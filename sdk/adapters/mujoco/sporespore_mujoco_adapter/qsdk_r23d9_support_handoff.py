"""Classic-MuJoCo entrypoint for the prospective QSDK-R23D9 worker.

This module composes the already-qualified R23D8 MuJoCo neutral-stance route
with the frozen R23D9 support-handoff oracle. The real physical loop is dormant
behind source-exact single-supervisor authorization; ordinary preflight remains
strictly zero-world.
"""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import asdict
from pathlib import Path
from typing import Any, Iterable

from . import qsdk_r23d8_neutral_stance as inherited


SDK_ROOT = Path(__file__).resolve().parents[3]
TURNING_ROOT = SDK_ROOT / "turning"
if str(TURNING_ROOT) not in sys.path:
    sys.path.insert(0, str(TURNING_ROOT))

import r23d9_support_handoff as design  # noqa: E402


CAMPAIGN_ID = design.CAMPAIGN_ID
GATE_ID = design.GATE_ID
ENGINE_ID = "mujoco"
PREFLIGHT_SCHEMA = "sporespore_qsdk_r23d9_mujoco_worker_preflight_v1"
FAILURE_SCHEMA = "sporespore_qsdk_r23d9_worker_failure_v1"


class R23D9MujocoError(RuntimeError):
    """A zero-world R23D9 MuJoCo route failed closed."""


def _cell(stage_id: str, arm_id: str) -> dict[str, Any]:
    if stage_id == "mujoco_support_handoff_screen":
        allowed = ("positive_heading", "negative_heading")
    elif stage_id == "three_engine_confirmation":
        allowed = ("reference_zero", "positive_heading", "negative_heading")
    else:
        raise R23D9MujocoError(f"QSDK_R23D9_MJC_STAGE_UNKNOWN:{stage_id}")
    if arm_id not in allowed:
        raise R23D9MujocoError(f"QSDK_R23D9_MJC_ARM_UNKNOWN:{arm_id}")
    return {
        "stage_id": stage_id,
        "cell_id": f"mujoco__support_handoff__{arm_id}",
        "arm_id": arm_id,
        "turn_heading_offset_rad": {
            "reference_zero": 0.0,
            "positive_heading": 0.2,
            "negative_heading": -0.2,
        }[arm_id],
    }


def _inherited_stage(stage_id: str) -> str:
    return (
        "mujoco_neutral_stance_screen"
        if stage_id == "mujoco_support_handoff_screen"
        else "three_engine_confirmation"
    )


def _native_sequence_canaries() -> dict[str, Any]:
    down = (False, False, False, False)
    partial = (True, True, True, False)
    supported = (True, True, True, True)
    sequences = {
        "support_from_first_step": design._rows(
            (design.TERMINAL_STEPS, supported)
        ),
        "predecessor_shaped_transients": design._rows(
            (100, down),
            (23, supported),
            (1, partial),
            (16, supported),
            (1, partial),
            (159, down),
            (480, supported),
        ),
        "confirmation_at_deadline": design._rows((390, down), (390, supported)),
        "never_confirmed": design._rows((design.TERMINAL_STEPS, down)),
        "post_handoff_contact_loss": design._rows(
            (30, supported), (10, supported), (1, partial), (739, supported)
        ),
    }
    results: dict[str, Any] = {}
    for canary_id, rows in sequences.items():
        state = design.initial_state()
        receipts: list[dict[str, Any]] = []
        for contacts in rows:
            directive = design.plan_step(state)
            state, receipt = design.observe_completed_step(
                state,
                directive,
                contacts,
                directive.expected_native_application_count,
            )
            receipts.append(receipt)
        observed = design.outcome(state)
        if design.validation_failures(rows, receipts, observed):
            raise R23D9MujocoError(
                f"QSDK_R23D9_MJC_NATIVE_CANARY_REPLAY:{canary_id}"
            )
        results[canary_id] = {
            "final_state": asdict(state),
            "outcome": observed,
        }
    return results


def run_preflight(stage_id: str, arm_id: str) -> dict[str, Any]:
    cell = _cell(stage_id, arm_id)
    inherited_receipt = inherited.run_preflight(
        _inherited_stage(stage_id), arm_id
    )
    oracle = design.run_zero_world_preflight()
    native_canaries = _native_sequence_canaries()
    mutations = design._mutation_control_failures()
    if (
        inherited_receipt.get("model_construction_count") != 0
        or inherited_receipt.get("world_attempt_count") != 0
        or inherited_receipt.get("world_build_count") != 0
        or inherited_receipt.get("fixed_controller_horizon_step_count")
        != design.CONTROLLER_STEPS
        or inherited_receipt.get("neutral_stance_algebra_canary_count") != 5
        or oracle.get("oracle_canary_count") != 5
        or oracle.get("mutation_control_count") != 12
        or list(native_canaries)
        != list(oracle["oracle_canary_outcomes"])
        or list(mutations) != list(design._mutation_control_failures())
    ):
        raise R23D9MujocoError("QSDK_R23D9_MJC_PREFLIGHT_INVALID")
    return {
        "schema_version": PREFLIGHT_SCHEMA,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "engine_id": ENGINE_ID,
        **cell,
        "terminal_policy_id": design.POLICY_ID,
        "active_acquisition_policy_id": design.ACTIVE_POLICY_ID,
        "fixed_controller_horizon_step_count": design.CONTROLLER_STEPS,
        "fixed_terminal_handoff_step_count": design.TERMINAL_STEPS,
        "fixed_total_trace_step_count": design.TOTAL_TRACE_STEPS,
        "maximum_active_neutral_acquisition_step_count": (
            design.MAXIMUM_ACTIVE_STEPS
        ),
        "support_confirmation_step_count": design.SUPPORT_CONFIRMATION_STEPS,
        "minimum_post_handoff_zero_actuation_step_count": (
            design.MINIMUM_PASSIVE_STEPS
        ),
        "neutral_stance_algebra_canary_count": inherited_receipt[
            "neutral_stance_algebra_canary_count"
        ],
        "neutral_stance_mutation_control_count": inherited_receipt[
            "neutral_stance_mutation_control_count"
        ],
        "support_handoff_oracle_canary_count": len(native_canaries),
        "support_handoff_mutation_control_count": len(mutations),
        "native_temporal_mirror": True,
        "transition_applies_to_following_step": True,
        "handoff_is_irreversible": True,
        "post_handoff_native_actuation_permitted": False,
        "physical_worker_implemented": True,
        "physical_worker_dormant_behind_supervisor_authorization": True,
        "physics_adapter_start_count": 0,
        "physical_process_launch_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
    }


def _arguments(arguments: Iterable[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "command", choices=("preflight", "authorization-preflight", "physical")
    )
    parser.add_argument("--stage-id", required=True)
    parser.add_argument("--arm-id", required=True)
    parser.add_argument("--source-commit", default="")
    return parser.parse_args(arguments)


def main(arguments: Iterable[str] | None = None) -> int:
    args = _arguments(arguments)
    try:
        if args.command == "preflight":
            receipt = run_preflight(args.stage_id, args.arm_id)
            print(
                "QSDK_R23D9_MUJOCO_PREFLIGHT "
                + json.dumps(receipt, allow_nan=False, separators=(",", ":"), sort_keys=True)
            )
            return 0
        from . import qsdk_r23d9_support_handoff_physical as physical

        if args.command == "authorization-preflight":
            receipt = physical.authorization_preflight(
                args.stage_id, args.arm_id, args.source_commit
            )
            print(
                "QSDK_R23D9_MUJOCO_AUTHORIZATION_PREFLIGHT "
                + json.dumps(
                    receipt,
                    allow_nan=False,
                    separators=(",", ":"),
                    sort_keys=True,
                )
            )
            return 0
        report = physical.run_physical(
            args.stage_id, args.arm_id, args.source_commit
        )
        print(
            "QSDK_R23D9_TERMINAL "
            + json.dumps(
                report,
                allow_nan=False,
                separators=(",", ":"),
                sort_keys=True,
            )
        )
        return 0
    except (R23D9MujocoError, design.R23D9Error) as error:
        print(f"QSDK_R23D9_MUJOCO_FAILURE {error}", file=sys.stderr)
        return 1
    except Exception as error:
        # The physical module owns exact retained failure receipts. Import it
        # only after a physical or authorization command so zero-world module
        # loading cannot accidentally broaden the worker boundary.
        try:
            from . import qsdk_r23d9_support_handoff_physical as physical

            if isinstance(error, physical.R23D9MujocoPhysicalError):
                if error.terminal_receipt is not None:
                    print(
                        "QSDK_R23D9_TERMINAL "
                        + json.dumps(
                            error.terminal_receipt,
                            allow_nan=False,
                            separators=(",", ":"),
                            sort_keys=True,
                        )
                    )
                else:
                    print(f"QSDK_R23D9_MUJOCO_FAILURE {error}", file=sys.stderr)
                return 1
        except Exception:
            pass
        raise


if __name__ == "__main__":
    raise SystemExit(main())
