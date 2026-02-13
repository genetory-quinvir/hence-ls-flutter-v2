import 'package:permission_handler/permission_handler.dart';

class LocationPermissionService {
  LocationPermissionService._();

  static Future<bool> requestWhenInUse() async {
    final status = await Permission.locationWhenInUse.request();
    return status.isGranted;
  }

  static Future<bool> isGranted() async {
    final status = await Permission.locationWhenInUse.status;
    return status.isGranted;
  }

  static Future<PermissionStatus> getStatus() async {
    return Permission.locationWhenInUse.status;
  }

  static bool isGrantedStatus(PermissionStatus status) {
    return status.isGranted || status.isLimited;
  }
}
