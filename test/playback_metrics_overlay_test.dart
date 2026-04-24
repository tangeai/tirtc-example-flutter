import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tirtc_av_kit_example/src/widgets/playback_metrics_overlay.dart';

void main() {
  testWidgets('overlay shows session-first metrics and explanation entry', (
    WidgetTester tester,
  ) async {
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaybackMetricsOverlay(
            metrics: const PlaybackMetricsOverlayModel(
              connectDurationMs: 320,
              firstFrameDurationMs: 820,
              sessionStutterRatio: 0.125,
              sessionStutterCount: 6,
              sessionStutterPeakMs: 480,
            ),
            onShowExplanation: () {
              tapped = true;
            },
          ),
        ),
      ),
    );

    expect(find.text('播放调试信息'), findsOneWidget);
    expect(find.text('检测到的卡顿占比'), findsOneWidget);
    expect(find.text('12.5%'), findsOneWidget);
    expect(find.text('检测到的卡顿次数'), findsOneWidget);
    expect(find.text('6 次'), findsOneWidget);
    expect(find.text('检测到的最长卡顿'), findsOneWidget);
    expect(find.text('480 ms'), findsOneWidget);
    expect(find.textContaining('connected 后'), findsNothing);
    expect(find.text('最近窗口卡顿率'), findsNothing);

    await tester.tap(find.text('说明'));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
