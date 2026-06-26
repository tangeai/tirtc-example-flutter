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
    if (parent / "AGENTS.md").is_file() and (parent / "products").is_dir():
      return parent
  return None


def build_root() -> Path:
  resolved = find_repo_root()
  if resolved is not None:
    return resolved / ".build"
  return example_root() / ".build"


def legacy_scripts_dir() -> Path:
  return plugin_root() / "scripts"
