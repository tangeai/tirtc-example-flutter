import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:tirtc_av_kit_example/src/demo_configuration.dart';

const String automationRunIdDefine = String.fromEnvironment(
  'TIRTC_AV_INTEGRATION_RUN_ID',
);
const String automationPayloadDefine = String.fromEnvironment(
  'TIRTC_AV_INTEGRATION_PAYLOAD_B64URL',
);

final class AutomationPayloadParseResult {
  const AutomationPayloadParseResult._({
    required this.enabled,
    this.payload,
    this.failureMessage,
  });

  factory AutomationPayloadParseResult.disabled() {
    return const AutomationPayloadParseResult._(enabled: false);
  }

  factory AutomationPayloadParseResult.failed(String message) {
    return AutomationPayloadParseResult._(
      enabled: true,
      failureMessage: message,
    );
  }

  factory AutomationPayloadParseResult.parsed(AutomationPayload payload) {
    return AutomationPayloadParseResult._(
      enabled: true,
      payload: payload,
    );
  }

  final bool enabled;
  final AutomationPayload? payload;
  final String? failureMessage;

  bool get valid => enabled && payload != null;
}

final class AutomationPayload {
  static const int schemaVersion = 1;
  static const String scenarioCliDeviceToFlutterClient = 'cli_device_to_flutter_client';
  static const String scenarioFlutterDeviceServerToCliClient = 'flutter_device_server_to_cli_client';
  static const int expectedAudioStreamId = 10;
  static const int expectedVideoStreamId = 11;
  static const int expectedRenderWindowSeconds = 30;

  const AutomationPayload({
    required this.runId,
    required this.scenario,
    required this.bootstrapId,
    required this.appId,
    required this.endpoint,
    required this.remoteId,
    required this.token,
    required this.tokenFingerprint,
    required this.deviceId,
    required this.deviceSecretKey,
    required this.audioStreamId,
    required this.videoStreamId,
    required this.codec,
    required this.encoderPreference,
    required this.videoDecoderPreference,
    required this.renderWindowSeconds,
    required this.autoUploadLogs,
    required this.consoleLogEnabled,
  });

  final String runId;
  final String scenario;
  final String bootstrapId;
  final String appId;
  final String? endpoint;
  final String remoteId;
  final String token;
  final String tokenFingerprint;
  final String deviceId;
  final String deviceSecretKey;
  final int audioStreamId;
  final int videoStreamId;
  final String codec;
  final String encoderPreference;
  final int videoDecoderPreference;
  final int renderWindowSeconds;
  final bool autoUploadLogs;
  final bool consoleLogEnabled;

  static AutomationPayloadParseResult fromEnvironment() {
    return tryParse(
      runIdAuthority: automationRunIdDefine,
      payloadBase64Url: automationPayloadDefine,
    );
  }

  static AutomationPayloadParseResult tryParse({
    required String runIdAuthority,
    required String payloadBase64Url,
  }) {
    if (runIdAuthority.isEmpty) {
      return AutomationPayloadParseResult.failed('missing automation run id');
    }
    if (payloadBase64Url.isEmpty) {
      return AutomationPayloadParseResult.failed('missing automation payload');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(_decodeBase64Url(payloadBase64Url)));
    } on FormatException {
      return AutomationPayloadParseResult.failed('automation payload is not valid base64url JSON');
    }
    if (decoded is! Map<String, Object?>) {
      return AutomationPayloadParseResult.failed('automation payload is not an object');
    }

    final String? validationError = _validate(decoded, runIdAuthority);
    if (validationError != null) {
      return AutomationPayloadParseResult.failed(validationError);
    }

    return AutomationPayloadParseResult.parsed(
      AutomationPayload(
        runId: runIdAuthority,
        scenario: decoded.containsKey('scenario')
            ? decoded['scenario']! as String
            : AutomationPayload.scenarioCliDeviceToFlutterClient,
        bootstrapId: decoded['bootstrap_id']! as String,
        appId: decoded.containsKey('app_id') ? decoded['app_id']! as String : '',
        endpoint: decoded['endpoint'] as String?,
        remoteId: decoded.containsKey('remote_id') ? decoded['remote_id']! as String : '',
        token: decoded.containsKey('token') ? decoded['token']! as String : '',
        tokenFingerprint: decoded.containsKey('token_fingerprint') ? decoded['token_fingerprint']! as String : '',
        deviceId: decoded.containsKey('device_id') ? decoded['device_id']! as String : '',
        deviceSecretKey: decoded.containsKey('device_secret_key') ? decoded['device_secret_key']! as String : '',
        audioStreamId: decoded['audio_stream_id']! as int,
        videoStreamId: decoded['video_stream_id']! as int,
        codec: decoded['codec']! as String,
        encoderPreference: decoded.containsKey('encoder_preference')
            ? decoded['encoder_preference']! as String
            : DemoDeviceEncoderPreference.hardware.name,
        videoDecoderPreference: decoded.containsKey('video_decoder_preference')
            ? decoded['video_decoder_preference']! as int
            : DemoExampleSettings.videoDecoderPreferenceAuto,
        renderWindowSeconds: decoded['render_window_seconds']! as int,
        autoUploadLogs: decoded['auto_upload_logs']! as bool,
        consoleLogEnabled: decoded.containsKey('console_log_enabled') ? decoded['console_log_enabled']! as bool : true,
      ),
    );
  }

  Map<String, Object?> markerPayload() {
    return <String, Object?>{
      'scenario': scenario,
      'bootstrap_id': bootstrapId,
      'app_id_present': appId.isNotEmpty,
      'endpoint': endpoint,
      if (remoteId.isNotEmpty) 'remote_id': remoteId,
      if (tokenFingerprint.isNotEmpty) 'token_fingerprint': tokenFingerprint,
      if (scenario == scenarioFlutterDeviceServerToCliClient) 'device_id_present': deviceId.isNotEmpty,
      'audio_stream_id': audioStreamId,
      'video_stream_id': videoStreamId,
      'codec': codec,
      if (scenario == scenarioFlutterDeviceServerToCliClient) ...<String, Object?>{
        'page_role': 'device_server',
        'page_lifecycle': 'manual_page',
        'requested_video_codec': codec,
        'requested_encoder_preference': encoderPreference,
        'requested_width': DemoDeviceServerConfiguration.fixedVideoWidth,
        'requested_height': DemoDeviceServerConfiguration.fixedVideoHeight,
        'requested_fps': DemoDeviceServerConfiguration.fixedVideoFps,
      },
      'video_decoder_preference': videoDecoderPreference,
      'render_window_seconds': renderWindowSeconds,
      'auto_upload_logs': autoUploadLogs,
      'console_log_enabled': consoleLogEnabled,
    };
  }

  static String? _validate(Map<String, Object?> payload, String runIdAuthority) {
    final Object? schemaVersion = payload['schema_version'];
    if (schemaVersion != AutomationPayload.schemaVersion) {
      return 'schema_version must be 1';
    }
    if (payload['run_id'] != runIdAuthority) {
      return 'run id mismatch';
    }
    final String scenario = payload.containsKey('scenario')
        ? _stringField(payload, 'scenario') ?? ''
        : AutomationPayload.scenarioCliDeviceToFlutterClient;
    if (scenario != AutomationPayload.scenarioCliDeviceToFlutterClient &&
        scenario != AutomationPayload.scenarioFlutterDeviceServerToCliClient) {
      return 'scenario is invalid';
    }
    final String? bootstrapId = _requiredString(payload, 'bootstrap_id');
    final String? codec = _requiredString(payload, 'codec');
    if (bootstrapId != null || codec != null) {
      return bootstrapId ?? codec;
    }
    if (scenario == AutomationPayload.scenarioCliDeviceToFlutterClient) {
      final String? appId = _requiredString(payload, 'app_id');
      final String? remoteId = _requiredString(payload, 'remote_id');
      final String? token = _requiredString(payload, 'token');
      final String? tokenFingerprint = _requiredString(payload, 'token_fingerprint');
      if (appId != null || remoteId != null || token != null || tokenFingerprint != null) {
        return appId ?? remoteId ?? token ?? tokenFingerprint;
      }
    } else {
      if (payload.containsKey('app_id') && payload['app_id'] is! String) {
        return 'app_id must be a string';
      }
      final String? deviceId = _requiredString(payload, 'device_id');
      final String? deviceSecretKey = _requiredString(payload, 'device_secret_key');
      if (deviceId != null || deviceSecretKey != null) {
        return deviceId ?? deviceSecretKey;
      }
      if (payload.containsKey('width') ||
          payload.containsKey('height') ||
          payload.containsKey('frame_rate') ||
          payload.containsKey('bitrate_kbps')) {
        return 'local media dimensions are fixed';
      }
    }
    if (payload['codec'] is! String) {
      return 'codec must be a string';
    }
    final String codecValue = payload['codec']! as String;
    if (scenario == AutomationPayload.scenarioFlutterDeviceServerToCliClient) {
      if (DemoDeviceVideoCodec.tryParse(codecValue) == null) {
        return 'server codec must be h264, h265, or mjpeg';
      }
      final Object? rawEncoderPreference = payload['encoder_preference'];
      if (rawEncoderPreference != null && rawEncoderPreference is! String) {
        return 'encoder_preference must be a string';
      }
      final String encoderPreferenceValue =
          rawEncoderPreference is String ? rawEncoderPreference : DemoDeviceEncoderPreference.hardware.name;
      final DemoDeviceEncoderPreference? encoderPreference =
          DemoDeviceEncoderPreference.tryParse(encoderPreferenceValue);
      if (encoderPreference == null) {
        return 'encoder_preference must be software or hardware';
      }
    }
    if (payload['endpoint'] != null && payload['endpoint'] is! String) {
      return 'endpoint must be a string or null';
    }
    if (payload['audio_stream_id'] != expectedAudioStreamId || payload['video_stream_id'] != expectedVideoStreamId) {
      return 'stream id mismatch';
    }
    if (payload.containsKey('video_decoder_preference')) {
      final Object? videoDecoderPreference = payload['video_decoder_preference'];
      if (videoDecoderPreference is! int ||
          !DemoExampleSettings.isValidVideoDecoderPreference(videoDecoderPreference)) {
        return 'video_decoder_preference must be 0, 1, or 2';
      }
    }
    if (payload['render_window_seconds'] != expectedRenderWindowSeconds) {
      return 'render_window_seconds must be $expectedRenderWindowSeconds';
    }
    if (payload['auto_upload_logs'] != true) {
      return 'auto_upload_logs must be true';
    }
    if (payload.containsKey('console_log_enabled')) {
      final Object? consoleLogEnabled = payload['console_log_enabled'];
      if (consoleLogEnabled != true) {
        return 'console_log_enabled must be true';
      }
    }
    if (scenario == AutomationPayload.scenarioCliDeviceToFlutterClient &&
        _fingerprint(payload['token']! as String) != payload['token_fingerprint']) {
      return 'token fingerprint mismatch';
    }
    return null;
  }

  static String? _stringField(Map<String, Object?> payload, String key) {
    final Object? value = payload[key];
    return value is String ? value : null;
  }

  static String? _requiredString(Map<String, Object?> payload, String key) {
    final Object? value = payload[key];
    if (value is String && value.isNotEmpty) {
      return null;
    }
    return '$key is required';
  }

  static List<int> _decodeBase64Url(String value) {
    final int padding = (4 - value.length % 4) % 4;
    return base64Url.decode(value + ''.padRight(padding, '='));
  }

  static String _fingerprint(String token) {
    return 'sha256:${sha256.convert(utf8.encode(token))}';
  }
}
