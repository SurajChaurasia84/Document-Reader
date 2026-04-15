import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/app_file.dart';
import '../services/app_controller.dart';
import '../utils/instant_page_route.dart';
import '../utils/theme_utils.dart';
import '../widgets/fixed_top_header.dart';
import '../widgets/recent_file_card.dart';
import 'category_files_screen.dart';
import 'document_viewer_screen.dart';
import 'my_creations_screen.dart';
import 'my_files_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _searchCollapsed = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final allFiles = _dedupeFiles(<AppFile>[
      ...controller.recentFiles,
      ...controller.favoriteFiles,
      ...controller.internalFiles,
      ...controller.downloadFiles,
    ]);
    final filteredFiles = _filterFiles(allFiles, _query);

    final categories = <_HomeCategory>[
      _HomeCategory(
        title: 'All files',
        count: allFiles.length,
        files: allFiles,
        icon: Icons.grid_view_rounded,
        color: const Color(0xFF2D87F3),
      ),
      _HomeCategory(
        title: 'PDF files',
        count: allFiles.where((file) => file.extension == 'pdf').length,
        files: allFiles.where((file) => file.extension == 'pdf').toList(),
        assetIcon: 'assets/pdf.png',
        color: const Color(0xFFFFEAEA),
      ),
      _HomeCategory(
        title: 'Word files',
        count: allFiles.where((file) => file.extension == 'docx').length,
        files: allFiles.where((file) => file.extension == 'docx').toList(),
        assetIcon: 'assets/doc.png',
        color: const Color(0xFFE8F0FF),
      ),
      _HomeCategory(
        title: 'Excel files',
        count: allFiles.where((file) => file.extension == 'xlsx').length,
        files: allFiles.where((file) => file.extension == 'xlsx').toList(),
        assetIcon: 'assets/xls.png',
        color: const Color(0xFFE6F4EA),
      ),
      _HomeCategory(
        title: 'PPT files',
        count: allFiles.where((file) => file.extension == 'pptx').length,
        files: allFiles.where((file) => file.extension == 'pptx').toList(),
        assetIcon: 'assets/ppt.png',
        color: const Color(0xFFFFF4E5),
      ),
      _HomeCategory(
        title: 'TXT files',
        count: allFiles.where((file) => file.extension == 'txt').length,
        files: allFiles.where((file) => file.extension == 'txt').toList(),
        assetIcon: 'assets/txt.png',
        color: const Color(0xFFF1F3F4),
      ),
    ];

    final places = <_PlaceAction>[
      _PlaceAction(
        title: 'Browse files',
        icon: Icons.folder_open_rounded,
        color: const Color(0xFF2F6FD6),
        onTap: () async {
          final file = await controller.pickDocument();
          if (file != null && context.mounted) {
            _openViewer(context, file);
          }
        },
      ),
      _PlaceAction(
        title: 'Favourites',
        icon: Icons.star_rounded,
        color: const Color(0xFF705AC7),
        onTap: () => _openFavorites(context, controller),
      ),
      _PlaceAction(
        title: 'Last Opened',
        icon: Icons.history_rounded,
        color: const Color(0xFF7B6A47),
        onTap: () {
          if (filteredFiles.isNotEmpty) {
            _openViewer(context, filteredFiles.first);
          }
        },
      ),
      _PlaceAction(
        title: 'My Creation',
        icon: Icons.edit_note_rounded,
        color: const Color(0xFFE15A3B),
        onTap: () => _openMyCreationsScreen(context, controller),
      ),
    ];

    return Column(
      children: <Widget>[
        FixedTopHeader(
          title: 'PDF Studio',
          trailing: IgnorePointer(
            ignoring: !_searchCollapsed,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 160),
              opacity: _searchCollapsed ? 1 : 0,
              child: IconButton(
                onPressed: _focusSearch,
                icon: Icon(Icons.search_rounded, color: context.iconMuted),
              ),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: controller.refreshAll,
            color: context.selectedAccent,
            backgroundColor: context.panelBackground,
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 120),
              children: <Widget>[
                _SearchField(
                  query: _query,
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: (value) {
                    setState(() {
                      _query = value.trim().toLowerCase();
                    });
                  },
                ),
                const SizedBox(height: 12),
                _SectionLabel(title: 'Categories'),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final maxWidth = constraints.maxWidth;
                    final crossAxisCount = maxWidth < 280 ? 1 : 2;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: categories.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        mainAxisExtent: maxWidth < 360 ? 78 : 72,
                      ),
                      itemBuilder: (context, index) {
                        return _CategoryCard(
                          category: categories[index],
                          onTap: () =>
                              _openCategory(context, categories[index]),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 18),
                _SectionLabel(title: 'Places'),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: places.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    mainAxisExtent: MediaQuery.of(context).size.width < 360
                        ? 78
                        : 72,
                  ),
                  itemBuilder: (context, index) {
                    return _PlaceCard(action: places[index]);
                  },
                ),
                const SizedBox(height: 18),
                _SectionLabel(
                  title: _query.isEmpty ? 'Recent files' : 'Search results',
                  trailing: _query.isEmpty
                      ? '${filteredFiles.length} files'
                      : null,
                  actionLabel: _query.isEmpty ? 'All files' : null,
                  onActionTap: _query.isEmpty
                      ? () => _openMyFilesScreen(context)
                      : null,
                ),
                const SizedBox(height: 12),
                if (filteredFiles.isEmpty)
                  const _EmptyFilesCard()
                else
                  ...filteredFiles
                      .take(8)
                      .map(
                        (file) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                        child: RecentFileCard(
                            file: file,
                            onTap: () => _openViewer(context, file),
                            onFavorite: () => controller.toggleFavorite(file),
                            onShare: () => _shareFile(context, file),
                            onSave: () => _saveFile(context, controller, file),
                            onDelete: () => _deleteFile(context, controller, file),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<AppFile> _dedupeFiles(List<AppFile> files) {
    final map = <String, AppFile>{};
    for (final file in files) {
      map[file.path] = file;
    }
    final values = map.values.toList()
      ..sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return values;
  }

  List<AppFile> _filterFiles(List<AppFile> files, String query) {
    if (query.isEmpty) {
      return files;
    }
    return files.where((file) {
      final name = file.name.toLowerCase();
      final ext = file.extension.toLowerCase();
      return name.contains(query) || ext.contains(query);
    }).toList();
  }

  void _openViewer(BuildContext context, AppFile file) {
    File(file.path).exists().then((exists) {
      if (!context.mounted) {
        return;
      }
      if (!exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This file is no longer available on your device.'),
          ),
        );
        return;
      }
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => DocumentViewerScreen(file: file)));
    });
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
      final savedPath = await controller.fileService.saveToPdfStudioFolder(file.path);
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
          content: Text('Are you sure you want to delete "${file.name}"?'),
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

    await controller.deleteManagedFile(file);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('File deleted')),
    );
  }

  void _openCategory(BuildContext context, _HomeCategory category) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            CategoryFilesScreen(title: category.title, files: category.files),
      ),
    );
  }

  void _openFavorites(BuildContext context, AppController controller) {
    _clearSearch();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CategoryFilesScreen(
          title: 'Favorites',
          files: controller.favoriteFiles,
        ),
      ),
    );
  }

  void _openMyFilesScreen(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const MyFilesScreen()));
  }

  Future<void> _openMyCreationsScreen(
    BuildContext context,
    AppController controller,
  ) async {
    try {
      final createdFiles = await controller.pdfService.listCreatedFiles(
        favorites: controller.favoriteFiles.map((file) => file.path).toSet(),
      );
      if (!context.mounted) {
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MyCreationsScreen(initialFiles: createdFiles),
        ),
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
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const MyCreationsScreen(),
        ),
      );
    }
  }

  void _handleScroll() {
    final shouldCollapse = _scrollController.offset > 24;
    if (shouldCollapse != _searchCollapsed && mounted) {
      setState(() {
        _searchCollapsed = shouldCollapse;
      });
    }
  }

  void _focusSearch() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
    Future<void>.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _query = '';
    });
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.query,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final String query;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.searchBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        style: TextStyle(color: context.primaryText),
        decoration: InputDecoration(
          hintText: 'Search',
          hintStyle: TextStyle(color: context.secondaryText),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: context.secondaryText,
          ),
          suffixIcon: query.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    controller.clear();
                    focusNode.unfocus();
                    onChanged('');
                  },
                  icon: Icon(
                    Icons.close_rounded,
                    color: context.secondaryText,
                  ),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.title,
    this.trailing,
    this.actionLabel,
    this.onActionTap,
  });

  final String title;
  final String? trailing;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: context.primaryText,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: TextStyle(
              color: context.secondaryText,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        if (actionLabel != null) ...<Widget>[
          if (trailing != null) const SizedBox(width: 12),
          GestureDetector(
            onTap: onActionTap,
            child: Text(
              actionLabel!,
              style: const TextStyle(
                color: Color(0xFF2D87F3),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.onTap});

  final _HomeCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.panelBackground,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: category.assetIcon != null ? Colors.transparent : category.color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: category.assetIcon != null
                    ? Center(
                        child: Image.asset(
                          category.assetIcon!,
                          width: 36,
                          height: 36,
                          fit: BoxFit.contain,
                        ),
                      )
                    : Icon(category.icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      category.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.primaryText,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${category.count} files',
                      style: TextStyle(
                        color: context.secondaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.action});

  final _PlaceAction action;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.panelBackground,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: action.color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(action.icon, color: Colors.white, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  action.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.primaryText,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



class _EmptyFilesCard extends StatelessWidget {
  const _EmptyFilesCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.panelBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        'No files found. Open a folder file or pull documents into the app to get started.',
        style: TextStyle(
          color: context.secondaryText,
          fontSize: 14,
          height: 1.4,
        ),
      ),
    );
  }
}

class _HomeCategory {
  const _HomeCategory({
    required this.title,
    required this.count,
    required this.files,
    this.icon = Icons.insert_drive_file_rounded,
    this.assetIcon,
    required this.color,
  });

  final String title;
  final int count;
  final List<AppFile> files;
  final IconData icon;
  final String? assetIcon;
  final Color color;
}

class _PlaceAction {
  const _PlaceAction({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}
