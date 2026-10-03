"""Fresh exploratory MuJoCo loop using the portable controller and host mapping.

No campaign evaluator or acceptance flag is used. World construction requires
the coordinator's fresh permit and Windows job containment. The original MV6
worker and all observed evidence remain unchanged.
"""
import argparse
import json
import os
from pathlib import Path
import sys
import time
from unittest.mock import patch
import xml.etree.ElementTree as ET

SDK=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(SDK/'adapters/mujoco'))
sys.path.insert(0,str(SDK/'conformance'))
import r10v_windows_job as jobs
import mujoco
import numpy as np
from sporespore_mujoco_adapter import selected_policy_development as bridge
from live_impulses import InteractiveTransport, mark_native_application
from sandbox_spec import validate


def preflight(spec,core):
    validate(spec)
    def forbidden(*args,**kwargs):raise RuntimeError('PREFLIGHT_WORLD_CONSTRUCTION_FORBIDDEN')
    with patch.object(mujoco,'MjModel',forbidden),patch.object(mujoco,'MjData',forbidden):
        compiled=core.compile_bounded_quadruped(spec['descriptor'])
        if compiled.get('world_build_count')!=0:raise RuntimeError('Compiler created world')
        xml=bridge.build_model_xml(compiled,bridge.PER_ACTUATOR_DEVELOPMENT_PROFILE_ID)
        tree=ET.fromstring(xml)
        if len(tree.findall('.//actuator/velocity'))!=8:raise RuntimeError('Actuator population')
        session=core.create_balanced_wave_policy_session(bridge.SELECTED_POLICY_ID,spec['descriptor'])
        session.close()
        if not session.closed:raise RuntimeError('Native controller session did not close')
        profile=bridge._mujoco_host_profile(bridge.PER_ACTUATOR_DEVELOPMENT_PROFILE_ID)
        if profile['host_response_characterized_for_this_profile'] is not False:raise RuntimeError('Exploratory profile overclaim')
    return dict(ok=True,world_build_count=0,solver_step_count=0,
        descriptor_sha256=compiled['descriptor_sha256'],native_controller_create_destroy=True,
        native_model_construction_trapped=True,host_profile=profile,engine_version=mujoco.__version__,
        physical_acceptance_authority=False,release_authority=False)


class ExploratoryRobot(bridge.MujocoBw19vRobot):
    def __init__(self,core,descriptor):
        # The inherited observation and actuation methods operate on these
        # compiled IDs. The new constructor supplies the edited descriptor.
        self.core=core;self.profile_id=bridge.PER_ACTUATOR_DEVELOPMENT_PROFILE_ID
        self.descriptor=descriptor;self.compiled=core.compile_bounded_quadruped(descriptor)
        self.morphology=self.compiled['morphology'];self.spec=self.morphology['morphology_spec']
        self.model_xml=bridge.build_model_xml(self.compiled,self.profile_id)
        self.model=mujoco.MjModel.from_xml_string(self.model_xml);self.data=mujoco.MjData(self.model)
        mujoco.mj_forward(self.model,self.data)
        self.ground_geom_id=self.model.geom('ground').id
        self.body_geom_ids={key:self.model.geom(key+'_geom').id for key in self.morphology['ordered_body_ids']}
        self.joint_ids={key:self.model.joint(key).id for key in self.morphology['ordered_joint_ids']}
        self.actuator_ids={key:self.model.actuator(key).id for key in self.morphology['ordered_actuator_ids']}
        self.actuator_specs={row['actuator_id']:row for row in self.spec['actuators']}
        self.contact_sites={row['contact_site_id']:row for row in self.spec['contact_sites']}
        self.limbs={row['limb_id']:row for row in self.spec['limbs']}
        self._validate_model_identity()


def run(spec,core,transport,output):
    robot=ExploratoryRobot(core,spec['descriptor'])
    (output/'model.xml').write_text(robot.model_xml,encoding='utf-8')
    transport.scene(robot);transport.wait_for_start()
    memory=core.balanced_wave_initial_memory();composition_memory=bridge.CompositionMemory()
    session=core.create_balanced_wave_policy_session(bridge.SELECTED_POLICY_ID,spec['descriptor'])
    robot.prepare();initial=robot.torso_metrics()
    origin=np.array([initial['x'],initial['y'],initial['z']])
    started=time.perf_counter();costs={};errors=[];steps=0;kicks=0
    def cost(name,start):costs[name]=costs.get(name,0)+time.perf_counter()-start
    try:
        with (output/'controller-steps.jsonl').open('x',encoding='utf-8') as trace:
            for step in range(spec['steps']):
                before=time.perf_counter()
                state=robot.state_frame(step,origin);stability=robot.stability_state(step)
                kinematics=robot.endpoint_kinematics(stability)
                limb_steps=bridge._ordered_limb_steps(memory,robot.morphology['ordered_limb_ids'])
                cost('native_observation',before);before=time.perf_counter()
                request={'memory':memory,'state':state,'command':bridge._motion_command(step,spec['phase_mode'])}
                result=session.step(request);memory=result['next_memory'];actuation=result['actuation']
                if actuation['safe_no_actuation'] or actuation['failure_codes'] or actuation['receipt']['controller_error'] is not None:
                    raise RuntimeError('Portable controller refused: '+str(actuation['failure_codes']))
                composition=bridge.compose_bw19v_step(robot,actuation,stability,kinematics,limb_steps,composition_memory)
                mapping=composition['host_mapping'];cost('portable_controller_and_host_mapping',before)
                due=transport.take_due_impulses();torso=robot.model.body('torso').id
                previous=np.asarray(robot.data.xfrc_applied[torso]).copy();applied=[]
                if due:
                    vector=np.sum([[p['impulse_n_s'][axis] for axis in ['x','y','z']] for p in due],axis=0)
                    robot.data.xfrc_applied[torso,:3]+=bridge._canonical_to_mujoco(vector/bridge.CONTROLLER_DT_S)
                    applied=[dict(p,native_application='xfrc_applied_over_outer_step',outer_step_duration_s=bridge.CONTROLLER_DT_S) for p in due]
                before=time.perf_counter()
                try:
                    mark_native_application(applied)
                    application=robot.apply_host_mapping(mapping)
                finally:robot.data.xfrc_applied[torso]=previous
                cost('native_actuation_and_five_substeps',before)
                if application['portable_impulse_violation_count']:raise RuntimeError('Native impulse cap violation')
                if not np.all(np.isfinite(robot.data.qpos)) or not np.all(np.isfinite(robot.data.qvel)):raise RuntimeError('Nonfinite native state')
                steps+=1;kicks+=len(applied)
                # Full solver inputs and cap readback remain retained. Display
                # poses use the existing 30 Hz transport with impulse frames.
                trace.write(json.dumps(dict(step=step,request=request,host_mapping=mapping,application=application,impulses=applied),allow_nan=False,separators=(',',':'))+'\n')
                if trace.tell()>268435456:raise RuntimeError('Controller trace exceeded 256 MiB bound')
                # mj_step2 integrates qpos/qvel; mj_step1 refreshes the derived
                # body poses. Publish only after that existing next-step prep.
                robot.prepare()
                before=time.perf_counter();transport.frame(robot,applied);cost('presentation_transport_and_pacing',before)
                if time.perf_counter()-started>120:raise TimeoutError('Sandbox 120-second wall limit')
    except Exception as exc:
        errors.append(str(exc));raise
    finally:
        session.close()
        summary=dict(schema_version='sporespore_explorer_sandbox_summary_v1',ok=not errors,
            descriptor=spec['descriptor'],steps=steps,kicks=kicks,simulated_seconds=steps/120,
            native_loop_wall_seconds=time.perf_counter()-started,cost_seconds=costs,
            initial_metrics=initial,final_metrics=robot.torso_metrics(),errors=errors,
            profile='uncharacterized_edited_body_development',controller_session_closed=session.closed,
            world_build_count=1,physical_acceptance_authority=False,release_authority=False)
        with (output/'summary.json').open('x',encoding='utf-8') as out:json.dump(summary,out,indent=2)
    transport.completed(True,'exploratory_observation',summary)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--spec',type=Path,required=True);parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--check-only',action='store_true');parser.add_argument('--connect');parser.add_argument('--session');parser.add_argument('--source-commit');parser.add_argument('--permit',type=Path)
    args=parser.parse_args();spec=validate(json.loads(args.spec.read_text(encoding='utf-8-sig')))
    core=bridge.LocomotionCore();check=preflight(spec,core)
    if args.check_only:
        print(json.dumps(check));return 0
    if not args.permit or not args.permit.is_file() or not jobs.current_in_job():raise RuntimeError('Sandbox requires owned native launch')
    transport=InteractiveTransport(args.connect,args.session,spec['realtime'],True,args.source_commit)
    try:
        transport.hello();run(spec,core,transport,args.output);return 0
    except Exception as exc:
        transport.error(exc);raise
    finally:transport.close()


if __name__=='__main__':raise SystemExit(main())
