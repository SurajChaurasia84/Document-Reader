import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_file.dart';
import '../services/app_controller.dart';
import '../utils/app_theme.dart';
import '../widgets/file_tile.dart';
import '../widgets/glass_card.dart';
import '../widgets/neon_button.dart';
import 'document_viewer_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();

    return RefreshIndicator(
      onRefresh: controller.refreshAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: <Widget>[
          Text('Doc Reader', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Offline-first document hub with smart tools, scanner, OCR, and premium AI workflows.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 20),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Quick Start',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    NeonButton(
                      label: 'Open file',
                      icon: Icons.folder_open,
                      onPressed: () async {
                        final file = await controller.pickDocument();
                        if (file != null && context.mounted) {
                          _openViewer(context, file);
                        } else if (controller.statusMessage != null &&
                            context.mounted) {
                          _showSnack(context, controller.statusMessage!);
                        }
                      },
                    ),
                    OutlinedButton.icon(
                      onPressed: controller.lastOpenedFile == null
                          ? null
                          : () => _openViewer(
                              context,
                              controller.lastOpenedFile!,
                            ),
                      icon: const Icon(Icons.play_circle_outline),
                      label: const Text('Resume'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (controller.lastOpenedFile != null) ...<Widget>[
            _SectionTitle(
              title: 'Resume last opened',
              action: TextButton(
                onPressed: () =>
                    _openViewer(context, controller.lastOpenedFile!),
                child: const Text('Open'),
              ),
            ),
            FileTile(
              file: controller.lastOpenedFile!,
              onTap: () => _openViewer(context, controller.lastOpenedFile!),
              onFavoriteTap: () =>
                  controller.toggleFavorite(controller.lastOpenedFile!),
            ),
            const SizedBox(height: 20),
          ],
          _SectionTitle(title: 'Recent files'),
          const SizedBox(height: 8),
          if (controller.recentFiles.isEmpty)
            const _EmptyState(
              label: 'No recent files yet. Open a document to start.',
            )
          else
            ...controller.recentFiles.map(
              (file) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: FileTile(
                  file: file,
                  onTap: () => _openViewer(context, file),
                  onFavoriteTap: () => controller.toggleFavorite(file),
                ),
              ),
            ),
          const SizedBox(height: 20),
          _SectionTitle(title: 'Favorites'),
          const SizedBox(height: 8),
          if (controller.favoriteFiles.isEmpty)
            const _EmptyState(label: 'Favorite files you star will show here.')
          else
            ...controller.favoriteFiles
                .take(6)
                .map(
                  (file) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FileTile(
                      file: file,
                      onTap: () => _openViewer(context, file),
                      onFavoriteTap: () => controller.toggleFavorite(file),
                    ),
                  ),
                ),
          if (controller.statusMessage != null) ...<Widget>[
            const SizedBox(height: 20),
            Text(
              controller.statusMessage!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.cyan),
            ),
          ],
        ],
      ),
    );
  }

  void _openViewer(BuildContext context, AppFile file) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => DocumentViewerScreen(file: file)),
    );
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (action != null) ...<Widget>[const SizedBox(width: 12), action!],
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
      ),
    );
  }
}
