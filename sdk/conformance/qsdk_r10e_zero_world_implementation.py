#!/usr/bin/env python3
"""Audit the complete QSDK-R10E implementation without constructing a world."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
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
    ROOT
    / "sdk/qsdk_r10e_observer_minimized_upright_push_recovery_successor_design_v1.json"
)
DESIGN_AUDIT_PATH = (
    ROOT
    / "sdk/conformance/qsdk_r10e_observer_minimized_upright_push_recovery_successor_design.py"
)
R10D_DEVELOPMENT_PATH = (
    ROOT / "sdk/qsdk_r10d_l1_development_route_ghost_physical_closure_v1.json"
)
R10D_HELD_OUT_PATH = (
    ROOT / "sdk/qsdk_r10d_l1_held_out_finite_decision_physical_closure_v1.json"
)
R05E_PATH = ROOT / "sdk/qsdk_r05e_exact_finite_morphology_physical_closure_v1.json"
QUALIFICATION_FAILURE_CLOSURE_PATH = (
    ROOT / "sdk/qsdk_r10e_development_route_ghost_"
    "zero_world_qualification_failure_closure_v1.json"
)
SUPERVISOR_REFUSAL_CLOSURE_PATH = (
    ROOT / "sdk/qsdk_r10e_development_route_ghost_physical_supervisor_refusal_v1.json"
)
L2_HELD_OUT_FAILURE_CLOSURE_PATH = (
    ROOT / "sdk/qsdk_r10e_l2_held_out_finite_decision_physical_failure_closure_v1.json"
)
DEPENDENCY_AUDIT_PATH = ROOT / "sdk/conformance/qsdk_r10e_dependency_closure.py"
MATERIALIZER_PATH = ROOT / "sdk/conformance/qsdk_r10e_authority_materializer.py"
PHYSICAL_CLOSURE_PATH = ROOT / "sdk/conformance/qsdk_r10e_physical_closure.py"
SUPERVISOR_PATH = (
    ROOT / "sdk/run_qsdk_r10e_observer_minimized_upright_push_recovery.ps1"
)
QUALIFICATION_PATH = ROOT / "sdk/qsdk_r10e_zero_world_qualification.ps1"
OPERATION_LOCK_PATH = ROOT / "sdk/locomotion_operation_lock.ps1"
ACTIVE_ADAPTER_PATH = ROOT / "sdk/target/debug/sporespore_godot_adapter.dll"

SOURCE_SCRIPT = (
    "res://tests/test_sdk_qsdk_r10e_"
    "observer_minimized_upright_push_recovery_source.gd"
)
WORKER_SCRIPT = (
    "res://tests/test_sdk_qsdk_r10e_"
    "observer_minimized_upright_push_recovery_worker.gd"
)
DEFERRED_TRACE_TEST = (
    "res://tests/test_sdk_qsdk_r10e_deferred_recovery_trace_zero_world.gd"
)
SCALAR_RECEIPT_TEST = (
    "res://tests/test_sdk_qsdk_r10e_"
    "native_impulse_scalar_receipt_validation_zero_world.gd"
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
EXPECTED_QUALIFICATION_FAILURE_CLOSURE_BYTES = 5_827
EXPECTED_QUALIFICATION_FAILURE_CLOSURE_SHA256 = (
    "sha256:5a8b2060c2582c81673c6a9c27b96f8179b998b37c11d4310a58a84ab5a8b2f5"
)
FAILED_QUALIFICATION_SOURCE_COMMIT = "831e5703f682703cfa6e9f721b0ce564dcb6ce9b"
FAILED_QUALIFICATION_SOURCE_TREE = "7b276feed657d432daff39df5b738303009a2932"
EXPECTED_SUPERVISOR_REFUSAL_CLOSURE_BYTES = 5_728
EXPECTED_SUPERVISOR_REFUSAL_CLOSURE_SHA256 = (
    "sha256:831c1c8bdc3720be7e1c9abe584cea098856982b4795f23f00c029f18b3b7fc0"
)
REFUSED_PHYSICAL_SOURCE_COMMIT = "0dbd259477d01c6de026f4c99587619a69b59b44"
REFUSED_PHYSICAL_SOURCE_TREE = "42364f743ce3226868537436259b24f715df0469"
REFUSED_PHYSICAL_STAGE_COMMIT = "047739f02306d20f28153ef34758ec3d30fbcb2e"
REFUSED_PHYSICAL_STAGE_TREE = "956853461fbd1fadd15d27b6778cf6402aed38f9"
REFUSED_PHYSICAL_AUTHORITY_COMMIT = "716feb860ba3ca980d90cb96cc4d72cd2e24b808"
REFUSED_PHYSICAL_AUTHORITY_TREE = "975426eac66af7e85e9181528cd2da6775e3690d"
EXPECTED_L2_HELD_OUT_FAILURE_CLOSURE_BYTES = 14_311
EXPECTED_L2_HELD_OUT_FAILURE_CLOSURE_SHA256 = (
    "sha256:29942c4f666d3cc7d88388945bb450d6d64f01a6757f72f7a38e149b5d351211"
)
L2_HELD_OUT_SOURCE_COMMIT = "ea290eab9bed81788c87d3e6a0271fb4fda0f27c"
L2_HELD_OUT_SOURCE_TREE = "62a9c9057d165d61be064d5eb023f8c3bfe12938"
L2_HELD_OUT_STAGE_COMMIT = "42b51524dbfafd3df61bbf6f835f170591d2a846"
L2_HELD_OUT_STAGE_TREE = "164bd96e5ec76a7a56d9b70b68bb744a949efc3e"
L2_HELD_OUT_AUTHORITY_COMMIT = "a2a24e0b02a240333750cd6aecf24366bf0fa9fd"
L2_HELD_OUT_AUTHORITY_TREE = "bbb8165e29f3bb828a16fef5ee8fdcc352f261f8"
L2_HELD_OUT_FAILURE_COMMIT = "a2c12c2af6d23564030b9f8213c4e002f971e7f5"
L2_HELD_OUT_FAILURE_TREE = "1943166b741f7464c9558dc3acc062d8a7430375"

# Installed with the finalized recursive dependency closure.
EXPECTED_SOURCE_COUNT = 91
EXPECTED_SOURCE_PATH_SHA256 = (
    "sha256:348c65a448016b769cc13f3c23336a295a03990ef39e40a8418650a2d9667f67"
)

PASS_MARKER = "QSDK_R10E_ZERO_WORLD_IMPLEMENTATION_PASS "
DESIGN_MARKER = "QSDK_R10E_OBSERVER_MINIMIZED_SUCCESSOR_DESIGN_PASS "
DEPENDENCY_MARKER = "QSDK_R10E_DEPENDENCY_CLOSURE_PASS "
MATERIALIZER_MARKER = "QSDK_R10E_AUTHORITY_MATERIALIZER_SELF_TEST_PASS "
PHYSICAL_CLOSURE_MARKER = "QSDK_R10E_PHYSICAL_CLOSURE_SELF_TEST_PASS "
SOURCE_MARKER = "QSDK_R10E_OBSERVER_MINIMIZED_UPRIGHT_PUSH_RECOVERY_SOURCE_ZERO_WORLD "
CONTRACT_MARKER = "QSDK_R10E_WORKER_CONTRACT_ZERO_WORLD "
PREFLIGHT_MARKER = "QSDK_R10E_WORKER_ENTRYPOINT_ZERO_WORLD "
CELL_MARKER = "QSDK_R10E_PHYSICAL_CELL "
SUPERVISOR_MARKER = "QSDK_R10E_SUPERVISOR_ZERO_WORLD_PASS "
DEFERRED_TRACE_MARKER = "QSDK_R10E_DEFERRED_RECOVERY_TRACE_ZERO_WORLD_PASS"
SCALAR_RECEIPT_MARKER = "QSDK_R10E_NATIVE_IMPULSE_SCALAR_RECEIPT_ZERO_WORLD_PASS"
ATTEMPT_PATH_ENV = "SPORESPORE_QSDK_R10E_ATTEMPT"
ATTEMPT_TOKEN_ENV = "SPORESPORE_QSDK_R10E_TOKEN"
QUALIFICATION_LOCK_ENV = "SPORESPORE_QSDK_R10E_QUALIFICATION_LOCK_HELD"

ZERO_COUNTERS = (
    "model_construction_count",
    "world_attempt_count",
    "world_build_count",
    "native_readback_count",
    "solver_step_count",
)
ROLE_SPECS: dict[str, dict[str, Any]] = {
    "development_route_ghost": {
        "question_class": "development",
        "seeds": [40002],
        "ordered_cell_ids": ["baseline_s40002", "push_s40002"],
    },
    "held_out_finite_decision": {
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
    },
}

GDSCRIPT_PATHS = (
    ROOT / "scripts/lab/gait/qsdk_r10e_observer_minimized_upright_push_recovery.gd",
    ROOT / "sdk/adapters/godot/gdscript/deferred_recovery_trace_v1.gd",
    ROOT
    / "sdk/adapters/godot/gdscript/qsdk_r10e_native_impulse_scalar_receipt_validation_v1.gd",
    ROOT
    / "sdk/adapters/godot/gdscript/qsdk_r10e_native_impulse_scalar_receipt_validation_v2.gd",
    ROOT / "tests/test_sdk_qsdk_r10e_deferred_recovery_trace_zero_world.gd",
    ROOT
    / "tests/test_sdk_qsdk_r10e_native_impulse_scalar_receipt_validation_zero_world.gd",
    ROOT
    / "tests/test_sdk_qsdk_r10e_observer_minimized_upright_push_recovery_source.gd",
    ROOT
    / "tests/test_sdk_qsdk_r10e_observer_minimized_upright_push_recovery_worker.gd",
)
PYTHON_PATHS = (
    DESIGN_AUDIT_PATH,
    DEPENDENCY_AUDIT_PATH,
    MATERIALIZER_PATH,
    PHYSICAL_CLOSURE_PATH,
    ROOT / "sdk/conformance/qsdk_r10e_zero_world_implementation.py",
    ROOT / "tests/test_qsdk_r10e_deferred_recovery_trace_source.py",
    ROOT / "tests/test_qsdk_r10e_worker_source.py",
)
BLACK_PATHS = tuple(path for path in PYTHON_PATHS if path != DESIGN_AUDIT_PATH)
POWERSHELL_PATHS = (SUPERVISOR_PATH, QUALIFICATION_PATH)


class AuditFailure(RuntimeError):
    """The R10E implementation is not an exact zero-world authority."""


def require(condition: bool, code: str) -> None:
    if not condition:
        raise AuditFailure(code)


def sha256_bytes(value: bytes) -> str:
    return "sha256:" + hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def is_prefixed_sha256(value: Any) -> bool:
    return (
        isinstance(value, str)
        and re.fullmatch(r"sha256:[0-9a-f]{64}", value) is not None
    )


def read_json(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise AuditFailure(f"{label}_UNREADABLE:{exc}") from exc
    require(isinstance(value, dict), f"{label}_NOT_OBJECT")
    return value


def run_process(
    arguments: Iterable[str | Path],
    *,
    timeout_seconds: int,
    environment: Mapping[str, str] | None = None,
    cwd: Path = ROOT,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        tuple(str(value) for value in arguments),
        cwd=cwd,
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=timeout_seconds,
        env=None if environment is None else dict(environment),
    )


def parse_marker(stdout: str, marker: str, label: str) -> dict[str, Any]:
    matches = [
        line[len(marker) :] for line in stdout.splitlines() if line.startswith(marker)
    ]
    require(len(matches) == 1, f"{label}_MARKER_COUNT")
    try:
        value = json.loads(matches[0])
    except json.JSONDecodeError as exc:
        raise AuditFailure(f"{label}_MARKER_JSON:{exc}") from exc
    require(isinstance(value, dict), f"{label}_MARKER_NOT_OBJECT")
    return value


def require_zero_world(
    receipt: Mapping[str, Any], label: str, *, require_ok: bool = True
) -> None:
    if require_ok:
        require(receipt.get("ok") is True, f"{label}_NOT_OK")
    for counter in ZERO_COUNTERS:
        require(receipt.get(counter) == 0, f"{label}_{counter.upper()}")
    require(
        receipt.get("scene_tree_insertion_count", 0) == 0,
        f"{label}_SCENE_TREE_INSERTION_COUNT",
    )
    require(receipt.get("physics_state_modified") is False, f"{label}_PHYSICS_STATE")
    require(
        receipt.get("physical_acceptance_authority") is False,
        f"{label}_PHYSICAL_ACCEPTANCE",
    )
    require(
        receipt.get("release_authority", False) is False, f"{label}_RELEASE_AUTHORITY"
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
        "SOURCE_BOUNDARY_INSPECTION",
    )
    require(
        Path(results["top"].stdout.strip()).resolve() == ROOT.resolve(),
        "CANONICAL_ROOT",
    )
    require(results["remote"].stdout.strip() == EXPECTED_REMOTE, "CANONICAL_REMOTE")
    head = results["head"].stdout.strip()
    origin = results["origin"].stdout.strip()
    branch = results["branch"].stdout.strip()
    clean = not results["status"].stdout.strip()
    live_commit = ""
    live_equal = False
    if official_qualification:
        live = run_process(
            ("git", "ls-remote", "origin", "refs/heads/main"), timeout_seconds=60
        )
        records = [line.split() for line in live.stdout.splitlines() if line.strip()]
        require(
            live.returncode == 0
            and len(records) == 1
            and len(records[0]) == 2
            and records[0][1] == "refs/heads/main",
            "LIVE_MAIN_QUERY",
        )
        live_commit = records[0][0]
        live_equal = live_commit == head
        require(
            branch == "main" and clean and head == origin and live_equal,
            "OFFICIAL_QUALIFICATION_REQUIRES_CLEAN_LIVE_MAIN",
        )
    return {
        "source_commit": head,
        "source_tree": results["tree"].stdout.strip(),
        "source_branch": branch,
        "source_clean": clean,
        "source_origin_main_equal": head == origin,
        "source_live_main_equal": live_equal,
        "source_live_main_commit": live_commit,
        "official_qualification": official_qualification,
    }


def validate_bound_json(
    path: Path, byte_length: int, digest: str, label: str
) -> dict[str, Any]:
    require(path.is_file(), f"{label}_MISSING")
    require(path.stat().st_size == byte_length, f"{label}_BYTE_LENGTH")
    require(sha256_file(path) == digest, f"{label}_SHA256")
    return read_json(path, label)


def git_text(arguments: Iterable[str], label: str) -> str:
    result = run_process(("git", *arguments), timeout_seconds=60)
    require(
        result.returncode == 0,
        f"{label}_GIT_PROCESS:{(result.stdout + result.stderr)[-3000:]}",
    )
    return result.stdout.strip()


def git_bytes(arguments: Iterable[str], label: str) -> bytes:
    result = subprocess.run(
        ("git", *tuple(arguments)),
        cwd=ROOT,
        check=False,
        capture_output=True,
        timeout=60,
    )
    require(
        result.returncode == 0,
        f"{label}_GIT_PROCESS:{result.stderr.decode('utf-8', errors='replace')[-3000:]}",
    )
    return result.stdout


def powershell_ast_scan(pwsh: str, paths: Iterable[Path]) -> list[dict[str, Any]]:
    resolved_paths = [str(path.resolve()) for path in paths]
    environment = dict(os.environ)
    environment["SPORESPORE_R10E_AST_PATHS"] = json.dumps(resolved_paths)
    script = "\n".join(
        (
            "$ErrorActionPreference = 'Stop'",
            "$paths = @($env:SPORESPORE_R10E_AST_PATHS | ConvertFrom-Json)",
            "$records = @()",
            "foreach ($path in $paths) {",
            "  $tokens = $null; $errors = $null",
            "  $ast = [System.Management.Automation.Language.Parser]::ParseFile("
            "$path, [ref]$tokens, [ref]$errors)",
            "  $ifCommands = @($ast.FindAll({ param($node) "
            "$node -is [System.Management.Automation.Language.CommandAst] -and "
            "$node.GetCommandName() -ceq 'if' }, $true))",
            "  $records += [ordered]@{",
            "    path = [IO.Path]::GetFullPath($path).Replace('\\', '/')",
            "    parse_error_count = @($errors).Count",
            "    parse_errors = @($errors | ForEach-Object { $_.Message })",
            "    command_ast_named_if_count = $ifCommands.Count",
            "    command_ast_named_if_start_lines = @($ifCommands | "
            "ForEach-Object { $_.Extent.StartLineNumber })",
            "  }",
            "}",
            "Write-Output ('QSDK_R10E_POWERSHELL_AST_SCAN ' + "
            "($records | ConvertTo-Json -Compress -Depth 6 -AsArray))",
        )
    )
    result = run_process(
        (pwsh, "-NoLogo", "-NoProfile", "-Command", script),
        timeout_seconds=120,
        environment=environment,
    )
    require(
        result.returncode == 0,
        f"R10E_POWERSHELL_AST_SCAN:{(result.stdout + result.stderr)[-3000:]}",
    )
    marker = "QSDK_R10E_POWERSHELL_AST_SCAN "
    matches = [
        line[len(marker) :]
        for line in result.stdout.splitlines()
        if line.startswith(marker)
    ]
    require(len(matches) == 1, "R10E_POWERSHELL_AST_SCAN_MARKER_COUNT")
    try:
        records = json.loads(matches[0])
    except json.JSONDecodeError as exc:
        raise AuditFailure(f"R10E_POWERSHELL_AST_SCAN_JSON:{exc}") from exc
    require(
        isinstance(records, list)
        and len(records) == len(resolved_paths)
        and all(isinstance(record, dict) for record in records),
        "R10E_POWERSHELL_AST_SCAN_RECORDS",
    )
    return records


def validate_predecessor_qualification_failure() -> dict[str, Any]:
    closure = validate_bound_json(
        QUALIFICATION_FAILURE_CLOSURE_PATH,
        EXPECTED_QUALIFICATION_FAILURE_CLOSURE_BYTES,
        EXPECTED_QUALIFICATION_FAILURE_CLOSURE_SHA256,
        "R10E_QUALIFICATION_FAILURE_CLOSURE",
    )
    require(
        closure.get("schema_version")
        == "sporespore_qsdk_r10e_zero_world_qualification_failure_closure_v1"
        and closure.get("status")
        == "closed_failed_official_zero_world_qualification_identity_consumed_pre_physics"
        and closure.get("gate_id") == "QSDK-R10E"
        and closure.get("repair_id") == "QSDK-R10E-L1"
        and closure.get("campaign_role") == "development_route_ghost"
        and closure.get("question_class") == "development"
        and closure.get("ledger_scope")
        == {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "immutable_zero_world_qualification_failure_closure",
            "question_class": "development",
        },
        "R10E_QUALIFICATION_FAILURE_HEADER",
    )
    source = closure.get("source")
    retained = closure.get("retained_evidence")
    diagnosis = closure.get("diagnosis")
    boundary = closure.get("execution_boundary")
    successor = closure.get("successor_policy")
    claim = closure.get("claim_boundary")
    require(
        all(
            isinstance(value, dict)
            for value in (source, retained, diagnosis, boundary, successor, claim)
        ),
        "R10E_QUALIFICATION_FAILURE_STRUCTURE",
    )
    require(
        source.get("source_commit") == FAILED_QUALIFICATION_SOURCE_COMMIT
        and source.get("source_tree_git_oid") == FAILED_QUALIFICATION_SOURCE_TREE
        and source.get("qualified_source_path_count") == 84
        and source.get("qualified_source_path_sha256")
        == "sha256:967f4fe5f4c7f5a8cdc39732aa34d87467b492deeb1f9ea67d21d75bba200d80"
        and source.get("local_origin_live_equal_before_invocation") is True
        and source.get("worktree_clean_before_invocation") is True,
        "R10E_QUALIFICATION_FAILURE_SOURCE",
    )
    tree = run_process(
        ("git", "rev-parse", f"{FAILED_QUALIFICATION_SOURCE_COMMIT}^{{tree}}"),
        timeout_seconds=30,
    )
    require(
        tree.returncode == 0
        and tree.stdout.strip() == FAILED_QUALIFICATION_SOURCE_TREE,
        "R10E_QUALIFICATION_FAILURE_SOURCE_TREE",
    )

    expected_files = [
        {
            "path": "qualification_attempt.json",
            "byte_length": 3_083,
            "raw_sha256": "sha256:49be906d0f38f51b5558c2f54383776f3dc434d8f9b115ed82ba15b8648fec60",
        },
        {
            "path": "qualification_failure.json",
            "byte_length": 907,
            "raw_sha256": "sha256:23283482289c63e2dd71fbaadb1b1ac6976decdf14d5c36753e0cafa2bae692f",
        },
        {
            "path": "qualification_stderr.log",
            "byte_length": 1_863,
            "raw_sha256": "sha256:24a3d5352b43b7d5b52682adff5effb96e1bb674cf69d1d4e476e13d6cc0cad2",
        },
        {
            "path": "qualification_stdout.log",
            "byte_length": 0,
            "raw_sha256": "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
        },
    ]
    require(
        retained.get("files") == expected_files
        and retained.get("file_count") == 4
        and retained.get("total_byte_length") == 5_853
        and retained.get("canonical_manifest_byte_length") == 569
        and retained.get("canonical_manifest_sha256")
        == "sha256:fda2b3fba88474418ae7ed888af0b1ed5b55723a7608eb931afbb820ac6d0aeb",
        "R10E_QUALIFICATION_FAILURE_RETAINED_MANIFEST",
    )
    evidence_root = Path(str(retained.get("root", ""))).resolve()
    require(
        evidence_root
        == Path(
            r"C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
            r"\qsdk-r10e-development-route-ghost-zero-world-qualification-831e5703f682"
        ).resolve()
        and evidence_root.is_dir(),
        "R10E_QUALIFICATION_FAILURE_EVIDENCE_ROOT",
    )
    require(
        sorted(path.name for path in evidence_root.iterdir() if path.is_file())
        == [entry["path"] for entry in expected_files],
        "R10E_QUALIFICATION_FAILURE_FILE_SET",
    )
    observed_files: list[dict[str, Any]] = []
    for expected in expected_files:
        path = evidence_root / expected["path"]
        require(path.is_file(), f"R10E_QUALIFICATION_FAILURE_FILE:{expected['path']}")
        observed_files.append(
            {
                "path": expected["path"],
                "byte_length": path.stat().st_size,
                "raw_sha256": sha256_file(path),
            }
        )
    require(
        observed_files == expected_files, "R10E_QUALIFICATION_FAILURE_FILE_BINDINGS"
    )
    canonical_manifest = json.dumps(
        observed_files, separators=(",", ":"), ensure_ascii=True
    ).encode("utf-8")
    require(
        len(canonical_manifest) == 569
        and sha256_bytes(canonical_manifest)
        == "sha256:fda2b3fba88474418ae7ed888af0b1ed5b55723a7608eb931afbb820ac6d0aeb",
        "R10E_QUALIFICATION_FAILURE_CANONICAL_MANIFEST",
    )

    attempt = read_json(
        evidence_root / "qualification_attempt.json", "R10E_FAILURE_ATTEMPT"
    )
    failure = read_json(
        evidence_root / "qualification_failure.json", "R10E_FAILURE_RESULT"
    )
    stderr = (evidence_root / "qualification_stderr.log").read_text(encoding="utf-8")
    require(
        (evidence_root / "qualification_stdout.log").read_bytes() == b"",
        "R10E_FAILURE_STDOUT",
    )
    require(
        attempt.get("source_commit") == FAILED_QUALIFICATION_SOURCE_COMMIT
        and attempt.get("same_identity_rerun_permitted") is False
        and failure.get("status") == "closed_failed_identity_consumed"
        and failure.get("source_commit") == FAILED_QUALIFICATION_SOURCE_COMMIT
        and failure.get("failure_code") == "IMPLEMENTATION_AUDIT_FAILED_OR_TIMED_OUT"
        and failure.get("same_identity_rerun_permitted") is False,
        "R10E_QUALIFICATION_FAILURE_RECEIPTS",
    )
    for field in (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "native_readback_count",
        "solver_step_count",
    ):
        require(
            attempt.get(field) == 0 and failure.get(field) == 0, f"R10E_FAILURE_{field}"
        )
    expected_diagnostics = (
        'Cannot infer the type of "common_execution_integrity" variable',
        'Cannot infer the type of "exact" variable',
        'Cannot infer the type of "exact_attempt" variable',
    )
    require(
        all(stderr.count(value) == 1 for value in expected_diagnostics),
        "R10E_QUALIFICATION_FAILURE_DIAGNOSTICS",
    )
    require(
        diagnosis.get("classification")
        == "implementation_invalid_zero_world_parser_failure"
        and diagnosis.get("failure_count") == 3
        and diagnosis.get("physical_or_locomotion_interpretation_permitted") is False
        and boundary.get("qualification_identity_consumed") is True
        and boundary.get("official_zero_world_qualification_passed") is False
        and boundary.get("world_build_count") == 0
        and boundary.get("solver_step_count") == 0
        and successor.get("repeat_failed_qualification") is False
        and successor.get("new_clean_pushed_source_required") is True
        and successor.get("controller_changed") is False
        and successor.get("threshold_changed") is False
        and claim.get("external_push_recovery_claimed") is False
        and claim.get("physical_acceptance_authority") is False
        and claim.get("release_authority") is False,
        "R10E_QUALIFICATION_FAILURE_BOUNDARY",
    )
    predecessor_recovery = run_process(
        (
            "git",
            "show",
            f"{FAILED_QUALIFICATION_SOURCE_COMMIT}:scripts/lab/gait/"
            "qsdk_r10e_observer_minimized_upright_push_recovery.gd",
        ),
        timeout_seconds=30,
    )
    predecessor_worker = run_process(
        (
            "git",
            "show",
            f"{FAILED_QUALIFICATION_SOURCE_COMMIT}:tests/"
            "test_sdk_qsdk_r10e_observer_minimized_upright_push_recovery_worker.gd",
        ),
        timeout_seconds=30,
    )
    require(
        predecessor_recovery.returncode == 0
        and predecessor_worker.returncode == 0
        and "var common_execution_integrity := (" in predecessor_recovery.stdout
        and "var exact := (" in predecessor_worker.stdout
        and "var exact_attempt := (" in predecessor_worker.stdout,
        "R10E_QUALIFICATION_FAILURE_PREDECESSOR_SOURCE",
    )
    require(
        "var common_execution_integrity: bool = ("
        in (
            ROOT
            / "scripts/lab/gait/qsdk_r10e_observer_minimized_upright_push_recovery.gd"
        ).read_text(encoding="utf-8")
        and "var exact: bool = ("
        in (
            ROOT
            / "tests/test_sdk_qsdk_r10e_observer_minimized_upright_push_recovery_worker.gd"
        ).read_text(encoding="utf-8")
        and "var exact_attempt: bool = ("
        in (
            ROOT
            / "tests/test_sdk_qsdk_r10e_observer_minimized_upright_push_recovery_worker.gd"
        ).read_text(encoding="utf-8"),
        "R10E_L1_TYPED_BOOLEAN_REPAIR",
    )
    return {
        "source_commit": FAILED_QUALIFICATION_SOURCE_COMMIT,
        "retained_file_count": len(observed_files),
        "retained_total_byte_length": sum(
            int(entry["byte_length"]) for entry in observed_files
        ),
        "parser_failure_count": len(expected_diagnostics),
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
    }


def validate_predecessor_physical_supervisor_refusal(
    pwsh: str,
) -> dict[str, Any]:
    closure = validate_bound_json(
        SUPERVISOR_REFUSAL_CLOSURE_PATH,
        EXPECTED_SUPERVISOR_REFUSAL_CLOSURE_BYTES,
        EXPECTED_SUPERVISOR_REFUSAL_CLOSURE_SHA256,
        "R10E_PHYSICAL_SUPERVISOR_REFUSAL_CLOSURE",
    )
    require(
        closure.get("schema_version")
        == "sporespore_qsdk_r10e_physical_supervisor_refusal_v1"
        and closure.get("status")
        == "closed_infrastructure_invalid_pre_physics_output_identity_unconsumed"
        and closure.get("gate_id") == "QSDK-R10E"
        and closure.get("repair_id") == "QSDK-R10E-L2"
        and closure.get("campaign_id")
        == "QSDK-R10E-OBSERVER-MINIMIZED-UPRIGHT-PUSH-RECOVERY-ROUTE-GHOST"
        and closure.get("campaign_role") == "development_route_ghost"
        and closure.get("question_class") == "development"
        and closure.get("ledger_scope")
        == {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "closed_pre_physics_supervisor_refusal",
            "question_class": "development",
        },
        "R10E_PHYSICAL_SUPERVISOR_REFUSAL_HEADER",
    )
    invocation = closure.get("invocation")
    source = closure.get("source")
    bindings = closure.get("authority_bindings")
    diagnosis = closure.get("diagnosis")
    boundary = closure.get("execution_boundary")
    successor = closure.get("successor_policy")
    claim = closure.get("claim_boundary")
    require(
        all(
            isinstance(value, dict)
            for value in (
                invocation,
                source,
                bindings,
                diagnosis,
                boundary,
                successor,
                claim,
            )
        ),
        "R10E_PHYSICAL_SUPERVISOR_REFUSAL_STRUCTURE",
    )
    require(
        invocation.get("mode") == "Physical"
        and invocation.get("command")
        == "pwsh -NoProfile -File sdk/run_qsdk_r10e_observer_minimized_upright_push_recovery.ps1 -Mode Physical -CampaignRole development_route_ghost -AuthorizePhysical"
        and invocation.get("process_exit_code") == 1
        and invocation.get("terminal_error_first_line")
        == "The term 'if' is not recognized as a name of a cmdlet, function, script file, or executable program."
        and invocation.get("same_authority_graph_rerun_permitted") is False,
        "R10E_PHYSICAL_SUPERVISOR_REFUSAL_INVOCATION",
    )
    require(
        source.get("source_commit") == REFUSED_PHYSICAL_SOURCE_COMMIT
        and source.get("source_tree_git_oid") == REFUSED_PHYSICAL_SOURCE_TREE
        and source.get("qualification_commit") == REFUSED_PHYSICAL_STAGE_COMMIT
        and source.get("qualification_tree_git_oid") == REFUSED_PHYSICAL_STAGE_TREE
        and source.get("authorization_commit") == REFUSED_PHYSICAL_AUTHORITY_COMMIT
        and source.get("authorization_tree_git_oid") == REFUSED_PHYSICAL_AUTHORITY_TREE
        and source.get("branch") == "main"
        and source.get("remote") == EXPECTED_REMOTE
        and source.get("local_origin_live_equal_before_invocation") is True
        and source.get("worktree_clean_before_invocation") is True,
        "R10E_PHYSICAL_SUPERVISOR_REFUSAL_SOURCE",
    )
    for commit, expected_tree, label in (
        (REFUSED_PHYSICAL_SOURCE_COMMIT, REFUSED_PHYSICAL_SOURCE_TREE, "SOURCE"),
        (REFUSED_PHYSICAL_STAGE_COMMIT, REFUSED_PHYSICAL_STAGE_TREE, "STAGE"),
        (
            REFUSED_PHYSICAL_AUTHORITY_COMMIT,
            REFUSED_PHYSICAL_AUTHORITY_TREE,
            "AUTHORITY",
        ),
    ):
        require(
            git_text(("rev-parse", f"{commit}^{{tree}}"), f"R10E_REFUSAL_{label}_TREE")
            == expected_tree,
            f"R10E_PHYSICAL_SUPERVISOR_REFUSAL_{label}_TREE",
        )
    require(
        git_text(
            ("rev-parse", f"{REFUSED_PHYSICAL_STAGE_COMMIT}^"),
            "R10E_REFUSAL_STAGE_PARENT",
        )
        == REFUSED_PHYSICAL_SOURCE_COMMIT
        and git_text(
            ("rev-parse", f"{REFUSED_PHYSICAL_AUTHORITY_COMMIT}^"),
            "R10E_REFUSAL_AUTHORITY_PARENT",
        )
        == REFUSED_PHYSICAL_STAGE_COMMIT,
        "R10E_PHYSICAL_SUPERVISOR_REFUSAL_PARENT_CHAIN",
    )
    stage_relative = (
        "sdk/qsdk_r10e_development_route_ghost_zero_world_qualification_closure_v1.json"
    )
    authority_relative = (
        "sdk/qsdk_r10e_development_route_ghost_execution_authority_v1.json"
    )
    require(
        git_text(
            (
                "diff-tree",
                "--no-commit-id",
                "--name-only",
                "--no-renames",
                "-r",
                REFUSED_PHYSICAL_STAGE_COMMIT,
            ),
            "R10E_REFUSAL_STAGE_PATH",
        ).splitlines()
        == [stage_relative]
        and git_text(
            (
                "diff-tree",
                "--no-commit-id",
                "--name-only",
                "--no-renames",
                "-r",
                REFUSED_PHYSICAL_AUTHORITY_COMMIT,
            ),
            "R10E_REFUSAL_AUTHORITY_PATH",
        ).splitlines()
        == [authority_relative],
        "R10E_PHYSICAL_SUPERVISOR_REFUSAL_COMMIT_PATHS",
    )

    expected_stage_binding = {
        "path": stage_relative,
        "byte_length": 3_934,
        "raw_sha256": "sha256:485e4f198c0cdeb3d86eb53251f858ca6753fc601590f7b94721aff17ac5ceb3",
        "git_blob_oid": "8699d019c12f210eca321ae70b36a4b7f63fa59b",
    }
    expected_authority_binding = {
        "path": authority_relative,
        "byte_length": 2_067,
        "raw_sha256": "sha256:be404df1a74445032dbadcd3624534fe66d524a82d7b4dcd25cb6516497d1131",
        "git_blob_oid": "b47d0a79638210268b1c256d067f96f6a6544ba0",
    }
    expected_completion_binding = {
        "path": "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r10e-development-route-ghost-zero-world-qualification-0dbd259477d0/qualification_completion.json",
        "byte_length": 2_731,
        "raw_sha256": "sha256:a05693864ac28ce6cc11addf093a10de8e9986b194650a73b0a1d52f51ef7ba9",
    }
    require(
        bindings.get("stage_freeze") == expected_stage_binding
        and bindings.get("execution_authority") == expected_authority_binding
        and bindings.get("qualification_completion") == expected_completion_binding
        and bindings.get("qualified_source_path_count") == 85
        and bindings.get("qualified_source_path_sha256")
        == "sha256:fa7dd62aa503db13c15818a5a66df1fbbf94351348da7a047de950cc99888a1d"
        and bindings.get("authorized_output_root")
        == "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r10e-development-route-ghost-physical-0dbd259477d0"
        and bindings.get("authorized_output_root_absent_after_refusal") is True,
        "R10E_PHYSICAL_SUPERVISOR_REFUSAL_BINDINGS",
    )
    for binding, commit, label in (
        (expected_stage_binding, REFUSED_PHYSICAL_STAGE_COMMIT, "STAGE"),
        (
            expected_authority_binding,
            REFUSED_PHYSICAL_AUTHORITY_COMMIT,
            "AUTHORITY",
        ),
    ):
        raw = git_bytes(
            ("show", f"{commit}:{binding['path']}"), f"R10E_REFUSAL_{label}_BLOB"
        )
        require(
            len(raw) == binding["byte_length"]
            and sha256_bytes(raw) == binding["raw_sha256"]
            and git_text(
                ("rev-parse", f"{commit}:{binding['path']}"),
                f"R10E_REFUSAL_{label}_OID",
            )
            == binding["git_blob_oid"],
            f"R10E_PHYSICAL_SUPERVISOR_REFUSAL_{label}_BINDING",
        )
    completion_path = Path(expected_completion_binding["path"])
    require(
        completion_path.is_file()
        and not completion_path.is_symlink()
        and completion_path.stat().st_size == expected_completion_binding["byte_length"]
        and sha256_file(completion_path) == expected_completion_binding["raw_sha256"],
        "R10E_PHYSICAL_SUPERVISOR_REFUSAL_QUALIFICATION_BINDING",
    )
    old_output_root = Path(str(bindings["authorized_output_root"])).resolve()
    require(
        not old_output_root.exists(),
        "R10E_PHYSICAL_SUPERVISOR_REFUSAL_OUTPUT_IDENTITY_CONSUMED",
    )

    require(
        diagnosis.get("classification")
        == "infrastructure_invalid_supervisor_runtime_expression"
        and diagnosis.get("failure_predicate")
        == "physical_closure_output_path_selection"
        and diagnosis.get("powershell_parse_error_count") == 0
        and diagnosis.get("command_ast_named_if_count") == 1
        and diagnosis.get("command_ast_start_line") == 1441
        and diagnosis.get("root_cause_expression_start_line") == 1440
        and diagnosis.get("authority_check_passed_before_invocation") is True
        and diagnosis.get("stage_freeze_sha256_matched") is True
        and diagnosis.get("execution_authority_sha256_matched") is True
        and diagnosis.get("runtime_identity_sha256_matched") is True
        and diagnosis.get("sole_observed_runtime_expression_failure") is True,
        "R10E_PHYSICAL_SUPERVISOR_REFUSAL_DIAGNOSIS",
    )
    expected_boundary = {
        "physical_supervisor_invocation_count": 1,
        "operation_lock_acquisition_count": 1,
        "operation_lock_explicit_release_count": 0,
        "post_process_lock_probe_created_new": True,
        "post_process_lock_probe_abandoned_owner_recovered": False,
        "durable_evidence_directory_created": False,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "scene_tree_insertion_count": 0,
        "native_readback_count": 0,
        "solver_step_count": 0,
        "locomotion_outcome_exposure_count": 0,
        "physics_state_modified": False,
        "physical_attempt_identity_consumed": False,
    }
    require(
        boundary == expected_boundary,
        "R10E_PHYSICAL_SUPERVISOR_REFUSAL_EXECUTION_BOUNDARY",
    )
    require(
        successor.get("repeat_failed_supervisor_invocation") is False
        and successor.get("old_stage_freeze_reusable") is False
        and successor.get("old_execution_authority_reusable") is False
        and successor.get("new_clean_pushed_source_required") is True
        and successor.get("new_official_zero_world_qualification_required") is True
        and successor.get("new_stage_freeze_required") is True
        and successor.get("new_execution_authority_required") is True
        and successor.get("controller_changed") is False
        and successor.get("fixture_changed") is False
        and successor.get("challenge_changed") is False
        and successor.get("impulse_changed") is False
        and successor.get("threshold_changed") is False
        and successor.get("population_changed") is False
        and successor.get("physical_canary_added") is False,
        "R10E_PHYSICAL_SUPERVISOR_REFUSAL_SUCCESSOR",
    )
    expected_claim_keys = {
        "production_route_construct_step_finalize_retain_pair_evaluate_qualified",
        "bounded_upright_push_recovery_claimed",
        "locomotion_negative_claimed",
        "fall_recovery_claimed",
        "prone_to_standing_claimed",
        "force_aware_recovery_claimed",
        "other_engine_claimed",
        "cross_engine_equivalence_claimed",
        "physical_acceptance_authority",
        "release_authority",
    }
    require(
        set(claim) == expected_claim_keys
        and all(value is False for value in claim.values()),
        "R10E_PHYSICAL_SUPERVISOR_REFUSAL_CLAIM_BOUNDARY",
    )

    old_supervisor = git_bytes(
        (
            "show",
            f"{REFUSED_PHYSICAL_SOURCE_COMMIT}:sdk/"
            "run_qsdk_r10e_observer_minimized_upright_push_recovery.ps1",
        ),
        "R10E_REFUSAL_OLD_SUPERVISOR",
    )
    with tempfile.TemporaryDirectory(prefix="sporespore-r10e-refusal-") as raw:
        old_path = Path(raw) / "refused_supervisor.ps1"
        old_path.write_bytes(old_supervisor)
        old_scan = powershell_ast_scan(pwsh, (old_path,))[0]
    require(
        old_scan.get("parse_error_count") == 0
        and old_scan.get("command_ast_named_if_count") == 1
        and old_scan.get("command_ast_named_if_start_lines") == [1441],
        "R10E_PHYSICAL_SUPERVISOR_REFUSAL_OLD_AST",
    )
    current_scan = powershell_ast_scan(pwsh, (SUPERVISOR_PATH,))[0]
    supervisor_text = SUPERVISOR_PATH.read_text(encoding="utf-8")
    lock_acquire = supervisor_text.index(
        "$lock = Enter-SporeSporeLocomotionOperationLock -Role $lockRole"
    )
    outer_try = supervisor_text.index("    try {", lock_acquire)
    lock_release = supervisor_text.index(
        "Exit-SporeSporeLocomotionOperationLock -Receipt $lock", outer_try
    )
    require(
        current_scan.get("parse_error_count") == 0
        and current_scan.get("command_ast_named_if_count") == 0
        and "physical_closure_path = (" in supervisor_text
        and "qsdk_r10e_development_route_ghost_physical_closure_v2.json"
        in supervisor_text
        and "qsdk_r10e_held_out_finite_decision_physical_closure_v3.json"
        in supervisor_text
        and 'repair_id = "QSDK-R10E-L3"' in supervisor_text
        and "function Test-EmptyPopulationTerminalization" in supervisor_text
        and supervisor_text.count("[AllowEmptyCollection()]") >= 2
        and "$closurePath = Join-Path $script:RepoRoot (" not in supervisor_text
        and lock_acquire < outer_try < lock_release,
        "R10E_PHYSICAL_SUPERVISOR_REFUSAL_FORWARD_REPAIRS",
    )
    return {
        "source_commit": REFUSED_PHYSICAL_SOURCE_COMMIT,
        "stage_commit": REFUSED_PHYSICAL_STAGE_COMMIT,
        "authority_commit": REFUSED_PHYSICAL_AUTHORITY_COMMIT,
        "physical_supervisor_invocation_count": 1,
        "old_command_ast_named_if_count": 1,
        "current_command_ast_named_if_count": 0,
        "physical_attempt_identity_consumed": False,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
    }


def validate_l2_held_out_failure() -> dict[str, Any]:
    closure = validate_bound_json(
        L2_HELD_OUT_FAILURE_CLOSURE_PATH,
        EXPECTED_L2_HELD_OUT_FAILURE_CLOSURE_BYTES,
        EXPECTED_L2_HELD_OUT_FAILURE_CLOSURE_SHA256,
        "R10E_L2_HELD_OUT_FAILURE_CLOSURE",
    )
    require(
        closure.get("schema_version")
        == "sporespore_qsdk_r10e_l2_held_out_finite_decision_physical_failure_closure_v1"
        and closure.get("status")
        == "closed_consumed_invalid_or_incomplete_no_finite_decision"
        and closure.get("gate_id") == "QSDK-R10E"
        and closure.get("repair_id") == "QSDK-R10E-L2"
        and closure.get("campaign_id")
        == "QSDK-R10E-OBSERVER-MINIMIZED-UPRIGHT-PUSH-RECOVERY-VALIDATION"
        and closure.get("campaign_role") == "held_out_finite_decision"
        and closure.get("question_class") == "finite decision"
        and closure.get("ledger_scope")
        == {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "closed_consumed_incomplete_physical_evidence",
            "question_class": "finite decision",
        },
        "R10E_L2_HELD_OUT_FAILURE_HEADER",
    )
    invocation = closure.get("invocation")
    source = closure.get("source")
    bindings = closure.get("authority_bindings")
    source_bindings = closure.get("execution_source_bindings")
    retained = closure.get("retained_evidence")
    cells = closure.get("observed_cells")
    numeric = closure.get("numeric_diagnosis")
    terminalization = closure.get("terminalization_diagnosis")
    outcome = closure.get("outcome")
    successor = closure.get("successor_policy")
    decision = closure.get("decision")
    claim = closure.get("claim_boundary")
    process = closure.get("closure_process")
    require(
        all(
            isinstance(value, dict)
            for value in (
                invocation,
                source,
                bindings,
                retained,
                numeric,
                terminalization,
                outcome,
                successor,
                decision,
                claim,
                process,
            )
        )
        and isinstance(source_bindings, list)
        and isinstance(cells, list),
        "R10E_L2_HELD_OUT_FAILURE_STRUCTURE",
    )
    require(
        invocation.get("mode") == "Physical"
        and invocation.get("process_exit_code") == 1
        and invocation.get("terminal_error")
        == "Cannot bind argument to parameter 'Pairs' because it is an empty array."
        and invocation.get("same_authority_graph_rerun_permitted") is False,
        "R10E_L2_HELD_OUT_FAILURE_INVOCATION",
    )
    require(
        source
        == {
            "source_commit": L2_HELD_OUT_SOURCE_COMMIT,
            "source_tree_git_oid": L2_HELD_OUT_SOURCE_TREE,
            "qualification_commit": L2_HELD_OUT_STAGE_COMMIT,
            "qualification_tree_git_oid": L2_HELD_OUT_STAGE_TREE,
            "authorization_commit": L2_HELD_OUT_AUTHORITY_COMMIT,
            "authorization_tree_git_oid": L2_HELD_OUT_AUTHORITY_TREE,
            "branch": "main",
            "remote": EXPECTED_REMOTE,
            "local_origin_live_equal_before_invocation": True,
            "worktree_clean_before_invocation": True,
        },
        "R10E_L2_HELD_OUT_FAILURE_SOURCE",
    )
    for commit, expected_tree, label in (
        (L2_HELD_OUT_SOURCE_COMMIT, L2_HELD_OUT_SOURCE_TREE, "SOURCE"),
        (L2_HELD_OUT_STAGE_COMMIT, L2_HELD_OUT_STAGE_TREE, "STAGE"),
        (L2_HELD_OUT_AUTHORITY_COMMIT, L2_HELD_OUT_AUTHORITY_TREE, "AUTHORITY"),
        (L2_HELD_OUT_FAILURE_COMMIT, L2_HELD_OUT_FAILURE_TREE, "FAILURE"),
    ):
        require(
            git_text(("rev-parse", f"{commit}^{{tree}}"), f"R10E_L2_{label}_TREE")
            == expected_tree,
            f"R10E_L2_HELD_OUT_FAILURE_{label}_TREE",
        )
    require(
        git_text(
            ("rev-parse", f"{L2_HELD_OUT_STAGE_COMMIT}^"),
            "R10E_L2_STAGE_PARENT",
        )
        == L2_HELD_OUT_SOURCE_COMMIT
        and git_text(
            ("rev-parse", f"{L2_HELD_OUT_AUTHORITY_COMMIT}^"),
            "R10E_L2_AUTHORITY_PARENT",
        )
        == L2_HELD_OUT_STAGE_COMMIT
        and git_text(
            ("rev-parse", f"{L2_HELD_OUT_FAILURE_COMMIT}^"),
            "R10E_L2_FAILURE_PARENT",
        )
        == L2_HELD_OUT_AUTHORITY_COMMIT,
        "R10E_L2_HELD_OUT_FAILURE_PARENT_CHAIN",
    )
    expected_commit_paths = (
        (
            L2_HELD_OUT_STAGE_COMMIT,
            "sdk/qsdk_r10e_held_out_finite_decision_zero_world_qualification_closure_v2.json",
            "STAGE",
        ),
        (
            L2_HELD_OUT_AUTHORITY_COMMIT,
            "sdk/qsdk_r10e_held_out_finite_decision_execution_authority_v2.json",
            "AUTHORITY",
        ),
        (
            L2_HELD_OUT_FAILURE_COMMIT,
            L2_HELD_OUT_FAILURE_CLOSURE_PATH.relative_to(ROOT).as_posix(),
            "FAILURE",
        ),
    )
    for commit, expected_path, label in expected_commit_paths:
        changed_paths = git_text(
            (
                "diff-tree",
                "--no-commit-id",
                "--name-only",
                "--no-renames",
                "-r",
                commit,
            ),
            f"R10E_L2_{label}_PATH",
        ).splitlines()
        require(
            changed_paths == [expected_path],
            f"R10E_L2_HELD_OUT_FAILURE_{label}_COMMIT_SCOPE",
        )
    failure_relative = L2_HELD_OUT_FAILURE_CLOSURE_PATH.relative_to(ROOT).as_posix()
    require(
        git_text(
            ("rev-parse", f"{L2_HELD_OUT_FAILURE_COMMIT}:{failure_relative}"),
            "R10E_L2_FAILURE_BLOB_OID",
        )
        == "181064bccbccf755cb6a10093318ff0d43b4ed9f",
        "R10E_L2_HELD_OUT_FAILURE_BLOB_OID",
    )

    expected_stage_binding = {
        "path": "sdk/qsdk_r10e_held_out_finite_decision_zero_world_qualification_closure_v2.json",
        "byte_length": 5_118,
        "raw_sha256": "sha256:949b6e98534bdcb237b407684b646f0cef54dfadb474d90fdbcabfaf1ff719eb",
        "git_blob_oid": "5f9f4cef057269ddd8152803a6d48dfc21a27d4e",
    }
    expected_authority_binding = {
        "path": "sdk/qsdk_r10e_held_out_finite_decision_execution_authority_v2.json",
        "byte_length": 2_318,
        "raw_sha256": "sha256:35916dda16f755b0c5e2f946a140f001baab4776d4a994ca95b7e4cc5ce51f1c",
        "git_blob_oid": "e15a93f04b15ae4c4f0c0a8a0b7ffd06c915a6c6",
    }
    expected_completion_binding = {
        "path": "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r10e-held-out-finite-decision-zero-world-qualification-ea290eab9bed/qualification_completion.json",
        "byte_length": 2_981,
        "raw_sha256": "sha256:194f4ba12080f57c4ba5f5a2f665462f2adf41ea4ab01ed77d6aa0b4b6d7e2b4",
    }
    expected_development_binding = {
        "path": "sdk/qsdk_r10e_development_route_ghost_physical_closure_v2.json",
        "byte_length": 8_112,
        "raw_sha256": "sha256:c86603452d678bc91b9c80666aaac054aad050e7f872ab6cf4563f74de8db8e2",
        "git_blob_oid": "5d11b4781740712664dc56d3360a3f603d7673a9",
        "route_execution_valid": True,
        "behavior_passed": False,
        "held_out_qualification_eligible": True,
    }
    require(
        bindings.get("stage_freeze") == expected_stage_binding
        and bindings.get("execution_authority") == expected_authority_binding
        and bindings.get("qualification_completion") == expected_completion_binding
        and bindings.get("runtime_identity_sha256")
        == "sha256:116fe0ee876ab7057414023885860664876a40d0c57c0306e86ed8418f7c6356"
        and bindings.get("development_route_prerequisite")
        == expected_development_binding
        and bindings.get("qualified_source_path_count") == 88
        and bindings.get("qualified_source_path_sha256")
        == "sha256:f228a9c1bbeca5beee17d9cf92b08c8c016a18d6e975428d820a58f3d554b0d3"
        and bindings.get("authorized_output_root")
        == "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r10e-held-out-finite-decision-physical-ea290eab9bed",
        "R10E_L2_HELD_OUT_FAILURE_AUTHORITY_BINDINGS",
    )
    for binding, commit, label in (
        (expected_stage_binding, L2_HELD_OUT_STAGE_COMMIT, "STAGE"),
        (expected_authority_binding, L2_HELD_OUT_AUTHORITY_COMMIT, "AUTHORITY"),
        (expected_development_binding, L2_HELD_OUT_SOURCE_COMMIT, "DEVELOPMENT"),
    ):
        raw = git_bytes(
            ("show", f"{commit}:{binding['path']}"), f"R10E_L2_{label}_BLOB"
        )
        require(
            len(raw) == binding["byte_length"]
            and sha256_bytes(raw) == binding["raw_sha256"]
            and git_text(
                ("rev-parse", f"{commit}:{binding['path']}"),
                f"R10E_L2_{label}_OID",
            )
            == binding["git_blob_oid"],
            f"R10E_L2_HELD_OUT_FAILURE_{label}_BINDING",
        )
    completion_path = Path(expected_completion_binding["path"])
    require(
        completion_path.is_file()
        and not completion_path.is_symlink()
        and completion_path.stat().st_size == expected_completion_binding["byte_length"]
        and sha256_file(completion_path) == expected_completion_binding["raw_sha256"],
        "R10E_L2_HELD_OUT_FAILURE_QUALIFICATION_COMPLETION",
    )

    require(len(source_bindings) == 6, "R10E_L2_EXECUTION_SOURCE_BINDING_COUNT")
    for index, binding_value in enumerate(source_bindings):
        require(
            isinstance(binding_value, dict)
            and set(binding_value)
            == {"path", "byte_length", "raw_sha256", "git_blob_oid"},
            f"R10E_L2_EXECUTION_SOURCE_BINDING_SHAPE:{index}",
        )
        binding = binding_value
        raw = git_bytes(
            ("show", f"{L2_HELD_OUT_SOURCE_COMMIT}:{binding['path']}"),
            f"R10E_L2_EXECUTION_SOURCE_BLOB_{index}",
        )
        require(
            len(raw) == binding["byte_length"]
            and sha256_bytes(raw) == binding["raw_sha256"]
            and git_text(
                ("rev-parse", f"{L2_HELD_OUT_SOURCE_COMMIT}:{binding['path']}"),
                f"R10E_L2_EXECUTION_SOURCE_OID_{index}",
            )
            == binding["git_blob_oid"],
            f"R10E_L2_EXECUTION_SOURCE_BINDING:{index}",
        )
    validator_v1_binding = next(
        (
            value
            for value in source_bindings
            if value.get("path")
            == "sdk/adapters/godot/gdscript/qsdk_r10e_native_impulse_scalar_receipt_validation_v1.gd"
        ),
        None,
    )
    require(
        isinstance(validator_v1_binding, dict)
        and validator_v1_binding.get("byte_length") == 12_079
        and validator_v1_binding.get("raw_sha256")
        == "sha256:d8fc31b59d2d1e4d4cd77e9a8a1abc134a903a7cac2df3d4865dbd1f072e546a",
        "R10E_L2_VALIDATOR_BINDING",
    )
    validator_v1_path = ROOT / str(validator_v1_binding["path"])
    require(
        validator_v1_path.stat().st_size == validator_v1_binding["byte_length"]
        and sha256_file(validator_v1_path) == validator_v1_binding["raw_sha256"],
        "R10E_L2_VALIDATOR_IMMUTABLE",
    )

    tree = retained.get("retained_tree")
    expected_output_root = (
        "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/"
        "qsdk-r10e-held-out-finite-decision-physical-ea290eab9bed"
    )
    require(
        retained.get("output_root") == expected_output_root
        and retained.get("terminal_report_retained") is False
        and retained.get("terminal_report_absent") is True
        and isinstance(tree, dict),
        "R10E_L2_RETAINED_EVIDENCE_HEADER",
    )
    expected_files = [
        {
            "path": "baseline_s40101/attempt.json",
            "byte_length": 3_218,
            "raw_sha256": "sha256:5c1f5c0b473f4c91ea4b91cc688e27fa565559d929cf3b3c5fbf15a576c2e987",
        },
        {
            "path": "baseline_s40101/receipt.json",
            "byte_length": 6_798_172,
            "raw_sha256": "sha256:9be3ca4b67f847dab06daf1ec768f2010e4a35cc8604f0cf385c6399c202f91e",
        },
        {
            "path": "baseline_s40101/stderr.txt",
            "byte_length": 0,
            "raw_sha256": "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
        },
        {
            "path": "baseline_s40101/stdout.txt",
            "byte_length": 6_818_261,
            "raw_sha256": "sha256:9e88e23c4a6c31c1bc787bcb5b7ac59c608ae53206e3623e403208c28cdd6091",
        },
        {
            "path": "campaign_start.json",
            "byte_length": 1_648,
            "raw_sha256": "sha256:a46e27695c81c5573abd08630319ce409e4c6833e15f6c4335c5575570bc1df0",
        },
        {
            "path": "push_s40101/attempt.json",
            "byte_length": 3_207,
            "raw_sha256": "sha256:ffe3c7ea48ce9352bd15f3dabcbe5c8f3c96bff8e7aa4b39cf76ab0699ce1917",
        },
        {
            "path": "push_s40101/receipt.json",
            "byte_length": 6_401_011,
            "raw_sha256": "sha256:4aae37b8b18912e8b4d512302ae6d8867579fd20c6ce62fb308f633ee84667e6",
        },
        {
            "path": "push_s40101/stderr.txt",
            "byte_length": 0,
            "raw_sha256": "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
        },
        {
            "path": "push_s40101/stdout.txt",
            "byte_length": 6_420_340,
            "raw_sha256": "sha256:19a9a0551170987483ee9f9aa9792adb6de9d5a3d785919d28f1119c6d05772f",
        },
    ]
    require(
        tree.get("schema_version")
        == "sporespore_qsdk_r10e_l2_incomplete_retained_evidence_tree_v1"
        and tree.get("root") == expected_output_root
        and tree.get("file_count") == 9
        and tree.get("total_byte_length") == 26_445_857
        and tree.get("path_set_sha256")
        == "sha256:c35873d746552ab49bf51387052d7e0c5d746b5958f8bf7fb274b795d8ca5089"
        and tree.get("manifest_sha256")
        == "sha256:fec3f36d76c9d36b11228de866e8b9c59339b86d90d260d12a580d5a6de91de3"
        and tree.get("files") == expected_files,
        "R10E_L2_RETAINED_EVIDENCE_MANIFEST",
    )
    evidence_root = Path(expected_output_root).resolve()
    require(
        evidence_root.is_dir() and not evidence_root.is_symlink(),
        "R10E_L2_RETAINED_EVIDENCE_ROOT",
    )
    all_entries = list(evidence_root.rglob("*"))
    require(
        all(not path.is_symlink() for path in all_entries),
        "R10E_L2_RETAINED_EVIDENCE_SYMLINK",
    )
    observed_paths = sorted(
        path.relative_to(evidence_root).as_posix()
        for path in all_entries
        if path.is_file()
    )
    require(
        observed_paths == [entry["path"] for entry in expected_files]
        and not (evidence_root / "terminal_report.json").exists(),
        "R10E_L2_RETAINED_EVIDENCE_PATH_SET",
    )
    observed_files: list[dict[str, Any]] = []
    for expected in expected_files:
        path = evidence_root / expected["path"]
        observed_files.append(
            {
                "path": expected["path"],
                "byte_length": path.stat().st_size,
                "raw_sha256": sha256_file(path),
            }
        )
    canonical_manifest = json.dumps(
        observed_files, sort_keys=True, separators=(",", ":")
    ).encode("utf-8")
    require(
        observed_files == expected_files
        and sum(value["byte_length"] for value in observed_files) == 26_445_857
        and sha256_bytes(canonical_manifest)
        == "sha256:fec3f36d76c9d36b11228de866e8b9c59339b86d90d260d12a580d5a6de91de3",
        "R10E_L2_RETAINED_EVIDENCE_FILE_BINDINGS",
    )

    require(
        len(cells) == 2
        and cells[0].get("cell_id") == "baseline_s40101"
        and cells[0].get("worker_ok") is True
        and cells[0].get("evidence_valid") is True
        and cells[0].get("outcome_complete") is True
        and cells[0].get("behavior_passed") is False
        and cells[0].get("only_false_walking_predicate") == "bounded_anchor_error"
        and cells[1].get("cell_id") == "push_s40101"
        and cells[1].get("worker_ok") is False
        and cells[1].get("failure_code")
        == "QSDK_R10E_PUSH_NATIVE_IMPULSE_RECEIPT_MISMATCH"
        and cells[1].get("evidence_valid") is False
        and cells[1].get("outcome_complete") is False
        and cells[1].get("behavior_passed") is None,
        "R10E_L2_OBSERVED_CELLS",
    )
    baseline_receipt = read_json(
        evidence_root / "baseline_s40101/receipt.json", "R10E_L2_BASELINE_RECEIPT"
    )
    push_receipt = read_json(
        evidence_root / "push_s40101/receipt.json", "R10E_L2_PUSH_RECEIPT"
    )
    require(
        baseline_receipt.get("ok") is True
        and baseline_receipt.get("evidence_valid") is True
        and baseline_receipt.get("outcome_complete") is True
        and baseline_receipt.get("behavior_passed") is False
        and baseline_receipt.get("world_build_count") == 1
        and baseline_receipt.get("evaluation", {})
        .get("pre_push_window", {})
        .get("passed")
        is True
        and baseline_receipt.get("evaluation", {})
        .get("baseline_post_marker_window", {})
        .get("passed")
        is True,
        "R10E_L2_BASELINE_RECEIPT_SEMANTICS",
    )
    push_summary = push_receipt.get("runtime_summary_projection")
    require(isinstance(push_summary, dict), "R10E_L2_PUSH_SUMMARY")
    native_receipt = push_summary.get("external_push_receipt")
    require(
        push_receipt.get("ok") is False
        and push_receipt.get("failure_code")
        == "QSDK_R10E_PUSH_NATIVE_IMPULSE_RECEIPT_MISMATCH"
        and push_receipt.get("evidence_valid") is False
        and push_receipt.get("outcome_complete") is False
        and push_receipt.get("behavior_passed") is False
        and push_receipt.get("world_build_count") == 1
        and push_summary.get("external_push_application_count") == 1
        and isinstance(native_receipt, dict)
        and native_receipt.get("application_count") == 1
        and native_receipt.get("application_method")
        == "RigidBody3D.apply_central_impulse"
        and native_receipt.get("step_from_sdk_start") == 900
        and native_receipt.get("impulse_task_n_s") == [0.0, 0.0, 0.25]
        and native_receipt.get("observed_next_tick_velocity_delta_world_m_s")
        == [-0.008176282048225403, 0.0009064096957445145, 0.06388828158378601]
        and native_receipt.get("observed_next_tick_velocity_delta_magnitude_m_s")
        == 0.06441572308540344,
        "R10E_L2_PUSH_RECEIPT_SEMANTICS",
    )
    observed_delta = native_receipt["observed_next_tick_velocity_delta_world_m_s"]
    binary64_norm = sum(float(value) ** 2 for value in observed_delta) ** 0.5
    require(
        numeric.get("classification")
        == "representation_validator_mismatch_not_physical_impulse_absence"
        and numeric.get("receipt_key_set_exact") is True
        and numeric.get("predicate_count") == 20
        and numeric.get("passed_predicate_count") == 19
        and numeric.get("failed_predicates")
        == ["observed_delta_vector_links_to_stored_magnitude"]
        and numeric.get("stored_host_real_magnitude_m_s")
        == native_receipt["observed_next_tick_velocity_delta_magnitude_m_s"]
        and numeric.get("binary64_recomputed_scalar_norm_m_s") == binary64_norm
        and numeric.get("absolute_difference_m_s")
        == abs(
            binary64_norm
            - native_receipt["observed_next_tick_velocity_delta_magnitude_m_s"]
        )
        and numeric.get("frozen_absolute_allowance_m_s") == 1.0e-9
        and numeric.get("native_effect_floor_m_s") == 1.0e-4
        and numeric.get("stored_effect_exceeds_native_effect_floor") is True
        and numeric.get("impulse_application_count") == 1
        and numeric.get("impulse_semantic_step") == 900
        and numeric.get("impulse_task_n_s") == [0.0, 0.0, 0.25]
        and numeric.get("world_impulse_n_s") == native_receipt["impulse_world_n_s"]
        and numeric.get("observed_velocity_delta_world_m_s") == observed_delta,
        "R10E_L2_NUMERIC_DIAGNOSIS",
    )
    require(
        terminalization.get("classification")
        == "supervisor_failed_to_terminalize_empty_pair_population"
        and terminalization.get("primary_cell_failure_preceded_terminalization_failure")
        is True
        and terminalization.get("pair_s40101_directory_created") is False
        and terminalization.get("pair_evaluation_count") == 0
        and terminalization.get("terminal_report_written") is False
        and terminalization.get("physical_closure_written") is False
        and "lacked AllowEmptyCollection" in terminalization.get("mechanism", "")
        and terminalization.get("operation_lock_released_by_outer_finally") is True,
        "R10E_L2_TERMINALIZATION_DIAGNOSIS",
    )
    require(
        outcome
        == {
            "declared_world_count": 6,
            "world_attempt_count": 2,
            "world_build_count_known": True,
            "world_build_count": 2,
            "remaining_unattempted_world_count": 4,
            "valid_complete_cell_count": 1,
            "invalid_or_incomplete_cell_count": 1,
            "pair_evaluation_count": 0,
            "route_execution_valid": False,
            "evidence_valid": False,
            "outcome_complete": False,
            "behavioral_conclusion_available": False,
            "behavior_passed": None,
            "physical_identity_consumed": True,
            "same_identity_rerun_permitted": False,
        },
        "R10E_L2_OUTCOME",
    )
    require(
        successor.get("successor_repair_id") == "QSDK-R10E-L3"
        and successor.get("repeat_failed_held_out_invocation") is False
        and successor.get("old_stage_freeze_reusable") is False
        and successor.get("old_execution_authority_reusable") is False
        and successor.get("development_route_ghost_rerun_required") is False
        and successor.get("development_route_ghost_rerun_permitted") is False
        and successor.get("new_clean_pushed_source_required") is True
        and successor.get("new_official_held_out_zero_world_qualification_required")
        is True
        and successor.get("new_held_out_stage_freeze_required") is True
        and successor.get("new_held_out_execution_authority_required") is True
        and successor.get("new_complete_six_world_identity_required") is True
        and successor.get("run_only_remaining_four_worlds_permitted") is False
        and successor.get("retained_l2_receipt_may_be_used_as_regression_only") is True
        and successor.get(
            "retained_l2_outcome_may_select_tolerance_or_behavior_threshold"
        )
        is False
        and all(
            successor.get(field) is False
            for field in (
                "controller_changed",
                "fixture_changed",
                "challenge_changed",
                "impulse_changed",
                "effect_floor_changed",
                "behavior_threshold_changed",
                "population_changed",
                "physical_canary_added",
            )
        ),
        "R10E_L2_SUCCESSOR_POLICY",
    )
    require(
        decision.get("result")
        == "held_out_invalid_or_incomplete_no_behavioral_conclusion"
        and decision.get("q_sdk_r10_satisfied") is False
        and decision.get("sdk1_m07_satisfied") is False
        and decision.get("external_push_recovery_claimed") is False
        and decision.get("new_physical_work_authorized_by_this_closure") is False
        and claim.get("retained_physical_attempt_claimed") is True
        and claim.get("genuine_godot_jolt_world_count_claimed") == 2
        and claim.get("bounded_upright_push_recovery_claimed") is False
        and claim.get("force_aware_recovery_claimed") is False
        and claim.get("physical_acceptance_authority") is False
        and claim.get("release_authority") is False,
        "R10E_L2_DECISION_AND_CLAIMS",
    )
    require(
        all(process.get(counter) == 0 for counter in ZERO_COUNTERS)
        and process.get("physics_state_modified") is False
        and process.get("physical_acceptance_authority") is False
        and process.get("release_authority") is False,
        "R10E_L2_FAILURE_CLOSURE_ZERO_WORLD",
    )

    validator_v2 = (
        ROOT
        / "sdk/adapters/godot/gdscript/qsdk_r10e_native_impulse_scalar_receipt_validation_v2.gd"
    ).read_text(encoding="utf-8")
    recovery = (
        ROOT / "scripts/lab/gait/qsdk_r10e_observer_minimized_upright_push_recovery.gd"
    ).read_text(encoding="utf-8")
    validator_function = re.search(
        r"(?ms)^static func validate_push_receipt\(.*?(?=^static func |\Z)",
        validator_v2,
    )
    require(
        validator_function is not None
        and validator_function.group(0).count("Vector3(") == 1
        and "Vector3(exported_components).length()" in validator_v2
        and '"observed_delta_host_real_vector_construction_count": 1' in validator_v2
        and '"axis_and_impulse_links_remain_scalar_only": true' in validator_v2
        and '"observed_l2_outcome_used_to_select_allowance": false' in validator_v2
        and '"effect_floor_changed": false' in validator_v2
        and '"behavior_threshold_changed": false' in validator_v2
        and "qsdk_r10e_native_impulse_scalar_receipt_validation_v2.gd" in recovery,
        "R10E_L3_NUMERIC_LINK_REPAIR_SURFACE",
    )
    return {
        "source_commit": L2_HELD_OUT_SOURCE_COMMIT,
        "stage_commit": L2_HELD_OUT_STAGE_COMMIT,
        "authority_commit": L2_HELD_OUT_AUTHORITY_COMMIT,
        "closure_commit": L2_HELD_OUT_FAILURE_COMMIT,
        "retained_file_count": len(observed_files),
        "retained_total_byte_length": sum(
            int(value["byte_length"]) for value in observed_files
        ),
        "declared_world_count": outcome["declared_world_count"],
        "world_attempt_count": outcome["world_attempt_count"],
        "world_build_count": outcome["world_build_count"],
        "remaining_unattempted_world_count": outcome[
            "remaining_unattempted_world_count"
        ],
        "failed_predicate": numeric["failed_predicates"][0],
        "stored_host_real_magnitude_m_s": numeric["stored_host_real_magnitude_m_s"],
        "binary64_recomputed_scalar_norm_m_s": numeric[
            "binary64_recomputed_scalar_norm_m_s"
        ],
        "absolute_difference_m_s": numeric["absolute_difference_m_s"],
        "frozen_absolute_allowance_m_s": numeric["frozen_absolute_allowance_m_s"],
        "native_effect_floor_m_s": numeric["native_effect_floor_m_s"],
        "same_identity_rerun_permitted": outcome["same_identity_rerun_permitted"],
    }


def run_design_and_history_audit() -> dict[str, Any]:
    design = validate_bound_json(
        DESIGN_PATH, EXPECTED_DESIGN_BYTES, EXPECTED_DESIGN_SHA256, "R10E_DESIGN"
    )
    require(
        design.get("status")
        == "prospective_zero_world_successor_design_complete_physics_blocked",
        "R10E_DESIGN_STATUS",
    )
    result = run_process((sys.executable, "-B", DESIGN_AUDIT_PATH), timeout_seconds=180)
    require(
        result.returncode == 0,
        f"R10E_DESIGN_AUDIT_PROCESS:{(result.stdout + result.stderr)[-3000:]}",
    )
    receipt = parse_marker(result.stdout, DESIGN_MARKER, "R10E_DESIGN_AUDIT")
    require_zero_world(receipt, "R10E_DESIGN_AUDIT")
    require(
        receipt.get("schema_version")
        == "sporespore_qsdk_r10e_observer_minimized_successor_design_audit_v1"
        and receipt.get("design_byte_length") == EXPECTED_DESIGN_BYTES
        and receipt.get("design_raw_sha256") == EXPECTED_DESIGN_SHA256
        and receipt.get("design_mutation_refusal_count") == 82
        and receipt.get("same_seed_pre_marker_pair_count") == 3
        and receipt.get("same_seed_pre_marker_different_row_count") == 0
        and receipt.get("single_rejecting_application_predicate")
        == "world_impulse_link"
        and receipt.get("r05e_selected_unopened_generator_index") == 225
        and receipt.get("q_sdk_r10_satisfied") is False
        and receipt.get("sdk1_m07_satisfied") is False,
        "R10E_DESIGN_AUDIT_RECEIPT",
    )

    development = validate_bound_json(
        R10D_DEVELOPMENT_PATH,
        EXPECTED_R10D_DEVELOPMENT_BYTES,
        EXPECTED_R10D_DEVELOPMENT_SHA256,
        "R10D_DEVELOPMENT",
    )
    held_out = validate_bound_json(
        R10D_HELD_OUT_PATH,
        EXPECTED_R10D_HELD_OUT_BYTES,
        EXPECTED_R10D_HELD_OUT_SHA256,
        "R10D_HELD_OUT",
    )
    r05e = validate_bound_json(
        R05E_PATH, EXPECTED_R05E_BYTES, EXPECTED_R05E_SHA256, "R05E"
    )
    require(
        development.get("status")
        == "closed_execution_valid_complete_behavior_finite_negative"
        and development.get("route_execution_valid") is True
        and development.get("evidence_valid") is True
        and development.get("outcome_complete") is True
        and development.get("behavior_passed") is False
        and development.get("physical_identity_consumed") is True
        and development.get("same_identity_rerun_permitted") is False,
        "R10D_DEVELOPMENT_BOUNDARY",
    )
    require(
        held_out.get("status")
        == "closed_consumed_invalid_or_incomplete_no_finite_decision"
        and held_out.get("route_execution_valid") is False
        and held_out.get("evidence_valid") is False
        and held_out.get("outcome_complete") is False
        and held_out.get("behavior_passed") is None
        and held_out.get("physical_identity_consumed") is True
        and held_out.get("same_identity_rerun_permitted") is False,
        "R10D_HELD_OUT_BOUNDARY",
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
        value
        for value in population.get("frozen_cells", [])
        if isinstance(value, dict) and value.get("generator_index") == 225
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
    return receipt


def run_dependency_audit(*, require_tracked: bool) -> dict[str, Any]:
    arguments: list[str | Path] = [sys.executable, "-B", DEPENDENCY_AUDIT_PATH]
    if require_tracked:
        arguments.append("--require-tracked")
    result = run_process(arguments, timeout_seconds=180)
    require(
        result.returncode == 0,
        f"R10E_DEPENDENCY_PROCESS:{(result.stdout + result.stderr)[-3000:]}",
    )
    receipt = parse_marker(result.stdout, DEPENDENCY_MARKER, "R10E_DEPENDENCY")
    require_zero_world(receipt, "R10E_DEPENDENCY")
    require(
        receipt.get("schema_version")
        == "sporespore_qsdk_r10e_dependency_closure_zero_world_v4"
        and receipt.get("qualification_finalized") is True
        and receipt.get("qualified_source_path_count") == EXPECTED_SOURCE_COUNT
        and receipt.get("qualified_source_path_sha256") == EXPECTED_SOURCE_PATH_SHA256
        and receipt.get("tracked_source_required") is require_tracked
        and (not require_tracked or receipt.get("all_qualified_paths_tracked") is True)
        and receipt.get("all_qualified_paths_lf_checkout_policy") is True
        and receipt.get("mutation_rejection_count") == 4
        and receipt.get("process_and_audit_path_count") == 23
        and receipt.get("prospective_runtime_authority_path_count") == 4
        and receipt.get("all_prospective_runtime_authority_literals_observed") is True,
        "R10E_DEPENDENCY_RECEIPT",
    )
    return receipt


def run_materializer_self_test() -> dict[str, Any]:
    result = run_process(
        (sys.executable, "-B", MATERIALIZER_PATH, "self-test"), timeout_seconds=180
    )
    require(
        result.returncode == 0,
        f"R10E_MATERIALIZER_PROCESS:{(result.stdout + result.stderr)[-3000:]}",
    )
    receipt = parse_marker(result.stdout, MATERIALIZER_MARKER, "R10E_MATERIALIZER")
    require_zero_world(receipt, "R10E_MATERIALIZER")
    require(
        receipt.get("schema_version")
        == "sporespore_qsdk_r10e_authority_materializer_self_test_v1"
        and receipt.get("source_binding_finalized") is True
        and receipt.get("authority_valid_control_count") == 1
        and receipt.get("authority_mutation_rejection_count") == 11,
        "R10E_MATERIALIZER_RECEIPT",
    )
    return receipt


def run_physical_closure_self_test() -> dict[str, Any]:
    result = run_process(
        (sys.executable, "-B", PHYSICAL_CLOSURE_PATH, "self-test"),
        timeout_seconds=180,
    )
    require(
        result.returncode == 0,
        f"R10E_PHYSICAL_CLOSURE_PROCESS:{(result.stdout + result.stderr)[-3000:]}",
    )
    receipt = parse_marker(
        result.stdout, PHYSICAL_CLOSURE_MARKER, "R10E_PHYSICAL_CLOSURE"
    )
    require_zero_world(receipt, "R10E_PHYSICAL_CLOSURE")
    require(
        receipt.get("schema_version")
        == "sporespore_qsdk_r10e_physical_closure_self_test_v1"
        and receipt.get("synthetic_report_control_count") == 7
        and receipt.get("report_mutation_rejection_count") == 22
        and receipt.get("classifications")
        == [
            "valid_complete_behavior_positive",
            "valid_complete_behavior_finite_negative",
            "valid_complete_behavior_positive",
            "valid_complete_behavior_finite_negative",
            "invalid_or_incomplete_no_behavioral_conclusion",
            "invalid_or_incomplete_no_behavioral_conclusion",
            "invalid_or_incomplete_no_behavioral_conclusion",
        ],
        "R10E_PHYSICAL_CLOSURE_RECEIPT",
    )
    return receipt


def run_python_source_tests() -> int:
    result = run_process(
        (
            sys.executable,
            "-B",
            "-m",
            "unittest",
            "tests.test_qsdk_r10e_deferred_recovery_trace_source",
            "tests.test_qsdk_r10e_worker_source",
        ),
        timeout_seconds=180,
    )
    combined = result.stdout + result.stderr
    require(result.returncode == 0, f"R10E_PYTHON_SOURCE_TESTS:{combined[-3000:]}")
    require(
        "Ran 31 tests" in combined and "OK" in combined, "R10E_PYTHON_SOURCE_TEST_COUNT"
    )
    return 31


def isolated_godot_environment(directory: Path) -> dict[str, str]:
    environment = dict(os.environ)
    appdata = directory / "appdata"
    localappdata = directory / "localappdata"
    appdata.mkdir(parents=True)
    localappdata.mkdir(parents=True)
    environment["APPDATA"] = str(appdata)
    environment["LOCALAPPDATA"] = str(localappdata)
    environment.pop(ATTEMPT_PATH_ENV, None)
    environment.pop(ATTEMPT_TOKEN_ENV, None)
    return environment


def run_godot(
    godot: Path,
    script: str,
    user_arguments: Iterable[str],
    *,
    label: str,
    expect_success: bool,
) -> subprocess.CompletedProcess[str]:
    with tempfile.TemporaryDirectory(prefix="sporespore-r10e-zero-") as raw:
        temporary = Path(raw)
        arguments: list[str | Path] = [
            godot,
            "--headless",
            "--path",
            ROOT,
            "--log-file",
            temporary / "godot.log",
            "--script",
            script,
        ]
        values = list(user_arguments)
        if values:
            arguments.extend(("--", *values))
        result = run_process(
            arguments,
            timeout_seconds=240,
            environment=isolated_godot_environment(temporary),
        )
    if expect_success:
        require(
            result.returncode == 0,
            f"{label}_PROCESS:{(result.stdout + result.stderr)[-3000:]}",
        )
    else:
        require(result.returncode != 0, f"{label}_UNEXPECTED_SUCCESS")
    return result


def run_godot_json(
    godot: Path,
    script: str,
    marker: str,
    arguments: Iterable[str],
    *,
    label: str,
    expect_success: bool = True,
) -> dict[str, Any]:
    result = run_godot(
        godot,
        script,
        arguments,
        label=label,
        expect_success=expect_success,
    )
    receipt = parse_marker(result.stdout, marker, label)
    require_zero_world(receipt, label, require_ok=expect_success)
    return receipt


def run_godot_marker(
    godot: Path, script: str, marker: str, label: str
) -> dict[str, Any]:
    result = run_godot(godot, script, (), label=label, expect_success=True)
    matches = [line for line in result.stdout.splitlines() if line == marker]
    require(len(matches) == 1, f"{label}_MARKER_COUNT")
    return {"ok": True, "marker": marker}


def validate_source_receipt(receipt: Mapping[str, Any]) -> None:
    require_zero_world(receipt, "R10E_SOURCE")
    require(
        receipt.get("schema_version") == "sporespore_qsdk_r10e_source_zero_world_v1"
        and receipt.get("gate_id") == "QSDK-R10E"
        and receipt.get("repair_id") == "QSDK-R10E-L3"
        and receipt.get("superseded_physical_supervisor_refusal_sha256")
        == EXPECTED_SUPERVISOR_REFUSAL_CLOSURE_SHA256
        and receipt.get("l2_held_out_failure_closure_sha256")
        == EXPECTED_L2_HELD_OUT_FAILURE_CLOSURE_SHA256
        and receipt.get("ledger_scope")
        == {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "zero_world_source_and_evaluator_qualification",
            "question_class": "development",
        }
        and receipt.get("static_contract_compile_count") == 8
        and receipt.get("synthetic_positive_world_count") == 2
        and receipt.get("synthetic_positive_pair_count") == 1
        and receipt.get("valid_finite_negative_world_count") == 2
        and receipt.get("invalid_or_incomplete_refusal_count") == 21
        and receipt.get("authorization_document_valid_control_count") == 2
        and receipt.get("authorization_document_mutation_rejection_count") == 19
        and receipt.get("locomotion_outcome_exposure_count") == 0,
        "R10E_SOURCE_RECEIPT",
    )


def expected_contract_identities() -> list[tuple[str, int, str]]:
    identities: list[tuple[str, int, str]] = []
    for seed in (40002, 40101, 40102, 40103):
        identities.append(("matched_no_impulse_control", seed, f"baseline_s{seed}"))
        identities.append(("lateral_upright_impulse", seed, f"push_s{seed}"))
    return identities


def validate_contract(receipt: Mapping[str, Any]) -> None:
    require_zero_world(receipt, "R10E_WORKER_CONTRACT")
    contracts = receipt.get("contracts")
    require(
        receipt.get("schema_version")
        == "sporespore_qsdk_r10e_worker_contract_zero_world_v1"
        and receipt.get("gate_id") == "QSDK-R10E"
        and receipt.get("contract_count") == 8
        and isinstance(contracts, list)
        and len(contracts) == 8
        and receipt.get("physical_execution_authorized") is False
        and receipt.get("locomotion_outcome_exposure_count") == 0,
        "R10E_WORKER_CONTRACT_RECEIPT",
    )
    observed: list[tuple[str, int, str]] = []
    for contract in contracts:
        require(isinstance(contract, dict), "R10E_WORKER_CONTRACT_ENTRY")
        require(
            set(contract)
            == {
                "arm_id",
                "campaign_seed",
                "cell_id",
                "challenge_configuration_sha256",
                "trace_configuration_sha256",
            }
            and type(contract.get("campaign_seed")) is int
            and is_prefixed_sha256(contract.get("challenge_configuration_sha256"))
            and is_prefixed_sha256(contract.get("trace_configuration_sha256")),
            "R10E_WORKER_CONTRACT_ENTRY_FIELDS",
        )
        observed.append(
            (
                str(contract["arm_id"]),
                int(contract["campaign_seed"]),
                str(contract["cell_id"]),
            )
        )
    require(observed == expected_contract_identities(), "R10E_WORKER_CONTRACT_ORDER")


def validate_preflight(receipt: Mapping[str, Any], role: str) -> None:
    spec = ROLE_SPECS[role]
    entrypoints = receipt.get("entrypoints")
    require_zero_world(receipt, f"R10E_PREFLIGHT_{role}")
    require(
        receipt.get("schema_version")
        == "sporespore_qsdk_r10e_worker_entrypoint_zero_world_v1"
        and receipt.get("gate_id") == "QSDK-R10E"
        and receipt.get("campaign_role") == role
        and receipt.get("entrypoint_count") == len(spec["ordered_cell_ids"])
        and isinstance(entrypoints, list)
        and len(entrypoints) == len(spec["ordered_cell_ids"])
        and receipt.get("physical_execution_authorized") is False
        and receipt.get("locomotion_outcome_exposure_count") == 0,
        f"R10E_PREFLIGHT_RECEIPT_{role}",
    )
    observed_ids: list[str] = []
    for entry in entrypoints:
        require(isinstance(entry, dict), f"R10E_PREFLIGHT_ENTRY_{role}")
        require(
            entry.get("declared_policy_runtime_boundary_preflight_passed") is True
            and entry.get("world_build_count") == 0
            and is_prefixed_sha256(entry.get("trace_configuration_sha256")),
            f"R10E_PREFLIGHT_ENTRY_FIELDS_{role}",
        )
        observed_ids.append(str(entry.get("cell_id", "")))
    require(observed_ids == spec["ordered_cell_ids"], f"R10E_PREFLIGHT_ORDER_{role}")


def run_direct_bypass(godot: Path) -> dict[str, Any]:
    receipt = run_godot_json(
        godot,
        WORKER_SCRIPT,
        CELL_MARKER,
        (
            "physical",
            "held_out_finite_decision",
            "matched_no_impulse_control",
            "40101",
        ),
        label="R10E_DIRECT_BYPASS",
        expect_success=False,
    )
    require(
        receipt.get("ok") is False
        and receipt.get("failure_code") == "QSDK_R10E_PHYSICAL_AUTHORIZATION_REQUIRED",
        "R10E_DIRECT_BYPASS_FAILURE_CODE",
    )
    return receipt


def run_historical_development_bypass(godot: Path) -> dict[str, Any]:
    receipt = run_godot_json(
        godot,
        WORKER_SCRIPT,
        CELL_MARKER,
        ("physical", "development_route_ghost", "matched_no_impulse_control", "40002"),
        label="R10E_HISTORICAL_DEVELOPMENT_BYPASS",
        expect_success=False,
    )
    require(
        receipt.get("ok") is False
        and receipt.get("failure_code")
        == "QSDK_R10E_HISTORICAL_DEVELOPMENT_ROUTE_RERUN_FORBIDDEN",
        "R10E_HISTORICAL_DEVELOPMENT_BYPASS_FAILURE_CODE",
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
            "-Python",
            sys.executable,
        ),
        timeout_seconds=900,
    )
    require(
        result.returncode == 0,
        f"R10E_SUPERVISOR_PROCESS:{(result.stdout + result.stderr)[-4000:]}",
    )
    receipt = parse_marker(result.stdout, SUPERVISOR_MARKER, "R10E_SUPERVISOR")
    require_zero_world(receipt, "R10E_SUPERVISOR")
    require(
        receipt.get("schema_version") == "sporespore_qsdk_r10e_supervisor_zero_world_v1"
        and receipt.get("gate_id") == "QSDK-R10E"
        and receipt.get("repair_id") == "QSDK-R10E-L3"
        and receipt.get("superseded_physical_supervisor_refusal_sha256")
        == EXPECTED_SUPERVISOR_REFUSAL_CLOSURE_SHA256
        and receipt.get("l2_held_out_failure_closure_sha256")
        == EXPECTED_L2_HELD_OUT_FAILURE_CLOSURE_SHA256
        and receipt.get("direct_physical_bypass_refused") is True
        and receipt.get("direct_physical_bypass_failure_code")
        == "QSDK_R10E_PHYSICAL_AUTHORIZATION_REQUIRED"
        and receipt.get("historical_development_route_bypass_refused") is True
        and receipt.get("historical_development_route_bypass_failure_code")
        == "QSDK_R10E_HISTORICAL_DEVELOPMENT_ROUTE_RERUN_FORBIDDEN"
        and receipt.get("physical_closure_path_control_count") == 2
        and receipt.get("physical_closure_path_controls")
        == [
            "sdk/qsdk_r10e_development_route_ghost_physical_closure_v2.json",
            "sdk/qsdk_r10e_held_out_finite_decision_physical_closure_v3.json",
        ]
        and receipt.get("empty_population_terminalization")
        == {
            "ok": True,
            "failure_code": "",
            "repair_id": "QSDK-R10E-L3",
            "empty_cells_accepted": True,
            "empty_pairs_accepted": True,
            "invalid_or_incomplete_preserved": True,
            "behavioral_conclusion_available": False,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "native_readback_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        }
        and receipt.get("physical_execution_authorized") is False
        and receipt.get("locomotion_outcome_exposure_count") == 0,
        "R10E_SUPERVISOR_RECEIPT",
    )
    return receipt


def run_black_check() -> int:
    result = run_process(
        (sys.executable, "-m", "black", "--check", *BLACK_PATHS),
        timeout_seconds=180,
    )
    require(
        result.returncode == 0,
        f"R10E_BLACK_CHECK:{(result.stdout + result.stderr)[-3000:]}",
    )
    return len(BLACK_PATHS)


def run_gdscript_checks() -> dict[str, Any]:
    gdformat = shutil.which("gdformat")
    gdlint = shutil.which("gdlint")
    require(gdformat is not None and gdlint is not None, "GDSCRIPT_TOOLS_MISSING")
    format_result = run_process(
        (gdformat, "--check", *GDSCRIPT_PATHS), timeout_seconds=180
    )
    require(
        format_result.returncode == 0,
        f"R10E_GDFORMAT_CHECK:{(format_result.stdout + format_result.stderr)[-3000:]}",
    )
    lint_result = run_process((gdlint, *GDSCRIPT_PATHS), timeout_seconds=180)
    require(
        lint_result.returncode == 0,
        f"R10E_GDLINT_CHECK:{(lint_result.stdout + lint_result.stderr)[-3000:]}",
    )
    return {"gdformat": gdformat, "gdlint": gdlint, "path_count": len(GDSCRIPT_PATHS)}


def run_powershell_parse_check(pwsh: str) -> int:
    records = powershell_ast_scan(pwsh, POWERSHELL_PATHS)
    require(
        all(
            record.get("parse_error_count") == 0
            and record.get("command_ast_named_if_count") == 0
            for record in records
        ),
        "R10E_POWERSHELL_PARSE_OR_COMMAND_AST_IF",
    )
    return len(records)


def run_rust_checks() -> None:
    cargo = shutil.which("cargo")
    require(cargo is not None, "CARGO_MISSING")
    format_result = run_process(
        (cargo, "fmt", "--all", "--", "--check"),
        timeout_seconds=180,
        cwd=ROOT / "sdk",
    )
    require(
        format_result.returncode == 0,
        f"R10E_CARGO_FORMAT:{(format_result.stdout + format_result.stderr)[-3000:]}",
    )
    check_result = run_process(
        (cargo, "check", "--workspace"), timeout_seconds=600, cwd=ROOT / "sdk"
    )
    require(
        check_result.returncode == 0,
        f"R10E_CARGO_CHECK:{(check_result.stdout + check_result.stderr)[-3000:]}",
    )


def validate_static_authorization_boundary() -> int:
    paths = (
        SUPERVISOR_PATH,
        QUALIFICATION_PATH,
        MATERIALIZER_PATH,
        PHYSICAL_CLOSURE_PATH,
        ROOT
        / "tests/test_sdk_qsdk_r10e_observer_minimized_upright_push_recovery_worker.gd",
        ROOT / "scripts/lab/gait/physical_wave_gait_quadruped.gd",
    )
    texts = {path: path.read_text(encoding="utf-8") for path in paths}
    worker = texts[
        ROOT
        / "tests/test_sdk_qsdk_r10e_observer_minimized_upright_push_recovery_worker.gd"
    ]
    physical_function = worker.index("func _physical(")
    authorization_call = worker.index(
        "_physical_authorization_receipt(", physical_function
    )
    world_call = worker.index("_run_cell(", authorization_call)
    require(authorization_call < world_call, "R10E_WORKER_AUTHORIZATION_ORDER")
    require(
        "QSDK_R10E_IMPLEMENTATION_QUALIFICATION_NOT_FINALIZED" in worker
        and "QSDK_R10E_PHYSICAL_AUTHORIZATION_REQUIRED" in worker
        and "QSDK_R10E_HISTORICAL_DEVELOPMENT_ROUTE_RERUN_FORBIDDEN" in worker
        and "authorized_single_use_unconsumed" in worker
        and "same_identity_rerun_permitted" in worker
        and "FileAccess.get_sha256(freeze_path)" in worker
        and "FileAccess.get_sha256(authority_path)" in worker
        and "PHYSICAL_SUPERVISOR_REFUSAL_SHA256" in worker
        and "L2_HELD_OUT_FAILURE_CLOSURE_SHA256" in worker
        and 'String(attempt.get("repair_id", "")) == "QSDK-R10E-L3"' in worker,
        "R10E_WORKER_AUTHORIZATION_SURFACE",
    )
    supervisor = texts[SUPERVISOR_PATH]
    require(
        "[switch]$AuthorizePhysical" in supervisor
        and '"Physical" { Invoke-SupervisorPhysical }' in supervisor
        and 'Assert-R10e $AuthorizePhysical "PHYSICAL_SWITCH_REQUIRED"' in supervisor
        and "Enter-SporeSporeLocomotionOperationLock" in supervisor
        and "Exit-SporeSporeLocomotionOperationLock" in supervisor
        and "physical_closure_path = (" in supervisor
        and "$closurePath = Join-Path $script:RepoRoot (" not in supervisor
        and "$script:ExpectedSupervisorRefusalSha256" in supervisor
        and "same_identity_rerun_permitted = $false" in supervisor
        and 'Assert-R10e (-not (Test-Path -LiteralPath $expectedOutput)) "PHYSICAL_IDENTITY_CONSUMED"'
        in supervisor,
        "R10E_SUPERVISOR_AUTHORIZATION_SURFACE",
    )
    qualification = texts[QUALIFICATION_PATH]
    require(
        "SPORESPORE_QSDK_R10E_QUALIFICATION_LOCK_HELD" in qualification
        and "physical_execution_authorized = $false" in qualification
        and "same_identity_rerun_permitted = $false" in qualification,
        "R10E_QUALIFICATION_AUTHORIZATION_SURFACE",
    )
    live = texts[ROOT / "scripts/lab/gait/physical_wave_gait_quadruped.gd"]
    require(
        len(
            re.findall(
                r"(?m)^\s*torso\.apply_central_impulse\(push_impulse_world\)$", live
            )
        )
        == 1
        and "DeferredRecoveryTraceScript" in live
        and "materialize_after_final_solver_step" in live,
        "R10E_LIVE_TRACE_AND_IMPULSE_SURFACE",
    )
    return len(paths)


def run_operation_lock_probe(pwsh: str) -> None:
    environment = dict(os.environ)
    environment["SPORESPORE_R10E_LOCK_PATH"] = str(OPERATION_LOCK_PATH)
    script = "\n".join(
        (
            "$ErrorActionPreference = 'Stop'",
            ". $env:SPORESPORE_R10E_LOCK_PATH",
            "$receipt = Enter-SporeSporeLocomotionOperationLock -Role conformance",
            "if (-not [bool]$receipt.acquired -or "
            "[bool]$receipt.abandoned_owner_recovered) { exit 71 }",
            "Exit-SporeSporeLocomotionOperationLock -Receipt $receipt",
            "if (-not [bool]$receipt.released) { exit 72 }",
            "Write-Output 'QSDK_R10E_OPERATION_LOCK_PROBE_PASS'",
        )
    )
    result = run_process(
        (pwsh, "-NoLogo", "-NoProfile", "-Command", script),
        timeout_seconds=60,
        environment=environment,
    )
    require(
        result.returncode == 0
        and result.stdout.count("QSDK_R10E_OPERATION_LOCK_PROBE_PASS") == 1,
        f"R10E_OPERATION_LOCK_PROBE:{(result.stdout + result.stderr)[-3000:]}",
    )


def command_version(arguments: Iterable[str | Path], label: str) -> str:
    result = run_process(arguments, timeout_seconds=60)
    require(result.returncode == 0, f"{label}_VERSION_PROCESS")
    value = " ".join((result.stdout + result.stderr).strip().splitlines())
    require(bool(value), f"{label}_VERSION_EMPTY")
    return value


def executable_identity(path: Path, version: str) -> dict[str, Any]:
    resolved = path.resolve()
    require(resolved.is_file(), f"RUNTIME_IDENTITY_PATH_MISSING:{resolved}")
    return {
        "path": str(resolved).replace("\\", "/"),
        "raw_sha256": sha256_file(resolved),
        "byte_length": resolved.stat().st_size,
        "version": version,
    }


def build_runtime_identity(
    source_commit: str,
    godot: Path,
    pwsh: str,
    gdscript_tools: Mapping[str, Any],
    dependency: Mapping[str, Any],
) -> dict[str, Any]:
    git_path = shutil.which("git")
    cargo_path = shutil.which("cargo")
    require(git_path is not None and cargo_path is not None, "RUNTIME_TOOLS_MISSING")
    adapter_digest = sha256_file(ACTIVE_ADAPTER_PATH)
    require(
        dependency.get("active_runtime_artifact_raw_sha256") == adapter_digest
        and dependency.get("active_runtime_artifact_byte_length")
        == ACTIVE_ADAPTER_PATH.stat().st_size,
        "ACTIVE_ADAPTER_DEPENDENCY_BINDING",
    )
    godot_version = command_version((godot, "--version"), "GODOT")
    python_version = command_version((sys.executable, "--version"), "PYTHON")
    powershell_version = command_version(
        (
            pwsh,
            "-NoLogo",
            "-NoProfile",
            "-Command",
            "$PSVersionTable.PSVersion.ToString()",
        ),
        "POWERSHELL",
    )
    return {
        "schema_version": "sporespore_qsdk_r10e_runtime_identity_v1",
        "gate_id": "QSDK-R10E",
        "source_commit": source_commit,
        "qualified_source_path_count": EXPECTED_SOURCE_COUNT,
        "qualified_source_path_sha256": EXPECTED_SOURCE_PATH_SHA256,
        "godot_console": executable_identity(godot, godot_version),
        "active_adapter": {
            "path": "sdk/target/debug/sporespore_godot_adapter.dll",
            "raw_sha256": adapter_digest,
            "byte_length": ACTIVE_ADAPTER_PATH.stat().st_size,
        },
        "active_adapter_raw_sha256": adapter_digest,
        "python": executable_identity(Path(sys.executable), python_version),
        "python_version": python_version,
        "powershell": executable_identity(Path(pwsh), powershell_version),
        "powershell_version": powershell_version,
        "git": executable_identity(
            Path(git_path), command_version((git_path, "--version"), "GIT")
        ),
        "cargo": executable_identity(
            Path(cargo_path), command_version((cargo_path, "--version"), "CARGO")
        ),
        "gdformat": executable_identity(
            Path(str(gdscript_tools["gdformat"])),
            command_version((str(gdscript_tools["gdformat"]), "--version"), "GDFORMAT"),
        ),
        "gdlint": executable_identity(
            Path(str(gdscript_tools["gdlint"])),
            command_version((str(gdscript_tools["gdlint"]), "--version"), "GDLINT"),
        ),
        "runtime_identity_complete": True,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, default=DEFAULT_GODOT)
    parser.add_argument("--require-tracked", action="store_true")
    parser.add_argument("--official-qualification", action="store_true")
    arguments = parser.parse_args()
    try:
        require(ROOT.resolve() == EXPECTED_ROOT.resolve(), "CANONICAL_ROOT")
        require(
            EXPECTED_SOURCE_COUNT > 0
            and is_prefixed_sha256(EXPECTED_SOURCE_PATH_SHA256),
            "SOURCE_BINDING_NOT_FINALIZED",
        )
        godot = arguments.godot.resolve()
        require(godot.is_file(), f"GODOT_CONSOLE_MISSING:{godot}")
        require(ACTIVE_ADAPTER_PATH.is_file(), "ACTIVE_ADAPTER_MISSING")
        pwsh = shutil.which("pwsh")
        require(pwsh is not None, "POWERSHELL_MISSING")
        for path in (*GDSCRIPT_PATHS, *PYTHON_PATHS, *POWERSHELL_PATHS):
            require(path.is_file(), f"QUALIFICATION_SOURCE_MISSING:{path}")

        source = inspect_source_boundary(
            official_qualification=arguments.official_qualification
        )
        require_tracked = arguments.require_tracked or arguments.official_qualification
        design = run_design_and_history_audit()
        qualification_failure = validate_predecessor_qualification_failure()
        supervisor_refusal = validate_predecessor_physical_supervisor_refusal(pwsh)
        l2_failure = validate_l2_held_out_failure()
        dependency = run_dependency_audit(require_tracked=require_tracked)
        comparison_dependency = (
            run_dependency_audit(require_tracked=False)
            if require_tracked
            else dependency
        )
        materializer = run_materializer_self_test()
        physical_closure = run_physical_closure_self_test()
        python_test_count = run_python_source_tests()
        black_path_count = run_black_check()
        gdscript_tools = run_gdscript_checks()
        powershell_path_count = run_powershell_parse_check(pwsh)
        run_rust_checks()
        static_path_count = validate_static_authorization_boundary()

        direct_source = run_godot_json(
            godot, SOURCE_SCRIPT, SOURCE_MARKER, (), label="R10E_SOURCE"
        )
        validate_source_receipt(direct_source)
        direct_deferred = run_godot_marker(
            godot, DEFERRED_TRACE_TEST, DEFERRED_TRACE_MARKER, "R10E_DEFERRED_TRACE"
        )
        direct_scalar = run_godot_marker(
            godot, SCALAR_RECEIPT_TEST, SCALAR_RECEIPT_MARKER, "R10E_SCALAR_RECEIPT"
        )
        direct_contract = run_godot_json(
            godot,
            WORKER_SCRIPT,
            CONTRACT_MARKER,
            ("contract",),
            label="R10E_WORKER_CONTRACT",
        )
        validate_contract(direct_contract)
        direct_preflights: list[dict[str, Any]] = []
        for role in ROLE_SPECS:
            receipt = run_godot_json(
                godot,
                WORKER_SCRIPT,
                PREFLIGHT_MARKER,
                ("preflight", role),
                label=f"R10E_PREFLIGHT_{role}",
            )
            validate_preflight(receipt, role)
            direct_preflights.append(receipt)
        direct_bypass = run_direct_bypass(godot)
        historical_development_bypass = run_historical_development_bypass(godot)
        supervisor = run_supervisor(pwsh, godot)
        require(
            supervisor.get("source_gate") == direct_source, "SOURCE_RECEIPT_DIVERGENCE"
        )
        require(
            supervisor.get("deferred_trace_gate") == direct_deferred,
            "DEFERRED_TRACE_RECEIPT_DIVERGENCE",
        )
        require(
            supervisor.get("scalar_receipt_gate") == direct_scalar,
            "SCALAR_RECEIPT_DIVERGENCE",
        )
        require(
            supervisor.get("worker_contract") == direct_contract,
            "WORKER_CONTRACT_RECEIPT_DIVERGENCE",
        )
        require(
            supervisor.get("entrypoint_preflights") == direct_preflights,
            "PREFLIGHT_RECEIPT_DIVERGENCE",
        )
        require(
            supervisor.get("dependency_closure") == comparison_dependency,
            "DEPENDENCY_RECEIPT_DIVERGENCE",
        )
        require(
            supervisor.get("direct_physical_bypass_failure_code")
            == direct_bypass.get("failure_code"),
            "BYPASS_RECEIPT_DIVERGENCE",
        )
        require(
            supervisor.get("historical_development_route_bypass_failure_code")
            == historical_development_bypass.get("failure_code"),
            "HISTORICAL_DEVELOPMENT_BYPASS_RECEIPT_DIVERGENCE",
        )

        wrapper_lock_held = os.environ.get(QUALIFICATION_LOCK_ENV) == "1"
        require(
            wrapper_lock_held is arguments.official_qualification,
            "QUALIFICATION_LOCK_OWNERSHIP",
        )
        if wrapper_lock_held:
            operation_lock_mode = "held_by_official_qualification_wrapper"
        else:
            run_operation_lock_probe(pwsh)
            operation_lock_mode = "independent_acquire_release_probe"

        runtime = build_runtime_identity(
            str(source["source_commit"]), godot, pwsh, gdscript_tools, dependency
        )
        runtime_digest = sha256_bytes(
            json.dumps(runtime, sort_keys=True, separators=(",", ":")).encode("utf-8")
        )
        audit_status = (
            "closed_passing_official_zero_world_qualification"
            if arguments.official_qualification
            else "passing_development_zero_world_implementation_audit"
        )
        receipt = {
            "schema_version": "sporespore_qsdk_r10e_zero_world_implementation_audit_v1",
            "status": audit_status,
            "gate_id": "QSDK-R10E",
            "repair_id": "QSDK-R10E-L3",
            "ledger_scope": {
                "subsystem": "recovery",
                "engine_scope": "godot_jolt",
                "authority_mode": "official_zero_world_implementation_qualification",
                "question_class": "development",
            },
            "ok": True,
            "failure_code": "",
            **source,
            "r10e_design_raw_sha256": EXPECTED_DESIGN_SHA256,
            "r10e_design_byte_length": EXPECTED_DESIGN_BYTES,
            "r10e_design_audit_passed": True,
            "r10e_design_mutation_rejection_count": design[
                "design_mutation_refusal_count"
            ],
            "r10d_development_closure_raw_sha256": EXPECTED_R10D_DEVELOPMENT_SHA256,
            "r10d_development_closure_byte_length": EXPECTED_R10D_DEVELOPMENT_BYTES,
            "r10d_development_result_reclassified": False,
            "r10d_held_out_closure_raw_sha256": EXPECTED_R10D_HELD_OUT_SHA256,
            "r10d_held_out_closure_byte_length": EXPECTED_R10D_HELD_OUT_BYTES,
            "r10d_held_out_result_reclassified": False,
            "r05e_physical_closure_raw_sha256": EXPECTED_R05E_SHA256,
            "r05e_physical_closure_byte_length": EXPECTED_R05E_BYTES,
            "r05e_selected_generator_index": 225,
            "r05e_selected_generator_walking_receipt_count": 81,
            "r05e_selected_generator_false_walking_receipt_count": 0,
            "predecessor_qualification_failure_closure_raw_sha256": (
                EXPECTED_QUALIFICATION_FAILURE_CLOSURE_SHA256
            ),
            "predecessor_qualification_failure_source_commit": qualification_failure[
                "source_commit"
            ],
            "predecessor_qualification_failure_retained_file_count": (
                qualification_failure["retained_file_count"]
            ),
            "predecessor_qualification_failure_retained_total_byte_length": (
                qualification_failure["retained_total_byte_length"]
            ),
            "predecessor_qualification_parser_failure_count": qualification_failure[
                "parser_failure_count"
            ],
            "predecessor_qualification_world_attempt_count": qualification_failure[
                "world_attempt_count"
            ],
            "predecessor_qualification_world_build_count": qualification_failure[
                "world_build_count"
            ],
            "predecessor_qualification_solver_step_count": qualification_failure[
                "solver_step_count"
            ],
            "predecessor_physical_supervisor_refusal_closure_raw_sha256": (
                EXPECTED_SUPERVISOR_REFUSAL_CLOSURE_SHA256
            ),
            "predecessor_physical_supervisor_refusal_source_commit": (
                supervisor_refusal["source_commit"]
            ),
            "predecessor_physical_supervisor_refusal_stage_commit": (
                supervisor_refusal["stage_commit"]
            ),
            "predecessor_physical_supervisor_refusal_authority_commit": (
                supervisor_refusal["authority_commit"]
            ),
            "predecessor_physical_supervisor_invocation_count": supervisor_refusal[
                "physical_supervisor_invocation_count"
            ],
            "predecessor_physical_supervisor_command_ast_named_if_count": (
                supervisor_refusal["old_command_ast_named_if_count"]
            ),
            "repaired_physical_supervisor_command_ast_named_if_count": (
                supervisor_refusal["current_command_ast_named_if_count"]
            ),
            "predecessor_physical_attempt_identity_consumed": supervisor_refusal[
                "physical_attempt_identity_consumed"
            ],
            "predecessor_physical_supervisor_world_attempt_count": supervisor_refusal[
                "world_attempt_count"
            ],
            "predecessor_physical_supervisor_world_build_count": supervisor_refusal[
                "world_build_count"
            ],
            "predecessor_physical_supervisor_solver_step_count": supervisor_refusal[
                "solver_step_count"
            ],
            "l2_held_out_failure_closure_raw_sha256": (
                EXPECTED_L2_HELD_OUT_FAILURE_CLOSURE_SHA256
            ),
            "l2_held_out_failure_closure_byte_length": (
                EXPECTED_L2_HELD_OUT_FAILURE_CLOSURE_BYTES
            ),
            "l2_held_out_failure_source_commit": l2_failure["source_commit"],
            "l2_held_out_failure_stage_commit": l2_failure["stage_commit"],
            "l2_held_out_failure_authority_commit": l2_failure["authority_commit"],
            "l2_held_out_failure_closure_commit": l2_failure["closure_commit"],
            "l2_held_out_failure_retained_file_count": l2_failure[
                "retained_file_count"
            ],
            "l2_held_out_failure_retained_total_byte_length": l2_failure[
                "retained_total_byte_length"
            ],
            "l2_held_out_declared_world_count": l2_failure["declared_world_count"],
            "l2_held_out_world_attempt_count": l2_failure["world_attempt_count"],
            "l2_held_out_world_build_count": l2_failure["world_build_count"],
            "l2_held_out_remaining_unattempted_world_count": l2_failure[
                "remaining_unattempted_world_count"
            ],
            "l2_held_out_failed_predicate": l2_failure["failed_predicate"],
            "l2_stored_host_real_magnitude_m_s": l2_failure[
                "stored_host_real_magnitude_m_s"
            ],
            "l2_binary64_recomputed_scalar_norm_m_s": l2_failure[
                "binary64_recomputed_scalar_norm_m_s"
            ],
            "l2_numeric_absolute_difference_m_s": l2_failure["absolute_difference_m_s"],
            "l2_frozen_absolute_allowance_m_s": l2_failure[
                "frozen_absolute_allowance_m_s"
            ],
            "native_effect_floor_m_s": l2_failure["native_effect_floor_m_s"],
            "l2_same_identity_rerun_permitted": l2_failure[
                "same_identity_rerun_permitted"
            ],
            "l3_retained_l2_receipt_used_as_regression_only": True,
            "l3_retained_l2_outcome_used_to_select_allowance": False,
            "l3_effect_floor_changed": False,
            "l3_behavior_threshold_changed": False,
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
            "prospective_runtime_authority_path_count": dependency[
                "prospective_runtime_authority_path_count"
            ],
            "authority_materializer_self_test_passed": True,
            "authority_materializer_valid_control_count": materializer[
                "authority_valid_control_count"
            ],
            "authority_materializer_mutation_rejection_count": materializer[
                "authority_mutation_rejection_count"
            ],
            "physical_closure_self_test_passed": True,
            "physical_closure_synthetic_report_control_count": physical_closure[
                "synthetic_report_control_count"
            ],
            "physical_closure_report_mutation_rejection_count": physical_closure[
                "report_mutation_rejection_count"
            ],
            "python_source_test_count": python_test_count,
            "python_source_tests_passed": True,
            "python_black_check_passed": True,
            "python_black_check_path_count": black_path_count,
            "gdformat_check_passed": True,
            "gdlint_check_passed": True,
            "gdscript_check_path_count": gdscript_tools["path_count"],
            "powershell_parse_passed": True,
            "powershell_parse_path_count": powershell_path_count,
            "powershell_command_ast_named_if_count": 0,
            "rust_format_check_passed": True,
            "rust_workspace_compile_check_passed": True,
            "rust_test_body_execution_count": 0,
            "static_authorization_boundary_passed": True,
            "static_authorization_path_count": static_path_count,
            "source_gate_count": 2,
            "source_receipts_exact_across_independent_runs": True,
            "static_contract_compile_count_per_source_gate": 8,
            "synthetic_positive_world_count_per_source_gate": 2,
            "synthetic_positive_pair_count_per_source_gate": 1,
            "valid_finite_negative_world_count_per_source_gate": 2,
            "invalid_or_incomplete_refusal_count_per_source_gate": 21,
            "authorization_document_valid_control_count_per_source_gate": 2,
            "authorization_document_mutation_rejection_count_per_source_gate": 19,
            "deferred_trace_gate_count": 2,
            "scalar_receipt_gate_count": 2,
            "worker_contract_count_per_gate": 8,
            "entrypoint_preflight_receipt_count_per_gate": 2,
            "development_entrypoint_count_per_gate": 2,
            "held_out_entrypoint_count_per_gate": 6,
            "direct_physical_bypass_refusal_count": 2,
            "direct_bypass_failure_code": direct_bypass["failure_code"],
            "historical_development_route_bypass_refusal_count": 2,
            "historical_development_route_bypass_failure_code": (
                historical_development_bypass["failure_code"]
            ),
            "operation_lock_boundary_passed": True,
            "operation_lock_probe_passed": not wrapper_lock_held,
            "operation_lock_mode": operation_lock_mode,
            "runtime_identity": runtime,
            "runtime_identity_sha256": runtime_digest,
            "official_qualification": arguments.official_qualification,
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
    except (
        AuditFailure,
        KeyError,
        IndexError,
        TypeError,
        OSError,
        UnicodeError,
        json.JSONDecodeError,
        subprocess.TimeoutExpired,
    ) as exc:
        print(f"QSDK_R10E_ZERO_WORLD_IMPLEMENTATION_FAIL {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
