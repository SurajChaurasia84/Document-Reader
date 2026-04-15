import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_file.dart';
import '../services/app_controller.dart';
import '../utils/formatters.dart';
import '../utils/theme_utils.dart';

class ProtectedPdfPickerScreen extends StatefulWidget {
  const ProtectedPdfPickerScreen({super.key});

  @override
  State<ProtectedPdfPickerScreen> createState() =>
      _ProtectedPdfPickerScreenState();
}

class _ProtectedPdfPickerScreenState extends State<ProtectedPdfPickerScreen> {
  late Future<List<AppFile>> _future = _loadProtectedFiles();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Protected PDFs'),
      ),
      body: FutureBuilder<List<AppFile>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final files = snapshot.data ?? const <AppFile>[];
          if (files.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No protected PDF found in your scanned files.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.secondaryText,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _future = _loadProtectedFiles();
              });
              await _future;
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: files.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final file = files[index];
                return Material(
                  color: context.panelBackground,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.of(context).pop(file),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.borderColor),
                      ),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.lock_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  file.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: context.primaryText,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${formatFileSize(file.size)} • ${_formatDate(file.modifiedAt)}',
                                  style: TextStyle(
                                    color: context.secondaryText,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: context.iconMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<List<AppFile>> _loadProtectedFiles() async {
    final controller = context.read<AppController>();
    final favoritePaths = controller.favoriteFiles.map((item) => item.path).toSet();
    final createdFiles = await controller.pdfService.listCreatedFiles(
      favorites: favoritePaths,
    );
    final candidates = <String, AppFile>{};

    for (final file in <AppFile>[
      ...controller.recentFiles,
      ...controller.internalFiles,
      ...controller.downloadFiles,
      ...createdFiles,
    ]) {
      if (file.extension.toLowerCase() == 'pdf' && await File(file.path).exists()) {
        candidates[file.path] = file;
      }
    }

    final protected = <AppFile>[];
    for (final file in candidates.values) {
      final isProtected = await controller.pdfService.isPdfPasswordProtected(
        file.path,
      );
      if (isProtected) {
        protected.add(file);
      }
    }

    protected.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return protected;
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }
}
