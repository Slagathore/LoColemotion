#!/usr/bin/env python3
"""Thin R110 binding for the retained infrastructure-invalid closure audit."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.finite_godot_recovery_infrastructure_invalid_physical_closure import (  # noqa: E402
    run_cli,
)


if __name__ == "__main__":
    raise SystemExit(
        run_cli(
            ROOT,
            "sdk/recovery/r24d110_godot_jolt_joint_space_effective_inertia_population_recovery_behavior_invalid_closure_v1.json",
            "sporespore_qsdk_r24d110_godot_jolt_joint_space_effective_inertia_population_recovery_behavior_invalid_closure_v1",
            "QSDK-R24D110",
            "sha256:d5f696fce8ad67df6bf8bd7caa783ef3085f92eb77e742fa3241879ae703b1b0",
            13397,
            "QSDK_R24D110_JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_RECOVERY_BEHAVIOR_INVALID_CLOSURE_PASS",
            "QSDK_R24D110_JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_RECOVERY_BEHAVIOR_INVALID_CLOSURE_FAIL",
            contract_relative_path=(
                "sdk/recovery/r24d110_godot_jolt_joint_space_effective_inertia_"
                "population_recovery_behavior_contract_v1.json"
            ),
            live_record_key="r24d110_contract_path",
            live_identity_prefix="r24d110_physical_closure",
            next_gate_id="QSDK-R24D111",
            timeout_seconds=900,
        )
    )
