"""Run MJCAL0-MJCAL7 pure zero-world protocol conformance."""

from __future__ import annotations

import argparse
import copy
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any, Callable

from .mujoco_warp_equivalence_calibration import (
    CONTRACT_PATH,
    REQUIRED_EXACT_FAILURES,
    REQUIRED_METRICS,
    REQUIRED_SENSITIVITY_ROLES,
    REQUIRED_WARP_PLACEMENTS,
    CalibrationProtocolError,
    canonical_sha256,
    compile_calibration_plan,
    compile_calibration_summary,
    compile_heldout_freeze_fixture,
    file_sha256,
    load_calibration_contract,
    minimum_zero_exceedance_condition_count,
)


SDK_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = SDK_ROOT.parent
REPORT_SCHEMA = "sporespore_mujoco_warp_equivalence_calibration_conformance_report_v1"


class CalibrationConformanceFailure(RuntimeError):
    """An MJCAL0-MJCAL7 fixture invariant failed."""


def _require(condition: bool, code: str, detail: object = "") -> None:
    if not condition:
        raise CalibrationConformanceFailure(f"{code}:{detail}")


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
    status_ok, status = _git("status", "--porcelain=v1", "--untracked-files=all")
    return {
        "commit": head if head_ok else None,
        "origin_main": origin if origin_ok else None,
        "clean": status_ok and status == "",
        "matches_origin_main": head_ok and origin_ok and head == origin,
        "status_entries": status.splitlines() if status else [],
    }


def _condition(
    cohort: str,
    ordinal: int,
    seed_base: int,
    factor_shift: int,
) -> dict[str, Any]:
    contacts = ("free_flight", "contact_transition", "sustained_contact")
    materials = ("mu020", "mu060", "mu100")
    horizons = (1, 5, 60, 600)
    index = ordinal + factor_shift
    return {
        "condition_id": f"mjcal_fixture_{cohort}_{ordinal:03d}",
        "cohort": cohort,
        "seed": seed_base + ordinal,
        "topology_bucket": "s169_fixture_bucket",
        "contact_regime": contacts[index % len(contacts)],
        "material_profile": materials[(index // len(contacts)) % len(materials)],
        "horizon_steps": horizons[
            (index // (len(contacts) * len(materials))) % len(horizons)
        ],
        "outcome_exposed": False,
        "training_data": False,
    }


def calibration_plan_fixture() -> dict[str, Any]:
    conditions = [_condition("calibration", index, 41000, 0) for index in range(59)]
    conditions.extend(_condition("heldout", index, 51000, 7) for index in range(59))
    semantic_sources = (
        "canonical_state_or_action_normalization_resolution",
        "downstream_training_label_stability",
        "canonical_state_or_action_normalization_resolution",
        "safety_gate_guard_band",
        "contact_event_label_tolerance",
    )
    margins = (0.01, 0.01, 0.02, 0.02, 1.0)
    units = (
        "normalized_ratio",
        "normalized_ratio",
        "normalized_ratio",
        "relative_ratio",
        "step",
    )
    plan = {
        "schema_version": ("sporespore_mujoco_warp_equivalence_calibration_plan_v1"),
        "plan_id": "mjcal_fixture_plan_not_production",
        "contract_raw_sha256": file_sha256(CONTRACT_PATH),
        "question_class": "development",
        "fixture_only": True,
        "population": {
            "population_id": "synthetic_protocol_fixture_population",
            "generator_sha256": "sha256:" + "a" * 64,
            "partition_sha256": "sha256:" + "0" * 64,
            "scope_statement": (
                "Synthetic zero-world records exercising only the protocol "
                "compiler and no physical population."
            ),
            "exchangeability_argument": (
                "Fixture ordinals are generated before any result and are "
                "used only to test the declared order-statistic contract."
            ),
            "coverage_probability": 0.95,
            "confidence_probability": 0.95,
            "population_claim_scope": "declared_generator_population_only",
        },
        "factor_levels": {
            "topology_bucket": ["s169_fixture_bucket"],
            "contact_regime": [
                "free_flight",
                "contact_transition",
                "sustained_contact",
            ],
            "material_profile": ["mu020", "mu060", "mu100"],
            "horizon_steps": [1, 5, 60, 600],
        },
        "conditions": conditions,
        "metric_margins": [
            {
                "metric_id": metric_id,
                "margin": margin,
                "unit": unit,
                "semantic_ceiling": margin,
                "semantic_source": source,
                "provenance_reference": (
                    f"fixture-only semantic provenance for {metric_id}"
                ),
                "chosen_before_calibration_outcomes": True,
            }
            for metric_id, margin, unit, source in zip(
                REQUIRED_METRICS,
                margins,
                units,
                semantic_sources,
                strict=True,
            )
        ],
        "repeatability": {
            "fresh_process_repeats_per_runtime_condition": 3,
            "warp_placement_modes": list(REQUIRED_WARP_PLACEMENTS),
            "selective_repeat_discard_or_replacement_permitted": False,
        },
        "numerical_sensitivity": {
            "perturbation_roles": list(REQUIRED_SENSITIVITY_ROLES),
            "effective_input_dtype_observed": True,
            "fields_axes_and_order_frozen_before_results": True,
            "outcome_selected_field_or_axis_permitted": False,
        },
        "exact_failure_families": list(REQUIRED_EXACT_FAILURES),
        "physical_series_open": False,
        "world_build_count": 0,
    }
    plan["population"]["partition_sha256"] = canonical_sha256(
        {
            "factor_levels": plan["factor_levels"],
            "conditions": plan["conditions"],
        }
    )
    return plan


def calibration_summary_fixture(
    plan_receipt: dict[str, Any], *, negative: bool = False
) -> dict[str, Any]:
    margins = plan_receipt["metric_margins"]
    results = []
    for ordinal, condition_id in enumerate(plan_receipt["calibration_condition_ids"]):
        metric_results = {}
        for metric_index, metric_id in enumerate(REQUIRED_METRICS):
            margin = margins[metric_id]["margin"]
            repeatability = margin * (0.05 + (ordinal % 5) * 0.01)
            sensitivity = margin * (0.10 + (metric_index % 3) * 0.02)
            metric_results[metric_id] = {
                "repeatability_max": repeatability,
                "sensitivity_max": sensitivity,
            }
        results.append(
            {
                "condition_id": condition_id,
                "metrics": metric_results,
                "exact_failure_count": 0,
            }
        )
    if negative:
        metric_id = REQUIRED_METRICS[0]
        results[-1]["metrics"][metric_id]["sensitivity_max"] = margins[metric_id][
            "margin"
        ]
    return {
        "schema_version": ("sporespore_mujoco_warp_equivalence_calibration_summary_v1"),
        "plan_sha256": plan_receipt["plan_sha256"],
        "fixture_only": True,
        "condition_results": results,
        "heldout_results_observed": False,
        "world_build_count": 0,
    }


def _expect_error(callback: Callable[[], object], expected_prefix: str) -> bool:
    try:
        callback()
    except CalibrationProtocolError as error:
        return str(error).startswith(expected_prefix)
    return False


def run_calibration_conformance() -> dict[str, Any]:
    contract = load_calibration_contract()
    cells: list[dict[str, Any]] = []
    cells.append(
        {
            "cell_id": "mjcal0_contract_and_predecessor_boundary",
            "passed": True,
            "contract_id": contract["contract_id"],
            "contract_raw_sha256": file_sha256(CONTRACT_PATH),
            "predecessor_contract_raw_sha256": contract["predecessor_boundary"][
                "supported_subset_contract_raw_sha256"
            ],
            "production_plan_exists": False,
            "world_build_count": 0,
            "physical_acceptance_authority": False,
        }
    )

    minimum = minimum_zero_exceedance_condition_count(0.95, 0.95)
    _require(minimum == 59, "MJCAL1_ADEQUACY", minimum)
    cells.append(
        {
            "cell_id": "mjcal1_adequacy_formula",
            "passed": True,
            "coverage_probability": 0.95,
            "confidence_probability": 0.95,
            "minimum_unique_condition_groups": minimum,
            "condition_level_familywise_outcome": True,
            "world_build_count": 0,
            "physical_acceptance_authority": False,
        }
    )

    plan = calibration_plan_fixture()
    first_plan = compile_calibration_plan(copy.deepcopy(plan))
    second_plan = compile_calibration_plan(copy.deepcopy(plan))
    _require(first_plan == second_plan, "MJCAL2_NONDETERMINISTIC")
    _require(
        first_plan["calibration_condition_count"] == 59
        and first_plan["heldout_condition_count"] == 59,
        "MJCAL2_COHORT_COUNTS",
    )
    cells.append(
        {
            "cell_id": "mjcal2_plan_compilation",
            "passed": True,
            "plan_sha256": first_plan["plan_sha256"],
            "calibration_condition_count": 59,
            "heldout_condition_count": 59,
            "metric_count": len(REQUIRED_METRICS),
            "world_build_count": 0,
            "physical_acceptance_authority": False,
        }
    )

    positive_summary = calibration_summary_fixture(first_plan)
    positive = compile_calibration_summary(first_plan, positive_summary)
    _require(
        positive["classification"]
        == "valid_complete_positive_resolvable_calibration_fixture"
        and positive["all_metrics_resolvable"] is True
        and positive["condition_count"] == 59,
        "MJCAL3_POSITIVE",
    )
    cells.append(
        {
            "cell_id": "mjcal3_positive_calibration_projection",
            "passed": True,
            "classification": positive["classification"],
            "condition_count": positive["condition_count"],
            "all_metrics_resolvable": True,
            "production_margin_authority": False,
            "world_build_count": 0,
            "physical_acceptance_authority": False,
        }
    )

    negative_summary = calibration_summary_fixture(first_plan, negative=True)
    negative = compile_calibration_summary(first_plan, negative_summary)
    _require(
        negative["classification"]
        == "valid_complete_negative_unresolvable_calibration_fixture"
        and negative["all_metrics_resolvable"] is False
        and negative["negative_result_retained"] is True,
        "MJCAL4_NEGATIVE",
    )
    cells.append(
        {
            "cell_id": "mjcal4_negative_calibration_retention",
            "passed": True,
            "classification": negative["classification"],
            "negative_result_retained": True,
            "margin_widened": False,
            "world_build_count": 0,
            "physical_acceptance_authority": False,
        }
    )

    heldout = compile_heldout_freeze_fixture(first_plan, positive)
    _require(
        heldout["heldout_condition_count"] == 59
        and heldout["production_freeze"] is False
        and heldout["heldout_execution_authorized"] is False,
        "MJCAL5_HELDOUT",
    )
    cells.append(
        {
            "cell_id": "mjcal5_disjoint_heldout_freeze",
            "passed": True,
            "heldout_condition_count": heldout["heldout_condition_count"],
            "heldout_results_observed": False,
            "production_freeze": False,
            "world_build_count": 0,
            "physical_acceptance_authority": False,
        }
    )

    mutations: dict[str, bool] = {}
    inadequate = copy.deepcopy(plan)
    inadequate["conditions"] = [
        condition
        for condition in inadequate["conditions"]
        if not (
            condition["cohort"] == "calibration"
            and condition["condition_id"].endswith("058")
        )
    ]
    mutations["inadequate_calibration_cohort"] = _expect_error(
        lambda: compile_calibration_plan(inadequate),
        "MJCAL_COHORT_INADEQUATE:",
    )
    duplicate_id = copy.deepcopy(plan)
    duplicate_id["conditions"][1]["condition_id"] = duplicate_id["conditions"][0][
        "condition_id"
    ]
    mutations["duplicate_condition_id"] = _expect_error(
        lambda: compile_calibration_plan(duplicate_id),
        "MJCAL_CONDITION_DUPLICATE:",
    )
    overlap = copy.deepcopy(plan)
    overlap["conditions"][59]["condition_id"] = overlap["conditions"][0]["condition_id"]
    mutations["calibration_heldout_overlap"] = _expect_error(
        lambda: compile_calibration_plan(overlap),
        "MJCAL_CONDITION_DUPLICATE:",
    )
    duplicate_seed = copy.deepcopy(plan)
    duplicate_seed["conditions"][59]["seed"] = duplicate_seed["conditions"][0]["seed"]
    mutations["duplicate_or_overlapping_seed"] = _expect_error(
        lambda: compile_calibration_plan(duplicate_seed),
        "MJCAL_CONDITION_SEED_DUPLICATE:",
    )
    partition_mutation = copy.deepcopy(plan)
    partition_mutation["population"]["partition_sha256"] = "sha256:" + "f" * 64
    mutations["partition_binding_mutation"] = _expect_error(
        lambda: compile_calibration_plan(partition_mutation),
        "MJCAL_PARTITION_BINDING:",
    )
    coverage_mutation = copy.deepcopy(plan)
    for condition in coverage_mutation["conditions"]:
        if condition["cohort"] == "calibration":
            condition["contact_regime"] = "free_flight"
    mutations["missing_factor_coverage"] = _expect_error(
        lambda: compile_calibration_plan(coverage_mutation),
        "MJCAL_COHORT_FACTOR_COVERAGE:",
    )
    outcome_leak = copy.deepcopy(plan)
    outcome_leak["conditions"][0]["outcome_exposed"] = True
    mutations["outcome_exposed_condition"] = _expect_error(
        lambda: compile_calibration_plan(outcome_leak),
        "MJCAL_CONDITION_OUTCOME_EXPOSED:",
    )
    training_leak = copy.deepcopy(plan)
    training_leak["conditions"][0]["training_data"] = True
    mutations["training_condition_leakage"] = _expect_error(
        lambda: compile_calibration_plan(training_leak),
        "MJCAL_CONDITION_TRAINING_LEAKAGE:",
    )
    widened = copy.deepcopy(plan)
    widened["metric_margins"][0]["margin"] *= 2.0
    mutations["margin_widened_beyond_semantic_ceiling"] = _expect_error(
        lambda: compile_calibration_plan(widened),
        "MJCAL_MARGIN_WIDENED:",
    )
    nonfinite_margin = copy.deepcopy(plan)
    nonfinite_margin["metric_margins"][0]["margin"] = float("nan")
    mutations["nonfinite_margin"] = _expect_error(
        lambda: compile_calibration_plan(nonfinite_margin),
        "MJCAL_MARGIN_VALUE:",
    )
    repeats = copy.deepcopy(plan)
    repeats["repeatability"]["fresh_process_repeats_per_runtime_condition"] = 2
    mutations["insufficient_fresh_process_repeats"] = _expect_error(
        lambda: compile_calibration_plan(repeats),
        "MJCAL_REPEATABILITY_INADEQUATE:",
    )
    sensitivity_roles = copy.deepcopy(plan)
    sensitivity_roles["numerical_sensitivity"]["perturbation_roles"] = [
        "unmodified_baseline"
    ]
    mutations["sensitivity_role_omission"] = _expect_error(
        lambda: compile_calibration_plan(sensitivity_roles),
        "MJCAL_SENSITIVITY_ROLES:",
    )
    heldout_leak = copy.deepcopy(positive_summary)
    heldout_leak["condition_results"][0]["condition_id"] = first_plan[
        "heldout_condition_ids"
    ][0]
    mutations["heldout_result_in_calibration"] = _expect_error(
        lambda: compile_calibration_summary(first_plan, heldout_leak),
        "MJCAL_SUMMARY_HELDOUT_CONDITION:",
    )
    nonfinite_result = copy.deepcopy(positive_summary)
    nonfinite_result["condition_results"][0]["metrics"][REQUIRED_METRICS[0]][
        "repeatability_max"
    ] = float("inf")
    mutations["nonfinite_calibration_result"] = _expect_error(
        lambda: compile_calibration_summary(first_plan, nonfinite_result),
        "MJCAL_REPEATABILITY_VALUE:",
    )
    incomplete_result = copy.deepcopy(positive_summary)
    incomplete_result["condition_results"].pop()
    mutations["incomplete_calibration_result"] = _expect_error(
        lambda: compile_calibration_summary(first_plan, incomplete_result),
        "MJCAL_SUMMARY_RESULT_COUNT:",
    )
    _require(all(mutations.values()), "MJCAL6_MUTATION_ACCEPTED", mutations)
    cells.append(
        {
            "cell_id": "mjcal6_mutation_and_leakage_controls",
            "passed": True,
            "rejected_mutations": mutations,
            "mutation_control_count": len(mutations),
            "world_build_count": 0,
            "physical_acceptance_authority": False,
        }
    )

    _require(
        all(
            receipt["world_build_count"] == 0
            and receipt["physical_acceptance_authority"] is False
            and receipt["release_authority"] is False
            for receipt in (first_plan, positive, negative, heldout)
        ),
        "MJCAL7_AUTHORITY",
    )
    cells.append(
        {
            "cell_id": "mjcal7_authority_boundary",
            "passed": True,
            "fixture_only": True,
            "production_plan_frozen": False,
            "calibration_executed": False,
            "production_margins_frozen": False,
            "heldout_execution_authorized": False,
            "training_plane_authorized": False,
            "scientific_result": False,
            "world_build_count": 0,
            "physical_acceptance_authority": False,
            "release_authority": False,
        }
    )

    return {
        "schema_version": REPORT_SCHEMA,
        "ok": True,
        "contract_id": contract["contract_id"],
        "contract_raw_sha256": file_sha256(CONTRACT_PATH),
        "source": _source_receipt(),
        "cells": cells,
        "passed_cells": len(cells),
        "failed_cells": 0,
        "minimum_unique_calibration_condition_groups": minimum,
        "minimum_unique_heldout_condition_groups": minimum,
        "metric_family_count": len(REQUIRED_METRICS),
        "mutation_control_count": len(mutations),
        "positive_and_negative_calibration_fixtures_retained": True,
        "fixture_only": True,
        "production_plan_frozen": False,
        "calibration_executed": False,
        "production_margins_frozen": False,
        "heldout_execution_authorized": False,
        "supported_physics_subset_qualified": False,
        "training_plane_authorized": False,
        "training_data_authority": False,
        "model_construction_count": 0,
        "step_invocation_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physics_state_modified": False,
        "scientific_result": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def _retain_report(report: dict[str, Any], path: Path) -> None:
    _require(path.name == "report.json", "MJCAL_REPORT_NAME")
    _require(not path.exists(), "MJCAL_REPORT_EXISTS", path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name("report.json.tmp")
    _require(not temporary.exists(), "MJCAL_REPORT_TEMP_EXISTS")
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
        report = run_calibration_conformance()
        if args.output is not None:
            _retain_report(report, args.output.resolve())
        print(json.dumps(report, sort_keys=True, allow_nan=False))
    except Exception as error:  # pragma: no cover - CLI terminal boundary
        print(f"MJCAL_CONFORMANCE_FAILURE {error}", file=sys.stderr)
        raise SystemExit(1) from error


if __name__ == "__main__":
    main()
