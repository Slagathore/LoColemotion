"""Run MJMS0-MJMS7 pure zero-world metric-semantics conformance."""

from __future__ import annotations

import argparse
import copy
import json
import math
import os
import subprocess
from pathlib import Path
from typing import Any, Callable

from .mujoco_warp_equivalence_calibration import canonical_json_bytes
from .mujoco_warp_metric_semantics import (
    CONTRACT_PATH,
    SUITE_SCHEMA,
    TRACE_SCHEMA,
    MetricSemanticsError,
    compile_current_metric_semantics_inventory,
    compile_metric_suite,
    evaluate_fixture_pair,
    file_sha256,
    load_metric_semantics_contract,
)


SDK_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = SDK_ROOT.parent
REPORT_SCHEMA = "sporespore_mujoco_warp_metric_semantics_conformance_report_v1"


class MetricSemanticsConformanceFailure(RuntimeError):
    """MJMS0-MJMS7 conformance failed."""


def _require(condition: bool, code: str, detail: object = "") -> None:
    if not condition:
        raise MetricSemanticsConformanceFailure(f"{code}:{detail}")


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


def _component(
    component_id: str,
    quantity: str,
    unit: str,
    value_kind: str,
    error_unit: str,
    scale: float,
) -> dict[str, Any]:
    return {
        "component_id": component_id,
        "quantity": quantity,
        "unit": unit,
        "value_kind": value_kind,
        "error_unit": error_unit,
        "normalization_scale": scale,
        "normalization_source": "fixture_only_canary_scale",
        "provenance_reference": f"fixture:{component_id}:normalization",
        "adequacy_argument": (
            "The arbitrary positive fixture scale exercises normalization only; "
            "it has no production population or acceptance meaning."
        ),
        "chosen_before_outcomes": True,
        "population_scope": "synthetic fixture trace only",
        "broader_population_claim": False,
    }


def metric_suite_fixture() -> dict[str, Any]:
    return {
        "schema_version": SUITE_SCHEMA,
        "suite_id": "mjms_fixture_suite_not_production",
        "contract_raw_sha256": file_sha256(CONTRACT_PATH),
        "fixture_only": True,
        "step_index_origin": 0,
        "one_step_observation_index": 1,
        "bounded_horizon_inclusion": "steps_1_through_h_inclusive",
        "state_components": [
            _component(
                "base_x",
                "base_world_x_position",
                "meter",
                "scalar_linear",
                "meter",
                2.0,
            ),
            _component(
                "base_yaw",
                "base_world_yaw",
                "radian",
                "scalar_periodic_radians",
                "radian",
                math.pi,
            ),
            _component(
                "base_orientation",
                "base_world_orientation",
                "unit_quaternion",
                "unit_quaternion_wxyz",
                "radian",
                math.pi,
            ),
        ],
        "actuator_components": [
            _component(
                "hip_command",
                "front_left_hip_canonical_command",
                "newton_meter",
                "scalar_linear",
                "newton_meter",
                10.0,
            )
        ],
        "pose_velocity_components": [
            _component(
                "torso_x",
                "torso_world_x_position",
                "meter",
                "scalar_linear",
                "meter",
                1.0,
            ),
            _component(
                "torso_yaw",
                "torso_world_yaw",
                "radian",
                "scalar_periodic_radians",
                "radian",
                math.pi,
            ),
            _component(
                "torso_orientation",
                "torso_world_orientation",
                "unit_quaternion",
                "unit_quaternion_wxyz",
                "radian",
                math.pi,
            ),
        ],
        "energy_semantics": {
            "observable": "total_mechanical_energy_j",
            "reference_role": "cpu_reference",
            "denominator_rule": "max_abs_cpu_reference_and_positive_floor",
            "denominator_floor_j": 1.0,
            "denominator_floor_provenance": "fixture:energy:positive_floor",
            "adequacy_argument": (
                "One joule keeps the zero-world canary denominator finite; it "
                "does not estimate a production energy scale."
            ),
            "aggregation": "rms_over_steps_1_through_h_inclusive",
            "chosen_before_outcomes": True,
            "population_scope": "synthetic fixture trace only",
            "broader_population_claim": False,
        },
        "contact_event_semantics": {
            "identity_fields": [
                "body_pair_id",
                "event_kind",
                "occurrence_index",
            ],
            "event_kinds": ["contact_begin", "contact_end"],
            "matching_rule": "exact_identity_and_count",
            "event_order": "lexicographic_body_pair_kind_occurrence",
            "occurrence_indexing": (
                "one_based_contiguous_per_body_pair_and_event_kind"
            ),
            "aggregation": "maximum_absolute_step_delta",
            "empty_matched_event_set_value_steps": 0,
            "mismatch_disposition": "exact_failure_without_numeric_substitution",
            "adequacy_argument": (
                "Exact fixture identities test deterministic matching only; "
                "they do not define a production contact population."
            ),
            "chosen_before_outcomes": True,
            "population_scope": "synthetic fixture trace only",
            "broader_population_claim": False,
        },
        "production_metric_semantics_complete": False,
        "model_construction_count": 0,
        "step_invocation_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physics_state_modified": False,
        "scientific_result": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def _sample(
    step: int,
    *,
    base_x: float,
    base_yaw: float,
    hip_command: float,
    torso_x: float,
    torso_yaw: float,
    energy_j: float,
) -> dict[str, Any]:
    return {
        "step_index": step,
        "state": {
            "base_x": base_x,
            "base_yaw": base_yaw,
            "base_orientation": [1.0, 0.0, 0.0, 0.0],
        },
        "actuator": {"hip_command": hip_command},
        "pose_velocity": {
            "torso_x": torso_x,
            "torso_yaw": torso_yaw,
            "torso_orientation": [1.0, 0.0, 0.0, 0.0],
        },
        "energy_j": energy_j,
    }


def paired_trace_fixture(suite_sha256: str) -> tuple[dict[str, Any], dict[str, Any]]:
    common = {
        "schema_version": TRACE_SCHEMA,
        "suite_sha256": suite_sha256,
        "horizon_steps": 2,
        "exact_failure_count": 0,
        "fixture_only": True,
        "model_construction_count": 0,
        "step_invocation_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physics_state_modified": False,
    }
    reference = {
        **common,
        "trace_id": "mjms_fixture_cpu_reference",
        "runtime_role": "cpu_reference",
        "samples": [
            _sample(
                0,
                base_x=0.0,
                base_yaw=0.0,
                hip_command=0.0,
                torso_x=0.0,
                torso_yaw=0.0,
                energy_j=10.0,
            ),
            _sample(
                1,
                base_x=1.0,
                base_yaw=math.pi - 0.1,
                hip_command=5.0,
                torso_x=1.0,
                torso_yaw=0.2,
                energy_j=12.0,
            ),
            _sample(
                2,
                base_x=2.0,
                base_yaw=0.3,
                hip_command=6.0,
                torso_x=2.0,
                torso_yaw=0.4,
                energy_j=14.0,
            ),
        ],
        "contact_events": [
            {
                "body_pair_id": "front_left_foot|ground",
                "event_kind": "contact_begin",
                "occurrence_index": 1,
                "step_index": 1,
            },
            {
                "body_pair_id": "front_left_foot|ground",
                "event_kind": "contact_end",
                "occurrence_index": 1,
                "step_index": 2,
            },
        ],
    }
    candidate = {
        **common,
        "trace_id": "mjms_fixture_warp_candidate",
        "runtime_role": "warp_candidate",
        "samples": [
            _sample(
                0,
                base_x=0.0,
                base_yaw=0.0,
                hip_command=0.0,
                torso_x=0.0,
                torso_yaw=0.0,
                energy_j=10.0,
            ),
            _sample(
                1,
                base_x=1.2,
                base_yaw=-math.pi + 0.1,
                hip_command=5.5,
                torso_x=1.1,
                torso_yaw=0.2,
                energy_j=12.6,
            ),
            _sample(
                2,
                base_x=2.1,
                base_yaw=0.3,
                hip_command=6.0,
                torso_x=2.2,
                torso_yaw=0.4,
                energy_j=13.3,
            ),
        ],
        "contact_events": [
            {
                "body_pair_id": "front_left_foot|ground",
                "event_kind": "contact_begin",
                "occurrence_index": 1,
                "step_index": 2,
            },
            {
                "body_pair_id": "front_left_foot|ground",
                "event_kind": "contact_end",
                "occurrence_index": 1,
                "step_index": 2,
            },
        ],
    }
    return reference, candidate


def _expect_error(callback: Callable[[], object], prefix: str) -> bool:
    try:
        callback()
    except MetricSemanticsError as error:
        return str(error).startswith(prefix)
    return False


def run_metric_semantics_conformance() -> dict[str, Any]:
    contract = load_metric_semantics_contract()
    current = compile_current_metric_semantics_inventory()
    suite_input = metric_suite_fixture()
    suite = compile_metric_suite(suite_input)
    reference, candidate = paired_trace_fixture(suite["suite_sha256"])
    positive = evaluate_fixture_pair(suite, reference, candidate)

    expected_pose_rms = math.sqrt((0.1**2 + 0.2**2) / 6.0)
    _require(positive["valid_metric_vector"], "MJMS_POSITIVE_VECTOR")
    metrics = positive["metrics"]
    _require(metrics is not None, "MJMS_POSITIVE_METRICS")
    _require(
        math.isclose(metrics["one_step_state_linf_normalized"], 0.1, abs_tol=1e-12)
        and math.isclose(
            metrics["one_step_actuator_linf_normalized"], 0.05, abs_tol=1e-12
        )
        and math.isclose(
            metrics["bounded_horizon_pose_velocity_rms_normalized"],
            expected_pose_rms,
            abs_tol=1e-12,
        )
        and math.isclose(
            metrics["bounded_horizon_energy_relative_error"],
            0.05,
            abs_tol=1e-12,
        )
        and metrics["contact_event_time_error_steps"] == 1,
        "MJMS_POSITIVE_VALUES",
        metrics,
    )

    controls: dict[str, bool] = {}

    def suite_mutation(callback: Callable[[dict[str, Any]], None]) -> dict[str, Any]:
        mutated = copy.deepcopy(suite_input)
        callback(mutated)
        return mutated

    def reference_mutation(
        callback: Callable[[dict[str, Any]], None]
    ) -> dict[str, Any]:
        mutated = copy.deepcopy(reference)
        callback(mutated)
        return mutated

    def candidate_mutation(
        callback: Callable[[dict[str, Any]], None]
    ) -> dict[str, Any]:
        mutated = copy.deepcopy(candidate)
        callback(mutated)
        return mutated

    controls["unknown_suite_field"] = _expect_error(
        lambda: compile_metric_suite(
            suite_mutation(lambda value: value.__setitem__("unexpected", True))
        ),
        "MJMS_SUITE_FIELDS:",
    )
    controls["suite_contract_hash_mutation"] = _expect_error(
        lambda: compile_metric_suite(
            suite_mutation(
                lambda value: value.__setitem__(
                    "contract_raw_sha256", "sha256:" + "0" * 64
                )
            )
        ),
        "MJMS_SUITE_CONTRACT_BINDING:",
    )
    controls["fixture_role_leak"] = _expect_error(
        lambda: compile_metric_suite(
            suite_mutation(lambda value: value.__setitem__("fixture_only", False))
        ),
        "MJMS_SUITE_FIXTURE_ONLY:",
    )
    controls["production_authority_injection"] = _expect_error(
        lambda: compile_metric_suite(
            suite_mutation(
                lambda value: value.__setitem__(
                    "production_metric_semantics_complete", True
                )
            )
        ),
        "MJMS_SUITE_PRODUCTION_AUTHORITY:",
    )
    controls["suite_world_count_injection"] = _expect_error(
        lambda: compile_metric_suite(
            suite_mutation(lambda value: value.__setitem__("world_build_count", 1))
        ),
        "MJMS_SUITE_ZERO_WORLD:",
    )
    controls["noninteger_suite_step_origin"] = _expect_error(
        lambda: compile_metric_suite(
            suite_mutation(lambda value: value.__setitem__("step_index_origin", False))
        ),
        "MJMS_SUITE_STEP_INDEX_ORIGIN:",
    )
    controls["boolean_suite_world_count"] = _expect_error(
        lambda: compile_metric_suite(
            suite_mutation(lambda value: value.__setitem__("world_build_count", False))
        ),
        "MJMS_SUITE_ZERO_WORLD:",
    )
    controls["duplicate_component"] = _expect_error(
        lambda: compile_metric_suite(
            suite_mutation(
                lambda value: value["state_components"].append(
                    copy.deepcopy(value["state_components"][0])
                )
            )
        ),
        "MJMS_COMPONENT_DUPLICATE:",
    )
    reordered_suite_input = copy.deepcopy(suite_input)
    reordered_suite_input["state_components"].reverse()
    reordered_suite = compile_metric_suite(reordered_suite_input)
    controls["component_reorder_changes_hash"] = (
        reordered_suite["suite_sha256"] != suite["suite_sha256"]
    )
    controls["nonpositive_normalization_scale"] = _expect_error(
        lambda: compile_metric_suite(
            suite_mutation(
                lambda value: value["state_components"][0].__setitem__(
                    "normalization_scale", 0.0
                )
            )
        ),
        "MJMS_COMPONENT_SCALE:",
    )
    controls["nonfinite_normalization_scale"] = _expect_error(
        lambda: compile_metric_suite(
            suite_mutation(
                lambda value: value["state_components"][0].__setitem__(
                    "normalization_scale", float("nan")
                )
            )
        ),
        "MJMS_COMPONENT_SCALE:",
    )
    controls["periodic_unit_mismatch"] = _expect_error(
        lambda: compile_metric_suite(
            suite_mutation(
                lambda value: value["state_components"][1].__setitem__("unit", "degree")
            )
        ),
        "MJMS_COMPONENT_PERIODIC_UNIT:",
    )
    controls["quaternion_error_unit_mismatch"] = _expect_error(
        lambda: compile_metric_suite(
            suite_mutation(
                lambda value: value["state_components"][2].__setitem__(
                    "error_unit", "unit_quaternion"
                )
            )
        ),
        "MJMS_COMPONENT_QUATERNION_UNIT:",
    )
    controls["missing_normalization_provenance"] = _expect_error(
        lambda: compile_metric_suite(
            suite_mutation(
                lambda value: value["state_components"][0].__setitem__(
                    "provenance_reference", "short"
                )
            )
        ),
        "MJMS_COMPONENT_PROVENANCE:",
    )
    controls["missing_normalization_adequacy"] = _expect_error(
        lambda: compile_metric_suite(
            suite_mutation(
                lambda value: value["state_components"][0].__setitem__(
                    "adequacy_argument", "too short"
                )
            )
        ),
        "MJMS_COMPONENT_ADEQUACY:",
    )
    controls["postoutcome_normalization"] = _expect_error(
        lambda: compile_metric_suite(
            suite_mutation(
                lambda value: value["state_components"][0].__setitem__(
                    "chosen_before_outcomes", False
                )
            )
        ),
        "MJMS_COMPONENT_POST_OUTCOME:",
    )
    controls["broad_component_population_claim"] = _expect_error(
        lambda: compile_metric_suite(
            suite_mutation(
                lambda value: value["state_components"][0].__setitem__(
                    "broader_population_claim", True
                )
            )
        ),
        "MJMS_COMPONENT_BROAD_CLAIM:",
    )

    periodic_candidate = copy.deepcopy(candidate)
    periodic_candidate["samples"][1]["state"]["base_x"] = reference["samples"][1][
        "state"
    ]["base_x"]
    periodic_candidate["samples"][1]["state"]["base_orientation"] = copy.deepcopy(
        reference["samples"][1]["state"]["base_orientation"]
    )
    periodic_evaluation = evaluate_fixture_pair(suite, reference, periodic_candidate)
    controls["periodic_shortest_arc_exact"] = math.isclose(
        periodic_evaluation["metrics"]["one_step_state_linf_normalized"],
        0.2 / math.pi,
        abs_tol=1e-12,
    )

    sign_candidate = copy.deepcopy(candidate)
    sign_candidate["samples"][1]["state"]["base_x"] = reference["samples"][1]["state"][
        "base_x"
    ]
    sign_candidate["samples"][1]["state"]["base_yaw"] = reference["samples"][1][
        "state"
    ]["base_yaw"]
    sign_candidate["samples"][1]["state"]["base_orientation"] = [
        -1.0,
        0.0,
        0.0,
        0.0,
    ]
    sign_evaluation = evaluate_fixture_pair(suite, reference, sign_candidate)
    controls["quaternion_sign_invariance"] = math.isclose(
        sign_evaluation["metrics"]["one_step_state_linf_normalized"],
        0.0,
        abs_tol=1e-12,
    )

    quaternion_candidate = copy.deepcopy(sign_candidate)
    quaternion_candidate["samples"][1]["state"]["base_orientation"] = [
        2.0 * math.cos(0.1),
        0.0,
        0.0,
        2.0 * math.sin(0.1),
    ]
    quaternion_evaluation = evaluate_fixture_pair(
        suite, reference, quaternion_candidate
    )
    controls["quaternion_geodesic_and_scale_normalization"] = math.isclose(
        quaternion_evaluation["metrics"]["one_step_state_linf_normalized"],
        0.2 / math.pi,
        abs_tol=1e-12,
    )
    controls["energy_observable_mutation"] = _expect_error(
        lambda: compile_metric_suite(
            suite_mutation(
                lambda value: value["energy_semantics"].__setitem__(
                    "observable", "outcome_selected_energy"
                )
            )
        ),
        "MJMS_ENERGY_OBSERVABLE:",
    )
    controls["nonpositive_energy_floor"] = _expect_error(
        lambda: compile_metric_suite(
            suite_mutation(
                lambda value: value["energy_semantics"].__setitem__(
                    "denominator_floor_j", 0.0
                )
            )
        ),
        "MJMS_ENERGY_FLOOR:",
    )
    controls["nonfinite_energy_floor"] = _expect_error(
        lambda: compile_metric_suite(
            suite_mutation(
                lambda value: value["energy_semantics"].__setitem__(
                    "denominator_floor_j", float("inf")
                )
            )
        ),
        "MJMS_ENERGY_FLOOR:",
    )
    controls["postoutcome_energy_rule"] = _expect_error(
        lambda: compile_metric_suite(
            suite_mutation(
                lambda value: value["energy_semantics"].__setitem__(
                    "chosen_before_outcomes", False
                )
            )
        ),
        "MJMS_ENERGY_POST_OUTCOME:",
    )
    controls["missing_energy_adequacy"] = _expect_error(
        lambda: compile_metric_suite(
            suite_mutation(
                lambda value: value["energy_semantics"].__setitem__(
                    "adequacy_argument", "too short"
                )
            )
        ),
        "MJMS_ENERGY_ADEQUACY:",
    )
    controls["weakened_contact_matching"] = _expect_error(
        lambda: compile_metric_suite(
            suite_mutation(
                lambda value: value["contact_event_semantics"].__setitem__(
                    "matching_rule", "nearest_event"
                )
            )
        ),
        "MJMS_CONTACT_RULE:",
    )
    controls["contact_numeric_substitution"] = _expect_error(
        lambda: compile_metric_suite(
            suite_mutation(
                lambda value: value["contact_event_semantics"].__setitem__(
                    "mismatch_disposition", "substitute_large_number"
                )
            )
        ),
        "MJMS_CONTACT_RULE:",
    )
    controls["postoutcome_contact_rule"] = _expect_error(
        lambda: compile_metric_suite(
            suite_mutation(
                lambda value: value["contact_event_semantics"].__setitem__(
                    "chosen_before_outcomes", False
                )
            )
        ),
        "MJMS_CONTACT_POST_OUTCOME:",
    )
    controls["missing_contact_adequacy"] = _expect_error(
        lambda: compile_metric_suite(
            suite_mutation(
                lambda value: value["contact_event_semantics"].__setitem__(
                    "adequacy_argument", "too short"
                )
            )
        ),
        "MJMS_CONTACT_ADEQUACY:",
    )
    controls["unknown_trace_field"] = _expect_error(
        lambda: evaluate_fixture_pair(
            suite,
            reference_mutation(lambda value: value.__setitem__("unexpected", True)),
            candidate,
        ),
        "MJMS_TRACE_FIELDS:",
    )
    controls["trace_suite_hash_mutation"] = _expect_error(
        lambda: evaluate_fixture_pair(
            suite,
            reference_mutation(
                lambda value: value.__setitem__("suite_sha256", "sha256:" + "0" * 64)
            ),
            candidate,
        ),
        "MJMS_TRACE_SUITE_BINDING:",
    )
    controls["runtime_role_collision"] = _expect_error(
        lambda: evaluate_fixture_pair(
            suite,
            reference,
            candidate_mutation(
                lambda value: value.__setitem__("runtime_role", "cpu_reference")
            ),
        ),
        "MJMS_EVALUATION_ROLES:",
    )
    horizon_candidate = copy.deepcopy(candidate)
    horizon_candidate["horizon_steps"] = 3
    horizon_candidate["samples"].append(
        {**copy.deepcopy(horizon_candidate["samples"][-1]), "step_index": 3}
    )
    controls["paired_horizon_mismatch"] = _expect_error(
        lambda: evaluate_fixture_pair(suite, reference, horizon_candidate),
        "MJMS_EVALUATION_HORIZON:",
    )
    controls["trace_sample_count_mismatch"] = _expect_error(
        lambda: evaluate_fixture_pair(
            suite,
            reference_mutation(lambda value: value["samples"].pop()),
            candidate,
        ),
        "MJMS_TRACE_SAMPLE_COUNT:",
    )
    controls["trace_step_reorder"] = _expect_error(
        lambda: evaluate_fixture_pair(
            suite,
            reference_mutation(
                lambda value: value["samples"][1].__setitem__("step_index", 2)
            ),
            candidate,
        ),
        "MJMS_TRACE_STEP_ORDER:",
    )
    controls["noninteger_trace_step_index"] = _expect_error(
        lambda: evaluate_fixture_pair(
            suite,
            reference_mutation(
                lambda value: value["samples"][0].__setitem__("step_index", False)
            ),
            candidate,
        ),
        "MJMS_TRACE_STEP_INDEX_TYPE:",
    )
    controls["missing_trace_component"] = _expect_error(
        lambda: evaluate_fixture_pair(
            suite,
            reference_mutation(
                lambda value: value["samples"][1]["state"].pop("base_x")
            ),
            candidate,
        ),
        "MJMS_TRACE_STATE:",
    )
    controls["extra_trace_component"] = _expect_error(
        lambda: evaluate_fixture_pair(
            suite,
            reference_mutation(
                lambda value: value["samples"][1]["state"].__setitem__("extra", 0.0)
            ),
            candidate,
        ),
        "MJMS_TRACE_STATE:",
    )
    controls["nonfinite_trace_component"] = _expect_error(
        lambda: evaluate_fixture_pair(
            suite,
            reference_mutation(
                lambda value: value["samples"][1]["state"].__setitem__(
                    "base_x", float("nan")
                )
            ),
            candidate,
        ),
        "MJMS_TRACE_STATE:",
    )
    controls["zero_norm_quaternion"] = _expect_error(
        lambda: evaluate_fixture_pair(
            suite,
            reference_mutation(
                lambda value: value["samples"][1]["state"].__setitem__(
                    "base_orientation", [0.0, 0.0, 0.0, 0.0]
                )
            ),
            candidate,
        ),
        "MJMS_TRACE_ZERO_QUATERNION:",
    )
    controls["duplicate_contact_event"] = _expect_error(
        lambda: evaluate_fixture_pair(
            suite,
            reference_mutation(
                lambda value: value["contact_events"].append(
                    copy.deepcopy(value["contact_events"][0])
                )
            ),
            candidate,
        ),
        "MJMS_TRACE_EVENT_DUPLICATE:",
    )
    controls["contact_event_reorder"] = _expect_error(
        lambda: evaluate_fixture_pair(
            suite,
            reference_mutation(lambda value: value["contact_events"].reverse()),
            candidate,
        ),
        "MJMS_TRACE_EVENT_ORDER:",
    )
    controls["unknown_contact_event_kind"] = _expect_error(
        lambda: evaluate_fixture_pair(
            suite,
            reference_mutation(
                lambda value: value["contact_events"][0].__setitem__(
                    "event_kind", "contact_near"
                )
            ),
            candidate,
        ),
        "MJMS_TRACE_EVENT_KIND:",
    )
    controls["contact_occurrence_gap"] = _expect_error(
        lambda: evaluate_fixture_pair(
            suite,
            reference_mutation(
                lambda value: value["contact_events"][0].__setitem__(
                    "occurrence_index", 2
                )
            ),
            candidate,
        ),
        "MJMS_TRACE_EVENT_OCCURRENCE_SEQUENCE:",
    )
    controls["nonfinite_trace_energy"] = _expect_error(
        lambda: evaluate_fixture_pair(
            suite,
            reference_mutation(
                lambda value: value["samples"][1].__setitem__("energy_j", float("inf"))
            ),
            candidate,
        ),
        "MJMS_TRACE_ENERGY:",
    )
    controls["trace_fixture_role_leak"] = _expect_error(
        lambda: evaluate_fixture_pair(
            suite,
            reference_mutation(lambda value: value.__setitem__("fixture_only", False)),
            candidate,
        ),
        "MJMS_TRACE_FIXTURE_ONLY:",
    )
    controls["trace_world_count_injection"] = _expect_error(
        lambda: evaluate_fixture_pair(
            suite,
            reference_mutation(lambda value: value.__setitem__("world_build_count", 1)),
            candidate,
        ),
        "MJMS_TRACE_ZERO_WORLD:",
    )

    content_candidate = copy.deepcopy(candidate)
    content_candidate["samples"][0]["state"]["base_x"] = 123.0
    content_evaluation = evaluate_fixture_pair(suite, reference, content_candidate)
    controls["trace_content_mutation_changes_hash"] = (
        content_evaluation["metrics"] == positive["metrics"]
        and content_evaluation["candidate_trace_sha256"]
        != positive["candidate_trace_sha256"]
        and content_evaluation["evaluation_sha256"] != positive["evaluation_sha256"]
    )

    floor_reference = copy.deepcopy(reference)
    floor_candidate = copy.deepcopy(candidate)
    for step in (1, 2):
        floor_reference["samples"][step]["energy_j"] = 0.0
        floor_candidate["samples"][step]["energy_j"] = 0.5
    floor_evaluation = evaluate_fixture_pair(suite, floor_reference, floor_candidate)
    controls["energy_denominator_floor_exact"] = math.isclose(
        floor_evaluation["metrics"]["bounded_horizon_energy_relative_error"],
        0.5,
        abs_tol=1e-12,
    )

    declared_failure_trace = copy.deepcopy(candidate)
    declared_failure_trace["exact_failure_count"] = 1
    declared_failure = evaluate_fixture_pair(suite, reference, declared_failure_trace)
    controls["declared_exact_failure_retained"] = (
        not declared_failure["valid_metric_vector"]
        and declared_failure["metrics"] is None
        and declared_failure["failure_codes"] == ["declared_exact_failure"]
    )
    mismatched_event_trace = copy.deepcopy(candidate)
    mismatched_event_trace["contact_events"].pop()
    contact_failure = evaluate_fixture_pair(suite, reference, mismatched_event_trace)
    controls["contact_identity_mismatch_retained"] = (
        not contact_failure["valid_metric_vector"]
        and contact_failure["metrics"] is None
        and contact_failure["failure_codes"]
        == ["contact_event_identity_or_count_mismatch"]
    )
    empty_reference = copy.deepcopy(reference)
    empty_candidate = copy.deepcopy(candidate)
    empty_reference["contact_events"] = []
    empty_candidate["contact_events"] = []
    empty_evaluation = evaluate_fixture_pair(suite, empty_reference, empty_candidate)
    controls["empty_contact_set_is_exact_zero"] = (
        empty_evaluation["valid_metric_vector"]
        and empty_evaluation["metrics"]["contact_event_time_error_steps"] == 0
    )
    _require(all(controls.values()), "MJMS_MUTATION_CONTROL", controls)

    component_controls = (
        "duplicate_component",
        "component_reorder_changes_hash",
        "nonpositive_normalization_scale",
        "nonfinite_normalization_scale",
        "periodic_unit_mismatch",
        "quaternion_error_unit_mismatch",
        "missing_normalization_provenance",
        "missing_normalization_adequacy",
        "postoutcome_normalization",
        "broad_component_population_claim",
        "periodic_shortest_arc_exact",
        "quaternion_sign_invariance",
        "quaternion_geodesic_and_scale_normalization",
    )
    trace_controls = (
        "unknown_trace_field",
        "trace_suite_hash_mutation",
        "runtime_role_collision",
        "paired_horizon_mismatch",
        "trace_sample_count_mismatch",
        "trace_step_reorder",
        "noninteger_trace_step_index",
        "missing_trace_component",
        "extra_trace_component",
        "nonfinite_trace_component",
        "zero_norm_quaternion",
        "trace_fixture_role_leak",
        "trace_world_count_injection",
        "trace_content_mutation_changes_hash",
    )
    semantic_controls = (
        "energy_observable_mutation",
        "nonpositive_energy_floor",
        "nonfinite_energy_floor",
        "postoutcome_energy_rule",
        "missing_energy_adequacy",
        "weakened_contact_matching",
        "contact_numeric_substitution",
        "postoutcome_contact_rule",
        "missing_contact_adequacy",
        "duplicate_contact_event",
        "contact_event_reorder",
        "unknown_contact_event_kind",
        "contact_occurrence_gap",
        "nonfinite_trace_energy",
        "energy_denominator_floor_exact",
        "declared_exact_failure_retained",
        "contact_identity_mismatch_retained",
        "empty_contact_set_is_exact_zero",
    )
    cells = [
        {
            "cell_id": "mjms0_contract_and_predecessor_boundary",
            "passed": True,
            "contract_id": contract["contract_id"],
            "contract_raw_sha256": file_sha256(CONTRACT_PATH),
            "calibration_contract_raw_sha256": contract["predecessor_boundary"][
                "calibration_contract_raw_sha256"
            ],
            "semantic_ceiling_contract_raw_sha256": contract["predecessor_boundary"][
                "semantic_ceiling_contract_raw_sha256"
            ],
            "semantic_ceiling_validation_manifest_raw_sha256": contract[
                "predecessor_boundary"
            ]["semantic_ceiling_validation_manifest_raw_sha256"],
            "semantic_ceiling_source_commit": contract["predecessor_boundary"][
                "semantic_ceiling_source_commit"
            ],
            "semantic_ceiling_source_report_sha256": contract["predecessor_boundary"][
                "semantic_ceiling_source_report_sha256"
            ],
            "semantic_ceiling_integration_commit": contract["predecessor_boundary"][
                "semantic_ceiling_integration_commit"
            ],
            "semantic_ceiling_integration_receipt_sha256": contract[
                "predecessor_boundary"
            ]["semantic_ceiling_integration_receipt_sha256"],
            "world_build_count": 0,
            "physical_acceptance_authority": False,
        },
        {
            "cell_id": "mjms1_current_incomplete_inventory",
            "passed": True,
            "production_metric_definition_count": current[
                "production_metric_definition_count"
            ],
            "unresolved_metric_count": current["unresolved_metric_count"],
            "all_unresolved_reasons_retained": all(
                item["unresolved_reason"] for item in current["metric_readiness"]
            ),
            "world_build_count": 0,
            "physical_acceptance_authority": False,
        },
        {
            "cell_id": "mjms2_fixture_suite_compilation",
            "passed": True,
            "suite_sha256": suite["suite_sha256"],
            "component_count": sum(
                len(suite[name])
                for name in (
                    "state_components",
                    "actuator_components",
                    "pose_velocity_components",
                )
            ),
            "compiler_fixture_complete": suite["compiler_fixture_complete"],
            "production_metric_semantics_complete": False,
            "world_build_count": 0,
            "physical_acceptance_authority": False,
        },
        {
            "cell_id": "mjms3_positive_fixture_evaluation",
            "passed": True,
            "valid_metric_vector": positive["valid_metric_vector"],
            "metric_count": len(metrics),
            "evaluation_sha256": positive["evaluation_sha256"],
            "reference_trace_sha256": positive["reference_trace_sha256"],
            "candidate_trace_sha256": positive["candidate_trace_sha256"],
            "world_build_count": 0,
            "physical_acceptance_authority": False,
        },
        {
            "cell_id": "mjms4_component_and_normalization_controls",
            "passed": all(controls[name] for name in component_controls),
            "rejected_control_count": len(component_controls),
            "world_build_count": 0,
            "physical_acceptance_authority": False,
        },
        {
            "cell_id": "mjms5_trace_and_horizon_controls",
            "passed": all(controls[name] for name in trace_controls),
            "rejected_control_count": len(trace_controls),
            "world_build_count": 0,
            "physical_acceptance_authority": False,
        },
        {
            "cell_id": "mjms6_energy_contact_and_failure_controls",
            "passed": all(controls[name] for name in semantic_controls),
            "rejected_control_count": len(semantic_controls),
            "world_build_count": 0,
            "physical_acceptance_authority": False,
        },
        {
            "cell_id": "mjms7_authority_boundary",
            "passed": True,
            "current_inventory_incomplete": True,
            "production_metric_semantics_complete": False,
            "production_semantic_ceiling_sources_complete": False,
            "production_plan_frozen": False,
            "calibration_authorized": False,
            "heldout_qualification_authorized": False,
            "supported_physics_subset_qualified": False,
            "training_plane_authorized": False,
            "scientific_result": False,
            "release_authority": False,
            "world_build_count": 0,
            "physical_acceptance_authority": False,
        },
    ]
    _require(len(cells) == 8 and all(cell["passed"] for cell in cells), "MJMS_CELLS")
    return {
        "schema_version": REPORT_SCHEMA,
        "ok": True,
        "contract_id": contract["contract_id"],
        "contract_raw_sha256": file_sha256(CONTRACT_PATH),
        "source": _source_receipt(),
        "cells": cells,
        "passed_cells": 8,
        "failed_cells": 0,
        "mutation_control_count": len(controls),
        "rejected_mutations": dict(sorted(controls.items())),
        "required_metric_count": 5,
        "production_metric_definition_count": 0,
        "unresolved_metric_count": 5,
        "all_unresolved_reasons_retained": True,
        "positive_fixture_metric_count": len(metrics),
        "fixture_only": True,
        "production_metric_semantics_complete": False,
        "production_semantic_ceiling_sources_complete": False,
        "production_plan_frozen": False,
        "calibration_executed": False,
        "production_margins_frozen": False,
        "heldout_execution_authorized": False,
        "supported_physics_subset_qualified": False,
        "training_data_authority": False,
        "training_plane_authorized": False,
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
    resolved = path.resolve()
    _require(resolved.name == "report.json", "MJMS_OUTPUT_NAME", resolved)
    resolved.parent.mkdir(parents=True, exist_ok=True)
    descriptor = os.open(resolved, os.O_WRONLY | os.O_CREAT | os.O_EXCL)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(canonical_json_bytes(report))
            stream.write(b"\n")
    except BaseException:
        resolved.unlink(missing_ok=True)
        raise


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path)
    arguments = parser.parse_args()
    report = run_metric_semantics_conformance()
    if arguments.output is not None:
        _retain_report(report, arguments.output)
    print(json.dumps(report, sort_keys=True, allow_nan=False))


if __name__ == "__main__":
    main()
