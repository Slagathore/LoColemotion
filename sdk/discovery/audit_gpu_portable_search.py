"""Recompute the exposed ranking and replay the actual ABI without native worlds."""
import argparse
import copy
import json
import math
from pathlib import Path
import random
import struct
import sys
from types import SimpleNamespace
from unittest.mock import patch

from gpu_quadruped_model import ROOT,FLAGS,sha,f32
sys.path[:0]=[str(ROOT/'sdk/python'),str(ROOT/'sdk/adapters/mujoco')]
from sporespore_mujoco_adapter import selected_policy_development as bridge
import mujoco
import numpy as np


def require(ok,message):
    if not ok:raise ValueError(message)


def same(core,left,right):
    return core.canonicalize_json(left)['sha256']==core.canonicalize_json(right)['sha256']


def close(a,b):
    return math.isclose(float(a),float(b),rel_tol=64*2**-52,abs_tol=64*2**-52)


def validate_observation(row,metadata,compiled):
    n=row['native_observation'];state=row['request']['state'];step=row['outer_step']
    require(n['sampling_stage']=='prepared_before_control' and state['semantic_step']==step,'Observation stage/clock')
    require(state['sample_time_s']==step*bridge.CONTROLLER_DT_S,'Canonical sample time')
    require(len(n['qpos'])==15 and len(n['qvel'])==14,'Observation generalized coordinates')
    for index,joint in enumerate(state['ordered_joint_observations']):
        require(joint['position_rad']==n['qpos'][7+index] and joint['velocity_rad_s']==n['qvel'][6+index],'Joint observation mismatch')
    def pose_twist(index):
        position=bridge._mujoco_to_canonical(n['xpos'][index]);rotation=bridge._canonical_rotation(n['xmat'][index])
        v=np.asarray(n['cvel'][index],float);offset=np.asarray(n['xipos'][index])-np.asarray(n['subtree_com'][metadata['body_rootid'][index]])
        linear=v[3:]+np.cross(v[:3],offset)
        return dict(position_m=bridge._vec_json(position),orientation_xyzw=bridge._quaternion_xyzw(rotation)),dict(
            linear_velocity_m_s=bridge._vec_json(bridge._mujoco_to_canonical(linear)),angular_velocity_rad_s=bridge._vec_json(bridge._mujoco_to_canonical(v[:3])))
    for body in row['stability']['ordered_body_states']:
        index=metadata['ordered_bodies'].index(body['body_id']);pose,twist=pose_twist(index)
        require(body['pose_world']==pose,'Body pose observation mismatch')
        require(all(close(body['twist_world'][kind][axis],twist[kind][axis]) for kind in twist for axis in 'xyz'),'Body velocity observation mismatch')
        if body['body_id']=='torso':
            require(state['base_pose_world']==pose and state['base_twist_world']==body['twist_world'],'Root observation join')
    sites=compiled['morphology']['morphology_spec']['contact_sites']
    for i,site in enumerate(sites):
        geom=metadata['ordered_bodies'].index(site['body_id'])
        hits=[(index,r) for index,r in enumerate(n['contacts']) if set(r['geom'])=={0,geom}]
        observed=state['ordered_contact_observations'][i]
        require(observed['presence']==bool(hits) and observed['bears_support']==bool(hits),'Contact presence join')
        require(observed['provenance']['engine_contact_ids']==['mujoco_contact_'+str(index) for index,r in hits],'Contact identity join')
        support=row['stability']['ordered_support_contacts'][i]
        require(support['presence']==bool(hits),'Support contact presence')
        if hits:
            contact=min(hits,key=lambda pair:pair[1]['distance_m'])[1]
            require(support['point_world_m']==bridge._vec_json(bridge._mujoco_to_canonical(contact['position_m'])),'Support point join')


def validate_resolution(row,c,cell,previous):
    request=row['resolution_request']['provider_request'];response=row['resolution_request']['provider_response'];resolved=row['resolution']
    require(request['deterministic_baseline']==row['composition']['canonical_actuation'],'Provider baseline join')
    require(request['state']==row['request']['state'] and request['command']==row['request']['command'],'Provider observation join')
    factor=c['provider']['candidates'][cell]['factor']
    require((response is None)==(factor is None),'Candidate identity')
    require(request['expected_model_id']==c['provider']['candidates'][cell]['id'],'Candidate model identity')
    require(request['expected_training_corpus_id']=='untrained_no_training_corpus','Untrained candidate relabelled')
    baseline=request['deterministic_baseline']['ordered_commands'];limits=request['safety_envelope']['ordered_actuator_limits']
    require(len(baseline)==len(limits)==len(resolved['ordered_commands'])==len(row['native_targets'])==8,'Provider population')
    for i,(base,limit,actual) in enumerate(zip(baseline,limits,resolved['ordered_commands'])):
        require(limit['previous_applied_correction_rad_s']==previous[i] and limit['maximum_absolute_correction_rad_s']==c['provider']['maximum_absolute_correction_rad_s']
            and limit['maximum_slew_per_step_rad_s']==c['provider']['maximum_slew_per_step_rad_s'],'Correction history or envelope changed')
        proposal=0. if factor is None else factor*base['combined_canonical_target_velocity_rad_s']
        if response is not None:require(response['ordered_corrections'][i]['canonical_velocity_delta_rad_s']==proposal,'Candidate proposal changed')
        if factor is None or resolved['safe_no_actuation']:expected=0.
        else:
            cap=c['provider']['maximum_absolute_correction_rad_s'];slew=c['provider']['maximum_slew_per_step_rad_s']
            bounded=max(-cap,min(cap,proposal));expected=max(-cap,min(cap,max(previous[i]-slew,min(previous[i]+slew,bounded))))
        require(actual['applied_correction_rad_s']==expected,'Resolved correction mismatch')
        final=max(-base['maximum_target_speed_rad_s'],min(base['maximum_target_speed_rad_s'],base['combined_canonical_target_velocity_rad_s']+expected))
        require(actual['final_canonical_target_velocity_rad_s']==final and row['native_targets'][i]==final,'Canonical/native target mismatch')
        if factor is None:require(struct.pack('d',final)==struct.pack('d',base['combined_canonical_target_velocity_rad_s']),'Baseline bits changed')


def audit(folder,core_path):
    declaration=json.loads((folder.parent/'declaration.json').read_text());c=declaration['contract'];result=json.loads((folder/'worker-result.json').read_text())
    synthetic=declaration.get('synthetic',False);outer_steps=c['outer_steps'];steps=outer_steps*5
    require(type(synthetic) is bool and result['synthetic'] is synthetic,'Synthetic/native identity')
    require(c['schema_version']=='locolemotion_gpu_portable_search_v1' and (outer_steps==480 or synthetic and 1<=outer_steps<=480) and c['internal_steps_per_outer']==5,'Declaration population')
    require(result['ok'] is True and all(c[k] is False and result[k] is False for k in FLAGS),'Incomplete execution or changed authority')
    require(sha(core_path)==c['core_sha256'],'Core runtime pin')
    for name in ['trace','controller']:require(sha(folder/(name+'.jsonl'))==result[name+'_sha256'],'Raw trace digest')
    require(sha(folder/'model.xml')==c['model_xml_sha256'],'Native model pin')
    metadata=json.loads((folder/'native-model.json').read_text());compiled=json.loads((folder/'compiled.json').read_text());spec=json.loads((folder/'inputs.json').read_text())
    for name in ['model','compiled','inputs']:require(metadata[name+'_sha256']==sha(folder/(name+'.xml' if name=='model' else name+'.json')),'Native binding')
    require(compiled['descriptor_sha256']==c['descriptor_sha256'] and compiled['world_build_count']==0,'Descriptor/compiler binding')
    require(metadata['observation_stage']=='prepared_before_control' and metadata['force_stage']=='completed_step_before_next_prepare','Sampling label')
    expected_velocity=random.Random(c['seed']).uniform(-.005,.005)
    require(spec['initial_lateral_velocities']==[expected_velocity]*4,'Matched initial conditions changed')
    expected_outer=[('gpu',cell,step) for step in range(outer_steps) for cell in range(4)]+[('cpu',cell,step) for cell in range(4) for step in range(outer_steps)]
    controls={};core=bridge.LocomotionCore(core_path)
    contexts={};memories={};composition_memories={};provider_memories={};previous={}
    with patch.object(mujoco,'MjModel',side_effect=AssertionError('Audit world')),patch.object(mujoco,'MjData',side_effect=AssertionError('Audit data')):
        with (folder/'controller.jsonl').open() as stream:
            for index,line in enumerate(stream):
                row=json.loads(line);key=(row['backend'],row['cell'],row['outer_step']);backend,cell,step=key;pair=(backend,cell)
                require(index<len(expected_outer) and key==expected_outer[index],'Missing/repeated/crossed portable step')
                if step==0:
                    contexts[pair]=SimpleNamespace(core=core,descriptor=bridge.s169_descriptor(),morphology=compiled['morphology'],profile_id=bridge.PER_ACTUATOR_DEVELOPMENT_PROFILE_ID)
                    memories[pair]=core.balanced_wave_initial_memory();composition_memories[pair]=bridge.CompositionMemory();previous[pair]=[0.]*8
                require(row['request']['memory']==memories[pair],'Crossed controller memory')
                validate_observation(row,metadata,compiled)
                output=core.balanced_wave_policy_step(c['policy_id'],dict(row['request'],descriptor=bridge.s169_descriptor()))
                require(same(core,output,row['output']),'Portable controller replay')
                limb_steps=bridge._ordered_limb_steps(memories[pair],compiled['morphology']['ordered_limb_ids'])
                composition=bridge.compose_bw19v_step(contexts[pair],output['actuation'],row['stability'],row['kinematics'],limb_steps,composition_memories[pair])
                require(same(core,composition,row['composition']),'Stability/baseline replay')
                provider=row['resolution_request']['provider_request']
                if step:require(provider['provider_memory']==provider_memories[pair],'Crossed provider memory')
                else:require(provider['provider_memory']['sequence']==0 and provider['provider_memory']['reset_epoch']==0 and provider['provider_memory']['opaque_state']=={},'Initial provider memory')
                validate_resolution(row,c,cell,previous[pair]);resolved=core.resolve_adaptation_v1(row['resolution_request'])
                require(same(core,resolved,row['resolution']),'Provider ABI replay')
                memories[pair]=output['next_memory'];provider_memories[pair]=resolved['next_memory'];previous[pair]=[r['applied_correction_rad_s'] for r in resolved['ordered_commands']]
                controls[key]=row
    require(len(controls)==8*outer_steps,'Controller denominator')
    metrics={b:[dict(minimum_height_m=math.inf,maximum_tilt_rad=0.,torso_contact_steps=0,safe_no_actuation_steps=0,forward_displacement_m=0.) for _ in range(4)] for b in ['gpu','cpu']}
    for (b,cell,step),row in controls.items():metrics[b][cell]['safe_no_actuation_steps']+=int(row['output']['actuation']['safe_no_actuation'])
    expected=[('gpu',cell,step) for step in range(1,steps+1) for cell in range(4)]+[('cpu',cell,step) for cell in range(4) for step in range(1,steps+1)]
    rows={};sensor_error=0.
    with (folder/'trace.jsonl').open() as stream:
        for index,line in enumerate(stream):
            r=json.loads(line);key=(r['backend'],r['cell'],r['step']);b,cell,step=key
            require(index<len(expected) and key==expected[index],'Missing/repeated/crossed internal step')
            project=f32 if b=='gpu' else float;eps=2**(-23 if b=='gpu' else -52);outer=(step-1)//5;control=controls[b,cell,outer]
            for field,size in [('before_qpos',15),('qpos',15),('before_qvel',14),('qvel',14),('ctrl',8),('actuator_force_nm',8),('joint_force_nm',8)]:
                require(len(r[field])==size and all(type(x) in (int,float) and math.isfinite(x) for x in r[field]),'Invalid native vector')
            prior=rows.get((b,cell,step-1));initial_vel=[0.]*14;initial_vel[1]=project(expected_velocity)
            require(r['before_qpos']==(prior['qpos'] if prior else list(map(project,spec['initial_qpos']))) and r['before_qvel']==(prior['qvel'] if prior else initial_vel),'State continuity')
            require(r['ctrl']==list(map(project,control['native_targets'])),'Solver input/provider join')
            if (step-1)%5==0:require(r['before_qpos']==control['native_observation']['qpos'] and r['before_qvel']==control['native_observation']['qvel'],'Native observation/control clock')
            require(math.isfinite(r['time_s']) and abs(r['time_s']-step*c['timestep_s'])<=4*eps*step*step*c['timestep_s'],'Native clock')
            require(abs(sum(x*x for x in r['qpos'][3:7])-1)<=128*eps,'Native quaternion')
            require(len(r['warnings'])==(0 if b=='gpu' else 7) and not any(r['warnings']) and r['overflow']==0 and 0<=r['nefc']<=c['njmax'],'Capacity/warning')
            caps=[[project(x) for x in pair] for pair in spec['force_ranges']]
            require(r['on_force_cap']==[f<=lo or f>=hi for f,(lo,hi) in zip(r['actuator_force_nm'],caps)],'Clamp label')
            for motor,joint,(lo,hi) in zip(r['actuator_force_nm'],r['joint_force_nm'],caps):
                require(lo-32*eps*abs(lo)<=motor<=hi+32*eps*abs(hi) and abs(motor-joint)<=32*eps*max(abs(lo),abs(hi)),'Named force/cap')
                sensor_error=max(sensor_error,abs(motor-joint))
            require(0<=r['batch_contacts']<=c['naconmax'],'Contact capacity');slots=[]
            for contact in r['contacts']:
                require(contact['world']==cell and type(contact['native_index']) is int and 0<=contact['native_index']<r['batch_contacts'],'Contact world/slot')
                require(len(contact['geom'])==2 and 0 in contact['geom'] and contact['geom'][0]!=contact['geom'][1] and all(type(g) is int and 0<=g<10 for g in contact['geom']),'Contact geometry')
                require(len(contact['position_m'])==3 and len(contact['frame'])==9 and all(math.isfinite(x) for x in [contact['distance_m'],*contact['position_m'],*contact['frame']]),'Native contact values')
                slots.append(contact['native_index'])
            require(len(set(slots))==len(slots),'Duplicate contact')
            if b=='cpu':require(sorted(slots)==list(range(r['batch_contacts'])),'CPU contact denominator')
            m=metrics[b][cell];m['minimum_height_m']=min(m['minimum_height_m'],r['qpos'][2]);m['maximum_tilt_rad']=max(m['maximum_tilt_rad'],math.acos(max(-1.,min(1.,1-2*(r['qpos'][4]**2+r['qpos'][5]**2)))))
            m['torso_contact_steps']+=int(any(1 in x['geom'] for x in r['contacts']));m['forward_displacement_m']=r['qpos'][0]-spec['initial_qpos'][0];rows[key]=r
    require(len(rows)==8*steps,'Internal denominator')
    for step in range(1,steps+1):
        batch=[rows['gpu',cell,step] for cell in range(4)]
        require(len({r['batch_contacts'] for r in batch})==1 and sorted(x['native_index'] for r in batch for x in r['contacts'])==list(range(batch[0]['batch_contacts'])),'GPU global contacts')
    eligible=[];ranked=[]
    for cell,m in enumerate(metrics['gpu']):
        ok=m['minimum_height_m']>=c['selection']['minimum_height_m'] and m['maximum_tilt_rad']<=c['selection']['maximum_tilt_rad'] and m['torso_contact_steps']<=c['selection']['maximum_torso_contact_steps'] and m['safe_no_actuation_steps']==0
        eligible.append(dict(cell=cell,candidate=c['provider']['candidates'][cell]['id'],eligible=ok,forward_displacement_m=m['forward_displacement_m']))
        if ok:ranked.append(cell)
    ranked.sort(key=lambda cell:(-metrics['gpu'][cell]['forward_displacement_m'],cell))
    selection=dict(candidates=eligible,ranked_cells=ranked,selected_cell=ranked[0] if ranked else None,selection_scope='exposed_finite_gpu_discovery',trained_provider=False,physical_acceptance_authority=False)
    require(selection==result['gpu_selection']==json.loads((folder/'gpu-selection.json').read_text()),'GPU ranking changed')
    require(metrics==result['metrics'],'Outcome summary changed')
    require(result['completed_steps']=={b:[steps]*4 for b in metrics} and result['completed_outer_steps']=={b:[outer_steps]*4 for b in metrics},'Worker denominator')
    require(result['constructed_worlds']==dict(gpu=4,cpu=4) and result['cpu_readback_views']==4 and result['gpu_selection_before_cpu_construction'] and result['controller_sessions_closed'],'Native lifecycle')
    chosen=selection['selected_cell'];delta=None if chosen is None else metrics['cpu'][chosen]['forward_displacement_m']-metrics['cpu'][0]['forward_displacement_m']
    return dict(ok=True,synthetic=synthetic,internal_rows=8*steps,portable_steps_replayed=8*outer_steps,sensor_max_disagreement_nm=sensor_error,
        gpu_selection=selection,cpu_selected_minus_baseline_displacement_m=delta,metrics=metrics,trained_provider=False,
        interpretation='Exposed finite parameter discovery and task-specific CPU observations. No trained provider, held-out result, superiority, locomotion acceptance or equivalence claim.',**{k:False for k in FLAGS})


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('folder',type=Path);p.add_argument('--core',type=Path,required=True);a=p.parse_args();print(json.dumps(audit(a.folder,a.core),indent=2))
