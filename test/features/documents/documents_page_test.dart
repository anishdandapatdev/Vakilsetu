import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vakilsetu/features/chats/domain/server_messaging.dart';
import 'package:vakilsetu/features/documents/presentation/documents_page.dart';

class MockServerMessaging implements ServerMessaging {
  final List<SharedAttachment> attachments;

  MockServerMessaging(this.attachments);

  @override
  Future<SharedAttachmentPage> sharedAttachments({
    String? before,
    String search = '',
    String kind = 'all',
  }) async {
    final filtered = attachments.where((a) {
      if (search.isNotEmpty && !a.filename.toLowerCase().contains(search.toLowerCase())) {
        return false;
      }
      if (kind == 'documents' && !a.contentType.contains('pdf')) return false;
      if (kind == 'images' && !a.contentType.startsWith('image/')) return false;
      return true;
    }).toList();
    return SharedAttachmentPage(filtered, null);
  }

  @override
  Future<List<int>> downloadAttachment(String attachmentId) async {
    return [37, 80, 68, 70]; // %PDF
  }

  @override
  Future<String> uploadAttachment(
    String conversationId,
    String filename,
    String contentType,
    List<int> bytes,
  ) async {
    final newDoc = SharedAttachment(
      id: 'att_new_${attachments.length + 1}',
      messageId: 'msg_new',
      conversationId: conversationId,
      conversationTitle: 'New Upload',
      filename: filename,
      contentType: contentType,
      byteSize: bytes.length,
      createdAt: DateTime.now(),
    );
    attachments.insert(0, newDoc);
    return newDoc.id;
  }

  @override
  Future<ServerMessagePage> history(String conversationId, {String? before}) =>
      throw UnimplementedError();

  @override
  Future<void> markRead(String conversationId, String messageId) async {}

  @override
  Future<void> sendText(
    String conversationId,
    String clientMessageId,
    String body, {
    String? attachmentId,
    String? replyToMessageId,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> editMessage(
    String conversationId,
    String messageId,
    String body,
  ) =>
      throw UnimplementedError();

  @override
  Future<void> deleteMessage(String conversationId, String messageId) =>
      throw UnimplementedError();
}

void main() {
  group('DocumentsPage Backend Integration Tests', () {
    testWidgets('DocumentsPage displays real backend attachments without mock data', (tester) async {
      final mockRepo = MockServerMessaging([
        SharedAttachment(
          id: 'att_wp_1042_2026',
          messageId: 'msg_1',
          conversationId: '11111111-2222-3333-4444-555555555553',
          conversationTitle: 'Delhi High Court Bar Association',
          filename: 'Petition_Draft_WP_1042_2026.pdf',
          contentType: 'application/pdf',
          byteSize: 102400,
          createdAt: DateTime.now(),
        ),
        SharedAttachment(
          id: 'att_order_saket_14',
          messageId: 'msg_2',
          conversationId: '11111111-2222-3333-4444-555555555551',
          conversationTitle: 'Meera Sharma',
          filename: 'Court_Order_Item_14_Saket.pdf',
          contentType: 'application/pdf',
          byteSize: 51200,
          createdAt: DateTime.now(),
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DocumentsPage(repository: mockRepo),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verified real documents from backend are displayed
      expect(find.text('Petition_Draft_WP_1042_2026.pdf'), findsOneWidget);
      expect(find.text('Court_Order_Item_14_Saket.pdf'), findsOneWidget);

      // Verify NO old mock fallbacks or sample warnings exist
      expect(find.text('Sample file'), findsNothing);
      expect(find.text('Sample documents only. No real files are opened in demo mode.'), findsNothing);
      expect(find.text('Sample files for exploring the design.'), findsNothing);

      // Verify "Upload File" button exists
      expect(find.text('Upload File'), findsOneWidget);
    });

    testWidgets('DocumentsPage shows empty state when repository has no files', (tester) async {
      final emptyRepo = MockServerMessaging([]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DocumentsPage(repository: emptyRepo),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Displays clean empty state without falling back to sample documents
      expect(find.text('No matching documents'), findsOneWidget);
      expect(find.text('Petition_draft.pdf'), findsNothing);
      expect(find.text('Court_order.pdf'), findsNothing);
      expect(find.text('Cause_list.pdf'), findsNothing);
      expect(find.text('Evidence_photo.jpg'), findsNothing);
    });
  });
}
