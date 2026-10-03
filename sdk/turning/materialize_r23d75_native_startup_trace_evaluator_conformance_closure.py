#!/usr/bin/env python3
"""Reconstruct and audit the immutable QSDK-R23D75 development closure.

The closure consumes no new physics.  It replays the complete, immutable,
outcome-exposed R23D74 native trace population through the clean-pushed R23D75
engine-aware startup binding.  R23D74 remains consumed and invalid/incomplete;
only the successor's software-conformance question can close positively.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
from typing import Any, Sequence


REPO_ROOT = Path(__file__).resolve().parents[2]
TURNING_ROOT = REPO_ROOT / "sdk" / "turning"
if str(TURNING_ROOT) not in sys.path:
    sys.path.insert(0, str(TURNING_ROOT))

import r23d75_native_startup_trace_evaluator_conformance as conformance  # noqa: E402


SOURCE_COMMIT = "440c375cc8d082461fd1de1ccb71d5a696103eb6"
SOURCE_TREE = "4beb62aa6a7b53764e381d3318e83db8fa20e578"
EXPECTED_REMOTE = "https://github.com/Slagathore/sporespore.git"
CAMPAIGN_ID = conformance.CAMPAIGN_ID
GATE_ID = conformance.GATE_ID
CLOSURE_SCHEMA = (
    "sporespore_qsdk_r23d75_native_startup_trace_evaluator_"
    "conformance_development_closure_v1"
)
CLOSURE_STATUS = "closed_valid_complete_native_startup_trace_evaluator_conformance_development"
CLOSURE_PATH = (
    TURNING_ROOT
    / "r23d75_native_startup_trace_evaluator_conformance_closure_v1.json"
)

SOURCE_FILES = {
    "sdk/turning/r23d75_native_startup_trace_evaluator_conformance.py": {
        "git_blob_oid": "6533c6df306014cb9deceef6414fbb1a4ab911c2",
        "git_blob_raw_sha256": (
            "sha256:f56f33607b505f6e3cb3f6e3f16fc57421db357576cdcae0690bc2c7ec163e63"
        ),
    },
    "sdk/turning/r23d75_native_startup_trace_evaluator_conformance_v1.json": {
        "git_blob_oid": "e692123661f4bc3da1c021bfff8038b55a07f22d",
        "git_blob_raw_sha256": (
            "sha256:7185288894258f6abe8a73f5a9bb896ed6b25b6b528c89a800f9d88eed2753ea"
        ),
    },
    "tests/test_qsdk_r23d75_native_startup_trace_evaluator_conformance.ps1": {
        "git_blob_oid": "08a6ded726f65148ec93bf0fad7da8d1b85fef48",
        "git_blob_raw_sha256": (
            "sha256:855a5b26a7fb13ce4ecf0c9d74013dfb16f88bc272252bcfc94442e712efb706"
        ),
    },
}


class R23D75ClosureError(RuntimeError):
    """The source freeze, replay, closure projection or persisted file is invalid."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise R23D75ClosureError(code)


def _git(*arguments: str, binary: bool = False) -> bytes | str:
    completed = subprocess.run(
        ["git", "-C", str(REPO_ROOT), *arguments],
        check=False,
        capture_output=True,
    )
    if completed.returncode != 0:
        detail = completed.stderr.decode("utf-8", errors="replace").strip()
        raise R23D75ClosureError(
            f"R23D75_GIT_COMMAND_FAILED:{arguments[0]}:{detail}"
        )
    if binary:
        return completed.stdout
    return completed.stdout.decode("utf-8").strip()


def _canonical_sha256(value: Any) -> str:
    payload = json.dumps(
        value,
        allow_nan=False,
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")
    return "sha256:" + hashlib.sha256(payload).hexdigest()


def _source_projection() -> dict[str, Any]:
    root = str(_git("rev-parse", "--show-toplevel")).replace("\\", "/")
    _require(root.casefold() == REPO_ROOT.as_posix().casefold(), "R23D75_REPO_ROOT_INVALID")
    _require(_git("remote", "get-url", "origin") == EXPECTED_REMOTE, "R23D75_REMOTE_INVALID")
    _require(_git("cat-file", "-t", SOURCE_COMMIT) == "commit", "R23D75_SOURCE_COMMIT_MISSING")
    _require(_git("rev-parse", f"{SOURCE_COMMIT}^{{tree}}") == SOURCE_TREE, "R23D75_SOURCE_TREE_INVALID")
    ancestor = subprocess.run(
        ["git", "-C", str(REPO_ROOT), "merge-base", "--is-ancestor", SOURCE_COMMIT, "HEAD"],
        check=False,
        capture_output=True,
    )
    _require(ancestor.returncode == 0, "R23D75_SOURCE_NOT_ANCESTOR")

    files: dict[str, Any] = {}
    for relative, expected in SOURCE_FILES.items():
        blob = str(_git("rev-parse", f"{SOURCE_COMMIT}:{relative}"))
        payload = _git("show", f"{SOURCE_COMMIT}:{relative}", binary=True)
        assert isinstance(payload, bytes)
        sha256 = "sha256:" + hashlib.sha256(payload).hexdigest()
        _require(blob == expected["git_blob_oid"], f"R23D75_SOURCE_BLOB_INVALID:{relative}")
        _require(
            sha256 == expected["git_blob_raw_sha256"],
            f"R23D75_SOURCE_BYTES_INVALID:{relative}",
        )
        unchanged = subprocess.run(
            ["git", "-C", str(REPO_ROOT), "diff", "--quiet", SOURCE_COMMIT, "--", relative],
            check=False,
            capture_output=True,
        )
        _require(unchanged.returncode == 0, f"R23D75_LIVE_SOURCE_DRIFT:{relative}")
        files[relative] = {
            "git_blob_oid": blob,
            "git_blob_raw_sha256": sha256,
        }
    return {
        "commit": SOURCE_COMMIT,
        "tree_git_oid": SOURCE_TREE,
        "branch": "main",
        "origin_main_commit_at_freeze": SOURCE_COMMIT,
        "live_github_main_commit_at_freeze": SOURCE_COMMIT,
        "worktree_clean_at_freeze": True,
        "files": files,
    }


def build_closure() -> dict[str, Any]:
    source = _source_projection()
    replay = conformance.replay_r23d74_retained_traces()
    _require(replay.get("conformance_passed") is True, "R23D75_REPLAY_NOT_PASSING")
    _require(replay.get("retained_trace_count") == 9, "R23D75_REPLAY_TRACE_COUNT")
    _require(replay.get("retained_trace_row_count") == 26_928, "R23D75_REPLAY_ROW_COUNT")
    _require(
        replay.get("retained_trace_count_by_engine")
        == {"godot_jolt": 3, "rapier_parry": 3, "mujoco": 3},
        "R23D75_REPLAY_ENGINE_COUNT",
    )
    zero_world = replay["zero_world_preflight"]
    _require(
        zero_world.get("status")
        == "complete_zero_world_gate_passed_retained_trace_replay_pending"
        and zero_world.get("startup_mutation_rejection_count") == 19
        and zero_world.get("world_attempt_count") == 0,
        "R23D75_ZERO_WORLD_PROJECTION_INVALID",
    )
    trace_replays = replay["trace_replays"]
    replay_digest = _canonical_sha256(trace_replays)
    return {
        "schema_version": CLOSURE_SCHEMA,
        "status": CLOSURE_STATUS,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "ledger_scope": {
            "subsystem": "turning",
            "engine_scope": "godot_jolt_rapier_parry_mujoco",
            "authority_mode": "zero_world_and_retained_trace_development",
            "question_class": "development",
        },
        "source": source,
        "immutable_parent": {
            "gate_id": "QSDK-R23D74",
            "campaign_id": "QSDK-R23D74-FRESH-FINITE-THREE-ENGINE-TURNING-DECISION",
            "closure_path": (
                "sdk/turning/"
                "r23d74_production_route_three_engine_turning_validation_closure_v1.json"
            ),
            "closure_raw_sha256": conformance.R23D74_CLOSURE_SHA256,
            "observed_status": (
                "closed_consumed_invalid_or_incomplete_first_attempt_"
                "mujoco_startup_trace_evaluator_binding_mismatch"
            ),
            "seed_consumed": True,
            "rerun_or_selective_repair_permitted": False,
            "result_reinterpreted": False,
        },
        "development_question": {
            "classification": "valid_complete_positive_software_conformance_development",
            "question_class": "development",
            "question_answered": (
                "The exact declared native engine identity selects the already-observed "
                "startup transform and the shared retained-trace evaluator consumes all "
                "nine exact R23D74 traces without modifying their rows."
            ),
            "threshold_introduced_or_invoked": False,
            "equivalence_margin": None,
            "non_inferiority_margin": None,
            "behavioral_success_evaluated": False,
            "turning_result_computed": False,
            "new_physical_evidence_collected": False,
        },
        "engine_startup_binding": {
            engine_id: {
                "startup_transform_id": conformance.startup_transform_spec(
                    engine_id
                ).startup_transform_id,
                "startup_ramp_id": conformance.startup_transform_spec(
                    engine_id
                ).startup_ramp_id,
                "startup_policy": conformance.startup_transform_spec(
                    engine_id
                ).startup_policy,
                "startup_step_count": conformance.startup_transform_spec(
                    engine_id
                ).startup_step_count,
            }
            for engine_id in conformance.design.ENGINES
        },
        "zero_world": {
            "complete_gate_passed": True,
            "complete_engine_binding_enumeration_count": zero_world[
                "complete_engine_binding_enumeration_count"
            ],
            "compact_positive_sequence_count": zero_world[
                "compact_positive_sequence_count"
            ],
            "compact_row_count_per_sequence": zero_world[
                "compact_row_count_per_sequence"
            ],
            "sampled_boundary_steps": zero_world["sampled_boundary_steps"],
            "startup_mutation_rejection_count": zero_world[
                "startup_mutation_rejection_count"
            ],
            "unsupported_engine_rejection_count": zero_world[
                "unsupported_engine_rejection_count"
            ],
            "full_seeded_world_ghost_run": False,
            "behavioral_success_prediction_made": False,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physical_execution_authorized": False,
            "physical_acceptance_authority": False,
        },
        "retained_trace_replay": {
            "scientific_role": "outcome_exposed_software_conformance_development",
            "complete_enumeration_used": True,
            "sampling_used": False,
            "retained_trace_count": replay["retained_trace_count"],
            "retained_trace_row_count": replay["retained_trace_row_count"],
            "retained_trace_count_by_engine": replay[
                "retained_trace_count_by_engine"
            ],
            "trace_replay_projection_sha256": replay_digest,
            "trace_replays": trace_replays,
            "all_conformance_passed": True,
            "new_physical_world_count": 0,
            "turning_result_computed": False,
            "r23d74_result_reinterpreted": False,
            "physical_acceptance_authority": False,
        },
        "provenance_and_adequacy": {
            "cohort": "all_nine_exact_outcome_exposed_r23d74_native_traces",
            "cohort_selection": "complete_enumeration_from_the_immutable_r23d74_closure",
            "sampling_used": False,
            "population_inference_attempted": False,
            "adequacy_argument": (
                "The defect was an exact finite three-engine startup-binding mismatch. "
                "All three engine identities, both observed startup mechanisms, exact "
                "boundary behavior, 19 shape/identity/cross-binding mutations, unknown-"
                "engine refusal, and all nine retained native traces were exercised. "
                "That is complete for this software-conformance question and is not a "
                "behavior, robustness, equivalence, or population claim."
            ),
        },
        "immutability": {
            "r23d74_trace_row_rewrite_count": 0,
            "r23d74_threshold_change_count": 0,
            "r23d74_selector_change_count": 0,
            "r23d74_evaluator_rewrite_count": 0,
            "r23d74_result_rewrite_count": 0,
            "r23d74_interpretation_change_count": 0,
            "native_startup_policy_change_count": 0,
        },
        "claims": dict(conformance.FALSE_CLAIMS),
        "next_boundary": {
            "native_startup_trace_evaluator_conformance_closed": True,
            "fresh_finite_turning_decision_requires_new_campaign_identity_and_seed": True,
            "fresh_finite_turning_decision_authorized_by_this_closure": False,
            "r23d74_rerun_or_selective_repair_permitted": False,
            "physical_world_permitted_by_this_closure": False,
        },
    }


def audit_closure() -> dict[str, Any]:
    expected = build_closure()
    try:
        observed = json.loads(CLOSURE_PATH.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise R23D75ClosureError(
            f"R23D75_CLOSURE_UNREADABLE:{type(error).__name__}"
        ) from error
    _require(observed == expected, "R23D75_CLOSURE_PROJECTION_DRIFT")
    return {
        "schema_version": "sporespore_qsdk_r23d75_closure_audit_v1",
        "status": "passed",
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "closure_status": observed["status"],
        "source_commit": observed["source"]["commit"],
        "retained_trace_count": observed["retained_trace_replay"][
            "retained_trace_count"
        ],
        "retained_trace_row_count": observed["retained_trace_replay"][
            "retained_trace_row_count"
        ],
        "startup_mutation_rejection_count": observed["zero_world"][
            "startup_mutation_rejection_count"
        ],
        "new_physical_world_count": 0,
        "turning_result_computed": False,
        "r23d74_result_reinterpreted": False,
        "physical_acceptance_authority": False,
    }


def _arguments(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--emit", action="store_true")
    mode.add_argument("--audit", action="store_true")
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    arguments = _arguments(sys.argv[1:] if argv is None else argv)
    try:
        if arguments.emit:
            print(json.dumps(build_closure(), indent=2, ensure_ascii=False) + "\n", end="")
        else:
            value = audit_closure()
            print(
                "QSDK_R23D75_CLOSURE_AUDIT "
                + json.dumps(
                    value,
                    allow_nan=False,
                    ensure_ascii=False,
                    separators=(",", ":"),
                    sort_keys=True,
                )
            )
        return 0
    except (
        R23D75ClosureError,
        conformance.R23D75ConformanceError,
        conformance.StartupBindingError,
        OSError,
        UnicodeError,
        json.JSONDecodeError,
        TypeError,
        ValueError,
    ) as error:
        print(
            f"QSDK_R23D75_CLOSURE_FAILURE {type(error).__name__}:{error}",
            file=sys.stderr,
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
