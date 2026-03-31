import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_controller.dart';
import '../utils/app_theme.dart';
import 'files_screen.dart';
import 'home_screen.dart';
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
      const FilesScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      extendBody: true,
      body: SafeArea(
        child: IndexedStack(index: controller.currentIndex, children: screens),
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
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppTheme.surface.withValues(alpha: 0.92),
        selectedIndex: controller.currentIndex,
        onDestinationSelected: controller.updateNavigation,
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_fix_high_outlined),
            selectedIcon: Icon(Icons.auto_fix_high),
            label: 'Tools',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: 'Files',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
