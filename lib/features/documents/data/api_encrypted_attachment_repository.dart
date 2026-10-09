import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../authentication/data/api_auth_repository.dart';
import '../domain/encrypted_attachment_repository.dart';

class ApiEncryptedAttachmentRepository implements EncryptedAttachmentRepository {
  final ApiAuthRepository _auth;
  final http.Client _client;

  ApiEncryptedAttachmentRepository(this._auth, {http.Client? client})
    : _client = client ?? http.Client();

  @override
  Future<EncryptedAttachmentReference> uploadCiphertext(
    Stream<Uint8List> chunks, {
    required String conversationId,
    required int membershipEpoch,
    required int ciphertextBytes,
    required String ciphertextSha256Hex,
  }) async {
    if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(ciphertextSha256Hex)) {
      throw const AttachmentTransportException('invalid_ciphertext_hash');
    }
    final initiated = await _api('POST', '/conversations/$conversationId/attachments', body: {
      'membershipEpoch': membershipEpoch,
      'ciphertextSize': ciphertextBytes,
      'ciphertextSha256': ciphertextSha256Hex.toLowerCase(),
    });
    final attachmentId = initiated['attachmentId']! as String;
    final upload = initiated['upload']! as Map<String, Object?>;
    final request = http.StreamedRequest('PUT', Uri.parse(upload['url']! as String))
      ..contentLength = ciphertextBytes
      ..headers['content-type'] = 'application/octet-stream'
      ..headers['x-amz-meta-sha256'] = ciphertextSha256Hex.toLowerCase();
    await request.sink.addStream(chunks);
    await request.sink.close();
    final response = await _client.send(request).timeout(const Duration(minutes: 3));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const AttachmentTransportException('ciphertext_upload_failed');
    }
    await response.stream.drain<void>();
    await _api('POST', '/attachments/$attachmentId/complete');
    return EncryptedAttachmentReference(attachmentId, ciphertextBytes);
  }

  @override
  Stream<Uint8List> downloadCiphertext(String opaqueObjectId) async* {
    final signed = await _api('GET', '/attachments/$opaqueObjectId/download');
    final response = await _client
        .send(http.Request('GET', Uri.parse(signed['url']! as String)))
        .timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const AttachmentTransportException('ciphertext_download_failed');
    }
    await for (final chunk in response.stream) {
      yield Uint8List.fromList(chunk);
    }
  }

  @override
  Future<void> deleteCiphertext(String opaqueObjectId) async {
    await _api('DELETE', '/attachments/$opaqueObjectId');
  }

  Future<Map<String, Object?>> _api(String method, String path, {Map<String, Object?>? body}) async {
    final headers = {
      'authorization': 'Bearer ${await _auth.validAccessToken()}',
      'content-type': 'application/json',
    };
    final uri = ApiConfig.endpoint(path);
    final request = switch (method) {
      'POST' => _client.post(uri, headers: headers, body: jsonEncode(body ?? const {})),
      'DELETE' => _client.delete(uri, headers: headers),
      _ => _client.get(uri, headers: headers),
    };
    final response = await request.timeout(const Duration(seconds: 15));
    if (response.statusCode == 204) return const {};
    Object? decoded;
    try { decoded = jsonDecode(response.body); } on FormatException { decoded = null; }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map ? decoded['message']?.toString() : null;
      throw AttachmentTransportException(message ?? 'attachment_request_failed');
    }
    if (decoded is! Map<String, Object?>) {
      throw const AttachmentTransportException('invalid_server_response');
    }
    return decoded;
  }
}

class AttachmentTransportException implements Exception {
  final String code;
  const AttachmentTransportException(this.code);
  @override
  String toString() => code;
}
