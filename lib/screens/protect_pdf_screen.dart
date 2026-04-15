import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../models/app_file.dart';
import '../services/app_controller.dart';
import '../utils/formatters.dart';
import '../utils/instant_page_route.dart';
import 'document_viewer_screen.dart';

class ProtectPdfScreen extends StatefulWidget {
  const ProtectPdfScreen({
    super.key,
    required this.inputPath,
  });

  final String inputPath;

  @override
  State<ProtectPdfScreen> createState() => _ProtectPdfScreenState();
}

class _ProtectPdfScreenState extends State<ProtectPdfScreen> {
  bool _isProtecting = false;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<AppController>();
    final file = File(widget.inputPath);
    final name = p.basename(widget.inputPath);
    final size = file.existsSync() ? formatFileSize(file.lengthSync()) : '--';

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Protect PDF'),
        actions: <Widget>[
          TextButton(
            onPressed: _isProtecting
                ? null
                : () => _protectPdf(context, controller),
            child: Text(
              _isProtecting ? 'Saving...' : 'Protect',
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
              const Text(
                'Preview and save a password-protected copy of your PDF.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Original size: $size',
                style: const TextStyle(
                  color: Color(0xFF96A0AE),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF131726),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF1E2135)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    FutureBuilder<Uint8List?>(
                      future: controller.pdfService.renderPageAsImage(
                        widget.inputPath,
                        1,
                      ),
                      builder: (context, snapshot) {
                        final bytes = snapshot.data;
                        return Container(
                          width: 92,
                          height: 124,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E2335),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: bytes == null
                              ? const Icon(
                                  Icons.lock_rounded,
                                  color: Colors.white70,
                                  size: 34,
                                )
                              : Stack(
                                  fit: StackFit.expand,
                                  children: <Widget>[
                                    Image.memory(bytes, fit: BoxFit.cover),
                                    Align(
                                      alignment: Alignment.topRight,
                                      child: Container(
                                        margin: const EdgeInsets.all(6),
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(
                                            alpha: 0.55,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.lock_rounded,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        );
                      },
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            size,
                            style: const TextStyle(
                              color: Color(0xFF96A0AE),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'A protected copy will be saved so your original PDF stays untouched.',
                            style: TextStyle(
                              color: Color(0xFF96A0AE),
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
                  onPressed: _isProtecting
                      ? null
                      : () => _protectPdf(context, controller),
                  icon: const Icon(Icons.lock_rounded),
                  label: Text(_isProtecting ? 'Saving...' : 'Protect PDF'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _protectPdf(
    BuildContext context,
    AppController controller,
  ) async {
    final settings = await _promptForSettings(context, _suggestedOutputName());
    if (settings == null) {
      return;
    }

    setState(() {
      _isProtecting = true;
    });
    final output = await controller.protectPdfPath(
      widget.inputPath,
      password: settings.password,
      outputFileName: settings.fileName,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _isProtecting = false;
    });
    if (output == null) {
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(content: Text(controller.statusMessage ?? 'Protection failed')),
      );
      return;
    }

    final outputFile = File(output);
    final protectedFile = AppFile(
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
        builder: (_) => DocumentViewerScreen(file: protectedFile),
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
    return 'protected_$stamp';
  }

  Future<_ProtectPdfSettings?> _promptForSettings(
    BuildContext context,
    String initialFileName,
  ) async {
    return showDialog<_ProtectPdfSettings>(
      context: context,
      builder: (_) => _ProtectPdfDialog(initialFileName: initialFileName),
    );
  }
}

class _ProtectPdfDialog extends StatefulWidget {
  const _ProtectPdfDialog({required this.initialFileName});

  final String initialFileName;

  @override
  State<_ProtectPdfDialog> createState() => _ProtectPdfDialogState();
}

class _ProtectPdfDialogState extends State<_ProtectPdfDialog> {
  late final TextEditingController _fileNameController = TextEditingController(
    text: widget.initialFileName,
  );
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  String? _errorText;
  bool _obscure = true;

  @override
  void dispose() {
    _fileNameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Protect PDF'),
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
              hintText: 'Enter password',
              errorText: _errorText,
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure ? Icons.visibility_off : Icons.visibility,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmPasswordController,
            obscureText: _obscure,
            decoration: const InputDecoration(
              labelText: 'Confirm password',
              hintText: 'Re-enter password',
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
            final confirmPassword = _confirmPasswordController.text.trim();

            if (password.isEmpty) {
              setState(() {
                _errorText = 'Enter a password';
              });
              return;
            }
            if (password != confirmPassword) {
              setState(() {
                _errorText = 'Passwords do not match';
              });
              return;
            }
            Navigator.of(
              context,
            ).pop(_ProtectPdfSettings(fileName: fileName, password: password));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _ProtectPdfSettings {
  const _ProtectPdfSettings({
    required this.fileName,
    required this.password,
  });

  final String fileName;
  final String password;
}
