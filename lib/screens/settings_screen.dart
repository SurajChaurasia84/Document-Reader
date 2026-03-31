import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_controller.dart';
import '../widgets/glass_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      children: <Widget>[
        Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'Manage your document library, refresh local data, and check app status.',
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
                'Library Overview',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text('Recent files: ${controller.recentFiles.length}'),
              const SizedBox(height: 6),
              Text('Favorites: ${controller.favoriteFiles.length}'),
              const SizedBox(height: 6),
              Text('Internal files: ${controller.internalFiles.length}'),
              const SizedBox(height: 6),
              Text('Downloads: ${controller.downloadFiles.length}'),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: controller.refreshAll,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Refresh files'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Features', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              const Text(
                'All document tools, OCR, summarizer, and translation are available without subscription.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
