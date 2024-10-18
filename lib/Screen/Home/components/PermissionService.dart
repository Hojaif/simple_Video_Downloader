import 'dart:async';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  Future<bool> checkPermission(Permission permission) async {
    if (Platform.isAndroid) {
      AndroidDeviceInfo build = await DeviceInfoPlugin().androidInfo;
      if (build.version.sdkInt >= 30) {
        var result = await Permission.manageExternalStorage.request();
        return result.isGranted;
      } else {
        var result = await permission.request();
        return result.isGranted;
      }
    } else {
      var result = await permission.request();
      return result.isGranted;
    }
  }

  Future<void> checkAndRequestNotificationPermission() async {
    PermissionStatus status = await Permission.notification.status;

    if (status.isDenied || status.isRestricted) {
      // Request notification permission
      await Permission.notification.request();
    }
  }

  Future<void> requestVideoPermission() async {
    PermissionStatus status = await Permission.videos.request();

    if (status.isGranted) {
      // Permission granted
    } else if (status.isDenied) {
      await Permission.videos.request();
    } else if (status.isPermanentlyDenied) {
      openAppSettings();
    }
  }
}
