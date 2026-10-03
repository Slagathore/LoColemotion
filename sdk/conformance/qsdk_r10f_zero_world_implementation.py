#!/usr/bin/env python3
"""Audit the complete QSDK-R10F implementation without opening a world."""

from __future__ import annotations

import argparse
import contextlib
import copy
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from typing import Any, Iterable, Mapping


ROOT = Path(__file__).resolve().parents[2]
if str(Path(__file__).resolve().parent) not in sys.path:
    sys.path.insert(0, str(Path(__file__).resolve().parent))
import qsdk_r10f_l14_authority_contract as l14_authority
import qsdk_r10f_l14_qualification_components as l14_components
import qsdk_r10f_l14_qualification_pipeline as l14_pipeline
import qsdk_r10f_l14_runtime_binding as l14_runtime

EXPECTED_ROOT = Path(r"C:\Users\Cole\CodeStuff\games\SporeSpore")
EXPECTED_REMOTE = "https://github.com/Slagathore/sporespore.git"
DEFAULT_GODOT = Path(
    r"C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
    r"\qsdk-r24d157-godot-jolt-rotation-integration-energy-v6"
    r"\development-cold-build-ed4ec00a"
    r"\godot.windows.editor.dev.x86_64.console.exe"
)
DESIGN_PATH = (
    ROOT / "sdk/qsdk_r10f_continuous_passive_fall_recovery_successor_design_v1.json"
)
REPAIR_DESIGN_PATH = l14_authority.DESIGN_PATH
BRANCH_COMPLETENESS_ADDENDUM_PATH = l14_authority.addendum_audit.PATH
EXPECTED_BRANCH_COMPLETENESS_ADDENDUM_SHA256 = l14_authority.addendum_audit.SHA256
# The original adapter-drift permission remains L13, not widened L14 authority.
HISTORICAL_ADAPTER_PERMISSION_PATH = (
    ROOT / "sdk/qsdk_r10f_l13_walking_ledger_transport_projection_successor_design_v1.json"
)
HISTORICAL_ADAPTER_PERMISSION_BYTES = 27_267
HISTORICAL_ADAPTER_PERMISSION_SHA256 = (
    "sha256:ce85d54e7a8cc12304015f5551d4f7874ad783613cd7feb566fc63cb10b20ce9"
)
PREDECESSOR_REPAIR_DESIGN_PATH = (
    ROOT / "sdk/qsdk_r10f_l12_walking_actuation_handoff_successor_design_v1.json"
)
DESIGN_AUDIT_PATH = (
    ROOT
    / "sdk/conformance/qsdk_r10f_continuous_passive_fall_recovery_successor_design.py"
)
DEPENDENCY_AUDIT_PATH = ROOT / "sdk/conformance/qsdk_r10f_dependency_closure.py"
MANIFEST_PATH = ROOT / "sdk/qsdk_r10f_dependency_manifest_v19.json"
SOURCE_TEST_PATH = ROOT / "tests/test_qsdk_r10f_worker_source.py"
ZERO_WORLD_SCRIPT = (
    "res://tests/test_sdk_qsdk_r10f_continuous_passive_recovery_zero_world.gd"
)
WORKER_SCRIPT = "res://tests/test_sdk_qsdk_r10f_continuous_passive_recovery_worker.gd"
SUPERVISOR_PATH = ROOT / "sdk/run_qsdk_r10f_continuous_passive_recovery.ps1"
QUALIFICATION_WRAPPER_PATH = ROOT / "sdk/qsdk_r10f_zero_world_qualification.ps1"
AUTHORITY_MATERIALIZER_PATH = (
    ROOT / "sdk/conformance/qsdk_r10f_authority_materializer.py"
)
PHYSICAL_CLOSURE_PATH = ROOT / "sdk/conformance/qsdk_r10f_physical_closure.py"
ACTIVE_ADAPTER_PATH = ROOT / "sdk/target/debug/sporespore_godot_adapter.dll"
SUPERVISOR_REFUSAL_PATH = (
    ROOT / "sdk/qsdk_r10f_development_route_ghost_physical_supervisor_refusal_v2.json"
)
PREDECESSOR_PHYSICAL_CLOSURE_PATH = (
    ROOT / "sdk/qsdk_r10f_development_route_ghost_physical_closure_v14.json"
)
QUALIFICATION_FAILURE_CLOSURE_PATH = (
    ROOT
    / "sdk/qsdk_r10f_development_route_ghost_zero_world_qualification_failure_closure_v1.json"
)
EXPECTED_QUALIFICATION_FAILURE_CLOSURE_BYTES = 6_151
EXPECTED_QUALIFICATION_FAILURE_CLOSURE_SHA256 = (
    "sha256:3aed8ce62bc18369f5698e78174e7fb85a36e8595d8d43196af4dad6a86db5a1"
)
FAILED_QUALIFICATION_SOURCE_COMMIT = "8de3a28f4a9cbbb9249fefd28d61eba420c011df"
EXPECTED_DESIGN_BYTES = 25_621
EXPECTED_DESIGN_SHA256 = (
    "sha256:696cc5ee80002e39968d27c6f21fa97f9309b7f08d3caad2961699ceb7184dfa"
)
EXPECTED_REPAIR_DESIGN_BYTES = l14_authority.design_audit.DESIGN_BYTES
EXPECTED_REPAIR_DESIGN_SHA256 = l14_authority.design_audit.DESIGN_SHA256
EXPECTED_PREDECESSOR_REPAIR_DESIGN_BYTES = 26_010
EXPECTED_PREDECESSOR_REPAIR_DESIGN_SHA256 = (
    "sha256:d10684da1566d9a0e4684ff1b13c3ddbc583d44b23088fc2485731c89a0a6de8"
)
REPAIR_ID = l14_authority.REPAIR_ID
EXPECTED_SUPERVISOR_REFUSAL_BYTES = 6_486
EXPECTED_SUPERVISOR_REFUSAL_SHA256 = (
    "sha256:93e60e8fe747a8ba7a5b6a1621175ce4bf877f537a2a5d03d01ff9e186e1140f"
)
EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_BYTES = l14_authority.PREDECESSOR_BYTES
EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_SHA256 = l14_authority.PREDECESSOR_SHA256
PASS_MARKER = "QSDK_R10F_ZERO_WORLD_IMPLEMENTATION_PASS "
DESIGN_MARKER = "QSDK_R10F_CONTINUOUS_PASSIVE_RECOVERY_SUCCESSOR_DESIGN_PASS "
DEPENDENCY_MARKER = "QSDK_R10F_DEPENDENCY_CLOSURE_PASS "
ZERO_WORLD_MARKER = "QSDK_R10F_CONTINUOUS_PASSIVE_RECOVERY_ZERO_WORLD "
SUPERVISOR_MARKER = "QSDK_R10F_SUPERVISOR_ZERO_WORLD_PASS "
SUPERVISOR_REFUSAL_MARKER = "QSDK_R10F_SUPERVISOR_REFUSAL "
MATERIALIZER_SELF_TEST_MARKER = "QSDK_R10F_AUTHORITY_MATERIALIZER_SELF_TEST_PASS "
PHYSICAL_CLOSURE_SELF_TEST_MARKER = "QSDK_R10F_PHYSICAL_CLOSURE_SELF_TEST_PASS "
QUALIFICATION_LOCK_ENV = "SPORESPORE_QSDK_R10F_QUALIFICATION_LOCK_HELD"
ZERO_COUNTERS = (
    "model_construction_count",
    "world_attempt_count",
    "world_build_count",
    "native_readback_count",
    "solver_step_count",
)
GDSCRIPT_PATHS = (
    ROOT / "sdk/adapters/godot/gdscript/recovery_epoch_boundary_transport_v1.gd",
    ROOT / "sdk/adapters/godot/gdscript/recovery_epoch_discrete_staging_route_v1.gd",
    ROOT / "sdk/adapters/godot/gdscript/recovery_epoch_energy_initializer_v1.gd",
    ROOT / "sdk/adapters/godot/gdscript/recovery_epoch_native_measurement_route_v1.gd",
    ROOT / "sdk/adapters/godot/gdscript/"
    "qsdk_r10f_event_triggered_passive_recovery_orchestrator_v1.gd",
    ROOT / "sdk/adapters/godot/gdscript/qsdk_r10f_native_impulse_pair_receipt_v1.gd",
    ROOT / "sdk/adapters/godot/gdscript/qsdk_r10f_precondition_pair_barrier_v1.gd",
    ROOT
    / "sdk/adapters/godot/gdscript/qsdk_r10f_precondition_terminal_disposition_v1.gd",
    ROOT
    / "sdk/adapters/godot/gdscript/qsdk_r10f_process_isolated_child_contract_v1.gd",
    ROOT / "sdk/adapters/godot/gdscript/"
    "qsdk_r10f_recovery_native_locomotion_facade_v1.gd",
    ROOT / "sdk/adapters/godot/gdscript/qsdk_r10f_walking_segment_evaluator_v1.gd",
    ROOT / "sdk/adapters/godot/gdscript/qsdk_r10f_walking_segment_evaluator_v2.gd",
    ROOT / "tests/test_sdk_qsdk_r10f_continuous_passive_recovery_worker.gd",
    ROOT / "tests/test_sdk_qsdk_r10f_continuous_passive_recovery_zero_world.gd",
    ROOT / "tests/test_sdk_qsdk_r10f_l14_walking_terminal_zero_world.gd",
    ROOT / "tests/test_sdk_qsdk_r10f_l14_worker_terminal_zero_world.gd",
    ROOT / "tests/test_sdk_qsdk_r10f_l14_no_resume_terminal_zero_world.gd",
)


class AuditFailure(RuntimeError):
    """The R10F implementation is not an exact zero-world authority."""


def require(condition: bool, code: str) -> None:
    if not condition:
        raise AuditFailure(code)


def sha256_file(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def is_sha256(value: Any) -> bool:
    return (
        isinstance(value, str)
        and re.fullmatch(r"sha256:[0-9a-f]{64}", value) is not None
    )


def exact_int(value: Any, expected: int) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value == expected


def run_process(
    arguments: Iterable[str | Path],
    *,
    timeout_seconds: int,
    environment: Mapping[str, str] | None = None,
    strict_utf8: bool = False,
) -> subprocess.CompletedProcess[str]:
    require(type(strict_utf8) is bool, "PROCESS_UTF8_MODE_KIND")
    result = subprocess.run(
        tuple(str(value) for value in arguments),
        cwd=ROOT,
        check=False,
        capture_output=True,
        text=not strict_utf8,
        encoding=None if strict_utf8 else "utf-8",
        errors=None if strict_utf8 else "replace",
        timeout=timeout_seconds,
        env=None if environment is None else dict(environment),
    )
    if strict_utf8:
        # Decode only after both byte streams are captured and the child joined.
        # On Windows a TextIOWrapper error otherwise occurs in a reader thread
        # and can leave stdout=None. No replacement or newline conversion here.
        return subprocess.CompletedProcess(
            result.args, result.returncode,
            result.stdout.decode("utf-8", errors="strict"),
            result.stderr.decode("utf-8", errors="strict"),
        )
    return result


def checked_process(
    arguments: Iterable[str | Path],
    label: str,
    *,
    timeout_seconds: int,
    strict_utf8: bool = False,
) -> subprocess.CompletedProcess[str]:
    result = run_process(
        arguments, timeout_seconds=timeout_seconds, strict_utf8=strict_utf8
    )
    require(
        result.returncode == 0,
        f"{label}_PROCESS:{(result.stdout + result.stderr)[-5000:]}",
    )
    return result


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


def require_zero_world(receipt: Mapping[str, Any], label: str) -> None:
    require(receipt.get("ok") is True, f"{label}_NOT_OK")
    for counter in ZERO_COUNTERS:
        require(receipt.get(counter) == 0, f"{label}_{counter.upper()}")
    require(receipt.get("scene_tree_insertion_count", 0) == 0, f"{label}_SCENE_TREE")
    require(receipt.get("physics_state_modified") is False, f"{label}_PHYSICS_STATE")
    require(
        receipt.get("physical_acceptance_authority") is False,
        f"{label}_PHYSICAL_ACCEPTANCE",
    )
    require(receipt.get("release_authority") is False, f"{label}_RELEASE_AUTHORITY")


def git_text(arguments: Iterable[str], label: str) -> str:
    result = checked_process(("git", *arguments), label, timeout_seconds=60)
    return result.stdout.strip()


def inspect_source(*, official_qualification: bool) -> dict[str, Any]:
    root = Path(git_text(("rev-parse", "--show-toplevel"), "GIT_ROOT")).resolve()
    remote = git_text(("remote", "get-url", "origin"), "GIT_REMOTE")
    head = git_text(("rev-parse", "HEAD"), "GIT_HEAD")
    origin = git_text(("rev-parse", "origin/main"), "GIT_ORIGIN")
    branch = git_text(("branch", "--show-current"), "GIT_BRANCH")
    tree = git_text(("rev-parse", "HEAD^{tree}"), "GIT_TREE")
    status_result = checked_process(
        ("git", "status", "--porcelain=v1", "--untracked-files=all"),
        "GIT_STATUS",
        timeout_seconds=60,
    )
    clean = not status_result.stdout.strip()
    require(root == ROOT.resolve() == EXPECTED_ROOT.resolve(), "CANONICAL_ROOT")
    require(remote == EXPECTED_REMOTE, "CANONICAL_REMOTE")
    live_commit = ""
    live_equal = False
    if official_qualification:
        require(
            os.environ.get(QUALIFICATION_LOCK_ENV) == "1", "QUALIFICATION_LOCK_MISSING"
        )
        live = checked_process(
            ("git", "ls-remote", "origin", "refs/heads/main"),
            "GIT_LIVE_MAIN",
            timeout_seconds=90,
        )
        records = [line.split() for line in live.stdout.splitlines() if line.strip()]
        require(
            len(records) == 1
            and len(records[0]) == 2
            and records[0][1] == "refs/heads/main",
            "LIVE_MAIN_SHAPE",
        )
        live_commit = records[0][0]
        live_equal = live_commit == head
        require(
            branch == "main" and clean and head == origin and live_equal,
            "OFFICIAL_QUALIFICATION_REQUIRES_CLEAN_PUSHED_LIVE_MAIN",
        )
    return {
        "source_commit": head,
        "source_tree": tree,
        "source_branch": branch,
        "source_clean": clean,
        "source_origin_main_equal": head == origin,
        "source_live_main_equal": live_equal,
        "source_live_main_commit": live_commit,
        "official_qualification": official_qualification,
    }


def audit_design(*, require_l15_sources: bool = False) -> dict[str, Any]:
    require(type(require_l15_sources) is bool, "DESIGN_L15_MODE_KIND")
    require(DESIGN_PATH.stat().st_size == EXPECTED_DESIGN_BYTES, "DESIGN_BYTE_LENGTH")
    require(sha256_file(DESIGN_PATH) == EXPECTED_DESIGN_SHA256, "DESIGN_SHA256")
    require(
        HISTORICAL_ADAPTER_PERMISSION_PATH.stat().st_size == HISTORICAL_ADAPTER_PERMISSION_BYTES,
        "DESIGN_SUCCESSOR_BYTE_LENGTH",
    )
    require(
        sha256_file(HISTORICAL_ADAPTER_PERMISSION_PATH) == HISTORICAL_ADAPTER_PERMISSION_SHA256,
        "DESIGN_SUCCESSOR_SHA256",
    )
    successor_design = json.loads(HISTORICAL_ADAPTER_PERMISSION_PATH.read_text(encoding="utf-8"))
    require(isinstance(successor_design, dict), "DESIGN_SUCCESSOR_NOT_OBJECT")
    successor_bindings = successor_design.get("bound_authorities")
    controlled_change = successor_design.get("controlled_change")
    require(
        successor_design.get("repair_id") == "QSDK-R10F-L13"
        and isinstance(successor_bindings, list)
        and isinstance(controlled_change, dict)
        and controlled_change.get("change_class")
        == "walking_ledger_transport_verification_host_target_projection_and_failure_retention_only",
        "DESIGN_SUCCESSOR_AUTHORIZATION",
    )
    observed_adapter_bindings = [
        entry
        for entry in successor_bindings
        if isinstance(entry, dict)
        and entry.get("role") == "observed_l12_shared_walking_adapter_source"
    ]
    require(
        len(observed_adapter_bindings) == 1, "DESIGN_SUCCESSOR_ADAPTER_BINDING_COUNT"
    )
    observed_adapter = observed_adapter_bindings[0]
    expected_drift_path = "scripts/lab/gait/sdk_godot_jolt_adapter.gd"
    require(
        observed_adapter.get("path") == expected_drift_path
        and observed_adapter.get("git_blob_oid")
        == "ef793ede82d63ee266ee815f2b0dd19866ef9596"
        and observed_adapter.get("checkout_byte_length") == 331_602
        and observed_adapter.get("checkout_raw_sha256")
        == "sha256:10679c11476f9b83cd23205580313caba9b348e1bee2bb8473189f8f05f61e63",
        "DESIGN_SUCCESSOR_ADAPTER_BINDING",
    )

    expected_drift_paths = [expected_drift_path]
    l15_handoff: dict[str, Any] = {}
    historical_auditor_binding: dict[str, Any] = {}
    historical_auditor_raw = b""
    current_source = ""
    if require_l15_sources:
        import qsdk_r10f_authority_materializer as materializer
        import qsdk_r10f_l15_source_binding as l15_source_binding

        current_source = git_text(("rev-parse", "HEAD"), "DESIGN_L15_SOURCE")
        # Run the actual source consumer, including the separate L13 adapter
        # rule. A changed-path list alone is not permission for current bytes.
        root_design, authorities = materializer.design_binding(
            current_source, require_l15_sources=True
        )
        require(
            authorities == root_design["bound_authorities"], "DESIGN_L15_ROOT_HISTORY"
        )
        l15_handoff = l15_source_binding.bind_root_sources(current_source, root_design)
        expected_drift_paths = [*l15_source_binding.SOURCE_ROLES, expected_drift_path]
        historical_auditor_raw, historical_auditor_binding = (
            l15_source_binding.bind_current_source(
                DESIGN_AUDIT_PATH.relative_to(ROOT).as_posix(), current_source
            )
        )
        require(
            tuple(
                historical_auditor_binding[key]
                for key in ("byte_length", "raw_sha256", "git_blob_oid")
            )
            == (
                67_778,
                "sha256:0834eaad48d264d06d546465268fd38aba020daa9837ca292ad877bdeb7403b7",
                "fa5229d8f73880c2e6b2ca26c0aef3190caf7485",
            )
            and git_text(
                (
                    "rev-parse",
                    "9f87f295e8adc7ec4d9632c45c6a3d624a8823d9:"
                    + DESIGN_AUDIT_PATH.relative_to(ROOT).as_posix(),
                ),
                "DESIGN_L15_ORIGINAL_AUDITOR",
            )
            == historical_auditor_binding["git_blob_oid"],
            "DESIGN_L15_ORIGINAL_AUDITOR_PIN",
        )

    spec = importlib.util.spec_from_file_location(
        "_qsdk_r10f_historical_root_design_audit", DESIGN_AUDIT_PATH
    )
    require(spec is not None and spec.loader is not None, "DESIGN_AUDIT_MODULE_SPEC")
    module = importlib.util.module_from_spec(spec)
    try:
        if require_l15_sources:
            # Execute the exact bytes whose identity was just checked, without
            # relying on a cached bytecode file or a second working-file read.
            exec(
                compile(historical_auditor_raw, str(DESIGN_AUDIT_PATH), "exec"),
                module.__dict__,
            )
        else:
            spec.loader.exec_module(module)
    except Exception as exc:  # pragma: no cover - fail-closed import boundary
        raise AuditFailure(f"DESIGN_AUDIT_MODULE_LOAD:{exc}") from exc

    current_disk_drift_paths: list[str] = []

    def load_historical_bound_authorities(design: dict[str, Any]) -> dict[str, bytes]:
        loaded: dict[str, bytes] = {}
        for entry in design["bound_authorities"]:
            role = str(entry["role"])
            path = str(entry["path"])
            historical_raw = module.git_bytes(
                ("show", f"{module.AUTHORED_PARENT}:{path}")
            )
            module.require(
                module.git_blob_oid(historical_raw) == entry["git_blob_oid"],
                f"{role}:HISTORICAL_BLOB",
            )
            module.require(
                module.git_text(("rev-parse", f"{module.AUTHORED_PARENT}:{path}"))
                == entry["git_blob_oid"],
                f"{role}:HISTORICAL_TREE_BINDING",
            )
            current_blob = module.git_text(("hash-object", "--", path))
            if current_blob == entry["git_blob_oid"]:
                # Preserve the original checkout-byte authority for legacy
                # CRLF files whose Git blob alone cannot reproduce those bytes.
                current_raw = (ROOT / path).read_bytes()
                module.require(
                    len(current_raw) == entry["byte_length"],
                    f"{role}:CURRENT_CHECKOUT_BYTES",
                )
                module.require(
                    module.sha256_bytes(current_raw) == entry["raw_sha256"],
                    f"{role}:CURRENT_CHECKOUT_SHA256",
                )
                loaded[role] = current_raw
            else:
                current_disk_drift_paths.append(path)
                # Each explicitly permitted changed source was already LF in
                # the authored tree; its Git and declared checkout bytes must
                # match exactly. Other paths still cannot gain drift permission.
                module.require(
                    len(historical_raw) == entry["byte_length"],
                    f"{role}:HISTORICAL_CHECKOUT_BYTES",
                )
                module.require(
                    module.sha256_bytes(historical_raw) == entry["raw_sha256"],
                    f"{role}:HISTORICAL_CHECKOUT_SHA256",
                )
                loaded[role] = historical_raw
        if require_l15_sources:
            module.require(
                current_disk_drift_paths == expected_drift_paths,
                "ROOT_DESIGN_CURRENT_DRIFT_NOT_EXACT_SUCCESSOR_SURFACE",
            )
        else:
            # Keep the original L13-only surface explicit in the legacy mode.
            module.require(
                current_disk_drift_paths == [expected_drift_path],
                "ROOT_DESIGN_CURRENT_DRIFT_NOT_EXACT_SUCCESSOR_SURFACE",
            )
        return loaded

    module.load_bound_authorities = load_historical_bound_authorities
    stdout = io.StringIO()
    try:
        with contextlib.redirect_stdout(stdout):
            exit_code = module.main()
    except Exception as exc:
        raise AuditFailure(f"DESIGN_HISTORICAL_REPLAY:{exc}") from exc
    require(exit_code == 0, "DESIGN_HISTORICAL_REPLAY_EXIT")
    receipt = parse_marker(stdout.getvalue(), DESIGN_MARKER, "DESIGN")
    require_zero_world(receipt, "DESIGN")
    require(receipt.get("gate_id") == "QSDK-R10F", "DESIGN_GATE")
    require(
        receipt.get("design_raw_sha256") == EXPECTED_DESIGN_SHA256, "DESIGN_RECEIPT_SHA"
    )
    require(receipt.get("sdk1_m07_satisfied") is False, "DESIGN_M07_PREMATURE")
    if require_l15_sources:
        # Keep the complete original audit as a nested historical object. In
        # particular, its older 3841-step design is not today's execution budget.
        return {
            "schema_version": "sporespore_qsdk_r10f_l15_root_design_projection_v1",
            "ledger_scope": {
                "subsystem": "recovery",
                "engine_scope": "godot_jolt",
                "authority_mode": "zero_world_explicit_historical_design_projection",
                "question_class": "development",
            },
            "ok": True,
            "source_commit": current_source,
            "historical_root_design_audit": receipt,
            "historical_auditor_source_binding": historical_auditor_binding,
            "historical_auditor_introduced_commit": "9f87f295e8adc7ec4d9632c45c6a3d624a8823d9",
            "l15_root_source_binding": l15_handoff,
            "unchanged_l13_adapter_permission": {
                "path": HISTORICAL_ADAPTER_PERMISSION_PATH.relative_to(ROOT).as_posix(),
                "byte_length": HISTORICAL_ADAPTER_PERMISSION_BYTES,
                "raw_sha256": HISTORICAL_ADAPTER_PERMISSION_SHA256,
            },
            "current_disk_drift_path_count": len(current_disk_drift_paths),
            "current_disk_drift_paths": current_disk_drift_paths,
            "historical_authority_input_loader_replaced": True,
            "historical_auditor_source_file_modified": False,
            "historical_design_and_behavior_predicates_rewritten": False,
            "historical_schedule_promoted_to_current_execution_budget": False,
            "physical_family_selector_changed": False,
            "whole_route_qualified": False,
            "official_qualification_consumed": False,
            "stage_file_written": False,
            "execution_authority_written": False,
            **dict.fromkeys((*ZERO_COUNTERS, "scene_tree_insertion_count"), 0),
            "physics_state_modified": False,
            "physical_execution_authorized": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        }
    receipt["bound_authority_source_mode"] = (
        "authored_parent_historical_replay_with_explicit_l13_successor_drift"
    )
    receipt["current_disk_drift_path_count"] = len(current_disk_drift_paths)
    receipt["current_disk_drift_paths"] = current_disk_drift_paths
    receipt["successor_authorization_repair_id"] = "QSDK-R10F-L13"
    receipt["active_repair_id"] = REPAIR_ID
    # The immutable historical receipt predates this explicit counter. Add it
    # only in the successor projection, after the complete old audit passes.
    receipt["scene_tree_insertion_count"] = 0
    receipt["scene_tree_counter_source"] = (
        "successor_zero_world_projection_after_complete_historical_validation"
    )
    return receipt


def audit_predecessor_qualification_failure() -> dict[str, Any]:
    """Reopen the consumed failure; a new source must not erase or retry it."""
    require(
        QUALIFICATION_FAILURE_CLOSURE_PATH.stat().st_size
        == EXPECTED_QUALIFICATION_FAILURE_CLOSURE_BYTES
        and sha256_file(QUALIFICATION_FAILURE_CLOSURE_PATH)
        == EXPECTED_QUALIFICATION_FAILURE_CLOSURE_SHA256,
        "QUALIFICATION_FAILURE_CLOSURE_BINDING",
    )
    closure = json.loads(QUALIFICATION_FAILURE_CLOSURE_PATH.read_text(encoding="utf-8"))
    require(
        closure["schema_version"]
        == "sporespore_qsdk_r10f_l13_zero_world_qualification_failure_closure_v1"
        and closure["status"]
        == "closed_failed_official_zero_world_qualification_identity_consumed_pre_physics"
        and closure["repair_id"] == "QSDK-R10F-L13",
        "QUALIFICATION_FAILURE_HEADER",
    )
    source = closure["source"]
    require(
        source["source_commit"] == FAILED_QUALIFICATION_SOURCE_COMMIT
        and git_text(
            ("rev-parse", f"{FAILED_QUALIFICATION_SOURCE_COMMIT}^{{tree}}"),
            "QUALIFICATION_FAILURE_SOURCE_TREE",
        )
        == source["source_tree_git_oid"],
        "QUALIFICATION_FAILURE_SOURCE_BINDING",
    )
    retained = closure["retained_evidence"]
    evidence_root = Path(retained["root"])
    require(
        evidence_root.resolve()
        == Path(
            r"C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
            r"\qsdk-r10f-development-route-ghost-zero-world-qualification-8de3a28f4a9c"
        ).resolve(),
        "QUALIFICATION_FAILURE_EVIDENCE_ROOT",
    )
    expected_files = retained["files"]
    require(
        sorted(
            path.relative_to(evidence_root).as_posix()
            for path in evidence_root.rglob("*")
            if path.is_file()
        )
        == [entry["path"] for entry in expected_files],
        "QUALIFICATION_FAILURE_FILE_SET",
    )
    observed_files = [
        {
            "path": entry["path"],
            "byte_length": (evidence_root / entry["path"]).stat().st_size,
            "raw_sha256": sha256_file(evidence_root / entry["path"]),
        }
        for entry in expected_files
    ]
    canonical = json.dumps(
        observed_files, separators=(",", ":"), ensure_ascii=True
    ).encode("utf-8")
    require(
        observed_files == expected_files
        and len(observed_files) == retained["file_count"] == 4
        and sum(entry["byte_length"] for entry in observed_files)
        == retained["total_byte_length"]
        == 28_659
        and len(canonical) == retained["canonical_manifest_byte_length"] == 570
        and "sha256:" + hashlib.sha256(canonical).hexdigest()
        == retained["canonical_manifest_sha256"],
        "QUALIFICATION_FAILURE_RETAINED_BINDINGS",
    )
    attempt = json.loads((evidence_root / "qualification_attempt.json").read_text())
    failure = json.loads((evidence_root / "qualification_failure.json").read_text())
    stdout = (evidence_root / "qualification_stdout.log").read_text(encoding="utf-8")
    implementation = parse_marker(stdout, PASS_MARKER, "FAILED_QUALIFICATION")
    require_zero_world(implementation, "FAILED_QUALIFICATION_IMPLEMENTATION")
    root_design = implementation["root_design_audit"]
    require_zero_world(root_design, "FAILED_QUALIFICATION_ROOT_DESIGN")
    require(
        attempt["source_commit"]
        == failure["source_commit"]
        == implementation["source"]["source_commit"]
        == FAILED_QUALIFICATION_SOURCE_COMMIT
        and attempt["same_identity_rerun_permitted"] is False
        and failure["same_identity_rerun_permitted"] is False
        and failure["status"]
        == "closed_failed_consumed_official_zero_world_qualification"
        and failure["failure_code"]
        == "IMPLEMENTATION_NONZERO:scene_tree_insertion_count"
        and "scene_tree_insertion_count" not in root_design
        and exact_int(implementation["scene_tree_insertion_count"], 0)
        and implementation["positive_case_count"] == 24
        and implementation["forced_failure_case_count"] == 237
        and "QSDK_R10F_ZERO_WORLD_QUALIFICATION_COMPLETE " not in stdout,
        "QUALIFICATION_FAILURE_EXACT_DIAGNOSIS",
    )
    for receipt in (attempt, failure, closure["execution_boundary"]):
        for counter in (*ZERO_COUNTERS, "scene_tree_insertion_count"):
            require(
                exact_int(receipt.get(counter), 0), f"QUALIFICATION_FAILURE_{counter}"
            )
        require(
            receipt["physics_state_modified"] is False, "QUALIFICATION_FAILURE_PHYSICS"
        )
    return {
        "ok": True,
        "closure_raw_sha256": EXPECTED_QUALIFICATION_FAILURE_CLOSURE_SHA256,
        "source_commit": FAILED_QUALIFICATION_SOURCE_COMMIT,
        "retained_file_count": len(observed_files),
        "retained_total_byte_length": retained["total_byte_length"],
        "failure_code": failure["failure_code"],
        "historical_missing_scene_tree_counter_confirmed": True,
        "same_identity_rerun_permitted": False,
        **dict.fromkeys((*ZERO_COUNTERS, "scene_tree_insertion_count"), 0),
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def audit_qualification_receipt_contract(receipt: Mapping[str, Any]) -> dict[str, Any]:
    """Execute the wrapper's real functions, never its one-shot entry point.

    A development receipt keeps its real source flags. Only the in-memory
    positive fixture projects those flags to exercise the official consumer;
    that projection is neither a qualification nor an execution authority.
    """
    positive = copy.deepcopy(dict(receipt))
    for field in (
        "official_qualification",
        "source_clean",
        "source_origin_main_equal",
        "source_live_main_equal",
    ):
        positive["source"][field] = True
    cases: list[dict[str, Any]] = [
        {"id": "complete_current_receipt", "receipt": positive, "accept": True}
    ]

    def reject(
        case_id: str,
        path: tuple[str, ...],
        value: Any,
        *,
        remove: bool = False,
        code: str | None = None,
    ) -> None:
        mutated = copy.deepcopy(positive)
        owner = mutated
        for key in path[:-1]:
            owner = owner[key]
        if remove:
            del owner[path[-1]]
        else:
            owner[path[-1]] = value
        cases.append({"id": case_id, "receipt": mutated, "accept": False, "code": code})

    for prefix in ((), ("root_design_audit",)):
        for counter in (*ZERO_COUNTERS, "scene_tree_insertion_count"):
            for label, value, remove in (
                ("missing", None, True),
                ("null", None, False),
                ("bool", False, False),
                ("float", 0.0, False),
                ("string", "0", False),
                ("nonzero", 1, False),
            ):
                reject(
                    "/".join((*prefix, counter, label)),
                    (*prefix, counter),
                    value,
                    remove=remove,
                    code=f"IMPLEMENTATION_NONZERO:{counter}",
                )
        for flag in (
            "physics_state_modified",
            "physical_acceptance_authority",
            "release_authority",
        ):
            reject(
                "/".join((*prefix, flag)),
                (*prefix, flag),
                True,
                code=f"IMPLEMENTATION_AUTHORITY_DRIFT:{flag}",
            )
    reject("source_not_official", ("source", "official_qualification"), False)
    reject("source_commit_drift", ("source", "source_commit"), "0" * 40)
    reject(
        "dependency_path_digest_drift",
        ("qualified_source_path_sha256",),
        "sha256:" + "0" * 64,
    )
    reject(
        "root_design_hash_drift",
        ("root_design_audit", "design_raw_sha256"),
        "sha256:" + "0" * 64,
    )
    reject("forced_failure_count_drift", ("forced_failure_case_count",), 236)
    reject("physical_authority", ("physical_execution_authorized",), True)
    reject("missing_branch_addendum", ("branch_completeness_addendum_sha256",), None, remove=True)
    reject("wrong_branch_addendum", ("branch_completeness_addendum_sha256",), EXPECTED_REPAIR_DESIGN_SHA256)
    reject("missing_active_repair", ("root_design_audit", "active_repair_id"), None, remove=True)
    reject("wrong_active_repair", ("root_design_audit", "active_repair_id"), "QSDK-R10F-L13")
    reject("historical_permission_renamed", ("root_design_audit", "successor_authorization_repair_id"), REPAIR_ID)
    reject("missing_l14_components", ("l14_component_qualification",), None, remove=True)
    for case in l14_components.receipt_corruptions():
        reject("l14_component:" + case["id"], ("l14_component_qualification",), case["receipt"])
    reject("missing_runtime_images", ("runtime_identity", "l14_exact_runtime_images"), None, remove=True)
    for case in l14_runtime.binding_corruptions():
        reject("l14_runtime:" + case["id"], ("runtime_identity", "l14_exact_runtime_images"), case["binding"])
    reject(
        "failure_closure_digest_drift",
        ("predecessor_qualification_failure_closure_raw_sha256",),
        "sha256:" + "0" * 64,
    )
    closure = json.loads(QUALIFICATION_FAILURE_CLOSURE_PATH.read_text(encoding="utf-8"))
    historical = parse_marker(
        (
            Path(closure["retained_evidence"]["root"]) / "qualification_stdout.log"
        ).read_text(encoding="utf-8"),
        PASS_MARKER,
        "WRAPPER_RETAINED_FAILURE",
    )
    cases.append(
        {
            "id": "exact_retained_failed_receipt",
            "receipt": historical,
            "accept": False,
            "code": "IMPLEMENTATION_NONZERO:scene_tree_insertion_count",
        }
    )
    payload = {
        "wrapper_path": str(QUALIFICATION_WRAPPER_PATH),
        "runtime_module": str(ROOT / "sdk/qsdk_r10f_l14_runtime_binding.ps1"),
        "source": {
            "commit": positive["source"]["source_commit"],
            "tree": positive["source"]["source_tree"],
        },
        "policy": {
            "expected_qualified_source_count": positive["qualified_source_path_count"],
            "expected_qualified_source_path_sha256": positive[
                "qualified_source_path_sha256"
            ],
        },
        "cases": cases,
    }
    script = r"""
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$payload = [Console]::In.ReadToEnd() | ConvertFrom-Json -AsHashtable -Depth 100
. $payload.runtime_module
$parseTokens = $null; $parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile(
    $payload.wrapper_path, [ref]$parseTokens, [ref]$parseErrors)
if (@($parseErrors).Count -ne 0) { throw "WRAPPER_PARSE_ERRORS" }
# Import only literal authority constants and the five pure validators.
# The operation-lock, identity creation, process execution, and writes cannot run.
foreach ($name in @("ExpectedDesignSha256", "ExpectedRepairDesignSha256", "RepairId",
    "ExpectedSupervisorRefusalSha256", "ExpectedPredecessorPhysicalClosureSha256",
    "ExpectedQualificationFailureClosureSha256", "ExpectedBranchCompletenessAddendumSha256",
    "ExpectedL14ComponentReceiptJson")) {
    $nodes = @($ast.FindAll({ param($node)
        $node -is [Management.Automation.Language.AssignmentStatementAst] -and
        $node.Left.Extent.Text -ceq ('$script:' + $name)
    }, $true))
    if ($nodes.Count -ne 1) { throw "WRAPPER_CONSTANT_COUNT:$name" }
    . ([scriptblock]::Create($nodes[0].Extent.Text))
}
foreach ($name in @("Assert-R10fQualification", "Test-ExactJsonIntegerZero",
    "Assert-ZeroWorldReceipt", "Test-ExactJsonSourceValue", "Assert-ImplementationReceipt")) {
    $nodes = @($ast.FindAll({ param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -ceq $name
    }, $true))
    if ($nodes.Count -ne 1) { throw "WRAPPER_FUNCTION_COUNT:$name" }
    . ([scriptblock]::Create($nodes[0].Extent.Text))
}
$accepted = 0; $rejected = 0
foreach ($case in $payload.cases) {
    $failureCode = $null
    try { Assert-ImplementationReceipt -Receipt $case.receipt -Source $payload.source -Policy $payload.policy }
    catch { $failureCode = $_.Exception.Message }
    if ($case.accept) {
        if ($null -ne $failureCode) { throw "WRAPPER_POSITIVE:$($case.id):$failureCode" }
        $accepted++
    } else {
        if ($null -eq $failureCode) { throw "WRAPPER_MUTATION_ACCEPTED:$($case.id)" }
        if ($null -ne $case.code -and $case.code -cne $failureCode) {
            throw "WRAPPER_WRONG_REFUSAL:$($case.id):$failureCode"
        }
        $rejected++
    }
}
[ordered]@{ positive_control_count = $accepted; mutation_rejection_count = $rejected } |
    ConvertTo-Json -Compress
"""
    result = subprocess.run(
        ["pwsh", "-NoLogo", "-NoProfile", "-Command", script],
        input=json.dumps(payload, separators=(",", ":")),
        capture_output=True,
        text=True,
        encoding="utf-8",
        cwd=ROOT,
        timeout=60,
    )
    require(result.returncode == 0, f"WRAPPER_CONTRACT:{result.stdout}:{result.stderr}")
    proof = json.loads(result.stdout)
    require(
        proof == {"positive_control_count": 1, "mutation_rejection_count": 335},
        "WRAPPER_CONTRACT_COUNTS",
    )
    return {
        "ok": True,
        "schema_version": "sporespore_qsdk_r10f_qualification_receipt_contract_audit_v1",
        "validation_source": "actual_wrapper_ast_five_pure_functions",
        "development_fixture_projection": "source_authority_flags_only_in_memory",
        "actual_receipt_source_flags_preserved": True,
        "exact_retained_failure_rejected": True,
        "preserved_historical_corruption_count": 86,
        "l14_component_corruption_count": 176,
        "l14_authority_metadata_corruption_count": 6,
        "l14_runtime_corruption_count": 67,
        **proof,
        **dict.fromkeys((*ZERO_COUNTERS, "scene_tree_insertion_count"), 0),
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def _audit_l8_repair_design_retired(
    *, official_qualification: bool, source_commit: str
) -> dict[str, Any]:
    require(REPAIR_DESIGN_PATH.is_file(), "REPAIR_DESIGN_MISSING")
    require(
        REPAIR_DESIGN_PATH.stat().st_size == EXPECTED_REPAIR_DESIGN_BYTES,
        "REPAIR_DESIGN_BYTE_LENGTH",
    )
    require(
        sha256_file(REPAIR_DESIGN_PATH) == EXPECTED_REPAIR_DESIGN_SHA256,
        "REPAIR_DESIGN_SHA256",
    )
    design = json.loads(REPAIR_DESIGN_PATH.read_text(encoding="utf-8"))
    require(isinstance(design, dict), "REPAIR_DESIGN_NOT_OBJECT")
    predecessor = design.get("predecessor_design")
    consumed = design.get("consumed_l7_physical_closure")
    evidence = design.get("retained_l7_evidence")
    diagnosis = design.get("retained_diagnosis")
    change = design.get("controlled_change")
    frozen = design.get("frozen_behavioral_terms")
    envelope = design.get("bounded_execution_envelope")
    sequence = design.get("forward_authority_sequence")
    claim = design.get("claim_boundary")
    decision = design.get("decision")
    require(
        design.get("schema_version")
        == "sporespore_qsdk_r10f_l8_integer_valued_native_step_domain_successor_design_v1"
        and design.get("status") == "prospective_zero_world_implementation_authorized"
        and design.get("gate_id") == "QSDK-R10F"
        and design.get("repair_id") == REPAIR_ID
        and design.get("campaign_role") == "development_route_ghost"
        and design.get("question_class") == "development"
        and design.get("ledger_scope")
        == {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "prospective_successor_design",
            "question_class": "development",
        }
        and isinstance(predecessor, dict)
        and predecessor.get("path")
        == PREDECESSOR_REPAIR_DESIGN_PATH.relative_to(ROOT).as_posix()
        and predecessor.get("byte_length") == EXPECTED_PREDECESSOR_REPAIR_DESIGN_BYTES
        and predecessor.get("raw_sha256") == EXPECTED_PREDECESSOR_REPAIR_DESIGN_SHA256
        and predecessor.get("repair_id") == "QSDK-R10F-L7"
        and predecessor.get("superseded") is False
        and isinstance(consumed, dict)
        and consumed.get("path")
        == PREDECESSOR_PHYSICAL_CLOSURE_PATH.relative_to(ROOT).as_posix()
        and consumed.get("byte_length") == EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_BYTES
        and consumed.get("raw_sha256") == EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_SHA256
        and consumed.get("status")
        == "closed_consumed_invalid_or_incomplete_no_behavioral_conclusion"
        and consumed.get("classification")
        == "invalid_or_incomplete_no_behavioral_conclusion"
        and consumed.get("attempt_id") == "0485211cfa1049e6bdee374b406d0c32"
        and consumed.get("source_commit") == "a07514ce2ce14c870811c86f55b6c775be4789db"
        and consumed.get("stage_commit") == "db5d56cbaa4869920c5b38f2f0352da4b1630cda"
        and consumed.get("authority_commit")
        == "898c6ff2146bf8e19367b196a0a1d309c3d39bfa"
        and consumed.get("closure_audit_commit")
        == "63911dacda99c31dc67e7fbd7a4b2826b21e2483"
        and consumed.get("closure_commit") == "6151a27d65b89d206f99ea1c2fe54f5b725680b0"
        and consumed.get("authority_sha256")
        == "sha256:fe5241e8b3d90b2e2b3062830f887974353f1e71d9b9e46ed8e98430cb34fdc5"
        and consumed.get("failure_code")
        == "QSDK_R10F_L7_PRECONDITION_DISPOSITION_BUILD_INVALID"
        and consumed.get("inner_failure_code")
        == "QSDK_R10F_L7_DISPOSITION_BUILD_INVALID"
        and consumed.get("world_attempt_count") == 2
        and consumed.get("world_build_count") == 2
        and consumed.get("solver_step_count") == 2
        and consumed.get("global_lockstep_solver_frame_count") == 1
        and consumed.get("external_kick_application_count") == 0
        and consumed.get("behavior_evaluator_invocation_count") == 0
        and consumed.get("route_execution_valid") is False
        and consumed.get("scientific_outcome") == "none"
        and consumed.get("same_identity_rerun_permitted") is False
        and consumed.get("physical_acceptance_authority") is False
        and consumed.get("release_authority") is False,
        "REPAIR_DESIGN_IDENTITY_FIELDS",
    )
    require(
        isinstance(evidence, dict)
        and evidence.get("evidence_root")
        == "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r10f-development-route-ghost-fe5241e8b3d90b2e"
        and evidence.get("supervisor_result")
        == {
            "byte_length": 34725,
            "raw_sha256": "sha256:704d8964be6802ad4e5f5c9fa60595ebc50bf6ce5418fe8b4b778b2f77bc0e2c",
        }
        and evidence.get("attempt_identity")
        == {
            "byte_length": 1325,
            "raw_sha256": "sha256:dd3e534dd54d87ddae372afee8a0bab88867049313dc4fd6ccbfab9c373193e5",
        }
        and evidence.get("worker_stdout")
        == {
            "byte_length": 13330,
            "raw_sha256": "sha256:d2f2493177dde6bdba7304102e2728c31a65547b64e4500db4d401fa51fc96ed",
        }
        and evidence.get("worker_stderr")
        == {
            "byte_length": 0,
            "raw_sha256": "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
        }
        and evidence.get("engine_health_passed") is True
        and evidence.get("supervised_termination_passed") is True
        and evidence.get("pair_barrier_state_sha256")
        == "sha256:428602d7544fe17ac32b0d1d473b977ec29174b3dc6e281323f1ff3f30d5d899"
        and evidence.get("retained_disposition_sha256")
        == "sha256:b934db8de72250d32aff694ef196ac06dc74b07af67799211ed14aa2180375f2",
        "REPAIR_DESIGN_RETAINED_EVIDENCE",
    )
    require(
        isinstance(diagnosis, dict)
        and diagnosis.get("failing_builder_arm_id") == "matched_no_kick_continuation"
        and diagnosis.get("retained_disposition")
        == "nonterminal_last_completed_state_retained"
        and diagnosis.get("retained_global_semantic_step") == 1
        and diagnosis.get("recovery_memory_last_semantic_step_value") == 1.0
        and diagnosis.get("recovery_memory_last_semantic_step_runtime_kind")
        == "binary64"
        and diagnosis.get("disposition_recovery_step_global_semantic_step_value") == 1
        and diagnosis.get("disposition_recovery_step_global_semantic_step_runtime_kind")
        == "integer"
        and diagnosis.get("numeric_values_equal") is True
        and diagnosis.get(
            "canonical_content_digests_equal_for_integer_and_integer_valued_binary64"
        )
        is True
        and diagnosis.get("independent_retained_receipt_validation_passed") is True
        and diagnosis.get(
            "l7_validator_required_memory_last_semantic_step_variant_kind"
        )
        == "integer"
        and diagnosis.get("l7_validator_rejected_integer_valued_binary64") is True
        and diagnosis.get("semantic_step_mismatch_observed") is False
        and diagnosis.get("physical_parameter_failure_observed") is False
        and diagnosis.get("controller_failure_observed") is False
        and diagnosis.get("behavior_question_reached") is False
        and diagnosis.get("scientific_outcome") == "none",
        "REPAIR_DESIGN_DIAGNOSIS",
    )
    require(
        isinstance(change, dict)
        and change.get("mechanism") == "integer_valued_native_step_domain_validation_v1"
        and change.get("source_field") == "recovery_memory.last_semantic_step"
        and change.get("semantic_field_kind") == "discrete_monotonic_step_index"
        and isinstance(change.get("accepted_integer_variant"), str)
        and isinstance(change.get("accepted_binary64_variant"), str)
        and change.get("minimum_accepted_step") == 1
        and change.get("maximum_accepted_step") == 3842
        and change.get("preserve_original_source_number_kind_in_receipt") is True
        and change.get("physical_closure_must_independently_validate_number_kind")
        is True
        and all(
            change.get(key) is False
            for key in (
                "cast_or_rewrite_source_measurement_permitted",
                "canonical_digest_policy_changed",
                "other_discrete_fields_relaxed",
                "fractional_step_permitted",
                "nonfinite_step_permitted",
                "boolean_step_permitted",
                "string_step_permitted",
                "null_step_permitted",
                "out_of_domain_step_permitted",
                "mismatched_integer_valued_step_permitted",
                "outcome_derived_step_correction_permitted",
                "body_transform_or_velocity_write_permitted",
                "solver_reset_permitted",
            )
        ),
        "REPAIR_DESIGN_CONTROLLED_CHANGE",
    )
    require(
        isinstance(frozen, dict)
        and frozen.get("physical_body_population")
        == "exact recovery-native S169 nine-body eight-hinge world"
        and frozen.get("recovery_controller_id")
        == "sporespore_exact_s169_prone_to_standing_controller_v6"
        and frozen.get("walking_policy_id") == "sporespore_balanced_wave_v1"
        and frozen.get("walking_policy_profile") == "BW5R-B"
        and frozen.get("campaign_seed") == 40200
        and frozen.get("physics_ticks_per_second") == 120
        and frozen.get("jolt_velocity_steps") == 20
        and frozen.get("jolt_position_steps") == 7
        and frozen.get("kick_impulse_magnitude_n_s") == 0.25
        and frozen.get("maximum_precondition_recovery_controller_steps") == 1200
        and frozen.get("walking_prefix_steps") == 720
        and frozen.get("maximum_confirm_prone_steps") == 60
        and frozen.get("required_consecutive_prone_samples") == 12
        and frozen.get("maximum_post_kick_recovery_epoch_steps") == 1200
        and frozen.get("walking_resume_steps") == 720
        and frozen.get("maximum_solver_steps_per_arm") == 3842
        and frozen.get("maximum_total_solver_steps") == 7684
        and all(
            frozen.get(key) is False
            for key in (
                "threshold_values_changed",
                "policy_changed",
                "controller_changed",
                "model_or_material_changed",
                "kick_changed",
                "seed_changed",
                "evaluator_changed",
                "physical_schedule_changed",
                "solver_budget_changed",
            )
        ),
        "REPAIR_DESIGN_FROZEN_TERMS",
    )
    require(
        isinstance(envelope, dict)
        and envelope.get("maximum_development_campaign_attempt_count") == 1
        and envelope.get("maximum_world_count") == 2
        and envelope.get("maximum_solver_steps_per_arm") == 3842
        and envelope.get("maximum_total_solver_steps") == 7684
        and envelope.get("solver_budget_delta_from_l7") == 0
        and envelope.get("held_out_cells_accessible") is False
        and envelope.get("same_identity_rerun_permitted") is False,
        "REPAIR_DESIGN_EXECUTION_ENVELOPE",
    )
    require(
        design.get("required_positive_zero_world_controls")
        == [
            "exact_integer_memory_step_still_accepted",
            "exact_integer_valued_binary64_memory_step_accepted",
            "native_shaped_first_step_binary64_disposition_builds",
            "original_binary64_source_kind_retained_without_rewrite",
            "integer_and_binary64_forms_bind_the_same_expected_step",
            "all_existing_l7_terminal_disposition_positive_controls_still_pass",
        ]
        and design.get("required_negative_zero_world_controls")
        == [
            "fractional_binary64_step_refused",
            "nan_step_refused",
            "positive_infinity_step_refused",
            "negative_infinity_step_refused",
            "zero_step_refused",
            "negative_step_refused",
            "step_above_declared_route_domain_refused",
            "integer_valued_binary64_not_equal_to_expected_step_refused",
            "boolean_step_refused",
            "string_step_refused",
            "null_step_refused",
            "missing_step_refused",
            "source_number_rewrite_refused",
            "nested_receipt_or_memory_digest_mismatch_refused",
            "outcome_derived_step_correction_refused",
            "all_existing_l7_terminal_disposition_negative_controls_still_pass",
        ],
        "REPAIR_DESIGN_ZERO_WORLD_CONTROLS",
    )
    require(
        isinstance(sequence, dict)
        and sequence.get("ordered_steps")
        == [
            "commit_and_push_l8_successor_design",
            "implement_exact_integer_valued_native_step_validation_and_complete_zero_world_controls",
            "commit_and_push_l8_source",
            "run_one_official_l8_zero_world_qualification",
            "commit_and_push_l8_freeze_only_child",
            "commit_and_push_l8_execution_authority_only_child",
            "pass_l8_committed_graph_check",
            "run_at_most_one_l8_two_world_development_route_ghost",
            "close_and_preserve_l8_result",
        ]
        and sequence.get("physical_execution_authorized_by_design") is False
        and sequence.get("held_out_finite_decision_authorized") is False
        and isinstance(claim, dict)
        and claim.get("design_complete") is True
        and claim.get("retained_diagnosis_complete_for_successor_selection") is True
        and claim.get("exact_l7_builder_rejection_reason_known") is True
        and claim.get("zero_world_implementation_authorized") is True
        and claim.get("physical_execution_authorized") is False
        and claim.get("event_triggered_passive_recovery_observed") is False
        and claim.get("continuous_same_body_recovery_resume_observed") is False
        and claim.get("force_aware_recovery") is False
        and claim.get("force_aware_bracing") is False
        and claim.get("arbitrary_fall_recovery") is False
        and claim.get("cross_engine_push_recovery") is False
        and claim.get("physical_acceptance_authority") is False
        and claim.get("release_authority") is False
        and claim.get("sdk1_m07_satisfied") is False
        and claim.get("q_sdk_r10_satisfied") is False
        and claim.get("scores_changed") is False
        and isinstance(decision, dict)
        and decision.get("selected_successor_gate_id") == "QSDK-R10F"
        and decision.get("selected_repair_id") == REPAIR_ID
        and decision.get("selected_successor_kind")
        == "integer_valued_native_step_domain_repair"
        and isinstance(decision.get("next_required_work"), str),
        "REPAIR_DESIGN_AUTHORITY_AND_CLAIM_BOUNDARY",
    )
    for binding, path, code in (
        (
            predecessor,
            PREDECESSOR_REPAIR_DESIGN_PATH,
            "REPAIR_DESIGN_PREDECESSOR_L7",
        ),
        (
            consumed,
            PREDECESSOR_PHYSICAL_CLOSURE_PATH,
            "REPAIR_DESIGN_CONSUMED_L7",
        ),
    ):
        require(
            binding.get("byte_length") == path.stat().st_size
            and binding.get("raw_sha256") == sha256_file(path),
            f"{code}_IDENTITY",
        )
    if official_qualification:
        relative = REPAIR_DESIGN_PATH.relative_to(ROOT).as_posix()
        require(
            git_text(
                ("rev-parse", f"{source_commit}:{relative}"),
                "REPAIR_DESIGN_SOURCE_BLOB",
            )
            == git_text(("hash-object", str(REPAIR_DESIGN_PATH)), "REPAIR_DESIGN_BLOB"),
            "REPAIR_DESIGN_SOURCE_BLOB",
        )
    return {
        "path": REPAIR_DESIGN_PATH.relative_to(ROOT).as_posix(),
        "byte_length": REPAIR_DESIGN_PATH.stat().st_size,
        "raw_sha256": EXPECTED_REPAIR_DESIGN_SHA256,
        "repair_id": REPAIR_ID,
        "positive_control_count": 6,
        "negative_control_count": 16,
        "minimum_accepted_step": 1,
        "maximum_accepted_step": 3842,
        "maximum_solver_steps_per_arm": 3842,
        "maximum_total_solver_steps": 7684,
        "source_number_kind_preserved": True,
        "physical_execution_authorized": False,
    }


def _audit_l9_repair_design_retired(
    *, official_qualification: bool, source_commit: str
) -> dict[str, Any]:
    """Validate the immutable L9 topology-only successor declaration."""
    require(REPAIR_DESIGN_PATH.is_file(), "L9_REPAIR_DESIGN_MISSING")
    require(
        REPAIR_DESIGN_PATH.stat().st_size == EXPECTED_REPAIR_DESIGN_BYTES,
        "L9_REPAIR_DESIGN_BYTE_LENGTH",
    )
    require(
        sha256_file(REPAIR_DESIGN_PATH) == EXPECTED_REPAIR_DESIGN_SHA256,
        "L9_REPAIR_DESIGN_SHA256",
    )
    design = json.loads(REPAIR_DESIGN_PATH.read_text(encoding="utf-8"))
    require(isinstance(design, dict), "L9_REPAIR_DESIGN_NOT_OBJECT")
    question = design.get("question_declaration")
    bindings_value = design.get("bound_authorities")
    retained = design.get("retained_l8_result")
    diagnosis = design.get("retained_diagnosis")
    rejected = design.get("rejected_repairs")
    change = design.get("controlled_change")
    frozen = design.get("unchanged_scientific_terms")
    population = design.get("prospective_development_population")
    controls = design.get("required_zero_world_controls")
    sequence = design.get("forward_authority_sequence")
    claim = design.get("claim_boundary")
    decision = design.get("decision")
    require(
        design.get("schema_version")
        == "sporespore_qsdk_r10f_l9_process_isolated_matched_arm_successor_design_v1"
        and design.get("status")
        == (
            "prospective_zero_world_successor_design_complete_"
            "implementation_authorized_physics_blocked"
        )
        and design.get("gate_id") == "QSDK-R10F"
        and design.get("repair_id") == REPAIR_ID
        and design.get("parent_repair_id") == "QSDK-R10F-L8"
        and design.get("design_id")
        == "QSDK-R10F-L9-PROCESS-ISOLATED-MATCHED-ARM-EXECUTION"
        and design.get("ledger_scope")
        == {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": (
                "retained_evidence_diagnosis_and_prospective_successor_design"
            ),
            "question_class": "development",
        },
        "L9_REPAIR_DESIGN_IDENTITY",
    )
    require(
        isinstance(question, dict)
        and question.get("scientific_question_changed_from_r10f") is False
        and question.get("development_question_declared") is True
        and all(
            question.get(field) is False
            for field in (
                "finite_decision_declared",
                "superiority_question_declared",
                "equivalence_or_non_inferiority_question_declared",
                "population_inference_declared",
                "physical_question_declared",
                "physical_execution_authorized",
            )
        )
        and all(
            question.get(field) == 0
            for field in (
                "maximum_world_attempt_count_before_complete_new_authority_graph",
                "maximum_world_build_count_before_complete_new_authority_graph",
                "maximum_solver_step_count_before_complete_new_authority_graph",
            )
        ),
        "L9_REPAIR_DESIGN_QUESTION_BOUNDARY",
    )

    require(isinstance(bindings_value, list), "L9_BOUND_AUTHORITIES_NOT_ARRAY")
    bindings = {
        value.get("role"): value
        for value in bindings_value
        if isinstance(value, dict) and isinstance(value.get("role"), str)
    }
    require(
        len(bindings_value) == 6 and len(bindings) == 6,
        "L9_BOUND_AUTHORITIES_ROLE_SET",
    )
    expected_current_bindings = {
        "consumed_l8_physical_closure": (
            PREDECESSOR_PHYSICAL_CLOSURE_PATH,
            EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_BYTES,
            EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_SHA256,
        ),
        "consumed_l6_physical_closure": (
            ROOT / "sdk/qsdk_r10f_development_route_ghost_physical_closure_v7.json",
            5_154,
            "sha256:842af3fab4aa80d1cea43e5a59391978708206174362837c9aeb99ca417d9517",
        ),
        "consumed_r172_serial_godot_recovery_positive": (
            ROOT / "sdk/recovery/"
            "r24d172_godot_jolt_initializer_receipt_retention_recovery_behavior_"
            "physical_closure_v1.json",
            29_920,
            "sha256:87b0c9497ab4fa91da8d58f9cba1be9ab906a0d2603cedd5b8abc92231f36fe8",
        ),
        "r10f_parent_design": (
            DESIGN_PATH,
            EXPECTED_DESIGN_BYTES,
            EXPECTED_DESIGN_SHA256,
        ),
        "l8_repair_design": (
            PREDECESSOR_REPAIR_DESIGN_PATH,
            EXPECTED_PREDECESSOR_REPAIR_DESIGN_BYTES,
            EXPECTED_PREDECESSOR_REPAIR_DESIGN_SHA256,
        ),
    }
    for role, (path, byte_length, digest) in expected_current_bindings.items():
        binding = bindings.get(role)
        require(
            isinstance(binding, dict)
            and path.is_file()
            and binding.get("path") == path.relative_to(ROOT).as_posix()
            and binding.get("byte_length") == byte_length == path.stat().st_size
            and binding.get("raw_sha256") == digest == sha256_file(path)
            and binding.get("git_blob_oid")
            == git_text(("hash-object", str(path)), f"L9_{role.upper()}_BLOB"),
            f"L9_BOUND_AUTHORITY_{role.upper()}",
        )
    observed = bindings.get("observed_l8_worker_source")
    observed_path = "tests/test_sdk_qsdk_r10f_continuous_passive_recovery_worker.gd"
    require(
        isinstance(observed, dict)
        and observed.get("path") == observed_path
        and observed.get("source_commit") == "31434a606c2c1fb644796b4b546730a18234b652"
        and observed.get("git_blob_oid")
        == git_text(
            ("rev-parse", f"{observed['source_commit']}:{observed_path}"),
            "L9_OBSERVED_L8_WORKER_BLOB",
        )
        and observed.get("byte_length") == 212_530
        and observed.get("raw_sha256")
        == "sha256:22395f30dc3401e58e3c9ef88c24eb9f30b954c3503cc2f8a980532f91c357e8",
        "L9_OBSERVED_L8_WORKER_IDENTITY",
    )

    require(
        isinstance(retained, dict)
        and retained.get("attempt_id") == "2f418dc12e934bf1a10add729f3554fe"
        and retained.get("status")
        == "closed_consumed_invalid_or_incomplete_no_behavioral_conclusion"
        and retained.get("failure_code")
        == "QSDK_R10F_PRECONDITION_TERMINAL_DISPOSITION_RETAINED"
        and retained.get("source_commit") == "31434a606c2c1fb644796b4b546730a18234b652"
        and retained.get("world_attempt_count") == 2
        and retained.get("world_build_count") == 2
        and retained.get("solver_step_count") == 600
        and retained.get("global_solver_frame_count") == 300
        and retained.get("external_kick_application_count") == 0
        and retained.get("behavior_evaluator_invocation_count") == 0
        and retained.get("route_execution_valid") is False
        and retained.get("scientific_outcome") == "none"
        and retained.get("same_identity_rerun_permitted") is False,
        "L9_RETAINED_L8_RESULT",
    )
    require(
        isinstance(diagnosis, dict)
        and diagnosis.get("l8_native_step_domain_repair_succeeded") is True
        and diagnosis.get("l8_first_invalid_native_step_field") is None
        and diagnosis.get("l8_precondition_terminal_population_retained") is True
        and diagnosis.get("l8_baseline_arm", {}).get("construction_index") == 1
        and diagnosis.get("l8_baseline_arm", {}).get("disposition")
        == "complete_source_retained"
        and diagnosis.get("l8_baseline_arm", {}).get("terminal_global_step") == 240
        and diagnosis.get("l8_active_arm", {}).get("construction_index") == 2
        and diagnosis.get("l8_active_arm", {}).get("disposition")
        == "failed_source_retained"
        and diagnosis.get("l8_active_arm", {}).get("terminal_global_step") == 300
        and diagnosis.get("l8_active_arm", {}).get("terminal_failure_code")
        == "phase_timeout:stance_dwell"
        and diagnosis.get("l6_reproduction", {}).get(
            "l6_and_l8_baseline_terminal_memory_exact_json_equal"
        )
        is True
        and diagnosis.get("r172_comparison", {}).get(
            "r172_candidate_and_l8_first_built_baseline_terminal_memory_exact_json_equal"
        )
        is True
        and diagnosis.get("r172_comparison", {}).get("repeatability_established")
        is False
        and diagnosis.get("r172_comparison", {}).get(
            "engine_causal_mechanism_established"
        )
        is False
        and diagnosis.get("source_topology", {}).get(
            "both_worlds_stepped_during_the_same_process_physics_schedule"
        )
        is True
        and diagnosis.get("source_topology", {}).get("cross_arm_collision_possible")
        is False,
        "L9_RETAINED_DIAGNOSIS",
    )
    require(
        isinstance(rejected, dict)
        and all(value is False for key, value in rejected.items() if key != "reason")
        and isinstance(rejected.get("reason"), str),
        "L9_REJECTED_REPAIRS",
    )
    require(
        isinstance(change, dict)
        and change.get("change_class") == "execution_topology_only"
        and change.get("ordered_child_roles")
        == ["matched_no_kick_continuation", "kick_passive_recovery_resume"]
        and all(
            change.get(field) is True
            for field in (
                "one_world_per_child_process",
                "one_arm_per_child_process",
                "one_physics_space_per_child_process",
                "each_child_starts_from_a_fresh_process",
                "parent_attempt_identity_consumed_before_first_child_launch",
                "child_attempt_ids_derived_and_retained_before_each_child_launch",
                "all_declared_children_run_despite_an_earlier_behavioral_negative",
            )
        )
        and all(
            change.get(field) is False
            for field in (
                "child_processes_overlap_in_wall_clock_time",
                "world_or_body_state_transferred_between_children",
                "global_solver_step_values_rewritten_for_pair_alignment",
                "shared_contact_or_solver_state_required",
                "child_replacement_after_failure_permitted",
                "same_identity_child_retry_permitted",
                "model_or_world_reuse_across_children",
                "threshold_changed",
                "controller_changed",
                "selected_policy_changed",
                "morphology_changed",
                "material_changed",
                "actuator_profile_changed",
                "kick_changed",
                "seed_changed",
                "behavior_evaluator_terms_changed",
                "outcome_derived_correction",
            )
        ),
        "L9_CONTROLLED_CHANGE",
    )
    require(
        isinstance(frozen, dict)
        and frozen.get("development_seed") == 40200
        and frozen.get("recovery_controller_id")
        == "sporespore_exact_s169_prone_to_standing_controller_v6"
        and frozen.get("selected_policy_id") == "sporespore_balanced_wave_bw5r_b_v1"
        and frozen.get("physics_ticks_per_second") == 120
        and frozen.get("kick_api") == "RigidBody3D.apply_central_impulse"
        and frozen.get("kick_task_frame_impulse_n_s") == [0.0, 0.0, 0.25]
        and frozen.get("active_kick_application_count") == 1
        and frozen.get("baseline_kick_application_count") == 0
        and frozen.get("maximum_solver_steps_per_arm") == 3842
        and frozen.get("maximum_total_solver_steps") == 7684
        and all(
            frozen.get(field) is False
            for field in (
                "post_construction_transform_writes_permitted",
                "post_construction_velocity_writes_permitted",
                "solver_reset_permitted",
                "force_aware_recovery",
                "force_aware_bracing",
                "kick_impulse_alone_causes_fall_claimed",
            )
        ),
        "L9_UNCHANGED_SCIENTIFIC_TERMS",
    )
    require(
        isinstance(population, dict)
        and population.get("campaign_role") == "development_route_ghost"
        and population.get("question_class") == "development"
        and population.get("maximum_campaign_attempt_count") == 1
        and population.get("ordered_arm_count") == 2
        and population.get("maximum_child_process_count") == 2
        and population.get("maximum_world_attempt_count_per_child") == 1
        and population.get("maximum_world_build_count_per_child") == 1
        and population.get("maximum_total_world_attempt_count") == 2
        and population.get("maximum_total_world_build_count") == 2
        and population.get("maximum_solver_step_count_per_child") == 3842
        and population.get("maximum_total_solver_step_count") == 7684
        and population.get("held_out_cell_access_count") == 0
        and population.get("behavioral_success_required_for_route_validity") is False
        and population.get(
            "complete_valid_behavior_negative_counts_as_a_successful_route_ghost"
        )
        is True
        and population.get("both_child_reports_required_for_any_pair_outcome") is True
        and population.get(
            "any_invalid_or_incomplete_child_forces_no_behavioral_conclusion"
        )
        is True
        and population.get("positive_development_result_advances_m07") is False,
        "L9_DEVELOPMENT_POPULATION",
    )
    require(
        isinstance(controls, dict)
        and len(controls.get("aggregate_supervisor", [])) == 9
        and len(controls.get("single_arm_worker", [])) == 8
        and len(controls.get("pair_evaluator", [])) == 6
        and len(controls.get("negative_controls", [])) == 17
        and controls.get("all_zero_world_processes_must_report")
        == {
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "scene_tree_insertion_count": 0,
            "native_readback_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        "L9_REQUIRED_ZERO_WORLD_CONTROLS",
    )
    require(
        sequence
        == [
            "implement the process-isolated child worker, aggregate supervisor, pair evaluator, dependency closure, materializer, and closer",
            "run development-only zero-world tests and the full composed zero-world audit with every physical counter zero",
            "commit and push one clean L9 source identity",
            "run exactly one official L9 zero-world qualification from that source identity",
            "commit only the content-addressed L9 stage freeze",
            "commit only the single-use L9 execution authority",
            "verify source, freeze, authority, local HEAD, origin/main, live GitHub main, and clean worktree equality",
            "run at most one serialized two-child development route-ghost identity",
            "independently close the consumed result before selecting any successor",
        ],
        "L9_FORWARD_AUTHORITY_SEQUENCE",
    )
    require(
        isinstance(claim, dict)
        and claim.get("l8_closed") is True
        and claim.get("l8_same_identity_rerun_permitted") is False
        and claim.get("l8_native_step_domain_repair_verified_on_physical_path") is True
        and claim.get("multi_space_execution_topology_confounded") is True
        and claim.get("exact_engine_causal_mechanism_established") is False
        and claim.get("godot_or_jolt_bug_claimed") is False
        and claim.get("l9_implementation_authorized") is True
        and claim.get("l9_physical_execution_authorized") is False
        and claim.get("r10f_behavior_observed") is False
        and claim.get("q_sdk_r10_satisfied") is False
        and claim.get("sdk1_m07_satisfied") is False
        and claim.get("sdk1_score") == "14/20"
        and claim.get("full_program_score") == "14/25"
        and claim.get("force_aware_recovery") is False
        and claim.get("arbitrary_fall_recovery_claimed") is False
        and claim.get("cross_engine_push_recovery_claimed") is False
        and claim.get("cross_engine_equivalence_claimed") is False
        and claim.get("physical_acceptance_authority") is False
        and claim.get("release_authority") is False
        and isinstance(decision, dict)
        and decision.get("selected_next_repair_id") == REPAIR_ID
        and decision.get("selected_next_action")
        == "implement_and_zero_world_qualify_process_isolated_matched_arm_execution"
        and decision.get("physical_execution_authorized_by_this_design") is False,
        "L9_CLAIM_AND_DECISION_BOUNDARY",
    )
    if official_qualification:
        relative = REPAIR_DESIGN_PATH.relative_to(ROOT).as_posix()
        require(
            git_text(
                ("rev-parse", f"{source_commit}:{relative}"),
                "L9_REPAIR_DESIGN_SOURCE_BLOB",
            )
            == git_text(
                ("hash-object", str(REPAIR_DESIGN_PATH)), "L9_REPAIR_DESIGN_BLOB"
            ),
            "L9_REPAIR_DESIGN_SOURCE_IDENTITY",
        )
    return {
        "path": REPAIR_DESIGN_PATH.relative_to(ROOT).as_posix(),
        "byte_length": REPAIR_DESIGN_PATH.stat().st_size,
        "raw_sha256": EXPECTED_REPAIR_DESIGN_SHA256,
        "repair_id": REPAIR_ID,
        "bound_authority_count": len(bindings),
        "aggregate_supervisor_control_count": 9,
        "single_arm_worker_control_count": 8,
        "pair_evaluator_control_count": 6,
        "required_mutation_control_count": 17,
        "maximum_child_process_count": 2,
        "maximum_world_count_per_child": 1,
        "maximum_total_world_count": 2,
        "maximum_solver_steps_per_child": 3842,
        "maximum_total_solver_steps": 7684,
        "physical_execution_authorized": False,
    }


def _audit_l10_repair_design_retired(
    *, official_qualification: bool, source_commit: str
) -> dict[str, Any]:
    """Validate the immutable L10 nullable consumer-only successor declaration."""
    require(REPAIR_DESIGN_PATH.is_file(), "L10_REPAIR_DESIGN_MISSING")
    require(
        REPAIR_DESIGN_PATH.stat().st_size == EXPECTED_REPAIR_DESIGN_BYTES,
        "L10_REPAIR_DESIGN_BYTE_LENGTH",
    )
    require(
        sha256_file(REPAIR_DESIGN_PATH) == EXPECTED_REPAIR_DESIGN_SHA256,
        "L10_REPAIR_DESIGN_SHA256",
    )
    design = json.loads(REPAIR_DESIGN_PATH.read_text(encoding="utf-8"))
    require(isinstance(design, dict), "L10_REPAIR_DESIGN_NOT_OBJECT")
    require(
        set(design)
        == {
            "schema_version",
            "status",
            "gate_id",
            "repair_id",
            "parent_repair_id",
            "design_id",
            "authored_parent_commit",
            "authored_local_date",
            "ledger_scope",
            "question_declaration",
            "bound_authorities",
            "retained_l9_result",
            "retained_diagnosis",
            "rejected_repairs",
            "controlled_change",
            "frozen_behavioral_terms",
            "required_positive_zero_world_controls",
            "required_negative_zero_world_controls",
            "prospective_development_population",
            "forward_authority_sequence",
            "claim_boundary",
            "decision",
        },
        "L10_REPAIR_DESIGN_KEYS",
    )
    require(
        design.get("schema_version")
        == "sporespore_qsdk_r10f_l10_nullable_terminal_failure_code_successor_design_v1"
        and design.get("status")
        == (
            "prospective_zero_world_successor_design_complete_"
            "implementation_authorized_physics_blocked"
        )
        and design.get("gate_id") == "QSDK-R10F"
        and design.get("repair_id") == REPAIR_ID
        and design.get("parent_repair_id") == "QSDK-R10F-L9"
        and design.get("design_id")
        == "QSDK-R10F-L10-NULLABLE-TERMINAL-FAILURE-CODE-PROJECTION"
        and design.get("authored_parent_commit")
        == "bccca500a6fd04850a8183b91db40e02e0941aff"
        and design.get("authored_local_date") == "2026-09-05"
        and design.get("ledger_scope")
        == {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": (
                "retained_evidence_diagnosis_and_prospective_successor_design"
            ),
            "question_class": "development",
        },
        "L10_REPAIR_DESIGN_IDENTITY",
    )
    question = design.get("question_declaration")
    require(
        isinstance(question, dict)
        and isinstance(question.get("question"), str)
        and bool(question["question"])
        and question.get("scientific_question_changed_from_r10f") is False
        and question.get("development_question_declared") is True
        and all(
            question.get(field) is False
            for field in (
                "finite_decision_declared",
                "superiority_question_declared",
                "equivalence_or_non_inferiority_question_declared",
                "population_inference_declared",
                "physical_question_declared",
                "physical_execution_authorized",
            )
        )
        and all(
            question.get(field) == 0
            for field in (
                "maximum_world_attempt_count_before_complete_new_authority_graph",
                "maximum_world_build_count_before_complete_new_authority_graph",
                "maximum_solver_step_count_before_complete_new_authority_graph",
            )
        ),
        "L10_REPAIR_DESIGN_QUESTION_BOUNDARY",
    )
    bindings_value = design.get("bound_authorities")
    require(isinstance(bindings_value, list), "L10_BOUND_AUTHORITIES_NOT_ARRAY")
    bindings = {
        value.get("role"): value
        for value in bindings_value
        if isinstance(value, dict) and isinstance(value.get("role"), str)
    }
    require(
        len(bindings_value) == len(bindings) == 6
        and set(bindings)
        == {
            "consumed_l9_physical_closure",
            "l9_process_isolation_design",
            "observed_l9_worker_source",
            "observed_l9_child_contract_source",
            "nullable_recovery_memory_type_authority",
            "existing_nullable_terminal_disposition_precedent",
        },
        "L10_BOUND_AUTHORITY_ROLE_SET",
    )
    for role, path, byte_length, digest in (
        (
            "consumed_l9_physical_closure",
            PREDECESSOR_PHYSICAL_CLOSURE_PATH,
            EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_BYTES,
            EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_SHA256,
        ),
        (
            "l9_process_isolation_design",
            PREDECESSOR_REPAIR_DESIGN_PATH,
            EXPECTED_PREDECESSOR_REPAIR_DESIGN_BYTES,
            EXPECTED_PREDECESSOR_REPAIR_DESIGN_SHA256,
        ),
        (
            "nullable_recovery_memory_type_authority",
            ROOT / "sdk/core/src/recovery.rs",
            240_774,
            "sha256:9ab3a478e7fbfb610b5110ddce90879f7f1c19006462fa5916a205a8053399c2",
        ),
        (
            "existing_nullable_terminal_disposition_precedent",
            ROOT / "sdk/adapters/godot/gdscript/"
            "qsdk_r10f_precondition_terminal_disposition_v1.gd",
            57_614,
            "sha256:5eed448efef2992047b69720d9e8eb655f1ee97964fac8bf2abdea76301995e3",
        ),
    ):
        binding = bindings[role]
        require(
            path.is_file()
            and binding.get("path") == path.relative_to(ROOT).as_posix()
            and binding.get("byte_length") == byte_length == path.stat().st_size
            and binding.get("raw_sha256") == digest == sha256_file(path)
            and binding.get("git_blob_oid")
            == git_text(("hash-object", str(path)), f"L10_{role.upper()}_BLOB"),
            f"L10_BOUND_AUTHORITY_{role.upper()}",
        )
    for role, relative, historical_commit, blob_oid, byte_length, digest in (
        (
            "observed_l9_worker_source",
            "tests/test_sdk_qsdk_r10f_continuous_passive_recovery_worker.gd",
            "c94a596e731a1899f6e798fe8e9ec0b9e74c9cbc",
            "917e47b67fc9fffe5c1397d424ed4b2639c220b9",
            249_592,
            "sha256:8e547ee4cce43e79e1e01be50eaf6cfa8941c07c174c9085fc7b2746308424f5",
        ),
        (
            "observed_l9_child_contract_source",
            "sdk/adapters/godot/gdscript/qsdk_r10f_process_isolated_child_contract_v1.gd",
            "c94a596e731a1899f6e798fe8e9ec0b9e74c9cbc",
            "815224bc8513887bf8c49151f1f7eb169f14206b",
            49_995,
            "sha256:419f1d6360829a6bb99c6b69b768524a21580c8ed33d2440c9977ece9c3cea59",
        ),
    ):
        binding = bindings[role]
        require(
            binding.get("path") == relative
            and binding.get("source_commit") == historical_commit
            and binding.get("git_blob_oid") == blob_oid
            and binding.get("checkout_byte_length") == byte_length
            and binding.get("checkout_raw_sha256") == digest
            and git_text(
                ("rev-parse", f"{historical_commit}:{relative}"),
                f"L10_{role.upper()}_HISTORICAL_BLOB",
            )
            == blob_oid,
            f"L10_BOUND_AUTHORITY_{role.upper()}",
        )
    retained = design.get("retained_l9_result")
    diagnosis = design.get("retained_diagnosis")
    require(
        isinstance(retained, dict)
        and retained.get("attempt_id") == "3207ba0528264944b01aefd0640fd616"
        and retained.get("status")
        == "closed_consumed_invalid_or_incomplete_no_behavioral_conclusion"
        and retained.get("failure_code")
        == "QSDK_R10F_L9_PROCESS_POPULATION_VALIDATION_FAILED"
        and retained.get("source_commit") == "c94a596e731a1899f6e798fe8e9ec0b9e74c9cbc"
        and retained.get("observed_child_process_count") == 1
        and retained.get("model_construction_count") == 1
        and retained.get("world_attempt_count") == 1
        and retained.get("world_build_count") == 1
        and retained.get("solver_step_count") == 240
        and retained.get("external_kick_application_count") == 0
        and retained.get("behavior_evaluator_invocation_count") == 0
        and retained.get("route_execution_valid") is False
        and retained.get("scientific_outcome") == "none"
        and retained.get("same_identity_rerun_permitted") is False
        and isinstance(diagnosis, dict)
        and diagnosis.get("engine_fatal_function")
        == "build_precondition_terminal_receipt_v1"
        and diagnosis.get("retained_terminal_memory", {}).get("phase") == "complete"
        and diagnosis.get("retained_terminal_memory", {}).get("terminal_failure_code")
        is None
        and diagnosis.get("producer_invariant")
        == "failed or refused phase if and only if terminal_failure_code is present"
        and diagnosis.get("zero_world_fixture_shape_gap_established") is True
        and diagnosis.get("active_child_process_started") is False
        and diagnosis.get("behavior_question_reached") is False
        and diagnosis.get("scientific_outcome") == "none",
        "L10_RETAINED_L9_DIAGNOSIS",
    )
    rejected = design.get("rejected_repairs")
    require(
        isinstance(rejected, dict)
        and all(value is False for key, value in rejected.items() if key != "reason")
        and isinstance(rejected.get("reason"), str),
        "L10_REJECTED_REPAIRS",
    )
    change = design.get("controlled_change")
    require(
        isinstance(change, dict)
        and change.get("change_class")
        == "terminal_receipt_consumer_representation_only"
        and change.get("mechanism") == "nullable_terminal_failure_code_projection_v1"
        and change.get("source_field") == "recovery_memory.terminal_failure_code"
        and change.get("source_domain") == ["null", "nonempty String"]
        and change.get("nested_recovery_memory_retained_without_mutation") is True
        and change.get("source_nullness_independently_revalidated") is True
        and all(
            change.get(field) is False
            for field in (
                "generic_string_conversion_permitted",
                "receipt_key_set_changed",
                "receipt_schema_version_changed",
                "canonical_digest_policy_changed",
                "body_transform_or_velocity_write_permitted",
                "solver_reset_permitted",
                "process_isolation_changed",
                "child_order_changed",
                "threshold_changed",
                "controller_changed",
                "selected_policy_changed",
                "morphology_changed",
                "material_changed",
                "actuator_profile_changed",
                "kick_changed",
                "seed_changed",
                "physical_schedule_changed",
                "solver_budget_changed",
                "behavior_evaluator_terms_changed",
                "outcome_derived_correction",
            )
        ),
        "L10_CONTROLLED_CHANGE",
    )
    frozen = design.get("frozen_behavioral_terms")
    population = design.get("prospective_development_population")
    require(
        isinstance(frozen, dict)
        and frozen.get("ordered_child_roles")
        == ["matched_no_kick_continuation", "kick_passive_recovery_resume"]
        and frozen.get("one_arm_per_child_process") is True
        and frozen.get("one_world_per_child_process") is True
        and frozen.get("child_processes_overlap_in_wall_clock_time") is False
        and frozen.get("development_seed") == 40200
        and frozen.get("physics_ticks_per_second") == 120
        and frozen.get("maximum_child_process_count") == 2
        and frozen.get("maximum_world_count_per_child") == 1
        and frozen.get("maximum_total_world_count") == 2
        and frozen.get("maximum_solver_steps_per_child") == 3842
        and frozen.get("maximum_total_solver_steps") == 7684
        and frozen.get("force_aware_recovery") is False
        and frozen.get("force_aware_bracing") is False
        and isinstance(population, dict)
        and population.get("campaign_role") == "development_route_ghost"
        and population.get("question_class") == "development"
        and population.get("maximum_campaign_attempt_count") == 1
        and population.get("maximum_child_process_count") == 2
        and population.get("maximum_total_world_attempt_count") == 2
        and population.get("maximum_total_world_build_count") == 2
        and population.get("maximum_solver_step_count_per_child") == 3842
        and population.get("maximum_total_solver_step_count") == 7684
        and population.get("held_out_cell_access_count") == 0
        and population.get("behavioral_success_required_for_route_validity") is False
        and population.get(
            "complete_valid_behavior_negative_counts_as_a_successful_route_ghost"
        )
        is True
        and population.get("both_child_reports_required_for_any_pair_outcome") is True
        and population.get(
            "any_invalid_or_incomplete_child_forces_no_behavioral_conclusion"
        )
        is True
        and population.get("positive_development_result_advances_m07") is False,
        "L10_FROZEN_POPULATION",
    )
    positives = design.get("required_positive_zero_world_controls")
    negatives = design.get("required_negative_zero_world_controls")
    require(
        isinstance(positives, list)
        and len(positives) == 7
        and len(set(positives)) == 7
        and positives[-1]
        == "all_existing_l9_process_isolated_child_positive_controls_still_pass"
        and isinstance(negatives, list)
        and len(negatives) == 17
        and len(set(negatives)) == 17
        and negatives[-1]
        == "all_existing_l9_process_isolated_child_negative_controls_still_pass",
        "L10_ZERO_WORLD_CONTROL_DECLARATION",
    )
    sequence = design.get("forward_authority_sequence")
    claim = design.get("claim_boundary")
    decision = design.get("decision")
    require(
        isinstance(sequence, dict)
        and len(sequence.get("ordered_steps", [])) == 10
        and sequence.get("physical_execution_authorized_by_design") is False
        and sequence.get("held_out_finite_decision_authorized") is False
        and isinstance(claim, dict)
        and claim.get("design_complete") is True
        and claim.get("retained_diagnosis_complete_for_successor_selection") is True
        and claim.get("exact_l9_failure_source_known") is True
        and claim.get("zero_world_implementation_authorized") is True
        and all(
            claim.get(field) is False
            for field in (
                "physical_execution_authorized",
                "event_triggered_passive_recovery_observed",
                "continuous_same_body_recovery_resume_observed",
                "force_aware_recovery",
                "force_aware_bracing",
                "arbitrary_fall_recovery",
                "cross_engine_push_recovery",
                "physical_acceptance_authority",
                "release_authority",
                "sdk1_m07_satisfied",
                "q_sdk_r10_satisfied",
                "scores_changed",
            )
        )
        and isinstance(decision, dict)
        and decision.get("selected_successor_gate_id") == "QSDK-R10F"
        and decision.get("selected_repair_id") == REPAIR_ID
        and decision.get("selected_successor_kind")
        == "nullable_terminal_failure_code_consumer_repair",
        "L10_AUTHORITY_AND_CLAIM_BOUNDARY",
    )
    if official_qualification:
        relative = REPAIR_DESIGN_PATH.relative_to(ROOT).as_posix()
        require(
            git_text(
                ("rev-parse", f"{source_commit}:{relative}"),
                "L10_REPAIR_DESIGN_SOURCE_BLOB",
            )
            == git_text(
                ("hash-object", str(REPAIR_DESIGN_PATH)), "L10_REPAIR_DESIGN_BLOB"
            ),
            "L10_REPAIR_DESIGN_SOURCE_IDENTITY",
        )
    return {
        "path": REPAIR_DESIGN_PATH.relative_to(ROOT).as_posix(),
        "byte_length": REPAIR_DESIGN_PATH.stat().st_size,
        "raw_sha256": EXPECTED_REPAIR_DESIGN_SHA256,
        "repair_id": REPAIR_ID,
        "change_class": "terminal_receipt_consumer_representation_only",
        "bound_authority_count": len(bindings),
        "positive_control_count": len(positives),
        "mutation_rejection_count": len(negatives),
        "maximum_child_process_count": 2,
        "maximum_world_count_per_child": 1,
        "maximum_total_world_count": 2,
        "maximum_solver_steps_per_child": 3842,
        "maximum_total_solver_steps": 7684,
        "nested_recovery_memory_retained_without_mutation": True,
        "generic_string_conversion_permitted": False,
        "physical_execution_authorized": False,
    }


def _audit_l12_repair_design_retired(
    *, official_qualification: bool, source_commit: str
) -> dict[str, Any]:
    """Retained L12 validator; superseded by the active L13 validator below."""
    require(REPAIR_DESIGN_PATH.is_file(), "L12_REPAIR_DESIGN_MISSING")
    require(
        REPAIR_DESIGN_PATH.stat().st_size == EXPECTED_REPAIR_DESIGN_BYTES,
        "L12_REPAIR_DESIGN_BYTE_LENGTH",
    )
    require(
        sha256_file(REPAIR_DESIGN_PATH) == EXPECTED_REPAIR_DESIGN_SHA256,
        "L12_REPAIR_DESIGN_SHA256",
    )
    design = json.loads(REPAIR_DESIGN_PATH.read_text(encoding="utf-8"))
    require(isinstance(design, dict), "L12_REPAIR_DESIGN_NOT_OBJECT")
    require(
        set(design)
        == {
            "schema_version",
            "status",
            "gate_id",
            "repair_id",
            "parent_repair_id",
            "design_id",
            "authored_parent_commit",
            "authored_local_date",
            "ledger_scope",
            "question_declaration",
            "bound_authorities",
            "retained_l11_result",
            "retained_l11_release_boundary",
            "retained_diagnosis",
            "rejected_repairs",
            "controlled_change",
            "frozen_behavioral_terms",
            "required_positive_zero_world_controls",
            "required_negative_zero_world_controls",
            "prospective_development_population",
            "forward_authority_sequence",
            "claim_boundary",
            "decision",
        },
        "L12_REPAIR_DESIGN_KEYS",
    )
    require(
        design.get("schema_version")
        == "sporespore_qsdk_r10f_l12_walking_actuation_handoff_successor_design_v1"
        and design.get("status")
        == (
            "prospective_zero_world_successor_design_complete_"
            "implementation_authorized_physics_blocked"
        )
        and design.get("gate_id") == "QSDK-R10F"
        and design.get("repair_id") == REPAIR_ID
        and design.get("parent_repair_id") == "QSDK-R10F-L11"
        and design.get("design_id")
        == "QSDK-R10F-L12-WALKING-ACTUATION-OWNERSHIP-HANDOFF"
        and design.get("authored_parent_commit")
        == "55e5fe7d6a73e13e9eacf13c46e21a23a66d43c4"
        and design.get("authored_local_date") == "2026-09-05"
        and design.get("ledger_scope")
        == {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": (
                "retained_evidence_diagnosis_and_prospective_successor_design"
            ),
            "question_class": "development",
        },
        "L12_REPAIR_DESIGN_IDENTITY",
    )
    question = design.get("question_declaration")
    require(
        isinstance(question, dict)
        and isinstance(question.get("question"), str)
        and bool(question["question"])
        and question.get("scientific_question_changed_from_r10f") is False
        and question.get("development_question_declared") is True
        and all(
            question.get(field) is False
            for field in (
                "finite_decision_declared",
                "superiority_question_declared",
                "equivalence_or_non_inferiority_question_declared",
                "population_inference_declared",
                "physical_question_declared",
                "physical_execution_authorized",
            )
        )
        and all(
            exact_int(question.get(field), 0)
            for field in (
                "maximum_world_attempt_count_before_complete_new_authority_graph",
                "maximum_world_build_count_before_complete_new_authority_graph",
                "maximum_solver_step_count_before_complete_new_authority_graph",
            )
        ),
        "L12_REPAIR_DESIGN_QUESTION_BOUNDARY",
    )

    authorities_value = design.get("bound_authorities")
    require(isinstance(authorities_value, list), "L12_BOUND_AUTHORITIES_NOT_ARRAY")
    authorities = {
        value.get("role"): value
        for value in authorities_value
        if isinstance(value, dict) and isinstance(value.get("role"), str)
    }
    require(
        len(authorities_value) == len(authorities) == 8
        and set(authorities)
        == {
            "consumed_l11_physical_closure",
            "l11_release_owner_projection_design",
            "qualified_r69_host_cap_projection_contract",
            "qualified_r69_zero_world_projection_population",
            "observed_l11_worker_source",
            "observed_l11_locomotion_facade_source",
            "observed_l11_shared_walking_adapter_source",
            "observed_l11_recovery_world_host_cap_source",
        },
        "L12_BOUND_AUTHORITY_ROLE_SET",
    )
    immutable_authorities = {
        "consumed_l11_physical_closure": (
            PREDECESSOR_PHYSICAL_CLOSURE_PATH,
            8_654,
            EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_SHA256,
        ),
        "l11_release_owner_projection_design": (
            PREDECESSOR_REPAIR_DESIGN_PATH,
            17_978,
            EXPECTED_PREDECESSOR_REPAIR_DESIGN_SHA256,
        ),
        "qualified_r69_host_cap_projection_contract": (
            ROOT
            / "sdk/recovery/r24d69_godot_native_effective_impulse_limit_contract_v1.json",
            30_329,
            "sha256:457822e8873b6f6e1e335c5b08b78c10d3948046206d7939608170ab5c36929d",
        ),
        "qualified_r69_zero_world_projection_population": (
            ROOT
            / (
                "sdk/recovery/r24d69_godot_native_effective_impulse_limit_"
                "zero_world_qualification_closure_v1.json"
            ),
            20_793,
            "sha256:0199a964d408eefb2d8d0610f729ff867d3eb29e8830709b7b5a7d90108f0811",
        ),
    }
    for role, (path, byte_length, digest) in immutable_authorities.items():
        binding = authorities[role]
        require(
            path.is_file()
            and binding.get("path") == path.relative_to(ROOT).as_posix()
            and exact_int(binding.get("byte_length"), byte_length)
            and path.stat().st_size == byte_length
            and binding.get("raw_sha256") == digest == sha256_file(path)
            and binding.get("git_blob_oid")
            == git_text(("hash-object", str(path)), f"L12_{role.upper()}_BLOB"),
            f"L12_BOUND_AUTHORITY_{role.upper()}",
        )
    historical_authorities = {
        "observed_l11_worker_source": (
            "tests/test_sdk_qsdk_r10f_continuous_passive_recovery_worker.gd",
            "5c13fb1c50b1aa24d0e63456c6dd6bdacce86015",
            247_924,
            "sha256:3ba329cac5fe6a08c5e677b0054c31a29e5b07e98fd9983878d0995b0f81eabc",
        ),
        "observed_l11_locomotion_facade_source": (
            "sdk/adapters/godot/gdscript/"
            "qsdk_r10f_recovery_native_locomotion_facade_v1.gd",
            "2615ba0921675fecaeff0f9d59c7cf392a8b3e13",
            50_498,
            "sha256:1b6c2632fd996eca6497e74ac6b348fc10395fdbadc8f412659cdb64075f7eff",
        ),
        "observed_l11_shared_walking_adapter_source": (
            "scripts/lab/gait/sdk_godot_jolt_adapter.gd",
            "ef793ede82d63ee266ee815f2b0dd19866ef9596",
            331_602,
            "sha256:10679c11476f9b83cd23205580313caba9b348e1bee2bb8473189f8f05f61e63",
        ),
        "observed_l11_recovery_world_host_cap_source": (
            "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd",
            "c418010d7dd22baf00af8ad6f4cd9f0b870957f0",
            605_131,
            "sha256:c7b84a7fd0c59904e0f9619dfd0fa4ed559d3fd370ad2b54601e4948c3ac751a",
        ),
    }
    for role, (relative, blob, byte_length, digest) in historical_authorities.items():
        binding = authorities[role]
        historical_commit = "02f7b554a29ed80ad55d9d21930f23a267c07273"
        require(
            binding.get("path") == relative
            and binding.get("source_commit") == historical_commit
            and binding.get("git_blob_oid") == blob
            and exact_int(binding.get("checkout_byte_length"), byte_length)
            and binding.get("checkout_raw_sha256") == digest
            and git_text(
                ("rev-parse", f"{historical_commit}:{relative}"),
                f"L12_{role.upper()}_HISTORICAL_BLOB",
            )
            == blob,
            f"L12_BOUND_AUTHORITY_{role.upper()}",
        )

    retained = design.get("retained_l11_result")
    release = design.get("retained_l11_release_boundary")
    diagnosis = design.get("retained_diagnosis")
    require(
        isinstance(retained, dict)
        and retained.get("attempt_id") == "977175976c09461c9fac94dd23e6ab21"
        and retained.get("first_child_attempt_id") == "7bae4d8af5484fcabe27bd7e3e60c427"
        and retained.get("source_commit") == "02f7b554a29ed80ad55d9d21930f23a267c07273"
        and retained.get("stage_commit") == "487584fc851bf6825e7c7de919e6c777fa71215b"
        and retained.get("authority_commit")
        == "f0fb74e29d1064ade3d817933d7835ca4927998c"
        and exact_int(retained.get("world_attempt_count"), 1)
        and exact_int(retained.get("world_build_count"), 1)
        and exact_int(retained.get("solver_step_count"), 241)
        and exact_int(retained.get("external_kick_application_count"), 0)
        and exact_int(retained.get("behavior_evaluator_invocation_count"), 0)
        and retained.get("physical_identity_consumed") is True
        and retained.get("same_identity_rerun_permitted") is False
        and retained.get("scientific_outcome") == "none"
        and isinstance(release, dict)
        and exact_int(release.get("completed_precondition_terminal_step"), 240)
        and exact_int(release.get("release_step"), 241)
        and release.get("release_receipt_payload_sha256")
        == "sha256:02c0c62c1133f8f58b35815df256b332606f073a999b8149a4febca085a5b489"
        and release.get("release_owner_source_payload_sha256")
        == "sha256:bf1d1256cd2e0ec9947d7019412627a85c287f9c83b5ea7d8aa3d82dc70a11fc"
        and exact_int(release.get("released_motor_count"), 8)
        and exact_int(release.get("released_motor_enabled_count"), 0)
        and exact_int(release.get("released_zero_target_velocity_count"), 8)
        and release.get("l11_release_owner_projection_passed_runtime_boundary") is True
        and isinstance(diagnosis, dict)
        and retained.get("first_child_outer_failure_code")
        == "QSDK_R10F_L9_CHILD_NEXT_FRAME_PLAN_INVALID"
        and retained.get("first_child_inner_failure_code")
        == "QSDK_R10F_LOCOMOTION_MOTOR_READBACK_INVALID:front_left_hip"
        and diagnosis.get("l11_release_receipt_built_and_validated") is True
        and diagnosis.get("release_left_all_motor_flags_disabled") is True
        and diagnosis.get("walking_session_start_enables_motor_flags") is False
        and diagnosis.get(
            "live_host_caps_exactly_match_qualified_r69_selected_host_caps"
        )
        is True
        and diagnosis.get("facade_current_apply_authority_override_is_empty") is True
        and diagnosis.get("first_walking_solver_step_completed") is False
        and diagnosis.get("kick_applied") is False
        and diagnosis.get("behavior_question_reached") is False
        and diagnosis.get("scientific_outcome") == "none",
        "L12_RETAINED_L11_DIAGNOSIS",
    )

    rejected = design.get("rejected_repairs")
    require(
        isinstance(rejected, dict)
        and all(value is False for key, value in rejected.items() if key != "reason")
        and isinstance(rejected.get("reason"), str)
        and bool(rejected["reason"]),
        "L12_REJECTED_REPAIRS",
    )
    change = design.get("controlled_change")
    require(
        isinstance(change, dict)
        and change.get("change_class")
        == "r10f_walking_actuation_ownership_handoff_and_existing_host_cap_binding_only"
        and change.get("mechanism") == "walking_actuation_ownership_handoff_v1"
        and change.get("covered_evaluation_segments")
        == ["walking_prefix", "matched_continuation", "walking_resume"]
        and change.get("covered_facade_segment_ids")
        == ["walking_prefix", "walking_resume"]
        and exact_int(change.get("motor_enable_write_count_per_fresh_session"), 8)
        and exact_int(change.get("zero_target_write_count_per_fresh_session"), 8)
        and exact_int(change.get("handoff_solver_step_count"), 0)
        and change.get("existing_complete_override_interface_used") is True
        and all(
            change.get(field) is False
            for field in (
                "extra_solver_step_inserted",
                "release_step_changed",
                "release_motors_disabled_invariant_changed",
                "shared_adapter_enable_behavior_changed",
                "shared_adapter_cap_resolution_behavior_changed",
                "published_actuator_profile_changed",
                "published_cap_changed",
                "selected_host_cap_changed_from_r69",
                "native_effective_projection_changed",
                "new_tolerance_or_margin_added",
                "raw_measurement_clamped",
                "l11_release_receipt_schema_changed",
                "body_transform_or_velocity_write_permitted",
                "body_impulse_write_permitted_by_handoff",
                "solver_reset_permitted",
                "process_isolation_changed",
                "child_order_changed",
                "threshold_changed",
                "controller_changed",
                "selected_policy_changed",
                "morphology_changed",
                "material_changed",
                "actuator_profile_changed",
                "kick_changed",
                "seed_changed",
                "physical_schedule_changed",
                "solver_budget_changed",
                "behavior_evaluator_terms_changed",
                "outcome_derived_correction",
            )
        ),
        "L12_CONTROLLED_CHANGE",
    )
    frozen = design.get("frozen_behavioral_terms")
    population = design.get("prospective_development_population")
    require(
        isinstance(frozen, dict)
        and frozen.get("ordered_child_roles")
        == ["matched_no_kick_continuation", "kick_passive_recovery_resume"]
        and frozen.get("one_arm_per_child_process") is True
        and frozen.get("one_world_per_child_process") is True
        and exact_int(frozen.get("development_seed"), 40200)
        and exact_int(frozen.get("physics_ticks_per_second"), 120)
        and exact_int(frozen.get("maximum_child_process_count"), 2)
        and exact_int(frozen.get("maximum_world_count_per_child"), 1)
        and exact_int(frozen.get("maximum_total_world_count"), 2)
        and exact_int(frozen.get("maximum_solver_steps_per_child"), 3842)
        and exact_int(frozen.get("maximum_total_solver_steps"), 7684)
        and frozen.get("force_aware_recovery") is False
        and frozen.get("force_aware_bracing") is False
        and isinstance(population, dict)
        and population.get("campaign_role") == "development_route_ghost"
        and population.get("question_class") == "development"
        and exact_int(population.get("maximum_campaign_attempt_count"), 1)
        and exact_int(population.get("maximum_child_process_count"), 2)
        and exact_int(population.get("maximum_total_world_attempt_count"), 2)
        and exact_int(population.get("maximum_total_world_build_count"), 2)
        and exact_int(population.get("maximum_solver_step_count_per_child"), 3842)
        and exact_int(population.get("maximum_total_solver_step_count"), 7684)
        and exact_int(population.get("held_out_cell_access_count"), 0),
        "L12_FROZEN_POPULATION",
    )
    positives = design.get("required_positive_zero_world_controls")
    negatives = design.get("required_negative_zero_world_controls")
    require(
        isinstance(positives, list)
        and len(positives) == len(set(positives)) == 13
        and isinstance(negatives, list)
        and len(negatives) == len(set(negatives)) == 19,
        "L12_ZERO_WORLD_CONTROL_DECLARATION",
    )
    sequence = design.get("forward_authority_sequence")
    claim = design.get("claim_boundary")
    decision = design.get("decision")
    require(
        isinstance(sequence, dict)
        and len(sequence.get("ordered_steps", [])) == 13
        and sequence.get("physical_execution_authorized_by_design") is False
        and sequence.get("held_out_finite_decision_authorized") is False
        and isinstance(claim, dict)
        and claim.get("design_complete") is True
        and claim.get("retained_diagnosis_complete_for_successor_selection") is True
        and claim.get("exact_l11_observed_failure_source_known") is True
        and claim.get("l11_release_owner_projection_crossed_runtime_boundary") is True
        and claim.get("l11_release_step_completed") is True
        and claim.get("motor_enable_handoff_missing_in_l11") is True
        and claim.get("host_cap_composition_gap_deterministically_established") is True
        and claim.get("r69_projection_requalified_or_changed") is False
        and claim.get("zero_world_implementation_authorized") is True
        and all(
            claim.get(field) is False
            for field in (
                "physical_execution_authorized",
                "event_triggered_passive_recovery_observed",
                "continuous_same_body_recovery_resume_observed",
                "force_aware_recovery",
                "force_aware_bracing",
                "arbitrary_fall_recovery",
                "cross_engine_push_recovery",
                "physical_acceptance_authority",
                "release_authority",
                "sdk1_m07_satisfied",
                "q_sdk_r10_satisfied",
                "scores_changed",
            )
        )
        and isinstance(decision, dict)
        and decision.get("selected_successor_gate_id") == "QSDK-R10F"
        and decision.get("selected_repair_id") == REPAIR_ID
        and decision.get("selected_successor_kind")
        == (
            "r10f_walking_actuation_ownership_handoff_"
            "with_qualified_host_cap_binding"
        ),
        "L12_AUTHORITY_AND_CLAIM_BOUNDARY",
    )
    if official_qualification:
        relative = REPAIR_DESIGN_PATH.relative_to(ROOT).as_posix()
        require(
            git_text(
                ("rev-parse", f"{source_commit}:{relative}"),
                "L12_REPAIR_DESIGN_SOURCE_BLOB",
            )
            == git_text(
                ("hash-object", str(REPAIR_DESIGN_PATH)),
                "L12_REPAIR_DESIGN_BLOB",
            ),
            "L12_REPAIR_DESIGN_SOURCE_IDENTITY",
        )
    return {
        "path": REPAIR_DESIGN_PATH.relative_to(ROOT).as_posix(),
        "byte_length": REPAIR_DESIGN_PATH.stat().st_size,
        "raw_sha256": EXPECTED_REPAIR_DESIGN_SHA256,
        "repair_id": REPAIR_ID,
        "change_class": (
            "r10f_walking_actuation_ownership_handoff_and_existing_host_cap_binding_only"
        ),
        "bound_authority_count": len(authorities),
        "declared_positive_control_count": len(positives),
        "declared_mutation_rejection_count": len(negatives),
        "walking_actuation_handoff_positive_control_count": 5,
        "walking_actuation_handoff_mutation_rejection_count": 22,
        "qualified_r69_projection_count": 8,
        "covered_evaluation_segments": [
            "walking_prefix",
            "matched_continuation",
            "walking_resume",
        ],
        "maximum_child_process_count": 2,
        "maximum_world_count_per_child": 1,
        "maximum_total_world_count": 2,
        "maximum_solver_steps_per_child": 3842,
        "maximum_total_solver_steps": 7684,
        "shared_adapter_enable_behavior_changed": False,
        "published_actuator_profile_changed": False,
        "extra_solver_step_inserted": False,
        "physical_execution_authorized": False,
    }


def audit_repair_design(
    *, official_qualification: bool, source_commit: str
) -> dict[str, Any]:
    """Bind the unchanged L14 base design; permission is not qualification."""
    # The source binding is required even during development. These immutable
    # declarations must already be committed before implementation can qualify.
    try:
        return l14_authority.repair_design_binding(source_commit)
    except (ValueError, OSError, subprocess.SubprocessError) as exc:
        raise AuditFailure(f"L14_REPAIR_DESIGN:{exc}") from exc


def audit_branch_completeness_addendum(source_commit: str) -> dict[str, Any]:
    """Require the separately approved scope, never infer it from the base."""
    try:
        return l14_authority.branch_completeness_addendum_binding(source_commit)
    except (ValueError, OSError, subprocess.SubprocessError) as exc:
        raise AuditFailure(f"L14_BRANCH_COMPLETENESS_ADDENDUM:{exc}") from exc


def audit_superseded_refusal(*, official_qualification: bool) -> dict[str, Any]:
    require(SUPERVISOR_REFUSAL_PATH.is_file(), "SUPERVISOR_REFUSAL_MISSING")
    require(
        SUPERVISOR_REFUSAL_PATH.stat().st_size == EXPECTED_SUPERVISOR_REFUSAL_BYTES,
        "SUPERVISOR_REFUSAL_BYTE_LENGTH",
    )
    require(
        sha256_file(SUPERVISOR_REFUSAL_PATH) == EXPECTED_SUPERVISOR_REFUSAL_SHA256,
        "SUPERVISOR_REFUSAL_SHA256",
    )
    refusal = json.loads(SUPERVISOR_REFUSAL_PATH.read_text(encoding="utf-8"))
    require(isinstance(refusal, dict), "SUPERVISOR_REFUSAL_NOT_OBJECT")
    source = refusal.get("source")
    boundary = refusal.get("execution_boundary")
    successor = refusal.get("successor_policy")
    claim = refusal.get("claim_boundary")
    bindings = refusal.get("authority_bindings")
    require(
        refusal.get("schema_version")
        == "sporespore_qsdk_r10f_physical_supervisor_refusal_v2"
        and refusal.get("status")
        == "closed_infrastructure_invalid_pre_physics_output_identity_unconsumed"
        and refusal.get("gate_id") == "QSDK-R10F"
        and refusal.get("repair_id") == "QSDK-R10F-L2"
        and refusal.get("campaign_role") == "development_route_ghost"
        and isinstance(source, dict)
        and source.get("source_commit") == "04a4b4aa68a7b466db6bc975fdec9295e7c280f8"
        and source.get("qualification_commit")
        == "e211187d08de8a57f57221fe8cf83250c5b331e0"
        and source.get("authorization_commit")
        == "fc3187f918c953b156b3036811709ef95227fc6c"
        and isinstance(boundary, dict)
        and boundary.get("physical_supervisor_invocation_count") == 1
        and boundary.get("operation_lock_acquisition_count") == 1
        and boundary.get("operation_lock_explicit_release_count") == 1
        and boundary.get("post_refusal_zero_world_preflight_passed") is True
        and boundary.get("durable_evidence_directory_created") is False
        and boundary.get("model_construction_count") == 0
        and boundary.get("world_attempt_count") == 0
        and boundary.get("world_build_count") == 0
        and boundary.get("scene_tree_insertion_count") == 0
        and boundary.get("native_readback_count") == 0
        and boundary.get("solver_step_count") == 0
        and boundary.get("locomotion_outcome_exposure_count") == 0
        and boundary.get("physics_state_modified") is False
        and boundary.get("physical_attempt_identity_consumed") is False
        and isinstance(successor, dict)
        and successor.get("repeat_failed_supervisor_invocation") is False
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
        and successor.get("seed_changed") is False
        and successor.get("population_changed") is False
        and isinstance(claim, dict)
        and claim.get("continuous_passive_fall_recovery_claimed") is False
        and claim.get("locomotion_negative_claimed") is False
        and claim.get("physical_acceptance_authority") is False
        and claim.get("release_authority") is False
        and isinstance(bindings, dict)
        and isinstance(bindings.get("predecessor_supervisor_refusal"), dict)
        and bindings["predecessor_supervisor_refusal"].get("raw_sha256")
        == "sha256:27528d78b217278700f5d1860046a2e5f7fc1e2324cef1a0239ffbd7859391e0"
        and bindings.get("authorized_output_root_absent_after_refusal") is True,
        "SUPERVISOR_REFUSAL_FIELDS",
    )
    for commit_key, tree_key in (
        ("source_commit", "source_tree_git_oid"),
        ("qualification_commit", "qualification_tree_git_oid"),
        ("authorization_commit", "authorization_tree_git_oid"),
    ):
        require(
            git_text(("rev-parse", f"{source[commit_key]}^{{tree}}"), commit_key)
            == source[tree_key],
            f"SUPERVISOR_REFUSAL_{commit_key.upper()}_TREE",
        )
    output_root = Path(str(bindings.get("authorized_output_root", "")))
    require(not output_root.exists(), "SUPERSEDED_PHYSICAL_OUTPUT_ROOT_EXISTS")
    if official_qualification:
        relative = SUPERVISOR_REFUSAL_PATH.relative_to(ROOT).as_posix()
        require(
            git_text(("rev-parse", f"HEAD:{relative}"), "REFUSAL_SOURCE_BLOB")
            == git_text(("hash-object", str(SUPERVISOR_REFUSAL_PATH)), "REFUSAL_BLOB"),
            "SUPERVISOR_REFUSAL_SOURCE_BLOB",
        )
    return {
        "path": SUPERVISOR_REFUSAL_PATH.relative_to(ROOT).as_posix(),
        "byte_length": SUPERVISOR_REFUSAL_PATH.stat().st_size,
        "raw_sha256": EXPECTED_SUPERVISOR_REFUSAL_SHA256,
        "status": refusal["status"],
        "repair_id": "QSDK-R10F-L2",
        "physical_attempt_identity_consumed": False,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
    }


def _audit_l7_predecessor_physical_closure_retired(
    *, official_qualification: bool, source_commit: str
) -> dict[str, Any]:
    require(
        PREDECESSOR_PHYSICAL_CLOSURE_PATH.is_file(),
        "PREDECESSOR_PHYSICAL_CLOSURE_MISSING",
    )
    require(
        PREDECESSOR_PHYSICAL_CLOSURE_PATH.stat().st_size
        == EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_BYTES,
        "PREDECESSOR_PHYSICAL_CLOSURE_BYTE_LENGTH",
    )
    require(
        sha256_file(PREDECESSOR_PHYSICAL_CLOSURE_PATH)
        == EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_SHA256,
        "PREDECESSOR_PHYSICAL_CLOSURE_SHA256",
    )
    closure = json.loads(PREDECESSOR_PHYSICAL_CLOSURE_PATH.read_text(encoding="utf-8"))
    require(isinstance(closure, dict), "PREDECESSOR_PHYSICAL_CLOSURE_NOT_OBJECT")
    bindings = closure.get("evidence_bindings")
    dispositions = closure.get("precondition_terminal_dispositions")
    require(
        closure.get("schema_version")
        == "sporespore_qsdk_r10f_development_route_ghost_physical_closure_v8"
        and closure.get("status")
        == "closed_consumed_invalid_or_incomplete_no_behavioral_conclusion"
        and closure.get("gate_id") == "QSDK-R10F"
        and closure.get("repair_id") == "QSDK-R10F-L7"
        and closure.get("campaign_role") == "development_route_ghost"
        and closure.get("classification")
        == "invalid_or_incomplete_no_behavioral_conclusion"
        and closure.get("source_commit") == "a07514ce2ce14c870811c86f55b6c775be4789db"
        and closure.get("stage_commit") == "db5d56cbaa4869920c5b38f2f0352da4b1630cda"
        and closure.get("authority_commit")
        == "898c6ff2146bf8e19367b196a0a1d309c3d39bfa"
        and closure.get("closure_audit_commit")
        == "63911dacda99c31dc67e7fbd7a4b2826b21e2483"
        and closure.get("authority_sha256")
        == "sha256:fe5241e8b3d90b2e2b3062830f887974353f1e71d9b9e46ed8e98430cb34fdc5"
        and closure.get("repair_design_sha256")
        == "sha256:1f1288acb506c39347e33ca6c6f0c86749caaf955f83dce71836cd8100f98c3b"
        and closure.get("superseded_physical_supervisor_refusal_sha256")
        == EXPECTED_SUPERVISOR_REFUSAL_SHA256
        and closure.get("consumed_predecessor_physical_closure_sha256")
        == "sha256:842af3fab4aa80d1cea43e5a59391978708206174362837c9aeb99ca417d9517"
        and closure.get("attempt_id") == "0485211cfa1049e6bdee374b406d0c32"
        and closure.get("failure_code")
        == "QSDK_R10F_L7_PRECONDITION_DISPOSITION_BUILD_INVALID"
        and closure.get("physical_identity_consumed") is True
        and closure.get("same_identity_rerun_permitted") is False
        and closure.get("route_execution_valid") is False
        and closure.get("evidence_valid") is False
        and closure.get("outcome_complete") is False
        and closure.get("behavior_passed") is False
        and closure.get("scientific_outcome") == "none"
        and closure.get("campaign_attempt_count") == 1
        and closure.get("maximum_campaign_attempt_count") == 1
        and closure.get("world_attempt_count") == 2
        and closure.get("world_build_count") == 2
        and closure.get("solver_step_count") == 2
        and closure.get("false_route_receipts") == []
        and closure.get("arm_projections") == {}
        and closure.get("precondition_pair_barrier") == {}
        and isinstance(dispositions, dict)
        and dispositions.get("validation_class")
        == "disposition_builder_number_kind_rejection"
        and dispositions.get("outer_failure_code")
        == "QSDK_R10F_L7_PRECONDITION_DISPOSITION_BUILD_INVALID"
        and dispositions.get("inner_failure_code")
        == "QSDK_R10F_L7_DISPOSITION_BUILD_INVALID"
        and dispositions.get("failing_arm_id") == "matched_no_kick_continuation"
        and dispositions.get("retained_disposition")
        == "nonterminal_last_completed_state_retained"
        and dispositions.get("pair_state_sha256")
        == "sha256:428602d7544fe17ac32b0d1d473b977ec29174b3dc6e281323f1ff3f30d5d899"
        and dispositions.get("global_semantic_step") == 1
        and dispositions.get("memory_last_semantic_step_json_kind") == "binary64"
        and dispositions.get("memory_last_semantic_step_numeric_value") == 1.0
        and dispositions.get("receipt_global_semantic_step_json_kind") == "integer"
        and dispositions.get("receipt_global_semantic_step_numeric_value") == 1
        and dispositions.get("numeric_values_equal") is True
        and dispositions.get("independent_receipt_validation_performed") is True
        and dispositions.get("summary_boolean_only") is False
        and closure.get("event_triggered_passive_recovery_observed") is False
        and closure.get("continuous_same_body_recovery_resume_observed") is False
        and closure.get("sdk1_m07_satisfied") is False
        and closure.get("physical_acceptance_authority") is False
        and closure.get("release_authority") is False
        and isinstance(bindings, dict),
        "PREDECESSOR_PHYSICAL_CLOSURE_FIELDS",
    )
    for key in (
        "supervisor_result",
        "attempt_identity",
        "worker_stdout",
        "worker_stderr",
        "execution_authority",
        "stage_freeze",
        "r10f_design",
        "l7_repair_design",
        "superseded_physical_supervisor_refusal",
        "consumed_predecessor_physical_closure",
    ):
        declared = bindings.get(key)
        require(isinstance(declared, dict), f"PREDECESSOR_BINDING_{key.upper()}")
        declared_path = Path(str(declared.get("path", "")))
        actual_path = (
            declared_path if declared_path.is_absolute() else ROOT / declared_path
        )
        require(actual_path.is_file(), f"PREDECESSOR_BINDING_{key.upper()}_MISSING")
        expected_path = (
            actual_path.as_posix()
            if declared_path.is_absolute()
            else actual_path.relative_to(ROOT).as_posix()
        )
        require(
            declared.get("path") == expected_path
            and declared.get("byte_length") == actual_path.stat().st_size
            and declared.get("raw_sha256") == sha256_file(actual_path),
            f"PREDECESSOR_BINDING_{key.upper()}_IDENTITY",
        )
    if official_qualification:
        relative = PREDECESSOR_PHYSICAL_CLOSURE_PATH.relative_to(ROOT).as_posix()
        require(
            git_text(
                ("rev-parse", f"{source_commit}:{relative}"),
                "PREDECESSOR_CLOSURE_SOURCE_BLOB",
            )
            == git_text(
                ("hash-object", str(PREDECESSOR_PHYSICAL_CLOSURE_PATH)),
                "PREDECESSOR_CLOSURE_BLOB",
            ),
            "PREDECESSOR_PHYSICAL_CLOSURE_SOURCE_BLOB",
        )
    return {
        "path": PREDECESSOR_PHYSICAL_CLOSURE_PATH.relative_to(ROOT).as_posix(),
        "byte_length": PREDECESSOR_PHYSICAL_CLOSURE_PATH.stat().st_size,
        "raw_sha256": EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_SHA256,
        "status": closure["status"],
        "repair_id": "QSDK-R10F-L7",
        "classification": closure["classification"],
        "attempt_id": closure["attempt_id"],
        "physical_identity_consumed": True,
        "same_identity_rerun_permitted": False,
        "world_attempt_count": 2,
        "world_build_count": 2,
        "solver_step_count": 2,
        "scientific_outcome": "none",
        "number_kind_diagnosis_independently_validated": True,
        "evidence_binding_count": 10,
    }


def _audit_l8_predecessor_physical_closure_retired(
    *, official_qualification: bool, source_commit: str
) -> dict[str, Any]:
    """Revalidate the consumed L8 record without reopening its identity."""
    require(
        PREDECESSOR_PHYSICAL_CLOSURE_PATH.is_file(),
        "L8_PREDECESSOR_CLOSURE_MISSING",
    )
    require(
        PREDECESSOR_PHYSICAL_CLOSURE_PATH.stat().st_size
        == EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_BYTES,
        "L8_PREDECESSOR_CLOSURE_BYTE_LENGTH",
    )
    require(
        sha256_file(PREDECESSOR_PHYSICAL_CLOSURE_PATH)
        == EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_SHA256,
        "L8_PREDECESSOR_CLOSURE_SHA256",
    )
    closure = json.loads(PREDECESSOR_PHYSICAL_CLOSURE_PATH.read_text(encoding="utf-8"))
    require(isinstance(closure, dict), "L8_PREDECESSOR_CLOSURE_NOT_OBJECT")
    dispositions = closure.get("precondition_terminal_dispositions")
    bindings = closure.get("evidence_bindings")
    require(
        closure.get("schema_version")
        == "sporespore_qsdk_r10f_development_route_ghost_physical_closure_v9"
        and closure.get("status")
        == "closed_consumed_invalid_or_incomplete_no_behavioral_conclusion"
        and closure.get("gate_id") == "QSDK-R10F"
        and closure.get("repair_id") == "QSDK-R10F-L8"
        and closure.get("campaign_role") == "development_route_ghost"
        and closure.get("classification")
        == "invalid_or_incomplete_no_behavioral_conclusion"
        and closure.get("source_commit") == "31434a606c2c1fb644796b4b546730a18234b652"
        and closure.get("stage_commit") == "b1545306291f51b6480b1923a356eeb7d0958589"
        and closure.get("authority_commit")
        == "9977d7aaccabd700b03e6e12a1a71335190bd907"
        and closure.get("closure_audit_commit")
        == "0b403136d47b84d3caad292eba74987828e9c763"
        and closure.get("authority_sha256")
        == "sha256:aed5ff88bdef57c3137cf957344f0e4655ab15ef42ce1e69557aa0fc943bab7d"
        and closure.get("repair_design_sha256")
        == EXPECTED_PREDECESSOR_REPAIR_DESIGN_SHA256
        and closure.get("superseded_physical_supervisor_refusal_sha256")
        == EXPECTED_SUPERVISOR_REFUSAL_SHA256
        and closure.get("consumed_predecessor_physical_closure_sha256")
        == "sha256:15cf3bdd5485405613726be8c800c5e46f4178a818ae89b947efc992e3094aba"
        and closure.get("attempt_id") == "2f418dc12e934bf1a10add729f3554fe"
        and closure.get("failure_code")
        == "QSDK_R10F_PRECONDITION_TERMINAL_DISPOSITION_RETAINED"
        and closure.get("physical_identity_consumed") is True
        and closure.get("same_identity_rerun_permitted") is False
        and closure.get("route_execution_valid") is False
        and closure.get("evidence_valid") is False
        and closure.get("outcome_complete") is False
        and closure.get("behavior_passed") is False
        and closure.get("scientific_outcome") == "none"
        and closure.get("campaign_attempt_count") == 1
        and closure.get("maximum_campaign_attempt_count") == 1
        and closure.get("world_attempt_count") == 2
        and closure.get("world_build_count") == 2
        and closure.get("solver_step_count") == 600
        and closure.get("false_route_receipts") == []
        and closure.get("arm_projections") == {}
        and closure.get("precondition_pair_barrier") == {}
        and closure.get("event_triggered_passive_recovery_observed") is False
        and closure.get("continuous_same_body_recovery_resume_observed") is False
        and closure.get("sdk1_m07_satisfied") is False
        and closure.get("physical_acceptance_authority") is False
        and closure.get("release_authority") is False
        and closure.get("ledger_scope")
        == {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "consumed_physical_campaign_closure",
            "question_class": "development",
        },
        "L8_PREDECESSOR_CLOSURE_FIELDS",
    )
    require(
        isinstance(dispositions, dict)
        and dispositions.get("global_semantic_step") == 300
        and dispositions.get("completed_wait_step_count_by_arm")
        == {
            "kick_passive_recovery_resume": 0,
            "matched_no_kick_continuation": 60,
        }
        and dispositions.get("expected_worker_extra_native_readback_count") == 1440
        and dispositions.get("disposition_by_arm")
        == {
            "matched_no_kick_continuation": "complete_source_retained",
            "kick_passive_recovery_resume": "failed_source_retained",
        }
        and dispositions.get("failing_arm_ids") == ["kick_passive_recovery_resume"]
        and dispositions.get("independent_population_validation_performed") is True
        and dispositions.get("summary_boolean_only") is False,
        "L8_PREDECESSOR_DISPOSITION_POPULATION",
    )
    expected_binding_keys = {
        "supervisor_result",
        "attempt_identity",
        "worker_stdout",
        "worker_stderr",
        "execution_authority",
        "stage_freeze",
        "r10f_design",
        "l8_repair_design",
        "superseded_physical_supervisor_refusal",
        "consumed_predecessor_physical_closure",
    }
    require(
        isinstance(bindings, dict) and set(bindings) == expected_binding_keys,
        "L8_PREDECESSOR_BINDING_SET",
    )
    for key in sorted(expected_binding_keys):
        declared = bindings[key]
        require(isinstance(declared, dict), f"L8_PREDECESSOR_BINDING_{key.upper()}")
        declared_path = Path(str(declared.get("path", "")))
        actual_path = (
            declared_path if declared_path.is_absolute() else ROOT / declared_path
        )
        require(actual_path.is_file(), f"L8_PREDECESSOR_BINDING_{key.upper()}_MISSING")
        expected_path = (
            actual_path.as_posix()
            if declared_path.is_absolute()
            else actual_path.relative_to(ROOT).as_posix()
        )
        require(
            declared.get("path") == expected_path
            and declared.get("byte_length") == actual_path.stat().st_size
            and declared.get("raw_sha256") == sha256_file(actual_path),
            f"L8_PREDECESSOR_BINDING_{key.upper()}_IDENTITY",
        )
    if official_qualification:
        relative = PREDECESSOR_PHYSICAL_CLOSURE_PATH.relative_to(ROOT).as_posix()
        require(
            git_text(
                ("rev-parse", f"{source_commit}:{relative}"),
                "L8_PREDECESSOR_SOURCE_BLOB",
            )
            == git_text(
                ("hash-object", str(PREDECESSOR_PHYSICAL_CLOSURE_PATH)),
                "L8_PREDECESSOR_LOCAL_BLOB",
            ),
            "L8_PREDECESSOR_SOURCE_IDENTITY",
        )
    return {
        "path": PREDECESSOR_PHYSICAL_CLOSURE_PATH.relative_to(ROOT).as_posix(),
        "byte_length": PREDECESSOR_PHYSICAL_CLOSURE_PATH.stat().st_size,
        "raw_sha256": EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_SHA256,
        "status": closure["status"],
        "repair_id": "QSDK-R10F-L8",
        "classification": closure["classification"],
        "attempt_id": closure["attempt_id"],
        "physical_identity_consumed": True,
        "same_identity_rerun_permitted": False,
        "world_attempt_count": 2,
        "world_build_count": 2,
        "solver_step_count": 600,
        "scientific_outcome": "none",
        "topology_confound_retained": True,
        "evidence_binding_count": len(expected_binding_keys),
    }


def _audit_l9_predecessor_physical_closure_retired_v2(
    *, official_qualification: bool, source_commit: str
) -> dict[str, Any]:
    """Reopen the immutable, consumed L9 instrumentation-invalid closure."""
    require(
        PREDECESSOR_PHYSICAL_CLOSURE_PATH.is_file(),
        "L9_PREDECESSOR_CLOSURE_MISSING",
    )
    require(
        PREDECESSOR_PHYSICAL_CLOSURE_PATH.stat().st_size
        == EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_BYTES,
        "L9_PREDECESSOR_CLOSURE_BYTE_LENGTH",
    )
    require(
        sha256_file(PREDECESSOR_PHYSICAL_CLOSURE_PATH)
        == EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_SHA256,
        "L9_PREDECESSOR_CLOSURE_SHA256",
    )
    closure = json.loads(PREDECESSOR_PHYSICAL_CLOSURE_PATH.read_text(encoding="utf-8"))
    process = closure.get("process_isolation")
    dispositions = closure.get("precondition_terminal_dispositions")
    bindings = closure.get("evidence_bindings")
    require(
        isinstance(closure, dict)
        and closure.get("schema_version")
        == "sporespore_qsdk_r10f_development_route_ghost_physical_closure_v10"
        and closure.get("status")
        == "closed_consumed_invalid_or_incomplete_no_behavioral_conclusion"
        and closure.get("gate_id") == "QSDK-R10F"
        and closure.get("repair_id") == "QSDK-R10F-L9"
        and closure.get("campaign_role") == "development_route_ghost"
        and closure.get("question_class") == "development"
        and closure.get("classification")
        == "invalid_or_incomplete_no_behavioral_conclusion"
        and closure.get("source_commit") == "c94a596e731a1899f6e798fe8e9ec0b9e74c9cbc"
        and closure.get("stage_commit") == "f82a527b99f5c3b2ed9c94e14853f759d30c9658"
        and closure.get("authority_commit")
        == "776cfd2f0a67c50676e8959312bae7ef1aa09bd3"
        and closure.get("closure_audit_commit")
        == "f567ff8ded5d7b78d8ccf853824e3c801efc7dea"
        and closure.get("attempt_id") == "3207ba0528264944b01aefd0640fd616"
        and closure.get("failure_code")
        == "QSDK_R10F_L9_PROCESS_POPULATION_VALIDATION_FAILED"
        and closure.get("physical_identity_consumed") is True
        and closure.get("same_identity_rerun_permitted") is False
        and closure.get("route_execution_valid") is False
        and closure.get("evidence_valid") is False
        and closure.get("measurement_complete") is False
        and closure.get("outcome_complete") is False
        and closure.get("behavior_passed") is False
        and closure.get("scientific_outcome") == "none"
        and closure.get("campaign_attempt_count") == 1
        and closure.get("observed_child_process_count") == 1
        and closure.get("model_construction_attempt_count") == 1
        and closure.get("model_construction_count") == 1
        and closure.get("world_attempt_count") == 1
        and closure.get("world_build_count") == 1
        and closure.get("solver_step_count") == 240
        and isinstance(process, dict)
        and process.get("ordered_declared_child_roles")
        == ["matched_no_kick_continuation", "kick_passive_recovery_resume"]
        and process.get("declared_child_count") == 2
        and process.get("observed_child_count") == 1
        and process.get("distinct_child_process_ids") is False
        and process.get("child_process_lifetimes_overlap") is None
        and process.get("child_retry_or_replacement_used") is False
        and closure.get("topology_validation_errors") == ["declared_child_missing"]
        and isinstance(dispositions, dict)
        and dispositions.get("disposition_by_arm") == {}
        and dispositions.get("precondition_negative_roles") == []
        and dispositions.get("independent_population_validation_performed") is True
        and dispositions.get("summary_boolean_only") is False
        and closure.get("event_triggered_passive_recovery_observed") is False
        and closure.get("continuous_same_body_recovery_resume_observed") is False
        and closure.get("force_aware_recovery") is False
        and closure.get("sdk1_m07_satisfied") is False
        and closure.get("physical_acceptance_authority") is False
        and closure.get("release_authority") is False
        and isinstance(bindings, dict),
        "L9_PREDECESSOR_CLOSURE_FIELDS",
    )
    require(
        set(bindings)
        == {
            "supervisor_result",
            "attempt_identity",
            "child_process_artifacts",
            "execution_authority",
            "stage_freeze",
            "r10f_design",
            "l9_repair_design",
            "superseded_physical_supervisor_refusal",
            "consumed_predecessor_physical_closure",
        },
        "L9_PREDECESSOR_BINDING_SET",
    )

    def verify_declared_binding(binding: Any, code: str) -> None:
        require(isinstance(binding, dict), f"{code}_NOT_OBJECT")
        declared_path = Path(str(binding.get("path", "")))
        actual_path = (
            declared_path if declared_path.is_absolute() else ROOT / declared_path
        )
        require(actual_path.is_file(), f"{code}_MISSING")
        require(
            binding.get("byte_length") == actual_path.stat().st_size
            and binding.get("raw_sha256") == sha256_file(actual_path),
            f"{code}_IDENTITY",
        )

    for key in (
        "supervisor_result",
        "attempt_identity",
        "execution_authority",
        "stage_freeze",
        "r10f_design",
        "l9_repair_design",
        "superseded_physical_supervisor_refusal",
        "consumed_predecessor_physical_closure",
    ):
        verify_declared_binding(bindings[key], f"L9_PREDECESSOR_{key.upper()}")
    child_artifacts = bindings["child_process_artifacts"]
    require(
        isinstance(child_artifacts, dict)
        and set(child_artifacts) == {"matched_no_kick_continuation"},
        "L9_PREDECESSOR_CHILD_ARTIFACT_SET",
    )
    baseline_artifacts = child_artifacts["matched_no_kick_continuation"]
    require(
        isinstance(baseline_artifacts, dict)
        and set(baseline_artifacts)
        == {
            "child_attempt_identity",
            "worker_stdout",
            "worker_stderr",
            "termination_receipt",
            "engine_health",
            "child_envelope",
            "worker_report",
        },
        "L9_PREDECESSOR_BASELINE_ARTIFACT_SET",
    )
    for key, value in baseline_artifacts.items():
        verify_declared_binding(value, f"L9_PREDECESSOR_CHILD_{key.upper()}")
    if official_qualification:
        relative = PREDECESSOR_PHYSICAL_CLOSURE_PATH.relative_to(ROOT).as_posix()
        require(
            git_text(
                ("rev-parse", f"{source_commit}:{relative}"),
                "L9_PREDECESSOR_CLOSURE_SOURCE_BLOB",
            )
            == git_text(
                ("hash-object", str(PREDECESSOR_PHYSICAL_CLOSURE_PATH)),
                "L9_PREDECESSOR_CLOSURE_BLOB",
            ),
            "L9_PREDECESSOR_CLOSURE_SOURCE_IDENTITY",
        )
    return {
        "path": PREDECESSOR_PHYSICAL_CLOSURE_PATH.relative_to(ROOT).as_posix(),
        "byte_length": PREDECESSOR_PHYSICAL_CLOSURE_PATH.stat().st_size,
        "raw_sha256": EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_SHA256,
        "status": closure["status"],
        "repair_id": "QSDK-R10F-L9",
        "classification": closure["classification"],
        "attempt_id": closure["attempt_id"],
        "physical_identity_consumed": True,
        "same_identity_rerun_permitted": False,
        "observed_child_process_count": 1,
        "world_attempt_count": 1,
        "world_build_count": 1,
        "solver_step_count": 240,
        "scientific_outcome": "none",
        "terminal_adapter_failure_retained": True,
    }


def _audit_l11_predecessor_physical_closure_retired(
    *, official_qualification: bool, source_commit: str
) -> dict[str, Any]:
    """Retained L11 closure validator; superseded by the L12 validator below."""
    require(
        PREDECESSOR_PHYSICAL_CLOSURE_PATH.is_file(),
        "L11_PREDECESSOR_CLOSURE_MISSING",
    )
    require(
        PREDECESSOR_PHYSICAL_CLOSURE_PATH.stat().st_size
        == EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_BYTES,
        "L11_PREDECESSOR_CLOSURE_BYTE_LENGTH",
    )
    require(
        sha256_file(PREDECESSOR_PHYSICAL_CLOSURE_PATH)
        == EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_SHA256,
        "L11_PREDECESSOR_CLOSURE_SHA256",
    )
    closure = json.loads(PREDECESSOR_PHYSICAL_CLOSURE_PATH.read_text(encoding="utf-8"))
    process = closure.get("process_isolation")
    dispositions = closure.get("precondition_terminal_dispositions")
    bindings = closure.get("evidence_bindings")
    require(
        isinstance(closure, dict)
        and closure.get("schema_version")
        == "sporespore_qsdk_r10f_development_route_ghost_physical_closure_v12"
        and closure.get("status")
        == "closed_consumed_invalid_or_incomplete_no_behavioral_conclusion"
        and closure.get("gate_id") == "QSDK-R10F"
        and closure.get("repair_id") == "QSDK-R10F-L11"
        and closure.get("campaign_role") == "development_route_ghost"
        and closure.get("question_class") == "development"
        and closure.get("classification")
        == "invalid_or_incomplete_no_behavioral_conclusion"
        and closure.get("source_commit") == "02f7b554a29ed80ad55d9d21930f23a267c07273"
        and closure.get("stage_commit") == "487584fc851bf6825e7c7de919e6c777fa71215b"
        and closure.get("authority_commit")
        == "f0fb74e29d1064ade3d817933d7835ca4927998c"
        and closure.get("closure_audit_commit")
        == "02f7b554a29ed80ad55d9d21930f23a267c07273"
        and closure.get("attempt_id") == "977175976c09461c9fac94dd23e6ab21"
        and closure.get("failure_code")
        == "QSDK_R10F_L9_PROCESS_POPULATION_VALIDATION_FAILED"
        and closure.get("physical_identity_consumed") is True
        and closure.get("same_identity_rerun_permitted") is False
        and closure.get("route_execution_valid") is False
        and closure.get("evidence_valid") is False
        and closure.get("measurement_complete") is False
        and closure.get("outcome_complete") is False
        and closure.get("behavior_passed") is False
        and closure.get("scientific_outcome") == "none"
        and exact_int(closure.get("campaign_attempt_count"), 1)
        and exact_int(closure.get("observed_child_process_count"), 1)
        and exact_int(closure.get("model_construction_attempt_count"), 1)
        and exact_int(closure.get("model_construction_count"), 1)
        and exact_int(closure.get("world_attempt_count"), 1)
        and exact_int(closure.get("world_build_count"), 1)
        and exact_int(closure.get("solver_step_count"), 241)
        and isinstance(process, dict)
        and process.get("ordered_declared_child_roles")
        == ["matched_no_kick_continuation", "kick_passive_recovery_resume"]
        and exact_int(process.get("declared_child_count"), 2)
        and exact_int(process.get("observed_child_count"), 1)
        and process.get("distinct_child_process_ids") is False
        and process.get("child_process_lifetimes_overlap") is None
        and process.get("child_retry_or_replacement_used") is False
        and process.get("world_or_body_state_transferred_between_children") is False
        and closure.get("topology_validation_errors") == ["declared_child_missing"]
        and closure.get("child_validation_errors")
        == {
            "matched_no_kick_continuation": (
                "L9_matched_no_kick_continuation_REPORT_FIELDS"
            )
        }
        and isinstance(dispositions, dict)
        and dispositions.get("disposition_by_arm") == {}
        and dispositions.get("precondition_negative_roles") == []
        and dispositions.get("independent_population_validation_performed") is True
        and dispositions.get("summary_boolean_only") is False
        and closure.get("event_triggered_passive_recovery_observed") is False
        and closure.get("continuous_same_body_recovery_resume_observed") is False
        and closure.get("force_aware_recovery") is False
        and closure.get("sdk1_m07_satisfied") is False
        and closure.get("physical_acceptance_authority") is False
        and closure.get("release_authority") is False
        and isinstance(bindings, dict),
        "L11_PREDECESSOR_CLOSURE_FIELDS",
    )
    expected_binding_keys = {
        "supervisor_result",
        "attempt_identity",
        "child_process_artifacts",
        "execution_authority",
        "stage_freeze",
        "r10f_design",
        "l11_repair_design",
        "superseded_physical_supervisor_refusal",
        "consumed_predecessor_physical_closure",
    }
    require(set(bindings) == expected_binding_keys, "L11_PREDECESSOR_BINDING_SET")

    def verify_declared_binding(binding: Any, code: str) -> None:
        require(isinstance(binding, dict), f"{code}_NOT_OBJECT")
        declared_path = Path(str(binding.get("path", "")))
        actual_path = (
            declared_path if declared_path.is_absolute() else ROOT / declared_path
        )
        require(actual_path.is_file(), f"{code}_MISSING")
        expected_path = (
            actual_path.resolve().as_posix()
            if declared_path.is_absolute()
            else actual_path.resolve().relative_to(ROOT.resolve()).as_posix()
        )
        require(
            binding.get("path") == expected_path
            and exact_int(binding.get("byte_length"), actual_path.stat().st_size)
            and binding.get("raw_sha256") == sha256_file(actual_path),
            f"{code}_IDENTITY",
        )

    for key in sorted(expected_binding_keys - {"child_process_artifacts"}):
        verify_declared_binding(bindings[key], f"L11_PREDECESSOR_{key.upper()}")
    child_artifacts = bindings["child_process_artifacts"]
    require(
        isinstance(child_artifacts, dict)
        and set(child_artifacts) == {"matched_no_kick_continuation"},
        "L11_PREDECESSOR_CHILD_ARTIFACT_SET",
    )
    baseline_artifacts = child_artifacts["matched_no_kick_continuation"]
    require(
        isinstance(baseline_artifacts, dict)
        and set(baseline_artifacts)
        == {
            "child_attempt_identity",
            "worker_stdout",
            "worker_stderr",
            "termination_receipt",
            "engine_health",
            "child_envelope",
            "worker_report",
        },
        "L11_PREDECESSOR_BASELINE_ARTIFACT_SET",
    )
    for key, value in baseline_artifacts.items():
        verify_declared_binding(value, f"L11_PREDECESSOR_CHILD_{key.upper()}")
    if official_qualification:
        relative = PREDECESSOR_PHYSICAL_CLOSURE_PATH.relative_to(ROOT).as_posix()
        require(
            git_text(
                ("rev-parse", f"{source_commit}:{relative}"),
                "L11_PREDECESSOR_CLOSURE_SOURCE_BLOB",
            )
            == git_text(
                ("hash-object", str(PREDECESSOR_PHYSICAL_CLOSURE_PATH)),
                "L11_PREDECESSOR_CLOSURE_BLOB",
            ),
            "L11_PREDECESSOR_CLOSURE_SOURCE_IDENTITY",
        )
    return {
        "path": PREDECESSOR_PHYSICAL_CLOSURE_PATH.relative_to(ROOT).as_posix(),
        "byte_length": PREDECESSOR_PHYSICAL_CLOSURE_PATH.stat().st_size,
        "raw_sha256": EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_SHA256,
        "status": closure["status"],
        "repair_id": "QSDK-R10F-L11",
        "classification": closure["classification"],
        "attempt_id": closure["attempt_id"],
        "physical_identity_consumed": True,
        "same_identity_rerun_permitted": False,
        "observed_child_process_count": 1,
        "world_attempt_count": 1,
        "world_build_count": 1,
        "solver_step_count": 241,
        "scientific_outcome": "none",
        "l11_release_step_completed": True,
        "walking_handoff_failure_retained": True,
    }


def audit_predecessor_physical_closure(
    *, official_qualification: bool, source_commit: str
) -> dict[str, Any]:
    """Preserve the consumed L13 invalid result, including its empty projections."""
    try:
        return l14_authority.predecessor_physical_closure_binding(source_commit)
    except (ValueError, OSError, subprocess.SubprocessError) as exc:
        raise AuditFailure(f"L14_CONSUMED_PREDECESSOR:{exc}") from exc


def audit_dependency(
    *, official_qualification: bool, require_l15_sources: bool = False
) -> dict[str, Any]:
    require(type(require_l15_sources) is bool, "DEPENDENCY_L15_MODE_KIND")
    arguments: list[str | Path] = [sys.executable, DEPENDENCY_AUDIT_PATH]
    if official_qualification:
        arguments.append("--require-tracked")
    if require_l15_sources:
        arguments.append("--require-l15-sources")
    result = checked_process(arguments, "DEPENDENCY", timeout_seconds=180)
    receipt = parse_marker(result.stdout, DEPENDENCY_MARKER, "DEPENDENCY")
    require_zero_world(receipt, "DEPENDENCY")
    require(receipt.get("qualification_finalized") is True, "DEPENDENCY_UNFINALIZED")
    require(
        receipt.get("gdscript_transitive_path_count", 0) >= 37,
        "DEPENDENCY_GDSCRIPT_COUNT",
    )
    require(receipt.get("rust_build_path_count") == 25, "DEPENDENCY_RUST_COUNT")
    require(receipt.get("mutation_rejection_count") == 4, "DEPENDENCY_MUTATIONS")
    if official_qualification:
        require(
            receipt.get("all_qualified_paths_tracked") is True, "DEPENDENCY_UNTRACKED"
        )
    if require_l15_sources:
        import qsdk_r10f_dependency_closure as dependency
        import qsdk_r10f_l15_collection_retention as packet

        # Reopen this complete source-only graph independently after consuming
        # the actual child output. No tests, native SDK calls or physics run in
        # this second read; do not replace missing fields with a green subset.
        try:
            expected = dependency.audit(
                require_tracked=official_qualification,
                allow_unfinalized=False,
                require_l15_sources=True,
            )
        except (dependency.ClosureFailure, OSError) as exc:
            raise AuditFailure(f"DEPENDENCY_L15_SOURCE_REOPEN:{exc}") from exc
        require(packet.same(receipt, expected), "DEPENDENCY_L15_COMPLETE_RECEIPT")
    return receipt


def audit_l15_qualification_inputs(
    source_commit: str, *, official_qualification: bool
) -> dict[str, Any]:
    """Pass the complete actual input binding through the enclosing reader."""
    import qsdk_r10f_authority_materializer as materializer
    import qsdk_r10f_dependency_closure as dependency
    import qsdk_r10f_l15_source_binding as l15_source

    require(type(official_qualification) is bool, "QUALIFICATION_INPUT_MODE_KIND")
    try:
        receipt = l15_source.bind_qualification_inputs(
            source_commit, require_committed_source=official_qualification
        )
        materializer.validate_l15_qualification_inputs(
            receipt,
            source_commit,
            require_committed_source=official_qualification,
        )
    except (
        ValueError,
        OSError,
        dependency.ClosureFailure,
        materializer.MaterializationFailure,
    ) as exc:
        raise AuditFailure(f"L15_QUALIFICATION_INPUTS:{exc}") from exc
    return receipt


def audit_static_source() -> dict[str, Any]:
    result = checked_process(
        (sys.executable, "-m", "unittest", "tests.test_qsdk_r10f_worker_source", "-v"),
        "SOURCE_TEST",
        timeout_seconds=180,
    )
    require("Ran 44 tests" in result.stderr, "SOURCE_TEST_COUNT")
    require(result.stderr.rstrip().endswith("OK"), "SOURCE_TEST_NOT_OK")
    format_result = checked_process(
        ("gdformat", "--check", *(str(path) for path in GDSCRIPT_PATHS)),
        "GDFORMAT",
        timeout_seconds=180,
    )
    lint_result = checked_process(
        ("gdlint", *(str(path) for path in GDSCRIPT_PATHS)),
        "GDLINT",
        timeout_seconds=180,
    )
    require("Success: no problems found" in lint_result.stdout, "GDLINT_RESULT")
    return {
        "unittest_case_count": 44,
        "gdformat_path_count": len(GDSCRIPT_PATHS),
        "gdlint_path_count": len(GDSCRIPT_PATHS),
        "gdformat_stdout": format_result.stdout.strip(),
        "gdlint_stdout": lint_result.stdout.strip(),
    }


def audit_source_authority_preflight(
    *, require_l15_sources: bool = False
) -> dict[str, Any]:
    """Exercise production source consumers before consuming qualification."""
    require(type(require_l15_sources) is bool, "PREFLIGHT_L15_MODE_KIND")
    retirement_path = ROOT / "sdk/qsdk_r10f_l13_qualified_source_retirement_v1.json"
    retirement_sha = (
        "sha256:2e6089be8512c3da2c9227ab30e3235c9088dd1c417e744edcd9f4d3a5f55430"
    )
    require(
        retirement_path.stat().st_size == 4_423
        and sha256_file(retirement_path) == retirement_sha,
        "SOURCE_RETIREMENT_BINDING",
    )
    retirement = json.loads(retirement_path.read_text(encoding="utf-8"))
    retired_source = "ebee550164eea4830ea7c55127ff672b04ad8419"
    qualification = retirement["official_qualification"]
    evidence_root = Path(qualification["retained_root"])
    observed = [
        {
            "path": entry["path"],
            "byte_length": (evidence_root / entry["path"]).stat().st_size,
            "raw_sha256": sha256_file(evidence_root / entry["path"]),
        }
        for entry in qualification["files"]
    ]
    require(
        retirement["source_commit"] == retired_source
        and retirement["source_tree_git_oid"]
        == git_text(("rev-parse", f"{retired_source}^{{tree}}"), "RETIRED_SOURCE_TREE")
        and observed == qualification["files"]
        and len(observed) == qualification["retained_file_count"] == 6
        and sum(entry["byte_length"] for entry in observed)
        == qualification["retained_total_byte_length"]
        == 63_609
        and sorted(
            path.relative_to(evidence_root).as_posix()
            for path in evidence_root.rglob("*")
            if path.is_file()
        )
        == [entry["path"] for entry in observed],
        "SOURCE_RETIREMENT_RETAINED_QUALIFICATION",
    )
    completion = json.loads(
        (evidence_root / "qualification_completion.json").read_text()
    )
    require(
        completion["official_zero_world_qualification_passed"] is True
        and completion["source_commit"] == retired_source
        and completion["same_identity_rerun_permitted"] is False,
        "SOURCE_RETIREMENT_QUALIFICATION_REMAINS_PASSING",
    )
    for counter in (*ZERO_COUNTERS, "scene_tree_insertion_count"):
        require(exact_int(completion.get(counter), 0), f"SOURCE_RETIREMENT_{counter}")

    import qsdk_r10f_l15_frozen_source_replay as frozen_source

    historical_replay = frozen_source.replay_retired_materializer()
    require(
        historical_replay["historical_source_commit"] == retired_source
        and historical_replay["historical_materializer_refusal"]
        == "DESIGN_AUTHORITY_13_IDENTITY",
        "RETIRED_MATERIALIZER_EXACT_REFUSAL",
    )

    def load_source_module(path: Path, name: str) -> Any:
        spec = importlib.util.spec_from_file_location(name, path)
        require(spec is not None and spec.loader is not None, "PREFLIGHT_MODULE_SPEC")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module

    materializer = load_source_module(
        AUTHORITY_MATERIALIZER_PATH, "_r10f_current_materializer_preflight"
    )
    closer = load_source_module(PHYSICAL_CLOSURE_PATH, "_r10f_current_closer_preflight")
    current_source = git_text(("rev-parse", "HEAD"), "PREFLIGHT_CURRENT_SOURCE")
    design, authorities = materializer.design_binding(
        current_source, require_l15_sources=require_l15_sources
    )
    require(
        authorities == design["bound_authorities"] and len(authorities) == 15,
        "PREFLIGHT_HISTORICAL_ROOT_AUTHORITIES_PRESERVED",
    )
    materializer.repair_design_binding(current_source)
    materializer.branch_completeness_addendum_binding(current_source)
    materializer.supervisor_refusal_binding(current_source)
    materializer.predecessor_physical_closure_binding(current_source)
    closer.validate_l14_repair_design(current_source)
    closer.validate_l14_branch_completeness_addendum(current_source)
    l15_handoff: dict[str, Any] = {}
    if require_l15_sources:
        import qsdk_r10f_l15_source_binding as l15_source_binding

        # Reopen independently for the returned receipt; do not manufacture a
        # successful binding from the materializer's unchanged authority list.
        l15_handoff = l15_source_binding.bind_root_sources(current_source, design)
    return {
        "ok": True,
        "schema_version": (
            "sporespore_qsdk_r10f_l15_source_authority_preflight_audit_v1"
            if require_l15_sources
            else "sporespore_qsdk_r10f_source_authority_preflight_audit_v1"
        ),
        "retired_source_commit": retired_source,
        "retirement_closure_raw_sha256": retirement_sha,
        "retired_qualification_preserved_passing": True,
        "retired_qualification_retained_file_count": len(observed),
        "retired_qualification_retained_byte_length": 63_609,
        "exact_historical_materializer_refusal_reproduced": True,
        "production_source_binding_function_count": 8 if require_l15_sources else 7,
        "historical_root_authority_count": len(authorities),
        "historical_root_authorities_preserved_unchanged": True,
        "current_adapter_bound_to_exact_successor_source": True,
        "stage_file_written": False,
        "execution_authority_written": False,
        **dict.fromkeys((*ZERO_COUNTERS, "scene_tree_insertion_count"), 0),
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
        **(
            {
                "ledger_scope": {
                    "subsystem": "recovery",
                    "engine_scope": "godot_jolt",
                    "authority_mode": "zero_world_explicit_l15_source_preflight",
                    "question_class": "development",
                },
                "historical_fixed_git_replay": historical_replay,
                "l15_root_source_binding": l15_handoff,
                "physical_family_selector_changed": False,
                "whole_route_qualified": False,
                "official_qualification_consumed": False,
                "physical_execution_authorized": False,
            }
            if require_l15_sources
            else {}
        ),
    }


def audit_future_authority_tooling() -> dict[str, Any]:
    materializer = checked_process(
        (sys.executable, "-B", AUTHORITY_MATERIALIZER_PATH, "self-test"),
        "AUTHORITY_MATERIALIZER_SELF_TEST",
        timeout_seconds=180,
    )
    materializer_receipt = parse_marker(
        materializer.stdout,
        MATERIALIZER_SELF_TEST_MARKER,
        "AUTHORITY_MATERIALIZER_SELF_TEST",
    )
    require_zero_world(materializer_receipt, "AUTHORITY_MATERIALIZER_SELF_TEST")
    require(
        materializer_receipt.get("stage_valid_control_count") == 1
        and materializer_receipt.get("authority_valid_control_count") == 1
        and materializer_receipt.get("mutation_rejection_count") == 521,
        "AUTHORITY_MATERIALIZER_SELF_TEST_COUNTS",
    )
    closure = checked_process(
        (sys.executable, "-B", PHYSICAL_CLOSURE_PATH, "self-test"),
        "PHYSICAL_CLOSURE_SELF_TEST",
        timeout_seconds=180,
    )
    closure_receipt = parse_marker(
        closure.stdout,
        PHYSICAL_CLOSURE_SELF_TEST_MARKER,
        "PHYSICAL_CLOSURE_SELF_TEST",
    )
    require_zero_world(closure_receipt, "PHYSICAL_CLOSURE_SELF_TEST")
    require(
        closure_receipt.get("schema_version")
        == "sporespore_qsdk_r10f_l13_physical_closure_self_test_v1"
        and closure_receipt.get("repair_id") == REPAIR_ID
        and closure_receipt.get("synthetic_report_control_count") == 5
        and closure_receipt.get("integer_valued_native_step_positive_control_count")
        == 4
        and closure_receipt.get("integer_valued_native_step_mutation_rejection_count")
        == 15
        and closure_receipt.get("nullable_terminal_failure_code_positive_control_count")
        == 3
        and closure_receipt.get(
            "nullable_terminal_failure_code_mutation_rejection_count"
        )
        == 16
        and closure_receipt.get("release_owner_source_mutation_rejection_count") == 4
        and closure_receipt.get("walking_actuation_handoff_mutation_rejection_count")
        == 4
        and closure_receipt.get("walking_failure_retention_positive_control_count") == 1
        and closure_receipt.get("walking_failure_retention_mutation_rejection_count")
        == 15
        and closure_receipt.get("walking_failure_retention_retained_source_count") == 8
        and closure_receipt.get("walking_ledger_named_predicate_count") == 125
        and closure_receipt.get("partial_child_envelope_failure_retention_projected")
        is True
        and closure_receipt.get("process_isolated_report_mutation_rejection_count")
        == 43
        and closure_receipt.get("retained_artifact_positive_control_count") == 1
        and closure_receipt.get("retained_artifact_mutation_rejection_count") == 2
        and closure_receipt.get("mutation_rejection_count") == 91
        and closure_receipt.get("content_digest_recomputation_enabled") is True
        and closure_receipt.get("retained_child_artifact_reopening_enabled") is True
        and closure_receipt.get("classifications")
        == [
            "valid_complete_behavior_positive",
            "valid_complete_behavior_development_negative",
            "invalid_or_incomplete_no_behavioral_conclusion",
            "invalid_or_incomplete_no_behavioral_conclusion",
            "invalid_or_incomplete_no_behavioral_conclusion",
        ],
        "PHYSICAL_CLOSURE_SELF_TEST_COUNTS",
    )
    wrapper_parse = checked_process(
        (
            "pwsh",
            "-NoLogo",
            "-NoProfile",
            "-Command",
            "$ErrorActionPreference='Stop';"
            "$null=[scriptblock]::Create((Get-Content -Raw -LiteralPath "
            "'sdk/qsdk_r10f_zero_world_qualification.ps1'));"
            "'QSDK_R10F_QUALIFICATION_WRAPPER_PARSE_OK'",
        ),
        "QUALIFICATION_WRAPPER_PARSE",
        timeout_seconds=120,
    )
    require(
        "QSDK_R10F_QUALIFICATION_WRAPPER_PARSE_OK" in wrapper_parse.stdout,
        "QUALIFICATION_WRAPPER_PARSE_MARKER",
    )
    return {
        "qualification_wrapper_powershell_parse_passed": True,
        "authority_materializer_self_test": materializer_receipt,
        "physical_closure_self_test": closure_receipt,
    }


def expected_godot_zero_world_fields() -> dict[str, Any]:
    """Complete existing native gate contract, not an executed passing result.

    The synthetic route has two precondition steps, one release, 720 prefix,
    one kick-effect event, 12 prone samples, two recovery events and 720 resume
    events: 1458 global / 734 post-kick bookkeeping steps, zero solver steps.
    These are the existing fixture's counters, not a physical horizon change.
    """
    return {
        "schema_version": "sporespore_qsdk_r10f_continuous_passive_recovery_zero_world_v1",
        "gate_id": "QSDK-R10F",
        "ok": True,
        "status": "passed_complete_zero_world_offset_epoch_same_body_passive_recovery_implementation",
        "ledger_scope": {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "prospective_zero_world_implementation",
            "question_class": "development",
        },
        "question_class": "development",
        "epoch_start_global_step_canary": 508,
        "first_recovery_global_step_canary": 509,
        "first_recovery_local_step_canary": 1,
        # The facade identity population includes nine bodies and eight joints.
        "same_body_node_identity_count": 17,
        "positive_case_count": 24,
        "forced_failure_case_count": 237,
        "initial_bootstrap_producer_consumer_control_count": 1,
        "initial_bootstrap_mutation_rejection_count": 6,
        "detached_command_surface_node_count": 8,
        "joint_geometry_source_shape_control_count": 1,
        "joint_geometry_mutation_rejection_count": 16,
        "detached_geometry_body_node_count": 9,
        "detached_geometry_joint_node_count": 8,
        "collection_solver_counter_consecutive_positive_count": 2,
        "collection_solver_counter_mutation_rejection_count": 16,
        "precondition_pair_barrier_positive_sequence_control_count": 4,
        "precondition_pair_barrier_mutation_rejection_count": 9,
        "precondition_pair_application_positive_control_count": 2,
        "precondition_pair_application_mutation_rejection_count": 3,
        "precondition_pair_required_mutation_rejection_count": 12,
        "precondition_terminal_disposition_positive_control_count": 6,
        "precondition_terminal_disposition_mutation_rejection_count": 16,
        "integer_valued_native_step_domain_positive_control_count": 6,
        "integer_valued_native_step_domain_mutation_rejection_count": 16,
        "process_isolated_child_positive_case_count": 8,
        "process_isolated_child_mutation_rejection_count": 31,
        "nullable_terminal_failure_code_positive_control_count": 7,
        "nullable_terminal_failure_code_mutation_rejection_count": 17,
        "precondition_release_owner_source_positive_control_count": 9,
        "precondition_release_owner_source_mutation_rejection_count": 23,
        "walking_actuation_handoff_positive_control_count": 5,
        "walking_actuation_handoff_mutation_rejection_count": 22,
        "qualified_r69_projection_count": 8,
        "walking_ledger_l13_positive_control_count": 15,
        "walking_ledger_l13_mutation_rejection_count": 16,
        "walking_ledger_failure_retention_positive_control_count": 1,
        "walking_ledger_failure_retention_mutation_rejection_count": 15,
        "production_shaped_l13_walking_fixture_count": 3,
        "detached_l13_hinge_parameter_container_count": 24,
        "walking_evaluator_fixed_receipt_count": 27,
        "portable_nonzero_global_step_accepted": True,
        "active_terminal_global_step": 1458,
        "baseline_terminal_global_step": 1458,
        "active_terminal_local_recovery_step": 734,
        "baseline_terminal_local_recovery_step": 734,
        "historical_closure_audits_executed_count": 0,
        "bespoke_physical_canary_count": 0,
        "full_seeded_ghost_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "body_impulse_write_count": 0,
        "body_transform_write_count": 0,
        "body_velocity_write_count": 0,
        "native_readback_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_question_declared": True,
        "physical_question_opened": False,
        "physical_execution_authorized": False,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def validate_godot_receipt(
    receipt: Mapping[str, Any], *, require_l15_context: bool = False
) -> dict[str, Any] | None:
    """Read the complete result without launching an engine or reopening images.

    Process exit, original UTF-8/marker and diagnostic checks remain with the
    producer. This reader proves result integrity, never qualification origin.
    """
    require(type(require_l15_context) is bool, "GODOT_L15_CONTEXT_MODE_KIND")
    require(type(receipt) is dict, "GODOT_RECEIPT_KIND")
    context_proof = None
    if require_l15_context:
        import qsdk_r10f_l15_collection_context as l15_context
        import qsdk_r10f_physical_closure as closer

        expected = expected_godot_zero_world_fields()
        try:
            l15_context.packet.exact_keys(
                receipt,
                set(expected) | {"l15_prepared_collection_context"},
                "COMPLETE_NATIVE_GATE",
            )
            different_fields = [
                key
                for key in expected
                if not l15_context.packet.same(receipt[key], expected[key])
            ]
            require(
                not different_fields,
                "GODOT_L15_COMPLETE_GATE_FIELDS:" + ",".join(different_fields),
            )
            snapshot = receipt["l15_prepared_collection_context"]
            captured = l15_context.packet.verify_bytes(snapshot, "GATE_CONTEXT_CAPTURE")
            context_proof = l15_context.validate_capture(
                captured.decode("utf-8", errors="strict"),
                expected_raw_binding={
                    key: snapshot[key] for key in ("utf8_byte_length", "raw_sha256")
                },
                canonical_sha256=closer.canonical_sha256_v1,
            )
        except (ValueError, RecursionError, closer.ClosureFailure) as exc:
            raise AuditFailure(f"GODOT_L15_PREPARED_CONTEXT:{exc}") from exc
    require_zero_world(receipt, "ZERO_WORLD")
    require(receipt.get("positive_case_count") == 24, "ZERO_WORLD_POSITIVE_COUNT")
    require(receipt.get("forced_failure_case_count") == 237, "ZERO_WORLD_FAILURE_COUNT")
    require(
        receipt.get("initial_bootstrap_producer_consumer_control_count") == 1
        and receipt.get("initial_bootstrap_mutation_rejection_count") == 6
        and receipt.get("detached_command_surface_node_count") == 8,
        "ZERO_WORLD_INITIAL_BOOTSTRAP_CONTROLS",
    )
    require(
        receipt.get("joint_geometry_source_shape_control_count") == 1
        and receipt.get("joint_geometry_mutation_rejection_count") == 16
        and receipt.get("detached_geometry_body_node_count") == 9
        and receipt.get("detached_geometry_joint_node_count") == 8,
        "ZERO_WORLD_JOINT_GEOMETRY_CONTROLS",
    )
    require(
        receipt.get("collection_solver_counter_consecutive_positive_count") == 2
        and receipt.get("collection_solver_counter_mutation_rejection_count") == 16,
        "ZERO_WORLD_COLLECTION_SOLVER_COUNTER_CONTROLS",
    )
    require(
        receipt.get("precondition_pair_barrier_positive_sequence_control_count") == 4
        and receipt.get("precondition_pair_barrier_mutation_rejection_count") == 9
        and receipt.get("precondition_pair_application_positive_control_count") == 2
        and receipt.get("precondition_pair_application_mutation_rejection_count") == 3
        and receipt.get("precondition_pair_required_mutation_rejection_count") == 12,
        "ZERO_WORLD_PRECONDITION_PAIR_BARRIER_CONTROLS",
    )
    require(
        receipt.get("precondition_terminal_disposition_positive_control_count") == 6
        and receipt.get("precondition_terminal_disposition_mutation_rejection_count")
        == 16,
        "ZERO_WORLD_PRECONDITION_TERMINAL_DISPOSITION_CONTROLS",
    )
    require(
        receipt.get("integer_valued_native_step_domain_positive_control_count") == 6
        and receipt.get("integer_valued_native_step_domain_mutation_rejection_count")
        == 16,
        "ZERO_WORLD_INTEGER_VALUED_NATIVE_STEP_DOMAIN_CONTROLS",
    )
    require(
        receipt.get("process_isolated_child_positive_case_count") == 8
        and receipt.get("process_isolated_child_mutation_rejection_count") == 31,
        "ZERO_WORLD_PROCESS_ISOLATED_CHILD_CONTROLS",
    )
    require(
        receipt.get("nullable_terminal_failure_code_positive_control_count") == 7
        and receipt.get("nullable_terminal_failure_code_mutation_rejection_count")
        == 17,
        "ZERO_WORLD_NULLABLE_TERMINAL_FAILURE_CODE_CONTROLS",
    )
    require(
        receipt.get("precondition_release_owner_source_positive_control_count") == 9
        and receipt.get("precondition_release_owner_source_mutation_rejection_count")
        == 23,
        "ZERO_WORLD_PRECONDITION_RELEASE_OWNER_SOURCE_CONTROLS",
    )
    require(
        receipt.get("walking_actuation_handoff_positive_control_count") == 5
        and receipt.get("walking_actuation_handoff_mutation_rejection_count") == 22
        and receipt.get("qualified_r69_projection_count") == 8,
        "ZERO_WORLD_WALKING_ACTUATION_HANDOFF_CONTROLS",
    )
    require(
        receipt.get("walking_ledger_l13_positive_control_count") == 15
        and receipt.get("walking_ledger_l13_mutation_rejection_count") == 16
        and receipt.get("walking_ledger_failure_retention_positive_control_count") == 1
        and receipt.get("walking_ledger_failure_retention_mutation_rejection_count")
        == 15
        and receipt.get("production_shaped_l13_walking_fixture_count") == 3
        and receipt.get("detached_l13_hinge_parameter_container_count") == 24,
        "ZERO_WORLD_L13_WALKING_LEDGER_CONTROLS",
    )
    require(
        receipt.get("walking_evaluator_fixed_receipt_count") == 27,
        "ZERO_WORLD_WALKING_COUNT",
    )
    require(
        receipt.get("physical_execution_authorized") is False, "ZERO_WORLD_AUTHORITY"
    )
    return context_proof


def l15_worker_parse_output_header() -> dict[str, Any]:
    """Source contract for the check-only process, not proof of official origin."""
    return {
        "schema_version": "sporespore_qsdk_r10f_l15_worker_parse_output_v1",
        "gate_id": "QSDK-R10F",
        "repair_id": "QSDK-R10F-L15",
        "ledger_scope": {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "development_zero_world_worker_syntax_check",
            "question_class": "development",
        },
        "arguments": [
            str(DEFAULT_GODOT),
            "--headless",
            "--path",
            str(ROOT),
            "--check-only",
            "--script",
            WORKER_SCRIPT,
        ],
        "working_directory": ROOT.as_posix(),
        "original_utf8_process_output_retained": True,
        "worker_runtime_entrypoint_executed": False,
        "official_source_origin_authenticated": False,
        **dict.fromkeys((*ZERO_COUNTERS, "scene_tree_insertion_count"), 0),
        "physics_state_modified": False,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def validate_l15_worker_parse_receipt(value: Any) -> None:
    """Bind both original streams to their existing hash metadata, without I/O."""
    import qsdk_r10f_l15_collection_retention as packet

    try:
        packet.exact_keys(
            value,
            {
                "worker_parse_exit_code",
                "worker_parse_stdout_sha256",
                "worker_parse_stderr_sha256",
                "l15_process_output",
            },
            "WORKER_PARSE_RECEIPT",
        )
        require(exact_int(value["worker_parse_exit_code"], 0), "L15_WORKER_PARSE_EXIT")
        output = value["l15_process_output"]
        header = l15_worker_parse_output_header()
        packet.exact_keys(
            output, set(header) | {"stdout", "stderr"}, "WORKER_PARSE_OUTPUT"
        )
        require(
            packet.same({key: output[key] for key in header}, header),
            "L15_WORKER_PARSE_HEADER",
        )
        for stream in ("stdout", "stderr"):
            raw = packet.verify_bytes(output[stream], "WORKER_PARSE_" + stream.upper())
            require(
                packet.same(
                    value["worker_parse_" + stream + "_sha256"],
                    output[stream]["raw_sha256"],
                ),
                "L15_WORKER_PARSE_" + stream.upper() + "_BINDING",
            )
            text = raw.decode("utf-8", errors="strict")
            require(
                "SCRIPT ERROR:" not in text and "ERROR:" not in text,
                "L15_WORKER_PARSE_DIAGNOSTIC",
            )
    except (ValueError, RecursionError) as exc:
        raise AuditFailure(f"L15_WORKER_PARSE_OUTPUT:{exc}") from exc


def audit_godot(
    godot: Path, *, require_l15_context: bool = False
) -> tuple[dict[str, Any], dict[str, Any]]:
    require(type(require_l15_context) is bool, "GODOT_L15_CONTEXT_MODE_KIND")
    require(godot.is_file(), "GODOT_EXECUTABLE_MISSING")
    if require_l15_context:
        # This direct gate entry point still checks the actual pinned images.
        # It does not allocate an official qualification or physical identity.
        l14_runtime.bind_runtime(godot)
    check = checked_process(
        (
            godot,
            "--headless",
            "--path",
            ROOT,
            "--check-only",
            "--script",
            WORKER_SCRIPT,
        ),
        "WORKER_PARSE",
        timeout_seconds=180,
        strict_utf8=require_l15_context,
    )
    combined_check = check.stdout + check.stderr
    require(
        "SCRIPT ERROR:" not in combined_check and "ERROR:" not in combined_check,
        "WORKER_PARSE_DIAGNOSTIC",
    )
    zero_arguments = (
        godot,
        "--headless",
        "--path",
        ROOT,
        "--script",
        ZERO_WORLD_SCRIPT,
    )
    if require_l15_context:
        zero_arguments += ("--", "--r10f-l15-prepared-context")
    zero = checked_process(
        zero_arguments,
        "ZERO_WORLD",
        timeout_seconds=240,
        strict_utf8=require_l15_context,
    )
    receipt = parse_marker(zero.stdout, ZERO_WORLD_MARKER, "ZERO_WORLD")
    if require_l15_context:
        import qsdk_r10f_l15_collection_context as l15_context

        # Preserve strict original marker parsing before any dictionary reader.
        original_text = next(
            line[len(ZERO_WORLD_MARKER) :]
            for line in zero.stdout.splitlines()
            if line.startswith(ZERO_WORLD_MARKER)
        )
        try:
            receipt = l15_context.packet.parse_json(original_text)
        except (ValueError, RecursionError) as exc:
            raise AuditFailure(f"GODOT_L15_PREPARED_CONTEXT:{exc}") from exc
    validate_godot_receipt(receipt, require_l15_context=require_l15_context)
    if require_l15_context:
        require(
            "SCRIPT ERROR:" not in zero.stdout + zero.stderr
            and "ERROR:" not in zero.stdout + zero.stderr,
            "GODOT_L15_ZERO_WORLD_DIAGNOSTIC",
        )
        l14_runtime.bind_runtime(godot)
    worker_parse = {
        "worker_parse_exit_code": check.returncode,
        "worker_parse_stdout_sha256": "sha256:"
        + hashlib.sha256(check.stdout.encode("utf-8")).hexdigest(),
        "worker_parse_stderr_sha256": "sha256:"
        + hashlib.sha256(check.stderr.encode("utf-8")).hexdigest(),
    }
    if require_l15_context:
        import qsdk_r10f_l15_collection_context as l15_context

        # These are the actual completed check-only process's arguments and
        # original streams. No second syntax check is run to fill missing data.
        worker_parse["l15_process_output"] = {
            **l15_worker_parse_output_header(),
            "arguments": [str(argument) for argument in check.args],
            "stdout": {
                "utf8_text": check.stdout,
                **l15_context.raw_binding(check.stdout),
            },
            "stderr": {
                "utf8_text": check.stderr,
                **l15_context.raw_binding(check.stderr),
            },
        }
        validate_l15_worker_parse_receipt(worker_parse)
    return receipt, worker_parse


def audit_supervisor(*, official_qualification: bool) -> dict[str, Any]:
    parse = checked_process(
        (
            "pwsh",
            "-NoLogo",
            "-NoProfile",
            "-Command",
            "$ErrorActionPreference='Stop';"
            "$null=[scriptblock]::Create((Get-Content -Raw -LiteralPath "
            "'sdk/run_qsdk_r10f_continuous_passive_recovery.ps1'));"
            "'QSDK_R10F_SUPERVISOR_PARSE_OK'",
        ),
        "SUPERVISOR_PARSE",
        timeout_seconds=120,
    )
    require("QSDK_R10F_SUPERVISOR_PARSE_OK" in parse.stdout, "SUPERVISOR_PARSE_MARKER")
    if official_qualification:
        return {
            "powershell_parse_passed": True,
            "preflight_process_skipped_under_outer_qualification_lock": True,
            "physical_refusal_process_skipped_under_outer_qualification_lock": True,
            "authority_graph_path_projection_exercised_by_static_zero_world_test": True,
        }
    preflight = checked_process(
        (
            "pwsh",
            "-NoLogo",
            "-NoProfile",
            "-File",
            SUPERVISOR_PATH,
            "-Mode",
            "Preflight",
        ),
        "SUPERVISOR_PREFLIGHT",
        timeout_seconds=180,
    )
    preflight_receipt = parse_marker(preflight.stdout, SUPERVISOR_MARKER, "SUPERVISOR")
    require_zero_world(preflight_receipt, "SUPERVISOR")
    require(
        preflight_receipt.get("repair_id") == REPAIR_ID
        and preflight_receipt.get("repair_design_raw_sha256")
        == EXPECTED_REPAIR_DESIGN_SHA256
        and preflight_receipt.get("branch_completeness_addendum_raw_sha256")
        == EXPECTED_BRANCH_COMPLETENESS_ADDENDUM_SHA256
        and preflight_receipt.get("superseded_physical_supervisor_refusal_sha256")
        == EXPECTED_SUPERVISOR_REFUSAL_SHA256
        and preflight_receipt.get("consumed_predecessor_physical_closure_sha256")
        == EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_SHA256
        and preflight_receipt.get(
            "authority_graph_path_projection_zero_world_control_count"
        )
        == 2
        and preflight_receipt.get("authority_graph_path_set_zero_world_control_count")
        == 5
        and preflight_receipt.get("pair_evaluator_positive_control_count") == 3
        and preflight_receipt.get("pair_evaluator_mutation_rejection_count") == 35,
        "SUPERVISOR_PREFLIGHT_REPAIR_FIELDS",
    )
    refusal = run_process(
        (
            "pwsh",
            "-NoLogo",
            "-NoProfile",
            "-File",
            SUPERVISOR_PATH,
            "-Mode",
            "Physical",
        ),
        timeout_seconds=180,
    )
    require(refusal.returncode == 1, "SUPERVISOR_BYPASS_EXIT")
    refusal_receipt = parse_marker(
        refusal.stdout, SUPERVISOR_REFUSAL_MARKER, "SUPERVISOR_REFUSAL"
    )
    require(refusal_receipt.get("ok") is False, "SUPERVISOR_BYPASS_OK")
    require(
        refusal_receipt.get("repair_id") == REPAIR_ID
        and refusal_receipt.get("failure_code") == "PHYSICAL_MODE_REQUIRES_RUNPHYSICAL",
        "SUPERVISOR_BYPASS_CODE",
    )
    for counter in ZERO_COUNTERS:
        require(refusal_receipt.get(counter) == 0, f"SUPERVISOR_BYPASS_{counter}")
    return {
        "powershell_parse_passed": True,
        "preflight_receipt": preflight_receipt,
        "physical_without_explicit_switch_refusal": refusal_receipt,
    }


def runtime_identity(godot: Path) -> dict[str, Any]:
    try:
        exact_images = l14_runtime.bind_runtime(godot)
    except (ValueError, OSError) as exc:
        raise AuditFailure(f"L14_RUNTIME_IDENTITY:{exc}") from exc
    version = checked_process(
        (godot, "--version"), "GODOT_VERSION", timeout_seconds=120
    )
    python_version = checked_process(
        (sys.executable, "--version"), "PYTHON_VERSION", timeout_seconds=60
    )
    powershell_version = checked_process(
        (
            "pwsh",
            "-NoLogo",
            "-NoProfile",
            "-Command",
            "$PSVersionTable.PSVersion.ToString()",
        ),
        "POWERSHELL_VERSION",
        timeout_seconds=60,
    )
    require(ACTIVE_ADAPTER_PATH.is_file(), "ACTIVE_ADAPTER_MISSING")
    return {
        "godot_console": {
            "path": godot.as_posix(),
            "byte_length": godot.stat().st_size,
            "raw_sha256": sha256_file(godot),
            "version": version.stdout.strip(),
        },
        "active_adapter": {
            "path": ACTIVE_ADAPTER_PATH.relative_to(ROOT).as_posix(),
            "byte_length": ACTIVE_ADAPTER_PATH.stat().st_size,
            "raw_sha256": sha256_file(ACTIVE_ADAPTER_PATH),
        },
        "python_version": python_version.stdout.strip(),
        "powershell_version": powershell_version.stdout.strip(),
        "l14_exact_runtime_images": exact_images,
    }


def l15_qualification_candidate_header() -> dict[str, Any]:
    """Prospective combined-reader contract, never a substitute for execution."""
    return {
        "schema_version": "sporespore_qsdk_r10f_l15_qualification_candidate_v2",
        "gate_id": "QSDK-R10F",
        "repair_id": "QSDK-R10F-L15",
        "ledger_scope": {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "development_assembled_zero_world_qualification_candidate",
            "question_class": "development",
        },
        "question_class": "development",
        "ok": True,
        "status": "passed_combined_zero_world_result_pending_official_enclosing_integration",
        "serialized_execution": True,
        "complete_native_gate_executed": True,
        "legacy_component_rollup_executed": True,
        "l15_component_rollup_executed": True,
        "complete_inputs_reopened_before_and_after": True,
        "combined_record_read_by_materializer": True,
        "candidate_reader_contract_test_count": 6,
        "qualification_wrapper_validated_this_candidate": False,
        "qualification_directory_validated_this_candidate": False,
        "official_expected_context_origin_authenticated": False,
        "qualification_or_physical_identity_created": False,
        "complete_implementation_qualified": False,
        "physical_question_declared": False,
        "physical_question_opened": False,
        "whole_route_qualified": False,
        "sdk1_m07_satisfied": False,
        **dict.fromkeys((*ZERO_COUNTERS, "scene_tree_insertion_count"), 0),
        "physics_state_modified": False,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def l15_qualification_source_record_names() -> frozenset[str]:
    return frozenset(
        {
            "source",
            "qualification_inputs",
            "runtime_identity",
            "root_design_audit",
            "predecessor_qualification_failure_audit",
            "l14_repair_design",
            "l14_branch_completeness_addendum",
            "l14_superseded_physical_supervisor_refusal",
            "l14_consumed_predecessor_physical_closure",
            "l14_qualified_source_retirement_audit",
            "future_authority_tooling_receipt",
            "source_authority_preflight_receipt",
            "legacy_supervisor_regression",
            "historical_qualification_wrapper_regression",
        }
    )


def audit_l15_qualification_source_records(
    godot: Path, source_commit: str, *, qualification_capture: bool | None = None
) -> dict[str, Any]:
    """Reopen complete source/retained authorities without a native SDK gate.

    Existing source-only auditors and nonphysics host preflights really run.
    The historical wrapper regression consumes its complete retained L14 input;
    it does not pretend that the old wrapper accepts the new L15 candidate.
    """
    import qsdk_r10f_authority_materializer as materializer
    import qsdk_r10f_l15_collection_retention as packet

    require(qualification_capture is None or type(qualification_capture) is bool,
            "L15_QUALIFICATION_CAPTURE_MODE")
    under_outer_lock = (
        os.environ.get(QUALIFICATION_LOCK_ENV) == "1"
        if qualification_capture is None else qualification_capture
    )
    source = inspect_source(official_qualification=False)
    require(
        type(source_commit) is str and source_commit == source["source_commit"],
        "L15_CANDIDATE_SOURCE_COMMIT",
    )
    retirement = l14_pipeline.audit_retirement()
    retirement_record = packet.parse_json(
        l14_pipeline.PATH.read_bytes().decode("utf-8")
    )
    retained_path = (
        Path(retirement_record["retained_evidence"]["root"])
        / "implementation_audit.json"
    )
    retained_raw = retained_path.read_bytes()
    retained_binding = {
        "path": retained_path.as_posix(),
        "byte_length": len(retained_raw),
        "raw_sha256": "sha256:" + hashlib.sha256(retained_raw).hexdigest(),
    }
    require(
        retained_binding in retirement_record["retained_evidence"]["files"],
        "L15_CANDIDATE_HISTORICAL_WRAPPER_INPUT",
    )
    retained_receipt = packet.parse_json(retained_raw.decode("utf-8"))
    records = {
        "source": source,
        "qualification_inputs": audit_l15_qualification_inputs(
            source_commit, official_qualification=False
        ),
        "runtime_identity": runtime_identity(godot),
        "root_design_audit": audit_design(require_l15_sources=True),
        "predecessor_qualification_failure_audit": audit_predecessor_qualification_failure(),
        "l14_repair_design": audit_repair_design(
            official_qualification=False, source_commit=source_commit
        ),
        "l14_branch_completeness_addendum": audit_branch_completeness_addendum(
            source_commit
        ),
        "l14_superseded_physical_supervisor_refusal": audit_superseded_refusal(
            official_qualification=False
        ),
        "l14_consumed_predecessor_physical_closure": audit_predecessor_physical_closure(
            official_qualification=False, source_commit=source_commit
        ),
        "l14_qualified_source_retirement_audit": retirement,
        "future_authority_tooling_receipt": audit_future_authority_tooling(),
        "source_authority_preflight_receipt": audit_source_authority_preflight(
            require_l15_sources=True
        ),
        # The enclosing wrapper owns the operation mutex. Use the existing
        # official path's explicit parse-only receipt for this legacy preflight;
        # never launch a second mutex owner or relabel it as an executed check.
        # The full native, static and L14/L15 component gates still execute.
        "legacy_supervisor_regression": audit_supervisor(
            official_qualification=under_outer_lock
        ),
        "historical_qualification_wrapper_regression": {
            "retained_input": retained_binding,
            "retained_source_commit": l14_pipeline.SOURCE,
            "actual_wrapper_contract": audit_qualification_receipt_contract(
                retained_receipt
            ),
            "historical_receipt_adopted_as_l15_qualification": False,
            "current_l15_receipt_consumed_by_this_legacy_control": False,
        },
    }
    require(
        set(records) == l15_qualification_source_record_names(),
        "L15_CANDIDATE_SOURCE_RECORDS",
    )
    require(
        packet.same(inspect_source(official_qualification=False), source),
        "L15_CANDIDATE_SOURCE_DRIFT",
    )
    # This additional complete reopening catches changes across the source audits.
    materializer.validate_l15_qualification_inputs(
        records["qualification_inputs"], source_commit, require_committed_source=False
    )
    return records


def audit_l15_qualification_candidate(godot: Path) -> dict[str, Any]:
    """Execute the combined development result; no official mode or identity.

    The legacy top-level entry point remains unchanged. This distinct producer
    assembles actual full results for the enclosing L15 readers still being built.
    """
    import qsdk_r10f_authority_materializer as materializer
    import qsdk_r10f_l15_component_rollup as l15_components
    import qsdk_r10f_l15_collection_retention as packet

    source = inspect_source(official_qualification=False)
    source_commit = source["source_commit"]
    try:
        records = audit_l15_qualification_source_records(godot, source_commit)
        print("L15_CANDIDATE_STAGE_PASS complete_source_records", flush=True)
        static_source = audit_static_source()
        print("L15_CANDIDATE_STAGE_PASS complete_static_source", flush=True)
        dependency = audit_dependency(
            official_qualification=False, require_l15_sources=True
        )
        print("L15_CANDIDATE_STAGE_PASS complete_dependency", flush=True)
        native, worker_parse = audit_godot(godot, require_l15_context=True)
        print("L15_CANDIDATE_STAGE_PASS complete_native_gate", flush=True)
        legacy_components = l14_components.audit(godot)
        print("L15_CANDIDATE_STAGE_PASS legacy_components", flush=True)
        additional_components = l15_components.audit(godot)
        print("L15_CANDIDATE_STAGE_PASS additional_components", flush=True)
        receipt = {
            **l15_qualification_candidate_header(),
            "source_records": records,
            "static_source_receipt": static_source,
            "dependency_receipt": dependency,
            "zero_world_receipt": native,
            "worker_parse_receipt": worker_parse,
            "l14_component_qualification": legacy_components,
            "l15_component_qualification": additional_components,
            "prepared_context_integrity": validate_godot_receipt(
                native, require_l15_context=True
            ),
        }
        independently_reopened = materializer.validate_l15_qualification_candidate(
            receipt, source_commit
        )
        print("L15_CANDIDATE_STAGE_PASS independent_complete_reader", flush=True)
        spec = importlib.util.spec_from_file_location(
            "_sporespore_l15_candidate_reader_controls",
            ROOT / l15_components.READER_CONTROLS,
        )
        require(
            spec is not None and spec.loader is not None, "L15_CANDIDATE_CONTROL_MODULE"
        )
        controls = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(controls)
        receipt["candidate_reader_contract_test_count"] = (
            controls.exercise_actual_candidate_controls(
                receipt, expected_source_records=independently_reopened
            )
        )
        materializer.validate_l15_qualification_inputs(
            records["qualification_inputs"],
            source_commit,
            require_committed_source=False,
        )
        require(
            packet.same(inspect_source(official_qualification=False), source),
            "L15_CANDIDATE_FINAL_SOURCE_DRIFT",
        )
        materializer.validate_l15_qualification_candidate_record(
            receipt, expected_source_records=independently_reopened
        )
        print(
            "L15_CANDIDATE_STAGE_PASS reader_controls_and_final_input_reopen",
            flush=True,
        )
        return receipt
    except (ValueError, materializer.MaterializationFailure) as exc:
        raise AuditFailure(f"L15_QUALIFICATION_CANDIDATE:{exc}") from exc


def audit(godot: Path, *, official_qualification: bool) -> dict[str, Any]:
    source = inspect_source(official_qualification=official_qualification)
    runtime = runtime_identity(godot)
    require(
        not official_qualification
        or source["source_commit"] != FAILED_QUALIFICATION_SOURCE_COMMIT,
        "CONSUMED_QUALIFICATION_SOURCE_CANNOT_BE_RETRIED",
    )
    qualification_failure = audit_predecessor_qualification_failure()
    design = audit_design()
    repair_design = audit_repair_design(
        official_qualification=official_qualification,
        source_commit=source["source_commit"],
    )
    superseded_refusal = audit_superseded_refusal(
        official_qualification=official_qualification
    )
    predecessor_physical_closure = audit_predecessor_physical_closure(
        official_qualification=official_qualification,
        source_commit=source["source_commit"],
    )
    branch_completeness_addendum = audit_branch_completeness_addendum(source["source_commit"])
    dependency = audit_dependency(official_qualification=official_qualification)
    static_source = audit_static_source()
    future_authority_tooling = audit_future_authority_tooling()
    source_authority_preflight = audit_source_authority_preflight()
    try:
        l14_qualification_retirement = l14_pipeline.audit_retirement()
    except ValueError as exc:
        raise AuditFailure(f"L14_QUALIFIED_SOURCE_RETIREMENT:{exc}") from exc
    # Cheap production-envelope checks precede the longer GDScript controls.
    supervisor = audit_supervisor(official_qualification=official_qualification)
    zero_world, worker_parse = audit_godot(godot)
    try:
        l14_component_qualification = l14_components.audit(godot)
    except ValueError as exc:
        raise AuditFailure(f"L14_COMPONENT_QUALIFICATION:{exc}") from exc
    require(
        l14_authority.design_audit.exact(runtime_identity(godot), runtime),
        "L14_RUNTIME_DRIFT_DURING_QUALIFICATION",
    )
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    require(isinstance(manifest, dict), "MANIFEST_NOT_OBJECT")
    policy = manifest.get("policy", {})
    require(isinstance(policy, dict), "MANIFEST_POLICY_NOT_OBJECT")
    require(
        manifest.get("schema_version") == "sporespore_qsdk_r10f_dependency_manifest_v19"
        and manifest.get("repair_id") == REPAIR_ID,
        "MANIFEST_REPAIR_FIELDS",
    )
    qualified_count = policy.get("expected_qualified_source_count")
    qualified_digest = policy.get("expected_qualified_source_path_sha256")
    require(isinstance(qualified_count, int) and qualified_count > 0, "QUALIFIED_COUNT")
    require(is_sha256(qualified_digest), "QUALIFIED_DIGEST")
    receipt = {
        "schema_version": "sporespore_qsdk_r10f_zero_world_implementation_audit_v1",
        "gate_id": "QSDK-R10F",
        "repair_id": REPAIR_ID,
        "ledger_scope": {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": (
                "official_zero_world_qualification"
                if official_qualification
                else "development_zero_world_audit"
            ),
            "question_class": "development",
        },
        "ok": True,
        "status": "passed_complete_zero_world_implementation",
        "source": source,
        "design_raw_sha256": design["design_raw_sha256"],
        "root_design_audit": design,
        "predecessor_qualification_failure_closure_raw_sha256": (
            EXPECTED_QUALIFICATION_FAILURE_CLOSURE_SHA256
        ),
        "predecessor_qualification_failure_audit": qualification_failure,
        "repair_design_raw_sha256": repair_design["raw_sha256"],
        "repair_design": repair_design,
        "branch_completeness_addendum": branch_completeness_addendum,
        "branch_completeness_addendum_sha256": EXPECTED_BRANCH_COMPLETENESS_ADDENDUM_SHA256,
        "superseded_physical_supervisor_refusal_sha256": (
            EXPECTED_SUPERVISOR_REFUSAL_SHA256
        ),
        "superseded_physical_supervisor_refusal": superseded_refusal,
        "consumed_predecessor_physical_closure_sha256": (
            EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_SHA256
        ),
        "consumed_predecessor_physical_closure": predecessor_physical_closure,
        "dependency_manifest_raw_sha256": sha256_file(MANIFEST_PATH),
        "qualified_source_path_count": qualified_count,
        "qualified_source_path_sha256": qualified_digest,
        "dependency_receipt": dependency,
        "zero_world_receipt": zero_world,
        "worker_parse_receipt": worker_parse,
        "l14_component_qualification": l14_component_qualification,
        "static_source_receipt": static_source,
        "future_authority_tooling_receipt": future_authority_tooling,
        "source_authority_preflight_receipt": source_authority_preflight,
        "l14_qualified_source_retirement_audit": l14_qualification_retirement,
        "supervisor_receipt": supervisor,
        "runtime_identity": runtime,
        "positive_case_count": zero_world["positive_case_count"],
        "forced_failure_case_count": zero_world["forced_failure_case_count"],
        "physical_question_declared": True,
        "physical_question_opened": False,
        "physical_execution_authorized": False,
        "event_triggered_passive_recovery": True,
        "force_aware_recovery": False,
        "r10f_behavior_observed": False,
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
    receipt["qualification_receipt_contract_audit"] = (
        audit_qualification_receipt_contract(receipt)
    )
    try:
        receipt["qualification_directory_reader_contract_audit"] = (
            l14_pipeline.audit_reader_contract(receipt)
        )
    except ValueError as exc:
        raise AuditFailure(f"L14_QUALIFICATION_DIRECTORY_READER:{exc}") from exc
    return receipt


L15_CANDIDATE_MARKER = "QSDK_R10F_L15_QUALIFICATION_CANDIDATE_PASS "


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", type=Path, default=DEFAULT_GODOT)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--official-qualification", action="store_true")
    modes.add_argument("--l15-qualification-candidate", action="store_true")
    arguments = parser.parse_args()
    try:
        receipt = (
            audit_l15_qualification_candidate(arguments.godot.resolve())
            if arguments.l15_qualification_candidate
            else audit(
                arguments.godot.resolve(),
                official_qualification=arguments.official_qualification,
            )
        )
    except (AuditFailure, OSError, subprocess.TimeoutExpired) as exc:
        print(f"QSDK_R10F_ZERO_WORLD_IMPLEMENTATION_FAIL {exc}", file=sys.stderr)
        return 1
    marker = (
        L15_CANDIDATE_MARKER
        if arguments.l15_qualification_candidate
        else PASS_MARKER
    )
    print(marker + json.dumps(receipt, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
