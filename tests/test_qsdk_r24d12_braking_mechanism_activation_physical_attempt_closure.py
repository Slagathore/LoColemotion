#!/usr/bin/env python3
"""Audit the immutable consumed-invalid R24D12 physical attempt."""

from __future__ import annotations

import copy
import hashlib
import importlib.util
import json
import math
import struct
import subprocess
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
CLOSURE_PATH = ROOT / "sdk/recovery/r24d12_godot_jolt_braking_mechanism_activation_physical_attempt_closure_v1.json"
EVALUATOR_PATH = ROOT / "sdk/recovery/r24d12_godot_jolt_braking_mechanism_activation_evaluator.py"
AUTHORIZATION_PATH = ROOT / "sdk/recovery/r24d12_godot_jolt_braking_mechanism_activation_physical_authorization_v1.json"
RUN_ROOT = Path(
    "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/"
    "qsdk-r24d12-braking-mechanism-activation/physical/"
    "20260826T223912889Z-0a15d68a-f58e60297ec4"
)
AUTHORIZATION_COMMIT = "0a15d68acef43d632089e1df15d2a0260848d826"
QUALIFIED_PARENT = "a9f6eaad2ef59558bdee4ba87187ed0d27555f66"
NONCE = "f58e60297ec4490784d9691bb2387fdb"
EXPECTED_REJECTION = "FIXTURE_CHILD_INERTIA_DIAGONAL_KG_M2"
EXPECTED_NATIVE_INERTIA = struct.unpack("<f", struct.pack("<f", 0.05))[0]


class AuditError(RuntimeError):
    """Raised when immutable closure authority drifts."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AuditError(message)


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    require(type(value) is dict, f"JSON_NOT_OBJECT:{path}")
    return value


def raw_sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def git(*args: str) -> str:
    completed = subprocess.run(
        ["git", *args],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    return completed.stdout.strip()


def load_evaluator() -> Any:
    spec = importlib.util.spec_from_file_location("r24d12_evaluator", EVALUATOR_PATH)
    require(spec is not None and spec.loader is not None, "EVALUATOR_IMPORT_SPEC")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def validate_closure(closure: dict[str, Any]) -> None:
    require(
        closure.get("schema_version")
        == "sporespore_qsdk_r24d12_braking_mechanism_activation_physical_attempt_closure_v1",
        "CLOSURE_SCHEMA",
    )
    require(closure.get("closure_id") == "QSDK-R24D12-PHYSICAL-CLOSURE-V1", "CLOSURE_ID")
    require(closure.get("gate_id") == "QSDK-R24D12", "CLOSURE_GATE")
    require(closure.get("question_class") == "development", "CLOSURE_QUESTION_CLASS")
    require(
        closure.get("status")
        == "closed_consumed_invalid_incomplete_after_one_world_float32_readback_exactness_rejection",
        "CLOSURE_STATUS",
    )

    authorization = closure.get("authorization", {})
    require(authorization.get("authorization_commit") == AUTHORIZATION_COMMIT, "AUTHORIZATION_COMMIT")
    require(authorization.get("authorization_parent_commit") == QUALIFIED_PARENT, "AUTHORIZATION_PARENT")
    require(authorization.get("authorization_only_check_passed") is True, "AUTHORIZATION_CHECK")
    require(authorization.get("authorized_attempt_limit") == 1, "AUTHORIZATION_LIMIT")
    require(authorization.get("same_source_rerun_allowed") is False, "AUTHORIZATION_RERUN")

    retained = closure.get("retained_evidence", {})
    require(Path(retained.get("run_root", "")) == RUN_ROOT, "RUN_ROOT")
    require(retained.get("execution_nonce") == NONCE, "RETAINED_NONCE")
    require(retained.get("file_count") == 15, "RETAINED_FILE_COUNT")
    require(retained.get("total_byte_length") == 78778, "RETAINED_BYTES")
    require(retained.get("unique_content_digest_count") == 13, "RETAINED_UNIQUE_DIGESTS")
    require(retained.get("receipt_published") is False, "RECEIPT_PUBLICATION")
    require(retained.get("evaluation_published") is False, "EVALUATION_PUBLICATION")

    execution = closure.get("execution", {})
    require(execution.get("world_attempt_count") == 1, "WORLD_ATTEMPTS")
    require(execution.get("world_build_count") == 1, "WORLD_BUILDS")
    require(execution.get("solver_step_count") == 1, "SOLVER_STEPS")
    require(execution.get("retained_sample_count") == 4, "RETAINED_SAMPLES")
    require(execution.get("evaluator_exit_code") == 1, "EVALUATOR_EXIT")
    require(execution.get("attempt_status") == "failed_or_incomplete_retained", "ATTEMPT_STATUS")

    diagnosis = closure.get("failure_diagnosis", {})
    require(
        diagnosis.get("failure_class") == "evaluator_fixture_readback_exactness_rejection",
        "FAILURE_CLASS",
    )
    require(diagnosis.get("evaluator_error_code") == EXPECTED_REJECTION, "FAILURE_CODE")
    require(diagnosis.get("frozen_expected_value") == [0.05, 0.05, 0.05], "EXPECTED_INERTIA")
    require(
        diagnosis.get("native_serialized_value")
        == [EXPECTED_NATIVE_INERTIA, EXPECTED_NATIVE_INERTIA, EXPECTED_NATIVE_INERTIA],
        "NATIVE_INERTIA",
    )
    require(
        diagnosis.get("per_component_absolute_difference")
        == abs(EXPECTED_NATIVE_INERTIA - 0.05),
        "INERTIA_DIFFERENCE",
    )
    require(diagnosis.get("physics_negative") is False, "PHYSICS_NEGATIVE")
    require(diagnosis.get("valid_finite_physics_result") is False, "VALID_RESULT")
    require(diagnosis.get("infrastructure_invalid_or_incomplete") is True, "INVALID_RESULT")

    disposition = closure.get("disposition", {})
    require(disposition.get("attempt_consumed") is True, "ATTEMPT_CONSUMED")
    require(disposition.get("same_source_rerun_forbidden") is True, "RERUN_FORBIDDEN")
    require(disposition.get("frozen_evaluator_may_be_rewritten") is False, "EVALUATOR_REWRITE")
    require(disposition.get("raw_report_may_be_selectively_promoted") is False, "RAW_PROMOTION")
    require(disposition.get("distinct_prospective_successor_required") is True, "SUCCESSOR_REQUIRED")
    require(disposition.get("successor_may_reuse_r24d12_as_accepted_physical_evidence") is False, "EVIDENCE_REUSE")

    claims = closure.get("claims", {})
    require(claims.get("physical_characterization_executed") is True, "PHYSICAL_EXECUTED")
    for field in (
        "accepted_physical_characterization",
        "native_braking_mechanism_activation_observed",
        "numerical_accuracy_accepted",
        "instrumented_profile_promoted",
        "stock_godot_profile_promoted",
        "native_capability_conjunction_complete",
        "recovery_world_opened",
        "prone_to_standing_world_opened",
        "turning_claim_changed",
        "cross_engine_equivalence_claimed",
        "q_sdk_r24_satisfied",
        "physical_acceptance_authority",
        "release_authority",
    ):
        require(claims.get(field) is False, f"CLAIM_{field.upper()}")
    require(closure.get("next_boundary", {}).get("next_gate_id") == "QSDK-R24D13", "NEXT_GATE")


def audit_inventory(closure: dict[str, Any]) -> None:
    declared = closure["retained_evidence"]["inventory"]
    require(type(declared) is list and len(declared) == 15, "INVENTORY_SHAPE")
    actual_paths = sorted(
        path.relative_to(RUN_ROOT).as_posix()
        for path in RUN_ROOT.rglob("*")
        if path.is_file()
    )
    declared_paths = [item["path"] for item in declared]
    require(declared_paths == sorted(declared_paths), "INVENTORY_ORDER")
    require(declared_paths == actual_paths, "INVENTORY_PATHS")
    total_bytes = 0
    digests: set[str] = set()
    for item in declared:
        path = RUN_ROOT / item["path"]
        require(path.is_file(), f"INVENTORY_MISSING:{item['path']}")
        require(path.stat().st_size == item["byte_length"], f"INVENTORY_BYTES:{item['path']}")
        digest = raw_sha256(path)
        require(digest == item["raw_sha256"], f"INVENTORY_SHA:{item['path']}")
        total_bytes += path.stat().st_size
        digests.add(digest)
    require(total_bytes == closure["retained_evidence"]["total_byte_length"], "INVENTORY_TOTAL_BYTES")
    require(len(digests) == closure["retained_evidence"]["unique_content_digest_count"], "INVENTORY_DIGESTS")
    require(not (RUN_ROOT / "evaluation.json").exists(), "UNDECLARED_EVALUATION")
    require(not (RUN_ROOT / "receipt.json").exists(), "UNDECLARED_RECEIPT")
    physical_root = RUN_ROOT.parent
    require([path for path in physical_root.iterdir() if path.is_dir()] == [RUN_ROOT], "R24D12_RERUN_DETECTED")


def audit_git_and_attempt(closure: dict[str, Any]) -> dict[str, Any]:
    parents = git("rev-list", "--parents", "-n", "1", AUTHORIZATION_COMMIT).split()
    require(parents == [AUTHORIZATION_COMMIT, QUALIFIED_PARENT], "AUTHORIZATION_PARENT_EDGE")
    tracked_authorization = subprocess.run(
        ["git", "show", f"{AUTHORIZATION_COMMIT}:sdk/recovery/{AUTHORIZATION_PATH.name}"],
        cwd=ROOT,
        check=True,
        capture_output=True,
    ).stdout
    require(
        "sha256:" + hashlib.sha256(tracked_authorization).hexdigest()
        == closure["authorization"]["authorization_raw_sha256"],
        "TRACKED_AUTHORIZATION_SHA",
    )
    authorization = load_json(AUTHORIZATION_PATH)
    require("authorization_commit" not in authorization, "AUTHORIZATION_SELF_IDENTITY")
    require(authorization.get("authorization_parent_commit") == QUALIFIED_PARENT, "AUTHORIZATION_JSON_PARENT")

    attempt = load_json(RUN_ROOT / "attempt.json")
    require(attempt.get("schema_version") == "sporespore_qsdk_r24d12_physical_attempt_v1", "ATTEMPT_SCHEMA")
    require(attempt.get("status") == "failed_or_incomplete_retained", "ATTEMPT_RETAINED_STATUS")
    require(attempt.get("authorization_commit") == AUTHORIZATION_COMMIT, "ATTEMPT_AUTHORIZATION")
    require(attempt.get("execution_nonce") == NONCE, "ATTEMPT_NONCE")
    require(attempt.get("world_attempt_count") == 1, "ATTEMPT_WORLD_COUNT")
    require(attempt.get("world_build_count") == 1, "ATTEMPT_BUILD_COUNT")
    require(attempt.get("solver_step_count") == 1, "ATTEMPT_STEP_COUNT")
    require(attempt.get("retained_sample_count") == 4, "ATTEMPT_SAMPLE_COUNT")
    require(attempt.get("same_source_rerun_allowed") is False, "ATTEMPT_RERUN")
    require(EXPECTED_REJECTION in attempt.get("failure", ""), "ATTEMPT_FAILURE")
    return attempt


def audit_raw_report(closure: dict[str, Any], evaluator: Any) -> None:
    report = load_json(RUN_ROOT / "raw-report.json")
    require(report.get("source_commit") == AUTHORIZATION_COMMIT, "REPORT_SOURCE")
    require(report.get("execution_nonce") == NONCE, "REPORT_NONCE")
    require(report.get("evidence_kind") == "native_physical", "REPORT_KIND")
    require(report.get("execution", {}).get("world_attempt_count") == 1, "REPORT_WORLD_COUNT")
    require(report.get("execution", {}).get("world_build_count") == 1, "REPORT_BUILD_COUNT")
    require(report.get("execution", {}).get("physics_step_count") == 1, "REPORT_STEP_COUNT")
    require(report.get("execution", {}).get("retained_sample_count") == 4, "REPORT_SAMPLE_COUNT")
    require(report.get("fixture", {}).get("child_inertia_diagonal_kg_m2") == [EXPECTED_NATIVE_INERTIA] * 3, "REPORT_FIXTURE_INERTIA")
    require(len(report.get("cells", [])) == 4, "REPORT_CELL_COUNT")
    for cell in report["cells"]:
        require(cell["parameter_readback"]["child_inertia_diagonal_kg_m2"] == [EXPECTED_NATIVE_INERTIA] * 3, "REPORT_PARAMETER_INERTIA")
        require(len(cell["samples"]) == 1, "REPORT_CELL_SAMPLE_COUNT")

    try:
        evaluator.evaluate(
            report,
            expected_evidence_kind="native_physical",
            expected_source_commit=AUTHORIZATION_COMMIT,
            expected_nonce=NONCE,
        )
    except evaluator.EvaluationError as exc:
        require(str(exc) == EXPECTED_REJECTION, "EVALUATOR_REJECTION_CODE")
    else:
        raise AuditError("FROZEN_EVALUATOR_DID_NOT_REJECT")

    diagnostic_copy = copy.deepcopy(report)
    diagnostic_copy["fixture"]["child_inertia_diagonal_kg_m2"] = [0.05, 0.05, 0.05]
    for cell in diagnostic_copy["cells"]:
        cell["parameter_readback"]["child_inertia_diagonal_kg_m2"] = [0.05, 0.05, 0.05]
    counterfactual = evaluator.evaluate(
        diagnostic_copy,
        expected_evidence_kind="native_physical",
        expected_source_commit=AUTHORIZATION_COMMIT,
        expected_nonce=NONCE,
    )
    require(
        counterfactual.get("result")
        == "complete_valid_finite_native_braking_mechanism_activation_positive",
        "DIAGNOSTIC_SINGLE_FIELD_FAMILY_CAUSALITY",
    )
    require(counterfactual.get("summary", {}).get("motor_enabled_braking_witness_count") == 2, "RAW_ENABLED_PATTERN")
    require(counterfactual.get("summary", {}).get("motor_disabled_zero_witness_count") == 2, "RAW_DISABLED_PATTERN")
    require(closure["claims"]["native_braking_mechanism_activation_observed"] is False, "COUNTERFACTUAL_PROMOTION")


def mutation_audit(closure: dict[str, Any]) -> int:
    mutations: list[tuple[tuple[str, ...], Any]] = [
        (("status",), "positive"),
        (("question_class",), "finite_decision"),
        (("authorization", "same_source_rerun_allowed"), True),
        (("retained_evidence", "file_count"), 14),
        (("retained_evidence", "receipt_published"), True),
        (("execution", "world_attempt_count"), 0),
        (("execution", "solver_step_count"), 0),
        (("failure_diagnosis", "evaluator_error_code"), "OTHER"),
        (("failure_diagnosis", "physics_negative"), True),
        (("failure_diagnosis", "valid_finite_physics_result"), True),
        (("disposition", "attempt_consumed"), False),
        (("disposition", "same_source_rerun_forbidden"), False),
        (("disposition", "raw_report_may_be_selectively_promoted"), True),
        (("claims", "accepted_physical_characterization"), True),
        (("claims", "native_braking_mechanism_activation_observed"), True),
        (("claims", "release_authority"), True),
        (("next_boundary", "next_gate_id"), "QSDK-R24"),
    ]
    rejected = 0
    for path, value in mutations:
        candidate = copy.deepcopy(closure)
        cursor: dict[str, Any] = candidate
        for part in path[:-1]:
            cursor = cursor[part]
        cursor[path[-1]] = value
        try:
            validate_closure(candidate)
        except AuditError:
            rejected += 1
    require(rejected == len(mutations), "MUTATION_REJECTION_COUNT")
    return rejected


def main() -> int:
    closure = load_json(CLOSURE_PATH)
    validate_closure(closure)
    audit_inventory(closure)
    audit_git_and_attempt(closure)
    evaluator = load_evaluator()
    audit_raw_report(closure, evaluator)
    mutations = mutation_audit(closure)
    print(
        "QSDK_R24D12_PHYSICAL_ATTEMPT_CLOSURE_PASS "
        f"files=15 unique_digests=13 bytes=78778 mutations={mutations} "
        "worlds=1 builds=1 solver_steps=1 accepted_result=false rerun=false "
        "physical_authority=false release_authority=false"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AuditError, OSError, ValueError, subprocess.CalledProcessError) as exc:
        print(f"QSDK_R24D12_PHYSICAL_ATTEMPT_CLOSURE_FAIL {exc}", file=sys.stderr)
        raise SystemExit(1)
