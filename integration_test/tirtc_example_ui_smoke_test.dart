import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tirtc_av_kit_example/src/app_theme.dart';
import 'package:tirtc_av_kit_example/src/device/device_configure_page.dart';
import 'package:tirtc_av_kit_example/src/device/device_page.dart';
import 'package:tirtc_av_kit_example/src/demo_route_lifecycle.dart';
import 'package:tirtc_av_kit_example/src/demo_test_hooks.dart';
import 'package:tirtc_av_kit_example/src/demo_widget_keys.dart';
import 'package:tirtc_av_kit_example/src/pages/configure_page.dart';
import 'package:tirtc_av_kit_example/src/pages/player_page.dart';
import 'package:tirtc_av_kit_example/src/widgets/downlink_metrics_overlay.dart';

import 'src/example_smoke_marker_sink.dart';
import 'src/example_smoke_payload.dart';

const Duration _smokeActionDelay = Duration(seconds: 3);
const Duration _smokeConfigurePageObservationDelay = Duration(seconds: 30);
const Duration _smokeLogUploadTimeout = Duration(seconds: 180);
const Duration _smokePageTimeout = Duration(seconds: 30);
const Duration _smokePollInterval = Duration(milliseconds: 250);
const Duration _smokeReturnStabilityDelay = Duration(seconds: 5);

void main() {
  final IntegrationTestWidgetsFlutterBinding binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('public example downlink UI smoke', (WidgetTester tester) async {
    final ExampleSmokePayload payload = ExampleSmokePayload.fromEnvironment();
    final ExampleSmokeMarkerSink markers = ExampleSmokeMarkerSink(runId: payload.runId);
    DemoExampleSmokeHooks.current = DemoExampleSmokeHooks(
      markerSink: markers,
      renderWindowSeconds: payload.renderWindowSeconds,
    );

    try {
      await tester.pumpWidget(
        MaterialApp(
          title: 'Ti RTC Example Smoke',
          debugShowCheckedModeBanner: false,
          theme: ExampleTheme.build(),
          navigatorObservers: <NavigatorObserver>[exampleRouteObserver],
          home: const DemoConfigurePage(),
        ),
      );
      await tester.pumpAndSettle();
      markers.passed('smoke_payload_applied', payload: <String, Object?>{
        'flow': payload.flow,
        'app_id_present': payload.appId.isNotEmpty,
        'remote_id': payload.remoteId,
        'audio_stream_id': payload.audioStreamId,
        'video_stream_id': payload.videoStreamId,
        'render_window_seconds': payload.renderWindowSeconds,
      });

      if (payload.flow == 'device_server_ui') {
        await _observeInitialConfigurePage(tester, markers, payload.flow);
        await _runDeviceServerFlow(tester, markers, payload);
        return;
      }

      await _observeInitialConfigurePage(tester, markers, payload.flow);
      await _runDownlinkFlow(tester, markers, payload);
    } finally {
      DemoExampleSmokeHooks.current = null;
    }
  });
}

Future<void> _runDownlinkFlow(
  WidgetTester tester,
  ExampleSmokeMarkerSink markers,
  ExampleSmokePayload payload,
) async {
  await _enterSmokeText(tester, find.byKey(DemoWidgetKeys.appIdField), payload.appId);
  await _enterSmokeText(tester, find.byKey(DemoWidgetKeys.endpointField), payload.endpoint);
  await _enterSmokeText(tester, find.byKey(DemoWidgetKeys.remoteIdField), payload.remoteId);
  await _enterSmokeText(tester, find.byKey(DemoWidgetKeys.audioStreamIdField), payload.audioStreamId.toString());
  await _enterSmokeText(tester, find.byKey(DemoWidgetKeys.videoStreamIdField), payload.videoStreamId.toString());
  await _enterSmokeText(tester, find.byKey(DemoWidgetKeys.tokenField), payload.token);
  await _observe(
    tester,
    markers,
    'smoke_public_form_populated',
    payload: <String, Object?>{'flow': payload.flow},
  );

  await _pumpUntilEnabled(tester, find.byKey(DemoWidgetKeys.startDownlinkButton));
  await _tapAndObserve(
    tester,
    markers,
    find.byKey(DemoWidgetKeys.startDownlinkButton),
    marker: 'smoke_public_submit_tapped',
    flow: payload.flow,
  );
  await _pumpUntilVisible(tester, find.byKey(DemoWidgetKeys.playerPage));
  expect(find.byType(DemoPlayerPage), findsOneWidget);
  await _observe(
    tester,
    markers,
    'smoke_page_visible',
    payload: <String, Object?>{'flow': payload.flow, 'page': 'player'},
  );
  await _pumpUntilVisible(tester, find.byType(DownlinkMetricsOverlay));
  await Future<void>.delayed(Duration(seconds: payload.renderWindowSeconds + 3));
  await tester.pump();
  await _tapAndObserve(
    tester,
    markers,
    find.byKey(DemoWidgetKeys.playerLogUploadButton),
    marker: 'smoke_log_upload_tapped',
    flow: payload.flow,
  );
  await _confirmLogUploadDialog(tester, markers, payload.flow);
  await _returnToConfigurePage(tester, markers, payload.flow);
}

Future<void> _runDeviceServerFlow(
  WidgetTester tester,
  ExampleSmokeMarkerSink markers,
  ExampleSmokePayload payload,
) async {
  await _tapAndObserve(
    tester,
    markers,
    find.byKey(DemoWidgetKeys.openDeviceServerButton),
    marker: 'smoke_open_device_server_tapped',
    flow: payload.flow,
  );
  await _pumpUntilVisible(tester, find.byType(DemoDeviceServerConfigurePage));
  expect(find.byType(DemoDeviceServerConfigurePage), findsOneWidget);

  await _enterSmokeText(tester, find.byKey(DemoWidgetKeys.deviceEndpointField), payload.endpoint);
  await _enterSmokeText(tester, find.byKey(DemoWidgetKeys.deviceIdField), payload.deviceId);
  await _enterSmokeText(tester, find.byKey(DemoWidgetKeys.deviceSecretKeyField), payload.deviceSecretKey);
  await _observe(
    tester,
    markers,
    'smoke_public_form_populated',
    payload: <String, Object?>{'flow': payload.flow},
  );

  await _pumpUntilEnabled(tester, find.byKey(DemoWidgetKeys.startDeviceServerButton));
  await _tapAndObserve(
    tester,
    markers,
    find.byKey(DemoWidgetKeys.startDeviceServerButton),
    marker: 'smoke_public_submit_tapped',
    flow: payload.flow,
  );
  await _pumpUntilVisible(tester, find.byKey(DemoWidgetKeys.deviceServerPage));
  expect(find.byType(DemoDeviceServerPage), findsOneWidget);
  await _observe(
    tester,
    markers,
    'smoke_page_visible',
    payload: <String, Object?>{'flow': payload.flow, 'page': 'device_server'},
  );
  await Future<void>.delayed(Duration(seconds: payload.renderWindowSeconds + 15));
  await tester.pump();
  await _observe(
    tester,
    markers,
    'smoke_public_ui_submitted',
    payload: <String, Object?>{'flow': payload.flow},
  );
}

Future<void> _observeInitialConfigurePage(
  WidgetTester tester,
  ExampleSmokeMarkerSink markers,
  String flow,
) async {
  await _pumpUntilVisible(tester, find.byType(DemoConfigurePage));
  await Future<void>.delayed(_smokeConfigurePageObservationDelay);
  await tester.pump();
  expect(find.byType(DemoConfigurePage), findsOneWidget);
  markers.passed('smoke_configure_page_ready', payload: <String, Object?>{
    'flow': flow,
    'stable_duration_ms': _smokeConfigurePageObservationDelay.inMilliseconds,
  });
}

Future<void> _enterSmokeText(WidgetTester tester, Finder finder, String text) async {
  await tester.ensureVisible(finder);
  await tester.pump(_smokePollInterval);

  final TextFormField field = tester.widget<TextFormField>(finder);
  field.controller?.value = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );
  await tester.pump(_smokePollInterval);

  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(_smokePollInterval);

  expect(field.controller?.text, text);
}

Future<void> _tapAndObserve(
  WidgetTester tester,
  ExampleSmokeMarkerSink markers,
  Finder finder, {
  required String marker,
  required String flow,
}) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
  markers.passed(marker, payload: <String, Object?>{'flow': flow});
  await Future<void>.delayed(_smokeActionDelay);
  await tester.pump();
}

Future<void> _confirmLogUploadDialog(
  WidgetTester tester,
  ExampleSmokeMarkerSink markers,
  String flow,
) async {
  await _pumpUntilVisible(
    tester,
    find.text('日志上传成功'),
    timeout: _smokeLogUploadTimeout,
  );
  markers.passed('smoke_log_upload_dialog_visible', payload: <String, Object?>{'flow': flow});
  await tester.tap(find.text('确定'));
  await tester.pumpAndSettle();
}

Future<void> _returnToConfigurePage(
  WidgetTester tester,
  ExampleSmokeMarkerSink markers,
  String flow,
) async {
  await tester.pageBack();
  await tester.pumpAndSettle();
  await _pumpUntilVisible(tester, find.byType(DemoConfigurePage));
  await Future<void>.delayed(_smokeReturnStabilityDelay);
  await tester.pump();
  expect(find.byType(DemoConfigurePage), findsOneWidget);
  expect(find.byType(DemoPlayerPage), findsNothing);
  markers.passed('smoke_returned_to_configure', payload: <String, Object?>{
    'flow': flow,
    'returned_to_configure': true,
    'stable_duration_ms': _smokeReturnStabilityDelay.inMilliseconds,
  });
}

Future<void> _observe(
  WidgetTester tester,
  ExampleSmokeMarkerSink markers,
  String marker, {
  Map<String, Object?> payload = const <String, Object?>{},
}) async {
  await Future<void>.delayed(_smokeActionDelay);
  await tester.pump();
  markers.passed(marker, payload: payload);
}

Future<void> _pumpUntilVisible(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = _smokePageTimeout,
}) async {
  final DateTime deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(_smokePollInterval);
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    await Future<void>.delayed(_smokePollInterval);
  }
  expect(finder, findsOneWidget);
}

Future<void> _pumpUntilEnabled(WidgetTester tester, Finder finder) async {
  final DateTime deadline = DateTime.now().add(_smokePageTimeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(_smokePollInterval);
    final Iterable<Element> elements = finder.evaluate();
    if (elements.isNotEmpty) {
      final Widget widget = elements.single.widget;
      if (widget is ButtonStyleButton && widget.onPressed != null) {
        return;
      }
    }
    await Future<void>.delayed(_smokePollInterval);
  }
  expect(finder, findsOneWidget);
}
