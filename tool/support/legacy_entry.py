from __future__ import annotations

import importlib
import json
import os
import sys
from argparse import ArgumentParser
from argparse import Namespace
from pathlib import Path
from typing import Any

from .automation_env import missing_automation_blocked_reason
from .cli_resolver import command_env, resolve_cli
from .device_lane_lock import DeviceLaneLockBusy, acquire_flutter_device_lane_lock, mobile_device_lane_required
from .options import MatrixArgumentParser, add_common_options, default_artifact_root, new_run_id, validate_platform_args
from .paths import legacy_scripts_dir
from .summary import base_summary, finish_summary, now_iso, read_json, write_json


def _load_legacy(module_name: str) -> Any:
  scripts_dir = str(legacy_scripts_dir())
  if scripts_dir not in sys.path:
    sys.path.insert(0, scripts_dir)
  return importlib.import_module(module_name)


def _public_parser(layer: str) -> MatrixArgumentParser:
  parser = MatrixArgumentParser(description=f"Run Flutter SDK {layer} matrix.")
  add_common_options(parser, dry_run=False)
  if layer == "smoke":
    parser.add_argument("--flow", default="downlink_ui", choices=("downlink_ui", "device_server", "device_server_ui", "all"))
    parser.add_argument("--token-source", default="issuer", choices=("issuer", "one_time_token"))
  else:
    parser.add_argument("--codec", default="h264", choices=("h264", "h265", "mjpeg", "all"))
    parser.add_argument(
      "--scenario",
      default="all",
      choices=("cli_device_to_flutter_client", "flutter_device_server_to_cli_client", "all"),
    )
    parser.add_argument("--buffer-policy", default="automatic", choices=("automatic", "no_buffer"))
    parser.add_argument("--audio-case")
    parser.add_argument("--encoder-preference", choices=("software", "hardware"))
  return parser


def _help_requested(argv: list[str]) -> bool:
  return any(item in {"-h", "--help"} for item in argv)


def _parse_public_args(layer: str, argv: list[str]) -> Namespace:
  parser = _public_parser(layer)
  args, _unknown = parser.parse_known_args(argv)
  return args


def _legacy_argv(layer: str, argv: list[str]) -> list[str]:
  if layer != "smoke":
    return list(argv)
  result: list[str] = []
  iterator = iter(argv)
  for item in iterator:
    if item == "--flow":
      result.append(item)
      try:
        value = next(iterator)
      except StopIteration:
        break
      result.append("device_server_ui" if value == "device_server" else value)
      continue
    if item == "--flow=device_server":
      result.append("--flow=device_server_ui")
      continue
    result.append(item)
  return result


def _legacy_unavailable(layer: str, argv: list[str]) -> int:
  args = _parse_public_args(layer, argv)
  try:
    validate_platform_args(args)
  except SystemExit as error:
    return int(error.code or 3)
  blocked_reason = missing_automation_blocked_reason()
  if blocked_reason is None and not getattr(args, "prepared_state", None):
    blocked_reason = "prepared_state_missing"
  if blocked_reason is None:
    blocked_reason = "published_example_real_runner_unavailable"
  run_id = new_run_id(layer)
  artifact_root = Path(args.artifact_root) if getattr(args, "artifact_root", None) else default_artifact_root(layer, run_id)
  cli = resolve_cli(
    cli_source=args.cli_source,
    cli_path=args.cli_path,
    cli_npm_spec=args.cli_npm_spec,
    check_available=False,
  )
  summary = base_summary(
    entry=layer,
    run_id=run_id,
    platform=args.platform,
    artifact_root=artifact_root,
    cli=cli.evidence(),
    mode="real",
    started_at=now_iso(),
  )
  summary["blocked_reason"] = blocked_reason
  summary["failure_stage"] = "blocked"
  return finish_summary(artifact_root, summary)


def _marker_names(markers_path: Path) -> list[str]:
  if not markers_path.is_file():
    return []
  names: list[str] = []
  for line in markers_path.read_text(encoding="utf-8", errors="replace").splitlines():
    if not line.strip():
      continue
    try:
      marker = json.loads(line)
    except json.JSONDecodeError:
      continue
    name = marker.get("name") or marker.get("marker") if isinstance(marker, dict) else None
    if isinstance(name, str):
      names.append(name)
  return names


def _relative_existing(root: Path, path: Path) -> str | None:
  if not path.is_file():
    return None
  try:
    return str(path.relative_to(root))
  except ValueError:
    return str(path)


def _smoke_required_markers(legacy: Any, args: Namespace) -> list[str]:
  required = getattr(legacy, "required_markers_for_flow", None)
  if callable(required):
    return list(required(args.flow))
  return []


def _smoke_all_flow_evidence(legacy_summary: dict[str, Any], artifact_root: Path) -> dict[str, Any]:
  flow_results = legacy_summary.get("flow_results")
  if not isinstance(flow_results, dict):
    return {}
  observed: list[str] = []
  log_ids: list[str] = []
  counterpart_summary_path: str | None = None
  for result in flow_results.values():
    if not isinstance(result, dict):
      continue
    summary_path_value = result.get("summary_path")
    if not isinstance(summary_path_value, str) or not summary_path_value:
      continue
    summary_path = Path(summary_path_value)
    child_root = summary_path.parent
    child_summary = read_json(summary_path) if summary_path.is_file() else {}
    observed.extend(_marker_names(child_root / "flutter/markers.jsonl"))
    log_id = child_summary.get("log_id")
    if isinstance(log_id, str) and log_id:
      log_ids.append(log_id)
    if counterpart_summary_path is None:
      counterpart_summary_path = (
        child_summary.get("counterpart_summary_path")
        or _relative_existing(artifact_root, child_root / "source/summary.json")
        or _relative_existing(artifact_root, child_root / "client/summary.json")
      )
  return {
    "observed_markers": observed,
    "log_id": ",".join(log_ids) if log_ids else None,
    "counterpart_summary_path": counterpart_summary_path,
  }


def _case_log_ids(artifact_root: Path) -> list[str]:
  result: list[str] = []
  for summary_path in sorted(artifact_root.rglob("cases/*/summary.json")):
    try:
      data = read_json(summary_path)
    except (OSError, ValueError):
      return []
    if summary_path.parent.name.endswith("_failed") and data.get("run_ok") is not True:
      continue
    log_id = data.get("log_id")
    if not isinstance(log_id, str) or not log_id:
      return []
    result.append(log_id)
  return result


def _integration_log_id(legacy_summary: dict[str, Any], artifact_root: Path) -> str | None:
  log_id = legacy_summary.get("log_id")
  if isinstance(log_id, str) and log_id:
    return log_id
  scenario_results = legacy_summary.get("scenario_results")
  if isinstance(scenario_results, dict):
    log_ids = [item.get("log_id") for item in scenario_results.values() if isinstance(item, dict)]
    if log_ids and all(isinstance(item, str) and item for item in log_ids):
      return ",".join(log_ids)
  case_log_ids = _case_log_ids(artifact_root)
  if case_log_ids:
    return ",".join(case_log_ids)
  return None


def _layer_evidence(layer: str, legacy_summary: dict[str, Any], mode: str, *, artifact_root: Path, legacy: Any, args: Namespace) -> dict[str, Any]:
  if layer == "smoke":
    all_flow = _smoke_all_flow_evidence(legacy_summary, artifact_root)
    markers_path = artifact_root / "flutter/markers.jsonl"
    observed = list(legacy_summary.get("observed_markers") or []) or all_flow.get("observed_markers") or _marker_names(markers_path)
    log_id = legacy_summary.get("log_id") or all_flow.get("log_id")
    return {
      "ui_flow": {
        "name": legacy_summary.get("flow") or "downlink_ui",
        "status": "passed" if legacy_summary.get("ui_ok") is True else "failed",
        "final_page": None,
        "returned_to_configure": legacy_summary.get("run_ok") is True,
      },
      "markers_path": legacy_summary.get("markers_path") or "flutter/markers.jsonl",
      "required_markers": list(legacy_summary.get("required_markers") or []) or _smoke_required_markers(legacy, args),
      "observed_markers": observed,
      "av_output_observed": legacy_summary.get("av_ok") is True,
      "log_upload": {
        "required": True,
        "status": "passed" if log_id else "failed",
        "log_id": log_id,
        "code": None,
      },
      "teardown_ok": legacy_summary.get("run_ok") is True,
      "counterpart_summary_path": legacy_summary.get("counterpart_summary_path")
      or all_flow.get("counterpart_summary_path")
      or _relative_existing(artifact_root, artifact_root / "source/summary.json")
      or _relative_existing(artifact_root, artifact_root / "client/summary.json"),
    }
  log_id = _integration_log_id(legacy_summary, artifact_root)
  return {
    "scenario_results": list((legacy_summary.get("scenario_results") or {}).values())
    if isinstance(legacy_summary.get("scenario_results"), dict)
    else list(legacy_summary.get("scenario_results") or []),
    "codec_results": list(legacy_summary.get("codec_results") or []),
    "audio_matrix_results": list(legacy_summary.get("audio_matrix_results") or []),
    "markers_path": legacy_summary.get("markers_path") or "flutter/markers.jsonl",
    "required_markers": list(legacy_summary.get("required_markers") or []),
    "counterpart_summary_path": legacy_summary.get("counterpart_summary_path"),
    "av_contract_ok": legacy_summary.get("av_ok") is True,
    "log_upload": {
      "required": True,
      "status": "passed" if log_id else "failed",
      "log_id": log_id,
      "code": None,
    },
    "teardown_ok": legacy_summary.get("run_ok") is True,
  }


def run_legacy_layer(module_name: str, layer: str, argv: list[str]) -> int:
  if _help_requested(argv):
    _public_parser(layer).print_help()
    return 0
  public_args = _parse_public_args(layer, argv)
  try:
    legacy = _load_legacy(module_name)
  except ModuleNotFoundError:
    return _legacy_unavailable(layer, argv)
  parser = legacy.parser()
  parser.add_argument("--cli-source", choices=("npm", "local", "path"))
  parser.add_argument("--cli-path")
  parser.add_argument("--cli-npm-spec")
  args = parser.parse_args(_legacy_argv(layer, argv))
  if getattr(args, "dry_run", False):
    parser.error("--dry-run is not supported for this layer")
  validate_platform_args(args)

  run_id = new_run_id(layer)
  if not getattr(args, "artifact_root", None):
    args.artifact_root = str(default_artifact_root(layer, run_id))
  artifact_root = Path(args.artifact_root)
  started_at = now_iso()
  cli = resolve_cli(
    cli_source=args.cli_source,
    cli_path=args.cli_path,
    cli_npm_spec=args.cli_npm_spec,
    check_available=False,
  )
  matrix_summary = base_summary(
    entry=layer,
    run_id=run_id,
    platform=args.platform,
    artifact_root=artifact_root,
    cli=cli.evidence(),
    mode="real",
    started_at=started_at,
  )
  if getattr(args, "ohos_device_resolution", None):
    matrix_summary["evidence"]["ohos_device_resolution"] = args.ohos_device_resolution

  device_lane_lock = None
  if mobile_device_lane_required(args.platform, dry_run=getattr(args, "dry_run", False)):
    try:
      device_lane_lock = acquire_flutter_device_lane_lock(
        {
          "entry": layer,
          "layer": layer,
          "platform": args.platform,
          "artifact_root": str(artifact_root),
          "run_id": run_id,
        }
      )
      matrix_summary["evidence"]["device_lane_lock"] = device_lane_lock.evidence()
    except DeviceLaneLockBusy as error:
      matrix_summary["blocked_reason"] = "device_lane_lock_busy"
      matrix_summary["failure_stage"] = "blocked"
      matrix_summary["evidence"]["device_lane_lock"] = error.evidence()
      return finish_summary(artifact_root, matrix_summary)

  old_env = os.environ.copy()
  os.environ.clear()
  os.environ.update(command_env(cli))
  os.environ.update({key: value for key, value in old_env.items() if key not in os.environ})
  try:
    if layer == "smoke":
      if args.platform == "all":
        rc = legacy.run_all_platforms(args)
      elif args.flow == "all":
        rc = legacy.run_all_flows(args)
      else:
        rc = legacy.run_single(args, run_override=run_id)
    else:
      rc = legacy.run_self_test(args)
  finally:
    os.environ.clear()
    os.environ.update(old_env)
    if device_lane_lock is not None:
      device_lane_lock.release()

  legacy_path = artifact_root / "summary.json"
  legacy_summary = read_json(legacy_path) if legacy_path.is_file() else {}
  write_json(artifact_root / "raw/legacy-summary.json", legacy_summary)
  _redact_legacy_secrets(artifact_root)
  matrix_summary["run_ok"] = rc == 0 and legacy_summary.get("run_ok") is True
  matrix_summary["blocked_reason"] = legacy_summary.get("blocked_reason")
  matrix_summary["failure_stage"] = legacy_summary.get("failure_stage")
  for key in (
    "prepared_state_schema_version",
    "artifact_visibility",
    "owner_responsibility_status",
    "native_artifact_ref",
    "prepared_state_path",
    "buffer_policy",
    "requested_output_buffer_policy",
    "requested_output_buffer_max_watermark_ms",
    "buffer_policy_ok",
    "buffer_policy_evidence",
    "audio_requested_strategy",
    "video_requested_strategy",
    "audio_requested_max_ms",
    "video_requested_max_ms",
    "audio_applied_before_start",
    "video_applied_before_start",
    "audio_input_packet_rate",
    "audio_render_callback_rate",
    "audio_output_continuity_ratio",
    "audio_output_stall_count",
    "audio_output_stall_total_ms",
    "audio_output_stall_peak_ms",
    "audio_output_stall_ratio",
    "audio_output_health_ok",
    "video_input_fps",
    "video_render_fps",
    "video_render_continuity_ratio",
    "video_output_health_ok",
    "av_output_health_ok",
    "audio_local_latency_window_duration_ms",
    "audio_local_latency_total_average_ms",
    "audio_local_latency_buffer_average_ms",
    "audio_local_latency_decode_or_ready_average_ms",
    "audio_local_latency_output_average_ms",
    "video_local_latency_window_duration_ms",
    "video_local_latency_total_average_ms",
    "video_local_latency_buffer_average_ms",
    "video_local_latency_decode_or_ready_average_ms",
    "video_local_latency_output_average_ms",
  ):
    if key in legacy_summary:
      matrix_summary[key] = legacy_summary[key]
  if matrix_summary["blocked_reason"]:
    matrix_summary["failure_stage"] = "blocked"
  matrix_summary["evidence"].update(_layer_evidence(layer, legacy_summary, "real", artifact_root=artifact_root, legacy=legacy, args=args))
  if matrix_summary["run_ok"]:
    matrix_summary["blocked_reason"] = None
    matrix_summary["failure_stage"] = None
  return finish_summary(artifact_root, matrix_summary)


def _redact_legacy_secrets(root: Path) -> None:
  for path in root.rglob("*.json"):
    if not path.is_file():
      continue
    try:
      data = read_json(path)
    except (OSError, ValueError):
      continue
    if _redact_json_value(data):
      write_json(path, data)


def _redact_json_value(value: object) -> bool:
  changed = False
  if isinstance(value, dict):
    for key, item in list(value.items()):
      if key in {"token", "device_secret_key", "client_token"} and isinstance(item, str) and item:
        value[key] = "<redacted>"
        changed = True
      else:
        changed = _redact_json_value(item) or changed
  elif isinstance(value, list):
    for item in value:
      changed = _redact_json_value(item) or changed
  return changed
