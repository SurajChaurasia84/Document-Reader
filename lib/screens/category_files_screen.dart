import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/app_file.dart';
import '../services/app_controller.dart';
import '../utils/instant_page_route.dart';
import '../utils/theme_utils.dart';
import '../widgets/recent_file_card.dart';
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
  text('Text');

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
  String _searchQuery = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final visibleFiles = _filteredFiles(widget.files, _formatFilter, _searchQuery);
    final sortedFiles = _sortedFiles(visibleFiles, _sortOption);
    final normalizedTitle = widget.title.toLowerCase();
    final showFormatFilters =
        normalizedTitle == 'all files' || normalizedTitle == 'favorites';

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                style: const TextStyle(color: Colors.white),
                cursorColor: Colors.white,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Search files...',
                  hintStyle: TextStyle(color: Colors.white70),
                ),
              )
            : Text(widget.title),
        actions: <Widget>[
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close_rounded : Icons.search_rounded,
              color: context.primaryText,
            ),
            tooltip: _isSearching ? 'Close search' : 'Search',
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchController.clear();
                } else {
                  _isSearching = true;
                  Future.microtask(() => _searchController.selection = TextSelection.collapsed(
                        offset: _searchController.text.length,
                      ));
                }
              });
            },
          ),
          PopupMenuButton<FileSortOption>(
            tooltip: 'Sort',
            icon: Icon(
              Icons.sort_rounded,
              color: context.primaryText,
            ),
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
                    final activeColor = selected
                        ? AppFile.getColorForLabel(filter.label,
                            fallback: context.primaryAccent)
                        : context.selectedAccent;
                    return _FormatChip(
                      label: filter.label,
                      selected: selected,
                      activeColor: activeColor,
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
                ? Center(
                    child: Text(
                      'No files found in this category.',
                      style: TextStyle(color: context.secondaryText),
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
                        return RecentFileCard(
                          file: file,
                          onTap: () async {
                            if (!await File(file.path).exists()) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'This file is no longer available on your device.',
                                    ),
                                  ),
                                );
                              }
                              return;
                            }
                            if (!context.mounted) {
                              return;
                            }
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => DocumentViewerScreen(file: file),
                              ),
                            );
                          },
                          onFavorite: () => controller.toggleFavorite(file),
                          onShare: () async {
                            if (!await File(file.path).exists()) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'This file is no longer available on your device.',
                                    ),
                                  ),
                                );
                              }
                              return;
                            }
                            await Share.shareXFiles(
                              <XFile>[XFile(file.path)],
                              text: 'Shared from PDF Studio',
                              subject: file.name,
                            );
                          },
                          onSave: () async {
                            try {
                              final savedPath = await controller.fileService
                                  .saveToPdfStudioFolder(file.path);
                              await controller.refreshAll();
                              if (!context.mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Saved to $savedPath')),
                              );
                            } catch (error) {
                              if (!context.mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    error.toString().replaceFirst('Exception: ', ''),
                                  ),
                                ),
                              );
                            }
                          },
                          onDelete: () async {
                            final shouldDelete = await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) {
                                return AlertDialog(
                                  title: const Text('Delete file?'),
                                  content: Text(
                                      'Are you sure you want to delete "${file.name}"?'),
                                  actions: <Widget>[
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(dialogContext).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.of(dialogContext).pop(true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                );
                              },
                            );

                            if (shouldDelete != true) {
                              return;
                            }

                            await controller.deleteManagedFile(file);
                            if (!context.mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('File deleted')),
                            );
                          },
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
    String query,
  ) {
    final lowerQuery = query.trim().toLowerCase();
    List<AppFile> filtered;
    switch (formatFilter) {
      case FileFormatFilter.all:
        filtered = List<AppFile>.from(files);
        break;
      case FileFormatFilter.pdf:
        filtered = files.where((file) => file.extension == 'pdf').toList();
        break;
      case FileFormatFilter.word:
        filtered = files
            .where((file) => <String>['doc', 'docx'].contains(file.extension))
            .toList();
        break;
      case FileFormatFilter.excel:
        filtered = files
            .where((file) => <String>['xls', 'xlsx'].contains(file.extension))
            .toList();
        break;
      case FileFormatFilter.ppt:
        filtered = files
            .where((file) => <String>['ppt', 'pptx'].contains(file.extension))
            .toList();
        break;
      case FileFormatFilter.text:
        filtered = files
            .where((file) => <String>['txt', 'csv', 'rtf'].contains(file.extension))
            .toList();
        break;
    }

    if (lowerQuery.isEmpty) {
      return filtered;
    }

    return filtered.where((file) {
      final name = file.name.toLowerCase();
      final extension = file.extension.toLowerCase();
      return name.contains(lowerQuery) || extension.contains(lowerQuery);
    }).toList();
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
    required this.activeColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? activeColor.withValues(alpha: 0.12) : context.softPanel,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? activeColor : context.borderColor,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? activeColor : context.secondaryText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
