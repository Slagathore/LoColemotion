"""One bounded development replay; shared model/C ABI, fixed commands, full retention.

The launcher owns the project mutex and a bounded child. The child alone may
construct a world. --gate and --read are zero-world routes. No acceptance claims.
"""
from __future__ import annotations

import argparse
import copy
import ctypes
from dataclasses import replace
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import sys
import time
import traceback
import uuid
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT.parent / 'SporeSpore_Evidence'
sys.path[:0] = [str(ROOT / p) for p in ('sdk/python', 'sdk/adapters/mujoco', 'sdk/conformance')]
import numpy as np
import mujoco
from sporespore_locomotion import LocomotionCore, r23d60_selected_s169_quadruped
from sporespore_mujoco_adapter import selected_policy_development as base
from sporespore_mujoco_adapter import actuator_cap_profile as caps
from sporespore_mujoco_adapter.recovery_morphology_route import (
    compile_recovery_morphology_model_route, MujocoRecoveryMorphologyWorld)
import development_recovery_v44_support_diagnosis as source

PLAN = ROOT / 'sdk/development/v44_mujoco_command_replay_v1.json'
DLL = EVIDENCE / 'development-candidate-build-e18ac74f9dfb4a6fa1809fdd96f3f6f2/sporespore_godot_adapter.dll'
DLL_SHA = 'sha256:ac9e8d6c301f947f8f2313da7cda8910a989021dfb748c23d99707ac4b4c6ab5'
FLAGS = dict(physical_acceptance_authority=False, release_authority=False,
             behavior_claimed=False, equivalence_claimed=False)
MUTEX = r'Global\SporeSpore.Locomotion.PhysicalConformance.Serial.v1'
LIMBS = tuple(source.LIMBS)
C = base._CANONICAL_TO_MUJOCO


def require(value, code):
    if not value:
        raise ValueError('V44_MUJOCO_' + code)


def encoded(value):
    return (json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False) + '\n').encode('utf-8')


def sha(raw):
    return 'sha256:' + hashlib.sha256(raw).hexdigest()


def write_new(path, value):
    with Path(path).open('xb') as stream:
        stream.write(encoded(value))


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8'))


def file_binding(path):
    path = Path(path).resolve()
    raw = path.read_bytes()
    return dict(path=str(path), byte_length=len(raw), sha256=sha(raw))


def reopen(bindings):
    for expected in bindings:
        require(file_binding(expected['path']) == expected, 'CHANGED_INPUT:' + expected['path'])


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True, encoding='utf-8').strip()


def identity(clean=False):
    require(Path(git('rev-parse', '--show-toplevel')).resolve() == ROOT, 'ROOT')
    require(git('remote', 'get-url', 'origin') == 'https://github.com/Slagathore/sporespore.git', 'REMOTE')
    status = git('status', '--short')
    if clean:
        require(not status, 'DIRTY_PHYSICAL_FREEZE')
        require(git('rev-parse', 'HEAD') == git('rev-parse', 'origin/main') ==
                git('ls-remote', 'origin', 'refs/heads/main').split()[0], 'UNPUSHED_FREEZE')
    return dict(commit=git('rev-parse', 'HEAD'), status=status)


def dependency_bindings():
    # Bind loaded Python modules and native package images, including the actual
    # interpreter. The source tree identity/status is checked independently.
    paths = {PLAN, Path(__file__), ROOT/'tests/test_development_v44_mujoco_replay.py',
             source.RECORD, DLL, Path(sys.executable), Path(sys._base_executable)}
    for module in tuple(sys.modules.values()):
        name = getattr(module, '__file__', None)
        if name and Path(name).is_file() and Path(name).suffix.lower() in ('.py', '.pyd', '.dll'):
            paths.add(Path(name).resolve())
    for package in (Path(mujoco.__file__).parent, Path(np.__file__).parent.parent/'numpy.libs'):
        for path in package.rglob('*'):
            if path.is_file() and path.suffix.lower() in ('.dll', '.pyd'):
                paths.add(path.resolve())
    return [file_binding(path) for path in sorted(paths)]


class OperationLock:
    def __enter__(self):
        kernel = ctypes.WinDLL('kernel32', use_last_error=True)
        kernel.CreateMutexW.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_wchar_p]
        kernel.CreateMutexW.restype = ctypes.c_void_p
        for name in ('WaitForSingleObject', 'ReleaseMutex', 'CloseHandle'):
            getattr(kernel, name).argtypes = ([ctypes.c_void_p, ctypes.c_uint32]
                                             if name == 'WaitForSingleObject' else [ctypes.c_void_p])
        self.kernel = kernel
        self.handle = kernel.CreateMutexW(None, False, MUTEX)
        require(self.handle, 'LOCK_CREATE')
        result = kernel.WaitForSingleObject(self.handle, 0)
        if result not in (0, 0x80):
            kernel.CloseHandle(self.handle)
            raise ValueError('V44_MUJOCO_OPERATION_BUSY')
        self.receipt = dict(name=MUTEX, owner_pid=os.getpid(), abandoned_owner_recovered=result == 0x80)
        return self

    def __exit__(self, *args):
        self.kernel.ReleaseMutex(self.handle)
        self.kernel.CloseHandle(self.handle)


def rotation(q):
    x, y, z, w = (float(q[k]) for k in ('x', 'y', 'z', 'w'))
    require(abs(x*x+y*y+z*z+w*w-1) < 1e-6, 'QUATERNION')
    scale = 2/(x*x+y*y+z*z+w*w)
    return np.array([[1-scale*(y*y+z*z), scale*(x*y-z*w), scale*(x*z+y*w)],
                     [scale*(x*y+z*w), 1-scale*(x*x+z*z), scale*(y*z-x*w)],
                     [scale*(x*z-y*w), scale*(y*z+x*w), 1-scale*(x*x+y*y)]])


def vector(value):
    return np.array([value[k] for k in ('x', 'y', 'z')], dtype=float)


def project_free_state(state):
    pose, twist = state['base_pose_world'], state['base_twist_world']
    rm = C @ rotation(pose['orientation_xyzw']) @ C.T
    q = base._quaternion_xyzw(rm)
    qpos = np.r_[C @ vector(pose['position_m']), [q[k] for k in ('w', 'x', 'y', 'z')]]
    qvel = np.r_[C @ vector(twist['linear_velocity_m_s']),
                 rm.T @ C @ vector(twist['angular_velocity_rad_s'])]
    require(np.all(np.isfinite(qpos)) and np.all(np.isfinite(qvel)), 'INITIAL_STATE_NONFINITE')
    return qpos, qvel


def integral(value):
    require(type(value) in (int, float) and math.isfinite(value) and
            0 <= value < 2**53 and int(value) == value, 'INTEGER_PROJECTION')
    return int(value)


def exact_json_integers(value):
    """Restore Godot's integral JSON tokens without rounding any numeric value.

    Rust accepts integer tokens for floating fields, but rejects `1.0` for u64.
    Preserve negative zero and all nonintegral floats exactly.
    """
    if isinstance(value, dict):
        return {k: exact_json_integers(v) for k, v in value.items()}
    if isinstance(value, list):
        return [exact_json_integers(v) for v in value]
    if type(value) is float and math.isfinite(value) and 0 <= value < 2**53 and \
            math.copysign(1, value) > 0 and int(value) == value:
        return int(value)
    return value


def canonical_mapping(core, actuation):
    a = exact_json_integers(actuation)
    a['semantic_step'] = integral(a['semantic_step'])
    a['world_build_count'] = integral(a['world_build_count'])
    for command in a['ordered_commands']:
        command['valid_through_step'] = integral(command['valid_through_step'])
    residuals = [dict(schema_version='sporespore_canonical_velocity_residual_v1',
        actuator_id=c['actuator_id'], canonical_velocity_delta_rad_s=0.,
        command_not_measurement=True, physical_acceptance_authority=False) for c in a['ordered_commands']]
    canonical = core.canonical_velocity_compose_v1(dict(
        schema_version='sporespore_canonical_velocity_compose_request_v1',
        descriptor=r23d60_selected_s169_quadruped(), source_actuation=a,
        ordered_stability_residuals=residuals))
    mapping = core.canonical_velocity_host_map_v1(dict(
        schema_version='sporespore_canonical_velocity_host_map_request_v1',
        descriptor=r23d60_selected_s169_quadruped(), canonical_actuation=canonical,
        host_profile=base._mujoco_host_profile(base.PER_ACTUATOR_VH5_CHARACTERIZED_PROFILE_ID)))
    require(not mapping['independent_native_position_feedback_applied'] and
            mapping['native_position_stiffness'] == 0, 'POSITION_FEEDBACK')
    for original, mapped in zip(a['ordered_commands'], mapping['ordered_commands']):
        require(mapped['actuator_id'] == original['actuator_id'] and
                mapped['native_target_position_rad'] is None and
                mapped['host_target_velocity_rad_s'] == -original['target_velocity_rad_s'], 'COMMAND_SIGN')
    return dict(canonical=canonical, mapping=mapping)


def compile_route(core):
    original = compile_recovery_morphology_model_route(core)
    tree = ET.fromstring(original.model_xml)
    ground = tree.find(".//geom[@name='ground']")
    require(ground is not None and ground.get('type') == 'plane', 'FLOOR_SOURCE')
    ground.set('type', 'box'); ground.set('size', '10 10 0.05'); ground.set('pos', '0 0 -0.05')
    for geom in tree.iter('geom'):
        old = geom.get('friction', '0.95 0.005 0.0001').split()
        require(len(old) == 3, 'FRICTION_SOURCE')
        geom.set('friction', '1.8 ' + ' '.join(old[1:]))
    xml = ET.tostring(tree, encoding='unicode')
    return replace(original, model_xml=xml), sha(original.model_xml.encode('utf-8'))


def build_input():
    plan = read(PLAN)
    require(plan['outer_steps'] == 400 and plan['native_step_limit'] == 2000 and
            plan['native_substeps_per_outer'] == 5 and plan['world_count'] == 1 and
            plan['child_wall_time_limit_s'] == 120 and
            all(plan[k] is False for k in FLAGS), 'PLAN_LIMIT_OR_AUTHORITY')
    require(mujoco.__version__ == plan['engine_version'] == '3.11.0', 'ENGINE_VERSION')
    require(file_binding(DLL)['sha256'] == DLL_SHA, 'DLL_BINDING')
    core = LocomotionCore(DLL)
    route, original_xml_sha = compile_route(core)
    report = source.report()
    require(report['configuration']['authored_friction'] == 1.8, 'SOURCE_FRICTION')
    entries = report['development_walking_entry']['rows']
    native = [r for r in report['development_native_walking_contacts']['rows'] if r['segment_id'] == 'walking_resume']
    require(len(entries) == len(native) == 400, 'SOURCE_POPULATION')
    rows = []
    for n, (entry, observation) in enumerate(zip(entries, native), 1):
        require(entry['session_local_step'] == observation['session_local_step'] == n, 'SOURCE_ORDER')
        mapped = canonical_mapping(core, entry['native_output']['actuation'])
        commands = mapped['mapping']['ordered_commands']
        require([c['actuator_id'] for c in commands] == list(caps.ORDERED_ACTUATOR_IDS), 'ACTUATOR_ORDER')
        wave = entry['native_output']['actuation']['receipt']['recovery_support_plane']['wave_velocity']['current_wave']
        rows.append(dict(command=n, targets=[c['host_target_velocity_rad_s'] for c in commands],
            composition=mapped, godot_motor_applications=entry['ordered_motor_applications'],
            source_stance={limb: bool(wave['active'] and wave['ordered_limbs'][i]['scheduled_phase_step'] > 72)
                           for i, limb in enumerate(LIMBS)},
            godot_precommand_contacts=observation['native_source']['precommand_trace']['contact_by_limb']))
    state = native[0]['native_source']['observation']['state']
    qpos, qvel = project_free_state(state)
    value = dict(schema_version='sporespore_v44_mujoco_fixed_command_input_v1', plan=plan,
        plan_sha256=file_binding(PLAN)['sha256'], source_report_sha256=source.REPORT_SHA,
        dll=file_binding(DLL), original_xml_sha256=original_xml_sha,
        replay_xml_sha256=sha(route.model_xml.encode('utf-8')),
        public_cap_mapping=route.host_mapping_receipt, ordered_caps_nms=list(caps.ORDERED_CAPS_NMS),
        initial_native_state=state, initial_source_body_states=entries[0]['ordered_body_states'],
        initial_source_walking_state=entries[0]['request']['state'],
        free_qpos=qpos.tolist(), free_qvel=qvel.tolist(), commands=rows, **FLAGS)
    return core, route, value


def body_snapshot(world):
    bodies = []
    bottoms = {}
    for body_id in world.morphology['ordered_body_ids']:
        pose, twist = world._body_pose_twist(body_id)
        bodies.append(dict(body_id=body_id, pose_world=pose, twist_world=twist))
        if body_id.endswith('_distal'):
            collision = world.body_specs[body_id]['collision']
            bottoms[body_id.removesuffix('_distal')] = (pose['position_m']['y'] -
                abs(rotation(pose['orientation_xyzw'])[1, 1])*collision['length_m']/2 - collision['radius_m'])
    joints = []
    for name in caps.ORDERED_JOINT_IDS:
        joint = world.joint_ids[name]
        joints.append(dict(joint_id=name, position_rad=float(world.data.qpos[world.model.jnt_qposadr[joint]]),
                           velocity_rad_s=float(world.data.qvel[world.model.jnt_dofadr[joint]])))
    return dict(bodies=bodies, joints=joints, nominal_capsule_bottom_m=bottoms)


def contacts(world, solved):
    result = []
    for i in range(int(world.data.ncon)):
        contact = world.data.contact[i]
        geoms = [int(contact.geom1), int(contact.geom2)]
        body_geom = next((g for g in geoms if g != world.ground_geom_id), None) if world.ground_geom_id in geoms else None
        body = world.body_ids_by_geom.get(body_geom)
        site = world._distal_foot_site_id(body) if body else None
        cap = bool(site and world._is_foot_cap_contact(body, np.asarray(contact.pos)))
        force = np.zeros(6)
        if solved:
            mujoco.mj_contactForce(world.model, world.data, i, force)
        result.append(dict(index=i, geoms=geoms, body_id=body,
            foot_site_id=site if cap else None, point_mujoco_m=np.asarray(contact.pos).tolist(),
            frame_mujoco=np.asarray(contact.frame).tolist(), distance_m=float(contact.dist),
            constraint_address=int(contact.efc_address), force_torque_contact_frame=force.tolist() if solved else None))
    return result


def bearing(contact_rows):
    return {limb: any(c['foot_site_id'] == limb+'_foot' and
        c['force_torque_contact_frame'] is not None and abs(c['force_torque_contact_frame'][0]) > 0
        for c in contact_rows) for limb in LIMBS}


def step_outer(world, targets, command):
    target = np.asarray(targets, dtype=float)
    require(target.shape == (8,) and np.all(np.isfinite(target)), 'TARGETS')
    steps = []
    for sub in range(5):
        mujoco.mj_step1(world.model, world.data)
        world.data.ctrl[:] = target
        require(np.array_equal(world.data.ctrl, target), 'CONTROL_READBACK')
        mujoco.mj_step2(world.model, world.data)
        require(np.all(np.isfinite(world.data.qpos)) and np.all(np.isfinite(world.data.qvel)), 'STATE_NONFINITE')
        require(not any(int(w.number) for w in world.data.warning), 'NATIVE_WARNING')
        expected = ((command-1)*5+sub+1)/600
        require(abs(world.data.time-expected) < 1e-10, 'NATIVE_CLOCK')
        force = np.asarray(world.data.actuator_force).copy()
        require(np.all(np.isfinite(force)) and np.all(np.abs(force)/120 <= np.asarray(caps.ORDERED_CAPS_NMS)+1e-12), 'FORCE_CAP')
        steps.append(dict(native_step=(command-1)*5+sub+1, time_s=float(world.data.time),
            controls=world.data.ctrl.tolist(), actuator_force_nm=force.tolist(), contacts=contacts(world, True)))
    # Refresh post-integration kinematics without taking another integration step.
    world.prepare()
    all_contacts = [c for step in steps for c in step['contacts']]
    return dict(command=command, substeps=steps, post=body_snapshot(world),
        post_geometry_contacts=contacts(world, False),
        any_substep_bearing=bearing(all_contacts), last_substep_bearing=bearing(steps[-1]['contacts']),
        absolute_actuator_impulse_nms=(np.abs([s['actuator_force_nm'] for s in steps]).sum(axis=0)/600).tolist())


def initialize(world, value):
    state = value['initial_native_state']
    world.data.qpos[:7] = value['free_qpos']
    world.data.qvel[:6] = value['free_qvel']
    require([j['joint_id'] for j in state['ordered_joint_observations']] == list(caps.ORDERED_JOINT_IDS), 'INITIAL_JOINT_ORDER')
    for observation in state['ordered_joint_observations']:
        joint = world.joint_ids[observation['joint_id']]
        world.data.qpos[world.model.jnt_qposadr[joint]] = observation['position_rad']
        world.data.qvel[world.model.jnt_dofadr[joint]] = observation['velocity_rad_s']
    mujoco.mj_forward(world.model, world.data)
    measured = body_snapshot(world)
    original = {b['body_id']: b for b in value['initial_source_body_states']}
    errors = []
    for body in measured['bodies']:
        old = original[body['body_id']]
        errors.append(dict(body_id=body['body_id'], center_error_m=float(np.linalg.norm(
            vector(body['pose_world']['position_m'])-vector(old['pose_world']['position_m']))),
            up_axis_error=float(np.linalg.norm(rotation(body['pose_world']['orientation_xyzw'])[:, 1] -
                                               rotation(old['pose_world']['orientation_xyzw'])[:, 1])),
            linear_velocity_error_m_s=float(np.linalg.norm(vector(body['twist_world']['linear_velocity_m_s'])-
                                                   vector(old['twist_world']['linear_velocity_m_s']))),
            angular_velocity_error_rad_s=float(np.linalg.norm(vector(body['twist_world']['angular_velocity_rad_s'])-
                                                   vector(old['twist_world']['angular_velocity_rad_s'])))))
    torso = measured['bodies'][0]
    require(errors[0]['center_error_m'] < 1e-12 and errors[0]['linear_velocity_error_m_s'] < 1e-10 and
            errors[0]['angular_velocity_error_rad_s'] < 1e-10 and
            np.max(np.abs(rotation(torso['pose_world']['orientation_xyzw'])-
                          rotation(state['base_pose_world']['orientation_xyzw']))) < 1e-12, 'FREE_STATE_READBACK')
    return dict(snapshot=measured, initial_contacts=contacts(world, True),
        projection_errors=errors, world_build_count=1, solver_step_count=0,
        model_identity=world.model_identity, morphology_readback=world.native_recovery_morphology_readback)


def validate_owner(ticket, value, parent_pid, nonce):
    require(ticket['parent_pid'] == parent_pid and ticket['nonce'] == nonce and len(nonce) == 32, 'CHILD_OWNER')
    require(ticket['input_sha256'] == sha(encoded(value)) and ticket['plan_sha256'] == file_binding(PLAN)['sha256'], 'CHILD_INPUT')
    require(ticket['gate_passed'] is True and all(ticket[k] is False for k in FLAGS), 'CHILD_GATE_OR_AUTHORITY')
    require(ticket['source'] == identity(), 'SOURCE_DRIFT')
    reopen(ticket['bindings'])


def worker(root):
    ticket, value = read(root/'ticket.json'), read(root/'input.json')
    validate_owner(ticket, value, os.getppid(), os.environ.get('SPORE_V44_REPLAY_NONCE', ''))
    core, route, reconstructed = build_input()
    require(encoded(reconstructed) == encoded(value), 'INPUT_RECONSTRUCTION')
    with (root/'replay.xml').open('xb') as stream:
        stream.write(route.model_xml.encode('utf-8'))
    write_new(root/'construction-intent.json', dict(pid=os.getpid(), world_limit=1, native_step_limit=2000))
    world = MujocoRecoveryMorphologyWorld(core, route, 'development-fixed-command-replay-no-portable-observation')
    initial = initialize(world, value)
    write_new(root/'initial.json', initial)
    with (root/'trajectory.jsonl').open('xb') as stream:
        for command in value['commands']:
            row = step_outer(world, command['targets'], command['command'])
            stream.write(encoded(row)); stream.flush()
    reopen(ticket['bindings'])
    require(ticket['source'] == identity(), 'SOURCE_DRIFT')
    write_new(root/'worker-receipt.json', dict(status='complete', parent_pid=os.getppid(), child_pid=os.getpid(),
        nonce=ticket['nonce'], input_sha256=ticket['input_sha256'], world_build_count=1,
        outer_steps=400, solver_step_count=2000, policy_feedback_call_count=0,
        random_draw_count=0, warnings=[int(w.number) for w in world.data.warning],
        initial=file_binding(root/'initial.json'), trajectory=file_binding(root/'trajectory.jsonl'), **FLAGS))


def verify_rows(rows, value):
    require(len(rows) == len(value['commands']) == 400, 'READER_POPULATION')
    for n, (row, command) in enumerate(zip(rows, value['commands']), 1):
        require(row['command'] == command['command'] == n and len(row['substeps']) == 5, 'READER_ORDER')
        for j, step in enumerate(row['substeps'], 1):
            require(step['native_step'] == (n-1)*5+j and abs(step['time_s']-((n-1)*5+j)/600) < 1e-10, 'READER_CLOCK')
            require(step['controls'] == command['targets'], 'READER_CONTROLS')
            require(len(step['actuator_force_nm']) == 8 and all(math.isfinite(f) and abs(f)/120 <= cap+1e-12
                for f, cap in zip(step['actuator_force_nm'], caps.ORDERED_CAPS_NMS)), 'READER_FORCES')
        impulse = np.abs([s['actuator_force_nm'] for s in row['substeps']]).sum(axis=0)/600
        require(np.allclose(impulse, row['absolute_actuator_impulse_nms'], atol=1e-14, rtol=0) and
                np.all(impulse <= np.asarray(caps.ORDERED_CAPS_NMS)+1e-12), 'READER_IMPULSE')
        require(row['any_substep_bearing'] == bearing([c for s in row['substeps'] for c in s['contacts']]) and
                row['last_substep_bearing'] == bearing(row['substeps'][-1]['contacts']), 'READER_CONTACTS')
        require(len(row['post']['bodies']) == 9 and len(row['post']['joints']) == 8, 'READER_STATE')
        require([b['body_id'] for b in row['post']['bodies']] ==
                [b['body_id'] for b in value['initial_source_body_states']] and
                [j['joint_id'] for j in row['post']['joints']] == list(caps.ORDERED_JOINT_IDS), 'READER_STATE_ORDER')
        for body in row['post']['bodies']:
            rotation(body['pose_world']['orientation_xyzw'])
            for field in (body['pose_world']['position_m'], *body['twist_world'].values()):
                require(np.all(np.isfinite(vector(field))), 'READER_BODY_NONFINITE')
        encoded(row)  # Reject nonfinite serialized state/contact samples too.


def read_result(root):
    ticket, value, receipt = (read(root/name) for name in ('ticket.json', 'input.json', 'worker-receipt.json'))
    require(receipt['status'] == 'complete' and all(receipt[k] is False for k in FLAGS), 'READER_AUTHORITY')
    require(receipt['nonce'] == ticket['nonce'] and receipt['parent_pid'] == ticket['parent_pid'] and
            receipt['child_pid'] == read(root/'launch.json')['child_pid'] and
            receipt['input_sha256'] == ticket['input_sha256'] == sha(encoded(value)), 'READER_IDENTITY')
    require((receipt['world_build_count'], receipt['outer_steps'], receipt['solver_step_count'],
        receipt['policy_feedback_call_count'], receipt['random_draw_count']) == (1,400,2000,0,0) and
        not any(receipt['warnings']), 'READER_BOUNDS')
    reopen(ticket['bindings']); reopen([receipt['initial'], receipt['trajectory']])
    rows = [json.loads(line) for line in (root/'trajectory.jsonl').read_text(encoding='utf-8').splitlines()]
    verify_rows(rows, value)
    per_limb = []
    for limb in LIMBS:
        item = dict(limb=limb)
        for channel in ('any_substep_bearing', 'last_substep_bearing'):
            lost, intervals = None, []
            for n, row in enumerate(rows, 1):
                if not row[channel][limb] and lost is None:
                    lost = n
                if lost is not None and (row[channel][limb] or n == 400):
                    end = n-1 if row[channel][limb] else n
                    intervals.append(dict(first_absent=lost, last_absent=end, count=end-lost+1,
                        recontact=n if row[channel][limb] else None, initial_absence_censored=lost == 1,
                        source_stance_at_onset=value['commands'][lost-1]['source_stance'][limb]))
                    lost = None
            item[channel] = dict(absent_count=sum(not r[channel][limb] for r in rows),
                absent_source_stance_count=sum(not r[channel][limb] and c['source_stance'][limb]
                                              for r,c in zip(rows,value['commands'])), intervals=intervals)
        item['minimum_nominal_capsule_bottom_m'] = min(r['post']['nominal_capsule_bottom_m'][limb] for r in rows)
        item['maximum_nominal_capsule_bottom_m'] = max(r['post']['nominal_capsule_bottom_m'][limb] for r in rows)
        per_limb.append(item)
    return dict(schema_version='sporespore_v44_mujoco_fixed_command_reader_v1', status='valid_development_observation',
        world_count_during_read=0, solver_step_count_during_read=0, original_receipt=file_binding(root/'worker-receipt.json'),
        per_limb=per_limb, initial_projection=read(root/'initial.json'), terminal=rows[-1]['post'],
        limitations=value['plan']['not_covered'], **FLAGS)


def run_owned(command, root, label, timeout, env=None):
    started = time.monotonic()
    # Windows venv python.exe is a redirector, so Popen.pid would identify the
    # launcher instead of the worker. Own the real interpreter directly and
    # explicitly select the already-bound venv packages for that child.
    require(Path(command[0]).resolve() == Path(sys.executable).resolve(), 'CHILD_EXECUTABLE')
    command = [str(Path(sys._base_executable).resolve()), '-s', *command[1:]]
    env = dict(os.environ if env is None else env)
    for name in ('__PYVENV_LAUNCHER__', 'PYTHONHOME', 'PYTHONEXECUTABLE'):
        env.pop(name, None)
    env['PYTHONPATH'] = str(ROOT/'sdk/adapters/mujoco/.venv/Lib/site-packages')
    env['PYTHONNOUSERSITE'] = '1'
    with (root/(label+'.stdout')).open('xb') as stdout, (root/(label+'.stderr')).open('xb') as stderr:
        child = subprocess.Popen(command, cwd=ROOT, env=env, stdout=stdout, stderr=stderr,
                                 creationflags=subprocess.CREATE_NO_WINDOW)
        write_new(root/(label+'-launch.json'), dict(child_pid=child.pid, parent_pid=os.getpid(), command=command))
        try:
            code = child.wait(timeout=timeout)
            result = dict(exit_code=code, timed_out=False)
        except subprocess.TimeoutExpired:
            child.kill(); child.wait(timeout=10)
            result = dict(exit_code=child.returncode, timed_out=True)
    result.update(child_pid=child.pid, elapsed_s=time.monotonic()-started)
    write_new(root/(label+'-exit.json'), result)
    require(not result['timed_out'] and result['exit_code'] == 0, label.upper()+'_FAILED')
    return result


def launch(physical):
    root = EVIDENCE / ('development-v44-mujoco-replay-' + uuid.uuid4().hex)
    root.mkdir(exist_ok=False)
    result = dict(status='gate_or_launch_refused', evidence_root=str(root), **FLAGS)
    try:
        with OperationLock() as lock:
            source_identity = identity(clean=physical)
            bindings = dependency_bindings()
            write_new(root/'preflight.json', dict(source=source_identity, bindings=bindings, lock=lock.receipt, **FLAGS))
            for binding in bindings:
                path = Path(binding['path'])
                if path.is_relative_to(ROOT) and '.venv' not in path.parts:
                    retained = root/'tested-source'/path.relative_to(ROOT)
                    retained.parent.mkdir(parents=True, exist_ok=True)
                    with retained.open('xb') as stream:
                        stream.write(path.read_bytes())
            _, _, value = build_input()
            write_new(root/'input.json', value)
            env = dict(os.environ, SPORE_V44_GATE_ROOT=str(root))
            run_owned([sys.executable, str(ROOT/'tests/test_development_v44_mujoco_replay.py')], root, 'gate', 120, env)
            reopen(bindings); require(source_identity == identity(), 'SOURCE_DRIFT')
            if physical:
                ticket = dict(parent_pid=os.getpid(), nonce=uuid.uuid4().hex,
                    input_sha256=sha(encoded(value)), plan_sha256=file_binding(PLAN)['sha256'],
                    gate_passed=True, source=source_identity, bindings=bindings, **FLAGS)
                write_new(root/'ticket.json', ticket)
                env = dict(os.environ, SPORE_V44_REPLAY_NONCE=ticket['nonce'])
                child = run_owned([sys.executable, str(Path(__file__)), '--worker', str(root)], root, 'worker', 120, env)
                write_new(root/'launch.json', dict(child_pid=child['child_pid']))
                # Separate process cold-reader: no model construction is allowed.
                run_owned([sys.executable, str(Path(__file__)), '--read', str(root)], root, 'reader', 120)
                result.update(status='closed_valid_development_observation', reader=file_binding(root/'reader.json'))
            else:
                result.update(status='zero_world_gate_passed')
            reopen(bindings); require(source_identity == identity(), 'SOURCE_DRIFT')
    except Exception as error:
        result.update(error=str(error), traceback=traceback.format_exc())
    write_new(root/'supervisor.json', result)
    print(json.dumps(result), flush=True)
    return 0 if result['status'] in ('zero_world_gate_passed', 'closed_valid_development_observation') else 1


def main():
    parser = argparse.ArgumentParser(__doc__)
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument('--gate', action='store_true'); modes.add_argument('--run', action='store_true')
    modes.add_argument('--worker', type=Path); modes.add_argument('--read', type=Path)
    args = parser.parse_args()
    if args.worker:
        worker(args.worker.resolve()); return 0
    if args.read:
        from unittest.mock import patch
        with patch.object(mujoco, 'MjModel', side_effect=AssertionError('READER_WORLD_FORBIDDEN')), \
             patch.object(mujoco, 'MjData', side_effect=AssertionError('READER_DATA_FORBIDDEN')):
            write_new(args.read/'reader.json', read_result(args.read.resolve()))
        return 0
    return launch(args.run)


if __name__ == '__main__':
    sys.exit(main())
