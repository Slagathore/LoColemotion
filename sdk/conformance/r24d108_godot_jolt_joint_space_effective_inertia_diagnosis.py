#!/usr/bin/env python3
"""Thin R108 binding for the reusable coupled joint-space diagnosis."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.joint_space_effective_inertia_diagnosis import (  # noqa: E402
    run_cli,
)


if __name__ == "__main__":
    raise SystemExit(
        run_cli(
            ROOT,
            "sdk/recovery/r24d108_godot_jolt_joint_space_effective_inertia_diagnosis_v1.json",
            "sporespore_qsdk_r24d108_godot_jolt_joint_space_effective_inertia_diagnosis_v1",
            "sha256:17f4e77119c6974f661edad7c65b4f1f94259b83f5f3b2a1143d2f5e018298da",
            13886,
            "QSDK_R24D108_JOINT_SPACE_EFFECTIVE_INERTIA_DIAGNOSIS_PASS",
            "QSDK_R24D108_JOINT_SPACE_EFFECTIVE_INERTIA_DIAGNOSIS_FAIL",
            gate_id="QSDK-R24D108",
            next_gate_id="QSDK-R24D109",
            live_record_key="r24d107_contract_path",
            live_identity_prefix="r24d108_diagnosis",
        )
    )
