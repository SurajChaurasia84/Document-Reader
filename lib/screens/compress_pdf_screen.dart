import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../models/app_file.dart';
import '../services/app_controller.dart';
import '../utils/formatters.dart';
import '../utils/instant_page_route.dart';
import 'document_viewer_screen.dart';

class CompressPdfScreen extends StatefulWidget {
  const CompressPdfScreen({
    super.key,
    required this.inputPath,
  });

  final String inputPath;

  @override
  State<CompressPdfScreen> createState() => _CompressPdfScreenState();
}

class _CompressPdfScreenState extends State<CompressPdfScreen> {
  bool _isCompressing = false;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<AppController>();
    final file = File(widget.inputPath);
    final name = p.basename(widget.inputPath);
    final size = file.existsSync() ? formatFileSize(file.lengthSync()) : '--';

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Compress PDF'),
        actions: <Widget>[
          TextButton(
            onPressed: _isCompressing
                ? null
                : () => _compressPdf(context, controller),
            child: Text(
              _isCompressing ? 'Saving...' : 'Compress',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Preview and save a compressed copy of your PDF.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Original size: $size',
                style: const TextStyle(
                  color: Color(0xFF96A0AE),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131726),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF1E2135)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      FutureBuilder<Uint8List?>(
                        future: controller.pdfService.renderPageAsImage(
                          widget.inputPath,
                          1,
                        ),
                        builder: (context, snapshot) {
                          final bytes = snapshot.data;
                          return Container(
                            width: 92,
                            height: 124,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E2335),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: bytes == null
                                ? const Icon(
                                    Icons.picture_as_pdf_rounded,
                                    color: Colors.white70,
                                    size: 34,
                                  )
                                : Image.memory(bytes, fit: BoxFit.cover),
                          );
                        },
                      ),
                      const SizedBox(width: 14),
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
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              size,
                              style: const TextStyle(
                                color: Color(0xFF96A0AE),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'A compressed copy will be saved so your original PDF stays untouched.',
                              style: TextStyle(
                                color: Color(0xFF96A0AE),
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isCompressing
                      ? null
                      : () => _compressPdf(context, controller),
                  icon: const Icon(Icons.compress_rounded),
                  label: Text(
                    _isCompressing ? 'Saving...' : 'Compress PDF',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _compressPdf(
    BuildContext context,
    AppController controller,
  ) async {
    final outputName = await _promptForOutputName(
      context,
      _suggestedOutputName(),
    );
    if (outputName == null) {
      return;
    }

    setState(() {
      _isCompressing = true;
    });
    final output = await controller.compressPdfPath(
      widget.inputPath,
      outputFileName: outputName,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _isCompressing = false;
    });
    if (output == null) {
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(content: Text(controller.statusMessage ?? 'Compression failed')),
      );
      return;
    }

    final outputFile = File(output);
    final compressedFile = AppFile(
      path: output,
      name: p.basename(output),
      extension: 'pdf',
      size: await outputFile.length(),
      modifiedAt: DateTime.now(),
    );
    if (!mounted) {
      return;
    }
    Navigator.of(this.context).pushReplacement(
      InstantPageRoute<void>(
        builder: (_) => DocumentViewerScreen(file: compressedFile),
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
    return 'compressed_$stamp';
  }

  Future<String?> _promptForOutputName(
    BuildContext context,
    String initialValue,
  ) async {
    return showDialog<String>(
      context: context,
      builder: (_) => _RenameCompressDialog(initialValue: initialValue),
    );
  }
}

class _RenameCompressDialog extends StatefulWidget {
  const _RenameCompressDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_RenameCompressDialog> createState() => _RenameCompressDialogState();
}

class _RenameCompressDialogState extends State<_RenameCompressDialog> {
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
      title: const Text('Rename compressed PDF'),
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
