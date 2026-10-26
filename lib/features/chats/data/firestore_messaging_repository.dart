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
  bool _seeded = false;
  bool _attachmentsSeeded = false;

  static const Map<String, String> _knownAdvocateNames = {
    'adv_meera': 'Meera Sharma',
    'meera': 'Meera Sharma',
    'adv_kabir': 'Kabir Malhotra',
    'kabir': 'Kabir Malhotra',
    'adv_naina': 'Naina Bansal',
    'naina': 'Naina Bansal',
    'adv_rohit': 'Rohit Verma',
    'rohit': 'Rohit Verma',
  };

  static String normalizeAdvocateId(String id) {
    if (id.startsWith('adv_')) return id;
    if (id == 'meera' || id == 'kabir' || id == 'naina' || id == 'rohit') {
      return 'adv_$id';
    }
    return id;
  }

  FirestoreMessagingRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance {
    _authSub = _auth.authStateChanges().listen((user) {
      if (user != null) {
        connectRealtime().catchError((_) {});
      }
    });
  }

  String get _currentUserId {
    final user = _auth.currentUser;
    return user?.uid ?? 'current_user';
  }

  String get _currentUserName {
    final user = _auth.currentUser;
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      return user.displayName!;
    }
    return 'Anish Kumar';
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
      var query = await _firestore
          .collection('conversations')
          .where('memberIds', arrayContains: uid)
          .get();

      // If database has no conversations for this user, seed starter chats
      if (query.docs.isEmpty && !_seeded) {
        _seeded = true;
        await _seedDefaultConversations(uid);
        query = await _firestore
            .collection('conversations')
            .where('memberIds', arrayContains: uid)
            .get();
      }

      final list = query.docs.map((doc) {
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

        String title = (data['title'] as String?)?.isNotEmpty == true
            ? data['title'] as String
            : (isGroup ? 'Private Group' : 'Advocate');

        if (!isGroup) {
          final peerId = memberIds.firstWhere((mId) => mId != uid, orElse: () => '');
          final memberNames = data['memberNames'] as Map<String, dynamic>?;
          if (memberNames != null &&
              peerId.isNotEmpty &&
              memberNames[peerId] is String &&
              (memberNames[peerId] as String).isNotEmpty) {
            title = memberNames[peerId] as String;
          } else if (peerId.isNotEmpty && _knownAdvocateNames.containsKey(peerId)) {
            title = _knownAdvocateNames[peerId]!;
          }
        }

        final description = data['description'] as String?;
        final category = data['category'] as String?;
        final inviteCode = data['inviteCode'] as String?;
        final memberCount = (data['memberCount'] as num?)?.toInt() ?? memberIds.length;
        final createdBy = data['createdBy'] as String?;
        final isPublic = (data['isPublic'] as bool?) ?? true;

        return ConversationSummary(
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
          category: category ?? (isGroup ? 'Chamber Group' : null),
          inviteCode: inviteCode,
          memberCount: memberCount,
          createdBy: createdBy,
          isPublic: isPublic,
        );
      }).toList();

      list.sort((a, b) {
        final aTime = a.lastMessageAt ?? a.createdAt;
        final bTime = b.lastMessageAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });

      return list.isNotEmpty ? list : _fallbackConversations;
    } catch (e) {
      debugPrint('Firestore listConversations error: $e');
      return _fallbackConversations;
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
          final peerId = memberIds.firstWhere((mId) => mId != _currentUserId, orElse: () => '');
          if (memberNames != null && peerId.isNotEmpty && memberNames[peerId] is String) {
            title = memberNames[peerId] as String;
          } else if (peerId.isNotEmpty && _knownAdvocateNames.containsKey(peerId)) {
            title = _knownAdvocateNames[peerId];
          }
        }

        final members = memberIds.map((mId) {
          String name = mId == _currentUserId ? _currentUserName : 'Advocate';
          if (memberNames != null && memberNames[mId] is String) {
            name = memberNames[mId] as String;
          } else if (_knownAdvocateNames.containsKey(mId)) {
            name = _knownAdvocateNames[mId]!;
          }
          return ConversationMember(
            accountId: mId,
            fullName: name,
            role: 'member',
            devices: const [],
          );
        }).toList();

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
    } catch (_) {}

    return ConversationDetail(
      ConversationAccess(
        conversationId: id,
        kind: ConversationKind.direct,
        memberIds: [_currentUserId],
        membershipEpoch: 1,
      ),
      'Conversation',
      const [],
    );
  }

  @override
  Future<ConversationSummary> createDirect(String peerAccountId) async {
    final uid = _currentUserId;
    final normPeerId = normalizeAdvocateId(peerAccountId);

    try {
      // 1. Check if direct conversation already exists between these users
      final existing = await _firestore
          .collection('conversations')
          .where('memberIds', arrayContains: uid)
          .get();

      for (final doc in existing.docs) {
        final data = doc.data();
        if (data['kind'] == 'direct' || data['kind'] == null) {
          final members =
              (data['memberIds'] as List<dynamic>?)?.cast<String>() ?? [];
          if (members.contains(peerAccountId) || members.contains(normPeerId)) {
            final memberNames = data['memberNames'] as Map<String, dynamic>?;
            String title = data['title'] as String? ?? 'Private Conversation';
            if (memberNames != null && memberNames[normPeerId] is String) {
              title = memberNames[normPeerId] as String;
            } else if (_knownAdvocateNames.containsKey(peerAccountId)) {
              title = _knownAdvocateNames[peerAccountId]!;
            } else if (_knownAdvocateNames.containsKey(normPeerId)) {
              title = _knownAdvocateNames[normPeerId]!;
            }

            _listenToConversationMessages(doc.id);
            return ConversationSummary(
              id: doc.id,
              kind: ConversationKind.direct,
              title: title,
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

      // 2. Resolve peer advocate details for title
      String peerTitle = _knownAdvocateNames[peerAccountId] ??
          _knownAdvocateNames[normPeerId] ??
          'Advocate';
      try {
        final advDoc =
            await _firestore.collection('advocates').doc(normPeerId).get();
        if (advDoc.exists) {
          peerTitle = advDoc.data()?['fullName'] as String? ?? peerTitle;
        } else {
          final userDoc =
              await _firestore.collection('users').doc(peerAccountId).get();
          if (userDoc.exists) {
            peerTitle = userDoc.data()?['fullName'] as String? ?? peerTitle;
          }
        }
      } catch (_) {}

      // 3. Create new direct conversation document
      final id = _generateUuid();
      final now = FieldValue.serverTimestamp();
      final allMemberIds = {uid, normPeerId, peerAccountId}.toList();
      final data = {
        'id': id,
        'kind': 'direct',
        'title': peerTitle,
        'memberIds': allMemberIds,
        'memberNames': {
          uid: _currentUserName,
          normPeerId: peerTitle,
          if (peerAccountId != normPeerId) peerAccountId: peerTitle,
        },
        'membershipEpoch': 1,
        'createdAt': now,
        'lastMessageAt': now,
        'lastMessagePreview': 'Conversation started',
        'unreadCount': 0,
        'createdBy': uid,
      };

      await _firestore.collection('conversations').doc(id).set(data);
      _listenToConversationMessages(id);
      _syncEvents.add(null);

      return ConversationSummary(
        id: id,
        kind: ConversationKind.direct,
        title: peerTitle,
        membershipEpoch: 1,
        createdAt: DateTime.now(),
        lastMessageAt: DateTime.now(),
        lastMessagePreview: 'Conversation started',
        unreadCount: 0,
      );
    } catch (e) {
      debugPrint('Firestore createDirect error: $e');
      final fallbackId = _generateUuid();
      final fallbackTitle = _knownAdvocateNames[peerAccountId] ??
          _knownAdvocateNames[normPeerId] ??
          'Advocate';
      return ConversationSummary(
        id: fallbackId,
        kind: ConversationKind.direct,
        title: fallbackTitle,
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

    // 1. Search by invite code first
    var query = await _firestore
        .collection('conversations')
        .where('inviteCode', isEqualTo: normalized)
        .limit(1)
        .get();

    // 2. If not found, try searching by document ID directly
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
      throw Exception('No group found with code or ID "$inviteCodeOrId"');
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
      title: data['title'] as String? ?? 'Private Group',
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
            title: data['title'] as String? ?? 'Private Group',
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
          data['senderName'] as String? ??
              (isMine ? _currentUserName : 'Advocate'),
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

      if (items.isEmpty && before == null) {
        final fallbacks = _fallbackMessagesForConversation(conversationId, uid);
        if (fallbacks.isNotEmpty) {
          return ServerMessagePage(fallbacks, null);
        }
      }

      return ServerMessagePage(items, nextCursor);
    } catch (e) {
      debugPrint('Firestore history error: $e');
      final fallbacks = _fallbackMessagesForConversation(conversationId, uid);
      return ServerMessagePage(fallbacks, null);
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
    final userName = _currentUserName;

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
          'title': _knownAdvocateNames[conversationId] ?? 'Advocate',
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
        await convRef.set({
          'lastMessagePreview':
              body.isNotEmpty ? body : (attachmentName ?? 'Attachment'),
          'lastMessageAt': FieldValue.serverTimestamp(),
          'lastSenderId': uid,
          'unreadCount': FieldValue.increment(1),
          'memberIds': FieldValue.arrayUnion([uid]),
        }, SetOptions(merge: true));
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
    for (var i = 0; i < _fallbackConversations.length; i++) {
      if (_fallbackConversations[i].id == conversationId) {
        final c = _fallbackConversations[i];
        _fallbackConversations[i] = ConversationSummary(
          id: c.id,
          kind: c.kind,
          title: c.title,
          membershipEpoch: c.membershipEpoch,
          createdAt: c.createdAt,
          lastMessageAt: c.lastMessageAt,
          lastMessagePreview: c.lastMessagePreview,
          unreadCount: 0,
        );
      }
    }

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

  Future<void> _seedInitialAttachments() async {
    final initialDocs = [
      {
        'id': 'att_wp_1042_2026',
        'conversationId': '11111111-2222-3333-4444-555555555553',
        'conversationTitle': 'Delhi High Court Bar Association',
        'filename': 'Petition_Draft_WP_1042_2026.pdf',
        'contentType': 'application/pdf',
        'court': 'HIGH COURT OF DELHI AT NEW DELHI',
        'caseNum': 'W.P.(C) 1042/2026',
        'summary': 'Writ Petition under Article 226 of the Constitution of India for interim protection.',
      },
      {
        'id': 'att_order_saket_14',
        'conversationId': '11111111-2222-3333-4444-555555555551',
        'conversationTitle': 'Meera Sharma',
        'filename': 'Court_Order_Item_14_Saket.pdf',
        'contentType': 'application/pdf',
        'court': 'COURT OF DISTRICT JUDGE, SAKET COURTS, NEW DELHI',
        'caseNum': 'Civil Suit No. 412/2026',
        'summary': 'Interim Injunction Order passed in matter listed at Item 14.',
      },
      {
        'id': 'att_vakalatnama_meera',
        'conversationId': '11111111-2222-3333-4444-555555555551',
        'conversationTitle': 'Meera Sharma',
        'filename': 'Vakalatnama_Meera_Sharma.pdf',
        'contentType': 'application/pdf',
        'court': 'BAR COUNCIL OF DELHI - POWER OF ATTORNEY',
        'caseNum': 'Enrolment No. D/1420/2018',
        'summary': 'Executed Advocate Vakalatnama appointing counsel for all court proceedings.',
      },
      {
        'id': 'att_evidence_report',
        'conversationId': '11111111-2222-3333-4444-555555555553',
        'conversationTitle': 'Delhi High Court Bar Association',
        'filename': 'Evidence_Site_Inspection_Report.pdf',
        'contentType': 'application/pdf',
        'court': 'LOCAL COMMISSIONER EVIDENCE REPORT',
        'caseNum': 'Commission Order Dated 12-09-2026',
        'summary': 'Joint site inspection, demarcation findings, and annexed photographic evidence.',
      },
    ];

    for (final doc in initialDocs) {
      final pdfBytes = _buildSimplePdf(
        doc['filename'] as String,
        doc['court'] as String,
        doc['caseNum'] as String,
        doc['summary'] as String,
      );
      await _firestore.collection('attachments').doc(doc['id'] as String).set({
        'id': doc['id'],
        'conversationId': doc['conversationId'],
        'conversationTitle': doc['conversationTitle'],
        'filename': doc['filename'],
        'contentType': doc['contentType'],
        'byteSize': pdfBytes.length,
        'dataBase64': base64Encode(pdfBytes),
        'createdAt': FieldValue.serverTimestamp(),
        'uploaderId': _currentUserId,
      }, SetOptions(merge: true));
    }
  }

  static List<int> _buildSimplePdf(
    String title,
    String court,
    String caseNum,
    String summary,
  ) {
    final cleanCourt = court.replaceAll(RegExp(r'[()]'), '');
    final cleanTitle = title.replaceAll(RegExp(r'[()]'), '');
    final cleanCase = caseNum.replaceAll(RegExp(r'[()]'), '');
    final cleanSummary = summary.replaceAll(RegExp(r'[()]'), '');

    final content = '''
BT
/F1 14 Tf
50 750 Td
($cleanCourt) Tj
/F1 12 Tf
0 -30 Td
(Document: $cleanTitle) Tj
0 -22 Td
(Case: $cleanCase) Tj
0 -22 Td
(Verified Digital Filing - VakilSetu Court Records) Tj
0 -30 Td
($cleanSummary) Tj
ET
''';
    final streamBytes = utf8.encode(content);
    final streamLength = streamBytes.length;
    final pdfText = '''%PDF-1.4
1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
2 0 obj
<< /Type /Pages /Kids [3 0 R] /Count 1 >>
endobj
3 0 obj
<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>
endobj
4 0 obj
<< /Length $streamLength >>
stream
$content
endstream
endobj
5 0 obj
<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>
endobj
xref
0 6
0000000000 65535 f 
0000000009 00000 n 
0000000058 00000 n 
0000000115 00000 n 
0000000244 00000 n 
0000000350 00000 n 
trailer
<< /Size 6 /Root 1 0 R >>
startxref
450
%%EOF''';
    return utf8.encode(pdfText);
  }

  @override
  Future<SharedAttachmentPage> sharedAttachments({
    String? before,
    String search = '',
    String kind = 'all',
  }) async {
    try {
      var snapshot = await _firestore
          .collection('attachments')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      if (snapshot.docs.isEmpty && !_attachmentsSeeded) {
        _attachmentsSeeded = true;
        await _seedInitialAttachments();
        snapshot = await _firestore
            .collection('attachments')
            .orderBy('createdAt', descending: true)
            .limit(50)
            .get();
      }

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

  // -------------------------------------------------------------
  // Default Seed Data for New / Clean Firestore Databases
  // -------------------------------------------------------------
  Future<void> _seedDefaultConversations(String uid) async {
    try {
      final now = DateTime.now();

      // Conversation 1: Meera Sharma
      const meeraId = '11111111-2222-3333-4444-555555555551';
      final meeraDoc = _firestore.collection('conversations').doc(meeraId);
      await meeraDoc.set({
        'id': meeraId,
        'kind': 'direct',
        'title': 'Meera Sharma',
        'memberIds': FieldValue.arrayUnion([uid, 'adv_meera', 'meera']),
        'memberNames': {
          uid: _currentUserName,
          'adv_meera': 'Meera Sharma',
          'meera': 'Meera Sharma',
        },
        'membershipEpoch': 1,
        'createdAt': Timestamp.fromDate(now.subtract(const Duration(hours: 3))),
        'lastMessageAt':
            Timestamp.fromDate(now.subtract(const Duration(minutes: 15))),
        'lastMessagePreview':
            'Let me know once you go through the clause 14 provisions.',
        'unreadCount': 1,
        'createdBy': 'adv_meera',
      }, SetOptions(merge: true));

      await meeraDoc.collection('messages').doc('msg_meera_1').set({
        'id': 'msg_meera_1',
        'conversationId': meeraId,
        'body':
            'Hello Counsel, have you reviewed the commercial arbitration draft for Delhi High Court?',
        'senderAccountId': 'adv_meera',
        'senderName': 'Meera Sharma',
        'createdAt':
            Timestamp.fromDate(now.subtract(const Duration(hours: 2))),
        'recipientCount': 1,
        'deliveredCount': 1,
        'readCount': 1,
      });

      await meeraDoc.collection('messages').doc('msg_meera_2').set({
        'id': 'msg_meera_2',
        'conversationId': meeraId,
        'body':
            'Yes, I reviewed it. The jurisdiction clause looks solid.',
        'senderAccountId': uid,
        'senderName': _currentUserName,
        'createdAt':
            Timestamp.fromDate(now.subtract(const Duration(hours: 1))),
        'recipientCount': 1,
        'deliveredCount': 1,
        'readCount': 1,
      });

      await meeraDoc.collection('messages').doc('msg_meera_3').set({
        'id': 'msg_meera_3',
        'conversationId': meeraId,
        'body':
            'Let me know once you go through the clause 14 provisions.',
        'senderAccountId': 'adv_meera',
        'senderName': 'Meera Sharma',
        'createdAt':
            Timestamp.fromDate(now.subtract(const Duration(minutes: 15))),
        'recipientCount': 1,
        'deliveredCount': 1,
        'readCount': 0,
      });

      // Conversation 2: Kabir Malhotra
      const kabirId = '11111111-2222-3333-4444-555555555552';
      final kabirDoc = _firestore.collection('conversations').doc(kabirId);
      await kabirDoc.set({
        'id': kabirId,
        'kind': 'direct',
        'title': 'Kabir Malhotra',
        'memberIds': FieldValue.arrayUnion([uid, 'adv_kabir', 'kabir']),
        'memberNames': {
          uid: _currentUserName,
          'adv_kabir': 'Kabir Malhotra',
          'kabir': 'Kabir Malhotra',
        },
        'membershipEpoch': 1,
        'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 1))),
        'lastMessageAt':
            Timestamp.fromDate(now.subtract(const Duration(minutes: 45))),
        'lastMessagePreview':
            'Saket Court bench hearing is scheduled for tomorrow 10:30 AM.',
        'unreadCount': 0,
        'createdBy': 'adv_kabir',
      }, SetOptions(merge: true));

      await kabirDoc.collection('messages').doc('msg_kabir_1').set({
        'id': 'msg_kabir_1',
        'conversationId': kabirId,
        'body': 'Are you appearing before Court 3 tomorrow?',
        'senderAccountId': uid,
        'senderName': _currentUserName,
        'createdAt':
            Timestamp.fromDate(now.subtract(const Duration(hours: 2))),
        'recipientCount': 1,
        'deliveredCount': 1,
        'readCount': 1,
      });

      await kabirDoc.collection('messages').doc('msg_kabir_2').set({
        'id': 'msg_kabir_2',
        'conversationId': kabirId,
        'body':
            'Saket Court bench hearing is scheduled for tomorrow 10:30 AM.',
        'senderAccountId': 'adv_kabir',
        'senderName': 'Kabir Malhotra',
        'createdAt':
            Timestamp.fromDate(now.subtract(const Duration(minutes: 45))),
        'recipientCount': 1,
        'deliveredCount': 1,
        'readCount': 1,
      });

      // Conversation 3: Delhi High Court Bar Association Group
      const groupId = '11111111-2222-3333-4444-555555555553';
      final groupDoc = _firestore.collection('conversations').doc(groupId);
      await groupDoc.set({
        'id': groupId,
        'kind': 'privateGroup',
        'title': 'Delhi High Court Bar Association',
        'memberIds': FieldValue.arrayUnion([uid, 'adv_meera', 'adv_kabir', 'adv_rohit']),
        'membershipEpoch': 1,
        'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 3))),
        'lastMessageAt':
            Timestamp.fromDate(now.subtract(const Duration(hours: 2))),
        'lastMessagePreview':
            'The bar association meeting on digital filings is at 4 PM in library hall.',
        'unreadCount': 2,
        'createdBy': 'adv_meera',
        'inviteCode': 'VS-DHCBA',
        'category': 'Bar Association',
        'description':
            'Official forum for advocates registered with Delhi High Court Bar Association.',
        'memberCount': 240,
        'isPublic': true,
      }, SetOptions(merge: true));

      await groupDoc.collection('messages').doc('msg_grp_1').set({
        'id': 'msg_grp_1',
        'conversationId': groupId,
        'body':
            'Notice: The bar association meeting on digital filings is at 4 PM in library hall.',
        'senderAccountId': 'adv_meera',
        'senderName': 'Meera Sharma',
        'createdAt':
            Timestamp.fromDate(now.subtract(const Duration(hours: 3))),
        'recipientCount': 4,
        'deliveredCount': 4,
        'readCount': 2,
      });

      await groupDoc.collection('messages').doc('msg_grp_2').set({
        'id': 'msg_grp_2',
        'conversationId': groupId,
        'body': 'Agreed, we need to address the hybrid hearing slots as well.',
        'senderAccountId': 'adv_rohit',
        'senderName': 'Rohit Verma',
        'createdAt':
            Timestamp.fromDate(now.subtract(const Duration(hours: 2))),
        'recipientCount': 4,
        'deliveredCount': 4,
        'readCount': 2,
      });

      // Conversation 4: Saket Chamber & Litigation Forum (Discoverable)
      const saketId = '11111111-2222-3333-4444-555555555554';
      final saketDoc = _firestore.collection('conversations').doc(saketId);
      await saketDoc.set({
        'id': saketId,
        'kind': 'privateGroup',
        'title': 'Saket Chamber & Litigation Forum',
        'memberIds': ['adv_kabir', 'adv_meera', 'adv_naina'],
        'membershipEpoch': 1,
        'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 5))),
        'lastMessageAt':
            Timestamp.fromDate(now.subtract(const Duration(hours: 5))),
        'lastMessagePreview':
            'Chamber brief coordination for Saket Court civil appeal.',
        'unreadCount': 0,
        'createdBy': 'adv_kabir',
        'inviteCode': 'VS-SAKET',
        'category': 'Chamber Group',
        'description':
            'Trial advocacy, cause-list coordination, and chamber updates for Saket District Court.',
        'memberCount': 18,
        'isPublic': true,
      }, SetOptions(merge: true));

      // Conversation 5: Commercial & Arbitration Bench (Discoverable)
      const arbId = '11111111-2222-3333-4444-555555555555';
      final arbDoc = _firestore.collection('conversations').doc(arbId);
      await arbDoc.set({
        'id': arbId,
        'kind': 'privateGroup',
        'title': 'Commercial & Arbitration Bench',
        'memberIds': ['adv_rohit', 'adv_naina'],
        'membershipEpoch': 1,
        'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 7))),
        'lastMessageAt':
            Timestamp.fromDate(now.subtract(const Duration(hours: 8))),
        'lastMessagePreview':
            'New draft guidelines on fast-track commercial arbitrations.',
        'unreadCount': 0,
        'createdBy': 'adv_rohit',
        'inviteCode': 'VS-ARB01',
        'category': 'Practice Forum',
        'description':
            'Commercial dispute resolution, arbitration procedures, and mediation briefs.',
        'memberCount': 45,
        'isPublic': true,
      }, SetOptions(merge: true));

      debugPrint('Firestore seed conversations complete');
    } catch (e) {
      debugPrint('Firestore seed error: $e');
    }
  }

  static List<ServerMessage> _fallbackMessagesForConversation(
    String conversationId,
    String uid,
  ) {
    final now = DateTime.now();
    final lowerId = conversationId.toLowerCase();

    if (lowerId == '11111111-2222-3333-4444-555555555551' ||
        lowerId.contains('meera')) {
      return [
        ServerMessage(
          'msg_meera_1',
          'Hello Counsel, have you reviewed the commercial arbitration draft for Delhi High Court?',
          'Meera Sharma',
          false,
          now.subtract(const Duration(hours: 2)),
          1,
          1,
          1,
          null,
          null,
          null,
          null,
          null,
          null,
          null,
          false,
          null,
          null,
        ),
        ServerMessage(
          'msg_meera_2',
          'Yes, I reviewed it. The jurisdiction clause looks solid.',
          'Anish Kumar',
          true,
          now.subtract(const Duration(hours: 1)),
          1,
          1,
          1,
          null,
          null,
          null,
          null,
          null,
          null,
          null,
          false,
          null,
          null,
        ),
        ServerMessage(
          'msg_meera_3',
          'Let me know once you go through the clause 14 provisions.',
          'Meera Sharma',
          false,
          now.subtract(const Duration(minutes: 15)),
          1,
          1,
          0,
          null,
          null,
          null,
          null,
          null,
          null,
          null,
          false,
          null,
          null,
        ),
      ];
    }

    if (lowerId == '11111111-2222-3333-4444-555555555552' ||
        lowerId.contains('kabir')) {
      return [
        ServerMessage(
          'msg_kabir_1',
          'Are you appearing before Court 3 tomorrow?',
          'Anish Kumar',
          true,
          now.subtract(const Duration(hours: 2)),
          1,
          1,
          1,
          null,
          null,
          null,
          null,
          null,
          null,
          null,
          false,
          null,
          null,
        ),
        ServerMessage(
          'msg_kabir_2',
          'Saket Court bench hearing is scheduled for tomorrow 10:30 AM.',
          'Kabir Malhotra',
          false,
          now.subtract(const Duration(minutes: 45)),
          1,
          1,
          1,
          null,
          null,
          null,
          null,
          null,
          null,
          null,
          false,
          null,
          null,
        ),
      ];
    }

    if (lowerId == '11111111-2222-3333-4444-555555555553' ||
        lowerId.contains('highcourt') ||
        lowerId.contains('delhi') ||
        lowerId.contains('bar')) {
      return [
        ServerMessage(
          'msg_grp_1',
          'Notice: The bar association meeting on digital filings is at 4 PM in library hall.',
          'Meera Sharma',
          false,
          now.subtract(const Duration(hours: 3)),
          4,
          4,
          2,
          null,
          null,
          null,
          null,
          null,
          null,
          null,
          false,
          null,
          null,
        ),
        ServerMessage(
          'msg_grp_2',
          'Agreed, we need to address the hybrid hearing slots as well.',
          'Rohit Verma',
          false,
          now.subtract(const Duration(hours: 2)),
          4,
          4,
          2,
          null,
          null,
          null,
          null,
          null,
          null,
          null,
          false,
          null,
          null,
        ),
      ];
    }

    return const [];
  }

  static final List<ConversationSummary> _fallbackConversations = [
    ConversationSummary(
      id: '11111111-2222-3333-4444-555555555551',
      kind: ConversationKind.direct,
      title: 'Meera Sharma',
      membershipEpoch: 1,
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      lastMessageAt: DateTime.now().subtract(const Duration(minutes: 15)),
      lastMessagePreview:
          'Let me know once you go through the clause 14 provisions.',
      unreadCount: 1,
    ),
    ConversationSummary(
      id: '11111111-2222-3333-4444-555555555552',
      kind: ConversationKind.direct,
      title: 'Kabir Malhotra',
      membershipEpoch: 1,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      lastMessageAt: DateTime.now().subtract(const Duration(minutes: 45)),
      lastMessagePreview:
          'Saket Court bench hearing is scheduled for tomorrow 10:30 AM.',
      unreadCount: 0,
    ),
    ConversationSummary(
      id: '11111111-2222-3333-4444-555555555553',
      kind: ConversationKind.privateGroup,
      title: 'Delhi High Court Bar Association',
      membershipEpoch: 1,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      lastMessageAt: DateTime.now().subtract(const Duration(hours: 2)),
      lastMessagePreview:
          'The bar association meeting on digital filings is at 4 PM in library hall.',
      unreadCount: 2,
    ),
    ConversationSummary(
      id: '11111111-2222-3333-4444-555555555554',
      kind: ConversationKind.privateGroup,
      title: 'Court 4 Roster & Daily Cause List',
      membershipEpoch: 1,
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      lastMessageAt: DateTime.now().subtract(const Duration(minutes: 15)),
      lastMessagePreview: 'Adv. Meera: Listed at item 14 before Court 4.',
      unreadCount: 2,
    ),
  ];
}
