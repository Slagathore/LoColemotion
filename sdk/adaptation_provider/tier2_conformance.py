"""Compile the Tier 2 T0-T6 architecture-only conformance report."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any

try:
    from sporespore_locomotion import LocomotionCore, LocomotionCoreError
except ImportError:
    from python.sporespore_locomotion import LocomotionCore, LocomotionCoreError

from .tier2_architecture import (
    ARCHITECTURE_PATH,
    Tier2ArchitectureError,
    canonical_sha256,
    compile_candidate_chapter,
    freeze_corpus,
    load_tier2_architecture,
    promote_successor_release,
    register_model_candidate,
)


SDK_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = SDK_ROOT.parent
REPORT_SCHEMA = "sporespore_tier2_architecture_conformance_report_v1"


def _require(condition: bool, code: str, detail: str = "") -> None:
    if not condition:
        raise Tier2ArchitectureError(f"{code}:{detail}")


def _file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return f"sha256:{digest.hexdigest()}"


def _git(*arguments: str) -> tuple[bool, str]:
    result = subprocess.run(
        ["git", "-C", str(REPO_ROOT), *arguments],
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    return result.returncode == 0, result.stdout.strip()


def _source_receipt() -> dict[str, Any]:
    head_ok, head = _git("rev-parse", "HEAD")
    origin_ok, origin = _git("rev-parse", "origin/main")
    status_ok, status = _git(
        "status", "--porcelain=v1", "--untracked-files=all"
    )
    return {
        "commit": head if head_ok else None,
        "origin_main": origin if origin_ok else None,
        "clean": status_ok and status == "",
        "matches_origin_main": head_ok and origin_ok and head == origin,
        "status_entries": status.splitlines() if status else [],
    }


def _episode(
    episode_id: str,
    outcome: str,
    failure_code: str | None,
) -> dict[str, Any]:
    marker = "1" if outcome == "success" else "2"
    return {
        "schema_version": "sporespore_tier2_episode_v1",
        "episode_id": episode_id,
        "provider_request_sha256": "sha256:" + marker * 64,
        "provider_response_sha256": "sha256:" + "3" * 64,
        "resolution_receipt_sha256": "sha256:" + "4" * 64,
        "morphology_descriptor_sha256": "sha256:" + "5" * 64,
        "task_id": "bounded_walk",
        "environment_id": "mujoco_warp_discovery",
        "seed": 9101 if outcome == "success" else 9102,
        "outcome": outcome,
        "failure_code": failure_code,
        "candidate_only": True,
        "physical_acceptance_authority": False,
    }


def _qualification(engine_id: str) -> dict[str, Any]:
    markers = {
        "godot_jolt": "6",
        "rapier_parry": "7",
        "mujoco_cpu": "8",
    }
    return {
        "schema_version": "sporespore_tier2_engine_qualification_v1",
        "engine_id": engine_id,
        "prospective_contract_frozen": True,
        "accepted": True,
        "evidence_sha256": "sha256:" + markers[engine_id] * 64,
        "training_plane": False,
        "architecture_fixture_only": True,
        "physical_acceptance_authority": False,
    }


def run_tier2_architecture_conformance() -> dict[str, Any]:
    core = LocomotionCore()
    architecture = load_tier2_architecture()
    cells: list[dict[str, Any]] = []

    cells.append(
        {
            "cell_id": "t0_contract",
            "passed": True,
            "architecture_id": architecture["architecture_id"],
            "architecture_file_sha256": _file_sha256(ARCHITECTURE_PATH),
            "architecture_canonical_sha256": canonical_sha256(
                core, architecture
            ),
            "world_build_count": 0,
            "physical_acceptance_authority": False,
        }
    )

    success = _episode("episode_success", "success", None)
    failure = _episode("episode_failure", "failure", "fell_before_horizon")
    cells.append(
        {
            "cell_id": "t1_episode_records",
            "passed": True,
            "success_episode_sha256": canonical_sha256(core, success),
            "failure_episode_sha256": canonical_sha256(core, failure),
            "failure_retained": True,
            "world_build_count": 0,
            "physical_acceptance_authority": False,
        }
    )

    chapter = compile_candidate_chapter(
        core,
        lesson_family_id="bounded_velocity_residual",
        parent_encyclopedia_id="behavior_encyclopedia_v1",
        parent_encyclopedia_sha256="sha256:" + "9" * 64,
        episodes=[success, failure],
    )
    _require(chapter["success_count"] == 1, "T2_SUCCESS_COUNT")
    _require(chapter["counterexample_count"] == 1, "T2_FAILURE_COUNT")
    cells.append(
        {
            "cell_id": "t2_candidate_chapter",
            "passed": True,
            "candidate_chapter_id": chapter["candidate_chapter_id"],
            "success_count": chapter["success_count"],
            "counterexample_count": chapter["counterexample_count"],
            "parent_rewritten": chapter["parent_rewritten"],
            "world_build_count": 0,
            "physical_acceptance_authority": False,
        }
    )

    corpus = freeze_corpus(
        core,
        candidate_chapters=[chapter],
        prospective_split_plan_id="heldout_by_morphology_seed_v1",
    )
    cells.append(
        {
            "cell_id": "t3_frozen_corpus",
            "passed": True,
            "corpus_id": corpus["corpus_id"],
            "immutable_after_freeze": corpus["immutable_after_freeze"],
            "observed_results_may_change_split": corpus[
                "observed_results_may_change_split"
            ],
            "world_build_count": 0,
            "physical_acceptance_authority": False,
        }
    )

    model = register_model_candidate(
        core,
        corpus=corpus,
        model_architecture_id="bounded_residual_provider_v1",
        model_artifact_sha256="sha256:" + "a" * 64,
    )
    cells.append(
        {
            "cell_id": "t4_model_candidate",
            "passed": True,
            "model_candidate_id": model["model_candidate_id"],
            "base_model_immutable": model["base_model_immutable"],
            "online_weight_mutation_permitted": model[
                "online_weight_mutation_permitted"
            ],
            "world_build_count": 0,
            "physical_acceptance_authority": False,
        }
    )

    training_only_rejected = False
    try:
        promote_successor_release(
            core,
            candidate_chapter=chapter,
            corpus=corpus,
            model_candidate=model,
            qualifications=[
                {
                    **_qualification("mujoco_cpu"),
                    "engine_id": "mujoco_warp",
                    "training_plane": True,
                }
            ],
        )
    except Tier2ArchitectureError as error:
        training_only_rejected = str(error).startswith(
            "TIER2_PROMOTION_ENGINE_SET:"
        )
    _require(training_only_rejected, "T5_TRAINING_ONLY_ACCEPTED")
    cells.append(
        {
            "cell_id": "t5_training_only_negative_control",
            "passed": True,
            "mujoco_warp_only_promotion_rejected": True,
            "world_build_count": 0,
            "physical_acceptance_authority": False,
        }
    )

    promotion = promote_successor_release(
        core,
        candidate_chapter=chapter,
        corpus=corpus,
        model_candidate=model,
        qualifications=[
            _qualification("godot_jolt"),
            _qualification("rapier_parry"),
            _qualification("mujoco_cpu"),
        ],
    )
    _require(promotion["predecessor_rewritten"] is False, "T6_REWRITE")
    _require(
        promotion["deployed_provider_mutated_in_place"] is False,
        "T6_PROVIDER_MUTATION",
    )
    _require(promotion["successor_identity_new"] is True, "T6_IDENTITY")
    cells.append(
        {
            "cell_id": "t6_successor_promotion_shape",
            "passed": True,
            "promotion_id": promotion["promotion_id"],
            "required_engine_set_complete": promotion[
                "required_engine_set_complete"
            ],
            "predecessor_rewritten": promotion["predecessor_rewritten"],
            "architecture_fixture_only": promotion[
                "architecture_fixture_only"
            ],
            "world_build_count": 0,
            "physical_acceptance_authority": False,
        }
    )

    return {
        "schema_version": REPORT_SCHEMA,
        "ok": True,
        "architecture_id": architecture["architecture_id"],
        "release_gate_id": "QSDK-R22",
        "source": _source_receipt(),
        "core": {
            "version": core.version,
            "library_path_execution_only": str(core.library_path),
            "library_sha256": _file_sha256(core.library_path),
        },
        "cells": cells,
        "passed_cells": len(cells),
        "failed_cells": 0,
        "candidate_chapter_pipeline_executable": True,
        "success_and_failure_retention_exercised": True,
        "training_plane_only_promotion_rejected": True,
        "three_engine_successor_promotion_shape_exercised": True,
        "trained_provider_evaluated": False,
        "engine_qualification_executed": False,
        "architecture_fixture_only": True,
        "world_build_count": 0,
        "walking_acceptance": False,
        "physical_acceptance_authority": False,
        "completed_engine_neutral_sdk": False,
    }


def _retain_report(report: dict[str, Any], path: Path) -> None:
    _require(path.name == "report.json", "TIER2_REPORT_NAME_INVALID")
    _require(not path.exists(), "TIER2_REPORT_ALREADY_EXISTS", str(path))
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name("report.json.tmp")
    _require(not temporary.exists(), "TIER2_REPORT_TEMP_EXISTS")
    temporary.write_text(
        json.dumps(report, indent=2, allow_nan=False) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    os.replace(temporary, path)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        report = run_tier2_architecture_conformance()
        if args.output is not None:
            output = args.output.resolve()
            _retain_report(report, output)
            print(f"retained Tier 2 report: {output}", file=sys.stderr)
        print(json.dumps(report, indent=2, allow_nan=False))
    except (Tier2ArchitectureError, LocomotionCoreError, OSError) as error:
        print(str(error), file=sys.stderr)
        raise SystemExit(1) from error


if __name__ == "__main__":
    main()
