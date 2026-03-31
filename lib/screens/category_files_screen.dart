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

enum FileFormatFilter {
  all('All'),
  pdf('PDF'),
  word('Word'),
  excel('Excel'),
  ppt('PPT'),
  text('Text'),
  image('Image');

  const FileFormatFilter(this.label);
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
  FileFormatFilter _formatFilter = FileFormatFilter.all;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final visibleFiles = _filteredFiles(widget.files, _formatFilter);
    final sortedFiles = _sortedFiles(visibleFiles, _sortOption);
    final normalizedTitle = widget.title.toLowerCase();
    final showFormatFilters =
        normalizedTitle == 'all files' || normalizedTitle == 'favorites';

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
      body: Column(
        children: <Widget>[
          if (showFormatFilters)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: FileFormatFilter.values.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final filter = FileFormatFilter.values[index];
                    final selected = filter == _formatFilter;
                    return _FormatChip(
                      label: filter.label,
                      selected: selected,
                      onTap: () {
                        setState(() {
                          _formatFilter = filter;
                        });
                      },
                    );
                  },
                ),
              ),
            ),
          Expanded(
            child: sortedFiles.isEmpty
                ? const Center(
                    child: Text(
                      'No files found in this category.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: controller.refreshAll,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
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
                                builder: (_) =>
                                    DocumentViewerScreen(file: file),
                              ),
                            );
                          },
                          onFavoriteTap: () => controller.toggleFavorite(file),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  List<AppFile> _filteredFiles(
    List<AppFile> files,
    FileFormatFilter formatFilter,
  ) {
    switch (formatFilter) {
      case FileFormatFilter.all:
        return List<AppFile>.from(files);
      case FileFormatFilter.pdf:
        return files.where((file) => file.extension == 'pdf').toList();
      case FileFormatFilter.word:
        return files
            .where((file) => <String>['doc', 'docx'].contains(file.extension))
            .toList();
      case FileFormatFilter.excel:
        return files
            .where((file) => <String>['xls', 'xlsx'].contains(file.extension))
            .toList();
      case FileFormatFilter.ppt:
        return files
            .where((file) => <String>['ppt', 'pptx'].contains(file.extension))
            .toList();
      case FileFormatFilter.text:
        return files
            .where((file) => <String>['txt', 'csv', 'rtf'].contains(file.extension))
            .toList();
      case FileFormatFilter.image:
        return files.where((file) => file.isImage).toList();
    }
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

class _FormatChip extends StatelessWidget {
  const _FormatChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF2C1A0A) : const Color(0xFF111423),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? const Color(0xFFFFA73A)
                  : const Color(0xFF1E2135),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? const Color(0xFFFFA73A)
                  : const Color(0xFF747A97),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
