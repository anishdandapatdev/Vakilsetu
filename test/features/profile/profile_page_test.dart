import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vakilsetu/app/demo_store.dart';
import 'package:vakilsetu/core/domain/identity.dart';
import 'package:vakilsetu/features/profile/domain/advocate_profile.dart';
import 'package:vakilsetu/features/profile/presentation/profile_page.dart';

class MockProfileRepository implements ProfileRepository {
  AdvocateProfile? profile;
  ProfileUpdate? lastSavedUpdate;
  Map<String, String> courtMap = {
    'Delhi High Court': 'delhi_high_court',
    'Saket District Court': 'saket_district_court',
    'Tis Hazari Courts': 'tis_hazari_courts',
  };

  MockProfileRepository({this.profile});

  @override
  Future<AdvocateProfile?> getMine() async => profile;

  @override
  Future<AdvocateProfile> save(ProfileUpdate update) async {
    lastSavedUpdate = update;
    profile = AdvocateProfile(
      id: profile?.id ?? 'mock_uid',
      fullName: update.fullName,
      enrollmentNumber: update.enrollmentNumber,
      primaryCourtId: update.primaryCourtId,
      primaryCourtName: courtMap.entries
          .firstWhere(
            (e) => e.value == update.primaryCourtId,
            orElse: () => const MapEntry('Delhi High Court', 'delhi_high_court'),
          )
          .key,
      practiceAreas: update.practiceAreas,
      bio: update.bio,
      experienceYears: update.experienceYears,
      phone: update.phone,
      chamberAddress: update.chamberAddress,
      stateBar: update.stateBar,
      verification: VerificationStatus.verified,
    );
    return profile!;
  }

  @override
  Future<Map<String, String>> listCourtIdsByName() async => courtMap;
}

void main() {
  Widget buildTestWidget({
    required DemoStore store,
    required ProfileRepository repo,
    VoidCallback? onSaved,
    VoidCallback? onSignOut,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ProfilePage(
          store: store,
          repository: repo,
          onSaved: onSaved ?? () {},
          onSignOut: onSignOut,
        ),
      ),
    );
  }

  group('ProfilePage Dynamic & Production-Level Tests', () {
    testWidgets('renders dynamic advocate information and dynamic stat cards', (tester) async {
      tester.view.physicalSize = const Size(600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final store = DemoStore();
      final mockRepo = MockProfileRepository(
        profile: const AdvocateProfile(
          id: 'test_advocate',
          fullName: 'Advocate Arjun Khanna',
          enrollmentNumber: 'D/1234/2018',
          primaryCourtId: 'saket_district_court',
          primaryCourtName: 'Saket District Court',
          practiceAreas: 'Commercial Arbitration & Civil Disputes',
          experienceYears: 8,
          phone: '+91 98765 43210',
          chamberAddress: 'Chamber 512, Lawyers Chamber Block, Saket',
          stateBar: 'Bar Council of Delhi',
          bio: 'Registered trial and appellate counsel.',
          verification: VerificationStatus.verified,
        ),
      );

      await tester.pumpWidget(buildTestWidget(store: store, repo: mockRepo));
      await tester.pumpAndSettle();

      // Verify name, enrollment and court
      expect(find.text('Advocate Arjun Khanna'), findsWidgets);
      expect(find.text('D/1234/2018'), findsWidgets);
      expect(find.text('Saket District Court'), findsWidgets);
      expect(find.text('BAR COUNCIL OF DELHI'), findsWidgets);

      // Verify dynamic stat cards: Experience, Courts, Groups
      expect(find.text('8 Years'), findsOneWidget);
      expect(find.text('${store.joined.length} Channels'), findsOneWidget);
      expect(find.text('${store.joinedGroupIds.length} Joined'), findsOneWidget);

      // Verify personal information rows
      expect(find.text('+91 98765 43210'), findsOneWidget);
      expect(find.text('Chamber 512, Lawyers Chamber Block, Saket'), findsOneWidget);
    });

    testWidgets('stat cards reactively update when store channels or groups change', (tester) async {
      tester.view.physicalSize = const Size(600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final store = DemoStore();
      final mockRepo = MockProfileRepository();

      await tester.pumpWidget(buildTestWidget(store: store, repo: mockRepo));
      await tester.pumpAndSettle();

      final initialCourtCount = store.joined.length;
      final initialGroupCount = store.joinedGroupIds.length;

      expect(find.text('$initialCourtCount Channels'), findsOneWidget);
      expect(find.text('$initialGroupCount Joined'), findsOneWidget);

      // Join an extra court channel in the store
      store.toggleCourt('Tis Hazari Courts');
      await tester.pumpAndSettle();

      expect(find.text('${initialCourtCount + 1} Channels'), findsOneWidget);

      // Leave a group in the store
      store.leaveGroup('saket');
      await tester.pumpAndSettle();

      expect(find.text('${initialGroupCount - 1} Joined'), findsOneWidget);
    });

    testWidgets('opens edit personal info sheet, updates fields, and saves to repository', (tester) async {
      tester.view.physicalSize = const Size(600, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final store = DemoStore();
      final mockRepo = MockProfileRepository(
        profile: const AdvocateProfile(
          id: 'test_advocate',
          fullName: 'Arjun Khanna',
          enrollmentNumber: 'D/1234/2018',
          primaryCourtId: 'saket_district_court',
          primaryCourtName: 'Saket District Court',
          practiceAreas: 'Civil Litigation',
          experienceYears: 7,
          phone: '+91 98101 23456',
          chamberAddress: 'Chamber 402, Saket',
          stateBar: 'Bar Council of Delhi',
          verification: VerificationStatus.verified,
        ),
      );

      bool savedCallbackCalled = false;
      await tester.pumpWidget(
        buildTestWidget(
          store: store,
          repo: mockRepo,
          onSaved: () => savedCallbackCalled = true,
        ),
      );
      await tester.pumpAndSettle();

      // Open edit sheet via the edit icon button
      final editButton = find.byTooltip('Edit Profile Information');
      expect(editButton, findsOneWidget);
      await tester.tap(editButton);
      await tester.pumpAndSettle();

      expect(find.text('Edit Personal Information'), findsOneWidget);

      // Change experience to 10 years and phone number
      final expField = find.widgetWithText(TextFormField, '7');
      expect(expField, findsOneWidget);
      await tester.enterText(expField, '10');

      final phoneField = find.widgetWithText(TextFormField, '+91 98101 23456');
      expect(phoneField, findsOneWidget);
      await tester.enterText(phoneField, '+91 99999 88888');

      // Tap save
      final saveBtn = find.text('Save Changes');
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verify sheet closed and save callback fired
      expect(savedCallbackCalled, isTrue);
      expect(mockRepo.lastSavedUpdate, isNotNull);
      expect(mockRepo.lastSavedUpdate!.experienceYears, 10);
      expect(mockRepo.lastSavedUpdate!.phone, '+91 99999 88888');

      // Verify UI updated
      expect(find.text('10 Years'), findsOneWidget);
      expect(find.text('+91 99999 88888'), findsOneWidget);
    });

    testWidgets('opens avatar appearance customizer and changes theme', (tester) async {
      tester.view.physicalSize = const Size(600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final store = DemoStore();
      final mockRepo = MockProfileRepository();

      await tester.pumpWidget(buildTestWidget(store: store, repo: mockRepo));
      await tester.pumpAndSettle();

      // Tap the avatar stack
      final cameraIcon = find.byIcon(Icons.camera_alt_rounded);
      expect(cameraIcon, findsOneWidget);
      await tester.tap(cameraIcon);
      await tester.pumpAndSettle();

      expect(find.text('Avatar Appearance'), findsOneWidget);
      expect(find.text('SELECT PALETTE PRESET'), findsOneWidget);

      // Tap the "Done" button to dismiss
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('Avatar Appearance'), findsNothing);
    });

    testWidgets('tapping credentials and chamber rows opens dedicated detail screens', (tester) async {
      tester.view.physicalSize = const Size(600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final store = DemoStore();
      final mockRepo = MockProfileRepository();

      await tester.pumpWidget(buildTestWidget(store: store, repo: mockRepo));
      await tester.pumpAndSettle();

      // Tap credentials row -> opens BarCouncilCredentialsScreen
      await tester.tap(find.text('Bar Council Credentials'));
      await tester.pumpAndSettle();

      expect(find.text('Bar Council Credentials'), findsWidgets);
      expect(find.text('REGISTRATION DETAILS'), findsOneWidget);
      expect(find.text('Digitally Verified Credential'), findsOneWidget);
      expect(find.text('Edit Bar Credentials'), findsOneWidget);

      // Dismiss / go back
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      // Tap chamber address row -> opens ChamberAddressScreen
      await tester.tap(find.text('Court & Chamber Address'));
      await tester.pumpAndSettle();

      expect(find.text('Court & Chamber Address'), findsOneWidget);
      expect(find.text('CHAMBER OFFICE DETAILS'), findsOneWidget);
      expect(find.text('PRIMARY JURISDICTION'), findsOneWidget);
      expect(find.text('Update Chamber & Contact'), findsOneWidget);

      // Dismiss / go back
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
    });

    testWidgets('account & sync status and dark mode are removed, and language screen shows only English', (tester) async {
      tester.view.physicalSize = const Size(600, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final store = DemoStore();
      final mockRepo = MockProfileRepository();

      await tester.pumpWidget(buildTestWidget(store: store, repo: mockRepo));
      await tester.pumpAndSettle();

      // Verify Account & Sync Status and Dark Mode are NOT present
      expect(find.text('Account & Sync Status'), findsNothing);
      expect(find.text('Dark Mode'), findsNothing);

      // Scroll to App Settings and find Language
      final languageRow = find.text('Language');
      expect(languageRow, findsOneWidget);

      // Tap Language row
      await tester.tap(languageRow);
      await tester.pumpAndSettle();

      // Verify AppLanguageScreen opened
      expect(find.text('App Language'), findsOneWidget);
      expect(find.text('Court & App Language'), findsOneWidget);
      expect(find.text('English (India)'), findsOneWidget);
      expect(find.text('ACTIVE'), findsOneWidget);
      expect(find.text('Confirm English (Standard)'), findsOneWidget);

      // Verify no other languages like Hindi, Marathi, etc. are listed
      expect(find.text('Hindi'), findsNothing);
      expect(find.text('Bengali'), findsNothing);

      // Tap confirm button to dismiss
      await tester.tap(find.text('Confirm English (Standard)'));
      await tester.pumpAndSettle();

      expect(find.text('Court & App Language'), findsNothing);
    });

    testWidgets('tapping log out prompts confirmation dialog', (tester) async {
      tester.view.physicalSize = const Size(600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final store = DemoStore();
      final mockRepo = MockProfileRepository();
      bool signOutCalled = false;

      await tester.pumpWidget(
        buildTestWidget(
          store: store,
          repo: mockRepo,
          onSignOut: () => signOutCalled = true,
        ),
      );
      await tester.pumpAndSettle();

      // Scroll down to Log Out button
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();

      final logOutBtn = find.widgetWithText(OutlinedButton, 'Log Out');
      expect(logOutBtn, findsOneWidget);
      await tester.tap(logOutBtn);
      await tester.pumpAndSettle();

      expect(find.text('Sign out of VakilSetu?'), findsOneWidget);

      // Tap cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(signOutCalled, isFalse);
      expect(find.text('Sign out of VakilSetu?'), findsNothing);

      // Tap log out again and confirm
      await tester.tap(logOutBtn);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Sign Out'));
      await tester.pumpAndSettle();

      expect(signOutCalled, isTrue);
    });
  });
}
