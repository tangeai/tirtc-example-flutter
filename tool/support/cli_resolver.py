from __future__ import annotations

import json
import os
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Sequence

from .paths import find_repo_root


DEFAULT_NPM_SPEC = "tirtc-devtools-cli@latest"


@dataclass(frozen=True)
class ResolvedCli:
  source: str
  command: list[str]
  npm_spec: str | None
  path: str | None
  version: str | None
  available: bool
  blocked_reason: str | None = None

  def evidence(self) -> dict[str, object]:
    return {
      "source": self.source,
      "command": self.command,
      "npm_spec": self.npm_spec,
      "path": self.path,
      "version": self.version,
      "available": self.available,
    }


class CliResolutionError(ValueError):
  def __init__(self, message: str, *, blocked_reason: str, exit_code: int = 2) -> None:
    super().__init__(message)
    self.blocked_reason = blocked_reason
    self.exit_code = exit_code


def _repo_local_cli() -> Path | None:
  explicit_root = os.environ.get("TIRTC_REPO_ROOT")
  root = Path(explicit_root) if explicit_root else find_repo_root()
  if root is None:
    return None
  return root / "cli/devtools/bin/tirtc-devtools-cli.js"


def _path_command(path_value: str) -> list[str]:
  path = Path(path_value)
  return ["node", str(path)] if path.suffix == ".js" else [str(path)]


def _probe(command: Sequence[str]) -> tuple[bool, str | None]:
  try:
    result = subprocess.run(
      [*command, "--version"],
      stdout=subprocess.PIPE,
      stderr=subprocess.STDOUT,
      text=True,
      check=False,
      timeout=30,
    )
  except (OSError, subprocess.TimeoutExpired):
    return False, None
  if result.returncode != 0:
    return False, None
  first_line = result.stdout.strip().splitlines()[0] if result.stdout.strip() else None
  return True, first_line


def resolve_cli(
  *,
  cli_source: str | None = None,
  cli_path: str | None = None,
  cli_npm_spec: str | None = None,
  check_available: bool = False,
) -> ResolvedCli:
  env_source = os.environ.get("TIRTC_DEVTOOLS_CLI_SOURCE")
  env_path = os.environ.get("TIRTC_DEVTOOLS_CLI")
  env_npm_spec = os.environ.get("TIRTC_DEVTOOLS_CLI_NPM_SPEC")

  source = cli_source or env_source
  if source is None and env_path:
    source = "path"
  if source is None:
    local_path = _repo_local_cli()
    source = "local" if local_path is not None and local_path.is_file() else "npm"
  npm_spec = cli_npm_spec or env_npm_spec or DEFAULT_NPM_SPEC
  path_value = cli_path or env_path

  if source not in {"npm", "local", "path"}:
    raise CliResolutionError(
      f"unsupported CLI source: {source}",
      blocked_reason="invalid_devtools_cli_source",
      exit_code=3,
    )
  if source == "path" and not path_value:
    raise CliResolutionError(
      "--cli-path or TIRTC_DEVTOOLS_CLI is required for --cli-source path",
      blocked_reason="missing_devtools_cli_path",
      exit_code=3,
    )
  if cli_path and source != "path":
    raise CliResolutionError(
      "--cli-path is only valid with --cli-source path",
      blocked_reason="conflicting_devtools_cli_options",
      exit_code=3,
    )

  if source == "npm":
    command = ["npx", "--yes", npm_spec]
    resolved = ResolvedCli(source, command, npm_spec, None, None, not check_available)
  elif source == "local":
    local_path = _repo_local_cli()
    if local_path is None or not local_path.is_file():
      raise CliResolutionError(
        f"local DevTools CLI is missing: {local_path}",
        blocked_reason="local_devtools_cli_missing",
        exit_code=2,
      )
    command = _path_command(str(local_path))
    resolved = ResolvedCli(source, command, None, str(local_path), None, not check_available)
  else:
    assert path_value is not None
    command = _path_command(path_value)
    resolved = ResolvedCli(source, command, None, path_value, None, not check_available)

  if not check_available:
    return resolved

  available, version = _probe(resolved.command)
  if not available:
    reason = "devtools_cli_unavailable" if source == "npm" else "local_devtools_cli_missing"
    raise CliResolutionError(
      "DevTools CLI is unavailable",
      blocked_reason=reason,
      exit_code=2,
    )
  return ResolvedCli(source, resolved.command, resolved.npm_spec, resolved.path, version, True)


def command_env(resolved: ResolvedCli) -> dict[str, str]:
  env = os.environ.copy()
  env["TIRTC_DEVTOOLS_CLI_COMMAND_JSON"] = json.dumps(resolved.command, separators=(",", ":"))
  if resolved.source == "path" and resolved.path:
    env["TIRTC_DEVTOOLS_CLI"] = resolved.path
  elif resolved.source == "local" and resolved.path:
    env["TIRTC_DEVTOOLS_CLI"] = resolved.path
    env["TIRTC_DEVTOOLS_CLI_SOURCE"] = "local"
  else:
    env.pop("TIRTC_DEVTOOLS_CLI", None)
    env["TIRTC_DEVTOOLS_CLI_SOURCE"] = "npm"
    env["TIRTC_DEVTOOLS_CLI_NPM_SPEC"] = resolved.npm_spec or DEFAULT_NPM_SPEC
  return env
