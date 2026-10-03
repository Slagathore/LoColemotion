#!/usr/bin/env python3
"""Materialize and audit the immutable positive R23D78 physical closure.

R23D78 consumed one prospectively authorized nine-cell finite decision at the
fresh held-out seed 23199.  The exact Godot/Jolt, Rapier/Parry, and MuJoCo
populations all completed their 2,992-step horizons, retained full-precision
content-addressed traces, passed every unchanged common physical gate, and
passed the preregistered raw-signed plus reference-conditioned cycle tests.

This closure pins the complete qualification and physical populations, the
clean-pushed source tree and all 227 implementation dependencies, every native
terminal and trace CAS object, and the frozen positive interpretation.  It
does not claim cross-engine equivalence, repeatability, population robustness,
arbitrary morphology, prone-to-standing, physical acceptance, or release.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
from typing import Any, Mapping


REPO_ROOT = Path(__file__).resolve().parents[2]
TURNING_ROOT = REPO_ROOT / "sdk" / "turning"
EVIDENCE_ROOT = REPO_ROOT.parent / "SporeSpore_Evidence"
ARTIFACT_ROOT = EVIDENCE_ROOT / "artifacts" / "sha256"
QUALIFICATION_ROOT = (
    EVIDENCE_ROOT
    / "qsdk-r23d78-qualification-20260826T173203Z-7b876726"
)
PHYSICAL_ROOT = (
    EVIDENCE_ROOT
    / "qsdk-r23d78-physical-20260826T174119Z-7b876726"
)
FIRST_QUALIFICATION_FAILURE_ROOT = (
    EVIDENCE_ROOT
    / "qsdk-r23d78-qualification-20260826T170603Z-0e479979"
)
FIRST_SUCCESSOR_GHOST_FAILURE_ROOT = (
    EVIDENCE_ROOT
    / "r23d78-successor-campaign-gates-testonly-20260826T1725Z"
)
CORRECTED_SUCCESSOR_GHOST_ROOT = (
    EVIDENCE_ROOT
    / "r23d78-successor-campaign-gates-testonly-20260826T1730Z"
)
CLOSURE_PATH = (
    TURNING_ROOT
    / "r23d78_production_route_three_engine_turning_validation_closure_v1.json"
)
IMPLEMENTATION_PATH = (
    "sdk/turning/"
    "r23d78_production_route_three_engine_turning_implementation_v1.json"
)

SOURCE_COMMIT = "7b876726ba1471c6acd228181a877bd18bbb08a3"
SOURCE_TREE = "5a7ee58cff5eee5e2be9ddd7f369351fd5a8561f"
CAMPAIGN_ID = "QSDK-R23D78-FRESH-FINITE-THREE-ENGINE-TURNING-DECISION"
GATE_ID = "QSDK-R23D78"
ATTEMPT_ID = "59f9c4302a5e413285102dd720fd6e2f"
CLASSIFICATION = (
    "valid_complete_positive_exact_seed_23199_three_engine_portable_turning"
)
CLOSED_STATUS = (
    "closed_consumed_valid_complete_positive_exact_seed_23199_"
    "three_engine_portable_turning"
)
PROFILE_ID = "sporespore_qsdk_r23d60_selected_s169_actuator_cap_profile_v1"
ENGINES = ("godot_jolt", "rapier_parry", "mujoco")
ARMS = ("reference_zero", "positive_heading", "negative_heading")
CELL_IDS = [
    f"r23d78__{engine}__s23199__{arm}"
    for engine in ENGINES
    for arm in ARMS
]

EXPECTED_FIRST_QUALIFICATION_FAILURE_POPULATION = {
    "complete_file_population_count": 13,
    "complete_file_population_byte_count": 12653,
    "canonical_population_manifest_byte_length": 1482,
    "canonical_population_manifest_sha256": (
        "sha256:56718b57574cd8137bd1b0c54b11e96c1261b55418ff18dc862bcf680fde7969"
    ),
}
EXPECTED_FIRST_SUCCESSOR_GHOST_FAILURE_POPULATION = {
    "complete_file_population_count": 4,
    "complete_file_population_byte_count": 4355,
    "canonical_population_manifest_byte_length": 444,
    "canonical_population_manifest_sha256": (
        "sha256:19a5054d94fefb57fc0f70ea8fedf0b5aa39db824015646b7b646447382f61db"
    ),
}
EXPECTED_CORRECTED_SUCCESSOR_GHOST_POPULATION = {
    "complete_file_population_count": 13,
    "complete_file_population_byte_count": 112512,
    "canonical_population_manifest_byte_length": 1465,
    "canonical_population_manifest_sha256": (
        "sha256:5f7e91d00692efe430c1284c8a5a444cfa26f33f58693573ce2df67ed37353a2"
    ),
}
EXPECTED_QUALIFICATION_POPULATION = {
    "complete_file_population_count": 50,
    "complete_file_population_byte_count": 505610,
    "canonical_population_manifest_byte_length": 5843,
    "canonical_population_manifest_sha256": (
        "sha256:12cfc80774c1f4e33e3664471560024ec8a7abad588428e18f158b1764b29640"
    ),
}
EXPECTED_PHYSICAL_POPULATION = {
    "complete_file_population_count": 72,
    "complete_file_population_byte_count": 674391547,
    "canonical_population_manifest_byte_length": 10289,
    "canonical_population_manifest_sha256": (
        "sha256:a41c513d89d41665ea90ef609ee0aeb32bdb97bc9ca3be32e29aeda0d4dbbd3f"
    ),
}
EXPECTED_QUALIFICATION_BINDINGS = {
    "attestation.json": (
        157522,
        "2e84b1d341f9aa30910c26256792cc1f8ddcdce1c0cf9f6b3a5a1f24e3fc210e",
    ),
    "adoption.json": (
        3264,
        "b308ad7a8a1e9a28639f4e93826343272a54dbc5a3d7030d9b2555d06fc2727a",
    ),
}
EXPECTED_PHYSICAL_BINDINGS = {
    "attempt-authorization.json": (
        166914,
        "793a7ad7e7e3540d8c74e00f39b22c2ccc0021d44e227f3ecbd149db73cca44e",
    ),
    "authorization-preflight.json": (
        25455,
        "7d80ef876e47ed6843e1521310ad59abe4aaae32cacefb10d47ebb66a1cc3aa0",
    ),
    "physical-freeze.json": (
        335460,
        "32742a55ab02ec8d0d717921be06609790509eefcc7baf1826bd80aebf669267",
    ),
    "terminal-paths.json": (
        1435,
        "6aa9ad27aabe846d0b2d4f2a14b175c6cd9beaa9de42dc7e10b6558e57954b40",
    ),
    "complete-evaluation.json": (
        19368,
        "8af1cd796b5ec934cfa6248a89e99f302e6b97e2f4b5c75e0c8899111a7834e6",
    ),
    "report.json": (
        55213,
        "b5623428112833e1707f957dd858488594168a4ee0508c3af1b462a8b19cf2f3",
    ),
    "completion.json": (
        2928,
        "b380b173e9d574b3af0bb70c4e0c5d72e40098e8a2ff6912efb79732c77961be",
    ),
}
EXPECTED_ENGINE_MEASUREMENTS = {
    "godot_jolt": {
        "positive_reference_conditioned_cycle_shift_rad": 0.21771034587650862,
        "negative_reference_conditioned_cycle_shift_rad": 0.15143261911316452,
        "bilateral_reference_conditioned_cycle_separation_rad": 0.36914296498967314,
        "every_terminal_swing_raw_direction": False,
        "every_terminal_swing_reference_conditioned_direction": False,
    },
    "rapier_parry": {
        "positive_reference_conditioned_cycle_shift_rad": 0.015370547127428105,
        "negative_reference_conditioned_cycle_shift_rad": 0.02846469314771735,
        "bilateral_reference_conditioned_cycle_separation_rad": 0.04383524027514546,
        "every_terminal_swing_raw_direction": True,
        "every_terminal_swing_reference_conditioned_direction": True,
    },
    "mujoco": {
        "positive_reference_conditioned_cycle_shift_rad": 0.13323493019355534,
        "negative_reference_conditioned_cycle_shift_rad": 0.1485493879001832,
        "bilateral_reference_conditioned_cycle_separation_rad": 0.28178431809373855,
        "every_terminal_swing_raw_direction": True,
        "every_terminal_swing_reference_conditioned_direction": True,
    },
}

sys.path.insert(0, str(TURNING_ROOT))
from r23d77_windows_cas_file_identity import (  # noqa: E402
    expected_cas_paths,
    same_existing_file,
)


class ClosureError(RuntimeError):
    """Fail-closed R23D78 closure error."""


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
        lines.append(f"{relative}\t{size}\tsha256:{sha256_file(path)}\n")
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


def source_binding(relative: str, expected_sha256: str) -> dict[str, Any]:
    raw = git("show", f"{SOURCE_COMMIT}:{relative}", binary=True)
    require(isinstance(raw, bytes), f"SOURCE_BYTES_INVALID:{relative}")
    actual = "sha256:" + sha256_bytes(raw)
    require(actual == expected_sha256, f"SOURCE_DIGEST_DRIFT:{relative}")
    object_id = git("rev-parse", f"{SOURCE_COMMIT}:{relative}")
    require(isinstance(object_id, str), f"SOURCE_OBJECT_INVALID:{relative}")
    return {
        "path": relative,
        "git_blob_oid": object_id,
        "byte_length": len(raw),
        "raw_sha256": actual,
    }


def verify_source() -> tuple[list[dict[str, Any]], dict[str, Any]]:
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

    raw = git("show", f"{SOURCE_COMMIT}:{IMPLEMENTATION_PATH}", binary=True)
    require(isinstance(raw, bytes), "IMPLEMENTATION_SOURCE_BYTES_INVALID")
    implementation = json.loads(raw.decode("utf-8"))
    require(isinstance(implementation, dict), "IMPLEMENTATION_SOURCE_INVALID")
    dependencies = implementation.get("dependency_digests")
    require(
        isinstance(dependencies, dict)
        and len(dependencies) == 227
        and implementation.get("campaign_id") == CAMPAIGN_ID
        and implementation.get("gate_id") == GATE_ID
        and implementation.get("ordered_cell_ids") == CELL_IDS
        and implementation.get("complete_zero_world_gate", {}).get("passed") is True
        and implementation.get("physical_execution_authorized") is False,
        "IMPLEMENTATION_SOURCE_PROJECTION_INVALID",
    )
    bindings = [
        source_binding(relative, str(dependencies[relative]))
        for relative in sorted(dependencies)
    ]
    return bindings, implementation


def verify_retained_history() -> dict[str, Any]:
    expected_roots = (
        (
            FIRST_QUALIFICATION_FAILURE_ROOT,
            EXPECTED_FIRST_QUALIFICATION_FAILURE_POPULATION,
            "failure.json",
            (614, "7af1a52dc8a87ef5cce0011226fd864c5b5adf0fcb13f490f755484c32e42153"),
        ),
        (
            FIRST_SUCCESSOR_GHOST_FAILURE_ROOT,
            EXPECTED_FIRST_SUCCESSOR_GHOST_FAILURE_POPULATION,
            "failure.json",
            (616, "bfa100397caad4cf8ebc8b8b70f86e0ab0a7b9a588ef03e56318b90d3f2c670c"),
        ),
        (
            CORRECTED_SUCCESSOR_GHOST_ROOT,
            EXPECTED_CORRECTED_SUCCESSOR_GHOST_POPULATION,
            "attestation.json",
            (94574, "4f0c820de99a8acaed3dabe2dd1ecc7c1ea7ecb3f1deb1258e7f2ec13c505866"),
        ),
    )
    retained: list[dict[str, Any]] = []
    for root, expected_population, selected_name, selected_expected in expected_roots:
        require(root.is_dir(), f"HISTORY_ROOT_MISSING:{root}")
        require(
            population_identity(root) == expected_population,
            f"HISTORY_POPULATION_DRIFT:{root.name}",
        )
        verify_file(root / selected_name, selected_expected)
        retained.append(
            {
                "root": root.resolve().as_posix(),
                "population_identity": expected_population,
                "selected_artifact": file_binding(root / selected_name),
            }
        )

    first_failure = load_json(FIRST_QUALIFICATION_FAILURE_ROOT / "failure.json")
    ghost_failure = load_json(FIRST_SUCCESSOR_GHOST_FAILURE_ROOT / "failure.json")
    corrected = load_json(CORRECTED_SUCCESSOR_GHOST_ROOT / "attestation.json")
    require(
        first_failure.get("campaign_id") == CAMPAIGN_ID
        and first_failure.get("source_commit")
        == "0e47997990617ee5582b6ebacd552ad4a29378af"
        and first_failure.get("campaign_local_qualification_passed") is False
        and first_failure.get("physical_launch_prerequisite_satisfied") is False
        and ghost_failure.get("campaign_id") == CAMPAIGN_ID
        and ghost_failure.get("campaign_local_qualification_passed") is False
        and ghost_failure.get("physical_launch_prerequisite_satisfied") is False
        and corrected.get("campaign_id") == CAMPAIGN_ID
        and corrected.get("test_only") is True
        and corrected.get("executed_gate_count") == 4
        and corrected.get("all_gates_executed") is True
        and corrected.get("commissioned") is False
        and corrected.get("claims", {}).get("physical_campaign_executed") is False,
        "RETAINED_QUALIFICATION_HISTORY_INVALID",
    )
    return {
        "first_clean_pushed_qualification_failed_closed": retained[0],
        "first_corrected_successor_ghost_failed_closed": retained[1],
        "corrected_successor_four_gate_ghost_passed": retained[2],
        "historical_result_reinterpreted": False,
        "physical_world_count": 0,
    }


def verify_qualification() -> dict[str, Any]:
    require(QUALIFICATION_ROOT.is_dir(), "QUALIFICATION_ROOT_MISSING")
    require(
        population_identity(QUALIFICATION_ROOT) == EXPECTED_QUALIFICATION_POPULATION,
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
        and attestation.get("lineage_gate_count") == 1
        and attestation.get("campaign_gate_count") == 3
        and attestation.get("executed_gate_count") == 16
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
        and adoption.get("executed_gate_count") == 16
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
        "lineage_gate_count": 1,
        "campaign_role_gate_count": 3,
        "executed_gate_count": 16,
        "campaign_local_qualification_passed": True,
        "physical_launch_prerequisite_satisfied": True,
        "qualification_world_count": 0,
        "physical_acceptance_authority": False,
    }


def verify_trace_artifact(terminal: Mapping[str, Any]) -> dict[str, Any]:
    artifact = terminal.get("trace_artifact")
    require(isinstance(artifact, Mapping), "TRACE_ARTIFACT_INVALID")
    expected = expected_cas_paths(terminal, authority_repo_root=REPO_ROOT)
    require(expected is not None, "TRACE_EXPECTED_PATHS_INVALID")
    expected_payload, expected_manifest = expected
    recorded_payload = Path(str(artifact.get("payload_path", "")))
    recorded_manifest = Path(str(artifact.get("manifest_path", "")))
    require(
        same_existing_file(recorded_payload, expected_payload)
        and same_existing_file(recorded_manifest, expected_manifest),
        "TRACE_EXISTING_FILE_IDENTITY_INVALID",
    )
    digest = str(artifact.get("sha256", ""))
    digest_hex = digest.removeprefix("sha256:")
    raw = expected_payload.read_bytes()
    manifest = load_json(expected_manifest)
    require(
        len(digest_hex) == 64
        and "sha256:" + sha256_bytes(raw) == digest
        and len(raw) == artifact.get("byte_length")
        and manifest.get("schema_version")
        == "sporespore_content_addressed_artifact_manifest_v1"
        and manifest.get("algorithm") == "sha256"
        and manifest.get("sha256") == digest
        and manifest.get("byte_length") == len(raw)
        and manifest.get("payload_name") == "payload.bin"
        and manifest.get("media_type") == "application/x-ndjson",
        "TRACE_CAS_BYTES_INVALID",
    )
    return {
        "receipt": dict(artifact),
        "payload": file_binding(expected_payload),
        "manifest": file_binding(expected_manifest),
        "recorded_and_expected_existing_file_identity_equal": True,
        "recorded_and_expected_bytes_identical": True,
    }


def verify_engine_result(engine: str, result: Mapping[str, Any]) -> dict[str, Any]:
    measurement = result.get("cycle_integrated_measurement")
    expected = EXPECTED_ENGINE_MEASUREMENTS[engine]
    require(isinstance(measurement, Mapping), f"MEASUREMENT_MISSING:{engine}")
    diagnostics = measurement.get("nonselecting_diagnostics")
    require(
        result.get("passed") is True
        and result.get("all_common_physical_gates_passed") is True
        and result.get("all_three_cells_execution_valid") is True
        and result.get("measurement_failure_codes") == []
        and measurement.get("passed") is True
        and measurement.get("gates", {}).get("raw_signed_cycle_shift") is True
        and measurement.get("gates", {}).get("reference_conditioned_cycle_shift")
        is True
        and measurement.get("measurement_configuration", {}).get(
            "minimum_cycle_shift_rad"
        )
        == 0.01
        and measurement.get("positive_reference_conditioned_cycle_shift_rad")
        == expected["positive_reference_conditioned_cycle_shift_rad"]
        and measurement.get("negative_reference_conditioned_cycle_shift_rad")
        == expected["negative_reference_conditioned_cycle_shift_rad"]
        and measurement.get("bilateral_reference_conditioned_cycle_separation_rad")
        == expected["bilateral_reference_conditioned_cycle_separation_rad"]
        and isinstance(diagnostics, Mapping)
        and diagnostics.get("every_terminal_swing_raw_direction")
        is expected["every_terminal_swing_raw_direction"]
        and diagnostics.get("every_terminal_swing_reference_conditioned_direction")
        is expected["every_terminal_swing_reference_conditioned_direction"],
        f"ENGINE_RESULT_PROJECTION_CHANGED:{engine}",
    )
    return {
        "passed": True,
        "all_common_physical_gates_passed": True,
        "all_three_cells_execution_valid": True,
        "minimum_raw_signed_cycle_shift_rad": 0.01,
        "minimum_reference_conditioned_cycle_shift_rad": 0.01,
        **expected,
        "nonselecting_diagnostics_are_not_selection_gates": True,
    }


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
        attempt.get("schema_version") == "sporespore_qsdk_r23d78_physical_attempt_v1"
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
        and freeze.get("all_cells_run_regardless_of_intermediate_outcome") is True
        and freeze.get("posthoc_threshold_or_selector_change_performed") is False,
        "PHYSICAL_FREEZE_INVALID",
    )

    claims = evaluation.get("claims", {})
    finite = evaluation.get("finite_decision", {})
    require(
        evaluation.get("classification") == CLASSIFICATION
        and evaluation.get("cell_count") == 9
        and evaluation.get("fresh_held_out_seed_consumed") is True
        and evaluation.get("fresh_held_out_seed_count") == 1
        and evaluation.get("turning_gate_invoked") is True
        and evaluation.get("cross_engine_equivalence_test_invoked") is False
        and evaluation.get("population_inference_attempted") is False
        and evaluation.get("posthoc_threshold_or_selector_change_performed") is False
        and finite.get("matrix_execution_valid") is True
        and finite.get("strict_nine_cell_conjunction_used") is True
        and finite.get("all_nine_common_physical_gates_passed") is True
        and finite.get("finite_three_engine_turning_positive") is True
        and finite.get("equivalence_or_non_inferiority_test_invoked") is False
        and finite.get("superiority_test_invoked") is False
        and finite.get("population_inference_attempted") is False
        and claims.get("r23d78_finite_three_engine_turning") is True
        and claims.get("finite_three_engine_turning") is True
        and claims.get("portable_basic_turning") is True
        and claims.get("q_sdk_r23_satisfied") is True
        and claims.get("cross_engine_equivalence") is False
        and claims.get("arbitrary_quadruped_coverage") is False
        and claims.get("population_robustness") is False
        and claims.get("prone_to_standing") is False
        and claims.get("physical_acceptance_authority") is False
        and claims.get("release_authorized") is False,
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
        and completion.get("finite_three_engine_turning_positive") is True
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
    trace_byte_count = 0
    for engine in ENGINES:
        for arm in ARMS:
            cell_id = f"r23d78__{engine}__s23199__{arm}"
            terminal_path = PHYSICAL_ROOT / "cells" / cell_id / "terminal.json"
            terminal = load_json(terminal_path)
            require(
                terminal.get("schema_version")
                == "sporespore_qsdk_r23d78_engine_cell_report_v1"
                and terminal.get("campaign_id") == CAMPAIGN_ID
                and terminal.get("cell_id") == cell_id
                and terminal.get("engine_id") == engine
                and terminal.get("arm_id") == arm
                and terminal.get("source_commit") == SOURCE_COMMIT
                and terminal.get("profile_id") == PROFILE_ID
                and terminal.get("execution", {}).get("world_attempt_count") == 1
                and terminal.get("execution", {}).get("world_build_count") == 1
                and terminal.get("execution", {}).get(
                    "controller_semantic_step_count"
                )
                == 2992
                and terminal.get("execution", {}).get("integrity_passed") is True
                and terminal.get("trace_summary", {}).get("row_count") == 2992
                and terminal.get("measurements", {}).get(
                    "torso_ground_contact_step_count"
                )
                == 0
                and terminal.get("physical_acceptance_authority") is False,
                f"TERMINAL_INVALID:{cell_id}",
            )
            trace = verify_trace_artifact(terminal)
            trace_byte_count += int(trace["payload"]["byte_length"])
            cell_evaluation = evaluations.get(cell_id)
            require(
                isinstance(cell_evaluation, dict)
                and cell_evaluation.get("execution_valid") is True
                and cell_evaluation.get("common_physical_gate_passed") is True
                and cell_evaluation.get("failed_gate_ids") == [],
                f"CELL_EVALUATION_INVALID:{cell_id}",
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
                    "torso_ground_contact_step_count": 0,
                    "trace_artifact": trace,
                    "official_execution_valid": True,
                    "official_common_physical_gate_passed": True,
                    "official_failed_gate_ids": [],
                }
            )

    engine_results = finite.get("engine_results")
    require(isinstance(engine_results, dict), "ENGINE_RESULTS_INVALID")
    projected_engine_results = {
        engine: verify_engine_result(engine, engine_results[engine])
        for engine in ENGINES
    }
    return {
        "root": PHYSICAL_ROOT.resolve().as_posix(),
        "population_identity": EXPECTED_PHYSICAL_POPULATION,
        "selected_artifacts": {
            relative: file_binding(PHYSICAL_ROOT / relative)
            for relative in EXPECTED_PHYSICAL_BINDINGS
        },
        "attempt_id": ATTEMPT_ID,
        "campaign_seed": 23199,
        "authorization_preflight_count": 9,
        "authorization_preflight_pass_count": 9,
        "world_attempt_count": 9,
        "world_build_count": 9,
        "complete_native_horizon_count": 9,
        "retained_trace_count": 9,
        "retained_trace_row_count": 26928,
        "retained_trace_payload_byte_count": trace_byte_count,
        "retained_cells": retained_cells,
        "engine_results": projected_engine_results,
    }


def materialize() -> dict[str, Any]:
    source_bindings, implementation = verify_source()
    history = verify_retained_history()
    qualification = verify_qualification()
    physical = verify_physical()
    return {
        "schema_version": (
            "sporespore_qsdk_r23d78_production_route_three_engine_"
            "turning_validation_closure_v1"
        ),
        "closure_id": (
            "QSDK-R23D78-PRODUCTION-ROUTE-THREE-ENGINE-"
            "TURNING-VALIDATION-CLOSURE-V1"
        ),
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "release_gate_id": "QSDK-R23",
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
            "implementation_dependency_count": len(source_bindings),
            "complete_implementation_dependency_git_blob_bindings": source_bindings,
            "implementation_contract_projection": {
                "campaign_id": implementation["campaign_id"],
                "gate_id": implementation["gate_id"],
                "ordered_cell_ids": implementation["ordered_cell_ids"],
                "complete_zero_world_gate_passed": True,
            },
        },
        "retained_prephysical_history": history,
        "qualification_and_adoption": qualification,
        "retained_physical_attempt": physical,
        "official_result": {
            "classification": CLASSIFICATION,
            "complete_finite_evaluator_completed": True,
            "matrix_execution_valid": True,
            "finite_three_engine_turning_positive": True,
            "valid_three_engine_turning_result_available": True,
            "portable_basic_turning": True,
            "q_sdk_r23_satisfied": True,
            "fresh_held_out_seed_consumed": True,
            "campaign_identity_consumed": True,
            "same_identity_rerun_allowed": False,
            "replacement_or_selective_rerun_allowed": False,
            "historical_result_reinterpreted": False,
            "posthoc_threshold_selector_evaluator_or_result_change_count": 0,
            "cross_engine_equivalence_test_invoked": False,
            "superiority_test_invoked": False,
            "population_inference_attempted": False,
            "release_score_before": "10/25",
            "release_score_after": "11/25",
        },
        "adequacy_and_claim_boundary": {
            "decision_population": "exact_seed_23199_three_engines_by_three_arms",
            "strict_nine_cell_conjunction_used": True,
            "declared_cell_count": 9,
            "observed_cell_count": 9,
            "minimum_raw_signed_cycle_shift_rad": 0.01,
            "minimum_reference_conditioned_cycle_shift_rad": 0.01,
            "threshold_provenance": (
                "prospectively inherited unchanged from the R23D76 finite decision"
            ),
            "cohort_adequacy": (
                "complete declared finite population; no sampling or pass-rate estimate"
            ),
            "formal_cross_engine_equivalence_established": False,
            "repeatability_established": False,
            "population_robustness_established": False,
            "arbitrary_morphology_established": False,
        },
        "next_work": {
            "preserve_r23d78_unchanged": True,
            "same_seed_or_same_campaign_rerun_allowed": False,
            "q_sdk_r23_closure_complete": True,
            "sdk1_cross_engine_equivalence_required": False,
            "canonical_prone_to_standing_remains_open": True,
            "overall_release_still_blocked": True,
        },
        "closure_materializer_path": (
            "sdk/turning/materialize_r23d78_physical_closure.py"
        ),
        "closure_audit_path": "tests/test_qsdk_r23d78_physical_closure.ps1",
        "claims": {
            "campaign_closed": True,
            "retained_physical_population_exact": True,
            "campaign_identity_consumed": True,
            "complete_nine_cell_native_population_observed": True,
            "nine_complete_native_horizons_observed": True,
            "nine_complete_traces_retained": True,
            "godot_jolt_frozen_turning_gates_passed": True,
            "rapier_parry_frozen_turning_gates_passed": True,
            "mujoco_frozen_turning_gates_passed": True,
            "historical_result_reinterpreted": False,
            "finite_three_engine_turning": True,
            "portable_basic_turning": True,
            "q_sdk_r23_satisfied": True,
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
        "QSDK_R23D78_PHYSICAL_CLOSURE "
        + json.dumps(
            {
                "passed": True,
                "check_only": args.check,
                "status": CLOSED_STATUS,
                "attempt_id": ATTEMPT_ID,
                "qualification_gates": 16,
                "authorization_receipts": 9,
                "worlds": 9,
                "complete_horizons": 9,
                "retained_trace_rows": 26928,
                "engine_turning_pass_count": 3,
                "finite_three_engine_turning": True,
                "q_sdk_r23_satisfied": True,
                "release_score": "11/25",
                "cross_engine_equivalence": False,
                "physical_acceptance_authority": False,
                "release_authority": False,
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
            f"QSDK_R23D78_PHYSICAL_CLOSURE {type(error).__name__}:{error}"
        ) from error
