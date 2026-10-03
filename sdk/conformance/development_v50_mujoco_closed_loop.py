"""Finite V50 startup reference-velocity diagnostic with measured feedback; no acceptance authority.

Reuse the verified recovery model, native step/cap/contact collector and direct
child ownership path. Keep the new observation conversion, cycle boundary and
independent reader explicit. A controller refusal is retained and ends the world.
"""
from __future__ import annotations
import argparse
import copy
import json
import math
import os
from pathlib import Path
import sys
import traceback
import uuid
import development_v44_mujoco_replay as native
from sporespore_locomotion import LocomotionCore

ROOT=native.ROOT
PLAN=ROOT/'sdk/development/v50_mujoco_closed_loop_v1.json'
POLICY='sporespore_balanced_wave_recovery_startup_reference_velocity_v1'
FLAGS=native.FLAGS
LIMBS=native.LIMBS
RY90=native.np.array([[0.,0.,1.],[0.,1.,0.],[-1.,0.,0.]])

def require(value,code):
    if not value:raise ValueError('V50_MUJOCO_'+code)

class RecordedCore(LocomotionCore):
    """Capture the final actual C ABI bytes before the ordinary SDK decoder."""
    def _decode(self,status,output):
        self.last_raw_response=bytes(output);self.last_status=status
        return LocomotionCore._decode(status,output)

def build_input():
    plan=native.read(PLAN)
    require((plan['maximum_walking_commands'],plan['stopping_commands'],plan['settle_tail_commands'],
        plan['world_count'],plan['seed'],plan['engine_version'])==(1600,120,30,1,40200,'3.11.0'),'PLAN')
    require(all(plan[k] is False for k in FLAGS),'AUTHORITY')
    require(plan['policy_id']==POLICY and plan['controller_contract']=='sdk/development/recovery_startup_reference_velocity_contract_v1.json','POLICY_DECLARATION')
    require(native.mujoco.__version__==plan['engine_version'],'ENGINE_VERSION')
    require((plan['native_substeps_per_command'],plan['native_dt_s'],plan['maximum_native_steps'],
        plan['child_wall_time_limit_s'])==(5,1/600,8600,180),'NATIVE_PLAN_LIMITS')
    binding=native.read(ROOT/plan['runtime_binding'])
    dll=Path(binding['runtime']['path'])
    require(native.file_binding(dll)['sha256']==binding['runtime']['raw_sha256'],'DLL')
    for item in binding['source_files']:
        require(native.file_binding(ROOT/item['path'])['sha256']==item['raw_sha256'],'RUNTIME_SOURCE')
    core=RecordedCore(dll);route,original_sha=native.compile_route(core)
    closure=native.read(ROOT/'sdk/development/v44_mujoco_fixed_command_closure_v1.json')
    old_binding=next(a for a in closure['artifacts'] if Path(a['path']).name=='input.json')
    native.reopen([old_binding]);old=native.read(old_binding['path'])
    require(native.sha(route.model_xml.encode('utf-8'))==old['replay_xml_sha256'],'MODEL_UNCHANGED')
    descriptor=native.r23d60_selected_s169_quadruped()
    memory=core.balanced_wave_policy_initial_memory(POLICY,descriptor)
    for limb in memory['ordered_limb_memory']:limb['gait_step']=90
    capability=dict(schema_version='sporespore_v50_mujoco_development_observation_v1',engine_version='3.11.0',
        body_basis='native_anatomical_rotation_times_local_y_positive_90_degrees',
        frame_id='sporespore_state_world_y_up_metres_v1',
        contacts='previous_final_native_substep_qualified_lower_capsule_contacts_and_positive_normal_force',
        initial_contacts='mj_forward_constraint_forces_at_exact_projected_initial_state',
        time='local_semantic_step_n_sample_time_n_over_120_measures_native_time_n_minus_1_over_120',
        joint_anchor_error='zero_for_exact_reduced_coordinate_joint_construction',
        physical_acceptance_authority=False,release_authority=False)
    value=dict(schema_version='sporespore_v50_mujoco_closed_loop_input_v1',plan=plan,
        descriptor=descriptor,dll=native.file_binding(dll),runtime_binding=native.file_binding(ROOT/plan['runtime_binding']),
        parent_input=old_binding,original_xml_sha256=original_sha,replay_xml_sha256=old['replay_xml_sha256'],
        initial_native_state=old['initial_native_state'],initial_source_body_states=old['initial_source_body_states'],
        free_qpos=old['free_qpos'],free_qvel=old['free_qvel'],initial_memory=memory,
        task_frame=old['initial_source_walking_state']['task_frame'],capability=capability,
        capability_sha256=native.sha(native.encoded(capability)),
        floor_reference=dict(schema_version='sporespore_static_horizontal_floor_reference_v1',
            frame_id='sporespore_state_world_y_up_metres_v1',surface_id='floor',
            source_instance_id='v50_mujoco_'+plan['diagnostic_id'],source_kind='declared_static_horizontal_surface',
            geometry_source_sha256=old['replay_xml_sha256'],height_world_m=0.),**FLAGS)
    return core,route,native.exact_json_integers(value)

def observe(snapshot,contact_rows,n,value):
    bodies=copy.deepcopy(snapshot['bodies'])
    for body in bodies:
        q=body['pose_world']['orientation_xyzw']
        body['pose_world']['orientation_xyzw']=native.base._quaternion_xyzw(native.rotation(q)@RY90)
    contacts=[]
    for limb in LIMBS:
        matches=[c for c in contact_rows if c['foot_site_id']==limb+'_foot']
        bearing=any(c['force_torque_contact_frame'] is not None and abs(c['force_torque_contact_frame'][0])>0 for c in matches)
        contacts.append(dict(contact_site_id=limb+'_foot',presence=bool(matches),bears_support=bearing,normal_load_n=None,
            provenance=dict(adapter_id='sporespore_mujoco_adapter',engine_contact_ids=['mujoco_contact_'+str(c['index']) for c in matches],
                aggregation_rule_id='mujoco_last_substep_lower_cap_positive_normal_force_v1',quality='qualified_bearing')))
    joints=[dict(j,anchor_error_m=0.,validity=dict(position=True,velocity=True,anchor_error=True)) for j in snapshot['joints']]
    state=dict(schema_version='sporespore_state_frame_v1',semantic_step=n,sample_time_s=n/120,
        base_pose_world=copy.deepcopy(bodies[0]['pose_world']),base_twist_world=copy.deepcopy(bodies[0]['twist_world']),
        ordered_joint_observations=joints,ordered_contact_observations=contacts,previous_applied_actuation=None,
        gravity_world_m_s2=dict(x=0.,y=-9.8,z=0.),task_frame=copy.deepcopy(value['task_frame']),
        adapter_capability_sha256=value['capability_sha256'])
    frame=dict(schema_version='sporespore_measured_walking_body_frame_v1',semantic_step=n,sample_time_s=n/120,
        frame_id='sporespore_state_world_y_up_metres_v1',adapter_capability_sha256=value['capability_sha256'],
        source_measurement=True,ordered_body_states=bodies)
    return state,frame

def request(snapshot,contacts,n,memory,value,stopping):
    state,frame=observe(snapshot,contacts,n,value)
    u=min(1.,(n-1)/72);amplitude=0. if stopping else .5994550408719347*u*u*(3-2*u)
    command=dict(schema_version='sporespore_motion_command_v2',command_id='v50_mujoco_closed_loop_walk_stop',
        desired_planar_velocity_task_m_s=dict(x=0. if stopping else .2,y=0.,z=0.),
        desired_heading_rad=state['task_frame']['reference_yaw_rad'],desired_yaw_rate_rad_s=None,
        gait_family_id='lateral_wave',speed_class='walk',gait_amplitude=amplitude,
        phase_progression_mode='contact_gated',valid_from_step=n,valid_through_step=n,authority='test_fixture')
    return dict(schema_version='sporespore_balanced_wave_policy_step_request_v3',descriptor=value['descriptor'],
        policy_id=POLICY,memory=copy.deepcopy(memory),state=state,command=command,
        floor_reference=value['floor_reference'],measured_body_frame=frame)

def phases(memory):
    return {l['limb_id']:(l['gait_step']+360-i*90)%360 for i,l in enumerate(memory['ordered_limb_memory'])}

def update_cycle(progress,out,physics):
    """Require a released swing, measured absence, then supported scheduled stance."""
    r=out['actuation']['receipt']['recovery_support_plane']['measured_support_transfer'];p=phases(out['next_memory'])
    if r['preparation_released_this_command']:
        progress['released'].setdefault(r['planned_swing_limb_id'],physics['command'])
    for limb in LIMBS:
        if limb in progress['released'] and p[limb]<=72 and not physics['last_substep_bearing'][limb]:
            progress['absent'].setdefault(limb,physics['command'])
        if limb in progress['absent'] and p[limb]>72 and physics['last_substep_bearing'][limb]:
            progress['completed'].setdefault(limb,physics['command'])
    return len(progress['completed'])==4 and all(p[l]>72 and physics['last_substep_bearing'][l] for l in LIMBS)

def settled(physics,compiled):
    masses={b['body_id']:b['mass_kg'] for b in compiled['morphology']['morphology_spec']['bodies']}
    bodies=physics['post']['bodies'];velocity=sum((masses[b['body_id']]*native.vector(b['twist_world']['linear_velocity_m_s']) for b in bodies),native.np.zeros(3))/sum(masses.values())
    torso=bodies[0];omega=native.vector(torso['twist_world']['angular_velocity_rad_s']);up=native.rotation(torso['pose_world']['orientation_xyzw'])[:,1]
    return bool(all(physics['last_substep_bearing'].values()) and math.hypot(velocity[0],velocity[2])<=.030
        and native.np.linalg.norm(omega)<=.15 and math.acos(float(native.np.clip(up[1],-1,1)))<=.05)

def validate_ticket(root,value):
    ticket=native.read(root/'ticket.json')
    require(ticket['parent_pid']==os.getppid() and ticket['nonce']==os.environ.get('SPORE_V50_NONCE') and len(ticket['nonce'])==32,'OWNER')
    require(ticket['input_sha256']==native.sha(native.encoded(value)) and ticket['gate_passed'] is True,'INPUT_GATE')
    require(all(ticket[k] is False for k in FLAGS) and ticket['source']==native.identity(),'AUTHORITY_SOURCE')
    native.reopen(ticket['bindings']);return ticket

def worker(root):
    value=native.read(root/'input.json');ticket=validate_ticket(root,value)
    core,route,reconstructed=build_input();require(reconstructed==value,'INPUT_RECONSTRUCTION')
    with (root/'world.xml').open('xb') as stream:stream.write(route.model_xml.encode('utf-8'))
    native.write_new(root/'construction-intent.json',dict(pid=os.getpid(),world_limit=1,native_step_limit=8600))
    world=native.MujocoRecoveryMorphologyWorld(core,route,value['capability_sha256'])
    initial=native.initialize(world,value);native.write_new(root/'initial.json',initial)
    snapshot=initial['snapshot'];contacts=initial['initial_contacts'];memory=value['initial_memory']
    progress=dict(released={},absent={},completed={});cycle_end=None;stop_count=0;rows=0;calls=0;refused=False
    with (root/'trajectory.jsonl').open('xb') as stream:
        for n in range(1,1721):
            stopping=cycle_end is not None
            r=request(snapshot,contacts,n,memory,value,stopping)
            raw_input=core._input_bytes(r)
            # Retain the input before entering native code; final bytes before decoding.
            with (root/'calls'/f'{n:04d}.request.json').open('xb') as stream_input:stream_input.write(raw_input)
            if hasattr(core,'last_raw_response'):del core.last_raw_response
            try:out=core.balanced_wave_policy_step_with_measured_body(POLICY,r)
            finally:
                if hasattr(core,'last_raw_response'):
                    with (root/'calls'/f'{n:04d}.response.json').open('xb') as stream_response:stream_response.write(core.last_raw_response)
            calls+=1;raw_output=core.last_raw_response
            base=dict(command=n,stopping=stopping,request=r,raw_request_sha256=native.sha(raw_input),
                raw_response_sha256=native.sha(raw_output),output=out)
            if out['actuation']['safe_no_actuation']:
                require(out['next_memory']==memory and all(c['target_velocity_rad_s']==0 for c in out['actuation']['ordered_commands']),'REFUSAL_SAFE_ZERO')
                world.data.ctrl[:]=0.;require(native.np.all(world.data.ctrl==0),'REFUSAL_CONTROL_ZERO')
                native.write_new(root/'controller-refusal.json',dict(base,native_controls_after_refusal=world.data.ctrl.tolist(),
                    solver_steps_after_refusal=0,**FLAGS));refused=True;break
            mapped=native.canonical_mapping(core,out['actuation'])
            targets=[c['host_target_velocity_rad_s'] for c in mapped['mapping']['ordered_commands']]
            physics=native.step_outer(world,targets,n)
            row=dict(base,composition=mapped,physics=physics)
            stream.write(native.encoded(row));stream.flush();rows+=1;memory=out['next_memory']
            snapshot=physics['post'];contacts=physics['substeps'][-1]['contacts']
            if stopping:
                stop_count+=1
                if stop_count==120:break
            elif update_cycle(progress,out,physics):cycle_end=n
            elif n==1600:break
    native.reopen(ticket['bindings']);require(ticket['source']==native.identity(),'SOURCE_DRIFT')
    native.write_new(root/'worker-receipt.json',dict(status='complete',parent_pid=os.getppid(),child_pid=os.getpid(),
        nonce=ticket['nonce'],input_sha256=ticket['input_sha256'],world_build_count=1,outer_steps=rows,
        solver_step_count=rows*5,policy_feedback_call_count=calls,controller_refused=refused,
        cycle_end_command=cycle_end,stopping_commands=stop_count,cycle_progress=progress,
        random_draw_count=0,warnings=[int(w.number) for w in world.data.warning],
        initial=native.file_binding(root/'initial.json'),trajectory=native.file_binding(root/'trajectory.jsonl'),**FLAGS))

def read_result(root):
    value,ticket,receipt=(native.read(root/n) for n in ('input.json','ticket.json','worker-receipt.json'))
    require(receipt['status']=='complete' and all(receipt[k] is False for k in FLAGS),'READER_AUTHORITY')
    require(receipt['input_sha256']==ticket['input_sha256']==native.sha(native.encoded(value)) and
        receipt['nonce']==ticket['nonce'] and receipt['parent_pid']==ticket['parent_pid'] and
        receipt['child_pid']==native.read(root/'worker-launch.json')['child_pid'],'READER_IDENTITY')
    native.reopen(ticket['bindings']);native.reopen([receipt['initial'],receipt['trajectory']])
    core,route,reconstructed=build_input();require(reconstructed==value,'READER_INPUT')
    rows=[json.loads(line) for line in (root/'trajectory.jsonl').read_text(encoding='utf-8').splitlines()]
    require(0<len(rows)<=1720 and (receipt['world_build_count'],receipt['outer_steps'],receipt['solver_step_count'],
        receipt['random_draw_count'])==(1,len(rows),len(rows)*5,0) and not any(receipt['warnings']),'READER_BOUNDS')
    initial=native.read(root/'initial.json');snapshot=initial['snapshot'];contacts=initial['initial_contacts'];memory=value['initial_memory']
    progress=dict(released={},absent={},completed={});cycle_end=None;stop_count=0;settle=[]
    compiled=core.compile_bounded_quadruped(value['descriptor']);missing_stance={l:0 for l in LIMBS}
    for n,row in enumerate(rows,1):
        r=request(snapshot,contacts,n,memory,value,cycle_end is not None)
        require(row['command']==n and row['stopping']==(cycle_end is not None) and row['request']==r,'READER_REQUEST_CHAIN')
        require((root/'calls'/f'{n:04d}.request.json').read_bytes()==core._input_bytes(r) and row['raw_request_sha256']==native.sha(core._input_bytes(r)),'READER_REQUEST_BYTES')
        raw=(root/'calls'/f'{n:04d}.response.json').read_bytes()
        out=core.balanced_wave_policy_step_with_measured_body(POLICY,r)
        require(raw==core.last_raw_response and native.sha(raw)==row['raw_response_sha256'] and out==row['output'] and not out['actuation']['safe_no_actuation'],'READER_POLICY_REPLAY')
        mapped=native.canonical_mapping(core,out['actuation']);require(mapped==row['composition'],'READER_MAPPING')
        physics=row['physics'];targets=[c['host_target_velocity_rad_s'] for c in mapped['mapping']['ordered_commands']]
        # Recheck absolute native clocks, controls, caps and contact aggregation.
        require(physics['command']==n and len(physics['substeps'])==5,'READER_NATIVE_ORDER')
        for j,s in enumerate(physics['substeps'],1):
            require(s['native_step']==(n-1)*5+j and abs(s['time_s']-s['native_step']/600)<1e-10,'READER_CLOCK')
            require(s['controls']==targets and len(s['actuator_force_nm'])==8 and all(math.isfinite(f) and abs(f)/120<=cap+1e-12 for f,cap in zip(s['actuator_force_nm'],native.caps.ORDERED_CAPS_NMS)),'READER_CONTROLS_CAPS')
        require(physics['last_substep_bearing']==native.bearing(physics['substeps'][-1]['contacts']) and
            physics['any_substep_bearing']==native.bearing([c for s in physics['substeps'] for c in s['contacts']]),'READER_CONTACTS')
        require(native.np.allclose(physics['absolute_actuator_impulse_nms'],native.np.abs([s['actuator_force_nm'] for s in physics['substeps']]).sum(axis=0)/600,atol=1e-14,rtol=0),'READER_IMPULSE')
        p=phases(out['next_memory'])
        for limb in LIMBS:missing_stance[limb]+=not row['stopping'] and p[limb]>72 and not physics['last_substep_bearing'][limb]
        memory=out['next_memory'];snapshot=physics['post'];contacts=physics['substeps'][-1]['contacts'];native.encoded(row)
        if cycle_end is not None:stop_count+=1;settle.append(settled(physics,compiled))
        elif update_cycle(progress,out,physics):cycle_end=n
    refused=receipt['controller_refused'];calls=len(rows)+int(refused)
    if refused:
        refusal=native.read(root/'controller-refusal.json');n=len(rows)+1
        r=request(snapshot,contacts,n,memory,value,cycle_end is not None);out=core.balanced_wave_policy_step_with_measured_body(POLICY,r)
        require(refusal['request']==r and refusal['output']==out and out['actuation']['safe_no_actuation'] and out['next_memory']==memory,'READER_REFUSAL')
        require((root/'calls'/f'{n:04d}.request.json').read_bytes()==core._input_bytes(r) and
            (root/'calls'/f'{n:04d}.response.json').read_bytes()==core.last_raw_response and
            refusal['raw_response_sha256']==native.sha(core.last_raw_response),'READER_REFUSAL_BYTES')
        require(refusal['native_controls_after_refusal']==[0.]*8 and refusal['solver_steps_after_refusal']==0,'READER_REFUSAL_ZERO')
    require((receipt['policy_feedback_call_count'],receipt['cycle_end_command'],receipt['stopping_commands'],receipt['cycle_progress'])==(calls,cycle_end,stop_count,progress),'READER_FINALIZATION')
    require(refused or (cycle_end is None and len(rows)==1600) or (cycle_end is not None and stop_count==120),'READER_PARTIAL')
    origin=native.vector(initial['snapshot']['bodies'][0]['pose_world']['position_m']);terminal=native.vector(snapshot['bodies'][0]['pose_world']['position_m'])
    forward=native.vector(value['task_frame']['forward_axis_world_unit'])
    return dict(schema_version='sporespore_v50_mujoco_closed_loop_reader_v1',status='valid_development_observation',
        world_count_during_read=0,solver_step_count_during_read=0,outer_steps=len(rows),controller_refused=refused,
        refusal_error=native.read(root/'controller-refusal.json')['output']['actuation']['receipt']['controller_error'] if refused else None,
        cycle_end_command=cycle_end,cycle_progress=progress,stopping_commands=stop_count,
        final_30_commands_settled=stop_count==120 and all(settle[-30:]),
        missing_scheduled_stance_samples=missing_stance,forward_displacement_m=float((terminal-origin)@forward),
        terminal_snapshot=snapshot,**FLAGS)

def dependencies():
    paths={PLAN,Path(__file__),ROOT/'tests/test_development_v50_mujoco_closed_loop.py',
        ROOT/'tests/test_development_v50_startup_reference_velocity.py',
        ROOT/'tests/test_development_v49_remaining_support_release.py',
        ROOT/'sdk/conformance/development_v49_godot_cycle_stop_diagnosis.py',
        ROOT/'sdk/conformance/development_v49_cycle_stop_diagnosis.py',
        ROOT/'sdk/development/recovery_startup_reference_velocity_contract_v1.json'}
    _,_,value=build_input();paths.update([Path(value['dll']['path']),Path(value['runtime_binding']['path']),Path(value['parent_input']['path'])])
    return sorted({b['path']:b for b in [*native.dependency_bindings(),*[native.file_binding(p) for p in paths]]}.values(),key=lambda b:b['path'])

def launch(physical):
    root=native.EVIDENCE/('development-v50-mujoco-closed-loop-'+uuid.uuid4().hex);root.mkdir();(root/'calls').mkdir()
    result=dict(status='gate_or_launch_refused',evidence_root=str(root),**FLAGS)
    try:
        with native.OperationLock() as lock:
            source=native.identity(clean=physical);bindings=dependencies();_,_,value=build_input()
            native.write_new(root/'preflight.json',dict(source=source,bindings=bindings,lock=lock.receipt,**FLAGS));native.write_new(root/'input.json',value)
            for b in bindings:
                p=Path(b['path'])
                if p.is_relative_to(ROOT) and '.venv' not in p.parts:
                    q=root/'tested-source'/p.relative_to(ROOT);q.parent.mkdir(parents=True,exist_ok=True);q.write_bytes(p.read_bytes())
            env=dict(os.environ,SPORE_V50_GATE_ROOT=str(root),SPORE_V50_DLL=value['dll']['path'],SPORE_V49_DLL=value['dll']['path'])
            native.run_owned([sys.executable,str(ROOT/'tests/test_development_v50_mujoco_closed_loop.py')],root,'gate',180,env)
            native.reopen(bindings);require(source==native.identity(),'SOURCE_DRIFT')
            if physical:
                ticket=dict(parent_pid=os.getpid(),nonce=uuid.uuid4().hex,input_sha256=native.sha(native.encoded(value)),
                    gate_passed=True,source=source,bindings=bindings,**FLAGS);native.write_new(root/'ticket.json',ticket)
                native.run_owned([sys.executable,str(Path(__file__)),'--worker',str(root)],root,'worker',180,dict(os.environ,SPORE_V50_NONCE=ticket['nonce']))
                native.run_owned([sys.executable,str(Path(__file__)),'--read',str(root)],root,'reader',180)
                result.update(status='closed_valid_development_observation',reader=native.file_binding(root/'reader.json'))
            else:result['status']='zero_world_gate_passed'
            native.reopen(bindings);require(source==native.identity(),'SOURCE_DRIFT')
    except Exception as error:result.update(error=str(error),traceback=traceback.format_exc())
    native.write_new(root/'supervisor.json',result);print(json.dumps(result),flush=True)
    return 0 if result['status'] in ('zero_world_gate_passed','closed_valid_development_observation') else 1

def main():
    parser=argparse.ArgumentParser(__doc__);modes=parser.add_mutually_exclusive_group(required=True)
    modes.add_argument('--gate',action='store_true');modes.add_argument('--run',action='store_true')
    modes.add_argument('--worker',type=Path);modes.add_argument('--read',type=Path);args=parser.parse_args()
    if args.worker:worker(args.worker.resolve());return 0
    if args.read:
        from unittest.mock import patch
        with patch.object(native.mujoco,'MjModel',side_effect=AssertionError('READER_WORLD_FORBIDDEN')),patch.object(native.mujoco,'MjData',side_effect=AssertionError('READER_DATA_FORBIDDEN')):
            native.write_new(args.read/'reader.json',read_result(args.read.resolve()))
        return 0
    return launch(args.run)

if __name__=='__main__':sys.exit(main())
