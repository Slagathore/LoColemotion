use rapier3d::prelude::*;
use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use sporespore_locomotion_core::protocol::{PhaseProgressionMode, Quaternion};
use sporespore_locomotion_core::{
    BALANCED_WAVE_BW15F_B_POLICY_ID, BalancedWaveController, BalancedWaveControllerMemory,
    CANONICAL_VELOCITY_RESIDUAL_V1_VERSION, CanonicalVelocityResidualV1,
    LEGACY_GODOT_HOST_TO_CANONICAL_VELOCITY_SIGN, RAPIER_CANONICAL_TO_HOST_VELOCITY_SIGN,
    RAPIER_FORCE_BASED_VELOCITY_ONLY_PROFILE_ID, VelocityOnlyHostProfileV1,
    compile_bounded_quadruped, map_canonical_velocity_to_host_v1,
};

use crate::active_configuration::RAPIER_ACTIVE_SOLVER_ITERATIONS;
use crate::bw19v_composition::{
    BW19V_GLOBAL_REQUESTED_CORRECTION_SCALE, map_bw19v_velocity_only_v4,
};
use crate::locomotion::{descriptor, motion_command, synthetic_state_frame};
use crate::{ADAPTER_ID, RAPIER_DT_S};

const VH1_CLOSURE_RAW: &str = include_str!(
    "../../../rapier_c6_force_based_velocity_only_host_characterization_vh1_closure.json"
);
const CANONICAL_PROFILE_RAW: &str =
    include_str!("../../../canonical_velocity_actuation_profile_v1.json");
const ACTIVE_CONFIGURATION_V1_RAW: &str =
    include_str!("../../../rapier_c6_force_based_active_configuration.json");

pub(crate) const VH1_CLOSURE_RAW_SHA256: &str =
    "sha256:d94b20ef4767479172408c1dfbd0b7f66e18e3f4bc8b9d8d84193fc157d284aa";
pub(crate) const CANONICAL_PROFILE_RAW_SHA256: &str =
    "sha256:1240ad4bba89bc8d1c22fa270fa718c57ab5ee227d777434b3870b859001e6a3";
pub(crate) const ACTIVE_CONFIGURATION_V1_RAW_SHA256: &str =
    "sha256:dc1eb57df75a41cb5ab80c45e537e7bd0974df0ac9cc7d738e24f08daaf60737";

pub(crate) const VELOCITY_ONLY_LIVE_PROFILE_ID: &str = RAPIER_FORCE_BASED_VELOCITY_ONLY_PROFILE_ID;
pub(crate) const VELOCITY_ONLY_MOTOR_DAMPING_NM_S_PER_RAD: f32 = 10.0;
pub(crate) const VELOCITY_ONLY_NATIVE_POSITION_STIFFNESS_NM_PER_RAD: f32 = 0.0;
const MOTOR_READBACK_TOLERANCE: f32 = 1.0e-6;

#[derive(Clone, Copy, Debug)]
pub(crate) struct VelocityOnlyMotorReadbackV1 {
    pub model: MotorModel,
    pub target_position_rad: f32,
    pub target_velocity_rad_s: f32,
    pub stiffness_nm_per_rad: f32,
    pub damping_nm_s_per_rad: f32,
    pub maximum_force_nm: f32,
}

impl VelocityOnlyMotorReadbackV1 {
    fn from_motor(motor: &JointMotor) -> Self {
        Self {
            model: motor.model,
            target_position_rad: motor.target_pos,
            target_velocity_rad_s: motor.target_vel,
            stiffness_nm_per_rad: motor.stiffness,
            damping_nm_s_per_rad: motor.damping,
            maximum_force_nm: motor.max_force,
        }
    }

    pub(crate) fn validates(self, target_velocity_rad_s: f32, maximum_force_nm: f32) -> bool {
        self.model == MotorModel::ForceBased
            && self.target_position_rad == 0.0
            && self.target_velocity_rad_s == target_velocity_rad_s
            && self.stiffness_nm_per_rad == VELOCITY_ONLY_NATIVE_POSITION_STIFFNESS_NM_PER_RAD
            && self.damping_nm_s_per_rad == VELOCITY_ONLY_MOTOR_DAMPING_NM_S_PER_RAD
            && self.maximum_force_nm == maximum_force_nm
    }

    fn to_json(self) -> Value {
        json!({
            "model": motor_model_name(self.model),
            "target_position_rad": self.target_position_rad,
            "target_velocity_rad_s": self.target_velocity_rad_s,
            "stiffness_nm_per_rad": self.stiffness_nm_per_rad,
            "damping_nm_s_per_rad": self.damping_nm_s_per_rad,
            "maximum_force_nm": self.maximum_force_nm,
        })
    }
}

fn raw_sha256(raw: &str) -> String {
    format!("sha256:{:x}", Sha256::digest(raw.as_bytes()))
}

fn motor_model_name(model: MotorModel) -> &'static str {
    match model {
        MotorModel::AccelerationBased => "AccelerationBased",
        MotorModel::ForceBased => "ForceBased",
    }
}

fn require_finite_positive(value: f32, code: &str) -> Result<(), String> {
    if value.is_finite() && value > 0.0 {
        Ok(())
    } else {
        Err(code.to_owned())
    }
}

/// Convert the portable maximum impulse budget for one complete outer SDK
/// step into Rapier's ForceBased maximum force. Rapier enforces that force at
/// each solver small-step, so the corresponding observable motor-impulse cap
/// is `maximum_impulse / solver_iterations` per small-step.
pub(crate) fn velocity_only_maximum_force_from_outer_impulse_v1(
    maximum_outer_step_impulse_nms: f64,
) -> Result<f32, String> {
    if !maximum_outer_step_impulse_nms.is_finite() || maximum_outer_step_impulse_nms <= 0.0 {
        return Err("C6_RAP_V4_MAXIMUM_OUTER_IMPULSE_INVALID".to_owned());
    }
    let maximum_force_nm = (maximum_outer_step_impulse_nms / RAPIER_DT_S as f64) as f32;
    require_finite_positive(maximum_force_nm, "C6_RAP_V4_MAXIMUM_FORCE_INVALID")?;
    Ok(maximum_force_nm)
}

pub(crate) fn velocity_only_small_step_impulse_limit_v1(maximum_force_nm: f32) -> f32 {
    maximum_force_nm * RAPIER_DT_S / RAPIER_ACTIVE_SOLVER_ITERATIONS as f32
}

/// Configure the only native motor profile allowed by the Rapier v4 live
/// path: ForceBased velocity-only, zero native position stiffness, damping 10.
pub(crate) fn build_velocity_only_joint_v1(
    builder: RevoluteJointBuilder,
    target_velocity_rad_s: f32,
    maximum_force_nm: f32,
) -> Result<RevoluteJoint, String> {
    if !target_velocity_rad_s.is_finite() {
        return Err("C6_RAP_V4_TARGET_VELOCITY_NONFINITE".to_owned());
    }
    require_finite_positive(maximum_force_nm, "C6_RAP_V4_MAXIMUM_FORCE_INVALID")?;
    let joint = builder
        .motor_velocity(
            target_velocity_rad_s,
            VELOCITY_ONLY_MOTOR_DAMPING_NM_S_PER_RAD,
        )
        .motor_model(MotorModel::ForceBased)
        .motor_max_force(maximum_force_nm)
        .build();
    let readback = joint
        .motor()
        .map(VelocityOnlyMotorReadbackV1::from_motor)
        .ok_or_else(|| "C6_RAP_V4_BUILDER_MOTOR_MISSING".to_owned())?;
    if !readback.validates(target_velocity_rad_s, maximum_force_nm) {
        return Err("C6_RAP_V4_BUILDER_MOTOR_READBACK_MISMATCH".to_owned());
    }
    Ok(joint)
}

/// Apply and immediately read back the same velocity-only profile through the
/// mutable-joint route used on every prospective live control step.
pub(crate) fn update_velocity_only_motor_v1(
    joint: &mut RevoluteJoint,
    target_velocity_rad_s: f32,
    maximum_force_nm: f32,
) -> Result<VelocityOnlyMotorReadbackV1, String> {
    if !target_velocity_rad_s.is_finite() {
        return Err("C6_RAP_V4_TARGET_VELOCITY_NONFINITE".to_owned());
    }
    require_finite_positive(maximum_force_nm, "C6_RAP_V4_MAXIMUM_FORCE_INVALID")?;
    joint
        .set_motor_velocity(
            target_velocity_rad_s,
            VELOCITY_ONLY_MOTOR_DAMPING_NM_S_PER_RAD,
        )
        .set_motor_model(MotorModel::ForceBased)
        .set_motor_max_force(maximum_force_nm);
    let readback = joint
        .motor()
        .map(VelocityOnlyMotorReadbackV1::from_motor)
        .ok_or_else(|| "C6_RAP_V4_MUTABLE_MOTOR_MISSING".to_owned())?;
    if !readback.validates(target_velocity_rad_s, maximum_force_nm) {
        return Err("C6_RAP_V4_MUTABLE_MOTOR_READBACK_MISMATCH".to_owned());
    }
    Ok(readback)
}

fn zero_world_boundary_valid(
    world_build_count: u64,
    scene_insertion_count: u64,
    physics_state_modified: bool,
    locomotion_outcome_exposed: bool,
    physical_acceptance_authority: bool,
) -> bool {
    world_build_count == 0
        && scene_insertion_count == 0
        && !physics_state_modified
        && !locomotion_outcome_exposed
        && !physical_acceptance_authority
}

/// Complete synthetic gate for the live-v4 adapter integration.
///
/// Building and mutating standalone joint values exercises Rapier's builder
/// and mutable readback APIs but does not construct a PhysicsWorld, insert a
/// scene, step a solver, or expose a locomotion outcome.
pub fn run_velocity_only_live_integration_preflight() -> Result<Value, String> {
    if raw_sha256(VH1_CLOSURE_RAW) != VH1_CLOSURE_RAW_SHA256
        || raw_sha256(CANONICAL_PROFILE_RAW) != CANONICAL_PROFILE_RAW_SHA256
        || raw_sha256(ACTIVE_CONFIGURATION_V1_RAW) != ACTIVE_CONFIGURATION_V1_RAW_SHA256
    {
        return Err("C6_RAP_V4_BOUND_PREDECESSOR_HASH_MISMATCH".to_owned());
    }
    let vh1_closure: Value = serde_json::from_str(VH1_CLOSURE_RAW)
        .map_err(|error| format!("C6_RAP_V4_VH1_CLOSURE_PARSE:{error}"))?;
    let vh1_authority_valid = vh1_closure["status"]
        == "closed_positive_exact_finite_velocity_only_host_characterization"
        && vh1_closure["technical_disposition"]["exact_finite_velocity_only_host_characterization_passed"]
            == true
        && vh1_closure["validated_host_profile"]["rapier_host_profile_id"]
            == VELOCITY_ONLY_LIVE_PROFILE_ID
        && vh1_closure["validated_host_profile"]["motor_model"] == "ForceBased"
        && vh1_closure["validated_host_profile"]["position_stiffness_nm_per_rad"] == 0.0
        && vh1_closure["validated_host_profile"]["damping_nm_s_per_rad"]
            == VELOCITY_ONLY_MOTOR_DAMPING_NM_S_PER_RAD
        && vh1_closure["claims"]["rapier_v4_live_adapter_integration"] == false;

    let mut default_canary = RevoluteJoint::new(Vector::X);
    default_canary.set_motor_velocity(0.75, VELOCITY_ONLY_MOTOR_DAMPING_NM_S_PER_RAD);
    let default_readback = default_canary
        .motor()
        .map(VelocityOnlyMotorReadbackV1::from_motor)
        .ok_or_else(|| "C6_RAP_V4_DEFAULT_CANARY_MOTOR_MISSING".to_owned())?;
    let default_model_canary_passed = default_readback.model == MotorModel::AccelerationBased;

    let maximum_force_nm = 6.0;
    let explicit_builder =
        build_velocity_only_joint_v1(RevoluteJointBuilder::new(Vector::X), 0.75, maximum_force_nm)?;
    let explicit_builder_readback = explicit_builder
        .motor()
        .map(VelocityOnlyMotorReadbackV1::from_motor)
        .ok_or_else(|| "C6_RAP_V4_BUILDER_MOTOR_MISSING".to_owned())?;
    let mut mutable = explicit_builder;
    let mutable_readback = update_velocity_only_motor_v1(&mut mutable, -1.5, maximum_force_nm)?;

    let compiled = compile_bounded_quadruped(descriptor()).map_err(|error| error.to_string())?;
    let controller =
        BalancedWaveController::new_for_policy(compiled.clone(), BALANCED_WAVE_BW15F_B_POLICY_ID)
            .map_err(|error| error.to_string())?;
    if controller.profile().policy_id != BALANCED_WAVE_BW15F_B_POLICY_ID
        || !controller.profile().branch_surfaces.is_empty()
    {
        return Err("C6_RAP_V4_SELECTED_POLICY_IDENTITY_MISMATCH".to_owned());
    }
    let output = controller.step(
        &BalancedWaveControllerMemory::initial(),
        &synthetic_state_frame(&compiled, Quaternion::IDENTITY),
        &motion_command(0, PhaseProgressionMode::Clocked),
    );
    if output.actuation.safe_no_actuation || !output.actuation.failure_codes.is_empty() {
        return Err("C6_RAP_V4_SYNTHETIC_CONTROLLER_OUTPUT_INVALID".to_owned());
    }
    let ordered_residuals = output
        .actuation
        .ordered_commands
        .iter()
        .enumerate()
        .map(|(index, command)| CanonicalVelocityResidualV1 {
            schema_version: CANONICAL_VELOCITY_RESIDUAL_V1_VERSION.to_owned(),
            actuator_id: command.actuator_id.clone(),
            canonical_velocity_delta_rad_s: if index % 2 == 0 { 0.01 } else { -0.01 },
            command_not_measurement: true,
            physical_acceptance_authority: false,
        })
        .collect::<Vec<_>>();
    let (canonical, host_mapping) =
        map_bw19v_velocity_only_v4(&compiled, &output.actuation, &ordered_residuals)?;

    let mapping_formula_passed = output
        .actuation
        .ordered_commands
        .iter()
        .zip(&ordered_residuals)
        .zip(&canonical.ordered_commands)
        .zip(&host_mapping.ordered_commands)
        .all(|(((legacy, residual), canonical_command), host_command)| {
            let expected_unbounded = legacy.target_velocity_rad_s
                * LEGACY_GODOT_HOST_TO_CANONICAL_VELOCITY_SIGN
                + residual.canonical_velocity_delta_rad_s;
            canonical_command
                .unbounded_canonical_target_velocity_rad_s
                .to_bits()
                == expected_unbounded.to_bits()
                && host_command.host_target_velocity_rad_s.to_bits()
                    == (canonical_command.combined_canonical_target_velocity_rad_s
                        * RAPIER_CANONICAL_TO_HOST_VELOCITY_SIGN)
                        .to_bits()
                && host_command.native_target_position_rad.is_none()
        });
    let mixed_space_negative_witness_count = output
        .actuation
        .ordered_commands
        .iter()
        .zip(&ordered_residuals)
        .zip(&host_mapping.ordered_commands)
        .filter(|((legacy, residual), mapped)| {
            let mixed = legacy.target_velocity_rad_s + residual.canonical_velocity_delta_rad_s;
            mixed.to_bits() != mapped.host_target_velocity_rad_s.to_bits()
        })
        .count();

    let mut reordered = ordered_residuals.clone();
    reordered.swap(0, 1);
    let reordered_residual_canary_rejected =
        map_bw19v_velocity_only_v4(&compiled, &output.actuation, &reordered).is_err();
    let mut missing = ordered_residuals.clone();
    missing.pop();
    let missing_residual_canary_rejected =
        map_bw19v_velocity_only_v4(&compiled, &output.actuation, &missing).is_err();
    let mut wrong_sign_profile =
        VelocityOnlyHostProfileV1::rapier_force_based_velocity_only_target();
    wrong_sign_profile.canonical_to_host_velocity_sign = -1.0;
    let wrong_sign_profile_canary_rejected =
        map_canonical_velocity_to_host_v1(&compiled.morphology, &canonical, &wrong_sign_profile)
            .is_err();

    let wrong_model = RevoluteJointBuilder::new(Vector::X)
        .motor_velocity(0.75, VELOCITY_ONLY_MOTOR_DAMPING_NM_S_PER_RAD)
        .motor_max_force(maximum_force_nm)
        .build();
    let wrong_model_canary_rejected = wrong_model
        .motor()
        .map(VelocityOnlyMotorReadbackV1::from_motor)
        .is_some_and(|readback| !readback.validates(0.75, maximum_force_nm));
    let nonzero_stiffness = RevoluteJointBuilder::new(Vector::X)
        .motor(0.0, 0.75, 40.0, VELOCITY_ONLY_MOTOR_DAMPING_NM_S_PER_RAD)
        .motor_model(MotorModel::ForceBased)
        .motor_max_force(maximum_force_nm)
        .build();
    let nonzero_stiffness_canary_rejected = nonzero_stiffness
        .motor()
        .map(VelocityOnlyMotorReadbackV1::from_motor)
        .is_some_and(|readback| !readback.validates(0.75, maximum_force_nm));
    let wrong_target_canary_rejected = !mutable_readback.validates(1.5, maximum_force_nm);
    let wrong_force_canary_rejected = !mutable_readback.validates(-1.5, maximum_force_nm * 2.0);

    let mut maximum_force_receipts = Vec::new();
    let mut maximum_small_step_reconstruction_error_nms = 0.0_f64;
    let mut all_selected_actuator_builder_readbacks_passed = true;
    let mut all_selected_actuator_mutable_readbacks_passed = true;
    for (actuator, command) in compiled
        .morphology
        .morphology_spec
        .actuators
        .iter()
        .zip(&host_mapping.ordered_commands)
    {
        if actuator.actuator_id != command.actuator_id {
            return Err("C6_RAP_V4_ACTUATOR_FORCE_MAPPING_ORDER".to_owned());
        }
        let force =
            velocity_only_maximum_force_from_outer_impulse_v1(actuator.maximum_impulse_nms)?;
        let small_step_limit = velocity_only_small_step_impulse_limit_v1(force);
        let expected = actuator.maximum_impulse_nms / RAPIER_ACTIVE_SOLVER_ITERATIONS as f64;
        maximum_small_step_reconstruction_error_nms = maximum_small_step_reconstruction_error_nms
            .max((small_step_limit as f64 - expected).abs());
        let target_velocity = command.host_target_velocity_rad_s as f32;
        let selected_builder = build_velocity_only_joint_v1(
            RevoluteJointBuilder::new(Vector::X),
            target_velocity,
            force,
        )?;
        let builder_readback = selected_builder
            .motor()
            .map(VelocityOnlyMotorReadbackV1::from_motor)
            .ok_or_else(|| "C6_RAP_V4_SELECTED_BUILDER_MOTOR_MISSING".to_owned())?;
        let mut selected_mutable = selected_builder;
        let mutable_readback =
            update_velocity_only_motor_v1(&mut selected_mutable, target_velocity, force)?;
        all_selected_actuator_builder_readbacks_passed &=
            builder_readback.validates(target_velocity, force);
        all_selected_actuator_mutable_readbacks_passed &=
            mutable_readback.validates(target_velocity, force);
        maximum_force_receipts.push(json!({
            "actuator_id": actuator.actuator_id,
            "portable_maximum_outer_step_impulse_nms": actuator.maximum_impulse_nms,
            "rapier_maximum_force_nm": force,
            "observable_small_step_impulse_limit_nms": small_step_limit,
            "host_target_velocity_rad_s": target_velocity,
            "builder_readback": builder_readback.to_json(),
            "mutable_update_readback": mutable_readback.to_json(),
        }));
    }
    let exact_force_mapping_passed = maximum_force_receipts.len() == 8
        && maximum_small_step_reconstruction_error_nms <= MOTOR_READBACK_TOLERANCE as f64
        && all_selected_actuator_builder_readbacks_passed
        && all_selected_actuator_mutable_readbacks_passed;

    let serialized = serde_json::to_string(&host_mapping)
        .map_err(|error| format!("C6_RAP_V4_MAPPING_SERIALIZE:{error}"))?;
    let round_trip: Value = serde_json::from_str(&serialized)
        .map_err(|error| format!("C6_RAP_V4_MAPPING_ROUND_TRIP:{error}"))?;
    let serialization_round_trip_passed = round_trip
        == serde_json::to_value(&host_mapping)
            .map_err(|error| format!("C6_RAP_V4_MAPPING_VALUE:{error}"))?;
    let boundary_inflation_canary_rejected = !zero_world_boundary_valid(1, 1, true, true, true);
    let actual_boundary_passed = zero_world_boundary_valid(0, 0, false, false, false);

    let ok = vh1_authority_valid
        && default_model_canary_passed
        && explicit_builder_readback.validates(0.75, maximum_force_nm)
        && mutable_readback.validates(-1.5, maximum_force_nm)
        && mapping_formula_passed
        && mixed_space_negative_witness_count > 0
        && reordered_residual_canary_rejected
        && missing_residual_canary_rejected
        && wrong_sign_profile_canary_rejected
        && wrong_model_canary_rejected
        && nonzero_stiffness_canary_rejected
        && wrong_target_canary_rejected
        && wrong_force_canary_rejected
        && exact_force_mapping_passed
        && serialization_round_trip_passed
        && boundary_inflation_canary_rejected
        && actual_boundary_passed;

    let report = json!({
        "schema_version":
            "sporespore_rapier_velocity_only_live_integration_preflight_v1",
        "ok": ok,
        "adapter_id": ADAPTER_ID,
        "rapier_version": rapier3d::VERSION,
        "live_profile_id": VELOCITY_ONLY_LIVE_PROFILE_ID,
        "canonical_profile_raw_sha256": CANONICAL_PROFILE_RAW_SHA256,
        "vh1_closure_raw_sha256": VH1_CLOSURE_RAW_SHA256,
        "active_configuration_v1_predecessor_raw_sha256":
            ACTIVE_CONFIGURATION_V1_RAW_SHA256,
        "vh1_positive_authority_valid": vh1_authority_valid,
        "selected_policy_id": controller.profile().policy_id,
        "selected_policy_branch_surface_count": controller.profile().branch_surfaces.len(),
        "bw19v_global_requested_correction_scale":
            BW19V_GLOBAL_REQUESTED_CORRECTION_SCALE,
        "synthetic_actuator_count": host_mapping.ordered_commands.len(),
        "canonical_mapping_formula_passed": mapping_formula_passed,
        "native_position_target_count": host_mapping
            .ordered_commands
            .iter()
            .filter(|command| command.native_target_position_rad.is_some())
            .count(),
        "mixed_space_negative_witness_count": mixed_space_negative_witness_count,
        "default_model_canary": {
            "expected": "AccelerationBased",
            "readback": default_readback.to_json(),
            "passed": default_model_canary_passed,
        },
        "explicit_builder_readback": explicit_builder_readback.to_json(),
        "mutable_update_readback": mutable_readback.to_json(),
        "ordered_maximum_force_receipts": maximum_force_receipts,
        "maximum_small_step_reconstruction_error_nms":
            maximum_small_step_reconstruction_error_nms,
        "all_selected_actuator_builder_readbacks_passed":
            all_selected_actuator_builder_readbacks_passed,
        "all_selected_actuator_mutable_readbacks_passed":
            all_selected_actuator_mutable_readbacks_passed,
        "exact_force_mapping_passed": exact_force_mapping_passed,
        "reordered_residual_canary_rejected": reordered_residual_canary_rejected,
        "missing_residual_canary_rejected": missing_residual_canary_rejected,
        "wrong_sign_profile_canary_rejected": wrong_sign_profile_canary_rejected,
        "wrong_model_canary_rejected": wrong_model_canary_rejected,
        "nonzero_stiffness_canary_rejected": nonzero_stiffness_canary_rejected,
        "wrong_target_velocity_canary_rejected": wrong_target_canary_rejected,
        "wrong_maximum_force_canary_rejected": wrong_force_canary_rejected,
        "serialization_round_trip_passed": serialization_round_trip_passed,
        "world_and_authority_inflation_canary_rejected":
            boundary_inflation_canary_rejected,
        "world_build_count": 0,
        "scene_insertion_count": 0,
        "physics_state_modified": false,
        "locomotion_outcome_exposed": false,
        "rapier_v4_live_adapter_semantic_integration": ok,
        "selected_policy_physical_authority": false,
        "walking_acceptance": false,
        "release_authorized": false,
        "physical_acceptance_authority": false,
    });
    if !ok {
        return Err("C6_RAP_V4_LIVE_INTEGRATION_PREFLIGHT_FAILED".to_owned());
    }
    Ok(report)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn velocity_only_live_integration_preflight_is_complete_and_zero_world() {
        let report = run_velocity_only_live_integration_preflight().unwrap();
        assert_eq!(report["ok"], true);
        assert_eq!(report["vh1_positive_authority_valid"], true);
        assert_eq!(report["canonical_mapping_formula_passed"], true);
        assert_eq!(report["native_position_target_count"], 0);
        assert_eq!(report["synthetic_actuator_count"], 8);
        assert!(
            report["mixed_space_negative_witness_count"]
                .as_u64()
                .unwrap()
                > 0
        );
        assert_eq!(report["exact_force_mapping_passed"], true);
        assert_eq!(
            report["all_selected_actuator_builder_readbacks_passed"],
            true
        );
        assert_eq!(
            report["all_selected_actuator_mutable_readbacks_passed"],
            true
        );
        for field in [
            "reordered_residual_canary_rejected",
            "missing_residual_canary_rejected",
            "wrong_sign_profile_canary_rejected",
            "wrong_model_canary_rejected",
            "nonzero_stiffness_canary_rejected",
            "wrong_target_velocity_canary_rejected",
            "wrong_maximum_force_canary_rejected",
            "serialization_round_trip_passed",
            "world_and_authority_inflation_canary_rejected",
        ] {
            assert_eq!(report[field], true, "{field}");
        }
        assert_eq!(report["world_build_count"], 0);
        assert_eq!(report["scene_insertion_count"], 0);
        assert_eq!(report["physics_state_modified"], false);
        assert_eq!(report["locomotion_outcome_exposed"], false);
        assert_eq!(report["selected_policy_physical_authority"], false);
        assert_eq!(report["physical_acceptance_authority"], false);
    }
}
