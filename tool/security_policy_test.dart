import 'dart:typed_data';

import '../lib/core/domain/identity.dart';
import '../lib/features/chats/domain/conversation.dart';
import '../lib/features/chats/application/send_private_message.dart';
import '../lib/features/court_channels/domain/publishing_policy.dart';
import '../lib/features/profile/domain/advocate_profile.dart';
import '../lib/security/encryption_provider.dart';

// TEST DOUBLE ONLY. This is intentionally not a cryptographic implementation.
class FakeEncryption implements EncryptionProvider {
  bool wrongContext = false;
  int calls = 0;
  Uint8List? buffer;
  @override
  Future<EncryptedEnvelope> encrypt({
    required SessionIdentity sender,
    required ConversationAccess conversation,
    required Uint8List plaintext,
  }) async {
    calls++;
    buffer = plaintext;
    return EncryptedEnvelope(
      conversationId: wrongContext
          ? 'another-room'
          : conversation.conversationId,
      senderDeviceId: sender.deviceId,
      membershipEpoch: conversation.membershipEpoch,
      bytes: [42, 71, 99],
    );
  }
}

class FakeAuthorizer implements ConversationAuthorizer {
  bool member = true;
  bool active = true;
  @override
  Future<ConversationAccess> authorizeSend(
    SessionIdentity sender,
    String conversationId,
  ) async => ConversationAccess(
    conversationId: conversationId,
    kind: ConversationKind.privateGroup,
    memberIds: member ? [sender.userId, 'other'] : ['other'],
    membershipEpoch: 3,
    active: active,
  );
}

class FakeTransport implements EncryptedMessageTransport {
  final List<EncryptedEnvelope> delivered = [];
  @override
  Future<void> deliver(EncryptedEnvelope envelope, String id) async {
    delivered.add(envelope);
  }
}

SessionIdentity identity({
  VerificationStatus verification = VerificationStatus.verified,
  DeviceStatus device = DeviceStatus.trusted,
}) => SessionIdentity(
  userId: 'advocate-a',
  deviceId: 'device-a',
  verification: verification,
  deviceStatus: device,
);

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> denied(Future<void> Function() operation, String expected) async {
  try {
    await operation();
  } on AccessDenied catch (e) {
    check(e.code == expected, 'Expected $expected, got ${e.code}');
    return;
  }
  throw StateError('Expected denial: $expected');
}

Future<void> main() async {
  final authority = FakeAuthorizer();
  final crypto = FakeEncryption();
  final delivery = FakeTransport();
  final useCase = SendPrivateMessage(
    authorizer: authority,
    encryption: crypto,
    transport: delivery,
  );
  Future<void> send([
    SessionIdentity? sender,
    String text = 'Private petition',
  ]) => useCase.send(
    sender: sender ?? identity(),
    conversationId: 'room-a',
    clientMessageId: 'unique-message-id',
    text: text,
  );

  await denied(
    () => send(identity(verification: VerificationStatus.pending)),
    'advocate_not_verified',
  );
  await denied(
    () => send(identity(device: DeviceStatus.revoked)),
    'device_not_trusted',
  );
  check(
    crypto.calls == 0 && delivery.delivered.isEmpty,
    'Rejected identities must never reach encryption or transport',
  );

  authority.member = false;
  await denied(send, 'conversation_access_denied');
  authority.member = true;
  authority.active = false;
  await denied(send, 'conversation_access_denied');
  authority.active = true;
  await denied(() => send(null, '  '), 'invalid_message_size');
  await denied(() => send(null, 'x' * 32769), 'invalid_message_size');

  await denied(
    () =>
        SendPrivateMessage(
          authorizer: authority,
          encryption: const UnavailableEncryptionProvider(),
          transport: delivery,
        ).send(
          sender: identity(),
          conversationId: 'room-a',
          clientMessageId: 'id-2',
          text: 'Do not send plaintext',
        ),
    'encryption_not_configured',
  );
  check(
    delivery.delivered.isEmpty,
    'Missing crypto must not fall back to delivery',
  );

  crypto.wrongContext = true;
  await denied(send, 'invalid_encrypted_envelope');
  check(
    delivery.delivered.isEmpty,
    'Wrong-context output must not be delivered',
  );
  check(
    crypto.buffer!.every((b) => b == 0),
    'Temporary buffer not cleared on error',
  );
  crypto.wrongContext = false;
  await send();
  check(delivery.delivered.length == 1, 'Authorized delivery missing');
  check(
    crypto.buffer!.every((b) => b == 0),
    'Temporary buffer not cleared on success',
  );
  check(delivery.delivered.single.membershipEpoch == 3, 'Epoch not preserved');
  try {
    delivery.delivered.single.bytes.add(9);
    throw StateError('Envelope is mutable');
  } on UnsupportedError {
    /* expected */
  }

  await denied(
    () async => requireChannelPublisher(
      sender: identity(),
      channelId: 'saket',
      grant: const ChannelGrant('saket', 'advocate-a', false),
    ),
    'channel_publish_denied',
  );
  await denied(
    () async => requireChannelPublisher(
      sender: identity(),
      channelId: 'saket',
      grant: const ChannelGrant('high-court', 'advocate-a', true),
    ),
    'channel_publish_denied',
  );
  await denied(
    () async => requireChannelPublisher(
      sender: identity(),
      channelId: 'saket',
      grant: const ChannelGrant('saket', 'someone-else', true),
    ),
    'channel_publish_denied',
  );
  requireChannelPublisher(
    sender: identity(),
    channelId: 'saket',
    grant: const ChannelGrant('saket', 'advocate-a', true),
  );

  check(
    !const AdvocateProfile(
      id: 'a',
      fullName: 'Test',
      enrollmentNumber: 'D/1/2020',
      primaryCourtId: 'saket',
      verification: VerificationStatus.pending,
    ).showVerifiedBadge,
    'Pending profiles must not show verified badge',
  );

  print(
    'PASS: identity/device gates, membership, message limits, missing crypto,',
  );
  print(
    'context binding, buffer cleanup, immutable envelope, scoped publishing,',
  );
  print('and profile verification. These are policy tests, NOT proof of E2EE.');
}
