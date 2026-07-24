#!/usr/bin/env python3

from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any

from support.automation_env import missing_automation_env_vars
from support.cli_resolver import CliResolutionError, resolve_cli
from support.dry_layers import local_audio_input_slice, run_first_slice
from support.options import CaseArgumentParser, add_common_options, default_artifact_root, new_run_id, validate_platform_args
from support.paths import build_root, example_root, plugin_root
from support.performance_downlink_metrics import (
  apply_failure_marker,
  apply_success_facts,
  copy_self_test_client_facts,
  copy_self_test_source_facts,
  final_snapshot_from_markers,
)
from support.performance_source_summary import redact_source_bootstrap, write_source_summary
from support.summary import base_summary, finish_summary, now_iso, read_json, redaction_ok, write_json

CASE_DOWNLINK_METRICS = "downlink-metrics-period-summary"
DEFAULT_AUDIO_STREAM_ID = 10
DEFAULT_VIDEO_STREAM_ID = 11
DEFAULT_AUDIO_SAMPLE_RATE_HZ = 16000
DEFAULT_AUDIO_CHANNELS = 1
DEFAULT_DURATION_SECONDS = 180
DEFAULT_WARMUP_SECONDS = 30
FINAL_SNAPSHOT_PATH = "raw/downlink-metrics-final-snapshot.json"
INPUT_PATH = "raw/performance-input.redacted.json"
PROFILE_EXECUTION_MODE = "profile"


def _load_integration_helpers():
  scripts_dir = plugin_root() / "scripts"
  if not scripts_dir.is_dir():
    raise RuntimeError("flutter integration scripts are unavailable")
  if str(scripts_dir) not in sys.path:
    sys.path.insert(0, str(scripts_dir))
  from flutter_integration_markers import collect_flutter_markers
  from flutter_integration_test import flutter_test_command
  from flutter_test_base import payload_define

  return collect_flutter_markers, flutter_test_command, payload_define


def _load_self_test_helpers():
  scripts_dir = plugin_root() / "scripts"
  if not scripts_dir.is_dir():
    raise RuntimeError("flutter test scripts are unavailable")
  if str(scripts_dir) not in sys.path:
    sys.path.insert(0, str(scripts_dir))
  from flutter_test_base import issue_token, normalize_bootstrap, start_source, wait_for_bootstrap

  return issue_token, normalize_bootstrap, start_source, wait_for_bootstrap


def parser() -> CaseArgumentParser:
  result = CaseArgumentParser(description="Run Flutter SDK performance cases.")
  add_common_options(result, dry_run=True)
  result.add_argument("--case")
  result.add_argument("--self-test", action="store_true")
  result.add_argument("--app-id")
  result.add_argument("--endpoint")
  result.add_argument("--remote-id")
  result.add_argument("--token")
  result.add_argument("--audio-stream-id", type=int, default=DEFAULT_AUDIO_STREAM_ID)
  result.add_argument("--video-stream-id", type=int, default=DEFAULT_VIDEO_STREAM_ID)
  result.add_argument("--duration-seconds", type=int, default=DEFAULT_DURATION_SECONDS)
  result.add_argument("--warmup-seconds", type=int, default=DEFAULT_WARMUP_SECONDS)
  result.add_argument("--sample-interval-seconds", type=int)
  result.add_argument("--source")
  return result


def _sha256_text(value: str) -> str:
  return "sha256:" + hashlib.sha256(value.encode("utf-8")).hexdigest()


def _redacted_input(args: argparse.Namespace, run_id: str) -> dict[str, Any]:
  token = args.token or ""
  app_id = args.app_id or ""
  endpoint = args.endpoint or ""
  remote_id = args.remote_id or ""
  device_id = args.device_id or ""
  return {
    "schema_version": 1,
    "run_id": run_id,
    "case": CASE_DOWNLINK_METRICS,
    "platform": args.platform,
    "connection": {
      "app_id_present": bool(app_id),
      "app_id_fingerprint": _sha256_text(app_id) if app_id else None,
      "endpoint_present": bool(endpoint),
      "endpoint_fingerprint": _sha256_text(endpoint) if endpoint else None,
      "remote_id_present": bool(remote_id),
      "remote_id_fingerprint": _sha256_text(remote_id) if remote_id else None,
      "token": "<redacted>",
      "token_present": bool(token),
      "token_fingerprint": _sha256_text(token) if token else None,
    },
    "streams": {
      "audio_stream_id": args.audio_stream_id,
      "video_stream_id": args.video_stream_id,
    },
    "timing": {
      "duration_seconds": args.duration_seconds,
      "warmup_seconds": args.warmup_seconds,
      "measurement_duration_seconds": args.duration_seconds - args.warmup_seconds,
    },
    "execution": {
      "mode": PROFILE_EXECUTION_MODE,
    },
    "client": {
      "device_id_present": args.platform == "android" and bool(device_id),
      "device_id_fingerprint": _sha256_text(device_id) if args.platform == "android" and device_id else None,
    },
    "counterpart_managed": False,
  }


def _payload(args: argparse.Namespace, run_id: str) -> dict[str, Any]:
  token = args.token or ""
  return {
    "schema_version": 1,
    "scenario": "cli_device_to_flutter_client",
    "run_id": run_id,
    "pairing_id": run_id,
    "bootstrap_id": f"performance-{run_id}",
    "app_id": args.app_id or "",
    "endpoint": args.endpoint or "",
    "remote_id": args.remote_id or "",
    "token": token,
    "token_fingerprint": _sha256_text(token),
    "audio_stream_id": args.audio_stream_id,
    "video_stream_id": args.video_stream_id,
    "codec": "h264",
    "audio_codec": "g711a",
    "audio_sample_rate_hz": DEFAULT_AUDIO_SAMPLE_RATE_HZ,
    "audio_channels": DEFAULT_AUDIO_CHANNELS,
    "video_decoder_preference": 0,
    "buffer_policy": "automatic",
    "render_window_seconds": args.duration_seconds,
    "metrics_session_reset_after_seconds": args.warmup_seconds,
    "auto_upload_logs": True,
    "console_log_enabled": True,
  }


def _empty_prepared_state(args: argparse.Namespace) -> dict[str, Any]:
  return {
    "path": None,
    "artifact_visibility": None,
    "owner_responsibility_status": None,
    "native_artifact_ref": None,
    "consumed_platform": args.platform if args.platform in {"macos", "android"} else None,
    "local_darwin_pod_path": None,
  }


def _prepared_state(args: argparse.Namespace) -> tuple[dict[str, Any], str | None]:
  path = Path(args.prepared_state) if args.prepared_state else build_root() / "flutter-example-prepare/current.json"
  if not path.is_file():
    return _empty_prepared_state(args), "prepared_state_missing"
  try:
    state = read_json(path)
  except (OSError, ValueError):
    return _empty_prepared_state(args), "prepared_state_invalid"
  platforms = state.get("prepared_platforms")
  if not isinstance(platforms, list):
    platforms = state.get("platforms")
  if not isinstance(platforms, list) and isinstance(state.get("platform"), str):
    platforms = [state["platform"]]
  if isinstance(platforms, list) and args.platform not in platforms and "all" not in platforms:
    return _empty_prepared_state(args), "platform_not_prepared"
  artifact_ref = state.get("native_artifact_ref")
  if not isinstance(artifact_ref, dict):
    artifact_ref = state.get("darwin_artifact") if args.platform == "macos" else state.get("android_artifact")
  owner = state.get("owner_responsibility")
  owner_status = state.get("owner_responsibility_status")
  if owner_status is None and isinstance(owner, dict):
    owner_status = owner.get("status")
  return (
    {
      "path": str(path),
      "artifact_visibility": state.get("artifact_visibility"),
      "owner_responsibility_status": owner_status,
      "native_artifact_ref": artifact_ref if isinstance(artifact_ref, dict) else None,
      "consumed_platform": args.platform,
      "local_darwin_pod_path": state.get("local_darwin_pod_path") if args.platform != "android" else None,
    },
    None,
  )


def _prepared_state_env(args: argparse.Namespace, prepared: dict[str, Any]) -> dict[str, str]:
  if args.platform == "android":
    return {}
  local_darwin_pod_path = prepared.get("local_darwin_pod_path")
  if isinstance(local_darwin_pod_path, str) and local_darwin_pod_path:
    return {"TIRTC_LOCAL_POD_PATH": local_darwin_pod_path}
  return {}


def _restore_env(previous: dict[str, str | None]) -> None:
  for key, value in previous.items():
    if value is None:
      os.environ.pop(key, None)
    else:
      os.environ[key] = value


def _child_path_arg(path: Path | str) -> str:
  return str(Path(path).expanduser().resolve())


def _base_case_summary(args: argparse.Namespace, run_id: str, root: Path, mode: str) -> dict[str, Any]:
  summary = base_summary(
    entry="performance",
    run_id=run_id,
    platform=args.platform,
    artifact_root=root,
    cli={"source": args.cli_source or "unused", "command": [], "npm_spec": args.cli_npm_spec, "path": args.cli_path, "version": None, "available": False},
    mode=mode,
    started_at=now_iso(),
  )
  summary.update(
    {
      "case": CASE_DOWNLINK_METRICS,
      "counterpart_managed": False,
      "duration_seconds": args.duration_seconds,
      "warmup_seconds": args.warmup_seconds,
      "measurement_duration_seconds": args.duration_seconds - args.warmup_seconds,
      "execution_mode": PROFILE_EXECUTION_MODE,
      "final_metrics_path": FINAL_SNAPSHOT_PATH,
      "input_path": INPUT_PATH,
      "period_summary_available": False,
      "period_summary_required_rows": {"stutter": False, "latency_stats": False},
      "prepared_state": _empty_prepared_state(args),
      "log_upload": {"required": True, "status": "failed", "log_id": None},
      "client_shutdown": {
        "end_output_requested": False,
        "returned_to_previous_page": False,
        "app_terminated": False,
      },
      "redaction_ok": True,
    }
  )
  summary["evidence"].update(
    {
      "performance_case": {
        "name": CASE_DOWNLINK_METRICS,
        "case_id": CASE_DOWNLINK_METRICS,
        "status": mode,
        "duration_seconds": args.duration_seconds,
        "uses_av": True,
      },
      "local_audio_input_slice": local_audio_input_slice("performance", mode),
      "profile_evidence_ok": mode in {"dry_run", "real"},
      "final_metrics_path": FINAL_SNAPSHOT_PATH,
    }
  )
  return summary


def _write_invalid_summary(args: argparse.Namespace, message: str) -> int:
  run_id = new_run_id("performance")
  root = Path(args.artifact_root) if args.artifact_root else default_artifact_root("performance", run_id)
  summary = _base_case_summary(args, run_id, root, "dry_run" if args.dry_run else "real")
  summary["failure_stage"] = "invalid_args"
  summary["blocked_reason"] = message
  finish_summary(root, summary)
  return 3


def _validate_case_args(args: argparse.Namespace) -> str | None:
  if args.platform not in {"macos", "android"}:
    return "--platform must be macos or android"
  if args.platform == "android" and not (args.device_id or args.android_device_id):
    return "--device-id is required for --platform android"
  if args.platform == "macos" and args.device_id:
    return "--device-id is not valid for --platform macos"
  if args.sample_interval_seconds is not None:
    return "--sample-interval-seconds is not accepted by downlink-metrics-period-summary"
  if args.duration_seconds <= 0:
    return "--duration-seconds must be positive"
  if args.warmup_seconds < 0:
    return "--warmup-seconds must be non-negative"
  if args.duration_seconds <= args.warmup_seconds:
    return "--duration-seconds must be greater than --warmup-seconds"
  if args.audio_stream_id != DEFAULT_AUDIO_STREAM_ID or args.video_stream_id != DEFAULT_VIDEO_STREAM_ID:
    return "downlink-metrics-period-summary requires audio stream 10 and video stream 11"
  for name in ("app_id", "endpoint", "remote_id", "token"):
    if not getattr(args, name):
      return f"--{name.replace('_', '-')} is required"
  return None


def _dry_run_snapshot(args: argparse.Namespace, run_id: str) -> dict[str, Any]:
  rows = [
    {"key": "media_params", "text": "媒体参数：1280x720 · H264 · G711A · 硬解", "present": True, "period_text_present": False},
    {"key": "video_receive", "text": "视频接收：码率 1200 kbps · 接收 15.0 fps", "present": True, "period_text_present": False},
    {"key": "audio_receive", "text": "音频接收：码率 64.0 kbps · PPS 25.0/s", "present": True, "period_text_present": False},
    {"key": "latency_stats", "text": "缓冲长度：视频 92 ms · 音频 28 ms", "present": True, "period_text_present": True},
    {"key": "startup", "text": "启动耗时：连接 219 ms · 首帧等待 115 ms", "present": True, "period_text_present": False},
    {"key": "stutter", "text": "卡顿统计：视频 0 次 / 最长 0 ms · 音频最近 0 次 / 最长 0 ms", "present": True, "period_text_present": True},
  ]
  return {
    "schema_version": 1,
    "run_id": run_id,
    "timestamp": now_iso(),
    "elapsed_ms": args.duration_seconds * 1000,
    "source": "ui_text_final_snapshot",
    "platform": args.platform,
    "measurement": {
      "warmup_seconds": args.warmup_seconds,
      "duration_seconds": args.duration_seconds,
      "measurement_duration_seconds": args.duration_seconds - args.warmup_seconds,
      "final_snapshot_elapsed_ms": args.duration_seconds * 1000,
    },
    "rows": rows,
    "period_summary": {
      "available": True,
      "source": "ui_text_period_summary",
      "rows": [
        {"key": "latency_stats", "text": rows[3]["text"], "available": True, "unavailable_reason": None},
        {"key": "stutter", "text": rows[5]["text"], "available": True, "unavailable_reason": None},
      ],
    },
  }


def _base_self_test_summary(args: argparse.Namespace, run_id: str, root: Path, mode: str) -> dict[str, Any]:
  summary = _base_case_summary(args, run_id, root, mode)
  summary.update(
    {
      "self_test": True,
      "counterpart_managed": True,
      "cli": {"source": args.cli_source or "local"},
      "counterpart_profile": {
        "video_codec": "h264",
        "audio_codec": "g711a",
        "audio_sample_rate_hz": DEFAULT_AUDIO_SAMPLE_RATE_HZ,
        "audio_channels": DEFAULT_AUDIO_CHANNELS,
        "audio_stream_id": DEFAULT_AUDIO_STREAM_ID,
        "video_stream_id": DEFAULT_VIDEO_STREAM_ID,
      },
      "client_summary_path": "client/summary.json",
      "source_summary_path": "source/summary.json",
      "final_metrics_path": "client/" + FINAL_SNAPSHOT_PATH,
      "input_path": "client/" + INPUT_PATH,
      "client_log_id": None,
    }
  )
  summary["evidence"]["cli"] = {"source": args.cli_source or "local", "command": [], "available": False}
  return summary


def _validate_self_test_args(args: argparse.Namespace) -> str | None:
  if args.platform not in {"macos", "android"}:
    return "--self-test --platform must be macos or android"
  if args.platform == "android" and not (args.device_id or args.android_device_id):
    return "--device-id is required for Android self-test"
  if args.sample_interval_seconds is not None:
    return "--sample-interval-seconds is not accepted by self-test"
  if args.cli_source is not None and args.cli_source != "local":
    return "--self-test uses the repo-local DevTools CLI; --cli-source must be local"
  if args.cli_path is not None:
    return "--self-test uses the repo-local DevTools CLI and does not accept --cli-path"
  if args.cli_npm_spec is not None:
    return "--self-test uses the repo-local DevTools CLI and does not accept --cli-npm-spec"
  if args.duration_seconds <= 0:
    return "--duration-seconds must be positive"
  if args.warmup_seconds < 0:
    return "--warmup-seconds must be non-negative"
  if args.duration_seconds <= args.warmup_seconds:
    return "--duration-seconds must be greater than --warmup-seconds"
  return None


def _write_blocked_self_test(summary: dict[str, Any], root: Path, reason: str) -> int:
  summary["failure_stage"] = "blocked"
  summary["blocked_reason"] = reason
  return finish_summary(root, summary)


def _stop_source(process: subprocess.Popen[str] | None) -> tuple[int | None, bool]:
  if process is None:
    return None, True
  try:
    return process.wait(timeout=20), True
  except subprocess.TimeoutExpired:
    process.terminate()
    try:
      return process.wait(timeout=10), True
    except subprocess.TimeoutExpired:
      process.kill()
      return process.wait(timeout=10), False


def _run_self_test(args: argparse.Namespace) -> int:
  validation_error = _validate_self_test_args(args)
  if validation_error is not None:
    return _write_invalid_summary(args, validation_error)
  validate_platform_args(args)
  run_id = new_run_id("performance")
  root = Path(args.artifact_root) if args.artifact_root else default_artifact_root("performance", run_id)
  summary = _base_self_test_summary(args, run_id, root, "real")
  prepared, prepared_error = _prepared_state(args)
  summary["prepared_state"] = prepared
  if prepared_error is not None:
    return _write_blocked_self_test(summary, root, prepared_error)
  try:
    cli = resolve_cli(cli_source="local", check_available=True)
  except CliResolutionError as error:
    return _write_blocked_self_test(summary, root, error.blocked_reason)
  summary["cli"] = {"source": cli.source}
  summary["evidence"]["cli"] = cli.evidence()
  missing_env = missing_automation_env_vars()
  if missing_env:
    return _write_blocked_self_test(summary, root, "missing_environment:" + ",".join(missing_env))

  try:
    issue_token, normalize_bootstrap, start_source, wait_for_bootstrap = _load_self_test_helpers()
  except RuntimeError as error:
    return _write_blocked_self_test(summary, root, str(error))

  source_process: subprocess.Popen[str] | None = None
  source_started_at = now_iso()
  source_ready = False
  source_ready_at: str | None = None
  source_failure_stage: str | None = None
  source_summary_written = False
  token_json_path: Path | None = None
  env_command_json = os.environ.get("TIRTC_DEVTOOLS_CLI_COMMAND_JSON")
  os.environ["TIRTC_DEVTOOLS_CLI_COMMAND_JSON"] = json.dumps(cli.command, separators=(",", ":"))
  try:
    token_json, token_issue = issue_token(root, os.environ["TIRTC_DEVICE_ID"], os.environ["TIRTC_ENDPOINT"])
    token_json_path = token_json
    source_process = start_source(
      root,
      run_id,
      "h264",
      token_json,
      token_issue,
      source=Path(args.source) if args.source else None,
      audio_codec="g711a",
      audio_sample_rate_hz=DEFAULT_AUDIO_SAMPLE_RATE_HZ,
      audio_channels=DEFAULT_AUDIO_CHANNELS,
    )
    source_ready = wait_for_bootstrap(root / "source/bootstrap.json", source_process)
    if not source_ready:
      source_failure_stage = "source_start"
      summary["failure_stage"] = "source_start"
      try:
        token_json.unlink()
      except OSError:
        pass
      token_json_path = None
      redact_source_bootstrap(root / "source/bootstrap.json")
      exit_code, teardown_ok = _stop_source(source_process)
      source_process = None
      source_summary = write_source_summary(
        root,
        run_id,
        cli=cli,
        source_ready=False,
        ready_at=None,
        started_at=source_started_at,
        stopped_at=now_iso(),
        exit_code=exit_code,
        teardown_ok=teardown_ok,
        failure_stage="source_start",
        audio_codec="g711a",
        audio_sample_rate_hz=DEFAULT_AUDIO_SAMPLE_RATE_HZ,
        audio_channels=DEFAULT_AUDIO_CHANNELS,
      )
      copy_self_test_source_facts(summary, source_summary)
      source_summary_written = True
      return finish_summary(root, summary)
    source_ready_at = now_iso()
    try:
      token_json.unlink()
    except OSError:
      pass
    token_json_path = None
    bootstrap = normalize_bootstrap(
      root,
      run_id,
      "h264",
      token_issue,
      audio_codec="g711a",
      audio_sample_rate_hz=DEFAULT_AUDIO_SAMPLE_RATE_HZ,
      audio_channels=DEFAULT_AUDIO_CHANNELS,
    )
    client_root = root / "client"
    child_args = [
      sys.executable,
      str(Path(__file__).resolve()),
      "--case",
      CASE_DOWNLINK_METRICS,
      "--platform",
      args.platform,
      "--artifact-root",
      _child_path_arg(client_root),
      "--app-id",
      str(bootstrap["app_id"]),
      "--endpoint",
      str(bootstrap.get("endpoint") or ""),
      "--remote-id",
      str(bootstrap["remote_id"]),
      "--token",
      str(bootstrap["token"]),
      "--duration-seconds",
      str(args.duration_seconds),
      "--warmup-seconds",
      str(args.warmup_seconds),
    ]
    if args.platform == "android":
      child_args.extend(["--device-id", str(args.device_id)])
    if args.prepared_state:
      child_args.extend(["--prepared-state", _child_path_arg(args.prepared_state)])
    child_result = subprocess.run(
      child_args,
      cwd=example_root(),
      stdout=subprocess.PIPE,
      stderr=subprocess.STDOUT,
      text=True,
      check=False,
    )
    (root / "logs").mkdir(parents=True, exist_ok=True)
    (root / "logs/client-case.log").write_text(child_result.stdout, encoding="utf-8")
    redact_source_bootstrap(root / "source/bootstrap.json")
    client_summary_path = client_root / "summary.json"
    client_summary = read_json(client_summary_path) if client_summary_path.is_file() else {}
    copy_self_test_client_facts(summary, client_summary)
    log_upload = client_summary.get("log_upload") if isinstance(client_summary.get("log_upload"), dict) else {}
    summary["client_log_id"] = log_upload.get("log_id")
    summary["log_upload"] = {
      "required": True,
      "status": log_upload.get("status") if isinstance(log_upload.get("status"), str) else "failed",
      "log_id": log_upload.get("log_id"),
    }
    summary["redaction_ok"] = redaction_ok(root)
    summary["run_ok"] = (
      child_result.returncode == 0
      and client_summary.get("run_ok") is True
      and summary["log_upload"]["status"] == "passed"
      and isinstance(summary["client_log_id"], str)
      and bool(summary["client_log_id"])
    )
    if not summary["run_ok"]:
      child_failure_stage = client_summary.get("failure_stage")
      summary["failure_stage"] = child_failure_stage if isinstance(child_failure_stage, str) and child_failure_stage else "client_case"
    exit_code, teardown_ok = _stop_source(source_process)
    source_process = None
    if not teardown_ok and summary["run_ok"]:
      summary["run_ok"] = False
      summary["failure_stage"] = "teardown"
    source_summary = write_source_summary(
      root,
      run_id,
      cli=cli,
      source_ready=True,
      ready_at=source_ready_at,
      started_at=source_started_at,
      stopped_at=now_iso(),
      exit_code=exit_code,
      teardown_ok=teardown_ok,
      failure_stage=None if teardown_ok else "teardown",
      audio_codec="g711a",
      audio_sample_rate_hz=DEFAULT_AUDIO_SAMPLE_RATE_HZ,
      audio_channels=DEFAULT_AUDIO_CHANNELS,
    )
    copy_self_test_source_facts(summary, source_summary)
    source_summary_written = True
    return finish_summary(root, summary)
  except Exception as error:  # noqa: BLE001
    summary["failure_stage"] = "token_issue" if "token" in str(error).lower() else "source_start"
    summary["blocked_reason"] = str(error)
    return finish_summary(root, summary)
  finally:
    if token_json_path is not None:
      try:
        token_json_path.unlink()
      except OSError:
        pass
    exit_code, teardown_ok = _stop_source(source_process)
    redact_source_bootstrap(root / "source/bootstrap.json")
    if not source_summary_written:
      source_summary = write_source_summary(
        root,
        run_id,
        cli=cli,
        source_ready=source_ready,
        ready_at=source_ready_at,
        started_at=source_started_at,
        stopped_at=now_iso(),
        exit_code=exit_code,
        teardown_ok=teardown_ok,
        failure_stage=source_failure_stage if source_failure_stage else None if teardown_ok else "teardown",
        audio_codec="g711a",
        audio_sample_rate_hz=DEFAULT_AUDIO_SAMPLE_RATE_HZ,
        audio_channels=DEFAULT_AUDIO_CHANNELS,
      )
      copy_self_test_source_facts(summary, source_summary)
    if env_command_json is None:
      os.environ.pop("TIRTC_DEVTOOLS_CLI_COMMAND_JSON", None)
    else:
      os.environ["TIRTC_DEVTOOLS_CLI_COMMAND_JSON"] = env_command_json


def _run_case(args: argparse.Namespace) -> int:
  validation_error = _validate_case_args(args)
  if validation_error is not None:
    return _write_invalid_summary(args, validation_error)
  validate_platform_args(args)

  run_id = new_run_id("performance")
  root = Path(args.artifact_root) if args.artifact_root else default_artifact_root("performance", run_id)
  mode = "dry_run" if args.dry_run else "real"
  summary = _base_case_summary(args, run_id, root, mode)
  prepared, prepared_error = _prepared_state(args)
  summary["prepared_state"] = prepared
  write_json(root / INPUT_PATH, _redacted_input(args, run_id))

  if prepared_error is not None and not args.dry_run:
    summary["failure_stage"] = "blocked"
    summary["blocked_reason"] = prepared_error
    return finish_summary(root, summary)

  if args.dry_run:
    snapshot = _dry_run_snapshot(args, run_id)
    write_json(root / FINAL_SNAPSHOT_PATH, snapshot)
    apply_success_facts(
      summary,
      snapshot,
      [
        {"marker": "render_window_completed", "payload": {"video_input_fps": 15.0, "video_render_fps": 15.0}},
        {"marker": "log_upload_completed", "payload": {"log_id": "dry-run-log"}},
        {"marker": "teardown_completed", "payload": {"returned_to_configure": True}},
      ],
    )
    return finish_summary(root, summary)

  try:
    collect_flutter_markers, flutter_test_command, payload_define = _load_integration_helpers()
  except RuntimeError as error:
    summary["failure_stage"] = "blocked"
    summary["blocked_reason"] = str(error)
    return finish_summary(root, summary)

  payload = _payload(args, run_id)
  command = flutter_test_command(args, run_id, payload_define(payload), "integration_test/integration/tirtc_downlink_test.dart")
  required_markers = (
    "payload_applied",
    "runtime_initialized",
    "connected",
    "audio_playing",
    "video_rendering",
    "debug_stats_ready",
    "metrics_session_reset",
    "final_metrics_snapshot",
    "render_window_completed",
    "log_upload_completed",
    "teardown_completed",
  )
  timeouts = {
    "payload_applied": 30,
    "runtime_initialized": 30,
    "connected": 60,
    "audio_playing": 60,
    "video_rendering": 90,
    "debug_stats_ready": 90,
    "metrics_session_reset": args.warmup_seconds + 60,
    "final_metrics_snapshot": args.duration_seconds - args.warmup_seconds + 90,
    "render_window_completed": 30,
    "log_upload_completed": 180,
    "teardown_completed": 60,
  }
  env_updates = _prepared_state_env(args, summary["prepared_state"])
  previous_env = {key: os.environ.get(key) for key in env_updates}
  os.environ.update(env_updates)
  try:
    _, markers, timed_out = collect_flutter_markers(command, root, run_id, required_markers=required_markers, marker_timeouts=timeouts)
  finally:
    _restore_env(previous_env)
  if apply_failure_marker(summary, markers):
    return finish_summary(root, summary)
  if timed_out is not None:
    summary["failure_stage"] = "metrics_panel" if timed_out in {"debug_stats_ready", "final_metrics_snapshot"} else timed_out
    summary["marker_timeout_stage"] = timed_out
    return finish_summary(root, summary)
  snapshot = final_snapshot_from_markers(markers)
  if snapshot is None:
    summary["failure_stage"] = "final_snapshot"
    return finish_summary(root, summary)
  write_json(root / FINAL_SNAPSHOT_PATH, snapshot)
  apply_success_facts(summary, snapshot, markers)
  return finish_summary(root, summary)


def main(argv: list[str]) -> int:
  args = parser().parse_args(argv)
  if args.self_test:
    if args.case not in (None, CASE_DOWNLINK_METRICS):
      return _write_invalid_summary(args, f"unsupported self-test case: {args.case}")
    args.case = CASE_DOWNLINK_METRICS
    return _run_self_test(args)
  if args.case == CASE_DOWNLINK_METRICS:
    return _run_case(args)
  if args.case:
    return _write_invalid_summary(args, f"unsupported performance case: {args.case}")
  return run_first_slice("performance", args)


if __name__ == "__main__":
  raise SystemExit(main(sys.argv[1:]))
