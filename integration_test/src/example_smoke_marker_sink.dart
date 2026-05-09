import 'dart:convert';

import 'package:tirtc_av_kit_example/src/demo_test_hooks.dart';

final class ExampleSmokeMarkerSink implements DemoAutomationMarkerSink {
  ExampleSmokeMarkerSink({required this.runId}) : _startedAt = Stopwatch()..start();

  final String runId;
  final Stopwatch _startedAt;
  int _sequence = 0;

  @override
  void passed(String marker, {Map<String, Object?> payload = const <String, Object?>{}}) {
    _sequence += 1;
    final Map<String, Object?> event = <String, Object?>{
      'schema_version': 1,
      'run_id': runId,
      'sequence': _sequence,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'elapsed_ms': _startedAt.elapsedMilliseconds,
      'marker': marker,
      'status': 'passed',
      'payload': payload,
    };
    // ignore: avoid_print
    print('TIRTC_FLUTTER_INTEGRATION_MARKER ${jsonEncode(event)}');
  }

  @override
  void failure({
    required String failureStage,
    required String message,
    int? errorCode,
  }) {
    _sequence += 1;
    final Map<String, Object?> event = <String, Object?>{
      'schema_version': 1,
      'run_id': runId,
      'sequence': _sequence,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'elapsed_ms': _startedAt.elapsedMilliseconds,
      'marker': 'failure',
      'status': 'failed',
      'payload': <String, Object?>{
        'failure_stage': failureStage,
        'message': message,
        'error_code': errorCode,
      },
    };
    // ignore: avoid_print
    print('TIRTC_FLUTTER_INTEGRATION_MARKER ${jsonEncode(event)}');
  }
}
