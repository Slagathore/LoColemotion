//! Synthetic R10Q task inputs. No retained physical observation is modified.
use super::*;
use crate::recovery::partial_fall as partial;
use crate::recovery::upright_recovery as upright;
use crate::recovery::passive_entry::RecoveryPassiveEntryStatusV1;
use crate::recovery_energy_v3::RecoveryEnergyWorkIncrementV3;

pub(crate) fn entry_first(height: f64) -> upright::EntryRequest {
    let mut source = passive_entry_tests::first(RecoveryNativeEngineV1::GodotJolt4_7, true);
    source.declaration.maximum_descent_steps = 240;
    source.declaration.initialization.threshold_profile_id = partial::PRONE_PROFILE.to_owned();
    let g = compile_bounded_quadruped(source.declaration.initialization.descriptor.clone()).unwrap().geometry;
    source.observation.state.base_pose_world.position_m.y = height * g.initial_torso_center_y_m;
    upright::EntryRequest { schema_version: upright::ENTRY_REQUEST.to_owned(),
        original_request: partial::EntryRequest { schema_version: partial::ENTRY_REQUEST.to_owned(), passive_request: source, prior: None }, prior: None }
}

pub(crate) fn advance(request: &mut upright::EntryRequest, receipt: &upright::EntryReceipt, height: f64) {
    let original = &receipt.original_entry;
    let ledger = original.original_passive_receipt.memory.last_energy_ledger.clone();
    passive_entry_tests::advance(&mut request.original_request.passive_request, &original.original_passive_receipt, false);
    let source = &mut request.original_request.passive_request;
    source.observation.energy_balance = ledger;
    source.energy_increment.passive_dissipation_j = 0.0;
    let g = compile_bounded_quadruped(source.declaration.initialization.descriptor.clone()).unwrap().geometry;
    source.observation.state.base_pose_world.position_m.y = height * g.initial_torso_center_y_m;
    request.original_request.prior = Some(original.memory.clone());
    request.prior = Some(receipt.memory.clone());
}

pub(crate) fn handoff() -> upright::EntryReceipt {
    let mut request = entry_first(0.72);
    for step in 1..240 {
        let receipt = upright::select_entry(request.clone()).unwrap();
        assert_eq!(upright::EntryRoute::Waiting, receipt.memory.route);
        assert!(receipt.upright_memory.is_none());
        assert_eq!(step, receipt.memory.original_memory.passive_memory.observations_seen);
        advance(&mut request, &receipt, 0.72);
    }
    upright::select_entry(request).unwrap()
}

pub(crate) fn step_input(declaration: &upright::Declaration, memory: &upright::Memory) -> upright::StepRequest {
    let entry = &declaration.entry_request.original_request.passive_request;
    let mut observation = entry.observation.clone();
    let next = memory.last_semantic_step + 1;
    observation.task_id = upright::TASK.to_owned();
    observation.semantics_id = upright::SEMANTICS.to_owned();
    observation.semantic_step = next;
    observation.state.semantic_step = next;
    observation.state.sample_time_s = next as f64 * RECOVERY_OUTER_STEP_DURATION_S;
    observation.applied_actuation.source_semantic_step = next;
    observation.engine_step_identity.semantic_step = next;
    observation.engine_step_identity.host_step_before = memory.last_host_step_after;
    observation.engine_step_identity.host_step_after = memory.last_host_step_after + 1;
    let stance = matches!(memory.phase, RecoveryPhaseV1::StanceHandoff | RecoveryPhaseV1::StanceDwell);
    observation.controller_ownership = owner(RecoveryArmKindV1::CandidateCommand, stance);
    if stance {
        observation.controller_ownership.stance_controller_id = Some("sporespore_exact_s169_stance_handoff_controller_v7".to_owned());
    } else {
        observation.controller_ownership.recovery_controller_id = Some(crate::recovery_runtime::EXACT_S169_RECOVERY_CONTROLLER_V20_ID.to_owned());
    }
    let g = compile_bounded_quadruped(entry.declaration.initialization.descriptor.clone()).unwrap().geometry;
    observation.state.base_pose_world.position_m.y = g.initial_torso_center_y_m * 0.8;
    observation.center_of_mass.position_world_m.y = entry.observation.center_of_mass.position_world_m.y - 0.01;
    observation.energy_balance = memory.last_energy_ledger.clone();
    upright::StepRequest { schema_version: upright::STEP_REQUEST.to_owned(), declaration: declaration.clone(),
        memory: memory.clone(), observation, native_global_energy: None,
        energy_increment: RecoveryEnergyWorkIncrementV3 { source_measurement: true, semantic_step: next,
            sequence_index: next - entry.declaration.first_semantic_step + 1,
            applied_actuator_work_j: 0.0, signed_external_work_j: 0.0, signed_constraint_exchange_j: 0.0,
            signed_discrete_staging_exchange_j: 0.0, passive_dissipation_j: 0.0 } }
}


#[test]
fn upright_admission_preserves_original_timeout_and_energy_without_prone_or_partial_claim() {
    let receipt = handoff();
    assert_eq!(upright::EntryRoute::Upright, receipt.memory.route);
    assert_eq!(12, receipt.memory.consecutive_upright_samples);
    assert_eq!(partial::EntryRoute::Timeout, receipt.original_entry.memory.route);
    let original = &receipt.original_entry.original_passive_receipt;
    assert_eq!(RecoveryPassiveEntryStatusV1::DescentTimeout, original.memory.status);
    assert!(original.canonical_memory.is_none() && receipt.original_entry.partial_memory.is_none());
    let memory = receipt.upright_memory.as_ref().unwrap();
    assert_eq!(original.memory.last_energy_ledger, memory.last_energy_ledger);
    assert_eq!(2.0, memory.last_energy_ledger.cumulative_signed_external_work_j);
    assert_eq!(0, memory.total_steps_observed);
    assert!(!receipt.energy_epoch_reset && !receipt.prone_to_standing_claimed
        && !receipt.partial_fall_standing_claimed && !receipt.physical_acceptance_authority);
}

#[test]
fn upright_requires_twelve_consecutive_samples_at_the_original_timeout() {
    for (bad_step, expected) in [(228, upright::EntryRoute::Upright), (229, upright::EntryRoute::Timeout)] {
        let mut request = entry_first(0.72);
        for count in 1..240 {
            let receipt = upright::select_entry(request.clone()).unwrap();
            advance(&mut request, &receipt, if count + 1 == bad_step { 0.4 } else { 0.72 });
        }
        let result = upright::select_entry(request).unwrap();
        assert_eq!(expected, result.memory.route);
        assert_eq!(240-bad_step, result.memory.consecutive_upright_samples);
    }
}

#[test]
fn exact_partial_boundary_and_genuine_prone_keep_their_original_routes() {
    let mut request = entry_first(0.5);
    for _ in 1..240 {
        let receipt = upright::select_entry(request.clone()).unwrap();
        advance(&mut request, &receipt, 0.5);
    }
    let result = upright::select_entry(request).unwrap();
    assert_eq!(upright::EntryRoute::Partial, result.memory.route);
    assert!(result.original_entry.partial_memory.is_some() && result.upright_memory.is_none());
    let mut request = entry_first(0.72);
    let receipt = upright::select_entry(request.clone()).unwrap();
    advance(&mut request, &receipt, 0.2);
    let torso = request.original_request.passive_request.observation.ordered_body_clearance_observations.iter_mut()
        .find(|body| body.body_id == "torso").unwrap();
    torso.ventral_surface_contact = true; torso.nonfoot_contact_present = true;
    torso.minimum_nonfoot_clearance_m = 0.0; torso.engine_contact_ids = vec!["synthetic_upright_prone_contact".to_owned()];
    let result = upright::select_entry(request).unwrap();
    assert_eq!(upright::EntryRoute::Prone, result.memory.route);
    assert!(result.original_entry.original_passive_receipt.canonical_memory.is_some() && result.upright_memory.is_none());
}

#[test]
fn crossed_prior_and_reused_terminal_entry_refuse() {
    let mut request = entry_first(0.72);
    let receipt = upright::select_entry(request.clone()).unwrap();
    advance(&mut request, &receipt, 0.72);
    request.prior.as_mut().unwrap().consecutive_upright_samples = 12;
    assert!(upright::select_entry(request).is_err());
    let terminal = handoff();
    let mut request = *terminal.upright_declaration.clone().unwrap().entry_request;
    advance(&mut request, &terminal, 0.72);
    assert!(upright::select_entry(request).is_err());
}

#[test]
fn absolute_standing_can_complete_without_relative_com_gain() {
    let entry = handoff(); let declaration = entry.upright_declaration.unwrap();
    let mut memory = entry.upright_memory.unwrap();
    for expected in [RecoveryPhaseV1::RaiseBody, RecoveryPhaseV1::StanceHandoff, RecoveryPhaseV1::StanceDwell] {
        let result = upright::step(step_input(&declaration, &memory)).unwrap();
        assert!(result.classification.center_of_mass_height_gain_m < 0.0);
        assert!(!result.classification.raised_body_gate);
        assert_eq!(expected, result.next_phase); memory = result.memory;
    }
    for count in 1..=60 {
        let result = upright::step(step_input(&declaration, &memory)).unwrap();
        assert_eq!(count == 60, result.upright_stabilization_complete);
        assert!(!result.prone_to_standing_claimed && !result.partial_fall_standing_claimed);
        memory = result.memory;
    }
    assert_eq!(4, memory.ordered_completed_phases.len());
    assert!(upright::step(step_input(&declaration, &memory)).is_err());
}

#[test]
fn missing_support_clearance_or_joint_limit_resets_the_standing_dwell() {
    let entry = handoff(); let declaration = entry.upright_declaration.unwrap();
    let mut memory = entry.upright_memory.unwrap();
    for _ in 0..13 { memory = upright::step(step_input(&declaration, &memory)).unwrap().memory; }
    assert_eq!(10, memory.standing_samples_observed);
    for mutation in 0..3 {
        let mut request = step_input(&declaration, &memory);
        if mutation == 0 {
            request.observation.state.ordered_contact_observations[0].presence = Some(false);
            request.observation.state.ordered_contact_observations[0].bears_support = Some(false);
            request.observation.ordered_foot_bearing_observations[0].bearing_normal_impulse_ns = 0.0;
        }
        if mutation == 1 { request.observation.ordered_body_clearance_observations[0].minimum_nonfoot_clearance_m = -0.001; }
        if mutation == 2 { request.observation.state.ordered_joint_observations[0].position_rad = Some(9.0); }
        let result = upright::step(request).unwrap();
        assert_eq!(0, result.memory.standing_samples_observed);
        assert!(!result.upright_stabilization_complete);
    }
}

#[test]
fn named_task_refuses_wrong_identity_clock_energy_phase_and_owner() {
    let entry = handoff(); let declaration = entry.upright_declaration.unwrap(); let memory = entry.upright_memory.unwrap();
    for mutation in 0..8 {
        let mut request = step_input(&declaration, &memory);
        if mutation == 0 { request.observation.task_id = partial::TASK.to_owned(); }
        if mutation == 1 { request.observation.semantic_step += 1; }
        if mutation == 2 { request.observation.energy_balance.initial_mechanical_energy_j += 1.0; request.observation.energy_balance.current_mechanical_energy_j += 1.0; }
        if mutation == 3 { request.memory.phase = RecoveryPhaseV1::StanceDwell; }
        if mutation == 4 { request.observation.controller_ownership = owner(RecoveryArmKindV1::MatchedZeroCommand, false); }
        if mutation == 5 { request.energy_increment.sequence_index += 1; }
        if mutation == 6 { request.observation.energy_balance.cumulative_signed_discrete_staging_exchange_j += 0.125; request.observation.energy_balance.current_mechanical_energy_j += 0.125; }
        if mutation == 7 { request.memory.schema_version = partial::MEMORY.to_owned(); }
        assert!(upright::step(request).is_err(), "mutation {mutation}");
    }
}

#[test]
fn standing_timeout_does_not_turn_incomplete_dwell_into_completion() {
    let entry = handoff(); let declaration = entry.upright_declaration.unwrap(); let initial = entry.upright_memory.unwrap();
    let mut memory = initial.clone();
    for _ in 0..3 { memory = upright::step(step_input(&declaration, &memory)).unwrap().memory; }
    for (elapsed, good, expected) in [(239,47,RecoveryPhaseV1::StanceDwell), (359,47,RecoveryPhaseV1::Failed), (359,59,RecoveryPhaseV1::Complete)] {
        let mut boundary = memory.clone(); boundary.phase_steps_observed = elapsed;
        boundary.total_steps_observed = 3+elapsed; boundary.standing_samples_observed = good;
        boundary.last_semantic_step = initial.last_semantic_step+u64::from(boundary.total_steps_observed);
        boundary.last_host_step_after = initial.last_host_step_after+u64::from(boundary.total_steps_observed);
        let result = upright::step(step_input(&declaration, &boundary)).unwrap();
        assert_eq!(expected, result.next_phase);
        assert_eq!(expected == RecoveryPhaseV1::Complete, result.upright_stabilization_complete);
    }
}

#[test]
fn small_native_joint_overshoot_can_enter_repair_but_is_not_standing() {
    let terminal = handoff();
    let mut request = *terminal.upright_declaration.unwrap().entry_request;
    request.original_request.passive_request.observation.state.ordered_joint_observations[1].position_rad = Some(-1.1048928499221802);
    let result = upright::select_entry(request).unwrap();
    assert_eq!(upright::EntryRoute::Upright, result.memory.route);
    assert!(!result.original_entry.original_passive_receipt.classification.joint_limits_respected);
    assert!(!result.original_entry.original_passive_receipt.classification.stable_stance_gate);
    assert_eq!(0, result.upright_memory.unwrap().standing_samples_observed);
}

#[test]
fn insufficient_upright_orientation_resets_admission_even_above_the_height_boundary() {
    let terminal = handoff();
    let mut request = *terminal.upright_declaration.unwrap().entry_request;
    let half_angle = 0.94_f64.acos() * 0.5;
    let orientation = &mut request.original_request.passive_request.observation.state.base_pose_world.orientation_xyzw;
    orientation.x = half_angle.sin(); orientation.y = 0.0; orientation.z = 0.0; orientation.w = half_angle.cos();
    let result = upright::select_entry(request).unwrap();
    assert_eq!(upright::EntryRoute::Timeout, result.memory.route);
    assert_eq!(0, result.memory.consecutive_upright_samples);
    assert!(result.upright_memory.is_none());
}
