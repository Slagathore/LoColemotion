#!/usr/bin/env python3
"""Materialize and audit the immutable R23D69 physical closure.

R23D69 consumed its complete nine-cell finite population.  Every worker built
one genuine native world and retained a complete 2,992-row trace, but the
shared retention producer placed ``row_count`` only inside ``trace_summary``
while all three frozen consumers required a top-level ``row_count``.  This
tool binds that observed integration-invalid result without re-evaluating any
behavior threshold, selector, trace, or campaign interpretation.
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
    / "qsdk-r23d69-physical-20260826T031516Z-2b7a2be1-commissioned-python"
)
QUALIFICATION_ROOT = (
    PROJECT_STATE_ROOT
    / "qsdk-r23d69-qualification-20260826T030636Z-2b7a2be1-commissioned-python"
)
ABSENT_PRE_ROOT = (
    PROJECT_STATE_ROOT / "qsdk-r23d69-physical-20260826T031321Z-2b7a2be1"
)
ARTIFACT_ROOT = PROJECT_STATE_ROOT / "artifacts" / "sha256"
CLOSURE_PATH = (
    REPO_ROOT
    / "sdk"
    / "turning"
    / "r23d69_complete_production_row_three_engine_turning_validation_closure_v1.json"
)
AUDIT_PATH = REPO_ROOT / "tests" / "test_qsdk_r23d69_physical_closure.ps1"
RELEASE_PATH = REPO_ROOT / "sdk" / "release" / "quadruped_release_contract.json"
SUPPORT_PATH = REPO_ROOT / "sdk" / "release" / "quadruped_support_matrix.json"

SOURCE_COMMIT = "2b7a2be1012d7e1d8f2ca41a6c4cd71769d097f7"
SOURCE_TREE = "7c0e9e99fabed27f819b65dbf4d24f72690dd5de"
CAMPAIGN_ID = (
    "QSDK-R23D69-COMPLETE-PRODUCTION-ROW-CONFORMANCE-REPAIRED-"
    "THREE-ENGINE-TURNING-VALIDATION"
)
GATE_ID = "QSDK-R23D69"
CLOSED_STATUS = (
    "closed_consumed_invalid_complete_nine_cell_population_"
    "shared_trace_retention_receipt_schema_mismatch"
)
CLOSURE_RELATIVE = (
    "sdk/turning/"
    "r23d69_complete_production_row_three_engine_turning_validation_closure_v1.json"
)
AUDIT_RELATIVE = "tests/test_qsdk_r23d69_physical_closure.ps1"
CLASSIFICATION = "invalid_or_incomplete_exact_seed_23187_three_engine_portable_turning"
ATTEMPT_ID = "3ce20398befa4d33bfc75ecbba41bd96"

ENGINES = ("godot_jolt", "rapier_parry", "mujoco")
ARMS = ("reference_zero", "positive_heading", "negative_heading")
CELL_IDS = [
    f"r23d69__{engine}__s23187__{arm}"
    for engine in ENGINES
    for arm in ARMS
]

SOURCE_BLOBS = {
    "sdk/run_qsdk_r23d69_supervisor.ps1": "7e60a3cb82ec12a511a198125baa80a77edd7b0e",
    "sdk/turning/r23d69_production_route_three_engine_turning_evaluator.py": (
        "a7e332832cdd75876e4e64cecdacbd1dec4ae563"
    ),
    "sdk/turning/r23d65_selected_profile_three_engine_turning_validation_evaluator.py": (
        "ba5d48ce0a2673e258c4302035be3f5c8d2dbccd"
    ),
    "sdk/turning/r23d58_godot_cap_source_factorial_evaluator.py": (
        "049e72d49f403dc07fff09e5b1cb632710133138"
    ),
    "sdk/turning/r23d34_native_r23d29_transfer_evaluator.py": (
        "b429fe9dbbda057e88b24eff0182bb4f5b1c7ebf"
    ),
    "sdk/publish_qsdk_r23d48_trace.ps1": "4864b31a4f988cb935b95f0b9aec339714cbbbde",
    "tests/test_sdk_qsdk_r23d69_godot_jolt_worker.gd": (
        "c14d1f3dc52dbd75a488dec75562a30912367f85"
    ),
    "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d27_physical.rs": (
        "8a038f978ed5a3c4660cf3541a0dc3b556dec808"
    ),
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d69_turning_route.py": (
        "5bac6ccbd377b92d46d22610474259ae3dc71c36"
    ),
    "sdk/turning/r23d69_production_route_runtime.py": (
        "5fa4cc8a9f69d072b11fdc6229fb43a85e79ad87"
    ),
    "sdk/process_result_projection.ps1": "be3d194a4ce331b381f4a4a7c9a647cc1692742b",
}

PRIMARY_BINDINGS = {
    "physical-freeze.json": (
        317971,
        "54c1b77fb0f9adab1dd9e54b325d9fd42135d71fb96cf1c27949c7feec677299",
    ),
    "attempt-authorization.json": (
        157881,
        "f5f32d3a63f79b2df6bcd6f689b021ac46c8ed376cbf6d1c7733b526e8dea907",
    ),
    "authorization-preflight.json": (
        26221,
        "0e759f4799edaa1f243b1de0277d3b0bc3516eb38afdf0adfb9086103e6d8791",
    ),
    "complete-evaluation.json": (
        8963,
        "379934cbb13d975a3061135ce4e89bbd08da7e574f71e91cc33a7d6550224c5a",
    ),
    "completion.json": (
        2960,
        "a039869962639ee32830d6c64869ec075824c40f019580fdf5d5b25d5a39f01c",
    ),
    "report.json": (
        44426,
        "fd29aeafef9bfd75f543f48ca201ba2591836c310ee4ef33197c05efbc1bd53b",
    ),
    "terminal-paths.json": (
        1435,
        "01286543643cfe73c89b39a3fb66b63e08b15aca48255467cb4b1d177867d41e",
    ),
}

TERMINAL_BINDINGS = {
    "r23d69__godot_jolt__s23187__reference_zero": (
        121991,
        "a86619f6eddf83e6d21a2027df2834fb3fa7d244c05750dbef5dacb3bf77635e",
    ),
    "r23d69__godot_jolt__s23187__positive_heading": (
        121969,
        "a36ce7f5029c1ede2ca3e5cf6623a2b8d6995af5c67eab5dfc32aff8fb885564",
    ),
    "r23d69__godot_jolt__s23187__negative_heading": (
        121880,
        "850b8df65783c5338d14634dee38b7c56dc09d3cbabfdee1e8df1b04fb4ca5d0",
    ),
    "r23d69__rapier_parry__s23187__reference_zero": (
        1748,
        "0c755d2ca5e9bf95e166b48fe4dbefd66d7f2f2ba8ef1cd038cfffd0fb6e6a75",
    ),
    "r23d69__rapier_parry__s23187__positive_heading": (
        1752,
        "9a29a1b18833b926a5d24567778ccd1f5184d4a6839af6233d900879e5a9dcf9",
    ),
    "r23d69__rapier_parry__s23187__negative_heading": (
        1753,
        "6a5025084f7ffa28eefe64cae7784e1552f29da2c0661522fdec5ea11fa4571c",
    ),
    "r23d69__mujoco__s23187__reference_zero": (
        1623,
        "a71035521ca79b7c47ffdd0984d05d5aae2b0c07fa0b6adb030af8490a1353a0",
    ),
    "r23d69__mujoco__s23187__positive_heading": (
        1627,
        "e8d581f32d2f7fb593273fd797f87b68e700272f42b0c2490355fd3681357220",
    ),
    "r23d69__mujoco__s23187__negative_heading": (
        1628,
        "e85974e625087aa1824f8adf43b55a55526f9efa51d41c8945b66e1d8d18f5cf",
    ),
}

EXPECTED_PHYSICAL_POPULATION = {
    "complete_file_population_count": 75,
    "complete_file_population_byte_count": 779848989,
    "retained_unique_digest_count": 58,
    "cas_backed_file_count": 66,
    "non_cas_file_count": 9,
    "non_cas_relative_paths": [
        "pending-traces/complete_production_row_conformance_repaired_three_engine_turning_validation__r23d69__mujoco__s23187__negative_heading.rows.json",
        "pending-traces/complete_production_row_conformance_repaired_three_engine_turning_validation__r23d69__mujoco__s23187__positive_heading.rows.json",
        "pending-traces/complete_production_row_conformance_repaired_three_engine_turning_validation__r23d69__mujoco__s23187__reference_zero.rows.json",
        "pending-traces/complete_production_row_conformance_repaired_three_engine_turning_validation__r23d69__rapier_parry__s23187__negative_heading.rows.json",
        "pending-traces/complete_production_row_conformance_repaired_three_engine_turning_validation__r23d69__rapier_parry__s23187__positive_heading.rows.json",
        "pending-traces/complete_production_row_conformance_repaired_three_engine_turning_validation__r23d69__rapier_parry__s23187__reference_zero.rows.json",
        "pending-traces/r23d69__godot_jolt__s23187__negative_heading.rows.json",
        "pending-traces/r23d69__godot_jolt__s23187__positive_heading.rows.json",
        "pending-traces/r23d69__godot_jolt__s23187__reference_zero.rows.json",
    ],
    "canonical_population_manifest_format": (
        "relative_path<TAB>byte_length<TAB>sha256:<lowercase_hex><LF>"
    ),
    "canonical_population_manifest_sort_order": "relative_path_unicode_codepoint_ascending",
    "canonical_population_manifest_byte_length": 10975,
    "canonical_population_manifest_sha256": (
        "sha256:3a1fb9af425fc19ae86010cbf6ad8f779618262ee6f58e757d4934618ccd12c6"
    ),
}

EXPECTED_QUALIFICATION_POPULATION = {
    "complete_file_population_count": 50,
    "complete_file_population_byte_count": 497000,
    "canonical_population_manifest_format": (
        "relative_path<TAB>byte_length<TAB>sha256:<lowercase_hex><LF>"
    ),
    "canonical_population_manifest_sort_order": "relative_path_unicode_codepoint_ascending",
    "canonical_population_manifest_byte_length": 5842,
    "canonical_population_manifest_sha256": (
        "sha256:89fca256b93de301385f577a780b141b3789efa3d9f3030ea27e8925adf63e5f"
    ),
}


class ClosureError(RuntimeError):
    """Fail-closed R23D69 closure error."""


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
    value = {
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

    r69 = source_text(
        "sdk/turning/r23d69_production_route_three_engine_turning_evaluator.py"
    )
    r65 = source_text(
        "sdk/turning/r23d65_selected_profile_three_engine_turning_validation_evaluator.py"
    )
    r34 = source_text("sdk/turning/r23d34_native_r23d29_transfer_evaluator.py")
    godot = source_text("tests/test_sdk_qsdk_r23d69_godot_jolt_worker.gd")
    rapier = source_text(
        "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d27_physical.rs"
    )
    mujoco = source_text(
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d69_turning_route.py"
    )
    r69_retain = r69[r69.index("def retain_trace"):r69.index("def evaluate_complete_entries")]
    r65_retain = r65[r65.index("def retain_trace"):r65.index("def _entry_identity_failures")]
    r34_return = r34[
        r34.index('    return {\n        "schema_version": TRACE_RETENTION_SCHEMA'):
        r34.index("\n\n\ndef _artifact_rows")
    ]
    require(
        "return inherited.retain_trace(**kwargs)" in r69_retain,
        "R69 retention delegation changed",
    )
    require(
        "value = accepted.retain_trace(**kwargs)" in r65_retain
        and "row_count=" not in r65_retain,
        "R65 retention projection changed",
    )
    require(
        '"trace_summary": summary' in r34_return
        and '"row_count":' not in r34_return,
        "shared producer return shape changed",
    )
    require(
        'receipt.get("row_count", -1)' in godot
        and 'receipt["row_count"] != R23D27_CONTROLLER_STEPS' in rapier
        and 'receipt.get("row_count") != design.CONTROLLER_STEPS' in mujoco,
        "frozen consumer row-count checks changed",
    )


def false_claims(value: Any) -> bool:
    return isinstance(value, dict) and all(item is False for item in value.values())


def verify_qualification() -> dict[str, Any]:
    require(QUALIFICATION_ROOT.is_dir(), "qualification root is missing")
    population = population_identity(QUALIFICATION_ROOT, cas_check=False)
    require(
        population == EXPECTED_QUALIFICATION_POPULATION,
        "complete qualification population changed",
    )
    attestation_path = QUALIFICATION_ROOT / "attestation.json"
    adoption_path = QUALIFICATION_ROOT / "adoption.json"
    verify_file(
        attestation_path,
        (151318, "b02191e56661fdfc434478c44ac6c2a51a66d85e1286eb07b945112e0cb144b2"),
    )
    verify_file(
        adoption_path,
        (3318, "d1f8cc05317e859f5657a964e2ce4a52ad0d6c4f6e2db765736652f81cc45894"),
    )
    attestation = load_json(attestation_path)
    adoption = load_json(adoption_path)
    require(
        attestation.get("campaign_id") == CAMPAIGN_ID
        and attestation.get("executed_gate_count") == 16
        and attestation.get("all_gates_executed") is True
        and attestation.get("claims", {}).get("turning_acceptance") is False,
        "qualification attestation changed",
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
    return {
        "root": QUALIFICATION_ROOT.resolve().as_posix(),
        "population_identity": population,
        "attestation": binding(attestation_path),
        "adoption": binding(adoption_path),
        "gate_pass_count": 16,
        "adopted_for_physical_launch": True,
        "turning_acceptance": False,
        "physical_acceptance_authority": False,
    }


def expected_failure(engine: str) -> tuple[str, str]:
    if engine == "godot_jolt":
        return "QSDK_R23D69_GJT_TRACE_RETENTION_RECEIPT_INVALID", "controller_horizon_complete"
    if engine == "rapier_parry":
        return "QSDK_R23D69_RAP_TRACE_RETENTION_RECEIPT_INVALID", "settlement_complete"
    return (
        "QSDK_R23D69_MJC_WORKER_FAILURE:R23D3MujocoError:"
        "QSDK_R23D69_MJC_TRACE_RETENTION_RECEIPT_INVALID",
        "settlement_complete",
    )


def verify_cells() -> list[dict[str, Any]]:
    summaries: list[dict[str, Any]] = []
    for cell_id in CELL_IDS:
        _, engine, _, arm = cell_id.split("__")
        terminal_path = EVIDENCE_ROOT / "cells" / cell_id / "terminal.json"
        trace_path = EVIDENCE_ROOT / "traces" / f"{cell_id}.ndjson"
        verify_file(terminal_path, TERMINAL_BINDINGS[cell_id])
        require(trace_path.is_file(), f"retained trace missing: {cell_id}")
        trace_raw = trace_path.read_bytes()
        trace_raw_sha = hashlib.sha256(trace_raw).hexdigest()
        require(
            trace_raw.endswith(b"\n") and trace_raw.count(b"\n") == 2992,
            f"complete trace row count changed: {cell_id}",
        )
        cas_payload = ARTIFACT_ROOT / trace_raw_sha / "payload.bin"
        require(
            cas_payload.is_file()
            and cas_payload.stat().st_size == len(trace_raw)
            and sha256(cas_payload) == trace_raw_sha,
            f"retained trace CAS identity changed: {cell_id}",
        )
        terminal = load_json(terminal_path)
        failure_code, failure_stage = expected_failure(engine)
        require(
            terminal.get("campaign_id") == CAMPAIGN_ID
            and terminal.get("gate_id") == GATE_ID
            and terminal.get("source_commit") == SOURCE_COMMIT
            and terminal.get("engine_id") == engine
            and terminal.get("arm_id") == arm
            and terminal.get("failure_code") == failure_code
            and terminal.get("failure_stage") == failure_stage
            and terminal.get("world_attempt_count") == 1
            and terminal.get("world_build_count") == 1
            and terminal.get("physical_acceptance_authority") is False
            and false_claims(terminal.get("claims")),
            f"terminal result changed: {cell_id}",
        )
        summary: dict[str, Any] = {
            "cell_id": cell_id,
            "engine_id": engine,
            "arm_id": arm,
            "terminal": binding(terminal_path),
            "trace_artifact": binding(trace_path),
            "retained_trace_row_count": 2992,
            "complete_native_horizon_observed": True,
            "failure_code": failure_code,
            "failure_stage": failure_stage,
            "world_attempt_count": 1,
            "world_build_count": 1,
            "execution_valid": False,
        }
        if engine == "godot_jolt":
            diagnostic = terminal.get("trace_diagnostic")
            receipt = diagnostic.get("trace_retention_failure_detail", {})
            require(
                diagnostic.get("complete") is True
                and diagnostic.get("actual_row_count") == 2992
                and diagnostic.get("contiguous_row_count") == 2992
                and diagnostic.get("failure_codes") == []
                and "row_count" not in receipt
                and receipt.get("trace_summary", {}).get("row_count") == 2992
                and receipt.get("trace_artifact", {}).get("sha256")
                == f"sha256:{trace_raw_sha}",
                f"Godot receipt-shape witness changed: {cell_id}",
            )
            summary["receipt_shape_witness"] = {
                "top_level_row_count_present": False,
                "nested_trace_summary_row_count": 2992,
                "trace_diagnostic_artifact": terminal.get("trace_diagnostic_artifact"),
            }
        summaries.append(summary)
    return summaries


def build_closure() -> dict[str, Any]:
    verify_source_identity()
    require(EVIDENCE_ROOT.is_dir(), "physical evidence root is missing")
    require(not ABSENT_PRE_ROOT.exists(), "pre-root rejected launch unexpectedly created evidence")
    for name, expected in PRIMARY_BINDINGS.items():
        verify_file(EVIDENCE_ROOT / name, expected)
    physical_population = population_identity(EVIDENCE_ROOT, cas_check=True)
    require(
        physical_population == EXPECTED_PHYSICAL_POPULATION,
        "complete retained physical population changed",
    )
    qualification = verify_qualification()

    freeze = load_json(EVIDENCE_ROOT / "physical-freeze.json")
    authorization = load_json(EVIDENCE_ROOT / "attempt-authorization.json")
    preflight = load_json(EVIDENCE_ROOT / "authorization-preflight.json")
    evaluation = load_json(EVIDENCE_ROOT / "complete-evaluation.json")
    completion = load_json(EVIDENCE_ROOT / "completion.json")
    report = load_json(EVIDENCE_ROOT / "report.json")

    require(
        freeze.get("campaign_id") == CAMPAIGN_ID
        and freeze.get("gate_id") == GATE_ID
        and freeze.get("question_class") == "finite_decision"
        and freeze.get("source_commit") == SOURCE_COMMIT
        and freeze.get("source_tree_git_oid") == SOURCE_TREE
        and freeze.get("complete_zero_world_gate_passed") is True
        and freeze.get("clean_pushed_zero_world_qualification_adopted") is True
        and len(freeze.get("implementation_dependency_digests", {})) == 214
        and len(freeze.get("source_bindings", [])) == 214
        and freeze.get("declared_world_count") == 9
        and freeze.get("ordered_cell_ids") == CELL_IDS
        and freeze.get("physical_execution_authorized") is True
        and freeze.get("physical_acceptance_authority") is False,
        "physical freeze changed",
    )
    require(
        authorization.get("campaign_id") == CAMPAIGN_ID
        and authorization.get("attempt_id") == ATTEMPT_ID
        and Path(authorization.get("attempt_root", "")).resolve() == EVIDENCE_ROOT.resolve()
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
        evaluation.get("classification") == CLASSIFICATION
        and evaluation.get("cell_count") == 9
        and evaluation.get("all_declared_cells_executed_or_retained_as_failures") is True
        and evaluation.get("turning_gate_invoked") is True
        and evaluation.get("cross_engine_equivalence_test_invoked") is False
        and evaluation.get("fresh_held_out_seed_consumed") is True
        and evaluation.get("fresh_held_out_seed_count") == 1
        and false_claims(evaluation.get("claims"))
        and evaluation.get("physical_acceptance_authority") is False,
        "complete evaluation changed",
    )
    require(
        completion.get("attempt_id") == ATTEMPT_ID
        and completion.get("status") == CLASSIFICATION
        and completion.get("cell_count") == 9
        and completion.get("world_count") == 9
        and completion.get("world_count_exact") is True
        and completion.get("world_count_lower_bound") == 9
        and completion.get("world_count_upper_bound") == 9
        and completion.get("finite_three_engine_turning_positive") is False
        and completion.get("one_shot_attempt_consumed") is True
        and completion.get("replacement_or_selective_rerun_permitted") is False
        and completion.get("physical_acceptance_authority") is False,
        "completion changed",
    )
    require(
        report.get("attempt_id") == ATTEMPT_ID
        and report.get("result_classification") == CLASSIFICATION
        and len(report.get("ordered_cells", [])) == 9
        and report.get("all_nine_cells_executed_or_retained_as_failures") is True
        and report.get("world_build_count_exact") is True
        and report.get("world_build_count_lower_bound") == 9
        and report.get("world_build_count_upper_bound") == 9
        and false_claims(report.get("claims"))
        and report.get("physical_acceptance_authority") is False,
        "supervisor report changed",
    )

    cells = verify_cells()
    return {
        "schema_version": "sporespore_qsdk_r23d69_physical_closure_v1",
        "status": CLOSED_STATUS,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "question_class": "finite_decision",
        "maintenance_question_class": "equivalence_non_inferiority",
        "source_commit": SOURCE_COMMIT,
        "source_tree_git_oid": SOURCE_TREE,
        "source_blob_bindings": SOURCE_BLOBS,
        "qualification": qualification,
        "rejected_pre_root_operator_invocation": {
            "classification": "invalid_unretained_before_attempt_root",
            "proposed_root": ABSENT_PRE_ROOT.resolve().as_posix(),
            "output_root_created": False,
            "failure": (
                "campaign-attestation adoption failed: VERIFICATION_EXCEPTION::"
                "Runtime or host changed since LCA1 commissioning."
            ),
            "cause": "supervisor_invocation_omitted_commissioned_python_argument",
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "finite_attempt_consumed": False,
            "evidence_strength": "operator_observation_preserved_in_repository_closure",
            "physical_acceptance_authority": False,
        },
        "attempt": {
            "attempt_root": EVIDENCE_ROOT.resolve().as_posix(),
            "attempt_id": ATTEMPT_ID,
            "primary_evidence": {
                name: binding(EVIDENCE_ROOT / name) for name in PRIMARY_BINDINGS
            },
            "authorization_receipt_count": 9,
            "authorization_pass_count": 9,
            "physical_worker_process_count": 9,
            "world_attempt_count": 9,
            "world_build_count": 9,
            "complete_native_horizon_count": 9,
            "execution_valid_cell_count": 0,
            "turning_evaluated_cell_count": 0,
            "campaign_identity_consumed": True,
            "same_identity_rerun_allowed": False,
            "replacement_or_selective_rerun_allowed": False,
            "population_identity": physical_population,
        },
        "cells": cells,
        "shared_receipt_schema_failure": {
            "producer_chain": [
                "r23d69.retain_trace",
                "r23d65.retain_trace",
                "r23d58.retain_trace",
                "r23d34.retain_trace",
            ],
            "producer_returned_top_level_row_count": False,
            "producer_returned_nested_trace_summary_row_count": True,
            "frozen_consumer_required_top_level_row_count": {
                "godot_jolt": True,
                "rapier_parry": True,
                "mujoco": True,
            },
            "affected_cell_count": 9,
            "common_failure_before_behavior_evaluation": True,
            "trace_publication_succeeded": True,
            "complete_trace_retention_count": 9,
            "trace_rows_per_cell": 2992,
            "total_retained_trace_row_count": 26928,
            "threshold_or_selector_failure": False,
            "physics_failure": False,
            "behavior_result_available": False,
        },
        "official_result": {
            "classification": CLASSIFICATION,
            "finite_three_engine_turning_positive": False,
            "turning_gate_invoked": True,
            "turning_behavior_evaluated": False,
            "cross_engine_equivalence_test_invoked": False,
            "equivalence_margin": 0.0,
            "non_inferiority_margin": 0.0,
            "historical_result_reinterpreted": False,
            "threshold_selector_evaluator_result_or_interpretation_change_count": 0,
            "maintenance_process_physical_world_count": 0,
            "release_score_before": "10/25",
            "release_score_after": "10/25",
        },
        "claims": {
            "campaign_closed": True,
            "retained_evidence_complete": True,
            "campaign_identity_consumed": True,
            "historical_result_reinterpreted": False,
            "nine_complete_native_horizons_observed": True,
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
    for path, expected_count in ((RELEASE_PATH, 1), (SUPPORT_PATH, 1)):
        value = load_json(path)
        matches = [
            item
            for item in walk_dicts(value)
            if item.get("campaign_id") == CAMPAIGN_ID and item.get("gate_id") == GATE_ID
        ]
        require(len(matches) == expected_count, f"R69 authority population changed: {path}")
        for item in matches:
            lifecycle = item.get("current_lifecycle", {})
            require(
                item.get("status") == CLOSED_STATUS
                and item.get("current_lifecycle_status") == CLOSED_STATUS
                and item.get("qualification_passed") is True
                and item.get("campaign_attestation_adopted") is True
                and item.get("physical_campaign_opened") is True
                and item.get("world_attempt_count") == 9
                and item.get("world_build_count") == 9
                and item.get("finite_three_engine_turning") is False
                and item.get("q_sdk_r23_satisfied") is False
                and item.get("physical_acceptance_authority") is False
                and item.get("release_authorized") is False
                and lifecycle.get("closure_path") == CLOSURE_RELATIVE
                and lifecycle.get("closure_raw_sha256") == f"sha256:{closure_sha}"
                and lifecycle.get("closure_audit_path") == AUDIT_RELATIVE
                and lifecycle.get("closure_audit_raw_sha256") == f"sha256:{audit_sha}"
                and lifecycle.get("attempt_id") == ATTEMPT_ID
                and lifecycle.get("complete_native_horizon_count") == 9
                and lifecycle.get("execution_valid_cell_count") == 0,
                f"R69 live lifecycle projection changed: {path}",
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
            "R23D69" in text
            and "receipt" in text.lower()
            and "10/25" in text,
            f"R69 live documentation projection changed: {path}",
        )


def materialize() -> None:
    closure = build_closure()
    CLOSURE_PATH.write_text(canonical_json(closure), encoding="utf-8")
    print(
        "[turning/3e] MATERIALIZED R23D69 immutable physical closure: "
        "authorization=9/9 cells=9 worlds=9 horizons=9 traces=9 "
        "execution_valid=0 turning=False QSDK-R23=False score=10/25"
    )


def audit() -> None:
    expected = build_closure()
    require(CLOSURE_PATH.is_file(), "R23D69 closure is missing")
    actual = load_json(CLOSURE_PATH)
    require(actual == expected, "R23D69 closure claim vector changed")
    verify_live_authorities(sha256(CLOSURE_PATH), sha256(AUDIT_PATH))
    mutations = [
        ("status", "passing"),
        ("attempt.same_identity_rerun_allowed", True),
        ("attempt.world_build_count", 8),
        ("shared_receipt_schema_failure.physics_failure", True),
        ("claims.turning_claimed", True),
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
        "[turning/3e] PASS R23D69 immutable physical closure: qualification=16/16 "
        "adoption=True authorization=9/9 cells=9 worlds=9 horizons=9 traces=9 "
        "execution_valid=0 mutations=5 turning=False QSDK-R23=False score=10/25"
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
