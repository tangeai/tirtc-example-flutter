import 'dart:convert';

const String exampleSmokeRunIdDefine = String.fromEnvironment('TIRTC_EXAMPLE_SMOKE_RUN_ID');
const String exampleSmokePayloadDefine = String.fromEnvironment('TIRTC_EXAMPLE_SMOKE_PAYLOAD_B64URL');
const String exampleSmokeTokenSourceIssuer = 'issuer';
const String exampleSmokeTokenSourceOneTime = 'one_time_token';

final class ExampleSmokePayload {
  const ExampleSmokePayload({
    required this.runId,
    required this.platform,
    required this.flow,
    required this.pairingId,
    required this.appId,
    required this.endpoint,
    required this.remoteId,
    required this.tokenSource,
    required this.token,
    required this.tokenIssuerBaseUrl,
    required this.deviceId,
    required this.deviceSecretKey,
    required this.audioStreamId,
    required this.localAudioStreamId,
    required this.videoStreamId,
    required this.renderWindowSeconds,
  });

  final String runId;
  final String platform;
  final String flow;
  final String pairingId;
  final String appId;
  final String endpoint;
  final String remoteId;
  final String tokenSource;
  final String token;
  final String tokenIssuerBaseUrl;
  final String deviceId;
  final String deviceSecretKey;
  final int audioStreamId;
  final int localAudioStreamId;
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
    final String token = (decoded['token'] as String?) ?? '';
    final String tokenIssuerBaseUrl =
        (decoded['token_issuer_base_url'] as String?) ?? (decoded['token_issuer_url'] as String?) ?? '';
    final String tokenSource = _parseTokenSource(
      decoded['token_source'],
      token: token,
      tokenIssuerBaseUrl: tokenIssuerBaseUrl,
    );
    final String flow = (decoded['flow'] as String?) ?? 'downlink_ui';
    if (flow == 'downlink_ui') {
      if (token.isNotEmpty && tokenIssuerBaseUrl.isNotEmpty) {
        throw StateError('example smoke payload must not provide both token and token_issuer_base_url');
      }
      if (tokenSource == exampleSmokeTokenSourceIssuer && tokenIssuerBaseUrl.isEmpty) {
        throw StateError('example smoke issuer payload must provide token_issuer_base_url');
      }
      if (tokenSource == exampleSmokeTokenSourceOneTime && token.isEmpty) {
        throw StateError('example smoke one-time payload must provide token');
      }
    }
    return ExampleSmokePayload(
      runId: exampleSmokeRunIdDefine,
      platform: (decoded['platform'] as String?) ?? 'macos',
      flow: flow,
      pairingId: (decoded['pairing_id'] as String?) ?? exampleSmokeRunIdDefine,
      appId: decoded['app_id']! as String,
      endpoint: (decoded['endpoint'] as String?) ?? '',
      remoteId: decoded['remote_id']! as String,
      tokenSource: tokenSource,
      token: token,
      tokenIssuerBaseUrl: tokenIssuerBaseUrl,
      deviceId: (decoded['device_id'] as String?) ?? '',
      deviceSecretKey: (decoded['device_secret_key'] as String?) ?? '',
      audioStreamId: (decoded['audio_stream_id'] as int?) ?? 10,
      localAudioStreamId: (decoded['local_audio_stream_id'] as int?) ?? 14,
      videoStreamId: (decoded['video_stream_id'] as int?) ?? 11,
      renderWindowSeconds: (decoded['render_window_seconds'] as int?) ?? 30,
    );
  }

  static String _parseTokenSource(
    Object? value, {
    required String token,
    required String tokenIssuerBaseUrl,
  }) {
    final String rawValue = value is String ? value : '';
    final String resolved = rawValue.isEmpty
        ? (token.isNotEmpty && tokenIssuerBaseUrl.isEmpty
            ? exampleSmokeTokenSourceOneTime
            : exampleSmokeTokenSourceIssuer)
        : rawValue;
    if (resolved == exampleSmokeTokenSourceIssuer || resolved == exampleSmokeTokenSourceOneTime) {
      return resolved;
    }
    throw StateError('unsupported example smoke token_source: $resolved');
  }
}
