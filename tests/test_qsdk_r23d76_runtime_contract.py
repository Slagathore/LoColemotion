#!/usr/bin/env python3
"""Compact zero-world runtime and terminal-contract controls for R23D76."""

from __future__ import annotations

import copy
import json
from pathlib import Path
import sys
from typing import Any, Callable


ROOT = Path(__file__).resolve().parents[1]
TURNING = ROOT / "sdk" / "turning"
if str(TURNING) not in sys.path:
    sys.path.insert(0, str(TURNING))

import r23d76_production_route_runtime as design  # noqa: E402
import r23d76_production_route_three_engine_turning_evaluator as evaluator  # noqa: E402


def _declaration() -> dict[str, Any]:
    return json.loads(design.DECLARATION_PATH.read_text(encoding="utf-8"))


def _rejects(mutate: Callable[[dict[str, Any]], None]) -> bool:
    candidate = copy.deepcopy(_declaration())
    mutate(candidate)
    try:
        design.validate_declaration(candidate)
    except (RuntimeError, ValueError):
        return True
    return False


def _terminals() -> list[dict[str, Any]]:
    return [
        {
            "cell_id": item.cell_id,
            "engine_id": item.engine_id,
            "campaign_seed": item.campaign_seed,
            "profile_id": item.profile_id,
            "host_mapping_id": item.host_mapping_id,
            "arm_id": item.arm_id,
            "turn_heading_offset_rad": item.turn_heading_offset_rad,
            "question_class": design.QUESTION_CLASS,
            "trace_artifact": {
                "trace_transport_id": evaluator.TRACE_TRANSPORT_ID,
                "trace_transport_engine_id": item.engine_id,
                "canonical_ndjson": True,
                "full_precision": True,
                "byte_length": 1,
            },
        }
        for item in design.cells()
    ]


def main() -> int:
    declaration = _declaration()
    design.validate_declaration(declaration)
    projection = design.validate_runtime_projection()
    if projection["cell_count"] != 9:
        raise RuntimeError("R23D76_RUNTIME_CELL_COUNT_INVALID")

    declaration_mutations: tuple[Callable[[dict[str, Any]], None], ...] = (
        lambda value: value.update(status="physical_authorized"),
        lambda value: value.update(campaign_id="QSDK-R23D74"),
        lambda value: value["held_out_seed_selection"].update(seed=23195),
        lambda value: value["finite_population"]["ordered_cell_ids"].reverse(),
        lambda value: value["fixed_schedule"].update(controller_semantic_step_count=2),
        lambda value: value["fixed_schedule"]["startup_transform_by_engine"].update(
            mujoco=design.SUPPORT_LOSS_STARTUP_ID
        ),
        lambda value: value["thresholds_and_estimator"].update(
            minimum_positive_raw_cycle_shift_rad=0.02
        ),
        lambda value: value["thresholds_and_estimator"].update(
            equivalence_margin=0.1
        ),
        lambda value: value["required_zero_world_implementation_gate"].update(
            full_seeded_world_ghost_required=True
        ),
        lambda value: value["post_zero_world_native_smoke"].update(
            uses_held_out_seed_23197=True
        ),
        lambda value: value["physical_authorization"].update(
            physical_execution_authorized=True
        ),
        lambda value: value["claims"].update(
            q_sdk_r23_satisfied=True,
            release_score_after="11/25",
        ),
    )
    declaration_results = [_rejects(mutation) for mutation in declaration_mutations]
    declaration_rejections = sum(declaration_results)
    if declaration_rejections != len(declaration_mutations):
        accepted = [index for index, rejected in enumerate(declaration_results) if not rejected]
        raise RuntimeError(f"R23D76_DECLARATION_MUTATION_ACCEPTED:{accepted}")

    terminals = _terminals()
    if evaluator._terminal_contract_failures(terminals):
        raise RuntimeError("R23D76_TERMINAL_POSITIVE_CONTROL_FAILED")
    evaluator._configure_inherited_evaluator()
    evaluator.inherited._validate_complete_order(terminals)

    terminal_mutations: tuple[Callable[[list[dict[str, Any]]], None], ...] = (
        lambda value: value[0].update(question_class="development"),
        lambda value: value[0].pop("trace_artifact"),
        lambda value: value[0]["trace_artifact"].update(trace_transport_id="wrong"),
        lambda value: value[0]["trace_artifact"].update(
            trace_transport_engine_id="mujoco"
        ),
        lambda value: value[0]["trace_artifact"].update(canonical_ndjson=False),
        lambda value: value[0]["trace_artifact"].update(full_precision=False),
        lambda value: value[0]["trace_artifact"].update(byte_length="1"),
        lambda value: value.pop(),
    )
    terminal_rejections = 0
    for mutate in terminal_mutations:
        candidate = copy.deepcopy(terminals)
        mutate(candidate)
        rejected = bool(evaluator._terminal_contract_failures(candidate))
        try:
            evaluator.inherited._validate_complete_order(candidate)
        except (RuntimeError, ValueError):
            rejected = True
        terminal_rejections += int(rejected)
    if terminal_rejections != len(terminal_mutations):
        raise RuntimeError("R23D76_TERMINAL_MUTATION_ACCEPTED")

    receipt = {
        "schema_version": "sporespore_qsdk_r23d76_runtime_contract_test_v1",
        "declaration_mutation_rejection_count": declaration_rejections,
        "terminal_contract_mutation_rejection_count": terminal_rejections,
        "declared_cell_count": len(terminals),
        "engine_aware_startup_binding": copy.deepcopy(
            design.STARTUP_TRANSFORM_BY_ENGINE
        ),
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
    }
    print("QSDK_R23D76_RUNTIME_CONTRACT_PASS " + json.dumps(receipt, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
