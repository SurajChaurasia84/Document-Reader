import 'storage_info.dart';

class StorageOverview {
  const StorageOverview({
    required this.filesStorage,
    required this.sdCardStorage,
  });

  final StorageInfo filesStorage;
  final StorageInfo? sdCardStorage;

  factory StorageOverview.fromMap(Map<Object?, Object?> map) {
    final filesStorageMap =
        map['filesStorage'] as Map<Object?, Object?>? ?? <Object?, Object?>{};
    final sdCardMap = map['sdCardStorage'] as Map<Object?, Object?>?;
    return StorageOverview(
      filesStorage: StorageInfo.fromMap(filesStorageMap),
      sdCardStorage: sdCardMap == null ? null : StorageInfo.fromMap(sdCardMap),
    );
  }
}
