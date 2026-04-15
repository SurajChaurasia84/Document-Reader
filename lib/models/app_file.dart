import 'dart:io';

import 'package:path/path.dart' as p;

class AppFile {
  const AppFile({
    required this.path,
    required this.name,
    required this.extension,
    required this.size,
    required this.modifiedAt,
    this.isFavorite = false,
  });

  final String path;
  final String name;
  final String extension;
  final int size;
  final DateTime modifiedAt;
  final bool isFavorite;

  bool get isPdf => extension.toLowerCase() == 'pdf';
  bool get isText => extension.toLowerCase() == 'txt';
  bool get isImage =>
      ['jpg', 'jpeg', 'png', 'webp'].contains(extension.toLowerCase());
  bool get isOffice =>
      ['docx', 'xlsx', 'pptx'].contains(extension.toLowerCase());
  String get displayType => extension.toUpperCase();

  String? get assetIcon {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'assets/pdf.png';
      case 'docx':
        return 'assets/doc.png';
      case 'xlsx':
        return 'assets/xls.png';
      case 'pptx':
        return 'assets/ppt.png';
      case 'txt':
        return 'assets/txt.png';
      default:
        return null;
    }
  }

  AppFile copyWith({
    String? path,
    String? name,
    String? extension,
    int? size,
    DateTime? modifiedAt,
    bool? isFavorite,
  }) {
    return AppFile(
      path: path ?? this.path,
      name: name ?? this.name,
      extension: extension ?? this.extension,
      size: size ?? this.size,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'path': path,
      'name': name,
      'extension': extension,
      'size': size,
      'modified_at': modifiedAt.millisecondsSinceEpoch,
    };
  }

  factory AppFile.fromMap(Map<String, dynamic> map, {bool isFavorite = false}) {
    return AppFile(
      path: map['path'] as String,
      name: map['name'] as String,
      extension: map['extension'] as String,
      size: map['size'] as int,
      modifiedAt: DateTime.fromMillisecondsSinceEpoch(
        map['modified_at'] as int,
      ),
      isFavorite: isFavorite,
    );
  }

  factory AppFile.fromFileSystemEntity(
    FileSystemEntity entity, {
    bool isFavorite = false,
  }) {
    final file = File(entity.path);
    final stat = file.statSync();
    final extension = p
        .extension(entity.path)
        .replaceFirst('.', '')
        .toLowerCase();
    return AppFile(
      path: entity.path,
      name: p.basename(entity.path),
      extension: extension,
      size: stat.size,
      modifiedAt: stat.modified,
      isFavorite: isFavorite,
    );
  }
}
