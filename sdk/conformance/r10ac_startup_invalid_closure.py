"""Read-only closure of the consumed R10AC pre-world startup refusal.

The original worker did not retain the helper failure detail. Later predicate
checks narrow the boundary but do not establish a unique original root cause.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT.parent / 'SporeSpore_Evidence'
HEAD = 'b6ee9bbf8a3de7a833c75357461030e32923bb37'
RUN = EVIDENCE / 'development-recovery-smoke-24a712a1d75b4e4c8e70356417d251be'
OUTER = EVIDENCE / 'r10ac-frozen-diagnostic-supervisor-10017c6c2b03485bbf6cb307fe7e9a29'
DIAG = EVIDENCE / 'r10ac-binding-diagnosis-2943599fb0a24bd8a0b4c338d833b6bb'
TOKEN = EVIDENCE / 'r10ac_contact_frame_diagnostic_61248_consumption_v1.json'
KEY = ROOT / 'sdk/recovery/r10ac_v56_walking_entry_contract_v28.json'
CONTRACT = ROOT / 'sdk/development/r10ac_safety_stage_contract_v3.json'
RECORD = ROOT / 'sdk/recovery/r10ac_startup_invalid_closure_v1.json'
CLAIMS = dict(original_attempt_classification='consumed_infrastructure_invalid_before_world',
    original_attempt_reclassified=False, population_consumed=True, rerun_authorized=False,
    contact_frame_measurement_obtained=False, recovery_result_obtained=False,
    unique_original_root_cause_established=False, physical_acceptance_authority=False,
    release_authority=False, sdk1_score='14/20', full_program_score='14/25')


def require(value, code):
    if not value:
        raise ValueError('R10AC_STARTUP_CLOSURE_' + code)


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
    require(len(rows) == len({r['path'] for r in rows}) == 1770, 'FROZEN_INPUT_POPULATION')
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
        and supervisor['failure_code'] == 'QSDK_R10F_L15_LAUNCH_RECEIPT_OBJECT', 'SUPERVISOR')
    require(report['ok'] is False and report['failure_code'] == 'QSDK_R10F_CAMPAIGN_BINDING_INVALID', 'WORKER')
    counters = ['world_build_count', 'solver_step_count', 'model_construction_attempt_count',
        'model_construction_count', 'external_kick_application_count', 'held_out_cell_access_count']
    require(all(type(report[k]) is int and report[k] == 0 for k in counters), 'ZERO_WORLD_COUNTERS')
    require(all(report[k] is False for k in ['physics_state_modified', 'physical_question_opened',
        'recovery_success_observed', 'physical_acceptance_authority', 'release_authority']), 'WORKER_CLAIMS')
    require(termination['exit_code'] == 1 and termination['timed_out'] is False
        and termination['termination_ready_receipt'] is None
        and termination['r10f_l15_launch_relationship'] is None, 'TERMINATION')
    require(declaration['seed'] == token['seed'] == 61248
        and token['attempt_id'] == declaration['attempt_id'] == launch['attempt_id']
        and token['attempt_limit'] == 1 and token['source_commit'] == HEAD, 'RESERVATION')
    require(declaration['safety_stages'] == supervisor['safety_stages'], 'STAGE_RECEIPTS')
    stages = declaration['safety_stages']; expected = contract['stages']
    require(len(stages) == len(expected) == 54 and contract['total_tests'] == 196, 'STAGE_POPULATION')
    for stage, spec in zip(stages, expected, strict=True):
        require(stage['id'] == spec['id'] and stage['passed'] is True and stage['timed_out'] is False
            and type(stage['exit_code']) is int and stage['exit_code'] == 0
            and stage['test_count'] == stage['expected_test_count'] == spec['tests'], 'STAGE_FAILED')
    require(sum(s['test_count'] for s in stages) == 196, 'TEST_POPULATION')
    return dict(complete_safety_gate_passed=True, safety_stages=54, safety_tests=196,
        diagnostic_seed=61248, exposed_prefix_phase=248, physical_worlds=0,
        physical_solver_steps=0, physical_kicks=0,
        original_worker_failure=report['failure_code'], original_supervisor_failure=supervisor['failure_code'],
        ready_receipt_obtained=False, native_world_claim_obtained=False)


def observed():
    child = RUN / 'children/kick_passive_recovery_resume'
    declaration = read(RUN / 'declaration.json'); launch = read(RUN / 'r10ac_development_launch.json')
    result = validate_observation(declaration, read(RUN / 'supervisor_result.json'),
        read(child / 'worker_report.json'), read(child / 'termination_receipt.json'),
        read(TOKEN), launch, read(CONTRACT))
    require(not (child / 'r10ac_native_world_claim_v1.json').exists(), 'UNEXPECTED_LATER_CLAIM')
    require(read(OUTER / 'execution.json')['exit_code'] == 1, 'OUTER_EXIT')
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
    diagnostic = read(DIAG / 'native-full-checks.json')
    require(all(v is True for v in diagnostic['checks'].values()), 'PREDICATE_DIAGNOSIS')
    require(diagnostic['production_initializer_called'] is False and diagnostic['native_claim_helper_called'] is False
        and diagnostic['world_build_count'] == diagnostic['solver_step_count'] == 0, 'DIAGNOSIS_SCOPE')
    helper = json.loads(diagnostic['readonly_helper']['output'][0])
    require(diagnostic['readonly_helper']['exit_code'] == 0, 'HELPER_EXIT')
    require(all(v['ok'] is True for k, v in helper['checks'].items() if k != 'current_freeze'), 'HELPER_CHECKS')
    require(helper['checks']['current_freeze'] == dict(ok=False, error='R10V_LAUNCH_SOURCE_NOT_CLEAN', type='ValueError'), 'OWNED_DIRTY_DIAGNOSIS')
    lock = read(DIAG / 'full-checks.operation-lock.json')
    require(lock['acquired'] is True and lock['released'] is True and lock['role'] == 'conformance', 'DIAGNOSIS_LOCK')
    require(read(DIAG / 'full-checks.execution.json')['exit_code'] == 0, 'DIAGNOSIS_EXIT')
    require((DIAG / 'full-checks.stderr.log').read_bytes() == b'', 'DIAGNOSIS_STDERR')
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
    paths += [DIAG / name for name in ['launcher-reconstruction.json', 'original-launch-verification.json',
        'captured-launch-boundary.json', 'native-full-checks.json', 'full-checks.execution.json',
        'full-checks.stdout.log', 'full-checks.stderr.log', 'full-checks.operation-lock.json']]
    paths += [TOKEN, KEY, CONTRACT, ROOT / 'tests/test_r10ac_binding_diagnosis.gd',
        ROOT / 'tests/r10ac_binding_readonly_helper.py']
    record = dict(schema_version='sporespore_r10ac_startup_invalid_closure_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
            authority_mode='consumed_pre_world_infrastructure_invalid_closure', question_class='development'),
        source_commit=HEAD, original_run=RUN.as_posix(), auditor=bind(__file__),
        bindings=[bind(p) for p in paths], observed=observation, claim_boundary=CLAIMS,
        diagnosis_limits='Post-exposure reconstruction passed native admission with the world-authority call replaced by a seed-only stub. Read-only helper predicates passed except the expected rejection of the owned dirty diagnostic tree. Original helper output was not retained; no unique original cause is established. Earlier exploratory outputs are retained but are not closure validation.',
        next_action='Distinct successor with structured retained startup refusals and a zero-world production-startup preflight before any new diagnostic reservation. No R10AC retry or key renewal.')
    audit(record); write_new(RECORD, record)
    return audit(record)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('--create', action='store_true')
    args = parser.parse_args()
    print(json.dumps(create() if args.create else audit(read(RECORD))))
