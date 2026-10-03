#!/usr/bin/env python3
"""Audit the prospective R05E implementation without opening a physics world."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from typing import Any, Iterable


ROOT = Path(__file__).resolve().parents[2]
DESIGN_PATH = ROOT / "sdk/qsdk_r05d_exact_finite_morphology_successor_design_v1.json"
DESIGN_AUDIT_PATH = (
    ROOT / "sdk/conformance/qsdk_r05d_exact_finite_morphology_successor_design.py"
)
OFFICIAL_PREREGISTRATION_PATH = (
    ROOT / "sdk/qsdk_r05e_exact_finite_morphology_preregistration.json"
)
GHOST_PREREGISTRATION_PATH = (
    ROOT / "sdk/qsdk_r05e_development_route_ghost_preregistration.json"
)
GENERIC_RUNNER_PATH = ROOT / "sdk/run_qsdk_independent_morphology_v2.ps1"
AUTHORITY_CONTRACT_TEST_PATH = (
    ROOT / "tests/test_qsdk_r05e_execution_authority_contract.ps1"
)
DEPENDENCY_AUDIT_PATH = ROOT / "sdk/conformance/qsdk_r05e_dependency_closure.py"
OPERATION_LOCK_PATH = ROOT / "sdk/locomotion_operation_lock.ps1"
EXPECTED_DESIGN_SHA256 = (
    "3b75b7609b638470ee947326f71018d082beb4a2c2909e78dae77d3b50250a6c"
)
EXPECTED_OFFICIAL_PREREGISTRATION_SHA256 = (
    "3e51a1b2198740bf3a54198bb6cfdbdc946429fb69528378dba7d25cc2d21895"
)
EXPECTED_GHOST_PREREGISTRATION_SHA256 = (
    "ce1ef34851f81455115dd7031546f867f466c8ce264e375faba6c2d4436cf7f9"
)
EXPECTED_POLICY_ID = "sporespore_balanced_wave_bw5r_b_v1"
EXPECTED_POLICY_DIGEST = (
    "sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f"
)
EXPECTED_OFFICIAL_INDICES = tuple(range(217, 229))
EXPECTED_OFFICIAL_SEEDS = (40101, 40102, 40103)
EXPECTED_GHOST_INDICES = (229,)
EXPECTED_GHOST_SEEDS = (40001,)
DEFAULT_GODOT = Path(
    r"C:\Users\Cole\CodeStuff\Misc\Godot\Godot_v4.7-stable_mono_win64_console.exe"
)
PASS_MARKER = "QSDK_R05E_ZERO_WORLD_IMPLEMENTATION_PASS "
EXPECTED_QUALIFIED_SOURCE_PATH_COUNT = 80
EXPECTED_QUALIFIED_SOURCE_PATH_SHA256 = (
    "sha256:2097b6962dd41cc0554355a9418365b917f25393752b5712ea26141cf6ab5fa7"
)


class AuditFailure(RuntimeError):
    """Raised when the prospective implementation does not reconcile exactly."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AuditFailure(message)


def sha256_hex(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def qualification_tool_identity() -> dict[str, Any]:
    executable = Path(sys.executable).resolve()
    require(executable.is_file(), "Python qualification executable is missing")
    return {
        "path": executable.as_posix(),
        "raw_sha256": f"sha256:{sha256_hex(executable)}",
        "byte_length": executable.stat().st_size,
        "version": sys.version.replace("\n", " "),
    }


def read_json(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise AuditFailure(f"{label}: invalid UTF-8 JSON: {exc}") from exc
    require(isinstance(value, dict), f"{label}: root must be an object")
    return value


def run_process(
    arguments: Iterable[str | Path],
    *,
    timeout_seconds: int,
) -> subprocess.CompletedProcess[str]:
    command = tuple(str(argument) for argument in arguments)
    try:
        return subprocess.run(
            command,
            cwd=ROOT,
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


def exact_ints(values: Any) -> tuple[int, ...]:
    require(isinstance(values, list), "expected an integer array")
    require(
        all(isinstance(value, int) and not isinstance(value, bool) for value in values),
        "integer array contains a non-integer value",
    )
    return tuple(values)


def validate_preregistrations() -> None:
    require(
        sha256_hex(DESIGN_PATH) == EXPECTED_DESIGN_SHA256, "R05D design digest changed"
    )
    require(
        sha256_hex(OFFICIAL_PREREGISTRATION_PATH)
        == EXPECTED_OFFICIAL_PREREGISTRATION_SHA256,
        "official preregistration digest changed",
    )
    require(
        sha256_hex(GHOST_PREREGISTRATION_PATH) == EXPECTED_GHOST_PREREGISTRATION_SHA256,
        "ghost preregistration digest changed",
    )
    design = read_json(DESIGN_PATH, "R05D design")
    official = read_json(OFFICIAL_PREREGISTRATION_PATH, "official preregistration")
    ghost = read_json(GHOST_PREREGISTRATION_PATH, "ghost preregistration")
    selected = design["selected_successor_design"]
    require(
        selected["campaign_id"] == official["campaign_id"],
        "official campaign ID drifted",
    )
    require(
        selected["selected_policy_id"] == EXPECTED_POLICY_ID
        and selected["selected_policy_digest"] == EXPECTED_POLICY_DIGEST,
        "R05D selected policy drifted",
    )
    require(
        official["schema_version"]
        == "sporespore_qsdk_r05e_exact_finite_morphology_preregistration_v1"
        and official["status"] == "frozen_before_first_qsdk_r05e_heldout_physics_world"
        and official["campaign_role"] == "held_out_finite_decision"
        and official["ledger_scope"]["question_class"] == "finite decision",
        "official preregistration identity drifted",
    )
    require(
        ghost["schema_version"]
        == "sporespore_qsdk_r05e_development_route_ghost_preregistration_v1"
        and ghost["status"] == "frozen_before_first_qsdk_r05e_development_ghost_world"
        and ghost["campaign_role"] == "development_route_ghost"
        and ghost["ledger_scope"]["question_class"] == "development",
        "ghost preregistration identity drifted",
    )
    for label, document in (("official", official), ("ghost", ghost)):
        require(
            document["freeze_parent_commit"]
            == "3aa9f4d7642ba498635a0680b85a94432bcd5048",
            f"{label}: freeze parent drifted",
        )
        require(
            document["selected_policy_id"] == EXPECTED_POLICY_ID,
            f"{label}: policy ID drifted",
        )
        require(
            document["selected_policy_digest"] == EXPECTED_POLICY_DIGEST,
            f"{label}: policy digest drifted",
        )
        require(
            document["policy_branch_surface_count"] == 0,
            f"{label}: branch surface opened",
        )
        require(
            document["controller_threshold_material_solver_or_host_change_from_r05b"]
            is False,
            f"{label}: frozen production conditions changed",
        )
        authorization = document["authorization"]
        require(
            authorization["zero_world_qualification_passed"] is False
            and authorization["single_use_authorization_created"] is False
            and authorization["physical_execution_authorized"] is False
            and authorization["maximum_world_attempt_count_now"] == 0
            and authorization["maximum_world_build_count_now"] == 0
            and authorization["maximum_solver_step_count_now"] == 0,
            f"{label}: preregistration prematurely authorizes physics",
        )
        claim = document["claim_boundary"]
        require(
            claim["arbitrary_quadruped_coverage"] is False
            and claim["continuous_full_volume_coverage"] is False
            and claim["completed_engine_neutral_sdk"] is False
            and claim["release_authorized"] is False,
            f"{label}: claim boundary widened",
        )
    require(
        exact_ints(official["morphology_generator"]["generator_indices"])
        == EXPECTED_OFFICIAL_INDICES
        and exact_ints(official["repetitions"]["campaign_seeds"])
        == EXPECTED_OFFICIAL_SEEDS
        and len(official["morphology_generator"]["cells"]) == 12
        and official["repetitions"]["expected_world_count"] == 36
        and official["authorization"]["held_out_cells_remain_sealed"] is True,
        "official finite population drifted",
    )
    require(
        exact_ints(ghost["morphology_generator"]["generator_indices"])
        == EXPECTED_GHOST_INDICES
        and exact_ints(ghost["repetitions"]["campaign_seeds"]) == EXPECTED_GHOST_SEEDS
        and len(ghost["morphology_generator"]["cells"]) == 1
        and ghost["repetitions"]["expected_world_count"] == 1
        and ghost["predecessor_interlock"]["heldout_access_permitted"] is False
        and ghost["walking_gate"]["behavior_success_required"] is False
        and ghost["walking_gate"]["route_completion_required"] is True,
        "development ghost population or claim boundary drifted",
    )


def run_r05d_audit() -> None:
    result = run_process(
        (sys.executable, "-B", DESIGN_AUDIT_PATH),
        timeout_seconds=120,
    )
    require(result.returncode == 0, f"R05D audit failed: {result.stderr.strip()}")
    require(
        "QSDK_R05D_EXACT_FINITE_MORPHOLOGY_SUCCESSOR_DESIGN_PASS" in result.stdout,
        "R05D audit did not emit its pass marker",
    )


def run_authority_contract_test(pwsh: str) -> None:
    result = run_process(
        (
            pwsh,
            "-NoLogo",
            "-NoProfile",
            "-File",
            AUTHORITY_CONTRACT_TEST_PATH,
        ),
        timeout_seconds=120,
    )
    require(
        result.returncode == 0,
        f"R05E authority contract failed: {(result.stdout + result.stderr)[-4000:]}",
    )
    receipt = parse_marker(
        result.stdout,
        "QSDK_R05E_EXECUTION_AUTHORITY_CONTRACT_ZERO_WORLD ",
        "R05E execution-authority contract",
    )
    require(
        receipt.get("ok") is True
        and receipt.get("positive_repository_graph_count") == 2
        and receipt.get("content_mutation_rejection_count") == 35
        and receipt.get("repository_binding_rejection_count") == 5
        and receipt.get("authority_commit_self_reference_required") is False
        and receipt.get("authorization_parent_binding_required") is True
        and receipt.get("authorization_only_commit_required") is True
        and receipt.get("qualification_direct_source_child_required") is True
        and receipt.get("qualification_only_commit_required") is True
        and receipt.get("qualified_source_blob_equality_required") is True
        and receipt.get("qualification_receipt_content_address_required") is True
        and receipt.get("qualification_receipt_semantics_required") is True
        and receipt.get("runtime_identity_binding_required") is True
        and receipt.get("model_construction_count") == 0
        and receipt.get("world_attempt_count") == 0
        and receipt.get("world_build_count") == 0
        and receipt.get("native_readback_count") == 0
        and receipt.get("solver_step_count") == 0
        and receipt.get("physics_state_modified") is False
        and receipt.get("physical_execution_authorized") is False
        and receipt.get("physical_acceptance_authority") is False
        and receipt.get("release_authority") is False,
        "R05E authority contract receipt failed strict reconciliation",
    )


def run_dependency_audit(*, require_tracked: bool) -> dict[str, Any]:
    arguments: tuple[str | Path, ...] = (
        sys.executable,
        "-B",
        DEPENDENCY_AUDIT_PATH,
    )
    if require_tracked:
        arguments = (*arguments, "--require-tracked")
    result = run_process(
        arguments,
        timeout_seconds=120,
    )
    require(
        result.returncode == 0,
        f"R05E dependency closure failed: {(result.stdout + result.stderr)[-4000:]}",
    )
    receipt = parse_marker(
        result.stdout,
        "QSDK_R05E_DEPENDENCY_CLOSURE_PASS ",
        "R05E dependency closure",
    )
    require(
        receipt.get("ok") is True
        and receipt.get("gdscript_direct_entry_count") == 4
        and receipt.get("gdscript_transitive_path_count") == 41
        and receipt.get("rust_build_path_count") == 25
        and receipt.get("process_and_audit_path_count") == 15
        and receipt.get("qualified_source_path_count")
        == EXPECTED_QUALIFIED_SOURCE_PATH_COUNT
        and receipt.get("qualified_source_path_sha256")
        == EXPECTED_QUALIFIED_SOURCE_PATH_SHA256
        and receipt.get("active_runtime_artifact_count") == 1
        and receipt.get("inactive_runtime_artifact_count") == 1
        and receipt.get("mutation_rejection_count") == 4
        and receipt.get("all_qualified_paths_lf_checkout_policy") is True
        and receipt.get("tracked_source_required") is require_tracked
        and isinstance(receipt.get("all_qualified_paths_tracked"), bool)
        and (
            not require_tracked
            or receipt.get("all_qualified_paths_tracked") is True
        )
        and receipt.get("model_construction_count") == 0
        and receipt.get("world_attempt_count") == 0
        and receipt.get("world_build_count") == 0
        and receipt.get("native_readback_count") == 0
        and receipt.get("solver_step_count") == 0
        and receipt.get("physics_state_modified") is False
        and receipt.get("physical_acceptance_authority") is False
        and receipt.get("release_authority") is False,
        "R05E dependency receipt failed strict reconciliation",
    )
    return receipt


def inspect_source_boundary(*, official_qualification: bool) -> dict[str, Any]:
    head = run_process(("git", "rev-parse", "HEAD"), timeout_seconds=30)
    origin_main = run_process(("git", "rev-parse", "origin/main"), timeout_seconds=30)
    branch = run_process(("git", "branch", "--show-current"), timeout_seconds=30)
    status = run_process(
        ("git", "status", "--porcelain=v1", "--untracked-files=all"),
        timeout_seconds=30,
    )
    require(
        head.returncode == 0
        and origin_main.returncode == 0
        and branch.returncode == 0
        and status.returncode == 0,
        "could not inspect the source boundary",
    )
    source_commit = head.stdout.strip()
    origin_commit = origin_main.stdout.strip()
    branch_name = branch.stdout.strip()
    clean = not status.stdout.strip()
    upstream_equal = source_commit == origin_commit
    live_equal = False
    if official_qualification:
        live = run_process(
            ("git", "ls-remote", "origin", "refs/heads/main"),
            timeout_seconds=60,
        )
        records = [line.split() for line in live.stdout.splitlines() if line.strip()]
        live_equal = (
            live.returncode == 0
            and len(records) == 1
            and len(records[0]) == 2
            and records[0][0] == source_commit
            and records[0][1] == "refs/heads/main"
        )
        require(
            branch_name == "main" and clean and upstream_equal and live_equal,
            "official qualification requires clean HEAD = origin/main = live main",
        )
    return {
        "source_commit": source_commit,
        "branch": branch_name,
        "worktree_clean": clean,
        "head_origin_main_equal": upstream_equal,
        "head_live_remote_main_equal": live_equal,
        "official_qualification_mode": official_qualification,
    }


def exact_keys(value: dict[str, Any], expected: set[str], label: str) -> None:
    require(set(value) == expected, f"{label}: exact key set drifted")


def validate_runtime_path_text(value: Any, label: str) -> str:
    require(isinstance(value, str), f"{label}: path must be a string")
    if sys.platform == "win32":
        require(
            value == value.lower() and "\\" not in value,
            f"{label}: Windows runtime identity path was not case-canonicalized",
        )
    return value


def validate_file_identity(value: Any, label: str) -> dict[str, Any]:
    require(isinstance(value, dict), f"{label}: identity must be an object")
    exact_keys(value, {"path", "raw_sha256", "byte_length", "version"}, label)
    path = Path(validate_runtime_path_text(value.get("path"), label))
    require(
        isinstance(value["path"], str)
        and path.is_absolute()
        and path.is_file()
        and isinstance(value["raw_sha256"], str)
        and value["raw_sha256"] == f"sha256:{sha256_hex(path)}"
        and isinstance(value["byte_length"], int)
        and not isinstance(value["byte_length"], bool)
        and value["byte_length"] == path.stat().st_size
        and value["byte_length"] > 0
        and isinstance(value["version"], str)
        and bool(value["version"].strip()),
        f"{label}: file, digest, length, or version drifted",
    )
    return value


def validate_rust_tool_identity(
    value: Any,
    *,
    label: str,
    expected_launcher: str,
) -> dict[str, Any]:
    require(isinstance(value, dict), f"{label}: identity must be an object")
    exact_keys(
        value,
        {
            "command_path",
            "command_resolved_launcher_path",
            "effective_path",
            "effective_raw_sha256",
            "effective_byte_length",
            "version",
        },
        label,
    )
    command_path = Path(
        validate_runtime_path_text(value.get("command_path"), f"{label} command")
    )
    resolved_launcher = validate_runtime_path_text(
        value.get("command_resolved_launcher_path"), f"{label} resolved launcher"
    )
    effective_path = Path(
        validate_runtime_path_text(value.get("effective_path"), f"{label} effective")
    )
    require(
        isinstance(value["command_path"], str)
        and command_path.is_absolute()
        and command_path.is_file()
        and resolved_launcher == expected_launcher
        and isinstance(value["effective_path"], str)
        and effective_path.is_absolute()
        and effective_path.is_file()
        and isinstance(value["effective_raw_sha256"], str)
        and value["effective_raw_sha256"] == f"sha256:{sha256_hex(effective_path)}"
        and isinstance(value["effective_byte_length"], int)
        and not isinstance(value["effective_byte_length"], bool)
        and value["effective_byte_length"] == effective_path.stat().st_size
        and value["effective_byte_length"] > 0
        and isinstance(value["version"], str)
        and bool(value["version"].strip()),
        f"{label}: launcher, effective binary, digest, length, or version drifted",
    )
    return value


def validate_runtime_identity_projection(value: Any) -> dict[str, Any]:
    require(isinstance(value, dict), "runtime identity projection must be an object")
    exact_keys(
        value,
        {"schema_version", "identity_sha256", "identity"},
        "runtime identity projection",
    )
    identity = value.get("identity")
    require(isinstance(identity, dict), "runtime identity must be an object")
    exact_keys(
        identity,
        {
            "schema_version",
            "godot",
            "active_adapter",
            "rustup",
            "cargo",
            "rustc",
            "powershell",
            "git",
            "host",
            "build_environment",
        },
        "runtime identity",
    )
    canonical = json.dumps(
        identity, ensure_ascii=False, separators=(",", ":"), sort_keys=True
    )
    require(
        value.get("schema_version")
        == "sporespore_qsdk_r05e_runtime_identity_projection_v1"
        and identity.get("schema_version") == "sporespore_qsdk_r05e_runtime_identity_v1"
        and value.get("identity_sha256")
        == "sha256:" + hashlib.sha256(canonical.encode("utf-8")).hexdigest(),
        "runtime identity schema or canonical digest drifted",
    )
    godot = validate_file_identity(identity.get("godot"), "Godot runtime")
    rustup = validate_file_identity(identity.get("rustup"), "Rustup runtime")
    validate_file_identity(identity.get("powershell"), "PowerShell runtime")
    validate_file_identity(identity.get("git"), "Git runtime")
    validate_rust_tool_identity(
        identity.get("cargo"), label="Cargo runtime", expected_launcher=rustup["path"]
    )
    validate_rust_tool_identity(
        identity.get("rustc"), label="Rust compiler", expected_launcher=rustup["path"]
    )
    adapter = identity.get("active_adapter")
    require(isinstance(adapter, dict), "active adapter identity must be an object")
    exact_keys(
        adapter,
        {"relative_path", "raw_sha256", "byte_length"},
        "active adapter identity",
    )
    adapter_path = ROOT / adapter["relative_path"]
    require(
        adapter.get("relative_path") == "sdk/target/debug/sporespore_godot_adapter.dll"
        and adapter_path.is_file()
        and adapter.get("raw_sha256") == f"sha256:{sha256_hex(adapter_path)}"
        and isinstance(adapter.get("byte_length"), int)
        and not isinstance(adapter.get("byte_length"), bool)
        and adapter.get("byte_length") == adapter_path.stat().st_size
        and adapter.get("byte_length") > 0,
        "active adapter runtime binding drifted",
    )
    require(
        godot["version"].startswith("4.7.stable")
        and "host: x86_64-pc-windows-msvc" in identity["cargo"]["version"]
        and "host: x86_64-pc-windows-msvc" in identity["rustc"]["version"],
        "runtime version or target triple drifted",
    )
    host = identity.get("host")
    require(isinstance(host, dict), "host identity must be an object")
    exact_keys(
        host,
        {
            "os_description",
            "os_architecture",
            "process_architecture",
            "framework_description",
            "processor_identifier",
            "logical_processor_count",
        },
        "host identity",
    )
    require(
        all(
            isinstance(host[key], str) and host[key]
            for key in host
            if key != "logical_processor_count"
        )
        and isinstance(host["logical_processor_count"], int)
        and not isinstance(host["logical_processor_count"], bool)
        and host["logical_processor_count"] > 0,
        "host identity value drifted",
    )
    build_environment = identity.get("build_environment")
    require(isinstance(build_environment, dict), "build environment must be an object")
    exact_keys(
        build_environment,
        {
            "cargo_target_dir",
            "cargo_build_target",
            "rustflags",
            "rustc_wrapper",
            "rustup_toolchain",
            "rustup_active_toolchain",
        },
        "build environment",
    )
    require(
        all(isinstance(item, str) for item in build_environment.values())
        and bool(build_environment["rustup_active_toolchain"]),
        "build environment value drifted",
    )
    return value


def validate_supervisor_bundle(
    bundle: dict[str, Any],
    *,
    campaign_id: str,
    gate_id: str,
    schema_version: str,
    expected_morphologies: int,
    expected_worlds: int,
    expected_sources: int,
) -> dict[str, Any]:
    source_gate = bundle.get("exact_finite_morphology_source_gate")
    operation_lock = bundle.get("operation_lock")
    require(
        isinstance(source_gate, dict), f"{campaign_id}: source gate receipt missing"
    )
    require(
        isinstance(operation_lock, dict),
        f"{campaign_id}: operation lock receipt missing",
    )
    require(
        bundle.get("schema_version") == schema_version
        and bundle.get("campaign_id") == campaign_id
        and bundle.get("gate_id") == gate_id
        and bundle.get("controller_policy_id") == EXPECTED_POLICY_ID
        and bundle.get("candidate_policy_digest") == EXPECTED_POLICY_DIGEST,
        f"{campaign_id}: preflight identity drifted",
    )
    require(
        bundle.get("full_integrity_passed") is True
        and bundle.get("declared_policy_runtime_boundary_count") == 8
        and bundle.get("declared_policy_runtime_boundaries_passed") is True
        and bundle.get("worst_case_declared_policy_runtime_horizon_step_count") == 3232
        and bundle.get("worst_case_declared_policy_runtime_horizon_command_count")
        == 25856,
        f"{campaign_id}: production policy-semantic gate failed",
    )
    require(
        bundle.get("expected_morphology_count") == expected_morphologies
        and bundle.get("expected_world_count") == expected_worlds
        and bundle.get("entrypoint_cell_count") == expected_worlds
        and bundle.get("exact_candidate_full_authority_start_count") == expected_worlds
        and bundle.get("exact_candidate_declared_policy_runtime_boundary_count")
        == expected_worlds
        and bundle.get("runner_report_synthetic_cell_count") == expected_worlds
        and bundle.get("runner_report_source_file_count") == expected_sources,
        f"{campaign_id}: exact population or source inventory drifted",
    )
    require(
        bundle.get("dependency_manifest_schema")
        == "sporespore_qsdk_r05e_dependency_manifest_v1"
        and bundle.get("complete_transitive_dependency_manifest_reconciled") is True
        and bundle.get("dependency_gdscript_direct_entry_count") == 4
        and bundle.get("dependency_gdscript_transitive_path_count") == 41
        and bundle.get("dependency_rust_build_path_count") == 25
        and bundle.get("dependency_process_and_audit_path_count") == 15
        and bundle.get("qualified_source_path_count")
        == EXPECTED_QUALIFIED_SOURCE_PATH_COUNT
        and bundle.get("qualified_source_path_sha256")
        == EXPECTED_QUALIFIED_SOURCE_PATH_SHA256,
        f"{campaign_id}: complete transitive dependency projection drifted",
    )
    require(
        bundle.get("runner_report_serialization_passed") is True
        and bundle.get("perfect_all_zero_production_aggregate_gate_passed") is True
        and bundle.get("nonzero_ordered_dictionary_canary_passed") is True
        and bundle.get("worker_physical_authorization_required") is True
        and bundle.get("worker_authorization_preflight_passed") is True
        and bundle.get("mismatched_worker_authorization_token_refused") is True
        and bundle.get("worker_authorization_type_mutation_refused") is True
        and bundle.get("direct_physical_worker_bypass_refused") is True,
        f"{campaign_id}: runner or authorization negative control failed",
    )
    require(
        source_gate.get("passed") is True
        and source_gate.get("schema_version")
        == "sporespore_qsdk_r05e_exact_finite_morphology_source_zero_world_v1"
        and source_gate.get("official_descriptor_compile_count") == 12
        and source_gate.get("development_ghost_descriptor_compile_count") == 1
        and source_gate.get("negative_control_count") == 32
        and source_gate.get("negative_controls_passed") == 32
        and source_gate.get("actual_world_build_count") == 0
        and source_gate.get("solver_step_count") == 0
        and source_gate.get("locomotion_outcome_exposed") is False
        and source_gate.get("physical_acceptance_authority") is False,
        f"{campaign_id}: exact source or mutation gate failed",
    )
    require(
        operation_lock.get("schema_version")
        == "sporespore_locomotion_operation_lock_receipt_v1"
        and operation_lock.get("acquired") is True
        and operation_lock.get("role") == "conformance"
        and operation_lock.get("test_only") is False
        and operation_lock.get("abandoned_owner_recovered") is False
        and operation_lock.get("physical_acceptance_authority") is False,
        f"{campaign_id}: qualification was not serialized",
    )
    require(
        bundle.get("actual_world_build_count") == 0
        and bundle.get("scene_tree_insertion_count") == 0
        and bundle.get("physics_state_modified") is False
        and bundle.get("locomotion_outcome_exposed") is False
        and bundle.get("physical_acceptance_authority") is False,
        f"{campaign_id}: zero-world boundary was crossed",
    )
    return validate_runtime_identity_projection(
        bundle.get("runtime_identity_projection")
    )


def run_supervisor_preflights(pwsh: str, godot: Path) -> dict[str, Any]:
    specifications = (
        {
            "wrapper": ROOT / "sdk/run_qsdk_r05e_development_route_ghost.ps1",
            "marker": "QSDK_R05E_DEVELOPMENT_GHOST_PREFLIGHT_BUNDLE ",
            "campaign_id": "QSDK-R05E-DEVELOPMENT-ROUTE-GHOST",
            "gate_id": "QSDK-R05E-GHOST",
            "schema_version": "sporespore_qsdk_r05e_development_ghost_preflight_bundle_v1",
            "morphologies": 1,
            "worlds": 1,
            "sources": EXPECTED_QUALIFIED_SOURCE_PATH_COUNT,
        },
        {
            "wrapper": ROOT / "sdk/run_qsdk_r05e_exact_finite_morphology.ps1",
            "marker": "QSDK_R05E_EXACT_FINITE_PREFLIGHT_BUNDLE ",
            "campaign_id": "QSDK-R05E-EXACT-FINITE-MORPHOLOGY-VALIDATION",
            "gate_id": "QSDK-R05E",
            "schema_version": "sporespore_qsdk_r05e_exact_finite_preflight_bundle_v1",
            "morphologies": 12,
            "worlds": 36,
            "sources": EXPECTED_QUALIFIED_SOURCE_PATH_COUNT,
        },
    )
    runtime_identities: list[dict[str, Any]] = []
    for ordinal, specification in enumerate(specifications):
        supervisor_pwsh = pwsh
        if sys.platform == "win32" and ordinal == 1:
            suffix = pwsh[-4:]
            require(
                suffix.lower() == ".exe",
                "R05E PowerShell path lacks the expected .exe suffix",
            )
            alternate_suffix = ".exe" if suffix != ".exe" else ".EXE"
            supervisor_pwsh = pwsh[:-4] + alternate_suffix
            require(
                supervisor_pwsh != pwsh and Path(supervisor_pwsh).is_file(),
                "R05E Windows executable-case control could not be constructed",
            )
        result = run_process(
            (
                supervisor_pwsh,
                "-NoLogo",
                "-NoProfile",
                "-File",
                specification["wrapper"],
                "-Godot",
                godot,
                "-PreflightOnly",
            ),
            timeout_seconds=900,
        )
        require(
            result.returncode == 0,
            f"{specification['campaign_id']}: supervisor preflight failed: "
            f"{(result.stdout + result.stderr)[-4000:]}",
        )
        require(
            "REPORT=" not in result.stdout,
            f"{specification['campaign_id']}: preflight retained a report",
        )
        bundle = parse_marker(
            result.stdout,
            str(specification["marker"]),
            str(specification["campaign_id"]),
        )
        runtime_identities.append(
            validate_supervisor_bundle(
                bundle,
                campaign_id=str(specification["campaign_id"]),
                gate_id=str(specification["gate_id"]),
                schema_version=str(specification["schema_version"]),
                expected_morphologies=int(specification["morphologies"]),
                expected_worlds=int(specification["worlds"]),
                expected_sources=int(specification["sources"]),
            )
        )
    require(
        len(runtime_identities) == 2 and runtime_identities[0] == runtime_identities[1],
        "R05E supervisor runtime identities were not exact",
    )
    return runtime_identities[0]


def run_missing_authority_controls(pwsh: str, godot: Path) -> None:
    campaigns = (
        "QSDK-R05E-DEVELOPMENT-ROUTE-GHOST",
        "QSDK-R05E-EXACT-FINITE-MORPHOLOGY-VALIDATION",
    )
    with tempfile.TemporaryDirectory(
        prefix="sporespore-r05e-zero-world-audit-"
    ) as raw_root:
        scratch = Path(raw_root)
        for ordinal, campaign_id in enumerate(campaigns):
            missing_authority = scratch / f"missing-authority-{ordinal}.json"
            output = scratch / f"forbidden-output-{ordinal}" / "report.json"
            result = run_process(
                (
                    pwsh,
                    "-NoLogo",
                    "-NoProfile",
                    "-File",
                    GENERIC_RUNNER_PATH,
                    "-Godot",
                    godot,
                    "-CampaignId",
                    campaign_id,
                    "-ExecutionAuthority",
                    missing_authority,
                    "-Output",
                    output,
                ),
                timeout_seconds=120,
            )
            combined = result.stdout + result.stderr
            require(
                result.returncode != 0, f"{campaign_id}: missing authority was accepted"
            )
            require(
                "physical execution authority does not exist" in combined,
                f"{campaign_id}: missing authority failed at an unexpected boundary",
            )
            require(
                not output.exists() and not output.parent.exists(),
                f"{campaign_id}: refusal created retained state",
            )


def run_final_operation_lock_probe(pwsh: str) -> None:
    script = "\n".join(
        (
            "$ErrorActionPreference = 'Stop'",
            f". '{OPERATION_LOCK_PATH.as_posix()}'",
            "$receipt = Enter-SporeSporeLocomotionOperationLock -Role conformance",
            "if (-not [bool]$receipt.acquired -or [bool]$receipt.abandoned_owner_recovered) { exit 31 }",
            "Exit-SporeSporeLocomotionOperationLock -Receipt $receipt",
            "if (-not [bool]$receipt.released) { exit 32 }",
            "Write-Output 'QSDK_R05E_FINAL_OPERATION_LOCK_PROBE_PASS'",
        )
    )
    result = run_process(
        (pwsh, "-NoLogo", "-NoProfile", "-Command", script),
        timeout_seconds=30,
    )
    require(
        result.returncode == 0
        and result.stdout.count("QSDK_R05E_FINAL_OPERATION_LOCK_PROBE_PASS") == 1,
        f"R05E final operation-lock probe failed: {(result.stdout + result.stderr)[-2000:]}",
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, default=DEFAULT_GODOT)
    parser.add_argument("--official-qualification", action="store_true")
    arguments = parser.parse_args()
    try:
        require(
            ROOT == Path(r"C:\Users\Cole\CodeStuff\games\SporeSpore"),
            "canonical root changed",
        )
        require(
            arguments.godot.is_file(), f"Godot console is missing: {arguments.godot}"
        )
        pwsh = shutil.which("pwsh")
        require(pwsh is not None, "pwsh is not available")
        remote = run_process(("git", "remote", "get-url", "origin"), timeout_seconds=30)
        require(
            remote.returncode == 0
            and remote.stdout.strip() == "https://github.com/Slagathore/sporespore.git",
            "canonical origin changed",
        )
        source_projection = inspect_source_boundary(
            official_qualification=arguments.official_qualification
        )
        validate_preregistrations()
        run_r05d_audit()
        dependency_receipt = run_dependency_audit(
            require_tracked=arguments.official_qualification
        )
        run_authority_contract_test(pwsh)
        runtime_identity_projection = run_supervisor_preflights(pwsh, arguments.godot)
        run_missing_authority_controls(pwsh, arguments.godot)
        run_final_operation_lock_probe(pwsh)
        receipt = {
            "schema_version": "sporespore_qsdk_r05e_zero_world_implementation_audit_v1",
            "gate_id": "QSDK-R05E",
            "ledger_scope": {
                "subsystem": "walking",
                "engine_scope": "godot_jolt",
                "authority_mode": "prospective_zero_world_implementation_audit",
                "question_class": "development",
            },
            "ok": True,
            **source_projection,
            "r05d_design_audit_passed": True,
            "dependency_closure_audit_passed": True,
            "dependency_gdscript_direct_entry_count": dependency_receipt[
                "gdscript_direct_entry_count"
            ],
            "dependency_gdscript_transitive_path_count": dependency_receipt[
                "gdscript_transitive_path_count"
            ],
            "dependency_rust_build_path_count": dependency_receipt[
                "rust_build_path_count"
            ],
            "dependency_process_and_audit_path_count": dependency_receipt[
                "process_and_audit_path_count"
            ],
            "qualified_source_path_count": dependency_receipt[
                "qualified_source_path_count"
            ],
            "qualified_source_path_sha256": dependency_receipt[
                "qualified_source_path_sha256"
            ],
            "dependency_mutation_rejection_count": dependency_receipt[
                "mutation_rejection_count"
            ],
            "dependency_all_qualified_paths_lf_checkout_policy": dependency_receipt[
                "all_qualified_paths_lf_checkout_policy"
            ],
            "dependency_all_qualified_paths_tracked": dependency_receipt[
                "all_qualified_paths_tracked"
            ],
            "dependency_tracked_source_required": dependency_receipt[
                "tracked_source_required"
            ],
            "runtime_identity_projection": runtime_identity_projection,
            "runtime_identity_exact_across_supervisors": True,
            "qualification_tool_identity": qualification_tool_identity(),
            "preregistration_count": 2,
            "supervisor_preflight_count": 2,
            "serialized_conformance_lock_count": 2,
            "final_operation_lock_release_probe_passed": True,
            "official_descriptor_compile_count_per_supervisor": 12,
            "development_ghost_descriptor_compile_count_per_supervisor": 1,
            "source_mutation_control_count_per_supervisor": 32,
            "worker_authorization_type_mutation_refusal_count": 2,
            "authority_contract_positive_repository_graph_count": 2,
            "authority_contract_content_mutation_rejection_count": 35,
            "authority_contract_repository_binding_rejection_count": 5,
            "physical_missing_authority_refusal_count": 2,
            "held_out_locomotion_outcome_exposure_count": 0,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "native_readback_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
            "physical_execution_authorized": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        }
        print(PASS_MARKER + json.dumps(receipt, sort_keys=True, separators=(",", ":")))
        return 0
    except (AuditFailure, KeyError, IndexError, TypeError, OSError) as exc:
        print(f"QSDK_R05E_ZERO_WORLD_IMPLEMENTATION_FAIL {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
