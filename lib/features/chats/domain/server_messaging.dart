class ServerMessage {
  final String id;
  final String body;
  final String senderName;
  final bool mine;
  final DateTime createdAt;
  final int recipientCount, deliveredCount, readCount;
  final String? attachmentId, attachmentName, attachmentContentType;
  final int? attachmentBytes;
  final String? replyToMessageId, replyBody, replySenderName;
  final bool replyDeleted;
  final DateTime? editedAt, deletedAt;
  ServerMessage(
    this.id,
    this.body,
    this.senderName,
    this.mine,
    this.createdAt,
    this.recipientCount,
    this.deliveredCount,
    this.readCount,
    this.attachmentId,
    this.attachmentName,
    this.attachmentContentType,
    this.attachmentBytes,
    this.replyToMessageId,
    this.replyBody,
    this.replySenderName,
    this.replyDeleted,
    this.editedAt,
    this.deletedAt,
  );
}

class ServerMessagePage {
  final List<ServerMessage> items;
  final String? nextCursor;
  ServerMessagePage(this.items, this.nextCursor);
}

class SharedAttachment {
  final String id, messageId, conversationId, conversationTitle;
  final String filename, contentType;
  final int byteSize;
  final DateTime createdAt;

  const SharedAttachment({
    required this.id,
    required this.messageId,
    required this.conversationId,
    required this.conversationTitle,
    required this.filename,
    required this.contentType,
    required this.byteSize,
    required this.createdAt,
  });
}

class SharedAttachmentPage {
  final List<SharedAttachment> items;
  final String? nextCursor;
  const SharedAttachmentPage(this.items, this.nextCursor);
}

abstract interface class ServerMessaging {
  Future<SharedAttachmentPage> sharedAttachments({
    String? before,
    String search = '',
    String kind = 'all',
  });
  Future<ServerMessagePage> history(String conversationId, {String? before});
  Future<void> sendText(
    String conversationId,
    String clientMessageId,
    String body, {
    String? attachmentId,
    String? replyToMessageId,
  });
  Future<void> editMessage(
    String conversationId,
    String messageId,
    String body,
  );
  Future<void> deleteMessage(String conversationId, String messageId);
  Future<String> uploadAttachment(
    String conversationId,
    String filename,
    String contentType,
    List<int> bytes,
  );
  Future<List<int>> downloadAttachment(String attachmentId);
  Future<void> markRead(String conversationId, String throughMessageId);
}
