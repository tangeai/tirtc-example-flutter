import 'dart:io';

import 'package:flutter/services.dart';
import 'package:tirtc_av_kit/tirtc_av_kit.dart';

final class DemoExamplePermissions {
  const DemoExamplePermissions();

  static const MethodChannel _channel = MethodChannel('tirtc_av_kit_example/permissions');

  Future<bool> checkLocalMediaPermissions() async {
    if (!Platform.isAndroid && !Platform.isIOS && !Platform.isMacOS) {
      return true;
    }
    try {
      return await _channel.invokeMethod<bool>('checkLocalMediaPermissions') ?? false;
    } on PlatformException catch (error) {
      TiRtcLogging.w(
        'flutter_example',
        'local_media_permission_check_failed code=${error.code} message=${error.message ?? ''}',
      );
      return false;
    }
  }

  Future<bool> requestLocalMediaPermissions() async {
    if (!Platform.isAndroid && !Platform.isIOS && !Platform.isMacOS) {
      return true;
    }
    try {
      return await _channel.invokeMethod<bool>('requestLocalMediaPermissions') ?? false;
    } on PlatformException catch (error) {
      TiRtcLogging.w(
        'flutter_example',
        'local_media_permission_request_failed code=${error.code} message=${error.message ?? ''}',
      );
      return false;
    }
  }

  Future<void> requestLocalNetworkPermissionIfNeeded() async {
    if (!Platform.isIOS) {
      return;
    }
    try {
      await _channel.invokeMethod<bool>('requestLocalNetworkPermission');
    } on PlatformException catch (error) {
      TiRtcLogging.w(
        'flutter_example',
        'ios_local_network_permission_request_failed code=${error.code} message=${error.message ?? ''}',
      );
    }
  }
}
