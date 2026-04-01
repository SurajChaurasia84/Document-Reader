import 'package:flutter/material.dart';

import '../models/tool_action.dart';
import '../utils/theme_utils.dart';

class ToolTile extends StatelessWidget {
  const ToolTile({super.key, required this.tool, required this.onTap});

  final ToolAction tool;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[context.toolbarBlueStart, context.toolbarBlueEnd],
            ),
            border: Border.all(color: context.borderColor),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: (context.isDarkMode
                        ? const Color(0xFF2D66FF)
                        : const Color(0xFF7AA2F7))
                    .withValues(alpha: 0.16),
                blurRadius: 14,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    IconData(tool.icon, fontFamily: 'MaterialIcons'),
                    color: context.primaryText,
                    size: 24,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tool.title,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.primaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
