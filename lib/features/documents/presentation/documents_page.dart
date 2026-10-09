import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../design_system/ui.dart';
import '../../conversations/domain/server_messaging.dart';

const sampleDocuments = [
  'Petition_draft.pdf',
  'Court_order.pdf',
  'Cause_list.pdf',
  'Evidence_photo.jpg',
];

class DocumentsPage extends StatefulWidget {
  final ServerMessaging? repository;
  const DocumentsPage({super.key, this.repository});
  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  String query = '', filter = 'All';
  List<SharedAttachment> documents = [];
  String? nextCursor, loadError;
  bool loading = false;
  Timer? searchDebounce;
  int requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    if (widget.repository != null) _load();
  }

  @override
  void dispose() {
    searchDebounce?.cancel();
    super.dispose();
  }

  void _filtersChanged({bool immediate = false}) {
    if (widget.repository == null) return;
    searchDebounce?.cancel();
    requestGeneration++;
    setState(() {
      documents = [];
      nextCursor = null;
      loadError = null;
      loading = false;
    });
    if (immediate) {
      _load();
    } else {
      searchDebounce = Timer(const Duration(milliseconds: 300), _load);
    }
  }

  Future<void> _load({bool more = false}) async {
    if (loading || widget.repository == null) return;
    final generation = requestGeneration;
    final search = query.trim();
    final boundedSearch = search.length > 100
        ? search.substring(0, 100)
        : search;
    final kind = switch (filter) {
      'PDFs' => 'pdf',
      'Images' => 'images',
      _ => 'all',
    };
    setState(() {
      loading = true;
      loadError = null;
    });
    try {
      final page = await widget.repository!.sharedAttachments(
        before: more ? nextCursor : null,
        search: boundedSearch,
        kind: kind,
      );
      if (!mounted || generation != requestGeneration) return;
      setState(() {
        documents = more ? [...documents, ...page.items] : page.items;
        nextCursor = page.nextCursor;
      });
    } on Object catch (error) {
      if (mounted && generation == requestGeneration) {
        setState(() => loadError = error.toString());
      }
    } finally {
      if (mounted && generation == requestGeneration) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _download(SharedAttachment document) async {
    try {
      final bytes = await widget.repository!.downloadAttachment(document.id);
      await FilePicker.platform.saveFile(
        dialogTitle: 'Save ${document.filename}',
        fileName: document.filename,
        bytes: Uint8List.fromList(bytes),
      );
    } on Object catch (error) {
      if (mounted) toast(context, 'Could not download file: $error');
    }
  }

  bool _matches(String name) =>
      name.toLowerCase().contains(query.toLowerCase()) &&
      (filter == 'All' ||
          (filter == 'PDFs'
              ? name.toLowerCase().endsWith('.pdf')
              : RegExp(
                  r'\.(jpe?g|png)$',
                  caseSensitive: false,
                ).hasMatch(name)));

  @override
  Widget build(BuildContext context) {
    final docs = sampleDocuments.where(_matches).toList();
    final shared = documents;
    return PageBody(
      children: [
        PageTitle(
          'Documents',
          widget.repository == null
              ? 'Sample files for exploring the design.'
              : 'Recent files shared in your conversations.',
        ),
        SearchBox(
          hint: widget.repository == null
              ? 'Search sample documents'
              : 'Search shared documents',
          onChanged: (v) {
            setState(() => query = v);
            _filtersChanged();
          },
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 9,
          children: [
            for (final f in ['All', 'PDFs', 'Images'])
              ChoiceChip(
                label: Text(f),
                selected: filter == f,
                onSelected: (_) {
                  setState(() => filter = f);
                  _filtersChanged(immediate: true);
                },
              ),
          ],
        ),
        const SizedBox(height: 20),
        Surface(
          child: Column(
            children: [
              if (loading) const LinearProgressIndicator(minHeight: 2),
              if (loadError != null) ...[
                Text('Could not load shared files: $loadError'),
                TextButton(
                  onPressed: () => _load(more: documents.isNotEmpty),
                  child: const Text('Retry'),
                ),
              ],
              if (widget.repository == null && docs.isEmpty ||
                  widget.repository != null &&
                      shared.isEmpty &&
                      !loading &&
                      loadError == null)
                const EmptyState(
                  'No matching documents',
                  'Try a different name or file type.',
                ),
              for (final d
                  in widget.repository == null ? docs : const <String>[]) ...[
                DocumentTile(
                  name: d,
                  detail: d.endsWith('.pdf')
                      ? '1.2 MB · PDF · Sample file'
                      : '860 KB · Image · Sample file',
                ),
                const SizedBox(height: 13),
              ],
              for (final document in shared) ...[
                DocumentTile(
                  name: document.filename,
                  detail:
                      '${(document.byteSize / 1024).round()} KB · ${document.conversationTitle}',
                  onTap: () => _download(document),
                ),
                const SizedBox(height: 13),
              ],
              if (widget.repository != null && nextCursor != null)
                TextButton(
                  onPressed: loading ? null : () => _load(more: true),
                  child: const Text('Load more files'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (widget.repository == null)
          const Text(
            'Sample documents only. No real files are opened in demo mode.',
            style: TextStyle(color: muted, fontSize: 11),
          ),
      ],
    );
  }
}

class DocumentTile extends StatelessWidget {
  final String name, detail;
  final VoidCallback? onTap;
  const DocumentTile({
    super.key,
    required this.name,
    required this.detail,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) => Material(
    color: canvas,
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap ?? () => openDocument(context, name),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            LegalIcon(
              'documents',
              size: 34,
              color: name.endsWith('.pdf') ? bronze : teal,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    style: const TextStyle(color: muted, fontSize: 9),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              onTap == null ? Icons.open_in_full : Icons.download_rounded,
              size: 15,
              color: slateBlue,
            ),
          ],
        ),
      ),
    ),
  );
}

void openDocument(BuildContext context, String name) => Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => DocumentPreview(name: name)),
);

class DocumentPreview extends StatefulWidget {
  final String name;
  const DocumentPreview({super.key, required this.name});
  @override
  State<DocumentPreview> createState() => _DocumentPreviewState();
}

class _DocumentPreviewState extends State<DocumentPreview> {
  int page = 1;
  double zoom = 1;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.name, style: heading(16)),
      actions: [
        const Padding(
          padding: EdgeInsets.all(12),
          child: Tag('Sample preview'),
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Previous page',
                onPressed: page > 1 ? () => setState(() => page--) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text('$page of 3'),
              IconButton(
                tooltip: 'Next page',
                onPressed: page < 3 ? () => setState(() => page++) : null,
                icon: const Icon(Icons.chevron_right),
              ),
              const SizedBox(width: 20),
              IconButton(
                tooltip: 'Zoom out',
                onPressed: zoom > .7 ? () => setState(() => zoom -= .1) : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('${(zoom * 100).round()}%'),
              IconButton(
                tooltip: 'Zoom in',
                onPressed: zoom < 1.8 ? () => setState(() => zoom += .1) : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ),
        Expanded(
          child: InteractiveViewer(
            minScale: .5,
            maxScale: 3,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Transform.scale(
                  scale: zoom,
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: 620,
                    padding: const EdgeInsets.all(34),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: line),
                      boxShadow: const [
                        BoxShadow(color: Color(0x09000000), blurRadius: 16),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          widget.name.endsWith('.jpg')
                              ? 'SAMPLE IMAGE'
                              : 'SAMPLE DOCUMENT',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            letterSpacing: 3,
                            color: bronze,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 30),
                        Text(
                          widget.name.endsWith('.jpg')
                              ? 'Evidence photo placeholder'
                              : 'IN THE HIGH COURT OF DELHI',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'UI preview · Page $page',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: muted),
                        ),
                        const SizedBox(height: 38),
                        if (widget.name.endsWith('.jpg'))
                          Container(
                            height: 230,
                            color: paleBlue,
                            child: const Center(
                              child: Icon(
                                Icons.image_outlined,
                                size: 80,
                                color: slateBlue,
                              ),
                            ),
                          )
                        else ...[
                          Text(
                            page == 1
                                ? 'PETITION DRAFT'
                                : page == 2
                                ? 'SUPPORTING NOTES'
                                : 'ANNEXURES',
                            style: heading(16),
                          ),
                          const SizedBox(height: 22),
                          for (int i = 0; i < 5; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 22),
                              child: Text(
                                '${i + 1}.  This is sample text for reviewing the document reading experience. It is not a legal filing, court order or advice. Actual PDF decoding will be integrated with the encrypted attachment workflow.',
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.9,
                                ),
                              ),
                            ),
                        ],
                        const SizedBox(height: 30),
                        const Divider(),
                        const SizedBox(height: 15),
                        const Text(
                          'VakilSetu · Demonstration content',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: muted, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
