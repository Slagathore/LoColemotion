"""Exercise R10AP reservation/claim components; production launch remains closed.

Run --run under the operation lock. Synthetic reservation namespaces never touch
the real population token. The native probe checks the actual Godot parent image
and closed world boundary. It grants neither a world nor complete qualification.
"""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys
import traceback
import uuid

import development_passive_entry_profile as consumer
import development_recovery_candidate as candidate
import r10ap_development as identity
import r10ap_native_component as native
import r10ap_development_launch as launch

ROOT, EVIDENCE = identity.ROOT, identity.EVIDENCE
RECORD = ROOT / 'sdk/recovery/r10ap_launch_authority_component_v1.json'
STAGES = dict(physical_identity=5, startup_preflight=4, launch_guard=13, native_world_authority=20)
CLAIMS = dict(reservation_and_child_claim_components_tested=True,
    real_godot_parent_image_probed=True, synthetic_reservation_namespaces_only=True,
    production_supervisor_integrated=False, context_handoff_executed=False,
    complete_safety_gate_qualified=False, physical_execution_authorized=False,
    world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)
NEW_SOURCES = [
    'sdk/conformance/r10ap_physical_identity.py',
    'sdk/conformance/r10ap_development_launch.py',
    'sdk/conformance/r10ap_startup_preflight.py',
    'sdk/conformance/r10ap_native_world_authority.py',
    'sdk/conformance/r10ap_context_handoff.py',
    'sdk/conformance/r10ap_launch_component.py',
    'sdk/adapters/godot/gdscript/r10ap_native_world_guard_v1.gd',
    'sdk/adapters/godot/gdscript/r10ap_prepare_launch_context_v1.gd',
    'sdk/adapters/godot/gdscript/r10ap_pre_world_consumer_v1.gd',
    'tests/test_r10ap_physical_identity.py',
    'tests/test_r10ap_startup_preflight.py',
    'tests/test_r10ap_launch_guard.py',
    'tests/test_r10ap_native_world_authority.py',
    'tests/test_r10ap_native_world_guard.gd']


def write(path, value):
    with Path(path).open('x', encoding='utf-8', newline='\n') as stream:
        stream.write(json.dumps(value, indent=2, allow_nan=False) + '\n')


def tokens():
    return [native.closure.bind(p) for p in sorted(EVIDENCE.glob('r10ap*consumption*.json'))]


def stage_result(out, name, count):
    process = candidate.read(out / (name + '.execution.json'))
    assert process['returncode'] == 0 and process['timed_out'] is False, name
    assert process['command'] == [sys.executable, '-B', '-X', 'utf8', '-m', 'unittest',
        'discover', '-s', 'tests', '-p', 'test_r10ap_' + name + '.py', '-v']
    stderr = (out / (name + '.stderr.txt')).read_text()
    assert re.findall(r'Ran (\d+) tests? in ', stderr) == [str(count)], (name, stderr[-3000:])
    assert stderr.rstrip().endswith('OK') and 'skipped=' not in stderr, name
    return count


def child_roots(out):
    roots = []
    for name in STAGES:
        stdout = (out / (name + '.stdout.txt')).read_text()
        for line in stdout.splitlines():
            if line.startswith('R10AP_LAUNCH_GUARD_ROOT '):
                root = Path(line.partition(' ')[2]).resolve()
                assert root.parent == EVIDENCE and root.name.startswith('r10ap-launch-guard-')
                roots.append(root)
    assert len(roots) == len(set(roots)) == 2
    return roots


def inspect(out):
    execution = candidate.read(out / 'execution.json')
    assert execution['ok'] is execution['source_unchanged'] is True
    assert candidate.read(out / 'source-before.json') == candidate.read(out / 'source-after.json')
    assert candidate.read(out / 'tokens-before.json') == candidate.read(out / 'tokens-after.json') == tokens()
    assert not launch.CONTRACT.exists(), 'Complete production safety graph is still pending'
    observed = {name: stage_result(out, name, count) for name, count in STAGES.items()}
    roots = child_roots(out)
    native_results = []
    for root in roots:
        assert candidate.read(root / 'source_before.json') == candidate.read(root / 'source_after.json')
        for path in root.rglob('result.json'):
            value = candidate.read(path)
            assert value['ok'] is True and value['checks'] and all(value['checks'].values())
            assert value['world_build_count'] == value['solver_step_count'] == 0
            assert value['physical_acceptance_authority'] is value['release_authority'] is False
            assert value['owner_probe']['worker_image'] == launch.host.expected_binding()['images']['godot_engine']
            native_results.append(value)
    assert len(native_results) == 1
    observed['native_guard_checks'] = len(native_results[0]['checks'])
    return observed, roots


def run():
    assert not RECORD.exists()
    out = EVIDENCE / ('r10ap-launch-component-' + uuid.uuid4().hex); out.mkdir()
    print('R10AP_LAUNCH_COMPONENT_ROOT ' + out.as_posix(), flush=True)
    before = consumer._source_snapshot(); write(out / 'source-before.json', before)
    write(out / 'tokens-before.json', tokens())
    key = candidate.R10AP_ROUTE_ENTRY_PATH
    dependencies = candidate.read(key)['bound_source_files'] + [native.closure.bind(key)]
    dependencies += [native.closure.bind(ROOT / path) for path in NEW_SOURCES]
    write(out / 'dependencies-before.json', dependencies)
    execution = dict(ok=False, **CLAIMS)
    try:
        for name, count in STAGES.items():
            command = [sys.executable, '-B', '-X', 'utf8', '-m', 'unittest',
                'discover', '-s', 'tests', '-p', 'test_r10ap_' + name + '.py', '-v']
            with (out / (name + '.stdout.txt')).open('xb') as stdout, (out / (name + '.stderr.txt')).open('xb') as stderr:
                with subprocess.Popen(command, cwd=ROOT, stdout=stdout, stderr=stderr,
                        creationflags=subprocess.CREATE_NO_WINDOW) as process:
                    try:
                        code = process.wait(timeout=600); timed_out = False
                    except subprocess.TimeoutExpired:
                        # Own the entire test tree; a timed-out child must not
                        # survive a failed component or a subsequent source edit.
                        killed = subprocess.run(['taskkill', '/PID', str(process.pid), '/T', '/F'],
                            capture_output=True, timeout=30, creationflags=subprocess.CREATE_NO_WINDOW)
                        write(out / (name + '.timeout-kill.json'), dict(returncode=killed.returncode,
                            stdout=killed.stdout.decode(errors='replace'), stderr=killed.stderr.decode(errors='replace')))
                        process.wait(timeout=30); code = process.returncode; timed_out = True
                    write(out / (name + '.execution.json'), dict(command=command, process_id=process.pid,
                        returncode=code, timed_out=timed_out, timeout_seconds=600))
            stage_result(out, name, count)
            print('R10AP_LAUNCH_COMPONENT_PASS ' + name + ' ' + str(count), flush=True)
        execution['ok'] = True
    except BaseException:
        execution['error'] = traceback.format_exc()
        raise
    finally:
        after = consumer._source_snapshot(); write(out / 'source-after.json', after)
        write(out / 'tokens-after.json', tokens())
        execution['source_unchanged'] = before == after
        write(out / 'execution.json', execution)
    observed, roots = inspect(out)
    for item in dependencies:
        native.builds.verify(item)
    write(RECORD, dict(schema_version='sporespore_r10ap_launch_authority_component_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
            authority_mode='zero_world_launch_authority_components', question_class='development'),
        evidence_root=out.as_posix(), dependencies=dependencies, observed=observed,
        evidence=[native.closure.bind(p) for root in [out, *roots] for p in sorted(root.rglob('*')) if p.is_file()],
        retained_failed_attempts=[native.closure.bind(p)
            for failed in sorted(EVIDENCE.glob('r10ap-launch-component-*'))
            if failed != out and (failed / 'execution.json').is_file()
            for p in sorted(failed.rglob('*')) if p.is_file()],
        claim_boundary=CLAIMS,
        next_action='Execute real context handoff, integrate production supervisor/worker/world and final result consumers, then declare and pass the complete affected safety graph at a fresh source key before the sole diagnostic.'))
    return observed


def audit():
    record = candidate.read(RECORD)
    assert record['claim_boundary'] == CLAIMS
    for item in record['dependencies'] + record['evidence'] + record['retained_failed_attempts']:
        native.builds.verify(item)
    observed, _ = inspect(Path(record['evidence_root']))
    assert observed == record['observed']
    return observed


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run', action='store_true')
    print(json.dumps(dict(observed=run() if parser.parse_args().run else audit(), **CLAIMS), indent=2))
