import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/shell_screen.dart';
import 'services/ai_service.dart';
import 'services/app_controller.dart';
import 'services/database_service.dart';
import 'services/file_service.dart';
import 'services/ocr_service.dart';
import 'services/pdf_service.dart';
import 'services/scanner_service.dart';
import 'services/storage_service.dart';
import 'utils/app_theme.dart';

class DocReaderApp extends StatelessWidget {
  const DocReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppController(
        storageService: StorageService(),
        databaseService: DatabaseService(),
        fileService: FileService(),
        pdfService: PdfService(),
        ocrService: OcrService(),
        aiService: AiService(),
        scannerService: ScannerService(),
      )..initialize(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Doc Reader',
        theme: AppTheme.darkTheme,
        home: const ShellScreen(),
      ),
    );
  }
}
