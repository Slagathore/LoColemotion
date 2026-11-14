"""Read retained prediction errors independently; no simulation or model import."""
import argparse
import hashlib
import json
import math
from pathlib import Path

from creature_trajectory_diagnosis import Archive, require


def near(a, b):
    return math.isfinite(a) and math.isfinite(b) and math.isclose(a, b, rel_tol=1e-12, abs_tol=1e-12)


def native_velocity(row):
    """Rotate the native local angular velocity with scalar quaternion algebra."""
    q = row['qpos'][3:7]; length = math.sqrt(math.fsum(x*x for x in q))
    w, x, y, z = [v/length for v in q]; v = row['qvel']; a, b, c = v[3:6]
    t = (2*(y*c-z*b), 2*(z*a-x*c), 2*(x*b-y*a))
    angular = (a+w*t[0]+y*t[2]-z*t[1], b+w*t[1]+z*t[0]-x*t[2], c+w*t[2]+x*t[1]-y*t[0])
    return [v[0], v[2], -v[1], angular[0], angular[2], -angular[1], *v[6:]]


def aggregate(rows, plan, result, expected):
    require(len(rows) == plan['expected_samples'] and
            [(r['batch'], r['cell_id'], r['outer_step']) for r in rows] == expected,
            'Response sample identity, order or denominator')
    groups = {}; maximum_geometry = maximum_kinetic = 0.
    for row in rows:
        require(set(row['predictions']) == set(plan['variants']), 'Response variant population')
        actual = row['native_velocity']; require(len(actual) == 14, 'Response velocity width')
        require(all(math.isfinite(v) and v >= 0 for v in row['checks'].values()), 'Response finite validation error')
        maximum_geometry = max(maximum_geometry, row['checks']['geometry_error_m'])
        maximum_kinetic = max(maximum_kinetic, row['checks']['kinetic_error_j'])
        for name, prediction in row['predictions'].items():
            require(len(prediction['velocity']) == 14, 'Response predicted velocity width')
            difference = [a-b for a,b in zip(prediction['velocity'], actual, strict=True)]
            require(all(math.isfinite(v) for v in difference), 'Response finite velocity')
            for field, values in (('root_angular_error_rad_s', difference[3:6]),
                                  ('root_linear_error_m_s', difference[:3]),
                                  ('joint_velocity_error_rad_s', difference[6:])):
                require(near(math.sqrt(math.fsum(x*x for x in values)), prediction[field]), 'Response error norm')
            residual = prediction['kkt_residual']
            require(math.isfinite(residual) and residual >= 0 and
                    prediction['converged'] == (residual <= plan['parameters']['kkt_tolerance']*10), 'Response convergence receipt')
            groups.setdefault((row['batch'], name), []).append(prediction)
    summaries = {}; all_converged = True
    for (batch, name), values in groups.items():
        summary = dict(samples=len(values), converged=sum(v['converged'] for v in values),
            maximum_root_angular_error_rad_s=max(v['root_angular_error_rad_s'] for v in values))
        for field in ('root_angular_error_rad_s', 'root_linear_error_m_s', 'joint_velocity_error_rad_s'):
            summary['mean_'+field] = math.fsum(v[field] for v in values)/len(values)
        require(all(near(value, result['summaries'][batch][name][key]) for key,value in summary.items()), 'Response aggregate mismatch')
        summaries.setdefault(batch, {})[name] = summary
        all_converged &= summary['converged'] == len(values)
    reductions = {batch: 1-v['all']['mean_root_angular_error_rad_s']/v['feet']['mean_root_angular_error_rad_s']
                  for batch,v in summaries.items()}
    require(near(maximum_geometry, result['maximum_geometry_error_m']) and near(maximum_kinetic, result['maximum_kinetic_error_j']), 'Response validation maxima')
    limits = plan['validation']; validation = (maximum_geometry <= limits['maximum_geometry_error_m'] and
        maximum_kinetic <= limits['maximum_kinetic_error_j'] and (all_converged or not limits['all_predictions_must_converge']))
    descriptive = {}
    for batch in summaries:
        selected = [r for r in rows if r['batch'] == batch]
        worst = max(selected, key=lambda r: r['predictions']['all']['root_angular_error_rad_s'])
        descriptive[batch] = dict(worse_than_feet_samples=sum(r['predictions']['all']['root_angular_error_rad_s'] >
            r['predictions']['feet']['root_angular_error_rad_s'] for r in selected),
            worst_all_contact_sample=dict(cell_id=worst['cell_id'], outer_step=worst['outer_step'],
                all_error_rad_s=worst['predictions']['all']['root_angular_error_rad_s'],
                feet_error_rad_s=worst['predictions']['feet']['root_angular_error_rad_s']))
    return dict(samples=len(rows), predictions=sum(len(v) for v in groups.values()), all_predictions_converged=all_converged,
        validation_passed=validation, relative_error_reduction_by_batch=reductions, descriptive=descriptive,
        retained_state_screen_passed=validation and len(summaries)==plan['input']['bodies'] and
            min(reductions.values()) >= plan['criterion']['minimum_relative_error_reduction_against_feet_per_body'])


def verify(root, receipt_sha256):
    raw = (root/'receipt.json').read_bytes()
    require(hashlib.sha256(raw).hexdigest() == receipt_sha256, 'Response owner digest')
    owner = json.loads(raw); require(owner['ok'] and owner['source_unchanged'] and
        owner['world_build_count'] == owner['solver_steps'] == 0, 'Response owner status')
    archive = Archive(root, owner)
    for name in archive.inventory:
        for _ in archive.lines(name): pass
    plan = archive.document('coupled_contact_response_plan_v1.json')
    require(archive.verified['coupled_contact_response_plan_v1.json']['sha256'] == owner['plan_sha256'], 'Response owner plan')
    source_root = Path(__file__).resolve().parents[2]
    for pin in plan['source_pins']:
        data = (source_root/pin['path']).read_bytes()
        require(len(data) == pin['byte_length'] and hashlib.sha256(data).hexdigest() == pin['sha256'] and
            archive.verified['source_snapshot/'+pin['path']]['sha256'] == pin['sha256'], 'Response source binding')
    for child in ('controls', 'evaluation-owned'):
        clean = archive.document(child+'/cleanup.json')
        require(clean['ok'] and clean['stable_handles'] and clean['exact_job_membership'] and not clean['errors'], 'Response owned cleanup')
    log = b''.join(archive.lines('controls/stderr.log')).decode('utf-8')
    require(f"Ran {plan['validation']['unit_controls']} tests" in log and log.rstrip().endswith('OK'), 'Response unit controls')
    result = archive.document('evaluation/result.json')
    require(archive.verified['evaluation/result.json']['sha256'] == owner['result_sha256'] and result['ok'] and
        result['world_build_count'] == result['solver_steps'] == 0 and not any(result[k] for k in
        ('physical_acceptance_authority', 'release_authority', 'native_solver_equivalence', 'controller_adopted')), 'Response result scope')
    rows = [json.loads(line) for line in archive.lines('evaluation/predictions.jsonl')]
    require(archive.verified['evaluation/predictions.jsonl']['sha256'] == result['predictions_sha256'], 'Response prediction digest')
    original_root = root.parent/plan['input']['archive_relative_path']; original_raw = (original_root/'receipt.json').read_bytes()
    require(hashlib.sha256(original_raw).hexdigest() == plan['input']['receipt_sha256'], 'Response original receipt')
    original = json.loads(original_raw); native = Archive(original_root, original); contract = original['contract']
    expected = [(g['batch_id'], contract['cells'][i]['cell_id'], step) for g in original['worker']['groups']
                for step in plan['sample_outer_steps'] for i in g['cell_indices']]
    answer = aggregate(rows, plan, result, expected); by_key = dict(zip(expected, rows, strict=True)); checked = 0
    for group in original['worker']['groups']:
        for line in native.lines('native/'+group['batch_id']+'/trace.jsonl'):
            row = json.loads(line); step, sub = divmod(row['step']-1, 5)
            if sub or step not in plan['sample_outer_steps']: continue
            key = (group['batch_id'], contract['cells'][group['cell_indices'][row['cell']]]['cell_id'], step)
            require(all(near(a,b) for a,b in zip(native_velocity(row), by_key[key]['native_velocity'], strict=True)), 'Response native velocity binding')
            checked += 1
    require(checked == len(rows), 'Response native sample denominator')
    for pin in result['input_files']:
        if pin['path'] not in native.verified:
            for _ in native.lines(pin['path']): pass
        require(native.verified[pin['path']] == pin, 'Response original input binding')
    require(result['read_counts'] == dict(controller=12960, native=64800, reactions=64800), 'Response retained read counts')
    return dict(ok=True, ledger_scope=plan['ledger_scope'], **answer, artifacts_verified=len(archive.verified),
        original_inputs_verified=len(native.verified), native_velocities_independently_verified=checked,
        source_pins_verified=len(plan['source_pins']), cleanup_reports_verified=2, controls_passed=plan['validation']['unit_controls'],
        world_build_count=0, solver_steps=0, counterfactual_ranking_validated=False, recovery_qualified=False,
        controller_adopted=False, physical_acceptance_authority=False, release_authority=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', type=Path, required=True); parser.add_argument('--receipt-sha256', required=True)
    parser.add_argument('--output', type=Path, required=True); args = parser.parse_args()
    answer = verify(args.archive, args.receipt_sha256)
    with args.output.open('x', encoding='utf-8', newline='\n') as stream:
        json.dump(answer, stream, indent=2, allow_nan=False); stream.write('\n')
    print(json.dumps(answer))
