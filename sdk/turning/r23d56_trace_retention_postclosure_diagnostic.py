"""Read-only post-closure diagnosis for the consumed QSDK-R23D56 attempt.

This tool does not retain, repair, or re-evaluate R23D56 as a scientific
result.  It independently inspects the already-retained raw rows and the
frozen evaluator to identify which primitive actuator/phase link predicate
caused trace retention to refuse the otherwise complete row sets.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib
import json
import math
from pathlib import Path
import sys
from typing import Any, Mapping, Sequence


CAMPAIGN_ID = (
    "QSDK-R23D56-GODOT-VALID-ROUTE-ACTUATOR-PHASE-"
    "CHARACTERIZATION-DEVELOPMENT"
)
ROOT_FAILURE = "QSDK_R23D56_GJT_TRACE_RETENTION_FAILED:1"
WORKER_FAILURE_SCHEMA = "sporespore_qsdk_r23d56_worker_failure_v1"
TRACE_DIAGNOSTIC_SCHEMA = "sporespore_qsdk_r23d56_trace_diagnostic_v1"
FROZEN_REPORT_CONSISTENCY_TOLERANCE = 1.0e-15
REFERENCE_ONLY_ROUNDTRIP_TOLERANCE = 1.0e-12
EXPECTED_ARM_ORDER = ("reference_zero", "positive_heading", "negative_heading")
EXPECTED_ROW_COUNT = 2992
EXPECTED_APPLICATIONS_PER_ROW = 8


class R23D56PostclosureDiagnosticError(RuntimeError):
    """The retained attempt no longer supports the bounded diagnosis."""


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise R23D56PostclosureDiagnosticError(message)


def _load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return f"sha256:{digest.hexdigest()}"


def _finite_float(value: Any, label: str) -> float:
    try:
        result = float(value)
    except (TypeError, ValueError) as error:
        raise R23D56PostclosureDiagnosticError(
            f"{label} is not numeric"
        ) from error
    _require(math.isfinite(result), f"{label} is not finite")
    return result


def _load_frozen_evaluator(source_root: Path) -> Any:
    turning_root = source_root / "sdk" / "turning"
    evaluator_path = (
        turning_root
        / "r23d56_godot_valid_route_actuator_phase_characterization_evaluator.py"
    )
    _require(evaluator_path.is_file(), "frozen R23D56 evaluator is missing")
    sys.path.insert(0, str(turning_root))
    try:
        for module_name in (
            "r23d56_godot_valid_route_actuator_phase_characterization_evaluator",
            "r23d56_godot_valid_route_actuator_phase_characterization",
            "r23d34_native_r23d29_transfer_evaluator",
        ):
            sys.modules.pop(module_name, None)
        return importlib.import_module(
            "r23d56_godot_valid_route_actuator_phase_characterization_evaluator"
        )
    finally:
        del sys.path[0]


def _cell_paths(attempt_root: Path, cell_id: str) -> dict[str, Path]:
    return {
        "terminal": attempt_root / "cells" / cell_id / "terminal.json",
        "rows": attempt_root / "pending-traces" / f"{cell_id}.rows.json",
        "diagnostic": (
            attempt_root
            / "pending-traces"
            / f"{cell_id}.trace-diagnostic.json"
        ),
    }


def _diagnose_cell(
    *,
    evaluator: Any,
    attempt_root: Path,
    reported_cell: Mapping[str, Any],
    expected_source_commit: str,
) -> dict[str, Any]:
    cell_id = str(reported_cell.get("cell_id", ""))
    arm_id = str(reported_cell.get("arm_id", ""))
    paths = _cell_paths(attempt_root, cell_id)
    for label, path in paths.items():
        _require(path.is_file(), f"{arm_id} {label} file is missing")

    terminal = _load_json(paths["terminal"])
    rows = _load_json(paths["rows"])
    diagnostic = _load_json(paths["diagnostic"])
    _require(isinstance(rows, list), f"{arm_id} raw rows are not a list")
    _require(
        terminal.get("schema_version") == WORKER_FAILURE_SCHEMA
        and terminal.get("campaign_id") == CAMPAIGN_ID
        and terminal.get("source_commit") == expected_source_commit
        and terminal.get("cell_id") == cell_id
        and terminal.get("arm_id") == arm_id
        and terminal.get("failure_code") == ROOT_FAILURE
        and terminal.get("trace_artifact") is None
        and terminal.get("world_attempt_count") == 1
        and terminal.get("world_build_count") == 1,
        f"{arm_id} terminal identity or retained failure changed",
    )
    _require(
        diagnostic.get("schema_version") == TRACE_DIAGNOSTIC_SCHEMA
        and diagnostic.get("campaign_id") == CAMPAIGN_ID
        and diagnostic.get("cell_id") == cell_id
        and diagnostic.get("arm_id") == arm_id
        and diagnostic.get("complete") is True
        and diagnostic.get("failure_codes") == []
        and diagnostic.get("declared_row_count") == EXPECTED_ROW_COUNT
        and diagnostic.get("actual_row_count") == EXPECTED_ROW_COUNT
        and diagnostic.get("reported_row_count") == EXPECTED_ROW_COUNT
        and diagnostic.get("contiguous_row_count") == EXPECTED_ROW_COUNT
        and diagnostic.get("first_missing_semantic_step") == EXPECTED_ROW_COUNT
        and diagnostic.get("rows") == rows,
        f"{arm_id} complete diagnostic or raw-row mirror changed",
    )
    _require(len(rows) == EXPECTED_ROW_COUNT, f"{arm_id} row count changed")

    counters = {
        "target_report_consistency_over_frozen_tolerance_count": 0,
        "target_report_consistency_over_reference_1e_12_count": 0,
        "impulse_report_consistency_over_frozen_tolerance_count": 0,
        "target_readback_tolerance_violation_count": 0,
        "impulse_readback_tolerance_violation_count": 0,
        "controller_speed_bound_violation_count": 0,
        "host_application_delta_tolerance_violation_count": 0,
        "host_target_readback_delta_tolerance_violation_count": 0,
        "host_additional_clamp_observed_count": 0,
        "target_readback_match_flag_failure_count": 0,
        "impulse_readback_match_flag_failure_count": 0,
        "phase_link_mismatch_count": 0,
        "contact_link_mismatch_count": 0,
    }
    maxima = {
        "target_report_recomputation_residual_rad_s": 0.0,
        "impulse_report_recomputation_residual_nms": 0.0,
        "target_velocity_readback_error_rad_s": 0.0,
        "impulse_readback_error_nms": 0.0,
        "host_application_delta_rad_s": 0.0,
    }
    affected_rows: set[int] = set()
    first_target_consistency_failure: dict[str, Any] | None = None
    application_count = 0
    expected_actuator_ids: tuple[str, ...] | None = None
    expected_limb_ids: tuple[str, ...] | None = None

    for expected_step, row in enumerate(rows):
        _require(
            isinstance(row, dict)
            and row.get("semantic_step") == expected_step
            and row.get("cell_id") == cell_id,
            f"{arm_id} row identity changed at {expected_step}",
        )
        observation = row.get("actuator_phase_observation")
        _require(
            isinstance(observation, dict)
            and observation.get("semantic_step") == expected_step,
            f"{arm_id} observation identity changed at {expected_step}",
        )
        applications = observation.get("ordered_applications")
        actuator_ids = observation.get("ordered_actuator_ids")
        limb_ids = observation.get("ordered_limb_ids")
        phases_value = row.get("ordered_limb_phase_before")
        before = row.get("ordered_foot_contacts_before")
        after = row.get("ordered_foot_contacts_after")
        _require(
            isinstance(applications, list)
            and len(applications) == EXPECTED_APPLICATIONS_PER_ROW
            and isinstance(actuator_ids, list)
            and len(actuator_ids) == EXPECTED_APPLICATIONS_PER_ROW
            and isinstance(limb_ids, list)
            and len(limb_ids) == 4
            and isinstance(phases_value, list)
            and len(phases_value) == 4
            and isinstance(before, dict)
            and isinstance(after, dict),
            f"{arm_id} observation shape changed at {expected_step}",
        )
        actuator_identity = tuple(str(value) for value in actuator_ids)
        limb_identity = tuple(str(value) for value in limb_ids)
        if expected_actuator_ids is None:
            expected_actuator_ids = actuator_identity
            expected_limb_ids = limb_identity
        _require(
            actuator_identity == expected_actuator_ids
            and limb_identity == expected_limb_ids,
            f"{arm_id} declared observation identity drifted at {expected_step}",
        )
        phases = {str(value.get("limb_id", "")): value for value in phases_value}
        tolerance = _finite_float(
            observation.get("readback_tolerance"),
            f"{arm_id} readback tolerance at {expected_step}",
        )
        _require(
            tolerance == 2.5e-7,
            f"{arm_id} frozen configured-readback tolerance changed",
        )

        for application_index, application in enumerate(applications):
            _require(
                isinstance(application, dict)
                and application.get("actuator_id") == actuator_ids[application_index],
                f"{arm_id} application identity changed at "
                f"{expected_step}:{application_index}",
            )
            application_count += 1
            limb_id = str(application.get("limb_id", ""))
            _require(
                limb_id in phases and limb_id in before and limb_id in after,
                f"{arm_id} limb link missing at {expected_step}:{application_index}",
            )
            phase = phases[limb_id]
            controller = _finite_float(
                application.get("controller_target_velocity_rad_s"), "controller"
            )
            maximum_speed = _finite_float(
                application.get("maximum_target_speed_rad_s"), "maximum speed"
            )
            applied = _finite_float(
                application.get("host_applied_target_velocity_rad_s"), "applied"
            )
            target_readback = _finite_float(
                application.get("motor_target_velocity_readback_rad_s"),
                "target readback",
            )
            target_error = _finite_float(
                application.get("motor_target_velocity_readback_error_rad_s"),
                "target error",
            )
            declared_impulse = _finite_float(
                application.get("declared_maximum_impulse_nms"), "declared impulse"
            )
            impulse_readback = _finite_float(
                application.get("motor_maximum_impulse_readback_nms"),
                "impulse readback",
            )
            impulse_error = _finite_float(
                application.get("motor_maximum_impulse_readback_error_nms"),
                "impulse error",
            )
            target_report_residual = abs(
                target_error - abs(target_readback - applied)
            )
            impulse_report_residual = abs(
                impulse_error - abs(impulse_readback - declared_impulse)
            )
            application_delta = abs(applied - controller)
            target_readback_delta = abs(target_readback - applied)
            maxima["target_report_recomputation_residual_rad_s"] = max(
                maxima["target_report_recomputation_residual_rad_s"],
                target_report_residual,
            )
            maxima["impulse_report_recomputation_residual_nms"] = max(
                maxima["impulse_report_recomputation_residual_nms"],
                impulse_report_residual,
            )
            maxima["target_velocity_readback_error_rad_s"] = max(
                maxima["target_velocity_readback_error_rad_s"], target_error
            )
            maxima["impulse_readback_error_nms"] = max(
                maxima["impulse_readback_error_nms"], impulse_error
            )
            maxima["host_application_delta_rad_s"] = max(
                maxima["host_application_delta_rad_s"], application_delta
            )

            if target_report_residual > FROZEN_REPORT_CONSISTENCY_TOLERANCE:
                counters[
                    "target_report_consistency_over_frozen_tolerance_count"
                ] += 1
                affected_rows.add(expected_step)
                if first_target_consistency_failure is None:
                    first_target_consistency_failure = {
                        "semantic_step": expected_step,
                        "application_index": application_index,
                        "actuator_id": application["actuator_id"],
                        "residual_rad_s": target_report_residual,
                    }
            counters[
                "target_report_consistency_over_reference_1e_12_count"
            ] += int(target_report_residual > REFERENCE_ONLY_ROUNDTRIP_TOLERANCE)
            counters[
                "impulse_report_consistency_over_frozen_tolerance_count"
            ] += int(
                impulse_report_residual > FROZEN_REPORT_CONSISTENCY_TOLERANCE
            )
            counters["target_readback_tolerance_violation_count"] += int(
                target_error > tolerance
            )
            counters["impulse_readback_tolerance_violation_count"] += int(
                impulse_error > tolerance
            )
            counters["controller_speed_bound_violation_count"] += int(
                abs(controller) > maximum_speed + tolerance
            )
            counters["host_application_delta_tolerance_violation_count"] += int(
                application_delta > tolerance
            )
            counters[
                "host_target_readback_delta_tolerance_violation_count"
            ] += int(target_readback_delta > tolerance)
            counters["host_additional_clamp_observed_count"] += int(
                application.get("host_additional_clamp_applied") is not False
            )
            counters["target_readback_match_flag_failure_count"] += int(
                application.get("target_velocity_readback_matches") is not True
            )
            counters["impulse_readback_match_flag_failure_count"] += int(
                application.get("maximum_impulse_readback_matches") is not True
            )
            counters["phase_link_mismatch_count"] += int(
                application.get("local_phase_step_before")
                != phase.get("local_phase_step")
                or application.get("gait_step_before") != phase.get("gait_step")
                or application.get("release_hold_step_count_before")
                != phase.get("release_hold_step_count")
            )
            counters["contact_link_mismatch_count"] += int(
                application.get("foot_contact_before") is not before[limb_id]
                or application.get("foot_contact_after") is not after[limb_id]
            )

    _require(
        application_count == EXPECTED_ROW_COUNT * EXPECTED_APPLICATIONS_PER_ROW,
        f"{arm_id} application count changed",
    )
    frozen_summary = evaluator.validate_trace(cell_id, rows)
    frozen_failures = list(frozen_summary.get("failure_codes", []))
    _require(
        frozen_summary.get("ok") is False
        and frozen_failures
        and frozen_failures[0]
        == "R23D56_OBSERVATION_APPLICATION_LINK:1:100"
        and "R23D56_OBSERVATION_LIMB_JOINT_CARDINALITY:100"
        in frozen_failures
        and "R23D56_OBSERVATION_IDENTITY_DRIFT:100" in frozen_failures,
        f"{arm_id} frozen evaluator failure projection changed",
    )
    non_report_failures = {
        key: value
        for key, value in counters.items()
        if key
        not in {
            "target_report_consistency_over_frozen_tolerance_count",
            "target_report_consistency_over_reference_1e_12_count",
        }
        and value != 0
    }
    _require(
        counters["target_report_consistency_over_frozen_tolerance_count"] > 0
        and counters[
            "target_report_consistency_over_reference_1e_12_count"
        ]
        == 0
        and not non_report_failures,
        f"{arm_id} has an additional primitive actuator-link failure",
    )

    authority = terminal.get("raw_sdk_authority_summary")
    _require(isinstance(authority, dict), f"{arm_id} SDK authority summary missing")
    cap = authority.get("r23d56_live_fixture_actuator_cap_binding_receipt")
    _require(
        authority.get("ok") is True
        and authority.get("failure_code") == ""
        and authority.get(
            "r23d56_live_fixture_actuator_cap_binding_integrity_passed"
        )
        is True
        and isinstance(cap, dict)
        and cap.get("ok") is True
        and cap.get("write_count") == 8
        and cap.get("readback_count") == 8
        and cap.get("validated_actuator_count") == 8
        and cap.get("unique_host_joint_object_count") == 8
        and cap.get("prebinding_mismatch_count") == 8
        and cap.get("all_postbinding_readbacks_match") is True
        and cap.get("configured_parameter_readback_only") is True
        and cap.get("measured_motor_torque_available") is False
        and cap.get("measured_motor_impulse_available") is False
        and _finite_float(cap.get("maximum_postbinding_readback_error_nms"), "cap")
        <= _finite_float(cap.get("readback_tolerance_nms"), "cap tolerance")
        == 2.5e-7,
        f"{arm_id} live cap-binding receipt changed",
    )

    return {
        "arm_id": arm_id,
        "cell_id": cell_id,
        "terminal_raw_sha256": _sha256(paths["terminal"]),
        "raw_rows_raw_sha256": _sha256(paths["rows"]),
        "diagnostic_raw_sha256": _sha256(paths["diagnostic"]),
        "raw_rows_equal_diagnostic_rows": True,
        "row_count": len(rows),
        "application_count": application_count,
        "target_report_consistency_affected_row_count": len(affected_rows),
        "first_target_report_consistency_failure": first_target_consistency_failure,
        "primitive_predicate_counts": counters,
        "maximums": maxima,
        "frozen_evaluator_ok": False,
        "frozen_evaluator_first_failure_codes": frozen_failures,
        "downstream_cardinality_and_identity_failures_are_link_omission_projections": True,
        "raw_sdk_authority_summary_ok": True,
        "cap_binding_write_count": int(cap["write_count"]),
        "cap_binding_readback_count": int(cap["readback_count"]),
        "cap_binding_maximum_postbinding_readback_error_nms": float(
            cap["maximum_postbinding_readback_error_nms"]
        ),
    }


def diagnose(
    *, source_root: Path, attempt_root: Path, expected_source_commit: str
) -> dict[str, Any]:
    source_root = source_root.resolve()
    attempt_root = attempt_root.resolve()
    _require(source_root.is_dir(), "source root is missing")
    _require(attempt_root.is_dir(), "attempt root is missing")
    report_path = attempt_root / "report.json"
    _require(report_path.is_file(), "R23D56 report is missing")
    report = _load_json(report_path)
    _require(
        report.get("campaign_id") == CAMPAIGN_ID
        and report.get("source", {}).get("commit") == expected_source_commit
        and report.get("all_three_cells_executed_or_retained_as_failures") is True
        and report.get("world_build_count_exact") is True
        and report.get("world_build_count_lower_bound") == 3
        and report.get("world_build_count_upper_bound") == 3,
        "R23D56 report identity or finite matrix changed",
    )
    reported_cells = report.get("ordered_cells")
    _require(
        isinstance(reported_cells, list)
        and tuple(cell.get("arm_id") for cell in reported_cells)
        == EXPECTED_ARM_ORDER,
        "R23D56 ordered cell matrix changed",
    )
    evaluator = _load_frozen_evaluator(source_root)
    cells = [
        _diagnose_cell(
            evaluator=evaluator,
            attempt_root=attempt_root,
            reported_cell=cell,
            expected_source_commit=expected_source_commit,
        )
        for cell in reported_cells
    ]
    return {
        "schema_version": "sporespore_qsdk_r23d56_trace_retention_postclosure_diagnostic_v1",
        "diagnosis_class": "read_only_exact_retained_rows_against_frozen_evaluator",
        "campaign_id": CAMPAIGN_ID,
        "source_commit": expected_source_commit,
        "attempt_root": attempt_root.as_posix(),
        "frozen_report_consistency_tolerance": (
            FROZEN_REPORT_CONSISTENCY_TOLERANCE
        ),
        "reference_only_1e_12_tolerance_is_successor_authority": False,
        "cell_count": len(cells),
        "row_count": sum(cell["row_count"] for cell in cells),
        "application_count": sum(cell["application_count"] for cell in cells),
        "target_report_consistency_over_frozen_tolerance_count": sum(
            cell["primitive_predicate_counts"][
                "target_report_consistency_over_frozen_tolerance_count"
            ]
            for cell in cells
        ),
        "target_report_consistency_affected_row_count": sum(
            cell["target_report_consistency_affected_row_count"] for cell in cells
        ),
        "all_other_primitive_actuator_link_failure_counts_zero": True,
        "live_fixture_actuator_cap_route_observed_conformant": True,
        "configured_readback_is_measured_torque_or_impulse": False,
        "r23d56_result_reinterpreted": False,
        "r23d56_remains_invalid_complete": True,
        "turning_result": False,
        "physical_acceptance_authority": False,
        "cells": cells,
    }


def _arguments(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument("--attempt-root", type=Path, required=True)
    parser.add_argument("--expected-source-commit", required=True)
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = _arguments(sys.argv[1:] if argv is None else argv)
    try:
        value = diagnose(
            source_root=args.source_root,
            attempt_root=args.attempt_root,
            expected_source_commit=args.expected_source_commit,
        )
        print(
            "QSDK_R23D56_POSTCLOSURE_DIAGNOSTIC "
            + json.dumps(value, allow_nan=False, separators=(",", ":"), sort_keys=True)
        )
        return 0
    except (
        R23D56PostclosureDiagnosticError,
        OSError,
        UnicodeError,
        json.JSONDecodeError,
        ImportError,
        AttributeError,
        TypeError,
        ValueError,
    ) as error:
        print(
            "QSDK_R23D56_POSTCLOSURE_DIAGNOSTIC_FAILURE "
            f"{type(error).__name__}:{error}"
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
