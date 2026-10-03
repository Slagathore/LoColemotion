"""Close R10AE's consumed post-world Python replay refusal without regrading it."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

import r10ae_development as identity
import r10ac_contact_frame_replay as original_reader

ROOT, EVIDENCE = identity.ROOT, identity.EVIDENCE
HEAD = '2d262c633e1771a45dc45761f0d460a09a4b7682'
RUN = EVIDENCE / 'development-recovery-smoke-901e10b65dad4778bac690e0b130fa18'
OUTER = EVIDENCE / 'r10ae-full-supervisor-e086ba82bd5743918b06075ef6d64767'
TOKEN = EVIDENCE / 'r10ae_contact_frame_diagnostic_63248_consumption_v1.json'
KEY = ROOT / 'sdk/recovery/r10ae_v56_walking_entry_contract_v11.json'
CONTRACT = ROOT / 'sdk/development/r10ae_safety_stage_contract_v2.json'
LOCALIZATION = EVIDENCE / 'r10ae-replay-failure-diagnosis-f1a2a54ca44141dd96185cc4ab33def4/localization.json'
RECORD = ROOT / 'sdk/recovery/r10ae_replay_invalid_closure_v1.json'
CLAIMS = dict(original_attempt_classification='consumed_infrastructure_invalid_after_world',
    original_attempt_reclassified=False, population_consumed=True, rerun_authorized=False,
    independently_qualified_contact_result=False, recovery_success_obtained=False,
    physical_acceptance_authority=False, release_authority=False,
    sdk1_score='14/20', full_program_score='14/25')


def require(value, code):
    if not value:
        raise ValueError('R10AE_REPLAY_CLOSURE_' + code)


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def bind(path):
    path = Path(path)
    with path.open('rb') as stream:
        digest = hashlib.file_digest(stream, 'sha256').hexdigest()
    return dict(path=path.as_posix(), byte_length=path.stat().st_size, raw_sha256='sha256:' + digest)


def write_new(path, value):
    with Path(path).open('x', encoding='utf-8', newline='\n') as stream:
        json.dump(value, stream, indent=2, allow_nan=False); stream.write('\n')


def frozen_sources():
    rows = read(KEY)['bound_source_files']
    require(len(rows) == len({r['path'] for r in rows}) == 1907, 'FROZEN_INPUT_POPULATION')
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


def observed():
    child = RUN / 'children/kick_passive_recovery_resume'
    declaration, supervisor = read(RUN / 'declaration.json'), read(RUN / 'supervisor_result.json')
    identity.validate_declaration(declaration)
    require(declaration['source_snapshot'] == supervisor['source_snapshot'] ==
        dict(head=HEAD, dirty=False, status=[], changed_file_bindings=[]), 'SOURCE')
    require(supervisor['ok'] is False and supervisor['physical_attempt_started'] is True and
        supervisor['failure_code'] == 'SMOKE_ENTRY_REPLAY_FAILED:kick_passive_recovery_resume' and
        supervisor['independent_audit'] is None, 'ORIGINAL_REFUSAL')
    require(read(OUTER / 'terminal.json')['returncode'] == 1, 'OUTER_EXIT')
    token, launch, contract = read(TOKEN), read(RUN / 'r10ae_development_launch.json'), read(CONTRACT)
    require(token['seed'] == declaration['seed'] == 63248 and token['source_commit'] == HEAD and
        token['attempt_id'] == declaration['attempt_id'] == launch['attempt_id'] and token['attempt_limit'] == 1,
        'CONSUMED_POPULATION')
    require(launch['freeze'] == dict(root=ROOT.as_posix(), remote='https://github.com/Slagathore/sporespore.git',
        branch='main', head=HEAD, origin_main=HEAD, live_origin_main=HEAD, clean=True), 'FREEZE')
    stages = declaration['safety_stages']
    require(stages == supervisor['safety_stages'] and len(stages) == len(contract['stages']) == 61 and
        sum(s['test_count'] for s in stages) == contract['total_tests'] == 230, 'STAGE_POPULATION')
    for stage, spec in zip(stages, contract['stages'], strict=True):
        require(stage['id'] == spec['id'] and stage['passed'] is True and stage['timed_out'] is False and
            stage['exit_code'] == 0 and stage['test_count'] == stage['expected_test_count'] == spec['tests'], 'STAGE')
        for stream in ['stdout', 'stderr']:
            path = RUN / stage[stream]
            require(bind(path)['raw_sha256'] == 'sha256:' + stage[stream + '_sha256'], 'STAGE_LOG')
    report_binding = bind(child / 'worker_report.json')
    require(report_binding['raw_sha256'] == 'sha256:02744296f1095c98bb688387f34292a34484188a569c5236c57e4eebfca12e43', 'REPORT_BYTES')
    retention = read(child / 'payload_release_receipt.json')
    require(retention['verified_artifacts']['worker_report'] == report_binding and
        retention['launch_relationship_valid'] is True and retention['original_evidence_rewritten'] is False, 'RETENTION')
    for value in [retention['retained_envelope'], *retention['verified_artifacts'].values()]:
        require(bind(value['path']) == value, 'RETAINED_ARTIFACT')
    require(read(child / 'engine_health.json')['passed'] is True, 'ENGINE_HEALTH')
    execution = read(child / 'passive_entry_replay/execution.json')
    require(execution['returncode'] == 0 and execution['timed_out'] is False and
        execution['input_raw_sha256'] == report_binding['raw_sha256'], 'NATIVE_REPLAY')
    marker = 'DEVELOPMENT_RECOVERY_CANDIDATE_REPLAY '
    rows = [json.loads(line[len(marker):]) for line in (child / 'passive_entry_replay/stdout.txt').read_text().splitlines()
        if line.startswith(marker)]
    require(len(rows) == 1 and rows[0]['ok'] is True and rows[0]['controller_and_diagnostic_replay_passed'] is True and
        rows[0]['transition_count'] == 1158, 'NATIVE_RECEIPT')
    refusal = read(child / 'passive_entry_replay_result.json')
    require(refusal == dict(ok=False, failure_code='exact float32 vector', physical_acceptance_authority=False,
        release_authority=False), 'PYTHON_REFUSAL')
    report = read(child / 'worker_report.json'); identity.validate_report_header(report, declaration)
    require(report['world_build_count'] == 1 and report['solver_step_count'] == 1158 and
        report['external_kick_application_count'] == 1 and report['held_out_cell_access_count'] == 0 and
        report['complete_route_proven'] is False and report['coverage_complete'] is False and
        report['stop_reason'] == 'production_controller_terminal_before_diagnostic_horizon', 'REPORTED_PHYSICAL_SCOPE')
    center = report['r10ac_contact_frames']['records'][0]['packet']['contact_sites_by_body']['front_left_distal']['local_center_m']
    require(center == dict(x=0.0, y=-0.08365750000000001, z=0.0), 'FIRST_REJECTED_VALUE')
    try:
        original_reader.vec(center)
    except ValueError as error:
        require(str(error) == refusal['failure_code'], 'REPRODUCED_FAILURE')
    else:
        raise ValueError('ORIGINAL_READER_NO_LONGER_REFUSES')
    localization = read(LOCALIZATION)
    require(localization['failed_step'] == 1 and localization['report_sha256'] == report_binding['raw_sha256'] and
        localization['values'] == [center[k] for k in ['x', 'y', 'z']], 'LOCALIZATION')
    return dict(complete_safety_gate_passed=True, safety_stages=61, safety_tests=230,
        diagnostic_seed=63248, exposed_prefix_phase=248, reported_worlds=1, reported_solver_steps=1158,
        reported_kicks=1, native_replay_passed=True, python_replay_passed=False,
        original_failure=supervisor['failure_code'], python_failure=refusal['failure_code'],
        first_refused_step=1, configured_cap_center_y=center['y'],
        godot_vector3_cap_center_y=original_reader.f32(center['y']),
        failure_cause='Python requires a configured scalar vector to already contain float32 values; Godot _source_vec converts the finite authored coordinates through Vector3.',
        synthetic_coverage_gap='Prior contact fixtures build local_center_m through Vector3 before serialization, so they cannot expose a non-float32 authored configuration coordinate.')


def audit(record):
    require(record['source_commit'] == HEAD and record['claim_boundary'] == CLAIMS, 'CLAIMS')
    for value in record['bindings'] + [record['auditor']]:
        require(bind(value['path']) == value, 'BINDING')
    frozen_sources()
    require(record['observed'] == observed(), 'OBSERVATION')
    return dict(ok=True, **record['observed'], **CLAIMS)


def create():
    require(not RECORD.exists(), 'ALREADY_CLOSED')
    frozen_sources(); observation = observed()
    paths = [p for folder in [RUN, OUTER] for p in sorted(folder.rglob('*')) if p.is_file()]
    paths += [TOKEN, KEY, CONTRACT, LOCALIZATION, Path(original_reader.__file__),
        ROOT / 'sdk/adapters/godot/gdscript/r10ac_contact_frame_capture_v1.gd',
        ROOT / 'tests/test_r10ac_contact_frame_capture.gd']
    record = dict(schema_version='sporespore_r10ae_replay_invalid_closure_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
            authority_mode='consumed_post_world_infrastructure_invalid_closure', question_class='development'),
        source_commit=HEAD, original_run=RUN.as_posix(), auditor=bind(__file__),
        bindings=[bind(p) for p in paths], observed=observation, claim_boundary=CLAIMS,
        diagnosis_limits='Immediate reader type-contract failure established. Native-only contact counts are not independently qualified. A later read-only successor analysis cannot reclassify this attempt or authorize another use of seed 63248.',
        next_action='Separate successor reader with Godot-matching configured-vector conversion, native parity and negative controls, then a separately labeled post-exposure analysis. Any new physical attempt requires a distinct prospective population and full applicable qualification.')
    audit(record); write_new(RECORD, record)
    return dict(ok=True, **observation, **CLAIMS)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('--create', action='store_true')
    args = parser.parse_args()
    print(json.dumps(create() if args.create else audit(read(RECORD))))
