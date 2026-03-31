import 'package:flutter/material.dart';

import '../models/tool_action.dart';
import 'glass_card.dart';

class ToolTile extends StatelessWidget {
  const ToolTile({super.key, required this.tool, required this.onTap});

  final ToolAction tool;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(IconData(tool.icon, fontFamily: 'MaterialIcons')),
          const SizedBox(height: 20),
          Text(tool.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            tool.description,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
