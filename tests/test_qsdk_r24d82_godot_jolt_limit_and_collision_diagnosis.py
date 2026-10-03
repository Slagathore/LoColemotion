#!/usr/bin/env python3
"""Compact audit of the read-only R82 Godot/Jolt adapter diagnosis."""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError,
    collision_masks_interact,
    exact,
    git,
    joint_position_ranges,
    load,
    require,
    sha256,
    verify_bound_source_markers,
    verify_exact_paths,
    verify_initial_relative_joint_limit_projection,
    verify_legacy_live_authority_projection,
    verify_retained_commit,
    verify_source_binding,
)

REPORT = ROOT / "sdk/recovery/r24d82_godot_jolt_limit_and_collision_diagnosis_v1.json"
R81 = ROOT / "sdk/recovery/r24d81_godot_jolt_guarded_command_recovery_behavior_negative_closure_v1.json"
PHYSICAL_SOURCE = "c17178c2ef5447fb4368ab268ef1a6eb94c5b595"
CLOSURE_COMMIT = "3969c3b154428e86ba22f232d4607b096a925f0c"
GODOT_ROOT = Path(r"C:\Users\Cole\CodeStuff\dependencies\godot-sporespore-4.7")
GODOT_COMMIT = "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88"


def audit() -> None:
    report = load(REPORT)
    verify_exact_paths(report, {
        "schema_version": "sporespore_qsdk_r24d82_godot_jolt_limit_and_collision_diagnosis_v1",
        "gate_id": "QSDK-R24D82",
        "ledger_scope.subsystem": "recovery",
        "ledger_scope.engine_scope": "godot_jolt",
        "ledger_scope.authority_mode": "zero_world_retained_trace_and_pinned_source_diagnosis",
        "ledger_scope.question_class": "development",
        "authored_parent_commit": CLOSURE_COMMIT,
        "question_class": "development",
        "physical_question_declared": False,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "next_boundary.gate_id": "QSDK-R24D83",
        "next_boundary.physical_question_declared": False,
        "next_boundary.full_seeded_ghost_required": False,
        "next_boundary.physical_execution_blocked": True,
        "next_boundary.maximum_world_attempt_count": 0,
        "next_boundary.maximum_world_build_count": 0,
        "next_boundary.maximum_physical_steps_authorized": 0,
    }, "REPORT")
    verify_retained_commit(ROOT, CLOSURE_COMMIT, PHYSICAL_SOURCE)

    predecessor = report["predecessor"]
    verify_exact_paths(predecessor, {
        "gate_id": "QSDK-R24D81",
        "physical_source_commit": PHYSICAL_SOURCE,
        "closure_commit": CLOSURE_COMMIT,
        "retained_evidence_reexecuted": False,
        "retained_trace_read_only_replay": True,
        "same_identity_rerun_permitted": False,
        "same_identity_requalification_permitted": False,
        "historical_result_rewritten": False,
        "historical_threshold_rewritten": False,
        "historical_selector_rewritten": False,
        "historical_evaluator_rewritten": False,
        "historical_interpretation_rewritten": False,
    }, "PREDECESSOR")
    closure_raw = R81.read_bytes()
    exact((len(closure_raw), sha256(closure_raw)),
          (predecessor["closure_byte_length"], predecessor["closure_raw_sha256"]),
          "R81_CLOSURE")

    basis = report["source_basis"]
    repo_bound = {
        item["path"]: verify_source_binding(ROOT, PHYSICAL_SOURCE, item)
        for item in basis["repository_bindings"]
    }
    repo_text = verify_bound_source_markers(repo_bound, {
        "sdk/core/src/recovery_morphology.rs": (
            "hip_limit_magnitude_rad: 1.60", "knee_limit_magnitude_rad: 1.10",
            "front_hip_angle_rad: 1.55", "rear_knee_angle_rad: -1.10",
        ),
        "sdk/recovery/r24d17_native_recovery_runtime_and_physical_profile_contract_v1.json": (
            '"establish_distal_support_ordered_target_positions_rad"', "1.05",
        ),
        "sdk/adapters/godot/gdscript/recovery_native_route_v1.gd": (
            "const LEGACY_GODOT_HOST_TO_CANONICAL_VELOCITY_SIGN := -1.0",
            "canonical_target_velocity_rad_s\n\t\t* LEGACY_GODOT_HOST_TO_CANONICAL_VELOCITY_SIGN",
        ),
        "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd": (
            "floor.collision_layer = 1", "floor.collision_mask = 0",
            "body.collision_layer = 1", "body.collision_mask = 1",
            'joint.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, float(joint_spec["lower_limit_rad"]))',
            'joint.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, float(joint_spec["upper_limit_rad"]))',
            'if String(sample.get("counterparty_id", "")) != "floor":',
        ),
        "sdk/adapters/godot/engine_patches/godot_4_7_jolt_solved_contact_telemetry_v3.patch": (
            "sporespore_solved_contact_telemetry",
        ),
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/selected_policy_development.py": (
            '"contype": "2"', '"conaffinity": "1"',
            '"contype": "1"', '"conaffinity": "2"',
        ),
        "sdk/adapters/rapier/src/locomotion.rs": (
            "InteractionTestMode::And",
            ".collision_groups(groups(Group::GROUP_2, Group::GROUP_1))",
            ".collision_groups(groups(Group::GROUP_1, Group::GROUP_2))",
        ),
    }, "REPO_SOURCE")
    patch = repo_text["sdk/adapters/godot/engine_patches/godot_4_7_jolt_solved_contact_telemetry_v3.patch"]
    require(not any(value in patch for value in ("mLimitsMin", "mLimitsMax", "limit_midpoint")),
            "PATCH_LIMIT_SEMANTICS")
    r17 = json.loads(repo_text["sdk/recovery/r24d17_native_recovery_runtime_and_physical_profile_contract_v1.json"])
    exact(r17["controller_candidate"]["establish_distal_support_ordered_target_positions_rad"],
          report["joint_limit_diagnosis"]["controller_establish_distal_support_ordered_target_positions_rad"],
          "CONTROLLER_TARGETS")

    exact(Path(basis["godot_source_root"]), GODOT_ROOT, "GODOT_ROOT")
    exact(git(GODOT_ROOT, "rev-parse", "HEAD"), GODOT_COMMIT, "GODOT_HEAD")
    exact(git(GODOT_ROOT, "remote", "get-url", "origin"), basis["godot_source_remote"],
          "GODOT_REMOTE")
    native_bound = {
        item["path"]: verify_source_binding(GODOT_ROOT, GODOT_COMMIT, item)
        for item in basis["godot_source_bindings"]
    }
    verify_bound_source_markers(native_bound, {
        "scene/3d/physics/joints/hinge_joint_3d.cpp": (
            "Transform3D local_a = ainv * gt;", "Transform3D local_b = gt;",
            "local_b = binv * gt;", "joint_make_hinge(p_joint",
        ),
        "modules/jolt_physics/joints/jolt_hinge_joint_3d.cpp": (
            "const double limit_midpoint = (limit_lower + limit_upper) / 2.0f;",
            "ref_shift = float(-limit_midpoint);",
            "constraint_settings.mLimitsMin = -p_limit;",
            "constraint_settings.mLimitsMax = p_limit;",
        ),
        "modules/jolt_physics/spaces/jolt_layers.cpp": (
            "const bool first_scans_second = (collision_mask1 & collision_layer2) != 0;",
            "const bool second_scans_first = (collision_mask2 & collision_layer1) != 0;",
            "return first_scans_second || second_scans_first;",
        ),
    }, "GODOT_SOURCE")

    limits = report["joint_limit_diagnosis"]
    rows = limits["ordered_joint_projection"]
    exact(len(rows), 8, "JOINT_COUNT")
    verify_initial_relative_joint_limit_projection(
        rows,
        host_velocity_sign=limits["canonical_to_host_velocity_sign"],
        prefix="LIMIT",
        require_nontrivial_offset=True,
    )
    for row in rows:
        if row["joint_id"] in ("rear_left_knee", "rear_right_knee"):
            require(row["current_realizable_canonical_upper_rad"] < 1.05 <= row["canonical_upper_rad"],
                    f"REAR_TARGET:{row['joint_id']}")
    verify_exact_paths(limits, {
        "godot_scene_hinge_zero_is_construction_pose": True,
        "jolt_limit_interval_is_relative_to_scene_hinge_zero": True,
        "current_adapter_passes_absolute_canonical_limits_as_relative_host_limits": True,
        "rear_knee_positive_1_05_rad_controller_target_reachable_under_current_mapping": False,
        "rear_knee_positive_1_05_rad_controller_target_reachable_under_required_projection": True,
        "canonical_absolute_limit_projection_defect_proven": True,
    }, "LIMITS")

    raw_path = Path(predecessor["evidence_root"]) / predecessor["raw_result_path"]
    raw_bytes = raw_path.read_bytes()
    exact((len(raw_bytes), sha256(raw_bytes)),
          (predecessor["raw_result_byte_length"], predecessor["raw_result_raw_sha256"]),
          "R81_RAW")
    candidate = json.loads(raw_bytes)["candidate_arm"]
    trace = candidate["trace_v3"]["observations"]
    observed = report["retained_trace_observation"]
    exact(len(trace), observed["candidate_observation_count"], "TRACE_COUNT")
    exact(candidate["initializer_manifest"]["ordered_joint_positions_rad"],
          observed["ordered_initial_joint_positions_rad"], "INITIAL_JOINTS")
    exact(joint_position_ranges(trace, tuple(observed["knee_ranges_and_final_rad"])),
          observed["knee_ranges_and_final_rad"], "KNEE_RANGES")
    seam = observed["seam_sample"]
    sample = trace[seam["semantic_step"] - 1]
    joint = {item["joint_id"]: item["position_rad"]
             for item in sample["state"]["ordered_joint_observations"]}
    impulse = {item["actuator_id"]: item["applied_angular_impulse_nms"]
               for item in sample["applied_actuation"]["ordered_applied_impulses"]}
    exact((joint["rear_left_knee"], joint["rear_right_knee"],
           impulse["rear_left_knee_motor"], impulse["rear_right_knee_motor"],
           sample["energy_balance"]["cumulative_applied_actuator_work_j"]),
          (seam["rear_left_knee_position_rad"], seam["rear_right_knee_position_rad"],
           seam["rear_left_knee_applied_angular_impulse_nms"],
           seam["rear_right_knee_applied_angular_impulse_nms"],
           seam["cumulative_applied_actuator_work_j"]), "SEAM")
    final = trace[-1]
    exact((final["energy_balance"]["cumulative_applied_actuator_work_j"],
           final["energy_balance"]["current_mechanical_energy_j"],
           candidate["portable_step_receipts"][-1]["classification"]["energy_balance_residual_j"]),
          (observed["final_cumulative_applied_actuator_work_j"],
           observed["final_mechanical_energy_j"],
           observed["final_energy_balance_residual_magnitude_j"]), "FINAL_ENERGY")

    collision = report["collision_group_diagnosis"]
    current_floor, current_robot = collision["current_godot_floor"], collision["current_godot_robot_body"]
    required_floor, required_robot = collision["required_godot_floor"], collision["required_godot_robot_body"]
    exact((collision_masks_interact(current_robot, current_floor),
           collision_masks_interact(current_robot, current_robot),
           collision_masks_interact(required_robot, required_floor),
           collision_masks_interact(required_robot, required_robot)),
          (True, True, True, False), "COLLISION_PROJECTION")
    verify_exact_paths(collision, {
        "mujoco_robot_robot_collision_enabled": False,
        "rapier_robot_robot_collision_enabled": False,
        "r81_floor_contact_projection_skips_non_floor_counterparties": True,
        "r81_self_contact_observed": False,
        "r81_self_contact_absence_proven": False,
        "r81_in_run_invariants_invalidated": False,
        "cross_engine_collision_filter_parity_defect_proven": True,
    }, "COLLISION")
    verify_exact_paths(report, {
        "energy_interpretation.retained_work_growth_is_temporally_associated_with_rear_knee_limit_drive": True,
        "energy_interpretation.joint_limit_projection_defect_proven_to_fully_explain_energy_residual": False,
        "energy_interpretation.energy_ledger_defect_proven": False,
        "decision.r82_diagnosis_closed": True,
        "decision.r81_result_preserved": True,
        "decision.r81_rerun_required": False,
        "decision.r83_limit_projection_correction_required": True,
        "decision.r83_collision_filter_correction_required": True,
        "decision.r83_controller_change_permitted": False,
        "decision.r83_evaluator_change_permitted": False,
        "decision.r83_threshold_change_permitted": False,
        "decision.r83_actuator_cap_change_permitted": False,
        "decision.physical_execution_authorized": False,
        "decision.prone_to_standing_claimed": False,
        "decision.sdk1_milestone_advanced": False,
        "decision.physical_acceptance_authority": False,
        "decision.release_authority": False,
    }, "CLAIMS")

    report_raw = REPORT.read_bytes()
    live = {
        "next_gate_id": "QSDK-R24D83",
        "r24d82_diagnosis_closed": True,
        "r24d82_diagnosis_path": REPORT.relative_to(ROOT).as_posix(),
        "r24d82_diagnosis_byte_length": len(report_raw),
        "r24d82_diagnosis_raw_sha256": sha256(report_raw),
        "r24d82_model_construction_count": 0,
        "r24d82_world_attempt_count": 0,
        "r24d82_world_build_count": 0,
        "r24d82_solver_step_count": 0,
        "r24d82_limit_projection_defect_proven": True,
        "r24d82_collision_filter_parity_defect_proven": True,
        "r24d83_distinct_successor_required": True,
        "r24d83_question_class": "development",
        "r24d83_physical_question_declared": False,
        "physical_execution_blocked_until_r24d83_zero_world_qualification": True,
        "held_out_cells_remain_sealed": True,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    verify_legacy_live_authority_projection(
        ROOT, report["live_authority_paths"], record_key="r24d82_diagnosis_path",
        expected=live, prefix="LIVE"
    )


if __name__ == "__main__":
    try:
        audit()
    except (ClosureAuditError, KeyError, OSError, subprocess.CalledProcessError) as error:
        raise SystemExit(f"R82 diagnosis audit failed: {error}") from error
    print("R82 diagnosis audit passed")
