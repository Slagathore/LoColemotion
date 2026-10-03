//! Supplied synthetic observations only, including explicitly native-shaped
//! fixtures for the physical-profile branches. No world or native read occurs.
use super::*;
use crate::recovery::passive_entry::*;
use crate::recovery_energy_v3::RecoveryEnergyWorkIncrementV3;

pub(super) fn sample(engine: RecoveryNativeEngineV1, step: u64, prone: bool) -> RecoveryObservationV3 {
    let legacy = observation(
        engine,
        RecoveryArmKindV1::CandidateCommand,
        step,
        prone,
        true,
        false,
        false,
    );
    let mut value = observation_v3_from_v2(observation_v2_from_v1(legacy, 0.0), 0.0);
    value.controller_ownership = owner(RecoveryArmKindV1::MatchedZeroCommand, false);
    for impulse in &mut value.applied_actuation.ordered_applied_impulses {
        impulse.applied_angular_impulse_nms = 0.0;
    }
    value.engine_step_identity.host_step_before = 1000 + step - 273;
    value.engine_step_identity.host_step_after = 1001 + step - 273;
    value
}

pub(super) fn first(engine: RecoveryNativeEngineV1, native_shape: bool) -> RecoveryPassiveEntryStepRequestV1 {
    let mut observation = sample(engine, 273, false);
    let mut initialization = initialization_v2(engine, RecoveryArmKindV1::CandidateCommand);
    if native_shape {
        initialization.threshold_profile_id =
            crate::recovery_runtime::EXACT_S169_DEVELOPMENT_THRESHOLD_PROFILE_ID.to_owned();
        observation.engine_step_identity.source_kind =
            RecoveryObservationSourceKindV1::NativePostStep;
        observation.engine_step_identity.native_solver_substep_count =
            expected_native_substeps(engine);
        observation.energy_balance.source_profile_id =
            GODOT_JOLT_R24D148_DISCRETE_STAGING_ENERGY_SOURCE_PROFILE_ID.to_owned();
    }
    let energy = &mut observation.energy_balance;
    energy.initial_mechanical_energy_j = 10.0;
    energy.current_mechanical_energy_j = 12.0;
    energy.cumulative_applied_actuator_work_j = 0.0;
    energy.cumulative_signed_external_work_j = 2.0; // Retained hypothetical kick work, not erased at handoff.
    energy.cumulative_signed_constraint_exchange_j = 0.0;
    energy.cumulative_signed_discrete_staging_exchange_j = 0.0;
    energy.cumulative_passive_dissipation_j = 0.0;
    let energy_partition_authority =
        native_shape.then(|| godot_commissioned_discrete_staging_energy_authority(&observation));
    RecoveryPassiveEntryStepRequestV1 {
        schema_version: PASSIVE_ENTRY_REQUEST_V1.to_owned(),
        declaration: RecoveryPassiveEntryDeclarationV1 {
            schema_version: PASSIVE_ENTRY_DECLARATION_V1.to_owned(),
            attempt_id: "synthetic_passive_entry_attempt".to_owned(),
            initialization,
            first_semantic_step: 273,
            first_host_step_before: 1000,
            maximum_descent_steps: if native_shape { 75 } else { 8 },
            energy_at_boundary: observation.energy_balance.clone(),
            energy_boundary_sequence_index: 0,
            energy_partition_authority,
            native_global_energy_at_boundary: None,
        },
        prior: None,
        native_global_energy: None,
        observation,
        energy_increment: RecoveryEnergyWorkIncrementV3 {
            sequence_index: 1,
            semantic_step: 273,
            applied_actuator_work_j: 0.0,
            signed_external_work_j: 0.0,
            signed_constraint_exchange_j: 0.0,
            signed_discrete_staging_exchange_j: 0.0,
            passive_dissipation_j: 0.0,
            source_measurement: true,
        },
    }
}

pub(super) fn advance(
    request: &mut RecoveryPassiveEntryStepRequestV1,
    receipt: &RecoveryPassiveEntryReceiptV1,
    prone: bool,
) {
    let next = receipt.memory.last_semantic_step + 1;
    let old_engine = request.observation.engine_step_identity.clone();
    request.observation = sample(old_engine.engine, next, prone);
    request.observation.engine_step_identity.source_kind = old_engine.source_kind;
    request
        .observation
        .engine_step_identity
        .native_solver_substep_count = old_engine.native_solver_substep_count;
    request.observation.energy_balance = receipt.memory.last_energy_ledger.clone();
    // Exercise nonzero running increments, so a balanced energy reset cannot
    // pass merely because every cumulative term was zero in the fixture.
    request
        .observation
        .energy_balance
        .cumulative_passive_dissipation_j += 0.125;
    request
        .observation
        .energy_balance
        .current_mechanical_energy_j -= 0.125;
    request.energy_increment.passive_dissipation_j = 0.125;
    request.energy_increment.semantic_step = next;
    request.energy_increment.sequence_index += 1;
    request.prior = Some(receipt.memory.clone());
}

#[test]
fn passive_entry_three_identity_canaries_start_once_at_measured_prone() {
    for engine in [
        RecoveryNativeEngineV1::GodotJolt4_7,
        RecoveryNativeEngineV1::RapierParryNative,
        RecoveryNativeEngineV1::MujocoNative,
    ] {
        let mut request = first(engine, false);
        request.observation.center_of_mass.position_world_m.y = 0.3235965073108673;
        let waiting = step_passive_entry_v1(request.clone()).unwrap();
        assert_eq!(
            waiting.memory.status,
            RecoveryPassiveEntryStatusV1::WaitingForProne
        );
        assert!(waiting.canonical_memory.is_none());
        assert_eq!(waiting.canonical_initialization_count, 0);
        advance(&mut request, &waiting, true);
        let before = request.clone();
        let ready = step_passive_entry_v1(request.clone()).unwrap();
        assert_eq!(request, before);
        assert_eq!(
            ready.memory.status,
            RecoveryPassiveEntryStatusV1::ProneHandoff
        );
        assert_eq!(ready.canonical_initialization_count, 1);
        let memory = ready.canonical_memory.as_ref().unwrap();
        assert_eq!(memory.phase, RecoveryPhaseV1::ConfirmProne);
        assert_eq!(memory.total_steps_observed, 1);
        assert_eq!(memory.phase_steps_observed, 1);
        assert_eq!(memory.prone_confirm_steps_observed, 1);
        assert_eq!(memory.start_semantic_step, Some(274));
        assert_eq!(
            memory.initial_center_of_mass_height_m,
            Some(request.observation.center_of_mass.position_world_m.y)
        );
        assert_eq!(
            ready.memory.last_energy_ledger,
            request.observation.energy_balance
        );
        assert_eq!(
            ready.memory.last_energy_ledger.initial_mechanical_energy_j,
            10.0
        );
        assert_eq!(
            ready
                .memory
                .last_energy_ledger
                .cumulative_signed_external_work_j,
            2.0
        );
        assert_eq!(
            ready
                .memory
                .last_energy_ledger
                .cumulative_passive_dissipation_j,
            0.125
        );
        assert_eq!(
            request.observation.controller_ownership.owner,
            RecoveryControllerOwnerV1::None
        );
        assert_eq!(
            ready.memory.last_observation_sha256,
            digest_serializable(&request.observation).unwrap()
        );
        assert!(
            !ready.energy_epoch_reset
                && !ready.controller_command_emitted
                && !ready.prone_to_standing_claimed
        );
        assert!(!ready.physical_acceptance_authority && !ready.release_authority);
        advance(&mut request, &ready, true);
        assert!(
            step_passive_entry_v1(request)
                .unwrap_err()
                .to_string()
                .contains("prior_identity_or_terminal")
        );
    }
}

#[test]
fn passive_entry_native_shaped_delay_preserves_canonical_twelve_sample_dwell() {
    let mut request = first(RecoveryNativeEngineV1::GodotJolt4_7, true);
    // More than the old 60-step confirmation window, without a canonical
    // controller, running clock, saved COM reference, or repeated initialization.
    for _ in 0..61 {
        let waiting = step_passive_entry_v1(request.clone()).unwrap();
        assert!(waiting.canonical_memory.is_none());
        assert_eq!(waiting.canonical_initialization_count, 0);
        advance(&mut request, &waiting, false);
    }
    let compiled =
        compile_bounded_quadruped(request.declaration.initialization.descriptor.clone()).unwrap();
    let prone = sample(
        RecoveryNativeEngineV1::GodotJolt4_7,
        request.observation.semantic_step,
        true,
    );
    request.observation.state.base_pose_world = prone.state.base_pose_world;
    request.observation.state.base_pose_world.position_m.y =
        compiled.geometry.initial_torso_center_y_m * 0.2;
    request.observation.ordered_body_clearance_observations =
        prone.ordered_body_clearance_observations;
    let ready = step_passive_entry_v1(request.clone()).unwrap();
    let mut memory = ready.canonical_memory.unwrap();
    assert_eq!(memory.start_semantic_step, Some(334));
    let mut observation = request.observation.clone();
    let authority = request.declaration.energy_partition_authority.unwrap();
    let init = request.declaration.initialization;
    // The old V5 path still rejects this owner-none observation; the new
    // entry contract did not weaken or silently relabel its historical input.
    let old = step_recovery_v5(RecoveryStepRequestV5 {
        schema_version: RECOVERY_STEP_REQUEST_V5_VERSION.to_owned(),
        descriptor: init.descriptor.clone(),
        morphology_context: init.morphology_context.clone(),
        adapter_capability: init.adapter_capability.clone(),
        memory: initialize_recovery_v2(init.clone())
            .unwrap()
            .memory
            .unwrap(),
        observation: observation.clone(),
        energy_partition_authority: authority.clone(),
    })
    .unwrap();
    assert_eq!(
        old.step.refusal_reason.as_deref(),
        Some("active_recovery_phase_owner_invalid")
    );
    observation.controller_ownership = owner(RecoveryArmKindV1::CandidateCommand, false);
    for count in 2..=12 {
        observation.semantic_step += 1;
        observation.state.semantic_step += 1;
        observation.applied_actuation.source_semantic_step += 1;
        observation.engine_step_identity.semantic_step += 1;
        observation.engine_step_identity.host_step_before += 1;
        observation.engine_step_identity.host_step_after += 1;
        let step = step_recovery_v5(RecoveryStepRequestV5 {
            schema_version: RECOVERY_STEP_REQUEST_V5_VERSION.to_owned(),
            descriptor: init.descriptor.clone(),
            morphology_context: init.morphology_context.clone(),
            adapter_capability: init.adapter_capability.clone(),
            memory,
            observation: observation.clone(),
            energy_partition_authority: authority.clone(),
        })
        .unwrap();
        assert_eq!(
            step.step.support_status,
            RecoverySupportStatusV1::SupportedExact
        );
        memory = step.step.memory.unwrap();
        assert_eq!(memory.total_steps_observed, count);
        assert_eq!(memory.start_semantic_step, Some(334));
        assert_eq!(
            memory.phase,
            if count < 12 {
                RecoveryPhaseV1::ConfirmProne
            } else {
                RecoveryPhaseV1::EstablishDistalSupport
            }
        );
    }
    assert_eq!(
        recovery_physical_development_threshold_profile_v1()
            .per_phase_timeout_steps
            .confirm_prone,
        60
    );
    assert_eq!(
        recovery_physical_development_threshold_profile_v1().minimum_com_height_gain_m,
        0.22
    );
}

#[test]
fn passive_entry_timeout_is_terminal_without_canonical_initialization() {
    let mut request = first(RecoveryNativeEngineV1::GodotJolt4_7, false);
    request.declaration.maximum_descent_steps = 1;
    let timeout = step_passive_entry_v1(request.clone()).unwrap();
    assert_eq!(
        timeout.memory.status,
        RecoveryPassiveEntryStatusV1::DescentTimeout
    );
    assert!(timeout.canonical_memory.is_none());
    advance(&mut request, &timeout, true);
    assert!(step_passive_entry_v1(request).is_err());
}

#[test]
fn passive_entry_identity_ownership_bounds_and_energy_mutations_refuse() {
    let valid = first(RecoveryNativeEngineV1::GodotJolt4_7, false);
    let waiting = step_passive_entry_v1(valid.clone()).unwrap();
    let mut second = valid.clone();
    advance(&mut second, &waiting, false);
    let mutations: &[fn(&mut RecoveryPassiveEntryStepRequestV1)] = &[
        |v| v.declaration.attempt_id.push_str("_changed"),
        |v| v.declaration.maximum_descent_steps = 0,
        |v| v.declaration.maximum_descent_steps = 33,
        |v| v.declaration.first_semantic_step = u64::MAX,
        |v| v.declaration.energy_boundary_sequence_index = u64::MAX,
        |v| v.prior = None,
        |v| v.observation.semantic_step -= 1,
        |v| v.observation.engine_step_identity.host_step_before += 1,
        |v| {
            v.observation.applied_actuation.ordered_applied_impulses[0]
                .applied_angular_impulse_nms = 0.0001
        },
        |v| v.observation.controller_ownership = owner(RecoveryArmKindV1::CandidateCommand, false),
        |v| {
            v.observation
                .controller_ownership
                .fallback_controller_active = true
        },
        |v| v.observation.center_of_mass.source_measurement = false,
        |v| v.observation.energy_balance.initial_mechanical_energy_j = 9.0,
        |v| {
            v.observation
                .energy_balance
                .cumulative_signed_external_work_j = 0.0
        },
        |v| {
            v.observation
                .energy_balance
                .cumulative_signed_constraint_exchange_j = 1.0
        },
        |v| {
            v.observation
                .energy_balance
                .cumulative_signed_discrete_staging_exchange_j = 1.0
        },
        |v| {
            v.observation
                .energy_balance
                .cumulative_passive_dissipation_j = 0.0
        },
        |v| v.energy_increment.sequence_index += 1,
        |v| v.energy_increment.semantic_step += 1,
        |v| v.energy_increment.applied_actuator_work_j = 0.125,
        |v| v.energy_increment.passive_dissipation_j = -0.125,
        |v| v.energy_increment.signed_external_work_j = f64::NAN,
    ];
    for (index, mutate) in mutations.iter().enumerate() {
        let mut bad = second.clone();
        mutate(&mut bad);
        assert!(step_passive_entry_v1(bad).is_err(), "mutation {index}");
    }
    let mut native = first(RecoveryNativeEngineV1::GodotJolt4_7, true);
    native.declaration.energy_partition_authority = None;
    assert!(
        step_passive_entry_v1(native)
            .unwrap_err()
            .to_string()
            .contains("native_energy_authority_missing")
    );
    let mut unknown = serde_json::to_value(valid).unwrap();
    unknown["acceptance"] = json!(true);
    assert!(serde_json::from_value::<RecoveryPassiveEntryStepRequestV1>(unknown).is_err());
}

#[test]
fn passive_entry_public_json_buffer_path_preserves_success_and_refusal() {
    use crate::ffi::{
        SS_BUFFER_TOO_SMALL, SS_CORE_ERROR, SS_OK, ss_recovery_passive_entry_step_v1_json,
    };
    let mut request = first(RecoveryNativeEngineV1::GodotJolt4_7, false);
    let waiting = step_passive_entry_v1(request.clone()).unwrap();
    advance(&mut request, &waiting, true);
    let expected = serde_json::to_value(step_passive_entry_v1(request.clone()).unwrap()).unwrap();
    let mut bad = serde_json::to_value(&request).unwrap();
    bad["observation"]["semantic_step"] = json!(999);
    for (value, expected_status) in [
        (serde_json::to_value(request).unwrap(), SS_OK),
        (bad, SS_CORE_ERROR),
    ] {
        let input = serde_json::to_vec(&value).unwrap();
        let mut required = 0;
        let sizing = unsafe {
            ss_recovery_passive_entry_step_v1_json(
                input.as_ptr(),
                input.len(),
                std::ptr::null_mut(),
                0,
                &mut required,
            )
        };
        assert_eq!(sizing, SS_BUFFER_TOO_SMALL);
        let mut output = vec![0u8; required];
        let status = unsafe {
            ss_recovery_passive_entry_step_v1_json(
                input.as_ptr(),
                input.len(),
                output.as_mut_ptr(),
                output.len(),
                &mut required,
            )
        };
        assert_eq!(status, expected_status);
        let response: serde_json::Value = serde_json::from_slice(&output[..required]).unwrap();
        if status == SS_OK {
            assert_eq!(response["value"], expected);
            assert_eq!(response["value"]["canonical_initialization_count"], 1);
        } else {
            assert_eq!(response["ok"], false);
            assert!(response.get("value").is_none());
        }
    }
}

#[test]
fn passive_entry_native_global_offsets_follow_producer_arithmetic_without_tolerance() {
    use crate::recovery::passive_entry::native_epoch::RecoveryPassiveNativeEnergyTotalsV1;
    let mut request = first(RecoveryNativeEngineV1::GodotJolt4_7, true);
    let boundary = RecoveryPassiveNativeEnergyTotalsV1 {
        source_values_sha256: format!("sha256:{}", "a".repeat(64)),
        cumulative_applied_actuator_work_j: 1085.0814377148167,
        cumulative_signed_external_work_j: 0.0,
        cumulative_signed_constraint_exchange_j: -1077.495694072387,
        cumulative_passive_dissipation_j: 0.0,
    };
    // Numeric anchors from the retained boundary and step 332, combined into a
    // SYNTHETIC one-step canary. This is not a claim about physical step 273.
    let delta = -0.02255246071647088;
    let mut global = boundary.clone();
    global.source_values_sha256 = format!("sha256:{}", "b".repeat(64));
    global.cumulative_signed_constraint_exchange_j += delta;
    let local = global.cumulative_signed_constraint_exchange_j
        - boundary.cumulative_signed_constraint_exchange_j;
    assert_ne!(local.to_bits(), delta.to_bits());
    request
        .declaration
        .energy_at_boundary
        .cumulative_signed_external_work_j = 0.0;
    request
        .declaration
        .energy_at_boundary
        .current_mechanical_energy_j = 10.0;
    request.observation.energy_balance = request.declaration.energy_at_boundary.clone();
    request
        .observation
        .energy_balance
        .cumulative_signed_constraint_exchange_j = local;
    request
        .observation
        .energy_balance
        .current_mechanical_energy_j = 10.0 + local;
    request.energy_increment.signed_constraint_exchange_j = delta;
    request.declaration.native_global_energy_at_boundary = Some(boundary);
    request.native_global_energy = Some(global);
    let valid = request.clone();
    let waiting = step_passive_entry_v1(request.clone()).unwrap();
    assert_eq!(
        waiting.memory.last_energy_ledger,
        request.observation.energy_balance
    );
    assert_eq!(
        waiting.memory.last_native_global_energy,
        request.native_global_energy
    );
    assert!(!waiting.energy_epoch_reset);

    // An undeclared local-sum check still refuses the arithmetic mismatch.
    let mut old = request.clone();
    old.native_global_energy = None;
    old.declaration.native_global_energy_at_boundary = None;
    assert!(
        step_passive_entry_v1(old)
            .unwrap_err()
            .to_string()
            .contains("increment_discontinuity")
    );
    for index in 0..9 {
        let mut bad = valid.clone();
        match index {
            0 => bad.native_global_energy = None,
            1 => bad.declaration.native_global_energy_at_boundary = None,
            2 => {
                bad.native_global_energy
                    .as_mut()
                    .unwrap()
                    .source_values_sha256 = "bad".to_owned()
            }
            3 => {
                bad.native_global_energy
                    .as_mut()
                    .unwrap()
                    .cumulative_signed_constraint_exchange_j += 0.001
            }
            4 => bad.energy_increment.signed_constraint_exchange_j = 0.0,
            5 => {
                bad.observation
                    .energy_balance
                    .cumulative_signed_constraint_exchange_j = delta
            }
            6 => {
                bad.declaration
                    .energy_at_boundary
                    .cumulative_signed_external_work_j = 0.1
            }
            7 => {
                bad.declaration
                    .energy_at_boundary
                    .current_mechanical_energy_j += 0.01
            }
            8 => {
                bad.declaration
                    .native_global_energy_at_boundary
                    .as_mut()
                    .unwrap()
                    .cumulative_passive_dissipation_j = -1.0
            }
            _ => unreachable!(),
        }
        assert!(
            step_passive_entry_v1(bad).is_err(),
            "native projection mutation {index}"
        );
    }
    advance(&mut request, &waiting, true);
    request.energy_increment.signed_constraint_exchange_j = 0.0;
    let global = request.native_global_energy.as_mut().unwrap();
    global.cumulative_passive_dissipation_j += 0.125;
    global.source_values_sha256 = format!("sha256:{}", "c".repeat(64));
    let compiled =
        compile_bounded_quadruped(request.declaration.initialization.descriptor.clone()).unwrap();
    request.observation.state.base_pose_world.position_m.y =
        compiled.geometry.initial_torso_center_y_m * 0.2;
    let mut missing_prior = request.clone();
    missing_prior
        .prior
        .as_mut()
        .unwrap()
        .last_native_global_energy = None;
    assert!(
        step_passive_entry_v1(missing_prior)
            .unwrap_err()
            .to_string()
            .contains("prior_global_source_missing")
    );
    let handoff = step_passive_entry_v1(request.clone()).unwrap();
    assert_eq!(
        handoff.memory.status,
        RecoveryPassiveEntryStatusV1::ProneHandoff
    );
    assert_eq!(handoff.canonical_initialization_count, 1);
    assert_eq!(
        handoff.memory.last_energy_ledger,
        request.observation.energy_balance
    );
    assert!(!handoff.energy_epoch_reset);
}

#[test]
fn passive_entry_preserves_safety_negative_and_canonical_reference_after_bounce() {
    let mut request = first(RecoveryNativeEngineV1::GodotJolt4_7, false);
    request.declaration.maximum_descent_steps = 2;
    let waiting = step_passive_entry_v1(request.clone()).unwrap();
    advance(&mut request, &waiting, true);
    request.observation.state.ordered_joint_observations[0].position_rad = Some(100.0);
    // Entry and safety are separate original predicates. Retain the safety
    // negative; do not turn measured prone entry into a locomotion success.
    let ready = step_passive_entry_v1(request.clone()).unwrap();
    assert_eq!(
        ready.memory.status,
        RecoveryPassiveEntryStatusV1::ProneHandoff
    );
    assert!(!ready.classification.joint_limits_respected);
    assert!(!ready.classification.safety_gate);
    assert!(!ready.prone_to_standing_claimed);
    let memory = ready.canonical_memory.unwrap();
    let saved_reference = memory.initial_center_of_mass_height_m;
    let mut bounce = sample(RecoveryNativeEngineV1::GodotJolt4_7, 275, false);
    bounce.controller_ownership = owner(RecoveryArmKindV1::CandidateCommand, false);
    bounce.center_of_mass.position_world_m.y = 0.4;
    let init = request.declaration.initialization;
    let result = step_recovery_v4(RecoveryStepRequestV4 {
        schema_version: RECOVERY_STEP_REQUEST_V4_VERSION.to_owned(),
        descriptor: init.descriptor,
        morphology_context: init.morphology_context,
        adapter_capability: init.adapter_capability,
        memory,
        observation: bounce,
    })
    .unwrap();
    let memory = result.memory.unwrap();
    assert_eq!(memory.initial_center_of_mass_height_m, saved_reference);
    assert_eq!(memory.prone_confirm_steps_observed, 0);
    assert_eq!(memory.phase_steps_observed, 2);
    assert_eq!(memory.start_semantic_step, Some(274));
}
