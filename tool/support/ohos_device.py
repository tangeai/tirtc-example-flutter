from __future__ import annotations

import subprocess
from dataclasses import dataclass


HDC_TIMEOUT_SECONDS = 5.0
PHYSICAL_DEVICE_PARAMS = (
  "const.product.model",
  "const.product.name",
  "const.product.devicetype",
)
VIRTUAL_DEVICE_TOKENS = ("emulator", "simulator", "virtual", "127.0.0.1", "localhost")


@dataclass(frozen=True)
class OhosDeviceCandidate:
  target: str
  identity: str

  @property
  def is_virtual(self) -> bool:
    haystack = f"{self.target} {self.identity}".lower()
    return any(token in haystack for token in VIRTUAL_DEVICE_TOKENS)


class OhosDeviceResolutionError(RuntimeError):
  def __init__(self, blocked_reason: str, detail: str) -> None:
    super().__init__(detail)
    self.blocked_reason = blocked_reason
    self.detail = detail


def _run_hdc(args: list[str], *, timeout: float = HDC_TIMEOUT_SECONDS) -> subprocess.CompletedProcess[str]:
  try:
    return subprocess.run(
      ["hdc", *args],
      stdout=subprocess.PIPE,
      stderr=subprocess.PIPE,
      text=True,
      timeout=timeout,
      check=False,
    )
  except FileNotFoundError as error:
    raise OhosDeviceResolutionError("ohos_hdc_missing", "hdc is not available on PATH") from error
  except subprocess.TimeoutExpired as error:
    raise OhosDeviceResolutionError("ohos_hdc_timeout", "hdc device discovery timed out") from error


def list_ohos_targets() -> list[str]:
  result = _run_hdc(["list", "targets"])
  if result.returncode != 0:
    detail = (result.stderr or result.stdout or "hdc list targets failed").strip()
    raise OhosDeviceResolutionError("ohos_hdc_list_failed", detail)
  targets: list[str] = []
  for line in result.stdout.splitlines():
    target = line.strip()
    if not target or target.lower().startswith("[empty]"):
      continue
    targets.append(target.split()[0])
  return targets


def _query_identity(target: str) -> str:
  values: list[str] = []
  for key in PHYSICAL_DEVICE_PARAMS:
    result = _run_hdc(["-t", target, "shell", "param", "get", key], timeout=3.0)
    if result.returncode != 0:
      continue
    value = result.stdout.strip()
    if value:
      values.append(value)
  return " ".join(values)


def select_ohos_target(targets: list[str]) -> tuple[str, dict[str, object]]:
  if not targets:
    raise OhosDeviceResolutionError("ohos_device_missing", "no OHOS target is connected")
  candidates = [OhosDeviceCandidate(target=target, identity=_query_identity(target)) for target in targets]
  physical = [candidate for candidate in candidates if not candidate.is_virtual]
  selected = physical[0] if physical else candidates[0]
  return selected.target, {
    "source": "hdc",
    "selected": selected.target,
    "target_count": len(candidates),
    "selection": "physical_preferred" if physical else "first_connected",
    "targets": [
      {
        "target": candidate.target,
        "identity": candidate.identity,
        "virtual": candidate.is_virtual,
      }
      for candidate in candidates
    ],
  }


def resolve_ohos_device_id(device_id: str | None) -> tuple[str, dict[str, object]]:
  if device_id:
    return device_id, {"source": "explicit", "selected": device_id}
  return select_ohos_target(list_ohos_targets())
