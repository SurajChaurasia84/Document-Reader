class StorageInfo {
  const StorageInfo({
    required this.label,
    required this.path,
    required this.totalBytes,
    required this.availableBytes,
    required this.isAvailable,
  });

  final String label;
  final String path;
  final int totalBytes;
  final int availableBytes;
  final bool isAvailable;

  int get usedBytes => (totalBytes - availableBytes).clamp(0, totalBytes);

  double get usedFraction {
    if (totalBytes <= 0) {
      return 0;
    }
    return usedBytes / totalBytes;
  }

  factory StorageInfo.fromMap(Map<Object?, Object?> map) {
    return StorageInfo(
      label: map['label'] as String? ?? 'Storage',
      path: map['path'] as String? ?? '',
      totalBytes: (map['totalBytes'] as num?)?.toInt() ?? 0,
      availableBytes: (map['availableBytes'] as num?)?.toInt() ?? 0,
      isAvailable: map['isAvailable'] as bool? ?? false,
    );
  }
}
