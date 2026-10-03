"""Retain production handoff, supervisor/refusal, reader and retention checks.

This component is a development integration check. The complete safety graph
and its clean pushed freeze remain mandatory before any physical attempt.
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
import r10ai_development as identity
import r10ai_context_handoff as handoff
import r10ai_native_component as native

ROOT, EVIDENCE = identity.ROOT, identity.EVIDENCE
RECORD = ROOT / 'sdk/recovery/r10ai_production_integration_component_v1.json'
STAGES = dict(finite_task_audit=11, retention_gate=1, production_workflow=3, context_handoff=3, smoke_reader=8)
PREFIXES = ('R10AI_PRODUCTION_WORKFLOW_ROOT ', 'R10AI_HANDOFF_ROOT ',
            'R10AI_SMOKE_READER_ROOT ', 'R10AI_RETENTION_CHECK ')
CLAIMS = dict(production_supervisor_integrated=True, context_handoff_executed=True,
    native_authority_replaced_by_read_only_identity_in_handoff=True,
    physical_execution_authorized=False, complete_safety_gate_qualified=False,
    complete_physical_route_proven=False, world_build_count=0, solver_step_count=0,
    physical_acceptance_authority=False, release_authority=False)


def roots(out):
    found = []
    for stdout in sorted(out.glob('*.stdout.txt')):
        for line in stdout.read_text().splitlines():
            if any(line.startswith(prefix) for prefix in PREFIXES):
                root = Path(line.partition(' ')[2]).resolve()
                assert root.parent == EVIDENCE and root.name.startswith('r10ai-')
                found.append(root)
    assert len(found) == len(set(found))
    return found


def tokens():
    return [native.closure.bind(p) for p in sorted(EVIDENCE.glob('r10ai*consumption*.json'))]


def validate(out):
    execution = candidate.read(out / 'execution.json')
    assert execution['ok'] is execution['source_unchanged'] is True
    assert candidate.read(out / 'source-before.json') == candidate.read(out / 'source-after.json')
    assert candidate.read(out / 'tokens-before.json') == candidate.read(out / 'tokens-after.json') == tokens()
    observed = {}
    for name, count in STAGES.items():
        process = candidate.read(out / (name + '.execution.json'))
        assert process['returncode'] == 0 and process['timed_out'] is False, name
        assert process['command'] == [sys.executable, '-B', '-X', 'utf8', '-m', 'unittest',
            'discover', '-s', 'tests', '-p', 'test_r10ai_' + name + '.py', '-v']
        stderr = (out / (name + '.stderr.txt')).read_text()
        assert re.findall(r'Ran (\d+) tests? in ', stderr) == [str(count)], (name, stderr[-2000:])
        assert stderr.rstrip().endswith('OK') and 'skipped=' not in stderr
        observed[name] = count
    children = roots(out); assert len(children) == 4
    for root in children:
        names = ('source_before.json', 'source_after.json') if root.name.startswith('r10ai-retention-check-') else ('source-before.json', 'source-after.json')
        assert candidate.read(root / names[0]) == candidate.read(root / names[1])
        if root.name.startswith('r10ai-handoff-'):
            handoff.verify(root / 'declaration.json')
            result = candidate.read(root / 'r10ai_pre_world_consumption/consumer.json')
            assert result['construction_guard']['failure_code'] == 'R10AI_NATIVE_WORLD_QUALIFICATION_PENDING'
        if root.name.startswith('r10ai-retention-check-'):
            result = candidate.read(root / 'result.json')
            assert result['ok'] is True and len(result['cases']) == 11
            assert all(case['passed'] is True for case in result['cases'])
            assert result['world_build_count'] == result['solver_step_count'] == 0
            observed['compact_retention_controls'] = 11
    return observed


def run():
    assert not RECORD.exists()
    out = EVIDENCE / ('r10ai-production-integration-' + uuid.uuid4().hex); out.mkdir()
    print('R10AI_PRODUCTION_INTEGRATION_ROOT ' + out.as_posix(), flush=True)
    before = consumer._source_snapshot(); handoff.write(out / 'source-before.json', before)
    handoff.write(out / 'tokens-before.json', tokens())
    key = candidate.R10AI_ROUTE_ENTRY_PATH
    dependencies = candidate.read(key)['bound_source_files'] + [native.closure.bind(key)]
    assert any(Path(row['path']).name == Path(__file__).name for row in dependencies)
    handoff.write(out / 'dependencies-before.json', dependencies)
    execution = dict(ok=False, **CLAIMS)
    try:
        for name, count in STAGES.items():
            command = [sys.executable, '-B', '-X', 'utf8', '-m', 'unittest',
                'discover', '-s', 'tests', '-p', 'test_r10ai_' + name + '.py', '-v']
            with (out / (name + '.stdout.txt')).open('xb') as stdout, (out / (name + '.stderr.txt')).open('xb') as stderr:
                with subprocess.Popen(command, cwd=ROOT, stdout=stdout, stderr=stderr,
                        creationflags=subprocess.CREATE_NO_WINDOW) as process:
                    try:
                        code = process.wait(timeout=600); timed_out = False
                    except subprocess.TimeoutExpired:
                        killed = subprocess.run(['taskkill', '/PID', str(process.pid), '/T', '/F'],
                            capture_output=True, timeout=30, creationflags=subprocess.CREATE_NO_WINDOW)
                        handoff.write(out / (name + '.timeout-kill.json'), dict(returncode=killed.returncode,
                            stdout=killed.stdout.decode(errors='replace'), stderr=killed.stderr.decode(errors='replace')))
                        process.wait(timeout=30); code = process.returncode; timed_out = True
                    handoff.write(out / (name + '.execution.json'), dict(command=command, process_id=process.pid,
                        returncode=code, timed_out=timed_out, timeout_seconds=600))
            assert code == 0 and not timed_out, name
            stderr = (out / (name + '.stderr.txt')).read_text()
            assert re.findall(r'Ran (\d+) tests? in ', stderr) == [str(count)] and stderr.rstrip().endswith('OK'), name
            print('R10AI_PRODUCTION_INTEGRATION_PASS ' + name + ' ' + str(count), flush=True)
        execution['ok'] = True
    except BaseException:
        execution['error'] = traceback.format_exc(); raise
    finally:
        after = consumer._source_snapshot(); handoff.write(out / 'source-after.json', after)
        handoff.write(out / 'tokens-after.json', tokens())
        execution['source_unchanged'] = before == after
        handoff.write(out / 'execution.json', execution)
    observed = validate(out)
    for item in dependencies:
        native.verify(item)
    evidence = [native.closure.bind(p) for root in [out, *roots(out)] for p in sorted(root.rglob('*')) if p.is_file()]
    failures = []
    for failed in sorted(EVIDENCE.glob('r10ai-production-integration-*')):
        if failed != out and (failed / 'execution.json').is_file():
            failures.extend(native.closure.bind(p) for root in [failed, *roots(failed)]
                            for p in sorted(root.rglob('*')) if p.is_file())
    # CRLF matches the unpinned JSON convention in this Windows checkout.
    with RECORD.open('x', encoding='utf-8', newline='\r\n') as stream:
        stream.write(json.dumps(dict(schema_version='sporespore_r10ai_production_integration_component_v1',
            ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
                authority_mode='zero_world_production_integration_component', question_class='development'),
            evidence_root=out.as_posix(), dependencies=dependencies, evidence=evidence,
            retained_failed_attempts=failures, observed=observed, claim_boundary=CLAIMS,
            next_action='Declare and execute the complete affected safety graph including fresh full Python consumer controls at its exact source key, then use a clean pushed freeze for the sole development diagnostic.'), indent=2) + '\n')
    return observed


def audit():
    record = candidate.read(RECORD)
    assert record['claim_boundary'] == CLAIMS
    for item in record['dependencies'] + record['evidence'] + record['retained_failed_attempts']:
        native.verify(item)
    observed = validate(Path(record['evidence_root']))
    assert observed == record['observed']
    return observed


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('--run', action='store_true')
    print(json.dumps(dict(observed=run() if parser.parse_args().run else audit(), **CLAIMS), indent=2))
