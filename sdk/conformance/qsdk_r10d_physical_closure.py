#!/usr/bin/env python3
"""Materialize or audit immutable QSDK-R10D physical result closures at zero worlds."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys
from typing import Any, Iterable


ROOT = Path(__file__).resolve().parents[2]
EXPECTED_ROOT = Path(r"C:\Users\Cole\CodeStuff\games\SporeSpore")
EXPECTED_REMOTE = "https://github.com/Slagathore/sporespore.git"
EVIDENCE_ROOT = Path(r"C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence")
MANIFEST_PATH = ROOT / "sdk/qsdk_r10d_dependency_manifest_v2.json"
REPAIR_ID = "QSDK-R10D-L1"
R10C_DESIGN_SHA256 = (
    "sha256:2f2a4f86562e3398d69fc08510c347ed1634a2331f45ce58651db7bbb8aae4a8"
)
R10D_L1_DESIGN_RELATIVE = (
    "sdk/qsdk_r10d_l1_stage_freeze_numeric_normalization_successor_design_v1.json"
)
R10D_L1_DESIGN_BYTES = 8_548
R10D_L1_DESIGN_SHA256 = (
    "sha256:f98f9f057e6f583b6f0f356a983cdcbcb4d6818f217fe055edd96ddcbf326db3"
)
CONSUMED_R10D_CLOSURE_RELATIVE = (
    "sdk/qsdk_r10d_development_route_ghost_physical_closure_v1.json"
)
CONSUMED_R10D_CLOSURE_BYTES = 7_196
CONSUMED_R10D_CLOSURE_SHA256 = (
    "sha256:fbefa85145bcd5bb05c3672c4fe6a0b56eaf75751ae8ed5dae9ff724487b4475"
)
R10B_CLOSURE_SHA256 = (
    "sha256:108473a00fb7d789862996b85e95ef255cc62b5e2c6037aecb556bd77dce625a"
)
R05E_CLOSURE_SHA256 = (
    "sha256:dac4ac8790cd74d89da0286c36aaf541fbfe7011d2bea66077b941363d47b33e"
)
QUALIFIED_SOURCE_COUNT = 88
QUALIFIED_SOURCE_PATH_SHA256 = (
    "sha256:fde0b22bd6fbe0a51a07949efeb93550db16bdb580de39f192192f4d63c897e2"
)
PHYSICAL_REPORT_SCHEMA = "sporespore_qsdk_r10d_physical_report_v2"
PHYSICAL_CELL_SCHEMA = "sporespore_qsdk_r10d_physical_cell_v2"
WORLD_EVALUATION_SCHEMA = "sporespore_qsdk_r10d_world_evaluation_v1"
PAIR_EVALUATION_SCHEMA = "sporespore_qsdk_r10d_pair_evaluation_v1"
PHYSICAL_ATTEMPT_SCHEMA = "sporespore_qsdk_r10d_physical_attempt_v2"
STAGE_FREEZE_SCHEMA = "sporespore_qsdk_r10d_stage_freeze_v2"
EXECUTION_AUTHORITY_SCHEMA = "sporespore_qsdk_r10d_execution_authority_v2"
QUALIFICATION_SCHEMA = "sporespore_qsdk_r10d_zero_world_qualification_completion_v2"
RUNTIME_PROJECTION_SCHEMA = "sporespore_qsdk_r10d_runtime_identity_projection_v1"
RUNTIME_IDENTITY_SCHEMA = "sporespore_qsdk_r10d_runtime_identity_v1"
TRACE_SCHEMA = "sporespore_sdk_physical_trace_v1"
TRACE_POLICY_ID = "qsdk_r10d_supported_start_phase_robust_push_recovery_trace_v1"
TRACE_ROW_SCHEMA = (
    "sporespore_qsdk_r10d_supported_start_phase_robust_push_recovery_trace_row_v1"
)
SELECTED_CANDIDATE_ID = "BW5R-B"
SELECTED_POLICY_ID = "sporespore_balanced_wave_bw5r_b_v1"
SELECTED_POLICY_DIGEST = (
    "sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f"
)
GENERATOR_INDEX = 217
MORPHOLOGY_ID = "qsdk_r05e_axis_star_torso_length_low_s217"
GENERATOR_RECEIPT_SHA256 = (
    "sha256:21957689d0f3cca678c93da6993b8d6b48569f86114b3ce19df7e10cc7e1655e"
)
R05E_GENERATOR_RECEIPT_SHA256 = (
    "sha256:776dc3efb497917a79391de6d895e4984d8c35fe9ae29b3470552e2ee3a087d9"
)
R05E_PROPORTION_SPEC_SHA256 = (
    "sha256:2ad58378a1e3c6e8e9b16a9862141c4f390f2947f01b1108cd66a594a0f75d0c"
)
MATERIAL_PROFILE_ID = "godot_jolt_bw5c_mu095_v1"
FIXTURE_SPEC_SHA256 = (
    "sha256:9b54fda516c11d451f319fb9ea116896de049aa53b43676de8745ca5f29d670a"
)
CONTROLLER_PROFILE_SHA256 = (
    "sha256:e4fb8bc38d6892ec5d7a4b5eb01007ab7bdb405c69ddfccac1684889dadfba2b"
)
MATERIAL_PROFILE_SHA256 = (
    "sha256:e62b97398497f32243bae4fb6eaca258f90cbd233fc8c913c456b01a287bf993"
)
ADAPTER_CAPABILITY_SHA256 = (
    "sha256:f561944603b5b365804fbe12e9514355e71d12bfb45961b4f9499c47b52ec3cf"
)
MINIMUM_NATIVE_EFFECT_M_S = 1.0e-4
SELF_TEST_MARKER = "QSDK_R10D_PHYSICAL_CLOSURE_SELF_TEST_PASS "
MATERIALIZED_MARKER = "QSDK_R10D_PHYSICAL_CLOSURE_MATERIALIZED "
AUDIT_MARKER = "QSDK_R10D_PHYSICAL_CLOSURE_AUDIT_PASS "

ROLE_SPECS: dict[str, dict[str, Any]] = {
    "development_route_ghost": {
        "campaign_id": (
            "QSDK-R10D-SUPPORTED-START-PHASE-ROBUST-"
            "UPRIGHT-PUSH-RECOVERY-ROUTE-GHOST"
        ),
        "question_class": "development",
        "seeds": [40001],
        "ordered_cell_ids": ["baseline_s40001", "push_s40001"],
        "stage_freeze_path": (
            "sdk/qsdk_r10d_development_route_ghost_"
            "zero_world_qualification_closure_v2.json"
        ),
        "authority_path": (
            "sdk/qsdk_r10d_development_route_ghost_execution_authority_v2.json"
        ),
        "closure_path": (
            "sdk/qsdk_r10d_l1_development_route_ghost_physical_closure_v1.json"
        ),
        "closure_schema": (
            "sporespore_qsdk_r10d_l1_development_route_ghost_physical_closure_v1"
        ),
    },
    "held_out_finite_decision": {
        "campaign_id": (
            "QSDK-R10D-SUPPORTED-START-PHASE-ROBUST-" "UPRIGHT-PUSH-RECOVERY-VALIDATION"
        ),
        "question_class": "finite decision",
        "seeds": [40101, 40102, 40103],
        "ordered_cell_ids": [
            "baseline_s40101",
            "push_s40101",
            "baseline_s40102",
            "push_s40102",
            "baseline_s40103",
            "push_s40103",
        ],
        "stage_freeze_path": (
            "sdk/qsdk_r10d_held_out_finite_decision_"
            "zero_world_qualification_closure_v2.json"
        ),
        "authority_path": (
            "sdk/qsdk_r10d_held_out_finite_decision_execution_authority_v2.json"
        ),
        "closure_path": (
            "sdk/qsdk_r10d_l1_held_out_finite_decision_physical_closure_v1.json"
        ),
        "closure_schema": (
            "sporespore_qsdk_r10d_l1_held_out_finite_decision_physical_closure_v1"
        ),
    },
}


class ClosureFailure(RuntimeError):
    """Retained R10D evidence or its immutable closure is not exact."""


def require(condition: bool, code: str) -> None:
    if not condition:
        raise ClosureFailure(code)


def is_lower_hex(value: Any, length: int) -> bool:
    return (
        isinstance(value, str)
        and len(value) == length
        and all(character in "0123456789abcdef" for character in value)
    )


def is_prefixed_sha256(value: Any) -> bool:
    return (
        isinstance(value, str)
        and value.startswith("sha256:")
        and is_lower_hex(value[7:], 64)
    )


def is_finite_number(value: Any) -> bool:
    return type(value) in (int, float) and math.isfinite(float(value))


def is_finite_json_tree(value: Any) -> bool:
    if value is None or type(value) in (bool, int, str):
        return True
    if type(value) is float:
        return math.isfinite(value)
    if isinstance(value, list):
        return all(is_finite_json_tree(item) for item in value)
    if isinstance(value, dict):
        return all(
            isinstance(key, str) and is_finite_json_tree(item)
            for key, item in value.items()
        )
    return False


def sha256_bytes(value: bytes) -> str:
    return "sha256:" + hashlib.sha256(value).hexdigest()


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
        raise ClosureFailure(f"{label}_UNREADABLE:{exc}") from exc
    require(isinstance(value, dict), f"{label}_NOT_OBJECT")
    require(is_finite_json_tree(value), f"{label}_NONFINITE_JSON")
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


def live_repository_identity() -> dict[str, str]:
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
        len(live_parts) == 2
        and live_parts[1] == "refs/heads/main"
        and head == origin == live_parts[0],
        "HEAD_ORIGIN_LIVE_MISMATCH",
    )
    return {"head": head, "tree": git(("rev-parse", "HEAD^{tree}"))}


def inside(path: Path, parent: Path) -> bool:
    resolved = path.resolve()
    boundary = parent.resolve()
    return resolved != boundary and boundary in resolved.parents


def absolute_file_identity(path: Path) -> dict[str, Any]:
    resolved = path.resolve()
    require(resolved.is_file(), f"FILE_MISSING:{resolved}")
    return {
        "path": str(resolved),
        "byte_length": resolved.stat().st_size,
        "raw_sha256": sha256_file(resolved),
    }


def repository_file_identity(relative: str) -> dict[str, Any]:
    path = ROOT / relative
    require(path.is_file(), f"REPOSITORY_FILE_MISSING:{relative}")
    return {
        "path": relative,
        "byte_length": path.stat().st_size,
        "raw_sha256": sha256_file(path),
        "git_blob_oid": git(("hash-object", "--", relative)),
    }


def expected_cells(spec: dict[str, Any]) -> list[tuple[str, str, int]]:
    result: list[tuple[str, str, int]] = []
    for seed in spec["seeds"]:
        result.append((f"baseline_s{seed}", "matched_no_impulse_control", seed))
        result.append((f"push_s{seed}", "lateral_upright_impulse", seed))
    return result


def changed_paths(commit: str) -> list[str]:
    value = git(
        ("diff-tree", "--no-commit-id", "--name-only", "--no-renames", "-r", commit)
    )
    return value.splitlines()


def validate_commit_graph(
    report: dict[str, Any],
    spec: dict[str, Any],
    current_head: str,
) -> dict[str, str]:
    source = report.get("source")
    require(isinstance(source, dict), "REPORT_SOURCE_NOT_OBJECT")
    names = (
        "source_freeze_commit",
        "qualification_parent_commit",
        "qualification_commit",
        "authorization_commit",
        "authorization_tree",
        "origin_main_commit",
        "live_main_commit",
    )
    require(
        all(is_lower_hex(source.get(name), 40) for name in names), "REPORT_SOURCE_IDS"
    )
    source_commit = source["source_freeze_commit"]
    qualification_commit = source["qualification_commit"]
    authorization_commit = source["authorization_commit"]
    require(
        source["qualification_parent_commit"] == source_commit, "REPORT_SOURCE_PARENT"
    )
    require(source.get("branch") == "main", "REPORT_SOURCE_BRANCH")
    require(source.get("remote") == EXPECTED_REMOTE, "REPORT_SOURCE_REMOTE")
    require(source.get("clean") is True, "REPORT_SOURCE_NOT_CLEAN")
    require(
        source["origin_main_commit"] == authorization_commit
        and source["live_main_commit"] == authorization_commit,
        "REPORT_SOURCE_NOT_PUSHED_AT_EXECUTION",
    )
    require(
        git(("rev-parse", f"{qualification_commit}^")) == source_commit,
        "QUALIFICATION_PARENT_GRAPH",
    )
    require(
        git(("rev-parse", f"{authorization_commit}^")) == qualification_commit,
        "AUTHORIZATION_PARENT_GRAPH",
    )
    require(
        git(("rev-parse", f"{authorization_commit}^{{tree}}"))
        == source["authorization_tree"],
        "AUTHORIZATION_TREE",
    )
    require(
        changed_paths(qualification_commit) == [spec["stage_freeze_path"]],
        "QUALIFICATION_COMMIT_NOT_STAGE_ONLY",
    )
    require(
        changed_paths(authorization_commit) == [spec["authority_path"]],
        "AUTHORIZATION_COMMIT_NOT_AUTHORITY_ONLY",
    )
    ancestor = subprocess.run(
        (
            "git",
            "-C",
            str(ROOT),
            "merge-base",
            "--is-ancestor",
            authorization_commit,
            current_head,
        ),
        check=False,
    )
    require(ancestor.returncode == 0, "AUTHORIZATION_NOT_CURRENT_ANCESTOR")
    for relative, commit in (
        (spec["stage_freeze_path"], qualification_commit),
        (spec["authority_path"], authorization_commit),
    ):
        require(
            git(("rev-parse", f"{commit}:{relative}"))
            == git(("rev-parse", f"{current_head}:{relative}")),
            f"COMMITTED_AUTHORITY_DRIFT:{relative}",
        )
    return {
        "source_commit": source_commit,
        "qualification_commit": qualification_commit,
        "authorization_commit": authorization_commit,
        "authorization_tree": source["authorization_tree"],
    }


def validate_runtime_projection(value: Any) -> dict[str, Any]:
    require(isinstance(value, dict), "RUNTIME_PROJECTION_NOT_OBJECT")
    require(
        set(value) == {"schema_version", "identity_sha256", "identity"}
        and value.get("schema_version") == RUNTIME_PROJECTION_SCHEMA,
        "RUNTIME_PROJECTION_FIELDS",
    )
    identity = value.get("identity")
    require(
        isinstance(identity, dict)
        and set(identity)
        == {
            "schema_version",
            "godot",
            "active_adapter",
            "python",
            "powershell",
            "git",
            "cargo",
            "gdformat",
        }
        and identity.get("schema_version") == RUNTIME_IDENTITY_SCHEMA,
        "RUNTIME_IDENTITY_SCHEMA",
    )
    canonical = json.dumps(identity, separators=(",", ":"), sort_keys=True)
    require(
        is_prefixed_sha256(value.get("identity_sha256"))
        and value.get("identity_sha256") == sha256_bytes(canonical.encode("utf-8")),
        "RUNTIME_IDENTITY_DIGEST",
    )
    godot = identity.get("godot")
    adapter = identity.get("active_adapter")
    require(isinstance(godot, dict) and isinstance(adapter, dict), "RUNTIME_FILES")
    require(
        set(godot) == {"path", "raw_sha256", "byte_length", "version"}
        and is_prefixed_sha256(godot.get("raw_sha256"))
        and type(godot.get("byte_length")) is int
        and godot.get("byte_length") > 0
        and isinstance(godot.get("path"), str)
        and Path(godot["path"]).is_absolute()
        and isinstance(godot.get("version"), str)
        and bool(godot.get("version"))
        and set(adapter) == {"path", "raw_sha256", "byte_length"}
        and is_prefixed_sha256(adapter.get("raw_sha256"))
        and type(adapter.get("byte_length")) is int
        and adapter.get("byte_length") > 0
        and adapter.get("path") == "sdk/target/debug/sporespore_godot_adapter.dll",
        "RUNTIME_FILE_IDENTITIES",
    )
    for tool_name in ("python", "powershell", "git", "cargo", "gdformat"):
        tool = identity.get(tool_name)
        require(
            isinstance(tool, dict)
            and set(tool) == {"path", "raw_sha256", "byte_length", "version"}
            and isinstance(tool.get("path"), str)
            and Path(tool["path"]).is_absolute()
            and is_prefixed_sha256(tool.get("raw_sha256"))
            and type(tool.get("byte_length")) is int
            and tool.get("byte_length") > 0
            and isinstance(tool.get("version"), str)
            and bool(tool.get("version")),
            f"RUNTIME_TOOL_IDENTITY:{tool_name}",
        )
    return value


def validate_qualified_source_bindings(
    stage: dict[str, Any], graph: dict[str, str], current_head: str
) -> list[dict[str, Any]]:
    bindings = stage.get("qualified_source_bindings")
    require(
        isinstance(bindings, list) and len(bindings) == QUALIFIED_SOURCE_COUNT,
        "QUALIFIED_SOURCE_BINDING_COUNT",
    )
    paths: list[str] = []
    for binding in bindings:
        require(isinstance(binding, dict), "QUALIFIED_SOURCE_BINDING_NOT_OBJECT")
        require(
            set(binding) == {"path", "byte_length", "raw_sha256", "git_blob_oid"},
            "QUALIFIED_SOURCE_BINDING_FIELDS",
        )
        relative = binding.get("path")
        require(
            isinstance(relative, str)
            and relative
            and "\\" not in relative
            and not Path(relative).is_absolute(),
            "QUALIFIED_SOURCE_BINDING_PATH",
        )
        path = ROOT / relative
        require(
            path.is_file() and inside(path, ROOT),
            f"QUALIFIED_SOURCE_MISSING:{relative}",
        )
        source_blob = git(("rev-parse", f"{graph['source_commit']}:{relative}"))
        current_blob = git(("rev-parse", f"{current_head}:{relative}"))
        require(
            is_lower_hex(binding.get("git_blob_oid"), 40)
            and binding.get("git_blob_oid") == source_blob == current_blob
            and type(binding.get("byte_length")) is int
            and binding.get("byte_length") == path.stat().st_size
            and is_prefixed_sha256(binding.get("raw_sha256"))
            and binding.get("raw_sha256") == sha256_file(path),
            f"QUALIFIED_SOURCE_BINDING_DRIFT:{relative}",
        )
        paths.append(relative)
    require(paths == sorted(set(paths)), "QUALIFIED_SOURCE_BINDING_ORDER")
    require(
        sha256_bytes("\n".join(paths).encode("utf-8")) == QUALIFIED_SOURCE_PATH_SHA256,
        "QUALIFIED_SOURCE_PATH_DIGEST",
    )
    return bindings


def validate_development_prerequisite(
    stage: dict[str, Any],
    role: str,
    graph: dict[str, str],
    current_head: str,
) -> dict[str, Any] | None:
    prerequisite = stage.get("prerequisite_development_route_ghost")
    if role == "development_route_ghost":
        require(prerequisite is None, "DEVELOPMENT_PREREQUISITE_MUST_BE_NULL")
        return None
    require(isinstance(prerequisite, dict), "DEVELOPMENT_PREREQUISITE_NOT_OBJECT")
    relative = "sdk/qsdk_r10d_l1_development_route_ghost_physical_closure_v1.json"
    path = ROOT / relative
    require(
        prerequisite.get("path") == relative
        and path.is_file()
        and inside(path, ROOT)
        and prerequisite.get("byte_length") == path.stat().st_size
        and prerequisite.get("raw_sha256") == sha256_file(path)
        and prerequisite.get("git_blob_oid")
        == git(("rev-parse", f"{graph['source_commit']}:{relative}"))
        == git(("rev-parse", f"{current_head}:{relative}"))
        and prerequisite.get("closure_audit_schema_version")
        == "sporespore_qsdk_r10d_physical_closure_audit_v1"
        and prerequisite.get("repair_id") == REPAIR_ID
        and prerequisite.get("closure_audit_passed") is True
        and prerequisite.get("reconstructed_from_retained_evidence") is True
        and prerequisite.get("route_execution_valid") is True
        and type(prerequisite.get("behavior_passed")) is bool
        and prerequisite.get("physical_identity_consumed") is True
        and prerequisite.get("same_identity_rerun_permitted") is False
        and prerequisite.get("held_out_qualification_eligible") is True
        and prerequisite.get("qsdk_r10_satisfied") is False
        and prerequisite.get("sdk1_m07_satisfied") is False,
        "DEVELOPMENT_PREREQUISITE_CONTRACT",
    )
    audit_receipt = audit("development_route_ghost")
    require(
        audit_receipt.get("closure_path") == relative
        and audit_receipt.get("repair_id") == REPAIR_ID
        and audit_receipt.get("closure_byte_length") == prerequisite.get("byte_length")
        and audit_receipt.get("closure_raw_sha256") == prerequisite.get("raw_sha256")
        and audit_receipt.get("closure_git_blob_oid")
        == prerequisite.get("git_blob_oid")
        and audit_receipt.get("route_execution_valid") is True
        and audit_receipt.get("behavior_passed") is prerequisite.get("behavior_passed")
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
        "closure": repository_file_identity(relative),
        "closure_audit": audit_receipt,
    }


def validate_authority_documents(
    report: dict[str, Any],
    report_path: Path,
    spec: dict[str, Any],
    graph: dict[str, str],
    current_head: str,
) -> dict[str, Any]:
    stage_path = ROOT / spec["stage_freeze_path"]
    authority_path = ROOT / spec["authority_path"]
    require(
        stage_path.is_file() and authority_path.is_file(), "AUTHORITY_DOCUMENT_MISSING"
    )
    require(
        report.get("stage_freeze_sha256") == sha256_file(stage_path)
        and report.get("execution_authority_sha256") == sha256_file(authority_path),
        "REPORT_AUTHORITY_DIGESTS",
    )
    stage = read_json(stage_path, "STAGE_FREEZE")
    authority = read_json(authority_path, "EXECUTION_AUTHORITY")
    expected_ids = spec["ordered_cell_ids"]
    stage_claims = stage.get("claim_boundary")
    r10b = stage.get("consumed_r10b_held_out_closure")
    r05e = stage.get("r05e_supported_start_closure")
    l1_design = stage.get("r10d_l1_successor_design")
    consumed_r10d = stage.get("consumed_r10d_development_route_closure")
    l1_design_path = ROOT / R10D_L1_DESIGN_RELATIVE
    consumed_r10d_path = ROOT / CONSUMED_R10D_CLOSURE_RELATIVE
    l1_design_exact = (
        isinstance(l1_design, dict)
        and l1_design.get("path") == R10D_L1_DESIGN_RELATIVE
        and l1_design_path.is_file()
        and l1_design.get("byte_length") == R10D_L1_DESIGN_BYTES
        and l1_design_path.stat().st_size == R10D_L1_DESIGN_BYTES
        and l1_design.get("raw_sha256") == R10D_L1_DESIGN_SHA256
        and sha256_file(l1_design_path) == R10D_L1_DESIGN_SHA256
        and l1_design.get("git_blob_oid")
        == git(("rev-parse", f"{graph['source_commit']}:{R10D_L1_DESIGN_RELATIVE}"))
        == git(("rev-parse", f"{current_head}:{R10D_L1_DESIGN_RELATIVE}"))
        and l1_design.get("repair_id") == REPAIR_ID
        and l1_design.get("representation_only_repair") is True
        and l1_design.get("new_physical_work_authorized_by_design") is False
    )
    consumed_r10d_exact = (
        isinstance(consumed_r10d, dict)
        and consumed_r10d.get("path") == CONSUMED_R10D_CLOSURE_RELATIVE
        and consumed_r10d_path.is_file()
        and consumed_r10d.get("byte_length") == CONSUMED_R10D_CLOSURE_BYTES
        and consumed_r10d_path.stat().st_size == CONSUMED_R10D_CLOSURE_BYTES
        and consumed_r10d.get("raw_sha256") == CONSUMED_R10D_CLOSURE_SHA256
        and sha256_file(consumed_r10d_path) == CONSUMED_R10D_CLOSURE_SHA256
        and consumed_r10d.get("git_blob_oid")
        == git(
            (
                "rev-parse",
                f"{graph['source_commit']}:{CONSUMED_R10D_CLOSURE_RELATIVE}",
            )
        )
        == git(("rev-parse", f"{current_head}:{CONSUMED_R10D_CLOSURE_RELATIVE}"))
        and consumed_r10d.get("status")
        == "closed_consumed_invalid_or_incomplete_no_valid_route"
        and consumed_r10d.get("route_execution_valid") is False
        and consumed_r10d.get("behavioral_conclusion_available") is False
        and consumed_r10d.get("physical_identity_consumed") is True
        and consumed_r10d.get("same_identity_rerun_permitted") is False
        and consumed_r10d.get("held_out_qualification_eligible") is False
    )
    require(
        stage.get("schema_version") == STAGE_FREEZE_SCHEMA
        and stage.get("status") == "closed_passing_official_zero_world_qualification"
        and stage.get("gate_id") == "QSDK-R10D"
        and stage.get("repair_id") == REPAIR_ID
        and stage.get("campaign_id") == spec["campaign_id"]
        and stage.get("campaign_role") == report.get("campaign_role")
        and stage.get("question_class") == spec["question_class"]
        and stage.get("source_commit") == graph["source_commit"]
        and stage.get("source_tree")
        == git(("rev-parse", f"{graph['source_commit']}^{{tree}}"))
        and stage.get("qualification_parent_commit") == graph["source_commit"]
        and stage.get("qualification_parent_tree") == stage.get("source_tree")
        and stage.get("repository_remote") == EXPECTED_REMOTE
        and stage.get("qualified_source_path_count") == QUALIFIED_SOURCE_COUNT
        and stage.get("qualified_source_path_sha256") == QUALIFIED_SOURCE_PATH_SHA256
        and stage.get("dependency_manifest_sha256") == sha256_file(MANIFEST_PATH)
        and stage.get("r10c_design_sha256") == R10C_DESIGN_SHA256
        and stage.get("r10d_l1_design_sha256") == R10D_L1_DESIGN_SHA256
        and l1_design_exact
        and stage.get("consumed_r10d_physical_closure_sha256")
        == CONSUMED_R10D_CLOSURE_SHA256
        and consumed_r10d_exact
        and isinstance(r10b, dict)
        and r10b.get("path")
        == "sdk/qsdk_r10b_held_out_finite_decision_physical_closure_v1.json"
        and r10b.get("raw_sha256") == R10B_CLOSURE_SHA256
        and r10b.get("physical_identity_consumed") is True
        and r10b.get("same_identity_rerun_permitted") is False
        and r10b.get("bounded_upright_push_recovery_claimed") is False
        and isinstance(r05e, dict)
        and r05e.get("path")
        == "sdk/qsdk_r05e_exact_finite_morphology_physical_closure_v1.json"
        and r05e.get("raw_sha256") == R05E_CLOSURE_SHA256
        and r05e.get("selected_generator_index") == GENERATOR_INDEX
        and r05e.get("selected_morphology_id") == MORPHOLOGY_ID
        and r05e.get("supported_campaign_seeds") == [40101, 40102, 40103]
        and r05e.get("walking_pass_count") == 3
        and r05e.get("false_walking_receipt_count") == 0
        and r05e.get("external_push_recovery_claimed") is False
        and stage.get("ordered_cell_ids") == expected_ids
        and stage.get("maximum_world_count") == len(expected_ids)
        and stage.get("official_zero_world_qualification_passed") is True
        and stage.get("physical_execution_authorized_by_freeze") is False
        and isinstance(stage_claims, dict)
        and stage_claims
        == {
            "r10d_bounded_upright_push_recovery": False,
            "external_push_recovery": False,
            "fall_recovery": False,
            "prone_to_standing": False,
            "force_aware_recovery": False,
            "other_engine": False,
            "cross_engine_equivalence": False,
            "release_authorized": False,
        },
        "STAGE_FREEZE_CONTRACT",
    )
    validate_qualified_source_bindings(stage, graph, current_head)
    development_prerequisite = validate_development_prerequisite(
        stage, report["campaign_role"], graph, current_head
    )
    require(
        authority.get("schema_version") == EXECUTION_AUTHORITY_SCHEMA
        and authority.get("status") == "authorized_single_use_unconsumed"
        and authority.get("gate_id") == "QSDK-R10D"
        and authority.get("repair_id") == REPAIR_ID
        and authority.get("campaign_id") == spec["campaign_id"]
        and authority.get("campaign_role") == report.get("campaign_role")
        and authority.get("question_class") == spec["question_class"]
        and authority.get("authorization_commit_derived_from_current_head") is True
        and authority.get("source_commit") == graph["source_commit"]
        and authority.get("qualification_parent_commit") == graph["source_commit"]
        and authority.get("authorization_parent_commit")
        == graph["qualification_commit"]
        and authority.get("qualification_closure_path") == spec["stage_freeze_path"]
        and authority.get("stage_freeze_sha256") == sha256_file(stage_path)
        and authority.get("stage_freeze_git_blob_oid")
        == git(
            (
                "rev-parse",
                f"{graph['qualification_commit']}:{spec['stage_freeze_path']}",
            )
        )
        and authority.get("r10c_design_sha256") == R10C_DESIGN_SHA256
        and authority.get("r10d_l1_design_sha256") == R10D_L1_DESIGN_SHA256
        and authority.get("consumed_r10d_physical_closure_sha256")
        == CONSUMED_R10D_CLOSURE_SHA256
        and authority.get("consumed_r10b_held_out_closure_sha256")
        == R10B_CLOSURE_SHA256
        and authority.get("r05e_physical_closure_sha256") == R05E_CLOSURE_SHA256
        and authority.get("qualified_source_path_count") == QUALIFIED_SOURCE_COUNT
        and authority.get("qualified_source_path_sha256")
        == QUALIFIED_SOURCE_PATH_SHA256
        and authority.get("ordered_cell_ids") == expected_ids
        and authority.get("maximum_world_count") == len(expected_ids)
        and authority.get("maximum_campaign_attempt_count") == 1
        and authority.get("zero_world_qualification_passed") is True
        and authority.get("physical_execution_authorized") is True
        and authority.get("physical_identity_consumed") is False
        and authority.get("same_identity_rerun_permitted") is False
        and authority.get("physical_acceptance_authority") is False
        and authority.get("release_authority") is False,
        "EXECUTION_AUTHORITY_CONTRACT",
    )
    output_root = Path(str(authority.get("output_root", ""))).resolve()
    require(
        inside(output_root, EVIDENCE_ROOT)
        and output_root == report_path.parent.resolve()
        and report.get("output_root") == str(output_root),
        "PHYSICAL_OUTPUT_ROOT",
    )

    qualification_binding = stage.get("qualification_evidence")
    require(isinstance(qualification_binding, dict), "QUALIFICATION_BINDING_NOT_OBJECT")
    completion_path = Path(
        str(qualification_binding.get("completion_path", ""))
    ).resolve()
    require(
        inside(completion_path, EVIDENCE_ROOT)
        and completion_path.is_file()
        and completion_path.stat().st_size
        == qualification_binding.get("completion_byte_length")
        and sha256_file(completion_path)
        == qualification_binding.get("completion_raw_sha256"),
        "QUALIFICATION_BINDING_BYTES",
    )
    completion = read_json(completion_path, "QUALIFICATION_COMPLETION")
    require(
        completion.get("schema_version") == QUALIFICATION_SCHEMA
        and completion.get("gate_id") == "QSDK-R10D"
        and completion.get("repair_id") == REPAIR_ID
        and completion.get("campaign_role") == report.get("campaign_role")
        and completion.get("source", {}).get("commit") == graph["source_commit"]
        and completion.get("r10d_l1_design_sha256") == R10D_L1_DESIGN_SHA256
        and completion.get("consumed_r10d_physical_closure_sha256")
        == CONSUMED_R10D_CLOSURE_SHA256
        and completion.get("qualification_passed") is True
        and completion.get("world_attempt_count") == 0
        and completion.get("world_build_count") == 0
        and completion.get("solver_step_count") == 0
        and completion.get("physical_execution_authorized") is False,
        "QUALIFICATION_COMPLETION_CONTRACT",
    )
    runtime = validate_runtime_projection(completion.get("runtime_identity_projection"))
    runtime_identity = runtime["identity"]
    require(
        report.get("runtime_identity_sha256") == runtime["identity_sha256"]
        and report.get("godot_raw_sha256") == runtime_identity["godot"]["raw_sha256"]
        and report.get("godot_byte_length") == runtime_identity["godot"]["byte_length"]
        and report.get("active_adapter_raw_sha256")
        == runtime_identity["active_adapter"]["raw_sha256"]
        and report.get("active_adapter_byte_length")
        == runtime_identity["active_adapter"]["byte_length"],
        "REPORT_RUNTIME_BINDING",
    )
    return {
        "stage_freeze": repository_file_identity(spec["stage_freeze_path"]),
        "execution_authority": repository_file_identity(spec["authority_path"]),
        "qualification_completion": absolute_file_identity(completion_path),
        "runtime_identity_sha256": runtime["identity_sha256"],
        "godot_raw_sha256": runtime_identity["godot"]["raw_sha256"],
        "godot_byte_length": runtime_identity["godot"]["byte_length"],
        "active_adapter_raw_sha256": runtime_identity["active_adapter"]["raw_sha256"],
        "active_adapter_byte_length": runtime_identity["active_adapter"]["byte_length"],
        "development_route_prerequisite": development_prerequisite,
    }


def validate_cell(
    record: Any,
    expected: tuple[str, str, int],
    report: dict[str, Any],
    output_root: Path,
    graph: dict[str, str],
) -> dict[str, Any]:
    cell_id, arm_id, seed = expected
    require(isinstance(record, dict), f"CELL_RECORD_NOT_OBJECT:{cell_id}")
    cell_path = (output_root / cell_id / "cell.json").resolve()
    require(
        record.get("cell_id") == cell_id
        and record.get("arm_id") == arm_id
        and record.get("campaign_seed") == seed
        and inside(cell_path, output_root)
        and Path(str(record.get("path", ""))).resolve() == cell_path
        and cell_path.is_file()
        and record.get("raw_sha256") == sha256_file(cell_path)
        and record.get("evidence_valid") is True
        and type(record.get("behavior_passed")) is bool,
        f"CELL_RECORD_CONTRACT:{cell_id}",
    )
    cell = read_json(cell_path, f"CELL_{cell_id}")
    require(
        cell.get("schema_version") == PHYSICAL_CELL_SCHEMA
        and cell.get("gate_id") == "QSDK-R10D"
        and cell.get("repair_id") == REPAIR_ID
        and cell.get("campaign_id") == report.get("campaign_id")
        and cell.get("campaign_role") == report.get("campaign_role")
        and cell.get("source_commit") == graph["source_commit"]
        and cell.get("arm_id") == arm_id
        and cell.get("campaign_seed") == seed
        and cell.get("cell_id") == cell_id
        and cell.get("selected_candidate_id") == SELECTED_CANDIDATE_ID
        and cell.get("controller_policy_id") == SELECTED_POLICY_ID
        and cell.get("selected_policy_digest") == SELECTED_POLICY_DIGEST
        and cell.get("generator_index") == GENERATOR_INDEX
        and cell.get("morphology_id") == MORPHOLOGY_ID
        and cell.get("generator_receipt_sha256") == GENERATOR_RECEIPT_SHA256
        and cell.get("source_r05e_generator_receipt_sha256")
        == R05E_GENERATOR_RECEIPT_SHA256
        and cell.get("proportion_spec_sha256") == R05E_PROPORTION_SPEC_SHA256
        and cell.get("material_profile_id") == MATERIAL_PROFILE_ID
        and cell.get("material_profile_sha256") == MATERIAL_PROFILE_SHA256
        and cell.get("fixture_spec_sha256") == FIXTURE_SPEC_SHA256
        and cell.get("controller_profile_sha256") == CONTROLLER_PROFILE_SHA256
        and cell.get("adapter_capability_sha256") == ADAPTER_CAPABILITY_SHA256
        and cell.get("r10c_design_sha256") == R10C_DESIGN_SHA256
        and cell.get("r10d_l1_design_sha256") == R10D_L1_DESIGN_SHA256
        and cell.get("consumed_r10d_physical_closure_sha256")
        == CONSUMED_R10D_CLOSURE_SHA256
        and cell.get("consumed_r10b_held_out_closure_sha256") == R10B_CLOSURE_SHA256
        and cell.get("r05e_physical_closure_sha256") == R05E_CLOSURE_SHA256
        and cell.get("world_build_count") == 1
        and cell.get("world_reset_count") == 0
        and cell.get("outcome_complete") is True
        and cell.get("evidence_valid") is True
        and cell.get("behavior_passed") is record.get("behavior_passed")
        and cell.get("physical_acceptance_authority") is False
        and cell.get("release_authority") is False,
        f"CELL_CONTRACT:{cell_id}",
    )
    authorization = cell.get("authorization")
    evaluation = cell.get("evaluation")
    runtime = cell.get("runtime_summary_projection")
    trace = cell.get("sdk_physical_trace")
    require(
        all(
            isinstance(value, dict)
            for value in (authorization, evaluation, runtime, trace)
        ),
        f"CELL_REQUIRED_OBJECTS:{cell_id}",
    )
    attempt_path = (output_root / cell_id / "attempt.json").resolve()
    require(
        authorization.get("ok") is True
        and authorization.get("failure_code") == ""
        and authorization.get("repair_id") == REPAIR_ID
        and authorization.get("source_commit") == graph["source_commit"]
        and authorization.get("authorization_commit") == graph["authorization_commit"]
        and authorization.get("authorization_parent_commit")
        == graph["qualification_commit"]
        and authorization.get("qualification_parent_commit") == graph["source_commit"]
        and inside(attempt_path, output_root)
        and Path(str(authorization.get("attempt_path", ""))).resolve() == attempt_path
        and attempt_path.is_file()
        and authorization.get("attempt_sha256") == sha256_file(attempt_path)
        and authorization.get("output_root") == str(output_root)
        and authorization.get("world_build_count") == 0
        and authorization.get("physical_acceptance_authority") is False,
        f"CELL_AUTHORIZATION:{cell_id}",
    )
    attempt = read_json(attempt_path, f"ATTEMPT_{cell_id}")
    lock = attempt.get("operation_lock")
    expected_lock_role = (
        "physical_development"
        if report.get("campaign_role") == "development_route_ghost"
        else "physical"
    )
    require(
        attempt.get("schema_version") == PHYSICAL_ATTEMPT_SCHEMA
        and attempt.get("gate_id") == "QSDK-R10D"
        and attempt.get("repair_id") == REPAIR_ID
        and attempt.get("campaign_id") == report.get("campaign_id")
        and attempt.get("campaign_role") == report.get("campaign_role")
        and attempt.get("arm_id") == arm_id
        and attempt.get("campaign_seed") == seed
        and attempt.get("cell_id") == cell_id
        and attempt.get("source_commit") == graph["source_commit"]
        and attempt.get("authorization_commit") == graph["authorization_commit"]
        and attempt.get("authorization_parent_commit") == graph["qualification_commit"]
        and attempt.get("qualification_parent_commit") == graph["source_commit"]
        and attempt.get("r10c_design_sha256") == R10C_DESIGN_SHA256
        and attempt.get("r10d_l1_design_sha256") == R10D_L1_DESIGN_SHA256
        and attempt.get("consumed_r10d_physical_closure_sha256")
        == CONSUMED_R10D_CLOSURE_SHA256
        and attempt.get("consumed_r10b_held_out_closure_sha256") == R10B_CLOSURE_SHA256
        and attempt.get("r05e_physical_closure_sha256") == R05E_CLOSURE_SHA256
        and attempt.get("runtime_identity_sha256")
        == report.get("runtime_identity_sha256")
        and attempt.get("godot_raw_sha256") == report.get("godot_raw_sha256")
        and attempt.get("godot_byte_length") == report.get("godot_byte_length")
        and attempt.get("active_adapter_raw_sha256")
        == report.get("active_adapter_raw_sha256")
        and attempt.get("active_adapter_byte_length")
        == report.get("active_adapter_byte_length")
        and attempt.get("output_root") == str(output_root)
        and attempt.get("supervisor_physical_authorized") is True
        and attempt.get("synthetic_authorization_preflight") is False
        and attempt.get("maximum_world_attempt_count") == 1
        and attempt.get("maximum_world_build_count") == 1
        and attempt.get("world_attempt_count_before_worker") == 0
        and attempt.get("world_build_count_before_worker") == 0
        and attempt.get("same_identity_rerun_permitted") is False
        and attempt.get("physical_acceptance_authority") is False
        and isinstance(lock, dict)
        and lock.get("acquired") is True
        and lock.get("role") == expected_lock_role,
        f"CELL_ATTEMPT:{cell_id}",
    )
    application = evaluation.get("application_receipt")
    require(
        evaluation.get("schema_version") == WORLD_EVALUATION_SCHEMA
        and evaluation.get("gate_id") == "QSDK-R10D"
        and evaluation.get("repair_id") == REPAIR_ID
        and evaluation.get("ok") is True
        and evaluation.get("failure_code") == ""
        and evaluation.get("outcome_complete") is True
        and evaluation.get("evidence_valid") is True
        and evaluation.get("behavior_passed") is cell.get("behavior_passed")
        and evaluation.get("arm_id") == arm_id
        and evaluation.get("campaign_seed") == seed
        and evaluation.get("cell_id") == cell_id
        and evaluation.get("common_execution_integrity") is True
        and evaluation.get("walking_receipts_structurally_complete") is True
        and evaluation.get("evaluation_world_build_count") == 0
        and evaluation.get("physical_acceptance_authority") is False
        and evaluation.get("release_authority") is False
        and isinstance(application, dict),
        f"CELL_EVALUATION:{cell_id}",
    )
    if arm_id == "matched_no_impulse_control":
        require(
            application.get("application_count") == 0
            and application.get("effect_sampled") is False
            and is_finite_number(application.get("effect_magnitude_m_s"))
            and application.get("effect_magnitude_m_s") == 0.0,
            f"BASELINE_APPLICATION:{cell_id}",
        )
    else:
        require(
            application.get("application_count") == 1
            and application.get("profile_id") == "lateral_impulse_v1"
            and application.get("step_from_sdk_start") == 900
            and application.get("effect_sampled") is True
            and is_finite_number(application.get("effect_magnitude_m_s"))
            and application.get("effect_magnitude_m_s") > MINIMUM_NATIVE_EFFECT_M_S,
            f"PUSH_APPLICATION:{cell_id}",
        )
    push_receipt = runtime.get("external_push_receipt")
    require(
        runtime.get("physics_engine") == "Jolt Physics"
        and runtime.get("physics_hz") == 120
        and runtime.get("solver_velocity_steps") == 20
        and runtime.get("solver_position_steps") == 7
        and runtime.get("fixture_spec_sha256") == FIXTURE_SPEC_SHA256
        and runtime.get("sdk_material_profile_sha256") == MATERIAL_PROFILE_SHA256
        and isinstance(push_receipt, dict),
        f"CELL_RUNTIME:{cell_id}",
    )
    if arm_id == "matched_no_impulse_control":
        require(
            runtime.get("external_push_application_count") == 0 and push_receipt == {},
            f"BASELINE_RUNTIME_PUSH:{cell_id}",
        )
    else:
        require(
            runtime.get("external_push_application_count") == 1
            and push_receipt.get("target_body_id") == "torso"
            and push_receipt.get("application_method")
            == "RigidBody3D.apply_central_impulse"
            and push_receipt.get("step_from_sdk_start") == 900
            and push_receipt.get("application_count") == 1
            and push_receipt.get("controller_command") is False
            and push_receipt.get("effect_sampled") is True,
            f"PUSH_RUNTIME_RECEIPT:{cell_id}",
        )
    rows = trace.get("rows")
    failures = trace.get("failure_codes")
    options = trace.get("options")
    require(
        trace.get("schema_version") == TRACE_SCHEMA
        and trace.get("enabled") is True
        and isinstance(rows, list)
        and isinstance(failures, list)
        and failures == []
        and trace.get("row_count") == len(rows)
        and 2152 <= len(rows) <= 2872
        and isinstance(options, dict)
        and options.get("cell_id") == cell_id
        and options.get("policy_id") == TRACE_POLICY_ID
        and options.get("push_marker_semantic_step") == 900
        and options.get("trace_row_schema_version") == TRACE_ROW_SCHEMA
        and trace.get("world_build_count") == 1
        and trace.get("physical_acceptance_authority") is False,
        f"CELL_TRACE:{cell_id}",
    )
    return {
        "cell_id": cell_id,
        "arm_id": arm_id,
        "campaign_seed": seed,
        "path": str(cell_path),
        "raw_sha256": sha256_file(cell_path),
        "attempt": absolute_file_identity(attempt_path),
        "trace_row_count": len(rows),
        "behavior_passed": cell["behavior_passed"],
        "evidence_valid": True,
        "outcome_complete": True,
        "native_impulse_application_count": 0 if arm_id.startswith("matched_") else 1,
    }


def validate_pair(
    record: Any,
    seed: int,
    report: dict[str, Any],
    output_root: Path,
    cells: dict[str, dict[str, Any]],
) -> dict[str, Any]:
    require(isinstance(record, dict), f"PAIR_RECORD_NOT_OBJECT:{seed}")
    pair_path = (output_root / f"pair-s{seed}.json").resolve()
    baseline_id = f"baseline_s{seed}"
    push_id = f"push_s{seed}"
    require(
        record.get("campaign_seed") == seed
        and inside(pair_path, output_root)
        and Path(str(record.get("path", ""))).resolve() == pair_path
        and pair_path.is_file()
        and record.get("raw_sha256") == sha256_file(pair_path)
        and type(record.get("behavior_passed")) is bool
        and record.get("native_effect_confirmed") is True,
        f"PAIR_RECORD_CONTRACT:{seed}",
    )
    pair = read_json(pair_path, f"PAIR_{seed}")
    native_effect = pair.get("native_effect_magnitude_m_s")
    paired_jump_difference = pair.get("paired_lateral_velocity_jump_difference_m_s")
    require(
        pair.get("schema_version") == PAIR_EVALUATION_SCHEMA
        and pair.get("gate_id") == "QSDK-R10D"
        and pair.get("repair_id") == REPAIR_ID
        and pair.get("ok") is True
        and pair.get("failure_code") == ""
        and pair.get("outcome_complete") is True
        and pair.get("evidence_valid") is True
        and pair.get("behavior_passed") is record.get("behavior_passed")
        and pair.get("campaign_seed") == seed
        and pair.get("baseline_cell_id") == baseline_id
        and pair.get("push_cell_id") == push_id
        and pair.get("matched_initial_perturbation") is True
        and pair.get("native_effect_confirmed") is True
        and is_finite_number(native_effect)
        and native_effect > MINIMUM_NATIVE_EFFECT_M_S
        and is_finite_number(paired_jump_difference)
        and paired_jump_difference > 0.0
        and pair.get("baseline_behavior_passed")
        is cells[baseline_id]["behavior_passed"]
        and pair.get("push_behavior_passed") is cells[push_id]["behavior_passed"]
        and pair.get("behavior_passed")
        is (cells[baseline_id]["behavior_passed"] and cells[push_id]["behavior_passed"])
        and pair.get("baseline_cell_raw_sha256") == cells[baseline_id]["raw_sha256"]
        and pair.get("push_cell_raw_sha256") == cells[push_id]["raw_sha256"]
        and pair.get("model_construction_count") == 0
        and pair.get("world_attempt_count") == 0
        and pair.get("world_build_count") == 0
        and pair.get("solver_step_count") == 0
        and pair.get("physics_state_modified") is False
        and pair.get("physical_acceptance_authority") is False,
        f"PAIR_CONTRACT:{seed}",
    )
    return {
        "campaign_seed": seed,
        "path": str(pair_path),
        "raw_sha256": sha256_file(pair_path),
        "baseline_cell_id": baseline_id,
        "push_cell_id": push_id,
        "baseline_cell_raw_sha256": cells[baseline_id]["raw_sha256"],
        "push_cell_raw_sha256": cells[push_id]["raw_sha256"],
        "behavior_passed": pair["behavior_passed"],
        "native_effect_confirmed": True,
        "native_effect_magnitude_m_s": pair["native_effect_magnitude_m_s"],
        "paired_lateral_velocity_jump_difference_m_s": pair[
            "paired_lateral_velocity_jump_difference_m_s"
        ],
    }


def evidence_tree_inventory(output_root: Path) -> dict[str, Any]:
    require(
        output_root.is_dir() and inside(output_root, EVIDENCE_ROOT),
        "EVIDENCE_TREE_ROOT",
    )
    entries: list[dict[str, Any]] = []
    for path in sorted(
        output_root.rglob("*"),
        key=lambda item: item.relative_to(output_root).as_posix(),
    ):
        require(not path.is_symlink(), f"EVIDENCE_TREE_SYMLINK:{path}")
        if not path.is_file():
            continue
        entries.append(
            {
                "path": path.relative_to(output_root).as_posix(),
                "byte_length": path.stat().st_size,
                "raw_sha256": sha256_file(path),
            }
        )
    paths = [entry["path"] for entry in entries]
    require(paths == sorted(set(paths)), "EVIDENCE_TREE_PATH_ORDER")
    require("report.json" in paths, "EVIDENCE_TREE_REPORT_MISSING")
    canonical_entries = json.dumps(
        entries,
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")
    return {
        "schema_version": "sporespore_qsdk_r10d_retained_evidence_tree_v1",
        "root": str(output_root),
        "file_count": len(entries),
        "total_byte_length": sum(entry["byte_length"] for entry in entries),
        "path_set_sha256": sha256_bytes("\n".join(paths).encode("utf-8")),
        "manifest_sha256": sha256_bytes(canonical_entries),
        "files": entries,
    }


def validate_report(
    report_path: Path,
    role: str,
    current_head: str,
) -> dict[str, Any]:
    spec = ROLE_SPECS[role]
    resolved = report_path.resolve()
    require(
        resolved.name == "report.json" and inside(resolved, EVIDENCE_ROOT),
        "REPORT_OUTSIDE_DURABLE_EVIDENCE",
    )
    report = read_json(resolved, "PHYSICAL_REPORT")
    expected_ids = spec["ordered_cell_ids"]
    status = report.get("status")
    complete_valid = status in {
        "complete_valid_positive",
        "complete_valid_finite_negative",
    }
    invalid_or_incomplete = status == "invalid_or_incomplete"
    world_attempt_count = report.get("world_attempt_count")
    records = report.get("cells")
    pair_records = report.get("pairs")
    failure_record = report.get("failure_record")
    require(
        report.get("schema_version") == PHYSICAL_REPORT_SCHEMA
        and report.get("gate_id") == "QSDK-R10D"
        and report.get("repair_id") == REPAIR_ID
        and report.get("campaign_id") == spec["campaign_id"]
        and report.get("campaign_role") == role
        and report.get("question_class") == spec["question_class"]
        and (complete_valid or invalid_or_incomplete)
        and report.get("ordered_cell_ids") == expected_ids
        and type(world_attempt_count) is int
        and 0 <= world_attempt_count <= len(expected_ids)
        and report.get("expected_world_count") == len(expected_ids)
        and isinstance(records, list)
        and isinstance(pair_records, list)
        and report.get("pair_count") == len(pair_records)
        and report.get("confirmed_valid_world_build_count") == len(records)
        and report.get("world_build_count_known") is complete_valid
        and report.get("world_build_count")
        == (len(expected_ids) if complete_valid else None)
        and report.get("complete") is complete_valid
        and report.get("evidence_valid") is complete_valid
        and report.get("outcome_complete") is complete_valid
        and report.get("behavioral_conclusion_available") is complete_valid
        and (
            type(report.get("behavior_passed")) is bool
            if complete_valid
            else report.get("behavior_passed") is None
        )
        and (
            failure_record is None
            if complete_valid
            else isinstance(failure_record, dict)
        )
        and report.get("same_identity_rerun_permitted") is False
        and report.get("physical_acceptance_authority") is False
        and report.get("release_authority") is False
        and report.get("r10c_design_sha256") == R10C_DESIGN_SHA256
        and report.get("r10d_l1_design_sha256") == R10D_L1_DESIGN_SHA256
        and report.get("consumed_r10d_physical_closure_sha256")
        == CONSUMED_R10D_CLOSURE_SHA256
        and report.get("consumed_r10b_held_out_closure_sha256") == R10B_CLOSURE_SHA256
        and report.get("r05e_physical_closure_sha256") == R05E_CLOSURE_SHA256,
        "PHYSICAL_REPORT_CONTRACT",
    )
    if invalid_or_incomplete:
        require(
            failure_record.get("schema_version")
            == "sporespore_qsdk_r10d_physical_failure_v2"
            and failure_record.get("repair_id") == REPAIR_ID
            and failure_record.get("failure_code")
            == "QSDK_R10D_PHYSICAL_CAMPAIGN_INVALID_OR_INCOMPLETE"
            and isinstance(failure_record.get("failure_stage"), str)
            and bool(failure_record.get("failure_stage"))
            and (
                failure_record.get("campaign_seed") is None
                or failure_record.get("campaign_seed") in spec["seeds"]
            )
            and isinstance(failure_record.get("arm_id"), str)
            and isinstance(failure_record.get("cell_id"), str)
            and isinstance(failure_record.get("message"), str)
            and bool(failure_record.get("message"))
            and failure_record.get("behavioral_conclusion_available") is False
            and failure_record.get("same_identity_rerun_permitted") is False,
            "PHYSICAL_REPORT_FAILURE_RECORD",
        )
    graph = validate_commit_graph(report, spec, current_head)
    authorities = validate_authority_documents(
        report, resolved, spec, graph, current_head
    )
    output_root = resolved.parent.resolve()
    require(
        (len(records) == len(expected_ids) if complete_valid else True)
        and len(records) <= len(expected_ids)
        and world_attempt_count >= len(records),
        "REPORT_CELL_RECORDS",
    )
    cell_projections: list[dict[str, Any]] = []
    cells_by_id: dict[str, dict[str, Any]] = {}
    expected_cell_sequence = expected_cells(spec)
    for index, record in enumerate(records):
        expected = expected_cell_sequence[index]
        projection = validate_cell(record, expected, report, output_root, graph)
        cell_projections.append(projection)
        cells_by_id[projection["cell_id"]] = projection
    require(
        (len(pair_records) == len(spec["seeds"]) if complete_valid else True)
        and len(pair_records) <= len(spec["seeds"])
        and len(pair_records) <= len(records) // 2,
        "REPORT_PAIR_RECORDS",
    )
    pair_projections = [
        validate_pair(record, seed, report, output_root, cells_by_id)
        for record, seed in zip(pair_records, spec["seeds"])
    ]
    aggregate_behavior: bool | None = None
    if complete_valid:
        require(world_attempt_count == len(expected_ids), "REPORT_COMPLETE_ATTEMPTS")
        aggregate_behavior = all(pair["behavior_passed"] for pair in pair_projections)
        require(
            aggregate_behavior is report["behavior_passed"],
            "REPORT_BEHAVIOR_AGGREGATE",
        )
        require(
            status
            == (
                "complete_valid_positive"
                if aggregate_behavior
                else "complete_valid_finite_negative"
            ),
            "PHYSICAL_REPORT_STATUS_CLASSIFICATION",
        )
    else:
        require(
            len(records) < len(expected_ids) or len(pair_records) < len(spec["seeds"]),
            "INVALID_REPORT_NOT_INCOMPLETE",
        )
    return {
        "role": role,
        "spec": spec,
        "report": report,
        "report_identity": absolute_file_identity(resolved),
        "graph": graph,
        "authorities": authorities,
        "cells": cell_projections,
        "pairs": pair_projections,
        "output_root": output_root,
        "retained_evidence_tree": evidence_tree_inventory(output_root),
        "route_execution_valid": complete_valid,
        "behavior_passed": aggregate_behavior,
        "invalid_or_incomplete": invalid_or_incomplete,
    }


def classification(
    role: str, route_valid: bool, behavior_passed: Any
) -> dict[str, Any]:
    require(
        role in {"development_route_ghost", "held_out_finite_decision"},
        "ROLE_UNKNOWN",
    )
    require(type(route_valid) is bool, "ROUTE_VALIDITY_NOT_BOOLEAN")
    if not route_valid:
        require(behavior_passed is None, "INVALID_ROUTE_HAS_BEHAVIOR_CONCLUSION")
        return {
            "status": (
                "closed_consumed_invalid_or_incomplete_no_valid_route"
                if role == "development_route_ghost"
                else "closed_consumed_invalid_or_incomplete_no_finite_decision"
            ),
            "result": (
                "development_route_invalid_or_incomplete_no_behavioral_conclusion"
                if role == "development_route_ghost"
                else "held_out_invalid_or_incomplete_no_behavioral_conclusion"
            ),
            "qsdk_r10_satisfied": False,
            "sdk1_m07_satisfied": False,
            "held_out_qualification_eligible": False,
        }
    require(type(behavior_passed) is bool, "BEHAVIOR_NOT_BOOLEAN")
    if role == "development_route_ghost":
        status = (
            "closed_execution_valid_complete_behavior_positive"
            if behavior_passed
            else "closed_execution_valid_complete_behavior_finite_negative"
        )
        return {
            "status": status,
            "result": (
                "development_route_execution_valid_behavior_positive"
                if behavior_passed
                else "development_route_execution_valid_behavior_finite_negative"
            ),
            "qsdk_r10_satisfied": False,
            "sdk1_m07_satisfied": False,
            "held_out_qualification_eligible": True,
        }
    return {
        "status": (
            "closed_consumed_valid_complete_finite_positive"
            if behavior_passed
            else "closed_consumed_valid_complete_finite_negative"
        ),
        "result": (
            "consumed_valid_complete_held_out_finite_positive"
            if behavior_passed
            else "consumed_valid_complete_held_out_finite_negative"
        ),
        "qsdk_r10_satisfied": behavior_passed,
        "sdk1_m07_satisfied": behavior_passed,
        "held_out_qualification_eligible": False,
    }


def build_closure(validated: dict[str, Any]) -> dict[str, Any]:
    role = validated["role"]
    spec = validated["spec"]
    route_valid = validated["route_execution_valid"]
    behavior_passed = validated["behavior_passed"]
    result = classification(role, route_valid, behavior_passed)
    report = validated["report"]
    world_attempt_count = report["world_attempt_count"]
    confirmed_world_count = len(validated["cells"])
    reported_world_count = report["world_build_count"]
    pair_count = len(validated["pairs"])
    baseline_application_count = sum(
        cell["native_impulse_application_count"]
        for cell in validated["cells"]
        if cell["arm_id"] == "matched_no_impulse_control"
    )
    push_application_count = sum(
        cell["native_impulse_application_count"]
        for cell in validated["cells"]
        if cell["arm_id"] == "lateral_upright_impulse"
    )
    sdk1_steps = (
        14
        if role == "held_out_finite_decision" and route_valid and behavior_passed
        else 13
    )
    return {
        "schema_version": spec["closure_schema"],
        "status": result["status"],
        "gate_id": "QSDK-R10D",
        "repair_id": REPAIR_ID,
        "campaign_id": spec["campaign_id"],
        "campaign_role": role,
        "question_class": spec["question_class"],
        "ledger_scope": {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "closed_consumed_physical_evidence",
            "question_class": spec["question_class"],
        },
        "source": validated["graph"],
        "r10c_design_sha256": R10C_DESIGN_SHA256,
        "r10d_l1_design_sha256": R10D_L1_DESIGN_SHA256,
        "consumed_r10d_physical_closure_sha256": CONSUMED_R10D_CLOSURE_SHA256,
        "evidence": {
            "report": validated["report_identity"],
            **validated["authorities"],
            "cells": validated["cells"],
            "pairs": validated["pairs"],
            "retained_evidence_tree": validated["retained_evidence_tree"],
        },
        "outcome": {
            "world_attempt_count": world_attempt_count,
            "world_build_count": reported_world_count,
            "world_build_count_known": route_valid,
            "confirmed_valid_world_build_count": confirmed_world_count,
            "pair_count": pair_count,
            "complete": route_valid,
            "evidence_valid": route_valid,
            "outcome_complete": route_valid,
            "behavioral_conclusion_available": route_valid,
            "behavior_passed": behavior_passed,
            "baseline_native_impulse_application_count": baseline_application_count,
            "push_native_impulse_application_count": push_application_count,
            "native_effect_confirmed_pair_count": pair_count,
            "failure_record": report["failure_record"],
        },
        "route_execution_valid": route_valid,
        "behavior_passed": behavior_passed,
        "evidence_valid": route_valid,
        "outcome_complete": route_valid,
        "behavioral_conclusion_available": route_valid,
        "physical_identity_consumed": True,
        "same_identity_rerun_permitted": False,
        "decision": {
            "result": result["result"],
            "qsdk_r10_satisfied": result["qsdk_r10_satisfied"],
            "sdk1_m07_satisfied": result["sdk1_m07_satisfied"],
            "held_out_qualification_eligible": result[
                "held_out_qualification_eligible"
            ],
            "threshold_change_applied": False,
            "population_change_applied": False,
            "controller_change_applied": False,
            "same_identity_rerun_permitted": False,
            "new_physical_work_authorized": False,
            "next_legal_work": (
                "zero_world_retained_evidence_diagnosis_and_new_successor_identity_only"
                if not route_valid
                else (
                    "held_out_zero_world_qualification_and_new_authority_graph"
                    if role == "development_route_ghost"
                    else (
                        "update_sdk1_m07_release_ledgers"
                        if behavior_passed
                        else "zero_world_retained_evidence_diagnosis_only"
                    )
                )
            ),
        },
        "sdk_status": {
            "sdk1_completed_steps": sdk1_steps,
            "sdk1_total_steps": 20,
            "full_program_completed_steps": sdk1_steps,
            "full_program_total_steps": 25,
            "qsdk_r10_satisfied": result["qsdk_r10_satisfied"],
            "sdk1_m07_satisfied": result["sdk1_m07_satisfied"],
        },
        "claim_boundary": {
            "retained_physical_attempt_claimed": True,
            "physical_identity_consumed_claimed": True,
            "genuine_godot_jolt_world_count_claimed": reported_world_count,
            "genuine_godot_jolt_world_count_known": route_valid,
            "confirmed_valid_godot_jolt_world_count_claimed": confirmed_world_count,
            "route_execution_valid_claimed": route_valid,
            "native_external_push_application_count_claimed": push_application_count,
            "native_external_push_effect_count_claimed": pair_count,
            "bounded_upright_push_recovery_claimed": (
                bool(behavior_passed)
                if route_valid and role == "held_out_finite_decision"
                else False
            ),
            "external_push_recovery_claimed": (
                bool(behavior_passed)
                if route_valid and role == "held_out_finite_decision"
                else False
            ),
            "fall_recovery_claimed": False,
            "prone_to_standing_claimed": False,
            "force_aware_recovery_claimed": False,
            "other_engine_claimed": False,
            "cross_engine_equivalence_claimed": False,
            "population_success_rate_claimed": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        "closure_process": {
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "native_readback_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
    }


def write_new_json(path: Path, value: dict[str, Any]) -> None:
    require(path.parent == ROOT / "sdk", "CLOSURE_OUTPUT_PARENT")
    raw = (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
    try:
        with path.open("xb") as stream:
            stream.write(raw)
            stream.flush()
    except FileExistsError as exc:
        raise ClosureFailure("CLOSURE_ALREADY_EXISTS") from exc


def self_test() -> dict[str, Any]:
    controls = [
        classification("development_route_ghost", True, True)["status"]
        == "closed_execution_valid_complete_behavior_positive",
        classification("development_route_ghost", True, False)["status"]
        == "closed_execution_valid_complete_behavior_finite_negative",
        classification("held_out_finite_decision", True, True)["sdk1_m07_satisfied"]
        is True,
        classification("held_out_finite_decision", True, False)["sdk1_m07_satisfied"]
        is False,
        classification("development_route_ghost", False, None)[
            "held_out_qualification_eligible"
        ]
        is False,
        classification("held_out_finite_decision", False, None)["qsdk_r10_satisfied"]
        is False,
    ]
    refusals = 0
    for role, route_valid, behavior in (
        ("development_route_ghost", False, True),
        ("held_out_finite_decision", True, 1),
        ("unknown", True, False),
    ):
        try:
            classification(role, route_valid, behavior)
        except ClosureFailure:
            refusals += 1
    numeric_controls = [
        is_finite_number(0.0),
        is_finite_number(1),
        not is_finite_number(True),
        not is_finite_number(float("nan")),
        not is_finite_number(float("inf")),
        not is_finite_number("1.0"),
    ]
    json_tree_controls = [
        is_finite_json_tree({"a": [None, True, 1, 1.5, "value"]}),
        not is_finite_json_tree({"a": float("nan")}),
        not is_finite_json_tree([float("-inf")]),
    ]
    require(all(controls) and refusals == 3, "CLOSURE_CLASSIFICATION_CONTROLS")
    require(all(numeric_controls), "CLOSURE_NUMERIC_CONTROLS")
    require(all(json_tree_controls), "CLOSURE_JSON_TREE_CONTROLS")
    return {
        "schema_version": "sporespore_qsdk_r10d_physical_closure_self_test_v1",
        "gate_id": "QSDK-R10D",
        "repair_id": REPAIR_ID,
        "ok": True,
        "classification_positive_control_count": len(controls),
        "invalid_or_incomplete_classification_control_count": 2,
        "classification_mutation_rejection_count": refusals,
        "numeric_validation_control_count": len(numeric_controls),
        "finite_json_tree_control_count": len(json_tree_controls),
        "campaign_role_count": len(ROLE_SPECS),
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "native_readback_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def materialize(role: str, report_path: Path) -> dict[str, Any]:
    identity = live_repository_identity()
    validated = validate_report(report_path, role, identity["head"])
    closure = build_closure(validated)
    output = ROOT / ROLE_SPECS[role]["closure_path"]
    write_new_json(output, closure)
    return {
        "mode": "materialize",
        "campaign_role": role,
        "repair_id": REPAIR_ID,
        "output_path": ROLE_SPECS[role]["closure_path"],
        "output_identity": repository_file_identity(ROLE_SPECS[role]["closure_path"]),
        "route_execution_valid": closure["route_execution_valid"],
        "behavior_passed": closure["behavior_passed"],
        "physical_identity_consumed": True,
        "same_identity_rerun_permitted": False,
        "closure_process_world_build_count": 0,
    }


def audit(role: str) -> dict[str, Any]:
    identity = live_repository_identity()
    relative = ROLE_SPECS[role]["closure_path"]
    path = ROOT / relative
    require(path.is_file(), "CLOSURE_MISSING")
    require(
        git(("rev-parse", f"HEAD:{relative}")) == git(("hash-object", "--", relative)),
        "CLOSURE_NOT_COMMITTED_CURRENT",
    )
    closure = read_json(path, "PHYSICAL_CLOSURE")
    evidence = closure.get("evidence")
    require(isinstance(evidence, dict), "CLOSURE_EVIDENCE_NOT_OBJECT")
    report_binding = evidence.get("report")
    require(isinstance(report_binding, dict), "CLOSURE_REPORT_BINDING_NOT_OBJECT")
    report_path = Path(str(report_binding.get("path", ""))).resolve()
    require(
        absolute_file_identity(report_path) == report_binding,
        "CLOSURE_REPORT_BINDING_DRIFT",
    )
    validated = validate_report(report_path, role, identity["head"])
    require(closure == build_closure(validated), "CLOSURE_DOCUMENT_DRIFT")
    decision = closure.get("decision")
    require(isinstance(decision, dict), "CLOSURE_DECISION_NOT_OBJECT")
    return {
        "schema_version": "sporespore_qsdk_r10d_physical_closure_audit_v1",
        "gate_id": "QSDK-R10D",
        "repair_id": REPAIR_ID,
        "ok": True,
        "campaign_role": role,
        "closure_path": relative,
        "closure_byte_length": path.stat().st_size,
        "closure_raw_sha256": sha256_file(path),
        "closure_git_blob_oid": git(("rev-parse", f"HEAD:{relative}")),
        "closure_status": closure["status"],
        "closure_result": decision["result"],
        "route_execution_valid": closure["route_execution_valid"],
        "behavior_passed": closure["behavior_passed"],
        "physical_identity_consumed": True,
        "same_identity_rerun_permitted": False,
        "held_out_qualification_eligible": decision["held_out_qualification_eligible"],
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


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("self-test", "materialize", "audit"))
    parser.add_argument(
        "--campaign-role",
        choices=tuple(ROLE_SPECS),
        default="development_route_ghost",
    )
    parser.add_argument("--report", type=Path)
    arguments = parser.parse_args()
    try:
        if arguments.mode == "self-test":
            print(
                SELF_TEST_MARKER
                + json.dumps(self_test(), separators=(",", ":"), sort_keys=True)
            )
            return 0
        if arguments.mode == "materialize":
            require(arguments.report is not None, "REPORT_ARGUMENT_REQUIRED")
            result = materialize(arguments.campaign_role, arguments.report)
            marker = MATERIALIZED_MARKER
        else:
            result = audit(arguments.campaign_role)
            marker = AUDIT_MARKER
        print(marker + json.dumps(result, separators=(",", ":"), sort_keys=True))
        return 0
    except (
        ClosureFailure,
        AttributeError,
        IndexError,
        KeyError,
        OSError,
        TypeError,
        UnicodeError,
        ValueError,
        subprocess.SubprocessError,
    ) as exc:
        print(f"QSDK_R10D_PHYSICAL_CLOSURE_FAIL {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
