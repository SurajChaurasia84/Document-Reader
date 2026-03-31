import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/app_file.dart';

class FileService {
  static const supportedExtensions = <String>[
    'pdf',
    'docx',
    'xlsx',
    'pptx',
    'txt',
    'jpg',
    'jpeg',
    'png',
    'webp',
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

  Future<List<AppFile>> listInternalFiles({
    Set<String> favorites = const <String>{},
  }) async {
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

  Future<List<AppFile>> _listSupportedFiles(
    Directory directory, {
    required Set<String> favorites,
  }) async {
    if (!await directory.exists()) {
      return <AppFile>[];
    }

    final entities =
        directory
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .where(
              (file) => supportedExtensions.contains(
                p.extension(file.path).replaceFirst('.', '').toLowerCase(),
              ),
            )
            .toList()
          ..sort(
            (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
          );

    return entities
        .take(50)
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
}
