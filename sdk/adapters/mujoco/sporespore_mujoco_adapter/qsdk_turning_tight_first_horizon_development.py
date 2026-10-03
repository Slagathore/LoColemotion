"""Classic-MuJoCo development wrapper for the 600/960 horizon successor."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any, Sequence

from . import qsdk_turning_tight_first_development as base

import terminal_tight_first_horizon_development as candidate


SCHEMA_VERSION = (
    "sporespore_qsdk_turning_tight_first_horizon_mujoco_development_v1"
)
MARKER = base.MARKER


def run_development(
    *, arm_id: str, source_commit: str, output_root: Path
) -> dict[str, Any]:
    return base._run_development_policy(
        arm_id=arm_id,
        source_commit=source_commit,
        output_root=output_root,
        policy=candidate,
        schema_version=SCHEMA_VERSION,
        candidate_change=(
            "retain_tight_gating_and_extend_maximum_active_540_to_600_"
            "plus_terminal_900_to_960"
        ),
    )


def preflight(source_commit: str) -> dict[str, Any]:
    oracle = candidate.run_zero_world_preflight()
    inherited = base.preflight(source_commit)
    if inherited["frozen_r23d13_production_refusal"] != "QSDK_R23D13_MJC_CLOSED":
        raise base.TightFirstDevelopmentError(
            "TIGHT_FIRST_HORIZON_FROZEN_WORKER_NOT_CLOSED"
        )
    return {
        "schema_version": SCHEMA_VERSION,
        "candidate_id": candidate.CANDIDATE_ID,
        "predecessor_candidate_id": candidate.v1.CANDIDATE_ID,
        "source_commit": source_commit,
        "oracle": oracle,
        "qualified_inherited_worker_count": inherited[
            "qualified_inherited_worker_count"
        ],
        "frozen_r23d13_production_refusal": inherited[
            "frozen_r23d13_production_refusal"
        ],
        "candidate_injection_scope": (
            "development_wrapper_process_only_restored_in_finally"
        ),
        "physical_process_launch_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "development_only": True,
        "outcomes_are_exposed": True,
        "validation_authority": False,
        "physical_acceptance_authority": False,
        "release_authorized": False,
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    preflight_parser = commands.add_parser("preflight")
    preflight_parser.add_argument("--source-commit", required=True)
    run_parser = commands.add_parser("run")
    run_parser.add_argument("--arm-id", choices=base.ALLOWED_ARMS, required=True)
    run_parser.add_argument("--source-commit", required=True)
    run_parser.add_argument("--output-root", type=Path, required=True)
    arguments = parser.parse_args(argv)
    try:
        if arguments.command == "preflight":
            receipt = preflight(arguments.source_commit)
        else:
            receipt = run_development(
                arm_id=arguments.arm_id,
                source_commit=arguments.source_commit,
                output_root=arguments.output_root,
            )
        print(MARKER + json.dumps(receipt, allow_nan=False, sort_keys=True))
        return 0
    except Exception as error:
        print(
            MARKER
            + json.dumps(
                {
                    "schema_version": SCHEMA_VERSION,
                    "candidate_id": candidate.CANDIDATE_ID,
                    "failure_code": f"{type(error).__name__}:{error}",
                    "development_only": True,
                    "validation_authority": False,
                    "physical_acceptance_authority": False,
                    "release_authorized": False,
                },
                allow_nan=False,
                sort_keys=True,
            )
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
