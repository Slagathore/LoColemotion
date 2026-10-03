"""Execute/audit the declared retained-input model probe; never launch physics."""
import argparse
import json
import math
from pathlib import Path
import subprocess
import sys
import traceback
import uuid

import development_passive_entry_profile as source
import r10ai_concurrent_load_rise_closure as closure
import r10ai_geometry_reference as original
import r10aj_hip_recenter_model as model

ROOT,EVIDENCE = closure.ROOT,closure.EVIDENCE
PROTOCOL = ROOT/'sdk/recovery/r10aj_hip_recenter_model_protocol_v1.json'
RECORD = ROOT/'sdk/recovery/r10aj_hip_recenter_model_result_v1.json'
CLAIMS = dict(original_result_regraded=False,physical_causal_effect_established=False,
    controller_implemented=False,native_route_integrated=False,new_physical_population_declared=False,
    world_build_count=0,solver_step_count=0,physical_acceptance_authority=False,release_authority=False)


def propagate(descriptor,q,joints,active):
    initial = joints[:]; current = joints[:]; steps=0
    for _ in range(600):
        result=model.plan(descriptor,q,current,active)
        if result['hold_reason'] is not None: break
        if max(abs(a-b) for a,b in zip(result['targets'],current)) < 1e-12: break
        current=result['targets'];steps+=1
    final=model.plan(descriptor,q,current,active)
    converged=max(abs(a-b) for a,b in zip(final['targets'],current)) < 1e-12
    return dict(updates=steps,stop=final['hold_reason'] or ('fixed_point' if converged else 'model_budget'),
        final_joints=current,body_fixed_foot_displacements=model.displacement(descriptor,q,initial,current),
        torso_pose_frozen=True,native_support_mask_frozen=True,contact_forces_predicted=False)


def derive():
    report=closure.CHILD/'worker_report.json';assert closure.bind(report)['raw_sha256']==closure.REPORT_SHA
    protocol=closure.read(PROTOCOL);assert protocol['report_raw_sha256']==closure.REPORT_SHA
    for item in protocol['dependencies']:assert closure.bind(item['path'])==item
    rows,trajectories=[],[];previous_command=None
    for packet in closure.geometry.records(report,'r10ai_partial_recovery','step_packets'):
        native=packet['native_receipt'];plan=native['next_load_plan']
        if previous_command is not None:assert previous_command==packet['source_application']['command_sha256']
        if plan is None:
            assert len(rows)==600 and native['step']['memory']['total_steps_observed']==601
            break
        previous_command=native['next_control']['command_sha256']
        request=json.loads(packet['call']['request']['utf8_text'])
        observation,descriptor=request['step']['observation'],request['collection']['descriptor']
        original.verify(observation,descriptor,plan)
        snapshot=closure.streams.diagnosis.snapshot(packet);joints=snapshot['joint_positions_rad'];q=snapshot['orientation_xyzw']
        assert snapshot['partial_step']==len(rows)+1
        variants={}
        for name,mask in [('all_hips',[True]*4),('qualified_only',plan['qualified_support'])]:
            result=model.plan(descriptor,q,joints,mask)
            delta=model.displacement(descriptor,q,joints,result['targets'])
            goal_error=[abs(joints[2*i]-v) if v is not None else None for i,v in enumerate(result['desired_hip_angles'])]
            variants[name]=dict(**result,body_fixed_foot_displacements=delta,initial_hip_goal_errors_rad=goal_error,
                joint_targets_in_authored_limits=all(abs(v)<=(1.6 if j%2==0 else 1.1) for j,v in enumerate(result['targets'])),
                maximum_joint_delta_rad=max(abs(a-b) for a,b in zip(joints,result['targets'])),
                explicit_limit_return_joints=[j for j,v in enumerate(joints) if abs(v)>(1.6 if j%2==0 else 1.1)])
            if snapshot['partial_step'] in (1,321,600):
                trajectories.append(dict(partial_step=snapshot['partial_step'],variant=name,
                    result=propagate(descriptor,q,joints,mask)))
        rows.append(dict(partial_step=snapshot['partial_step'],semantic_step=snapshot['semantic_step'],
            original_mode=plan['mode'],original_qualified_support=plan['qualified_support'],variants=variants))
    assert len(rows)==600 and len(trajectories)==6
    summary={}
    for name in ('all_hips','qualified_only'):
        selected=[r['variants'][name] for r in rows]
        summary[name]=dict(commands=len(selected),alignment_refusals=sum(r['hold_reason'] is not None for r in selected),
            all_joint_targets_bounded=all(r['joint_targets_in_authored_limits'] for r in selected),
            maximum_joint_delta_rad=max(r['maximum_joint_delta_rad'] for r in selected),
            explicit_limit_return_samples=sum(bool(r['explicit_limit_return_joints']) for r in selected),
            lower_foot_counts=[sum(r['body_fixed_foot_displacements'][i][1]<-1e-12 for r in selected) for i in range(4)],
            raise_foot_counts=[sum(r['body_fixed_foot_displacements'][i][1]>1e-12 for r in selected) for i in range(4)],
            fallback_states_with_active_placement=sum(r['original_mode']=='explicit_v23_fallback'
                and r['variants'][name]['maximum_joint_delta_rad']>1e-12 for r in rows),
            unqualified_foot_lower_counts=[sum(not r['original_qualified_support'][i]
                and r['variants'][name]['body_fixed_foot_displacements'][i][1]<-1e-12 for r in rows) for i in range(4)])
        assert summary[name]['all_joint_targets_bounded'] and summary[name]['maximum_joint_delta_rad']<=4*model.DT+1e-12
    return dict(reconstructed_original_plans=600,verified_command_links=600,
        variants=summary,trajectories=trajectories,observations=rows,**CLAIMS)


def compact(result):
    return {k:v for k,v in result.items() if k not in ('observations','trajectories')} | dict(
        trajectories=[dict(partial_step=r['partial_step'],variant=r['variant'],
            updates=r['result']['updates'],stop=r['result']['stop']) for r in result['trajectories']])


def run():
    assert not RECORD.exists()
    out=EVIDENCE/('r10aj-hip-recenter-model-'+uuid.uuid4().hex);out.mkdir()
    print('R10AJ_MODEL_ROOT '+out.as_posix(),flush=True)
    paths=[Path(__file__),Path(model.__file__),Path(original.__file__),Path(original.geometry.__file__),
        Path(closure.__file__),Path(closure.geometry.__file__),Path(closure.streams.diagnosis.__file__),
        ROOT/'tests/test_r10aj_hip_recenter_model.py',PROTOCOL,closure.RECORD,closure.CHILD/'worker_report.json']
    bindings=[closure.bind(p) for p in paths];closure.write_new(out/'bindings-before.json',bindings)
    before=source._source_snapshot();closure.write_new(out/'source-before.json',before)
    execution=dict(ok=False,**CLAIMS)
    try:
        command=[sys.executable,'-B','-X','utf8','-m','unittest','discover','-s','tests','-p','test_r10aj_hip_recenter_model.py','-v']
        tests=subprocess.run(command,cwd=ROOT,capture_output=True,timeout=60,creationflags=subprocess.CREATE_NO_WINDOW)
        (out/'controls.stdout.txt').write_bytes(tests.stdout);(out/'controls.stderr.txt').write_bytes(tests.stderr)
        execution.update(controls_command=command,controls_returncode=tests.returncode)
        assert tests.returncode==0 and b'Ran 6 tests' in tests.stderr
        result=derive();closure.write_new(out/'result.json',result);execution['ok']=True
    except BaseException:
        execution['error']=traceback.format_exc();raise
    finally:
        after=source._source_snapshot();closure.write_new(out/'source-after.json',after)
        end_bindings=[closure.bind(p) for p in paths];closure.write_new(out/'bindings-after.json',end_bindings)
        execution['source_unchanged']=before==after and bindings==end_bindings
        closure.write_new(out/'execution.json',execution)
    assert execution['source_unchanged']
    record=dict(schema_version='sporespore_r10aj_hip_recenter_model_result_v1',
        ledger_scope=closure.read(PROTOCOL)['ledger_scope'],protocol=closure.bind(PROTOCOL),evidence_root=out.as_posix(),
        files=[closure.bind(p) for p in sorted(out.iterdir()) if p.is_file()],observed=compact(result),claim_boundary=CLAIMS)
    closure.write_new(RECORD,record);return record['observed']


def audit():
    record=closure.read(RECORD);assert record['claim_boundary']==CLAIMS
    for item in [record['protocol'],*record['files']]:assert closure.bind(item['path'])==item
    out=Path(record['evidence_root']);before=closure.read(out/'bindings-before.json')
    assert before==closure.read(out/'bindings-after.json')
    for item in before:assert closure.bind(item['path'])==item
    assert closure.read(out/'source-before.json')==closure.read(out/'source-after.json')
    execution=closure.read(out/'execution.json')
    assert execution['ok'] is True and execution['source_unchanged'] is True and execution['controls_returncode']==0
    tests=(out/'controls.stderr.txt').read_text();assert tests.count(' ... ok\n')==6 and tests.rstrip().endswith('OK')
    result=derive();assert result==closure.read(out/'result.json') and compact(result)==record['observed']
    return record['observed']


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--run',action='store_true')
    print(json.dumps(run() if parser.parse_args().run else audit(),indent=2,allow_nan=False))
