"""Audit native child authority and synthetic final-reader checks; no full gate."""
import argparse
import json
from pathlib import Path

import development_recovery_candidate as candidate
import r10ac_development_launch as launch
import r10ac_development_v2 as identity
import r10ac_host_runtime as host
import r10ac_replay_host as replay
from r10ac_complete_report_component import marker, suite_pass
from r10ac_support_loss_diagnosis import binding, write

ROOT, EVIDENCE = identity.ROOT, identity.EVIDENCE
RECORD = ROOT / 'sdk/recovery/r10ac_native_audit_component_v1.json'
KEY = ROOT / 'sdk/recovery/r10ac_v56_walking_entry_contract_v20.json'
SUITE = EVIDENCE / 'r10ac-native-audit-suite-a8f2dcd17b92443da34afc1bdde98c3c'
GUARD = EVIDENCE / 'r10ac-launch-guard-0b51467e28714f839843eeb4a0913d6a'
READER = EVIDENCE / 'r10ac-smoke-reader-4117b0833d1c46d18ea6ea3524e9c4a0'
REPORT = EVIDENCE / 'r10ac-complete-report-171a13e710194007a682dd16c29fd7e4'
SELECTION = EVIDENCE / 'r10ac-selection-check-cc3521da12264242951cd54febb39559'
EARLIER = [EVIDENCE / name for name in (
    'r10ac-native-authority-suite-afc94782160b49a4806384152a85d66c',
    'r10ac-launch-guard-c75f839102064817bcf74348f53c82e3')]
read = lambda path: json.loads(Path(path).read_text(encoding='utf-8-sig'))


def observations():
    key = read(KEY)
    assert candidate.R10AC_ROUTE_ENTRY_PATH == KEY
    assert len(key['bound_source_files']) == 1752
    for row in key['bound_source_files']:
        actual = binding(ROOT / row['path'])
        assert (actual['raw_sha256'], actual['byte_length']) == (row['raw_sha256'], row['byte_length']), row['path']
    for folder, before, after in [(GUARD, 'source_before.json', 'source_after.json'),
            (READER, 'source-before.json', 'source-after.json'),
            (REPORT, 'source-before.json', 'source-after.json'),
            (SELECTION, 'source-before.json', 'source-after.json')]:
        assert read(folder / before) == read(folder / after)
    snapshot = read(SELECTION / 'source-before.json')
    assert {r['path'] for r in key['bound_source_files']} < {r['path'] for r in snapshot}
    for row in snapshot:
        actual = binding(ROOT / row['path'])
        assert (actual['raw_sha256'], actual['byte_length']) == ('sha256:' + row['sha256'].lower(), row['bytes'])
    for folder in (SUITE, SELECTION):
        assert read(folder / 'lock.json')['acquired'] is True
    for pattern, count in [('test_r10ac_smoke_reader.py', 8),
            ('test_r10ac_native_world_authority.py', 17), ('test_r10ac_complete_report.py', 1)]:
        suite_pass(SUITE, pattern, count)
    assert read(EARLIER[0] / 'execution.json')['exit_code'] == 1
    assert 'R10AC_DEVELOPMENT_CHILD_PATH' in (EARLIER[0] / 'stderr.txt').read_text()

    probe = GUARD / 'test_native_pure_permission_and_real_helper_parent_probe'
    assert read(probe / 'native.execution.json')['exit_code'] == 0
    assert (probe / 'native.stderr.txt').read_bytes() == b''
    native = read(probe / 'result.json')
    assert native['ok'] is True and len(native['checks']) == 28 and all(native['checks'].values())
    runtime = host.expected_binding()
    assert host.bind_runtime(runtime['images']['godot_console']['path'], runtime['images']['powershell_host']['path']) == runtime
    assert native['owner_probe']['ok'] is True
    assert native['owner_probe']['worker_image'] == runtime['images']['godot_engine']
    assert native['world_build_count'] == native['solver_step_count'] == 0

    selected = read(SELECTION / 'native.json')
    assert selected['ok'] is True and len(selected['checks']) == 30 and all(selected['checks'].values())
    for name in ('prepare', 'worker-parse', 'reader-parse', 'report', 'verify'):
        assert read(SELECTION / (name + '.execution.json'))['exit_code'] == 0
        assert (SELECTION / (name + '.stderr.log')).read_bytes() == b''
    report = read(REPORT / 'worker_report.json')
    declaration = read(REPORT / 'synthetic-declaration.json')
    identity.validate_report_header(report, declaration)
    receipt = read(REPORT / 'complete-replay.json')
    assert receipt == marker(REPORT / 'replay.stdout.txt')
    assert receipt['input_raw_sha256'] == binding(REPORT / 'worker_report.json')['raw_sha256']
    assert receipt['ok'] is True and receipt['complete_report_timeline_replayed'] is True
    assert receipt['controller_and_diagnostic_replay_passed'] is True
    assert (receipt['transition_count'], receipt['entry_observation_count'], receipt['partial_observation_count']) == (575, 240, 63)
    assert receipt['complete_route_proven'] is False and receipt['post_recovery_hold_commands'] == 0
    contact = replay.independent_result(report, REPORT / 'synthetic-declaration.json', receipt)
    assert (contact['diagnostic_steps_replayed'], contact['matched_source_contacts'], contact['classification_changes']) == (575, 575, 0)
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
    measured = read(READER / 'synthetic-task-measurement.json')
    assert measured['finite_task_predicates_passed'] is False
    assert measured['physical_acceptance_authority'] is measured['release_authority'] is False
    assert not launch.CONTRACT.exists()
    try: launch.contract()
    except ValueError as error: assert str(error) == 'R10AC_LAUNCH_COMPLETE_SAFETY_CONTRACT_PENDING'
    else: raise AssertionError('Undeclared safety graph admitted')
    assert not list(EVIDENCE.glob('r10ac*consumption*.json'))
    assert not any('r10ac_development' in read(p) for p in EVIDENCE.glob('development-recovery-smoke-*/declaration.json'))
    assert not list(EVIDENCE.glob('development-recovery-smoke-*/children/*/r10ac_native_world_claim_v1.json'))
    return dict(ok=True, source_key_inputs=1752, native_authority_and_reservation_tests=17,
        final_reader_tests=8, native_permission_checks=28, native_selection_checks=30,
        complete_synthetic_report_tests=1, malformed_report_refusals=3,
        synthetic_timeline_steps=575, matched_synthetic_contacts=575, synthetic_classification_changes=0,
        actual_godot_python_parent_image_checked=True, native_world_authorization_integrated=True,
        final_auditor_integrated=True, physical_final_audit_proven=False,
        complete_walking_route_proven=False, complete_safety_gate_passed=False,
        real_population_consumed=False, launch_still_refused=True,
        world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)


def capture():
    observed = observations()
    sources = [Path(__file__), ROOT / 'sdk/conformance/r10ac_support_loss_diagnosis.py',
        ROOT / 'sdk/conformance/r10ac_complete_report_component.py', KEY,
        ROOT / 'sdk/recovery/r10ac_v56_walking_entry_contract_v19.json']
    folders = (SUITE, GUARD, READER, REPORT, SELECTION, *EARLIER)
    for folder in folders: assert folder.is_dir(), folder
    files = [p for folder in folders for p in sorted(folder.rglob('*')) if p.is_file()]
    write(RECORD, dict(schema_version='sporespore_r10ac_native_audit_component_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
            authority_mode='development_native_authority_and_final_reader_checks', question_class='development'),
        source_bindings=[binding(p) for p in sources], retained_evidence=[binding(p) for p in files], observed=observed,
        scope='One-use native child claim bound to the real Godot parent image, frozen launch receipt and exact environment; consumed permission before world construction; final-reader claim, identity, combined replay and diagnostic result checks.',
        retained_failures='The v19 native fixture crossed its isolated Python evidence namespace before launching Godot. The original failed suite is retained. v20 uses the canonical template captured before redirection; all 26 tests and native selection checks pass at v20.',
        limits='Isolated synthetic launch receipts are not a real population reservation. The real process probe checks ownership without claiming a world. The full synthetic report covers descent and partial recovery only, with no hold or walking. No physical final audit or complete applicable safety graph is proved.',
        next_action='Cover remaining phase capture and complete final-audit paths, declare and pass the full applicable safety graph, then freeze and run the fresh contact-frame diagnostic. A supported repair, official qualification, all-pass held-out decision and M07 adoption remain before SDK1 15/20.'))
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
    print('R10AC_NATIVE_AUDIT_COMPONENT ' + json.dumps(capture() if parser.parse_args().capture else audit()), flush=True)
