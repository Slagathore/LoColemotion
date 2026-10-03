#!/usr/bin/env python3
"""Zero-world exercise of the actual R23D74 MuJoCo success normalizer."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys


REPO_ROOT = Path(__file__).resolve().parents[1]
MUJOCO_ROOT = REPO_ROOT / "sdk" / "adapters" / "mujoco"
if str(MUJOCO_ROOT) not in sys.path:
    sys.path.insert(0, str(MUJOCO_ROOT))

from sporespore_mujoco_adapter import qsdk_r23d74_turning_route as route  # noqa: E402


def main() -> int:
    arguments = argparse.Namespace(
        command="physical",
        stage=route.STAGE_ID,
        onset=route.ONSET_ID,
        campaign_seed=route.CAMPAIGN_SEED,
        profile=route.PROFILE_ID,
        arm="reference_zero",
        source_commit="1" * 40,
    )
    terminal = route._normalize_success_terminal(  # noqa: SLF001
        {
            "schema_version": route.REPORT_SCHEMA,
            "question_class": "finite_decision",
            "trace_artifact": {
                "trace_transport_id": route.evaluator.TRACE_TRANSPORT_ID,
                "trace_transport_engine_id": route.ENGINE_ID,
                "canonical_ndjson": True,
                "full_precision": True,
                "byte_length": 0,
            },
            "forward_displacement_measurement_origin": {
                "policy_id": route.design.MEASUREMENT_ORIGIN_POLICY_ID,
                "semantic_step": route.design.MEASUREMENT_ORIGIN_SEMANTIC_STEP,
                "captured_before_controller_step": True,
                "task_frame_reanchors_change_measurement_origin": False,
            },
            "measurements": {
                "startup_ramp_id": route.design.MUJOCO_STARTUP_RAMP_ID,
                "startup_policy": "unconditional_one_cycle",
                "startup_ramp_step_count": route.design.MUJOCO_STARTUP_RAMP_STEP_COUNT,
            },
            "execution": {
                "world_attempt_count": 1,
                "world_build_count": 1,
                "startup_ramp_composition_integrity_passed": True,
                "startup_transform_composition_integrity_passed": True,
            },
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
        },
        arguments,
    )
    exact = (
        terminal.get("schema_version") == route.REPORT_SCHEMA
        and terminal.get("question_class") == "finite_decision"
        and terminal.get("execution", {}).get("world_attempt_count") == 1
        and terminal.get("execution", {}).get("world_build_count") == 1
        and type(terminal.get("trace_artifact", {}).get("byte_length")) is int
        and "model_construction_count" not in terminal
        and "world_attempt_count" not in terminal
        and "world_build_count" not in terminal
    )
    if not exact:
        raise RuntimeError("QSDK_R23D74_MUJOCO_SUCCESS_TERMINAL_SHAPE_INVALID")
    print(
        "QSDK_R23D74_MUJOCO_SUCCESS_TERMINAL_GHOST "
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
