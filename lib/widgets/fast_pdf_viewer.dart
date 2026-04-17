import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

class FastPdfViewer extends StatefulWidget {
  const FastPdfViewer({
    super.key,
    required this.controller,
    this.backgroundColor = const Color(0xFFF1F5F9),
    this.padding = 16.0,
  });

  final PdfController controller;
  final Color backgroundColor;
  final double padding;

  @override
  State<FastPdfViewer> createState() => _FastPdfViewerState();
}

class _FastPdfViewerState extends State<FastPdfViewer> {
  final Map<int, Future<PdfPageImage>> _imageCaches = {};

  @override
  void dispose() {
    _imageCaches.clear();
    super.dispose();
  }

  Future<PdfPageImage> _getPageImage(int pageIndex) {
    if (_imageCaches.containsKey(pageIndex)) {
      return _imageCaches[pageIndex]!;
    }

    final future = _renderPage(pageIndex);
    _imageCaches[pageIndex] = future;
    return future;
  }

  Future<PdfPageImage> _renderPage(int pageIndex) async {
    final document = await widget.controller.document;
    final page = await document.getPage(pageIndex + 1);
    try {
      // Optimized rendering scale: 2.2x is the sweet spot for sharpness vs memory.
      // 3x was causing some slowdowns/OOM on large documents.
      final rendered = await page.render(
        width: page.width * 2.2,
        height: page.height * 2.2,
        format: PdfPageImageFormat.jpeg,
        quality: 90,
        backgroundColor: '#ffffff',
      );
      if (rendered == null) {
        throw Exception('Failed to render page $pageIndex');
      }
      return rendered;
    } finally {
      await page.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PdfLoadingState>(
      valueListenable: widget.controller.loadingState,
      builder: (context, state, child) {
        if (state == PdfLoadingState.error) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                const Text('Failed to load PDF'),
                TextButton(
                  onPressed: () => widget.controller.document, // Re-trigger
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (state != PdfLoadingState.success) {
          return const Center(child: CircularProgressIndicator());
        }

        final pageCount = widget.controller.pagesCount ?? 0;

        return Container(
          color: widget.backgroundColor,
          child: ListView.builder(
            itemCount: pageCount,
            padding: EdgeInsets.symmetric(vertical: widget.padding),
            cacheExtent: 3000, // Pre-load pages for smoother scrolling
            itemBuilder: (context, index) {
              return _PdfPageItem(
                imageFuture: _getPageImage(index),
                pageNumber: index + 1,
                padding: widget.padding,
              );
            },
          ),
        );
      },
    );
  }
}

class _PdfPageItem extends StatelessWidget {
  const _PdfPageItem({
    required this.imageFuture,
    required this.pageNumber,
    required this.padding,
  });

  final Future<PdfPageImage> imageFuture;
  final int pageNumber;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PdfPageImage>(
      future: imageFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          // Placeholder with correct AspectRatio to avoid scroll jumps
          return Padding(
            padding: EdgeInsets.only(bottom: padding),
            child: AspectRatio(
              aspectRatio: 0.707, // Standard A4 Aspect Ratio
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return const SizedBox(height: 100, child: Icon(Icons.error_outline));
        }

        final image = snapshot.data!;
        return Padding(
          padding: EdgeInsets.only(bottom: padding),
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Image(
                image: MemoryImage(image.bytes),
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
    );
  }
}
