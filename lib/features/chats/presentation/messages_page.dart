import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../../app/demo_store.dart';
import '../../../design_system/ui.dart';
import '../../home/presentation/dashboard.dart';
import '../domain/conversation.dart';
import '../domain/server_messaging.dart';

class MessagesPage extends StatefulWidget {
  final DemoStore store;
  final DemoRoom? initialRoom;
  final ValueChanged<bool>? onConversationChanged;
  final MessagingRepository? repository;
  final VoidCallback? onProfile;
  const MessagesPage({
    super.key,
    required this.store,
    this.initialRoom,
    this.onConversationChanged,
    this.repository,
    this.onProfile,
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
  PlatformFile? pendingAttachment;
  Uint8List? pendingAttachmentBytes;
  static final Map<String, Uint8List> _attachmentBytesCache = {};

  bool get serverRoom =>
      widget.repository is ServerMessaging &&
      active != null;

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
              ..sort((a, b) {
                final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                return aTime.compareTo(bTime);
              }),
          );
        if (!historyInitialized) nextHistoryCursor = page.nextCursor;
        historyInitialized = true;
      });
      if (room.unread > 0) {
        setState(() => room.unread = 0);
        widget.store.read(room);
      }
      if (widget.repository is ServerMessaging) {
        final incoming = page.items.where((message) => !message.mine).toList();
        final throughId = incoming.isNotEmpty
            ? incoming.last.id
            : (page.items.isNotEmpty ? page.items.last.id : '');
        unawaited(
          (widget.repository! as ServerMessaging)
              .markRead(room.id, throughId)
              .catchError((_) {}),
        );
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
    if (room != null) {
      room.unread = 0;
      widget.store.read(room);
      if (widget.repository is ServerMessaging) {
        (widget.repository! as ServerMessaging)
            .markRead(room.id, '')
            .catchError((_) {});
      }
    }
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
          (RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(room.id) ||
              !RegExp(r'^[1-5]$').hasMatch(room.id));
    });
    if (room != null) unawaited(_refreshHistory(showLoading: true));
  }

  @override
  void initState() {
    super.initState();
    active = widget.initialRoom;
    if (active != null) {
      active!.unread = 0;
      widget.store.read(active!);
      if (widget.repository is ServerMessaging) {
        historyLoading = true;
        (widget.repository! as ServerMessaging)
            .markRead(active!.id, '')
            .catchError((_) {});
      }
    }
    historyTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _refreshHistory(),
    );
    _refreshHistory(showLoading: true);
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
          unread: (active?.id == summary.id) ? 0 : summary.unreadCount,
          lastMessagePreview: summary.lastMessagePreview,
          lastMessageAt: summary.lastMessageAt ?? summary.createdAt,
        );
      }).toList();
      if (mounted) {
        setState(() {
          apiRooms = mapped;
          if (active != null) {
            final match = mapped.where((m) => m.id == active!.id);
            if (match.isNotEmpty) {
              final activeMessages = List<DemoMessage>.from(active!.messages);
              active = match.first;
              if (active!.messages.isEmpty && activeMessages.isNotEmpty) {
                active!.messages.addAll(activeMessages);
              }
            }
          }
        });
      }
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
      if (active != null) {
        active!.unread = 0;
        widget.store.read(active!);
        if (widget.repository is ServerMessaging) {
          (widget.repository! as ServerMessaging)
              .markRead(active!.id, '')
              .catchError((_) {});
        }
      }
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

  void _showAttachmentPicker() {
    if (active == null || sending) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Share in conversation',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: navy,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _AttachmentOption(
                      icon: Icons.image_rounded,
                      label: 'Gallery & Photo',
                      color: const Color(0xFF00A884),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickAttachment(
                          FileType.custom,
                          allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'gif'],
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AttachmentOption(
                      icon: Icons.picture_as_pdf_rounded,
                      label: 'Document / PDF',
                      color: const Color(0xFF5367FF),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickAttachment(
                          FileType.custom,
                          allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAttachment(
    FileType type, {
    List<String>? allowedExtensions,
  }) async {
    if (active == null || sending) return;
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: type,
        allowedExtensions: allowedExtensions,
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
      setState(() {
        pendingAttachment = file;
        pendingAttachmentBytes = file.bytes;
      });
    } catch (e) {
      if (mounted) toast(context, 'Could not select file: $e');
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
    final body = composer.text.trim();
    if ((body.isEmpty && pendingAttachment == null && file == null) || sending) {
      return;
    }
    if (body.length > 4000) {
      toast(context, 'Keep messages under 4,000 characters.');
      return;
    }
    final room = active!;
    if (editingMessage != null) {
      setState(() => sending = true);
      try {
        if (widget.repository is ServerMessaging) {
          await (widget.repository! as ServerMessaging).editMessage(
            room.id,
            editingMessage!.id!,
            body,
          );
        }
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

    if (widget.repository is ServerMessaging) {
      setState(() => sending = true);
      try {
        String? attachmentId;
        if (pendingAttachment != null && pendingAttachmentBytes != null) {
          final ext = pendingAttachment!.extension?.toLowerCase();
          final contentType = switch (ext) {
            'pdf' => 'application/pdf',
            'jpg' || 'jpeg' => 'image/jpeg',
            'png' => 'image/png',
            'webp' => 'image/webp',
            'gif' => 'image/gif',
            'doc' => 'application/msword',
            'docx' =>
                'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            _ => 'application/octet-stream',
          };
          attachmentId = await (widget.repository! as ServerMessaging)
              .uploadAttachment(
            room.id,
            pendingAttachment!.name,
            contentType,
            pendingAttachmentBytes!,
          );
          _attachmentBytesCache[attachmentId] = pendingAttachmentBytes!;
        }

        if (pendingBody != body ||
            pendingRoom != room.id ||
            pendingReply != replyingTo?.id) {
          pendingId = _newClientMessageId();
          pendingBody = body;
          pendingRoom = room.id;
          pendingReply = replyingTo?.id;
        }

        await (widget.repository! as ServerMessaging).sendText(
          room.id,
          pendingId!,
          body,
          attachmentId: attachmentId,
          replyToMessageId: replyingTo?.id,
        );

        if (!mounted) return;
        composer.clear();
        setState(() {
          pendingAttachment = null;
          pendingAttachmentBytes = null;
          replyingTo = null;
        });
        pendingId = pendingBody = pendingRoom = pendingReply = null;
        await _refreshHistory();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (scroll.hasClients) {
            scroll.animateTo(
              scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
            );
          }
        });
      } catch (_) {
        if (mounted) {
          toast(context, 'Message not confirmed. Tap send to retry.');
        }
      } finally {
        if (mounted) setState(() => sending = false);
      }
      return;
    }

    widget.store.send(
      active!,
      composer.text,
      file: pendingAttachment?.name ?? file,
    );
    composer.clear();
    setState(() {
      pendingAttachment = null;
      pendingAttachmentBytes = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) {
        scroll.animateTo(
          scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
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
    final bool isServerChat = widget.repository != null;
    final bool isInitialListLoading = isServerChat && apiRooms == null;
    final rawRooms = (apiRooms != null)
        ? apiRooms!
        : (isServerChat ? <DemoRoom>[] : widget.store.rooms);
    final rooms = rawRooms
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
              child: BrandedTopBar(
                initials: initials,
                onAvatarTap: widget.onProfile,
              ),
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
                  if (isInitialListLoading || (apiLoading && rooms.isEmpty))
                    const ChatConversationShimmerList()
                  else ...[
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
                          selected: active?.id == r.id,
                          onTap: () {
                            widget.store.read(r);
                            _openRoom(r);
                            widget.onConversationChanged?.call(true);
                          },
                        ),
                      ),
                  ],
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
        : SafeArea(
            bottom: false,
            child: Column(
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
                        'Communications in this channel are encrypted in transit and legally protected under Advocate-Client Privilege pursuant to the Indian Evidence Act, 1872.',
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
              Center(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 5.5,
                  ),
              
                  
                ),
              ),
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 2, bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x06000000),
                        blurRadius: 6,
                        offset: Offset(0, 1.5),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Today',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
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
                  child: (historyLoading &&
                          (!historyInitialized || active!.messages.isEmpty))
                      ? const ChatMessageShimmerList()
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
                                                          14,
                                                          10,
                                                          14,
                                                          9,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: m.mine
                                                          ? const Color(
                                                              0xFF005C4B,
                                                            )
                                                          : Colors.white,
                                                      border: Border.all(
                                                        color: m.mine
                                                            ? const Color(
                                                                0xFF004D3F,
                                                              )
                                                            : const Color(
                                                                0xFFE2ECF2,
                                                              ),
                                                        width: 1,
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
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: m.mine
                                                              ? const Color(
                                                                  0x24000000,
                                                                )
                                                              : const Color(
                                                                  0x0A0F172A,
                                                                ),
                                                          blurRadius: 8,
                                                          offset: const Offset(
                                                            0,
                                                            2,
                                                          ),
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
                                                            style: TextStyle(
                                                              color: m.mine
                                                                  ? Colors.white70
                                                                  : slateBlue,
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
                                                                color: m.mine
                                                                    ? const Color(
                                                                        0xFF024639,
                                                                      )
                                                                    : const Color(
                                                                        0xFFEAF6FA,
                                                                      ),
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      9,
                                                                    ),
                                                                border: Border(
                                                                  left:
                                                                      BorderSide(
                                                                        color: m.mine
                                                                            ? const Color(
                                                                                0xFF34D399,
                                                                              )
                                                                            : teal,
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
                                                                    style: TextStyle(
                                                                      color: m.mine
                                                                          ? const Color(
                                                                              0xFF34D399,
                                                                            )
                                                                          : teal,
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
                                                                    style: TextStyle(
                                                                      color: m.mine
                                                                          ? Colors.white.withValues(alpha: 0.85)
                                                                          : slateBlue,
                                                                      fontSize:
                                                                          11,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          () {
                                                            final isImage = m.file != null &&
                                                                ((m.attachmentContentType?.startsWith('image/') ?? false) ||
                                                                    RegExp(r'\.(jpe?g|png|webp|gif|bmp)$', caseSensitive: false)
                                                                        .hasMatch(m.file!));
                                                            if (isImage) {
                                                              return Column(
                                                                crossAxisAlignment: m.mine
                                                                    ? CrossAxisAlignment.end
                                                                    : CrossAxisAlignment.start,
                                                                children: [
                                                                  _ChatImageBubble(
                                                                    filename: m.file!,
                                                                    attachmentId: m.attachmentId,
                                                                    attachmentBytes: m.attachmentBytes,
                                                                    repository: widget.repository is ServerMessaging
                                                                        ? widget.repository! as ServerMessaging
                                                                        : null,
                                                                    mine: m.mine,
                                                                    onDownload: m.attachmentId == null
                                                                        ? null
                                                                        : () => _downloadAttachment(m),
                                                                  ),
                                                                  if (m.text.isNotEmpty) ...[
                                                                    const SizedBox(height: 6),
                                                                    Text(
                                                                      m.text,
                                                                      style: TextStyle(
                                                                        color: m.mine
                                                                            ? Colors.white
                                                                            : const Color(0xFF0F2644),
                                                                        fontSize: 14.5,
                                                                        fontWeight: FontWeight.w500,
                                                                        height: 1.35,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ],
                                                              );
                                                            }
                                                            return Column(
                                                              crossAxisAlignment: m.mine
                                                                  ? CrossAxisAlignment.end
                                                                  : CrossAxisAlignment.start,
                                                              children: [
                                                                if (m.text.isNotEmpty)
                                                                  Text(
                                                                    m.text,
                                                                    style: TextStyle(
                                                                      color: m.mine
                                                                          ? Colors.white
                                                                          : const Color(0xFF0F2644),
                                                                      fontSize: 14.5,
                                                                      fontWeight: FontWeight.w500,
                                                                      height: 1.35,
                                                                    ),
                                                                  ),
                                                                if (m.file != null) ...[
                                                                  if (m.text.isNotEmpty)
                                                                    const SizedBox(height: 8),
                                                                  _ChatDocument(
                                                                    name: m.file!,
                                                                    detail: m.attachmentBytes == null
                                                                        ? 'Attachment · Ready'
                                                                        : '${(m.attachmentBytes! / 1024).ceil()} KB',
                                                                    mine: m.mine,
                                                                    onOpen: m.attachmentId == null
                                                                        ? null
                                                                        : () => _downloadAttachment(m),
                                                                  ),
                                                                ],
                                                              ],
                                                            );
                                                          }(),
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
                                                                  TextStyle(
                                                                    color: m.mine
                                                                        ? Colors.white.withValues(alpha: 0.82)
                                                                        : const Color(0xFF64748B),
                                                                    fontSize: 11,
                                                                    fontWeight: FontWeight.w500,
                                                                  ),
                                                            ),
                                                            if (m.editedAt !=
                                                                    null &&
                                                                m.deletedAt ==
                                                                    null) ...[
                                                              const SizedBox(
                                                                width: 4,
                                                              ),
                                                              Text(
                                                                'edited',
                                                                style: TextStyle(
                                                                  color: m.mine
                                                                      ? Colors.white.withValues(alpha: 0.75)
                                                                      : slateBlue,
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
                                                              Tooltip(
                                                                message: 'Stored locally; not delivered',
                                                                child: Icon(
                                                                  Icons
                                                                      .schedule_rounded,
                                                                  color: Colors.white.withValues(alpha: 0.75),
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
                                                                          0xFF53BDEB,
                                                                        )
                                                                      : Colors.white.withValues(alpha: 0.75),
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
                      if (pendingAttachment != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F8FC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFC7E3F7)),
                          ),
                          child: Row(
                            children: [
                              if (pendingAttachmentBytes != null &&
                                  RegExp(r'\.(jpe?g|png|webp|gif|bmp)$', caseSensitive: false)
                                      .hasMatch(pendingAttachment!.name))
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    pendingAttachmentBytes!,
                                    width: 44,
                                    height: 44,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              else
                                Container(
                                  width: 40,
                                  height: 40,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: pendingAttachment!.name.toLowerCase().endsWith('.pdf')
                                        ? const Color(0xFFFF4D55)
                                        : const Color(0xFF0870E4),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    pendingAttachment!.name.toLowerCase().endsWith('.pdf')
                                        ? 'PDF'
                                        : 'DOC',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      pendingAttachment!.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: navy,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${(pendingAttachment!.size / 1024).ceil()} KB · Ready to send',
                                      style: const TextStyle(
                                        color: slateBlue,
                                        fontSize: 10.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Remove attachment',
                                onPressed: () {
                                  setState(() {
                                    pendingAttachment = null;
                                    pendingAttachmentBytes = null;
                                  });
                                },
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          IconButton(
                            tooltip: 'Attach a document or file',
                            onPressed: _showAttachmentPicker,
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
                                decoration: InputDecoration(
                                  hintText: pendingAttachment != null
                                      ? 'Add a caption...'
                                      : 'Write a message',
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
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
          ),
        );
    if (!wide) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _openRoom(null);
          widget.onConversationChanged?.call(false);
        },
        child: chat,
      );
    }
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
  final bool mine;
  final VoidCallback? onOpen;
  const _ChatDocument({
    required this.name,
    required this.detail,
    this.mine = false,
    this.onOpen,
  });

  (String, Color) _badgeInfo(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return ('PDF', const Color(0xFFFF4D55));
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) {
      return ('DOC', const Color(0xFF0870E4));
    }
    if (lower.endsWith('.xls') ||
        lower.endsWith('.xlsx') ||
        lower.endsWith('.csv')) {
      return ('XLS', const Color(0xFF107C41));
    }
    if (lower.endsWith('.txt')) {
      return ('TXT', const Color(0xFF5A6872));
    }
    return ('FILE', const Color(0xFF0D9488));
  }

  @override
  Widget build(BuildContext context) {
    final (badgeText, badgeColor) = _badgeInfo(name);
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: mine ? const Color(0xFF024639) : const Color(0xFFF8FCFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: mine ? const Color(0xFF00382E) : const Color(0xFFE0EDF5),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badgeText,
                style: const TextStyle(
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
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: mine ? Colors.white : ink,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    style: TextStyle(
                      color: mine
                          ? Colors.white.withValues(alpha: 0.75)
                          : slateBlue,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: mine ? const Color(0xFF005C4B) : paleBlue,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                onOpen == null
                    ? Icons.open_in_full_rounded
                    : Icons.download_rounded,
                color: mine ? Colors.white : const Color(0xFF0870E4),
                size: 17,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatImageBubble extends StatefulWidget {
  final String filename;
  final String? attachmentId;
  final int? attachmentBytes;
  final ServerMessaging? repository;
  final bool mine;
  final VoidCallback? onDownload;

  const _ChatImageBubble({
    required this.filename,
    this.attachmentId,
    this.attachmentBytes,
    this.repository,
    this.mine = false,
    this.onDownload,
  });

  @override
  State<_ChatImageBubble> createState() => _ChatImageBubbleState();
}

class _ChatImageBubbleState extends State<_ChatImageBubble> {
  Uint8List? _bytes;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadBytes();
  }

  @override
  void didUpdateWidget(covariant _ChatImageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attachmentId != widget.attachmentId) {
      _loadBytes();
    }
  }

  void _loadBytes() {
    if (widget.attachmentId != null &&
        _MessagesPageState._attachmentBytesCache.containsKey(widget.attachmentId)) {
      _bytes = _MessagesPageState._attachmentBytesCache[widget.attachmentId];
      _loading = false;
      return;
    }

    if (widget.attachmentId != null && widget.repository != null) {
      _loading = true;
      widget.repository!.downloadAttachment(widget.attachmentId!).then((bytes) {
        if (!mounted) return;
        final uint8 = Uint8List.fromList(bytes);
        _MessagesPageState._attachmentBytesCache[widget.attachmentId!] = uint8;
        setState(() {
          _bytes = uint8;
          _loading = false;
        });
      }).catchError((_) {
        if (!mounted) return;
        setState(() {
          _loading = false;
        });
      });
    }
  }

  void _openLightbox() {
    if (_bytes == null) return;
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (ctx) => Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.black.withValues(alpha: 0.6),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(ctx),
          ),
          title: Text(
            widget.filename,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            if (widget.onDownload != null)
              IconButton(
                tooltip: 'Download image',
                icon: const Icon(Icons.download_rounded, color: Colors.white),
                onPressed: () {
                  Navigator.pop(ctx);
                  widget.onDownload?.call();
                },
              ),
          ],
        ),
        body: Center(
          child: InteractiveViewer(
            panEnabled: true,
            minScale: 0.8,
            maxScale: 4.0,
            child: Image.memory(
              _bytes!,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const maxWidth = 260.0;
    const maxHeight = 260.0;

    if (_loading) {
      return Container(
        width: maxWidth,
        height: 180,
        decoration: BoxDecoration(
          color: const Color(0xFFEAF4FB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD0E6F5)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: teal),
            ),
            const SizedBox(height: 10),
            Text(
              'Loading image...',
              style: TextStyle(color: slateBlue, fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (_bytes != null) {
      return GestureDetector(
        onTap: _openLightbox,
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: maxHeight,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.mine
                  ? const Color(0xFFBCE3DA)
                  : const Color(0xFFD6E8F5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Stack(
              children: [
                Image.memory(
                  _bytes!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
                      child,
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.fullscreen_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
                if (widget.onDownload != null)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: widget.onDownload,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.download_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      width: maxWidth,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.mine
            ? const Color(0xFF024639)
            : const Color(0xFFF3F8FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.mine
              ? const Color(0xFF00382E)
              : const Color(0xFFD0E6F5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF00A884).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.image_outlined,
              color: Color(0xFF00A884),
              size: 24,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: widget.mine ? Colors.white : ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.attachmentBytes != null
                      ? '${(widget.attachmentBytes! / 1024).ceil()} KB · Photo'
                      : 'Photo',
                  style: TextStyle(
                    color: widget.mine
                        ? Colors.white.withValues(alpha: 0.75)
                        : slateBlue,
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),
          if (widget.onDownload != null)
            IconButton(
              icon: Icon(
                Icons.download_rounded,
                color: widget.mine ? Colors.white : teal,
                size: 20,
              ),
              onPressed: widget.onDownload,
            ),
        ],
      ),
    );
  }
}

class _AttachmentOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachmentOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: navy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
