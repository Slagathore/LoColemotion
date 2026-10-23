"""Contained quadruped batch and fresh CPU challenge. No training or acceptance."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys
import time

from gpu_quadruped_model import ROOT, FLAGS, load_contract, build_inputs, controls, split_contacts, zero_world, sha
from actuation_measurement import named_force_samples
from gpu_measurement_probe import write_new


def check_capture(row, contract, force_ranges):
    def finite(value):
        if isinstance(value, dict):
            for child in value.values(): finite(child)
        elif isinstance(value, list):
            for child in value: finite(child)
        elif isinstance(value, (float, int)) and not math.isfinite(value):
            raise ValueError('Nonfinite native capture')
    finite(row)
    if len(row['warnings']) != (contract['cpu_warning_count'] if row['backend']=='cpu' else 0):
        raise ValueError('Incomplete native warning population')
    if any(type(row[k]) is not int or row[k]<0 for k in ['overflow','nefc','batch_contacts']):
        raise ValueError('Invalid native capacity counter')
    if row['overflow'] or any(row['warnings']) or not 0 <= row['nefc'] <= contract['njmax']:
        raise ValueError('Native overflow, warning or constraint capacity exceeded')
    if row['batch_contacts'] > contract['naconmax']:
        raise ValueError('Native contact capacity exceeded')
    epsilon=2**(-23 if row['backend']=='gpu' else -52)
    if len(row['actuator_force_nm'])!=8 or len(row['joint_force_nm'])!=8 or len(force_ranges)!=8:
        raise ValueError('Incomplete force population')
    for motor,joint,(lo,hi) in zip(row['actuator_force_nm'],row['joint_force_nm'],force_ranges):
        if not lo-32*epsilon*abs(lo)<=motor<=hi+32*epsilon*abs(hi) or abs(motor-joint)>32*epsilon*max(abs(lo),abs(hi)):
            raise ValueError('Force cap or named sensor disagreement')


def run(folder, permit, core):
    sys.path.insert(0, str(ROOT/'sdk/conformance'))
    import r10v_windows_job as jobs
    if not permit.is_file() or not jobs.current_in_job():
        raise ValueError('Native quadruped execution requires job containment')
    zero_world(core)
    import mujoco
    import numpy as np
    import warp as wp
    import mujoco_warp as mjw

    c = load_contract()
    compiled, xml, spec = build_inputs(core, c)
    write_new(folder/'compiled.json', compiled)
    write_new(folder/'inputs.json', spec)
    (folder/'model.xml').write_text(xml, encoding='utf-8', newline='\n')
    counts = {key: [0]*4 for key in ['gpu','cpu']}
    constructed = dict(cpu=0,gpu=0)
    timings = {}; started = time.perf_counter(); stage = 'model_construction'
    result = dict(ok=False, ledger_scope=c['ledger_scope'], synthetic=False,
                  completed_steps=counts, constructed_worlds=constructed, **{k:False for k in FLAGS})
    try:
        model = mujoco.MjModel.from_xml_string(xml)
        if (model.nq,model.nv,model.nu,model.nbody,model.ngeom,model.nsensordata) != (15,14,8,10,10,16):
            raise ValueError('Native topology differs from declaration')
        initial = mujoco.MjData(model)
        if model.qpos0.tolist() != spec['initial_qpos']:
            raise ValueError('Native initial pose differs from XML declaration')
        addresses = []
        for index,(motor,joint) in enumerate(zip(spec['ordered_actuators'],spec['ordered_joints'])):
            named_force_samples(model,initial,motor,joint)  # Validate native names, types, dimensions and object ids.
            if model.actuator(motor).id != index or int(model.jnt_qposadr[model.joint(joint).id]) != 7+index or int(model.jnt_dofadr[model.joint(joint).id]) != 6+index:
                raise ValueError('Native joint ordering changed')
            addresses.append([int(model.sensor_adr[model.sensor(motor+'_force').id]),int(model.sensor_adr[model.sensor(joint+'_actuator_force').id])])
        metadata = dict(nq=model.nq,nv=model.nv,nu=model.nu,nbody=model.nbody,ngeom=model.ngeom,
                        nsensordata=model.nsensordata,sensor_addresses=addresses,model_sha256=sha(folder/'model.xml'),
                        inputs_sha256=sha(folder/'inputs.json'),compiled_sha256=sha(folder/'compiled.json'),
                        contact_and_force_stage='force_evaluation_state',root_post_state_source='qpos',
                        force_ranges=model.actuator_forcerange.tolist(),ordered_geoms=[model.geom(i).name for i in range(model.ngeom)])
        if metadata['force_ranges'] != spec['force_ranges'] or metadata['ordered_geoms'] != spec['geom_names']:
            raise ValueError('Native force or geometry mapping changed')
        write_new(folder/'native-model.json',metadata)
        trace_path = folder/'trace.jsonl'
        with trace_path.open('x',encoding='utf-8',newline='\n') as trace:
            def retain(backend,cell,step,before_qpos,before_qvel,qpos,qvel,ctrl,sensors,native_time,contacts,ncontact,nefc,overflow,warnings):
                forces = [float(sensors[a]) for a,b in addresses]
                joint_forces = [float(sensors[b]) for a,b in addresses]
                caps = np.asarray(spec['force_ranges'],dtype=np.float32 if backend=='gpu' else np.float64).tolist()
                row = dict(backend=backend,cell=cell,cell_id=c['control']['cells'][cell]['id'],step=step,
                    before_qpos=list(map(float,before_qpos)),before_qvel=list(map(float,before_qvel)),
                    qpos=list(map(float,qpos)),qvel=list(map(float,qvel)),ctrl=list(map(float,ctrl)),
                    actuator_force_nm=forces,joint_force_nm=joint_forces,
                    on_force_cap=[f<=lo or f>=hi for f,(lo,hi) in zip(forces,caps)],
                    time_s=float(native_time),contacts=contacts,batch_contacts=int(ncontact),nefc=int(nefc),
                    overflow=int(overflow),warnings=list(map(int,warnings)))
                try:
                    check_capture(row,c,caps)
                except Exception:
                    write_new(folder/'invalid-capture.json',dict(stage=backend,cell=cell,step=step,raw_repr=repr(row)))
                    raise
                trace.write(json.dumps(row,allow_nan=False,separators=(',',':'))+'\n')
                counts[backend][cell] += 1

            stage='gpu_setup'; tick=time.perf_counter()
            wp.config.kernel_cache_dir=str(folder/'warp-cache')
            wp.init(); device=wp.get_device(c['device'])
            if not device.is_cuda:raise ValueError('Declared CUDA device unavailable')
            with wp.ScopedDevice(device):
                wm=mjw.put_model(model)
                wd=mjw.put_data(model,initial,nworld=4,naconmax=c['naconmax'],njmax=c['njmax'],njmax_nnz=c['njmax_nnz'],nvmax=c['nvmax'])
                constructed['gpu']=4
                qpos=np.tile(spec['initial_qpos'],(4,1)).astype(np.float32)
                qvel=np.zeros((4,14),dtype=np.float32);qvel[:,1]=spec['initial_lateral_velocities']
                wp.copy(wd.qpos,wp.array(qpos,dtype=wp.float32,device=device))
                wp.copy(wd.qvel,wp.array(qvel,dtype=wp.float32,device=device))
                timings['gpu_setup_s']=time.perf_counter()-tick;costs=[];capture=0.
                for step in range(1,c['steps_per_world']+1):
                    stage=f'gpu_step_{step}'
                    before_pos=wd.qpos.numpy().copy();before_vel=wd.qvel.numpy().copy()
                    command=np.array([controls(c,cell,step,before_pos[cell].tolist(),True) for cell in range(4)],dtype=np.float32)
                    wp.copy(wd.ctrl,wp.array(command,dtype=wp.float32,device=device))
                    tick=time.perf_counter();mjw.step(wm,wd);wp.synchronize_device(device);costs.append(time.perf_counter()-tick)
                    tick=time.perf_counter()
                    after_pos=wd.qpos.numpy();after_vel=wd.qvel.numpy();sensors=wd.sensordata.numpy()
                    native_ctrl=wd.ctrl.numpy();times=wd.time.numpy();nefc=wd.nefc.numpy();overflow=wd.overflow.numpy()
                    count=int(wd.nacon.numpy()[0])
                    if count>c['naconmax'] or any(overflow) or any(nefc>c['njmax']):
                        write_new(folder/'invalid-capacity.json',dict(step=step,contacts=count,nefc=nefc.tolist(),overflow=overflow.tolist()))
                        raise ValueError('GPU capacity exceeded')
                    contacts=split_contacts(count,wd.contact.worldid.numpy(),wd.contact.geom.numpy(),
                        wd.contact.dist.numpy(),wd.contact.pos.numpy(),nworld=4,capacity=c['naconmax'])
                    for cell in range(4):
                        retain('gpu',cell,step,before_pos[cell],before_vel[cell],after_pos[cell],after_vel[cell],native_ctrl[cell],
                               sensors[cell],times[cell],contacts[cell],count,nefc[cell],overflow[cell],[])
                    trace.flush();capture+=time.perf_counter()-tick
                timings.update(gpu_first_step_including_jit_s=costs[0],gpu_later_steps_including_sync_s=sum(costs[1:]),gpu_capture_s=capture)
                result['device']=dict(alias=device.alias,name=device.name,architecture=device.arch)

            tick=time.perf_counter()
            for cell in range(4):
                stage=f'cpu_setup_{cell}';data=mujoco.MjData(model);constructed['cpu']+=1
                data.qvel[1]=spec['initial_lateral_velocities'][cell]
                for step in range(1,c['steps_per_world']+1):
                    stage=f'cpu_cell_{cell}_step_{step}'
                    before_pos=data.qpos.copy();before_vel=data.qvel.copy()
                    command=controls(c,cell,step,before_pos.tolist())
                    mujoco.mj_step1(model,data);data.ctrl[:]=command;mujoco.mj_step2(model,data)
                    contacts=split_contacts(data.ncon,[0]*data.ncon,
                        [data.contact[i].geom for i in range(data.ncon)],
                        [data.contact[i].dist for i in range(data.ncon)],
                        [data.contact[i].pos for i in range(data.ncon)],nworld=1,capacity=c['naconmax'])[0]
                    for contact in contacts:contact['world']=cell
                    retain('cpu',cell,step,before_pos,before_vel,data.qpos,data.qvel,data.ctrl,data.sensordata,
                           data.time,contacts,data.ncon,data.nefc,0,[w.number for w in data.warning])
                    trace.flush()
            timings['cpu_execution_and_capture_s']=time.perf_counter()-tick
        result.update(ok=True,status='completed_contact_and_control_commissioning',trace_sha256=sha(trace_path),model_sha256=sha(folder/'model.xml'))
    except BaseException as exc:
        result.update(status='invalid_or_incomplete_execution',failed_stage=stage,error=f'{type(exc).__name__}: {exc}')
    finally:
        result.update(timings=timings,total_wall_s=time.perf_counter()-started)
        write_new(folder/'worker-result.json',result)
    if result['ok'] is not True:raise RuntimeError(result['error'])


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--core',type=Path,required=True)
    parser.add_argument('--check-only',action='store_true')
    parser.add_argument('--output',type=Path);parser.add_argument('--permit',type=Path)
    args=parser.parse_args()
    if args.check_only:print(json.dumps(zero_world(args.core)))
    elif args.output is None or args.permit is None:parser.error('Use the owned supervisor')
    else:run(args.output.resolve(),args.permit.resolve(),args.core.resolve())
