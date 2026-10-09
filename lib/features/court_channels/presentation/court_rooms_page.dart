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
  String? selected;
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

  @override
  void initState() {
    super.initState();
    if (widget.repository != null) _loadCourts();
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

  CourtChannel? _channelFor(String name) {
    final matches = apiCourts?.where((item) => item.name == name);
    return matches == null || matches.isEmpty ? null : matches.first;
  }

  bool _joined(String name) {
    final channel = _channelFor(name);
    if (widget.repository == null) return widget.store.joined.contains(name);
    return channel != null && apiJoined.contains(channel.id);
  }

  Future<void> _toggleJoined(String name) async {
    final channel = _channelFor(name);
    if (widget.repository == null) {
      widget.store.toggleCourt(name);
      setState(() {});
      return;
    }
    if (channel == null) return;
    final next = !apiJoined.contains(channel.id);
    setState(
      () => next ? apiJoined.add(channel.id) : apiJoined.remove(channel.id),
    );
    try {
      await widget.repository!.setJoined(channel.id, next);
    } on Object catch (exception) {
      if (!mounted) return;
      setState(
        () => next ? apiJoined.remove(channel.id) : apiJoined.add(channel.id),
      );
      toast(context, 'Could not update court subscription: $exception');
    }
  }

  Future<void> _openCourt(String name) async {
    setState(() {
      selected = name;
      apiNotices = null;
      error = null;
    });
    final channel = _channelFor(name);
    if (channel?.channelId == null || widget.repository == null) return;
    setState(() => loading = true);
    try {
      final notices = await widget.repository!.announcements(
        channel!.channelId!,
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
    if (selected != null) return _channelDetails();
    final sourceCourts = widget.repository == null
        ? courts
        : (apiCourts ?? const <CourtChannel>[])
              .map((court) => court.name)
              .toList();
    final filtered = sourceCourts
        .where(
          (court) =>
              court.toLowerCase().contains(query.toLowerCase()) &&
              (!joinedOnly || _joined(court)),
        )
        .toList();
    final initials = widget.store.name
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0])
        .take(2)
        .join();

    return ColoredBox(
      color: canvas,
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: StickyBrandSearchHeader(
                initials: initials,
                search: UniversalSearchCard(
                  hint: 'Search court channels',
                  onChanged: (value) => setState(() => query = value),
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
                  for (final court in filtered) ...[
                    _CourtChannelCard(
                      name: court,
                      imagePath:
                          _courtPhotos[court] ??
                          'assets/images/courts/delhi_high_court.png',
                      joined: _joined(court),
                      onOpen: () => _openCourt(court),
                      onJoin: () => _toggleJoined(court),
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
    );
  }

  Widget _channelDetails() {
    final court = selected!;
    final localNotices = widget.store.notices
        .where((n) => n.court == court)
        .toList();
    final notices = <DemoNotice>[
      for (final notice in apiNotices ?? const <CourtAnnouncement>[])
        DemoNotice(court, 'Official court update', notice.body),
      if (widget.repository == null) ...localNotices,
    ];
    return ColoredBox(
      color: canvas,
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
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
                    onPressed: () => setState(() => selected = null),
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
                            _courtPhotos[court] ??
                                'assets/images/courts/delhi_high_court.png',
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
                                court,
                                style: heading(23)
                                    .copyWith(color: Colors.white),
                              ),
                              const SizedBox(height: 7),
                              const Text(
                                'Official announcements & cause lists',
                                style: TextStyle(color: Colors.white),
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
                        onPressed: () => _toggleJoined(court),
                        icon: Icon(
                          _joined(court)
                              ? Icons.check_circle
                              : Icons.add_circle,
                          size: 18,
                        ),
                        label: Text(_joined(court) ? 'Joined' : 'Join'),
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
                          if (widget.repository == null) ...[
                            const SizedBox(height: 16),
                            const DocumentTile(
                              name: 'Cause_list.pdf',
                              detail: '128 KB · Sample attachment',
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
    );
  }
}

class _CourtChannelCard extends StatelessWidget {
  final String name;
  final String imagePath;
  final bool joined;
  final VoidCallback onOpen;
  final VoidCallback onJoin;

  const _CourtChannelCard({
    required this.name,
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
          padding: EdgeInsets.fromLTRB(12, 0, 1, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(name, style: heading(14))),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: slateBlue,
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              const Text(
                'Official announcements & cause lists',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: slateBlue, fontSize: 9.5),
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
