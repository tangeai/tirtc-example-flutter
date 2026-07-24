import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/av_contract_payload.dart';

void main() {
  test('downlink automation payload accepts extended CLI file audio formats', () {
    final AutomationPayloadParseResult opus = AutomationPayload.tryParse(
      runIdAuthority: 'downlink-opus',
      payloadBase64Url: _payloadDefine(
        _downlinkPayload(
          runId: 'downlink-opus',
          audioCodec: 'opus',
          audioSampleRateHz: 16000,
          audioChannels: 2,
        ),
      ),
    );
    expect(opus.valid, isTrue);
    expect(opus.payload!.audioCodec, 'opus');
    expect(opus.payload!.audioChannels, 2);

    final AutomationPayloadParseResult amr = AutomationPayload.tryParse(
      runIdAuthority: 'downlink-amr',
      payloadBase64Url: _payloadDefine(
        _downlinkPayload(
          runId: 'downlink-amr',
          audioCodec: 'amr',
          audioSampleRateHz: 8000,
          audioChannels: 1,
        ),
      ),
    );
    expect(amr.valid, isTrue);
    expect(amr.payload!.audioCodec, 'amr');
    expect(amr.payload!.audioSampleRateHz, 8000);
  });

  test('downlink automation payload rejects unsupported AMR variants', () {
    final AutomationPayloadParseResult result = AutomationPayload.tryParse(
      runIdAuthority: 'downlink-amr-stereo',
      payloadBase64Url: _payloadDefine(
        _downlinkPayload(
          runId: 'downlink-amr-stereo',
          audioCodec: 'amr',
          audioSampleRateHz: 8000,
          audioChannels: 2,
        ),
      ),
    );

    expect(result.valid, isFalse);
    expect(result.failureMessage, 'amr audio must be 8000 Hz mono');
  });
}

Map<String, Object?> _downlinkPayload({
  required String runId,
  required String audioCodec,
  required int audioSampleRateHz,
  required int audioChannels,
}) {
  const String token = 'payload-test-token';
  return <String, Object?>{
    'schema_version': AutomationPayload.schemaVersion,
    'scenario': AutomationPayload.scenarioCliDeviceToFlutterClient,
    'run_id': runId,
    'pairing_id': '$runId-pairing',
    'bootstrap_id': '$runId-bootstrap',
    'app_id': 'AD_testapp',
    'endpoint': 'https://example.invalid',
    'remote_id': 'PRODTEST',
    'token': token,
    'token_fingerprint': _fingerprint(token),
    'audio_stream_id': AutomationPayload.expectedAudioStreamId,
    'video_stream_id': AutomationPayload.expectedVideoStreamId,
    'codec': 'h264',
    'audio_codec': audioCodec,
    'audio_sample_rate_hz': audioSampleRateHz,
    'audio_channels': audioChannels,
    'video_decoder_preference': 0,
    'buffer_policy': 'automatic',
    'render_window_seconds': AutomationPayload.expectedRenderWindowSeconds,
    'auto_upload_logs': true,
    'console_log_enabled': true,
  };
}

String _payloadDefine(Map<String, Object?> payload) {
  return base64UrlEncode(utf8.encode(jsonEncode(payload))).replaceAll('=', '');
}

String _fingerprint(String token) {
  return 'sha256:${sha256.convert(utf8.encode(token))}';
}
