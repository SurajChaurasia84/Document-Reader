import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfService {
  Future<Directory> _outputDirectory(String folderName) async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(root.path, folderName));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<String> mergePdfs(List<String> inputPaths) async {
    final output = PdfDocument();
    for (final inputPath in inputPaths) {
      final bytes = await File(inputPath).readAsBytes();
      final document = PdfDocument(inputBytes: bytes);
      for (var i = 0; i < document.pages.count; i++) {
        final sourcePage = document.pages[i];
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
    final filePath = p.join(
      directory.path,
      'merged_${DateTime.now().millisecondsSinceEpoch}.pdf',
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

  Future<String> imageToPdf(List<String> imagePaths) async {
    final document = PdfDocument();
    for (final imagePath in imagePaths) {
      final page = document.pages.add();
      final bytes = await File(imagePath).readAsBytes();
      final bitmap = PdfBitmap(bytes);
      final size = page.getClientSize();
      page.graphics.drawImage(
        bitmap,
        Rect.fromLTWH(0, 0, size.width, size.height),
      );
    }

    final directory = await _outputDirectory('scanner');
    final filePath = p.join(
      directory.path,
      'scan_${DateTime.now().millisecondsSinceEpoch}.pdf',
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

  Future<String> compressPdf(String inputPath) async {
    final bytes = await File(inputPath).readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    document.fileStructure.incrementalUpdate = false;
    final optimized = document.saveSync();
    final directory = await _outputDirectory('compressed');
    final filePath = p.join(
      directory.path,
      '${p.basenameWithoutExtension(inputPath)}_compressed.pdf',
    );
    await File(filePath).writeAsBytes(optimized, flush: true);
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
}
