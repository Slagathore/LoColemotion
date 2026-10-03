"""Retain targeted safety-component development without qualification or worlds.

Run under the operation lock. Source must remain unchanged during each batch.
Full report cases and clean startup are reserved for their explicit gate runs.
"""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import uuid

import development_passive_entry_profile as source
import development_recovery_candidate as candidate
import r10ap_development as identity
import r10ap_development_launch as launch
from r10ap_context_handoff import write
from r10ac_support_loss_diagnosis import binding

ROOT, EVIDENCE = identity.ROOT, identity.EVIDENCE
DEFAULT_IDS = (
    'r10ap_native_interfaces', 'r10ap_host', 'r10ap_workflow', 'r10ap_runtime',
    'r10ap_native_control', 'r10ap_task_source', 'r10ap_loaded_source', 'r10ap_native_api',
    'r10ap_worker_new_partial', 'r10ap_worker_new_prone',
    'r10ap_worker_original_partial', 'r10ap_worker_original_prone',
    'r10ap_upright_worker', 'r10ap_segment_reader', 'r10ap_route_bindings',
    'r10ap_hold_interfaces', 'r10ap_measured_body', 'r10ap_walking_boundaries',
    'r10ap_contact_report', 'r10ap_walking_source', 'r10ap_pre_world', 'r10ap_progressive_headroom_geometry')


def run(ids):
    graph = launch.contract()
    stages = [s for s in graph['stages'] if s['id'] in ids]
    assert len(stages) == len(set(ids)) and all(i in DEFAULT_IDS for i in ids)
    out = EVIDENCE / ('r10ap-safety-development-' + uuid.uuid4().hex); out.mkdir()
    print('R10AP_SAFETY_DEVELOPMENT_ROOT ' + out.as_posix(), flush=True)
    before = source._source_snapshot(); write(out / 'source-before.json', before)
    tokens = [binding(p) for p in sorted(EVIDENCE.glob('r10ap*consumption*.json'))]
    write(out / 'tokens-before.json', tokens)
    key = candidate.R10AP_ROUTE_ENTRY_PATH
    write(out / 'dependencies.json', dict(source_key=binding(key),
        files=json.loads(key.read_text())['bound_source_files']))
    receipt = dict(ok=False, stages=[], qualification=False, world_build_count=0,
        solver_step_count=0, physical_execution_authorized=False,
        physical_acceptance_authority=False, release_authority=False)
    try:
        for stage in stages:
            name = stage['pattern'].removesuffix('.py')
            command = [sys.executable, '-B', '-X', 'utf8', '-m', 'unittest',
                'discover', '-s', 'tests', '-p', stage['pattern'], '-v']
            env = dict(os.environ)
            env.pop('SPORESPORE_DEVELOPMENT_TEST_CANDIDATE', None)
            if stage['candidate_bound']:
                env['SPORESPORE_DEVELOPMENT_TEST_CANDIDATE'] = identity.PROFILE.relative_to(ROOT).as_posix()
            timeout = stage.get('timeout_seconds', 300)
            with (out / (name+'.stdout.txt')).open('xb') as stdout, (out / (name+'.stderr.txt')).open('xb') as stderr:
                with subprocess.Popen(command, cwd=ROOT, stdout=stdout, stderr=stderr,
                        env=env, creationflags=subprocess.CREATE_NO_WINDOW) as process:
                    timed_out = False
                    try: code = process.wait(timeout=timeout)
                    except subprocess.TimeoutExpired:
                        timed_out = True
                        kill = subprocess.run(['taskkill','/PID',str(process.pid),'/T','/F'],
                            capture_output=True,timeout=30,creationflags=subprocess.CREATE_NO_WINDOW)
                        write(out/(name+'.timeout-kill.json'), dict(returncode=kill.returncode,
                            stdout=kill.stdout.decode(errors='replace'),stderr=kill.stderr.decode(errors='replace')))
                        code = process.wait(timeout=30)
            log = (out / (name+'.stderr.txt')).read_text(errors='replace')
            passed = code == 0 and not timed_out and re.findall(r'Ran (\d+) tests? in ', log) == [str(stage['tests'])] and log.rstrip().endswith('OK') and 'skipped=' not in log
            result = dict(id=stage['id'], pattern=stage['pattern'], tests=stage['tests'],
                command=command, returncode=code, timed_out=timed_out,
                timeout_seconds=timeout, passed=passed)
            write(out / (name+'.execution.json'), result); receipt['stages'].append(result)
            print('R10AP_SAFETY_DEVELOPMENT_STAGE '+stage['id']+' '+('PASS' if passed else 'FAIL'),flush=True)
        receipt['ok'] = all(s['passed'] for s in receipt['stages'])
    finally:
        after = source._source_snapshot(); write(out / 'source-after.json', after)
        after_tokens = [binding(p) for p in sorted(EVIDENCE.glob('r10ap*consumption*.json'))]
        write(out / 'tokens-after.json', after_tokens)
        receipt['source_unchanged'] = before == after
        receipt['tokens_unchanged'] = tokens == after_tokens
        receipt['ok'] = receipt['ok'] and receipt['source_unchanged'] and receipt['tokens_unchanged']
        write(out / 'execution.json', receipt)
    return receipt


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--stage', action='append', choices=DEFAULT_IDS)
    result=run(parser.parse_args().stage or DEFAULT_IDS)
    print(json.dumps(dict(ok=result['ok'], stages=len(result['stages']),
        tests=sum(s['tests'] for s in result['stages'] if s['passed']), qualification=False)))
    raise SystemExit(0 if result['ok'] else 1)
