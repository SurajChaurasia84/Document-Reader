import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../models/app_file.dart';
import 'ai_service.dart';
import 'database_service.dart';
import 'file_service.dart';
import 'office_service.dart';
import 'ocr_service.dart';
import 'pdf_service.dart';
import 'scanner_service.dart';
import 'storage_service.dart';

class AppController extends ChangeNotifier {
  AppController({
    required this.storageService,
    required this.databaseService,
    required this.fileService,
    required this.pdfService,
    required this.officeService,
    required this.ocrService,
    required this.aiService,
    required this.scannerService,
  });

  final StorageService storageService;
  final DatabaseService databaseService;
  final FileService fileService;
  final PdfService pdfService;
  final OfficeService officeService;
  final OcrService ocrService;
  final AiService aiService;
  final ScannerService scannerService;

  bool isInitialized = false;
  bool isLoading = false;
  int currentIndex = 0;
  String? statusMessage;

  List<AppFile> recentFiles = <AppFile>[];
  List<AppFile> favoriteFiles = <AppFile>[];
  List<AppFile> internalFiles = <AppFile>[];
  List<AppFile> downloadFiles = <AppFile>[];
  AppFile? lastOpenedFile;

  Future<void> initialize() async {
    await _runBusyTask(() async {
      await storageService.init();
      await databaseService.init();
      await refreshAll();
      isInitialized = true;
    });
  }

  Future<void> refreshAll() async {
    final favorites = await storageService.getFavorites();
    final storedRecentFiles = await databaseService.getRecentFiles();
    final availableRecentFiles = <AppFile>[];
    for (final file in storedRecentFiles) {
      if (await File(file.path).exists()) {
        availableRecentFiles.add(
          file.copyWith(isFavorite: favorites.contains(file.path)),
        );
      } else {
        await databaseService.deleteRecentFile(file.path);
      }
    }
    recentFiles = availableRecentFiles;
    internalFiles = await fileService.listInternalFiles(favorites: favorites);
    downloadFiles = await fileService.listDownloads(favorites: favorites);

    favoriteFiles =
        <AppFile>[...recentFiles, ...internalFiles, ...downloadFiles]
            .where((file) => favorites.contains(file.path))
            .fold<Map<String, AppFile>>(<String, AppFile>{}, (map, file) {
              map[file.path] = file.copyWith(isFavorite: true);
              return map;
            })
            .values
            .toList()
          ..sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));

    final lastPath = await storageService.getLastOpenedPath();
    final allFiles = <AppFile>[
      ...recentFiles,
      ...favoriteFiles,
      ...internalFiles,
      ...downloadFiles,
    ];
    lastOpenedFile = allFiles.firstWhereOrNull((file) => file.path == lastPath);
    if (lastOpenedFile == null &&
        lastPath != null &&
        await File(lastPath).exists()) {
      lastOpenedFile = AppFile.fromFileSystemEntity(
        File(lastPath),
        isFavorite: favorites.contains(lastPath),
      );
    }
    notifyListeners();
  }

  void updateNavigation(int index) {
    currentIndex = index;
    notifyListeners();
  }

  Future<AppFile?> pickDocument() async {
    final file = await fileService.pickSingleDocument();
    if (file == null) {
      return null;
    }
    await openFile(file);
    return file;
  }

  Future<void> openFile(AppFile file) async {
    if (!await File(file.path).exists()) {
      statusMessage = 'This file is no longer available on your device.';
      notifyListeners();
      return;
    }
    await databaseService.upsertRecentFile(file);
    await storageService.setLastOpenedPath(file.path);
    await refreshAll();
  }

  Future<void> toggleFavorite(AppFile file) async {
    final nextValue = !file.isFavorite;
    _applyFavoriteState(file.path, nextValue);
    notifyListeners();

    try {
      await storageService.setFavorite(file.path, nextValue);
      await refreshAll();
    } catch (_) {
      _applyFavoriteState(file.path, file.isFavorite);
      notifyListeners();
      rethrow;
    }
  }

  Future<String?> mergePdfs() {
    return _runBusyTask(() async {
      final files = await fileService.pickPdfFiles(allowMultiple: true);
      if (files.length < 2) {
        throw Exception('Pick at least two PDF files to merge.');
      }
      final output = await pdfService.mergePdfs(files);
      statusMessage = 'Merged PDF saved to $output';
      return output;
    });
  }

  Future<String?> mergePdfsFromPaths(
    List<String> paths, {
    String? outputFileName,
  }) {
    return _runBusyTask(() async {
      if (paths.length < 2) {
        throw Exception('Pick at least two PDF files to merge.');
      }
      final output = await pdfService.mergePdfs(
        paths,
        outputFileName: outputFileName,
      );
      statusMessage = 'Merged PDF saved to $output';
      await refreshAll();
      return output;
    });
  }

  Future<List<String>?> splitPdf() {
    return _runBusyTask(() async {
      final files = await fileService.pickPdfFiles(allowMultiple: false);
      if (files.isEmpty) {
        throw Exception('Pick a PDF to split.');
      }
      final output = await pdfService.splitPdf(files.first);
      statusMessage = 'Created ${output.length} split files.';
      return output;
    });
  }

  Future<List<String>?> splitPdfPages(
    String inputPath,
    List<int> pageNumbers, {
    String? outputPrefix,
  }) {
    return _runBusyTask(() async {
      if (pageNumbers.isEmpty) {
        throw Exception('Select at least one page to split.');
      }
      final output = await pdfService.splitPdfPages(
        inputPath,
        pageNumbers,
        outputPrefix: outputPrefix,
      );
      statusMessage = 'Created ${output.length} split files.';
      await refreshAll();
      return output;
    });
  }

  Future<String?> imageToPdf() {
    return _runBusyTask(() async {
      final files = await fileService.pickImageFiles(allowMultiple: true);
      if (files.isEmpty) {
        throw Exception('Pick one or more images.');
      }
      final output = await pdfService.imageToPdf(files);
      statusMessage = 'Image PDF saved to $output';
      await refreshAll();
      return output;
    });
  }

  Future<List<String>?> pdfToImages() {
    return _runBusyTask(() async {
      final files = await fileService.pickPdfFiles(allowMultiple: false);
      if (files.isEmpty) {
        throw Exception('Pick a PDF to convert.');
      }
      final output = await pdfService.pdfToImages(files.first);
      statusMessage = 'Exported ${output.length} images.';
      return output;
    });
  }

  Future<String?> compressPdf() {
    return _runBusyTask(() async {
      final files = await fileService.pickPdfFiles(allowMultiple: false);
      if (files.isEmpty) {
        throw Exception('Pick a PDF to compress.');
      }
      final output = await pdfService.compressPdf(files.first);
      statusMessage = 'Compressed PDF saved to $output';
      await refreshAll();
      return output;
    });
  }

  Future<String?> compressPdfPath(
    String inputPath, {
    String? outputFileName,
  }) {
    return _runBusyTask(() async {
      final output = await pdfService.compressPdf(
        inputPath,
        outputFileName: outputFileName,
      );
      statusMessage = 'Compressed PDF saved to $output';
      await refreshAll();
      return output;
    });
  }

  Future<String?> wordToPdfPath(
    String inputPath, {
    String? outputFileName,
  }) {
    return _runBusyTask(() async {
      final output = await officeService.wordToPdf(
        inputPath,
        outputFileName: outputFileName,
      );
      statusMessage = 'Word PDF saved to $output';
      await refreshAll();
      return output;
    });
  }

  Future<String?> runOcrForFile(AppFile file) {
    return _runBusyTask(() async {
      if (file.isPdf) {
        return ocrService.recognizePdf(file.path, pdfService);
      }
      if (file.isImage) {
        return ocrService.recognizeFromImage(file.path);
      }
      if (file.isText) {
        return fileService.readTextFile(file.path);
      }
      throw Exception('OCR supports PDF and image files in this MVP.');
    });
  }

  Future<String?> summarizeFile(AppFile file) {
    return _runBusyTask(() async {
      final cached = await storageService.getCachedSummaries();
      final existing = cached[file.path];
      if (existing != null) {
        return existing;
      }
      final source = file.isText
          ? await fileService.readTextFile(file.path)
          : await runOcrForFile(file) ?? '';
      final summary = await aiService.summarizeText(source);
      await storageService.cacheSummary(file.path, summary);
      return summary;
    });
  }

  Future<String?> translateFile(
    AppFile file, {
    String targetLanguage = 'Hindi',
  }) {
    return _runBusyTask(() async {
      final source = file.isText
          ? await fileService.readTextFile(file.path)
          : await runOcrForFile(file) ?? '';
      return aiService.translateText(source, targetLanguage: targetLanguage);
    });
  }

  Future<void> openExternally(String path) async {
    await OpenFilex.open(path);
  }

  void setStatus(String? message) {
    statusMessage = message;
    notifyListeners();
  }

  Future<T?> _runBusyTask<T>(Future<T> Function() action) async {
    try {
      isLoading = true;
      statusMessage = null;
      notifyListeners();
      return await action();
    } catch (error) {
      statusMessage = error.toString().replaceFirst('Exception: ', '');
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    unawaited(ocrService.dispose());
    super.dispose();
  }

  void _applyFavoriteState(String path, bool isFavorite) {
    recentFiles = _updateFavoriteInList(recentFiles, path, isFavorite);
    internalFiles = _updateFavoriteInList(internalFiles, path, isFavorite);
    downloadFiles = _updateFavoriteInList(downloadFiles, path, isFavorite);
    favoriteFiles = _rebuildFavoriteFiles();
    if (lastOpenedFile?.path == path) {
      lastOpenedFile = lastOpenedFile?.copyWith(isFavorite: isFavorite);
    }
  }

  List<AppFile> _updateFavoriteInList(
    List<AppFile> files,
    String path,
    bool isFavorite,
  ) {
    return files
        .map(
          (file) => file.path == path
              ? file.copyWith(isFavorite: isFavorite)
              : file,
        )
        .toList();
  }

  List<AppFile> _rebuildFavoriteFiles() {
    final favorites = <String, AppFile>{};
    for (final file in <AppFile>[
      ...recentFiles,
      ...internalFiles,
      ...downloadFiles,
    ]) {
      if (file.isFavorite) {
        favorites[file.path] = file.copyWith(isFavorite: true);
      }
    }

    final files = favorites.values.toList()
      ..sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return files;
  }
}

extension<T> on List<T> {
  T? firstWhereOrNull(bool Function(T value) test) {
    for (final value in this) {
      if (test(value)) {
        return value;
      }
    }
    return null;
  }
}
