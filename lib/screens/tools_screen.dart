import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_file.dart';
import '../models/tool_action.dart';
import '../services/app_controller.dart';
import '../utils/constants.dart';
import '../utils/theme_utils.dart';
import '../widgets/fixed_top_header.dart';
import '../widgets/tool_tile.dart';
import 'compress_pdf_screen.dart';
import 'edit_pdf_screen.dart';
import 'add_page_numbers_screen.dart';
import 'image_to_pdf_screen.dart';
import 'merge_pdf_screen.dart';
import 'protect_pdf_screen.dart';
import 'protected_pdf_picker_screen.dart';
import 'scanner_screen.dart';
import 'sign_pdf_screen.dart';
import 'split_pdf_screen.dart';
import 'unlock_pdf_screen.dart';
import 'word_to_pdf_screen.dart';

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _query = '';
  bool _isGridView = true;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final tools = <ToolAction>[...coreTools, ...advancedTools];
    final filteredTools = tools.where((tool) {
      if (_query.isEmpty) {
        return true;
      }
      final q = _query.toLowerCase();
      return tool.title.toLowerCase().contains(q) ||
          tool.description.toLowerCase().contains(q);
    }).toList();

    return Column(
      children: <Widget>[
        FixedTopHeader(
          title: 'All Tools',
          trailing: IconButton(
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
            icon: Icon(
              _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
              color: context.iconMuted,
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 140),
            children: <Widget>[
              Container(
                decoration: BoxDecoration(
                  color: context.searchBackground,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.borderColor),
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: (value) {
                    setState(() {
                      _query = value.trim();
                    });
                  },
                  style: TextStyle(color: context.primaryText),
                  decoration: InputDecoration(
                    hintText: 'Search tools...',
                    hintStyle: TextStyle(color: context.secondaryText),
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
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (_isGridView)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth < 300 ? 2 : 3;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredTools.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        mainAxisExtent: 110,
                      ),
                      itemBuilder: (context, index) {
                        final tool = filteredTools[index];
                        return ToolTile(
                          tool: tool,
                          onTap: () => _handleToolTap(context, controller, tool),
                        );
                      },
                    );
                  },
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredTools.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final tool = filteredTools[index];
                    return _ToolListTile(
                      tool: tool,
                      onTap: () => _handleToolTap(context, controller, tool),
                    );
                  },
                ),
              if (controller.statusMessage != null) ...<Widget>[
                const SizedBox(height: 16),
                Text(
                  controller.statusMessage!,
                  style: TextStyle(
                    color: context.secondaryText,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleToolTap(
    BuildContext context,
    AppController controller,
    ToolAction tool,
  ) async {
    switch (tool.id) {
      case 'merge_pdf':
        final files = await controller.fileService.pickPdfFiles(allowMultiple: true);
        if (files.length < 2) {
          controller.setStatus('Pick at least two PDF files to merge.');
          break;
        }
        if (!context.mounted) {
          return;
        }
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MergePdfScreen(initialPaths: files),
          ),
        );
        break;
      case 'split_pdf':
        final files = await controller.fileService.pickPdfFiles(allowMultiple: false);
        if (files.isEmpty) {
          controller.setStatus('Pick a PDF to split.');
          break;
        }
        if (!context.mounted) {
          return;
        }
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SplitPdfScreen(inputPath: files.first),
          ),
        );
        break;
      case 'word_to_pdf':
        final files = await controller.fileService.pickWordFiles(
          allowMultiple: false,
        );
        if (files.isEmpty) {
          controller.setStatus('Pick a Word document to convert.');
          break;
        }
        if (!context.mounted) {
          return;
        }
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => WordToPdfScreen(inputPath: files.first),
          ),
        );
        break;
      case 'image_to_pdf':
        final files = await controller.fileService.pickPhotoLibraryImages(
          allowMultiple: true,
        );
        if (files.isEmpty) {
          controller.setStatus('Pick one or more images to create a PDF.');
          break;
        }
        if (!context.mounted) {
          return;
        }
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ImageToPdfScreen(initialPaths: files),
          ),
        );
        break;
      case 'pdf_to_image':
        await controller.pdfToImages();
        break;
      case 'compress_pdf':
        final files = await controller.fileService.pickPdfFiles(allowMultiple: false);
        if (files.isEmpty) {
          controller.setStatus('Pick a PDF to compress.');
          break;
        }
        if (!context.mounted) {
          return;
        }
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CompressPdfScreen(inputPath: files.first),
          ),
        );
        break;
      case 'protect_pdf':
        final files = await controller.fileService.pickPdfFiles(allowMultiple: false);
        if (files.isEmpty) {
          controller.setStatus('Pick a PDF to protect.');
          break;
        }
        if (!context.mounted) {
          return;
        }
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ProtectPdfScreen(inputPath: files.first),
          ),
        );
        break;
      case 'add_page_numbers':
        final files = await controller.fileService.pickPdfFiles(allowMultiple: false);
        if (files.isEmpty) {
          controller.setStatus('Pick a PDF to add page numbers.');
          break;
        }
        if (!context.mounted) {
          return;
        }
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AddPageNumbersScreen(inputPath: files.first),
          ),
        );
        break;
      case 'scan_to_pdf':
        if (!context.mounted) {
          return;
        }
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ScannerScreen()),
        );
        return;
      case 'unlock_pdf':
        final protectedFile = await Navigator.of(context).push<AppFile>(
          MaterialPageRoute<AppFile>(
            builder: (_) => const ProtectedPdfPickerScreen(),
          ),
        );
        if (protectedFile == null) {
          break;
        }
        if (!context.mounted) {
          return;
        }
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => UnlockPdfScreen(file: protectedFile),
          ),
        );
        break;
      case 'sign_pdf':
        final files = await controller.fileService.pickPdfFiles(allowMultiple: false);
        if (files.isEmpty) {
          controller.setStatus('Pick a PDF to sign.');
          break;
        }
        if (!context.mounted) {
          return;
        }
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SignPdfScreen(inputPath: files.first),
          ),
        );
        break;
      case 'edit_pdf':
        final files = await controller.fileService.pickPdfFiles(allowMultiple: false);
        if (files.isEmpty) {
          controller.setStatus('Pick a PDF to edit.');
          break;
        }
        if (!context.mounted) {
          return;
        }
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => EditPdfScreen(inputPath: files.first),
          ),
        );
        break;
      case 'ocr_pdf':
        controller.setStatus('Open a file to run OCR from the viewer screen.');
        break;
      case 'ai_summarizer':
        controller.setStatus(
          'Open a file to summarize it from the viewer screen.',
        );
        break;
      case 'translate':
        controller.setStatus('Open a file to translate it from the viewer.');
        break;
      default:
        controller.setStatus('${tool.title} is coming in a later update.');
        break;
    }

    if (context.mounted && controller.statusMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(controller.statusMessage!)));
    }
  }
}

class _ToolListTile extends StatelessWidget {
  const _ToolListTile({
    required this.tool,
    required this.onTap,
  });

  final ToolAction tool;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.toolbarBlueEnd,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.borderColor),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.isDarkMode
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFE9EEF8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  children: <Widget>[
                    Center(
                      child: Icon(
                        tool.icon,
                        color: context.primaryText,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      tool.title,
                      style: TextStyle(
                        color: context.primaryText,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tool.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.tertiaryText,
                        fontSize: 12,
                        height: 1.35,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: context.secondaryText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
