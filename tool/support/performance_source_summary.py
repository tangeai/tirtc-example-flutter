from __future__ import annotations

from pathlib import Path
from typing import Any

from .cli_resolver import ResolvedCli
from .summary import read_json, redaction_ok, write_json


def redact_source_bootstrap(path: Path) -> None:
  if not path.is_file():
    return
  data = read_json(path)
  if isinstance(data.get("token"), str):
    data["token"] = "<redacted>"
  write_json(path, data)


def write_source_summary(
  root: Path,
  run_id: str,
  *,
  cli: ResolvedCli,
  source_ready: bool,
  ready_at: str | None,
  started_at: str | None,
  stopped_at: str | None,
  exit_code: int | None,
  teardown_ok: bool,
  failure_stage: str | None = None,
  audio_codec: str = "g711a",
  audio_sample_rate_hz: int = 16000,
  audio_channels: int = 1,
) -> dict[str, Any]:
  source_summary: dict[str, Any] = {
    "schema_version": 1,
    "run_id": run_id,
    "role": "device_source",
    "producer": "flutter-test-performance-wrapper",
    "cli": {
      "source": cli.source,
      "command": cli.command,
      "path": cli.path,
      "version": cli.version,
    },
    "source_ready": source_ready,
    "ready_evidence_path": "source/bootstrap.json" if source_ready else None,
    "started_at": started_at,
    "ready_at": ready_at,
    "stopped_at": stopped_at,
    "exit_code": exit_code,
    "teardown_ok": teardown_ok,
    "failure_stage": failure_stage,
    "profile": {
      "video_codec": "h264",
      "audio_codec": audio_codec,
      "audio_sample_rate_hz": audio_sample_rate_hz,
      "audio_channels": audio_channels,
      "audio_stream_id": 10,
      "video_stream_id": 11,
    },
    "redaction_ok": redaction_ok(root),
  }
  driver_summary_path = _preserve_source_driver_summary(root)
  if driver_summary_path is not None:
    source_summary["source_driver_summary_path"] = driver_summary_path
  write_json(root / "source/summary.json", source_summary)
  return source_summary


def _preserve_source_driver_summary(root: Path) -> str | None:
  summary_path = root / "source/summary.json"
  if not summary_path.is_file():
    return None
  try:
    driver_summary = read_json(summary_path)
  except Exception:  # noqa: BLE001
    return None
  if not isinstance(driver_summary.get("driver_version"), str):
    return None
  preserved_path = root / "source/driver-summary.json"
  write_json(preserved_path, driver_summary)
  return "source/driver-summary.json"
