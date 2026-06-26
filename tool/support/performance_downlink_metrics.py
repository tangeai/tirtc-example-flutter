from __future__ import annotations

from typing import Any

EXPECTED_DOWNLINK_VIDEO_FPS = 15.0
MIN_DOWNLINK_VIDEO_FPS_RATIO = 0.8
MIN_DOWNLINK_VIDEO_FPS = EXPECTED_DOWNLINK_VIDEO_FPS * MIN_DOWNLINK_VIDEO_FPS_RATIO
SELF_TEST_CLIENT_FACT_KEYS = (
  "period_summary_available",
  "period_summary_required_rows",
  "video_input_fps",
  "video_render_fps",
  "minimum_downlink_video_fps",
  "video_fps_ok",
)
SELF_TEST_SOURCE_FACT_KEYS = (
  "source_driver_summary_path",
)


def final_snapshot_from_markers(markers: list[dict[str, Any]]) -> dict[str, Any] | None:
  for marker in reversed(markers):
    if marker.get("marker") == "final_metrics_snapshot" and isinstance(marker.get("payload"), dict):
      return marker["payload"]
  return None


def marker_payload(markers: list[dict[str, Any]], name: str) -> dict[str, Any] | None:
  for marker in reversed(markers):
    if marker.get("marker") == name and isinstance(marker.get("payload"), dict):
      return marker["payload"]
  return None


def apply_failure_marker(summary: dict[str, Any], markers: list[dict[str, Any]]) -> bool:
  payload = marker_payload(markers, "failure")
  if payload is None:
    return False
  failure_stage = payload.get("failure_stage")
  summary["run_ok"] = False
  summary["failure_stage"] = failure_stage if isinstance(failure_stage, str) and failure_stage else "client_failure"
  message = payload.get("message")
  if isinstance(message, str) and message:
    summary["failure_message"] = message
  error_code = payload.get("error_code")
  if isinstance(error_code, int) and not isinstance(error_code, bool):
    summary["error_code"] = error_code
  return True


def apply_success_facts(summary: dict[str, Any], snapshot: dict[str, Any], markers: list[dict[str, Any]]) -> None:
  required_rows = _period_required_rows(snapshot)
  period = snapshot.get("period_summary")
  period_available = isinstance(period, dict) and period.get("available") is True
  render_payload = marker_payload(markers, "render_window_completed")
  video_input_fps = render_payload.get("video_input_fps") if isinstance(render_payload, dict) else None
  video_render_fps = render_payload.get("video_render_fps") if isinstance(render_payload, dict) else None
  video_input_fps_ok = (
    isinstance(video_input_fps, (int, float))
    and not isinstance(video_input_fps, bool)
    and video_input_fps >= MIN_DOWNLINK_VIDEO_FPS
  )
  video_render_fps_ok = (
    isinstance(video_render_fps, (int, float))
    and not isinstance(video_render_fps, bool)
    and video_render_fps >= MIN_DOWNLINK_VIDEO_FPS
  )
  log_payload = marker_payload(markers, "log_upload_completed")
  teardown_payload = marker_payload(markers, "teardown_completed")
  summary["period_summary_available"] = period_available
  summary["period_summary_required_rows"] = required_rows
  summary["video_input_fps"] = video_input_fps
  summary["video_render_fps"] = video_render_fps
  summary["minimum_downlink_video_fps"] = MIN_DOWNLINK_VIDEO_FPS
  summary["video_fps_ok"] = video_input_fps_ok and video_render_fps_ok
  summary["log_upload"] = {
    "required": True,
    "status": "passed" if isinstance(log_payload, dict) and isinstance(log_payload.get("log_id"), str) and log_payload.get("log_id") else "failed",
    "log_id": log_payload.get("log_id") if isinstance(log_payload, dict) else None,
  }
  summary["client_shutdown"] = {
    "end_output_requested": True,
    "returned_to_previous_page": isinstance(teardown_payload, dict) and teardown_payload.get("returned_to_configure") is True,
    "app_terminated": True,
  }
  summary["run_ok"] = bool(
    period_available
    and required_rows["stutter"]
    and required_rows["latency_stats"]
    and summary["video_fps_ok"]
    and summary["log_upload"]["status"] == "passed"
    and summary["client_shutdown"]["returned_to_previous_page"]
  )
  if not summary["run_ok"] and not summary.get("failure_stage"):
    summary["failure_stage"] = "output_health" if not summary["video_fps_ok"] else "final_snapshot"


def copy_self_test_client_facts(summary: dict[str, Any], client_summary: dict[str, Any]) -> None:
  for key in SELF_TEST_CLIENT_FACT_KEYS:
    if key in client_summary:
      summary[key] = client_summary[key]
  client_shutdown = client_summary.get("client_shutdown")
  if isinstance(client_shutdown, dict):
    summary["client_shutdown"] = client_shutdown


def copy_self_test_source_facts(summary: dict[str, Any], source_summary: dict[str, Any]) -> None:
  for key in SELF_TEST_SOURCE_FACT_KEYS:
    if key in source_summary:
      summary[key] = source_summary[key]


def _period_required_rows(snapshot: dict[str, Any]) -> dict[str, bool]:
  result = {"stutter": False, "latency_stats": False}
  period = snapshot.get("period_summary")
  rows = period.get("rows") if isinstance(period, dict) else None
  if not isinstance(rows, list):
    return result
  for row in rows:
    if isinstance(row, dict) and row.get("key") in result:
      result[str(row["key"])] = row.get("available") is True
  return result
