import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'pdf_service.dart';

class OcrService {
  final TextRecognizer _recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  Future<String> recognizeFromImage(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final result = await _recognizer.processImage(inputImage);
    return result.text.trim();
  }

  Future<String> recognizePdf(String pdfPath, PdfService pdfService) async {
    final bytes = await pdfService.renderPageAsImage(pdfPath, 1);
    if (bytes == null) {
      return '';
    }

    final temporary = await _createTempImage(
      bytes,
      '${p.basenameWithoutExtension(pdfPath)}_ocr.png',
    );
    try {
      return await recognizeFromImage(temporary.path);
    } finally {
      if (await temporary.exists()) {
        await temporary.delete();
      }
    }
  }

  Future<File> _createTempImage(Uint8List bytes, String name) async {
    final directory = await getTemporaryDirectory();
    final file = File(p.join(directory.path, name));
    return file.writeAsBytes(bytes, flush: true);
  }

  Future<void> dispose() async {
    await _recognizer.close();
  }
}
