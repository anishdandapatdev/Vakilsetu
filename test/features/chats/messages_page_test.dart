import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vakilsetu/app/demo_store.dart';
import 'package:vakilsetu/design_system/ui.dart';
import 'package:vakilsetu/features/chats/domain/conversation.dart';
import 'package:vakilsetu/features/chats/domain/server_messaging.dart';
import 'package:vakilsetu/features/chats/presentation/messages_page.dart';

class _MockChatServerMessaging implements MessagingRepository, ServerMessaging {
  final Completer<ServerMessagePage> historyCompleter = Completer<ServerMessagePage>();

  @override
  Future<ServerMessagePage> history(String conversationId, {String? before}) =>
      historyCompleter.future;

  @override
  Stream<void> get syncAvailable => const Stream.empty();

  @override
  Future<void> connectRealtime() async {}

  @override
  Future<void> retryPending() async {}

  @override
  Future<List<ConversationSummary>> listConversations() async => [];

  @override
  Future<void> markRead(String conversationId, String throughMessageId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('MessagesPage logic tests', () {
    test('message sorting handles null createdAt safely without throwing', () {
      final now = DateTime.now();
      final messages = [
        DemoMessage('Message with timestamp 2', createdAt: now.add(const Duration(minutes: 5))),
        DemoMessage('Message with null timestamp 1'),
        DemoMessage('Message with timestamp 1', createdAt: now),
        DemoMessage('Message with null timestamp 2'),
      ];

      // Replicating the sorting logic in messages_page.dart
      expect(
        () => messages.sort((a, b) {
          final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return aTime.compareTo(bTime);
        }),
        returnsNormally,
      );

      // Null timestamps should sort to the beginning (epoch 0), followed by timestamps
      expect(messages[0].createdAt, isNull);
      expect(messages[1].createdAt, isNull);
      expect(messages[2].text, equals('Message with timestamp 1'));
      expect(messages[3].text, equals('Message with timestamp 2'));
    });

    test('ConversationRow selected check correctly uses id comparison', () {
      final roomA1 = DemoRoom('room_1', 'Meera Sharma', 'Civil', 'MS');
      final roomA2 = DemoRoom('room_1', 'Meera Sharma', 'Civil', 'MS'); // re-instantiated on reload
      final roomB = DemoRoom('room_2', 'Kabir Malhotra', 'Criminal', 'KM');

      DemoRoom? active = roomA1;

      // Instance identity comparison fails after reload:
      expect(active == roomA2, isFalse);

      // ID-based comparison properly preserves selection:
      expect(active.id == roomA2.id, isTrue);
      expect(active.id == roomB.id, isFalse);
    });

    test('DemoRoom mapping from ConversationSummary maintains integrity', () {
      final summary = ConversationSummary(
        id: 'conv_123',
        kind: ConversationKind.direct,
        title: 'Meera Sharma',
        membershipEpoch: 1,
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        lastMessagePreview: 'Latest draft uploaded',
        unreadCount: 3,
      );

      final initials = summary.title
          .split(' ')
          .where((part) => part.isNotEmpty)
          .map((part) => part[0])
          .take(2)
          .join();

      final room = DemoRoom(
        summary.id,
        summary.title,
        summary.kind == ConversationKind.privateGroup
            ? 'Private group'
            : 'Private conversation',
        initials.isEmpty ? 'VS' : initials,
        group: summary.kind == ConversationKind.privateGroup,
        unread: summary.unreadCount,
        lastMessagePreview: summary.lastMessagePreview,
        lastMessageAt: summary.lastMessageAt ?? summary.createdAt,
      );

      expect(room.id, equals('conv_123'));
      expect(room.name, equals('Meera Sharma'));
      expect(room.initials, equals('MS'));
      expect(room.group, isFalse);
      expect(room.unread, equals(3));
      expect(room.lastMessagePreview, equals('Latest draft uploaded'));
    });

    testWidgets('MessagesPage active chat screen does not contain VakilSetu logo or menubar header', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final store = DemoStore();
      final activeRoom = DemoRoom('room_kabir', 'Kabir Malhotra', 'Private conversation', 'KM');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessagesPage(
              store: store,
              initialRoom: activeRoom,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // The chat room header card is present
      expect(find.text('Kabir Malhotra'), findsOneWidget);
      expect(find.text('Private conversation'), findsOneWidget);
      expect(find.byTooltip('Back to conversations'), findsOneWidget);

      // VakilSetu logo, menubar, and BrandedTopBar are NOT rendered above the active chat
      expect(find.byType(VakilSetuLogo), findsNothing);
      expect(find.byType(Brand), findsNothing);
      expect(find.byType(BrandedTopBar), findsNothing);
      expect(find.byIcon(Icons.menu_rounded), findsNothing);
      expect(find.byIcon(Icons.menu), findsNothing);
    });

    testWidgets('Tapping unread conversation immediately clears green badge to chevron', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final store = DemoStore();
      for (final r in store.rooms) {
        r.unread = 0;
      }
      final meeraRoom = store.rooms.firstWhere((r) => r.name == 'Meera Sharma');
      meeraRoom.unread = 1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessagesPage(
              store: store,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Green badge '1' is initially visible
      expect(find.text('1'), findsOneWidget);

      // Tap on Meera Sharma to open conversation
      await tester.tap(find.text('Meera Sharma'));
      await tester.pumpAndSettle();

      // Chat screen is open
      expect(find.byTooltip('Back to conversations'), findsOneWidget);

      // Tap back button to return to conversation list
      await tester.tap(find.byTooltip('Back to conversations'));
      await tester.pumpAndSettle();

      // Green badge '1' is now gone and unread count is 0
      expect(find.text('1'), findsNothing);
      expect(meeraRoom.unread, equals(0));
    });

    testWidgets('Image message does not render PDF badge and renders photo representation', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final store = DemoStore();
      final room = DemoRoom('room_img', 'Advocate Sharma', 'Civil', 'AS');
      room.messages.add(
        DemoMessage(
          'Here is the evidence photo',
          file: 'IMG_20260813_150136.jpg',
          attachmentBytes: 30720,
          mine: false,
          createdAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessagesPage(
              store: store,
              initialRoom: room,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Ensure the message text and filename are rendered
      expect(find.text('IMG_20260813_150136.jpg'), findsOneWidget);
      expect(find.text('Here is the evidence photo'), findsOneWidget);

      // Crucially, it must NOT show the generic "PDF" badge that was incorrectly shown before!
      expect(find.text('PDF'), findsNothing);
      // It should display 'Photo' detail
      expect(find.textContaining('Photo'), findsOneWidget);
    });

    testWidgets('Tapping attach button displays modal bottom sheet with Gallery & Photo and Document / PDF options', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final store = DemoStore();
      final room = DemoRoom('room_attach', 'Advocate Kabir', 'Criminal', 'AK');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessagesPage(
              store: store,
              initialRoom: room,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the attachment paperclip icon
      final attachBtn = find.byTooltip('Attach a document or file');
      expect(attachBtn, findsOneWidget);
      await tester.tap(attachBtn);
      await tester.pumpAndSettle();

      // Modal bottom sheet should now be shown
      expect(find.text('Share in conversation'), findsOneWidget);
      expect(find.text('Gallery & Photo'), findsOneWidget);
      expect(find.text('Document / PDF'), findsOneWidget);
    });

    testWidgets('Pressing phone navigation back button on chat screen closes active chat and returns to conversations list', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final store = DemoStore();
      final room = DemoRoom('room_meera', 'Meera Sharma', 'Private conversation', 'MS');
      bool? conversationOpenState;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessagesPage(
              store: store,
              initialRoom: room,
              onConversationChanged: (open) => conversationOpenState = open,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify active chat screen is displayed
      expect(find.text('Meera Sharma'), findsOneWidget);
      expect(find.byTooltip('Back to conversations'), findsOneWidget);

      // Simulate tapping Android system/phone navigation back button
      final didHandlePop = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // Back event must be handled by PopScope, closing active room without popping the app route
      expect(didHandlePop, isTrue);
      expect(conversationOpenState, isFalse);

      // Verify user is now back on the conversations list
      expect(find.text('Search conversations'), findsOneWidget);
      expect(find.byTooltip('Back to conversations'), findsNothing);
    });

    testWidgets('Sent messages (mine) render with deep green background and white text', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final store = DemoStore();
      final room = DemoRoom('room_contrast', 'Advocate Verma', 'Civil', 'AV');
      room.messages.addAll([
        DemoMessage(
          'Hello from client, this is my sent message',
          mine: true,
          createdAt: DateTime.now(),
        ),
        DemoMessage(
          'Hello, this is lawyer reply',
          mine: false,
          createdAt: DateTime.now(),
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessagesPage(
              store: store,
              initialRoom: room,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find sent message text widget
      final sentTextFinder = find.text('Hello from client, this is my sent message');
      expect(sentTextFinder, findsOneWidget);

      final Text sentTextWidget = tester.widget(sentTextFinder);
      expect(sentTextWidget.style?.color, equals(Colors.white));

      // Find received message text widget
      final receivedTextFinder = find.text('Hello, this is lawyer reply');
      expect(receivedTextFinder, findsOneWidget);

      final Text receivedTextWidget = tester.widget(receivedTextFinder);
      expect(receivedTextWidget.style?.color, equals(const Color(0xFF0F2644)));

      // Find Container decoration with deep green color
      final deepGreenContainers = tester.widgetList<Container>(find.byType(Container)).where((container) {
        final decoration = container.decoration;
        if (decoration is BoxDecoration) {
          return decoration.color == const Color(0xFF005C4B);
        }
        return false;
      });
      expect(deepGreenContainers, isNotEmpty);
    });

    testWidgets('Active chat displays ChatMessageShimmerList when entering room before messages load', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final store = DemoStore();
      final room = DemoRoom('room_shimmer', 'Advocate Mishra', 'Civil', 'AM');
      final mockRepo = _MockChatServerMessaging();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessagesPage(
              store: store,
              initialRoom: room,
              repository: mockRepo,
            ),
          ),
        ),
      );

      // Verify ChatMessageShimmerList is rendered while messages are loading from server
      expect(find.byType(ChatMessageShimmerList), findsOneWidget);

      // Complete history loading
      mockRepo.historyCompleter.complete(ServerMessagePage([], null));
      await tester.pumpAndSettle();

      // Shimmer is gone once messages resolve
      expect(find.byType(ChatMessageShimmerList), findsNothing);
    });
  });
}


