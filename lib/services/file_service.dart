import 'dart:io';

import 'package:file_picker/file_picker.dart';
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
    final result = await FilePicker.platform.pickFiles(
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
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: allowMultiple,
      type: FileType.custom,
      allowedExtensions: const <String>['pdf'],
    );
    if (result == null) {
      return <String>[];
    }
    return result.paths.whereType<String>().toList();
  }

  Future<List<String>> pickImageFiles({bool allowMultiple = true}) async {
    await ensureStoragePermissions();
    final result = await FilePicker.platform.pickFiles(
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
            photos = <XFile>[?single];
          }
        } else {
          final single = await _imagePicker.pickImage(
            source: ImageSource.gallery,
            imageQuality: 100,
            requestFullMetadata: false,
          );
          photos = <XFile>[?single];
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

  Future<List<AppFile>> listInternalFiles({
    Set<String> favorites = const <String>{},
  }) async {
    await ensureStoragePermissions();
    if (Platform.isAndroid) {
      final directories = <Directory>[
        Directory('/storage/emulated/0/Documents'),
        Directory('/storage/emulated/0/Document'),
        Directory('/storage/emulated/0/Movies'),
        Directory('/storage/emulated/0/Recordings'),
        Directory('/storage/emulated/0/Podcasts'),
        Directory('/storage/emulated/0/Books'),
      ];
      return _listSupportedFilesFromDirectories(
        directories,
        favorites: favorites,
        excludedPaths: <String>{
          '/storage/emulated/0/Download',
          '/storage/emulated/0/Downloads',
          '/storage/emulated/0/Android',
          '/storage/emulated/0/.Trash',
          '/storage/emulated/0/Trash',
          '/storage/emulated/0/Recycle Bin',
          '/storage/emulated/0/.recycle',
          '/storage/emulated/0/Deleted',
          '/storage/emulated/0/.Deleted',
        },
      );
    }

    final directory = await getApplicationDocumentsDirectory();
    return _listSupportedFiles(directory, favorites: favorites);
  }

  Future<List<AppFile>> listDownloads({
    Set<String> favorites = const <String>{},
  }) async {
    await ensureStoragePermissions();
    final candidates = <Directory>[
      Directory('/storage/emulated/0/Download'),
      Directory('/storage/emulated/0/Downloads'),
    ];

    Directory? directory;
    for (final candidate in candidates) {
      if (await candidate.exists()) {
        directory = candidate;
        break;
      }
    }

    directory ??= await getTemporaryDirectory();
    return _listSupportedFiles(directory, favorites: favorites);
  }

  Future<List<AppFile>> _listSupportedFilesFromDirectories(
    List<Directory> directories, {
    required Set<String> favorites,
    Set<String> excludedPaths = const <String>{},
  }) async {
    final filesByPath = <String, AppFile>{};

    for (final directory in directories) {
      final files = await _listSupportedFiles(
        directory,
        favorites: favorites,
        excludedPaths: excludedPaths,
      );
      for (final file in files) {
        filesByPath[file.path] = file;
      }
    }

    final allFiles = filesByPath.values.toList()
      ..sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return allFiles;
  }

  Future<List<AppFile>> _listSupportedFiles(
    Directory directory, {
    required Set<String> favorites,
    Set<String> excludedPaths = const <String>{},
  }) async {
    if (!await directory.exists()) {
      return <AppFile>[];
    }

    final normalizedExclusions = excludedPaths
        .map((path) => p.normalize(path).toLowerCase())
        .toList();
    final entities = <File>[];

    try {
      await for (final entity
          in directory.list(recursive: true, followLinks: false)) {
        if (entity is! File) {
          continue;
        }

        final normalizedPath = p.normalize(entity.path).toLowerCase();
        if (_isIgnoredPath(normalizedPath)) {
          continue;
        }
        final isExcluded = normalizedExclusions.any(
          (path) =>
              normalizedPath == path ||
              normalizedPath.startsWith('$path${Platform.pathSeparator}'),
        );
        if (isExcluded) {
          continue;
        }

        final extension = p
            .extension(entity.path)
            .replaceFirst('.', '')
            .toLowerCase();
        if (!supportedExtensions.contains(extension)) {
          continue;
        }

        entities.add(entity);
      }
    } on FileSystemException {
      // Skip unreadable folders and return whatever could be scanned.
    }

    entities.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

    return entities
        .map(
          (file) => AppFile.fromFileSystemEntity(
            file,
            isFavorite: favorites.contains(file.path),
          ),
        )
        .toList();
  }

  Future<String> readTextFile(String path) {
    return File(path).readAsString();
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
