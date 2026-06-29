#!/usr/bin/env python3

from __future__ import annotations

import sys

from support.options import CaseArgumentParser, add_common_options
from support.dry_layers import run_first_slice


def parser() -> CaseArgumentParser:
  result = CaseArgumentParser(description="Run Flutter SDK stress cases.")
  add_common_options(result, dry_run=True)
  return result


def main(argv: list[str]) -> int:
  args = parser().parse_args(argv)
  return run_first_slice("stress", args)


if __name__ == "__main__":
  raise SystemExit(main(sys.argv[1:]))
