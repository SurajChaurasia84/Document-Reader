import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/app_file.dart';
import '../services/app_controller.dart';
import 'document_viewer_screen.dart';

class SplitPdfScreen extends StatefulWidget {
  const SplitPdfScreen({
    super.key,
    required this.inputPath,
  });

  final String inputPath;

  @override
  State<SplitPdfScreen> createState() => _SplitPdfScreenState();
}

class _SplitPdfScreenState extends State<SplitPdfScreen> {
  late final List<int> _pageNumbers = _loadPageNumbers();
  bool _isSplitting = false;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<AppController>();

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Split PDF'),
        actions: <Widget>[
          TextButton(
            onPressed: _pageNumbers.isEmpty || _isSplitting
                ? null
                : () => _splitPdf(context, controller),
            child: Text(
              _isSplitting ? 'Saving...' : 'Split',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Arrange or remove pages before splitting.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_pageNumbers.length} pages selected',
                  style: const TextStyle(
                    color: Color(0xFF96A0AE),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: _pageNumbers.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) {
                    newIndex -= 1;
                  }
                  final item = _pageNumbers.removeAt(oldIndex);
                  _pageNumbers.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                final pageNumber = _pageNumbers[index];
                return _SplitPageTile(
                  key: ValueKey<int>(pageNumber * 100000 + index),
                  inputPath: widget.inputPath,
                  pageNumber: pageNumber,
                  index: index,
                  onRemove: _pageNumbers.length <= 1
                      ? null
                      : () {
                          setState(() {
                            _pageNumbers.removeAt(index);
                          });
                        },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _pageNumbers.isEmpty || _isSplitting
                      ? null
                      : () => _splitPdf(context, controller),
                  icon: const Icon(Icons.call_split_rounded),
                  label: Text(_isSplitting ? 'Saving...' : 'Split PDF'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<int> _loadPageNumbers() {
    try {
      final document = PdfDocument(
        inputBytes: File(widget.inputPath).readAsBytesSync(),
      );
      final count = document.pages.count;
      document.dispose();
      return List<int>.generate(count, (index) => index + 1);
    } catch (_) {
      return <int>[];
    }
  }

  Future<void> _splitPdf(
    BuildContext context,
    AppController controller,
  ) async {
    final outputPrefix = await _promptForOutputName(
      context,
      _suggestedOutputName(),
    );
    if (outputPrefix == null) {
      return;
    }

    setState(() {
      _isSplitting = true;
    });
    final outputs = await controller.splitPdfPages(
      widget.inputPath,
      _pageNumbers,
      outputPrefix: outputPrefix,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _isSplitting = false;
    });

    if (outputs == null || outputs.isEmpty) {
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(content: Text(controller.statusMessage ?? 'Split failed')),
      );
      return;
    }

    final firstOutput = outputs.first;
    final splitFile = AppFile(
      path: firstOutput,
      name: p.basename(firstOutput),
      extension: 'pdf',
      size: await File(firstOutput).length(),
      modifiedAt: DateTime.now(),
    );
    if (!mounted) {
      return;
    }
    Navigator.of(this.context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => DocumentViewerScreen(file: splitFile),
      ),
    );
  }

  String _suggestedOutputName() {
    final now = DateTime.now();
    final stamp =
        '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
    return 'split_$stamp';
  }

  Future<String?> _promptForOutputName(
    BuildContext context,
    String initialValue,
  ) async {
    return showDialog<String>(
      context: context,
      builder: (_) => _RenameSplitDialog(initialValue: initialValue),
    );
  }
}

class _RenameSplitDialog extends StatefulWidget {
  const _RenameSplitDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_RenameSplitDialog> createState() => _RenameSplitDialogState();
}

class _RenameSplitDialogState extends State<_RenameSplitDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename split PDF'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'File name prefix',
          hintText: 'Enter file name prefix',
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final trimmed = _controller.text.trim();
            Navigator.of(
              context,
            ).pop(trimmed.isEmpty ? widget.initialValue : trimmed);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _SplitPageTile extends StatelessWidget {
  const _SplitPageTile({
    super.key,
    required this.inputPath,
    required this.pageNumber,
    required this.index,
    required this.onRemove,
  });

  final String inputPath;
  final int pageNumber;
  final int index;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<AppController>();

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF131726),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1E2135)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            Container(
              width: 28,
              alignment: Alignment.center,
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Color(0xFFFFB020),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            FutureBuilder<Uint8List?>(
              future: controller.pdfService.renderPageAsImage(
                inputPath,
                pageNumber,
              ),
              builder: (context, snapshot) {
                final bytes = snapshot.data;
                return Container(
                  width: 62,
                  height: 82,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2335),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: bytes == null
                      ? const Icon(
                          Icons.picture_as_pdf_rounded,
                          color: Colors.white70,
                        )
                      : Image.memory(bytes, fit: BoxFit.cover),
                );
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Page $pageNumber',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'One PDF will be created from this page.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFF96A0AE),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: <Widget>[
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.drag_handle_rounded,
                      color: Color(0xFF96A0AE),
                    ),
                  ),
                ),
                if (onRemove != null)
                  IconButton(
                    onPressed: onRemove,
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF96A0AE),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
