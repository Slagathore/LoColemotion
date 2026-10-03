"""Check real R10AA worker sequences and replay their compiled calls, zero world.

--run requires the native-operation lock. Default audit reads retained evidence.
A worker component is not complete smoke qualification or physical acceptance.
"""
import argparse
from collections import Counter
import json
from pathlib import Path
import subprocess
import sys
import time
import uuid

import r10aa_native_component as native
import r10aa_task_source_component as source
from development_passive_entry_profile import _source_snapshot

ROOT, EVIDENCE = native.ROOT, native.EVIDENCE
RECORD = ROOT / 'sdk/recovery/r10aa_worker_component_v1.json'
NEW = EVIDENCE / 'r10aa-worker-9a95685d2fe1446caef1d120a464d7cd'
ORIGINAL = NEW
WRAPPER = EVIDENCE / 'r10aa-worker-source-check-d0c27153aa9648ae80ad292a2cc6bef6'
GODOT = EVIDENCE / 'qsdk-r24d157-godot-jolt-rotation-integration-energy-v6/development-cold-build-ed4ec00a/godot.windows.editor.dev.x86_64.exe'
PATHS = (
 'sdk/adapters/godot/gdscript/r10aa_recovery_worker_v1.gd',
 'sdk/adapters/godot/gdscript/r10aa_recovery_orchestrator_v1.gd',
 'sdk/adapters/godot/gdscript/development_recovery_candidate_worker_v1.gd',
 'sdk/adapters/godot/gdscript/development_recovery_stance_profile_v1.gd',
 'sdk/adapters/godot/gdscript/qsdk_r10f_l15_canonical_ownership_v1.gd',
 'sdk/adapters/godot/gdscript/r10v_recovery_worker_v1.gd',
 'sdk/adapters/godot/gdscript/r10v_recovery_orchestrator_v1.gd',
 'sdk/adapters/godot/gdscript/development_passive_entry_smoke_worker_v1.gd',
 'tests/test_sdk_qsdk_r10f_continuous_passive_recovery_worker.gd',
 'tests/test_development_r10aa_worker.py',
 'tests/test_development_r10aa_worker_hooks.gd',
 'tests/test_development_r10aa_legacy_worker_hooks.gd',
 'tests/test_development_r10v_branch_worker_hooks.gd',
 'tests/test_development_r10k_worker_hooks.gd',
 'tests/test_development_passive_entry_worker_hooks.gd',
 'tests/test_development_r10aa_orchestrator_refusals.gd',
 'sdk/conformance/r10aa_worker_component.py')
CASES = ((NEW, 'new-partial', 22), (NEW, 'new-prone', 11),
         (ORIGINAL, 'original-partial', 16), (ORIGINAL, 'original-prone', 10))

def reports():
    for folder in (NEW, ORIGINAL):
        assert native.read(folder / 'source_before.json') == native.read(folder / 'source_after.json')
    for folder, name, count in CASES:
        report = native.read(folder / (name + '.json'))
        assert native.read(folder / (name + '.execution.json'))['exit_code'] == 0
        assert (folder / (name + '.stderr.log')).read_bytes() == b''
        assert report['ok'] is True and report['failure'] == {}
        assert all(v is True for v in report['checks'].values())
        assert len(report['checks']) == count, (name, len(report['checks']))
        assert report['synthetic_measurements_only'] is True
        assert report['selector_and_launcher_validation_exercised'] is False
        assert report['world_build_count'] == report['solver_step_count'] == 0
        assert report['physical_acceptance_authority'] is report['release_authority'] is False
        partial = name.endswith('partial')
        assert len(report['entry_packets']) == (240 if partial else 1)
        assert len(report['partial_packets']) == (63 if partial else 0)
        if partial:
            assert report['final_partial_memory']['standing_samples_observed'] == 60
            assert report['final_state']['phase'] == 'fresh_selected_policy_walking_resume'
        assert len(report['transitions']) == (304 if partial else 15), (name, len(report['transitions']))
        previous = None
        for row in report['transitions']:
            assert row['advance']['ok'] is True
            assert row['event']['global_semantic_step'] == row['state_before']['previous_global_semantic_step'] + 1
            if previous is not None: assert row['state_before'] == previous
            previous = row['advance']['state_after']
        assert previous == report['final_state']
        yield name, report


def run():
    assert source.audit()['ok']
    bound, _ = native.runtime()
    out = EVIDENCE / ('r10aa-worker-audit-' + uuid.uuid4().hex)
    out.mkdir()
    before = _source_snapshot()
    native.write(out / 'source_before.json', before)
    print('R10AA_WORKER_AUDIT_ROOT ' + str(out), flush=True)
    core = native.ExactInputCore(bound['runtime']['path'])
    counts, fixtures = Counter(), {}
    with (out / 'compiled_replay.jsonl').open('x', encoding='utf-8', newline='\n') as trace:
        for name, report in reports():
            if name == 'new-partial':
                for key, index in (('entry', 1), ('handoff', 240), ('partial', 241), ('complete', 303)):
                    fixtures[key] = report['transitions'][index]
            if name == 'new-prone': fixtures['prone'] = report['transitions'][1]
            for group in ('entry_packets', 'partial_packets'):
                for index, packet in enumerate(report[group]):
                    call = packet['call']
                    assert call['ok'] is True and call['compiled_call_count'] == 1
                    assert packet['native_receipt'] == call['value']
                    for field in ('request', 'response'):
                        raw = call[field]['utf8_text'].encode('utf-8')
                        assert len(raw) == call[field]['utf8_byte_length']
                        assert native.diagnosis.digest(raw) == call[field]['raw_sha256']
                    result = core._call_json_input('ss_' + call['method'], call['request']['utf8_text'].encode('utf-8'))
                    assert result == call['value']
                    assert core.raw_response == call['response']['utf8_text'].encode('utf-8')
                    trace.write(json.dumps(dict(case=name, group=group, index=index, method=call['method'],
                        request_sha256=call['request']['raw_sha256'], response_sha256=call['response']['raw_sha256'],
                        exact_compiled_replay=True)) + '\n')
                    counts[name] += 1
    assert dict(counts) == {'new-partial': 303, 'new-prone': 1, 'original-partial': 303, 'original-prone': 1}
    native.write(out / 'orchestrator-input.json', fixtures)
    args = [str(GODOT), '--headless', '--path', str(ROOT), '--script',
        'res://tests/test_development_r10aa_orchestrator_refusals.gd', '--',
        str(out / 'orchestrator-input.json'), str(out / 'orchestrator-result.json')]
    started = time.monotonic()
    with (out / 'stdout.log').open('xb') as stdout, (out / 'stderr.log').open('xb') as stderr:
        try:
            process = subprocess.run(args, cwd=ROOT, stdout=stdout, stderr=stderr,
                timeout=60, creationflags=subprocess.CREATE_NO_WINDOW)
        except subprocess.TimeoutExpired:
            native.write(out / 'execution.json', dict(command=args, timed_out=True, direct_process_killed_and_reaped=True))
            raise
    native.write(out / 'execution.json', dict(command=args, exit_code=process.returncode, seconds=round(time.monotonic()-started,3)))
    after = _source_snapshot()
    native.write(out / 'source_after.json', after)
    assert before == after
    assert process.returncode == 0, (out / 'stderr.log').read_text(encoding='utf-8')
    assert (out / 'stderr.log').read_bytes() == b''
    result = native.read(out / 'orchestrator-result.json')
    assert result['ok'] is True and all(result['checks'].values())
    receipt = dict(ok=True, compiled_replay_counts=dict(counts), compiled_replay_count=sum(counts.values()),
        orchestrator_checks=len(result['checks']), world_build_count=0, solver_step_count=0,
        physical_acceptance_authority=False, release_authority=False)
    native.write(out / 'receipt.json', receipt)
    return receipt


def capture(out):
    assert not RECORD.exists()
    result = reconstruct(out)
    files = [p for folder in (NEW, WRAPPER, out) for p in sorted(folder.iterdir()) if p.is_file()]
    native.write(RECORD, dict(schema_version='sporespore_r10aa_worker_component_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='zero_world_worker_component', question_class='development'),
        evidence_root=out.as_posix(), source_component=native.diagnosis.binding(source.RECORD),
        source_bindings=[native.diagnosis.binding(ROOT / p) for p in PATHS],
        retained_evidence=[native.diagnosis.binding(p) for p in files], observed=result,
        initial_attempt_notes=[]))
    return result


def reconstruct(out):
    assert source.audit()['ok']
    counts = {name: len(report['checks']) for name, report in reports()}
    assert native.read(WRAPPER / 'worker.execution.json')['exit_code'] == 0
    assert native.read(out / 'source_before.json') == native.read(out / 'source_after.json')
    receipt = native.read(out / 'receipt.json')
    assert receipt['ok'] is True and receipt['compiled_replay_count'] == 608
    rows = [json.loads(line) for line in (out / 'compiled_replay.jsonl').read_text(encoding='utf-8').splitlines()]
    assert len(rows) == 608 and all(r['exact_compiled_replay'] is True for r in rows)
    assert native.read(out / 'execution.json')['exit_code'] == 0
    result = native.read(out / 'orchestrator-result.json')
    assert result['ok'] is True and all(result['checks'].values())
    return dict(ok=True, worker_tests=4, worker_checks=counts, total_worker_checks=sum(counts.values()),
        compiled_replay_count=608, orchestrator_checks=len(result['checks']),
        new_partial_commands=63, original_partial_commands=63, new_entry_samples=240,
        standing_samples_observed=60, original_partial_and_prone_preserved=True,
        upright_sequence_checked=False, launcher_reader_integrated=False, complete_smoke_safety_gate_passed=False,
        successor_physics_observed=False, world_build_count=0, solver_step_count=0,
        physical_acceptance_authority=False, release_authority=False)


def audit():
    record = native.read(RECORD)
    for item in record['source_bindings'] + record['retained_evidence'] + [record['source_component']]: native.verify(item)
    result = reconstruct(Path(record['evidence_root']))
    assert result == record['observed']
    return result

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run', action='store_true')
    parser.add_argument('--capture', type=Path)
    args = parser.parse_args()
    print('R10AA_WORKER_COMPONENT ' + json.dumps(run() if args.run else capture(args.capture) if args.capture else audit()), flush=True)
