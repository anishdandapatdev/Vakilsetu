import 'dart:typed_data';

/// Keys, filenames, MIME type and thumbnails travel INSIDE encrypted messages.
/// Do not return public object URLs or place content keys in query strings.
class EncryptedAttachmentReference {
  final String opaqueObjectId;
  final int ciphertextBytes;
  const EncryptedAttachmentReference(this.opaqueObjectId, this.ciphertextBytes);
}

abstract interface class EncryptedAttachmentRepository {
  /// Accepts SDK-encrypted chunks only. Bounded streaming, resumable upload,
  /// authenticated chunk ordering and final integrity verification are required
  /// in the adapter. The interface alone cannot guarantee encrypted inputs.
  Future<EncryptedAttachmentReference> uploadCiphertext(
    Stream<Uint8List> chunks, {
    required String conversationId,
    required int membershipEpoch,
    required int ciphertextBytes,
    required String ciphertextSha256Hex,
  });
  Stream<Uint8List> downloadCiphertext(String opaqueObjectId);
  Future<void> deleteCiphertext(String opaqueObjectId);
}
