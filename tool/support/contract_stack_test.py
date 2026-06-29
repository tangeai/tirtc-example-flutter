#!/usr/bin/env python3

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import unittest
from argparse import Namespace
from pathlib import Path
from unittest.mock import patch


TOOL_ROOT = Path(__file__).resolve().parents[1]
if str(TOOL_ROOT) not in sys.path:
  sys.path.insert(0, str(TOOL_ROOT))
SCRIPTS_ROOT_CANDIDATES = (
  TOOL_ROOT.parents[1] / "scripts",
  TOOL_ROOT.parents[1] / "tirtc_av_kit" / "scripts",
)
SCRIPTS_ROOT = next(
  (candidate for candidate in SCRIPTS_ROOT_CANDIDATES if (candidate / "flutter_integration_test.py").is_file()),
  SCRIPTS_ROOT_CANDIDATES[0],
)
if str(SCRIPTS_ROOT) not in sys.path:
  sys.path.insert(0, str(SCRIPTS_ROOT))

from support.cli_resolver import CliResolutionError, resolve_cli
from support.ohos_device import select_ohos_target
from support.options import validate_platform_args
from support.performance_downlink_metrics import (
  apply_failure_marker,
  apply_success_facts,
  copy_self_test_client_facts,
  copy_self_test_source_facts,
)
from support.performance_source_summary import write_source_summary
from support.summary import base_summary, finish_summary, now_iso
from performance import _prepared_state_env
from flutter_integration_test import flutter_test_command


class ToolContractStackTest(unittest.TestCase):
  def run_tool(self, entry: str, args: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
      [sys.executable, str(TOOL_ROOT / entry), *args],
      cwd=TOOL_ROOT.parent,
      stdout=subprocess.PIPE,
      stderr=subprocess.PIPE,
      text=True,
      check=False,
    )

  def run_public_tool(self, root: Path, entry: str, args: list[str]) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env.pop("TIRTC_AV_REPO_ROOT", None)
    env.pop("TIRTC_DEVTOOLS_CLI_SOURCE", None)
    env.pop("TIRTC_DEVTOOLS_CLI", None)
    return subprocess.run(
      [sys.executable, str(root / "tool" / entry), *args],
      cwd=root,
      env=env,
      stdout=subprocess.PIPE,
      stderr=subprocess.PIPE,
      text=True,
      check=False,
    )

  def sync_public_example(self, root: Path) -> None:
    sync_script = SCRIPTS_ROOT / "sync_public_example_repo.py"
    result = subprocess.run(
      [sys.executable, str(sync_script), "--target-root", str(root)],
      stdout=subprocess.PIPE,
      stderr=subprocess.PIPE,
      text=True,
      check=False,
    )
    self.assertEqual(result.returncode, 0, result.stderr)

  def test_cli_resolver_defaults_to_repo_local_when_available(self) -> None:
    resolved = resolve_cli(check_available=False)
    self.assertEqual(resolved.source, "local")
    self.assertEqual(resolved.command[0], "node")
    self.assertTrue(str(resolved.path or "").endswith("developer-tools/devtools/bin/tirtc-devtools-cli.js"))
    self.assertIsNone(resolved.npm_spec)

  def test_cli_resolver_uses_npm_outside_repo(self) -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
      with patch.dict(os.environ, {"TIRTC_AV_REPO_ROOT": temp_dir}, clear=False):
        resolved = resolve_cli(check_available=False)
    self.assertEqual(resolved.source, "npm")
    self.assertEqual(resolved.command, ["npx", "--yes", "tirtc-devtools-cli@latest"])
    self.assertEqual(resolved.npm_spec, "tirtc-devtools-cli@latest")
    self.assertIsNone(resolved.path)

  def test_cli_resolver_accepts_explicit_js_path(self) -> None:
    resolved = resolve_cli(cli_source="path", cli_path="devtools.js", check_available=False)
    self.assertEqual(resolved.source, "path")
    self.assertEqual(resolved.command, ["node", "devtools.js"])
    self.assertEqual(resolved.path, "devtools.js")

  def test_cli_resolver_reports_missing_local(self) -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
      with patch.dict(os.environ, {"TIRTC_AV_REPO_ROOT": temp_dir}, clear=False):
        with self.assertRaises(CliResolutionError) as ctx:
          resolve_cli(cli_source="local", check_available=False)
    self.assertEqual(ctx.exception.exit_code, 2)
    self.assertEqual(ctx.exception.blocked_reason, "local_devtools_cli_missing")

  def test_smoke_and_integration_reject_dry_run(self) -> None:
    for entry in ("smoke.py", "integration.py"):
      result = self.run_tool(entry, ["--dry-run"])
      self.assertEqual(result.returncode, 3, result.stderr)

  def test_mobile_requires_device_id(self) -> None:
    result = self.run_tool("performance.py", ["--platform", "android", "--dry-run"])
    self.assertEqual(result.returncode, 3, result.stderr)

  def test_ohos_auto_selects_device_id(self) -> None:
    args = Namespace(platform="ohos", device_id=None, android_device_id=None, ios_device_id=None, dry_run=False)
    with patch("support.options.resolve_ohos_device_id", return_value=("ohos-device", {"source": "hdc"})):
      validate_platform_args(args)
    self.assertEqual(args.device_id, "ohos-device")

  def test_ohos_dry_run_does_not_probe_device(self) -> None:
    args = Namespace(platform="ohos", device_id=None, android_device_id=None, ios_device_id=None, dry_run=True)
    with patch("support.options.resolve_ohos_device_id", side_effect=AssertionError("unexpected device probe")):
      validate_platform_args(args)
    self.assertIsNone(args.device_id)

  def test_ohos_target_selection_prefers_physical_device(self) -> None:
    identities = {
      "emulator-5554": "OpenHarmony emulator",
      "2LQ0224125000544": "HUAWEI phone",
    }
    with patch("support.ohos_device._query_identity", side_effect=lambda target: identities[target]):
      selected, evidence = select_ohos_target(["emulator-5554", "2LQ0224125000544"])
    self.assertEqual(selected, "2LQ0224125000544")
    self.assertEqual(evidence["selection"], "physical_preferred")

  def test_all_platform_rejects_single_device_id(self) -> None:
    result = self.run_tool(
      "performance.py",
      ["--platform", "all", "--device-id", "device", "--android-device-id", "android", "--ios-device-id", "ios", "--dry-run"],
    )
    self.assertEqual(result.returncode, 3, result.stderr)

  def test_first_slice_dry_run_summary_schema(self) -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
      root = Path(temp_dir) / "performance"
      result = self.run_tool("performance.py", ["--artifact-root", str(root), "--dry-run"])
      self.assertEqual(result.returncode, 0, result.stderr)
      summary = json.loads((root / "summary.json").read_text(encoding="utf-8"))
      self.assertTrue(summary["run_ok"])
      self.assertEqual(summary["entry"], "performance")
      self.assertEqual(summary["layer"], "performance")
      self.assertEqual(summary["evidence"]["mode"], "dry_run")
      self.assertEqual(summary["evidence"]["coverage_level"], "wiring")
      self.assertEqual(
        summary["evidence"]["local_audio_input_slice"],
        {
          "name": "local_audio_input_transport",
          "layer": "performance",
          "status": "dry_run",
          "scope": "transport_wiring",
          "stream_id": 14,
          "codec": "g711a",
          "sample_rate_hz": 16000,
          "channels": 1,
          "start_stop_cycles": 2,
          "quality_scope": "excluded",
        },
      )
      self.assertTrue(summary["evidence"]["summary_schema_valid"])
      self.assertEqual(summary["evidence"]["cli"]["source"], "local")

  def test_downlink_metrics_period_summary_dry_run_schema(self) -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
      root = Path(temp_dir) / "performance"
      result = self.run_tool(
        "performance.py",
        [
          "--case",
          "downlink-metrics-period-summary",
          "--artifact-root",
          str(root),
          "--dry-run",
          "--platform",
          "macos",
          "--app-id",
          "app",
          "--endpoint",
          "https://endpoint.example",
          "--remote-id",
          "device",
          "--token",
          "secret-token",
          "--duration-seconds",
          "2",
          "--warmup-seconds",
          "1",
        ],
      )
      self.assertEqual(result.returncode, 0, result.stderr)
      summary = json.loads((root / "summary.json").read_text(encoding="utf-8"))
      self.assertTrue(summary["run_ok"])
      self.assertEqual(summary["case"], "downlink-metrics-period-summary")
      self.assertFalse(summary["counterpart_managed"])
      self.assertEqual(summary["execution_mode"], "profile")
      self.assertTrue(summary["period_summary_available"])
      self.assertEqual(summary["period_summary_required_rows"], {"stutter": True, "latency_stats": True})
      self.assertEqual(summary["minimum_downlink_video_fps"], 12.0)
      self.assertEqual(summary["video_input_fps"], 15.0)
      self.assertEqual(summary["video_render_fps"], 15.0)
      self.assertTrue(summary["video_fps_ok"])
      self.assertEqual(summary["log_upload"]["status"], "passed")
      final_snapshot = json.loads((root / "raw/downlink-metrics-final-snapshot.json").read_text(encoding="utf-8"))
      self.assertTrue(final_snapshot["period_summary"]["available"])
      self.assertEqual({row["key"] for row in final_snapshot["rows"]}, {
        "media_params",
        "video_receive",
        "audio_receive",
        "latency_stats",
        "startup",
        "stutter",
      })
      redacted = json.loads((root / "raw/performance-input.redacted.json").read_text(encoding="utf-8"))
      self.assertEqual(redacted["connection"]["token"], "<redacted>")
      self.assertNotIn("secret-token", (root / "summary.json").read_text(encoding="utf-8"))
      self.assertNotIn("secret-token", (root / "raw/performance-input.redacted.json").read_text(encoding="utf-8"))

  def test_downlink_metrics_period_summary_rejects_low_video_fps(self) -> None:
    summary: dict[str, object] = {}
    snapshot = {
      "period_summary": {
        "available": True,
        "rows": [
          {"key": "latency_stats", "available": True},
          {"key": "stutter", "available": True},
        ],
      }
    }
    markers = [
      {"marker": "render_window_completed", "payload": {"video_input_fps": 1.0, "video_render_fps": 1.0}},
      {"marker": "log_upload_completed", "payload": {"log_id": "log-1"}},
      {"marker": "teardown_completed", "payload": {"returned_to_configure": True}},
    ]

    apply_success_facts(summary, snapshot, markers)

    self.assertFalse(summary["run_ok"])
    self.assertFalse(summary["video_fps_ok"])
    self.assertEqual(summary["failure_stage"], "output_health")

  def test_downlink_metrics_period_summary_maps_app_failure_marker(self) -> None:
    summary: dict[str, object] = {}
    markers = [
      {
        "marker": "failure",
        "payload": {
          "failure_stage": "measurement_start",
          "message": "video reset failed",
          "error_code": 6000,
        },
      }
    ]

    self.assertTrue(apply_failure_marker(summary, markers))

    self.assertFalse(summary["run_ok"])
    self.assertEqual(summary["failure_stage"], "measurement_start")
    self.assertEqual(summary["failure_message"], "video reset failed")
    self.assertEqual(summary["error_code"], 6000)

  def test_downlink_metrics_self_test_copies_child_video_fps_facts(self) -> None:
    summary: dict[str, object] = {
      "period_summary_available": False,
      "period_summary_required_rows": {"stutter": False, "latency_stats": False},
      "final_metrics_path": "client/raw/downlink-metrics-final-snapshot.json",
      "input_path": "client/raw/performance-input.redacted.json",
      "client_shutdown": {
        "end_output_requested": False,
        "returned_to_previous_page": False,
        "app_terminated": False,
      },
    }
    client_summary = {
      "period_summary_available": True,
      "period_summary_required_rows": {"stutter": True, "latency_stats": True},
      "video_input_fps": 1.0,
      "video_render_fps": 1.0,
      "minimum_downlink_video_fps": 12.0,
      "video_fps_ok": False,
      "final_metrics_path": "raw/downlink-metrics-final-snapshot.json",
      "input_path": "raw/performance-input.redacted.json",
      "client_shutdown": {
        "end_output_requested": True,
        "returned_to_previous_page": True,
        "app_terminated": True,
      },
    }

    copy_self_test_client_facts(summary, client_summary)

    self.assertTrue(summary["period_summary_available"])
    self.assertEqual(summary["period_summary_required_rows"], {"stutter": True, "latency_stats": True})
    self.assertEqual(summary["video_input_fps"], 1.0)
    self.assertEqual(summary["video_render_fps"], 1.0)
    self.assertEqual(summary["minimum_downlink_video_fps"], 12.0)
    self.assertFalse(summary["video_fps_ok"])
    self.assertEqual(summary["final_metrics_path"], "client/raw/downlink-metrics-final-snapshot.json")
    self.assertEqual(summary["input_path"], "client/raw/performance-input.redacted.json")
    self.assertEqual(
      summary["client_shutdown"],
      {
        "end_output_requested": True,
        "returned_to_previous_page": True,
        "app_terminated": True,
      },
    )

  def test_downlink_metrics_source_summary_preserves_driver_summary(self) -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
      root = Path(temp_dir)
      source_root = root / "source"
      source_root.mkdir(parents=True)
      (source_root / "summary.json").write_text(
        json.dumps({"schema_version": 1, "driver_version": "devtools-driver-probe-v1"}),
        encoding="utf-8",
      )
      cli = Namespace(source="local", command=["node", "cli.js"], path="/repo/cli.js", version="CLI Version: test")

      source_summary = write_source_summary(
        root,
        "performance-test",
        cli=cli,
        source_ready=True,
        ready_at="2026-06-23T00:00:01Z",
        started_at="2026-06-23T00:00:00Z",
        stopped_at="2026-06-23T00:00:02Z",
        exit_code=0,
        teardown_ok=True,
      )
      summary: dict[str, object] = {}
      copy_self_test_source_facts(summary, source_summary)

      self.assertEqual(source_summary["source_driver_summary_path"], "source/driver-summary.json")
      self.assertTrue((source_root / "driver-summary.json").is_file())
      self.assertEqual(summary["source_driver_summary_path"], "source/driver-summary.json")

  def test_downlink_metrics_performance_uses_profile_flutter_drive(self) -> None:
    macos_args = Namespace(platform="macos", device_id=None)
    android_args = Namespace(platform="android", device_id="android-device")

    macos_command = flutter_test_command(macos_args, "run", "payload", "integration_test/integration/tirtc_av_downlink_test.dart")
    android_command = flutter_test_command(android_args, "run", "payload", "integration_test/integration/tirtc_av_downlink_test.dart")

    self.assertEqual(macos_command[:3], ["flutter", "drive", "--profile"])
    self.assertIn("--driver=test_driver/integration_test.dart", macos_command)
    self.assertEqual(android_command[:3], ["flutter", "drive", "--profile"])
    self.assertIn("--driver=test_driver/integration_test.dart", android_command)

  def test_downlink_metrics_period_summary_reads_prepared_state_v2(self) -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
      state_path = Path(temp_dir) / "prepared.json"
      android_artifact = {
        "artifact_key": "android-tirtc-av",
        "artifact_name": "com.tange.ai:tirtc-av",
        "version": "2.0.0-test",
        "coordinate": "com.tange.ai:tirtc-av:2.0.0-test",
      }
      state_path.write_text(
        json.dumps(
          {
            "schema_version": 2,
            "platforms": ["android"],
            "platform": "android",
            "artifact_visibility": "local",
            "owner_responsibility": {"status": "local-debug"},
            "android_artifact": android_artifact,
          }
        ),
        encoding="utf-8",
      )
      root = Path(temp_dir) / "performance"
      result = self.run_tool(
        "performance.py",
        [
          "--case",
          "downlink-metrics-period-summary",
          "--artifact-root",
          str(root),
          "--dry-run",
          "--platform",
          "android",
          "--device-id",
          "android-device",
          "--prepared-state",
          str(state_path),
          "--app-id",
          "app",
          "--endpoint",
          "https://endpoint.example",
          "--remote-id",
          "device",
          "--token",
          "secret-token",
          "--duration-seconds",
          "2",
          "--warmup-seconds",
          "1",
        ],
      )
      self.assertEqual(result.returncode, 0, result.stderr)
      summary = json.loads((root / "summary.json").read_text(encoding="utf-8"))
      self.assertEqual(summary["prepared_state"]["path"], str(state_path))
      self.assertEqual(summary["prepared_state"]["artifact_visibility"], "local")
      self.assertEqual(summary["prepared_state"]["owner_responsibility_status"], "local-debug")
      self.assertEqual(summary["prepared_state"]["native_artifact_ref"], android_artifact)
      self.assertEqual(summary["prepared_state"]["consumed_platform"], "android")

  def test_downlink_metrics_prepared_state_env_uses_local_darwin_pod(self) -> None:
    macos_args = Namespace(platform="macos")
    android_args = Namespace(platform="android")
    prepared = {"local_darwin_pod_path": "/tmp/TiRTC_AV-local"}

    self.assertEqual(_prepared_state_env(macos_args, prepared), {"TIRTC_AV_LOCAL_POD_PATH": "/tmp/TiRTC_AV-local"})
    self.assertEqual(_prepared_state_env(android_args, prepared), {})

  def test_downlink_metrics_self_test_blocks_on_platform_mismatched_prepared_state(self) -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
      state_path = Path(temp_dir) / "prepared.json"
      state_path.write_text(
        json.dumps(
          {
            "schema_version": 2,
            "platforms": ["android"],
            "platform": "android",
            "artifact_visibility": "local",
            "owner_responsibility": {"status": "local-debug"},
            "android_artifact": {"artifact_key": "android-tirtc-av"},
          }
        ),
        encoding="utf-8",
      )
      root = Path(temp_dir) / "performance"
      result = self.run_tool(
        "performance.py",
        [
          "--case",
          "downlink-metrics-period-summary",
          "--self-test",
          "--artifact-root",
          str(root),
          "--platform",
          "macos",
          "--cli-source",
          "local",
          "--prepared-state",
          str(state_path),
        ],
      )
      self.assertEqual(result.returncode, 2, result.stderr)
      summary = json.loads((root / "summary.json").read_text(encoding="utf-8"))
      self.assertFalse(summary["run_ok"])
      self.assertEqual(summary["failure_stage"], "blocked")
      self.assertEqual(summary["blocked_reason"], "platform_not_prepared")
      self.assertEqual(summary["evidence"]["cli"]["source"], "local")

  def test_downlink_metrics_period_summary_rejects_sample_interval(self) -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
      root = Path(temp_dir) / "performance"
      result = self.run_tool(
        "performance.py",
        [
          "--case",
          "downlink-metrics-period-summary",
          "--artifact-root",
          str(root),
          "--dry-run",
          "--platform",
          "macos",
          "--app-id",
          "app",
          "--endpoint",
          "https://endpoint.example",
          "--remote-id",
          "device",
          "--token",
          "secret-token",
          "--sample-interval-seconds",
          "5",
        ],
      )
      self.assertEqual(result.returncode, 3, result.stderr)
      summary = json.loads((root / "summary.json").read_text(encoding="utf-8"))
      self.assertFalse(summary["run_ok"])
      self.assertEqual(summary["failure_stage"], "invalid_args")
      self.assertIn("sample-interval", summary["blocked_reason"])

  def test_downlink_metrics_self_test_rejects_non_local_cli_options(self) -> None:
    cases = (
      ["--cli-source", "npm"],
      ["--cli-source", "path", "--cli-path", "devtools.js"],
      ["--cli-path", "devtools.js"],
      ["--cli-npm-spec", "tirtc-devtools-cli@latest"],
    )
    for options in cases:
      with self.subTest(options=options), tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir) / "performance"
        result = self.run_tool(
          "performance.py",
          [
            "--case",
            "downlink-metrics-period-summary",
            "--self-test",
            "--artifact-root",
            str(root),
            "--platform",
            "macos",
            *options,
          ],
        )
        self.assertEqual(result.returncode, 3, result.stderr)
        summary = json.loads((root / "summary.json").read_text(encoding="utf-8"))
        self.assertFalse(summary["run_ok"])
        self.assertEqual(summary["failure_stage"], "invalid_args")
        self.assertIn("repo-local DevTools CLI", summary["blocked_reason"])

  def test_downlink_metrics_self_test_does_not_accept_execution_mode_option(self) -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
      root = Path(temp_dir) / "performance"
      result = self.run_tool(
        "performance.py",
        [
          "--case",
          "downlink-metrics-period-summary",
          "--self-test",
          "--artifact-root",
          str(root),
          "--platform",
          "macos",
          "--execution-mode",
          "debug",
        ],
      )
      self.assertEqual(result.returncode, 3, result.stderr)
      self.assertIn("unrecognized arguments: --execution-mode debug", result.stderr)
      self.assertFalse((root / "summary.json").exists())

  def test_generated_public_example_commands_do_not_require_repo_scripts(self) -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
      root = Path(temp_dir) / "public_example"
      self.sync_public_example(root)
      self.assertFalse((root.parent / "scripts").exists())
      for entry in ("smoke.py", "integration.py"):
        result = self.run_public_tool(root, entry, ["--help"])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--cli-source", result.stdout)
        artifact_root = root / ".build" / entry.removesuffix(".py") / "preflight"
        result = self.run_public_tool(root, entry, ["--platform", "macos", "--artifact-root", str(artifact_root)])
        self.assertEqual(result.returncode, 2, result.stderr)
        summary = json.loads((artifact_root / "summary.json").read_text(encoding="utf-8"))
        self.assertFalse(summary["run_ok"])
        self.assertEqual(summary["failure_stage"], "blocked")
        self.assertIn(summary["blocked_reason"], {"prepared_state_missing", "missing_environment:TIRTC_ACCESS_KEY_ID,TIRTC_SECRET_KEY_ID,TIRTC_APP_ID,TIRTC_DEVICE_ID,TIRTC_DEVICE_SECRET_KEY,TIRTC_ENDPOINT,TIRTC_OPEN_API_ENDPOINT"})
        self.assertNotIn("legacy_runner", summary["blocked_reason"])
      for entry in ("performance.py", "stability.py", "stress.py"):
        artifact_root = root / ".build" / entry.removesuffix(".py")
        result = self.run_public_tool(root, entry, ["--dry-run", "--artifact-root", str(artifact_root)])
        self.assertEqual(result.returncode, 0, result.stderr)
        summary = json.loads((artifact_root / "summary.json").read_text(encoding="utf-8"))
        self.assertTrue(summary["run_ok"])
        self.assertEqual(summary["evidence"]["cli"]["source"], "npm")

  def test_first_slice_mobile_non_dry_run_is_blocked(self) -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
      root = Path(temp_dir) / "stress"
      result = self.run_tool("stress.py", ["--platform", "android", "--device-id", "android", "--artifact-root", str(root)])
      self.assertEqual(result.returncode, 2, result.stderr)
      summary = json.loads((root / "summary.json").read_text(encoding="utf-8"))
      self.assertFalse(summary["run_ok"])
      self.assertEqual(summary["failure_stage"], "blocked")
      self.assertEqual(summary["blocked_reason"], "stress_mobile_execution_not_implemented")

  def test_smoke_pass_requires_counterpart_markers_and_log_upload(self) -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
      root = Path(temp_dir) / "smoke"
      summary = base_summary(
        entry="smoke",
        run_id="smoke-test",
        platform="macos",
        artifact_root=root,
        cli={"source": "npm"},
        mode="real",
        started_at=now_iso(),
      )
      summary["run_ok"] = True
      summary["evidence"].update(
        {
          "ui_flow": {"status": "passed"},
          "required_markers": ["source_started"],
          "observed_markers": [],
          "av_output_observed": True,
          "log_upload": {"required": True, "status": "failed", "log_id": None},
          "teardown_ok": True,
          "counterpart_summary_path": None,
        }
      )
      self.assertEqual(finish_summary(root, summary), 4)
      written = json.loads((root / "summary.json").read_text(encoding="utf-8"))
      self.assertFalse(written["run_ok"])
      self.assertFalse(written["evidence"]["summary_schema_valid"])

  def test_integration_pass_requires_layer_evidence_log_upload_and_audio_cases(self) -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
      root = Path(temp_dir) / "integration"
      summary = base_summary(
        entry="integration",
        run_id="integration-test",
        platform="macos",
        artifact_root=root,
        cli={"source": "npm"},
        mode="real",
        started_at=now_iso(),
      )
      summary["run_ok"] = True
      summary["evidence"].update(
        {
          "scenario_results": [{"status": "passed"}],
          "audio_case_results": [{"status": "passed", "evidence_path": "case/summary.json"}],
          "av_contract_ok": True,
          "log_upload": {"required": True, "status": "failed", "log_id": None},
          "teardown_ok": True,
        }
      )
      self.assertEqual(finish_summary(root, summary), 4)
      written = json.loads((root / "summary.json").read_text(encoding="utf-8"))
      self.assertFalse(written["run_ok"])
      self.assertFalse(written["evidence"]["summary_schema_valid"])

  def test_real_public_summary_writes_current_pointer(self) -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
      root = Path(temp_dir) / "integration" / "integration-test-run"
      summary = base_summary(
        entry="integration",
        run_id="integration-test-run",
        platform="macos",
        artifact_root=root,
        cli={"source": "npm"},
        mode="real",
        started_at=now_iso(),
      )
      summary["run_ok"] = True
      summary["evidence"].update(
        {
          "scenario_results": [{"status": "passed"}],
          "audio_case_results": [{"status": "passed", "evidence_path": "case/summary.json"}],
          "av_contract_ok": True,
          "log_upload": {"required": True, "status": "passed", "log_id": "log-123"},
          "teardown_ok": True,
        }
      )
      self.assertEqual(finish_summary(root, summary), 0)

      current = root.parent / "current/summary.json"
      self.assertTrue(current.is_file())
      written = json.loads(current.read_text(encoding="utf-8"))
      self.assertEqual(written["run_id"], "integration-test-run")


if __name__ == "__main__":
  unittest.main()
