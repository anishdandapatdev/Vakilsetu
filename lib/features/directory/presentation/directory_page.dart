import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/demo_store.dart';
import '../../../design_system/ui.dart';
import '../domain/directory_repository.dart';

class DirectoryPage extends StatefulWidget {
  final DemoStore store;
  final Future<void> Function(DemoAdvocate) onMessage;
  final String initialQuery;
  final DirectoryRepository? repository;

  const DirectoryPage({
    super.key,
    required this.store,
    required this.onMessage,
    this.initialQuery = '',
    this.repository,
  });

  @override
  State<DirectoryPage> createState() => _DirectoryPageState();
}

class _DirectoryPageState extends State<DirectoryPage> {
  late String query;
  String court = 'All courts';
  String sort = 'Relevance';
  final saved = <String>{'meera'};
  List<DemoAdvocate>? apiResults;
  bool apiLoading = false;
  String? apiError;
  Timer? searchDebounce;

  @override
  void initState() {
    super.initState();
    query = widget.initialQuery;
    if (widget.repository != null) _loadApi();
  }

  @override
  void dispose() {
    searchDebounce?.cancel();
    super.dispose();
  }

  void _scheduleApiSearch() {
    searchDebounce?.cancel();
    searchDebounce = Timer(const Duration(milliseconds: 350), _loadApi);
  }

  Future<void> _loadApi() async {
    setState(() {
      apiLoading = true;
      apiError = null;
    });
    try {
      final page = await widget.repository!.search(query: query);
      final mapped = page.items.map((profile) {
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
      if (mounted) setState(() => apiResults = mapped);
    } on Object catch (error) {
      if (mounted) setState(() => apiError = error.toString());
    } finally {
      if (mounted) setState(() => apiLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.repository == null
        ? widget.store.advocates
        : (apiResults ?? const <DemoAdvocate>[]);
    final results = source
        .where(
          (advocate) =>
              ('${advocate.name} ${advocate.court} ${advocate.practice} ${advocate.enrollment}')
                  .toLowerCase()
                  .contains(query.toLowerCase()) &&
              (court == 'All courts' || court == advocate.court),
        )
        .toList();
    if (sort == 'Name') {
      results.sort((a, b) => a.name.compareTo(b.name));
    } else if (sort == 'Court') {
      results.sort((a, b) => a.court.compareTo(b.court));
    }

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
                  initialValue: query,
                  hint: 'Search name, enrollment or specialisation',
                  onChanged: (value) {
                    setState(() => query = value);
                    if (widget.repository != null) _scheduleApiSearch();
                  },
                  trailing: IconButton(
                    tooltip: 'Filter advocates',
                    onPressed: _showCourtFilter,
                    icon: const Icon(Icons.tune_rounded, color: navy),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 26),
              sliver: SliverList.list(
                children: [
                  Row(
                    children: [
                      Text(
                        '${results.length} advocates found',
                        style: const TextStyle(
                          color: slateBlue,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      PopupMenuButton<String>(
                        initialValue: sort,
                        onSelected: (value) => setState(() => sort = value),
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'Relevance',
                            child: Text('Relevance'),
                          ),
                          PopupMenuItem(value: 'Name', child: Text('Name')),
                          PopupMenuItem(value: 'Court', child: Text('Court')),
                        ],
                        child: Row(
                          children: [
                            const Text(
                              'Sort: ',
                              style: TextStyle(color: muted, fontSize: 11),
                            ),
                            Text(
                              sort,
                              style: const TextStyle(
                                color: Color(0xFF0870E4),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: Color(0xFF0870E4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (apiLoading) const LinearProgressIndicator(minHeight: 2),
                  if (apiError != null) ...[
                    Surface(
                      color: paleBronze,
                      child: Text(
                        'Could not refresh the directory: $apiError',
                        style: const TextStyle(color: muted, fontSize: 11),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (results.isEmpty)
                    const Surface(
                      child: EmptyState(
                        'No advocates found',
                        'Try another name or clear the court filter.',
                      ),
                    ),
                  for (final advocate in results) ...[
                    _AdvocateCard(
                      advocate: advocate,
                      saved: saved.contains(advocate.id),
                      onSave: () => setState(() {
                        saved.contains(advocate.id)
                            ? saved.remove(advocate.id)
                            : saved.add(advocate.id);
                      }),
                      onMessage: () => widget.onMessage(advocate),
                      onProfile: () => _showProfile(advocate),
                    ),
                    const SizedBox(height: 11),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCourtFilter() async {
    final value = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          children: [
            Text('Filter by court', style: heading(19)),
            const SizedBox(height: 8),
            for (final item in ['All courts', ...courts])
              ListTile(
                title: Text(item),
                trailing: item == court
                    ? const Icon(Icons.check_circle_rounded, color: teal)
                    : null,
                onTap: () => Navigator.pop(context, item),
              ),
          ],
        ),
      ),
    );
    if (value != null) setState(() => court = value);
  }

  Future<void> _showProfile(DemoAdvocate advocate) => showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(advocate.name, style: heading(21)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AdvocatePhoto(advocate: advocate, size: 78),
          const SizedBox(height: 16),
          const Tag('Verified advocate'),
          const SizedBox(height: 14),
          Text(advocate.enrollment),
          const SizedBox(height: 7),
          Text(advocate.court),
          const SizedBox(height: 7),
          Text(advocate.practice),
          const SizedBox(height: 14),
          const Text(
            'Public professional details only. Phone numbers are not shown.',
            style: TextStyle(color: muted, fontSize: 11),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            widget.onMessage(advocate);
          },
          child: const Text('Message'),
        ),
      ],
    ),
  );
}

class _AdvocateCard extends StatelessWidget {
  final DemoAdvocate advocate;
  final bool saved;
  final VoidCallback onSave;
  final VoidCallback onMessage;
  final VoidCallback onProfile;

  const _AdvocateCard({
    required this.advocate,
    required this.saved,
    required this.onSave,
    required this.onMessage,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    final specialties = advocate.practice.split(' · ');
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFD7EAF4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C0C6F91),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AdvocatePhoto(advocate: advocate, size: 70),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            advocate.name,
                            overflow: TextOverflow.ellipsis,
                            style: heading(15),
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Icon(
                          Icons.verified_rounded,
                          color: Color(0xFF087DE1),
                          size: 16,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      advocate.enrollment,
                      style: const TextStyle(color: slateBlue, fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      advocate.court,
                      style: const TextStyle(color: slateBlue, fontSize: 11),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: [
                        for (final specialty in specialties.take(2))
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: paleBlue,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: line),
                            ),
                            child: Text(
                              specialty,
                              style: const TextStyle(color: navy, fontSize: 9),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: saved ? 'Remove bookmark' : 'Bookmark advocate',
                onPressed: onSave,
                style: IconButton.styleFrom(backgroundColor: paleBlue),
                icon: CustomPaint(
                  size: const Size(17, 21),
                  painter: _BookmarkPainter(filled: saved),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onMessage,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0870E4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 17),
                  label: const Text('Message'),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: OutlinedButton(
                  onPressed: onProfile,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0870E4),
                    side: const BorderSide(color: Color(0xFF0870E4)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('View Profile'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdvocatePhoto extends StatelessWidget {
  final DemoAdvocate advocate;
  final double size;
  const _AdvocatePhoto({required this.advocate, required this.size});

  @override
  Widget build(BuildContext context) {
    final asset = 'assets/images/advocates/${advocate.id}.png';
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        ClipOval(
          child: Image.asset(
            asset,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Avatar(advocate.initials, size: size),
          ),
        ),
        Container(
          width: size * .2,
          height: size * .2,
          decoration: BoxDecoration(
            color: teal,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
      ],
    );
  }
}

class _BookmarkPainter extends CustomPainter {
  final bool filled;
  const _BookmarkPainter({required this.filled});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0870E4)
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(2, 2)
      ..quadraticBezierTo(2, 1, 3.5, 1)
      ..lineTo(size.width - 3.5, 1)
      ..quadraticBezierTo(size.width - 2, 1, size.width - 2, 2)
      ..lineTo(size.width - 2, size.height - 2)
      ..lineTo(size.width / 2, size.height - 6)
      ..lineTo(2, size.height - 2)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BookmarkPainter oldDelegate) =>
      oldDelegate.filled != filled;
}
