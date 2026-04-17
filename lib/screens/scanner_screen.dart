import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_file.dart';
import '../services/app_controller.dart';
import '../utils/instant_page_route.dart';
import '../widgets/glass_card.dart';
import 'document_viewer_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  CameraController? _cameraController;
  final List<String> _scanQueue = [];
  String? _currentCapturePath;
  bool _loading = true;
  bool _processing = false;
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

  Future<void> _onCapture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    setState(() => _processing = true);
    try {
      final photo = await _cameraController!.takePicture();
      setState(() {
        _currentCapturePath = photo.path;
        _processing = false;
      });
    } catch (e) {
      setState(() => _processing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _onNext() {
    if (_currentCapturePath != null) {
      setState(() {
        _scanQueue.add(_currentCapturePath!);
        _currentCapturePath = null;
      });
    }
  }

  Future<void> _onAdjust() async {
    if (_currentCapturePath == null) return;

    final controller = context.read<AppController>();
    final adjustedPath =
        await controller.scannerService.adjustEdges(_currentCapturePath!);

    if (adjustedPath != null) {
      setState(() {
        _scanQueue.add(adjustedPath);
        _currentCapturePath = null;
      });
    }
  }

  void _onRetake() {
    if (_currentCapturePath != null) {
      final file = File(_currentCapturePath!);
      if (file.existsSync()) file.deleteSync();
      setState(() {
        _currentCapturePath = null;
      });
    }
  }

  Future<void> _onFinalize() async {
    if (_scanQueue.isEmpty) return;

    setState(() => _loading = true);
    try {
      final controller = context.read<AppController>();
      final output = await controller.pdfService.imageToPdf(_scanQueue);

      final scannedFile = AppFile(
        path: output,
        name: output.split(RegExp(r'[\\/]')).last,
        extension: 'pdf',
        size: await File(output).length(),
        modifiedAt: DateTime.now(),
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        InstantPageRoute<void>(
          builder: (_) => DocumentViewerScreen(file: scannedFile),
        ),
      );
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    // Cleanup temporary files
    for (final path in _scanQueue) {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    }
    if (_currentCapturePath != null) {
      final file = File(_currentCapturePath!);
      if (file.existsSync()) file.deleteSync();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Multi-page scanner'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white)))
              : Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: CameraPreview(_cameraController!),
                    ),
                    if (_currentCapturePath != null)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black54,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.file(
                                    File(_currentCapturePath!),
                                    height: MediaQuery.of(context).size.height * 0.5,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                GlassCard(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _actionButton(
                                        context: context,
                                        icon: Icons.refresh_rounded,
                                        label: 'Retake',
                                        onPressed: _onRetake,
                                      ),
                                      const SizedBox(width: 20),
                                      _actionButton(
                                        context: context,
                                        icon: Icons.auto_fix_high_rounded,
                                        label: 'Adjust',
                                        onPressed: _onAdjust,
                                        primary: true,
                                      ),
                                      const SizedBox(width: 20),
                                      _actionButton(
                                        context: context,
                                        icon: Icons.arrow_forward_rounded,
                                        label: 'Next',
                                        onPressed: _onNext,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (_currentCapturePath == null)
                      Positioned(
                        bottom: 40,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            const SizedBox(width: 60), // Spacer for balance
                            GestureDetector(
                              onTap: _processing ? null : _onCapture,
                              child: _CaptureButton(isProcessing: _processing),
                            ),
                            _PageCountIndicator(count: _scanQueue.length),
                          ],
                        ),
                      ),
                    if (_scanQueue.isNotEmpty && _currentCapturePath == null)
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 60,
                        right: 20,
                        child: FloatingActionButton.extended(
                          onPressed: _onFinalize,
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          label: const Text('Create PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                          icon: const Icon(Icons.check_rounded),
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget _actionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool primary = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filled(
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor: primary ? Theme.of(context).colorScheme.primary : Colors.white24,
            padding: const EdgeInsets.all(12),
          ),
          icon: Icon(icon, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _CaptureButton extends StatelessWidget {
  final bool isProcessing;
  const _CaptureButton({required this.isProcessing});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 76,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isProcessing ? Colors.white54 : Colors.white,
          shape: BoxShape.circle,
        ),
        child: isProcessing ? const Center(child: CircularProgressIndicator(color: Colors.grey)) : null,
      ),
    );
  }
}

class _PageCountIndicator extends StatelessWidget {
  final int count;
  const _PageCountIndicator({required this.count});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox(width: 60);
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.black45,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 2),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$count', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            const Text('PAGES', style: TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
