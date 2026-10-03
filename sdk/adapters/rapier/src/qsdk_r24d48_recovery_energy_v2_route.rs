//! Rapier recovery successor consuming the qualified R24D47 energy partition.
//!
//! The zero-world entry point exercises only pure mapping, source-identity,
//! mutation, and inherited qualification paths. The physical entry points are
//! separately launched from a clean pushed source: first a two-step-per-arm
//! integration ghost, then (only if that ghost is valid) the unchanged finite
//! paired recovery development horizon.

use rapier3d::dynamics::ImpulseJointHandle;
use serde_json::{Value, json};
use sporespore_locomotion_core::{
    CANONICAL_PRONE_TO_STANDING_TASK_ID, EXACT_S169_DEVELOPMENT_THRESHOLD_PROFILE_ID,
    PORTABLE_RECOVERY_SEMANTICS_ID, R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
    RAPIER_R24D48_ENERGY_V2_MAPPING_PROFILE_ID, RAPIER_R24D48_RECOVERY_ROUTE_ID,
    RECOVERY_ENERGY_BALANCE_AGGREGATION_REQUEST_V2_VERSION, RECOVERY_EVALUATION_REQUEST_V3_VERSION,
    RECOVERY_OBSERVATION_V2_VERSION, RECOVERY_STEP_REQUEST_V3_VERSION, RECOVERY_TRACE_V2_VERSION,
    RecoveryArmKindV1, RecoveryControlReceiptV1, RecoveryEnergyBalanceAggregationReceiptV2,
    RecoveryEnergyBalanceAggregationRequestV2, RecoveryEnergyWorkIncrementV2,
    RecoveryEvaluationReceiptV1, RecoveryEvaluationRequestV3, RecoveryNativeCollectionRequestV3,
    RecoveryObservationV1, RecoveryObservationV2, RecoveryObservationV2SourceBindingV1,
    RecoveryPhaseV1, RecoveryStepRequestV3, RecoverySupervisorMemoryV1, RecoverySupportStatusV1,
    RecoveryTraceV2, aggregate_recovery_energy_balance_v2, bind_recovery_observation_v2_source_v1,
    digest_json, digest_serializable, evaluate_recovery_trace_v3, r23d60_selected_s169_descriptor,
    recovery_observation_v2_source_identity_supported_v1, step_recovery_v3,
};

use crate::qsdk_r24d45_recovery_route::{
    RapierRecoveryBoundaryV1, RapierRecoveryNativeStepV1, RapierRecoveryPronePosePlanV1,
    RapierRecoveryStepContextV1, apply_and_step_r24d45_recovery_v1, arm_id,
    build_r24d45_recovery_world_v1, collect_r24d45_native_step_v1,
    compile_r24d45_recovery_boundary_v1, initialize_arm_memory_v1,
    plan_r24d45_canonical_prone_pose_v1, run_qsdk_r24d45_rapier_recovery_route_qualification,
    validate_r24d45_in_run_step_v1,
};
use crate::qsdk_r24d47_energy_exchange_observer::{
    R24D47_ENERGY_RULE_ID, RapierEnergyExchangeSampleV1,
    collect_r24d47_rapier_world_energy_exchange_v1,
    observe_r24d47_rapier_world_route_capability_v1,
    run_qsdk_r24d47_rapier_energy_exchange_zero_world_qualification,
};
use crate::recovery_capability::{RAPIER_RECOVERY_ADAPTER_ID, rapier_recovery_capability_v1};
use crate::recovery_runtime::{
    collect_rapier_native_recovery_observation_v3, plan_rapier_recovery_control_v3,
    plan_rapier_recovery_stance_control_v3, rapier_recovery_collection_request_v3,
};

const CONTRACT_RAW: &str =
    include_str!("../../../recovery/r24d48_rapier_recovery_energy_v2_contract_v1.json");
pub const R24D48_GATE_ID: &str = "QSDK-R24D48";
const CELL_ID: &str = "r24d48_rapier_development_nominal";
const CELL_SEED: u32 = 260_226_999;
const ZERO_WORLD_SCHEMA: &str =
    "sporespore_qsdk_r24d48_rapier_recovery_energy_v2_zero_world_qualification_v1";
const MAPPING_RECEIPT_SCHEMA: &str =
    "sporespore_qsdk_r24d48_rapier_recovery_observation_v2_mapping_receipt_v1";
const COMPONENT_RECEIPT_SCHEMA: &str =
    "sporespore_qsdk_r24d48_rapier_recovery_energy_component_receipt_v1";

struct RapierRecoveryMappedObservationV2 {
    observation: RecoveryObservationV2,
    observation_sha256: String,
    source_binding: RecoveryObservationV2SourceBindingV1,
    source_binding_sha256: String,
    component_receipt: Value,
    mapping_receipt: Value,
    aggregation_receipt: RecoveryEnergyBalanceAggregationReceiptV2,
}

pub(crate) struct RapierRecoveryArmRunV2 {
    pub(crate) trace: RecoveryTraceV2,
    pub(crate) arm_result: Value,
}

fn valid_sha256(value: &str) -> bool {
    value.len() == 71
        && value.starts_with("sha256:")
        && value[7..]
            .bytes()
            .all(|byte| byte.is_ascii_digit() || (b'a'..=b'f').contains(&byte))
}

fn sha256_value(value: &Value, code: &str) -> Result<String, String> {
    digest_json(value).map_err(|error| format!("{code}:{error}"))
}

fn validate_contract() -> Result<Value, String> {
    let contract: Value = serde_json::from_str(CONTRACT_RAW)
        .map_err(|error| format!("QSDK_R24D48_CONTRACT_PARSE:{error}"))?;
    if contract["gate_id"] != R24D48_GATE_ID
        || contract["question_class"] != "development"
        || contract["physical_question_declared"] != true
        || contract["scope"]["engine"] != "rapier_parry_native"
        || contract["development_cohort"]["cell_count"] != 1
        || contract["development_cohort"]["cells"][0]["cell_id"] != CELL_ID
        || contract["development_cohort"]["cells"][0]["seed"] != CELL_SEED
        || contract["staged_physical_execution"]["integration_ghost"]["maximum_outer_steps_per_arm"]
            != 2
        || contract["staged_physical_execution"]["paired_development"]["maximum_outer_steps_per_arm"]
            != 1200
        || contract["threshold_and_margin_provenance"]["threshold_change_count"] != 0
        || contract["held_out_seal"]["held_out_access_count"] != 0
        || contract["held_out_seal"]["held_out_selector_invocation_count"] != 0
    {
        return Err("QSDK_R24D48_CONTRACT_IDENTITY_INVALID".to_owned());
    }
    Ok(contract)
}

fn map_energy_increment_v1(
    sample: RapierEnergyExchangeSampleV1,
    semantic_step: u64,
) -> Result<RecoveryEnergyWorkIncrementV2, String> {
    if sample.sequence != semantic_step || semantic_step == 0 || !sample.source_measurement {
        return Err("QSDK_R24D48_ENERGY_SAMPLE_IDENTITY_INVALID".to_owned());
    }
    for value in [
        sample.motor_net_work_j,
        sample.signed_external_work_j,
        sample.signed_constraint_exchange_j,
        sample.passive_dissipation_j,
    ] {
        if !value.is_finite() {
            return Err("QSDK_R24D48_ENERGY_SAMPLE_NONFINITE".to_owned());
        }
    }
    if sample.passive_dissipation_j < 0.0 {
        return Err("QSDK_R24D48_PASSIVE_DISSIPATION_NEGATIVE".to_owned());
    }
    Ok(RecoveryEnergyWorkIncrementV2 {
        sequence_index: sample.sequence,
        semantic_step,
        applied_actuator_work_j: sample.motor_net_work_j,
        signed_external_work_j: sample.signed_external_work_j,
        signed_constraint_exchange_j: sample.signed_constraint_exchange_j,
        passive_dissipation_j: sample.passive_dissipation_j,
        source_measurement: true,
    })
}

fn r47_sample_from_value(value: &Value) -> Result<RapierEnergyExchangeSampleV1, String> {
    let number = |field: &str| -> Result<f64, String> {
        value[field]
            .as_f64()
            .ok_or_else(|| format!("QSDK_R24D48_R47_FIXTURE_NUMBER:{field}"))
    };
    let count = |field: &str| -> Result<u32, String> {
        value[field]
            .as_u64()
            .and_then(|item| u32::try_from(item).ok())
            .ok_or_else(|| format!("QSDK_R24D48_R47_FIXTURE_COUNT:{field}"))
    };
    Ok(RapierEnergyExchangeSampleV1 {
        sequence: value["sequence"]
            .as_u64()
            .ok_or_else(|| "QSDK_R24D48_R47_FIXTURE_SEQUENCE".to_owned())?,
        motor_supplied_work_j: number("motor_supplied_work_j")?,
        motor_absorbed_work_j: number("motor_absorbed_work_j")?,
        motor_net_work_j: number("motor_net_work_j")?,
        joint_phase_exchange_j: number("joint_phase_exchange_j")?,
        nonmotor_joint_and_stabilization_exchange_j: number(
            "nonmotor_joint_and_stabilization_exchange_j",
        )?,
        contact_and_friction_exchange_j: number("contact_and_friction_exchange_j")?,
        contact_warmstart_exchange_j: number("contact_warmstart_exchange_j")?,
        signed_constraint_exchange_j: number("signed_constraint_exchange_j")?,
        signed_external_work_j: number("signed_external_work_j")?,
        passive_dissipation_j: number("passive_dissipation_j")?,
        phase_partition_consistency_bound_j: number("phase_partition_consistency_bound_j")?,
        constraint_phase_count: count("constraint_phase_count")?,
        joint_phase_count: count("joint_phase_count")?,
        contact_phase_count: count("contact_phase_count")?,
        contact_warmstart_phase_count: count("contact_warmstart_phase_count")?,
        small_step_count: count("small_step_count")?,
        motor_count: count("motor_count")?,
        source_measurement: value["source_measurement"]
            .as_bool()
            .ok_or_else(|| "QSDK_R24D48_R47_FIXTURE_SOURCE_MEASUREMENT".to_owned())?,
    })
}

fn observation_v2_from_v1(
    base: RecoveryObservationV1,
    energy_balance: sporespore_locomotion_core::RecoveryEnergyBalanceLedgerV2,
) -> RecoveryObservationV2 {
    RecoveryObservationV2 {
        schema_version: RECOVERY_OBSERVATION_V2_VERSION.to_owned(),
        task_id: base.task_id,
        semantics_id: base.semantics_id,
        actuator_profile_id: base.actuator_profile_id,
        semantic_step: base.semantic_step,
        outer_step_duration_s: base.outer_step_duration_s,
        state: base.state,
        center_of_mass: base.center_of_mass,
        ordered_foot_bearing_observations: base.ordered_foot_bearing_observations,
        ordered_body_clearance_observations: base.ordered_body_clearance_observations,
        applied_actuation: base.applied_actuation,
        external_interventions: base.external_interventions,
        controller_ownership: base.controller_ownership,
        energy_balance,
        engine_step_identity: base.engine_step_identity,
    }
}

fn map_native_step_to_observation_v2(
    native: RapierRecoveryNativeStepV1,
    sample: RapierEnergyExchangeSampleV1,
    pre_step_route_capability: Value,
    post_step_route_capability: Value,
    ordered_increments: &mut Vec<RecoveryEnergyWorkIncrementV2>,
    previous_observation_v2_sha256: Option<&str>,
) -> Result<RapierRecoveryMappedObservationV2, String> {
    let semantic_step = native.observation.semantic_step;
    if pre_step_route_capability != post_step_route_capability
        || previous_observation_v2_sha256.is_some_and(|value| !valid_sha256(value))
    {
        return Err("QSDK_R24D48_ROUTE_CAPABILITY_OR_CHAIN_INVALID".to_owned());
    }
    let increment = map_energy_increment_v1(sample, semantic_step)?;
    ordered_increments.push(increment);
    let aggregation_receipt =
        aggregate_recovery_energy_balance_v2(RecoveryEnergyBalanceAggregationRequestV2 {
            schema_version: RECOVERY_ENERGY_BALANCE_AGGREGATION_REQUEST_V2_VERSION.to_owned(),
            source_profile_id: RAPIER_R24D48_ENERGY_V2_MAPPING_PROFILE_ID.to_owned(),
            initial_mechanical_energy_j: native
                .observation
                .energy_balance
                .initial_mechanical_energy_j,
            current_mechanical_energy_j: native
                .observation
                .energy_balance
                .current_mechanical_energy_j,
            ordered_increments: ordered_increments.clone(),
        })
        .map_err(|error| format!("QSDK_R24D48_ENERGY_AGGREGATION:{error}"))?;
    if aggregation_receipt.increment_count != ordered_increments.len()
        || aggregation_receipt.last_sequence_index != sample.sequence
        || aggregation_receipt.last_semantic_step != semantic_step
        || aggregation_receipt.world_build_count != 0
        || aggregation_receipt.solver_step_count != 0
        || aggregation_receipt.physics_state_modified
        || aggregation_receipt.physical_acceptance_authority
        || aggregation_receipt.release_authority
    {
        return Err("QSDK_R24D48_ENERGY_AGGREGATION_RECEIPT_INVALID".to_owned());
    }

    let component_receipt = json!({
        "schema_version": COMPONENT_RECEIPT_SCHEMA,
        "gate_id": R24D48_GATE_ID,
        "source_route_id": RAPIER_R24D48_RECOVERY_ROUTE_ID,
        "mapping_profile_id": RAPIER_R24D48_ENERGY_V2_MAPPING_PROFILE_ID,
        "semantic_step": semantic_step,
        "previous_observation_v2_sha256": previous_observation_v2_sha256,
        "base_observation_v1_sha256": native.observation_sha256,
        "pre_step_route_capability": pre_step_route_capability,
        "post_step_route_capability": post_step_route_capability,
        "energy_exchange_sample": sample.to_json(),
        "source_measurement": true,
    });
    let source_component_receipts_sha256 =
        sha256_value(&component_receipt, "QSDK_R24D48_COMPONENT_RECEIPT_SHA")?;
    let observation =
        observation_v2_from_v1(native.observation, aggregation_receipt.ledger.clone());
    let mapping_receipt = json!({
        "schema_version": MAPPING_RECEIPT_SCHEMA,
        "gate_id": R24D48_GATE_ID,
        "source_route_id": RAPIER_R24D48_RECOVERY_ROUTE_ID,
        "mapping_profile_id": RAPIER_R24D48_ENERGY_V2_MAPPING_PROFILE_ID,
        "energy_rule_id": R24D47_ENERGY_RULE_ID,
        "semantic_step": semantic_step,
        "sequence_index": sample.sequence,
        "base_observation_v1_sha256": native.observation_sha256,
        "source_component_receipts_sha256": source_component_receipts_sha256,
        "ordered_source_values_sha256": aggregation_receipt.ordered_source_values_sha256,
        "ledger_sha256": aggregation_receipt.ledger_sha256,
        "component_partition": {
            "actuator": "r24d47.motor_net_work_j",
            "external": "r24d47.signed_external_work_j",
            "constraint": "r24d47.signed_constraint_exchange_j",
            "passive": "r24d47.passive_dissipation_j",
            "mechanical_energy_change_used_as_work_source": false,
            "energy_balance_residual_used_as_work_source": false,
        },
        "threshold_applied": false,
        "physical_result": false,
    });
    let mapping_receipt_sha256 = sha256_value(&mapping_receipt, "QSDK_R24D48_MAPPING_RECEIPT_SHA")?;
    let source_binding = bind_recovery_observation_v2_source_v1(
        &observation,
        RAPIER_RECOVERY_ADAPTER_ID,
        RAPIER_R24D48_RECOVERY_ROUTE_ID,
        RAPIER_R24D48_ENERGY_V2_MAPPING_PROFILE_ID,
        &mapping_receipt_sha256,
        &source_component_receipts_sha256,
    )
    .map_err(|error| format!("QSDK_R24D48_SOURCE_BINDING:{error}"))?;
    let source_binding_sha256 =
        digest_serializable(&source_binding).map_err(|error| error.to_string())?;
    let observation_sha256 =
        digest_serializable(&observation).map_err(|error| error.to_string())?;
    Ok(RapierRecoveryMappedObservationV2 {
        observation,
        observation_sha256,
        source_binding,
        source_binding_sha256,
        component_receipt,
        mapping_receipt,
        aggregation_receipt,
    })
}

fn initial_observation_sha256(observation: &RecoveryObservationV2) -> Result<String, String> {
    sha256_value(
        &json!({
            "base_pose_world": observation.state.base_pose_world,
            "base_twist_world": observation.state.base_twist_world,
            "ordered_joint_observations": observation.state.ordered_joint_observations,
            "ordered_contact_observations": observation.state.ordered_contact_observations,
            "gravity_world_m_s2": observation.state.gravity_world_m_s2,
            "task_frame": observation.state.task_frame,
            "center_of_mass": observation.center_of_mass,
            "ordered_foot_bearing_observations": observation.ordered_foot_bearing_observations,
            "ordered_body_clearance_observations": observation.ordered_body_clearance_observations,
            "energy_initial_mechanical_j": observation.energy_balance.initial_mechanical_energy_j,
            "energy_current_mechanical_j": observation.energy_balance.current_mechanical_energy_j,
        }),
        "QSDK_R24D48_INITIAL_OBSERVATION_SHA",
    )
}

fn ordered_actuator_joint_handles(
    boundary: &RapierRecoveryBoundaryV1,
    world: &crate::qsdk_r24d45_recovery_route::RapierRecoveryWorldV1,
) -> Result<Vec<ImpulseJointHandle>, String> {
    boundary
        .compiled
        .morphology
        .morphology_spec
        .actuators
        .iter()
        .map(|actuator| {
            world
                .robot
                .joints
                .get(&actuator.joint_id)
                .copied()
                .ok_or_else(|| {
                    format!(
                        "QSDK_R24D48_ACTUATOR_JOINT_HANDLE_MISSING:{}",
                        actuator.actuator_id
                    )
                })
        })
        .collect()
}

pub(crate) fn run_arm<F>(
    boundary: &RapierRecoveryBoundaryV1,
    pose: &RapierRecoveryPronePosePlanV1,
    arm: RecoveryArmKindV1,
    maximum_outer_steps: u64,
    runtime_qualification_sha256: &str,
    mut observe_post_step: F,
) -> Result<RapierRecoveryArmRunV2, String>
where
    F: FnMut(
        &rapier3d::pipeline::PhysicsWorld,
        &RapierEnergyExchangeSampleV1,
        u64,
    ) -> Result<(), String>,
{
    if maximum_outer_steps == 0
        || maximum_outer_steps > 1200
        || !valid_sha256(runtime_qualification_sha256)
    {
        return Err("QSDK_R24D48_ARM_BUDGET_OR_RUNTIME_INVALID".to_owned());
    }
    let mut memory: RecoverySupervisorMemoryV1 = initialize_arm_memory_v1(boundary, arm)?;
    let mut world = build_r24d45_recovery_world_v1(boundary, pose)?;
    let ordered_handles = ordered_actuator_joint_handles(boundary, &world)?;
    let mut control = None::<RecoveryControlReceiptV1>;
    let mut observations = Vec::new();
    let mut ordered_increments = Vec::new();
    let mut invariant_receipts = Vec::new();
    let mut energy_samples = Vec::new();
    let mut component_receipts = Vec::new();
    let mut mapping_receipts = Vec::new();
    let mut aggregation_receipts = Vec::new();
    let mut collector_receipts = Vec::new();
    let mut portable_step_receipts = Vec::new();
    let mut planned_control_receipts = Vec::new();
    let mut previous_base_observation_sha256 = None::<String>;
    let mut previous_observation_v2_sha256 = None::<String>;
    let mut previous_energy_sequence = 0_u64;

    for semantic_step in 1..=maximum_outer_steps {
        let phase = memory.phase;
        if matches!(
            phase,
            RecoveryPhaseV1::Complete | RecoveryPhaseV1::Failed | RecoveryPhaseV1::Refused
        ) {
            break;
        }
        let pre_step_route_capability =
            observe_r24d47_rapier_world_route_capability_v1(&world.robot.world, 0, 0)?;
        let application = apply_and_step_r24d45_recovery_v1(
            &mut world,
            boundary,
            arm,
            phase,
            semantic_step,
            control.as_ref(),
        )?;
        let post_step_route_capability =
            observe_r24d47_rapier_world_route_capability_v1(&world.robot.world, 0, 0)?;
        let energy_sample = collect_r24d47_rapier_world_energy_exchange_v1(
            &world.robot.world,
            &ordered_handles,
            previous_energy_sequence,
            0,
            0,
        )?;
        observe_post_step(&world.robot.world, &energy_sample, semantic_step)?;
        let native = collect_r24d45_native_step_v1(
            &mut world,
            boundary,
            application,
            RapierRecoveryStepContextV1 {
                arm,
                phase,
                semantic_step,
                previous_observation_sha256: previous_base_observation_sha256.as_deref(),
                runtime_qualification_sha256,
            },
        )?;
        validate_r24d45_in_run_step_v1(
            &native.invariant_receipt,
            previous_base_observation_sha256.as_deref(),
        )?;
        let base_invariant_receipt = native.invariant_receipt.clone();
        previous_base_observation_sha256 = Some(native.observation_sha256.clone());
        let mapped = map_native_step_to_observation_v2(
            native,
            energy_sample,
            pre_step_route_capability,
            post_step_route_capability,
            &mut ordered_increments,
            previous_observation_v2_sha256.as_deref(),
        )?;
        let collection: RecoveryNativeCollectionRequestV3 = rapier_recovery_collection_request_v3(
            mapped.observation.clone(),
            mapped.source_binding.clone(),
            boundary.morphology_context.clone(),
            runtime_qualification_sha256,
            arm,
            phase,
        )?;
        let collected = collect_rapier_native_recovery_observation_v3(collection.clone())?;
        if collected.support_status != RecoverySupportStatusV1::SupportedExact
            || collected.refusal_reason.is_some()
            || collected.observation_sha256.as_deref() != Some(mapped.observation_sha256.as_str())
            || collected.observation_source_binding_sha256.as_deref()
                != Some(mapped.source_binding_sha256.as_str())
            || !collected.supplied_native_post_step_observation_validated
            || collected.native_runtime_observation_collection_executed
            || collected.engine_identity_exposed_to_controller
            || collected.prone_to_standing_claimed
            || collected.physical_acceptance_authority
            || collected.release_authority
        {
            return Err(format!(
                "QSDK_R24D48_NATIVE_COLLECTION_INVALID:{}:{semantic_step}",
                arm_id(arm)
            ));
        }
        let stepped = step_recovery_v3(RecoveryStepRequestV3 {
            schema_version: RECOVERY_STEP_REQUEST_V3_VERSION.to_owned(),
            descriptor: r23d60_selected_s169_descriptor(),
            morphology_context: boundary.morphology_context.clone(),
            adapter_capability: rapier_recovery_capability_v1(),
            memory,
            observation: mapped.observation.clone(),
        })
        .map_err(|error| error.to_string())?;
        if stepped.support_status != RecoverySupportStatusV1::SupportedExact
            || stepped.refusal_reason.is_some()
            || stepped.observation_sha256.as_deref() != Some(mapped.observation_sha256.as_str())
            || !stepped.post_step_observation_only
            || stepped.phase_skip_permitted
            || !stepped.controller_implemented
            || !stepped.physical_threshold_authority
            || stepped.world_build_count != 0
            || stepped.solver_step_count != 0
            || stepped.physics_state_modified
            || stepped.physical_acceptance_authority
            || stepped.release_authority
        {
            return Err(format!(
                "QSDK_R24D48_PORTABLE_STEP_INVALID:{}:{semantic_step}",
                arm_id(arm)
            ));
        }

        previous_energy_sequence = energy_sample.sequence;
        previous_observation_v2_sha256 = Some(mapped.observation_sha256.clone());
        observations.push(mapped.observation);
        invariant_receipts.push(base_invariant_receipt);
        energy_samples.push(energy_sample.to_json());
        component_receipts.push(mapped.component_receipt);
        mapping_receipts.push(mapped.mapping_receipt);
        aggregation_receipts.push(
            serde_json::to_value(&mapped.aggregation_receipt)
                .map_err(|error| format!("QSDK_R24D48_AGGREGATION_SERIALIZE:{error}"))?,
        );
        collector_receipts.push(
            serde_json::to_value(&collected)
                .map_err(|error| format!("QSDK_R24D48_COLLECTOR_SERIALIZE:{error}"))?,
        );
        portable_step_receipts.push(
            serde_json::to_value(&stepped)
                .map_err(|error| format!("QSDK_R24D48_STEP_SERIALIZE:{error}"))?,
        );
        memory = stepped
            .memory
            .clone()
            .ok_or_else(|| "QSDK_R24D48_PORTABLE_STEP_MEMORY_MISSING".to_owned())?;
        if matches!(
            memory.phase,
            RecoveryPhaseV1::Complete | RecoveryPhaseV1::Failed | RecoveryPhaseV1::Refused
        ) {
            break;
        }
        control = if matches!(
            memory.phase,
            RecoveryPhaseV1::StanceHandoff | RecoveryPhaseV1::StanceDwell
        ) {
            if arm != RecoveryArmKindV1::CandidateCommand {
                return Err("QSDK_R24D48_MATCHED_ZERO_REACHED_STANCE_OWNER".to_owned());
            }
            Some(plan_rapier_recovery_stance_control_v3(
                collection,
                stepped.clone(),
            )?)
        } else {
            let mut next_collection = collection;
            next_collection.phase = memory.phase;
            Some(plan_rapier_recovery_control_v3(
                next_collection,
                memory.phase_steps_observed,
            )?)
        };
        let next_control = control
            .as_ref()
            .ok_or_else(|| "QSDK_R24D48_PLANNED_CONTROL_MISSING".to_owned())?;
        if next_control.support_status != RecoverySupportStatusV1::SupportedExact
            || next_control.refusal_reason.is_some()
            || !next_control.controller_implemented
            || !next_control.deterministic
            || next_control.engine_identity_input_count != 0
            || next_control.engine_specific_policy_branch_count != 0
            || next_control.fallback_controller_active
            || next_control.physics_state_modified
            || next_control.physical_acceptance_authority
            || next_control.release_authority
        {
            return Err(format!(
                "QSDK_R24D48_CONTROL_PLAN_INVALID:{}:{semantic_step}",
                arm_id(arm)
            ));
        }
        planned_control_receipts.push(
            serde_json::to_value(next_control)
                .map_err(|error| format!("QSDK_R24D48_CONTROL_SERIALIZE:{error}"))?,
        );
    }
    if observations.is_empty() {
        return Err("QSDK_R24D48_EMPTY_ARM_TRACE".to_owned());
    }
    let declared_initial_state_sha256 = initial_observation_sha256(&observations[0])?;
    let trace = RecoveryTraceV2 {
        schema_version: RECOVERY_TRACE_V2_VERSION.to_owned(),
        arm_kind: arm,
        declared_initial_state_sha256: declared_initial_state_sha256.clone(),
        observations,
    };
    let arm_result = json!({
        "schema_version": "sporespore_qsdk_r24d48_rapier_recovery_arm_result_v1",
        "gate_id": R24D48_GATE_ID,
        "route_id": RAPIER_R24D48_RECOVERY_ROUTE_ID,
        "cell_id": CELL_ID,
        "seed": CELL_SEED,
        "arm_kind": arm_id(arm),
        "declared_initial_state_sha256": declared_initial_state_sha256,
        "trace": trace,
        "invariant_receipts": invariant_receipts,
        "energy_samples": energy_samples,
        "component_receipts": component_receipts,
        "mapping_receipts": mapping_receipts,
        "aggregation_receipts": aggregation_receipts,
        "collector_receipts": collector_receipts,
        "portable_step_receipts": portable_step_receipts,
        "planned_control_receipts": planned_control_receipts,
        "final_phase": memory.phase,
        "terminal_failure_code": memory.terminal_failure_code,
        "outer_step_count": trace.observations.len(),
        "native_solver_step_count": world.robot.solver_step_count,
        "energy_exchange_sequence_count": previous_energy_sequence,
        "model_construction_count": 1,
        "world_attempt_count": 1,
        "world_build_count": 1,
        "post_initialization_intervention_count": 0,
        "physics_state_modified": true,
        "prone_to_standing_claimed": false,
        "physical_acceptance_authority": false,
        "release_authority": false,
    });
    Ok(RapierRecoveryArmRunV2 { trace, arm_result })
}

fn evaluate_paired_traces(
    boundary: &RapierRecoveryBoundaryV1,
    candidate: RecoveryTraceV2,
    matched_zero: RecoveryTraceV2,
) -> Result<RecoveryEvaluationReceiptV1, String> {
    evaluate_recovery_trace_v3(RecoveryEvaluationRequestV3 {
        schema_version: RECOVERY_EVALUATION_REQUEST_V3_VERSION.to_owned(),
        task_id: CANONICAL_PRONE_TO_STANDING_TASK_ID.to_owned(),
        semantics_id: PORTABLE_RECOVERY_SEMANTICS_ID.to_owned(),
        actuator_profile_id: R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID.to_owned(),
        threshold_profile_id: EXACT_S169_DEVELOPMENT_THRESHOLD_PROFILE_ID.to_owned(),
        descriptor: r23d60_selected_s169_descriptor(),
        morphology_context: boundary.morphology_context.clone(),
        adapter_capability: rapier_recovery_capability_v1(),
        candidate_trace: candidate,
        matched_zero_command_trace: matched_zero,
    })
    .map_err(|error| error.to_string())
}

fn expected_runtime_qualification_sha256() -> Result<String, String> {
    let qualification = run_qsdk_r24d48_rapier_recovery_energy_v2_zero_world_qualification()?;
    sha256_value(&qualification, "QSDK_R24D48_RUNTIME_QUALIFICATION_SHA")
}

fn validate_runtime_qualification_sha256(observed: &str) -> Result<(), String> {
    if !valid_sha256(observed) {
        return Err("QSDK_R24D48_RUNTIME_QUALIFICATION_SHA_INVALID".to_owned());
    }
    let expected = expected_runtime_qualification_sha256()?;
    if observed != expected {
        return Err(format!(
            "QSDK_R24D48_RUNTIME_QUALIFICATION_SHA_MISMATCH:expected={expected}:observed={observed}"
        ));
    }
    Ok(())
}

/// Complete zero-world gate for the additive Rapier observation-V2 mapping.
pub fn run_qsdk_r24d48_rapier_recovery_energy_v2_zero_world_qualification() -> Result<Value, String>
{
    let contract = validate_contract()?;
    let r45 = run_qsdk_r24d45_rapier_recovery_route_qualification()?;
    let r47 = run_qsdk_r24d47_rapier_energy_exchange_zero_world_qualification()?;
    let sample = r47_sample_from_value(&r47["accepted_fixture"])?;
    let accepted_increment = map_energy_increment_v1(sample, 1)?;
    let expected_current = 10.0
        + accepted_increment.applied_actuator_work_j
        + accepted_increment.signed_external_work_j
        + accepted_increment.signed_constraint_exchange_j
        - accepted_increment.passive_dissipation_j;
    let accepted_aggregation =
        aggregate_recovery_energy_balance_v2(RecoveryEnergyBalanceAggregationRequestV2 {
            schema_version: RECOVERY_ENERGY_BALANCE_AGGREGATION_REQUEST_V2_VERSION.to_owned(),
            source_profile_id: RAPIER_R24D48_ENERGY_V2_MAPPING_PROFILE_ID.to_owned(),
            initial_mechanical_energy_j: 10.0,
            current_mechanical_energy_j: expected_current,
            ordered_increments: vec![accepted_increment],
        })
        .map_err(|error| format!("QSDK_R24D48_ZERO_WORLD_AGGREGATION:{error}"))?;
    if accepted_aggregation.evaluation.absolute_residual_j != 0.0
        || accepted_aggregation.evaluation.threshold_applied
        || accepted_aggregation.evaluation.physical_result
        || accepted_aggregation.world_build_count != 0
        || accepted_aggregation.solver_step_count != 0
    {
        return Err("QSDK_R24D48_ZERO_WORLD_AGGREGATION_INVALID".to_owned());
    }

    let mut mutation_results = Vec::new();
    let mut record = |mutation_id: &str, rejected: bool| -> Result<(), String> {
        mutation_results.push(json!({"mutation_id": mutation_id, "rejected": rejected}));
        if rejected {
            Ok(())
        } else {
            Err(format!(
                "QSDK_R24D48_MAPPING_MUTATION_ACCEPTED:{mutation_id}"
            ))
        }
    };
    let mut mutated = sample;
    mutated.sequence = 2;
    record(
        "sample_sequence_mismatch",
        map_energy_increment_v1(mutated, 1).is_err(),
    )?;
    let mut mutated = sample;
    mutated.source_measurement = false;
    record(
        "source_measurement_false",
        map_energy_increment_v1(mutated, 1).is_err(),
    )?;
    let mut mutated = sample;
    mutated.motor_net_work_j = f64::NAN;
    record(
        "nonfinite_actuator_work",
        map_energy_increment_v1(mutated, 1).is_err(),
    )?;
    let mut mutated = sample;
    mutated.passive_dissipation_j = -1.0;
    record(
        "negative_passive_dissipation",
        map_energy_increment_v1(mutated, 1).is_err(),
    )?;
    record(
        "wrong_source_route",
        !recovery_observation_v2_source_identity_supported_v1(
            sporespore_locomotion_core::RecoveryNativeEngineV1::RapierParryNative,
            RAPIER_RECOVERY_ADAPTER_ID,
            "mutated_route",
            RAPIER_R24D48_ENERGY_V2_MAPPING_PROFILE_ID,
        ),
    )?;
    record(
        "wrong_mapping_profile",
        !recovery_observation_v2_source_identity_supported_v1(
            sporespore_locomotion_core::RecoveryNativeEngineV1::RapierParryNative,
            RAPIER_RECOVERY_ADAPTER_ID,
            RAPIER_R24D48_RECOVERY_ROUTE_ID,
            "mutated_mapping",
        ),
    )?;
    record(
        "wrong_adapter",
        !recovery_observation_v2_source_identity_supported_v1(
            sporespore_locomotion_core::RecoveryNativeEngineV1::RapierParryNative,
            "mutated_adapter",
            RAPIER_R24D48_RECOVERY_ROUTE_ID,
            RAPIER_R24D48_ENERGY_V2_MAPPING_PROFILE_ID,
        ),
    )?;
    record(
        "unqualified_engine",
        !recovery_observation_v2_source_identity_supported_v1(
            sporespore_locomotion_core::RecoveryNativeEngineV1::GodotJolt4_7,
            RAPIER_RECOVERY_ADAPTER_ID,
            RAPIER_R24D48_RECOVERY_ROUTE_ID,
            RAPIER_R24D48_ENERGY_V2_MAPPING_PROFILE_ID,
        ),
    )?;

    Ok(json!({
        "schema_version": ZERO_WORLD_SCHEMA,
        "ok": true,
        "gate_id": R24D48_GATE_ID,
        "question_class": "development",
        "qualification_class": "zero_world_rapier_recovery_observation_v2_mapping",
        "route_id": RAPIER_R24D48_RECOVERY_ROUTE_ID,
        "mapping_profile_id": RAPIER_R24D48_ENERGY_V2_MAPPING_PROFILE_ID,
        "energy_rule_id": R24D47_ENERGY_RULE_ID,
        "r45_qualification_sha256": sha256_value(&r45, "QSDK_R24D48_R45_SHA")?,
        "r47_qualification_sha256": sha256_value(&r47, "QSDK_R24D48_R47_SHA")?,
        "accepted_energy_increment": accepted_increment,
        "accepted_aggregation": accepted_aggregation,
        "rapier_source_identity_supported": true,
        "observation_v2_assembly_compiled": true,
        "observation_v2_source_binding_builder_compiled": true,
        "v3_collector_controller_and_evaluator_compiled": true,
        "live_world_energy_collector_compiled": true,
        "in_run_pre_and_post_route_capability_readback_compiled": true,
        "mapping_mutation_rejection_count": mutation_results.len(),
        "mapping_mutation_results": mutation_results,
        "physical_question_declared": contract["physical_question_declared"],
        "physical_execution_authorized_by_this_receipt": false,
        "maximum_physical_steps_authorized_by_this_receipt": 0,
        "held_out_cell_access_count": 0,
        "held_out_selector_invocation_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": false,
        "prone_to_standing_claimed": false,
        "sdk1_milestone_advanced": false,
        "physical_acceptance_authority": false,
        "release_authority": false,
    }))
}

/// Short integration ghost: exactly two native outer steps per paired arm.
/// It proves the patched collector and V2 consumer are wired; behavior success
/// is deliberately neither required nor inferred.
pub fn run_qsdk_r24d48_rapier_recovery_energy_v2_ghost(
    runtime_qualification_sha256: &str,
) -> Result<Value, String> {
    validate_runtime_qualification_sha256(runtime_qualification_sha256)?;
    run_qsdk_r24d48_rapier_recovery_energy_v2_ghost_after_runtime_binding_v1(
        runtime_qualification_sha256,
    )
}

/// Preserve the exact R24D48 physical mechanics for a successor that owns an
/// independently qualified runtime binding. Callers must validate that binding
/// before entering this function.
pub(crate) fn run_qsdk_r24d48_rapier_recovery_energy_v2_ghost_after_runtime_binding_v1(
    runtime_qualification_sha256: &str,
) -> Result<Value, String> {
    let boundary = compile_r24d45_recovery_boundary_v1()?;
    let pose = plan_r24d45_canonical_prone_pose_v1(&boundary)?;
    let candidate = run_arm(
        &boundary,
        &pose,
        RecoveryArmKindV1::CandidateCommand,
        2,
        runtime_qualification_sha256,
        |_, _, _| Ok(()),
    )?;
    let matched_zero = run_arm(
        &boundary,
        &pose,
        RecoveryArmKindV1::MatchedZeroCommand,
        2,
        runtime_qualification_sha256,
        |_, _, _| Ok(()),
    )?;
    if candidate.trace.declared_initial_state_sha256
        != matched_zero.trace.declared_initial_state_sha256
    {
        return Err("QSDK_R24D48_GHOST_INITIAL_STATE_MISMATCH".to_owned());
    }
    let actual_total = candidate.trace.observations.len() + matched_zero.trace.observations.len();
    if candidate.trace.observations.len() != 2
        || matched_zero.trace.observations.len() != 2
        || actual_total != 4
    {
        return Err("QSDK_R24D48_GHOST_EXACT_STEP_COUNT_INVALID".to_owned());
    }
    Ok(json!({
        "schema_version": "sporespore_qsdk_r24d48_rapier_recovery_energy_v2_ghost_v1",
        "ok": true,
        "gate_id": R24D48_GATE_ID,
        "route_id": RAPIER_R24D48_RECOVERY_ROUTE_ID,
        "question_class": "development_integration_ghost",
        "runtime_qualification_sha256": runtime_qualification_sha256,
        "candidate": candidate.arm_result,
        "matched_zero_command": matched_zero.arm_result,
        "maximum_outer_steps_per_arm": 2,
        "maximum_total_outer_steps": 4,
        "actual_total_outer_steps": actual_total,
        "behavior_success_required": false,
        "official_behavior_evidence": false,
        "result_may_satisfy_prone_to_standing": false,
        "held_out_cell_access_count": 0,
        "held_out_selector_invocation_count": 0,
        "prone_to_standing_claimed": false,
        "physical_acceptance_authority": false,
        "release_authority": false,
    }))
}

/// Execute the prospectively declared finite paired Rapier development attempt.
pub fn run_qsdk_r24d48_rapier_recovery_energy_v2_development_attempt(
    runtime_qualification_sha256: &str,
) -> Result<Value, String> {
    validate_runtime_qualification_sha256(runtime_qualification_sha256)?;
    run_qsdk_r24d48_rapier_recovery_energy_v2_development_after_runtime_binding_v1(
        runtime_qualification_sha256,
    )
}

/// Preserve the exact R24D48 finite behavior path after a successor has
/// independently validated its qualified runtime-binding identity.
pub(crate) fn run_qsdk_r24d48_rapier_recovery_energy_v2_development_after_runtime_binding_v1(
    runtime_qualification_sha256: &str,
) -> Result<Value, String> {
    let boundary = compile_r24d45_recovery_boundary_v1()?;
    let pose = plan_r24d45_canonical_prone_pose_v1(&boundary)?;
    let candidate = run_arm(
        &boundary,
        &pose,
        RecoveryArmKindV1::CandidateCommand,
        1200,
        runtime_qualification_sha256,
        |_, _, _| Ok(()),
    )?;
    let matched_zero = run_arm(
        &boundary,
        &pose,
        RecoveryArmKindV1::MatchedZeroCommand,
        1200,
        runtime_qualification_sha256,
        |_, _, _| Ok(()),
    )?;
    if candidate.trace.declared_initial_state_sha256
        != matched_zero.trace.declared_initial_state_sha256
    {
        return Err("QSDK_R24D48_DEVELOPMENT_INITIAL_STATE_MISMATCH".to_owned());
    }
    let candidate_steps = candidate.trace.observations.len();
    let matched_zero_steps = matched_zero.trace.observations.len();
    let actual_total = candidate_steps + matched_zero_steps;
    if candidate_steps > 1200 || matched_zero_steps > 1200 || actual_total > 2400 {
        return Err("QSDK_R24D48_DEVELOPMENT_BUDGET_EXCEEDED".to_owned());
    }
    let evaluation = evaluate_paired_traces(
        &boundary,
        candidate.trace.clone(),
        matched_zero.trace.clone(),
    )?;
    if evaluation.model_construction_count != 0
        || evaluation.world_attempt_count != 0
        || evaluation.world_build_count != 0
        || evaluation.solver_step_count != 0
        || evaluation.physics_state_modified
        || evaluation.physical_acceptance_authority
        || evaluation.release_authority
    {
        return Err("QSDK_R24D48_DEVELOPMENT_EVALUATION_INVALID".to_owned());
    }
    Ok(json!({
        "schema_version": "sporespore_qsdk_r24d48_rapier_recovery_energy_v2_development_result_v1",
        "ok": true,
        "gate_id": R24D48_GATE_ID,
        "route_id": RAPIER_R24D48_RECOVERY_ROUTE_ID,
        "question_class": "development",
        "runtime_qualification_sha256": runtime_qualification_sha256,
        "cell_id": CELL_ID,
        "cell_seed": CELL_SEED,
        "candidate": candidate.arm_result,
        "matched_zero_command": matched_zero.arm_result,
        "evaluation": evaluation,
        "candidate_outer_steps": candidate_steps,
        "matched_zero_outer_steps": matched_zero_steps,
        "actual_total_outer_steps": actual_total,
        "maximum_outer_steps_per_arm": 1200,
        "maximum_total_outer_steps": 2400,
        "held_out_cell_access_count": 0,
        "held_out_selector_invocation_count": 0,
        "result_may_satisfy_r24d48": true,
        "prone_to_standing_claimed": evaluation.prone_to_standing_claimed,
        "physical_acceptance_authority": false,
        "release_authority": false,
    }))
}
