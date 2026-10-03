#!/usr/bin/env python3
"""Thin R135 binding for the reusable retained stance-dwell diagnosis."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.finite_recovery_stance_dwell_diagnosis import (  # noqa: E402
    run_stance_dwell_predicate_diagnosis_cli,
)


if __name__ == "__main__":
    raise SystemExit(
        run_stance_dwell_predicate_diagnosis_cli(
            ROOT,
            "sdk/recovery/r24d135_godot_jolt_stance_dwell_predicate_diagnosis_v1.json",
            "sporespore_qsdk_r24d135_godot_jolt_stance_dwell_predicate_diagnosis_v1",
            "sha256:e2c0029fe0612a5cdb67a4671bfd4dee937c81b6bfd17e5302619d3a27c203ff",
            19513,
            "QSDK_R24D135_STANCE_DWELL_PREDICATE_DIAGNOSIS_PASS",
            "QSDK_R24D135_STANCE_DWELL_PREDICATE_DIAGNOSIS_FAIL",
            gate_id="QSDK-R24D135",
            next_gate_id="QSDK-R24D136",
            predecessor_gate_id="QSDK-R24D134",
            predecessor_decision_prefix="r24d134",
            next_required_decision_key=(
                "r24d136_zero_world_energy_partition_implementation_required"
            ),
            live_record_key="r24d134_contract_path",
            live_identity_prefix="r24d135_diagnosis",
            ignored_forward_live_keys=(
                "r24d136_zero_world_energy_partition_implementation_required",
            ),
        )
    )
