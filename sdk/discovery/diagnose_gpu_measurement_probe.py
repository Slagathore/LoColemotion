"""Explain a retained scalar probe without changing its capture or pass rules."""
import argparse
import csv
import hashlib
import json
from pathlib import Path

from audit_gpu_measurement_probe import audit


def diagnose(physical: Path):
    checked = audit(physical)
    with (physical/'trace.csv').open(newline='') as stream:
        rows = list(csv.DictReader(stream))
    indexed = {(r['backend'], int(r['cell']), int(r['step'])): r for r in rows}
    per_cell = []
    local_residual = {'cpu': 0., 'gpu': 0.}
    for cell in range(8):
        switches = []
        maximum = 0.
        for step in range(1, 121):
            cpu, gpu = indexed['cpu', cell, step], indexed['gpu', cell, step]
            maximum = max(maximum, abs(float(cpu['after_rad_s'])-float(gpu['after_rad_s'])))
            if (abs(float(cpu['completed_step_force_nm'])) >= 6) != (abs(float(gpu['completed_step_force_nm'])) >= 6):
                switches.append(dict(step=step, cpu=cpu, gpu=gpu))
            for backend, row in [('cpu', cpu), ('gpu', gpu)]:
                force = float(row['completed_step_force_nm'])
                # Use each backend's observed branch and state. This separates
                # local integration error from trajectory divergence; it does
                # not erase the divergence or claim bitwise GPU arithmetic.
                effective_inertia = 1/60 if abs(force) >= 6 else 1/60+10/600
                prediction = float(row['before_rad_s']) + force/600/effective_inertia
                error = abs(prediction-float(row['after_rad_s']))
                local_residual[backend] = max(local_residual[backend], error)
        per_cell.append(dict(cell=cell, maximum_velocity_difference_rad_s=maximum,
                             clamp_branch_mismatches=switches))
    return dict(schema_version='sporespore_gpu_clamp_diagnosis_v1',
                ledger_scope=dict(subsystem='discovery', engine_scope='mujoco_cpu_and_warp',
                                  authority_mode='retained_trace_diagnosis', question_class='development'),
                source_trace_sha256=hashlib.sha256((physical/'trace.csv').read_bytes()).hexdigest(),
                audited_rows=checked['rows'], per_cell=per_cell,
                observed_branch_scalar_equation_max_residual_rad_s=local_residual,
                interpretation='Observed clamp-branch differences can amplify input/state rounding. Local branch consistency does not make divergent trajectories equivalent. Preserve branch-sensitive counterexamples in future training and native transfer tests.',
                new_worlds=0, thresholds_changed=False, equivalence_authority=False,
                physical_acceptance_authority=False, training_data_authority=False, release_authority=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('physical_directory', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = diagnose(args.physical_directory)
    with args.output.open('x', encoding='utf-8', newline='\n') as stream:
        json.dump(result, stream, indent=2, allow_nan=False)
        stream.write('\n')
    print(json.dumps(dict(output=str(args.output), rows=result['audited_rows'],
                         residual=result['observed_branch_scalar_equation_max_residual_rad_s'])))
