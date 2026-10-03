"""Zero-world forensic audit for the consumed MuJoCo VH3 report.

This module never imports MuJoCo and never constructs or advances a model.  It
uses only the immutable VH3 report to compare the quantity frozen as the
"internal-step" actuator sample with the one-DoF momentum balance across each
completed step.

The result is diagnostic only.  It cannot repair, re-score, or promote VH3.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
from typing import Any


CAMPAIGN_ID = "C6-MUJOCO-VELOCITY-ONLY-STABILITY-HOST-CHARACTERIZATION-VH3"
GATE_ID = "C6-MJC-HC-VH3"
SOURCE_COMMIT = "57e97f2f08636ef42b38511e11650e89b674dfaf"
TRACE_RECORD_COUNT = 43_200
SATURATION_TOLERANCE = 1.0e-10
MOMENTUM_TOLERANCE = 1.0e-12


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def _finite(value: float, label: str) -> float:
    _require(math.isfinite(value), f"nonfinite {label}")
    return value


def diagnose(report_path: Path) -> dict[str, Any]:
    report = json.loads(report_path.read_text(encoding="utf-8"))
    _require(report.get("campaign_id") == CAMPAIGN_ID, "campaign changed")
    _require(report.get("gate_id") == GATE_ID, "gate changed")
    _require(
        report.get("source", {}).get("commit") == SOURCE_COMMIT,
        "source commit changed",
    )
    _require(report.get("ok") is False, "frozen VH3 result changed")
    _require(report.get("passed_cells") == 22, "passed-cell count changed")
    _require(report.get("failed_cells") == 2, "failed-cell count changed")

    mechanism = report["stability_mechanism"]
    profile = report["motor_profile"]
    dt = _finite(float(mechanism["internal_timestep_s"]), "internal timestep")
    gain = _finite(float(profile["velocity_gain_nm_s_per_rad"]), "velocity gain")
    force_range = [float(value) for value in profile["force_range_nm"]]
    _require(force_range[0] == -6.0 and force_range[1] == 6.0, "force cap changed")
    force_cap = force_range[1]
    cap_impulse = force_cap * dt

    cell_diagnostics: list[dict[str, Any]] = []
    total_records = 0
    total_retained_post_state_saturation = 0
    total_reconstructed_pre_step_saturation = 0
    maximum_saturated_momentum_error = 0.0
    maximum_abs_momentum_inferred_motor_impulse = 0.0
    low_target_zero_cells: list[dict[str, Any]] = []

    cells = report.get("cells", [])
    _require(len(cells) == 24, "cell count changed")
    for cell in cells:
        trace = cell.get("internal_step_trace", [])
        _require(len(trace) == 1_800, f"trace count changed: {cell.get('cell_id')}")
        previous_velocity = _finite(
            float(cell["initial_joint_velocity_rad_s"]),
            "initial velocity",
        )
        target_velocity = _finite(float(cell["target_velocity_rad_s"]), "target")
        reconstructed_saturation_count = 0
        maximum_cell_momentum_impulse = 0.0
        first_step: dict[str, float] | None = None

        for expected_index, row in enumerate(trace):
            _require(len(row) == 11, "trace row schema changed")
            _require(int(row[0]) == expected_index, "trace order changed")
            result_velocity = _finite(float(row[5]), "result velocity")
            post_state_force = _finite(float(row[7]), "post-state force")
            external_torque = _finite(float(row[8]), "external torque")
            inertia = _finite(float(row[9]), "generalized inertia")

            raw_pre_step_force = gain * (target_velocity - previous_velocity)
            predicted_pre_step_force = max(
                force_range[0], min(force_range[1], raw_pre_step_force)
            )
            momentum_inferred_motor_impulse = (
                inertia * (result_velocity - previous_velocity)
                - external_torque * dt
            )
            maximum_cell_momentum_impulse = max(
                maximum_cell_momentum_impulse,
                abs(momentum_inferred_motor_impulse),
            )
            maximum_abs_momentum_inferred_motor_impulse = max(
                maximum_abs_momentum_inferred_motor_impulse,
                abs(momentum_inferred_motor_impulse),
            )

            saturated = (
                abs(abs(predicted_pre_step_force) - force_cap)
                <= SATURATION_TOLERANCE
            )
            if saturated:
                reconstructed_saturation_count += 1
                error = abs(
                    momentum_inferred_motor_impulse
                    - predicted_pre_step_force * dt
                )
                maximum_saturated_momentum_error = max(
                    maximum_saturated_momentum_error, error
                )

            if first_step is None:
                first_step = {
                    "previous_velocity_rad_s": previous_velocity,
                    "result_velocity_rad_s": result_velocity,
                    "predicted_pre_step_force_nm": predicted_pre_step_force,
                    "retained_post_state_force_nm": post_state_force,
                    "momentum_inferred_motor_impulse_nms": (
                        momentum_inferred_motor_impulse
                    ),
                }
            previous_velocity = result_velocity

        retained_saturation_count = int(cell["saturated_internal_step_count"])
        total_records += len(trace)
        total_retained_post_state_saturation += retained_saturation_count
        total_reconstructed_pre_step_saturation += reconstructed_saturation_count
        diagnostic = {
            "cell_id": cell["cell_id"],
            "frozen_cell_passed": bool(cell["passed"]),
            "retained_post_state_saturation_count": retained_saturation_count,
            "reconstructed_pre_step_saturation_count": (
                reconstructed_saturation_count
            ),
            "saturation_events_lost_by_post_state_sampling": (
                reconstructed_saturation_count - retained_saturation_count
            ),
            "maximum_abs_momentum_inferred_motor_impulse_nms": (
                maximum_cell_momentum_impulse
            ),
            "first_step": first_step,
        }
        cell_diagnostics.append(diagnostic)
        if cell["cell_id"] in {
            "unloaded_vn075_izero",
            "unloaded_vp075_izero",
        }:
            low_target_zero_cells.append(diagnostic)

    _require(total_records == TRACE_RECORD_COUNT, "aggregate trace count changed")
    _require(
        all(
            cell["reconstructed_pre_step_saturation_count"] >= 1
            for cell in cell_diagnostics
        ),
        "a cell lacks reconstructed pre-step saturation",
    )
    _require(
        all(
            cell["saturation_events_lost_by_post_state_sampling"] == 1
            for cell in cell_diagnostics
        ),
        "post-state temporal offset is not exactly one event per cell",
    )
    _require(
        maximum_saturated_momentum_error <= MOMENTUM_TOLERANCE,
        "saturated momentum balance changed",
    )
    _require(
        maximum_abs_momentum_inferred_motor_impulse
        <= cap_impulse + MOMENTUM_TOLERANCE,
        "momentum-derived motor impulse exceeds native cap",
    )
    _require(
        len(low_target_zero_cells) == 2
        and all(not cell["frozen_cell_passed"] for cell in low_target_zero_cells)
        and all(
            cell["retained_post_state_saturation_count"] == 0
            and cell["reconstructed_pre_step_saturation_count"] == 1
            for cell in low_target_zero_cells
        ),
        "two-cell failure mechanism changed",
    )

    return {
        "schema_version": (
            "sporespore_mujoco_c6_velocity_only_stability_host_"
            "characterization_vh3_posthoc_diagnostic_v1"
        ),
        "status": "posthoc_temporal_measurement_invalid_no_scientific_result",
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "experiment_source_commit": SOURCE_COMMIT,
        "input_report": {
            "path": report_path.as_posix(),
            "raw_sha256": f"sha256:{_sha256(report_path)}",
        },
        "frozen_result": {
            "report_ok": False,
            "passed_cells": 22,
            "failed_cells": 2,
            "failed_cell_ids": [
                "unloaded_vn075_izero",
                "unloaded_vp075_izero",
            ],
            "internal_trace_record_count": total_records,
        },
        "temporal_measurement_finding": {
            "retained_quantity": (
                "actuator_force and qfrc_actuator recomputed by mj_forward on "
                "a copied post-mj_step state"
            ),
            "quantity_required_by_declared_gate": (
                "force saturation and motor impulse during each completed "
                "internal physics step"
            ),
            "retained_post_state_saturation_count": (
                total_retained_post_state_saturation
            ),
            "reconstructed_pre_step_saturation_count": (
                total_reconstructed_pre_step_saturation
            ),
            "saturation_events_lost_by_post_state_sampling": (
                total_reconstructed_pre_step_saturation
                - total_retained_post_state_saturation
            ),
            "all_24_cells_reconstruct_at_least_one_saturated_step": True,
            "all_24_cells_lose_exactly_one_saturation_event": True,
            "native_force_cap_nm": force_cap,
            "internal_timestep_s": dt,
            "native_cap_impulse_nms": cap_impulse,
            "maximum_abs_momentum_inferred_motor_impulse_nms": (
                maximum_abs_momentum_inferred_motor_impulse
            ),
            "maximum_saturated_momentum_vs_cap_impulse_error_nms": (
                maximum_saturated_momentum_error
            ),
        },
        "failed_cell_forensics": low_target_zero_cells,
        "cell_diagnostics": cell_diagnostics,
        "technical_disposition": {
            "complete_twenty_four_cell_physical_report_exists": True,
            "all_43200_internal_state_traces_exist": True,
            "frozen_report_or_threshold_changed": False,
            "declared_saturation_measurement_valid": False,
            "declared_internal_step_impulse_measurement_valid": False,
            "campaign_identity_consumed": True,
            "scientific_positive": False,
            "scientific_negative": False,
            "development_observation_supports_corrected_successor": True,
            "retroactive_rescore_or_promotion_permitted": False,
        },
        "successor_requirements": {
            "new_campaign_gate_source_and_preregistration": True,
            "record_pre_integration_actuator_force": True,
            "record_post_integration_state_separately": True,
            "derive_motor_impulse_from_one_dof_momentum_balance": True,
            "distinguish_pre_step_force_from_post_state_recomputed_force": True,
            "retain_all_signed_load_initial_condition_and_trace_gates": True,
            "zero_world_whole_gate_preflight_before_any_model": True,
        },
        "world_build_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    diagnostic = diagnose(args.report.resolve())
    payload = json.dumps(diagnostic, indent=2, sort_keys=False) + "\n"
    args.output.resolve().write_text(payload, encoding="utf-8", newline="\n")
    print(json.dumps(diagnostic, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
