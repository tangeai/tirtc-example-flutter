from __future__ import annotations

import argparse
import sys
from pathlib import Path

from .ohos_device import OhosDeviceResolutionError, resolve_ohos_device_id
from .paths import build_root
from .summary import now_iso

PLATFORMS = ("macos", "android", "ios", "ohos", "all")


class CaseArgumentParser(argparse.ArgumentParser):
  def error(self, message: str) -> None:
    self.print_usage(sys.stderr)
    self.exit(3, f"{self.prog}: error: {message}\n")


def add_common_options(parser: argparse.ArgumentParser, *, dry_run: bool) -> None:
  parser.add_argument("--platform", default="macos", choices=PLATFORMS)
  parser.add_argument("--device-id")
  parser.add_argument("--android-device-id")
  parser.add_argument("--ios-device-id")
  parser.add_argument("--artifact-root")
  parser.add_argument("--qualified-counterpart")
  parser.add_argument("--prepared-state")
  parser.add_argument("--cli-source", choices=("npm", "local", "path"))
  parser.add_argument("--cli-path")
  parser.add_argument("--cli-npm-spec")
  if dry_run:
    parser.add_argument("--dry-run", action="store_true")
  else:
    parser.add_argument("--dry-run", action="store_true", help=argparse.SUPPRESS)


def validate_platform_args(args: argparse.Namespace) -> None:
  if args.platform == "all":
    if args.device_id:
      raise SystemExit(3)
    if not args.android_device_id or not args.ios_device_id:
      raise SystemExit(3)
    return
  if args.platform == "android":
    args.device_id = args.device_id or args.android_device_id
    if not args.device_id:
      raise SystemExit(3)
  if args.platform == "ios":
    args.device_id = args.device_id or args.ios_device_id
    if not args.device_id:
      raise SystemExit(3)
  if args.platform == "ohos" and not args.device_id and not getattr(args, "dry_run", False):
    try:
      device_id, evidence = resolve_ohos_device_id(args.device_id)
    except OhosDeviceResolutionError as error:
      print(f"OHOS device resolution failed: {error.detail}", file=sys.stderr)
      raise SystemExit(2) from error
    args.device_id = device_id
    args.ohos_device_resolution = evidence
    print(f"OHOS device auto-selected: {device_id}", file=sys.stderr)
  if args.platform == "macos" and args.device_id:
    raise SystemExit(3)


def default_artifact_root(layer: str, run_id: str) -> Path:
  return build_root() / "flutter-test" / layer / run_id


def new_run_id(layer: str) -> str:
  return layer + "-" + now_iso().replace("-", "").replace(":", "").replace("Z", "")
