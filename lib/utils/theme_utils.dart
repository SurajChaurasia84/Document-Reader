import 'package:flutter/material.dart';

extension ThemeSurfaceX on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  Color get appBackground =>
      isDarkMode ? const Color(0xFF0A0E1A) : const Color(0xFFF4F7FB);

  Color get panelBackground =>
      isDarkMode ? const Color(0xFF1E232A) : const Color(0xFFFFFFFF);

  Color get elevatedPanel =>
      isDarkMode ? const Color(0xFF131726) : const Color(0xFFFFFFFF);

  Color get softPanel =>
      isDarkMode ? const Color(0xFF181C2B) : const Color(0xFFE9EEF8);

  Color get searchBackground =>
      isDarkMode ? const Color(0xFF22272E) : const Color(0xFFE9EEF8);

  Color get borderColor =>
      isDarkMode
          ? Colors.white.withValues(alpha: 0.10)
          : const Color(0xFFD7E0EE);

  Color get primaryText =>
      isDarkMode ? Colors.white : const Color(0xFF111827);

  Color get secondaryText =>
      isDarkMode ? const Color(0xFF96A0AE) : const Color(0xFF607089);

  Color get tertiaryText =>
      isDarkMode ? const Color(0xFFB9C9F2) : const Color(0xFF6B7C96);

  Color get iconMuted =>
      isDarkMode ? Colors.white70 : const Color(0xFF5E6B80);

  Color get overlayBackground =>
      isDarkMode
          ? Colors.black.withValues(alpha: 0.58)
          : Colors.white.withValues(alpha: 0.92);

  Color get selectedAccent => const Color(0xFFFFB020);

  Color get toolbarBlueStart =>
      isDarkMode ? const Color(0xFF203D78) : const Color(0xFFDDE8FF);

  Color get toolbarBlueEnd =>
      isDarkMode ? const Color(0xFF152C58) : const Color(0xFFC9DAFF);
}
