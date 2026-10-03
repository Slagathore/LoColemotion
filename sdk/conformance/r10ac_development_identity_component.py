"""Audit the fresh R10AC diagnostic declaration and cross-language identities.

This record covers no launcher selection, source qualification or physics.
"""
import argparse
import json
from pathlib import Path

import r10ac_development as identity
import r10ac_development_identity_check as checks
from r10ac_support_loss_diagnosis import binding, write

RECORD = identity.ROOT / 'sdk/recovery/r10ac_development_identity_component_v1.json'
CHECK = identity.EVIDENCE / 'r10ac-identity-check-1a98aafafa7d44e78cdd6246e29b5b62'
EARLIER = [identity.EVIDENCE / name for name in (
    'r10ac-identity-check-b114fe7c6d284796939c76d31a3a635a',
    'r10ac-identity-check-f85854c5358b4453a5eb5b6866877c26')]
read = lambda p: json.loads(Path(p).read_text(encoding='utf-8-sig'))


def observations():
    result = read(CHECK/'result.json')
    assert result['ok'] is True
    before = read(CHECK/'source-before.json')
    assert before == read(CHECK/'source-after.json')
    for row in before:
        current = binding(identity.ROOT/row['path'])
        assert current['raw_sha256'] == 'sha256:'+row['sha256'].lower()
        assert current['byte_length'] == row['bytes']
    engine = read(CHECK/'engine.json')
    assert binding(engine['path'])['raw_sha256'] == engine['raw_sha256']
    assert read(CHECK/'lock.json')['acquired'] is True
    for name in ('prepare','identity','verify'):
        execution = read(CHECK/(name+'.execution.json'))
        assert execution['exit_code'] == 0
        assert (CHECK/(name+'.stderr.log')).read_bytes() == b''
    execution = read(CHECK/'identity.execution.json')
    assert execution['timed_out'] is False and execution['stderr_bytes'] == 0
    command = read(CHECK/'identity.command.json')
    assert command['executable'] == engine['path'] and command['timeout_ms'] == 60000
    assert 'res://tests/test_r10ac_development_identity.gd' in command['arguments']
    native, fixture = read(CHECK/'native.json'), read(CHECK/'fixture.json')
    assert native['ok'] is True and all(native['checks'].values())
    assert native['fixture'] == fixture and native['report'] == fixture['expected_report']
    assert native['prefix_selection'] == fixture['prefix_selection']
    expected_counts = dict(declaration_positive=1,declaration_negative=44,
        report_positive=1,report_negative=5,prefix_positive=1,prefix_negative=4)
    assert native['counts'] == fixture['expected_counts'] == expected_counts
    for row in fixture['cases']:
        try:
            identity.validate_declaration(row['declaration'])
            admitted = True
        except ValueError:
            admitted = False
        assert admitted == row['admitted']
    identity.validate_report_header(native['report'], fixture['cases'][0]['declaration'])
    expected = dict(**checks.check_declarations(), **expected_counts)
    assert result['observed'] == read(CHECK/'prepare.stdout.log') == read(CHECK/'verify.stdout.log') == expected
    assert read(EARLIER[0]/'result.json')['ok'] is False
    assert read(EARLIER[0]/'identity.execution.json')['exit_code'] == 1
    assert read(EARLIER[1]/'result.json')['ok'] is False
    assert read(EARLIER[1]/'verify.execution.json')['exit_code'] == 1
    for folder in EARLIER:
        assert read(folder/'identity.execution.json')['timed_out'] is False
        assert read(folder/'source-before.json') == read(folder/'source-after.json')
        for row in read(folder/'source-before.json'):
            retained = (folder/'test-source.gd' if row['path'] == 'tests/test_r10ac_development_identity.gd'
                else folder/'wrapper-source.ps1' if row['path'] == 'sdk/check_r10ac_development_identity.ps1'
                else identity.ROOT/row['path'])
            assert binding(retained)['raw_sha256'] == 'sha256:'+row['sha256'].lower()
    # This prospective component must not quietly activate the still-unqualified route.
    worker = (identity.ROOT/'sdk/adapters/godot/gdscript/r10ac_capture_worker_v1.gd').read_text(encoding='utf-8')
    assert 'func _authorized_seed_binding_v1' not in worker
    assert not (identity.EVIDENCE/'r10ac_contact_frame_diagnostic_61248_consumption_v1.json').exists()
    return dict(**expected, physical_population_declared=True,
        seed_and_report_guards_checked=True, independent_publication_roundtrip=True,
        source_unchanged_during_checks=True, failed_test_attempts_retained=2,
        supervisor_integration_checked=False, prefix_facade_dispatch_integrated=False,
        complete_safety_gate_passed=False, launch_still_refused=True)


def capture():
    observed = observations()
    sources = [Path(__file__), Path(checks.__file__),
        identity.ROOT/'sdk/conformance/r10ac_support_loss_diagnosis.py',
        identity.ROOT/'sdk/adapters/godot/gdscript/r10ac_capture_worker_v1.gd']
    sources += [identity.ROOT/row['path'] for row in read(CHECK/'source-before.json')]
    sources = list(dict.fromkeys(sources))
    files = [p for folder in (CHECK,*EARLIER) for p in sorted(folder.iterdir()) if p.is_file()]
    write(RECORD,dict(schema_version='sporespore_r10ac_development_identity_component_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',
            authority_mode='prospective_diagnostic_identity_and_publication_checks',question_class='development'),
        source_bindings=[binding(p) for p in sources],retained_evidence=[binding(p) for p in files],
        observed=observed,
        scope='Fresh diagnostic identity 61248 maps to exposed phase 248. The inherited V24 controller, task clocks, contact rule and finite schedule are unchanged. Python and the exact v7 engine agree on declaration admission, prefix selection and independently checked report publication.',
        limits='The identity helpers are not a safety gate or launch authority. The shared candidate selector, native prefix facade, supervisor and full-report reader still need distinct R10AC integration and complete source qualification. No world or held-out attempt was run.',
        next_action='Wire the declared diagnostic into candidate dispatch, prefix facade, a guarded capture worker and complete report reader; qualify the entire applicable safety graph, reserve its single-use attempt and run the fresh bounded diagnostic.'))
    return observed


def audit():
    value = read(RECORD)
    for row in value['source_bindings']+value['retained_evidence']:
        assert binding(row['path']) == row
    observed = observations()
    assert value['observed'] == observed
    return observed


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', action='store_true')
    print('R10AC_DEVELOPMENT_IDENTITY_COMPONENT '+json.dumps(capture() if parser.parse_args().capture else audit()),flush=True)
