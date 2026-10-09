import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../../app/demo_store.dart';
import '../../../design_system/ui.dart';
import '../../home/presentation/dashboard.dart';
import '../../documents/presentation/documents_page.dart';
import '../domain/conversation.dart';
import '../domain/server_messaging.dart';

class MessagesPage extends StatefulWidget {
  final DemoStore store;
  final DemoRoom? initialRoom;
  final ValueChanged<bool>? onConversationChanged;
  final MessagingRepository? repository;
  const MessagesPage({
    super.key,
    required this.store,
    this.initialRoom,
    this.onConversationChanged,
    this.repository,
  });
  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  DemoRoom? active;
  String query = '', filter = 'All';
  final composer = TextEditingController();
  final scroll = ScrollController();
  List<DemoRoom>? apiRooms;
  String? apiError;
  bool apiLoading = false;
  StreamSubscription<void>? syncSubscription;
  Timer? historyTimer;
  bool sending = false;
  bool historyInitialized = false;
  bool loadingOlder = false;
  bool historyLoading = false;
  String? historyError;
  String? historyRoomId;
  String? nextHistoryCursor;
  String? pendingId, pendingBody, pendingRoom, pendingReply;
  DemoMessage? replyingTo, editingMessage;
  bool get serverRoom =>
      widget.repository is ServerMessaging &&
      active != null &&
      RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(active!.id);

  Future<void> _refreshHistory({bool showLoading = false}) async {
    if (!serverRoom) return;
    final room = active!;
    if (showLoading && mounted) {
      setState(() {
        historyLoading = true;
        historyError = null;
      });
    }
    try {
      final page = await (widget.repository! as ServerMessaging).history(
        room.id,
      );
      if (!mounted || active != room) return;
      setState(() {
        historyError = null;
        if (historyRoomId != room.id) {
          room.messages.clear();
          historyRoomId = room.id;
          historyInitialized = false;
        }
        final byId = <String, DemoMessage>{
          for (final message in room.messages)
            if (message.id != null) message.id!: message,
          for (final message in page.items)
            message.id: DemoMessage(
              message.body,
              id: message.id,
              senderName: message.senderName,
              mine: message.mine,
              createdAt: message.createdAt,
              recipientCount: message.recipientCount,
              deliveredCount: message.deliveredCount,
              readCount: message.readCount,
              attachmentId: message.attachmentId,
              file: message.attachmentName,
              attachmentContentType: message.attachmentContentType,
              attachmentBytes: message.attachmentBytes,
              replyToMessageId: message.replyToMessageId,
              replyBody: message.replyBody,
              replySenderName: message.replySenderName,
              replyDeleted: message.replyDeleted,
              editedAt: message.editedAt,
              deletedAt: message.deletedAt,
            ),
        };
        room.messages
          ..clear()
          ..addAll(
            byId.values.toList()
              ..sort((a, b) => a.createdAt!.compareTo(b.createdAt!)),
          );
        if (!historyInitialized) nextHistoryCursor = page.nextCursor;
        historyInitialized = true;
      });
      if (widget.store.receipts) {
        final incoming = page.items.where((message) => !message.mine).toList();
        if (incoming.isNotEmpty) {
          unawaited(
            (widget.repository! as ServerMessaging)
                .markRead(room.id, incoming.last.id)
                .catchError((_) {}),
          );
        }
      }
    } catch (_) {
      // Keep the last loaded history during temporary outages.
      if (mounted && active == room) {
        setState(() => historyError = 'Could not refresh messages.');
      }
    } finally {
      if (showLoading && mounted && active == room) {
        setState(() => historyLoading = false);
      }
    }
  }

  Future<void> _loadOlder() async {
    if (!serverRoom || nextHistoryCursor == null || loadingOlder) return;
    final room = active!;
    setState(() => loadingOlder = true);
    try {
      final page = await (widget.repository! as ServerMessaging).history(
        room.id,
        before: nextHistoryCursor,
      );
      if (!mounted || active != room) return;
      setState(() {
        final existing = room.messages.map((message) => message.id).toSet();
        room.messages.insertAll(
          0,
          page.items
              .where((message) => !existing.contains(message.id))
              .map(
                (message) => DemoMessage(
                  message.body,
                  id: message.id,
                  senderName: message.senderName,
                  mine: message.mine,
                  createdAt: message.createdAt,
                  recipientCount: message.recipientCount,
                  deliveredCount: message.deliveredCount,
                  readCount: message.readCount,
                  attachmentId: message.attachmentId,
                  file: message.attachmentName,
                  attachmentContentType: message.attachmentContentType,
                  attachmentBytes: message.attachmentBytes,
                  replyToMessageId: message.replyToMessageId,
                  replyBody: message.replyBody,
                  replySenderName: message.replySenderName,
                  replyDeleted: message.replyDeleted,
                  editedAt: message.editedAt,
                  deletedAt: message.deletedAt,
                ),
              ),
        );
        nextHistoryCursor = page.nextCursor;
      });
    } on Object {
      if (mounted) toast(context, 'Could not load older messages.');
    } finally {
      if (mounted) setState(() => loadingOlder = false);
    }
  }

  void _openRoom(DemoRoom? room) {
    composer.clear();
    setState(() {
      active = room;
      historyRoomId = null;
      historyInitialized = false;
      nextHistoryCursor = null;
      historyError = null;
      replyingTo = null;
      editingMessage = null;
      historyLoading =
          room != null &&
          widget.repository is ServerMessaging &&
          RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(room.id);
    });
    if (room != null) unawaited(_refreshHistory(showLoading: true));
  }

  @override
  void initState() {
    super.initState();
    active = widget.initialRoom;
    historyTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _refreshHistory(),
    );
    _refreshHistory();
    if (widget.repository != null) {
      _loadConversations();
      widget.repository!.connectRealtime().catchError((_) {});
      widget.repository!.retryPending().catchError((_) {});
      syncSubscription = widget.repository!.syncAvailable.listen((_) {
        _loadConversations();
        _refreshHistory();
      });
    }
  }


  Future<void> _loadConversations() async {
    setState(() {
      apiLoading = true;
      apiError = null;
    });
    try {
      final summaries = await widget.repository!.listConversations();
      final mapped = summaries.map((summary) {
        // Never substitute a fixture ID or fixture history for a server conversation.
        final initials = summary.title
            .split(' ')
            .where((part) => part.isNotEmpty)
            .map((part) => part[0])
            .take(2)
            .join();
        return DemoRoom(
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
      }).toList();
      if (mounted) setState(() => apiRooms = mapped);
    } on Object catch (error) {
      if (mounted) setState(() => apiError = error.toString());
    } finally {
      if (mounted) setState(() => apiLoading = false);
    }
  }

  @override
  void didUpdateWidget(covariant MessagesPage old) {
    super.didUpdateWidget(old);
    if (old.initialRoom != widget.initialRoom) {
      active = widget.initialRoom;
      historyRoomId = null;
      historyInitialized = false;
      nextHistoryCursor = null;
      historyError = null;
      historyLoading = false;
      unawaited(_refreshHistory(showLoading: true));
    }
    if (old.repository != widget.repository) {
      syncSubscription?.cancel();
      if (widget.repository != null) {
        _loadConversations();
        widget.repository!.connectRealtime().catchError((_) {});
        widget.repository!.retryPending().catchError((_) {});
        syncSubscription = widget.repository!.syncAvailable.listen((_) {
          _loadConversations();
          _refreshHistory();
        });
      }
    }
  }

  @override
  void dispose() {
    syncSubscription?.cancel();
    historyTimer?.cancel();
    composer.dispose();
    scroll.dispose();
    super.dispose();
  }

  String _newClientMessageId() {
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<void> _pickAndSendAttachment() async {
    if (!serverRoom || sending) return;
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    final file = picked?.files.single;
    if (file == null) return;
    if (file.bytes == null) {
      if (mounted) toast(context, 'Could not read the selected file.');
      return;
    }
    if (file.size > 25 * 1024 * 1024) {
      if (mounted) toast(context, 'Attachments must be 25 MB or smaller.');
      return;
    }
    final contentType = switch (file.extension?.toLowerCase()) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      _ => null,
    };
    if (contentType == null) return;
    final room = active!;
    setState(() => sending = true);
    try {
      final messaging = widget.repository! as ServerMessaging;
      final attachmentId = await messaging.uploadAttachment(
        room.id,
        file.name,
        contentType,
        file.bytes!,
      );
      await messaging.sendText(
        room.id,
        _newClientMessageId(),
        composer.text.trim(),
        attachmentId: attachmentId,
        replyToMessageId: replyingTo?.id,
      );
      if (!mounted) return;
      composer.clear();
      setState(() => replyingTo = null);
      await _refreshHistory();
    } on Object catch (error) {
      if (mounted) toast(context, 'Could not send attachment: $error');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _downloadAttachment(DemoMessage message) async {
    if (message.attachmentId == null || widget.repository is! ServerMessaging) {
      return;
    }
    try {
      final bytes = await (widget.repository! as ServerMessaging)
          .downloadAttachment(message.attachmentId!);
      await FilePicker.platform.saveFile(
        dialogTitle: 'Save attachment',
        fileName: message.file ?? 'attachment',
        bytes: Uint8List.fromList(bytes),
      );
    } on Object catch (error) {
      if (mounted) toast(context, 'Could not download attachment: $error');
    }
  }

  Future<void> send({String? file}) async {
    if (active == null) return;
    if (widget.repository != null) {
      if (!serverRoom || file != null) {
        toast(
          context,
          'Open a server conversation to send text. File sending is not connected yet.',
        );
        return;
      }
      final body = composer.text.trim();
      if (body.isEmpty || sending) return;
      if (body.length > 4000) {
        toast(context, 'Keep messages under 4,000 characters.');
        return;
      }
      final room = active!;
      if (editingMessage != null) {
        setState(() => sending = true);
        try {
          await (widget.repository! as ServerMessaging).editMessage(
            room.id,
            editingMessage!.id!,
            body,
          );
          if (!mounted) return;
          composer.clear();
          setState(() => editingMessage = null);
          await _refreshHistory();
        } on Object catch (error) {
          if (mounted) toast(context, 'Could not edit message: $error');
        } finally {
          if (mounted) setState(() => sending = false);
        }
        return;
      }
      if (pendingBody != body ||
          pendingRoom != room.id ||
          pendingReply != replyingTo?.id) {
        pendingId = _newClientMessageId();
        pendingBody = body;
        pendingRoom = room.id;
        pendingReply = replyingTo?.id;
      }
      setState(() => sending = true);
      try {
        await (widget.repository! as ServerMessaging).sendText(
          room.id,
          pendingId!,
          body,
          replyToMessageId: replyingTo?.id,
        );
        if (!mounted) return;
        if (active == room && composer.text.trim() == body) composer.clear();
        pendingId = pendingBody = pendingRoom = pendingReply = null;
        setState(() => replyingTo = null);
        await _refreshHistory();
      } catch (_) {
        if (mounted)
          toast(context, 'Message not confirmed. Tap send to retry.');
      } finally {
        if (mounted) setState(() => sending = false);
      }
      return;
    }
    widget.store.send(active!, composer.text, file: file);
    composer.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients)
        scroll.animateTo(
          scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
    });
  }

  Future<void> _messageActions(DemoMessage message) async {
    if (!serverRoom || message.deletedAt != null || message.id == null) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: const Text('Reply'),
              onTap: () => Navigator.pop(context, 'reply'),
            ),
            if (message.mine) ...[
              ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: const Text('Edit message'),
                onTap: () => Navigator.pop(context, 'edit'),
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red,
                ),
                title: const Text('Delete for everyone'),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            ],
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'reply') {
      setState(() {
        editingMessage = null;
        replyingTo = message;
      });
    } else if (action == 'edit') {
      composer.text = message.text;
      setState(() {
        replyingTo = null;
        editingMessage = message;
      });
    } else if (action == 'delete') {
      try {
        await (widget.repository! as ServerMessaging).deleteMessage(
          active!.id,
          message.id!,
        );
        await _refreshHistory();
      } on Object catch (error) {
        if (mounted) toast(context, 'Could not delete message: $error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1150;
    final rooms =
        (widget.repository == null
                ? widget.store.rooms
                : (apiRooms ?? const <DemoRoom>[]))
            .where(
              (r) =>
                  r.name.toLowerCase().contains(query.toLowerCase()) &&
                  (filter != 'Unread' || r.unread > 0) &&
                  (filter != 'Groups' || r.group),
            )
            .toList();
    final initials = widget.store.name
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0])
        .take(2)
        .join();
    final list = ColoredBox(
      color: canvas,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: BrandedTopBar(initials: initials),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: CompactSearchBox(
                hint: 'Search conversations',
                onChanged: (v) => setState(() => query = v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 11, 16, 10),
              child: Wrap(
                spacing: 6,
                children: [
                  for (final f in ['All', 'Unread', 'Groups'])
                    ChoiceChip(
                      label: Text(
                        f,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              filter == f ? FontWeight.w700 : FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      selected: filter == f,
                      selectedColor: const Color(0xFFE0F2FE),
                      backgroundColor: Colors.white,
                      checkmarkColor: Colors.black,
                      side: BorderSide(
                        color: filter == f ? const Color(0xFF38BDF8) : line,
                      ),
                      onSelected: (_) => setState(() => filter = f),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                children: [
                  if (apiLoading) const LinearProgressIndicator(minHeight: 2),
                  if (apiError != null) ...[
                    Surface(
                      color: paleBronze,
                      child: Text(
                        'Could not refresh conversations: $apiError',
                        style: const TextStyle(color: muted, fontSize: 11),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (rooms.isEmpty)
                    const EmptyState(
                      'Nothing here yet',
                      'Try another filter or start a chat from the directory.',
                    ),
                  for (final r in rooms)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: line),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0C0C6F91),
                            blurRadius: 14,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ConversationRow(
                        room: r,
                        selected: active == r,
                        onTap: () {
                          widget.store.read(r);
                          _openRoom(r);
                          widget.onConversationChanged?.call(true);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (!wide && active == null) return list;
    final chat = active == null
        ? const Center(
            child: EmptyState(
              'Your conversations, together',
              'Select a conversation to start reading.',
            ),
          )
        : Column(
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(10, 7, 10, 0),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFE3EDF4)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x120C6F91),
                      blurRadius: 22,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    if (!wide)
                      IconButton(
                        tooltip: 'Back to conversations',
                        onPressed: () {
                          _openRoom(null);
                          widget.onConversationChanged?.call(false);
                        },
                        icon: const Icon(Icons.arrow_back_rounded, color: navy),
                      ),
                    Avatar(active!.initials, group: active!.group, size: 42),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(active!.name, style: heading(15)),
                              ),
                              if (!active!.group) ...[
                                const SizedBox(width: 5),
                                const Icon(
                                  Icons.verified_rounded,
                                  color: Color(0xFF1188EA),
                                  size: 16,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            active!.group
                                ? '${active!.subtitle} · Private group'
                                : active!.subtitle,
                            style: const TextStyle(
                              color: slateBlue,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Conversation information',
                      onPressed: () => info(
                        context,
                        active!.name,
                        widget.repository == null
                            ? 'This is a local conversation preview. Messages stay on this device and are not transmitted.'
                            : 'Messages are delivered through the VakilSetu server and are not end-to-end encrypted.',
                      ),
                      icon: const Icon(
                        Icons.info_outline_rounded,
                        size: 22,
                        color: navy,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(40, 9, 40, 5),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F8F6),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.verified_user_rounded,
                      color: teal,
                      size: 17,
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        widget.repository == null
                            ? 'Local preview · messages are not transmitted'
                            : 'Server-readable messaging · not end-to-end encrypted',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: teal,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 5),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE4F0FF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Today',
                    style: TextStyle(color: slateBlue, fontSize: 10),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1FBFF),
                    image: DecorationImage(
                      image: AssetImage(
                        'assets/images/chat/legal_chat_background.png',
                      ),
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    ),
                  ),
                  child: historyLoading && active!.messages.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : historyError != null && active!.messages.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.cloud_off_rounded,
                                  color: slateBlue,
                                  size: 34,
                                ),
                                const SizedBox(height: 10),
                                Text(historyError!, style: heading(14)),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      _refreshHistory(showLoading: true),
                                  icon: const Icon(
                                    Icons.refresh_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Try again'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            if (historyError != null)
                              Material(
                                color: const Color(0xFFFFF4DE),
                                child: InkWell(
                                  onTap: () =>
                                      _refreshHistory(showLoading: true),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 7,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.refresh_rounded,
                                          size: 16,
                                          color: navy,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'Messages may be out of date · Tap to retry',
                                          style: TextStyle(
                                            color: navy,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            Expanded(
                              child: ListView.builder(
                                controller: scroll,
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  10,
                                  12,
                                  12,
                                ),
                                itemCount:
                                    active!.messages.length +
                                    (serverRoom && nextHistoryCursor != null
                                        ? 1
                                        : 0),
                                itemBuilder: (context, i) {
                                  if (serverRoom &&
                                      nextHistoryCursor != null &&
                                      i == 0) {
                                    return Center(
                                      child: TextButton.icon(
                                        onPressed: loadingOlder
                                            ? null
                                            : _loadOlder,
                                        icon: loadingOlder
                                            ? const SizedBox.square(
                                                dimension: 15,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : const Icon(
                                                Icons.history_rounded,
                                                size: 18,
                                              ),
                                        label: const Text(
                                          'Load older messages',
                                        ),
                                      ),
                                    );
                                  }
                                  final offset =
                                      serverRoom && nextHistoryCursor != null
                                      ? 1
                                      : 0;
                                  final m = active!.messages[i - offset];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Row(
                                      mainAxisAlignment: m.mine
                                          ? MainAxisAlignment.end
                                          : MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Flexible(
                                          child: ConstrainedBox(
                                            constraints: BoxConstraints(
                                              maxWidth:
                                                  MediaQuery.sizeOf(context)
                                                          .width <
                                                      600
                                                  ? MediaQuery.sizeOf(context)
                                                            .width *
                                                        .82
                                                  : 440,
                                            ),
                                            child: Column(
                                              crossAxisAlignment: m.mine
                                                  ? CrossAxisAlignment.end
                                                  : CrossAxisAlignment.start,
                                              children: [
                                                GestureDetector(
                                                  onLongPress: () =>
                                                      _messageActions(m),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.fromLTRB(
                                                          12,
                                                          9,
                                                          12,
                                                          8,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: m.mine
                                                          ? const Color(
                                                              0xFFD8F6FB,
                                                            )
                                                          : Colors.white,
                                                      border: Border.all(
                                                        color: m.mine
                                                            ? const Color(
                                                                0xFFBCEAF3,
                                                              )
                                                            : const Color(
                                                                0xFFE2ECF2,
                                                              ),
                                                      ),
                                                      borderRadius: BorderRadius.only(
                                                        topLeft:
                                                            const Radius.circular(
                                                              18,
                                                            ),
                                                        topRight:
                                                            const Radius.circular(
                                                              18,
                                                            ),
                                                        bottomLeft:
                                                            Radius.circular(
                                                              m.mine ? 18 : 4,
                                                            ),
                                                        bottomRight:
                                                            Radius.circular(
                                                              m.mine ? 4 : 18,
                                                            ),
                                                      ),
                                                      boxShadow: const [
                                                        BoxShadow(
                                                          color: Color(
                                                            0x0D0C6F91,
                                                          ),
                                                          blurRadius: 14,
                                                          offset: Offset(0, 5),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        if (active!.group &&
                                                            !m.mine &&
                                                            m.senderName !=
                                                                null) ...[
                                                          Text(
                                                            m.senderName!,
                                                            style:
                                                                const TextStyle(
                                                                  color: teal,
                                                                  fontSize: 11,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                ),
                                                          ),
                                                          const SizedBox(
                                                            height: 3,
                                                          ),
                                                        ],
                                                        if (m.deletedAt != null)
                                                          Text(
                                                            'This message was deleted',
                                                            style:
                                                                const TextStyle(
                                                                  color:
                                                                      slateBlue,
                                                                  fontSize: 13,
                                                                  fontStyle:
                                                                      FontStyle
                                                                          .italic,
                                                                ),
                                                          )
                                                        else ...[
                                                          if (m.replyToMessageId !=
                                                              null)
                                                            Container(
                                                              width: double
                                                                  .infinity,
                                                              margin:
                                                                  const EdgeInsets.only(
                                                                    bottom: 7,
                                                                  ),
                                                              padding:
                                                                  const EdgeInsets.all(
                                                                    8,
                                                                  ),
                                                              decoration: BoxDecoration(
                                                                color:
                                                                    const Color(
                                                                      0xFFEAF6FA,
                                                                    ),
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      9,
                                                                    ),
                                                                border: const Border(
                                                                  left:
                                                                      BorderSide(
                                                                        color:
                                                                            teal,
                                                                        width:
                                                                            3,
                                                                      ),
                                                                ),
                                                              ),
                                                              child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  Text(
                                                                    m.replySenderName ?? 'Advocate',
                                                                    style: const TextStyle(
                                                                      color:
                                                                          teal,
                                                                      fontSize:
                                                                          10.5,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w700,
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    m.replyDeleted
                                                                        ? 'Deleted message'
                                                                        : (m.replyBody ??
                                                                              'Attachment'),
                                                                    maxLines: 2,
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                    style: const TextStyle(
                                                                      color:
                                                                          slateBlue,
                                                                      fontSize:
                                                                          11,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          if (m.text.isNotEmpty)
                                                            Text(
                                                              m.text,
                                                              style:
                                                                  const TextStyle(
                                                                    color: navy,
                                                                    fontSize:
                                                                        14,
                                                                    height:
                                                                        1.35,
                                                                  ),
                                                            ),
                                                          if (m.file !=
                                                              null) ...[
                                                            const SizedBox(
                                                              height: 8,
                                                            ),
                                                            _ChatDocument(
                                                              name: m.file!,
                                                              detail:
                                                                  m.attachmentBytes ==
                                                                      null
                                                                  ? 'Sample attachment · Preview'
                                                                  : '${(m.attachmentBytes! / 1024).ceil()} KB',
                                                              onOpen:
                                                                  m.attachmentId ==
                                                                      null
                                                                  ? null
                                                                  : () =>
                                                                        _downloadAttachment(
                                                                          m,
                                                                        ),
                                                            ),
                                                          ],
                                                        ],
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Text(
                                                              m.createdAt ==
                                                                      null
                                                                  ? 'Sample'
                                                                  : TimeOfDay.fromDateTime(
                                                                      m.createdAt!
                                                                          .toLocal(),
                                                                    ).format(
                                                                      context,
                                                                    ),
                                                              style:
                                                                  const TextStyle(
                                                                    color:
                                                                        slateBlue,
                                                                    fontSize:
                                                                        11,
                                                                  ),
                                                            ),
                                                            if (m.editedAt !=
                                                                    null &&
                                                                m.deletedAt ==
                                                                    null) ...[
                                                              const SizedBox(
                                                                width: 4,
                                                              ),
                                                              const Text(
                                                                'edited',
                                                                style: TextStyle(
                                                                  color:
                                                                      slateBlue,
                                                                  fontSize: 10,
                                                                  fontStyle:
                                                                      FontStyle
                                                                          .italic,
                                                                ),
                                                              ),
                                                            ],
                                                            if (m.mine &&
                                                                widget.repository ==
                                                                    null) ...[
                                                              const SizedBox(
                                                                width: 5,
                                                              ),
                                                              const Tooltip(
                                                                message: 'Stored locally; not delivered',
                                                                child: Icon(
                                                                  Icons
                                                                      .schedule_rounded,
                                                                  color:
                                                                      slateBlue,
                                                                  size: 15,
                                                                ),
                                                              ),
                                                            ] else if (m.mine &&
                                                                m.recipientCount >
                                                                    0) ...[
                                                              const SizedBox(
                                                                width: 5,
                                                              ),
                                                              Tooltip(
                                                                message:
                                                                    m.readCount ==
                                                                        m.recipientCount
                                                                    ? 'Read'
                                                                    : m.deliveredCount ==
                                                                          m.recipientCount
                                                                    ? 'Delivered'
                                                                    : 'Sent',
                                                                child: Icon(
                                                                  m.deliveredCount >
                                                                          0
                                                                      ? Icons
                                                                            .done_all_rounded
                                                                      : Icons
                                                                            .done_rounded,
                                                                  color:
                                                                      m.readCount ==
                                                                          m.recipientCount
                                                                      ? const Color(
                                                                          0xFF0BA7CD,
                                                                        )
                                                                      : slateBlue,
                                                                  size: 15,
                                                                ),
                                                              ),
                                                            ],
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(6, 7, 8, 8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: line)),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (replyingTo != null || editingMessage != null)
                        Container(
                          margin: const EdgeInsets.fromLTRB(8, 0, 4, 7),
                          padding: const EdgeInsets.fromLTRB(10, 7, 4, 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF6FA),
                            borderRadius: BorderRadius.circular(10),
                            border: const Border(
                              left: BorderSide(color: teal, width: 3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      editingMessage != null
                                          ? 'Editing message'
                                          : 'Replying to ${replyingTo!.senderName ?? (replyingTo!.mine ? 'You' : 'Advocate')}',
                                      style: const TextStyle(
                                        color: teal,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      (editingMessage ?? replyingTo)!.text,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: slateBlue,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Cancel',
                                onPressed: () {
                                  if (editingMessage != null) composer.clear();
                                  setState(() {
                                    replyingTo = null;
                                    editingMessage = null;
                                  });
                                },
                                icon: const Icon(Icons.close_rounded, size: 18),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          IconButton(
                            tooltip: 'Attach a sample document',
                            onPressed: serverRoom
                                ? _pickAndSendAttachment
                                : () => showModalBottomSheet(
                                    context: context,
                                    showDragHandle: true,
                                    builder: (c) => SafeArea(
                                      child: Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Attach a sample file',
                                              style: heading(19),
                                            ),
                                            const SizedBox(height: 8),
                                            const Text(
                                              'Device file upload comes with encrypted storage integration.',
                                              style: TextStyle(
                                                color: muted,
                                                fontSize: 11,
                                              ),
                                            ),
                                            for (final f in sampleDocuments)
                                              ListTile(
                                                leading: const LegalIcon(
                                                  'documents',
                                                ),
                                                title: Text(f),
                                                onTap: () {
                                                  Navigator.pop(c);
                                                  send(file: f);
                                                },
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                            icon: const Icon(
                              Icons.attach_file_rounded,
                              color: Color(0xFF0870E4),
                              size: 23,
                            ),
                          ),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: const Color(0xFFBFDFF4),
                                ),
                              ),
                              child: TextField(
                                controller: composer,
                                minLines: 1,
                                maxLines: 4,
                                keyboardType: TextInputType.multiline,
                                decoration: const InputDecoration(
                                  hintText: 'Write a message',
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          IconButton.filled(
                            tooltip: editingMessage != null
                                ? 'Save edited message'
                                : 'Send message',
                            onPressed: send,
                            style: IconButton.styleFrom(
                              backgroundColor: teal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.all(11),
                            ),
                            icon: const Icon(Icons.send_rounded, size: 20),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
    return Row(
      children: [
        if (wide) ...[
          SizedBox(width: 310, child: list),
          const VerticalDivider(width: 1),
        ],
        Expanded(child: chat),
      ],
    );
  }
}

class _ChatDocument extends StatelessWidget {
  final String name;
  final String detail;
  final VoidCallback? onOpen;
  const _ChatDocument({required this.name, required this.detail, this.onOpen});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FCFF),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE0EDF5)),
    ),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFFF4D55),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'PDF',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 10,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: heading(11),
              ),
              const SizedBox(height: 3),
              Text(detail, style: TextStyle(color: slateBlue, fontSize: 9)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(11),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: paleBlue,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              onOpen == null
                  ? Icons.open_in_full_rounded
                  : Icons.download_rounded,
              color: const Color(0xFF0870E4),
              size: 17,
            ),
          ),
        ),
      ],
    ),
  );
}
