"""Audit zero-world R10AG launch integration; full safety qualification is separate."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

import r10ag_report_integration_component as previous
import r10ag_context_handoff as handoff
from r10ae_replay_invalid_closure import ROOT, EVIDENCE, read, bind, write_new

RECORD = ROOT / 'sdk/recovery/r10ag_launch_integration_component_v1.json'
PARENT = '61affb3d952c2d60657cfed2346f939aa0a4c378'

CLAIMS = dict(production_context_handoff_proven=True, synthetic_audit_dispatch_proven=True,
    complete_safety_gate_qualified=False, physical_attempt_started_at_checkpoint=False,
    physical_execution_authorized=False, physical_acceptance_authority=False, release_authority=False,
    world_build_count=0, solver_step_count=0, sdk1_score='14/20', full_program_score='14/25')


def historical_reports():
    """The prior record is checked against its own source, never silently refreshed."""
    raw_record = subprocess.check_output(['git', 'cat-file', 'blob', PARENT + ':' + previous.RECORD.relative_to(ROOT).as_posix()], cwd=ROOT)
    assert json.loads(raw_record) == read(previous.RECORD)
    record = read(previous.RECORD)
    for value in [bind(previous.RECORD), record['auditor'], *record['bindings']]:
        path = Path(value['path'])
        if path.is_relative_to(ROOT) and bind(path) != value:
            raw = subprocess.check_output(['git', 'cat-file', 'blob', PARENT + ':' + path.relative_to(ROOT).as_posix()], cwd=ROOT)
            variants = [raw] if b'\r\n' in raw else [raw, raw.replace(b'\n', b'\r\n')]
            assert any(len(data) == value['byte_length'] and 'sha256:' + hashlib.sha256(data).hexdigest() == value['raw_sha256'] for data in variants), path
        else:
            assert bind(path) == value, path
    assert record['claim_boundary'] == previous.CLAIMS
    return dict(ok=True, source_commit=PARENT, component=bind(previous.RECORD),
        original_component_reclassified=False, current_source_qualification=False)


def observations(checks):
    roots = {key: EVIDENCE / name for key, name in checks.items()}
    assert set(roots) == {"reservation", "authority", "host", "header", "retention", "handoff", "interfaces", "workflow", "runtime", "pre_world", "startup"}
    assert all(root.resolve().parent == EVIDENCE.resolve() for root in roots.values())
    for key, root in roots.items():
        before, after = ('source_before.json', 'source_after.json') if key in ('reservation', 'authority', 'retention') else ('r10ag-source-before.json', 'r10ag-source-after.json') if key == 'runtime' else ('source-before.json', 'source-after.json')
        assert read(root / before) == read(root / after), key
    declaration = read(roots['handoff'] / 'declaration.json')
    producer = read(roots['handoff'] / 'r10ag_context_production/producer.json')
    assert handoff.expectation(producer) == declaration['prepared_context_expectation']
    handoff.validate_consumer(read(roots['handoff'] / 'r10ag_pre_world_consumption/consumer.json'), declaration)
    for name in ('r10ag_context_producer.json', 'r10ag_pre_world_receipt.json'):
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
    diagnostic = dispatch['result']['r10ag_contact_frame_diagnostic']
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


def test_runs(batches):
    import re
    statuses = {}
    retained = []
    for name in batches:
        root = EVIDENCE / name
        assert root.resolve().parent == EVIDENCE.resolve()
        raw = (root / 'stderr.log').read_bytes()
        text = raw.decode('utf-16' if raw.startswith(b'\xff\xfe') else 'utf-8-sig').replace('\r\n', '\n')
        rows = re.findall(r'^(test_\S+) \(([^)]+)\) \.\.\. (ok|FAIL|ERROR)$', text, re.M)
        assert rows and re.search(r'Ran \d+ tests in ', text)
        for _, identity, status in rows: statuses[identity] = status
        retained.append(dict(root=root.as_posix(), log=bind(root / 'stderr.log'), observed_tests=len(rows)))
    failures = {key: value for key, value in statuses.items() if value != 'ok'}
    assert failures == {'test_r10ag_native_startup_gate.R10AGNativeStartupGate.test_clean_native_helper_preflight_before_reservation': 'FAIL'}, failures
    assert len(statuses) == 79 and len(statuses) - len(failures) == 78
    return dict(retained_batches=retained, distinct_tests_passed=78,
        dirty_tree_clean_startup_refusal_retained=True, clean_startup_success_pending=True,
        component_runs_span_explicit_source_snapshots=True, complete_safety_gate=False)


def audit(record):
    assert record['claim_boundary'] == CLAIMS
    for item in record['bindings'] + [record['auditor']]: assert bind(item['path']) == item, item['path']
    assert record['historical_report_integration'] == historical_reports()
    assert record['observed'] == observations(record['evidence_roots'])
    assert record['test_runs'] == test_runs(record['batch_roots'])
    return dict(ok=True, **record['observed'], **CLAIMS)


def create(inputs):
    inputs = read(inputs)
    checks, batches = inputs["checks"], inputs["batches"]
    assert not RECORD.exists()
    names = subprocess.check_output(['git', 'diff', '--name-only', 'HEAD'], cwd=ROOT, text=True).splitlines()
    names += subprocess.check_output(['git', 'ls-files', '--others', '--exclude-standard'], cwd=ROOT, text=True).splitlines()
    # Admission pointers will advance to include this record. Their exact earlier
    # values remain in retained snapshots; the full gate qualifies the final key.
    selectors = {'sdk/conformance/development_recovery_candidate.py', 'sdk/adapters/godot/gdscript/development_recovery_walking_startup_v1.gd'}
    paths = {ROOT / name for name in names if Path(name).suffix in ('.py', '.gd', '.ps1') and name not in selectors}
    # Complete applicable safety graph has not been declared at this checkpoint.
    assert not (ROOT / 'sdk/development/r10ag_safety_stage_contract_v1.json').exists()
    paths.update((ROOT / "sdk/recovery").glob("r10ag_v56_walking_entry_contract_v*.json"))
    for name in [*checks.values(), *batches, *inputs["history"]]: paths.update(p for p in (EVIDENCE / name).rglob('*') if p.is_file())
    record = dict(schema_version='sporespore_r10ag_launch_integration_component_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='zero_world_launch_integration', question_class='development'),
        auditor=bind(__file__), bindings=[bind(p) for p in sorted(paths)],
        historical_report_integration=historical_reports(), observed=observations(checks), claim_boundary=CLAIMS,
        evidence_roots=checks, batch_roots=batches, retained_development_history=inputs["history"], test_runs=test_runs(batches),
        coverage_limits=[
            'Real context initialization reaches intercepted construction; no physical observer-to-controller path was executed.',
            'Reservation and claim tests use isolated synthetic namespaces. Real population remains unreserved at this checkpoint.',
            'Workflow authentication and cold-replay transport are explicitly doubled; native interfaces and prior complete synthetic report coverage are separate.',
            'Admission selectors may advance after component tests. The full applicable V23 safety graph remains undeclared; its complete execution on a clean pushed source is mandatory.',
            'A positive diagnostic would still require fresh paired commissioning, official qualification, held-out acceptance and M07 adoption.'])
    result = audit(record); write_new(RECORD, record); return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--create', type=Path); parser.add_argument('--historical-reports', action='store_true')
    args = parser.parse_args()
    print(json.dumps(historical_reports() if args.historical_reports else create(args.create) if args.create else audit(read(RECORD))))
