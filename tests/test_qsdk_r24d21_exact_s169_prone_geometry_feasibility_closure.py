"""Verify the exact QSDK-R24D21 finite geometry decision closure."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
CLOSURE_RELATIVE = Path(
    "sdk/recovery/r24d21_exact_s169_prone_geometry_feasibility_closure_v1.json"
)
SOURCE_COMMIT = "603f33678d2cbb811b8b4430e07b1c64e1bbc8e8"


class ClosureError(RuntimeError):
    pass


def require(condition: bool, code: str) -> None:
    if not condition:
        raise ClosureError(code)


def exact(actual: object, expected: object, code: str) -> None:
    require(actual == expected, f"{code}: expected={expected!r} actual={actual!r}")


def _reject_duplicates(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    value: dict[str, Any] = {}
    for key, item in pairs:
        require(key not in value, f"DUPLICATE_KEY:{key}")
        value[key] = item
    return value


def load(path: Path) -> dict[str, Any]:
    value = json.loads(
        path.read_text(encoding="utf-8"),
        object_pairs_hook=_reject_duplicates,
    )
    require(isinstance(value, dict), f"JSON_ROOT:{path}")
    assert isinstance(value, dict)
    return value


def raw_sha256_bytes(value: bytes) -> str:
    return "sha256:" + hashlib.sha256(value).hexdigest()


def raw_sha256(path: Path) -> str:
    return raw_sha256_bytes(path.read_bytes())


def canonical_bytes(value: object) -> bytes:
    return json.dumps(
        value,
        allow_nan=False,
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")


def source_at_commit(relative: str) -> bytes:
    result = subprocess.run(
        ["git", "show", f"{SOURCE_COMMIT}:{relative}"],
        cwd=REPO_ROOT,
        check=True,
        capture_output=True,
    )
    return result.stdout


def audit() -> None:
    closure = load(REPO_ROOT / CLOSURE_RELATIVE)
    exact(
        closure["schema_version"],
        "sporespore_qsdk_r24d21_exact_s169_prone_geometry_feasibility_closure_v1",
        "SCHEMA",
    )
    exact(closure["gate_id"], "QSDK-R24D21", "GATE")
    exact(closure["question_class"], "finite_decision", "QUESTION_CLASS")
    exact(closure["source_commit"], SOURCE_COMMIT, "SOURCE_COMMIT")
    subprocess.run(
        ["git", "cat-file", "-e", f"{SOURCE_COMMIT}^{{commit}}"],
        cwd=REPO_ROOT,
        check=True,
        capture_output=True,
    )

    contract_path = REPO_ROOT / closure["contract_path"]
    evaluator_path = REPO_ROOT / closure["evaluator_path"]
    source_audit_path = REPO_ROOT / closure["source_audit_path"]
    exact(raw_sha256(contract_path), closure["contract_raw_sha256"], "CONTRACT_DIGEST")
    exact(raw_sha256(evaluator_path), closure["evaluator_raw_sha256"], "EVALUATOR_DIGEST")
    exact(raw_sha256(source_audit_path), closure["source_audit_raw_sha256"], "SOURCE_AUDIT_DIGEST")
    for item in closure["bound_source"]:
        committed = source_at_commit(item["path"])
        exact(len(committed), item["byte_length"], f"SOURCE_LENGTH:{item['path']}")
        exact(
            raw_sha256_bytes(committed),
            item["raw_sha256"],
            f"SOURCE_DIGEST:{item['path']}",
        )

    contract = load(contract_path)
    exact(contract["question_class"], "finite_decision", "CONTRACT_CLASS")
    exact(contract["decision_rule"]["feasibility_threshold_m"], 0.0, "THRESHOLD")
    require(bool(contract["decision_rule"]["threshold_provenance"].strip()), "PROVENANCE")
    require(bool(contract["decision_rule"]["threshold_adequacy"].strip()), "ADEQUACY")
    exact(contract["decision_rule"]["new_margin_count"], 0, "MARGINS")
    exact(contract["decision_rule"]["post_outcome_rethresholding_permitted"], False, "RETHRESHOLD")

    execution = closure["execution"]
    exact(execution["source_identity_clean_pushed_remote_equal_before_execution"], True, "SOURCE_IDENTITY")
    exact(execution["core_rebuilt_before_decision"], True, "CORE_REBUILT")
    exact(execution["mujoco_imported"], False, "MUJOCO")
    for key in (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
        "held_out_cell_access_count",
        "held_out_selector_invocation_count",
    ):
        exact(execution[key], 0, f"EXECUTION_{key.upper()}")
    exact(execution["physics_state_modified"], False, "EXECUTION_PHYSICS")

    core_library = REPO_ROOT / "sdk/target/debug/sporespore_locomotion_core.dll"
    require(core_library.is_file(), "CORE_LIBRARY_MISSING")
    evaluated_process = subprocess.run(
        [
            sys.executable,
            str(evaluator_path),
            "--core-library",
            str(core_library),
        ],
        cwd=REPO_ROOT,
        check=True,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    evaluated = json.loads(evaluated_process.stdout, object_pairs_hook=_reject_duplicates)
    require(isinstance(evaluated, dict), "EVALUATED_ROOT")
    assert isinstance(evaluated, dict)
    evaluated_raw = canonical_bytes(evaluated)
    exact(len(evaluated_raw), execution["decision_canonical_byte_length"], "DECISION_LENGTH")
    exact(
        raw_sha256_bytes(evaluated_raw),
        execution["decision_canonical_sha256"],
        "DECISION_DIGEST",
    )
    for key in (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
        "held_out_cell_access_count",
        "held_out_selector_invocation_count",
    ):
        exact(evaluated[key], 0, f"EVALUATED_{key.upper()}")
    exact(evaluated["physics_state_modified"], False, "EVALUATED_PHYSICS")
    exact(evaluated["mujoco_imported"], False, "EVALUATED_MUJOCO")
    exact(evaluated["feasible"], False, "EVALUATED_FEASIBLE")
    exact(
        evaluated["decision"],
        "exact_pose_family_infeasible_upper_link_necessary_condition",
        "EVALUATED_DECISION",
    )
    exact(evaluated["knee_search_required"], False, "EVALUATED_KNEE")
    exact(len(evaluated["ordered_limb_decisions"]), 4, "EVALUATED_LIMBS")

    decision = closure["decision"]
    exact(decision["population_size"], 1, "POPULATION_SIZE")
    exact(decision["feasibility_threshold_m"], 0.0, "DECISION_THRESHOLD")
    exact(decision["feasible"], False, "DECISION_FEASIBLE")
    exact(decision["result"], evaluated["decision"], "DECISION_RESULT")
    exact(decision["ordered_limb_count"], 4, "DECISION_LIMBS")
    exact(decision["all_four_limb_bounds_identical"], True, "DECISION_IDENTICAL")
    exact(decision["knee_search_required"], False, "DECISION_KNEE")
    expected_geometry = decision["per_limb_geometry"]
    for item in evaluated["ordered_limb_decisions"]:
        for key, expected in expected_geometry.items():
            exact(item[key], expected, f"LIMB_{item['limb_id']}:{key}")
        exact(item["nonpenetrating"], False, f"LIMB_{item['limb_id']}:NONPENETRATING")
        exact(item["knee_configuration_can_change_this_bound"], False, f"LIMB_{item['limb_id']}:KNEE")
    exact(
        evaluated["maximum_clearance_across_limb_upper_bounds_m"],
        expected_geometry["maximum_upper_capsule_clearance_m"],
        "MAX_CLEARANCE",
    )

    cross_check = decision["r24d20_native_cross_check"]
    trace_path = Path(cross_check["evidence_root"]) / cross_check["artifact_path"]
    require(trace_path.is_file(), "R24D20_TRACE_MISSING")
    exact(raw_sha256(trace_path), cross_check["artifact_raw_sha256"], "R24D20_TRACE_DIGEST")
    trace = load(trace_path)
    first_clearances = {
        item["body_id"]: item["minimum_nonfoot_clearance_m"]
        for item in trace["result"]["candidate"]["observations"][0][
            "ordered_body_clearance_observations"
        ]
    }
    exact(
        first_clearances["front_left_upper"],
        cross_check["first_observation_front_left_upper_minimum_clearance_m"],
        "NATIVE_CROSS_CHECK",
    )
    exact(
        first_clearances["front_left_upper"],
        expected_geometry["maximum_upper_capsule_clearance_m"],
        "ANALYTIC_NATIVE_EQUAL",
    )
    exact(cross_check["analytic_and_native_value_exactly_equal"], True, "CROSS_CHECK_CLAIM")

    length_m = expected_geometry["upper_capsule_length_m"]
    radius_m = expected_geometry["upper_capsule_radius_m"]
    half_height_m = expected_geometry["torso_half_height_m"]
    hip_angle = expected_geometry["best_abs_hip_angle_rad"]
    tangent_anchor = length_m * math.cos(hip_angle) + radius_m - half_height_m
    tangent_clearance = (
        half_height_m + tangent_anchor - length_m * math.cos(hip_angle) - radius_m
    )
    above_anchor = math.nextafter(tangent_anchor, math.inf)
    above_clearance = (
        half_height_m + above_anchor - length_m * math.cos(hip_angle) - radius_m
    )
    mutations = closure["mutation_controls"]
    exact(len(mutations), 2, "MUTATION_COUNT")
    exact(mutations[0]["hip_anchor_parent_y_m"], tangent_anchor, "TANGENT_ANCHOR")
    exact(mutations[0]["maximum_upper_capsule_clearance_m"], tangent_clearance, "TANGENT_CLEARANCE")
    exact(mutations[0]["accepted"], tangent_clearance >= 0.0, "TANGENT_ACCEPTED")
    exact(mutations[1]["hip_anchor_parent_y_m"], above_anchor, "ABOVE_ANCHOR")
    exact(mutations[1]["maximum_upper_capsule_clearance_m"], above_clearance, "ABOVE_CLEARANCE")
    exact(mutations[1]["accepted"], above_clearance >= 0.0, "ABOVE_ACCEPTED")
    exact(math.nextafter(tangent_anchor, math.inf), above_anchor, "ADJACENT_ANCHOR")

    interpretation = closure["interpretation"]
    exact(interpretation["initializer_only_repair_possible_for_declared_pose_family"], False, "INITIALIZER_ONLY")
    exact(interpretation["compiled_morphology_capability_mismatch_identified"], True, "CAPABILITY_MISMATCH")
    exact(
        interpretation["current_s169_recovery_support_status"],
        "unsupported_declared_pose_family_geometry_infeasible",
        "SUPPORT_STATUS",
    )
    exact(interpretation["current_s169_walking_or_turning_evidence_changed"], False, "OTHER_EVIDENCE")
    exact(interpretation["physical_result_reinterpreted"], False, "PHYSICAL_REWRITE")

    next_boundary = closure["next_boundary"]
    exact(next_boundary["gate_id"], "QSDK-R24D22", "NEXT_GATE")
    exact(next_boundary["question_class"], "development", "NEXT_CLASS")
    exact(next_boundary["existing_s169_morphology_rewritten"], False, "NEXT_MORPHOLOGY_REWRITE")
    exact(next_boundary["physical_world_permitted_before_zero_world_geometry_feasibility"], False, "NEXT_PHYSICS")
    exact(next_boundary["held_out_cells_remain_sealed"], True, "NEXT_HELDOUT")

    claim = closure["claim_boundary"]
    exact(claim["finite_geometry_decision_observed"], True, "CLAIM_DECISION")
    exact(claim["exact_s169_declared_pose_family_infeasible"], True, "CLAIM_INFEASIBLE")
    for key in (
        "initializer_successor_implemented",
        "recovery_capable_morphology_implemented",
        "physical_question_opened",
        "controller_physical_viability_proven",
        "prone_to_standing_claimed",
        "held_out_validation_claimed",
        "cross_engine_recovery_claimed",
        "cross_engine_equivalence_claimed",
        "physical_acceptance_authority",
        "release_authority",
    ):
        exact(claim[key], False, f"CLAIM_{key.upper()}")

    print(
        "QSDK_R24D21_PRONE_GEOMETRY_CLOSURE_PASS result=infeasible "
        "population=1 maximum_clearance_m=-0.14984362962810435 "
        "native_cross_check_exact=True models=0 worlds=0 solver_steps=0 "
        "heldout_access=0 next=QSDK-R24D22"
    )


if __name__ == "__main__":
    try:
        audit()
    except Exception as error:
        print(f"QSDK_R24D21_PRONE_GEOMETRY_CLOSURE_FAIL {error}", file=sys.stderr)
        raise SystemExit(1) from error
