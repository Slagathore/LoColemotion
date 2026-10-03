"""Descriptive successor analysis of consumed R10AE bytes; no physical authority."""
import argparse
from collections import Counter
import json
from pathlib import Path

import contact_frame_report_v2 as reader
import contact_frame_replay_v2 as capture
import r10ae_development as identity
import r10ae_replay_invalid_closure as closure

ROOT, EVIDENCE = identity.ROOT, identity.EVIDENCE
RUN = closure.RUN
POST = EVIDENCE/'r10ae-post-exposure-contact-replay-b4107b84cbe5432fa3169d18eb313d92'
PARITY = EVIDENCE/'contact-frame-configured-vector-v2-592303ec4e87439b8cd7f358eaae0939'
RECORD = ROOT/'sdk/recovery/r10ae_post_exposure_contact_analysis_v1.json'
CLAIMS = dict(original_attempt_reclassified=False, original_population_consumed=True,
    new_physical_execution_authorized=False, qualified_route_proven=False,
    recovery_repair_proven=False, causal_effect_proven=False,
    physical_acceptance_authority=False, release_authority=False,
    world_build_count=0, solver_step_count=0, sdk1_score='14/20')


def native_parity():
    data = closure.read(PARITY/'fixtures.json')
    assert data['ok'] is True and len(data['cases']) == 4
    assert closure.read(PARITY/'source-before.json') == closure.read(PARITY/'source-after.json')
    execution = closure.read(PARITY/'native.execution.json')
    assert execution['returncode'] == 0 and execution['timed_out'] is False
    assert not (PARITY/'native.stderr.txt').read_bytes()
    for case in data['cases']:
        p = case['packet']
        assert capture.replay(p,7,p['model_instance_id'],p['body_population_instance_sha256']) == case['replay']
        assert case['authored_center'] != capture.f32(case['authored_center'])
    return dict(native_unrounded_configuration_cases=4, all_agree=True)


def analyze():
    path = RUN/'children/kick_passive_recovery_resume/worker_report.json'
    assert closure.bind(path)['raw_sha256'] == 'sha256:02744296f1095c98bb688387f34292a34484188a569c5236c57e4eebfca12e43'
    report, declaration = closure.read(path), closure.read(RUN/'declaration.json')
    replay = reader.replay_report(report, declaration, identity)
    assert replay == closure.read(POST/'replay.json')['result']
    assert closure.read(POST/'source-before.json') == closure.read(POST/'source-after.json')
    for file, sha in closure.read(POST/'scope.json')['reader_files'].items():
        assert closure.bind(ROOT/file)['raw_sha256'] == sha
    rows, packets = report['retained_arm']['trace_rows'], report['r10ab_partial_recovery']['step_packets']
    partial = {}
    for p in packets:
        step = p['native_receipt']['collection']['observation']['semantic_step']
        assert step not in partial and p['prior_memory']['last_semantic_step'] + 1 == step
        partial[step] = p['native_receipt']['step']
    phases, bodies = {}, {}
    for row, record in zip(rows, report['r10ac_contact_frames']['records'], strict=True):
        step = row['global_semantic_step']
        phase = partial[step]['prior_phase'] if step in partial else row['orchestrator_phase']
        summary = phases.setdefault(phase, dict(phase=phase, steps=0, loaded_contacts=0,
            distal_loaded_contacts=0, classification_changes=0, nonfoot_to_foot=0,
            foot_to_nonfoot=0, steps_with_changes=0, original_distal_support_gate_steps=0,
            original_raised_body_gate_steps=0))
        summary['steps'] += 1
        if step in partial:
            for name in ['distal_support_gate', 'raised_body_gate']:
                summary['original_'+name+'_steps'] += int(partial[step]['classification'][name])
        comparisons = record['replay']['comparisons']
        changed_step = False
        for body in capture.BODIES:
            key = (phase, body)
            bodies.setdefault(key, dict(phase=phase, body=body, observed_steps=0,
                loaded_contacts=0, classification_changes=0, nonfoot_to_foot=0,
                foot_to_nonfoot=0, maximum_abs_local_y_difference_m=0.0,
                loaded_impulse_sum_ns=0.0))['observed_steps'] += 1
        for contact in comparisons:
            body = bodies[(phase,contact['body_id'])]
            summary['loaded_contacts'] += 1; body['loaded_contacts'] += 1
            summary['distal_loaded_contacts'] += int(contact['body_id'].endswith('_distal'))
            body['maximum_abs_local_y_difference_m'] = max(body['maximum_abs_local_y_difference_m'],abs(contact['local_y_difference_m']))
            body['loaded_impulse_sum_ns'] += contact['normal_impulse_ns']
            if contact['membership_changed']:
                changed_step = True
                direction = 'foot_to_nonfoot' if contact['original_classified_as_foot'] else 'nonfoot_to_foot'
                for stats in [summary,body]:
                    stats['classification_changes'] += 1; stats[direction] += 1
        summary['steps_with_changes'] += int(changed_step)
    phase_rows, body_rows = list(phases.values()), list(bodies.values())
    assert sum(p['steps'] for p in phase_rows) == replay['diagnostic_steps_replayed']
    assert sum(p['loaded_contacts'] for p in phase_rows) == replay['matched_source_contacts']
    assert sum(p['classification_changes'] for p in phase_rows) == replay['classification_changes']
    final = report['r10ab_partial_recovery']['final_memory']
    return dict(independent_successor_replay=replay, phase_summaries=phase_rows,
        phase_body_summaries=body_rows,
        reported_partial_terminal=dict(phase=final['phase'], failure_code=final['terminal_failure_code'],
            total_steps_observed=final['total_steps_observed'], phase_steps_observed=final['phase_steps_observed']),
        denominator='Each comparison is one uniquely matched loaded body-floor source contact at one completed step; repeated contacts across time are not independent samples.',
        phase_rule='Use the partial controller receipt prior_phase for recovery steps, otherwise the original orchestrator_phase. Preserve original gate counts; no counterfactual trajectory is evaluated.')


def audit(record):
    assert record['claim_boundary'] == CLAIMS
    for binding in record['bindings'] + [record['auditor']]:
        assert closure.bind(binding['path']) == binding
    assert record['native_parity'] == native_parity()
    assert record['analysis'] == analyze()
    return dict(ok=True, **CLAIMS,
        replayed_steps=record['analysis']['independent_successor_replay']['diagnostic_steps_replayed'],
        loaded_contacts=record['analysis']['independent_successor_replay']['matched_source_contacts'],
        classification_changes=record['analysis']['independent_successor_replay']['classification_changes'])


def create():
    assert not RECORD.exists()
    closure.audit(closure.read(closure.RECORD))
    paths = [closure.RECORD, Path(__file__), Path(reader.__file__), Path(capture.__file__),
        ROOT/'sdk/conformance/r10ac_contact_frame_replay.py',
        ROOT/'tests/test_contact_frame_configured_vector_v2.py',
        ROOT/'tests/test_contact_frame_configured_vector_v2.gd']
    paths += [p for folder in [POST,PARITY] for p in sorted(folder.iterdir()) if p.is_file()]
    record = dict(schema_version='sporespore_r10ae_post_exposure_contact_analysis_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',
            authority_mode='post_exposure_read_only_successor_analysis',question_class='development'),
        original_closure=closure.RECORD.relative_to(ROOT).as_posix(),
        auditor=closure.bind(__file__), bindings=[closure.bind(p) for p in dict.fromkeys(paths)],
        native_parity=native_parity(), analysis=analyze(), claim_boundary=CLAIMS,
        interpretation_limits='This descriptive result uses a reader repaired after seeing the original refusal. It does not change the original invalid grade or prove a classification correction improves recovery. A prospective repair needs its own declaration, qualified implementation and fresh physical population.')
    result = audit(record); closure.write_new(RECORD,record)
    return result


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--create',action='store_true')
    args=parser.parse_args();print(json.dumps(create() if args.create else audit(closure.read(RECORD))))
