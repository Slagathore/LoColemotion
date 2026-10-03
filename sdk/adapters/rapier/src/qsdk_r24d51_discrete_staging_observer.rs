use serde_json::{Value, json};

pub const R24D51_GATE_ID: &str = "QSDK-R24D51";
pub const R24D51_STAGING_RULE_ID: &str =
    "rapier_discrete_force_position_half_step_staging_exchange_v1";
pub const R24D51_EXPECTED_SMALL_STEP_COUNT: u32 = 16;
const R24D51_BINARY64_CONTROL_OPERATION_BUDGET: u32 = R24D51_EXPECTED_SMALL_STEP_COUNT * 64;

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct RapierDiscreteStagingSmallStepV1 {
    pub small_step_index: u32,
    pub kinetic_energy_before_force_j: f64,
    pub kinetic_energy_after_force_j: f64,
    pub raw_gravity_potential_before_position_j: f64,
    pub raw_gravity_potential_after_position_j: f64,
    pub source_measurement: bool,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct RapierEndpointHalfStepProjectionV1 {
    pub before_outer_step_j: f64,
    pub after_outer_step_j: f64,
    pub source_measurement: bool,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct RapierDiscreteStagingExchangeV1 {
    pub sequence: u64,
    pub force_integration_kinetic_exchange_j: f64,
    pub raw_gravity_potential_position_exchange_j: f64,
    pub endpoint_half_step_projection_exchange_j: f64,
    pub signed_discrete_staging_exchange_j: f64,
    pub small_step_count: u32,
    pub source_measurement: bool,
}

impl RapierDiscreteStagingExchangeV1 {
    fn to_json(self) -> Value {
        json!({
            "schema_version": "sporespore_rapier_discrete_staging_exchange_v1",
            "rule_id": R24D51_STAGING_RULE_ID,
            "sequence": self.sequence,
            "force_integration_kinetic_exchange_j":
                self.force_integration_kinetic_exchange_j,
            "raw_gravity_potential_position_exchange_j":
                self.raw_gravity_potential_position_exchange_j,
            "endpoint_half_step_projection_exchange_j":
                self.endpoint_half_step_projection_exchange_j,
            "signed_discrete_staging_exchange_j":
                self.signed_discrete_staging_exchange_j,
            "small_step_count": self.small_step_count,
            "source_measurement": self.source_measurement,
            "mechanical_energy_change_used_as_input": false,
            "energy_balance_residual_used_as_input": false,
            "acceptance_threshold_used_as_input": false,
        })
    }
}

fn finite(value: f64, code: &str) -> Result<f64, String> {
    if value.is_finite() {
        Ok(value)
    } else {
        Err(code.to_owned())
    }
}

fn add(sum: &mut f64, value: f64, code: &str) -> Result<(), String> {
    *sum = finite(*sum + value, code)?;
    Ok(())
}

pub fn measure_r24d51_rapier_discrete_staging_exchange_v1(
    sequence: u64,
    previous_sequence: u64,
    small_steps: &[RapierDiscreteStagingSmallStepV1],
    endpoint_half_step: RapierEndpointHalfStepProjectionV1,
) -> Result<RapierDiscreteStagingExchangeV1, String> {
    let expected_sequence = previous_sequence
        .checked_add(1)
        .ok_or_else(|| "QSDK_R24D51_EXPECTED_SEQUENCE_OVERFLOW".to_owned())?;
    if sequence != expected_sequence {
        return Err(format!(
            "QSDK_R24D51_SEQUENCE_INVALID:expected={expected_sequence}:observed={sequence}"
        ));
    }
    if small_steps.len() != R24D51_EXPECTED_SMALL_STEP_COUNT as usize {
        return Err("QSDK_R24D51_SMALL_STEP_POPULATION_INVALID".to_owned());
    }
    if !endpoint_half_step.source_measurement {
        return Err("QSDK_R24D51_ENDPOINT_NOT_SOURCE_MEASURED".to_owned());
    }

    let mut force_exchange = 0.0;
    let mut position_exchange = 0.0;
    for (expected_index, step) in small_steps.iter().enumerate() {
        if step.small_step_index != expected_index as u32 {
            return Err("QSDK_R24D51_SMALL_STEP_ORDER_INVALID".to_owned());
        }
        if !step.source_measurement {
            return Err("QSDK_R24D51_SMALL_STEP_NOT_SOURCE_MEASURED".to_owned());
        }
        let force_before = finite(
            step.kinetic_energy_before_force_j,
            "QSDK_R24D51_FORCE_BOUNDARY_NONFINITE",
        )?;
        let force_after = finite(
            step.kinetic_energy_after_force_j,
            "QSDK_R24D51_FORCE_BOUNDARY_NONFINITE",
        )?;
        let position_before = finite(
            step.raw_gravity_potential_before_position_j,
            "QSDK_R24D51_POSITION_BOUNDARY_NONFINITE",
        )?;
        let position_after = finite(
            step.raw_gravity_potential_after_position_j,
            "QSDK_R24D51_POSITION_BOUNDARY_NONFINITE",
        )?;
        add(
            &mut force_exchange,
            force_after - force_before,
            "QSDK_R24D51_FORCE_EXCHANGE_NONFINITE",
        )?;
        add(
            &mut position_exchange,
            position_after - position_before,
            "QSDK_R24D51_POSITION_EXCHANGE_NONFINITE",
        )?;
    }

    let endpoint_before = finite(
        endpoint_half_step.before_outer_step_j,
        "QSDK_R24D51_ENDPOINT_BOUNDARY_NONFINITE",
    )?;
    let endpoint_after = finite(
        endpoint_half_step.after_outer_step_j,
        "QSDK_R24D51_ENDPOINT_BOUNDARY_NONFINITE",
    )?;
    let endpoint_exchange = finite(
        endpoint_after - endpoint_before,
        "QSDK_R24D51_ENDPOINT_EXCHANGE_NONFINITE",
    )?;
    let signed_exchange = finite(
        force_exchange + position_exchange + endpoint_exchange,
        "QSDK_R24D51_STAGING_EXCHANGE_NONFINITE",
    )?;

    Ok(RapierDiscreteStagingExchangeV1 {
        sequence,
        force_integration_kinetic_exchange_j: force_exchange,
        raw_gravity_potential_position_exchange_j: position_exchange,
        endpoint_half_step_projection_exchange_j: endpoint_exchange,
        signed_discrete_staging_exchange_j: signed_exchange,
        small_step_count: R24D51_EXPECTED_SMALL_STEP_COUNT,
        source_measurement: true,
    })
}

#[derive(Clone)]
struct AnalyticFixtureV1 {
    steps: Vec<RapierDiscreteStagingSmallStepV1>,
    endpoint: RapierEndpointHalfStepProjectionV1,
    endpoint_energy_change_j: f64,
    independently_known_constraint_exchange_j: f64,
}

fn close(left: f64, right: f64) -> bool {
    let scale = left.abs().max(right.abs()).max(1.0);
    (left - right).abs()
        <= f64::from(R24D51_BINARY64_CONTROL_OPERATION_BUDGET) * f64::EPSILON * scale
}

fn kinetic_energy(mass_kg: f64, velocity_y_mps: f64) -> f64 {
    0.5 * mass_kg * velocity_y_mps * velocity_y_mps
}

fn raw_gravity_potential(mass_kg: f64, gravity_y_mps2: f64, com_y_m: f64) -> f64 {
    -mass_kg * gravity_y_mps2 * com_y_m
}

fn endpoint_half_step_projection(
    mass_kg: f64,
    gravity_y_mps2: f64,
    velocity_y_mps: f64,
    outer_timestep_s: f64,
) -> f64 {
    mass_kg * gravity_y_mps2 * velocity_y_mps * outer_timestep_s * 0.5
}

fn analytic_fixture(
    initial_velocity_y_mps: f64,
    gravity_y_mps2: f64,
    supported: bool,
) -> AnalyticFixtureV1 {
    let mass_kg = 4.72;
    let outer_timestep_s = 1.0 / 120.0;
    let small_timestep_s = outer_timestep_s / f64::from(R24D51_EXPECTED_SMALL_STEP_COUNT);
    let initial_com_y_m = 1.25;
    let mut velocity_y_mps = initial_velocity_y_mps;
    let mut com_y_m = initial_com_y_m;
    let mut steps = Vec::with_capacity(R24D51_EXPECTED_SMALL_STEP_COUNT as usize);
    let mut independently_known_constraint_exchange_j = 0.0;

    for small_step_index in 0..R24D51_EXPECTED_SMALL_STEP_COUNT {
        let kinetic_before = kinetic_energy(mass_kg, velocity_y_mps);
        let velocity_after_force = velocity_y_mps + gravity_y_mps2 * small_timestep_s;
        let kinetic_after = kinetic_energy(mass_kg, velocity_after_force);
        let position_velocity = if supported { 0.0 } else { velocity_after_force };
        if supported {
            independently_known_constraint_exchange_j += kinetic_before - kinetic_after;
        }
        let potential_before = raw_gravity_potential(mass_kg, gravity_y_mps2, com_y_m);
        com_y_m += position_velocity * small_timestep_s;
        let potential_after = raw_gravity_potential(mass_kg, gravity_y_mps2, com_y_m);
        steps.push(RapierDiscreteStagingSmallStepV1 {
            small_step_index,
            kinetic_energy_before_force_j: kinetic_before,
            kinetic_energy_after_force_j: kinetic_after,
            raw_gravity_potential_before_position_j: potential_before,
            raw_gravity_potential_after_position_j: potential_after,
            source_measurement: true,
        });
        velocity_y_mps = position_velocity;
    }

    let endpoint_before = endpoint_half_step_projection(
        mass_kg,
        gravity_y_mps2,
        initial_velocity_y_mps,
        outer_timestep_s,
    );
    let endpoint_after =
        endpoint_half_step_projection(mass_kg, gravity_y_mps2, velocity_y_mps, outer_timestep_s);
    let initial_endpoint_energy = kinetic_energy(mass_kg, initial_velocity_y_mps)
        + raw_gravity_potential(mass_kg, gravity_y_mps2, initial_com_y_m)
        + endpoint_before;
    let final_endpoint_energy = kinetic_energy(mass_kg, velocity_y_mps)
        + raw_gravity_potential(mass_kg, gravity_y_mps2, com_y_m)
        + endpoint_after;

    AnalyticFixtureV1 {
        steps,
        endpoint: RapierEndpointHalfStepProjectionV1 {
            before_outer_step_j: endpoint_before,
            after_outer_step_j: endpoint_after,
            source_measurement: true,
        },
        endpoint_energy_change_j: final_endpoint_energy - initial_endpoint_energy,
        independently_known_constraint_exchange_j,
    }
}

fn reject(
    mutation_id: &str,
    steps: &[RapierDiscreteStagingSmallStepV1],
    endpoint: RapierEndpointHalfStepProjectionV1,
    expected_code: &str,
) -> Result<Value, String> {
    match measure_r24d51_rapier_discrete_staging_exchange_v1(1, 0, steps, endpoint) {
        Ok(_) => Err(format!("QSDK_R24D51_MUTATION_ACCEPTED:{mutation_id}")),
        Err(error) if error.starts_with(expected_code) => Ok(json!({
            "mutation_id": mutation_id,
            "expected_code": expected_code,
            "observed_code": error,
            "rejected": true,
        })),
        Err(error) => Err(format!(
            "QSDK_R24D51_MUTATION_WRONG_REFUSAL:{mutation_id}:{error}"
        )),
    }
}

pub fn run_qsdk_r24d51_rapier_discrete_staging_zero_world_qualification() -> Result<Value, String> {
    let supported_fixture = analytic_fixture(0.0, -9.8, true);
    let free_fall_fixture = analytic_fixture(0.0, -9.8, false);
    let upward_fixture = analytic_fixture(2.5, -9.8, false);
    let downward_fixture = analytic_fixture(-2.5, -9.8, false);
    let zero_gravity_fixture = analytic_fixture(1.25, 0.0, false);
    let supported = measure_r24d51_rapier_discrete_staging_exchange_v1(
        1,
        0,
        &supported_fixture.steps,
        supported_fixture.endpoint,
    )?;
    let free_fall = measure_r24d51_rapier_discrete_staging_exchange_v1(
        1,
        0,
        &free_fall_fixture.steps,
        free_fall_fixture.endpoint,
    )?;
    let upward = measure_r24d51_rapier_discrete_staging_exchange_v1(
        1,
        0,
        &upward_fixture.steps,
        upward_fixture.endpoint,
    )?;
    let downward = measure_r24d51_rapier_discrete_staging_exchange_v1(
        1,
        0,
        &downward_fixture.steps,
        downward_fixture.endpoint,
    )?;
    let zero_gravity = measure_r24d51_rapier_discrete_staging_exchange_v1(
        1,
        0,
        &zero_gravity_fixture.steps,
        zero_gravity_fixture.endpoint,
    )?;

    let controls = [
        (
            "resting_supported_gravity_kick_and_constraint_cancellation_close",
            close(
                supported.signed_discrete_staging_exchange_j
                    + supported_fixture.independently_known_constraint_exchange_j,
                supported_fixture.endpoint_energy_change_j,
            ),
        ),
        (
            "free_fall_force_position_and_half_step_terms_match_endpoint_change_once",
            close(
                free_fall.signed_discrete_staging_exchange_j,
                free_fall_fixture.endpoint_energy_change_j,
            ),
        ),
        (
            "upward_and_downward_free_fall_preserve_the_same_discrete_defect",
            close(
                upward.signed_discrete_staging_exchange_j,
                upward_fixture.endpoint_energy_change_j,
            ) && close(
                downward.signed_discrete_staging_exchange_j,
                downward_fixture.endpoint_energy_change_j,
            ) && close(
                upward.signed_discrete_staging_exchange_j,
                downward.signed_discrete_staging_exchange_j,
            ),
        ),
        (
            "zero_gravity_has_zero_force_position_half_step_and_total_exchange",
            zero_gravity.force_integration_kinetic_exchange_j == 0.0
                && zero_gravity.raw_gravity_potential_position_exchange_j == 0.0
                && zero_gravity.endpoint_half_step_projection_exchange_j == 0.0
                && zero_gravity.signed_discrete_staging_exchange_j == 0.0,
        ),
        (
            "all_three_components_are_retained_separately_before_the_signed_sum",
            close(
                free_fall.force_integration_kinetic_exchange_j
                    + free_fall.raw_gravity_potential_position_exchange_j
                    + free_fall.endpoint_half_step_projection_exchange_j,
                free_fall.signed_discrete_staging_exchange_j,
            ),
        ),
    ];
    if let Some((id, _)) = controls.iter().find(|(_, passed)| !passed) {
        return Err(format!("QSDK_R24D51_CONTROL_FAILED:{id}"));
    }

    let mut omitted = free_fall_fixture.steps.clone();
    omitted.pop();
    let mut duplicated = free_fall_fixture.steps.clone();
    duplicated[15] = duplicated[14];
    let mut reordered = free_fall_fixture.steps.clone();
    reordered.swap(3, 4);
    let mut stale_sequence_steps = free_fall_fixture.steps.clone();
    stale_sequence_steps[0].source_measurement = false;
    let mut nonfinite_force = free_fall_fixture.steps.clone();
    nonfinite_force[7].kinetic_energy_after_force_j = f64::NAN;
    let mut nonfinite_position = free_fall_fixture.steps.clone();
    nonfinite_position[7].raw_gravity_potential_after_position_j = f64::INFINITY;
    let mut endpoint_not_source = free_fall_fixture.endpoint;
    endpoint_not_source.source_measurement = false;
    let mut endpoint_nonfinite = free_fall_fixture.endpoint;
    endpoint_nonfinite.after_outer_step_j = f64::NAN;

    let mutations = vec![
        reject(
            "omitted_small_step",
            &omitted,
            free_fall_fixture.endpoint,
            "QSDK_R24D51_SMALL_STEP_POPULATION_INVALID",
        )?,
        reject(
            "duplicated_small_step",
            &duplicated,
            free_fall_fixture.endpoint,
            "QSDK_R24D51_SMALL_STEP_ORDER_INVALID",
        )?,
        reject(
            "reordered_small_steps",
            &reordered,
            free_fall_fixture.endpoint,
            "QSDK_R24D51_SMALL_STEP_ORDER_INVALID",
        )?,
        reject(
            "small_step_not_source_measured",
            &stale_sequence_steps,
            free_fall_fixture.endpoint,
            "QSDK_R24D51_SMALL_STEP_NOT_SOURCE_MEASURED",
        )?,
        reject(
            "nonfinite_force_boundary",
            &nonfinite_force,
            free_fall_fixture.endpoint,
            "QSDK_R24D51_FORCE_BOUNDARY_NONFINITE",
        )?,
        reject(
            "nonfinite_position_boundary",
            &nonfinite_position,
            free_fall_fixture.endpoint,
            "QSDK_R24D51_POSITION_BOUNDARY_NONFINITE",
        )?,
        reject(
            "endpoint_not_source_measured",
            &free_fall_fixture.steps,
            endpoint_not_source,
            "QSDK_R24D51_ENDPOINT_NOT_SOURCE_MEASURED",
        )?,
        reject(
            "nonfinite_endpoint_boundary",
            &free_fall_fixture.steps,
            endpoint_nonfinite,
            "QSDK_R24D51_ENDPOINT_BOUNDARY_NONFINITE",
        )?,
    ];
    let mutation_ids = mutations
        .iter()
        .map(|mutation| mutation["mutation_id"].clone())
        .collect::<Vec<_>>();
    let check_count = controls.len() + mutations.len();

    Ok(json!({
        "schema_version":
            "sporespore_qsdk_r24d51_rapier_discrete_staging_zero_world_qualification_v1",
        "ok": true,
        "gate_id": R24D51_GATE_ID,
        "question_class": "development",
        "qualification_class": "zero_world_discrete_force_position_staging_observer_design",
        "rule_id": R24D51_STAGING_RULE_ID,
        "accepted_fixtures": {
            "supported_rest": supported.to_json(),
            "free_fall": free_fall.to_json(),
            "upward_free_fall": upward.to_json(),
            "downward_free_fall": downward.to_json(),
            "zero_gravity": zero_gravity.to_json(),
        },
        "controls": controls.iter().map(|(id, passed)| json!({
            "control_id": id,
            "passed": passed,
        })).collect::<Vec<_>>(),
        "control_count": controls.len(),
        "mutation_ids": mutation_ids,
        "mutation_rejections": mutations,
        "mutation_rejection_count": 8,
        "check_count": check_count,
        "checks_passed": check_count,
        "mechanical_energy_change_used_as_observer_input": false,
        "energy_balance_residual_used_as_observer_input": false,
        "acceptance_threshold_used_as_observer_input": false,
        "native_runtime_wiring_implemented": false,
        "new_engine_neutral_ledger_mapping_implemented": false,
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
    fn zero_world_design_closes_controls_and_rejects_topology_mutations() {
        let receipt = run_qsdk_r24d51_rapier_discrete_staging_zero_world_qualification().unwrap();
        assert_eq!(receipt["ok"], true);
        assert_eq!(receipt["checks_passed"], 13);
        assert_eq!(receipt["world_build_count"], 0);
    }
}
