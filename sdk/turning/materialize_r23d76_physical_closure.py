#!/usr/bin/env python3
"""Materialize and audit the immutable R23D76 physical closure.

R23D76 consumed its one authorized nine-cell finite decision.  All nine native
worlds completed their 2,992-step horizons and retained full CAS traces.  The
frozen evaluator accepted the complete Godot/Jolt and MuJoCo populations, but
rejected all three Rapier/Parry reports because Rust emitted Windows extended
length CAS paths (``\\\\?\\C:\\...``) while the inherited Python evaluator
compared them to equivalent non-prefixed paths (``C:\\...``).

This closure binds the exact source, qualification, adoption, physical files,
CAS payloads, official invalid classification, and narrow integration finding.
It does not rewrite a terminal, normalize retained evidence, rerun a world, or
promote the two accepted engine-local observations into a three-engine claim.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
from typing import Any, Mapping


REPO_ROOT = Path(__file__).resolve().parents[2]
EVIDENCE_ROOT = REPO_ROOT.parent / "SporeSpore_Evidence"
ARTIFACT_ROOT = EVIDENCE_ROOT / "artifacts" / "sha256"
QUALIFICATION_ROOT = (
    EVIDENCE_ROOT
    / "qsdk-r23d76-qualification-20260826T150900Z-1f3ca9e4"
)
PHYSICAL_ROOT = (
    EVIDENCE_ROOT
    / "qsdk-r23d76-physical-20260826T151849Z-1f3ca9e4-lca1-system-python"
)
CLOSURE_PATH = (
    REPO_ROOT
    / "sdk"
    / "turning"
    / "r23d76_production_route_three_engine_turning_validation_closure_v1.json"
)

SOURCE_COMMIT = "1f3ca9e472c50318cc4d531a5f9609bb9c66c93d"
SOURCE_TREE = "ff37837e44e77d7abda645f8e60a84fe38517033"
CAMPAIGN_ID = "QSDK-R23D76-FRESH-FINITE-THREE-ENGINE-TURNING-DECISION"
GATE_ID = "QSDK-R23D76"
ATTEMPT_ID = "9a12d254c49f4e0a9e5177b792f52184"
CLASSIFICATION = (
    "invalid_or_incomplete_exact_seed_23197_three_engine_portable_turning"
)
CLOSED_STATUS = (
    "closed_consumed_invalid_complete_rapier_windows_extended_"
    "cas_path_identity_failure"
)
ENGINES = ("godot_jolt", "rapier_parry", "mujoco")
ARMS = ("reference_zero", "positive_heading", "negative_heading")
CELL_IDS = [
    f"r23d76__{engine}__s23197__{arm}"
    for engine in ENGINES
    for arm in ARMS
]

SOURCE_PATHS = (
    "sdk/run_qsdk_r23d76_supervisor.ps1",
    "tests/test_sdk_qsdk_r23d76_godot_jolt_worker.gd",
    "sdk/adapters/rapier/src/qsdk_r23d76_turning_route.rs",
    "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d27_physical.rs",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d76_turning_route.py",
    "sdk/turning/r23d76_production_route_three_engine_turning_evaluator.py",
    "sdk/turning/r23d65_selected_profile_three_engine_turning_validation_evaluator.py",
    "sdk/turning/r23d76_receipt_contract.py",
    "sdk/turning/r23d76_production_route_runtime.py",
    "sdk/turning/r23d76_production_route_three_engine_turning_implementation_v1.json",
    "sdk/turning/r23d76_fresh_finite_three_engine_turning_decision_v1.json",
    "sdk/turning/r23d76_campaign_attestation_manifest_v1.json",
    "tests/test_qsdk_r23d76_zero_world_qualification_v3.ps1",
)

EXPECTED_QUALIFICATION_POPULATION = {
    "complete_file_population_count": 53,
    "complete_file_population_byte_count": 513419,
    "canonical_population_manifest_byte_length": 6225,
    "canonical_population_manifest_sha256": (
        "sha256:92d86afa5e1fba2b72e1be45a96a06efbb0ced5e5a37887d5b03eff5b3ed8f57"
    ),
}
EXPECTED_PHYSICAL_POPULATION = {
    "complete_file_population_count": 72,
    "complete_file_population_byte_count": 674518544,
    "canonical_population_manifest_byte_length": 10289,
    "canonical_population_manifest_sha256": (
        "sha256:e8098dfc110eb3933e9d9038e72410693cfb35a1dc1f58b4d3810a879b9c3298"
    ),
}
EXPECTED_QUALIFICATION_BINDINGS = {
    "attestation.json": (
        161586,
        "70c74233e70c185202e6c41b2ae4d1dd71c8cb480306efa70109a429ff626f53",
    ),
    "adoption.json": (
        3264,
        "6e833c399fe57d70bed1889547a743f4e1ae6c854169bcd86126814cf1f6b5ba",
    ),
}
EXPECTED_PHYSICAL_BINDINGS = {
    "attempt-authorization.json": (
        163438,
        "9cac2fba3afbb7fb449ac8454c10c889f57a2fe957f12045aa3a5996e8b9bc67",
    ),
    "authorization-preflight.json": (
        25569,
        "0be53c231a5c81608852d9498d0275e37ba497485029dcf777d709f9b6d1f95e",
    ),
    "physical-freeze.json": (
        328731,
        "64363d32a45a1c6901a6c33f5f658e270007056ae3d932f2cf26150cf7324318",
    ),
    "terminal-paths.json": (
        1435,
        "76ed6edd9d415301b706abebe08f73e01cd126ec7f25d5c33265b3cf03c12341",
    ),
    "complete-evaluation.json": (
        15731,
        "9789ebb79ac5d8b88d44dbd984a75e90b0e24ab68f443a34aced7fa911cc51a3",
    ),
    "report.json": (
        51416,
        "a33b63bfadb8b9ccadb0c00d0fe677a5c89f4b23c1c450b746367e63beebbeeb",
    ),
    "completion.json": (
        2927,
        "022764ea13d6302500cfc431dd550a4bb1a462d2d35eed832da5b0e3825cb73c",
    ),
}


class ClosureError(RuntimeError):
    """Fail-closed R23D76 closure error."""


def require(condition: bool, code: str) -> None:
    if not condition:
        raise ClosureError(code)


def sha256_bytes(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(value, dict), f"JSON_NOT_OBJECT:{path}")
    return value


def canonical_json(value: Any) -> str:
    return json.dumps(value, indent=2, ensure_ascii=False) + "\n"


def git(*arguments: str, binary: bool = False) -> str | bytes:
    process = subprocess.run(
        ["git", *arguments],
        cwd=REPO_ROOT,
        check=False,
        capture_output=True,
        text=not binary,
    )
    require(process.returncode == 0, "GIT_FAILED:" + ":".join(arguments))
    return process.stdout if binary else process.stdout.strip()


def file_binding(path: Path) -> dict[str, Any]:
    return {
        "path": path.resolve().as_posix(),
        "byte_length": path.stat().st_size,
        "raw_sha256": "sha256:" + sha256_file(path),
    }


def verify_file(path: Path, expected: tuple[int, str]) -> None:
    require(path.is_file(), f"FILE_MISSING:{path}")
    require(path.stat().st_size == expected[0], f"FILE_SIZE_DRIFT:{path}")
    require(sha256_file(path) == expected[1], f"FILE_DIGEST_DRIFT:{path}")


def source_binding(relative: str) -> dict[str, Any]:
    raw = git("show", f"{SOURCE_COMMIT}:{relative}", binary=True)
    require(isinstance(raw, bytes), f"SOURCE_BYTES_INVALID:{relative}")
    object_id = git("rev-parse", f"{SOURCE_COMMIT}:{relative}")
    require(isinstance(object_id, str), f"SOURCE_OBJECT_INVALID:{relative}")
    return {
        "path": relative,
        "git_blob_oid": object_id,
        "byte_length": len(raw),
        "raw_sha256": "sha256:" + sha256_bytes(raw),
    }


def source_text(relative: str) -> str:
    raw = git("show", f"{SOURCE_COMMIT}:{relative}", binary=True)
    require(isinstance(raw, bytes), f"SOURCE_TEXT_INVALID:{relative}")
    return raw.decode("utf-8")


def population_identity(root: Path) -> dict[str, Any]:
    files = sorted(
        (path for path in root.rglob("*") if path.is_file()),
        key=lambda path: path.relative_to(root).as_posix(),
    )
    lines: list[str] = []
    byte_count = 0
    for path in files:
        relative = path.relative_to(root).as_posix()
        size = path.stat().st_size
        digest = sha256_file(path)
        lines.append(f"{relative}\t{size}\tsha256:{digest}\n")
        byte_count += size
    manifest = "".join(lines).encode("utf-8")
    return {
        "complete_file_population_count": len(files),
        "complete_file_population_byte_count": byte_count,
        "canonical_population_manifest_byte_length": len(manifest),
        "canonical_population_manifest_sha256": (
            "sha256:" + sha256_bytes(manifest)
        ),
    }


def false_claims(value: Any) -> bool:
    return isinstance(value, dict) and all(item is False for item in value.values())


def verify_source() -> list[dict[str, Any]]:
    require(
        git("rev-parse", "--show-toplevel") == REPO_ROOT.as_posix(),
        "REPOSITORY_ROOT_INVALID",
    )
    require(
        git("remote", "get-url", "origin")
        == "https://github.com/Slagathore/sporespore.git",
        "REMOTE_INVALID",
    )
    require(
        git("rev-parse", f"{SOURCE_COMMIT}^{{tree}}") == SOURCE_TREE,
        "SOURCE_TREE_INVALID",
    )
    ancestor = subprocess.run(
        ["git", "merge-base", "--is-ancestor", SOURCE_COMMIT, "origin/main"],
        cwd=REPO_ROOT,
        check=False,
        capture_output=True,
    )
    require(ancestor.returncode == 0, "SOURCE_NOT_REACHABLE_FROM_ORIGIN_MAIN")

    rapier = source_text("sdk/adapters/rapier/src/qsdk_r23d76_turning_route.rs")
    inherited = source_text(
        "sdk/turning/"
        "r23d65_selected_profile_three_engine_turning_validation_evaluator.py"
    )
    require(
        ".join(\"../../..\")\n        .canonicalize()" in rapier
        and "match run_r23d76_rapier_physical_core" in rapier,
        "PINNED_RAPIER_CANONICALIZATION_SOURCE_CHANGED",
    )
    require(
        "recorded_payload = Path(str(artifact.get(\"payload_path\", \"\"))).resolve(strict=True)"
        in inherited
        and "if recorded_payload != payload or recorded_manifest != manifest_path:"
        in inherited
        and 'return ["R23D65_TRACE_ARTIFACT_CAS_PATH"]' in inherited,
        "PINNED_EVALUATOR_PATH_IDENTITY_SOURCE_CHANGED",
    )
    return [source_binding(relative) for relative in SOURCE_PATHS]


def verify_qualification() -> dict[str, Any]:
    require(QUALIFICATION_ROOT.is_dir(), "QUALIFICATION_ROOT_MISSING")
    require(
        population_identity(QUALIFICATION_ROOT)
        == EXPECTED_QUALIFICATION_POPULATION,
        "QUALIFICATION_POPULATION_DRIFT",
    )
    for relative, expected in EXPECTED_QUALIFICATION_BINDINGS.items():
        verify_file(QUALIFICATION_ROOT / relative, expected)

    attestation = load_json(QUALIFICATION_ROOT / "attestation.json")
    adoption = load_json(QUALIFICATION_ROOT / "adoption.json")
    require(
        attestation.get("campaign_id") == CAMPAIGN_ID
        and attestation.get("source", {}).get("commit") == SOURCE_COMMIT
        and attestation.get("source", {}).get("tree_git_oid") == SOURCE_TREE
        and attestation.get("global_gate_count") == 12
        and attestation.get("lineage_gate_count") == 2
        and attestation.get("campaign_gate_count") == 3
        and attestation.get("executed_gate_count") == 17
        and attestation.get("all_gates_executed") is True
        and attestation.get("all_gate_streams_content_addressed") is True
        and attestation.get("commissioned") is False
        and attestation.get("claims", {}).get("physical_campaign_executed") is False
        and attestation.get("claims", {}).get("turning_acceptance") is False,
        "QUALIFICATION_ATTESTATION_INVALID",
    )
    require(
        adoption.get("campaign_id") == CAMPAIGN_ID
        and adoption.get("source_commit") == SOURCE_COMMIT
        and adoption.get("source_tree_git_oid") == SOURCE_TREE
        and adoption.get("executed_gate_count") == 17
        and adoption.get("physical_launch_prerequisite_satisfied") is True
        and adoption.get("physical_acceptance_authority") is False
        and adoption.get("release_authority") is False,
        "QUALIFICATION_ADOPTION_INVALID",
    )
    return {
        "root": QUALIFICATION_ROOT.resolve().as_posix(),
        "population_identity": EXPECTED_QUALIFICATION_POPULATION,
        "attestation": file_binding(QUALIFICATION_ROOT / "attestation.json"),
        "adoption": file_binding(QUALIFICATION_ROOT / "adoption.json"),
        "global_gate_count": 12,
        "lineage_gate_count": 2,
        "campaign_role_gate_count": 3,
        "executed_gate_count": 17,
        "campaign_local_qualification_passed": True,
        "physical_launch_prerequisite_satisfied": True,
        "qualification_world_count": 0,
        "physical_acceptance_authority": False,
    }


def verify_trace_artifact(
    terminal: Mapping[str, Any], engine: str
) -> tuple[dict[str, Any], bool]:
    artifact = terminal.get("trace_artifact")
    require(isinstance(artifact, Mapping), f"TRACE_ARTIFACT_INVALID:{engine}")
    digest = str(artifact.get("sha256", ""))
    digest_hex = digest.removeprefix("sha256:")
    require(
        len(digest_hex) == 64
        and all(character in "0123456789abcdef" for character in digest_hex),
        f"TRACE_DIGEST_INVALID:{engine}",
    )
    recorded_payload_raw = str(artifact.get("payload_path", ""))
    recorded_manifest_raw = str(artifact.get("manifest_path", ""))
    recorded_payload = Path(recorded_payload_raw).resolve(strict=True)
    recorded_manifest = Path(recorded_manifest_raw).resolve(strict=True)
    expected_directory = (ARTIFACT_ROOT / digest_hex).resolve(strict=True)
    expected_payload = (expected_directory / "payload.bin").resolve(strict=True)
    expected_manifest = (expected_directory / "manifest.json").resolve(strict=True)
    path_identity_equal = (
        recorded_payload == expected_payload
        and recorded_manifest == expected_manifest
    )
    if engine == "rapier_parry":
        require(
            recorded_payload_raw.startswith("\\\\?\\")
            and recorded_manifest_raw.startswith("\\\\?\\")
            and not path_identity_equal,
            "RAPIER_EXTENDED_PATH_OBSERVATION_INVALID",
        )
    else:
        require(path_identity_equal, f"NATIVE_CAS_PATH_INVALID:{engine}")

    raw = expected_payload.read_bytes()
    manifest = load_json(expected_manifest)
    require(
        "sha256:" + sha256_bytes(raw) == digest
        and len(raw) == artifact.get("byte_length")
        and manifest.get("schema_version")
        == "sporespore_content_addressed_artifact_manifest_v1"
        and manifest.get("algorithm") == "sha256"
        and manifest.get("sha256") == digest
        and manifest.get("byte_length") == len(raw)
        and manifest.get("payload_name") == "payload.bin"
        and manifest.get("media_type") == "application/x-ndjson",
        f"TRACE_CAS_BYTES_INVALID:{engine}",
    )
    return (
        {
            "receipt": dict(artifact),
            "expected_payload": file_binding(expected_payload),
            "expected_manifest": file_binding(expected_manifest),
            "recorded_path_exists": recorded_payload.is_file(),
            "expected_path_exists": expected_payload.is_file(),
            "recorded_and_expected_path_identity_equal": path_identity_equal,
            "recorded_and_expected_bytes_identical": True,
        },
        path_identity_equal,
    )


def verify_physical() -> dict[str, Any]:
    require(PHYSICAL_ROOT.is_dir(), "PHYSICAL_ROOT_MISSING")
    require(
        population_identity(PHYSICAL_ROOT) == EXPECTED_PHYSICAL_POPULATION,
        "PHYSICAL_POPULATION_DRIFT",
    )
    for relative, expected in EXPECTED_PHYSICAL_BINDINGS.items():
        verify_file(PHYSICAL_ROOT / relative, expected)

    attempt = load_json(PHYSICAL_ROOT / "attempt-authorization.json")
    preflight = load_json(PHYSICAL_ROOT / "authorization-preflight.json")
    freeze = load_json(PHYSICAL_ROOT / "physical-freeze.json")
    report = load_json(PHYSICAL_ROOT / "report.json")
    evaluation = load_json(PHYSICAL_ROOT / "complete-evaluation.json")
    completion = load_json(PHYSICAL_ROOT / "completion.json")
    require(
        attempt.get("schema_version") == "sporespore_qsdk_r23d76_physical_attempt_v1"
        and attempt.get("campaign_id") == CAMPAIGN_ID
        and attempt.get("attempt_id") == ATTEMPT_ID
        and attempt.get("source_commit") == SOURCE_COMMIT
        and attempt.get("ordered_cell_ids") == CELL_IDS
        and attempt.get("physical_execution_authorized") is True
        and attempt.get("single_use_supervisor_authorization") is True
        and attempt.get("matrix_authorization_immutable_before_first_world") is True
        and attempt.get("operation_lock_held") is True
        and attempt.get("one_shot_attempt_unconsumed") is True,
        "ATTEMPT_AUTHORIZATION_INVALID",
    )
    require(
        preflight.get("receipt_count") == 9
        and preflight.get("pass_count") == 9
        and preflight.get("complete_matrix_passed") is True
        and preflight.get("model_construction_count") == 0
        and preflight.get("world_attempt_count") == 0
        and preflight.get("world_build_count") == 0
        and preflight.get("physical_acceptance_authority") is False,
        "AUTHORIZATION_PREFLIGHT_INVALID",
    )
    require(
        freeze.get("source_commit") == SOURCE_COMMIT
        and freeze.get("source_tree_git_oid") == SOURCE_TREE
        and freeze.get("origin_main_commit") == SOURCE_COMMIT
        and freeze.get("live_github_main_commit") == SOURCE_COMMIT
        and freeze.get("source_worktree_clean") is True
        and freeze.get("clean_pushed_zero_world_qualification_adopted") is True
        and freeze.get("campaign_attestation_adoption_sha256")
        == "sha256:" + EXPECTED_QUALIFICATION_BINDINGS["adoption.json"][1]
        and freeze.get("declared_world_count") == 9
        and freeze.get("ordered_cell_ids") == CELL_IDS
        and freeze.get("serial_execution_required") is True
        and freeze.get("all_cells_run_regardless_of_intermediate_outcome") is True,
        "PHYSICAL_FREEZE_INVALID",
    )
    require(
        evaluation.get("classification") == CLASSIFICATION
        and evaluation.get("cell_count") == 9
        and evaluation.get("fresh_held_out_seed_consumed") is True
        and evaluation.get("fresh_held_out_seed_count") == 1
        and evaluation.get("turning_gate_invoked") is True
        and evaluation.get("cross_engine_equivalence_test_invoked") is False
        and evaluation.get("population_inference_attempted") is False
        and evaluation.get("posthoc_threshold_or_selector_change_performed") is False
        and evaluation.get("finite_decision", {}).get("matrix_execution_valid") is False
        and evaluation.get("finite_decision", {}).get(
            "finite_three_engine_turning_positive"
        )
        is False
        and false_claims(evaluation.get("claims")),
        "COMPLETE_EVALUATION_INVALID",
    )
    require(
        report.get("result_classification") == CLASSIFICATION
        and report.get("attempt_id") == ATTEMPT_ID
        and report.get("source", {}).get("commit") == SOURCE_COMMIT
        and len(report.get("ordered_cells", [])) == 9
        and report.get("all_nine_cells_executed_or_retained_as_failures") is True
        and report.get("world_build_count_exact") is True
        and report.get("world_build_count_lower_bound") == 9
        and report.get("world_build_count_upper_bound") == 9
        and report.get("physical_acceptance_authority") is False,
        "REPORT_INVALID",
    )
    require(
        completion.get("status") == CLASSIFICATION
        and completion.get("attempt_id") == ATTEMPT_ID
        and completion.get("source_commit") == SOURCE_COMMIT
        and completion.get("cell_count") == 9
        and completion.get("world_count") == 9
        and completion.get("world_count_exact") is True
        and completion.get("finite_three_engine_turning_positive") is False
        and completion.get("one_shot_attempt_consumed") is True
        and completion.get("replacement_or_selective_rerun_permitted") is False
        and completion.get("physical_acceptance_authority") is False,
        "COMPLETION_INVALID",
    )

    evaluations = {
        str(value.get("cell_id")): value
        for value in evaluation.get("cell_evaluations", [])
    }
    retained_cells: list[dict[str, Any]] = []
    rapier_path_mismatches: list[dict[str, Any]] = []
    for engine in ENGINES:
        for arm in ARMS:
            cell_id = f"r23d76__{engine}__s23197__{arm}"
            terminal_path = PHYSICAL_ROOT / "cells" / cell_id / "terminal.json"
            terminal = load_json(terminal_path)
            require(
                terminal.get("schema_version")
                == "sporespore_qsdk_r23d76_engine_cell_report_v1"
                and terminal.get("campaign_id") == CAMPAIGN_ID
                and terminal.get("cell_id") == cell_id
                and terminal.get("engine_id") == engine
                and terminal.get("arm_id") == arm
                and terminal.get("source_commit") == SOURCE_COMMIT
                and terminal.get("execution", {}).get("world_attempt_count") == 1
                and terminal.get("execution", {}).get("world_build_count") == 1
                and terminal.get("execution", {}).get(
                    "controller_semantic_step_count"
                )
                == 2992
                and terminal.get("trace_summary", {}).get("row_count") == 2992
                and terminal.get("physical_acceptance_authority") is False,
                f"TERMINAL_INVALID:{cell_id}",
            )
            trace, path_equal = verify_trace_artifact(terminal, engine)
            cell_evaluation = evaluations.get(cell_id)
            require(isinstance(cell_evaluation, dict), f"CELL_EVALUATION_MISSING:{cell_id}")
            if engine == "rapier_parry":
                require(
                    cell_evaluation.get("execution_valid") is False
                    and cell_evaluation.get("common_physical_gate_passed") is False
                    and cell_evaluation.get("failed_gate_ids")
                    == ["R23D65_TRACE_ARTIFACT_CAS_PATH"]
                    and not path_equal,
                    f"RAPIER_OFFICIAL_INVALIDITY_CHANGED:{cell_id}",
                )
                rapier_path_mismatches.append(
                    {
                        "cell_id": cell_id,
                        "recorded_payload_path": terminal["trace_artifact"]["payload_path"],
                        "expected_payload_path": trace["expected_payload"]["path"],
                        "recorded_and_expected_path_identity_equal": False,
                        "recorded_and_expected_bytes_identical": True,
                        "official_failure_code": "R23D65_TRACE_ARTIFACT_CAS_PATH",
                    }
                )
            else:
                require(
                    cell_evaluation.get("execution_valid") is True
                    and cell_evaluation.get("common_physical_gate_passed") is True
                    and cell_evaluation.get("failed_gate_ids") == []
                    and path_equal,
                    f"ENGINE_CELL_RESULT_CHANGED:{cell_id}",
                )
            retained_cells.append(
                {
                    "cell_id": cell_id,
                    "engine_id": engine,
                    "arm_id": arm,
                    "terminal": file_binding(terminal_path),
                    "world_attempt_count": 1,
                    "world_build_count": 1,
                    "controller_semantic_step_count": 2992,
                    "retained_trace_row_count": 2992,
                    "trace_artifact": trace,
                    "official_execution_valid": cell_evaluation["execution_valid"],
                    "official_common_physical_gate_passed": cell_evaluation[
                        "common_physical_gate_passed"
                    ],
                    "official_failed_gate_ids": cell_evaluation["failed_gate_ids"],
                }
            )

    engine_results = evaluation["finite_decision"]["engine_results"]
    require(
        engine_results["godot_jolt"]["passed"] is True
        and engine_results["godot_jolt"]["cycle_integrated_measurement"]["passed"]
        is True
        and engine_results["mujoco"]["passed"] is True
        and engine_results["mujoco"]["cycle_integrated_measurement"]["passed"]
        is True
        and engine_results["rapier_parry"]["passed"] is False
        and engine_results["rapier_parry"]["cycle_integrated_measurement"] is None,
        "ENGINE_RESULT_PROJECTION_CHANGED",
    )
    return {
        "root": PHYSICAL_ROOT.resolve().as_posix(),
        "population_identity": EXPECTED_PHYSICAL_POPULATION,
        "selected_artifacts": {
            relative: file_binding(PHYSICAL_ROOT / relative)
            for relative in EXPECTED_PHYSICAL_BINDINGS
        },
        "attempt_id": ATTEMPT_ID,
        "campaign_seed": 23197,
        "authorization_preflight_count": 9,
        "authorization_preflight_pass_count": 9,
        "world_attempt_count": 9,
        "world_build_count": 9,
        "complete_native_horizon_count": 9,
        "retained_trace_count": 9,
        "retained_trace_row_count": 26928,
        "retained_cells": retained_cells,
        "engine_results": engine_results,
        "rapier_path_mismatches": rapier_path_mismatches,
    }


def materialize() -> dict[str, Any]:
    source_bindings = verify_source()
    qualification = verify_qualification()
    physical = verify_physical()
    return {
        "schema_version": (
            "sporespore_qsdk_r23d76_production_route_three_engine_"
            "turning_validation_closure_v1"
        ),
        "closure_id": (
            "QSDK-R23D76-PRODUCTION-ROUTE-THREE-ENGINE-"
            "TURNING-VALIDATION-CLOSURE-V1"
        ),
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "status": CLOSED_STATUS,
        "ledger_scope": {
            "subsystem": "turning",
            "engine_scope": "3e",
            "authority_mode": "physical_closure",
            "question_class": "finite_decision",
        },
        "source_authority": {
            "source_commit": SOURCE_COMMIT,
            "source_tree_git_oid": SOURCE_TREE,
            "branch": "main",
            "origin_url": "https://github.com/Slagathore/sporespore.git",
            "source_was_clean_pushed_and_live_equal": True,
            "source_bindings": source_bindings,
        },
        "qualification_and_adoption": qualification,
        "retained_physical_attempt": physical,
        "official_result": {
            "classification": CLASSIFICATION,
            "complete_finite_evaluator_completed": True,
            "matrix_execution_valid": False,
            "finite_three_engine_turning_positive": False,
            "valid_three_engine_turning_result_available": False,
            "fresh_held_out_seed_consumed": True,
            "campaign_identity_consumed": True,
            "same_identity_rerun_allowed": False,
            "replacement_or_selective_rerun_allowed": False,
            "historical_result_reinterpreted": False,
            "posthoc_threshold_selector_evaluator_or_result_change_count": 0,
            "cross_engine_equivalence_test_invoked": False,
            "population_inference_attempted": False,
            "release_score_before": "10/25",
            "release_score_after": "10/25",
        },
        "integration_finding": {
            "finding_id": (
                "r23d76_rapier_windows_extended_cas_path_identity_failure_v1"
            ),
            "affected_engine": "rapier_parry",
            "affected_cell_count": 3,
            "official_failure_code": "R23D65_TRACE_ARTIFACT_CAS_PATH",
            "producer_recorded_windows_extended_length_paths": True,
            "evaluator_constructed_equivalent_non_prefixed_paths": True,
            "recorded_and_expected_paths_both_exist": True,
            "recorded_and_expected_payload_bytes_identical": True,
            "pathlib_path_identity_equal": False,
            "deterministic_evidence_transport_invalidity": True,
            "physics_failure_established": False,
            "threshold_selector_or_behavior_failure_established": False,
            "rapier_turning_positive_or_valid_negative_established": False,
            "godot_jolt_frozen_turning_gates_passed": True,
            "mujoco_frozen_turning_gates_passed": True,
            "rapier_path_mismatches": physical["rapier_path_mismatches"],
        },
        "next_work": {
            "preserve_r23d76_unchanged": True,
            "normalize_or_compare_windows_cas_paths_by_file_identity_in_a_distinct_successor": True,
            "focused_actual_rapier_cas_receipt_conformance_required_before_more_physics": True,
            "full_seeded_ghost_required": False,
            "same_seed_or_same_campaign_rerun_allowed": False,
            "fresh_finite_decision_required_for_q_sdk_r23": True,
        },
        "closure_materializer_path": (
            "sdk/turning/materialize_r23d76_physical_closure.py"
        ),
        "closure_audit_path": "tests/test_qsdk_r23d76_physical_closure.ps1",
        "claims": {
            "campaign_closed": True,
            "retained_physical_population_exact": True,
            "campaign_identity_consumed": True,
            "complete_nine_cell_native_population_observed": True,
            "nine_complete_native_horizons_observed": True,
            "nine_complete_traces_retained": True,
            "godot_jolt_frozen_turning_gates_passed": True,
            "mujoco_frozen_turning_gates_passed": True,
            "historical_result_reinterpreted": False,
            "finite_three_engine_turning": False,
            "portable_basic_turning": False,
            "q_sdk_r23_satisfied": False,
            "cross_engine_equivalence": False,
            "arbitrary_quadruped_coverage": False,
            "population_robustness": False,
            "prone_to_standing": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    value = materialize()
    raw = canonical_json(value)
    if args.check:
        require(CLOSURE_PATH.is_file(), "CLOSURE_MISSING")
        require(CLOSURE_PATH.read_text(encoding="utf-8") == raw, "CLOSURE_DRIFT")
    else:
        require(not CLOSURE_PATH.exists(), "CLOSURE_REFUSES_OVERWRITE")
        CLOSURE_PATH.write_text(raw, encoding="utf-8", newline="\n")
    print(
        "QSDK_R23D76_PHYSICAL_CLOSURE "
        + json.dumps(
            {
                "passed": True,
                "check_only": args.check,
                "status": CLOSED_STATUS,
                "attempt_id": ATTEMPT_ID,
                "qualification_gates": 17,
                "authorization_receipts": 9,
                "worlds": 9,
                "complete_horizons": 9,
                "godot_jolt_turning_gates_passed": True,
                "mujoco_turning_gates_passed": True,
                "rapier_cas_path_invalid_cells": 3,
                "finite_three_engine_turning": False,
                "release_score": "10/25",
                "physical_acceptance_authority": False,
            },
            sort_keys=True,
            separators=(",", ":"),
        )
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ClosureError, OSError, UnicodeError, ValueError, json.JSONDecodeError) as error:
        raise SystemExit(
            f"QSDK_R23D76_PHYSICAL_CLOSURE {type(error).__name__}:{error}"
        ) from error
