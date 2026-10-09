import 'package:flutter/material.dart';

import '../design_system/ui.dart';
import 'demo_store.dart';
import '../features/home/presentation/dashboard.dart';
import '../features/chats/presentation/messages_page.dart';
import '../features/directory/presentation/directory_page.dart';
import '../features/court_channels/presentation/court_rooms_page.dart';
import '../features/private_groups/presentation/groups_page.dart';
import '../features/documents/presentation/documents_page.dart';
import '../features/profile/presentation/profile_page.dart';
import '../features/authentication/presentation/login_page.dart';
import '../features/authentication/domain/auth_repository.dart';
import '../features/authentication/data/api_auth_repository.dart';
import '../features/directory/data/api_advocates_repository.dart';
import '../features/court_channels/data/api_court_repository.dart';
import '../features/chats/data/api_messaging_repository.dart';
import '../features/chats/domain/conversation.dart';
import '../features/chats/domain/server_messaging.dart';

class AppShell extends StatefulWidget {
  final DemoStore store;
  final bool startProfile;
  final AuthRepository? authRepository;
  const AppShell({
    super.key,
    required this.store,
    this.startProfile = false,
    this.authRepository,
  });
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int selected = 0;
  DemoRoom? activeRoom;
  bool conversationOpen = false;
  String directoryQuery = '';
  MessagingRepository? messagingRepository;
  final labels = [
    'Home',
    'Chats',
    'Advocates',
    'Courts',
    'Groups',
    'Documents',
    'Profile',
    'Settings',
  ];
  final icons = [
    'home',
    'chats',
    'advocates',
    'courts',
    'groups',
    'documents',
    'verified',
    'settings',
  ];
  @override
  void initState() {
    super.initState();
    selected = widget.startProfile ? 6 : 0;
    if (widget.authRepository is ApiAuthRepository) {
      messagingRepository = ApiMessagingRepository(
        widget.authRepository! as ApiAuthRepository,
      );
    }
  }

  @override
  void dispose() {
    messagingRepository?.close();
    widget.store.dispose();
    super.dispose();
  }

  void go(int n) => setState(() {
    selected = n;
    if (n != 1) {
      activeRoom = null;
      conversationOpen = false;
    }
  });
  void chat(DemoRoom room) {
    widget.store.read(room);
    setState(() {
      activeRoom = room;
      conversationOpen = true;
      selected = 1;
    });
  }

  DemoRoom _roomFromSummary(ConversationSummary summary) {
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
  }

  Future<void> startAdvocateChat(DemoAdvocate advocate) async {
    final isServerAdvocate =
        RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(advocate.id);
    if (!isServerAdvocate || messagingRepository is! ConversationCreator) {
      chat(widget.store.openAdvocate(advocate));
      return;
    }
    try {
      final summary = await (messagingRepository! as ConversationCreator)
          .createDirect(advocate.id);
      if (mounted) chat(_roomFromSummary(summary));
    } on Object catch (error) {
      if (mounted) toast(context, 'Could not start conversation: $error');
    }
  }

  Future<DemoRoom?> createServerGroup(
    String title,
    List<String> memberIds,
  ) async {
    if (messagingRepository is! ConversationCreator) return null;
    final summary = await (messagingRepository! as ConversationCreator)
        .createGroup(title, memberIds);
    return _roomFromSummary(summary);
  }

  void search(String q) {
    setState(() {
      directoryQuery = q;
      selected = 2;
    });
  }

  Future<void> signOut() async {
    await widget.authRepository?.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LoginPage(authRepository: widget.authRepository),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final wide = MediaQuery.sizeOf(context).width >= 980;
      final store = widget.store;
      final advocatesRepository = widget.authRepository is ApiAuthRepository
          ? ApiAdvocatesRepository(widget.authRepository! as ApiAuthRepository)
          : null;
      final courtRepository = widget.authRepository is ApiAuthRepository
          ? ApiCourtRepository(widget.authRepository! as ApiAuthRepository)
          : null;
      final pages = [
        Dashboard(
          store: store,
          onNavigate: go,
          onChat: chat,
          onSearch: search,
          messagingRepository: messagingRepository,
          courtRepository: courtRepository,
        ),
        MessagesPage(
          store: store,
          repository: messagingRepository,
          initialRoom: activeRoom,
          onConversationChanged: (open) {
            if (conversationOpen == open) return;
            setState(() {
              conversationOpen = open;
              if (!open) activeRoom = null;
            });
          },
        ),
        DirectoryPage(
          store: store,
          repository: advocatesRepository,
          onMessage: startAdvocateChat,
          initialQuery: directoryQuery,
        ),
        CourtRoomsPage(store: store, repository: courtRepository),
        GroupsPage(
          store: store,
          onOpen: chat,
          directoryRepository: advocatesRepository,
          messagingRepository: messagingRepository,
          onCreateServerGroup: messagingRepository is ConversationCreator
              ? createServerGroup
              : null,
        ),
        DocumentsPage(
          repository: messagingRepository is ServerMessaging
              ? messagingRepository! as ServerMessaging
              : null,
        ),
        ProfilePage(
          store: store,
          repository: advocatesRepository,
          onSaved: () => go(0),
        ),
        SettingsPage(store: store, onProfile: () => go(6), onSignOut: signOut),
      ];
      Widget nav() => Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 26, 15, 24),
            child: Brand(),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'YOUR WORKSPACE',
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 1.7,
                  color: muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < 6; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Material(
                color: selected == i ? paleBlue : Colors.white,
                borderRadius: BorderRadius.circular(9),
                child: ListTile(
                  onTap: () {
                    go(i);
                    if (!wide) Navigator.pop(context);
                  },
                  leading: LegalIcon(
                    icons[i],
                    size: 29,
                    color: i == 4 ? bronze : teal,
                  ),
                  title: Text(
                    labels[i],
                    style: TextStyle(
                      fontWeight: selected == i
                          ? FontWeight.w700
                          : FontWeight.w500,
                      fontSize: 13,
                      color: ink,
                    ),
                  ),
                  trailing:
                      i == 1 &&
                          store.rooms.fold<int>(0, (n, r) => n + r.unread) > 0
                      ? Tag(
                          '${store.rooms.fold<int>(0, (n, r) => n + r.unread)}',
                        )
                      : null,
                ),
              ),
            ),
          const Spacer(),
          const Divider(),
          ListTile(
            onTap: () {
              go(6);
              if (!wide) Navigator.pop(context);
            },
            leading: Avatar(
              store.name
                  .split(' ')
                  .map((s) => s.isEmpty ? '' : s[0])
                  .take(2)
                  .join(),
            ),
            title: Text(
              store.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            subtitle: Text(
              store.pending ? 'Verification pending' : 'Demo advocate',
              style: const TextStyle(fontSize: 10, color: teal),
            ),
          ),
          ListTile(
            onTap: () {
              go(7);
              if (!wide) Navigator.pop(context);
            },
            leading: const Icon(
              Icons.settings_outlined,
              color: muted,
              size: 23,
            ),
            title: const Text('Settings', style: TextStyle(fontSize: 13)),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Tag('LOCAL UI PREVIEW'),
          ),
        ],
      );
      return Scaffold(
        appBar: wide || selected <= 4
            ? null
            : AppBar(
                title: const Brand(small: true),
                actions: [
                  IconButton(
                    tooltip: 'Your profile',
                    onPressed: () => go(6),
                    icon: const Icon(Icons.account_circle_outlined),
                  ),
                ],
              ),
        drawer: wide
            ? null
            : Drawer(
                backgroundColor: Colors.white,
                child: SafeArea(child: nav()),
              ),
        body: Row(
          children: [
            if (wide)
              Container(
                width: 236,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(right: BorderSide(color: line)),
                ),
                child: nav(),
              ),
            Expanded(
              child: Column(
                children: [
                  if (wide)
                    Container(
                      height: 49,
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(bottom: BorderSide(color: line)),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Workspace  /  ${labels[selected]}',
                            style: const TextStyle(fontSize: 11, color: muted),
                          ),
                          const Spacer(),
                          Tag(widget.authRepository == null ? 'Local preview' : 'Connected'),
                          const SizedBox(width: 14),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  Expanded(child: pages[selected]),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: wide || conversationOpen
            ? null
            : SafeArea(
                minimum: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x180B3954),
                        blurRadius: 22,
                        offset: Offset(0, 7),
                      ),
                    ],
                  ),
                  child: NavigationBar(
                    height: 68,
                    backgroundColor: Colors.white,
                    elevation: 0,
                    indicatorColor: Colors.transparent,
                    selectedIndex: selected < 5 ? selected : 0,
                    onDestinationSelected: go,
                    destinations: [
                      for (int i = 0; i < 5; i++)
                        NavigationDestination(
                          icon: IllustratedIcon(
                            icons[i],
                            size: selected == i ? 38 : 34,
                          ),
                          label: labels[i],
                        ),
                    ],
                  ),
                ),
              ),
      );
    },
  );
}
