"""Audit zero-world durable-host evidence without granting physical authority."""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import re
import uuid
import r10t_route_integration_component as base
import r10v_durable_host as host

ROOT,EVIDENCE=base.ROOT,base.EVIDENCE
CURRENT=EVIDENCE/'r10v-host-controls-f5d391cc3cff42588276451d10457469'
PRIOR=EVIDENCE/'r10v-host-controls-5d07558771b946a0b63d6059e7ef2075'
INITIAL=EVIDENCE/'r10v-host-fc7bf5c4922446d7bbc917172bfc105b'
RECORD=ROOT/'sdk/recovery/r10v_durable_host_component_v1.json'
CLAIMS=dict(zero_world_host_component_implemented=True,production_smoke_host_integrated=False,
    payload_release_implemented=False,complete_safety_gate_passed=False,physical_attempt_started=False,
    world_build_count=0,solver_step_count=0,physical_acceptance_authority=False,release_authority=False,
    sdk1_score='14/20',full_program_score='14/25')


def suite(directory,count):
    result=base.read(directory/'result.json')
    assert result['ok'] and result['tests']==count and result['failures']==result['errors']==0
    assert result['source_unchanged'] and result['world_build_count']==result['solver_step_count']==0
    before=base.read(directory/'source_before.json');assert before==base.read(directory/'source_after.json')
    assert before['head']=='c0c8813dccc9429a9872251fedf630d5dcbfe962'
    for item in before['changed_files']:
        if not item['deleted']:
            raw=base64.b64decode(item['replacement_base64'],validate=True)
            assert 'sha256:'+hashlib.sha256(raw).hexdigest()==item['raw_sha256']
    log=(directory/'tests.stderr.txt').read_text(encoding='utf-8')
    assert re.findall(r'^Ran (\d+) tests in ',log,re.M)==[str(count)]
    assert len(re.findall(r'^test_.* \.\.\. ok$',log,re.M))==count and log.rstrip().endswith('OK')
    assert len(result['roots'])==count and len(set(result['roots']))==count
    return result


def observed():
    first=suite(PRIOR,13);current=suite(CURRENT,15)
    actual=[]
    for name in current['roots']:
        root=Path(name);assert root.parent==EVIDENCE
        req=host.read(root/'request.json')
        if (root/'host_started.json').exists() and (root/'job_assigned.json').exists():
            identity=host.read(root/'host_started.json')['host_identity']
            assert not host.win.alive(identity),'OWNED_HOST_STILL_RUNNING'
            state=host.status(root)['state']
            actual.append(dict(root=root.as_posix(),case=req['probe_case'],state=state))
            assert state in ('complete','failed','incomplete')
            job=host.read(root/'job_assigned.json')
            assert job['kill_on_job_close'] and not host.win.alive(job['worker_identity'])
            assert host.read(root/'host_started.json')['in_caller_job'] is False
        elif (root/'launch_reservation.json').exists():
            raise AssertionError('INCOMPLETE_UNEXPLAINED_LAUNCH')
    assert len(actual)==9
    assert sum(x['state']=='complete' for x in actual)==2
    assert sum(x['state']=='incomplete' for x in actual)==1
    assert sum(x['state']=='failed' for x in actual)==6
    assert (INITIAL/'supervisor.stdout.txt').stat().st_size==0
    return dict(current_controls_passed=15,prior_controls_passed=13,actual_current_host_runs=9,
        real_caller_loss_passed=True,real_host_loss_cleanup_passed=True,
        real_deadline_and_owned_cancellation_passed=True,real_operation_lock_contention_passed=True,
        source_drift_and_identity_refusals_passed=True,terminal_and_publication_refusals_passed=True,
        original_probe_output_capture_gap_retained=True,live_hosts_remaining=0,actual=actual)


def audit(record):
    assert record['claim_boundary']==CLAIMS
    for item in record['bindings']+[record['manifest'],record['auditor']]:base.verify(item)
    for item in base.read(record['manifest']['path'])['files']:base.verify(item)
    assert observed()==record['observed']
    return dict(ok=True,**record['observed'],**CLAIMS)


def create():
    assert not RECORD.exists()
    observation=observed()
    directory=EVIDENCE/('r10v-host-component-'+uuid.uuid4().hex);directory.mkdir()
    roots={INITIAL,CURRENT,PRIOR}
    for run in (CURRENT,PRIOR):roots.update(Path(p) for p in base.read(run/'result.json')['roots'])
    manifest=directory/'manifest.json'
    base.write_new(manifest,dict(files=[base.bind(p) for root in sorted(roots) for p in sorted(root.rglob('*')) if p.is_file()]))
    record=dict(schema_version='sporespore_r10v_durable_host_component_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='zero_world_real_host_lifecycle_component',question_class='development'),
        auditor=base.bind(__file__),manifest=base.bind(manifest),observed=observation,claim_boundary=CLAIMS,
        bindings=[base.bind(ROOT/name) for name in ['sdk/recovery/r10v_durable_workflow_design_v1.json',
            'sdk/conformance/r10v_durable_host.py','sdk/conformance/r10v_windows_job.py',
            'sdk/conformance/r10v_host_probe.ps1','sdk/conformance/test_r10v_durable_host.py']],
        evidence_scope='Actual detached host, gated supervisor and descendants on Windows; the probe takes the real operation lock and launches no Godot or physics. Six additional cases exercise original request and terminal-consumer refusal paths. Deliberate source drift is an owned synthetic zero-world mutation, retained exactly and removed after process cleanup.',
        history='The first probe reached a terminal receipt but lost nested stdout inheritance. Explicit standard-handle forwarding repaired capture before the 13-control suite. A subsequent review added explicit publication binding and two controls: an unpublished terminal stays incomplete and crossed publication is refused. The distinct 15-control suite passed. Original probe and suite records remain unchanged.',
        next='Implement verified retained-payload release, integrate the actual R10V production launcher and final auditor, declare the complete dependency key and safety graph, then qualify from a clean pushed freeze. This component grants no physical launch.')
    audit(record);base.write_new(RECORD,record)
    return dict(ok=True,record=base.bind(RECORD),**observation,**CLAIMS)


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--create',action='store_true');args=parser.parse_args()
    print(json.dumps(create() if args.create else audit(base.read(RECORD))))
