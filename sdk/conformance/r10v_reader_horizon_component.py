"""Audit the original pre-physics gate refusal and corrected reader evidence."""
import argparse
import json
import re
from pathlib import Path
import r10t_route_integration_component as b
import r10v_production_host_component as units

ROOT, EVIDENCE = b.ROOT, b.EVIDENCE
RECORD = ROOT/'sdk/recovery/r10v_reader_horizon_component_v1.json'
DIRECTORY = EVIDENCE/'r10v-reader-horizon-component-d1426a37c9824c378f8381ba06d45c5d'
REGRESSION = EVIDENCE/'r10v-horizon-regression-5dd3f058cc4c41c89553e1ad6a6f09e2'
PREPARATION = EVIDENCE/'r10v-horizon-preparation-0b24ebdf32ef455bad74cba488347660'
FIXTURE = EVIDENCE/'development-r10v-preparation-report-de682de3af944eab878635b737300825'
CLAIMS = dict(reader_schema_dispatch_corrected=True, complete_safety_gate_passed=False,
    physical_attempt_started=False, world_build_count=0, solver_step_count=0,
    controller_or_dll_changed=False, physical_limits_changed=False,
    original_attempt_reclassified=False, physical_acceptance_authority=False,
    release_authority=False, sdk1_score='14/20', full_program_score='14/25')


def observed():
    failure = b.read(DIRECTORY/'failed_gate.json')
    for name in ('host','supervisor','prehost'): b.verify(failure[name])
    supervisor = b.read(failure['supervisor']['path'])
    assert not supervisor['ok'] and not supervisor['physical_attempt_started']
    assert supervisor['failure_code'] == 'SMOKE_SAFETY_GATE_FAILED:r10v_preparation_refusals'
    stages = supervisor['safety_stages']
    assert len(stages) == 38 and all(s['passed'] for s in stages[:37])
    assert sum(s['test_count'] for s in stages[:37]) == 116
    assert stages[-1]['test_count'] == 0 and not stages[-1]['timed_out']
    original = Path(failure['supervisor']['path']).parent
    assert "KeyError: 'maximum_v50_walking_commands'" in (original/stages[-1]['stderr']).read_text(encoding='utf-8')
    host = b.read(failure['host']['path'])
    assert not host['ok'] and host['owned_cleanup_complete'] and host['source_unchanged']
    units.lifecycle(Path(failure['host']['path']).parent)
    units.unit(REGRESSION,20,0)
    run = b.read(PREPARATION/'execution.json'); stage = b.read(PREPARATION/'stage.json')
    assert run['passed'] and run['source_unchanged']
    assert stage['passed'] and stage['test_count'] == 2 and stage['exit_code'] == 0 and not stage['timed_out']
    assert b.read(PREPARATION/'source_before.json') == b.read(PREPARATION/'source_after.json')
    for stream in ('stdout','stderr'):
        assert b.bind(PREPARATION/stage[stream])['raw_sha256'] == 'sha256:'+stage[stream+'_sha256']
    log = (PREPARATION/stage['stderr']).read_text(encoding='utf-8')
    assert re.findall(r'^Ran (\d+) tests in ',log,re.M) == ['2'] and log.rstrip().endswith('OK')
    before = b.read(FIXTURE/'source_before.json')
    assert before == b.read(FIXTURE/'source_after.json') == b.read(FIXTURE/'setup_source_after.json')
    replay = b.read(FIXTURE/'replay-result.json')
    assert replay['ok'] and replay['complete_report_timeline_replayed'] and replay['transition_count'] == 611
    stance = replay['stance_entry_replay']
    assert (stance['replayed_neutral_commands'],stance['replayed_hold_commands'],stance['recomputed_readiness_samples']) == (166,171,337)
    assert len(b.read(FIXTURE/'refusals.json')) == 8
    assert not b.read(FIXTURE/'finite-task-measurement.json')['finite_task_predicates_passed']
    for root in (REGRESSION, PREPARATION):
        lock = b.read(root/'operation_lock.json')
        assert lock['acquired'] and not lock['test_only'] and lock['role'] == 'conformance'
    return dict(original_passed_stages=37, original_passed_tests=116,
        original_failure='missing_R10V_schema_in_shared_walking_horizon_dispatch',
        focused_regressions_passed=20, preparation_tests_passed=2,
        preparation_refusals=8, preparation_replayed_transitions=611,
        preparation_stage_seconds=stage['seconds'], corrected_source_unchanged=True)


def audit(record):
    assert record['claim_boundary'] == CLAIMS
    for item in (record['auditor'], record['failed_manifest'], record['corrected_manifest']): b.verify(item)
    for name in ('failed_manifest','corrected_manifest'):
        for item in b.read(record[name]['path'])['files']: b.verify(item)
    for archive in record['source_archives']:
        b.verify(archive['key']); b.verify(archive['snapshot'])
        for item in b.read(archive['key']['path'])['bound_source_files']:
            assert b.bind(Path(archive['directory'])/item['path'])['raw_sha256'] == item['raw_sha256']
    assert record['observed'] == observed()
    return dict(ok=True, **record['observed'], **CLAIMS)


def create():
    assert not RECORD.exists()
    observation = observed()
    manifest = DIRECTORY/'corrected_manifest.json'
    files = {p for root in (REGRESSION,PREPARATION,FIXTURE) for p in root.rglob('*') if p.is_file()}
    b.write_new(manifest,dict(files=[b.bind(p) for p in sorted(files)]))
    record = dict(schema_version='sporespore_r10v_reader_horizon_component_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='zero_world_reader_correction',question_class='development'),
        auditor=b.bind(__file__), failed_manifest=b.bind(DIRECTORY/'failed_gate_manifest.json'),
        corrected_manifest=b.bind(manifest),
        source_archives=[b.read(DIRECTORY/name) for name in ('failed_source_archive.json','corrected_source_archive.json')],
        observed=observation, claim_boundary=CLAIMS,
        interpretation='The original v15 gate stopped before physics after 37 passing stages. The shared finite-walking reader now recognizes the unchanged R10V task schema and reads its existing maximum_walking_commands bound. The v16 component passes 20 regressions and both complete native preparation tests with eight corruption refusals. The original failure and both source archives remain retained. Focused regressions have original logs and lock but no outer before/after snapshot; preparation has both full snapshots.',
        next='Fresh complete source key and clean pushed freeze, fresh prehost receipts and the full 66-stage 258-test gate before any physical reservation.')
    audit(record)
    with RECORD.open('x',encoding='utf-8',newline='\r\n') as stream:
        json.dump(record,stream,indent=2); stream.write('\n')
    return audit(record)


if __name__ == '__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('--create',action='store_true')
    print(json.dumps(create() if parser.parse_args().create else audit(b.read(RECORD))))
