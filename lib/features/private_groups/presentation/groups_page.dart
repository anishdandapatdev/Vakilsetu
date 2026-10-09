import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/demo_store.dart';
import '../../../design_system/ui.dart';
import '../../home/presentation/dashboard.dart';
import '../../directory/domain/directory_repository.dart';
import '../../chats/domain/conversation.dart';

class GroupsPage extends StatefulWidget {
  final DemoStore store;
  final ValueChanged<DemoRoom> onOpen;
  final DirectoryRepository? directoryRepository;
  final MessagingRepository? messagingRepository;
  final Future<DemoRoom?> Function(String, List<String>)? onCreateServerGroup;
  const GroupsPage({
    super.key,
    required this.store,
    required this.onOpen,
    this.directoryRepository,
    this.messagingRepository,
    this.onCreateServerGroup,
  });

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  String query = '';
  List<DemoAdvocate>? serverAdvocates;
  List<DemoRoom>? serverGroups;
  StreamSubscription<void>? syncSubscription;

  @override
  void initState() {
    super.initState();
    _loadServerAdvocates();
    _loadServerGroups();
    syncSubscription = widget.messagingRepository?.syncAvailable.listen((_) {
      _loadServerGroups();
    });
  }

  @override
  void didUpdateWidget(covariant GroupsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messagingRepository != widget.messagingRepository ||
        oldWidget.directoryRepository != widget.directoryRepository) {
      syncSubscription?.cancel();
      syncSubscription = widget.messagingRepository?.syncAvailable.listen((_) {
        _loadServerGroups();
      });
      _loadServerAdvocates();
      _loadServerGroups();
    }
  }

  @override
  void dispose() {
    syncSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadServerGroups() async {
    if (widget.messagingRepository == null) return;
    try {
      final summaries = await widget.messagingRepository!.listConversations();
      if (!mounted) return;
      setState(() {
        serverGroups = summaries
            .where((summary) => summary.kind == ConversationKind.privateGroup)
            .map((summary) {
              final initials = summary.title
                  .split(' ')
                  .where((part) => part.isNotEmpty)
                  .map((part) => part[0])
                  .take(2)
                  .join();
              return DemoRoom(
                summary.id,
                summary.title,
                'Private group',
                initials.isEmpty ? 'VS' : initials,
                group: true,
                unread: summary.unreadCount,
                lastMessagePreview: summary.lastMessagePreview,
                lastMessageAt: summary.lastMessageAt ?? summary.createdAt,
              );
            })
            .toList();
      });
    } on Object {
      // Keep the last server list during a temporary connection failure.
    }
  }

  Future<void> _loadServerAdvocates() async {
    if (widget.directoryRepository == null) return;
    try {
      final result = await widget.directoryRepository!.search(query: '');
      if (!mounted) return;
      setState(() {
        serverAdvocates = result.items.map((profile) {
          final initials = profile.fullName
              .split(' ')
              .where((part) => part.isNotEmpty)
              .map((part) => part[0])
              .take(2)
              .join();
          return DemoAdvocate(
            profile.id,
            profile.fullName,
            profile.primaryCourtName ?? 'Court not provided',
            profile.enrollmentNumber,
            'Legal professional',
            initials,
          );
        }).toList();
      });
    } on Object {
      // Creation dialog reports unavailable server members if opened.
    }
  }

  Future<void> _createGroup(BuildContext context) async {
    final room = await showDialog<DemoRoom>(
      context: context,
      builder: (_) => CreateGroupDialog(
        store: widget.store,
        advocates: widget.onCreateServerGroup == null
            ? widget.store.advocates
            : (serverAdvocates ?? const []),
        createServerGroup: widget.onCreateServerGroup,
      ),
    );
    if (room != null) {
      await _loadServerGroups();
      widget.onOpen(room);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = widget.store.name
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase())
        .take(2)
        .join();
    final headerInitials = initials.isEmpty ? 'VS' : initials;
    final allGroups = widget.messagingRepository == null
        ? widget.store.rooms.where((room) => room.group).toList()
        : (serverGroups ?? const <DemoRoom>[]);
    final groups = allGroups
        .where((room) => room.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
            child: BrandedTopBar(initials: headerInitials),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 2, 18, 10),
            child: CompactSearchBox(
              hint: 'Search your private groups',
              onChanged: (value) => setState(() => query = value),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                RefreshIndicator(
                  color: const Color(0xFF0870E4),
                  onRefresh: () async {
                    await _loadServerAdvocates();
                    await _loadServerGroups();
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 88),
                  children: [
                    Text('Your groups', style: heading(16)),
                    const SizedBox(height: 9),
                    if (groups.isEmpty)
                      const Surface(
                        child: EmptyState(
                          'No groups found',
                          'Try another group name.',
                        ),
                      ),
                    for (final room in groups) ...[
                      Container(
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
                          room: room,
                          onTap: () => widget.onOpen(room),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
              Positioned(
                  right: 18,
                  bottom: 18,
                  child: FloatingActionButton(
                    heroTag: 'create-private-group',
                    tooltip: 'Create a private group',
                    onPressed: () => _createGroup(context),
                    backgroundColor: teal,
                    foregroundColor: Colors.white,
                    elevation: 5,
                    child: const Icon(Icons.add_rounded, size: 26),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CreateGroupDialog extends StatefulWidget {
  final DemoStore store;
  final List<DemoAdvocate> advocates;
  final Future<DemoRoom?> Function(String, List<String>)? createServerGroup;
  const CreateGroupDialog({
    super.key,
    required this.store,
    required this.advocates,
    this.createServerGroup,
  });
  @override
  State<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> {
  final name = TextEditingController();
  final members = <String>{};
  String? error;
  bool submitting = false;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Create a private group', style: heading(21)),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Group name'),
            const SizedBox(height: 8),
            TextField(
              controller: name,
              maxLength: 60,
              decoration: const InputDecoration(hintText: 'e.g. Saket Chamber'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Add colleagues',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            if (widget.advocates.isEmpty)
              const Text(
                'No verified advocates are available. Refresh the directory and try again.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
            for (final a in widget.advocates)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Avatar(a.initials, size: 36),
                title: Text(a.name, style: const TextStyle(fontSize: 12)),
                value: members.contains(a.id),
                onChanged: (v) => setState(() {
                  v == true ? members.add(a.id) : members.remove(a.id);
                }),
              ),
            if (error != null)
              Text(
                error!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: submitting
            ? null
            : () async {
                if (name.text.trim().isEmpty || members.isEmpty) {
                  setState(
                    () => error =
                        'Enter a group name and select at least one colleague.',
                  );
                  return;
                }
                if (widget.createServerGroup == null) {
                  Navigator.pop(
                    context,
                    widget.store.createGroup(name.text.trim(), members),
                  );
                  return;
                }
                setState(() {
                  submitting = true;
                  error = null;
                });
                try {
                  final room = await widget.createServerGroup!(
                    name.text.trim(),
                    members.toList(growable: false),
                  );
                  if (context.mounted) Navigator.pop(context, room);
                } on Object catch (failure) {
                  if (context.mounted)
                    setState(() {
                      submitting = false;
                      error = 'Could not create group: $failure';
                    });
                }
              },
        child: Text(submitting ? 'Creating…' : 'Create group'),
      ),
    ],
  );
}
