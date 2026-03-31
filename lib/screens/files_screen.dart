import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_file.dart';
import '../services/app_controller.dart';
import '../widgets/file_tile.dart';
import '../widgets/fixed_top_header.dart';
import 'document_viewer_screen.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 2,
    vsync: this,
  );

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();

    return Column(
      children: <Widget>[
        const FixedTopHeader(title: 'Files'),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Browse app storage and Downloads with file size and modified date.',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              TabBar(
                controller: _tabController,
                tabs: const <Widget>[
                  Tab(text: 'Internal'),
                  Tab(text: 'Downloads'),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: <Widget>[
              _FileList(files: controller.internalFiles),
              _FileList(files: controller.downloadFiles),
            ],
          ),
        ),
      ],
    );
  }
}

class _FileList extends StatelessWidget {
  const _FileList({required this.files});

  final List<AppFile> files;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<AppController>();
    if (files.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        children: const <Widget>[
          Text('No supported files found in this location.'),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: controller.refreshAll,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        itemBuilder: (context, index) {
          final file = files[index];
          return FileTile(
            file: file,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DocumentViewerScreen(file: file),
                ),
              );
            },
            onFavoriteTap: () => controller.toggleFavorite(file),
          );
        },
        separatorBuilder: (_, index) => const SizedBox(height: 12),
        itemCount: files.length,
      ),
    );
  }
}
