import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tirtc_example/src/demo_widget_keys.dart';
import 'package:tirtc_example/src/widgets/downlink_metrics_overlay.dart';
import 'package:tirtc_example/src/widgets/downlink_metrics_overlay_markers.dart';
import 'package:tirtc_example/src/widgets/downlink_metrics_overlay_model.dart';

void main() {
  test('smoke marker payload contains the current metrics contract', () {
    final DownlinkMetricsOverlayModel metrics = _metrics();

    final Map<String, Object?> payload = metrics.smokeRenderWindowMarkerPayload(
      sessionGeneration: 1,
    );

    expect(payload['audio_input_packet_rate'], 25);
    expect(payload['audio_render_callback_rate'], 25);
    expect(payload['audio_output_continuity_ratio'], 1);
    expect(payload['audio_stats_refresh_interval_ms'], 1000);
    expect(payload['audio_stutter_threshold_ms'], 300);
    expect(payload['audio_output_duration_ms'], 150000);
    expect(payload['audio_stutter_total_ms'], 0);
    expect(payload['audio_stutter_count'], 0);
    expect(payload['audio_stutter_peak_ms'], 0);
    expect(payload['audio_stutter_average_ms'], 0);
    expect(payload['audio_stutter_rate'], 0);
    expect(payload['audio_output_health_ok'], isTrue);
    expect(payload['audio_estimated_output_latency_ms'], 58);
    expect(payload['video_stutter_threshold_ms'], 600);
    expect(payload['video_output_duration_ms'], 150000);
    expect(payload['video_stutter_total_ms'], 0);
    expect(payload['video_stutter_count'], 0);
    expect(payload['video_stutter_peak_ms'], 0);
    expect(payload['video_stutter_average_ms'], 0);
    expect(payload['video_stutter_rate'], 0);
    expect(payload['video_estimated_output_latency_ms'], 122);
    expect(payload['video_input_fps'], 15);
    expect(payload['video_render_continuity_ratio'], 1);
    expect(payload['video_output_health_ok'], isTrue);
    expect(payload['av_output_health_ok'], isTrue);
    expect(payload['runtime_focus_log'], 'logs/runtime-focus.log');
    expect(payload['latency_metrics_ok'], isTrue);
    expect(payload['latency_metrics_available'], isTrue);
    expect(payload['period_summary_available'], isTrue);
    expect(payload['period_summary_required_rows'], <String, Object?>{
      'stutter': true,
      'latency_stats': true,
    });
  });

  test(
    'smoke marker payload marks latency unavailable only through the new latency fields',
    () {
      final DownlinkMetricsOverlayModel metrics = _metrics(
        audioEstimatedOutputLatencyMs: -1,
        videoEstimatedOutputLatencyMs: -1,
      );

      final Map<String, Object?> payload = metrics.smokeRenderWindowMarkerPayload(sessionGeneration: 1);

      expect(payload['audio_estimated_output_latency_ms'], -1);
      expect(payload['video_estimated_output_latency_ms'], -1);
      expect(payload['latency_metrics_ok'], isTrue);
      expect(payload['latency_metrics_available'], isFalse);
      expect(payload['audio_output_health_ok'], isTrue);
      expect(payload['video_output_health_ok'], isTrue);
      expect(payload['av_output_health_ok'], isTrue);
      expect(payload['period_summary_available'], isFalse);
    },
  );

  test('debug marker payload accepts new audio codec display names', () {
    final DownlinkMetricsOverlayModel metrics = _metrics(audioCodec: 4);

    final Map<String, Object?> payload = metrics.debugMarkerPayload(
      sessionGeneration: 1,
    );

    expect(metrics.debugStatsReady, isTrue);
    expect(payload['display_audio_codec'], 'OPUS');
  });

  test('audio output health is independent from video stutter', () {
    final DownlinkMetricsOverlayModel metrics = _metrics(audioStutterCount: 3);

    final Map<String, Object?> payload = metrics.smokeRenderWindowMarkerPayload(
      sessionGeneration: 1,
    );

    expect(metrics.videoStutterRate, 0);
    expect(metrics.audioOutputContinuityRatio, 1);
    expect(metrics.audioOutputHealthOk, isFalse);
    expect(metrics.videoOutputHealthOk, isTrue);
    expect(metrics.avOutputHealthOk, isFalse);
    expect(payload['audio_output_health_ok'], isFalse);
    expect(payload['av_output_health_ok'], isFalse);
  });

  testWidgets('overlay defaults to compact expanded rows and can collapse', (
    WidgetTester tester,
  ) async {
    final DownlinkMetricsOverlayModel metrics = _metrics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: DownlinkMetricsOverlay(
              metrics: metrics,
              onShowExplanation: () {},
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(DemoWidgetKeys.downlinkMetricsStatsPanel),
      findsOneWidget,
    );
    expect(
      find.byKey(DemoWidgetKeys.downlinkMetricsStatsCollapseAction),
      findsOneWidget,
    );
    expect(
      find.byKey(DemoWidgetKeys.downlinkMetricsStatsExpandAction),
      findsNothing,
    );
    expect(
      find.byKey(DemoWidgetKeys.downlinkMetricsMediaParamsText),
      findsOneWidget,
    );
    expect(
      find.byKey(DemoWidgetKeys.downlinkMetricsVideoReceiveText),
      findsOneWidget,
    );
    expect(
      find.byKey(DemoWidgetKeys.downlinkMetricsAudioReceiveText),
      findsOneWidget,
    );
    expect(
      find.byKey(DemoWidgetKeys.downlinkMetricsLatencyStatsText),
      findsOneWidget,
    );
    expect(
      find.byKey(DemoWidgetKeys.downlinkMetricsStartupText),
      findsOneWidget,
    );
    expect(
      find.byKey(DemoWidgetKeys.downlinkMetricsStutterText),
      findsOneWidget,
    );
    expect(find.text('播放调试信息'), findsNothing);
    expect(
      find.textContaining('媒体参数：1280x720 · H264 · G711A · 硬解'),
      findsOneWidget,
    );
    expect(
      find.textContaining('视频接收：码率 1245 kbps · 接收 15.0 fps'),
      findsOneWidget,
    );
    expect(
      find.textContaining('音频接收：码率 64.0 kbps · PPS 25.0/s'),
      findsOneWidget,
    );
    expect(find.textContaining('估算延迟：视频 122 ms · 音频 58 ms'), findsOneWidget);
    expect(find.textContaining('启动耗时：连接 219 ms · 首帧等待 115 ms'), findsOneWidget);
    expect(find.textContaining('卡顿统计'), findsOneWidget);
    expect(
      find.textContaining('视频 0 次 / 最长 0 ms · 音频 0 次 / 最长 0 ms'),
      findsOneWidget,
    );
    expect(find.textContaining('解码'), findsNothing);
    expect(find.textContaining('渲染'), findsNothing);

    await tester.tap(
      find.byKey(DemoWidgetKeys.downlinkMetricsStatsCollapseAction),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(DemoWidgetKeys.downlinkMetricsStatsPanel), findsNothing);
    expect(
      find.byKey(DemoWidgetKeys.downlinkMetricsStatsExpandAction),
      findsOneWidget,
    );
    expect(find.text('即时统计'), findsOneWidget);

    await tester.tap(
      find.byKey(DemoWidgetKeys.downlinkMetricsStatsExpandAction),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(DemoWidgetKeys.downlinkMetricsStatsPanel),
      findsOneWidget,
    );
  });

  testWidgets('overlay panel is centered within a wide parent', (
    WidgetTester tester,
  ) async {
    final DownlinkMetricsOverlayModel metrics = _metrics();
    const ValueKey<String> hostKey = ValueKey<String>('metrics-overlay-host');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              key: hostKey,
              width: 800,
              child: DownlinkMetricsOverlay(
                metrics: metrics,
                onShowExplanation: () {},
              ),
            ),
          ),
        ),
      ),
    );

    final Rect hostRect = tester.getRect(find.byKey(hostKey));
    final Rect panelRect = tester.getRect(
      find.byKey(DemoWidgetKeys.downlinkMetricsStatsPanel),
    );

    expect(panelRect.width, lessThanOrEqualTo(430));
    expect((panelRect.center.dx - hostRect.center.dx).abs(), lessThan(0.5));

    await tester.tap(
      find.byKey(DemoWidgetKeys.downlinkMetricsStatsCollapseAction),
    );
    await tester.pumpAndSettle();

    final Rect pillRect = tester.getRect(
      find.byKey(DemoWidgetKeys.downlinkMetricsStatsExpandAction),
    );

    expect((pillRect.center.dx - hostRect.center.dx).abs(), lessThan(0.5));
  });

  testWidgets(
    'overlay keeps audio latency readable when video latency is unavailable',
    (WidgetTester tester) async {
      final DownlinkMetricsOverlayModel metrics = _metrics(
        videoEstimatedOutputLatencyMs: -1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 390,
              child: DownlinkMetricsOverlay(
                metrics: metrics,
                onShowExplanation: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining('估算延迟'), findsOneWidget);
      expect(find.textContaining('--'), findsOneWidget);
      expect(find.textContaining('音频 58 ms'), findsOneWidget);
      expect(find.textContaining('解码就绪'), findsNothing);
      expect(find.textContaining('交给音频输出'), findsNothing);
    },
  );

  testWidgets('overlay shows audio stutter separately', (
    WidgetTester tester,
  ) async {
    final DownlinkMetricsOverlayModel metrics = _metrics(
      audioStutterCount: 3,
      audioStutterTotalMs: 120,
      audioStutterPeakMs: 80,
      audioStutterRate: 0.08,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: DownlinkMetricsOverlay(
              metrics: metrics,
              onShowExplanation: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('卡顿统计'), findsOneWidget);
    expect(find.textContaining('音频 3 次 / 最长 80 ms'), findsOneWidget);
    expect(find.textContaining('断续风险'), findsNothing);
  });
}

DownlinkMetricsOverlayModel _metrics({
  double audioInputPacketRate = 25,
  double audioRenderCallbackRate = 25,
  int audioStutterCount = 0,
  int audioStutterTotalMs = 0,
  int audioStutterPeakMs = 0,
  double audioStutterRate = 0,
  int audioEstimatedOutputLatencyMs = 58,
  int videoEstimatedOutputLatencyMs = 122,
  double videoInputFps = 15,
  double videoRenderFps = 15,
  int audioCodec = 1,
}) {
  return DownlinkMetricsOverlayModel(
    connectDurationMs: 219,
    firstVideoOutputMs: 334,
    firstAudioOutputMs: 301,
    videoWidth: 1280,
    videoHeight: 720,
    videoCodec: 65,
    audioCodec: audioCodec,
    audioSampleRate: 8000,
    audioChannels: 1,
    requestedDecoderPreference: 0,
    resolvedDecoderBackend: 2,
    audioInputBitrateKbps: 64,
    audioInputPacketRate: audioInputPacketRate,
    audioRenderCallbackRate: audioRenderCallbackRate,
    audioStatsRefreshIntervalMs: 1000,
    audioStatsUpdatedAtMs: 10000,
    audioStutterThresholdMs: 300,
    audioOutputDurationMs: 150000,
    audioStutterTotalMs: audioStutterTotalMs,
    audioStutterCount: audioStutterCount,
    audioStutterPeakMs: audioStutterPeakMs,
    audioStutterAverageMs: audioStutterCount == 0 ? 0 : audioStutterTotalMs ~/ audioStutterCount,
    audioStutterRate: audioStutterRate,
    audioEstimatedOutputLatencyMs: audioEstimatedOutputLatencyMs,
    videoInputBitrateKbps: 1245,
    videoInputFps: videoInputFps,
    videoDecodedFps: 15,
    videoRenderFps: videoRenderFps,
    videoStatsRefreshIntervalMs: 1000,
    videoStatsUpdatedAtMs: 10000,
    videoStutterThresholdMs: 600,
    videoOutputDurationMs: 150000,
    videoStutterTotalMs: 0,
    videoStutterCount: 0,
    videoStutterPeakMs: 0,
    videoStutterAverageMs: 0,
    videoStutterRate: 0,
    videoEstimatedOutputLatencyMs: videoEstimatedOutputLatencyMs,
  );
}
