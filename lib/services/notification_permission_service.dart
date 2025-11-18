import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationPermissionService {
  NotificationPermissionService._();

  static Future<void> requestPermissionIfNeeded(BuildContext context) async {
    final status = await Permission.notification.status;
    if (status.isGranted || status.isLimited) {
      return;
    }

    final result = await Permission.notification.request();
    if (result.isPermanentlyDenied && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Notifications are disabled. Enable them in settings to get updates.',
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

