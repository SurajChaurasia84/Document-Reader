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
              color: context.isDarkMode
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFE9EEF8),
            ),
            child: Center(
              child: Text(
                file.displayType,
                style: const TextStyle(fontWeight: FontWeight.w700),
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
