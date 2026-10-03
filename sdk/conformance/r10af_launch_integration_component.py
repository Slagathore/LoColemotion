"""Audit zero-world R10AF launch integration; full safety qualification is separate."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

import r10af_report_integration_component as previous
import r10af_context_handoff as handoff
from r10ae_replay_invalid_closure import ROOT, EVIDENCE, read, bind, write_new

RECORD = ROOT / 'sdk/recovery/r10af_launch_integration_component_v1.json'
PARENT = 'fd23210e4a00e955cc189b176ea843990838fd71'
CHECKS = {
    'reservation': 'r10af-launch-guard-7379fdbd0ed14a2090e0b3ab950bba97',
    'authority': 'r10af-launch-guard-27868ae9aa354382a1e83a9a1213ad5e',
    'host': 'r10af-host-check-96a16ab502b44103af7febe57da261b7',
    'header': 'r10af-smoke-reader-5ce687af0cb94c228e3de8242edc9c26',
    'retention': 'r10af-retention-check-02e703a56ad4451a85dc81b6f850d732',
    'handoff': 'r10af-handoff-0095a551b5e3458f9696bdb7799d74f9',
    'interfaces': 'r10af-native-interfaces-8ac40a90526943f9ad0868291b96d96e',
    'workflow': 'r10af-workflow-audit-469e09db44c74c3ca504131d81d5fc67',
    'runtime': 'development-r10ab-runtime-1ecd3951ea8b4ce09c7c86e9e636d60a',
    'pre_world': 'r10af-pre-world-check-454515b7814c41f0bfce22d2b2d71e9b',
    'startup': 'r10af-startup-preflight-99398c2c3b8c4be7ad80dbfce8294efc',
}
CLAIMS = dict(production_context_handoff_proven=True, synthetic_audit_dispatch_proven=True,
    complete_safety_gate_qualified=False, physical_attempt_started_at_checkpoint=False,
    physical_execution_authorized=False, physical_acceptance_authority=False, release_authority=False,
    world_build_count=0, solver_step_count=0, sdk1_score='14/20', full_program_score='14/25')


def historical_reports():
    """The prior record is checked against its own source, never silently refreshed."""
    record = read(previous.RECORD)
    for value in [bind(previous.RECORD), record['auditor'], *record['bindings']]:
        path = Path(value['path'])
        if path.is_relative_to(ROOT):
            raw = subprocess.check_output(['git', 'cat-file', 'blob', PARENT + ':' + path.relative_to(ROOT).as_posix()], cwd=ROOT)
            variants = [raw] if b'\r\n' in raw else [raw, raw.replace(b'\n', b'\r\n')]
            assert any(len(data) == value['byte_length'] and 'sha256:' + hashlib.sha256(data).hexdigest() == value['raw_sha256'] for data in variants), path
        else:
            assert bind(path) == value, path
    assert record['claim_boundary'] == previous.CLAIMS
    return dict(ok=True, source_commit=PARENT, component=bind(previous.RECORD),
        original_component_reclassified=False, current_source_qualification=False)


def observations():
    roots = {key: EVIDENCE / name for key, name in CHECKS.items()}
    for key, root in roots.items():
        before, after = ('source_before.json', 'source_after.json') if key in ('reservation', 'authority', 'retention') else ('r10af-source-before.json', 'r10af-source-after.json') if key == 'runtime' else ('source-before.json', 'source-after.json')
        assert read(root / before) == read(root / after), key
    declaration = read(roots['handoff'] / 'declaration.json')
    producer = read(roots['handoff'] / 'r10af_context_production/producer.json')
    assert handoff.expectation(producer) == declaration['prepared_context_expectation']
    handoff.validate_consumer(read(roots['handoff'] / 'r10af_pre_world_consumption/consumer.json'), declaration)
    for name in ('r10af_context_producer.json', 'r10af_pre_world_receipt.json'):
        receipt = read(roots['handoff'] / name)
        handoff.zero(receipt)
        for item in receipt['artifacts']: assert bind(item['path']) == item
    retention = read(roots['retention'] / 'result.json')
    assert retention['ok'] is True and len(retention['cases']) == 11 and all(row['passed'] for row in retention['cases'])
    selection = read(roots['interfaces'] / 'selection/verification.json')
    assert selection['ok'] is True and selection['native_checks'] == 30
    dispatch = read(roots['workflow'] / 'synthetic-dispatch-result.json')
    assert dispatch['synthetic_workflow_only'] is True and dispatch['actual_physical_attempt'] is False
    assert dispatch['result']['ok'] is True
    diagnostic = dispatch['result']['r10af_contact_frame_diagnostic']
    assert diagnostic['all_tasks_positive'] is False and diagnostic['physical_acceptance_authority'] is False
    assert diagnostic['contact_frame_replay']['controller_observation_changed'] is True
    pre_world = read(roots['pre_world'] / 'result.json')
    assert pre_world['ok'] is True and pre_world['independent_native_processes'] == 5 and pre_world['population_reserved'] is False
    startup = read(roots['startup'] / 'result.json')
    assert startup['ok'] is True and startup['owned_dirty_source_refused'] is True and startup['native_preflight_passed'] is False
    return dict(native_selection_checks=30, retention_controls=11, independent_pre_world_processes=5,
        context_producer_consumer_agree=True, synthetic_negative_preserved=True,
        owned_dirty_startup_refused=True, clean_startup_success_pending=True,
        source_unchanged_during_each_check=True)


def audit(record):
    assert record['claim_boundary'] == CLAIMS
    for item in record['bindings'] + [record['auditor']]: assert bind(item['path']) == item, item['path']
    assert record['historical_report_integration'] == historical_reports()
    assert record['observed'] == observations()
    return dict(ok=True, **record['observed'], **CLAIMS)


def create():
    assert not RECORD.exists()
    names = subprocess.check_output(['git', 'diff', '--name-only', 'HEAD'], cwd=ROOT, text=True).splitlines()
    names += subprocess.check_output(['git', 'ls-files', '--others', '--exclude-standard'], cwd=ROOT, text=True).splitlines()
    # Admission pointers will advance to include this record. Their exact earlier
    # values remain in retained snapshots; the full gate qualifies the final key.
    selectors = {'sdk/conformance/development_recovery_candidate.py', 'sdk/adapters/godot/gdscript/development_recovery_walking_startup_v1.gd'}
    paths = {ROOT / name for name in names if Path(name).suffix in ('.py', '.gd', '.ps1') and name not in selectors}
    paths.add(ROOT / 'sdk/development/r10af_safety_stage_contract_v1.json')
    for name in CHECKS.values(): paths.update(p for p in (EVIDENCE / name).rglob('*') if p.is_file())
    record = dict(schema_version='sporespore_r10af_launch_integration_component_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='zero_world_launch_integration', question_class='development'),
        auditor=bind(__file__), bindings=[bind(p) for p in sorted(paths)],
        historical_report_integration=historical_reports(), observed=observations(), claim_boundary=CLAIMS,
        focused_test_run=dict(integration_tests_passed=59, runtime_and_pre_world_tests_passed=5,
            integration_elapsed_seconds=510.704, runtime_and_pre_world_elapsed_seconds=130.859,
            provenance='Observed unittest terminal results; individual retained artifacts are independently checked here. These component runs are not a complete safety gate.'),
        coverage_limits=[
            'Real context initialization reaches intercepted construction; no physical observer-to-controller path was executed.',
            'Reservation and claim tests use isolated synthetic namespaces. Real population remains unreserved at this checkpoint.',
            'Workflow authentication and cold-replay transport are explicitly doubled; native interfaces and prior complete synthetic report coverage are separate.',
            'Admission selectors may advance after component tests. Full 65-stage/239-test safety execution on the final clean pushed source is mandatory.',
            'A positive diagnostic would still require fresh paired commissioning, official qualification, held-out acceptance and M07 adoption.'])
    result = audit(record); write_new(RECORD, record); return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--create', action='store_true'); parser.add_argument('--historical-reports', action='store_true')
    args = parser.parse_args()
    print(json.dumps(historical_reports() if args.historical_reports else create() if args.create else audit(read(RECORD))))
