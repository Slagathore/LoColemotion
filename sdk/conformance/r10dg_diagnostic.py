"""Prospective finite-reference diagnostic integration and retained zero-world checks."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import traceback
import zipfile

import r10df_worker_component as worker
import r10ap_gate_support as gate
import r10dg_identity as identity
import r10dg_launch as launch

C = worker.C


def dependencies():
    found = set(worker.dependencies())
    pending = list(C.ROOT.glob('tests/test_r10dg*.gd'))
    pending += list((C.ROOT / 'sdk/adapters/godot/gdscript').glob('r10dg*.gd'))
    pending += [Path(__file__), C.ROOT / 'sdk/run_r10dg_diagnostic.ps1']
    pending += list((C.ROOT / 'sdk/conformance').glob('r10dg*.py'))
    pending += list((C.ROOT / 'sdk').glob('*r10dg*.ps1'))
    pending += list((C.ROOT / 'sdk/development').glob('r10dg*.json'))
    # Post-exit closures are consumers, not mutable launch dependencies.
    pending += [identity.DESIGN]
    pending += [identity.PROFILE, C.ROOT / 'sdk/development/recovery_schedules/r10dg-finite-reference-v1.json']
    while pending:
        path = pending.pop()
        if path in found:
            continue
        found.add(path)
        if path.suffix == '.gd':
            pending += [C.ROOT / name for name in re.findall(r'"res://([^"\n]+\.gd)"', path.read_text(encoding='utf-8'))]
    return sorted(found)


def stage(folder, name, script, args, timeout=180, extra_environment=None):
    result_path = folder / (name + '-result.json')
    engine = C.read(C.ROOT / 'sdk/development/r10ap_host_runtime_contract_v1.json')['images']['godot_engine']
    worker.previous.prior.verify(engine)
    command = [engine['path'], '--headless', '--path', str(C.ROOT), '--script', 'res://' + script,
               '--', *map(str, args), str(result_path)]
    env = gate.godot_environment(folder, name + '-host')
    if extra_environment:
        env.update(extra_environment)
    with (folder / (name + '-stdout.txt')).open('xb') as out, (folder / (name + '-stderr.txt')).open('xb') as err:
        with subprocess.Popen(command, cwd=C.ROOT, env=env, stdout=out, stderr=err, creationflags=subprocess.CREATE_NO_WINDOW) as process:
            try:
                code = process.wait(timeout=timeout)
                timed_out = False
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
                code, timed_out = process.returncode, True
    C.write_new(folder / (name + '-execution.json'), dict(command=command, return_code=code, timed_out=timed_out))
    assert code == 0 and not timed_out and (folder / (name + '-stderr.txt')).read_bytes() == b'', name
    result = C.read(result_path)
    assert result['ok'] and all(result['checks'].values()) and result['world_build_count'] == result['solver_step_count'] == 0
    print(json.dumps(dict(stage=name, checks=len(result['checks']), ok=True)), flush=True)
    return result_path


def run(folder, modes=('full', 'entry', 'partial')):
    folder = Path(folder).resolve()
    assert folder.is_relative_to(C.EVIDENCE)
    lock = C.read(folder / 'operation-lock.json')
    assert lock['acquired'] and lock['owner_process_id'] == os.getppid()
    before = [C.bind(path) for path in dependencies()]
    C.write_new(folder / 'bindings-before.json', before)
    with zipfile.ZipFile(folder / 'source.zip', 'x', zipfile.ZIP_DEFLATED) as archive:
        for path in dependencies():
            archive.write(path, path.relative_to(C.ROOT).as_posix())
    state = dict(ok=False, physical_attempted=False)
    try:
        inputs = C.read(C.ROOT / 'sdk/core/contracts/r10dd_native_reference_inputs_v1.json')['fixture']
        worker.previous.prior.verify(inputs)
        head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=C.ROOT, text=True).strip()
        declaration = launch.declaration(head, fixture=True)
        declared = folder / 'fixture-declaration.json'
        C.write_new(declared, declaration)
        completed = []
        for mode in modes:
            name = 'full' if mode == 'full' else mode + '-refusal'
            environment = {'SPORE_R10DG_FIXTURE_DECLARATION': str(declared)}
            if mode != 'full': environment['SPORE_R10DG_FIXTURE_REFUSAL'] = mode
            fixture = stage(folder, name + '-worker', 'tests/test_r10dg_complete_report_fixture.gd', [inputs['path']], timeout=600,
                            extra_environment=environment)
            report = Path(str(fixture) + '.report.json')
            engine = declaration['runtime']['images']['godot_engine']['path']
            launch.run_process(folder, name + '-reader', [engine, '--headless', '--path', C.ROOT, '--script',
                'res://sdk/trace_analysis/r10dg_recovery_replay.gd', '--', report,
                declaration['candidate_profile']['resource'], declaration['candidate_profile']['raw_sha256'], declared],
                launch.clean_environment(), timeout=1200)
            lines = (folder / (name + '-reader.stdout.txt')).read_text(encoding='utf-8').splitlines()
            receipts = [json.loads(line.removeprefix('DEVELOPMENT_RECOVERY_CANDIDATE_REPLAY ')) for line in lines
                        if line.startswith('DEVELOPMENT_RECOVERY_CANDIDATE_REPLAY ')]
            assert len(receipts) == 1 and receipts[0]['ok'] is True, receipts
            C.write_new(folder / (name + '-reader-result.json'), receipts[0])
            print(json.dumps(dict(stage=name + '-reader', ok=True)), flush=True)
            completed.append(dict(mode=mode, fixture=C.bind(fixture), report=C.bind(report), reader=C.bind(folder / (name + '-reader-result.json'))))
        state.update(ok=True, completed=completed, complete_report_and_refusal_population=list(modes) == ['full', 'entry', 'partial'])
    except BaseException:
        state['error'] = traceback.format_exc()
        raise
    finally:
        after = [C.bind(path) for path in dependencies()]
        C.write_new(folder / 'bindings-after.json', after)
        state['source_unchanged'] = before == after
        C.write_new(folder / 'execution.json', state)
    assert state['source_unchanged']


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--run', required=True)
    parser.add_argument('--only-refusals', action='store_true')
    args = parser.parse_args()
    run(args.run, ('entry', 'partial') if args.only_refusals else ('full', 'entry', 'partial'))
