"""Cold, profile-driven description of completed development attempts.

Consumes original publication and replay receipts. Never reruns an engine or
rewrites a consumed attempt. Single-child diagnostics stay non-comparative.
"""
import argparse
import json
from pathlib import Path

import development_rearward_fold_checkpoint as prior

entry = prior.entry
smoke = prior.smoke
CONTRACT = 'sdk/development_recovery_candidate_contract_v1.json'


def support_geometry(report, metrics, distal_body_origins=False):
    """Count all support samples; selected rows illustrate the complete counts."""
    minimum = metrics['existing_per_foot_bearing_requirement_ns']
    feet = {}
    rows = []
    first_active = metrics['first_active_global_step']
    packets = report['passive_entry']['canonical_packets']
    for packet in packets:
        step = packet['global_semantic_step']
        phase = packet['step_receipt']['prior_phase']
        observation = entry.packet.parse_json(packet['collection_transport']['source_links']
            ['bound_observation']['utf8_text'])['observation_v3']
        trace = report['retained_arm']['trace_rows'][step - 1]
        smoke.require(trace['global_semantic_step'] == step, 'CANDIDATE_GEOMETRY_TRACE_STEP')
        qualified = []
        for foot, contact in zip(observation['ordered_foot_bearing_observations'],
                                 observation['state']['ordered_contact_observations']):
            name = foot['contact_site_id']
            smoke.require(name == contact['contact_site_id'], 'CANDIDATE_GEOMETRY_CONTACT_ORDER')
            bears = (contact['presence'] is True and contact['bears_support'] is True
                     and foot['ordinary_unilateral_contact'] is True
                     and foot['bearing_normal_impulse_ns'] >= minimum)
            if bears:
                qualified.append(name)
            if phase == 'establish_distal_support':
                group = feet.setdefault(name, dict(contact_site_id=name,
                    qualifying_sample_count=0, first_qualifying_step=None, last_qualifying_step=None))
                if bears:
                    group['qualifying_sample_count'] += 1
                    if group['first_qualifying_step'] is None:
                        group['first_qualifying_step'] = step
                    group['last_qualifying_step'] = step
        classification = packet['step_receipt']['classification']
        smoke.require(classification['distal_support_gate'] is (len(qualified) == 4),
                      'CANDIDATE_GEOMETRY_SUPPORT_RECOMPUTATION')
        rows.append(dict(global_step=step, phase=phase, qualifying_feet=qualified,
            joint_positions_rad=[j['position_rad'] for j in observation['state']['ordered_joint_observations']],
            requested_motor_velocities_rad_s=[i['canonical_target_velocity_rad_s']
                for i in packet['application'].get('ordered_intents', [])],
            foot_positions_world_m=trace['foot_position_world_m_by_limb'],
            torso_position_world_m=trace['torso_position_world_m'],
            torso_up_dot=classification['torso_up_dot'],
            angular_speed_rad_s=classification['terminal_angular_speed_rad_s']))
    event_steps = {first_active - 1, first_active, rows[-1]['global_step'],
        metrics['first_torso_up_vector_below_horizontal_global_step'],
        max(rows, key=lambda row: row['angular_speed_rad_s'])['global_step']}
    if distal_body_origins:
        # New descriptive schema only: retain the support/rise boundary rather
        # than relying on a ten-step sample to happen to capture a brief contact.
        event_steps.update(metrics['four_foot_support_global_steps'])
        event_steps.add(metrics['first_support_loss_after_support_global_step'])
        for previous, current in zip(rows, rows[1:]):
            if current['phase'] != previous['phase']:
                event_steps.update((previous['global_step'], current['global_step']))
    samples = [row for row in rows if row['global_step'] in event_steps
               or (row['global_step'] >= first_active and (row['global_step'] - first_active) % 10 == 0)]
    result = dict(per_foot_support=list(feet.values()), samples=samples,
        sample_selection='Last pre-actuation row, first active row, every tenth active-or-later row, first horizontal crossing, peak angular speed, and terminal row; deduplicated in trace order.',
        foot_position_limitation='Retained foot-site positions, not floor clearance or proof of load. Qualifying load is counted separately using the unchanged native contact rule.',
        velocity_limitation='Applied motor velocity requests, not measured joint velocities or guaranteed motion.',
        causal_attribution_proven=False)
    if distal_body_origins:
        for row in samples:
            row['distal_body_origins_world_m'] = row.pop('foot_positions_world_m')
        result['foot_position_limitation'] = ('Historical trace field foot_position_world_m_by_limb '
            'contains distal rigid-body origins, not contact-site centers, floor clearance, or proof of load. '
            'Native qualifying load is counted separately using the unchanged contact rule.')
        result['sample_selection'] += ' Also every four-foot support row, first subsequent support loss, and both sides of each phase transition.'
    return result


def walking_control_diagnostics(report):
    """Describe all retained walking inputs; never replace the original evaluator."""
    retained = report['development_walking_entry']
    sources = retained['rows']
    trace = {r['global_semantic_step']: r for r in report['retained_arm']['trace_rows']}
    walk = next(s for s in report['retained_arm']['walking_sessions'] if s['evaluation_segment_id'] == 'walking_resume')
    smoke.require(len(sources) == retained['sample_count'] == walk['evaluation']['trace_row_count'], 'WALKING_SOURCE_POPULATION')
    by_limb = {}
    for limb in ('front_left', 'front_right', 'rear_left', 'rear_right'):
        observations = [next(o for o in r['request']['state']['ordered_contact_observations'] if o['contact_site_id'] == limb + '_foot') for r in sources]
        by_limb[limb] = dict(sample_count=len(sources), controller_present_count=sum(o['presence'] is True for o in observations),
            controller_support_count=sum(o['bears_support'] is True for o in observations),
            native_precommand_contact_count=sum(trace[r['measured_global_step']]['contact_by_limb'][limb] is True for r in sources),
            terminal_gate_timeout_count=int(next(m['gate_timeout_count'] for m in sources[-1]['native_output']['next_memory']['ordered_limb_memory'] if m['limb_id'] == limb)))
    first_joints = sources[0]['request']['state']['ordered_joint_observations']
    first_commands = sources[0]['native_output']['actuation']['ordered_commands']
    ordered_steps = [trace[r['commanded_global_step']] for r in sources]
    def first_step(predicate):
        return next((r['global_semantic_step'] for r in ordered_steps if predicate(r)), None)
    return dict(schema_version='sporespore_development_walking_control_diagnosis_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='post_exposure_retained_data_diagnosis', question_class='development'),
        sample_count=len(sources), first_commanded_global_step=sources[0]['commanded_global_step'], last_commanded_global_step=sources[-1]['commanded_global_step'],
        first_gait_amplitude=sources[0]['request']['command']['gait_amplitude'],
        first_full_amplitude_global_step=next((r['commanded_global_step'] for r in sources if r['request']['command']['gait_amplitude'] == 1), None),
        full_amplitude_sample_count=sum(r['request']['command']['gait_amplitude'] == 1 for r in sources),
        maximum_first_command_target_jump_rad=max(abs(c['requested_target_position_rad']-j['position_rad']) for j,c in zip(first_joints,first_commands)),
        first_precommand_native_contact_map=trace[sources[0]['measured_global_step']]['contact_by_limb'],
        per_limb_contact_observations=by_limb,
        contact_comparison_limit='Walking semantic-contact presence/support versus time-aligned native trace contact presence, not a claim that their load qualification rules are identical.',
        first_tilt_limit_exceeded_global_step=first_step(lambda r:r['torso_tilt_rad'] > walk['evaluation']['fixed_thresholds']['maximum_tilt_rad']),
        first_no_foot_contact_global_step=first_step(lambda r:not any(r['contact_by_limb'].values())),
        first_torso_contact_global_step=first_step(lambda r:r['torso_contact']),
        original_evaluator_timeout_free_flag=walk['evaluation']['walking_gate_receipts']['contact_gating_completed_without_timeout'],
        actual_native_gate_timeout_total=sum(r['terminal_gate_timeout_count'] for r in by_limb.values()),
        timeout_flag_limit='The frozen evaluator tests summary.ok and step count, not native gate_timeout_count. Preserve its original flag; do not treat it as proof of zero native timeouts.',
        additional_native_physics_read_count=retained['additional_native_physics_read_count'],
        original_evaluation_replaced=False, causal_attribution_proven=False, physical_acceptance_authority=False, release_authority=False)


def walking_contact_diagnostics(report):
    """Keep geometric contact and native load-bearing flags distinct and finite."""
    retained = report['development_walking_contacts']
    rows = retained['rows']
    arm = report['retained_arm']
    trace = {row['global_semantic_step']: row for row in arm['trace_rows']}
    expected = [row for row in arm['trace_rows'] if row.get('walking_segment_id') in
                ('walking_prefix', 'walking_resume', 'matched_continuation')]
    smoke.require(retained['sample_count'] == len(rows) == len(expected), 'WALKING_CONTACT_POPULATION')
    segments = {}
    for segment in ('walking_prefix', 'walking_resume', 'matched_continuation'):
        selected = [row for row in rows if row['segment_id'] == segment]
        by_limb = {}
        for limb in ('front_left', 'front_right', 'rear_left', 'rear_right'):
            contacts = [next(c for c in row['controller_contacts'] if c['contact_site_id'] == limb + '_foot') for row in selected]
            sources = [next(s for s in row['sources'] if s['limb_id'] == limb) for row in selected]
            native = [trace[row['commanded_global_step'] - 1]['contact_by_limb'][limb] for row in selected]
            by_limb[limb] = dict(controller_contact_presence_count=sum(c['presence'] for c in contacts),
                controller_bears_support_count=sum(c['bears_support'] for c in contacts),
                native_precommand_bears_support_count=sum(native),
                support_flag_disagreement_count=sum(c['bears_support'] != n for c, n in zip(contacts, native)),
                callback_sequence_first=sources[0]['callback_sequence'] if sources else None,
                callback_sequence_last=sources[-1]['callback_sequence'] if sources else None,
                callback_matches_precommand_clock=all(s['callback_sequence'] == r['commanded_global_step'] - 1 for s,r in zip(sources, selected)))
        segments[segment] = dict(sample_count=len(selected), by_limb=by_limb)
    stance = [p for p in report['passive_entry']['canonical_packets'] if p['step_receipt']['prior_phase'] == 'stance_dwell']
    unstable = [p for p in stance if not p['step_receipt']['classification']['stable_stance_gate']]
    return dict(schema_version='sporespore_development_walking_contact_diagnosis_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='post_exposure_retained_data_diagnosis', question_class='development'),
        sample_count=len(rows), segments=segments,
        terminal_timeout_diagnostics_by_session=retained['terminal_timeout_diagnostics_by_session'],
        stance_sample_count=len(stance), stable_stance_sample_count=sum(p['step_receipt']['classification']['stable_stance_gate'] for p in stance),
        terminal_consecutive_stable_samples=stance[-1]['step_receipt']['memory']['stance_dwell_steps_observed'] if stance else None,
        last_unstable_global_step=unstable[-1]['global_semantic_step'] if unstable else None,
        last_unstable_classification=unstable[-1]['step_receipt']['classification'] if unstable else None,
        native_trace_flag_definition='bears_support, not geometric contact presence',
        adapter_support_flag_definition='semantic shape-floor contact existence, not force-qualified load bearing',
        callback_impulse_samples_retained=False, contact_channels_equivalent=False,
        shape_lookup_correction_proves_load_qualification=False,
        additional_native_physics_read_count=0, physical_acceptance_authority=False, release_authority=False)


def native_walking_contact_diagnostics(report):
    """Describe the new native-input path without reinterpreting old selectors."""
    retained = report['development_native_walking_contacts']
    rows = retained['rows']
    trace = {row['global_semantic_step']: row for row in report['retained_arm']['trace_rows']}
    expected = [row for row in trace.values() if row.get('walking_segment_id') in
                ('walking_prefix', 'walking_resume', 'matched_continuation')]
    smoke.require(retained['sample_count'] == len(rows) == len(expected), 'NATIVE_WALKING_CONTACT_POPULATION')
    segments = {}
    for segment in ('walking_prefix', 'walking_resume', 'matched_continuation'):
        selected = [row for row in rows if row['segment_id'] == segment]
        by_limb = {}
        for index, limb in enumerate(('front_left', 'front_right', 'rear_left', 'rear_right')):
            contacts = [row['controller_contacts'][index] for row in selected]
            native = [trace[row['commanded_global_step'] - 1]['contact_by_limb'][limb] for row in selected]
            by_limb[limb] = dict(controller_contact_presence_count=sum(c['presence'] for c in contacts),
                controller_bears_support_count=sum(c['bears_support'] for c in contacts),
                native_precommand_bears_support_count=sum(native),
                support_flag_disagreement_count=sum(c['bears_support'] != n for c, n in zip(contacts, native)))
        segments[segment] = dict(sample_count=len(selected), by_limb=by_limb)
    sources_exact = all(row['controller_contacts'] == row['native_source']['observation']['state']['ordered_contact_observations']
                        and row['native_source']['precommand_trace'] == trace[row['commanded_global_step'] - 1] for row in rows)
    smoke.require(sources_exact, 'NATIVE_WALKING_CONTACT_SOURCE_LINK')
    support = [p for p in report['passive_entry']['canonical_packets'] if p['step_receipt']['prior_phase'] == 'establish_distal_support']
    inverted = [p for p in support if p['step_receipt']['classification']['torso_up_dot'] < 0]
    return dict(schema_version='sporespore_development_native_walking_contact_diagnosis_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='post_exposure_retained_data_diagnosis', question_class='development'),
        sample_count=len(rows), segments=segments, retained_source_and_precommand_trace_links_exact=sources_exact,
        terminal_timeout_diagnostics_by_session=retained['terminal_timeout_diagnostics_by_session'],
        support_establishment=dict(sample_count=len(support),
            first_global_step=support[0]['global_semantic_step'] if support else None,
            last_global_step=support[-1]['global_semantic_step'] if support else None,
            distal_support_gate_sample_count=sum(p['step_receipt']['classification']['distal_support_gate'] for p in support),
            first_inverted_global_step=inverted[0]['global_semantic_step'] if inverted else None,
            inversion_definition='torso_up_dot < 0: body up axis below the world horizontal, descriptive geometry only',
            first_classification=support[0]['step_receipt']['classification'] if support else None,
            terminal_classification=support[-1]['step_receipt']['classification'] if support else None),
        adapter_support_flag_definition='unchanged native qualified foot-contact observation, not whole-shape contact existence',
        physical_cause_of_rollover_established=False, additional_native_physics_read_count=0,
        physical_acceptance_authority=False, release_authority=False)


def walking_entry_rule_sources(schedule, source):
    """Resolve the selected contract from the frozen tree, not today's selector."""
    selected = schedule.get('walking_entry_profile_id')
    if not selected:
        return []
    relative = 'sdk/development/recovery_walking_entry_contract_v1.json'
    raw = prior.committed(relative, source)
    if entry.packet.parse_json(raw.decode())['profile_id'] != selected:
        relative = 'sdk/development/recovery_clocked_walking_entry_contract_v1.json'
        raw = prior.committed(relative, source)
    first_swing = False
    if entry.packet.parse_json(raw.decode())['profile_id'] != selected:
        relative = 'sdk/development/recovery_first_swing_walking_entry_contract_v1.json'
        raw = prior.committed(relative, source)
        first_swing = True
    selected_contract = entry.packet.parse_json(raw.decode())
    if selected_contract['profile_id'] != selected:
        relative = 'sdk/development/recovery_joint_bounded_walking_entry_contract_v1.json'
        raw = prior.committed(relative, source)
        selected_contract = entry.packet.parse_json(raw.decode())
    contact_from_start = False
    if selected_contract['profile_id'] != selected:
        relative = 'sdk/development/recovery_contact_gated_walking_entry_contract_v1.json'
        raw = prior.committed(relative, source)
        selected_contract = entry.packet.parse_json(raw.decode())
        contact_from_start = True
    if selected_contract['profile_id'] != selected:
        relative = 'sdk/development/recovery_front_left_first_walking_entry_contract_v1.json'
        raw = prior.committed(relative, source)
        selected_contract = entry.packet.parse_json(raw.decode())
    if selected_contract['profile_id'] != selected:
        relative = 'sdk/development/recovery_swing_end_walking_entry_contract_v1.json'
        raw = prior.committed(relative, source)
        selected_contract = entry.packet.parse_json(raw.decode())
    if selected_contract['profile_id'] != selected:
        relative = 'sdk/development/recovery_bounded_support_walking_entry_contract_v1.json'
        raw = prior.committed(relative, source)
        selected_contract = entry.packet.parse_json(raw.decode())
    if selected_contract['profile_id'] != selected:
        relative = 'sdk/development/recovery_floor_support_walking_entry_contract_v1.json'
        raw = prior.committed(relative, source)
        selected_contract = entry.packet.parse_json(raw.decode())
    if selected_contract['profile_id'] != selected:
        relative = 'sdk/development/recovery_feasible_support_walking_entry_contract_v1.json'
        raw = prior.committed(relative, source)
        selected_contract = entry.packet.parse_json(raw.decode())
    if selected_contract['profile_id'] != selected:
        relative = 'sdk/development/recovery_smooth_swing_walking_entry_contract_v1.json'
        raw = prior.committed(relative, source)
        selected_contract = entry.packet.parse_json(raw.decode())
    if selected_contract['profile_id'] != selected:
        relative = 'sdk/development/recovery_reference_velocity_walking_entry_contract_v1.json'
        raw = prior.committed(relative, source)
        selected_contract = entry.packet.parse_json(raw.decode())
    if selected_contract['profile_id'] != selected:
        relative = 'sdk/development/recovery_wave_velocity_walking_entry_contract_v1.json'
        raw = prior.committed(relative, source)
        selected_contract = entry.packet.parse_json(raw.decode())
    if selected_contract['profile_id'] != selected:
        relative = 'sdk/development/recovery_airborne_reference_walking_entry_contract_v1.json'
        raw = prior.committed(relative, source)
        selected_contract = entry.packet.parse_json(raw.decode())
    if selected_contract['profile_id'] != selected:
        relative = 'sdk/development/recovery_absent_contact_reference_walking_entry_contract_v1.json'
        raw = prior.committed(relative, source)
        selected_contract = entry.packet.parse_json(raw.decode())
    if selected_contract['profile_id'] != selected:
        relative = 'sdk/development/recovery_upright_stance_walking_entry_contract_v1.json'
        raw = prior.committed(relative, source)
        selected_contract = entry.packet.parse_json(raw.decode())
    if selected_contract['profile_id'] != selected:
        relative = 'sdk/development/recovery_upright_stance_walking_entry_contract_v2.json'
        raw = prior.committed(relative, source)
        selected_contract = entry.packet.parse_json(raw.decode())
    if selected_contract['profile_id'] != selected:
        relative = 'sdk/development/recovery_stance_latch_walking_entry_contract_v1.json'
        raw = prior.committed(relative, source)
        selected_contract = entry.packet.parse_json(raw.decode())
    if selected_contract['profile_id'] != selected:
        relative = 'sdk/development/recovery_support_progression_walking_entry_contract_v1.json'
        raw = prior.committed(relative, source)
        selected_contract = entry.packet.parse_json(raw.decode())
    if selected_contract['profile_id'] != selected:
        relative = 'sdk/development/recovery_support_hold_posture_walking_entry_contract_v1.json'
        raw = prior.committed(relative, source)
        selected_contract = entry.packet.parse_json(raw.decode())
    if selected_contract['profile_id'] != selected:
        relative = 'sdk/development/recovery_remaining_support_release_walking_entry_contract_v1.json'
        raw = prior.committed(relative, source)
        selected_contract = entry.packet.parse_json(raw.decode())
    if selected_contract['profile_id'] != selected:
        relative = 'sdk/development/recovery_startup_reference_velocity_walking_entry_contract_v1.json'
        raw = prior.committed(relative, source)
        selected_contract = entry.packet.parse_json(raw.decode())
    if selected in ('r10g_v50_joint_bounded_contact_gated_v1', 'r10g_v50_joint_bounded_contact_gated_v2', 'r10g_v50_joint_bounded_contact_gated_v3', 'r10h_v50_joint_bounded_contact_gated_v1', 'r10i_v50_joint_bounded_contact_gated_v1', 'r10j_v50_joint_bounded_contact_gated_v1', 'r10k_v51_joint_bounded_contact_gated_v1', 'r10l_v52_joint_bounded_contact_gated_v1', 'r10m_v53_joint_bounded_contact_gated_v1', 'r10n_v54_joint_bounded_contact_gated_v1', 'r10o_v55_joint_bounded_contact_gated_v1'):
        relative = 'sdk/recovery/r10o_v55_walking_entry_contract_v2.json' if selected == 'r10o_v55_joint_bounded_contact_gated_v1' else 'sdk/recovery/r10n_v54_walking_entry_contract_v2.json' if selected == 'r10n_v54_joint_bounded_contact_gated_v1' else 'sdk/recovery/r10m_v53_walking_entry_contract_v1.json' if selected == 'r10m_v53_joint_bounded_contact_gated_v1' else 'sdk/recovery/r10l_v52_walking_entry_contract_v6.json' if selected == 'r10l_v52_joint_bounded_contact_gated_v1' else 'sdk/recovery/r10k_v51_walking_entry_contract_v23.json' if selected == 'r10k_v51_joint_bounded_contact_gated_v1' else 'sdk/recovery/r10j_v50_walking_entry_contract_v6.json' if selected == 'r10j_v50_joint_bounded_contact_gated_v1' else 'sdk/recovery/r10i_v50_walking_entry_contract_v4.json' if selected == 'r10i_v50_joint_bounded_contact_gated_v1' else 'sdk/recovery/r10h_v50_walking_entry_contract_v3.json' if selected == 'r10h_v50_joint_bounded_contact_gated_v1' else 'sdk/recovery/r10g_v50_walking_entry_contract_' + selected.rsplit('_', 1)[1] + '.json'
        raw = prior.committed(relative, source)
        selected_contract = entry.packet.parse_json(raw.decode())
        first_swing = True
        contact_from_start = True
    smoke.require(selected_contract['profile_id'] == selected, 'CANDIDATE_CLOSURE_WALKING_ENTRY')
    sources = [dict(path=relative, source_commit=source, byte_length=len(raw), raw_sha256=entry.digest(raw))]
    for bound in selected_contract.get('bound_source_files', []):
        raw = prior.committed(bound['path'], source)
        smoke.require(entry.digest(raw) == bound['raw_sha256'], 'CANDIDATE_CLOSURE_ENTRY_BOUND_SOURCE')
        sources.append(dict(path=bound['path'], source_commit=source, byte_length=len(raw), raw_sha256=entry.digest(raw)))
    phase_family = selected
    if first_swing:
        phase_family = selected_contract['phase_progression_entry_profile_id']
        smoke.require((selected_contract['warmup_steps'], selected_contract['first_full_amplitude_local_step'],
                       selected_contract['first_contact_gated_local_step']) == (72, 73, 1 if contact_from_start else 361), 'CANDIDATE_CLOSURE_ENTRY_TIMING')
        for field in ('phase_progression_contract', 'amplitude_and_retention_contract'):
            relative = selected_contract[field]
            raw = prior.committed(relative, source)
            smoke.require(entry.digest(raw) == selected_contract[field + '_sha256'], 'CANDIDATE_CLOSURE_ENTRY_ANCESTRY')
            if field == 'phase_progression_contract':
                smoke.require(entry.packet.parse_json(raw.decode())['profile_id'] == phase_family, 'CANDIDATE_CLOSURE_ENTRY_FAMILY')
            sources.append(dict(path=relative, source_commit=source, byte_length=len(raw), raw_sha256=entry.digest(raw)))
        for relative in ('sdk/adapters/godot/gdscript/development_recovery_walking_startup_v1.gd',
                         'sdk/adapters/godot/gdscript/development_recovery_walking_entry_v1.gd'):
            raw = prior.committed(relative, source)
            sources.append(dict(path=relative, source_commit=source, byte_length=len(raw), raw_sha256=entry.digest(raw)))
    if schedule.get('walking_replay_profile_id'):
        relative = 'sdk/development/recovery_prospective_walking_replay_contract_v1.json'
        raw = prior.committed(relative, source)
        contract = entry.packet.parse_json(raw.decode())
        smoke.require(contract['profile_id'] == schedule['walking_replay_profile_id']
                      and contract['walking_entry_profile_id'] == phase_family, 'CANDIDATE_CLOSURE_WALKING_REPLAY')
        sources.append(dict(path=relative, source_commit=source, byte_length=len(raw), raw_sha256=entry.digest(raw)))
        raw = prior.committed(contract['transition_contract'], source)
        transition = entry.packet.parse_json(raw.decode())
        smoke.require(entry.digest(raw) == contract['transition_contract_sha256']
                      and transition['profile_id'] == contract['memory_transition_profile_id'], 'CANDIDATE_CLOSURE_TRANSITION_CONTRACT')
        sources.append(dict(path=contract['transition_contract'], source_commit=source, byte_length=len(raw), raw_sha256=entry.digest(raw)))
        for relative in ('sdk/adapters/godot/gdscript/development_walking_memory_transition_v1.gd',
                         'sdk/trace_analysis/development_recovery_candidate_replay.gd'):
            raw = prior.committed(relative, source)
            sources.append(dict(path=relative, source_commit=source, byte_length=len(raw), raw_sha256=entry.digest(raw)))
        smoke.require(entry.digest(prior.committed(transition['adapter_resource'].removeprefix('res://'), source))
                      == transition['adapter_raw_sha256'], 'CANDIDATE_CLOSURE_TRANSITION_ADAPTER')
    if schedule.get('walking_start_profile_id'):
        relative = 'sdk/development/recovery_walking_start_contract_v1.json'
        raw = prior.committed(relative, source)
        contract = entry.packet.parse_json(raw.decode())
        if contract['profile_id'] != schedule['walking_start_profile_id']:
            relative = 'sdk/development/recovery_contact_gated_walking_start_contract_v1.json'
            raw = prior.committed(relative, source)
            contract = entry.packet.parse_json(raw.decode())
        if contract['profile_id'] != schedule['walking_start_profile_id']:
            relative = 'sdk/development/recovery_front_left_first_walking_start_contract_v1.json'
            raw = prior.committed(relative, source)
            contract = entry.packet.parse_json(raw.decode())
        if contract['profile_id'] != schedule['walking_start_profile_id']:
            relative = 'sdk/development/recovery_swing_end_walking_start_contract_v1.json'
            raw = prior.committed(relative, source)
            contract = entry.packet.parse_json(raw.decode())
        if contract['profile_id'] != schedule['walking_start_profile_id']:
            relative = 'sdk/development/recovery_bounded_support_walking_start_contract_v1.json'
            raw = prior.committed(relative, source)
            contract = entry.packet.parse_json(raw.decode())
        if contract['profile_id'] != schedule['walking_start_profile_id']:
            relative = 'sdk/development/recovery_floor_support_walking_start_contract_v1.json'
            raw = prior.committed(relative, source)
            contract = entry.packet.parse_json(raw.decode())
        if contract['profile_id'] != schedule['walking_start_profile_id']:
            relative = 'sdk/development/recovery_feasible_support_walking_start_contract_v1.json'
            raw = prior.committed(relative, source)
            contract = entry.packet.parse_json(raw.decode())
        if contract['profile_id'] != schedule['walking_start_profile_id']:
            relative = 'sdk/development/recovery_smooth_swing_walking_start_contract_v1.json'
            raw = prior.committed(relative, source)
            contract = entry.packet.parse_json(raw.decode())
        if contract['profile_id'] != schedule['walking_start_profile_id']:
            relative = 'sdk/development/recovery_reference_velocity_walking_start_contract_v1.json'
            raw = prior.committed(relative, source)
            contract = entry.packet.parse_json(raw.decode())
        if contract['profile_id'] != schedule['walking_start_profile_id']:
            relative = 'sdk/development/recovery_wave_velocity_walking_start_contract_v1.json'
            raw = prior.committed(relative, source)
            contract = entry.packet.parse_json(raw.decode())
        if contract['profile_id'] != schedule['walking_start_profile_id']:
            relative = 'sdk/development/recovery_airborne_reference_walking_start_contract_v1.json'
            raw = prior.committed(relative, source)
            contract = entry.packet.parse_json(raw.decode())
        if contract['profile_id'] != schedule['walking_start_profile_id']:
            relative = 'sdk/development/recovery_absent_contact_reference_walking_start_contract_v1.json'
            raw = prior.committed(relative, source)
            contract = entry.packet.parse_json(raw.decode())
        if contract['profile_id'] != schedule['walking_start_profile_id']:
            relative = 'sdk/development/recovery_upright_stance_walking_start_contract_v1.json'
            raw = prior.committed(relative, source)
            contract = entry.packet.parse_json(raw.decode())
        if contract['profile_id'] != schedule['walking_start_profile_id']:
            relative = 'sdk/development/recovery_upright_stance_walking_start_contract_v2.json'
            raw = prior.committed(relative, source)
            contract = entry.packet.parse_json(raw.decode())
        if contract['profile_id'] != schedule['walking_start_profile_id']:
            relative = 'sdk/development/recovery_stance_latch_walking_start_contract_v1.json'
            raw = prior.committed(relative, source)
            contract = entry.packet.parse_json(raw.decode())
        if contract['profile_id'] != schedule['walking_start_profile_id']:
            relative = 'sdk/development/recovery_support_progression_walking_start_contract_v1.json'
            raw = prior.committed(relative, source)
            contract = entry.packet.parse_json(raw.decode())
        if contract['profile_id'] != schedule['walking_start_profile_id']:
            relative = 'sdk/development/recovery_support_hold_posture_walking_start_contract_v1.json'
            raw = prior.committed(relative, source)
            contract = entry.packet.parse_json(raw.decode())
        if contract['profile_id'] != schedule['walking_start_profile_id']:
            relative = 'sdk/development/recovery_remaining_support_release_walking_start_contract_v1.json'
            raw = prior.committed(relative, source)
            contract = entry.packet.parse_json(raw.decode())
        if contract['profile_id'] != schedule['walking_start_profile_id']:
            relative = 'sdk/development/recovery_startup_reference_velocity_walking_start_contract_v1.json'
            raw = prior.committed(relative, source)
            contract = entry.packet.parse_json(raw.decode())
        if selected in ('r10g_v50_joint_bounded_contact_gated_v1', 'r10g_v50_joint_bounded_contact_gated_v2', 'r10g_v50_joint_bounded_contact_gated_v3', 'r10h_v50_joint_bounded_contact_gated_v1', 'r10i_v50_joint_bounded_contact_gated_v1', 'r10j_v50_joint_bounded_contact_gated_v1', 'r10k_v51_joint_bounded_contact_gated_v1', 'r10l_v52_joint_bounded_contact_gated_v1', 'r10m_v53_joint_bounded_contact_gated_v1', 'r10n_v54_joint_bounded_contact_gated_v1', 'r10o_v55_joint_bounded_contact_gated_v1'):
            relative = 'sdk/recovery/r10o_v55_walking_start_contract_v1.json' if selected == 'r10o_v55_joint_bounded_contact_gated_v1' else 'sdk/recovery/r10n_v54_walking_start_contract_v1.json' if selected == 'r10n_v54_joint_bounded_contact_gated_v1' else 'sdk/recovery/r10m_v53_walking_start_contract_v1.json' if selected == 'r10m_v53_joint_bounded_contact_gated_v1' else 'sdk/recovery/r10l_v52_walking_start_contract_v1.json' if selected == 'r10l_v52_joint_bounded_contact_gated_v1' else 'sdk/recovery/r10k_v51_walking_start_contract_v1.json' if selected == 'r10k_v51_joint_bounded_contact_gated_v1' else 'sdk/recovery/r10j_v50_walking_start_contract_v6.json' if selected == 'r10j_v50_joint_bounded_contact_gated_v1' else 'sdk/recovery/r10i_v50_walking_start_contract_v4.json' if selected == 'r10i_v50_joint_bounded_contact_gated_v1' else 'sdk/recovery/r10h_v50_walking_start_contract_v3.json' if selected == 'r10h_v50_joint_bounded_contact_gated_v1' else 'sdk/recovery/r10g_v50_walking_start_contract_' + selected.rsplit('_', 1)[1] + '.json'
            raw = prior.committed(relative, source)
            contract = entry.packet.parse_json(raw.decode())
        smoke.require(contract['profile_id'] == schedule['walking_start_profile_id']
                      and contract['walking_entry_profile_id'] == phase_family, 'CANDIDATE_CLOSURE_WALKING_START')
        if 'exact_entry_profile_id' in contract:
            smoke.require(contract['exact_entry_profile_id'] == selected, 'CANDIDATE_CLOSURE_WALKING_START_PAIRING')
        sources.append(dict(path=relative, source_commit=source, byte_length=len(raw), raw_sha256=entry.digest(raw)))
        if 'parent_start_contract' in contract:
            relative = contract['parent_start_contract']
            raw = prior.committed(relative, source)
            smoke.require(entry.digest(raw) == contract['parent_start_contract_sha256'], 'CANDIDATE_CLOSURE_START_PARENT')
            sources.append(dict(path=relative, source_commit=source, byte_length=len(raw), raw_sha256=entry.digest(raw)))
        for relative in (contract['normal_launcher_resource'].removeprefix('res://'),
                         'sdk/adapters/godot/gdscript/development_recovery_walking_start_v1.gd',
                         'sdk/adapters/godot/gdscript/qsdk_r10f_recovery_native_locomotion_facade_v1.gd',
                         'sdk/adapters/godot/gdscript/development_recovery_candidate_worker_v1.gd',
                         'tests/test_sdk_qsdk_r10f_continuous_passive_recovery_worker.gd'):
            raw = prior.committed(relative, source)
            if relative == contract['normal_launcher_resource'].removeprefix('res://'):
                smoke.require(entry.digest(raw) == contract['normal_launcher_raw_sha256'], 'CANDIDATE_CLOSURE_WALKING_START_LAUNCHER')
            sources.append(dict(path=relative, source_commit=source, byte_length=len(raw), raw_sha256=entry.digest(raw)))
    if schedule.get('walking_policy_id'):
        relative = 'sdk/development/recovery_swing_end_walking_policy_contract_v1.json'
        raw = prior.committed(relative, source)
        contract = entry.packet.parse_json(raw.decode())
        if contract['policy_id'] != schedule['walking_policy_id']:
            relative = 'sdk/development/recovery_bounded_support_walking_policy_contract_v1.json'
            raw = prior.committed(relative, source)
            contract = entry.packet.parse_json(raw.decode())
        if contract['policy_id'] != schedule['walking_policy_id']:
            relative = 'sdk/development/recovery_floor_support_walking_policy_contract_v1.json'
            raw = prior.committed(relative, source)
            contract = entry.packet.parse_json(raw.decode())
        if contract['policy_id'] != schedule['walking_policy_id']:
            relative = 'sdk/development/recovery_feasible_support_walking_policy_contract_v1.json'
            raw = prior.committed(relative, source)
            contract = entry.packet.parse_json(raw.decode())
        if contract['policy_id'] != schedule['walking_policy_id']:
            relative = 'sdk/development/recovery_smooth_swing_walking_policy_contract_v1.json'
            raw = prior.committed(relative, source)
            contract = entry.packet.parse_json(raw.decode())
        if contract['policy_id'] != schedule['walking_policy_id']:
            relative = 'sdk/development/recovery_reference_velocity_walking_policy_contract_v1.json'
            raw = prior.committed(relative, source)
            contract = entry.packet.parse_json(raw.decode())
        if contract['policy_id'] != schedule['walking_policy_id']:
            relative = 'sdk/development/recovery_wave_velocity_walking_policy_contract_v1.json'
            raw = prior.committed(relative, source)
            contract = entry.packet.parse_json(raw.decode())
        if contract['policy_id'] != schedule['walking_policy_id']:
            relative = 'sdk/development/recovery_airborne_reference_walking_policy_contract_v1.json'
            raw = prior.committed(relative, source)
            contract = entry.packet.parse_json(raw.decode())
        if contract['policy_id'] != schedule['walking_policy_id']:
            relative = 'sdk/development/recovery_absent_contact_reference_walking_policy_contract_v1.json'
            raw = prior.committed(relative, source)
            contract = entry.packet.parse_json(raw.decode())
        if contract['policy_id'] != schedule['walking_policy_id']:
            relative = 'sdk/development/recovery_upright_stance_walking_policy_contract_v1.json'
            raw = prior.committed(relative, source)
            contract = entry.packet.parse_json(raw.decode())
        if selected == 'upright_stance_joint_bounded_contact_gated_v2':
            relative = 'sdk/development/recovery_upright_stance_walking_policy_contract_v2.json'
            raw = prior.committed(relative, source)
            contract = entry.packet.parse_json(raw.decode())
        if selected == 'stance_latch_joint_bounded_contact_gated_v1':
            relative = 'sdk/development/recovery_stance_latch_walking_policy_contract_v1.json'
            raw = prior.committed(relative, source)
            contract = entry.packet.parse_json(raw.decode())
        if selected == 'support_progression_joint_bounded_contact_gated_v1':
            relative = 'sdk/development/recovery_support_progression_walking_policy_contract_v1.json'
            raw = prior.committed(relative, source)
            contract = entry.packet.parse_json(raw.decode())
        if selected == 'support_hold_posture_joint_bounded_contact_gated_v1':
            relative = 'sdk/development/recovery_support_hold_posture_walking_policy_contract_v1.json'
            raw = prior.committed(relative, source)
            contract = entry.packet.parse_json(raw.decode())
        if selected == 'remaining_support_release_joint_bounded_contact_gated_v1':
            relative = 'sdk/development/recovery_remaining_support_release_walking_policy_contract_v1.json'
            raw = prior.committed(relative, source)
            contract = entry.packet.parse_json(raw.decode())
        if selected == 'startup_reference_velocity_joint_bounded_contact_gated_v1':
            relative = 'sdk/development/recovery_startup_reference_velocity_walking_policy_contract_v1.json'
            raw = prior.committed(relative, source)
            contract = entry.packet.parse_json(raw.decode())
        if selected in ('r10g_v50_joint_bounded_contact_gated_v1', 'r10g_v50_joint_bounded_contact_gated_v2', 'r10g_v50_joint_bounded_contact_gated_v3', 'r10h_v50_joint_bounded_contact_gated_v1', 'r10i_v50_joint_bounded_contact_gated_v1', 'r10j_v50_joint_bounded_contact_gated_v1', 'r10k_v51_joint_bounded_contact_gated_v1', 'r10l_v52_joint_bounded_contact_gated_v1', 'r10m_v53_joint_bounded_contact_gated_v1', 'r10n_v54_joint_bounded_contact_gated_v1', 'r10o_v55_joint_bounded_contact_gated_v1'):
            relative = 'sdk/recovery/r10o_v55_walking_route_contract_v1.json' if selected == 'r10o_v55_joint_bounded_contact_gated_v1' else 'sdk/recovery/r10n_v54_walking_route_contract_v1.json' if selected == 'r10n_v54_joint_bounded_contact_gated_v1' else 'sdk/recovery/r10m_v53_walking_route_contract_v1.json' if selected == 'r10m_v53_joint_bounded_contact_gated_v1' else 'sdk/recovery/r10l_v52_walking_route_contract_v1.json' if selected == 'r10l_v52_joint_bounded_contact_gated_v1' else 'sdk/recovery/r10k_v51_walking_route_contract_v1.json' if selected == 'r10k_v51_joint_bounded_contact_gated_v1' else 'sdk/recovery/r10j_v50_walking_route_contract_v6.json' if selected == 'r10j_v50_joint_bounded_contact_gated_v1' else 'sdk/recovery/r10i_v50_walking_route_contract_v4.json' if selected == 'r10i_v50_joint_bounded_contact_gated_v1' else 'sdk/recovery/r10h_v50_walking_route_contract_v3.json' if selected == 'r10h_v50_joint_bounded_contact_gated_v1' else 'sdk/recovery/r10g_v50_walking_route_contract_' + selected.rsplit('_', 1)[1] + '.json'
            raw = prior.committed(relative, source)
            contract = entry.packet.parse_json(raw.decode())
            task_raw = prior.committed(contract['task_contract'], source)
            smoke.require(entry.digest(task_raw) == contract['task_contract_sha256'], 'CANDIDATE_CLOSURE_FINITE_TASK')
            sources.append(dict(path=contract['task_contract'], source_commit=source, byte_length=len(task_raw), raw_sha256=entry.digest(task_raw)))
        smoke.require(contract.get('selection_id', contract['policy_id']) == schedule['walking_policy_id']
                      and entry.digest(raw) == schedule['walking_policy_contract_sha256']
                      and contract['runtime_sha256'] == schedule['runtime_sha256']
                      and selected_contract['required_walking_policy_id'] == contract.get('selection_id', contract['policy_id'])
                      and not schedule.get('walking_replay_profile_id'), 'CANDIDATE_CLOSURE_WALKING_POLICY')
        sources.append(dict(path=relative, source_commit=source, byte_length=len(raw), raw_sha256=entry.digest(raw)))
        for relative in ('sdk/adapters/godot/gdscript/development_recovery_walking_policy_v1.gd',
                         'sdk/adapters/godot/gdscript/development_passive_entry_orchestrator_v1.gd',
                         'sdk/adapters/godot/gdscript/development_passive_entry_replay_v1.gd',
                         'sdk/adapters/godot/gdscript/qsdk_r10f_event_triggered_passive_recovery_orchestrator_v1.gd',
                         'sdk/adapters/godot/gdscript/qsdk_r10f_walking_segment_evaluator_v2.gd',
                         'sdk/trace_analysis/development_recovery_candidate_replay.gd'):
            raw = prior.committed(relative, source)
            sources.append(dict(path=relative, source_commit=source, byte_length=len(raw), raw_sha256=entry.digest(raw)))
    return sources


def observe(root, distal_body_origins=False):
    checkpoint = smoke.retained_checkpoint(root)
    declaration = smoke.read(root / 'declaration.json')
    source = checkpoint['source_snapshot']['head']
    smoke.require(checkpoint['source_snapshot']['dirty'] is False, 'CANDIDATE_CLOSURE_CLEAN_SOURCE')
    fixed = entry.packet.parse_json(prior.committed(CONTRACT, source).decode())
    smoke.require(declaration['schema_version'] == fixed['worker_selection']['declaration_schema'],
                  'CANDIDATE_CLOSURE_DECLARATION')
    profile_path = declaration['candidate_profile']['resource'].removeprefix('res://')
    profile = entry.packet.parse_json(prior.committed(profile_path, source).decode())
    roles = smoke.declared_roles(declaration)
    report_path = root / 'children' / fixed['single_role'] / 'worker_report.json'
    report = smoke.read(report_path)
    metrics = prior.summarize(report, source_commit=source, profile_path=profile_path)
    children = [{key: value for key, value in child.items() if key != 'step_cost_profile'}
                for child in checkpoint['observed']['children']]
    supervisor = smoke.read(root / 'supervisor_result.json')
    times = dict(checkpoint['elapsed_seconds'])
    times['safety_gate'] = round(sum(stage['seconds'] for stage in supervisor['safety_stages']), 3)
    times['independent_replays'] = {role: smoke.read(root / 'children' / role /
        'passive_entry_replay' / 'execution.json')['elapsed_seconds'] for role in roles}
    phase = report['retained_arm']['orchestrator_state']['phase']
    status = ('closed_consumed_valid_development_behavior_negative' if phase == 'failed' else
              'closed_consumed_valid_development_observation')
    sources = []
    for relative in (CONTRACT, profile_path, profile['runtime_binding'].removeprefix('res://'),
                     prior.RULE, 'sdk/core/src/recovery_runtime.rs'):
        raw = prior.committed(relative, source)
        sources.append(dict(path=relative, source_commit=source, byte_length=len(raw), raw_sha256=entry.digest(raw)))
    if profile.get('schema_version') == 'sporespore_development_recovery_candidate_profile_v2':
        relative = 'sdk/development_recovery_candidate_schedules_v1.json'
        # Resolve against the frozen Git tree, not the current checkout. Old
        # schedules and their original bytes remain valid after new additions.
        schedule_id = profile['diagnostic_schedule_id']
        import re
        smoke.require(re.fullmatch(r'[a-z0-9][a-z0-9-]{0,79}', schedule_id) is not None, 'CANDIDATE_CLOSURE_SCHEDULE_ID')
        named = 'sdk/development/recovery_schedules/' + schedule_id + '.json'
        exists = entry.subprocess.run(['git', 'cat-file', '-e', source + ':' + named], cwd=entry.ROOT,
            stdout=entry.subprocess.DEVNULL, stderr=entry.subprocess.DEVNULL,
            creationflags=entry.subprocess.CREATE_NO_WINDOW).returncode == 0
        if exists:
            relative = named
        raw = prior.committed(relative, source)
        smoke.require(entry.digest(raw) == profile['diagnostic_schedule_sha256'], 'CANDIDATE_CLOSURE_SCHEDULE_BINDING')
        sources.append(dict(path=relative, source_commit=source, byte_length=len(raw), raw_sha256=entry.digest(raw)))
        schedule = entry.packet.parse_json(raw.decode())['schedules'][schedule_id]
        if schedule.get('walking_resume_frame_id'):
            relative = 'sdk/development/recovery_walking_frame_contract_v1.json'
            raw = prior.committed(relative, source)
            frame = entry.packet.parse_json(raw.decode())
            smoke.require(frame['resume_frame_id'] == schedule['walking_resume_frame_id'], 'CANDIDATE_CLOSURE_WALKING_FRAME')
            sources.append(dict(path=relative, source_commit=source, byte_length=len(raw), raw_sha256=entry.digest(raw)))
        sources.extend(walking_entry_rule_sources(schedule, source))
    result = dict(schema_version=('sporespore_development_recovery_candidate_checkpoint_v2' if distal_body_origins
                               else 'sporespore_development_recovery_candidate_checkpoint_v1'),
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
            authority_mode='retained_development_physical_result', question_class='development'),
        status=status, attempt_id=checkpoint['attempt_id'], candidate_id=profile['candidate_id'],
        evidence_root=root.as_posix(), source_snapshot=checkpoint['source_snapshot'],
        candidate_profile=declaration['candidate_profile'], execution_mode=declaration['development_execution_mode'],
        retained_population=checkpoint['retained_population'], artifact_sha256=checkpoint['artifact_sha256'],
        elapsed_seconds=times, safety_test_count=sum(s['test_count'] for s in supervisor['safety_stages']),
        children=children, rule_sources=sources, kicked_report=entry.runtime.file_identity(report_path),
        original_attempt_and_all_independent_replays_passed=True,
        world_count=len(roles), solver_step_count=checkpoint['observed']['total_solver_steps'],
        diagnostic_coverage_complete=checkpoint['observed']['coverage_complete'], metrics=metrics,
        support_geometry=support_geometry(report, metrics, distal_body_origins),
        comparative_authority=False, baseline_reused=False, causal_attribution_proven=False,
        successful_recovery_proven=False, complete_route_proven=False,
        physical_acceptance_authority=False, release_authority=False,
        repeat_consumed_attempt_permitted=False, new_world_build_count=0, new_solver_step_count=0)
    if report.get('development_walking_entry', {}).get('sample_count', 0):
        result['walking_control_diagnosis'] = walking_control_diagnostics(report)
        for relative in ('scripts/lab/gait/sdk_godot_jolt_adapter.gd',
                         'scripts/lab/mechanics/semantic_contact_rigid_body.gd',
                         'sdk/adapters/godot/gdscript/recovery_native_world_v1.gd',
                         'sdk/adapters/godot/gdscript/qsdk_r10f_walking_segment_evaluator_v2.gd'):
            raw = prior.committed(relative, source)
            sources.append(dict(path=relative, source_commit=source, byte_length=len(raw), raw_sha256=entry.digest(raw)))
    if 'development_walking_contacts' in report:
        result['walking_contact_diagnosis'] = walking_contact_diagnostics(report)
        for relative in ('sdk/development/recovery_walking_contact_contract_v1.json',
                         'sdk/adapters/godot/gdscript/development_recovery_walking_contacts_v1.gd',
                         'scripts/lab/gait/sdk_godot_jolt_adapter.gd',
                         'scripts/lab/mechanics/semantic_contact_rigid_body.gd',
                         'tests/test_sdk_qsdk_r10f_continuous_passive_recovery_worker.gd'):
            if not any(row['path'] == relative for row in sources):
                raw = prior.committed(relative, source)
                sources.append(dict(path=relative, source_commit=source, byte_length=len(raw), raw_sha256=entry.digest(raw)))
    if 'development_native_walking_contacts' in report:
        result['native_walking_contact_diagnosis'] = native_walking_contact_diagnostics(report)
        for relative in ('sdk/development/recovery_native_walking_contact_contract_v1.json',
                         'sdk/adapters/godot/gdscript/development_recovery_native_walking_contacts_v1.gd',
                         'scripts/lab/gait/sdk_godot_jolt_adapter.gd',
                         'scripts/lab/mechanics/semantic_contact_rigid_body.gd',
                         'sdk/adapters/godot/gdscript/recovery_native_world_v1.gd',
                         'tests/test_sdk_qsdk_r10f_continuous_passive_recovery_worker.gd'):
            if not any(row['path'] == relative for row in sources):
                raw = prior.committed(relative, source)
                sources.append(dict(path=relative, source_commit=source, byte_length=len(raw), raw_sha256=entry.digest(raw)))
    return result


def observe_clocked_entry_replay_failure(root):
    """Preserve V23's ORIGINAL failed replay; never repair or rerun that attempt."""
    import copy
    import hashlib
    root = root.resolve()
    attempt = '92dd4a7de9124bd6bde70dd7a9042843'
    smoke.require(root == entry.ROOT.parent / 'SporeSpore_Evidence' / ('development-recovery-smoke-' + attempt), 'V23_FAILURE_ROOT')
    supervisor = smoke.read(root / 'supervisor_result.json')
    declaration = smoke.read(root / 'declaration.json')
    source = declaration['source_snapshot']['head']
    prefix = 'DEVELOPMENT_RECOVERY_SMOKE_COMPLETE '
    published = (root / 'published_marker.txt').read_text(encoding='utf-8')
    smoke.require(published.startswith(prefix) and smoke.packet.same(supervisor, smoke.packet.parse_json(published[len(prefix):])), 'V23_FINAL_PUBLICATION')
    role = 'kick_passive_recovery_resume'
    smoke.require(supervisor['ok'] is False and supervisor['independent_audit'] is None
        and supervisor['failure_code'] == 'SMOKE_ENTRY_REPLAY_FAILED:' + role
        and supervisor['physical_attempt_started'] is True and len(supervisor['children']) == 1
        and supervisor['source_snapshot'] == declaration['source_snapshot']
        and declaration['source_snapshot']['dirty'] is False, 'V23_ORIGINAL_FAILURE')
    child = root / 'children' / role
    report_path = child / 'worker_report.json'
    report = smoke.read(report_path)
    envelope = smoke.read(child / 'child_envelope.json')
    smoke.require(smoke.packet.same(report, envelope['report']), 'V23_REPORT_ENVELOPE')
    for item in list(envelope['retained_artifact_bindings'].values()) + [supervisor['children'][0]['envelope']]:
        path = Path(item['path']).resolve()
        smoke.require(path.parent == child and path.stat().st_size == item['byte_length'] and smoke.sha(path) == item['raw_sha256'], 'V23_ARTIFACT_BINDING')
    smoke.validate_header(report, declaration['children'][0], declaration, envelope['worker_process_id'])
    smoke.require(envelope['exit_code'] == 0 and all(envelope[k] is True for k in ('engine_health_passed', 'raw_marker_valid', 'termination_protocol_valid'))
        and (child / 'worker.stderr.txt').read_bytes() == b'', 'V23_NATIVE_HEALTH')
    stages = supervisor['safety_stages']
    smoke.require(sum(s['test_count'] for s in stages) == 95 and all(s['passed'] for s in stages), 'V23_SAFETY')
    execution = smoke.read(child / 'passive_entry_replay/execution.json')
    smoke.require(execution['returncode'] == 1 and execution['timed_out'] is False
        and execution['input_raw_sha256'] == smoke.sha(report_path), 'V23_FAILED_REPLAY_INPUT')
    for stream in ('stdout', 'stderr'):
        path = child / 'passive_entry_replay' / (stream + '.txt')
        smoke.require(path.stat().st_size == execution[stream + '_binding']['byte_length']
            and smoke.sha(path) == execution[stream + '_binding']['raw_sha256'], 'V23_FAILED_REPLAY_STREAM')
    marker = 'DEVELOPMENT_RECOVERY_CANDIDATE_REPLAY '
    lines = [line[len(marker):] for line in (child / 'passive_entry_replay/stdout.txt').read_text().splitlines() if line.startswith(marker)]
    smoke.require(len(lines) == 1, 'V23_FAILED_REPLAY_MARKER')
    replay = smoke.packet.parse_json(lines[0])
    smoke.require(replay['ok'] is False and replay['failure_code'] == 'DEVELOPMENT_WALKING_ENTRY_READER_MEMORY_CHAIN', 'V23_FAILED_REPLAY_REASON')
    rows = report['development_walking_entry']['rows']
    differences = []
    for previous, current in zip(rows, rows[1:]):
        before, after = previous['native_output']['next_memory'], current['request']['memory']
        if not smoke.packet.same(before, after):
            expected = copy.deepcopy(before)
            for limb in expected['ordered_limb_memory']:
                limb['evidence_gait_step_limit'] = int(limb['gait_step']) + 1 + 1440
            differences.append(dict(local_step=current['session_local_step'], global_step=current['commanded_global_step'],
                previous_mode=before['phase_progression_mode'], command_mode=current['request']['command']['phase_progression_mode'],
                previous_output_memory=before, next_request_memory=after,
                only_expected_adapter_endpoint_changes=smoke.packet.same(expected, after)))
    smoke.require(len(rows) == 445 and len(differences) == 1 and differences[0]['local_step'] == 361
        and differences[0]['only_expected_adapter_endpoint_changes'] is True, 'V23_MEMORY_DIFFERENCE_POPULATION')
    profile_path = declaration['candidate_profile']['resource'].removeprefix('res://')
    metrics = prior.summarize(report, source_commit=source, profile_path=profile_path)
    inventory = [dict(path=p.relative_to(root).as_posix(), byte_length=p.stat().st_size, raw_sha256=smoke.sha(p))
                 for p in sorted(root.rglob('*')) if p.is_file()]
    inventory_sha = 'sha256:' + hashlib.sha256(json.dumps(inventory, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
    sources = []
    for path in (profile_path, 'sdk/development/recovery_schedules/v23-clocked-walking-warmup-v1.json',
        'sdk/development/recovery_clocked_walking_entry_contract_v1.json', 'scripts/lab/gait/sdk_godot_jolt_adapter.gd',
        'sdk/adapters/godot/gdscript/development_recovery_walking_entry_v1.gd', 'tests/test_development_recovery_walking_entry.gd'):
        raw = prior.committed(path, source)
        sources.append(dict(path=path, source_commit=source, byte_length=len(raw), raw_sha256=entry.digest(raw)))
    def seconds(record):
        return round((smoke.launch.utc_ticks(record['completed_utc']) - smoke.launch.utc_ticks(record['started_utc'])) / 10_000_000, 3)
    return dict(schema_version='sporespore_development_clocked_entry_replay_failure_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='post_exposure_retained_data_diagnosis', question_class='development'),
        status='closed_consumed_independent_replay_invalid', attempt_id=attempt, evidence_root=root.as_posix(),
        source_snapshot=declaration['source_snapshot'], candidate_profile=declaration['candidate_profile'],
        retained_population=dict(file_count=len(inventory), byte_length=sum(p['byte_length'] for p in inventory), inventory_sha256=inventory_sha, files=inventory),
        kicked_report=entry.runtime.file_identity(report_path), failure_code=supervisor['failure_code'], failed_replay=replay,
        elapsed_seconds=dict(whole_invocation=seconds(supervisor), native_child=seconds(envelope), safety_gate=round(sum(s['seconds'] for s in stages),3), original_failed_replay=execution['elapsed_seconds']),
        safety_test_count=95, world_count=1, solver_step_count=report['solver_step_count'], native_engine_health_passed=True,
        original_independent_replay_passed=False, full_recovery_sequence_independently_replayed=False,
        original_supervisor_passed=False, original_independent_audit_present=False,
        worker_report_metrics_provisional=metrics, walking_control_diagnosis_provisional=walking_control_diagnostics(report),
        memory_transition_diagnosis=dict(sample_count=len(rows), mismatch_count=len(differences), mismatches=differences,
            source_function='LabSdkGodotJoltAdapter._configure_phase_progression_mode', gait_clock_reset_observed=False,
            source_rule='On clocked-to-contact_gated transition, endpoint equals current gait_step plus 1 plus 1440; no other memory fields change.',
            actual_adapter_transition_independently_executed=False,
            missed_test_boundary='The pure native 450-command probe bypassed the production adapter mode-configuration operation; the sampler capture stub did not execute it.'),
        frozen_sources=sources, diagnosis='Original replay refuses one expected adapter endpoint update at resumed local 361. This retained-data diagnosis does not repair the original replay or validate the full physical sequence.',
        next_work='Separate zero-world successor replay using the actual adapter transition, with corrupted-transition controls and a fresh diagnostic output root. Preserve this original invalid attempt; no repeat of its identity.',
        successful_recovery_proven=False, complete_route_proven=False, physical_acceptance_authority=False, release_authority=False,
        comparative_authority=False, causal_attribution_proven=False, repeat_consumed_attempt_permitted=False,
        new_world_build_count=0, new_solver_step_count=0, new_native_physics_read_count=0)


def observe_transition_diagnostic(root):
    """Close a separate successful diagnostic, never upgrade its invalid source."""
    import hashlib
    original_path = entry.ROOT / 'sdk/development/recovery_attempts/92dd4a7de9124bd6bde70dd7a9042843.json'
    original = smoke.read(original_path)
    smoke.require(smoke.sha(original_path) == 'sha256:e1fe74012d27269c081a36971e57e674df09c3d8640adc3ece1b5b70e21fd4f8'
        and original['status'] == 'closed_consumed_independent_replay_invalid', 'TRANSITION_DIAGNOSTIC_ORIGINAL')
    report_path = Path(original['kicked_report']['path'])
    profile_id = 'production_adapter_clocked_warmup_v1'
    result = entry.consume_replay(report_path, diagnostic_directory=root, memory_transition_profile=profile_id)
    execution = smoke.read(root / 'execution.json')
    report = smoke.read(report_path)
    walk = next(s['evaluation'] for s in report['retained_arm']['walking_sessions'] if s['evaluation_segment_id'] == 'walking_resume')
    inventory = [dict(path=p.relative_to(root).as_posix(), byte_length=p.stat().st_size, raw_sha256=smoke.sha(p))
                 for p in sorted(root.rglob('*')) if p.is_file()]
    digest = 'sha256:' + hashlib.sha256(json.dumps(inventory, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
    smoke.require({p['path'] for p in inventory} == {'execution.json', 'stdout.txt', 'stderr.txt', 'source_snapshot.json'}, 'TRANSITION_DIAGNOSTIC_FILES')
    return dict(schema_version='sporespore_development_walking_transition_diagnostic_checkpoint_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='post_exposure_retained_data_replay', question_class='development'),
        status='closed_post_exposure_diagnostic_passed_original_attempt_invalid', diagnostic_id=root.name.rsplit('-', 1)[-1],
        evidence_root=root.as_posix(), original_attempt_id=original['attempt_id'],
        original_invalid_closure=entry.runtime.file_identity(original_path), original_report=original['kicked_report'],
        original_attempt_status=original['status'], original_attempt_reclassified=False,
        memory_transition_profile_id=profile_id, diagnostic_result=result,
        elapsed_seconds=execution['elapsed_seconds'], source_snapshot_binding=execution['source_snapshot_binding'],
        exact_source_unchanged_during_replay=execution['source_unchanged_during_replay'],
        original_replay_bindings=execution['original_replay_bindings'],
        retained_population=dict(file_count=len(inventory), byte_length=sum(p['byte_length'] for p in inventory), inventory_sha256=digest, files=inventory),
        original_recorded_walking_evaluation={k: walk[k] for k in ('evaluator_id', 'trace_row_count', 'behavior_passed',
            'false_walking_receipts', 'fixed_thresholds', 'forward_advance_m', 'absolute_lateral_drift_m', 'maximum_tilt_rad',
            'minimum_cycle_forward_relocation_by_limb_m', 'contact_cycle_count_by_limb', 'torso_contact_step_count')},
        evaluation_regraded=False, complete_route_proven=False, successful_recovery_proven=False,
        physical_acceptance_authority=False, release_authority=False, causal_attribution_proven=False,
        new_world_build_count=0, new_native_physics_read_count=0, new_solver_step_count=0,
        next_work='Integrate the explicitly qualified adapter-transition reader into a distinct prospective candidate, fix its new-selector closure binding, and diagnose the two unchanged walking negatives before selecting more physics.')


def observe_schedule_gate_failure(root, fixture_root):
    """Retain a schedule-test failure before launch; never repair its old result."""
    import hashlib
    supervisor = smoke.read(root / 'supervisor_result.json')
    stages = supervisor['safety_stages']
    smoke.require(supervisor['ok'] is False and supervisor['physical_attempt_started'] is False
        and supervisor['children'] == [] and supervisor['independent_audit'] is None
        and supervisor['failure_code'] == 'SMOKE_SAFETY_GATE_FAILED:candidate_schedule'
        and not (root / 'children').exists(), 'SCHEDULE_GATE_NO_PHYSICAL_CHILD')
    smoke.require(all(s['passed'] is True for s in stages[:-1]) and stages[-1]['passed'] is False
        and stages[-1]['id'] == 'candidate_schedule', 'SCHEDULE_GATE_STAGE_ORDER')
    for stage in stages:
        for stream in ('stdout', 'stderr'):
            smoke.require(smoke.sha(root / stage[stream]) == 'sha256:' + stage[stream + '_sha256'],
                          'SCHEDULE_GATE_LOG_BINDING')
    smoke.require(fixture_root.as_posix() in (root / stages[-1]['stdout']).read_text().replace('\\', '/'),
                  'SCHEDULE_GATE_FIXTURE_LINK')
    execution = smoke.read(fixture_root / 'schedule_hooks.execution.json')
    smoke.require(execution['returncode'] == 1 and execution['timed_out'] is False
        and execution['source_unchanged'] is True and execution['world_build_count'] == 0
        and execution['solver_step_count'] == 0, 'SCHEDULE_GATE_FIXTURE_EXECUTION')
    lines = (fixture_root / 'schedule_hooks.stdout.txt').read_text().splitlines()
    markers = [line.removeprefix('CANDIDATE_SCHEDULE_CHECKS ') for line in lines
               if line.startswith('CANDIDATE_SCHEDULE_CHECKS ')]
    smoke.require(len(markers) == 1, 'SCHEDULE_GATE_MARKER_COUNT')
    result = json.loads(markers[0])
    smoke.require(result['ok'] is False and result['world_build_count'] == 0 and result['solver_step_count'] == 0,
                  'SCHEDULE_GATE_FAILED_ZERO_WORLD_MARKER')
    profile_path, profile_sha = execution['command'][-2:]
    raw = prior.committed(profile_path.removeprefix('res://'), supervisor['source_snapshot']['head'])
    smoke.require(entry.digest(raw) == profile_sha, 'SCHEDULE_GATE_FROZEN_PROFILE')
    def population(directory):
        files = [dict(path=p.relative_to(directory).as_posix(), byte_length=p.stat().st_size,
                      raw_sha256=smoke.sha(p)) for p in sorted(directory.rglob('*')) if p.is_file()]
        digest = 'sha256:' + hashlib.sha256(json.dumps(files, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
        return dict(root=directory.as_posix(), file_count=len(files), byte_length=sum(f['byte_length'] for f in files),
                    inventory_sha256=digest, files=files)
    return dict(schema_version='sporespore_development_recovery_schedule_gate_failure_checkpoint_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='retained_zero_world_gate_failure', question_class='development'),
        status='closed_consumed_zero_world_safety_gate_failure', attempt_id=root.name.rsplit('-', 1)[-1],
        evidence_root=root.as_posix(), source_snapshot=supervisor['source_snapshot'],
        candidate_profile=dict(resource=profile_path, raw_sha256=profile_sha), failure_code=supervisor['failure_code'],
        failed_checks=[name for name, passed in result['checks'].items() if passed is not True],
        completed_test_count=sum(s['test_count'] for s in stages),
        passed_tests_in_preceding_stages=sum(s['test_count'] for s in stages[:-1]),
        failed_stage_completed_test_count=stages[-1]['test_count'],
        failed_stage_assertions=result, retained_population=population(root), failed_stage_source_population=population(fixture_root),
        physical_attempt_started=False, world_build_count=0, solver_step_count=0,
        complete_route_proven=False, successful_recovery_proven=False, physical_acceptance_authority=False,
        release_authority=False, repeat_consumed_attempt_permitted=False)


def observe_floor_gate_failure(root, fixture_root):
    """Cold description of the original failed production-ledger setup."""
    import hashlib
    supervisor = smoke.read(root / 'supervisor_result.json')
    stages = supervisor['safety_stages']
    smoke.require(supervisor['ok'] is False and supervisor['physical_attempt_started'] is False
        and supervisor['children'] == [] and supervisor['independent_audit'] is None
        and supervisor['failure_code'] == 'SMOKE_SAFETY_GATE_FAILED:candidate_walking_policy'
        and not (root / 'children').exists(), 'FLOOR_GATE_NO_PHYSICAL_CHILD')
    smoke.require(all(s['passed'] is True for s in stages[:-1]) and stages[-1]['passed'] is False
        and stages[-1]['id'] == 'candidate_walking_policy' and stages[-1]['test_count'] == 0,
        'FLOOR_GATE_SETUP_FAILURE')
    for stage in stages:
        for stream in ('stdout', 'stderr'):
            smoke.require(smoke.sha(root / stage[stream]) == 'sha256:' + stage[stream + '_sha256'],
                          'FLOOR_GATE_LOG_BINDING')
    smoke.require(fixture_root.as_posix() in (root / stages[-1]['stdout']).read_text().replace('\\', '/'),
                  'FLOOR_GATE_FIXTURE_LINK')
    execution = smoke.read(fixture_root / 'producer.execution.json')
    smoke.require(execution['returncode'] == 1 and execution['timed_out'] is False
        and execution['source_unchanged'] is True and execution['world_build_count'] == 0
        and execution['solver_step_count'] == 0, 'FLOOR_GATE_FIXTURE_EXECUTION')
    markers = [line.removeprefix('V34_FLOOR_PRODUCER ') for line in
               (fixture_root / 'producer.stdout.txt').read_text().splitlines()
               if line.startswith('V34_FLOOR_PRODUCER ')]
    smoke.require(len(markers) == 1, 'FLOOR_GATE_MARKER_COUNT')
    result = json.loads(markers[0])
    ledger = result['result']['floor_fixture']
    transport = ledger['native_step_transport_verification']
    smoke.require(result['ok'] is False and result['world_build_count'] == 0
        and result['solver_step_count'] == 0 and transport['ok'] is True
        and transport['policy_identity_exact'] is True
        and transport['controller_receipt_schema_exact'] is True, 'FLOOR_GATE_NATIVE_TRANSPORT_VALID')
    failed = [name for name, passed in result['checks'].items() if passed is not True]
    predicates = ledger['walking_ledger_predicate_receipt']['failed_predicate_ids']
    smoke.require(failed == ['new_real_motor_ledger']
        and predicates == ['identity.native_transport_verification_valid'], 'FLOOR_GATE_EXACT_REJECTION')
    source = supervisor['source_snapshot']['head']
    facade_path = 'sdk/adapters/godot/gdscript/qsdk_r10f_recovery_native_locomotion_facade_v1.gd'
    raw = prior.committed(facade_path, source)
    lookup = raw.decode().split('. native_step_transport_verification_receipt_valid_v1(', 1)[1].split('session_local_step,', 1)[0]
    smoke.require('DEVELOPMENT_ABSENT_CONTACT_REFERENCE_RECEIPT_SCHEMA' in lookup
        and 'DEVELOPMENT_UPRIGHT_STANCE_RECEIPT_SCHEMA' not in lookup
        and 'else SELECTED_CONTROLLER_RECEIPT_SCHEMA' in lookup, 'FLOOR_GATE_FROZEN_LOOKUP_OMISSION')
    def population(directory):
        files = [dict(path=p.relative_to(directory).as_posix(), byte_length=p.stat().st_size,
                      raw_sha256=smoke.sha(p)) for p in sorted(directory.rglob('*')) if p.is_file()]
        digest = 'sha256:' + hashlib.sha256(json.dumps(files, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
        return dict(root=directory.as_posix(), file_count=len(files), byte_length=sum(f['byte_length'] for f in files),
                    inventory_sha256=digest, files=files)
    return dict(schema_version='sporespore_development_recovery_floor_gate_failure_checkpoint_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='retained_zero_world_gate_failure', question_class='development'),
        status='closed_consumed_zero_world_safety_gate_failure', attempt_id=root.name.rsplit('-', 1)[-1],
        evidence_root=root.as_posix(), source_snapshot=supervisor['source_snapshot'],
        failure_code=supervisor['failure_code'], failed_checks=failed, failed_ledger_predicates=predicates,
        passed_tests_in_preceding_stages=sum(s['test_count'] for s in stages[:-1]),
        failed_stage_completed_test_count=0, failed_stage=stages[-1],
        original_transport_verification=transport,
        frozen_facade=dict(path=facade_path, source_commit=source, raw_sha256=entry.digest(raw)),
        diagnosis='The frozen production motor-ledger schema lookup lacks V41 and selects the legacy schema; native transport and every other ledger predicate pass.',
        retained_population=population(root), failed_stage_source_population=population(fixture_root),
        physical_attempt_started=False, world_build_count=0, solver_step_count=0,
        complete_route_proven=False, successful_recovery_proven=False, physical_acceptance_authority=False,
        release_authority=False, repeat_consumed_attempt_permitted=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('root', type=Path)
    parser.add_argument('--distal-body-origins', action='store_true',
                        help='New descriptive schema with corrected point labels and phase-boundary samples; old closures remain byte-for-byte reproducible.')
    parser.add_argument('--clocked-entry-replay-failure', action='store_true',
                        help='Describe the original invalid V23 replay without rerunning or repairing it.')
    parser.add_argument('--transition-diagnostic', action='store_true',
                        help='Describe a separate post-exposure adapter-transition diagnostic; no physics or regrading.')
    parser.add_argument('--schedule-gate-fixture', type=Path,
                        help='Close an original zero-world schedule failure using its retained actual-interface fixture root.')
    parser.add_argument('--floor-gate-fixture', type=Path,
                        help='Describe an original zero-world motor-ledger setup failure; never rerun or repair the attempt.')
    args = parser.parse_args()
    result = (observe_floor_gate_failure(args.root.resolve(), args.floor_gate_fixture.resolve()) if args.floor_gate_fixture
              else observe_schedule_gate_failure(args.root.resolve(), args.schedule_gate_fixture.resolve()) if args.schedule_gate_fixture
              else observe_transition_diagnostic(args.root.resolve()) if args.transition_diagnostic
              else observe_clocked_entry_replay_failure(args.root) if args.clocked_entry_replay_failure
              else observe(args.root.resolve(), args.distal_body_origins))
    print(json.dumps(result, indent=2, allow_nan=False))
