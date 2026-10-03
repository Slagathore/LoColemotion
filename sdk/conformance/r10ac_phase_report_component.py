"""Retain synthetic R10AC upright, hold and walking replay; never physical proof."""
import argparse
import json
from pathlib import Path
import re

import development_recovery_candidate as candidate
import r10ac_development_launch as launch
import r10ac_development_v2 as identity
import r10ac_host_runtime as host
import r10ac_replay_host as replay
from r10ac_complete_report_component import marker
from r10ac_support_loss_diagnosis import binding, write

ROOT, EVIDENCE = identity.ROOT, identity.EVIDENCE
RECORD = ROOT / 'sdk/recovery/r10ac_phase_report_component_v1.json'
KEY = ROOT / 'sdk/recovery/r10ac_v56_walking_entry_contract_v22.json'
WALK_SUITE = EVIDENCE / 'r10ac-phase-walking-suite-bd885bf09a8c4b509b7400679fbc8172'
HOLD_SUITE = EVIDENCE / 'r10ac-phase-hold-suite-b918904aaa254ceb96ff5a82d077b462'
WALK = EVIDENCE / 'r10ac-complete-phases-9ac98762b2d446d6aa18ee38a136ef75'
HOLD = EVIDENCE / 'r10ac-complete-phases-6e8f9ad6584f438581bdc732b79a3923'
REGRESSION = EVIDENCE / 'r10ac-phase-regression-20e65d36825b4b649f8472cbc747590a'
OLD_WORKER = EVIDENCE / 'r10ab-upright-worker-ab6c786789f34bf1bc87552b20366f86'
SELECTION = EVIDENCE / 'r10ac-selection-check-771925f7d59c4d68ac009a7d264b8fc2'
EARLIER = [EVIDENCE / name for name in (
    'r10ac-phase-suite-48511524ae3443ce8683169cb633c56e',
    'r10ac-complete-phases-3eac12de70a447ec81aa6c43ecf1174e')]
read = lambda p: json.loads(Path(p).read_text(encoding='utf-8-sig'))


def observations():
    key = read(KEY)
    assert candidate.R10AC_ROUTE_ENTRY_PATH == KEY and len(key['bound_source_files']) == 1756
    for row in key['bound_source_files']:
        actual = binding(ROOT / row['path'])
        assert (actual['raw_sha256'], actual['byte_length']) == (row['raw_sha256'], row['byte_length']), row['path']
    prior = {r['path']: r for r in read(ROOT / 'sdk/recovery/r10ac_v56_walking_entry_contract_v20.json')['bound_source_files']}
    current = {r['path']: r for r in key['bound_source_files']}
    assert {p for p in prior if prior[p] != current[p]} == {
        'sdk/conformance/development_recovery_candidate.py',
        'sdk/adapters/godot/gdscript/development_recovery_walking_startup_v1.gd',
        'tests/test_development_r10v_worker_hooks.gd'}
    assert set(current) - set(prior) == {'tests/test_r10ac_complete_phase_fixture.gd',
        'tests/test_r10ac_complete_phases.py', 'sdk/conformance/r10ac_native_audit_component.py',
        'sdk/recovery/r10ac_native_audit_component_v1.json'}
    for folder, count in ((WALK_SUITE, 1), (HOLD_SUITE, 3), (REGRESSION, 1)):
        assert read(folder / 'lock.json')['acquired'] is True
        assert read(folder / 'execution.json')['exit_code'] == 0
        assert re.search(r'Ran ' + str(count) + r' tests? in [\d.]+s\s+OK\s*$',
            (folder / 'stderr.txt').read_text(encoding='utf-8-sig'))
    for folder in (WALK, HOLD):
        assert read(folder / 'source-before.json') == read(folder / 'source-after.json')
    assert read(OLD_WORKER / 'source_before.json') == read(OLD_WORKER / 'source_after.json')
    assert read(OLD_WORKER / 'upright-worker.execution.json')['exit_code'] == 0
    assert (OLD_WORKER / 'upright-worker.stderr.log').read_bytes() == b''
    old = read(OLD_WORKER / 'upright-worker.json')
    assert old['ok'] is True and all(old['checks'].values())
    assert (len(old['entry_packets']), len(old['upright_packets'])) == (240, 63)
    assert old['final_upright_memory']['standing_samples_observed'] == 60
    assert old['world_build_count'] == old['solver_step_count'] == 0
    assert read(SELECTION / 'lock.json')['acquired'] is True
    snapshot = read(SELECTION / 'source-before.json')
    assert snapshot == read(SELECTION / 'source-after.json')
    assert set(current) < {r['path'] for r in snapshot}
    for row in snapshot:
        actual = binding(ROOT / row['path'])
        assert (actual['raw_sha256'], actual['byte_length']) == ('sha256:' + row['sha256'].lower(), row['bytes'])
    for label in ('prepare', 'worker-parse', 'reader-parse', 'report', 'verify'):
        assert read(SELECTION / (label + '.execution.json'))['exit_code'] == 0
        assert (SELECTION / (label + '.stderr.log')).read_bytes() == b''
    selected = read(SELECTION / 'native.json')
    assert selected['ok'] is True and len(selected['checks']) == 30 and all(selected['checks'].values())
    runtime = host.expected_binding()
    assert host.bind_runtime(runtime['images']['godot_console']['path'], runtime['images']['powershell_host']['path']) == runtime
    cases = []
    for branch, folder, count, held in [('upright', HOLD, 575, 0), ('ready', HOLD, 605, 30),
            ('timeout', HOLD, 815, 240), ('walking', WALK, 607, 30)]:
        path = folder / branch
        report = read(path / 'worker_report.json')
        receipt = read(path / 'complete-replay.json')
        assert report['synthetic_test_fixture'] is True and receipt == marker(path / 'replay.stdout.txt')
        assert receipt['ok'] is True and receipt['complete_report_timeline_replayed'] is True
        assert receipt['controller_and_diagnostic_replay_passed'] is True
        assert receipt['input_raw_sha256'] == binding(path / 'worker_report.json')['raw_sha256']
        assert receipt['transition_count'] == report['solver_step_count'] == count
        assert (receipt['entry_observation_count'], receipt['upright_observation_count'], receipt['partial_observation_count']) == (240, 63, 0)
        assert receipt['stance_entry_replay']['replayed_post_recovery_hold_commands'] == held
        contact = replay.independent_result(report, folder / 'synthetic-declaration.json', receipt)
        assert contact == read(path / 'independent-contact-replay.json')
        assert (contact['diagnostic_steps_replayed'], contact['matched_source_contacts'], contact['classification_changes']) == (count, count, 0)
        assert receipt['physical_acceptance_authority'] is receipt['release_authority'] is False
        assert receipt['finite_recovery_task']['cycle_and_stop_boundary_reached'] is False
        for label in ('fixture', 'replay'):
            run = read(path / (label + '.execution.json'))
            assert run['returncode'] == 0 and run['timed_out'] is False
            assert run['world_build_count'] == run['solver_step_count'] == 0
            assert (path / (label + '.stderr.txt')).read_bytes() == b''
        if held:
            assert report['retained_arm']['orchestrator_state']['post_recovery_settling']['outcome'] == ('timeout' if branch == 'timeout' else 'ready')
        if branch == 'walking':
            assert receipt['walking_control_replay']['replayed_walking_steps'] == 2
            assert receipt['walking_contact_validation']['validated_native_contact_steps'] == 2
            measured = read(path / 'finite-task.json')
            assert measured['finite_task_predicates_passed'] is False
            assert measured['predicates']['declared_entry_kind'] is measured['predicates']['planned_cycles'] is False
        cases.append(dict(branch=branch, steps=count, hold_commands=held, walking_commands=2 if branch == 'walking' else 0,
            matched_synthetic_contacts=count, synthetic_classification_changes=0))
    for label, code in [('shutdown', 'R10AB_ENTRY_REPLAY_POST_HOLD_FINALIZATION'),
            ('memory', 'DEVELOPMENT_WALKING_START_INITIAL_MEMORY'), ('capture', 'R10AC_CONTACT_REPORT_RECORD_POPULATION')]:
        path = WALK / 'walking'
        refused = marker(path / (label + '.stdout.txt'))
        assert refused['ok'] is False and refused['failure_code'] == code
        assert refused['input_raw_sha256'] == binding(path / (label + '.json'))['raw_sha256']
        run = read(path / (label + '.execution.json'))
        assert run['returncode'] == 1 and run['timed_out'] is False
        assert (path / (label + '.stderr.txt')).read_bytes() == b''
    assert read(EARLIER[0] / 'execution.json')['exit_code'] == 1
    assert 'R10H_ENTRY_SOURCE_NATIVE_SOURCE' in (EARLIER[0] / 'stderr.txt').read_text()
    assert not launch.CONTRACT.exists() and not list(EVIDENCE.glob('r10ac*consumption*.json'))
    assert not any('r10ac_development' in read(p) for p in EVIDENCE.glob('development-recovery-smoke-*/declaration.json'))
    return dict(ok=True, source_key_inputs=1756, phase_report_tests=4, shared_fixture_regression_tests=1,
        native_selection_checks=30, malformed_walking_report_refusals=3, cases=cases,
        controller_or_runtime_changed=False, synthetic_branch_coverage_only=True,
        complete_physical_route_proven=False, full_workflow_audit_proven=False,
        complete_safety_gate_passed=False, real_population_consumed=False,
        world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)


def capture():
    observed = observations()
    sources = [Path(__file__), ROOT / 'sdk/conformance/r10ac_support_loss_diagnosis.py',
        ROOT / 'sdk/conformance/r10ac_complete_report_component.py', KEY,
        ROOT / 'sdk/recovery/r10ac_v56_walking_entry_contract_v21.json']
    folders = (WALK_SUITE, HOLD_SUITE, WALK, HOLD, REGRESSION, OLD_WORKER, SELECTION, *EARLIER)
    files = [p for folder in folders for p in sorted(folder.rglob('*')) if p.is_file()]
    write(RECORD, dict(schema_version='sporespore_r10ac_phase_report_component_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
            authority_mode='synthetic_phase_report_replay_checks', question_class='development'),
        source_bindings=[binding(p) for p in sources], retained_evidence=[binding(p) for p in files], observed=observed,
        scope='The selected R10AC worker and actual controller sessions publish synthetic upright, ready-hold, timeout and fresh-walking reports. Native combined replay and independent Python contact replay agree at every retained step.',
        retained_failure='v21 direct upright passed, then walking refused because the new synthetic source builder replaced the native post-step identity. v22 merges diagnostic fields into that supplied identity; the failed record is retained unchanged.',
        limits='All poses and contact-frame packets are supplied synthetic fixtures. Two fresh walking commands cover session handoff and retention, not complete cycles or stop. The required physical entry kind is partial; these upright counterfactuals do not satisfy it or characterize phase 248. No physical workflow audit, full safety qualification, repair or acceptance proof is claimed.',
        next_action='Exercise the complete final workflow audit and assemble/pass the full applicable safety graph; then freeze and execute the fresh contact-frame diagnostic. SDK1 remains 14/20.'))
    return observed


def audit():
    record = read(RECORD)
    for row in record['source_bindings'] + record['retained_evidence']:
        assert binding(row['path']) == row, row['path']
    observed = observations(); assert observed == record['observed']
    return observed


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('--capture', action='store_true')
    print('R10AC_PHASE_REPORT_COMPONENT ' + json.dumps(capture() if parser.parse_args().capture else audit()), flush=True)
