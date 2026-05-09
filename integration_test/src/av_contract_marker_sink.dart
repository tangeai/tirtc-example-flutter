import 'dart:convert';

import 'package:tirtc_av_kit_example/src/demo_test_hooks.dart';

final class AutomationMarkerSink implements DemoAutomationMarkerSink {
  AutomationMarkerSink({
    required this.runId,
  }) : _startedAt = Stopwatch()..start();

  final String runId;
  final Stopwatch _startedAt;
  int _sequence = 0;

  @override
  void passed(String marker, {Map<String, Object?> payload = const <String, Object?>{}}) {
    _emit(marker: marker, status: 'passed', payload: payload);
  }

  @override
  void failure({
    required String failureStage,
    required String message,
    int? errorCode,
  }) {
    _emit(
      marker: 'failure',
      status: 'failed',
      payload: <String, Object?>{
        'failure_stage': failureStage,
        'error_code': errorCode,
        'message': message,
      },
    );
  }

  void _emit({
    required String marker,
    required String status,
    required Map<String, Object?> payload,
  }) {
    _sequence += 1;
    final Map<String, Object?> event = <String, Object?>{
      'schema_version': 1,
      'run_id': runId,
      'sequence': _sequence,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'elapsed_ms': _startedAt.elapsedMilliseconds,
      'marker': marker,
      'status': status,
      'payload': payload,
    };
    // The self-test script is the only consumer of this stdout marker prefix.
    // TiRtcLogging is intentionally not used before runtime initialization.
    // ignore: avoid_print
    print('TIRTC_FLUTTER_INTEGRATION_MARKER ${jsonEncode(event)}');
  }
}
