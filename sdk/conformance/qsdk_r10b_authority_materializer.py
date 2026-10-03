#!/usr/bin/env python3
"""Materialize QSDK-R10B stage freezes and parent-bound execution authorities."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
from typing import Any, Iterable


ROOT = Path(__file__).resolve().parents[2]
EXPECTED_ROOT = Path(r"C:\Users\Cole\CodeStuff\games\SporeSpore")
EXPECTED_REMOTE = "https://github.com/Slagathore/sporespore.git"
EVIDENCE_ROOT = Path(r"C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence")
MANIFEST_PATH = ROOT / "sdk/qsdk_r10b_dependency_manifest_v4.json"
DESIGN_PATH = (
    ROOT / "sdk/qsdk_r10a_bounded_upright_push_recovery_successor_design_v1.json"
)
L2_DESIGN_PATH = (
    ROOT / "sdk/qsdk_r10b_l2_exact_quaternion_projection_successor_design_v1.json"
)
L3_DESIGN_PATH = (
    ROOT
    / "sdk/qsdk_r10b_l3_serialization_stable_trace_validation_successor_design_v1.json"
)
AUTHORITY_CHECK_REFUSAL_PATH = (
    ROOT / "sdk/qsdk_r10b_development_route_ghost_authority_check_refusal_v1.json"
)
L1_PHYSICAL_INVALID_CLOSURE_PATH = (
    ROOT / "sdk/qsdk_r10b_l1_development_route_ghost_physical_invalid_closure_v1.json"
)
L2_PHYSICAL_INVALID_CLOSURE_PATH = (
    ROOT / "sdk/qsdk_r10b_l2_development_route_ghost_physical_invalid_closure_v1.json"
)
EXPECTED_DESIGN_SHA256 = (
    "sha256:f5738803e65d25b3225c0b054ced5f21613650f2a5aa1d79e76b700ad7d36f66"
)
EXPECTED_L2_DESIGN_BYTES = 10_199
EXPECTED_L2_DESIGN_SHA256 = (
    "sha256:5acc66edbc274616898b25ede236207ff77ca92e596ffbf171472ca9dfc7a478"
)
EXPECTED_L3_DESIGN_BYTES = 12_654
EXPECTED_L3_DESIGN_SHA256 = (
    "sha256:ad8d147ee5a508aee3104fb346dcedde692568a9f9093a73e3bdbca638901f76"
)
EXPECTED_AUTHORITY_CHECK_REFUSAL_BYTES = 4668
EXPECTED_AUTHORITY_CHECK_REFUSAL_SHA256 = (
    "sha256:0196bdbcb8f914421edab305ca37e637708f8e35d5320f5c41fed827bfa9e230"
)
EXPECTED_L1_PHYSICAL_INVALID_CLOSURE_BYTES = 16_922
EXPECTED_L1_PHYSICAL_INVALID_CLOSURE_SHA256 = (
    "sha256:b9f8304e229d1a897137bafcce51ee6089b11b15742f624ccf38d202b8fe35a1"
)
EXPECTED_L2_PHYSICAL_INVALID_CLOSURE_BYTES = 20_839
EXPECTED_L2_PHYSICAL_INVALID_CLOSURE_SHA256 = (
    "sha256:5f6242e2cab9658a54c673717596c7649fac785136d29d8798192bfc0f60babb"
)
EXPECTED_SOURCE_COUNT = 85
EXPECTED_SOURCE_PATH_SHA256 = (
    "sha256:4bfe0e8a7cbdb920655cb3082b6e2a7182f4f05ac76e24142a73acca640a7a8d"
)
REFUSED_SOURCE_COUNT = 69
REFUSED_SOURCE_PATH_SHA256 = (
    "sha256:1d6152156a40d5fbd6d86c28f0cbbddfa2d48c02aa1f43ad326851d432c655d7"
)
QUALIFICATION_PASS_MARKER = "QSDK_R10B_ZERO_WORLD_IMPLEMENTATION_PASS "
SELF_TEST_MARKER = "QSDK_R10B_AUTHORITY_MATERIALIZER_SELF_TEST_PASS "
MATERIALIZED_MARKER = "QSDK_R10B_AUTHORITY_MATERIALIZED "

ROLE_SPECS: dict[str, dict[str, Any]] = {
    "development_route_ghost": {
        "campaign_id": "QSDK-R10B-BOUNDED-UPRIGHT-PUSH-RECOVERY-ROUTE-GHOST",
        "question_class": "development",
        "ordered_cell_ids": ["baseline_s50300", "push_s50300"],
        "maximum_world_count": 2,
        "stage_freeze_path": (
            "sdk/qsdk_r10b_development_route_ghost_"
            "zero_world_qualification_closure_v4.json"
        ),
        "authority_path": (
            "sdk/qsdk_r10b_development_route_ghost_execution_authority_v4.json"
        ),
        "physical_output_slug": "development-route-ghost",
    },
    "held_out_finite_decision": {
        "campaign_id": "QSDK-R10B-BOUNDED-UPRIGHT-PUSH-RECOVERY-VALIDATION",
        "question_class": "finite decision",
        "ordered_cell_ids": [
            "baseline_s50301",
            "push_s50301",
            "baseline_s50302",
            "push_s50302",
            "baseline_s50303",
            "push_s50303",
        ],
        "maximum_world_count": 6,
        "stage_freeze_path": (
            "sdk/qsdk_r10b_held_out_finite_decision_"
            "zero_world_qualification_closure_v4.json"
        ),
        "authority_path": (
            "sdk/qsdk_r10b_held_out_finite_decision_execution_authority_v4.json"
        ),
        "physical_output_slug": "held-out-finite-decision",
    },
}


class MaterializationFailure(RuntimeError):
    """A prospective authority boundary was not exact."""


def require(condition: bool, code: str) -> None:
    if not condition:
        raise MaterializationFailure(code)


def canonical_bytes(value: Any) -> bytes:
    return json.dumps(
        value, ensure_ascii=False, separators=(",", ":"), sort_keys=True
    ).encode("utf-8")


def sha256_bytes(value: bytes) -> str:
    return "sha256:" + hashlib.sha256(value).hexdigest()


def file_identity(path: Path, *, relative_to: Path | None = None) -> dict[str, Any]:
    raw = path.read_bytes()
    path_value = (
        path.as_posix()
        if relative_to is None
        else path.relative_to(relative_to).as_posix()
    )
    return {
        "path": path_value,
        "byte_length": len(raw),
        "raw_sha256": sha256_bytes(raw),
    }


def read_json(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise MaterializationFailure(f"{label}_INVALID_JSON:{exc}") from exc
    require(isinstance(value, dict), f"{label}_ROOT_NOT_OBJECT")
    return value


def git(arguments: Iterable[str], *, text: bool = True) -> str | bytes:
    completed = subprocess.run(
        ("git", "-C", ROOT, *arguments),
        check=False,
        capture_output=True,
        text=text,
        encoding="utf-8" if text else None,
        errors="strict" if text else None,
    )
    require(completed.returncode == 0, f"GIT_FAILED:{' '.join(arguments)}")
    return completed.stdout.strip() if text else completed.stdout


def live_source_identity() -> dict[str, Any]:
    root = Path(str(git(("rev-parse", "--show-toplevel")))).resolve()
    remote = str(git(("remote", "get-url", "origin")))
    branch = str(git(("branch", "--show-current")))
    commit = str(git(("rev-parse", "HEAD")))
    parent = str(git(("rev-parse", "HEAD^")))
    tree = str(git(("rev-parse", "HEAD^{tree}")))
    origin = str(git(("rev-parse", "origin/main")))
    status = str(git(("status", "--porcelain=v1", "--untracked-files=all")))
    live_fields = str(git(("ls-remote", "origin", "refs/heads/main"))).split()
    require(root == EXPECTED_ROOT.resolve() == ROOT.resolve(), "WRONG_REPOSITORY_ROOT")
    require(remote == EXPECTED_REMOTE, "WRONG_REPOSITORY_REMOTE")
    require(branch == "main", "WRONG_BRANCH")
    require(not status, "WORKTREE_NOT_CLEAN")
    require(commit == origin, "HEAD_NOT_EQUAL_ORIGIN_MAIN")
    require(live_fields == [commit, "refs/heads/main"], "HEAD_NOT_EQUAL_LIVE_MAIN")
    return {
        "commit": commit,
        "parent_commit": parent,
        "tree": tree,
        "branch": branch,
        "remote": remote,
        "origin_main_commit": origin,
        "live_main_commit": live_fields[0],
        "clean": True,
    }


def source_inventory() -> tuple[list[str], str]:
    manifest = read_json(MANIFEST_PATH, "DEPENDENCY_MANIFEST")
    policy = manifest.get("policy")
    require(isinstance(policy, dict), "DEPENDENCY_POLICY_MISSING")
    paths = sorted(
        set(
            [
                str(value)
                for value in policy.get("expected_gdscript_transitive_paths", [])
            ]
            + [str(value) for value in policy.get("rust_build_paths", [])]
            + [str(value) for value in policy.get("process_and_audit_paths", [])]
        )
    )
    digest = sha256_bytes("\n".join(paths).encode("utf-8"))
    require(len(paths) == EXPECTED_SOURCE_COUNT, "SOURCE_COUNT_DRIFT")
    require(digest == EXPECTED_SOURCE_PATH_SHA256, "SOURCE_PATH_DIGEST_DRIFT")
    require(
        policy.get("expected_qualified_source_count") == len(paths),
        "MANIFEST_COUNT_DRIFT",
    )
    require(
        policy.get("expected_qualified_source_path_sha256") == digest,
        "MANIFEST_PATH_DIGEST_DRIFT",
    )
    return paths, digest


def source_bindings(source_commit: str, current_commit: str) -> list[dict[str, Any]]:
    paths, _ = source_inventory()
    bindings: list[dict[str, Any]] = []
    for relative in paths:
        source_raw = bytes(git(("show", f"{source_commit}:{relative}"), text=False))
        current_raw = bytes(git(("show", f"{current_commit}:{relative}"), text=False))
        source_blob = str(git(("rev-parse", f"{source_commit}:{relative}")))
        current_blob = str(git(("rev-parse", f"{current_commit}:{relative}")))
        checkout_raw = (ROOT / relative).read_bytes()
        require(source_blob == current_blob, f"QUALIFIED_SOURCE_BLOB_DRIFT:{relative}")
        require(
            source_raw == current_raw == checkout_raw,
            f"QUALIFIED_SOURCE_BYTE_DRIFT:{relative}",
        )
        bindings.append(
            {
                "path": relative,
                "byte_length": len(source_raw),
                "raw_sha256": sha256_bytes(source_raw),
                "git_blob_oid": source_blob,
            }
        )
    return bindings


def validate_authority_check_refusal_document() -> dict[str, Any]:
    require(AUTHORITY_CHECK_REFUSAL_PATH.is_file(), "AUTHORITY_CHECK_REFUSAL_MISSING")
    raw = AUTHORITY_CHECK_REFUSAL_PATH.read_bytes()
    require(
        len(raw) == EXPECTED_AUTHORITY_CHECK_REFUSAL_BYTES,
        "AUTHORITY_CHECK_REFUSAL_BYTES",
    )
    require(
        sha256_bytes(raw) == EXPECTED_AUTHORITY_CHECK_REFUSAL_SHA256,
        "AUTHORITY_CHECK_REFUSAL_DIGEST",
    )
    refusal = read_json(AUTHORITY_CHECK_REFUSAL_PATH, "AUTHORITY_CHECK_REFUSAL")
    require(
        refusal.get("schema_version")
        == "sporespore_qsdk_r10b_authority_check_refusal_v1",
        "AUTHORITY_CHECK_REFUSAL_SCHEMA",
    )
    require(
        refusal.get("status") == "closed_infrastructure_invalid_pre_physics"
        and refusal.get("gate_id") == "QSDK-R10B"
        and refusal.get("repair_id") == "QSDK-R10B-L1"
        and refusal.get("campaign_role") == "development_route_ghost",
        "AUTHORITY_CHECK_REFUSAL_IDENTITY",
    )
    source = refusal.get("source")
    require(
        isinstance(source, dict)
        and source.get("source_commit") == "5f7ab1da5fc78c4bd26de320a07e519367fe3fc1"
        and source.get("qualification_commit")
        == "959bf78fa59fa9d34f30c13933cd62e2e921bf45"
        and source.get("authorization_commit")
        == "881dc1f1001bc9f7a2b19cdba60d9a96477b713d",
        "AUTHORITY_CHECK_REFUSAL_SOURCE",
    )
    diagnosis = refusal.get("diagnosis")
    require(
        isinstance(diagnosis, dict)
        and diagnosis.get("failure_predicate")
        == "qualified_source_bindings_ordinal_order_check"
        and diagnosis.get("materialized_binding_count") == REFUSED_SOURCE_COUNT
        and diagnosis.get("materialized_path_digest") == REFUSED_SOURCE_PATH_SHA256
        and diagnosis.get("materialized_path_digest_matched") is True
        and diagnosis.get("all_source_blobs_matched") is True
        and diagnosis.get("all_worktree_byte_lengths_matched") is True
        and diagnosis.get("all_worktree_raw_sha256_values_matched") is True,
        "AUTHORITY_CHECK_REFUSAL_DIAGNOSIS",
    )
    boundary = refusal.get("execution_boundary")
    require(
        isinstance(boundary, dict)
        and boundary.get("operation_lock_acquisition_count") == 0
        and boundary.get("durable_evidence_directory_created") is False
        and boundary.get("model_construction_count") == 0
        and boundary.get("world_attempt_count") == 0
        and boundary.get("world_build_count") == 0
        and boundary.get("scene_tree_insertion_count") == 0
        and boundary.get("native_readback_count") == 0
        and boundary.get("solver_step_count") == 0
        and boundary.get("locomotion_outcome_exposure_count") == 0
        and boundary.get("physics_state_modified") is False
        and boundary.get("physical_attempt_identity_consumed") is False,
        "AUTHORITY_CHECK_REFUSAL_EXECUTION_BOUNDARY",
    )
    old_output = Path(
        str(refusal.get("authority_bindings", {}).get("authorized_output_root", ""))
    )
    require(
        refusal.get("authority_bindings", {}).get(
            "authorized_output_root_absent_after_refusal"
        )
        is True
        and not old_output.exists(),
        "AUTHORITY_CHECK_REFUSAL_OLD_OUTPUT_EXISTS",
    )
    return refusal


def authority_check_refusal_binding(
    source_commit: str, current_commit: str
) -> dict[str, Any]:
    refusal = validate_authority_check_refusal_document()
    relative = AUTHORITY_CHECK_REFUSAL_PATH.relative_to(ROOT).as_posix()
    source_raw = bytes(git(("show", f"{source_commit}:{relative}"), text=False))
    current_raw = bytes(git(("show", f"{current_commit}:{relative}"), text=False))
    source_blob = str(git(("rev-parse", f"{source_commit}:{relative}")))
    current_blob = str(git(("rev-parse", f"{current_commit}:{relative}")))
    checkout_raw = AUTHORITY_CHECK_REFUSAL_PATH.read_bytes()
    require(source_blob == current_blob, "AUTHORITY_CHECK_REFUSAL_BLOB_DRIFT")
    require(
        source_raw == current_raw == checkout_raw,
        "AUTHORITY_CHECK_REFUSAL_BYTE_DRIFT",
    )
    return {
        "path": relative,
        "byte_length": len(source_raw),
        "raw_sha256": sha256_bytes(source_raw),
        "git_blob_oid": source_blob,
        "status": refusal["status"],
        "repair_id": refusal["repair_id"],
        "physical_attempt_identity_consumed": refusal["execution_boundary"][
            "physical_attempt_identity_consumed"
        ],
    }


def validate_l1_physical_invalid_closure() -> dict[str, Any]:
    require(
        L1_PHYSICAL_INVALID_CLOSURE_PATH.is_file(),
        "L1_PHYSICAL_INVALID_CLOSURE_MISSING",
    )
    raw = L1_PHYSICAL_INVALID_CLOSURE_PATH.read_bytes()
    require(
        len(raw) == EXPECTED_L1_PHYSICAL_INVALID_CLOSURE_BYTES,
        "L1_PHYSICAL_INVALID_CLOSURE_BYTES",
    )
    require(
        sha256_bytes(raw) == EXPECTED_L1_PHYSICAL_INVALID_CLOSURE_SHA256,
        "L1_PHYSICAL_INVALID_CLOSURE_DIGEST",
    )
    closure = read_json(L1_PHYSICAL_INVALID_CLOSURE_PATH, "L1_PHYSICAL_INVALID_CLOSURE")
    require(
        closure.get("schema_version")
        == "sporespore_qsdk_r10b_l1_development_route_ghost_physical_invalid_closure_v1"
        and closure.get("status")
        == "closed_consumed_infrastructure_invalid_baseline_trace_quaternion_projection"
        and closure.get("gate_id") == "QSDK-R10B"
        and closure.get("repair_id") == "QSDK-R10B-L1"
        and closure.get("closure_id") == "QSDK-R10B-L1-P1",
        "L1_PHYSICAL_INVALID_CLOSURE_IDENTITY",
    )
    physical = closure.get("physical_attempt")
    decision = closure.get("decision")
    require(
        isinstance(physical, dict)
        and physical.get("physical_identity_consumed") is True
        and physical.get("same_identity_rerun_permitted") is False
        and physical.get("attempted_cell_count") == 1
        and physical.get("completed_valid_cell_count") == 0
        and physical.get("execution_counts", {}).get("world_build_count") == 1
        and physical.get("execution_counts", {}).get("push_world_attempt_count") == 0,
        "L1_PHYSICAL_INVALID_CLOSURE_ATTEMPT",
    )
    require(
        isinstance(decision, dict)
        and decision.get("selected_successor_id") == "QSDK-R10B-L2"
        and decision.get("same_identity_rerun_permitted") is False
        and decision.get("valid_positive_or_negative_route_result_observed") is False,
        "L1_PHYSICAL_INVALID_CLOSURE_DECISION",
    )
    return closure


def l1_physical_invalid_closure_binding(
    source_commit: str, current_commit: str
) -> dict[str, Any]:
    closure = validate_l1_physical_invalid_closure()
    relative = L1_PHYSICAL_INVALID_CLOSURE_PATH.relative_to(ROOT).as_posix()
    source_raw = bytes(git(("show", f"{source_commit}:{relative}"), text=False))
    current_raw = bytes(git(("show", f"{current_commit}:{relative}"), text=False))
    source_blob = str(git(("rev-parse", f"{source_commit}:{relative}")))
    current_blob = str(git(("rev-parse", f"{current_commit}:{relative}")))
    checkout_raw = L1_PHYSICAL_INVALID_CLOSURE_PATH.read_bytes()
    require(source_blob == current_blob, "L1_PHYSICAL_INVALID_CLOSURE_BLOB_DRIFT")
    require(
        source_raw == current_raw == checkout_raw,
        "L1_PHYSICAL_INVALID_CLOSURE_BYTE_DRIFT",
    )
    return {
        "path": relative,
        "byte_length": len(source_raw),
        "raw_sha256": sha256_bytes(source_raw),
        "git_blob_oid": source_blob,
        "status": closure["status"],
        "repair_id": closure["repair_id"],
        "closure_id": closure["closure_id"],
        "physical_identity_consumed": closure["physical_attempt"][
            "physical_identity_consumed"
        ],
        "same_identity_rerun_permitted": closure["physical_attempt"][
            "same_identity_rerun_permitted"
        ],
        "selected_successor_id": closure["decision"]["selected_successor_id"],
    }


def validate_l2_physical_invalid_closure() -> dict[str, Any]:
    require(
        L2_PHYSICAL_INVALID_CLOSURE_PATH.is_file(),
        "L2_PHYSICAL_INVALID_CLOSURE_MISSING",
    )
    raw = L2_PHYSICAL_INVALID_CLOSURE_PATH.read_bytes()
    require(
        len(raw) == EXPECTED_L2_PHYSICAL_INVALID_CLOSURE_BYTES,
        "L2_PHYSICAL_INVALID_CLOSURE_BYTES",
    )
    require(
        sha256_bytes(raw) == EXPECTED_L2_PHYSICAL_INVALID_CLOSURE_SHA256,
        "L2_PHYSICAL_INVALID_CLOSURE_DIGEST",
    )
    closure = read_json(L2_PHYSICAL_INVALID_CLOSURE_PATH, "L2_PHYSICAL_INVALID_CLOSURE")
    require(
        closure.get("schema_version")
        == "sporespore_qsdk_r10b_l2_development_route_ghost_physical_invalid_closure_v1"
        and closure.get("status")
        == "closed_consumed_infrastructure_invalid_compound_trace_representation_validation"
        and closure.get("gate_id") == "QSDK-R10B"
        and closure.get("repair_id") == "QSDK-R10B-L2"
        and closure.get("closure_id") == "QSDK-R10B-L2-P1",
        "L2_PHYSICAL_INVALID_CLOSURE_IDENTITY",
    )
    physical = closure.get("physical_attempt")
    decision = closure.get("decision")
    require(
        isinstance(physical, dict)
        and physical.get("physical_identity_consumed") is True
        and physical.get("same_identity_rerun_permitted") is False
        and physical.get("attempted_cell_count") == 1
        and physical.get("completed_valid_cell_count") == 0
        and physical.get("execution_counts", {}).get("world_build_count") == 1
        and physical.get("execution_counts", {}).get("push_world_attempt_count") == 0,
        "L2_PHYSICAL_INVALID_CLOSURE_ATTEMPT",
    )
    require(
        isinstance(decision, dict)
        and decision.get("selected_successor_id") == "QSDK-R10B-L3"
        and decision.get("same_identity_rerun_permitted") is False
        and decision.get("valid_positive_or_negative_route_result_observed") is False
        and decision.get("behavior_threshold_changed") is False
        and decision.get("quaternion_length_tolerance_changed") is False
        and decision.get("task_axis_exported_scalar_unit_tolerance_changed") is False,
        "L2_PHYSICAL_INVALID_CLOSURE_DECISION",
    )
    return closure


def l2_physical_invalid_closure_binding(
    source_commit: str, current_commit: str
) -> dict[str, Any]:
    closure = validate_l2_physical_invalid_closure()
    relative = L2_PHYSICAL_INVALID_CLOSURE_PATH.relative_to(ROOT).as_posix()
    source_raw = bytes(git(("show", f"{source_commit}:{relative}"), text=False))
    current_raw = bytes(git(("show", f"{current_commit}:{relative}"), text=False))
    source_blob = str(git(("rev-parse", f"{source_commit}:{relative}")))
    current_blob = str(git(("rev-parse", f"{current_commit}:{relative}")))
    checkout_raw = L2_PHYSICAL_INVALID_CLOSURE_PATH.read_bytes()
    require(source_blob == current_blob, "L2_PHYSICAL_INVALID_CLOSURE_BLOB_DRIFT")
    require(
        source_raw == current_raw == checkout_raw,
        "L2_PHYSICAL_INVALID_CLOSURE_BYTE_DRIFT",
    )
    return {
        "path": relative,
        "byte_length": len(source_raw),
        "raw_sha256": sha256_bytes(source_raw),
        "git_blob_oid": source_blob,
        "status": closure["status"],
        "repair_id": closure["repair_id"],
        "closure_id": closure["closure_id"],
        "physical_identity_consumed": closure["physical_attempt"][
            "physical_identity_consumed"
        ],
        "same_identity_rerun_permitted": closure["physical_attempt"][
            "same_identity_rerun_permitted"
        ],
        "selected_successor_id": closure["decision"]["selected_successor_id"],
    }


def verify_retained_qualification(
    qualification_root: Path,
    role: str,
    qualification_parent: str,
) -> dict[str, Any]:
    resolved = qualification_root.resolve()
    evidence = EVIDENCE_ROOT.resolve()
    require(
        resolved.parent == evidence and resolved.is_dir(),
        "QUALIFICATION_ROOT_NOT_DIRECT_DURABLE_CHILD",
    )
    completion_path = resolved / "qualification_completion.json"
    completion = read_json(completion_path, "QUALIFICATION_COMPLETION")
    spec = ROLE_SPECS[role]
    require(
        completion.get("schema_version")
        == "sporespore_qsdk_r10b_zero_world_qualification_completion_v4",
        "QUALIFICATION_COMPLETION_SCHEMA",
    )
    require(
        completion.get("status") == "complete_valid_official_zero_world_qualification",
        "QUALIFICATION_COMPLETION_STATUS",
    )
    require(completion.get("campaign_role") == role, "QUALIFICATION_COMPLETION_ROLE")
    require(
        completion.get("campaign_id") == spec["campaign_id"],
        "QUALIFICATION_COMPLETION_CAMPAIGN",
    )
    require(
        completion.get("source", {}).get("commit") == qualification_parent,
        "QUALIFICATION_COMPLETION_SOURCE",
    )
    require(
        completion.get("official_zero_world_qualification_passed") is True
        and completion.get("physical_execution_authorized") is False
        and completion.get("physical_acceptance_authority") is False
        and completion.get("release_authority") is False,
        "QUALIFICATION_COMPLETION_AUTHORITY",
    )
    retained: dict[str, dict[str, Any]] = {}
    for field in ("attempt", "stdout", "stderr", "receipt"):
        declaration = completion.get(field)
        require(isinstance(declaration, dict), f"QUALIFICATION_{field.upper()}_MISSING")
        relative = str(declaration.get("path", ""))
        require(
            relative and "/" not in relative and "\\" not in relative,
            f"QUALIFICATION_{field.upper()}_PATH",
        )
        path = resolved / relative
        identity = file_identity(path, relative_to=resolved)
        require(identity == declaration, f"QUALIFICATION_{field.upper()}_IDENTITY")
        retained[field] = identity
    receipt_path = resolved / retained["receipt"]["path"]
    receipt = read_json(receipt_path, "QUALIFICATION_RECEIPT")
    attempt = read_json(resolved / retained["attempt"]["path"], "QUALIFICATION_ATTEMPT")
    require(
        attempt.get("schema_version")
        == "sporespore_qsdk_r10b_zero_world_qualification_attempt_v4"
        and attempt.get("gate_id") == "QSDK-R10B"
        and attempt.get("campaign_role") == role
        and attempt.get("source", {}).get("commit") == qualification_parent
        and attempt.get("qualified_source_path_count") == EXPECTED_SOURCE_COUNT
        and attempt.get("qualified_source_path_sha256") == EXPECTED_SOURCE_PATH_SHA256
        and attempt.get("l2_successor_design_sha256") == EXPECTED_L2_DESIGN_SHA256
        and attempt.get("l3_successor_design_sha256") == EXPECTED_L3_DESIGN_SHA256
        and attempt.get("consumed_l1_physical_invalid_closure_sha256")
        == EXPECTED_L1_PHYSICAL_INVALID_CLOSURE_SHA256
        and attempt.get("consumed_l2_physical_invalid_closure_sha256")
        == EXPECTED_L2_PHYSICAL_INVALID_CLOSURE_SHA256
        and Path(str(attempt.get("output_root", ""))).resolve() == resolved
        and attempt.get("physical_execution_authorized") is False
        and attempt.get("physical_acceptance_authority") is False
        and attempt.get("release_authority") is False,
        "QUALIFICATION_ATTEMPT_INVALID",
    )
    require(
        (resolved / retained["stderr"]["path"]).read_bytes() == b"",
        "QUALIFICATION_STDERR_NOT_EMPTY",
    )
    stdout = (resolved / retained["stdout"]["path"]).read_text(encoding="utf-8")
    marker_lines = [
        line
        for line in stdout.splitlines()
        if line.startswith(QUALIFICATION_PASS_MARKER)
    ]
    require(len(marker_lines) == 1, "QUALIFICATION_PASS_MARKER_COUNT")
    marker_receipt = json.loads(marker_lines[0][len(QUALIFICATION_PASS_MARKER) :])
    require(marker_receipt == receipt, "QUALIFICATION_RECEIPT_NOT_EXACT_STDOUT_OBJECT")
    require(
        receipt.get("schema_version")
        == "sporespore_qsdk_r10b_zero_world_implementation_audit_v4"
        and receipt.get("ok") is True
        and receipt.get("official_qualification_mode") is True
        and receipt.get("source_commit") == qualification_parent
        and receipt.get("worktree_clean") is True
        and receipt.get("head_origin_main_equal") is True
        and receipt.get("head_live_remote_main_equal") is True
        and receipt.get("qualified_source_path_count") == EXPECTED_SOURCE_COUNT
        and receipt.get("qualified_source_path_sha256") == EXPECTED_SOURCE_PATH_SHA256,
        "QUALIFICATION_RECEIPT_SOURCE",
    )
    require(
        receipt.get("l2_successor_design_audit_passed") is True
        and receipt.get("l3_successor_design_audit_passed") is True
        and receipt.get("l3_successor_design_raw_sha256")
        == EXPECTED_L3_DESIGN_SHA256
        and receipt.get("l2_physical_invalid_closure_audit_passed") is True
        and receipt.get("l2_physical_identity_consumed") is True
        and receipt.get("l2_same_identity_rerun_permitted") is False
        and receipt.get("l2_valid_behavior_result_count") == 0
        and receipt.get("l3_retained_trace_validation_passed") is True
        and receipt.get("l3_retained_trace_row_count") == 2640
        and receipt.get("l3_projection_receipt_acceptance_count") == 2640
        and receipt.get("l3_exported_axis_acceptance_count") == 2640
        and receipt.get("l3_behavior_reclassification_count") == 0
        and receipt.get(
            "l3_projection_receipt_numeric_type_mutation_rejection_count_per_source_gate"
        )
        == 2
        and receipt.get("retained_raw_quaternion_refusal_count_per_source_gate") == 2
        and receipt.get(
            "retained_projected_quaternion_acceptance_count_per_source_gate"
        )
        == 2
        and receipt.get(
            "additional_nonidentity_projected_acceptance_count_per_source_gate"
        )
        == 2
        and receipt.get("zero_quaternion_projection_refusal_count_per_source_gate") == 1
        and receipt.get("projection_receipt_mutation_rejection_count_per_source_gate")
        == 3,
        "QUALIFICATION_RECEIPT_L2_L3_CONTROLS",
    )
    for counter in (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "native_readback_count",
        "solver_step_count",
    ):
        require(receipt.get(counter) == 0, f"QUALIFICATION_NONZERO_{counter.upper()}")
    require(
        receipt.get("physical_acceptance_authority") is False
        and receipt.get("release_authority") is False,
        "QUALIFICATION_RECEIPT_AUTHORITY",
    )
    tree_entries = [
        file_identity(path, relative_to=resolved)
        for path in sorted(resolved.iterdir(), key=lambda item: item.name)
        if path.is_file()
    ]
    require(len(tree_entries) == 5, "QUALIFICATION_TREE_FILE_COUNT")
    return {
        "root": resolved.as_posix(),
        "completion": file_identity(completion_path, relative_to=resolved),
        "files": tree_entries,
        "file_count": len(tree_entries),
        "total_byte_length": sum(int(entry["byte_length"]) for entry in tree_entries),
        "tree_manifest_sha256": sha256_bytes(canonical_bytes(tree_entries)),
        "receipt": receipt,
    }


def development_prerequisite(
    role: str, qualification_parent: str
) -> dict[str, Any] | None:
    if role == "development_route_ghost":
        return None
    relative = "sdk/qsdk_r10b_development_route_ghost_physical_closure_v1.json"
    path = ROOT / relative
    document = read_json(path, "DEVELOPMENT_ROUTE_GHOST_CLOSURE")
    require(
        document.get("schema_version")
        == "sporespore_qsdk_r10b_development_route_ghost_physical_closure_v1",
        "DEVELOPMENT_ROUTE_GHOST_CLOSURE_SCHEMA",
    )
    require(document.get("gate_id") == "QSDK-R10B", "DEVELOPMENT_ROUTE_GHOST_GATE")
    require(
        document.get("campaign_role") == "development_route_ghost",
        "DEVELOPMENT_ROUTE_GHOST_ROLE",
    )
    require(
        document.get("route_execution_valid") is True, "DEVELOPMENT_ROUTE_NOT_VALID"
    )
    require(
        document.get("physical_identity_consumed") is True,
        "DEVELOPMENT_ROUTE_NOT_CONSUMED",
    )
    require(
        document.get("same_identity_rerun_permitted") is False,
        "DEVELOPMENT_ROUTE_RERUN_PERMITTED",
    )
    blob = str(git(("rev-parse", f"{qualification_parent}:{relative}")))
    return {
        **file_identity(path, relative_to=ROOT),
        "git_blob_oid": blob,
        "route_execution_valid": True,
        "physical_identity_consumed": True,
        "same_identity_rerun_permitted": False,
    }


def write_new_json(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    raw = (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
    try:
        with path.open("xb") as stream:
            stream.write(raw)
            stream.flush()
    except FileExistsError as exc:
        raise MaterializationFailure(f"OUTPUT_ALREADY_EXISTS:{path}") from exc


def materialize_stage_freeze(arguments: argparse.Namespace) -> dict[str, Any]:
    identity = live_source_identity()
    role = arguments.campaign_role
    spec = ROLE_SPECS[role]
    qualification_parent = str(identity["commit"])
    source_commit = arguments.source_commit or qualification_parent
    require(len(source_commit) == 40, "SOURCE_COMMIT_FORMAT")
    if role == "development_route_ghost":
        require(
            source_commit == qualification_parent,
            "DEVELOPMENT_SOURCE_NOT_QUALIFICATION_PARENT",
        )
    bindings = source_bindings(source_commit, qualification_parent)
    refusal_binding = authority_check_refusal_binding(
        source_commit, qualification_parent
    )
    l1_invalid_binding = l1_physical_invalid_closure_binding(
        source_commit, qualification_parent
    )
    l2_invalid_binding = l2_physical_invalid_closure_binding(
        source_commit, qualification_parent
    )
    require(
        L2_DESIGN_PATH.stat().st_size == EXPECTED_L2_DESIGN_BYTES
        and sha256_bytes(L2_DESIGN_PATH.read_bytes()) == EXPECTED_L2_DESIGN_SHA256,
        "L2_DESIGN_IDENTITY",
    )
    require(
        L3_DESIGN_PATH.stat().st_size == EXPECTED_L3_DESIGN_BYTES
        and sha256_bytes(L3_DESIGN_PATH.read_bytes()) == EXPECTED_L3_DESIGN_SHA256,
        "L3_DESIGN_IDENTITY",
    )
    retained = verify_retained_qualification(
        arguments.qualification_root, role, qualification_parent
    )
    prerequisite = development_prerequisite(role, qualification_parent)
    output = ROOT / spec["stage_freeze_path"]
    require(not output.exists(), "STAGE_FREEZE_ALREADY_EXISTS")
    receipt = retained["receipt"]
    closure = {
        "schema_version": "sporespore_qsdk_r10b_stage_freeze_v4",
        "status": "closed_passing_official_zero_world_qualification",
        "gate_id": "QSDK-R10B",
        "campaign_id": spec["campaign_id"],
        "campaign_role": role,
        "question_class": spec["question_class"],
        "ledger_scope": {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "closed_official_zero_world_stage_freeze",
            "question_class": spec["question_class"],
        },
        "source_commit": source_commit,
        "source_tree": str(git(("rev-parse", f"{source_commit}^{{tree}}"))),
        "qualification_parent_commit": qualification_parent,
        "qualification_parent_tree": identity["tree"],
        "qualification_parent_subject": str(
            git(("show", "-s", "--format=%s", qualification_parent))
        ),
        "repository_remote": EXPECTED_REMOTE,
        "qualified_source_path_count": EXPECTED_SOURCE_COUNT,
        "qualified_source_path_sha256": EXPECTED_SOURCE_PATH_SHA256,
        "qualified_source_bindings": bindings,
        "r10a_design_sha256": EXPECTED_DESIGN_SHA256,
        "l2_successor_design_sha256": EXPECTED_L2_DESIGN_SHA256,
        "l3_successor_design_sha256": EXPECTED_L3_DESIGN_SHA256,
        "dependency_manifest_sha256": sha256_bytes(MANIFEST_PATH.read_bytes()),
        "ordered_cell_ids": spec["ordered_cell_ids"],
        "maximum_world_count": spec["maximum_world_count"],
        "prerequisite_development_route_ghost": prerequisite,
        "superseded_authority_check_refusal": refusal_binding,
        "consumed_l1_physical_invalid_closure": l1_invalid_binding,
        "consumed_l2_physical_invalid_closure": l2_invalid_binding,
        "official_qualification": {
            "evidence_root": retained["root"],
            "file_count": retained["file_count"],
            "total_byte_length": retained["total_byte_length"],
            "tree_manifest_sha256": retained["tree_manifest_sha256"],
            "completion": retained["completion"],
            "files": retained["files"],
            "implementation_receipt_schema": receipt["schema_version"],
            "implementation_receipt_runtime_identity_projection": receipt[
                "runtime_identity_projection"
            ],
            "implementation_receipt_summary": {
                key: receipt[key]
                for key in (
                    "source_commit",
                    "r10a_design_raw_sha256",
                    "r10a_design_mutation_rejection_count",
                    "l2_successor_design_mutation_rejection_count",
                    "l3_successor_design_mutation_rejection_count",
                    "l2_physical_invalid_closure_audit_passed",
                    "l2_physical_identity_consumed",
                    "l2_same_identity_rerun_permitted",
                    "l2_valid_behavior_result_count",
                    "l3_retained_trace_validation_passed",
                    "l3_retained_trace_row_count",
                    "l3_projection_receipt_acceptance_count",
                    "l3_exported_axis_acceptance_count",
                    "l3_behavior_reclassification_count",
                    "l3_projection_receipt_numeric_type_mutation_rejection_count_per_source_gate",
                    "retained_raw_quaternion_refusal_count_per_source_gate",
                    "retained_projected_quaternion_acceptance_count_per_source_gate",
                    "additional_nonidentity_projected_acceptance_count_per_source_gate",
                    "zero_quaternion_projection_refusal_count_per_source_gate",
                    "projection_receipt_mutation_rejection_count_per_source_gate",
                    "qualified_source_path_count",
                    "qualified_source_path_sha256",
                    "authorization_document_valid_control_count_per_source_gate",
                    "authorization_document_mutation_rejection_count_per_source_gate",
                    "supervisor_entrypoint_preflight_count",
                    "direct_physical_bypass_refusal_count",
                    "model_construction_count",
                    "world_attempt_count",
                    "world_build_count",
                    "native_readback_count",
                    "solver_step_count",
                    "physical_acceptance_authority",
                    "release_authority",
                )
            },
        },
        "official_zero_world_qualification_passed": True,
        "physical_execution_authorized_by_freeze": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
        "claim_boundary": {
            "production_route_construct_step_finalize_retain_pair_evaluate_qualified": False,
            "bounded_upright_push_recovery_claimed": False,
            "fall_recovery_claimed": False,
            "prone_to_standing_claimed": False,
            "force_aware_recovery_claimed": False,
            "other_engine_claimed": False,
            "cross_engine_equivalence_claimed": False,
        },
    }
    write_new_json(output, closure)
    return {
        "mode": "stage-freeze",
        "campaign_role": role,
        "output_path": spec["stage_freeze_path"],
        "output_identity": file_identity(output, relative_to=ROOT),
        "source_commit": source_commit,
        "qualification_parent_commit": qualification_parent,
        "physical_execution_authorized": False,
    }


def validate_stage_freeze_document(
    freeze: dict[str, Any], role: str, current_commit: str
) -> dict[str, Any]:
    spec = ROLE_SPECS[role]
    require(
        freeze.get("schema_version") == "sporespore_qsdk_r10b_stage_freeze_v4",
        "STAGE_SCHEMA",
    )
    require(
        freeze.get("status") == "closed_passing_official_zero_world_qualification",
        "STAGE_STATUS",
    )
    require(freeze.get("campaign_id") == spec["campaign_id"], "STAGE_CAMPAIGN")
    require(freeze.get("campaign_role") == role, "STAGE_ROLE")
    require(
        freeze.get("question_class") == spec["question_class"], "STAGE_QUESTION_CLASS"
    )
    require(
        freeze.get("qualification_parent_commit") == str(git(("rev-parse", "HEAD^"))),
        "STAGE_PARENT",
    )
    require(
        freeze.get("qualified_source_path_count") == EXPECTED_SOURCE_COUNT,
        "STAGE_SOURCE_COUNT",
    )
    require(
        freeze.get("qualified_source_path_sha256") == EXPECTED_SOURCE_PATH_SHA256,
        "STAGE_SOURCE_DIGEST",
    )
    require(freeze.get("r10a_design_sha256") == EXPECTED_DESIGN_SHA256, "STAGE_DESIGN")
    require(
        freeze.get("l2_successor_design_sha256") == EXPECTED_L2_DESIGN_SHA256,
        "STAGE_L2_DESIGN",
    )
    require(
        freeze.get("l3_successor_design_sha256") == EXPECTED_L3_DESIGN_SHA256,
        "STAGE_L3_DESIGN",
    )
    require(freeze.get("ordered_cell_ids") == spec["ordered_cell_ids"], "STAGE_CELLS")
    require(
        freeze.get("maximum_world_count") == spec["maximum_world_count"],
        "STAGE_WORLD_COUNT",
    )
    require(
        freeze.get("official_zero_world_qualification_passed") is True,
        "STAGE_NOT_QUALIFIED",
    )
    require(
        freeze.get("physical_execution_authorized_by_freeze") is False,
        "STAGE_AUTHORIZED_PHYSICS",
    )
    require(
        freeze.get("physical_acceptance_authority") is False,
        "STAGE_ACCEPTANCE_AUTHORITY",
    )
    require(freeze.get("release_authority") is False, "STAGE_RELEASE_AUTHORITY")
    source_commit = str(freeze.get("source_commit", ""))
    bindings = freeze.get("qualified_source_bindings")
    require(
        isinstance(bindings, list) and len(bindings) == EXPECTED_SOURCE_COUNT,
        "STAGE_BINDINGS",
    )
    expected_bindings = source_bindings(source_commit, current_commit)
    require(bindings == expected_bindings, "STAGE_BINDING_CONTENT")
    require(
        freeze.get("superseded_authority_check_refusal")
        == authority_check_refusal_binding(source_commit, current_commit),
        "STAGE_AUTHORITY_CHECK_REFUSAL_BINDING",
    )
    require(
        freeze.get("consumed_l1_physical_invalid_closure")
        == l1_physical_invalid_closure_binding(source_commit, current_commit),
        "STAGE_L1_PHYSICAL_INVALID_CLOSURE_BINDING",
    )
    require(
        freeze.get("consumed_l2_physical_invalid_closure")
        == l2_physical_invalid_closure_binding(source_commit, current_commit),
        "STAGE_L2_PHYSICAL_INVALID_CLOSURE_BINDING",
    )
    return spec


def materialize_execution_authority(arguments: argparse.Namespace) -> dict[str, Any]:
    identity = live_source_identity()
    role = arguments.campaign_role
    spec = ROLE_SPECS[role]
    current_commit = str(identity["commit"])
    stage_relative = str(spec["stage_freeze_path"])
    authority_relative = str(spec["authority_path"])
    changed = str(
        git(("diff-tree", "--no-commit-id", "--name-only", "-r", current_commit))
    ).splitlines()
    require(changed == [stage_relative], "QUALIFICATION_COMMIT_NOT_STAGE_FREEZE_ONLY")
    stage_path = ROOT / stage_relative
    freeze = read_json(stage_path, "STAGE_FREEZE")
    validate_stage_freeze_document(freeze, role, current_commit)
    authority_path = ROOT / authority_relative
    require(not authority_path.exists(), "EXECUTION_AUTHORITY_ALREADY_EXISTS")
    source_commit = str(freeze["source_commit"])
    output_root = (
        arguments.evidence_root.resolve()
        / f"qsdk-r10b-{spec['physical_output_slug']}-physical-{source_commit[:12]}"
    )
    require(
        arguments.evidence_root.resolve() == EVIDENCE_ROOT.resolve(),
        "WRONG_EVIDENCE_ROOT",
    )
    require(not output_root.exists(), "PHYSICAL_OUTPUT_IDENTITY_ALREADY_CONSUMED")
    stage_blob = str(git(("rev-parse", f"{current_commit}:{stage_relative}")))
    authority = {
        "schema_version": "sporespore_qsdk_r10b_execution_authority_v4",
        "status": "authorized_single_use_unconsumed",
        "gate_id": "QSDK-R10B",
        "campaign_id": spec["campaign_id"],
        "campaign_role": role,
        "question_class": spec["question_class"],
        "ledger_scope": {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "single_use_parent_bound_physical_execution_authorization",
            "question_class": spec["question_class"],
        },
        "authorization_commit_derived_from_current_head": True,
        "authorization_parent_commit": current_commit,
        "qualification_parent_commit": freeze["qualification_parent_commit"],
        "source_commit": source_commit,
        "qualification_closure_path": stage_relative,
        "stage_freeze_sha256": sha256_bytes(stage_path.read_bytes()),
        "stage_freeze_git_blob_oid": stage_blob,
        "r10a_design_sha256": EXPECTED_DESIGN_SHA256,
        "l2_successor_design_sha256": EXPECTED_L2_DESIGN_SHA256,
        "l3_successor_design_sha256": EXPECTED_L3_DESIGN_SHA256,
        "qualified_source_path_count": EXPECTED_SOURCE_COUNT,
        "qualified_source_path_sha256": EXPECTED_SOURCE_PATH_SHA256,
        "ordered_cell_ids": spec["ordered_cell_ids"],
        "maximum_world_count": spec["maximum_world_count"],
        "maximum_campaign_attempt_count": 1,
        "output_root": str(output_root),
        "superseded_authority_check_refusal_sha256": (
            EXPECTED_AUTHORITY_CHECK_REFUSAL_SHA256
        ),
        "consumed_l1_physical_invalid_closure_sha256": (
            EXPECTED_L1_PHYSICAL_INVALID_CLOSURE_SHA256
        ),
        "consumed_l2_physical_invalid_closure_sha256": (
            EXPECTED_L2_PHYSICAL_INVALID_CLOSURE_SHA256
        ),
        "zero_world_qualification_passed": True,
        "physical_execution_authorized": True,
        "physical_identity_consumed": False,
        "same_identity_rerun_permitted": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    write_new_json(authority_path, authority)
    return {
        "mode": "execution-authority",
        "campaign_role": role,
        "output_path": authority_relative,
        "output_identity": file_identity(authority_path, relative_to=ROOT),
        "source_commit": source_commit,
        "authorization_parent_commit": current_commit,
        "physical_output_root": str(output_root),
        "physical_execution_authorized_after_authority_only_commit": True,
    }


def self_test() -> dict[str, Any]:
    paths, digest = source_inventory()
    refusal = validate_authority_check_refusal_document()
    l1_invalid = validate_l1_physical_invalid_closure()
    l2_invalid = validate_l2_physical_invalid_closure()
    require(DESIGN_PATH.is_file(), "DESIGN_MISSING")
    require(
        sha256_bytes(DESIGN_PATH.read_bytes()) == EXPECTED_DESIGN_SHA256,
        "DESIGN_DIGEST",
    )
    require(
        L2_DESIGN_PATH.is_file()
        and L2_DESIGN_PATH.stat().st_size == EXPECTED_L2_DESIGN_BYTES
        and sha256_bytes(L2_DESIGN_PATH.read_bytes()) == EXPECTED_L2_DESIGN_SHA256,
        "L2_DESIGN_DIGEST",
    )
    require(
        L3_DESIGN_PATH.is_file()
        and L3_DESIGN_PATH.stat().st_size == EXPECTED_L3_DESIGN_BYTES
        and sha256_bytes(L3_DESIGN_PATH.read_bytes()) == EXPECTED_L3_DESIGN_SHA256,
        "L3_DESIGN_DIGEST",
    )
    require(
        set(ROLE_SPECS) == {"development_route_ghost", "held_out_finite_decision"},
        "ROLE_SET",
    )
    require(
        ROLE_SPECS["development_route_ghost"]["maximum_world_count"] == 2,
        "GHOST_WORLD_COUNT",
    )
    require(
        ROLE_SPECS["held_out_finite_decision"]["maximum_world_count"] == 6,
        "HELDOUT_WORLD_COUNT",
    )
    return {
        "schema_version": "sporespore_qsdk_r10b_authority_materializer_self_test_v4",
        "gate_id": "QSDK-R10B",
        "ok": True,
        "qualified_source_path_count": len(paths),
        "qualified_source_path_sha256": digest,
        "campaign_role_count": len(ROLE_SPECS),
        "authority_check_refusal_preserved": True,
        "authority_check_refusal_status": refusal["status"],
        "authority_check_refusal_raw_sha256": (EXPECTED_AUTHORITY_CHECK_REFUSAL_SHA256),
        "l1_physical_invalid_closure_preserved": True,
        "l1_physical_invalid_closure_status": l1_invalid["status"],
        "l1_physical_invalid_closure_raw_sha256": (
            EXPECTED_L1_PHYSICAL_INVALID_CLOSURE_SHA256
        ),
        "l1_physical_identity_consumed": True,
        "l1_same_identity_rerun_permitted": False,
        "l2_successor_design_raw_sha256": EXPECTED_L2_DESIGN_SHA256,
        "l2_physical_invalid_closure_preserved": True,
        "l2_physical_invalid_closure_status": l2_invalid["status"],
        "l2_physical_invalid_closure_raw_sha256": (
            EXPECTED_L2_PHYSICAL_INVALID_CLOSURE_SHA256
        ),
        "l2_physical_identity_consumed": True,
        "l2_same_identity_rerun_permitted": False,
        "l3_successor_design_raw_sha256": EXPECTED_L3_DESIGN_SHA256,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "scene_tree_insertion_count": 0,
        "native_readback_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "mode", choices=("self-test", "stage-freeze", "execution-authority")
    )
    parser.add_argument(
        "--campaign-role", choices=tuple(ROLE_SPECS), default="development_route_ghost"
    )
    parser.add_argument("--qualification-root", type=Path)
    parser.add_argument("--source-commit", default="")
    parser.add_argument("--evidence-root", type=Path, default=EVIDENCE_ROOT)
    arguments = parser.parse_args()
    try:
        if arguments.mode == "self-test":
            print(
                SELF_TEST_MARKER
                + json.dumps(self_test(), separators=(",", ":"), sort_keys=True)
            )
            return 0
        if arguments.mode == "stage-freeze":
            require(
                arguments.qualification_root is not None, "QUALIFICATION_ROOT_REQUIRED"
            )
            result = materialize_stage_freeze(arguments)
        else:
            result = materialize_execution_authority(arguments)
        print(
            MATERIALIZED_MARKER
            + json.dumps(result, separators=(",", ":"), sort_keys=True)
        )
        return 0
    except (MaterializationFailure, OSError, UnicodeError, json.JSONDecodeError) as exc:
        print(f"QSDK_R10B_AUTHORITY_MATERIALIZATION_FAIL {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
