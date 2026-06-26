import 'package:tirtc_av_kit/tirtc_av_kit.dart';

import '../demo_configuration.dart';
import 'example_preferences.dart';

final class DemoDeviceServerConfigurationSnapshot {
  const DemoDeviceServerConfigurationSnapshot({
    this.endpoint = '',
    this.deviceId = '',
    this.deviceSecretKey = '',
    this.cameraFacing = DemoDeviceCameraFacing.back,
    this.videoCodec = DemoDeviceVideoCodec.h264,
    this.encoderPreference = DemoDeviceEncoderPreference.hardware,
  });

  final String endpoint;
  final String deviceId;
  final String deviceSecretKey;
  final DemoDeviceCameraFacing cameraFacing;
  final DemoDeviceVideoCodec videoCodec;
  final DemoDeviceEncoderPreference encoderPreference;
}

final class DemoDeviceServerConfigurationStore {
  const DemoDeviceServerConfigurationStore({
    this.preferences = const MethodChannelDemoExamplePreferences(),
  });

  static const String endpointKey = 'tirtc_av_kit_example.device_server.endpoint';
  static const String deviceIdKey = 'tirtc_av_kit_example.device_server.device_id';
  static const String deviceSecretKeyKey = 'tirtc_av_kit_example.device_server.device_secret_key';
  static const String cameraFacingKey = 'tirtc_av_kit_example.device_server.camera_facing';
  static const String videoCodecKey = 'tirtc_av_kit_example.device_server.video_codec';
  static const String encoderPreferenceKey = 'tirtc_av_kit_example.device_server.encoder_preference';

  final DemoExamplePreferences preferences;

  Future<DemoDeviceServerConfigurationSnapshot> load() async {
    final String endpoint = await _readString(endpointKey);
    final String deviceId = await _readString(deviceIdKey);
    final String deviceSecretKey = await _readString(deviceSecretKeyKey);
    final DemoDeviceCameraFacing cameraFacing = DemoDeviceCameraFacing.tryParse(
          await _readString(cameraFacingKey, defaultValue: DemoDeviceCameraFacing.back.name),
        ) ??
        DemoDeviceCameraFacing.back;
    final DemoDeviceVideoCodec videoCodec = DemoDeviceVideoCodec.tryParseConfigurable(
          await _readString(videoCodecKey, defaultValue: DemoDeviceVideoCodec.h264.name),
        ) ??
        DemoDeviceVideoCodec.h264;
    DemoDeviceEncoderPreference encoderPreference = DemoDeviceEncoderPreference.tryParse(
          await _readString(encoderPreferenceKey, defaultValue: DemoDeviceEncoderPreference.hardware.name),
        ) ??
        DemoDeviceEncoderPreference.hardware;
    if (videoCodec == DemoDeviceVideoCodec.mjpeg) {
      encoderPreference = DemoDeviceEncoderPreference.software;
    }
    return DemoDeviceServerConfigurationSnapshot(
      endpoint: endpoint,
      deviceId: deviceId,
      deviceSecretKey: deviceSecretKey,
      cameraFacing: cameraFacing,
      videoCodec: videoCodec,
      encoderPreference: encoderPreference,
    );
  }

  Future<void> save(DemoDeviceServerConfiguration configuration) async {
    await preferences.putString(key: endpointKey, value: configuration.endpoint);
    await preferences.putString(key: deviceIdKey, value: configuration.deviceId);
    await preferences.putString(key: deviceSecretKeyKey, value: configuration.deviceSecretKey);
    await saveDevicePreferences(
      cameraFacing: configuration.cameraFacing,
      videoCodec: configuration.videoCodec,
      encoderPreference: configuration.encoderPreference,
    );
  }

  Future<void> saveDevicePreferences({
    required DemoDeviceCameraFacing cameraFacing,
    required DemoDeviceVideoCodec videoCodec,
    required DemoDeviceEncoderPreference encoderPreference,
  }) async {
    final DemoDeviceEncoderPreference resolvedPreference =
        videoCodec == DemoDeviceVideoCodec.mjpeg ? DemoDeviceEncoderPreference.software : encoderPreference;
    await preferences.putString(key: cameraFacingKey, value: cameraFacing.name);
    await preferences.putString(key: videoCodecKey, value: videoCodec.name);
    await preferences.putString(key: encoderPreferenceKey, value: resolvedPreference.name);
  }

  Future<String> _readString(String key, {String defaultValue = ''}) async {
    try {
      return await preferences.getString(key: key, defaultValue: defaultValue);
    } on Object catch (error) {
      TiRtcLogging.w(
        'flutter_example',
        'device_server_preferences_read_failed key=$key error=$error',
      );
      return defaultValue;
    }
  }
}
