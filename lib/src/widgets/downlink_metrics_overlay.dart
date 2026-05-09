import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../demo_configuration.dart';

const int _mediaCodecAudioG711A = 1;
const int _mediaCodecVideoH264 = 65;
const int _mediaCodecVideoH265 = 66;
const int _mediaCodecVideoMjpeg = 67;
const int _videoDecoderBackendSoftware = 1;
const int _videoDecoderBackendHardware = 2;

const String downlinkMetricsExplanationContent = '【连接耗时】：从点击开始连接，到 runtime 确认连接成功的时间。'
    '只表示连接建立用了多久，不表示画面已经出来。\n\n'
    '【首帧耗时】：从点击开始连接，到第一个视频帧真正显示成功的时间。'
    '这里按 SDK 的“视频帧渲染成功”记录，不按收到数据、解码完成或提交渲染来算。\n\n'
    '【什么时候开始统计卡顿】：第一个视频帧真正显示成功后，才开始统计本次播放的卡顿。'
    '连接中、等首帧、页面看不见、画面承载区域不可用、停止播放后的空窗，都不算卡顿。\n\n'
    '【如何定义一次卡顿】：播放已经开始后，SDK 会观察视频帧成功显示的间隔。'
    '先用最近几次正常显示的帧间隔估出“正常一帧应该隔多久”。'
    '如果下一帧的显示间隔超过这个正常间隔的 3 倍，超过 3 倍的多出来时间才记为卡顿。'
    '连续的一段停顿算 1 次；恢复显示后，如果后面又停住，再算下一次。\n\n'
    '【本次播放卡顿占比】：从开始播放到现在，累计卡顿时长占本次播放已持续时长的比例。'
    '例如已经播放 60 秒，其中累计有 3 秒被记为卡顿，占比就是 5%。'
    '如果当前正在卡，已经发生的那部分也会立刻算进去，不会等恢复后才显示。\n\n'
    '【本次播放卡顿次数】：从开始播放到现在，累计发生过多少段卡顿。'
    '连续停住又恢复，算 1 次；恢复后再次停住，才算新的一次。\n\n'
    '【本次播放最长卡顿】：本次播放里，单次卡顿中被计入的最长时长。'
    '它用于判断最严重的一次停顿有多长。\n\n'
    '【码率 / 速率】：码率、接收 FPS、解码 FPS、渲染 FPS 和音频包率来自 runtime 最近一个已闭合 5 秒窗口。'
    '渲染 FPS 表示 runtime 视频输出成功次数；接收 FPS 表示下行编码帧被 accepted 的速率，不等于屏幕刷新率。';

class DownlinkMetricsOverlayModel {
  const DownlinkMetricsOverlayModel({
    required this.connectDurationMs,
    required this.firstFrameDurationMs,
    required this.sessionStutterRatio,
    required this.sessionStutterCount,
    required this.sessionStutterPeakMs,
    required this.videoWidth,
    required this.videoHeight,
    required this.videoCodec,
    required this.audioCodec,
    required this.requestedDecoderPreference,
    required this.resolvedDecoderBackend,
    required this.audioInputBitrateKbps,
    required this.audioInputPacketRate,
    required this.audioRenderCallbackRate,
    required this.audioRateWindowDurationMs,
    required this.videoInputBitrateKbps,
    required this.videoInputFps,
    required this.videoDecodedFps,
    required this.videoRenderFps,
    required this.videoRateWindowDurationMs,
  });

  final int? connectDurationMs;
  final int? firstFrameDurationMs;
  final double? sessionStutterRatio;
  final int? sessionStutterCount;
  final int? sessionStutterPeakMs;
  final int? videoWidth;
  final int? videoHeight;
  final int? videoCodec;
  final int? audioCodec;
  final int requestedDecoderPreference;
  final int? resolvedDecoderBackend;
  final double? audioInputBitrateKbps;
  final double? audioInputPacketRate;
  final double? audioRenderCallbackRate;
  final int? audioRateWindowDurationMs;
  final double? videoInputBitrateKbps;
  final double? videoInputFps;
  final double? videoDecodedFps;
  final double? videoRenderFps;
  final int? videoRateWindowDurationMs;

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
      _ => '--',
    };
  }

  String get displayVideoDecoder {
    final String suffix = requestedDecoderPreference == DemoExampleSettings.videoDecoderPreferenceAuto ? '（自动）' : '';
    return switch (resolvedDecoderBackend) {
      _videoDecoderBackendHardware => '硬解$suffix',
      _videoDecoderBackendSoftware => '软解$suffix',
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
        audioCodec == _mediaCodecAudioG711A &&
        _isResolvedDecoderBackend(resolvedDecoderBackend);
  }

  bool get avStatsReady {
    return _positive(audioInputBitrateKbps) &&
        _positive(videoInputBitrateKbps) &&
        _positive(videoRenderFps) &&
        _positive(audioRateWindowDurationMs) &&
        _positive(videoRateWindowDurationMs);
  }

  Map<String, Object?> debugMarkerPayload({required int sessionGeneration}) {
    return <String, Object?>{
      'session_generation': sessionGeneration,
      'requested_decoder_preference': requestedDecoderPreference,
      'video_width': videoWidth,
      'video_height': videoHeight,
      'video_codec': videoCodec,
      'audio_codec': audioCodec,
      'resolved_decoder_backend': resolvedDecoderBackend,
      'display_video_size': displayVideoSize,
      'display_video_codec': displayVideoCodec,
      'display_audio_codec': displayAudioCodec,
      'display_video_decoder': displayVideoDecoder,
      'audio_input_bitrate_kbps': audioInputBitrateKbps,
      'audio_input_packet_rate': audioInputPacketRate,
      'audio_render_callback_rate': audioRenderCallbackRate,
      'audio_rate_window_duration_ms': audioRateWindowDurationMs,
      'video_input_bitrate_kbps': videoInputBitrateKbps,
      'video_input_fps': videoInputFps,
      'video_decoded_fps': videoDecodedFps,
      'video_render_fps': videoRenderFps,
      'video_rate_window_duration_ms': videoRateWindowDurationMs,
      'runtime_focus_log': 'logs/runtime-focus.log',
    };
  }

  static bool _isKnownVideoCodec(int? codec) {
    return codec == _mediaCodecVideoH264 || codec == _mediaCodecVideoH265 || codec == _mediaCodecVideoMjpeg;
  }

  static bool _isResolvedDecoderBackend(int? backend) {
    return backend == _videoDecoderBackendHardware || backend == _videoDecoderBackendSoftware;
  }

  static bool _positive(num? value) {
    return value != null && value > 0;
  }
}

class DownlinkMetricsOverlay extends StatelessWidget {
  const DownlinkMetricsOverlay({
    super.key,
    required this.metrics,
    required this.onShowExplanation,
  });

  final DownlinkMetricsOverlayModel metrics;
  final VoidCallback onShowExplanation;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(204),
          borderRadius: BorderRadius.circular(8),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withAlpha(70),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '播放调试信息',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                decoration: TextDecoration.underline,
                decorationColor: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            _MetricLine(
              label: '音视频参数',
              value: '分辨率 ${metrics.displayVideoSize} / 视频 ${metrics.displayVideoCodec} / '
                  '音频 ${metrics.displayAudioCodec} / ${metrics.displayVideoDecoder}',
            ),
            _MetricLine(
              label: '视频接收',
              value: '码率 ${_formatKbps(metrics.videoInputBitrateKbps)} / '
                  '接收 ${_formatRate(metrics.videoInputFps, suffix: '帧/秒')} / '
                  '解码 ${_formatRate(metrics.videoDecodedFps, suffix: '帧/秒')} / '
                  '渲染 ${_formatRate(metrics.videoRenderFps, suffix: '帧/秒')}',
            ),
            _MetricLine(
              label: '音频接收',
              value: '码率 ${_formatKbps(metrics.audioInputBitrateKbps)} / '
                  '音频包 ${_formatRate(metrics.audioInputPacketRate, suffix: '个/秒')} / '
                  '播放输出 ${_formatRate(metrics.audioRenderCallbackRate, suffix: '次/秒')}',
            ),
            _MetricLine(
              label: '连接耗时',
              value: _formatDuration(metrics.connectDurationMs),
            ),
            _MetricLine(
              label: '首帧耗时',
              value: _formatDuration(metrics.firstFrameDurationMs),
            ),
            _MetricLine(
              label: '本次播放卡顿占比',
              value: _formatRatio(metrics.sessionStutterRatio),
            ),
            _MetricLine(
              label: '本次播放卡顿次数',
              value: _formatCount(metrics.sessionStutterCount),
            ),
            _MetricLine(
              label: '本次播放最长卡顿',
              value: _formatDuration(metrics.sessionStutterPeakMs),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: IconButton(
                tooltip: '指标说明',
                onPressed: onShowExplanation,
                style: IconButton.styleFrom(
                  foregroundColor: ExampleTheme.foreground,
                  padding: const EdgeInsets.all(2),
                  minimumSize: const Size.square(24),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.help_outline_rounded, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDuration(int? durationMs) {
    if (durationMs == null || durationMs < 0) {
      return '--';
    }
    return '$durationMs ms';
  }

  static String _formatRatio(double? ratio) {
    if (ratio == null || ratio.isNaN || ratio.isInfinite) {
      return '--';
    }
    return '${(ratio * 100).toStringAsFixed(1)}%';
  }

  static String _formatKbps(double? value) {
    if (value == null || value.isNaN || value.isInfinite || value <= 0) {
      return '--';
    }
    return '${value.toStringAsFixed(value >= 100 ? 0 : 1)} Kbps';
  }

  static String _formatRate(double? value, {required String suffix}) {
    if (value == null || value.isNaN || value.isInfinite || value <= 0) {
      return '--';
    }
    return '${value.toStringAsFixed(1)} $suffix';
  }

  static String _formatCount(int? count) {
    if (count == null || count < 0) {
      return '--';
    }
    return '$count 次';
  }
}

class _MetricLine extends StatelessWidget {
  const _MetricLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '[$label] ',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
