"""R23D58 zero-world terminal/trace cap-identity validator.

This validator consumes the production-shaped JSON emitted by the Godot 4.7
runtime gate. It requires exact IEEE-754 binary64 identity between every cap
value projected into a terminal receipt and the corresponding first trace-row
application. It also mutation-tests the complete four-profile 2 x 2 cap-source
factorial surface. It constructs no physics model or world.
"""

from __future__ import annotations

import argparse
import copy
import json
import math
import struct
import sys
from pathlib import Path
from typing import Any, Callable


TRANSPORT_ID = "godot_4_7_sorted_full_precision_authoritative_json_v1"
TRANSPORT_SCHEMA = "sporespore_godot_authoritative_json_transport_receipt_v1"
TRANSPORT_INVOCATION = 'JSON.stringify(value, "", true, true)'
TERMINAL_SCHEMA = "sporespore_qsdk_r23d58_terminal_cap_identity_canary_v1"
TRACE_SCHEMA = "sporespore_qsdk_r23d58_trace_cap_identity_canary_v1"
TRACE_ROW_SCHEMA = "sporespore_qsdk_r23d58_trace_cap_identity_row_v1"
OBSERVATION_SCHEMA = "sporespore_godot_jolt_actuator_phase_observation_v1"
RECEIPT_SCHEMA = (
    "sporespore_godot_jolt_live_fixture_cap_source_factorial_binding_receipt_v1"
)
POLICY_ID = "sporespore_godot_jolt_live_fixture_cap_source_factorial_binding_v1"
READBACK_TOLERANCE_NMS = 2.5e-7

PORTABLE = "portable_compiled_morphology"
FIXTURE = "fixture_realized_prebinding"
PROFILE_DEFINITIONS = {
    "portable_hip__portable_knee": (PORTABLE, PORTABLE),
    "portable_hip__fixture_knee": (PORTABLE, FIXTURE),
    "fixture_hip__portable_knee": (FIXTURE, PORTABLE),
    "fixture_hip__fixture_knee": (FIXTURE, FIXTURE),
}
ORDERED_PROFILE_IDS = list(PROFILE_DEFINITIONS)
ORDERED_ACTUATOR_IDS = [
    "front_left_hip_motor",
    "front_left_knee_motor",
    "front_right_hip_motor",
    "front_right_knee_motor",
    "rear_left_hip_motor",
    "rear_left_knee_motor",
    "rear_right_hip_motor",
    "rear_right_knee_motor",
]


class ValidationError(ValueError):
    pass


def _reject_constant(value: str) -> None:
    raise ValidationError(f"non-finite JSON constant: {value}")


def _read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"), parse_constant=_reject_constant)


def _is_number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def _finite_float(value: Any) -> float | None:
    if not _is_number(value):
        return None
    converted = float(value)
    return converted if math.isfinite(converted) else None


def _bits(value: float) -> bytes:
    return struct.pack(">d", value)


def _same_binary64(left: Any, right: Any) -> bool:
    left_float = _finite_float(left)
    right_float = _finite_float(right)
    return (
        left_float is not None
        and right_float is not None
        and _bits(left_float) == _bits(right_float)
    )


def _dict(value: Any, path: str, issues: list[str]) -> dict[str, Any]:
    if not isinstance(value, dict):
        issues.append(f"{path}:dictionary_required")
        return {}
    return value


def _list(value: Any, path: str, issues: list[str]) -> list[Any]:
    if not isinstance(value, list):
        issues.append(f"{path}:array_required")
        return []
    return value


def _require_equal(actual: Any, expected: Any, path: str, issues: list[str]) -> None:
    if actual != expected or type(actual) is not type(expected):
        issues.append(f"{path}:identity_mismatch")


def _require_binary64(actual: Any, expected: Any, path: str, issues: list[str]) -> None:
    if not _same_binary64(actual, expected):
        issues.append(f"{path}:binary64_mismatch")


def _validate_transport(value: Any, path: str, issues: list[str]) -> None:
    transport = _dict(value, path, issues)
    _require_equal(transport.get("schema_version"), TRANSPORT_SCHEMA, f"{path}.schema", issues)
    _require_equal(transport.get("transport_id"), TRANSPORT_ID, f"{path}.id", issues)
    _require_equal(
        transport.get("selected_godot_invocation"),
        TRANSPORT_INVOCATION,
        f"{path}.invocation",
        issues,
    )
    _require_equal(transport.get("sorted_keys"), True, f"{path}.sorted_keys", issues)
    _require_equal(transport.get("full_precision"), True, f"{path}.full_precision", issues)
    _require_equal(
        transport.get("numeric_consumer"),
        "cpython_json_ieee754_binary64",
        f"{path}.numeric_consumer",
        issues,
    )


def evaluate(terminal: Any, trace: Any) -> dict[str, Any]:
    issues: list[str] = []
    terminal_doc = _dict(terminal, "terminal", issues)
    trace_doc = _dict(trace, "trace", issues)
    _require_equal(terminal_doc.get("schema_version"), TERMINAL_SCHEMA, "terminal.schema", issues)
    _require_equal(trace_doc.get("schema_version"), TRACE_SCHEMA, "trace.schema", issues)
    _validate_transport(terminal_doc.get("transport"), "terminal.transport", issues)
    _validate_transport(trace_doc.get("transport"), "trace.transport", issues)
    _require_equal(
        terminal_doc.get("ordered_profile_ids"),
        ORDERED_PROFILE_IDS,
        "terminal.ordered_profile_ids",
        issues,
    )
    _require_equal(
        trace_doc.get("ordered_profile_ids"),
        ORDERED_PROFILE_IDS,
        "trace.ordered_profile_ids",
        issues,
    )
    for document, path in ((terminal_doc, "terminal"), (trace_doc, "trace")):
        _require_equal(document.get("model_construction_count"), 0, f"{path}.models", issues)
        _require_equal(document.get("world_attempt_count"), 0, f"{path}.attempts", issues)
        _require_equal(document.get("world_build_count"), 0, f"{path}.worlds", issues)
        _require_equal(document.get("turning_claimed"), False, f"{path}.turning", issues)
        _require_equal(
            document.get("prone_to_standing_claimed"), False, f"{path}.prone", issues
        )
        _require_equal(
            document.get("physical_acceptance_authority"), False, f"{path}.physical", issues
        )

    cells = _list(terminal_doc.get("cells"), "terminal.cells", issues)
    rows = _list(trace_doc.get("rows"), "trace.rows", issues)
    if len(cells) != len(ORDERED_PROFILE_IDS):
        issues.append("terminal.cells:cardinality_mismatch")
    if len(rows) != len(ORDERED_PROFILE_IDS):
        issues.append("trace.rows:cardinality_mismatch")

    comparison_count = 0
    identity_comparison_count = 0
    for profile_index, profile_id in enumerate(ORDERED_PROFILE_IDS):
        if profile_index >= len(cells) or profile_index >= len(rows):
            continue
        cell_path = f"terminal.cells[{profile_index}]"
        row_path = f"trace.rows[{profile_index}]"
        cell = _dict(cells[profile_index], cell_path, issues)
        row = _dict(rows[profile_index], row_path, issues)
        expected_cell_id = f"zero_world__{profile_id}"
        _require_equal(cell.get("cell_id"), expected_cell_id, f"{cell_path}.cell_id", issues)
        _require_equal(row.get("cell_id"), expected_cell_id, f"{row_path}.cell_id", issues)
        _require_equal(cell.get("profile_id"), profile_id, f"{cell_path}.profile_id", issues)
        _require_equal(row.get("profile_id"), profile_id, f"{row_path}.profile_id", issues)
        _require_equal(row.get("schema_version"), TRACE_ROW_SCHEMA, f"{row_path}.schema", issues)
        _require_equal(row.get("semantic_step"), 0, f"{row_path}.semantic_step", issues)

        summary = _dict(cell.get("sdk_authority_summary"), f"{cell_path}.summary", issues)
        receipt = _dict(
            summary.get("r23d58_live_fixture_cap_source_factorial_binding_receipt"),
            f"{cell_path}.receipt",
            issues,
        )
        _require_equal(receipt.get("schema_version"), RECEIPT_SCHEMA, f"{cell_path}.receipt.schema", issues)
        _require_equal(receipt.get("policy_id"), POLICY_ID, f"{cell_path}.receipt.policy", issues)
        _require_equal(receipt.get("profile_id"), profile_id, f"{cell_path}.receipt.profile", issues)
        expected_hip_source, expected_knee_source = PROFILE_DEFINITIONS[profile_id]
        _require_equal(
            receipt.get("hip_cap_source"), expected_hip_source, f"{cell_path}.receipt.hip_source", issues
        )
        _require_equal(
            receipt.get("knee_cap_source"),
            expected_knee_source,
            f"{cell_path}.receipt.knee_source",
            issues,
        )
        _require_equal(
            receipt.get("ordered_actuator_ids"),
            ORDERED_ACTUATOR_IDS,
            f"{cell_path}.receipt.actuator_order",
            issues,
        )
        _require_equal(receipt.get("write_count"), 8, f"{cell_path}.receipt.writes", issues)
        _require_equal(receipt.get("readback_count"), 8, f"{cell_path}.receipt.readbacks", issues)
        _require_binary64(
            receipt.get("readback_tolerance_nms"),
            READBACK_TOLERANCE_NMS,
            f"{cell_path}.receipt.tolerance",
            issues,
        )
        _require_equal(receipt.get("model_construction_count"), 0, f"{cell_path}.receipt.models", issues)
        _require_equal(receipt.get("world_attempt_count"), 0, f"{cell_path}.receipt.attempts", issues)
        _require_equal(receipt.get("world_build_count"), 0, f"{cell_path}.receipt.worlds", issues)

        observation = _dict(row.get("actuator_phase_observation"), f"{row_path}.observation", issues)
        _require_equal(
            observation.get("schema_version"),
            OBSERVATION_SCHEMA,
            f"{row_path}.observation.schema",
            issues,
        )
        bindings = _list(receipt.get("ordered_bindings"), f"{cell_path}.receipt.bindings", issues)
        applications = _list(
            observation.get("ordered_applications"), f"{row_path}.observation.applications", issues
        )
        if len(bindings) != 8:
            issues.append(f"{cell_path}.receipt.bindings:cardinality_mismatch")
        if len(applications) != 8:
            issues.append(f"{row_path}.observation.applications:cardinality_mismatch")
        for actuator_index, actuator_id in enumerate(ORDERED_ACTUATOR_IDS):
            if actuator_index >= len(bindings) or actuator_index >= len(applications):
                continue
            binding_path = f"{cell_path}.receipt.bindings[{actuator_index}]"
            application_path = f"{row_path}.observation.applications[{actuator_index}]"
            binding = _dict(bindings[actuator_index], binding_path, issues)
            application = _dict(applications[actuator_index], application_path, issues)
            expected_source = (
                expected_hip_source if binding.get("joint_role") == "hip_pitch" else expected_knee_source
            )
            for key in (
                "actuator_id",
                "joint_id",
                "host_joint_id",
                "limb_id",
                "joint_role",
                "selected_cap_source",
            ):
                expected_value = actuator_id if key == "actuator_id" else binding.get(key)
                if key == "selected_cap_source":
                    expected_value = expected_source
                _require_equal(binding.get(key), expected_value, f"{binding_path}.{key}", issues)
                _require_equal(
                    application.get(key), binding.get(key), f"{application_path}.{key}", issues
                )
                identity_comparison_count += 1
            for binding_key, application_key in (
                ("selected_maximum_impulse_nms", "declared_maximum_impulse_nms"),
                ("motor_maximum_impulse_readback_nms", "motor_maximum_impulse_readback_nms"),
                ("readback_error_nms", "readback_error_nms"),
            ):
                _require_binary64(
                    binding.get(binding_key),
                    application.get(application_key),
                    f"{application_path}.{application_key}",
                    issues,
                )
                comparison_count += 1

    return {
        "ok": not issues,
        "failure_codes": issues,
        "binary64_comparison_count": comparison_count,
        "identity_comparison_count": identity_comparison_count,
        "binary64_mismatch_count": sum("binary64_mismatch" in issue for issue in issues),
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def _mutation_controls(
    terminal: dict[str, Any],
    trace: dict[str, Any],
    default_terminal: dict[str, Any],
) -> dict[str, bool]:
    controls: dict[str, bool] = {}

    def rejected(name: str, mutate: Callable[[dict[str, Any], dict[str, Any]], None]) -> None:
        terminal_mutation = copy.deepcopy(terminal)
        trace_mutation = copy.deepcopy(trace)
        mutate(terminal_mutation, trace_mutation)
        controls[name] = not bool(evaluate(terminal_mutation, trace_mutation)["ok"])

    controls["default_terminal_precision_rejected"] = not bool(
        evaluate(default_terminal, trace)["ok"]
    )
    rejected(
        "terminal_full_precision_false_rejected",
        lambda t, _: t["transport"].__setitem__("full_precision", False),
    )
    rejected(
        "trace_full_precision_false_rejected",
        lambda _, r: r["transport"].__setitem__("full_precision", False),
    )
    rejected(
        "terminal_transport_id_rejected",
        lambda t, _: t["transport"].__setitem__("transport_id", "mutated"),
    )
    rejected(
        "trace_transport_id_rejected",
        lambda _, r: r["transport"].__setitem__("transport_id", "mutated"),
    )
    rejected("missing_terminal_cell_rejected", lambda t, _: t["cells"].pop())
    rejected("duplicate_terminal_cell_rejected", lambda t, _: t["cells"].append(t["cells"][0]))
    rejected("reordered_terminal_cells_rejected", lambda t, _: t["cells"].reverse())
    rejected(
        "terminal_profile_id_rejected",
        lambda t, _: t["cells"][0].__setitem__("profile_id", "mutated"),
    )
    rejected(
        "missing_terminal_binding_rejected",
        lambda t, _: t["cells"][0]["sdk_authority_summary"][
            "r23d58_live_fixture_cap_source_factorial_binding_receipt"
        ]["ordered_bindings"].pop(),
    )
    rejected(
        "duplicate_terminal_binding_rejected",
        lambda t, _: t["cells"][0]["sdk_authority_summary"][
            "r23d58_live_fixture_cap_source_factorial_binding_receipt"
        ]["ordered_bindings"].append(
            t["cells"][0]["sdk_authority_summary"][
                "r23d58_live_fixture_cap_source_factorial_binding_receipt"
            ]["ordered_bindings"][0]
        ),
    )
    rejected(
        "swapped_terminal_bindings_rejected",
        lambda t, _: t["cells"][0]["sdk_authority_summary"][
            "r23d58_live_fixture_cap_source_factorial_binding_receipt"
        ]["ordered_bindings"].reverse(),
    )
    rejected(
        "terminal_actuator_id_rejected",
        lambda t, _: t["cells"][0]["sdk_authority_summary"][
            "r23d58_live_fixture_cap_source_factorial_binding_receipt"
        ]["ordered_bindings"][0].__setitem__("actuator_id", "mutated"),
    )
    rejected(
        "terminal_host_joint_id_rejected",
        lambda t, _: t["cells"][0]["sdk_authority_summary"][
            "r23d58_live_fixture_cap_source_factorial_binding_receipt"
        ]["ordered_bindings"][0].__setitem__("host_joint_id", "mutated"),
    )
    rejected(
        "terminal_selected_source_rejected",
        lambda t, _: t["cells"][0]["sdk_authority_summary"][
            "r23d58_live_fixture_cap_source_factorial_binding_receipt"
        ]["ordered_bindings"][0].__setitem__("selected_cap_source", FIXTURE),
    )

    def mutate_terminal_cap(t: dict[str, Any], _: dict[str, Any], direction: float) -> None:
        binding = t["cells"][0]["sdk_authority_summary"][
            "r23d58_live_fixture_cap_source_factorial_binding_receipt"
        ]["ordered_bindings"][0]
        binding["selected_maximum_impulse_nms"] = math.nextafter(
            float(binding["selected_maximum_impulse_nms"]), direction
        )

    rejected(
        "terminal_cap_nextafter_up_rejected",
        lambda t, r: mutate_terminal_cap(t, r, math.inf),
    )
    rejected(
        "terminal_cap_nextafter_down_rejected",
        lambda t, r: mutate_terminal_cap(t, r, -math.inf),
    )
    rejected("missing_trace_row_rejected", lambda _, r: r["rows"].pop())
    rejected("duplicate_trace_row_rejected", lambda _, r: r["rows"].append(r["rows"][0]))
    rejected(
        "trace_profile_id_rejected",
        lambda _, r: r["rows"][0].__setitem__("profile_id", "mutated"),
    )
    rejected(
        "missing_trace_application_rejected",
        lambda _, r: r["rows"][0]["actuator_phase_observation"][
            "ordered_applications"
        ].pop(),
    )
    rejected(
        "duplicate_trace_application_rejected",
        lambda _, r: r["rows"][0]["actuator_phase_observation"][
            "ordered_applications"
        ].append(r["rows"][0]["actuator_phase_observation"]["ordered_applications"][0]),
    )
    rejected(
        "swapped_trace_applications_rejected",
        lambda _, r: r["rows"][0]["actuator_phase_observation"][
            "ordered_applications"
        ].reverse(),
    )
    rejected(
        "trace_actuator_id_rejected",
        lambda _, r: r["rows"][0]["actuator_phase_observation"][
            "ordered_applications"
        ][0].__setitem__("actuator_id", "mutated"),
    )

    def mutate_trace_numeric(r: dict[str, Any], key: str) -> None:
        application = r["rows"][0]["actuator_phase_observation"]["ordered_applications"][0]
        application[key] = math.nextafter(float(application[key]), math.inf)

    rejected(
        "trace_cap_nextafter_up_rejected",
        lambda _, r: mutate_trace_numeric(r, "declared_maximum_impulse_nms"),
    )
    rejected(
        "trace_readback_nextafter_up_rejected",
        lambda _, r: mutate_trace_numeric(r, "motor_maximum_impulse_readback_nms"),
    )
    rejected(
        "terminal_tolerance_rejected",
        lambda t, _: t["cells"][0]["sdk_authority_summary"][
            "r23d58_live_fixture_cap_source_factorial_binding_receipt"
        ].__setitem__("readback_tolerance_nms", READBACK_TOLERANCE_NMS * 2.0),
    )
    rejected(
        "physical_world_count_rejected",
        lambda t, _: t.__setitem__("world_build_count", 1),
    )
    rejected("turning_claim_rejected", lambda t, _: t.__setitem__("turning_claimed", True))
    rejected("terminal_schema_rejected", lambda t, _: t.__setitem__("schema_version", "mutated"))
    rejected("trace_schema_rejected", lambda _, r: r.__setitem__("schema_version", "mutated"))
    rejected(
        "trace_semantic_step_rejected",
        lambda _, r: r["rows"][0].__setitem__("semantic_step", 1),
    )
    return controls


def validate_canary(terminal_path: Path, trace_path: Path, default_terminal_path: Path) -> dict[str, Any]:
    terminal = _read_json(terminal_path)
    trace = _read_json(trace_path)
    default_terminal = _read_json(default_terminal_path)
    baseline = evaluate(terminal, trace)
    if not baseline["ok"]:
        raise ValidationError("baseline invalid: " + ";".join(baseline["failure_codes"]))
    default_result = evaluate(default_terminal, trace)
    if default_result["ok"] or int(default_result["binary64_mismatch_count"]) <= 0:
        raise ValidationError("default-precision terminal did not produce a numeric identity negative")
    controls = _mutation_controls(terminal, trace, default_terminal)
    failed_controls = [name for name, passed in controls.items() if not passed]
    if failed_controls:
        raise ValidationError("mutation controls accepted: " + ",".join(failed_controls))
    return {
        "schema_version": "sporespore_qsdk_r23d58_terminal_trace_cap_identity_validator_receipt_v1",
        "ok": True,
        "failure_code": "",
        "profile_count": len(ORDERED_PROFILE_IDS),
        "actuator_count_per_profile": len(ORDERED_ACTUATOR_IDS),
        "binary64_comparison_count": baseline["binary64_comparison_count"],
        "identity_comparison_count": baseline["identity_comparison_count"],
        "binary64_mismatch_count": baseline["binary64_mismatch_count"],
        "default_precision_binary64_mismatch_count": default_result[
            "binary64_mismatch_count"
        ],
        "mutation_rejection_count": len(controls),
        "mutation_results": controls,
        "nextafter_up_rejected": controls["terminal_cap_nextafter_up_rejected"],
        "nextafter_down_rejected": controls["terminal_cap_nextafter_down_rejected"],
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "turning_claimed": False,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def _main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--terminal-json", type=Path, required=True)
    parser.add_argument("--trace-json", type=Path, required=True)
    parser.add_argument("--default-terminal-json", type=Path, required=True)
    arguments = parser.parse_args(argv)
    try:
        receipt = validate_canary(
            arguments.terminal_json,
            arguments.trace_json,
            arguments.default_terminal_json,
        )
    except Exception as exc:  # fail-closed CLI boundary
        print(f"QSDK_R23D58_TERMINAL_TRACE_CANARY_FAILED {type(exc).__name__}: {exc}")
        return 1
    print(
        "QSDK_R23D58_TERMINAL_TRACE_CANARY "
        + json.dumps(receipt, sort_keys=True, separators=(",", ":"), allow_nan=False)
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(_main(sys.argv[1:]))
