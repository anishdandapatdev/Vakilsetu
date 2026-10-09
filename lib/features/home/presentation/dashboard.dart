import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../app/demo_store.dart';
import '../../../design_system/ui.dart';
import '../../conversations/domain/conversation.dart';
import '../../conversations/domain/server_messaging.dart';
import '../../court_channels/domain/court_repository.dart';

const _ice = Color(0xFFF5FBFC);
const _aqua = Color(0xFF19B7B0);
const _royal = Color(0xFF147BEA);
const _red = Color(0xFFF04444);

class Dashboard extends StatefulWidget {
  final DemoStore store;
  final ValueChanged<int> onNavigate;
  final ValueChanged<DemoRoom> onChat;
  final ValueChanged<String> onSearch;
  final MessagingRepository? messagingRepository;
  final CourtRepository? courtRepository;

  const Dashboard({
    super.key,
    required this.store,
    required this.onNavigate,
    required this.onChat,
    required this.onSearch,
    this.messagingRepository,
    this.courtRepository,
  });

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  List<DemoRoom>? rooms;
  List<DemoNotice>? notices;
  List<CourtChannel>? channels;
  List<SharedAttachment>? documents;
  String? loadError;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (widget.messagingRepository != null) {
      try {
        final summaries = await widget.messagingRepository!.listConversations();
        if (!mounted) return;
        setState(() {
          rooms = summaries.map((summary) {
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
          loadError = null;
        });
      } on Object catch (error) {
        if (mounted) {
          setState(() {
            rooms ??= [];
            loadError = 'Could not load conversations: $error';
          });
        }
      }
    }
    if (widget.messagingRepository is ServerMessaging) {
      try {
        final page = await (widget.messagingRepository! as ServerMessaging)
            .sharedAttachments();
        if (mounted) setState(() => documents = page.items.take(3).toList());
      } on Object catch (error) {
        if (mounted) {
          setState(() {
            documents ??= [];
            loadError = 'Could not load recent files: $error';
          });
        }
      }
    }
    if (widget.courtRepository != null) {
      try {
        final channels = await widget.courtRepository!.listCourts();
        if (mounted) setState(() => this.channels = channels);
        final joined = await widget.courtRepository!.joinedCourtIds();
        final joinedChannels = channels
            .where(
              (channel) =>
                  joined.contains(channel.id) && channel.channelId != null,
            )
            .take(4);
        final updates = <DemoNotice>[];
        for (final channel in joinedChannels) {
          final announcements = await widget.courtRepository!.announcements(
            channel.channelId!,
          );
          for (final announcement in announcements.take(2)) {
            updates.add(
              DemoNotice(
                channel.name,
                'Official court update',
                announcement.body,
              ),
            );
          }
        }
        if (mounted) setState(() => notices = updates);
      } on Object catch (error) {
        if (mounted) {
          setState(() {
            notices ??= [];
            channels ??= [];
            loadError = 'Could not load court updates: $error';
          });
        }
      }
    }
  }

  Future<void> _download(SharedAttachment document) async {
    final repository = widget.messagingRepository;
    if (repository is! ServerMessaging) return;
    try {
      final bytes = await (repository as ServerMessaging).downloadAttachment(
        document.id,
      );
      await FilePicker.platform.saveFile(
        dialogTitle: 'Save ${document.filename}',
        fileName: document.filename,
        bytes: Uint8List.fromList(bytes),
      );
    } on Object catch (error) {
      if (mounted) toast(context, 'Could not download file: $error');
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 760;
      final horizontal = compact ? 16.0 : 30.0;
      return ColoredBox(
        color: _ice,
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: StickyBrandSearchHeader(
                  initials: 'AK',
                  search: _Search(onSearch: widget.onSearch),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  compact ? 8 : 16,
                  horizontal,
                  compact ? 100 : 38,
                ),
                sliver: SliverToBoxAdapter(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1240),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 18),
                          _CourtHighlights(
                            onOpen: () => widget.onNavigate(3),
                            channels: widget.courtRepository == null
                                ? null
                                : (channels ?? []),
                          ),
                          const SizedBox(height: 16),
                          if ((widget.messagingRepository != null &&
                                  rooms == null) ||
                              (widget.messagingRepository is ServerMessaging &&
                                  documents == null) ||
                              (widget.courtRepository != null &&
                                  notices == null))
                            const LinearProgressIndicator(minHeight: 2),
                          if (loadError != null) ...[
                            Text(
                              loadError!,
                              style: const TextStyle(
                                color: muted,
                                fontSize: 11,
                              ),
                            ),
                            TextButton(
                              onPressed: _refresh,
                              child: const Text('Retry'),
                            ),
                          ],
                          _Metrics(
                            store: widget.store,
                            rooms: widget.messagingRepository == null
                                ? null
                                : (rooms ?? []),
                            courtUpdateCount: widget.courtRepository == null
                                ? null
                                : (notices?.length ?? 0),
                            onNavigate: widget.onNavigate,
                          ),
                          const SizedBox(height: 22),
                          _HomeSection(
                            title: 'Quick Access',
                            onSeeAll: () => widget.onNavigate(2),
                            child: _QuickAccess(onNavigate: widget.onNavigate),
                          ),
                          const SizedBox(height: 22),
                          if (compact) ...[
                            _Conversations(
                              rooms: widget.messagingRepository == null
                                  ? widget.store.rooms
                                  : (rooms ?? []),
                              onChat: widget.onChat,
                              onAll: () => widget.onNavigate(1),
                            ),
                            const SizedBox(height: 22),
                            _CourtUpdates(
                              notices: widget.courtRepository == null
                                  ? widget.store.notices
                                  : (notices ?? []),
                              sample: widget.courtRepository == null,
                              onAll: () => widget.onNavigate(3),
                            ),
                            const SizedBox(height: 22),
                            _Groups(
                              rooms: widget.messagingRepository == null
                                  ? widget.store.rooms
                                  : (rooms ?? []),
                              onChat: widget.onChat,
                              onAll: () => widget.onNavigate(4),
                            ),
                            const SizedBox(height: 22),
                            _Documents(
                              onAll: () => widget.onNavigate(5),
                              documents:
                                  widget.messagingRepository is ServerMessaging
                                  ? (documents ?? [])
                                  : null,
                              onDownload: _download,
                            ),
                          ] else ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 6,
                                  child: Column(
                                    children: [
                                      _Conversations(
                                        rooms:
                                            widget.messagingRepository == null
                                            ? widget.store.rooms
                                            : (rooms ?? []),
                                        onChat: widget.onChat,
                                        onAll: () => widget.onNavigate(1),
                                      ),
                                      const SizedBox(height: 22),
                                      _Groups(
                                        rooms:
                                            widget.messagingRepository == null
                                            ? widget.store.rooms
                                            : (rooms ?? []),
                                        onChat: widget.onChat,
                                        onAll: () => widget.onNavigate(4),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 22),
                                Expanded(
                                  flex: 5,
                                  child: Column(
                                    children: [
                                      _CourtUpdates(
                                        notices: widget.courtRepository == null
                                            ? widget.store.notices
                                            : (notices ?? []),
                                        sample: widget.courtRepository == null,
                                        onAll: () => widget.onNavigate(3),
                                      ),
                                      const SizedBox(height: 22),
                                      _Documents(
                                        onAll: () => widget.onNavigate(5),
                                        documents:
                                            widget.messagingRepository
                                                is ServerMessaging
                                            ? (documents ?? [])
                                            : null,
                                        onDownload: _download,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _Search extends StatelessWidget {
  final ValueChanged<String> onSearch;
  const _Search({required this.onSearch});

  @override
  Widget build(BuildContext context) => UniversalSearchCard(
    hint: 'Search advocates, courts, cases…',
    onChanged: (_) {},
    onSubmitted: onSearch,
  );
}

class _CourtHighlights extends StatefulWidget {
  final VoidCallback onOpen;
  final List<CourtChannel>? channels;
  const _CourtHighlights({required this.onOpen, this.channels});

  @override
  State<_CourtHighlights> createState() => _CourtHighlightsState();
}

class _CourtHighlightsState extends State<_CourtHighlights> {
  final PageController _controller = PageController(viewportFraction: .5);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final cards = widget.channels == null
          ? <_CourtFeature>[
              _CourtFeature(
                title: 'Delhi High Court',
                update: 'Revised Cause List',
                imageAsset: 'assets/images/courts/delhi_high_court.png',
                color: _royal,
                onOpen: widget.onOpen,
              ),
              _CourtFeature(
                title: 'Saket District Court',
                update: 'Administrative Notice',
                imageAsset: 'assets/images/courts/saket_district_court.png',
                color: teal,
                onOpen: widget.onOpen,
              ),
            ]
          : <_CourtFeature>[
              for (final channel in widget.channels!.take(2))
                _CourtFeature(
                  title: channel.name,
                  update: 'Official court channel',
                  imageAsset: channel.name.contains('Saket')
                      ? 'assets/images/courts/saket_district_court.png'
                      : channel.name.contains('Tis Hazari')
                      ? 'assets/images/courts/tis_hazari_courts.png'
                      : channel.name.contains('Patiala')
                      ? 'assets/images/courts/patiala_house_courts.png'
                      : 'assets/images/courts/delhi_high_court.png',
                  color: _royal,
                  onOpen: widget.onOpen,
                ),
            ];
      if (cards.isEmpty) return const SizedBox.shrink();
      if (c.maxWidth >= 530) {
        if (cards.length == 1) return cards.first;
        return Row(
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 12),
            Expanded(child: cards[1]),
          ],
        );
      }
      return Column(
        children: [
          SizedBox(
            height: 166,
            child: PageView.builder(
              controller: _controller,
              padEnds: false,
              itemCount: cards.length,
              onPageChanged: (page) => setState(() => _page = page),
              itemBuilder: (_, i) => Padding(
                padding: EdgeInsets.only(right: i == cards.length - 1 ? 0 : 10),
                child: cards[i],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _CarouselDots(selected: _page, count: cards.length),
        ],
      );
    },
  );
}

class _CourtFeature extends StatelessWidget {
  final String title, update, imageAsset;
  final Color color;
  final VoidCallback onOpen;
  const _CourtFeature({
    required this.title,
    required this.update,
    required this.imageAsset,
    required this.color,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) => Container(
    height: 166,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(14),
      boxShadow: const [
        BoxShadow(
          color: Color(0x160B3954),
          blurRadius: 16,
          offset: Offset(0, 7),
        ),
      ],
    ),
    child: Stack(
      children: [
        Positioned.fill(
          child: Image.asset(imageAsset, fit: BoxFit.cover, cacheWidth: 720),
        ),
        Positioned.fill(
          child: ColoredBox(color: Colors.white.withValues(alpha: .42)),
        ),
        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  color: navy,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                update,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: navy, fontSize: 11),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: paleBlue.withValues(alpha: .9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded, size: 12, color: slateBlue),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Admin only posts',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: slateBlue, fontSize: 9),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: onOpen,
                style: FilledButton.styleFrom(
                  backgroundColor: _aqua,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 12,
                  ),
                  minimumSize: Size.zero,
                ),
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text(
                  'View channel',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _CarouselDots extends StatelessWidget {
  final int selected, count;
  const _CarouselDots({required this.selected, required this.count});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (int i = 0; i < count; i++)
        Container(
          width: i == selected ? 14 : 7,
          height: 7,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: i == selected ? _aqua : const Color(0xFFD5E8EE),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
    ],
  );
}

class _Metrics extends StatelessWidget {
  final DemoStore store;
  final List<DemoRoom>? rooms;
  final int? courtUpdateCount;
  final ValueChanged<int> onNavigate;
  const _Metrics({
    required this.store,
    this.rooms,
    this.courtUpdateCount,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final sourceRooms = rooms ?? store.rooms;
    final unread = sourceRooms.fold<int>(0, (n, r) => n + r.unread);
    final groupUnread = sourceRooms
        .where((room) => room.group)
        .fold<int>(0, (n, r) => n + r.unread);
    final data = [
      ('chats', '$unread', 'Unread chats', 1, _aqua),
      ('documents', '${courtUpdateCount ?? 28}', 'Court updates', 3, _royal),
      (
        'groups',
        rooms == null ? '7' : '$groupUnread',
        'Group messages',
        4,
        bronze,
      ),
    ];
    return Row(
      children: [
        for (int i = 0; i < data.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: _Metric(item: data[i], onTap: () => onNavigate(data[i].$4)),
          ),
        ],
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  final (String, String, String, int, Color) item;
  final VoidCallback onTap;
  const _Metric({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(13),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
        child: LayoutBuilder(
          builder: (_, c) {
            if (c.maxWidth < 115) {
              return Column(
                children: [
                  IllustratedIcon(item.$1, size: 40),
                  const SizedBox(height: 5),
                  Text(item.$2, style: heading(17)),
                  Text(
                    item.$3,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 9, color: slateBlue),
                  ),
                ],
              );
            }
            return Row(
              children: [
                IllustratedIcon(item.$1, size: 42),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.$2, style: heading(18)),
                      Text(
                        item.$3,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, color: slateBlue),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 20, color: navy),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _HomeSection extends StatelessWidget {
  final String title;
  final VoidCallback onSeeAll;
  final Widget child;
  const _HomeSection({
    required this.title,
    required this.onSeeAll,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                height: 1.2,
                letterSpacing: -.25,
                fontWeight: FontWeight.w700,
                color: navy,
              ),
            ),
          ),
          TextButton(
            onPressed: onSeeAll,
            child: const Text(
              'See all',
              style: TextStyle(
                color: _aqua,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      child,
    ],
  );
}

class _QuickAccess extends StatelessWidget {
  final ValueChanged<int> onNavigate;
  const _QuickAccess({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('advocates', 'Find Advocate', 'Search by name or court', 2, _aqua),
      ('courts', 'Court Channels', 'Official court updates', 3, _royal),
      ('groups', 'Private Groups', 'Collaborate with peers', 4, bronze),
      ('documents', 'Shared Files', 'PDFs and documents', 5, slateBlue),
    ];
    return LayoutBuilder(
      builder: (_, c) {
        final mobile = c.maxWidth < 650;
        Widget card((String, String, String, int, Color) item) => Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onNavigate(item.$4),
            child: Container(
              padding: EdgeInsets.fromLTRB(
                mobile ? 7 : 13,
                mobile ? 9 : 13,
                mobile ? 7 : 13,
                mobile ? 8 : 12,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: const Color(0xFFDCEBF2)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0C0C6F91),
                    blurRadius: 14,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Center(
                      child: Container(
                        width: mobile ? 62 : 76,
                        height: mobile ? 62 : 76,
                        decoration: BoxDecoration(
                          color: item.$5.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        alignment: Alignment.center,
                        child: IllustratedIcon(item.$1, size: mobile ? 53 : 65),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: navy,
                      fontSize: mobile ? 9.5 : 12,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.$3,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: slateBlue,
                      fontSize: mobile ? 8 : 9,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        if (mobile) {
          final cardWidth = (c.maxWidth - 20) / 3;
          return SizedBox(
            height: 142,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, index) =>
                  SizedBox(width: cardWidth, child: card(items[index])),
            ),
          );
        }

        return SizedBox(
          height: 174,
          child: Row(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                Expanded(child: card(items[i])),
                if (i < items.length - 1) const SizedBox(width: 12),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Conversations extends StatelessWidget {
  final List<DemoRoom> rooms;
  final ValueChanged<DemoRoom> onChat;
  final VoidCallback onAll;
  const _Conversations({
    required this.rooms,
    required this.onChat,
    required this.onAll,
  });

  @override
  Widget build(BuildContext context) {
    final direct = rooms.where((r) => !r.group).take(3).toList();
    return _HomeSection(
      title: 'Recent Conversations',
      onSeeAll: onAll,
      child: Surface(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            if (direct.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No conversations yet'),
              ),
            for (int i = 0; i < direct.length; i++) ...[
              ConversationRow(room: direct[i], onTap: () => onChat(direct[i])),
              if (i < direct.length - 1) const Divider(indent: 64),
            ],
          ],
        ),
      ),
    );
  }
}

class _CourtUpdates extends StatelessWidget {
  final List<DemoNotice> notices;
  final bool sample;
  final VoidCallback onAll;
  const _CourtUpdates({
    required this.notices,
    required this.sample,
    required this.onAll,
  });

  @override
  Widget build(BuildContext context) => _HomeSection(
    title: 'From Your Courts',
    onSeeAll: onAll,
    child: notices.isEmpty
        ? const Surface(child: Text('No updates from your joined courts yet'))
        : LayoutBuilder(
            builder: (_, c) => SizedBox(
              height: 126,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: notices.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) => SizedBox(
                  width: math.min(330, c.maxWidth * .84),
                  child: _CourtUpdateCard(notice: notices[i], sample: sample),
                ),
              ),
            ),
          ),
  );
}

class _CourtUpdateCard extends StatelessWidget {
  final DemoNotice notice;
  final bool sample;
  const _CourtUpdateCard({required this.notice, required this.sample});

  String get imagePath => notice.court.contains('Saket')
      ? 'assets/images/courts/saket_district_court_list.png'
      : notice.court.contains('Tis Hazari')
      ? 'assets/images/courts/tis_hazari_courts.png'
      : notice.court.contains('Patiala')
      ? 'assets/images/courts/patiala_house_courts.png'
      : 'assets/images/courts/delhi_high_court_list.png';

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFD7EAF4)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0C0C6F91),
          blurRadius: 14,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            imagePath,
            width: 112,
            height: 108,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: paleBlue,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_rounded, size: 11, color: slateBlue),
                        SizedBox(width: 4),
                        Text(
                          'ADMIN POST',
                          style: TextStyle(
                            fontSize: 7.5,
                            color: slateBlue,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 19,
                    color: slateBlue,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                notice.court,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: navy,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                notice.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: slateBlue),
              ),
              const Spacer(),
              if (sample)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'PDF',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Cause_List.pdf · 2.4 MB',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 8, color: muted),
                      ),
                    ),
                    const Icon(Icons.download_rounded, size: 18, color: _royal),
                  ],
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Groups extends StatelessWidget {
  final List<DemoRoom> rooms;
  final ValueChanged<DemoRoom> onChat;
  final VoidCallback onAll;
  const _Groups({
    required this.rooms,
    required this.onChat,
    required this.onAll,
  });

  @override
  Widget build(BuildContext context) {
    final groups = rooms.where((r) => r.group).take(3).toList();
    return _HomeSection(
      title: 'Your Groups',
      onSeeAll: onAll,
      child: Surface(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            if (groups.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No groups yet'),
              ),
            for (int i = 0; i < groups.length; i++) ...[
              InkWell(
                onTap: () => onChat(groups[i]),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Avatar(groups[i].initials, group: true, size: 38),
                      const SizedBox(width: 11),
                      SizedBox(
                        width: 130,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              groups[i].name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              groups[i].subtitle,
                              style: const TextStyle(fontSize: 9, color: muted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          groups[i].lastMessagePreview ??
                              (groups[i].messages.isEmpty
                                  ? 'Start the conversation'
                                  : groups[i].messages.last.text),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 9, color: slateBlue),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: navy,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              if (i < groups.length - 1) const Divider(indent: 62),
            ],
          ],
        ),
      ),
    );
  }
}

class _Documents extends StatelessWidget {
  final VoidCallback onAll;
  final List<SharedAttachment>? documents;
  final ValueChanged<SharedAttachment> onDownload;
  const _Documents({
    required this.onAll,
    required this.documents,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final docs = <(String, String, SharedAttachment?)>[
      if (documents == null) ...[
        ('Petition_draft.pdf', '2.4 MB · 5 Sep', null),
        ('Court_order.pdf', '1.1 MB · 4 Sep', null),
        ('Evidence_01.jpg', '950 KB · 3 Sep', null),
      ] else
        for (final document in documents!.take(3))
          (
            document.filename,
            '${(document.byteSize / 1024).round()} KB · ${document.conversationTitle}',
            document,
          ),
    ];
    return _HomeSection(
      title: 'Recent Documents',
      onSeeAll: onAll,
      child: docs.isEmpty
          ? const Surface(
              child: Text('No files shared in your conversations yet'),
            )
          : SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: docs.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) => InkWell(
                  onTap: () =>
                      docs[i].$3 == null ? onAll() : onDownload(docs[i].$3!),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 230,
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: line),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 44,
                          decoration: BoxDecoration(
                            color: i == 2 ? paleBlue : const Color(0xFFFFEFF0),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Icon(
                            i == 2
                                ? Icons.image_rounded
                                : Icons.picture_as_pdf_rounded,
                            color: i == 2 ? _royal : _red,
                            size: 25,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                docs[i].$1,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                docs[i].$2,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 8,
                                  color: muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          docs[i].$3 == null
                              ? Icons.chevron_right_rounded
                              : Icons.download_rounded,
                          size: 19,
                          color: navy,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class ConversationRow extends StatelessWidget {
  final DemoRoom room;
  final VoidCallback onTap;
  final bool selected;
  const ConversationRow({
    super.key,
    required this.room,
    required this.onTap,
    this.selected = false,
  });

  String _timeLabel(BuildContext context) {
    final timestamp = room.lastMessageAt?.toLocal();
    if (timestamp == null) return room.unread > 0 ? '11:20 AM' : 'Yesterday';
    final now = DateTime.now();
    if (timestamp.year == now.year &&
        timestamp.month == now.month &&
        timestamp.day == now.day) {
      return TimeOfDay.fromDateTime(timestamp).format(context);
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (timestamp.year == yesterday.year &&
        timestamp.month == yesterday.month &&
        timestamp.day == yesterday.day) {
      return 'Yesterday';
    }
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? paleBlue : Colors.transparent,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        child: Row(
          children: [
            Avatar(room.initials, group: room.group, size: 41),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          room.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (!room.group) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified_rounded,
                          size: 13,
                          color: Color(0xFF1684D8),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    room.lastMessagePreview ??
                        (room.messages.isEmpty
                            ? 'Start a conversation'
                            : room.messages.last.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 9, color: slateBlue),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _timeLabel(context),
                  style: const TextStyle(fontSize: 8, color: slateBlue),
                ),
                const SizedBox(height: 7),
                if (room.unread > 0)
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: _aqua,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${room.unread}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                else
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 19,
                    color: navy,
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
