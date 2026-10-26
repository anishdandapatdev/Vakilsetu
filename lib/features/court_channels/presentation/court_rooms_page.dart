import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/demo_store.dart';
import '../../../design_system/ui.dart';
import '../../documents/presentation/documents_page.dart';
import '../data/firestore_court_repository.dart';
import '../domain/court_repository.dart';

class CourtRoomsPage extends StatefulWidget {
  final DemoStore store;
  final CourtRepository? repository;
  final VoidCallback? onProfile;
  const CourtRoomsPage({
    super.key,
    required this.store,
    this.repository,
    this.onProfile,
  });

  @override
  State<CourtRoomsPage> createState() => _CourtRoomsPageState();
}

class _CourtRoomsPageState extends State<CourtRoomsPage> {
  String query = '';
  String activeFilter = 'Joined';
  CourtChannel? selectedChannel;
  List<CourtChannel>? apiCourts;
  Set<String> apiJoined = {};
  List<CourtAnnouncement>? apiNotices;
  bool loading = false;
  String? error;

  late CourtRepository _repo;
  StreamSubscription<List<CourtAnnouncement>>? _announcementsSub;

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

  static String _canonicalId(String input) {
    return input.toLowerCase().replaceAll(' ', '_');
  }

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? FirestoreCourtRepository();
    _loadCourts();
  }

  @override
  void didUpdateWidget(covariant CourtRoomsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _repo = widget.repository ?? FirestoreCourtRepository();
      _loadCourts();
    }
  }

  @override
  void dispose() {
    _announcementsSub?.cancel();
    super.dispose();
  }

  Future<void> _loadCourts() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final values = await Future.wait([
        _repo.listCourts(),
        _repo.joinedCourtIds(),
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
    final cId = _canonicalId(channel.id.isNotEmpty ? channel.id : channel.name);
    return apiJoined.contains(channel.id) ||
        apiJoined.contains(cId) ||
        widget.store.joined.contains(channel.name) ||
        widget.store.joined.contains(cId);
  }

  Future<void> _toggleJoined(CourtChannel channel) async {
    final currentlyJoined = _isJoined(channel);
    final next = !currentlyJoined;
    final cId = _canonicalId(channel.id.isNotEmpty ? channel.id : channel.name);
    setState(() {
      if (next) {
        apiJoined.add(channel.id);
        apiJoined.add(cId);
        widget.store.joined.add(channel.name);
      } else {
        apiJoined.remove(channel.id);
        apiJoined.remove(cId);
        widget.store.joined.remove(channel.name);
        widget.store.joined.remove(cId);
      }
    });

    try {
      await _repo.setJoined(channel.id, next);
      if (mounted) {
        toast(
          context,
          next
              ? 'Subscribed to ${channel.name} updates'
              : 'Left ${channel.name}',
        );
      }
    } on Object catch (exception) {
      if (!mounted) return;
      setState(() {
        if (next) {
          apiJoined.remove(channel.id);
          apiJoined.remove(cId);
          widget.store.joined.remove(channel.name);
          widget.store.joined.remove(cId);
        } else {
          apiJoined.add(channel.id);
          apiJoined.add(cId);
          widget.store.joined.add(channel.name);
        }
      });
      toast(context, 'Could not update court subscription: $exception');
    }
  }

  Future<void> _openCourt(CourtChannel channel) async {
    _announcementsSub?.cancel();
    setState(() {
      selectedChannel = channel;
      apiNotices = null;
      error = null;
    });
    final channelId = channel.channelId ?? channel.id;
    if (channelId.isEmpty) return;

    final stream = _repo.streamAnnouncements(channelId);
    if (stream != null) {
      _announcementsSub = stream.listen((notices) {
        if (mounted) {
          setState(() {
            apiNotices = notices;
            loading = false;
          });
        }
      }, onError: (err) {
        if (mounted) {
          setState(() {
            error = err.toString();
            loading = false;
          });
        }
      });
    }

    setState(() => loading = true);
    try {
      final notices = await _repo.announcements(channelId);
      if (mounted && apiNotices == null) {
        setState(() => apiNotices = notices);
      }
    } on Object catch (exception) {
      if (mounted && apiNotices == null) {
        setState(() => error = exception.toString());
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _openAddNoticeDialog(CourtChannel channel) async {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    bool attachFile = true;

    final posted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Post Court Announcement', style: heading(18)),
                        const SizedBox(height: 4),
                        Text(
                          'Publish to ${channel.name} · Cloud Firestore',
                          style: const TextStyle(color: slateBlue, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx, false),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Notice Title *',
                  hintText: 'e.g., Daily Cause List - Court No. 1',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: bodyController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Announcement Body *',
                  hintText: 'Official updates, hearing instructions, or registry notices...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: attachFile,
                onChanged: (val) => setModalState(() => attachFile = val ?? false),
                title: const Text('Attach verified Cause_list.pdf', style: TextStyle(fontSize: 13)),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0870E4),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  if (titleController.text.trim().isEmpty ||
                      bodyController.text.trim().isEmpty) {
                    toast(ctx, 'Please enter title and announcement details.');
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Publish to Firestore'),
              ),
            ],
          ),
        ),
      ),
    );

    if (posted == true) {
      try {
        await _repo.postAnnouncement(
          channelId: channel.channelId ?? channel.id,
          title: titleController.text.trim(),
          body: bodyController.text.trim(),
          attachmentKey: attachFile ? 'Cause_list.pdf' : null,
        );
        if (mounted) {
          toast(context, 'Announcement published to Firestore!');
          await _openCourt(channel);
        }
      } catch (e) {
        if (mounted) toast(context, 'Could not post announcement: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (selectedChannel != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          setState(() => selectedChannel = null);
        },
        child: _channelDetails(),
      );
    }

    final availableChannels = (apiCourts != null && apiCourts!.isNotEmpty)
        ? apiCourts!
        : courts
            .map(
              (name) => CourtChannel(
                id: name.toLowerCase().replaceAll(' ', '_'),
                channelId: name.toLowerCase().replaceAll(' ', '_'),
                name: name,
                city: 'New Delhi',
              ),
            )
            .toList();

    final joinedCount = availableChannels.where((c) => _isJoined(c)).length;
    final highCourtCount = availableChannels
        .where((c) => c.name.toLowerCase().contains('high court'))
        .length;
    final districtCount = availableChannels
        .where((c) => !c.name.toLowerCase().contains('high court'))
        .length;

    final filtered = availableChannels.where((c) {
      final matchesQuery = c.name.toLowerCase().contains(query.toLowerCase()) ||
          c.city.toLowerCase().contains(query.toLowerCase());
      if (!matchesQuery) return false;

      return switch (activeFilter) {
        'Joined' => _isJoined(c),
        'High Court' => c.name.toLowerCase().contains('high court'),
        'District' => !c.name.toLowerCase().contains('high court'),
        _ => true,
      };
    }).toList();

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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: BrandedTopBar(
                initials: headerInitials,
                onAvatarTap: widget.onProfile,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: UniversalSearchCard(
                hint: 'Search court channels or cities...',
                onChanged: (value) => setState(() => query = value),
                onSubmitted: (value) => setState(() => query = value),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All Courts',
                      count: availableChannels.length,
                      selected: activeFilter == 'All',
                      onTap: () => setState(() => activeFilter = 'All'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'My Channels',
                      count: joinedCount,
                      selected: activeFilter == 'Joined',
                      onTap: () => setState(() => activeFilter = 'Joined'),
                      activeColor: const Color(0xFF00A884),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'High Court',
                      count: highCourtCount,
                      selected: activeFilter == 'High Court',
                      onTap: () => setState(() => activeFilter = 'High Court'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'District Courts',
                      count: districtCount,
                      selected: activeFilter == 'District',
                      onTap: () => setState(() => activeFilter = 'District'),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFF0870E4),
                onRefresh: () async {
                  await _loadCourts();
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    if (loading && filtered.isEmpty)
                      const ChatConversationShimmerList()
                    else ...[
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
                    ],
                    for (final channel in filtered) ...[
                      _CourtChannelCard(
                        channel: channel,
                        imagePath: _courtPhoto(channel.name),
                        joined: _isJoined(channel),
                        onOpen: () => _openCourt(channel),
                        onJoin: () => _toggleJoined(channel),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: activeFilter == 'Joined'
                            ? Column(
                                children: [
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00A884).withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.account_balance_outlined,
                                      size: 32,
                                      color: Color(0xFF00A884),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    'No subscribed court channels',
                                    style: heading(16),
                                  ),
                                  const SizedBox(height: 6),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 32),
                                    child: Text(
                                      'Tap "+ Join" on any court channel to receive daily cause lists, roster changes, and registry circulars directly.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: slateBlue, fontSize: 12.5),
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF0870E4),
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                                    ),
                                    onPressed: () => setState(() => activeFilter = 'All'),
                                    icon: const Icon(Icons.explore_outlined, size: 18),
                                    label: const Text('Browse All Courts'),
                                  ),
                                ],
                              )
                            : EmptyState(
                                'No court found',
                                query.isNotEmpty
                                    ? 'No court matching "$query" was found.'
                                    : 'Try another filter or search term.',
                              ),
                      ),
                  ],
                ),
              ),
            ),
          ],
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
        DemoNotice(channel.name, notice.title ?? 'Official court update', notice.body),
      if (apiNotices == null || apiNotices!.isEmpty)
        ...localNotices,
    ];

    return ColoredBox(
      color: canvas,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: const Color(0xFF0870E4),
          onRefresh: () async {
            final channelId = channel.channelId ?? channel.id;
            if (channelId.isNotEmpty) {
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
                      onPressed: () {
                        _announcementsSub?.cancel();
                        setState(() => selectedChannel = null);
                      },
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0870E4).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified_rounded,
                                size: 14,
                                color: Color(0xFF0870E4),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Official Forum',
                                style: TextStyle(
                                  color: Color(0xFF0870E4),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _openAddNoticeDialog(channel),
                              icon: const Icon(Icons.add_comment_outlined, size: 16),
                              label: const Text('Post Notice'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: navy,
                                side: const BorderSide(color: Color(0xFFCFDFE8)),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (_isJoined(channel))
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFE6F7F3),
                                  foregroundColor: const Color(0xFF00896C),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: const BorderSide(color: Color(0xFF00A884)),
                                  ),
                                ),
                                onPressed: () => _toggleJoined(channel),
                                icon: const Icon(Icons.check_circle_rounded, size: 16),
                                label: const Text(
                                  'Joined',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              )
                            else
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF0870E4),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () => _toggleJoined(channel),
                                icon: const Icon(Icons.add_rounded, size: 16),
                                label: const Text(
                                  'Join Channel',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                          ],
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
                      () {
                        final (categoryText, categoryColor) =
                            _announcementCategory(notice.title, notice.body);
                        return Surface(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                alignment: WrapAlignment.spaceBetween,
                                children: [
                                  Tag(categoryText, color: categoryColor),
                                  const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.verified_rounded,
                                        size: 14,
                                        color: Color(0xFF0870E4),
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Registry Verified',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: slateBlue,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(notice.title, style: heading(17)),
                              const SizedBox(height: 8),
                              Text(
                                notice.body,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  height: 1.45,
                                  color: Color(0xFF243242),
                                ),
                              ),
                              if (notice.title.contains('Cause List') ||
                                  notice.body.contains('.pdf') ||
                                  notice.body.contains('cause list')) ...[
                                const SizedBox(height: 14),
                                const DocumentTile(
                                  name: 'Cause_list.pdf',
                                  detail: '128 KB · Verified official document',
                                ),
                              ],
                            ],
                          ),
                        );
                      }(),
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
                              'Court registry and verified advocates can post updates. Members receive real-time notifications.',
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

  (String, Color) _announcementCategory(String title, String body) {
    final lower = '$title $body'.toLowerCase();
    if (lower.contains('cause list')) {
      return ('Daily Cause List', const Color(0xFFD97706));
    }
    if (lower.contains('roster') || lower.contains('bench')) {
      return ('Bench Roster', const Color(0xFF0870E4));
    }
    if (lower.contains('maintenance') ||
        lower.contains('relocation') ||
        lower.contains('circular') ||
        lower.contains('portal')) {
      return ('Registry Circular', const Color(0xFF0D9488));
    }
    return ('Official Notice', const Color(0xFF475569));
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

  static int _memberCount(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('high court')) return 240;
    if (lower.contains('saket')) return 185;
    if (lower.contains('tis hazari')) return 310;
    if (lower.contains('patiala')) return 145;
    if (lower.contains('karkardooma')) return 160;
    if (lower.contains('rohini')) return 120;
    return 150;
  }

  void _showManageSubscription(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
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
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      imagePath,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(channel.name, style: heading(15)),
                        const SizedBox(height: 2),
                        Text(
                          '${channel.city} · ${_memberCount(channel.name)} advocates',
                          style: TextStyle(color: slateBlue, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00A884).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: Color(0xFF00A884),
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Subscription Active',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                subtitle: const Text(
                  'You receive daily cause lists and registry notices',
                  style: TextStyle(fontSize: 11.5),
                ),
                trailing: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF00A884),
                  size: 20,
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0870E4).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.open_in_new_rounded,
                    color: Color(0xFF0870E4),
                    size: 19,
                  ),
                ),
                title: const Text(
                  'Open Court Channel',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                subtitle: const Text(
                  'View all official announcements and cause lists',
                  style: TextStyle(fontSize: 11.5),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  onOpen();
                },
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4D55).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.exit_to_app_rounded,
                    color: Color(0xFFFF4D55),
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Leave Court Channel',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: Color(0xFFFF4D55),
                  ),
                ),
                subtitle: const Text(
                  'Unsubscribe from updates and alerts',
                  style: TextStyle(fontSize: 11.5),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  onJoin();
                },
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: joined
                  ? const Color(0xFFBFEADB)
                  : const Color(0xFFDCEAF3),
              width: joined ? 1.2 : 1.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0C0C6F91),
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  imagePath,
                  width: 96,
                  height: 96,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            channel.name,
                            style: heading(14.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: slateBlue,
                          size: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Official announcements & cause lists · ${channel.city}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: slateBlue, fontSize: 10),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F5FA),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.people_outline_rounded,
                                size: 12,
                                color: slateBlue,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${_memberCount(channel.name)} advocates',
                                style: const TextStyle(
                                  color: slateBlue,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF5FF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '🔒 Verified',
                            style: TextStyle(
                              color: Color(0xFF0870E4),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: joined
                          ? InkWell(
                              onTap: () => _showManageSubscription(context),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE6F7F3),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFF00A884),
                                    width: 1.1,
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      size: 15,
                                      color: Color(0xFF00A884),
                                    ),
                                    SizedBox(width: 5),
                                    Text(
                                      'Joined',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF00896C),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ElevatedButton.icon(
                              onPressed: onJoin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0870E4),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                minimumSize: const Size(80, 32),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text(
                                'Join',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
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

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final Color? activeColor;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = activeColor ?? const Color(0xFF0870E4);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? effectiveColor.withValues(alpha: 0.12)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? effectiveColor : const Color(0xFFD6E4ED),
            width: selected ? 1.4 : 1.0,
          ),
          boxShadow: [
            if (!selected)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? effectiveColor : navy,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: selected ? effectiveColor : const Color(0xFFE2EDF4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : slateBlue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
