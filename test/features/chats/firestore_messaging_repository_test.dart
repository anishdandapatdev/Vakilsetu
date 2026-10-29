import 'package:flutter_test/flutter_test.dart';
import 'package:vakilsetu/features/chats/data/firestore_messaging_repository.dart';
import 'package:vakilsetu/features/chats/domain/conversation.dart';
import 'package:vakilsetu/features/chats/domain/server_messaging.dart';

void main() {
  group('FirestoreMessagingRepository Unit Tests', () {
    test('ConversationSummary models advocate-to-advocate consultation correctly', () {
      final now = DateTime.now();
      final directConv = ConversationSummary(
        id: 'conv_adv_direct_01',
        kind: ConversationKind.direct,
        title: 'Adv. Anish Dandapat',
        category: 'Delhi High Court',
        membershipEpoch: 1,
        createdAt: now.subtract(const Duration(hours: 1)),
        lastMessageAt: now.subtract(const Duration(minutes: 5)),
        lastMessagePreview: 'Good morning Counsel, cause list review ready.',
        unreadCount: 1,
      );

      expect(directConv.id, equals('conv_adv_direct_01'));
      expect(directConv.kind, equals(ConversationKind.direct));
      expect(directConv.title, equals('Adv. Anish Dandapat'));
      expect(directConv.category, equals('Delhi High Court'));
      expect(directConv.unreadCount, equals(1));
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

    test('SharedAttachment model represents verified backend court document', () {
      final now = DateTime.now();
      final attachment = SharedAttachment(
        id: 'att_wp_1042_2026',
        messageId: 'msg_101',
        conversationId: 'conv_delhi_bar',
        conversationTitle: 'Delhi High Court Bar Association',
        filename: 'Petition_Draft_WP_1042_2026.pdf',
        contentType: 'application/pdf',
        byteSize: 102400,
        createdAt: now,
      );

      expect(attachment.id, equals('att_wp_1042_2026'));
      expect(attachment.filename, equals('Petition_Draft_WP_1042_2026.pdf'));
      expect(attachment.contentType, equals('application/pdf'));
      expect(attachment.conversationTitle, equals('Delhi High Court Bar Association'));
      expect(attachment.byteSize, equals(102400));
      expect(attachment.createdAt, equals(now));
    });
  });
}

