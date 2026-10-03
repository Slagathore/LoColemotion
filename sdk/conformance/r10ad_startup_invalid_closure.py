"""Read-only closure of the consumed R10AD runtime-context mismatch before physics."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT.parent / 'SporeSpore_Evidence'
HEAD = '83af08fba5d6388688ade95653d364a02b4bab67'
RUN = EVIDENCE / 'development-recovery-smoke-8485948617454f89ab7ac3f3fdab0cb1'
OUTER = EVIDENCE / 'r10ad-frozen-diagnostic-supervisor-8625cb371ae74c0d9333cef1d1ea330f'
TOKEN = EVIDENCE / 'r10ad_contact_frame_diagnostic_62248_consumption_v1.json'
KEY = ROOT / 'sdk/recovery/r10ad_v56_walking_entry_contract_v5.json'
CONTRACT = ROOT / 'sdk/development/r10ad_safety_stage_contract_v1.json'
RECORD = ROOT / 'sdk/recovery/r10ad_startup_invalid_closure_v1.json'
CLAIMS = dict(original_attempt_classification='consumed_infrastructure_invalid_before_world',
    original_attempt_reclassified=False, population_consumed=True, rerun_authorized=False,
    contact_frame_measurement_obtained=False, recovery_result_obtained=False,
    unique_original_root_cause_established=True, physical_acceptance_authority=False,
    release_authority=False, sdk1_score='14/20', full_program_score='14/25')


def require(value, code):
    if not value:
        raise ValueError('R10AD_STARTUP_CLOSURE_' + code)


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def bind(path):
    path = Path(path)
    return dict(path=path.as_posix(), byte_length=path.stat().st_size,
        raw_sha256='sha256:' + hashlib.sha256(path.read_bytes()).hexdigest())


def verify_binding(binding):
    require(bind(binding['path']) == binding, 'RETAINED_BYTES:' + binding['path'])


def write_new(path, value):
    with Path(path).open('x', encoding='utf-8', newline='\n') as stream:
        json.dump(value, stream, indent=2); stream.write('\n')


def frozen_sources():
    rows = read(KEY)['bound_source_files']
    require(len(rows) == len({r['path'] for r in rows}) == 1839, 'FROZEN_INPUT_POPULATION')
    result = subprocess.run(['git', 'cat-file', '--batch'], cwd=ROOT,
        input=''.join(HEAD + ':' + r['path'] + '\n' for r in rows).encode(),
        capture_output=True, timeout=60, check=True, creationflags=subprocess.CREATE_NO_WINDOW)
    require(not result.stderr, 'GIT_STDERR')
    raw, cursor = result.stdout, 0
    for row in rows:
        end = raw.index(b'\n', cursor); header = raw[cursor:end].split()
        require(len(header) == 3 and header[1] == b'blob', 'FROZEN_BLOB:' + row['path'])
        size = int(header[2]); data = raw[end + 1:end + 1 + size]; cursor = end + 2 + size
        variants = [data] if b'\r\n' in data else [data, data.replace(b'\n', b'\r\n')]
        require(any(len(v) == row['byte_length'] and
            'sha256:' + hashlib.sha256(v).hexdigest() == row['raw_sha256'] for v in variants),
            'FROZEN_HASH:' + row['path'])
    require(cursor == len(raw), 'FROZEN_BATCH_TAIL')


def validate_observation(declaration, supervisor, report, termination, token, launch, contract):
    source = dict(head=HEAD, dirty=False, status=[], changed_file_bindings=[])
    require(declaration['source_snapshot'] == supervisor['source_snapshot'] == source, 'SOURCE')
    require(supervisor['ok'] is False and supervisor['physical_attempt_started'] is True
        and supervisor['failure_code'] == 'R10V_RETENTION_EXIT_OR_RETRY', 'SUPERVISOR')
    require(report['ok'] is False and report['failure_code'] == 'QSDK_R10F_L15_PRE_WORLD_CONTEXT_INVALID', 'WORKER')
    counters = ['world_build_count', 'solver_step_count', 'model_construction_attempt_count',
        'model_construction_count', 'external_kick_application_count', 'held_out_cell_access_count']
    require(all(type(report[k]) is int and report[k] == 0 for k in counters), 'ZERO_WORLD_COUNTERS')
    require(all(report[k] is False for k in ['physics_state_modified', 'physical_question_opened',
        'recovery_success_observed', 'physical_acceptance_authority', 'release_authority']), 'WORKER_CLAIMS')
    require(termination['exit_code'] == 1 and termination['timed_out'] is False
        and isinstance(termination['termination_ready_receipt'], dict)
        and bool(termination['termination_ready_receipt'])
        and termination['termination_protocol_valid'] is True
        and isinstance(termination['r10f_l15_launch_relationship'], dict), 'TERMINATION')
    require(declaration['seed'] == token['seed'] == 62248
        and token['attempt_id'] == declaration['attempt_id'] == launch['attempt_id']
        and token['attempt_limit'] == 1 and token['source_commit'] == HEAD, 'RESERVATION')
    require(declaration['safety_stages'] == supervisor['safety_stages'], 'STAGE_RECEIPTS')
    stages = declaration['safety_stages']; expected = contract['stages']
    require(len(stages) == len(expected) == 57 and contract['total_tests'] == 203, 'STAGE_POPULATION')
    for stage, spec in zip(stages, expected, strict=True):
        require(stage['id'] == spec['id'] and stage['passed'] is True and stage['timed_out'] is False
            and type(stage['exit_code']) is int and stage['exit_code'] == 0
            and stage['test_count'] == stage['expected_test_count'] == spec['tests'], 'STAGE_FAILED')
    require(sum(s['test_count'] for s in stages) == 203, 'TEST_POPULATION')
    return dict(complete_safety_gate_passed=True, safety_stages=57, safety_tests=203,
        diagnostic_seed=62248, exposed_prefix_phase=248, physical_worlds=0,
        physical_solver_steps=0, physical_kicks=0,
        original_worker_failure=report['failure_code'], original_supervisor_failure=supervisor['failure_code'],
        ready_receipt_obtained=True, native_world_claim_obtained=True)


def observed():
    child = RUN / 'children/kick_passive_recovery_resume'
    declaration = read(RUN / 'declaration.json'); launch = read(RUN / 'r10ad_development_launch.json')
    result = validate_observation(declaration, read(RUN / 'supervisor_result.json'),
        read(child / 'worker_report.json'), read(child / 'termination_receipt.json'),
        read(TOKEN), launch, read(CONTRACT))
    require((child / 'r10ad_native_world_claim_v1.json').is_file(), 'MISSING_NATIVE_CLAIM')
    require(read(OUTER / 'execution.json')['ok'] is False, 'OUTER_EXIT')
    for field, path in [('declaration', RUN / 'declaration.json'), ('source_key', KEY),
                        ('safety_contract', CONTRACT), ('stage_reservation', TOKEN)]:
        require(launch[field] == {k: v for k, v in bind(path).items() if k != 'byte_length'}, 'LAUNCH_' + field)
    require(launch['freeze'] == dict(root=ROOT.as_posix(), remote='https://github.com/Slagathore/sporespore.git',
        branch='main', head=HEAD, origin_main=HEAD, live_origin_main=HEAD, clean=True), 'FREEZE')
    require(all(launch[k] is False for k in ['official_qualification', 'physical_acceptance_authority', 'release_authority']), 'LAUNCH_CLAIMS')
    logs = []
    for stage in declaration['safety_stages']:
        texts = []
        for stream in ['stdout', 'stderr']:
            path = RUN / (stage['id'] + '.' + stream + '.log'); binding = bind(path)
            require(stage[stream] == path.name and binding['raw_sha256'] == 'sha256:' + stage[stream + '_sha256'], 'STAGE_LOG')
            logs.append({k: v for k, v in binding.items() if k != 'byte_length'})
            texts.append(path.read_text(encoding='utf-8'))
        text = '\n'.join(texts)
        require(re.findall(r'^Ran (\d+) tests? in [0-9.]+s\s*$', text, re.M) == [str(stage['test_count'])]
            and len(re.findall(r'^OK\s*$', text, re.M)) == 1, 'TEST_LOG_POPULATION')
    require(logs == launch['safety_logs'], 'LAUNCH_LOGS')
    report = read(child / 'worker_report.json')
    detail = report['detail']
    require(detail['failure_code'] == 'L15_PRE_WORLD_PREPARED_CONTEXT_MISMATCH'
        and detail['expected_capture_binding_matched'] is False, 'CONTEXT_MISMATCH')
    native_lines = [line[len('DEVELOPMENT_SMOKE_ZERO_WORLD '):] for line in
        (RUN / 'smoke_native_safety.stdout.log').read_text(encoding='utf-8-sig').splitlines()
        if line.startswith('DEVELOPMENT_SMOKE_ZERO_WORLD ')]
    require(len(native_lines) == 1, 'CONTEXT_ORIGIN')
    expected = json.loads(native_lines[0])['native']['l15_prepared_collection_context']
    observed_capture = detail['observed_capture']
    for capture in [expected, observed_capture]:
        raw = capture['utf8_text'].encode('utf-8')
        require(len(raw) == capture['utf8_byte_length'] and
            'sha256:' + hashlib.sha256(raw).hexdigest() == capture['raw_sha256'], 'CAPTURE_HASH')
    expected_binding = {k: expected[k] for k in ['raw_sha256', 'utf8_byte_length']}
    require(detail['expected_capture_binding'] == declaration['prepared_context_expectation']['raw_capture_binding']
        == expected_binding, 'EXPECTED_ORIGIN')
    def source(capture):
        return json.loads(json.loads(capture['utf8_text'])['source_context']['utf8_text'])
    before, after = source(expected), source(observed_capture)
    legacy = before['runtime_profile_receipt']['runtime_identity']
    selected = after['runtime_profile_receipt']['runtime_identity']
    require(legacy['engine_binary']['raw_sha256'] == '1b365fe5a054e2614e2c063273d6e686593eafac81836475385df14b65177e4b'
        and selected['engine_binary']['raw_sha256'] == '491663b2f41147938b45eeb0863d68a0bb14ec18c6349d94402df846f29f9347'
        and selected['r10ad_diagnostic_only'] is True, 'RUNTIME_MISMATCH')
    allowed = {'r162_zero_world_context_sha256', 'r163_route_ghost_context_sha256',
        'r164_finite_behavior_context_sha256', 'r165_behavior_context_sha256',
        'r170_behavior_context_sha256', 'runtime_binding', 'runtime_profile_receipt',
        'runtime_qualification_sha256'}
    changed = {k for k in before.keys() | after.keys() if before.get(k) != after.get(k)}
    require(changed == allowed, 'CONTEXT_DIFFERENCE_SCOPE')
    require(report['r10ad_native_world_claim']['world_permission_consumed'] is False, 'PERMISSION_UNUSED')
    startup = [json.loads(line.split(' ', 1)[1]) for line in (child / 'worker.stdout.txt').read_text(
        encoding='utf-8-sig').splitlines() if line.startswith('R10AD_STARTUP_DIAGNOSTIC ')]
    require(len(startup) == 1 and startup[0]['ok'] is True, 'STARTUP_SUCCEEDED')
    result.update(expected_context_engine_sha256=legacy['engine_binary']['raw_sha256'],
        observed_context_engine_sha256=selected['engine_binary']['raw_sha256'],
        expected_capture_binding=expected_binding,
        observed_capture_binding={k: observed_capture[k] for k in ['raw_sha256', 'utf8_byte_length']},
        differing_source_context_fields=sorted(changed), startup_helper_succeeded=True,
        native_world_permission_consumed=False,
        failure_cause='Launcher expected context came from the legacy v6 safety fixture; child selected the declared v7 diagnostic runtime.')
    return result


def audit(record):
    require(record['claim_boundary'] == CLAIMS and record['source_commit'] == HEAD, 'RECORD_CLAIMS')
    for binding in record['bindings'] + [record['auditor']]:
        verify_binding(binding)
    frozen_sources()
    require(record['observed'] == observed(), 'OBSERVATION_CHANGED')
    return dict(ok=True, **record['observed'], **CLAIMS)


def create():
    require(not RECORD.exists(), 'ALREADY_CLOSED')
    frozen_sources(); observation = observed()
    paths = [p for folder in [RUN, OUTER] for p in sorted(folder.rglob('*')) if p.is_file()]
    paths += [TOKEN, KEY, CONTRACT]
    record = dict(schema_version='sporespore_r10ad_startup_invalid_closure_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
            authority_mode='consumed_pre_world_infrastructure_invalid_closure', question_class='development'),
        source_commit=HEAD, original_run=RUN.as_posix(), auditor=bind(__file__),
        bindings=[bind(p) for p in paths], observed=observation, claim_boundary=CLAIMS,
        diagnosis_limits='Both original captures and startup receipts are retained. The expected capture is byte-identical to the legacy safety-stage capture. The observed capture selects the declared v7 images. This establishes the immediate context-mismatch cause, not any physical recovery result or success of a future repair.',
        next_action='Distinct successor with selected-runtime context production and an independent pre-world consumer round trip before reservation. No R10AD retry or source-key renewal.')
    audit(record); write_new(RECORD, record)
    return audit(record)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('--create', action='store_true')
    args = parser.parse_args()
    print(json.dumps(create() if args.create else audit(read(RECORD))))
