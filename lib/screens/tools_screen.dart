import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/tool_action.dart';
import '../services/app_controller.dart';
import '../utils/constants.dart';
import '../widgets/fixed_top_header.dart';
import '../widgets/tool_tile.dart';

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  String _query = '';

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
        const FixedTopHeader(title: 'All Tools'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 140),
            children: <Widget>[
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2B51),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      _query = value.trim();
                    });
                  },
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Search tools...',
                    hintStyle: TextStyle(color: Color(0xFF8FA5D6)),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: Color(0xFF8FA5D6),
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 18),
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
                      mainAxisExtent: 104,
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
              ),
              if (controller.statusMessage != null) ...<Widget>[
                const SizedBox(height: 16),
                Text(
                  controller.statusMessage!,
                  style: const TextStyle(
                    color: Color(0xFFB9C9F2),
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
        await controller.mergePdfs();
        break;
      case 'split_pdf':
        await controller.splitPdf();
        break;
      case 'image_to_pdf':
        await controller.imageToPdf();
        break;
      case 'pdf_to_image':
        await controller.pdfToImages();
        break;
      case 'compress_pdf':
        await controller.compressPdf();
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
