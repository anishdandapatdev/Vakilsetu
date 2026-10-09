enum ConversationKind { direct, privateGroup }

class ConversationAccess {
  final String conversationId;
  final ConversationKind kind;
  final Set<String> memberIds;
  final int membershipEpoch;
  final bool active;
  ConversationAccess({
    required this.conversationId,
    required this.kind,
    required Iterable<String> memberIds,
    required this.membershipEpoch,
    this.active = true,
  }) : memberIds = Set.unmodifiable(memberIds);
}

class ConversationSummary {
  final String id;
  final ConversationKind kind;
  final String title;
  final int membershipEpoch;
  final DateTime createdAt;
  final DateTime? lastMessageAt;
  final String? lastMessagePreview;
  final int unreadCount;
  const ConversationSummary({
    required this.id,
    required this.kind,
    required this.title,
    required this.membershipEpoch,
    required this.createdAt,
    this.lastMessageAt,
    this.lastMessagePreview,
    this.unreadCount = 0,
  });
}

class RecipientDevice {
  final String deviceId;
  final String publicIdentityKey;
  final String keyFingerprint;
  const RecipientDevice(
    this.deviceId,
    this.publicIdentityKey,
    this.keyFingerprint,
  );
}

class ConversationMember {
  final String accountId;
  final String? fullName;
  final String role;
  final List<RecipientDevice> devices;
  const ConversationMember({
    required this.accountId,
    required this.fullName,
    required this.role,
    required this.devices,
  });
}

class ConversationDetail {
  final ConversationAccess access;
  final String? title;
  final List<ConversationMember> members;
  const ConversationDetail(this.access, this.title, this.members);
}

class InboxEnvelope {
  final String id;
  final String conversationId;
  final String senderDeviceId;
  final int membershipEpoch;
  final String protocol;
  final List<int> ciphertext;
  final DateTime createdAt;
  const InboxEnvelope({
    required this.id,
    required this.conversationId,
    required this.senderDeviceId,
    required this.membershipEpoch,
    required this.protocol,
    required this.ciphertext,
    required this.createdAt,
  });
}

abstract interface class MessagingRepository {
  Future<List<ConversationSummary>> listConversations();
  Future<ConversationDetail> conversation(String id);
  Future<List<InboxEnvelope>> syncInbox();
  Future<void> acknowledge(List<String> envelopeIds);
  Future<void> retryPending();
  Stream<void> get syncAvailable;
  Future<void> connectRealtime();
  Future<void> close();
}

/// Conversation creation is separate from message transport so the UI can
/// support server-readable and encrypted transports without coupling them.
abstract interface class ConversationCreator {
  Future<ConversationSummary> createDirect(String peerAccountId);
  Future<ConversationSummary> createGroup(
    String title,
    List<String> memberAccountIds,
  );
}
