import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vakilsetu/app/demo_store.dart';
import 'package:vakilsetu/features/court_channels/domain/court_repository.dart';
import 'package:vakilsetu/features/court_channels/presentation/court_rooms_page.dart';

class _FakeCourtRepository implements CourtRepository {
  final List<CourtChannel> mockCourts;
  final Set<String> mockJoined;
  final Map<String, List<CourtAnnouncement>> mockAnnouncements;

  _FakeCourtRepository({
    List<CourtChannel>? courts,
    Set<String>? joined,
    Map<String, List<CourtAnnouncement>>? announcements,
  })  : mockCourts = courts ?? [
          const CourtChannel(
            id: 'delhi_high_court',
            channelId: 'delhi_high_court',
            name: 'Delhi High Court',
            city: 'New Delhi',
          ),
          const CourtChannel(
            id: 'saket_district_court',
            channelId: 'saket_district_court',
            name: 'Saket District Court',
            city: 'South Delhi',
          ),
          const CourtChannel(
            id: 'tis_hazari_courts',
            channelId: 'tis_hazari_courts',
            name: 'Tis Hazari Courts',
            city: 'Central Delhi',
          ),
          const CourtChannel(
            id: 'patiala_house_courts',
            channelId: 'patiala_house_courts',
            name: 'Patiala House Courts',
            city: 'New Delhi',
          ),
        ],
        mockJoined = joined ?? {'delhi_high_court', 'saket_district_court'},
        mockAnnouncements = announcements ?? {};

  @override
  Future<List<CourtChannel>> listCourts() async => mockCourts;

  @override
  Future<Set<String>> joinedCourtIds() async => mockJoined;

  @override
  Future<void> setJoined(String courtId, bool joined) async {
    if (joined) {
      mockJoined.add(courtId);
    } else {
      mockJoined.remove(courtId);
    }
  }

  @override
  Future<List<CourtAnnouncement>> announcements(String channelId) async {
    return mockAnnouncements[channelId] ??
        [
          CourtAnnouncement(
            id: 'ann_1',
            title: 'Daily Cause List - Court 1',
            body: 'Hearing starts at 10:30 AM',
            attachmentKey: 'Cause_list.pdf',
            revision: 1,
            createdAt: DateTime.now(),
          ),
        ];
  }

  @override
  Stream<List<CourtAnnouncement>>? streamAnnouncements(String channelId) => null;

  @override
  Future<void> postAnnouncement({
    required String channelId,
    required String title,
    required String body,
    String? attachmentKey,
  }) async {}
}

void main() {
  group('CourtRoomsPage Senior Designer Tests', () {
    testWidgets('Renders segmented filter chips and defaults to My Channels', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final store = DemoStore();
      final repo = _FakeCourtRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CourtRoomsPage(
              store: store,
              repository: repo,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check segmented chips
      expect(find.text('All Courts'), findsOneWidget);
      expect(find.text('My Channels'), findsOneWidget);
      expect(find.text('High Court'), findsOneWidget);
      expect(find.text('District Courts'), findsOneWidget);

      // By default, 'My Channels' is active, showing joined courts (Delhi High Court & Saket District Court)
      expect(find.text('Delhi High Court'), findsOneWidget);
      expect(find.text('Saket District Court'), findsOneWidget);

      // Switch to All Courts to view all 4
      await tester.tap(find.text('All Courts'));
      await tester.pumpAndSettle();

      expect(find.text('Tis Hazari Courts'), findsOneWidget);
      expect(find.text('Patiala House Courts'), findsOneWidget);
    });

    testWidgets('Displays Joined for subscribed courts and Join for unjoined courts in All Courts', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final store = DemoStore();
      store.joined.clear();
      store.joined.add('Delhi High Court');
      final repo = _FakeCourtRepository(
        joined: {'delhi_high_court'}, // Only Delhi High Court is joined
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CourtRoomsPage(
              store: store,
              repository: repo,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Switch to All Courts
      await tester.tap(find.text('All Courts'));
      await tester.pumpAndSettle();

      // Exactly 1 'Joined' badge and 3 'Join' buttons
      expect(find.text('Joined'), findsOneWidget);
      expect(find.text('Join'), findsNWidgets(3));
    });

    testWidgets('Tapping Join on unjoined court subscribes and updates to Joined immediately', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final store = DemoStore();
      store.joined.clear();
      store.joined.add('Delhi High Court');
      final repo = _FakeCourtRepository(
        joined: {'delhi_high_court'},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CourtRoomsPage(
              store: store,
              repository: repo,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Switch to All Courts
      await tester.tap(find.text('All Courts'));
      await tester.pumpAndSettle();

      // Tap Join on Tis Hazari Courts
      final joinButtons = find.widgetWithText(ElevatedButton, 'Join');
      expect(joinButtons, findsWidgets);

      await tester.tap(joinButtons.first);
      await tester.pumpAndSettle();

      // Now 2 courts are joined
      expect(find.text('Joined'), findsNWidgets(2));
    });

    testWidgets('Defaults to My Channels tab filtering only joined courts', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final store = DemoStore();
      store.joined.clear();
      store.joined.add('Delhi High Court');
      final repo = _FakeCourtRepository(
        joined: {'delhi_high_court'},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CourtRoomsPage(
              store: store,
              repository: repo,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Only Delhi High Court should be visible initially because My Channels is default
      expect(find.text('Delhi High Court'), findsOneWidget);
      expect(find.text('Tis Hazari Courts'), findsNothing);
      expect(find.text('Patiala House Courts'), findsNothing);
    });

    testWidgets('Tapping on a court channel card opens channel details with announcements', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final store = DemoStore();
      final repo = _FakeCourtRepository(
        announcements: {
          'delhi_high_court': [
            CourtAnnouncement(
              id: 'dhc_1',
              title: 'Daily Cause List - Court No. 1',
              body: 'Matters before Chief Justice Bench',
              attachmentKey: 'Cause_list.pdf',
              revision: 1,
              createdAt: DateTime.now(),
            ),
          ],
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CourtRoomsPage(
              store: store,
              repository: repo,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on Delhi High Court card
      await tester.tap(find.text('Delhi High Court'));
      await tester.pumpAndSettle();

      // Channel details view is open
      expect(find.text('All court channels'), findsOneWidget);
      expect(find.text('Official Forum'), findsOneWidget);
      expect(find.text('Post Notice'), findsOneWidget);
      expect(find.text('Daily Cause List - Court No. 1'), findsOneWidget);
      expect(find.text('Cause_list.pdf'), findsOneWidget);

      // Back button returns to court list
      await tester.tap(find.text('All court channels'));
      await tester.pumpAndSettle();

      expect(find.text('All Courts'), findsOneWidget);
    });
  });
}
