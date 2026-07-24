import 'dart:io';

import 'package:tirtc_flutter/tirtc_flutter.dart';

import 'package:tirtc_example/src/demo_configuration.dart';
import 'package:tirtc_example/src/demo_downlink_session.dart';

final class AvContractLocalAudioProbeMarker {
  const AvContractLocalAudioProbeMarker({
    required this.name,
    required this.payload,
  });

  final String name;
  final Map<String, Object?> payload;
}

final class AvContractLocalAudioProbeResult {
  const AvContractLocalAudioProbeResult._({
    required this.ok,
    this.failureStage,
    this.message,
    this.errorCode,
    this.markers = const <AvContractLocalAudioProbeMarker>[],
  });

  factory AvContractLocalAudioProbeResult.passed(
    List<AvContractLocalAudioProbeMarker> markers,
  ) {
    return AvContractLocalAudioProbeResult._(ok: true, markers: markers);
  }

  factory AvContractLocalAudioProbeResult.failed({
    required String failureStage,
    required String message,
    int? errorCode,
  }) {
    return AvContractLocalAudioProbeResult._(
      ok: false,
      failureStage: failureStage,
      message: message,
      errorCode: errorCode,
    );
  }

  final bool ok;
  final String? failureStage;
  final String? message;
  final int? errorCode;
  final List<AvContractLocalAudioProbeMarker> markers;
}

Future<AvContractLocalAudioProbeResult> startAvContractLocalAudioProbe({
  required DemoDownlinkSession? session,
  required DemoExampleSettings settings,
}) async {
  if (!Platform.isAndroid) {
    return AvContractLocalAudioProbeResult.passed(const <AvContractLocalAudioProbeMarker>[]);
  }
  if (session == null) {
    return AvContractLocalAudioProbeResult.failed(
      failureStage: 'local_audio_connection',
      message: 'downlink session missing before local audio start',
    );
  }

  final int streamId = settings.localAudioStreamId;
  int code = await session.prepareLocalAudio(audioOptions: _localAudioOptions(settings));
  if (code != 0) {
    return AvContractLocalAudioProbeResult.failed(
      failureStage: 'local_audio_options',
      message: 'local audio input options failed',
      errorCode: code,
    );
  }
  code = await session.attachLocalAudio(streamId: streamId);
  if (code != 0) {
    return AvContractLocalAudioProbeResult.failed(
      failureStage: 'local_audio_attach',
      message: 'local audio input attach failed',
      errorCode: code,
    );
  }
  code = await session.startLocalAudio();
  if (code != 0) {
    return AvContractLocalAudioProbeResult.failed(
      failureStage: 'local_audio_start',
      message: 'local audio input start failed',
      errorCode: code,
    );
  }

  return AvContractLocalAudioProbeResult.passed(
    <AvContractLocalAudioProbeMarker>[
      AvContractLocalAudioProbeMarker(
        name: 'local_audio_input_attached',
        payload: <String, Object?>{
          'stream_id': streamId,
          'previous_stream_id': null,
        },
      ),
      AvContractLocalAudioProbeMarker(
        name: 'local_audio_input_started',
        payload: <String, Object?>{
          'stream_id': streamId,
          'codec': settings.localAudioCodec,
          'sample_rate_hz': settings.localAudioSampleRateHz,
          'channels': 1,
          'start_count': 1,
          'stop_count': 0,
          'reused_binding': false,
        },
      ),
    ],
  );
}

TiRtcAudioInputOptions _localAudioOptions(DemoExampleSettings settings) {
  return TiRtcAudioInputOptions(
    codec: switch (settings.localAudioCodec) {
      DemoExampleSettings.localAudioCodecAac => TiRtcAudioCodec.aac,
      DemoExampleSettings.localAudioCodecPcm => TiRtcAudioCodec.pcm,
      DemoExampleSettings.localAudioCodecOpus => TiRtcAudioCodec.opus,
      DemoExampleSettings.localAudioCodecAmr => TiRtcAudioCodec.amr,
      _ => TiRtcAudioCodec.g711a,
    },
    sampleRate: settings.localAudioSampleRateHz == DemoExampleSettings.localAudioSampleRate8k
        ? TiRtcAudioSampleRate.rate8k
        : TiRtcAudioSampleRate.rate16k,
    channels: TiRtcAudioChannelCount.mono,
    aecMode: settings.localAudioAecEnabled ? TiRtcAudioAecMode.enabled : TiRtcAudioAecMode.disabled,
    agcLevel: _localAudioAgcLevel(settings.localAudioAgcLevel),
    ansLevel: _localAudioAnsLevel(settings.localAudioAnsLevel),
  );
}

TiRtcAudioAgcLevel _localAudioAgcLevel(int value) {
  return switch (value) {
    1 => TiRtcAudioAgcLevel.low,
    2 => TiRtcAudioAgcLevel.medium,
    3 => TiRtcAudioAgcLevel.high,
    _ => TiRtcAudioAgcLevel.disabled,
  };
}

TiRtcAudioAnsLevel _localAudioAnsLevel(int value) {
  return switch (value) {
    1 => TiRtcAudioAnsLevel.low,
    2 => TiRtcAudioAnsLevel.medium,
    3 => TiRtcAudioAnsLevel.high,
    _ => TiRtcAudioAnsLevel.disabled,
  };
}
