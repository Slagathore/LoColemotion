#!/usr/bin/env python3
"""Materialize and audit the immutable R23D68 physical closure.

The observed evidence remains untouched.  This tool binds the complete retained
population, records the supervisor's original six-world report, and separately
records the nine complete native horizons proved by the retained production
trace paths and pinned source control flow.
"""

from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import subprocess
from typing import Any, Iterable


REPO_ROOT = Path(__file__).resolve().parents[2]
EVIDENCE_ROOT = (
    REPO_ROOT.parent
    / "SporeSpore_Evidence"
    / "qsdk-r23d68-physical-20260826T013723Z-23358ebb"
)
QUALIFICATION_ROOT = (
    REPO_ROOT.parent
    / "SporeSpore_Evidence"
    / "qsdk-r23d68-qualification-20260826T013058Z-23358ebb-commissioned-python"
)
ARTIFACT_ROOT = REPO_ROOT.parent / "SporeSpore_Evidence" / "artifacts" / "sha256"
CLOSURE_PATH = (
    REPO_ROOT
    / "sdk"
    / "turning"
    / "r23d68_production_route_three_engine_turning_validation_closure_v1.json"
)
AUDIT_PATH = REPO_ROOT / "tests" / "test_qsdk_r23d68_physical_closure.ps1"
RELEASE_PATH = REPO_ROOT / "sdk" / "release" / "quadruped_release_contract.json"
SUPPORT_PATH = REPO_ROOT / "sdk" / "release" / "quadruped_support_matrix.json"

SOURCE_COMMIT = "23358ebbc21fa4ddd5208c22a46b21e6abf8c4dc"
SOURCE_TREE = "00820b2baf193eaf1524b5481a468fed65d6b44d"
CAMPAIGN_ID = (
    "QSDK-R23D68-PRODUCTION-PATH-CONFORMANCE-REPAIRED-"
    "THREE-ENGINE-TURNING-VALIDATION"
)
GATE_ID = "QSDK-R23D68"
CLOSED_STATUS = (
    "closed_consumed_invalid_complete_nine_cell_population_"
    "three_engine_trace_schema_and_serialization_failures"
)
PREVIOUS_STATUS = (
    "prospective_declaration_complete_compact_production_path_ghosts_"
    "and_implementation_pending_physical_not_authorized"
)
CLOSURE_RELATIVE = (
    "sdk/turning/"
    "r23d68_production_route_three_engine_turning_validation_closure_v1.json"
)
AUDIT_RELATIVE = "tests/test_qsdk_r23d68_physical_closure.ps1"

CELL_IDS = [
    f"r23d68__{engine}__s23185__{arm}"
    for engine in ("godot_jolt", "rapier_parry", "mujoco")
    for arm in ("reference_zero", "positive_heading", "negative_heading")
]

PRIMARY_BINDINGS = {
    "physical-freeze.json": (315270, "c52a764820c987800b40fb3a86b310c1bf5b9641e53609ff8110394303f2e3df"),
    "attempt-authorization.json": (156456, "3418b5ad3d704a19e4de2df22342b797b76cb76236c3743cdade534ed1faf2ac"),
    "authorization-preflight.json": (25949, "035068f945d50e16164a83c86052bb611eccc96aff2cff3e8e2298ae4cb8bb70"),
    "complete-evaluation.json": (10104, "b9827c678406d4b8120311dc41e8abb04d5656f235b19cb6832a05187faaecbb"),
    "completion.json": (2953, "ebac91eb53adb2cc77e79b0687e5c94a5b5f6b4c2cae71442ea9cef551dc7844"),
    "report.json": (45563, "052d07cd283a2f54c00078c2a484c110c3993b7ffcc5e4eaca7ea7d82c473e1b"),
    "terminal-paths.json": (1435, "1415eeca5228e05fdaf0231acc5953ffe2b7ec7a3351d6ce04c448f46f0d3ac7"),
}

TERMINAL_BINDINGS = {
    "r23d68__godot_jolt__s23185__reference_zero": (118446, "2f514ab6e77d127b2d26c7299db7bb8da756b909484fd49361fb7bdb688a2846"),
    "r23d68__godot_jolt__s23185__positive_heading": (118458, "52ebf0de7861cc6646977b74f1301655db9c2d09f0e6cb893a60c6408f84d6e0"),
    "r23d68__godot_jolt__s23185__negative_heading": (118611, "45b89c830d95c7c5ac7a580b728bdb7050aaceadbb85ffc465ad50453bfbc7e8"),
    "r23d68__rapier_parry__s23185__reference_zero": (2078, "6dae28d0d6a67d1a7b31909b46904259bb5989dd846884c9aacf91c03fdecad0"),
    "r23d68__rapier_parry__s23185__positive_heading": (2082, "4ea5d666a938c398d9bdc4bce846c1e764cb548546e933de1b7f627a9ff69d6b"),
    "r23d68__rapier_parry__s23185__negative_heading": (2083, "deac3396047dcf2529eb6117eca72ec633ec0e35840b6d188288ddc6dcb05b9e"),
    "r23d68__mujoco__s23185__reference_zero": (1476, "8346b2cbf1af39faa15b676bc8ab601925c866408e2471e88ede7219a4f2db18"),
    "r23d68__mujoco__s23185__positive_heading": (1480, "d56aea796022808c0471a265e401311fc27414bc351fb28f0303af2fbc9d63e0"),
    "r23d68__mujoco__s23185__negative_heading": (1481, "5f5e00f26025b29cea713e7912d2894f32d421cd09de00c1cc46d9fd9e36aac6"),
}

GODOT_ROWS = {
    "reference_zero": (8278531, "d008a4ec0d6b5409277be53fde7f34376d559c7cc8084584edd9b2e796da7ce8"),
    "positive_heading": (8301981, "12884bd879b9701238365a676b995f6537284d891f4d63da0e7a75cf2718a73d"),
    "negative_heading": (8304497, "caf783f799887f7a8c416c3c403d28ff1fa70683d23edf1024736a7f60039db4"),
}

GODOT_DIAGNOSTICS = {
    "reference_zero": (7466702, "db2f518862c0cb9373d0e9d90e04843f909b08e2d4228475238d3a3ac5cc82b9"),
    "positive_heading": (7467232, "a1bb0cb0a7d34930d5ea93b1d7a5be3694d46d99599ca6ac6b35877bb7128333"),
    "negative_heading": (7470600, "2816f31ef67f410b83b7c312eb77473c03e2da2e0af5f5a5c07e4d16d14982ce"),
}

RAPIER_ROWS = {
    "reference_zero": (44657915, "0cc5709b3fa70c8412bf379f3b0c127d4cc64aa3d84ede528385bca221888b2b"),
    "positive_heading": (44627307, "9ed806e42c720fd16f32078a738b22847b6d6773a8d0b21553e30745de748ccf"),
    "negative_heading": (44629570, "b2ed7a2824690c8bef590183a548ad8e51d520af0dae7b1faf18af6b3ad7a180"),
}

MUJOCO_PARTIAL = (1590, "7b32b5b16180484e94edc556db4a9f191f81a4f39db0a078ed044ec5282ae472")

SOURCE_BLOBS = {
    "sdk/run_qsdk_r23d68_supervisor.ps1": "7d25bbd75b3ff877d3465741da566aa943625afb",
    "sdk/turning/r23d68_production_route_runtime.py": "5536a606a51ddcb4ea8c986910a6e35deb492d1d",
    "sdk/turning/r23d68_production_route_three_engine_turning_evaluator.py": "f827c87fa7c44d4176e9ec96be6e76be9223b986",
    "tests/test_sdk_qsdk_r23d68_godot_jolt_worker.gd": "fc171bcb811cdd1926648a5ee645d27f202b14dc",
    "scripts/lab/gait/physical_wave_gait_quadruped.gd": "21800d942fbc63c599a8c48f64bd0031e2016e95",
    "sdk/adapters/rapier/src/qsdk_r23d68_turning_route.rs": "1092a2befaf018f1d273caec21bd82df5654daf8",
    "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d27_physical.rs": "a820dcbbe4baa8d4fc9fca28e66412a8c263e590",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d68_turning_route.py": "06d85f7841100bedc5222d64dd62b592f5a3f464",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d65_selected_profile_turning.py": "6c4fb2052adda03d32d3309129b75369fed897f6",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d3_phase_balanced.py": "a20c31d137f6b70b0ab32b3c4c470530689e821c",
    "sdk/process_result_projection.ps1": "be3d194a4ce331b381f4a4a7c9a647cc1692742b",
}

CURRENT_REASON = (
    "R23D68 passed 16/16 clean-pushed qualification and separate adoption at source "
    "23358ebb, then consumed the complete nine-cell seed-23185 population after 9/9 "
    "authorization receipts. All nine worker processes reached retained terminal entries, "
    "but no cell was execution-valid. Godot/Jolt completed three 2,992-step native horizons "
    "whose rows lacked the actuator-phase observation required by the frozen evaluator. "
    "Rapier/Parry completed three 2,992-step native horizons whose final 592 rows retained "
    "the inherited after_declared_schedule label instead of reference_continuation. MuJoCo "
    "completed three 2,992-step native horizons and entered trace retention, where a non-native "
    "boolean made JSON serialization fail; the outer wrapper then replaced the inner "
    "settlement-complete 1/1 failure receipt with a before-world 0/0 terminal. The immutable "
    "report therefore records six worlds while the retained partial traces and pinned control "
    "flow prove nine complete native horizons. This is consumed invalid integration evidence, "
    "not a turning result. No threshold, selector, evaluator result, or interpretation changed; "
    "QSDK-R23 and the 11th gate remain unearned at 10/25."
)

OVERALL_REASON = (
    "No accepted portable three-engine commanded-turning campaign exists. R23D60 remains "
    "the exact bounded native Godot/Jolt positive; historical Rapier and MuJoCo positives "
    "remain separate and cannot be composed retrospectively. The separate production-route "
    "development population closed execution-valid in all three genuine engines without "
    "applying a behavior threshold. R23D66 is immutable invalid/incomplete zero-world "
    "integration evidence. R23D67 passed clean-pushed 16/16 qualification, separate adoption, "
    "and all 9/9 authorization receipts before its first Godot/Jolt world exposed a 592-row "
    "producer/evaluator segment-vocabulary mismatch and a subsequent PSCustomObject "
    "process-projection error; it is consumed invalid/incomplete integration evidence, not a "
    "turning result. R23D68 passed clean-pushed 16/16 qualification, separate adoption, and "
    "9/9 authorization receipts before consuming all nine seed-23185 cells. Three Godot/Jolt "
    "and three Rapier/Parry complete horizons failed frozen trace-schema retention; three "
    "MuJoCo complete horizons failed strict JSON retention and their outer wrapper underreported "
    "the inner physical stage/counts. The immutable six-world supervisor report and separate "
    "pinned proof of nine complete native horizons are both preserved. R23D68 is consumed "
    "invalid integration evidence, not a turning result. QSDK-R23, formal cross-engine "
    "equivalence, broader morphology or robustness, prone-to-standing, physical acceptance, "
    "and release authority remain false. Readiness remains 10/25."
)


class ClosureError(RuntimeError):
    """Fail-closed R23D68 closure error."""


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


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def canonical_json(value: Any) -> str:
    return json.dumps(value, indent=2, ensure_ascii=False) + "\n"


def git(*arguments: str) -> str:
    result = subprocess.run(
        ["git", *arguments],
        cwd=REPO_ROOT,
        check=False,
        capture_output=True,
        text=True,
    )
    require(result.returncode == 0, f"git failed: {' '.join(arguments)}: {result.stderr}")
    return result.stdout.strip()


def verify_file(path: Path, expected: tuple[int, str]) -> None:
    require(path.is_file(), f"missing retained file: {path}")
    require(path.stat().st_size == expected[0], f"byte length drift: {path}")
    require(sha256(path) == expected[1], f"digest drift: {path}")


def pending_name(engine: str, arm: str) -> str:
    if engine == "godot_jolt":
        return f"r23d68__godot_jolt__s23185__{arm}.rows.json"
    return (
        "production_path_conformance_repaired_three_engine_turning_validation__"
        f"r23d68__{engine}__s23185__{arm}.rows.json"
    )


def population_identity(root: Path) -> dict[str, Any]:
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
        payload = ARTIFACT_ROOT / raw / "payload.bin"
        if not payload.is_file() or payload.stat().st_size != size or sha256(payload) != raw:
            non_cas.append(relative)
    manifest = "".join(lines).encode("utf-8")
    return {
        "complete_file_population_count": len(files),
        "complete_file_population_byte_count": total_bytes,
        "retained_unique_digest_count": len(digests),
        "cas_backed_file_count": len(files) - len(non_cas),
        "non_cas_file_count": len(non_cas),
        "non_cas_relative_paths": non_cas,
        "canonical_population_manifest_format": (
            "relative_path<TAB>byte_length<TAB>sha256:<lowercase_hex><LF>"
        ),
        "canonical_population_manifest_sort_order": "relative_path_unicode_codepoint_ascending",
        "canonical_population_manifest_byte_length": len(manifest),
        "canonical_population_manifest_sha256": (
            "sha256:" + hashlib.sha256(manifest).hexdigest()
        ),
    }


def source_text(relative: str) -> str:
    result = subprocess.run(
        ["git", "show", f"{SOURCE_COMMIT}:{relative}"],
        cwd=REPO_ROOT,
        check=False,
        capture_output=True,
    )
    require(result.returncode == 0, f"pinned source unavailable: {relative}")
    return result.stdout.decode("utf-8")


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

    godot_worker = source_text("tests/test_sdk_qsdk_r23d68_godot_jolt_worker.gd")
    rapier_row = source_text(
        "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d27_physical.rs"
    )
    mujoco_core = source_text(
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d3_phase_balanced.py"
    )
    mujoco_wrapper = source_text(
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d68_turning_route.py"
    )
    require(
        'trace_options["post_schedule_segment_id"] = "reference_continuation"'
        in godot_worker
        and "actuator_phase_observation_schema_version" not in godot_worker,
        "Godot missing-observation source diagnosis changed",
    )
    require(
        'let segment_id = if phase_id == "reference_continuation"' in rapier_row
        and '"after_declared_schedule"' in rapier_row,
        "Rapier post-schedule source diagnosis changed",
    )
    require(
        "for semantic_step in range(CONTROLLER_STEPS):" in mujoco_core
        and "trace = _retain_trace(cell, rows, authorization[\"attempt_root\"])" in mujoco_core
        and '"world_attempt_count": 1' in mujoco_core
        and '"world_build_count": 1' in mujoco_core,
        "MuJoCo complete-horizon control flow changed",
    )
    require(
        "except (" in mujoco_wrapper
        and "production._core.R23D3MujocoError" in mujoco_wrapper
        and "value = _failure_terminal(" in mujoco_wrapper,
        "MuJoCo outer failure-projection diagnosis changed",
    )


def verify_and_summarize_engine_evidence() -> list[dict[str, Any]]:
    summaries: list[dict[str, Any]] = []
    pending_root = EVIDENCE_ROOT / "pending-traces"
    cells_root = EVIDENCE_ROOT / "cells"
    expected_segments = {
        "reference_warmup": 600,
        "commanded_turn": 1200,
        "reference_recovery": 600,
        "reference_continuation": 592,
    }

    for cell_id in CELL_IDS:
        verify_file(cells_root / cell_id / "terminal.json", TERMINAL_BINDINGS[cell_id])

    for arm in ("reference_zero", "positive_heading", "negative_heading"):
        cell_id = f"r23d68__godot_jolt__s23185__{arm}"
        terminal = load_json(cells_root / cell_id / "terminal.json")
        rows_path = pending_root / pending_name("godot_jolt", arm)
        diagnostic_path = pending_root / f"{cell_id}.trace-diagnostic.json"
        verify_file(rows_path, GODOT_ROWS[arm])
        verify_file(diagnostic_path, GODOT_DIAGNOSTICS[arm])
        rows = load_json(rows_path)
        diagnostic = load_json(diagnostic_path)
        segments = Counter(row.get("segment_id") for row in rows)
        require(len(rows) == 2992, f"Godot row count changed: {arm}")
        require(segments == expected_segments, f"Godot segment counts changed: {arm}")
        require(
            all("actuator_phase_observation" not in row for row in rows),
            f"Godot observation absence changed: {arm}",
        )
        require(
            terminal.get("failure_code") == "QSDK_R23D68_GJT_TRACE_RETENTION_FAILED:1"
            and terminal.get("failure_stage") == "controller_horizon_complete"
            and terminal.get("world_attempt_count") == 1
            and terminal.get("world_build_count") == 1
            and diagnostic.get("actual_row_count") == 2992
            and diagnostic.get("contiguous_row_count") == 2992
            and "R23D58_OBSERVATION_MISSING:0"
            in diagnostic["trace_retention_failure_detail"]["output"][0],
            f"Godot terminal diagnosis changed: {arm}",
        )
        summaries.append(
            {
                "engine_id": "godot_jolt",
                "arm_id": arm,
                "cell_id": cell_id,
                "terminal": binding(cells_root / cell_id / "terminal.json"),
                "rows": binding(rows_path),
                "trace_diagnostic": binding(diagnostic_path),
                "retained_row_count": 2992,
                "complete_horizon_proved": True,
                "missing_actuator_phase_observation_row_count": 2992,
                "reported_world_attempt_count": 1,
                "reported_world_build_count": 1,
                "execution_valid": False,
            }
        )

    for arm in ("reference_zero", "positive_heading", "negative_heading"):
        cell_id = f"r23d68__rapier_parry__s23185__{arm}"
        terminal = load_json(cells_root / cell_id / "terminal.json")
        rows_path = pending_root / pending_name("rapier_parry", arm)
        verify_file(rows_path, RAPIER_ROWS[arm])
        rows = load_json(rows_path)
        segments = Counter(row.get("segment_id") for row in rows)
        require(len(rows) == 2992, f"Rapier row count changed: {arm}")
        require(
            segments
            == {
                "reference_warmup": 600,
                "commanded_turn": 1200,
                "reference_recovery": 600,
                "after_declared_schedule": 592,
            },
            f"Rapier segment counts changed: {arm}",
        )
        require(
            all("actuator_phase_observation" in row for row in rows),
            f"Rapier observation population changed: {arm}",
        )
        require(
            terminal.get("failure_stage") == "settlement_complete"
            and "R23D34_TRACE_ROW_INVALID:2400" in terminal.get("failure_code", "")
            and terminal.get("world_attempt_count") == 1
            and terminal.get("world_build_count") == 1,
            f"Rapier terminal diagnosis changed: {arm}",
        )
        summaries.append(
            {
                "engine_id": "rapier_parry",
                "arm_id": arm,
                "cell_id": cell_id,
                "terminal": binding(cells_root / cell_id / "terminal.json"),
                "rows": binding(rows_path),
                "retained_row_count": 2992,
                "complete_horizon_proved": True,
                "mislabeled_post_schedule_row_count": 592,
                "reported_world_attempt_count": 1,
                "reported_world_build_count": 1,
                "execution_valid": False,
            }
        )

    for arm in ("reference_zero", "positive_heading", "negative_heading"):
        cell_id = f"r23d68__mujoco__s23185__{arm}"
        terminal = load_json(cells_root / cell_id / "terminal.json")
        rows_path = pending_root / pending_name("mujoco", arm)
        verify_file(rows_path, MUJOCO_PARTIAL)
        partial = rows_path.read_bytes()
        try:
            json.loads(partial)
        except json.JSONDecodeError:
            pass
        else:
            raise ClosureError(f"MuJoCo partial trace unexpectedly became valid JSON: {arm}")
        require(
            partial.endswith(b'"target_velocity_readback_matches":')
            and terminal.get("failure_stage") == "before_world"
            and terminal.get("world_attempt_count") == 0
            and terminal.get("world_build_count") == 0
            and "Object of type bool is not JSON serializable"
            in terminal.get("failure_code", ""),
            f"MuJoCo retained failure changed: {arm}",
        )
        summaries.append(
            {
                "engine_id": "mujoco",
                "arm_id": arm,
                "cell_id": cell_id,
                "terminal": binding(cells_root / cell_id / "terminal.json"),
                "partial_rows": binding(rows_path),
                "complete_horizon_proved_by_pinned_retain_trace_control_flow": True,
                "serialization_stopped_at_field": "target_velocity_readback_matches",
                "outer_terminal_reported_world_attempt_count": 0,
                "outer_terminal_reported_world_build_count": 0,
                "inner_failure_receipt_expected_world_attempt_count": 1,
                "inner_failure_receipt_expected_world_build_count": 1,
                "execution_valid": False,
            }
        )
    return summaries


def build_closure() -> dict[str, Any]:
    verify_source_identity()
    require(EVIDENCE_ROOT.is_dir(), "R23D68 physical evidence root is missing")
    require(QUALIFICATION_ROOT.is_dir(), "R23D68 adopted qualification root is missing")
    for name, expected in PRIMARY_BINDINGS.items():
        verify_file(EVIDENCE_ROOT / name, expected)

    physical_population = population_identity(EVIDENCE_ROOT)
    require(
        physical_population
        == {
            "complete_file_population_count": 66,
            "complete_file_population_byte_count": 182502686,
            "retained_unique_digest_count": 47,
            "cas_backed_file_count": 57,
            "non_cas_file_count": 9,
            "non_cas_relative_paths": [
                f"pending-traces/{pending_name('mujoco', arm)}"
                for arm in ("negative_heading", "positive_heading", "reference_zero")
            ]
            + [
                f"pending-traces/{pending_name('rapier_parry', arm)}"
                for arm in ("negative_heading", "positive_heading", "reference_zero")
            ]
            + [
                f"pending-traces/{pending_name('godot_jolt', arm)}"
                for arm in ("negative_heading", "positive_heading", "reference_zero")
            ],
            "canonical_population_manifest_format": (
                "relative_path<TAB>byte_length<TAB>sha256:<lowercase_hex><LF>"
            ),
            "canonical_population_manifest_sort_order": (
                "relative_path_unicode_codepoint_ascending"
            ),
            "canonical_population_manifest_byte_length": 9665,
            "canonical_population_manifest_sha256": (
                "sha256:a4b7c584ad8a9d719d75516ca6fbd9369bed4e6ef3b453f050fc181ab0de913f"
            ),
        },
        "complete retained physical population changed",
    )

    qualification_files = [path for path in QUALIFICATION_ROOT.rglob("*") if path.is_file()]
    require(len(qualification_files) == 50, "qualification file count changed")
    require(
        sum(path.stat().st_size for path in qualification_files) == 496146,
        "qualification byte count changed",
    )
    attestation_path = QUALIFICATION_ROOT / "attestation.json"
    adoption_path = QUALIFICATION_ROOT / "adoption.json"
    verify_file(
        attestation_path,
        (150560, "eefc41d1489e61f64ed3002f079ab9213125e399b71eb9a0e34da859c87d6ccd"),
    )
    verify_file(
        adoption_path,
        (3310, "f7f50a067d1634ae29c50eaf34791cd1839a5ebaf43de35c1c7d4fba05f20c0c"),
    )
    attestation = load_json(attestation_path)
    adoption = load_json(adoption_path)
    require(
        attestation.get("source", {}).get("commit") == SOURCE_COMMIT
        and attestation.get("executed_gate_count") == 16
        and attestation.get("all_gates_executed") is True
        and adoption.get("source_commit") == SOURCE_COMMIT
        and adoption.get("physical_launch_prerequisite_satisfied") is True
        and adoption.get("physical_acceptance_authority") is False,
        "qualification or adoption semantics changed",
    )

    freeze = load_json(EVIDENCE_ROOT / "physical-freeze.json")
    attempt = load_json(EVIDENCE_ROOT / "attempt-authorization.json")
    authorization = load_json(EVIDENCE_ROOT / "authorization-preflight.json")
    evaluation = load_json(EVIDENCE_ROOT / "complete-evaluation.json")
    completion = load_json(EVIDENCE_ROOT / "completion.json")
    report = load_json(EVIDENCE_ROOT / "report.json")
    require(
        freeze.get("source_commit") == SOURCE_COMMIT
        and len(freeze.get("implementation_dependency_digests", {})) == 212
        and len(freeze.get("source_bindings", [])) == 212
        and len(freeze.get("runtime_artifacts", [])) == 3
        and len(freeze.get("external_runtime_bindings", [])) == 5
        and freeze.get("physical_execution_authorized") is True
        and attempt.get("attempt_id") == "58e4c8b03b074affb51c80eb6f6f65b1"
        and authorization.get("receipt_count") == 9
        and authorization.get("pass_count") == 9
        and authorization.get("complete_matrix_passed") is True,
        "freeze, attempt, or authorization population changed",
    )
    require(
        completion.get("status")
        == "invalid_or_incomplete_exact_seed_23185_three_engine_portable_turning"
        and completion.get("cell_count") == 9
        and completion.get("world_count_exact") is True
        and completion.get("world_count_lower_bound") == 6
        and completion.get("world_count_upper_bound") == 6
        and completion.get("finite_three_engine_turning_positive") is False
        and completion.get("one_shot_attempt_consumed") is True
        and completion.get("replacement_or_selective_rerun_permitted") is False
        and evaluation.get("classification") == completion.get("status")
        and len(evaluation.get("cell_evaluations", [])) == 9
        and all(not item.get("execution_valid") for item in evaluation["cell_evaluations"])
        and evaluation.get("posthoc_threshold_or_selector_change_performed") is False
        and report.get("result_classification") == completion.get("status"),
        "complete invalid evaluation changed",
    )

    cells = verify_and_summarize_engine_evidence()
    primary = {
        name.removesuffix(".json").replace("-", "_"): binding(EVIDENCE_ROOT / name)
        for name in PRIMARY_BINDINGS
    }
    return {
        "schema_version": (
            "sporespore_qsdk_r23d68_production_route_three_engine_turning_"
            "validation_closure_v1"
        ),
        "status": CLOSED_STATUS,
        "closed_utc": "2026-08-26T01:57:12.0403866Z",
        "observed_completion_utc": "2026-08-26T01:50:58.6064444Z",
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "release_gate_id": "QSDK-R23",
        "ledger_scope": {
            "subsystem": "turning",
            "engine_scope": "3e",
            "authority_mode": "official_physical_closure",
            "question_class": "finite_decision",
        },
        "physical_question_class": "finite_decision",
        "observed_failure_question_class": "integration_contract_failure",
        "source": {
            "commit": SOURCE_COMMIT,
            "tree_git_oid": SOURCE_TREE,
            "pinned_source_blob_oids": SOURCE_BLOBS,
            "clean_pushed_live_equal_at_launch": True,
        },
        "qualification": {
            "root": QUALIFICATION_ROOT.resolve().as_posix(),
            "complete_retained_file_count": 50,
            "complete_retained_byte_count": 496146,
            "attestation": binding(attestation_path),
            "adoption": binding(adoption_path),
            "global_gate_count": 12,
            "lineage_gate_count": 1,
            "campaign_role_gate_count": 3,
            "executed_gate_count": 16,
            "qualification_passed": True,
            "adoption_passed": True,
            "physical_launch_prerequisite_satisfied": True,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "physical_acceptance_authority": False,
        },
        "attempt": {
            "root": EVIDENCE_ROOT.resolve().as_posix(),
            "attempt_id": "58e4c8b03b074affb51c80eb6f6f65b1",
            "campaign_seed": 23185,
            "campaign_identity_consumed": True,
            "held_out_condition_consumed": True,
            "same_identity_rerun_allowed": False,
            "replacement_or_selective_rerun_allowed": False,
            "all_declared_cells_executed_or_retained_as_failures": True,
            "physical_execution_observation_exists": True,
            "physical_outcome_exposed": True,
            **primary,
        },
        "frozen_input_population": {
            "implementation_dependency_count": 212,
            "source_binding_count": 212,
            "built_runtime_artifact_count": 3,
            "external_runtime_binding_count": 5,
            "runtime_binding_count": 8,
            "campaign_attestation_adoption_binding_count": 1,
            "complete_content_addressed_input_count": 221,
            "dependency_toolchain_environment_key": (
                "c5e6a53258f270d35983087aba8cdfd18785162c074d80e2e9a0a80831891e95"
            ),
            "source_checkout_bytes_equal_git_blobs": True,
            "complete_zero_world_gate_passed": True,
        },
        "retained_evidence": physical_population,
        "authorization_population": {
            "declared_cell_count": 9,
            "retained_receipt_count": 9,
            "accepted_receipt_count": 9,
            "rejected_receipt_count": 0,
            "complete_matrix_passed": True,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
        },
        "execution_population": {
            "physical_worker_process_count": 9,
            "retained_physical_cell_terminal_count": 9,
            "complete_evaluator_cell_count": 9,
            "execution_valid_cell_count": 0,
            "supervisor_reported_world_count_exact": True,
            "supervisor_reported_world_attempt_count": 6,
            "supervisor_reported_world_build_count": 6,
            "complete_native_horizon_count_proved_by_retained_evidence_and_pinned_control_flow": 9,
            "closure_derived_world_attempt_count": 9,
            "closure_derived_world_build_count": 9,
            "supervisor_report_rewritten": False,
            "world_count_reconciliation_required": True,
            "ordered_cells": cells,
        },
        "failure_mechanisms": [
            {
                "class": "godot_trace_rows_missing_required_actuator_phase_observation",
                "affected_cell_count": 3,
                "affected_row_count_per_cell": 2992,
                "complete_native_horizon_per_cell": True,
                "failure_code": "QSDK_R23D68_GJT_TRACE_RETENTION_FAILED:1",
                "first_bounded_evaluator_error": "R23D58_OBSERVATION_MISSING:0",
            },
            {
                "class": "rapier_inherited_post_schedule_segment_relabeling",
                "affected_cell_count": 3,
                "affected_first_semantic_step": 2400,
                "affected_last_semantic_step": 2991,
                "affected_row_count_per_cell": 592,
                "producer_segment_id": "after_declared_schedule",
                "evaluator_expected_segment_id": "reference_continuation",
                "complete_native_horizon_per_cell": True,
            },
            {
                "class": "mujoco_non_native_boolean_trace_json_serialization_failure",
                "affected_cell_count": 3,
                "failure_stage_from_pinned_inner_worker": "settlement_complete_trace_retention",
                "failure_code_suffix": (
                    "TypeError:Object of type bool is not JSON serializable"
                ),
                "serialization_stopped_at_field": "target_velocity_readback_matches",
                "complete_native_horizon_per_cell": True,
            },
            {
                "class": "mujoco_outer_failure_projection_discarded_inner_stage_and_counts",
                "affected_cell_count": 3,
                "outer_terminal_failure_stage": "before_world",
                "outer_terminal_world_count_per_cell": 0,
                "inner_failure_stage": "settlement_complete",
                "inner_failure_world_count_per_cell": 1,
                "original_outer_terminals_and_supervisor_report_preserved": True,
            },
        ],
        "official_result": {
            "scientific_turning_result_exists": False,
            "valid_physical_cell_result_exists": False,
            "finite_three_engine_turning": False,
            "portable_basic_turning": False,
            "q_sdk_r23_satisfied": False,
            "cross_engine_equivalence": False,
            "prone_to_standing": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
            "release_score_before": "10/25",
            "release_score_after": "10/25",
            "release_score_changed": False,
        },
        "successor_boundary": {
            "distinct_successor_required": True,
            "same_seed_reuse_allowed": False,
            "same_attempt_reuse_allowed": False,
            "selective_completion_allowed": False,
            "retained_rows_may_be_reused_as_successor_physical_evidence": False,
            "threshold_selector_evaluator_or_interpretation_change_required": False,
            "minimum_integration_repair_population": [
                "actual Godot production row includes the evaluator-required actuator-phase observation",
                "actual Rapier production row preserves reference_continuation at semantic step 2400",
                "actual MuJoCo production row is strict-JSON serializable before any official physical launch",
                "MuJoCo outer failure projection preserves inner physical stage and world counts",
                "compact production-shaped ghosts validate complete representative rows through the frozen evaluator",
                "complete qualified successor population passes before any fresh physical world",
            ],
            "next_physical_question_class_if_opened": "finite_decision",
            "next_integration_repair_work_class": (
                "development_then_complete_population_equivalence_non_inferiority"
            ),
        },
        "claims": {
            "campaign_closed": True,
            "retained_evidence_complete": True,
            "campaign_identity_consumed": True,
            "historical_result_reinterpreted": False,
            "nine_complete_native_horizons_observed": True,
            "turning_claimed": False,
            "q_sdk_r23_satisfied": False,
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


def lifecycle_projection(closure_sha: str, audit_sha: str) -> dict[str, Any]:
    return {
        "closure_path": CLOSURE_RELATIVE,
        "closure_raw_sha256": f"sha256:{closure_sha}",
        "closure_audit_path": AUDIT_RELATIVE,
        "closure_audit_raw_sha256": f"sha256:{audit_sha}",
        "qualification_root": QUALIFICATION_ROOT.resolve().as_posix(),
        "qualification_attestation_raw_sha256": (
            "sha256:eefc41d1489e61f64ed3002f079ab9213125e399b71eb9a0e34da859c87d6ccd"
        ),
        "qualification_adoption_raw_sha256": (
            "sha256:f7f50a067d1634ae29c50eaf34791cd1839a5ebaf43de35c1c7d4fba05f20c0c"
        ),
        "qualification_gate_pass_count": 16,
        "attempt_root": EVIDENCE_ROOT.resolve().as_posix(),
        "attempt_id": "58e4c8b03b074affb51c80eb6f6f65b1",
        "authorization_receipt_count": 9,
        "authorization_pass_count": 9,
        "physical_worker_process_count": 9,
        "supervisor_reported_world_attempt_count": 6,
        "supervisor_reported_world_build_count": 6,
        "closure_derived_world_attempt_count": 9,
        "closure_derived_world_build_count": 9,
        "complete_native_horizon_count": 9,
        "execution_valid_cell_count": 0,
        "campaign_identity_consumed": True,
        "q_sdk_r23_satisfied": False,
        "physical_acceptance_authority": False,
    }


def update_authority(value: Any, closure_sha: str, audit_sha: str) -> tuple[int, int]:
    lifecycle_count = 0
    current_count = 0
    for item in walk_dicts(value):
        if item.get("campaign_id") == CAMPAIGN_ID and item.get("gate_id") == GATE_ID:
            item.update(
                status=CLOSED_STATUS,
                current_lifecycle_status=CLOSED_STATUS,
                current_lifecycle=lifecycle_projection(closure_sha, audit_sha),
                implementation_complete=True,
                compact_production_path_ghosts_passed=True,
                complete_zero_world_gate_passed=True,
                complete_nine_cell_authorization_ghost_passed=True,
                qualification_passed=True,
                campaign_attestation_adopted=True,
                physical_campaign_opened=True,
                model_construction_count=0,
                world_attempt_count=9,
                world_build_count=9,
                finite_three_engine_turning=False,
                portable_basic_turning=False,
                q_sdk_r23_satisfied=False,
                cross_engine_equivalence=False,
                prone_to_standing=False,
                physical_acceptance_authority=False,
                release_authorized=False,
            )
            lifecycle_count += 1
        if item.get("current_prospective_successor_status") in (
            PREVIOUS_STATUS,
            CLOSED_STATUS,
        ):
            item["current_prospective_successor_status"] = CLOSED_STATUS
            item["current_prospective_successor_reason"] = CURRENT_REASON
            current_count += 1
        if item.get("current_score_bearing_successor_status") in (
            PREVIOUS_STATUS,
            CLOSED_STATUS,
        ):
            item["current_score_bearing_successor_status"] = CLOSED_STATUS
            item["current_score_bearing_successor_reason"] = CURRENT_REASON
            current_count += 1
    return lifecycle_count, current_count


DOC_REPLACEMENTS = {
    REPO_ROOT / "docs" / "README.md": (
        "## Current prospective held-out turning decision: R23D68",
        "## Consumed held-out turning decision: R23D67",
        """## Current consumed held-out turning decision: R23D68

`QSDK-R23D68` passed all `16/16` clean-pushed qualification gates and separate
exact-source adoption at `23358ebb`, then consumed the complete nine-cell
seed-`23185` population after all `9/9` authorization receipts passed.

All nine native worker processes reached terminal retention, but none produced
an execution-valid cell. Godot/Jolt completed three `2,992`-step horizons whose
rows lacked the frozen evaluator's actuator-phase observation. Rapier/Parry
completed three `2,992`-step horizons whose final `592` rows still used
`after_declared_schedule`. MuJoCo completed three `2,992`-step horizons, then
strict JSON retention stopped on a non-native boolean. Its outer wrapper lost
the inner settlement-complete `1/1` receipt and emitted before-world `0/0`, so
the immutable supervisor report says six worlds while retained partial traces
and pinned control flow prove nine complete horizons.

The exact [closure](../sdk/turning/r23d68_production_route_three_engine_turning_validation_closure_v1.json)
and [audit](../tests/test_qsdk_r23d68_physical_closure.ps1) bind all `66` files
and `182,502,686` bytes without changing the original report. R23D68 is
consumed invalid integration evidence, not a turning positive or negative. It
cannot rerun or be selectively completed. `QSDK-R23`, equivalence,
prone-to-standing, acceptance, and release remain false at `10/25`.

A distinct successor must validate representative complete production rows
through the frozen evaluator for every engine, including strict MuJoCo JSON and
failure-count projection, before a fresh physical world may open.

""",
    ),
    REPO_ROOT / "docs" / "ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md": (
        "## 2026-08-25 R23D68 prospective release-distance boundary",
        "## 2026-08-25 R23D67 consumed release-distance boundary",
        """## 2026-08-26 R23D68 consumed release-distance boundary

R23D68 was a prospectively frozen **finite decision** on seed `23185`. Source
`23358ebb` passed `16/16` qualification, separate adoption, and the complete
`9/9` authorization population before the one-shot supervisor ran all nine
native cells.

The resulting finite population is complete but invalid. Three Godot/Jolt
horizons lack required actuator-phase observations, three Rapier/Parry
horizons retain the wrong final-`592` segment label, and three MuJoCo horizons
fail strict JSON retention on a non-native boolean. MuJoCo's outer failure
wrapper also replaced each inner settlement-complete `1/1` receipt with a
before-world `0/0` terminal. The original six-world report is preserved; the
closure separately binds the partial traces and pinned control flow proving all
nine complete native horizons.

The immutable [closure](../sdk/turning/r23d68_production_route_three_engine_turning_validation_closure_v1.json)
and [audit](../tests/test_qsdk_r23d68_physical_closure.ps1) compare the complete
`66`-file, `182,502,686`-byte population. No threshold, selector, evaluator
result, or interpretation changed. R23D68 is consumed invalid integration
evidence and supplies no turning result, so readiness remains `10/25`.

The next work is development followed by exact complete-population conformance.
Representative complete rows from each actual production composer must pass
the frozen evaluator, strict MuJoCo serialization, and failure-count projection
before a distinct qualified finite decision can open physics.

""",
    ),
    REPO_ROOT / "docs" / "SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md": (
        "## Current prospective score-bearing decision: R23D68",
        "## Consumed score-bearing decision: R23D67",
        """## Current consumed score-bearing decision: R23D68

R23D68 passed `16/16` clean-pushed qualification, separate adoption, and all
`9/9` authorization receipts before its one-shot finite population ran. All
nine cells are retained, but all nine are execution-invalid at production trace
retention: Godot rows omit required actuator-phase observations, Rapier's final
`592` rows use the inherited post-schedule label, and MuJoCo cannot serialize a
non-native boolean.

The MuJoCo inner worker reached retention after each complete `2,992`-step
horizon, but the outer wrapper discarded its settlement-complete `1/1` receipt
and emitted before-world `0/0`. The exact [closure](../sdk/turning/r23d68_production_route_three_engine_turning_validation_closure_v1.json)
preserves the original six-world report while independently binding the nine
complete native horizons. The complete evidence population is `66` files and
`182,502,686` bytes.

This is consumed invalid integration evidence, not a behavioral result. The
seed cannot rerun, thresholds and interpretation remain frozen, and readiness
stays `10/25`. A distinct successor requires compact complete-row production
ghosts across all three engines before qualification or physics.

""",
    ),
    REPO_ROOT / "docs" / "LOCOMOTION_GROUND_UP_RESEARCH_PROGRAM.md": (
        "## Prospective R23D68 finite-decision contract",
        "## ",
        """## Consumed R23D68 finite-decision contract

R23D68 consumed seed `23185` only after clean-pushed `16/16` qualification,
separate adoption, and `9/9` authorization receipts. The complete nine-cell
population is retained but execution-invalid before behavioral evaluation.
Godot lacks required actuator-phase observations, Rapier mislabels the final
`592` rows, and MuJoCo fails strict JSON serialization after complete horizons;
its outer wrapper also loses the inner physical stage and world counts.

The [closure authority](../sdk/turning/r23d68_production_route_three_engine_turning_validation_closure_v1.json)
binds the original report and the complete retained population separately. No
threshold, selector, evaluator result, or interpretation was altered. This is
finite invalid integration evidence with no population inference and no
turning, equivalence, robustness, or release claim.

""",
    ),
}


def replace_section(path: Path, start: str, end: str, replacement: str) -> None:
    text = path.read_text(encoding="utf-8")
    start_index = text.find(start)
    if start_index < 0 and replacement.splitlines()[0] in text:
        return
    require(start_index >= 0, f"documentation start marker missing: {path}")
    end_index = text.find(end, start_index + len(start))
    require(end_index >= 0, f"documentation end marker missing: {path}")
    path.write_text(text[:start_index] + replacement + text[end_index:], encoding="utf-8")


def update_architecture() -> None:
    path = REPO_ROOT / "docs" / "LOCOMOTION_ARCHITECTURE.md"
    text = path.read_text(encoding="utf-8")
    start = text.find("R23D68 prospectively instantiates that architecture")
    if start < 0 and "R23D68 consumed that architecture" in text:
        return
    require(start >= 0, "architecture R23D68 marker missing")
    end = text.find("\n\n", start)
    while end >= 0 and "physical" not in text[start:end].lower():
        end = text.find("\n\n", end + 2)
    require(end >= 0, "architecture R23D68 paragraph end missing")
    replacement = (
        "R23D68 consumed that architecture across all nine native cells, but "
        "exposed three production trace contracts that the compact helper ghosts "
        "did not cover: complete Godot row observations, Rapier's inherited final "
        "segment relabeling, and strict MuJoCo row serialization plus inner failure "
        "projection. Its closure preserves the original report and separately binds "
        "the pinned control-flow proof for nine complete horizons. Future ghosts must "
        "pass representative complete production rows through the actual frozen "
        "evaluator; helper-only witnesses are insufficient for physical authorization."
    )
    path.write_text(text[:start] + replacement + text[end:], encoding="utf-8")


def verify_live_authorities(closure_sha: str, audit_sha: str) -> None:
    for path, expected_lifecycle, expected_current in (
        (RELEASE_PATH, 1, 1),
        (SUPPORT_PATH, 2, 1),
    ):
        value = load_json(path)
        lifecycle = [
            item
            for item in walk_dicts(value)
            if item.get("campaign_id") == CAMPAIGN_ID and item.get("gate_id") == GATE_ID
        ]
        current = [
            item
            for item in walk_dicts(value)
            if item.get("current_prospective_successor_status") == CLOSED_STATUS
        ]
        require(len(lifecycle) == expected_lifecycle, f"lifecycle count changed: {path}")
        require(len(current) == expected_current, f"current status count changed: {path}")
        for item in lifecycle:
            current_lifecycle = item.get("current_lifecycle", {})
            require(
                item.get("status") == CLOSED_STATUS
                and item.get("world_attempt_count") == 9
                and item.get("world_build_count") == 9
                and item.get("q_sdk_r23_satisfied") is False
                and current_lifecycle.get("closure_raw_sha256") == f"sha256:{closure_sha}"
                and current_lifecycle.get("closure_audit_raw_sha256") == f"sha256:{audit_sha}",
                f"lifecycle closure projection changed: {path}",
            )


def matching_brace_end(text: str, start: int) -> int:
    require(text[start] == "{", "JSON object span did not start at a brace")
    depth = 0
    quoted = False
    escaped = False
    for index in range(start, len(text)):
        character = text[index]
        if quoted:
            if escaped:
                escaped = False
            elif character == "\\":
                escaped = True
            elif character == '"':
                quoted = False
            continue
        if character == '"':
            quoted = True
        elif character == "{":
            depth += 1
        elif character == "}":
            depth -= 1
            if depth == 0:
                return index + 1
    raise ClosureError("unterminated JSON object while updating release authority")


def render_embedded_object(value: dict[str, Any], leading_spaces: str) -> str:
    lines = json.dumps(value, indent=2, ensure_ascii=False).splitlines()
    return lines[0] + "\n" + "\n".join(leading_spaces + line for line in lines[1:])


def update_current_fields(text: str) -> tuple[str, int]:
    status_pattern = re.compile(
        r'("current_prospective_successor_status"\s*:\s*)'
        r'("(?:\\.|[^"\\])*")'
    )
    reason_pattern = re.compile(
        r'("current_prospective_successor_reason"\s*:\s*)'
        r'("(?:\\.|[^"\\])*")'
    )
    status_count = 0

    def status_replacement(match: re.Match[str]) -> str:
        nonlocal status_count
        current = json.loads(match.group(2))
        if current not in (PREVIOUS_STATUS, CLOSED_STATUS):
            return match.group(0)
        status_count += 1
        return match.group(1) + json.dumps(CLOSED_STATUS)

    text = status_pattern.sub(status_replacement, text)
    reason_count = 0

    def reason_replacement(match: re.Match[str]) -> str:
        nonlocal reason_count
        current = json.loads(match.group(2))
        if "R23D68" not in current:
            return match.group(0)
        reason_count += 1
        return match.group(1) + json.dumps(CURRENT_REASON, ensure_ascii=False)

    text = reason_pattern.sub(reason_replacement, text)
    require(reason_count == status_count, "current R23D68 reason/status count diverged")
    return text, status_count


def update_overall_reason(text: str) -> tuple[str, int]:
    reason_pattern = re.compile(r'("reason"\s*:\s*)("(?:\\.|[^"\\])*")')
    reason_count = 0

    def replacement(match: re.Match[str]) -> str:
        nonlocal reason_count
        current = json.loads(match.group(2))
        if (
            "No accepted portable three-engine commanded-turning campaign exists" not in current
            or "R23D68" not in current
        ):
            return match.group(0)
        reason_count += 1
        return match.group(1) + json.dumps(OVERALL_REASON, ensure_ascii=False)

    return reason_pattern.sub(replacement, text), reason_count


def update_authority_file(
    path: Path,
    closure_sha: str,
    audit_sha: str,
    expected_lifecycle_count: int,
    expected_current_count: int,
    expected_overall_reason_count: int,
) -> None:
    text = path.read_text(encoding="utf-8")
    needle = f'"campaign_id": "{CAMPAIGN_ID}"'
    positions: list[tuple[int, int]] = []
    cursor = 0
    while True:
        position = text.find(needle, cursor)
        if position < 0:
            break
        start = text.rfind("{", 0, position)
        require(start >= 0, f"R23D68 lifecycle object start missing: {path}")
        end = matching_brace_end(text, start)
        positions.append((start, end))
        cursor = end
    require(
        len(positions) == expected_lifecycle_count,
        f"authority lifecycle object count changed before update: {path}",
    )
    for start, end in reversed(positions):
        value = json.loads(text[start:end])
        lifecycle_count, current_count = update_authority(value, closure_sha, audit_sha)
        require(lifecycle_count == 1 and current_count == 0, "scoped lifecycle update changed")
        line_start = text.rfind("\n", 0, start) + 1
        leading = text[line_start:start]
        leading_spaces = leading[: len(leading) - len(leading.lstrip(" "))]
        replacement = render_embedded_object(value, leading_spaces)
        text = text[:start] + replacement + text[end:]
    text, current_count = update_current_fields(text)
    require(
        current_count == expected_current_count,
        f"authority current status count changed before update: {path}",
    )
    text, overall_reason_count = update_overall_reason(text)
    require(
        overall_reason_count == expected_overall_reason_count,
        f"authority overall R23D68 reason count changed before update: {path}",
    )
    path.write_text(text, encoding="utf-8")


def materialize() -> None:
    closure = build_closure()
    CLOSURE_PATH.write_text(canonical_json(closure), encoding="utf-8")
    closure_sha = sha256(CLOSURE_PATH)
    audit_sha = sha256(AUDIT_PATH)
    for path, expected_lifecycle, expected_current, expected_overall_reason in (
        (RELEASE_PATH, 1, 1, 1),
        (SUPPORT_PATH, 2, 1, 0),
    ):
        update_authority_file(
            path,
            closure_sha,
            audit_sha,
            expected_lifecycle,
            expected_current,
            expected_overall_reason,
        )
    for path, values in DOC_REPLACEMENTS.items():
        replace_section(path, *values)
    update_architecture()
    verify_live_authorities(closure_sha, audit_sha)
    print(
        "[turning/3e] MATERIALIZED R23D68 immutable physical closure: "
        "cells=9 horizons=9 execution_valid=0 files=66 bytes=182502686 "
        "turning=False QSDK-R23=False score=10/25"
    )


def audit() -> None:
    expected = build_closure()
    require(CLOSURE_PATH.is_file(), "R23D68 closure is missing")
    actual = load_json(CLOSURE_PATH)
    require(actual == expected, "R23D68 closure claim vector changed")
    closure_sha = sha256(CLOSURE_PATH)
    audit_sha = sha256(AUDIT_PATH)
    verify_live_authorities(closure_sha, audit_sha)
    mutations = [
        ("status", "passing"),
        ("attempt.same_identity_rerun_allowed", True),
        ("execution_population.closure_derived_world_build_count", 6),
        ("official_result.q_sdk_r23_satisfied", True),
        ("claims.turning_claimed", True),
    ]
    for dotted, replacement in mutations:
        copy_value = json.loads(json.dumps(actual))
        target = copy_value
        parts = dotted.split(".")
        for part in parts[:-1]:
            target = target[part]
        target[parts[-1]] = replacement
        require(copy_value != expected, f"mutation was accepted: {dotted}")
    print(
        "[turning/3e] PASS R23D68 immutable physical closure: qualification=16/16 "
        "adoption=True authorization=9/9 cells=9 reported_worlds=6 "
        "proved_horizons=9 execution_valid=0 files=66 bytes=182502686 "
        f"mutations={len(mutations)} turning=False QSDK-R23=False score=10/25"
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
