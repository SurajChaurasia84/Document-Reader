import 'dart:io';
import 'dart:ui';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart';

class OfficeService {
  Future<String> extractWordText(String inputPath) async {
    final extension = p.extension(inputPath).toLowerCase();
    if (extension == '.doc') {
      throw Exception(
        'Legacy .doc files are not supported yet. Please use a .docx file.',
      );
    }
    if (extension != '.docx') {
      throw Exception('Please select a Word .docx file.');
    }

    final bytes = await File(inputPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final documentEntry = archive.findFile('word/document.xml');
    if (documentEntry == null) {
      throw Exception('Unable to read the Word document content.');
    }

    final xmlContent = String.fromCharCodes(documentEntry.content as List<int>);
    final document = XmlDocument.parse(xmlContent);
    final paragraphs = <String>[];

    for (final paragraph in document.findAllElements('w:p')) {
      final buffer = StringBuffer();
      for (final textNode in paragraph.findAllElements('w:t')) {
        buffer.write(textNode.innerText);
      }
      final text = buffer.toString().trim();
      if (text.isNotEmpty) {
        paragraphs.add(text);
      }
    }

    if (paragraphs.isEmpty) {
      throw Exception('No readable text found in this Word document.');
    }

    return paragraphs.join('\n\n');
  }

  Future<String> wordToPdf(
    String inputPath, {
    String? outputFileName,
  }) async {
    final text = await extractWordText(inputPath);
    final output = PdfDocument();
    output.pageSettings.margins.all = 28;
    output.pageSettings.size = PdfPageSize.a4;
    output.compressionLevel = PdfCompressionLevel.best;

    final titleFont = PdfStandardFont(
      PdfFontFamily.helvetica,
      18,
      style: PdfFontStyle.bold,
    );
    final bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 12);
    final title = p.basenameWithoutExtension(inputPath);

    final firstPage = output.pages.add();
    final size = firstPage.getClientSize();
    final titleResult = PdfTextElement(
      text: title,
      font: titleFont,
      brush: PdfBrushes.black,
    ).draw(
      page: firstPage,
      bounds: Rect.fromLTWH(0, 0, size.width, size.height),
    );

    final startY = (titleResult?.bounds.bottom ?? 0) + 12;
    PdfTextElement(
      text: text,
      font: bodyFont,
      brush: PdfBrushes.black,
      format: PdfStringFormat(lineSpacing: 5),
    ).draw(
      page: firstPage,
      bounds: Rect.fromLTWH(0, startY, size.width, size.height - startY),
      format: PdfLayoutFormat(layoutType: PdfLayoutType.paginate),
    );

    final directory = await _outputDirectory('word_to_pdf');
    final safeName = _sanitizePdfFileName(outputFileName);
    final filePath = p.join(
      directory.path,
      safeName ?? '${title}_converted.pdf',
    );
    await File(filePath).writeAsBytes(output.saveSync(), flush: true);
    output.dispose();
    return filePath;
  }

  Future<Directory> _outputDirectory(String folderName) async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(root.path, folderName));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
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
}
