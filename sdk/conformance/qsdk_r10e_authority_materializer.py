#!/usr/bin/env python3
"""Materialize QSDK-R10E stage freezes and parent-bound execution authorities."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
from typing import Any, Iterable, Mapping


ROOT = Path(__file__).resolve().parents[2]
EXPECTED_ROOT = Path(r"C:\Users\Cole\CodeStuff\games\SporeSpore")
EXPECTED_REMOTE = "https://github.com/Slagathore/sporespore.git"
EVIDENCE_ROOT = Path(r"C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence")
DEPENDENCY_AUDIT_PATH = ROOT / "sdk/conformance/qsdk_r10e_dependency_closure.py"
DESIGN_PATH = (
    ROOT
    / "sdk/qsdk_r10e_observer_minimized_upright_push_recovery_successor_design_v1.json"
)
R10D_DEVELOPMENT_PATH = (
    ROOT / "sdk/qsdk_r10d_l1_development_route_ghost_physical_closure_v1.json"
)
R10D_HELD_OUT_PATH = (
    ROOT / "sdk/qsdk_r10d_l1_held_out_finite_decision_physical_closure_v1.json"
)
R05E_PATH = ROOT / "sdk/qsdk_r05e_exact_finite_morphology_physical_closure_v1.json"
SUPERVISOR_REFUSAL_PATH = (
    ROOT / "sdk/qsdk_r10e_development_route_ghost_physical_supervisor_refusal_v1.json"
)
R10E_DEVELOPMENT_CLOSURE_PATH = (
    ROOT / "sdk/qsdk_r10e_development_route_ghost_physical_closure_v2.json"
)
R10E_L2_HELD_OUT_FAILURE_PATH = (
    ROOT / "sdk/qsdk_r10e_l2_held_out_finite_decision_physical_failure_closure_v1.json"
)

EXPECTED_DESIGN_BYTES = 40_110
EXPECTED_DESIGN_SHA256 = (
    "sha256:791dbf01b8720ca0851b5ec4f722ff421baeb9ca277399974db6338aec03e81a"
)
EXPECTED_R10D_DEVELOPMENT_BYTES = 11_227
EXPECTED_R10D_DEVELOPMENT_SHA256 = (
    "sha256:dbbdeb257a260a64c730459880d8d4d66682ec94b65ec8f3beaeb4c38a3cdcc9"
)
EXPECTED_R10D_HELD_OUT_BYTES = 16_158
EXPECTED_R10D_HELD_OUT_SHA256 = (
    "sha256:4a96145b54161a166e735bfd884e497772774d0f9e1e11ae8db6b8fa557c4ed2"
)
EXPECTED_R05E_BYTES = 49_049
EXPECTED_R05E_SHA256 = (
    "sha256:dac4ac8790cd74d89da0286c36aaf541fbfe7011d2bea66077b941363d47b33e"
)
EXPECTED_SUPERVISOR_REFUSAL_BYTES = 5_728
EXPECTED_SUPERVISOR_REFUSAL_SHA256 = (
    "sha256:831c1c8bdc3720be7e1c9abe584cea098856982b4795f23f00c029f18b3b7fc0"
)
EXPECTED_L2_HELD_OUT_FAILURE_BYTES = 14_311
EXPECTED_L2_HELD_OUT_FAILURE_SHA256 = (
    "sha256:29942c4f666d3cc7d88388945bb450d6d64f01a6757f72f7a38e149b5d351211"
)

# Final values are installed with the dependency manifest and worker constants.
EXPECTED_SOURCE_COUNT = 91
EXPECTED_SOURCE_PATH_SHA256 = (
    "sha256:348c65a448016b769cc13f3c23336a295a03990ef39e40a8418650a2d9667f67"
)

DEPENDENCY_MARKER = "QSDK_R10E_DEPENDENCY_CLOSURE_PASS "
SELF_TEST_MARKER = "QSDK_R10E_AUTHORITY_MATERIALIZER_SELF_TEST_PASS "
MATERIALIZED_MARKER = "QSDK_R10E_AUTHORITY_MATERIALIZED "
QUALIFICATION_COMPLETION_SCHEMA = (
    "sporespore_qsdk_r10e_zero_world_qualification_completion_v2"
)
QUALIFICATION_ATTEMPT_SCHEMA = (
    "sporespore_qsdk_r10e_zero_world_qualification_attempt_v2"
)
IMPLEMENTATION_AUDIT_SCHEMA = "sporespore_qsdk_r10e_zero_world_implementation_audit_v1"
RUNTIME_IDENTITY_SCHEMA = "sporespore_qsdk_r10e_runtime_identity_v1"
STAGE_FREEZE_SCHEMA = "sporespore_qsdk_r10e_stage_freeze_v3"
EXECUTION_AUTHORITY_SCHEMA = "sporespore_qsdk_r10e_execution_authority_v3"

ROLE_SPECS: dict[str, dict[str, Any]] = {
    "development_route_ghost": {
        "repair_id": "QSDK-R10E-L2",
        "materialization_permitted": False,
        "qualification_attempt_schema": (
            "sporespore_qsdk_r10e_zero_world_qualification_attempt_v1"
        ),
        "qualification_completion_schema": (
            "sporespore_qsdk_r10e_zero_world_qualification_completion_v1"
        ),
        "stage_schema": "sporespore_qsdk_r10e_stage_freeze_v2",
        "authority_schema": "sporespore_qsdk_r10e_execution_authority_v2",
        "campaign_id": "QSDK-R10E-OBSERVER-MINIMIZED-UPRIGHT-PUSH-RECOVERY-ROUTE-GHOST",
        "question_class": "development",
        "ordered_cell_ids": ["baseline_s40002", "push_s40002"],
        "stage_path": (
            "sdk/qsdk_r10e_development_route_ghost_"
            "zero_world_qualification_closure_v2.json"
        ),
        "authority_path": (
            "sdk/qsdk_r10e_development_route_ghost_execution_authority_v2.json"
        ),
        "physical_output_slug": "development-route-ghost",
    },
    "held_out_finite_decision": {
        "repair_id": "QSDK-R10E-L3",
        "materialization_permitted": True,
        "qualification_attempt_schema": QUALIFICATION_ATTEMPT_SCHEMA,
        "qualification_completion_schema": QUALIFICATION_COMPLETION_SCHEMA,
        "stage_schema": STAGE_FREEZE_SCHEMA,
        "authority_schema": EXECUTION_AUTHORITY_SCHEMA,
        "campaign_id": "QSDK-R10E-OBSERVER-MINIMIZED-UPRIGHT-PUSH-RECOVERY-VALIDATION",
        "question_class": "finite decision",
        "ordered_cell_ids": [
            "baseline_s40101",
            "push_s40101",
            "baseline_s40102",
            "push_s40102",
            "baseline_s40103",
            "push_s40103",
        ],
        "stage_path": (
            "sdk/qsdk_r10e_held_out_finite_decision_"
            "zero_world_qualification_closure_v3.json"
        ),
        "authority_path": (
            "sdk/qsdk_r10e_held_out_finite_decision_execution_authority_v3.json"
        ),
        "physical_output_slug": "held-out-finite-decision",
    },
}


class MaterializationFailure(RuntimeError):
    """A prospective R10E authority boundary was not exact."""


def require(condition: bool, code: str) -> None:
    if not condition:
        raise MaterializationFailure(code)


def sha256_bytes(value: bytes) -> str:
    return "sha256:" + hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return "sha256:" + digest.hexdigest()


def is_prefixed_sha256(value: Any) -> bool:
    return (
        isinstance(value, str)
        and re.fullmatch(r"sha256:[0-9a-f]{64}", value) is not None
    )


def is_commit(value: Any) -> bool:
    return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{40}", value) is not None


def read_json(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise MaterializationFailure(f"{label}_UNREADABLE:{exc}") from exc
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


def live_source_identity() -> dict[str, str | bool]:
    require(ROOT.resolve() == EXPECTED_ROOT.resolve(), "CANONICAL_ROOT")
    require(
        Path(git(("rev-parse", "--show-toplevel"))).resolve() == ROOT.resolve(),
        "GIT_TOPLEVEL",
    )
    require(git(("remote", "get-url", "origin")) == EXPECTED_REMOTE, "REMOTE")
    require(git(("branch", "--show-current")) == "main", "BRANCH")
    require(
        git(("status", "--porcelain=v1", "--untracked-files=all"), allow_empty=True)
        == "",
        "WORKTREE_NOT_CLEAN",
    )
    head = git(("rev-parse", "HEAD"))
    origin = git(("rev-parse", "origin/main"))
    live_parts = git(("ls-remote", "origin", "refs/heads/main")).split()
    require(
        len(live_parts) == 2 and live_parts[1] == "refs/heads/main",
        "LIVE_MAIN_FORMAT",
    )
    require(head == origin == live_parts[0], "HEAD_ORIGIN_LIVE_MISMATCH")
    return {
        "commit": head,
        "parent": git(("rev-parse", "HEAD^")),
        "tree": git(("rev-parse", "HEAD^{tree}")),
        "clean": True,
    }


def parse_marker(stdout: str, marker: str, label: str) -> dict[str, Any]:
    matches = [
        line[len(marker) :] for line in stdout.splitlines() if line.startswith(marker)
    ]
    require(len(matches) == 1, f"{label}_MARKER_COUNT")
    try:
        value = json.loads(matches[0])
    except json.JSONDecodeError as exc:
        raise MaterializationFailure(f"{label}_MARKER_JSON:{exc}") from exc
    require(isinstance(value, dict), f"{label}_MARKER_NOT_OBJECT")
    return value


def dependency_receipt() -> dict[str, Any]:
    require(
        EXPECTED_SOURCE_COUNT > 0 and is_prefixed_sha256(EXPECTED_SOURCE_PATH_SHA256),
        "SOURCE_BINDING_NOT_FINALIZED",
    )
    result = subprocess.run(
        (sys.executable, "-B", str(DEPENDENCY_AUDIT_PATH), "--require-tracked"),
        cwd=ROOT,
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
        timeout=120,
    )
    require(
        result.returncode == 0,
        f"DEPENDENCY_AUDIT_FAILED:{(result.stdout + result.stderr)[-3000:]}",
    )
    receipt = parse_marker(result.stdout, DEPENDENCY_MARKER, "DEPENDENCY")
    require(
        receipt.get("ok") is True
        and receipt.get("qualification_finalized") is True
        and receipt.get("qualified_source_path_count") == EXPECTED_SOURCE_COUNT
        and receipt.get("qualified_source_path_sha256") == EXPECTED_SOURCE_PATH_SHA256
        and receipt.get("all_qualified_source_paths_tracked", True) is True
        and receipt.get("all_qualified_paths_tracked") is True
        and receipt.get("world_build_count") == 0
        and receipt.get("solver_step_count") == 0,
        "DEPENDENCY_RECEIPT",
    )
    return receipt


def file_identity(path: Path, *, relative_to: Path | None = None) -> dict[str, Any]:
    raw = path.read_bytes()
    display = path.as_posix()
    if relative_to is not None:
        display = path.resolve().relative_to(relative_to.resolve()).as_posix()
    return {"path": display, "byte_length": len(raw), "raw_sha256": sha256_bytes(raw)}


def committed_file_binding(relative: str, commit: str) -> dict[str, Any]:
    path = ROOT / relative
    require(path.is_file(), f"BINDING_MISSING:{relative}")
    raw = path.read_bytes()
    blob = git(("rev-parse", f"{commit}:{relative}"))
    require(
        blob == git(("hash-object", "--", relative)), f"BINDING_BLOB_DRIFT:{relative}"
    )
    return {
        "path": relative,
        "byte_length": len(raw),
        "raw_sha256": sha256_bytes(raw),
        "git_blob_oid": blob,
    }


def validate_bound_file(
    path: Path, byte_length: int, digest: str, label: str
) -> dict[str, Any]:
    require(path.is_file(), f"{label}_MISSING")
    require(path.stat().st_size == byte_length, f"{label}_BYTE_LENGTH")
    require(sha256_file(path) == digest, f"{label}_SHA256")
    return read_json(path, label)


def ledger_scope(question_class: str, authority_mode: str) -> dict[str, str]:
    return {
        "subsystem": "recovery",
        "engine_scope": "godot_jolt",
        "authority_mode": authority_mode,
        "question_class": question_class,
    }


def role_spec(role: str) -> dict[str, Any]:
    require(role in ROLE_SPECS, "CAMPAIGN_ROLE")
    return ROLE_SPECS[role]


def historical_bindings(source_commit: str) -> dict[str, dict[str, Any]]:
    design = validate_bound_file(
        DESIGN_PATH, EXPECTED_DESIGN_BYTES, EXPECTED_DESIGN_SHA256, "R10E_DESIGN"
    )
    development = validate_bound_file(
        R10D_DEVELOPMENT_PATH,
        EXPECTED_R10D_DEVELOPMENT_BYTES,
        EXPECTED_R10D_DEVELOPMENT_SHA256,
        "R10D_DEVELOPMENT",
    )
    held_out = validate_bound_file(
        R10D_HELD_OUT_PATH,
        EXPECTED_R10D_HELD_OUT_BYTES,
        EXPECTED_R10D_HELD_OUT_SHA256,
        "R10D_HELD_OUT",
    )
    r05e = validate_bound_file(
        R05E_PATH, EXPECTED_R05E_BYTES, EXPECTED_R05E_SHA256, "R05E"
    )
    supervisor_refusal = validate_bound_file(
        SUPERVISOR_REFUSAL_PATH,
        EXPECTED_SUPERVISOR_REFUSAL_BYTES,
        EXPECTED_SUPERVISOR_REFUSAL_SHA256,
        "R10E_SUPERVISOR_REFUSAL",
    )
    l2_failure = validate_bound_file(
        R10E_L2_HELD_OUT_FAILURE_PATH,
        EXPECTED_L2_HELD_OUT_FAILURE_BYTES,
        EXPECTED_L2_HELD_OUT_FAILURE_SHA256,
        "R10E_L2_HELD_OUT_FAILURE",
    )
    require(
        design.get("status")
        == "prospective_zero_world_successor_design_complete_physics_blocked",
        "R10E_DESIGN_STATUS",
    )
    require(
        development.get("status")
        == "closed_execution_valid_complete_behavior_finite_negative"
        and development.get("route_execution_valid") is True
        and development.get("physical_identity_consumed") is True
        and development.get("same_identity_rerun_permitted") is False,
        "R10D_DEVELOPMENT_STATUS",
    )
    require(
        held_out.get("status")
        == "closed_consumed_invalid_or_incomplete_no_finite_decision"
        and held_out.get("route_execution_valid") is False
        and held_out.get("physical_identity_consumed") is True
        and held_out.get("same_identity_rerun_permitted") is False,
        "R10D_HELD_OUT_STATUS",
    )
    population = r05e.get("population")
    outcome = r05e.get("outcome")
    claim = r05e.get("claim_boundary")
    require(
        isinstance(population, dict)
        and isinstance(outcome, dict)
        and isinstance(claim, dict),
        "R05E_STRUCTURE",
    )
    selected = [
        item
        for item in population.get("frozen_cells", [])
        if isinstance(item, dict) and item.get("generator_index") == 225
    ]
    require(
        len(selected) == 1
        and selected[0].get("morphology_id")
        == "qsdk_r05e_axis_star_foot_radius_low_s225"
        and population.get("campaign_seeds") == [40101, 40102, 40103]
        and outcome.get("walking_gate_receipt_count") == 972
        and outcome.get("false_walking_gate_receipt_count") == 0
        and claim.get("external_push_recovery") is False,
        "R05E_GENERATOR_225_SUPPORT",
    )
    refusal_boundary = supervisor_refusal.get("execution_boundary")
    refusal_successor = supervisor_refusal.get("successor_policy")
    refusal_claim = supervisor_refusal.get("claim_boundary")
    require(
        supervisor_refusal.get("schema_version")
        == "sporespore_qsdk_r10e_physical_supervisor_refusal_v1"
        and supervisor_refusal.get("status")
        == "closed_infrastructure_invalid_pre_physics_output_identity_unconsumed"
        and supervisor_refusal.get("gate_id") == "QSDK-R10E"
        and supervisor_refusal.get("repair_id") == "QSDK-R10E-L2"
        and supervisor_refusal.get("campaign_role") == "development_route_ghost"
        and isinstance(refusal_boundary, dict)
        and refusal_boundary.get("physical_supervisor_invocation_count") == 1
        and refusal_boundary.get("durable_evidence_directory_created") is False
        and refusal_boundary.get("model_construction_count") == 0
        and refusal_boundary.get("world_attempt_count") == 0
        and refusal_boundary.get("world_build_count") == 0
        and refusal_boundary.get("native_readback_count") == 0
        and refusal_boundary.get("solver_step_count") == 0
        and refusal_boundary.get("locomotion_outcome_exposure_count") == 0
        and refusal_boundary.get("physics_state_modified") is False
        and refusal_boundary.get("physical_attempt_identity_consumed") is False
        and isinstance(refusal_successor, dict)
        and refusal_successor.get("repeat_failed_supervisor_invocation") is False
        and refusal_successor.get("new_clean_pushed_source_required") is True
        and refusal_successor.get("new_official_zero_world_qualification_required")
        is True
        and refusal_successor.get("new_stage_freeze_required") is True
        and refusal_successor.get("new_execution_authority_required") is True
        and isinstance(refusal_claim, dict)
        and refusal_claim.get("bounded_upright_push_recovery_claimed") is False
        and refusal_claim.get("physical_acceptance_authority") is False
        and refusal_claim.get("release_authority") is False,
        "R10E_SUPERVISOR_REFUSAL_BOUNDARY",
    )
    l2_outcome = l2_failure.get("outcome")
    l2_successor = l2_failure.get("successor_policy")
    l2_decision = l2_failure.get("decision")
    require(
        l2_failure.get("schema_version")
        == "sporespore_qsdk_r10e_l2_held_out_finite_decision_physical_failure_closure_v1"
        and l2_failure.get("status")
        == "closed_consumed_invalid_or_incomplete_no_finite_decision"
        and l2_failure.get("gate_id") == "QSDK-R10E"
        and l2_failure.get("repair_id") == "QSDK-R10E-L2"
        and l2_failure.get("campaign_role") == "held_out_finite_decision"
        and isinstance(l2_outcome, dict)
        and l2_outcome.get("declared_world_count") == 6
        and l2_outcome.get("world_attempt_count") == 2
        and l2_outcome.get("world_build_count") == 2
        and l2_outcome.get("remaining_unattempted_world_count") == 4
        and l2_outcome.get("route_execution_valid") is False
        and l2_outcome.get("outcome_complete") is False
        and l2_outcome.get("behavioral_conclusion_available") is False
        and l2_outcome.get("behavior_passed") is None
        and l2_outcome.get("physical_identity_consumed") is True
        and l2_outcome.get("same_identity_rerun_permitted") is False
        and isinstance(l2_successor, dict)
        and l2_successor.get("successor_repair_id") == "QSDK-R10E-L3"
        and l2_successor.get("new_complete_six_world_identity_required") is True
        and l2_successor.get(
            "retained_l2_outcome_may_select_tolerance_or_behavior_threshold"
        )
        is False
        and isinstance(l2_decision, dict)
        and l2_decision.get("external_push_recovery_claimed") is False
        and l2_decision.get("new_physical_work_authorized_by_this_closure") is False,
        "R10E_L2_HELD_OUT_FAILURE_BOUNDARY",
    )
    design_binding = committed_file_binding(
        "sdk/qsdk_r10e_observer_minimized_upright_push_recovery_successor_design_v1.json",
        source_commit,
    )
    design_binding["status"] = design["status"]
    development_binding = committed_file_binding(
        "sdk/qsdk_r10d_l1_development_route_ghost_physical_closure_v1.json",
        source_commit,
    )
    development_binding.update(
        {
            "status": development["status"],
            "route_execution_valid": True,
            "physical_identity_consumed": True,
            "same_identity_rerun_permitted": False,
        }
    )
    held_binding = committed_file_binding(
        "sdk/qsdk_r10d_l1_held_out_finite_decision_physical_closure_v1.json",
        source_commit,
    )
    held_binding.update(
        {
            "status": held_out["status"],
            "route_execution_valid": False,
            "physical_identity_consumed": True,
            "same_identity_rerun_permitted": False,
        }
    )
    support_binding = committed_file_binding(
        "sdk/qsdk_r05e_exact_finite_morphology_physical_closure_v1.json",
        source_commit,
    )
    support_binding.update(
        {
            "generator_index": 225,
            "morphology_id": "qsdk_r05e_axis_star_foot_radius_low_s225",
            "supported_campaign_seeds": [40101, 40102, 40103],
            "walking_receipt_count": 81,
            "false_walking_receipt_count": 0,
            "all_three_exact_walking_cells_passed": True,
            "r10_push_or_recovery_outcome_known": False,
        }
    )
    supervisor_refusal_binding = committed_file_binding(
        "sdk/qsdk_r10e_development_route_ghost_physical_supervisor_refusal_v1.json",
        source_commit,
    )
    supervisor_refusal_binding.update(
        {
            "status": supervisor_refusal["status"],
            "repair_id": "QSDK-R10E-L2",
            "physical_attempt_identity_consumed": False,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
        }
    )
    l2_failure_binding = committed_file_binding(
        "sdk/qsdk_r10e_l2_held_out_finite_decision_physical_failure_closure_v1.json",
        source_commit,
    )
    l2_failure_binding.update(
        {
            "status": l2_failure["status"],
            "repair_id": "QSDK-R10E-L2",
            "physical_identity_consumed": True,
            "same_identity_rerun_permitted": False,
            "behavioral_conclusion_available": False,
            "successor_repair_id": "QSDK-R10E-L3",
        }
    )
    return {
        "r10e_successor_design": design_binding,
        "consumed_r10d_development_closure": development_binding,
        "consumed_r10d_held_out_closure": held_binding,
        "r05e_generator_225_support": support_binding,
        "superseded_physical_supervisor_refusal": supervisor_refusal_binding,
        "consumed_l2_held_out_failure_closure": l2_failure_binding,
    }


def _validate_zero_counters(value: Mapping[str, Any], label: str) -> None:
    for key in (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "native_readback_count",
        "solver_step_count",
    ):
        require(value.get(key) == 0, f"{label}_{key.upper()}")
    require(value.get("physics_state_modified") is False, f"{label}_PHYSICS_STATE")
    require(
        value.get("physical_acceptance_authority") is False,
        f"{label}_PHYSICAL_ACCEPTANCE",
    )


def _binding_matches(path: Path, binding: Any, label: str) -> None:
    require(isinstance(binding, dict), f"{label}_BINDING_NOT_OBJECT")
    expected = file_identity(path, relative_to=path.parent)
    require(
        binding.get("path") == path.name
        and binding.get("byte_length") == expected["byte_length"]
        and binding.get("raw_sha256") == expected["raw_sha256"],
        f"{label}_BINDING",
    )


def _runtime_executable_identity_is_complete(value: Any) -> bool:
    return (
        isinstance(value, dict)
        and isinstance(value.get("path"), str)
        and bool(value.get("path"))
        and is_prefixed_sha256(value.get("raw_sha256"))
        and type(value.get("byte_length")) is int
        and value.get("byte_length") > 0
        and isinstance(value.get("version"), str)
        and bool(value.get("version"))
    )


def validate_qualification(
    directory: Path, source_commit: str, role: str
) -> dict[str, Any]:
    spec = role_spec(role)
    require(
        spec["materialization_permitted"] is True,
        "HISTORICAL_ROLE_REQUALIFICATION_FORBIDDEN",
    )
    directory = directory.resolve()
    evidence_root = EVIDENCE_ROOT.resolve()
    try:
        relative_directory = directory.relative_to(evidence_root)
    except ValueError as exc:
        raise MaterializationFailure(
            "QUALIFICATION_DIRECTORY_OUTSIDE_EVIDENCE_ROOT"
        ) from exc
    require(relative_directory.parts, "QUALIFICATION_DIRECTORY_IS_EVIDENCE_ROOT")
    expected_directory = (
        evidence_root
        / (
            f"qsdk-r10e-{spec['physical_output_slug']}-zero-world-qualification-"
            f"{source_commit[:12]}"
        )
    ).resolve()
    require(directory == expected_directory, "QUALIFICATION_DIRECTORY_IDENTITY")
    require(directory.is_dir(), "QUALIFICATION_DIRECTORY")
    directory_text = str(directory).replace("\\", "/")
    expected_scope = ledger_scope(
        str(spec["question_class"]), "official_zero_world_qualification"
    )
    expected_tree = git(("rev-parse", f"{source_commit}^{{tree}}"))
    attempt_path = directory / "qualification_attempt.json"
    implementation_path = directory / "implementation_audit.json"
    runtime_path = directory / "runtime_identity.json"
    completion_path = directory / "qualification_completion.json"
    attempt = read_json(attempt_path, "QUALIFICATION_ATTEMPT")
    implementation = read_json(implementation_path, "IMPLEMENTATION_AUDIT")
    runtime = read_json(runtime_path, "RUNTIME_IDENTITY")
    completion = read_json(completion_path, "QUALIFICATION_COMPLETION")
    require(
        attempt.get("schema_version") == spec["qualification_attempt_schema"]
        and attempt.get("status")
        == "started_consumed_official_zero_world_qualification"
        and attempt.get("gate_id") == "QSDK-R10E"
        and attempt.get("repair_id") == spec["repair_id"]
        and attempt.get("campaign_id") == spec["campaign_id"]
        and attempt.get("campaign_role") == role
        and attempt.get("question_class") == spec["question_class"]
        and attempt.get("ledger_scope") == expected_scope
        and attempt.get("source_commit") == source_commit
        and isinstance(attempt.get("source"), dict)
        and attempt["source"].get("commit") == source_commit
        and attempt["source"].get("tree") == expected_tree
        and attempt.get("output_root") == directory_text
        and attempt.get("qualified_source_path_count") == EXPECTED_SOURCE_COUNT
        and attempt.get("qualified_source_path_sha256") == EXPECTED_SOURCE_PATH_SHA256
        and attempt.get("superseded_physical_supervisor_refusal_sha256")
        == EXPECTED_SUPERVISOR_REFUSAL_SHA256
        and attempt.get("l2_held_out_failure_closure_sha256")
        == EXPECTED_L2_HELD_OUT_FAILURE_SHA256
        and attempt.get(
            "maximum_official_qualification_attempt_count_for_source_and_role"
        )
        == 1
        and attempt.get("same_identity_rerun_permitted") is False
        and attempt.get("physical_execution_authorized") is False,
        "QUALIFICATION_ATTEMPT_FIELDS",
    )
    require(
        implementation.get("schema_version") == IMPLEMENTATION_AUDIT_SCHEMA
        and implementation.get("status")
        == "closed_passing_official_zero_world_qualification"
        and implementation.get("source_commit") == source_commit
        and implementation.get("source_tree") == expected_tree
        and implementation.get("repair_id") == spec["repair_id"]
        and implementation.get("official_qualification") is True
        and implementation.get("qualified_source_path_count") == EXPECTED_SOURCE_COUNT
        and implementation.get("qualified_source_path_sha256")
        == EXPECTED_SOURCE_PATH_SHA256,
        "IMPLEMENTATION_AUDIT_FIELDS",
    )
    require(
        runtime.get("schema_version") == RUNTIME_IDENTITY_SCHEMA
        and runtime.get("gate_id") == "QSDK-R10E"
        and runtime.get("source_commit") == source_commit
        and runtime.get("qualified_source_path_count") == EXPECTED_SOURCE_COUNT
        and runtime.get("qualified_source_path_sha256") == EXPECTED_SOURCE_PATH_SHA256
        and _runtime_executable_identity_is_complete(runtime.get("godot_console"))
        and _runtime_executable_identity_is_complete(runtime.get("python"))
        and _runtime_executable_identity_is_complete(runtime.get("powershell"))
        and runtime.get("python_version") == runtime["python"].get("version")
        and runtime.get("powershell_version") == runtime["powershell"].get("version")
        and isinstance(runtime.get("active_adapter"), dict)
        and runtime["active_adapter"].get("path")
        == "sdk/target/debug/sporespore_godot_adapter.dll"
        and is_prefixed_sha256(runtime["active_adapter"].get("raw_sha256"))
        and type(runtime["active_adapter"].get("byte_length")) is int
        and runtime["active_adapter"].get("byte_length") > 0
        and runtime.get("active_adapter_raw_sha256")
        == runtime["active_adapter"].get("raw_sha256")
        and implementation.get("runtime_identity") == runtime
        and implementation.get("runtime_identity_sha256")
        == sha256_bytes(
            json.dumps(runtime, sort_keys=True, separators=(",", ":")).encode("utf-8")
        )
        and runtime.get("runtime_identity_complete") is True,
        "RUNTIME_IDENTITY_FIELDS",
    )
    require(
        completion.get("schema_version") == spec["qualification_completion_schema"]
        and completion.get("status")
        == "closed_passing_official_zero_world_qualification"
        and completion.get("gate_id") == "QSDK-R10E"
        and completion.get("repair_id") == spec["repair_id"]
        and completion.get("campaign_id") == spec["campaign_id"]
        and completion.get("campaign_role") == role
        and completion.get("question_class") == spec["question_class"]
        and completion.get("ledger_scope") == expected_scope
        and completion.get("source_commit") == source_commit
        and completion.get("source_tree") == expected_tree
        and completion.get("qualification_root") == directory_text
        and completion.get("qualified_source_path_count") == EXPECTED_SOURCE_COUNT
        and completion.get("qualified_source_path_sha256")
        == EXPECTED_SOURCE_PATH_SHA256
        and completion.get("superseded_physical_supervisor_refusal_sha256")
        == EXPECTED_SUPERVISOR_REFUSAL_SHA256
        and completion.get("l2_held_out_failure_closure_sha256")
        == EXPECTED_L2_HELD_OUT_FAILURE_SHA256
        and completion.get("official_zero_world_qualification_passed") is True
        and completion.get("source_unchanged_during_qualification") is True
        and completion.get("operation_lock_serialization_passed") is True
        and completion.get("ordered_future_cell_ids") == spec["ordered_cell_ids"]
        and completion.get("maximum_future_world_count")
        == len(spec["ordered_cell_ids"])
        and completion.get("maximum_future_campaign_attempt_count") == 1
        and completion.get("physical_execution_authorized") is False
        and completion.get("same_identity_rerun_permitted") is False,
        "QUALIFICATION_COMPLETION_FIELDS",
    )
    for value, label in (
        (attempt, "QUALIFICATION_ATTEMPT"),
        (implementation, "IMPLEMENTATION_AUDIT"),
        (completion, "QUALIFICATION_COMPLETION"),
    ):
        _validate_zero_counters(value, label)
    _binding_matches(attempt_path, completion.get("qualification_attempt"), "ATTEMPT")
    _binding_matches(
        implementation_path,
        completion.get("implementation_audit"),
        "IMPLEMENTATION",
    )
    _binding_matches(runtime_path, completion.get("runtime_identity"), "RUNTIME")
    return {
        "completion_path": completion_path,
        "completion": completion,
        # The stage freeze is committed in the repository but the retained
        # qualification lives outside it.  Preserve an absolute path so the
        # later supervisor cannot reinterpret it relative to its own cwd.
        "completion_binding": file_identity(completion_path),
        "runtime": runtime,
    }


def development_prerequisite(role: str, source_commit: str) -> dict[str, Any] | None:
    if role == "development_route_ghost":
        return None
    require(R10E_DEVELOPMENT_CLOSURE_PATH.is_file(), "DEVELOPMENT_CLOSURE_MISSING")
    closure = read_json(R10E_DEVELOPMENT_CLOSURE_PATH, "DEVELOPMENT_CLOSURE")
    require(
        closure.get("status")
        in {
            "closed_execution_valid_complete_behavior_positive",
            "closed_execution_valid_complete_behavior_finite_negative",
        }
        and closure.get("route_execution_valid") is True
        and closure.get("evidence_valid") is True
        and closure.get("outcome_complete") is True
        and closure.get("physical_identity_consumed") is True
        and closure.get("same_identity_rerun_permitted") is False,
        "DEVELOPMENT_CLOSURE_NOT_ELIGIBLE",
    )
    binding = committed_file_binding(
        "sdk/qsdk_r10e_development_route_ghost_physical_closure_v2.json",
        source_commit,
    )
    return {
        **binding,
        "route_execution_valid": True,
        "physical_identity_consumed": True,
        "same_identity_rerun_permitted": False,
        "physical_closure_sha256": binding["raw_sha256"],
    }


def build_stage_freeze(
    role: str,
    source_commit: str,
    qualification: Mapping[str, Any],
    histories: Mapping[str, Mapping[str, Any]],
    prerequisite: Mapping[str, Any] | None,
) -> dict[str, Any]:
    spec = role_spec(role)
    return {
        "schema_version": spec["stage_schema"],
        "status": "closed_passing_official_zero_world_qualification",
        "gate_id": "QSDK-R10E",
        "repair_id": spec["repair_id"],
        "campaign_id": spec["campaign_id"],
        "campaign_role": role,
        "question_class": spec["question_class"],
        "ledger_scope": ledger_scope(
            str(spec["question_class"]), "official_zero_world_qualification"
        ),
        "source_commit": source_commit,
        "qualification_parent_commit": source_commit,
        "qualified_source_path_count": EXPECTED_SOURCE_COUNT,
        "qualified_source_path_sha256": EXPECTED_SOURCE_PATH_SHA256,
        "r10e_design_sha256": EXPECTED_DESIGN_SHA256,
        "r10d_development_closure_sha256": EXPECTED_R10D_DEVELOPMENT_SHA256,
        "r10d_held_out_closure_sha256": EXPECTED_R10D_HELD_OUT_SHA256,
        "r05e_physical_closure_sha256": EXPECTED_R05E_SHA256,
        "ordered_cell_ids": list(spec["ordered_cell_ids"]),
        "maximum_world_count": len(spec["ordered_cell_ids"]),
        "maximum_campaign_attempt_count": 1,
        "official_zero_world_qualification_passed": True,
        "physical_execution_authorized_by_freeze": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
        "qualification_completion": dict(qualification),
        "prerequisite_development_route_ghost": (
            dict(prerequisite) if prerequisite is not None else None
        ),
        "r10e_successor_design": dict(histories["r10e_successor_design"]),
        "consumed_r10d_development_closure": dict(
            histories["consumed_r10d_development_closure"]
        ),
        "consumed_r10d_held_out_closure": dict(
            histories["consumed_r10d_held_out_closure"]
        ),
        "r05e_generator_225_support": dict(histories["r05e_generator_225_support"]),
        "superseded_physical_supervisor_refusal": dict(
            histories["superseded_physical_supervisor_refusal"]
        ),
        "consumed_l2_held_out_failure_closure": dict(
            histories["consumed_l2_held_out_failure_closure"]
        ),
    }


def validate_stage_freeze(
    value: Mapping[str, Any], role: str, source_commit: str
) -> None:
    spec = role_spec(role)
    require(
        value.get("schema_version") == spec["stage_schema"]
        and value.get("status") == "closed_passing_official_zero_world_qualification"
        and value.get("gate_id") == "QSDK-R10E"
        and value.get("repair_id") == spec["repair_id"]
        and value.get("campaign_id") == spec["campaign_id"]
        and value.get("campaign_role") == role
        and value.get("question_class") == spec["question_class"]
        and value.get("ledger_scope")
        == ledger_scope(
            str(spec["question_class"]), "official_zero_world_qualification"
        )
        and value.get("source_commit") == source_commit
        and value.get("qualification_parent_commit") == source_commit
        and value.get("qualified_source_path_count") == EXPECTED_SOURCE_COUNT
        and value.get("qualified_source_path_sha256") == EXPECTED_SOURCE_PATH_SHA256
        and value.get("r10e_design_sha256") == EXPECTED_DESIGN_SHA256
        and value.get("r10d_development_closure_sha256")
        == EXPECTED_R10D_DEVELOPMENT_SHA256
        and value.get("r10d_held_out_closure_sha256") == EXPECTED_R10D_HELD_OUT_SHA256
        and value.get("r05e_physical_closure_sha256") == EXPECTED_R05E_SHA256
        and value.get("ordered_cell_ids") == spec["ordered_cell_ids"]
        and value.get("maximum_world_count") == len(spec["ordered_cell_ids"])
        and value.get("maximum_campaign_attempt_count") == 1
        and value.get("official_zero_world_qualification_passed") is True
        and value.get("physical_execution_authorized_by_freeze") is False
        and value.get("physical_acceptance_authority") is False
        and value.get("release_authority") is False,
        "STAGE_FREEZE_FIELDS",
    )
    histories = (
        value.get("r10e_successor_design"),
        value.get("consumed_r10d_development_closure"),
        value.get("consumed_r10d_held_out_closure"),
        value.get("r05e_generator_225_support"),
        value.get("superseded_physical_supervisor_refusal"),
        value.get("consumed_l2_held_out_failure_closure"),
    )
    require(all(isinstance(item, dict) for item in histories), "STAGE_HISTORY_BINDINGS")
    supervisor_refusal = value["superseded_physical_supervisor_refusal"]
    require(
        supervisor_refusal.get("raw_sha256") == EXPECTED_SUPERVISOR_REFUSAL_SHA256
        and supervisor_refusal.get("status")
        == "closed_infrastructure_invalid_pre_physics_output_identity_unconsumed"
        and supervisor_refusal.get("repair_id") == "QSDK-R10E-L2"
        and supervisor_refusal.get("physical_attempt_identity_consumed") is False
        and supervisor_refusal.get("world_attempt_count") == 0
        and supervisor_refusal.get("world_build_count") == 0
        and supervisor_refusal.get("solver_step_count") == 0,
        "STAGE_SUPERVISOR_REFUSAL_BINDING",
    )
    l2_failure = value["consumed_l2_held_out_failure_closure"]
    require(
        l2_failure.get("raw_sha256") == EXPECTED_L2_HELD_OUT_FAILURE_SHA256
        and l2_failure.get("status")
        == "closed_consumed_invalid_or_incomplete_no_finite_decision"
        and l2_failure.get("repair_id") == "QSDK-R10E-L2"
        and l2_failure.get("physical_identity_consumed") is True
        and l2_failure.get("same_identity_rerun_permitted") is False
        and l2_failure.get("behavioral_conclusion_available") is False
        and l2_failure.get("successor_repair_id") == "QSDK-R10E-L3",
        "STAGE_L2_HELD_OUT_FAILURE_BINDING",
    )
    if role == "development_route_ghost":
        require(
            value.get("prerequisite_development_route_ghost") is None,
            "STAGE_UNEXPECTED_PREREQUISITE",
        )
    else:
        prerequisite = value.get("prerequisite_development_route_ghost")
        require(
            isinstance(prerequisite, dict)
            and prerequisite.get("route_execution_valid") is True
            and prerequisite.get("physical_identity_consumed") is True
            and prerequisite.get("same_identity_rerun_permitted") is False
            and is_prefixed_sha256(prerequisite.get("physical_closure_sha256")),
            "STAGE_PREREQUISITE",
        )


def build_execution_authority(
    role: str,
    stage_commit: str,
    stage_sha256: str,
    source_commit: str,
    output_root: Path,
) -> dict[str, Any]:
    spec = role_spec(role)
    return {
        "schema_version": spec["authority_schema"],
        "status": "authorized_single_use_unconsumed",
        "gate_id": "QSDK-R10E",
        "repair_id": spec["repair_id"],
        "campaign_id": spec["campaign_id"],
        "campaign_role": role,
        "question_class": spec["question_class"],
        "ledger_scope": ledger_scope(
            str(spec["question_class"]), "single_use_physical_execution_authority"
        ),
        "authorization_commit_derived_from_current_head": True,
        "authorization_parent_commit": stage_commit,
        "qualification_parent_commit": source_commit,
        "source_commit": source_commit,
        "qualification_closure_path": spec["stage_path"],
        "stage_freeze_sha256": stage_sha256,
        "r10e_design_sha256": EXPECTED_DESIGN_SHA256,
        "r10d_development_closure_sha256": EXPECTED_R10D_DEVELOPMENT_SHA256,
        "r10d_held_out_closure_sha256": EXPECTED_R10D_HELD_OUT_SHA256,
        "r05e_physical_closure_sha256": EXPECTED_R05E_SHA256,
        "superseded_physical_supervisor_refusal_sha256": (
            EXPECTED_SUPERVISOR_REFUSAL_SHA256
        ),
        "l2_held_out_failure_closure_sha256": EXPECTED_L2_HELD_OUT_FAILURE_SHA256,
        "qualified_source_path_count": EXPECTED_SOURCE_COUNT,
        "qualified_source_path_sha256": EXPECTED_SOURCE_PATH_SHA256,
        "ordered_cell_ids": list(spec["ordered_cell_ids"]),
        "maximum_world_count": len(spec["ordered_cell_ids"]),
        "maximum_campaign_attempt_count": 1,
        "output_root": str(output_root),
        "zero_world_qualification_passed": True,
        "physical_execution_authorized": True,
        "physical_identity_consumed": False,
        "same_identity_rerun_permitted": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def validate_execution_authority(
    value: Mapping[str, Any],
    role: str,
    stage_commit: str,
    stage_sha256: str,
    source_commit: str,
    output_root: Path,
) -> None:
    spec = role_spec(role)
    require(
        value.get("schema_version") == spec["authority_schema"]
        and value.get("status") == "authorized_single_use_unconsumed"
        and value.get("gate_id") == "QSDK-R10E"
        and value.get("repair_id") == spec["repair_id"]
        and value.get("campaign_id") == spec["campaign_id"]
        and value.get("campaign_role") == role
        and value.get("question_class") == spec["question_class"]
        and value.get("ledger_scope")
        == ledger_scope(
            str(spec["question_class"]), "single_use_physical_execution_authority"
        )
        and value.get("authorization_commit_derived_from_current_head") is True
        and value.get("authorization_parent_commit") == stage_commit
        and value.get("qualification_parent_commit") == source_commit
        and value.get("source_commit") == source_commit
        and value.get("qualification_closure_path") == spec["stage_path"]
        and value.get("stage_freeze_sha256") == stage_sha256
        and value.get("superseded_physical_supervisor_refusal_sha256")
        == EXPECTED_SUPERVISOR_REFUSAL_SHA256
        and value.get("l2_held_out_failure_closure_sha256")
        == EXPECTED_L2_HELD_OUT_FAILURE_SHA256
        and value.get("qualified_source_path_count") == EXPECTED_SOURCE_COUNT
        and value.get("qualified_source_path_sha256") == EXPECTED_SOURCE_PATH_SHA256
        and value.get("ordered_cell_ids") == spec["ordered_cell_ids"]
        and value.get("maximum_world_count") == len(spec["ordered_cell_ids"])
        and value.get("maximum_campaign_attempt_count") == 1
        and Path(str(value.get("output_root", ""))).resolve() == output_root.resolve()
        and value.get("zero_world_qualification_passed") is True
        and value.get("physical_execution_authorized") is True
        and value.get("physical_identity_consumed") is False
        and value.get("same_identity_rerun_permitted") is False
        and value.get("physical_acceptance_authority") is False
        and value.get("release_authority") is False,
        "EXECUTION_AUTHORITY_FIELDS",
    )


def write_new_json(path: Path, value: Mapping[str, Any]) -> None:
    require(not path.exists(), f"OUTPUT_ALREADY_EXISTS:{path}")
    path.parent.mkdir(parents=True, exist_ok=True)
    encoded = (json.dumps(value, indent=2, ensure_ascii=False) + "\n").encode("utf-8")
    path.write_bytes(encoded)


def materialize_stage(arguments: argparse.Namespace) -> dict[str, Any]:
    identity = live_source_identity()
    source_commit = str(identity["commit"])
    spec = role_spec(arguments.campaign_role)
    require(
        spec["materialization_permitted"] is True,
        "HISTORICAL_ROLE_MATERIALIZATION_FORBIDDEN",
    )
    require(
        not arguments.source_commit or arguments.source_commit == source_commit,
        "SOURCE_COMMIT_ARGUMENT",
    )
    dependency_receipt()
    qualification = validate_qualification(
        arguments.qualification_dir.resolve(), source_commit, arguments.campaign_role
    )
    histories = historical_bindings(source_commit)
    prerequisite = development_prerequisite(arguments.campaign_role, source_commit)
    freeze = build_stage_freeze(
        arguments.campaign_role,
        source_commit,
        qualification["completion_binding"],
        histories,
        prerequisite,
    )
    validate_stage_freeze(freeze, arguments.campaign_role, source_commit)
    spec = role_spec(arguments.campaign_role)
    output = ROOT / str(spec["stage_path"])
    write_new_json(output, freeze)
    return {
        "mode": "stage-freeze",
        "campaign_role": arguments.campaign_role,
        "output_identity": file_identity(output, relative_to=ROOT),
        "source_commit": source_commit,
        "physical_execution_authorized": False,
    }


def materialize_authority(arguments: argparse.Namespace) -> dict[str, Any]:
    identity = live_source_identity()
    stage_commit = str(identity["commit"])
    spec = role_spec(arguments.campaign_role)
    require(
        spec["materialization_permitted"] is True,
        "HISTORICAL_ROLE_MATERIALIZATION_FORBIDDEN",
    )
    stage_relative = str(spec["stage_path"])
    changed = git(
        (
            "diff-tree",
            "--no-commit-id",
            "--name-only",
            "--no-renames",
            "-r",
            stage_commit,
        )
    ).splitlines()
    require(changed == [stage_relative], "STAGE_COMMIT_NOT_SINGLE_PATH")
    stage_path = ROOT / stage_relative
    freeze = read_json(stage_path, "STAGE_FREEZE")
    source_commit = str(freeze.get("source_commit", ""))
    require(is_commit(source_commit), "STAGE_SOURCE_COMMIT")
    require(git(("rev-parse", "HEAD^")) == source_commit, "STAGE_PARENT_NOT_SOURCE")
    validate_stage_freeze(freeze, arguments.campaign_role, source_commit)
    require(
        not arguments.source_commit or arguments.source_commit == source_commit,
        "SOURCE_COMMIT_ARGUMENT",
    )
    evidence_root = arguments.evidence_root.resolve()
    require(evidence_root == EVIDENCE_ROOT.resolve(), "WRONG_EVIDENCE_ROOT")
    output_root = (
        evidence_root
        / f"qsdk-r10e-{spec['physical_output_slug']}-physical-{source_commit[:12]}"
    )
    require(not output_root.exists(), "PHYSICAL_OUTPUT_IDENTITY_ALREADY_CONSUMED")
    authority = build_execution_authority(
        arguments.campaign_role,
        stage_commit,
        sha256_file(stage_path),
        source_commit,
        output_root,
    )
    validate_execution_authority(
        authority,
        arguments.campaign_role,
        stage_commit,
        sha256_file(stage_path),
        source_commit,
        output_root,
    )
    authority_path = ROOT / str(spec["authority_path"])
    write_new_json(authority_path, authority)
    return {
        "mode": "execution-authority",
        "campaign_role": arguments.campaign_role,
        "output_identity": file_identity(authority_path, relative_to=ROOT),
        "source_commit": source_commit,
        "authorization_parent_commit": stage_commit,
        "physical_output_root": str(output_root),
        "physical_execution_authorized_after_authority_only_commit": True,
    }


def self_test() -> dict[str, Any]:
    require(STAGE_FREEZE_SCHEMA != EXECUTION_AUTHORITY_SCHEMA, "SCHEMA_COLLISION")
    require(
        set(ROLE_SPECS) == {"development_route_ghost", "held_out_finite_decision"},
        "ROLES",
    )
    require(
        ROLE_SPECS["development_route_ghost"]["ordered_cell_ids"]
        == ["baseline_s40002", "push_s40002"],
        "DEVELOPMENT_ORDER",
    )
    require(
        ROLE_SPECS["held_out_finite_decision"]["ordered_cell_ids"]
        == [
            "baseline_s40101",
            "push_s40101",
            "baseline_s40102",
            "push_s40102",
            "baseline_s40103",
            "push_s40103",
        ],
        "HELD_OUT_ORDER",
    )
    require(
        EXPECTED_SOURCE_COUNT == 0
        and EXPECTED_SOURCE_PATH_SHA256 == ""
        or EXPECTED_SOURCE_COUNT > 0
        and is_prefixed_sha256(EXPECTED_SOURCE_PATH_SHA256),
        "SOURCE_BINDING_SENTINEL",
    )
    source = "1" * 40
    stage = "2" * 40
    stage_sha = "sha256:" + "3" * 64
    output = EVIDENCE_ROOT / "self-test-never-created"
    authority_valid_count = 0
    authority_mutation_rejection_count = 0
    for role in ("held_out_finite_decision",):
        authority = build_execution_authority(role, stage, stage_sha, source, output)
        validate_execution_authority(authority, role, stage, stage_sha, source, output)
        authority_valid_count += 1
        mutations = (
            ("status", "consumed"),
            ("repair_id", "QSDK-R10E-L1"),
            ("authorization_parent_commit", "9" * 40),
            ("stage_freeze_sha256", "sha256:" + "9" * 64),
            (
                "superseded_physical_supervisor_refusal_sha256",
                "sha256:" + "9" * 64,
            ),
            ("l2_held_out_failure_closure_sha256", "sha256:" + "9" * 64),
            ("physical_execution_authorized", False),
            ("physical_identity_consumed", True),
            ("same_identity_rerun_permitted", True),
            ("maximum_campaign_attempt_count", 2),
            ("ordered_cell_ids", []),
        )
        for key, changed in mutations:
            mutation = json.loads(json.dumps(authority))
            mutation[key] = changed
            try:
                validate_execution_authority(
                    mutation, role, stage, stage_sha, source, output
                )
            except MaterializationFailure:
                authority_mutation_rejection_count += 1
    require(authority_valid_count == 1, "SELF_TEST_VALID_COUNT")
    require(authority_mutation_rejection_count == 11, "SELF_TEST_MUTATION_COUNT")
    return {
        "schema_version": "sporespore_qsdk_r10e_authority_materializer_self_test_v1",
        "gate_id": "QSDK-R10E",
        "ledger_scope": ledger_scope(
            "development", "zero_world_authority_materializer_self_test"
        ),
        "ok": True,
        "failure_code": "",
        "source_binding_finalized": EXPECTED_SOURCE_COUNT > 0,
        "authority_valid_control_count": authority_valid_count,
        "authority_mutation_rejection_count": authority_mutation_rejection_count,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "native_readback_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("self-test")
    for command in ("stage", "authority"):
        subparser = subparsers.add_parser(command)
        subparser.add_argument(
            "--campaign-role", required=True, choices=sorted(ROLE_SPECS)
        )
        subparser.add_argument("--source-commit", default="")
        if command == "stage":
            subparser.add_argument("--qualification-dir", required=True, type=Path)
        else:
            subparser.add_argument("--evidence-root", type=Path, default=EVIDENCE_ROOT)
    arguments = parser.parse_args()
    try:
        if arguments.command == "self-test":
            result = self_test()
            print(
                SELF_TEST_MARKER
                + json.dumps(result, sort_keys=True, separators=(",", ":"))
            )
            return 0
        if arguments.command == "stage":
            result = materialize_stage(arguments)
        else:
            result = materialize_authority(arguments)
    except MaterializationFailure as exc:
        print(f"QSDK_R10E_AUTHORITY_MATERIALIZER_FAIL {exc}", file=sys.stderr)
        return 1
    print(
        MATERIALIZED_MARKER + json.dumps(result, sort_keys=True, separators=(",", ":"))
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
