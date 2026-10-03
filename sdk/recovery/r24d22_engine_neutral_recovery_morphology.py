"""Execute the finite R24D22 recovery-morphology zero-world decision."""

from __future__ import annotations

import argparse
import copy
import json
import math
from pathlib import Path
import sys
from typing import Any, Callable, Mapping, Sequence


SDK_ROOT = Path(__file__).resolve().parents[1]
PYTHON_ROOT = SDK_ROOT / "python"
if str(PYTHON_ROOT) not in sys.path:
    sys.path.insert(0, str(PYTHON_ROOT))

from sporespore_locomotion import (  # noqa: E402
    LocomotionCore,
    LocomotionCoreError,
    r24d22_recovery_s169_morphology,
)


SCHEMA_VERSION = (
    "sporespore_qsdk_r24d22_engine_neutral_recovery_morphology_decision_v1"
)
GATE_ID = "QSDK-R24D22"
RECOVERY_MORPHOLOGY_ID = "qsdk_r24_recovery_s169_v1"
RECOVERY_DESCRIPTOR_SHA256 = (
    "sha256:431a9c8001931e751bb2f1f2750c31650dd2d994575a736c53adbef1b27a71f6"
)
BASE_DESCRIPTOR_SHA256 = (
    "sha256:ae7a0872b8b15dfb294c388931899cf82822293417d125dd72ee2a5a847e09e0"
)
BASE_MORPHOLOGY_SPEC_SHA256 = (
    "sha256:30893a75e8362dcab69f0fb46b0560cacbe5d5c034cb0152e67eb520ff35f45e"
)
RECOVERY_MORPHOLOGY_SPEC_SHA256 = (
    "sha256:926551af3a72eb1fd1f3b71bfb103587a0b906a116775551a2463792e2c160f9"
)
EXPECTED_MINIMUM_LIMB_CLEARANCE_M = 0.01625237411795359
EXPECTED_UPPER_CLEARANCE_M = 0.03370109688279206
EXPECTED_DISTAL_CLEARANCE_M = 0.01625237411795359
EXPECTED_CONTACT_CLEARANCE_M = 0.16375429922132906


class RecoveryMorphologyDecisionError(RuntimeError):
    """Stable fail-closed error for the finite zero-world evaluator."""


def require(condition: bool, code: str) -> None:
    if not condition:
        raise RecoveryMorphologyDecisionError(code)


def exact(actual: object, expected: object, code: str) -> None:
    require(actual == expected, f"{code}:expected={expected!r}:actual={actual!r}")


def changed(
    descriptor: Mapping[str, Any],
    mutation: Callable[[dict[str, Any]], None],
) -> dict[str, Any]:
    candidate = copy.deepcopy(dict(descriptor))
    mutation(candidate)
    return candidate


def expect_core_error(
    core: LocomotionCore,
    descriptor: Mapping[str, Any],
    expected_failure_code: str,
) -> dict[str, Any]:
    try:
        core.compile_recovery_morphology_v1(descriptor)
    except LocomotionCoreError as error:
        exact(error.failure_code, expected_failure_code, "CORE_ERROR_CODE")
        return {
            "failure_code": error.failure_code,
            "status": error.status,
            "accepted": False,
        }
    raise RecoveryMorphologyDecisionError(
        f"EXPECTED_CORE_ERROR:{expected_failure_code}"
    )


def evaluate(core: LocomotionCore) -> dict[str, Any]:
    descriptor = r24d22_recovery_s169_morphology()
    exact_receipt = core.compile_recovery_morphology_v1(descriptor)
    exact(exact_receipt["schema_version"], "sporespore_recovery_morphology_receipt_v1", "RECEIPT_SCHEMA")
    exact(exact_receipt["recovery_morphology_id"], RECOVERY_MORPHOLOGY_ID, "MORPHOLOGY_ID")
    exact(exact_receipt["descriptor_sha256"], RECOVERY_DESCRIPTOR_SHA256, "DESCRIPTOR_SHA")
    exact(exact_receipt["base_descriptor_sha256"], BASE_DESCRIPTOR_SHA256, "BASE_DESCRIPTOR_SHA")
    exact(
        exact_receipt["base_morphology_spec_sha256"],
        BASE_MORPHOLOGY_SPEC_SHA256,
        "BASE_MORPHOLOGY_SHA",
    )
    exact(
        exact_receipt["recovery_morphology_spec_sha256"],
        RECOVERY_MORPHOLOGY_SPEC_SHA256,
        "RECOVERY_MORPHOLOGY_SHA",
    )
    exact(exact_receipt["support_status"], "supported_exact", "EXACT_SUPPORT")
    exact(exact_receipt["refusal_reason"], None, "EXACT_REFUSAL")
    geometry = exact_receipt["prone_geometry"]
    exact(geometry["feasibility_threshold_m"], 0.0, "THRESHOLD")
    exact(geometry["minimum_ground_clearance_m"], 0.0, "TORSO_TANGENCY")
    exact(
        geometry["minimum_limb_ground_clearance_m"],
        EXPECTED_MINIMUM_LIMB_CLEARANCE_M,
        "MINIMUM_LIMB_CLEARANCE",
    )
    exact(geometry["all_limbs_fold_outward_from_torso"], True, "OUTWARD")
    exact(
        geometry["all_declared_collisions_ground_nonpenetrating"],
        True,
        "NONPENETRATION",
    )
    exact(geometry["feasible"], True, "FEASIBLE")
    limbs = geometry["ordered_limb_geometry"]
    exact(
        [limb["limb_id"] for limb in limbs],
        ["front_left", "front_right", "rear_left", "rear_right"],
        "LIMB_ORDER",
    )
    for limb in limbs:
        exact(
            limb["upper_capsule_minimum_ground_clearance_m"],
            EXPECTED_UPPER_CLEARANCE_M,
            f"UPPER_CLEARANCE:{limb['limb_id']}",
        )
        exact(
            limb["distal_capsule_minimum_ground_clearance_m"],
            EXPECTED_DISTAL_CLEARANCE_M,
            f"DISTAL_CLEARANCE:{limb['limb_id']}",
        )
        exact(
            limb["contact_site_ground_clearance_m"],
            EXPECTED_CONTACT_CLEARANCE_M,
            f"CONTACT_CLEARANCE:{limb['limb_id']}",
        )
        exact(limb["folds_outward_from_torso"], True, f"OUTWARD:{limb['limb_id']}")
        exact(limb["ground_nonpenetrating"], True, f"GROUND:{limb['limb_id']}")

    legacy = changed(
        descriptor,
        lambda value: (
            value.__setitem__("recovery_morphology_id", "r24d22_legacy_geometry_refusal"),
            value["joint_authority"].__setitem__("hip_anchor_parent_y_m", -0.05),
            value["joint_authority"].__setitem__("hip_limit_magnitude_rad", 0.72),
            value["canonical_prone_pose"].__setitem__("front_hip_angle_rad", 0.72),
            value["canonical_prone_pose"].__setitem__("rear_hip_angle_rad", -0.72),
        ),
    )
    legacy_receipt = core.compile_recovery_morphology_v1(legacy)
    exact(
        legacy_receipt["support_status"],
        "unsupported_prone_geometry_infeasible",
        "LEGACY_STATUS",
    )
    exact(
        legacy_receipt["refusal_reason"],
        "canonical_prone_pose_ground_penetration",
        "LEGACY_REASON",
    )
    require(
        legacy_receipt["prone_geometry"]["minimum_limb_ground_clearance_m"] < 0.0,
        "LEGACY_CLEARANCE",
    )

    inward = changed(
        descriptor,
        lambda value: (
            value.__setitem__("recovery_morphology_id", "r24d22_inward_fold_refusal"),
            value["canonical_prone_pose"].__setitem__("front_hip_angle_rad", -1.55),
            value["canonical_prone_pose"].__setitem__("front_knee_angle_rad", -1.10),
            value["canonical_prone_pose"].__setitem__("rear_hip_angle_rad", 1.55),
            value["canonical_prone_pose"].__setitem__("rear_knee_angle_rad", 1.10),
        ),
    )
    inward_receipt = core.compile_recovery_morphology_v1(inward)
    exact(
        inward_receipt["support_status"],
        "unsupported_prone_geometry_infeasible",
        "INWARD_STATUS",
    )
    exact(
        inward_receipt["refusal_reason"],
        "canonical_prone_pose_not_outward_fold",
        "INWARD_REASON",
    )
    exact(
        inward_receipt["prone_geometry"][
            "all_declared_collisions_ground_nonpenetrating"
        ],
        True,
        "INWARD_GROUND",
    )
    exact(
        inward_receipt["prone_geometry"]["all_limbs_fold_outward_from_torso"],
        False,
        "INWARD_FOLD",
    )

    tangent_anchor_m = (
        descriptor["joint_authority"]["hip_anchor_parent_y_m"]
        - geometry["minimum_limb_ground_clearance_m"]
    )
    tangent = changed(
        descriptor,
        lambda value: (
            value.__setitem__("recovery_morphology_id", "r24d22_exact_ground_boundary"),
            value["joint_authority"].__setitem__(
                "hip_anchor_parent_y_m", tangent_anchor_m
            ),
        ),
    )
    tangent_receipt = core.compile_recovery_morphology_v1(tangent)
    exact(tangent_receipt["support_status"], "supported_exact", "TANGENT_STATUS")
    exact(
        tangent_receipt["prone_geometry"]["minimum_limb_ground_clearance_m"],
        0.0,
        "TANGENT_CLEARANCE",
    )

    below_anchor_m = math.nextafter(
        math.nextafter(tangent_anchor_m, -math.inf),
        -math.inf,
    )
    below = changed(
        descriptor,
        lambda value: (
            value.__setitem__("recovery_morphology_id", "r24d22_below_ground_boundary"),
            value["joint_authority"].__setitem__(
                "hip_anchor_parent_y_m", below_anchor_m
            ),
        ),
    )
    below_receipt = core.compile_recovery_morphology_v1(below)
    exact(
        below_receipt["support_status"],
        "unsupported_prone_geometry_infeasible",
        "BELOW_STATUS",
    )
    exact(
        below_receipt["refusal_reason"],
        "canonical_prone_pose_ground_penetration",
        "BELOW_REASON",
    )
    require(
        below_receipt["prone_geometry"]["minimum_limb_ground_clearance_m"] < 0.0,
        "BELOW_CLEARANCE",
    )

    pose_outside = changed(
        descriptor,
        lambda value: value["canonical_prone_pose"].__setitem__(
            "front_hip_angle_rad", 1.61
        ),
    )
    anchor_outside = changed(
        descriptor,
        lambda value: value["joint_authority"].__setitem__(
            "hip_anchor_parent_y_m", 0.061
        ),
    )
    identity_collision = changed(
        descriptor,
        lambda value: value.__setitem__(
            "recovery_morphology_id",
            value["base_descriptor"]["morphology_id"],
        ),
    )
    unknown_field = changed(
        descriptor,
        lambda value: value.__setitem__("forbidden_override", True),
    )
    error_controls = [
        (
            "pose_outside_joint_limit_rejected",
            expect_core_error(core, pose_outside, "SCHEMA_INVALID"),
        ),
        (
            "hip_anchor_outside_torso_rejected",
            expect_core_error(core, anchor_outside, "SCHEMA_INVALID"),
        ),
        (
            "base_and_recovery_identity_collision_rejected",
            expect_core_error(core, identity_collision, "IDENTITY_INVALID"),
        ),
        (
            "unknown_top_level_field_rejected",
            expect_core_error(core, unknown_field, "SCHEMA_INVALID"),
        ),
    ]

    mutation_controls = [
        {
            "mutation_id": "legacy_joint_geometry_typed_refusal",
            "passed": True,
            "support_status": legacy_receipt["support_status"],
            "minimum_limb_ground_clearance_m": legacy_receipt["prone_geometry"][
                "minimum_limb_ground_clearance_m"
            ],
        },
        {
            "mutation_id": "inward_fold_typed_refusal",
            "passed": True,
            "support_status": inward_receipt["support_status"],
            "ground_nonpenetrating": inward_receipt["prone_geometry"][
                "all_declared_collisions_ground_nonpenetrating"
            ],
            "outward_folded": inward_receipt["prone_geometry"][
                "all_limbs_fold_outward_from_torso"
            ],
        },
        {
            "mutation_id": "exact_ground_boundary_accepted",
            "passed": True,
            "hip_anchor_parent_y_m": tangent_anchor_m,
            "hip_anchor_parent_y_binary64_hex": tangent_anchor_m.hex(),
            "minimum_limb_ground_clearance_m": 0.0,
            "support_status": tangent_receipt["support_status"],
        },
        {
            "mutation_id": "two_binary64_steps_below_ground_boundary_refused",
            "passed": True,
            "hip_anchor_parent_y_m": below_anchor_m,
            "hip_anchor_parent_y_binary64_hex": below_anchor_m.hex(),
            "minimum_limb_ground_clearance_m": below_receipt["prone_geometry"][
                "minimum_limb_ground_clearance_m"
            ],
            "support_status": below_receipt["support_status"],
        },
    ]
    mutation_controls.extend(
        {
            "mutation_id": mutation_id,
            "passed": True,
            **error,
        }
        for mutation_id, error in error_controls
    )
    exact(len(mutation_controls), 8, "MUTATION_COUNT")

    return {
        "schema_version": SCHEMA_VERSION,
        "gate_id": GATE_ID,
        "question_class": "development",
        "physical_question_declared": False,
        "recovery_morphology_id": RECOVERY_MORPHOLOGY_ID,
        "recovery_descriptor_sha256": exact_receipt["descriptor_sha256"],
        "base_descriptor_sha256": exact_receipt["base_descriptor_sha256"],
        "base_morphology_spec_sha256": exact_receipt[
            "base_morphology_spec_sha256"
        ],
        "recovery_morphology_spec_sha256": exact_receipt[
            "recovery_morphology_spec_sha256"
        ],
        "support_status": exact_receipt["support_status"],
        "feasibility_threshold_m": geometry["feasibility_threshold_m"],
        "minimum_limb_ground_clearance_m": geometry[
            "minimum_limb_ground_clearance_m"
        ],
        "ordered_limb_geometry": limbs,
        "mutation_controls": mutation_controls,
        "mutation_control_count": len(mutation_controls),
        "mutation_controls_passed": len(mutation_controls),
        "legacy_base_descriptor_preserved": exact_receipt["claim_boundary"][
            "legacy_base_descriptor_preserved"
        ],
        "legacy_base_morphology_spec_preserved": exact_receipt["claim_boundary"][
            "legacy_base_morphology_spec_preserved"
        ],
        "engine_imported": False,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "held_out_cell_access_count": 0,
        "held_out_selector_invocation_count": 0,
        "arbitrary_morphology_recovery_claimed": False,
        "controller_compatibility_claimed": False,
        "recovery_behavior_claimed": False,
        "prone_to_standing_claimed": False,
        "cross_engine_recovery_claimed": False,
        "cross_engine_equivalence_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def parser() -> argparse.ArgumentParser:
    value = argparse.ArgumentParser(description=__doc__)
    value.add_argument("--core-library", type=Path, required=True)
    return value


def main(argv: Sequence[str] | None = None) -> int:
    arguments = parser().parse_args(argv)
    core = LocomotionCore(arguments.core_library.resolve())
    print(json.dumps(evaluate(core), allow_nan=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"QSDK_R24D22_RECOVERY_MORPHOLOGY_FAIL {error}", file=sys.stderr)
        raise
