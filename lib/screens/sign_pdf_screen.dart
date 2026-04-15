import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

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

class SignPdfScreen extends StatefulWidget {
  const SignPdfScreen({
    super.key,
    required this.inputPath,
  });

  final String inputPath;

  @override
  State<SignPdfScreen> createState() => _SignPdfScreenState();
}

class _SignPdfScreenState extends State<SignPdfScreen> {
  bool _isSaving = false;
  int _pageCount = 1;
  int _selectedPage = 1;
  PdfSignaturePlacement _placement = PdfSignaturePlacement.bottomRight;
  Uint8List? _signatureBytes;

  @override
  void initState() {
    super.initState();
    _loadPageCount();
  }

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
        title: const Text('Sign PDF'),
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
              'Draw your signature, choose its position, and save a signed copy of your PDF.',
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
            _SignPreviewCard(
              inputPath: widget.inputPath,
              fileName: name,
              fileSize: size,
              placement: _placement,
              hasSignature: _signatureBytes != null,
              pdfService: controller.pdfService,
            ),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                Expanded(
                  child: _InfoChip(
                    label: 'Page',
                    value: '$_selectedPage / $_pageCount',
                    onTap: _pageCount < 2 ? null : _showPagePicker,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoChip(
                    label: 'Signature',
                    value: _signatureBytes == null ? 'Add' : 'Update',
                    onTap: _openSignatureDialog,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Position',
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
              itemCount: PdfSignaturePlacement.values.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 92,
              ),
              itemBuilder: (context, index) {
                final placement = PdfSignaturePlacement.values[index];
                final isSelected = placement == _placement;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _placement = placement;
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
                    child: Center(
                      child: Text(
                        placement.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : context.primaryText,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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
                icon: const Icon(Icons.draw_rounded),
                label: Text(_isSaving ? 'Saving...' : 'Sign PDF'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadPageCount() async {
    final controller = context.read<AppController>();
    final pageCount = await controller.pdfService.getPageCount(widget.inputPath);
    if (!mounted) {
      return;
    }
    setState(() {
      _pageCount = pageCount;
      _selectedPage = pageCount < _selectedPage ? pageCount : _selectedPage;
    });
  }

  Future<void> _showPagePicker() async {
    final result = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return ListView.builder(
          itemCount: _pageCount,
          itemBuilder: (context, index) {
            final page = index + 1;
            return ListTile(
              title: Text('Page $page'),
              trailing: page == _selectedPage
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: () => Navigator.of(context).pop(page),
            );
          },
        );
      },
    );
    if (result == null || !mounted) {
      return;
    }
    setState(() {
      _selectedPage = result;
    });
  }

  Future<void> _openSignatureDialog() async {
    final bytes = await showDialog<Uint8List>(
      context: context,
      builder: (_) => _SignatureDialog(initialBytes: _signatureBytes),
    );
    if (bytes == null || !mounted) {
      return;
    }
    setState(() {
      _signatureBytes = bytes;
    });
  }

  Future<void> _save(
    BuildContext context,
    AppController controller,
  ) async {
    if (_signatureBytes == null) {
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(content: Text('Draw a signature first.')),
      );
      return;
    }

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
    final output = await controller.signPdfPath(
      widget.inputPath,
      signatureBytes: _signatureBytes!,
      pageNumber: _selectedPage,
      placement: _placement,
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
        SnackBar(content: Text(controller.statusMessage ?? 'Signing failed')),
      );
      return;
    }

    final outputFile = File(output);
    final signedFile = AppFile(
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
        builder: (_) => DocumentViewerScreen(file: signedFile),
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
    return 'signed_$stamp';
  }

  Future<String?> _promptForOutputName(
    BuildContext context,
    String initialValue,
  ) async {
    return showDialog<String>(
      context: context,
      builder: (_) => _RenameSignedPdfDialog(initialValue: initialValue),
    );
  }
}

class _SignPreviewCard extends StatelessWidget {
  const _SignPreviewCard({
    required this.inputPath,
    required this.fileName,
    required this.fileSize,
    required this.placement,
    required this.hasSignature,
    required this.pdfService,
  });

  final String inputPath;
  final String fileName;
  final String fileSize;
  final PdfSignaturePlacement placement;
  final bool hasSignature;
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
                          if (hasSignature)
                            _SignaturePreviewOverlay(placement: placement),
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
                  hasSignature
                      ? 'Signature ready for ${placement.title.toLowerCase()}.'
                      : 'Add a signature to preview its placement.',
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

class _SignaturePreviewOverlay extends StatelessWidget {
  const _SignaturePreviewOverlay({required this.placement});

  final PdfSignaturePlacement placement;

  @override
  Widget build(BuildContext context) {
    final alignment = switch (placement) {
      PdfSignaturePlacement.bottomRight => Alignment.bottomRight,
      PdfSignaturePlacement.bottomLeft => Alignment.bottomLeft,
      PdfSignaturePlacement.topRight => Alignment.topRight,
      PdfSignaturePlacement.topLeft => Alignment.topLeft,
    };
    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.all(7),
        width: 38,
        height: 16,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(
          child: Text(
            'Sign',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.panelBackground,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: TextStyle(
                  color: context.secondaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  color: context.primaryText,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignatureDialog extends StatefulWidget {
  const _SignatureDialog({this.initialBytes});

  final Uint8List? initialBytes;

  @override
  State<_SignatureDialog> createState() => _SignatureDialogState();
}

class _SignatureDialogState extends State<_SignatureDialog> {
  final List<Offset?> _points = <Offset?>[];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Draw signature'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD1D5DB)),
              ),
              child: GestureDetector(
                onPanStart: (details) {
                  setState(() {
                    _points.add(details.localPosition);
                  });
                },
                onPanUpdate: (details) {
                  setState(() {
                    _points.add(details.localPosition);
                  });
                },
                onPanEnd: (_) {
                  setState(() {
                    _points.add(null);
                  });
                },
                child: CustomPaint(
                  painter: _SignaturePainter(_points),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Sign with your finger and save the signature.',
              style: TextStyle(
                color: context.secondaryText,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            setState(() {
              _points.clear();
            });
          },
          child: const Text('Clear'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            if (_points.whereType<Offset>().isEmpty) {
              return;
            }
            final bytes = await _renderSignatureBytes(_points);
            if (!mounted) {
              return;
            }
            Navigator.of(this.context).pop(bytes);
          },
          child: const Text('Use'),
        ),
      ],
    );
  }

  Future<Uint8List> _renderSignatureBytes(List<Offset?> points) async {
    const width = 600.0;
    const height = 220.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    for (var i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      if (current != null && next != null) {
        canvas.drawLine(
          Offset(current.dx * 1.8, current.dy * 1.2),
          Offset(next.dx * 1.8, next.dy * 1.2),
          paint,
        );
      }
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter(this.points);

  final List<Offset?> points;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    for (var i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      if (current != null && next != null) {
        canvas.drawLine(current, next, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class _RenameSignedPdfDialog extends StatefulWidget {
  const _RenameSignedPdfDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_RenameSignedPdfDialog> createState() => _RenameSignedPdfDialogState();
}

class _RenameSignedPdfDialogState extends State<_RenameSignedPdfDialog> {
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
      title: const Text('Rename signed PDF'),
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
