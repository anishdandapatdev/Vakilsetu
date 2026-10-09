import 'dart:convert';
import 'dart:typed_data';

import '../../../core/domain/identity.dart';
import '../../../security/encryption_provider.dart';
import '../domain/conversation.dart';

abstract interface class ConversationAuthorizer {
  /// Authenticated backend checks fresh membership, blocking and device status.
  /// Client-side guards supplement, never replace, server authorization.
  Future<ConversationAccess> authorizeSend(
    SessionIdentity sender,
    String conversationId,
  );
}

abstract interface class EncryptedMessageTransport {
  /// Server independently rechecks sender/device/current membership epoch.
  /// Atomic idempotency scope is sender + conversation + clientMessageId.
  Future<void> deliver(EncryptedEnvelope envelope, String clientMessageId);
}

class SendPrivateMessage {
  final ConversationAuthorizer authorizer;
  final EncryptionProvider encryption;
  final EncryptedMessageTransport transport;
  const SendPrivateMessage({
    required this.authorizer,
    required this.encryption,
    required this.transport,
  });

  Future<void> send({
    required SessionIdentity sender,
    required String conversationId,
    required String clientMessageId,
    required String text,
  }) async {
    requireTrustedIdentity(sender);
    if (conversationId.trim().isEmpty || clientMessageId.trim().isEmpty) {
      throw const AccessDenied('invalid_message_identity');
    }
    final encoded = utf8.encode(text);
    if (text.trim().isEmpty || encoded.length > 32768) {
      throw const AccessDenied('invalid_message_size');
    }
    final access = await authorizer.authorizeSend(sender, conversationId);
    if (!access.active ||
        access.conversationId != conversationId ||
        !access.memberIds.contains(sender.userId) ||
        access.membershipEpoch < 0 ||
        (access.kind == ConversationKind.direct &&
            access.memberIds.length != 2)) {
      throw const AccessDenied('conversation_access_denied');
    }
    final plaintext = Uint8List.fromList(encoded);
    try {
      final envelope = await encryption.encrypt(
        sender: sender,
        conversation: access,
        plaintext: plaintext,
      );
      if (envelope.bytes.isEmpty ||
          envelope.conversationId != conversationId ||
          envelope.senderDeviceId != sender.deviceId ||
          envelope.membershipEpoch != access.membershipEpoch) {
        throw const AccessDenied('invalid_encrypted_envelope');
      }
      await transport.deliver(envelope, clientMessageId);
    } finally {
      plaintext.fillRange(0, plaintext.length, 0);
      // Best effort only: Dart strings/GC copies cannot be securely zeroized.
    }
  }
}
