import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraPermissionService {
  CameraPermissionService._();

  static Future<void> requestPermissionIfNeeded(BuildContext context) async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      return;
    }

    final result = await Permission.camera.request();

    if (result.isPermanentlyDenied && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Camera access is required to capture problems. Enable it in settings.',
          ),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () {
              openAppSettings();
            },
          ),
        ),
      );
    }
  }
}
