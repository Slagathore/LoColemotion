"""Close the original five-cell R10V development population without new physics.

Historical source is checked against its retained archive. This reader never
calls a current-source launch authorizer or manufactures a missing receipt.
"""
import argparse
import json
from pathlib import Path
import re

from r10s_launch_component import ROOT, EVIDENCE, bind, read, verify
from r10t_initial_invalid_closure import root_scalars
from r10t_route_integration_component import write_new
import qsdk_r10f_l15_collection_retention as packet
import r10v_windows_job as win

RECORD = ROOT/'sdk/recovery/r10v_development_population_closure_v1.json'
REVIEW = EVIDENCE/'r10v-development-population-closure-fba3271b7d3a49888dd1472e2585183f'
VALIDATION = REVIEW/'closure_validation_v2'
HEAD = '3e6eeba85e8b424c9efd3e791e3689013b89505b'
KEY = ROOT/'sdk/recovery/r10v_v56_walking_entry_contract_v23.json'
CONTRACT = ROOT/'sdk/development/r10v_safety_stage_contract_v3.json'
DESIGN = ROOT/'sdk/recovery/r10v_durable_workflow_design_v1.json'
FAILED_PREHOST = EVIDENCE/'r10v-prehost-4e1d7760cb5f4dceb0338841b2e0ba16'
FAILED_OUTER = EVIDENCE/'r10v-full-workflow-790ac89403da46a88502aa6579a532fd'
FAILED_PROBE = EVIDENCE/'r10v-production-host-81ceea2e63174d548ddd7cd1cc1d6cea'
ROLES = ['matched_no_kick_continuation', 'kick_passive_recovery_resume']
CLAIMS = dict(question_class='development', original_results_reclassified=False,
    physical_population_consumed=True, retry_permitted=False, baseline_reused=False,
    held_out_population_declared=False, physical_acceptance_authority=False,
    release_authority=False, sdk1_m07_satisfied=False, sdk1_score='14/20', full_program_score='14/25')


def require(value, code):
    if not value:
        raise ValueError('R10V_CLOSURE_'+code)


def ref(path):
    value = bind(path)
    return dict(path=value['path'], raw_sha256=value['raw_sha256'])


def same(left, right, code):
    require(packet.same(left, right), code)


def check_cell(descriptor, child, cell, replay, header, seed, entry_kind, handoff):
    role = descriptor['role']
    require(role in ROLES and child['role'] == cell['role'] == role, 'CELL_ROLE')
    require(cell['child_attempt_id'] == descriptor['child_attempt_id'], 'CELL_IDENTITY')
    require(cell['entry_kind'] == entry_kind and cell['post_recovery_handoff'] == handoff, 'CELL_BRANCH')
    require(cell['finite_task_predicates_passed'] is True, 'CELL_NOT_POSITIVE')
    measurement = cell['measurement']
    require(measurement['finite_task_predicates_passed'] is True
        and measurement['predicates'] and all(v is True for v in measurement['predicates'].values()), 'CELL_PREDICATES')
    require(measurement['original_attempt_reclassified'] is False, 'CELL_REGRADED')
    for result in (measurement, replay):
        require(result['physical_acceptance_authority'] is False and result['release_authority'] is False, 'CELL_AUTHORITY')
        same([result['world_build_count'], result['solver_step_count']], [0, 0], 'REPLAY_CREATED_PHYSICS')
    require(replay['ok'] is True and replay['complete_report_timeline_replayed'] is True, 'REPLAY_INCOMPLETE')
    same(replay, child['passive_entry_replay'], 'ORIGINAL_REPLAY')
    same(replay['transition_count'], child['solver_steps'], 'REPLAY_STEP_COUNT')
    same(header, dict(world_build_count=1, external_kick_application_count=int(role == ROLES[1]),
        solver_step_count=child['solver_steps'], seed=seed, stop_reason='diagnostic_cycle_aligned_stop_complete'), 'REPORT_HEADER')
    require(child['stop_reason'] == header['stop_reason'], 'CHILD_STOP')
    walking = measurement['walking']
    same(walking, replay['finite_walking_measurement'], 'WALKING_REPLAY')
    require(len(walking['planned_cycles']) == 4 and type(walking['stopping_commands']) is int
        and walking['stopping_commands'] == 120 and walking['pre_first_to_post_last_body_forward_m'] >= 0.02, 'FINITE_WALKING')
    require(replay['finite_recovery_task']['cycle_and_stop_boundary_reached'] is True
        and replay['finite_recovery_task']['fixed_tail_coverage_reinterpreted'] is False, 'FINITE_BOUNDARY')
    hold = replay['stance_entry_replay']['replayed_post_recovery_hold_commands']
    require((hold == 106 if handoff == 'bounded_hold' else hold == 0), 'HOLD_COMMANDS')
    return dict(seed=seed, role=role, child_attempt_id=cell['child_attempt_id'], entry_kind=entry_kind,
        post_recovery_handoff=handoff, physical_worlds=1, physical_kicks=header['external_kick_application_count'],
        solver_steps=child['solver_steps'], replayed_transitions=replay['transition_count'],
        post_recovery_hold_commands=hold, walking_commands=walking['command_count'],
        planned_cycles=4, stopping_commands=120, forward_advance_m=walking['pre_first_to_post_last_body_forward_m'],
        finite_task_predicates=measurement['predicates'], all_tasks_positive=True)


def host_terminal(folder, run):
    request_path = folder/'request.json'; request = read(request_path)
    result = read(folder/'host_result.json'); started = read(folder/'host_started.json')
    assigned = read(folder/'job_assigned.json'); supervisor = read(folder/'supervisor_started.json')
    require(result['ok'] is True and result['failure_code'] == '' and result['owned_cleanup_complete'] is True
        and result['source_unchanged'] is True and result['worker_exit_code'] == 0, 'HOST_TERMINAL')
    for receipt in (result, started, assigned, supervisor):
        same(receipt['request'], bind(request_path), 'HOST_REQUEST')
    same(result['host_identity'], started['host_identity'], 'HOST_IDENTITY')
    same(result['host_identity'], assigned['host_identity'], 'JOB_IDENTITY')
    require(assigned['kill_on_job_close'] is True, 'HOST_JOB')
    require(not any(win.alive(i) for i in (result['host_identity'], assigned['worker_identity'], supervisor['supervisor_identity'])), 'LIVE_OWNER')
    same(read(folder/'published.json'), dict(request=bind(request_path), host_identity=result['host_identity'],
        host_result=bind(folder/'host_result.json')), 'HOST_PUBLICATION')
    same(result['primary_terminal'], bind(run/'supervisor_result.json'), 'HOST_PRIMARY')
    for item in result['logs']+[result['primary_terminal'], result['progress_log']]:
        verify(item)
    roles = ROLES if request['seed'] == 41345 else [ROLES[1]]
    stages = [('safety_gate','')]+[('child',r) for r in roles]+[('replay',r) for r in roles]+[('final_audit',''),('publication','')]
    rows = [json.loads(line) for line in (folder/'progress.jsonl').read_text(encoding='utf-8').splitlines()]
    same([(x['stage'],x['state'],x['role']) for x in rows],
        [(stage,state,role) for stage,role in stages for state in ('start','end')], 'HOST_PROGRESS_SEQUENCE')
    context = read(folder/'supervisor_context.json')
    for index,row in enumerate(rows):
        same(row['sequence'], index, 'HOST_PROGRESS_INDEX')
        same(row['context'], context, 'HOST_PROGRESS_CONTEXT')
        require(row['source_commit'] == HEAD, 'HOST_PROGRESS_SOURCE')
        if row['stage'] in ('replay','final_audit') and row['state'] == 'end':
            sub = row['subject']
            same(sub['process_identity'], rows[index-1]['subject']['process_identity'], 'AUDIT_PROCESS')
            require(sub['exit_code'] == 0 and sub['timed_out'] is False, 'AUDIT_PROCESS_RESULT')
            for name in ('stdout','stderr'): verify(sub[name])
    return request, context


def observe_run(spec):
    run = EVIDENCE/spec['run']; folder = EVIDENCE/spec['host']
    request, context = host_terminal(folder, run)
    declaration = read(run/'declaration.json'); supervisor = read(run/'supervisor_result.json')
    audit = read(run/'independent_audit.stdout.json'); finite = audit['r10v_finite_development']
    same(supervisor['independent_audit'], audit, 'ORIGINAL_AUDIT')
    marker = (run/'published_marker.txt').read_text(encoding='utf-8')
    prefix = 'DEVELOPMENT_RECOVERY_SMOKE_COMPLETE '
    require(marker.startswith(prefix), 'PUBLICATION_PREFIX')
    same(packet.parse_json(marker[len(prefix):]), supervisor, 'SUPERVISOR_PUBLICATION')
    require(supervisor['ok'] is True and supervisor['failure_code'] == '' and audit['ok'] is True, 'ORIGINAL_RESULT')
    same(supervisor['source_snapshot'], declaration['source_snapshot'], 'SOURCE_SNAPSHOT')
    same(declaration['source_snapshot'], dict(head=HEAD,dirty=False,status=[],changed_file_bindings=[]), 'CLEAN_FREEZE')
    same(declaration['r10v_host'], context, 'DECLARATION_HOST')
    same(supervisor['r10v_host'], context, 'SUPERVISOR_HOST')
    require(request['attempt_id'] == declaration['attempt_id'] and request['seed'] == declaration['seed'] == spec['seed'], 'DECLARATION_SEED')
    own = declaration['r10v_development']
    require(own['seed']['prefix_phase'] == spec['phase'], 'DECLARATION_PHASE')
    require(supervisor['physical_acceptance_authority'] is False and supervisor['release_authority'] is False
        and supervisor['official_qualification_passed'] is False and supervisor['physical_attempt_started'] is True, 'SUPERVISOR_CLAIMS')
    stages = declaration['safety_stages']; expected = read(CONTRACT)['stages']
    same(stages, supervisor['safety_stages'], 'SAFETY_ORIGINAL')
    same([s['id'] for s in stages], [s['id'] for s in expected], 'SAFETY_POPULATION')
    require(len(stages) == 66 and sum(s['test_count'] for s in stages) == 258, 'SAFETY_COUNT')
    for stage, definition in zip(stages, expected):
        require(stage['passed'] is True and stage['exit_code'] == 0 and stage['timed_out'] is False, 'SAFETY_RESULT')
        same(stage['test_count'], definition['tests'], 'SAFETY_TEST_COUNT')
        for stream in ('stdout','stderr'):
            require(bind(run/stage[stream])['raw_sha256'] == 'sha256:'+stage[stream+'_sha256'], 'SAFETY_LOG')
    prehost = read(EVIDENCE/spec['prehost']/'qualification.json')
    same(request['prehost_qualification'], bind(EVIDENCE/spec['prehost']/'qualification.json'), 'PREHOST_BINDING')
    require(prehost['ok'] is True and prehost['owned_cleanup_complete'] is True and prehost['failure_code'] == '', 'PREHOST_RESULT')
    same(prehost['stages'], stages[-2:], 'FRESH_PREHOST_STAGES')
    same(prehost['source_snapshot'], request['source_snapshot'], 'PREHOST_SOURCE')
    launch = read(run/'r10v_development_launch.json'); reservation = read(EVIDENCE/spec['reservation'])
    same(launch['declaration'], ref(run/'declaration.json'), 'LAUNCH_DECLARATION')
    same(launch['stage_reservation'], ref(EVIDENCE/spec['reservation']), 'LAUNCH_RESERVATION')
    same(launch['freeze'], dict(root=ROOT.as_posix(),remote='https://github.com/Slagathore/sporespore.git',branch='main',
        head=HEAD,origin_main=HEAD,live_origin_main=HEAD,clean=True), 'PUSHED_FREEZE')
    expected_reservation = dict(schema_version='sporespore_r10v_first_pair_consumption_v1',
        design_sha256=own['design_binding']['raw_sha256'],attempt_id=declaration['attempt_id'],
        declaration=ref(run/'declaration.json'),source_commit=HEAD,attempt_limit=1)
    if spec['seed'] != 41345:
        expected_reservation.update(schema_version='sporespore_r10v_stage_consumption_v1',stage=own['stage'],seed=spec['seed'])
        pair = read(REVIEW/'population_locations.json')[0]
        same(own['prerequisite_pair'],dict(**ref(EVIDENCE/pair['run']/'independent_audit.stdout.json'),
            attempt_id=pair['run'].removeprefix('development-recovery-smoke-')), 'ORIGINAL_PAIR_PREREQUISITE')
    same(reservation,expected_reservation, 'ONE_USE_RESERVATION')
    same([c['role'] for c in declaration['children']], ROLES if spec['seed'] == 41345 else [ROLES[1]], 'DECLARED_ROLE_POPULATION')
    require(finite['all_tasks_positive'] is True and finite['branch_coverage_complete'] is True, 'FINITE_POPULATION')
    same(finite['seed'], spec['seed'], 'FINITE_SEED')
    require(len(declaration['children']) == len(audit['children']) == len(finite['cells']) == len(spec['entries']), 'CELL_COUNT')
    cells = []
    for index,(descriptor,child,cell) in enumerate(zip(declaration['children'],audit['children'],finite['cells'])):
        child_root = run/'children'/descriptor['role']
        require(child['child_envelope_sha256'] == cell['child_envelope_sha256'] == bind(child_root/'child_envelope.json')['raw_sha256'], 'ORIGINAL_ENVELOPE')
        replay = read(child_root/'passive_entry_replay_result.json')
        header = root_scalars(child_root/'worker_report.json', ['world_build_count','external_kick_application_count','solver_step_count','seed','stop_reason'])
        measured = check_cell(descriptor,child,cell,replay,header,spec['seed'],spec['entries'][index],spec['handoffs'][index])
        same(measured['solver_steps'], spec['steps'][index], 'OBSERVED_STEP_COUNT')
        measured['prefix_phase'] = spec['phase']; cells.append(measured)
    same(sum(c['solver_steps'] for c in cells), audit['total_solver_steps'], 'TOTAL_STEPS')
    return dict(seed=spec['seed'],prefix_phase=spec['phase'],evidence_root=run.as_posix(),host_root=folder.as_posix(),
        safety_stages=66,safety_tests=258,original_host_success=True,original_publication_complete=True,
        source_unchanged=True,owned_cleanup_complete=True,cells=cells)


def failed_prehost():
    value = read(FAILED_PREHOST/'qualification.json'); diagnosis = read(FAILED_OUTER/'observation_timeout_diagnosis.json')
    require(value['ok'] is False and value['failure_code'] == 'R10V_PREHOST_COMPLETE_STAGES', 'FAILED_PREHOST_REGRADED')
    require(len(value['stages']) == 1 and value['stages'][0]['passed'] is False, 'FAILED_PREHOST_STAGES')
    require(diagnosis['original_qualification_passed'] is False and diagnosis['original_qualification_reclassified'] is False, 'DIAGNOSIS_REGRADED')
    for binding in diagnosis['bindings']: verify(binding)
    log = (FAILED_PREHOST/'r10v_production_host.stderr.log').read_text(encoding='utf-8')
    require('LIFECYCLE_OBSERVATION_TIMEOUT' in log and log.rstrip().endswith('FAILED (failures=1)'), 'ORIGINAL_FAILURE')
    # ResourceWarning diagnostics can separate a test name from its status.
    require(re.findall(r'^Ran (\d+) tests in ',log,re.M) == ['28']
        and len(re.findall(r'^(?:test_.* \.\.\. )?ok$',log,re.M)) == 27
        and len(re.findall(r'^FAIL: ',log,re.M)) == 1, 'ORIGINAL_FAILURE_COUNT')
    return dict(qualification_passed=False,tests=28,passed=27,failures=1,
        failure='LIFECYCLE_OBSERVATION_TIMEOUT',original_result_reclassified=False,
        fresh_qualification_used_unchanged_source_and_limits=True,world_build_count=0,solver_step_count=0)


def observed():
    specs = read(REVIEW/'population_locations.json')
    same([s['seed'] for s in specs], [41345,41346,41341,41343], 'DECLARED_SEED_POPULATION')
    same([s['phase'] for s in specs], [245,246,241,243], 'DECLARED_PHASE_POPULATION')
    same([s['entries'] for s in specs], [['unselected','upright'],['upright'],['partial'],['prone']], 'DECLARED_BRANCH_POPULATION')
    same([s['handoffs'] for s in specs], [['direct','bounded_hold'],['direct'],['direct'],['direct']], 'DECLARED_HANDOFF_POPULATION')
    runs = [observe_run(s) for s in specs]; cells = [c for r in runs for c in r['cells']]
    require(len(cells) == 5 and len({c['child_attempt_id'] for c in cells}) == 5, 'UNIQUE_CHILD_POPULATION')
    return dict(classification='valid_positive_complete_development_population',runs=runs,cell_count=5,
        total_physical_worlds=sum(c['physical_worlds'] for c in cells),total_physical_kicks=sum(c['physical_kicks'] for c in cells),
        total_physical_solver_steps=sum(c['solver_steps'] for c in cells),all_tasks_positive=True,
        branch_coverage=dict(no_kick=True,upright_bounded_hold=True,upright_direct=True,partial_direct=True,prone_direct=True),
        failed_zero_world_qualification=failed_prehost(),held_out_design_precondition_satisfied=True,
        next_permitted_stage='separate_fresh_held_out_design_and_qualification',**CLAIMS)


def evidence_roots():
    roots = {REVIEW,FAILED_PREHOST,FAILED_OUTER,FAILED_PROBE,
        EVIDENCE/'r10v-production-host-controls-cfeb1d845c4b463a9187d6902fbc3c81'}
    for spec in read(REVIEW/'population_locations.json'):
        roots.update(EVIDENCE/spec[k] for k in ('run','host','outer','prehost'))
    for root in list(roots):
        registry = root/'owned_requests.jsonl'
        if registry.exists():
            for line in registry.read_text(encoding='utf-8').splitlines():
                # These are pre-control bindings. Negative controls deliberately
                # cross request bytes; retain the registry and actual bytes as-is.
                binding = json.loads(line)
                owned = Path(binding['path']).parent
                require(owned.parent == EVIDENCE and re.fullmatch(r'r10v-production-host-[0-9a-f]{32}',owned.name)
                    and Path(binding['path']).name == 'request.json', 'OWNED_ROOT')
                roots.add(owned)
    return roots


def audit(record=None):
    value = read(RECORD) if record is None else record
    same(value['claim_boundary'], CLAIMS, 'CLAIM_BOUNDARY')
    for item in value['bindings']+[value['auditor'],value['evidence_manifest'],value['source_archive']]: verify(item)
    for item in read(value['evidence_manifest']['path'])['files']: verify(item)
    validation = read(VALIDATION/'execution.json')
    require(validation['exit_code'] == 0 and validation['source_unchanged'] is True, 'CLOSURE_VALIDATION')
    before = read(VALIDATION/'source_before.json')
    same(before,read(VALIDATION/'source_after.json'),'CLOSURE_VALIDATION_SOURCE')
    tested = {item['path']:item for item in before['changed_files']}
    for name in ('sdk/conformance/r10v_development_closure.py','tests/test_r10v_development_closure.py'):
        require(tested[name]['raw_sha256'] == bind(ROOT/name)['raw_sha256'], 'CLOSURE_TESTED_BYTES')
    tests = (VALIDATION/'tests.stderr.txt').read_text(encoding='utf-8')
    require(re.findall(r'^Ran (\d+) tests in ',tests,re.M) == ['8'] and tests.rstrip().endswith('OK'), 'CLOSURE_CONTROL_RESULTS')
    archive = read(value['source_archive']['path'])
    require(archive['source_commit'] == HEAD and archive['source_files'] == 1102, 'ARCHIVED_FREEZE')
    for item in read(KEY)['bound_source_files']:
        require(bind(Path(archive['archive']['directory'])/item['path'])['raw_sha256'] == item['raw_sha256'], 'ARCHIVED_SOURCE')
    result = observed(); same(value['observed'],result,'OBSERVATION_DRIFT')
    return result


def create():
    require(not RECORD.exists(), 'ALREADY_CLOSED')
    result = observed()
    paths = {p for root in evidence_roots() for p in root.rglob('*') if p.is_file()}
    paths.update(EVIDENCE/s['reservation'] for s in read(REVIEW/'population_locations.json'))
    manifest = REVIEW/'retained_evidence_manifest.json'
    write_new(manifest,dict(schema_version='sporespore_r10v_development_population_retention_v1',files=[bind(p) for p in sorted(paths)]))
    value = dict(schema_version='sporespore_r10v_development_population_closure_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='consumed_original_development_population_closure',question_class='development'),
        source_commit=HEAD,auditor=bind(__file__),evidence_manifest=bind(manifest),source_archive=bind(REVIEW/'source_archive.json'),
        bindings=[bind(p) for p in (KEY,CONTRACT,DESIGN,REVIEW/'population_locations.json',
            ROOT/'tests/test_r10v_development_closure.py')],observed=result,claim_boundary=CLAIMS,
        scope='Five original fresh development cells with complete original host, supervisor, replay and publication receipts. No development evidence is promoted to held-out acceptance. The failed prehost qualification remains failed; the fresh complete qualification used identical source and limits.')
    audit(value); write_new(RECORD,value)
    return result


if __name__ == '__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--create',action='store_true');parser.add_argument('--observe',action='store_true');args=parser.parse_args()
    result=create() if args.create else observed() if args.observe else audit()
    print('R10V_DEVELOPMENT_CLOSURE '+json.dumps(result,allow_nan=False))
