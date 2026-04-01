import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_controller.dart';
import '../utils/app_theme.dart';
import '../utils/theme_utils.dart';
import 'home_screen.dart';
import 'my_files_screen.dart';
import 'scanner_screen.dart';
import 'settings_screen.dart';
import 'tools_screen.dart';

class ShellScreen extends StatelessWidget {
  const ShellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final screens = <Widget>[
      const HomeScreen(),
      const ToolsScreen(),
      const MyFilesScreen(),
      const SettingsScreen(),
    ];

    return PopScope(
      canPop: controller.currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && controller.currentIndex != 0) {
          controller.updateNavigation(0);
        }
      },
      child: Scaffold(
        extendBody: true,
        body: SafeArea(
          child: IndexedStack(
            index: controller.currentIndex,
            children: screens,
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ScannerScreen()),
            );
          },
          icon: const Icon(Icons.document_scanner),
          label: const Text('Scan'),
        ),
        bottomNavigationBar: Container(
          color: context.panelBackground,
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
          child: SafeArea(
            top: false,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _BottomTabItem(
                    icon: Icons.home_outlined,
                    selectedIcon: Icons.home_rounded,
                    label: 'Home',
                    selected: controller.currentIndex == 0,
                    onTap: () => controller.updateNavigation(0),
                  ),
                ),
                Expanded(
                  child: _BottomTabItem(
                    icon: Icons.auto_fix_high_outlined,
                    selectedIcon: Icons.auto_fix_high_rounded,
                    label: 'Tools',
                    selected: controller.currentIndex == 1,
                    onTap: () => controller.updateNavigation(1),
                  ),
                ),
                Expanded(
                  child: _BottomTabItem(
                    icon: Icons.folder_outlined,
                    selectedIcon: Icons.folder_rounded,
                    label: 'Files',
                    selected: controller.currentIndex == 2,
                    onTap: () => controller.updateNavigation(2),
                  ),
                ),
                Expanded(
                  child: _BottomTabItem(
                    icon: Icons.settings_outlined,
                    selectedIcon: Icons.settings,
                    label: 'Settings',
                    selected: controller.currentIndex == 3,
                    onTap: () => controller.updateNavigation(3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomTabItem extends StatelessWidget {
  const _BottomTabItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selectedColor = context.isDarkMode
        ? AppTheme.cyan
        : (Theme.of(context).floatingActionButtonTheme.backgroundColor ??
              Theme.of(context).colorScheme.primary);
    final color = selected ? selectedColor : context.iconMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: 28,
              height: 3,
              decoration: BoxDecoration(
                color: selected ? selectedColor : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
                boxShadow: selected
                    ? <BoxShadow>[
                        BoxShadow(
                          color: selectedColor.withValues(
                            alpha: context.isDarkMode ? 0.05 : 0.12,
                          ),
                          blurRadius: 16,
                          spreadRadius: 0,
                        ),
                      ]
                    : const <BoxShadow>[],
              ),
              alignment: Alignment.center,
              child: Icon(
                selected ? selectedIcon : icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
