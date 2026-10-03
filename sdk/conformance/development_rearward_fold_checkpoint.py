"""Read-only closure of the first V7 physical attempt; never launches an engine.

Reopen the complete original publication/replay chain, then describe its native
observations against the run's unchanged support rule. This does not repair or
reclassify any predecessor, choose a new threshold, or claim successful recovery.
"""
import json
import math
from pathlib import Path

import development_recovery_smoke as smoke
import development_passive_entry_profile as entry

ATTEMPT = 'e93af378ec5e4483b208fa441d9945cb'
SOURCE = '6c54bd925ba9ef19bc81505730a3c193d2aa2abd'
EVIDENCE = entry.EVIDENCE / ('development-recovery-smoke-' + ATTEMPT)
RECORD = entry.ROOT / 'sdk/development_rearward_fold_smoke_checkpoint_v1.json'
RULE = 'sdk/recovery/r24d17_native_recovery_runtime_and_physical_profile_contract_v1.json'
PROFILE = 'sdk/development_rearward_fold_profile_v1.json'


def committed(relative, source_commit=SOURCE):
    return entry.subprocess.check_output(['git', 'show', source_commit + ':' + relative],
        cwd=entry.ROOT, creationflags=entry.subprocess.CREATE_NO_WINDOW)


def summarize(report, *, source_commit=SOURCE, profile_path=PROFILE):
    # Explicit successor selection reuses contact arithmetic, not V7 evidence.
    # Defaults still reproduce the original immutable V7 closure exactly.
    profile_raw = committed(profile_path, source_commit)
    profile = entry.packet.parse_json(profile_raw.decode())
    if profile.get('schema_version') in ('sporespore_development_recovery_candidate_profile_v1',
                                       'sporespore_development_recovery_candidate_profile_v2'):
        fixed = entry.packet.parse_json(committed(
            'sdk/development_recovery_candidate_contract_v1.json', source_commit).decode())
        smoke.require(entry.packet.same(report.get('candidate_profile'), dict(
            resource='res://' + profile_path, raw_sha256=entry.digest(profile_raw))),
            'CANDIDATE_SUMMARY_PROFILE_BINDING')
        profile = dict(profile, setup_controller_id=fixed['setup_controller_id'])
    retained = report['passive_entry']
    for key in ('setup_controller_id', 'post_kick_controller_id'):
        smoke.require(retained[key] == profile[key], 'V7_SUMMARY_CONTROLLER_' + key)
    contract = entry.packet.parse_json(committed(RULE, source_commit).decode())
    threshold = next(row['value'] for row in contract['threshold_profile']['thresholds']
                     if row['threshold_id'] == 'distal_bearing_minimum_impulse_ns')
    phases = {}
    samples = []
    transitions = []
    for packet in retained['canonical_packets']:
        receipt = packet['step_receipt']
        phase = receipt['prior_phase']
        classification = receipt['classification']
        bound = entry.packet.parse_json(packet['collection_transport']['source_links']['bound_observation']['utf8_text'])
        observation = bound['observation_v3']
        feet = observation['ordered_foot_bearing_observations']
        contacts = observation['state']['ordered_contact_observations']
        smoke.require(len(feet) == len(contacts) == 4, 'V7_SUMMARY_CONTACT_POPULATION')
        bearing = sum(contact['presence'] is True and contact['bears_support'] is True
                      and foot['ordinary_unilateral_contact'] is True
                      and foot['bearing_normal_impulse_ns'] >= threshold
                      for contact, foot in zip(contacts, feet))
        smoke.require(classification['distal_support_gate'] is (bearing == 4), 'V7_SUMMARY_SUPPORT_RECOMPUTATION')
        sample = dict(global_step=packet['global_semantic_step'], phase=phase,
            feet_meeting_existing_support_requirement=bearing,
            torso_up_dot=classification['torso_up_dot'],
            torso_tilt_degrees=math.degrees(math.acos(max(-1.0, min(1.0, classification['torso_up_dot'])))),
            torso_height_ratio=classification['torso_height_ratio'],
            angular_speed_rad_s=classification['terminal_angular_speed_rad_s'],
            linear_speed_m_s=classification['terminal_linear_speed_m_s'],
            raised_body=classification['raised_body_gate'], stable_stance=classification['stable_stance_gate'],
            no_actuation_requested=packet['application']['no_actuation_requested'])
        samples.append(sample)
        if phase not in phases:
            phases[phase] = dict(phase=phase, first_step=sample['global_step'], last_step=sample['global_step'],
                                sample_count=0, support_samples=0, raised_samples=0, stable_samples=0)
        group = phases[phase]
        group['last_step'] = sample['global_step']
        group['sample_count'] += 1
        group['support_samples'] += int(bearing == 4)
        group['raised_samples'] += int(sample['raised_body'])
        group['stable_samples'] += int(sample['stable_stance'])
        if packet['memory_after']['phase'] != phase:
            transitions.append(dict(sample, next_phase=packet['memory_after']['phase']))
    smoke.require(bool(samples), 'V7_SUMMARY_EMPTY_CANONICAL_POPULATION')
    state = report['retained_arm']['orchestrator_state']
    support_steps = [sample['global_step'] for sample in samples if sample['feet_meeting_existing_support_requirement'] == 4]
    return dict(prone_handoff_global_step=state['canonical_start_global_step'],
        first_active_global_step=next(s['global_step'] for s in samples if not s['no_actuation_requested']),
        entry_observation_count=len(retained['entry_packets']), canonical_observation_count=len(samples),
        phase_summary=list(phases.values()), phase_transitions=transitions,
        existing_per_foot_bearing_requirement_ns=threshold, four_foot_support_global_steps=support_steps,
        first_support_loss_after_support_global_step=next((s['global_step'] for s in samples
            if support_steps and s['global_step'] > support_steps[0] and s['feet_meeting_existing_support_requirement'] != 4), None),
        first_torso_up_vector_below_horizontal_global_step=next((s['global_step'] for s in samples if s['torso_up_dot'] < 0.0), None),
        peak_height_sample=max(samples, key=lambda s: s['torso_height_ratio']), terminal_sample=samples[-1],
        stable_stance_sample_count=sum(int(s['stable_stance']) for s in samples),
        walking_resume_step_count=state['walking_resume_step_count'], terminal_reason=state['terminal_reason'])


def observe():
    checkpoint = smoke.retained_checkpoint(EVIDENCE)
    smoke.require(checkpoint['attempt_id'] == ATTEMPT and checkpoint['source_snapshot']['head'] == SOURCE
                  and checkpoint['source_snapshot']['dirty'] is False, 'V7_CLOSURE_SOURCE')
    report_path = EVIDENCE / 'children' / smoke.ROLES[1] / 'worker_report.json'
    report = smoke.read(report_path)
    metrics = summarize(report)
    smoke.require(report['solver_step_count'] == 653 and metrics['terminal_reason'] == 'phase_timeout:stance_dwell'
                  and metrics['stable_stance_sample_count'] == metrics['walking_resume_step_count'] == 0,
                  'V7_CLOSURE_OBSERVED_NEGATIVE')
    children = [{key: value for key, value in child.items() if key != 'step_cost_profile'}
                for child in checkpoint['observed']['children']]
    rules = []
    for relative in (RULE, PROFILE, 'sdk/development_rearward_fold_support_v1.json', 'sdk/core/src/recovery_runtime.rs'):
        raw = committed(relative)
        rules.append(dict(path=relative, source_commit=SOURCE, byte_length=len(raw), raw_sha256=entry.digest(raw)))
    return dict(schema_version='sporespore_development_rearward_fold_smoke_checkpoint_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
                          authority_mode='retained_development_physical_result', question_class='development'),
        status='closed_consumed_valid_development_behavior_negative', attempt_id=ATTEMPT,
        evidence_root=EVIDENCE.as_posix(), source_snapshot=checkpoint['source_snapshot'],
        retained_population=checkpoint['retained_population'], artifact_sha256=checkpoint['artifact_sha256'],
        elapsed_seconds=checkpoint['elapsed_seconds'], children=children, rule_sources=rules,
        kicked_report=entry.runtime.file_identity(report_path), whole_original_attempt_audit_passed=True,
        both_independent_report_replays_passed=True, world_count=2,
        solver_step_count=checkpoint['observed']['total_solver_steps'], metrics=metrics,
        descriptive_conclusion='The new trace briefly reaches four-foot support and body lift, then loses support and overturns. No stable standing or walking resume is recorded.',
        causal_attribution_proven=False, successful_recovery_proven=False, complete_route_proven=False,
        physical_acceptance_authority=False, release_authority=False,
        repeat_consumed_attempt_permitted=False, new_world_build_count=0, new_solver_step_count=0)


if __name__ == '__main__':
    print(json.dumps(observe(), indent=2, allow_nan=False))
