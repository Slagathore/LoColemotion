"""One contained, bounded CPU/GPU measurement probe; no training/acceptance claim."""
from __future__ import annotations

import argparse
import csv
import hashlib
import importlib.metadata
import json
from pathlib import Path
import random
import sys
import time
import xml.etree.ElementTree as ET

from actuation_measurement import finite, named_force_samples

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
CONTRACT = HERE / 'gpu_measurement_probe_v1.json'
FIELDS = ['backend', 'cell', 'step', 'time_s', 'target_rad_s', 'before_rad_s',
          'after_rad_s', 'completed_step_force_nm', 'joint_force_nm',
          'post_state_force_nm', 'scalar_net_impulse_nms']


def load_contract():
    value = json.loads(CONTRACT.read_text(encoding='utf-8'))
    if (value['schema_version'] != 'sporespore_gpu_measurement_probe_v1'
            or value['worlds_per_backend'] != 8 or value['steps_per_world'] != 120
            or value['cuda_graph'] is not False or value['device'] != 'cuda:0'
            or any(value[k] is not False for k in ['physical_acceptance_authority',
                'release_authority', 'equivalence_authority', 'training_data_authority'])):
        raise ValueError('Probe contract or authority mismatch')
    return value


def model_xml(contract):
    return f'''<mujoco model="sdk2_scalar_measurement">
  <option timestep="{contract['timestep_s']:.17g}" gravity="0 0 0" integrator="implicitfast" solver="Newton"/>
  <worldbody><body name="rotor">
    <inertial pos="0 0 0" mass="1" diaginertia="{contract['inertia_kg_m2']:.17g} {contract['inertia_kg_m2']:.17g} {contract['inertia_kg_m2']:.17g}"/>
    <joint name="hinge" type="hinge" axis="0 0 1" damping="0"/>
    <geom type="sphere" size="0.1" contype="0" conaffinity="0"/>
  </body></worldbody>
  <actuator><velocity name="motor" joint="hinge" kv="10" forcelimited="true" forcerange="-6 6"/></actuator>
  <sensor><actuatorfrc name="motor_force" actuator="motor"/>
    <jointactuatorfrc name="hinge_actuator_force" joint="hinge"/></sensor>
</mujoco>'''


def inputs(contract):
    generator = random.Random(contract['seed'])
    return dict(initial_velocities=[generator.uniform(-.2, .2) for _ in range(8)],
                targets=[-.75, -.6, -.1, 0., .1, .6, .75, 1.], reverse_after_step=60)


def zero_world():
    """Check packages, source/model declaration and sensor API without a model."""
    contract = load_contract()
    versions = {name: importlib.metadata.version(name) for name in contract['runtime']}
    if versions != contract['runtime']:
        raise ValueError('Pinned runtime versions differ')
    import mujoco
    tree = ET.fromstring(model_xml(contract))
    if (len(tree.findall('.//joint')) != 1 or len(tree.findall('.//sensor/*')) != 2
            or not hasattr(mujoco.mjtSensor, 'mjSENS_JOINTACTFRC')):
        raise ValueError('Scalar model or named sensor API mismatch')
    return dict(ok=True, versions=versions, world_build_count=0, solver_steps=0,
                contract_sha256=hashlib.sha256(CONTRACT.read_bytes()).hexdigest())


def write_new(path, value):
    with path.open('x', encoding='utf-8', newline='\n') as stream:
        json.dump(value, stream, indent=2, allow_nan=False)
        stream.write('\n')


def run(folder, permit):
    # No model construction above this boundary. The supervisor provides the
    # permit only after assigning its process tree to a kill-on-close job.
    sys.path.insert(0, str(ROOT / 'sdk/conformance'))
    import r10v_windows_job as jobs
    if not permit.is_file() or not jobs.current_in_job():
        raise ValueError('GPU probe requires owned process containment')
    zero_world()
    import mujoco
    import numpy as np
    import warp as wp
    import mujoco_warp as mjw

    contract = load_contract()
    specification = inputs(contract)
    write_new(folder / 'inputs.json', specification)
    xml = model_xml(contract)
    (folder / 'model.xml').write_text(xml, encoding='utf-8', newline='\n')
    started = time.perf_counter()
    model = mujoco.MjModel.from_xml_string(xml)
    if (model.nq, model.nv, model.nu, model.nsensordata) != (1, 1, 1, 2):
        raise ValueError('Unexpected scalar topology')
    initial = np.asarray(specification['initial_velocities'], dtype=np.float64)
    targets = np.asarray(specification['targets'], dtype=np.float64)
    trace_path = folder / 'trace.csv'
    timings = {}
    with trace_path.open('x', newline='', encoding='utf-8') as trace:
        writer = csv.DictWriter(trace, fieldnames=FIELDS)
        writer.writeheader()
        cpu_start = time.perf_counter()
        for cell in range(8):
            data, observation = mujoco.MjData(model), mujoco.MjData(model)
            data.qvel[0] = initial[cell]
            for step in range(1, 121):
                target = targets[cell] * (1 if step <= 60 else -1)
                before = float(data.qvel[0])
                mujoco.mj_step1(model, data)
                data.ctrl[0] = target
                mujoco.mj_step2(model, data)
                completed = named_force_samples(model, data, 'motor', 'hinge')
                after = float(data.qvel[0])
                # Recompute on a separate state so the simulation's completed
                # force and warm-start state are not overwritten for display.
                mujoco.mj_copyData(observation, model, data)
                mujoco.mj_forward(model, observation)
                post = named_force_samples(model, observation, 'motor', 'hinge')
                row = dict(backend='cpu', cell=cell, step=step, time_s=float(data.time),
                    target_rad_s=float(target), before_rad_s=before, after_rad_s=after,
                    completed_step_force_nm=completed['actuator_force_nm'],
                    joint_force_nm=completed['joint_actuator_force_nm'],
                    post_state_force_nm=post['actuator_force_nm'],
                    scalar_net_impulse_nms=contract['inertia_kg_m2'] * (after-before))
                check_row(row)
                writer.writerow(row)
            trace.flush()
        timings['cpu_execution_and_capture_s'] = time.perf_counter()-cpu_start

        gpu_start = time.perf_counter()
        wp.config.kernel_cache_dir = str(folder / 'warp-cache')
        wp.init()
        device = wp.get_device(contract['device'])
        if not device.is_cuda:
            raise ValueError('CUDA device unavailable')
        with wp.ScopedDevice(device):
            gpu_model = mjw.put_model(model)
            gpu_data = mjw.put_data(model, mujoco.MjData(model), nworld=8)
            wp.copy(gpu_data.qvel, wp.array(initial[:, None].astype(np.float32), dtype=wp.float32, device=device))
            actuator_sensor = int(model.sensor_adr[model.sensor('motor_force').id])
            joint_sensor = int(model.sensor_adr[model.sensor('hinge_actuator_force').id])
            timings['gpu_setup_s'] = time.perf_counter()-gpu_start
            step_costs = []
            for step in range(1, 121):
                target = targets * (1 if step <= 60 else -1)
                projected_target = target.astype(np.float32)
                before = gpu_data.qvel.numpy().copy()[:, 0]
                wp.copy(gpu_data.ctrl, wp.array(projected_target[:, None], dtype=wp.float32, device=device))
                tick = time.perf_counter()
                mjw.step(gpu_model, gpu_data)
                wp.synchronize_device(device)
                step_costs.append(time.perf_counter()-tick)
                after = gpu_data.qvel.numpy().copy()[:, 0]
                samples = gpu_data.sensordata.numpy().copy()
                native_times = gpu_data.time.numpy().copy()
                # Affine one-hinge post-state evaluation; no generic claim
                # about effective multi-body forces or contact impulse.
                post = np.clip(10 * (projected_target-after), -6, 6)
                for cell in range(8):
                    row = dict(backend='gpu', cell=cell, step=step,
                        time_s=float(native_times[cell]), target_rad_s=float(projected_target[cell]),
                        before_rad_s=float(before[cell]), after_rad_s=float(after[cell]),
                        completed_step_force_nm=float(samples[cell, actuator_sensor]),
                        joint_force_nm=float(samples[cell, joint_sensor]),
                        post_state_force_nm=float(post[cell]),
                        scalar_net_impulse_nms=contract['inertia_kg_m2'] * float(after[cell]-before[cell]))
                    check_row(row)
                    writer.writerow(row)
                trace.flush()
            timings['gpu_first_step_including_jit_s'] = step_costs[0]
            timings['gpu_later_steps_including_sync_s'] = sum(step_costs[1:])
            timings['gpu_setup_execution_transfers_capture_s'] = time.perf_counter()-gpu_start
        device_info = dict(alias=device.alias, name=device.name, architecture=device.arch)
    result = dict(ok=True, status='completed_measurement_not_equivalence',
        ledger_scope=contract['ledger_scope'], versions=contract['runtime'], device=device_info,
        cpu_worlds=8, gpu_worlds=8, solver_steps_per_backend=960, timings=timings,
        total_wall_s=time.perf_counter()-started,
        trace_sha256=hashlib.sha256(trace_path.read_bytes()).hexdigest(),
        physical_acceptance_authority=False, release_authority=False, training_data_authority=False)
    write_new(folder / 'worker-result.json', result)


def check_row(row):
    for name in FIELDS[3:]:
        finite(row[name], name)
    if abs(row['completed_step_force_nm']) > 6.00001 or abs(row['joint_force_nm']) > 6.00001:
        raise ValueError('Native force limit violated')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check-only', action='store_true')
    parser.add_argument('--output', type=Path)
    parser.add_argument('--permit', type=Path)
    args = parser.parse_args()
    if args.check_only:
        print(json.dumps(zero_world()))
    elif args.output is None or args.permit is None:
        parser.error('Use the supervisor; output and containment permit required')
    else:
        run(args.output.resolve(), args.permit.resolve())
