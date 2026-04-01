import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_file.dart';
import '../services/app_controller.dart';
import '../widgets/glass_card.dart';
import 'document_viewer_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  CameraController? _cameraController;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _setupCamera();
  }

  Future<void> _setupCamera() async {
    final controller = context.read<AppController>();
    try {
      await controller.scannerService.ensureCameraPermission();
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('No camera found on this device.');
      }

      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.read<AppController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Scanner')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : Stack(
              children: <Widget>[
                Positioned.fill(child: CameraPreview(_cameraController!)),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 28,
                  child: GlassCard(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const Text(
                          'Capture, detect edges, and instantly convert to PDF.',
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () async {
                            try {
                              String? imagePath;
                              try {
                                imagePath = await controller.scannerService
                                    .detectEdges();
                              } catch (_) {
                                imagePath = null;
                              }

                              imagePath ??=
                                  (await _cameraController!.takePicture()).path;
                              final output = await controller.pdfService
                                  .imageToPdf(<String>[imagePath]);
                              final scannedFile = AppFile(
                                path: output,
                                name: output.split(RegExp(r'[\\/]')).last,
                                extension: 'pdf',
                                size: await File(output).length(),
                                modifiedAt: DateTime.now(),
                              );
                              if (!context.mounted) {
                                return;
                              }
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      DocumentViewerScreen(file: scannedFile),
                                ),
                              );
                            } catch (error) {
                              if (!context.mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(error.toString())),
                              );
                            }
                          },
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Capture'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
