import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/app_file.dart';

class FileService {
  final ImagePicker _imagePicker = ImagePicker();

  static const supportedExtensions = <String>[
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
    'txt',
    'csv',
    'rtf',
  ];

  Future<void> ensureStoragePermissions() async {
    if (!Platform.isAndroid) {
      return;
    }

    if (await Permission.manageExternalStorage.isGranted) {
      return;
    }

    final allFilesStatus = await Permission.manageExternalStorage.request();
    if (allFilesStatus.isGranted) {
      return;
    }

    final fallbackStatuses = await <Permission>[
      Permission.storage,
      Permission.photos,
      Permission.videos,
      Permission.audio,
    ].request();

    final mediaAccessGranted = fallbackStatuses.values.any(
      (status) => status.isGranted || status.isLimited,
    );
    if (mediaAccessGranted) {
      return;
    }

    if (allFilesStatus.isPermanentlyDenied) {
      await openAppSettings();
      throw const FileSystemException(
        'All files access is required. Enable it from App Settings.',
      );
    }

    throw const FileSystemException('Storage permission denied.');
  }

  Future<AppFile?> pickSingleDocument() async {
    await ensureStoragePermissions();
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: supportedExtensions,
    );
    if (result == null || result.files.single.path == null) {
      return null;
    }
    return AppFile.fromFileSystemEntity(File(result.files.single.path!));
  }

  Future<List<String>> pickPdfFiles({bool allowMultiple = true}) async {
    await ensureStoragePermissions();
    final result = await FilePicker.pickFiles(
      allowMultiple: allowMultiple,
      type: FileType.custom,
      allowedExtensions: const <String>['pdf'],
    );
    if (result == null) {
      return <String>[];
    }
    return result.paths.whereType<String>().toList();
  }

  Future<List<String>> pickWordFiles({bool allowMultiple = true}) async {
    await ensureStoragePermissions();
    final result = await FilePicker.pickFiles(
      allowMultiple: allowMultiple,
      type: FileType.custom,
      allowedExtensions: const <String>['doc', 'docx'],
    );
    if (result == null) {
      return <String>[];
    }
    return result.paths.whereType<String>().toList();
  }

  Future<List<String>> pickImageFiles({bool allowMultiple = true}) async {
    await ensureStoragePermissions();
    final result = await FilePicker.pickFiles(
      allowMultiple: allowMultiple,
      type: FileType.image,
    );
    if (result == null) {
      return <String>[];
    }
    return result.paths.whereType<String>().toList();
  }

  Future<List<String>> pickPhotoLibraryImages({
    bool allowMultiple = true,
  }) async {
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        List<XFile> photos;
        if (allowMultiple) {
          try {
            photos = await _imagePicker.pickMultiImage(
              imageQuality: 100,
              requestFullMetadata: false,
            );
          } on PlatformException {
            final single = await _imagePicker.pickImage(
              source: ImageSource.gallery,
              imageQuality: 100,
              requestFullMetadata: false,
            );
            photos = <XFile>[if (single != null) single];
          }
        } else {
          final single = await _imagePicker.pickImage(
            source: ImageSource.gallery,
            imageQuality: 100,
            requestFullMetadata: false,
          );
          photos = <XFile>[if (single != null) single];
        }

        return photos.map((file) => file.path).toList();
      } on PlatformException catch (error) {
        throw FileSystemException(
          'Unable to open photo library: ${error.message ?? error.code}',
        );
      }
    }

    return pickImageFiles(allowMultiple: allowMultiple);
  }

  static const _channel = MethodChannel('pdf_studio/storage_info');

  Future<List<AppFile>> fetchMediaStoreDocuments({
    Set<String> favorites = const <String>{},
  }) async {
    if (!Platform.isAndroid) return <AppFile>[];
    
    await ensureStoragePermissions();
    
    try {
      final List<dynamic> result = await _channel.invokeMethod('fetchMediaStoreFiles');
      if (result.isEmpty) return <AppFile>[];

      // OFF-LOAD TO BACKGROUND ISOLATE
      // This prevents UI freezes when parsing 10k+ files
      return await Isolate.run(() {
        final List<AppFile> parsedFiles = result.map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          return AppFile.fromMap(
            map,
            isFavorite: favorites.contains(map['path']),
          );
        }).toList();

        // Sort in background
        parsedFiles.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
        return parsedFiles;
      });
    } catch (e) {
      debugPrint('MediaStore error: $e');
      return <AppFile>[];
    }
  }

  Future<List<AppFile>> listDownloads({
    Set<String> favorites = const <String>{},
  }) async {
    final allFiles = await fetchMediaStoreDocuments(favorites: favorites);
    return allFiles.where((file) {
      final path = file.path.toLowerCase();
      return path.contains('/download/') || path.contains('/downloads/');
    }).toList();
  }

  Future<String> readTextFile(String path) {
    return File(path).readAsString();
  }

  Future<String> saveToPdfStudioFolder(String sourcePath) async {
    await ensureStoragePermissions();
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw const FileSystemException('Source file not found.');
    }

    Directory targetDirectory;
    if (Platform.isAndroid) {
      targetDirectory = Directory('/storage/emulated/0/PDF Studio');
    } else {
      final root = await getApplicationDocumentsDirectory();
      targetDirectory = Directory(p.join(root.path, 'PDF Studio'));
    }

    if (!await targetDirectory.exists()) {
      await targetDirectory.create(recursive: true);
    }

    final extension = p.extension(sourcePath);
    final baseName = p.basenameWithoutExtension(sourcePath);
    var fileName = '$baseName$extension';
    var targetPath = p.join(targetDirectory.path, fileName);
    var suffix = 1;

    while (await File(targetPath).exists()) {
      fileName = '${baseName}_$suffix$extension';
      targetPath = p.join(targetDirectory.path, fileName);
      suffix++;
    }

    await sourceFile.copy(targetPath);
    return targetPath;
  }

  Future<void> deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<String> renameFile(String sourcePath, String newName) async {
    final file = File(sourcePath);
    if (!await file.exists()) {
      throw const FileSystemException('Source file not found.');
    }

    final directory = p.dirname(sourcePath);
    final extension = p.extension(sourcePath);
    final sanitizedBaseName = newName
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    if (sanitizedBaseName.isEmpty) {
      throw const FileSystemException('Please enter a valid file name.');
    }

    final normalizedName = sanitizedBaseName.toLowerCase().endsWith(
          extension.toLowerCase(),
        )
        ? sanitizedBaseName
        : '$sanitizedBaseName$extension';
    var targetPath = p.join(directory, normalizedName);
    var suffix = 1;

    while (await File(targetPath).exists() &&
        p.normalize(targetPath).toLowerCase() !=
            p.normalize(sourcePath).toLowerCase()) {
      final base = p.basenameWithoutExtension(normalizedName);
      targetPath = p.join(directory, '${base}_$suffix$extension');
      suffix++;
    }

    if (p.normalize(targetPath).toLowerCase() ==
        p.normalize(sourcePath).toLowerCase()) {
      return sourcePath;
    }

    final renamed = await file.rename(targetPath);
    return renamed.path;
  }

  bool _isIgnoredPath(String normalizedPath) {
    final ignoredSegments = <String>[
      '${Platform.pathSeparator}.',
      '${Platform.pathSeparator}.trash${Platform.pathSeparator}',
      '${Platform.pathSeparator}trash${Platform.pathSeparator}',
      '${Platform.pathSeparator}deleted${Platform.pathSeparator}',
      '${Platform.pathSeparator}.deleted${Platform.pathSeparator}',
      '${Platform.pathSeparator}recycle bin${Platform.pathSeparator}',
      '${Platform.pathSeparator}.recycle${Platform.pathSeparator}',
    ];

    return ignoredSegments.any((segment) => normalizedPath.contains(segment));
  }
}
