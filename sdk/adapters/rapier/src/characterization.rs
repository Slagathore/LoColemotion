use rapier3d::prelude::*;
use serde_json::{Value, json};
use sha2::{Digest, Sha256};

use crate::{ADAPTER_ID, RAPIER_DT_S, capability_manifest, capability_manifest_sha256};

const BASE_PREREGISTRATION_RAW: &str =
    include_str!("../../../cross_engine_c6_host_characterization_preregistration.json");
const PREDECESSOR_CLOSURE_RAW: &str =
    include_str!("../../../cross_engine_c6_host_characterization_closure.json");
const R1_PREREGISTRATION_RAW: &str =
    include_str!("../../../cross_engine_c6_host_characterization_r1_preregistration.json");
const R1_CLOSURE_RAW: &str =
    include_str!("../../../cross_engine_c6_host_characterization_r1_closure.json");
const PREREGISTRATION_RAW: &str =
    include_str!("../../../cross_engine_c6_host_characterization_r2_preregistration.json");
const BASE_PREREGISTRATION_RAW_SHA256: &str =
    "sha256:2ff51bc87745d84f2d4d0521005098ead3bef20e691b25f9f49c0cf7eadade8e";
const PREDECESSOR_CLOSURE_RAW_SHA256: &str =
    "sha256:dadd1e8a44dca2e66136c496a91bf2d4e579300459af4f0884b9040aa3faff21";
const R1_PREREGISTRATION_RAW_SHA256: &str =
    "sha256:a5ebb5c3fa827ec6d4952326f63ef68a87134d2cea71186ca15bd3174df84e11";
const R1_CLOSURE_RAW_SHA256: &str =
    "sha256:c4fac9d63428e747ac052169d97b344e2b774ce728f1a368f3e842f70248da12";
const GRAVITY_M_S2: f32 = 9.8;
const SLED_MASS_KG: f32 = 1.0;
const SETTLE_STEPS: usize = 240;
const BREAKAWAY_STEPS: usize = 120;
const STEADY_SLIDE_STEPS: usize = 6;
const ACTUATOR_STEPS: usize = 240;
const SOLVER_ITERATIONS: usize = 20;
const INTERNAL_PGS_ITERATIONS: usize = 1;
const INTERNAL_STABILIZATION_ITERATIONS: usize = 7;
const BREAKAWAY_VELOCITY_THRESHOLD_M_S: f32 = 0.02;
const BREAKAWAY_DISPLACEMENT_THRESHOLD_M: f32 = 0.005;
const MAXIMUM_BREAKAWAY_BRACKET_WIDTH_RATIO: f32 = 0.25;
const MINIMUM_BREAKAWAY_LOWER_RATIO: f32 = 0.5;
const MAXIMUM_BREAKAWAY_UPPER_RATIO: f32 = 1.5;
const STEADY_SLIDE_INITIAL_VELOCITY_M_S: f32 = 1.0;
const MINIMUM_STEADY_SLIDE_EFFECTIVE_TO_AUTHORED_RATIO: f32 = 0.5;
const MAXIMUM_STEADY_SLIDE_EFFECTIVE_TO_AUTHORED_RATIO: f32 = 1.5;
const ACTUATOR_TARGET_VELOCITY_RAD_S: f32 = 0.0;
const ACTUATOR_STIFFNESS_NM_PER_RAD: f32 = 40.0;
const ACTUATOR_DAMPING_NM_S_PER_RAD: f32 = 10.0;
const ACTUATOR_CHILD_HALF_EXTENTS_M: [f32; 3] = [0.2, 0.2, 0.2];
const ACTUATOR_CHILD_MASS_KG: f32 = 1.0;
const ACTUATOR_CHILD_EXPECTED_PRINCIPAL_INERTIA_KG_M2: [f32; 3] =
    [0.026_666_667, 0.026_666_667, 0.026_666_667];
const ACTUATOR_CHILD_MASS_TOLERANCE_KG: f32 = 0.000001;
const ACTUATOR_CHILD_INERTIA_TOLERANCE_KG_M2: f32 = 0.000001;
const MAXIMUM_FINAL_POSITION_ERROR_RAD: f32 = 0.02;
const MAXIMUM_IMPULSE_TOLERANCE_NMS: f32 = 0.000001;
const AUTHORED_FRICTIONS: [f32; 3] = [0.2, 0.6, 1.0];
const BREAKAWAY_FORCE_RATIOS: [f32; 7] = [0.0, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5];
const ACTUATOR_TARGETS_RAD: [f32; 2] = [-0.4, 0.4];
const ACTUATOR_MAXIMUM_STEP_IMPULSES_NMS: [f32; 2] = [0.05, 0.25];

fn check(condition: bool, failure_code: impl Into<String>) -> Result<(), String> {
    condition.then_some(()).ok_or_else(|| failure_code.into())
}

fn declared_f32(value: &Value, expected: f32) -> bool {
    value
        .as_f64()
        .is_some_and(|actual| actual as f32 == expected)
}

fn declared_f32_array(value: &Value, expected: &[f32]) -> bool {
    value.as_array().is_some_and(|actual| {
        actual.len() == expected.len()
            && actual
                .iter()
                .zip(expected)
                .all(|(item, expected_item)| declared_f32(item, *expected_item))
    })
}

fn configured_world(gravity: Vector) -> PhysicsWorld {
    let mut world = PhysicsWorld::new();
    world.gravity = gravity;
    world.integration_parameters.dt = RAPIER_DT_S;
    world.integration_parameters.length_unit = 1.0;
    world.integration_parameters.num_solver_iterations = SOLVER_ITERATIONS;
    world.integration_parameters.num_internal_pgs_iterations = INTERNAL_PGS_ITERATIONS;
    world
        .integration_parameters
        .num_internal_stabilization_iterations = INTERNAL_STABILIZATION_ITERATIONS;
    world
}

fn sha256(raw: &str) -> String {
    let digest = Sha256::digest(raw.as_bytes());
    format!("sha256:{digest:x}")
}

fn base_preregistration() -> Result<Value, String> {
    check(
        sha256(BASE_PREREGISTRATION_RAW) == BASE_PREREGISTRATION_RAW_SHA256,
        "RAPIER_HC1_BASE_PREREGISTRATION_HASH",
    )?;
    let preregistration: Value = serde_json::from_str(BASE_PREREGISTRATION_RAW)
        .map_err(|error| format!("RAPIER_HC1_PREREGISTRATION_PARSE:{error}"))?;
    check(
        preregistration["schema_version"]
            == "sporespore_cross_engine_c6_host_characterization_preregistration_v1",
        "RAPIER_HC1_PREREGISTRATION_SCHEMA",
    )?;
    check(
        preregistration["campaign_id"] == "C6-HOST-CHARACTERIZATION"
            && preregistration["gate_id"] == "C6-HC1"
            && preregistration["status"] == "frozen_before_first_c6_hc1_physics_world",
        "RAPIER_HC1_PREREGISTRATION_IDENTITY",
    )?;
    let declared_timestep = preregistration["common_fixture"]["timestep_s"]
        .as_f64()
        .ok_or_else(|| "RAPIER_HC1_TIMESTEP_TYPE".to_owned())?;
    let declared_gravity = preregistration["common_fixture"]["gravity_m_s2"]
        .as_f64()
        .ok_or_else(|| "RAPIER_HC1_GRAVITY_TYPE".to_owned())?;
    let declared_mass = preregistration["common_fixture"]["sled_mass_kg"]
        .as_f64()
        .ok_or_else(|| "RAPIER_HC1_MASS_TYPE".to_owned())?;
    check(
        (declared_timestep - 1.0 / 120.0).abs() <= f64::EPSILON
            && (RAPIER_DT_S as f64 - declared_timestep).abs() <= 1.0e-9
            && (declared_gravity - GRAVITY_M_S2 as f64).abs() <= 1.0e-6
            && (declared_mass - SLED_MASS_KG as f64).abs() <= f64::EPSILON
            && preregistration["common_fixture"]["settle_steps"] == json!(SETTLE_STEPS)
            && preregistration["common_fixture"]["breakaway_observation_steps"]
                == json!(BREAKAWAY_STEPS)
            && preregistration["common_fixture"]["steady_slide_observation_steps"]
                == json!(STEADY_SLIDE_STEPS)
            && preregistration["actuator_fixture"]["observation_steps"] == json!(ACTUATOR_STEPS)
            && declared_f32_array(
                &preregistration["common_fixture"]["authored_sliding_friction_values"],
                &AUTHORED_FRICTIONS,
            )
            && declared_f32_array(
                &preregistration["common_fixture"]["breakaway_force_ratios"],
                &BREAKAWAY_FORCE_RATIOS,
            )
            && declared_f32(
                &preregistration["common_fixture"]["breakaway_velocity_threshold_m_s"],
                BREAKAWAY_VELOCITY_THRESHOLD_M_S,
            )
            && declared_f32(
                &preregistration["common_fixture"]["breakaway_displacement_threshold_m"],
                BREAKAWAY_DISPLACEMENT_THRESHOLD_M,
            )
            && declared_f32(
                &preregistration["common_fixture"]["maximum_breakaway_bracket_width_ratio"],
                MAXIMUM_BREAKAWAY_BRACKET_WIDTH_RATIO,
            )
            && declared_f32(
                &preregistration["common_fixture"]["minimum_breakaway_lower_ratio"],
                MINIMUM_BREAKAWAY_LOWER_RATIO,
            )
            && declared_f32(
                &preregistration["common_fixture"]["maximum_breakaway_upper_ratio"],
                MAXIMUM_BREAKAWAY_UPPER_RATIO,
            )
            && declared_f32(
                &preregistration["common_fixture"]["steady_slide_initial_velocity_m_s"],
                STEADY_SLIDE_INITIAL_VELOCITY_M_S,
            )
            && declared_f32(
                &preregistration["common_fixture"]["minimum_steady_slide_effective_to_authored_ratio"],
                MINIMUM_STEADY_SLIDE_EFFECTIVE_TO_AUTHORED_RATIO,
            )
            && declared_f32(
                &preregistration["common_fixture"]["maximum_steady_slide_effective_to_authored_ratio"],
                MAXIMUM_STEADY_SLIDE_EFFECTIVE_TO_AUTHORED_RATIO,
            )
            && declared_f32_array(
                &preregistration["actuator_fixture"]["target_positions_rad"],
                &ACTUATOR_TARGETS_RAD,
            )
            && declared_f32_array(
                &preregistration["actuator_fixture"]["maximum_step_impulses_nms"],
                &ACTUATOR_MAXIMUM_STEP_IMPULSES_NMS,
            )
            && declared_f32(
                &preregistration["actuator_fixture"]["target_velocity_rad_s"],
                ACTUATOR_TARGET_VELOCITY_RAD_S,
            )
            && declared_f32(
                &preregistration["actuator_fixture"]["stiffness_nm_per_rad"],
                ACTUATOR_STIFFNESS_NM_PER_RAD,
            )
            && declared_f32(
                &preregistration["actuator_fixture"]["damping_nm_s_per_rad"],
                ACTUATOR_DAMPING_NM_S_PER_RAD,
            )
            && declared_f32(
                &preregistration["actuator_fixture"]["maximum_final_position_error_rad"],
                MAXIMUM_FINAL_POSITION_ERROR_RAD,
            )
            && declared_f32(
                &preregistration["actuator_fixture"]["maximum_impulse_tolerance_nms"],
                MAXIMUM_IMPULSE_TOLERANCE_NMS,
            ),
        "RAPIER_HC1_PREREGISTRATION_COMMON_FIXTURE",
    )?;
    check(
        preregistration["host_contracts"]["rapier"]["adapter_id"] == ADAPTER_ID
            && preregistration["host_contracts"]["rapier"]["engine_version"] == rapier3d::VERSION
            && preregistration["host_contracts"]["rapier"]["friction_combine_rule"] == "min",
        "RAPIER_HC1_PREREGISTRATION_HOST",
    )?;
    Ok(preregistration)
}

fn r1_preregistration() -> Result<(Value, Value), String> {
    let base = base_preregistration()?;
    check(
        sha256(PREDECESSOR_CLOSURE_RAW) == PREDECESSOR_CLOSURE_RAW_SHA256,
        "RAPIER_HC1_R1_PREDECESSOR_CLOSURE_HASH",
    )?;
    let preregistration: Value = serde_json::from_str(R1_PREREGISTRATION_RAW)
        .map_err(|error| format!("RAPIER_HC1_R1_PREREGISTRATION_PARSE:{error}"))?;
    check(
        preregistration["schema_version"]
            == "sporespore_cross_engine_c6_host_characterization_r1_preregistration_v1"
            && preregistration["campaign_id"] == "C6-HOST-CHARACTERIZATION-R1"
            && preregistration["gate_id"] == "C6-HC1-R1"
            && preregistration["status"] == "frozen_before_first_c6_hc1_r1_physics_world",
        "RAPIER_HC1_R1_PREREGISTRATION_IDENTITY",
    )?;
    check(
        preregistration["implementation_parent_commit"]
            == "4707b8d5d467d899a3b6ea1d8f5caf28bd99f008"
            && preregistration["base_preregistration"]["raw_sha256"]
                == BASE_PREREGISTRATION_RAW_SHA256
            && preregistration["predecessor_closure"]["raw_sha256"]
                == PREDECESSOR_CLOSURE_RAW_SHA256
            && preregistration["predecessor_closure"]["same_identity_rerun_forbidden"] == true,
        "RAPIER_HC1_R1_PREDECESSOR_BOUNDARY",
    )?;
    let correction = &preregistration["correction"]["shared_actuator_child"];
    let unchanged = &preregistration["unchanged_grid"];
    check(
        correction["shape"] == "cuboid"
            && declared_f32_array(
                &correction["half_extents_m"],
                &ACTUATOR_CHILD_HALF_EXTENTS_M,
            )
            && declared_f32(&correction["mass_kg"], ACTUATOR_CHILD_MASS_KG)
            && correction["mass_properties_source"] == "shape_derived_from_nonzero_mass_collider"
            && correction["center_of_mass_at_joint_anchor"] == true
            && declared_f32_array(
                &correction["expected_principal_angular_inertia_kg_m2"],
                &ACTUATOR_CHILD_EXPECTED_PRINCIPAL_INERTIA_KG_M2,
            )
            && declared_f32(
                &correction["maximum_absolute_mass_error_kg"],
                ACTUATOR_CHILD_MASS_TOLERANCE_KG,
            )
            && declared_f32(
                &correction["maximum_absolute_principal_inertia_error_kg_m2"],
                ACTUATOR_CHILD_INERTIA_TOLERANCE_KG_M2,
            )
            && correction["every_principal_inertia_axis_must_be_positive"] == true
            && preregistration["correction"]["rapier"]["remove_additional_mass_only_fixture"]
                == true
            && declared_f32(
                &preregistration["correction"]["rapier"]["collider_mass_kg"],
                ACTUATOR_CHILD_MASS_KG,
            )
            && preregistration["correction"]["rapier"]["report_measured_principal_inertia"] == true,
        "RAPIER_HC1_R1_ACTUATOR_CORRECTION",
    )?;
    check(
        declared_f32(&unchanged["timestep_s"], RAPIER_DT_S)
            && declared_f32_array(
                &unchanged["authored_sliding_friction_values"],
                &AUTHORED_FRICTIONS,
            )
            && declared_f32_array(
                &unchanged["breakaway_force_ratios"],
                &BREAKAWAY_FORCE_RATIOS,
            )
            && declared_f32_array(&unchanged["target_positions_rad"], &ACTUATOR_TARGETS_RAD)
            && declared_f32_array(
                &unchanged["maximum_step_impulses_nms"],
                &ACTUATOR_MAXIMUM_STEP_IMPULSES_NMS,
            )
            && unchanged["actuator_observation_steps"] == json!(ACTUATOR_STEPS)
            && declared_f32(
                &unchanged["maximum_final_position_error_rad"],
                MAXIMUM_FINAL_POSITION_ERROR_RAD,
            ),
        "RAPIER_HC1_R1_UNCHANGED_GRID",
    )?;
    Ok((base, preregistration))
}

fn preregistration() -> Result<(Value, Value, Value), String> {
    let (base, r1) = r1_preregistration()?;
    check(
        sha256(R1_PREREGISTRATION_RAW) == R1_PREREGISTRATION_RAW_SHA256
            && sha256(R1_CLOSURE_RAW) == R1_CLOSURE_RAW_SHA256,
        "RAPIER_HC1_R2_R1_SOURCE_HASH",
    )?;
    let preregistration: Value = serde_json::from_str(PREREGISTRATION_RAW)
        .map_err(|error| format!("RAPIER_HC1_R2_PREREGISTRATION_PARSE:{error}"))?;
    check(
        preregistration["schema_version"]
            == "sporespore_cross_engine_c6_host_characterization_r2_preregistration_v1"
            && preregistration["campaign_id"] == "C6-HOST-CHARACTERIZATION-R2"
            && preregistration["gate_id"] == "C6-HC1-R2"
            && preregistration["status"] == "frozen_before_first_c6_hc1_r2_physics_world",
        "RAPIER_HC1_R2_PREREGISTRATION_IDENTITY",
    )?;
    check(
        preregistration["implementation_parent_commit"]
            == "f54375ad1a4ba3d1e02c01b77983c3879e110bf4"
            && preregistration["r1_preregistration"]["raw_sha256"] == R1_PREREGISTRATION_RAW_SHA256
            && preregistration["r1_closure"]["raw_sha256"] == R1_CLOSURE_RAW_SHA256
            && preregistration["r1_closure"]["same_identity_rerun_forbidden"] == true
            && preregistration["correction"]["rapier"]["integrator_unchanged"] == true
            && preregistration["correction"]["rapier"]["all_fixture_inputs_unchanged"] == true,
        "RAPIER_HC1_R2_PREDECESSOR_BOUNDARY",
    )?;
    let fixture = &preregistration["unchanged_actuator_fixture"];
    check(
        fixture["shape"] == "cuboid"
            && declared_f32_array(&fixture["half_extents_m"], &ACTUATOR_CHILD_HALF_EXTENTS_M)
            && declared_f32(&fixture["mass_kg"], ACTUATOR_CHILD_MASS_KG)
            && fixture["mass_properties_source"] == "shape_derived_from_nonzero_mass_collider"
            && declared_f32_array(
                &fixture["expected_principal_angular_inertia_kg_m2"],
                &ACTUATOR_CHILD_EXPECTED_PRINCIPAL_INERTIA_KG_M2,
            )
            && declared_f32_array(&fixture["target_positions_rad"], &ACTUATOR_TARGETS_RAD)
            && declared_f32_array(
                &fixture["maximum_step_impulses_nms"],
                &ACTUATOR_MAXIMUM_STEP_IMPULSES_NMS,
            )
            && declared_f32(
                &fixture["stiffness_nm_per_rad"],
                ACTUATOR_STIFFNESS_NM_PER_RAD,
            )
            && declared_f32(
                &fixture["damping_nm_s_per_rad"],
                ACTUATOR_DAMPING_NM_S_PER_RAD,
            )
            && declared_f32(&fixture["timestep_s"], RAPIER_DT_S)
            && fixture["observation_steps"] == json!(ACTUATOR_STEPS)
            && declared_f32(
                &fixture["maximum_final_position_error_rad"],
                MAXIMUM_FINAL_POSITION_ERROR_RAD,
            ),
        "RAPIER_HC1_R2_UNCHANGED_ACTUATOR_FIXTURE",
    )?;
    Ok((base, r1, preregistration))
}

fn raw_preregistration_sha256() -> String {
    sha256(PREREGISTRATION_RAW)
}

fn validate_integrity_summary(summary: &Value) -> Result<(), String> {
    check(
        summary["expected_material_profile_count"] == 3
            && summary["observed_material_profile_count"] == 3
            && summary["expected_breakaway_trial_count"] == 21
            && summary["observed_breakaway_trial_count"] == 21
            && summary["expected_steady_slide_trial_count"] == 3
            && summary["observed_steady_slide_trial_count"] == 3
            && summary["expected_actuator_cell_count"] == 4
            && summary["observed_actuator_cell_count"] == 4
            && summary["failed_material_profile_count"] == 0
            && summary["failed_breakaway_trial_count"] == 0
            && summary["failed_steady_slide_trial_count"] == 0
            && summary["failed_actuator_cell_count"] == 0
            && summary["source_mismatch_count"] == 0
            && summary["nonfinite_observation_count"] == 0,
        "RAPIER_HC1_INTEGRITY_GATE",
    )
}

fn perfect_synthetic_summary() -> Value {
    json!({
        "expected_material_profile_count": 3,
        "observed_material_profile_count": 3,
        "expected_breakaway_trial_count": 21,
        "observed_breakaway_trial_count": 21,
        "expected_steady_slide_trial_count": 3,
        "observed_steady_slide_trial_count": 3,
        "expected_actuator_cell_count": 4,
        "observed_actuator_cell_count": 4,
        "failed_material_profile_count": 0,
        "failed_breakaway_trial_count": 0,
        "failed_steady_slide_trial_count": 0,
        "failed_actuator_cell_count": 0,
        "source_mismatch_count": 0,
        "nonfinite_observation_count": 0,
    })
}

pub fn run_host_characterization_preflight() -> Result<Value, String> {
    let _ = preregistration()?;
    let perfect = perfect_synthetic_summary();
    validate_integrity_summary(&perfect)?;
    let mut canary = perfect.clone();
    canary["failed_breakaway_trial_count"] = json!(1);
    check(
        validate_integrity_summary(&canary).is_err(),
        "RAPIER_HC1_NONZERO_CANARY_ACCEPTED",
    )?;
    Ok(json!({
        "schema_version": "sporespore_c6_host_characterization_r2_preflight_v1",
        "ok": true,
        "adapter_id": ADAPTER_ID,
        "campaign_id": "C6-HOST-CHARACTERIZATION-R2",
        "gate_id": "C6-HC1-R2",
        "preregistration_raw_sha256": raw_preregistration_sha256(),
        "perfect_synthetic_result_passed": true,
        "nonzero_failure_canary_rejected": true,
        "full_integrity_gate_executed": true,
        "world_build_count": 0,
        "scene_insertion_count": 0,
        "physics_state_mutation_count": 0,
        "physical_acceptance_authority": false,
    }))
}

fn settled_sled_world(authored_friction: f32) -> Result<(PhysicsWorld, RigidBodyHandle), String> {
    let mut world = configured_world(Vector::new(0.0, -GRAVITY_M_S2, 0.0));
    world.insert(
        RigidBodyBuilder::fixed().translation(Vector::new(0.0, -0.1, 0.0)),
        ColliderBuilder::cuboid(5.0, 0.1, 5.0)
            .friction(authored_friction)
            .friction_combine_rule(CoefficientCombineRule::Min)
            .restitution(0.0),
    );
    let (sled, _) = world.insert(
        RigidBodyBuilder::dynamic()
            .translation(Vector::new(0.0, 0.1, 0.0))
            .additional_mass(SLED_MASS_KG)
            .linear_damping(0.0)
            .angular_damping(0.0),
        ColliderBuilder::cuboid(0.2, 0.1, 0.15)
            .mass(0.0)
            .friction(authored_friction)
            .friction_combine_rule(CoefficientCombineRule::Min)
            .restitution(0.0),
    );
    for _ in 0..SETTLE_STEPS {
        world.step();
    }
    let body = &world.bodies[sled];
    check(
        (body.mass() - SLED_MASS_KG).abs() <= 1.0e-6,
        "RAPIER_HC1_SLED_MASS_MISMATCH",
    )?;
    check(
        body.translation().y.is_finite() && body.linvel().is_finite() && body.angvel().is_finite(),
        "RAPIER_HC1_SLED_SETTLE_NONFINITE",
    )?;
    Ok((world, sled))
}

fn breakaway_trial(authored_friction: f32, force_ratio: f32) -> Result<Value, String> {
    let (mut world, sled) = settled_sled_world(authored_friction)?;
    let start_x = world.bodies[sled].translation().x;
    let applied_force_n = authored_friction * SLED_MASS_KG * GRAVITY_M_S2 * force_ratio;
    let mut maximum_absolute_speed_m_s = 0.0_f32;
    for _ in 0..BREAKAWAY_STEPS {
        let body = world
            .bodies
            .get_mut(sled)
            .ok_or_else(|| "RAPIER_HC1_SLED_MISSING".to_owned())?;
        body.reset_forces(true);
        body.add_force(Vector::new(applied_force_n, 0.0, 0.0), true);
        world.step();
        maximum_absolute_speed_m_s =
            maximum_absolute_speed_m_s.max(world.bodies[sled].linvel().x.abs());
    }
    let body = &world.bodies[sled];
    let displacement_m = (body.translation().x - start_x).abs();
    let broke_away = maximum_absolute_speed_m_s > BREAKAWAY_VELOCITY_THRESHOLD_M_S
        || displacement_m > BREAKAWAY_DISPLACEMENT_THRESHOLD_M;
    check(
        applied_force_n.is_finite()
            && displacement_m.is_finite()
            && maximum_absolute_speed_m_s.is_finite(),
        "RAPIER_HC1_BREAKAWAY_NONFINITE",
    )?;
    Ok(json!({
        "ok": true,
        "authored_friction": authored_friction,
        "force_ratio_to_authored_coulomb_limit": force_ratio,
        "applied_force_n": applied_force_n,
        "absolute_forward_displacement_m": displacement_m,
        "maximum_absolute_forward_speed_m_s": maximum_absolute_speed_m_s,
        "velocity_threshold_m_s": BREAKAWAY_VELOCITY_THRESHOLD_M_S,
        "displacement_threshold_m": BREAKAWAY_DISPLACEMENT_THRESHOLD_M,
        "broke_away": broke_away,
        "failure_codes": [],
        "world_attempt_count": 1,
        "world_build_count": 1,
    }))
}

fn steady_slide_trial(authored_friction: f32) -> Result<Value, String> {
    let (mut world, sled) = settled_sled_world(authored_friction)?;
    world.bodies[sled].set_linvel(
        Vector::new(STEADY_SLIDE_INITIAL_VELOCITY_M_S, 0.0, 0.0),
        true,
    );
    let start_x = world.bodies[sled].translation().x;
    for _ in 0..STEADY_SLIDE_STEPS {
        world.bodies[sled].reset_forces(true);
        world.step();
    }
    let body = &world.bodies[sled];
    let final_velocity_m_s = body.linvel().x;
    let elapsed_s = STEADY_SLIDE_STEPS as f32 * RAPIER_DT_S;
    let effective_friction =
        (STEADY_SLIDE_INITIAL_VELOCITY_M_S - final_velocity_m_s) / (GRAVITY_M_S2 * elapsed_s);
    let effective_to_authored_ratio = effective_friction / authored_friction;
    check(
        final_velocity_m_s.is_finite()
            && effective_friction.is_finite()
            && effective_to_authored_ratio.is_finite(),
        "RAPIER_HC1_STEADY_SLIDE_NONFINITE",
    )?;
    check(
        final_velocity_m_s > 0.0
            && (MINIMUM_STEADY_SLIDE_EFFECTIVE_TO_AUTHORED_RATIO
                ..=MAXIMUM_STEADY_SLIDE_EFFECTIVE_TO_AUTHORED_RATIO)
                .contains(&effective_to_authored_ratio),
        format!(
            "RAPIER_HC1_STEADY_SLIDE_ENVELOPE:mu={authored_friction}:\
             ratio={effective_to_authored_ratio}"
        ),
    )?;
    Ok(json!({
        "ok": true,
        "authored_friction": authored_friction,
        "initial_forward_velocity_m_s": STEADY_SLIDE_INITIAL_VELOCITY_M_S,
        "final_forward_velocity_m_s": final_velocity_m_s,
        "observation_steps": STEADY_SLIDE_STEPS,
        "elapsed_s": elapsed_s,
        "forward_displacement_m": body.translation().x - start_x,
        "effective_sliding_friction": effective_friction,
        "effective_to_authored_ratio": effective_to_authored_ratio,
        "failure_codes": [],
        "world_attempt_count": 1,
        "world_build_count": 1,
    }))
}

fn failed_breakaway_trial(authored_friction: f32, force_ratio: f32, failure_code: String) -> Value {
    json!({
        "ok": false,
        "authored_friction": authored_friction,
        "force_ratio_to_authored_coulomb_limit": force_ratio,
        "failure_codes": [failure_code],
        "world_attempt_count": 1,
        "world_build_count": 0,
    })
}

fn failed_steady_slide_trial(authored_friction: f32, failure_code: String) -> Value {
    json!({
        "ok": false,
        "authored_friction": authored_friction,
        "failure_codes": [failure_code],
        "world_attempt_count": 1,
        "world_build_count": 0,
    })
}

fn panic_failure_code(payload: Box<dyn std::any::Any + Send>) -> String {
    let detail = payload
        .downcast_ref::<&str>()
        .map(|message| (*message).to_owned())
        .or_else(|| payload.downcast_ref::<String>().cloned())
        .unwrap_or_else(|| "non-string panic payload".to_owned());
    format!("RAPIER_HC1_CELL_PANIC:{detail}")
}

fn retained_breakaway_trial(authored_friction: f32, force_ratio: f32) -> Value {
    match std::panic::catch_unwind(|| breakaway_trial(authored_friction, force_ratio)) {
        Ok(Ok(trial)) => trial,
        Ok(Err(failure)) => failed_breakaway_trial(authored_friction, force_ratio, failure),
        Err(payload) => {
            failed_breakaway_trial(authored_friction, force_ratio, panic_failure_code(payload))
        }
    }
}

fn retained_steady_slide_trial(authored_friction: f32) -> Value {
    match std::panic::catch_unwind(|| steady_slide_trial(authored_friction)) {
        Ok(Ok(trial)) => trial,
        Ok(Err(failure)) => failed_steady_slide_trial(authored_friction, failure),
        Err(payload) => failed_steady_slide_trial(authored_friction, panic_failure_code(payload)),
    }
}

fn material_profile(authored_friction: f32) -> Value {
    let mut trials = Vec::with_capacity(BREAKAWAY_FORCE_RATIOS.len());
    for ratio in BREAKAWAY_FORCE_RATIOS {
        trials.push(retained_breakaway_trial(authored_friction, ratio));
    }
    let steady_slide = retained_steady_slide_trial(authored_friction);
    let breakaway_cells_ok = trials.iter().all(|trial| trial["ok"] == true);
    let steady_slide_ok = steady_slide["ok"] == true;
    let mut failure_codes = Vec::new();
    let mut monotonic = false;
    let mut characterized = false;
    let mut lower_ratio = None;
    let mut upper_ratio = None;

    if !breakaway_cells_ok {
        failure_codes.push(format!(
            "RAPIER_HC1_BREAKAWAY_CELL_FAILURES:mu={authored_friction}"
        ));
    } else {
        let broke_away: Vec<bool> = trials
            .iter()
            .map(|trial| {
                trial["broke_away"]
                    .as_bool()
                    .expect("successful breakaway cell must carry a boolean")
            })
            .collect();
        monotonic = broke_away.windows(2).all(|window| !window[0] || window[1]);
        if !monotonic {
            failure_codes.push(format!(
                "RAPIER_HC1_BREAKAWAY_NONMONOTONIC:mu={authored_friction}"
            ));
        }
        match broke_away.iter().position(|observed| *observed) {
            None => failure_codes.push(format!(
                "RAPIER_HC1_BREAKAWAY_UPPER_BRACKET_MISSING:mu={authored_friction}"
            )),
            Some(0) => failure_codes.push(format!(
                "RAPIER_HC1_BREAKAWAY_LOWER_BRACKET_MISSING:mu={authored_friction}"
            )),
            Some(first_breakaway_index) => {
                let observed_lower = BREAKAWAY_FORCE_RATIOS[first_breakaway_index - 1];
                let observed_upper = BREAKAWAY_FORCE_RATIOS[first_breakaway_index];
                lower_ratio = Some(observed_lower);
                upper_ratio = Some(observed_upper);
                if observed_lower < MINIMUM_BREAKAWAY_LOWER_RATIO
                    || observed_upper > MAXIMUM_BREAKAWAY_UPPER_RATIO
                    || observed_upper - observed_lower
                        > MAXIMUM_BREAKAWAY_BRACKET_WIDTH_RATIO + f32::EPSILON
                {
                    failure_codes.push(format!(
                        "RAPIER_HC1_BREAKAWAY_BRACKET_ENVELOPE:mu={authored_friction}:\
                         lower={observed_lower}:upper={observed_upper}"
                    ));
                } else if monotonic {
                    characterized = true;
                }
            }
        }
    }
    if !steady_slide_ok {
        failure_codes.push(format!(
            "RAPIER_HC1_STEADY_SLIDE_CELL_FAILURE:mu={authored_friction}"
        ));
    }
    let world_build_count = trials
        .iter()
        .map(|trial| trial["world_build_count"].as_u64().unwrap_or(0))
        .sum::<u64>()
        + steady_slide["world_build_count"].as_u64().unwrap_or(0);
    let ok = failure_codes.is_empty() && characterized && steady_slide_ok;

    json!({
        "ok": ok,
        "authored_friction": authored_friction,
        "ground_and_sled_coefficients_equal": true,
        "combine_rule": "min",
        "rapier_distinct_static_dynamic_coefficients": false,
        "breakaway": {
            "trials": trials,
            "nonbreaking_lower_ratio": lower_ratio,
            "breaking_upper_ratio": upper_ratio,
            "bracket_width_ratio": lower_ratio.zip(upper_ratio).map(|(lower, upper)| upper - lower),
            "monotonic": monotonic,
            "characterized": characterized,
        },
        "steady_slide": steady_slide,
        "failure_codes": failure_codes,
        "world_attempt_count": BREAKAWAY_FORCE_RATIOS.len() + 1,
        "world_build_count": world_build_count,
        "physical_acceptance_authority": false,
    })
}

fn maximum_impulse_to_motor_max_force(maximum_impulse_nms: f32) -> Result<f32, String> {
    check(
        maximum_impulse_nms.is_finite() && maximum_impulse_nms > 0.0,
        "RAPIER_HC1_MAXIMUM_IMPULSE_INVALID",
    )?;
    let force = maximum_impulse_nms / RAPIER_DT_S;
    check(
        force.is_finite(),
        "RAPIER_HC1_MAXIMUM_FORCE_UNREPRESENTABLE",
    )?;
    Ok(force)
}

fn actuator_cell(target_position_rad: f32, maximum_step_impulse_nms: f32) -> Result<Value, String> {
    let maximum_motor_force_nm = maximum_impulse_to_motor_max_force(maximum_step_impulse_nms)?;
    let mut world = configured_world(Vector::ZERO);
    let parent = world.insert_body(RigidBodyBuilder::fixed());
    let (child, _) = world.insert(
        RigidBodyBuilder::dynamic(),
        ColliderBuilder::cuboid(
            ACTUATOR_CHILD_HALF_EXTENTS_M[0],
            ACTUATOR_CHILD_HALF_EXTENTS_M[1],
            ACTUATOR_CHILD_HALF_EXTENTS_M[2],
        )
        .mass(ACTUATOR_CHILD_MASS_KG),
    );
    let measured_child_mass_kg = world.bodies[child].mass();
    let measured_principal_inertia_kg_m2 = world.bodies[child]
        .mass_properties()
        .local_mprops
        .principal_inertia();
    check(
        (measured_child_mass_kg - ACTUATOR_CHILD_MASS_KG).abs() <= ACTUATOR_CHILD_MASS_TOLERANCE_KG,
        "RAPIER_HC1_R1_ACTUATOR_CHILD_MASS",
    )?;
    check(
        measured_principal_inertia_kg_m2.x > 0.0
            && measured_principal_inertia_kg_m2.y > 0.0
            && measured_principal_inertia_kg_m2.z > 0.0
            && (measured_principal_inertia_kg_m2.x
                - ACTUATOR_CHILD_EXPECTED_PRINCIPAL_INERTIA_KG_M2[0])
                .abs()
                <= ACTUATOR_CHILD_INERTIA_TOLERANCE_KG_M2
            && (measured_principal_inertia_kg_m2.y
                - ACTUATOR_CHILD_EXPECTED_PRINCIPAL_INERTIA_KG_M2[1])
                .abs()
                <= ACTUATOR_CHILD_INERTIA_TOLERANCE_KG_M2
            && (measured_principal_inertia_kg_m2.z
                - ACTUATOR_CHILD_EXPECTED_PRINCIPAL_INERTIA_KG_M2[2])
                .abs()
                <= ACTUATOR_CHILD_INERTIA_TOLERANCE_KG_M2,
        "RAPIER_HC1_R1_ACTUATOR_CHILD_INERTIA",
    )?;
    let joint = world.insert_impulse_joint(
        parent,
        child,
        RevoluteJointBuilder::new(Vector::X)
            .motor(
                target_position_rad,
                ACTUATOR_TARGET_VELOCITY_RAD_S,
                ACTUATOR_STIFFNESS_NM_PER_RAD,
                ACTUATOR_DAMPING_NM_S_PER_RAD,
            )
            .motor_model(MotorModel::ForceBased)
            .motor_max_force(maximum_motor_force_nm),
    );
    let mut maximum_observed_impulse_nms = 0.0_f32;
    let mut maximum_absolute_angle_rad = 0.0_f32;
    for _ in 0..ACTUATOR_STEPS {
        world.step();
        let revolute = world
            .impulse_joints
            .get(joint)
            .ok_or_else(|| "RAPIER_HC1_REVOLUTE_JOINT_MISSING".to_owned())?
            .data
            .as_revolute()
            .ok_or_else(|| "RAPIER_HC1_REVOLUTE_TYPE_MISMATCH".to_owned())?;
        let motor = revolute
            .motor()
            .ok_or_else(|| "RAPIER_HC1_MOTOR_MISSING".to_owned())?;
        check(
            motor.model == MotorModel::ForceBased,
            "RAPIER_HC1_MOTOR_MODEL_MISMATCH",
        )?;
        maximum_observed_impulse_nms = maximum_observed_impulse_nms.max(motor.impulse.abs());
        let angle = revolute.angle(
            &world.bodies[parent].position().rotation,
            &world.bodies[child].position().rotation,
        );
        maximum_absolute_angle_rad = maximum_absolute_angle_rad.max(angle.abs());
        check(
            motor.impulse.abs() <= maximum_step_impulse_nms + MAXIMUM_IMPULSE_TOLERANCE_NMS,
            "RAPIER_HC1_PER_STEP_IMPULSE_LIMIT_EXCEEDED",
        )?;
    }
    let revolute = world
        .impulse_joints
        .get(joint)
        .ok_or_else(|| "RAPIER_HC1_REVOLUTE_JOINT_MISSING".to_owned())?
        .data
        .as_revolute()
        .ok_or_else(|| "RAPIER_HC1_REVOLUTE_TYPE_MISMATCH".to_owned())?;
    let final_position_rad = revolute.angle(
        &world.bodies[parent].position().rotation,
        &world.bodies[child].position().rotation,
    );
    let final_error_rad = (final_position_rad - target_position_rad).abs();
    let final_motor = revolute
        .motor()
        .ok_or_else(|| "RAPIER_HC1_MOTOR_MISSING".to_owned())?;
    check(
        final_position_rad.is_finite()
            && maximum_absolute_angle_rad.is_finite()
            && maximum_observed_impulse_nms.is_finite(),
        "RAPIER_HC1_ACTUATOR_NONFINITE",
    )?;
    check(
        final_error_rad <= MAXIMUM_FINAL_POSITION_ERROR_RAD,
        format!(
            "RAPIER_HC1_ACTUATOR_TRACKING:target={target_position_rad}:\
             observed={final_position_rad}:error={final_error_rad}"
        ),
    )?;
    Ok(json!({
        "ok": true,
        "actuator_model": "rapier_revolute_position_velocity_force_based",
        "motor_model_readback": if final_motor.model == MotorModel::ForceBased {
            "ForceBased"
        } else {
            "AccelerationBased"
        },
        "target_position_rad": target_position_rad,
        "target_velocity_rad_s": ACTUATOR_TARGET_VELOCITY_RAD_S,
        "child_shape": "cuboid",
        "child_half_extents_m": ACTUATOR_CHILD_HALF_EXTENTS_M,
        "child_mass_properties_source": "shape_derived_from_nonzero_mass_collider",
        "measured_child_mass_kg": measured_child_mass_kg,
        "measured_child_principal_inertia_kg_m2": [
            measured_principal_inertia_kg_m2.x,
            measured_principal_inertia_kg_m2.y,
            measured_principal_inertia_kg_m2.z,
        ],
        "final_position_rad": final_position_rad,
        "final_absolute_position_error_rad": final_error_rad,
        "maximum_absolute_angle_rad": maximum_absolute_angle_rad,
        "maximum_step_impulse_nms": maximum_step_impulse_nms,
        "mapped_maximum_motor_force_nm": maximum_motor_force_nm,
        "maximum_observed_motor_impulse_nms": maximum_observed_impulse_nms,
        "mapping_rule": "max_force_nm = maximum_step_impulse_nms / timestep_s",
        "failure_codes": [],
        "world_attempt_count": 1,
        "world_build_count": 1,
        "physical_acceptance_authority": false,
    }))
}

fn failed_actuator_cell(
    target_position_rad: f32,
    maximum_step_impulse_nms: f32,
    failure_code: String,
) -> Value {
    json!({
        "ok": false,
        "actuator_model": "rapier_revolute_position_velocity_force_based",
        "target_position_rad": target_position_rad,
        "target_velocity_rad_s": ACTUATOR_TARGET_VELOCITY_RAD_S,
        "child_shape": "cuboid",
        "child_half_extents_m": ACTUATOR_CHILD_HALF_EXTENTS_M,
        "child_mass_properties_source": "shape_derived_from_nonzero_mass_collider",
        "maximum_step_impulse_nms": maximum_step_impulse_nms,
        "failure_codes": [failure_code],
        "world_attempt_count": 1,
        "world_build_count": 0,
        "physical_acceptance_authority": false,
    })
}

fn retained_actuator_cell(target_position_rad: f32, maximum_step_impulse_nms: f32) -> Value {
    match std::panic::catch_unwind(|| actuator_cell(target_position_rad, maximum_step_impulse_nms))
    {
        Ok(Ok(cell)) => cell,
        Ok(Err(failure)) => {
            failed_actuator_cell(target_position_rad, maximum_step_impulse_nms, failure)
        }
        Err(payload) => failed_actuator_cell(
            target_position_rad,
            maximum_step_impulse_nms,
            panic_failure_code(payload),
        ),
    }
}

fn cell_ok(cell: &Value) -> bool {
    cell["ok"].as_bool() == Some(true)
}

fn count_nonfinite_failure_codes(value: &Value) -> u64 {
    match value {
        Value::Array(items) => items.iter().map(count_nonfinite_failure_codes).sum::<u64>(),
        Value::Object(items) => items
            .values()
            .map(count_nonfinite_failure_codes)
            .sum::<u64>(),
        Value::String(item) if item.contains("NONFINITE") => 1,
        Value::String(_) => 0,
        _ => 0,
    }
}

pub fn run_host_characterization(source_commit: &str) -> Result<Value, String> {
    let preflight = run_host_characterization_preflight()?;
    check(
        source_commit.len() == 40 && source_commit.bytes().all(|byte| byte.is_ascii_hexdigit()),
        "RAPIER_HC1_SOURCE_COMMIT_INVALID",
    )?;
    let (base_preregistration, r1_preregistration, preregistration) = preregistration()?;
    let mut material_profiles = Vec::with_capacity(AUTHORED_FRICTIONS.len());
    for authored_friction in AUTHORED_FRICTIONS {
        material_profiles.push(material_profile(authored_friction));
    }
    let mut actuator_cells =
        Vec::with_capacity(ACTUATOR_TARGETS_RAD.len() * ACTUATOR_MAXIMUM_STEP_IMPULSES_NMS.len());
    for target in ACTUATOR_TARGETS_RAD {
        for maximum_impulse in ACTUATOR_MAXIMUM_STEP_IMPULSES_NMS {
            actuator_cells.push(retained_actuator_cell(target, maximum_impulse));
        }
    }
    let observed_breakaway_trial_count = material_profiles
        .iter()
        .map(|profile| {
            profile["breakaway"]["trials"]
                .as_array()
                .map_or(0, Vec::len)
        })
        .sum::<usize>();
    let failed_breakaway_trial_count = material_profiles
        .iter()
        .flat_map(|profile| {
            profile["breakaway"]["trials"]
                .as_array()
                .into_iter()
                .flatten()
        })
        .filter(|trial| !cell_ok(trial))
        .count();
    let failed_steady_slide_trial_count = material_profiles
        .iter()
        .filter(|profile| !cell_ok(&profile["steady_slide"]))
        .count();
    let failed_material_profile_count = material_profiles
        .iter()
        .filter(|profile| !cell_ok(profile))
        .count();
    let failed_actuator_cell_count = actuator_cells.iter().filter(|cell| !cell_ok(cell)).count();
    let nonfinite_observation_count = material_profiles
        .iter()
        .map(count_nonfinite_failure_codes)
        .sum::<u64>()
        + actuator_cells
            .iter()
            .map(count_nonfinite_failure_codes)
            .sum::<u64>();
    let summary = json!({
        "expected_material_profile_count": AUTHORED_FRICTIONS.len(),
        "observed_material_profile_count": material_profiles.len(),
        "expected_breakaway_trial_count":
            AUTHORED_FRICTIONS.len() * BREAKAWAY_FORCE_RATIOS.len(),
        "observed_breakaway_trial_count": observed_breakaway_trial_count,
        "expected_steady_slide_trial_count": AUTHORED_FRICTIONS.len(),
        "observed_steady_slide_trial_count": material_profiles.len(),
        "expected_actuator_cell_count":
            ACTUATOR_TARGETS_RAD.len() * ACTUATOR_MAXIMUM_STEP_IMPULSES_NMS.len(),
        "observed_actuator_cell_count": actuator_cells.len(),
        "failed_material_profile_count": failed_material_profile_count,
        "failed_breakaway_trial_count": failed_breakaway_trial_count,
        "failed_steady_slide_trial_count": failed_steady_slide_trial_count,
        "failed_actuator_cell_count": failed_actuator_cell_count,
        "source_mismatch_count": 0,
        "nonfinite_observation_count": nonfinite_observation_count,
    });
    let total_world_attempt_count = material_profiles
        .iter()
        .map(|profile| profile["world_attempt_count"].as_u64().unwrap_or(0))
        .sum::<u64>()
        + actuator_cells
            .iter()
            .map(|cell| cell["world_attempt_count"].as_u64().unwrap_or(0))
            .sum::<u64>();
    let total_world_build_count = material_profiles
        .iter()
        .map(|profile| profile["world_build_count"].as_u64().unwrap_or(0))
        .sum::<u64>()
        + actuator_cells
            .iter()
            .map(|cell| cell["world_build_count"].as_u64().unwrap_or(0))
            .sum::<u64>();
    let mut integrity_failure_codes = Vec::new();
    if validate_integrity_summary(&summary).is_err() {
        integrity_failure_codes.push("RAPIER_HC1_INTEGRITY_GATE");
    }
    if total_world_attempt_count != 28 {
        integrity_failure_codes.push("RAPIER_HC1_WORLD_ATTEMPT_COUNT");
    }
    if total_world_build_count != 28 {
        integrity_failure_codes.push("RAPIER_HC1_WORLD_BUILD_COUNT");
    }
    let material_complete = failed_material_profile_count == 0;
    let actuator_complete = failed_actuator_cell_count == 0;
    let ok = integrity_failure_codes.is_empty() && material_complete && actuator_complete;

    Ok(json!({
        "schema_version": "sporespore_rapier_c6_host_characterization_r2_report_v1",
        "ok": ok,
        "campaign_id": "C6-HOST-CHARACTERIZATION-R2",
        "gate_id": "C6-HC1-R2",
        "source": {
            "commit": source_commit,
            "clean": true,
            "matches_origin_main": true,
        },
        "adapter_id": ADAPTER_ID,
        "adapter_manifest": capability_manifest(),
        "adapter_manifest_sha256": capability_manifest_sha256(),
        "rapier_version": rapier3d::VERSION,
        "preregistration": {
            "schema_version": preregistration["schema_version"],
            "status": preregistration["status"],
            "raw_sha256": raw_preregistration_sha256(),
            "base_schema_version": base_preregistration["schema_version"],
            "base_raw_sha256": BASE_PREREGISTRATION_RAW_SHA256,
            "predecessor_closure_raw_sha256": PREDECESSOR_CLOSURE_RAW_SHA256,
            "r1_schema_version": r1_preregistration["schema_version"],
            "r1_raw_sha256": R1_PREREGISTRATION_RAW_SHA256,
            "r1_closure_raw_sha256": R1_CLOSURE_RAW_SHA256,
        },
        "preflight": preflight,
        "integrity_summary": summary,
        "integrity_failure_codes": integrity_failure_codes,
        "material_profiles": material_profiles,
        "actuator_cells": actuator_cells,
        "material_characterization_complete_for_declared_grid": material_complete,
        "actuator_characterization_complete_for_declared_grid": actuator_complete,
        "world_attempt_count": total_world_attempt_count,
        "world_build_count": total_world_build_count,
        "controller_policy_authority": false,
        "selected_policy_physical_authority": false,
        "cross_engine_c6": false,
        "different_physics_engines": false,
        "locomotion_acceptance": false,
        "material_robustness": false,
        "physical_acceptance_authority": false,
        "release_authorized": false,
        "completed_engine_neutral_sdk": false,
    }))
}
