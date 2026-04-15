import 'package:flutter/material.dart';

import '../models/tool_action.dart';
import '../utils/theme_utils.dart';

class ToolTile extends StatelessWidget {
  const ToolTile({super.key, required this.tool, required this.onTap});

  final ToolAction tool;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: tool.color.withValues(alpha: isDark ? 0.08 : 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: tool.color.withValues(alpha: isDark ? 0.25 : 0.15),
              width: 1.2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tool.color.withValues(alpha: isDark ? 0.18 : 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  tool.icon,
                  color: isDark ? tool.color.withValues(alpha: 0.9) : tool.color,
                  size: 24,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  tool.title,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.primaryText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    letterSpacing: -0.2,
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
