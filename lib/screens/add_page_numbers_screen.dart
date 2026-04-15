import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../models/app_file.dart';
import '../services/app_controller.dart';
import '../services/pdf_service.dart';
import '../utils/formatters.dart';
import '../utils/instant_page_route.dart';
import '../utils/theme_utils.dart';
import 'document_viewer_screen.dart';

class AddPageNumbersScreen extends StatefulWidget {
  const AddPageNumbersScreen({
    super.key,
    required this.inputPath,
  });

  final String inputPath;

  @override
  State<AddPageNumbersScreen> createState() => _AddPageNumbersScreenState();
}

class _AddPageNumbersScreenState extends State<AddPageNumbersScreen> {
  bool _isSaving = false;
  PdfPageNumberTemplate _selectedTemplate = PdfPageNumberTemplate.bottomCenter;

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
        title: const Text('Add page numbers'),
        actions: <Widget>[
          TextButton(
            onPressed: _isSaving ? null : () => _save(context, controller),
            child: Text(
              _isSaving ? 'Saving...' : 'Save',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: <Widget>[
            Text(
              'Choose a page-number style, preview it, and save a numbered copy of your PDF.',
              style: TextStyle(
                color: context.primaryText,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Original size: $size',
              style: TextStyle(
                color: context.secondaryText,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            _PreviewCard(
              inputPath: widget.inputPath,
              fileName: name,
              fileSize: size,
              template: _selectedTemplate,
              pdfService: controller.pdfService,
            ),
            const SizedBox(height: 18),
            Text(
              'Templates',
              style: TextStyle(
                color: context.primaryText,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: PdfPageNumberTemplate.values.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 106,
              ),
              itemBuilder: (context, index) {
                final template = PdfPageNumberTemplate.values[index];
                final isSelected = template == _selectedTemplate;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedTemplate = template;
                    });
                  },
                  borderRadius: BorderRadius.circular(18),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
                          : context.panelBackground,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : context.borderColor,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          template.title,
                          style: TextStyle(
                            color: context.primaryText,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Align(
                          alignment: Alignment.center,
                          child: Text(
                            template.preview,
                            style: TextStyle(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : context.secondaryText,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : () => _save(context, controller),
                icon: const Icon(Icons.pin_outlined),
                label: Text(_isSaving ? 'Saving...' : 'Add page numbers'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(
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
      _isSaving = true;
    });
    final output = await controller.addPageNumbersPath(
      widget.inputPath,
      template: _selectedTemplate,
      outputFileName: outputName,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _isSaving = false;
    });
    if (output == null) {
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(content: Text(controller.statusMessage ?? 'Saving failed')),
      );
      return;
    }

    final outputFile = File(output);
    final numberedFile = AppFile(
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
        builder: (_) => DocumentViewerScreen(file: numberedFile),
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
    return 'page_numbered_$stamp';
  }

  Future<String?> _promptForOutputName(
    BuildContext context,
    String initialValue,
  ) async {
    return showDialog<String>(
      context: context,
      builder: (_) => _RenameNumberedPdfDialog(initialValue: initialValue),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.inputPath,
    required this.fileName,
    required this.fileSize,
    required this.template,
    required this.pdfService,
  });

  final String inputPath;
  final String fileName;
  final String fileSize;
  final PdfPageNumberTemplate template;
  final PdfService pdfService;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.panelBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          FutureBuilder<Uint8List?>(
            future: pdfService.renderPageAsImage(inputPath, 1),
            builder: (context, snapshot) {
              final bytes = snapshot.data;
              return Container(
                width: 92,
                height: 124,
                decoration: BoxDecoration(
                  color: context.isDarkMode
                      ? const Color(0xFF1E2335)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: bytes == null
                    ? Icon(
                        Icons.picture_as_pdf_rounded,
                        color: context.iconMuted,
                        size: 34,
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          Image.memory(bytes, fit: BoxFit.cover),
                          _PreviewPageNumber(template: template),
                        ],
                      ),
              );
            },
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  fileName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.primaryText,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  fileSize,
                  style: TextStyle(
                    color: context.secondaryText,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Selected template: ${template.title}',
                  style: TextStyle(
                    color: context.primaryText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'A numbered copy will be saved and your original PDF will stay untouched.',
                  style: TextStyle(
                    color: context.secondaryText,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewPageNumber extends StatelessWidget {
  const _PreviewPageNumber({required this.template});

  final PdfPageNumberTemplate template;

  @override
  Widget build(BuildContext context) {
    final alignment = switch (template) {
      PdfPageNumberTemplate.bottomCenter => Alignment.bottomCenter,
      PdfPageNumberTemplate.bottomRight => Alignment.bottomRight,
      PdfPageNumberTemplate.topCenter => Alignment.topCenter,
      PdfPageNumberTemplate.topRight => Alignment.topRight,
    };
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          template.preview,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            shadows: <Shadow>[
              Shadow(color: Colors.white, blurRadius: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _RenameNumberedPdfDialog extends StatefulWidget {
  const _RenameNumberedPdfDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_RenameNumberedPdfDialog> createState() =>
      _RenameNumberedPdfDialogState();
}

class _RenameNumberedPdfDialogState extends State<_RenameNumberedPdfDialog> {
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
      title: const Text('Rename numbered PDF'),
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
            Navigator.of(context).pop(
              trimmed.isEmpty ? widget.initialValue : trimmed,
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
