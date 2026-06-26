import 'demo_token_acquisition.dart' as token_acquisition;

export 'demo_token_acquisition.dart'
    show
        DemoScanPayload,
        DemoTokenAcquirer,
        DemoTokenHttpRequest,
        DemoTokenHttpResponse,
        DemoTokenSource,
        DemoTokenSourceConfiguration,
        demoTokenIssuerRequest,
        normalizeDemoConnectionToken,
        parseDemoTokenIssuerResponse;

final class DemoExampleSettings {
  static const int videoDecoderPreferenceAuto = 0;
  static const int videoDecoderPreferenceSoftware = 1;
  static const int videoDecoderPreferenceHardware = 2;
  static const String outputBufferPolicyAutomatic = 'automatic';
  static const String outputBufferPolicyNoBuffer = 'no_buffer';
  static const String localAudioCodecG711a = 'g711a';
  static const String localAudioCodecAac = 'aac';
  static const String localAudioCodecPcm = 'pcm';
  static const int localAudioSampleRate8k = 8000;
  static const int localAudioSampleRate16k = 16000;
  static const int defaultLocalAudioStreamId = 14;

  static const Set<int> validVideoDecoderPreferences = <int>{
    videoDecoderPreferenceAuto,
    videoDecoderPreferenceSoftware,
    videoDecoderPreferenceHardware,
  };
  static const Set<String> validOutputBufferPolicies = <String>{
    outputBufferPolicyAutomatic,
    outputBufferPolicyNoBuffer,
  };
  static const Set<String> validLocalAudioCodecs = <String>{
    localAudioCodecG711a,
    localAudioCodecAac,
    localAudioCodecPcm,
  };
  static const Set<int> validLocalAudioSampleRates = <int>{
    localAudioSampleRate8k,
    localAudioSampleRate16k,
  };
  static const Set<int> validLocalAudioProcessingLevels = <int>{0, 1, 2, 3};

  const DemoExampleSettings({
    this.videoDecoderPreference = videoDecoderPreferenceAuto,
    this.outputBufferPolicy = outputBufferPolicyAutomatic,
    this.consoleLogEnabled = false,
    this.localAudioCodec = localAudioCodecG711a,
    this.localAudioSampleRateHz = localAudioSampleRate16k,
    this.localAudioStreamId = defaultLocalAudioStreamId,
    this.localAudioAecEnabled = false,
    this.localAudioAgcLevel = 0,
    this.localAudioAnsLevel = 0,
  });

  final int videoDecoderPreference;
  final String outputBufferPolicy;
  final bool consoleLogEnabled;
  final String localAudioCodec;
  final int localAudioSampleRateHz;
  final int localAudioStreamId;
  final bool localAudioAecEnabled;
  final int localAudioAgcLevel;
  final int localAudioAnsLevel;

  DemoExampleSettings copyWith({
    int? videoDecoderPreference,
    String? outputBufferPolicy,
    bool? consoleLogEnabled,
    String? localAudioCodec,
    int? localAudioSampleRateHz,
    int? localAudioStreamId,
    bool? localAudioAecEnabled,
    int? localAudioAgcLevel,
    int? localAudioAnsLevel,
  }) {
    return DemoExampleSettings(
      videoDecoderPreference: videoDecoderPreference ?? this.videoDecoderPreference,
      outputBufferPolicy: outputBufferPolicy ?? this.outputBufferPolicy,
      consoleLogEnabled: consoleLogEnabled ?? this.consoleLogEnabled,
      localAudioCodec: localAudioCodec ?? this.localAudioCodec,
      localAudioSampleRateHz: localAudioSampleRateHz ?? this.localAudioSampleRateHz,
      localAudioStreamId: localAudioStreamId ?? this.localAudioStreamId,
      localAudioAecEnabled: localAudioAecEnabled ?? this.localAudioAecEnabled,
      localAudioAgcLevel: localAudioAgcLevel ?? this.localAudioAgcLevel,
      localAudioAnsLevel: localAudioAnsLevel ?? this.localAudioAnsLevel,
    );
  }

  static bool isValidVideoDecoderPreference(int value) {
    return validVideoDecoderPreferences.contains(value);
  }

  static bool isValidOutputBufferPolicy(String value) {
    return validOutputBufferPolicies.contains(value);
  }

  static bool isValidLocalAudioCodec(String value) {
    return validLocalAudioCodecs.contains(value);
  }

  static bool isValidLocalAudioSampleRate(int value) {
    return validLocalAudioSampleRates.contains(value);
  }

  static bool isValidLocalAudioStreamId(int value) {
    return value >= 1 && value <= 255;
  }

  static bool isValidLocalAudioProcessingLevel(int value) {
    return validLocalAudioProcessingLevels.contains(value);
  }

  static String videoDecoderPreferenceLabel(int value) {
    return switch (value) {
      videoDecoderPreferenceHardware => '硬解',
      videoDecoderPreferenceSoftware => '软解',
      _ => '自动',
    };
  }

  static String outputBufferPolicyLabel(String value) {
    return switch (value) {
      outputBufferPolicyNoBuffer => '不缓冲',
      _ => '自动',
    };
  }

  static String localAudioCodecLabel(String value) {
    return switch (value) {
      localAudioCodecAac => 'AAC',
      localAudioCodecPcm => 'PCM',
      _ => 'G711A',
    };
  }

  static String localAudioSampleRateLabel(int value) {
    return switch (value) {
      localAudioSampleRate8k => '8 kHz',
      _ => '16 kHz',
    };
  }

  static String localAudioProcessingLevelLabel(int value) {
    return switch (value) {
      1 => '低',
      2 => '中',
      3 => '高',
      _ => '关闭',
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
    required this.tokenSource,
    required this.tokenIssuerBaseUrl,
    required this.token,
    required this.settings,
  });

  final String appId;
  final String endpoint;
  final String remoteId;
  final int audioStreamId;
  final int videoStreamId;
  final token_acquisition.DemoTokenSource tokenSource;
  final String tokenIssuerBaseUrl;
  final String token;
  final DemoExampleSettings settings;

  bool get usesTokenIssuer => tokenSource == token_acquisition.DemoTokenSource.issuer;

  token_acquisition.DemoTokenSourceConfiguration get tokenSourceConfiguration {
    return token_acquisition.DemoTokenSourceConfiguration(
      source: tokenSource,
      tokenIssuerBaseUrl: tokenIssuerBaseUrl,
      oneTimeToken: token,
    );
  }

  DemoDownlinkConfiguration withToken(String resolvedToken) {
    return DemoDownlinkConfiguration(
      appId: appId,
      endpoint: endpoint,
      remoteId: remoteId,
      audioStreamId: audioStreamId,
      videoStreamId: videoStreamId,
      tokenSource: tokenSource,
      tokenIssuerBaseUrl: tokenIssuerBaseUrl,
      token: resolvedToken,
      settings: settings,
    );
  }
}

String normalizeDemoTokenIssuerBaseUrl(String rawValue) {
  return token_acquisition.normalizeDemoTokenIssuerBaseUrl(rawValue);
}

Uri demoTokenIssuerTokenUri(String baseUrl) {
  return token_acquisition.demoTokenIssuerTokenUri(baseUrl);
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

enum DemoDeviceAudioCodec {
  g711a,
  aac,
  pcm;

  static DemoDeviceAudioCodec? tryParse(String value) {
    return switch (value.trim()) {
      'g711a' => DemoDeviceAudioCodec.g711a,
      'aac' => DemoDeviceAudioCodec.aac,
      'pcm' => DemoDeviceAudioCodec.pcm,
      _ => null,
    };
  }
}

enum DemoDeviceAudioSampleRate {
  rate8k,
  rate16k;

  int get hertz => switch (this) {
        DemoDeviceAudioSampleRate.rate8k => 8000,
        DemoDeviceAudioSampleRate.rate16k => 16000,
      };

  static DemoDeviceAudioSampleRate? tryParseHertz(int value) {
    return switch (value) {
      8000 => DemoDeviceAudioSampleRate.rate8k,
      16000 => DemoDeviceAudioSampleRate.rate16k,
      _ => null,
    };
  }
}

enum DemoDeviceAudioChannelCount {
  mono;

  int get count => switch (this) {
        DemoDeviceAudioChannelCount.mono => 1,
      };

  static DemoDeviceAudioChannelCount? tryParseCount(int value) {
    return switch (value) {
      1 => DemoDeviceAudioChannelCount.mono,
      _ => null,
    };
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
    this.audioCodec = DemoDeviceAudioCodec.g711a,
    this.audioSampleRate = DemoDeviceAudioSampleRate.rate16k,
    this.audioChannels = DemoDeviceAudioChannelCount.mono,
    required this.settings,
  });

  final String endpoint;
  final String deviceId;
  final String deviceSecretKey;
  final DemoDeviceCameraFacing cameraFacing;
  final DemoDeviceVideoCodec videoCodec;
  final DemoDeviceEncoderPreference encoderPreference;
  final DemoDeviceAudioCodec audioCodec;
  final DemoDeviceAudioSampleRate audioSampleRate;
  final DemoDeviceAudioChannelCount audioChannels;
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
    DemoDeviceAudioCodec? audioCodec,
    DemoDeviceAudioSampleRate? audioSampleRate,
    DemoDeviceAudioChannelCount? audioChannels,
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
      audioCodec: audioCodec ?? this.audioCodec,
      audioSampleRate: audioSampleRate ?? this.audioSampleRate,
      audioChannels: audioChannels ?? this.audioChannels,
      settings: settings ?? this.settings,
    );
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
