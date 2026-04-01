import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/app_file.dart';

class PdfService {
  static const Map<String, List<String>> creationFolders =
      <String, List<String>>{
        'merged': <String>['pdf'],
        'split': <String>['pdf'],
        'scanner': <String>['pdf'],
        'compressed': <String>['pdf'],
        'protected': <String>['pdf'],
        'numbered': <String>['pdf'],
        'images': <String>['png'],
      };

  Future<Directory> _outputDirectory(String folderName) async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(root.path, folderName));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<String> mergePdfs(
    List<String> inputPaths, {
    String? outputFileName,
  }) async {
    final output = PdfDocument();
    output.pageSettings.margins.all = 0;
    for (final inputPath in inputPaths) {
      final bytes = await File(inputPath).readAsBytes();
      final document = PdfDocument(inputBytes: bytes);
      for (var i = 0; i < document.pages.count; i++) {
        final sourcePage = document.pages[i];
        output.pageSettings.size = sourcePage.size;
        final targetPage = output.pages.add();
        final template = sourcePage.createTemplate();
        targetPage.graphics.drawPdfTemplate(
          template,
          Offset.zero,
          sourcePage.getClientSize(),
        );
      }
      document.dispose();
    }

    final directory = await _outputDirectory('merged');
    final safeName = _sanitizePdfFileName(outputFileName);
    final filePath = p.join(
      directory.path,
      safeName ?? 'merged_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await File(filePath).writeAsBytes(output.saveSync(), flush: true);
    output.dispose();
    return filePath;
  }

  Future<List<String>> splitPdf(String inputPath) async {
    final input = PdfDocument(inputBytes: await File(inputPath).readAsBytes());
    final directory = await _outputDirectory('split');
    final created = <String>[];

    for (var i = 0; i < input.pages.count; i++) {
      final part = PdfDocument();
      final sourcePage = input.pages[i];
      final targetPage = part.pages.add();
      final template = sourcePage.createTemplate();
      targetPage.graphics.drawPdfTemplate(
        template,
        Offset.zero,
        sourcePage.getClientSize(),
      );
      final filePath = p.join(
        directory.path,
        '${p.basenameWithoutExtension(inputPath)}_page_${i + 1}.pdf',
      );
      await File(filePath).writeAsBytes(part.saveSync(), flush: true);
      created.add(filePath);
      part.dispose();
    }

    input.dispose();
    return created;
  }

  Future<List<String>> splitPdfPages(
    String inputPath,
    List<int> pageNumbers, {
    String? outputPrefix,
  }) async {
    final input = PdfDocument(inputBytes: await File(inputPath).readAsBytes());
    final directory = await _outputDirectory('split');
    final created = <String>[];
    final safePrefix = _sanitizeBaseName(outputPrefix) ??
        'split_${DateTime.now().millisecondsSinceEpoch}';

    for (var i = 0; i < pageNumbers.length; i++) {
      final pageNumber = pageNumbers[i];
      if (pageNumber < 1 || pageNumber > input.pages.count) {
        continue;
      }

      final part = PdfDocument();
      part.pageSettings.margins.all = 0;
      final sourcePage = input.pages[pageNumber - 1];
      part.pageSettings.size = sourcePage.size;
      final targetPage = part.pages.add();
      final template = sourcePage.createTemplate();
      targetPage.graphics.drawPdfTemplate(
        template,
        Offset.zero,
        sourcePage.getClientSize(),
      );

      final filePath = p.join(
        directory.path,
        '${safePrefix}_page_${i + 1}.pdf',
      );
      await File(filePath).writeAsBytes(part.saveSync(), flush: true);
      created.add(filePath);
      part.dispose();
    }

    input.dispose();
    return created;
  }

  Future<String> imageToPdf(List<String> imagePaths) async {
    return imageToPdfPaths(imagePaths);
  }

  Future<String> imageToPdfPaths(
    List<String> imagePaths, {
    String? outputFileName,
  }) async {
    final document = PdfDocument();
    document.pageSettings.size = PdfPageSize.a4;
    document.pageSettings.margins.all = 0;
    for (final imagePath in imagePaths) {
      final page = document.pages.add();
      final bytes = await File(imagePath).readAsBytes();
      final bitmap = PdfBitmap(bytes);
      final size = page.getClientSize();
      page.graphics.drawRectangle(
        brush: PdfSolidBrush(PdfColor(255, 255, 255)),
        bounds: Rect.fromLTWH(0, 0, size.width, size.height),
      );

      final imageSize = await _readImageSize(bytes);
      final fittedRect = _fitImageOnPage(
        imageWidth: imageSize.width,
        imageHeight: imageSize.height,
        pageWidth: size.width,
        pageHeight: size.height,
        padding: 24,
      );

      page.graphics.drawImage(bitmap, fittedRect);
    }

    final directory = await _outputDirectory('scanner');
    final safeName = _sanitizePdfFileName(outputFileName);
    final filePath = p.join(
      directory.path,
      safeName ?? 'image_pdf_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await File(filePath).writeAsBytes(document.saveSync(), flush: true);
    document.dispose();
    return filePath;
  }

  Future<List<String>> pdfToImages(String inputPath) async {
    final directory = await _outputDirectory('images');
    final document = await pdfx.PdfDocument.openFile(inputPath);
    final created = <String>[];

    for (var i = 1; i <= document.pagesCount; i++) {
      final page = await document.getPage(i);
      final rendered = await page.render(
        width: page.width * 2,
        height: page.height * 2,
        format: pdfx.PdfPageImageFormat.png,
      );

      if (rendered != null) {
        final filePath = p.join(
          directory.path,
          '${p.basenameWithoutExtension(inputPath)}_$i.png',
        );
        await File(filePath).writeAsBytes(rendered.bytes, flush: true);
        created.add(filePath);
      }

      await page.close();
    }

    await document.close();
    return created;
  }

  Future<String> compressPdf(
    String inputPath, {
    String? outputFileName,
  }) async {
    final originalBytes = await File(inputPath).readAsBytes();
    final document = PdfDocument(inputBytes: originalBytes);
    document.fileStructure.incrementalUpdate = false;
    document.compressionLevel = PdfCompressionLevel.best;
    final optimized = document.saveSync();
    final fallback = await _rasterCompressPdf(
      inputPath,
      sourceDocument: document,
    );
    final directory = await _outputDirectory('compressed');
    final safeName = _sanitizePdfFileName(outputFileName);
    final filePath = p.join(
      directory.path,
      safeName ?? '${p.basenameWithoutExtension(inputPath)}_compressed.pdf',
    );
    final bestBytes = _pickCompressedBytes(
      original: originalBytes,
      optimized: optimized,
      rasterized: fallback,
    );
    await File(filePath).writeAsBytes(bestBytes, flush: true);
    document.dispose();
    return filePath;
  }

  Future<String> protectPdf(
    String inputPath, {
    required String userPassword,
    String? ownerPassword,
    String? outputFileName,
  }) async {
    if (userPassword.trim().isEmpty) {
      throw Exception('Enter a password to protect the PDF.');
    }

    final inputBytes = await File(inputPath).readAsBytes();
    final document = PdfDocument(inputBytes: inputBytes);
    document.fileStructure.incrementalUpdate = false;
    document.security.userPassword = userPassword.trim();
    document.security.ownerPassword =
        (ownerPassword?.trim().isNotEmpty ?? false)
        ? ownerPassword!.trim()
        : '${userPassword.trim()}_owner';
    document.security.algorithm = PdfEncryptionAlgorithm.aesx256Bit;

    final directory = await _outputDirectory('protected');
    final safeName = _sanitizePdfFileName(outputFileName);
    final filePath = p.join(
      directory.path,
      safeName ?? '${p.basenameWithoutExtension(inputPath)}_protected.pdf',
    );
    await File(filePath).writeAsBytes(document.saveSync(), flush: true);
    document.dispose();
    return filePath;
  }

  Future<String> unlockPdf(
    String inputPath, {
    required String password,
    String? outputFileName,
  }) async {
    if (password.trim().isEmpty) {
      throw Exception('Enter the password to unlock the PDF.');
    }

    final inputBytes = await File(inputPath).readAsBytes();
    final input = PdfDocument(
      inputBytes: inputBytes,
      password: password.trim(),
    );
    final output = PdfDocument();
    output.pageSettings.margins.all = 0;

    for (var i = 0; i < input.pages.count; i++) {
      final sourcePage = input.pages[i];
      output.pageSettings.size = sourcePage.size;
      final targetPage = output.pages.add();
      final template = sourcePage.createTemplate();
      targetPage.graphics.drawPdfTemplate(
        template,
        Offset.zero,
        sourcePage.getClientSize(),
      );
    }

    final directory = await _outputDirectory('protected');
    final safeName = _sanitizePdfFileName(outputFileName);
    final filePath = p.join(
      directory.path,
      safeName ?? '${p.basenameWithoutExtension(inputPath)}_unlocked.pdf',
    );
    await File(filePath).writeAsBytes(output.saveSync(), flush: true);
    input.dispose();
    output.dispose();
    return filePath;
  }

  Future<String> addPageNumbers(
    String inputPath, {
    required PdfPageNumberTemplate template,
    String? outputFileName,
  }) async {
    final inputBytes = await File(inputPath).readAsBytes();
    final document = PdfDocument(inputBytes: inputBytes);
    document.fileStructure.incrementalUpdate = false;

    final font = PdfStandardFont(PdfFontFamily.helvetica, 11);
    final brush = PdfSolidBrush(PdfColor(68, 68, 68));

    for (var i = 0; i < document.pages.count; i++) {
      final page = document.pages[i];
      final pageSize = page.getClientSize();
      final pageNumber = i + 1;
      final text = template.labelBuilder(pageNumber, document.pages.count);
      final textSize = font.measureString(text);
      final bounds = _pageNumberBounds(
        template: template,
        pageWidth: pageSize.width,
        pageHeight: pageSize.height,
        textWidth: textSize.width,
        textHeight: textSize.height,
      );
      page.graphics.drawString(
        text,
        font,
        brush: brush,
        bounds: bounds,
        format: PdfStringFormat(alignment: template.alignment),
      );
    }

    final directory = await _outputDirectory('numbered');
    final safeName = _sanitizePdfFileName(outputFileName);
    final filePath = p.join(
      directory.path,
      safeName ?? '${p.basenameWithoutExtension(inputPath)}_numbered.pdf',
    );
    await File(filePath).writeAsBytes(document.saveSync(), flush: true);
    document.dispose();
    return filePath;
  }

  Future<Uint8List?> renderPageAsImage(String inputPath, int pageNumber) async {
    final document = await pdfx.PdfDocument.openFile(inputPath);
    final page = await document.getPage(pageNumber);
    final rendered = await page.render(
      width: page.width * 2,
      height: page.height * 2,
      format: pdfx.PdfPageImageFormat.png,
    );
    await page.close();
    await document.close();
    return rendered?.bytes;
  }

  Future<bool> isPdfPasswordProtected(String inputPath) async {
    try {
      final bytes = await File(inputPath).readAsBytes();
      final document = PdfDocument(inputBytes: bytes);
      document.dispose();
      return false;
    } catch (error) {
      final message = error.toString().toLowerCase();
      return message.contains('password') ||
          message.contains('encrypted') ||
          message.contains('cannot open an encrypted document');
    }
  }

  Future<List<AppFile>> listCreatedFiles({
    Set<String> favorites = const <String>{},
  }) async {
    final root = await getApplicationDocumentsDirectory();
    final files = <AppFile>[];

    for (final entry in creationFolders.entries) {
      final directory = Directory(p.join(root.path, entry.key));
      if (!await directory.exists()) {
        continue;
      }

      await for (final entity
          in directory.list(recursive: true, followLinks: false)) {
        if (entity is! File) {
          continue;
        }

        final extension = p
            .extension(entity.path)
            .replaceFirst('.', '')
            .toLowerCase();
        if (!entry.value.contains(extension)) {
          continue;
        }

        files.add(
          AppFile.fromFileSystemEntity(
            entity,
            isFavorite: favorites.contains(entity.path),
          ),
        );
      }
    }

    files.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return files;
  }

  String? _sanitizePdfFileName(String? value) {
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final normalized = trimmed.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    if (normalized.toLowerCase().endsWith('.pdf')) {
      return normalized;
    }
    return '$normalized.pdf';
  }

  String? _sanitizeBaseName(String? value) {
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final withoutPdf = trimmed.toLowerCase().endsWith('.pdf')
        ? trimmed.substring(0, trimmed.length - 4)
        : trimmed;
    return withoutPdf.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  List<int> _pickCompressedBytes({
    required List<int> original,
    required List<int> optimized,
    List<int>? rasterized,
  }) {
    var best = optimized;
    if (rasterized != null && rasterized.isNotEmpty && rasterized.length < best.length) {
      best = rasterized;
    }

    // If no strategy produced a smaller file, still return the smallest attempt.
    if (best.length >= original.length) {
      return rasterized != null && rasterized.isNotEmpty && rasterized.length < optimized.length
          ? rasterized
          : optimized;
    }
    return best;
  }

  Future<List<int>?> _rasterCompressPdf(
    String inputPath, {
    required PdfDocument sourceDocument,
  }) async {
    try {
      final output = PdfDocument();
      output.pageSettings.margins.all = 0;
      output.compressionLevel = PdfCompressionLevel.best;
      final renderedDocument = await pdfx.PdfDocument.openFile(inputPath);

      for (var i = 1; i <= renderedDocument.pagesCount; i++) {
        final renderedPage = await renderedDocument.getPage(i);
        final longestSide = renderedPage.width > renderedPage.height
            ? renderedPage.width
            : renderedPage.height;
        final scale = longestSide > 1400 ? 1.0 : 1.35;
        final image = await renderedPage.render(
          width: renderedPage.width * scale,
          height: renderedPage.height * scale,
          format: pdfx.PdfPageImageFormat.jpeg,
        );

        if (image != null) {
          final sourcePage = sourceDocument.pages[i - 1];
          output.pageSettings.size = sourcePage.size;
          final page = output.pages.add();
          final size = page.getClientSize();
          page.graphics.drawImage(
            PdfBitmap(image.bytes),
            Rect.fromLTWH(0, 0, size.width, size.height),
          );
        }

        await renderedPage.close();
      }

      await renderedDocument.close();
      final bytes = output.saveSync();
      output.dispose();
      return bytes;
    } catch (_) {
      return null;
    }
  }

  Future<Size> _readImageSize(Uint8List bytes) async {
    final codec = await instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return Size(
      frame.image.width.toDouble(),
      frame.image.height.toDouble(),
    );
  }

  Rect _fitImageOnPage({
    required double imageWidth,
    required double imageHeight,
    required double pageWidth,
    required double pageHeight,
    double padding = 0,
  }) {
    final availableWidth = pageWidth - (padding * 2);
    final availableHeight = pageHeight - (padding * 2);
    final widthScale = availableWidth / imageWidth;
    final heightScale = availableHeight / imageHeight;
    final scale = widthScale < heightScale ? widthScale : heightScale;
    final targetWidth = imageWidth * scale;
    final targetHeight = imageHeight * scale;
    final left = (pageWidth - targetWidth) / 2;
    final top = (pageHeight - targetHeight) / 2;
    return Rect.fromLTWH(left, top, targetWidth, targetHeight);
  }

  Rect _pageNumberBounds({
    required PdfPageNumberTemplate template,
    required double pageWidth,
    required double pageHeight,
    required double textWidth,
    required double textHeight,
  }) {
    const horizontalPadding = 28.0;
    const verticalPadding = 22.0;
    final top = template.isTop
        ? verticalPadding
        : pageHeight - textHeight - verticalPadding;

    switch (template) {
      case PdfPageNumberTemplate.bottomCenter:
      case PdfPageNumberTemplate.topCenter:
        return Rect.fromLTWH(
          (pageWidth / 2) - ((textWidth + 2) / 2),
          top,
          textWidth + 2,
          textHeight + 2,
        );
      case PdfPageNumberTemplate.bottomRight:
      case PdfPageNumberTemplate.topRight:
        return Rect.fromLTWH(
          pageWidth - textWidth - horizontalPadding,
          top,
          textWidth + 2,
          textHeight + 2,
        );
    }
  }
}

enum PdfPageNumberTemplate {
  bottomCenter('Bottom Center', '1', PdfTextAlignment.center, false),
  bottomRight('Bottom Right', 'Page 1', PdfTextAlignment.right, false),
  topCenter('Top Center', '1 / 8', PdfTextAlignment.center, true),
  topRight('Top Right', 'Page 1 of 8', PdfTextAlignment.right, true);

  const PdfPageNumberTemplate(
    this.title,
    this.preview,
    this.alignment,
    this.isTop,
  );

  final String title;
  final String preview;
  final PdfTextAlignment alignment;
  final bool isTop;

  String labelBuilder(int pageNumber, int totalPages) {
    switch (this) {
      case PdfPageNumberTemplate.bottomCenter:
      case PdfPageNumberTemplate.topCenter:
        if (this == PdfPageNumberTemplate.topCenter) {
          return '$pageNumber / $totalPages';
        }
        return '$pageNumber';
      case PdfPageNumberTemplate.bottomRight:
        return 'Page $pageNumber';
      case PdfPageNumberTemplate.topRight:
        return 'Page $pageNumber of $totalPages';
    }
  }
}
