"""Read every probe row independently; numeric disagreement is not equivalence."""
import csv
import hashlib
import json
import math
from pathlib import Path
import random
import struct

from actuation_measurement import scalar_implicitfast_step


def f32(value):
    return struct.unpack('<f', struct.pack('<f', value))[0]


def audit(folder: Path):
    declaration = json.loads((folder.parent / 'declaration.json').read_text())
    contract = declaration['contract']
    inputs = json.loads((folder / 'inputs.json').read_text())
    result = json.loads((folder / 'worker-result.json').read_text())
    rng = random.Random(contract['seed'])
    if inputs != dict(initial_velocities=[rng.uniform(-.2, .2) for _ in range(8)],
                      targets=[-.75, -.6, -.1, 0., .1, .6, .75, 1.], reverse_after_step=60):
        raise ValueError('Input population differs from prospective declaration')
    if (result['cpu_worlds'], result['gpu_worlds'], result['solver_steps_per_backend']) != (8, 8, 960):
        raise ValueError('Worker counter mismatch')
    raw = (folder / 'trace.csv').read_bytes()
    if hashlib.sha256(raw).hexdigest() != result['trace_sha256']:
        raise ValueError('Trace digest mismatch')
    if result['ok'] is not True or any(result[k] is not False for k in
            ['physical_acceptance_authority', 'release_authority', 'training_data_authority']):
        raise ValueError('Worker completion or authority mismatch')
    with (folder / 'trace.csv').open(newline='') as stream:
        rows = list(csv.DictReader(stream))
    expected = {(backend, cell, step) for backend in ['cpu', 'gpu']
                for cell in range(8) for step in range(1, 121)}
    by_key = {}
    cpu_oracle_error = 0.
    sensor_error = 0.
    for row in rows:
        key = row['backend'], int(row['cell']), int(row['step'])
        if key not in expected or key in by_key:
            raise ValueError('Missing, extra or repeated batch member')
        numeric = {k: float(v) for k, v in row.items() if k not in ['backend', 'cell', 'step']}
        if not numeric or any(not math.isfinite(v) for v in numeric.values()):
            raise ValueError('Nonfinite measurement')
        backend, cell, step = key
        project = f32 if backend == 'gpu' else float
        target = project(inputs['targets'][cell] * (1 if step <= 60 else -1))
        if numeric['target_rad_s'] != target:
            raise ValueError('Crossed command or batch identity')
        initial = project(inputs['initial_velocities'][cell])
        prior = by_key.get((backend, cell, step-1))
        before = initial if step == 1 else prior['after_rad_s'] if prior else None
        if numeric['before_rad_s'] != before:
            raise ValueError('Missing or discontinuous step')
        # Bound repeated floating-point time addition, not behavioral drift.
        epsilon = 2**-23 if backend == 'gpu' else 2**-52
        if abs(numeric['time_s']-step*contract['timestep_s']) > 4*epsilon*step*step*contract['timestep_s']:
            raise ValueError('Native clock mismatch')
        sensor_error = max(sensor_error, abs(numeric['completed_step_force_nm']-numeric['joint_force_nm']))
        if abs(numeric['completed_step_force_nm']) > 6+32*epsilon:
            raise ValueError('Force cap violated')
        if backend == 'cpu':
            oracle = scalar_implicitfast_step(velocity=before, target=target,
                inertia=contract['inertia_kg_m2'], damping=10., force_cap=6., dt=contract['timestep_s'])
            for measured, predicted in [('after_rad_s', 'velocity_next_rad_s'),
                    ('completed_step_force_nm', 'completed_step_force_nm'),
                    ('post_state_force_nm', 'post_state_force_nm'),
                    ('scalar_net_impulse_nms', 'effective_motor_impulse_nms')]:
                cpu_oracle_error = max(cpu_oracle_error, abs(numeric[measured]-oracle[predicted]))
        by_key[key] = numeric
    if set(by_key) != expected or len(rows) != 1920:
        raise ValueError('Incomplete denominator')
    if cpu_oracle_error > 2e-12 or sensor_error > 2e-6:
        raise ValueError('Scalar measurement semantics mismatch')
    maxima = {}
    for name in ['after_rad_s', 'completed_step_force_nm', 'post_state_force_nm', 'scalar_net_impulse_nms']:
        maxima[name] = max(abs(by_key['cpu', cell, step][name]-by_key['gpu', cell, step][name])
                           for cell in range(8) for step in range(1, 121))
    return dict(ok=True, status='complete_finite_measurement', rows=1920,
                cpu_worlds=8, gpu_worlds=8, cpu_scalar_oracle_max_error=cpu_oracle_error,
                named_sensor_max_disagreement_nm=sensor_error, cpu_gpu_max_absolute_difference=maxima,
                interpretation='Differences include CPU float64 versus GPU float32 input projection. No equivalence margin or acceptance test is asserted.',
                physical_acceptance_authority=False, release_authority=False, training_data_authority=False)


def verify_closure(closure_path: Path, evidence_root: Path):
    """Authenticate the retained attempt and recompute its independent audit."""
    closure = json.loads(closure_path.read_text())
    evidence_root = evidence_root.resolve()
    seen = set()
    for artifact in closure['artifacts']:
        relative = artifact['evidence_relative_path']
        path = (evidence_root/relative).resolve()
        if relative in seen or not path.is_relative_to(evidence_root):
            raise ValueError('Duplicate or escaping evidence path')
        seen.add(relative)
        raw = path.read_bytes()
        if len(raw) != artifact['byte_length'] or hashlib.sha256(raw).hexdigest() != artifact['sha256']:
            raise ValueError('Retained artifact changed: '+relative)
    attempt = (evidence_root/closure['attempt_id']).resolve()
    required = ['receipt.json', 'declaration.json', 'consumed.json', 'independent-audit.json',
                'physical/trace.csv', 'physical/inputs.json', 'physical/worker-result.json',
                'physical/model.xml', 'physical/stdout.log', 'physical/stderr.log']
    if not attempt.is_relative_to(evidence_root) or any(closure['attempt_id']+'/'+p not in seen for p in required):
        raise ValueError('Incomplete closure inventory')
    receipt = json.loads((attempt/'receipt.json').read_text())
    if receipt['ok'] is not True or receipt['source_commit'] != closure['source_commit']:
        raise ValueError('Attempt source or completion mismatch')
    observed = audit(attempt/'physical')
    if observed != closure['independent_audit']:
        raise ValueError('Independent audit changed')
    for flag in ['physical_acceptance_authority', 'release_authority', 'equivalence_authority', 'training_data_authority']:
        if closure[flag] is not False:
            raise ValueError('Closure authority changed')
    return dict(ok=True, verified_artifacts=len(seen), rows=observed['rows'],
                source_commit=closure['source_commit'], new_worlds=0)
