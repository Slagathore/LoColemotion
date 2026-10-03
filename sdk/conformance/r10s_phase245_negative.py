"""Bind the consumed phase-245 handoff negative; never launch or regrade it."""
import argparse
import json
import math
import uuid

from r10s_launch_component import ROOT, EVIDENCE, bind, read, verify

RECORD = ROOT/'sdk/recovery/r10s_phase245_development_negative_closure_v1.json'
RUN = EVIDENCE/'development-recovery-smoke-204608746de3436083253e54ec4817f7'
OUTER = EVIDENCE/'r10s-phase245-single-launch-6bd44a0f6f6745889762ba1c3894d413'
PAIR = EVIDENCE/'development-recovery-smoke-ece7ab1f5de14c94b322a031a32433a0'
RESERVATION = EVIDENCE/'r10s_additional_branch_diagnostic_41045_consumption_v1.json'
HEAD = '0c07f2948fe9607eeee052290d4e993802da6044'
ROLE = 'kick_passive_recovery_resume'
CLAIMS = dict(question_class='development', original_result_reclassified=False,
    physical_identity_consumed=True, retry_permitted=False, complete_route_proven=False,
    held_out_population_declared=False, physical_acceptance_authority=False,
    release_authority=False, sdk1_score='14/20', full_program_score='14/25')


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
    assert declaration['seed'] == context['seed']['seed'] == 41045
    assert context['seed']['prefix_phase'] == 245 and context['required_entry_kind'] == 'upright'
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
        design_sha256=context['design_binding']['raw_sha256'], stage=context['stage'], seed=41045,
        attempt_id=declaration['attempt_id'], declaration=reference(RUN/'declaration.json'),
        source_commit=HEAD, attempt_limit=1)
    finite = audit['r10s_finite_development']
    assert finite['all_tasks_positive'] is False and finite['branch_coverage_complete'] is True
    assert len(declaration['children']) == len(audit['children']) == len(finite['cells']) == 1
    child = audit['children'][0]
    cell = finite['cells'][0]
    assert cell['role'] == child['role'] == declaration['children'][0]['role'] == ROLE
    assert cell['child_attempt_id'] == declaration['children'][0]['child_attempt_id']
    assert cell['entry_kind'] == 'upright' and cell['finite_task_predicates_passed'] is False
    predicates = cell['measurement']['predicates']
    assert predicates == dict(entry_ready=False, planned_cycles=False, forward_advance=False,
        settled_stop=False, whole_walking_envelope=False, recovery_completed=True)
    replay = read(RUN/'children'/ROLE/'passive_entry_replay_result.json')
    assert replay == child['passive_entry_replay'] and replay['ok'] is True
    assert replay['complete_report_timeline_replayed'] is True
    assert replay['transition_count'] == child['solver_steps'] == audit['total_solver_steps'] == 1034
    assert replay['entry_observation_count'] == 240 and replay['upright_observation_count'] == 522
    assert replay['walking_control_replay']['replayed_walking_steps'] == 0
    assert replay['finite_walking_measurement']['status'] == 'walking_not_reached'
    assert replay['stance_entry_independent_measurement']['recomputed_samples'] == 1
    assert replay['stance_entry_independent_measurement']['ready_samples'] == 0
    report = read(RUN/'children'/ROLE/'worker_report.json')
    assert report['ok'] is True and report['status'] == 'development_smoke_coverage_incomplete'
    assert report['stop_reason'] == child['stop_reason'] == 'diagnostic_walking_entry_not_ready'
    assert report['world_build_count'] == report['external_kick_application_count'] == 1
    assert report['solver_step_count'] == 1034 and report['maximum_solver_step_count'] == 3512
    upright = report['r10s_upright_recovery']
    memory = upright['final_memory']
    assert memory['phase'] == 'complete' and memory['standing_samples_observed'] == 60
    assert memory['total_steps_observed'] == len(upright['step_packets']) == 522
    classification = upright['step_packets'][-1]['native_receipt']['step']['classification']
    assert classification['stable_stance_gate'] is True and classification['physical_result'] is True
    stance = report['stance_entry']
    assert not stance['hold_control_rows'] and not stance['neutral_control_rows']
    assert len(stance['readiness_rows']) == 1
    row = stance['readiness_rows'][0]
    assert row['global_semantic_step'] == 1034 and row['purpose'] == 'post_recovery_entry'
    readiness = row['source']['readiness']
    assert readiness['ready'] is False and readiness['checks'] == dict(angular_settled=True,
        four_native_supports=True, horizontal_com_settled=False, upright=True,
        zero_bias_reference_path_feasible=True)
    # Use the original native whole-system COM channel already verified by replay.
    # Body origin velocities are a different observable and cannot replace it.
    com = row['source']['packet']['native_source']['observation']['center_of_mass']
    assert com['source_measurement'] is True
    velocity = com['linear_velocity_world_m_s']
    speed = math.hypot(velocity['x'], velocity['z'])
    assert math.isclose(speed, readiness['horizontal_com_speed_m_s'], rel_tol=0, abs_tol=1e-12)
    task = read(ROOT/'sdk/recovery/r10s_extended_preparation_finite_cycle_contract_v1.json')
    limit = task['stance_entry']['maximum_horizontal_com_speed_m_s']
    assert limit == 0.03 and speed > limit
    execution = read(OUTER/'execution.json')
    assert execution['exit_code'] == 0 and execution['source_commit_after'] == HEAD
    assert execution['source_status_after'] == []
    return dict(ok=True, classification='valid_development_negative_walking_entry_not_ready',
        seed=41045, prefix_phase=245, entry_kind='upright', child_attempt_id=cell['child_attempt_id'],
        physical_worlds=1, physical_kicks=1, total_physical_solver_steps=1034,
        entry_commands=240, upright_recovery_commands=522, standing_samples=60,
        walking_commands=0, planned_cycles=0, stopping_commands=0,
        complete_safety_stages=41, complete_safety_tests=194,
        horizontal_com_speed_m_s=readiness['horizontal_com_speed_m_s'],
        maximum_horizontal_com_speed_m_s=limit, readiness_checks=readiness['checks'],
        terminal_recovery_classification=classification, finite_task_predicates=predicates,
        next_permitted_stage='remaining_declared_phase241_partial_and_phase243_prone_diagnostics', **CLAIMS)


def audit():
    record = read(RECORD)
    assert record['schema_version'] == 'sporespore_r10s_phase245_negative_closure_v1'
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
    out = EVIDENCE/('r10s-phase245-negative-review-'+uuid.uuid4().hex)
    out.mkdir()
    manifest = out/'retained-evidence-manifest.json'
    value = dict(schema_version='sporespore_r10s_phase245_negative_retention_v1',
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
    record = dict(schema_version='sporespore_r10s_phase245_negative_closure_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
            authority_mode='consumed_development_negative_closure', question_class='development'),
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
    print('R10S_PHASE245_NEGATIVE '+json.dumps(create() if args.create else audit()))
