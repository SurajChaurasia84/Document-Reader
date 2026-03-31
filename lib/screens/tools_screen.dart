import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/tool_action.dart';
import '../services/app_controller.dart';
import '../utils/constants.dart';
import '../widgets/tool_tile.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final tools = <ToolAction>[...coreTools, ...premiumTools];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      children: <Widget>[
        Text('PDF Tools', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'Fast offline utilities for building, exporting, and upgrading documents.',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth < 420 ? 1 : 2;
            return GridView.builder(
              itemCount: tools.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                mainAxisExtent: 190,
              ),
              itemBuilder: (context, index) {
                final tool = tools[index];
                return TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.92, end: 1),
                  duration: Duration(milliseconds: 220 + (index * 35)),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Transform.scale(scale: value, child: child);
                  },
                  child: ToolTile(
                    tool: tool,
                    onTap: () => _handleToolTap(context, controller, tool),
                  ),
                );
              },
            );
          },
        ),
        if (controller.statusMessage != null) ...<Widget>[
          const SizedBox(height: 20),
          Text(
            controller.statusMessage!,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
        ],
      ],
    );
  }

  Future<void> _handleToolTap(
    BuildContext context,
    AppController controller,
    ToolAction tool,
  ) async {
    if (tool.isPremium && !controller.isPremium) {
      _showSnack(
        context,
        '${tool.title} is locked. Upgrade to Premium to unlock it.',
      );
      return;
    }

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
      default:
        controller.setStatus(
          '${tool.title} is available in the premium experience.',
        );
        break;
    }

    if (context.mounted && controller.statusMessage != null) {
      _showSnack(context, controller.statusMessage!);
    }
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
