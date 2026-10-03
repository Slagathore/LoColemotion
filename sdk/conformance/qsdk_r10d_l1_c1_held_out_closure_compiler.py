#!/usr/bin/env python3
"""Close the consumed R10D-L1 held-out identity after a schema-only compiler miss."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
from typing import Any, Iterable

import qsdk_r10d_physical_closure as predecessor


ROOT = Path(__file__).resolve().parents[2]
EXPECTED_ROOT = Path(r"C:\Users\Cole\CodeStuff\games\SporeSpore")
EXPECTED_REMOTE = "https://github.com/Slagathore/sporespore.git"
CORRECTION_ID = "QSDK-R10D-L1-C1"
PARENT_REPAIR_ID = "QSDK-R10D-L1"
CAMPAIGN_ROLE = "held_out_finite_decision"

SOURCE_COMMIT = "e6db6c23b5bff1b48fc6204fc9db82ffbb252344"
STAGE_COMMIT = "62277b588b2495b8cdb897ab49f47055b835e39d"
AUTHORIZATION_COMMIT = "808653a293b29a0596a4d866d28c06cad7c3fd51"

DESIGN_RELATIVE = (
    "sdk/qsdk_r10d_l1_c1_held_out_closure_compiler_successor_design_v1.json"
)
DESIGN_PATH = ROOT / DESIGN_RELATIVE
DESIGN_BYTES = 8_162
DESIGN_SHA256 = (
    "sha256:73d09c06ce7fe6f8704c5ff41d2dede488d031ba51bab640e2d6f85d4821c26a"
)
COMPILER_RELATIVE = (
    "sdk/conformance/qsdk_r10d_l1_c1_held_out_closure_compiler.py"
)

PREDECESSOR_RELATIVE = "sdk/conformance/qsdk_r10d_physical_closure.py"
PREDECESSOR_BYTES = 72_788
PREDECESSOR_SHA256 = (
    "sha256:1aff9a85491c32c063f81f1cea03f269c4f889c80fad9bf471363ea4e3a8fd33"
)
PREDECESSOR_BLOB = "9ff977b4da9bf5cb4ee845701976fae4d62adab2"

AUTHORITY_MATERIALIZER_RELATIVE = (
    "sdk/conformance/qsdk_r10d_authority_materializer.py"
)
AUTHORITY_MATERIALIZER_BYTES = 53_615
AUTHORITY_MATERIALIZER_SHA256 = (
    "sha256:9637001196f5c95dcc6b2defcd17e3a6a5295daf385f21911d4a488f5fd8d047"
)
AUTHORITY_MATERIALIZER_BLOB = "427e69d350b6f7032334feae14146d1c1d60470e"

STAGE_RELATIVE = (
    "sdk/qsdk_r10d_held_out_finite_decision_"
    "zero_world_qualification_closure_v2.json"
)
STAGE_BYTES = 29_116
STAGE_SHA256 = (
    "sha256:593b7707941dd01d8bc89e6609a1936d9220f09c7b2c4fb727865817a74c6b74"
)
STAGE_BLOB = "89a541c484ce8df02332c5ab25f96d0beb9e7d98"

AUTHORITY_RELATIVE = (
    "sdk/qsdk_r10d_held_out_finite_decision_execution_authority_v2.json"
)
AUTHORITY_BYTES = 2_411
AUTHORITY_SHA256 = (
    "sha256:7c8b852a4f40b34b0a71857eff85ec485d77abf5f2fb5cd33ecc1ec4c36510f1"
)
AUTHORITY_BLOB = "133f9d5ac3cadd4ea1fe2de6f1b956283034df97"

DEVELOPMENT_CLOSURE_RELATIVE = (
    "sdk/qsdk_r10d_l1_development_route_ghost_physical_closure_v1.json"
)
DEVELOPMENT_CLOSURE_BYTES = 11_227
DEVELOPMENT_CLOSURE_SHA256 = (
    "sha256:dbbdeb257a260a64c730459880d8d4d66682ec94b65ec8f3beaeb4c38a3cdcc9"
)
DEVELOPMENT_CLOSURE_BLOB = "d1cad3ee2093a1cd0e35b51c8f61825fa2a02d1b"

REPORT_PATH = Path(
    r"C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
    r"\qsdk-r10d-held-out-finite-decision-physical-e6db6c23b5bf"
    r"\report.json"
)
REPORT_BYTES = 5_159
REPORT_SHA256 = (
    "sha256:549c73d857fd3e4a32b75c52eb42c7eeabab9593bf50422fecabc1612394825f"
)
EVIDENCE_ROOT = REPORT_PATH.parent
EVIDENCE_FILE_COUNT = 22
EVIDENCE_TOTAL_BYTES = 75_434_026

OUTPUT_RELATIVE = (
    "sdk/qsdk_r10d_l1_held_out_finite_decision_physical_closure_v1.json"
)
OUTPUT_PATH = ROOT / OUTPUT_RELATIVE
OUTPUT_SCHEMA = (
    "sporespore_qsdk_r10d_l1_held_out_finite_decision_physical_closure_v1"
)

EXPECTED_PREREQUISITE_KEYS = {
    "path",
    "byte_length",
    "raw_sha256",
    "git_blob_oid",
    "closure_audit_schema_version",
    "closure_audit_passed",
    "reconstructed_from_retained_evidence",
    "route_execution_valid",
    "behavior_passed",
    "physical_identity_consumed",
    "same_identity_rerun_permitted",
    "held_out_qualification_eligible",
    "qsdk_r10_satisfied",
    "sdk1_m07_satisfied",
}

SELF_TEST_MARKER = "QSDK_R10D_L1_C1_CLOSURE_COMPILER_SELF_TEST_PASS "
MATERIALIZED_MARKER = "QSDK_R10D_L1_C1_CLOSURE_MATERIALIZED "
AUDIT_MARKER = "QSDK_R10D_L1_C1_CLOSURE_AUDIT_PASS "
FAIL_MARKER = "QSDK_R10D_L1_C1_CLOSURE_COMPILER_FAIL "

_PREDECESSOR_VALIDATE_DEVELOPMENT_PREREQUISITE = (
    predecessor.validate_development_prerequisite
)


class CorrectionFailure(RuntimeError):
    """The closure-only compatibility correction is not exact."""


def require(condition: bool, code: str) -> None:
    if not condition:
        raise CorrectionFailure(code)


def sha256_bytes(raw: bytes) -> str:
    return "sha256:" + hashlib.sha256(raw).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return "sha256:" + digest.hexdigest()


def read_json(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise CorrectionFailure(f"{label}_UNREADABLE:{exc}") from exc
    require(isinstance(value, dict), f"{label}_NOT_OBJECT")
    return value


def git(arguments: Iterable[str], *, allow_empty: bool = False) -> str:
    result = subprocess.run(
        ("git", "-C", str(ROOT), *arguments),
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    require(result.returncode == 0, f"GIT_FAILED:{' '.join(arguments)}")
    value = result.stdout.strip()
    require(allow_empty or bool(value), f"GIT_EMPTY:{' '.join(arguments)}")
    return value


def changed_paths(commit: str) -> list[str]:
    return git(
        (
            "diff-tree",
            "--no-commit-id",
            "--name-only",
            "--no-renames",
            "-r",
            commit,
        )
    ).splitlines()


def repository_identity(*, require_clean_pushed: bool) -> dict[str, Any]:
    root = Path(git(("rev-parse", "--show-toplevel"))).resolve()
    remote = git(("remote", "get-url", "origin"))
    head = git(("rev-parse", "HEAD"))
    branch = git(("branch", "--show-current"))
    status = git(
        ("status", "--porcelain=v1", "--untracked-files=all"), allow_empty=True
    )
    origin = git(("rev-parse", "origin/main"))
    live = ""
    if require_clean_pushed:
        records = [
            line.split()
            for line in git(("ls-remote", "origin", "refs/heads/main")).splitlines()
            if line.strip()
        ]
        require(
            len(records) == 1
            and len(records[0]) == 2
            and records[0][1] == "refs/heads/main",
            "LIVE_MAIN_RECORD",
        )
        live = records[0][0]
    require(root == EXPECTED_ROOT.resolve(), "CANONICAL_ROOT")
    require(ROOT.resolve() == EXPECTED_ROOT.resolve(), "SCRIPT_ROOT")
    require(remote == EXPECTED_REMOTE, "REMOTE")
    require(branch == "main", "BRANCH")
    if require_clean_pushed:
        require(not status, "WORKTREE_NOT_CLEAN")
        require(head == origin == live, "MAIN_NOT_PUSHED_LIVE_EQUAL")
    return {
        "head": head,
        "branch": branch,
        "remote": remote,
        "clean": not status,
        "origin_main": origin,
        "live_main": live,
    }


def validate_file_identity(
    relative: str,
    *,
    byte_length: int,
    raw_sha256: str,
    git_blob_oid: str,
    identity_commit: str,
    current_head: str,
) -> None:
    path = ROOT / relative
    require(path.is_file() and predecessor.inside(path, ROOT), f"FILE_MISSING:{relative}")
    require(path.stat().st_size == byte_length, f"FILE_BYTES:{relative}")
    require(sha256_file(path) == raw_sha256, f"FILE_SHA256:{relative}")
    require(
        git(("rev-parse", f"{identity_commit}:{relative}"))
        == git_blob_oid
        == git(("rev-parse", f"{current_head}:{relative}")),
        f"FILE_GIT_BLOB:{relative}",
    )


def validate_design() -> dict[str, Any]:
    require(DESIGN_PATH.is_file(), "DESIGN_MISSING")
    require(DESIGN_PATH.stat().st_size == DESIGN_BYTES, "DESIGN_BYTES")
    require(sha256_file(DESIGN_PATH) == DESIGN_SHA256, "DESIGN_SHA256")
    design = read_json(DESIGN_PATH, "DESIGN")
    trigger = design.get("trigger")
    physical = design.get("consumed_physical_identity")
    diagnosis = design.get("causal_diagnosis")
    successor = design.get("selected_successor")
    qualification = design.get("qualification_contract")
    decision = design.get("decision")
    claims = design.get("claim_boundary")
    require(
        design.get("schema_version")
        == "sporespore_qsdk_r10d_l1_c1_held_out_closure_compiler_successor_design_v1"
        and design.get("status")
        == "prospective_zero_world_closure_only_successor_physics_blocked"
        and design.get("gate_id") == "QSDK-R10D"
        and design.get("repair_id") == CORRECTION_ID
        and design.get("parent_repair_id") == PARENT_REPAIR_ID
        and design.get("campaign_role") == CAMPAIGN_ROLE,
        "DESIGN_HEADER",
    )
    require(
        isinstance(trigger, dict)
        and trigger.get("observed_failure_code")
        == "DEVELOPMENT_PREREQUISITE_CONTRACT"
        and trigger.get("closure_output_created") is False,
        "DESIGN_TRIGGER",
    )
    require(
        isinstance(physical, dict)
        and physical.get("source_commit") == SOURCE_COMMIT
        and physical.get("stage_commit") == STAGE_COMMIT
        and physical.get("authorization_commit") == AUTHORIZATION_COMMIT
        and physical.get("report_raw_sha256") == REPORT_SHA256
        and physical.get("report_status") == "invalid_or_incomplete"
        and physical.get("world_attempt_count") == 4
        and physical.get("reported_world_build_count") is None
        and physical.get("confirmed_valid_world_build_count") == 3
        and physical.get("behavioral_conclusion_available") is False
        and physical.get("behavior_passed") is None
        and physical.get("physical_identity_consumed") is True
        and physical.get("same_identity_rerun_permitted") is False,
        "DESIGN_PHYSICAL_IDENTITY",
    )
    require(
        isinstance(diagnosis, dict)
        and diagnosis.get("stage_prerequisite_projection_contains_repair_id") is False
        and diagnosis.get("predecessor_validator_requires_stage_projection_repair_id")
        is True
        and diagnosis.get("development_closure_contains_repair_id") is True
        and diagnosis.get("development_closure_repair_id") == PARENT_REPAIR_ID
        and diagnosis.get("all_other_predecessor_prerequisite_predicates_pass")
        is True
        and diagnosis.get("failed_predicate_count") == 1
        and diagnosis.get("post_processing_contract_mismatch") is True,
        "DESIGN_DIAGNOSIS",
    )
    require(
        isinstance(successor, dict)
        and successor.get("path") == COMPILER_RELATIVE
        and successor.get("predecessor_compiler_edited") is False
        and successor.get("qualified_physical_source_paths_edited") is False
        and successor.get("stage_edited") is False
        and successor.get("execution_authority_edited") is False
        and successor.get("report_or_retained_evidence_edited") is False
        and successor.get("all_remaining_validation_delegated_to_qualified_predecessor")
        is True
        and successor.get("output_path") == OUTPUT_RELATIVE
        and successor.get("output_schema_version") == OUTPUT_SCHEMA
        and successor.get("output_semantics_changed") is False
        and successor.get("physical_rerun_permitted") is False,
        "DESIGN_SUCCESSOR",
    )
    require(
        isinstance(qualification, dict)
        and qualification.get("original_rejection_must_be_reproduced") is True
        and qualification.get("corrected_reconstruction_must_pass_from_retained_evidence")
        is True
        and qualification.get("predecessor_qualified_source_bindings_must_remain_exact")
        is True
        and qualification.get("model_construction_count") == 0
        and qualification.get("world_attempt_count") == 0
        and qualification.get("world_build_count") == 0
        and qualification.get("solver_step_count") == 0,
        "DESIGN_QUALIFICATION",
    )
    require(
        isinstance(decision, dict)
        and decision.get("selected_successor_id") == CORRECTION_ID
        and decision.get("closure_only_implementation_authorized") is True
        and decision.get("physical_execution_authorized") is False
        and decision.get("same_physical_identity_rerun_permitted") is False
        and decision.get("new_physical_identity_authorized") is False
        and decision.get("threshold_change_applied") is False
        and decision.get("population_change_applied") is False
        and decision.get("controller_change_applied") is False
        and decision.get("outcome_reclassification_applied") is False
        and decision.get("qsdk_r10_satisfied") is False
        and decision.get("sdk1_m07_satisfied") is False,
        "DESIGN_DECISION",
    )
    require(
        isinstance(claims, dict)
        and claims.get("complete_held_out_finite_decision_claimed") is False
        and claims.get("bounded_upright_push_recovery_claimed") is False
        and claims.get("physical_acceptance_authority") is False
        and claims.get("release_authority") is False,
        "DESIGN_CLAIMS",
    )
    return design


def validate_static_identities(current_head: str) -> None:
    validate_file_identity(
        PREDECESSOR_RELATIVE,
        byte_length=PREDECESSOR_BYTES,
        raw_sha256=PREDECESSOR_SHA256,
        git_blob_oid=PREDECESSOR_BLOB,
        identity_commit=SOURCE_COMMIT,
        current_head=current_head,
    )
    validate_file_identity(
        AUTHORITY_MATERIALIZER_RELATIVE,
        byte_length=AUTHORITY_MATERIALIZER_BYTES,
        raw_sha256=AUTHORITY_MATERIALIZER_SHA256,
        git_blob_oid=AUTHORITY_MATERIALIZER_BLOB,
        identity_commit=SOURCE_COMMIT,
        current_head=current_head,
    )
    validate_file_identity(
        STAGE_RELATIVE,
        byte_length=STAGE_BYTES,
        raw_sha256=STAGE_SHA256,
        git_blob_oid=STAGE_BLOB,
        identity_commit=STAGE_COMMIT,
        current_head=current_head,
    )
    validate_file_identity(
        AUTHORITY_RELATIVE,
        byte_length=AUTHORITY_BYTES,
        raw_sha256=AUTHORITY_SHA256,
        git_blob_oid=AUTHORITY_BLOB,
        identity_commit=AUTHORIZATION_COMMIT,
        current_head=current_head,
    )
    validate_file_identity(
        DEVELOPMENT_CLOSURE_RELATIVE,
        byte_length=DEVELOPMENT_CLOSURE_BYTES,
        raw_sha256=DEVELOPMENT_CLOSURE_SHA256,
        git_blob_oid=DEVELOPMENT_CLOSURE_BLOB,
        identity_commit=SOURCE_COMMIT,
        current_head=current_head,
    )
    require(REPORT_PATH.is_file(), "REPORT_MISSING")
    require(REPORT_PATH.stat().st_size == REPORT_BYTES, "REPORT_BYTES")
    require(sha256_file(REPORT_PATH) == REPORT_SHA256, "REPORT_SHA256")
    evidence_files = sorted(path for path in EVIDENCE_ROOT.rglob("*") if path.is_file())
    require(len(evidence_files) == EVIDENCE_FILE_COUNT, "EVIDENCE_FILE_COUNT")
    require(
        sum(path.stat().st_size for path in evidence_files) == EVIDENCE_TOTAL_BYTES,
        "EVIDENCE_TOTAL_BYTES",
    )


def validate_projection_contract(
    stage: dict[str, Any], graph: dict[str, str], current_head: str
) -> tuple[dict[str, Any], dict[str, Any]]:
    prerequisite = stage.get("prerequisite_development_route_ghost")
    require(isinstance(prerequisite, dict), "DEVELOPMENT_PREREQUISITE_NOT_OBJECT")
    require(
        set(prerequisite) == EXPECTED_PREREQUISITE_KEYS,
        "DEVELOPMENT_PREREQUISITE_FIELDS",
    )
    require("repair_id" not in prerequisite, "REDUNDANT_REPAIR_ID_PRESENT")
    path = ROOT / DEVELOPMENT_CLOSURE_RELATIVE
    require(
        prerequisite.get("path") == DEVELOPMENT_CLOSURE_RELATIVE
        and path.is_file()
        and predecessor.inside(path, ROOT)
        and prerequisite.get("byte_length") == path.stat().st_size
        and prerequisite.get("raw_sha256") == predecessor.sha256_file(path)
        and prerequisite.get("git_blob_oid")
        == predecessor.git(
            (
                "rev-parse",
                f"{graph['source_commit']}:{DEVELOPMENT_CLOSURE_RELATIVE}",
            )
        )
        == predecessor.git(
            ("rev-parse", f"{current_head}:{DEVELOPMENT_CLOSURE_RELATIVE}")
        )
        and prerequisite.get("closure_audit_schema_version")
        == "sporespore_qsdk_r10d_physical_closure_audit_v1"
        and prerequisite.get("closure_audit_passed") is True
        and prerequisite.get("reconstructed_from_retained_evidence") is True
        and prerequisite.get("route_execution_valid") is True
        and type(prerequisite.get("behavior_passed")) is bool
        and prerequisite.get("physical_identity_consumed") is True
        and prerequisite.get("same_identity_rerun_permitted") is False
        and prerequisite.get("held_out_qualification_eligible") is True
        and prerequisite.get("qsdk_r10_satisfied") is False
        and prerequisite.get("sdk1_m07_satisfied") is False,
        "DEVELOPMENT_PREREQUISITE_CONTRACT_CORRECTED",
    )
    closure = predecessor.read_json(path, "DEVELOPMENT_ROUTE_CLOSURE")
    require(
        closure.get("schema_version")
        == "sporespore_qsdk_r10d_l1_development_route_ghost_physical_closure_v1"
        and closure.get("gate_id") == "QSDK-R10D"
        and closure.get("repair_id") == PARENT_REPAIR_ID
        and closure.get("campaign_role") == "development_route_ghost"
        and closure.get("route_execution_valid") is True
        and closure.get("behavior_passed")
        is prerequisite.get("behavior_passed")
        and closure.get("physical_identity_consumed") is True
        and closure.get("same_identity_rerun_permitted") is False,
        "DEVELOPMENT_CLOSURE_REPAIR_ID_AUTHORITY",
    )
    return prerequisite, closure


def corrected_validate_development_prerequisite(
    stage: dict[str, Any],
    role: str,
    graph: dict[str, str],
    current_head: str,
) -> dict[str, Any] | None:
    if role == "development_route_ghost":
        return _PREDECESSOR_VALIDATE_DEVELOPMENT_PREREQUISITE(
            stage, role, graph, current_head
        )
    require(role == CAMPAIGN_ROLE, "CAMPAIGN_ROLE")
    prerequisite, _closure = validate_projection_contract(stage, graph, current_head)
    audit_receipt = reaudited_development_closure(current_head)
    require(
        audit_receipt.get("closure_path") == DEVELOPMENT_CLOSURE_RELATIVE
        and audit_receipt.get("repair_id") == PARENT_REPAIR_ID
        and audit_receipt.get("closure_byte_length")
        == prerequisite.get("byte_length")
        and audit_receipt.get("closure_raw_sha256")
        == prerequisite.get("raw_sha256")
        and audit_receipt.get("closure_git_blob_oid")
        == prerequisite.get("git_blob_oid")
        and audit_receipt.get("route_execution_valid") is True
        and audit_receipt.get("behavior_passed")
        is prerequisite.get("behavior_passed")
        and audit_receipt.get("physical_identity_consumed") is True
        and audit_receipt.get("same_identity_rerun_permitted") is False
        and audit_receipt.get("held_out_qualification_eligible") is True
        and audit_receipt.get("qsdk_r10_satisfied") is False
        and audit_receipt.get("sdk1_m07_satisfied") is False
        and audit_receipt.get("reconstructed_from_retained_evidence") is True
        and audit_receipt.get("world_attempt_count") == 0
        and audit_receipt.get("world_build_count") == 0
        and audit_receipt.get("solver_step_count") == 0,
        "DEVELOPMENT_PREREQUISITE_REAUDIT",
    )
    return {
        "closure": predecessor.repository_file_identity(
            DEVELOPMENT_CLOSURE_RELATIVE
        ),
        "closure_audit": audit_receipt,
    }


def reaudited_development_closure(current_head: str) -> dict[str, Any]:
    path = ROOT / DEVELOPMENT_CLOSURE_RELATIVE
    closure = predecessor.read_json(path, "DEVELOPMENT_ROUTE_CLOSURE")
    evidence = closure.get("evidence")
    require(isinstance(evidence, dict), "DEVELOPMENT_CLOSURE_EVIDENCE")
    report_binding = evidence.get("report")
    require(
        isinstance(report_binding, dict),
        "DEVELOPMENT_CLOSURE_REPORT_BINDING",
    )
    report_path = Path(str(report_binding.get("path", ""))).resolve()
    require(
        predecessor.absolute_file_identity(report_path) == report_binding,
        "DEVELOPMENT_CLOSURE_REPORT_DRIFT",
    )
    validated = predecessor.validate_report(
        report_path, "development_route_ghost", current_head
    )
    require(
        closure == predecessor.build_closure(validated),
        "DEVELOPMENT_CLOSURE_DOCUMENT_DRIFT",
    )
    decision = closure.get("decision")
    require(isinstance(decision, dict), "DEVELOPMENT_CLOSURE_DECISION")
    return {
        "schema_version": "sporespore_qsdk_r10d_physical_closure_audit_v1",
        "gate_id": "QSDK-R10D",
        "repair_id": PARENT_REPAIR_ID,
        "ok": True,
        "campaign_role": "development_route_ghost",
        "closure_path": DEVELOPMENT_CLOSURE_RELATIVE,
        "closure_byte_length": path.stat().st_size,
        "closure_raw_sha256": predecessor.sha256_file(path),
        "closure_git_blob_oid": predecessor.git(
            ("rev-parse", f"{current_head}:{DEVELOPMENT_CLOSURE_RELATIVE}")
        ),
        "closure_status": closure["status"],
        "closure_result": decision["result"],
        "route_execution_valid": closure["route_execution_valid"],
        "behavior_passed": closure["behavior_passed"],
        "physical_identity_consumed": True,
        "same_identity_rerun_permitted": False,
        "held_out_qualification_eligible": decision[
            "held_out_qualification_eligible"
        ],
        "qsdk_r10_satisfied": decision["qsdk_r10_satisfied"],
        "sdk1_m07_satisfied": decision["sdk1_m07_satisfied"],
        "reconstructed_from_retained_evidence": True,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "native_readback_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def reproduce_predecessor_rejection(current_head: str) -> None:
    stage = predecessor.read_json(ROOT / STAGE_RELATIVE, "STAGE_FREEZE")
    graph = {"source_commit": SOURCE_COMMIT}
    try:
        _PREDECESSOR_VALIDATE_DEVELOPMENT_PREREQUISITE(
            stage, CAMPAIGN_ROLE, graph, current_head
        )
    except predecessor.ClosureFailure as exc:
        require(
            str(exc) == "DEVELOPMENT_PREREQUISITE_CONTRACT",
            f"PREDECESSOR_REJECTION_CHANGED:{exc}",
        )
    else:
        raise CorrectionFailure("PREDECESSOR_REJECTION_NOT_REPRODUCED")


def projection_mutation_controls(current_head: str) -> int:
    stage = predecessor.read_json(ROOT / STAGE_RELATIVE, "STAGE_FREEZE")
    graph = {"source_commit": SOURCE_COMMIT}
    validate_projection_contract(stage, graph, current_head)
    mutations: list[tuple[str, Any]] = [
        ("add_repair_id", lambda value: value.__setitem__("repair_id", PARENT_REPAIR_ID)),
        ("remove_path", lambda value: value.pop("path")),
        ("fractional_bytes", lambda value: value.__setitem__("byte_length", 11227.5)),
        ("behavior_not_boolean", lambda value: value.__setitem__("behavior_passed", "false")),
        ("route_not_valid", lambda value: value.__setitem__("route_execution_valid", False)),
        ("rerun_enabled", lambda value: value.__setitem__("same_identity_rerun_permitted", True)),
    ]
    rejected = 0
    for label, mutate in mutations:
        candidate = copy.deepcopy(stage)
        projection = candidate["prerequisite_development_route_ghost"]
        mutate(projection)
        try:
            validate_projection_contract(candidate, graph, current_head)
        except CorrectionFailure:
            rejected += 1
        else:
            raise CorrectionFailure(f"PROJECTION_MUTATION_ACCEPTED:{label}")
    return rejected


def validate_corrected_report(
    report_path: Path, *, require_clean_pushed: bool
) -> tuple[dict[str, Any], dict[str, Any]]:
    identity = repository_identity(require_clean_pushed=require_clean_pushed)
    require(report_path.resolve() == REPORT_PATH.resolve(), "REPORT_PATH")
    validate_design()
    validate_static_identities(identity["head"])
    reproduce_predecessor_rejection(identity["head"])
    previous = predecessor.validate_development_prerequisite
    predecessor.validate_development_prerequisite = (
        corrected_validate_development_prerequisite
    )
    try:
        validated = predecessor.validate_report(
            report_path, CAMPAIGN_ROLE, identity["head"]
        )
    finally:
        predecessor.validate_development_prerequisite = previous
    report = validated["report"]
    require(validated["route_execution_valid"] is False, "ROUTE_MUST_REMAIN_INVALID")
    require(validated["behavior_passed"] is None, "BEHAVIOR_MUST_REMAIN_NULL")
    require(validated["invalid_or_incomplete"] is True, "INVALID_STATUS")
    require(report.get("world_attempt_count") == 4, "WORLD_ATTEMPT_COUNT")
    require(
        report.get("confirmed_valid_world_build_count") == 3,
        "CONFIRMED_VALID_WORLD_COUNT",
    )
    require(report.get("behavioral_conclusion_available") is False, "BEHAVIOR_AUTHORITY")
    require(report.get("same_identity_rerun_permitted") is False, "RERUN_BOUNDARY")
    return validated, identity


def zero_world_fields() -> dict[str, Any]:
    return {
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "native_readback_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def compiler_commit_identity(expected_head: str) -> str:
    compiler_commit = git(("log", "-1", "--format=%H", "--", COMPILER_RELATIVE))
    design_commit = git(("log", "-1", "--format=%H", "--", DESIGN_RELATIVE))
    require(compiler_commit == design_commit, "COMPILER_DESIGN_COMMIT_SPLIT")
    require(
        sorted(changed_paths(compiler_commit))
        == sorted([COMPILER_RELATIVE, DESIGN_RELATIVE]),
        "COMPILER_COMMIT_SCOPE",
    )
    require(
        git(("rev-parse", f"{expected_head}:{DESIGN_RELATIVE}"))
        == git(("rev-parse", f"{compiler_commit}:{DESIGN_RELATIVE}"))
        and git(("rev-parse", f"{expected_head}:{COMPILER_RELATIVE}"))
        == git(("rev-parse", f"{compiler_commit}:{COMPILER_RELATIVE}")),
        "COMPILER_COMMIT_DRIFT",
    )
    return compiler_commit


def expected_closure(validated: dict[str, Any]) -> dict[str, Any]:
    closure = predecessor.build_closure(validated)
    decision = closure.get("decision")
    outcome = closure.get("outcome")
    claims = closure.get("claim_boundary")
    require(
        closure.get("schema_version") == OUTPUT_SCHEMA
        and closure.get("status")
        == "closed_consumed_invalid_or_incomplete_no_finite_decision"
        and closure.get("repair_id") == PARENT_REPAIR_ID
        and closure.get("campaign_role") == CAMPAIGN_ROLE
        and closure.get("route_execution_valid") is False
        and closure.get("behavior_passed") is None
        and closure.get("evidence_valid") is False
        and closure.get("outcome_complete") is False
        and closure.get("behavioral_conclusion_available") is False
        and closure.get("physical_identity_consumed") is True
        and closure.get("same_identity_rerun_permitted") is False,
        "CLOSURE_CLASSIFICATION",
    )
    require(
        isinstance(outcome, dict)
        and outcome.get("world_attempt_count") == 4
        and outcome.get("world_build_count") is None
        and outcome.get("world_build_count_known") is False
        and outcome.get("confirmed_valid_world_build_count") == 3
        and outcome.get("pair_count") == 1
        and outcome.get("behavioral_conclusion_available") is False
        and outcome.get("behavior_passed") is None,
        "CLOSURE_OUTCOME",
    )
    require(
        isinstance(decision, dict)
        and decision.get("result")
        == "held_out_invalid_or_incomplete_no_behavioral_conclusion"
        and decision.get("qsdk_r10_satisfied") is False
        and decision.get("sdk1_m07_satisfied") is False
        and decision.get("held_out_qualification_eligible") is False
        and decision.get("same_identity_rerun_permitted") is False
        and decision.get("new_physical_work_authorized") is False
        and decision.get("next_legal_work")
        == "zero_world_retained_evidence_diagnosis_and_new_successor_identity_only",
        "CLOSURE_DECISION",
    )
    require(
        isinstance(claims, dict)
        and claims.get("genuine_godot_jolt_world_count_claimed") is None
        and claims.get("genuine_godot_jolt_world_count_known") is False
        and claims.get("confirmed_valid_godot_jolt_world_count_claimed") == 3
        and claims.get("bounded_upright_push_recovery_claimed") is False
        and claims.get("physical_acceptance_authority") is False
        and claims.get("release_authority") is False,
        "CLOSURE_CLAIMS",
    )
    return closure


def self_test(report_path: Path) -> dict[str, Any]:
    validated, identity = validate_corrected_report(
        report_path, require_clean_pushed=False
    )
    predecessor_receipt = predecessor.self_test()
    require(predecessor_receipt.get("ok") is True, "PREDECESSOR_SELF_TEST")
    mutation_count = projection_mutation_controls(identity["head"])
    closure = expected_closure(validated)
    return {
        "schema_version": (
            "sporespore_qsdk_r10d_l1_c1_held_out_closure_compiler_self_test_v1"
        ),
        "ok": True,
        "gate_id": "QSDK-R10D",
        "repair_id": CORRECTION_ID,
        "parent_repair_id": PARENT_REPAIR_ID,
        "predecessor_rejection_reproduced": True,
        "predecessor_failure_code": "DEVELOPMENT_PREREQUISITE_CONTRACT",
        "projection_mutation_rejection_count": mutation_count,
        "corrected_reconstruction_passed": True,
        "retained_evidence_file_count": validated["retained_evidence_tree"][
            "file_count"
        ],
        "retained_evidence_total_byte_length": validated[
            "retained_evidence_tree"
        ]["total_byte_length"],
        "confirmed_valid_world_build_count": closure["outcome"][
            "confirmed_valid_world_build_count"
        ],
        "behavioral_conclusion_available": False,
        "same_identity_rerun_permitted": False,
        **zero_world_fields(),
    }


def materialize(report_path: Path) -> dict[str, Any]:
    require(not OUTPUT_PATH.exists(), "CLOSURE_ALREADY_EXISTS")
    validated, identity = validate_corrected_report(
        report_path, require_clean_pushed=True
    )
    compiler_commit = compiler_commit_identity(identity["head"])
    require(identity["head"] == compiler_commit, "MATERIALIZE_NOT_AT_COMPILER_COMMIT")
    closure = expected_closure(validated)
    predecessor.write_new_json(OUTPUT_PATH, closure)
    output = predecessor.repository_file_identity(OUTPUT_RELATIVE)
    return {
        "schema_version": (
            "sporespore_qsdk_r10d_l1_c1_held_out_closure_materialization_v1"
        ),
        "ok": True,
        "gate_id": "QSDK-R10D",
        "repair_id": CORRECTION_ID,
        "parent_repair_id": PARENT_REPAIR_ID,
        "compiler_commit": compiler_commit,
        "design_raw_sha256": DESIGN_SHA256,
        "predecessor_rejection_reproduced": True,
        "output_identity": output,
        "closure_status": closure["status"],
        "closure_result": closure["decision"]["result"],
        "route_execution_valid": False,
        "behavior_passed": None,
        "physical_identity_consumed": True,
        "same_identity_rerun_permitted": False,
        **zero_world_fields(),
    }


def audit(report_path: Path) -> dict[str, Any]:
    validated, identity = validate_corrected_report(
        report_path, require_clean_pushed=True
    )
    require(OUTPUT_PATH.is_file(), "CLOSURE_MISSING")
    actual = read_json(OUTPUT_PATH, "CLOSURE")
    expected = expected_closure(validated)
    require(actual == expected, "CLOSURE_DOCUMENT_DRIFT")
    closure_commit = git(("log", "-1", "--format=%H", "--", OUTPUT_RELATIVE))
    compiler_commit = compiler_commit_identity(identity["head"])
    require(
        git(("rev-parse", f"{closure_commit}^")) == compiler_commit,
        "CLOSURE_PARENT_NOT_COMPILER",
    )
    require(changed_paths(closure_commit) == [OUTPUT_RELATIVE], "CLOSURE_COMMIT_SCOPE")
    require(
        git(("rev-parse", f"{closure_commit}:{OUTPUT_RELATIVE}"))
        == git(("rev-parse", f"{identity['head']}:{OUTPUT_RELATIVE}")),
        "CLOSURE_GIT_BLOB_DRIFT",
    )
    output = predecessor.repository_file_identity(OUTPUT_RELATIVE)
    return {
        "schema_version": (
            "sporespore_qsdk_r10d_l1_c1_held_out_closure_audit_v1"
        ),
        "ok": True,
        "gate_id": "QSDK-R10D",
        "repair_id": CORRECTION_ID,
        "parent_repair_id": PARENT_REPAIR_ID,
        "compiler_commit": compiler_commit,
        "closure_commit": closure_commit,
        "closure_path": OUTPUT_RELATIVE,
        "closure_byte_length": output["byte_length"],
        "closure_raw_sha256": output["raw_sha256"],
        "closure_git_blob_oid": output["git_blob_oid"],
        "closure_status": actual["status"],
        "closure_result": actual["decision"]["result"],
        "predecessor_rejection_reproduced": True,
        "corrected_reconstruction_passed": True,
        "reconstructed_from_retained_evidence": True,
        "retained_evidence_file_count": actual["evidence"][
            "retained_evidence_tree"
        ]["file_count"],
        "retained_evidence_total_byte_length": actual["evidence"][
            "retained_evidence_tree"
        ]["total_byte_length"],
        "confirmed_valid_world_build_count": actual["outcome"][
            "confirmed_valid_world_build_count"
        ],
        "route_execution_valid": False,
        "behavior_passed": None,
        "behavioral_conclusion_available": False,
        "physical_identity_consumed": True,
        "same_identity_rerun_permitted": False,
        "qsdk_r10_satisfied": False,
        "sdk1_m07_satisfied": False,
        **zero_world_fields(),
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Close the consumed QSDK-R10D-L1 held-out identity without worlds "
            "after its qualified compiler required a non-schema projection field."
        )
    )
    parser.add_argument("mode", choices=("self-test", "materialize", "audit"))
    parser.add_argument("--report", default=str(REPORT_PATH))
    arguments = parser.parse_args()
    try:
        report_path = Path(arguments.report).resolve()
        if arguments.mode == "self-test":
            marker = SELF_TEST_MARKER
            receipt = self_test(report_path)
        elif arguments.mode == "materialize":
            marker = MATERIALIZED_MARKER
            receipt = materialize(report_path)
        else:
            marker = AUDIT_MARKER
            receipt = audit(report_path)
        print(marker + json.dumps(receipt, separators=(",", ":"), sort_keys=True))
        return 0
    except (CorrectionFailure, predecessor.ClosureFailure) as exc:
        print(FAIL_MARKER + str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
