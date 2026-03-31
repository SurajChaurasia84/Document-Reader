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
  late final bool _fileExists = File(widget.file.path).existsSync();
  late final PdfControllerPinch? _pdfController = widget.file.isPdf && _fileExists
      ? PdfControllerPinch(document: PdfDocument.openFile(widget.file.path))
      : null;
  double _zoomScale = 1;

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
      body: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (!_fileExists) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: GlassCard(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'File not found',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                'This file looks deleted, moved, or no longer accessible.',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.file.isPdf && _pdfController != null) {
      return Stack(
        children: <Widget>[
          Positioned.fill(
            child: Container(
              color: Colors.black,
              child: PdfViewPinch(
                controller: _pdfController,
                backgroundDecoration: const BoxDecoration(color: Colors.black),
              ),
            ),
          ),
          Positioned(
            right: 14,
            bottom: 22,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _ZoomActionButton(
                  icon: Icons.add_rounded,
                  onTap: _zoomIn,
                ),
                const SizedBox(height: 10),
                _ZoomActionButton(
                  icon: Icons.remove_rounded,
                  onTap: _zoomOut,
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 22,
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.58),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: PdfPageNumber(
                    controller: _pdfController,
                    builder: (context, loadingState, page, pagesCount) {
                      final total = pagesCount ?? 0;
                      return Text(
                        '$page / $total',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      );
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
        child: SizedBox(
          width: double.infinity,
          child: Image.file(File(widget.file.path), fit: BoxFit.contain),
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

  void _zoomIn() {
    _setZoom((_zoomScale + 0.25).clamp(1.0, 4.0));
  }

  void _zoomOut() {
    _setZoom((_zoomScale - 0.25).clamp(1.0, 4.0));
  }

  void _setZoom(double nextScale) {
    if (_pdfController == null) {
      return;
    }
    setState(() {
      _zoomScale = nextScale;
      _pdfController.value = Matrix4.diagonal3Values(
        _zoomScale,
        _zoomScale,
        1,
      );
    });
  }
}

class _ZoomActionButton extends StatelessWidget {
  const _ZoomActionButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.58),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}
