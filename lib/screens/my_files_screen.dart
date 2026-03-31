import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/app_file.dart';
import '../services/app_controller.dart';
import '../utils/formatters.dart';
import 'document_viewer_screen.dart';
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
  image('Image'),
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
  MyFilesSource _source = MyFilesSource.internal;
  MyFilesFilter _filter = MyFilesFilter.all;
  MyFilesSortOption _sort = MyFilesSortOption.dateModified;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final sourceFiles = _filesForSource(controller);
    final visibleFiles = _sortFiles(_applyFilter(sourceFiles));

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.refreshAll,
          color: const Color(0xFFF3B63F),
          backgroundColor: const Color(0xFF181C2B),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: <Widget>[
              _HeaderRow(
                onSearchTap: () => _showHint(context, 'Search will be added next.'),
                onViewTap: () => _showHint(context, 'Grid view will be added next.'),
              ),
              const SizedBox(height: 4),
              const Text(
                'All your documents in one place',
                style: TextStyle(
                  color: Color(0xFF767C98),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 18),
              _SourceTabs(
                current: _source,
                onChanged: (value) {
                  if (value == MyFilesSource.sdCard) {
                    _showHint(
                      context,
                      'SD Card browsing is not available in this MVP.',
                    );
                    return;
                  }
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
                    style: const TextStyle(
                      color: Color(0xFF767C98),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _ImportButton(onTap: () => _showImportSheet(context, controller)),
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
                    return _FilterChipButton(
                      label: filter.label,
                      selected: selected,
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
              if (visibleFiles.isEmpty)
                const _EmptyStateCard()
              else
                ...visibleFiles.map(
                  (file) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _MyFileCard(
                      file: file,
                      onTap: () async {
                        await controller.openFile(file);
                        if (!context.mounted) {
                          return;
                        }
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => DocumentViewerScreen(file: file),
                          ),
                        );
                      },
                      onFavoriteTap: () => controller.toggleFavorite(file),
                    ),
                  ),
                ),
            ],
          ),
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
        return const <AppFile>[];
    }
  }

  List<AppFile> _applyFilter(List<AppFile> files) {
    switch (_filter) {
      case MyFilesFilter.all:
        return List<AppFile>.from(files);
      case MyFilesFilter.pdf:
        return files.where((file) => file.extension == 'pdf').toList();
      case MyFilesFilter.word:
        return files.where((file) => file.extension == 'docx').toList();
      case MyFilesFilter.excel:
        return files.where((file) => file.extension == 'xlsx').toList();
      case MyFilesFilter.ppt:
        return files.where((file) => file.extension == 'pptx').toList();
      case MyFilesFilter.image:
        return files.where((file) => file.isImage).toList();
      case MyFilesFilter.text:
        return files.where((file) => file.extension == 'txt').toList();
    }
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
            _showHint(
              context,
              'Photo Library import will be added with image selection flow.',
            );
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
}

class _ImportButton extends StatelessWidget {
  const _ImportButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1E1A35),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF322C58)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.add_rounded,
                size: 16,
                color: Color(0xFFA7A2FF),
              ),
              SizedBox(width: 4),
              Text(
                'Import',
                style: TextStyle(
                  color: Color(0xFFA7A2FF),
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
  const _HeaderRow({required this.onSearchTap, required this.onViewTap});

  final VoidCallback onSearchTap;
  final VoidCallback onViewTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const <Widget>[
              Text(
                'My Files',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        _HeaderActionButton(icon: Icons.search_rounded, onTap: onSearchTap),
        const SizedBox(width: 10),
        _HeaderActionButton(icon: Icons.grid_view_rounded, onTap: onViewTap),
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
      color: const Color(0xFF181C2B),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: const Color(0xFFB7BED8), size: 20),
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
        color: const Color(0xFF111423),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E2135)),
      ),
      child: Row(
        children: MyFilesSource.values.map((source) {
          final selected = source == current;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Material(
                color: selected ? const Color(0xFF171935) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => onChanged(source),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: selected
                          ? Border.all(color: const Color(0xFF5147E5))
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        source.label,
                        style: TextStyle(
                          color: selected
                              ? const Color(0xFFA7A2FF)
                              : const Color(0xFF717694),
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
      color: const Color(0xFF181C2B),
      surfaceTintColor: Colors.transparent,
      onSelected: onSelected,
      itemBuilder: (context) {
        return MyFilesSortOption.values.map((option) {
          return PopupMenuItem<MyFilesSortOption>(
            value: option,
            child: Text(
              option.label,
              style: const TextStyle(color: Colors.white),
            ),
          );
        }).toList();
      },
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF111423),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1E2135)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.filter_list_rounded,
              size: 16,
              color: Color(0xFF8D93AF),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF8D93AF),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: Color(0xFF8D93AF),
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
    final accent = _accentForFile(file);
    return Material(
      color: const Color(0xFF121524),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withValues(alpha: 0.22)),
                ),
                child: Icon(_iconForFile(file), color: accent, size: 22),
              ),
              const SizedBox(width: 14),
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
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          _MyFileMetaPart(
                            futureLabel: _FilePageCountLabel.labelFor(file),
                            fallbackLabel: _FilePageCountLabel.fallbackFor(file),
                            style: TextStyle(
                              color: accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            formatFileSize(file.size),
                            style: const TextStyle(
                              color: Color(0xFF727894),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          formatDate(file.modifiedAt),
                          style: const TextStyle(
                            color: Color(0xFF727894),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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
                      ? const Color(0xFFFFA73A)
                      : const Color(0xFF747A97),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _accentForFile(AppFile file) {
    switch (file.extension) {
      case 'pdf':
        return const Color(0xFFD14B40);
      case 'docx':
        return const Color(0xFF4B79F6);
      case 'xlsx':
        return const Color(0xFF27B36A);
      case 'pptx':
        return const Color(0xFFFF9F2F);
      case 'txt':
        return const Color(0xFF7C86A9);
      default:
        return const Color(0xFF5C79FF);
    }
  }

  static IconData _iconForFile(AppFile file) {
    switch (file.extension) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'docx':
        return Icons.description_rounded;
      case 'xlsx':
        return Icons.table_chart_rounded;
      case 'pptx':
        return Icons.slideshow_rounded;
      case 'txt':
        return Icons.article_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }
}

class _MyFileMetaPart extends StatelessWidget {
  const _MyFileMetaPart({
    required this.futureLabel,
    required this.fallbackLabel,
    required this.style,
  });

  final Future<String> futureLabel;
  final String fallbackLabel;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: futureLabel,
      builder: (context, snapshot) {
        return Text(snapshot.data ?? fallbackLabel, style: style);
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
    if (file.isPdf) {
      try {
        final bytes = await File(file.path).readAsBytes();
        final document = PdfDocument(inputBytes: bytes);
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
        color: const Color(0xFF121524),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Text(
        'No files found for this location and filter.',
        style: TextStyle(
          color: Color(0xFF8A90AA),
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
        decoration: const BoxDecoration(
          color: Color(0xFF151733),
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
                color: const Color(0xFF595D78),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 18),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Import Files',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Choose how to add files to Doc Reader',
                style: TextStyle(
                  color: Color(0xFF8A90AA),
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
            _ImportActionTile(
              icon: Icons.cloud_rounded,
              color: const Color(0xFF3B82F6),
              title: 'Google Drive',
              subtitle: 'Connect cloud storage',
              trailing: const _ProBadge(),
              onTap: onGoogleDrive,
            ),
            _ImportActionTile(
              icon: Icons.cloud_queue_rounded,
              color: const Color(0xFF2563EB),
              title: 'Dropbox',
              subtitle: 'Connect cloud storage',
              trailing: const _ProBadge(),
              onTap: onDropbox,
            ),
            _ImportActionTile(
              icon: Icons.link_rounded,
              color: const Color(0xFF4062D8),
              title: 'Import via URL',
              subtitle: 'Paste a direct file link',
              onTap: onImportUrl,
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
    this.trailing,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFF8A90AA),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...<Widget>[
                  trailing!,
                  const SizedBox(width: 8),
                ],
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF8A90AA),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProBadge extends StatelessWidget {
  const _ProBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF2C1A0A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFA73A)),
      ),
      child: const Text(
        'PRO',
        style: TextStyle(
          color: Color(0xFFFFA73A),
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
