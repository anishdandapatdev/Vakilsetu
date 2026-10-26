import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vakilsetu/app/demo_store.dart';
import 'package:vakilsetu/features/private_groups/presentation/groups_page.dart';

void main() {
  group('GroupsPage Senior Designer Tests', () {
    testWidgets('Renders segmented filter chips with My Groups as default', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final store = DemoStore();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroupsPage(
              store: store,
              onOpen: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check segmented tabs
      expect(find.text('My Groups'), findsOneWidget);
      expect(find.text('Explore Groups'), findsOneWidget);

      // Check Quick Action buttons
      expect(find.text('Join via Code'), findsOneWidget);
      expect(find.text('Create Group'), findsOneWidget);

      // Verify default My Groups tab displays the user's initial joined groups
      expect(find.text('Saket Chamber'), findsOneWidget);
      expect(find.text('Research Team'), findsOneWidget);
      expect(find.text('High Court Juniors'), findsOneWidget);

      // Verify unjoined explore groups are not shown in My Groups tab
      expect(find.text('Delhi High Court Bar Association'), findsNothing);
    });

    testWidgets('Switching to Explore Groups displays discoverable groups with Join buttons', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final store = DemoStore();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroupsPage(
              store: store,
              onOpen: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Switch to Explore Groups tab
      await tester.tap(find.text('Explore Groups'));
      await tester.pumpAndSettle();

      // Discoverable open groups should be visible
      expect(find.text('Delhi High Court Bar Association'), findsOneWidget);
      expect(find.text('Commercial & Arbitration Bench'), findsOneWidget);
      expect(find.text('Tax & Corporate Legal Society'), findsOneWidget);

      // In Explore, each unjoined group should have a 'Join Group' button
      expect(find.text('Join Group'), findsWidgets);
    });

    testWidgets('Tapping Join Group on Explore tab enrolls advocate into group', (tester) async {
      tester.view.physicalSize = const Size(500, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final store = DemoStore();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroupsPage(
              store: store,
              onOpen: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Switch to Explore Groups
      await tester.tap(find.text('Explore Groups'));
      await tester.pumpAndSettle();

      // Tap 'Join Group' on the first unjoined card (Delhi High Court Bar Association)
      final joinButtons = find.text('Join Group');
      expect(joinButtons, findsWidgets);

      await tester.tap(joinButtons.first);
      await tester.pumpAndSettle();

      // Switch back to My Groups
      await tester.tap(find.text('My Groups'));
      await tester.pumpAndSettle();

      // Now Delhi High Court Bar Association is in My Groups!
      expect(find.text('Delhi High Court Bar Association'), findsOneWidget);
    });

    testWidgets('Joining group via Join with Code dialog resolves invite code and opens group', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final store = DemoStore();
      DemoRoom? openedRoom;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroupsPage(
              store: store,
              onOpen: (room) => openedRoom = room,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap 'Join via Code'
      await tester.tap(find.text('Join via Code'));
      await tester.pumpAndSettle();

      expect(find.text('Join with Code'), findsOneWidget);

      // Enter code for 'Tax & Corporate Legal Society' (VS-TAX99) in dialog
      final dialogField = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(dialogField, 'VS-TAX99');
      await tester.pumpAndSettle();

      // Verify preview card rendered with title
      expect(find.text('Tax & Corporate Legal Society'), findsOneWidget);

      // Tap 'Join Group' in modal
      await tester.tap(find.widgetWithText(FilledButton, 'Join Group'));
      await tester.pumpAndSettle();

      // Modal closed and openedRoom is Tax Society
      expect(openedRoom, isNotNull);
      expect(openedRoom!.name, 'Tax & Corporate Legal Society');
    });

    testWidgets('Creating a group via Create Group sheet creates and opens new chamber group', (tester) async {
      tester.view.physicalSize = const Size(500, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final store = DemoStore();
      DemoRoom? openedRoom;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroupsPage(
              store: store,
              onOpen: (room) => openedRoom = room,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap 'Create Group'
      await tester.tap(find.text('Create Group'));
      await tester.pumpAndSettle();

      expect(find.text('Create Private Group'), findsOneWidget);

      // Enter group title
      final titleField = find.widgetWithText(TextField, 'e.g. Saket Chamber Litigation Forum');
      await tester.enterText(titleField, 'Supreme Court Appellate Guild');
      await tester.pumpAndSettle();

      // Select 'Practice Forum' category chip
      await tester.tap(find.widgetWithText(ChoiceChip, 'Practice Forum'));
      await tester.pumpAndSettle();

      // Select Meera Sharma from colleagues
      await tester.tap(find.text('Meera Sharma'));
      await tester.pumpAndSettle();

      // Tap 'Create & Open Group'
      await tester.tap(find.text('Create & Open Group'));
      await tester.pumpAndSettle();

      // Group created and opened!
      expect(openedRoom, isNotNull);
      expect(openedRoom!.name, 'Supreme Court Appellate Guild');
      expect(openedRoom!.category, 'Practice Forum');
    });

    testWidgets('Viewing group details and leaving a group removes it from My Groups', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final store = DemoStore();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroupsPage(
              store: store,
              onOpen: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap info button on the first group card (Saket Chamber)
      final infoButtons = find.byIcon(Icons.info_outline_rounded);
      expect(infoButtons, findsWidgets);

      await tester.tap(infoButtons.first);
      await tester.pumpAndSettle();

      // Group details sheet is shown
      expect(find.text('About Group'), findsOneWidget);
      expect(find.text('Leave'), findsOneWidget);
      expect(find.text('Open Chat'), findsOneWidget);

      // Tap Leave
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();

      // Confirmation dialog is shown
      expect(find.text('Leave Group?'), findsOneWidget);

      // Confirm Leave
      await tester.tap(find.widgetWithText(FilledButton, 'Leave Group'));
      await tester.pumpAndSettle();

      // Saket Chamber is removed from My Groups!
      expect(find.text('Saket Chamber'), findsNothing);
    });
  });
}
