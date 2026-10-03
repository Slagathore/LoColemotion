"""Pure zero-world compiler and fixture evaluator for MuJoCo-Warp metrics."""

from __future__ import annotations

import json
import math
from collections.abc import Iterable, Mapping, Sequence
from pathlib import Path
from typing import Any

from .mujoco_warp_equivalence_calibration import (
    REQUIRED_METRICS,
    canonical_sha256,
    file_sha256,
)


CONTRACT_PATH = Path(__file__).with_name(
    "mujoco_warp_metric_semantics_contract_v1.json"
)
REPO_ROOT = CONTRACT_PATH.parents[2]

CONTRACT_SCHEMA = "sporespore_mujoco_warp_metric_semantics_contract_v1"
SUITE_SCHEMA = "sporespore_mujoco_warp_metric_semantics_suite_v1"
TRACE_SCHEMA = "sporespore_mujoco_warp_metric_fixture_trace_v1"
INVENTORY_SCHEMA = "sporespore_mujoco_warp_metric_semantics_inventory_v1"
EVALUATION_SCHEMA = "sporespore_mujoco_warp_metric_fixture_evaluation_v1"

EXPECTED_UNITS = {
    "one_step_state_linf_normalized": "normalized_ratio",
    "one_step_actuator_linf_normalized": "normalized_ratio",
    "bounded_horizon_pose_velocity_rms_normalized": "normalized_ratio",
    "bounded_horizon_energy_relative_error": "relative_ratio",
    "contact_event_time_error_steps": "step",
}
EXPECTED_KINDS = {
    metric_id: (
        "discrete_smaller_is_better"
        if metric_id == "contact_event_time_error_steps"
        else "continuous_smaller_is_better"
    )
    for metric_id in REQUIRED_METRICS
}
EXPECTED_METRIC_FORMULAS = {
    "one_step_state_linf_normalized": {
        "source_registry": "state_components",
        "sample_population": "one_step_observation_index_only",
        "component_error": (
            "value_kind_error_divided_by_component_normalization_scale"
        ),
        "aggregation": "maximum_over_ordered_components",
    },
    "one_step_actuator_linf_normalized": {
        "source_registry": "actuator_components",
        "sample_population": "one_step_observation_index_only",
        "component_error": (
            "value_kind_error_divided_by_component_normalization_scale"
        ),
        "aggregation": "maximum_over_ordered_components",
    },
    "bounded_horizon_pose_velocity_rms_normalized": {
        "source_registry": "pose_velocity_components",
        "sample_population": (
            "cartesian_product_steps_1_through_h_inclusive_and_ordered_components"
        ),
        "component_error": (
            "value_kind_error_divided_by_component_normalization_scale"
        ),
        "aggregation": ("sqrt_sum_squared_errors_divided_by_h_times_component_count"),
    },
    "bounded_horizon_energy_relative_error": {
        "source_field": "energy_j",
        "sample_population": "steps_1_through_h_inclusive",
        "per_step_error": (
            "abs_cpu_reference_minus_warp_candidate_divided_by_"
            "max_abs_cpu_reference_and_positive_floor"
        ),
        "aggregation": "sqrt_sum_squared_errors_divided_by_h",
    },
    "contact_event_time_error_steps": {
        "source_field": "contact_events",
        "sample_population": "exactly_matched_event_identities",
        "per_event_error": ("absolute_cpu_reference_step_minus_warp_candidate_step"),
        "aggregation": "maximum_or_exact_zero_for_empty_matched_set",
        "identity_or_count_mismatch": ("exact_failure_without_numeric_substitution"),
    },
}
EXPECTED_CELLS = (
    "mjms0_contract_and_predecessor_boundary",
    "mjms1_current_incomplete_inventory",
    "mjms2_fixture_suite_compilation",
    "mjms3_positive_fixture_evaluation",
    "mjms4_component_and_normalization_controls",
    "mjms5_trace_and_horizon_controls",
    "mjms6_energy_contact_and_failure_controls",
    "mjms7_authority_boundary",
)

_SUITE_FIELDS = (
    "schema_version",
    "suite_id",
    "contract_raw_sha256",
    "fixture_only",
    "step_index_origin",
    "one_step_observation_index",
    "bounded_horizon_inclusion",
    "state_components",
    "actuator_components",
    "pose_velocity_components",
    "energy_semantics",
    "contact_event_semantics",
    "production_metric_semantics_complete",
    "model_construction_count",
    "step_invocation_count",
    "world_attempt_count",
    "world_build_count",
    "physics_state_modified",
    "scientific_result",
    "physical_acceptance_authority",
    "release_authority",
)
_COMPONENT_FIELDS = (
    "component_id",
    "quantity",
    "unit",
    "value_kind",
    "error_unit",
    "normalization_scale",
    "normalization_source",
    "provenance_reference",
    "adequacy_argument",
    "chosen_before_outcomes",
    "population_scope",
    "broader_population_claim",
)
_ENERGY_FIELDS = (
    "observable",
    "reference_role",
    "denominator_rule",
    "denominator_floor_j",
    "denominator_floor_provenance",
    "adequacy_argument",
    "aggregation",
    "chosen_before_outcomes",
    "population_scope",
    "broader_population_claim",
)
_CONTACT_FIELDS = (
    "identity_fields",
    "event_kinds",
    "matching_rule",
    "event_order",
    "occurrence_indexing",
    "aggregation",
    "empty_matched_event_set_value_steps",
    "mismatch_disposition",
    "adequacy_argument",
    "chosen_before_outcomes",
    "population_scope",
    "broader_population_claim",
)
_TRACE_FIELDS = (
    "schema_version",
    "trace_id",
    "suite_sha256",
    "runtime_role",
    "horizon_steps",
    "samples",
    "contact_events",
    "exact_failure_count",
    "fixture_only",
    "model_construction_count",
    "step_invocation_count",
    "world_attempt_count",
    "world_build_count",
    "physics_state_modified",
)
_SAMPLE_FIELDS = (
    "step_index",
    "state",
    "actuator",
    "pose_velocity",
    "energy_j",
)
_EVENT_FIELDS = (
    "body_pair_id",
    "event_kind",
    "occurrence_index",
    "step_index",
)


class MetricSemanticsError(ValueError):
    """Metric semantics or fixture trace failed closed."""


def _require(condition: bool, code: str, detail: object = "") -> None:
    if not condition:
        raise MetricSemanticsError(f"{code}:{detail}")


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


def _nonempty_string(value: object, code: str, minimum: int = 1) -> str:
    _require(
        isinstance(value, str) and len(value.strip()) >= minimum,
        code,
        value,
    )
    return value


def _finite_number(value: object, code: str) -> float:
    _require(
        isinstance(value, (int, float)) and not isinstance(value, bool),
        code,
        "not_numeric",
    )
    numeric = float(value)
    _require(math.isfinite(numeric), code, value)
    return numeric


def _positive_number(value: object, code: str) -> float:
    numeric = _finite_number(value, code)
    _require(numeric > 0.0, code, value)
    return numeric


def _nonnegative_int(value: object, code: str) -> int:
    _require(
        isinstance(value, int) and not isinstance(value, bool) and value >= 0,
        code,
        value,
    )
    return value


def _positive_int(value: object, code: str) -> int:
    result = _nonnegative_int(value, code)
    _require(result > 0, code, value)
    return result


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


def _safe_repo_path(value: object) -> str:
    path = _nonempty_string(value, "MJMS_PREDECESSOR_PATH")
    candidate = Path(path)
    _require(not candidate.is_absolute(), "MJMS_PREDECESSOR_PATH_ABSOLUTE", path)
    _require(".." not in candidate.parts, "MJMS_PREDECESSOR_PATH_ESCAPE", path)
    _require(path.replace("\\", "/") == path, "MJMS_PREDECESSOR_SEPARATOR", path)
    _require(path.startswith("sdk/"), "MJMS_PREDECESSOR_PREFIX", path)
    return path


def load_metric_semantics_contract() -> dict[str, Any]:
    contract = json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))
    _require(contract.get("schema_version") == CONTRACT_SCHEMA, "MJMS_CONTRACT_SCHEMA")
    _require(
        contract.get("contract_id")
        == "sporespore_mujoco_warp_precalibration_metric_semantics_readiness_v1",
        "MJMS_CONTRACT_ID",
    )
    _require(
        contract.get("status")
        == "zero_world_source_only_all_production_metric_semantics_unresolved",
        "MJMS_CONTRACT_STATUS",
    )
    _require(contract.get("question_class") == "development", "MJMS_QUESTION")

    predecessor = contract["predecessor_boundary"]
    for path_key, hash_key in (
        ("calibration_contract_path", "calibration_contract_raw_sha256"),
        (
            "semantic_ceiling_contract_path",
            "semantic_ceiling_contract_raw_sha256",
        ),
        (
            "semantic_ceiling_validation_manifest_path",
            "semantic_ceiling_validation_manifest_raw_sha256",
        ),
    ):
        relative = _safe_repo_path(predecessor[path_key])
        path = (REPO_ROOT / relative).resolve()
        _require(path.is_relative_to(REPO_ROOT.resolve()), "MJMS_PREDECESSOR_ESCAPE")
        _require(path.is_file(), "MJMS_PREDECESSOR_MISSING", relative)
        _require(
            file_sha256(path) == predecessor[hash_key],
            "MJMS_PREDECESSOR_DIGEST",
            relative,
        )
    semantic_manifest_path = (
        REPO_ROOT / predecessor["semantic_ceiling_validation_manifest_path"]
    ).resolve()
    semantic_manifest = json.loads(semantic_manifest_path.read_text(encoding="utf-8"))
    _require(
        semantic_manifest["schema_version"]
        == "sporespore_mujoco_warp_semantic_ceiling_readiness_validation_manifest_v1"
        and semantic_manifest["status"] == "accepted_zero_world_source_conformance"
        and semantic_manifest["question_class"] == "development"
        and semantic_manifest["source_commit"]
        == predecessor["semantic_ceiling_source_commit"]
        and semantic_manifest["source_clean"]
        and semantic_manifest["source_matches_origin_main"]
        and semantic_manifest["contract"]["git_blob_raw_sha256"]
        == predecessor["semantic_ceiling_contract_raw_sha256"]
        and semantic_manifest["contract"]["predecessor_contract_raw_sha256"]
        == predecessor["calibration_contract_raw_sha256"]
        and semantic_manifest["report"]["sha256"]
        == predecessor["semantic_ceiling_source_report_sha256"]
        and semantic_manifest["report"]["passed_cells"] == 8
        and semantic_manifest["report"]["failed_cells"] == 0
        and semantic_manifest["report"]["accepted_production_source_count"] == 0
        and semantic_manifest["report"]["unresolved_metric_count"]
        == len(REQUIRED_METRICS)
        and semantic_manifest["report"]["world_build_count"] == 0
        and not semantic_manifest["production_semantic_ceiling_sources_complete"]
        and not semantic_manifest["production_plan_frozen"]
        and not semantic_manifest["calibration_executed"]
        and not semantic_manifest["heldout_execution_authorized"]
        and not semantic_manifest["supported_physics_subset_qualified"]
        and not semantic_manifest["training_plane_authorized"]
        and not semantic_manifest["physical_acceptance_authority"]
        and not semantic_manifest["release_authority"],
        "MJMS_SEMANTIC_MANIFEST_BOUNDARY",
    )

    source_commit = _nonempty_string(
        predecessor["semantic_ceiling_source_commit"],
        "MJMS_SEMANTIC_SOURCE_COMMIT",
    )
    integration_commit = _nonempty_string(
        predecessor["semantic_ceiling_integration_commit"],
        "MJMS_SEMANTIC_INTEGRATION_COMMIT",
    )
    for label, commit in (
        ("source", source_commit),
        ("integration", integration_commit),
    ):
        _require(
            len(commit) == 40
            and all(character in "0123456789abcdef" for character in commit),
            "MJMS_PREDECESSOR_COMMIT",
            label,
        )
    _sha256_text(
        predecessor["semantic_ceiling_source_report_sha256"],
        "MJMS_SEMANTIC_REPORT_DIGEST",
    )

    integration_receipt_path = Path(
        _nonempty_string(
            predecessor["semantic_ceiling_integration_receipt_path"],
            "MJMS_SEMANTIC_INTEGRATION_RECEIPT_PATH",
        )
    )
    _require(
        integration_receipt_path.is_absolute() and integration_receipt_path.is_file(),
        "MJMS_SEMANTIC_INTEGRATION_RECEIPT_MISSING",
        integration_receipt_path,
    )
    _require(
        integration_receipt_path.stat().st_size
        == predecessor["semantic_ceiling_integration_receipt_byte_length"]
        and file_sha256(integration_receipt_path)
        == _sha256_text(
            predecessor["semantic_ceiling_integration_receipt_sha256"],
            "MJMS_SEMANTIC_INTEGRATION_RECEIPT_DIGEST",
        ),
        "MJMS_SEMANTIC_INTEGRATION_RECEIPT_BINDING",
    )
    integration_receipt = json.loads(
        integration_receipt_path.read_text(encoding="utf-8")
    )
    _require(
        integration_receipt["schema_version"]
        == "sporespore_conformance_run_observation_v1"
        and integration_receipt["status"] == "passed"
        and integration_receipt["tier"] == "canonical_no_godot"
        and integration_receipt["skip_godot"] is True
        and integration_receipt["source"]["head"] == integration_commit
        and integration_receipt["source"]["origin_main"] == integration_commit
        and integration_receipt["source"]["worktree_clean"]
        and not integration_receipt["source"]["transitive_dependency_key_complete"]
        and not integration_receipt["cache"]["lookup_performed"]
        and not integration_receipt["cache"]["result_reused"]
        and not integration_receipt["cache"]["reuse_authority"]
        and all(not bool(value) for value in integration_receipt["claims"].values()),
        "MJMS_SEMANTIC_INTEGRATION_RECEIPT_BOUNDARY",
    )
    _require(
        predecessor["accepted_production_semantic_ceiling_source_count"] == 0
        and not predecessor["production_semantic_ceiling_sources_complete"]
        and not predecessor["production_plan_exists"]
        and not predecessor["physical_calibration_series_open"]
        and not predecessor["heldout_qualification_series_open"],
        "MJMS_PREDECESSOR_AUTHORITY",
    )

    readiness = contract["required_metric_semantics"]
    _require(
        [item["metric_id"] for item in readiness] == list(REQUIRED_METRICS),
        "MJMS_METRIC_ORDER",
    )
    _require(
        {item["metric_id"]: item["unit"] for item in readiness} == EXPECTED_UNITS,
        "MJMS_METRIC_UNITS",
    )
    _require(
        {item["metric_id"]: item["kind"] for item in readiness} == EXPECTED_KINDS,
        "MJMS_METRIC_KINDS",
    )
    for item in readiness:
        _require(
            item["status"] == "unresolved_no_production_metric_definition",
            "MJMS_METRIC_STATUS",
            item["metric_id"],
        )
        _nonempty_string(item["required_definition"], "MJMS_METRIC_DEFINITION", 32)

    suite_contract = contract["metric_suite_contract"]
    _require(
        suite_contract["schema_version"] == SUITE_SCHEMA
        and suite_contract["fixture_only_positive_path"]
        and not suite_contract["production_suite_installation_permitted_by_this_gate"]
        and suite_contract["step_index_origin"] == 0
        and suite_contract["one_step_observation_index"] == 1
        and suite_contract["bounded_horizon_inclusion"]
        == "steps_1_through_h_inclusive",
        "MJMS_SUITE_CONTRACT",
    )
    _require(
        tuple(suite_contract["allowed_value_kinds"])
        == (
            "scalar_linear",
            "scalar_periodic_radians",
            "unit_quaternion_wxyz",
        ),
        "MJMS_VALUE_KINDS",
    )
    _require(
        suite_contract["periodic_error_rule"]
        == "absolute_shortest_arc_modulo_2pi_radians"
        and suite_contract["quaternion_input_rule"]
        == "finite_nonzero_wxyz_normalized_for_error"
        and suite_contract["quaternion_error_rule"]
        == "twice_arccos_absolute_normalized_dot_clamped_to_unit_interval"
        and suite_contract["quaternion_sign_is_invariant"]
        and suite_contract["raw_quaternion_norm_is_not_a_metric_component"]
        and suite_contract["component_order_is_hash_bound"]
        and suite_contract["normalization_source_and_provenance_required"]
        and suite_contract["normalization_adequacy_argument_required"]
        and suite_contract["normalization_chosen_before_outcomes_required"]
        and suite_contract["bounded_population_scope_required"]
        and not suite_contract["broader_population_claim_permitted"],
        "MJMS_COMPONENT_ERROR_CONTRACT",
    )
    _require(
        contract["metric_formula_contract"] == EXPECTED_METRIC_FORMULAS,
        "MJMS_METRIC_FORMULA_CONTRACT",
    )
    current = contract["current_inventory"]
    _require(
        current["required_metric_count"] == len(REQUIRED_METRICS)
        and current["production_metric_definition_count"] == 0
        and current["unresolved_metric_count"] == len(REQUIRED_METRICS)
        and not current["production_metric_semantics_complete"]
        and not current["production_semantic_ceiling_sources_complete"]
        and not current["production_plan_exists"]
        and not current["calibration_authorized"],
        "MJMS_CURRENT_INVENTORY",
    )
    source = contract["source_conformance"]
    _require(
        tuple(source["required_cells"]) == EXPECTED_CELLS
        and source["exact_mutation_control_count"] == 52
        and source["model_construction_count"] == 0
        and source["step_invocation_count"] == 0
        and source["world_attempt_count"] == 0
        and source["world_build_count"] == 0
        and not source["physics_state_modified"],
        "MJMS_ZERO_WORLD_BOUNDARY",
    )
    _require(
        all(not bool(value) for value in contract["claims"].values()),
        "MJMS_CONTRACT_CLAIM",
    )
    return contract


def _validate_component_registry(
    value: object,
    *,
    registry_name: str,
    allowed_value_kinds: tuple[str, ...],
) -> list[dict[str, Any]]:
    _require(isinstance(value, list) and len(value) > 0, "MJMS_COMPONENT_LIST")
    result: list[dict[str, Any]] = []
    seen: set[str] = set()
    for raw in value:
        _require(isinstance(raw, dict), "MJMS_COMPONENT_TYPE", registry_name)
        _require_fields(raw, _COMPONENT_FIELDS, "MJMS_COMPONENT_FIELDS")
        component_id = _nonempty_string(raw["component_id"], "MJMS_COMPONENT_ID")
        _require(component_id not in seen, "MJMS_COMPONENT_DUPLICATE", component_id)
        seen.add(component_id)
        quantity = _nonempty_string(raw["quantity"], "MJMS_COMPONENT_QUANTITY")
        unit = _nonempty_string(raw["unit"], "MJMS_COMPONENT_UNIT")
        value_kind = _nonempty_string(raw["value_kind"], "MJMS_COMPONENT_KIND")
        _require(value_kind in allowed_value_kinds, "MJMS_COMPONENT_KIND", value_kind)
        error_unit = _nonempty_string(raw["error_unit"], "MJMS_COMPONENT_ERROR_UNIT")
        if value_kind == "scalar_linear":
            _require(error_unit == unit, "MJMS_COMPONENT_LINEAR_UNIT", component_id)
        elif value_kind == "scalar_periodic_radians":
            _require(
                unit == "radian" and error_unit == "radian",
                "MJMS_COMPONENT_PERIODIC_UNIT",
                component_id,
            )
        else:
            _require(
                unit == "unit_quaternion" and error_unit == "radian",
                "MJMS_COMPONENT_QUATERNION_UNIT",
                component_id,
            )
        scale = _positive_number(raw["normalization_scale"], "MJMS_COMPONENT_SCALE")
        source = _nonempty_string(raw["normalization_source"], "MJMS_COMPONENT_SOURCE")
        provenance = _nonempty_string(
            raw["provenance_reference"], "MJMS_COMPONENT_PROVENANCE", 16
        )
        adequacy = _nonempty_string(
            raw["adequacy_argument"], "MJMS_COMPONENT_ADEQUACY", 32
        )
        _require(
            raw["chosen_before_outcomes"] is True,
            "MJMS_COMPONENT_POST_OUTCOME",
            component_id,
        )
        scope = _nonempty_string(raw["population_scope"], "MJMS_COMPONENT_SCOPE", 16)
        _require(
            raw["broader_population_claim"] is False,
            "MJMS_COMPONENT_BROAD_CLAIM",
            component_id,
        )
        result.append(
            {
                "component_id": component_id,
                "quantity": quantity,
                "unit": unit,
                "value_kind": value_kind,
                "error_unit": error_unit,
                "normalization_scale": scale,
                "normalization_source": source,
                "provenance_reference": provenance,
                "adequacy_argument": adequacy,
                "chosen_before_outcomes": True,
                "population_scope": scope,
                "broader_population_claim": False,
            }
        )
    return result


def _validate_energy_semantics(
    value: object, contract: dict[str, Any]
) -> dict[str, Any]:
    _require(isinstance(value, dict), "MJMS_ENERGY_TYPE")
    _require_fields(value, _ENERGY_FIELDS, "MJMS_ENERGY_FIELDS")
    energy_contract = contract["energy_semantics_contract"]
    _require(
        energy_contract["denominator_floor_j_must_be_finite_positive_and_provenanced"]
        and energy_contract["denominator_floor_adequacy_argument_required"]
        and not energy_contract[
            "outcome_selected_observable_floor_or_aggregation_permitted"
        ],
        "MJMS_ENERGY_CONTRACT",
    )
    observable = _nonempty_string(value["observable"], "MJMS_ENERGY_OBSERVABLE")
    _require(
        observable in energy_contract["allowed_observables"],
        "MJMS_ENERGY_OBSERVABLE",
        observable,
    )
    _require(
        value["reference_role"] == energy_contract["reference_role"]
        and value["denominator_rule"] == energy_contract["denominator_rule"]
        and value["aggregation"] == energy_contract["aggregation"],
        "MJMS_ENERGY_RULE",
    )
    floor = _positive_number(value["denominator_floor_j"], "MJMS_ENERGY_FLOOR")
    provenance = _nonempty_string(
        value["denominator_floor_provenance"], "MJMS_ENERGY_PROVENANCE", 16
    )
    adequacy = _nonempty_string(value["adequacy_argument"], "MJMS_ENERGY_ADEQUACY", 32)
    _require(value["chosen_before_outcomes"] is True, "MJMS_ENERGY_POST_OUTCOME")
    scope = _nonempty_string(value["population_scope"], "MJMS_ENERGY_SCOPE", 16)
    _require(value["broader_population_claim"] is False, "MJMS_ENERGY_BROAD_CLAIM")
    return {
        "observable": observable,
        "reference_role": energy_contract["reference_role"],
        "denominator_rule": energy_contract["denominator_rule"],
        "denominator_floor_j": floor,
        "denominator_floor_provenance": provenance,
        "adequacy_argument": adequacy,
        "aggregation": energy_contract["aggregation"],
        "chosen_before_outcomes": True,
        "population_scope": scope,
        "broader_population_claim": False,
    }


def _validate_contact_semantics(
    value: object, contract: dict[str, Any]
) -> dict[str, Any]:
    _require(isinstance(value, dict), "MJMS_CONTACT_TYPE")
    _require_fields(value, _CONTACT_FIELDS, "MJMS_CONTACT_FIELDS")
    expected = contract["contact_event_semantics_contract"]
    _require(
        expected["population_scope_adequacy_argument_required"]
        and not expected["outcome_selected_matching_or_remapping_permitted"],
        "MJMS_CONTACT_CONTRACT",
    )
    empty_value = _nonnegative_int(
        value["empty_matched_event_set_value_steps"], "MJMS_CONTACT_EMPTY_VALUE"
    )
    _require(
        tuple(value["identity_fields"]) == tuple(expected["identity_fields"])
        and tuple(value["event_kinds"]) == tuple(expected["allowed_event_kinds"])
        and value["matching_rule"] == expected["matching_rule"]
        and value["event_order"] == expected["event_order"]
        and value["occurrence_indexing"] == expected["occurrence_indexing"]
        and value["aggregation"] == expected["aggregation"]
        and empty_value == expected["empty_matched_event_set_value_steps"]
        and value["mismatch_disposition"]
        == expected["identity_or_count_mismatch_disposition"],
        "MJMS_CONTACT_RULE",
    )
    _require(value["chosen_before_outcomes"] is True, "MJMS_CONTACT_POST_OUTCOME")
    scope = _nonempty_string(value["population_scope"], "MJMS_CONTACT_SCOPE", 16)
    adequacy = _nonempty_string(value["adequacy_argument"], "MJMS_CONTACT_ADEQUACY", 32)
    _require(value["broader_population_claim"] is False, "MJMS_CONTACT_BROAD_CLAIM")
    return {
        "identity_fields": list(expected["identity_fields"]),
        "event_kinds": list(expected["allowed_event_kinds"]),
        "matching_rule": expected["matching_rule"],
        "event_order": expected["event_order"],
        "occurrence_indexing": expected["occurrence_indexing"],
        "aggregation": expected["aggregation"],
        "empty_matched_event_set_value_steps": 0,
        "mismatch_disposition": expected["identity_or_count_mismatch_disposition"],
        "adequacy_argument": adequacy,
        "chosen_before_outcomes": True,
        "population_scope": scope,
        "broader_population_claim": False,
    }


def compile_metric_suite(suite: dict[str, Any]) -> dict[str, Any]:
    """Compile one fixture-only metric suite without constructing physics."""

    contract = load_metric_semantics_contract()
    _require(isinstance(suite, dict), "MJMS_SUITE_TYPE")
    _require_fields(suite, _SUITE_FIELDS, "MJMS_SUITE_FIELDS")
    _require(suite["schema_version"] == SUITE_SCHEMA, "MJMS_SUITE_SCHEMA")
    suite_id = _nonempty_string(suite["suite_id"], "MJMS_SUITE_ID")
    contract_hash = file_sha256(CONTRACT_PATH)
    _require(
        _sha256_text(suite["contract_raw_sha256"], "MJMS_SUITE_CONTRACT_HASH")
        == contract_hash,
        "MJMS_SUITE_CONTRACT_BINDING",
    )
    _require(suite["fixture_only"] is True, "MJMS_SUITE_FIXTURE_ONLY")
    suite_contract = contract["metric_suite_contract"]
    step_index_origin = _nonnegative_int(
        suite["step_index_origin"], "MJMS_SUITE_STEP_INDEX_ORIGIN"
    )
    one_step_observation_index = _positive_int(
        suite["one_step_observation_index"], "MJMS_SUITE_ONE_STEP_INDEX"
    )
    _require(
        step_index_origin == suite_contract["step_index_origin"]
        and one_step_observation_index == suite_contract["one_step_observation_index"]
        and suite["bounded_horizon_inclusion"]
        == suite_contract["bounded_horizon_inclusion"],
        "MJMS_SUITE_STEP_SEMANTICS",
    )
    allowed_kinds = tuple(suite_contract["allowed_value_kinds"])
    registries = {
        "state_components": _validate_component_registry(
            suite["state_components"],
            registry_name="state_components",
            allowed_value_kinds=allowed_kinds,
        ),
        "actuator_components": _validate_component_registry(
            suite["actuator_components"],
            registry_name="actuator_components",
            allowed_value_kinds=allowed_kinds,
        ),
        "pose_velocity_components": _validate_component_registry(
            suite["pose_velocity_components"],
            registry_name="pose_velocity_components",
            allowed_value_kinds=allowed_kinds,
        ),
    }
    energy = _validate_energy_semantics(suite["energy_semantics"], contract)
    contact = _validate_contact_semantics(suite["contact_event_semantics"], contract)
    _require(
        suite["production_metric_semantics_complete"] is False,
        "MJMS_SUITE_PRODUCTION_AUTHORITY",
    )
    for field in (
        "model_construction_count",
        "step_invocation_count",
        "world_attempt_count",
        "world_build_count",
    ):
        _require(
            _nonnegative_int(suite[field], "MJMS_SUITE_ZERO_WORLD") == 0,
            "MJMS_SUITE_ZERO_WORLD",
            field,
        )
    for field in (
        "physics_state_modified",
        "scientific_result",
        "physical_acceptance_authority",
        "release_authority",
    ):
        _require(suite[field] is False, "MJMS_SUITE_AUTHORITY", field)

    return {
        "schema_version": SUITE_SCHEMA,
        "suite_id": suite_id,
        "suite_sha256": canonical_sha256(suite),
        "contract_raw_sha256": contract_hash,
        "fixture_only": True,
        "step_index_origin": 0,
        "one_step_observation_index": 1,
        "bounded_horizon_inclusion": "steps_1_through_h_inclusive",
        **registries,
        "energy_semantics": energy,
        "contact_event_semantics": contact,
        "metric_order": list(REQUIRED_METRICS),
        "metric_units": dict(EXPECTED_UNITS),
        "compiler_fixture_complete": True,
        "production_metric_semantics_complete": False,
        "production_semantic_ceiling_sources_complete": False,
        "production_plan_exists": False,
        "calibration_authorized": False,
        "model_construction_count": 0,
        "step_invocation_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physics_state_modified": False,
        "scientific_result": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def _validate_component_value(
    value: object,
    component: Mapping[str, Any],
    code: str,
) -> float | tuple[float, float, float, float]:
    if component["value_kind"] != "unit_quaternion_wxyz":
        return _finite_number(value, code)
    _require(isinstance(value, list) and len(value) == 4, code, "quaternion_shape")
    quaternion = tuple(_finite_number(item, code) for item in value)
    norm = math.sqrt(sum(item * item for item in quaternion))
    _require(norm > 0.0, "MJMS_TRACE_ZERO_QUATERNION", component["component_id"])
    return quaternion


def _validate_component_map(
    value: object,
    registry: Sequence[Mapping[str, Any]],
    code: str,
) -> dict[str, float | tuple[float, float, float, float]]:
    _require(isinstance(value, dict), code, "not_object")
    component_ids = [component["component_id"] for component in registry]
    _require(set(value) == set(component_ids), code, "component_key_set")
    return {
        component_id: _validate_component_value(value[component_id], component, code)
        for component_id, component in zip(component_ids, registry, strict=True)
    }


def _validate_trace(trace: dict[str, Any], suite: dict[str, Any]) -> dict[str, Any]:
    _require(isinstance(trace, dict), "MJMS_TRACE_TYPE")
    _require_fields(trace, _TRACE_FIELDS, "MJMS_TRACE_FIELDS")
    _require(trace["schema_version"] == TRACE_SCHEMA, "MJMS_TRACE_SCHEMA")
    trace_id = _nonempty_string(trace["trace_id"], "MJMS_TRACE_ID")
    _require(
        _sha256_text(trace["suite_sha256"], "MJMS_TRACE_SUITE_HASH")
        == suite["suite_sha256"],
        "MJMS_TRACE_SUITE_BINDING",
    )
    role = _nonempty_string(trace["runtime_role"], "MJMS_TRACE_ROLE")
    _require(role in ("cpu_reference", "warp_candidate"), "MJMS_TRACE_ROLE", role)
    horizon = _positive_int(trace["horizon_steps"], "MJMS_TRACE_HORIZON")
    samples = trace["samples"]
    _require(isinstance(samples, list), "MJMS_TRACE_SAMPLES_TYPE")
    _require(len(samples) == horizon + 1, "MJMS_TRACE_SAMPLE_COUNT")
    validated_samples: list[dict[str, Any]] = []
    for expected_step, sample in enumerate(samples):
        _require(isinstance(sample, dict), "MJMS_TRACE_SAMPLE_TYPE")
        _require_fields(sample, _SAMPLE_FIELDS, "MJMS_TRACE_SAMPLE_FIELDS")
        sample_step = _nonnegative_int(
            sample["step_index"], "MJMS_TRACE_STEP_INDEX_TYPE"
        )
        _require(sample_step == expected_step, "MJMS_TRACE_STEP_ORDER")
        validated_samples.append(
            {
                "step_index": expected_step,
                "state": _validate_component_map(
                    sample["state"], suite["state_components"], "MJMS_TRACE_STATE"
                ),
                "actuator": _validate_component_map(
                    sample["actuator"],
                    suite["actuator_components"],
                    "MJMS_TRACE_ACTUATOR",
                ),
                "pose_velocity": _validate_component_map(
                    sample["pose_velocity"],
                    suite["pose_velocity_components"],
                    "MJMS_TRACE_POSE_VELOCITY",
                ),
                "energy_j": _finite_number(sample["energy_j"], "MJMS_TRACE_ENERGY"),
            }
        )

    events = trace["contact_events"]
    _require(isinstance(events, list), "MJMS_TRACE_EVENTS_TYPE")
    validated_events: list[dict[str, Any]] = []
    identities: list[tuple[str, str, int]] = []
    allowed_event_kinds = tuple(suite["contact_event_semantics"]["event_kinds"])
    for event in events:
        _require(isinstance(event, dict), "MJMS_TRACE_EVENT_TYPE")
        _require_fields(event, _EVENT_FIELDS, "MJMS_TRACE_EVENT_FIELDS")
        pair = _nonempty_string(event["body_pair_id"], "MJMS_TRACE_EVENT_PAIR")
        kind = _nonempty_string(event["event_kind"], "MJMS_TRACE_EVENT_KIND")
        _require(kind in allowed_event_kinds, "MJMS_TRACE_EVENT_KIND", kind)
        occurrence = _positive_int(
            event["occurrence_index"], "MJMS_TRACE_EVENT_OCCURRENCE"
        )
        step = _nonnegative_int(event["step_index"], "MJMS_TRACE_EVENT_STEP")
        _require(step <= horizon, "MJMS_TRACE_EVENT_STEP", step)
        identity = (pair, kind, occurrence)
        _require(identity not in identities, "MJMS_TRACE_EVENT_DUPLICATE", identity)
        identities.append(identity)
        validated_events.append(
            {
                "body_pair_id": pair,
                "event_kind": kind,
                "occurrence_index": occurrence,
                "step_index": step,
            }
        )
    _require(identities == sorted(identities), "MJMS_TRACE_EVENT_ORDER")
    occurrence_groups: dict[tuple[str, str], list[int]] = {}
    for pair, kind, occurrence in identities:
        occurrence_groups.setdefault((pair, kind), []).append(occurrence)
    _require(
        all(
            occurrences == list(range(1, len(occurrences) + 1))
            for occurrences in occurrence_groups.values()
        ),
        "MJMS_TRACE_EVENT_OCCURRENCE_SEQUENCE",
    )

    exact_failures = _nonnegative_int(
        trace["exact_failure_count"], "MJMS_TRACE_EXACT_FAILURE_COUNT"
    )
    _require(trace["fixture_only"] is True, "MJMS_TRACE_FIXTURE_ONLY")
    for field in (
        "model_construction_count",
        "step_invocation_count",
        "world_attempt_count",
        "world_build_count",
    ):
        _require(
            _nonnegative_int(trace[field], "MJMS_TRACE_ZERO_WORLD") == 0,
            "MJMS_TRACE_ZERO_WORLD",
            field,
        )
    _require(trace["physics_state_modified"] is False, "MJMS_TRACE_PHYSICS_STATE")
    return {
        "trace_id": trace_id,
        "trace_sha256": canonical_sha256(trace),
        "runtime_role": role,
        "horizon_steps": horizon,
        "samples": validated_samples,
        "contact_events": validated_events,
        "exact_failure_count": exact_failures,
    }


def _component_error(
    reference: float | tuple[float, float, float, float],
    candidate: float | tuple[float, float, float, float],
    component: Mapping[str, Any],
) -> float:
    kind = component["value_kind"]
    if kind == "scalar_linear":
        return abs(float(reference) - float(candidate))
    if kind == "scalar_periodic_radians":
        return abs(math.remainder(float(reference) - float(candidate), 2.0 * math.pi))
    reference_quaternion = tuple(float(item) for item in reference)  # type: ignore[arg-type]
    candidate_quaternion = tuple(float(item) for item in candidate)  # type: ignore[arg-type]
    reference_norm = math.sqrt(sum(item * item for item in reference_quaternion))
    candidate_norm = math.sqrt(sum(item * item for item in candidate_quaternion))
    dot = sum(
        left * right
        for left, right in zip(reference_quaternion, candidate_quaternion, strict=True)
    ) / (reference_norm * candidate_norm)
    return 2.0 * math.acos(min(1.0, max(0.0, abs(dot))))


def _normalized_errors(
    reference: Mapping[str, Any],
    candidate: Mapping[str, Any],
    registry: Sequence[Mapping[str, Any]],
) -> list[float]:
    return [
        _component_error(
            reference[component["component_id"]],
            candidate[component["component_id"]],
            component,
        )
        / float(component["normalization_scale"])
        for component in registry
    ]


def evaluate_fixture_pair(
    suite: dict[str, Any],
    reference_trace: dict[str, Any],
    candidate_trace: dict[str, Any],
) -> dict[str, Any]:
    """Evaluate a paired synthetic trace under an exact compiled suite."""

    _require(
        suite.get("schema_version") == SUITE_SCHEMA
        and suite.get("compiler_fixture_complete") is True
        and suite.get("fixture_only") is True,
        "MJMS_EVALUATION_SUITE",
    )
    reference = _validate_trace(reference_trace, suite)
    candidate = _validate_trace(candidate_trace, suite)
    _require(
        reference["runtime_role"] == "cpu_reference"
        and candidate["runtime_role"] == "warp_candidate",
        "MJMS_EVALUATION_ROLES",
    )
    _require(
        reference["horizon_steps"] == candidate["horizon_steps"],
        "MJMS_EVALUATION_HORIZON",
    )
    horizon = reference["horizon_steps"]
    failure_codes: list[str] = []
    if reference["exact_failure_count"] + candidate["exact_failure_count"] > 0:
        failure_codes.append("declared_exact_failure")

    reference_events = {
        (
            event["body_pair_id"],
            event["event_kind"],
            event["occurrence_index"],
        ): event["step_index"]
        for event in reference["contact_events"]
    }
    candidate_events = {
        (
            event["body_pair_id"],
            event["event_kind"],
            event["occurrence_index"],
        ): event["step_index"]
        for event in candidate["contact_events"]
    }
    if set(reference_events) != set(candidate_events):
        failure_codes.append("contact_event_identity_or_count_mismatch")

    metrics: dict[str, float | int] | None = None
    if not failure_codes:
        one_step = int(suite["one_step_observation_index"])
        reference_sample = reference["samples"][one_step]
        candidate_sample = candidate["samples"][one_step]
        state_errors = _normalized_errors(
            reference_sample["state"],
            candidate_sample["state"],
            suite["state_components"],
        )
        actuator_errors = _normalized_errors(
            reference_sample["actuator"],
            candidate_sample["actuator"],
            suite["actuator_components"],
        )
        pose_velocity_errors = [
            error
            for step in range(1, horizon + 1)
            for error in _normalized_errors(
                reference["samples"][step]["pose_velocity"],
                candidate["samples"][step]["pose_velocity"],
                suite["pose_velocity_components"],
            )
        ]
        energy_floor = float(suite["energy_semantics"]["denominator_floor_j"])
        energy_errors = [
            abs(
                float(reference["samples"][step]["energy_j"])
                - float(candidate["samples"][step]["energy_j"])
            )
            / max(abs(float(reference["samples"][step]["energy_j"])), energy_floor)
            for step in range(1, horizon + 1)
        ]
        contact_error = max(
            (
                abs(reference_events[identity] - candidate_events[identity])
                for identity in reference_events
            ),
            default=0,
        )
        metrics = {
            "one_step_state_linf_normalized": max(state_errors),
            "one_step_actuator_linf_normalized": max(actuator_errors),
            "bounded_horizon_pose_velocity_rms_normalized": math.sqrt(
                sum(value * value for value in pose_velocity_errors)
                / len(pose_velocity_errors)
            ),
            "bounded_horizon_energy_relative_error": math.sqrt(
                sum(value * value for value in energy_errors) / len(energy_errors)
            ),
            "contact_event_time_error_steps": contact_error,
        }

    evaluation_identity = {
        "suite_sha256": suite["suite_sha256"],
        "reference_trace_id": reference["trace_id"],
        "reference_trace_sha256": reference["trace_sha256"],
        "candidate_trace_id": candidate["trace_id"],
        "candidate_trace_sha256": candidate["trace_sha256"],
        "horizon_steps": horizon,
        "failure_codes": failure_codes,
        "metrics": metrics,
    }
    return {
        "schema_version": EVALUATION_SCHEMA,
        "ok": True,
        "fixture_only": True,
        "suite_sha256": suite["suite_sha256"],
        "reference_trace_id": reference["trace_id"],
        "reference_trace_sha256": reference["trace_sha256"],
        "candidate_trace_id": candidate["trace_id"],
        "candidate_trace_sha256": candidate["trace_sha256"],
        "horizon_steps": horizon,
        "valid_metric_vector": not failure_codes,
        "failure_codes": failure_codes,
        "metrics": metrics,
        "evaluation_sha256": canonical_sha256(evaluation_identity),
        "production_metric_semantics_complete": False,
        "production_semantic_ceiling_sources_complete": False,
        "production_plan_exists": False,
        "calibration_authorized": False,
        "model_construction_count": 0,
        "step_invocation_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physics_state_modified": False,
        "scientific_result": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def compile_current_metric_semantics_inventory() -> dict[str, Any]:
    contract = load_metric_semantics_contract()
    readiness = contract["required_metric_semantics"]
    inventory = {
        "schema_version": INVENTORY_SCHEMA,
        "inventory_id": contract["current_inventory"]["inventory_id"],
        "contract_id": contract["contract_id"],
        "contract_raw_sha256": file_sha256(CONTRACT_PATH),
        "question_class": "development",
        "metric_readiness": [
            {
                "metric_id": item["metric_id"],
                "unit": item["unit"],
                "kind": item["kind"],
                "status": item["status"],
                "unresolved_reason": item["required_definition"],
            }
            for item in readiness
        ],
        "required_metric_count": len(REQUIRED_METRICS),
        "production_metric_definition_count": 0,
        "unresolved_metric_count": len(REQUIRED_METRICS),
        "production_metric_semantics_complete": False,
        "production_semantic_ceiling_sources_complete": False,
        "production_plan_exists": False,
        "calibration_authorized": False,
        "model_construction_count": 0,
        "step_invocation_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physics_state_modified": False,
        "scientific_result": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    inventory["inventory_sha256"] = canonical_sha256(inventory)
    return inventory
