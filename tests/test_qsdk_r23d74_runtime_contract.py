#!/usr/bin/env python3
"""Zero-world mutation controls for the frozen R23D74 runtime contract.

This test exercises only declaration/runtime projection and terminal-shape
validation.  It imports no native physics binding and constructs no model or
world.
"""

from __future__ import annotations

import copy
import json
from pathlib import Path
import sys
from typing import Any, Callable


REPO_ROOT = Path(__file__).resolve().parents[1]
TURNING_ROOT = REPO_ROOT / "sdk" / "turning"
if str(TURNING_ROOT) not in sys.path:
    sys.path.insert(0, str(TURNING_ROOT))

import r23d74_production_route_runtime as design  # noqa: E402
import r23d74_production_route_three_engine_turning_evaluator as evaluator  # noqa: E402


Mutation = tuple[str, Callable[[dict[str, Any]], None]]


def _valid_terminal_entries() -> list[dict[str, Any]]:
    return [
        {
            "question_class": design.QUESTION_CLASS,
            "trace_artifact": {
                "trace_transport_id": evaluator.TRACE_TRANSPORT_ID,
                "trace_transport_engine_id": item.engine_id,
                "canonical_ndjson": True,
                "full_precision": True,
                "byte_length": 0,
            },
        }
        for item in design.cells()
    ]


def _expect_declaration_rejections(
    source: dict[str, Any], mutations: tuple[Mutation, ...]
) -> list[str]:
    rejected: list[str] = []
    for label, mutate in mutations:
        candidate = copy.deepcopy(source)
        mutate(candidate)
        try:
            design.validate_declaration(candidate)
        except design.DeclarationError:
            rejected.append(label)
            continue
        raise RuntimeError(f"QSDK_R23D74_DECLARATION_MUTATION_ACCEPTED:{label}")
    return rejected


def _expect_terminal_rejections() -> list[str]:
    source = _valid_terminal_entries()
    if evaluator._terminal_contract_failures(source):  # noqa: SLF001
        raise RuntimeError("QSDK_R23D74_VALID_TERMINAL_POPULATION_REJECTED")

    mutations: tuple[Mutation, ...] = (
        (
            "question_class",
            lambda value: value[0].__setitem__("question_class", "development"),
        ),
        (
            "trace_artifact",
            lambda value: value[0].__setitem__("trace_artifact", None),
        ),
        (
            "trace_transport_id",
            lambda value: value[0]["trace_artifact"].__setitem__(
                "trace_transport_id", "wrong"
            ),
        ),
        (
            "trace_transport_engine_id",
            lambda value: value[0]["trace_artifact"].__setitem__(
                "trace_transport_engine_id", "mujoco"
            ),
        ),
        (
            "canonical_ndjson",
            lambda value: value[0]["trace_artifact"].__setitem__(
                "canonical_ndjson", False
            ),
        ),
        (
            "full_precision",
            lambda value: value[0]["trace_artifact"].__setitem__(
                "full_precision", False
            ),
        ),
        (
            "byte_length_integer",
            lambda value: value[0]["trace_artifact"].__setitem__(
                "byte_length", 0.0
            ),
        ),
    )
    rejected: list[str] = []
    for label, mutate in mutations:
        candidate = copy.deepcopy(source)
        mutate(candidate)
        if not evaluator._terminal_contract_failures(candidate):  # noqa: SLF001
            raise RuntimeError(f"QSDK_R23D74_TERMINAL_MUTATION_ACCEPTED:{label}")
        rejected.append(label)
    if not evaluator._terminal_contract_failures(source[:-1]):  # noqa: SLF001
        raise RuntimeError("QSDK_R23D74_INCOMPLETE_TERMINAL_POPULATION_ACCEPTED")
    rejected.append("complete_entry_count")
    return rejected


def main() -> int:
    projection = design.validate_runtime_projection()
    source = design.load_source_declaration()
    declaration_mutations: tuple[Mutation, ...] = (
        ("status", lambda value: value.__setitem__("status", "physical_authorized")),
        (
            "held_out_seed",
            lambda value: value["held_out_seed_selection"].__setitem__("seed", 23195),
        ),
        (
            "cell_order",
            lambda value: value["finite_population"].__setitem__(
                "ordered_cell_ids",
                list(reversed(value["finite_population"]["ordered_cell_ids"])),
            ),
        ),
        (
            "measurement_origin_step",
            lambda value: value["fixed_schedule"].__setitem__(
                "forward_displacement_measurement_origin_semantic_step", 0
            ),
        ),
        (
            "mujoco_startup_ramp_steps",
            lambda value: value["fixed_schedule"].__setitem__(
                "mujoco_startup_ramp_step_count", 359
            ),
        ),
        (
            "positive_turn_threshold",
            lambda value: value["thresholds_and_estimator"].__setitem__(
                "minimum_positive_raw_cycle_shift_rad", 0.0
            ),
        ),
        (
            "common_physical_gate",
            lambda value: value["thresholds_and_estimator"][
                "common_physical_gate_vector"
            ].__setitem__("maximum_tilt_rad", 0.7),
        ),
        (
            "behavior_evaluator_change",
            lambda value: value["scientific_change_budget"].__setitem__(
                "behavior_evaluator_changed", True
            ),
        ),
        (
            "physical_execution_authority",
            lambda value: value["physical_authorization"].__setitem__(
                "physical_execution_authorized", True
            ),
        ),
        (
            "population_inference",
            lambda value: value["finite_population"].__setitem__(
                "population_inference_beyond_declared_matrix_allowed", True
            ),
        ),
    )
    declaration_rejections = _expect_declaration_rejections(
        source, declaration_mutations
    )
    terminal_rejections = _expect_terminal_rejections()
    exact = (
        projection["question_class"] == "finite_decision"
        and projection["cell_count"] == 9
        and projection["controller_step_count"] == 2_992
        and projection["measurement_origin_semantic_step"] == 472
        and projection["mujoco_startup_ramp_step_count"] == 360
        and projection["model_construction_count"] == 0
        and projection["world_attempt_count"] == 0
        and projection["world_build_count"] == 0
        and projection["solver_step_count"] == 0
        and projection["physical_execution_authorized"] is False
        and projection["physical_acceptance_authority"] is False
        and len(declaration_rejections) == 10
        and len(terminal_rejections) == 8
    )
    if not exact:
        raise RuntimeError("QSDK_R23D74_RUNTIME_CONTRACT_PROJECTION_INVALID")
    print(
        "QSDK_R23D74_RUNTIME_CONTRACT_PASS "
        + json.dumps(
            {
                "declaration_mutation_rejection_count": len(declaration_rejections),
                "terminal_mutation_rejection_count": len(terminal_rejections),
                "declared_cell_count": projection["cell_count"],
                "measurement_origin_semantic_step": projection[
                    "measurement_origin_semantic_step"
                ],
                "mujoco_startup_ramp_step_count": projection[
                    "mujoco_startup_ramp_step_count"
                ],
                "model_construction_count": 0,
                "world_attempt_count": 0,
                "world_build_count": 0,
                "solver_step_count": 0,
                "physical_execution_authorized": False,
                "physical_acceptance_authority": False,
            },
            allow_nan=False,
            separators=(",", ":"),
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
