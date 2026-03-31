import 'dart:io';

import 'package:edge_detection/edge_detection.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class ScannerService {
  Future<void> ensureCameraPermission() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      throw const FileSystemException('Camera permission denied.');
    }
  }

  Future<String> createEdgeOutputPath() async {
    final directory = await getTemporaryDirectory();
    return p.join(
      directory.path,
      'edge_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
  }

  Future<String?> detectEdges() async {
    final outputPath = await createEdgeOutputPath();
    final success = await EdgeDetection.detectEdge(
      outputPath,
      canUseGallery: false,
      androidScanTitle: 'Scan document',
      androidCropTitle: 'Adjust edges',
      androidCropBlackWhiteTitle: 'Enhance',
      androidCropReset: 'Reset',
    );
    if (!success) {
      return null;
    }
    return outputPath;
  }
}
