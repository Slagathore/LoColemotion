"""Audit retained production-host component evidence, never launch a world."""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import re
import r10t_route_integration_component as base
import r10v_windows_job as win

ROOT, EVIDENCE = base.ROOT, base.EVIDENCE
RECORD = ROOT/'sdk/recovery/r10v_production_host_component_v1.json'
DIRECTORY = EVIDENCE/'r10v-production-host-component-33cfc9ca767b4070a5e46f2201de6a6a'
SUITE = EVIDENCE/'r10v-production-host-controls-5e9df3eb39724ac09e2bac3602b4eaf8'
CURRENT = EVIDENCE/'r10v-production-host-check-260a9fbdeadc4cc891ac9492498fde0e'
REGRESSION = EVIDENCE/'r10v-host-integration-check-e5f8c6a4c4454f598d2c58b3d366bfb4'
PRIOR = [EVIDENCE/name for name in (
    'r10v-production-host-check-7432bffb7fd04c8abb000d7f30de9d17',
    'r10v-production-host-check-006e63c734db41cba508d81623e3e276',
    'r10v-production-host-check-fa35b8435c634a8a9407c12b5cee5d75')]
CLAIMS = dict(production_host_implemented=True,production_library_interface_verified=True,
    complete_production_gate_executed=False,complete_pair_final_auditor_qualified=False,
    physical_launch_authorizer_closed=True,physical_attempt_started=False,
    world_build_count=0,solver_step_count=0,native_controller_changed=False,native_dll_changed=False,
    original_attempt_reclassified=False,physical_acceptance_authority=False,release_authority=False,
    sdk1_score='14/20',full_program_score='14/25')


def snapshot(root):
    value = base.read(root/'source_before.json')
    assert value == base.read(root/'source_after.json')
    assert value['head'] == '043e1d39ab98fc2edfd653f4ed9cc4a09813aa45'
    assert value['remote'] == 'https://github.com/Slagathore/sporespore.git'
    for item in value['changed_files']:
        assert not item['deleted']
        assert 'sha256:'+hashlib.sha256(base64.b64decode(item['replacement_base64'],validate=True)).hexdigest() == item['raw_sha256']
    return value


def unit(root,count,failures):
    assert base.read(root/'execution.json')['exit_code'] == (1 if failures else 0)
    log = (root/'stderr.log').read_text(encoding='utf-8-sig')
    assert re.findall(r'^Ran (\d+) tests? in ',log,re.M) == [str(count)]
    assert len(re.findall(r'^test_.* \.\.\. ok$',log,re.M)) == count-failures
    assert not re.findall(r'^ERROR:',log,re.M)
    assert log.rstrip().endswith('FAILED (failures=1)' if failures else 'OK')


def lifecycle(root):
    """Read original terminal artifacts without borrowing current host source."""
    request = base.read(root/'request.json')
    started = base.read(root/'host_started.json')
    assigned = base.read(root/'job_assigned.json')
    assert started['request'] == assigned['request'] == base.bind(root/'request.json')
    assert started['host_identity'] == assigned['host_identity']
    assert started['in_caller_job'] is False and assigned['kill_on_job_close'] is True
    for identity in (assigned['host_identity'],assigned['worker_identity']):
        assert not win.alive(identity), 'OWNED_PROCESS_STILL_ALIVE'
    supervisor = root/'supervisor_started.json'
    if supervisor.exists():
        assert not win.alive(base.read(supervisor)['supervisor_identity'])
    terminal = root/'host_result.json'
    if terminal.exists():
        result = base.read(terminal)
        assert result['schema_version'] == 'sporespore_r10v_durable_host_result_v2'
        assert result['request'] == base.bind(root/'request.json')
        assert result['host_identity'] == assigned['host_identity'] and result['owned_cleanup_complete'] is True
        assert result['physical_acceptance_authority'] is False and result['release_authority'] is False
        for item in result['logs']+[result[k] for k in ('primary_terminal','progress_log') if result.get(k)]:
            base.verify(item)
        assert base.read(root/'published.json') == dict(request=base.bind(root/'request.json'),
            host_identity=assigned['host_identity'],host_result=base.bind(terminal))
        state = 'complete' if result['ok'] else 'failed'
        if result['ok']:
            assert result['source_unchanged'] and result['worker_exit_code'] == 0
            primary = base.read(result['primary_terminal']['path'])
            assert primary['ok'] and primary['world_build_count'] == primary['solver_step_count'] == 0
    else:
        assert not (root/'published.json').exists()
        state = 'incomplete'
    return dict(root=root.as_posix(),lane=request['lane'],case=request['probe_case'],state=state)


def observed():
    for root,count in zip(PRIOR,(1,1,23),strict=True): unit(root,count,1)
    unit(CURRENT,24,0); unit(REGRESSION,25,0)
    snapshot(SUITE)
    children = base.children(REGRESSION)-{REGRESSION}
    assert len(children) == 4
    for root in children: snapshot(root)
    lock = base.read(REGRESSION/'operation_lock.json')
    assert lock['acquired'] and not lock['test_only'] and not lock['abandoned_owner_recovered']
    result = base.read(SUITE/'result.json')
    assert result['ok'] and result['tests'] == 24 and result['failures'] == result['errors'] == 0
    assert result['source_unchanged'] and result['world_build_count'] == result['solver_step_count'] == 0
    actual = [lifecycle(Path(name)) for name in result['roots'] if (Path(name)/'job_assigned.json').exists()]
    assert len(actual) == 13
    assert [sum(x['state']==s for x in actual) for s in ('complete','failed','incomplete')] == [3,9,1]
    interface = next(Path(x['root']) for x in actual if x['lane']=='production_interface_probe' and x['case']=='success')
    rows = [json.loads(line) for line in (interface/'progress.jsonl').read_text().splitlines()]
    assert [(r['stage'],r['state']) for r in rows] == [('interface','start'),('interface','end'),('interface_python','start'),('interface_python','end')]
    assert [r['sequence'] for r in rows] == list(range(4))
    assert all(r['context']==base.read(interface/'supervisor_context.json') for r in rows)
    return dict(host_controls_passed=24,launcher_population_deadline_regressions_passed=25,
        real_host_lifecycles=13,complete_lifecycles=3,expected_failure_lifecycles=9,
        deliberate_host_loss_incomplete=1,prior_failed_runs_retained=3,source_unchanged_during_tests=True,
        live_owned_hosts_workers_and_supervisors=0,actual=actual)


def audit(record):
    assert record['claim_boundary'] == CLAIMS
    for item in (record['auditor'],record['manifest']): base.verify(item)
    for item in base.read(record['manifest']['path'])['files']: base.verify(item)
    for archive in record['source_archives']:
        base.verify(archive['key']); base.verify(archive['snapshot'])
        for item in base.read(archive['key']['path'])['bound_source_files']:
            assert base.bind(Path(archive['directory'])/item['path'])['raw_sha256'] == item['raw_sha256']
        guard = (Path(archive['directory'])/'sdk/conformance/r10v_development_launch.py').read_text()
        assert "require(False, 'PRODUCTION_HOST_INTEGRATION_PENDING')" in guard
    assert record['observed'] == observed()
    return dict(ok=True,**record['observed'],**CLAIMS)


def create():
    assert not RECORD.exists()
    observation = observed()
    archives = [base.read(DIRECTORY/n) for n in ('source_archive.json','regression_source_archive.json')]
    roots = {CURRENT,REGRESSION,SUITE,*PRIOR}
    for root in list(roots): roots.update(base.children(root))
    # Include every original lifecycle, including failed predecessor source revisions.
    for root in list(roots):
        path = root/'lifecycle_roots.json'
        if path.exists():
            values = base.read(path)
            roots.update(Path(p) for p in (values['roots'] if isinstance(values,dict) else values))
    paths = {p for root in roots|{DIRECTORY} for p in root.rglob('*') if p.is_file()}
    manifest = DIRECTORY/'manifest.json'
    base.write_new(manifest,dict(files=[base.bind(p) for p in sorted(paths)]))
    record = dict(schema_version='sporespore_r10v_production_host_component_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='zero_world_production_host_component',question_class='development'),
        auditor=base.bind(__file__),manifest=base.bind(manifest),source_archives=archives,
        observed=observation,claim_boundary=CLAIMS,
        history='Three earlier runs retained one failure each: a live Mutex in JSON metadata; extra task-completion pipeline values; then an immediate orphan refusal after a successful interface. The distinct final host adds a bounded cleanup drain plus a deliberate orphan control. All 24 controls pass. No original failure or physical result is replaced.',
        scope='Actual production launcher library under the detached host, canonical runtime and invocation checks, bounded Python execution with original logs, append-only progress, owned cleanup and publication. Full production gate and complete exposed-pair final audit remain unqualified.',
        remaining=['Run host and retention qualification before creating the production host; bind fresh complete-key receipts into the successor safety graph.',
            'Complete and measure the exposed-pair final-auditor diagnostic without repairing original R10U receipts.',
            'Qualify the full graph, freeze clean and pushed source, execute five fresh development cells, then the separate held-out decision and acceptance adoption.'])
    audit(record)
    with RECORD.open('x',encoding='utf-8',newline='\r\n') as stream:
        json.dump(record,stream,indent=2);stream.write('\n')
    return audit(record)


if __name__ == '__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--create',action='store_true')
    print(json.dumps(create() if parser.parse_args().create else audit(base.read(RECORD))))
