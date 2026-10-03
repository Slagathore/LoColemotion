//! Synthetic native-shaped branch inputs; no world or native sensor reads.
use super::*;
use crate::recovery::partial_fall as partial;
use crate::recovery::passive_entry::RecoveryPassiveEntryStatusV1;
use crate::recovery_energy_v3::RecoveryEnergyWorkIncrementV3;

fn entry_first() -> partial::EntryRequest {
    let mut source = passive_entry_tests::first(RecoveryNativeEngineV1::GodotJolt4_7, true);
    source.declaration.maximum_descent_steps = 240;
    source.declaration.initialization.threshold_profile_id = partial::PRONE_PROFILE.to_owned();
    let g = compile_bounded_quadruped(source.declaration.initialization.descriptor.clone()).unwrap().geometry;
    source.observation.state.base_pose_world.position_m.y = 0.4 * g.initial_torso_center_y_m;
    partial::EntryRequest { schema_version: partial::ENTRY_REQUEST.to_owned(), passive_request: source, prior: None }
}

fn entry_advance(request: &mut partial::EntryRequest, receipt: &partial::EntryReceipt, height_ratio: f64) {
    let ledger = receipt.original_passive_receipt.memory.last_energy_ledger.clone();
    passive_entry_tests::advance(&mut request.passive_request, &receipt.original_passive_receipt, false);
    request.passive_request.observation.energy_balance = ledger;
    request.passive_request.energy_increment.passive_dissipation_j = 0.0;
    let g = compile_bounded_quadruped(request.passive_request.declaration.initialization.descriptor.clone()).unwrap().geometry;
    request.passive_request.observation.state.base_pose_world.position_m.y = height_ratio * g.initial_torso_center_y_m;
    request.prior = Some(receipt.memory.clone());
}

pub(crate) fn partial_handoff() -> partial::EntryReceipt {
    let mut request = entry_first();
    for count in 1..240 {
        let receipt = partial::select_entry(request.clone()).unwrap();
        assert_eq!(partial::EntryRoute::Waiting, receipt.memory.route);
        assert_eq!(count, receipt.memory.passive_memory.observations_seen);
        assert!(receipt.partial_memory.is_none() && receipt.partial_declaration.is_none());
        entry_advance(&mut request, &receipt, 0.4);
    }
    partial::select_entry(request).unwrap()
}

pub(crate) fn step_input(declaration: &partial::Declaration, memory: &partial::Memory) -> partial::StepRequest {
    let entry = &declaration.entry_request.passive_request;
    let mut observation = entry.observation.clone();
    let next = memory.last_semantic_step + 1;
    observation.task_id = partial::TASK.to_owned();
    observation.semantics_id = partial::SEMANTICS.to_owned();
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
    observation.center_of_mass.position_world_m.y = entry.observation.center_of_mass.position_world_m.y + 0.125;
    observation.energy_balance = memory.last_energy_ledger.clone();
    partial::StepRequest { schema_version: partial::STEP_REQUEST.to_owned(), declaration: declaration.clone(),
        memory: memory.clone(), observation, native_global_energy: None,
        energy_increment: RecoveryEnergyWorkIncrementV3 { source_measurement: true, semantic_step: next,
            sequence_index: next - entry.declaration.first_semantic_step + 1,
            applied_actuator_work_j: 0.0, signed_external_work_j: 0.0, signed_constraint_exchange_j: 0.0,
            signed_discrete_staging_exchange_j: 0.0, passive_dissipation_j: 0.0 } }
}

fn remove_one_support(request: &mut partial::StepRequest) {
    request.observation.state.ordered_contact_observations[0].presence = Some(false);
    request.observation.state.ordered_contact_observations[0].bears_support = Some(false);
    request.observation.ordered_foot_bearing_observations[0].bearing_normal_impulse_ns = 0.0;
}

#[test]
fn prospective_prone_profile_changes_only_standing_timeout_numeric_value() {
    let original = recovery_physical_development_threshold_profile_v1();
    let mut next = partial::prone_thresholds();
    assert_eq!(360, next.per_phase_timeout_steps.stance_dwell);
    assert_eq!(60, next.stance_dwell_steps);
    assert_eq!(1200, next.total_timeout_steps);
    next.profile_id = original.profile_id.clone(); next.scope = original.scope.clone();
    next.per_phase_timeout_steps.stance_dwell = 240;
    assert_eq!(original, next);
    let initialized = initialize_recovery_v2(entry_first().passive_request.declaration.initialization).unwrap();
    assert_eq!(RecoverySupportStatusV1::SupportedExact, initialized.support_status);
}

#[test]
fn partial_handoff_preserves_original_timeout_energy_and_nonprone_history() {
    let result = partial_handoff();
    assert_eq!(partial::EntryRoute::Partial, result.memory.route);
    assert_eq!(12, result.memory.consecutive_partial_samples);
    assert_eq!(RecoveryPassiveEntryStatusV1::DescentTimeout, result.original_passive_receipt.memory.status);
    assert!(result.original_passive_receipt.canonical_memory.is_none());
    assert!(!result.original_passive_receipt.classification.entry_prone_gate);
    let memory = result.partial_memory.unwrap();
    assert_eq!(RecoveryPhaseV1::EstablishDistalSupport, memory.phase);
    assert!(memory.ordered_completed_phases.is_empty());
    assert_eq!(memory.last_energy_ledger, result.original_passive_receipt.memory.last_energy_ledger);
    assert_eq!(2.0, memory.last_energy_ledger.cumulative_signed_external_work_j);
    assert!(!result.energy_epoch_reset && !result.prone_to_standing_claimed && !result.physical_acceptance_authority);
}

#[test]
fn partial_samples_must_be_consecutive_and_genuine_prone_keeps_priority() {
    let mut request = entry_first();
    for count in 1..240 {
        let receipt = partial::select_entry(request.clone()).unwrap();
        entry_advance(&mut request, &receipt, if count == 234 { 0.6 } else { 0.4 });
    }
    let result = partial::select_entry(request).unwrap();
    assert_eq!(partial::EntryRoute::Timeout, result.memory.route);
    assert!(result.partial_memory.is_none());
    let mut request = entry_first();
    let receipt = partial::select_entry(request.clone()).unwrap();
    entry_advance(&mut request, &receipt, 0.2);
    let torso = request.passive_request.observation.ordered_body_clearance_observations.iter_mut()
        .find(|b| b.body_id == "torso").unwrap();
    torso.ventral_surface_contact = true; torso.nonfoot_contact_present = true;
    torso.minimum_nonfoot_clearance_m = 0.0;
    torso.engine_contact_ids = vec!["synthetic_partial_entry_prone_contact".to_owned()];
    let result = partial::select_entry(request).unwrap();
    assert_eq!(partial::EntryRoute::Prone, result.memory.route);
    assert!(result.partial_memory.is_none());
    assert_eq!(RecoveryPhaseV1::ConfirmProne, result.original_passive_receipt.canonical_memory.unwrap().phase);
}

#[test]
fn entry_selector_rejects_wrong_profile_nonzero_actuation_and_reused_terminal_memory() {
    for mutation in 0..4 {
        let mut request = entry_first();
        if mutation == 0 { request.passive_request.declaration.initialization.threshold_profile_id = crate::recovery_runtime::EXACT_S169_DEVELOPMENT_THRESHOLD_PROFILE_ID.to_owned(); }
        if mutation == 1 { request.passive_request.observation.applied_actuation.ordered_applied_impulses[0].applied_angular_impulse_nms = 0.0001; }
        if mutation == 2 { request.passive_request.declaration.maximum_descent_steps = 239; }
        if mutation == 3 {
            let terminal = partial_handoff();
            request.passive_request.prior = Some(terminal.memory.passive_memory.clone());
            request.prior = Some(terminal.memory);
        }
        assert!(partial::select_entry(request).is_err());
    }
}

#[test]
fn distinct_partial_supervisor_requires_the_whole_order_and_sixty_consecutive_samples() {
    let result = partial_handoff();
    let declaration = result.partial_declaration.unwrap();
    let mut memory = result.partial_memory.unwrap();
    for expected in [RecoveryPhaseV1::RaiseBody, RecoveryPhaseV1::StanceHandoff, RecoveryPhaseV1::StanceDwell] {
        let result = partial::step(step_input(&declaration, &memory)).unwrap();
        assert_eq!(expected, result.next_phase); memory = result.memory;
    }
    for count in 1..60 {
        let result = partial::step(step_input(&declaration, &memory)).unwrap();
        assert_eq!(count, result.memory.standing_samples_observed);
        assert!(!result.partial_fall_standing_complete); memory = result.memory;
    }
    let mut interruption = step_input(&declaration, &memory); remove_one_support(&mut interruption);
    let reset = partial::step(interruption).unwrap();
    assert_eq!(0, reset.memory.standing_samples_observed); memory = reset.memory;
    for count in 1..=60 {
        let result = partial::step(step_input(&declaration, &memory)).unwrap();
        assert_eq!(count == 60, result.partial_fall_standing_complete);
        assert!(!result.prone_to_standing_claimed && !result.energy_epoch_reset && !result.physical_acceptance_authority);
        memory = result.memory;
    }
    assert_eq!(RecoveryPhaseV1::Complete, memory.phase);
    assert_eq!(4, memory.ordered_completed_phases.len());
    assert!(!memory.ordered_completed_phases.contains(&RecoveryPhaseV1::ConfirmProne));
    assert!(partial::step(step_input(&declaration, &memory)).is_err());
}

#[test]
fn partial_task_rejects_identity_clock_energy_reset_phase_skip_and_false_completion() {
    let result = partial_handoff(); let declaration = result.partial_declaration.unwrap();
    let memory = result.partial_memory.unwrap();
    for mutation in 0..7 {
        let mut request = step_input(&declaration, &memory);
        if mutation == 0 { request.observation.task_id = CANONICAL_PRONE_TO_STANDING_TASK_ID.to_owned(); }
        if mutation == 1 { request.observation.semantic_step += 1; }
        if mutation == 2 { request.observation.energy_balance.initial_mechanical_energy_j += 1.0; request.observation.energy_balance.current_mechanical_energy_j += 1.0; }
        if mutation == 3 { request.memory.phase = RecoveryPhaseV1::StanceDwell; }
        if mutation == 4 { request.observation.controller_ownership = owner(RecoveryArmKindV1::MatchedZeroCommand, false); }
        if mutation == 5 { request.energy_increment.sequence_index += 1; }
        if mutation == 6 { request.observation.energy_balance.cumulative_signed_discrete_staging_exchange_j += 0.125; request.observation.energy_balance.current_mechanical_energy_j += 0.125; }
        assert!(partial::step(request).is_err(), "mutation {mutation}");
    }
    let raised = partial::step(step_input(&declaration, &memory)).unwrap();
    let mut too_little_rise = step_input(&declaration, &raised.memory);
    too_little_rise.observation.center_of_mass.position_world_m.y = declaration.entry_request.passive_request.observation.center_of_mass.position_world_m.y + 0.09;
    let result = partial::step(too_little_rise).unwrap();
    assert_eq!(RecoveryPhaseV1::RaiseBody, result.next_phase);
    assert!(!result.partial_fall_standing_complete);
}

#[test]
fn prospective_standing_budget_allows_command_240_but_refuses_360_without_sixty_good_samples() {
    let entry = partial_handoff(); let declaration = entry.partial_declaration.unwrap();
    let initial = entry.partial_memory.unwrap(); let mut memory = initial.clone();
    for _ in 0..3 { memory = partial::step(step_input(&declaration, &memory)).unwrap().memory; }
    assert_eq!(RecoveryPhaseV1::StanceDwell, memory.phase);
    // Explicit synthetic boundary counters, not a retained physical history.
    for (elapsed, good, expected) in [(239,47,RecoveryPhaseV1::StanceDwell),
        (359,47,RecoveryPhaseV1::Failed),(359,59,RecoveryPhaseV1::Complete)] {
        let mut boundary = memory.clone();
        boundary.phase_steps_observed = elapsed;
        boundary.total_steps_observed = 3 + elapsed;
        boundary.standing_samples_observed = good;
        boundary.last_semantic_step = initial.last_semantic_step + u64::from(boundary.total_steps_observed);
        boundary.last_host_step_after = initial.last_host_step_after + u64::from(boundary.total_steps_observed);
        let result = partial::step(step_input(&declaration, &boundary)).unwrap();
        assert_eq!(expected, result.next_phase);
        assert_eq!(expected == RecoveryPhaseV1::Complete, result.partial_fall_standing_complete);
        if expected == RecoveryPhaseV1::Failed {
            assert_eq!(Some("phase_timeout:stance_dwell"), result.memory.terminal_failure_code.as_deref());
        }
    }
}
