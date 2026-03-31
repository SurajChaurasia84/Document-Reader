import 'package:flutter/services.dart';

import '../models/storage_info.dart';
import '../models/storage_overview.dart';

class StorageInfoService {
  static const MethodChannel _channel = MethodChannel(
    'doc_reader/storage_info',
  );

  Future<StorageOverview?> getStorageOverview() async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'getStorageOverview',
      );
      if (result == null) {
        return _fallbackOverview();
      }
      return StorageOverview.fromMap(result);
    } on PlatformException {
      return _fallbackOverview();
    } on MissingPluginException {
      return _fallbackOverview();
    }
  }

  StorageOverview _fallbackOverview() {
    return const StorageOverview(
      filesStorage: StorageInfo(
        label: 'Files Storage',
        path: '',
        totalBytes: 0,
        availableBytes: 0,
        isAvailable: false,
      ),
      sdCardStorage: StorageInfo(
        label: 'SD Card',
        path: '',
        totalBytes: 0,
        availableBytes: 0,
        isAvailable: false,
      ),
    );
  }
}
