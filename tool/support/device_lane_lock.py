from __future__ import annotations

import errno
import fcntl
import json
import os
from pathlib import Path
from typing import Any

from .paths import build_root
from .summary import now_iso

MOBILE_DEVICE_PLATFORMS = {"android", "ios", "ohos", "all"}
LOCK_FILE_NAME = "device-lane.lock"
METADATA_FILE_NAME = "device-lane.lock.json"


class DeviceLaneLockBusy(RuntimeError):
  def __init__(self, *, lock_path: Path, holder: dict[str, Any]) -> None:
    super().__init__("Flutter mobile device lane is already running")
    self.lock_path = lock_path
    self.holder = holder

  def evidence(self) -> dict[str, Any]:
    return {
      "status": "busy",
      "lock_path": str(self.lock_path),
      "holder": self.holder,
    }


class DeviceLaneLock:
  def __init__(self, *, lock_path: Path, metadata_path: Path, handle: Any) -> None:
    self.lock_path = lock_path
    self.metadata_path = metadata_path
    self._handle = handle
    self._released = False

  def evidence(self) -> dict[str, Any]:
    return {
      "status": "acquired",
      "lock_path": str(self.lock_path),
      "metadata_path": str(self.metadata_path),
    }

  def release(self) -> None:
    if self._released:
      return
    self._released = True
    try:
      self.metadata_path.unlink(missing_ok=True)
    finally:
      fcntl.flock(self._handle.fileno(), fcntl.LOCK_UN)
      self._handle.close()

  def __enter__(self) -> "DeviceLaneLock":
    return self

  def __exit__(self, exc_type: object, exc: object, traceback: object) -> None:
    self.release()


def mobile_device_lane_required(platform: str, *, dry_run: bool = False) -> bool:
  return not dry_run and platform in MOBILE_DEVICE_PLATFORMS


def acquire_flutter_device_lane_lock(metadata: dict[str, Any], *, lock_dir: Path | None = None) -> DeviceLaneLock:
  root = lock_dir if lock_dir is not None else build_root() / "flutter-test"
  root.mkdir(parents=True, exist_ok=True)
  lock_path = root / LOCK_FILE_NAME
  metadata_path = root / METADATA_FILE_NAME
  handle = lock_path.open("a+", encoding="utf-8")
  try:
    fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
  except OSError as error:
    handle.close()
    if error.errno not in {errno.EACCES, errno.EAGAIN}:
      raise
    raise DeviceLaneLockBusy(lock_path=lock_path, holder=_read_metadata(metadata_path)) from error

  lock_metadata = {
    "schema_version": 1,
    "pid": os.getpid(),
    "started_at": now_iso(),
    **metadata,
  }
  metadata_path.write_text(json.dumps(lock_metadata, indent=2, sort_keys=True) + "\n", encoding="utf-8")
  return DeviceLaneLock(lock_path=lock_path, metadata_path=metadata_path, handle=handle)


def _read_metadata(path: Path) -> dict[str, Any]:
  if not path.is_file():
    return {}
  try:
    data = json.loads(path.read_text(encoding="utf-8"))
  except (OSError, json.JSONDecodeError):
    return {}
  return data if isinstance(data, dict) else {}
