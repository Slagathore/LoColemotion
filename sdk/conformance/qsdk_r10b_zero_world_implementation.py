#!/usr/bin/env python3
"""Qualify the prospective QSDK-R10B implementation without opening a world."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
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
DESIGN_PATH = (
    ROOT / "sdk/qsdk_r10a_bounded_upright_push_recovery_successor_design_v1.json"
)
DESIGN_AUDIT_PATH = (
    ROOT / "sdk/conformance/qsdk_r10a_bounded_upright_push_recovery_successor_design.py"
)
L2_DESIGN_PATH = (
    ROOT / "sdk/qsdk_r10b_l2_exact_quaternion_projection_successor_design_v1.json"
)
L2_DESIGN_AUDIT_PATH = (
    ROOT
    / "sdk/conformance/qsdk_r10b_l2_exact_quaternion_projection_successor_design.py"
)
L3_DESIGN_PATH = (
    ROOT
    / "sdk/qsdk_r10b_l3_serialization_stable_trace_validation_successor_design_v1.json"
)
L3_DESIGN_AUDIT_PATH = (
    ROOT
    / "sdk/conformance/qsdk_r10b_l3_serialization_stable_trace_validation_successor_design.py"
)
L2_PHYSICAL_INVALID_CLOSURE_PATH = (
    ROOT / "sdk/qsdk_r10b_l2_development_route_ghost_physical_invalid_closure_v1.json"
)
L2_PHYSICAL_INVALID_AUDIT_PATH = (
    ROOT / "sdk/conformance/qsdk_r10b_l2_development_route_ghost_physical_invalid.py"
)
L2_PHYSICAL_ROOT = Path(
    r"C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\qsdk-r10b-development-route-ghost-physical-49edaa8d95c2"
)
L2_RETAINED_TRACE_PATH = L2_PHYSICAL_ROOT / "baseline_s50300/godot.log"
DEPENDENCY_AUDIT_PATH = ROOT / "sdk/conformance/qsdk_r10b_dependency_closure.py"
AUTHORITY_MATERIALIZER_PATH = (
    ROOT / "sdk/conformance/qsdk_r10b_authority_materializer.py"
)
SUPERVISOR_PATH = ROOT / "sdk/run_qsdk_r10b_bounded_upright_push_recovery.ps1"
QUALIFICATION_WRAPPER_PATH = ROOT / "sdk/qsdk_r10b_zero_world_qualification.ps1"
WORKER_PATH = ROOT / "tests/test_sdk_qsdk_r10b_bounded_upright_push_recovery_worker.gd"
OPERATION_LOCK_PATH = ROOT / "sdk/locomotion_operation_lock.ps1"
ACTIVE_ADAPTER_PATH = ROOT / "sdk/target/debug/sporespore_godot_adapter.dll"
EXPECTED_DESIGN_BYTES = 25_836
EXPECTED_DESIGN_SHA256 = (
    "f5738803e65d25b3225c0b054ced5f21613650f2a5aa1d79e76b700ad7d36f66"
)
EXPECTED_L2_DESIGN_BYTES = 10_199
EXPECTED_L2_DESIGN_SHA256 = (
    "5acc66edbc274616898b25ede236207ff77ca92e596ffbf171472ca9dfc7a478"
)
EXPECTED_L3_DESIGN_BYTES = 12_654
EXPECTED_L3_DESIGN_SHA256 = (
    "ad8d147ee5a508aee3104fb346dcedde692568a9f9093a73e3bdbca638901f76"
)
EXPECTED_L2_PHYSICAL_INVALID_CLOSURE_BYTES = 20_839
EXPECTED_L2_PHYSICAL_INVALID_CLOSURE_SHA256 = (
    "5f6242e2cab9658a54c673717596c7649fac785136d29d8798192bfc0f60babb"
)
EXPECTED_QUALIFIED_SOURCE_PATH_COUNT = 85
EXPECTED_QUALIFIED_SOURCE_PATH_SHA256 = (
    "sha256:4bfe0e8a7cbdb920655cb3082b6e2a7182f4f05ac76e24142a73acca640a7a8d"
)
DEFAULT_GODOT = Path(
    r"C:\Users\Cole\CodeStuff\Misc\Godot\Godot_v4.7-stable_mono_win64_console.exe"
)
PASS_MARKER = "QSDK_R10B_ZERO_WORLD_IMPLEMENTATION_PASS "
SOURCE_MARKER = "QSDK_R10B_BOUNDED_UPRIGHT_PUSH_RECOVERY_SOURCE_ZERO_WORLD "
L3_RETAINED_TRACE_MARKER = "QSDK_R10B_L3_RETAINED_TRACE_VALIDATION "
CELL_MARKER = "QSDK_R10B_PHYSICAL_CELL "
SUPERVISOR_MARKER = "QSDK_R10B_SUPERVISOR_ZERO_WORLD_PASS "
FORMATTED_GDSCRIPT_PATHS = (
    ROOT / "sdk/adapters/godot/gdscript/exported_scalar_validation_v1.gd",
    ROOT / "sdk/adapters/godot/gdscript/quaternion_scalar_projection_v1.gd",
    ROOT
    / "sdk/adapters/godot/gdscript/quaternion_scalar_projection_validation_v2.gd",
    ROOT / "scripts/lab/gait/qsdk_r10b_bounded_upright_push_recovery.gd",
    ROOT / "tests/test_sdk_qsdk_r10b_bounded_upright_push_recovery_source.gd",
    ROOT / "tests/test_sdk_qsdk_r10b_bounded_upright_push_recovery_worker.gd",
    ROOT / "tests/test_sdk_qsdk_r10b_l3_retained_trace_validation.gd",
)
ZERO_COUNTERS = (
    "model_construction_count",
    "world_attempt_count",
    "world_build_count",
    "native_readback_count",
    "solver_step_count",
)


class AuditFailure(RuntimeError):
    """The prospective implementation failed exact zero-world reconciliation."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AuditFailure(message)


def sha256_hex(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


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


def require_zero_world(receipt: Mapping[str, Any], label: str) -> None:
    require(receipt.get("ok") is True, f"{label}: receipt did not pass")
    for counter in ZERO_COUNTERS:
        require(receipt.get(counter) == 0, f"{label}: {counter} was not zero")
    require(
        receipt.get("scene_tree_insertion_count") == 0,
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
    top = run_process(("git", "rev-parse", "--show-toplevel"), timeout_seconds=30)
    remote = run_process(("git", "remote", "get-url", "origin"), timeout_seconds=30)
    head = run_process(("git", "rev-parse", "HEAD"), timeout_seconds=30)
    origin = run_process(("git", "rev-parse", "origin/main"), timeout_seconds=30)
    branch = run_process(("git", "branch", "--show-current"), timeout_seconds=30)
    status = run_process(
        ("git", "status", "--porcelain=v1", "--untracked-files=all"),
        timeout_seconds=30,
    )
    require(
        all(
            item.returncode == 0 for item in (top, remote, head, origin, branch, status)
        ),
        "could not inspect the repository source boundary",
    )
    require(
        Path(top.stdout.strip()).resolve() == ROOT.resolve(), "canonical root changed"
    )
    require(remote.stdout.strip() == EXPECTED_REMOTE, "canonical origin changed")
    source_commit = head.stdout.strip()
    origin_commit = origin.stdout.strip()
    branch_name = branch.stdout.strip()
    clean = not status.stdout.strip()
    upstream_equal = source_commit == origin_commit
    live_equal = False
    if official_qualification:
        live = run_process(
            ("git", "ls-remote", "origin", "refs/heads/main"), timeout_seconds=60
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


def run_design_audit() -> int:
    require(
        DESIGN_PATH.stat().st_size == EXPECTED_DESIGN_BYTES,
        "R10A design length changed",
    )
    require(
        sha256_hex(DESIGN_PATH) == EXPECTED_DESIGN_SHA256, "R10A design digest changed"
    )
    specification = importlib.util.spec_from_file_location(
        "qsdk_r10a_frozen_design_audit", DESIGN_AUDIT_PATH
    )
    require(
        specification is not None and specification.loader is not None,
        "R10A design audit module could not be loaded",
    )
    module = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(module)

    def invoke_r10a(function: Any, *args: Any, **kwargs: Any) -> Any:
        try:
            return function(*args, **kwargs)
        except module.AuditFailure as exc:
            raise AuditFailure(f"R10A frozen design audit failed: {exc}") from exc

    raw_design = DESIGN_PATH.read_bytes()
    design = invoke_r10a(module.read_json, raw_design, "R10A design")
    loaded: dict[str, dict[str, Any]] = {}
    for entry in design.get("bound_authorities", []):
        require(isinstance(entry, dict), "R10A bound authority is not an object")
        role = entry.get("role")
        raw_path = entry.get("path")
        require(isinstance(role, str) and role, "R10A bound authority role is invalid")
        require(isinstance(raw_path, str) and raw_path, f"{role}: path is invalid")
        if entry.get("path_kind") == "absolute_durable_evidence":
            authority_path = Path(raw_path)
            require(authority_path.is_file(), f"{role}: durable evidence is missing")
            raw = authority_path.read_bytes()
        else:
            require(
                entry.get("source_commit") == module.PARENT_COMMIT,
                f"{role}: frozen source commit changed",
            )
            completed = subprocess.run(
                ("git", "show", f"{module.PARENT_COMMIT}:{raw_path}"),
                cwd=ROOT,
                check=False,
                capture_output=True,
            )
            require(
                completed.returncode == 0, f"{role}: frozen Git blob is unavailable"
            )
            raw = completed.stdout
            require(
                module.parent_blob_oid(module.PARENT_COMMIT, raw_path)
                == entry.get("git_blob_oid"),
                f"{role}: declared frozen Git blob changed",
            )
        require(
            len(raw) == entry.get("byte_length"), f"{role}: frozen byte length changed"
        )
        require(
            "sha256:" + module.sha256_hex(raw) == entry.get("raw_sha256"),
            f"{role}: frozen SHA-256 changed",
        )
        if entry.get("path_kind") != "absolute_durable_evidence":
            require(
                module.git_blob_oid(raw) == entry.get("git_blob_oid"),
                f"{role}: reconstructed Git blob changed",
            )
        authority = (
            invoke_r10a(module.read_json, raw, role)
            if Path(raw_path).suffix.lower() == ".json"
            else {}
        )
        loaded[role] = authority
        expected_paths = entry.get("expected_paths", {})
        require(isinstance(expected_paths, dict), f"{role}: expected paths are invalid")
        if expected_paths:
            selected = invoke_r10a(module.selected_authority_object, role, authority)
            for dotted_path, expected in expected_paths.items():
                require(
                    module.exact_equal(
                        invoke_r10a(module.dotted, selected, dotted_path), expected
                    ),
                    f"{role}: frozen expected path changed at {dotted_path}",
                )
    invoke_r10a(module.validate_design, design, verify_bindings=False, preloaded=loaded)
    mutation_count = invoke_r10a(module.mutation_controls, design, loaded)
    require(mutation_count == 19, "R10A design mutation-control count changed")
    return mutation_count


def run_l2_design_audit() -> dict[str, Any]:
    require(
        L2_DESIGN_PATH.stat().st_size == EXPECTED_L2_DESIGN_BYTES,
        "R10B-L2 design length changed",
    )
    require(
        sha256_hex(L2_DESIGN_PATH) == EXPECTED_L2_DESIGN_SHA256,
        "R10B-L2 design digest changed",
    )
    result = run_process(
        (sys.executable, "-B", L2_DESIGN_AUDIT_PATH), timeout_seconds=180
    )
    require(
        result.returncode == 0,
        f"R10B-L2 successor design audit failed: "
        f"{(result.stdout + result.stderr)[-4000:]}",
    )
    receipt = parse_marker(
        result.stdout,
        "QSDK_R10B_L2_SUCCESSOR_DESIGN_PASS ",
        "R10B-L2 successor design",
    )
    require_zero_world(receipt, "R10B-L2 successor design")
    require(
        receipt.get("schema_version")
        == "sporespore_qsdk_r10b_l2_successor_design_audit_v1"
        and receipt.get("repair_id") == "QSDK-R10B-L2"
        and receipt.get("bound_authority_count") == 5
        and receipt.get("design_mutation_rejection_count") == 8
        and receipt.get("retained_raw_control_count") == 2
        and receipt.get("additional_nonidentity_control_count") == 2
        and receipt.get("zero_quaternion_refusal_control_count") == 1
        and receipt.get("l1_closure_audit_passed") is True
        and receipt.get("l1_physical_identity_consumed") is True
        and receipt.get("l1_same_identity_rerun_permitted") is False
        and receipt.get("controller_changed") is False
        and receipt.get("behavior_threshold_changed") is False
        and receipt.get("quaternion_validator_tolerance_changed") is False,
        "R10B-L2 successor design receipt drifted",
    )
    return receipt


def run_l3_design_audit() -> dict[str, Any]:
    require(
        L3_DESIGN_PATH.stat().st_size == EXPECTED_L3_DESIGN_BYTES,
        "R10B-L3 design length changed",
    )
    require(
        sha256_hex(L3_DESIGN_PATH) == EXPECTED_L3_DESIGN_SHA256,
        "R10B-L3 design digest changed",
    )
    result = run_process(
        (sys.executable, "-B", L3_DESIGN_AUDIT_PATH), timeout_seconds=180
    )
    require(
        result.returncode == 0,
        f"R10B-L3 successor design audit failed: "
        f"{(result.stdout + result.stderr)[-4000:]}",
    )
    receipt = parse_marker(
        result.stdout,
        "QSDK_R10B_L3_SUCCESSOR_DESIGN_PASS ",
        "R10B-L3 successor design",
    )
    require_zero_world(
        {**receipt, "scene_tree_insertion_count": 0},
        "R10B-L3 successor design",
    )
    require(
        receipt.get("schema_version")
        == "sporespore_qsdk_r10b_l3_successor_design_audit_v1"
        and receipt.get("repair_id") == "QSDK-R10B-L3"
        and receipt.get("bound_authority_count") == 5
        and receipt.get("design_mutation_rejection_count") == 12
        and receipt.get("within_allowance_positive_control_count") == 4
        and receipt.get("outside_allowance_refusal_control_count") == 4
        and receipt.get("nonfinite_refusal_control_count") == 4
        and receipt.get("type_refusal_control_count") == 2
        and receipt.get("operation_derived_event_budget") == 32
        and receipt.get("predecessor_closure_audit_passed") is True
        and receipt.get("predecessor_physical_identity_consumed") is True
        and receipt.get("predecessor_valid_behavior_result_count") == 0
        and receipt.get("behavior_threshold_changed") is False
        and receipt.get("quaternion_length_tolerance_changed") is False
        and receipt.get("task_axis_unit_tolerance_changed") is False,
        "R10B-L3 successor design receipt drifted",
    )
    return receipt


def run_l2_physical_invalid_closure_audit() -> dict[str, Any]:
    require(
        L2_PHYSICAL_INVALID_CLOSURE_PATH.stat().st_size
        == EXPECTED_L2_PHYSICAL_INVALID_CLOSURE_BYTES,
        "R10B-L2 physical-invalid closure length changed",
    )
    require(
        sha256_hex(L2_PHYSICAL_INVALID_CLOSURE_PATH)
        == EXPECTED_L2_PHYSICAL_INVALID_CLOSURE_SHA256,
        "R10B-L2 physical-invalid closure digest changed",
    )
    result = run_process(
        (sys.executable, "-B", L2_PHYSICAL_INVALID_AUDIT_PATH),
        timeout_seconds=180,
    )
    require(
        result.returncode == 0,
        f"R10B-L2 physical-invalid closure audit failed: "
        f"{(result.stdout + result.stderr)[-4000:]}",
    )
    receipt = parse_marker(
        result.stdout,
        "QSDK_R10B_L2_PHYSICAL_INVALID_CLOSURE_PASS ",
        "R10B-L2 physical-invalid closure",
    )
    require(
        receipt.get("schema_version")
        == "sporespore_qsdk_r10b_l2_development_route_ghost_physical_invalid_closure_audit_v1"
        and receipt.get("gate_id") == "QSDK-R10B"
        and receipt.get("repair_id") == "QSDK-R10B-L2"
        and receipt.get("closure_id") == "QSDK-R10B-L2-P1"
        and receipt.get("ok") is True
        and receipt.get("physical_identity_consumed") is True
        and receipt.get("same_identity_rerun_permitted") is False
        and receipt.get("valid_behavior_result_count") == 0
        and receipt.get("push_world_attempt_count") == 0
        and receipt.get("selected_successor_id") == "QSDK-R10B-L3"
        and receipt.get("retained_world_attempt_count") == 1
        and receipt.get("retained_world_build_count") == 1
        and receipt.get("retained_trace_row_count") == 2640
        and receipt.get("projection_receipt_exact_failure_count") == 2640
        and receipt.get("float32_task_axis_unit_failure_count") == 2640
        and receipt.get("exported_scalar_task_axis_unit_failure_count") == 0
        and receipt.get("closure_mutation_rejection_count") == 10
        and receipt.get("audit_model_construction_count") == 0
        and receipt.get("audit_world_attempt_count") == 0
        and receipt.get("audit_world_build_count") == 0
        and receipt.get("audit_native_readback_count") == 0
        and receipt.get("audit_solver_step_count") == 0
        and receipt.get("audit_physics_state_modified") is False
        and receipt.get("physical_acceptance_authority") is False
        and receipt.get("release_authority") is False,
        "R10B-L2 physical-invalid closure receipt drifted",
    )
    return receipt


def run_dependency_audit(*, require_tracked: bool) -> dict[str, Any]:
    command: tuple[str | Path, ...] = (sys.executable, "-B", DEPENDENCY_AUDIT_PATH)
    if require_tracked:
        command = (*command, "--require-tracked")
    result = run_process(command, timeout_seconds=120)
    require(
        result.returncode == 0,
        f"R10B dependency closure failed: {(result.stdout + result.stderr)[-4000:]}",
    )
    receipt = parse_marker(
        result.stdout, "QSDK_R10B_DEPENDENCY_CLOSURE_PASS ", "R10B dependency closure"
    )
    require(
        receipt.get("schema_version")
        == "sporespore_qsdk_r10b_dependency_closure_zero_world_v4"
        and receipt.get("gdscript_direct_entry_count") == 3
        and receipt.get("gdscript_transitive_path_count") == 41
        and receipt.get("rust_build_path_count") == 25
        and receipt.get("process_and_audit_path_count") == 19
        and receipt.get("qualified_source_path_count")
        == EXPECTED_QUALIFIED_SOURCE_PATH_COUNT
        and receipt.get("qualified_source_path_sha256")
        == EXPECTED_QUALIFIED_SOURCE_PATH_SHA256
        and receipt.get("active_runtime_artifact_path")
        == "sdk/target/debug/sporespore_godot_adapter.dll"
        and receipt.get("inactive_runtime_artifact_count") == 1
        and receipt.get("mutation_rejection_count") == 4
        and receipt.get("all_qualified_paths_lf_checkout_policy") is True
        and receipt.get("tracked_source_required") is require_tracked
        and isinstance(receipt.get("all_qualified_paths_tracked"), bool)
        and (not require_tracked or receipt.get("all_qualified_paths_tracked") is True),
        "R10B dependency receipt failed strict reconciliation",
    )
    require_zero_world(
        {**receipt, "scene_tree_insertion_count": 0}, "R10B dependency closure"
    )
    return receipt


def run_authority_materializer_self_test() -> dict[str, Any]:
    result = run_process(
        (sys.executable, "-B", AUTHORITY_MATERIALIZER_PATH, "self-test"),
        timeout_seconds=120,
    )
    require(
        result.returncode == 0,
        f"R10B authority materializer self-test failed: "
        f"{(result.stdout + result.stderr)[-4000:]}",
    )
    receipt = parse_marker(
        result.stdout,
        "QSDK_R10B_AUTHORITY_MATERIALIZER_SELF_TEST_PASS ",
        "R10B authority materializer self-test",
    )
    require_zero_world(receipt, "R10B authority materializer self-test")
    require(
        receipt.get("schema_version")
        == "sporespore_qsdk_r10b_authority_materializer_self_test_v4"
        and receipt.get("gate_id") == "QSDK-R10B"
        and receipt.get("qualified_source_path_count")
        == EXPECTED_QUALIFIED_SOURCE_PATH_COUNT
        and receipt.get("qualified_source_path_sha256")
        == EXPECTED_QUALIFIED_SOURCE_PATH_SHA256
        and receipt.get("campaign_role_count") == 2
        and receipt.get("authority_check_refusal_preserved") is True
        and receipt.get("authority_check_refusal_status")
        == "closed_infrastructure_invalid_pre_physics"
        and receipt.get("authority_check_refusal_raw_sha256")
        == "sha256:0196bdbcb8f914421edab305ca37e637708f8e35d5320f5c41fed827bfa9e230"
        and receipt.get("l1_physical_invalid_closure_preserved") is True
        and receipt.get("l1_physical_invalid_closure_status")
        == "closed_consumed_infrastructure_invalid_baseline_trace_quaternion_projection"
        and receipt.get("l1_physical_invalid_closure_raw_sha256")
        == "sha256:b9f8304e229d1a897137bafcce51ee6089b11b15742f624ccf38d202b8fe35a1"
        and receipt.get("l1_physical_identity_consumed") is True
        and receipt.get("l1_same_identity_rerun_permitted") is False
        and receipt.get("l2_successor_design_raw_sha256")
        == "sha256:" + EXPECTED_L2_DESIGN_SHA256
        and receipt.get("l2_physical_invalid_closure_preserved") is True
        and receipt.get("l2_physical_invalid_closure_status")
        == "closed_consumed_infrastructure_invalid_compound_trace_representation_validation"
        and receipt.get("l2_physical_invalid_closure_raw_sha256")
        == "sha256:" + EXPECTED_L2_PHYSICAL_INVALID_CLOSURE_SHA256
        and receipt.get("l2_physical_identity_consumed") is True
        and receipt.get("l2_same_identity_rerun_permitted") is False
        and receipt.get("l3_successor_design_raw_sha256")
        == "sha256:" + EXPECTED_L3_DESIGN_SHA256
        and receipt.get("release_authority") is False,
        "R10B authority materializer self-test receipt drifted",
    )
    return receipt


def godot_environment(scratch: Path) -> dict[str, str]:
    environment = dict(os.environ)
    environment["APPDATA"] = str(scratch / "appdata")
    environment["LOCALAPPDATA"] = str(scratch / "localappdata")
    environment.pop("SPORESPORE_QSDK_R10B_ATTEMPT", None)
    environment.pop("SPORESPORE_QSDK_R10B_TOKEN", None)
    (scratch / "appdata").mkdir(parents=True)
    (scratch / "localappdata").mkdir(parents=True)
    return environment


def run_l3_retained_trace_gate(godot: Path) -> dict[str, Any]:
    require(L2_RETAINED_TRACE_PATH.is_file(), "consumed L2 retained trace is missing")
    with tempfile.TemporaryDirectory(prefix="sporespore-r10b-l3-retained-") as raw:
        result = run_process(
            (
                godot,
                "--headless",
                "--path",
                ROOT,
                "--script",
                "res://tests/test_sdk_qsdk_r10b_l3_retained_trace_validation.gd",
                "--",
                L2_RETAINED_TRACE_PATH,
            ),
            timeout_seconds=240,
            environment=godot_environment(Path(raw)),
        )
    require(
        result.returncode == 0,
        f"R10B-L3 retained trace gate failed: "
        f"{(result.stdout + result.stderr)[-4000:]}",
    )
    receipt = parse_marker(
        result.stdout,
        L3_RETAINED_TRACE_MARKER,
        "R10B-L3 retained trace gate",
    )
    require_zero_world(receipt, "R10B-L3 retained trace gate")
    require(
        receipt.get("schema_version")
        == "sporespore_qsdk_r10b_l3_retained_trace_validation_v1"
        and receipt.get("gate_id") == "QSDK-R10B"
        and receipt.get("repair_id") == "QSDK-R10B-L3"
        and receipt.get("retained_cell_id") == "baseline_s50300"
        and receipt.get("retained_l2_trace_row_count") == 2640
        and receipt.get("projection_receipt_acceptance_count") == 2640
        and receipt.get("exported_axis_acceptance_count") == 2640
        and receipt.get("task_frame_exact_change_count") == 0
        and receipt.get("maximum_projection_receipt_absolute_delta")
        == 4.440892098500626e-16
        and receipt.get("maximum_projection_receipt_allowance")
        == 7.105428234818674e-15
        and receipt.get("maximum_exported_axis_norm_delta")
        == 2.220446049250313e-16
        and receipt.get("historical_full_trace_reclassification_refusal_count") == 1
        and receipt.get("historical_full_trace_reclassification_failure_code")
        == "QSDK_R10B_TRACE_ROW_HEADER_INVALID"
        and receipt.get("historical_cell_remains_invalid") is True
        and receipt.get("behavior_reclassification_count") == 0
        and receipt.get("locomotion_outcome_exposure_count") == 0
        and receipt.get("release_authority") is False,
        "R10B-L3 retained trace receipt drifted",
    )
    return receipt


def run_source_gate(godot: Path) -> dict[str, Any]:
    with tempfile.TemporaryDirectory(prefix="sporespore-r10b-source-") as raw:
        result = run_process(
            (
                godot,
                "--headless",
                "--path",
                ROOT,
                "--script",
                "res://tests/test_sdk_qsdk_r10b_bounded_upright_push_recovery_source.gd",
            ),
            timeout_seconds=180,
            environment=godot_environment(Path(raw)),
        )
    require(
        result.returncode == 0,
        f"R10B source gate failed: {(result.stdout + result.stderr)[-4000:]}",
    )
    receipt = parse_marker(result.stdout, SOURCE_MARKER, "R10B source gate")
    require_zero_world(receipt, "R10B source gate")
    require(
        receipt.get("schema_version") == "sporespore_qsdk_r10b_source_zero_world_v4"
        and receipt.get("gate_id") == "QSDK-R10B"
        and receipt.get("static_contract_compile_count") == 8
        and receipt.get("legacy_turning_trace_compile_control_passed") is True
        and receipt.get("post_physics_observation_completion_control_passed") is True
        and receipt.get("quaternion_projection_case_count") == 4
        and receipt.get("retained_raw_quaternion_refusal_count") == 2
        and receipt.get("retained_projected_quaternion_acceptance_count") == 2
        and receipt.get("additional_nonidentity_projected_acceptance_count") == 2
        and receipt.get("zero_quaternion_projection_refusal_count") == 1
        and receipt.get("projection_receipt_mutation_rejection_count") == 3
        and receipt.get("l3_within_allowance_positive_control_count") == 4
        and receipt.get("l3_outside_allowance_refusal_count") == 4
        and receipt.get("l3_nonfinite_refusal_count") == 4
        and receipt.get("l3_type_refusal_count") == 2
        and receipt.get("l3_projection_receipt_static_mutation_rejection_count") == 18
        and receipt.get("l3_projection_receipt_key_mutation_rejection_count") == 2
        and receipt.get("l3_projection_receipt_row_link_mutation_rejection_count") == 4
        and receipt.get("l3_projection_receipt_numeric_mutation_rejection_count") == 9
        and receipt.get("l3_projection_receipt_numeric_type_mutation_rejection_count")
        == 2
        and receipt.get("l3_nonunit_axis_refusal_count") == 2
        and receipt.get("l3_nonorthogonal_axis_refusal_count") == 2
        and receipt.get("l3_changed_task_frame_refusal_count") == 2
        and receipt.get("zero_completion_structured_refusal_count") == 1
        and receipt.get("positive_synthetic_world_control_count") == 2
        and receipt.get("positive_synthetic_pair_control_count") == 1
        and receipt.get("valid_finite_negative_control_count") == 2
        and receipt.get("invalid_or_incomplete_refusal_count") == 9
        and receipt.get("authorization_document_valid_control_count") == 4
        and receipt.get("authorization_document_mutation_rejection_count") == 104
        and receipt.get("synthetic_world_shaped_fixture_count") == 8
        and receipt.get("locomotion_outcome_exposure_count") == 0
        and receipt.get("physical_question_opened") is False
        and receipt.get("release_authority") is False,
        "R10B source receipt drifted",
    )
    return receipt


def expected_cells(role: str) -> list[tuple[str, int, str]]:
    seeds = (50300,) if role == "development_route_ghost" else (50301, 50302, 50303)
    result: list[tuple[str, int, str]] = []
    for seed in seeds:
        result.append(("matched_no_impulse_control", seed, f"baseline_s{seed}"))
        result.append(("lateral_upright_impulse", seed, f"push_s{seed}"))
    return result


def validate_worker_contract(receipt: Mapping[str, Any]) -> None:
    require_zero_world(receipt, "R10B worker contract")
    contracts = receipt.get("contracts")
    require(
        receipt.get("schema_version")
        == "sporespore_qsdk_r10b_worker_contract_zero_world_v4"
        and receipt.get("contract_count") == 8
        and isinstance(contracts, list)
        and len(contracts) == 8
        and receipt.get("physical_execution_authorized") is False
        and receipt.get("locomotion_outcome_exposure_count") == 0,
        "R10B worker contract receipt drifted",
    )
    observed = [
        (item.get("arm_id"), item.get("campaign_seed"), item.get("cell_id"))
        for item in contracts
        if isinstance(item, dict)
    ]
    require(
        observed
        == expected_cells("development_route_ghost")
        + expected_cells("held_out_finite_decision"),
        "R10B worker contract cell order or identity drifted",
    )
    require(
        all(
            isinstance(item.get("challenge_configuration_sha256"), str)
            and item["challenge_configuration_sha256"].startswith("sha256:")
            and isinstance(item.get("trace_configuration_sha256"), str)
            and item["trace_configuration_sha256"].startswith("sha256:")
            for item in contracts
        ),
        "R10B worker contract digest was missing",
    )


def validate_preflight(receipt: Mapping[str, Any], role: str) -> None:
    require_zero_world(receipt, f"R10B {role} preflight")
    entrypoints = receipt.get("entrypoints")
    expected = expected_cells(role)
    require(
        receipt.get("schema_version")
        == "sporespore_qsdk_r10b_worker_entrypoint_zero_world_v4"
        and receipt.get("campaign_role") == role
        and receipt.get("entrypoint_count") == len(expected)
        and isinstance(entrypoints, list)
        and len(entrypoints) == len(expected)
        and receipt.get("physical_execution_authorized") is False
        and receipt.get("locomotion_outcome_exposure_count") == 0,
        f"R10B {role} preflight identity drifted",
    )
    observed = [
        (item.get("arm_id"), item.get("campaign_seed"), item.get("cell_id"))
        for item in entrypoints
        if isinstance(item, dict)
    ]
    require(observed == expected, f"R10B {role} preflight cell order drifted")
    require(
        all(
            item.get("declared_policy_runtime_boundary_preflight_passed") is True
            and item.get("world_build_count") == 0
            and isinstance(item.get("trace_configuration_sha256"), str)
            and item["trace_configuration_sha256"].startswith("sha256:")
            for item in entrypoints
        ),
        f"R10B {role} preflight boundary receipt drifted",
    )


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
        timeout_seconds=900,
    )
    require(
        result.returncode == 0,
        f"R10B supervisor failed: {(result.stdout + result.stderr)[-5000:]}",
    )
    receipt = parse_marker(result.stdout, SUPERVISOR_MARKER, "R10B supervisor")
    require_zero_world(receipt, "R10B supervisor")
    require(
        receipt.get("schema_version") == "sporespore_qsdk_r10b_supervisor_zero_world_v4"
        and receipt.get("gate_id") == "QSDK-R10B"
        and receipt.get("direct_physical_bypass_refused") is True
        and receipt.get("ordinal_path_order_control_passed") is True
        and receipt.get("ordinal_path_order_negative_control_count") == 2
        and receipt.get("physical_execution_authorized") is False
        and receipt.get("locomotion_outcome_exposure_count") == 0,
        "R10B supervisor receipt drifted",
    )
    source = receipt.get("source_gate")
    contract = receipt.get("worker_contract")
    preflights = receipt.get("entrypoint_preflights")
    require(isinstance(source, dict), "R10B supervisor source receipt missing")
    require(isinstance(contract, dict), "R10B supervisor contract receipt missing")
    require(
        isinstance(preflights, list) and len(preflights) == 2,
        "R10B supervisor preflight receipt count drifted",
    )
    require_zero_world(source, "R10B supervisor nested source")
    validate_worker_contract(contract)
    validate_preflight(preflights[0], "development_route_ghost")
    validate_preflight(preflights[1], "held_out_finite_decision")
    return receipt


def validate_static_authorization_boundary() -> None:
    supervisor = SUPERVISOR_PATH.read_text(encoding="utf-8")
    qualification = QUALIFICATION_WRAPPER_PATH.read_text(encoding="utf-8")
    materializer = AUTHORITY_MATERIALIZER_PATH.read_text(encoding="utf-8")
    worker = WORKER_PATH.read_text(encoding="utf-8")
    required_supervisor_fragments = (
        '[ValidateSet("ZeroWorld", "AuthorityCheck", "Physical")]',
        '[string]$Mode = "ZeroWorld"',
        'if ($Mode -ceq "ZeroWorld")',
        'elseif ($Mode -ceq "AuthorityCheck")',
        "Invoke-AuthorityCheckMode",
        "Invoke-PhysicalMode -TempRoot $tempRoot",
        "Get-QualifiedPhysicalAuthority -RepositoryIdentity $identity",
        "Physical mode requires -StageFreeze and -ExecutionAuthority",
        "$authority.output_root",
        "-Output must exactly match the execution authority output_root",
        "Test-Path -LiteralPath $authorizedOutputPath",
        "authorization_commit_derived_from_current_head",
        "authorization_parent_commit",
        "qualification_parent_commit",
        "qualified_source_bindings",
        "Test-StrictOrdinalStringOrder",
        "[StringComparer]::Ordinal.Compare",
        "superseded_authority_check_refusal",
        "consumed_l1_physical_invalid_closure",
        "consumed_l2_physical_invalid_closure",
        'diff-tree", "--no-commit-id", "--name-only"',
        "sporespore_qsdk_r10b_stage_freeze_v4",
        "sporespore_qsdk_r10b_execution_authority_v4",
        "sporespore_qsdk_r10b_physical_attempt_v4",
        "sporespore_qsdk_r10b_authority_check_zero_world_v4",
    )
    required_worker_fragments = (
        "SPORESPORE_QSDK_R10B_ATTEMPT",
        "SPORESPORE_QSDK_R10B_TOKEN",
        "QSDK_R10B_PHYSICAL_AUTHORIZATION_REQUIRED",
        "QSDK_R10B_EXECUTION_AUTHORITY_INVALID",
        'attempt.get("output_root", "")',
        'authority.get("output_root", "")',
        "QSDK_R10B_STAGE_FREEZE_INVALID",
        "authorization_commit_derived_from_current_head",
        "qualification_parent_commit",
        "maximum_world_attempt_count",
        "maximum_world_build_count",
        "L1_PHYSICAL_INVALID_CLOSURE_SHA256",
        "L2_PHYSICAL_INVALID_CLOSURE_SHA256",
        "L3_DESIGN_SHA256",
        "sporespore_qsdk_r10b_worker_contract_zero_world_v4",
        "sporespore_qsdk_r10b_worker_entrypoint_zero_world_v4",
    )
    required_qualification_fragments = (
        '"--official-qualification"',
        "QSDK_R10B_QUALIFICATION_IDENTITY_ALREADY_CONSUMED",
        "sporespore_qsdk_r10b_zero_world_implementation_audit_v4",
        "sporespore_qsdk_r10b_zero_world_qualification_completion_v4",
        "consumed_l1_physical_invalid_closure_sha256",
        "consumed_l2_physical_invalid_closure_sha256",
        "l3_successor_design_sha256",
        "official_qualification_attempt_count_for_source_and_role = 1",
        "physical_execution_authorized = $false",
        "physical_acceptance_authority = $false",
        "release_authority = $false",
    )
    required_materializer_fragments = (
        '("self-test", "stage-freeze", "execution-authority")',
        'with path.open("xb")',
        "source_bindings(source_commit, qualification_parent)",
        "authority_check_refusal_binding",
        "l1_physical_invalid_closure_binding",
        "l2_physical_invalid_closure_binding",
        "qsdk_r10b_dependency_manifest_v4.json",
        "sporespore_qsdk_r10b_zero_world_qualification_completion_v4",
        "QUALIFICATION_COMMIT_NOT_STAGE_FREEZE_ONLY",
        '"authorization_commit_derived_from_current_head": True',
        '"physical_identity_consumed": False',
        '"same_identity_rerun_permitted": False',
        '"physical_acceptance_authority": False',
        '"release_authority": False',
    )
    require(
        all(fragment in supervisor for fragment in required_supervisor_fragments),
        "R10B supervisor static physical authorization boundary drifted",
    )
    require(
        all(fragment in worker for fragment in required_worker_fragments),
        "R10B worker static physical authorization boundary drifted",
    )
    require(
        all(fragment in qualification for fragment in required_qualification_fragments),
        "R10B retained qualification wrapper boundary drifted",
    )
    require(
        all(fragment in materializer for fragment in required_materializer_fragments),
        "R10B authority materializer boundary drifted",
    )


def run_direct_bypass_control(godot: Path) -> dict[str, Any]:
    with tempfile.TemporaryDirectory(prefix="sporespore-r10b-bypass-") as raw:
        result = run_process(
            (
                godot,
                "--headless",
                "--path",
                ROOT,
                "--script",
                "res://tests/test_sdk_qsdk_r10b_bounded_upright_push_recovery_worker.gd",
                "--",
                "physical",
                "development_route_ghost",
                "matched_no_impulse_control",
                "50300",
            ),
            timeout_seconds=180,
            environment=godot_environment(Path(raw)),
        )
    require(result.returncode != 0, "R10B direct physical worker bypass was accepted")
    receipt = parse_marker(result.stdout, CELL_MARKER, "R10B direct bypass")
    require(
        receipt.get("ok") is False
        and receipt.get("failure_code") == "QSDK_R10B_PHYSICAL_AUTHORIZATION_REQUIRED",
        "R10B direct bypass failed at an unexpected boundary",
    )
    for counter in ZERO_COUNTERS:
        require(
            receipt.get(counter) == 0, f"R10B direct bypass: {counter} was not zero"
        )
    require(
        receipt.get("scene_tree_insertion_count") == 0
        and receipt.get("physics_state_modified") is False
        and receipt.get("physical_acceptance_authority") is False,
        "R10B direct bypass refusal crossed the zero-world boundary",
    )
    return receipt


def run_format_check() -> str:
    gdformat = shutil.which("gdformat")
    require(gdformat is not None, "gdformat is not available")
    result = run_process(
        (gdformat, "--check", *FORMATTED_GDSCRIPT_PATHS), timeout_seconds=120
    )
    require(
        result.returncode == 0,
        f"R10B GDScript formatting check failed: {(result.stdout + result.stderr)[-4000:]}",
    )
    return gdformat


def run_powershell_parse_check(pwsh: str) -> int:
    paths = (SUPERVISOR_PATH, QUALIFICATION_WRAPPER_PATH)
    for path in paths:
        environment = dict(os.environ)
        environment["SPORESPORE_R10B_PARSE_PATH"] = str(path)
        script = (
            "$tokens=$null; $errors=$null; "
            "[void][System.Management.Automation.Language.Parser]::ParseFile("
            "$env:SPORESPORE_R10B_PARSE_PATH,[ref]$tokens,[ref]$errors); "
            "if ($errors.Count -ne 0) { $errors | ForEach-Object { Write-Error $_ }; exit 41 }; "
            "Write-Output 'QSDK_R10B_POWERSHELL_PARSE_PASS'"
        )
        result = run_process(
            (pwsh, "-NoLogo", "-NoProfile", "-Command", script),
            timeout_seconds=60,
            environment=environment,
        )
        require(
            result.returncode == 0
            and result.stdout.count("QSDK_R10B_POWERSHELL_PARSE_PASS") == 1,
            f"R10B PowerShell parse check failed for {path}: "
            f"{(result.stdout + result.stderr)[-4000:]}",
        )
    return len(paths)


def run_final_operation_lock_probe(pwsh: str) -> None:
    environment = dict(os.environ)
    environment["SPORESPORE_R10B_LOCK_PATH"] = str(OPERATION_LOCK_PATH)
    script = "\n".join(
        (
            "$ErrorActionPreference = 'Stop'",
            ". $env:SPORESPORE_R10B_LOCK_PATH",
            "$receipt = Enter-SporeSporeLocomotionOperationLock -Role conformance",
            "if (-not [bool]$receipt.acquired -or [bool]$receipt.abandoned_owner_recovered) { exit 51 }",
            "Exit-SporeSporeLocomotionOperationLock -Receipt $receipt",
            "if (-not [bool]$receipt.released) { exit 52 }",
            "Write-Output 'QSDK_R10B_FINAL_OPERATION_LOCK_PROBE_PASS'",
        )
    )
    result = run_process(
        (pwsh, "-NoLogo", "-NoProfile", "-Command", script),
        timeout_seconds=60,
        environment=environment,
    )
    require(
        result.returncode == 0
        and result.stdout.count("QSDK_R10B_FINAL_OPERATION_LOCK_PROBE_PASS") == 1,
        f"R10B final operation lock probe failed: {(result.stdout + result.stderr)[-3000:]}",
    )


def file_identity(path: Path, version: str) -> dict[str, Any]:
    resolved = path.resolve()
    require(resolved.is_file(), f"runtime identity path is missing: {resolved}")
    path_text = resolved.as_posix()
    if sys.platform == "win32":
        path_text = path_text.lower()
    return {
        "path": path_text,
        "raw_sha256": f"sha256:{sha256_hex(resolved)}",
        "byte_length": resolved.stat().st_size,
        "version": version.strip(),
    }


def command_version(arguments: Iterable[str | Path], label: str) -> str:
    result = run_process(arguments, timeout_seconds=60)
    require(result.returncode == 0, f"could not identify {label}")
    version = (
        (result.stdout + result.stderr).strip().replace("\r", " ").replace("\n", " ")
    )
    require(bool(version), f"{label} returned an empty version")
    return version


def runtime_identity(
    godot: Path,
    pwsh: str,
    gdformat: str,
    dependency: Mapping[str, Any],
) -> dict[str, Any]:
    git = shutil.which("git")
    require(git is not None, "git is not available")
    adapter_digest = f"sha256:{sha256_hex(ACTIVE_ADAPTER_PATH)}"
    require(
        dependency.get("active_runtime_artifact_raw_sha256") == adapter_digest
        and dependency.get("active_runtime_artifact_byte_length")
        == ACTIVE_ADAPTER_PATH.stat().st_size,
        "active adapter changed between dependency and runtime qualification",
    )
    identity: dict[str, Any] = {
        "schema_version": "sporespore_qsdk_r10b_runtime_identity_v1",
        "godot": file_identity(godot, command_version((godot, "--version"), "Godot")),
        "active_adapter": {
            "relative_path": "sdk/target/debug/sporespore_godot_adapter.dll",
            "raw_sha256": adapter_digest,
            "byte_length": ACTIVE_ADAPTER_PATH.stat().st_size,
        },
        "python": file_identity(Path(sys.executable), sys.version.replace("\n", " ")),
        "powershell": file_identity(
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
        "git": file_identity(Path(git), command_version((git, "--version"), "Git")),
        "gdformat": file_identity(
            Path(gdformat), command_version((gdformat, "--version"), "gdformat")
        ),
    }
    canonical = json.dumps(
        identity, ensure_ascii=False, separators=(",", ":"), sort_keys=True
    )
    return {
        "schema_version": "sporespore_qsdk_r10b_runtime_identity_projection_v1",
        "identity_sha256": "sha256:"
        + hashlib.sha256(canonical.encode("utf-8")).hexdigest(),
        "identity": identity,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, default=DEFAULT_GODOT)
    parser.add_argument("--official-qualification", action="store_true")
    arguments = parser.parse_args()
    try:
        require(ROOT.resolve() == EXPECTED_ROOT.resolve(), "canonical root changed")
        require(
            arguments.godot.is_file(), f"Godot console is missing: {arguments.godot}"
        )
        require(ACTIVE_ADAPTER_PATH.is_file(), "active Godot adapter is missing")
        pwsh = shutil.which("pwsh")
        require(pwsh is not None, "pwsh is not available")
        source_projection = inspect_source_boundary(
            official_qualification=arguments.official_qualification
        )
        design_mutation_count = run_design_audit()
        l2_design = run_l2_design_audit()
        l2_physical_invalid = run_l2_physical_invalid_closure_audit()
        l3_design = run_l3_design_audit()
        dependency = run_dependency_audit(
            require_tracked=arguments.official_qualification
        )
        authority_materializer = run_authority_materializer_self_test()
        powershell_parse_count = run_powershell_parse_check(pwsh)
        gdformat = run_format_check()
        l3_retained_trace = run_l3_retained_trace_gate(arguments.godot)
        direct_source = run_source_gate(arguments.godot)
        validate_static_authorization_boundary()
        direct_bypass = run_direct_bypass_control(arguments.godot)
        supervisor = run_supervisor(pwsh, arguments.godot)
        require(
            supervisor.get("source_gate") == direct_source,
            "independent and supervisor source receipts were not exact",
        )
        run_final_operation_lock_probe(pwsh)
        runtime = runtime_identity(arguments.godot, pwsh, gdformat, dependency)
        receipt = {
            "schema_version": "sporespore_qsdk_r10b_zero_world_implementation_audit_v4",
            "gate_id": "QSDK-R10B",
            "ledger_scope": {
                "subsystem": "recovery",
                "engine_scope": "godot_jolt",
                "authority_mode": "prospective_zero_world_implementation_audit",
                "question_class": "development",
            },
            "ok": True,
            **source_projection,
            "r10a_design_raw_sha256": f"sha256:{EXPECTED_DESIGN_SHA256}",
            "r10a_design_byte_length": EXPECTED_DESIGN_BYTES,
            "r10a_design_audit_passed": True,
            "r10a_design_mutation_rejection_count": design_mutation_count,
            "l2_successor_design_raw_sha256": f"sha256:{EXPECTED_L2_DESIGN_SHA256}",
            "l2_successor_design_byte_length": EXPECTED_L2_DESIGN_BYTES,
            "l2_successor_design_audit_passed": True,
            "l2_successor_design_mutation_rejection_count": l2_design[
                "design_mutation_rejection_count"
            ],
            "l1_physical_identity_consumed": True,
            "l1_same_identity_rerun_permitted": False,
            "l2_physical_invalid_closure_raw_sha256": (
                f"sha256:{EXPECTED_L2_PHYSICAL_INVALID_CLOSURE_SHA256}"
            ),
            "l2_physical_invalid_closure_byte_length": (
                EXPECTED_L2_PHYSICAL_INVALID_CLOSURE_BYTES
            ),
            "l2_physical_invalid_closure_audit_passed": True,
            "l2_physical_invalid_closure_mutation_rejection_count": (
                l2_physical_invalid["closure_mutation_rejection_count"]
            ),
            "l2_physical_identity_consumed": True,
            "l2_same_identity_rerun_permitted": False,
            "l2_valid_behavior_result_count": 0,
            "l2_selected_successor_id": "QSDK-R10B-L3",
            "l3_successor_design_raw_sha256": f"sha256:{EXPECTED_L3_DESIGN_SHA256}",
            "l3_successor_design_byte_length": EXPECTED_L3_DESIGN_BYTES,
            "l3_successor_design_audit_passed": True,
            "l3_successor_design_mutation_rejection_count": l3_design[
                "design_mutation_rejection_count"
            ],
            "l3_retained_trace_validation_passed": True,
            "l3_retained_trace_row_count": l3_retained_trace[
                "retained_l2_trace_row_count"
            ],
            "l3_projection_receipt_acceptance_count": l3_retained_trace[
                "projection_receipt_acceptance_count"
            ],
            "l3_exported_axis_acceptance_count": l3_retained_trace[
                "exported_axis_acceptance_count"
            ],
            "l3_maximum_projection_receipt_absolute_delta": l3_retained_trace[
                "maximum_projection_receipt_absolute_delta"
            ],
            "l3_maximum_projection_receipt_allowance": l3_retained_trace[
                "maximum_projection_receipt_allowance"
            ],
            "l3_maximum_exported_axis_norm_delta": l3_retained_trace[
                "maximum_exported_axis_norm_delta"
            ],
            "l3_historical_full_trace_reclassification_refusal_count": (
                l3_retained_trace["historical_full_trace_reclassification_refusal_count"]
            ),
            "l3_behavior_reclassification_count": l3_retained_trace[
                "behavior_reclassification_count"
            ],
            "dependency_closure_audit_passed": True,
            "qualified_source_path_count": dependency["qualified_source_path_count"],
            "qualified_source_path_sha256": dependency["qualified_source_path_sha256"],
            "dependency_all_qualified_paths_tracked": dependency[
                "all_qualified_paths_tracked"
            ],
            "dependency_tracked_source_required": dependency["tracked_source_required"],
            "authority_materializer_self_test_passed": True,
            "authority_materializer_campaign_role_count": authority_materializer[
                "campaign_role_count"
            ],
            "runtime_identity_projection": runtime,
            "powershell_parse_passed": True,
            "powershell_parse_path_count": powershell_parse_count,
            "gdformat_path_count": len(FORMATTED_GDSCRIPT_PATHS),
            "direct_source_gate_count": 1,
            "supervisor_source_gate_count": 1,
            "source_receipts_exact_across_independent_runs": True,
            "static_contract_compile_count_per_source_gate": 8,
            "source_invalid_or_incomplete_refusal_count_per_gate": 9,
            "source_valid_finite_negative_control_count_per_gate": 2,
            "authorization_document_valid_control_count_per_source_gate": 4,
            "authorization_document_mutation_rejection_count_per_source_gate": 104,
            "quaternion_projection_case_count_per_source_gate": 4,
            "retained_raw_quaternion_refusal_count_per_source_gate": 2,
            "retained_projected_quaternion_acceptance_count_per_source_gate": 2,
            "additional_nonidentity_projected_acceptance_count_per_source_gate": 2,
            "zero_quaternion_projection_refusal_count_per_source_gate": 1,
            "projection_receipt_mutation_rejection_count_per_source_gate": 3,
            "l3_within_allowance_positive_control_count_per_source_gate": 4,
            "l3_outside_allowance_refusal_count_per_source_gate": 4,
            "l3_nonfinite_refusal_count_per_source_gate": 4,
            "l3_type_refusal_count_per_source_gate": 2,
            "l3_projection_receipt_static_mutation_rejection_count_per_source_gate": 18,
            "l3_projection_receipt_key_mutation_rejection_count_per_source_gate": 2,
            "l3_projection_receipt_row_link_mutation_rejection_count_per_source_gate": 4,
            "l3_projection_receipt_numeric_mutation_rejection_count_per_source_gate": 9,
            "l3_projection_receipt_numeric_type_mutation_rejection_count_per_source_gate": 2,
            "l3_nonunit_axis_refusal_count_per_source_gate": 2,
            "l3_nonorthogonal_axis_refusal_count_per_source_gate": 2,
            "l3_changed_task_frame_refusal_count_per_source_gate": 2,
            "zero_completion_structured_refusal_count_per_source_gate": 1,
            "supervisor_worker_contract_count": 8,
            "supervisor_entrypoint_preflight_count": 8,
            "supervisor_development_entrypoint_count": 2,
            "supervisor_heldout_entrypoint_count": 6,
            "supervisor_ordinal_path_order_control_passed": True,
            "supervisor_ordinal_path_order_negative_control_count": 2,
            "static_authorization_boundary_passed": True,
            "direct_physical_bypass_refusal_count": 2,
            "direct_bypass_failure_code": direct_bypass["failure_code"],
            "final_operation_lock_release_probe_passed": True,
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
        print(PASS_MARKER + json.dumps(receipt, sort_keys=True, separators=(",", ":")))
        return 0
    except (AuditFailure, KeyError, IndexError, TypeError, OSError) as exc:
        print(f"QSDK_R10B_ZERO_WORLD_IMPLEMENTATION_FAIL {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
