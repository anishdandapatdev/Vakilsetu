import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/demo_store.dart';
import '../../../design_system/ui.dart';
import '../../chats/domain/conversation.dart';
import '../../directory/domain/directory_repository.dart';

class GroupsPage extends StatefulWidget {
  final DemoStore store;
  final ValueChanged<DemoRoom> onOpen;
  final VoidCallback? onProfile;
  final DirectoryRepository? directoryRepository;
  final MessagingRepository? messagingRepository;
  final Future<DemoRoom?> Function(
    String title,
    List<String> memberIds, {
    String? category,
    String? description,
    String? inviteCode,
    bool isPublic,
  })? onCreateServerGroup;

  const GroupsPage({
    super.key,
    required this.store,
    required this.onOpen,
    this.onProfile,
    this.directoryRepository,
    this.messagingRepository,
    this.onCreateServerGroup,
  });

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  String query = '';
  String activeTab = 'My Groups'; // 'My Groups' or 'Explore'
  String selectedCategory = 'All'; // 'All', 'Chambers', 'Bar Associations', 'Practice Forums'

  List<DemoAdvocate>? serverAdvocates;
  List<DemoRoom>? serverGroups;
  List<DemoRoom>? discoverableServerGroups;
  StreamSubscription<void>? syncSubscription;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStoreChanged);
    _loadAll();
    syncSubscription = widget.messagingRepository?.syncAvailable.listen((_) {
      _loadServerGroups();
    });
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant GroupsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      oldWidget.store.removeListener(_onStoreChanged);
      widget.store.addListener(_onStoreChanged);
    }
    if (oldWidget.messagingRepository != widget.messagingRepository ||
        oldWidget.directoryRepository != widget.directoryRepository) {
      syncSubscription?.cancel();
      syncSubscription = widget.messagingRepository?.syncAvailable.listen((_) {
        _loadServerGroups();
      });
      _loadAll();
    }
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStoreChanged);
    syncSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => loading = true);
    await Future.wait([
      _loadServerAdvocates(),
      _loadServerGroups(),
    ]);
    if (mounted) setState(() => loading = false);
  }

  DemoRoom _summaryToRoom(ConversationSummary summary) {
    final initials = summary.title
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0])
        .take(2)
        .join();
    return DemoRoom(
      summary.id,
      summary.title,
      summary.category ?? 'Private group',
      initials.isEmpty ? 'VS' : initials,
      group: true,
      unread: summary.unreadCount,
      lastMessagePreview: summary.lastMessagePreview,
      lastMessageAt: summary.lastMessageAt ?? summary.createdAt,
      category: summary.category ?? 'Chamber Group',
      description: summary.description ?? '',
      inviteCode: summary.inviteCode,
      memberCount: summary.memberCount ?? 1,
      createdBy: summary.createdBy,
      isPublic: summary.isPublic,
    );
  }

  Future<void> _loadServerGroups() async {
    if (widget.messagingRepository == null) return;
    try {
      final repo = widget.messagingRepository!;
      final summaries = await repo.listConversations();

      List<DemoRoom>? discoverable;
      if (repo is GroupManager) {
        final discSummaries = await (repo as GroupManager).listDiscoverableGroups();
        discoverable = discSummaries.map(_summaryToRoom).toList();
      }

      if (!mounted) return;
      setState(() {
        serverGroups = summaries
            .where((summary) => summary.kind == ConversationKind.privateGroup)
            .map(_summaryToRoom)
            .toList();

        if (discoverable != null) {
          discoverableServerGroups = discoverable;
        }
      });
    } on Object {
      // Keep existing data during connectivity drops
    }
  }

  Future<void> _loadServerAdvocates() async {
    if (widget.directoryRepository == null) return;
    try {
      final result = await widget.directoryRepository!.search(query: '');
      if (!mounted) return;
      setState(() {
        final seen = <String>{};
        final list = <DemoAdvocate>[];
        for (final profile in result.items) {
          final cleanId = profile.id.startsWith('adv_')
              ? profile.id.substring(4)
              : profile.id;
          final key = cleanId.isNotEmpty ? cleanId : profile.enrollmentNumber;
          if (!seen.add(key)) continue;
          final initials = profile.fullName
              .split(' ')
              .where((part) => part.isNotEmpty)
              .map((part) => part[0])
              .take(2)
              .join();
          list.add(DemoAdvocate(
            profile.id,
            profile.fullName,
            profile.primaryCourtName ?? 'Court not provided',
            profile.enrollmentNumber,
            'Legal professional',
            initials,
          ));
        }
        serverAdvocates = list;
      });
    } on Object {
      // Creation dialog reports unavailable server members if opened
    }
  }

  bool _isJoined(DemoRoom group) {
    if (serverGroups != null &&
        serverGroups!.any((g) => g.id == group.id || g.name == group.name)) {
      return true;
    }
    if (widget.messagingRepository != null) return false;
    return widget.store.isGroupJoined(group);
  }

  List<DemoRoom> _getAllCatalog() {
    final Map<String, DemoRoom> catalog = {};

    // 1. From server discoverable groups
    if (discoverableServerGroups != null) {
      for (final g in discoverableServerGroups!) {
        catalog[g.id] = g;
      }
    }

    // 2. From server joined groups
    if (serverGroups != null) {
      for (final g in serverGroups!) {
        catalog[g.id] = g;
      }
    }

    // Only fallback if no backend messaging repository is connected
    if (widget.messagingRepository == null) {
      for (final g in widget.store.availableGroups) {
        catalog[g.id] = g;
      }
      for (final r in widget.store.rooms.where((r) => r.group)) {
        catalog[r.id] = r;
      }
    }

    return catalog.values.toList();
  }

  Future<void> _joinGroup(DemoRoom group) async {
    try {
      if (widget.messagingRepository is GroupManager) {
        final codeOrId = group.inviteCode ?? group.id;
        await (widget.messagingRepository as GroupManager).joinGroupByCode(codeOrId);
      }
      widget.store.joinGroup(group);
      await _loadServerGroups();
      if (mounted) {
        toast(context, 'Joined ${group.name} successfully!');
        setState(() {});
      }
    } catch (e) {
      if (mounted) toast(context, 'Could not join group: $e');
    }
  }

  Future<void> _leaveGroup(DemoRoom group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Leave Group?'),
        content: Text(
          'Are you sure you want to leave "${group.name}"? You will stop receiving chamber notices and chat updates.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave Group'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        if (widget.messagingRepository is GroupManager) {
          await (widget.messagingRepository as GroupManager).leaveGroup(group.id);
        }
        widget.store.leaveGroup(group.id);
        await _loadServerGroups();
        if (mounted) {
          toast(context, 'You have left ${group.name}.');
          setState(() {});
        }
      } catch (e) {
        if (mounted) toast(context, 'Could not leave group: $e');
      }
    }
  }

  Future<void> _showJoinWithCodeDialog() async {
    final codeController = TextEditingController();
    DemoRoom? previewGroup;
    String? lookupError;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          void checkCode(String input) {
            final q = input.trim().toUpperCase();
            if (q.isEmpty) {
              setDialogState(() {
                previewGroup = null;
                lookupError = null;
              });
              return;
            }

            final catalog = _getAllCatalog();
            final matches = catalog.where(
              (g) =>
                  (g.inviteCode?.toUpperCase() == q) ||
                  g.id.toUpperCase() == q ||
                  g.name.toUpperCase().contains(q),
            );

            if (matches.isNotEmpty) {
              setDialogState(() {
                previewGroup = matches.first;
                lookupError = null;
              });
            } else {
              setDialogState(() {
                previewGroup = null;
                lookupError = 'No group found with code "$q"';
              });
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.vpn_key_rounded, color: Color(0xFF0870E4), size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Join with Code', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            content: SizedBox(
              width: 380,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter the 6-character Invite Code or Group ID shared by your chamber admin.',
                      style: TextStyle(fontSize: 13, color: muted),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: codeController,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\-]')),
                      ],
                      decoration: InputDecoration(
                        hintText: 'e.g. VS-SAKET or VS-DHCBA',
                        prefixIcon: const Icon(Icons.tag_rounded, size: 20),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            codeController.clear();
                            checkCode('');
                          },
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: line),
                        ),
                      ),
                      onChanged: checkCode,
                    ),
                    if (lookupError != null && previewGroup == null) ...[
                      const SizedBox(height: 10),
                      Text(lookupError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                    ],
                    if (previewGroup != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: Row(
                          children: [
                            Avatar(previewGroup!.initials, size: 40),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    previewGroup!.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${previewGroup!.category ?? 'Chamber'} · ${previewGroup!.memberCount} members',
                                    style: const TextStyle(fontSize: 12, color: muted),
                                  ),
                                ],
                              ),
                            ),
                            if (_isJoined(previewGroup!))
                              const Text(
                                'Joined',
                                style: TextStyle(
                                  color: Color(0xFF00896C),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0870E4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: (previewGroup == null && codeController.text.trim().isEmpty)
                    ? null
                    : () async {
                        final inputCode = codeController.text.trim();
                        final targetGroup = previewGroup ?? widget.store.joinGroupByCode(inputCode);
                        if (targetGroup != null) {
                          await _joinGroup(targetGroup);
                          if (ctx.mounted) Navigator.pop(ctx);
                          widget.onOpen(targetGroup);
                        } else {
                          setDialogState(() {
                            lookupError = 'Could not resolve group code.';
                          });
                        }
                      },
                child: const Text('Join Group'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _createGroup(BuildContext context) async {
    final room = await showModalBottomSheet<DemoRoom>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateGroupSheet(
        store: widget.store,
        advocates: widget.onCreateServerGroup == null
            ? widget.store.advocates
            : (serverAdvocates ?? const []),
        onCreate: (title, memberIds, {category, description, inviteCode, isPublic}) async {
          if (widget.onCreateServerGroup != null) {
            return await widget.onCreateServerGroup!(
              title,
              memberIds,
              category: category,
              description: description,
              inviteCode: inviteCode,
              isPublic: isPublic ?? true,
            );
          } else {
            return widget.store.createGroup(
              title,
              memberIds.toSet(),
              category: category,
              description: description,
              inviteCode: inviteCode,
              isPublic: isPublic ?? true,
            );
          }
        },
      ),
    );

    if (room != null) {
      await _loadServerGroups();
      widget.onOpen(room);
    }
  }

  void _showGroupDetailsSheet(DemoRoom group) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _GroupDetailsSheet(
        group: group,
        isJoined: _isJoined(group),
        onJoin: () async {
          Navigator.pop(ctx);
          await _joinGroup(group);
        },
        onLeave: () async {
          Navigator.pop(ctx);
          await _leaveGroup(group);
        },
        onOpenChat: () {
          Navigator.pop(ctx);
          widget.onOpen(group);
        },
      ),
    );
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

    final allCatalog = _getAllCatalog();

    // Partition into My Groups and Explore Groups
    final myGroups = allCatalog.where((g) => _isJoined(g)).toList();
    final exploreGroups = allCatalog.where((g) => !_isJoined(g)).toList();

    final targetList = activeTab == 'My Groups' ? myGroups : exploreGroups;

    // Filter by query and category
    final filteredGroups = targetList.where((room) {
      final matchesQuery = room.name.toLowerCase().contains(query.toLowerCase()) ||
          (room.description?.toLowerCase().contains(query.toLowerCase()) ?? false) ||
          (room.category?.toLowerCase().contains(query.toLowerCase()) ?? false);
      if (!matchesQuery) return false;

      if (selectedCategory == 'All') return true;
      if (selectedCategory == 'Chambers') {
        return (room.category?.toLowerCase().contains('chamber') ?? false);
      }
      if (selectedCategory == 'Bar Associations') {
        return (room.category?.toLowerCase().contains('bar') ?? false);
      }
      if (selectedCategory == 'Practice Forums') {
        return (room.category?.toLowerCase().contains('forum') ?? false) ||
            (room.category?.toLowerCase().contains('circle') ?? false) ||
            (room.category?.toLowerCase().contains('practice') ?? false);
      }
      return true;
    }).toList();

    return ColoredBox(
      color: canvas,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header Top Bar with Profile Tap
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: BrandedTopBar(
                initials: headerInitials,
                onAvatarTap: widget.onProfile,
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: UniversalSearchCard(
                hint: 'Search private chambers, bar groups, topics...',
                onChanged: (value) => setState(() => query = value),
                onSubmitted: (value) => setState(() => query = value),
              ),
            ),

            // Segmented Filter Tabs: My Groups & Explore
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _TabChip(
                      label: 'My Groups',
                      count: myGroups.length,
                      selected: activeTab == 'My Groups',
                      onTap: () => setState(() => activeTab = 'My Groups'),
                      activeColor: const Color(0xFF00A884),
                    ),
                    const SizedBox(width: 8),
                    _TabChip(
                      label: 'Explore Groups',
                      count: exploreGroups.length,
                      selected: activeTab == 'Explore',
                      onTap: () => setState(() => activeTab = 'Explore'),
                      activeColor: const Color(0xFF0870E4),
                    ),
                    const SizedBox(width: 12),
                    Container(width: 1, height: 24, color: line),
                    const SizedBox(width: 12),
                    _CategoryPill(
                      label: 'All',
                      selected: selectedCategory == 'All',
                      onTap: () => setState(() => selectedCategory = 'All'),
                    ),
                    const SizedBox(width: 6),
                    _CategoryPill(
                      label: 'Chambers',
                      selected: selectedCategory == 'Chambers',
                      onTap: () => setState(() => selectedCategory = 'Chambers'),
                    ),
                    const SizedBox(width: 6),
                    _CategoryPill(
                      label: 'Bar Associations',
                      selected: selectedCategory == 'Bar Associations',
                      onTap: () => setState(() => selectedCategory = 'Bar Associations'),
                    ),
                    const SizedBox(width: 6),
                    _CategoryPill(
                      label: 'Practice Forums',
                      selected: selectedCategory == 'Practice Forums',
                      onTap: () => setState(() => selectedCategory = 'Practice Forums'),
                    ),
                  ],
                ),
              ),
            ),

            // Quick Action Row: + Create Group & Join via Code
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF00896C),
                        side: const BorderSide(color: Color(0xFF00A884), width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.vpn_key_rounded, size: 18),
                      label: const Text(
                        'Join via Code',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      onPressed: _showJoinWithCodeDialog,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0870E4),
                        foregroundColor: Colors.white,
                        elevation: 1,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text(
                        'Create Group',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      onPressed: () => _createGroup(context),
                    ),
                  ),
                ],
              ),
            ),

            // Main Groups List
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFF0870E4),
                onRefresh: _loadAll,
                child: (loading && filteredGroups.isEmpty)
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ChatConversationShimmerList(),
                      )
                    : filteredGroups.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(24),
                            children: [
                              const SizedBox(height: 30),
                              Center(
                                child: Column(
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Icon(
                                    activeTab == 'My Groups'
                                        ? Icons.group_off_rounded
                                        : Icons.travel_explore_rounded,
                                    size: 32,
                                    color: const Color(0xFF0870E4),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  activeTab == 'My Groups'
                                      ? 'No groups joined yet'
                                      : 'No groups found',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  activeTab == 'My Groups'
                                      ? 'Join an existing legal chamber with an invite code, or explore open communities.'
                                      : 'Try another search term or filter category.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 13, color: muted),
                                ),
                                const SizedBox(height: 20),
                                if (activeTab == 'My Groups')
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    alignment: WrapAlignment.center,
                                    children: [
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF0870E4),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        icon: const Icon(Icons.travel_explore_rounded, size: 18),
                                        label: const Text('Explore Groups'),
                                        onPressed: () => setState(() => activeTab = 'Explore'),
                                      ),
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFF00896C),
                                          side: const BorderSide(color: Color(0xFF00A884)),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        icon: const Icon(Icons.vpn_key_rounded, size: 18),
                                        label: const Text('Enter Code'),
                                        onPressed: _showJoinWithCodeDialog,
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: filteredGroups.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final group = filteredGroups[index];
                          final isJoined = _isJoined(group);
                          return _GroupCard(
                            group: group,
                            isJoined: isJoined,
                            onTap: () {
                              if (isJoined) {
                                widget.onOpen(group);
                              } else {
                                _showGroupDetailsSheet(group);
                              }
                            },
                            onInfoTap: () => _showGroupDetailsSheet(group),
                            onJoin: () => _joinGroup(group),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final Color activeColor;

  const _TabChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.activeColor = const Color(0xFF0870E4),
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? activeColor : const Color(0xFFCBD5E1),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF334155),
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.25)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF64748B),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE2E8F0) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final DemoRoom group;
  final bool isJoined;
  final VoidCallback onTap;
  final VoidCallback onInfoTap;
  final VoidCallback onJoin;

  const _GroupCard({
    required this.group,
    required this.isJoined,
    required this.onTap,
    required this.onInfoTap,
    required this.onJoin,
  });

  Color _categoryColor(String? category) {
    final cat = category?.toLowerCase() ?? '';
    if (cat.contains('bar')) return const Color(0xFF7C3AED); // Purple
    if (cat.contains('chamber')) return const Color(0xFF0870E4); // Blue
    if (cat.contains('circle') || cat.contains('study')) return const Color(0xFFD97706); // Amber
    return const Color(0xFF0D9488); // Teal
  }

  @override
  Widget build(BuildContext context) {
    final catColor = _categoryColor(group.category);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0.5,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Avatar, Title, Category Badge, Info Button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Avatar(group.initials, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: catColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            group.category ?? 'Chamber Group',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: catColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.info_outline_rounded, size: 20, color: Color(0xFF94A3B8)),
                    tooltip: 'Group Details',
                    onPressed: onInfoTap,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),

              // Description or Last Message Preview
              if (group.description?.isNotEmpty == true || group.lastMessagePreview != null) ...[
                const SizedBox(height: 10),
                Text(
                  group.lastMessagePreview ?? group.description ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
                ),
              ],

              const SizedBox(height: 12),

              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Members count badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.people_outline_rounded, size: 14, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text(
                                '${group.memberCount} members',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                              ),
                            ],
                          ),
                        ),

                        // Invite Code Chip (if available)
                        if (group.inviteCode != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.tag_rounded, size: 14, color: Color(0xFF0870E4)),
                                const SizedBox(width: 4),
                                Text(
                                  group.inviteCode!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0870E4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // State Action Button: Join vs Joined
                  if (isJoined)
                    InkWell(
                      onTap: onInfoTap,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F7F3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF00A884)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_rounded, size: 14, color: Color(0xFF00896C)),
                            SizedBox(width: 4),
                            Text(
                              'Joined',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF00896C),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0870E4),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text(
                        'Join Group',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      onPressed: onJoin,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateGroupSheet extends StatefulWidget {
  final DemoStore store;
  final List<DemoAdvocate> advocates;
  final Future<DemoRoom?> Function(
    String title,
    List<String> memberIds, {
    String? category,
    String? description,
    String? inviteCode,
    bool? isPublic,
  }) onCreate;

  const _CreateGroupSheet({
    required this.store,
    required this.advocates,
    required this.onCreate,
  });

  @override
  State<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<_CreateGroupSheet> {
  final nameController = TextEditingController();
  final descController = TextEditingController();
  final searchController = TextEditingController();

  String selectedCategory = 'Chamber Group';
  bool isPublic = true;
  final selectedMemberIds = <String>{};
  String memberSearchQuery = '';
  String? error;
  bool submitting = false;

  late final String generatedInviteCode =
      'VS-${Random().nextInt(9000) + 1000}';

  @override
  void dispose() {
    nameController.dispose();
    descController.dispose();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredAdvocates = widget.advocates.where((a) {
      if (memberSearchQuery.isEmpty) return true;
      final q = memberSearchQuery.toLowerCase();
      return a.name.toLowerCase().contains(q) || a.court.toLowerCase().contains(q);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Create Private Group',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Group Title
                const Text('Group Title *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameController,
                  maxLength: 60,
                  decoration: InputDecoration(
                    hintText: 'e.g. Saket Chamber Litigation Forum',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: line),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Category Selector
                const Text('Group Category', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    'Chamber Group',
                    'Bar Association',
                    'Practice Forum',
                    'Study Circle',
                  ].map((cat) {
                    final selected = selectedCategory == cat;
                    return ChoiceChip(
                      label: Text(cat),
                      selected: selected,
                      selectedColor: const Color(0xFF0870E4),
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : const Color(0xFF334155),
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onSelected: (val) {
                        if (val) setState(() => selectedCategory = cat);
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 14),

                // Description
                const Text('Purpose / Description', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: descController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Briefly state the focus of this legal group...',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: line),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Generated Invite Code
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.vpn_key_rounded, color: Color(0xFF0870E4), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Shareable Invite Code', style: TextStyle(fontSize: 11, color: muted)),
                            Text(
                              generatedInviteCode,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0870E4)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF0870E4)),
                        tooltip: 'Copy Code',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: generatedInviteCode));
                          toast(context, 'Invite code copied!');
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Colleague Selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Add Colleagues', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(
                      '${selectedMemberIds.length} selected',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF0870E4), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Search colleagues
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Search colleagues by name or court...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: line),
                    ),
                  ),
                  onChanged: (val) => setState(() => memberSearchQuery = val),
                ),

                const SizedBox(height: 10),

                // Selected members horizontal tray
                if (selectedMemberIds.isNotEmpty) ...[
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: selectedMemberIds.map((id) {
                        final adv = widget.advocates.firstWhere(
                          (a) => a.id == id,
                          orElse: () => DemoAdvocate(id, 'Colleague', '', '', '', 'VS'),
                        );
                        return Container(
                          margin: const EdgeInsets.only(right: 6),
                          child: Chip(
                            avatar: Avatar(adv.initials, size: 20),
                            label: Text(adv.name, style: const TextStyle(fontSize: 11)),
                            deleteIcon: const Icon(Icons.close_rounded, size: 14),
                            onDeleted: () => setState(() => selectedMemberIds.remove(id)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // Colleague List
                if (filteredAdvocates.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text('No verified colleagues found.', style: TextStyle(color: muted, fontSize: 12)),
                    ),
                  )
                else
                  ...filteredAdvocates.map((adv) {
                    final selected = selectedMemberIds.contains(adv.id);
                    return CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: Avatar(adv.initials, size: 36),
                      title: Text(adv.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text(adv.court, style: const TextStyle(fontSize: 11, color: muted)),
                      value: selected,
                      onChanged: (val) {
                        setState(() {
                          val == true ? selectedMemberIds.add(adv.id) : selectedMemberIds.remove(adv.id);
                        });
                      },
                    );
                  }),

                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ],
              ],
            ),
          ),

          // Bottom Submit Action
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: line)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0870E4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: submitting
                    ? null
                    : () async {
                        final title = nameController.text.trim();
                        if (title.isEmpty) {
                          setState(() => error = 'Please enter a group title.');
                          return;
                        }

                        setState(() {
                          submitting = true;
                          error = null;
                        });

                        try {
                          final room = await widget.onCreate(
                            title,
                            selectedMemberIds.toList(),
                            category: selectedCategory,
                            description: descController.text.trim(),
                            inviteCode: generatedInviteCode,
                            isPublic: isPublic,
                          );

                          if (context.mounted) {
                            Navigator.pop(context, room);
                          }
                        } catch (e) {
                          if (mounted) {
                            setState(() {
                              submitting = false;
                              error = 'Failed to create group: $e';
                            });
                          }
                        }
                      },
                child: Text(
                  submitting ? 'Creating Group...' : 'Create & Open Group',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupDetailsSheet extends StatelessWidget {
  final DemoRoom group;
  final bool isJoined;
  final VoidCallback onJoin;
  final VoidCallback onLeave;
  final VoidCallback onOpenChat;

  const _GroupDetailsSheet({
    required this.group,
    required this.isJoined,
    required this.onJoin,
    required this.onLeave,
    required this.onOpenChat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header with Avatar and Category
          Row(
            children: [
              Avatar(group.initials, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${group.category ?? 'Chamber Group'} · ${group.memberCount} members',
                      style: const TextStyle(fontSize: 12.5, color: muted),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Description Card
          if (group.description?.isNotEmpty == true) ...[
            const Text('About Group', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            Text(
              group.description!,
              style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4),
            ),
            const SizedBox(height: 14),
          ],

          // Shareable Invite Code
          if (group.inviteCode != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: line),
              ),
              child: Row(
                children: [
                  const Icon(Icons.vpn_key_rounded, size: 18, color: Color(0xFF0870E4)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Invite Code', style: TextStyle(fontSize: 11, color: muted)),
                        Text(
                          group.inviteCode!,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0870E4)),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 14),
                    label: const Text('Copy', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: group.inviteCode!));
                      toast(context, 'Invite code copied!');
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Action Buttons
          if (isJoined) ...[
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0870E4),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                    label: const Text('Open Chat', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: onOpenChat,
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.exit_to_app_rounded, size: 18),
                  label: const Text('Leave', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: onLeave,
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0870E4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Join this Group', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: onJoin,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
