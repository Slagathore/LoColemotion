#!/usr/bin/env python3
"""Materialize QSDK-R10D stage freezes and parent-bound execution authorities."""

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
MANIFEST_PATH = ROOT / "sdk/qsdk_r10d_dependency_manifest_v2.json"
DEPENDENCY_AUDIT_PATH = ROOT / "sdk/conformance/qsdk_r10d_dependency_closure.py"
PHYSICAL_CLOSURE_AUDIT_PATH = ROOT / "sdk/conformance/qsdk_r10d_physical_closure.py"
ACTIVE_ADAPTER_RELATIVE_PATH = "sdk/target/debug/sporespore_godot_adapter.dll"
ACTIVE_ADAPTER_PATH = ROOT / ACTIVE_ADAPTER_RELATIVE_PATH
DESIGN_PATH = (
    ROOT / "sdk/qsdk_r10c_supported_start_phase_robust_successor_design_v1.json"
)
L1_DESIGN_PATH = (
    ROOT
    / "sdk/qsdk_r10d_l1_stage_freeze_numeric_normalization_successor_design_v1.json"
)
CONSUMED_R10D_CLOSURE_PATH = (
    ROOT / "sdk/qsdk_r10d_development_route_ghost_physical_closure_v1.json"
)
R10B_CLOSURE_PATH = (
    ROOT / "sdk/qsdk_r10b_held_out_finite_decision_physical_closure_v1.json"
)
R05E_CLOSURE_PATH = (
    ROOT / "sdk/qsdk_r05e_exact_finite_morphology_physical_closure_v1.json"
)
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
EXPECTED_R10B_CLOSURE_BYTES = 30_998
EXPECTED_R10B_CLOSURE_SHA256 = (
    "sha256:108473a00fb7d789862996b85e95ef255cc62b5e2c6037aecb556bd77dce625a"
)
EXPECTED_R05E_CLOSURE_BYTES = 49_049
EXPECTED_R05E_CLOSURE_SHA256 = (
    "sha256:dac4ac8790cd74d89da0286c36aaf541fbfe7011d2bea66077b941363d47b33e"
)
EXPECTED_SOURCE_COUNT = 88
EXPECTED_SOURCE_PATH_SHA256 = (
    "sha256:fde0b22bd6fbe0a51a07949efeb93550db16bdb580de39f192192f4d63c897e2"
)
QUALIFICATION_SCHEMA = "sporespore_qsdk_r10d_zero_world_qualification_completion_v2"
QUALIFICATION_ATTEMPT_SCHEMA = (
    "sporespore_qsdk_r10d_zero_world_qualification_attempt_v2"
)
IMPLEMENTATION_AUDIT_SCHEMA = "sporespore_qsdk_r10d_zero_world_implementation_audit_v1"
RUNTIME_PROJECTION_SCHEMA = "sporespore_qsdk_r10d_runtime_identity_projection_v1"
RUNTIME_IDENTITY_SCHEMA = "sporespore_qsdk_r10d_runtime_identity_v1"
STAGE_SCHEMA = "sporespore_qsdk_r10d_stage_freeze_v2"
AUTHORITY_SCHEMA = "sporespore_qsdk_r10d_execution_authority_v2"
SELF_TEST_MARKER = "QSDK_R10D_AUTHORITY_MATERIALIZER_SELF_TEST_PASS "
MATERIALIZED_MARKER = "QSDK_R10D_AUTHORITY_MATERIALIZED "
DEPENDENCY_MARKER = "QSDK_R10D_DEPENDENCY_CLOSURE_PASS "
PHYSICAL_CLOSURE_AUDIT_MARKER = "QSDK_R10D_PHYSICAL_CLOSURE_AUDIT_PASS "

ROLE_SPECS: dict[str, dict[str, Any]] = {
    "development_route_ghost": {
        "campaign_id": (
            "QSDK-R10D-SUPPORTED-START-PHASE-ROBUST-"
            "UPRIGHT-PUSH-RECOVERY-ROUTE-GHOST"
        ),
        "question_class": "development",
        "ordered_cell_ids": ["baseline_s40001", "push_s40001"],
        "maximum_world_count": 2,
        "stage_freeze_path": (
            "sdk/qsdk_r10d_development_route_ghost_"
            "zero_world_qualification_closure_v2.json"
        ),
        "authority_path": (
            "sdk/qsdk_r10d_development_route_ghost_execution_authority_v2.json"
        ),
        "physical_output_slug": "development-route-ghost",
    },
    "held_out_finite_decision": {
        "campaign_id": (
            "QSDK-R10D-SUPPORTED-START-PHASE-ROBUST-" "UPRIGHT-PUSH-RECOVERY-VALIDATION"
        ),
        "question_class": "finite decision",
        "ordered_cell_ids": [
            "baseline_s40101",
            "push_s40101",
            "baseline_s40102",
            "push_s40102",
            "baseline_s40103",
            "push_s40103",
        ],
        "maximum_world_count": 6,
        "stage_freeze_path": (
            "sdk/qsdk_r10d_held_out_finite_decision_"
            "zero_world_qualification_closure_v2.json"
        ),
        "authority_path": (
            "sdk/qsdk_r10d_held_out_finite_decision_execution_authority_v2.json"
        ),
        "physical_output_slug": "held-out-finite-decision",
    },
}


class MaterializationFailure(RuntimeError):
    """A prospective R10D authority boundary was not exact."""


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
        and len(value) == 71
        and value.startswith("sha256:")
        and all(character in "0123456789abcdef" for character in value[7:])
    )


def path_set_digest(paths: Iterable[str]) -> str:
    return sha256_bytes("\n".join(paths).encode("utf-8"))


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
        git(
            ("status", "--porcelain=v1", "--untracked-files=all"),
            allow_empty=True,
        )
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
        "origin_main": origin,
        "live_main": live_parts[0],
        "clean": True,
    }


def file_identity(
    path: Path,
    *,
    relative_to: Path | None = None,
) -> dict[str, Any]:
    raw = path.read_bytes()
    name = path.as_posix()
    if relative_to is not None:
        name = path.resolve().relative_to(relative_to.resolve()).as_posix()
    return {
        "path": name,
        "byte_length": len(raw),
        "raw_sha256": sha256_bytes(raw),
    }


def committed_file_binding(relative: str, commit: str) -> dict[str, Any]:
    path = ROOT / relative
    require(path.is_file(), f"BINDING_MISSING:{relative}")
    raw = path.read_bytes()
    blob = git(("rev-parse", f"{commit}:{relative}"))
    current_blob = git(("hash-object", "--", relative))
    require(blob == current_blob, f"BINDING_BLOB_DRIFT:{relative}")
    return {
        "path": relative,
        "byte_length": len(raw),
        "raw_sha256": sha256_bytes(raw),
        "git_blob_oid": blob,
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


def dependency_receipt(require_tracked: bool) -> dict[str, Any]:
    arguments = [sys.executable, "-B", str(DEPENDENCY_AUDIT_PATH)]
    if require_tracked:
        arguments.append("--require-tracked")
    result = subprocess.run(
        arguments,
        cwd=ROOT,
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
        timeout=120,
    )
    require(
        result.returncode == 0,
        f"DEPENDENCY_AUDIT_FAILED:{(result.stdout + result.stderr)[-2000:]}",
    )
    receipt = parse_marker(result.stdout, DEPENDENCY_MARKER, "DEPENDENCY")
    require(
        receipt.get("ok") is True
        and receipt.get("schema_version")
        == "sporespore_qsdk_r10d_dependency_closure_zero_world_v2"
        and receipt.get("repair_id") == "QSDK-R10D-L1"
        and receipt.get("qualified_source_path_count") == EXPECTED_SOURCE_COUNT
        and receipt.get("qualified_source_path_sha256") == EXPECTED_SOURCE_PATH_SHA256
        and receipt.get("tracked_source_required") is require_tracked
        and (not require_tracked or receipt.get("all_qualified_paths_tracked") is True)
        and receipt.get("world_attempt_count") == 0
        and receipt.get("world_build_count") == 0
        and receipt.get("solver_step_count") == 0,
        "DEPENDENCY_RECEIPT",
    )
    return receipt


def source_inventory(*, require_tracked: bool) -> tuple[list[str], str]:
    receipt = dependency_receipt(require_tracked)
    paths = receipt.get("qualified_source_paths")
    require(
        isinstance(paths, list)
        and len(paths) == EXPECTED_SOURCE_COUNT
        and all(isinstance(path, str) and path for path in paths)
        and paths == sorted(set(paths)),
        "SOURCE_PATHS",
    )
    digest = path_set_digest(paths)
    require(digest == EXPECTED_SOURCE_PATH_SHA256, "SOURCE_PATH_DIGEST")
    return paths, digest


def source_bindings(source_commit: str, current_commit: str) -> list[dict[str, Any]]:
    paths, _ = source_inventory(require_tracked=True)
    bindings: list[dict[str, Any]] = []
    for relative in paths:
        source_blob = git(("rev-parse", f"{source_commit}:{relative}"))
        current_blob = git(("rev-parse", f"{current_commit}:{relative}"))
        require(
            source_blob == current_blob,
            f"SOURCE_CHANGED_AFTER_QUALIFICATION:{relative}",
        )
        binding = committed_file_binding(relative, current_commit)
        require(binding["git_blob_oid"] == source_blob, f"SOURCE_BLOB_DRIFT:{relative}")
        bindings.append(binding)
    return bindings


def validate_file_identity(
    path: Path,
    expected_bytes: int,
    expected_sha256: str,
    label: str,
) -> dict[str, Any]:
    require(path.is_file(), f"{label}_MISSING")
    raw = path.read_bytes()
    require(len(raw) == expected_bytes, f"{label}_BYTES")
    require(sha256_bytes(raw) == expected_sha256, f"{label}_SHA256")
    return read_json(path, label)


def validate_static_authorities() -> (
    tuple[dict[str, Any], dict[str, Any], dict[str, Any]]
):
    design = validate_file_identity(
        DESIGN_PATH,
        EXPECTED_DESIGN_BYTES,
        EXPECTED_DESIGN_SHA256,
        "R10C_DESIGN",
    )
    require(
        design.get("schema_version")
        == "sporespore_qsdk_r10c_supported_start_phase_robust_successor_design_v1"
        and design.get("design_id") == "QSDK-R10C-D1"
        and design.get("decision", {}).get("selected")
        == "QSDK-R10D-SUPPORTED-START-PHASE-ROBUST-UPRIGHT-PUSH-RECOVERY-IMPLEMENTATION"
        and design.get("decision", {}).get("q_sdk_r10d_physical_execution_authorized")
        is False,
        "R10C_DESIGN_CONTRACT",
    )
    r10b = validate_file_identity(
        R10B_CLOSURE_PATH,
        EXPECTED_R10B_CLOSURE_BYTES,
        EXPECTED_R10B_CLOSURE_SHA256,
        "R10B_CLOSURE",
    )
    require(
        r10b.get("status") == "closed_consumed_valid_complete_finite_negative"
        and r10b.get("physical_identity_consumed") is True
        and r10b.get("same_identity_rerun_permitted") is False
        and r10b.get("claim_boundary", {}).get("bounded_upright_push_recovery_claimed")
        is False,
        "R10B_CLOSURE_CONTRACT",
    )
    r05e = validate_file_identity(
        R05E_CLOSURE_PATH,
        EXPECTED_R05E_CLOSURE_BYTES,
        EXPECTED_R05E_CLOSURE_SHA256,
        "R05E_CLOSURE",
    )
    first = r05e.get("population", {}).get("frozen_cells", [{}])[0]
    require(
        r05e.get("status")
        == (
            "closed_consumed_complete_held_out_finite_positive_"
            "eligible_for_separate_qsdk_r05_adoption"
        )
        and r05e.get("population", {}).get("campaign_seeds") == [40101, 40102, 40103]
        and first.get("generator_index") == 217
        and first.get("morphology_id") == "qsdk_r05e_axis_star_torso_length_low_s217"
        and r05e.get("outcome", {}).get("walking_pass_count") == 36
        and r05e.get("outcome", {}).get("false_walking_gate_receipt_count") == 0
        and r05e.get("claim_boundary", {}).get("external_push_recovery") is False,
        "R05E_CLOSURE_CONTRACT",
    )
    return design, r10b, r05e


def r10b_closure_binding(source_commit: str) -> dict[str, Any]:
    _, r10b, _ = validate_static_authorities()
    binding = committed_file_binding(
        R10B_CLOSURE_PATH.relative_to(ROOT).as_posix(), source_commit
    )
    return {
        **binding,
        "status": r10b["status"],
        "physical_identity_consumed": True,
        "same_identity_rerun_permitted": False,
        "bounded_upright_push_recovery_claimed": False,
    }


def r05e_closure_binding(source_commit: str) -> dict[str, Any]:
    _, _, r05e = validate_static_authorities()
    first = r05e["population"]["frozen_cells"][0]
    binding = committed_file_binding(
        R05E_CLOSURE_PATH.relative_to(ROOT).as_posix(), source_commit
    )
    return {
        **binding,
        "status": r05e["status"],
        "selected_generator_index": first["generator_index"],
        "selected_morphology_id": first["morphology_id"],
        "supported_campaign_seeds": r05e["population"]["campaign_seeds"],
        "walking_pass_count": 3,
        "false_walking_receipt_count": 0,
        "external_push_recovery_claimed": False,
    }


def l1_successor_design_binding(source_commit: str) -> dict[str, Any]:
    design = validate_file_identity(
        L1_DESIGN_PATH,
        EXPECTED_L1_DESIGN_BYTES,
        EXPECTED_L1_DESIGN_SHA256,
        "R10D_L1_DESIGN",
    )
    require(
        design.get("schema_version")
        == "sporespore_qsdk_r10d_l1_stage_freeze_numeric_normalization_successor_design_v1"
        and design.get("status") == "closed_selected_zero_world_successor_design"
        and design.get("gate_id") == "QSDK-R10D-L1"
        and design.get("repair_id") == "QSDK-R10D-L1"
        and design.get("decision", {}).get("selected_successor_id") == "QSDK-R10D-L1"
        and design.get("decision", {}).get("new_physical_work_authorized_now") is False
        and design.get("repair_contract", {}).get("threshold_changed") is False
        and design.get("repair_contract", {}).get("population_changed") is False
        and design.get("repair_contract", {}).get("seed_changed") is False,
        "R10D_L1_DESIGN_CONTRACT",
    )
    return {
        **committed_file_binding(
            L1_DESIGN_PATH.relative_to(ROOT).as_posix(), source_commit
        ),
        "repair_id": "QSDK-R10D-L1",
        "representation_only_repair": True,
        "new_physical_work_authorized_by_design": False,
    }


def consumed_r10d_closure_binding(source_commit: str) -> dict[str, Any]:
    closure = validate_file_identity(
        CONSUMED_R10D_CLOSURE_PATH,
        EXPECTED_CONSUMED_R10D_CLOSURE_BYTES,
        EXPECTED_CONSUMED_R10D_CLOSURE_SHA256,
        "CONSUMED_R10D_CLOSURE",
    )
    require(
        closure.get("status") == "closed_consumed_invalid_or_incomplete_no_valid_route"
        and closure.get("route_execution_valid") is False
        and closure.get("behavioral_conclusion_available") is False
        and closure.get("physical_identity_consumed") is True
        and closure.get("same_identity_rerun_permitted") is False
        and closure.get("decision", {}).get("held_out_qualification_eligible") is False,
        "CONSUMED_R10D_CLOSURE_CONTRACT",
    )
    return {
        **committed_file_binding(
            CONSUMED_R10D_CLOSURE_PATH.relative_to(ROOT).as_posix(), source_commit
        ),
        "status": closure["status"],
        "route_execution_valid": False,
        "behavioral_conclusion_available": False,
        "physical_identity_consumed": True,
        "same_identity_rerun_permitted": False,
        "held_out_qualification_eligible": False,
    }


def validate_zero_world(value: dict[str, Any], label: str) -> None:
    require(
        value.get("model_construction_count") == 0
        and value.get("world_attempt_count") == 0
        and value.get("world_build_count") == 0
        and value.get("native_readback_count") == 0
        and value.get("solver_step_count") == 0
        and value.get("physics_state_modified") is False
        and value.get("physical_acceptance_authority") is False
        and value.get("release_authority") is False,
        f"{label}_NOT_ZERO_WORLD",
    )


def validate_retained_file_identity(
    value: Any,
    expected_path: Path,
    label: str,
) -> None:
    require(isinstance(value, dict), f"{label}_NOT_OBJECT")
    require(
        set(value) == {"path", "byte_length", "raw_sha256"},
        f"{label}_FIELDS",
    )
    declared_path = Path(str(value.get("path", "")))
    require(declared_path.is_absolute(), f"{label}_PATH_NOT_ABSOLUTE")
    require(declared_path.resolve() == expected_path.resolve(), f"{label}_PATH")
    require(expected_path.is_file(), f"{label}_MISSING")
    require(
        type(value.get("byte_length")) is int
        and value.get("byte_length") == expected_path.stat().st_size,
        f"{label}_BYTES",
    )
    require(
        is_prefixed_sha256(value.get("raw_sha256"))
        and value.get("raw_sha256") == sha256_file(expected_path),
        f"{label}_SHA256",
    )


def validate_recorded_executable_identity(
    value: Any,
    label: str,
    *,
    require_current: bool,
) -> Path:
    require(isinstance(value, dict), f"{label}_NOT_OBJECT")
    require(
        set(value) == {"path", "raw_sha256", "byte_length", "version"},
        f"{label}_FIELDS",
    )
    declared_path = Path(str(value.get("path", "")))
    require(declared_path.is_absolute(), f"{label}_PATH_NOT_ABSOLUTE")
    require(is_prefixed_sha256(value.get("raw_sha256")), f"{label}_SHA256_FORMAT")
    require(
        type(value.get("byte_length")) is int and value.get("byte_length") > 0,
        f"{label}_BYTES_FORMAT",
    )
    require(
        isinstance(value.get("version"), str) and bool(value.get("version")),
        f"{label}_VERSION",
    )
    resolved = declared_path.resolve()
    if require_current:
        require(resolved.is_file(), f"{label}_MISSING")
        require(
            value.get("byte_length") == resolved.stat().st_size,
            f"{label}_BYTES_DRIFT",
        )
        require(
            value.get("raw_sha256") == sha256_file(resolved),
            f"{label}_SHA256_DRIFT",
        )
    return resolved


def validate_runtime_identity_projection(
    projection: Any,
    attempt: dict[str, Any],
) -> dict[str, Any]:
    require(isinstance(projection, dict), "QUALIFICATION_RUNTIME_PROJECTION_NOT_OBJECT")
    require(
        set(projection) == {"schema_version", "identity_sha256", "identity"},
        "QUALIFICATION_RUNTIME_PROJECTION_FIELDS",
    )
    require(
        projection.get("schema_version") == RUNTIME_PROJECTION_SCHEMA,
        "QUALIFICATION_RUNTIME_PROJECTION_SCHEMA",
    )
    identity = projection.get("identity")
    require(isinstance(identity, dict), "QUALIFICATION_RUNTIME_IDENTITY_NOT_OBJECT")
    require(
        set(identity)
        == {
            "schema_version",
            "godot",
            "active_adapter",
            "python",
            "powershell",
            "git",
            "cargo",
            "gdformat",
        },
        "QUALIFICATION_RUNTIME_IDENTITY_FIELDS",
    )
    require(
        identity.get("schema_version") == RUNTIME_IDENTITY_SCHEMA,
        "QUALIFICATION_RUNTIME_IDENTITY_SCHEMA",
    )
    canonical = json.dumps(identity, separators=(",", ":"), sort_keys=True)
    require(
        is_prefixed_sha256(projection.get("identity_sha256"))
        and projection.get("identity_sha256")
        == sha256_bytes(canonical.encode("utf-8")),
        "QUALIFICATION_RUNTIME_IDENTITY_DIGEST",
    )

    godot = identity.get("godot")
    godot_path = validate_recorded_executable_identity(
        godot,
        "QUALIFICATION_RUNTIME_GODOT",
        require_current=True,
    )
    for tool_name in ("python", "powershell", "git", "cargo", "gdformat"):
        validate_recorded_executable_identity(
            identity.get(tool_name),
            f"QUALIFICATION_RUNTIME_{tool_name.upper()}",
            require_current=False,
        )

    adapter = identity.get("active_adapter")
    require(isinstance(adapter, dict), "QUALIFICATION_RUNTIME_ADAPTER_NOT_OBJECT")
    require(
        set(adapter) == {"path", "raw_sha256", "byte_length"},
        "QUALIFICATION_RUNTIME_ADAPTER_FIELDS",
    )
    require(
        adapter.get("path") == ACTIVE_ADAPTER_RELATIVE_PATH,
        "QUALIFICATION_RUNTIME_ADAPTER_PATH",
    )
    require(ACTIVE_ADAPTER_PATH.is_file(), "QUALIFICATION_RUNTIME_ADAPTER_MISSING")
    require(
        type(adapter.get("byte_length")) is int
        and adapter.get("byte_length") == ACTIVE_ADAPTER_PATH.stat().st_size,
        "QUALIFICATION_RUNTIME_ADAPTER_BYTES_DRIFT",
    )
    require(
        is_prefixed_sha256(adapter.get("raw_sha256"))
        and adapter.get("raw_sha256") == sha256_file(ACTIVE_ADAPTER_PATH),
        "QUALIFICATION_RUNTIME_ADAPTER_SHA256_DRIFT",
    )

    attempt_godot = attempt.get("godot")
    validate_retained_file_identity(
        attempt_godot,
        godot_path,
        "QUALIFICATION_ATTEMPT_GODOT",
    )
    require(
        attempt_godot.get("raw_sha256") == godot.get("raw_sha256")
        and attempt_godot.get("byte_length") == godot.get("byte_length"),
        "QUALIFICATION_ATTEMPT_GODOT_PROJECTION_MISMATCH",
    )
    attempt_adapter = attempt.get("active_adapter")
    validate_retained_file_identity(
        attempt_adapter,
        ACTIVE_ADAPTER_PATH,
        "QUALIFICATION_ATTEMPT_ADAPTER",
    )
    require(
        attempt_adapter.get("raw_sha256") == adapter.get("raw_sha256")
        and attempt_adapter.get("byte_length") == adapter.get("byte_length"),
        "QUALIFICATION_ATTEMPT_ADAPTER_PROJECTION_MISMATCH",
    )
    return projection


def runtime_identity_projection_self_test() -> int:
    executable = Path(sys.executable).resolve()
    executable_record = {
        "path": str(executable),
        "raw_sha256": sha256_file(executable),
        "byte_length": executable.stat().st_size,
        "version": "runtime-projection-self-test",
    }
    adapter_record = {
        "path": ACTIVE_ADAPTER_RELATIVE_PATH,
        "raw_sha256": sha256_file(ACTIVE_ADAPTER_PATH),
        "byte_length": ACTIVE_ADAPTER_PATH.stat().st_size,
    }
    identity = {
        "schema_version": RUNTIME_IDENTITY_SCHEMA,
        "godot": dict(executable_record),
        "active_adapter": dict(adapter_record),
        "python": dict(executable_record),
        "powershell": dict(executable_record),
        "git": dict(executable_record),
        "cargo": dict(executable_record),
        "gdformat": dict(executable_record),
    }

    def projection_for(value: dict[str, Any]) -> dict[str, Any]:
        canonical = json.dumps(value, separators=(",", ":"), sort_keys=True)
        return {
            "schema_version": RUNTIME_PROJECTION_SCHEMA,
            "identity_sha256": sha256_bytes(canonical.encode("utf-8")),
            "identity": value,
        }

    projection = projection_for(identity)
    attempt = {
        "godot": {
            "path": str(executable),
            "raw_sha256": executable_record["raw_sha256"],
            "byte_length": executable_record["byte_length"],
        },
        "active_adapter": {
            "path": str(ACTIVE_ADAPTER_PATH.resolve()),
            "raw_sha256": adapter_record["raw_sha256"],
            "byte_length": adapter_record["byte_length"],
        },
    }
    validate_runtime_identity_projection(projection, attempt)

    candidates: list[tuple[dict[str, Any], dict[str, Any]]] = []
    for mutation_name in (
        "projection_schema",
        "projection_digest",
        "identity_schema",
        "godot_sha256",
        "adapter_sha256",
        "tool_field",
        "attempt_godot_sha256",
        "attempt_adapter_bytes",
    ):
        candidate_projection = json.loads(json.dumps(projection))
        candidate_attempt = json.loads(json.dumps(attempt))
        if mutation_name == "projection_schema":
            candidate_projection["schema_version"] = "mutated"
        elif mutation_name == "projection_digest":
            candidate_projection["identity_sha256"] = "sha256:" + "0" * 64
        elif mutation_name == "identity_schema":
            candidate_projection["identity"]["schema_version"] = "mutated"
            candidate_projection = projection_for(candidate_projection["identity"])
        elif mutation_name == "godot_sha256":
            candidate_projection["identity"]["godot"]["raw_sha256"] = (
                "sha256:" + "0" * 64
            )
            candidate_projection = projection_for(candidate_projection["identity"])
        elif mutation_name == "adapter_sha256":
            candidate_projection["identity"]["active_adapter"]["raw_sha256"] = (
                "sha256:" + "0" * 64
            )
            candidate_projection = projection_for(candidate_projection["identity"])
        elif mutation_name == "tool_field":
            del candidate_projection["identity"]["cargo"]["version"]
            candidate_projection = projection_for(candidate_projection["identity"])
        elif mutation_name == "attempt_godot_sha256":
            candidate_attempt["godot"]["raw_sha256"] = "sha256:" + "0" * 64
        else:
            candidate_attempt["active_adapter"]["byte_length"] += 1
        candidates.append((candidate_projection, candidate_attempt))

    rejection_count = 0
    for candidate_projection, candidate_attempt in candidates:
        try:
            validate_runtime_identity_projection(
                candidate_projection, candidate_attempt
            )
        except MaterializationFailure:
            rejection_count += 1
    require(rejection_count == len(candidates), "RUNTIME_IDENTITY_MUTATION_CONTROLS")
    return rejection_count


def validate_qualification(
    qualification_root: Path,
    role: str,
    source_commit: str,
) -> dict[str, Any]:
    root = qualification_root.resolve()
    evidence = EVIDENCE_ROOT.resolve()
    require(
        root != evidence and evidence in root.parents, "QUALIFICATION_OUTSIDE_EVIDENCE"
    )
    completion_path = root / "completion.json"
    attempt_path = root / "attempt.json"
    require(completion_path.is_file(), "QUALIFICATION_COMPLETION_MISSING")
    require(attempt_path.is_file(), "QUALIFICATION_ATTEMPT_MISSING")
    completion = read_json(completion_path, "QUALIFICATION_COMPLETION")
    require(
        completion.get("schema_version") == QUALIFICATION_SCHEMA, "QUALIFICATION_SCHEMA"
    )
    require(completion.get("gate_id") == "QSDK-R10D", "QUALIFICATION_GATE")
    require(completion.get("repair_id") == "QSDK-R10D-L1", "QUALIFICATION_REPAIR")
    require(completion.get("campaign_role") == role, "QUALIFICATION_ROLE")
    require(completion.get("qualification_passed") is True, "QUALIFICATION_NOT_PASSED")
    require(
        completion.get("source", {}).get("commit") == source_commit,
        "QUALIFICATION_SOURCE",
    )
    require(
        completion.get("qualified_source_path_count") == EXPECTED_SOURCE_COUNT
        and completion.get("qualified_source_path_sha256")
        == EXPECTED_SOURCE_PATH_SHA256
        and completion.get("all_qualified_source_paths_tracked") is True,
        "QUALIFICATION_SOURCE_CLOSURE",
    )
    require(
        completion.get("r10d_l1_design_sha256") == EXPECTED_L1_DESIGN_SHA256
        and completion.get("consumed_r10d_physical_closure_sha256")
        == EXPECTED_CONSUMED_R10D_CLOSURE_SHA256,
        "QUALIFICATION_SUCCESSOR_BINDINGS",
    )
    require(
        completion.get("physical_execution_authorized") is False,
        "QUALIFICATION_AUTHORIZED_PHYSICS",
    )
    validate_zero_world(completion, "QUALIFICATION")
    attempt_identity = completion.get("attempt")
    validate_retained_file_identity(
        attempt_identity,
        attempt_path,
        "QUALIFICATION_ATTEMPT_BINDING",
    )
    attempt = read_json(attempt_path, "QUALIFICATION_ATTEMPT")
    require(
        attempt.get("schema_version") == QUALIFICATION_ATTEMPT_SCHEMA
        and attempt.get("gate_id") == "QSDK-R10D"
        and attempt.get("repair_id") == "QSDK-R10D-L1"
        and attempt.get("campaign_role") == role
        and attempt.get("source", {}).get("commit") == source_commit
        and attempt.get("r10d_l1_design_sha256") == EXPECTED_L1_DESIGN_SHA256
        and attempt.get("consumed_r10d_physical_closure_sha256")
        == EXPECTED_CONSUMED_R10D_CLOSURE_SHA256
        and attempt.get("physical_execution_authorized") is False,
        "QUALIFICATION_ATTEMPT_CONTRACT",
    )
    validate_zero_world(attempt, "QUALIFICATION_ATTEMPT")

    implementation_receipt_path = root / "implementation-receipt.json"
    validate_retained_file_identity(
        completion.get("implementation_receipt"),
        implementation_receipt_path,
        "QUALIFICATION_IMPLEMENTATION_RECEIPT_BINDING",
    )
    implementation_receipt = read_json(
        implementation_receipt_path,
        "QUALIFICATION_IMPLEMENTATION_RECEIPT",
    )
    require(
        implementation_receipt.get("schema_version") == IMPLEMENTATION_AUDIT_SCHEMA
        and implementation_receipt.get("gate_id") == "QSDK-R10D"
        and implementation_receipt.get("repair_id") == "QSDK-R10D-L1"
        and implementation_receipt.get("ok") is True
        and implementation_receipt.get("source_commit") == source_commit
        and implementation_receipt.get("official_qualification_mode") is True
        and implementation_receipt.get("physical_execution_authorized") is False,
        "QUALIFICATION_IMPLEMENTATION_RECEIPT_CONTRACT",
    )
    require(
        implementation_receipt.get("r10d_l1_design_raw_sha256")
        == EXPECTED_L1_DESIGN_SHA256
        and implementation_receipt.get("consumed_r10d_physical_closure_raw_sha256")
        == EXPECTED_CONSUMED_R10D_CLOSURE_SHA256,
        "QUALIFICATION_IMPLEMENTATION_SUCCESSOR_BINDINGS",
    )
    validate_zero_world(implementation_receipt, "QUALIFICATION_IMPLEMENTATION_RECEIPT")
    projection = completion.get("runtime_identity_projection")
    require(
        implementation_receipt.get("runtime_identity_projection") == projection,
        "QUALIFICATION_RUNTIME_PROJECTION_RECEIPT_MISMATCH",
    )
    validate_runtime_identity_projection(projection, attempt)
    return {
        "completion": completion,
        "runtime_identity_projection": projection,
        "completion_binding": {
            "completion_path": str(completion_path),
            "completion_byte_length": completion_path.stat().st_size,
            "completion_raw_sha256": sha256_bytes(completion_path.read_bytes()),
        },
    }


def development_prerequisite(role: str, source_commit: str) -> dict[str, Any] | None:
    if role == "development_route_ghost":
        return None
    relative = "sdk/qsdk_r10d_l1_development_route_ghost_physical_closure_v1.json"
    path = ROOT / relative
    require(path.is_file(), "DEVELOPMENT_ROUTE_CLOSURE_MISSING")
    result = subprocess.run(
        (
            sys.executable,
            "-B",
            str(PHYSICAL_CLOSURE_AUDIT_PATH),
            "audit",
            "--campaign-role",
            "development_route_ghost",
        ),
        cwd=ROOT,
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
        timeout=180,
    )
    require(
        result.returncode == 0,
        "DEVELOPMENT_ROUTE_CLOSURE_AUDIT_FAILED:"
        + (result.stdout + result.stderr)[-2000:],
    )
    audit_receipt = parse_marker(
        result.stdout,
        PHYSICAL_CLOSURE_AUDIT_MARKER,
        "DEVELOPMENT_ROUTE_CLOSURE_AUDIT",
    )
    validate_zero_world(audit_receipt, "DEVELOPMENT_ROUTE_CLOSURE_AUDIT")
    require(
        audit_receipt.get("schema_version")
        == "sporespore_qsdk_r10d_physical_closure_audit_v1"
        and audit_receipt.get("gate_id") == "QSDK-R10D"
        and audit_receipt.get("repair_id") == "QSDK-R10D-L1"
        and audit_receipt.get("ok") is True
        and audit_receipt.get("campaign_role") == "development_route_ghost"
        and audit_receipt.get("route_execution_valid") is True
        and type(audit_receipt.get("behavior_passed")) is bool
        and audit_receipt.get("physical_identity_consumed") is True
        and audit_receipt.get("same_identity_rerun_permitted") is False
        and audit_receipt.get("held_out_qualification_eligible") is True
        and audit_receipt.get("qsdk_r10_satisfied") is False
        and audit_receipt.get("sdk1_m07_satisfied") is False
        and audit_receipt.get("reconstructed_from_retained_evidence") is True,
        "DEVELOPMENT_ROUTE_CLOSURE_AUDIT_CONTRACT",
    )
    closure = read_json(path, "DEVELOPMENT_ROUTE_CLOSURE")
    decision = closure.get("decision")
    require(
        closure.get("schema_version")
        == "sporespore_qsdk_r10d_l1_development_route_ghost_physical_closure_v1"
        and closure.get("repair_id") == "QSDK-R10D-L1"
        and closure.get("gate_id") == "QSDK-R10D"
        and closure.get("campaign_role") == "development_route_ghost"
        and closure.get("route_execution_valid") is True
        and closure.get("physical_identity_consumed") is True
        and closure.get("same_identity_rerun_permitted") is False
        and isinstance(decision, dict)
        and decision.get("held_out_qualification_eligible") is True
        and decision.get("qsdk_r10_satisfied") is False
        and decision.get("sdk1_m07_satisfied") is False,
        "DEVELOPMENT_ROUTE_CLOSURE_CONTRACT",
    )
    binding = committed_file_binding(relative, source_commit)
    require(
        audit_receipt.get("closure_path") == relative
        and audit_receipt.get("closure_byte_length") == binding["byte_length"]
        and audit_receipt.get("closure_raw_sha256") == binding["raw_sha256"]
        and audit_receipt.get("closure_git_blob_oid") == binding["git_blob_oid"],
        "DEVELOPMENT_ROUTE_CLOSURE_AUDIT_BINDING",
    )
    return {
        **binding,
        "closure_audit_schema_version": audit_receipt["schema_version"],
        "closure_audit_passed": True,
        "reconstructed_from_retained_evidence": True,
        "route_execution_valid": True,
        "behavior_passed": closure["behavior_passed"],
        "physical_identity_consumed": True,
        "same_identity_rerun_permitted": False,
        "held_out_qualification_eligible": True,
        "qsdk_r10_satisfied": False,
        "sdk1_m07_satisfied": False,
    }


def write_new_json(path: Path, value: dict[str, Any]) -> None:
    require(path.parent.is_dir(), f"OUTPUT_PARENT_MISSING:{path.parent}")
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
    source_commit = str(identity["commit"])
    require(
        not arguments.source_commit or arguments.source_commit == source_commit,
        "SOURCE_COMMIT_NOT_CURRENT_HEAD",
    )
    qualification = validate_qualification(
        arguments.qualification_root,
        role,
        source_commit,
    )
    bindings = source_bindings(source_commit, source_commit)
    prerequisite = development_prerequisite(role, source_commit)
    l1_design = l1_successor_design_binding(source_commit)
    consumed_r10d = consumed_r10d_closure_binding(source_commit)
    output = ROOT / str(spec["stage_freeze_path"])
    require(not output.exists(), "STAGE_FREEZE_ALREADY_EXISTS")
    closure = {
        "schema_version": STAGE_SCHEMA,
        "status": "closed_passing_official_zero_world_qualification",
        "gate_id": "QSDK-R10D",
        "repair_id": "QSDK-R10D-L1",
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
        "source_tree": identity["tree"],
        "qualification_parent_commit": source_commit,
        "qualification_parent_tree": identity["tree"],
        "repository_remote": EXPECTED_REMOTE,
        "qualified_source_path_count": EXPECTED_SOURCE_COUNT,
        "qualified_source_path_sha256": EXPECTED_SOURCE_PATH_SHA256,
        "qualified_source_bindings": bindings,
        "dependency_manifest_sha256": sha256_bytes(MANIFEST_PATH.read_bytes()),
        "r10c_design_sha256": EXPECTED_DESIGN_SHA256,
        "r10d_l1_design_sha256": EXPECTED_L1_DESIGN_SHA256,
        "r10d_l1_successor_design": l1_design,
        "consumed_r10d_physical_closure_sha256": EXPECTED_CONSUMED_R10D_CLOSURE_SHA256,
        "consumed_r10d_development_route_closure": consumed_r10d,
        "consumed_r10b_held_out_closure": r10b_closure_binding(source_commit),
        "r05e_supported_start_closure": r05e_closure_binding(source_commit),
        "ordered_cell_ids": spec["ordered_cell_ids"],
        "maximum_world_count": spec["maximum_world_count"],
        "prerequisite_development_route_ghost": prerequisite,
        "qualification_evidence": qualification["completion_binding"],
        "official_zero_world_qualification_passed": True,
        "physical_execution_authorized_by_freeze": False,
        "claim_boundary": {
            "r10d_bounded_upright_push_recovery": False,
            "external_push_recovery": False,
            "fall_recovery": False,
            "prone_to_standing": False,
            "force_aware_recovery": False,
            "other_engine": False,
            "cross_engine_equivalence": False,
            "release_authorized": False,
        },
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "native_readback_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    write_new_json(output, closure)
    return {
        "mode": "stage-freeze",
        "campaign_role": role,
        "repair_id": "QSDK-R10D-L1",
        "output_path": output.relative_to(ROOT).as_posix(),
        "output_identity": file_identity(output, relative_to=ROOT),
        "source_commit": source_commit,
        "qualification_parent_commit": source_commit,
        "physical_execution_authorized": False,
    }


def validate_stage_freeze(
    freeze: dict[str, Any],
    role: str,
    stage_commit: str,
) -> dict[str, Any]:
    spec = ROLE_SPECS[role]
    source_commit = git(("rev-parse", f"{stage_commit}^"))
    require(freeze.get("schema_version") == STAGE_SCHEMA, "STAGE_SCHEMA")
    require(
        freeze.get("status") == "closed_passing_official_zero_world_qualification",
        "STAGE_STATUS",
    )
    require(freeze.get("gate_id") == "QSDK-R10D", "STAGE_GATE")
    require(freeze.get("repair_id") == "QSDK-R10D-L1", "STAGE_REPAIR")
    require(freeze.get("campaign_id") == spec["campaign_id"], "STAGE_CAMPAIGN")
    require(freeze.get("campaign_role") == role, "STAGE_ROLE")
    require(freeze.get("question_class") == spec["question_class"], "STAGE_QUESTION")
    require(freeze.get("source_commit") == source_commit, "STAGE_SOURCE")
    require(
        freeze.get("qualification_parent_commit") == source_commit,
        "STAGE_QUALIFICATION_PARENT",
    )
    require(
        freeze.get("qualified_source_path_count") == EXPECTED_SOURCE_COUNT
        and freeze.get("qualified_source_path_sha256") == EXPECTED_SOURCE_PATH_SHA256,
        "STAGE_SOURCE_CLOSURE",
    )
    require(
        freeze.get("qualified_source_bindings")
        == source_bindings(source_commit, stage_commit),
        "STAGE_SOURCE_BINDINGS",
    )
    require(freeze.get("r10c_design_sha256") == EXPECTED_DESIGN_SHA256, "STAGE_DESIGN")
    require(
        freeze.get("r10d_l1_design_sha256") == EXPECTED_L1_DESIGN_SHA256
        and freeze.get("r10d_l1_successor_design")
        == l1_successor_design_binding(source_commit),
        "STAGE_L1_DESIGN",
    )
    require(
        freeze.get("consumed_r10d_physical_closure_sha256")
        == EXPECTED_CONSUMED_R10D_CLOSURE_SHA256
        and freeze.get("consumed_r10d_development_route_closure")
        == consumed_r10d_closure_binding(source_commit),
        "STAGE_CONSUMED_R10D",
    )
    require(
        freeze.get("consumed_r10b_held_out_closure")
        == r10b_closure_binding(source_commit),
        "STAGE_R10B",
    )
    require(
        freeze.get("r05e_supported_start_closure")
        == r05e_closure_binding(source_commit),
        "STAGE_R05E",
    )
    require(freeze.get("ordered_cell_ids") == spec["ordered_cell_ids"], "STAGE_CELLS")
    require(
        freeze.get("maximum_world_count") == spec["maximum_world_count"],
        "STAGE_WORLD_COUNT",
    )
    require(
        freeze.get("prerequisite_development_route_ghost")
        == development_prerequisite(role, source_commit),
        "STAGE_DEVELOPMENT_PREREQUISITE",
    )
    require(
        freeze.get("official_zero_world_qualification_passed") is True
        and freeze.get("physical_execution_authorized_by_freeze") is False,
        "STAGE_AUTHORIZATION",
    )
    claim = freeze.get("claim_boundary")
    require(
        isinstance(claim, dict)
        and claim.get("r10d_bounded_upright_push_recovery") is False
        and claim.get("external_push_recovery") is False
        and claim.get("fall_recovery") is False
        and claim.get("force_aware_recovery") is False
        and claim.get("release_authorized") is False,
        "STAGE_CLAIMS",
    )
    validate_zero_world(freeze, "STAGE")
    qualification = freeze.get("qualification_evidence")
    require(isinstance(qualification, dict), "STAGE_QUALIFICATION_BINDING")
    completion_path = Path(str(qualification.get("completion_path", ""))).resolve()
    require(
        completion_path.is_file()
        and completion_path.stat().st_size
        == qualification.get("completion_byte_length")
        and sha256_bytes(completion_path.read_bytes())
        == qualification.get("completion_raw_sha256"),
        "STAGE_QUALIFICATION_BYTES",
    )
    validated_qualification = validate_qualification(
        completion_path.parent,
        role,
        source_commit,
    )
    require(
        validated_qualification.get("completion_binding") == qualification,
        "STAGE_QUALIFICATION_BINDING",
    )
    return spec


def materialize_execution_authority(arguments: argparse.Namespace) -> dict[str, Any]:
    identity = live_source_identity()
    role = arguments.campaign_role
    spec = ROLE_SPECS[role]
    stage_commit = str(identity["commit"])
    stage_relative = str(spec["stage_freeze_path"])
    authority_relative = str(spec["authority_path"])
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
    require(stage_path.is_file(), "STAGE_FREEZE_MISSING")
    stage_blob = git(("rev-parse", f"{stage_commit}:{stage_relative}"))
    require(
        stage_blob == git(("hash-object", "--", stage_relative)),
        "STAGE_FREEZE_BLOB_DRIFT",
    )
    freeze = read_json(stage_path, "STAGE_FREEZE")
    validate_stage_freeze(freeze, role, stage_commit)
    authority_path = ROOT / authority_relative
    require(not authority_path.exists(), "EXECUTION_AUTHORITY_ALREADY_EXISTS")
    source_commit = str(freeze["source_commit"])
    require(
        not arguments.source_commit or arguments.source_commit == source_commit,
        "SOURCE_COMMIT_ARGUMENT",
    )
    evidence_root = arguments.evidence_root.resolve()
    require(evidence_root == EVIDENCE_ROOT.resolve(), "WRONG_EVIDENCE_ROOT")
    output_root = (
        evidence_root
        / f"qsdk-r10d-{spec['physical_output_slug']}-physical-{source_commit[:12]}"
    )
    require(not output_root.exists(), "PHYSICAL_OUTPUT_IDENTITY_ALREADY_CONSUMED")
    authority = {
        "schema_version": AUTHORITY_SCHEMA,
        "status": "authorized_single_use_unconsumed",
        "gate_id": "QSDK-R10D",
        "repair_id": "QSDK-R10D-L1",
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
        "authorization_parent_commit": stage_commit,
        "qualification_parent_commit": source_commit,
        "source_commit": source_commit,
        "qualification_closure_path": stage_relative,
        "stage_freeze_sha256": sha256_bytes(stage_path.read_bytes()),
        "stage_freeze_git_blob_oid": stage_blob,
        "r10c_design_sha256": EXPECTED_DESIGN_SHA256,
        "r10d_l1_design_sha256": EXPECTED_L1_DESIGN_SHA256,
        "consumed_r10d_physical_closure_sha256": EXPECTED_CONSUMED_R10D_CLOSURE_SHA256,
        "consumed_r10b_held_out_closure_sha256": EXPECTED_R10B_CLOSURE_SHA256,
        "r05e_physical_closure_sha256": EXPECTED_R05E_CLOSURE_SHA256,
        "qualified_source_path_count": EXPECTED_SOURCE_COUNT,
        "qualified_source_path_sha256": EXPECTED_SOURCE_PATH_SHA256,
        "ordered_cell_ids": spec["ordered_cell_ids"],
        "maximum_world_count": spec["maximum_world_count"],
        "maximum_campaign_attempt_count": 1,
        "output_root": str(output_root),
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
        "repair_id": "QSDK-R10D-L1",
        "output_path": authority_relative,
        "output_identity": file_identity(authority_path, relative_to=ROOT),
        "source_commit": source_commit,
        "authorization_parent_commit": stage_commit,
        "physical_output_root": str(output_root),
        "physical_execution_authorized_after_authority_only_commit": True,
    }


def self_test() -> dict[str, Any]:
    paths, digest = source_inventory(require_tracked=False)
    validate_static_authorities()
    runtime_mutation_count = runtime_identity_projection_self_test()
    require(
        set(ROLE_SPECS) == {"development_route_ghost", "held_out_finite_decision"},
        "ROLE_SET",
    )
    require(
        ROLE_SPECS["development_route_ghost"]["ordered_cell_ids"]
        == ["baseline_s40001", "push_s40001"]
        and ROLE_SPECS["development_route_ghost"]["maximum_world_count"] == 2,
        "DEVELOPMENT_ROLE",
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
        ]
        and ROLE_SPECS["held_out_finite_decision"]["maximum_world_count"] == 6,
        "HELDOUT_ROLE",
    )
    mutations = [
        len(paths) - 1 != EXPECTED_SOURCE_COUNT,
        path_set_digest(paths[:-1]) != EXPECTED_SOURCE_PATH_SHA256,
        STAGE_SCHEMA != AUTHORITY_SCHEMA,
        ROLE_SPECS["development_route_ghost"]["campaign_id"]
        != ROLE_SPECS["held_out_finite_decision"]["campaign_id"],
        ROLE_SPECS["development_route_ghost"]["question_class"] != "finite decision",
        ROLE_SPECS["held_out_finite_decision"]["question_class"] != "development",
        EXPECTED_R10B_CLOSURE_SHA256 != EXPECTED_R05E_CLOSURE_SHA256,
        EXPECTED_DESIGN_SHA256 != EXPECTED_SOURCE_PATH_SHA256,
        EXPECTED_L1_DESIGN_SHA256 != EXPECTED_DESIGN_SHA256,
        EXPECTED_CONSUMED_R10D_CLOSURE_SHA256 != EXPECTED_R10B_CLOSURE_SHA256,
    ]
    require(all(mutations), "MUTATION_CONTROLS")
    return {
        "schema_version": "sporespore_qsdk_r10d_authority_materializer_self_test_v1",
        "gate_id": "QSDK-R10D",
        "repair_id": "QSDK-R10D-L1",
        "ok": True,
        "qualified_source_path_count": len(paths),
        "qualified_source_path_sha256": digest,
        "campaign_role_count": len(ROLE_SPECS),
        "development_world_count": 2,
        "held_out_world_count": 6,
        "authority_mutation_rejection_count": len(mutations),
        "runtime_identity_mutation_rejection_count": runtime_mutation_count,
        "r10c_design_raw_sha256": EXPECTED_DESIGN_SHA256,
        "r10d_l1_design_raw_sha256": EXPECTED_L1_DESIGN_SHA256,
        "consumed_r10d_physical_closure_raw_sha256": (
            EXPECTED_CONSUMED_R10D_CLOSURE_SHA256
        ),
        "r10b_consumed_negative_raw_sha256": EXPECTED_R10B_CLOSURE_SHA256,
        "r10b_physical_identity_consumed": True,
        "r10b_same_identity_rerun_permitted": False,
        "r05e_supported_start_raw_sha256": EXPECTED_R05E_CLOSURE_SHA256,
        "stage_freeze_authorizes_physics": False,
        "execution_authority_requires_stage_only_parent": True,
        "physical_output_must_be_absent": True,
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
        "mode",
        choices=("self-test", "stage-freeze", "execution-authority"),
    )
    parser.add_argument(
        "--campaign-role",
        choices=tuple(ROLE_SPECS),
        default="development_route_ghost",
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
                arguments.qualification_root is not None,
                "QUALIFICATION_ROOT_REQUIRED",
            )
            result = materialize_stage_freeze(arguments)
        else:
            result = materialize_execution_authority(arguments)
        print(
            MATERIALIZED_MARKER
            + json.dumps(result, separators=(",", ":"), sort_keys=True)
        )
        return 0
    except (
        MaterializationFailure,
        OSError,
        UnicodeError,
        json.JSONDecodeError,
        subprocess.TimeoutExpired,
    ) as exc:
        print(f"QSDK_R10D_AUTHORITY_MATERIALIZATION_FAIL {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
