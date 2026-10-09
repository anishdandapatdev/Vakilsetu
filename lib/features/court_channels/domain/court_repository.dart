class CourtChannel {
  final String id;
  final String? channelId;
  final String name;
  final String city;
  final String? imageKey;

  const CourtChannel({
    required this.id,
    required this.channelId,
    required this.name,
    required this.city,
    this.imageKey,
  });
}

class CourtAnnouncement {
  final String id;
  final String body;
  final String? attachmentKey;
  final int revision;
  final DateTime createdAt;

  const CourtAnnouncement({
    required this.id,
    required this.body,
    required this.revision,
    required this.createdAt,
    this.attachmentKey,
  });
}

abstract interface class CourtRepository {
  Future<List<CourtChannel>> listCourts();
  Future<Set<String>> joinedCourtIds();
  Future<void> setJoined(String courtId, bool joined);
  Future<List<CourtAnnouncement>> announcements(String channelId);
}
