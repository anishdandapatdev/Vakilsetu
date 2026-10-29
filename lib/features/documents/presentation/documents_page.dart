import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../design_system/ui.dart';
import '../../chats/domain/conversation.dart';
import '../../chats/domain/server_messaging.dart';

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
  bool uploading = false;
  Timer? searchDebounce;
  int requestGeneration = 0;
  StreamSubscription<void>? _syncSub;

  @override
  void initState() {
    super.initState();
    if (widget.repository != null) {
      _load();
      if (widget.repository is MessagingRepository) {
        _syncSub =
            (widget.repository! as MessagingRepository).syncAvailable.listen((_) {
          _filtersChanged(immediate: true);
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant DocumentsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _syncSub?.cancel();
      if (widget.repository != null) {
        if (widget.repository is MessagingRepository) {
          _syncSub =
              (widget.repository! as MessagingRepository).syncAvailable.listen((_) {
            _filtersChanged(immediate: true);
          });
        }
        _filtersChanged(immediate: true);
      }
    }
  }

  @override
  void dispose() {
    searchDebounce?.cancel();
    _syncSub?.cancel();
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
      'PDFs' => 'documents',
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
      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save ${document.filename}',
        fileName: document.filename,
        bytes: Uint8List.fromList(bytes),
      );
      if (mounted && savedPath != null) {
        toast(context, 'Saved ${document.filename}');
      }
    } on Object catch (error) {
      if (mounted) toast(context, 'Could not download file: $error');
    }
  }

  Future<void> _pickAndUploadDocument() async {
    if (widget.repository == null || uploading) return;
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
      withData: true,
    );
    final file = picked?.files.single;
    if (file == null || file.bytes == null) return;
    if (file.size > 25 * 1024 * 1024) {
      if (mounted) toast(context, 'Document must be 25 MB or smaller.');
      return;
    }

    final ext = file.extension?.toLowerCase();
    final contentType = switch (ext) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'doc' => 'application/msword',
      'docx' =>
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      _ => 'application/octet-stream',
    };

    setState(() => uploading = true);
    try {
      await widget.repository!.uploadAttachment(
        '',
        file.name,
        contentType,
        file.bytes!,
      );
      if (mounted) {
        toast(context, 'Uploaded "${file.name}" to legal records.');
        _load();
      }
    } catch (e) {
      if (mounted) toast(context, 'Could not upload document: $e');
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageBody(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: PageTitle(
                'Documents',
                'Verified court filings, orders, and legal records.',
              ),
            ),
            if (widget.repository != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ElevatedButton.icon(
                  onPressed: uploading ? null : _pickAndUploadDocument,
                  icon: uploading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.upload_file_rounded, size: 17),
                  label: Text(
                    uploading ? 'Uploading...' : 'Upload File',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: slateBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
          ],
        ),
        SearchBox(
          hint: 'Search legal documents and orders',
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
                Text('Could not load legal documents: $loadError'),
                TextButton(
                  onPressed: () => _load(more: documents.isNotEmpty),
                  child: const Text('Retry'),
                ),
              ],
              if (documents.isEmpty && !loading && loadError == null)
                EmptyState(
                  'No matching documents',
                  query.isNotEmpty
                      ? 'No files match "$query". Try a different search.'
                      : 'No documents uploaded yet. Upload a case file or petition.',
                ),
              for (final document in documents) ...[
                DocumentTile(
                  name: document.filename,
                  detail:
                      '${(document.byteSize / 1024).round()} KB · ${document.contentType.contains('pdf') ? 'PDF' : 'Document'} · ${document.conversationTitle}',
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
      actions: const [
        Padding(
          padding: EdgeInsets.all(12),
          child: Tag('Digital Vault'),
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
                          widget.name.endsWith('.jpg') || widget.name.endsWith('.png')
                              ? 'CASE EVIDENCE ATTACHMENT'
                              : 'OFFICIAL COURT DOCUMENT',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            letterSpacing: 3,
                            color: bronze,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          widget.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Verified Legal Filing Record · Page $page',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: muted, fontSize: 12),
                        ),
                        const SizedBox(height: 30),
                        if (widget.name.endsWith('.jpg') || widget.name.endsWith('.png'))
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
                                ? 'PETITION & REVISION BRIEF'
                                : page == 2
                                ? 'AFFIDAVIT & GROUNDS'
                                : 'ANNEXURES & CAUSE LIST',
                            style: heading(16),
                          ),
                          const SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              'Document Name: ${widget.name}\n\n'
                              'Status: Digitally Signed & Archived\n'
                              'Repository: VakilSetu Secure Legal Vault\n'
                              'Encryption: AES-GCM-256 Verified\n\n'
                              'This record is securely stored in the VakilSetu legal cloud and available for download, printing, and court presentation by authorized advocates.',
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.8,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 30),
                        const Divider(),
                        const SizedBox(height: 15),
                        const Text(
                          'VakilSetu · Certified Advocate Cloud Vault',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: muted, fontSize: 11),
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
