"""Zero-world conformance for the MuJoCo/Warp observable projection layer."""

from __future__ import annotations

import argparse
import copy
import json
import math
import os
import subprocess
import sys
from collections import OrderedDict
from pathlib import Path
from typing import Any, Callable

try:  # Package import under tests.
    from . import mujoco_warp_metric_semantics as mjms
    from . import mujoco_warp_observable_projection as projection
except ImportError:  # Direct script execution from this directory.
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
    from sdk.adaptation_provider import mujoco_warp_metric_semantics as mjms
    from sdk.adaptation_provider import mujoco_warp_observable_projection as projection


REPORT_SCHEMA = "sporespore_mujoco_warp_observable_projection_conformance_report_v1"
SNAPSHOT_SCHEMA = "sporespore_mujoco_warp_native_snapshot_fixture_v1"
SDK_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = SDK_ROOT.parent


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
    registries: list[str],
    native_field: str,
    native_indices: list[int],
    quantity: str,
    unit: str,
    value_kind: str = "scalar_linear",
    quaternion_input_order: str | None = None,
) -> dict[str, Any]:
    return {
        "component_id": component_id,
        "registries": registries,
        "native_field": native_field,
        "native_indices": native_indices,
        "quantity": quantity,
        "unit": unit,
        "value_kind": value_kind,
        "quaternion_input_order": quaternion_input_order,
    }


def build_fixture_binding() -> dict[str, Any]:
    contract = projection.load_observable_projection_contract()
    lifecycle = copy.deepcopy(contract["capture_lifecycle_contract"])
    model_sha = projection.canonical_sha256({"fixture": "synthetic_mjop_model_v1"})
    morphology_sha = projection.canonical_sha256(
        {"fixture": "synthetic_mjop_morphology_v1"}
    )
    components = [
        _component("base_position_x", ["state", "pose_velocity"], "qpos", [0], "base_world_position_x", "m"),
        _component("base_position_y", ["state", "pose_velocity"], "qpos", [1], "base_world_position_y", "m"),
        _component("base_position_z", ["state", "pose_velocity"], "qpos", [2], "base_world_position_z", "m"),
        _component(
            "base_orientation_wxyz",
            ["state", "pose_velocity"],
            "qpos",
            [3, 4, 5, 6],
            "base_world_orientation",
            "unit_quaternion",
            "unit_quaternion_wxyz",
            "wxyz",
        ),
        _component(
            "front_left_hip_position_rad",
            ["state", "pose_velocity"],
            "qpos",
            [7],
            "front_left_hip_position",
            "radian",
            "scalar_periodic_radians",
        ),
        _component(
            "front_left_knee_position_rad",
            ["state", "pose_velocity"],
            "qpos",
            [8],
            "front_left_knee_position",
            "radian",
            "scalar_periodic_radians",
        ),
        _component("base_linear_velocity_x", ["state", "pose_velocity"], "qvel", [0], "base_world_linear_velocity_x", "m_s"),
        _component("base_linear_velocity_y", ["state", "pose_velocity"], "qvel", [1], "base_world_linear_velocity_y", "m_s"),
        _component("base_linear_velocity_z", ["state", "pose_velocity"], "qvel", [2], "base_world_linear_velocity_z", "m_s"),
        _component("base_angular_velocity_x", ["state", "pose_velocity"], "qvel", [3], "base_angular_velocity_x", "rad_s"),
        _component("base_angular_velocity_y", ["state", "pose_velocity"], "qvel", [4], "base_angular_velocity_y", "rad_s"),
        _component("base_angular_velocity_z", ["state", "pose_velocity"], "qvel", [5], "base_angular_velocity_z", "rad_s"),
        _component("front_left_hip_velocity_rad_s", ["state", "pose_velocity"], "qvel", [6], "front_left_hip_velocity", "rad_s"),
        _component("front_left_knee_velocity_rad_s", ["state", "pose_velocity"], "qvel", [7], "front_left_knee_velocity", "rad_s"),
        _component("front_left_hip_actuator_force_nm", ["actuator"], "actuator_force", [0], "front_left_hip_actuator_force", "N_m"),
        _component("front_left_knee_actuator_force_nm", ["actuator"], "actuator_force", [1], "front_left_knee_actuator_force", "N_m"),
    ]
    return {
        "schema_version": projection.BINDING_SCHEMA,
        "binding_id": "synthetic_mjop_binding_v1",
        "contract_raw_sha256": projection.file_sha256(projection.CONTRACT_PATH),
        "fixture_only": True,
        "topology_bucket_id": "synthetic_free_root_two_hinge_bucket",
        "model_identity": {
            "model_sha256": model_sha,
            "morphology_sha256": morphology_sha,
            "nq": 9,
            "nv": 8,
            "nu": 2,
            "ngeom": 4,
            "nsite": 2,
            "energy_enabled": True,
            "unsupported_sensor_features_absent": True,
        },
        "capture_lifecycle": lifecycle,
        "runtime_layouts": [
            {
                "runtime_role": "cpu_reference",
                "nworld": 1,
                "world_index": 0,
                "world_axis_kind": "absent",
                "field_shapes": {
                    "qpos": [9],
                    "qvel": [8],
                    "actuator_force": [2],
                    "energy": [2],
                },
                "effective_float_dtype": "float64",
                "effective_dtype_observed": True,
                "contact_count_source": "mujoco.MjData.ncon",
                "contact_storage_rule": "mujoco.MjData.contact[0:ncon]",
            },
            {
                "runtime_role": "warp_candidate",
                "nworld": 2,
                "world_index": 1,
                "world_axis_kind": "leading_nworld",
                "field_shapes": {
                    "qpos": [2, 9],
                    "qvel": [2, 8],
                    "actuator_force": [2, 2],
                    "energy": [2, 2],
                },
                "effective_float_dtype": "float32",
                "effective_dtype_observed": True,
                "contact_count_source": "mujoco_warp.Data.nacon[0]",
                "contact_storage_rule": "mujoco_warp.Data.contact[0:nacon]",
            },
        ],
        "components": components,
        "contact_site_bindings": [
            {
                "body_pair_id": "front_left_foot__ground",
                "contact_site_id": "front_left_foot",
                "contact_site_geom_ids": [2],
                "environment_geom_ids": [0],
            },
            {
                "body_pair_id": "front_right_foot__ground",
                "contact_site_id": "front_right_foot",
                "contact_site_geom_ids": [3],
                "environment_geom_ids": [0],
            },
        ],
        "ignored_contact_pairs": [],
        "unmapped_included_contact_disposition": "exact_failure",
        "normalization_scales_installed": False,
        "semantic_ceilings_installed": False,
        "production_binding": False,
        "model_construction_count": 0,
        "step_invocation_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physics_state_modified": False,
        "scientific_result": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def _mjms_component(component: dict[str, Any], ordinal: int) -> dict[str, Any]:
    error_unit = "radian" if component["value_kind"] in (
        "scalar_periodic_radians",
        "unit_quaternion_wxyz",
    ) else component["unit"]
    return {
        "component_id": component["component_id"],
        "quantity": component["quantity"],
        "unit": component["unit"],
        "value_kind": component["value_kind"],
        "error_unit": error_unit,
        "normalization_scale": float(ordinal + 1),
        "normalization_source": "fixture_only_projection_canary_scale",
        "provenance_reference": f"fixture:mjop:{component['component_id']}:scale",
        "adequacy_argument": (
            "This arbitrary positive fixture scale exercises the projection-to-MJMS "
            "interface only and has no production adequacy or margin authority."
        ),
        "chosen_before_outcomes": True,
        "population_scope": "synthetic_mjop_projection_fixture_only",
        "broader_population_claim": False,
    }


def build_fixture_suite(compiled_binding: dict[str, Any]) -> dict[str, Any]:
    def registry(name: str) -> list[dict[str, Any]]:
        return [
            _mjms_component(component, index)
            for index, component in enumerate(compiled_binding["registries"][name])
        ]

    raw = {
        "schema_version": mjms.SUITE_SCHEMA,
        "suite_id": "synthetic_mjop_mjms_suite_v1",
        "contract_raw_sha256": mjms.file_sha256(mjms.CONTRACT_PATH),
        "fixture_only": True,
        "step_index_origin": 0,
        "one_step_observation_index": 1,
        "bounded_horizon_inclusion": "steps_1_through_h_inclusive",
        "state_components": registry("state"),
        "actuator_components": registry("actuator"),
        "pose_velocity_components": registry("pose_velocity"),
        "energy_semantics": {
            "observable": "total_mechanical_energy_j",
            "reference_role": "cpu_reference",
            "denominator_rule": "max_abs_cpu_reference_and_positive_floor",
            "denominator_floor_j": 1.0,
            "denominator_floor_provenance": "fixture:mjop:energy_floor_j",
            "adequacy_argument": (
                "The one-joule fixture floor exercises the exact denominator path only; "
                "it is not a production energy-resolution claim."
            ),
            "aggregation": "rms_over_steps_1_through_h_inclusive",
            "chosen_before_outcomes": True,
            "population_scope": "synthetic_mjop_projection_fixture_only",
            "broader_population_claim": False,
        },
        "contact_event_semantics": {
            "identity_fields": ["body_pair_id", "event_kind", "occurrence_index"],
            "event_kinds": ["contact_begin", "contact_end"],
            "matching_rule": "exact_identity_and_count",
            "event_order": "lexicographic_body_pair_kind_occurrence",
            "occurrence_indexing": "one_based_contiguous_per_body_pair_and_event_kind",
            "aggregation": "maximum_absolute_step_delta",
            "empty_matched_event_set_value_steps": 0,
            "mismatch_disposition": "exact_failure_without_numeric_substitution",
            "adequacy_argument": (
                "Both synthetic foot-ground bindings are included to exercise aggregation, "
                "world filtering, begin/end transitions, and occurrence matching only."
            ),
            "chosen_before_outcomes": True,
            "population_scope": "two_synthetic_foot_ground_pairs_over_four_fixture_steps",
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
    return mjms.compile_metric_suite(raw)


def _cpu_contacts(step: int) -> list[dict[str, Any]]:
    pairs_by_step = {
        0: [],
        1: [(2, 0)],
        2: [(2, 0), (3, 0)],
        3: [(3, 0)],
        4: [],
    }
    return [
        {"geom1": first, "geom2": second, "included_in_constraint": True}
        for first, second in pairs_by_step[step]
    ]


def _warp_contacts(step: int) -> list[dict[str, Any]]:
    selected_by_step = {
        0: [],
        1: [],
        2: [(2, 0)],
        3: [(2, 0), (3, 0)],
        4: [],
    }
    records = [
        {
            "world_index": 0,
            "geom1": 2,
            "geom2": 0,
            "contact_type_bits": 1,
            "included_in_constraint": True,
        }
    ]
    records.extend(
        {
            "world_index": 1,
            "geom1": first,
            "geom2": second,
            "contact_type_bits": 1,
            "included_in_constraint": True,
        }
        for first, second in selected_by_step[step]
    )
    return records


def _state_vectors(step: int, candidate: bool) -> tuple[list[float], list[float], list[float], list[float]]:
    offset = 0.001 if candidate else 0.0
    angle = 0.001 if candidate else 0.0
    qpos = [
        0.02 * step + offset,
        0.40 + 0.001 * step,
        -0.01,
        math.cos(angle / 2.0),
        0.0,
        0.0,
        math.sin(angle / 2.0),
        0.10 + 0.01 * step + offset,
        0.35 - 0.005 * step,
    ]
    qvel = [
        0.20 + offset,
        0.01,
        0.0,
        0.0,
        0.0,
        0.02 + offset,
        0.10 + offset,
        -0.05,
    ]
    actuator = [1.0 + 0.1 * step + offset, -0.8 + 0.05 * step]
    energy = [12.0 + 0.2 * step + offset, 0.5 + 0.05 * step]
    return qpos, qvel, actuator, energy


def _snapshot(
    compiled_binding: dict[str, Any], role: str, step: int
) -> dict[str, Any]:
    candidate = role == "warp_candidate"
    qpos, qvel, actuator, energy = _state_vectors(step, candidate)
    layout = compiled_binding["runtime_layouts"][role]
    if candidate:
        other_qpos, other_qvel, other_actuator, other_energy = _state_vectors(step, False)
        arrays: dict[str, Any] = {
            "qpos": [other_qpos, qpos],
            "qvel": [other_qvel, qvel],
            "actuator_force": [other_actuator, actuator],
            "energy": [other_energy, energy],
        }
        records = _warp_contacts(step)
    else:
        arrays = {
            "qpos": qpos,
            "qvel": qvel,
            "actuator_force": actuator,
            "energy": energy,
        }
        records = _cpu_contacts(step)
    return {
        "schema_version": SNAPSHOT_SCHEMA,
        "binding_sha256": compiled_binding["binding_sha256"],
        "runtime_role": role,
        "semantic_step": step,
        "capture_point": compiled_binding["capture_lifecycle"][
            "warp_capture_point" if candidate else "cpu_capture_point"
        ],
        "effective_float_dtype": layout["effective_float_dtype"],
        "arrays": arrays,
        "contacts": {
            "active_count": len(records),
            "capacity": 8,
            "overflow": False,
            "records": records,
        },
        "exact_failures": [],
        "fixture_only": True,
        "model_construction_count": 0,
        "step_invocation_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physics_state_modified": False,
    }


def build_native_trace(
    compiled_binding: dict[str, Any], suite: dict[str, Any], role: str
) -> dict[str, Any]:
    return {
        "schema_version": projection.NATIVE_TRACE_SCHEMA,
        "trace_id": "synthetic_mjop_cpu_trace_v1" if role == "cpu_reference" else "synthetic_mjop_warp_trace_v1",
        "binding_sha256": compiled_binding["binding_sha256"],
        "suite_sha256": suite["suite_sha256"],
        "runtime_role": role,
        "horizon_steps": 4,
        "snapshots": [_snapshot(compiled_binding, role, step) for step in range(5)],
        "fixture_only": True,
        "model_construction_count": 0,
        "step_invocation_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physics_state_modified": False,
    }


def _mutated(value: dict[str, Any], mutation: Callable[[dict[str, Any]], None]) -> dict[str, Any]:
    result = copy.deepcopy(value)
    mutation(result)
    return result


def _expect_error(call: Callable[[], Any], code: str) -> bool:
    try:
        call()
    except projection.ObservableProjectionError as error:
        return error.code == code
    return False


def _all_authorities_false(value: dict[str, Any]) -> bool:
    return all(
        value[field] is False
        for field in (
            "production_binding",
            "production_metric_semantics_complete",
            "production_plan_exists",
            "calibration_authorized",
            "scientific_result",
            "physical_acceptance_authority",
            "release_authority",
        )
    )


def run_conformance() -> dict[str, Any]:
    contract = projection.load_observable_projection_contract()
    predecessor = projection._validate_predecessor(contract)
    inventory = projection.compile_current_observable_projection_inventory()
    raw_binding = build_fixture_binding()
    binding = projection.compile_observable_binding(raw_binding)
    suite = build_fixture_suite(binding)
    cpu_native = build_native_trace(binding, suite, "cpu_reference")
    warp_native = build_native_trace(binding, suite, "warp_candidate")
    cpu_projection = projection.project_native_trace(binding, cpu_native)
    warp_projection = projection.project_native_trace(binding, warp_native)
    evaluation = mjms.evaluate_fixture_pair(
        suite,
        cpu_projection["metric_trace"],
        warp_projection["metric_trace"],
    )

    controls: OrderedDict[str, bool] = OrderedDict()
    rejected_mutations: OrderedDict[str, str] = OrderedDict()

    # MJOP0: contract and immutable predecessor boundary.
    controls["contract_schema_and_question_class"] = (
        contract["schema_version"] == projection.CONTRACT_SCHEMA
        and contract["question_class"] == "development"
    )
    controls["predecessor_contract_hash"] = predecessor["metric_contract_sha256"] == contract["predecessor_boundary"]["metric_semantics_contract_raw_sha256"]
    controls["predecessor_manifest_hash"] = predecessor["validation_manifest_sha256"] == contract["predecessor_boundary"]["metric_semantics_validation_manifest_raw_sha256"]
    controls["predecessor_report_hash"] = predecessor["source_report_sha256"] == contract["predecessor_boundary"]["metric_semantics_source_report_sha256"]
    controls["predecessor_cold_receipt_hash"] = predecessor["integration_receipt_sha256"] == contract["predecessor_boundary"]["metric_semantics_integration_receipt_sha256"]
    field_projection = contract["native_field_projection"]
    controls["native_field_projection_identity"] = (
        [item["native_field"] for item in field_projection["state_fields"]] == ["qpos", "qvel"]
        and field_projection["actuator_field"]["native_field"] == "actuator_force"
        and field_projection["energy_field"]["aggregation"] == "potential_plus_kinetic"
        and field_projection["contact_field"]["unmapped_included_contact_disposition"] == "exact_failure"
    )

    # MJOP1: the production inventory must remain incomplete.
    controls["inventory_zero_production_bindings"] = inventory["production_topology_binding_count"] == 0
    controls["inventory_one_unresolved_binding"] = inventory["unresolved_topology_binding_count"] == 1
    controls["inventory_zero_metric_definitions"] = inventory["production_metric_definition_count"] == 0
    controls["inventory_authorities_false"] = all(
        inventory[field] is False
        for field in (
            "production_native_observable_binding_complete",
            "production_metric_semantics_complete",
            "production_semantic_ceiling_sources_complete",
            "production_plan_exists",
            "calibration_authorized",
            "scientific_result",
            "physical_acceptance_authority",
            "release_authority",
        )
    )

    # MJOP2: fixture binding compilation and exact native-slot coverage.
    controls["fixture_binding_compiles"] = binding["fixture_binding_complete"] is True
    controls["qpos_qvel_exact_coverage"] = (
        sorted(index for item in binding["components"] if item["native_field"] == "qpos" for index in item["native_indices"]) == list(range(9))
        and sorted(index for item in binding["components"] if item["native_field"] == "qvel" for index in item["native_indices"]) == list(range(8))
    )
    controls["state_pose_component_order_shared"] = [item["component_id"] for item in binding["registries"]["state"]] == [item["component_id"] for item in binding["registries"]["pose_velocity"]]
    controls["actuator_force_exact_coverage"] = sorted(index for item in binding["registries"]["actuator"] for index in item["native_indices"]) == [0, 1]
    controls["contact_binding_order_and_count"] = [item["body_pair_id"] for item in binding["contact_site_bindings"]] == ["front_left_foot__ground", "front_right_foot__ground"]
    wrong_contact_source = _mutated(raw_binding, lambda value: value["runtime_layouts"][0].__setitem__("contact_count_source", "convenient_count"))
    controls["wrong_contact_source_rejected"] = _expect_error(
        lambda: projection.compile_observable_binding(wrong_contact_source),
        "MJOP_LAYOUT_CONTACT_SOURCE",
    )
    rejected_mutations["wrong_contact_source_rejected"] = "MJOP_LAYOUT_CONTACT_SOURCE"

    # MJOP3: both projections enter the exact MJMS evaluator.
    controls["cpu_projection_metric_eligible"] = cpu_projection["metric_trace_eligible"] is True
    controls["warp_projection_metric_eligible"] = warp_projection["metric_trace_eligible"] is True
    controls["mjms_evaluation_positive"] = (
        evaluation["ok"] is True
        and evaluation["valid_metric_vector"] is True
        and evaluation["failure_codes"] == []
    )
    controls["mjms_five_metric_vector"] = len(evaluation["metrics"]) == 5
    controls["contact_event_identities_match"] = (
        len(cpu_projection["metric_trace"]["contact_events"]) == 4
        and len(warp_projection["metric_trace"]["contact_events"]) == 4
        and evaluation["metrics"]["contact_event_time_error_steps"] == 1
    )
    wrong_registry = _mutated(raw_binding, lambda value: value["components"][0].__setitem__("registries", ["state"]))
    controls["wrong_component_registry_rejected"] = _expect_error(
        lambda: projection.compile_observable_binding(wrong_registry),
        "MJOP_COMPONENT_REGISTRIES",
    )
    rejected_mutations["wrong_component_registry_rejected"] = "MJOP_COMPONENT_REGISTRIES"

    # MJOP4: model identity, address, quaternion, layout, and dtype mutations.
    mutation_specs: list[tuple[str, dict[str, Any], str]] = []
    mutation_specs.append(("malformed_model_hash_rejected", _mutated(raw_binding, lambda value: value["model_identity"].__setitem__("model_sha256", "sha256:bad")), "MJOP_MODEL_SHA"))
    mutation_specs.append(("zero_nq_rejected", _mutated(raw_binding, lambda value: value["model_identity"].__setitem__("nq", 0)), "MJOP_MODEL_NQ"))
    mutation_specs.append(("duplicate_component_id_rejected", _mutated(raw_binding, lambda value: value["components"][1].__setitem__("component_id", value["components"][0]["component_id"])), "MJOP_COMPONENT_DUPLICATE"))
    mutation_specs.append(("component_coverage_gap_rejected", _mutated(raw_binding, lambda value: value["components"].pop(0)), "MJOP_COMPONENT_COVERAGE"))
    mutation_specs.append(("component_index_out_of_range_rejected", _mutated(raw_binding, lambda value: value["components"][0].__setitem__("native_indices", [99])), "MJOP_COMPONENT_INDICES"))
    mutation_specs.append(("quaternion_order_rejected", _mutated(raw_binding, lambda value: value["components"][3].__setitem__("quaternion_input_order", "xyzw")), "MJOP_COMPONENT_QUATERNION"))
    mutation_specs.append(("layout_shape_rejected", _mutated(raw_binding, lambda value: value["runtime_layouts"][1]["field_shapes"].__setitem__("qpos", [2, 8])), "MJOP_LAYOUT_SHAPE_MISMATCH"))
    mutation_specs.append(("unobserved_dtype_rejected", _mutated(raw_binding, lambda value: value["runtime_layouts"][1].__setitem__("effective_dtype_observed", False)), "MJOP_LAYOUT_DTYPE_UNOBSERVED"))
    for name, mutated_binding, code in mutation_specs:
        controls[name] = _expect_error(
            lambda value=mutated_binding: projection.compile_observable_binding(value), code
        )
        rejected_mutations[name] = code

    # MJOP5: exact horizon, binding, dtype, shape, finiteness, lifecycle, and world identity.
    trace_mutations: list[tuple[str, dict[str, Any], str]] = []
    trace_mutations.append(("missing_snapshot_rejected", _mutated(cpu_native, lambda value: value["snapshots"].pop()), "MJOP_TRACE_SNAPSHOT_COUNT"))
    trace_mutations.append(("snapshot_step_reorder_rejected", _mutated(cpu_native, lambda value: value["snapshots"][1].__setitem__("semantic_step", 2)), "MJOP_SNAPSHOT_STEP_ORDER"))
    trace_mutations.append(("snapshot_binding_rejected", _mutated(cpu_native, lambda value: value["snapshots"][1].__setitem__("binding_sha256", "sha256:" + "0" * 64)), "MJOP_SNAPSHOT_BINDING"))
    trace_mutations.append(("snapshot_dtype_rejected", _mutated(warp_native, lambda value: value["snapshots"][1].__setitem__("effective_float_dtype", "float64")), "MJOP_SNAPSHOT_DTYPE"))
    trace_mutations.append(("snapshot_array_shape_rejected", _mutated(cpu_native, lambda value: value["snapshots"][1]["arrays"]["qpos"].pop()), "MJOP_SNAPSHOT_ARRAY_SHAPE"))
    trace_mutations.append(("snapshot_nonfinite_rejected", _mutated(cpu_native, lambda value: value["snapshots"][1]["arrays"]["energy"].__setitem__(0, float("nan"))), "MJOP_SNAPSHOT_ARRAY_SHAPE"))
    trace_mutations.append(("snapshot_capture_point_rejected", _mutated(cpu_native, lambda value: value["snapshots"][1].__setitem__("capture_point", "after_mj_forward")), "MJOP_SNAPSHOT_CAPTURE_POINT"))
    trace_mutations.append(("warp_contact_world_out_of_range_rejected", _mutated(warp_native, lambda value: value["snapshots"][0]["contacts"]["records"][0].__setitem__("world_index", 2)), "MJOP_WARP_CONTACT_WORLD"))
    for name, mutated_trace, code in trace_mutations:
        controls[name] = _expect_error(
            lambda value=mutated_trace: projection.project_native_trace(binding, value), code
        )
        rejected_mutations[name] = code

    # MJOP6: energy and contacts distinguish invalid structure from retained failures.
    energy_disabled = _mutated(raw_binding, lambda value: value["model_identity"].__setitem__("energy_enabled", False))
    controls["disabled_energy_rejected"] = _expect_error(
        lambda: projection.compile_observable_binding(energy_disabled), "MJOP_MODEL_FEATURES"
    )
    rejected_mutations["disabled_energy_rejected"] = "MJOP_MODEL_FEATURES"
    energy_nonfinite = _mutated(cpu_native, lambda value: value["snapshots"][1]["arrays"]["energy"].__setitem__(1, float("inf")))
    controls["nonfinite_energy_rejected"] = _expect_error(
        lambda: projection.project_native_trace(binding, energy_nonfinite),
        "MJOP_SNAPSHOT_ARRAY_SHAPE",
    )
    rejected_mutations["nonfinite_energy_rejected"] = "MJOP_SNAPSHOT_ARRAY_SHAPE"
    contact_count_mismatch = _mutated(cpu_native, lambda value: value["snapshots"][1]["contacts"].__setitem__("active_count", 2))
    controls["contact_count_mismatch_rejected"] = _expect_error(
        lambda: projection.project_native_trace(binding, contact_count_mismatch),
        "MJOP_CONTACT_RECORD_COUNT",
    )
    rejected_mutations["contact_count_mismatch_rejected"] = "MJOP_CONTACT_RECORD_COUNT"
    overflow_trace = _mutated(cpu_native, lambda value: value["snapshots"][1]["contacts"].__setitem__("overflow", True))
    overflow_projection = projection.project_native_trace(binding, overflow_trace)
    controls["overflow_retained_as_exact_failure"] = (
        overflow_projection["metric_trace_eligible"] is False
        and overflow_projection["metric_trace"]["exact_failure_count"] == 1
        and overflow_projection["failure_records"][0]["failure_code"] == "contact_capacity_overflow"
    )
    unmapped_trace = _mutated(
        cpu_native,
        lambda value: value["snapshots"][1]["contacts"]["records"][0].__setitem__("geom1", 1),
    )
    unmapped_projection = projection.project_native_trace(binding, unmapped_trace)
    controls["unmapped_contact_retained_as_exact_failure"] = (
        unmapped_projection["metric_trace_eligible"] is False
        and unmapped_projection["failure_records"][0]["failure_code"] == "unmapped_included_contact:0:1"
    )
    missing_constraint_bit = _mutated(
        warp_native,
        lambda value: value["snapshots"][2]["contacts"]["records"][1].__setitem__("contact_type_bits", 0),
    )
    missing_bit_projection = projection.project_native_trace(binding, missing_constraint_bit)
    controls["warp_constraint_bit_failure_retained"] = (
        missing_bit_projection["metric_trace_eligible"] is False
        and any("missing_constraint_bit" in item["failure_code"] for item in missing_bit_projection["failure_records"])
    )
    baseline_contact = _mutated(cpu_native, lambda value: value["snapshots"][0]["contacts"].update({"active_count": 1, "records": [{"geom1": 2, "geom2": 0, "included_in_constraint": True}]}))
    baseline_projection = projection.project_native_trace(binding, baseline_contact)
    controls["baseline_contact_is_left_censored"] = all(
        event["step_index"] != 0 for event in baseline_projection["metric_trace"]["contact_events"]
    )
    ignored_without_adequacy = _mutated(
        raw_binding,
        lambda value: value["ignored_contact_pairs"].append(
            {
                "geom_id_a": 0,
                "geom_id_b": 1,
                "chosen_before_outcomes": True,
                "adequacy_argument": "too short",
            }
        ),
    )
    controls["ignored_pair_without_adequacy_rejected"] = _expect_error(
        lambda: projection.compile_observable_binding(ignored_without_adequacy),
        "MJOP_IGNORED_PAIR_ADEQUACY",
    )
    rejected_mutations["ignored_pair_without_adequacy_rejected"] = "MJOP_IGNORED_PAIR_ADEQUACY"

    # MJOP7: source fixtures cannot inject authority or physical counts.
    production_injection = _mutated(raw_binding, lambda value: value.__setitem__("production_binding", True))
    controls["production_binding_injection_rejected"] = _expect_error(
        lambda: projection.compile_observable_binding(production_injection),
        "MJOP_BINDING_AUTHORITY",
    )
    rejected_mutations["production_binding_injection_rejected"] = "MJOP_BINDING_AUTHORITY"
    world_injection = _mutated(cpu_native, lambda value: value.__setitem__("world_build_count", 1))
    controls["world_count_injection_rejected"] = _expect_error(
        lambda: projection.project_native_trace(binding, world_injection),
        "MJOP_TRACE_ZERO_WORLD",
    )
    rejected_mutations["world_count_injection_rejected"] = "MJOP_TRACE_ZERO_WORLD"

    cell_control_names = [
        list(controls.keys())[0:6],
        list(controls.keys())[6:10],
        list(controls.keys())[10:16],
        list(controls.keys())[16:22],
        list(controls.keys())[22:30],
        list(controls.keys())[30:38],
        list(controls.keys())[38:46],
        list(controls.keys())[46:48],
    ]
    cells = []
    for cell_id, names in zip(projection.REQUIRED_CELLS, cell_control_names, strict=True):
        cells.append(
            {
                "cell_id": cell_id,
                "ok": all(controls[name] for name in names),
                "control_names": names,
            }
        )
    passed_cells = sum(1 for cell in cells if cell["ok"])
    failed_cells = len(cells) - passed_cells
    _all_ok = (
        len(controls) == 48
        and len(rejected_mutations) >= 24
        and all(controls.values())
        and passed_cells == len(projection.REQUIRED_CELLS)
        and failed_cells == 0
    )

    report = {
        "schema_version": REPORT_SCHEMA,
        "ok": _all_ok,
        "question_class": "development",
        "status": "passed_zero_world_source_conformance" if _all_ok else "failed_zero_world_source_conformance",
        "contract_id": contract["contract_id"],
        "contract_raw_sha256": projection.file_sha256(projection.CONTRACT_PATH),
        "source": _source_receipt(),
        "predecessor": predecessor,
        "required_cells": list(projection.REQUIRED_CELLS),
        "cells": cells,
        "passed_cells": passed_cells,
        "failed_cells": failed_cells,
        "controls": dict(controls),
        "control_count": len(controls),
        "rejected_mutations": dict(rejected_mutations),
        "rejected_mutation_count": len(rejected_mutations),
        "current_inventory": inventory,
        "fixture": {
            "binding_sha256": binding["binding_sha256"],
            "suite_sha256": suite["suite_sha256"],
            "cpu_native_trace_sha256": cpu_projection["native_trace_sha256"],
            "warp_native_trace_sha256": warp_projection["native_trace_sha256"],
            "cpu_metric_trace_sha256": cpu_projection["metric_trace_sha256"],
            "warp_metric_trace_sha256": warp_projection["metric_trace_sha256"],
            "evaluation_sha256": evaluation["evaluation_sha256"],
            "metric_count": len(evaluation["metrics"]),
            "contact_event_count_per_role": 4,
            "contact_event_time_error_steps": evaluation["metrics"]["contact_event_time_error_steps"],
            "fixture_only": True,
            "production_authority": False,
        },
        "production_topology_binding_count": 0,
        "unresolved_topology_binding_count": 1,
        "production_native_observable_binding_complete": False,
        "production_metric_definition_count": 0,
        "production_metric_semantics_complete": False,
        "production_semantic_ceiling_sources_complete": False,
        "production_plan_exists": False,
        "calibration_authorized": False,
        "model_construction_count": 0,
        "step_invocation_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physics_state_modified": False,
        "supported_physics_subset_qualified": False,
        "training_plane_authorized": False,
        "training_data_authority": False,
        "native_mujoco_equivalence": False,
        "cross_engine_equivalence": False,
        "scientific_result": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    return report


def _retain_report(report: dict[str, Any], path: Path) -> None:
    resolved = path.resolve()
    if resolved.name != "report.json":
        raise projection.ObservableProjectionError("MJOP_OUTPUT_NAME", str(resolved))
    resolved.parent.mkdir(parents=True, exist_ok=True)
    descriptor = os.open(resolved, os.O_WRONLY | os.O_CREAT | os.O_EXCL)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(projection.canonical_json_bytes(report))
            stream.write(b"\n")
    except BaseException:
        resolved.unlink(missing_ok=True)
        raise


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path)
    arguments = parser.parse_args()
    report = run_conformance()
    if arguments.output is not None:
        _retain_report(report, arguments.output)
    print(json.dumps(report, sort_keys=True, allow_nan=False))
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
