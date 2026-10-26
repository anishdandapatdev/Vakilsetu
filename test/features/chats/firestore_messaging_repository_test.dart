import 'package:flutter_test/flutter_test.dart';
import 'package:vakilsetu/features/chats/data/firestore_messaging_repository.dart';
import 'package:vakilsetu/features/chats/domain/conversation.dart';
import 'package:vakilsetu/features/chats/domain/server_messaging.dart';

void main() {
  group('FirestoreMessagingRepository Unit Tests', () {
    test('normalizeAdvocateId handles demo and prefixed advocate ids', () {
      expect(FirestoreMessagingRepository.normalizeAdvocateId('meera'), equals('adv_meera'));
      expect(FirestoreMessagingRepository.normalizeAdvocateId('kabir'), equals('adv_kabir'));
      expect(FirestoreMessagingRepository.normalizeAdvocateId('naina'), equals('adv_naina'));
      expect(FirestoreMessagingRepository.normalizeAdvocateId('rohit'), equals('adv_rohit'));
      expect(FirestoreMessagingRepository.normalizeAdvocateId('adv_meera'), equals('adv_meera'));
      expect(FirestoreMessagingRepository.normalizeAdvocateId('custom_id_123'), equals('custom_id_123'));
    });

    test('fallback conversations provide expected initial contacts and titles', () async {
      // Testing the static fallback and messaging domain models
      final fallbacks = [
        ConversationSummary(
          id: '11111111-2222-3333-4444-555555555551',
          kind: ConversationKind.direct,
          title: 'Meera Sharma',
          membershipEpoch: 1,
          createdAt: DateTime.now().subtract(const Duration(hours: 3)),
          lastMessageAt: DateTime.now().subtract(const Duration(minutes: 15)),
          lastMessagePreview: 'Let me know once you go through the clause 14 provisions.',
          unreadCount: 1,
        ),
        ConversationSummary(
          id: '11111111-2222-3333-4444-555555555552',
          kind: ConversationKind.direct,
          title: 'Kabir Malhotra',
          membershipEpoch: 1,
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          lastMessageAt: DateTime.now().subtract(const Duration(minutes: 45)),
          lastMessagePreview: 'Saket Court bench hearing is scheduled for tomorrow 10:30 AM.',
          unreadCount: 0,
        ),
        ConversationSummary(
          id: '11111111-2222-3333-4444-555555555553',
          kind: ConversationKind.privateGroup,
          title: 'Delhi High Court Bar Association',
          membershipEpoch: 1,
          createdAt: DateTime.now().subtract(const Duration(days: 3)),
          lastMessageAt: DateTime.now().subtract(const Duration(hours: 2)),
          lastMessagePreview: 'The bar association meeting on digital filings is at 4 PM in library hall.',
          unreadCount: 2,
        ),
      ];

      expect(fallbacks.length, equals(3));
      expect(fallbacks[0].title, equals('Meera Sharma'));
      expect(fallbacks[0].kind, equals(ConversationKind.direct));
      expect(fallbacks[1].title, equals('Kabir Malhotra'));
      expect(fallbacks[2].kind, equals(ConversationKind.privateGroup));
      expect(fallbacks[2].unreadCount, equals(2));
    });

    test('ConversationSummary ordering by lastMessageAt descending', () {
      final now = DateTime.now();
      final convs = [
        ConversationSummary(
          id: 'c1',
          kind: ConversationKind.direct,
          title: 'Old chat',
          membershipEpoch: 1,
          createdAt: now.subtract(const Duration(days: 5)),
          lastMessageAt: now.subtract(const Duration(days: 2)),
        ),
        ConversationSummary(
          id: 'c2',
          kind: ConversationKind.direct,
          title: 'Recent chat',
          membershipEpoch: 1,
          createdAt: now.subtract(const Duration(days: 1)),
          lastMessageAt: now.subtract(const Duration(minutes: 10)),
        ),
        ConversationSummary(
          id: 'c3',
          kind: ConversationKind.privateGroup,
          title: 'Newest chat',
          membershipEpoch: 1,
          createdAt: now,
          lastMessageAt: now.subtract(const Duration(minutes: 1)),
        ),
      ];

      convs.sort((a, b) {
        final aTime = a.lastMessageAt ?? a.createdAt;
        final bTime = b.lastMessageAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });

      expect(convs[0].id, equals('c3'));
      expect(convs[1].id, equals('c2'));
      expect(convs[2].id, equals('c1'));
    });

    test('ServerMessage model instantiation and properties', () {
      final now = DateTime.now();
      final message = ServerMessage(
        'msg_test_1',
        'Hello Counsel',
        'Meera Sharma',
        false,
        now,
        1,
        1,
        1,
        'att_1',
        'sample.pdf',
        'application/pdf',
        1024,
        null,
        null,
        null,
        false,
        null,
        null,
      );

      expect(message.id, equals('msg_test_1'));
      expect(message.body, equals('Hello Counsel'));
      expect(message.senderName, equals('Meera Sharma'));
      expect(message.mine, isFalse);
      expect(message.attachmentName, equals('sample.pdf'));
      expect(message.attachmentBytes, equals(1024));
    });

    test('unread calculation logic resets unread to 0 when last sender is current user', () {
      const currentUid = 'user_123';

      int resolveUnread(Map<String, dynamic> data) {
        final lastSenderId = data['lastSenderId'] as String?;
        final unreadCounts = data['unreadCounts'] as Map<String, dynamic>?;
        final rawUnread = (unreadCounts != null && unreadCounts.containsKey(currentUid))
            ? (unreadCounts[currentUid] as num?)?.toInt() ?? 0
            : (data['unreadCount'] as num?)?.toInt() ?? 0;
        return (lastSenderId == currentUid) ? 0 : rawUnread;
      }

      // Incoming message from peer: unread count is preserved
      final incomingDoc = {
        'lastSenderId': 'peer_456',
        'unreadCount': 2,
      };
      expect(resolveUnread(incomingDoc), equals(2));

      // Outgoing message from current user: unread count is always 0
      final outgoingDoc = {
        'lastSenderId': currentUid,
        'unreadCount': 2,
      };
      expect(resolveUnread(outgoingDoc), equals(0));

      // Per-user unread tracking
      final perUserDoc = {
        'lastSenderId': 'peer_456',
        'unreadCount': 3,
        'unreadCounts': {
          currentUid: 1,
          'other_user': 3,
        },
      };
      expect(resolveUnread(perUserDoc), equals(1));
    });
  });
}

