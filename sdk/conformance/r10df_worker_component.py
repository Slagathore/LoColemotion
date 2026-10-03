"""V29 worker orchestration, actual uninserted motors and source compatibility."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import traceback
import zipfile
import r10de_reference_session as previous
import r10ap_gate_support as gate

C = previous.C
CONTRACT = C.ROOT / 'sdk/recovery/r10df_worker_component_contract_v1.json'
RECORD = C.ROOT / 'sdk/recovery/r10df_worker_component_v1.json'
WRAPPER = C.ROOT / 'sdk/run_r10df_worker_component.ps1'
SCRIPTS = ['tests/test_r10df_worker.gd', 'tests/test_r10de_reference_session.gd', 'tests/test_development_r10ap_task_source.gd']
CHANGED = {'sdk/adapters/godot/gdscript/' + name for name in (
    'qsdk_r10f_l15_canonical_ownership_v1.gd', 'development_recovery_stance_profile_v1.gd', 'recovery_task_source_selector_v1.gd')}


def dependencies():
    found = {Path(__file__), CONTRACT, WRAPPER, previous.prior.BINDING, previous.prior.OLD,
             previous.prior.EXTENSION, previous.prior.component.INPUTS,
             previous.RECORD, C.ROOT / 'sdk/development/r10ap_host_runtime_contract_v1.json',
             C.ROOT / 'sdk/conformance/r10ap_gate_support.py', C.ROOT / 'tests/r10ap_preflight_fixture.py'}
    pending = [C.ROOT / name for name in SCRIPTS]
    while pending:
        path = pending.pop()
        if path in found:
            continue
        found.add(path)
        pending.extend(C.ROOT / name for name in re.findall(r'"res://([^"\n]+\.gd)"', path.read_text(encoding='utf-8')))
    return sorted(found)


def historical_session():
    record = C.read(previous.RECORD)
    for binding in record['evidence']:
        previous.prior.verify(binding)
    folder = Path(record['execution_root'])
    with zipfile.ZipFile(folder / 'source.zip') as archive:
        for binding in record['dependencies']:
            name = Path(binding['path']).relative_to(C.ROOT).as_posix()
            raw = archive.read(name)
            assert len(raw) == binding['byte_length'] and 'sha256:' + hashlib.sha256(raw).hexdigest() == binding['raw_sha256']
            if name not in CHANGED:
                previous.prior.verify(binding)
    # A changed key supersedes live reuse, not the historical qualified snapshot.
    return folder / 'godot-result.json.packets.jsonl'


def run(folder):
    folder = Path(folder).resolve()
    assert folder.is_relative_to(C.EVIDENCE)
    lock = C.read(folder / 'operation-lock.json')
    assert lock['acquired'] and lock['owner_process_id'] == os.getppid()
    packets = historical_session()
    binding = C.read(previous.prior.BINDING)
    old = C.read(previous.prior.OLD)
    inputs = C.read(previous.prior.component.INPUTS)['fixture']
    engine = C.read(C.ROOT / 'sdk/development/r10ap_host_runtime_contract_v1.json')['images']['godot_engine']
    for item in (binding['runtime'], binding['compiled_fixtures'], old['runtime'], old['compiled_fixtures'], inputs, engine):
        previous.prior.verify(item)
    before = [C.bind(p) for p in dependencies()]
    C.write_new(folder / 'bindings-before.json', before)
    with zipfile.ZipFile(folder / 'source.zip', 'x', zipfile.ZIP_DEFLATED) as archive:
        for path in dependencies(): archive.write(path, path.relative_to(C.ROOT).as_posix())
    C.write_new(folder / 'declaration.json', dict(contract=C.bind(CONTRACT), runtime=binding['runtime'],
        old_runtime=old['runtime'], engine=engine, packets=C.bind(packets), original_inputs=inputs))
    state = dict(ok=False)
    results = []
    arguments = [[str(packets)], [binding['compiled_fixtures']['path'], inputs['path']], [old['compiled_fixtures']['path']]]
    try:
        for index, (script, args) in enumerate(zip(SCRIPTS, arguments, strict=True)):
            result_path = folder / f'stage-{index}-result.json'
            command = [engine['path'], '--headless', '--path', str(C.ROOT), '--script', 'res://' + script, '--', *args, str(result_path)]
            env = {k: v for k, v in os.environ.items() if not k.startswith(('SPORESPORE_GODOT_RECOVERY_', 'SPORE_R10AG_', 'SPORE_R10AP_'))}
            if index == 0:
                env = gate.godot_environment(folder, 'worker-host-context')
            with (folder / f'stage-{index}-stdout.txt').open('xb') as out, (folder / f'stage-{index}-stderr.txt').open('xb') as err:
                with subprocess.Popen(command, cwd=C.ROOT, env=env, stdout=out, stderr=err, creationflags=subprocess.CREATE_NO_WINDOW) as process:
                    try: code = process.wait(timeout=180); timed_out = False
                    except subprocess.TimeoutExpired: process.kill(); process.wait(); code, timed_out = process.returncode, True
            C.write_new(folder / f'stage-{index}-execution.json', dict(command=command, return_code=code, timed_out=timed_out))
            assert code == 0 and not timed_out and (folder / f'stage-{index}-stderr.txt').read_bytes() == b'', script
            result = C.read(result_path)
            assert result['ok'] and all(result['checks'].values()) and result['world_build_count'] == result['solver_step_count'] == 0
            results.append(dict(script=script, checks_passed=len(result['checks'])))
            print(json.dumps(results[-1]), flush=True)
        C.write_new(folder / 'result.json', dict(ok=True, stages=results, world_build_count=0, solver_step_count=0,
            worker_hooks_qualified=True, full_physical_source_collection_tested=False,
            complete_report_reader_qualified=False, complete_safety_gate_qualified=False,
            physical_acceptance_authority=False, release_authority=False))
        state['ok'] = True
    except BaseException:
        state['error'] = traceback.format_exc()
        raise
    finally:
        after = [C.bind(p) for p in dependencies()]
        C.write_new(folder / 'bindings-after.json', after)
        state['source_unchanged'] = before == after
        C.write_new(folder / 'execution.json', state)
    assert state['source_unchanged']


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--run', required=True)
    run(parser.parse_args().run)
