"""Retain the interrupted R10U pair; missing original receipts grant no credit."""
import argparse
import json
from pathlib import Path
import uuid
import r10t_route_integration_component as base
import r10u_development_launch as launch
from r10t_initial_invalid_closure import root_scalars

ROOT, EVIDENCE = base.ROOT, base.EVIDENCE
RUN = EVIDENCE/'development-recovery-smoke-2e83ffbb9cb84fb1ba1dfc2c76886f37'
OUTER = EVIDENCE/'r10u-full-gate-af9b30d330b64519b2a8266e98a5bf0c'
RECORD = ROOT/'sdk/recovery/r10u_phase245_interrupted_pair_closure_v1.json'
KEY = ROOT/'sdk/recovery/r10u_v56_walking_entry_contract_v14.json'
COMPONENT = EVIDENCE/'r10u-startup-budget-component-59f3f8e3dcfd429f9be62212678e5f22/component.json'
HEAD = '7f7b8296f9d7a52b03f2052fa7accddcf835668e'
ROLES = {'matched_no_kick_continuation': (0,1749), 'kick_passive_recovery_resume': (1,2315)}
CLAIMS = dict(original_attempt_classification='consumed_infrastructure_incomplete',
    original_attempt_reclassified=False, r10u_development_chain_closed=True,
    r10u_pair_or_later_diagnostics_authorized=False, original_full_audit_passed=False,
    finite_physical_positivity_established=False, interruption_cause='unknown',
    held_out_population_declared=False, physical_acceptance_authority=False,
    release_authority=False, sdk1_score='14/20', full_program_score='14/25')


def missing_paths():
    paths = [RUN/name for name in ('supervisor_result.json','independent_audit.stdout.json','published_marker.txt')]
    paths.append(OUTER/'execution.json')
    for role in ROLES:
        paths.extend(RUN/'children'/role/name for name in
            ('passive_entry_replay_result.json','passive_entry_replay/execution.json'))
    return paths


def observed():
    # Never synthesize the missing terminal records or restart the consumed pair.
    assert all(not p.exists() for p in missing_paths()), 'ORIGINAL_TERMINAL_STATE_CHANGED'
    declaration = base.read(RUN/'declaration.json')
    assert declaration['source_snapshot'] == dict(head=HEAD,dirty=False,status=[],changed_file_bindings=[])
    assert declaration['seed'] == 41245 and declaration['timeout_seconds_per_child'] == 1740
    assert len(declaration['safety_stages']) == 64
    assert sum(s['test_count'] for s in declaration['safety_stages']) == 229
    assert launch.verify(RUN/'declaration.json')['ok']
    cells = []
    ids = set()
    for role,(kicks,steps) in ROLES.items():
        child = RUN/'children'/role
        with (child/'child_envelope.json').open(encoding='utf-8') as stream:
            prefix, separator, _ = stream.read(12000).partition('"report":')
        assert separator
        envelope = json.loads(prefix+'"report":null}')
        identity = base.read(child/'child_attempt_identity.json')
        assert envelope['role'] == identity['role'] == role
        assert envelope['child_attempt_id'] == identity['child_attempt_id']
        assert identity['child_attempt_id'] not in ids
        ids.add(identity['child_attempt_id'])
        assert envelope['exit_code'] == 0
        assert all(envelope[k] is True for k in ('termination_protocol_valid','engine_health_passed','raw_marker_valid'))
        assert envelope['child_retry_count'] == envelope['child_replacement_count'] == 0
        assert base.read(child/'engine_health.json')['passed'] is True
        assert (child/'worker.stderr.txt').stat().st_size == 0
        counts = root_scalars(child/'worker_report.json',
            ['world_build_count','external_kick_application_count','solver_step_count','seed','stop_reason'])
        assert counts == dict(world_build_count=1,external_kick_application_count=kicks,
            solver_step_count=steps,seed=41245,stop_reason='diagnostic_cycle_aligned_stop_complete')
        cells.append(dict(role=role,child_attempt_id=identity['child_attempt_id'],
            native_exit_code=0,termination_protocol_valid=True,engine_health_passed=True,
            started_utc=envelope['started_utc'],completed_utc=envelope['completed_utc'],**counts))
    return dict(complete_safety_gate_passed=True,safety_stages=64,safety_tests=229,
        source_commit=HEAD,seed=41245,prefix_phase=245,physical_worlds=2,physical_kicks=1,
        total_physical_solver_steps=4064,cells=cells,
        missing_original_receipts=[p.as_posix() for p in missing_paths()])


def audit(record):
    assert record['claim_boundary'] == CLAIMS
    for item in record['bindings']+[record['auditor'],record['manifest']]: base.verify(item)
    manifest = base.read(record['manifest']['path'])
    expected = {x['path'] for x in manifest['files']}
    actual = {p.as_posix() for root in (RUN,OUTER) for p in root.rglob('*') if p.is_file()}
    assert actual == expected, 'ORIGINAL_FILE_INVENTORY_CHANGED'
    for item in manifest['files']: base.verify(item)
    archive = record['source_archive']
    base.verify(archive['key']); base.verify(archive['snapshot'])
    for item in base.read(archive['key']['path'])['bound_source_files']:
        assert base.bind(Path(archive['directory'])/item['path'])['raw_sha256'] == item['raw_sha256']
    assert record['observed'] == observed()
    return dict(ok=True,**record['observed'],**CLAIMS)


def create():
    assert not RECORD.exists()
    result = observed()
    directory = EVIDENCE/('r10u-interrupted-pair-closure-'+uuid.uuid4().hex)
    directory.mkdir()
    manifest = directory/'manifest.json'
    base.write_new(manifest,dict(schema_version='sporespore_r10u_interrupted_pair_retention_v1',
        files=[base.bind(p) for root in (RUN,OUTER) for p in sorted(root.rglob('*')) if p.is_file()]))
    archive = base.read(COMPONENT)['source_archive']
    assert archive['key'] == base.bind(KEY)
    record = dict(schema_version='sporespore_r10u_phase245_interrupted_pair_closure_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',
            authority_mode='consumed_infrastructure_incomplete_closure',question_class='development'),
        auditor=base.bind(__file__),manifest=base.bind(manifest),source_archive=archive,
        evidence_root=RUN.as_posix(),outer_root=OUTER.as_posix(),source_commit=HEAD,
        bindings=[base.bind(p) for p in [COMPONENT,KEY,
            EVIDENCE/'r10u_first_pair_consumption_v1.json',ROOT/'sdk/recovery/r10u_audit_handoff_design_v1.json']],
        observed=result,claim_boundary=CLAIMS,
        interpretation='The original supervisor disappeared without terminal supervisor, independent audit or publication receipts. Both native children retained exit-zero envelopes and cycle-aligned stop reports. Their finite predicates and full workflow were not independently established. The consumed design requires an original successful supervisor and audit; its entire development chain is closed. Any later retained-data diagnosis must use separate output and cannot restore this attempt or authorize its branches. The cause of the interruption is not established.')
    audit(record)
    base.write_new(RECORD,record)
    return dict(ok=True,record=base.bind(RECORD),**result,**CLAIMS)


if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--create',action='store_true')
    args=parser.parse_args()
    print(json.dumps(create() if args.create else audit(base.read(RECORD))))
