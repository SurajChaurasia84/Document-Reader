import 'dart:ui';

import 'package:flutter/material.dart';

import '../utils/theme_utils.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Material(
          color: context.isDarkMode
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.white.withValues(alpha: 0.75),
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: context.borderColor),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    context.panelBackground.withValues(alpha: 0.92),
                    context.softPanel.withValues(alpha: 0.72),
                  ],
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: (context.isDarkMode
                            ? const Color(0xFF00E5FF)
                            : const Color(0xFF1D4ED8))
                        .withValues(alpha: 0.08),
                    blurRadius: 18,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
