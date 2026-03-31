import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/app_file.dart';
import '../services/app_controller.dart';
import '../utils/formatters.dart';
import 'document_viewer_screen.dart';
import 'photo_preview_screen.dart';

enum CreationFilter {
  all('All'),
  merged('Merged'),
  compressed('Compressed'),
  imagePdf('Image PDF'),
  split('Split'),
  exported('PDF Images');

  const CreationFilter(this.label);

  final String label;
}

enum CreationSortOption {
  newest('Newest first'),
  oldest('Oldest first'),
  nameAsc('Name A-Z'),
  nameDesc('Name Z-A'),
  sizeLargest('Largest first'),
  sizeSmallest('Smallest first');

  const CreationSortOption(this.label);

  final String label;
}

class MyCreationsScreen extends StatefulWidget {
  const MyCreationsScreen({
    super.key,
    this.initialFiles = const <AppFile>[],
  });

  final List<AppFile> initialFiles;

  @override
  State<MyCreationsScreen> createState() => _MyCreationsScreenState();
}

class _MyCreationsScreenState extends State<MyCreationsScreen> {
  CreationFilter _filter = CreationFilter.all;
  CreationSortOption _sortOption = CreationSortOption.newest;
  late Future<List<AppFile>> _createdFilesFuture;

  @override
  void initState() {
    super.initState();
    _createdFilesFuture = Future<List<AppFile>>.value(widget.initialFiles);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();

    return FutureBuilder<List<AppFile>>(
      future: _createdFilesFuture,
      builder: (context, snapshot) {
        final createdFiles = snapshot.data ?? const <AppFile>[];
        final filteredFiles = _sortFiles(
          _applyFilter(createdFiles, _filter),
          _sortOption,
        );

        return Scaffold(
          backgroundColor: const Color(0xFF0A0E1A),
          appBar: AppBar(
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            title: const Text('My Creation'),
            actions: <Widget>[
              PopupMenuButton<CreationSortOption>(
                tooltip: 'Sort',
                icon: const Icon(Icons.sort_rounded),
                initialValue: _sortOption,
                color: const Color(0xFF181C2B),
                surfaceTintColor: Colors.transparent,
                onSelected: (value) {
                  setState(() {
                    _sortOption = value;
                  });
                },
                itemBuilder: (context) {
                  return CreationSortOption.values.map((option) {
                    return PopupMenuItem<CreationSortOption>(
                      value: option,
                      child: Text(
                        option.label,
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }).toList();
                },
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              await controller.refreshAll();
              _reloadCreatedFiles(controller);
            },
            color: const Color(0xFFF3B63F),
            backgroundColor: const Color(0xFF181C2B),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: <Widget>[
                const Text(
                  'Files you created inside PureDoc',
                  style: TextStyle(
                    color: Color(0xFF767C98),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: CreationFilter.values.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final filter = CreationFilter.values[index];
                      return _CreationChip(
                        label: filter.label,
                        selected: filter == _filter,
                        onTap: () {
                          setState(() {
                            _filter = filter;
                          });
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                if (snapshot.connectionState == ConnectionState.waiting &&
                    createdFiles.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (filteredFiles.isEmpty)
                  const _EmptyCreationsCard()
                else
                        ...filteredFiles.map(
                          (file) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _CreationFileCard(
                              file: file,
                              categoryLabel: _categoryLabelFor(file),
                              onTap: () => _openFile(context, controller, file),
                              onFavoriteToggle: () =>
                                  _toggleFavorite(context, controller, file),
                              onShare: () => _shareFile(context, file),
                              onDelete: () =>
                                  _deleteFile(context, controller, file),
                              onSave: () => _saveFile(context, controller, file),
                            ),
                          ),
                        ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _reloadCreatedFiles(AppController controller) {
    final future = controller.pdfService.listCreatedFiles(
      favorites: controller.favoriteFiles.map((file) => file.path).toSet(),
    );
    setState(() {
      _createdFilesFuture = future;
    });
  }

  Future<void> _openFile(
    BuildContext context,
    AppController controller,
    AppFile file,
  ) async {
    if (!await File(file.path).exists()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This created file is no longer available.'),
          ),
        );
      }
      return;
    }

    await controller.openFile(file);
    if (!context.mounted) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => file.isImage
            ? PhotoPreviewScreen(imagePaths: <String>[file.path])
            : DocumentViewerScreen(file: file),
      ),
    );
  }

  Future<void> _toggleFavorite(
    BuildContext context,
    AppController controller,
    AppFile file,
  ) async {
    await controller.toggleFavorite(file);
    if (!context.mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _shareFile(BuildContext context, AppFile file) async {
    if (!await File(file.path).exists()) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This file is no longer available.')),
      );
      return;
    }

    await Share.shareXFiles(
      <XFile>[XFile(file.path)],
      text: 'Shared from PureDoc',
      subject: file.name,
    );
  }

  Future<void> _saveFile(
    BuildContext context,
    AppController controller,
    AppFile file,
  ) async {
    try {
      final savedPath = await controller.fileService.saveToPureDocFolder(
        file.path,
      );
      await controller.refreshAll();
      _reloadCreatedFiles(controller);
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
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _deleteFile(
    BuildContext context,
    AppController controller,
    AppFile file,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete file?'),
          content: Text(
            'Are you sure you want to delete "${file.name}"?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await controller.fileService.deleteFile(file.path);
      await controller.refreshAll();
      _reloadCreatedFiles(controller);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File deleted')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  List<AppFile> _applyFilter(List<AppFile> files, CreationFilter filter) {
    switch (filter) {
      case CreationFilter.all:
        return List<AppFile>.from(files);
      case CreationFilter.merged:
        return files.where((file) => _creationKeyFor(file) == 'merged').toList();
      case CreationFilter.compressed:
        return files
            .where((file) => _creationKeyFor(file) == 'compressed')
            .toList();
      case CreationFilter.imagePdf:
        return files.where(_isImagePdf).toList();
      case CreationFilter.split:
        return files.where((file) => _creationKeyFor(file) == 'split').toList();
      case CreationFilter.exported:
        return files.where((file) => _creationKeyFor(file) == 'images').toList();
    }
  }

  List<AppFile> _sortFiles(
    List<AppFile> files,
    CreationSortOption sortOption,
  ) {
    final sorted = List<AppFile>.from(files);
    switch (sortOption) {
      case CreationSortOption.newest:
        sorted.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
      case CreationSortOption.oldest:
        sorted.sort((a, b) => a.modifiedAt.compareTo(b.modifiedAt));
      case CreationSortOption.nameAsc:
        sorted.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case CreationSortOption.nameDesc:
        sorted.sort(
          (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
        );
      case CreationSortOption.sizeLargest:
        sorted.sort((a, b) => b.size.compareTo(a.size));
      case CreationSortOption.sizeSmallest:
        sorted.sort((a, b) => a.size.compareTo(b.size));
    }
    return sorted;
  }

  String _creationKeyFor(AppFile file) {
    return p.basename(p.dirname(file.path)).toLowerCase();
  }

  bool _isImagePdf(AppFile file) {
    return _creationKeyFor(file) == 'scanner';
  }

  String _categoryLabelFor(AppFile file) {
    final key = _creationKeyFor(file);
    if (key == 'merged') {
      return 'Merged';
    }
    if (key == 'compressed') {
      return 'Compressed';
    }
    if (key == 'split') {
      return 'Split';
    }
    if (key == 'images') {
      return 'PDF Images';
    }
    if (_isImagePdf(file)) {
      return 'Image to PDF';
    }
    return 'Created';
  }
}

class _CreationChip extends StatelessWidget {
  const _CreationChip({
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

class _CreationFileCard extends StatelessWidget {
  const _CreationFileCard({
    required this.file,
    required this.categoryLabel,
    required this.onTap,
    required this.onFavoriteToggle,
    required this.onShare,
    required this.onDelete,
    required this.onSave,
  });

  final AppFile file;
  final String categoryLabel;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF131726),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF1E2135)),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2335),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  file.isImage
                      ? Icons.image_rounded
                      : Icons.picture_as_pdf_rounded,
                  color: const Color(0xFFD93025),
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$categoryLabel  •  ${formatFileSize(file.size)}  •  ${formatDate(file.modifiedAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF7D84A2),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<_CreationAction>(
                tooltip: 'More actions',
                color: const Color(0xFF181C2B),
                surfaceTintColor: Colors.transparent,
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: Color(0xFF98A0BC),
                ),
                onSelected: (value) {
                  switch (value) {
                    case _CreationAction.favorite:
                      onFavoriteToggle();
                    case _CreationAction.share:
                      onShare();
                    case _CreationAction.delete:
                      onDelete();
                    case _CreationAction.save:
                      onSave();
                  }
                },
                itemBuilder: (context) {
                  return <PopupMenuEntry<_CreationAction>>[
                    PopupMenuItem<_CreationAction>(
                      value: _CreationAction.favorite,
                      child: Text(
                        file.isFavorite
                            ? 'Remove from favourites'
                            : 'Add to favourites',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const PopupMenuItem<_CreationAction>(
                      value: _CreationAction.share,
                      child: Text(
                        'Share',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    const PopupMenuItem<_CreationAction>(
                      value: _CreationAction.save,
                      child: Text(
                        'Save',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    const PopupMenuItem<_CreationAction>(
                      value: _CreationAction.delete,
                      child: Text(
                        'Delete',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _CreationAction { favorite, share, save, delete }

class _EmptyCreationsCard extends StatelessWidget {
  const _EmptyCreationsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF131726),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1E2135)),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.folder_copy_rounded, color: Color(0xFF7D84A2), size: 34),
          SizedBox(height: 10),
          Text(
            'No creations found yet.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Merged PDFs, compressed files, scans, and image PDFs will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF7D84A2),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
