import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../security/encryption_provider.dart';
import '../application/send_private_message.dart';
import '../domain/conversation.dart';
import '../domain/server_messaging.dart';

/// Production Firestore repository for authentic advocate-to-advocate messaging,
/// chamber groups, and legal document exchange.
class FirestoreMessagingRepository
    implements
        MessagingRepository,
        ConversationCreator,
        GroupManager,
        ServerMessaging,
        ConversationAuthorizer,
        EncryptedMessageTransport {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  final StreamController<void> _syncEvents = StreamController<void>.broadcast();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _conversationsSub;
  StreamSubscription<User?>? _authSub;
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
      _messageSubs = {};

  // In-memory cache for advocate details (name, court, enrollment, etc.)
  final Map<String, Map<String, dynamic>> _advocateCache = {};
  String _cachedCurrentUserName = '';

  FirestoreMessagingRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance {
    _authSub = _auth.authStateChanges().listen((user) {
      if (user != null) {
        _advocateCache.clear();
        _cachedCurrentUserName = '';
        connectRealtime().catchError((_) {});
      }
    });
  }

  String get _currentUserId {
    final user = _auth.currentUser;
    return user?.uid ?? 'current_user';
  }

  /// Resolves the current logged-in advocate's real display name.
  Future<String> getCurrentAdvocateFullName() async {
    if (_cachedCurrentUserName.isNotEmpty) return _cachedCurrentUserName;
    final user = _auth.currentUser;
    if (user != null) {
      if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
        _cachedCurrentUserName = user.displayName!.trim();
        return _cachedCurrentUserName;
      }
      final info = await _resolveAdvocateInfo(user.uid);
      if (info['fullName'] is String && (info['fullName'] as String).trim().isNotEmpty) {
        _cachedCurrentUserName = (info['fullName'] as String).trim();
        return _cachedCurrentUserName;
      }
      if (user.email != null && user.email!.isNotEmpty) {
        final emailPrefix = user.email!.split('@').first;
        final clean = emailPrefix.replaceAll(RegExp(r'[._]'), ' ').trim();
        if (clean.isNotEmpty) {
          _cachedCurrentUserName = clean
              .split(' ')
              .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
              .join(' ');
          return _cachedCurrentUserName;
        }
      }
    }
    return 'Advocate';
  }



  /// Looks up real advocate profile from Firestore (/advocates or /users)
  Future<Map<String, dynamic>> _resolveAdvocateInfo(String accountId) async {
    if (accountId.trim().isEmpty) return const {};
    final id = accountId.trim();
    if (_advocateCache.containsKey(id)) {
      return _advocateCache[id]!;
    }

    try {
      // 1. Direct document lookup in /advocates
      var doc = await _firestore.collection('advocates').doc(id).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _advocateCache[id] = data;
        return data;
      }

      // 2. If ID doesn't have 'adv_' prefix, try with prefix
      if (!id.startsWith('adv_')) {
        final withPref = 'adv_$id';
        doc = await _firestore.collection('advocates').doc(withPref).get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          _advocateCache[id] = data;
          _advocateCache[withPref] = data;
          return data;
        }
      }

      // 3. If ID starts with 'adv_', try without prefix
      if (id.startsWith('adv_')) {
        final noPref = id.substring(4);
        doc = await _firestore.collection('advocates').doc(noPref).get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          _advocateCache[id] = data;
          _advocateCache[noPref] = data;
          return data;
        }
      }

      // 4. Query /advocates where field id == id or enrollmentNumber == id
      final query = await _firestore
          .collection('advocates')
          .where('id', isEqualTo: id)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();
        _advocateCache[id] = data;
        return data;
      }

      // 5. Query /users collection
      final userDoc = await _firestore.collection('users').doc(id).get();
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data()!;
        _advocateCache[id] = data;
        return data;
      }
    } catch (e) {
      debugPrint('Firestore resolveAdvocateInfo error for $id: $e');
    }

    return const {};
  }

  String _generateUuid() {
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64; // Version 4
    bytes[8] = (bytes[8] & 63) | 128; // Variant 1
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  @override
  Stream<void> get syncAvailable => _syncEvents.stream;

  @override
  Future<void> connectRealtime() async {
    await _conversationsSub?.cancel();
    final uid = _currentUserId;

    _conversationsSub = _firestore
        .collection('conversations')
        .where('memberIds', arrayContains: uid)
        .snapshots()
        .listen(
      (snapshot) {
        _syncEvents.add(null);
        for (final doc in snapshot.docs) {
          _listenToConversationMessages(doc.id);
        }
      },
      onError: (e) {
        debugPrint('Firestore realtime conversations error: $e');
      },
    );
  }

  void _listenToConversationMessages(String conversationId) {
    if (_messageSubs.containsKey(conversationId)) return;
    _messageSubs[conversationId] = _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen(
      (_) => _syncEvents.add(null),
      onError: (_) {},
    );
  }

  @override
  Future<List<ConversationSummary>> listConversations() async {
    final uid = _currentUserId;
    try {
      final query = await _firestore
          .collection('conversations')
          .where('memberIds', arrayContains: uid)
          .get();

      final list = <ConversationSummary>[];

      for (final doc in query.docs) {
        // Skip any legacy fake seed conversations if present
        if (doc.id.startsWith('11111111-2222-3333-4444-55555555555') ||
            doc.id == 'delhi-bar') {
          continue;
        }

        final data = doc.data();
        final isGroup =
            data['kind'] == 'privateGroup' || data['kind'] == 'private_group';
        final createdAt =
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final lastMessageAt = (data['lastMessageAt'] as Timestamp?)?.toDate();
        final lastMessagePreview = data['lastMessagePreview'] as String?;
        final lastSenderId = data['lastSenderId'] as String?;
        final unreadCounts = data['unreadCounts'] as Map<String, dynamic>?;
        final rawUnread = (unreadCounts != null && unreadCounts.containsKey(uid))
            ? (unreadCounts[uid] as num?)?.toInt() ?? 0
            : (data['unreadCount'] as num?)?.toInt() ?? 0;
        final unread = (lastSenderId == uid) ? 0 : rawUnread;
        final memberIds =
            (data['memberIds'] as List<dynamic>?)?.cast<String>() ?? [];

        String title = '';
        String? category = data['category'] as String?;

        if (isGroup) {
          title = (data['title'] as String?)?.isNotEmpty == true
              ? data['title'] as String
              : 'Private Group';
          category ??= 'Chamber Group';
        } else {
          // Direct advocate-to-advocate conversation
          // Identify the peer advocate ID
          final peerId =
              memberIds.firstWhere((mId) => mId != uid, orElse: () => '');
          final memberNames = data['memberNames'] as Map<String, dynamic>?;
          final memberCourts = data['memberCourts'] as Map<String, dynamic>?;

          if (peerId.isNotEmpty &&
              memberNames != null &&
              memberNames[peerId] is String &&
              (memberNames[peerId] as String).trim().isNotEmpty) {
            title = memberNames[peerId] as String;
          } else if (peerId.isNotEmpty) {
            final peerInfo = await _resolveAdvocateInfo(peerId);
            if (peerInfo['fullName'] is String &&
                (peerInfo['fullName'] as String).trim().isNotEmpty) {
              title = (peerInfo['fullName'] as String).trim();
            }
          }

          if (title.isEmpty) {
            title = (data['title'] as String?)?.isNotEmpty == true
                ? data['title'] as String
                : 'Advocate';
          }

          if (peerId.isNotEmpty &&
              memberCourts != null &&
              memberCourts[peerId] is String &&
              (memberCourts[peerId] as String).isNotEmpty) {
            category = memberCourts[peerId] as String;
          } else if (peerId.isNotEmpty) {
            final peerInfo = await _resolveAdvocateInfo(peerId);
            if (peerInfo['primaryCourtName'] is String) {
              category = peerInfo['primaryCourtName'] as String;
            }
          }
          category ??= 'Direct Consultation';
        }

        final description = data['description'] as String?;
        final inviteCode = data['inviteCode'] as String?;
        final memberCount =
            (data['memberCount'] as num?)?.toInt() ?? memberIds.length;
        final createdBy = data['createdBy'] as String?;
        final isPublic = (data['isPublic'] as bool?) ?? true;

        list.add(
          ConversationSummary(
            id: doc.id,
            kind: isGroup
                ? ConversationKind.privateGroup
                : ConversationKind.direct,
            title: title,
            membershipEpoch: (data['membershipEpoch'] as num?)?.toInt() ?? 1,
            createdAt: createdAt,
            lastMessageAt: lastMessageAt,
            lastMessagePreview: lastMessagePreview,
            unreadCount: unread,
            description: description,
            category: category,
            inviteCode: inviteCode,
            memberCount: memberCount,
            createdBy: createdBy,
            isPublic: isPublic,
          ),
        );
      }

      list.sort((a, b) {
        final aTime = a.lastMessageAt ?? a.createdAt;
        final bTime = b.lastMessageAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });

      return list;
    } catch (e) {
      debugPrint('Firestore listConversations error: $e');
      return const [];
    }
  }

  @override
  Future<ConversationDetail> conversation(String id) async {
    try {
      final doc = await _firestore.collection('conversations').doc(id).get();
      if (doc.exists) {
        final data = doc.data()!;
        final memberIds =
            (data['memberIds'] as List<dynamic>?)?.cast<String>() ?? [];
        final isGroup = data['kind'] == 'privateGroup';
        final epoch = (data['membershipEpoch'] as num?)?.toInt() ?? 1;
        final memberNames = data['memberNames'] as Map<String, dynamic>?;

        String? title = data['title'] as String?;
        if (!isGroup && memberIds.isNotEmpty) {
          final peerId = memberIds.firstWhere((mId) => mId != _currentUserId,
              orElse: () => '');
          if (memberNames != null &&
              peerId.isNotEmpty &&
              memberNames[peerId] is String) {
            title = memberNames[peerId] as String;
          } else if (peerId.isNotEmpty) {
            final peerInfo = await _resolveAdvocateInfo(peerId);
            if (peerInfo['fullName'] is String) {
              title = peerInfo['fullName'] as String;
            }
          }
        }

        final myFullName = await getCurrentAdvocateFullName();
        final members = <ConversationMember>[];
        for (final mId in memberIds) {
          String name = mId == _currentUserId ? myFullName : 'Advocate';
          if (memberNames != null &&
              memberNames[mId] is String &&
              (memberNames[mId] as String).isNotEmpty) {
            name = memberNames[mId] as String;
          } else {
            final info = await _resolveAdvocateInfo(mId);
            if (info['fullName'] is String &&
                (info['fullName'] as String).isNotEmpty) {
              name = info['fullName'] as String;
            }
          }
          members.add(ConversationMember(
            accountId: mId,
            fullName: name,
            role: mId == data['createdBy'] ? 'admin' : 'member',
            devices: const [],
          ));
        }

        return ConversationDetail(
          ConversationAccess(
            conversationId: id,
            kind: isGroup
                ? ConversationKind.privateGroup
                : ConversationKind.direct,
            memberIds: memberIds,
            membershipEpoch: epoch,
          ),
          title,
          members,
        );
      }
    } catch (e) {
      debugPrint('Firestore conversation detail error: $e');
    }

    return ConversationDetail(
      ConversationAccess(
        conversationId: id,
        kind: ConversationKind.direct,
        memberIds: [_currentUserId],
        membershipEpoch: 1,
      ),
      'Advocate Consultation',
      const [],
    );
  }

  @override
  Future<ConversationSummary> createDirect(String peerAccountId) async {
    final uid = _currentUserId;
    final cleanPeerId = peerAccountId.trim();

    try {
      // 1. Resolve peer advocate details from Firestore
      final peerInfo = await _resolveAdvocateInfo(cleanPeerId);
      final peerTitle = (peerInfo['fullName'] as String?)?.trim().isNotEmpty == true
          ? (peerInfo['fullName'] as String).trim()
          : 'Advocate';
      final peerCourt = (peerInfo['primaryCourtName'] as String?) ??
          (peerInfo['primaryCourt'] as String?) ??
          'Delhi High Court';
      final peerEnrollment = (peerInfo['enrollmentNumber'] as String?) ?? '';

      // 2. Resolve current advocate details
      final myName = await getCurrentAdvocateFullName();
      final myInfo = await _resolveAdvocateInfo(uid);
      final myCourt = (myInfo['primaryCourtName'] as String?) ??
          (myInfo['primaryCourt'] as String?) ??
          'High Court';
      final myEnrollment = (myInfo['enrollmentNumber'] as String?) ?? '';

      // 3. Check if direct conversation already exists between these two advocates
      final existing = await _firestore
          .collection('conversations')
          .where('memberIds', arrayContains: uid)
          .get();

      for (final doc in existing.docs) {
        final data = doc.data();
        final kind = data['kind'] as String?;
        if (kind == 'direct' || kind == null) {
          final members =
              (data['memberIds'] as List<dynamic>?)?.cast<String>() ?? [];
          final hasPeer = members.contains(cleanPeerId) ||
              (peerInfo['id'] != null && members.contains(peerInfo['id']));
          if (hasPeer) {
            _listenToConversationMessages(doc.id);
            return ConversationSummary(
              id: doc.id,
              kind: ConversationKind.direct,
              title: peerTitle,
              category: peerCourt,
              membershipEpoch:
                  (data['membershipEpoch'] as num?)?.toInt() ?? 1,
              createdAt:
                  (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
              lastMessagePreview: data['lastMessagePreview'] as String?,
              unreadCount: (data['unreadCount'] as num?)?.toInt() ?? 0,
            );
          }
        }
      }

      // 4. Create new authentic direct conversation between the two advocates
      final id = _generateUuid();
      final now = FieldValue.serverTimestamp();
      final allMemberIds = <String>{uid, cleanPeerId};
      if (peerInfo['id'] is String && (peerInfo['id'] as String).isNotEmpty) {
        allMemberIds.add(peerInfo['id'] as String);
      }

      final data = {
        'id': id,
        'kind': 'direct',
        'title': peerTitle,
        'memberIds': allMemberIds.toList(),
        'memberNames': {
          uid: myName,
          cleanPeerId: peerTitle,
          if (peerInfo['id'] is String) peerInfo['id'] as String: peerTitle,
        },
        'memberCourts': {
          uid: myCourt,
          cleanPeerId: peerCourt,
          if (peerInfo['id'] is String) peerInfo['id'] as String: peerCourt,
        },
        'memberEnrollments': {
          uid: myEnrollment,
          cleanPeerId: peerEnrollment,
          if (peerInfo['id'] is String) peerInfo['id'] as String: peerEnrollment,
        },
        'membershipEpoch': 1,
        'createdAt': now,
        'lastMessageAt': now,
        'lastMessagePreview': 'Direct advocate consultation channel opened',
        'lastSenderId': uid,
        'unreadCount': 0,
        'unreadCounts': {
          uid: 0,
          cleanPeerId: 0,
        },
        'createdBy': uid,
      };

      await _firestore.collection('conversations').doc(id).set(data);
      _listenToConversationMessages(id);
      _syncEvents.add(null);

      return ConversationSummary(
        id: id,
        kind: ConversationKind.direct,
        title: peerTitle,
        category: peerCourt,
        membershipEpoch: 1,
        createdAt: DateTime.now(),
        lastMessageAt: DateTime.now(),
        lastMessagePreview: 'Direct advocate consultation channel opened',
        unreadCount: 0,
      );
    } catch (e) {
      debugPrint('Firestore createDirect error: $e');
      final fallbackId = _generateUuid();
      return ConversationSummary(
        id: fallbackId,
        kind: ConversationKind.direct,
        title: 'Advocate Consultation',
        membershipEpoch: 1,
        createdAt: DateTime.now(),
      );
    }
  }

  @override
  Future<ConversationSummary> createGroup(
    String title,
    List<String> memberAccountIds, {
    String? description,
    String? category,
    String? inviteCode,
    bool isPublic = true,
  }) async {
    final uid = _currentUserId;
    final allMembers = {uid, ...memberAccountIds}.toList();
    final id = _generateUuid();
    final now = FieldValue.serverTimestamp();
    final effectiveCode = inviteCode ??
        'VS-${(DateTime.now().millisecondsSinceEpoch % 9000 + 1000)}';

    final data = {
      'id': id,
      'kind': 'privateGroup',
      'title': title,
      'memberIds': allMembers,
      'membershipEpoch': 1,
      'createdAt': now,
      'lastMessageAt': now,
      'lastMessagePreview': 'Group created',
      'unreadCount': 0,
      'createdBy': uid,
      'description': description ?? '',
      'category': category ?? 'Chamber Group',
      'inviteCode': effectiveCode,
      'isPublic': isPublic,
      'memberCount': allMembers.length,
    };

    await _firestore.collection('conversations').doc(id).set(data);
    _listenToConversationMessages(id);
    _syncEvents.add(null);

    return ConversationSummary(
      id: id,
      kind: ConversationKind.privateGroup,
      title: title,
      membershipEpoch: 1,
      createdAt: DateTime.now(),
      lastMessageAt: DateTime.now(),
      lastMessagePreview: 'Group created',
      unreadCount: 0,
      description: description,
      category: category ?? 'Chamber Group',
      inviteCode: effectiveCode,
      memberCount: allMembers.length,
      createdBy: uid,
      isPublic: isPublic,
    );
  }

  @override
  Future<ConversationSummary> joinGroupByCode(String inviteCodeOrId) async {
    final uid = _currentUserId;
    final normalized = inviteCodeOrId.trim().toUpperCase();

    var query = await _firestore
        .collection('conversations')
        .where('inviteCode', isEqualTo: normalized)
        .limit(1)
        .get();

    DocumentSnapshot<Map<String, dynamic>>? doc;
    if (query.docs.isNotEmpty) {
      doc = query.docs.first;
    } else {
      final byId = await _firestore
          .collection('conversations')
          .doc(inviteCodeOrId.trim())
          .get();
      if (byId.exists) {
        doc = byId;
      }
    }

    if (doc == null || !doc.exists) {
      throw Exception('No chamber group found with code "$inviteCodeOrId"');
    }

    final data = doc.data()!;
    final memberIds =
        (data['memberIds'] as List<dynamic>?)?.cast<String>() ?? [];
    if (!memberIds.contains(uid)) {
      await _firestore.collection('conversations').doc(doc.id).update({
        'memberIds': FieldValue.arrayUnion([uid]),
        'memberCount': memberIds.length + 1,
      });
    }

    _listenToConversationMessages(doc.id);
    _syncEvents.add(null);

    final createdAt =
        (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final lastMessageAt = (data['lastMessageAt'] as Timestamp?)?.toDate();
    return ConversationSummary(
      id: doc.id,
      kind: ConversationKind.privateGroup,
      title: data['title'] as String? ?? 'Chamber Group',
      membershipEpoch: (data['membershipEpoch'] as num?)?.toInt() ?? 1,
      createdAt: createdAt,
      lastMessageAt: lastMessageAt,
      lastMessagePreview: data['lastMessagePreview'] as String?,
      unreadCount: 0,
      description: data['description'] as String?,
      category: data['category'] as String? ?? 'Chamber Group',
      inviteCode: data['inviteCode'] as String?,
      memberCount: memberIds.length + (memberIds.contains(uid) ? 0 : 1),
      createdBy: data['createdBy'] as String?,
      isPublic: (data['isPublic'] as bool?) ?? true,
    );
  }

  @override
  Future<void> leaveGroup(String conversationId) async {
    final uid = _currentUserId;
    try {
      await _firestore.collection('conversations').doc(conversationId).update({
        'memberIds': FieldValue.arrayRemove([uid]),
        'memberCount': FieldValue.increment(-1),
      });
      _syncEvents.add(null);
    } catch (e) {
      debugPrint('Firestore leaveGroup error: $e');
      rethrow;
    }
  }

  @override
  Future<List<ConversationSummary>> listDiscoverableGroups() async {
    try {
      final query = await _firestore
          .collection('conversations')
          .where('kind', isEqualTo: 'privateGroup')
          .get();

      final list = <ConversationSummary>[];
      for (final doc in query.docs) {
        // Skip legacy fake docs
        if (doc.id.startsWith('11111111-2222-3333-4444-55555555555')) continue;

        final data = doc.data();
        final memberIds =
            (data['memberIds'] as List<dynamic>?)?.cast<String>() ?? [];
        final createdAt =
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final lastMessageAt = (data['lastMessageAt'] as Timestamp?)?.toDate();
        list.add(
          ConversationSummary(
            id: doc.id,
            kind: ConversationKind.privateGroup,
            title: data['title'] as String? ?? 'Chamber Group',
            membershipEpoch: (data['membershipEpoch'] as num?)?.toInt() ?? 1,
            createdAt: createdAt,
            lastMessageAt: lastMessageAt,
            lastMessagePreview: data['lastMessagePreview'] as String?,
            unreadCount: 0,
            description: data['description'] as String?,
            category: data['category'] as String? ?? 'Chamber Group',
            inviteCode: data['inviteCode'] as String?,
            memberCount:
                (data['memberCount'] as num?)?.toInt() ?? memberIds.length,
            createdBy: data['createdBy'] as String?,
            isPublic: (data['isPublic'] as bool?) ?? true,
          ),
        );
      }
      return list;
    } catch (e) {
      debugPrint('Firestore listDiscoverableGroups error: $e');
      return const [];
    }
  }

  @override
  Future<ServerMessagePage> history(
    String conversationId, {
    String? before,
  }) async {
    final uid = _currentUserId;
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(50);

      if (before != null) {
        final beforeDoc = await _firestore
            .collection('conversations')
            .doc(conversationId)
            .collection('messages')
            .doc(before)
            .get();
        if (beforeDoc.exists) {
          query = query.startAfterDocument(beforeDoc);
        }
      }

      final snapshot = await query.get();
      final myName = await getCurrentAdvocateFullName();

      final items = snapshot.docs.map((doc) {
        final data = doc.data();
        final senderId = data['senderAccountId'] as String? ?? '';
        final isMine = senderId == uid;
        final createdAt =
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final editedAt = (data['editedAt'] as Timestamp?)?.toDate();
        final deletedAt = (data['deletedAt'] as Timestamp?)?.toDate();

        return ServerMessage(
          doc.id,
          data['body'] as String? ?? '',
          data['senderName'] as String? ?? (isMine ? myName : 'Advocate'),
          isMine,
          createdAt,
          (data['recipientCount'] as num?)?.toInt() ?? 1,
          (data['deliveredCount'] as num?)?.toInt() ?? 1,
          (data['readCount'] as num?)?.toInt() ?? (isMine ? 1 : 0),
          data['attachmentId'] as String?,
          data['attachmentName'] as String?,
          data['attachmentContentType'] as String?,
          (data['attachmentBytes'] as num?)?.toInt(),
          data['replyToMessageId'] as String?,
          data['replyBody'] as String?,
          data['replySenderName'] as String?,
          data['replyDeleted'] as bool? ?? false,
          editedAt,
          deletedAt,
        );
      }).toList();

      final nextCursor =
          snapshot.docs.isNotEmpty ? snapshot.docs.last.id : null;

      return ServerMessagePage(items, nextCursor);
    } catch (e) {
      debugPrint('Firestore history error: $e');
      return ServerMessagePage(const [], null);
    }
  }

  @override
  Future<void> sendText(
    String conversationId,
    String clientMessageId,
    String body, {
    String? attachmentId,
    String? replyToMessageId,
  }) async {
    final uid = _currentUserId;
    final userName = await getCurrentAdvocateFullName();

    String? replyBody;
    String? replySenderName;
    if (replyToMessageId != null) {
      try {
        final rDoc = await _firestore
            .collection('conversations')
            .doc(conversationId)
            .collection('messages')
            .doc(replyToMessageId)
            .get();
        if (rDoc.exists) {
          replyBody = rDoc.data()?['body'] as String?;
          replySenderName = rDoc.data()?['senderName'] as String?;
        }
      } catch (_) {}
    }

    String? attachmentName;
    String? attachmentContentType;
    int? attachmentBytes;
    if (attachmentId != null) {
      try {
        final aDoc =
            await _firestore.collection('attachments').doc(attachmentId).get();
        if (aDoc.exists) {
          final aData = aDoc.data()!;
          attachmentName = aData['filename'] as String?;
          attachmentContentType = aData['contentType'] as String?;
          attachmentBytes = (aData['byteSize'] as num?)?.toInt();
        }
      } catch (_) {}
    }

    final messageDoc = {
      'id': clientMessageId,
      'conversationId': conversationId,
      'body': body,
      'senderAccountId': uid,
      'senderName': userName,
      'createdAt': FieldValue.serverTimestamp(),
      'recipientCount': 1,
      'deliveredCount': 1,
      'readCount': 0,
      if (attachmentId != null) 'attachmentId': attachmentId,
      if (attachmentName != null) 'attachmentName': attachmentName,
      if (attachmentContentType != null)
        'attachmentContentType': attachmentContentType,
      if (attachmentBytes != null) 'attachmentBytes': attachmentBytes,
      if (replyToMessageId != null) ...{
        'replyToMessageId': replyToMessageId,
        'replyBody': replyBody,
        'replySenderName': replySenderName,
        'replyDeleted': false,
      },
    };

    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(clientMessageId)
        .set(messageDoc);

    final convRef = _firestore.collection('conversations').doc(conversationId);
    try {
      final convDoc = await convRef.get();
      if (!convDoc.exists) {
        await convRef.set({
          'id': conversationId,
          'kind': 'direct',
          'title': 'Advocate Consultation',
          'memberIds': [uid],
          'membershipEpoch': 1,
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessagePreview':
              body.isNotEmpty ? body : (attachmentName ?? 'Attachment'),
          'lastMessageAt': FieldValue.serverTimestamp(),
          'lastSenderId': uid,
          'unreadCount': 0,
          'createdBy': uid,
        });
      } else {
        final members = (convDoc.data()?['memberIds'] as List<dynamic>?)
                ?.cast<String>() ??
            [];
        final updates = <String, dynamic>{
          'lastMessagePreview':
              body.isNotEmpty ? body : (attachmentName ?? 'Attachment'),
          'lastMessageAt': FieldValue.serverTimestamp(),
          'lastSenderId': uid,
          'unreadCount': FieldValue.increment(1),
          'memberIds': FieldValue.arrayUnion([uid]),
        };
        for (final m in members) {
          if (m != uid) {
            updates['unreadCounts.$m'] = FieldValue.increment(1);
          }
        }
        await convRef.update(updates);
      }
    } catch (_) {
      await convRef.set({
        'lastMessagePreview':
            body.isNotEmpty ? body : (attachmentName ?? 'Attachment'),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSenderId': uid,
        'unreadCount': FieldValue.increment(1),
        'memberIds': FieldValue.arrayUnion([uid]),
      }, SetOptions(merge: true));
    }

    _listenToConversationMessages(conversationId);
    _syncEvents.add(null);
  }

  @override
  Future<void> editMessage(
    String conversationId,
    String messageId,
    String body,
  ) async {
    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update({
      'body': body,
      'editedAt': FieldValue.serverTimestamp(),
    });
    _syncEvents.add(null);
  }

  @override
  Future<void> deleteMessage(String conversationId, String messageId) async {
    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update({
      'body': 'This message was deleted',
      'deletedAt': FieldValue.serverTimestamp(),
    });
    _syncEvents.add(null);
  }

  @override
  Future<void> markRead(String conversationId, String throughMessageId) async {
    final uid = _currentUserId;
    try {
      await _firestore.collection('conversations').doc(conversationId).set({
        'unreadCount': 0,
        'unreadCounts': {
          uid: 0,
        },
      }, SetOptions(merge: true));

      final snapshot = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .where('senderAccountId', isNotEqualTo: uid)
          .limit(20)
          .get();

      for (final doc in snapshot.docs) {
        if ((doc.data()['readCount'] as num? ?? 0) == 0) {
          doc.reference.update({'readCount': 1});
        }
      }
    } catch (_) {} finally {
      _syncEvents.add(null);
    }
  }

  @override
  Future<String> uploadAttachment(
    String conversationId,
    String filename,
    String contentType,
    List<int> bytes,
  ) async {
    final attachmentId = _generateUuid();
    final base64Data = base64Encode(bytes);

    String conversationTitle = 'Legal Document';
    try {
      if (conversationId.isNotEmpty) {
        final convDoc = await _firestore
            .collection('conversations')
            .doc(conversationId)
            .get();
        if (convDoc.exists && convDoc.data()?['title'] != null) {
          conversationTitle = convDoc.data()!['title'] as String;
        }
      }
    } catch (_) {}

    await _firestore.collection('attachments').doc(attachmentId).set({
      'id': attachmentId,
      'conversationId': conversationId,
      'conversationTitle': conversationTitle,
      'filename': filename,
      'contentType': contentType,
      'byteSize': bytes.length,
      'dataBase64': base64Data,
      'createdAt': FieldValue.serverTimestamp(),
      'uploaderId': _currentUserId,
    });

    _syncEvents.add(null);
    return attachmentId;
  }

  @override
  Future<List<int>> downloadAttachment(String attachmentId) async {
    try {
      final doc =
          await _firestore.collection('attachments').doc(attachmentId).get();
      if (doc.exists && doc.data()?['dataBase64'] != null) {
        final base64Data = doc.data()!['dataBase64'] as String;
        return base64Decode(base64Data);
      }
    } catch (e) {
      debugPrint('Firestore downloadAttachment error: $e');
    }
    throw StateError('Attachment not found or unreadable');
  }

  @override
  Future<SharedAttachmentPage> sharedAttachments({
    String? before,
    String search = '',
    String kind = 'all',
  }) async {
    try {
      final snapshot = await _firestore
          .collection('attachments')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      final items = <SharedAttachment>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final filename = data['filename'] as String? ?? 'attachment';
        final contentType =
            data['contentType'] as String? ?? 'application/octet-stream';
        final createdAt =
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final byteSize = (data['byteSize'] as num?)?.toInt() ?? 0;
        final conversationId = data['conversationId'] as String? ?? '';
        final conversationTitle = data['conversationTitle'] as String? ??
            'Legal Attachment';

        if (search.isNotEmpty &&
            !filename.toLowerCase().contains(search.toLowerCase())) {
          continue;
        }

        if (kind == 'images' && !contentType.startsWith('image/')) continue;
        if (kind == 'documents' && !contentType.contains('pdf')) continue;

        items.add(SharedAttachment(
          id: doc.id,
          messageId: doc.id,
          conversationId: conversationId,
          conversationTitle: conversationTitle,
          filename: filename,
          contentType: contentType,
          byteSize: byteSize,
          createdAt: createdAt,
        ));
      }

      return SharedAttachmentPage(items, null);
    } catch (e) {
      debugPrint('Firestore sharedAttachments error: $e');
      return const SharedAttachmentPage([], null);
    }
  }

  @override
  Future<List<InboxEnvelope>> syncInbox() async => const [];

  @override
  Future<void> acknowledge(List<String> envelopeIds) async {}

  @override
  Future<void> retryPending() async {}

  @override
  Future<ConversationAccess> authorizeSend(
    sender,
    String conversationId,
  ) async =>
      (await conversation(conversationId)).access;

  @override
  Future<void> deliver(
    EncryptedEnvelope envelope,
    String clientMessageId,
  ) async {
    final currentUserId = _currentUserId;
    await _firestore
        .collection('conversations')
        .doc(envelope.conversationId)
        .collection('messages')
        .doc(clientMessageId)
        .set({
      'id': clientMessageId,
      'conversationId': envelope.conversationId,
      'body': '[Encrypted Message]',
      'senderAccountId': currentUserId,
      'senderDeviceId': envelope.senderDeviceId,
      'ciphertext': base64Encode(envelope.bytes),
      'createdAt': FieldValue.serverTimestamp(),
      'recipientCount': 1,
      'deliveredCount': 1,
      'readCount': 0,
    });
  }

  @override
  Future<void> close() async {
    await _authSub?.cancel();
    await _conversationsSub?.cancel();
    for (final sub in _messageSubs.values) {
      await sub.cancel();
    }
    _messageSubs.clear();
    await _syncEvents.close();
  }
}
