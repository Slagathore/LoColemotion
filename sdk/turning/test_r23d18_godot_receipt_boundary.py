"""Exact Godot-worker to Python-evaluator receipt boundary control for R23D18."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import shutil
import subprocess
import tempfile
from pathlib import Path

import r23d18_physical_evaluator as evaluator
import r23d18_physical_trace as design

MARKER = "QSDK_R23D18_GODOT_RECEIPT_PROJECTION "


def _report(cell: design.Cell, retained: dict[str, object]) -> dict[str, object]:
    summary = copy.deepcopy(retained["trace_summary"])
    replay = summary["taper_outcome"]
    applications = int(
        design.CONTROLLER_STEPS * design.ACTUATOR_COUNT
        + replay["active_native_application_count"]
    )
    yaw = 0.0 if cell.arm_id == "reference_zero" else cell.turn_heading_offset_rad * 0.5
    return {
        "schema_version": evaluator.REPORT_SCHEMA,
        "campaign_id": evaluator.CAMPAIGN_ID,
        "gate_id": evaluator.GATE_ID,
        "stage_id": cell.stage_id,
        "cell_id": cell.cell_id,
        "engine_id": cell.engine_id,
        "arm_id": cell.arm_id,
        "turn_heading_offset_rad": cell.turn_heading_offset_rad,
        "source_commit": "a" * 40,
        "trace_artifact": copy.deepcopy(retained["trace_artifact"]),
        "trace_summary": summary,
        "execution": {
            "integrity_passed": True,
            "worker_failure_code": "",
            "controller_semantic_step_count": design.CONTROLLER_STEPS,
            "terminal_quiescent_taper_step_count": design.TERMINAL_STEPS,
            "validated_portable_command_count": applications,
            "native_actuation_application_count": applications,
            "post_handoff_native_actuation_application_count": 0,
            "portable_impulse_violation_count": 0,
            "world_attempt_count": 1,
            "world_build_count": 1,
            "trace_retained_before_terminal_entry": True,
            "fixed_horizon_configuration_proved_before_fixture_insertion": True,
        },
        "measurements": {
            "final_forward_displacement_m": 1.0,
            "turn_phase_yaw_delta_rad": yaw,
            "maximum_absolute_requested_steering_fraction": 0.2,
            "maximum_absolute_held_steering_fraction": 0.2,
            "maximum_tilt_rad": 0.2,
            "minimum_torso_height_m": 0.4,
            "contact_cycle_count_by_limb": {limb: 2 for limb in design.LIMB_IDS},
            "torso_ground_contact_step_count": 0,
            "controller_error_count": 0,
            "active_safe_no_actuation_count": 0,
            "nonfinite_observation_count": 0,
            "actuator_application_mismatch_count": 0,
            "controller_semantic_step_count": design.CONTROLLER_STEPS,
            "terminal_quiescent_taper_step_count": design.TERMINAL_STEPS,
            "validated_portable_command_count": applications,
            "native_actuation_application_count": applications,
            "post_handoff_native_actuation_application_count": 0,
            "confirmation_satisfied": replay["confirmation_satisfied"],
            "handoff_after_active_step": int(replay["handoff_after_active_step"]),
            "first_passive_step": int(replay["first_passive_step"]),
            "handoff_reason": replay["handoff_reason"],
            "active_terminal_step_count": int(replay["active_step_count"]),
            "quiescent_taper_step_count": int(replay["taper_step_count"]),
            "passive_terminal_step_count": int(replay["passive_step_count"]),
            "taper_reset_count": int(replay["taper_reset_count"]),
            "active_terminal_native_actuation_application_count": int(
                replay["active_native_application_count"]
            ),
            "quiescent_taper_gate_passed": replay["quiescent_taper_gate_passed"],
            "first_post_handoff_contact_loss_step": replay[
                "first_post_handoff_contact_loss_step"
            ],
            "post_handoff_contact_loss_step_count": int(
                replay["post_handoff_contact_loss_step_count"]
            ),
            "terminal_receipt_validation_failure_count": 0,
            "maximum_absolute_terminal_active_joint_velocity_rad_s": 0.35,
        },
        "claims": copy.deepcopy(evaluator.FALSE_CLAIMS),
    }


def run(godot: Path) -> None:
    powershell = shutil.which("pwsh")
    if not powershell:
        raise RuntimeError("pwsh is required")
    with tempfile.TemporaryDirectory(prefix="r23d18-godot-receipt-") as raw_root:
        root = Path(raw_root)
        evidence_root = root / "evidence"
        attempt_root = root / "attempt"
        evidence_root.mkdir()
        attempt_root.mkdir()
        cell = design.cell_for_identity(
            design.MATRIX_STAGE_ID,
            "godot_jolt__tight_gated_horizon__reference_zero",
        )
        rows_path = root / "rows.json"
        rows_path.write_text(json.dumps(design.synthetic_trace(cell)), encoding="utf-8")
        retained = evaluator.retain_trace(
            stage_id=cell.stage_id,
            cell_id=cell.cell_id,
            rows_json_path=rows_path,
            repo_root=evaluator.REPO_ROOT,
            attempt_root=attempt_root,
            powershell=powershell,
            test_only=True,
            evidence_root_override=evidence_root,
        )
        receipt_path = root / "retention-receipt.json"
        receipt_path.write_text(json.dumps(retained), encoding="utf-8")
        process = subprocess.run(
            [
                str(godot),
                "--headless",
                "--path",
                str(evaluator.REPO_ROOT),
                "--script",
                "res://tests/test_sdk_qsdk_r23d18_receipt_projection.gd",
                "--",
                "--receipt-path",
                str(receipt_path),
            ],
            cwd=evaluator.REPO_ROOT,
            capture_output=True,
            check=False,
            text=True,
            timeout=60,
        )
        matches = [line[len(MARKER) :] for line in process.stdout.splitlines() if line.startswith(MARKER)]
        if process.returncode != 0 or len(matches) != 1:
            raise AssertionError(f"Godot projection failed: {process.stderr[-500:]}")
        projected = json.loads(matches[0])
        normalized = projected["receipt"]
        byte_length = normalized["trace_artifact"]["byte_length"]
        if type(byte_length) is not int:
            raise AssertionError("Godot projection did not emit an integer JSON token")

        valid = _report(cell, normalized)
        accepted = evaluator.evaluate_entry(
            valid,
            cell,
            expected_source_commit="a" * 40,
            allow_test_artifacts=True,
        )
        if not accepted["entry_valid"]:
            raise AssertionError(accepted["failure_codes"])

        artifact_json = json.dumps(
            valid["trace_artifact"], separators=(",", ":"), allow_nan=False
        )
        integer_token = f'"byte_length":{byte_length}'
        real_token = f'"byte_length":{byte_length}.0'
        if artifact_json.count(integer_token) != 1:
            raise AssertionError("expected exactly one relevant integer receipt token")
        mutated = copy.deepcopy(valid)
        mutated["trace_artifact"] = json.loads(
            artifact_json.replace(integer_token, real_token, 1)
        )
        if type(mutated["trace_artifact"]["byte_length"]) is not float:
            raise AssertionError("JSON-real mutation did not survive parsing")
        refused = evaluator.evaluate_entry(
            mutated,
            cell,
            expected_source_commit="a" * 40,
            allow_test_artifacts=True,
        )
        if refused["entry_valid"] or "R23D18_TRACE_ARTIFACT_RECEIPT" not in refused["failure_codes"]:
            raise AssertionError(refused["failure_codes"])

        digest = "sha256:" + hashlib.sha256(matches[0].encode("utf-8")).hexdigest()
        print(
            "R23D18_GODOT_RECEIPT_BOUNDARY_PASS "
            f"integer_fields=1 json_real_mutations=1 projection_sha256={digest} "
            "models=0 worlds=0 physical_authority=False"
        )


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", type=Path, required=True)
    run(parser.parse_args().godot)
