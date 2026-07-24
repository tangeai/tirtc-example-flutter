import 'dart:convert';

import 'package:tirtc_example/src/demo_test_hooks.dart';

const int _markerChunkLength = 480;

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
    _printMarkerEvent(event);
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
    _printMarkerEvent(event);
  }

  void _printMarkerEvent(Map<String, Object?> event) {
    final String raw = jsonEncode(event);
    if (raw.length <= _markerChunkLength) {
      // ignore: avoid_print
      print('TIRTC_FLUTTER_INTEGRATION_MARKER $raw');
      return;
    }

    final int sequence = event['sequence']! as int;
    final int partCount = (raw.length + _markerChunkLength - 1) ~/ _markerChunkLength;
    for (int partIndex = 0; partIndex < partCount; partIndex += 1) {
      final int start = partIndex * _markerChunkLength;
      final int end = start + _markerChunkLength < raw.length ? start + _markerChunkLength : raw.length;
      final Map<String, Object?> part = <String, Object?>{
        'schema_version': 1,
        'run_id': runId,
        'sequence': sequence,
        'part_index': partIndex,
        'part_count': partCount,
        'chunk': raw.substring(start, end),
      };
      // ignore: avoid_print
      print('TIRTC_FLUTTER_INTEGRATION_MARKER_PART ${jsonEncode(part)}');
    }
  }
}
