import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/app_file.dart';
import '../services/app_controller.dart';
import '../utils/formatters.dart';
import '../utils/instant_page_route.dart';
import '../utils/theme_utils.dart';
import 'document_viewer_screen.dart';
import 'photo_preview_screen.dart';
import 'scanner_screen.dart';

enum MyFilesSortOption {
  dateModified('Date Modified'),
  newest('Newest first'),
  oldest('Oldest first'),
  nameAsc('Name A-Z'),
  nameDesc('Name Z-A'),
  sizeLargest('Largest first'),
  sizeSmallest('Smallest first');

  const MyFilesSortOption(this.label);
  final String label;
}

enum MyFilesSource {
  internal('Internal'),
  downloads('Downloads'),
  sdCard('SD Card');

  const MyFilesSource(this.label);
  final String label;
}

enum MyFilesFilter {
  all('All'),
  pdf('PDF'),
  word('Word'),
  excel('Excel'),
  ppt('PPT'),
  text('Text');

  const MyFilesFilter(this.label);
  final String label;
}

class MyFilesScreen extends StatefulWidget {
  const MyFilesScreen({super.key});

  @override
  State<MyFilesScreen> createState() => _MyFilesScreenState();
}

class _MyFilesScreenState extends State<MyFilesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  MyFilesSource _source = MyFilesSource.internal;
  MyFilesFilter _filter = MyFilesFilter.all;
  MyFilesSortOption _sort = MyFilesSortOption.dateModified;
  bool _showSearch = false;
  bool _isGridView = false;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final sourceFiles = _filesForSource(controller);
    final visibleFiles = _sortFiles(_applySearch(_applyFilter(sourceFiles)));

    return Scaffold(
      backgroundColor: context.appBackground,
      body: SafeArea(
        child: Column(
          children: [
            if (controller.isScanning)
              const LinearProgressIndicator(
                minHeight: 1.5,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2D87F3)),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => controller.refreshAll(forceFullScan: true),
                color: context.selectedAccent,
                backgroundColor: context.panelBackground,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _HeaderRow(
                              isGridView: _isGridView,
                              isSearchActive: _showSearch,
                              onSearchTap: _toggleSearch,
                              onViewTap: () {
                                setState(() {
                                  _isGridView = !_isGridView;
                                });
                              },
                            ),
                            if (_showSearch) ...<Widget>[
                              const SizedBox(height: 14),
                              Container(
                                decoration: BoxDecoration(
                                  color: context.searchBackground,
                                  borderRadius: BorderRadius.circular(14),
                                  border:
                                      Border.all(color: context.borderColor),
                                ),
                                child: TextField(
                                  controller: _searchController,
                                  focusNode: _searchFocusNode,
                                  onChanged: (value) {
                                    setState(() {
                                      _query = value.trim().toLowerCase();
                                    });
                                  },
                                  style: TextStyle(color: context.primaryText),
                                  decoration: InputDecoration(
                                    hintText: 'Search files...',
                                    hintStyle: TextStyle(
                                        color: context.secondaryText),
                                    prefixIcon: Icon(
                                      Icons.search_rounded,
                                      color: context.secondaryText,
                                    ),
                                    suffixIcon: _query.isEmpty
                                        ? null
                                        : IconButton(
                                            onPressed: () {
                                              _searchController.clear();
                                              _searchFocusNode.unfocus();
                                              setState(() {
                                                _query = '';
                                              });
                                            },
                                            icon: Icon(
                                              Icons.close_rounded,
                                              color: context.secondaryText,
                                            ),
                                          ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              'All your documents in one place',
                              style: TextStyle(
                                color: context.secondaryText,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 18),
                            _SourceTabs(
                              current: _source,
                              onChanged: (value) {
                                setState(() {
                                  _source = value;
                                });
                              },
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: <Widget>[
                                Text(
                                  '${visibleFiles.length} files',
                                  style: TextStyle(
                                    color: context.secondaryText,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                _ImportButton(
                                    onTap: () =>
                                        _showImportSheet(context, controller)),
                                const Spacer(),
                                _SortButton(
                                  label: _sort.label,
                                  onSelected: (value) {
                                    setState(() {
                                      _sort = value;
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              height: 34,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: MyFilesFilter.values.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  final filter = MyFilesFilter.values[index];
                                  final selected = filter == _filter;
                                  final activeColor = selected
                                      ? AppFile.getColorForLabel(filter.label,
                                          fallback: context.primaryAccent)
                                      : context.selectedAccent;
                                  return _FilterChipButton(
                                    label: filter.label,
                                    selected: selected,
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
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                    if (visibleFiles.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: _EmptyStateCard()),
                      )
                    else if (_isGridView)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            mainAxisExtent: 150,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final file = visibleFiles[index];
                              return _MyFileGridCard(
                                file: file,
                                onTap: () => _openFile(context, file),
                                onFavoriteTap: () =>
                                    controller.toggleFavorite(file),
                              );
                            },
                            childCount: visibleFiles.length,
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final file = visibleFiles[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _MyFileCard(
                                  file: file,
                                  onTap: () => _openFile(context, file),
                                  onFavoriteTap: () =>
                                      controller.toggleFavorite(file),
                                ),
                              );
                            },
                            childCount: visibleFiles.length,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<AppFile> _filesForSource(AppController controller) {
    switch (_source) {
      case MyFilesSource.internal:
        return controller.internalFiles;
      case MyFilesSource.downloads:
        return controller.downloadFiles;
      case MyFilesSource.sdCard:
        return controller.sdCardFiles;
    }
  }

  List<AppFile> _applyFilter(List<AppFile> files) {
    switch (_filter) {
      case MyFilesFilter.all:
        return List<AppFile>.from(files);
      case MyFilesFilter.pdf:
        return files.where((file) => file.extension == 'pdf').toList();
      case MyFilesFilter.word:
        return files
            .where((file) => <String>['doc', 'docx'].contains(file.extension))
            .toList();
      case MyFilesFilter.excel:
        return files
            .where((file) => <String>['xls', 'xlsx'].contains(file.extension))
            .toList();
      case MyFilesFilter.ppt:
        return files
            .where((file) => <String>['ppt', 'pptx'].contains(file.extension))
            .toList();
      case MyFilesFilter.text:
        return files
            .where((file) => <String>['txt', 'csv', 'rtf'].contains(file.extension))
            .toList();
    }
  }

  List<AppFile> _applySearch(List<AppFile> files) {
    if (_query.isEmpty) {
      return files;
    }
    return files.where((file) {
      final name = file.name.toLowerCase();
      final extension = file.extension.toLowerCase();
      final path = file.path.toLowerCase();
      return name.contains(_query) ||
          extension.contains(_query) ||
          path.contains(_query);
    }).toList();
  }

  List<AppFile> _sortFiles(List<AppFile> files) {
    final sorted = List<AppFile>.from(files);
    switch (_sort) {
      case MyFilesSortOption.dateModified:
      case MyFilesSortOption.newest:
        sorted.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
      case MyFilesSortOption.oldest:
        sorted.sort((a, b) => a.modifiedAt.compareTo(b.modifiedAt));
      case MyFilesSortOption.nameAsc:
        sorted.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case MyFilesSortOption.nameDesc:
        sorted.sort(
          (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
        );
      case MyFilesSortOption.sizeLargest:
        sorted.sort((a, b) => b.size.compareTo(a.size));
      case MyFilesSortOption.sizeSmallest:
        sorted.sort((a, b) => a.size.compareTo(b.size));
    }
    return sorted;
  }

  void _showHint(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (!_showSearch) {
        _searchController.clear();
        _searchFocusNode.unfocus();
        _query = '';
      }
    });
    if (_showSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _searchFocusNode.requestFocus();
        }
      });
    }
  }

  Future<void> _openFile(BuildContext context, AppFile file) async {
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
    Navigator.of(
      context,
    ).push(InstantPageRoute<void>(builder: (_) => DocumentViewerScreen(file: file)));
  }

  void _showImportSheet(BuildContext context, AppController controller) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _ImportSheet(
          onBrowseFiles: () async {
            Navigator.of(sheetContext).pop();
            final file = await controller.pickDocument();
            if (file != null && context.mounted) {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DocumentViewerScreen(file: file),
                ),
              );
            }
          },
          onPhotoLibrary: () {
            Navigator.of(sheetContext).pop();
            _openPhotoLibraryPreview(context, controller);
          },
          onScanDocument: () {
            Navigator.of(sheetContext).pop();
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ScannerScreen(),
              ),
            );
          },
          onGoogleDrive: () {
            Navigator.of(sheetContext).pop();
            _showHint(context, 'Google Drive import is planned next.');
          },
          onDropbox: () {
            Navigator.of(sheetContext).pop();
            _showHint(context, 'Dropbox import is planned next.');
          },
          onImportUrl: () {
            Navigator.of(sheetContext).pop();
            _showHint(context, 'Import via URL is planned next.');
          },
        );
      },
    );
  }

  Future<void> _openPhotoLibraryPreview(
    BuildContext context,
    AppController controller,
  ) async {
    try {
      final imagePaths = await controller.fileService.pickPhotoLibraryImages();
      if (!context.mounted || imagePaths.isEmpty) {
        return;
      }

      Navigator.of(context).push(
        InstantPageRoute<void>(
          builder: (_) => PhotoPreviewScreen(imagePaths: imagePaths),
        ),
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
}

class _ImportButton extends StatelessWidget {
  const _ImportButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.softPanel,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.add_rounded,
                size: 16,
                color: context.selectedAccent,
              ),
              SizedBox(width: 4),
              Text(
                'Import',
                style: TextStyle(
                  color: context.selectedAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.onSearchTap,
    required this.onViewTap,
    required this.isGridView,
    required this.isSearchActive,
  });

  final VoidCallback onSearchTap;
  final VoidCallback onViewTap;
  final bool isGridView;
  final bool isSearchActive;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'My Files',
                style: TextStyle(
                  color: context.primaryText,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        _HeaderActionButton(
          icon: isSearchActive ? Icons.close_rounded : Icons.search_rounded,
          onTap: onSearchTap,
        ),
        const SizedBox(width: 10),
        _HeaderActionButton(
          icon: isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
          onTap: onViewTap,
        ),
      ],
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.panelBackground,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: context.iconMuted, size: 20),
        ),
      ),
    );
  }
}

class _SourceTabs extends StatelessWidget {
  const _SourceTabs({required this.current, required this.onChanged});

  final MyFilesSource current;
  final ValueChanged<MyFilesSource> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.softPanel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        children: MyFilesSource.values.map((source) {
          final selected = source == current;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Material(
                color: selected
                    ? context.primaryAccent.withValues(alpha: 0.14)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => onChanged(source),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: selected
                          ? Border.all(color: context.primaryAccent)
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        source.label,
                        style: TextStyle(
                          color: selected
                              ? context.primaryAccent
                              : context.secondaryText,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.label, required this.onSelected});

  final String label;
  final ValueChanged<MyFilesSortOption> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<MyFilesSortOption>(
      tooltip: 'Sort files',
      color: context.panelBackground,
      surfaceTintColor: Colors.transparent,
      onSelected: onSelected,
      itemBuilder: (context) {
        return MyFilesSortOption.values.map((option) {
          return PopupMenuItem<MyFilesSortOption>(
            value: option,
            child: Text(
              option.label,
              style: TextStyle(color: context.primaryText),
            ),
          );
        }).toList();
      },
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: context.softPanel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.filter_list_rounded,
              size: 16,
              color: context.secondaryText,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: context.secondaryText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: context.secondaryText,
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
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

class _MyFileCard extends StatelessWidget {
  const _MyFileCard({
    required this.file,
    required this.onTap,
    required this.onFavoriteTap,
  });

  final AppFile file;
  final VoidCallback onTap;
  final VoidCallback onFavoriteTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.panelBackground,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _fileColor(file),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: file.assetIcon != null
                    ? Image.asset(
                        file.assetIcon!,
                        width: 32,
                        height: 32,
                        fit: BoxFit.contain,
                      )
                    : Text(
                        file.extension.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
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
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _MyFileMetaPart(
                      futureLabel: _FilePageCountLabel.labelFor(file),
                      fallbackLabel: _FilePageCountLabel.fallbackFor(file),
                      size: file.size,
                      modifiedAt: file.modifiedAt,
                      style: TextStyle(
                        color: context.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onFavoriteTap,
                splashRadius: 18,
                icon: Icon(
                  file.isFavorite
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: file.isFavorite
                      ? const Color(0xFFF3B63F)
                      : context.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _fileColor(AppFile file) {
    if (file.assetIcon != null) return Colors.transparent;
    switch (file.extension.toLowerCase()) {
      case 'pdf':
        return const Color(0xFFD93025);
      case 'doc':
      case 'docx':
        return const Color(0xFF2F6FD6);
      case 'xls':
      case 'xlsx':
        return const Color(0xFF16A34A);
      case 'ppt':
      case 'pptx':
        return const Color(0xFFE9742B);
      case 'txt':
      case 'csv':
      case 'rtf':
        return const Color(0xFF586274);
      default:
        return const Color(0xFF6B7280);
    }
  }
}

class _MyFileGridCard extends StatelessWidget {
  const _MyFileGridCard({
    required this.file,
    required this.onTap,
    required this.onFavoriteTap,
  });

  final AppFile file;
  final VoidCallback onTap;
  final VoidCallback onFavoriteTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.panelBackground,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _MyFileCard._fileColor(file),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: file.assetIcon != null
                        ? Image.asset(
                            file.assetIcon!,
                            width: 30,
                            height: 30,
                            fit: BoxFit.contain,
                          )
                        : Text(
                            file.extension.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onFavoriteTap,
                    splashRadius: 18,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      file.isFavorite
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: file.isFavorite
                          ? const Color(0xFFF3B63F)
                          : context.secondaryText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                file.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.primaryText,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              _MyFileMetaPart(
                futureLabel: _FilePageCountLabel.labelFor(file),
                fallbackLabel: _FilePageCountLabel.fallbackFor(file),
                size: file.size,
                modifiedAt: file.modifiedAt,
                style: TextStyle(
                  color: context.secondaryText,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyFileMetaPart extends StatelessWidget {
  const _MyFileMetaPart({
    required this.futureLabel,
    required this.fallbackLabel,
    required this.size,
    required this.modifiedAt,
    required this.style,
  });

  final Future<String> futureLabel;
  final String fallbackLabel;
  final int size;
  final DateTime modifiedAt;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: futureLabel,
      builder: (context, snapshot) {
        return Text(
          '${snapshot.data ?? fallbackLabel}  •  ${formatFileSize(size)}  •  ${formatDate(modifiedAt)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        );
      },
    );
  }
}

class _FilePageCountLabel {
  static final Map<String, Future<String>> _cache = <String, Future<String>>{};

  static Future<String> labelFor(AppFile file) {
    return _cache.putIfAbsent(file.path, () => _load(file));
  }

  static String fallbackFor(AppFile file) {
    if (file.isImage) {
      return '1 page';
    }
    return '-- pages';
  }

  static Future<String> _load(AppFile file) async {
    if (file.isPdf && file.size <= 15 * 1024 * 1024) {
      try {
        final document = PdfDocument(inputBytes: await File(file.path).readAsBytes());
        final count = document.pages.count;
        document.dispose();
        return count == 1 ? '1 page' : '$count pages';
      } catch (_) {
        return fallbackFor(file);
      }
    }

    return fallbackFor(file);
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.panelBackground,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        'No files found for this location and filter.',
        style: TextStyle(
          color: context.secondaryText,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _ImportSheet extends StatelessWidget {
  const _ImportSheet({
    required this.onBrowseFiles,
    required this.onPhotoLibrary,
    required this.onScanDocument,
    required this.onGoogleDrive,
    required this.onDropbox,
    required this.onImportUrl,
  });

  final VoidCallback onBrowseFiles;
  final VoidCallback onPhotoLibrary;
  final VoidCallback onScanDocument;
  final VoidCallback onGoogleDrive;
  final VoidCallback onDropbox;
  final VoidCallback onImportUrl;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: context.panelBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 54,
              height: 4,
              decoration: BoxDecoration(
                color: context.secondaryText.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Import Files',
                style: TextStyle(
                  color: context.primaryText,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Choose how to add files to PDF Studio',
                style: TextStyle(
                  color: context.secondaryText,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 18),
            _ImportActionTile(
              icon: Icons.folder_rounded,
              color: const Color(0xFF5856F5),
              title: 'Browse Files',
              subtitle: 'Access internal storage & downloads',
              onTap: onBrowseFiles,
            ),
            _ImportActionTile(
              icon: Icons.photo_library_rounded,
              color: const Color(0xFF9C4DFF),
              title: 'Photo Library',
              subtitle: 'Import images and convert to PDF',
              onTap: onPhotoLibrary,
            ),
            _ImportActionTile(
              icon: Icons.document_scanner_rounded,
              color: const Color(0xFF16C6C0),
              title: 'Scan Document',
              subtitle: 'Use camera to scan physical docs',
              onTap: onScanDocument,
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportActionTile extends StatelessWidget {
  const _ImportActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            child: Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: TextStyle(
                          color: context.primaryText,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: context.secondaryText,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.secondaryText,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
