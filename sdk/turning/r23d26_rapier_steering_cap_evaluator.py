"""Zero-world trace retention and finite evaluation for QSDK-R23D26.

This module never constructs a physics model.  The Rust worker supplies the
complete fixed-horizon observations; this process validates and retains those
bytes before the worker emits its terminal report, then evaluates all nine
prospectively declared cells without outcome-dependent early stopping.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import sys
from typing import Any, Sequence


ROOT = Path(__file__).resolve().parent
SDK_ROOT = ROOT.parent
REPO_ROOT = SDK_ROOT.parent
DECLARATION_PATH = ROOT / "r23d26_rapier_steering_cap_preregistration_v1.json"
TRACE_PUBLISHER_PATH = SDK_ROOT / "publish_qsdk_r23d26_trace.ps1"

CAMPAIGN_ID = "QSDK-R23D26-RAPIER-STEERING-CAP-DEVELOPMENT"
GATE_ID = "QSDK-R23D26"
STAGE_ID = "rapier_steering_cap_development"
ENGINE_ID = "rapier_parry"
REPORT_SCHEMA = "sporespore_qsdk_r23d26_engine_cell_report_v1"
FAILURE_SCHEMA = "sporespore_qsdk_r23d26_worker_failure_v1"
TRACE_ROW_SCHEMA = "sporespore_qsdk_r23d26_physical_trace_row_v1"
TRACE_RETENTION_SCHEMA = "sporespore_qsdk_r23d26_trace_retention_v1"
COMPLETE_EVALUATION_SCHEMA = "sporespore_qsdk_r23d26_complete_evaluation_v1"
TRACE_ARTIFACT_SCHEMA = "sporespore_content_addressed_artifact_receipt_v1"
CONTROLLER_STEPS = 2_992
TURN_START_STEP = 600
TURN_END_STEP_EXCLUSIVE = 1_800
TOLERANCE = 1.0e-12

CANDIDATES = {
    "cap_0p10": {
        "policy_id": "sporespore_balanced_wave_r23d26_steering_cap_0p10_v1",
        "cap": 0.10,
    },
    "cap_0p20": {
        "policy_id": "sporespore_balanced_wave_r23d26_steering_cap_0p20_v1",
        "cap": 0.20,
    },
    "cap_0p30": {
        "policy_id": "sporespore_balanced_wave_r23d26_steering_cap_0p30_v1",
        "cap": 0.30,
    },
}
ARMS = {
    "reference_zero": 0.0,
    "positive_heading": 0.2,
    "negative_heading": -0.2,
}


class R23D26EvaluationError(RuntimeError):
    """The frozen declaration, trace, terminal entry, or matrix is invalid."""


def raw_sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def valid_source_commit(value: Any) -> bool:
    return (
        isinstance(value, str)
        and len(value) == 40
        and all(character in "0123456789abcdef" for character in value)
    )


def expected_cells() -> list[str]:
    return [
        f"{ENGINE_ID}__{candidate_id}__{arm_id}"
        for candidate_id in CANDIDATES
        for arm_id in ARMS
    ]


def load_declaration() -> dict[str, Any]:
    try:
        value = json.loads(DECLARATION_PATH.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise R23D26EvaluationError(
            f"R23D26_DECLARATION_UNREADABLE:{type(error).__name__}"
        ) from error
    matrix = value.get("frozen_matrix", {})
    family = value.get("candidate_family", {})
    candidates = family.get("ordered_candidates", [])
    invalid = (
        value.get("schema_version")
        != "sporespore_qsdk_r23d26_rapier_steering_cap_preregistration_v1"
        or value.get("status") != "prospective_zero_world_only"
        or value.get("campaign_id") != CAMPAIGN_ID
        or value.get("gate_id") != GATE_ID
        or family.get("only_behavioral_controller_field_changed")
        != "maximum_steering_fraction"
        or family.get("engine_specific_gait_logic_permitted") is not False
        or family.get("candidate_or_outcome_branching_permitted") is not False
        or [row.get("candidate_id") for row in candidates] != list(CANDIDATES)
        or [row.get("controller_policy_id") for row in candidates]
        != [item["policy_id"] for item in CANDIDATES.values()]
        or [row.get("maximum_steering_fraction") for row in candidates]
        != [item["cap"] for item in CANDIDATES.values()]
        or matrix.get("stage_id") != STAGE_ID
        or matrix.get("ordered_candidate_ids") != list(CANDIDATES)
        or matrix.get("ordered_arm_ids") != list(ARMS)
        or matrix.get("declared_cell_count") != 9
        or matrix.get("controller_step_count") != CONTROLLER_STEPS
        or matrix.get("turn_start_step") != TURN_START_STEP
        or matrix.get("turn_end_step_exclusive") != TURN_END_STEP_EXCLUSIVE
        or matrix.get("serial_execution_required") is not True
        or matrix.get("all_cells_run_regardless_of_intermediate_outcome") is not True
        or value.get("selector", {}).get("selected_candidate_is_validation") is not False
        or value.get("claims", {}).get("turning_validation") is not False
        or value.get("claims", {}).get("physical_acceptance_authority") is not False
    )
    if invalid:
        raise R23D26EvaluationError("R23D26_DECLARATION_IDENTITY_INVALID")
    return value


def identity(cell_id: str) -> tuple[str, str, float]:
    parts = cell_id.split("__")
    if len(parts) != 3 or parts[0] != ENGINE_ID:
        raise R23D26EvaluationError("R23D26_CELL_ID_INVALID")
    candidate_id, arm_id = parts[1], parts[2]
    if candidate_id not in CANDIDATES or arm_id not in ARMS:
        raise R23D26EvaluationError("R23D26_CELL_ID_UNKNOWN")
    return candidate_id, arm_id, CANDIDATES[candidate_id]["cap"]


def canonical_ndjson(rows: Sequence[dict[str, Any]]) -> bytes:
    return b"".join(
        (
            json.dumps(
                row,
                ensure_ascii=False,
                allow_nan=False,
                sort_keys=True,
                separators=(",", ":"),
            )
            + "\n"
        ).encode("utf-8")
        for row in rows
    )


def finite_number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def validate_trace(cell_id: str, rows: Any) -> dict[str, Any]:
    candidate_id, arm_id, cap = identity(cell_id)
    failures: list[str] = []
    if not isinstance(rows, list) or len(rows) != CONTROLLER_STEPS:
        raise R23D26EvaluationError("R23D26_TRACE_ROW_COUNT_INVALID")
    maximum_tilt = 0.0
    minimum_height = math.inf
    torso_contacts = 0
    saturation_steps = 0
    turn_start_yaw: float | None = None
    turn_end_yaw: float | None = None
    previous_contacts: dict[str, bool] | None = None
    cycles = {limb: 0 for limb in ("front_left", "front_right", "rear_left", "rear_right")}
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            failures.append(f"ROW_NOT_OBJECT:{index}")
            continue
        requested = row.get("requested_steering_fraction")
        held = row.get("held_steering_fraction")
        yaw = row.get("measured_yaw_rad")
        tilt = row.get("torso_tilt_rad")
        height = row.get("torso_height_m")
        contacts = row.get("ordered_foot_contacts")
        if (
            row.get("schema_version") != TRACE_ROW_SCHEMA
            or row.get("cell_id") != cell_id
            or row.get("trace_step") != index
            or row.get("controller_semantic_step") != index
            or not all(finite_number(value) for value in (requested, held, yaw, tilt, height))
            or abs(float(requested)) > cap + TOLERANCE
            or abs(float(held)) > cap + TOLERANCE
            or not isinstance(row.get("steering_saturated"), bool)
            or not isinstance(row.get("torso_ground_contact"), bool)
            or not isinstance(contacts, dict)
            or set(contacts) != set(cycles)
            or any(not isinstance(value, bool) for value in contacts.values())
        ):
            failures.append(f"ROW_INVALID:{index}")
            continue
        maximum_tilt = max(maximum_tilt, float(tilt))
        minimum_height = min(minimum_height, float(height))
        torso_contacts += int(row["torso_ground_contact"])
        saturation_steps += int(row["steering_saturated"])
        if index == TURN_START_STEP:
            turn_start_yaw = float(yaw)
        if index + 1 == TURN_END_STEP_EXCLUSIVE:
            turn_end_yaw = float(yaw)
        if index >= 472 and previous_contacts is not None:
            for limb in cycles:
                if not previous_contacts[limb] and contacts[limb]:
                    cycles[limb] += 1
        previous_contacts = contacts
    if failures:
        raise R23D26EvaluationError(
            "R23D26_TRACE_INVALID:" + ",".join(failures[:8])
        )
    canonical = canonical_ndjson(rows)
    return {
        "schema_version": "sporespore_qsdk_r23d26_trace_summary_v1",
        "cell_id": cell_id,
        "candidate_id": candidate_id,
        "arm_id": arm_id,
        "row_count": len(rows),
        "raw_sha256": "sha256:" + hashlib.sha256(canonical).hexdigest(),
        "byte_length": len(canonical),
        "maximum_tilt_rad": maximum_tilt,
        "minimum_torso_height_m": minimum_height,
        "torso_ground_contact_step_count": torso_contacts,
        "steering_saturation_step_count": saturation_steps,
        "contact_cycle_count_by_limb": cycles,
        "turn_phase_yaw_delta_rad": (
            None
            if turn_start_yaw is None or turn_end_yaw is None
            else math.remainder(turn_end_yaw - turn_start_yaw, 2.0 * math.pi)
        ),
        "ok": True,
        "failure_codes": [],
        "physical_acceptance_authority": False,
    }


def path_within(path: Path, parent: Path) -> bool:
    try:
        path.resolve().relative_to(parent.resolve())
        return True
    except ValueError:
        return False


def retain_trace(
    *,
    stage_id: str,
    cell_id: str,
    rows_json_path: Path,
    source_root: Path,
    repo_root: Path,
    attempt_root: Path,
    powershell: str,
    test_only: bool,
    evidence_root_override: Path | None,
) -> dict[str, Any]:
    load_declaration()
    if stage_id != STAGE_ID:
        raise R23D26EvaluationError("R23D26_STAGE_ID_INVALID")
    identity(cell_id)
    source_root = source_root.resolve()
    repo_root = repo_root.resolve()
    attempt_root = attempt_root.resolve()
    try:
        same_source = os.path.samefile(source_root, REPO_ROOT)
    except OSError:
        same_source = False
    if not same_source or not attempt_root.is_dir():
        raise R23D26EvaluationError("R23D26_RETENTION_ROOT_INVALID")
    if test_only:
        if evidence_root_override is None:
            raise R23D26EvaluationError("R23D26_TEST_EVIDENCE_ROOT_REQUIRED")
    elif evidence_root_override is not None or not path_within(
        attempt_root, repo_root.parent / "SporeSpore_Evidence"
    ):
        raise R23D26EvaluationError("R23D26_PRODUCTION_RETENTION_ROOT_INVALID")
    try:
        rows = json.loads(rows_json_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise R23D26EvaluationError(
            f"R23D26_TRACE_ROWS_UNREADABLE:{type(error).__name__}"
        ) from error
    summary = validate_trace(cell_id, rows)
    canonical = canonical_ndjson(rows)
    if (
        summary["raw_sha256"] != "sha256:" + hashlib.sha256(canonical).hexdigest()
        or summary["byte_length"] != len(canonical)
    ):
        raise R23D26EvaluationError("R23D26_TRACE_CANONICAL_RECEIPT_MISMATCH")
    trace_root = attempt_root / "traces"
    trace_root.mkdir(parents=True, exist_ok=True)
    canonical_path = trace_root / f"{stage_id}__{cell_id}.ndjson"
    try:
        with canonical_path.open("xb") as stream:
            stream.write(canonical)
    except FileExistsError as error:
        raise R23D26EvaluationError("R23D26_TRACE_STAGING_PATH_EXISTS") from error
    command = [
        powershell,
        "-NoLogo",
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        str(TRACE_PUBLISHER_PATH),
        "-RepoRoot",
        str(repo_root),
        "-ArtifactPath",
        str(canonical_path),
        "-ExpectedSha256",
        summary["raw_sha256"],
        "-ExpectedByteLength",
        str(summary["byte_length"]),
    ]
    if test_only:
        command.extend(
            ["-TestOnly", "-EvidenceRootOverride", str(evidence_root_override.resolve())]
        )
    process = subprocess.run(
        command,
        cwd=repo_root,
        capture_output=True,
        check=False,
        text=True,
        timeout=120,
    )
    marker = "QSDK_R23D26_TRACE_CAS "
    matches = [
        line[len(marker) :]
        for line in process.stdout.splitlines()
        if line.startswith(marker)
    ]
    if process.returncode != 0 or len(matches) != 1:
        raise R23D26EvaluationError(
            f"R23D26_TRACE_CAS_PUBLICATION_FAILED:{process.returncode}:{process.stderr[-500:]}"
        )
    artifact = json.loads(matches[0])
    if (
        artifact.get("schema_version") != TRACE_ARTIFACT_SCHEMA
        or artifact.get("sha256") != summary["raw_sha256"]
        or artifact.get("byte_length") != summary["byte_length"]
        or artifact.get("test_only") is not test_only
        or artifact.get("physical_acceptance_authority") is not False
    ):
        raise R23D26EvaluationError("R23D26_TRACE_CAS_RECEIPT_INVALID")
    return {
        "schema_version": TRACE_RETENTION_SCHEMA,
        "stage_id": stage_id,
        "cell_id": cell_id,
        "trace_artifact": artifact,
        "trace_summary": summary,
        "retained_before_terminal_entry": True,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def evaluate_entry(
    entry: Any,
    *,
    expected_cell_id: str,
    expected_source_commit: str,
    allow_test_artifacts: bool,
) -> dict[str, Any]:
    candidate_id, arm_id, cap = identity(expected_cell_id)
    if not isinstance(entry, dict):
        raise R23D26EvaluationError("R23D26_TERMINAL_ENTRY_INVALID")
    if entry.get("schema_version") == FAILURE_SCHEMA:
        if (
            entry.get("campaign_id") != CAMPAIGN_ID
            or entry.get("gate_id") != GATE_ID
            or entry.get("source_commit") != expected_source_commit
        ):
            raise R23D26EvaluationError("R23D26_FAILURE_IDENTITY_INVALID")
        return {
            "cell_id": expected_cell_id,
            "candidate_id": candidate_id,
            "arm_id": arm_id,
            "execution_valid": False,
            "gate_passed": False,
            "failure_codes": [entry.get("failure_code", "WORKER_FAILURE")],
        }
    execution = entry.get("execution", {})
    measurements = entry.get("measurements", {})
    artifact = entry.get("trace_artifact", {})
    summary = entry.get("trace_summary", {})
    identity_valid = (
        entry.get("schema_version") == REPORT_SCHEMA
        and entry.get("campaign_id") == CAMPAIGN_ID
        and entry.get("gate_id") == GATE_ID
        and entry.get("stage_id") == STAGE_ID
        and entry.get("cell_id") == expected_cell_id
        and entry.get("engine_id") == ENGINE_ID
        and entry.get("candidate_id") == candidate_id
        and entry.get("controller_policy_id") == CANDIDATES[candidate_id]["policy_id"]
        and entry.get("maximum_steering_fraction") == cap
        and entry.get("arm_id") == arm_id
        and entry.get("source_commit") == expected_source_commit
        and entry.get("claims", {}).get("physical_acceptance_authority") is False
    )
    artifact_valid = (
        isinstance(artifact, dict)
        and artifact.get("schema_version") == TRACE_ARTIFACT_SCHEMA
        and isinstance(artifact.get("payload_path"), str)
        and Path(artifact.get("payload_path", "")).is_file()
        and raw_sha256(Path(artifact["payload_path"])) == artifact.get("sha256")
        and Path(artifact["payload_path"]).stat().st_size == artifact.get("byte_length")
        and (allow_test_artifacts or artifact.get("test_only") is False)
        and summary.get("raw_sha256") == artifact.get("sha256")
        and summary.get("byte_length") == artifact.get("byte_length")
        and summary.get("row_count") == CONTROLLER_STEPS
    )
    common_gates = {
        "identity": identity_valid,
        "trace_artifact": artifact_valid,
        "execution_integrity": (
            execution.get("integrity_passed") is True
            and execution.get("world_attempt_count") == 1
            and execution.get("world_build_count") == 1
            and execution.get("controller_semantic_step_count") == CONTROLLER_STEPS
            and execution.get("terminal_quiescent_taper_step_count") == 0
        ),
        "forward_displacement": (
            finite_number(measurements.get("final_forward_displacement_m"))
            and measurements["final_forward_displacement_m"] >= 0.030123046875
        ),
        "tilt": (
            finite_number(measurements.get("maximum_tilt_rad"))
            and measurements["maximum_tilt_rad"] <= 0.6
        ),
        "height": (
            finite_number(measurements.get("minimum_torso_height_m"))
            and measurements["minimum_torso_height_m"] >= 0.2499708652072946
        ),
        "contacts": (
            isinstance(measurements.get("contact_cycle_count_by_limb"), dict)
            and set(measurements["contact_cycle_count_by_limb"]) == set(ARMS)  # replaced below
        ),
        "zero_failures": all(
            measurements.get(field) == 0
            for field in (
                "torso_ground_contact_step_count",
                "controller_error_count",
                "active_safe_no_actuation_count",
                "nonfinite_observation_count",
                "actuator_application_mismatch_count",
            )
        ),
        "steering_cap": (
            finite_number(measurements.get("maximum_absolute_requested_steering_fraction"))
            and finite_number(measurements.get("maximum_absolute_held_steering_fraction"))
            and measurements["maximum_absolute_requested_steering_fraction"] <= cap + TOLERANCE
            and measurements["maximum_absolute_held_steering_fraction"] <= cap + TOLERANCE
        ),
    }
    cycles = measurements.get("contact_cycle_count_by_limb", {})
    common_gates["contacts"] = (
        isinstance(cycles, dict)
        and set(cycles) == {"front_left", "front_right", "rear_left", "rear_right"}
        and all(isinstance(value, int) and value >= 2 for value in cycles.values())
    )
    yaw_delta = measurements.get("turn_phase_yaw_delta_rad")
    direction_gate = (
        arm_id == "reference_zero"
        or (
            finite_number(yaw_delta)
            and abs(yaw_delta) >= 0.01
            and math.copysign(1.0, yaw_delta) == math.copysign(1.0, ARMS[arm_id])
        )
    )
    common_gates["signed_turn_response"] = direction_gate
    failures = [name for name, passed in common_gates.items() if not passed]
    return {
        "cell_id": expected_cell_id,
        "candidate_id": candidate_id,
        "arm_id": arm_id,
        "execution_valid": identity_valid and artifact_valid and common_gates["execution_integrity"],
        "gate_passed": not failures,
        "failure_codes": failures,
        "turn_phase_yaw_delta_rad": yaw_delta,
        "final_forward_displacement_m": measurements.get("final_forward_displacement_m"),
        "maximum_tilt_rad": measurements.get("maximum_tilt_rad"),
        "minimum_torso_height_m": measurements.get("minimum_torso_height_m"),
    }


def evaluate_complete_entries(
    entries: Sequence[dict[str, Any]],
    *,
    expected_source_commit: str,
    allow_test_artifacts: bool = False,
) -> dict[str, Any]:
    declaration = load_declaration()
    if not valid_source_commit(expected_source_commit):
        raise R23D26EvaluationError("R23D26_SOURCE_COMMIT_INVALID")
    cells = expected_cells()
    if len(entries) != len(cells):
        raise R23D26EvaluationError("R23D26_COMPLETE_ENTRY_COUNT_INVALID")
    evaluations = [
        evaluate_entry(
            entry,
            expected_cell_id=cell_id,
            expected_source_commit=expected_source_commit,
            allow_test_artifacts=allow_test_artifacts,
        )
        for entry, cell_id in zip(entries, cells, strict=True)
    ]
    eligible: list[str] = []
    candidate_summaries: list[dict[str, Any]] = []
    for candidate_id in CANDIDATES:
        rows = [row for row in evaluations if row["candidate_id"] == candidate_id]
        reference = next(row for row in rows if row["arm_id"] == "reference_zero")
        positive = next(row for row in rows if row["arm_id"] == "positive_heading")
        negative = next(row for row in rows if row["arm_id"] == "negative_heading")
        bilateral_separation = (
            positive.get("turn_phase_yaw_delta_rad") - negative.get("turn_phase_yaw_delta_rad")
            if finite_number(positive.get("turn_phase_yaw_delta_rad"))
            and finite_number(negative.get("turn_phase_yaw_delta_rad"))
            else None
        )
        positive_conditioned = (
            positive.get("turn_phase_yaw_delta_rad")
            - reference.get("turn_phase_yaw_delta_rad")
            if finite_number(positive.get("turn_phase_yaw_delta_rad"))
            and finite_number(reference.get("turn_phase_yaw_delta_rad"))
            else None
        )
        negative_conditioned = (
            reference.get("turn_phase_yaw_delta_rad")
            - negative.get("turn_phase_yaw_delta_rad")
            if finite_number(reference.get("turn_phase_yaw_delta_rad"))
            and finite_number(negative.get("turn_phase_yaw_delta_rad"))
            else None
        )
        passed = (
            all(row["gate_passed"] for row in rows)
            and finite_number(bilateral_separation)
            and finite_number(positive_conditioned)
            and finite_number(negative_conditioned)
            and bilateral_separation >= 0.01
            and positive_conditioned >= 0.01
            and negative_conditioned >= 0.01
        )
        if passed:
            eligible.append(candidate_id)
        candidate_summaries.append(
            {
                "candidate_id": candidate_id,
                "maximum_steering_fraction": CANDIDATES[candidate_id]["cap"],
                "all_three_cells_passed": all(row["gate_passed"] for row in rows),
                "bilateral_yaw_separation_rad": bilateral_separation,
                "positive_reference_conditioned_yaw_delta_rad": positive_conditioned,
                "negative_reference_conditioned_yaw_delta_rad": negative_conditioned,
                "eligible": passed,
            }
        )
    selected = eligible[-1] if eligible else None
    classification = "valid_complete_positive" if selected else "valid_complete_negative"
    return {
        "schema_version": COMPLETE_EVALUATION_SCHEMA,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "source_commit": expected_source_commit,
        "declaration_raw_sha256": raw_sha256(DECLARATION_PATH),
        "classification": classification,
        "cell_count": len(evaluations),
        "cell_evaluations": evaluations,
        "candidate_summaries": candidate_summaries,
        "eligible_candidate_ids": eligible,
        "selected_candidate_id": selected,
        "selected_maximum_steering_fraction": (
            None if selected is None else CANDIDATES[selected]["cap"]
        ),
        "selection_is_validation": False,
        "distinct_prospective_validation_required": selected is not None,
        "all_cells_run_regardless_of_intermediate_outcome": (
            declaration["frozen_matrix"]["all_cells_run_regardless_of_intermediate_outcome"]
        ),
        "claims": {
            "development_screen_only": True,
            "turning_validation": False,
            "portable_basic_turning": False,
            "finite_three_engine_turning": False,
            "cross_engine_equivalence": False,
            "release_authorized": False,
            "physical_acceptance_authority": False,
        },
    }


def arguments(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    retain = commands.add_parser("retain-trace")
    retain.add_argument("--stage-id", required=True)
    retain.add_argument("--cell-id", required=True)
    retain.add_argument("--rows-json", type=Path, required=True)
    retain.add_argument("--source-root", type=Path, required=True)
    retain.add_argument("--repo-root", type=Path, required=True)
    retain.add_argument("--attempt-root", type=Path, required=True)
    retain.add_argument("--powershell", required=True)
    retain.add_argument("--test-only", action="store_true")
    retain.add_argument("--evidence-root-override", type=Path)
    evaluate = commands.add_parser("evaluate-complete")
    evaluate.add_argument("--manifest", type=Path, required=True)
    evaluate.add_argument("--source-commit", required=True)
    evaluate.add_argument("--allow-test-artifacts", action="store_true")
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = arguments(sys.argv[1:] if argv is None else argv)
    try:
        if args.command == "retain-trace":
            receipt = retain_trace(
                stage_id=args.stage_id,
                cell_id=args.cell_id,
                rows_json_path=args.rows_json,
                source_root=args.source_root,
                repo_root=args.repo_root,
                attempt_root=args.attempt_root,
                powershell=args.powershell,
                test_only=args.test_only,
                evidence_root_override=args.evidence_root_override,
            )
            print(
                "QSDK_R23D26_TRACE_RETENTION "
                + json.dumps(receipt, sort_keys=True, separators=(",", ":"))
            )
        else:
            manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
            if not isinstance(manifest, list):
                raise R23D26EvaluationError("R23D26_MANIFEST_INVALID")
            entries = [
                json.loads(Path(path).read_text(encoding="utf-8")) for path in manifest
            ]
            result = evaluate_complete_entries(
                entries,
                expected_source_commit=args.source_commit,
                allow_test_artifacts=args.allow_test_artifacts,
            )
            print(
                "QSDK_R23D26_COMPLETE_EVALUATION "
                + json.dumps(result, sort_keys=True, separators=(",", ":"))
            )
        return 0
    except (R23D26EvaluationError, OSError, UnicodeError, json.JSONDecodeError) as error:
        print(f"QSDK_R23D26_EVALUATOR_FAILURE {type(error).__name__}:{error}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
