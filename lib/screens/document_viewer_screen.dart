import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:provider/provider.dart';

import '../models/app_file.dart';
import '../services/app_controller.dart';
import '../widgets/glass_card.dart';

class DocumentViewerScreen extends StatefulWidget {
  const DocumentViewerScreen({super.key, required this.file});

  final AppFile file;

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  late final PdfControllerPinch? _pdfController = widget.file.isPdf
      ? PdfControllerPinch(document: PdfDocument.openFile(widget.file.path))
      : null;

  @override
  void initState() {
    super.initState();
    context.read<AppController>().openFile(widget.file);
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.file.name),
        actions: <Widget>[
          IconButton(
            onPressed: () => controller.toggleFavorite(widget.file),
            icon: Icon(
              widget.file.isFavorite
                  ? Icons.star_rounded
                  : Icons.star_border_rounded,
            ),
          ),
          IconButton(
            onPressed: () => controller.openExternally(widget.file.path),
            icon: const Icon(Icons.open_in_new),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(child: _buildContent(context)),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: () => _showTextDialog(
                    context,
                    'OCR Result',
                    () => controller.runOcrForFile(widget.file),
                  ),
                  icon: const Icon(Icons.text_snippet_outlined),
                  label: const Text('OCR'),
                ),
                FilledButton.icon(
                  onPressed: () => _showTextDialog(
                    context,
                    'AI Summary',
                    () => controller.summarizeFile(widget.file),
                  ),
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Summarize'),
                ),
                FilledButton.icon(
                  onPressed: () => _showTextDialog(
                    context,
                    'Translation',
                    () => controller.translateFile(widget.file),
                  ),
                  icon: const Icon(Icons.translate),
                  label: const Text('Translate'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (widget.file.isPdf && _pdfController != null) {
      return PdfViewPinch(controller: _pdfController);
    }

    if (widget.file.isText) {
      return FutureBuilder<String>(
        future: File(widget.file.path).readAsString(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: SelectableText(snapshot.data ?? ''),
          );
        },
      );
    }

    if (widget.file.isImage) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.file(File(widget.file.path), fit: BoxFit.contain),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: GlassCard(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Preview unavailable',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              'Office documents are supported for file management in-app and can be opened with an installed viewer.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTextDialog(
    BuildContext context,
    String title,
    Future<String?> Function() loader,
  ) async {
    final text = await loader();
    if (!context.mounted || text == null) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: SelectableText(text)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
