import 'dart:convert';
import 'dart:io';

const String exampleSmokeRunIdDefine = String.fromEnvironment('TIRTC_EXAMPLE_SMOKE_RUN_ID');
const String exampleSmokePayloadDefine = String.fromEnvironment('TIRTC_EXAMPLE_SMOKE_PAYLOAD_B64URL');

final class ExampleSmokePayload {
  const ExampleSmokePayload({
    required this.runId,
    required this.platform,
    required this.pairingId,
    required this.appId,
    required this.endpoint,
    required this.remoteId,
    required this.token,
    required this.audioStreamId,
    required this.localAudioStreamId,
    required this.videoStreamId,
    required this.renderWindowSeconds,
  });

  final String runId;
  final String platform;
  final String pairingId;
  final String appId;
  final String endpoint;
  final String remoteId;
  final String token;
  final int audioStreamId;
  final int localAudioStreamId;
  final int videoStreamId;
  final int renderWindowSeconds;

  String get flow => 'downlink_ui';

  static ExampleSmokePayload fromEnvironment() {
    final String runId = exampleSmokeRunIdDefine.isNotEmpty
        ? exampleSmokeRunIdDefine
        : (Platform.environment['TIRTC_EXAMPLE_SMOKE_RUN_ID'] ?? '');
    final String encodedPayload = exampleSmokePayloadDefine.isNotEmpty
        ? exampleSmokePayloadDefine
        : (Platform.environment['TIRTC_EXAMPLE_SMOKE_PAYLOAD_B64URL'] ?? '');
    if (runId.isEmpty) {
      throw StateError('missing example smoke run id');
    }
    if (encodedPayload.isEmpty) {
      throw StateError('missing example smoke payload');
    }
    final Object? decoded = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(encodedPayload))),
    );
    if (decoded is! Map<String, Object?>) {
      throw StateError('example smoke payload is not an object');
    }
    if (decoded['run_id'] != runId) {
      throw StateError('example smoke run id mismatch');
    }
    if (decoded['flow'] != null && decoded['flow'] != 'downlink_ui') {
      throw StateError('example smoke flow must be downlink_ui');
    }
    if (decoded.containsKey('token_issuer_base_url') || decoded.containsKey('token_issuer_url')) {
      throw StateError('example smoke payload must not provide token issuer URL');
    }
    final String token = (decoded['token'] as String?) ?? '';
    if (token.isEmpty) {
      throw StateError('example smoke payload must provide token');
    }
    return ExampleSmokePayload(
      runId: runId,
      platform: (decoded['platform'] as String?) ?? 'macos',
      pairingId: (decoded['pairing_id'] as String?) ?? runId,
      appId: decoded['app_id']! as String,
      endpoint: (decoded['endpoint'] as String?) ?? '',
      remoteId: decoded['remote_id']! as String,
      token: token,
      audioStreamId: (decoded['audio_stream_id'] as int?) ?? 10,
      localAudioStreamId: (decoded['local_audio_stream_id'] as int?) ?? 14,
      videoStreamId: (decoded['video_stream_id'] as int?) ?? 11,
      renderWindowSeconds: (decoded['render_window_seconds'] as int?) ?? 30,
    );
  }
}
