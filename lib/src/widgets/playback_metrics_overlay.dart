import 'package:flutter/material.dart';

import '../app_theme.dart';

class PlaybackMetricsOverlayModel {
  const PlaybackMetricsOverlayModel({
    required this.connectDurationMs,
    required this.firstFrameDurationMs,
    required this.sessionStutterRatio,
    required this.sessionStutterCount,
    required this.sessionStutterPeakMs,
  });

  final int? connectDurationMs;
  final int? firstFrameDurationMs;
  final double? sessionStutterRatio;
  final int? sessionStutterCount;
  final int? sessionStutterPeakMs;
}

class PlaybackMetricsOverlay extends StatelessWidget {
  const PlaybackMetricsOverlay({
    super.key,
    required this.metrics,
    required this.onShowExplanation,
  });

  final PlaybackMetricsOverlayModel metrics;
  final VoidCallback onShowExplanation;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: false,
      child: Container(
        width: 232,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(214),
          borderRadius: BorderRadius.circular(14),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withAlpha(44),
              blurRadius: 18,
              offset: const Offset(0, 8),
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
                color: ExampleTheme.primary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 8),
            _MetricLine(
              label: '连接耗时',
              value: _formatDuration(metrics.connectDurationMs),
            ),
            _MetricLine(
              label: '首帧耗时',
              value: _formatDuration(metrics.firstFrameDurationMs),
            ),
            _MetricLine(
              label: '检测到的卡顿占比',
              value: _formatRatio(metrics.sessionStutterRatio),
            ),
            _MetricLine(
              label: '检测到的卡顿次数',
              value: _formatCount(metrics.sessionStutterCount),
            ),
            _MetricLine(
              label: '检测到的最长卡顿',
              value: _formatDuration(metrics.sessionStutterPeakMs),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onShowExplanation,
                style: TextButton.styleFrom(
                  foregroundColor: ExampleTheme.foreground,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  '说明',
                  style: TextStyle(
                    color: ExampleTheme.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                    decorationColor: ExampleTheme.primary,
                  ),
                ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: ExampleTheme.primary.withAlpha(188),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: ExampleTheme.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
