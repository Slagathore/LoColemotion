"""Verify the retained QSDK-R24D18 invalid development closure."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess
import sys
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
CLOSURE_RELATIVE = Path(
    "sdk/recovery/r24d18_mujoco_native_recovery_development_invalid_closure_v1.json"
)
SOURCE_COMMIT = "3b1714eaafc29d20629bf15fd6350ba859dc3fab"


class ClosureError(RuntimeError):
    pass


def require(condition: bool, code: str) -> None:
    if not condition:
        raise ClosureError(code)


def exact(actual: object, expected: object, code: str) -> None:
    require(actual == expected, f"{code}: expected={expected!r} actual={actual!r}")


def load(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(value, dict), "JSON_ROOT")
    assert isinstance(value, dict)
    return value


def raw_sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def audit() -> None:
    closure = load(REPO_ROOT / CLOSURE_RELATIVE)
    exact(
        closure["schema_version"],
        "sporespore_qsdk_r24d18_mujoco_native_recovery_development_invalid_closure_v1",
        "SCHEMA",
    )
    exact(closure["gate_id"], "QSDK-R24D18", "GATE")
    exact(closure["question_class"], "development", "QUESTION_CLASS")
    exact(closure["source_commit"], SOURCE_COMMIT, "SOURCE_COMMIT")
    subprocess.run(
        ["git", "cat-file", "-e", f"{SOURCE_COMMIT}^{{commit}}"],
        cwd=REPO_ROOT,
        check=True,
        capture_output=True,
    )

    qualification = closure["qualification"]
    qualification_root = Path(qualification["evidence_root"])
    qualification_receipt = qualification_root / qualification["receipt_path"]
    require(qualification_receipt.is_file(), "QUALIFICATION_RECEIPT_MISSING")
    exact(
        raw_sha256(qualification_receipt),
        qualification["receipt_raw_sha256"],
        "QUALIFICATION_DIGEST",
    )
    qualification_value = load(qualification_receipt)
    exact(qualification_value["ok"], True, "QUALIFICATION_OK")
    exact(qualification_value["source_commit"], SOURCE_COMMIT, "QUALIFICATION_SOURCE")
    for key in (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
    ):
        exact(qualification_value[key], 0, f"QUALIFICATION_{key.upper()}")
    exact(qualification_value["physics_state_modified"], False, "QUALIFICATION_PHYSICS")

    attempt = closure["physical_attempt"]
    attempt_root = Path(attempt["evidence_root"])
    require(attempt_root.is_dir(), "ATTEMPT_ROOT_MISSING")
    for artifact in closure["retained_artifacts"]:
        path = attempt_root / artifact["path"]
        require(path.is_file(), f"ARTIFACT_MISSING:{artifact['path']}")
        exact(path.stat().st_size, artifact["byte_length"], "ARTIFACT_LENGTH")
        exact(raw_sha256(path), artifact["raw_sha256"], "ARTIFACT_DIGEST")
    invalid = load(attempt_root / "invalid_result.json")
    exact(invalid["source_commit"], SOURCE_COMMIT, "INVALID_SOURCE")
    exact(invalid["invalid_but_retained"], True, "INVALID_RETAINED")
    exact(
        invalid["error"],
        "C6_MJC_SP_DEV_ACTUATOR_PROFILE_MISMATCH:front_left_knee_motor",
        "INVALID_ERROR",
    )
    exact(invalid["route_coverage_passed"], False, "INVALID_COVERAGE")
    exact(invalid["held_out_cell_access_count"], 0, "INVALID_HELDOUT")
    exact(invalid["prone_to_standing_claimed"], False, "INVALID_CLAIM")

    exact(attempt["selected_cell_id"], "development_nominal", "CELL")
    exact(attempt["selected_seed"], 1129522465, "SEED")
    exact(attempt["held_out_cell_access_count"], 0, "HELDOUT_ACCESS")
    exact(attempt["held_out_selector_invocation_count"], 0, "HELDOUT_SELECTOR")
    exact(attempt["model_construction_count"], 1, "MODEL_CONSTRUCTION")
    exact(attempt["data_construction_count"], 1, "DATA_CONSTRUCTION")
    exact(attempt["world_attempt_count"], 1, "WORLD_ATTEMPT")
    exact(attempt["world_build_count"], 0, "WORLD_BUILD")
    exact(attempt["solver_step_count"], 0, "SOLVER_STEP")
    exact(attempt["physics_state_modified"], False, "PHYSICS_MODIFIED")
    exact(attempt["route_coverage_passed"], False, "ROUTE_COVERAGE")
    exact(attempt["result_class"], "invalid_integration_result", "RESULT_CLASS")

    cause = closure["observed_cause"]
    exact(cause["class"], "route_validator_integration_mismatch", "CAUSE")
    exact(cause["physics_behavior_failure"], False, "PHYSICS_FAILURE")
    exact(cause["threshold_failure"], False, "THRESHOLD_FAILURE")
    exact(cause["selector_failure"], False, "SELECTOR_FAILURE")
    exact(cause["evaluator_failure"], False, "EVALUATOR_FAILURE")
    exact(cause["result_interpretation_rewritten"], False, "INTERPRETATION")

    decision = closure["decision"]
    exact(decision["r24d18_result"], "invalid_and_retained", "DECISION")
    exact(decision["r24d18_may_be_rerun"], False, "RERUN")
    exact(decision["controller_physical_viability_proven"], False, "VIABILITY")
    exact(decision["prone_to_standing_claimed"], False, "RECOVERY_CLAIM")
    exact(decision["sdk1_milestone_advanced"], False, "MILESTONE")
    exact(decision["sdk1_completed_steps"], 11, "SDK1_COUNT")
    exact(decision["sdk1_total_steps"], 20, "SDK1_TOTAL")

    next_boundary = closure["next_boundary"]
    exact(next_boundary["gate_id"], "QSDK-R24D19", "NEXT_GATE")
    exact(next_boundary["question_class"], "development", "NEXT_CLASS")
    for key in (
        "thresholds_changed",
        "selector_changed",
        "cell_changed",
        "seed_changed",
        "horizon_changed",
        "evaluator_changed",
    ):
        exact(next_boundary[key], False, f"NEXT_{key.upper()}")
    exact(next_boundary["held_out_cells_remain_sealed"], True, "NEXT_HELDOUT")

    claim = closure["claim_boundary"]
    exact(claim["complete_zero_world_gate_passed"], True, "ZERO_WORLD_CLAIM")
    exact(claim["physical_question_opened"], True, "PHYSICAL_OPENED")
    for key in (
        "valid_physical_behavior_result_observed",
        "native_route_coverage_proven",
        "controller_physical_viability_proven",
        "prone_to_standing_claimed",
        "repeatability_rate_claimed",
        "population_claimed",
        "held_out_validation_claimed",
        "cross_engine_recovery_claimed",
        "cross_engine_equivalence_claimed",
        "physical_acceptance_authority",
        "release_authority",
    ):
        exact(claim[key], False, f"CLAIM_{key.upper()}")

    print(
        "QSDK_R24D18_INVALID_CLOSURE_PASS result=invalid retained=True "
        "model_constructions=1 world_builds=0 solver_steps=0 heldout_access=0 "
        "prone_to_standing_claimed=False next=QSDK-R24D19"
    )


if __name__ == "__main__":
    try:
        audit()
    except Exception as error:
        print(f"QSDK_R24D18_INVALID_CLOSURE_FAIL {error}", file=sys.stderr)
        raise SystemExit(1) from error
