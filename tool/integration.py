#!/usr/bin/env python3

from __future__ import annotations

import sys

from support.legacy_entry import run_legacy_layer


def main(argv: list[str]) -> int:
  return run_legacy_layer("flutter_integration_test", "integration", argv)


if __name__ == "__main__":
  raise SystemExit(main(sys.argv[1:]))
