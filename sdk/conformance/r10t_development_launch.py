"""Clean-source, complete-gate and first-attempt guard for R10T development."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import subprocess

import r10t_development as development

ROOT = development.ROOT
EVIDENCE = development.EVIDENCE
CONTRACT = ROOT/'sdk/development/r10t_safety_stage_contract_v5.json'
REMOTE = 'https://github.com/Slagathore/sporespore.git'
LAUNCH_FILE = 'r10t_development_launch.json'
FIRST_FILE = 'r10t_first_single_consumption_v1.json'


def require(value, code):
    if not value:
        raise ValueError('R10T_LAUNCH_'+code)


def read(path):
    return development.read(path)


def binding(path):
    path = Path(path)
    return dict(path=path.as_posix(), raw_sha256=development.sha(path))


def write_new(path, value):
    with Path(path).open('x',encoding='utf-8',newline='\n') as stream:
        json.dump(value,stream,indent=2); stream.write('\n'); stream.flush()
        import os
        os.fsync(stream.fileno())


def current_freeze(source_commit):
    def git(*args):
        return subprocess.check_output(['git',*args],cwd=ROOT,text=True,timeout=45,
            creationflags=subprocess.CREATE_NO_WINDOW).strip()
    require(Path(git('rev-parse','--show-toplevel')).resolve() == ROOT.resolve(), 'SOURCE_ROOT')
    require(git('remote','get-url','origin') == REMOTE and git('branch','--show-current') == 'main', 'SOURCE_REMOTE_OR_BRANCH')
    require(git('status','--porcelain') == '', 'SOURCE_NOT_CLEAN')
    head, tracking = git('rev-parse','HEAD'), git('rev-parse','origin/main')
    remote = git('ls-remote','origin','refs/heads/main').split()
    require(len(remote) == 2 and remote[1] == 'refs/heads/main' and
        head == tracking == remote[0] == source_commit, 'SOURCE_NOT_PUSHED')
    return dict(root=ROOT.as_posix(),remote=REMOTE,branch='main',head=head,
        origin_main=tracking,live_origin_main=remote[0],clean=True)


def declared(path):
    path = Path(path).resolve()
    require(path.name == 'declaration.json' and path.parent.parent == EVIDENCE.resolve()
        and re.fullmatch(r'development-recovery-smoke-[0-9a-f]{32}',path.parent.name), 'DECLARATION_ROOT')
    value = read(path)
    require(path.parent.name == 'development-recovery-smoke-'+value['attempt_id'], 'ATTEMPT_ROOT')
    development.validate_declaration(value)
    head = value['source_snapshot']['head']
    require(value['source_snapshot'] == dict(head=head,dirty=False,status=[],changed_file_bindings=[]), 'DECLARED_SOURCE_NOT_CLEAN')
    require(value.get('physical_acceptance_authority') is False and value.get('release_authority') is False
        and value.get('official_qualification') is False, 'CLAIMS')
    return value


def safety(path, value, contract_path=None):
    contract = read(CONTRACT if contract_path is None else contract_path)
    expected, observed = contract['stages'], value.get('safety_stages')
    require(type(observed) is list and len(observed) == len(expected), 'COMPLETE_GATE_REQUIRED')
    files = []
    for spec, receipt in zip(expected,observed,strict=True):
        require(type(receipt) is dict and receipt.get('id') == spec['id']
            and receipt.get('passed') is True and receipt.get('timed_out') is False
            and type(receipt.get('exit_code')) is int and receipt['exit_code'] == 0
            and type(receipt.get('test_count')) is int and receipt['test_count'] == spec['tests']
            and type(receipt.get('expected_test_count')) is int and receipt['expected_test_count'] == spec['tests'], 'GATE_STAGE')
        logs = []
        for stream in ['stdout','stderr']:
            name = spec['id']+'.'+stream+'.log'
            require(receipt.get(stream) == name, 'GATE_LOG_PATH')
            log = path.parent/name
            require(log.is_file() and development.sha(log) == 'sha256:'+str(receipt.get(stream+'_sha256')), 'GATE_LOG_BYTES')
            files.append(binding(log)); logs.append(log.read_text(encoding='utf-8'))
        log = '\n'.join(logs)
        require(re.findall(r'^Ran (\d+) tests? in [0-9.]+s\s*$',log,flags=re.M) == [str(spec['tests'])]
            and len(re.findall(r'^OK\s*$',log,flags=re.M)) == 1, 'GATE_TEST_POPULATION')
    return files


def authorize(path):
    """Called under the production operation lock, after the complete safety gate."""
    path = Path(path).resolve()
    value = declared(path)
    files = safety(path,value)
    freeze = current_freeze(value['source_snapshot']['head'])
    target = path.parent/LAUNCH_FILE
    require(not target.exists(), 'ATTEMPT_ALREADY_AUTHORIZED')
    stage = value['r10t_development']['stage']
    first = None
    if stage == 'initial_single_diagnostic':
        token = EVIDENCE/FIRST_FILE
        reservation = dict(schema_version='sporespore_r10t_first_single_consumption_v1',
            design_sha256=development.DESIGN_SHA,attempt_id=value['attempt_id'],
            declaration=binding(path),source_commit=freeze['head'],attempt_limit=1)
        try:
            write_new(token,reservation)
        except FileExistsError as error:
            raise ValueError('R10T_LAUNCH_FIRST_SINGLE_ALREADY_CONSUMED') from error
        first = binding(token)
    reservation_binding = first
    if stage != 'initial_single_diagnostic':
        token = EVIDENCE / ('r10t_' + stage + '_' + str(value['seed']) + '_consumption_v1.json')
        reservation = dict(schema_version='sporespore_r10t_stage_consumption_v1',
            design_sha256=development.DESIGN_SHA,stage=stage,seed=value['seed'],
            attempt_id=value['attempt_id'],declaration=binding(path),source_commit=freeze['head'],attempt_limit=1)
        try:
            write_new(token,reservation)
        except FileExistsError as error:
            raise ValueError('R10T_LAUNCH_STAGE_ALREADY_CONSUMED') from error
        reservation_binding = binding(token)
    record = dict(schema_version='sporespore_r10t_development_launch_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',
            authority_mode='bounded_development_launch_guard',question_class='development'),
        attempt_id=value['attempt_id'],stage=stage,declaration=binding(path),freeze=freeze,
        safety_contract=binding(CONTRACT),safety_logs=files,first_single_reservation=first,stage_reservation=reservation_binding,
        created_utc=datetime.now(timezone.utc).isoformat(),official_qualification=False,
        physical_acceptance_authority=False,release_authority=False)
    write_new(target,record)
    return dict(ok=True,launch=binding(target),stage=stage,first_single_reserved=first is not None)


def verify(path):
    """Read the original launch record; never reserve or launch during replay."""
    path = Path(path).resolve()
    value = declared(path)
    record = read(path.parent/LAUNCH_FILE)
    require(record.get('schema_version') == 'sporespore_r10t_development_launch_v1'
        and record.get('attempt_id') == value['attempt_id'] and record.get('declaration') == binding(path)
        and record.get('stage') == value['r10t_development']['stage'], 'RECORD_BINDING')
    require(record.get('safety_contract') == binding(CONTRACT), 'RECORD_GATE_CONTRACT')
    contract_path = CONTRACT
    require(record.get('safety_logs') == safety(path,value,contract_path), 'RECORD_GATE')
    head = value['source_snapshot']['head']
    require(record.get('freeze') == dict(root=ROOT.as_posix(),remote=REMOTE,branch='main',head=head,
        origin_main=head,live_origin_main=head,clean=True), 'RECORDED_FREEZE')
    require(all(record.get(key) is False for key in ['official_qualification','physical_acceptance_authority','release_authority']), 'RECORD_CLAIMS')
    if record['stage'] == 'initial_single_diagnostic':
        token = EVIDENCE/FIRST_FILE
        require(record.get('first_single_reservation') == record.get('stage_reservation') == binding(token), 'FIRST_SINGLE_RESERVATION')
        reservation = read(token)
        require(reservation == dict(schema_version='sporespore_r10t_first_single_consumption_v1',
            design_sha256=development.DESIGN_SHA,attempt_id=value['attempt_id'],declaration=binding(path),
            source_commit=head,attempt_limit=1), 'FIRST_SINGLE_IDENTITY')
    else:
        require(record.get('first_single_reservation') is None, 'CROSSED_FIRST_SINGLE_RESERVATION')
        token = EVIDENCE / ('r10t_' + record['stage'] + '_' + str(value['seed']) + '_consumption_v1.json')
        require(record.get('stage_reservation') == binding(token), 'STAGE_RESERVATION')
        require(read(token) == dict(schema_version='sporespore_r10t_stage_consumption_v1',
            design_sha256=development.DESIGN_SHA,stage=record['stage'],seed=value['seed'],
            attempt_id=value['attempt_id'],declaration=binding(path),source_commit=head,attempt_limit=1), 'STAGE_RESERVATION_IDENTITY')

    return dict(ok=True,stage=record['stage'],launch=binding(path.parent/LAUNCH_FILE))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--authorize',type=Path)
    mode.add_argument('--verify',type=Path)
    mode.add_argument('--check-freeze')
    args = parser.parse_args()
    result = authorize(args.authorize) if args.authorize else verify(args.verify) if args.verify else current_freeze(args.check_freeze)
    print(json.dumps(result,separators=(',',':')))
