import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

class MediaPermissionService {
  const MediaPermissionService._();

  static Future<bool> ensureCamera() async {
    final status = await Permission.camera.request();
    return _handleStatus(status);
  }

  static Future<bool> ensurePhotoLibrary() async {
    if (Platform.isIOS) {
      final status = await Permission.photos.request();
      return _handleStatus(status);
    }
    if (Platform.isAndroid) {
      final status = await Permission.photos.request();
      if (_handleStatus(status)) return true;
      final fallback = await Permission.storage.request();
      return _handleStatus(fallback);
    }
    return false;
  }

  static bool _handleStatus(PermissionStatus status) {
    if (status.isGranted || status.isLimited) return true;
    return false;
  }
}
