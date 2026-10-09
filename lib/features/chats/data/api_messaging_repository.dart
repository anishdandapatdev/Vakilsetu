import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../core/config/api_config.dart';
import '../../../security/encryption_provider.dart';
import '../../authentication/data/api_auth_repository.dart';
import '../application/send_private_message.dart';
import '../domain/conversation.dart';
import '../domain/server_messaging.dart';

class ApiMessagingRepository
    implements
        MessagingRepository,
        ConversationCreator,
        ServerMessaging,
        ConversationAuthorizer,
        EncryptedMessageTransport {
  @override
  Future<SharedAttachmentPage> sharedAttachments({
    String? before,
    String search = '',
    String kind = 'all',
  }) async {
    final query = Uri(
      queryParameters: {
        if (before != null) 'before': before,
        if (search.isNotEmpty) 'search': search,
        'kind': kind,
      },
    ).query;
    final response = await _request('GET', '/server-attachments?$query');
    final items = (response['items'] as List).map((raw) {
      final item = raw as Map<String, Object?>;
      return SharedAttachment(
        id: item['id']! as String,
        messageId: item['messageId']! as String,
        conversationId: item['conversationId']! as String,
        conversationTitle: item['conversationTitle']! as String,
        filename: item['filename']! as String,
        contentType: item['contentType']! as String,
        byteSize: (item['byteSize'] as num).toInt(),
        createdAt: DateTime.parse(item['createdAt']! as String),
      );
    }).toList();
    return SharedAttachmentPage(items, response['nextCursor'] as String?);
  }

  @override
  Future<ServerMessagePage> history(
    String conversationId, {
    String? before,
  }) async {
    final session = await _auth.restoreSession();
    if (session == null) throw const AuthenticationException('session_missing');
    final response = await _request(
      'GET',
      '/conversations/$conversationId/messages${before == null ? '' : '?before=${Uri.encodeQueryComponent(before)}'}',
    );
    final items = (response['items'] as List)
        .map(
          (item) => ServerMessage(
            item['id'] as String,
            item['body'] as String? ?? '',
            item['senderName'] as String? ?? 'Advocate',
            item['senderAccountId'] == session.userId,
            DateTime.parse(item['createdAt'] as String),
            item['recipientCount'] == null ? 0 : (item['recipientCount'] as num).toInt(),
            item['deliveredCount'] == null ? 0 : (item['deliveredCount'] as num).toInt(),
            item['readCount'] == null ? 0 : (item['readCount'] as num).toInt(),
            item['attachmentId'] as String?,
            item['attachmentName'] as String?,
            item['attachmentContentType'] as String?,
            (item['attachmentBytes'] as num?)?.toInt(),
            item['replyToMessageId'] as String?,
            item['replyBody'] as String?,
            item['replySenderName'] as String?,
            item['replyDeleted'] as bool? ?? false,
            item['editedAt'] == null
                ? null
                : DateTime.parse(item['editedAt'] as String),
            item['deletedAt'] == null
                ? null
                : DateTime.parse(item['deletedAt'] as String),
          ),
        )
        .toList();
    return ServerMessagePage(items, response['nextCursor'] as String?);
  }

  @override
  Future<void> markRead(String conversationId, String throughMessageId) async {
    await _request(
      'POST',
      '/conversations/$conversationId/messages/read',
      body: {'throughMessageId': throughMessageId},
    );
  }

  @override
  Future<void> sendText(
    String conversationId,
    String clientMessageId,
    String body, {
    String? attachmentId,
    String? replyToMessageId,
  }) async {
    final pending = <String, Object?>{
      'conversationId': conversationId,
      'clientMessageId': clientMessageId,
      'body': body,
      if (attachmentId != null) 'attachmentId': attachmentId,
      if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
    };
    await _mutateServerPending((items) {
      if (items.any((item) => item['clientMessageId'] == clientMessageId)) {
        return;
      }
      if (items.length >= 500) {
        throw const AuthenticationException('message_outbox_full');
      }
      items.add(pending);
    });
    await _sendServerPending(pending);
    await _removeServerPending(clientMessageId);
  }

  @override
  Future<void> editMessage(
    String conversationId,
    String messageId,
    String body,
  ) => _request(
    'PATCH',
    '/conversations/$conversationId/messages/$messageId',
    body: {'body': body},
  ).then((_) {});

  @override
  Future<void> deleteMessage(String conversationId, String messageId) =>
      _request(
        'DELETE',
        '/conversations/$conversationId/messages/$messageId',
      ).then((_) {});

  @override
  Future<String> uploadAttachment(
    String conversationId,
    String filename,
    String contentType,
    List<int> bytes,
  ) async {
    final digest = sha256.convert(bytes);
    final hash = digest.toString();
    final initiated = await _request(
      'POST',
      '/conversations/$conversationId/server-attachments',
      body: {
        'filename': filename,
        'contentType': contentType,
        'byteSize': bytes.length,
        'sha256': hash,
      },
    );
    final attachmentId = initiated['attachmentId']! as String;
    final upload = initiated['upload']! as Map<String, Object?>;
    final response = await _client
        .put(
          Uri.parse(upload['url']! as String),
          // The presigned URL already contains the checksum and metadata.
          // Sending them again as unsigned x-amz headers is rejected by MinIO.
          headers: {'content-type': contentType},
          body: bytes,
        )
        .timeout(const Duration(minutes: 3));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const AuthenticationException('attachment_upload_failed');
    }
    await _request('POST', '/server-attachments/$attachmentId/complete');
    return attachmentId;
  }

  @override
  Future<List<int>> downloadAttachment(String attachmentId) async {
    final signed = await _request(
      'GET',
      '/server-attachments/$attachmentId/download',
    );
    final response = await _client
        .get(Uri.parse(signed['url']! as String))
        .timeout(const Duration(minutes: 2));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const AuthenticationException('attachment_download_failed');
    }
    return response.bodyBytes;
  }

  static const _cursorKey = 'vakilsetu.inbox.cursor.v1';
  static const _pendingKey = 'vakilsetu.envelopes.pending.v1';
  static const _serverPendingKey = 'vakilsetu.server_messages.pending.v1';

  final ApiAuthRepository _auth;
  final http.Client _client;
  final FlutterSecureStorage _storage;
  final StreamController<void> _syncEvents = StreamController<void>.broadcast();
  Future<void> _serverOutboxTail = Future<void>.value();
  io.Socket? _socket;

  ApiMessagingRepository(
    this._auth, {
    http.Client? client,
    FlutterSecureStorage? storage,
  }) : _client = client ?? http.Client(),
       _storage = storage ?? const FlutterSecureStorage();

  @override
  Stream<void> get syncAvailable => _syncEvents.stream;

  Future<ConversationSummary> _createdConversation(
    String path,
    Map<String, Object?> body,
  ) async {
    final result = await _request('POST', path, body: body);
    final id = result['conversationId']! as String;
    final summaries = await listConversations();
    final match = summaries.where((item) => item.id == id);
    if (match.isNotEmpty) return match.first;
    final detail = await conversation(id);
    return ConversationSummary(
      id: id,
      kind: detail.access.kind,
      title: detail.title ?? 'Private conversation',
      membershipEpoch: detail.access.membershipEpoch,
      createdAt: DateTime.now(),
      unreadCount: 0,
    );
  }

  @override
  Future<ConversationSummary> createDirect(String peerAccountId) =>
      _createdConversation('/conversations/direct', {
        'peerAccountId': peerAccountId,
      });

  @override
  Future<ConversationSummary> createGroup(
    String title,
    List<String> memberAccountIds,
  ) => _createdConversation('/conversations/groups', {
    'title': title,
    'memberAccountIds': memberAccountIds,
  });

  @override
  Future<List<ConversationSummary>> listConversations() async {
    final json = await _request('GET', '/conversations');
    return (json['items']! as List<Object?>)
        .cast<Map<String, Object?>>()
        .map(
          (item) => ConversationSummary(
            id: item['id']! as String,
            kind: item['kind'] == 'private_group'
                ? ConversationKind.privateGroup
                : ConversationKind.direct,
            title: item['title']! as String,
            membershipEpoch: (item['membershipEpoch'] as num?)?.toInt() ?? 1,
            createdAt: DateTime.parse(item['createdAt']! as String),
            lastMessageAt: item['lastMessageAt'] == null
                ? null
                : DateTime.parse(item['lastMessageAt']! as String),
            lastMessagePreview: item['lastMessagePreview'] as String?,
            unreadCount: (item['unreadCount'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<ConversationDetail> conversation(String id) async {
    final json = await _request('GET', '/conversations/$id');
    final members = (json['members']! as List<Object?>)
        .cast<Map<String, Object?>>()
        .map((member) {
          final devices = (member['devices']! as List<Object?>)
              .cast<Map<String, Object?>>()
              .map(
                (device) => RecipientDevice(
                  device['deviceId']! as String,
                  device['publicIdentityKey']! as String,
                  device['keyFingerprint']! as String,
                ),
              )
              .toList(growable: false);
          return ConversationMember(
            accountId: member['accountId']! as String,
            fullName: member['fullName'] as String?,
            role: member['role']! as String,
            devices: devices,
          );
        })
        .toList(growable: false);
    return ConversationDetail(
      ConversationAccess(
        conversationId: json['id']! as String,
        kind: json['kind'] == 'private_group'
            ? ConversationKind.privateGroup
            : ConversationKind.direct,
        memberIds: members.map((member) => member.accountId),
        membershipEpoch: (json['membershipEpoch'] as num?)?.toInt() ?? 1,
      ),
      json['title'] as String?,
      members,
    );
  }

  @override
  Future<ConversationAccess> authorizeSend(
    sender,
    String conversationId,
  ) async => (await conversation(conversationId)).access;

  @override
  Future<void> deliver(
    EncryptedEnvelope envelope,
    String clientMessageId,
  ) async {
    final detail = await conversation(envelope.conversationId);
    final sender = await _auth.restoreSession();
    if (sender == null) throw const AuthenticationException('session_missing');
    final recipients = detail.members
        .where((member) => member.accountId != sender.userId)
        .expand((member) => member.devices)
        .toList();
    if (recipients.isEmpty)
      throw const AuthenticationException('trusted_recipient_device_missing');
    for (final device in recipients) {
      final pending = <String, Object?>{
        'conversationId': envelope.conversationId,
        'clientMessageId': clientMessageId,
        'recipientDeviceId': device.deviceId,
        'membershipEpoch': envelope.membershipEpoch,
        'protocol': const String.fromEnvironment(
          'E2EE_PROTOCOL',
          defaultValue: 'disabled',
        ),
        'ciphertext': base64Encode(envelope.bytes),
      };
      try {
        await _request('POST', '/private-messages/envelopes', body: pending);
      } on Object {
        await _enqueue(pending);
        rethrow;
      }
    }
  }

  @override
  Future<List<InboxEnvelope>> syncInbox() async {
    final cursor = await _storage.read(key: _cursorKey);
    final query = cursor == null
        ? ''
        : '?after=${Uri.encodeQueryComponent(cursor)}';
    final json = await _request('GET', '/inbox$query');
    final items = (json['items']! as List<Object?>)
        .cast<Map<String, Object?>>()
        .map(
          (item) => InboxEnvelope(
            id: item['id']! as String,
            conversationId: item['conversationId']! as String,
            senderDeviceId: item['senderDeviceId']! as String,
            membershipEpoch: (item['membershipEpoch'] as num?)?.toInt() ?? 1,
            protocol: item['protocol']! as String,
            ciphertext: base64Decode(item['ciphertext']! as String),
            createdAt: DateTime.parse(item['createdAt']! as String),
          ),
        )
        .toList(growable: false);
    return items;
  }

  @override
  Future<void> acknowledge(List<String> envelopeIds) async {
    if (envelopeIds.isEmpty) return;
    await _request(
      'POST',
      '/inbox/acknowledgements',
      body: {'envelopeIds': envelopeIds},
    );
    // Advance only after the caller has successfully authenticated/decrypted and
    // durably stored every envelope in this ordered batch.
    await _storage.write(key: _cursorKey, value: envelopeIds.last);
  }

  @override
  Future<void> retryPending() async {
    final pending = await _readPending();
    final remaining = <Map<String, Object?>>[];
    for (final envelope in pending) {
      try {
        await _request('POST', '/private-messages/envelopes', body: envelope);
      } on Object {
        remaining.add(envelope);
      }
    }
    await _writePending(remaining);

    final serverMessages = await _serverPendingSnapshot();
    var deliveredAny = false;
    for (final message in serverMessages) {
      try {
        await _sendServerPending(message);
        await _removeServerPending(message['clientMessageId']! as String);
        deliveredAny = true;
      } on Object {
        // Retain each failed item with its original idempotency key.
      }
    }
    if (deliveredAny) _syncEvents.add(null);
  }

  @override
  Future<void> connectRealtime() async {
    await _socket?.close();
    final token = await _auth.validAccessToken();
    final api = Uri.parse(ApiConfig.baseUrl);
    final origin =
        '${api.scheme}://${api.host}${api.hasPort ? ':${api.port}' : ''}';
    final socket = io.io(
      '$origin/realtime',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'accessToken': token})
          .disableAutoConnect()
          .enableReconnection()
          .build(),
    );
    socket.on('sync:available', (_) => _syncEvents.add(null));
    socket.onConnect((_) => retryPending());
    socket.connect();
    _socket = socket;
  }

  Future<Map<String, Object?>> _request(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    final token = await _auth.validAccessToken();
    final headers = {
      'authorization': 'Bearer $token',
      'content-type': 'application/json',
    };
    final uri = ApiConfig.endpoint(path);
    final request = switch (method) {
      'POST' => _client.post(uri, headers: headers, body: jsonEncode(body)),
      'PATCH' => _client.patch(uri, headers: headers, body: jsonEncode(body)),
      'DELETE' => _client.delete(uri, headers: headers),
      _ => _client.get(uri, headers: headers),
    };
    final response = await request.timeout(const Duration(seconds: 12));
    Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      decoded = null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map ? decoded['message']?.toString() : null;
      throw AuthenticationException(message ?? 'messaging_request_failed');
    }
    if (response.statusCode == 204) return <String, Object?>{};
    if (decoded is! Map<String, Object?>)
      throw const AuthenticationException('invalid_server_response');
    return decoded;
  }

  Future<void> _enqueue(Map<String, Object?> envelope) async {
    final pending = await _readPending();
    final duplicate = pending.any(
      (item) =>
          item['clientMessageId'] == envelope['clientMessageId'] &&
          item['recipientDeviceId'] == envelope['recipientDeviceId'],
    );
    if (!duplicate) pending.add(envelope);
    if (pending.length > 500) pending.removeRange(0, pending.length - 500);
    await _writePending(pending);
  }

  Future<List<Map<String, Object?>>> _readPending() async {
    final encoded = await _storage.read(key: _pendingKey);
    if (encoded == null) return [];
    try {
      return (jsonDecode(encoded) as List<Object?>)
          .cast<Map<String, Object?>>();
    } on Object {
      await _storage.delete(key: _pendingKey);
      return [];
    }
  }

  Future<void> _writePending(List<Map<String, Object?>> pending) =>
      pending.isEmpty
      ? _storage.delete(key: _pendingKey)
      : _storage.write(key: _pendingKey, value: jsonEncode(pending));

  Future<void> _sendServerPending(Map<String, Object?> pending) => _request(
    'POST',
    '/conversations/${pending['conversationId']}/messages',
    body: {
      'clientMessageId': pending['clientMessageId'],
      if ((pending['body'] as String?)?.isNotEmpty == true)
        'body': pending['body'],
      if (pending['attachmentId'] != null)
        'attachmentId': pending['attachmentId'],
      if (pending['replyToMessageId'] != null)
        'replyToMessageId': pending['replyToMessageId'],
    },
  );

  Future<String> _serverPendingStorageKey() async {
    final session = await _auth.restoreSession();
    if (session == null) {
      throw const AuthenticationException('session_missing');
    }
    return '$_serverPendingKey.${session.userId}';
  }

  Future<List<Map<String, Object?>>> _readServerPending(String key) async {
    final encoded = await _storage.read(key: key);
    if (encoded == null) return [];
    try {
      return (jsonDecode(encoded) as List<Object?>)
          .cast<Map<String, Object?>>();
    } on Object {
      // Preserve the original value for recovery instead of dropping unsent text.
      throw const AuthenticationException('message_outbox_corrupted');
    }
  }

  Future<void> _writeServerPending(
    String key,
    List<Map<String, Object?>> items,
  ) async {
    if (items.isEmpty) {
      await _storage.delete(key: key);
    } else {
      await _storage.write(key: key, value: jsonEncode(items));
    }
  }

  Future<void> _mutateServerPending(
    void Function(List<Map<String, Object?>>) mutation,
  ) async {
    final key = await _serverPendingStorageKey();
    final operation = _serverOutboxTail.then((_) async {
      final items = await _readServerPending(key);
      mutation(items);
      await _writeServerPending(key, items);
    });
    _serverOutboxTail = operation.catchError((_) {});
    return operation;
  }

  Future<List<Map<String, Object?>>> _serverPendingSnapshot() async {
    final key = await _serverPendingStorageKey();
    await _serverOutboxTail;
    return _readServerPending(key);
  }

  Future<void> _removeServerPending(String clientMessageId) =>
      _mutateServerPending(
        (items) => items.removeWhere(
          (item) => item['clientMessageId'] == clientMessageId,
        ),
      );

  @override
  Future<void> close() async {
    _socket?.dispose();
    await _syncEvents.close();
    _client.close();
  }
}
