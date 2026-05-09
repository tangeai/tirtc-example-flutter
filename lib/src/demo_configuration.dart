import 'dart:convert';

final class DemoExampleSettings {
  static const int videoDecoderPreferenceAuto = 0;
  static const int videoDecoderPreferenceSoftware = 1;
  static const int videoDecoderPreferenceHardware = 2;

  static const Set<int> validVideoDecoderPreferences = <int>{
    videoDecoderPreferenceAuto,
    videoDecoderPreferenceSoftware,
    videoDecoderPreferenceHardware,
  };

  const DemoExampleSettings({
    this.videoDecoderPreference = videoDecoderPreferenceAuto,
    this.consoleLogEnabled = false,
  });

  final int videoDecoderPreference;
  final bool consoleLogEnabled;

  DemoExampleSettings copyWith({
    int? videoDecoderPreference,
    bool? consoleLogEnabled,
  }) {
    return DemoExampleSettings(
      videoDecoderPreference: videoDecoderPreference ?? this.videoDecoderPreference,
      consoleLogEnabled: consoleLogEnabled ?? this.consoleLogEnabled,
    );
  }

  static bool isValidVideoDecoderPreference(int value) {
    return validVideoDecoderPreferences.contains(value);
  }

  static String videoDecoderPreferenceLabel(int value) {
    return switch (value) {
      videoDecoderPreferenceHardware => '硬解',
      videoDecoderPreferenceSoftware => '软解',
      _ => '自动',
    };
  }
}

final class DemoDownlinkConfiguration {
  static const int defaultAudioStreamId = 10;
  static const int defaultVideoStreamId = 11;

  const DemoDownlinkConfiguration({
    required this.appId,
    required this.endpoint,
    required this.remoteId,
    required this.audioStreamId,
    required this.videoStreamId,
    required this.token,
    required this.settings,
  });

  final String appId;
  final String endpoint;
  final String remoteId;
  final int audioStreamId;
  final int videoStreamId;
  final String token;
  final DemoExampleSettings settings;
}

enum DemoDeviceCameraFacing {
  front,
  back;

  static DemoDeviceCameraFacing? tryParse(String value) {
    return switch (value.trim()) {
      'front' => DemoDeviceCameraFacing.front,
      'back' => DemoDeviceCameraFacing.back,
      _ => null,
    };
  }
}

enum DemoDeviceVideoCodec {
  h264,
  h265,
  mjpeg;

  static DemoDeviceVideoCodec? tryParse(String value) {
    return switch (value.trim()) {
      'h264' => DemoDeviceVideoCodec.h264,
      'h265' => DemoDeviceVideoCodec.h265,
      'mjpeg' => DemoDeviceVideoCodec.mjpeg,
      _ => null,
    };
  }

  static DemoDeviceVideoCodec? tryParseConfigurable(String value) {
    final DemoDeviceVideoCodec? codec = tryParse(value);
    return codec == DemoDeviceVideoCodec.h265 ? null : codec;
  }
}

enum DemoDeviceEncoderPreference {
  software,
  hardware;

  static DemoDeviceEncoderPreference? tryParse(String value) {
    return switch (value.trim()) {
      'software' => DemoDeviceEncoderPreference.software,
      'hardware' => DemoDeviceEncoderPreference.hardware,
      _ => null,
    };
  }
}

final class DemoDeviceServerConfiguration {
  static const int defaultAudioStreamId = 10;
  static const int defaultVideoStreamId = 11;
  static const int fixedVideoWidth = 1280;
  static const int fixedVideoHeight = 720;
  static const int fixedVideoFps = 15;
  static const int fixedVideoBitrateKbps = 0;

  const DemoDeviceServerConfiguration({
    required this.endpoint,
    required this.deviceId,
    required this.deviceSecretKey,
    this.cameraFacing = DemoDeviceCameraFacing.back,
    this.videoCodec = DemoDeviceVideoCodec.h264,
    this.encoderPreference = DemoDeviceEncoderPreference.hardware,
    required this.settings,
  });

  final String endpoint;
  final String deviceId;
  final String deviceSecretKey;
  final DemoDeviceCameraFacing cameraFacing;
  final DemoDeviceVideoCodec videoCodec;
  final DemoDeviceEncoderPreference encoderPreference;
  final DemoExampleSettings settings;

  bool get validCodecBackend =>
      videoCodec != DemoDeviceVideoCodec.h265 &&
      (videoCodec != DemoDeviceVideoCodec.mjpeg || encoderPreference == DemoDeviceEncoderPreference.software);

  DemoDeviceServerConfiguration copyWith({
    String? endpoint,
    String? deviceId,
    String? deviceSecretKey,
    DemoDeviceCameraFacing? cameraFacing,
    DemoDeviceVideoCodec? videoCodec,
    DemoDeviceEncoderPreference? encoderPreference,
    DemoExampleSettings? settings,
  }) {
    final DemoDeviceVideoCodec resolvedCodec = videoCodec ?? this.videoCodec;
    DemoDeviceEncoderPreference resolvedPreference = encoderPreference ?? this.encoderPreference;
    if (resolvedCodec == DemoDeviceVideoCodec.mjpeg) {
      resolvedPreference = DemoDeviceEncoderPreference.software;
    }
    return DemoDeviceServerConfiguration(
      endpoint: endpoint ?? this.endpoint,
      deviceId: deviceId ?? this.deviceId,
      deviceSecretKey: deviceSecretKey ?? this.deviceSecretKey,
      cameraFacing: cameraFacing ?? this.cameraFacing,
      videoCodec: resolvedCodec,
      encoderPreference: resolvedPreference,
      settings: settings ?? this.settings,
    );
  }
}

final class DemoDeviceServerScanPayload {
  const DemoDeviceServerScanPayload({
    required this.deviceId,
    required this.deviceSecretKey,
    this.endpoint,
  });

  final String deviceId;
  final String deviceSecretKey;
  final String? endpoint;

  static const Set<String> _allowedPayloadKeys = <String>{
    'device_id',
    'device_secret_key',
    'endpoint',
  };

  static DemoDeviceServerScanPayload? tryParse(String rawValue) {
    final Object? decoded;
    try {
      decoded = jsonDecode(DemoScanPayload._normalizeJson(rawValue));
    } on FormatException {
      return null;
    }
    if (decoded is! Map<Object?, Object?>) {
      return null;
    }

    final Map<Object?, Object?> payload = decoded;
    for (final Object? key in payload.keys) {
      if (key is! String || !_allowedPayloadKeys.contains(key)) {
        return null;
      }
    }
    final String deviceId = DemoScanPayload._stringValue(payload['device_id']);
    final String deviceSecretKey = DemoScanPayload._stringValue(payload['device_secret_key']);
    if (deviceId.isEmpty || deviceSecretKey.isEmpty) {
      return null;
    }

    final Object? rawEndpoint = payload['endpoint'];
    if (payload.containsKey('endpoint') && rawEndpoint != null && rawEndpoint is! String) {
      return null;
    }
    final String? endpoint = rawEndpoint is String ? rawEndpoint.trim() : null;
    if (endpoint != null && endpoint.isNotEmpty && !_validEndpoint(endpoint)) {
      return null;
    }

    return DemoDeviceServerScanPayload(
      deviceId: deviceId,
      deviceSecretKey: deviceSecretKey,
      endpoint: endpoint == null || endpoint.isEmpty ? null : endpoint,
    );
  }
}

final class DemoScanPayload {
  const DemoScanPayload({
    required this.appId,
    required this.remoteId,
    required this.token,
    this.endpoint,
  });

  final String appId;
  final String remoteId;
  final String token;
  final String? endpoint;

  static DemoScanPayload? tryParse(String rawValue) {
    final Object? decoded;
    try {
      decoded = jsonDecode(_normalizeJson(rawValue));
    } on FormatException {
      return null;
    }
    if (decoded is! Map<Object?, Object?>) {
      return null;
    }

    final Map<Object?, Object?> payload = decoded;
    final String appId = _stringValue(payload['app_id']);
    final String remoteId = _stringValue(payload['remote_id']);
    final String token = _stringValue(payload['token']);
    final String? endpoint = payload.containsKey('endpoint') ? _stringValue(payload['endpoint']) : null;
    if (appId.isEmpty || remoteId.isEmpty || token.isEmpty) {
      return null;
    }
    return DemoScanPayload(
      appId: appId,
      remoteId: remoteId,
      token: token,
      endpoint: endpoint,
    );
  }

  static String _normalizeJson(String rawValue) {
    return rawValue.replaceAll(RegExp(r',\s*}'), '}').replaceAll(RegExp(r',\s*]'), ']');
  }

  static String _stringValue(Object? value) {
    return switch (value) {
      final String text => text.trim(),
      _ => '',
    };
  }
}

bool demoEndpointValid(String text) => _validEndpoint(text.trim());

bool _validEndpoint(String text) {
  if (text.isEmpty) {
    return true;
  }
  final Uri? uri = Uri.tryParse(text);
  return uri != null && uri.host.isNotEmpty && (uri.scheme == 'http' || uri.scheme == 'https');
}
