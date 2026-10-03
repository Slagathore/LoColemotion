"""Audit the synthetic partial-controller/contact report; no physical authority."""
import argparse
import hashlib
import json
from pathlib import Path
import re

import r10ac_development_v2 as identity
import r10ac_host_runtime as host
import r10ac_replay_host as replay
import r10ac_selection_check as selection
from r10ac_support_loss_diagnosis import binding, write

ROOT, EVIDENCE = identity.ROOT, identity.EVIDENCE
RECORD = ROOT / 'sdk/recovery/r10ac_complete_report_component_v1.json'
KEY = ROOT / 'sdk/recovery/r10ac_v56_walking_entry_contract_v13.json'
SUITE = EVIDENCE / 'r10ac-complete-suite-1283abe784af4b9e99b3619056b33b1d'
REPORT = EVIDENCE / 'r10ac-complete-report-b932da09b4ad41b5af4b119094b17cd4'
REGRESSION = EVIDENCE / 'r10ac-complete-regression-b40142d3c86e4249a297fe41125f159a'
HOST = EVIDENCE / 'r10ac-host-check-c673006167f54b90aa5ad42715c880ff'
SELECTION = EVIDENCE / 'r10ac-selection-check-3a6a200a84bd4305a310a468bbe8973e'
INTERRUPTED = EVIDENCE / 'r10ac-interrupted-report-replay-c7ea576b3cb9444db4bd9a0208ebd7c1'
EARLIER = [EVIDENCE / name for name in (
    'r10ac-complete-suite-a78e74ed1bcb482f87d5d79bb09d0f84',
    'r10ac-complete-report-8be23957467d4bf28b820e1a2e1bbfe3',
    'r10ac-complete-suite-99d50cf8c2114e329b1e95df5ea3ad66',
    'r10ac-complete-report-7d44d4882a134c7384a48847e61607e2',
    'r10ac-complete-suite-fee3c490a93042909c0b7ed967f6e3df',
    'r10ac-complete-report-5d23e75de56b43efb88ff6c743e73019',
    'r10ac-complete-suite-3153095d5d91412d977c448c16813aae',
    'r10ac-complete-report-641c80bfbf36473bbcd2b9459f4db2bd',
    'r10ac-complete-suite-afd6ef50279e401ebffcf82d4f43c874',
    'r10ac-complete-report-44f26a84568146b789cd01f4b30d7f65',
    'r10ac-host-check-9aa25b656827489dbe6d70ec5335e292')]
read = lambda path: json.loads(Path(path).read_text(encoding='utf-8-sig'))
MARKER = 'DEVELOPMENT_RECOVERY_CANDIDATE_REPLAY '


def marker(path):
    rows = [json.loads(line[len(MARKER):]) for line in path.read_text().splitlines() if line.startswith(MARKER)]
    assert len(rows) == 1
    return rows[0]


def suite_pass(folder, pattern, count):
    assert read(folder / (pattern + '.execution.json'))['exit_code'] == 0
    log = (folder / (pattern + '.stderr.txt')).read_text(encoding='utf-8-sig')
    assert re.search(r'Ran ' + str(count) + r' tests? in [\d.]+s\s+OK\s*$', log)


def observations():
    key = read(KEY)
    assert selection.candidate.R10AC_ROUTE_ENTRY_PATH == KEY
    assert len(key['bound_source_files']) == 1736
    for row in key['bound_source_files']:
        actual = binding(ROOT / row['path'])
        assert (actual['raw_sha256'], actual['byte_length']) == (row['raw_sha256'], row['byte_length']), row['path']
    before = read(SELECTION / 'source-before.json')
    assert before == read(SELECTION / 'source-after.json')
    assert {r['path'] for r in key['bound_source_files']} < {r['path'] for r in before}
    for row in before:
        actual = binding(ROOT / row['path'])
        assert (actual['raw_sha256'], actual['byte_length']) == ('sha256:' + row['sha256'].lower(), row['bytes'])
    for folder in (REPORT, HOST):
        assert read(folder / 'source-before.json') == read(folder / 'source-after.json')
    for folder in (SUITE, REGRESSION, SELECTION):
        assert read(folder / 'lock.json')['acquired'] is True
    suite_pass(SUITE, 'test_r10ac_complete_report.py', 1)
    suite_pass(REGRESSION, 'test_r10ac_host.py', 7)
    suite_pass(REGRESSION, 'test_qsdk_r10f_l14_runtime_binding.py', 11)
    # The first host regression remains a failed timeout, never regraded.
    assert read(SUITE / 'test_r10ac_host.py.execution.json')['exit_code'] == 1
    assert 'TimeoutExpired' in (SUITE / 'test_r10ac_host.py.stderr.txt').read_text()
    actual_runtime = host.bind_runtime(host.expected_binding()['images']['godot_console']['path'],
        host.expected_binding()['images']['powershell_host']['path'])
    assert actual_runtime == read(HOST / 'runtime-binding.json')
    for name in ('prepare', 'worker-parse', 'reader-parse', 'report', 'verify'):
        assert read(SELECTION / (name + '.execution.json'))['exit_code'] == 0
        assert (SELECTION / (name + '.stderr.log')).read_bytes() == b''
    native = read(SELECTION / 'native.json')
    assert native['ok'] is True and len(native['checks']) == 30 and all(native['checks'].values())
    assert native['selection'] == selection.candidate.selection(identity.reference())
    fixed = read(REPORT / 'partial.fixture.json')
    assert fixed['ok'] is True and fixed['synthetic_measurements_only'] is True
    assert all(fixed['checks'].values()) and len(fixed['checks']) == 35
    for name in ('v7_default_native_profile_refuses', 'explicit_v7_diagnostic_runtime_selected',
                 'runtime_selection_has_no_world_authority', 'native_world_stays_closed_after_runtime_selection'):
        assert fixed['checks'][name] is True
    report = fixed['active']['report']
    # The worker report was written with this exact compact JSON encoding.
    encoded = (json.dumps(report, separators=(',', ':'), allow_nan=False) + '\n').encode()
    assert 'sha256:' + hashlib.sha256(encoded).hexdigest() == binding(REPORT / 'worker_report.json')['raw_sha256']
    del encoded
    declaration = read(REPORT / 'synthetic-declaration.json')
    identity.validate_declaration(declaration)
    identity.validate_report_header(report, declaration)
    receipt = read(REPORT / 'complete-replay.json')
    assert receipt == marker(REPORT / 'replay.stdout.txt')
    assert receipt['input_raw_sha256'] == binding(REPORT / 'worker_report.json')['raw_sha256']
    assert receipt['ok'] is True and receipt['complete_report_timeline_replayed'] is True
    assert receipt['controller_and_diagnostic_replay_passed'] is True
    assert (receipt['transition_count'], receipt['entry_observation_count'], receipt['partial_observation_count']) == (575, 240, 63)
    assert receipt['complete_route_proven'] is False and receipt['post_recovery_hold_commands'] == 0
    expected = replay.independent_result(report, REPORT / 'synthetic-declaration.json', receipt)
    assert (expected['diagnostic_steps_replayed'], expected['matched_source_contacts'], expected['classification_changes']) == (575, 575, 0)
    for label, code in [('controller-missing', 'R10AB_RECOVERY_REPLAY_REPORT_PROFILE_OR_STEP_POPULATION'),
                        ('capture-missing', 'R10AC_CONTACT_REPORT_RECORD_POPULATION'),
                        ('source-crossed', 'R10AC_CONTACT_REPORT_TRACE_LINK')]:
        refused = marker(REPORT / (label + '.stdout.txt'))
        assert refused['ok'] is False and refused['failure_code'] == code
        assert refused['input_raw_sha256'] == binding(REPORT / (label + '.json'))['raw_sha256']
    for label in ('fixture', 'replay', 'controller-missing', 'capture-missing', 'source-crossed'):
        execution = read(REPORT / (label + '.execution.json'))
        assert execution['returncode'] == (0 if label in ('fixture', 'replay') else 1)
        assert execution['timed_out'] is False and execution['timeout_seconds'] == 180
        assert (REPORT / (label + '.stderr.txt')).read_bytes() == b''
    rejected = read(REPORT / 'partial.fixture.json.rejected.json')
    assert rejected['synthetic_negative_control'] is True
    assert rejected['result']['failure_code'] == 'R10K_PENDING_PARTIAL_SOURCE_CROSSED'
    assert len(rejected['link_records']) == 1
    for value in (fixed, receipt, expected):
        assert value['world_build_count'] == value['solver_step_count'] == 0
        assert value['physical_acceptance_authority'] is value['release_authority'] is False
    assert 'R10AC_NATIVE_WORLD_QUALIFICATION_PENDING' in (ROOT / 'sdk/adapters/godot/gdscript/recovery_native_world_v1.gd').read_text()
    assert 'func _authorized_seed_binding_v1' not in (ROOT / 'sdk/adapters/godot/gdscript/r10ac_development_worker_v1.gd').read_text()
    assert 'R10AC_COMPLETE_SAFETY_CONTRACT_PENDING' in (ROOT / 'sdk/run_development_recovery_smoke.ps1').read_text()
    assert not list(EVIDENCE.glob('r10ac*consumption*.json'))
    return dict(ok=True, source_key_inputs=1736, synthetic_fixture_assertions=35,
        complete_report_tests=1, malformed_report_refusals=3, host_tests=7, runtime_regression_tests=11,
        native_selection_checks=30, combined_positive_controller_replay_proven=True,
        synthetic_timeline_steps=575, descent_observations=240, partial_recovery_observations=63,
        matched_synthetic_contacts=575, synthetic_classification_changes=0,
        complete_walking_route_proven=False, complete_safety_gate_passed=False,
        single_use_reservation_integrated=False, launch_still_refused=True,
        world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)


def capture():
    observed = observations()
    sources = [Path(__file__), ROOT / 'sdk/conformance/r10ac_support_loss_diagnosis.py']
    sources += [ROOT / f'sdk/recovery/r10ac_v56_walking_entry_contract_v{i}.json' for i in range(8, 14)]
    folders = (SUITE, REPORT, REGRESSION, HOST, SELECTION, INTERRUPTED, *EARLIER)
    for folder in folders: assert folder.is_dir(), folder
    files = [p for folder in folders for p in sorted(folder.rglob('*')) if p.is_file()]
    write(RECORD, dict(schema_version='sporespore_r10ac_complete_report_component_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
            authority_mode='synthetic_partial_controller_and_contact_report_checks', question_class='development'),
        source_bindings=[binding(p) for p in sources], retained_evidence=[binding(p) for p in files], observed=observed,
        scope='Actual worker publication, exact v7 diagnostic runtime selection, cold native controller/contact reader and independent Python contact replay of explicitly synthetic sources. No controller or foot rule change.',
        retained_failures='Earlier prospective keys retain runtime refusal, missing synthetic source, and crossed-memory probe population failure. The interrupted v12 suite has no terminal test result; a separate retained replay passed. The first v13 host regression timed out; fresh unchanged-source host/runtime/selection regression passed without regrading it.',
        limits='Partial path only: 240 descent and 63 partial-recovery observations within a 575-step synthetic timeline. No upright, hold, walking or physical route proof. Direct cold-reader invocation is tested; canonical physical launch/publication and compact-retention integration remain pending. Stationary synthetic contacts do not measure physical classification changes.',
        next_action='Integrate the one-use diagnostic guard, complete report auditor and compact retention; declare and pass the complete applicable safety graph before the fresh physical diagnostic. SDK1 remains 14/20.'))
    return observed


def audit():
    value = read(RECORD)
    for row in value['source_bindings'] + value['retained_evidence']:
        assert binding(row['path']) == row, row['path']
    observed = observations()
    assert observed == value['observed']
    return observed


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', action='store_true')
    print('R10AC_COMPLETE_REPORT_COMPONENT ' + json.dumps(capture() if parser.parse_args().capture else audit()), flush=True)
