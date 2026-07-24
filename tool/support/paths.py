from __future__ import annotations

from pathlib import Path


def example_root() -> Path:
  return Path(__file__).resolve().parents[2]


def plugin_root() -> Path:
  return example_root().parent


def repo_root() -> Path:
  resolved = find_repo_root()
  if resolved is None:
    raise RuntimeError("failed to resolve repository root")
  return resolved


def find_repo_root() -> Path | None:
  current = Path(__file__).resolve()
  for parent in current.parents:
    if (parent / "AGENTS.md").is_file() and (parent / "runtime").is_dir() and (parent / "script").is_dir():
      return parent
  return None


def build_root() -> Path:
  resolved = find_repo_root()
  if resolved is not None:
    return resolved / ".build"
  return example_root() / ".build"


def legacy_scripts_dir() -> Path:
  candidates = (
    plugin_root() / "scripts",
    plugin_root() / "tirtc" / "scripts",
  )
  return next((candidate for candidate in candidates if candidate.is_dir()), candidates[0])
