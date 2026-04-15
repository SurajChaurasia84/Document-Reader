import 'package:flutter/material.dart';

import '../models/app_file.dart';
import '../utils/formatters.dart';
import '../utils/theme_utils.dart';
import 'glass_card.dart';

class FileTile extends StatelessWidget {
  const FileTile({
    super.key,
    required this.file,
    required this.onTap,
    required this.onFavoriteTap,
  });

  final AppFile file;
  final VoidCallback onTap;
  final VoidCallback onFavoriteTap;

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
    if (file.assetIcon != null) {
      switch (file.extension.toLowerCase()) {
        case 'pdf':
          return const Color(0xFFFFEAEA);
        case 'doc':
        case 'docx':
          return const Color(0xFFE8F0FF);
        case 'xls':
        case 'xlsx':
          return const Color(0xFFE6F4EA);
        case 'ppt':
        case 'pptx':
          return const Color(0xFFFFF4E5);
        case 'txt':
          return const Color(0xFFF1F3F4);
        default:
          return const Color(0xFFF3F4F6);
      }
    }

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

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: _containerColor(file),
            ),
            child: Center(
              child: file.assetIcon != null
                  ? Image.asset(
                      file.assetIcon!,
                      width: 26,
                      height: 26,
                      fit: BoxFit.contain,
                    )
                  : Icon(
                      _fileIcon(file.extension),
                      color: Colors.white,
                      size: 24,
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatFileSize(file.size)}  |  ${formatDate(file.modifiedAt)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: context.secondaryText),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onFavoriteTap,
            icon: Icon(
              file.isFavorite
                  ? Icons.star_rounded
                  : Icons.star_border_rounded,
              color: file.isFavorite
                  ? const Color(0xFFF3B63F)
                  : context.iconMuted,
            ),
          ),
        ],
      ),
    );
  }
}
