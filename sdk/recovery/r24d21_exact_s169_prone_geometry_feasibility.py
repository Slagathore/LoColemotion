"""Exact zero-world feasibility evaluator for the nominal s169 prone pose."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import sys
from typing import Any, Mapping, Sequence


SDK_ROOT = Path(__file__).resolve().parents[1]
PYTHON_ROOT = SDK_ROOT / "python"
if str(PYTHON_ROOT) not in sys.path:
    sys.path.insert(0, str(PYTHON_ROOT))

from sporespore_locomotion import (  # noqa: E402
    LocomotionCore,
    r23d60_selected_s169_quadruped,
)


SCHEMA_VERSION = "sporespore_qsdk_r24d21_exact_s169_prone_geometry_decision_v1"
GATE_ID = "QSDK-R24D21"
MORPHOLOGY_ID = "qsdk_r05_generated_s169"
DESCRIPTOR_SHA256 = (
    "sha256:ae7a0872b8b15dfb294c388931899cf82822293417d125dd72ee2a5a847e09e0"
)
MORPHOLOGY_SPEC_SHA256 = (
    "sha256:30893a75e8362dcab69f0fb46b0560cacbe5d5c034cb0152e67eb520ff35f45e"
)
FEASIBILITY_THRESHOLD_M = 0.0


class GeometryDecisionError(RuntimeError):
    """Stable fail-closed error for the finite geometry evaluator."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise GeometryDecisionError(code)


def _by_id(items: Sequence[Mapping[str, Any]], key: str) -> dict[str, Mapping[str, Any]]:
    result: dict[str, Mapping[str, Any]] = {}
    for item in items:
        value = item.get(key)
        _require(isinstance(value, str) and value not in result, f"IDENTITY:{key}")
        assert isinstance(value, str)
        result[value] = item
    return result


def _upper_link_decision(
    *,
    torso_half_height_m: float,
    upper: Mapping[str, Any],
    hip: Mapping[str, Any],
) -> dict[str, Any]:
    collision = upper.get("collision")
    _require(isinstance(collision, dict), "UPPER_COLLISION")
    assert isinstance(collision, dict)
    _require(collision.get("kind") == "capsule", "UPPER_NOT_CAPSULE")
    length_m = float(collision["length_m"])
    radius_m = float(collision["radius_m"])
    anchor_parent = hip.get("anchor_parent_m")
    axis = hip.get("axis_parent_unit")
    _require(isinstance(anchor_parent, dict), "HIP_ANCHOR")
    _require(isinstance(axis, dict), "HIP_AXIS")
    assert isinstance(anchor_parent, dict)
    assert isinstance(axis, dict)
    _require(
        float(axis["x"]) == 0.0
        and float(axis["y"]) == 0.0
        and float(axis["z"]) == 1.0,
        "HIP_AXIS_NOT_CANONICAL_Z",
    )
    lower = float(hip["lower_limit_rad"])
    upper_limit = float(hip["upper_limit_rad"])
    _require(lower == -upper_limit and 0.0 <= upper_limit < math.pi / 2.0, "HIP_RANGE")
    hip_center_y_m = torso_half_height_m + float(anchor_parent["y"])
    proximal_cap_clearance_m = hip_center_y_m - radius_m
    best_abs_hip_angle_rad = upper_limit
    distal_cap_clearance_at_best_angle_m = (
        hip_center_y_m
        - length_m * math.cos(best_abs_hip_angle_rad)
        - radius_m
    )
    maximum_upper_capsule_clearance_m = min(
        proximal_cap_clearance_m,
        distal_cap_clearance_at_best_angle_m,
    )
    required_anchor_y_at_current_range_m = (
        length_m * math.cos(best_abs_hip_angle_rad)
        + radius_m
        - torso_half_height_m
    )
    return {
        "upper_body_id": str(upper["body_id"]),
        "hip_joint_id": str(hip["joint_id"]),
        "torso_half_height_m": torso_half_height_m,
        "hip_anchor_parent_y_m": float(anchor_parent["y"]),
        "hip_center_y_m": hip_center_y_m,
        "upper_capsule_length_m": length_m,
        "upper_capsule_radius_m": radius_m,
        "hip_lower_limit_rad": lower,
        "hip_upper_limit_rad": upper_limit,
        "best_abs_hip_angle_rad": best_abs_hip_angle_rad,
        "proximal_cap_clearance_m": proximal_cap_clearance_m,
        "distal_cap_clearance_at_best_angle_m": distal_cap_clearance_at_best_angle_m,
        "maximum_upper_capsule_clearance_m": maximum_upper_capsule_clearance_m,
        "required_hip_anchor_parent_y_at_current_range_m": (
            required_anchor_y_at_current_range_m
        ),
        "nonpenetrating": maximum_upper_capsule_clearance_m
        >= FEASIBILITY_THRESHOLD_M,
        "knee_configuration_can_change_this_bound": False,
    }


def evaluate_compiled_v1(compiled: Mapping[str, Any]) -> dict[str, Any]:
    """Evaluate the exact necessary upper-link condition without physics."""

    _require(compiled.get("morphology_id") == MORPHOLOGY_ID, "MORPHOLOGY_ID")
    _require(compiled.get("descriptor_sha256") == DESCRIPTOR_SHA256, "DESCRIPTOR_SHA")
    morphology = compiled.get("morphology")
    _require(isinstance(morphology, dict), "MORPHOLOGY")
    assert isinstance(morphology, dict)
    _require(
        morphology.get("morphology_spec_sha256") == MORPHOLOGY_SPEC_SHA256,
        "MORPHOLOGY_SPEC_SHA",
    )
    geometry = compiled.get("geometry")
    spec = morphology.get("morphology_spec")
    _require(isinstance(geometry, dict), "GEOMETRY")
    _require(isinstance(spec, dict), "SPEC")
    assert isinstance(geometry, dict)
    assert isinstance(spec, dict)
    torso_size = geometry.get("torso_size_m")
    _require(isinstance(torso_size, dict), "TORSO_SIZE")
    assert isinstance(torso_size, dict)
    torso_half_height_m = float(torso_size["y"]) / 2.0
    bodies = _by_id(spec["bodies"], "body_id")
    joints = _by_id(spec["joints"], "joint_id")
    limb_decisions: list[dict[str, Any]] = []
    for limb in spec["limbs"]:
        ordered_joint_ids = limb["ordered_joint_ids"]
        _require(len(ordered_joint_ids) == 2, "LIMB_JOINT_COUNT")
        upper_body_id = str(limb["root_body_id"])
        hip_joint_id = str(ordered_joint_ids[0])
        decision = _upper_link_decision(
            torso_half_height_m=torso_half_height_m,
            upper=bodies[upper_body_id],
            hip=joints[hip_joint_id],
        )
        decision["limb_id"] = str(limb["limb_id"])
        limb_decisions.append(decision)
    _require(len(limb_decisions) == 4, "LIMB_COUNT")
    maximum_clearance_m = max(
        item["maximum_upper_capsule_clearance_m"] for item in limb_decisions
    )
    all_nonpenetrating = all(item["nonpenetrating"] for item in limb_decisions)
    return {
        "schema_version": SCHEMA_VERSION,
        "gate_id": GATE_ID,
        "question_class": "finite_decision",
        "population": "exact_s169_nominal_roll_joint_limit_valid_ventral_tangent_pose_family",
        "morphology_id": MORPHOLOGY_ID,
        "descriptor_sha256": DESCRIPTOR_SHA256,
        "morphology_spec_sha256": MORPHOLOGY_SPEC_SHA256,
        "feasibility_threshold_m": FEASIBILITY_THRESHOLD_M,
        "ordered_limb_decisions": limb_decisions,
        "maximum_clearance_across_limb_upper_bounds_m": maximum_clearance_m,
        "feasible": all_nonpenetrating,
        "decision": (
            "exact_pose_family_feasible"
            if all_nonpenetrating
            else "exact_pose_family_infeasible_upper_link_necessary_condition"
        ),
        "knee_search_required": False,
        "mujoco_imported": False,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "held_out_cell_access_count": 0,
        "held_out_selector_invocation_count": 0,
        "arbitrary_morphology_claimed": False,
        "population_inference_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--core-library", type=Path, required=True)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    arguments = _parser().parse_args(argv)
    core = LocomotionCore(arguments.core_library.resolve())
    compiled = core.compile_bounded_quadruped(r23d60_selected_s169_quadruped())
    print(json.dumps(evaluate_compiled_v1(compiled), allow_nan=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
