"""Repeatable classic-MuJoCo screen for the tight-gated turning hypothesis.

The frozen R23D13 worker remains closed.  This module deliberately reuses its
already-qualified controller, fixture, host mapping, and physics loop while
injecting one development-only temporal transition and a separate trace sink.
Every output remains visibly non-validating and cannot satisfy a release gate.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any, Sequence

from . import qsdk_r23d13_residual_pose_authority_physical as frozen_worker

import terminal_tight_first_development as candidate


SCHEMA_VERSION = "sporespore_qsdk_turning_tight_first_mujoco_development_v1"
MARKER = "QSDK_TURNING_TIGHT_FIRST_DEVELOPMENT "
ALLOWED_ARMS = ("positive_heading", "negative_heading")
STAGE_ID = "mujoco_residual_pose_authority_screen"


class TightFirstDevelopmentError(RuntimeError):
    pass


def _sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def _durable_development_root() -> Path:
    return (
        frozen_worker.REPO_ROOT.parent / "SporeSpore_Evidence" / "development"
    ).resolve()


def _validated_new_output_root(path: Path) -> Path:
    resolved = path.resolve()
    try:
        resolved.relative_to(_durable_development_root())
    except ValueError as error:
        raise TightFirstDevelopmentError(
            "TIGHT_FIRST_OUTPUT_OUTSIDE_DURABLE_DEVELOPMENT_ROOT"
        ) from error
    if resolved.exists():
        raise TightFirstDevelopmentError("TIGHT_FIRST_OUTPUT_ALREADY_EXISTS")
    resolved.mkdir(parents=True, exist_ok=False)
    return resolved


def _development_authorization(output_root: Path):
    def authorize(cell: Any, source_commit: str) -> dict[str, Any]:
        del cell
        return {
            "attempt_root": output_root,
            "source_commit": source_commit,
            "development_only": True,
            "development_authorization_injection_used": True,
            "production_authorization_route_invoked": False,
            "production_authority_granted": False,
        }

    return authorize


def _retain_development_trace_for(policy: Any):
    def retain(
        cell: Any, rows: list[dict[str, Any]], attempt_root: Path
    ) -> dict[str, Any]:
        trace_root = attempt_root / "traces"
        trace_root.mkdir(parents=True, exist_ok=False)
        trace_path = trace_root / f"{cell.cell_id}.ndjson"
        with trace_path.open("x", encoding="utf-8", newline="\n") as stream:
            for row in rows:
                stream.write(
                    json.dumps(
                        row,
                        allow_nan=False,
                        separators=(",", ":"),
                        sort_keys=True,
                    )
                    + "\n"
                )
        terminal_rows = rows[-int(policy.TERMINAL_STEPS) :]
        active_rows = [
            row for row in terminal_rows if not bool(row["zero_actuation"])
        ]
        passive_rows = [row for row in terminal_rows if bool(row["zero_actuation"])]
        return {
            "trace_artifact": {
                "path": str(trace_path),
                "raw_sha256": _sha256(trace_path),
                "byte_length": trace_path.stat().st_size,
                "row_count": len(rows),
                "development_only": True,
                "content_addressed": False,
            },
            "trace_summary": {
                "schema_version": (
                    "sporespore_tight_first_development_trace_summary_v1"
                ),
                "row_count": len(rows),
                "terminal_row_count": len(terminal_rows),
                "active_terminal_row_count": len(active_rows),
                "passive_terminal_row_count": len(passive_rows),
                "tight_pose_row_count": sum(
                    int(bool(row["tight_pose_satisfied"])) for row in active_rows
                ),
                "first_tight_pose_trace_step": next(
                    (
                        int(row["trace_step"])
                        for row in active_rows
                        if bool(row["tight_pose_satisfied"])
                    ),
                    None,
                ),
                "development_only": True,
                "validation_authority": False,
                "physical_acceptance_authority": False,
            },
        }

    return retain


_retain_development_trace = _retain_development_trace_for(candidate)


def _screen_conjunction(report: dict[str, Any], arm_id: str) -> dict[str, Any]:
    measurements = report["measurements"]
    yaw = float(measurements["turn_phase_yaw_delta_rad"])
    signed_yaw = yaw >= 0.01 if arm_id == "positive_heading" else yaw <= -0.01
    integrity = (
        bool(report["execution"]["integrity_passed"])
        and int(report["execution"]["world_attempt_count"]) == 1
        and int(report["execution"]["world_build_count"]) == 1
        and int(measurements["controller_error_count"]) == 0
        and int(measurements["active_safe_no_actuation_count"]) == 0
        and int(measurements["nonfinite_observation_count"]) == 0
        and int(measurements["actuator_application_mismatch_count"]) == 0
        and int(measurements["terminal_receipt_validation_failure_count"]) == 0
    )
    walking = (
        float(measurements["final_forward_displacement_m"]) >= 0.030123046875
        and float(measurements["maximum_tilt_rad"]) <= 0.6
        and float(measurements["minimum_torso_height_m"]) >= 0.2499708652072946
        and int(measurements["torso_ground_contact_step_count"]) == 0
        and all(
            int(value) >= 2
            for value in measurements["contact_cycle_count_by_limb"].values()
        )
    )
    terminal = bool(measurements["quiescent_taper_gate_passed"])
    return {
        "execution_integrity_passed": integrity,
        "walking_safety_conjunction_passed": walking,
        "signed_yaw_response_passed": signed_yaw,
        "tight_first_terminal_gate_passed": terminal,
        "development_screen_passed": integrity and walking and signed_yaw and terminal,
    }


def _run_development_policy(
    *,
    arm_id: str,
    source_commit: str,
    output_root: Path,
    policy: Any,
    schema_version: str,
    candidate_change: str,
) -> dict[str, Any]:
    if arm_id not in ALLOWED_ARMS:
        raise TightFirstDevelopmentError("TIGHT_FIRST_ARM_INVALID")
    if (
        len(source_commit) != 40
        or any(character not in "0123456789abcdef" for character in source_commit)
    ):
        raise TightFirstDevelopmentError("TIGHT_FIRST_SOURCE_COMMIT_INVALID")
    root = _validated_new_output_root(output_root)
    manifest = {
        "schema_version": schema_version,
        "candidate_id": policy.CANDIDATE_ID,
        "arm_id": arm_id,
        "source_commit": source_commit,
        "development_only": True,
        "outcomes_are_exposed": True,
        "inherited_frozen_worker": (
            "qsdk_r23d13_residual_pose_authority_physical"
        ),
        "candidate_change": candidate_change,
        "terminal_step_count": int(policy.TERMINAL_STEPS),
        "maximum_active_step_count": int(policy.MAXIMUM_ACTIVE_STEPS),
        "world_count_if_completed": 1,
        "validation_authority": False,
        "physical_acceptance_authority": False,
        "release_authorized": False,
    }
    manifest_path = root / "manifest.json"
    manifest_path.write_text(
        json.dumps(manifest, allow_nan=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
        newline="\n",
    )

    original_authorization = frozen_worker.physical_authorization
    original_retention = frozen_worker._retain_trace
    original_observer = frozen_worker.terminal.observe_completed_step
    original_contract = frozen_worker._contract
    original_terminal_steps = frozen_worker.terminal.TERMINAL_STEPS
    original_maximum_active_steps = frozen_worker.terminal.MAXIMUM_ACTIVE_STEPS
    original_design_terminal_steps = frozen_worker.design.TERMINAL_STEPS
    frozen_declaration = frozen_worker._contract()
    try:
        frozen_worker.physical_authorization = _development_authorization(root)
        frozen_worker._retain_trace = _retain_development_trace_for(policy)
        frozen_worker.terminal.observe_completed_step = policy.observe_completed_step
        if (
            int(policy.TERMINAL_STEPS) != int(original_terminal_steps)
            or int(policy.MAXIMUM_ACTIVE_STEPS)
            != int(original_maximum_active_steps)
        ):
            frozen_worker._contract = lambda: frozen_declaration
            frozen_worker.terminal.TERMINAL_STEPS = int(policy.TERMINAL_STEPS)
            frozen_worker.terminal.MAXIMUM_ACTIVE_STEPS = int(
                policy.MAXIMUM_ACTIVE_STEPS
            )
            frozen_worker.design.TERMINAL_STEPS = int(policy.TERMINAL_STEPS)
        inherited_report = frozen_worker.run_physical(
            STAGE_ID, arm_id, source_commit
        )
    finally:
        frozen_worker.physical_authorization = original_authorization
        frozen_worker._retain_trace = original_retention
        frozen_worker.terminal.observe_completed_step = original_observer
        frozen_worker._contract = original_contract
        frozen_worker.terminal.TERMINAL_STEPS = original_terminal_steps
        frozen_worker.terminal.MAXIMUM_ACTIVE_STEPS = original_maximum_active_steps
        frozen_worker.design.TERMINAL_STEPS = original_design_terminal_steps

    conjunction = _screen_conjunction(inherited_report, arm_id)
    result = {
        "schema_version": schema_version,
        "candidate_id": policy.CANDIDATE_ID,
        "engine_id": "mujoco",
        "arm_id": arm_id,
        "source_commit": source_commit,
        "manifest_path": str(manifest_path),
        "manifest_raw_sha256": _sha256(manifest_path),
        "trace_artifact": inherited_report["trace_artifact"],
        "trace_summary": inherited_report["trace_summary"],
        "measurements": inherited_report["measurements"],
        "screen_conjunction": conjunction,
        "world_attempt_count": 1,
        "world_build_count": 1,
        "development_only": True,
        "outcomes_are_exposed": True,
        "candidate_selection_authority": True,
        "validation_authority": False,
        "cross_engine_equivalence": False,
        "portable_basic_turning": False,
        "physical_acceptance_authority": False,
        "release_authorized": False,
    }
    result_path = root / "result.json"
    result_path.write_text(
        json.dumps(result, allow_nan=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    result["result_path"] = str(result_path)
    result["result_raw_sha256"] = _sha256(result_path)
    return result


def run_development(
    *, arm_id: str, source_commit: str, output_root: Path
) -> dict[str, Any]:
    return _run_development_policy(
        arm_id=arm_id,
        source_commit=source_commit,
        output_root=output_root,
        policy=candidate,
        schema_version=SCHEMA_VERSION,
        candidate_change="tight_pose_gates_taper_entry_and_continuation",
    )


def preflight(source_commit: str) -> dict[str, Any]:
    oracle = candidate.run_zero_world_preflight()
    workers = [frozen_worker.worker_preflight(STAGE_ID, arm) for arm in ALLOWED_ARMS]
    closed_refusal = ""
    try:
        cell = frozen_worker._cell(STAGE_ID, ALLOWED_ARMS[0])
        frozen_worker.physical_authorization(cell, source_commit)
    except frozen_worker.R23D13MujocoPhysicalError as error:
        closed_refusal = error.code
    if closed_refusal != "QSDK_R23D13_MJC_CLOSED":
        raise TightFirstDevelopmentError("TIGHT_FIRST_FROZEN_WORKER_NOT_CLOSED")
    return {
        "schema_version": SCHEMA_VERSION,
        "candidate_id": candidate.CANDIDATE_ID,
        "source_commit": source_commit,
        "oracle": oracle,
        "qualified_inherited_worker_count": len(workers),
        "frozen_r23d13_production_refusal": closed_refusal,
        "candidate_injection_scope": (
            "development_wrapper_process_only_restored_in_finally"
        ),
        "physical_process_launch_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "development_only": True,
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
    run_parser.add_argument("--arm-id", choices=ALLOWED_ARMS, required=True)
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
