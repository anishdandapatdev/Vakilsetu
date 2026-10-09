import '../../../core/domain/identity.dart';

/// Grants must come from server authority, not client-supplied role flags.
class ChannelGrant {
  final String channelId;
  final String userId;
  final bool mayPublish;
  const ChannelGrant(this.channelId, this.userId, this.mayPublish);
}

void requireChannelPublisher({
  required SessionIdentity sender,
  required String channelId,
  required ChannelGrant grant,
}) {
  requireTrustedIdentity(sender);
  if (channelId.trim().isEmpty ||
      grant.channelId != channelId ||
      grant.userId != sender.userId ||
      !grant.mayPublish) {
    throw const AccessDenied('channel_publish_denied');
  }
}
