import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../models/app_file.dart';
import '../services/app_controller.dart';
import 'document_viewer_screen.dart';

class WordToPdfScreen extends StatefulWidget {
  const WordToPdfScreen({
    super.key,
    required this.inputPath,
  });

  final String inputPath;

  @override
  State<WordToPdfScreen> createState() => _WordToPdfScreenState();
}

class _WordToPdfScreenState extends State<WordToPdfScreen> {
  bool _isConverting = false;
  late final Future<String> _previewFuture =
      context.read<AppController>().officeService.extractWordText(
        widget.inputPath,
      );

  @override
  Widget build(BuildContext context) {
    final controller = context.read<AppController>();

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Word to PDF'),
        actions: <Widget>[
          TextButton(
            onPressed: _isConverting
                ? null
                : () => _convertToPdf(context, controller),
            child: Text(
              _isConverting ? 'Saving...' : 'Convert',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Preview extracted text before creating the PDF.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              p.basename(widget.inputPath),
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
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF131726),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF1E2135)),
                ),
                child: FutureBuilder<String>(
                  future: _previewFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          snapshot.error.toString().replaceFirst(
                            'Exception: ',
                            '',
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      );
                    }

                    return SingleChildScrollView(
                      child: Text(
                        snapshot.data ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          height: 1.55,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isConverting
                    ? null
                    : () => _convertToPdf(context, controller),
                icon: const Icon(Icons.picture_as_pdf_rounded),
                label: Text(_isConverting ? 'Saving...' : 'Convert to PDF'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _convertToPdf(
    BuildContext context,
    AppController controller,
  ) async {
    try {
      await _previewFuture;
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
      return;
    }

    if (!mounted) {
      return;
    }
    final outputName = await _promptForOutputName(
      this.context,
      _suggestedOutputName(),
    );
    if (outputName == null) {
      return;
    }

    setState(() {
      _isConverting = true;
    });
    final output = await controller.wordToPdfPath(
      widget.inputPath,
      outputFileName: outputName,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _isConverting = false;
    });

    if (output == null) {
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(content: Text(controller.statusMessage ?? 'Conversion failed')),
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
      MaterialPageRoute<void>(
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
    return 'word_$stamp';
  }

  Future<String?> _promptForOutputName(
    BuildContext context,
    String initialValue,
  ) async {
    return showDialog<String>(
      context: context,
      builder: (_) => _RenameWordDialog(initialValue: initialValue),
    );
  }
}

class _RenameWordDialog extends StatefulWidget {
  const _RenameWordDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_RenameWordDialog> createState() => _RenameWordDialogState();
}

class _RenameWordDialogState extends State<_RenameWordDialog> {
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
