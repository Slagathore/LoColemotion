#!/usr/bin/env python3
"""Zero-world MuJoCo row-serialization and failure-projection ghosts for R23D69."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys
from typing import Any

import numpy as np


ROOT = Path(__file__).resolve().parents[1]
MUJOCO_ROOT = ROOT / "sdk" / "adapters" / "mujoco"
TURNING_ROOT = ROOT / "sdk" / "turning"
for path in (MUJOCO_ROOT, TURNING_ROOT):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from sporespore_mujoco_adapter import (  # noqa: E402
    qsdk_r23d65_selected_profile_turning as production,
)
from sporespore_mujoco_adapter import qsdk_r23d69_turning_route as route  # noqa: E402


STEPS = (599, 600, 1799, 1800, 2399, 2400, 2991)
SEGMENTS = (
    "reference_warmup",
    "commanded_turn",
    "commanded_turn",
    "reference_recovery",
    "reference_recovery",
    "reference_continuation",
    "reference_continuation",
)


class _GhostRamp:
    @staticmethod
    def trace_fields(_semantic_step: int) -> dict[str, Any]:
        return {}


def _base_row(**kwargs: Any) -> dict[str, Any]:
    semantic_step = int(kwargs["semantic_step"])
    segment_id, heading = route.design.segment_for_step(
        route.design.cell("mujoco", "reference_zero"), semantic_step
    )
    return {
        "schema_version": route.TRACE_ROW_SCHEMA,
        "campaign_id": route.CAMPAIGN_ID,
        "gate_id": route.GATE_ID,
        "stage_id": route.STAGE_ID,
        "cell_id": route.design.cell("mujoco", "reference_zero").cell_id,
        "engine_id": "mujoco",
        "campaign_seed": route.CAMPAIGN_SEED,
        "semantic_step": semantic_step,
        "trace_step": semantic_step,
        "segment_id": segment_id,
        "desired_heading_offset_rad": heading,
        "ordered_limb_phase_before": kwargs["limb_phase_before"],
        "ordered_foot_contacts_before": kwargs["contacts_before"],
        "ordered_foot_contacts_after": kwargs["contacts_after"],
        "oracle_passed": True,
    }


def _application(actuator_id: str, joint_id: str) -> dict[str, Any]:
    return {
        "actuator_id": actuator_id,
        "joint_id": joint_id,
        "host_joint_id": joint_id,
        "requested_target_position_rad": 0.0,
        "clamped_target_position_rad": 0.0,
        "controller_target_velocity_rad_s": 0.1,
        "maximum_target_speed_rad_s": 1.0,
        "host_applied_target_velocity_rad_s": 0.1,
        "motor_target_velocity_readback_rad_s": 0.1,
        "motor_target_velocity_readback_error_rad_s": 0.0,
        "declared_maximum_impulse_nms": 0.01,
        "motor_maximum_impulse_readback_nms": 0.01,
        "motor_maximum_impulse_readback_error_nms": 0.0,
        "position_saturated": False,
        "velocity_saturated": False,
        "slew_limited": False,
        "host_additional_clamp_applied": False,
        "target_velocity_readback_matches": production._native_json_bool(
            np.bool_(True)
        ),
        "maximum_impulse_readback_matches": production._native_json_bool(
            np.bool_(True)
        ),
    }


def _compose_rows() -> list[dict[str, Any]]:
    previous_trace = production._INHERITED_TRACE_ROW
    previous_ramp = production._RAMP
    production._INHERITED_TRACE_ROW = _base_row
    production._RAMP = _GhostRamp()
    rows: list[dict[str, Any]] = []
    try:
        for semantic_step, expected_segment in zip(STEPS, SEGMENTS, strict=True):
            production._RUNTIME.task_origins = {
                semantic_step: {
                    "task_frame_origin_world_m": [0.0, 0.4, 0.0],
                    "torso_position_world_m": [0.0, 0.4, 0.0],
                    "task_frame_origin_reanchored_this_step": False,
                    "task_frame_origin_reanchor_count": 0,
                }
            }
            production._RUNTIME.native_applications = {
                semantic_step: [
                    _application(actuator_id, joint_id)
                    for actuator_id, joint_id in zip(
                        production.ORDERED_ACTUATOR_IDS,
                        production.ORDERED_JOINT_IDS,
                        strict=True,
                    )
                ]
            }
            phases = [
                {
                    "limb_id": limb_id,
                    "local_phase_step": semantic_step % 360,
                    "gait_step": semantic_step,
                    "release_hold_step_count": 0,
                }
                for limb_id in production.LIMB_IDS
            ]
            contacts = {limb_id: True for limb_id in production.LIMB_IDS}
            row = production._trace_row(
                semantic_step=semantic_step,
                limb_phase_before=phases,
                contacts_before=contacts,
                contacts_after=contacts,
                receipt={"semantic_step": semantic_step, "ok": True},
            )
            exact = (
                row.get("schema_version") == route.TRACE_ROW_SCHEMA
                and row.get("campaign_id") == route.CAMPAIGN_ID
                and row.get("gate_id") == route.GATE_ID
                and row.get("stage_id") == route.STAGE_ID
                and row.get("engine_id") == "mujoco"
                and row.get("campaign_seed") == route.CAMPAIGN_SEED
                and row.get("semantic_step") == semantic_step
                and row.get("trace_step") == semantic_step
                and row.get("segment_id") == expected_segment
                and isinstance(row.get("actuator_phase_observation"), dict)
                and all(
                    type(application["target_velocity_readback_matches"]) is bool
                    and type(application["maximum_impulse_readback_matches"]) is bool
                    for application in row["actuator_phase_observation"][
                        "ordered_applications"
                    ]
                )
            )
            if not exact:
                raise RuntimeError(
                    f"QSDK_R23D69_MJC_COMPLETE_ROW_INVALID:{semantic_step}"
                )
            json.dumps(row, allow_nan=False)
            rows.append(row)
    finally:
        production._INHERITED_TRACE_ROW = previous_trace
        production._RAMP = previous_ramp
    return rows


def _project_failures() -> tuple[dict[str, Any], dict[str, Any]]:
    arguments = argparse.Namespace(
        stage=route.STAGE_ID,
        onset="onset_600",
        campaign_seed=route.CAMPAIGN_SEED,
        profile=route.PROFILE_ID,
        arm="reference_zero",
        source_commit="1" * 40,
    )
    before = route._project_failure_terminal(
        production._core.R23D3MujocoError(
            "QSDK_R23D69_SYNTHETIC_BEFORE_WORLD",
            world_attempt_count=0,
            world_build_count=0,
        ),
        arguments,
    )
    after_receipt = {
        "failure_code": "QSDK_R23D69_SYNTHETIC_SETTLEMENT_FAILURE",
        "failure_stage": "settlement_complete",
        "model_construction_count": 1,
        "world_attempt_count": 1,
        "world_build_count": 1,
    }
    after = route._project_failure_terminal(
        production._core.R23D3MujocoError(
            "QSDK_R23D69_SYNTHETIC_SETTLEMENT_FAILURE",
            world_attempt_count=1,
            world_build_count=1,
            terminal_receipt=after_receipt,
        ),
        arguments,
    )
    if not (
        before["failure_stage"] == "before_world"
        and before["world_attempt_count"] == 0
        and before["world_build_count"] == 0
        and after["failure_stage"] == "settlement_complete"
        and after["world_attempt_count"] == 1
        and after["world_build_count"] == 1
        and after["model_construction_count"] == 1
    ):
        raise RuntimeError("QSDK_R23D69_MJC_FAILURE_PROJECTION_INVALID")
    json.dumps(before, allow_nan=False)
    json.dumps(after, allow_nan=False)
    return before, after


def main() -> int:
    route._configure_shared_kernel()
    rows = _compose_rows()
    _project_failures()
    receipt = {
        "schema_version": "sporespore_qsdk_r23d69_mujoco_complete_row_ghost_v1",
        "ok": True,
        "representative_semantic_steps": list(STEPS),
        "representative_complete_row_count": len(rows),
        "actual_native_row_composer_used": True,
        "actual_native_boolean_projection_used": True,
        "strict_json_allow_nan_false_count": len(rows) + 2,
        "failure_projection_case_count": 2,
        "inner_failure_stage_and_counts_preserved": True,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }
    print(
        "QSDK_R23D69_MUJOCO_COMPLETE_ROW_GHOST "
        + json.dumps(receipt, allow_nan=False, separators=(",", ":"), sort_keys=True)
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
