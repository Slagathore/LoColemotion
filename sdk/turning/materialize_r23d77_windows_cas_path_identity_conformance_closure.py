"""Materialize the immutable R23D77 retained-receipt conformance closure."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
from typing import Any, Mapping, Sequence


ROOT = Path(__file__).resolve().parent
REPO_ROOT = ROOT.parent.parent
CLOSURE_PATH = ROOT / "r23d77_windows_cas_path_identity_conformance_closure_v1.json"
RESULT_PATH = Path(
    "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/turning/"
    "r23d77-windows-cas-path-identity/20260826T155706Z-a18e9eec/result.json"
)
SOURCE_COMMIT = "a18e9eec539b396380a9697742f97ae55c264d8d"
SOURCE_TREE = "e69299cd0add345cab23f52cb9f60723707a07cb"
RESULT_SHA256 = "sha256:5abeb8adc4903a45e5a757838113bc121411bb917b3bfb48b5f4252820211277"
RESULT_BYTE_LENGTH = 7995
R23D76_CLOSURE_SHA256 = (
    "sha256:349883f5ff7c4a072c1a5d9ff4253e2aa033223c53540238022f1f550e93af5b"
)
R23D76_CLASSIFICATION = (
    "invalid_or_incomplete_exact_seed_23197_three_engine_portable_turning"
)
PATH_FAILURE = "R23D65_TRACE_ARTIFACT_CAS_PATH"
FILE_IDENTITY_FAILURE = "R23D77_TRACE_ARTIFACT_CAS_FILE_IDENTITY"
NEGATIVE_CONTROL_IDS = (
    "missing_manifest",
    "missing_payload",
    "wrong_manifest",
    "wrong_payload",
)
SOURCE_PATHS = (
    "sdk/turning/r23d77_windows_cas_file_identity.py",
    "sdk/turning/r23d77_windows_cas_path_identity_conformance.py",
    "sdk/turning/r23d77_windows_cas_path_identity_conformance_v1.json",
    "sdk/turning/r23d77_first_focused_check_failure_v1.json",
    "sdk/turning/r23d50_rapier_cas_path_identity_replay_evaluator.py",
    "sdk/turning/r23d50_rapier_cas_path_identity_replay_closure_v1.json",
    "sdk/turning/r23d76_production_route_three_engine_turning_validation_closure_v1.json",
    "sdk/turning/r23d65_selected_profile_three_engine_turning_validation_evaluator.py",
)
EXPECTED_CELLS = (
    {
        "cell_id": "r23d76__rapier_parry__s23197__reference_zero",
        "arm_id": "reference_zero",
        "terminal_raw_sha256": (
            "sha256:06df83240cff692c5703f57555e3f7acde19e300b217b5c8c515f3181cd114d1"
        ),
        "trace_sha256": (
            "sha256:56d7b1b0633d54c26c28e17a74eac89959ad29aca9a7c181d9ec4a9ed2584047"
        ),
        "trace_byte_length": 44563955,
    },
    {
        "cell_id": "r23d76__rapier_parry__s23197__positive_heading",
        "arm_id": "positive_heading",
        "terminal_raw_sha256": (
            "sha256:b53c50dea54002fa20c7c9978ac86974652bbd62a1b8485af31863ac15dce4f4"
        ),
        "trace_sha256": (
            "sha256:d0f757471603bc832f2d93b50724b19cb8d3df6935cc9b254454bf6b5b301b7c"
        ),
        "trace_byte_length": 44532384,
    },
    {
        "cell_id": "r23d76__rapier_parry__s23197__negative_heading",
        "arm_id": "negative_heading",
        "terminal_raw_sha256": (
            "sha256:1438bd91b77058b07359e8800053d0edb33b4278b64e3268aa4a8dace611d6ba"
        ),
        "trace_sha256": (
            "sha256:edbcef7e901ebdcc6291091dd208abd3d5792fe1124816a0f9a32dd8a4e73875"
        ),
        "trace_byte_length": 44535105,
    },
)


class R23D77ClosureError(RuntimeError):
    """The retained result or closure input is invalid."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise R23D77ClosureError(code)


def raw_sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def _git_bytes(specification: str) -> bytes:
    process = subprocess.run(
        ["git", "-C", os.fspath(REPO_ROOT), "show", specification],
        check=False,
        capture_output=True,
    )
    if process.returncode != 0:
        raise R23D77ClosureError(
            "GIT_SHOW_FAILED:" + specification + ":" + process.stderr.decode(
                "utf-8", errors="replace"
            ).strip()
        )
    return process.stdout


def _git_text(*arguments: str) -> str:
    process = subprocess.run(
        ["git", "-C", os.fspath(REPO_ROOT), *arguments],
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if process.returncode != 0:
        raise R23D77ClosureError(
            "GIT_FAILED:" + " ".join(arguments) + ":" + process.stderr.strip()
        )
    return process.stdout.strip()


def _source_binding(relative_path: str) -> dict[str, Any]:
    raw = _git_bytes(f"{SOURCE_COMMIT}:{relative_path}")
    return {
        "path": relative_path,
        "git_blob_oid": _git_text("rev-parse", f"{SOURCE_COMMIT}:{relative_path}"),
        "byte_length": len(raw),
        "raw_sha256": "sha256:" + hashlib.sha256(raw).hexdigest(),
    }


def _load_result() -> dict[str, Any]:
    _require(RESULT_PATH.is_file(), "RESULT_MISSING")
    _require(RESULT_PATH.stat().st_size == RESULT_BYTE_LENGTH, "RESULT_BYTES")
    _require(raw_sha256(RESULT_PATH) == RESULT_SHA256, "RESULT_SHA256")
    try:
        result = json.loads(RESULT_PATH.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise R23D77ClosureError(f"RESULT_UNREADABLE:{type(error).__name__}") from error
    _require(isinstance(result, dict), "RESULT_ROOT")
    _validate_result(result)
    return result


def _validate_result(result: Mapping[str, Any]) -> None:
    _require(
        result.get("schema_version")
        == "sporespore_qsdk_r23d77_windows_cas_path_identity_result_v1",
        "RESULT_SCHEMA",
    )
    _require(
        result.get("status")
        == "passed_complete_zero_world_retained_receipt_conformance",
        "RESULT_STATUS",
    )
    _require(result.get("question_class") == "development", "QUESTION_CLASS")
    source = result.get("source_authority")
    _require(isinstance(source, Mapping), "SOURCE_AUTHORITY")
    _require(source.get("source_commit") == SOURCE_COMMIT, "SOURCE_COMMIT")
    _require(source.get("origin_main") == SOURCE_COMMIT, "SOURCE_ORIGIN_MAIN")
    _require(source.get("clean") is True, "SOURCE_CLEAN")
    _require(source.get("live_remote_equal") is True, "SOURCE_REMOTE_EQUAL")
    retained = result.get("retained_r23d76")
    _require(isinstance(retained, Mapping), "R23D76_LINEAGE")
    _require(retained.get("closure_raw_sha256") == R23D76_CLOSURE_SHA256, "R23D76_SHA")
    _require(
        retained.get("official_classification_preserved") == R23D76_CLASSIFICATION,
        "R23D76_CLASSIFICATION",
    )
    _require(retained.get("historical_result_reinterpreted") is False, "R23D76_REWRITE")
    _require(retained.get("campaign_identity_consumed") is True, "R23D76_CONSUMED")
    expected_counts = {
        "complete_rapier_receipt_population_count": 3,
        "extended_receipt_acceptance_count": 3,
        "ordinary_receipt_acceptance_count": 3,
        "negative_control_count": 12,
        "negative_control_rejection_count": 12,
        "complete_frozen_byte_verifier_replay_count": 6,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "behavior_measurement_invocation_count": 0,
    }
    for field, expected in expected_counts.items():
        _require(result.get(field) == expected, f"RESULT_COUNT:{field}")
    _require(result.get("r23d76_reclassified") is False, "R23D76_RECLASSIFIED")
    _require(result.get("finite_turning_evidence_created") is False, "TURNING_EVIDENCE")
    _require(result.get("physical_acceptance_authority") is False, "PHYSICAL_AUTHORITY")
    _require(result.get("release_authority") is False, "RELEASE_AUTHORITY")
    cells = result.get("cell_results")
    _require(isinstance(cells, list) and len(cells) == 3, "CELL_COUNT")
    for cell, expected in zip(cells, EXPECTED_CELLS, strict=True):
        _require(isinstance(cell, Mapping), "CELL_TYPE")
        for field, expected_value in expected.items():
            _require(cell.get(field) == expected_value, f"CELL_FIELD:{field}")
        _require(cell.get("frozen_failure_codes") == [PATH_FAILURE], "FROZEN_FAILURE")
        _require(cell.get("successor_failure_codes") == [], "SUCCESSOR_FAILURE")
        _require(cell.get("ordinary_spelling_failure_codes") == [], "ORDINARY_FAILURE")
        _require(cell.get("payload_same_existing_file") is True, "PAYLOAD_IDENTITY")
        _require(cell.get("manifest_same_existing_file") is True, "MANIFEST_IDENTITY")
        _require(
            cell.get("complete_frozen_byte_verifier_replayed") is True,
            "FROZEN_REPLAY",
        )
        _require(cell.get("behavior_measurement_invoked") is False, "BEHAVIOR_INVOKED")
        _require(
            str(cell.get("recorded_payload_path", "")).startswith("\\\\?\\"),
            "RECORDED_PAYLOAD_NAMESPACE",
        )
        _require(
            str(cell.get("recorded_manifest_path", "")).startswith("\\\\?\\"),
            "RECORDED_MANIFEST_NAMESPACE",
        )
        _require(
            cell.get("recorded_payload_path") != cell.get("expected_payload_path"),
            "PAYLOAD_TEXT_COLLAPSED",
        )
        _require(
            cell.get("recorded_manifest_path") != cell.get("expected_manifest_path"),
            "MANIFEST_TEXT_COLLAPSED",
        )
        controls = cell.get("negative_controls")
        _require(isinstance(controls, Mapping), "NEGATIVE_CONTROLS")
        _require(tuple(sorted(controls)) == NEGATIVE_CONTROL_IDS, "NEGATIVE_CONTROL_IDS")
        _require(
            all(controls[key] == [FILE_IDENTITY_FAILURE] for key in controls),
            "NEGATIVE_CONTROL_FAILURE",
        )


def build_closure() -> dict[str, Any]:
    result = _load_result()
    _require(
        _git_text("rev-parse", f"{SOURCE_COMMIT}^{{tree}}") == SOURCE_TREE,
        "SOURCE_TREE",
    )
    bindings = [_source_binding(path) for path in SOURCE_PATHS]
    cells = [
        {
            "cell_id": cell["cell_id"],
            "arm_id": cell["arm_id"],
            "terminal_raw_sha256": cell["terminal_raw_sha256"],
            "trace_sha256": cell["trace_sha256"],
            "trace_byte_length": cell["trace_byte_length"],
            "recorded_payload_path": cell["recorded_payload_path"],
            "expected_payload_path": cell["expected_payload_path"],
            "recorded_manifest_path": cell["recorded_manifest_path"],
            "expected_manifest_path": cell["expected_manifest_path"],
            "frozen_failure_codes": cell["frozen_failure_codes"],
            "successor_failure_codes": cell["successor_failure_codes"],
            "ordinary_spelling_failure_codes": cell["ordinary_spelling_failure_codes"],
            "payload_same_existing_file": cell["payload_same_existing_file"],
            "manifest_same_existing_file": cell["manifest_same_existing_file"],
            "negative_controls": cell["negative_controls"],
            "complete_frozen_byte_verifier_replayed": cell[
                "complete_frozen_byte_verifier_replayed"
            ],
            "behavior_measurement_invoked": cell["behavior_measurement_invoked"],
        }
        for cell in result["cell_results"]
    ]
    return {
        "schema_version": (
            "sporespore_qsdk_r23d77_windows_cas_path_identity_conformance_closure_v1"
        ),
        "closure_id": "QSDK-R23D77-WINDOWS-CAS-PATH-IDENTITY-CLOSURE-V1",
        "status": "closed_positive_complete_zero_world_retained_receipt_conformance",
        "question_class": "development",
        "source_authority": {
            "source_commit": SOURCE_COMMIT,
            "source_tree_git_oid": SOURCE_TREE,
            "branch": "main",
            "origin_url": "https://github.com/Slagathore/sporespore.git",
            "source_was_clean_pushed_and_live_equal": True,
            "source_bindings": bindings,
        },
        "retained_result": {
            "root": RESULT_PATH.parent.as_posix(),
            "result": {
                "path": RESULT_PATH.as_posix(),
                "byte_length": RESULT_BYTE_LENGTH,
                "raw_sha256": RESULT_SHA256,
            },
            "complete_file_population_count": 1,
            "complete_file_population_byte_count": RESULT_BYTE_LENGTH,
        },
        "immutable_lineage": {
            "r23d50_existing_file_identity_positive_preserved": True,
            "r23d76_closure_raw_sha256": R23D76_CLOSURE_SHA256,
            "r23d76_official_classification_preserved": R23D76_CLASSIFICATION,
            "r23d76_historical_result_reinterpreted": False,
            "r23d76_campaign_and_seed_consumed": True,
            "r23d76_same_identity_or_selective_rerun_allowed": False,
            "first_r23d77_pre_receipt_failure_preserved": True,
            "first_r23d77_failure_source_commit": (
                "d40fd27b100aaf1e35502ce660bde22b6d3f54bf"
            ),
            "first_r23d77_failure_code": "R23D76_STATUS",
        },
        "adequacy": {
            "affected_engine": "rapier_parry",
            "complete_affected_receipt_population_count": 3,
            "observed_receipt_population_count": 3,
            "sampling_used": False,
            "population_inference_attempted": False,
            "threshold": (
                "Both recorded CAS paths must identify the exact expected existing "
                "files and the complete frozen byte verifier must return no failure."
            ),
            "threshold_provenance": (
                "The prospectively positive R23D50 closure established os.path.samefile "
                "for this same Windows namespace distinction."
            ),
            "equivalence_margin": None,
            "non_inferiority_margin": None,
        },
        "observed_conformance": {
            "complete_rapier_receipt_population_count": 3,
            "extended_receipt_acceptance_count": 3,
            "ordinary_receipt_acceptance_count": 3,
            "complete_frozen_byte_verifier_replay_count": 6,
            "negative_control_count": 12,
            "negative_control_rejection_count": 12,
            "trace_payload_byte_count_reverified": sum(
                cell["trace_byte_length"] for cell in result["cell_results"]
            ),
            "cells": cells,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "behavior_measurement_invocation_count": 0,
        },
        "interpretation": {
            "windows_cas_existing_file_identity_seam_closed_for_future_successors": True,
            "exact_retained_rapier_receipts_conform_under_successor_semantics": True,
            "development_only": True,
            "finite_turning_evidence_created": False,
            "r23d76_reclassified": False,
            "rapier_behavior_measurement_computed": False,
            "fresh_finite_decision_still_required": True,
            "full_seeded_ghost_required_before_that_decision": False,
            "release_score_before": "10/25",
            "release_score_after": "10/25",
        },
        "claims": {
            "r23d77_path_identity_seam_closed": True,
            "r23d76_reclassified": False,
            "rapier_turning": False,
            "finite_three_engine_turning": False,
            "portable_basic_turning": False,
            "q_sdk_r23_satisfied": False,
            "cross_engine_equivalence": False,
            "population_robustness": False,
            "prone_to_standing": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        "next_work": {
            "fresh_finite_decision_required": True,
            "fresh_campaign_identity_and_seed_required": True,
            "r23d77_semantics_must_be_bound_into_successor_evaluator": True,
            "complete_zero_world_gate_required": True,
            "clean_pushed_qualification_and_separate_adoption_required": True,
            "full_seeded_ghost_required": False,
            "same_r23d76_seed_or_attempt_reuse_allowed": False,
        },
        "closure_materializer_path": (
            "sdk/turning/"
            "materialize_r23d77_windows_cas_path_identity_conformance_closure.py"
        ),
        "closure_audit_path": (
            "sdk/audit_r23d77_windows_cas_path_identity_conformance_closure.py"
        ),
    }


def _arguments(argv: Sequence[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("render")
    commands.add_parser("check")
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    arguments = _arguments(argv)
    try:
        expected = build_closure()
        if arguments.command == "render":
            print(json.dumps(expected, allow_nan=False, indent=2, sort_keys=True))
        else:
            actual = json.loads(CLOSURE_PATH.read_text(encoding="utf-8"))
            _require(actual == expected, "CLOSURE_MATERIALIZATION_DRIFT")
            print(
                "QSDK_R23D77_CLOSURE_MATERIALIZATION_PASS "
                "receipts=3 negatives=12 worlds=0"
            )
        return 0
    except (OSError, UnicodeError, json.JSONDecodeError, R23D77ClosureError) as error:
        print(f"QSDK_R23D77_CLOSURE_MATERIALIZATION_FAIL {error}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
