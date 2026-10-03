"""Pure zero-world MuJoCo-Warp calibration-plan and result compiler."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path
from typing import Any, Iterable


CONTRACT_PATH = Path(__file__).with_name(
    "mujoco_warp_equivalence_calibration_contract_v1.json"
)
REPO_ROOT = CONTRACT_PATH.parents[2]

CONTRACT_SCHEMA = "sporespore_mujoco_warp_equivalence_calibration_contract_v1"
PLAN_SCHEMA = "sporespore_mujoco_warp_equivalence_calibration_plan_v1"
SUMMARY_SCHEMA = "sporespore_mujoco_warp_equivalence_calibration_summary_v1"
PLAN_RECEIPT_SCHEMA = "sporespore_mujoco_warp_equivalence_calibration_plan_receipt_v1"
SUMMARY_RECEIPT_SCHEMA = (
    "sporespore_mujoco_warp_equivalence_calibration_summary_receipt_v1"
)
HELDOUT_FREEZE_SCHEMA = "sporespore_mujoco_warp_equivalence_heldout_freeze_fixture_v1"

REQUIRED_FACTOR_AXES = (
    "topology_bucket",
    "contact_regime",
    "material_profile",
    "horizon_steps",
)
REQUIRED_METRICS = (
    "one_step_state_linf_normalized",
    "one_step_actuator_linf_normalized",
    "bounded_horizon_pose_velocity_rms_normalized",
    "bounded_horizon_energy_relative_error",
    "contact_event_time_error_steps",
)
REQUIRED_EXACT_FAILURES = (
    "model_or_topology_identity_mismatch",
    "contact_body_pair_identity_mismatch",
    "nonfinite_state_or_metric",
    "solver_or_capacity_overflow",
    "missing_or_extra_step",
    "unsupported_feature_execution",
    "source_runtime_or_environment_mismatch",
)
REQUIRED_WARP_PLACEMENTS = (
    "single_world",
    "declared_batch_first_slot",
    "declared_batch_last_slot",
)
REQUIRED_SENSITIVITY_ROLES = (
    "nextafter_minus_one_representable_input_step",
    "unmodified_baseline",
    "nextafter_plus_one_representable_input_step",
)
ALLOWED_SEMANTIC_SOURCES = (
    "downstream_training_label_stability",
    "canonical_state_or_action_normalization_resolution",
    "safety_gate_guard_band",
    "contact_event_label_tolerance",
)


class CalibrationProtocolError(ValueError):
    """The prospective calibration protocol failed closed."""


def _require(condition: bool, code: str, detail: object = "") -> None:
    if not condition:
        raise CalibrationProtocolError(f"{code}:{detail}")


def _require_fields(value: dict[str, Any], expected: Iterable[str], code: str) -> None:
    expected_set = set(expected)
    actual_set = set(value)
    _require(
        actual_set == expected_set,
        code,
        {
            "missing": sorted(expected_set - actual_set),
            "extra": sorted(actual_set - expected_set),
        },
    )


def _finite_number(value: object, code: str) -> float:
    _require(
        isinstance(value, (int, float)) and not isinstance(value, bool),
        code,
        "not_numeric",
    )
    numeric = float(value)
    _require(math.isfinite(numeric), code, "not_finite")
    return numeric


def _positive_number(value: object, code: str) -> float:
    numeric = _finite_number(value, code)
    _require(numeric > 0.0, code, "not_positive")
    return numeric


def _positive_int(value: object, code: str) -> int:
    _require(
        isinstance(value, int) and not isinstance(value, bool) and value > 0,
        code,
        value,
    )
    return value


def _sha256_text(value: object, code: str) -> str:
    _require(isinstance(value, str), code, "not_string")
    _require(
        len(value) == 71
        and value.startswith("sha256:")
        and all(character in "0123456789abcdef" for character in value[7:]),
        code,
        value,
    )
    return value


def canonical_json_bytes(value: object) -> bytes:
    return json.dumps(
        value,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
        allow_nan=False,
    ).encode("utf-8")


def canonical_sha256(value: object) -> str:
    return "sha256:" + hashlib.sha256(canonical_json_bytes(value)).hexdigest()


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return f"sha256:{digest.hexdigest()}"


def minimum_zero_exceedance_condition_count(
    coverage_probability: float, confidence_probability: float
) -> int:
    coverage = _positive_number(coverage_probability, "MJCAL_ADEQUACY_COVERAGE")
    confidence = _positive_number(confidence_probability, "MJCAL_ADEQUACY_CONFIDENCE")
    _require(coverage < 1.0, "MJCAL_ADEQUACY_COVERAGE", coverage)
    _require(confidence < 1.0, "MJCAL_ADEQUACY_CONFIDENCE", confidence)
    return math.ceil(math.log1p(-confidence) / math.log(coverage))


def load_calibration_contract() -> dict[str, Any]:
    contract = json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))
    _require(
        contract.get("schema_version") == CONTRACT_SCHEMA,
        "MJCAL_CONTRACT_SCHEMA",
    )
    _require(
        contract.get("status")
        == "prospective_zero_world_protocol_source_only_production_plan_absent",
        "MJCAL_CONTRACT_STATUS",
    )
    _require(
        contract.get("question_class") == "development",
        "MJCAL_CONTRACT_QUESTION",
    )
    predecessor = contract["predecessor_boundary"]
    for path_key, hash_key in (
        ("supported_subset_contract_path", "supported_subset_contract_raw_sha256"),
        ("runtime_evidence_manifest_path", "runtime_evidence_manifest_raw_sha256"),
    ):
        relative = predecessor[path_key]
        _require(isinstance(relative, str), "MJCAL_PREDECESSOR_PATH", path_key)
        path = (REPO_ROOT / relative).resolve()
        _require(
            path.is_relative_to(REPO_ROOT.resolve()),
            "MJCAL_PREDECESSOR_ESCAPE",
            relative,
        )
        _require(path.is_file(), "MJCAL_PREDECESSOR_MISSING", relative)
        _require(
            file_sha256(path) == predecessor[hash_key],
            "MJCAL_PREDECESSOR_DIGEST",
            relative,
        )
    adequacy = contract["population_and_cohort_adequacy"]
    minimum = minimum_zero_exceedance_condition_count(
        adequacy["coverage_probability"],
        adequacy["confidence_probability"],
    )
    _require(minimum == 59, "MJCAL_ADEQUACY_EXPECTED", minimum)
    _require(
        adequacy["minimum_unique_calibration_condition_groups"] == minimum
        and adequacy["minimum_unique_heldout_condition_groups"] == minimum,
        "MJCAL_ADEQUACY_DECLARATION",
    )
    _require(
        tuple(contract["production_plan_requirements"]["required_factor_axes"])
        == REQUIRED_FACTOR_AXES,
        "MJCAL_FACTOR_AXES",
    )
    _require(
        tuple(metric["metric_id"] for metric in contract["required_metric_families"])
        == REQUIRED_METRICS,
        "MJCAL_METRIC_FAMILIES",
    )
    _require(
        tuple(contract["exact_failure_families"]) == REQUIRED_EXACT_FAILURES,
        "MJCAL_EXACT_FAILURE_FAMILIES",
    )
    _require(
        not contract["production_plan_requirements"]["production_plan_exists"]
        and not contract["production_plan_requirements"][
            "physical_calibration_series_open"
        ]
        and not contract["production_plan_requirements"][
            "heldout_qualification_series_open"
        ],
        "MJCAL_PRODUCTION_SERIES_OPEN",
    )
    _require(
        all(not bool(value) for value in contract["claims"].values()),
        "MJCAL_CONTRACT_CLAIM",
    )
    source = contract["source_conformance"]
    _require(
        source["fixture_only"]
        and source["model_construction_count"] == 0
        and source["step_invocation_count"] == 0
        and source["world_attempt_count"] == 0
        and source["world_build_count"] == 0
        and not source["physics_state_modified"],
        "MJCAL_ZERO_WORLD_BOUNDARY",
    )
    return contract


_PLAN_FIELDS = (
    "schema_version",
    "plan_id",
    "contract_raw_sha256",
    "question_class",
    "fixture_only",
    "population",
    "factor_levels",
    "conditions",
    "metric_margins",
    "repeatability",
    "numerical_sensitivity",
    "exact_failure_families",
    "physical_series_open",
    "world_build_count",
)
_POPULATION_FIELDS = (
    "population_id",
    "generator_sha256",
    "partition_sha256",
    "scope_statement",
    "exchangeability_argument",
    "coverage_probability",
    "confidence_probability",
    "population_claim_scope",
)
_CONDITION_FIELDS = (
    "condition_id",
    "cohort",
    "seed",
    "topology_bucket",
    "contact_regime",
    "material_profile",
    "horizon_steps",
    "outcome_exposed",
    "training_data",
)
_MARGIN_FIELDS = (
    "metric_id",
    "margin",
    "unit",
    "semantic_ceiling",
    "semantic_source",
    "provenance_reference",
    "chosen_before_calibration_outcomes",
)
_REPEATABILITY_FIELDS = (
    "fresh_process_repeats_per_runtime_condition",
    "warp_placement_modes",
    "selective_repeat_discard_or_replacement_permitted",
)
_SENSITIVITY_FIELDS = (
    "perturbation_roles",
    "effective_input_dtype_observed",
    "fields_axes_and_order_frozen_before_results",
    "outcome_selected_field_or_axis_permitted",
)


def _validate_factor_levels(value: object) -> dict[str, tuple[object, ...]]:
    _require(isinstance(value, dict), "MJCAL_FACTOR_LEVELS_TYPE")
    _require_fields(value, REQUIRED_FACTOR_AXES, "MJCAL_FACTOR_LEVELS_FIELDS")
    result: dict[str, tuple[object, ...]] = {}
    for axis in REQUIRED_FACTOR_AXES:
        levels = value[axis]
        _require(isinstance(levels, list), "MJCAL_FACTOR_LEVELS_LIST", axis)
        _require(len(levels) > 0, "MJCAL_FACTOR_LEVELS_EMPTY", axis)
        canonical_levels = [canonical_json_bytes(level) for level in levels]
        _require(
            len(set(canonical_levels)) == len(levels),
            "MJCAL_FACTOR_LEVEL_DUPLICATE",
            axis,
        )
        if axis == "horizon_steps":
            for level in levels:
                _positive_int(level, "MJCAL_HORIZON_LEVEL")
        else:
            for level in levels:
                _require(
                    isinstance(level, str) and bool(level),
                    "MJCAL_FACTOR_LEVEL_VALUE",
                    axis,
                )
        result[axis] = tuple(levels)
    return result


def compile_calibration_plan(plan: dict[str, Any]) -> dict[str, Any]:
    contract = load_calibration_contract()
    _require(isinstance(plan, dict), "MJCAL_PLAN_TYPE")
    _require_fields(plan, _PLAN_FIELDS, "MJCAL_PLAN_FIELDS")
    _require(plan["schema_version"] == PLAN_SCHEMA, "MJCAL_PLAN_SCHEMA")
    _require(
        isinstance(plan["plan_id"], str) and bool(plan["plan_id"]),
        "MJCAL_PLAN_ID",
    )
    expected_contract_sha = file_sha256(CONTRACT_PATH)
    _require(
        _sha256_text(plan["contract_raw_sha256"], "MJCAL_PLAN_CONTRACT_SHA")
        == expected_contract_sha,
        "MJCAL_PLAN_CONTRACT_BINDING",
    )
    _require(plan["question_class"] == "development", "MJCAL_PLAN_QUESTION")
    _require(plan["fixture_only"] is True, "MJCAL_PLAN_FIXTURE_ONLY")

    population = plan["population"]
    _require(isinstance(population, dict), "MJCAL_POPULATION_TYPE")
    _require_fields(population, _POPULATION_FIELDS, "MJCAL_POPULATION_FIELDS")
    for field in ("population_id", "scope_statement", "exchangeability_argument"):
        _require(
            isinstance(population[field], str) and len(population[field]) >= 16,
            "MJCAL_POPULATION_TEXT",
            field,
        )
    _sha256_text(population["generator_sha256"], "MJCAL_GENERATOR_SHA")
    _sha256_text(population["partition_sha256"], "MJCAL_PARTITION_SHA")
    coverage = _finite_number(population["coverage_probability"], "MJCAL_PLAN_COVERAGE")
    confidence = _finite_number(
        population["confidence_probability"], "MJCAL_PLAN_CONFIDENCE"
    )
    contract_adequacy = contract["population_and_cohort_adequacy"]
    _require(
        coverage == contract_adequacy["coverage_probability"]
        and confidence == contract_adequacy["confidence_probability"],
        "MJCAL_PLAN_ADEQUACY_PROBABILITY",
    )
    _require(
        population["population_claim_scope"] == "declared_generator_population_only",
        "MJCAL_PLAN_POPULATION_SCOPE",
    )
    minimum = minimum_zero_exceedance_condition_count(coverage, confidence)

    factor_levels = _validate_factor_levels(plan["factor_levels"])
    conditions = plan["conditions"]
    _require(isinstance(conditions, list), "MJCAL_CONDITIONS_TYPE")
    ids: set[str] = set()
    seeds: set[int] = set()
    cohort_ids: dict[str, list[str]] = {"calibration": [], "heldout": []}
    cohort_seeds: dict[str, set[int]] = {"calibration": set(), "heldout": set()}
    coverage_by_cohort: dict[str, dict[str, set[bytes]]] = {
        cohort: {axis: set() for axis in REQUIRED_FACTOR_AXES} for cohort in cohort_ids
    }
    for condition in conditions:
        _require(isinstance(condition, dict), "MJCAL_CONDITION_TYPE")
        _require_fields(condition, _CONDITION_FIELDS, "MJCAL_CONDITION_FIELDS")
        condition_id = condition["condition_id"]
        _require(
            isinstance(condition_id, str) and bool(condition_id),
            "MJCAL_CONDITION_ID",
        )
        _require(condition_id not in ids, "MJCAL_CONDITION_DUPLICATE", condition_id)
        ids.add(condition_id)
        cohort = condition["cohort"]
        _require(cohort in cohort_ids, "MJCAL_CONDITION_COHORT", cohort)
        seed = _positive_int(condition["seed"], "MJCAL_CONDITION_SEED")
        _require(seed not in seeds, "MJCAL_CONDITION_SEED_DUPLICATE", seed)
        seeds.add(seed)
        cohort_ids[cohort].append(condition_id)
        cohort_seeds[cohort].add(seed)
        _require(
            condition["outcome_exposed"] is False,
            "MJCAL_CONDITION_OUTCOME_EXPOSED",
            condition_id,
        )
        _require(
            condition["training_data"] is False,
            "MJCAL_CONDITION_TRAINING_LEAKAGE",
            condition_id,
        )
        for axis in REQUIRED_FACTOR_AXES:
            value = condition[axis]
            _require(
                value in factor_levels[axis],
                "MJCAL_CONDITION_FACTOR",
                {"condition": condition_id, "axis": axis, "value": value},
            )
            coverage_by_cohort[cohort][axis].add(canonical_json_bytes(value))
    for cohort, cohort_condition_ids in cohort_ids.items():
        _require(
            len(cohort_condition_ids) >= minimum,
            "MJCAL_COHORT_INADEQUATE",
            {"cohort": cohort, "count": len(cohort_condition_ids)},
        )
        for axis in REQUIRED_FACTOR_AXES:
            expected_levels = {
                canonical_json_bytes(level) for level in factor_levels[axis]
            }
            _require(
                coverage_by_cohort[cohort][axis] == expected_levels,
                "MJCAL_COHORT_FACTOR_COVERAGE",
                {"cohort": cohort, "axis": axis},
            )
    _require(
        cohort_seeds["calibration"].isdisjoint(cohort_seeds["heldout"]),
        "MJCAL_COHORT_SEED_OVERLAP",
    )
    expected_partition_sha = canonical_sha256(
        {
            "factor_levels": plan["factor_levels"],
            "conditions": conditions,
        }
    )
    _require(
        population["partition_sha256"] == expected_partition_sha,
        "MJCAL_PARTITION_BINDING",
    )

    margins = plan["metric_margins"]
    _require(isinstance(margins, list), "MJCAL_MARGINS_TYPE")
    _require(len(margins) == len(REQUIRED_METRICS), "MJCAL_MARGIN_COUNT")
    compiled_margins: dict[str, dict[str, Any]] = {}
    for item in margins:
        _require(isinstance(item, dict), "MJCAL_MARGIN_TYPE")
        _require_fields(item, _MARGIN_FIELDS, "MJCAL_MARGIN_FIELDS")
        metric_id = item["metric_id"]
        _require(metric_id in REQUIRED_METRICS, "MJCAL_MARGIN_METRIC", metric_id)
        _require(metric_id not in compiled_margins, "MJCAL_MARGIN_DUPLICATE", metric_id)
        margin = _positive_number(item["margin"], "MJCAL_MARGIN_VALUE")
        ceiling = _positive_number(item["semantic_ceiling"], "MJCAL_SEMANTIC_CEILING")
        _require(margin <= ceiling, "MJCAL_MARGIN_WIDENED", metric_id)
        _require(
            item["semantic_source"] in ALLOWED_SEMANTIC_SOURCES,
            "MJCAL_MARGIN_SOURCE",
            metric_id,
        )
        _require(
            isinstance(item["provenance_reference"], str)
            and len(item["provenance_reference"]) >= 16,
            "MJCAL_MARGIN_PROVENANCE",
            metric_id,
        )
        _require(
            item["chosen_before_calibration_outcomes"] is True,
            "MJCAL_MARGIN_POST_OUTCOME",
            metric_id,
        )
        _require(
            isinstance(item["unit"], str) and bool(item["unit"]),
            "MJCAL_MARGIN_UNIT",
            metric_id,
        )
        compiled_margins[metric_id] = {
            "margin": margin,
            "semantic_ceiling": ceiling,
            "unit": item["unit"],
            "semantic_source": item["semantic_source"],
            "provenance_reference": item["provenance_reference"],
        }
    _require(
        tuple(item["metric_id"] for item in margins) == REQUIRED_METRICS,
        "MJCAL_MARGIN_ORDER",
    )

    repeatability = plan["repeatability"]
    _require(isinstance(repeatability, dict), "MJCAL_REPEATABILITY_TYPE")
    _require_fields(repeatability, _REPEATABILITY_FIELDS, "MJCAL_REPEATABILITY_FIELDS")
    _require(
        _positive_int(
            repeatability["fresh_process_repeats_per_runtime_condition"],
            "MJCAL_REPEATABILITY_COUNT",
        )
        >= contract["repeatability_protocol"][
            "fresh_process_repeats_per_runtime_condition_minimum"
        ],
        "MJCAL_REPEATABILITY_INADEQUATE",
    )
    _require(
        tuple(repeatability["warp_placement_modes"]) == REQUIRED_WARP_PLACEMENTS,
        "MJCAL_REPEATABILITY_PLACEMENTS",
    )
    _require(
        repeatability["selective_repeat_discard_or_replacement_permitted"] is False,
        "MJCAL_REPEATABILITY_SELECTION",
    )

    sensitivity = plan["numerical_sensitivity"]
    _require(isinstance(sensitivity, dict), "MJCAL_SENSITIVITY_TYPE")
    _require_fields(sensitivity, _SENSITIVITY_FIELDS, "MJCAL_SENSITIVITY_FIELDS")
    _require(
        tuple(sensitivity["perturbation_roles"]) == REQUIRED_SENSITIVITY_ROLES,
        "MJCAL_SENSITIVITY_ROLES",
    )
    _require(
        sensitivity["effective_input_dtype_observed"] is True
        and sensitivity["fields_axes_and_order_frozen_before_results"] is True
        and sensitivity["outcome_selected_field_or_axis_permitted"] is False,
        "MJCAL_SENSITIVITY_BOUNDARY",
    )
    _require(
        tuple(plan["exact_failure_families"]) == REQUIRED_EXACT_FAILURES,
        "MJCAL_PLAN_EXACT_FAILURES",
    )
    _require(plan["physical_series_open"] is False, "MJCAL_PLAN_PHYSICAL_OPEN")
    _require(plan["world_build_count"] == 0, "MJCAL_PLAN_WORLD_COUNT")

    plan_sha = canonical_sha256(plan)
    return {
        "schema_version": PLAN_RECEIPT_SCHEMA,
        "ok": True,
        "fixture_only": True,
        "plan_id": plan["plan_id"],
        "plan_sha256": plan_sha,
        "contract_raw_sha256": expected_contract_sha,
        "population_id": population["population_id"],
        "generator_sha256": population["generator_sha256"],
        "partition_sha256": expected_partition_sha,
        "coverage_probability": coverage,
        "confidence_probability": confidence,
        "minimum_condition_groups": minimum,
        "calibration_condition_ids": tuple(cohort_ids["calibration"]),
        "heldout_condition_ids": tuple(cohort_ids["heldout"]),
        "calibration_condition_count": len(cohort_ids["calibration"]),
        "heldout_condition_count": len(cohort_ids["heldout"]),
        "factor_levels_sha256": canonical_sha256(plan["factor_levels"]),
        "metric_margins": compiled_margins,
        "exact_failure_families": REQUIRED_EXACT_FAILURES,
        "production_plan": False,
        "calibration_executed": False,
        "margins_frozen_for_production": False,
        "heldout_execution_authorized": False,
        "model_construction_count": 0,
        "step_invocation_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "scientific_result": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


_SUMMARY_FIELDS = (
    "schema_version",
    "plan_sha256",
    "fixture_only",
    "condition_results",
    "heldout_results_observed",
    "world_build_count",
)
_CONDITION_RESULT_FIELDS = (
    "condition_id",
    "metrics",
    "exact_failure_count",
)
_METRIC_RESULT_FIELDS = (
    "repeatability_max",
    "sensitivity_max",
)


def compile_calibration_summary(
    plan_receipt: dict[str, Any], summary: dict[str, Any]
) -> dict[str, Any]:
    _require(
        plan_receipt.get("schema_version") == PLAN_RECEIPT_SCHEMA
        and plan_receipt.get("ok") is True,
        "MJCAL_SUMMARY_PLAN_RECEIPT",
    )
    _require(isinstance(summary, dict), "MJCAL_SUMMARY_TYPE")
    _require_fields(summary, _SUMMARY_FIELDS, "MJCAL_SUMMARY_FIELDS")
    _require(summary["schema_version"] == SUMMARY_SCHEMA, "MJCAL_SUMMARY_SCHEMA")
    _require(
        summary["plan_sha256"] == plan_receipt["plan_sha256"],
        "MJCAL_SUMMARY_PLAN_BINDING",
    )
    _require(summary["fixture_only"] is True, "MJCAL_SUMMARY_FIXTURE_ONLY")
    _require(
        summary["heldout_results_observed"] is False,
        "MJCAL_SUMMARY_HELDOUT_LEAKAGE",
    )
    _require(summary["world_build_count"] == 0, "MJCAL_SUMMARY_WORLD_COUNT")
    results = summary["condition_results"]
    _require(isinstance(results, list), "MJCAL_SUMMARY_RESULTS_TYPE")
    expected_ids = tuple(plan_receipt["calibration_condition_ids"])
    _require(len(results) == len(expected_ids), "MJCAL_SUMMARY_RESULT_COUNT")
    upper_bounds = {
        metric_id: {"repeatability": 0.0, "sensitivity": 0.0}
        for metric_id in REQUIRED_METRICS
    }
    complete_ids: list[str] = []
    exact_failure_total = 0
    for result in results:
        _require(isinstance(result, dict), "MJCAL_SUMMARY_RESULT_TYPE")
        _require_fields(result, _CONDITION_RESULT_FIELDS, "MJCAL_SUMMARY_RESULT_FIELDS")
        condition_id = result["condition_id"]
        _require(
            condition_id not in plan_receipt["heldout_condition_ids"],
            "MJCAL_SUMMARY_HELDOUT_CONDITION",
            condition_id,
        )
        complete_ids.append(condition_id)
        failures = result["exact_failure_count"]
        _require(
            isinstance(failures, int)
            and not isinstance(failures, bool)
            and failures >= 0,
            "MJCAL_SUMMARY_FAILURE_COUNT",
            condition_id,
        )
        exact_failure_total += failures
        metrics = result["metrics"]
        _require(isinstance(metrics, dict), "MJCAL_SUMMARY_METRICS_TYPE")
        _require_fields(metrics, REQUIRED_METRICS, "MJCAL_SUMMARY_METRIC_IDS")
        for metric_id in REQUIRED_METRICS:
            values = metrics[metric_id]
            _require(isinstance(values, dict), "MJCAL_SUMMARY_METRIC_TYPE")
            _require_fields(
                values, _METRIC_RESULT_FIELDS, "MJCAL_SUMMARY_METRIC_FIELDS"
            )
            repeatability = _finite_number(
                values["repeatability_max"], "MJCAL_REPEATABILITY_VALUE"
            )
            sensitivity = _finite_number(
                values["sensitivity_max"], "MJCAL_SENSITIVITY_VALUE"
            )
            _require(
                repeatability >= 0.0 and sensitivity >= 0.0,
                "MJCAL_SUMMARY_NEGATIVE_VALUE",
                metric_id,
            )
            upper_bounds[metric_id]["repeatability"] = max(
                upper_bounds[metric_id]["repeatability"], repeatability
            )
            upper_bounds[metric_id]["sensitivity"] = max(
                upper_bounds[metric_id]["sensitivity"], sensitivity
            )
    _require(tuple(complete_ids) == expected_ids, "MJCAL_SUMMARY_ORDER_OR_ID")

    resolutions: dict[str, dict[str, Any]] = {}
    all_resolvable = exact_failure_total == 0
    for metric_id in REQUIRED_METRICS:
        observed = max(upper_bounds[metric_id].values())
        margin = plan_receipt["metric_margins"][metric_id]["margin"]
        resolvable = observed < margin
        all_resolvable = all_resolvable and resolvable
        resolutions[metric_id] = {
            "repeatability_upper_tolerance_bound": upper_bounds[metric_id][
                "repeatability"
            ],
            "sensitivity_upper_tolerance_bound": upper_bounds[metric_id]["sensitivity"],
            "calibration_upper_tolerance_bound": observed,
            "predeclared_margin": margin,
            "resolvable": resolvable,
        }
    classification = (
        "valid_complete_positive_resolvable_calibration_fixture"
        if all_resolvable
        else "valid_complete_negative_unresolvable_calibration_fixture"
    )
    return {
        "schema_version": SUMMARY_RECEIPT_SCHEMA,
        "ok": True,
        "fixture_only": True,
        "classification": classification,
        "plan_sha256": plan_receipt["plan_sha256"],
        "summary_sha256": canonical_sha256(summary),
        "condition_count": len(results),
        "minimum_condition_groups": plan_receipt["minimum_condition_groups"],
        "condition_order_sha256": canonical_sha256(complete_ids),
        "exact_failure_count": exact_failure_total,
        "metric_resolution": resolutions,
        "all_metrics_resolvable": all_resolvable,
        "negative_result_retained": not all_resolvable,
        "production_margin_authority": False,
        "heldout_execution_authorized": False,
        "model_construction_count": 0,
        "step_invocation_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "scientific_result": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def compile_heldout_freeze_fixture(
    plan_receipt: dict[str, Any], summary_receipt: dict[str, Any]
) -> dict[str, Any]:
    _require(
        plan_receipt.get("schema_version") == PLAN_RECEIPT_SCHEMA
        and plan_receipt.get("fixture_only") is True,
        "MJCAL_HELDOUT_PLAN_RECEIPT",
    )
    _require(
        summary_receipt.get("schema_version") == SUMMARY_RECEIPT_SCHEMA
        and summary_receipt.get("fixture_only") is True
        and summary_receipt.get("plan_sha256") == plan_receipt["plan_sha256"],
        "MJCAL_HELDOUT_SUMMARY_RECEIPT",
    )
    _require(
        summary_receipt.get("all_metrics_resolvable") is True,
        "MJCAL_HELDOUT_UNRESOLVABLE",
    )
    calibration_ids = set(plan_receipt["calibration_condition_ids"])
    heldout_ids = tuple(plan_receipt["heldout_condition_ids"])
    _require(
        calibration_ids.isdisjoint(heldout_ids),
        "MJCAL_HELDOUT_ID_OVERLAP",
    )
    _require(
        len(heldout_ids) >= plan_receipt["minimum_condition_groups"],
        "MJCAL_HELDOUT_INADEQUATE",
    )
    return {
        "schema_version": HELDOUT_FREEZE_SCHEMA,
        "ok": True,
        "fixture_only": True,
        "plan_sha256": plan_receipt["plan_sha256"],
        "calibration_summary_sha256": summary_receipt["summary_sha256"],
        "heldout_condition_count": len(heldout_ids),
        "heldout_condition_ids_sha256": canonical_sha256(heldout_ids),
        "metric_margins_sha256": canonical_sha256(plan_receipt["metric_margins"]),
        "production_freeze": False,
        "heldout_results_observed": False,
        "heldout_execution_authorized": False,
        "model_construction_count": 0,
        "step_invocation_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "scientific_result": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
