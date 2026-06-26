import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tirtc_av_kit_example/src/demo_widget_keys.dart';
import 'package:tirtc_av_kit_example/src/widgets/downlink_metrics_overlay.dart';
import 'package:tirtc_av_kit_example/src/widgets/downlink_metrics_overlay_markers.dart';
import 'package:tirtc_av_kit_example/src/widgets/downlink_metrics_overlay_model.dart';

void main() {
  test('smoke marker payload contains the full local latency contract', () {
    final DownlinkMetricsOverlayModel metrics = _metrics();

    final Map<String, Object?> payload = metrics.smokeRenderWindowMarkerPayload(sessionGeneration: 1);

    expect(payload['audio_local_latency_window_duration_ms'], 5000);
    expect(payload['audio_local_latency_total_average_ms'], 30);
    expect(payload['audio_local_latency_buffer_average_ms'], 28);
    expect(payload['audio_local_latency_decode_or_ready_average_ms'], 1);
    expect(payload['audio_local_latency_output_average_ms'], 1);
    expect(payload['audio_local_latency_total_sample_count'], 125);
    expect(payload['audio_local_latency_buffer_sample_count'], 124);
    expect(payload['audio_local_latency_decode_or_ready_sample_count'], 123);
    expect(payload['audio_local_latency_output_sample_count'], 122);
    expect(payload['audio_local_latency_total_unavailable_count'], 2);
    expect(payload['audio_local_latency_session_duration_ms'], 150000);
    expect(payload['audio_local_latency_session_total_average_ms'], 31);
    expect(payload['audio_local_latency_session_total_min_ms'], 12);
    expect(payload['audio_local_latency_session_total_peak_ms'], 55);
    expect(payload['audio_local_latency_session_total_sample_count'], 2400);
    expect(payload['audio_local_latency_session_total_unavailable_count'], 3);
    expect(payload['audio_input_packet_rate'], 25);
    expect(payload['audio_render_callback_rate'], 25);
    expect(payload['audio_output_continuity_ratio'], 1);
    expect(payload['audio_output_stall_count'], 0);
    expect(payload['audio_output_stall_total_ms'], 0);
    expect(payload['audio_output_stall_peak_ms'], 0);
    expect(payload['audio_output_stall_ratio'], 0);
    expect(payload['audio_output_health_ok'], isTrue);
    expect(payload['video_stutter_session_total_ms'], 0);
    expect(payload['video_stutter_session_count'], 0);
    expect(payload['video_stutter_session_peak_ms'], 0);
    expect(payload['video_stutter_session_ratio'], 0);
    expect(payload['video_local_latency_window_duration_ms'], 5000);
    expect(payload['video_local_latency_total_average_ms'], 94);
    expect(payload['video_local_latency_buffer_average_ms'], 92);
    expect(payload['video_local_latency_decode_or_ready_average_ms'], 2);
    expect(payload['video_local_latency_output_average_ms'], 0);
    expect(payload['video_local_latency_total_sample_count'], 75);
    expect(payload['video_local_latency_buffer_sample_count'], 74);
    expect(payload['video_local_latency_decode_or_ready_sample_count'], 73);
    expect(payload['video_local_latency_output_sample_count'], 72);
    expect(payload['video_local_latency_total_unavailable_count'], 1);
    expect(payload['video_local_latency_session_duration_ms'], 150000);
    expect(payload['video_local_latency_session_total_average_ms'], 96);
    expect(payload['video_local_latency_session_total_min_ms'], 60);
    expect(payload['video_local_latency_session_total_peak_ms'], 140);
    expect(payload['video_local_latency_session_total_sample_count'], 900);
    expect(payload['video_local_latency_session_total_unavailable_count'], 2);
    expect(payload['video_input_fps'], 15);
    expect(payload['video_render_continuity_ratio'], 1);
    expect(payload['video_output_health_ok'], isTrue);
    expect(payload['av_output_health_ok'], isTrue);
    expect(payload['runtime_focus_log'], 'logs/runtime-focus.log');
    expect(payload['local_latency_ok'], isTrue);
    expect(payload['period_summary_available'], isTrue);
    expect(payload['period_summary_required_rows'], <String, Object?>{
      'stutter': true,
      'latency_stats': true,
    });
  });

  test('smoke marker payload uses null averages when samples are unavailable', () {
    final DownlinkMetricsOverlayModel metrics = _metrics(
      audioLatencyTotalSampleCount: 0,
      audioLatencyBufferSampleCount: 0,
      audioLatencyDecodeReadySampleCount: 0,
      audioLatencyOutputSampleCount: 0,
      videoLatencyTotalSampleCount: 0,
      videoLatencyBufferSampleCount: 0,
      videoLatencyDecodeReadySampleCount: 0,
      videoLatencyOutputSampleCount: 0,
    );

    final Map<String, Object?> payload = metrics.smokeRenderWindowMarkerPayload(sessionGeneration: 1);

    expect(payload['audio_local_latency_total_average_ms'], isNull);
    expect(payload['audio_local_latency_buffer_average_ms'], isNull);
    expect(payload['audio_local_latency_decode_or_ready_average_ms'], isNull);
    expect(payload['audio_local_latency_output_average_ms'], isNull);
    expect(payload['video_local_latency_total_average_ms'], isNull);
    expect(payload['video_local_latency_buffer_average_ms'], isNull);
    expect(payload['video_local_latency_decode_or_ready_average_ms'], isNull);
    expect(payload['video_local_latency_output_average_ms'], isNull);
    expect(payload['local_latency_ok'], isFalse);
  });

  test('smoke marker payload uses per-stage sample counts for null averages', () {
    final DownlinkMetricsOverlayModel metrics = _metrics(
      audioLatencyBufferSampleCount: 0,
      audioLatencyDecodeReadySampleCount: 0,
      audioLatencyOutputSampleCount: 0,
    );

    final Map<String, Object?> payload = metrics.smokeRenderWindowMarkerPayload(sessionGeneration: 1);

    expect(payload['audio_local_latency_total_average_ms'], 30);
    expect(payload['audio_local_latency_buffer_average_ms'], isNull);
    expect(payload['audio_local_latency_decode_or_ready_average_ms'], isNull);
    expect(payload['audio_local_latency_output_average_ms'], isNull);
    expect(payload['local_latency_ok'], isTrue);
  });

  test('debug marker payload accepts new audio codec display names', () {
    final DownlinkMetricsOverlayModel metrics = _metrics(audioCodec: 4);

    final Map<String, Object?> payload = metrics.debugMarkerPayload(sessionGeneration: 1);

    expect(metrics.debugStatsReady, isTrue);
    expect(payload['display_audio_codec'], 'OPUS');
  });

  test('audio output health is independent from video stutter', () {
    final DownlinkMetricsOverlayModel metrics = _metrics(audioRecentStutterCount: 3);

    final Map<String, Object?> payload = metrics.smokeRenderWindowMarkerPayload(sessionGeneration: 1);

    expect(metrics.sessionStutterRatio, 0);
    expect(metrics.audioOutputContinuityRatio, 1);
    expect(metrics.audioOutputHealthOk, isFalse);
    expect(metrics.videoOutputHealthOk, isTrue);
    expect(metrics.avOutputHealthOk, isFalse);
    expect(payload['audio_output_health_ok'], isFalse);
    expect(payload['av_output_health_ok'], isFalse);
  });

  testWidgets('overlay defaults to compact expanded rows and can collapse', (WidgetTester tester) async {
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

    expect(find.byKey(DemoWidgetKeys.downlinkMetricsStatsPanel), findsOneWidget);
    expect(find.byKey(DemoWidgetKeys.downlinkMetricsStatsCollapseAction), findsOneWidget);
    expect(find.byKey(DemoWidgetKeys.downlinkMetricsStatsExpandAction), findsNothing);
    expect(find.byKey(DemoWidgetKeys.downlinkMetricsMediaParamsText), findsOneWidget);
    expect(find.byKey(DemoWidgetKeys.downlinkMetricsVideoReceiveText), findsOneWidget);
    expect(find.byKey(DemoWidgetKeys.downlinkMetricsAudioReceiveText), findsOneWidget);
    expect(find.byKey(DemoWidgetKeys.downlinkMetricsLatencyStatsText), findsOneWidget);
    expect(find.byKey(DemoWidgetKeys.downlinkMetricsStartupText), findsOneWidget);
    expect(find.byKey(DemoWidgetKeys.downlinkMetricsStutterText), findsOneWidget);
    expect(find.text('播放调试信息'), findsNothing);
    expect(find.textContaining('媒体参数：1280x720 · H264 · G711A · 硬解'), findsOneWidget);
    expect(find.textContaining('视频接收：码率 1245 kbps · 接收 15.0 fps'), findsOneWidget);
    expect(find.textContaining('音频接收：码率 64.0 kbps · PPS 25.0/s'), findsOneWidget);
    expect(find.textContaining('缓冲长度：视频 92 ms · 音频 28 ms'), findsOneWidget);
    expect(find.textContaining('启动耗时：连接 219 ms · 首帧等待 115 ms'), findsOneWidget);
    expect(find.textContaining('卡顿统计'), findsOneWidget);
    expect(find.textContaining('视频 0 次 / 最长 0 ms · 音频最近 0 次 / 最长 0 ms'), findsOneWidget);
    expect(find.textContaining('解码'), findsNothing);
    expect(find.textContaining('渲染'), findsNothing);

    await tester.tap(find.byKey(DemoWidgetKeys.downlinkMetricsStatsCollapseAction));
    await tester.pumpAndSettle();

    expect(find.byKey(DemoWidgetKeys.downlinkMetricsStatsPanel), findsNothing);
    expect(find.byKey(DemoWidgetKeys.downlinkMetricsStatsExpandAction), findsOneWidget);
    expect(find.text('即时统计'), findsOneWidget);

    await tester.tap(find.byKey(DemoWidgetKeys.downlinkMetricsStatsExpandAction));
    await tester.pumpAndSettle();

    expect(find.byKey(DemoWidgetKeys.downlinkMetricsStatsPanel), findsOneWidget);
  });

  testWidgets('overlay panel is centered within a wide parent', (WidgetTester tester) async {
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
    final Rect panelRect = tester.getRect(find.byKey(DemoWidgetKeys.downlinkMetricsStatsPanel));

    expect(panelRect.width, lessThanOrEqualTo(430));
    expect((panelRect.center.dx - hostRect.center.dx).abs(), lessThan(0.5));

    await tester.tap(find.byKey(DemoWidgetKeys.downlinkMetricsStatsCollapseAction));
    await tester.pumpAndSettle();

    final Rect pillRect = tester.getRect(find.byKey(DemoWidgetKeys.downlinkMetricsStatsExpandAction));

    expect((pillRect.center.dx - hostRect.center.dx).abs(), lessThan(0.5));
  });

  testWidgets('overlay keeps audio latency readable when video has no samples', (WidgetTester tester) async {
    final DownlinkMetricsOverlayModel metrics = _metrics(
      videoLatencyTotalSampleCount: 0,
      videoLatencyBufferSampleCount: 0,
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

    expect(find.textContaining('缓冲长度'), findsOneWidget);
    expect(find.textContaining('--'), findsOneWidget);
    expect(find.textContaining('音频 28 ms'), findsOneWidget);
    expect(find.textContaining('解码就绪'), findsNothing);
    expect(find.textContaining('交给音频输出'), findsNothing);
  });

  testWidgets('overlay shows audio stall risk separately', (WidgetTester tester) async {
    final DownlinkMetricsOverlayModel metrics = _metrics(
      audioRecentStutterCount: 3,
      audioRecentStutterTotalMs: 120,
      audioRecentStutterPeakMs: 80,
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
    expect(find.textContaining('音频最近 3 次 / 最长 80 ms'), findsOneWidget);
    expect(find.textContaining('断续风险'), findsNothing);
  });
}

DownlinkMetricsOverlayModel _metrics({
  int audioLatencyTotalSampleCount = 125,
  int audioLatencyBufferSampleCount = 124,
  int audioLatencyDecodeReadySampleCount = 123,
  int audioLatencyOutputSampleCount = 122,
  int videoLatencyTotalSampleCount = 75,
  int videoLatencyBufferSampleCount = 74,
  int videoLatencyDecodeReadySampleCount = 73,
  int videoLatencyOutputSampleCount = 72,
  double audioInputPacketRate = 25,
  double audioRenderCallbackRate = 25,
  int audioRecentStutterCount = 0,
  int audioRecentStutterTotalMs = 0,
  int audioRecentStutterPeakMs = 0,
  int audioLatencySessionTotalSampleCount = 2400,
  int videoLatencySessionTotalSampleCount = 900,
  double videoInputFps = 15,
  double videoRenderFps = 15,
  int audioCodec = 1,
}) {
  return DownlinkMetricsOverlayModel(
    connectDurationMs: 219,
    firstFrameDurationMs: 334,
    sessionStutterRatio: 0,
    sessionStutterTotalMs: 0,
    sessionStutterCount: 0,
    sessionStutterPeakMs: 0,
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
    audioRecentStutterRatio: audioRecentStutterTotalMs / 5000,
    audioRecentStutterCount: audioRecentStutterCount,
    audioRecentStutterTotalMs: audioRecentStutterTotalMs,
    audioRecentStutterPeakMs: audioRecentStutterPeakMs,
    audioRateWindowDurationMs: 5000,
    audioLatencyWindowDurationMs: 5000,
    audioLatencyTotalAverageMs: 30,
    audioLatencyBufferAverageMs: 28,
    audioLatencyDecodeReadyAverageMs: 1,
    audioLatencyOutputAverageMs: 1,
    audioLatencyTotalSampleCount: audioLatencyTotalSampleCount,
    audioLatencyBufferSampleCount: audioLatencyBufferSampleCount,
    audioLatencyDecodeReadySampleCount: audioLatencyDecodeReadySampleCount,
    audioLatencyOutputSampleCount: audioLatencyOutputSampleCount,
    audioLatencyTotalUnavailableCount: 2,
    audioLatencySessionDurationMs: 150000,
    audioLatencySessionTotalAverageMs: 31,
    audioLatencySessionTotalMinMs: 12,
    audioLatencySessionTotalPeakMs: 55,
    audioLatencySessionTotalSampleCount: audioLatencySessionTotalSampleCount,
    audioLatencySessionTotalUnavailableCount: 3,
    videoInputBitrateKbps: 1245,
    videoInputFps: videoInputFps,
    videoDecodedFps: 15,
    videoRenderFps: videoRenderFps,
    videoRateWindowDurationMs: 5000,
    videoLatencyWindowDurationMs: 5000,
    videoLatencyTotalAverageMs: 94,
    videoLatencyBufferAverageMs: 92,
    videoLatencyDecodeReadyAverageMs: 2,
    videoLatencyOutputAverageMs: 0,
    videoLatencyTotalSampleCount: videoLatencyTotalSampleCount,
    videoLatencyBufferSampleCount: videoLatencyBufferSampleCount,
    videoLatencyDecodeReadySampleCount: videoLatencyDecodeReadySampleCount,
    videoLatencyOutputSampleCount: videoLatencyOutputSampleCount,
    videoLatencyTotalUnavailableCount: 1,
    videoLatencySessionDurationMs: 150000,
    videoLatencySessionTotalAverageMs: 96,
    videoLatencySessionTotalMinMs: 60,
    videoLatencySessionTotalPeakMs: 140,
    videoLatencySessionTotalSampleCount: videoLatencySessionTotalSampleCount,
    videoLatencySessionTotalUnavailableCount: 2,
  );
}
