//! Zero-world qualification for the R24D47 Rapier energy-exchange partition.

use rapier3d::dynamics::{ImpulseJointHandle, JointMotor};
use rapier3d::pipeline::{PhysicsWorld, SporeSporeEnergyExchangeTelemetry};
use serde_json::{Value, json};

use crate::qsdk_r24d46_motor_work_observer::accumulation_consistency_bound;
use crate::{
    RAPIER_ACTIVE_INTERNAL_PGS_ITERATIONS, RAPIER_ACTIVE_INTERNAL_STABILIZATION_ITERATIONS,
    RAPIER_ACTIVE_SOLVER_ITERATIONS, RAPIER_DT_S, RapierMotorWorkSampleV1,
    collect_r24d46_rapier_motor_work_v1,
};

pub const R24D47_GATE_ID: &str = "QSDK-R24D47";
pub const R24D47_PATCH_FEATURE: &str = "sporespore-energy-exchange-telemetry";
pub const R24D47_ENERGY_RULE_ID: &str = "rapier_scalar_solver_phase_total_kinetic_exchange_v1";

const EXPECTED_DYNAMIC_BODY_COUNT: u32 = 9;
const EXPECTED_FIXED_GROUND_BODY_COUNT: u32 = 1;
const EXPECTED_IMPULSE_JOINT_COUNT: u32 = 8;
const EXPECTED_CCD_SUBSTEP_COUNT: u32 = 1;
const EXPECTED_ISLAND_SOLVE_COUNT: u32 = 1;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct RapierEnergyExchangeRouteCapabilityV1 {
    source_measurement: bool,
    dynamic_body_count: u32,
    fixed_ground_body_count: u32,
    impulse_joint_count: u32,
    multibody_joint_count: u32,
    kinematic_body_count: u32,
    locked_axis_body_count: u32,
    nonzero_linear_damping_body_count: u32,
    nonzero_angular_damping_body_count: u32,
    nonunit_gravity_scale_body_count: u32,
    nonzero_user_force_body_count: u32,
    nonzero_user_torque_body_count: u32,
    gyroscopic_force_body_count: u32,
    external_impulse_application_count: u32,
    external_intervention_count: u32,
    sleeping_enabled_dynamic_body_count: u32,
    solver_small_steps_per_outer_step: u32,
    internal_pgs_iterations_per_small_step: u32,
    internal_stabilization_iterations_per_small_step: u32,
    outer_timestep_f32_bits: u32,
    length_unit_f32_bits: u32,
    warmstart_coefficient_f32_bits: u32,
    maximum_ccd_substeps: u32,
}

impl RapierEnergyExchangeRouteCapabilityV1 {
    fn exact_supported_fixture() -> Self {
        Self {
            source_measurement: true,
            dynamic_body_count: EXPECTED_DYNAMIC_BODY_COUNT,
            fixed_ground_body_count: EXPECTED_FIXED_GROUND_BODY_COUNT,
            impulse_joint_count: EXPECTED_IMPULSE_JOINT_COUNT,
            multibody_joint_count: 0,
            kinematic_body_count: 0,
            locked_axis_body_count: 0,
            nonzero_linear_damping_body_count: 0,
            nonzero_angular_damping_body_count: 0,
            nonunit_gravity_scale_body_count: 0,
            nonzero_user_force_body_count: 0,
            nonzero_user_torque_body_count: 0,
            gyroscopic_force_body_count: 0,
            external_impulse_application_count: 0,
            external_intervention_count: 0,
            sleeping_enabled_dynamic_body_count: 0,
            solver_small_steps_per_outer_step: u32::try_from(RAPIER_ACTIVE_SOLVER_ITERATIONS)
                .expect("active solver-step count must fit u32"),
            internal_pgs_iterations_per_small_step: u32::try_from(
                RAPIER_ACTIVE_INTERNAL_PGS_ITERATIONS,
            )
            .expect("active PGS count must fit u32"),
            internal_stabilization_iterations_per_small_step: u32::try_from(
                RAPIER_ACTIVE_INTERNAL_STABILIZATION_ITERATIONS,
            )
            .expect("active stabilization count must fit u32"),
            outer_timestep_f32_bits: RAPIER_DT_S.to_bits(),
            length_unit_f32_bits: 1.0_f32.to_bits(),
            warmstart_coefficient_f32_bits: 1.0_f32.to_bits(),
            maximum_ccd_substeps: EXPECTED_CCD_SUBSTEP_COUNT,
        }
    }

    fn to_json(self) -> Value {
        json!({
            "source_measurement": self.source_measurement,
            "dynamic_body_count": self.dynamic_body_count,
            "fixed_ground_body_count": self.fixed_ground_body_count,
            "impulse_joint_count": self.impulse_joint_count,
            "multibody_joint_count": self.multibody_joint_count,
            "kinematic_body_count": self.kinematic_body_count,
            "locked_axis_body_count": self.locked_axis_body_count,
            "nonzero_linear_damping_body_count": self.nonzero_linear_damping_body_count,
            "nonzero_angular_damping_body_count": self.nonzero_angular_damping_body_count,
            "nonunit_gravity_scale_body_count": self.nonunit_gravity_scale_body_count,
            "nonzero_user_force_body_count": self.nonzero_user_force_body_count,
            "nonzero_user_torque_body_count": self.nonzero_user_torque_body_count,
            "gyroscopic_force_body_count": self.gyroscopic_force_body_count,
            "external_impulse_application_count": self.external_impulse_application_count,
            "external_intervention_count": self.external_intervention_count,
            "sleeping_enabled_dynamic_body_count": self.sleeping_enabled_dynamic_body_count,
            "solver_small_steps_per_outer_step": self.solver_small_steps_per_outer_step,
            "internal_pgs_iterations_per_small_step":
                self.internal_pgs_iterations_per_small_step,
            "internal_stabilization_iterations_per_small_step":
                self.internal_stabilization_iterations_per_small_step,
            "outer_timestep_f32_bits": self.outer_timestep_f32_bits,
            "length_unit_f32_bits": self.length_unit_f32_bits,
            "warmstart_coefficient_f32_bits": self.warmstart_coefficient_f32_bits,
            "maximum_ccd_substeps": self.maximum_ccd_substeps,
        })
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct RapierEnergyExchangeSampleV1 {
    pub sequence: u64,
    pub motor_supplied_work_j: f64,
    pub motor_absorbed_work_j: f64,
    pub motor_net_work_j: f64,
    pub joint_phase_exchange_j: f64,
    pub nonmotor_joint_and_stabilization_exchange_j: f64,
    pub contact_and_friction_exchange_j: f64,
    pub contact_warmstart_exchange_j: f64,
    pub signed_constraint_exchange_j: f64,
    pub signed_external_work_j: f64,
    pub passive_dissipation_j: f64,
    pub phase_partition_consistency_bound_j: f64,
    pub constraint_phase_count: u32,
    pub joint_phase_count: u32,
    pub contact_phase_count: u32,
    pub contact_warmstart_phase_count: u32,
    pub small_step_count: u32,
    pub motor_count: u32,
    pub source_measurement: bool,
}

impl RapierEnergyExchangeSampleV1 {
    pub(crate) fn to_json(self) -> Value {
        json!({
            "schema_version": "sporespore_rapier_energy_exchange_sample_v1",
            "rule_id": R24D47_ENERGY_RULE_ID,
            "sequence": self.sequence,
            "motor_supplied_work_j": self.motor_supplied_work_j,
            "motor_absorbed_work_j": self.motor_absorbed_work_j,
            "motor_net_work_j": self.motor_net_work_j,
            "joint_phase_exchange_j": self.joint_phase_exchange_j,
            "nonmotor_joint_and_stabilization_exchange_j":
                self.nonmotor_joint_and_stabilization_exchange_j,
            "contact_and_friction_exchange_j": self.contact_and_friction_exchange_j,
            "contact_warmstart_exchange_j": self.contact_warmstart_exchange_j,
            "signed_constraint_exchange_j": self.signed_constraint_exchange_j,
            "signed_external_work_j": self.signed_external_work_j,
            "passive_dissipation_j": self.passive_dissipation_j,
            "phase_partition_consistency_bound_j": self.phase_partition_consistency_bound_j,
            "constraint_phase_count": self.constraint_phase_count,
            "joint_phase_count": self.joint_phase_count,
            "contact_phase_count": self.contact_phase_count,
            "contact_warmstart_phase_count": self.contact_warmstart_phase_count,
            "small_step_count": self.small_step_count,
            "motor_count": self.motor_count,
            "source_measurement": self.source_measurement,
            "integration_and_numerical_exchange_role": "independent_v2_energy_balance_residual",
            "residual_derived_work_used": false,
        })
    }
}

pub(crate) fn observe_r24d47_rapier_world_route_capability_v1(
    world: &PhysicsWorld,
    external_impulse_application_count: u32,
    external_intervention_count: u32,
) -> Result<Value, String> {
    let route = observe_route_capability(
        world,
        external_impulse_application_count,
        external_intervention_count,
    )?;
    validate_route_capability(route)?;
    Ok(route.to_json())
}

fn finite(value: f64, code: &str) -> Result<f64, String> {
    if value.is_finite() {
        Ok(value)
    } else {
        Err(code.to_owned())
    }
}

fn expected_phase_counts() -> Result<(u32, u32, u32, u32), String> {
    let small_steps = u32::try_from(RAPIER_ACTIVE_SOLVER_ITERATIONS)
        .map_err(|_| "QSDK_R24D47_SMALL_STEP_COUNT_OVERFLOW".to_owned())?;
    let joint_per_small_step = RAPIER_ACTIVE_INTERNAL_PGS_ITERATIONS
        .checked_add(RAPIER_ACTIVE_INTERNAL_STABILIZATION_ITERATIONS)
        .ok_or_else(|| "QSDK_R24D47_PHASE_COUNT_OVERFLOW".to_owned())?;
    let joint_per_small_step = u32::try_from(joint_per_small_step)
        .map_err(|_| "QSDK_R24D47_PHASE_COUNT_OVERFLOW".to_owned())?;
    let joint_phases = small_steps
        .checked_mul(joint_per_small_step)
        .ok_or_else(|| "QSDK_R24D47_PHASE_COUNT_OVERFLOW".to_owned())?;
    let contact_phases = joint_phases;
    let warmstart_phases = small_steps;
    let constraint_phases = joint_phases
        .checked_add(contact_phases)
        .and_then(|value| value.checked_add(warmstart_phases))
        .ok_or_else(|| "QSDK_R24D47_PHASE_COUNT_OVERFLOW".to_owned())?;
    Ok((small_steps, joint_phases, contact_phases, constraint_phases))
}

fn validate_route_capability(route: RapierEnergyExchangeRouteCapabilityV1) -> Result<(), String> {
    if route.solver_small_steps_per_outer_step
        != u32::try_from(RAPIER_ACTIVE_SOLVER_ITERATIONS).unwrap_or(u32::MAX)
        || route.internal_pgs_iterations_per_small_step
            != u32::try_from(RAPIER_ACTIVE_INTERNAL_PGS_ITERATIONS).unwrap_or(u32::MAX)
        || route.internal_stabilization_iterations_per_small_step
            != u32::try_from(RAPIER_ACTIVE_INTERNAL_STABILIZATION_ITERATIONS).unwrap_or(u32::MAX)
        || route.outer_timestep_f32_bits != RAPIER_DT_S.to_bits()
        || route.length_unit_f32_bits != 1.0_f32.to_bits()
        || route.warmstart_coefficient_f32_bits != 1.0_f32.to_bits()
    {
        return Err("QSDK_R24D47_SOLVER_CONFIGURATION_UNSUPPORTED".to_owned());
    }
    if !route.source_measurement
        || route.dynamic_body_count != EXPECTED_DYNAMIC_BODY_COUNT
        || route.fixed_ground_body_count != EXPECTED_FIXED_GROUND_BODY_COUNT
        || route.impulse_joint_count != EXPECTED_IMPULSE_JOINT_COUNT
    {
        return Err("QSDK_R24D47_ROUTE_BODY_INVENTORY_INVALID".to_owned());
    }
    if route.nonzero_user_force_body_count != 0
        || route.nonzero_user_torque_body_count != 0
        || route.external_impulse_application_count != 0
        || route.external_intervention_count != 0
    {
        return Err("QSDK_R24D47_EXPLICIT_EXTERNAL_WORK_NOT_ZERO".to_owned());
    }
    if route.nonzero_linear_damping_body_count != 0
        || route.nonzero_angular_damping_body_count != 0
        || route.gyroscopic_force_body_count != 0
        || route.sleeping_enabled_dynamic_body_count != 0
    {
        return Err("QSDK_R24D47_PASSIVE_ZERO_CAPABILITY_INVALID".to_owned());
    }
    if route.kinematic_body_count != 0 {
        return Err("QSDK_R24D47_KINEMATIC_ROUTE_UNSUPPORTED".to_owned());
    }
    if route.locked_axis_body_count != 0 {
        return Err("QSDK_R24D47_LOCKED_AXIS_ROUTE_UNSUPPORTED".to_owned());
    }
    if route.multibody_joint_count != 0 {
        return Err("QSDK_R24D47_MULTIBODY_ROUTE_UNSUPPORTED".to_owned());
    }
    if route.nonunit_gravity_scale_body_count != 0 {
        return Err("QSDK_R24D47_GRAVITY_POTENTIAL_PARTITION_INVALID".to_owned());
    }
    if route.maximum_ccd_substeps != EXPECTED_CCD_SUBSTEP_COUNT {
        return Err("QSDK_R24D47_CCD_ROUTE_UNSUPPORTED".to_owned());
    }
    Ok(())
}

fn increment(value: &mut u32, code: &str) -> Result<(), String> {
    *value = value.checked_add(1).ok_or_else(|| code.to_owned())?;
    Ok(())
}

fn usize_to_u32(value: usize, code: &str) -> Result<u32, String> {
    u32::try_from(value).map_err(|_| code.to_owned())
}

fn observe_route_capability(
    world: &PhysicsWorld,
    external_impulse_application_count: u32,
    external_intervention_count: u32,
) -> Result<RapierEnergyExchangeRouteCapabilityV1, String> {
    let mut route = RapierEnergyExchangeRouteCapabilityV1 {
        source_measurement: true,
        dynamic_body_count: 0,
        fixed_ground_body_count: 0,
        impulse_joint_count: usize_to_u32(
            world.impulse_joints.len(),
            "QSDK_R24D47_IMPULSE_JOINT_COUNT_OVERFLOW",
        )?,
        multibody_joint_count: usize_to_u32(
            world.multibody_joints.iter().count(),
            "QSDK_R24D47_MULTIBODY_JOINT_COUNT_OVERFLOW",
        )?,
        kinematic_body_count: 0,
        locked_axis_body_count: 0,
        nonzero_linear_damping_body_count: 0,
        nonzero_angular_damping_body_count: 0,
        nonunit_gravity_scale_body_count: 0,
        nonzero_user_force_body_count: 0,
        nonzero_user_torque_body_count: 0,
        gyroscopic_force_body_count: 0,
        external_impulse_application_count,
        external_intervention_count,
        sleeping_enabled_dynamic_body_count: 0,
        solver_small_steps_per_outer_step: usize_to_u32(
            world.integration_parameters.num_solver_iterations,
            "QSDK_R24D47_SOLVER_STEP_COUNT_OVERFLOW",
        )?,
        internal_pgs_iterations_per_small_step: usize_to_u32(
            world.integration_parameters.num_internal_pgs_iterations,
            "QSDK_R24D47_PGS_COUNT_OVERFLOW",
        )?,
        internal_stabilization_iterations_per_small_step: usize_to_u32(
            world
                .integration_parameters
                .num_internal_stabilization_iterations,
            "QSDK_R24D47_STABILIZATION_COUNT_OVERFLOW",
        )?,
        outer_timestep_f32_bits: world.integration_parameters.dt.to_bits(),
        length_unit_f32_bits: world.integration_parameters.length_unit.to_bits(),
        warmstart_coefficient_f32_bits: world
            .integration_parameters
            .warmstart_coefficient
            .to_bits(),
        maximum_ccd_substeps: usize_to_u32(
            world.integration_parameters.max_ccd_substeps,
            "QSDK_R24D47_CCD_SUBSTEP_COUNT_OVERFLOW",
        )?,
    };

    for (_, body) in world.bodies.iter() {
        if body.is_fixed() {
            increment(
                &mut route.fixed_ground_body_count,
                "QSDK_R24D47_FIXED_BODY_COUNT_OVERFLOW",
            )?;
            continue;
        }
        if body.is_kinematic() {
            increment(
                &mut route.kinematic_body_count,
                "QSDK_R24D47_KINEMATIC_BODY_COUNT_OVERFLOW",
            )?;
            continue;
        }
        if !body.is_dynamic() {
            return Err("QSDK_R24D47_UNKNOWN_BODY_TYPE".to_owned());
        }
        increment(
            &mut route.dynamic_body_count,
            "QSDK_R24D47_DYNAMIC_BODY_COUNT_OVERFLOW",
        )?;
        if !body.locked_axes().is_empty() {
            increment(
                &mut route.locked_axis_body_count,
                "QSDK_R24D47_LOCKED_AXIS_BODY_COUNT_OVERFLOW",
            )?;
        }
        if body.linear_damping() != 0.0 {
            increment(
                &mut route.nonzero_linear_damping_body_count,
                "QSDK_R24D47_LINEAR_DAMPING_BODY_COUNT_OVERFLOW",
            )?;
        }
        if body.angular_damping() != 0.0 {
            increment(
                &mut route.nonzero_angular_damping_body_count,
                "QSDK_R24D47_ANGULAR_DAMPING_BODY_COUNT_OVERFLOW",
            )?;
        }
        if body.gravity_scale() != 1.0 {
            increment(
                &mut route.nonunit_gravity_scale_body_count,
                "QSDK_R24D47_GRAVITY_SCALE_BODY_COUNT_OVERFLOW",
            )?;
        }
        if body.user_force() != Default::default() {
            increment(
                &mut route.nonzero_user_force_body_count,
                "QSDK_R24D47_USER_FORCE_BODY_COUNT_OVERFLOW",
            )?;
        }
        if body.user_torque() != Default::default() {
            increment(
                &mut route.nonzero_user_torque_body_count,
                "QSDK_R24D47_USER_TORQUE_BODY_COUNT_OVERFLOW",
            )?;
        }
        if body.gyroscopic_forces_enabled() {
            increment(
                &mut route.gyroscopic_force_body_count,
                "QSDK_R24D47_GYROSCOPIC_BODY_COUNT_OVERFLOW",
            )?;
        }
        let activation = body.activation();
        if activation.normalized_linear_threshold != -1.0 || activation.angular_threshold != -1.0 {
            increment(
                &mut route.sleeping_enabled_dynamic_body_count,
                "QSDK_R24D47_SLEEPING_BODY_COUNT_OVERFLOW",
            )?;
        }
    }
    Ok(route)
}

pub(crate) fn collect_r24d47_rapier_energy_exchange_v1(
    telemetry: SporeSporeEnergyExchangeTelemetry,
    motor_samples: &[RapierMotorWorkSampleV1],
    previous_sequence: u64,
    route: RapierEnergyExchangeRouteCapabilityV1,
) -> Result<RapierEnergyExchangeSampleV1, String> {
    validate_route_capability(route)?;
    let expected_sequence = previous_sequence
        .checked_add(1)
        .ok_or_else(|| "QSDK_R24D47_EXPECTED_SEQUENCE_OVERFLOW".to_owned())?;
    if telemetry.sequence != expected_sequence {
        return Err(format!(
            "QSDK_R24D47_TELEMETRY_SEQUENCE_INVALID:expected={expected_sequence}:observed={}",
            telemetry.sequence
        ));
    }

    let (small_steps, joint_phases, contact_phases, constraint_phases) = expected_phase_counts()?;
    if telemetry.small_step_count != small_steps
        || telemetry.joint_phase_count != joint_phases
        || telemetry.contact_phase_count != contact_phases
        || telemetry.contact_warmstart_phase_count != small_steps
        || telemetry.constraint_phase_count != constraint_phases
        || telemetry.island_solve_count != EXPECTED_ISLAND_SOLVE_COUNT
        || telemetry.ccd_substep_count != EXPECTED_CCD_SUBSTEP_COUNT
        || telemetry.active_body_observation_count != EXPECTED_DYNAMIC_BODY_COUNT
    {
        return Err("QSDK_R24D47_PHASE_COUNTER_IDENTITY_INVALID".to_owned());
    }
    if telemetry.non_dynamic_body_count != 0
        || telemetry.locked_axis_body_count != 0
        || telemetry.nonzero_linear_damping_body_count != 0
        || telemetry.nonzero_angular_damping_body_count != 0
        || telemetry.nonunit_gravity_scale_body_count != 0
        || telemetry.nonzero_user_force_body_count != 0
        || telemetry.nonzero_user_torque_body_count != 0
        || telemetry.gyroscopic_force_body_count != 0
    {
        return Err("QSDK_R24D47_ENGINE_ROUTE_CAPABILITY_INVALID".to_owned());
    }
    if telemetry.multibody_link_body_count != 0
        || telemetry.multibody_root_count != 0
        || telemetry.generic_solver_dof_count != 0
    {
        return Err("QSDK_R24D47_GENERIC_OR_MULTIBODY_ROUTE_UNSUPPORTED".to_owned());
    }
    if motor_samples.len() != EXPECTED_IMPULSE_JOINT_COUNT as usize {
        return Err("QSDK_R24D47_MOTOR_SAMPLE_COUNT_INVALID".to_owned());
    }

    let mut supplied_work_j = 0.0;
    let mut absorbed_work_j = 0.0;
    let mut net_motor_work_j = 0.0;
    for sample in motor_samples {
        if sample.sequence != expected_sequence
            || sample.small_step_count != small_steps
            || sample.application_count != joint_phases
        {
            return Err("QSDK_R24D47_MOTOR_SEQUENCE_OR_COUNTER_INVALID".to_owned());
        }
        supplied_work_j = finite(
            supplied_work_j + sample.supplied_work_j,
            "QSDK_R24D47_MOTOR_WORK_NONFINITE",
        )?;
        absorbed_work_j = finite(
            absorbed_work_j + sample.absorbed_work_j,
            "QSDK_R24D47_MOTOR_WORK_NONFINITE",
        )?;
        net_motor_work_j = finite(
            net_motor_work_j + sample.net_work_j,
            "QSDK_R24D47_MOTOR_WORK_NONFINITE",
        )?;
    }

    let total_exchange_j = finite(
        f64::from(telemetry.total_constraint_exchange_j),
        "QSDK_R24D47_PHASE_EXCHANGE_NONFINITE",
    )?;
    let joint_exchange_j = finite(
        f64::from(telemetry.joint_constraint_exchange_j),
        "QSDK_R24D47_PHASE_EXCHANGE_NONFINITE",
    )?;
    let contact_exchange_j = finite(
        f64::from(telemetry.contact_constraint_exchange_j),
        "QSDK_R24D47_PHASE_EXCHANGE_NONFINITE",
    )?;
    let warmstart_exchange_j = finite(
        f64::from(telemetry.contact_warmstart_exchange_j),
        "QSDK_R24D47_PHASE_EXCHANGE_NONFINITE",
    )?;
    let scale = total_exchange_j.abs()
        + joint_exchange_j.abs()
        + contact_exchange_j.abs()
        + warmstart_exchange_j.abs()
        + 1.0;
    let consistency_bound = accumulation_consistency_bound(constraint_phases, scale)?;
    if (total_exchange_j - (joint_exchange_j + contact_exchange_j)).abs() > consistency_bound {
        return Err("QSDK_R24D47_PHASE_PARTITION_INVALID".to_owned());
    }

    let nonmotor_joint_exchange_j = finite(
        joint_exchange_j - net_motor_work_j,
        "QSDK_R24D47_NONMOTOR_EXCHANGE_NONFINITE",
    )?;
    let signed_constraint_exchange_j = finite(
        nonmotor_joint_exchange_j + contact_exchange_j,
        "QSDK_R24D47_CONSTRAINT_EXCHANGE_NONFINITE",
    )?;
    if (net_motor_work_j + signed_constraint_exchange_j - total_exchange_j).abs()
        > consistency_bound
    {
        return Err("QSDK_R24D47_CONSTRAINT_PARTITION_INVALID".to_owned());
    }

    Ok(RapierEnergyExchangeSampleV1 {
        sequence: telemetry.sequence,
        motor_supplied_work_j: supplied_work_j,
        motor_absorbed_work_j: absorbed_work_j,
        motor_net_work_j: net_motor_work_j,
        joint_phase_exchange_j: joint_exchange_j,
        nonmotor_joint_and_stabilization_exchange_j: nonmotor_joint_exchange_j,
        contact_and_friction_exchange_j: contact_exchange_j,
        contact_warmstart_exchange_j: warmstart_exchange_j,
        signed_constraint_exchange_j,
        signed_external_work_j: 0.0,
        passive_dissipation_j: 0.0,
        phase_partition_consistency_bound_j: consistency_bound,
        constraint_phase_count: constraint_phases,
        joint_phase_count: joint_phases,
        contact_phase_count: contact_phases,
        contact_warmstart_phase_count: small_steps,
        small_step_count: small_steps,
        motor_count: EXPECTED_IMPULSE_JOINT_COUNT,
        source_measurement: true,
    })
}

pub fn collect_r24d47_rapier_world_energy_exchange_v1(
    world: &PhysicsWorld,
    ordered_actuator_joint_handles: &[ImpulseJointHandle],
    previous_sequence: u64,
    external_impulse_application_count: u32,
    external_intervention_count: u32,
) -> Result<RapierEnergyExchangeSampleV1, String> {
    if ordered_actuator_joint_handles.len() != world.impulse_joints.len() {
        return Err("QSDK_R24D47_ACTUATOR_JOINT_HANDLE_POPULATION_INVALID".to_owned());
    }
    let (small_steps, joint_phases, _, _) = expected_phase_counts()?;
    let mut motor_samples = Vec::with_capacity(ordered_actuator_joint_handles.len());
    for (index, handle) in ordered_actuator_joint_handles.iter().enumerate() {
        if ordered_actuator_joint_handles[..index].contains(handle) {
            return Err("QSDK_R24D47_ACTUATOR_JOINT_HANDLE_DUPLICATE".to_owned());
        }
        let motor = world
            .impulse_joints
            .get(*handle)
            .and_then(|joint| joint.data.as_revolute())
            .and_then(|joint| joint.motor())
            .ok_or_else(|| "QSDK_R24D47_ACTUATOR_MOTOR_MISSING".to_owned())?;
        motor_samples.push(collect_r24d46_rapier_motor_work_v1(
            motor,
            previous_sequence,
            small_steps,
            joint_phases,
        )?);
    }
    let route = observe_route_capability(
        world,
        external_impulse_application_count,
        external_intervention_count,
    )?;
    collect_r24d47_rapier_energy_exchange_v1(
        world.physics_pipeline.sporespore_energy_exchange,
        &motor_samples,
        previous_sequence,
        route,
    )
}

fn fixture_motor_samples() -> Result<Vec<RapierMotorWorkSampleV1>, String> {
    let (small_steps, joint_phases, _, _) = expected_phase_counts()?;
    (0..EXPECTED_IMPULSE_JOINT_COUNT)
        .map(|_| {
            let mut motor = JointMotor::default();
            motor.sporespore_solver_work.sequence = 1;
            motor.sporespore_solver_work.generalized_impulse = 0.25;
            motor.sporespore_solver_work.absolute_generalized_impulse = 0.25;
            motor.sporespore_solver_work.supplied_work = 0.2;
            motor.sporespore_solver_work.absorbed_work = 0.075;
            motor.sporespore_solver_work.net_work = 0.125;
            motor.sporespore_solver_work.application_count = joint_phases;
            motor.sporespore_solver_work.small_step_count = small_steps;
            collect_r24d46_rapier_motor_work_v1(&motor, 0, small_steps, joint_phases)
        })
        .collect()
}

fn fixture_phase_telemetry() -> Result<SporeSporeEnergyExchangeTelemetry, String> {
    let (small_steps, joint_phases, contact_phases, constraint_phases) = expected_phase_counts()?;
    Ok(SporeSporeEnergyExchangeTelemetry {
        sequence: 1,
        total_constraint_exchange_j: 1.5,
        joint_constraint_exchange_j: 2.0,
        contact_constraint_exchange_j: -0.5,
        contact_warmstart_exchange_j: -0.1,
        constraint_phase_count: constraint_phases,
        joint_phase_count: joint_phases,
        contact_phase_count: contact_phases,
        contact_warmstart_phase_count: small_steps,
        small_step_count: small_steps,
        island_solve_count: EXPECTED_ISLAND_SOLVE_COUNT,
        ccd_substep_count: EXPECTED_CCD_SUBSTEP_COUNT,
        active_body_observation_count: EXPECTED_DYNAMIC_BODY_COUNT,
        ..Default::default()
    })
}

fn expect_rejection(
    telemetry: SporeSporeEnergyExchangeTelemetry,
    motors: &[RapierMotorWorkSampleV1],
    route: RapierEnergyExchangeRouteCapabilityV1,
    mutation_id: &str,
    expected_code: &str,
) -> Result<Value, String> {
    let error = collect_r24d47_rapier_energy_exchange_v1(telemetry, motors, 0, route)
        .expect_err("R24D47 mutation control unexpectedly passed");
    if !error.starts_with(expected_code) {
        return Err(format!(
            "QSDK_R24D47_MUTATION_WRONG_ERROR:expected={expected_code}:observed={error}"
        ));
    }
    Ok(json!({
        "mutation_id": mutation_id,
        "expected_error": expected_code,
        "observed_error": error,
    }))
}

pub fn run_qsdk_r24d47_rapier_energy_exchange_zero_world_qualification() -> Result<Value, String> {
    let telemetry = fixture_phase_telemetry()?;
    let motors = fixture_motor_samples()?;
    let route = RapierEnergyExchangeRouteCapabilityV1::exact_supported_fixture();
    let accepted = collect_r24d47_rapier_energy_exchange_v1(telemetry, &motors, 0, route)?;

    let mut stale = telemetry;
    stale.sequence = 0;
    let mut wrong_count = telemetry;
    wrong_count.joint_phase_count -= 1;
    let mut nonfinite = telemetry;
    nonfinite.total_constraint_exchange_j = f32::NAN;
    let mut stale_motors = motors.clone();
    stale_motors[0].sequence = 0;
    let mut bad_partition = telemetry;
    bad_partition.total_constraint_exchange_j = 1.75;
    let mut external = route;
    external.nonzero_user_force_body_count = 1;
    let mut damping = route;
    damping.nonzero_linear_damping_body_count = 1;
    let mut kinematic = route;
    kinematic.kinematic_body_count = 1;
    let mut locked = route;
    locked.locked_axis_body_count = 1;
    let mut multibody = route;
    multibody.multibody_joint_count = 1;
    let mut ccd = route;
    ccd.maximum_ccd_substeps = 2;
    let mut solver_configuration = route;
    solver_configuration.internal_pgs_iterations_per_small_step += 1;
    let mut sleeping = route;
    sleeping.sleeping_enabled_dynamic_body_count = 1;

    let mutations = vec![
        expect_rejection(
            stale,
            &motors,
            route,
            "stale_telemetry_sequence",
            "QSDK_R24D47_TELEMETRY_SEQUENCE_INVALID",
        )?,
        expect_rejection(
            wrong_count,
            &motors,
            route,
            "wrong_solver_phase_count",
            "QSDK_R24D47_PHASE_COUNTER_IDENTITY_INVALID",
        )?,
        expect_rejection(
            nonfinite,
            &motors,
            route,
            "nonfinite_phase_exchange",
            "QSDK_R24D47_PHASE_EXCHANGE_NONFINITE",
        )?,
        expect_rejection(
            telemetry,
            &stale_motors,
            route,
            "stale_motor_sequence",
            "QSDK_R24D47_MOTOR_SEQUENCE_OR_COUNTER_INVALID",
        )?,
        expect_rejection(
            bad_partition,
            &motors,
            route,
            "inconsistent_total_partition",
            "QSDK_R24D47_PHASE_PARTITION_INVALID",
        )?,
        expect_rejection(
            telemetry,
            &motors,
            external,
            "nonzero_user_force",
            "QSDK_R24D47_EXPLICIT_EXTERNAL_WORK_NOT_ZERO",
        )?,
        expect_rejection(
            telemetry,
            &motors,
            damping,
            "nonzero_linear_damping",
            "QSDK_R24D47_PASSIVE_ZERO_CAPABILITY_INVALID",
        )?,
        expect_rejection(
            telemetry,
            &motors,
            kinematic,
            "kinematic_body",
            "QSDK_R24D47_KINEMATIC_ROUTE_UNSUPPORTED",
        )?,
        expect_rejection(
            telemetry,
            &motors,
            locked,
            "locked_axis",
            "QSDK_R24D47_LOCKED_AXIS_ROUTE_UNSUPPORTED",
        )?,
        expect_rejection(
            telemetry,
            &motors,
            multibody,
            "multibody_joint",
            "QSDK_R24D47_MULTIBODY_ROUTE_UNSUPPORTED",
        )?,
        expect_rejection(
            telemetry,
            &motors,
            ccd,
            "multiple_ccd_substeps",
            "QSDK_R24D47_CCD_ROUTE_UNSUPPORTED",
        )?,
        expect_rejection(
            telemetry,
            &motors,
            solver_configuration,
            "solver_configuration_drift",
            "QSDK_R24D47_SOLVER_CONFIGURATION_UNSUPPORTED",
        )?,
        expect_rejection(
            telemetry,
            &motors,
            sleeping,
            "sleeping_enabled",
            "QSDK_R24D47_PASSIVE_ZERO_CAPABILITY_INVALID",
        )?,
    ];
    let mutation_ids = mutations
        .iter()
        .map(|mutation| mutation["mutation_id"].clone())
        .collect::<Vec<_>>();
    let mutation_count = mutations.len();
    let check_count = mutation_count + 1;

    Ok(json!({
        "schema_version":
            "sporespore_qsdk_r24d47_rapier_energy_exchange_zero_world_qualification_v1",
        "ok": true,
        "gate_id": R24D47_GATE_ID,
        "question_class": "development",
        "qualification_class": "zero_world_scalar_solver_phase_energy_exchange",
        "patch_feature": R24D47_PATCH_FEATURE,
        "rule_id": R24D47_ENERGY_RULE_ID,
        "accepted_fixture": accepted.to_json(),
        "route_capability_fixture": route.to_json(),
        "mutation_ids": mutation_ids,
        "mutation_rejections": mutations,
        "mutation_rejection_count": mutation_count,
        "check_count": check_count,
        "checks_passed": check_count,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": false,
        "physical_question_opened": false,
        "physical_acceptance_authority": false,
        "prone_to_standing_claimed": false,
        "sdk1_milestone_advanced": false,
        "release_authority": false,
    }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn zero_world_qualification_accepts_partition_and_rejects_mutations() {
        let receipt = run_qsdk_r24d47_rapier_energy_exchange_zero_world_qualification().unwrap();
        assert_eq!(receipt["ok"], true);
        assert_eq!(receipt["checks_passed"], 14);
        assert_eq!(receipt["world_build_count"], 0);
    }
}
