import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../models/app_file.dart';
import '../services/app_controller.dart';
import '../utils/instant_page_route.dart';
import 'document_viewer_screen.dart';

class ImageToPdfScreen extends StatefulWidget {
  const ImageToPdfScreen({
    super.key,
    required this.initialPaths,
  });

  final List<String> initialPaths;

  @override
  State<ImageToPdfScreen> createState() => _ImageToPdfScreenState();
}

class _ImageToPdfScreenState extends State<ImageToPdfScreen> {
  late final List<String> _paths = List<String>.from(widget.initialPaths);
  bool _isCreating = false;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<AppController>();

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Image to PDF'),
        actions: <Widget>[
          TextButton(
            onPressed: _paths.isEmpty || _isCreating
                ? null
                : () => _createPdf(context, controller),
            child: Text(
              _isCreating ? 'Saving...' : 'Create',
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
                Text(
                  'Arrange your images before creating the PDF.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_paths.length} images selected • A4 pages',
                  style: Theme.of(context).textTheme.bodySmall,
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
                return _ImagePreviewTile(
                  key: ValueKey<String>(path),
                  path: path,
                  index: index,
                  onRemove: _paths.length <= 1
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
                      onPressed: _isCreating ? null : () => _addMoreImages(controller),
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('Add Images'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _paths.isEmpty || _isCreating
                          ? null
                          : () => _createPdf(context, controller),
                      icon: const Icon(Icons.picture_as_pdf_rounded),
                      label: Text(_isCreating ? 'Saving...' : 'Create PDF'),
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

  Future<void> _addMoreImages(AppController controller) async {
    final paths = await controller.fileService.pickPhotoLibraryImages(
      allowMultiple: true,
    );
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

  Future<void> _createPdf(BuildContext context, AppController controller) async {
    final suggestedName = _suggestedOutputName();
    final outputFileName = await _promptForOutputName(context, suggestedName);
    if (outputFileName == null) {
      return;
    }

    setState(() {
      _isCreating = true;
    });
    final output = await controller.imageToPdfPaths(
      _paths,
      outputFileName: outputFileName,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _isCreating = false;
    });
    if (output == null) {
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(content: Text(controller.statusMessage ?? 'Image to PDF failed')),
      );
      return;
    }

    final createdFile = AppFile(
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
      InstantPageRoute<void>(
        builder: (_) => DocumentViewerScreen(file: createdFile),
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
    return 'image_pdf_$stamp';
  }

  Future<String?> _promptForOutputName(
    BuildContext context,
    String initialValue,
  ) async {
    return showDialog<String>(
      context: context,
      builder: (_) => _RenameImagePdfDialog(initialValue: initialValue),
    );
  }
}

class _RenameImagePdfDialog extends StatefulWidget {
  const _RenameImagePdfDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_RenameImagePdfDialog> createState() => _RenameImagePdfDialogState();
}

class _RenameImagePdfDialogState extends State<_RenameImagePdfDialog> {
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
      title: const Text('Rename PDF'),
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

class _ImagePreviewTile extends StatelessWidget {
  const _ImagePreviewTile({
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
            SizedBox(
              width: 28,
              child: Text(
                '${index + 1}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFFFB020),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Container(
              width: 62,
              height: 82,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.file(
                File(path),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.image_not_supported_outlined);
                },
              ),
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
                    'A4 page • original quality',
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
}
