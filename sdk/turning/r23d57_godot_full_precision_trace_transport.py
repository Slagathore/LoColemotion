"""Zero-world cross-runtime float-transport gate for QSDK-R23D57.

The Godot half emits production-shaped actuator applications twice: once with
Godot's default JSON float formatting and once with ``full_precision=true``.
This validator independently decodes both forms, applies the unchanged R23D56
consistency predicate, verifies binary64 round trips, and exercises negative
controls.  It never creates or opens a physics world.
"""

from __future__ import annotations

import argparse
import copy
import json
import math
from pathlib import Path
import struct
import subprocess
import sys
from typing import Any, Mapping, Sequence


REPO_ROOT = Path(__file__).resolve().parents[2]
CONTRACT_PATH = (
    REPO_ROOT
    / "sdk"
    / "turning"
    / "r23d57_godot_full_precision_trace_transport_contract_v1.json"
)
GODOT_SCRIPT = (
    "res://tests/"
    "test_sdk_qsdk_r23d57_godot_full_precision_trace_transport.gd"
)
RECEIPT_MARKER = "QSDK_R23D57_GODOT_FULL_PRECISION_TRACE_TRANSPORT "
PASS_MARKER = "QSDK_R23D57_FULL_PRECISION_TRACE_TRANSPORT_PASS "
EXPECTED_CONTRACT_ID = "QSDK-R23D57-GODOT-FULL-PRECISION-TRACE-TRANSPORT"
EXPECTED_RECEIPT_SCHEMA = (
    "sporespore_qsdk_r23d57_godot_full_precision_trace_transport_receipt_v1"
)
EXPECTED_FIXED_IDS = (
    "retained_r23d56_first_failure_shape",
    "independent_positive_unit_scale",
    "independent_negative_fractional_scale",
)
NUMERIC_FIELDS = (
    "host_applied_target_velocity_rad_s",
    "motor_target_velocity_readback_rad_s",
    "motor_target_velocity_readback_error_rad_s",
    "declared_maximum_impulse_nms",
    "motor_maximum_impulse_readback_nms",
    "motor_maximum_impulse_readback_error_nms",
)
APPLICATION_FIELDS = frozenset(("actuator_id", *NUMERIC_FIELDS))
FIXTURE_FIELDS = frozenset(
    (
        "fixture_id",
        "source_application",
        "default_json",
        "full_precision_json",
    )
)


class R23D57TransportError(RuntimeError):
    """The zero-world transport contract or receipt is not satisfied."""


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise R23D57TransportError(message)


def _load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def _finite_float(value: Any, label: str) -> float:
    _require(not isinstance(value, bool), f"{label} is Boolean, not numeric")
    try:
        result = float(value)
    except (TypeError, ValueError) as error:
        raise R23D57TransportError(f"{label} is not numeric") from error
    _require(math.isfinite(result), f"{label} is not finite")
    return result


def _binary64(value: Any, label: str) -> bytes:
    return struct.pack(">d", _finite_float(value, label))


def _same_binary64(left: Any, right: Any, label: str) -> bool:
    return _binary64(left, f"{label}.left") == _binary64(
        right, f"{label}.right"
    )


def _target_residual(application: Mapping[str, Any], label: str) -> float:
    applied = _finite_float(
        application.get("host_applied_target_velocity_rad_s"),
        f"{label}.host_applied_target_velocity_rad_s",
    )
    readback = _finite_float(
        application.get("motor_target_velocity_readback_rad_s"),
        f"{label}.motor_target_velocity_readback_rad_s",
    )
    reported = _finite_float(
        application.get("motor_target_velocity_readback_error_rad_s"),
        f"{label}.motor_target_velocity_readback_error_rad_s",
    )
    return abs(reported - abs(readback - applied))


def _impulse_residual(application: Mapping[str, Any], label: str) -> float:
    declared = _finite_float(
        application.get("declared_maximum_impulse_nms"),
        f"{label}.declared_maximum_impulse_nms",
    )
    readback = _finite_float(
        application.get("motor_maximum_impulse_readback_nms"),
        f"{label}.motor_maximum_impulse_readback_nms",
    )
    reported = _finite_float(
        application.get("motor_maximum_impulse_readback_error_nms"),
        f"{label}.motor_maximum_impulse_readback_error_nms",
    )
    return abs(reported - abs(readback - declared))


def _target_error(application: Mapping[str, Any], label: str) -> float:
    return abs(
        _finite_float(
            application.get("motor_target_velocity_readback_rad_s"),
            f"{label}.motor_target_velocity_readback_rad_s",
        )
        - _finite_float(
            application.get("host_applied_target_velocity_rad_s"),
            f"{label}.host_applied_target_velocity_rad_s",
        )
    )


def _impulse_error(application: Mapping[str, Any], label: str) -> float:
    return abs(
        _finite_float(
            application.get("motor_maximum_impulse_readback_nms"),
            f"{label}.motor_maximum_impulse_readback_nms",
        )
        - _finite_float(
            application.get("declared_maximum_impulse_nms"),
            f"{label}.declared_maximum_impulse_nms",
        )
    )


def _validate_contract(contract: Mapping[str, Any]) -> dict[str, Any]:
    _require(
        contract.get("schema_version")
        == "sporespore_qsdk_r23d57_godot_full_precision_trace_transport_contract_v1"
        and contract.get("status") == "prospective_zero_world_transport_gate_only"
        and contract.get("campaign_id")
        == (
            "QSDK-R23D57-GODOT-FULL-PRECISION-TRACE-ACTUATOR-PHASE-"
            "CHARACTERIZATION-DEVELOPMENT"
        )
        and contract.get("gate_id") == "QSDK-R23D57"
        and contract.get("contract_id") == EXPECTED_CONTRACT_ID
        and contract.get("question_class") == "development"
        and contract.get("physical_question_declared") is True
        and contract.get("physical_campaign_opened") is False,
        "contract identity, status, or question class changed",
    )

    parent = contract.get("immutable_parent")
    _require(isinstance(parent, dict), "immutable parent is missing")
    _require(
        parent.get("r23d56_closure_raw_sha256")
        == "sha256:34d165fb8aaad4321e2c28e992cd66221179fe2d791aae977528c23227013531"
        and parent.get("r23d56_identity_consumed") is True
        and parent.get("r23d56_rerun_allowed") is False
        and parent.get("r23d56_result_reinterpreted") is False
        and parent.get("r23d56_root_failure_code")
        == "QSDK_R23D56_GJT_TRACE_RETENTION_FAILED:1"
        and parent.get("r23d56_target_report_consistency_failure_count") == 2203
        and parent.get("r23d56_other_primitive_actuator_link_failure_count") == 0
        and parent.get("retained_r23d56_rows_may_be_promoted_to_r23d57_evidence")
        is False,
        "immutable R23D56 parent boundary changed",
    )

    successor = contract.get("scientifically_distinct_successor")
    _require(isinstance(successor, dict), "successor declaration is missing")
    _require(
        successor.get("declared_physics_model_change_count") == 0
        and successor.get("declared_controller_change_count") == 0
        and successor.get("declared_measurement_change_count") == 0
        and successor.get("declared_threshold_change_count") == 0
        and successor.get("declared_evidence_transport_change_count") == 1
        and "JSON.stringify(rows, \"\", true, true)"
        in str(successor.get("only_declared_transport_change", ""))
        and successor.get("historical_world_reused_as_r23d57_cell") is False
        and successor.get("r23d56_terminal_or_trace_reused_as_r23d57_cell")
        is False
        and successor.get("fresh_worlds_required_for_any_r23d57_physical_result")
        is True,
        "scientifically distinct successor boundary changed",
    )

    api = contract.get("godot_api_authority")
    _require(isinstance(api, dict), "Godot API authority is missing")
    _require(
        api.get("version") == "4.7-stable"
        and api.get("method_signature")
        == (
            "String stringify(data: Variant, indent: String = \"\", "
            "sort_keys: bool = true, full_precision: bool = false) static"
        )
        and api.get("selected_invocation") == 'JSON.stringify(data, "", true, true)'
        and api.get("context7_library_id") == "/websites/godotengine_en_4_7",
        "Godot JSON.stringify API authority changed",
    )

    numeric = contract.get("numeric_semantics")
    _require(isinstance(numeric, dict), "numeric semantics are missing")
    readback_tolerance = _finite_float(
        numeric.get("configured_readback_tolerance"),
        "numeric_semantics.configured_readback_tolerance",
    )
    consistency_tolerance = _finite_float(
        numeric.get("reported_error_recomputation_consistency_tolerance"),
        "numeric_semantics.reported_error_recomputation_consistency_tolerance",
    )
    _require(
        readback_tolerance == 2.5e-7
        and consistency_tolerance == 1.0e-15
        and numeric.get("configured_readback_and_transport_consistency_tolerances_are_distinct")
        is True
        and numeric.get("new_empirical_threshold_count") == 0
        and numeric.get("threshold_change_count") == 0
        and numeric.get("r23d56_observed_maximum_used_to_set_tolerance") is False
        and numeric.get("population_margin") is False
        and numeric.get("cross_engine_equivalence_margin") is False,
        "threshold identity, provenance, or adequacy changed",
    )

    canary = contract.get("zero_world_canary")
    _require(isinstance(canary, dict), "zero-world canary declaration is missing")
    _require(
        canary.get("godot_path")
        == "tests/test_sdk_qsdk_r23d57_godot_full_precision_trace_transport.gd"
        and canary.get("python_path")
        == "sdk/turning/r23d57_godot_full_precision_trace_transport.py"
        and canary.get("receipt_schema") == EXPECTED_RECEIPT_SCHEMA
        and canary.get("fixture_count") == 35
        and canary.get("retained_failure_shape_fixture_count") == 1
        and canary.get("independent_literal_fixture_count") == 2
        and canary.get("deterministic_cancellation_fixture_count") == 32
        and canary.get("default_serialization_expected_target_failure_count") == 14
        and canary.get("default_serialization_expected_impulse_failure_count") == 0
        and canary.get("full_precision_expected_target_failure_count") == 0
        and canary.get("full_precision_expected_impulse_failure_count") == 0
        and canary.get("full_precision_binary64_operand_roundtrip_mismatch_count") == 0
        and canary.get("required_mutation_rejection_count") == 12
        and canary.get("required_boundary_control_count") == 2
        and all(
            canary.get(field) == 0
            for field in (
                "scene_tree_insertion_count",
                "model_construction_count",
                "controller_step_count",
                "world_attempt_count",
                "world_build_count",
            )
        ),
        "zero-world canary cohort, controls, or boundary changed",
    )

    implementation = contract.get("implementation_boundary")
    claims = contract.get("claims")
    _require(
        isinstance(implementation, dict)
        and all(value is False for value in implementation.values()),
        "physical implementation boundary opened before the zero-world gate",
    )
    _require(isinstance(claims, dict), "claim boundary is missing")
    _require(
        claims.get("zero_world_transport_contract_declared") is True
        and all(
            value is False
            for key, value in claims.items()
            if key != "zero_world_transport_contract_declared"
        ),
        "claim boundary broadened before the zero-world gate",
    )
    return {
        "readback_tolerance": readback_tolerance,
        "consistency_tolerance": consistency_tolerance,
        "canary": canary,
    }


def _parse_application(value: Any, label: str) -> dict[str, Any]:
    _require(isinstance(value, dict), f"{label} is not an object")
    _require(set(value) == APPLICATION_FIELDS, f"{label} field set changed")
    _require(
        value.get("actuator_id") == "front_left_knee_motor",
        f"{label} actuator identity changed",
    )
    for field in NUMERIC_FIELDS:
        _finite_float(value[field], f"{label}.{field}")
    return value


def _decode_application(value: Any, label: str) -> dict[str, Any]:
    _require(isinstance(value, str), f"{label} is not a JSON string")
    try:
        decoded = json.loads(value)
    except json.JSONDecodeError as error:
        raise R23D57TransportError(f"{label} is invalid JSON") from error
    return _parse_application(decoded, label)


def _expected_fixture_ids() -> tuple[str, ...]:
    return EXPECTED_FIXED_IDS + tuple(
        f"deterministic_cancellation_{index:02d}" for index in range(1, 33)
    )


def _validate_receipt(
    receipt: Mapping[str, Any],
    contract_values: Mapping[str, Any],
) -> dict[str, Any]:
    _require(isinstance(receipt, dict), "Godot receipt is not an object")
    _require(
        receipt.get("schema_version") == EXPECTED_RECEIPT_SCHEMA
        and receipt.get("contract_id") == EXPECTED_CONTRACT_ID,
        "Godot receipt identity changed",
    )
    version = receipt.get("godot_version")
    _require(isinstance(version, dict), "Godot version receipt is missing")
    _require(
        version.get("major") == 4
        and version.get("minor") == 7
        and version.get("status") == "stable",
        "Godot runtime is not the declared 4.7-stable line",
    )
    _require(
        receipt.get("json_stringify_signature")
        == 'JSON.stringify(data, indent="", sort_keys=true, full_precision=false)'
        and receipt.get("full_precision_argument_explicit") is True
        and receipt.get("full_precision_argument_value") is True
        and receipt.get("sort_keys_argument_value") is True,
        "Godot serialization invocation declaration changed",
    )

    tolerance = _finite_float(
        receipt.get("inherited_consistency_tolerance"),
        "receipt.inherited_consistency_tolerance",
    )
    readback_tolerance = _finite_float(
        receipt.get("configured_readback_tolerance"),
        "receipt.configured_readback_tolerance",
    )
    _require(
        tolerance == contract_values["consistency_tolerance"]
        and readback_tolerance == contract_values["readback_tolerance"],
        "receipt changed an inherited tolerance",
    )
    _require(
        all(
            receipt.get(field) == 0
            for field in (
                "scene_tree_insertion_count",
                "model_construction_count",
                "controller_step_count",
                "world_attempt_count",
                "world_build_count",
            )
        )
        and receipt.get("physics_state_modified") is False
        and receipt.get("turning_claimed") is False
        and receipt.get("prone_to_standing_claimed") is False
        and receipt.get("physical_acceptance_authority") is False,
        "zero-world or claim boundary changed",
    )

    fixtures = receipt.get("fixtures")
    _require(isinstance(fixtures, list), "receipt fixtures are not a list")
    expected_ids = _expected_fixture_ids()
    _require(
        receipt.get("fixture_count") == len(fixtures) == len(expected_ids),
        "fixture cardinality changed",
    )
    actual_ids = tuple(
        str(fixture.get("fixture_id", "")) if isinstance(fixture, dict) else ""
        for fixture in fixtures
    )
    _require(actual_ids == expected_ids, "fixture identity or order changed")

    counts = {
        "default_target": 0,
        "default_impulse": 0,
        "full_target": 0,
        "full_impulse": 0,
        "full_binary64_mismatch": 0,
    }
    maxima = {
        "default_target": 0.0,
        "default_impulse": 0.0,
        "full_target": 0.0,
        "full_impulse": 0.0,
    }
    default_target_failure_ids: list[str] = []

    for index, fixture in enumerate(fixtures):
        fixture_label = f"fixtures[{index}]"
        _require(isinstance(fixture, dict), f"{fixture_label} is not an object")
        _require(set(fixture) == FIXTURE_FIELDS, f"{fixture_label} field set changed")
        fixture_id = actual_ids[index]
        source = _parse_application(
            fixture.get("source_application"), f"{fixture_id}.source_application"
        )

        source_target_residual = _target_residual(source, f"{fixture_id}.source")
        source_impulse_residual = _impulse_residual(source, f"{fixture_id}.source")
        _require(
            source_target_residual <= tolerance
            and source_impulse_residual <= tolerance,
            f"{fixture_id} source application is internally inconsistent",
        )
        _require(
            _target_error(source, f"{fixture_id}.source") <= readback_tolerance
            and _impulse_error(source, f"{fixture_id}.source")
            <= readback_tolerance,
            f"{fixture_id} exceeds the inherited physical readback bound",
        )

        default = _decode_application(
            fixture.get("default_json"), f"{fixture_id}.default_json"
        )
        full = _decode_application(
            fixture.get("full_precision_json"), f"{fixture_id}.full_precision_json"
        )
        for field in NUMERIC_FIELDS:
            if not _same_binary64(
                source[field], full[field], f"{fixture_id}.full_precision.{field}"
            ):
                counts["full_binary64_mismatch"] += 1

        residuals = {
            "default_target": _target_residual(default, f"{fixture_id}.default"),
            "default_impulse": _impulse_residual(default, f"{fixture_id}.default"),
            "full_target": _target_residual(full, f"{fixture_id}.full"),
            "full_impulse": _impulse_residual(full, f"{fixture_id}.full"),
        }
        for key, residual in residuals.items():
            maxima[key] = max(maxima[key], residual)
            if residual > tolerance:
                counts[key] += 1
        if residuals["default_target"] > tolerance:
            default_target_failure_ids.append(fixture_id)

    canary = contract_values["canary"]
    expected_counts = {
        "default_target": canary[
            "default_serialization_expected_target_failure_count"
        ],
        "default_impulse": canary[
            "default_serialization_expected_impulse_failure_count"
        ],
        "full_target": canary[
            "full_precision_expected_target_failure_count"
        ],
        "full_impulse": canary[
            "full_precision_expected_impulse_failure_count"
        ],
        "full_binary64_mismatch": canary[
            "full_precision_binary64_operand_roundtrip_mismatch_count"
        ],
    }
    _require(counts == expected_counts, f"transport control counts changed: {counts}")
    return {
        "counts": counts,
        "maxima": maxima,
        "default_target_failure_ids": default_target_failure_ids,
        "godot_version": version,
        "fixture_count": len(fixtures),
    }


def _expect_mutation_rejected(
    name: str,
    receipt: Mapping[str, Any],
    contract_values: Mapping[str, Any],
) -> str:
    try:
        _validate_receipt(receipt, contract_values)
    except (R23D57TransportError, json.JSONDecodeError, KeyError, TypeError, ValueError):
        return name
    raise R23D57TransportError(f"mutation was accepted: {name}")


def _json_application(application: Mapping[str, Any]) -> str:
    return json.dumps(
        application,
        allow_nan=False,
        separators=(",", ":"),
        sort_keys=True,
    )


def _run_mutation_controls(
    receipt: Mapping[str, Any],
    contract_values: Mapping[str, Any],
    base_result: Mapping[str, Any],
) -> list[str]:
    rejected: list[str] = []

    mutation = copy.deepcopy(receipt)
    mutation["full_precision_argument_value"] = False
    rejected.append(
        _expect_mutation_rejected("full_precision_flag_false", mutation, contract_values)
    )

    mutation = copy.deepcopy(receipt)
    del mutation["fixtures"][-1]
    rejected.append(
        _expect_mutation_rejected("missing_fixture", mutation, contract_values)
    )

    mutation = copy.deepcopy(receipt)
    mutation["fixtures"][1]["fixture_id"] = mutation["fixtures"][0]["fixture_id"]
    rejected.append(
        _expect_mutation_rejected("duplicate_fixture_id", mutation, contract_values)
    )

    first_failure_id = base_result["default_target_failure_ids"][0]
    fixture_index = _expected_fixture_ids().index(first_failure_id)
    mutation = copy.deepcopy(receipt)
    mutation["fixtures"][fixture_index]["full_precision_json"] = mutation[
        "fixtures"
    ][fixture_index]["default_json"]
    rejected.append(
        _expect_mutation_rejected(
            "full_precision_replaced_by_default", mutation, contract_values
        )
    )

    mutation = copy.deepcopy(receipt)
    del mutation["fixtures"][0]["full_precision_json"]
    rejected.append(
        _expect_mutation_rejected("missing_full_precision_json", mutation, contract_values)
    )

    mutation = copy.deepcopy(receipt)
    application = json.loads(mutation["fixtures"][0]["full_precision_json"])
    application["motor_target_velocity_readback_error_rad_s"] += 2.0e-15
    mutation["fixtures"][0]["full_precision_json"] = _json_application(application)
    rejected.append(
        _expect_mutation_rejected("reported_target_error_perturbed", mutation, contract_values)
    )

    mutation = copy.deepcopy(receipt)
    application = json.loads(mutation["fixtures"][0]["full_precision_json"])
    application["motor_target_velocity_readback_rad_s"] += 1.0e-9
    mutation["fixtures"][0]["full_precision_json"] = _json_application(application)
    rejected.append(
        _expect_mutation_rejected("readback_operand_perturbed", mutation, contract_values)
    )

    mutation = copy.deepcopy(receipt)
    mutation["contract_id"] = "QSDK-R23D57-WRONG-CONTRACT"
    rejected.append(
        _expect_mutation_rejected("wrong_contract_id", mutation, contract_values)
    )

    mutation = copy.deepcopy(receipt)
    mutation["inherited_consistency_tolerance"] = 2.0e-15
    rejected.append(
        _expect_mutation_rejected("consistency_tolerance_changed", mutation, contract_values)
    )

    mutation = copy.deepcopy(receipt)
    mutation["world_attempt_count"] = 1
    rejected.append(
        _expect_mutation_rejected("world_attempt_opened", mutation, contract_values)
    )

    mutation = copy.deepcopy(receipt)
    source = mutation["fixtures"][0]["source_application"]
    source["motor_target_velocity_readback_rad_s"] = (
        source["host_applied_target_velocity_rad_s"] + 1.0e-6
    )
    source["motor_target_velocity_readback_error_rad_s"] = 1.0e-6
    rejected.append(
        _expect_mutation_rejected("physical_readback_bound_exceeded", mutation, contract_values)
    )

    mutation = copy.deepcopy(receipt)
    mutation["fixtures"][fixture_index]["default_json"] = mutation["fixtures"][
        fixture_index
    ]["full_precision_json"]
    rejected.append(
        _expect_mutation_rejected(
            "default_negative_control_replaced", mutation, contract_values
        )
    )

    _require(len(set(rejected)) == len(rejected), "mutation control identities repeated")
    return rejected


def _run_boundary_controls(consistency_tolerance: float) -> dict[str, Any]:
    applied = -1.04273172492923
    readback = -1.04273176193237
    recomputed = abs(readback - applied)
    below_reported = recomputed + 5.0e-16
    above_reported = recomputed + 2.0e-15
    below_residual = abs(below_reported - recomputed)
    above_residual = abs(above_reported - recomputed)
    _require(
        0.0 < below_residual <= consistency_tolerance,
        "below-boundary control was not accepted",
    )
    _require(
        above_residual > consistency_tolerance,
        "above-boundary control was not rejected",
    )
    return {
        "control_count": 2,
        "below_boundary_residual": below_residual,
        "below_boundary_accepted": True,
        "above_boundary_residual": above_residual,
        "above_boundary_rejected": True,
    }


def _run_godot(godot: Path, source_root: Path) -> dict[str, Any]:
    _require(godot.is_file(), f"Godot executable is missing: {godot}")
    completed = subprocess.run(
        (
            str(godot),
            "--headless",
            "--path",
            str(source_root),
            "--script",
            GODOT_SCRIPT,
        ),
        cwd=source_root,
        capture_output=True,
        check=False,
        encoding="utf-8",
        errors="replace",
        text=True,
        timeout=60,
    )
    combined = f"{completed.stdout}\n{completed.stderr}"
    markers = [
        line[len(RECEIPT_MARKER) :]
        for line in combined.splitlines()
        if line.startswith(RECEIPT_MARKER)
    ]
    _require(completed.returncode == 0, f"Godot exited {completed.returncode}")
    _require(len(markers) == 1, f"expected one Godot receipt, found {len(markers)}")
    try:
        receipt = json.loads(markers[0])
    except json.JSONDecodeError as error:
        raise R23D57TransportError("Godot receipt JSON is invalid") from error
    _require(isinstance(receipt, dict), "Godot receipt JSON is not an object")
    return receipt


def validate(*, godot: Path, source_root: Path) -> dict[str, Any]:
    resolved_root = source_root.resolve()
    _require(resolved_root == REPO_ROOT.resolve(), "source root is not canonical")
    _require(CONTRACT_PATH.is_file(), "R23D57 transport contract is missing")
    contract = _load_json(CONTRACT_PATH)
    _require(isinstance(contract, dict), "R23D57 transport contract is not an object")
    contract_values = _validate_contract(contract)
    receipt = _run_godot(godot.resolve(), resolved_root)
    base_result = _validate_receipt(receipt, contract_values)
    mutations = _run_mutation_controls(receipt, contract_values, base_result)
    boundaries = _run_boundary_controls(contract_values["consistency_tolerance"])
    canary = contract_values["canary"]
    _require(
        len(mutations) == canary["required_mutation_rejection_count"],
        "mutation rejection cardinality changed",
    )
    _require(
        boundaries["control_count"] == canary["required_boundary_control_count"],
        "boundary-control cardinality changed",
    )
    counts = base_result["counts"]
    return {
        "schema_version": (
            "sporespore_qsdk_r23d57_full_precision_trace_transport_result_v1"
        ),
        "contract_id": EXPECTED_CONTRACT_ID,
        "godot_version": base_result["godot_version"],
        "fixture_count": base_result["fixture_count"],
        "default_target_consistency_failure_count": counts["default_target"],
        "default_impulse_consistency_failure_count": counts["default_impulse"],
        "full_precision_target_consistency_failure_count": counts["full_target"],
        "full_precision_impulse_consistency_failure_count": counts["full_impulse"],
        "full_precision_binary64_roundtrip_mismatch_count": counts[
            "full_binary64_mismatch"
        ],
        "maximum_residuals": base_result["maxima"],
        "mutation_rejection_count": len(mutations),
        "mutation_rejections": mutations,
        "boundary_control_count": boundaries["control_count"],
        "boundary_controls": boundaries,
        "godot_process_launch_count": 1,
        "scene_tree_insertion_count": 0,
        "model_construction_count": 0,
        "controller_step_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_campaign_opened": False,
        "turning_claimed": False,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
    }


def _arguments(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--source-root", type=Path, default=REPO_ROOT)
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = _arguments(sys.argv[1:] if argv is None else argv)
    try:
        result = validate(godot=args.godot, source_root=args.source_root)
        print(
            PASS_MARKER
            + json.dumps(result, allow_nan=False, separators=(",", ":"), sort_keys=True)
        )
        return 0
    except (
        R23D57TransportError,
        OSError,
        UnicodeError,
        json.JSONDecodeError,
        subprocess.SubprocessError,
        KeyError,
        TypeError,
        ValueError,
    ) as error:
        print(
            "QSDK_R23D57_FULL_PRECISION_TRACE_TRANSPORT_FAILURE "
            f"{type(error).__name__}:{error}"
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
