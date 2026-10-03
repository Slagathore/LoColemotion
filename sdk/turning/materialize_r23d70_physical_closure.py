#!/usr/bin/env python3
"""Materialize and audit the immutable R23D70 physical closure.

R23D70 passed complete zero-world qualification and adoption, then consumed its
one-shot finite identity.  The first Godot/Jolt worker completed one genuine
2,992-step native horizon and retained its trace, but its success terminal
contained both the canonical ``execution`` object and stale root execution
counters.  The shared terminal projector rejected that ambiguous shape before
the terminal could be retained as a cell result.  Eight declared cells never
opened and no behavior evaluator ran.

This tool binds that exact integration-invalid result.  It never evaluates the
retained measurements, changes a threshold, or turns the incomplete campaign
into a movement result.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
from typing import Any, Iterable


REPO_ROOT = Path(__file__).resolve().parents[2]
PROJECT_STATE_ROOT = REPO_ROOT.parent / "SporeSpore_Evidence"
EVIDENCE_ROOT = (
    PROJECT_STATE_ROOT
    / "qsdk-r23d70-physical-20260826T044117Z-fc79836b-lca1-python"
)
QUALIFICATION_ROOT = (
    PROJECT_STATE_ROOT
    / "qsdk-r23d70-qualification-20260826T043433Z-fc79836b-lca1-python"
)
INCOMPATIBLE_QUALIFICATION_ROOT = (
    PROJECT_STATE_ROOT
    / "qsdk-r23d70-qualification-20260826T042520Z-fc79836b-commissioned-python"
)
ARTIFACT_ROOT = PROJECT_STATE_ROOT / "artifacts" / "sha256"
CLOSURE_PATH = (
    REPO_ROOT
    / "sdk"
    / "turning"
    / "r23d70_trace_retention_receipt_contract_repaired_three_engine_turning_validation_closure_v1.json"
)
AUDIT_PATH = REPO_ROOT / "tests" / "test_qsdk_r23d70_physical_closure.ps1"
RELEASE_PATH = REPO_ROOT / "sdk" / "release" / "quadruped_release_contract.json"
SUPPORT_PATH = REPO_ROOT / "sdk" / "release" / "quadruped_support_matrix.json"

SOURCE_COMMIT = "fc79836bf440e9958e6d05179834c9fe44c7acf5"
SOURCE_TREE = "79f0c1dfcc7e1e6b36d089ac633f4539fdada827"
CAMPAIGN_ID = (
    "QSDK-R23D70-TRACE-RETENTION-RECEIPT-CONTRACT-REPAIRED-"
    "THREE-ENGINE-TURNING-VALIDATION"
)
GATE_ID = "QSDK-R23D70"
ATTEMPT_ID = "ed4fbaf292584279a8796ed9678026c8"
CLOSED_STATUS = (
    "closed_consumed_invalid_incomplete_after_one_native_world_"
    "success_terminal_execution_projection_shape_ambiguity"
)
CLASSIFICATION = "invalid_or_incomplete_exact_seed_23189_three_engine_portable_turning"
CLOSURE_RELATIVE = (
    "sdk/turning/"
    "r23d70_trace_retention_receipt_contract_repaired_three_engine_turning_"
    "validation_closure_v1.json"
)
AUDIT_RELATIVE = "tests/test_qsdk_r23d70_physical_closure.ps1"
OBSERVED_CELL_ID = "r23d70__godot_jolt__s23189__reference_zero"
TERMINAL_PREFIX = "QSDK_R23D70_GODOT_JOLT_TERMINAL "
TERMINATION_PREFIX = "QSDK_R23D65_GODOT_SUPERVISOR_TERMINATION_READY "
PROJECTOR_FAILURE = (
    "TERMINAL_EXECUTION_PROJECTION_SUCCESS_SHAPE_INVALID:"
    "sporespore_qsdk_r23d70_engine_cell_report_v1"
)

ENGINES = ("godot_jolt", "rapier_parry", "mujoco")
ARMS = ("reference_zero", "positive_heading", "negative_heading")
CELL_IDS = [
    f"r23d70__{engine}__s23189__{arm}"
    for engine in ENGINES
    for arm in ARMS
]
UNOPENED_CELL_IDS = CELL_IDS[1:]

SOURCE_BLOBS = {
    "sdk/run_qsdk_r23d70_supervisor.ps1": "ae50c0318145108244f2107d24d0b4c2858812cd",
    "sdk/locomotion_terminal_execution_projection.ps1": (
        "502317e88272dd928ff8bc6096e852f7b18dcc6a"
    ),
    "tests/test_sdk_qsdk_r23d70_godot_jolt_worker.gd": (
        "bbfd9505c3b371feeb925b24825d982931ef5e8d"
    ),
    "sdk/adapters/rapier/src/qsdk_r23d70_turning_route.rs": (
        "8281e79e7dba2c943e0401744f57d45154c3641d"
    ),
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d70_turning_route.py": (
        "7ecfd7ac4a826275a33a4a1c467fc1cffee8243f"
    ),
    "sdk/turning/r23d70_production_route_runtime.py": (
        "645b8a06fcd5368bc38e2cc343ee9f565e0f8099"
    ),
    "sdk/turning/r23d70_receipt_contract.py": (
        "6f3d27c7ed04b569b307f8717708f099e11aca9e"
    ),
    "sdk/turning/r23d70_production_route_three_engine_turning_implementation_v1.json": (
        "0696f9db3acc7d6edbc1afd4aa12541e16c1c817"
    ),
}

EXPECTED_PHYSICAL_POPULATION = {
    "complete_file_population_count": 26,
    "complete_file_population_byte_count": 70628011,
    "retained_unique_digest_count": 17,
    "cas_backed_file_count": 25,
    "non_cas_file_count": 1,
    "non_cas_relative_paths": [
        "pending-traces/r23d70__godot_jolt__s23189__reference_zero.rows.json"
    ],
    "canonical_population_manifest_format": (
        "relative_path<TAB>byte_length<TAB>sha256:<lowercase_hex><LF>"
    ),
    "canonical_population_manifest_sort_order": (
        "relative_path_unicode_codepoint_ascending"
    ),
    "canonical_population_manifest_byte_length": 3733,
    "canonical_population_manifest_sha256": (
        "sha256:e1cc63926494bf66916b2ecbe2624c68d638f7ef3b5e84186cd0ccab58c865c8"
    ),
}

EXPECTED_QUALIFICATION_POPULATION = {
    "complete_file_population_count": 50,
    "complete_file_population_byte_count": 497818,
    "canonical_population_manifest_format": (
        "relative_path<TAB>byte_length<TAB>sha256:<lowercase_hex><LF>"
    ),
    "canonical_population_manifest_sort_order": (
        "relative_path_unicode_codepoint_ascending"
    ),
    "canonical_population_manifest_byte_length": 5842,
    "canonical_population_manifest_sha256": (
        "sha256:3924c1ad30914ec9b20e2c08a3880e786741e50330471bd9c75e28d9ca867906"
    ),
}

EXPECTED_INCOMPATIBLE_QUALIFICATION_POPULATION = {
    "complete_file_population_count": 49,
    "complete_file_population_byte_count": 495213,
    "canonical_population_manifest_format": (
        "relative_path<TAB>byte_length<TAB>sha256:<lowercase_hex><LF>"
    ),
    "canonical_population_manifest_sort_order": (
        "relative_path_unicode_codepoint_ascending"
    ),
    "canonical_population_manifest_byte_length": 5751,
    "canonical_population_manifest_sha256": (
        "sha256:4e69f6f79e9ccc92bc7f8eb9e3ce52d4a74a6e620961ddbb0f9a3e26ad5728fb"
    ),
}

FILE_BINDINGS = {
    "physical-freeze.json": (
        323208,
        "293a6731d6348e8ee91e83a1b73ffd52629b733a64a7027f324ebef837711c08",
    ),
    "attempt-authorization.json": (
        160665,
        "d4758499f7ef45aece2ab345859793d3950bf8c9949c14d8dd1ad0bdb467cadf",
    ),
    "authorization-preflight.json": (
        26116,
        "eae0cc949290f1c240ec06cea74144196e7d51bfc66d3f58a3b88a18c2e7248f",
    ),
    "completion.json": (
        708,
        "b5c7151c5e71fd134bae92fd699f4cc7a632b35fee06c3f3638dbcad77ba9bf1",
    ),
    f"cells/{OBSERVED_CELL_ID}/stdout.txt": (
        79558,
        "eef8a5f64998e1094dd1e102778901f27dcdd109c9baf80780c1f394a8ccfc29",
    ),
    f"cells/{OBSERVED_CELL_ID}/stderr.txt": (
        0,
        "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    ),
    f"traces/{OBSERVED_CELL_ID}.ndjson": (
        35014316,
        "6e38ae906cda5d53411cca091c93cb288e19879398a1f56f72381ed56ee35543",
    ),
    f"pending-traces/{OBSERVED_CELL_ID}.rows.json": (
        35014521,
        "c8a158e6e81a7e55cf1962109ed3ee90fe99846b2d3f88108a17a2ac40db540c",
    ),
}

QUALIFICATION_BINDINGS = {
    "attestation.json": (
        152336,
        "e5eadad1d5572e337a5889f1b18228ee3a23c02ae0836b460b1a586c595e05cd",
    ),
    "adoption.json": (
        3307,
        "9ad04358e03f9b0a7cf6a5cda987c8243b52994a50afb7ceb4b0853d96a124a7",
    ),
}

INCOMPATIBLE_ATTESTATION_BINDING = (
    152779,
    "c598b88a876b143e98f1ce485fde8f4efa22dc68c004d2565426b4765ec63584",
)


class ClosureError(RuntimeError):
    """Fail-closed R23D70 closure error."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ClosureError(message)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def binding(path: Path) -> dict[str, Any]:
    return {
        "path": path.resolve().as_posix(),
        "raw_sha256": f"sha256:{sha256(path)}",
        "byte_length": path.stat().st_size,
    }


def verify_file(path: Path, expected: tuple[int, str]) -> None:
    require(path.is_file(), f"missing retained file: {path}")
    require(path.stat().st_size == expected[0], f"byte length drift: {path}")
    require(sha256(path) == expected[1], f"digest drift: {path}")


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def canonical_json(value: Any) -> str:
    return json.dumps(value, indent=2, ensure_ascii=False) + "\n"


def git(*arguments: str) -> str:
    process = subprocess.run(
        ["git", *arguments],
        cwd=REPO_ROOT,
        check=False,
        capture_output=True,
        text=True,
    )
    require(
        process.returncode == 0,
        f"git failed: {' '.join(arguments)}: {process.stderr}",
    )
    return process.stdout.strip()


def source_text(relative: str) -> str:
    process = subprocess.run(
        ["git", "show", f"{SOURCE_COMMIT}:{relative}"],
        cwd=REPO_ROOT,
        check=False,
        capture_output=True,
    )
    require(process.returncode == 0, f"pinned source unavailable: {relative}")
    return process.stdout.decode("utf-8")


def population_identity(root: Path, *, cas_check: bool) -> dict[str, Any]:
    files = sorted(path for path in root.rglob("*") if path.is_file())
    lines: list[str] = []
    digests: set[str] = set()
    non_cas: list[str] = []
    total_bytes = 0
    for path in files:
        relative = path.relative_to(root).as_posix()
        raw = sha256(path)
        size = path.stat().st_size
        lines.append(f"{relative}\t{size}\tsha256:{raw}\n")
        digests.add(raw)
        total_bytes += size
        if cas_check:
            payload = ARTIFACT_ROOT / raw / "payload.bin"
            if (
                not payload.is_file()
                or payload.stat().st_size != size
                or sha256(payload) != raw
            ):
                non_cas.append(relative)
    manifest = "".join(lines).encode("utf-8")
    value: dict[str, Any] = {
        "complete_file_population_count": len(files),
        "complete_file_population_byte_count": total_bytes,
    }
    if cas_check:
        value.update(
            retained_unique_digest_count=len(digests),
            cas_backed_file_count=len(files) - len(non_cas),
            non_cas_file_count=len(non_cas),
            non_cas_relative_paths=non_cas,
        )
    value.update(
        canonical_population_manifest_format=(
            "relative_path<TAB>byte_length<TAB>sha256:<lowercase_hex><LF>"
        ),
        canonical_population_manifest_sort_order=(
            "relative_path_unicode_codepoint_ascending"
        ),
        canonical_population_manifest_byte_length=len(manifest),
        canonical_population_manifest_sha256=(
            "sha256:" + hashlib.sha256(manifest).hexdigest()
        ),
    )
    return value


def false_claims(value: Any) -> bool:
    return isinstance(value, dict) and all(item is False for item in value.values())


def marker_json(stdout: str, prefix: str) -> dict[str, Any]:
    matches = [line for line in stdout.splitlines() if line.startswith(prefix)]
    require(len(matches) == 1, f"marker population changed: {prefix}")
    value = json.loads(matches[0][len(prefix) :])
    require(isinstance(value, dict), f"marker payload changed: {prefix}")
    return value


def verify_source_identity() -> None:
    require(git("rev-parse", "--show-toplevel") == REPO_ROOT.as_posix(), "wrong repository")
    require(
        git("remote", "get-url", "origin")
        == "https://github.com/Slagathore/sporespore.git",
        "wrong origin",
    )
    require(git("rev-parse", f"{SOURCE_COMMIT}^{{tree}}") == SOURCE_TREE, "source tree drift")
    for relative, object_id in SOURCE_BLOBS.items():
        require(
            git("rev-parse", f"{SOURCE_COMMIT}:{relative}") == object_id,
            f"pinned source blob drift: {relative}",
        )

    projector = source_text("sdk/locomotion_terminal_execution_projection.ps1")
    supervisor = source_text("sdk/run_qsdk_r23d70_supervisor.ps1")
    godot = source_text("tests/test_sdk_qsdk_r23d70_godot_jolt_worker.gd")
    require(
        '$presentRootKeys.Count -ne 0' in projector
        and "TERMINAL_EXECUTION_PROJECTION_SUCCESS_SHAPE_INVALID" in projector,
        "success projection contract changed",
    )
    require(
        supervisor.index("Get-SporeSporeTerminalExecutionProjection")
        < supervisor.index('$terminalPath = Join-Path $CellRoot "terminal.json"'),
        "projection/write ordering changed",
    )
    terminal_block = godot[
        godot.index("func _r23d70_terminal(") : godot.index(
            "static func _r23d70_expected_cell_ids"
        )
    ]
    require(
        "_r23d65_rebrand_terminal" in terminal_block
        and '.erase("world_attempt_count")' not in terminal_block
        and '.erase("world_build_count")' not in terminal_block,
        "observed Godot success projection lineage changed",
    )
    role_block = supervisor[
        supervisor.index("function Invoke-R23D70RolePreflight") : supervisor.index(
            "function Invoke-R23D70AuthorizationGhost"
        )
    ]
    require(
        "Get-R23D70TerminalFailure" in role_block
        and "Get-R23D70TerminalSuccess" not in role_block,
        "R70 zero-world success-shape coverage boundary changed",
    )


def verify_qualifications() -> dict[str, Any]:
    require(QUALIFICATION_ROOT.is_dir(), "adopted qualification root is missing")
    require(
        population_identity(QUALIFICATION_ROOT, cas_check=False)
        == EXPECTED_QUALIFICATION_POPULATION,
        "adopted qualification population changed",
    )
    for name, expected in QUALIFICATION_BINDINGS.items():
        verify_file(QUALIFICATION_ROOT / name, expected)
    attestation = load_json(QUALIFICATION_ROOT / "attestation.json")
    adoption = load_json(QUALIFICATION_ROOT / "adoption.json")
    require(
        attestation.get("campaign_id") == CAMPAIGN_ID
        and attestation.get("source", {}).get("commit") == SOURCE_COMMIT
        and attestation.get("executed_gate_count") == 16
        and attestation.get("all_gates_executed") is True
        and attestation.get("runtime", {}).get("python", {}).get("executable_path")
        == r"C:\Program Files\Python311\python.exe"
        and attestation.get("claims", {}).get("turning_acceptance") is False,
        "adopted qualification attestation changed",
    )
    require(
        adoption.get("campaign_id") == CAMPAIGN_ID
        and adoption.get("source_commit") == SOURCE_COMMIT
        and adoption.get("executed_gate_count") == 16
        and adoption.get("physical_launch_prerequisite_satisfied") is True
        and adoption.get("physical_acceptance_authority") is False
        and adoption.get("release_authority") is False,
        "qualification adoption changed",
    )

    require(
        INCOMPATIBLE_QUALIFICATION_ROOT.is_dir(),
        "incompatible qualification root is missing",
    )
    require(
        population_identity(INCOMPATIBLE_QUALIFICATION_ROOT, cas_check=False)
        == EXPECTED_INCOMPATIBLE_QUALIFICATION_POPULATION,
        "incompatible qualification population changed",
    )
    incompatible_path = INCOMPATIBLE_QUALIFICATION_ROOT / "attestation.json"
    verify_file(incompatible_path, INCOMPATIBLE_ATTESTATION_BINDING)
    incompatible = load_json(incompatible_path)
    require(
        incompatible.get("campaign_id") == CAMPAIGN_ID
        and incompatible.get("executed_gate_count") == 16
        and incompatible.get("runtime", {}).get("python", {}).get("executable_path")
        == (
            r"C:\Users\Cole\CodeStuff\games\SporeSpore\sdk\adapters\mujoco"
            r"\.venv\Scripts\python.exe"
        )
        and not (INCOMPATIBLE_QUALIFICATION_ROOT / "adoption.json").exists(),
        "incompatible qualification boundary changed",
    )
    return {
        "first_campaign_local_qualification": {
            "root": INCOMPATIBLE_QUALIFICATION_ROOT.resolve().as_posix(),
            "population_identity": EXPECTED_INCOMPATIBLE_QUALIFICATION_POPULATION,
            "attestation": binding(incompatible_path),
            "gate_pass_count": 16,
            "adoption_created": False,
            "adoption_refusal": "Runtime or host changed since LCA1 commissioning.",
            "exact_runtime_difference_count": 2,
            "differing_runtime_fields": [
                "python.executable_path",
                "python.executable_sha256",
            ],
            "physical_world_count": 0,
            "finite_attempt_consumed": False,
        },
        "adopted_qualification": {
            "root": QUALIFICATION_ROOT.resolve().as_posix(),
            "population_identity": EXPECTED_QUALIFICATION_POPULATION,
            "attestation": binding(QUALIFICATION_ROOT / "attestation.json"),
            "adoption": binding(QUALIFICATION_ROOT / "adoption.json"),
            "gate_pass_count": 16,
            "adopted_for_physical_launch": True,
            "physical_launch_prerequisite_satisfied": True,
            "turning_acceptance": False,
            "physical_acceptance_authority": False,
        },
    }


def build_closure() -> dict[str, Any]:
    verify_source_identity()
    qualifications = verify_qualifications()
    require(EVIDENCE_ROOT.is_dir(), "physical evidence root is missing")
    for relative, expected in FILE_BINDINGS.items():
        verify_file(EVIDENCE_ROOT / relative, expected)
    population = population_identity(EVIDENCE_ROOT, cas_check=True)
    require(population == EXPECTED_PHYSICAL_POPULATION, "physical population changed")

    freeze = load_json(EVIDENCE_ROOT / "physical-freeze.json")
    authorization = load_json(EVIDENCE_ROOT / "attempt-authorization.json")
    preflight = load_json(EVIDENCE_ROOT / "authorization-preflight.json")
    completion = load_json(EVIDENCE_ROOT / "completion.json")
    require(
        freeze.get("campaign_id") == CAMPAIGN_ID
        and freeze.get("gate_id") == GATE_ID
        and freeze.get("question_class") == "finite_decision"
        and freeze.get("source_commit") == SOURCE_COMMIT
        and freeze.get("source_tree_git_oid") == SOURCE_TREE
        and freeze.get("complete_zero_world_gate_passed") is True
        and freeze.get("clean_pushed_zero_world_qualification_adopted") is True
        and len(freeze.get("implementation_dependency_digests", {})) == 218
        and len(freeze.get("source_bindings", [])) == 218
        and freeze.get("declared_world_count") == 9
        and freeze.get("ordered_cell_ids") == CELL_IDS
        and freeze.get("physical_execution_authorized") is True
        and freeze.get("physical_acceptance_authority") is False,
        "physical freeze changed",
    )
    require(
        authorization.get("campaign_id") == CAMPAIGN_ID
        and authorization.get("attempt_id") == ATTEMPT_ID
        and Path(authorization.get("attempt_root", "")).resolve()
        == EVIDENCE_ROOT.resolve()
        and authorization.get("ordered_cell_ids") == CELL_IDS
        and authorization.get("physical_execution_authorized") is True
        and authorization.get("campaign_attestation_adoption_valid") is True
        and authorization.get("one_shot_attempt_unconsumed") is True
        and authorization.get("physical_acceptance_authority") is False,
        "attempt authorization changed",
    )
    require(
        preflight.get("receipt_count") == 9
        and preflight.get("pass_count") == 9
        and preflight.get("complete_matrix_passed") is True
        and preflight.get("model_construction_count") == 0
        and preflight.get("world_attempt_count") == 0
        and preflight.get("world_build_count") == 0
        and preflight.get("physical_acceptance_authority") is False,
        "authorization preflight changed",
    )
    require(
        completion.get("campaign_id") == CAMPAIGN_ID
        and completion.get("attempt_id") == ATTEMPT_ID
        and completion.get("status") == "invalid_or_incomplete_first_attempt"
        and completion.get("source_commit") == SOURCE_COMMIT
        and completion.get("retained_cell_count") == 0
        and completion.get("one_shot_attempt_consumed") is True
        and completion.get("replacement_or_selective_rerun_permitted") is False
        and completion.get("failure_message") == PROJECTOR_FAILURE
        and completion.get("physical_acceptance_authority") is False,
        "completion changed",
    )

    stdout_path = EVIDENCE_ROOT / "cells" / OBSERVED_CELL_ID / "stdout.txt"
    stdout = stdout_path.read_text(encoding="utf-8")
    worker = marker_json(stdout, TERMINAL_PREFIX)
    termination = marker_json(stdout, TERMINATION_PREFIX)
    execution = worker.get("execution", {})
    root_count_keys = [
        key
        for key in (
            "world_attempt_count",
            "world_build_count",
            "world_build_count_exact",
            "world_build_count_lower_bound",
            "world_build_count_upper_bound",
        )
        if key in worker
    ]
    require(
        worker.get("schema_version")
        == "sporespore_qsdk_r23d70_engine_cell_report_v1"
        and worker.get("campaign_id") == CAMPAIGN_ID
        and worker.get("gate_id") == GATE_ID
        and worker.get("source_commit") == SOURCE_COMMIT
        and worker.get("engine_id") == "godot_jolt"
        and worker.get("arm_id") == "reference_zero"
        and isinstance(execution, dict)
        and execution.get("world_attempt_count") == 1
        and execution.get("world_build_count") == 1
        and execution.get("controller_semantic_step_count") == 2992
        and execution.get("trace_retained_before_terminal_entry") is True
        and root_count_keys == ["world_attempt_count", "world_build_count"]
        and worker.get("model_construction_count") == 0
        and worker.get("world_attempt_count") == 0
        and worker.get("world_build_count") == 0
        and worker.get("trace_summary", {}).get("row_count") == 2992
        and worker.get("trace_artifact", {}).get("sha256")
        == "sha256:6e38ae906cda5d53411cca091c93cb288e19879398a1f56f72381ed56ee35543"
        and false_claims(worker.get("claims"))
        and worker.get("physical_acceptance_authority") is False,
        "observed worker terminal changed",
    )
    require(
        termination.get("schema_version")
        == "sporespore_godot_supervised_termination_ready_v1"
        and termination.get("requested_exit_code") == 0
        and termination.get("worker_receipt_emitted") is True
        and termination.get("worker_receipt_kind") == "terminal"
        and termination.get("physics_evidence_authority") is False,
        "Godot termination receipt changed",
    )

    trace_path = EVIDENCE_ROOT / "traces" / f"{OBSERVED_CELL_ID}.ndjson"
    trace_raw = trace_path.read_bytes()
    require(
        trace_raw.endswith(b"\n") and trace_raw.count(b"\n") == 2992,
        "retained trace row count changed",
    )
    trace_sha = sha256(trace_path)
    trace_cas = ARTIFACT_ROOT / trace_sha / "payload.bin"
    require(
        trace_cas.is_file()
        and trace_cas.stat().st_size == trace_path.stat().st_size
        and sha256(trace_cas) == trace_sha,
        "retained trace CAS changed",
    )
    require(
        not (EVIDENCE_ROOT / "cells" / OBSERVED_CELL_ID / "terminal.json").exists()
        and not (EVIDENCE_ROOT / "report.json").exists()
        and not (EVIDENCE_ROOT / "complete-evaluation.json").exists()
        and not (EVIDENCE_ROOT / "terminal-paths.json").exists(),
        "post-projector output boundary changed",
    )

    return {
        "schema_version": "sporespore_qsdk_r23d70_physical_closure_v1",
        "status": CLOSED_STATUS,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "question_class": "finite_decision",
        "maintenance_question_class": "equivalence_non_inferiority",
        "source_commit": SOURCE_COMMIT,
        "source_tree_git_oid": SOURCE_TREE,
        "source_blob_bindings": SOURCE_BLOBS,
        "qualifications": qualifications,
        "attempt": {
            "attempt_root": EVIDENCE_ROOT.resolve().as_posix(),
            "attempt_id": ATTEMPT_ID,
            "primary_evidence": {
                relative: binding(EVIDENCE_ROOT / relative)
                for relative in FILE_BINDINGS
            },
            "authorization_receipt_count": 9,
            "authorization_pass_count": 9,
            "declared_cell_count": 9,
            "physical_worker_process_count": 1,
            "world_attempt_count": 1,
            "world_build_count": 1,
            "complete_native_horizon_count": 1,
            "retained_trace_count": 1,
            "retained_trace_row_count": 2992,
            "execution_valid_cell_count": 0,
            "turning_evaluated_cell_count": 0,
            "campaign_identity_consumed": True,
            "same_identity_rerun_allowed": False,
            "replacement_or_selective_rerun_allowed": False,
            "population_identity": population,
        },
        "observed_cell": {
            "cell_id": OBSERVED_CELL_ID,
            "engine_id": "godot_jolt",
            "arm_id": "reference_zero",
            "worker_terminal_source": binding(stdout_path),
            "trace_artifact": binding(trace_path),
            "pending_trace_artifact": binding(
                EVIDENCE_ROOT / "pending-traces" / f"{OBSERVED_CELL_ID}.rows.json"
            ),
            "execution_object": execution,
            "stale_root_execution_counts": {
                "model_construction_count": worker["model_construction_count"],
                "world_attempt_count": worker["world_attempt_count"],
                "world_build_count": worker["world_build_count"],
            },
            "retained_trace_row_count": 2992,
            "complete_native_horizon_observed": True,
            "execution_valid": False,
            "behavior_evaluated": False,
            "measurements_preserved_without_interpretation": True,
        },
        "unopened_population": {
            "cell_count": len(UNOPENED_CELL_IDS),
            "ordered_cell_ids": UNOPENED_CELL_IDS,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "behavior_result_available": False,
        },
        "terminal_execution_projection_failure": {
            "failure_message": PROJECTOR_FAILURE,
            "success_schema": "sporespore_qsdk_r23d70_engine_cell_report_v1",
            "canonical_execution_object_present": True,
            "canonical_execution_world_attempt_count": 1,
            "canonical_execution_world_build_count": 1,
            "stale_root_count_keys_present": root_count_keys,
            "stale_root_world_attempt_count": 0,
            "stale_root_world_build_count": 0,
            "shared_projector_requires_success_root_count_key_count": 0,
            "projection_rejected_before_terminal_json_write": True,
            "trace_retention_completed_before_projection": True,
            "zero_world_coverage_gap": (
                "R70 exercised failure-terminal projection and all nine authorization "
                "entrypoints, but never projected a production-shaped success terminal."
            ),
            "observed_engine_count": 1,
            "unobserved_engine_count": 2,
            "physics_failure": False,
            "threshold_or_selector_failure": False,
            "behavior_result_available": False,
        },
        "official_result": {
            "classification": CLASSIFICATION,
            "finite_three_engine_turning_positive": False,
            "turning_gate_invoked": False,
            "turning_behavior_evaluated": False,
            "cross_engine_equivalence_test_invoked": False,
            "historical_result_reinterpreted": False,
            "threshold_selector_evaluator_result_or_interpretation_change_count": 0,
            "maintenance_process_physical_world_count": 0,
            "release_score_before": "10/25",
            "release_score_after": "10/25",
        },
        "claims": {
            "campaign_closed": True,
            "retained_attempt_evidence_complete": True,
            "campaign_identity_consumed": True,
            "historical_result_reinterpreted": False,
            "one_complete_native_horizon_observed": True,
            "complete_nine_cell_population_observed": False,
            "turning_claimed": False,
            "q_sdk_r23_satisfied": False,
            "cross_engine_equivalence": False,
            "prone_to_standing": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
    }


def walk_dicts(value: Any) -> Iterable[dict[str, Any]]:
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from walk_dicts(child)
    elif isinstance(value, list):
        for child in value:
            yield from walk_dicts(child)


def verify_live_authorities(closure_sha: str, audit_sha: str) -> None:
    for path in (RELEASE_PATH, SUPPORT_PATH):
        value = load_json(path)
        matches = [
            item
            for item in walk_dicts(value)
            if item.get("campaign_id") == CAMPAIGN_ID and item.get("gate_id") == GATE_ID
        ]
        require(len(matches) == 1, f"R70 authority population changed: {path}")
        item = matches[0]
        lifecycle = item.get("current_lifecycle", {})
        require(
            item.get("status") == CLOSED_STATUS
            and item.get("current_lifecycle_status") == CLOSED_STATUS
            and item.get("qualification_passed") is True
            and item.get("campaign_attestation_adopted") is True
            and item.get("physical_execution_authorized") is True
            and item.get("physical_campaign_opened") is True
            and item.get("fresh_seed_occurrence_count") == 1
            and item.get("world_attempt_count") == 1
            and item.get("world_build_count") == 1
            and item.get("finite_three_engine_turning") is False
            and item.get("q_sdk_r23_satisfied") is False
            and item.get("physical_acceptance_authority") is False
            and item.get("release_authorized") is False
            and lifecycle.get("closure_path") == CLOSURE_RELATIVE
            and lifecycle.get("closure_raw_sha256") == f"sha256:{closure_sha}"
            and lifecycle.get("closure_audit_path") == AUDIT_RELATIVE
            and lifecycle.get("closure_audit_raw_sha256") == f"sha256:{audit_sha}"
            and lifecycle.get("attempt_id") == ATTEMPT_ID
            and lifecycle.get("complete_native_horizon_count") == 1
            and lifecycle.get("execution_valid_cell_count") == 0
            and lifecycle.get("unopened_cell_count") == 8,
            f"R70 live lifecycle projection changed: {path}",
        )
    for path in (
        REPO_ROOT / "docs" / "README.md",
        REPO_ROOT / "docs" / "ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md",
        REPO_ROOT / "docs" / "SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md",
        REPO_ROOT / "docs" / "LOCOMOTION_GROUND_UP_RESEARCH_PROGRAM.md",
        REPO_ROOT / "docs" / "LOCOMOTION_ARCHITECTURE.md",
    ):
        text = path.read_text(encoding="utf-8")
        require(
            "R23D70" in text
            and "TERMINAL_EXECUTION_PROJECTION_SUCCESS_SHAPE_INVALID" in text
            and "10/25" in text,
            f"R70 live documentation projection changed: {path}",
        )


def materialize() -> None:
    closure = build_closure()
    CLOSURE_PATH.write_text(canonical_json(closure), encoding="utf-8")
    print(
        "[turning/3e] MATERIALIZED R23D70 immutable physical closure: "
        "qualification=16/16 adoption=True authorization=9/9 worlds=1 "
        "horizons=1 traces=1 unopened=8 execution_valid=0 turning=False "
        "QSDK-R23=False score=10/25"
    )


def audit() -> None:
    expected = build_closure()
    require(CLOSURE_PATH.is_file(), "R23D70 closure is missing")
    actual = load_json(CLOSURE_PATH)
    require(actual == expected, "R23D70 closure claim vector changed")
    verify_live_authorities(sha256(CLOSURE_PATH), sha256(AUDIT_PATH))
    mutations = [
        ("status", "passing"),
        ("attempt.same_identity_rerun_allowed", True),
        ("attempt.world_build_count", 9),
        ("terminal_execution_projection_failure.physics_failure", True),
        ("claims.turning_claimed", True),
        ("claims.complete_nine_cell_population_observed", True),
    ]
    for dotted, replacement in mutations:
        changed = json.loads(json.dumps(actual))
        target = changed
        parts = dotted.split(".")
        for part in parts[:-1]:
            target = target[part]
        target[parts[-1]] = replacement
        require(changed != expected, f"mutation was accepted: {dotted}")
    print(
        "[turning/3e] PASS R23D70 immutable physical closure: "
        "qualification=16/16 adoption=True authorization=9/9 worlds=1 "
        "horizons=1 traces=1 unopened=8 execution_valid=0 mutations=6 "
        "turning=False QSDK-R23=False score=10/25"
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--audit", action="store_true")
    arguments = parser.parse_args()
    if arguments.audit:
        audit()
    else:
        materialize()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
