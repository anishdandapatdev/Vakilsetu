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
        ServerMessaging,
        ConversationAuthorizer,
        EncryptedMessageTransport {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  final StreamController<void> _syncEvents = StreamController<void>.broadcast();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _conversationsSub;
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
      _messageSubs = {};
  bool _seeded = false;

  FirestoreMessagingRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

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
        final unread = (data['unreadCount'] as num?)?.toInt() ?? 0;
        final title = (data['title'] as String?)?.isNotEmpty == true
            ? data['title'] as String
            : (isGroup ? 'Private Group' : 'Advocate');

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
        );
      }).toList();

      list.sort((a, b) {
        final aTime = a.lastMessageAt ?? a.createdAt;
        final bTime = b.lastMessageAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });

      return list;
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
        final title = data['title'] as String?;
        final epoch = (data['membershipEpoch'] as num?)?.toInt() ?? 1;

        final members = memberIds.map((mId) {
          return ConversationMember(
            accountId: mId,
            fullName: mId == _currentUserId ? _currentUserName : 'Advocate',
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
          if (members.contains(peerAccountId)) {
            final title =
                data['title'] as String? ?? 'Private Conversation';
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

      // 2. Fetch peer advocate details for title
      String peerTitle = 'Advocate';
      try {
        final advDoc =
            await _firestore.collection('advocates').doc(peerAccountId).get();
        if (advDoc.exists) {
          peerTitle = advDoc.data()?['fullName'] as String? ?? 'Advocate';
        } else {
          final userDoc =
              await _firestore.collection('users').doc(peerAccountId).get();
          if (userDoc.exists) {
            peerTitle = userDoc.data()?['fullName'] as String? ?? 'Advocate';
          }
        }
      } catch (_) {}

      // 3. Create new direct conversation document
      final id = _generateUuid();
      final now = FieldValue.serverTimestamp();
      final data = {
        'id': id,
        'kind': 'direct',
        'title': peerTitle,
        'memberIds': [uid, peerAccountId],
        'membershipEpoch': 1,
        'createdAt': now,
        'lastMessageAt': now,
        'lastMessagePreview': 'Conversation started',
        'unreadCount': 0,
        'createdBy': uid,
      };

      await _firestore.collection('conversations').doc(id).set(data);
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
      return ConversationSummary(
        id: fallbackId,
        kind: ConversationKind.direct,
        title: 'Advocate',
        membershipEpoch: 1,
        createdAt: DateTime.now(),
      );
    }
  }

  @override
  Future<ConversationSummary> createGroup(
    String title,
    List<String> memberAccountIds,
  ) async {
    final uid = _currentUserId;
    final allMembers = {uid, ...memberAccountIds}.toList();
    final id = _generateUuid();
    final now = FieldValue.serverTimestamp();

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
    };

    await _firestore.collection('conversations').doc(id).set(data);
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
    );
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

    await _firestore.collection('conversations').doc(conversationId).set({
      'lastMessagePreview':
          body.isNotEmpty ? body : (attachmentName ?? 'Attachment'),
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': uid,
    }, SetOptions(merge: true));

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
    try {
      await _firestore.collection('conversations').doc(conversationId).update({
        'unreadCount': 0,
      });

      final snapshot = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .where('senderAccountId', isNotEqualTo: _currentUserId)
          .limit(20)
          .get();

      for (final doc in snapshot.docs) {
        if ((doc.data()['readCount'] as num? ?? 0) == 0) {
          doc.reference.update({'readCount': 1});
        }
      }
    } catch (_) {}
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

    await _firestore.collection('attachments').doc(attachmentId).set({
      'id': attachmentId,
      'conversationId': conversationId,
      'filename': filename,
      'contentType': contentType,
      'byteSize': bytes.length,
      'dataBase64': base64Data,
      'createdAt': FieldValue.serverTimestamp(),
      'uploaderId': _currentUserId,
    });

    return attachmentId;
  }

  @override
  Future<List<int>> downloadAttachment(String attachmentId) async {
    final doc =
        await _firestore.collection('attachments').doc(attachmentId).get();
    if (!doc.exists) throw Exception('attachment_not_found');
    final base64Data = doc.data()!['dataBase64'] as String;
    return base64Decode(base64Data);
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
          conversationTitle: 'Document Attachment',
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
        'memberIds': [uid, 'adv_meera'],
        'membershipEpoch': 1,
        'createdAt': Timestamp.fromDate(now.subtract(const Duration(hours: 3))),
        'lastMessageAt':
            Timestamp.fromDate(now.subtract(const Duration(minutes: 15))),
        'lastMessagePreview':
            'Let me know once you go through the clause 14 provisions.',
        'unreadCount': 1,
        'createdBy': 'adv_meera',
      });

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
        'memberIds': [uid, 'adv_kabir'],
        'membershipEpoch': 1,
        'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 1))),
        'lastMessageAt':
            Timestamp.fromDate(now.subtract(const Duration(minutes: 45))),
        'lastMessagePreview':
            'Saket Court bench hearing is scheduled for tomorrow 10:30 AM.',
        'unreadCount': 0,
        'createdBy': 'adv_kabir',
      });

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
        'memberIds': [uid, 'adv_meera', 'adv_kabir', 'adv_rohit'],
        'membershipEpoch': 1,
        'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 3))),
        'lastMessageAt':
            Timestamp.fromDate(now.subtract(const Duration(hours: 2))),
        'lastMessagePreview':
            'The bar association meeting on digital filings is at 4 PM in library hall.',
        'unreadCount': 2,
        'createdBy': 'adv_meera',
      });

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

      debugPrint('Firestore seed conversations complete');
    } catch (e) {
      debugPrint('Firestore seed error: $e');
    }
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
  ];
}
