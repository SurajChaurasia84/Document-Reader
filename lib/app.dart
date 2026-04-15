import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'screens/splash_screen.dart';
import 'screens/shell_screen.dart';
import 'services/ai_service.dart';
import 'services/app_controller.dart';
import 'services/database_service.dart';
import 'services/file_service.dart';
import 'services/office_service.dart';
import 'services/ocr_service.dart';
import 'services/pdf_service.dart';
import 'services/scanner_service.dart';
import 'services/storage_info_service.dart';
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
        officeService: OfficeService(),
        ocrService: OcrService(),
        aiService: AiService(),
        scannerService: ScannerService(),
        storageInfoService: StorageInfoService(),
      )..initialize(),
      child: Consumer<AppController>(
        builder: (context, controller, _) {
          final themeMode = controller.isDarkMode ? ThemeMode.dark : ThemeMode.light;
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'PDF Studio',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeMode,
            builder: (context, child) {
              final activeTheme = Theme.of(context);
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: overlayStyleForTheme(activeTheme),
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: const SplashScreen(child: ShellScreen()),
          );
        },
      ),
    );
  }
}
