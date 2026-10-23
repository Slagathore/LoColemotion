"""Pure input/shape contract for the contact-bearing GPU commissioning route."""
import hashlib
import importlib.metadata
import json
import math
from pathlib import Path
import random
import struct
import sys
import xml.etree.ElementTree as ET
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
CONTRACT = HERE/'gpu_quadruped_probe_v1.json'
FLAGS = ['physical_acceptance_authority', 'release_authority', 'equivalence_authority', 'training_data_authority']


def sha(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def f32(value):
    return struct.unpack('<f', struct.pack('<f', value))[0]


def load_contract():
    c = json.loads(CONTRACT.read_text())
    if (c['schema_version'] != 'locolemotion_gpu_quadruped_probe_v1'
            or c['worlds_per_backend'] != 4 or c['steps_per_world'] != 1200
            or c['cuda_graph'] is not False or any(c[k] is not False for k in FLAGS)):
        raise ValueError('Quadruped probe declaration changed')
    return c


def build_inputs(core, contract):
    """Use the public morphology compiler and existing XML builder, zero worlds."""
    if sha(core) != contract['core_sha256']:
        raise ValueError('Core image differs from prospective binding')
    sys.path.insert(0, str(ROOT/'sdk/explorer'))
    sys.path.insert(0, str(ROOT/'sdk/adapters/mujoco'))
    from showcase_model import Compiler, S169
    from sporespore_mujoco_adapter import selected_policy_development as bridge
    compiled = Compiler(core).compile(S169)
    if compiled['world_build_count'] != 0:
        raise ValueError('Morphology compiler constructed a world')
    xml = bridge.build_model_xml(compiled, bridge.PER_ACTUATOR_DEVELOPMENT_PROFILE_ID)
    tree = ET.fromstring(xml)
    tree.set('model', 'sdk2_gpu_quadruped_probe_v1')
    motors = list(tree.findall('actuator/velocity'))
    joints = list(tree.findall('.//joint'))
    if len(motors) != 8 or len(joints) != 8 or len(tree.findall('.//body')) != 9 or len(tree.findall('.//freejoint')) != 1:
        raise ValueError('Unexpected compiled topology')
    if [r.attrib['joint'] for r in motors] != [r.attrib['name'] for r in joints]:
        raise ValueError('Compiled actuator/joint ordering changed')
    sensor = ET.SubElement(tree, 'sensor')
    for motor in motors:
        ET.SubElement(sensor, 'actuatorfrc', name=motor.attrib['name']+'_force', actuator=motor.attrib['name'])
        ET.SubElement(sensor, 'jointactuatorfrc', name=motor.attrib['joint']+'_actuator_force', joint=motor.attrib['joint'])
    rng = random.Random(contract['seed'])
    qpos = [float(x) for x in tree.find('worldbody/body').attrib['pos'].split()] + [1., 0., 0., 0.] + [0.]*8
    spec = dict(initial_qpos=qpos, initial_lateral_velocities=[rng.uniform(-.005, .005) for _ in range(4)],
                ordered_actuators=[r.attrib['name'] for r in motors], ordered_joints=[r.attrib['joint'] for r in motors],
                force_ranges=[[float(x) for x in r.attrib['forcerange'].split()] for r in motors],
                geom_names=[r.attrib['name'] for r in tree.findall('.//geom')])
    return compiled, ET.tostring(tree, encoding='unicode')+'\n', spec


def controls(contract, cell, step, qpos, gpu=False):
    if len(qpos) != 15 or not all(math.isfinite(x) for x in qpos):
        raise ValueError('Invalid feedback state')
    p = contract['control']; c = p['cells'][cell]
    phase = 2*math.pi*p['frequency_hz']*(step-1)*contract['timestep_s']
    targets = []
    for limb, offset in enumerate(p['limb_phase_pi']):
        angle = phase + math.pi*offset
        references = [c['hip_amplitude_rad']*math.sin(angle),
                      p['knee_offset_rad'] + c['knee_amplitude_rad']*(1-math.cos(angle))/2]
        for joint, reference in enumerate(references):
            value = p['gain_per_s']*(reference-qpos[7+2*limb+joint])
            value = max(-p['velocity_limit_rad_s'], min(p['velocity_limit_rad_s'], value))
            targets.append(f32(value) if gpu else value)
    return targets


def split_contacts(count, worlds, geoms, distances, positions, *, nworld, capacity):
    """Global GPU contact ordering is arbitrary; world id, not slot, assigns it."""
    if not 0 <= count <= capacity or any(len(x) < count for x in [worlds, geoms, distances, positions]):
        raise ValueError('Contact buffer overflow or incomplete capture')
    result = [[] for _ in range(nworld)]
    for index in range(count):
        world = int(worlds[index]); pair = [int(x) for x in geoms[index]]
        values = [float(distances[index]), *[float(x) for x in positions[index]]]
        if world != worlds[index] or not 0 <= world < nworld or len(pair) != 2 or any(not 0 <= x < 10 for x in pair):
            raise ValueError('Crossed native contact identity')
        if len(values) != 4 or not all(math.isfinite(x) for x in values):
            raise ValueError('Nonfinite native contact')
        result[world].append(dict(native_index=index, world=world, geom=pair, distance_m=values[0], position_m=values[1:]))
    return result


def zero_world(core):
    import mujoco
    c = load_contract()
    versions = {name: importlib.metadata.version(name) for name in c['runtime']}
    if versions != c['runtime']:
        raise ValueError('Pinned package versions changed')
    if int(mujoco.mjtWarning.mjNWARNING) != c['cpu_warning_count']:
        raise ValueError('Native warning population changed')
    with patch.object(mujoco, 'MjModel', side_effect=AssertionError('World in preflight')), \
            patch.object(mujoco, 'MjData', side_effect=AssertionError('Data in preflight')):
        compiled, xml, spec = build_inputs(core, c)
        if hashlib.sha256(xml.encode()).hexdigest()!=c['model_xml_sha256'] or compiled['descriptor_sha256']!=c['descriptor_sha256']:
            raise ValueError('Compiled model differs from prospective pin')
        for cell in range(4):
            controls(c, cell, 1, spec['initial_qpos'], True)
    return dict(ok=True, world_build_count=0, solver_steps=0, runtime=versions,
                xml_sha256=hashlib.sha256(xml.encode()).hexdigest(), descriptor_sha256=compiled['descriptor_sha256'],
                topology=dict(bodies=9,free_joints=1,hinges=8,actuators=8,named_force_sensors=16))
