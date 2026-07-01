import 'dart:io';

import 'package:tirtc_av_kit_example/src/widgets/downlink_metrics_overlay_model.dart';

import 'av_contract_payload.dart';

Map<String, Object?> avContractFinalMetricsSnapshotPayload({
  required AutomationPayload payload,
  required DownlinkMetricsOverlayModel metrics,
}) {
  final int warmupSeconds = payload.metricsSessionResetAfterSeconds ?? 0;
  return <String, Object?>{
    'schema_version': 1,
    'run_id': payload.runId,
    'timestamp': DateTime.now().toUtc().toIso8601String(),
    'elapsed_ms': payload.renderWindowSeconds * 1000,
    'source': 'ui_text_final_snapshot',
    'platform': Platform.operatingSystem,
    'measurement': <String, Object?>{
      'warmup_seconds': warmupSeconds,
      'duration_seconds': payload.renderWindowSeconds,
      'measurement_duration_seconds': payload.renderWindowSeconds - warmupSeconds,
      'final_snapshot_elapsed_ms': payload.renderWindowSeconds * 1000,
    },
    'rows': metrics.snapshotRowsPayload(),
    'period_summary': metrics.periodSummaryPayload(),
  };
}
