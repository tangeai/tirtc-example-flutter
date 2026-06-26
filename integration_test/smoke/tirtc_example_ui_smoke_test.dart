import 'dart:async';

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
import 'package:tirtc_av_kit_example/src/widgets/command_panel_model.dart';
import 'package:tirtc_av_kit_example/src/widgets/downlink_metrics_overlay.dart';

import '../support/example_smoke_marker_sink.dart';
import '../support/example_smoke_payload.dart';

const Duration _smokeActionDelay = Duration(seconds: 3);
const Duration _smokeConfigurePageObservationDelay = Duration(seconds: 30);
const Duration _smokeLocalAudioFirstWindow = Duration(seconds: 10);
const Duration _smokeLocalAudioStopGap = Duration(seconds: 5);
const Duration _smokeLocalAudioSecondWindow = Duration(seconds: 10);
const Duration _smokeLocalAudioMarkerTimeout = Duration(seconds: 30);
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
    final _SmokeFlowMarkerSink markerSink = _SmokeFlowMarkerSink(payload: payload, delegate: markers);
    DemoExampleSmokeHooks.current = DemoExampleSmokeHooks(
      markerSink: markerSink,
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
        'platform': payload.platform,
        'flow': payload.flow,
        'app_id_present': payload.appId.isNotEmpty,
        'remote_id': payload.remoteId,
        'token_source': payload.tokenSource,
        'one_time_token_present': payload.token.isNotEmpty,
        'token_issuer_base_url_present': payload.tokenIssuerBaseUrl.isNotEmpty,
        'audio_stream_id': payload.audioStreamId,
        'local_audio_stream_id': payload.localAudioStreamId,
        'video_stream_id': payload.videoStreamId,
        'render_window_seconds': payload.renderWindowSeconds,
      });

      if (payload.flow == 'device_server_ui') {
        await _observeInitialConfigurePage(tester, markers, payload);
        await _runDeviceServerFlow(tester, markers, payload);
        return;
      }

      await _observeInitialConfigurePage(tester, markers, payload);
      await _runDownlinkFlow(tester, markers, markerSink, payload);
    } finally {
      DemoExampleSmokeHooks.current = null;
    }
  });
}

Future<void> _runDownlinkFlow(
  WidgetTester tester,
  ExampleSmokeMarkerSink markers,
  _SmokeFlowMarkerSink markerSink,
  ExampleSmokePayload payload,
) async {
  await _enterSmokeText(tester, find.byKey(DemoWidgetKeys.appIdField), payload.appId);
  await _enterSmokeText(tester, find.byKey(DemoWidgetKeys.endpointField), payload.endpoint);
  await _enterSmokeText(tester, find.byKey(DemoWidgetKeys.remoteIdField), payload.remoteId);
  await _enterSmokeText(tester, find.byKey(DemoWidgetKeys.audioStreamIdField), payload.audioStreamId.toString());
  await _enterSmokeText(tester, find.byKey(DemoWidgetKeys.videoStreamIdField), payload.videoStreamId.toString());
  await _applyDownlinkTokenSource(tester, payload);
  await _observe(
    tester,
    markers,
    'smoke_public_form_populated',
    payload: <String, Object?>{
      'flow': payload.flow,
      'token_source': payload.tokenSource,
      'one_time_token_present': payload.token.isNotEmpty,
      'token_issuer_base_url_present': payload.tokenIssuerBaseUrl.isNotEmpty,
    },
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
  await _pumpUntilVisible(tester, find.byType(DownlinkMetricsOverlay));
  await _observeStreamMessageBubble(tester);
  await _observe(
    tester,
    markers,
    'smoke_page_visible',
    payload: <String, Object?>{'flow': payload.flow, 'page': 'player'},
  );
  await _runCommandPanelEchoFlow(
    tester,
    markers,
    payload.flow,
    openButton: find.byKey(DemoWidgetKeys.playerCommandButton),
  );
  await _runLocalAudioSmokeFlow(tester, markers, markerSink, payload);
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

Future<void> _observeStreamMessageBubble(
  WidgetTester tester,
) async {
  await _pumpUntilVisible(
    tester,
    find.byKey(DemoWidgetKeys.streamMessageBubble),
    timeout: const Duration(seconds: 20),
  );
}

final class _SmokeFlowMarkerSink implements DemoAutomationMarkerSink {
  _SmokeFlowMarkerSink({
    required this.payload,
    required this.delegate,
  });

  final ExampleSmokePayload payload;
  final ExampleSmokeMarkerSink delegate;
  bool _bubbleVisibleMarked = false;
  bool _streamMessageSentMarked = false;
  final Set<String> _seenMarkers = <String>{};
  final Map<String, int> _markerCounts = <String, int>{};
  final Map<String, Map<String, Object?>> _latestPayloads = <String, Map<String, Object?>>{};
  final Map<String, Completer<void>> _markerCompleters = <String, Completer<void>>{};
  final Map<String, Map<int, Completer<void>>> _markerCountCompleters = <String, Map<int, Completer<void>>>{};

  @override
  void passed(String marker, {Map<String, Object?> payload = const <String, Object?>{}}) {
    delegate.passed(marker, payload: payload);
    _seenMarkers.add(marker);
    _markerCounts[marker] = (_markerCounts[marker] ?? 0) + 1;
    _latestPayloads[marker] = payload;
    final Completer<void>? completer = _markerCompleters[marker];
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
    final Map<int, Completer<void>>? countCompleters = _markerCountCompleters[marker];
    final int count = _markerCounts[marker] ?? 0;
    if (countCompleters != null) {
      for (final MapEntry<int, Completer<void>> entry in countCompleters.entries) {
        if (count >= entry.key && !entry.value.isCompleted) {
          entry.value.complete();
        }
      }
    }
    if (marker == 'stream_message_received') {
      _markBubbleVisible(payload);
    } else if (marker == 'stream_message_sent') {
      _markStreamMessageSent(payload);
    }
  }

  @override
  void failure({
    required String failureStage,
    required String message,
    int? errorCode,
  }) {
    delegate.failure(failureStage: failureStage, message: message, errorCode: errorCode);
  }

  void _markBubbleVisible(Map<String, Object?> eventPayload) {
    if (_bubbleVisibleMarked || payload.flow != 'downlink_ui') {
      return;
    }
    _bubbleVisibleMarked = true;
    final Object? epochSeconds = eventPayload['payload_epoch_seconds'];
    delegate.passed('smoke_stream_message_bubble_visible', payload: <String, Object?>{
      'flow': payload.flow,
      'pairing_id': payload.pairingId,
      'session_index': eventPayload['session_index'] ?? 1,
      'stream_id': eventPayload['stream_id'],
      'payload_epoch_seconds': epochSeconds,
      'payload_bytes': eventPayload['payload_bytes'],
      'payload_hash': eventPayload['payload_hash'],
      'bubble_text': epochSeconds?.toString() ?? '',
      'alignment': 'bottom_right',
      'animation_direction': 'right_to_left',
      'visible': true,
    });
  }

  void _markStreamMessageSent(Map<String, Object?> eventPayload) {
    if (_streamMessageSentMarked || payload.flow != 'device_server_ui') {
      return;
    }
    _streamMessageSentMarked = true;
    delegate.passed('smoke_stream_message_sent', payload: <String, Object?>{
      'flow': payload.flow,
      'pairing_id': payload.pairingId,
      'session_index': eventPayload['session_index'],
      'stream_id': eventPayload['stream_id'],
      'payload_epoch_seconds': eventPayload['payload_epoch_seconds'],
      'payload_bytes': eventPayload['payload_bytes'],
      'payload_hash': eventPayload['payload_hash'],
      'sent_count': eventPayload['sent_count'],
      'periodic_send_ok': eventPayload['periodic_send_ok'],
    });
  }

  Future<void> waitForMarker(String marker, {required Duration timeout}) {
    if (_seenMarkers.contains(marker)) {
      return Future<void>.value();
    }
    final Completer<void> completer = _markerCompleters.putIfAbsent(marker, Completer<void>.new);
    return completer.future.timeout(timeout);
  }

  Future<void> waitForMarkerCount(
    String marker, {
    required int count,
    required Duration timeout,
  }) {
    if ((_markerCounts[marker] ?? 0) >= count) {
      return Future<void>.value();
    }
    final Map<int, Completer<void>> countCompleters =
        _markerCountCompleters.putIfAbsent(marker, () => <int, Completer<void>>{});
    final Completer<void> completer = countCompleters.putIfAbsent(count, Completer<void>.new);
    return completer.future.timeout(timeout);
  }

  int markerCount(String marker) => _markerCounts[marker] ?? 0;

  Map<String, Object?> latestPayload(String marker) => _latestPayloads[marker] ?? const <String, Object?>{};
}

Future<void> _runLocalAudioSmokeFlow(
  WidgetTester tester,
  ExampleSmokeMarkerSink markers,
  _SmokeFlowMarkerSink markerSink,
  ExampleSmokePayload payload,
) async {
  final Finder button = find.byKey(DemoWidgetKeys.playerLocalAudioButton);
  await _pumpUntilEnabled(tester, button);
  await tester.tap(button);
  await tester.pump();
  await markerSink.waitForMarkerCount(
    'local_audio_input_started',
    count: 1,
    timeout: _smokeLocalAudioMarkerTimeout,
  );

  await Future<void>.delayed(_smokeLocalAudioFirstWindow);
  await tester.pump();
  await tester.tap(button);
  await tester.pump();
  await markerSink.waitForMarkerCount(
    'local_audio_input_stopped',
    count: 1,
    timeout: _smokeLocalAudioMarkerTimeout,
  );

  await Future<void>.delayed(_smokeLocalAudioStopGap);
  await tester.pump();
  await tester.tap(button);
  await tester.pump();
  await markerSink.waitForMarkerCount(
    'local_audio_input_started',
    count: 2,
    timeout: _smokeLocalAudioMarkerTimeout,
  );

  await Future<void>.delayed(_smokeLocalAudioSecondWindow);
  await tester.pump();
  await tester.tap(button);
  await tester.pump();
  await markerSink.waitForMarkerCount(
    'local_audio_input_stopped',
    count: 2,
    timeout: _smokeLocalAudioMarkerTimeout,
  );

  markers.passed('smoke_local_audio_cycle_completed', payload: <String, Object?>{
    'flow': payload.flow,
    'stream_id': payload.localAudioStreamId,
    'start_count': markerSink.markerCount('local_audio_input_started'),
    'stop_count': markerSink.markerCount('local_audio_input_stopped'),
    'attach_count': markerSink.markerCount('local_audio_input_attached'),
    'binding_reused': markerSink.latestPayload('local_audio_input_started')['reused_binding'] == true,
    'first_start_window_ms': _smokeLocalAudioFirstWindow.inMilliseconds,
    'stop_gap_ms': _smokeLocalAudioStopGap.inMilliseconds,
    'second_start_window_ms': _smokeLocalAudioSecondWindow.inMilliseconds,
  });
}

Future<void> _runCommandPanelEchoFlow(
  WidgetTester tester,
  ExampleSmokeMarkerSink markers,
  String flow, {
  required Finder openButton,
}) async {
  await _tapAndObserve(
    tester,
    markers,
    openButton,
    marker: 'smoke_command_panel_open_tapped',
    flow: flow,
  );
  await _pumpUntilVisible(tester, find.byKey(DemoWidgetKeys.commandPanelSheet));
  markers.passed('smoke_command_panel_visible', payload: <String, Object?>{'flow': flow});

  await tester.tap(find.byKey(DemoWidgetKeys.commandPanelEchoPreset));
  await tester.pump();
  markers.passed('smoke_command_preset_applied', payload: <String, Object?>{
    'flow': flow,
    'command_id': demoCommandEchoPresetId,
    'payload_text': demoCommandEchoPresetPayload,
    'payload_bytes': demoCommandEchoPresetPayload.length,
  });

  await _pumpUntilEnabled(tester, find.byKey(DemoWidgetKeys.commandPanelSendButton));
  await _tapAndObserve(
    tester,
    markers,
    find.byKey(DemoWidgetKeys.commandPanelSendButton),
    marker: 'smoke_command_send_tapped',
    flow: flow,
  );
  await _pumpUntilVisible(
    tester,
    find.byKey(DemoWidgetKeys.commandPanelEvent('received', formatDemoCommandId(demoCommandEchoPresetId))),
  );
  markers.passed('smoke_command_echo_received', payload: <String, Object?>{
    'flow': flow,
    'command_id': demoCommandEchoPresetId,
    'payload_text': demoCommandEchoPresetPayload,
    'payload_bytes': demoCommandEchoPresetPayload.length,
  });

  await tester.tap(find.byKey(DemoWidgetKeys.commandPanelCloseButton));
  await tester.pumpAndSettle();
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
  await _runCommandPanelEchoFlow(
    tester,
    markers,
    payload.flow,
    openButton: find.byKey(DemoWidgetKeys.deviceServerCommandButton),
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
  ExampleSmokePayload payload,
) async {
  await _pumpUntilVisible(tester, find.byType(DemoConfigurePage));
  final Duration observationDelay = payload.platform == 'ios' ? _smokeConfigurePageObservationDelay : Duration.zero;
  if (observationDelay > Duration.zero) {
    await Future<void>.delayed(observationDelay);
  }
  await tester.pump();
  expect(find.byType(DemoConfigurePage), findsOneWidget);
  expect(find.text('连接 Token'), findsOneWidget);
  expect(find.text('Token 签发服务地址'), findsWidgets);
  expect(find.text('一次性连接 Token'), findsWidgets);
  expect(find.text('token_issuer_base_url'), findsNothing);
  markers.passed('smoke_configure_page_ready', payload: <String, Object?>{
    'flow': payload.flow,
    'platform': payload.platform,
    'stable_duration_ms': observationDelay.inMilliseconds,
  });
}

Future<void> _applyDownlinkTokenSource(
  WidgetTester tester,
  ExampleSmokePayload payload,
) async {
  switch (payload.tokenSource) {
    case exampleSmokeTokenSourceIssuer:
      await _selectTokenSource(tester, find.byKey(DemoWidgetKeys.tokenSourceIssuerButton));
      await _enterSmokeText(tester, find.byKey(DemoWidgetKeys.tokenIssuerBaseUrlField), payload.tokenIssuerBaseUrl);
    case exampleSmokeTokenSourceOneTime:
      await _selectTokenSource(tester, find.byKey(DemoWidgetKeys.tokenSourceOneTimeButton));
      await _enterSmokeText(tester, find.byKey(DemoWidgetKeys.tokenField), payload.token);
    default:
      throw StateError('unsupported smoke token source ${payload.tokenSource}');
  }
}

Future<void> _selectTokenSource(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
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
