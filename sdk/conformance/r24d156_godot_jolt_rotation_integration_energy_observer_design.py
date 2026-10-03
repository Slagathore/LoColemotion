#!/usr/bin/env python3
"""Qualify R156's zero-world rotation-integration observer surface."""

from __future__ import annotations

import json
from pathlib import Path
import sys
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    exact,
    load,
    require,
    sha256,
)
from sdk.conformance.rotation_integration_energy_observer import (  # noqa: E402
    RotationObserverError,
    binary64_bound,
    jolt_rotation_step,
    observe_rotation_integration_exchange,
)

DESIGN_PATH = ROOT / (
    "sdk/recovery/"
    "r24d156_godot_jolt_rotation_integration_energy_observer_design_v1.json"
)
PASS_MARKER = "QSDK_R24D156_ROTATION_INTEGRATION_ENERGY_OBSERVER_DESIGN_PASS"
FAIL_MARKER = "QSDK_R24D156_ROTATION_INTEGRATION_ENERGY_OBSERVER_DESIGN_FAIL"


def _file_identity(relative: str) -> dict[str, Any]:
    raw = (ROOT / relative).read_bytes()
    return {"path": relative, "raw_sha256": sha256(raw), "byte_length": len(raw)}


def _payload(
    pre_rotation: list[list[float]], angular: list[float], step: float
) -> dict[str, Any]:
    return {
        "previous_sequence": 40,
        "sequence": 41,
        "solver_step_s": step,
        "pre_body_to_world": pre_rotation,
        "post_body_to_world": jolt_rotation_step(pre_rotation, angular, step),
        "angular_velocity_world_rad_s": angular,
        "principal_inertia_kg_m2": [2.0, 3.5, 5.0],
        "pre_source_measurement": True,
        "post_source_measurement": True,
    }


def _expect_error(payload: dict[str, Any], code: str) -> None:
    try:
        observe_rotation_integration_exchange(payload)
    except RotationObserverError as error:
        exact(str(error), code, f"MUTATION:{code}")
        return
    raise RuntimeError(f"MUTATION_ACCEPTED:{code}")


def evaluate() -> dict[str, Any]:
    design = load(DESIGN_PATH)
    exact(design["gate_id"], "QSDK-R24D156", "GATE_ID")
    exact(design["question_class"], "development", "QUESTION_CLASS")
    require(design["physical_execution_authorized"] is False, "PHYSICAL_AUTHORITY")

    for binding in design["source_bindings"]:
        exact(_file_identity(str(binding["path"])), binding, "SOURCE_BINDING")

    v4 = (ROOT / design["source_rules"]["v4_patch_path"]).read_text(encoding="utf-8")
    observer_v1 = (ROOT / design["source_rules"]["r148_observer_path"]).read_text(
        encoding="utf-8"
    )
    v6 = (ROOT / design["source_rules"]["v6_patch_path"]).read_text(encoding="utf-8")
    for token, count in design["source_rules"]["v6_required_token_counts"].items():
        exact(v6.count(token), count, f"V6_TOKEN:{token}")
    for token in design["source_rules"]["v6_forbidden_tokens"]:
        exact(v6.count(token), 0, f"V6_FORBIDDEN:{token}")
    exact(v4.count("RotationIntegration"), 0, "V4_ROTATION_FIELD_ABSENT")
    exact(
        observer_v1.count("rotation_integration_kinetic_exchange_j"),
        0,
        "R148_ROTATION_INPUT_ABSENT",
    )
    before_index = v6.index("rotation_before = MeasureSporeSporeEnergy")
    integration_index = v6.index("body.AddRotationStep")
    after_index = v6.index("rotation_after = MeasureSporeSporeEnergy")
    exact(before_index < integration_index < after_index, True, "SOURCE_STAGE_ORDER")

    identity = [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]]
    zero_payload = _payload(identity, [0.0, 0.0, 0.0], 1.0 / 120.0)
    principal_payload = _payload(identity, [3.0, 0.0, 0.0], 1.0 / 120.0)
    off_principal_pre = jolt_rotation_step(identity, [0.4, -0.8, 0.3], 0.37)
    off_principal_payload = _payload(
        [list(row) for row in off_principal_pre],
        [1.7, -0.6, 0.9],
        1.0 / 120.0,
    )
    cases = {
        "zero_rotation": observe_rotation_integration_exchange(zero_payload),
        "principal_axis": observe_rotation_integration_exchange(principal_payload),
        "off_principal_axis": observe_rotation_integration_exchange(
            off_principal_payload
        ),
    }
    maximum_abs_exchange = 0.0
    maximum_bound = 0.0
    for case_id, receipt in cases.items():
        exchange = abs(float(receipt["signed_rotation_integration_kinetic_exchange_j"]))
        bound = binary64_bound(
            [
                float(receipt["pre_rotational_kinetic_energy_j"]),
                float(receipt["post_rotational_kinetic_energy_j"]),
            ],
            operation_factor=int(design["analytic_controls"]["operation_factor"]),
        )
        require(exchange <= bound, f"ANALYTIC_INVARIANCE:{case_id}")
        maximum_abs_exchange = max(maximum_abs_exchange, exchange)
        maximum_bound = max(maximum_bound, bound)

    crossed = dict(off_principal_payload)
    crossed["sequence"] = crossed["previous_sequence"]
    _expect_error(crossed, "SEQUENCE_CROSSED")
    contaminated = dict(off_principal_payload)
    contaminated["energy_balance_residual_j"] = 12.27480813475702
    _expect_error(contaminated, "RESIDUAL_DERIVED_INPUT_REFUSED")

    return {
        "gate_id": "QSDK-R24D156",
        "ok": True,
        "status": design["status"],
        "question_class": "development",
        "native_extension_required": True,
        "adapter_only_observer_rejected": True,
        "analytic_positive_case_count": len(cases),
        "forced_failure_case_count": 2,
        "maximum_abs_ideal_exchange_j": maximum_abs_exchange,
        "maximum_binary64_control_bound_j": maximum_bound,
        "rotational_staging_cause_established": False,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "prone_to_standing_claimed": False,
        "sdk1_milestone_advanced": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def main() -> int:
    try:
        result = evaluate()
    except Exception as error:  # noqa: BLE001 - fail-closed CLI boundary
        print(FAIL_MARKER, json.dumps({"ok": False, "error": str(error)}, sort_keys=True))
        return 1
    print(PASS_MARKER, json.dumps(result, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
