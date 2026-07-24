from __future__ import annotations

import os

REQUIRED_AUTOMATION_ENV_VARS = (
  "TIRTC_ACCESS_KEY_ID",
  "TIRTC_SECRET_KEY_ID",
  "TIRTC_APP_ID",
  "TIRTC_DEVICE_ID",
  "TIRTC_ENDPOINT",
)


def missing_automation_env_vars() -> list[str]:
  return [name for name in REQUIRED_AUTOMATION_ENV_VARS if not os.environ.get(name)]


def missing_automation_blocked_reason() -> str | None:
  missing = missing_automation_env_vars()
  if not missing:
    return None
  return "missing_environment:" + ",".join(missing)
