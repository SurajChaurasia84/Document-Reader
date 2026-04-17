import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/app_file.dart';
import '../services/app_controller.dart';
import '../utils/formatters.dart';
import '../utils/instant_page_route.dart';
import '../utils/theme_utils.dart';
import '../utils/file_action_helper.dart';
import '../widgets/file_action_menu.dart';
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
          backgroundColor: context.appBackground,
          appBar: AppBar(
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            title: const Text('My Creation'),
            actions: <Widget>[
              PopupMenuButton<CreationSortOption>(
                tooltip: 'Sort',
                icon: const Icon(Icons.sort_rounded),
                initialValue: _sortOption,
                color: context.panelBackground,
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
                        style: TextStyle(color: context.primaryText),
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
            color: context.selectedAccent,
            backgroundColor: context.panelBackground,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: <Widget>[
                Text(
                  'Files you created inside PDF Studio',
                  style: TextStyle(
                    color: context.secondaryText,
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
                      final activeColor = filter == CreationFilter.all
                          ? context.primaryAccent
                          : AppFile.getColorForLabel('pdf');
                      return _CreationChip(
                        label: filter.label,
                        selected: filter == _filter,
                        activeColor: activeColor,
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

    if (!context.mounted) {
      return;
    }
    Navigator.of(context).push(
      InstantPageRoute<void>(
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
      text: 'Shared from PDF Studio',
      subject: file.name,
    );
  }

  Future<void> _saveFile(
    BuildContext context,
    AppController controller,
    AppFile file,
  ) async {
    try {
      final savedPath = await controller.fileService.saveToPdfStudioFolder(
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
      color: context.panelBackground,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.borderColor),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: file.assetIcon != null
                    ? Center(
                        child: Image.asset(
                          file.assetIcon!,
                          width: 40,
                          height: 40,
                          fit: BoxFit.contain,
                        ),
                      )
                    : Icon(
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
                      style: TextStyle(
                        color: context.primaryText,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$categoryLabel  •  ${formatFileSize(file.size)}  •  ${formatDate(file.modifiedAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.secondaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              StandardFileActionMenu(
                file: file,
                onOpen: onTap,
                onSave: onSave,
                onChanged: onFavoriteToggle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}



class _EmptyCreationsCard extends StatelessWidget {
  const _EmptyCreationsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.panelBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.folder_copy_rounded, color: context.secondaryText, size: 34),
          const SizedBox(height: 10),
          Text(
            'No creations found yet.',
            style: TextStyle(
              color: context.primaryText,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Merged PDFs, compressed files, scans, and image PDFs will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.secondaryText,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
