#!/usr/bin/env python3
"""Thin R159 binding for the shared compact native-observation closure audit."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.compact_godot_native_observation_closure import run_cli  # noqa: E402


if __name__ == "__main__":
    raise SystemExit(
        run_cli(
            ROOT,
            "sdk/recovery/r24d159_godot_jolt_native_observation_evidence_directory_contract_v1.json",
        )
    )
