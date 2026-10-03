"""Retained pre-host gate and exact log-import component; no physics authority."""
import argparse
import json
from pathlib import Path
import re
import r10t_route_integration_component as b
import r10v_production_host_component as previous

ROOT,EVIDENCE=b.ROOT,b.EVIDENCE
RECORD=ROOT/'sdk/recovery/r10v_prehost_component_v1.json'
DIRECTORY=EVIDENCE/'r10v-prehost-component-72594004b650417e9b720f467543b21e'
PREHOST=EVIDENCE/'r10v-prehost-f46109b2d0124b40b8ee5fd6cbf67df7'
OUTER=EVIDENCE/'r10v-prehost-check-03d756629ca845b3b200f583cc189888'
REGRESSION=EVIDENCE/'r10v-prehost-launcher-check-f30c08188cd745c09e99a9d6f01af05d'
CLAIMS=dict(prehost_qualification_implemented=True,exact_log_import_verified=True,
    complete_safety_gate_passed=False,complete_pair_final_auditor_qualified=False,
    physical_launch_authorizer_closed=True,physical_attempt_started=False,world_build_count=0,
    solver_step_count=0,physical_acceptance_authority=False,release_authority=False,sdk1_score='14/20')


def roots():
    found={DIRECTORY,PREHOST,OUTER,REGRESSION}
    found.update(b.children(REGRESSION))
    for path in PREHOST.glob('*.stdout.log'):
        for name in re.findall(r'^[A-Z0-9_]+ (C:[^\r\n]+)$',path.read_text(encoding='utf-8'),re.M):
            child=Path(name);assert child.parent==EVIDENCE and child.is_dir();found.add(child)
    for line in (PREHOST/'owned_requests.jsonl').read_text().splitlines():
        found.add(Path(json.loads(line)['path']).parent)
    integration=b.read(DIRECTORY/'integration.json')
    found.add(Path(integration['production_gate_request']['path']).parent)
    found.add(Path(integration['import_target']))
    return found


def observed():
    assert b.read(OUTER/'execution.json')['exit_code']==0
    previous.unit(REGRESSION,5,0)
    value=b.read(PREHOST/'qualification.json');request=b.read(PREHOST/'request.json')
    assert value['ok'] and value['owned_cleanup_complete'] and not value['failure_code']
    assert value['request']==b.bind(PREHOST/'request.json')
    assert value['dependencies']==request['dependencies']
    assert value['source_snapshot']==request['source_snapshot']==b.read(DIRECTORY/'source_before.json')
    assert value['owned_registry']==b.bind(PREHOST/'owned_requests.jsonl')
    assert value['world_build_count']==value['solver_step_count']==0
    assert [(s['id'],s['test_count']) for s in value['stages']]==[('r10v_production_host',28),('r10v_compact_retention',1)]
    for stage in value['stages']:
        assert stage['passed'] and stage['exit_code']==0 and not stage['timed_out']
        for stream in ('stdout','stderr'):
            assert b.bind(PREHOST/stage[stream])['raw_sha256']=='sha256:'+stage[stream+'_sha256']
        log=(PREHOST/stage['stderr']).read_text(encoding='utf-8')
        assert re.findall(r'^Ran (\d+) tests? in ',log,re.M)==[str(stage['test_count'])] and log.rstrip().endswith('OK')
    children=b.children(REGRESSION)-{REGRESSION};assert len(children)==1
    child=next(iter(children));assert b.read(child/'source_before.json')==b.read(child/'source_after.json')==value['source_snapshot']
    selected=b.read(child/'selected-stages.json')
    assert len(selected['stages'])==66 and selected['test_count']==sum(selected['discovered_test_counts'].values())==258
    integration=b.read(DIRECTORY/'integration.json');b.verify(integration['production_gate_request'])
    assert not integration['production_host_launched']
    assert not (Path(integration['production_gate_request']['path']).parent/'launch_reservation.json').exists()
    for stage in value['stages']:
        for stream in ('stdout','stderr'):
            assert (Path(integration['import_target'])/stage[stream]).read_bytes()==(PREHOST/stage[stream]).read_bytes()
    lifecycles=[previous.lifecycle(r) for r in roots() if (r/'job_assigned.json').exists()]
    assert len(lifecycles)==13
    retention=next(r for r in roots() if r.name.startswith('r10v-retention-check-'))
    result=b.read(retention/'result.json')
    assert result['ok'] and len(result['cases'])==8 and all(c['passed'] for c in result['cases'])
    return dict(host_tests_passed=28,retention_test_passed=1,retention_controls_passed=8,
        launcher_regressions_passed=5,declared_stages=66,discovered_tests=258,
        host_stage_seconds=value['stages'][0]['seconds'],retention_stage_seconds=value['stages'][1]['seconds'],
        actual_host_lifecycles=13,original_logs_imported_byte_for_byte=True,complete_graph_executed=False)


def audit(record):
    assert record['claim_boundary']==CLAIMS
    for item in [record['auditor'],record['manifest']]:b.verify(item)
    for item in b.read(record['manifest']['path'])['files']:b.verify(item)
    archive=record['source_archive'];b.verify(archive['key']);b.verify(archive['snapshot'])
    for item in b.read(archive['key']['path'])['bound_source_files']:
        assert b.bind(Path(archive['directory'])/item['path'])['raw_sha256']==item['raw_sha256']
    assert record['observed']==observed()
    return dict(ok=True,**record['observed'],**CLAIMS)


def create():
    assert not RECORD.exists()
    observation=observed()
    manifest=DIRECTORY/'manifest.json'
    files={p for root in roots() for p in root.rglob('*') if p.is_file()}
    b.write_new(manifest,dict(files=[b.bind(p) for p in sorted(files)]))
    record=dict(schema_version='sporespore_r10v_prehost_component_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='zero_world_prehost_gate_component',question_class='development'),
        auditor=b.bind(__file__),manifest=b.bind(manifest),source_archive=b.read(DIRECTORY/'source_archive.json'),
        observed=observation,claim_boundary=CLAIMS,
        remaining='Complete and measure the exposed-pair final auditor; qualify the complete source-bound graph with fresh prehost receipts; clean pushed freeze, fresh development cells, separate held-out decision and acceptance adoption.')
    audit(record)
    with RECORD.open('x',encoding='utf-8',newline='\r\n') as stream:json.dump(record,stream,indent=2);stream.write('\n')
    return audit(record)


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--create',action='store_true')
    print(json.dumps(create() if parser.parse_args().create else audit(b.read(RECORD))))
