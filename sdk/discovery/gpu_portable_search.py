"""Contained finite GPU parameter search through the real portable/provider path."""
import argparse
from contextlib import ExitStack
import importlib.metadata
import json
import math
from pathlib import Path
import sys
import time
from unittest.mock import patch

import numpy as np
import mujoco

from gpu_quadruped_model import ROOT,FLAGS,sha,split_contacts
from gpu_quadruped_probe import check_capture
from gpu_measurement_probe import write_new
from portable_search_control import contract,inputs,robot_view,Controller,VIEW_FIELDS,rank,bridge


def preflight(core_path):
    import mujoco_warp as mjw
    c=contract()
    if {p:importlib.metadata.version(p) for p in c['runtime']}!=c['runtime']:raise ValueError('Pinned runtime changed')
    if any(not callable(getattr(mjw,name,None)) for name in ['step1','step2','get_data_into']):raise ValueError('Missing native split/readback interface')
    with patch.object(mujoco,'MjModel',side_effect=AssertionError('world in preflight')),patch.object(mujoco,'MjData',side_effect=AssertionError('data in preflight')):
        core=bridge.LocomotionCore(core_path);compiled,xml,spec=inputs(core_path,c)
        import hashlib
        if hashlib.sha256(xml.encode()).hexdigest()!=c['model_xml_sha256']:raise ValueError('Model pin changed')
        if compiled['descriptor_sha256']!=c['descriptor_sha256']:raise ValueError('Descriptor pin changed')
        for cell in range(4):
            controller=Controller(core,compiled,c,cell);controller.close()
            if not controller.session.closed:raise ValueError('Controller session leaked')
    return dict(ok=True,world_build_count=0,solver_steps=0,controller_sessions_created_closed=4,runtime=c['runtime'])


def verify_view(data,native,cell,contacts):
    for name in VIEW_FIELDS:
        expected=np.asarray(native[name][cell]);actual=np.asarray(getattr(data,name))
        if actual.shape!=expected.reshape(actual.shape).shape or not np.array_equal(actual,expected.reshape(actual.shape)):
            raise ValueError('Crossed or stale GPU readback: '+name)
    if data.time!=native['time'][cell] or data.ncon!=len(contacts):raise ValueError('Readback time/contact population')
    for i,r in enumerate(contacts):
        v=data.contact[i]
        if (list(map(int,v.geom))!=r['geom'] or [int(v.geom1),int(v.geom2)]!=r['geom'] or float(v.dist)!=r['distance_m']
                or list(v.pos)!=r['position_m'] or list(v.frame)!=r['frame']):raise ValueError('Crossed native contact readback')


def bind_contact_compatibility_view(data,contacts):
    """Populate legacy fields in the unstepped host copy, never in a native world.

    MuJoCo 3.11 stores geom[2] separately from geom1/geom2. Warp copies geom;
    the unchanged production adapter reads the legacy fields. Retain both.
    """
    if data.ncon!=len(contacts):raise ValueError('Contact bridge population')
    before=[];after=[]
    for i,row in enumerate(contacts):
        contact=data.contact[i];pair=list(map(int,contact.geom))
        if pair!=row['geom']:raise ValueError('Contact bridge crossed native pair')
        before.append([int(contact.geom1),int(contact.geom2)])
        contact.geom1,contact.geom2=pair
        after.append([int(contact.geom1),int(contact.geom2)])
        if list(map(int,contact.geom))!=pair or after[-1]!=pair:raise ValueError('Contact compatibility copy failed')
    return dict(schema_version='locolemotion_gpu_contact_compatibility_copy_v1',legacy_geometry_before=before,
                legacy_geometry_after=after,native_geometry=[r['geom'] for r in contacts],unstepped_host_copy_only=True)


def gpu_snapshot(wd,c):
    count=int(wd.nacon.numpy()[0]);nefc=wd.nefc.numpy();overflow=wd.overflow.numpy()
    if count>c['naconmax'] or any(overflow) or any(nefc>c['njmax']):raise ValueError('GPU capacity before readback')
    contacts=split_contacts(count,wd.contact.worldid.numpy(),wd.contact.geom.numpy(),wd.contact.dist.numpy(),wd.contact.pos.numpy(),nworld=4,capacity=c['naconmax'])
    frames=wd.contact.frame.numpy()
    for rows in contacts:
        for r in rows:r['frame']=frames[r['native_index']].reshape(-1).tolist()
    return dict({name:getattr(wd,name).numpy() for name in VIEW_FIELDS},time=wd.time.numpy(),contacts=contacts,
                batch_contacts=count,nefc=nefc,overflow=overflow)


def observation_native(data,contacts):
    return dict({name:np.asarray(getattr(data,name)).tolist() for name in VIEW_FIELDS},time_s=float(data.time),contacts=contacts,
                sampling_stage='prepared_before_control')


def cpu_contacts(data,cell):
    rows=split_contacts(data.ncon,[0]*data.ncon,[data.contact[i].geom for i in range(data.ncon)],
        [data.contact[i].dist for i in range(data.ncon)],[data.contact[i].pos for i in range(data.ncon)],nworld=1,capacity=256)[0]
    for r in rows:r.update(world=cell,frame=data.contact[r['native_index']].frame.tolist())
    return rows


def run(folder,permit,core_path):
    sys.path.insert(0,str(ROOT/'sdk/conformance'));import r10v_windows_job as jobs
    if not permit.is_file() or not jobs.current_in_job():raise ValueError('Owned contained execution required')
    preflight(core_path)
    import warp as wp
    import mujoco_warp as mjw
    c=contract();core=bridge.LocomotionCore(core_path);compiled,xml,spec=inputs(core_path,c)
    for name,value in [('compiled',compiled),('inputs',spec)]:write_new(folder/(name+'.json'),value)
    (folder/'model.xml').write_text(xml,encoding='utf-8',newline='\n')
    counts={b:[0]*4 for b in ['gpu','cpu']};outer_counts={b:[0]*4 for b in ['gpu','cpu']}
    metrics={b:[dict(minimum_height_m=math.inf,maximum_tilt_rad=0.,torso_contact_steps=0,safe_no_actuation_steps=0,forward_displacement_m=0.) for _ in range(4)] for b in counts}
    result=dict(ok=False,synthetic=False,ledger_scope=c['ledger_scope'],completed_steps=counts,completed_outer_steps=outer_counts,
                constructed_worlds=dict(gpu=0,cpu=0),cpu_readback_views=0,unstepped_initial_templates=0,**{k:False for k in FLAGS})
    timings={};controllers=[];started=time.perf_counter();stage='model';trace_path=folder/'trace.jsonl';control_path=folder/'controller.jsonl'
    def elapsed(name,tick):timings[name]=timings.get(name,0.)+time.perf_counter()-tick
    try:
        model=mujoco.MjModel.from_xml_string(xml);initial=mujoco.MjData(model);result['unstepped_initial_templates']=1
        if (model.nq,model.nv,model.nu,model.nsensordata)!=(15,14,8,16):raise ValueError('Native dimensions')
        from actuation_measurement import named_force_samples
        for motor,joint in zip(spec['ordered_actuators'],spec['ordered_joints']):named_force_samples(model,initial,motor,joint)
        metadata=dict(model_sha256=sha(folder/'model.xml'),inputs_sha256=sha(folder/'inputs.json'),compiled_sha256=sha(folder/'compiled.json'),
            ordered_bodies=[model.body(i).name for i in range(model.nbody)],body_rootid=model.body_rootid.tolist(),
            force_ranges=model.actuator_forcerange.tolist(),observation_stage='prepared_before_control',force_stage='completed_step_before_next_prepare')
        write_new(folder/'native-model.json',metadata)
        with trace_path.open('x',encoding='utf-8',newline='\n') as trace,control_path.open('x',encoding='utf-8',newline='\n') as control:
            def append(stream,row):
                stream.write(json.dumps(row,allow_nan=False,separators=(',',':'))+'\n')
                if stream.tell()>c['maximum_trace_bytes']:raise ValueError('Declared trace byte limit')

            def retain(b,cell,step,before_pos,before_vel,pos,vel,targets,sensors,clock,contacts,count,nefc,overflow,warnings):
                caps=np.asarray(spec['force_ranges'],dtype=np.float32 if b=='gpu' else np.float64).tolist()
                forces=list(map(float,sensors[::2]));joint=list(map(float,sensors[1::2]))
                row=dict(backend=b,cell=cell,step=step,before_qpos=list(map(float,before_pos)),before_qvel=list(map(float,before_vel)),qpos=list(map(float,pos)),qvel=list(map(float,vel)),
                    ctrl=list(map(float,targets)),actuator_force_nm=forces,joint_force_nm=joint,on_force_cap=[f<=lo or f>=hi for f,(lo,hi) in zip(forces,caps)],
                    time_s=float(clock),contacts=contacts,batch_contacts=int(count),nefc=int(nefc),overflow=int(overflow),warnings=list(map(int,warnings)))
                try:check_capture(row,c,caps)
                except Exception:
                    write_new(folder/'invalid-capture.json',dict(raw_repr=repr(row)));raise
                append(trace,row);counts[b][cell]+=1
                m=metrics[b][cell];m['minimum_height_m']=min(m['minimum_height_m'],float(pos[2]))
                m['maximum_tilt_rad']=max(m['maximum_tilt_rad'],math.acos(max(-1.,min(1.,1-2*(float(pos[4])**2+float(pos[5])**2)))))
                m['torso_contact_steps']+=int(any(1 in r['geom'] for r in contacts));m['forward_displacement_m']=float(pos[0])-spec['initial_qpos'][0]

            stage='gpu_setup';tick=time.perf_counter();wp.config.kernel_cache_dir=str(folder/'warp-cache');wp.init();device=wp.get_device(c['device'])
            if not device.is_cuda:raise ValueError('CUDA required')
            wp.set_device(device)
            wm=mjw.put_model(model);wd=mjw.put_data(model,initial,nworld=4,naconmax=c['naconmax'],njmax=c['njmax'],njmax_nnz=c['njmax_nnz'],nvmax=c['nvmax'])
            result['constructed_worlds']['gpu']=4
            views=[mujoco.MjData(model) for _ in range(4)];result['cpu_readback_views']=4
            robots=[robot_view(core,compiled,model,d) for d in views]
            controllers=[Controller(core,compiled,c,i) for i in range(4)]
            qvel=np.zeros((4,14),np.float32);qvel[:,1]=spec['initial_lateral_velocities']
            wp.copy(wd.qvel,wp.array(qvel,dtype=wp.float32,device=device));elapsed('gpu_setup_s',tick)
            with ExitStack() as trap:
                for name in ['mj_step','mj_step1','mj_step2','mj_forward']:
                    trap.enter_context(patch.object(mujoco,name,side_effect=AssertionError('CPU dynamics forbidden during GPU execution')))
                for outer in range(c['outer_steps']):
                    stage=f'gpu_outer_{outer}';tick=time.perf_counter();mjw.step1(wm,wd);wp.synchronize_device(device);elapsed('gpu_prepare_s',tick)
                    tick=time.perf_counter();snapshot=gpu_snapshot(wd,c);contact_bridges=[]
                    for cell,view in enumerate(views):
                        mjw.get_data_into(view,model,wd,cell)
                        contact_bridges.append(bind_contact_compatibility_view(view,snapshot['contacts'][cell]))
                        verify_view(view,snapshot,cell,snapshot['contacts'][cell])
                    elapsed('gpu_readback_s',tick);targets=[]
                    for cell,(robot,controller) in enumerate(zip(robots,controllers)):
                        tick=time.perf_counter();state=robot.state_frame(outer,bridge._mujoco_to_canonical(spec['initial_qpos'][:3]));stability=robot.stability_state(outer);kinematics=robot.endpoint_kinematics(stability)
                        row=controller.step(state,stability,kinematics);elapsed('gpu_portable_control_s',tick)
                        row.update(backend='gpu',cell=cell,outer_step=outer,native_observation=observation_native(views[cell],snapshot['contacts'][cell]))
                        row['native_observation']['contact_compatibility_copy']=contact_bridges[cell]
                        from audit_gpu_portable_search import validate_observation
                        validate_observation(row,metadata,compiled)
                        append(control,row);outer_counts['gpu'][cell]+=1;metrics['gpu'][cell]['safe_no_actuation_steps']+=int(row['output']['actuation']['safe_no_actuation']);targets.append(row['native_targets'])
                    projected=np.asarray(targets,np.float32);wp.copy(wd.ctrl,wp.array(projected,dtype=wp.float32,device=device))
                    for sub in range(5):
                        if sub:
                            tick=time.perf_counter();mjw.step1(wm,wd);wp.synchronize_device(device);elapsed('gpu_prepare_s',tick)
                        before_pos=wd.qpos.numpy();before_vel=wd.qvel.numpy()
                        tick=time.perf_counter();mjw.step2(wm,wd);wp.synchronize_device(device);elapsed('gpu_integrate_s',tick)
                        tick=time.perf_counter();snapshot=gpu_snapshot(wd,c);pos=wd.qpos.numpy();vel=wd.qvel.numpy();sensors=wd.sensordata.numpy();actual=wd.ctrl.numpy()
                        if not np.array_equal(actual,projected):raise ValueError('GPU native target readback')
                        for cell in range(4):retain('gpu',cell,5*outer+sub+1,before_pos[cell],before_vel[cell],pos[cell],vel[cell],actual[cell],sensors[cell],snapshot['time'][cell],snapshot['contacts'][cell],snapshot['batch_contacts'],snapshot['nefc'][cell],snapshot['overflow'][cell],[])
                        elapsed('gpu_internal_capture_s',tick)
                    trace.flush();control.flush()
            for controller in controllers:controller.close()
            controllers=[];result['gpu_selection']=rank(c,metrics['gpu']);write_new(folder/'gpu-selection.json',result['gpu_selection'])
            result['gpu_selection_before_cpu_construction']=result['constructed_worlds']['cpu']==0
            for cell in range(4):
                stage=f'cpu_setup_{cell}';data=mujoco.MjData(model);result['constructed_worlds']['cpu']+=1;data.qvel[1]=spec['initial_lateral_velocities'][cell]
                robot=robot_view(core,compiled,model,data);controller=Controller(core,compiled,c,cell);controllers=[controller]
                for outer in range(c['outer_steps']):
                    stage=f'cpu_cell_{cell}_outer_{outer}';tick=time.perf_counter();mujoco.mj_step1(model,data)
                    state=robot.state_frame(outer,bridge._mujoco_to_canonical(spec['initial_qpos'][:3]));stability=robot.stability_state(outer);kinematics=robot.endpoint_kinematics(stability)
                    row=controller.step(state,stability,kinematics);row.update(backend='cpu',cell=cell,outer_step=outer,native_observation=observation_native(data,cpu_contacts(data,cell)))
                    append(control,row);outer_counts['cpu'][cell]+=1;metrics['cpu'][cell]['safe_no_actuation_steps']+=int(row['output']['actuation']['safe_no_actuation']);targets=row['native_targets'];elapsed('cpu_prepare_control_s',tick)
                    for sub in range(5):
                        tick=time.perf_counter()
                        if sub:mujoco.mj_step1(model,data)
                        before_pos=data.qpos.copy();before_vel=data.qvel.copy();data.ctrl[:]=targets;mujoco.mj_step2(model,data)
                        retain('cpu',cell,5*outer+sub+1,before_pos,before_vel,data.qpos,data.qvel,data.ctrl,data.sensordata,data.time,cpu_contacts(data,cell),data.ncon,data.nefc,0,[w.number for w in data.warning]);elapsed('cpu_integrate_capture_s',tick)
                    trace.flush();control.flush()
                controller.close();controllers=[]
        result.update(ok=True,status='complete_finite_parameter_search_and_fresh_cpu_challenge',metrics=metrics,
                      trace_sha256=sha(trace_path),controller_sha256=sha(control_path),device=dict(name=device.name,architecture=device.arch))
    except BaseException as exc:result.update(error=f'{type(exc).__name__}: {exc}',failed_stage=stage,status='incomplete_or_refused_execution')
    finally:
        for controller in controllers:controller.close()
        result.update(timings=timings,total_wall_s=time.perf_counter()-started,controller_sessions_closed=True)
        write_new(folder/'worker-result.json',result)
    if not result['ok']:raise RuntimeError(result['error'])


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--core',type=Path,required=True);p.add_argument('--check-only',action='store_true');p.add_argument('--output',type=Path);p.add_argument('--permit',type=Path);a=p.parse_args()
    if a.check_only:print(json.dumps(preflight(a.core)))
    elif a.output is None or a.permit is None:p.error('Use contained supervisor')
    else:run(a.output,a.permit,a.core)
