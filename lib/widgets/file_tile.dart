import 'package:flutter/material.dart';

import '../models/app_file.dart';
import '../utils/formatters.dart';
import 'glass_card.dart';
import 'premium_badge.dart';

class FileTile extends StatelessWidget {
  const FileTile({
    super.key,
    required this.file,
    required this.onTap,
    required this.onFavoriteTap,
    this.showPremium = false,
  });

  final AppFile file;
  final VoidCallback onTap;
  final VoidCallback onFavoriteTap;
  final bool showPremium;

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
              color: Colors.white.withValues(alpha: 0.08),
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
                  '${formatFileSize(file.size)}  •  ${formatDate(file.modifiedAt)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          if (showPremium) ...<Widget>[
            const PremiumBadge(),
            const SizedBox(width: 8),
          ],
          IconButton(
            onPressed: onFavoriteTap,
            icon: Icon(
              file.isFavorite ? Icons.favorite : Icons.favorite_border,
            ),
          ),
        ],
      ),
    );
  }
}
