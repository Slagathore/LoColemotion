"""Audit diagnostic host/declaration integration; complete launch remains pending."""
import argparse
import json
from pathlib import Path
import re

import r10ac_development_v2 as identity
import r10ac_host_runtime as host
import r10ac_selection_check as selection
from r10ac_support_loss_diagnosis import binding, write

ROOT, EVIDENCE = identity.ROOT, identity.EVIDENCE
RECORD = ROOT / 'sdk/recovery/r10ac_host_component_v1.json'
SUITE = EVIDENCE / 'r10ac-host-suite-dece76b988854241adb07b6163b2b37d'
HOST = EVIDENCE / 'r10ac-host-check-74aaf02d163243788b5011f8b4475c7c'
SELECTION = EVIDENCE / 'r10ac-selection-check-6f99fa4b64cc4084966c6d83fa294ab0'
EARLIER = [EVIDENCE / name for name in (
    'r10ac-host-suite-430fdf2a377c4b3896825930bcc1d305',
    'r10ac-host-check-a2b10f1a5a7345fa8660c590245967b2',
    'r10ac-host-suite-86140142477449558fd7c8b58b963309',
    'r10ac-host-check-6231a480b8e54ebbb4d820a5230fffb6',
    'development-measured-entry-profile-5d0916f9356748989705d58d3f84bd50')]
KEY = ROOT / 'sdk/recovery/r10ac_v56_walking_entry_contract_v7.json'
read = lambda path: json.loads(Path(path).read_text(encoding='utf-8-sig'))


def observations():
    key = read(KEY)
    assert selection.candidate.R10AC_ROUTE_ENTRY_PATH == KEY
    assert len(key['bound_source_files']) == 1731
    for row in key['bound_source_files']:
        current = binding(ROOT / row['path'])
        assert current['raw_sha256'] == row['raw_sha256'] and current['byte_length'] == row['byte_length'], row['path']
    before = read(SELECTION / 'source-before.json')
    assert before == read(SELECTION / 'source-after.json')
    assert {r['path'] for r in key['bound_source_files']} < {r['path'] for r in before}
    for row in before:
        current = binding(ROOT / row['path'])
        assert current['raw_sha256'] == 'sha256:' + row['sha256'].lower() and current['byte_length'] == row['bytes']
    assert read(HOST / 'source-before.json') == read(HOST / 'source-after.json')
    assert read(SUITE / 'lock.json')['acquired'] is True
    assert read(SELECTION / 'lock.json')['acquired'] is True
    for pattern, count in [('test_r10ac_host.py', 7), ('test_qsdk_r10f_l14_runtime_binding.py', 11)]:
        assert read(SUITE / (pattern + '.execution.json'))['exit_code'] == 0
        log = (SUITE / (pattern + '.stderr.txt')).read_text(encoding='utf-8-sig')
        assert re.search(r'Ran ' + str(count) + r' tests in [\d.]+s\s+OK\s*$', log)
    # This extra legacy suite did not execute tests: retain its source refusal.
    legacy = 'test_development_measured_entry_profile.py'
    assert read(SUITE / (legacy + '.execution.json'))['exit_code'] == 1
    assert 'runtime_load' in (SUITE / (legacy + '.stderr.txt')).read_text()
    old_binding = read(ROOT / 'sdk/development_passive_entry_runtime_binding_v1.json')
    declared = {r['path']: r['raw_sha256'] for r in old_binding['source_files']}
    for row in read(SUITE / 'legacy-profile-refusal.json')['mismatches']:
        assert row['unchanged_this_turn'] is True
        assert row['declared_sha256'] == declared[row['path']]
        assert row['current_sha256'] == row['pre_turn_head_sha256'] == identity.sha(ROOT / row['path'])
        assert row['current_sha256'] != row['declared_sha256']
    for name in ('runtime', 'runtime-mutations', 'library'):
        assert read(HOST / (name + '.execution.json'))['returncode'] == 0
        assert (HOST / (name + '.stderr.txt')).read_bytes() == b''
    for name in ('paired', 'seed', 'pending'):
        assert read(HOST / (name + '.execution.json'))['returncode'] != 0
    assert 'R10AC_COMPLETE_SAFETY_CONTRACT_PENDING' in (HOST / 'pending.stderr.txt').read_text()
    actual = host.bind_runtime(host.expected_binding()['images']['godot_console']['path'],
        host.expected_binding()['images']['powershell_host']['path'])
    assert actual == read(HOST / 'runtime-binding.json') == read(HOST / 'runtime.stdout.txt')
    declaration = read(HOST / 'supervisor-declaration-interface.json')
    identity.validate_declaration(declaration)
    import development_passive_entry_profile as entry
    entry.validate_declaration(declaration)
    assert (declaration['seed'], declaration['timeout_seconds_per_child'],
        declaration['independent_replay_timeout_seconds']) == (61248, 2400, 1200)
    for name in ('prepare', 'worker-parse', 'reader-parse', 'report', 'verify'):
        execution = read(SELECTION / (name + '.execution.json'))
        assert execution['exit_code'] == 0 and (SELECTION / (name + '.stderr.log')).read_bytes() == b''
        if name in ('worker-parse', 'reader-parse', 'report'):
            assert execution['timed_out'] is False and execution['stderr_bytes'] == 0
    native, fixture = read(SELECTION / 'native.json'), read(SELECTION / 'fixture.json')
    assert native['ok'] is True and len(native['checks']) == 30 and all(native['checks'].values())
    assert native['selection'] == fixture['selection'] == selection.candidate.selection(identity.reference())
    assert native['diagnostic_replay'] == fixture['diagnostic_expected']
    assert 'func _authorized_seed_binding_v1' not in (ROOT / 'sdk/adapters/godot/gdscript/r10ac_development_worker_v1.gd').read_text()
    assert not list(EVIDENCE.glob('r10ac*consumption*.json'))
    return dict(ok=True, host_launcher_tests=7, historical_runtime_regression_tests=11,
        runtime_mutation_refusals=len(read(HOST / 'runtime-mutations.json')), native_selection_checks=30,
        source_key_inputs=1731, actual_v7_runtime_images_reopened=True,
        python_powershell_runtime_binding_equal=True, actual_supervisor_declaration_checked=True,
        declaration_bound_four_argument_replay_command_checked=True, child_wall_seconds=2400, reader_wall_seconds=1200,
        legacy_v6_profile_regression='refused_preexisting_source_binding_before_tests',
        complete_safety_gate_passed=False, combined_positive_controller_replay_proven=False,
        single_use_reservation_integrated=False, launch_still_refused=True,
        world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)


def capture():
    observed = observations()
    sources = [Path(__file__), ROOT / 'sdk/conformance/r10ac_support_loss_diagnosis.py']
    sources += [ROOT / f'sdk/recovery/r10ac_v56_walking_entry_contract_v{i}.json' for i in (5, 6, 7)]
    files = [p for folder in (SUITE, HOST, SELECTION, *EARLIER) for p in sorted(folder.rglob('*')) if p.is_file()]
    write(RECORD, dict(schema_version='sporespore_r10ac_host_component_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
            authority_mode='diagnostic_host_and_declaration_interface_checks', question_class='development'),
        source_bindings=[binding(p) for p in sources], retained_evidence=[binding(p) for p in files], observed=observed,
        scope='Exact v7 host images, actual supervisor selection and declaration, diagnostic wall bounds, declaration-bound replay command and independent contact-result verification. Controller laws, simulated schedule and consumed predecessors remain unchanged.',
        retained_failures='The first host fixture omitted shared context-cache fields. The next historical runtime regression found a missing-schema refusal compatibility bug, now fixed. A broader legacy V6 profile test refused its already-stale source key before executing tests; that key is unchanged and this is not counted as a pass.',
        limits='No physics, complete safety qualification, positive full controller-plus-contact replay, durable reservation or M07 acceptance. Source key admission is not qualification.',
        next_action='Complete a positive combined report fixture and the one-use guard, integrate complete report auditing and compact retention, then declare and run the full applicable safety graph before the single fresh diagnostic.'))
    return observed


def audit():
    value = read(RECORD)
    for row in value['source_bindings'] + value['retained_evidence']:
        assert binding(row['path']) == row
    observed = observations()
    assert observed == value['observed']
    return observed


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', action='store_true')
    print('R10AC_HOST_COMPONENT ' + json.dumps(capture() if parser.parse_args().capture else audit()), flush=True)
