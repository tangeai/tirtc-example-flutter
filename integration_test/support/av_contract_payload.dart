import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:tirtc_example/src/demo_configuration.dart';

const String automationRunIdDefine = String.fromEnvironment(
  'TIRTC_INTEGRATION_RUN_ID',
);
const String automationPayloadDefine = String.fromEnvironment(
  'TIRTC_INTEGRATION_PAYLOAD_B64URL',
);
const Set<String> _supportedAudioCodecs = <String>{
  'g711a',
  'aac',
  'pcm',
  'opus',
  'amr',
};
const Set<int> _supportedAudioSampleRates = <int>{8000, 16000};
const Set<int> _supportedAudioChannels = <int>{1, 2};

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
  static const int expectedAudioStreamId = 10;
  static const int expectedVideoStreamId = 11;
  static const int expectedRenderWindowSeconds = 30;

  const AutomationPayload({
    required this.runId,
    required this.scenario,
    required this.pairingId,
    required this.bootstrapId,
    required this.appId,
    required this.endpoint,
    required this.remoteId,
    required this.token,
    required this.tokenFingerprint,
    required this.audioStreamId,
    required this.videoStreamId,
    required this.codec,
    required this.audioCodec,
    required this.audioSampleRateHz,
    required this.audioChannels,
    required this.videoDecoderPreference,
    required this.bufferPolicy,
    required this.renderWindowSeconds,
    required this.metricsSessionResetAfterSeconds,
    required this.autoUploadLogs,
    required this.consoleLogEnabled,
  });

  final String runId;
  final String scenario;
  final String pairingId;
  final String bootstrapId;
  final String appId;
  final String? endpoint;
  final String remoteId;
  final String token;
  final String tokenFingerprint;
  final int audioStreamId;
  final int videoStreamId;
  final String codec;
  final String audioCodec;
  final int audioSampleRateHz;
  final int audioChannels;
  final int videoDecoderPreference;
  final String bufferPolicy;
  final int renderWindowSeconds;
  final int? metricsSessionResetAfterSeconds;
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
        scenario: decoded['scenario']! as String,
        pairingId: decoded['pairing_id']! as String,
        bootstrapId: decoded['bootstrap_id']! as String,
        appId: decoded['app_id']! as String,
        endpoint: decoded['endpoint'] as String?,
        remoteId: decoded['remote_id']! as String,
        token: decoded['token']! as String,
        tokenFingerprint: decoded['token_fingerprint']! as String,
        audioStreamId: decoded['audio_stream_id']! as int,
        videoStreamId: decoded['video_stream_id']! as int,
        codec: decoded['codec']! as String,
        audioCodec: decoded['audio_codec']! as String,
        audioSampleRateHz: decoded['audio_sample_rate_hz']! as int,
        audioChannels: decoded['audio_channels']! as int,
        videoDecoderPreference: decoded.containsKey('video_decoder_preference')
            ? decoded['video_decoder_preference']! as int
            : DemoExampleSettings.videoDecoderPreferenceAuto,
        bufferPolicy: decoded.containsKey('buffer_policy')
            ? decoded['buffer_policy']! as String
            : DemoExampleSettings.outputBufferPolicyAutomatic,
        renderWindowSeconds: decoded['render_window_seconds']! as int,
        metricsSessionResetAfterSeconds: decoded['metrics_session_reset_after_seconds'] as int?,
        autoUploadLogs: decoded['auto_upload_logs']! as bool,
        consoleLogEnabled: decoded.containsKey('console_log_enabled') ? decoded['console_log_enabled']! as bool : true,
      ),
    );
  }

  Map<String, Object?> markerPayload() {
    return <String, Object?>{
      'scenario': scenario,
      'pairing_id': pairingId,
      'bootstrap_id': bootstrapId,
      'app_id_present': appId.isNotEmpty,
      'endpoint': endpoint,
      'remote_id': remoteId,
      'token_fingerprint': tokenFingerprint,
      'audio_stream_id': audioStreamId,
      'video_stream_id': videoStreamId,
      'codec': codec,
      'audio_codec': audioCodec,
      'audio_sample_rate_hz': audioSampleRateHz,
      'audio_channels': audioChannels,
      'video_decoder_preference': videoDecoderPreference,
      'buffer_policy': bufferPolicy,
      'requested_output_buffer_policy': bufferPolicy,
      'requested_output_buffer_max_watermark_ms': null,
      'render_window_seconds': renderWindowSeconds,
      if (metricsSessionResetAfterSeconds != null)
        'metrics_session_reset_after_seconds': metricsSessionResetAfterSeconds,
      'auto_upload_logs': autoUploadLogs,
      'console_log_enabled': consoleLogEnabled,
    };
  }

  static String? _validate(Map<String, Object?> payload, String runIdAuthority) {
    if (payload['schema_version'] != schemaVersion) {
      return 'schema_version must be 1';
    }
    if (payload['run_id'] != runIdAuthority) {
      return 'run id mismatch';
    }
    if (payload['scenario'] != scenarioCliDeviceToFlutterClient) {
      return 'scenario must be cli_device_to_flutter_client';
    }
    for (final String key in <String>[
      'pairing_id',
      'bootstrap_id',
      'app_id',
      'remote_id',
      'token',
      'token_fingerprint',
      'codec',
      'audio_codec',
    ]) {
      final String? error = _requiredString(payload, key);
      if (error != null) {
        return error;
      }
    }
    if (payload['endpoint'] != null && payload['endpoint'] is! String) {
      return 'endpoint must be a string or null';
    }
    final String audioCodec = payload['audio_codec']! as String;
    if (!_supportedAudioCodecs.contains(audioCodec)) {
      return 'audio_codec must be pcm, g711a, aac, opus, or amr';
    }
    if (payload['audio_sample_rate_hz'] is! int ||
        !_supportedAudioSampleRates.contains(payload['audio_sample_rate_hz'])) {
      return 'audio_sample_rate_hz must be 8000 or 16000';
    }
    if (payload['audio_channels'] is! int || !_supportedAudioChannels.contains(payload['audio_channels'])) {
      return 'audio_channels must be 1 or 2';
    }
    final int audioSampleRateHz = payload['audio_sample_rate_hz']! as int;
    final int audioChannels = payload['audio_channels']! as int;
    if (audioCodec == 'amr' && (audioSampleRateHz != 8000 || audioChannels != 1)) {
      return 'amr audio must be 8000 Hz mono';
    }
    if (payload['audio_stream_id'] != expectedAudioStreamId || payload['video_stream_id'] != expectedVideoStreamId) {
      return 'stream id mismatch';
    }
    if (payload.containsKey('video_decoder_preference')) {
      final Object? value = payload['video_decoder_preference'];
      if (value is! int || !DemoExampleSettings.isValidVideoDecoderPreference(value)) {
        return 'video_decoder_preference must be 0, 1, or 2';
      }
    }
    if (payload.containsKey('buffer_policy')) {
      final Object? value = payload['buffer_policy'];
      if (value is! String || !DemoExampleSettings.isValidOutputBufferPolicy(value)) {
        return 'buffer_policy must be automatic or no_buffer';
      }
    }
    if (payload['render_window_seconds'] is! int || (payload['render_window_seconds']! as int) <= 0) {
      return 'render_window_seconds must be positive';
    }
    if (payload.containsKey('metrics_session_reset_after_seconds')) {
      final Object? resetAfterSeconds = payload['metrics_session_reset_after_seconds'];
      if (resetAfterSeconds is! int || resetAfterSeconds < 0) {
        return 'metrics_session_reset_after_seconds must be a non-negative integer';
      }
      if (resetAfterSeconds >= (payload['render_window_seconds']! as int)) {
        return 'metrics_session_reset_after_seconds must be less than render_window_seconds';
      }
    }
    if (payload['auto_upload_logs'] != true) {
      return 'auto_upload_logs must be true';
    }
    if (payload.containsKey('console_log_enabled') && payload['console_log_enabled'] != true) {
      return 'console_log_enabled must be true';
    }
    if (_fingerprint(payload['token']! as String) != payload['token_fingerprint']) {
      return 'token fingerprint mismatch';
    }
    return null;
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
