#!/usr/bin/env python3
"""Audit the read-only R86 Godot/Jolt raise-body diagnosis."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError,
    exact,
    godot_recovery_phase_response_projection,
    load,
    loads,
    require,
    sha256,
    verify_bound_source_markers,
    verify_legacy_live_authority_projection,
    verify_retained_commit,
    verify_source_binding,
)

REPORT = ROOT / "sdk/recovery/r24d86_godot_jolt_raise_body_control_and_energy_diagnosis_v1.json"
R81_CLOSURE = ROOT / "sdk/recovery/r24d81_godot_jolt_guarded_command_recovery_behavior_negative_closure_v1.json"
R85_CLOSURE = ROOT / "sdk/recovery/r24d85_godot_jolt_corrected_adapter_recovery_behavior_negative_closure_v1.json"
HIP_IDS = (
    "front_left_hip",
    "front_right_hip",
    "rear_left_hip",
    "rear_right_hip",
)
KNEE_IDS = (
    "front_left_knee",
    "front_right_knee",
    "rear_left_knee",
    "rear_right_knee",
)


def _verify_predecessor(root: Path, closure_path: Path, claim: dict[str, object]) -> dict[str, object]:
    raw = closure_path.read_bytes()
    exact(len(raw), claim["closure_byte_length"], f"{claim['gate_id']}_CLOSURE_LENGTH")
    exact(sha256(raw), claim["closure_raw_sha256"], f"{claim['gate_id']}_CLOSURE_HASH")
    verify_retained_commit(
        root,
        str(claim["closure_commit"]),
        str(claim["physical_source_commit"]),
    )
    evidence = Path(str(claim["evidence_root"])) / str(claim["raw_result_path"])
    evidence_raw = evidence.read_bytes()
    exact(len(evidence_raw), claim["raw_result_byte_length"], f"{claim['gate_id']}_RAW_LENGTH")
    exact(sha256(evidence_raw), claim["raw_result_raw_sha256"], f"{claim['gate_id']}_RAW_HASH")
    return loads(evidence_raw)


def _selected_projection(projected: dict[str, object], report: dict[str, object]) -> None:
    keys = (
        "maximum_com_height_gain_m",
        "maximum_com_phase_step_one_based",
        "final_com_height_gain_m",
        "maximum_torso_height_ratio",
        "raised_body_gate_true_count",
        "safety_gate_true_count",
        "energy_within_0_25_j_count",
        "final_energy_balance_residual_j",
        "all_external_constraint_staging_passive_channels_structural_zero",
    )
    for key in keys:
        exact(projected[key], report[key], f"PROJECTION:{key}")
    exact(
        projected["tail_com_height_gain_delta_m"],
        report["last_120_com_height_gain_delta_m"],
        "PROJECTION:TAIL_COM",
    )
    exact(
        projected["phase_mechanical_energy_delta_j"],
        report["raise_body_mechanical_energy_delta_j"],
        "PROJECTION:MECHANICAL_ENERGY",
    )
    exact(
        projected["phase_actuator_work_delta_j"],
        report["raise_body_actuator_work_delta_j"],
        "PROJECTION:ACTUATOR_WORK",
    )


def _verify_hip_rows(projected: dict[str, object], expected: list[dict[str, object]]) -> None:
    exact([row["joint_id"] for row in expected], list(HIP_IDS), "HIP_ORDER")
    joints = projected["joints"]
    assert isinstance(joints, dict)
    for row in expected:
        joint_id = str(row["joint_id"])
        actual = joints[joint_id]
        for report_key, projection_key in (
            ("final_position_error_rad", "final_position_error_rad"),
            ("command_speed_cap_count", "settled_target_command_speed_cap_count"),
            ("native_impulse_cap_exact_count", "settled_target_native_impulse_cap_exact_count"),
            ("last_120_position_delta_rad", "tail_position_delta_rad"),
        ):
            exact(actual[projection_key], row[report_key], f"HIP:{joint_id}:{report_key}")
        if "settled_target_entry_position_rad" in row:
            exact(
                actual["settled_target_entry_position_rad"],
                row["settled_target_entry_position_rad"],
                f"HIP:{joint_id}:SETTLED_ENTRY",
            )
            exact(actual["final_position_rad"], row["final_position_rad"], f"HIP:{joint_id}:FINAL")


def _rapier_projection(result: dict[str, object]) -> dict[str, object]:
    capture = result["candidate"]["complete_capture"]
    observations = capture["trace_v3"]["observations"]
    invariants = capture["in_run_invariant_receipts"]
    indices = [index for index, receipt in enumerate(invariants) if receipt["phase"] == "raise_body"]
    exact(indices, list(range(indices[0], indices[-1] + 1)), "R55_RAISE_CONTIGUOUS")
    hip_offsets = (0, 2, 4, 6)
    ratios: list[float] = []
    cap_count = 0
    speed_count_by_hip = [0, 0, 0, 0]
    for index in indices:
        application = invariants[index]["application"]
        exact(
            application["actuator_profile_id"],
            "sporespore_qsdk_r23d60_selected_s169_actuator_cap_profile_v1",
            f"R55_PROFILE:{index}",
        )
        for hip_index, offset in enumerate(hip_offsets):
            applied = abs(float(application["ordered_applied_impulses"][offset]["applied_angular_impulse_nms"]))
            readback = application["ordered_pre_step_readbacks"][offset]
            cap = float(readback["outer_step_impulse_readback_nms"])
            ratios.append(applied / cap)
            cap_count += applied / cap >= 0.999
            speed_count_by_hip[hip_index] += (
                abs(float(readback["motor_target_velocity_readback_rad_s"])) >= 0.75 - 1.0e-12
            )
    final = observations[indices[-1]]
    initial_com_y = float(observations[0]["center_of_mass"]["position_world_m"]["y"])
    energy = final["energy_balance"]
    signed_residual = (
        float(energy["current_mechanical_energy_j"])
        - float(energy["initial_mechanical_energy_j"])
        - float(energy["cumulative_applied_actuator_work_j"])
        - float(energy["cumulative_signed_external_work_j"])
        - float(energy["cumulative_signed_constraint_exchange_j"])
        - float(energy["cumulative_signed_discrete_staging_exchange_j"])
        + float(energy["cumulative_passive_dissipation_j"])
    )
    return {
        "raise_body_step_count": len(indices),
        "raise_body_first_observation_index": indices[0],
        "raise_body_last_observation_index": indices[-1],
        "handoff_semantic_step": final["semantic_step"],
        "handoff_com_height_gain_m": float(final["center_of_mass"]["position_world_m"]["y"]) - initial_com_y,
        "handoff_energy_residual_magnitude_j": abs(signed_residual),
        "maximum_observed_hip_impulse_cap_fraction": max(ratios),
        "hip_impulse_cap_99_9_percent_count": cap_count,
        "all_four_hip_command_speed_caps_cover_raise_body": all(
            count == len(indices) for count in speed_count_by_hip
        ),
    }


def audit() -> None:
    report = load(REPORT)
    exact(
        (
            report["schema_version"],
            report["gate_id"],
            report["authored_parent_commit"],
            report["ledger_scope"],
            report["physical_question_declared"],
            report["model_construction_count"],
            report["world_attempt_count"],
            report["world_build_count"],
            report["solver_step_count"],
        ),
        (
            "sporespore_qsdk_r24d86_godot_jolt_raise_body_control_and_energy_diagnosis_v1",
            "QSDK-R24D86",
            "f94d5239bfd86c4218613eb0ce143837e7dd72cf",
            {
                "subsystem": "recovery",
                "engine_scope": "godot_jolt",
                "authority_mode": "zero_world_retained_trace_and_bound_source_diagnosis",
                "question_class": "development",
            },
            False,
            0,
            0,
            0,
            0,
        ),
        "REPORT_IDENTITY",
    )

    r81 = _verify_predecessor(ROOT, R81_CLOSURE, report["predecessors"]["r81"])
    r85 = _verify_predecessor(ROOT, R85_CLOSURE, report["predecessors"]["r85"])
    exact(set(r81), set(r85), "PREDECESSOR_TOP_LEVEL_SCHEMA")

    source_commit = report["source_basis"]["repository_source_commit"]
    bound = {
        item["path"]: verify_source_binding(ROOT, source_commit, item)
        for item in report["source_basis"]["repository_bindings"]
    }
    verify_bound_source_markers(bound, {
        "sdk/core/src/recovery.rs": (
            "minimum_com_height_gain_m: 0.22",
            "maximum_energy_balance_residual_j: 0.25",
            "let raised_body_gate = center_of_mass_height_gain_m",
            "let safety_gate = joint_limits_respected",
        ),
        "sdk/core/src/recovery_runtime.rs": (
            "const RAISE_BODY_RAMP_STEPS: u32 = 360;",
            "const STANCE_TARGETS_RAD: [f64; 8] = [0.0; 8];",
            "!classification.raised_body_gate || !classification.safety_gate",
        ),
        "sdk/adapters/godot/gdscript/recovery_native_route_v1.gd": (
            "(target - position) / OUTER_STEP_DURATION_S",
            "LEGACY_GODOT_HOST_TO_CANONICAL_VELOCITY_SIGN",
        ),
        "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd": (
            "HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY",
            "HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE",
            '"cumulative_signed_constraint_exchange_j": 0.0',
            '"cumulative_passive_dissipation_j": 0.0',
        ),
        "sdk/adapters/rapier/src/qsdk_r24d45_recovery_route.rs": (
            "set_motor_velocity(",
            "VELOCITY_ONLY_MOTOR_DAMPING_NM_S_PER_RAD",
            "let actuator_work_j = signed_impulse_nms * centered_velocity_rad_s;",
            '"actuator_work_j": actuator_work_j',
        ),
        "sdk/adapters/rapier/src/velocity_only_live_integration.rs": (
            "VELOCITY_ONLY_MOTOR_DAMPING_NM_S_PER_RAD: f32 = 10.0",
            "MotorModel::ForceBased",
        ),
        "sdk/recovery/r24d57_godot_jolt_native_recovery_route_contract_v1.json": (
            '"unclosed_residual_preserved": true',
            '"constraint_and_passive_partition_claimed_complete": false',
            '"physical_energy_balance_claimed_by_this_gate": false',
        ),
        "sdk/recovery/r24d55_rapier_terminal_prefix_recovery_development_positive_closure_v1.json": (
            '"exact_nominal_rapier_prone_to_standing_observed": true',
            '"terminal_absolute_energy_residual_j": 1.8697292034630664e-6',
        ),
    }, "BOUND_SOURCE")

    projections: dict[str, dict[str, object]] = {}
    for identity, raw in (("r81", r81), ("r85", r85)):
        projection = godot_recovery_phase_response_projection(
            raw["candidate_arm"],
            "raise_body",
            settled_target_phase_step=360,
            tail_step_count=120,
        )
        projections[identity] = projection
        exact(
            (
                projection["phase_step_count"],
                projection["first_observation_index"],
                projection["last_observation_index"],
                projection["settled_target_step_count"],
            ),
            (600, 136, 735, 240),
            f"{identity.upper()}_PHASE_ALIGNMENT",
        )
        _selected_projection(projection, report[f"{identity}_projection"])
        _verify_hip_rows(projection, report[f"{identity}_projection"]["settled_zero_target_hip_projection"])

    r85_joints = projections["r85"]["joints"]
    assert isinstance(r85_joints, dict)
    knee_claim = report["r85_projection"]["settled_zero_target_knee_projection"]
    exact(list(KNEE_IDS), knee_claim["ordered_joint_ids"], "R85_KNEE_ORDER")
    exact(
        [r85_joints[joint_id]["final_position_rad"] for joint_id in KNEE_IDS],
        [knee_claim["all_final_positions_rad"]] * 4,
        "R85_KNEE_FINAL",
    )
    exact(
        sum(r85_joints[joint_id]["settled_target_command_speed_cap_count"] for joint_id in KNEE_IDS),
        knee_claim["total_command_speed_cap_count"],
        "R85_KNEE_SPEED_CAP",
    )
    exact(
        sum(r85_joints[joint_id]["settled_target_native_impulse_cap_exact_count"] for joint_id in KNEE_IDS),
        knee_claim["total_native_impulse_cap_exact_count"],
        "R85_KNEE_IMPULSE_CAP",
    )
    exact(0.22 - projections["r85"]["maximum_com_height_gain_m"],
          report["r85_projection"]["minimum_com_gain_shortfall_m"], "R85_COM_SHORTFALL")

    reference = report["rapier_reference"]
    reference_raw = Path(reference["physical_result_path"]).read_bytes()
    exact(len(reference_raw), reference["physical_result_byte_length"], "R55_RESULT_LENGTH")
    exact(sha256(reference_raw), reference["physical_result_raw_sha256"], "R55_RESULT_HASH")
    r55 = _rapier_projection(loads(reference_raw))
    for report_key in (
        "raise_body_step_count",
        "handoff_semantic_step",
        "handoff_com_height_gain_m",
        "handoff_energy_residual_magnitude_j",
        "maximum_observed_hip_impulse_cap_fraction",
        "hip_impulse_cap_99_9_percent_count",
    ):
        exact(r55[report_key], reference[report_key], f"R55:{report_key}")
    exact(
        r55["all_four_hip_command_speed_caps_cover_raise_body"],
        reference["all_four_hip_command_speed_cap_counts_equal_raise_body_step_count"],
        "R55_HIP_SPEED_CAPS",
    )

    require(all(
        projections["r85"]["joints"][joint_id]["settled_target_command_speed_cap_count"] == 240
        and projections["r85"]["joints"][joint_id]["settled_target_native_impulse_cap_exact_count"] == 240
        for joint_id in HIP_IDS
    ), "R85_ALL_HIPS_SATURATED")
    exact(
        {
            key: report["decision"][key]
            for key in (
                "r86_diagnosis_closed",
                "r81_and_r85_results_preserved",
                "r81_or_r85_rerun_required",
                "r87_distinct_adapter_successor_required",
                "r87_adapter_actuator_mapping_change_required",
                "r87_actuator_work_source_change_required",
                "r87_threshold_change_permitted",
                "r87_actuator_cap_change_permitted",
                "physical_execution_authorized",
                "prone_to_standing_claimed",
                "sdk1_milestone_advanced",
                "physical_acceptance_authority",
                "release_authority",
            )
        },
        {
            "r86_diagnosis_closed": True,
            "r81_and_r85_results_preserved": True,
            "r81_or_r85_rerun_required": False,
            "r87_distinct_adapter_successor_required": True,
            "r87_adapter_actuator_mapping_change_required": True,
            "r87_actuator_work_source_change_required": True,
            "r87_threshold_change_permitted": False,
            "r87_actuator_cap_change_permitted": False,
            "physical_execution_authorized": False,
            "prone_to_standing_claimed": False,
            "sdk1_milestone_advanced": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        "DECISION",
    )
    exact(
        (
            report["next_boundary"]["gate_id"],
            report["next_boundary"]["ledger_prefix"],
            report["next_boundary"]["question_class"],
            report["next_boundary"]["physical_question_declared"],
            report["next_boundary"]["full_seeded_ghost_required"],
            report["next_boundary"]["physical_execution_blocked"],
            report["next_boundary"]["maximum_world_attempt_count"],
            report["next_boundary"]["maximum_world_build_count"],
            report["next_boundary"]["maximum_physical_steps_authorized"],
        ),
        ("QSDK-R24D87", "[recovery/godot]", "development", False, False, True, 0, 0, 0),
        "NEXT_BOUNDARY",
    )

    report_raw = REPORT.read_bytes()
    verify_legacy_live_authority_projection(
        ROOT,
        report["live_authority_paths"],
        record_key="r24d86_diagnosis_path",
        expected={
            "r24d86_diagnosis_closed": True,
            "r24d86_diagnosis_path": REPORT.relative_to(ROOT).as_posix(),
            "r24d86_diagnosis_byte_length": len(report_raw),
            "r24d86_diagnosis_raw_sha256": sha256(report_raw),
            "r24d86_model_construction_count": 0,
            "r24d86_world_attempt_count": 0,
            "r24d86_world_build_count": 0,
            "r24d86_solver_step_count": 0,
            "r24d86_physical_execution_authorized": False,
            "r24d86_sdk1_milestone_advanced": False,
            "prone_to_standing_claimed": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        prefix="LIVE_R86",
    )


def main() -> int:
    try:
        audit()
    except (ClosureAuditError, KeyError, TypeError, ValueError, OSError) as exc:
        print(f"QSDK_R24D86_DIAGNOSIS_FAIL:{exc}", file=sys.stderr)
        return 1
    print(
        "QSDK_R24D86_DIAGNOSIS_PASS "
        "r81=600 r85=600 settled=240 hips=4/4 energy_authority=unclosed "
        "next=R24D87 worlds=0 sdk1=11/20"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
