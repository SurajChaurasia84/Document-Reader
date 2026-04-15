import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../models/app_file.dart';
import '../services/app_controller.dart';
import '../utils/formatters.dart';
import '../utils/instant_page_route.dart';
import '../utils/theme_utils.dart';
import 'document_viewer_screen.dart';

class UnlockPdfScreen extends StatefulWidget {
  const UnlockPdfScreen({
    super.key,
    required this.file,
  });

  final AppFile file;

  @override
  State<UnlockPdfScreen> createState() => _UnlockPdfScreenState();
}

class _UnlockPdfScreenState extends State<UnlockPdfScreen> {
  bool _isUnlocking = false;

  @override
  Widget build(BuildContext context) {
    final file = File(widget.file.path);
    final size = file.existsSync() ? formatFileSize(file.lengthSync()) : '--';

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Unlock PDF'),
        actions: <Widget>[
          TextButton(
            onPressed: _isUnlocking ? null : () => _unlock(context),
            child: Text(
              _isUnlocking ? 'Saving...' : 'Unlock',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Enter the password and save an unlocked copy of your protected PDF.',
                style: TextStyle(
                  color: context.primaryText,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Original size: $size',
                style: TextStyle(
                  color: context.secondaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.panelBackground,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: context.borderColor),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 92,
                      height: 124,
                      decoration: BoxDecoration(
                        color: context.isDarkMode
                            ? const Color(0xFF1E2335)
                            : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.lock_rounded,
                        color: context.iconMuted,
                        size: 34,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            widget.file.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.primaryText,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            size,
                            style: TextStyle(
                              color: context.secondaryText,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'An unlocked copy will be saved and the original protected PDF will stay untouched.',
                            style: TextStyle(
                              color: context.secondaryText,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isUnlocking ? null : () => _unlock(context),
                  icon: const Icon(Icons.lock_open_rounded),
                  label: Text(_isUnlocking ? 'Saving...' : 'Unlock PDF'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _unlock(BuildContext context) async {
    final controller = context.read<AppController>();
    final settings = await _promptForSettings(context, _suggestedOutputName());
    if (settings == null) {
      return;
    }

    setState(() {
      _isUnlocking = true;
    });
    final output = await controller.unlockPdfPath(
      widget.file.path,
      password: settings.password,
      outputFileName: settings.fileName,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _isUnlocking = false;
    });
    if (output == null) {
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(content: Text(controller.statusMessage ?? 'Unlock failed')),
      );
      return;
    }

    final outputFile = File(output);
    final unlockedFile = AppFile(
      path: output,
      name: p.basename(output),
      extension: 'pdf',
      size: await outputFile.length(),
      modifiedAt: DateTime.now(),
    );
    if (!mounted) {
      return;
    }
    Navigator.of(this.context).pushReplacement(
      InstantPageRoute<void>(
        builder: (_) => DocumentViewerScreen(file: unlockedFile),
      ),
    );
  }

  String _suggestedOutputName() {
    final now = DateTime.now();
    final stamp =
        '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
    return 'unlocked_$stamp';
  }

  Future<_UnlockPdfSettings?> _promptForSettings(
    BuildContext context,
    String initialFileName,
  ) async {
    return showDialog<_UnlockPdfSettings>(
      context: context,
      builder: (_) => _UnlockPdfDialog(initialFileName: initialFileName),
    );
  }
}

class _UnlockPdfDialog extends StatefulWidget {
  const _UnlockPdfDialog({required this.initialFileName});

  final String initialFileName;

  @override
  State<_UnlockPdfDialog> createState() => _UnlockPdfDialogState();
}

class _UnlockPdfDialogState extends State<_UnlockPdfDialog> {
  late final TextEditingController _fileNameController = TextEditingController(
    text: widget.initialFileName,
  );
  final TextEditingController _passwordController = TextEditingController();
  String? _errorText;
  bool _obscure = true;

  @override
  void dispose() {
    _fileNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Unlock PDF'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: _fileNameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'File name',
              hintText: 'Enter file name',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Enter current password',
              errorText: _errorText,
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure ? Icons.visibility_off : Icons.visibility,
                ),
              ),
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final fileName = _fileNameController.text.trim().isEmpty
                ? widget.initialFileName
                : _fileNameController.text.trim();
            final password = _passwordController.text.trim();

            if (password.isEmpty) {
              setState(() {
                _errorText = 'Enter the PDF password';
              });
              return;
            }
            Navigator.of(
              context,
            ).pop(_UnlockPdfSettings(fileName: fileName, password: password));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _UnlockPdfSettings {
  const _UnlockPdfSettings({
    required this.fileName,
    required this.password,
  });

  final String fileName;
  final String password;
}
