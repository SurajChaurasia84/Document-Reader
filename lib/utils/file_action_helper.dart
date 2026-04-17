import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/app_file.dart';
import '../services/app_controller.dart';
import '../utils/formatters.dart';
import '../utils/theme_utils.dart';

class FileActionHelper {
  /// Opens a file in the DocumentViewerScreen (handled by the screen/caller).
  /// This helper focuses on dialogs and side-actions.

  static Future<void> showInfoDialog(BuildContext context, AppFile file) async {
    if (!context.mounted) return;

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.panelBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: context.primaryAccent),
            const SizedBox(width: 12),
            Text(
              'File Information',
              style: TextStyle(color: context.primaryText, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoTile(context, 'Name', file.name),
              _infoTile(context, 'Format', file.extension.toUpperCase()),
              _infoTile(context, 'Size', formatFileSize(file.size)),
              _infoTile(context, 'Last Modified', formatDate(file.modifiedAt)),
              _infoTile(context, 'Path', file.path, isPath: true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: context.primaryAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static Widget _infoTile(BuildContext context, String label, String value, {bool isPath = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: context.secondaryText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: context.primaryText,
              fontSize: 14,
              fontWeight: isPath ? FontWeight.normal : FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> showRenameDialog({
    required BuildContext context,
    required AppFile file,
    required AppController controller,
    required VoidCallback onRenamed,
  }) async {
    final nameController = TextEditingController(text: file.nameWithoutExtension);
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.panelBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Rename File', style: TextStyle(color: context.primaryText, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: nameController,
          autofocus: true,
          style: TextStyle(color: context.primaryText),
          decoration: InputDecoration(
            hintText: 'Enter new name',
            hintStyle: TextStyle(color: context.secondaryText),
            suffixText: '.${file.extension}',
            suffixStyle: TextStyle(color: context.secondaryText),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: context.borderColor)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: context.primaryAccent, width: 2)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: context.secondaryText)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.primaryAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && result != file.nameWithoutExtension) {
      try {
        final newName = '$result.${file.extension}';
        await controller.renameFile(file, newName);
        onRenamed();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File renamed successfully')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}')),
          );
        }
      }
    }
  }

  static Future<void> showDeleteDialog({
    required BuildContext context,
    required AppFile file,
    required AppController controller,
    required VoidCallback onDeleted,
  }) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.panelBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete File?', style: TextStyle(color: context.primaryText, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to delete "${file.name}"? This action cannot be undone.',
          style: TextStyle(color: context.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: context.secondaryText)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        await controller.deleteManagedFile(file);
        onDeleted();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File deleted')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}')),
          );
        }
      }
    }
  }

  static Future<void> shareFile(BuildContext context, AppFile file) async {
    if (!await File(file.path).exists()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File is no longer available')),
        );
      }
      return;
    }

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Shared from PDF Studio',
      subject: file.name,
    );
  }
}
