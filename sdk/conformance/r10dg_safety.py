"""Complete applicable zero-world safety gate for the finite single-kick diagnostic."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import traceback
import zipfile
import r10dg_identity as I
import r10dg_diagnostic as D
import r10dg_launch as L

CONTRACT = I.ROOT / 'sdk/development/r10dg_safety_contract_v1.json'

def dependencies():
    found = set(D.dependencies())
    # Bind the complete shared scripting/test surfaces used by the subprocesses,
    # including transitively imported helpers and the native process observer.
    names = subprocess.check_output(['git', 'ls-files', '-c', '-o', '--exclude-standard', '--', 'sdk', 'tests'], cwd=I.ROOT, text=True).splitlines()
    for name in names:
        path = I.ROOT / name
        if (path.suffix in ['.ps1', '.cs', '.gdextension'] or name.startswith('tests/') and path.suffix in ['.py', '.gd']
            or name.startswith('sdk/conformance/') and path.suffix in ['.py', '.json']
            or name.startswith(('sdk/development/', 'sdk/process/', 'sdk/core/contracts/')) and path.suffix == '.json'):
            found.add(path)
    found.add(CONTRACT)
    found.add(I.ROOT / 'project.godot')
    return sorted(p for p in found if not any(x in p.parts for x in ['target', '__pycache__']))

def verify(path):
    value = I.read(path)
    I.require(value.get('ok') is True and value.get('source_unchanged') is True, 'SAFETY_RESULT')
    I.require(value.get('contract') == I.binding(CONTRACT), 'SAFETY_CONTRACT')
    I.require(value.get('dependencies') == [I.binding(p) for p in dependencies()], 'SAFETY_DEPENDENCY_KEY')
    I.require(value.get('physical_acceptance_authority') is False and value.get('release_authority') is False, 'SAFETY_CLAIMS')
    contract = I.read(CONTRACT)
    I.require([s['id'] for s in value['stages']] == contract['required_stage_ids'], 'SAFETY_STAGE_POPULATION')
    I.require(all(s['ok'] is True for s in value['stages']), 'SAFETY_STAGE_FAILURE')
    for binding in value['evidence']:
        I.require(I.binding(binding['path']) == binding, 'SAFETY_EVIDENCE')
    folder = Path(path).parent
    I.require(I.read(folder / 'bindings-before.json') == I.read(folder / 'bindings-after.json') == value['dependencies'], 'SAFETY_SNAPSHOT')
    with zipfile.ZipFile(folder / 'source.zip') as archive:
        for binding in value['dependencies']:
            raw = archive.read(Path(binding['path']).relative_to(I.ROOT).as_posix())
            I.require(len(raw) == binding['byte_length'] and 'sha256:' + hashlib.sha256(raw).hexdigest() == binding['raw_sha256'], 'SAFETY_ARCHIVE')
    return value

def python_stage(folder, stage):
    command = [I.read(I.HOST)['images']['python_helper']['path'], '-B', '-X', 'utf8', '-m', 'unittest',
               'discover', '-s', 'tests', '-p', stage['pattern'], '-v']
    with (folder / (stage['id'] + '.stdout.txt')).open('xb') as out, (folder / (stage['id'] + '.stderr.txt')).open('xb') as err:
        with subprocess.Popen(command, cwd=I.ROOT, env=L.clean_environment(), stdout=out, stderr=err, creationflags=subprocess.CREATE_NO_WINDOW) as proc:
            try:
                code = proc.wait(timeout=stage['timeout_seconds'])
                timeout = False
            except subprocess.TimeoutExpired:
                proc.kill(); proc.wait()
                code, timeout = proc.returncode, True
    text = (folder / (stage['id'] + '.stderr.txt')).read_text(encoding='utf-8')
    counts = re.findall(r'Ran (\d+) tests? in', text)
    I.write_new(folder / (stage['id'] + '.execution.json'), dict(command=command, exit_code=code, timed_out=timeout))
    I.require(code == 0 and not timeout and counts == [str(stage['tests'])] and '\nOK' in text, 'SAFETY_TEST:' + stage['id'])
    return dict(id=stage['id'], ok=True, tests=stage['tests'])

def run(folder):
    folder = Path(folder).resolve()
    I.require(folder.is_relative_to(I.EVIDENCE), 'SAFETY_STORAGE')
    lock = I.read(folder / 'operation-lock.json')
    I.require(lock['acquired'] is True and lock['owner_process_id'] == os.getppid(), 'SAFETY_LOCK')
    I.verify_images()
    before = [I.binding(p) for p in dependencies()]
    I.write_new(folder / 'bindings-before.json', before)
    with zipfile.ZipFile(folder / 'source.zip', 'x', zipfile.ZIP_DEFLATED) as archive:
        for path in dependencies(): archive.write(path, path.relative_to(I.ROOT).as_posix())
    result = dict(schema_version='sporespore_r10dg_safety_qualification_v1', ledger_scope=I.read(I.DESIGN)['ledger_scope'],
        ok=False, physical_attempted=False, contract=I.binding(CONTRACT), dependencies=before, stages=[],
        physical_acceptance_authority=False, release_authority=False)
    try:
        contract = I.read(CONTRACT)
        for stage in contract['python_stages']:
            result['stages'].append(python_stage(folder, stage))
            print(json.dumps(result['stages'][-1]), flush=True)
        worker = D.worker
        binding = I.read(worker.previous.prior.BINDING)
        inputs = I.read(worker.previous.prior.component.INPUTS)['fixture']
        prior_record = I.read(worker.previous.RECORD)
        packets = Path(prior_record['execution_root']) / 'godot-result.json.packets.jsonl'
        # Old qualification stays historical. Verify exact archived sources and
        # evidence; freshly execute all affected component checks under this key.
        for record_path in [worker.RECORD, worker.previous.RECORD]:
            record = I.read(record_path)
            for item in record['evidence']:
                I.require(I.binding(item['path']) == item, 'HISTORICAL_EVIDENCE')
            with zipfile.ZipFile(Path(record['execution_root']) / 'source.zip') as archive:
                for item in record['dependencies']:
                    raw = archive.read(Path(item['path']).relative_to(I.ROOT).as_posix())
                    I.require(len(raw) == item['byte_length'] and 'sha256:' + hashlib.sha256(raw).hexdigest() == item['raw_sha256'], 'HISTORICAL_SOURCE')
        for name, script, args in [
            ('finite_worker', 'tests/test_r10df_worker.gd', [packets]),
            ('finite_session', 'tests/test_r10de_reference_session.gd', [binding['compiled_fixtures']['path'], inputs['path']]),
            ('native_world_guard', 'tests/test_r10dg_native_guard.gd', []),
            ('early_worker_stop', 'tests/test_r10dg_early_worker_stop.gd', [packets])]:
            receipt = D.stage(folder, name, script, args, timeout=300)
            result['stages'].append(dict(id=name, ok=True, receipt=I.binding(receipt)))
        segment_fixture = I.EVIDENCE / 'r10dg-integration-b8431946a66b45a68fdd427c6442a3af/source-worker-result.json'
        original = I.read(segment_fixture.parent / 'execution.json')['fixture']
        I.require(I.binding(segment_fixture) == original, 'SEGMENT_FIXTURE_BINDING')
        receipt = D.stage(folder, 'segment_reader_controls', 'tests/test_r10dg_segment_reader.gd', [segment_fixture], timeout=1200)
        result['stages'].append(dict(id='segment_reader_controls', ok=True, receipt=I.binding(receipt)))
        integration = folder / 'complete-report'
        integration.mkdir()
        I.write_new(integration / 'operation-lock.json', lock)
        D.run(integration)
        result['stages'].append(dict(id='complete_report_and_refusals', ok=True, receipt=I.binding(integration / 'execution.json')))
        head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=I.ROOT, text=True).strip()
        preworld = folder / 'pre-world'
        preworld.mkdir()
        declaration = L.declaration(head, fixture=True)
        path = L.prepare_context(preworld, declaration)
        result['stages'].append(dict(id='actual_pre_world_handoff', ok=True, receipt=I.binding(preworld / 'pre-world-result.json')))
        env = L.clean_environment()
        env.update(I.read(preworld / 'child-environment.json')['environment'])
        # Real initializer must reject a crossed prepared-context digest without
        # reaching construction. Keep both attempts and their exact environments.
        keys = [k for k in env if 'L15_CONTEXT' in k]
        I.require(bool(keys), 'PREPARED_ENVIRONMENT_FIELDS')
        key = next(k for k in keys if 'SHA256' in k)
        env[key] = 'sha256:' + '0' * 64
        I.write_new(preworld / 'crossed-environment.json', {k:v for k,v in env.items() if k.startswith('SPORESPORE_GODOT_RECOVERY_')})
        output = preworld / 'crossed-result.json'
        L.run_process(preworld, 'crossed-context', [declaration['runtime']['images']['godot_engine']['path'], '--headless', '--path', I.ROOT,
            '--script', 'res://sdk/adapters/godot/gdscript/r10dg_pre_world_consumer_v1.gd', '--', path, output], env)
        crossed = I.read(output)
        I.require(crossed['construction_boundary_reached'] is False and crossed['world_build_count'] == crossed['solver_step_count'] == 0, 'CROSSED_CONTEXT_REACHED_WORLD')
        result['stages'].append(dict(id='crossed_pre_world_context', ok=True, receipt=I.binding(output)))
        I.require([s['id'] for s in result['stages']] == contract['required_stage_ids'], 'GATE_POPULATION')
        result['ok'] = True
    except BaseException:
        result['error'] = traceback.format_exc()
        raise
    finally:
        after = [I.binding(p) for p in dependencies()]
        I.write_new(folder / 'bindings-after.json', after)
        result['source_unchanged'] = before == after
        result['evidence'] = [I.binding(p) for p in sorted(folder.rglob('*')) if p.is_file()]
        I.write_new(folder / 'qualification.json', result)
    verify(folder / 'qualification.json')

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--run', type=Path)
    group.add_argument('--verify', type=Path)
    args = parser.parse_args()
    if args.run: run(args.run)
    else:
        value = verify(args.verify)
        print(json.dumps(dict(ok=True, stages=len(value['stages']), world_build_count=0, solver_step_count=0)))
