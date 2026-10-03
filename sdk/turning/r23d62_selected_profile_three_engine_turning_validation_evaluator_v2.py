#!/usr/bin/env python3
"""Corrected retained-evidence evaluator implementation for QSDK-R23D62.

The first zero-world evaluator implementation is retained unchanged.  Its
synthetic trace generator used placeholder actuator identities that genuine
Godot/Jolt evidence never emits.  This distinct implementation preserves all
of that evaluator's declaration, trace, CAS, common-gate, task-origin,
measurement, and mutation logic while replacing only the synthetic-only
identity projection with the public ordered actuator surface used by every
native adapter.

No historical physical outcome is reclassified or reused as an R23D62 cell.
The optional cold-baseline command reads a retained R23D60 trace solely to
prove input-shape compatibility; it constructs and advances no world.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
import sys
from typing import Any, Mapping, Sequence

import r23d62_selected_profile_three_engine_turning_validation as design
import r23d62_selected_profile_three_engine_turning_validation_evaluator as legacy


ROOT = Path(__file__).resolve().parent
REPO_ROOT = ROOT.parent.parent
REJECTION_PATH = ROOT / "r23d62_evaluator_v1_zero_world_rejection_v1.json"
IMPLEMENTATION_ID = "sporespore_qsdk_r23d62_retained_evidence_evaluator_v2"
PREFLIGHT_SCHEMA = "sporespore_qsdk_r23d62_evaluator_preflight_v2"
COLD_BASELINE_SCHEMA = (
    "sporespore_qsdk_r23d62_evaluator_v2_genuine_godot_trace_cold_baseline_v1"
)
LEGACY_EVALUATOR_SHA256 = (
    "sha256:6198faf15f66d25966c51cc554f036f051c97890aa0da4a42d61267cbb2df653"
)
LEGACY_GATE_SHA256 = (
    "sha256:6ab8a1016453d3eccf2312a325161830c054c6635e75751d08fac269e1a3fd25"
)
PUBLIC_ACTUATOR_IDS = (
    "front_left_hip_motor",
    "front_left_knee_motor",
    "front_right_hip_motor",
    "front_right_knee_motor",
    "rear_left_hip_motor",
    "rear_left_knee_motor",
    "rear_right_hip_motor",
    "rear_right_knee_motor",
)
PUBLIC_JOINT_IDS = (
    "front_left_hip",
    "front_left_knee",
    "front_right_hip",
    "front_right_knee",
    "rear_left_hip",
    "rear_left_knee",
    "rear_right_hip",
    "rear_right_knee",
)
PUBLIC_LIMB_AND_JOINT_INDEX = (
    ("front_left", 0),
    ("front_left", 1),
    ("front_right", 0),
    ("front_right", 1),
    ("rear_left", 0),
    ("rear_left", 1),
    ("rear_right", 0),
    ("rear_right", 1),
)
LEGACY_PLACEHOLDER_ACTUATOR_IDS = tuple(
    f"{limb_id}_joint_{joint_index}"
    for limb_id in legacy.r60_design.LIMB_IDS
    for joint_index in range(2)
)
_LEGACY_SYNTHETIC_ROWS = legacy._synthetic_rows


class R23D62EvaluatorV2Error(RuntimeError):
    """The corrected evaluator implementation or its cold baseline is invalid."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise R23D62EvaluatorV2Error(code)


def _raw_sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def _rejection_record() -> dict[str, Any]:
    value = json.loads(REJECTION_PATH.read_text(encoding="utf-8"))
    rejected = value.get("rejected_implementation", {})
    counterexample = value.get("cold_native_shape_counterexample", {})
    successor = value.get("successor", {})
    claims = value.get("claims", {})
    legacy_path = REPO_ROOT / str(rejected.get("path", ""))
    legacy_gate_path = REPO_ROOT / str(rejected.get("zero_world_gate_path", ""))
    _require(
        value.get("schema_version")
        == "sporespore_qsdk_r23d62_evaluator_zero_world_rejection_v1",
        "R23D62_EVALUATOR_V2_REJECTION_SCHEMA_INVALID",
    )
    _require(
        value.get("status")
        == "rejected_before_physical_qualification_or_world_opening",
        "R23D62_EVALUATOR_V2_REJECTION_STATUS_INVALID",
    )
    _require(
        rejected.get("raw_sha256") == LEGACY_EVALUATOR_SHA256
        and _raw_sha256(legacy_path) == LEGACY_EVALUATOR_SHA256,
        "R23D62_EVALUATOR_V2_LEGACY_EVALUATOR_BYTES_CHANGED",
    )
    _require(
        rejected.get("zero_world_gate_raw_sha256") == LEGACY_GATE_SHA256
        and _raw_sha256(legacy_gate_path) == LEGACY_GATE_SHA256,
        "R23D62_EVALUATOR_V2_LEGACY_GATE_BYTES_CHANGED",
    )
    _require(
        rejected.get("observed_failure_codes")
        == ["R23D62_TRACE_CAP_ORDER_INVALID:0"],
        "R23D62_EVALUATOR_V2_REJECTION_FAILURE_INVALID",
    )
    _require(
        tuple(counterexample.get("ordered_actuator_ids", []))
        == PUBLIC_ACTUATOR_IDS
        and counterexample.get("legacy_evaluator_failure_codes")
        == ["R23D62_TRACE_CAP_ORDER_INVALID:0"]
        and counterexample.get("corrected_public_identity_projection_failure_codes")
        == [],
        "R23D62_EVALUATOR_V2_COUNTEREXAMPLE_INVALID",
    )
    _require(
        successor.get("implementation_id") == IMPLEMENTATION_ID
        and successor.get("path")
        == "sdk/turning/r23d62_selected_profile_three_engine_turning_validation_evaluator_v2.py"
        and successor.get("legacy_file_mutation_permitted") is False,
        "R23D62_EVALUATOR_V2_SUCCESSOR_IDENTITY_INVALID",
    )
    _require(
        not any(bool(item) for item in claims.values()),
        "R23D62_EVALUATOR_V2_REJECTION_CLAIM_INFLATION",
    )
    return value


def _correct_synthetic_rows(item: design.Cell) -> list[dict[str, Any]]:
    rows = _LEGACY_SYNTHETIC_ROWS(item)
    for row in rows:
        observation = row.get("actuator_phase_observation")
        _require(
            isinstance(observation, dict),
            "R23D62_EVALUATOR_V2_SYNTHETIC_OBSERVATION_MISSING",
        )
        original = observation.get("ordered_applications")
        _require(
            isinstance(original, list) and len(original) == design.ACTUATOR_COUNT,
            "R23D62_EVALUATOR_V2_SYNTHETIC_APPLICATIONS_INVALID",
        )
        application_by_identity: dict[tuple[str, int], dict[str, Any]] = {}
        for application in original:
            _require(
                isinstance(application, dict),
                "R23D62_EVALUATOR_V2_SYNTHETIC_APPLICATION_INVALID",
            )
            identity = (
                str(application.get("limb_id", "")),
                int(application.get("limb_joint_index", -1)),
            )
            _require(
                identity not in application_by_identity,
                "R23D62_EVALUATOR_V2_SYNTHETIC_APPLICATION_DUPLICATE",
            )
            application_by_identity[identity] = application
        corrected: list[dict[str, Any]] = []
        for index, (actuator_id, joint_id, identity, cap) in enumerate(
            zip(
                PUBLIC_ACTUATOR_IDS,
                PUBLIC_JOINT_IDS,
                PUBLIC_LIMB_AND_JOINT_INDEX,
                design.ORDERED_CAPS_NMS,
                strict=True,
            )
        ):
            _require(
                identity in application_by_identity,
                f"R23D62_EVALUATOR_V2_SYNTHETIC_IDENTITY_MISSING:{index}",
            )
            application = copy.deepcopy(application_by_identity[identity])
            limb_id, joint_index = identity
            host_role = "hip_pitch" if joint_index == 0 else "knee_pitch"
            application.update(
                actuator_id=actuator_id,
                joint_id=joint_id,
                host_joint_id=f"{limb_id}.{host_role}",
                declared_maximum_impulse_nms=cap,
                motor_maximum_impulse_readback_nms=cap,
                motor_maximum_impulse_readback_error_nms=0.0,
                maximum_impulse_readback_matches=True,
            )
            corrected.append(application)
        observation["ordered_actuator_ids"] = list(PUBLIC_ACTUATOR_IDS)
        observation["ordered_applications"] = corrected
    return rows


def _install_corrected_identity_projection() -> None:
    _require(
        tuple(legacy.PROFILE_ACTUATOR_IDS) == PUBLIC_ACTUATOR_IDS
        and tuple(legacy.PROFILE_JOINT_IDS) == PUBLIC_JOINT_IDS,
        "R23D62_EVALUATOR_V2_PUBLIC_PROFILE_IDENTITY_CHANGED",
    )
    legacy.TRACE_ACTUATOR_IDS = PUBLIC_ACTUATOR_IDS
    legacy._synthetic_rows = _correct_synthetic_rows


def run_zero_world_preflight() -> dict[str, Any]:
    rejection = _rejection_record()
    _install_corrected_identity_projection()
    probe = _correct_synthetic_rows(design.cells()[0])[0][
        "actuator_phase_observation"
    ]
    _require(
        tuple(probe.get("ordered_actuator_ids", [])) == PUBLIC_ACTUATOR_IDS,
        "R23D62_EVALUATOR_V2_PUBLIC_TRACE_ORDER_INVALID",
    )
    _require(
        tuple(
            application.get("actuator_id")
            for application in probe.get("ordered_applications", [])
        )
        == PUBLIC_ACTUATOR_IDS,
        "R23D62_EVALUATOR_V2_PUBLIC_APPLICATION_ORDER_INVALID",
    )
    value = legacy.run_zero_world_preflight()
    counterexample = rejection["cold_native_shape_counterexample"]
    value.update(
        schema_version=PREFLIGHT_SCHEMA,
        evaluator_implementation_id=IMPLEMENTATION_ID,
        rejected_predecessor_evaluator_sha256=LEGACY_EVALUATOR_SHA256,
        rejected_predecessor_failure_code="R23D62_TRACE_CAP_ORDER_INVALID:0",
        public_trace_actuator_ids=list(PUBLIC_ACTUATOR_IDS),
        placeholder_trace_actuator_identity_permitted=False,
        genuine_godot_trace_cold_baseline_sha256=counterexample[
            "retained_trace_raw_sha256"
        ],
        genuine_godot_trace_cold_baseline_row_count=counterexample[
            "retained_trace_row_count"
        ],
        genuine_godot_trace_cold_baseline_passed=True,
        historical_world_reused_as_r23d62_cell=False,
    )
    return value


def audit_genuine_godot_trace(
    trace_path: Path,
    expected_sha256: str,
) -> dict[str, Any]:
    rejection = _rejection_record()
    _install_corrected_identity_projection()
    raw = trace_path.read_bytes()
    actual_sha256 = "sha256:" + hashlib.sha256(raw).hexdigest()
    counterexample = rejection["cold_native_shape_counterexample"]
    _require(
        expected_sha256 == counterexample["retained_trace_raw_sha256"]
        and actual_sha256 == expected_sha256,
        "R23D62_EVALUATOR_V2_COLD_TRACE_DIGEST_INVALID",
    )
    rows = [json.loads(line) for line in raw.splitlines()]
    _require(
        len(rows) == design.CONTROLLER_STEPS,
        "R23D62_EVALUATOR_V2_COLD_TRACE_ROW_COUNT_INVALID",
    )
    item = design.cell("godot_jolt", "reference_zero")
    legacy.TRACE_ACTUATOR_IDS = LEGACY_PLACEHOLDER_ACTUATOR_IDS
    legacy_failures = legacy._trace_profile_cap_failures(rows, item)
    legacy.TRACE_ACTUATOR_IDS = PUBLIC_ACTUATOR_IDS
    corrected_failures = legacy._trace_profile_cap_failures(rows, item)
    first_observation: Mapping[str, Any] = rows[0]["actuator_phase_observation"]
    _require(
        legacy_failures == ["R23D62_TRACE_CAP_ORDER_INVALID:0"],
        "R23D62_EVALUATOR_V2_COLD_LEGACY_CONTROL_INVALID",
    )
    _require(
        corrected_failures == [],
        "R23D62_EVALUATOR_V2_COLD_CORRECTED_CONTROL_INVALID",
    )
    _require(
        tuple(first_observation.get("ordered_actuator_ids", []))
        == PUBLIC_ACTUATOR_IDS,
        "R23D62_EVALUATOR_V2_COLD_PUBLIC_ORDER_INVALID",
    )
    return {
        "schema_version": COLD_BASELINE_SCHEMA,
        "campaign_id": design.CAMPAIGN_ID,
        "gate_id": design.GATE_ID,
        "evaluator_implementation_id": IMPLEMENTATION_ID,
        "trace_raw_sha256": actual_sha256,
        "trace_row_count": len(rows),
        "ordered_actuator_ids": list(PUBLIC_ACTUATOR_IDS),
        "legacy_failure_codes": legacy_failures,
        "corrected_failure_codes": corrected_failures,
        "historical_result_reinterpreted": False,
        "historical_world_reused_as_r23d62_cell": False,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
    }


def _arguments(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("preflight")
    retain = commands.add_parser("retain-trace")
    retain.add_argument("--stage-id", required=True)
    retain.add_argument("--cell-id", required=True)
    retain.add_argument("--rows-json", type=Path, required=True)
    retain.add_argument("--repo-root", type=Path, required=True)
    retain.add_argument("--attempt-root", type=Path, required=True)
    retain.add_argument("--powershell", required=True)
    retain.add_argument("--test-only", action="store_true")
    retain.add_argument("--evidence-root-override", type=Path)
    evaluate = commands.add_parser("evaluate-complete")
    evaluate.add_argument("--manifest", type=Path, required=True)
    evaluate.add_argument("--expected-source-commit", required=True)
    evaluate.add_argument("--authority-repo-root", type=Path, required=True)
    cold = commands.add_parser("cold-godot-trace")
    cold.add_argument("--trace", type=Path, required=True)
    cold.add_argument("--expected-sha256", required=True)
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    arguments = _arguments(sys.argv[1:] if argv is None else argv)
    try:
        _install_corrected_identity_projection()
        if arguments.command == "preflight":
            value = run_zero_world_preflight()
            marker = "QSDK_R23D62_EVALUATOR_V2_PREFLIGHT "
        elif arguments.command == "retain-trace":
            value = legacy.retain_trace(
                stage_id=arguments.stage_id,
                cell_id=arguments.cell_id,
                rows_json_path=arguments.rows_json,
                repo_root=arguments.repo_root,
                attempt_root=arguments.attempt_root,
                powershell=arguments.powershell,
                test_only=arguments.test_only,
                evidence_root_override=arguments.evidence_root_override,
            )
            marker = "QSDK_R23D62_TRACE_RETAINED "
        elif arguments.command == "evaluate-complete":
            manifest = json.loads(arguments.manifest.read_text(encoding="utf-8"))
            entries = [
                json.loads(Path(path).read_text(encoding="utf-8"))
                for path in legacy._manifest_paths(manifest)
            ]
            value = legacy.evaluate_complete_entries(
                entries,
                expected_source_commit=arguments.expected_source_commit,
                authority_repo_root=arguments.authority_repo_root,
            )
            marker = "QSDK_R23D62_COMPLETE_EVALUATION "
        else:
            value = audit_genuine_godot_trace(
                arguments.trace,
                arguments.expected_sha256,
            )
            marker = "QSDK_R23D62_EVALUATOR_V2_COLD_GODOT_TRACE "
        print(marker + json.dumps(value, allow_nan=False, separators=(",", ":"), sort_keys=True))
    except (
        R23D62EvaluatorV2Error,
        legacy.R23D62EvaluationError,
        legacy.accepted.R23D58EvaluationError,
        legacy.accepted.inherited.R23D34EvaluationError,
        OSError,
        UnicodeError,
        json.JSONDecodeError,
        KeyError,
        TypeError,
        ValueError,
    ) as error:
        print(
            f"QSDK_R23D62_EVALUATOR_V2_FAILURE {type(error).__name__}:{error}",
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
