"""Audit the prospective capture worker, synthetic interfaces and Python replay.

This component does not authorize a population or run physics. Worker hook
execution in a live recovery remains a required subsequent diagnostic.
"""
import argparse
import json
from pathlib import Path

import r10ac_contact_frame_replay as replay
from r10ac_support_loss_diagnosis import ROOT, EVIDENCE, binding, write

RECORD = ROOT / 'sdk/recovery/r10ac_contact_capture_component_v1.json'
CHECK = EVIDENCE / 'r10ac-capture-check-6025ba78de6f44de9b2e8218b3caacce'
EARLIER = [EVIDENCE/name for name in (
    'r10ac-capture-interface-8a5a7f6e9dc646d39383b5e1bef5e9d9',
    'r10ac-capture-interface-de73e58b97cf4354af9661e87b300885',
    'r10ac-capture-interface-bbbc0ac6bd8e4252b0c396ea432ec3f9',
    'r10ac-capture-check-2a611010fe9e421da99d1c9aafe5324f',
)]
read = lambda p: json.loads(Path(p).read_text(encoding='utf-8-sig'))


def observations():
    result = read(CHECK/'result.json')
    assert result['ok'] is True and result['world_build_count'] == result['solver_step_count'] == 0
    assert result['physical_acceptance_authority'] is result['release_authority'] is False
    native = result['capture']
    assert native['positive_cases'] == 5 and native['negative_cases'] == 29
    assert native['callback_bodies_checked'] == 9 and native['serialized_roundtrip_exact'] is True
    assert native['missing_model_refused'] is True
    before = read(CHECK/'source-before.json')
    assert before == read(CHECK/'source-after.json')
    for row in before:
        current = binding(ROOT/row['path'])
        assert current['raw_sha256'] == 'sha256:'+row['sha256'].lower()
        assert current['byte_length'] == row['bytes']
    runtime = read(CHECK/'runtime.json')
    for name in ('engine','core'):
        assert binding(runtime[name])['raw_sha256'] == 'sha256:'+runtime[name+'_sha256'].lower()
    assert runtime['engine_sha256'].lower() == '491663b2f41147938b45eeb0863d68a0bb14ec18c6349d94402df846f29f9347'
    assert runtime['core_sha256'].lower() == '729661dfd0936a4858238254fa8429688ad8815c49bda1dc9cd1cc3f6604ba08'
    for name in ('worker-parse','capture'):
        receipt = read(CHECK/(name+'.execution.json'))
        assert receipt['exit_code'] == receipt['stderr_bytes'] == 0 and receipt['timed_out'] is False
        assert (CHECK/(name+'.stderr.log')).read_bytes() == b''
        command = read(CHECK/(name+'.command.json'))
        assert command['executable'] == runtime['engine'] and command['timeout_ms'] == 60000
        expected_script = ('res://sdk/adapters/godot/gdscript/r10ac_capture_worker_v1.gd'
            if name == 'worker-parse' else 'res://tests/test_r10ac_contact_frame_capture.gd')
        assert expected_script in command['arguments']
        if name == 'worker-parse':
            assert '--check-only' in command['arguments']
    assert read(CHECK/'lock.json')['acquired'] is True
    assert (CHECK/'replay.stderr.log').read_bytes() == b''
    independent = replay.check_fixture_result(CHECK/'fixtures.json')
    marker = 'R10AC_CONTACT_FRAME_REPLAY '
    rows = [line[len(marker):] for line in (CHECK/'replay.stdout.log').read_text(encoding='utf-8-sig').splitlines() if line.startswith(marker)]
    assert len(rows) == 1 and json.loads(rows[0]) == independent
    # A successful assertion record from a nonterminal process is not accepted.
    assert read(EARLIER[0]/'execution.json')['exit_code'] != 0
    assert 'isn\'t a constant expression' in (EARLIER[0]/'stderr.log').read_text(encoding='utf-8-sig')
    assert read(EARLIER[1]/'execution.json')['exit_code'] != 0
    assert read(EARLIER[1]/'forced-stop.json')['qualification_pass'] is False
    assert "Can't free a RefCounted object" in (EARLIER[1]/'stderr.log').read_text(encoding='utf-8-sig')
    assert read(EARLIER[2]/'execution.json')['exit_code'] == 0
    worker = (ROOT/'sdk/adapters/godot/gdscript/r10ac_capture_worker_v1.gd').read_text(encoding='utf-8')
    assert worker.startswith('extends "res://sdk/adapters/godot/gdscript/r10ab_route_worker_v1.gd"')
    assert 'func _authorized_seed_binding_v1' not in worker
    parent = (ROOT/'sdk/adapters/godot/gdscript/r10ab_recovery_worker_v1.gd').read_text(encoding='utf-8')
    refusal = parent.split('func _authorized_seed_binding_v1(',1)[1].split('\nfunc ',1)[0]
    assert refusal.count('return false') == 1 and 'return true' not in refusal
    return dict(ok=True, worker_hook_implemented=True, worker_parse_passed=True,
        worker_hooks_physically_exercised=False, native_contact_population_observed=False,
        native_positive_cases=5, native_negative_refusals=29, callback_body_count=9,
        exact_serialized_roundtrip=True, independent_positive_replays=independent['independent_positive_replays'],
        independent_negative_refusals=independent['independent_negative_refusals'],
        exact_float32_contact_coordinate_replay=True, current_capture_cost_instrumented=True,
        live_capture_cost_measured=False, source_unchanged_during_checks=True,
        failed_parser_and_nonterminal_test_retained=True, launch_still_refused=True,
        original_controller_or_foot_classifier_changed=False, physical_population_declared=False,
        world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)


def capture():
    observed = observations()
    sources = [Path(__file__), Path(replay.__file__),
        ROOT/'sdk/conformance/content_addressed_zero_world_closure.py',
        ROOT/'sdk/conformance/r10ac_support_loss_diagnosis.py',
        ROOT/'sdk/recovery/r10ac_contact_frame_component_v1.json',
        ROOT/'sdk/adapters/godot/gdscript/r10ab_route_worker_v1.gd',
        ROOT/'sdk/adapters/godot/gdscript/r10ab_recovery_worker_v1.gd']
    sources += [ROOT/row['path'] for row in read(CHECK/'source-before.json')]
    source_root = Path('C:/Users/Cole/CodeStuff/dependencies/godot-sporespore-4.7-r136')
    sources += [source_root/('core/math/'+name) for name in ('basis.cpp','transform_3d.cpp','transform_3d.h','vector3.h')]
    sources = list(dict.fromkeys(sources))
    files = [p for folder in (CHECK,*EARLIER) for p in sorted(folder.iterdir()) if p.is_file()]
    write(RECORD, dict(schema_version='sporespore_r10ac_contact_capture_component_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',
            authority_mode='prospective_capture_worker_and_independent_synthetic_replay',question_class='development'),
        source_bindings=[binding(p) for p in sources],retained_evidence=[binding(p) for p in files],observed=observed,
        scope='Read-only diagnostic sidecar on the inherited V24 production path. Nine exact callback bases/origins and original direct/contact source hashes are retained. Contact-time points are matched one-to-one to original loaded floor-contact samples; original classifications are checked, not replaced. Rejected capture records are retained and abort the new diagnostic.',
        limits='Synthetic interface and replay checks only. The worker has not run a world, capture cost is not physically measured, and no fresh population, launcher integration or complete safety gate is qualified.',
        next_action='Declare a distinct bounded production-path development population and its capture profile, integrate launcher/reader and full-tail retention checks, qualify the complete applicable safety gate, then execute the fresh diagnostic with the original V24 controller and foot rule unchanged.'))
    return observed


def audit():
    value = read(RECORD)
    for row in value['source_bindings']+value['retained_evidence']:
        assert binding(row['path']) == row
    observed = observations()
    assert value['observed'] == observed
    return observed


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture',action='store_true')
    print('R10AC_CONTACT_CAPTURE_COMPONENT '+json.dumps(capture() if parser.parse_args().capture else audit()),flush=True)
