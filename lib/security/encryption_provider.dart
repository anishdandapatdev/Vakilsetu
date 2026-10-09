import 'dart:typed_data';

import '../core/domain/identity.dart';
import '../features/chats/domain/conversation.dart';

/// Opaque wire output from a vetted E2EE SDK. No plaintext serialization.
class EncryptedEnvelope {
  final String conversationId;
  final String senderDeviceId;
  final int membershipEpoch;
  final List<int> bytes;
  EncryptedEnvelope({
    required this.conversationId,
    required this.senderDeviceId,
    required this.membershipEpoch,
    required Iterable<int> bytes,
  }) : bytes = List.unmodifiable(bytes);
}

/// This boundary is NOT an encryption implementation.
/// The selected SDK owns key agreement, identity verification, ratchets,
/// replay protection, persistence and protocol-authenticated metadata.
abstract interface class EncryptionProvider {
  Future<EncryptedEnvelope> encrypt({
    required SessionIdentity sender,
    required ConversationAccess conversation,
    required Uint8List plaintext,
  });
}

/// No production fallback, global static key or base64-as-encryption.
class UnavailableEncryptionProvider implements EncryptionProvider {
  const UnavailableEncryptionProvider();
  @override
  Future<EncryptedEnvelope> encrypt({
    required SessionIdentity sender,
    required ConversationAccess conversation,
    required Uint8List plaintext,
  }) async => throw const AccessDenied('encryption_not_configured');
}
