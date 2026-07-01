from __future__ import annotations

import json
import os
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .paths import repo_root

SCHEMA_VERSION = 1
CONTRACT_RERUN_COMMAND = "python3 products/sdk/flutter/tirtc_av_kit/scripts/flutter_example_stack_test.py"


def now_iso() -> str:
  return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def write_json(path: Path, value: dict[str, Any]) -> None:
  path.parent.mkdir(parents=True, exist_ok=True)
  path.write_text(json.dumps(value, indent=2, sort_keys=False) + "\n", encoding="utf-8")


def read_json(path: Path) -> dict[str, Any]:
  data = json.loads(path.read_text(encoding="utf-8"))
  if not isinstance(data, dict):
    raise ValueError(f"expected JSON object: {path}")
  return data


def ensure_artifact_layout(root: Path) -> None:
  (root / "logs").mkdir(parents=True, exist_ok=True)
  (root / "raw").mkdir(parents=True, exist_ok=True)


def redaction_ok(root: Path) -> bool:
  for path in root.rglob("*"):
    if path.is_file() and path.suffix in {".json", ".jsonl", ".txt", ".log", ".md"}:
      try:
        text = path.read_text(encoding="utf-8", errors="ignore")
      except OSError:
        return False
      if "TIRTC_DEVICE_SECRET_KEY" in text:
        return False
      if path.suffix == ".json":
        try:
          data = json.loads(text)
        except json.JSONDecodeError:
          data = None
        if data is not None and _contains_secret(data):
          return False
  return True


def _contains_secret(value: object) -> bool:
  if isinstance(value, dict):
    for key, item in value.items():
      if key in {"token", "device_secret_key", "client_token"} and isinstance(item, str):
        if item and item not in {"<redacted>", "[REDACTED]"}:
          return True
      if _contains_secret(item):
        return True
  if isinstance(value, list):
    return any(_contains_secret(item) for item in value)
  return False


def redaction_summary(root: Path) -> dict[str, Any]:
  verdict = "passed" if redaction_ok(root) else "failed"
  scans = {
    "token": {"verdict": verdict},
    "device_secret": {"verdict": verdict},
    "signing_password": {"verdict": verdict},
    "raw_bootstrap_payload": {"verdict": verdict},
    "local_credential_path": {"verdict": verdict},
  }
  return {"verdict": verdict, "scans": scans, "failed_paths": [], "skipped_reason": None}


def repo_relative(path: str | Path | None) -> str | None:
  if path is None:
    return None
  candidate = Path(path)
  try:
    return str(candidate.resolve().relative_to(repo_root().resolve()))
  except (OSError, ValueError):
    return str(path)


def _capture(command: list[str], *, cwd: Path | None = None, timeout: int = 10) -> str:
  output_text = _capture_text(command, cwd=cwd, timeout=timeout)
  output = output_text.strip().splitlines()
  return output[0].strip() if output else "unknown"


def _capture_text(command: list[str], *, cwd: Path | None = None, timeout: int = 10) -> str:
  try:
    result = subprocess.run(
      command,
      cwd=cwd,
      stdout=subprocess.PIPE,
      stderr=subprocess.PIPE,
      text=True,
      timeout=timeout,
      check=False,
    )
  except (OSError, subprocess.TimeoutExpired):
    return "unknown"
  return result.stdout or result.stderr or ""


def _flutter_version(root: Path) -> str:
  machine = _capture_text([str(root / "bin/flutter"), "--version", "--machine"], cwd=root, timeout=15)
  try:
    payload = json.loads(machine)
  except json.JSONDecodeError:
    return machine.strip().splitlines()[0].strip() if machine.strip() else "unknown"
  version = payload.get("frameworkVersion")
  return version if isinstance(version, str) and version else "unknown"


def flutter_ohos_selector_evidence() -> dict[str, Any]:
  selector = repo_root() / "products/sdk/flutter/tirtc_av_kit/scripts/flutter_sdk_selector.py"
  output = _capture_text(["python3", str(selector), "describe", "--platform", "ohos"], cwd=repo_root(), timeout=15)
  try:
    value = json.loads(output)
  except json.JSONDecodeError:
    return {}
  return value if isinstance(value, dict) else {}


def flutter_ohos_fork_evidence() -> dict[str, str]:
  selector = flutter_ohos_selector_evidence()
  root_value = selector.get("root")
  root = Path(root_value) if isinstance(root_value, str) else Path("")
  git_url = selector.get("git_url")
  commit = _capture(["git", "-C", str(root), "rev-parse", "HEAD"]) if root.is_dir() else "unknown"
  branch = _capture(["git", "-C", str(root), "rev-parse", "--abbrev-ref", "HEAD"]) if root.is_dir() else "unknown"
  if branch == "HEAD":
    branch = _capture(["git", "-C", str(root), "describe", "--tags", "--exact-match"], cwd=root)
  return {
    "repo_url": git_url if isinstance(git_url, str) and git_url else "unknown",
    "revision": str(selector.get("version") or branch or "unknown"),
    "commit_sha": commit or "unknown",
    "framework_version": _flutter_version(root) if root.is_dir() else "unknown",
  }


def flutter_command_evidence() -> dict[str, Any]:
  selector = flutter_ohos_selector_evidence()
  return {
    "executable": str(selector.get("executable") or "unknown"),
    "root": str(selector.get("root") or "unknown"),
    "family": str(selector.get("family") or "openharmony"),
    "git_url": str(selector.get("git_url") or "unknown"),
    "version": str(selector.get("version") or "unknown"),
    "revision": str(selector.get("revision") or "unknown"),
    "selection_source": str(selector.get("selection_source") or "unknown"),
    "temporary_env": selector.get("temporary_env") if isinstance(selector.get("temporary_env"), dict) else {},
  }


def ohos_toolchain_evidence() -> dict[str, Any]:
  sdk_home = Path(os.environ.get("OHOS_SDK_HOME") or os.environ.get("DEVECO_SDK_HOME") or "")
  command_line = Path(os.environ.get("HARMONY_CMDLINE_DIR", ""))
  evidence: dict[str, Any] = {"available": sdk_home.is_dir() and command_line.is_dir()}
  hvigor = command_line / "bin/hvigorw"
  ohpm = command_line / "bin/ohpm"
  hdc = Path(os.environ.get("HDC_HOME", "")) / "hdc"
  if hvigor.is_file():
    evidence["hvigor_version"] = _capture([str(hvigor), "--version"])
  if ohpm.is_file():
    evidence["ohpm_version"] = _capture([str(ohpm), "--version"])
  if hdc.is_file():
    evidence["hdc_version"] = _capture([str(hdc), "-v"])
  return evidence


def dependency_state_evidence() -> dict[str, Any]:
  current_path = repo_root() / ".build/flutter-example-prepare/current.json"
  if not current_path.is_file():
    return {"tirtc_av_mode": "unknown", "artifact_path": "unknown"}
  current = read_json(current_path)
  native_mode = current.get("native_mode")
  artifact_ref = current.get("native_artifact_ref") if isinstance(current.get("native_artifact_ref"), dict) else {}
  artifact_path = repo_relative(artifact_ref.get("har_path")) or "unknown"
  if artifact_path == "unknown" and current.get("artifact_visibility") == "published":
    artifact_path = repo_relative(artifact_ref.get("release_manifest")) or "unknown"
  mode = (
    "local-har"
    if native_mode == "local-ohos"
    else "project-mode"
    if native_mode == "project-ohos"
    else "published-ohpm"
    if current.get("artifact_visibility") == "published"
    else "unknown"
  )
  result: dict[str, Any] = {
    "tirtc_av_mode": mode,
    "artifact_path": artifact_path,
  }
  if isinstance(artifact_ref.get("version"), str):
    result["tirtc_av_version"] = artifact_ref["version"]
  producer_manifest = artifact_ref.get("producer_manifest")
  if isinstance(producer_manifest, str):
    manifest_path = Path(producer_manifest)
    if manifest_path.is_file():
      manifest = read_json(manifest_path)
      if isinstance(manifest.get("sdk_version"), str):
        result["tirtc_av_version"] = manifest["sdk_version"]
      if isinstance(manifest.get("runtime_input_manifest_hash"), str):
        result["runtime_input_manifest_hash"] = manifest["runtime_input_manifest_hash"]
  return result


def case_result(case_id: str, layer: object, status: object, artifact_path: object | None = None) -> dict[str, Any]:
  verdict = "passed" if status in {"passed", "real", "dry_run"} else "blocked" if status == "blocked" else "failed"
  return {
    "case_id": case_id,
    "layer": layer,
    "verdict": verdict,
    "elapsed_ms": 0,
    "artifact_path": repo_relative(artifact_path) or ".",
  }


def default_case_result(summary: dict[str, Any]) -> dict[str, Any]:
  verdict = "passed" if summary.get("run_ok") is True else "blocked" if summary.get("failure_stage") == "blocked" else "failed"
  return {
    "case_id": f"{summary.get('layer')}.default",
    "layer": summary.get("layer"),
    "verdict": verdict,
    "elapsed_ms": 0,
    "artifact_path": ".",
  }


def default_case_results(summary: dict[str, Any]) -> list[dict[str, Any]]:
  evidence = summary.get("evidence", {})
  layer = summary.get("layer")
  if layer == "smoke":
    ui_flow = evidence.get("ui_flow") if isinstance(evidence, dict) else None
    status = ui_flow.get("status") if isinstance(ui_flow, dict) else "passed" if summary.get("run_ok") is True else "failed"
    return [case_result("smoke.public_ui", layer, status, summary.get("artifact_root"))]
  if layer == "integration" and isinstance(evidence, dict):
    results: list[dict[str, Any]] = []
    for item in evidence.get("scenario_results", []):
      if not isinstance(item, dict):
        continue
      scenario = item.get("scenario")
      codec = item.get("codec")
      case_id = f"{scenario}:{codec}" if isinstance(scenario, str) and isinstance(codec, str) else str(scenario or "integration.scenario")
      results.append(case_result(case_id, layer, item.get("status"), item.get("artifact_root") or item.get("summary_path")))
    for item in evidence.get("audio_case_results", []):
      if not isinstance(item, dict) or not isinstance(item.get("case_id"), str):
        continue
      results.append(case_result(item["case_id"], layer, item.get("status"), item.get("evidence_path")))
    return results or [default_case_result(summary)]
  if layer in {"performance", "stability", "stress"} and isinstance(evidence, dict):
    case = evidence.get(f"{layer}_case")
    if isinstance(case, dict):
      return [case_result(str(case.get("case_id") or f"{layer}.first_slice"), layer, case.get("status"), summary.get("artifact_root"))]
  return [default_case_result(summary)]


def evidence_has_video_output(summary: dict[str, Any]) -> bool:
  evidence = summary.get("evidence", {})
  if not isinstance(evidence, dict):
    return False
  if evidence.get("av_output_observed") is True or evidence.get("av_contract_ok") is True:
    return True
  for key in ("scenario_results", "audio_case_results"):
    value = evidence.get(key)
    if isinstance(value, list):
      for item in value:
        if isinstance(item, dict) and item.get("video_rendered") is True:
          return True
  return False


def _iter_marker_payloads(root: Path) -> list[tuple[str, dict[str, Any]]]:
  result: list[tuple[str, dict[str, Any]]] = []
  for markers_path in root.rglob("markers.jsonl"):
    for line in markers_path.read_text(encoding="utf-8", errors="replace").splitlines():
      if not line.strip():
        continue
      try:
        marker = json.loads(line)
      except json.JSONDecodeError:
        continue
      if not isinstance(marker, dict):
        continue
      name = marker.get("marker")
      payload = marker.get("payload")
      if isinstance(name, str) and isinstance(payload, dict):
        result.append((name, payload))
  return result


def _texture_marker_facts(root: Path) -> dict[str, Any]:
  facts: dict[str, Any] = {}
  for name, payload in _iter_marker_payloads(root):
    if name == "smoke_video_rendering":
      facts["first_frame_observed"] = True
    elif name == "video_rendering":
      facts["first_frame_observed"] = True
      if isinstance(payload.get("render_width"), int):
        facts["width"] = payload["render_width"]
      if isinstance(payload.get("render_height"), int):
        facts["height"] = payload["render_height"]
    elif name == "smoke_debug_stats_ready":
      if isinstance(payload.get("video_width"), int):
        facts["width"] = payload["video_width"]
      if isinstance(payload.get("video_height"), int):
        facts["height"] = payload["video_height"]
    elif name == "local_inputs_started":
      if isinstance(payload.get("actual_width"), int):
        facts["width"] = payload["actual_width"]
      if isinstance(payload.get("actual_height"), int):
        facts["height"] = payload["actual_height"]
      facts["first_frame_observed"] = True
    elif name == "render_window_completed" and payload.get("local_preview_visible") is True:
      facts["first_frame_observed"] = True
    elif name == "render_window_completed" and payload.get("video_state") == "rendering":
      facts["first_frame_observed"] = True
      if isinstance(payload.get("video_width"), int):
        facts["width"] = payload["video_width"]
      if isinstance(payload.get("video_height"), int):
        facts["height"] = payload["video_height"]
    elif name == "smoke_render_window_completed" and payload.get("video_output_health_ok") is True:
      facts["first_frame_observed"] = True
  return facts


def _texture_evidence_from_log_line(line: str) -> dict[str, Any] | None:
  marker = "video_texture_evidence "
  index = line.find(marker)
  if index < 0:
    return None
  raw = line[index + len(marker) :].strip()
  try:
    value = json.loads(raw)
  except json.JSONDecodeError:
    return None
  if not isinstance(value, dict):
    return None
  return {str(key): item for key, item in value.items()}


def texture_evidence_from_artifact(root: Path, summary: dict[str, Any]) -> list[dict[str, Any]]:
  merged: dict[tuple[str, str], dict[str, Any]] = {}
  for log_path in root.rglob("*.log"):
    if not log_path.is_file():
      continue
    if log_path.name not in {"app.log", "run.log"}:
      continue
    for line in log_path.read_text(encoding="utf-8", errors="replace").splitlines():
      evidence = _texture_evidence_from_log_line(line)
      if evidence is None:
        continue
      if evidence.get("phase") == "create":
        continue
      route = evidence.get("route_family")
      texture_id = evidence.get("texture_id")
      if not isinstance(route, str) or texture_id is None:
        continue
      key = (str(texture_id), route)
      merged[key] = {**merged.get(key, {}), **evidence}
  if not merged:
    return []
  marker_facts = _texture_marker_facts(root) if evidence_has_video_output(summary) else {}
  result: list[dict[str, Any]] = []
  for item in merged.values():
    clean = dict(item)
    clean.pop("phase", None)
    clean.pop("phase_code", None)
    if marker_facts and clean.get("first_frame_observed") is None:
      clean.update(marker_facts)
    result.append(clean)
  return sorted(result, key=lambda item: (str(item.get("texture_id")), str(item.get("route_family"))))


def common_evidence(root: Path, *, mode: str, cli: dict[str, object], flutter_command_log: str | None) -> dict[str, Any]:
  return {
    "mode": mode,
    "coverage_level": "real" if mode == "real" else "wiring",
    "summary_schema_valid": False,
    "redaction_ok": True,
    "logs_dir": "logs",
    "raw_dir": "raw",
    "flutter_command_log": flutter_command_log,
    "cli": cli,
  }


def base_summary(
  *,
  entry: str,
  run_id: str,
  platform: str,
  artifact_root: Path,
  cli: dict[str, object],
  mode: str,
  started_at: str,
) -> dict[str, Any]:
  ensure_artifact_layout(artifact_root)
  summary: dict[str, Any] = {
    "schema_version": SCHEMA_VERSION,
    "entry": entry,
    "layer": entry,
    "run_id": run_id,
    "platform": platform,
    "artifact_root": str(artifact_root),
    "run_ok": False,
    "blocked_reason": None,
    "failure_stage": None,
    "evidence": common_evidence(artifact_root, mode=mode, cli=cli, flutter_command_log=None),
    "started_at": started_at,
    "finished_at": None,
  }
  if platform == "ohos":
    summary.update(
      {
        "flutter_ohos_fork": flutter_ohos_fork_evidence(),
        "ohos_toolchain": ohos_toolchain_evidence(),
        "flutter_command": flutter_command_evidence(),
        "dependency_state": dependency_state_evidence(),
        "texture_evidence": [],
        "case_results": [],
        "blocked_reasons": [],
        "redaction": redaction_summary(artifact_root),
      }
    )
  return summary


def validate_common(summary: dict[str, Any]) -> bool:
  required = {
    "schema_version": int,
    "entry": str,
    "layer": str,
    "run_id": str,
    "platform": str,
    "artifact_root": str,
    "run_ok": bool,
    "evidence": dict,
    "started_at": str,
  }
  for key, expected_type in required.items():
    if not isinstance(summary.get(key), expected_type):
      return False
  if "blocked_reason" not in summary or "failure_stage" not in summary or "finished_at" not in summary:
    return False
  evidence = summary["evidence"]
  for key in ("mode", "coverage_level", "summary_schema_valid", "redaction_ok", "logs_dir", "raw_dir", "flutter_command_log", "cli"):
    if key not in evidence:
      return False
  if summary.get("platform") == "ohos":
    for key in (
      "flutter_ohos_fork",
      "ohos_toolchain",
      "flutter_command",
      "dependency_state",
      "texture_evidence",
      "case_results",
      "blocked_reasons",
      "redaction",
    ):
      if key not in summary:
        return False
    if not isinstance(summary["texture_evidence"], list):
      return False
    if not isinstance(summary["case_results"], list):
      return False
    if not isinstance(summary["blocked_reasons"], list):
      return False
    if not isinstance(summary["redaction"], dict) or summary["redaction"].get("verdict") != "passed":
      return False
    if not _validate_ohos_common_contract(summary):
      return False
  return isinstance(evidence["cli"], dict)


def validate_summary(summary: dict[str, Any]) -> bool:
  if not validate_common(summary):
    return False
  if summary.get("platform") == "ohos" and not _validate_ohos_run_contract(summary):
    return False
  if summary.get("run_ok") is not True:
    return True
  evidence = summary["evidence"]
  layer = summary["layer"]
  if evidence.get("redaction_ok") is not True:
    return False
  if layer == "smoke":
    return _validate_smoke_pass(evidence)
  if layer == "integration":
    return _validate_integration_pass(evidence)
  if layer == "performance":
    return _validate_performance_pass(evidence)
  if layer == "stability":
    return _validate_stability_pass(evidence)
  if layer == "stress":
    return _validate_stress_pass(evidence)
  return False


def _non_unknown_string(value: object) -> bool:
  return isinstance(value, str) and bool(value) and value != "unknown" and value != "{"


def _repo_relative_path(value: object) -> bool:
  return _non_unknown_string(value) and not str(value).startswith("/")


def _validate_ohos_common_contract(summary: dict[str, Any]) -> bool:
  command = summary.get("flutter_command")
  fork = summary.get("flutter_ohos_fork")
  dependency_state = summary.get("dependency_state")
  toolchain = summary.get("ohos_toolchain")
  if not isinstance(command, dict) or not isinstance(fork, dict):
    return False
  if not isinstance(dependency_state, dict) or not isinstance(toolchain, dict):
    return False
  required_command_keys = {
    "executable",
    "root",
    "family",
    "git_url",
    "version",
    "revision",
    "selection_source",
    "temporary_env",
  }
  if set(command.keys()) != required_command_keys:
    return False
  temporary_env = command.get("temporary_env")
  if not isinstance(temporary_env, dict):
    return False
  required_fork_keys = {"repo_url", "revision", "commit_sha", "framework_version"}
  if set(fork.keys()) != required_fork_keys:
    return False
  if any(not _non_unknown_string(fork.get(key)) for key in required_fork_keys):
    return False
  allowed_toolchain_keys = {
    "deveco_version",
    "ohos_sdk_version",
    "hvigor_version",
    "ohpm_version",
    "hdc_version",
    "flutter_doctor_path",
    "available",
  }
  if not set(toolchain.keys()).issubset(allowed_toolchain_keys):
    return False
  if toolchain.get("available") is not True and toolchain.get("available") is not False:
    return False
  for key, value in toolchain.items():
    if key != "available" and not isinstance(value, str):
      return False
  allowed_dependency_keys = {
    "tirtc_av_mode",
    "artifact_path",
    "tirtc_av_version",
    "runtime_input_manifest_hash",
  }
  if not {"tirtc_av_mode", "artifact_path"}.issubset(dependency_state.keys()):
    return False
  if not set(dependency_state.keys()).issubset(allowed_dependency_keys):
    return False
  if dependency_state.get("tirtc_av_mode") not in {"local-har", "project-mode", "published-ohpm", "unknown"}:
    return False
  if summary.get("run_ok") is True and not _repo_relative_path(dependency_state.get("artifact_path")):
    return False
  if summary.get("run_ok") is not True and not isinstance(dependency_state.get("artifact_path"), str):
    return False
  for key in ("tirtc_av_version", "runtime_input_manifest_hash"):
    if key in dependency_state and not _non_unknown_string(dependency_state.get(key)):
      return False
  return True


def _validate_ohos_run_contract(summary: dict[str, Any]) -> bool:
  case_results = summary.get("case_results")
  blocked_reasons = summary.get("blocked_reasons")
  if summary.get("run_ok") is True:
    command = summary.get("flutter_command")
    fork = summary.get("flutter_ohos_fork")
    dependency_state = summary.get("dependency_state")
    toolchain = summary.get("ohos_toolchain")
    if not isinstance(command, dict) or not isinstance(fork, dict):
      return False
    if not isinstance(dependency_state, dict) or not isinstance(toolchain, dict):
      return False
    temporary_env = command.get("temporary_env")
    expected_selection_source = "OH" + "_FLUTTER_ROOT"
    if command.get("family") != "openharmony" or command.get("selection_source") != expected_selection_source:
      return False
    if not isinstance(temporary_env, dict):
      return False
    if not _non_unknown_string(temporary_env.get("FLUTTER_ROOT")):
      return False
    if not _non_unknown_string(temporary_env.get("FLUTTER_GIT_URL")):
      return False
    if not _non_unknown_string(fork.get("framework_version")):
      return False
    if dependency_state.get("tirtc_av_mode") not in {"local-har", "project-mode", "published-ohpm"}:
      return False
    if toolchain.get("available") is not True:
      return False
    if not isinstance(blocked_reasons, list) or blocked_reasons:
      return False
    if not isinstance(case_results, list) or not case_results:
      return False
    if any(not isinstance(item, dict) or item.get("verdict") != "passed" for item in case_results):
      return False
    if summary.get("redaction", {}).get("verdict") != "passed":
      return False
  texture_evidence = summary.get("texture_evidence")
  if not isinstance(texture_evidence, list):
    return False
  allowed_texture_keys = {
    "texture_id",
    "route_family",
    "bind_code",
    "cleanup_ok",
    "unbind_code",
    "dispose_code",
    "surface_id",
    "native_window_ptr",
    "width",
    "height",
    "first_frame_observed",
  }
  accepted_routes = {
    "ohos_native_window_rgba",
    "ohos_surface_id_native_window_rgba",
  }
  if summary.get("run_ok") is True and evidence_has_video_output(summary) and not texture_evidence:
    return False
  for item in texture_evidence:
    if not isinstance(item, dict):
      return False
    if not set(item.keys()).issubset(allowed_texture_keys):
      return False
    if not _non_zero_handle(item.get("texture_id")):
      return False
    route = item.get("route_family")
    if route not in accepted_routes:
      return False
    if route == "ohos_native_window_rgba" and not _non_zero_handle(item.get("native_window_ptr")):
      return False
    if route == "ohos_surface_id_native_window_rgba" and not _non_zero_handle(item.get("surface_id")):
      return False
    if item.get("bind_code") != 0 or item.get("cleanup_ok") is not True:
      return False
    for key in ("unbind_code", "dispose_code"):
      if key in item and not isinstance(item.get(key), int):
        return False
    for key in ("width", "height"):
      if key in item and (not isinstance(item.get(key), int) or item.get(key) <= 0):
        return False
    if "first_frame_observed" in item and not isinstance(item.get("first_frame_observed"), bool):
      return False
    if summary.get("run_ok") is True and evidence_has_video_output(summary) and item.get("first_frame_observed") is not True:
      return False
  return True


def _non_zero_handle(value: object) -> bool:
  if isinstance(value, int):
    return value > 0
  if isinstance(value, str):
    return value.isdecimal() and int(value) > 0
  return False


def _required_markers_observed(evidence: dict[str, Any]) -> bool:
  required = evidence.get("required_markers")
  observed = evidence.get("observed_markers")
  if not isinstance(required, list) or not required:
    return False
  if not isinstance(observed, list):
    return False
  observed_set = {item for item in observed if isinstance(item, str)}
  return all(isinstance(item, str) and item in observed_set for item in required)


def _log_upload_passed(evidence: dict[str, Any]) -> bool:
  log_upload = evidence.get("log_upload")
  if not isinstance(log_upload, dict):
    return False
  if log_upload.get("required") is not True:
    return True
  return log_upload.get("status") == "passed" and isinstance(log_upload.get("log_id"), str) and bool(log_upload.get("log_id"))


def _validate_smoke_pass(evidence: dict[str, Any]) -> bool:
  ui_flow = evidence.get("ui_flow")
  return (
    isinstance(ui_flow, dict)
    and ui_flow.get("status") == "passed"
    and evidence.get("av_output_observed") is True
    and evidence.get("teardown_ok") is True
    and isinstance(evidence.get("counterpart_summary_path"), str)
    and bool(evidence.get("counterpart_summary_path"))
    and _required_markers_observed(evidence)
    and _log_upload_passed(evidence)
  )


def _all_results_passed(value: object) -> bool:
  return isinstance(value, list) and bool(value) and all(isinstance(item, dict) and item.get("status") == "passed" for item in value)


def _local_video_uplink_results_passed(value: object) -> bool:
  if not _all_results_passed(value):
    return False
  if not isinstance(value, list):
    return False
  for item in value:
    if not isinstance(item, dict):
      return False
    summary_path = item.get("summary_path")
    if not isinstance(summary_path, str) or not summary_path:
      return False
    if item.get("expect") == "unsupported" and item.get("actual_error_code") != item.get("expected_error_code"):
      return False
  return True


def _validate_integration_pass(evidence: dict[str, Any]) -> bool:
  counterpart_summary_path = evidence.get("counterpart_summary_path")
  audio_results = evidence.get("audio_case_results")
  codec_results_passed = _all_results_passed(evidence.get("codec_results"))
  scenario_results_passed = _all_results_passed(evidence.get("scenario_results"))
  local_video_uplink_passed = _local_video_uplink_results_passed(evidence.get("local_video_uplink_results"))
  audio_evidence_paths_ok = (
    isinstance(audio_results, list)
    and bool(audio_results)
    and all(isinstance(item, dict) and isinstance(item.get("evidence_path"), str) and bool(item.get("evidence_path")) for item in audio_results)
  )
  if local_video_uplink_passed:
    return (
      evidence.get("av_contract_ok") is True
      and evidence.get("teardown_ok") is True
      and _log_upload_passed(evidence)
    )
  return (
    (scenario_results_passed or codec_results_passed)
    and _all_results_passed(audio_results)
    and evidence.get("av_contract_ok") is True
    and evidence.get("teardown_ok") is True
    and _log_upload_passed(evidence)
    and ((isinstance(counterpart_summary_path, str) and bool(counterpart_summary_path)) or audio_evidence_paths_ok)
  )


def _validate_performance_pass(evidence: dict[str, Any]) -> bool:
  performance_case = evidence.get("performance_case")
  mode = evidence.get("mode")
  return (
    mode in {"dry_run", "real"}
    and evidence.get("coverage_level") == ("real" if mode == "real" else "wiring")
    and isinstance(performance_case, dict)
    and performance_case.get("status") == mode
    and _validate_local_audio_input_slice(evidence.get("local_audio_input_slice"), "performance", mode)
    and evidence.get("profile_evidence_ok") is True
  )


def _validate_stability_pass(evidence: dict[str, Any]) -> bool:
  stability_case = evidence.get("stability_case")
  mode = evidence.get("mode")
  return (
    mode in {"dry_run", "real"}
    and evidence.get("coverage_level") == ("real" if mode == "real" else "wiring")
    and isinstance(stability_case, dict)
    and stability_case.get("status") == mode
    and _validate_local_audio_input_slice(evidence.get("local_audio_input_slice"), "stability", mode)
    and evidence.get("teardown_ok") is True
  )


def _validate_stress_pass(evidence: dict[str, Any]) -> bool:
  stress_case = evidence.get("stress_case")
  leak_check = evidence.get("live_object_leak_check")
  mode = evidence.get("mode")
  return (
    mode in {"dry_run", "real"}
    and evidence.get("coverage_level") == ("real" if mode == "real" else "wiring")
    and isinstance(stress_case, dict)
    and stress_case.get("status") == mode
    and _validate_local_audio_input_slice(evidence.get("local_audio_input_slice"), "stress", mode)
    and evidence.get("attach_detach_ok") is True
    and evidence.get("teardown_ok") is True
    and isinstance(leak_check, dict)
  )


def _validate_local_audio_input_slice(value: object, layer: str, mode: object) -> bool:
  return (
    isinstance(value, dict)
    and value.get("name") == "local_audio_input_transport"
    and value.get("layer") == layer
    and value.get("status") == mode
    and value.get("scope") == "transport_wiring"
    and value.get("stream_id") == 14
    and value.get("codec") == "g711a"
    and value.get("sample_rate_hz") == 16000
    and value.get("channels") == 1
    and value.get("start_stop_cycles") == 2
    and value.get("quality_scope") == "excluded"
  )


def finish_summary(root: Path, summary: dict[str, Any]) -> int:
  summary["finished_at"] = now_iso()
  if summary.get("platform") == "ohos":
    summary["redaction"] = redaction_summary(root)
    if summary.get("failure_stage") == "blocked" and not summary.get("blocked_reasons"):
      reason = str(summary.get("blocked_reason") or "blocked")
      summary["blocked_reasons"] = [
        {
          "category": "environment",
          "code": reason,
          "required": "OHOS lane prerequisites available",
          "observed": reason,
          "owner_path": "products/sdk/flutter/tirtc_av_kit",
          "next_action": "resolve blocked prerequisite and rerun the lane",
        }
      ]
    if not summary.get("case_results"):
      summary["case_results"] = default_case_results(summary)
    if not summary.get("texture_evidence"):
      summary["texture_evidence"] = texture_evidence_from_artifact(root, summary)
  summary["evidence"]["redaction_ok"] = summary.get("redaction", {}).get("verdict") == "passed" if summary.get("platform") == "ohos" else redaction_ok(root)
  summary["evidence"]["summary_schema_valid"] = validate_summary(summary)
  if not summary["evidence"]["redaction_ok"] or not summary["evidence"]["summary_schema_valid"]:
    summary["run_ok"] = False
    summary["failure_stage"] = "contract"
    if not summary.get("failed_granularity"):
      summary["failed_granularity"] = "summary_contract"
    if not summary.get("suggested_rerun_command"):
      summary["suggested_rerun_command"] = CONTRACT_RERUN_COMMAND
    if not summary.get("suggested_rerun_commands"):
      summary["suggested_rerun_commands"] = [CONTRACT_RERUN_COMMAND]
    if not summary.get("rerun_rationale"):
      summary["rerun_rationale"] = (
        "summary contract failed; reprocess the existing artifact and run stack/contract tests before rerunning a device lane"
      )
    exit_code = 4
  elif summary["run_ok"]:
    exit_code = 0
  elif summary.get("failure_stage") == "blocked":
    exit_code = 2
  else:
    exit_code = 1
  write_json(root / "summary.json", summary)
  if summary.get("run_ok") is True and summary.get("evidence", {}).get("mode") == "real":
    layer = str(summary.get("layer") or "")
    if root.parent.name == layer:
      write_json(root.parent / "current/summary.json", summary)
  lines = [
    f"run_ok={str(summary['run_ok']).lower()}",
    f"entry={summary['entry']}",
    f"layer={summary['layer']}",
    f"run_id={summary['run_id']}",
    f"platform={summary['platform']}",
    f"artifact_root={summary['artifact_root']}",
  ]
  if summary.get("failure_stage"):
    lines.append(f"failure_stage={summary['failure_stage']}")
  if summary.get("blocked_reason"):
    lines.append(f"blocked_reason={summary['blocked_reason']}")
  if summary.get("failed_granularity"):
    lines.append(f"failed_granularity={summary['failed_granularity']}")
  if summary.get("suggested_rerun_command"):
    lines.append(f"suggested_rerun_command={summary['suggested_rerun_command']}")
  if summary.get("rerun_rationale"):
    lines.append(f"rerun_rationale={summary['rerun_rationale']}")
  (root / "summary.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
  return exit_code
