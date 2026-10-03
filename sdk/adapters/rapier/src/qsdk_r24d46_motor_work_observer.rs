use rapier3d::dynamics::JointMotor;
use serde_json::{Value, json};

use crate::{
    RAPIER_ACTIVE_INTERNAL_PGS_ITERATIONS, RAPIER_ACTIVE_INTERNAL_STABILIZATION_ITERATIONS,
    RAPIER_ACTIVE_SOLVER_ITERATIONS,
};

pub const R24D46_GATE_ID: &str = "QSDK-R24D46";
pub const R24D46_PATCH_FEATURE: &str = "sporespore-motor-work-telemetry";
pub const R24D46_WORK_RULE_ID: &str =
    "rapier_solver_delta_impulse_times_application_centered_relative_velocity_v1";

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct RapierMotorWorkSampleV1 {
    pub sequence: u64,
    pub generalized_impulse: f64,
    pub absolute_generalized_impulse: f64,
    pub supplied_work_j: f64,
    pub absorbed_work_j: f64,
    pub net_work_j: f64,
    pub application_count: u32,
    pub small_step_count: u32,
    pub applications_per_small_step: u32,
    pub numerical_consistency_bound: f64,
}

impl RapierMotorWorkSampleV1 {
    fn to_json(self) -> Value {
        json!({
            "schema_version": "sporespore_rapier_motor_work_sample_v1",
            "work_rule_id": R24D46_WORK_RULE_ID,
            "coordinate_semantics": "body2_minus_body1",
            "sequence": self.sequence,
            "generalized_impulse": self.generalized_impulse,
            "absolute_generalized_impulse": self.absolute_generalized_impulse,
            "supplied_work_j": self.supplied_work_j,
            "absorbed_work_j": self.absorbed_work_j,
            "net_work_j": self.net_work_j,
            "application_count": self.application_count,
            "small_step_count": self.small_step_count,
            "applications_per_small_step": self.applications_per_small_step,
            "numerical_consistency_bound": self.numerical_consistency_bound,
        })
    }
}

pub(crate) fn accumulation_consistency_bound(
    application_count: u32,
    scale: f64,
) -> Result<f64, String> {
    let n = f64::from(application_count.max(1));
    let epsilon = f64::from(f32::EPSILON);
    let denominator = 1.0 - n * epsilon;
    if denominator <= 0.0 {
        return Err("QSDK_R24D46_NUMERICAL_BOUND_DOMAIN_INVALID".to_owned());
    }
    let gamma_n = n * epsilon / denominator;
    Ok((2.0 * gamma_n + epsilon) * scale.max(1.0))
}

pub fn collect_r24d46_rapier_motor_work_v1(
    motor: &JointMotor,
    previous_sequence: u64,
    expected_small_step_count: u32,
    expected_application_count: u32,
) -> Result<RapierMotorWorkSampleV1, String> {
    if expected_small_step_count == 0
        || expected_application_count == 0
        || expected_application_count % expected_small_step_count != 0
    {
        return Err("QSDK_R24D46_EXPECTED_COUNTERS_INVALID".to_owned());
    }
    let expected_sequence = previous_sequence
        .checked_add(1)
        .ok_or_else(|| "QSDK_R24D46_EXPECTED_SEQUENCE_OVERFLOW".to_owned())?;
    let telemetry = motor.sporespore_solver_work;
    if telemetry.sequence != expected_sequence {
        return Err(format!(
            "QSDK_R24D46_TELEMETRY_SEQUENCE_INVALID:expected={expected_sequence}:observed={}",
            telemetry.sequence
        ));
    }
    if telemetry.small_step_count != expected_small_step_count {
        return Err(format!(
            "QSDK_R24D46_SMALL_STEP_COUNT_INVALID:expected={expected_small_step_count}:observed={}",
            telemetry.small_step_count
        ));
    }
    if telemetry.application_count != expected_application_count {
        return Err(format!(
            "QSDK_R24D46_APPLICATION_COUNT_INVALID:expected={expected_application_count}:observed={}",
            telemetry.application_count
        ));
    }

    let generalized_impulse = f64::from(telemetry.generalized_impulse);
    let absolute_generalized_impulse = f64::from(telemetry.absolute_generalized_impulse);
    let supplied_work_j = f64::from(telemetry.supplied_work);
    let absorbed_work_j = f64::from(telemetry.absorbed_work);
    let net_work_j = f64::from(telemetry.net_work);
    if [
        generalized_impulse,
        absolute_generalized_impulse,
        supplied_work_j,
        absorbed_work_j,
        net_work_j,
    ]
    .iter()
    .any(|value| !value.is_finite())
    {
        return Err("QSDK_R24D46_MOTOR_WORK_NONFINITE".to_owned());
    }
    if absolute_generalized_impulse < 0.0 || supplied_work_j < 0.0 || absorbed_work_j < 0.0 {
        return Err("QSDK_R24D46_NONNEGATIVE_PARTITION_INVALID".to_owned());
    }

    let scale = absolute_generalized_impulse
        .max(generalized_impulse.abs())
        .max(supplied_work_j + absorbed_work_j)
        .max(net_work_j.abs());
    let numerical_consistency_bound =
        accumulation_consistency_bound(telemetry.application_count, scale)?;
    if generalized_impulse.abs() > absolute_generalized_impulse + numerical_consistency_bound {
        return Err("QSDK_R24D46_ABSOLUTE_IMPULSE_PARTITION_INVALID".to_owned());
    }
    if (net_work_j - (supplied_work_j - absorbed_work_j)).abs() > numerical_consistency_bound {
        return Err("QSDK_R24D46_WORK_PARTITION_INVALID".to_owned());
    }

    Ok(RapierMotorWorkSampleV1 {
        sequence: telemetry.sequence,
        generalized_impulse,
        absolute_generalized_impulse,
        supplied_work_j,
        absorbed_work_j,
        net_work_j,
        application_count: telemetry.application_count,
        small_step_count: telemetry.small_step_count,
        applications_per_small_step: telemetry.application_count / telemetry.small_step_count,
        numerical_consistency_bound,
    })
}

fn active_expected_counts() -> (u32, u32) {
    let small_steps = RAPIER_ACTIVE_SOLVER_ITERATIONS as u32;
    let applications_per_small_step = (RAPIER_ACTIVE_INTERNAL_PGS_ITERATIONS
        + RAPIER_ACTIVE_INTERNAL_STABILIZATION_ITERATIONS)
        as u32;
    (small_steps, small_steps * applications_per_small_step)
}

fn require_rejection(
    motor: &JointMotor,
    previous_sequence: u64,
    expected_small_steps: u32,
    expected_applications: u32,
    expected_code: &str,
) -> Result<String, String> {
    let error = collect_r24d46_rapier_motor_work_v1(
        motor,
        previous_sequence,
        expected_small_steps,
        expected_applications,
    )
    .expect_err("R24D46 mutation control unexpectedly passed");
    if !error.starts_with(expected_code) {
        return Err(format!(
            "QSDK_R24D46_MUTATION_WRONG_ERROR:expected={expected_code}:observed={error}"
        ));
    }
    Ok(error)
}

pub fn run_qsdk_r24d46_rapier_motor_work_zero_world_qualification() -> Result<Value, String> {
    let (small_steps, applications) = active_expected_counts();
    let mut fixture = JointMotor::default();
    fixture.sporespore_solver_work.sequence = 1;
    fixture.sporespore_solver_work.generalized_impulse = -0.6;
    fixture.sporespore_solver_work.absolute_generalized_impulse = 0.8;
    fixture.sporespore_solver_work.supplied_work = 1.25;
    fixture.sporespore_solver_work.absorbed_work = 0.5;
    fixture.sporespore_solver_work.net_work = 0.75;
    fixture.sporespore_solver_work.application_count = applications;
    fixture.sporespore_solver_work.small_step_count = small_steps;
    let accepted = collect_r24d46_rapier_motor_work_v1(&fixture, 0, small_steps, applications)?;

    let mut stale = fixture;
    stale.sporespore_solver_work.sequence = 0;
    let mut incomplete = fixture;
    incomplete.sporespore_solver_work.application_count -= 1;
    let mut nonfinite = fixture;
    nonfinite.sporespore_solver_work.net_work = f32::NAN;
    let mut negative_partition = fixture;
    negative_partition.sporespore_solver_work.supplied_work = -0.01;
    let mut bad_impulse_partition = fixture;
    bad_impulse_partition
        .sporespore_solver_work
        .absolute_generalized_impulse = 0.1;
    let mut bad_work_partition = fixture;
    bad_work_partition.sporespore_solver_work.net_work = 0.9;
    let mutation_rejections = vec![
        require_rejection(
            &stale,
            0,
            small_steps,
            applications,
            "QSDK_R24D46_TELEMETRY_SEQUENCE_INVALID",
        )?,
        require_rejection(
            &incomplete,
            0,
            small_steps,
            applications,
            "QSDK_R24D46_APPLICATION_COUNT_INVALID",
        )?,
        require_rejection(
            &nonfinite,
            0,
            small_steps,
            applications,
            "QSDK_R24D46_MOTOR_WORK_NONFINITE",
        )?,
        require_rejection(
            &negative_partition,
            0,
            small_steps,
            applications,
            "QSDK_R24D46_NONNEGATIVE_PARTITION_INVALID",
        )?,
        require_rejection(
            &bad_impulse_partition,
            0,
            small_steps,
            applications,
            "QSDK_R24D46_ABSOLUTE_IMPULSE_PARTITION_INVALID",
        )?,
        require_rejection(
            &bad_work_partition,
            0,
            small_steps,
            applications,
            "QSDK_R24D46_WORK_PARTITION_INVALID",
        )?,
    ];

    Ok(json!({
        "schema_version": "sporespore_qsdk_r24d46_rapier_motor_work_zero_world_qualification_v1",
        "ok": true,
        "gate_id": R24D46_GATE_ID,
        "question_class": "development",
        "qualification_class": "zero_world_exact_solver_work_observer",
        "patch_feature": R24D46_PATCH_FEATURE,
        "work_rule_id": R24D46_WORK_RULE_ID,
        "supported_solver_path": "scalar_rigid_body_impulse_joint_motor_constraints",
        "simd_solver_path_supported": false,
        "generic_or_multibody_solver_path_supported": false,
        "expected_small_step_count": small_steps,
        "expected_applications_per_small_step": applications / small_steps,
        "expected_application_count": applications,
        "accepted_fixture": accepted.to_json(),
        "mutation_rejection_count": mutation_rejections.len(),
        "mutation_rejections": mutation_rejections,
        "unmeasured_energy_channels": [
            "contact_and_friction_constraint_work",
            "nonmotor_joint_and_stabilization_constraint_work",
            "explicit_external_force_work",
            "integration_and_numerical_dissipation"
        ],
        "unmeasured_energy_channels_typed_refused": true,
        "complete_energy_partition_claimed": false,
        "physical_question_declared": false,
        "physical_execution_authorized": false,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": false,
        "prone_to_standing_claimed": false,
        "physical_acceptance_authority": false,
        "release_authority": false,
    }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn qualification_is_zero_world_and_fail_closed() {
        let receipt = run_qsdk_r24d46_rapier_motor_work_zero_world_qualification().unwrap();
        assert_eq!(receipt["ok"], true);
        assert_eq!(receipt["expected_small_step_count"], 16);
        assert_eq!(receipt["expected_applications_per_small_step"], 8);
        assert_eq!(receipt["expected_application_count"], 128);
        assert_eq!(receipt["mutation_rejection_count"], 6);
        assert_eq!(receipt["unmeasured_energy_channels_typed_refused"], true);
        assert_eq!(receipt["world_build_count"], 0);
        assert_eq!(receipt["solver_step_count"], 0);
        assert_eq!(receipt["physical_execution_authorized"], false);
    }
}
