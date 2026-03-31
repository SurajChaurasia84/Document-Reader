import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_file.dart';
import '../services/app_controller.dart';
import 'category_files_screen.dart';
import 'document_viewer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _query = '';

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
        icon: Icons.picture_as_pdf_rounded,
        color: const Color(0xFFD93025),
      ),
      _HomeCategory(
        title: 'Word files',
        count: allFiles.where((file) => file.extension == 'docx').length,
        files: allFiles.where((file) => file.extension == 'docx').toList(),
        icon: Icons.description_rounded,
        color: const Color(0xFF2F6FD6),
      ),
      _HomeCategory(
        title: 'Excel files',
        count: allFiles.where((file) => file.extension == 'xlsx').length,
        files: allFiles.where((file) => file.extension == 'xlsx').toList(),
        icon: Icons.table_chart_rounded,
        color: const Color(0xFF16A34A),
      ),
      _HomeCategory(
        title: 'PPT files',
        count: allFiles.where((file) => file.extension == 'pptx').length,
        files: allFiles.where((file) => file.extension == 'pptx').toList(),
        icon: Icons.slideshow_rounded,
        color: const Color(0xFFE9742B),
      ),
      _HomeCategory(
        title: 'TXT files',
        count: allFiles.where((file) => file.extension == 'txt').length,
        files: allFiles.where((file) => file.extension == 'txt').toList(),
        icon: Icons.article_rounded,
        color: const Color(0xFF586274),
      ),
      _HomeCategory(
        title: 'Archive files',
        count: controller.internalFiles.length,
        files: controller.internalFiles,
        icon: Icons.inventory_2_rounded,
        color: const Color(0xFFB1B7C3),
      ),
    ];

    final places = <_PlaceAction>[
      _PlaceAction(
        title: 'Folder files',
        icon: Icons.folder_open_rounded,
        color: const Color(0xFFF3B63F),
        onTap: () async {
          final file = await controller.pickDocument();
          if (file != null && context.mounted) {
            _openViewer(context, file);
          }
        },
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
        title: 'Favourites',
        icon: Icons.star_rounded,
        color: const Color(0xFF705AC7),
        onTap: () {
          setState(() {
            _query = '';
          });
        },
      ),
      _PlaceAction(
        title: 'My Creation',
        icon: Icons.edit_note_rounded,
        color: const Color(0xFFE15A3B),
        onTap: () {
          controller.updateNavigation(1);
        },
      ),
    ];

    return RefreshIndicator(
      onRefresh: controller.refreshAll,
      color: const Color(0xFFF3B63F),
      backgroundColor: const Color(0xFF1E232A),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 120),
        children: <Widget>[
          _HomeHeader(
            onSettingsTap: () => controller.updateNavigation(3),
            onMoreTap: () => controller.refreshAll(),
          ),
          const SizedBox(height: 16),
          _SearchField(
            query: _query,
            onChanged: (value) {
              setState(() {
                _query = value.trim().toLowerCase();
              });
            },
          ),
          const SizedBox(height: 18),
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
                    onTap: () => _openCategory(context, categories[index]),
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
              mainAxisExtent: MediaQuery.of(context).size.width < 360 ? 78 : 72,
            ),
            itemBuilder: (context, index) {
              return _PlaceCard(action: places[index]);
            },
          ),
          const SizedBox(height: 18),
          _SectionLabel(
            title: _query.isEmpty ? 'Recent files' : 'Search results',
            trailing: '${filteredFiles.length} files',
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
                    child: _RecentFileCard(
                      file: file,
                      onTap: () => _openViewer(context, file),
                      onFavoriteTap: () => controller.toggleFavorite(file),
                    ),
                  ),
                ),
          if (controller.statusMessage != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              controller.statusMessage!,
              style: const TextStyle(
                color: Color(0xFFF3B63F),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
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
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => DocumentViewerScreen(file: file)),
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
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.onSettingsTap, required this.onMoreTap});

  final VoidCallback onSettingsTap;
  final VoidCallback onMoreTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            'Doc Reader',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        _HeaderIconButton(
          icon: Icons.settings_outlined,
          iconColor: Colors.white70,
          onTap: onSettingsTap,
        ),
        const SizedBox(width: 8),
        _HeaderIconButton(
          icon: Icons.more_vert_rounded,
          iconColor: Colors.white70,
          onTap: onMoreTap,
        ),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 36,
        height: 36,
        child: Icon(icon, color: iconColor, size: 22),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.query, required this.onChanged});

  final String query;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF22272E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search',
          hintStyle: const TextStyle(color: Color(0xFF96A0AE)),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF96A0AE),
          ),
          suffixIcon: query.isEmpty
              ? null
              : IconButton(
                  onPressed: () => onChanged(''),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF96A0AE),
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
  const _SectionLabel({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: const TextStyle(
              color: Color(0xFF96A0AE),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
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
      color: const Color(0xFF1E232A),
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
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: category.color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(category.icon, color: Colors.white, size: 20),
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${category.count} files',
                      style: const TextStyle(
                        color: Color(0xFF96A0AE),
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
      color: const Color(0xFF1E232A),
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
                  style: const TextStyle(
                    color: Colors.white,
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

class _RecentFileCard extends StatelessWidget {
  const _RecentFileCard({
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
      color: const Color(0xFF1E232A),
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
                  color: _fileColor(file.extension),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      file.path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF96A0AE),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onFavoriteTap,
                icon: Icon(
                  file.isFavorite
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: file.isFavorite
                      ? const Color(0xFFF3B63F)
                      : const Color(0xFF96A0AE),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _fileColor(String extension) {
    switch (extension) {
      case 'pdf':
        return const Color(0xFFD93025);
      case 'docx':
        return const Color(0xFF2F6FD6);
      case 'xlsx':
        return const Color(0xFF16A34A);
      case 'pptx':
        return const Color(0xFFE9742B);
      case 'txt':
        return const Color(0xFF586274);
      default:
        return const Color(0xFF6B7280);
    }
  }
}

class _EmptyFilesCard extends StatelessWidget {
  const _EmptyFilesCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E232A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        'No files found. Open a folder file or pull documents into the app to get started.',
        style: TextStyle(color: Color(0xFF96A0AE), fontSize: 14, height: 1.4),
      ),
    );
  }
}

class _HomeCategory {
  const _HomeCategory({
    required this.title,
    required this.count,
    required this.files,
    required this.icon,
    required this.color,
  });

  final String title;
  final int count;
  final List<AppFile> files;
  final IconData icon;
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
