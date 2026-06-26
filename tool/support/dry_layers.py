from __future__ import annotations

from argparse import Namespace
from pathlib import Path
import subprocess
import sys

from .cli_resolver import CliResolutionError, resolve_cli
from .device_lane_lock import DeviceLaneLockBusy, acquire_flutter_device_lane_lock, mobile_device_lane_required
from .options import default_artifact_root, new_run_id, validate_platform_args
from .paths import example_root, plugin_root
from .summary import base_summary, finish_summary, now_iso, write_json


LOCAL_AUDIO_INPUT_STREAM_ID = 14


def local_audio_input_slice(layer: str, mode: str) -> dict[str, object]:
  return {
    "name": "local_audio_input_transport",
    "layer": layer,
    "status": mode,
    "scope": "transport_wiring",
    "stream_id": LOCAL_AUDIO_INPUT_STREAM_ID,
    "codec": "g711a",
    "sample_rate_hz": 16000,
    "channels": 1,
    "start_stop_cycles": 2,
    "quality_scope": "excluded",
  }


def _performance_evidence(mode: str, *, command_log: str | None = None) -> dict[str, object]:
  return {
    "profile_mode": mode,
    "frame_timing_path": None,
    "timeline_path": None,
    "memory_path": None,
    "av_markers_path": command_log,
    "performance_case": {"name": "profile_evidence_skeleton", "status": mode, "duration_seconds": 0, "uses_av": False},
    "local_audio_input_slice": local_audio_input_slice("performance", mode),
    "sample_window_seconds": 0,
    "profile_evidence_ok": mode in {"dry_run", "real"},
  }


def _stability_evidence(mode: str, *, command_log: str | None = None) -> dict[str, object]:
  return {
    "stability_case": {"name": "downlink_health_window", "status": mode, "target_duration_seconds": 0},
    "local_audio_input_slice": local_audio_input_slice("stability", mode),
    "target_duration_seconds": 0,
    "actual_duration_seconds": 0,
    "health_markers_path": command_log,
    "health_sample_count": 1 if mode == "real" else 0,
    "terminal_av_failure_count": 0,
    "teardown_ok": mode in {"dry_run", "real"},
  }


def _stress_evidence(mode: str, *, command_log: str | None = None) -> dict[str, object]:
  return {
    "stress_case": {"name": "lifecycle_wiring", "status": mode, "operation": "connect_attach_detach"},
    "local_audio_input_slice": local_audio_input_slice("stress", mode),
    "requested_iterations": 1 if mode == "real" else 0,
    "completed_iterations": 1 if mode == "real" else 0,
    "lifecycle_markers_path": command_log,
    "attach_detach_ok": mode in {"dry_run", "real"},
    "live_object_leak_check": {
      "status": "skipped",
      "skipped_reason": "not_available",
      "live_object_count": None,
      "evidence_path": None,
    },
    "teardown_ok": mode in {"dry_run", "real"},
  }


def _layer_evidence(layer: str, mode: str, *, command_log: str | None = None) -> dict[str, object]:
  if layer == "performance":
    return _performance_evidence(mode, command_log=command_log)
  if layer == "stability":
    return _stability_evidence(mode, command_log=command_log)
  return _stress_evidence(mode, command_log=command_log)


def _flutter_test_target(layer: str) -> str:
  return f"integration_test/{layer}/{layer}_wiring_test.dart"


def _flutter_test_command(layer: str, args: Namespace) -> list[str]:
  command = [
    sys.executable,
    str(plugin_root() / "scripts/flutter_sdk_selector.py"),
    "run",
    "--platform",
    args.platform,
    "--",
    "flutter",
    "test",
    _flutter_test_target(layer),
  ]
  if args.platform != "macos":
    command.extend(["-d", str(args.device_id)])
  return command


def _retryable_ohos_app_launch_failure(log_path: Path) -> bool:
  if not log_path.is_file():
    return False
  text = log_path.read_text(encoding="utf-8", errors="replace")
  return "TCP Port listen failed" in text or "Error waiting for a debug connection" in text


def _run_flutter_first_slice(layer: str, args: Namespace, root: Path) -> tuple[int, str, int]:
  log_path = root / "logs/flutter-test.log"
  log_path.parent.mkdir(parents=True, exist_ok=True)
  command = _flutter_test_command(layer, args)
  max_attempts = 2 if args.platform == "ohos" else 1
  retry_count = 0
  for attempt in range(1, max_attempts + 1):
    with log_path.open("a" if attempt > 1 else "w", encoding="utf-8") as log_file:
      if attempt > 1:
        log_file.write(f"\n\n# retry attempt {attempt}\n")
      log_file.write("$ " + " ".join(command) + "\n\n")
      result = subprocess.run(
        command,
        cwd=example_root(),
        stdout=log_file,
        stderr=subprocess.STDOUT,
        text=True,
        check=False,
      )
    if result.returncode == 0:
      return result.returncode, str(log_path.relative_to(root)), retry_count
    if attempt < max_attempts and _retryable_ohos_app_launch_failure(log_path):
      retry_count += 1
      continue
    return result.returncode, str(log_path.relative_to(root)), retry_count
  return 1, str(log_path.relative_to(root)), retry_count


def run_first_slice(layer: str, args: Namespace) -> int:
  try:
    validate_platform_args(args)
    cli = resolve_cli(
      cli_source=args.cli_source,
      cli_path=args.cli_path,
      cli_npm_spec=args.cli_npm_spec,
      check_available=False,
    )
  except CliResolutionError as error:
    root = Path(args.artifact_root) if args.artifact_root else default_artifact_root(layer, new_run_id(layer))
    summary = base_summary(
      entry=layer,
      run_id=new_run_id(layer),
      platform=args.platform,
      artifact_root=root,
      cli={"source": args.cli_source or "npm", "command": [], "npm_spec": args.cli_npm_spec, "path": args.cli_path, "version": None, "available": False},
      mode="dry_run" if args.dry_run else "fake_case",
      started_at=now_iso(),
    )
    summary["blocked_reason"] = error.blocked_reason
    summary["failure_stage"] = "blocked" if error.exit_code == 2 else "invalid_args"
    return finish_summary(root, summary) if error.exit_code != 3 else 3

  run_id = new_run_id(layer)
  root = Path(args.artifact_root) if args.artifact_root else default_artifact_root(layer, run_id)
  mode = "dry_run" if args.dry_run else "real"
  summary = base_summary(
    entry=layer,
    run_id=run_id,
    platform=args.platform,
    artifact_root=root,
    cli=cli.evidence(),
    mode=mode,
    started_at=now_iso(),
  )
  if getattr(args, "ohos_device_resolution", None):
    summary["evidence"]["ohos_device_resolution"] = args.ohos_device_resolution
  command_log: str | None = None
  device_lane_lock = None
  if mobile_device_lane_required(args.platform, dry_run=args.dry_run):
    try:
      device_lane_lock = acquire_flutter_device_lane_lock(
        {
          "entry": layer,
          "layer": layer,
          "platform": args.platform,
          "artifact_root": str(root),
          "run_id": run_id,
        }
      )
      summary["evidence"]["device_lane_lock"] = device_lane_lock.evidence()
    except DeviceLaneLockBusy as error:
      summary["blocked_reason"] = "device_lane_lock_busy"
      summary["failure_stage"] = "blocked"
      summary["evidence"]["device_lane_lock"] = error.evidence()
      return finish_summary(root, summary)
  try:
    if args.dry_run:
      summary["run_ok"] = True
    elif args.platform not in {"macos", "ohos"}:
      summary["blocked_reason"] = f"{layer}_mobile_execution_not_implemented"
      summary["failure_stage"] = "blocked"
    else:
      if args.platform == "ohos" and not args.device_id:
        summary["blocked_reason"] = f"{layer}_ohos_device_missing"
        summary["failure_stage"] = "blocked"
      else:
        rc, command_log, retry_count = _run_flutter_first_slice(layer, args, root)
        summary["evidence"]["flutter_command_log"] = command_log
        if retry_count:
          summary["evidence"]["ohos_app_launch_retry_count"] = retry_count
        summary["run_ok"] = rc == 0
        if rc != 0:
          summary["failure_stage"] = "flutter_test"
  finally:
    if device_lane_lock is not None:
      device_lane_lock.release()
  summary["evidence"].update(_layer_evidence(layer, mode, command_log=command_log))
  write_json(root / "raw/first-slice-input.json", {"dry_run": args.dry_run, "platform": args.platform, "mode": mode})
  return finish_summary(root, summary)
