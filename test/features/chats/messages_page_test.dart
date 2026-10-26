import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vakilsetu/app/demo_store.dart';
import 'package:vakilsetu/design_system/ui.dart';
import 'package:vakilsetu/features/chats/domain/conversation.dart';
import 'package:vakilsetu/features/chats/presentation/messages_page.dart';

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
  });
}
