"""Synthetic complete-route and real-ABI refusal controls. No native worlds."""
import copy
import json
import math
import os
from pathlib import Path
import sys
import unittest
import uuid
import xml.etree.ElementTree as ET
from unittest.mock import patch

import numpy as np
import mujoco
from portable_search_control import *
from gpu_quadruped_model import f32
from gpu_portable_search import preflight,verify_view,bind_contact_compatibility_view
from audit_gpu_portable_search import audit,validate_resolution,verify_closure
sys.path.insert(0,str(ROOT/'sdk'))
from adaptation_provider.conformance import _fixture


class PortableSearchControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.core_path=Path(os.environ['QUADRUPED_TEST_CORE']);cls.core=bridge.LocomotionCore(cls.core_path);cls.c=contract();cls.c['outer_steps']=3
        cls.root=Path(os.environ.get('EXPLORER_TEST_OUTPUT',ROOT.parent/'SporeSpore_Evidence'))/('portable-search-synthetic-'+uuid.uuid4().hex);cls.root.mkdir()
        with patch.object(mujoco,'MjModel',side_effect=AssertionError('Synthetic world')),patch.object(mujoco,'MjData',side_effect=AssertionError('Synthetic data')):
            cls.compiled,cls.xml,cls.spec=inputs(cls.core_path,cls.c)
            cls.template=_fixture(cls.core)['provider_request']['state']
            tree=ET.fromstring(cls.xml);cls.names=['world'];cls.positions=[np.zeros(3)];cls.anchors=[np.asarray(cls.spec['initial_qpos'][:3])];cls.axes=[np.zeros(3)]
            def walk(body,parent):
                pos=parent+np.array(list(map(float,body.attrib['pos'].split())));cls.names.append(body.attrib['name']);cls.positions.append(pos)
                for joint in body.findall('joint'):
                    cls.anchors.append(pos+np.array(list(map(float,joint.attrib.get('pos','0 0 0').split()))));cls.axes.append(np.array(list(map(float,joint.attrib['axis'].split()))))
                for child in body.findall('body'):walk(child,pos)
            walk(tree.find('worldbody/body'),np.zeros(3))
            cls.controls=[];cls.raw=[];cls.metrics={b:[] for b in ['gpu','cpu']}
            for b in ['gpu','cpu']:
                project=f32 if b=='gpu' else float
                for cell in range(4):
                    n=cls.native(b,cell);controller=Controller(cls.core,cls.compiled,cls.c,cell)
                    try:
                        for outer in range(3):
                            state,stability,kinematics=cls.observations(n,outer)
                            row=controller.step(state,stability,kinematics);row.update(backend=b,cell=cell,outer_step=outer,native_observation=dict(n,time_s=outer*5*cls.c['timestep_s']))
                            cls.controls.append(row)
                            for sub in range(5):
                                step=outer*5+sub+1
                                cls.raw.append(dict(backend=b,cell=cell,step=step,before_qpos=n['qpos'],before_qvel=n['qvel'],qpos=n['qpos'],qvel=n['qvel'],
                                    ctrl=list(map(project,row['native_targets'])),actuator_force_nm=[0.]*8,joint_force_nm=[0.]*8,on_force_cap=[False]*8,
                                    time_s=step*cls.c['timestep_s'],contacts=n['contacts'],batch_contacts=16 if b=='gpu' else 4,nefc=12,overflow=0,warnings=[] if b=='gpu' else [0]*7))
                    finally:controller.close()
                    cls.metrics[b].append(dict(minimum_height_m=n['qpos'][2],maximum_tilt_rad=0.,torso_contact_steps=0,safe_no_actuation_steps=0,forward_displacement_m=0.))
            cls.controls.sort(key=lambda r:(r['backend']=='cpu',r['outer_step'] if r['backend']=='gpu' else r['cell'],r['cell'] if r['backend']=='gpu' else r['outer_step']))
            cls.raw.sort(key=lambda r:(r['backend']=='cpu',r['step'] if r['backend']=='gpu' else r['cell'],r['cell'] if r['backend']=='gpu' else r['step']))

    @classmethod
    def native(cls,b,cell):
        project=f32 if b=='gpu' else float
        pos=[[project(x) for x in row] for row in cls.positions];velocity=project(cls.spec['initial_lateral_velocities'][cell]);contacts=[]
        for i,site in enumerate(cls.compiled['morphology']['morphology_spec']['contact_sites']):
            geom=cls.names.index(site['body_id']);point=[pos[geom][0],pos[geom][1],0.]
            contacts.append(dict(world=cell,native_index=cell*4+i if b=='gpu' else i,geom=[0,geom],distance_m=0.,position_m=point,frame=np.eye(3).reshape(-1).tolist()))
        return dict(contact_compatibility_copy=dict(schema_version='locolemotion_gpu_contact_compatibility_copy_v1',legacy_geometry_before=[[0,0] for r in contacts],
                    legacy_geometry_after=[r['geom'] for r in contacts],native_geometry=[r['geom'] for r in contacts],unstepped_host_copy_only=True),
            qpos=list(map(project,cls.spec['initial_qpos'])),qvel=[0.,velocity]+[0.]*12,xpos=pos,xipos=pos,xmat=[np.eye(3).reshape(-1).tolist() for _ in pos],
            subtree_com=[[0.,0.,0.] for _ in pos],cvel=[[0.,0.,0.,0.,velocity,0.] for _ in pos],
            xanchor=[[project(x) for x in r] for r in cls.anchors],xaxis=[[project(x) for x in r] for r in cls.axes],contacts=contacts,sampling_stage='prepared_before_control')

    @classmethod
    def observations(cls,n,step):
        state=copy.deepcopy(cls.template);state['semantic_step']=step;state['sample_time_s']=step*bridge.CONTROLLER_DT_S
        state['base_pose_world']=dict(position_m=bridge._vec_json(bridge._mujoco_to_canonical(n['xpos'][1])),orientation_xyzw=dict(x=0.,y=0.,z=0.,w=1.))
        twist=dict(linear_velocity_m_s=bridge._vec_json(bridge._mujoco_to_canonical(n['cvel'][1][3:])),angular_velocity_rad_s=dict(x=0.,y=0.,z=0.))
        state['base_twist_world']=twist
        for joint in state['ordered_joint_observations']:joint['position_rad']=0.;joint['velocity_rad_s']=0.
        bodies=[dict(body_id=name,pose_world=dict(position_m=bridge._vec_json(bridge._mujoco_to_canonical(n['xpos'][i])),orientation_xyzw=dict(x=0.,y=0.,z=0.,w=1.)),twist_world=copy.deepcopy(twist)) for i,name in enumerate(cls.names) if i]
        supports=[]
        sites=cls.compiled['morphology']['morphology_spec']['contact_sites']
        for i,site in enumerate(sites):
            ids=['mujoco_contact_'+str(i)];state['ordered_contact_observations'][i].update(presence=True,bears_support=True)
            state['ordered_contact_observations'][i]['provenance']['engine_contact_ids']=ids
            supports.append(dict(contact_site_id=site['contact_site_id'],presence=True,bears_support=True,point_world_m=bridge._vec_json(bridge._mujoco_to_canonical(n['contacts'][i]['position_m'])),
                normal_world_unit=dict(x=0.,y=1.,z=0.),surface_relative_velocity_world_m_s=twist['linear_velocity_m_s'],material_id='mujoco_bw19v_mu095',adapter_id=bridge.ADAPTER_ID,engine_contact_ids=ids))
        stability=dict(schema_version='sporespore_stability_state_v2',semantic_step=step,ordered_body_states=bodies,ordered_support_contacts=supports,
            gravity_world_m_s2=dict(x=0.,y=-9.8,z=0.),support_plane_forward_world_unit=dict(x=1.,y=0.,z=0.),adapter_capability_sha256=state['adapter_capability_sha256'])
        kinematics=[]
        for i,actuator in enumerate(cls.compiled['morphology']['morphology_spec']['actuators']):
            kinematics.append(dict(actuator_id=actuator['actuator_id'],contact_site_id=sites[i//2]['contact_site_id'],joint_anchor_world_m=bridge._vec_json(bridge._mujoco_to_canonical(n['xanchor'][i+1])),
                joint_axis_world_unit=bridge._vec_json(bridge._mujoco_to_canonical(n['xaxis'][i+1])),endpoint_world_m=supports[i//2]['point_world_m']))
        return state,stability,kinematics

    def fixture(self,controls=None,raw=None):
        parent=self.root/uuid.uuid4().hex;folder=parent/'physical';folder.mkdir(parents=True)
        (parent/'declaration.json').write_text(json.dumps(dict(contract=self.c,synthetic=True)))
        (folder/'model.xml').write_text(self.xml,encoding='utf-8',newline='\n')
        for name,value in [('compiled',self.compiled),('inputs',self.spec)]: (folder/(name+'.json')).write_text(json.dumps(value))
        metadata=dict(model_sha256=sha(folder/'model.xml'),compiled_sha256=sha(folder/'compiled.json'),inputs_sha256=sha(folder/'inputs.json'),
            ordered_bodies=self.names,body_rootid=[0]+[1]*9,observation_stage='prepared_before_control',force_stage='completed_step_before_next_prepare')
        (folder/'native-model.json').write_text(json.dumps(metadata))
        for name,rows in [('controller',self.controls if controls is None else controls),('trace',self.raw if raw is None else raw)]:
            with (folder/(name+'.jsonl')).open('w') as stream:
                for row in rows:stream.write(json.dumps(row)+'\n')
        selection=rank(self.c,self.metrics['gpu']);(folder/'gpu-selection.json').write_text(json.dumps(selection))
        result=dict(ok=True,synthetic=True,trace_sha256=sha(folder/'trace.jsonl'),controller_sha256=sha(folder/'controller.jsonl'),metrics=self.metrics,gpu_selection=selection,
            completed_steps={b:[15]*4 for b in self.metrics},completed_outer_steps={b:[3]*4 for b in self.metrics},constructed_worlds=dict(cpu=4,gpu=4),
            cpu_readback_views=4,gpu_selection_before_cpu_construction=True,controller_sessions_closed=True,**{k:False for k in FLAGS})
        (folder/'worker-result.json').write_text(json.dumps(result));return folder

    def test_full_synthetic_route_replays_real_abi_without_worlds(self):
        with patch.object(mujoco,'MjModel',side_effect=AssertionError('world')),patch.object(mujoco,'MjData',side_effect=AssertionError('data')):
            result=audit(self.fixture(),self.core_path)
        self.assertTrue(result['synthetic']);self.assertEqual(result['portable_steps_replayed'],24);self.assertEqual(result['internal_rows'],120)

    def test_actual_preflight_constructs_zero_worlds(self):
        self.assertEqual(preflight(self.core_path)['world_build_count'],0)

    def test_missing_or_crossed_denominator_refuses(self):
        for raw in [self.raw[:-1],self.raw[1:]+self.raw[:1]]:
            with self.assertRaises(ValueError):audit(self.fixture(raw=raw),self.core_path)
        with self.assertRaises(ValueError):audit(self.fixture(controls=self.controls[:-1]),self.core_path)

    def test_candidate_target_memory_and_observation_corruptions_refuse(self):
        for field,value in [('native_targets',[0.]*8),('outer_step',99)]:
            controls=copy.deepcopy(self.controls);controls[0][field]=value
            with self.assertRaises(ValueError):audit(self.fixture(controls=controls),self.core_path)
        controls=copy.deepcopy(self.controls);controls[0]['native_observation']['qpos'][7]=.1
        with self.assertRaises(ValueError):audit(self.fixture(controls=controls),self.core_path)

    def test_force_contact_overflow_and_solver_input_corruptions_refuse(self):
        for field,value in [('overflow',1),('ctrl',[0.]*8),('actuator_force_nm',[999.]*8),('time_s',100.)]:
            raw=copy.deepcopy(self.raw);raw[0][field]=value
            with self.assertRaises(ValueError):audit(self.fixture(raw=raw),self.core_path)
        raw=copy.deepcopy(self.raw);raw[0]['contacts'][0]['world']=2
        with self.assertRaises(ValueError):audit(self.fixture(raw=raw),self.core_path)

    def test_ranking_eligibility_ties_and_no_candidate(self):
        m=copy.deepcopy(self.metrics['gpu']);self.assertEqual(rank(self.c,m)['selected_cell'],0)
        m[1]['forward_displacement_m']=10.;m[1]['minimum_height_m']=.1;self.assertEqual(rank(self.c,m)['selected_cell'],0)
        for row in m:row['torso_contact_steps']=1
        self.assertIsNone(rank(self.c,m)['selected_cell'])

    def test_gpu_readback_refuses_crossed_arrays_and_contacts(self):
        from types import SimpleNamespace
        n=self.native('gpu',0);native={key:np.asarray([n[key]]*4) for key in VIEW_FIELDS};native['time']=[0.]*4
        view=SimpleNamespace(**{key:np.asarray(n[key]) for key in VIEW_FIELDS},time=0.,ncon=4,
            contact=[SimpleNamespace(geom=r['geom'],geom1=r['geom'][0],geom2=r['geom'][1],dist=r['distance_m'],pos=r['position_m'],frame=r['frame']) for r in n['contacts']])
        verify_view(view,native,0,n['contacts'])
        view.qpos=view.qpos.copy();view.qpos[0]+=.01
        with self.assertRaises(ValueError):verify_view(view,native,0,n['contacts'])
        view.qpos=np.asarray(n['qpos']);view.contact[0].geom=[0,1]
        with self.assertRaises(ValueError):verify_view(view,native,0,n['contacts'])

    def test_real_contact_compatibility_copy_preserves_native_pair(self):
        # A standalone contact struct is not a model, data world or solver.
        contact=mujoco.MjContact();contact.geom[:]=[0,3]
        self.assertEqual([contact.geom1,contact.geom2],[0,0])
        view=SimpleNamespace(ncon=1,contact=[contact]);rows=[dict(geom=[0,3])]
        copy=bind_contact_compatibility_view(view,rows)
        self.assertEqual(copy['legacy_geometry_before'],[[0,0]])
        self.assertEqual(copy['legacy_geometry_after'],[[0,3]])
        self.assertEqual(contact.geom.tolist(),[0,3])
        robot=object.__new__(bridge.MujocoBw19vRobot);robot.data=view;robot.ground_geom_id=0;robot.body_geom_ids={'foot':3}
        contact.frame[:]=[0,0,1,0,1,0,-1,0,0]
        self.assertTrue(robot._contact(dict(body_id='foot'))['present'])
        with self.assertRaises(ValueError):bind_contact_compatibility_view(view,[dict(geom=[0,9])])

    def test_contact_copy_and_native_presence_corruptions_refuse(self):
        for field,value in [('legacy_geometry_after',[[0,0]]*4),('unstepped_host_copy_only',False)]:
            controls=copy.deepcopy(self.controls);controls[0]['native_observation']['contact_compatibility_copy'][field]=value
            with self.assertRaises(ValueError):audit(self.fixture(controls=controls),self.core_path)
        controls=copy.deepcopy(self.controls);controls[0]['request']['state']['ordered_contact_observations'][0]['presence']=False
        with self.assertRaisesRegex(ValueError,'Contact presence join'):audit(self.fixture(controls=controls),self.core_path)

    def test_retained_invalid_closure_stays_invalid_and_corruptions_refuse(self):
        path=Path(__file__).with_name('gpu_portable_search_invalid_closure_v1.json');evidence=ROOT.parent/'SporeSpore_Evidence'
        result=verify_closure(path,evidence,self.core_path)
        self.assertTrue(result['original_failure_reproduced']);self.assertFalse(result['original_attempt_valid'])
        for mutation in ['digest','inventory','promoted']:
            value=json.loads(path.read_text())
            if mutation=='digest':value['artifacts'][0]['sha256']='0'*64
            elif mutation=='inventory':value['artifacts'].pop()
            else:value['independent_audit_passed']=True
            changed=self.root/(mutation+'.json');changed.write_text(json.dumps(value))
            with self.assertRaises(ValueError):verify_closure(changed,evidence,self.core_path)

    def test_fallback_is_exact_and_stale_response_falls_back(self):
        row=copy.deepcopy(next(r for r in self.controls if r['cell']==2));request=row['resolution_request'];request['provider_response']['request_id']='stale'
        resolution=self.core.resolve_adaptation_v1(request);self.assertTrue(resolution['deterministic_baseline_fallback_used'])
        self.assertEqual(map_resolution(row['composition']['host_mapping'],resolution),[r['host_target_velocity_rad_s'] for r in row['composition']['host_mapping']['ordered_commands']])
        resolution['ordered_commands'][0]['actuator_id']='crossed'
        with self.assertRaises(ValueError):map_resolution(row['composition']['host_mapping'],resolution)


if __name__=='__main__':unittest.main()
