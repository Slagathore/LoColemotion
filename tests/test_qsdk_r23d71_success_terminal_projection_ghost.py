#!/usr/bin/env python3
"""Compact zero-world exercise of the actual MuJoCo success rebranding path."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys


REPO_ROOT = Path(__file__).resolve().parents[1]
MUJOCO_ROOT = REPO_ROOT / "sdk" / "adapters" / "mujoco"
if str(MUJOCO_ROOT) not in sys.path:
    sys.path.insert(0, str(MUJOCO_ROOT))

from sporespore_mujoco_adapter import qsdk_r23d71_turning_route as route  # noqa: E402


def main() -> int:
    arguments = argparse.Namespace(
        command="physical",
        stage=route.STAGE_ID,
        onset=route.ONSET_ID,
        campaign_seed=route.CAMPAIGN_SEED,
        profile=route.PROFILE_ID,
        arm="reference_zero",
        source_commit="1111111111111111111111111111111111111111",
    )
    terminal = route._normalize_success_terminal(
        {
            "schema_version": "sporespore_qsdk_r23d70_engine_cell_report_v1",
            "execution": {
                "world_attempt_count": 1,
                "world_build_count": 1,
            },
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
        },
        arguments,
    )
    if not (
        terminal.get("schema_version") == route.REPORT_SCHEMA
        and terminal.get("execution")
        == {"world_attempt_count": 1, "world_build_count": 1}
        and "model_construction_count" not in terminal
        and "world_attempt_count" not in terminal
        and "world_build_count" not in terminal
    ):
        raise RuntimeError("QSDK_R23D71_MUJOCO_SUCCESS_TERMINAL_SHAPE_INVALID")
    print(
        "QSDK_R23D71_MUJOCO_SUCCESS_TERMINAL_GHOST "
        + json.dumps(
            {
                "terminal": terminal,
                "actual_producer_function": "_normalize_success_terminal",
                "model_construction_count": 0,
                "world_attempt_count": 0,
                "world_build_count": 0,
                "physical_acceptance_authority": False,
            },
            allow_nan=False,
            separators=(",", ":"),
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
