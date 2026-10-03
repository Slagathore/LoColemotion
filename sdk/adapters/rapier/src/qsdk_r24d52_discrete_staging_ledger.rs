//! QSDK-R24D52 native discrete-staging collector and portable V3 ledger mapping.
//!
//! This module only translates already-produced telemetry and evaluates pure
//! zero-world fixtures. The actual sampling sites live in the pinned Rapier
//! delta; this module constructs no body, joint, collider, or physics world.

use rapier3d::pipeline::{
    PhysicsWorld, SPORESPORE_DISCRETE_STAGING_SMALL_STEP_CAPACITY,
    SporeSporeDiscreteStagingTelemetry,
};
use serde_json::{Value, json};
use sporespore_locomotion_core::{
    RECOVERY_ENERGY_BALANCE_AGGREGATION_REQUEST_V3_VERSION,
    RecoveryEnergyBalanceAggregationRequestV3, RecoveryEnergyWorkIncrementV3,
    aggregate_recovery_energy_balance_v3,
};

use crate::qsdk_r24d47_energy_exchange_observer::RapierEnergyExchangeSampleV1;
use crate::qsdk_r24d51_discrete_staging_observer::{
    R24D51_EXPECTED_SMALL_STEP_COUNT, RapierDiscreteStagingExchangeV1,
    RapierDiscreteStagingSmallStepV1, RapierEndpointHalfStepProjectionV1,
    measure_r24d51_rapier_discrete_staging_exchange_v1,
    run_qsdk_r24d51_rapier_discrete_staging_zero_world_qualification,
};

pub const R24D52_GATE_ID: &str = "QSDK-R24D52";
pub const R24D52_STAGING_LEDGER_MAPPING_PROFILE_ID: &str =
    "rapier_r24d52_native_discrete_staging_energy_v3_mapping_v1";

const EXPECTED_ISLAND_SOLVE_COUNT: u32 = 1;
const EXPECTED_CCD_SUBSTEP_COUNT: u32 = 1;
const EXPECTED_DYNAMIC_BODY_COUNT: u32 = 9;

fn collect_error(
    id: &str,
    result: Result<RapierDiscreteStagingExchangeV1, String>,
    expected: &str,
) -> Result<Value, String> {
    match result {
        Err(error) if error.starts_with(expected) => Ok(json!({
            "mutation_id": id,
            "expected_code": expected,
            "observed_code": error,
            "rejected": true,
        })),
        Err(error) => Err(format!("QSDK_R24D52_MUTATION_WRONG_REFUSAL:{id}:{error}")),
        Ok(_) => Err(format!("QSDK_R24D52_MUTATION_ACCEPTED:{id}")),
    }
}

pub fn collect_r24d52_rapier_discrete_staging_v1(
    telemetry: SporeSporeDiscreteStagingTelemetry,
    previous_sequence: u64,
) -> Result<RapierDiscreteStagingExchangeV1, String> {
    if telemetry.small_step_count != R24D51_EXPECTED_SMALL_STEP_COUNT
        || telemetry.small_step_count as usize != SPORESPORE_DISCRETE_STAGING_SMALL_STEP_CAPACITY
        || telemetry.overflow_small_step_count != 0
    {
        return Err("QSDK_R24D52_NATIVE_SMALL_STEP_POPULATION_INVALID".to_owned());
    }
    if telemetry.island_solve_count != EXPECTED_ISLAND_SOLVE_COUNT
        || telemetry.ccd_substep_count != EXPECTED_CCD_SUBSTEP_COUNT
    {
        return Err("QSDK_R24D52_NATIVE_SOLVER_ROUTE_INVALID".to_owned());
    }
    if telemetry.endpoint_body_count_before != EXPECTED_DYNAMIC_BODY_COUNT
        || telemetry.endpoint_body_count_after != EXPECTED_DYNAMIC_BODY_COUNT
    {
        return Err("QSDK_R24D52_ENDPOINT_BODY_POPULATION_INVALID".to_owned());
    }

    let small_steps = telemetry
        .small_steps
        .iter()
        .map(|sample| RapierDiscreteStagingSmallStepV1 {
            small_step_index: sample.small_step_index,
            kinetic_energy_before_force_j: f64::from(sample.kinetic_energy_before_force_j),
            kinetic_energy_after_force_j: f64::from(sample.kinetic_energy_after_force_j),
            raw_gravity_potential_before_position_j: f64::from(
                sample.raw_gravity_potential_before_position_j,
            ),
            raw_gravity_potential_after_position_j: f64::from(
                sample.raw_gravity_potential_after_position_j,
            ),
            source_measurement: sample.source_measurement,
        })
        .collect::<Vec<_>>();
    measure_r24d51_rapier_discrete_staging_exchange_v1(
        telemetry.sequence,
        previous_sequence,
        &small_steps,
        RapierEndpointHalfStepProjectionV1 {
            before_outer_step_j: f64::from(telemetry.endpoint_half_step_projection_before_j),
            after_outer_step_j: f64::from(telemetry.endpoint_half_step_projection_after_j),
            source_measurement: telemetry.endpoint_source_measurement,
        },
    )
}

pub fn collect_r24d52_rapier_world_discrete_staging_v1(
    world: &PhysicsWorld,
    previous_sequence: u64,
) -> Result<RapierDiscreteStagingExchangeV1, String> {
    collect_r24d52_rapier_discrete_staging_v1(
        world.physics_pipeline.sporespore_discrete_staging,
        previous_sequence,
    )
}

pub fn map_r24d52_recovery_energy_increment_v3(
    energy: RapierEnergyExchangeSampleV1,
    staging: RapierDiscreteStagingExchangeV1,
    semantic_step: u64,
) -> Result<RecoveryEnergyWorkIncrementV3, String> {
    if semantic_step == 0
        || energy.sequence != semantic_step
        || staging.sequence != semantic_step
        || !energy.source_measurement
        || !staging.source_measurement
    {
        return Err("QSDK_R24D52_NATIVE_SOURCE_IDENTITY_INVALID".to_owned());
    }
    for value in [
        energy.motor_net_work_j,
        energy.signed_external_work_j,
        energy.signed_constraint_exchange_j,
        staging.signed_discrete_staging_exchange_j,
        energy.passive_dissipation_j,
    ] {
        if !value.is_finite() {
            return Err("QSDK_R24D52_NATIVE_ENERGY_COMPONENT_NONFINITE".to_owned());
        }
    }
    if energy.passive_dissipation_j < 0.0 {
        return Err("QSDK_R24D52_PASSIVE_DISSIPATION_NEGATIVE".to_owned());
    }
    Ok(RecoveryEnergyWorkIncrementV3 {
        sequence_index: energy.sequence,
        semantic_step,
        applied_actuator_work_j: energy.motor_net_work_j,
        signed_external_work_j: energy.signed_external_work_j,
        signed_constraint_exchange_j: energy.signed_constraint_exchange_j,
        signed_discrete_staging_exchange_j: staging.signed_discrete_staging_exchange_j,
        passive_dissipation_j: energy.passive_dissipation_j,
        source_measurement: true,
    })
}

fn native_fixture() -> SporeSporeDiscreteStagingTelemetry {
    let mut telemetry = SporeSporeDiscreteStagingTelemetry {
        sequence: 1,
        small_step_count: R24D51_EXPECTED_SMALL_STEP_COUNT,
        island_solve_count: EXPECTED_ISLAND_SOLVE_COUNT,
        ccd_substep_count: EXPECTED_CCD_SUBSTEP_COUNT,
        endpoint_half_step_projection_before_j: 1.0,
        endpoint_half_step_projection_after_j: 0.5,
        endpoint_body_count_before: EXPECTED_DYNAMIC_BODY_COUNT,
        endpoint_body_count_after: EXPECTED_DYNAMIC_BODY_COUNT,
        endpoint_source_measurement: true,
        ..Default::default()
    };
    for (index, sample) in telemetry.small_steps.iter_mut().enumerate() {
        sample.small_step_index = u32::try_from(index).unwrap_or(u32::MAX);
        sample.kinetic_energy_before_force_j = index as f32;
        sample.kinetic_energy_after_force_j = index as f32 + 0.25;
        sample.raw_gravity_potential_before_position_j = 100.0 - index as f32;
        sample.raw_gravity_potential_after_position_j = 99.875 - index as f32;
        sample.source_measurement = true;
    }
    telemetry
}

fn energy_fixture() -> RapierEnergyExchangeSampleV1 {
    RapierEnergyExchangeSampleV1 {
        sequence: 1,
        motor_supplied_work_j: 2.0,
        motor_absorbed_work_j: 0.0,
        motor_net_work_j: 2.0,
        joint_phase_exchange_j: -0.25,
        nonmotor_joint_and_stabilization_exchange_j: 0.0,
        contact_and_friction_exchange_j: 0.0,
        contact_warmstart_exchange_j: 0.0,
        signed_constraint_exchange_j: -0.25,
        signed_external_work_j: 0.0,
        passive_dissipation_j: 0.5,
        phase_partition_consistency_bound_j: 0.0,
        constraint_phase_count: 0,
        joint_phase_count: 0,
        contact_phase_count: 0,
        contact_warmstart_phase_count: 0,
        small_step_count: R24D51_EXPECTED_SMALL_STEP_COUNT,
        motor_count: 8,
        source_measurement: true,
    }
}

pub fn run_qsdk_r24d52_rapier_discrete_staging_ledger_zero_world_qualification()
-> Result<Value, String> {
    let inherited = run_qsdk_r24d51_rapier_discrete_staging_zero_world_qualification()?;
    if inherited["ok"] != true || inherited["check_count"] != 13 {
        return Err("QSDK_R24D52_INHERITED_R51_CONTROL_INVALID".to_owned());
    }

    let telemetry = native_fixture();
    let staging = collect_r24d52_rapier_discrete_staging_v1(telemetry, 0)?;
    let energy = energy_fixture();
    let increment = map_r24d52_recovery_energy_increment_v3(energy, staging, 1)?;
    let expected_current = 10.0
        + increment.applied_actuator_work_j
        + increment.signed_external_work_j
        + increment.signed_constraint_exchange_j
        + increment.signed_discrete_staging_exchange_j
        - increment.passive_dissipation_j;
    let aggregate =
        aggregate_recovery_energy_balance_v3(RecoveryEnergyBalanceAggregationRequestV3 {
            schema_version: RECOVERY_ENERGY_BALANCE_AGGREGATION_REQUEST_V3_VERSION.to_owned(),
            source_profile_id: R24D52_STAGING_LEDGER_MAPPING_PROFILE_ID.to_owned(),
            initial_mechanical_energy_j: 10.0,
            current_mechanical_energy_j: expected_current,
            ordered_increments: vec![increment],
        })
        .map_err(|error| format!("QSDK_R24D52_V3_AGGREGATION:{error}"))?;

    let mut omitted = increment;
    omitted.signed_discrete_staging_exchange_j = 0.0;
    let omission_control =
        aggregate_recovery_energy_balance_v3(RecoveryEnergyBalanceAggregationRequestV3 {
            schema_version: RECOVERY_ENERGY_BALANCE_AGGREGATION_REQUEST_V3_VERSION.to_owned(),
            source_profile_id: R24D52_STAGING_LEDGER_MAPPING_PROFILE_ID.to_owned(),
            initial_mechanical_energy_j: 10.0,
            current_mechanical_energy_j: expected_current,
            ordered_increments: vec![omitted],
        })
        .map_err(|error| format!("QSDK_R24D52_OMISSION_CONTROL:{error}"))?;

    let controls = [
        inherited["ok"] == true,
        staging.force_integration_kinetic_exchange_j == 4.0
            && staging.raw_gravity_potential_position_exchange_j == -2.0
            && staging.endpoint_half_step_projection_exchange_j == -0.5
            && staging.signed_discrete_staging_exchange_j == 1.5,
        aggregate
            .ledger
            .cumulative_signed_discrete_staging_exchange_j
            == 1.5
            && aggregate.ledger.cumulative_signed_external_work_j == 0.0
            && aggregate.ledger.cumulative_passive_dissipation_j == 0.5,
        aggregate.evaluation.signed_residual_j == 0.0
            && !aggregate.evaluation.threshold_applied
            && !aggregate.evaluation.physical_result,
        omission_control.evaluation.signed_residual_j == 1.5,
        aggregate.world_build_count == 0
            && aggregate.solver_step_count == 0
            && !aggregate.physics_state_modified
            && !aggregate.physical_acceptance_authority
            && !aggregate.release_authority,
    ];
    if controls.iter().any(|passed| !passed) {
        return Err("QSDK_R24D52_ZERO_WORLD_CONTROL_FAILED".to_owned());
    }

    let mut stale = telemetry;
    stale.sequence = 0;
    let mut short = telemetry;
    short.small_step_count = 15;
    let mut overflow = telemetry;
    overflow.overflow_small_step_count = 1;
    let mut islands = telemetry;
    islands.island_solve_count = 2;
    let mut ccd = telemetry;
    ccd.ccd_substep_count = 2;
    let mut body_population = telemetry;
    body_population.endpoint_body_count_after = 8;
    let mut endpoint_source = telemetry;
    endpoint_source.endpoint_source_measurement = false;
    let mut step_source = telemetry;
    step_source.small_steps[0].source_measurement = false;
    let mut nonfinite = telemetry;
    nonfinite.small_steps[0].kinetic_energy_after_force_j = f32::NAN;
    let mut reordered = telemetry;
    reordered.small_steps.swap(2, 3);

    let mut mutations = vec![
        collect_error(
            "stale_sequence",
            collect_r24d52_rapier_discrete_staging_v1(stale, 0),
            "QSDK_R24D51_SEQUENCE_INVALID",
        )?,
        collect_error(
            "short_small_step_population",
            collect_r24d52_rapier_discrete_staging_v1(short, 0),
            "QSDK_R24D52_NATIVE_SMALL_STEP_POPULATION_INVALID",
        )?,
        collect_error(
            "native_small_step_overflow",
            collect_r24d52_rapier_discrete_staging_v1(overflow, 0),
            "QSDK_R24D52_NATIVE_SMALL_STEP_POPULATION_INVALID",
        )?,
        collect_error(
            "multiple_island_solves",
            collect_r24d52_rapier_discrete_staging_v1(islands, 0),
            "QSDK_R24D52_NATIVE_SOLVER_ROUTE_INVALID",
        )?,
        collect_error(
            "multiple_ccd_substeps",
            collect_r24d52_rapier_discrete_staging_v1(ccd, 0),
            "QSDK_R24D52_NATIVE_SOLVER_ROUTE_INVALID",
        )?,
        collect_error(
            "endpoint_body_population_drift",
            collect_r24d52_rapier_discrete_staging_v1(body_population, 0),
            "QSDK_R24D52_ENDPOINT_BODY_POPULATION_INVALID",
        )?,
        collect_error(
            "endpoint_not_source_measured",
            collect_r24d52_rapier_discrete_staging_v1(endpoint_source, 0),
            "QSDK_R24D51_ENDPOINT_NOT_SOURCE_MEASURED",
        )?,
        collect_error(
            "small_step_not_source_measured",
            collect_r24d52_rapier_discrete_staging_v1(step_source, 0),
            "QSDK_R24D51_SMALL_STEP_NOT_SOURCE_MEASURED",
        )?,
        collect_error(
            "native_force_boundary_nonfinite",
            collect_r24d52_rapier_discrete_staging_v1(nonfinite, 0),
            "QSDK_R24D51_FORCE_BOUNDARY_NONFINITE",
        )?,
        collect_error(
            "native_small_step_reordered",
            collect_r24d52_rapier_discrete_staging_v1(reordered, 0),
            "QSDK_R24D51_SMALL_STEP_ORDER_INVALID",
        )?,
    ];
    let mut wrong_energy_sequence = energy;
    wrong_energy_sequence.sequence = 2;
    let mapping_error = map_r24d52_recovery_energy_increment_v3(wrong_energy_sequence, staging, 1)
        .expect_err("mismatched native sequences must be rejected");
    if !mapping_error.starts_with("QSDK_R24D52_NATIVE_SOURCE_IDENTITY_INVALID") {
        return Err(format!(
            "QSDK_R24D52_MUTATION_WRONG_REFUSAL:energy_sequence_mismatch:{mapping_error}"
        ));
    }
    mutations.push(json!({
        "mutation_id": "energy_sequence_mismatch",
        "expected_code": "QSDK_R24D52_NATIVE_SOURCE_IDENTITY_INVALID",
        "observed_code": mapping_error,
        "rejected": true,
    }));
    let mutation_ids = mutations
        .iter()
        .map(|mutation| mutation["mutation_id"].clone())
        .collect::<Vec<_>>();

    Ok(json!({
        "schema_version":
            "sporespore_qsdk_r24d52_rapier_discrete_staging_ledger_zero_world_qualification_v1",
        "ok": true,
        "gate_id": R24D52_GATE_ID,
        "question_class": "development",
        "qualification_class": "zero_world_native_boundary_telemetry_and_portable_v3_ledger",
        "native_patch_feature": "sporespore-discrete-staging-telemetry",
        "adapter_feature": "sporespore-rapier-discrete-staging",
        "mapping_profile_id": R24D52_STAGING_LEDGER_MAPPING_PROFILE_ID,
        "control_count": controls.len(),
        "controls_passed": controls.len(),
        "mutation_ids": mutation_ids,
        "mutation_rejections": mutations,
        "mutation_rejection_count": 11,
        "check_count": controls.len() + 11,
        "checks_passed": controls.len() + 11,
        "inherited_r51_check_count": inherited["check_count"],
        "native_boundary_telemetry_implemented": true,
        "engine_neutral_staging_ledger_v3_implemented": true,
        "staging_mapped_to_external_work": false,
        "staging_mapped_to_passive_dissipation": false,
        "mechanical_energy_change_used_as_work_source": false,
        "energy_balance_residual_used_as_work_source": false,
        "threshold_applied": false,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": false,
        "physical_question_opened": false,
        "prone_to_standing_claimed": false,
        "sdk1_milestone_advanced": false,
        "physical_acceptance_authority": false,
        "release_authority": false,
    }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn zero_world_native_mapping_and_v3_ledger_gate_passes() {
        let receipt =
            run_qsdk_r24d52_rapier_discrete_staging_ledger_zero_world_qualification().unwrap();
        assert_eq!(receipt["ok"], true);
        assert_eq!(receipt["checks_passed"], 17);
        assert_eq!(receipt["world_build_count"], 0);
    }
}
