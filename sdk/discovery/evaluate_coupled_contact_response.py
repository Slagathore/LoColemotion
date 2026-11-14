"""Compare prepared contact predictions with retained native motion; zero worlds."""
import argparse
from contextlib import ExitStack
import hashlib
import json
from pathlib import Path
import time
from unittest.mock import patch
import xml.etree.ElementTree as ET

import mujoco
import numpy as np

from actuation_recovery_mechanics import quaternion_rotation,xyz
from creature_body_moment_diagnosis import bound_archive
from creature_contact_reactions_diagnosis import joined
from creature_righting_sequence import mechanics
from sporespore_mujoco_adapter.selected_policy_development import _CANONICAL_TO_MUJOCO as TRANSFORM
from coupled_contact_response import CoupledBody,response,require


def native_velocity(row):
    q=np.asarray(row['qpos'][3:7]);q=q/np.linalg.norm(q)
    rotation=quaternion_rotation([*q[1:],q[0]])
    velocity=np.asarray(row['qvel'])
    return np.r_[TRANSFORM.T @ velocity[:3],TRANSFORM.T @ (rotation @ velocity[3:6]),velocity[6:]]


def prepare(model,creature,row,settings):
    state=row['request']['state'];pose=state['base_pose_world'];twist=state['base_twist_world']
    qd=np.asarray([j['velocity_rad_s'] for j in state['ordered_joint_observations']])
    velocity=np.r_[xyz(twist['linear_velocity_m_s']),xyz(twist['angular_velocity_rad_s']),qd]
    prepared=model.prepare(xyz(pose['position_m']),[pose['orientation_xyzw'][k] for k in 'xyzw'],
        [j['position_rad'] for j in state['ordered_joint_observations']],velocity)
    native=row['native_observation'];expected=np.asarray(native['xipos'])[1:] @ TRANSFORM
    geometry_error=float(np.max(np.abs(prepared['frame']['centers']-expected)))
    reference=mechanics(model.tree,state,[1.,0.,0.])['kinetic_energy_j']
    kinetic_error=abs(.5*velocity @ prepared['mass'] @ velocity-reference)
    gains=np.asarray(creature['spec']['velocity_gains']);bounds=np.asarray(creature['spec']['force_ranges'])
    motor=np.clip(gains*(row['native_targets']-qd),bounds[:,0],bounds[:,1])
    damping=np.asarray([j['passive_damping_nms_per_rad'] for j in model.tree.joints])
    applied=np.r_[np.zeros(6),motor-damping*qd]
    contacts=[]
    for hit in native['contacts']:
        require(hit['geom'].count(0)==1,'Coupled retained ground contact')
        body=hit['geom'][1] if hit['geom'][0]==0 else hit['geom'][0]
        normal=np.asarray(hit['frame'][:3])*(1 if hit['geom'][0]==0 else -1)
        geom=creature['spec']['geom_names'][body]
        require(geom.endswith('_geom') and geom[:-5] in model.tree.body_ids,'Coupled retained body identity')
        contacts.append(dict(body_id=geom[:-5],point=(TRANSFORM.T @ np.asarray(hit['position_m'])).tolist(),
            normal=(TRANSFORM.T @ normal).tolist(),gap=hit['distance_m'],friction=settings['friction']))
    return prepared,applied,contacts,dict(geometry_error_m=geometry_error,kinetic_error_j=kinetic_error)


def settings(creature):
    root=ET.fromstring(creature['model_xml']);ground=root.find('worldbody/geom');option=root.find('option')
    require(ground.attrib['type']=='plane' and option.attrib['integrator']=='implicitfast','Coupled native model lane')
    return dict(dt=float(option.attrib['timestep']),friction=float(ground.attrib['friction'].split()[0]),
        penetration_recovery_time=float(ground.attrib['solref'].split()[0]))


def evaluate(archive_path,receipt_sha256,output,selection):
    archive,receipt=bound_archive(archive_path,receipt_sha256);contract=receipt['contract']
    require(contract['capture_mode']=='full' and contract['outer_steps']==360 and contract['internal_steps_per_outer']==5,'Coupled retained population')
    selected=set(selection);require(selected==set(range(0,360,30)),'Coupled prospective sample steps')
    rows=[];read_counts=dict(controller=0,native=0,reactions=0);start=time.monotonic()
    for group in receipt['worker']['groups']:
        prefix='native/'+group['batch_id'];indices=group['cell_indices']
        creatures=[archive.document(prefix+f'/cell_{i}/creature.json') for i in range(len(indices))]
        models=[CoupledBody(v['compiled']['morphology']['morphology_spec']) for v in creatures]
        configuration=[settings(v) for v in creatures];previous=[None]*len(indices)
        streams=[iter(archive.lines(prefix+'/'+name+'.jsonl')) for name in ('controller','trace','reactions')]
        for outer in range(contract['outer_steps']):
            controllers=[json.loads(next(streams[0])) for _ in indices];read_counts['controller']+=len(indices)
            staged={}
            if outer in selected:
                for local,index in enumerate(indices):
                    row=controllers[local];cell=contract['cells'][index]
                    require(row['binding']==dict(creatures[local]['binding'],cell_id=cell['cell_id'],candidate_id=cell['profile']['id']),'Coupled source binding')
                    p,applied,contacts,checks=prepare(models[local],creatures[local],row,configuration[local])
                    variants=dict(free=[],feet=[v for v in contacts if v['body_id'].endswith('_distal')],all=contacts)
                    prediction={}
                    for name,hits in variants.items():
                        r=response(models[local],p,applied,hits,configuration[local]['dt'],penetration_recovery_time=configuration[local]['penetration_recovery_time'])
                        prediction[name]=dict(velocity=r['velocity'].tolist(),converged=r['solver']['converged'],
                            kkt_residual=r['solver']['kkt_residual'],iterations=r['solver']['iterations'],contact_count=len(hits))
                    staged[local]=dict(cell_id=cell['cell_id'],batch=group['batch_id'],outer_step=outer,
                        contacts=[v['body_id'] for v in contacts],checks=checks,predictions=prediction)
            for sub in range(5):
                for local in range(len(indices)):
                    native,reaction=[json.loads(next(s)) for s in streams[1:]]
                    joined(controllers[local],native,reaction,local,outer,sub,previous[local]);previous[local]=native
                    read_counts['native']+=1;read_counts['reactions']+=1
                    if sub==0 and local in staged:
                        row=staged[local];actual=native_velocity(native);row['native_velocity']=actual.tolist()
                        for prediction in row['predictions'].values():
                            difference=np.asarray(prediction['velocity'])-actual
                            prediction['root_angular_error_rad_s']=float(np.linalg.norm(difference[3:6]))
                            prediction['root_linear_error_m_s']=float(np.linalg.norm(difference[:3]))
                            prediction['joint_velocity_error_rad_s']=float(np.linalg.norm(difference[6:]))
                        rows.append(row);output.write(json.dumps(row,separators=(',',':'),allow_nan=False)+'\n')
        for stream in streams:require(next(stream,None) is None,'Coupled extra retained rows')
        print(json.dumps(dict(batch=group['batch_id'],samples=len(rows))),flush=True)
    require(len(rows)==36*len(selection),'Coupled sample denominator')
    summaries={}
    for batch in sorted({r['batch'] for r in rows}):
        group=[r for r in rows if r['batch']==batch];by_variant={}
        for name in ('free','feet','all'):
            values=[r['predictions'][name] for r in group]
            by_variant[name]=dict(samples=len(values),converged=sum(v['converged'] for v in values),
                mean_root_angular_error_rad_s=float(np.mean([v['root_angular_error_rad_s'] for v in values])),
                maximum_root_angular_error_rad_s=max(v['root_angular_error_rad_s'] for v in values),
                mean_root_linear_error_m_s=float(np.mean([v['root_linear_error_m_s'] for v in values])),
                mean_joint_velocity_error_rad_s=float(np.mean([v['joint_velocity_error_rad_s'] for v in values])))
        summaries[batch]=by_variant
    return dict(ok=True,samples=len(rows),read_counts=read_counts,summaries=summaries,
        maximum_geometry_error_m=max(r['checks']['geometry_error_m'] for r in rows),
        maximum_kinetic_error_j=max(r['checks']['kinetic_error_j'] for r in rows),
        input_files=list(archive.verified.values()),wall_s=time.monotonic()-start,world_build_count=0,solver_steps=0,
        physical_acceptance_authority=False,release_authority=False,native_solver_equivalence=False,controller_adopted=False)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--plan',type=Path,required=True);parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
    plan=json.loads(args.plan.read_bytes());base=Path(__file__).resolve().parents[2].parent/'SporeSpore_Evidence'
    require(args.output.resolve().is_relative_to(base.resolve()),'Coupled durable evidence root');args.output.mkdir(exist_ok=False)
    for item in plan['source_pins']:
        path=Path(__file__).resolve().parents[2]/item['path'];require(hashlib.sha256(path.read_bytes()).hexdigest()==item['sha256'],'Coupled frozen source')
    with ExitStack() as stack:
        for name in ('MjModel','MjData','mj_step','mj_step1','mj_step2','mj_forward'):
            stack.enter_context(patch.object(mujoco,name,side_effect=AssertionError('Physics in retained coupled-response evaluation')))
        with (args.output/'predictions.jsonl').open('x',encoding='utf-8',newline='\n') as stream:
            result=evaluate(base/plan['input']['archive_relative_path'],plan['input']['receipt_sha256'],stream,plan['sample_outer_steps'])
    result['predictions_sha256']=hashlib.sha256((args.output/'predictions.jsonl').read_bytes()).hexdigest()
    with (args.output/'result.json').open('x',encoding='utf-8',newline='\n') as stream:json.dump(result,stream,indent=2,allow_nan=False);stream.write('\n')
    print(json.dumps({k:v for k,v in result.items() if k!='input_files'}),flush=True)
