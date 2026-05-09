import 'dart:convert';

const String exampleSmokeRunIdDefine = String.fromEnvironment('TIRTC_EXAMPLE_SMOKE_RUN_ID');
const String exampleSmokePayloadDefine = String.fromEnvironment('TIRTC_EXAMPLE_SMOKE_PAYLOAD_B64URL');

final class ExampleSmokePayload {
  const ExampleSmokePayload({
    required this.runId,
    required this.flow,
    required this.appId,
    required this.endpoint,
    required this.remoteId,
    required this.token,
    required this.deviceId,
    required this.deviceSecretKey,
    required this.audioStreamId,
    required this.videoStreamId,
    required this.renderWindowSeconds,
  });

  final String runId;
  final String flow;
  final String appId;
  final String endpoint;
  final String remoteId;
  final String token;
  final String deviceId;
  final String deviceSecretKey;
  final int audioStreamId;
  final int videoStreamId;
  final int renderWindowSeconds;

  static ExampleSmokePayload fromEnvironment() {
    if (exampleSmokeRunIdDefine.isEmpty) {
      throw StateError('missing example smoke run id');
    }
    if (exampleSmokePayloadDefine.isEmpty) {
      throw StateError('missing example smoke payload');
    }
    final Object? decoded = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(exampleSmokePayloadDefine))));
    if (decoded is! Map<String, Object?>) {
      throw StateError('example smoke payload is not an object');
    }
    if (decoded['run_id'] != exampleSmokeRunIdDefine) {
      throw StateError('example smoke run id mismatch');
    }
    return ExampleSmokePayload(
      runId: exampleSmokeRunIdDefine,
      flow: (decoded['flow'] as String?) ?? 'downlink_ui',
      appId: decoded['app_id']! as String,
      endpoint: (decoded['endpoint'] as String?) ?? '',
      remoteId: decoded['remote_id']! as String,
      token: decoded['token']! as String,
      deviceId: (decoded['device_id'] as String?) ?? '',
      deviceSecretKey: (decoded['device_secret_key'] as String?) ?? '',
      audioStreamId: (decoded['audio_stream_id'] as int?) ?? 10,
      videoStreamId: (decoded['video_stream_id'] as int?) ?? 11,
      renderWindowSeconds: (decoded['render_window_seconds'] as int?) ?? 30,
    );
  }
}
