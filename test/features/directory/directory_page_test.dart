import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vakilsetu/app/demo_store.dart';
import 'package:vakilsetu/core/domain/identity.dart';
import 'package:vakilsetu/features/directory/domain/directory_repository.dart';
import 'package:vakilsetu/features/directory/presentation/directory_page.dart';
import 'package:vakilsetu/features/profile/domain/advocate_profile.dart';

class _FakeDirectoryRepository implements DirectoryRepository {
  final List<AdvocateProfile> advocates;

  _FakeDirectoryRepository(this.advocates);

  @override
  Future<AdvocatePage> search({
    required String query,
    String? courtId,
    String? cursor,
  }) async {
    final clean = query.trim().toLowerCase();
    final filtered = advocates.where((a) {
      if (clean.isEmpty) return true;
      return a.fullName.toLowerCase().contains(clean) ||
          a.enrollmentNumber.toLowerCase().contains(clean);
    }).toList();
    return AdvocatePage(filtered, null);
  }
}

void main() {
  group('Directory Advocate Deduplication', () {
    test('deduplicates server advocates and demo store advocates correctly', () {
      final store = DemoStore();

      final serverAdvocates = [
        AdvocateProfile(
          id: 'adv_meera',
          fullName: 'Meera Sharma',
          enrollmentNumber: 'D/1842/2016',
          primaryCourtId: 'delhi_high_court',
          primaryCourtName: 'Delhi High Court',
          practiceAreas: 'Civil litigation · Arbitration',
          verification: VerificationStatus.verified,
        ),
        AdvocateProfile(
          id: 'adv_kabir',
          fullName: 'Kabir Malhotra',
          enrollmentNumber: 'D/0921/2018',
          primaryCourtId: 'saket_district_court',
          primaryCourtName: 'Saket District Court',
          practiceAreas: 'Civil litigation · Family law',
          verification: VerificationStatus.verified,
        ),
        AdvocateProfile(
          id: 'adv_naina',
          fullName: 'Naina Bansal',
          enrollmentNumber: 'D/2247/2019',
          primaryCourtId: 'tis_hazari_courts',
          primaryCourtName: 'Tis Hazari Courts',
          practiceAreas: 'Corporate law · Contracts',
          verification: VerificationStatus.verified,
        ),
        AdvocateProfile(
          id: 'adv_rohit',
          fullName: 'Rohit Verma',
          enrollmentNumber: 'D/1056/2015',
          primaryCourtId: 'patiala_house_courts',
          primaryCourtName: 'Patiala House Courts',
          practiceAreas: 'Criminal law · Appeals',
          verification: VerificationStatus.verified,
        ),
      ];

      final mappedServer = serverAdvocates.map((p) => DemoAdvocate(
            p.id,
            p.fullName,
            p.primaryCourtName ?? '',
            p.enrollmentNumber,
            p.practiceAreas ?? '',
            'VS',
          )).toList();

      // Combined contains 4 server items and 4 demo store items (8 total before dedup)
      final combined = [...mappedServer, ...store.advocates];
      expect(combined.length, equals(8));

      // Replicating DirectoryPage deduplication logic
      String cleanId(String id) {
        final lower = id.trim().toLowerCase();
        return lower.startsWith('adv_') ? lower.substring(4) : lower;
      }

      bool areSame(DemoAdvocate a, DemoAdvocate b) {
        final aClean = cleanId(a.id);
        final bClean = cleanId(b.id);
        if (aClean.isNotEmpty && aClean == bClean) return true;

        final aName = a.name.trim().toLowerCase();
        final bName = b.name.trim().toLowerCase();
        if (aName.isNotEmpty && aName == bName) return true;

        final aEnroll = a.enrollment.trim().toLowerCase();
        final bEnroll = b.enrollment.trim().toLowerCase();
        if (aEnroll.isNotEmpty && aEnroll == bEnroll) return true;

        return false;
      }

      final deduplicated = <DemoAdvocate>[];
      for (final item in combined) {
        if (!deduplicated.any((existing) => areSame(existing, item))) {
          deduplicated.add(item);
        }
      }

      // Must be exactly 4 unique advocates, NOT 8!
      expect(deduplicated.length, equals(4));
      // Server IDs (adv_...) are prioritized and preserved
      expect(deduplicated.map((a) => a.id).toList(), equals([
        'adv_meera',
        'adv_kabir',
        'adv_naina',
        'adv_rohit',
      ]));
    });

    testWidgets('DirectoryPage displays exactly 4 advocates without duplicates', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final store = DemoStore();
      final serverAdvocates = [
        const AdvocateProfile(
          id: 'adv_kabir',
          fullName: 'Kabir Malhotra',
          enrollmentNumber: 'D/0921/2018',
          primaryCourtId: 'saket_district_court',
          primaryCourtName: 'Saket District Court',
          practiceAreas: 'Civil litigation · Family law',
          verification: VerificationStatus.verified,
        ),
        const AdvocateProfile(
          id: 'adv_meera',
          fullName: 'Meera Sharma',
          enrollmentNumber: 'D/1842/2016',
          primaryCourtId: 'delhi_high_court',
          primaryCourtName: 'Delhi High Court',
          practiceAreas: 'Civil litigation · Arbitration',
          verification: VerificationStatus.verified,
        ),
        const AdvocateProfile(
          id: 'adv_naina',
          fullName: 'Naina Bansal',
          enrollmentNumber: 'D/2247/2019',
          primaryCourtId: 'tis_hazari_courts',
          primaryCourtName: 'Tis Hazari Courts',
          practiceAreas: 'Corporate law · Contracts',
          verification: VerificationStatus.verified,
        ),
        const AdvocateProfile(
          id: 'adv_rohit',
          fullName: 'Rohit Verma',
          enrollmentNumber: 'D/1056/2015',
          primaryCourtId: 'patiala_house_courts',
          primaryCourtName: 'Patiala House Courts',
          practiceAreas: 'Criminal law · Appeals',
          verification: VerificationStatus.verified,
        ),
      ];

      final repo = _FakeDirectoryRepository(serverAdvocates);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DirectoryPage(
              store: store,
              repository: repo,
              onMessage: (_) async {},
            ),
          ),
        ),
      );

      // Allow async _loadApi to complete
      await tester.pumpAndSettle();

      // Check header shows "4 advocates found", NOT "8 advocates found"
      expect(find.text('4 advocates found'), findsOneWidget);
      expect(find.text('8 advocates found'), findsNothing);

      // Verify each advocate name appears exactly ONCE
      expect(find.text('Kabir Malhotra'), findsOneWidget);
      expect(find.text('Meera Sharma'), findsOneWidget);
      expect(find.text('Naina Bansal'), findsOneWidget);
      expect(find.text('Rohit Verma'), findsOneWidget);
    });

    testWidgets('DirectoryPage query filters advocates properly', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final store = DemoStore();
      final serverAdvocates = [
        const AdvocateProfile(
          id: 'adv_kabir',
          fullName: 'Kabir Malhotra',
          enrollmentNumber: 'D/0921/2018',
          primaryCourtId: 'saket_district_court',
          primaryCourtName: 'Saket District Court',
          practiceAreas: 'Civil litigation · Family law',
          verification: VerificationStatus.verified,
        ),
        const AdvocateProfile(
          id: 'adv_meera',
          fullName: 'Meera Sharma',
          enrollmentNumber: 'D/1842/2016',
          primaryCourtId: 'delhi_high_court',
          primaryCourtName: 'Delhi High Court',
          practiceAreas: 'Civil litigation · Arbitration',
          verification: VerificationStatus.verified,
        ),
      ];

      final repo = _FakeDirectoryRepository(serverAdvocates);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DirectoryPage(
              store: store,
              repository: repo,
              initialQuery: 'Kabir',
              onMessage: (_) async {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('1 advocates found'), findsOneWidget);
      expect(find.text('Kabir Malhotra'), findsOneWidget);
      expect(find.text('Meera Sharma'), findsNothing);
    });

    testWidgets('DirectoryPage bookmark button toggles saved status without duplicate issues', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final store = DemoStore();
      final serverAdvocates = [
        const AdvocateProfile(
          id: 'adv_meera',
          fullName: 'Meera Sharma',
          enrollmentNumber: 'D/1842/2016',
          primaryCourtId: 'delhi_high_court',
          primaryCourtName: 'Delhi High Court',
          practiceAreas: 'Civil litigation · Arbitration',
          verification: VerificationStatus.verified,
        ),
      ];

      final repo = _FakeDirectoryRepository(serverAdvocates);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DirectoryPage(
              store: store,
              repository: repo,
              onMessage: (_) async {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Meera is initially in saved set ({'meera'}), and matches 'adv_meera'
      expect(find.byTooltip('Remove bookmark'), findsOneWidget);

      // Tap remove bookmark
      await tester.tap(find.byTooltip('Remove bookmark'));
      await tester.pumpAndSettle();

      // Now no advocate is saved
      expect(find.byTooltip('Remove bookmark'), findsNothing);

      // Tap Meera's bookmark button again (the first bookmark button)
      await tester.tap(find.byTooltip('Bookmark advocate').first);
      await tester.pumpAndSettle();

      expect(find.byTooltip('Remove bookmark'), findsOneWidget);
    });
  });
}

