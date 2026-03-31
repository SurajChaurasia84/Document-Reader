import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_file.dart';
import '../services/app_controller.dart';
import '../widgets/file_tile.dart';
import 'document_viewer_screen.dart';

enum FileSortOption {
  newest('Newest first'),
  oldest('Oldest first'),
  nameAsc('Name A-Z'),
  nameDesc('Name Z-A'),
  sizeLargest('Largest first'),
  sizeSmallest('Smallest first');

  const FileSortOption(this.label);
  final String label;
}

class CategoryFilesScreen extends StatefulWidget {
  const CategoryFilesScreen({
    super.key,
    required this.title,
    required this.files,
  });

  final String title;
  final List<AppFile> files;

  @override
  State<CategoryFilesScreen> createState() => _CategoryFilesScreenState();
}

class _CategoryFilesScreenState extends State<CategoryFilesScreen> {
  FileSortOption _sortOption = FileSortOption.newest;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final sortedFiles = _sortedFiles(widget.files, _sortOption);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(widget.title),
        actions: <Widget>[
          PopupMenuButton<FileSortOption>(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort_rounded),
            initialValue: _sortOption,
            onSelected: (value) {
              setState(() {
                _sortOption = value;
              });
            },
            itemBuilder: (context) {
              return FileSortOption.values.map((option) {
                return PopupMenuItem<FileSortOption>(
                  value: option,
                  child: Text(option.label),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: sortedFiles.isEmpty
          ? const Center(
              child: Text(
                'No files found in this category.',
                style: TextStyle(color: Colors.white70),
              ),
            )
          : RefreshIndicator(
              onRefresh: controller.refreshAll,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                itemCount: sortedFiles.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final file = sortedFiles[index];
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
              ),
            ),
    );
  }

  List<AppFile> _sortedFiles(List<AppFile> files, FileSortOption sortOption) {
    final sorted = List<AppFile>.from(files);
    switch (sortOption) {
      case FileSortOption.newest:
        sorted.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
      case FileSortOption.oldest:
        sorted.sort((a, b) => a.modifiedAt.compareTo(b.modifiedAt));
      case FileSortOption.nameAsc:
        sorted.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case FileSortOption.nameDesc:
        sorted.sort(
          (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
        );
      case FileSortOption.sizeLargest:
        sorted.sort((a, b) => b.size.compareTo(a.size));
      case FileSortOption.sizeSmallest:
        sorted.sort((a, b) => a.size.compareTo(b.size));
    }
    return sorted;
  }
}
