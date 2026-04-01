import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color background = Color(0xFF0A0E1A);
  static const Color surface = Color(0xFF111827);
  static const Color cyan = Color(0xFF00E5FF);
  static const Color purple = Color(0xFFBB86FC);
  static const Color pink = Color(0xFFFF4081);
  static const Color lightBackground = Color(0xFFF4F7FB);
  static const Color lightSurface = Color(0xFFFFFFFF);

  static ThemeData get darkTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: cyan,
      brightness: Brightness.dark,
      primary: cyan,
      secondary: purple,
      tertiary: pink,
      surface: surface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: _FastFadePageTransitionsBuilder(),
          TargetPlatform.iOS: _FastFadePageTransitionsBuilder(),
          TargetPlatform.macOS: _FastFadePageTransitionsBuilder(),
          TargetPlatform.windows: _FastFadePageTransitionsBuilder(),
          TargetPlatform.linux: _FastFadePageTransitionsBuilder(),
        },
      ),
      textTheme: GoogleFonts.spaceGroteskTextTheme(
        Typography.whiteMountainView,
      ).apply(bodyColor: Colors.white, displayColor: Colors.white),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: background,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: GoogleFonts.spaceGrotesk(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 22,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface.withValues(alpha: 0.65),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surface.withValues(alpha: 0.92),
        behavior: SnackBarBehavior.floating,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: cyan,
        foregroundColor: Colors.black,
      ),
    );
  }

  static ThemeData get lightTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1D4ED8),
      brightness: Brightness.light,
      primary: const Color(0xFF1D4ED8),
      secondary: const Color(0xFF7C3AED),
      tertiary: const Color(0xFFE11D48),
      surface: lightSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: lightBackground,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: _FastFadePageTransitionsBuilder(),
          TargetPlatform.iOS: _FastFadePageTransitionsBuilder(),
          TargetPlatform.macOS: _FastFadePageTransitionsBuilder(),
          TargetPlatform.windows: _FastFadePageTransitionsBuilder(),
          TargetPlatform.linux: _FastFadePageTransitionsBuilder(),
        },
      ),
      textTheme: GoogleFonts.spaceGroteskTextTheme(
        Typography.blackMountainView,
      ).apply(bodyColor: const Color(0xFF111827), displayColor: const Color(0xFF111827)),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: lightBackground,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: GoogleFonts.spaceGrotesk(
          color: const Color(0xFF111827),
          fontWeight: FontWeight.w700,
          fontSize: 22,
        ),
      ),
      cardTheme: CardThemeData(
        color: lightSurface.withValues(alpha: 0.94),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF111827),
        behavior: SnackBarBehavior.floating,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF1D4ED8),
        foregroundColor: Colors.white,
      ),
    );
  }
}

SystemUiOverlayStyle overlayStyleForTheme(ThemeData theme) {
  final isDark = theme.brightness == Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: theme.scaffoldBackgroundColor,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness:
        isDark ? Brightness.light : Brightness.dark,
  );
}

class _FastFadePageTransitionsBuilder extends PageTransitionsBuilder {
  const _FastFadePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return FadeTransition(
      opacity: Tween<double>(begin: 0.92, end: 1).animate(curvedAnimation),
      child: child,
    );
  }
}
