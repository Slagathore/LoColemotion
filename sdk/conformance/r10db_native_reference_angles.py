"""Audit admitted model endpoints through the production Godot angle helper.

This exports references, not commands: no world is built and no actuator moves.
Refused increments are excluded; every retained admitted snapshot must match.
"""
import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import numpy as np
import r10da_preserved_seed_ground_approach as D

C,S,I,T,G = D.C,D.S,D.I,D.T,D.G
LIFT = D.P.P.X
STUDY = C.ROOT/'sdk/recovery/r10db_native_reference_angles_study_v1.json'
RESULT = C.ROOT/'sdk/recovery/r10db_native_reference_angles_result_v1.json'
SCRIPT = C.ROOT/'tests/test_r10db_native_reference_angles.gd'
WRAPPER = C.ROOT/'sdk/run_r10db_native_angle_audit.ps1'
HOST = C.ROOT/'sdk/development/r10ap_host_runtime_contract_v1.json'
NAMES = ['torso']+[f+'_'+part for f in G.FEET for part in ('upper','distal')]
CLAIMS = dict(new_model_increments=0,world_build_count=0,solver_step_count=0,
    motor_commands_applied=0,physical_tracking_proven=False,physical_execution_authorized=False,
    physical_acceptance_authority=False,release_authority=False)


def digest(raw):
    return dict(byte_length=len(raw),raw_sha256='sha256:'+hashlib.sha256(raw).hexdigest())


def validate_inputs(value):
    assert value['schema_version']=='sporespore_r10db_native_angle_inputs_v1'
    assert value['body_order']==NAMES and value['poses']
    for index,pose in enumerate(value['poses']):
        assert type(pose['index']) is int and pose['index']==index
        bases=np.array(pose['basis_columns'],dtype=float)
        joints=np.array(pose['model_joint_positions_rad'],dtype=float)
        assert bases.shape==(9,3,3) and joints.shape==(8,)
        assert np.all(np.isfinite(bases)) and np.all(np.isfinite(joints))
        assert np.all(np.linalg.det(bases)>0.)


def controls():
    fixture=dict(schema_version='sporespore_r10db_native_angle_inputs_v1',body_order=NAMES,
        poses=[dict(index=0,basis_columns=[np.eye(3).tolist()]*9,model_joint_positions_rad=[0.]*8)])
    validate_inputs(fixture)
    mutations=[lambda p:p.update(body_order=list(reversed(NAMES))),
        lambda p:p.update(poses=[]),lambda p:p['poses'][0].update(index=1),
        lambda p:p['poses'][0].update(basis_columns=[np.eye(3).tolist()]*8),
        lambda p:p['poses'][0].update(model_joint_positions_rad=[0.]*7),
        lambda p:p['poses'][0]['basis_columns'][0][0].__setitem__(0,float('nan')),
        lambda p:p['poses'][0]['model_joint_positions_rad'].__setitem__(0,float('inf')),
        lambda p:p['poses'][0]['basis_columns'][0][0].__setitem__(0,-1.)]
    for mutate in mutations:
        bad=copy.deepcopy(fixture);mutate(bad)
        try:validate_inputs(bad)
        except AssertionError:pass
        else:raise AssertionError('malformed reference admitted')
    # A deliberately excessive angle or reference rate must remain visible.
    observed=np.array([[0.]*8,[1.7]+[0.]*7])
    assert np.max(np.abs(observed)-S.LIMITS)>.09
    assert np.max(np.abs(np.diff(observed,axis=0))/G.DT)>4.
    return dict(valid_input=1,malformed_input_refusals=len(mutations),unclipped_limit_and_rate=2)


def script_closure(path):
    pending=[path];seen=set()
    while pending:
        source=pending.pop().resolve()
        if source in seen:continue
        seen.add(source)
        for relative in re.findall(r'preload\(\s*"res://([^\"]+)"\s*\)',source.read_text(encoding='utf-8-sig')):
            child=C.ROOT/relative
            assert child.suffix=='.gd'
            pending.append(child)
    return sorted(seen)


def runtime():
    images=C.read(HOST)['images']
    for binding in images.values():assert C.bind(binding['path'])==binding
    extension=C.ROOT/'.godot/extension_list.cfg'
    assert extension.read_text(encoding='utf-8-sig').strip()=='res://sdk/adapters/godot/sporespore_locomotion.gdextension'
    return images


def declare():
    controls();images=runtime()
    dependencies={b['path']:b for b in C.read(D.STUDY)['dependencies']}
    sources=[D.__file__,D.STUDY,D.RESULT,LIFT.STUDY,LIFT.RESULT,D.P.STUDY,D.P.RESULT,
        __file__,WRAPPER,HOST,C.ROOT/'sdk/locomotion_operation_lock.ps1',C.ROOT/'project.godot',
        C.ROOT/'sdk/adapters/godot/sporespore_locomotion.gdextension',*script_closure(SCRIPT)]
    for module in list(sys.modules.values()):
        path=getattr(module,'__file__',None)
        if path and Path(path).resolve().is_relative_to(C.ROOT/'sdk/conformance'):sources.append(path)
    for path in sources:
        binding=C.bind(path);dependencies[binding['path']]=binding
    C.write_new(STUDY,dict(schema_version='sporespore_r10db_native_reference_angles_study_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='zero_world_native_reference_semantics',question_class='development'),
        source_parent_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=C.ROOT).decode().strip(),
        question='Do the admitted measured-transform model endpoints yield native-readable joint references within existing joint/rate limits?',
        dependencies=list(dependencies.values()),runtime_images=images,
        population=dict(source_semantic_step=513,admitted_lift=69,admitted_placement=24,admitted_descent=25,endpoint_poses=119),
        design=dict(reconstruction='Rebase only retained admitted endpoint deltas, requiring every before/after and phase boundary snapshot. Never propagate refused probes; no solver rerun.',
            native='Call the production signed full-quaternion relative-angle helper on all nine body bases, using actual pinned Godot and sorted full-precision transport. No physics objects or commands.',
            measurement='Report native-minus-additive joint coordinates, initial native-versus-retained readback, signed hard-limit excess and absolute endpoint difference/DT. No clipping, retiming or automatic launch approval.',
            coverage='Endpoint semantics only. Does not bound between-endpoint extrema or show dynamical tracking, force feasibility, native landing or recovery.',
            replay='Fresh original and cold native processes under the shared conformance operation lock. Preserve input/output, invocation, exit status and original stdout/stderr. Require identical complete result and transport bytes.'),
        numerics=dict(outer_step_duration_s=G.DT,hard_joint_limits_rad=S.LIMITS.tolist(),maximum_reference_rate_rad_s=4.,entry_readback_tolerance_rad=1e-6),
        checks=dict(python=controls(),native_manufactured=8),claim_boundary=CLAIMS))


def reconstruct():
    descriptor,samples=S.statics.tracking.rows();entry=samples[0]
    packet=next(r['packet'] for r in G.records(C.CHILD/'worker_report.json','r10af_contact_frames','records') if r['packet']['semantic_step']==513)
    replay=S.statics.replay.replay(packet,513,packet['model_instance_id'],packet['body_population_instance_sha256']);assert replay['ok']
    packet=copy.deepcopy(packet);packet['counterfactual_model_only']=True
    model=I.CapModel(packet,descriptor,entry['joint_positions_rad']);assert model.names==NAMES
    poses=[];phases=[]
    def append(phase,step):
        poses.append(dict(index=len(poses),phase=phase,phase_step=step,
            basis_columns=[model.r[name].T.tolist() for name in NAMES],
            body_positions_world_m=[model.p[name].tolist() for name in NAMES],
            model_joint_positions_rad=model.joints.tolist()))
    append('entry',0)
    for name,module,expected in [('lift',LIFT,69),('placement',D.P,24),('descent',D,25)]:
        retained=C.read(module.RESULT);assert T.snapshot(model)==retained['initial']
        accepted=0;refused=0
        for index,row in enumerate(retained['trajectory']):
            assert T.snapshot(model)==row['before']
            if not row['admitted']:
                assert index==len(retained['trajectory'])-1
                refused+=1;break
            assert row['nodes'][-1]['admitted'] and row['nodes'][-1]['fraction']==1.
            model=I.advance(model,np.array(row['nodes'][-1]['delta']));accepted+=1
            assert T.snapshot(model)==row['after'];append(name,accepted)
        assert accepted==expected and T.snapshot(model)==retained['final']
        phases.append(dict(phase=name,source=C.bind(module.RESULT),admitted=accepted,refused_excluded=refused))
    assert len(poses)==119
    payload=dict(schema_version='sporespore_r10db_native_angle_inputs_v1',body_order=NAMES,poses=poses)
    validate_inputs(payload)
    return payload,phases,replay,entry['joint_positions_rad']


def native(payload,folder,images):
    folder=Path(folder).resolve();assert folder.is_relative_to(C.EVIDENCE.resolve()) and folder.is_dir()
    input_path=folder/'native_input.json';output=folder/'native_output.json'
    C.write_new(input_path,payload)
    command=[images['powershell_host']['path'],'-NoProfile','-NonInteractive','-File',str(WRAPPER),
        '-Godot',images['godot_console']['path'],'-InputPath',str(input_path),'-OutputPath',str(output),'-LockReceipt',str(folder/'native_lock.json')]
    C.write_new(folder/'native_invocation.json',dict(command=command,cwd=C.ROOT.as_posix(),timeout_s=180))
    environment={k:v for k,v in os.environ.items() if not k.startswith(('SPORESPORE_GODOT_RECOVERY_','SPORE_R10AG_'))}
    with (folder/'native_stdout.txt').open('xb') as out,(folder/'native_stderr.txt').open('xb') as err:
        try:
            process=subprocess.run(command,cwd=C.ROOT,env=environment,stdout=out,stderr=err,timeout=180,creationflags=subprocess.CREATE_NO_WINDOW)
        except subprocess.TimeoutExpired:
            C.write_new(folder/'native_execution.json',dict(timed_out=True));raise
    C.write_new(folder/'native_execution.json',dict(return_code=process.returncode,timed_out=False))
    assert process.returncode==0 and C.read(folder/'native_lock.json')['acquired']
    answer=C.read(output)
    assert answer['schema_version']=='sporespore_r10db_native_angle_outputs_v1'
    assert len(answer['checks'])==8 and all(answer['checks'].values())
    assert all(answer[key]==0 for key in ('world_build_count','solver_step_count','motor_commands_applied'))
    assert answer['physical_acceptance_authority'] is False and answer['release_authority'] is False
    assert len(answer['poses'])==len(payload['poses'])
    assert [r['index'] for r in answer['poses']]==list(range(len(payload['poses'])))
    angles=np.array([r['native_joint_positions_rad'] for r in answer['poses']])
    assert angles.shape==(len(payload['poses']),8) and np.all(np.isfinite(angles))
    return answer,dict(input=digest(input_path.read_bytes()),output=digest(output.read_bytes()))


def derive(folder):
    declaration=C.read(STUDY)
    for binding in declaration['dependencies']:assert C.bind(binding['path'])==binding
    images=runtime();assert images==declaration['runtime_images']
    checked=controls();payload,phases,replay,entry=reconstruct()
    answer,transport=native(payload,folder,images)
    angles=np.array([r['native_joint_positions_rad'] for r in answer['poses']])
    additive=np.array([r['model_joint_positions_rad'] for r in payload['poses']])
    difference=angles-additive;rates=np.abs(np.diff(angles,axis=0))/G.DT
    excess=np.abs(angles)-S.LIMITS
    rows=[]
    for index,(source,actual) in enumerate(zip(payload['poses'],answer['poses'],strict=True)):
        rows.append(dict(index=index,phase=source['phase'],phase_step=source['phase_step'],
            model_joint_positions_rad=source['model_joint_positions_rad'],native_joint_positions_rad=actual['native_joint_positions_rad'],
            native_minus_model_rad=difference[index].tolist(),hard_limit_excess_rad=excess[index].tolist(),
            reference_rate_rad_s=None if index==0 else rates[index-1].tolist()))
    summary=dict(endpoint_poses=len(rows),admitted_increments=len(rows)-1,
        initial_readback_max_error_rad=float(np.max(np.abs(angles[0]-entry))),
        initial_readback_matches=bool(np.max(np.abs(angles[0]-entry))<=1e-6),
        maximum_native_model_difference_rad=float(np.max(np.abs(difference))),
        per_joint_maximum_native_model_difference_rad=np.max(np.abs(difference),axis=0).tolist(),
        maximum_reference_rate_rad_s=float(np.max(rates)),maximum_hard_limit_excess_rad=float(np.max(excess)),
        hard_limit_violations=[dict(pose=int(i),joint=int(j),excess_rad=float(excess[i,j])) for i,j in np.argwhere(excess>0.)],
        reference_rate_violations=[dict(pose=int(i+1),joint=int(j),rate_rad_s=float(rates[i,j])) for i,j in np.argwhere(rates>4.)])
    return dict(schema_version='sporespore_r10db_native_reference_angles_result_v1',ledger_scope=declaration['ledger_scope'],
        declaration=C.bind(STUDY),implementation=C.bind(__file__),controls=checked,native_controls=answer['checks'],
        source_phases=phases,entry_contact_replay=replay,transport=transport,summary=summary,poses=rows,**CLAIMS)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    for flag in ('declare','controls','create'):parser.add_argument('--'+flag,action='store_true')
    parser.add_argument('--native-run');args=parser.parse_args()
    if args.declare:declare();print('R10DB prospective declaration created')
    elif args.controls:print(json.dumps(controls(),indent=2))
    else:
        if not args.native_run:parser.error('--native-run must name a fresh durable evidence directory')
        if args.create:assert not RESULT.exists()
        result=derive(args.native_run)
        if args.create:C.write_new(RESULT,result)
        else:assert result==C.read(RESULT)
        print(json.dumps(dict(replay=not args.create,summary=result['summary'],**CLAIMS),indent=2))
