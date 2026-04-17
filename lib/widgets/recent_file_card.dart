import 'dart:io';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/app_file.dart';
import '../utils/formatters.dart';
import '../utils/theme_utils.dart';

import 'file_action_menu.dart';

class RecentFileCard extends StatelessWidget {
  const RecentFileCard({
    super.key,
    required this.file,
    required this.onTap,
    required this.onFavorite, // This is now toggle handled inside StandardFileActionMenu
    this.onShare,
    this.onSave,
    this.onDelete,
  });

  final AppFile file;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final VoidCallback? onShare;
  final VoidCallback? onSave;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.panelBackground,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _containerColor(file),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: file.assetIcon != null
                    ? Image.asset(
                        file.assetIcon!,
                        width: 32,
                        height: 32,
                        fit: BoxFit.contain,
                      )
                    : Icon(
                        _fileIcon(file.extension),
                        color: Colors.white,
                        size: 20,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.primaryText,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    RecentFileMetaText(
                      file: file,
                      textStyle: TextStyle(
                        color: context.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              StandardFileActionMenu(
                file: file,
                onOpen: onTap,
                onSave: onSave,
                onChanged: onFavorite, // Triggers Refresh
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _fileIcon(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'xls':
      case 'xlsx':
        return Icons.grid_on_rounded;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_rounded;
      case 'txt':
        return Icons.notes_rounded;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  static Color _containerColor(AppFile file) {
    if (file.assetIcon != null) return Colors.transparent;

    switch (file.extension.toLowerCase()) {
      case 'pdf':
        return const Color(0xFFD93025);
      case 'doc':
      case 'docx':
        return const Color(0xFF2F6FD6);
      case 'xls':
      case 'xlsx':
        return const Color(0xFF16A34A);
      case 'ppt':
      case 'pptx':
        return const Color(0xFFE9742B);
      case 'txt':
        return const Color(0xFF586274);
      default:
        return const Color(0xFF6B7280);
    }
  }
}

class RecentFileMetaText extends StatelessWidget {
  const RecentFileMetaText({required this.file, required this.textStyle});

  final AppFile file;
  final TextStyle textStyle;

  static final Map<String, Future<String>> _pageCountCache =
      <String, Future<String>>{};

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _pageCountCache.putIfAbsent(file.path, () => _pageCountLabel(file)),
      builder: (context, snapshot) {
        final pageLabel = snapshot.data ?? _fallbackPageLabel(file);
        return Text(
          '$pageLabel  •  ${formatFileSize(file.size)}  •  ${formatDate(file.modifiedAt)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textStyle,
        );
      },
    );
  }

  static Future<String> _pageCountLabel(AppFile file) async {
    if (file.isPdf && file.size <= 15 * 1024 * 1024) {
      try {
        final document = PdfDocument(inputBytes: await File(file.path).readAsBytes());
        final count = document.pages.count;
        document.dispose();
        return count == 1 ? '1 page' : '$count pages';
      } catch (_) {
        return _fallbackPageLabel(file);
      }
    }

    return _fallbackPageLabel(file);
  }

  static String _fallbackPageLabel(AppFile file) {
    if (file.isImage) {
      return '1 page';
    }
    return '-- pages';
  }
}
