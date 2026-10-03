"""Verify the retained QSDK-R24D25 invalid development closure."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess
import sys
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
CLOSURE = REPO_ROOT / "sdk/recovery/r24d25_first_active_command_invalid_closure_v1.json"
SOURCE_COMMIT = "03ee06a5a2b43aedf3e9e8320678060b17205741"


class ClosureError(RuntimeError):
    pass


def require(condition: bool, code: str) -> None:
    if not condition:
        raise ClosureError(code)


def exact(actual: object, expected: object, code: str) -> None:
    require(actual == expected, f"{code}:expected={expected!r}:actual={actual!r}")


def load(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(value, dict), f"JSON_ROOT:{path}")
    return value


def sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def source_at_commit(relative: str) -> str:
    return subprocess.run(
        ["git", "show", f"{SOURCE_COMMIT}:{relative}"],
        cwd=REPO_ROOT,
        check=True,
        capture_output=True,
        text=True,
        encoding="utf-8",
    ).stdout


def verify_artifacts(root: Path, artifacts: list[dict[str, Any]]) -> None:
    for artifact in artifacts:
        path = root / artifact["path"]
        require(path.is_file(), f"ARTIFACT_MISSING:{path}")
        exact(path.stat().st_size, artifact["byte_length"], f"LENGTH:{path.name}")
        exact(sha256(path), artifact["raw_sha256"], f"DIGEST:{path.name}")


def audit() -> None:
    closure = load(CLOSURE)
    exact(
        closure["schema_version"],
        "sporespore_qsdk_r24d25_first_active_command_invalid_closure_v1",
        "SCHEMA",
    )
    exact(closure["gate_id"], "QSDK-R24D25", "GATE")
    exact(closure["question_class"], "development", "QUESTION")
    exact(closure["source_commit"], SOURCE_COMMIT, "SOURCE")
    subprocess.run(
        ["git", "cat-file", "-e", f"{SOURCE_COMMIT}^{{commit}}"],
        cwd=REPO_ROOT,
        check=True,
        capture_output=True,
    )
    contract = REPO_ROOT / closure["contract_path"]
    exact(sha256(contract), closure["contract_raw_sha256"], "CONTRACT_DIGEST")

    qualification = closure["qualification"]
    qualification_root = Path(qualification["evidence_root"])
    verify_artifacts(qualification_root, qualification["retained_artifacts"])
    receipt = load(qualification_root / qualification["receipt_path"])
    exact(receipt["ok"], True, "QUALIFICATION_OK")
    exact(receipt["source_commit"], SOURCE_COMMIT, "QUALIFICATION_SOURCE")
    exact(len(receipt["source_manifest"]), 47, "QUALIFICATION_MANIFEST")
    exact(receipt["production_preflight"]["negative_control_count"], 23, "CONTROLS")
    exact(receipt["production_preflight"]["negative_controls_passed"], 23, "PASS")
    for key in (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
    ):
        exact(receipt[key], 0, f"QUALIFICATION_{key.upper()}")

    attempt = closure["physical_attempt"]
    attempt_root = Path(attempt["evidence_root"])
    verify_artifacts(attempt_root, attempt["retained_artifacts"])
    invalid = load(attempt_root / "invalid_result.json")
    completion = load(attempt_root / "supervisor_completion.json")
    reservation = load(attempt_root / "attempt_reservation.json")
    exact(invalid["source_commit"], SOURCE_COMMIT, "INVALID_SOURCE")
    exact(invalid["invalid_but_retained"], True, "INVALID_RETAINED")
    exact(invalid["error_type"], "TypeError", "ERROR_TYPE")
    exact(invalid["error"], "Object of type bool is not JSON serializable", "ERROR")
    require("application_sha256" in invalid["traceback"], "STACK_APPLICATION")
    require("json.dumps" in invalid["traceback"], "STACK_JSON")
    exact(completion["worker_exit_code"], 2, "WORKER_EXIT")
    exact(completion["invalid_or_incomplete_retained"], True, "COMPLETION")
    exact(completion["operation_lock_released"], True, "LOCK_RELEASED")
    exact(reservation["horizon_steps_per_arm"], 13, "HORIZON")
    exact(reservation["held_out_cell_access_count"], 0, "HELDOUT")

    source_path = closure["observed_cause"]["source_path"]
    source = source_at_commit(source_path)
    comparison = "host_clamped[index] = targets[index] != requested"
    receipt_field = '"ordered_host_clamped": host_clamped'
    canonicalization = "application_sha256 = _canonical_sha256(self.core, application)"
    require(comparison in source, "SOURCE_COMPARISON")
    require(receipt_field in source, "SOURCE_RECEIPT_FIELD")
    require(canonicalization in source, "SOURCE_CANONICALIZATION")
    require(
        source.index(comparison) < source.index(receipt_field) < source.index(canonicalization),
        "SOURCE_ORDER",
    )
    require('"host_clamped": bool(host_clamped[index])' in source, "LATE_BOOL_CAST")
    exact(attempt["candidate_arm_entered"], True, "CANDIDATE")
    exact(attempt["matched_zero_arm_entered"], False, "MATCHED_ZERO")
    exact(attempt["outer_step_count_inferred"], 13, "INFERRED_OUTER")
    exact(attempt["solver_step_count_inferred"], 65, "INFERRED_SOLVER")
    exact(attempt["execution_count_inference_is_direct_runtime_counter"], False, "INFERENCE")

    cause = closure["observed_cause"]
    exact(cause["class"], "active_application_numpy_boolean_not_json_serializable", "CAUSE")
    exact(cause["active_path_exposed_for_first_time"], True, "ACTIVE_PATH")
    for key in (
        "physics_behavior_failure",
        "threshold_failure",
        "selector_failure",
        "evaluator_failure",
        "result_interpretation_rewritten",
    ):
        exact(cause[key], False, f"CAUSE_{key.upper()}")

    postmortem = closure["zero_world_gate_postmortem"]
    exact(postmortem["gate_result_rewritten"], False, "GATE_REWRITE")
    exact(postmortem["gate_was_adequate_for_physical_opening"], False, "ADEQUACY")
    exact(postmortem["full_seeded_ghost_required"], False, "FULL_GHOST")
    exact(postmortem["additional_physical_canary_required"], False, "CANARY")
    decision = closure["decision"]
    exact(decision["r24d25_result"], "consumed_invalid_incomplete_and_retained", "DECISION")
    exact(decision["r24d25_may_be_rerun"], False, "RERUN")
    exact(decision["sdk1_completed_steps"], 11, "SDK1")
    exact(decision["sdk1_total_steps"], 20, "SDK1_TOTAL")
    exact(closure["next_boundary"]["gate_id"], "QSDK-R24D26", "NEXT")
    exact(closure["claim_boundary"]["first_active_command_covered"], False, "COVERED")
    exact(closure["claim_boundary"]["prone_to_standing_claimed"], False, "STANDING")

    print(
        "QSDK_R24D25_INVALID_CLOSURE_PASS result=invalid_incomplete "
        "cause=active_application_numpy_bool candidate_outer_inferred=13 "
        "solver_steps_inferred=65 heldout_access=0 next=QSDK-R24D26"
    )


if __name__ == "__main__":
    try:
        audit()
    except Exception as error:
        print(f"QSDK_R24D25_INVALID_CLOSURE_FAIL {error}", file=sys.stderr)
        raise SystemExit(1) from error
