import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_file.dart';
import '../services/app_controller.dart';
import '../utils/file_action_helper.dart';
import '../utils/theme_utils.dart';

enum FileAction { open, rename, share, favorite, info, delete, save }

class StandardFileActionMenu extends StatelessWidget {
  const StandardFileActionMenu({
    super.key,
    required this.file,
    required this.onOpen,
    this.onChanged,
    this.onSave,
  });

  final AppFile file;
  final VoidCallback onOpen;
  final VoidCallback? onChanged; // Called after rename/favorite/delete
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<AppController>();

    return PopupMenuButton<FileAction>(
      tooltip: 'File actions',
      padding: EdgeInsets.zero,
      iconSize: 22,
      style: IconButton.styleFrom(
        foregroundColor: context.secondaryText,
        visualDensity: VisualDensity.compact,
      ),
      icon: const Icon(Icons.more_vert_rounded),
      elevation: 8,
      color: context.panelBackground,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (action) async {
        switch (action) {
          case FileAction.open:
            onOpen();
            break;
          case FileAction.rename:
            await FileActionHelper.showRenameDialog(
              context: context,
              file: file,
              controller: controller,
              onRenamed: () {
                 if (onChanged != null) onChanged!();
              },
            );
            break;
          case FileAction.share:
            await FileActionHelper.shareFile(context, file);
            break;
          case FileAction.favorite:
            await controller.toggleFavorite(file);
            if (onChanged != null) onChanged!();
            break;
          case FileAction.info:
            await FileActionHelper.showInfoDialog(context, file);
            break;
          case FileAction.delete:
            await FileActionHelper.showDeleteDialog(
              context: context,
              file: file,
              controller: controller,
              onDeleted: () {
                 if (onChanged != null) onChanged!();
              },
            );
            break;
          case FileAction.save:
            if (onSave != null) onSave!();
            break;
        }
      },
      itemBuilder: (context) => [
        _buildItem(context, FileAction.open, Icons.open_in_new_rounded, 'Open'),
        _buildSeparator(),
        _buildItem(
          context,
          FileAction.favorite,
          file.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
          file.isFavorite ? 'Remove from favorites' : 'Add to favorites',
          iconColor: file.isFavorite ? const Color(0xFFF3B63F) : null,
        ),
        _buildItem(context, FileAction.rename, Icons.drive_file_rename_outline_rounded, 'Rename'),
        _buildItem(context, FileAction.share, Icons.share_rounded, 'Share'),
        _buildItem(context, FileAction.info, Icons.info_outline_rounded, 'Info'),
        if (onSave != null)
           _buildItem(context, FileAction.save, Icons.save_alt_rounded, 'Save to Files'),
        _buildSeparator(),
        _buildItem(context, FileAction.delete, Icons.delete_outline_rounded, 'Delete', 
            iconColor: Colors.redAccent, textColor: Colors.redAccent),
      ],
    );
  }

  PopupMenuItem<FileAction> _buildItem(
    BuildContext context,
    FileAction action,
    IconData icon,
    String label, {
    Color? iconColor,
    Color? textColor,
  }) {
    return PopupMenuItem<FileAction>(
      value: action,
      height: 48,
      child: Row(
        children: [
          Icon(icon, color: iconColor ?? context.secondaryText, size: 20),
          const SizedBox(width: 14),
          Text(
            label,
            style: TextStyle(
              color: textColor ?? context.primaryText,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuEntry<FileAction> _buildSeparator() {
    return const PopupMenuDivider(height: 1);
  }
}
