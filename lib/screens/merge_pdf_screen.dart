import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/app_file.dart';
import '../services/app_controller.dart';
import 'document_viewer_screen.dart';

class MergePdfScreen extends StatefulWidget {
  const MergePdfScreen({
    super.key,
    required this.initialPaths,
  });

  final List<String> initialPaths;

  @override
  State<MergePdfScreen> createState() => _MergePdfScreenState();
}

class _MergePdfScreenState extends State<MergePdfScreen> {
  late final List<String> _paths = List<String>.from(widget.initialPaths);
  bool _isMerging = false;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<AppController>();

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Merge PDF'),
        actions: <Widget>[
          TextButton(
            onPressed: _paths.length < 2 || _isMerging
                ? null
                : () => _mergeFiles(context, controller),
            child: Text(
              _isMerging ? 'Merging...' : 'Merge',
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
                  'Arrange your PDFs before merging.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_paths.length} files selected',
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
              itemCount: _paths.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) {
                    newIndex -= 1;
                  }
                  final item = _paths.removeAt(oldIndex);
                  _paths.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                final path = _paths[index];
                return _MergeFileTile(
                  key: ValueKey<String>(path),
                  path: path,
                  index: index,
                  onRemove: _paths.length <= 2
                      ? null
                      : () {
                          setState(() {
                            _paths.removeAt(index);
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
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isMerging ? null : () => _addMoreFiles(controller),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add PDF'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _paths.length < 2 || _isMerging
                          ? null
                          : () => _mergeFiles(context, controller),
                      icon: const Icon(Icons.merge_type_rounded),
                      label: Text(_isMerging ? 'Merging...' : 'Merge PDF'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addMoreFiles(AppController controller) async {
    final paths = await controller.fileService.pickPdfFiles(allowMultiple: true);
    if (paths.isEmpty) {
      return;
    }
    final seen = _paths.toSet();
    setState(() {
      for (final path in paths) {
        if (seen.add(path)) {
          _paths.add(path);
        }
      }
    });
  }

  Future<void> _mergeFiles(
    BuildContext context,
    AppController controller,
  ) async {
    final suggestedName = _suggestedOutputName();
    final outputFileName = await _promptForOutputName(context, suggestedName);
    if (outputFileName == null) {
      return;
    }

    setState(() {
      _isMerging = true;
    });
    final output = await controller.mergePdfsFromPaths(
      _paths,
      outputFileName: outputFileName,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _isMerging = false;
    });
    if (output == null) {
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(content: Text(controller.statusMessage ?? 'Merge failed')),
      );
      return;
    }

    final mergedFile = AppFile(
      path: output,
      name: p.basename(output),
      extension: 'pdf',
      size: await File(output).length(),
      modifiedAt: DateTime.now(),
    );
    if (!mounted) {
      return;
    }
    Navigator.of(this.context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => DocumentViewerScreen(file: mergedFile),
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
    return 'merged_$stamp';
  }

  Future<String?> _promptForOutputName(
    BuildContext context,
    String initialValue,
  ) async {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return _RenameMergeDialog(initialValue: initialValue);
      },
    );
  }
}

class _RenameMergeDialog extends StatefulWidget {
  const _RenameMergeDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_RenameMergeDialog> createState() => _RenameMergeDialogState();
}

class _RenameMergeDialogState extends State<_RenameMergeDialog> {
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
      title: const Text('Rename merged PDF'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'File name',
          hintText: 'Enter file name',
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

class _MergeFileTile extends StatelessWidget {
  const _MergeFileTile({
    super.key,
    required this.path,
    required this.index,
    required this.onRemove,
  });

  final String path;
  final int index;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<AppController>();
    final name = p.basename(path);

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
            FutureBuilder<dynamic>(
              future: controller.pdfService.renderPageAsImage(path, 1),
              builder: (context, snapshot) {
                final bytes = snapshot.data as Uint8List?;
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
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _pageCountLabel(path),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
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

  String _pageCountLabel(String path) {
    try {
      final document = PdfDocument(inputBytes: File(path).readAsBytesSync());
      final count = document.pages.count;
      document.dispose();
      return count == 1 ? '1 page' : '$count pages';
    } catch (_) {
      return '-- pages';
    }
  }
}
