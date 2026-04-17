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
      return _extractLegacyText(inputPath);
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

  Future<String> extractSpreadsheetText(String inputPath) async {
    final extension = p.extension(inputPath).toLowerCase();
    if (extension == '.xls') {
      return _extractLegacyText(inputPath);
    }
    if (extension != '.xlsx') {
      throw Exception('Please select an Excel .xlsx file.');
    }

    final archive = await _readArchive(inputPath);
    final sharedStrings = _readSharedStrings(archive);
    final sheetFiles = archive.files
        .where(
          (file) =>
              !file.isFile
                  ? false
                  : file.name.startsWith('xl/worksheets/') &&
                        file.name.endsWith('.xml'),
        )
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final sections = <String>[];
    for (var i = 0; i < sheetFiles.length; i++) {
      final file = sheetFiles[i];
      final xml = XmlDocument.parse(
        String.fromCharCodes(file.content as List<int>),
      );
      final rows = <String>[];

      for (final row in xml.findAllElements('row')) {
        final cells = <String>[];
        for (final cell in row.findAllElements('c')) {
          final type = cell.getAttribute('t');
          final valueNode = cell.getElement('v');
          if (valueNode == null) {
            continue;
          }
          final raw = valueNode.innerText.trim();
          if (raw.isEmpty) {
            continue;
          }
          if (type == 's') {
            final index = int.tryParse(raw);
            if (index != null && index >= 0 && index < sharedStrings.length) {
              cells.add(sharedStrings[index]);
            }
          } else {
            cells.add(raw);
          }
        }
        if (cells.isNotEmpty) {
          rows.add(cells.join(' | '));
        }
      }

      if (rows.isNotEmpty) {
        sections.add('Sheet ${i + 1}\n${rows.join('\n')}');
      }
    }

    if (sections.isEmpty) {
      throw Exception('No readable data found in this Excel file.');
    }

    return sections.join('\n\n');
  }

  Future<SpreadsheetPreviewData> extractSpreadsheetPreview(String inputPath) async {
    final extension = p.extension(inputPath).toLowerCase();
    if (extension == '.xls') {
      throw Exception(
        'Legacy .xls files are not supported yet. Please use a .xlsx file.',
      );
    }
    if (extension != '.xlsx') {
      throw Exception('Please select an Excel .xlsx file.');
    }

    final archive = await _readArchive(inputPath);
    final sharedStrings = _readSharedStrings(archive);
    final workbook = _readWorkbookSheetNames(archive);
    final sheetFiles = archive.files
        .where(
          (file) =>
              file.isFile &&
              file.name.startsWith('xl/worksheets/') &&
              file.name.endsWith('.xml'),
        )
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final sheets = <SpreadsheetSheetData>[];
    for (var i = 0; i < sheetFiles.length; i++) {
      final file = sheetFiles[i];
      final xml = XmlDocument.parse(
        String.fromCharCodes(file.content as List<int>),
      );

      // We use a Map of row index to a Map of column index to value
      // This allows us to handle sparse Excel data correctly.
      final Map<int, Map<int, String>> grid = {};
      int maxCol = 0;
      int maxRow = 0;

      for (final rowNode in xml.findAllElements('row')) {
        final rAttr = rowNode.getAttribute('r');
        int rowIndex = rAttr != null ? int.parse(rAttr) - 1 : maxRow;
        if (rowIndex > maxRow) maxRow = rowIndex;

        if (!grid.containsKey(rowIndex)) grid[rowIndex] = {};

        for (final cellNode in rowNode.findAllElements('c')) {
          final ref = cellNode.getAttribute('r');
          int colIndex = -1;
          if (ref != null) {
            final coords = _rowAndColFromRef(ref);
            colIndex = coords.$2;
            // rowIndex from ref should match rowIndex from row node
          }

          final type = cellNode.getAttribute('t');
          final valueNode = cellNode.getElement('v');
          String value = '';
          
          if (valueNode != null) {
            final raw = valueNode.innerText.trim();
            if (type == 's') {
              final index = int.tryParse(raw);
              if (index != null && index >= 0 && index < sharedStrings.length) {
                value = sharedStrings[index];
              }
            } else {
              value = raw;
            }
          }

          if (colIndex != -1) {
            grid[rowIndex]![colIndex] = value;
            if (colIndex > maxCol) maxCol = colIndex;
          }
        }
        maxRow++;
      }

      // Convert the sparse Map to a regular 2D List
      final List<List<String>> finalRows = [];
      if (maxRow > 0 || maxCol > 0) {
        // We add +1 because maxCol/maxRow are indices
        final numCols = maxCol + 1;
        final numRows = maxRow + 1;

        for (int r = 0; r < numRows; r++) {
          final List<String> rowList = List.filled(numCols, '');
          final rowData = grid[r];
          if (rowData != null) {
            rowData.forEach((c, val) {
              rowList[c] = val;
            });
          }
          finalRows.add(rowList);
        }
      }

      if (finalRows.isNotEmpty) {
        sheets.add(
          SpreadsheetSheetData(
            name: workbook[i],
            rows: finalRows,
          ),
        );
      }
    }

    if (sheets.isEmpty) {
      throw Exception('No readable data found in this Excel file.');
    }

    return SpreadsheetPreviewData(sheets: sheets);
  }

  Future<String> extractPresentationText(String inputPath) async {
    final extension = p.extension(inputPath).toLowerCase();
    if (extension == '.ppt') {
      return _extractLegacyText(inputPath);
    }
    if (extension != '.pptx') {
      throw Exception('Please select a PowerPoint .pptx file.');
    }

    final archive = await _readArchive(inputPath);
    final slideFiles = archive.files
        .where(
          (file) =>
              file.isFile &&
              file.name.startsWith('ppt/slides/') &&
              file.name.endsWith('.xml'),
        )
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final slides = <String>[];
    for (var i = 0; i < slideFiles.length; i++) {
      final xml = XmlDocument.parse(
        String.fromCharCodes(slideFiles[i].content as List<int>),
      );
      final texts = xml
          .findAllElements('a:t')
          .map((node) => node.innerText.trim())
          .where((text) => text.isNotEmpty)
          .toList();
      if (texts.isNotEmpty) {
        slides.add('Slide ${i + 1}\n${texts.join('\n')}');
      }
    }

    if (slides.isEmpty) {
      throw Exception('No readable text found in this PowerPoint file.');
    }

    return slides.join('\n\n');
  }

  Future<PresentationPreviewData> extractPresentationPreview(String inputPath) async {
    final extension = p.extension(inputPath).toLowerCase();
    if (extension == '.ppt') {
      throw Exception(
        'Legacy .ppt files are not supported yet. Please use a .pptx file.',
      );
    }
    if (extension != '.pptx') {
      throw Exception('Please select a PowerPoint .pptx file.');
    }

    final archive = await _readArchive(inputPath);
    final slideFiles = archive.files
        .where(
          (file) =>
              file.isFile &&
              file.name.startsWith('ppt/slides/') &&
              file.name.endsWith('.xml'),
        )
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final slides = <PresentationSlideData>[];
    for (var i = 0; i < slideFiles.length; i++) {
      final xml = XmlDocument.parse(
        String.fromCharCodes(slideFiles[i].content as List<int>),
      );
      final texts = xml
          .findAllElements('a:t')
          .map((node) => node.innerText.trim())
          .where((text) => text.isNotEmpty)
          .toList();
      if (texts.isNotEmpty) {
        slides.add(
          PresentationSlideData(
            title: texts.first,
            bullets: texts.length > 1 ? texts.sublist(1) : const <String>[],
          ),
        );
      }
    }

    if (slides.isEmpty) {
      throw Exception('No readable text found in this PowerPoint file.');
    }

    return PresentationPreviewData(slides: slides);
  }

  Future<String> extractPreviewText(String inputPath) async {
    final extension = p.extension(inputPath).toLowerCase();
    switch (extension) {
      case '.docx':
      case '.doc':
        return extractWordText(inputPath);
      case '.xlsx':
      case '.xls':
        return extractSpreadsheetText(inputPath);
      case '.pptx':
      case '.ppt':
        return extractPresentationText(inputPath);
      default:
        throw Exception('This file type is not supported for preview yet.');
    }
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

  Future<Archive> _readArchive(String inputPath) async {
    final bytes = await File(inputPath).readAsBytes();
    return ZipDecoder().decodeBytes(bytes);
  }

  List<String> _readSharedStrings(Archive archive) {
    final entry = archive.findFile('xl/sharedStrings.xml');
    if (entry == null) {
      return const <String>[];
    }

    final xml = XmlDocument.parse(
      String.fromCharCodes(entry.content as List<int>),
    );
    return xml
        .findAllElements('si')
        .map(
          (item) => item
              .findAllElements('t')
              .map((textNode) => textNode.innerText)
              .join(),
        )
        .toList();
  }

  List<String> _readWorkbookSheetNames(Archive archive) {
    final entry = archive.findFile('xl/workbook.xml');
    if (entry == null) {
      return const <String>[];
    }

    final xml = XmlDocument.parse(
      String.fromCharCodes(entry.content as List<int>),
    );
    final names = xml
        .findAllElements('sheet')
        .map((node) => node.getAttribute('name') ?? 'Sheet')
        .toList();
    return names.isEmpty ? const <String>[] : names;
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

  Future<String> _extractLegacyText(String inputPath) async {
    try {
      final bytes = await File(inputPath).readAsBytes();
      final buffer = StringBuffer();
      
      // Look for sequences of printable ASCII characters
      var currentSequence = <int>[];
      
      for (final byte in bytes) {
        if ((byte >= 32 && byte <= 126) || byte == 10 || byte == 13 || byte == 9) {
          currentSequence.add(byte);
        } else {
          if (currentSequence.length >= 4) {
            final text = String.fromCharCodes(currentSequence).trim();
            if (text.isNotEmpty) {
              buffer.write('$text ');
            }
          }
          currentSequence = [];
        }
      }
      
      if (currentSequence.length >= 4) {
        buffer.write(String.fromCharCodes(currentSequence));
      }

      final result = buffer.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
      if (result.isEmpty) {
        throw Exception('No readable text could be extracted from this legacy file.');
      }
      
      return '--- LEGACY PREVIEW (Limited Formatting) ---\n\n$result';
    } catch (e) {
      throw Exception('Unable to read this legacy file: ${e.toString()}');
    }
  }

  /// Converts a cell reference like "A1" or "AB10" into (row index, column index).
  (int, int) _rowAndColFromRef(String ref) {
    final colMatch = RegExp(r'[A-Z]+').firstMatch(ref);
    final rowMatch = RegExp(r'[0-9]+').firstMatch(ref);
    
    if (colMatch == null || rowMatch == null) return (0, 0);
    
    final colStr = colMatch.group(0)!;
    final rowStr = rowMatch.group(0)!;
    
    int colIndex = 0;
    for (int i = 0; i < colStr.length; i++) {
      colIndex = colIndex * 26 + (colStr.codeUnitAt(i) - 64);
    }
    
    return (int.parse(rowStr) - 1, colIndex - 1);
  }
}

class SpreadsheetPreviewData {
  const SpreadsheetPreviewData({
    required this.sheets,
  });

  final List<SpreadsheetSheetData> sheets;
}

class SpreadsheetSheetData {
  const SpreadsheetSheetData({
    required this.name,
    required this.rows,
  });

  final String name;
  final List<List<String>> rows;
}

class PresentationPreviewData {
  const PresentationPreviewData({
    required this.slides,
  });

  final List<PresentationSlideData> slides;
}

class PresentationSlideData {
  const PresentationSlideData({
    required this.title,
    required this.bullets,
  });

  final String title;
  final List<String> bullets;
}
