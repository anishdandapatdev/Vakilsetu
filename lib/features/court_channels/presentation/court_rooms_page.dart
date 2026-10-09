import 'package:flutter/material.dart';

import '../../../app/demo_store.dart';
import '../../../design_system/ui.dart';
import '../../documents/presentation/documents_page.dart';
import '../domain/court_repository.dart';

class CourtRoomsPage extends StatefulWidget {
  final DemoStore store;
  final CourtRepository? repository;
  const CourtRoomsPage({super.key, required this.store, this.repository});

  @override
  State<CourtRoomsPage> createState() => _CourtRoomsPageState();
}

class _CourtRoomsPageState extends State<CourtRoomsPage> {
  String query = '';
  bool joinedOnly = false;
  CourtChannel? selectedChannel;
  List<CourtChannel>? apiCourts;
  Set<String> apiJoined = {};
  List<CourtAnnouncement>? apiNotices;
  bool loading = false;
  String? error;

  static const _courtPhotos = {
    'Delhi High Court': 'assets/images/courts/delhi_high_court_list.png',
    'Saket District Court':
        'assets/images/courts/saket_district_court_list.png',
    'Tis Hazari Courts': 'assets/images/courts/tis_hazari_courts.png',
    'Patiala House Courts': 'assets/images/courts/patiala_house_courts.png',
    'Karkardooma Courts': 'assets/images/courts/delhi_high_court.png',
    'Rohini District Court': 'assets/images/courts/saket_district_court.png',
  };

  static String _courtPhoto(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('saket')) {
      return 'assets/images/courts/saket_district_court_list.png';
    }
    if (lower.contains('tis hazari')) {
      return 'assets/images/courts/tis_hazari_courts.png';
    }
    if (lower.contains('patiala')) {
      return 'assets/images/courts/patiala_house_courts.png';
    }
    if (lower.contains('rouse')) {
      return 'assets/images/courts/delhi_high_court.png';
    }
    if (lower.contains('rohini')) {
      return 'assets/images/courts/saket_district_court.png';
    }
    if (lower.contains('karkardooma')) {
      return 'assets/images/courts/delhi_high_court.png';
    }
    return _courtPhotos[name] ?? 'assets/images/courts/delhi_high_court_list.png';
  }

  @override
  void initState() {
    super.initState();
    if (widget.repository != null) _loadCourts();
  }

  @override
  void didUpdateWidget(covariant CourtRoomsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository && widget.repository != null) {
      _loadCourts();
    }
  }

  Future<void> _loadCourts() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final values = await Future.wait([
        widget.repository!.listCourts(),
        widget.repository!.joinedCourtIds(),
      ]);
      if (!mounted) return;
      setState(() {
        apiCourts = values[0] as List<CourtChannel>;
        apiJoined = values[1] as Set<String>;
      });
    } on Object catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  bool _isJoined(CourtChannel channel) {
    if (widget.repository == null) {
      return widget.store.joined.contains(channel.name);
    }
    return apiJoined.contains(channel.id) ||
        widget.store.joined.contains(channel.name);
  }

  Future<void> _toggleJoined(CourtChannel channel) async {
    final currentlyJoined = _isJoined(channel);
    final next = !currentlyJoined;
    setState(() {
      if (next) {
        apiJoined.add(channel.id);
        widget.store.joined.add(channel.name);
      } else {
        apiJoined.remove(channel.id);
        widget.store.joined.remove(channel.name);
      }
    });

    if (widget.repository == null) return;
    final isUuid = RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(channel.id);
    if (!isUuid) return;

    try {
      await widget.repository!.setJoined(channel.id, next);
    } on Object catch (exception) {
      if (!mounted) return;
      setState(() {
        if (next) {
          apiJoined.remove(channel.id);
          widget.store.joined.remove(channel.name);
        } else {
          apiJoined.add(channel.id);
          widget.store.joined.add(channel.name);
        }
      });
      toast(context, 'Could not update court subscription: $exception');
    }
  }

  Future<void> _openCourt(CourtChannel channel) async {
    setState(() {
      selectedChannel = channel;
      apiNotices = null;
      error = null;
    });
    if (channel.channelId == null || widget.repository == null) return;
    setState(() => loading = true);
    try {
      final notices = await widget.repository!.announcements(
        channel.channelId!,
      );
      if (mounted) setState(() => apiNotices = notices);
    } on Object catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (selectedChannel != null) return _channelDetails();

    final availableChannels = (apiCourts != null && apiCourts!.isNotEmpty)
        ? apiCourts!
        : courts
            .map(
              (name) => CourtChannel(
                id: name,
                channelId: null,
                name: name,
                city: 'New Delhi',
              ),
            )
            .toList();

    final filtered = availableChannels
        .where(
          (c) =>
              (c.name.toLowerCase().contains(query.toLowerCase()) ||
                  c.city.toLowerCase().contains(query.toLowerCase())) &&
              (!joinedOnly || _isJoined(c)),
        )
        .toList();

    final initials = widget.store.name
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase())
        .take(2)
        .join();
    final headerInitials = initials.isEmpty ? 'VS' : initials;

    return ColoredBox(
      color: canvas,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: const Color(0xFF0870E4),
          onRefresh: () async {
            if (widget.repository != null) await _loadCourts();
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: StickyBrandSearchHeader(
                  initials: headerInitials,
                  search: UniversalSearchCard(
                    hint: 'Search court channels',
                    onChanged: (value) => setState(() => query = value),
                    onSubmitted: (value) => setState(() => query = value),
                    trailing: IconButton(
                      tooltip: joinedOnly
                          ? 'Show all courts'
                          : 'Show joined courts',
                      onPressed: () => setState(() => joinedOnly = !joinedOnly),
                      icon: Icon(
                        joinedOnly
                            ? Icons.filter_alt_rounded
                            : Icons.tune_rounded,
                        color: navy,
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverList.list(
                  children: [
                    if (loading) const LinearProgressIndicator(minHeight: 2),
                    if (error != null) ...[
                      Surface(
                        color: paleBronze,
                        child: Text(
                          'Could not refresh courts: $error',
                          style: const TextStyle(color: muted, fontSize: 11),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    for (final channel in filtered) ...[
                      _CourtChannelCard(
                        channel: channel,
                        imagePath: _courtPhoto(channel.name),
                        joined: _isJoined(channel),
                        onOpen: () => _openCourt(channel),
                        onJoin: () => _toggleJoined(channel),
                      ),
                      const SizedBox(height: 11),
                    ],
                    if (filtered.isEmpty)
                      const EmptyState(
                        'No court found',
                        'Try another court name.',
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _channelDetails() {
    final channel = selectedChannel!;
    final localNotices = widget.store.notices
        .where((n) => n.court == channel.name)
        .toList();
    final notices = <DemoNotice>[
      for (final notice in apiNotices ?? const <CourtAnnouncement>[])
        DemoNotice(channel.name, 'Official court update', notice.body),
      if (widget.repository == null ||
          (apiNotices != null && apiNotices!.isEmpty))
        ...localNotices,
    ];

    return ColoredBox(
      color: canvas,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: const Color(0xFF0870E4),
          onRefresh: () async {
            if (channel.channelId != null && widget.repository != null) {
              await _openCourt(channel);
            }
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                sliver: SliverList.list(
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () => setState(() => selectedChannel = null),
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('All court channels'),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        alignment: Alignment.bottomLeft,
                        children: [
                          AspectRatio(
                            aspectRatio: 1.8,
                            child: Image.asset(
                              _courtPhoto(channel.name),
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Color(0xD9163150)],
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  channel.name,
                                  style: heading(23)
                                      .copyWith(color: Colors.white),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  'Official announcements & cause lists · ${channel.city}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Tag('Read only', color: slateBlue),
                        const Spacer(),
                        OutlinedButton.icon(
                          onPressed: () => _toggleJoined(channel),
                          icon: Icon(
                            _isJoined(channel)
                                ? Icons.check_circle
                                : Icons.add_circle,
                            size: 18,
                          ),
                          label: Text(_isJoined(channel) ? 'Joined' : 'Join'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    if (loading) const LinearProgressIndicator(minHeight: 2),
                    if (error != null) ...[
                      Text(
                        'Could not load announcements: $error',
                        style: const TextStyle(color: muted, fontSize: 11),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (notices.isEmpty)
                      const Surface(
                        child: EmptyState(
                          'No announcements yet',
                          'New court updates will appear here.',
                        ),
                      ),
                    for (final notice in notices) ...[
                      Surface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Tag('Official announcement', color: slateBlue),
                            const SizedBox(height: 14),
                            Text(notice.title, style: heading(18)),
                            const SizedBox(height: 10),
                            Text(notice.body),
                            if (notice.title.contains('Cause List') ||
                                notice.body.contains('.pdf') ||
                                widget.repository == null) ...[
                              const SizedBox(height: 16),
                              const DocumentTile(
                                name: 'Cause_list.pdf',
                                detail: '128 KB · Verified official document',
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    const Surface(
                      color: paleBlue,
                      child: Row(
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 18,
                            color: slateBlue,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Only court admins can post. Members can read verified updates.',
                              style: TextStyle(color: muted, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CourtChannelCard extends StatelessWidget {
  final CourtChannel channel;
  final String imagePath;
  final bool joined;
  final VoidCallback onOpen;
  final VoidCallback onJoin;

  const _CourtChannelCard({
    required this.channel,
    required this.imagePath,
    required this.joined,
    required this.onOpen,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 430;
      final photo = ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.asset(
          imagePath,
          width: compact ? 118 : 132,
          height: compact ? 94 : 126,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
        ),
      );
      final content = Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 1, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(channel.name, style: heading(14))),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: slateBlue,
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Official announcements & cause lists · ${channel.city}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: slateBlue, fontSize: 9.5),
              ),
              const SizedBox(height: 6),
              const Tag('🔒  Read only', color: slateBlue),
              if (!compact) ...[const Spacer(), _actionRow()],
            ],
          ),
        ),
      );
      return Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD7EAF4)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x100C6F91),
                  blurRadius: 18,
                  offset: Offset(0, 7),
                ),
              ],
            ),
            child: compact
                ? Column(
                    children: [
                      SizedBox(
                        height: 94,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [photo, content],
                        ),
                      ),
                      const SizedBox(height: 9),
                      _actionRow(),
                    ],
                  )
                : SizedBox(
                    height: 126,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [photo, content],
                    ),
                  ),
          ),
        ),
      );
    },
  );

  Widget _actionRow() => Row(
    children: [
      Expanded(
        flex: 6,
        child: TextButton.icon(
          onPressed: onOpen,
          style: TextButton.styleFrom(
            backgroundColor: const Color(0xFFF0F7FF),
            foregroundColor: const Color(0xFF0870E4),
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(11),
              side: const BorderSide(color: Color(0xFFC8E2FF)),
            ),
          ),
          icon: const Icon(Icons.open_in_new_rounded, size: 17),
          label: const Text(
            'Open Channel',
            maxLines: 1,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ),
      ),
      const SizedBox(width: 9),
      Expanded(
        flex: 5,
        child: OutlinedButton.icon(
          onPressed: onJoin,
          style: OutlinedButton.styleFrom(
            foregroundColor: teal,
            backgroundColor: const Color(0xFFF7FFFD),
            side: const BorderSide(color: teal, width: 1.2),
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(11),
            ),
          ),
          icon: Icon(joined ? Icons.check_circle : Icons.add_circle, size: 18),
          label: Text(
            joined ? 'Joined' : 'Join',
            maxLines: 1,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ),
      ),
    ],
  );
}
