"""Pure zero-world MuJoCo/MuJoCo-Warp native-observable projection compiler.

This module validates a model-specific native-array binding and projects
synthetic native snapshots into the exact fixture-trace schema consumed by
``mujoco_warp_metric_semantics``.  It never imports either physics runtime,
constructs a model, invokes a step, or installs a production binding.
"""

from __future__ import annotations

import hashlib
import json
import math
import re
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence


CONTRACT_PATH = Path(__file__).with_name(
    "mujoco_warp_observable_projection_contract_v1.json"
)
REPO_ROOT = CONTRACT_PATH.parents[2]

CONTRACT_SCHEMA = "sporespore_mujoco_warp_observable_projection_contract_v1"
BINDING_SCHEMA = "sporespore_mujoco_warp_observable_binding_v1"
NATIVE_TRACE_SCHEMA = "sporespore_mujoco_warp_native_observable_trace_fixture_v1"
METRIC_TRACE_SCHEMA = "sporespore_mujoco_warp_metric_fixture_trace_v1"
PROJECTION_RECEIPT_SCHEMA = (
    "sporespore_mujoco_warp_native_observable_projection_receipt_v1"
)

RUNTIME_ROLES = ("cpu_reference", "warp_candidate")
NATIVE_FIELDS = ("qpos", "qvel", "actuator_force")
REGISTRY_NAMES = ("state", "actuator", "pose_velocity")
VALUE_KINDS = (
    "scalar_linear",
    "scalar_periodic_radians",
    "unit_quaternion_wxyz",
)
REQUIRED_CELLS = (
    "mjop0_contract_and_predecessor_boundary",
    "mjop1_current_incomplete_inventory",
    "mjop2_fixture_binding_compilation",
    "mjop3_positive_native_projection_and_mjms_integration",
    "mjop4_model_address_and_dtype_controls",
    "mjop5_shape_lifecycle_and_horizon_controls",
    "mjop6_energy_contact_and_failure_controls",
    "mjop7_authority_boundary",
)

_SEMANTIC_ID = re.compile(r"^[a-z][a-z0-9_]*(?:__[a-z0-9_]+)?$")

_BINDING_FIELDS = (
    "schema_version",
    "binding_id",
    "contract_raw_sha256",
    "fixture_only",
    "topology_bucket_id",
    "model_identity",
    "capture_lifecycle",
    "runtime_layouts",
    "components",
    "contact_site_bindings",
    "ignored_contact_pairs",
    "unmapped_included_contact_disposition",
    "normalization_scales_installed",
    "semantic_ceilings_installed",
    "production_binding",
    "model_construction_count",
    "step_invocation_count",
    "world_attempt_count",
    "world_build_count",
    "physics_state_modified",
    "scientific_result",
    "physical_acceptance_authority",
    "release_authority",
)
_MODEL_FIELDS = (
    "model_sha256",
    "morphology_sha256",
    "nq",
    "nv",
    "nu",
    "ngeom",
    "nsite",
    "energy_enabled",
    "unsupported_sensor_features_absent",
)
_LIFECYCLE_FIELDS = (
    "semantic_step_origin",
    "cpu_capture_point",
    "warp_capture_point",
    "same_initial_state_control_and_semantic_step_required",
    "one_capture_per_semantic_step_required",
    "steps_zero_through_h_inclusive_required",
    "selective_step_discard_or_replacement_permitted",
    "post_capture_forward_recomputation_permitted",
)
_LAYOUT_FIELDS = (
    "runtime_role",
    "nworld",
    "world_index",
    "world_axis_kind",
    "field_shapes",
    "effective_float_dtype",
    "effective_dtype_observed",
    "contact_count_source",
    "contact_storage_rule",
)
_COMPONENT_FIELDS = (
    "component_id",
    "registries",
    "native_field",
    "native_indices",
    "quantity",
    "unit",
    "value_kind",
    "quaternion_input_order",
)
_CONTACT_BINDING_FIELDS = (
    "body_pair_id",
    "contact_site_id",
    "contact_site_geom_ids",
    "environment_geom_ids",
)
_IGNORED_PAIR_FIELDS = (
    "geom_id_a",
    "geom_id_b",
    "chosen_before_outcomes",
    "adequacy_argument",
)
_NATIVE_TRACE_FIELDS = (
    "schema_version",
    "trace_id",
    "binding_sha256",
    "suite_sha256",
    "runtime_role",
    "horizon_steps",
    "snapshots",
    "fixture_only",
    "model_construction_count",
    "step_invocation_count",
    "world_attempt_count",
    "world_build_count",
    "physics_state_modified",
)
_SNAPSHOT_FIELDS = (
    "schema_version",
    "binding_sha256",
    "runtime_role",
    "semantic_step",
    "capture_point",
    "effective_float_dtype",
    "arrays",
    "contacts",
    "exact_failures",
    "fixture_only",
    "model_construction_count",
    "step_invocation_count",
    "world_attempt_count",
    "world_build_count",
    "physics_state_modified",
)
_ARRAY_FIELDS = ("qpos", "qvel", "actuator_force", "energy")
_CONTACT_FIELDS = ("active_count", "capacity", "overflow", "records")
_CPU_CONTACT_RECORD_FIELDS = ("geom1", "geom2", "included_in_constraint")
_WARP_CONTACT_RECORD_FIELDS = (
    "world_index",
    "geom1",
    "geom2",
    "contact_type_bits",
    "included_in_constraint",
)


class ObservableProjectionError(ValueError):
    """A binding, native snapshot, or predecessor failed closed."""

    def __init__(self, code: str, detail: Any | None = None):
        self.code = code
        self.detail = detail
        message = code if detail is None else f"{code}:{detail}"
        super().__init__(message)


def _require(condition: bool, code: str, detail: Any | None = None) -> None:
    if not condition:
        raise ObservableProjectionError(code, detail)


def _strict_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ObservableProjectionError("MJOP_JSON_DUPLICATE_KEY", key)
        result[key] = value
    return result


def _reject_constant(value: str) -> None:
    raise ObservableProjectionError("MJOP_JSON_NONFINITE", value)


def strict_json_loads(raw: bytes | str) -> Any:
    text = raw.decode("utf-8") if isinstance(raw, bytes) else raw
    try:
        return json.loads(
            text,
            object_pairs_hook=_strict_object,
            parse_constant=_reject_constant,
        )
    except ObservableProjectionError:
        raise
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise ObservableProjectionError("MJOP_JSON_INVALID", str(error)) from error


def canonical_json_bytes(value: Any) -> bytes:
    try:
        return json.dumps(
            value,
            allow_nan=False,
            ensure_ascii=False,
            separators=(",", ":"),
            sort_keys=True,
        ).encode("utf-8")
    except (TypeError, ValueError) as error:
        raise ObservableProjectionError("MJOP_CANONICAL_JSON", str(error)) from error


def canonical_sha256(value: Any) -> str:
    return "sha256:" + hashlib.sha256(canonical_json_bytes(value)).hexdigest()


def file_sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def _require_fields(value: Mapping[str, Any], fields: Iterable[str], code: str) -> None:
    expected = set(fields)
    actual = set(value)
    _require(actual == expected, code, {"missing": sorted(expected - actual), "extra": sorted(actual - expected)})


def _nonempty_string(value: Any, code: str) -> str:
    _require(isinstance(value, str) and bool(value.strip()), code)
    return value


def _semantic_id(value: Any, code: str) -> str:
    text = _nonempty_string(value, code)
    _require(_SEMANTIC_ID.fullmatch(text) is not None, code, text)
    return text


def _sha256_text(value: Any, code: str) -> str:
    text = _nonempty_string(value, code)
    _require(re.fullmatch(r"sha256:[0-9a-f]{64}", text) is not None, code, text)
    return text


def _nonnegative_int(value: Any, code: str) -> int:
    _require(isinstance(value, int) and not isinstance(value, bool) and value >= 0, code, value)
    return value


def _positive_int(value: Any, code: str) -> int:
    result = _nonnegative_int(value, code)
    _require(result > 0, code, value)
    return result


def _finite_number(value: Any, code: str) -> float:
    _require(isinstance(value, (int, float)) and not isinstance(value, bool), code, value)
    result = float(value)
    _require(math.isfinite(result), code, value)
    return result


def _read_strict_json(path: Path, code: str) -> dict[str, Any]:
    _require(path.is_file(), code, str(path))
    value = strict_json_loads(path.read_bytes())
    _require(isinstance(value, dict), code, str(path))
    return value


def _validate_predecessor(contract: Mapping[str, Any]) -> dict[str, Any]:
    predecessor = contract["predecessor_boundary"]
    metric_contract_path = REPO_ROOT / predecessor["metric_semantics_contract_path"]
    metric_compiler_path = REPO_ROOT / predecessor["metric_semantics_compiler_path"]
    manifest_path = REPO_ROOT / predecessor["metric_semantics_validation_manifest_path"]
    _require(
        file_sha256(metric_contract_path)
        == predecessor["metric_semantics_contract_raw_sha256"],
        "MJOP_PREDECESSOR_CONTRACT_HASH",
    )
    _require(
        file_sha256(metric_compiler_path)
        == predecessor["metric_semantics_compiler_raw_sha256"],
        "MJOP_PREDECESSOR_COMPILER_HASH",
    )
    _require(
        file_sha256(manifest_path)
        == predecessor["metric_semantics_validation_manifest_raw_sha256"],
        "MJOP_PREDECESSOR_MANIFEST_HASH",
    )
    manifest = _read_strict_json(manifest_path, "MJOP_PREDECESSOR_MANIFEST")
    _require(
        manifest.get("schema_version")
        == "sporespore_mujoco_warp_metric_semantics_validation_manifest_v1"
        and manifest.get("source_commit") == predecessor["metric_semantics_source_commit"]
        and manifest.get("source_clean") is True
        and manifest.get("source_matches_origin_main") is True,
        "MJOP_PREDECESSOR_MANIFEST_IDENTITY",
    )
    report = manifest.get("report")
    _require(isinstance(report, dict), "MJOP_PREDECESSOR_REPORT_RECORD")
    report_path = Path(_nonempty_string(report.get("path"), "MJOP_PREDECESSOR_REPORT_PATH"))
    _require(report_path.is_file(), "MJOP_PREDECESSOR_REPORT_MISSING", str(report_path))
    _require(
        file_sha256(report_path) == predecessor["metric_semantics_source_report_sha256"]
        == report.get("sha256")
        and report_path.stat().st_size == report.get("byte_length")
        and report.get("passed_cells") == 8
        and report.get("failed_cells") == 0
        and report.get("mutation_control_count") == 52
        and report.get("production_metric_definition_count") == 0
        and report.get("unresolved_metric_count") == 5,
        "MJOP_PREDECESSOR_REPORT_IDENTITY",
    )
    _require(
        manifest.get("production_metric_semantics_complete") is False
        and manifest.get("production_semantic_ceiling_sources_complete") is False
        and manifest.get("production_plan_frozen") is False
        and manifest.get("calibration_executed") is False
        and manifest.get("scientific_result") is False
        and manifest.get("physical_acceptance_authority") is False
        and manifest.get("release_authority") is False,
        "MJOP_PREDECESSOR_AUTHORITY",
    )

    receipt_path = Path(predecessor["metric_semantics_integration_receipt_path"])
    _require(receipt_path.is_file(), "MJOP_PREDECESSOR_RECEIPT_MISSING")
    _require(
        file_sha256(receipt_path)
        == predecessor["metric_semantics_integration_receipt_sha256"]
        and receipt_path.stat().st_size
        == predecessor["metric_semantics_integration_receipt_byte_length"],
        "MJOP_PREDECESSOR_RECEIPT_HASH",
    )
    receipt = _read_strict_json(receipt_path, "MJOP_PREDECESSOR_RECEIPT")
    source = receipt.get("source")
    claims = receipt.get("claims")
    _require(
        receipt.get("schema_version") == "sporespore_conformance_run_observation_v1"
        and receipt.get("status") == "passed"
        and receipt.get("skip_godot") is True
        and isinstance(source, dict)
        and source.get("head") == predecessor["metric_semantics_integration_commit"]
        and source.get("origin_main") == predecessor["metric_semantics_integration_commit"]
        and source.get("worktree_clean") is True
        and source.get("transitive_dependency_key_complete") is False
        and isinstance(claims, dict)
        and claims.get("physical_campaign_executed") is False
        and claims.get("scientific_result") is False
        and claims.get("physical_acceptance_authority") is False
        and claims.get("release_authority") is False,
        "MJOP_PREDECESSOR_RECEIPT_IDENTITY",
    )
    return {
        "metric_contract_sha256": file_sha256(metric_contract_path),
        "metric_compiler_sha256": file_sha256(metric_compiler_path),
        "validation_manifest_sha256": file_sha256(manifest_path),
        "source_report_sha256": file_sha256(report_path),
        "integration_receipt_sha256": file_sha256(receipt_path),
        "production_metric_definition_count": 0,
        "production_metric_semantics_complete": False,
        "physical_authority": False,
    }


def load_observable_projection_contract() -> dict[str, Any]:
    contract = _read_strict_json(CONTRACT_PATH, "MJOP_CONTRACT_MISSING")
    _require(contract.get("schema_version") == CONTRACT_SCHEMA, "MJOP_CONTRACT_SCHEMA")
    _require(
        contract.get("status")
        == "zero_world_source_only_production_topology_bindings_unresolved"
        and contract.get("question_class") == "development",
        "MJOP_CONTRACT_STATUS",
    )
    _require(
        tuple(contract["source_conformance"]["required_cells"]) == REQUIRED_CELLS
        and contract["source_conformance"]["exact_control_count"] == 48
        and contract["source_conformance"]["minimum_rejected_mutation_count"] == 24,
        "MJOP_CONTRACT_CELLS",
    )
    inventory = contract["current_inventory"]
    _require(
        inventory["required_initial_topology_binding_count"] == 1
        and inventory["production_topology_binding_count"] == 0
        and inventory["unresolved_topology_binding_count"] == 1
        and inventory["production_native_observable_binding_complete"] is False
        and inventory["production_metric_definition_count"] == 0
        and inventory["production_metric_semantics_complete"] is False
        and inventory["calibration_authorized"] is False,
        "MJOP_CONTRACT_INVENTORY",
    )
    _require(
        contract["binding_contract"]["schema_version"] == BINDING_SCHEMA
        and contract["native_trace_contract"]["schema_version"] == NATIVE_TRACE_SCHEMA
        and tuple(contract["native_trace_contract"]["required_runtime_roles"])
        == RUNTIME_ROLES
        and contract["native_trace_contract"]["projected_trace_schema"]
        == METRIC_TRACE_SCHEMA,
        "MJOP_CONTRACT_SCHEMAS",
    )
    for field, value in contract["claims"].items():
        _require(value is False, "MJOP_CONTRACT_CLAIM", field)
    for field in (
        "model_construction_count",
        "step_invocation_count",
        "world_attempt_count",
        "world_build_count",
    ):
        _require(contract["source_conformance"][field] == 0, "MJOP_CONTRACT_ZERO_WORLD", field)
    _require(
        contract["source_conformance"]["physics_state_modified"] is False,
        "MJOP_CONTRACT_PHYSICS_STATE",
    )
    _validate_predecessor(contract)
    return contract


def _exact_lifecycle(value: Any, contract: Mapping[str, Any]) -> dict[str, Any]:
    _require(isinstance(value, dict), "MJOP_LIFECYCLE_TYPE")
    _require_fields(value, _LIFECYCLE_FIELDS, "MJOP_LIFECYCLE_FIELDS")
    expected = contract["capture_lifecycle_contract"]
    _require(value == expected, "MJOP_LIFECYCLE_MISMATCH")
    return dict(value)


def _shape(value: Any, code: str) -> tuple[int, ...]:
    _require(isinstance(value, list) and bool(value), code)
    return tuple(_positive_int(item, code) for item in value)


def _compile_layouts(
    value: Any, model: Mapping[str, int], contract: Mapping[str, Any]
) -> dict[str, dict[str, Any]]:
    _require(isinstance(value, list) and len(value) == 2, "MJOP_LAYOUTS_TYPE")
    result: dict[str, dict[str, Any]] = {}
    contact = contract["native_field_projection"]["contact_field"]
    for raw in value:
        _require(isinstance(raw, dict), "MJOP_LAYOUT_TYPE")
        _require_fields(raw, _LAYOUT_FIELDS, "MJOP_LAYOUT_FIELDS")
        role = _nonempty_string(raw["runtime_role"], "MJOP_LAYOUT_ROLE")
        _require(role in RUNTIME_ROLES and role not in result, "MJOP_LAYOUT_ROLE", role)
        nworld = _positive_int(raw["nworld"], "MJOP_LAYOUT_NWORLD")
        world_index = _nonnegative_int(raw["world_index"], "MJOP_LAYOUT_WORLD_INDEX")
        _require(world_index < nworld, "MJOP_LAYOUT_WORLD_INDEX")
        axis = _nonempty_string(raw["world_axis_kind"], "MJOP_LAYOUT_AXIS")
        if role == "cpu_reference":
            _require(nworld == 1 and world_index == 0 and axis == "absent", "MJOP_CPU_LAYOUT")
            expected_shapes = {
                "qpos": (model["nq"],),
                "qvel": (model["nv"],),
                "actuator_force": (model["nu"],),
                "energy": (2,),
            }
            expected_count = contact["cpu_active_count_source"]
            expected_storage = contact["cpu_active_storage"]
        else:
            _require(axis == "leading_nworld", "MJOP_WARP_LAYOUT")
            expected_shapes = {
                "qpos": (nworld, model["nq"]),
                "qvel": (nworld, model["nv"]),
                "actuator_force": (nworld, model["nu"]),
                "energy": (nworld, 2),
            }
            expected_count = contact["warp_active_count_source"]
            expected_storage = contact["warp_active_storage"]
        shapes = raw["field_shapes"]
        _require(isinstance(shapes, dict), "MJOP_LAYOUT_SHAPES_TYPE")
        _require_fields(shapes, _ARRAY_FIELDS, "MJOP_LAYOUT_SHAPE_FIELDS")
        compiled_shapes = {name: _shape(shapes[name], "MJOP_LAYOUT_SHAPE") for name in _ARRAY_FIELDS}
        _require(compiled_shapes == expected_shapes, "MJOP_LAYOUT_SHAPE_MISMATCH", role)
        dtype = _nonempty_string(raw["effective_float_dtype"], "MJOP_LAYOUT_DTYPE")
        _require(dtype in ("float32", "float64"), "MJOP_LAYOUT_DTYPE", dtype)
        _require(raw["effective_dtype_observed"] is True, "MJOP_LAYOUT_DTYPE_UNOBSERVED", role)
        _require(
            raw["contact_count_source"] == expected_count
            and raw["contact_storage_rule"] == expected_storage,
            "MJOP_LAYOUT_CONTACT_SOURCE",
            role,
        )
        result[role] = {
            "runtime_role": role,
            "nworld": nworld,
            "world_index": world_index,
            "world_axis_kind": axis,
            "field_shapes": compiled_shapes,
            "effective_float_dtype": dtype,
            "effective_dtype_observed": True,
            "contact_count_source": expected_count,
            "contact_storage_rule": expected_storage,
        }
    _require(tuple(result) == RUNTIME_ROLES, "MJOP_LAYOUT_ORDER")
    return result


def _index_list(value: Any, upper: int, code: str) -> tuple[int, ...]:
    _require(isinstance(value, list) and bool(value), code)
    result = tuple(_nonnegative_int(item, code) for item in value)
    _require(len(set(result)) == len(result), code, "duplicate")
    _require(all(item < upper for item in result), code, "out_of_range")
    return result


def _compile_components(value: Any, model: Mapping[str, int]) -> tuple[list[dict[str, Any]], dict[str, list[dict[str, Any]]]]:
    _require(isinstance(value, list) and bool(value), "MJOP_COMPONENTS_TYPE")
    ids: set[str] = set()
    coverage: dict[str, list[int]] = {field: [] for field in NATIVE_FIELDS}
    compiled: list[dict[str, Any]] = []
    registries: dict[str, list[dict[str, Any]]] = {name: [] for name in REGISTRY_NAMES}
    field_limits = {
        "qpos": model["nq"],
        "qvel": model["nv"],
        "actuator_force": model["nu"],
    }
    for raw in value:
        _require(isinstance(raw, dict), "MJOP_COMPONENT_TYPE")
        _require_fields(raw, _COMPONENT_FIELDS, "MJOP_COMPONENT_FIELDS")
        component_id = _semantic_id(raw["component_id"], "MJOP_COMPONENT_ID")
        _require(component_id not in ids, "MJOP_COMPONENT_DUPLICATE", component_id)
        ids.add(component_id)
        native_field = _nonempty_string(raw["native_field"], "MJOP_COMPONENT_NATIVE_FIELD")
        _require(native_field in NATIVE_FIELDS, "MJOP_COMPONENT_NATIVE_FIELD", native_field)
        indices = _index_list(
            raw["native_indices"], field_limits[native_field], "MJOP_COMPONENT_INDICES"
        )
        value_kind = _nonempty_string(raw["value_kind"], "MJOP_COMPONENT_VALUE_KIND")
        _require(value_kind in VALUE_KINDS, "MJOP_COMPONENT_VALUE_KIND", value_kind)
        expected_count = 4 if value_kind == "unit_quaternion_wxyz" else 1
        _require(len(indices) == expected_count, "MJOP_COMPONENT_INDEX_COUNT", component_id)
        if value_kind == "unit_quaternion_wxyz":
            _require(
                native_field == "qpos"
                and indices == tuple(range(indices[0], indices[0] + 4))
                and raw["quaternion_input_order"] == "wxyz"
                and raw["unit"] == "unit_quaternion",
                "MJOP_COMPONENT_QUATERNION",
                component_id,
            )
        else:
            _require(raw["quaternion_input_order"] is None, "MJOP_COMPONENT_SCALAR_ORDER", component_id)
        registry_names = raw["registries"]
        _require(isinstance(registry_names, list), "MJOP_COMPONENT_REGISTRIES")
        if native_field in ("qpos", "qvel"):
            _require(
                tuple(registry_names) == ("state", "pose_velocity"),
                "MJOP_COMPONENT_REGISTRIES",
                component_id,
            )
        else:
            _require(
                tuple(registry_names) == ("actuator",),
                "MJOP_COMPONENT_REGISTRIES",
                component_id,
            )
        quantity = _nonempty_string(raw["quantity"], "MJOP_COMPONENT_QUANTITY")
        unit = _nonempty_string(raw["unit"], "MJOP_COMPONENT_UNIT")
        component = {
            "component_id": component_id,
            "registries": tuple(registry_names),
            "native_field": native_field,
            "native_indices": indices,
            "quantity": quantity,
            "unit": unit,
            "value_kind": value_kind,
            "quaternion_input_order": raw["quaternion_input_order"],
        }
        compiled.append(component)
        coverage[native_field].extend(indices)
        for registry_name in registry_names:
            registries[registry_name].append(component)
    for field, limit in field_limits.items():
        _require(sorted(coverage[field]) == list(range(limit)), "MJOP_COMPONENT_COVERAGE", field)
    _require(
        [item["component_id"] for item in registries["state"]]
        == [item["component_id"] for item in registries["pose_velocity"]],
        "MJOP_STATE_POSE_ORDER",
    )
    _require(bool(registries["actuator"]), "MJOP_ACTUATOR_REGISTRY_EMPTY")
    return compiled, registries


def _geom_ids(value: Any, ngeom: int, code: str) -> tuple[int, ...]:
    _require(isinstance(value, list) and bool(value), code)
    result = tuple(_nonnegative_int(item, code) for item in value)
    _require(len(set(result)) == len(result) and all(item < ngeom for item in result), code)
    return result


def _compile_contact_bindings(
    raw_bindings: Any, raw_ignored: Any, ngeom: int
) -> tuple[list[dict[str, Any]], set[tuple[int, int]]]:
    _require(isinstance(raw_bindings, list) and bool(raw_bindings), "MJOP_CONTACT_BINDINGS_TYPE")
    body_pairs: set[str] = set()
    site_ids: set[str] = set()
    site_geom_owners: dict[int, str] = {}
    compiled: list[dict[str, Any]] = []
    for raw in raw_bindings:
        _require(isinstance(raw, dict), "MJOP_CONTACT_BINDING_TYPE")
        _require_fields(raw, _CONTACT_BINDING_FIELDS, "MJOP_CONTACT_BINDING_FIELDS")
        pair_id = _semantic_id(raw["body_pair_id"], "MJOP_CONTACT_BODY_PAIR")
        site_id = _semantic_id(raw["contact_site_id"], "MJOP_CONTACT_SITE")
        _require(pair_id not in body_pairs and site_id not in site_ids, "MJOP_CONTACT_ID_DUPLICATE")
        body_pairs.add(pair_id)
        site_ids.add(site_id)
        site_geoms = _geom_ids(raw["contact_site_geom_ids"], ngeom, "MJOP_CONTACT_SITE_GEOMS")
        environment_geoms = _geom_ids(raw["environment_geom_ids"], ngeom, "MJOP_CONTACT_ENV_GEOMS")
        _require(set(site_geoms).isdisjoint(environment_geoms), "MJOP_CONTACT_GEOM_OVERLAP", pair_id)
        for geom in site_geoms:
            _require(geom not in site_geom_owners, "MJOP_CONTACT_SITE_GEOM_REUSED", geom)
            site_geom_owners[geom] = pair_id
        compiled.append(
            {
                "body_pair_id": pair_id,
                "contact_site_id": site_id,
                "contact_site_geom_ids": site_geoms,
                "environment_geom_ids": environment_geoms,
            }
        )
    _require([item["body_pair_id"] for item in compiled] == sorted(body_pairs), "MJOP_CONTACT_BINDING_ORDER")

    _require(isinstance(raw_ignored, list), "MJOP_IGNORED_PAIRS_TYPE")
    ignored: set[tuple[int, int]] = set()
    for raw in raw_ignored:
        _require(isinstance(raw, dict), "MJOP_IGNORED_PAIR_TYPE")
        _require_fields(raw, _IGNORED_PAIR_FIELDS, "MJOP_IGNORED_PAIR_FIELDS")
        first = _nonnegative_int(raw["geom_id_a"], "MJOP_IGNORED_PAIR_GEOM")
        second = _nonnegative_int(raw["geom_id_b"], "MJOP_IGNORED_PAIR_GEOM")
        _require(first < second < ngeom, "MJOP_IGNORED_PAIR_ORDER")
        pair = (first, second)
        _require(pair not in ignored, "MJOP_IGNORED_PAIR_DUPLICATE", pair)
        _require(raw["chosen_before_outcomes"] is True, "MJOP_IGNORED_PAIR_POSTOUTCOME", pair)
        _require(
            isinstance(raw["adequacy_argument"], str)
            and len(raw["adequacy_argument"].strip()) >= 24,
            "MJOP_IGNORED_PAIR_ADEQUACY",
            pair,
        )
        ignored.add(pair)
    return compiled, ignored


def compile_observable_binding(binding: dict[str, Any]) -> dict[str, Any]:
    """Compile one fixture-only model binding without importing a physics runtime."""

    contract = load_observable_projection_contract()
    _require(isinstance(binding, dict), "MJOP_BINDING_TYPE")
    _require_fields(binding, _BINDING_FIELDS, "MJOP_BINDING_FIELDS")
    _require(binding["schema_version"] == BINDING_SCHEMA, "MJOP_BINDING_SCHEMA")
    binding_id = _semantic_id(binding["binding_id"], "MJOP_BINDING_ID")
    expected_contract_hash = file_sha256(CONTRACT_PATH)
    _require(
        _sha256_text(binding["contract_raw_sha256"], "MJOP_BINDING_CONTRACT_HASH")
        == expected_contract_hash,
        "MJOP_BINDING_CONTRACT_BINDING",
    )
    _require(binding["fixture_only"] is True, "MJOP_BINDING_FIXTURE_ONLY")
    topology = _semantic_id(binding["topology_bucket_id"], "MJOP_BINDING_TOPOLOGY")

    model_raw = binding["model_identity"]
    _require(isinstance(model_raw, dict), "MJOP_MODEL_TYPE")
    _require_fields(model_raw, _MODEL_FIELDS, "MJOP_MODEL_FIELDS")
    model: dict[str, Any] = {
        "model_sha256": _sha256_text(model_raw["model_sha256"], "MJOP_MODEL_SHA"),
        "morphology_sha256": _sha256_text(
            model_raw["morphology_sha256"], "MJOP_MORPHOLOGY_SHA"
        ),
        "nq": _positive_int(model_raw["nq"], "MJOP_MODEL_NQ"),
        "nv": _positive_int(model_raw["nv"], "MJOP_MODEL_NV"),
        "nu": _positive_int(model_raw["nu"], "MJOP_MODEL_NU"),
        "ngeom": _positive_int(model_raw["ngeom"], "MJOP_MODEL_NGEOM"),
        "nsite": _positive_int(model_raw["nsite"], "MJOP_MODEL_NSITE"),
        "energy_enabled": model_raw["energy_enabled"],
        "unsupported_sensor_features_absent": model_raw[
            "unsupported_sensor_features_absent"
        ],
    }
    _require(
        model["energy_enabled"] is True
        and model["unsupported_sensor_features_absent"] is True,
        "MJOP_MODEL_FEATURES",
    )
    lifecycle = _exact_lifecycle(binding["capture_lifecycle"], contract)
    layouts = _compile_layouts(binding["runtime_layouts"], model, contract)
    components, registries = _compile_components(binding["components"], model)
    contact_bindings, ignored_pairs = _compile_contact_bindings(
        binding["contact_site_bindings"], binding["ignored_contact_pairs"], model["ngeom"]
    )
    _require(
        binding["unmapped_included_contact_disposition"] == "exact_failure",
        "MJOP_UNMAPPED_CONTACT_DISPOSITION",
    )
    for field in ("normalization_scales_installed", "semantic_ceilings_installed", "production_binding"):
        _require(binding[field] is False, "MJOP_BINDING_AUTHORITY", field)
    for field in (
        "model_construction_count",
        "step_invocation_count",
        "world_attempt_count",
        "world_build_count",
    ):
        _require(_nonnegative_int(binding[field], "MJOP_BINDING_ZERO_WORLD") == 0, "MJOP_BINDING_ZERO_WORLD", field)
    for field in ("physics_state_modified", "scientific_result", "physical_acceptance_authority", "release_authority"):
        _require(binding[field] is False, "MJOP_BINDING_AUTHORITY", field)

    return {
        "schema_version": BINDING_SCHEMA,
        "binding_id": binding_id,
        "binding_sha256": canonical_sha256(binding),
        "contract_raw_sha256": expected_contract_hash,
        "fixture_only": True,
        "topology_bucket_id": topology,
        "model_identity": model,
        "capture_lifecycle": lifecycle,
        "runtime_layouts": layouts,
        "components": components,
        "registries": registries,
        "contact_site_bindings": contact_bindings,
        "ignored_contact_pairs": ignored_pairs,
        "unmapped_included_contact_disposition": "exact_failure",
        "fixture_binding_complete": True,
        "production_binding": False,
        "normalization_scales_installed": False,
        "semantic_ceilings_installed": False,
        "production_metric_semantics_complete": False,
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


def _validate_array_shape(value: Any, shape: Sequence[int], code: str) -> Any:
    if not shape:
        return _finite_number(value, code)
    _require(isinstance(value, list) and len(value) == shape[0], code, {"expected": list(shape)})
    return [_validate_array_shape(item, shape[1:], code) for item in value]


def _selected_vector(arrays: Mapping[str, Any], layout: Mapping[str, Any], field: str) -> list[float]:
    value = arrays[field]
    if layout["world_axis_kind"] == "leading_nworld":
        value = value[layout["world_index"]]
    _require(isinstance(value, list), "MJOP_PROJECT_VECTOR", field)
    return [float(item) for item in value]


def _project_component(vector: Sequence[float], component: Mapping[str, Any]) -> float | list[float]:
    indices = component["native_indices"]
    if component["value_kind"] == "unit_quaternion_wxyz":
        quaternion = [float(vector[index]) for index in indices]
        norm = math.sqrt(sum(item * item for item in quaternion))
        _require(norm > 0.0 and math.isfinite(norm), "MJOP_PROJECT_QUATERNION_NORM", component["component_id"])
        return quaternion
    return float(vector[indices[0]])


def _canonical_geom_pair(first: int, second: int) -> tuple[int, int]:
    return (first, second) if first < second else (second, first)


def _match_contact_pair(
    first: int, second: int, bindings: Sequence[Mapping[str, Any]]
) -> str | None:
    matches: list[str] = []
    for binding in bindings:
        site = set(binding["contact_site_geom_ids"])
        environment = set(binding["environment_geom_ids"])
        if (first in site and second in environment) or (second in site and first in environment):
            matches.append(binding["body_pair_id"])
    _require(len(matches) <= 1, "MJOP_CONTACT_AMBIGUOUS", (first, second))
    return matches[0] if matches else None


def _project_snapshot(
    compiled_binding: Mapping[str, Any], snapshot: Any, expected_step: int, expected_role: str
) -> tuple[dict[str, Any], dict[str, bool], list[str]]:
    _require(isinstance(snapshot, dict), "MJOP_SNAPSHOT_TYPE")
    _require_fields(snapshot, _SNAPSHOT_FIELDS, "MJOP_SNAPSHOT_FIELDS")
    _require(snapshot["schema_version"] == "sporespore_mujoco_warp_native_snapshot_fixture_v1", "MJOP_SNAPSHOT_SCHEMA")
    _require(snapshot["binding_sha256"] == compiled_binding["binding_sha256"], "MJOP_SNAPSHOT_BINDING")
    _require(snapshot["runtime_role"] == expected_role, "MJOP_SNAPSHOT_ROLE")
    _require(_nonnegative_int(snapshot["semantic_step"], "MJOP_SNAPSHOT_STEP") == expected_step, "MJOP_SNAPSHOT_STEP_ORDER")
    layout = compiled_binding["runtime_layouts"][expected_role]
    expected_capture = compiled_binding["capture_lifecycle"][
        "cpu_capture_point" if expected_role == "cpu_reference" else "warp_capture_point"
    ]
    _require(snapshot["capture_point"] == expected_capture, "MJOP_SNAPSHOT_CAPTURE_POINT")
    _require(snapshot["effective_float_dtype"] == layout["effective_float_dtype"], "MJOP_SNAPSHOT_DTYPE")
    arrays_raw = snapshot["arrays"]
    _require(isinstance(arrays_raw, dict), "MJOP_SNAPSHOT_ARRAYS_TYPE")
    _require_fields(arrays_raw, _ARRAY_FIELDS, "MJOP_SNAPSHOT_ARRAY_FIELDS")
    arrays = {
        field: _validate_array_shape(arrays_raw[field], layout["field_shapes"][field], "MJOP_SNAPSHOT_ARRAY_SHAPE")
        for field in _ARRAY_FIELDS
    }
    vectors = {field: _selected_vector(arrays, layout, field) for field in NATIVE_FIELDS}
    energy_vector = _selected_vector(arrays, layout, "energy")

    component_values: dict[str, float | list[float]] = {}
    for component in compiled_binding["components"]:
        component_values[component["component_id"]] = _project_component(
            vectors[component["native_field"]], component
        )
    sample = {
        "step_index": expected_step,
        "state": {
            item["component_id"]: component_values[item["component_id"]]
            for item in compiled_binding["registries"]["state"]
        },
        "actuator": {
            item["component_id"]: component_values[item["component_id"]]
            for item in compiled_binding["registries"]["actuator"]
        },
        "pose_velocity": {
            item["component_id"]: component_values[item["component_id"]]
            for item in compiled_binding["registries"]["pose_velocity"]
        },
        "energy_j": float(energy_vector[0] + energy_vector[1]),
    }

    failures_raw = snapshot["exact_failures"]
    _require(isinstance(failures_raw, list), "MJOP_SNAPSHOT_FAILURES_TYPE")
    failures = [_nonempty_string(item, "MJOP_SNAPSHOT_FAILURE_CODE") for item in failures_raw]
    _require(failures == sorted(set(failures)), "MJOP_SNAPSHOT_FAILURE_ORDER")

    contacts = snapshot["contacts"]
    _require(isinstance(contacts, dict), "MJOP_SNAPSHOT_CONTACTS_TYPE")
    _require_fields(contacts, _CONTACT_FIELDS, "MJOP_SNAPSHOT_CONTACT_FIELDS")
    active_count = _nonnegative_int(contacts["active_count"], "MJOP_CONTACT_ACTIVE_COUNT")
    capacity = _positive_int(contacts["capacity"], "MJOP_CONTACT_CAPACITY")
    _require(active_count <= capacity, "MJOP_CONTACT_ACTIVE_EXCEEDS_CAPACITY")
    _require(isinstance(contacts["overflow"], bool), "MJOP_CONTACT_OVERFLOW_TYPE")
    records = contacts["records"]
    _require(isinstance(records, list) and len(records) == active_count, "MJOP_CONTACT_RECORD_COUNT")
    if contacts["overflow"]:
        failures.append("contact_capacity_overflow")

    presence = {item["body_pair_id"]: False for item in compiled_binding["contact_site_bindings"]}
    ignored_pairs = compiled_binding["ignored_contact_pairs"]
    for record in records:
        _require(isinstance(record, dict), "MJOP_CONTACT_RECORD_TYPE")
        if expected_role == "cpu_reference":
            _require_fields(record, _CPU_CONTACT_RECORD_FIELDS, "MJOP_CPU_CONTACT_RECORD_FIELDS")
            selected_world = True
            constraint_bit_present = True
        else:
            _require_fields(record, _WARP_CONTACT_RECORD_FIELDS, "MJOP_WARP_CONTACT_RECORD_FIELDS")
            record_world = _nonnegative_int(record["world_index"], "MJOP_WARP_CONTACT_WORLD")
            _require(record_world < layout["nworld"], "MJOP_WARP_CONTACT_WORLD")
            selected_world = record_world == layout["world_index"]
            contact_bits = _nonnegative_int(record["contact_type_bits"], "MJOP_WARP_CONTACT_BITS")
            constraint_bit_present = bool(contact_bits & 1)
        first = _nonnegative_int(record["geom1"], "MJOP_CONTACT_GEOM")
        second = _nonnegative_int(record["geom2"], "MJOP_CONTACT_GEOM")
        _require(first < compiled_binding["model_identity"]["ngeom"] and second < compiled_binding["model_identity"]["ngeom"] and first != second, "MJOP_CONTACT_GEOM")
        _require(isinstance(record["included_in_constraint"], bool), "MJOP_CONTACT_INCLUDED_TYPE")
        if not selected_world or not record["included_in_constraint"]:
            continue
        if not constraint_bit_present:
            failures.append(f"warp_included_contact_missing_constraint_bit:{first}:{second}")
            continue
        pair = _canonical_geom_pair(first, second)
        matched = _match_contact_pair(first, second, compiled_binding["contact_site_bindings"])
        if matched is not None:
            presence[matched] = True
        elif pair not in ignored_pairs:
            failures.append(f"unmapped_included_contact:{pair[0]}:{pair[1]}")

    _require(snapshot["fixture_only"] is True, "MJOP_SNAPSHOT_FIXTURE_ONLY")
    for field in ("model_construction_count", "step_invocation_count", "world_attempt_count", "world_build_count"):
        _require(_nonnegative_int(snapshot[field], "MJOP_SNAPSHOT_ZERO_WORLD") == 0, "MJOP_SNAPSHOT_ZERO_WORLD", field)
    _require(snapshot["physics_state_modified"] is False, "MJOP_SNAPSHOT_PHYSICS_STATE")
    return sample, presence, failures


def project_native_trace(
    compiled_binding: dict[str, Any], native_trace: dict[str, Any]
) -> dict[str, Any]:
    """Project one synthetic native trace into an exact MJMS fixture trace."""

    _require(
        compiled_binding.get("schema_version") == BINDING_SCHEMA
        and compiled_binding.get("fixture_binding_complete") is True
        and compiled_binding.get("fixture_only") is True,
        "MJOP_PROJECT_BINDING",
    )
    _require(isinstance(native_trace, dict), "MJOP_TRACE_TYPE")
    _require_fields(native_trace, _NATIVE_TRACE_FIELDS, "MJOP_TRACE_FIELDS")
    _require(native_trace["schema_version"] == NATIVE_TRACE_SCHEMA, "MJOP_TRACE_SCHEMA")
    trace_id = _semantic_id(native_trace["trace_id"], "MJOP_TRACE_ID")
    _require(native_trace["binding_sha256"] == compiled_binding["binding_sha256"], "MJOP_TRACE_BINDING")
    suite_sha = _sha256_text(native_trace["suite_sha256"], "MJOP_TRACE_SUITE_HASH")
    role = _nonempty_string(native_trace["runtime_role"], "MJOP_TRACE_ROLE")
    _require(role in RUNTIME_ROLES, "MJOP_TRACE_ROLE")
    horizon = _positive_int(native_trace["horizon_steps"], "MJOP_TRACE_HORIZON")
    snapshots = native_trace["snapshots"]
    _require(isinstance(snapshots, list) and len(snapshots) == horizon + 1, "MJOP_TRACE_SNAPSHOT_COUNT")

    samples: list[dict[str, Any]] = []
    events: list[dict[str, Any]] = []
    failure_records: list[dict[str, Any]] = []
    prior_presence: dict[str, bool] | None = None
    occurrences: dict[tuple[str, str], int] = {}
    for step, snapshot in enumerate(snapshots):
        sample, presence, failures = _project_snapshot(compiled_binding, snapshot, step, role)
        samples.append(sample)
        for failure in failures:
            failure_records.append({"step_index": step, "failure_code": failure})
        if prior_presence is not None:
            for pair_id in sorted(presence):
                if presence[pair_id] == prior_presence[pair_id]:
                    continue
                kind = "contact_begin" if presence[pair_id] else "contact_end"
                key = (pair_id, kind)
                occurrence = occurrences.get(key, 0) + 1
                occurrences[key] = occurrence
                events.append(
                    {
                        "body_pair_id": pair_id,
                        "event_kind": kind,
                        "occurrence_index": occurrence,
                        "step_index": step,
                    }
                )
        prior_presence = presence
    events.sort(key=lambda item: (item["body_pair_id"], item["event_kind"], item["occurrence_index"]))

    _require(native_trace["fixture_only"] is True, "MJOP_TRACE_FIXTURE_ONLY")
    for field in ("model_construction_count", "step_invocation_count", "world_attempt_count", "world_build_count"):
        _require(_nonnegative_int(native_trace[field], "MJOP_TRACE_ZERO_WORLD") == 0, "MJOP_TRACE_ZERO_WORLD", field)
    _require(native_trace["physics_state_modified"] is False, "MJOP_TRACE_PHYSICS_STATE")

    metric_trace = {
        "schema_version": METRIC_TRACE_SCHEMA,
        "trace_id": trace_id,
        "suite_sha256": suite_sha,
        "runtime_role": role,
        "horizon_steps": horizon,
        "samples": samples,
        "contact_events": events,
        "exact_failure_count": len(failure_records),
        "fixture_only": True,
        "model_construction_count": 0,
        "step_invocation_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physics_state_modified": False,
    }
    return {
        "schema_version": PROJECTION_RECEIPT_SCHEMA,
        "ok": True,
        "fixture_only": True,
        "trace_id": trace_id,
        "runtime_role": role,
        "binding_sha256": compiled_binding["binding_sha256"],
        "native_trace_sha256": canonical_sha256(native_trace),
        "metric_trace_sha256": canonical_sha256(metric_trace),
        "metric_trace": metric_trace,
        "failure_records": failure_records,
        "metric_trace_eligible": len(failure_records) == 0,
        "production_binding": False,
        "production_metric_semantics_complete": False,
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


def compile_current_observable_projection_inventory() -> dict[str, Any]:
    """Return the deliberately incomplete production-binding inventory."""

    contract = load_observable_projection_contract()
    inventory = contract["current_inventory"]
    return {
        "schema_version": "sporespore_mujoco_warp_observable_projection_inventory_v1",
        "inventory_id": inventory["inventory_id"],
        "contract_raw_sha256": file_sha256(CONTRACT_PATH),
        "required_initial_topology_binding_count": 1,
        "required_initial_topology_bucket": inventory["required_initial_topology_bucket"],
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
        "scientific_result": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
