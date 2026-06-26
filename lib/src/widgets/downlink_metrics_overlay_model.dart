import 'package:flutter/foundation.dart';

import '../demo_widget_keys.dart';

const int _mediaCodecAudioG711A = 1;
const int _mediaCodecAudioAac = 2;
const int _mediaCodecAudioPcm = 3;
const int _mediaCodecAudioOpus = 4;
const int _mediaCodecAudioAmr = 5;
const int _mediaCodecVideoH264 = 65;
const int _mediaCodecVideoH265 = 66;
const int _mediaCodecVideoMjpeg = 67;
const int _videoDecoderBackendSoftware = 1;
const int _videoDecoderBackendHardware = 2;
const double _minimumVideoRenderContinuityRatio = 0.8;

class DownlinkMetricsOverlayModel {
  const DownlinkMetricsOverlayModel({
    required this.connectDurationMs,
    required this.firstFrameDurationMs,
    required this.sessionStutterRatio,
    required this.sessionStutterTotalMs,
    required this.sessionStutterCount,
    required this.sessionStutterPeakMs,
    required this.videoWidth,
    required this.videoHeight,
    required this.videoCodec,
    required this.audioCodec,
    required this.audioSampleRate,
    required this.audioChannels,
    required this.requestedDecoderPreference,
    required this.resolvedDecoderBackend,
    required this.audioInputBitrateKbps,
    required this.audioInputPacketRate,
    required this.audioRenderCallbackRate,
    required this.audioRecentStutterRatio,
    required this.audioRecentStutterCount,
    required this.audioRecentStutterTotalMs,
    required this.audioRecentStutterPeakMs,
    required this.audioRateWindowDurationMs,
    required this.audioLatencyWindowDurationMs,
    required this.audioLatencyTotalAverageMs,
    required this.audioLatencyBufferAverageMs,
    required this.audioLatencyDecodeReadyAverageMs,
    required this.audioLatencyOutputAverageMs,
    required this.audioLatencyTotalSampleCount,
    required this.audioLatencyBufferSampleCount,
    required this.audioLatencyDecodeReadySampleCount,
    required this.audioLatencyOutputSampleCount,
    required this.audioLatencyTotalUnavailableCount,
    required this.audioLatencySessionDurationMs,
    required this.audioLatencySessionTotalAverageMs,
    required this.audioLatencySessionTotalMinMs,
    required this.audioLatencySessionTotalPeakMs,
    required this.audioLatencySessionTotalSampleCount,
    required this.audioLatencySessionTotalUnavailableCount,
    required this.videoInputBitrateKbps,
    required this.videoInputFps,
    required this.videoDecodedFps,
    required this.videoRenderFps,
    required this.videoRateWindowDurationMs,
    required this.videoLatencyWindowDurationMs,
    required this.videoLatencyTotalAverageMs,
    required this.videoLatencyBufferAverageMs,
    required this.videoLatencyDecodeReadyAverageMs,
    required this.videoLatencyOutputAverageMs,
    required this.videoLatencyTotalSampleCount,
    required this.videoLatencyBufferSampleCount,
    required this.videoLatencyDecodeReadySampleCount,
    required this.videoLatencyOutputSampleCount,
    required this.videoLatencyTotalUnavailableCount,
    required this.videoLatencySessionDurationMs,
    required this.videoLatencySessionTotalAverageMs,
    required this.videoLatencySessionTotalMinMs,
    required this.videoLatencySessionTotalPeakMs,
    required this.videoLatencySessionTotalSampleCount,
    required this.videoLatencySessionTotalUnavailableCount,
  });

  final int? connectDurationMs;
  final int? firstFrameDurationMs;
  final double? sessionStutterRatio;
  final int? sessionStutterTotalMs;
  final int? sessionStutterCount;
  final int? sessionStutterPeakMs;
  final int? videoWidth;
  final int? videoHeight;
  final int? videoCodec;
  final int? audioCodec;
  final int? audioSampleRate;
  final int? audioChannels;
  final int requestedDecoderPreference;
  final int? resolvedDecoderBackend;
  final double? audioInputBitrateKbps;
  final double? audioInputPacketRate;
  final double? audioRenderCallbackRate;
  final double? audioRecentStutterRatio;
  final int? audioRecentStutterCount;
  final int? audioRecentStutterTotalMs;
  final int? audioRecentStutterPeakMs;
  final int? audioRateWindowDurationMs;
  final int? audioLatencyWindowDurationMs;
  final int? audioLatencyTotalAverageMs;
  final int? audioLatencyBufferAverageMs;
  final int? audioLatencyDecodeReadyAverageMs;
  final int? audioLatencyOutputAverageMs;
  final int? audioLatencyTotalSampleCount;
  final int? audioLatencyBufferSampleCount;
  final int? audioLatencyDecodeReadySampleCount;
  final int? audioLatencyOutputSampleCount;
  final int? audioLatencyTotalUnavailableCount;
  final int? audioLatencySessionDurationMs;
  final int? audioLatencySessionTotalAverageMs;
  final int? audioLatencySessionTotalMinMs;
  final int? audioLatencySessionTotalPeakMs;
  final int? audioLatencySessionTotalSampleCount;
  final int? audioLatencySessionTotalUnavailableCount;
  final double? videoInputBitrateKbps;
  final double? videoInputFps;
  final double? videoDecodedFps;
  final double? videoRenderFps;
  final int? videoRateWindowDurationMs;
  final int? videoLatencyWindowDurationMs;
  final int? videoLatencyTotalAverageMs;
  final int? videoLatencyBufferAverageMs;
  final int? videoLatencyDecodeReadyAverageMs;
  final int? videoLatencyOutputAverageMs;
  final int? videoLatencyTotalSampleCount;
  final int? videoLatencyBufferSampleCount;
  final int? videoLatencyDecodeReadySampleCount;
  final int? videoLatencyOutputSampleCount;
  final int? videoLatencyTotalUnavailableCount;
  final int? videoLatencySessionDurationMs;
  final int? videoLatencySessionTotalAverageMs;
  final int? videoLatencySessionTotalMinMs;
  final int? videoLatencySessionTotalPeakMs;
  final int? videoLatencySessionTotalSampleCount;
  final int? videoLatencySessionTotalUnavailableCount;

  String get displayVideoSize {
    final int? width = videoWidth;
    final int? height = videoHeight;
    if (width == null || height == null || width <= 0 || height <= 0) {
      return '--';
    }
    return '${width}x$height';
  }

  String get displayVideoCodec {
    return switch (videoCodec) {
      _mediaCodecVideoH264 => 'H264',
      _mediaCodecVideoH265 => 'H265',
      _mediaCodecVideoMjpeg => 'MJPEG',
      _ => '--',
    };
  }

  String get displayAudioCodec {
    return switch (audioCodec) {
      _mediaCodecAudioG711A => 'G711A',
      _mediaCodecAudioAac => 'AAC',
      _mediaCodecAudioPcm => 'PCM',
      _mediaCodecAudioOpus => 'OPUS',
      _mediaCodecAudioAmr => 'AMR',
      _ => '--',
    };
  }

  String get displayVideoDecoder {
    return switch (resolvedDecoderBackend) {
      _videoDecoderBackendHardware => '硬解',
      _videoDecoderBackendSoftware => '软解',
      _ => '未确定',
    };
  }

  bool get debugStatsReady {
    final int? width = videoWidth;
    final int? height = videoHeight;
    return width != null &&
        width > 0 &&
        height != null &&
        height > 0 &&
        _isKnownVideoCodec(videoCodec) &&
        _isKnownAudioCodec(audioCodec) &&
        _isKnownAudioSampleRate(audioSampleRate) &&
        _isKnownAudioChannels(audioChannels) &&
        _isResolvedDecoderBackend(resolvedDecoderBackend);
  }

  bool get avStatsReady {
    return audioOutputMetricsReady && videoOutputMetricsReady;
  }

  bool get audioOutputMetricsReady {
    return _positive(audioInputBitrateKbps) &&
        _positive(audioInputPacketRate) &&
        _positive(audioRenderCallbackRate) &&
        _positive(audioRateWindowDurationMs) &&
        _positive(audioLatencyWindowDurationMs) &&
        _positive(audioLatencyTotalSampleCount);
  }

  double? get audioOutputContinuityRatio {
    return _rateRatio(audioRenderCallbackRate, audioInputPacketRate);
  }

  bool get audioOutputHealthOk {
    return audioOutputMetricsReady && (audioRecentStutterCount ?? 0) == 0;
  }

  bool get videoOutputMetricsReady {
    return _positive(videoInputBitrateKbps) &&
        _positive(videoInputFps) &&
        _positive(videoDecodedFps) &&
        _positive(videoRenderFps) &&
        _positive(videoRateWindowDurationMs) &&
        _positive(videoLatencyWindowDurationMs) &&
        _positive(videoLatencyTotalSampleCount);
  }

  double? get videoRenderContinuityRatio {
    return _rateRatio(videoRenderFps, videoInputFps);
  }

  bool get videoOutputHealthOk {
    final double? ratio = videoRenderContinuityRatio;
    return videoOutputMetricsReady && ratio != null && ratio >= _minimumVideoRenderContinuityRatio;
  }

  bool get avOutputHealthOk {
    return audioOutputHealthOk && videoOutputHealthOk;
  }

  bool get localLatencyReady {
    return _positive(audioLatencyWindowDurationMs) &&
        _positive(videoLatencyWindowDurationMs) &&
        _positive(audioLatencyTotalSampleCount) &&
        _positive(videoLatencyTotalSampleCount);
  }

  bool get latencyPeriodReady {
    return _positive(audioLatencySessionTotalSampleCount) && _positive(videoLatencySessionTotalSampleCount);
  }

  bool get stutterPeriodReady {
    return sessionStutterRatio != null &&
        sessionStutterTotalMs != null &&
        sessionStutterCount != null &&
        sessionStutterPeakMs != null;
  }

  bool get periodSummaryAvailable {
    return latencyPeriodReady && stutterPeriodReady;
  }

  List<DownlinkMetricsOverlayRow> get overlayRows {
    return <DownlinkMetricsOverlayRow>[
      DownlinkMetricsOverlayRow(
        rowKey: 'media_params',
        widgetKey: DemoWidgetKeys.downlinkMetricsMediaParamsText,
        label: '媒体参数',
        value: '$displayVideoSize · $displayVideoCodec · $displayAudioCodec · $displayVideoDecoder',
      ),
      DownlinkMetricsOverlayRow(
        rowKey: 'video_receive',
        widgetKey: DemoWidgetKeys.downlinkMetricsVideoReceiveText,
        label: '视频接收',
        value: '码率 ${_formatKbps(videoInputBitrateKbps)} · '
            '接收 ${_formatFps(videoInputFps)}',
      ),
      DownlinkMetricsOverlayRow(
        rowKey: 'audio_receive',
        widgetKey: DemoWidgetKeys.downlinkMetricsAudioReceiveText,
        label: '音频接收',
        value: '码率 ${_formatKbps(audioInputBitrateKbps)} · '
            'PPS ${_formatPerSecond(audioInputPacketRate)}',
      ),
      DownlinkMetricsOverlayRow(
        rowKey: 'latency_stats',
        widgetKey: DemoWidgetKeys.downlinkMetricsLatencyStatsText,
        label: '缓冲长度',
        value:
            '视频 ${_formatLatencyDuration(videoLatencyBufferAverageMs, sampleCount: videoLatencyBufferSampleCount)} · '
            '音频 ${_formatLatencyDuration(audioLatencyBufferAverageMs, sampleCount: audioLatencyBufferSampleCount)}',
        periodTextPresent: true,
        periodAvailable: latencyPeriodReady,
        unavailableReason: latencyPeriodReady ? null : 'latency_session_samples_unavailable',
      ),
      DownlinkMetricsOverlayRow(
        rowKey: 'startup',
        widgetKey: DemoWidgetKeys.downlinkMetricsStartupText,
        label: '启动耗时',
        value: _formatStartup(connectDurationMs, firstFrameDurationMs),
      ),
      DownlinkMetricsOverlayRow(
        rowKey: 'stutter',
        widgetKey: DemoWidgetKeys.downlinkMetricsStutterText,
        label: '卡顿统计',
        value: '视频 ${_formatCount(sessionStutterCount)} / 最长 ${_formatDuration(sessionStutterPeakMs)} · '
            '音频最近 ${_formatCount(audioRecentStutterCount)} / 最长 ${_formatDuration(audioRecentStutterPeakMs)}',
        periodTextPresent: true,
        periodAvailable: stutterPeriodReady,
        unavailableReason: stutterPeriodReady ? null : 'stutter_session_unavailable',
      ),
    ];
  }

  List<Map<String, Object?>> snapshotRowsPayload() {
    return overlayRows
        .map(
          (DownlinkMetricsOverlayRow row) => <String, Object?>{
            'key': row.rowKey,
            'text': row.text,
            'present': true,
            'period_text_present': row.periodTextPresent,
          },
        )
        .toList(growable: false);
  }

  Map<String, Object?> periodSummaryPayload() {
    final List<DownlinkMetricsOverlayRow> periodRows =
        overlayRows.where((DownlinkMetricsOverlayRow row) => row.periodTextPresent).toList(growable: false);
    return <String, Object?>{
      'available': periodSummaryAvailable,
      'source': 'ui_text_period_summary',
      'rows': periodRows
          .map(
            (DownlinkMetricsOverlayRow row) => <String, Object?>{
              'key': row.rowKey,
              'text': row.text,
              'available': row.periodAvailable,
              'unavailable_reason': row.periodAvailable ? null : row.unavailableReason,
            },
          )
          .toList(growable: false),
    };
  }

  static bool _isKnownVideoCodec(int? codec) {
    return codec == _mediaCodecVideoH264 || codec == _mediaCodecVideoH265 || codec == _mediaCodecVideoMjpeg;
  }

  static bool _isKnownAudioCodec(int? codec) {
    return codec == _mediaCodecAudioG711A ||
        codec == _mediaCodecAudioAac ||
        codec == _mediaCodecAudioPcm ||
        codec == _mediaCodecAudioOpus ||
        codec == _mediaCodecAudioAmr;
  }

  static bool _isKnownAudioSampleRate(int? sampleRate) {
    return sampleRate == 8000 || sampleRate == 16000;
  }

  static bool _isKnownAudioChannels(int? channels) {
    return channels == 1 || channels == 2;
  }

  static bool _isResolvedDecoderBackend(int? backend) {
    return backend == _videoDecoderBackendHardware || backend == _videoDecoderBackendSoftware;
  }

  static bool _positive(num? value) {
    return value != null && value > 0;
  }

  static double? _rateRatio(double? numerator, double? denominator) {
    if (!_positive(numerator) || !_positive(denominator)) {
      return null;
    }
    return numerator! / denominator!;
  }
}

final class DownlinkMetricsOverlayRow {
  const DownlinkMetricsOverlayRow({
    required this.rowKey,
    required this.widgetKey,
    required this.label,
    required this.value,
    this.periodTextPresent = false,
    this.periodAvailable = false,
    this.unavailableReason,
  });

  final String rowKey;
  final ValueKey<String> widgetKey;
  final String label;
  final String value;
  final bool periodTextPresent;
  final bool periodAvailable;
  final String? unavailableReason;

  String get text => '$label：$value';
}

String _formatDuration(int? durationMs) {
  if (durationMs == null || durationMs < 0) {
    return '--';
  }
  return '$durationMs ms';
}

String _formatKbps(double? value) {
  if (value == null || value.isNaN || value.isInfinite || value <= 0) {
    return '--';
  }
  return '${value.toStringAsFixed(value >= 100 ? 0 : 1)} kbps';
}

String _formatFps(double? value) {
  if (value == null || value.isNaN || value.isInfinite || value <= 0) {
    return '--';
  }
  return '${value.toStringAsFixed(1)} fps';
}

String _formatPerSecond(double? value) {
  if (value == null || value.isNaN || value.isInfinite || value <= 0) {
    return '--';
  }
  return '${value.toStringAsFixed(1)}/s';
}

String _formatCount(int? count) {
  if (count == null || count < 0) {
    return '--';
  }
  return '$count 次';
}

String _formatLatencyDuration(int? value, {required int? sampleCount}) {
  if (sampleCount != null && sampleCount <= 0) {
    return '--';
  }
  if (value == null || value < 0) {
    return '--';
  }
  return '$value ms';
}

String _formatStartup(int? connectDurationMs, int? firstFrameDurationMs) {
  final String connectText = '连接 ${_formatDuration(connectDurationMs)}';
  if (connectDurationMs != null &&
      firstFrameDurationMs != null &&
      connectDurationMs >= 0 &&
      firstFrameDurationMs >= connectDurationMs) {
    return '$connectText · 首帧等待 ${_formatDuration(firstFrameDurationMs - connectDurationMs)}';
  }
  return '$connectText · 首帧总耗时 ${_formatDuration(firstFrameDurationMs)}';
}
