#!/usr/bin/env python3
"""Audit the complete QSDK-R10D implementation without constructing a world."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from typing import Any, Iterable, Mapping


ROOT = Path(__file__).resolve().parents[2]
EXPECTED_ROOT = Path(r"C:\Users\Cole\CodeStuff\games\SporeSpore")
EXPECTED_REMOTE = "https://github.com/Slagathore/sporespore.git"
DEFAULT_GODOT = Path(
    r"C:\Users\Cole\CodeStuff\Misc\Godot" r"\Godot_v4.7-stable_mono_win64_console.exe"
)
DESIGN_PATH = (
    ROOT / "sdk/qsdk_r10c_supported_start_phase_robust_successor_design_v1.json"
)
DESIGN_AUDIT_PATH = (
    ROOT / "sdk/conformance/qsdk_r10c_supported_start_phase_robust_successor_design.py"
)
L1_DESIGN_PATH = (
    ROOT
    / "sdk/qsdk_r10d_l1_stage_freeze_numeric_normalization_successor_design_v1.json"
)
L1_DESIGN_AUDIT_PATH = (
    ROOT
    / "sdk/conformance/qsdk_r10d_l1_stage_freeze_numeric_normalization_successor_design.py"
)
L1_DIAGNOSIS_TEST = (
    "res://tests/test_sdk_qsdk_r10d_l1_retained_stage_freeze_diagnosis.gd"
)
CONSUMED_R10D_CLOSURE_PATH = (
    ROOT / "sdk/qsdk_r10d_development_route_ghost_physical_closure_v1.json"
)
R10B_CLOSURE_PATH = (
    ROOT / "sdk/qsdk_r10b_held_out_finite_decision_physical_closure_v1.json"
)
R10B_CLOSURE_AUDIT_PATH = (
    ROOT / "sdk/conformance/qsdk_r10b_held_out_finite_decision_physical_closure.py"
)
R05E_CLOSURE_PATH = (
    ROOT / "sdk/qsdk_r05e_exact_finite_morphology_physical_closure_v1.json"
)
INVALID_AUDIT_PATH = ROOT / "sdk/qsdk_r10d_zero_world_audit_invalid_v1.json"
DEPENDENCY_AUDIT_PATH = ROOT / "sdk/conformance/qsdk_r10d_dependency_closure.py"
MATERIALIZER_PATH = ROOT / "sdk/conformance/qsdk_r10d_authority_materializer.py"
PHYSICAL_CLOSURE_PATH = ROOT / "sdk/conformance/qsdk_r10d_physical_closure.py"
SUPERVISOR_PATH = (
    ROOT / "sdk/run_qsdk_r10d_supported_start_phase_robust_push_recovery.ps1"
)
QUALIFICATION_PATH = ROOT / "sdk/qsdk_r10d_zero_world_qualification.ps1"
OPERATION_LOCK_PATH = ROOT / "sdk/locomotion_operation_lock.ps1"
SOURCE_TEST = (
    "res://tests/"
    "test_sdk_qsdk_r10d_supported_start_phase_robust_push_recovery_source.gd"
)
WORKER = (
    "res://tests/"
    "test_sdk_qsdk_r10d_supported_start_phase_robust_push_recovery_worker.gd"
)
ACTIVE_ADAPTER_PATH = ROOT / "sdk/target/debug/sporespore_godot_adapter.dll"
EXPECTED_DESIGN_BYTES = 40_599
EXPECTED_DESIGN_SHA256 = (
    "sha256:2f2a4f86562e3398d69fc08510c347ed1634a2331f45ce58651db7bbb8aae4a8"
)
EXPECTED_L1_DESIGN_BYTES = 8_548
EXPECTED_L1_DESIGN_SHA256 = (
    "sha256:f98f9f057e6f583b6f0f356a983cdcbcb4d6818f217fe055edd96ddcbf326db3"
)
EXPECTED_CONSUMED_R10D_CLOSURE_BYTES = 7_196
EXPECTED_CONSUMED_R10D_CLOSURE_SHA256 = (
    "sha256:fbefa85145bcd5bb05c3672c4fe6a0b56eaf75751ae8ed5dae9ff724487b4475"
)
EXPECTED_CONSUMED_R10D_STAGE_SHA256 = (
    "sha256:e30828c9896aad6ef6f34f1c52690f60884eae3f4e708ef123c5dd888f311e04"
)
EXPECTED_CONSUMED_R10D_ATTEMPT_SHA256 = (
    "sha256:37af2f19ca2af192b0109e8e04120afbcdbd4366df99fe5e0698737916b3d280"
)
EXPECTED_R10B_CLOSURE_BYTES = 30_998
EXPECTED_R10B_CLOSURE_SHA256 = (
    "sha256:108473a00fb7d789862996b85e95ef255cc62b5e2c6037aecb556bd77dce625a"
)
EXPECTED_R05E_CLOSURE_BYTES = 49_049
EXPECTED_R05E_CLOSURE_SHA256 = (
    "sha256:dac4ac8790cd74d89da0286c36aaf541fbfe7011d2bea66077b941363d47b33e"
)
EXPECTED_QUALIFIED_SOURCE_COUNT = 88
EXPECTED_QUALIFIED_SOURCE_PATH_SHA256 = (
    "sha256:fde0b22bd6fbe0a51a07949efeb93550db16bdb580de39f192192f4d63c897e2"
)
REPAIR_ID = "QSDK-R10D-L1"
PASS_MARKER = "QSDK_R10D_ZERO_WORLD_IMPLEMENTATION_PASS "
DESIGN_MARKER = "QSDK_R10C_SUPPORTED_START_PHASE_ROBUST_SUCCESSOR_DESIGN_PASS "
L1_DESIGN_MARKER = "QSDK_R10D_L1_SUCCESSOR_DESIGN_AUDIT_PASS "
L1_DIAGNOSIS_MARKER = "QSDK_R10D_L1_RETAINED_STAGE_FREEZE_DIAGNOSIS_ZERO_WORLD "
R10B_MARKER = "QSDK_R10B_HELD_OUT_FINITE_DECISION_PHYSICAL_CLOSURE_PASS "
DEPENDENCY_MARKER = "QSDK_R10D_DEPENDENCY_CLOSURE_PASS "
MATERIALIZER_MARKER = "QSDK_R10D_AUTHORITY_MATERIALIZER_SELF_TEST_PASS "
PHYSICAL_CLOSURE_MARKER = "QSDK_R10D_PHYSICAL_CLOSURE_SELF_TEST_PASS "
SOURCE_MARKER = (
    "QSDK_R10D_SUPPORTED_START_PHASE_ROBUST_PUSH_RECOVERY_SOURCE_ZERO_WORLD "
)
CONTRACT_MARKER = "QSDK_R10D_WORKER_CONTRACT_ZERO_WORLD "
PREFLIGHT_MARKER = "QSDK_R10D_WORKER_ENTRYPOINT_ZERO_WORLD "
CELL_MARKER = "QSDK_R10D_PHYSICAL_CELL "
SUPERVISOR_MARKER = "QSDK_R10D_SUPERVISOR_ZERO_WORLD_PASS "
ZERO_COUNTERS = (
    "model_construction_count",
    "world_attempt_count",
    "world_build_count",
    "native_readback_count",
    "solver_step_count",
)
FORMATTED_GDSCRIPT_PATHS = (
    ROOT / "scripts/lab/gait/qsdk_r10d_supported_start_phase_robust_push_recovery.gd",
    ROOT
    / "tests/test_sdk_qsdk_r10d_supported_start_phase_robust_push_recovery_source.gd",
    ROOT
    / "tests/test_sdk_qsdk_r10d_supported_start_phase_robust_push_recovery_worker.gd",
    ROOT / "tests/test_sdk_qsdk_r10d_l1_retained_stage_freeze_diagnosis.gd",
)
PYTHON_PATHS = (
    ROOT / "sdk/conformance/qsdk_r10d_authority_materializer.py",
    ROOT / "sdk/conformance/qsdk_r10d_dependency_closure.py",
    L1_DESIGN_AUDIT_PATH,
    ROOT / "sdk/conformance/qsdk_r10d_physical_closure.py",
    ROOT / "sdk/conformance/qsdk_r10d_zero_world_implementation.py",
)
POWERSHELL_PATHS = (SUPERVISOR_PATH, QUALIFICATION_PATH)
EXPECTED_CONTRACTS = [
    (
        "matched_no_impulse_control",
        40001,
        "baseline_s40001",
        "sha256:dc30c7b5ac75f42cfab669f537cdeb80b08e21e833f3fde8ebd2449f9c6809f5",
        "sha256:cda3a55ea4061cb88069af21e3585ba2b4d09f05fdb647bc8c62b45c137be7ce",
    ),
    (
        "lateral_upright_impulse",
        40001,
        "push_s40001",
        "sha256:2dd4859baa9515e51c6b60850251093257cc33df3ee9a12d72de2fc0536189ce",
        "sha256:301d056c16cda0df66f28bdd7042ecb94cf71580b0ad32550ee87363ca504243",
    ),
    (
        "matched_no_impulse_control",
        40101,
        "baseline_s40101",
        "sha256:dc30c7b5ac75f42cfab669f537cdeb80b08e21e833f3fde8ebd2449f9c6809f5",
        "sha256:6e70842482a143b5ea461ec1ded0d4bc4032f2315ce9419175aa42a6c2085dfd",
    ),
    (
        "lateral_upright_impulse",
        40101,
        "push_s40101",
        "sha256:2dd4859baa9515e51c6b60850251093257cc33df3ee9a12d72de2fc0536189ce",
        "sha256:f440744d7fae25b9bad8760ecfe2aa1a89648550e67a406968c37e736a452b5b",
    ),
    (
        "matched_no_impulse_control",
        40102,
        "baseline_s40102",
        "sha256:dc30c7b5ac75f42cfab669f537cdeb80b08e21e833f3fde8ebd2449f9c6809f5",
        "sha256:781b654cf76cb1d8188bbca6c827c5b4011748b9ca7bf02e33294a7db5b8dbf7",
    ),
    (
        "lateral_upright_impulse",
        40102,
        "push_s40102",
        "sha256:2dd4859baa9515e51c6b60850251093257cc33df3ee9a12d72de2fc0536189ce",
        "sha256:269359216db6dfa8669985f629122076cc6e1bbed9e92172cf0f08850b6e7d11",
    ),
    (
        "matched_no_impulse_control",
        40103,
        "baseline_s40103",
        "sha256:dc30c7b5ac75f42cfab669f537cdeb80b08e21e833f3fde8ebd2449f9c6809f5",
        "sha256:62c1d2e6cff82a42966ae1208666d99c3dcf1ef3fe6c641518ce00db687e9b32",
    ),
    (
        "lateral_upright_impulse",
        40103,
        "push_s40103",
        "sha256:2dd4859baa9515e51c6b60850251093257cc33df3ee9a12d72de2fc0536189ce",
        "sha256:c1ecb11f6362b831ed05ebd758d9d02de0319b11041a9a6f41aa8b1aff3df88c",
    ),
]


class AuditFailure(RuntimeError):
    """The R10D implementation is not an exact zero-world authority."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AuditFailure(message)


def sha256_bytes(value: bytes) -> str:
    return "sha256:" + hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def read_json(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise AuditFailure(f"{label}: invalid UTF-8 JSON: {exc}") from exc
    require(isinstance(value, dict), f"{label}: root must be an object")
    return value


def run_process(
    arguments: Iterable[str | Path],
    *,
    timeout_seconds: int,
    environment: Mapping[str, str] | None = None,
) -> subprocess.CompletedProcess[str]:
    command = tuple(str(argument) for argument in arguments)
    try:
        return subprocess.run(
            command,
            cwd=ROOT,
            env=dict(environment) if environment is not None else None,
            check=False,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=timeout_seconds,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise AuditFailure(
            f"process failed before completion: {' '.join(command)}: {exc}"
        ) from exc


def parse_marker(stdout: str, marker: str, label: str) -> dict[str, Any]:
    matches = [
        line[len(marker) :] for line in stdout.splitlines() if line.startswith(marker)
    ]
    require(
        len(matches) == 1, f"{label}: expected exactly one {marker.strip()} receipt"
    )
    try:
        value = json.loads(matches[0])
    except json.JSONDecodeError as exc:
        raise AuditFailure(f"{label}: receipt is not JSON: {exc}") from exc
    require(isinstance(value, dict), f"{label}: receipt root must be an object")
    return value


def require_zero_world(
    receipt: Mapping[str, Any],
    label: str,
    *,
    require_ok: bool = True,
) -> None:
    if require_ok:
        require(receipt.get("ok") is True, f"{label}: receipt did not pass")
    for counter in ZERO_COUNTERS:
        require(receipt.get(counter) == 0, f"{label}: {counter} was not zero")
    require(
        receipt.get("scene_tree_insertion_count", 0) == 0,
        f"{label}: scene tree insertion count was not zero",
    )
    require(
        receipt.get("physics_state_modified") is False,
        f"{label}: physics state was modified",
    )
    require(
        receipt.get("physical_acceptance_authority") is False,
        f"{label}: physical acceptance authority was exposed",
    )


def inspect_source_boundary(*, official_qualification: bool) -> dict[str, Any]:
    commands = {
        "top": ("git", "rev-parse", "--show-toplevel"),
        "remote": ("git", "remote", "get-url", "origin"),
        "head": ("git", "rev-parse", "HEAD"),
        "origin": ("git", "rev-parse", "origin/main"),
        "branch": ("git", "branch", "--show-current"),
        "tree": ("git", "rev-parse", "HEAD^{tree}"),
        "status": ("git", "status", "--porcelain=v1", "--untracked-files=all"),
    }
    results = {
        name: run_process(command, timeout_seconds=30)
        for name, command in commands.items()
    }
    require(
        all(result.returncode == 0 for result in results.values()),
        "could not inspect the repository source boundary",
    )
    require(
        Path(results["top"].stdout.strip()).resolve() == ROOT.resolve(),
        "canonical root changed",
    )
    require(
        results["remote"].stdout.strip() == EXPECTED_REMOTE, "canonical origin changed"
    )
    head = results["head"].stdout.strip()
    origin = results["origin"].stdout.strip()
    branch = results["branch"].stdout.strip()
    clean = not results["status"].stdout.strip()
    live_equal = False
    live_commit = ""
    if official_qualification:
        live = run_process(
            ("git", "ls-remote", "origin", "refs/heads/main"),
            timeout_seconds=60,
        )
        records = [line.split() for line in live.stdout.splitlines() if line.strip()]
        require(
            live.returncode == 0
            and len(records) == 1
            and len(records[0]) == 2
            and records[0][1] == "refs/heads/main",
            "could not resolve live origin/main",
        )
        live_commit = records[0][0]
        live_equal = live_commit == head
        require(
            branch == "main" and clean and head == origin and live_equal,
            "official qualification requires clean pushed live main source",
        )
    return {
        "source_commit": head,
        "source_tree": results["tree"].stdout.strip(),
        "source_branch": branch,
        "source_clean": clean,
        "source_origin_main_equal": head == origin,
        "source_live_main_equal": live_equal,
        "source_live_main_commit": live_commit,
        "official_qualification_mode": official_qualification,
    }


def validate_bound_file(
    path: Path,
    expected_bytes: int,
    expected_sha256: str,
    label: str,
) -> dict[str, Any]:
    require(path.is_file(), f"{label} is missing")
    require(path.stat().st_size == expected_bytes, f"{label} byte length changed")
    require(sha256_file(path) == expected_sha256, f"{label} digest changed")
    return read_json(path, label)


def run_design_audit() -> dict[str, Any]:
    design = validate_bound_file(
        DESIGN_PATH,
        EXPECTED_DESIGN_BYTES,
        EXPECTED_DESIGN_SHA256,
        "R10C design",
    )
    require(
        design.get("design_id") == "QSDK-R10C-D1"
        and design.get("decision", {}).get(
            "q_sdk_r10d_zero_world_implementation_authorized"
        )
        is True
        and design.get("decision", {}).get("q_sdk_r10d_physical_execution_authorized")
        is False,
        "R10C design boundary changed",
    )
    result = run_process(
        (sys.executable, "-B", DESIGN_AUDIT_PATH),
        timeout_seconds=420,
    )
    require(
        result.returncode == 0,
        f"R10C design audit failed: {(result.stdout + result.stderr)[-4000:]}",
    )
    receipt = parse_marker(result.stdout, DESIGN_MARKER, "R10C design")
    require_zero_world(receipt, "R10C design")
    require(
        receipt.get("schema_version")
        == "sporespore_qsdk_r10c_supported_start_phase_robust_successor_design_audit_v1"
        and receipt.get("r10b_retained_trace_row_count") == 16_315
        and receipt.get("r10b_cell_marker_count") == 12
        and receipt.get("matched_pre_marker_prefix_count") == 3
        and receipt.get("one_cycle_window_ending_by_old_marker_count") == 0
        and receipt.get("two_cycle_pre_window_pass_count") == 3
        and receipt.get("two_cycle_baseline_post_window_pass_count") == 3
        and receipt.get("r10b_result_reclassified") is False
        and receipt.get("r05e_result_reclassified") is False
        and receipt.get("r10d_physical_outcome_exposed") is False,
        "R10C design audit receipt drifted",
    )
    return receipt


def validate_l1_diagnosis_receipt(receipt: dict[str, Any]) -> None:
    require_zero_world(receipt, "R10D-L1 retained diagnosis")
    checks = receipt.get("checks")
    require(isinstance(checks, dict), "R10D-L1 diagnosis checks are missing")
    require(
        receipt.get("schema_version")
        == "sporespore_qsdk_r10d_l1_retained_stage_freeze_diagnosis_v1"
        and receipt.get("gate_id") == REPAIR_ID
        and receipt.get("failure_code") == ""
        and receipt.get("consumed_predecessor_gate_id") == "QSDK-R10D"
        and receipt.get("consumed_predecessor_closure_path")
        == "sdk/qsdk_r10d_development_route_ghost_physical_closure_v1.json"
        and receipt.get("stage_raw_sha256") == EXPECTED_CONSUMED_R10D_STAGE_SHA256
        and receipt.get("attempt_raw_sha256") == EXPECTED_CONSUMED_R10D_ATTEMPT_SHA256
        and checks.get("worker_exact_stage_freeze") is True
        and checks.get("r05e_seed_array_direct_equality") is False
        and checks.get("r05e_seed_array_normalized_equality") is True
        and receipt.get("failed_checks") == ["r05e_seed_array_direct_equality"]
        and receipt.get("expected_predecessor_failure_checks")
        == ["r05e_seed_array_direct_equality"]
        and receipt.get("unexpected_failure_checks") == []
        and receipt.get("parsed_supported_seed_values") == [40101, 40102, 40103]
        and receipt.get("parsed_supported_seed_types") == ["float", "float", "float"]
        and receipt.get("normalized_supported_seed_values") == [40101, 40102, 40103]
        and receipt.get("normalization_control_count") == 10
        and receipt.get("normalization_controls_passed") is True
        and receipt.get("diagnosis_world_build_count") == 0
        and receipt.get("release_authority") is False,
        "R10D-L1 retained diagnosis receipt drifted",
    )


def run_l1_diagnosis(godot: Path) -> dict[str, Any]:
    result = run_godot(
        godot,
        ("--script", L1_DIAGNOSIS_TEST),
        label="R10D-L1 retained diagnosis",
        expect_success=True,
    )
    receipt = parse_marker(result.stdout, L1_DIAGNOSIS_MARKER, "R10D-L1 diagnosis")
    validate_l1_diagnosis_receipt(receipt)
    return receipt


def run_l1_design_audit() -> dict[str, Any]:
    design = validate_bound_file(
        L1_DESIGN_PATH,
        EXPECTED_L1_DESIGN_BYTES,
        EXPECTED_L1_DESIGN_SHA256,
        "R10D-L1 successor design",
    )
    consumed = validate_bound_file(
        CONSUMED_R10D_CLOSURE_PATH,
        EXPECTED_CONSUMED_R10D_CLOSURE_BYTES,
        EXPECTED_CONSUMED_R10D_CLOSURE_SHA256,
        "consumed R10D physical closure",
    )
    require(
        design.get("repair_id") == REPAIR_ID
        and design.get("decision", {}).get("selected_successor_id") == REPAIR_ID
        and design.get("repair_contract", {}).get("policy_logic_changed") is False
        and design.get("repair_contract", {}).get("threshold_changed") is False
        and design.get("repair_contract", {}).get("population_changed") is False
        and design.get("repair_contract", {}).get("seed_changed") is False
        and design.get("decision", {}).get("new_physical_work_authorized_now") is False
        and consumed.get("status")
        == "closed_consumed_invalid_or_incomplete_no_valid_route"
        and consumed.get("route_execution_valid") is False
        and consumed.get("behavioral_conclusion_available") is False
        and consumed.get("physical_identity_consumed") is True
        and consumed.get("same_identity_rerun_permitted") is False,
        "R10D-L1 design or consumed predecessor boundary changed",
    )
    result = run_process(
        (sys.executable, "-B", L1_DESIGN_AUDIT_PATH),
        timeout_seconds=420,
    )
    require(
        result.returncode == 0,
        f"R10D-L1 design audit failed: {(result.stdout + result.stderr)[-4000:]}",
    )
    receipt = parse_marker(result.stdout, L1_DESIGN_MARKER, "R10D-L1 design")
    require_zero_world(receipt, "R10D-L1 design")
    require(
        receipt.get("schema_version")
        == "sporespore_qsdk_r10d_l1_successor_design_audit_v1"
        and receipt.get("gate_id") == REPAIR_ID
        and receipt.get("selected_successor_id") == REPAIR_ID
        and receipt.get("design_byte_length") == EXPECTED_L1_DESIGN_BYTES
        and receipt.get("design_raw_sha256") == EXPECTED_L1_DESIGN_SHA256
        and receipt.get("predecessor_physical_identity_consumed") is True
        and receipt.get("predecessor_same_identity_rerun_permitted") is False
        and receipt.get("predecessor_worker_world_build_count") == 0
        and receipt.get("predecessor_report_world_build_count_known") is False
        and receipt.get("predecessor_behavioral_conclusion_available") is False
        and receipt.get("parsed_seed_numeric_type") == "float"
        and receipt.get("exact_integer_normalization_passed") is True
        and receipt.get("normalization_control_count") == 10
        and receipt.get("design_and_diagnosis_mutation_control_count") == 10
        and receipt.get("policy_logic_changed") is False
        and receipt.get("threshold_changed") is False
        and receipt.get("population_changed") is False
        and receipt.get("seed_changed") is False
        and receipt.get("outcome_derived_correction") is False
        and receipt.get("new_physical_work_authorized") is False
        and receipt.get("held_out_work_authorized") is False
        and receipt.get("sdk1_completed_steps") == 13
        and receipt.get("release_authority") is False,
        "R10D-L1 design audit receipt drifted",
    )
    return receipt


def run_r10b_closure_audit() -> dict[str, Any]:
    closure = validate_bound_file(
        R10B_CLOSURE_PATH,
        EXPECTED_R10B_CLOSURE_BYTES,
        EXPECTED_R10B_CLOSURE_SHA256,
        "R10B held-out closure",
    )
    require(
        closure.get("status") == "closed_consumed_valid_complete_finite_negative"
        and closure.get("physical_identity_consumed") is True
        and closure.get("same_identity_rerun_permitted") is False
        and closure.get("decision", {}).get(
            "bounded_upright_push_recovery_acceptance_established"
        )
        is False,
        "R10B consumed result boundary changed",
    )
    result = run_process(
        (sys.executable, "-B", R10B_CLOSURE_AUDIT_PATH),
        timeout_seconds=420,
    )
    require(
        result.returncode == 0,
        f"R10B closure audit failed: {(result.stdout + result.stderr)[-4000:]}",
    )
    receipt = parse_marker(result.stdout, R10B_MARKER, "R10B closure")
    require(
        receipt.get("ok") is True
        and receipt.get("schema_version")
        == "sporespore_qsdk_r10b_held_out_finite_decision_physical_closure_audit_v1"
        and receipt.get("model_construction_count") == 0
        and receipt.get("audit_world_attempt_count") == 0
        and receipt.get("audit_world_build_count") == 0
        and receipt.get("native_readback_count") == 0
        and receipt.get("solver_step_count") == 0
        and receipt.get("physics_state_modified") is False
        and receipt.get("physical_acceptance_authority") is False
        and receipt.get("release_authority") is False
        and receipt.get("physical_identity_consumed") is True
        and receipt.get("same_identity_rerun_permitted") is False
        and receipt.get("evidence_valid") is True
        and receipt.get("outcome_complete") is True
        and receipt.get("behavior_passed") is False
        and receipt.get("pre_push_window_pass_count") == 0
        and receipt.get("post_push_recovery_window_found_count") == 3
        and receipt.get("native_effect_confirmed_pair_count") == 3
        and receipt.get("qsdk_r10_satisfied") is False
        and receipt.get("sdk1_m07_satisfied") is False,
        "R10B closure audit receipt drifted",
    )
    return receipt


def validate_r05e_closure() -> None:
    closure = validate_bound_file(
        R05E_CLOSURE_PATH,
        EXPECTED_R05E_CLOSURE_BYTES,
        EXPECTED_R05E_CLOSURE_SHA256,
        "R05E closure",
    )
    require(
        closure.get("outcome", {}).get("walking_pass_count") == 36
        and closure.get("outcome", {}).get("false_walking_gate_receipt_count") == 0
        and closure.get("claim_boundary", {}).get("external_push_recovery") is False,
        "R05E support boundary changed",
    )


def validate_invalid_audit_attempt() -> dict[str, Any]:
    record = read_json(INVALID_AUDIT_PATH, "R10D invalid audit attempt")
    breach = record.get("observed_scope_breach", {})
    correction = record.get("correction", {})
    claims = record.get("identity_and_claim_boundary", {})
    require(
        record.get("schema_version")
        == "sporespore_qsdk_r10d_zero_world_audit_invalid_v1"
        and record.get("status") == "closed_invalid_scope_breach_no_r10d_behavior_claim"
        and record.get("attempt_id") == "QSDK-R10D-ZW-A1"
        and breach.get("test_inventory_contains_physical_fixture_test") is True
        and breach.get("native_world_attempt_count") is None
        and breach.get("native_world_build_count") is None
        and breach.get("native_solver_step_count") is None
        and breach.get("native_physics_state_may_have_been_modified") is True
        and breach.get("r10d_godot_worker_started") is False
        and breach.get("r10d_physical_execution_authority_present") is False
        and breach.get("r10d_locomotion_outcome_exposed") is False
        and correction.get("unbounded_rust_test_execution_removed") is True
        and correction.get("replacement_executes_test_bodies") is False
        and correction.get("same_invalid_attempt_may_be_reclassified") is False
        and claims.get("invalid_audit_attempt_preserved") is True
        and claims.get("r10d_physical_campaign_identity_consumed") is False
        and claims.get("r10d_behavior_result_created") is False
        and claims.get("physical_acceptance_authority") is False
        and claims.get("release_authority") is False,
        "R10D invalid audit attempt record drifted",
    )
    return record


def run_dependency_audit(*, require_tracked: bool) -> dict[str, Any]:
    arguments: list[str | Path] = [sys.executable, "-B", DEPENDENCY_AUDIT_PATH]
    if require_tracked:
        arguments.append("--require-tracked")
    result = run_process(arguments, timeout_seconds=180)
    require(
        result.returncode == 0,
        f"R10D dependency closure failed: {(result.stdout + result.stderr)[-4000:]}",
    )
    receipt = parse_marker(result.stdout, DEPENDENCY_MARKER, "R10D dependency")
    require_zero_world(receipt, "R10D dependency")
    require(
        receipt.get("schema_version")
        == "sporespore_qsdk_r10d_dependency_closure_zero_world_v2"
        and receipt.get("repair_id") == REPAIR_ID
        and receipt.get("qualified_source_path_count")
        == EXPECTED_QUALIFIED_SOURCE_COUNT
        and receipt.get("qualified_source_path_sha256")
        == EXPECTED_QUALIFIED_SOURCE_PATH_SHA256
        and receipt.get("tracked_source_required") is require_tracked
        and (not require_tracked or receipt.get("all_qualified_paths_tracked") is True)
        and receipt.get("mutation_rejection_count") == 4,
        "R10D dependency receipt drifted",
    )
    return receipt


def run_materializer_self_test() -> dict[str, Any]:
    result = run_process(
        (sys.executable, "-B", MATERIALIZER_PATH, "self-test"),
        timeout_seconds=180,
    )
    require(
        result.returncode == 0,
        f"R10D authority materializer self-test failed: "
        f"{(result.stdout + result.stderr)[-4000:]}",
    )
    receipt = parse_marker(result.stdout, MATERIALIZER_MARKER, "R10D materializer")
    require_zero_world(receipt, "R10D materializer")
    require(
        receipt.get("schema_version")
        == "sporespore_qsdk_r10d_authority_materializer_self_test_v1"
        and receipt.get("repair_id") == REPAIR_ID
        and receipt.get("qualified_source_path_count")
        == EXPECTED_QUALIFIED_SOURCE_COUNT
        and receipt.get("qualified_source_path_sha256")
        == EXPECTED_QUALIFIED_SOURCE_PATH_SHA256
        and receipt.get("campaign_role_count") == 2
        and receipt.get("development_world_count") == 2
        and receipt.get("held_out_world_count") == 6
        and receipt.get("authority_mutation_rejection_count") == 10
        and receipt.get("runtime_identity_mutation_rejection_count") == 8
        and receipt.get("r10d_l1_design_raw_sha256") == EXPECTED_L1_DESIGN_SHA256
        and receipt.get("consumed_r10d_physical_closure_raw_sha256")
        == EXPECTED_CONSUMED_R10D_CLOSURE_SHA256
        and receipt.get("stage_freeze_authorizes_physics") is False,
        "R10D materializer receipt drifted",
    )
    return receipt


def run_physical_closure_self_test() -> dict[str, Any]:
    result = run_process(
        (sys.executable, "-B", PHYSICAL_CLOSURE_PATH, "self-test"),
        timeout_seconds=180,
    )
    require(
        result.returncode == 0,
        f"R10D physical closure self-test failed: "
        f"{(result.stdout + result.stderr)[-4000:]}",
    )
    receipt = parse_marker(
        result.stdout,
        PHYSICAL_CLOSURE_MARKER,
        "R10D physical closure",
    )
    require_zero_world(receipt, "R10D physical closure")
    require(
        receipt.get("schema_version")
        == "sporespore_qsdk_r10d_physical_closure_self_test_v1"
        and receipt.get("repair_id") == REPAIR_ID
        and receipt.get("campaign_role_count") == 2
        and receipt.get("classification_positive_control_count") == 6
        and receipt.get("classification_mutation_rejection_count") == 3
        and receipt.get("invalid_or_incomplete_classification_control_count") == 2
        and receipt.get("numeric_validation_control_count") == 6
        and receipt.get("finite_json_tree_control_count") == 3
        and receipt.get("release_authority") is False,
        "R10D physical closure receipt drifted",
    )
    return receipt


def godot_environment(root: Path) -> dict[str, str]:
    environment = dict(os.environ)
    appdata = root / "appdata"
    localappdata = root / "localappdata"
    appdata.mkdir(parents=True)
    localappdata.mkdir(parents=True)
    environment["APPDATA"] = str(appdata)
    environment["LOCALAPPDATA"] = str(localappdata)
    return environment


def run_godot(
    godot: Path,
    user_arguments: Iterable[str],
    *,
    label: str,
    expect_success: bool,
) -> subprocess.CompletedProcess[str]:
    with tempfile.TemporaryDirectory(prefix="sporespore-r10d-zero-") as raw:
        temp = Path(raw)
        result = run_process(
            (
                godot,
                "--headless",
                "--path",
                ROOT,
                "--log-file",
                temp / "godot.log",
                *user_arguments,
            ),
            timeout_seconds=180,
            environment=godot_environment(temp),
        )
    if expect_success:
        require(
            result.returncode == 0,
            f"{label} failed: {(result.stdout + result.stderr)[-4000:]}",
        )
    else:
        require(result.returncode != 0, f"{label} unexpectedly succeeded")
    return result


def validate_source_receipt(receipt: dict[str, Any]) -> None:
    require_zero_world(receipt, "R10D source")
    expected = {
        "schema_version": "sporespore_qsdk_r10d_source_zero_world_v2",
        "gate_id": "QSDK-R10D",
        "repair_id": REPAIR_ID,
        "r10d_l1_design_sha256": EXPECTED_L1_DESIGN_SHA256,
        "consumed_r10d_physical_closure_sha256": EXPECTED_CONSUMED_R10D_CLOSURE_SHA256,
        "static_contract_compile_count": 8,
        "successor_definition_control_count": 5,
        "supported_descriptor_hash_control_count": 1,
        "development_held_out_seed_separation_control_count": 1,
        "challenge_marker_and_impulse_exactness_control_count": 1,
        "positive_synthetic_world_control_count": 2,
        "positive_synthetic_pair_control_count": 1,
        "prospective_two_cycle_positive_control_count": 1,
        "historical_one_cycle_negative_control_count": 1,
        "window_boundary_and_duration_refusal_count": 2,
        "forward_floor_exact_scaling_control_count": 1,
        "forward_floor_negative_control_count": 1,
        "safe_envelope_negative_control_count": 3,
        "command_application_negative_control_count": 2,
        "per_limb_contact_cycle_negative_control_count": 4,
        "invalid_or_incomplete_refusal_count": 20,
        "valid_finite_negative_control_count": 2,
        "valid_finite_negative_json_round_trip_control_count": 1,
        "authorization_document_valid_control_count": 4,
        "authorization_document_mutation_rejection_count": 104,
        "stage_freeze_numeric_normalization_control_count": 2,
        "physical_question_opened": False,
        "release_authority": False,
    }
    for key, value in expected.items():
        require(receipt.get(key) == value, f"R10D source field drifted: {key}")
    require(
        receipt.get("ledger_scope")
        == {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "zero_world_source_and_evaluator_qualification",
            "question_class": "development",
        },
        "R10D source ledger scope drifted",
    )


def run_source_gate(godot: Path) -> dict[str, Any]:
    result = run_godot(
        godot,
        ("--script", SOURCE_TEST),
        label="R10D source gate",
        expect_success=True,
    )
    receipt = parse_marker(result.stdout, SOURCE_MARKER, "R10D source")
    validate_source_receipt(receipt)
    return receipt


def validate_contract(receipt: dict[str, Any]) -> None:
    require_zero_world(receipt, "R10D worker contract")
    require(
        receipt.get("schema_version")
        == "sporespore_qsdk_r10d_worker_contract_zero_world_v2"
        and receipt.get("gate_id") == "QSDK-R10D"
        and receipt.get("repair_id") == REPAIR_ID
        and receipt.get("contract_count") == 8
        and receipt.get("physical_execution_authorized") is False,
        "R10D worker contract header drifted",
    )
    contracts = receipt.get("contracts")
    require(isinstance(contracts, list) and len(contracts) == 8, "R10D contract array")
    observed = [
        (
            item.get("arm_id"),
            item.get("campaign_seed"),
            item.get("cell_id"),
            item.get("challenge_configuration_sha256"),
            item.get("trace_configuration_sha256"),
        )
        for item in contracts
    ]
    require(observed == EXPECTED_CONTRACTS, "R10D worker contract identity drifted")


def run_worker_contract(godot: Path) -> dict[str, Any]:
    result = run_godot(
        godot,
        ("--script", WORKER, "--", "contract"),
        label="R10D worker contract",
        expect_success=True,
    )
    receipt = parse_marker(result.stdout, CONTRACT_MARKER, "R10D contract")
    validate_contract(receipt)
    return receipt


def expected_role_contracts(role: str) -> list[tuple[Any, ...]]:
    if role == "development_route_ghost":
        return EXPECTED_CONTRACTS[:2]
    return EXPECTED_CONTRACTS[2:]


def validate_preflight(receipt: dict[str, Any], role: str) -> None:
    require_zero_world(receipt, f"R10D {role} preflight")
    expected = expected_role_contracts(role)
    require(
        receipt.get("schema_version")
        == "sporespore_qsdk_r10d_worker_entrypoint_zero_world_v2"
        and receipt.get("gate_id") == "QSDK-R10D"
        and receipt.get("repair_id") == REPAIR_ID
        and receipt.get("campaign_role") == role
        and receipt.get("entrypoint_count") == len(expected)
        and receipt.get("physical_execution_authorized") is False,
        f"R10D {role} preflight header drifted",
    )
    entries = receipt.get("entrypoints")
    require(
        isinstance(entries, list) and len(entries) == len(expected),
        f"R10D {role} preflight entries",
    )
    observed = [
        (
            entry.get("arm_id"),
            entry.get("campaign_seed"),
            entry.get("cell_id"),
            entry.get("trace_configuration_sha256"),
        )
        for entry in entries
    ]
    expected_projection = [
        (arm, seed, cell, trace) for arm, seed, cell, _, trace in expected
    ]
    require(observed == expected_projection, f"R10D {role} preflight identity drifted")
    require(
        all(
            entry.get("declared_policy_runtime_boundary_preflight_passed") is True
            and entry.get("world_build_count") == 0
            for entry in entries
        ),
        f"R10D {role} preflight boundary failed",
    )


def run_preflight(godot: Path, role: str) -> dict[str, Any]:
    result = run_godot(
        godot,
        ("--script", WORKER, "--", "preflight", role),
        label=f"R10D {role} preflight",
        expect_success=True,
    )
    receipt = parse_marker(result.stdout, PREFLIGHT_MARKER, f"R10D {role} preflight")
    validate_preflight(receipt, role)
    return receipt


def run_direct_bypass(godot: Path) -> dict[str, Any]:
    result = run_godot(
        godot,
        (
            "--script",
            WORKER,
            "--",
            "physical",
            "development_route_ghost",
            "matched_no_impulse_control",
            "40001",
        ),
        label="R10D direct physical bypass",
        expect_success=False,
    )
    receipt = parse_marker(result.stdout, CELL_MARKER, "R10D bypass")
    require_zero_world(receipt, "R10D bypass", require_ok=False)
    require(
        receipt.get("ok") is False
        and receipt.get("repair_id") == REPAIR_ID
        and receipt.get("failure_code") == "QSDK_R10D_PHYSICAL_AUTHORIZATION_REQUIRED"
        and receipt.get("evidence_valid") is False
        and receipt.get("outcome_complete") is False
        and receipt.get("behavior_passed") is False,
        "R10D direct physical bypass refusal drifted",
    )
    return receipt


def run_supervisor(pwsh: str, godot: Path) -> dict[str, Any]:
    result = run_process(
        (
            pwsh,
            "-NoLogo",
            "-NoProfile",
            "-File",
            SUPERVISOR_PATH,
            "-Mode",
            "ZeroWorld",
            "-Godot",
            godot,
        ),
        timeout_seconds=420,
    )
    require(
        result.returncode == 0,
        f"R10D supervisor failed: {(result.stdout + result.stderr)[-5000:]}",
    )
    receipt = parse_marker(result.stdout, SUPERVISOR_MARKER, "R10D supervisor")
    require_zero_world(receipt, "R10D supervisor")
    require(
        receipt.get("schema_version") == "sporespore_qsdk_r10d_supervisor_zero_world_v2"
        and receipt.get("gate_id") == "QSDK-R10D"
        and receipt.get("repair_id") == REPAIR_ID
        and receipt.get("direct_physical_bypass_refused") is True
        and receipt.get("ordinal_path_order_control_passed") is True
        and receipt.get("ordinal_path_order_negative_control_count") == 2
        and receipt.get("physical_execution_authorized") is False,
        "R10D supervisor receipt drifted",
    )
    validate_source_receipt(receipt.get("source_gate", {}))
    validate_contract(receipt.get("worker_contract", {}))
    preflights = receipt.get("entrypoint_preflights")
    require(
        isinstance(preflights, list) and len(preflights) == 2, "R10D preflight list"
    )
    validate_preflight(preflights[0], "development_route_ghost")
    validate_preflight(preflights[1], "held_out_finite_decision")
    return receipt


def run_gdformat_check() -> str:
    gdformat = shutil.which("gdformat")
    require(gdformat is not None, "gdformat is not available")
    result = run_process(
        (gdformat, "--check", *FORMATTED_GDSCRIPT_PATHS),
        timeout_seconds=180,
    )
    require(
        result.returncode == 0,
        f"R10D GDScript formatting check failed: "
        f"{(result.stdout + result.stderr)[-4000:]}",
    )
    return gdformat


def run_black_check() -> None:
    result = run_process(
        (sys.executable, "-m", "black", "--check", *PYTHON_PATHS),
        timeout_seconds=180,
    )
    require(
        result.returncode == 0,
        f"R10D Python formatting check failed: "
        f"{(result.stdout + result.stderr)[-4000:]}",
    )


def run_powershell_parse_check(pwsh: str) -> int:
    for path in POWERSHELL_PATHS:
        environment = dict(os.environ)
        environment["SPORESPORE_R10D_PARSE_PATH"] = str(path)
        script = (
            "$tokens=$null; $errors=$null; "
            "[void][System.Management.Automation.Language.Parser]::ParseFile("
            "$env:SPORESPORE_R10D_PARSE_PATH,[ref]$tokens,[ref]$errors); "
            "if ($errors.Count -ne 0) { "
            "$errors | ForEach-Object { Write-Error $_ }; exit 41 }; "
            "Write-Output 'QSDK_R10D_POWERSHELL_PARSE_PASS'"
        )
        result = run_process(
            (pwsh, "-NoLogo", "-NoProfile", "-Command", script),
            timeout_seconds=60,
            environment=environment,
        )
        require(
            result.returncode == 0
            and result.stdout.count("QSDK_R10D_POWERSHELL_PARSE_PASS") == 1,
            f"R10D PowerShell parse check failed for {path}: "
            f"{(result.stdout + result.stderr)[-3000:]}",
        )
    return len(POWERSHELL_PATHS)


def run_rust_checks() -> None:
    fmt = run_process(
        (
            "cargo",
            "fmt",
            "--manifest-path",
            ROOT / "sdk/Cargo.toml",
            "--all",
            "--",
            "--check",
        ),
        timeout_seconds=180,
    )
    require(
        fmt.returncode == 0,
        f"R10D Rust format check failed: {(fmt.stdout + fmt.stderr)[-4000:]}",
    )
    compile_check = run_process(
        (
            "cargo",
            "check",
            "--manifest-path",
            ROOT / "sdk/Cargo.toml",
            "--workspace",
            "--all-targets",
        ),
        timeout_seconds=600,
    )
    require(
        compile_check.returncode == 0,
        f"R10D Rust workspace compile check failed: "
        f"{(compile_check.stdout + compile_check.stderr)[-5000:]}",
    )


def validate_static_authorization_boundary() -> int:
    paths = (
        SUPERVISOR_PATH,
        QUALIFICATION_PATH,
        MATERIALIZER_PATH,
        PHYSICAL_CLOSURE_PATH,
        DEPENDENCY_AUDIT_PATH,
        L1_DESIGN_AUDIT_PATH,
        ROOT / "tests/test_sdk_qsdk_r10d_l1_retained_stage_freeze_diagnosis.gd",
        ROOT
        / "tests/test_sdk_qsdk_r10d_supported_start_phase_robust_push_recovery_worker.gd",
        ROOT
        / "scripts/lab/gait/qsdk_r10d_supported_start_phase_robust_push_recovery.gd",
        ROOT / "scripts/lab/gait/physical_wave_gait_quadruped.gd",
    )
    texts = {path: path.read_text(encoding="utf-8") for path in paths}
    combined = "\n".join(texts.values())
    forbidden = (
        "PLACEHOLDER",
        "qsdk_r10d_dependency_manifest_v4.json",
        "sporespore_qsdk_r10d_stage_freeze_v4",
        "sporespore_qsdk_r10d_execution_authority_v4",
        "sporespore_qsdk_r10d_zero_world_qualification_completion_v4",
        "QSDK-R10D-L2",
        "QSDK-R10D-L3",
    )
    for token in forbidden:
        require(token not in combined, f"stale R10D authority token remains: {token}")
    required = (
        EXPECTED_QUALIFIED_SOURCE_PATH_SHA256,
        "sporespore_qsdk_r10d_stage_freeze_v2",
        "sporespore_qsdk_r10d_execution_authority_v2",
        "sporespore_qsdk_r10d_zero_world_qualification_completion_v2",
        REPAIR_ID,
        EXPECTED_L1_DESIGN_SHA256,
        EXPECTED_CONSUMED_R10D_CLOSURE_SHA256,
        "sporespore_qsdk_r10d_runtime_identity_projection_v1",
        "sporespore_qsdk_r10d_runtime_identity_v1",
        "QSDK_R10D_PHYSICAL_AUTHORIZATION_REQUIRED",
        "RigidBody3D.apply_central_impulse",
        "qsdk_r10d_supported_start_phase_robust_push_recovery_trace_v1",
        "qsdk_r10b_bounded_upright_push_recovery_trace_v3",
        "authorized_single_use_unconsumed",
        "closed_passing_official_zero_world_qualification",
    )
    for token in required:
        require(token in combined, f"R10D authority token is missing: {token}")
    require(
        texts[SUPERVISOR_PATH].count("Get-QualifiedPhysicalAuthority") >= 2
        and texts[SUPERVISOR_PATH].count("Assert-PhysicalCellReceipt") == 2
        and texts[SUPERVISOR_PATH].count("Assert-PairReceipt") == 2
        and "source_r05e_generator_receipt_sha256" in texts[SUPERVISOR_PATH]
        and "target_body_id" in texts[SUPERVISOR_PATH]
        and "application_method" in texts[SUPERVISOR_PATH]
        and "baseline_cell_raw_sha256" in texts[SUPERVISOR_PATH]
        and "push_cell_raw_sha256" in texts[SUPERVISOR_PATH]
        and texts[SUPERVISOR_PATH].count("Assert-QualifiedRuntimeCurrent") >= 6
        and "Get-TextSha256 -Text $canonicalJson" in texts[SUPERVISOR_PATH]
        and "runtime_identity_sha256" in texts[SUPERVISOR_PATH]
        and "active_adapter_raw_sha256" in texts[SUPERVISOR_PATH]
        and "sporespore_qsdk_r10d_physical_failure_v2" in texts[SUPERVISOR_PATH]
        and "behavioral_conclusion_available" in texts[SUPERVISOR_PATH]
        and "world_build_count_known" in texts[SUPERVISOR_PATH]
        and "the terminal report is retained" in texts[SUPERVISOR_PATH]
        and "ls-remote" in texts[SUPERVISOR_PATH]
        and "Refusing to overwrite an existing physical evidence directory"
        in texts[SUPERVISOR_PATH],
        "R10D supervisor physical boundary drifted",
    )
    require(
        texts[MATERIALIZER_PATH].count("validate_runtime_identity_projection") == 4
        and "QUALIFICATION_RUNTIME_IDENTITY_DIGEST" in texts[MATERIALIZER_PATH]
        and "QUALIFICATION_RUNTIME_ADAPTER_SHA256_DRIFT" in texts[MATERIALIZER_PATH]
        and "QUALIFICATION_RUNTIME_PROJECTION_RECEIPT_MISMATCH"
        in texts[MATERIALIZER_PATH]
        and "PHYSICAL_CLOSURE_AUDIT_MARKER" in texts[MATERIALIZER_PATH]
        and "DEVELOPMENT_ROUTE_CLOSURE_AUDIT_BINDING" in texts[MATERIALIZER_PATH]
        and "reconstructed_from_retained_evidence" in texts[MATERIALIZER_PATH]
        and texts[MATERIALIZER_PATH].count("validate_qualification(") == 3,
        "R10D qualification runtime binding drifted",
    )
    require(
        "def validate_report(" in texts[PHYSICAL_CLOSURE_PATH]
        and "def build_closure(" in texts[PHYSICAL_CLOSURE_PATH]
        and "CLOSURE_DOCUMENT_DRIFT" in texts[PHYSICAL_CLOSURE_PATH]
        and "held_out_qualification_eligible" in texts[PHYSICAL_CLOSURE_PATH]
        and "bounded_upright_push_recovery_claimed" in texts[PHYSICAL_CLOSURE_PATH]
        and "same_identity_rerun_permitted" in texts[PHYSICAL_CLOSURE_PATH]
        and "def validate_qualified_source_bindings(" in texts[PHYSICAL_CLOSURE_PATH]
        and "QUALIFIED_SOURCE_BINDING_DRIFT" in texts[PHYSICAL_CLOSURE_PATH]
        and "def is_finite_number(" in texts[PHYSICAL_CLOSURE_PATH]
        and "def is_finite_json_tree(" in texts[PHYSICAL_CLOSURE_PATH]
        and "def evidence_tree_inventory(" in texts[PHYSICAL_CLOSURE_PATH]
        and "closed_consumed_invalid_or_incomplete_no_valid_route"
        in texts[PHYSICAL_CLOSURE_PATH]
        and "reconstructed_from_retained_evidence" in texts[PHYSICAL_CLOSURE_PATH],
        "R10D physical closure authority drifted",
    )
    require(
        '"application_method": "RigidBody3D.apply_central_impulse"'
        in texts[
            ROOT
            / "scripts/lab/gait/qsdk_r10d_supported_start_phase_robust_push_recovery.gd"
        ]
        or "RigidBody3D.apply_central_impulse"
        in texts[ROOT / "scripts/lab/gait/physical_wave_gait_quadruped.gd"],
        "R10D native impulse method binding is missing",
    )
    return len(paths)


def run_operation_lock_probe(pwsh: str) -> None:
    environment = dict(os.environ)
    environment["SPORESPORE_R10D_LOCK_PATH"] = str(OPERATION_LOCK_PATH)
    script = "\n".join(
        (
            "$ErrorActionPreference = 'Stop'",
            ". $env:SPORESPORE_R10D_LOCK_PATH",
            "$receipt = Enter-SporeSporeLocomotionOperationLock -Role conformance",
            "if (-not [bool]$receipt.acquired -or "
            "[bool]$receipt.abandoned_owner_recovered) { exit 51 }",
            "Exit-SporeSporeLocomotionOperationLock -Receipt $receipt",
            "if (-not [bool]$receipt.released) { exit 52 }",
            "Write-Output 'QSDK_R10D_OPERATION_LOCK_PROBE_PASS'",
        )
    )
    result = run_process(
        (pwsh, "-NoLogo", "-NoProfile", "-Command", script),
        timeout_seconds=60,
        environment=environment,
    )
    require(
        result.returncode == 0
        and result.stdout.count("QSDK_R10D_OPERATION_LOCK_PROBE_PASS") == 1,
        f"R10D operation lock probe failed: {(result.stdout + result.stderr)[-3000:]}",
    )


def command_version(arguments: Iterable[str | Path], label: str) -> str:
    result = run_process(arguments, timeout_seconds=60)
    require(result.returncode == 0, f"could not identify {label}")
    value = (
        (result.stdout + result.stderr).strip().replace("\r", " ").replace("\n", " ")
    )
    require(bool(value), f"{label} returned an empty version")
    return value


def executable_identity(path: Path, version: str) -> dict[str, Any]:
    resolved = path.resolve()
    require(resolved.is_file(), f"runtime identity path is missing: {resolved}")
    return {
        "path": str(resolved),
        "raw_sha256": sha256_file(resolved),
        "byte_length": resolved.stat().st_size,
        "version": version,
    }


def runtime_identity(
    godot: Path,
    pwsh: str,
    gdformat: str,
    dependency: Mapping[str, Any],
) -> dict[str, Any]:
    git_path = shutil.which("git")
    cargo_path = shutil.which("cargo")
    require(git_path is not None and cargo_path is not None, "Git or Cargo missing")
    adapter_digest = sha256_file(ACTIVE_ADAPTER_PATH)
    require(
        dependency.get("active_runtime_artifact_raw_sha256") == adapter_digest
        and dependency.get("active_runtime_artifact_byte_length")
        == ACTIVE_ADAPTER_PATH.stat().st_size,
        "active adapter changed after dependency qualification",
    )
    identity = {
        "schema_version": "sporespore_qsdk_r10d_runtime_identity_v1",
        "godot": executable_identity(
            godot,
            command_version((godot, "--version"), "Godot"),
        ),
        "active_adapter": {
            "path": "sdk/target/debug/sporespore_godot_adapter.dll",
            "raw_sha256": adapter_digest,
            "byte_length": ACTIVE_ADAPTER_PATH.stat().st_size,
        },
        "python": executable_identity(
            Path(sys.executable), sys.version.replace("\n", " ")
        ),
        "powershell": executable_identity(
            Path(pwsh),
            command_version(
                (
                    pwsh,
                    "-NoLogo",
                    "-NoProfile",
                    "-Command",
                    "$PSVersionTable.PSVersion.ToString()",
                ),
                "PowerShell",
            ),
        ),
        "git": executable_identity(
            Path(git_path),
            command_version((git_path, "--version"), "Git"),
        ),
        "cargo": executable_identity(
            Path(cargo_path),
            command_version((cargo_path, "--version"), "Cargo"),
        ),
        "gdformat": executable_identity(
            Path(gdformat),
            command_version((gdformat, "--version"), "gdformat"),
        ),
    }
    canonical = json.dumps(identity, separators=(",", ":"), sort_keys=True)
    return {
        "schema_version": "sporespore_qsdk_r10d_runtime_identity_projection_v1",
        "identity_sha256": sha256_bytes(canonical.encode("utf-8")),
        "identity": identity,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, default=DEFAULT_GODOT)
    parser.add_argument("--require-tracked", action="store_true")
    parser.add_argument("--official-qualification", action="store_true")
    arguments = parser.parse_args()
    try:
        require(ROOT.resolve() == EXPECTED_ROOT.resolve(), "canonical root changed")
        godot = arguments.godot.resolve()
        require(godot.is_file(), f"Godot console is missing: {godot}")
        require(ACTIVE_ADAPTER_PATH.is_file(), "active Godot adapter is missing")
        pwsh = shutil.which("pwsh")
        require(pwsh is not None, "pwsh is not available")
        source = inspect_source_boundary(
            official_qualification=arguments.official_qualification
        )
        require_tracked = arguments.require_tracked or arguments.official_qualification
        design = run_design_audit()
        l1_design = run_l1_design_audit()
        r10b = run_r10b_closure_audit()
        validate_r05e_closure()
        invalid_audit = validate_invalid_audit_attempt()
        run_rust_checks()
        dependency = run_dependency_audit(require_tracked=require_tracked)
        materializer = run_materializer_self_test()
        physical_closure = run_physical_closure_self_test()
        run_black_check()
        gdformat = run_gdformat_check()
        powershell_count = run_powershell_parse_check(pwsh)
        static_path_count = validate_static_authorization_boundary()
        l1_diagnosis = run_l1_diagnosis(godot)
        direct_source = run_source_gate(godot)
        direct_contract = run_worker_contract(godot)
        direct_development = run_preflight(godot, "development_route_ghost")
        direct_held_out = run_preflight(godot, "held_out_finite_decision")
        direct_bypass = run_direct_bypass(godot)
        supervisor = run_supervisor(pwsh, godot)
        require(
            supervisor.get("source_gate") == direct_source,
            "direct and supervisor source receipts differ",
        )
        require(
            supervisor.get("worker_contract") == direct_contract,
            "direct and supervisor contract receipts differ",
        )
        require(
            supervisor.get("entrypoint_preflights")
            == [direct_development, direct_held_out],
            "direct and supervisor preflight receipts differ",
        )
        wrapper_lock_held = (
            os.environ.get("SPORESPORE_QSDK_R10D_QUALIFICATION_LOCK_HELD") == "1"
        )
        require(
            wrapper_lock_held is arguments.official_qualification,
            "official qualification lock ownership did not match audit mode",
        )
        if wrapper_lock_held:
            operation_lock_mode = "held_by_official_qualification_wrapper"
        else:
            run_operation_lock_probe(pwsh)
            operation_lock_mode = "independent_acquire_release_probe"
        runtime = runtime_identity(godot, pwsh, gdformat, dependency)
        receipt = {
            "schema_version": "sporespore_qsdk_r10d_zero_world_implementation_audit_v1",
            "gate_id": "QSDK-R10D",
            "repair_id": REPAIR_ID,
            "ledger_scope": {
                "subsystem": "recovery",
                "engine_scope": "godot_jolt",
                "authority_mode": "prospective_zero_world_implementation_audit",
                "question_class": "development",
            },
            "ok": True,
            **source,
            "r10c_design_raw_sha256": EXPECTED_DESIGN_SHA256,
            "r10c_design_byte_length": EXPECTED_DESIGN_BYTES,
            "r10c_design_audit_passed": True,
            "r10c_design_mutation_rejection_count": design[
                "design_mutation_rejection_count"
            ],
            "r10d_l1_design_raw_sha256": EXPECTED_L1_DESIGN_SHA256,
            "r10d_l1_design_byte_length": EXPECTED_L1_DESIGN_BYTES,
            "r10d_l1_design_audit_passed": True,
            "r10d_l1_design_and_diagnosis_mutation_control_count": l1_design[
                "design_and_diagnosis_mutation_control_count"
            ],
            "r10d_l1_retained_diagnosis_passed": True,
            "r10d_l1_retained_diagnosis_normalization_control_count": l1_diagnosis[
                "normalization_control_count"
            ],
            "r10d_l1_retained_parsed_seed_numeric_types": l1_diagnosis[
                "parsed_supported_seed_types"
            ],
            "consumed_r10d_physical_closure_raw_sha256": (
                EXPECTED_CONSUMED_R10D_CLOSURE_SHA256
            ),
            "consumed_r10d_physical_closure_byte_length": (
                EXPECTED_CONSUMED_R10D_CLOSURE_BYTES
            ),
            "consumed_r10d_physical_identity_consumed": True,
            "consumed_r10d_same_identity_rerun_permitted": False,
            "consumed_r10d_behavioral_conclusion_available": False,
            "r10b_held_out_closure_raw_sha256": EXPECTED_R10B_CLOSURE_SHA256,
            "r10b_held_out_closure_byte_length": EXPECTED_R10B_CLOSURE_BYTES,
            "r10b_closure_audit_passed": True,
            "r10b_physical_identity_consumed": True,
            "r10b_same_identity_rerun_permitted": False,
            "r10b_bounded_upright_push_recovery_claimed": False,
            "r10b_closure_mutation_rejection_count": r10b[
                "closure_mutation_rejection_count"
            ],
            "r05e_physical_closure_raw_sha256": EXPECTED_R05E_CLOSURE_SHA256,
            "r05e_physical_closure_byte_length": EXPECTED_R05E_CLOSURE_BYTES,
            "r05e_physical_closure_audit_passed": True,
            "r05e_selected_generator_index": 217,
            "r05e_supported_start_seed_count": 3,
            "r05e_selected_start_walking_pass_count": 3,
            "dependency_closure_audit_passed": True,
            "qualified_source_path_count": dependency["qualified_source_path_count"],
            "qualified_source_path_sha256": dependency["qualified_source_path_sha256"],
            "all_qualified_source_paths_tracked": dependency[
                "all_qualified_paths_tracked"
            ],
            "tracked_source_required": dependency["tracked_source_required"],
            "dependency_mutation_rejection_count": dependency[
                "mutation_rejection_count"
            ],
            "authority_materializer_self_test_passed": True,
            "authority_materializer_campaign_role_count": materializer[
                "campaign_role_count"
            ],
            "authority_materializer_mutation_rejection_count": materializer[
                "authority_mutation_rejection_count"
            ],
            "authority_runtime_identity_mutation_rejection_count": materializer[
                "runtime_identity_mutation_rejection_count"
            ],
            "physical_closure_self_test_passed": True,
            "physical_closure_campaign_role_count": physical_closure[
                "campaign_role_count"
            ],
            "physical_closure_classification_positive_control_count": physical_closure[
                "classification_positive_control_count"
            ],
            "physical_closure_invalid_or_incomplete_classification_control_count": physical_closure[
                "invalid_or_incomplete_classification_control_count"
            ],
            "physical_closure_classification_mutation_rejection_count": physical_closure[
                "classification_mutation_rejection_count"
            ],
            "physical_closure_numeric_validation_control_count": physical_closure[
                "numeric_validation_control_count"
            ],
            "physical_closure_finite_json_tree_control_count": physical_closure[
                "finite_json_tree_control_count"
            ],
            "runtime_identity_projection": runtime,
            "rust_format_check_passed": True,
            "rust_workspace_compile_check_passed": True,
            "rust_test_body_execution_count": 0,
            "invalid_zero_world_audit_attempt_preserved": True,
            "invalid_zero_world_audit_attempt_id": invalid_audit["attempt_id"],
            "invalid_zero_world_audit_native_world_count_known": False,
            "invalid_zero_world_audit_r10d_behavior_result_created": False,
            "python_black_check_passed": True,
            "gdformat_check_passed": True,
            "gdformat_path_count": len(FORMATTED_GDSCRIPT_PATHS),
            "powershell_parse_passed": True,
            "powershell_parse_path_count": powershell_count,
            "static_authorization_boundary_passed": True,
            "static_authorization_path_count": static_path_count,
            "source_gate_count": 2,
            "source_receipts_exact_across_independent_runs": True,
            "static_contract_compile_count_per_source_gate": 8,
            "successor_definition_control_count_per_source_gate": 5,
            "supported_descriptor_hash_control_count_per_source_gate": 1,
            "prospective_two_cycle_positive_control_count_per_source_gate": 1,
            "historical_one_cycle_negative_control_count_per_source_gate": 1,
            "invalid_or_incomplete_refusal_count_per_source_gate": 20,
            "authorization_document_valid_control_count_per_source_gate": 4,
            "authorization_document_mutation_rejection_count_per_source_gate": 104,
            "stage_freeze_numeric_normalization_control_count_per_source_gate": 2,
            "worker_contract_count": 8,
            "entrypoint_preflight_count": 8,
            "development_entrypoint_count": 2,
            "held_out_entrypoint_count": 6,
            "direct_physical_bypass_refusal_count": 2,
            "direct_bypass_failure_code": direct_bypass["failure_code"],
            "operation_lock_boundary_passed": True,
            "operation_lock_probe_passed": not wrapper_lock_held,
            "operation_lock_mode": operation_lock_mode,
            "physical_execution_authorized": False,
            "locomotion_outcome_exposure_count": 0,
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
        print(PASS_MARKER + json.dumps(receipt, separators=(",", ":"), sort_keys=True))
        return 0
    except (
        AuditFailure,
        KeyError,
        IndexError,
        TypeError,
        OSError,
        UnicodeError,
        json.JSONDecodeError,
    ) as exc:
        print(f"QSDK_R10D_ZERO_WORLD_IMPLEMENTATION_FAIL {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
