#!/usr/bin/env python3
"""Thin R134 binding for the reusable finite behavior physical closure."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.finite_godot_recovery_behavior_physical_closure import (  # noqa: E402
    run_cli,
)


if __name__ == "__main__":
    raise SystemExit(
        run_cli(
            ROOT,
            "sdk/recovery/r24d134_godot_jolt_development_evaluator_replay_recovery_behavior_physical_closure_v1.json",
            "sporespore_qsdk_r24d134_godot_jolt_development_evaluator_replay_recovery_behavior_physical_closure_v1",
            "QSDK-R24D134",
            "sha256:6b6c2dac9a1ae87241c5783c2db153456d13f28d4b5006cf27d7c9d9e97c95a2",
            29056,
            "QSDK_R24D134_DEVELOPMENT_EVALUATOR_REPLAY_RECOVERY_BEHAVIOR_PHYSICAL_CLOSURE_PASS",
            "QSDK_R24D134_DEVELOPMENT_EVALUATOR_REPLAY_RECOVERY_BEHAVIOR_PHYSICAL_CLOSURE_FAIL",
            contract_relative_path="sdk/recovery/r24d134_godot_jolt_development_evaluator_replay_recovery_behavior_contract_v1.json",
            actuation_projection_mode="solver_coupled_constraint_motor_v1",
            live_record_key="r24d134_contract_path",
            live_identity_prefix="r24d134_physical_closure",
            ignored_forward_live_keys=(
                "r24d135_zero_world_stance_dwell_predicate_diagnosis_required",
            ),
            next_gate_id="QSDK-R24D135",
            expected_scientific_outcome="negative",
            expected_sdk1_milestone_advanced=False,
        )
    )
