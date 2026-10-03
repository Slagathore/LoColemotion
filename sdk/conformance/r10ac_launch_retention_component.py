"""Audit R10AC reservation and compact retention components, never a full gate."""
import argparse
import json
from pathlib import Path
import re

import r10ac_development_v2 as identity
import r10ac_host_runtime as host
import development_recovery_candidate as candidate
from r10ac_support_loss_diagnosis import binding, write

ROOT, EVIDENCE = identity.ROOT, identity.EVIDENCE
RECORD = ROOT / 'sdk/recovery/r10ac_launch_retention_component_v1.json'
KEY = ROOT / 'sdk/recovery/r10ac_v56_walking_entry_contract_v18.json'
SUITE = EVIDENCE / 'r10ac-launch-retention-suite-ae97895d1c454e12b775f553f1c9fddb'
GUARD = EVIDENCE / 'r10ac-launch-guard-e8b19c934bb34a919d81ecc3c99f6df7'
HOST = EVIDENCE / 'r10ac-host-check-d213b08f49a24e5a877b1319338a12b0'
RETENTION_SUITE = EVIDENCE / 'r10ac-retention-suite-4722f3d497cc46cfbd3b013d0544fe2c'
RETENTION = EVIDENCE / 'r10ac-retention-check-57fefa0b721e4b7ebb34039091b21ee8'
SELECTION = EVIDENCE / 'r10ac-selection-check-b06cb67325a541e6ad96540a4bedf74d'
EARLIER = [EVIDENCE / name for name in (
    'r10ac-launch-suite-f1f9fd09a68745bf81c322e2703c1081',
    'r10ac-launch-guard-09d0137444274c1c8a938759cce7d6fa',
    'r10ac-launch-suite-6711bfc7f7384dbb9bc4be4a5eb2684b',
    'r10ac-launch-guard-2906999c045e4141b8bbc3e187deea7c',
    'r10ac-host-check-50b2e82e3560424bb48bb1c0ff9adad4',
    'r10ac-retention-suite-200cdaa5ddcb4919a3502d85451dcf9b',
    'r10ac-retention-check-5655987f79c14e4ca197db01458354bb',
    'r10ac-retention-check-07067bcf89a749c6afcab22a5646c28d',
    'r10ac-selection-check-0b8dcc8df7204878a383b4eee11d1148')]
read = lambda path: json.loads(Path(path).read_text(encoding='utf-8-sig'))


def passed(folder, pattern, count):
    assert read(folder / (pattern + '.execution.json'))['exit_code'] == 0
    assert re.search(r'Ran ' + str(count) + r' tests? in [\d.]+s\s+OK\s*$',
        (folder / (pattern + '.stderr.txt')).read_text(encoding='utf-8-sig'))


def observations():
    key = read(KEY)
    assert candidate.R10AC_ROUTE_ENTRY_PATH == KEY and len(key['bound_source_files']) == 1743
    for row in key['bound_source_files']:
        actual = binding(ROOT / row['path'])
        assert (actual['raw_sha256'], actual['byte_length']) == (row['raw_sha256'], row['byte_length']), row['path']
    # Guard/host ran on v17. The final revision only removes a redundant test
    # assignment and updates the two admission selectors; production is identical.
    old = read(ROOT / 'sdk/recovery/r10ac_v56_walking_entry_contract_v17.json')
    old_rows = {r['path']: r for r in old['bound_source_files']}
    changed = {r['path'] for r in key['bound_source_files'] if r != old_rows[r['path']]}
    assert changed == {'sdk/conformance/development_recovery_candidate.py',
        'sdk/adapters/godot/gdscript/development_recovery_walking_startup_v1.gd',
        'tests/test_r10ac_compact_child_retention.ps1'}
    for folder, names in [(GUARD, ('source_before.json', 'source_after.json')),
                          (HOST, ('source-before.json', 'source-after.json')),
                          (RETENTION, ('source_before.json', 'source_after.json')),
                          (SELECTION, ('source-before.json', 'source-after.json'))]:
        assert read(folder / names[0]) == read(folder / names[1])
    before = read(SELECTION / 'source-before.json')
    assert {r['path'] for r in key['bound_source_files']} < {r['path'] for r in before}
    for row in before:
        actual = binding(ROOT / row['path'])
        assert (actual['raw_sha256'], actual['byte_length']) == ('sha256:' + row['sha256'].lower(), row['bytes'])
    for folder in (SUITE, RETENTION_SUITE, SELECTION):
        assert read(folder / 'lock.json')['acquired'] is True
    passed(SUITE, 'test_r10ac_launch_guard.py', 10)
    passed(SUITE, 'test_r10ac_host.py', 7)
    passed(SUITE, 'test_r10ac_retention_gate.py', 1)
    assert read(RETENTION_SUITE / 'execution.json')['exit_code'] == 0
    assert re.search(r'Ran 1 test in [\d.]+s\s+OK\s*$', (RETENTION_SUITE / 'stderr.txt').read_text(encoding='utf-8-sig'))
    assert read(RETENTION / 'execution.json')['exit_code'] == 0
    assert read(RETENTION / 'execution.json')['source_unchanged'] is True
    assert (RETENTION / 'stderr.txt').read_bytes() == b''
    fixture = read(RETENTION / 'fixture.json')
    assert fixture['synthetic_launch_metadata'] is True and fixture['original_attempt_reclassified'] is False
    assert binding(fixture['original_envelope']['path']) == fixture['original_envelope']
    actual = host.bind_runtime(host.expected_binding()['images']['godot_console']['path'],
        host.expected_binding()['images']['powershell_host']['path'])
    assert fixture['runtime'] == actual == read(HOST / 'runtime-binding.json')
    result = read(RETENTION / 'result.json')
    cases = {r['case']: r for r in result['cases']}
    assert len(cases) == 11 and result['ok'] is True and all(r['passed'] is True for r in cases.values())
    for name, code in [('missing_selector', 'R10AC_NATIVE_OBSERVER_REQUIRED'),
                       ('wrong_route', 'R10AC_COMPACT_ROUTE_REQUIRED'),
                       ('crossed_runtime', 'R10AC_HOST_BINDING_NOT_EXACT'),
                       ('ambiguous_selector', 'COMPACT_ROUTE_AMBIGUOUS')]:
        assert code in cases[name]['failure_code'] and cases[name]['native_executor_calls'] == 0
    assert cases['integrated_child']['native_executor_calls'] == 1
    for name in ('compact_large', 'integrated_child'):
        release = read(RETENTION / name / 'payload_release_receipt.json')
        assert release['report_payload_in_compact_metadata'] is False
        assert release['original_evidence_rewritten'] is False and release['launch_relationship_valid'] is True
        assert release['compact_metadata_byte_length'] <= 65536
        for row in [release['retained_envelope'], *release['verified_artifacts'].values()]:
            assert binding(row['path']) == row
    native = read(SELECTION / 'native.json')
    assert native['ok'] is True and len(native['checks']) == 30 and all(native['checks'].values())
    for name in ('prepare', 'worker-parse', 'reader-parse', 'report', 'verify'):
        assert read(SELECTION / (name + '.execution.json'))['exit_code'] == 0
        assert (SELECTION / (name + '.stderr.log')).read_bytes() == b''
    import r10ac_development_launch as launch
    assert not launch.CONTRACT.exists()
    try: launch.contract()
    except ValueError as error: assert str(error) == 'R10AC_LAUNCH_COMPLETE_SAFETY_CONTRACT_PENDING'
    else: raise AssertionError('Undeclared safety graph admitted')
    assert not list(EVIDENCE.glob('r10ac*consumption*.json'))
    assert not any('r10ac_development' in read(p) for p in EVIDENCE.glob('development-recovery-smoke-*/declaration.json'))
    assert 'func _authorized_seed_binding_v1' not in (ROOT / 'sdk/adapters/godot/gdscript/r10ac_development_worker_v1.gd').read_text()
    assert 'R10AC_NATIVE_WORLD_QUALIFICATION_PENDING' in (ROOT / 'sdk/adapters/godot/gdscript/recovery_native_world_v1.gd').read_text()
    return dict(ok=True, source_key_inputs=1743, reservation_tests=10, host_tests=7,
        compact_retention_tests=1, compact_retention_controls=11, native_selection_checks=30,
        supervisor_reservation_integrated=True, reservation_tests_use_isolated_synthetic_gate=True,
        actual_child_launcher_compact_writer_checked=True, exact_v7_inner_runtime_check=True,
        native_process_executor_replaced_with_synthetic_fixture=True, real_population_consumed=False,
        native_world_authorization_integrated=False, complete_report_final_auditor_integrated=False,
        complete_safety_gate_passed=False, launch_still_refused=True,
        world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)


def capture():
    observed = observations()
    sources = [Path(__file__), ROOT / 'sdk/conformance/r10ac_support_loss_diagnosis.py']
    sources += [ROOT / f'sdk/recovery/r10ac_v56_walking_entry_contract_v{i}.json' for i in range(14, 19)]
    folders = (SUITE, GUARD, HOST, RETENTION_SUITE, RETENTION, SELECTION, *EARLIER)
    for folder in folders: assert folder.is_dir(), folder
    files = [p for folder in folders for p in sorted(folder.rglob('*')) if p.is_file()]
    write(RECORD, dict(schema_version='sporespore_r10ac_launch_retention_component_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
            authority_mode='development_reservation_and_compact_retention_checks', question_class='development'),
        source_bindings=[binding(p) for p in sources], retained_evidence=[binding(p) for p in files], observed=observed,
        scope='Exclusive fsynced reservation before launch publication, complete coverage/log/source/runtime refusal checks, supervisor integration, exact v7 inner runtime validation and actual compact writer with a synthetic process-executor seam.',
        retained_failures='The v14 identity-only test fixture lacked the full schedule and refused before reservation. The v16 retention positive case exposed an inner child-launch v6 qualification recheck; the explicit v7 branch repairs it. Both negatives are retained unchanged. v17 passed all checks; v18 removes only a redundant test assignment and renews admission selectors, with retention and native selection rerun.',
        limits='No real safety graph or population reservation, no native child/process ownership observation, no physical world, and no recovery or acceptance result. Fresh synthetic process metadata cannot stand in for live launch proof.',
        next_action='Bind the one-use receipt into native worker/world creation; integrate the complete R10AC final report audit; then declare and pass the full applicable safety graph before the fresh physical diagnostic. SDK1 remains 14/20.'))
    return observed


def audit():
    value = read(RECORD)
    for row in value['source_bindings'] + value['retained_evidence']:
        assert binding(row['path']) == row, row['path']
    observed = observations()
    assert observed == value['observed']
    return observed


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('--capture', action='store_true')
    print('R10AC_LAUNCH_RETENTION_COMPONENT ' + json.dumps(capture() if parser.parse_args().capture else audit()), flush=True)
