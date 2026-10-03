"""Audit the consumed R10S partial-recovery diagnostic without new physics."""
import argparse
import json
import uuid

from r10s_launch_component import ROOT, EVIDENCE, bind, read, verify

RECORD = ROOT/'sdk/recovery/r10s_phase241_development_positive_closure_v1.json'
RUN = EVIDENCE/'development-recovery-smoke-8c7701a4e4c94990b24b11033369633c'
OUTER = EVIDENCE/'r10s-phase241-single-launch-5ed33ba7edab4c0e87e442311d4491a8'
PAIR = EVIDENCE/'development-recovery-smoke-ece7ab1f5de14c94b322a031a32433a0'
RESERVATION = EVIDENCE/'r10s_additional_branch_diagnostic_41041_consumption_v1.json'
HEAD = '32e1f46ad50a04077e772ec0a0aaf70cbd69893d'
ROLE = 'kick_passive_recovery_resume'
CLAIMS = dict(question_class='development', original_result_reclassified=False,
    physical_identity_consumed=True, retry_permitted=False, baseline_reused=False,
    paired_effect_proven=False, held_out_population_declared=False,
    physical_acceptance_authority=False, release_authority=False,
    sdk1_score='14/20', full_program_score='14/25')


def reference(path):
    item = bind(path)
    return dict(path=item['path'], raw_sha256=item['raw_sha256'])


def observed():
    declaration = read(RUN/'declaration.json')
    supervisor = read(RUN/'supervisor_result.json')
    audit = read(RUN/'independent_audit.stdout.json')
    marker = (RUN/'published_marker.txt').read_text(encoding='utf-8')
    prefix = 'DEVELOPMENT_RECOVERY_SMOKE_COMPLETE '
    assert marker.startswith(prefix) and json.loads(marker[len(prefix):]) == supervisor
    assert supervisor['ok'] is True and supervisor['failure_code'] == '' and audit['ok'] is True
    assert supervisor['independent_audit'] == audit
    assert declaration['source_snapshot'] == supervisor['source_snapshot'] == dict(
        head=HEAD, dirty=False, status=[], changed_file_bindings=[])
    context = declaration['r10s_development']
    assert declaration['seed'] == context['seed']['seed'] == 41041
    assert context['seed']['prefix_phase'] == 241 and context['required_entry_kind'] == 'partial'
    assert context['stage'] == 'additional_branch_diagnostic'
    assert context['prerequisite_pair'] == dict(**reference(PAIR/'independent_audit.stdout.json'),
        attempt_id=PAIR.name.removeprefix('development-recovery-smoke-'))
    stages = supervisor['safety_stages']
    assert stages == declaration['safety_stages'] and len(stages) == 41
    assert sum(s['test_count'] for s in stages) == 194 and all(s['passed'] is True for s in stages)
    launch = read(RUN/'r10s_development_launch.json')
    assert launch['stage'] == context['stage'] and launch['declaration'] == reference(RUN/'declaration.json')
    assert launch['stage_reservation'] == reference(RESERVATION)
    assert launch['freeze'] == dict(root=ROOT.as_posix(), remote='https://github.com/Slagathore/sporespore.git',
        branch='main', head=HEAD, origin_main=HEAD, live_origin_main=HEAD, clean=True)
    assert read(RESERVATION) == dict(schema_version='sporespore_r10s_stage_consumption_v1',
        design_sha256=context['design_binding']['raw_sha256'], stage=context['stage'], seed=41041,
        attempt_id=declaration['attempt_id'], declaration=reference(RUN/'declaration.json'),
        source_commit=HEAD, attempt_limit=1)
    finite = audit['r10s_finite_development']
    assert finite['all_tasks_positive'] is True and finite['branch_coverage_complete'] is True
    assert len(declaration['children']) == len(audit['children']) == len(finite['cells']) == 1
    child, cell = audit['children'][0], finite['cells'][0]
    assert cell['role'] == child['role'] == declaration['children'][0]['role'] == ROLE
    assert cell['child_attempt_id'] == declaration['children'][0]['child_attempt_id']
    assert cell['entry_kind'] == 'partial' and cell['finite_task_predicates_passed'] is True
    measurement = cell['measurement']
    assert measurement['predicates'] == dict(entry_ready=True, planned_cycles=True, forward_advance=True,
        settled_stop=True, whole_walking_envelope=True, recovery_completed=True)
    replay = read(RUN/'children'/ROLE/'passive_entry_replay_result.json')
    assert replay == child['passive_entry_replay'] and replay['ok'] is True
    assert replay['complete_report_timeline_replayed'] is True
    assert replay['transition_count'] == child['solver_steps'] == audit['total_solver_steps'] == 2205
    assert replay['entry_observation_count'] == 240 and replay['partial_observation_count'] == 513
    assert replay['partial_initialization_count'] == 1 and replay['upright_observation_count'] == 0
    walking = measurement['walking']
    assert walking == replay['finite_walking_measurement']
    assert walking['command_count'] == 1180 and walking['cycle_end_command'] == 1060
    assert len(walking['planned_cycles']) == 4 and walking['stopping_commands'] == 120
    assert replay['walking_control_replay']['cycle_stop_final_memory']['consecutive_settled_commands'] == 120
    assert replay['finite_recovery_task']['cycle_and_stop_boundary_reached'] is True
    assert replay['finite_recovery_task']['fixed_tail_coverage_reinterpreted'] is False
    report = read(RUN/'children'/ROLE/'worker_report.json')
    assert report['ok'] is True and report['status'] == 'development_smoke_coverage_incomplete'
    assert report['stop_reason'] == child['stop_reason'] == 'diagnostic_cycle_aligned_stop_complete'
    assert report['world_build_count'] == report['external_kick_application_count'] == 1
    assert report['solver_step_count'] == 2205 and report['maximum_solver_step_count'] == 3512
    partial = report['r10s_partial_recovery']
    memory = partial['final_memory']
    assert memory['phase'] == 'complete' and memory['standing_samples_observed'] == 60
    assert memory['total_steps_observed'] == len(partial['step_packets']) == 513
    assert len(report['stance_entry']['readiness_rows']) == 1
    row = report['stance_entry']['readiness_rows'][0]
    assert row['global_semantic_step'] == 1025 and row['purpose'] == 'post_recovery_entry'
    assert row['source']['readiness']['ready'] is True
    execution = read(OUTER/'execution.json')
    assert execution['exit_code'] == 0 and execution['source_commit_after'] == HEAD
    assert execution['source_status_after'] == []
    return dict(ok=True, classification='valid_positive_partial_recovery_development',
        seed=41041, prefix_phase=241, entry_kind='partial', child_attempt_id=cell['child_attempt_id'],
        physical_worlds=1, physical_kicks=1, total_physical_solver_steps=2205,
        entry_commands=240, partial_recovery_commands=513, standing_samples=60,
        walking_commands=1180, cycle_end_command=1060, planned_cycles=4,
        stopping_commands=120, consecutive_settled_stop_commands=120,
        forward_advance_m=walking['pre_first_to_post_last_body_forward_m'],
        walking_entry_horizontal_com_speed_m_s=row['source']['readiness']['horizontal_com_speed_m_s'],
        complete_safety_stages=41, complete_safety_tests=194,
        whole_walking_envelope=measurement['envelope']['metrics'], finite_task_predicates=measurement['predicates'],
        next_permitted_stage='remaining_declared_phase243_prone_diagnostic', **CLAIMS)


def audit():
    record = read(RECORD)
    assert record['schema_version'] == 'sporespore_r10s_phase241_positive_closure_v1'
    assert record['claim_boundary'] == CLAIMS
    for item in record['bindings'] + [record['auditor'], record['evidence_manifest']]:
        verify(item)
    for item in read(record['evidence_manifest']['path'])['files']:
        verify(item)
    result = observed()
    assert result == record['observed']
    return result


def create():
    assert not RECORD.exists()
    result = observed()
    out = EVIDENCE/('r10s-phase241-positive-review-'+uuid.uuid4().hex)
    out.mkdir()
    manifest = out/'retained-evidence-manifest.json'
    value = dict(schema_version='sporespore_r10s_phase241_positive_retention_v1',
        files=[bind(p) for root in [RUN, OUTER] for p in sorted(root.rglob('*')) if p.is_file()])
    with manifest.open('x', encoding='utf-8', newline='\n') as stream:
        json.dump(value, stream, indent=2); stream.write('\n')
    paths = [RESERVATION, PAIR/'independent_audit.stdout.json',
        ROOT/'sdk/recovery/r10s_phase246_development_pair_closure_v1.json',
        ROOT/'sdk/recovery/r10s_extended_preparation_design_v1.json',
        ROOT/'sdk/recovery/r10s_extended_preparation_finite_cycle_contract_v1.json',
        ROOT/'sdk/recovery/r10s_v56_walking_entry_contract_v8.json',
        ROOT/'sdk/development/r10s_safety_stage_contract_v2.json',
        ROOT/'sdk/conformance/r10s_launch_component.py']
    record = dict(schema_version='sporespore_r10s_phase241_positive_closure_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
            authority_mode='consumed_development_positive_closure', question_class='development'),
        source_commit=HEAD, evidence_root=RUN.as_posix(), auditor=bind(__file__),
        evidence_manifest=bind(manifest), bindings=[bind(p) for p in paths],
        observed=result, claim_boundary=CLAIMS)
    with RECORD.open('x', encoding='utf-8', newline='\n') as stream:
        json.dump(record, stream, indent=2); stream.write('\n')
    return audit()


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--create', action='store_true')
    args = parser.parse_args()
    print('R10S_PHASE241_POSITIVE '+json.dumps(create() if args.create else audit()))
