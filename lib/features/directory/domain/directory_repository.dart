import '../../profile/domain/advocate_profile.dart';

class AdvocatePage {
  final List<AdvocateProfile> items;
  final String? nextCursor;
  AdvocatePage(Iterable<AdvocateProfile> items, this.nextCursor)
    : items = List.unmodifiable(items);
}

abstract interface class DirectoryRepository {
  /// Return approved public fields only, never phone numbers or key material.
  Future<AdvocatePage> search({
    required String query,
    String? courtId,
    String? cursor,
  });
}
