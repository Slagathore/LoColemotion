"""Compare exposed support-transfer histories, without continuing any world.

The finite population is two original controller refusals and four previously
accepted walking components. Every input is bound by its original closure.
This is descriptive post-exposure analysis, not a timeout or policy change.
"""
import argparse
import collections
import copy
import gc
import json
import math
from pathlib import Path

import r10j_held_out_failure as original

ROOT = Path(__file__).resolve().parents[2]
RECORD = ROOT / 'sdk/recovery/r10r_support_transfer_diagnosis_v1.json'
read, binding = original.read, original.binding
LIMBS = ['front_left', 'front_right', 'rear_left', 'rear_right']


def require(value, code):
    if not value: raise ValueError('R10R_TRANSFER_DIAGNOSIS_' + code)


def report_in(closure, role):
    path = Path(closure['evidence_root']) / 'children' / role / 'worker_report.json'
    return next(b for b in closure['retained_evidence'] if Path(b['path']) == path)


def population():
    records = [ROOT / ('sdk/recovery/' + name) for name in [
        'r10r_phase246_development_failure_v1.json', 'r10n_phase241_development_failure_v1.json',
        'r10q_phase246_development_pair_closure_v1.json', 'r10p_held_out_physical_closure_v1.json']]
    r, n, q, p = map(read, records)
    selected = [dict(id='r10r_kicked_phase246', report=report_in(r, 'kick_passive_recovery_resume'), positive=False),
        dict(id='r10n_no_kick_phase241', report=report_in(n, 'matched_no_kick_continuation'), positive=False),
        dict(id='r10q_no_kick_phase246', report=report_in(q, 'matched_no_kick_continuation'), positive=True)]
    claim_path = Path(p['evidence_root']) / 'campaign_claim.json'
    require(binding(claim_path)['raw_sha256'] == p['independent_audit']['campaign_claim_sha256'], 'ORIGINAL_CLAIM')
    claim = read(claim_path)
    for index in range(3):
        cell, descriptor = p['independent_audit']['cells'][index], claim['children'][index]
        require(cell['outcome'] == 'positive' and cell['child_attempt_id'] == descriptor['child_attempt_id'], 'POSITIVE_POPULATION')
        report = Path(descriptor['evidence_path']) / 'worker_report.json'
        actual = binding(report)
        require(actual['raw_sha256'] == cell['original_report_sha256'], 'ORIGINAL_REPORT')
        selected.append(dict(id=f"r10p_{cell['seed']}_{cell['role']}", report=actual, positive=True))
    return selected, [binding(p) for p in records] + [binding(claim_path)]


def dot(a, b): return sum(a[k] * b[k] for k in 'xyz')
def minus(a, b): return {k: a[k] - b[k] for k in 'xyz'}


def row_measurement(row):
    plane = row['native_output']['actuation']['receipt']['recovery_support_plane']
    t, pose = plane['measured_support_transfer'], plane['anchored_body_pose']
    require(t['source_semantic_step'] == row['session_local_step'], 'CLOCK')
    limb = t['planned_swing_limb_id']
    require(limb in LIMBS and t['required_support_limb_ids'] == [k for k in LIMBS if k != limb], 'SUPPORT_POPULATION')
    contacts = row['request']['state']['ordered_contact_observations']
    require([c['contact_site_id'] for c in contacts] == [k + '_foot' for k in LIMBS], 'CONTACT_ORDER')
    m = t['measurement']
    checks = dict(required_supports=all(c['presence'] is True and c['bears_support'] is True for k, c in zip(LIMBS, contacts) if k != limb),
        triangle_margin=t['remaining_triangle_margin_m'] >= .020, horizontal_speed=m['horizontal_com_speed_m_s'] <= .030,
        angular_speed=m['torso_angular_speed_rad_s'] <= .15, tilt=m['torso_tilt_rad'] <= .05)
    require(all(checks.values()) is t['readiness_conditions_met'], 'READINESS')
    target, com = pose['desired_body_position_world_m'], m['measured_com_position_world_m']
    forward = m['anatomical_forward_horizontal_world_unit']
    foot_errors = [math.hypot(a['x']-b['x'], a['z']-b['z']) for a, b in
        zip(pose['ordered_foot_targets_world_m'], m['ordered_measured_capsule_endpoints_world_m'])]
    return dict(command=row['session_local_step'], limb=limb, epoch=t['planned_swing_start_gait_step'],
        held=t['preparation_held'], released=t['preparation_released_this_command'],
        incoming_count=t['incoming_memory']['preparation_commands'], next_count=t['next_memory']['preparation_commands'],
        incoming_dwell=t['incoming_memory']['ready_dwell_commands'], next_dwell=t['next_memory']['ready_dwell_commands'],
        readiness=checks, ready=all(checks.values()), triangle_margin_m=t['remaining_triangle_margin_m'],
        horizontal_speed_m_s=m['horizontal_com_speed_m_s'], forward_speed_m_s=m['forward_com_speed_m_s'],
        angular_speed_rad_s=m['torso_angular_speed_rad_s'], tilt_rad=m['torso_tilt_rad'],
        requested_foreaft_displacement_m=t['requested_foreaft_displacement_m'],
        hip_bias_rad=t['next_memory']['hip_bias_rad'], hip_bias_saturated=t['hip_bias_saturated'],
        reference_body_height_m=target['y'], height_correction_m=pose['next_memory']['height_correction_m'],
        reference_ahead_of_measured_com_m=dot(minus(target, com), forward),
        maximum_horizontal_foot_target_error_m=max(foot_errors),
        required_support_horizontal_foot_errors_m={k: e for k, e in zip(LIMBS, foot_errors) if k != limb})


def summarize(segment):
    require(bool(segment) and segment[0]['incoming_count'] == segment[0]['incoming_dwell'] == 0, 'PREPARATION_START')
    dwell = 0
    for index, row in enumerate(segment):
        require(row['command'] == segment[0]['command'] + index
            and row['limb'] == segment[0]['limb'] and row['epoch'] == segment[0]['epoch']
            and row['incoming_count'] == index and row['incoming_dwell'] == dwell, 'PREPARATION_CHAIN')
        dwell = dwell + 1 if row['ready'] else 0
        if row['released']:
            require(index == len(segment)-1 and dwell == 6 and row['held'] is False
                and row['next_count'] == row['next_dwell'] == 0, 'RELEASE')
        else:
            require(row['held'] is True and dwell < 6 and row['next_count'] == index+1 and row['next_dwell'] == dwell, 'HOLD')
    keys = ['triangle_margin_m', 'horizontal_speed_m_s', 'forward_speed_m_s', 'angular_speed_rad_s',
        'tilt_rad', 'hip_bias_rad', 'reference_body_height_m', 'height_correction_m',
        'reference_ahead_of_measured_com_m', 'maximum_horizontal_foot_target_error_m']
    ranges = {k: dict(first=segment[0][k], last=segment[-1][k], minimum=min(r[k] for r in segment),
        maximum=max(r[k] for r in segment)) for k in keys}
    changes = [r['command'] for old, r in zip(segment, segment[1:]) if old['height_correction_m'] != r['height_correction_m']]
    return dict(limb=segment[0]['limb'], epoch=segment[0]['epoch'], first_command=segment[0]['command'],
        last_command=segment[-1]['command'], preparation_commands=len(segment), held_commands=sum(r['held'] for r in segment),
        released=segment[-1]['released'], required_dwell=6, final_pre_release_dwell=dwell,
        failure_counts={k: sum(not r['readiness'][k] for r in segment) for k in segment[0]['readiness']},
        saturated_commands=sum(r['hip_bias_saturated'] for r in segment),
        height_correction_change_commands=changes, measurement_ranges=ranges, measurements=segment)


def extract(report):
    rows = report['development_walking_entry']['rows']
    segments, current = [], []
    for row in rows:
        t = row['native_output']['actuation']['receipt']['recovery_support_plane']['measured_support_transfer']
        if not t['preparation_held'] and not t['preparation_released_this_command']:
            require(not current, 'PREPARATION_DISAPPEARED')
            continue
        current.append(row_measurement(row))
        if t['preparation_released_this_command']:
            segments.append(summarize(current)); current = []
    if current:
        require(report['ok'] is False and len(current) == 240, 'TERMINAL_REFUSAL')
        segments.append(summarize(current))
    return segments


def negative_controls(segment):
    results = []
    for name in ['crossed_clock', 'crossed_limb', 'forged_dwell', 'forged_release']:
        value = copy.deepcopy(segment)
        if name == 'crossed_clock': value[-1]['command'] += 1
        elif name == 'crossed_limb': value[-1]['limb'] = 'front_right'
        elif name == 'forged_dwell': value[-1]['next_dwell'] = 6
        else: value[-1]['released'] = True
        try: summarize(value)
        except ValueError as error: results.append(dict(case=name, refused=True, failure_code=str(error)))
        else: raise ValueError('R10R_TRANSFER_DIAGNOSIS_NEGATIVE_ACCEPTED:' + name)
    return results


def audit():
    selected, authorities = population()
    results, controls = [], None
    for source in selected:
        original.bound_file(source['report'])
        report = read(source['report']['path'])
        require(report['ok'] is source['positive'], 'ORIGINAL_STATUS')
        segments = extract(report)
        require(len(segments) == 4 and sum(s['released'] for s in segments) == (4 if source['positive'] else 3), 'FOUR_PLANNED_PREPARATIONS')
        if controls is None: controls = negative_controls(segments[-1]['measurements'])
        results.append(dict(**source, native_policy=report['finite_recovery_task']['native_policy_id'],
            walking_commands=len(report['development_walking_entry']['rows']), preparations=segments))
        print('R10R_TRANSFER_HISTORY', source['id'], [(s['limb'], s['preparation_commands'], s['released']) for s in segments], flush=True)
        del report
        gc.collect()
    return dict(schema_version='sporespore_r10r_support_transfer_diagnosis_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='post_exposure_retained_support_transfer_diagnosis', question_class='development'),
        finite_history_count=6, positive_histories=4, original_refusal_histories=2,
        source_authorities=authorities, auditor=binding(Path(__file__)),
        source_helpers=[binding(ROOT/'sdk/conformance/r10j_held_out_failure.py'),
            binding(ROOT/'sdk/core/src/recovery_measured_support_transfer.rs'), binding(ROOT/'sdk/core/src/recovery_anchored_body_pose.rs')],
        histories=results, negative_controls=controls,
        interpretation_limits=['All inputs are exposed original physical measurements; no future trajectory is synthesized.',
            'R10N uses V54; the other histories use V55. These are descriptive histories, not a matched controller comparison.',
            'Reference and measured COM positions differ physically; their difference is descriptive, not a body tracking-error acceptance predicate.',
            'Foot target errors include capsule endpoint motion and cannot by themselves classify contact slip.',
            'Additional preparation time, changed gains and any other successor remain untested.'],
        original_results_regraded=False, new_world_count=0, new_solver_step_count=0,
        physical_acceptance_authority=False, release_authority=False, sdk1_score='14/20')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(); parser.add_argument('--create', action='store_true'); args = parser.parse_args()
    observed = audit()
    if args.create:
        with RECORD.open('x', encoding='utf-8', newline='\n') as stream:
            json.dump(observed, stream, indent=2, allow_nan=False); stream.write('\n')
    else: require(observed == read(RECORD), 'RECONSTRUCTION')
    print('R10R_TRANSFER_DIAGNOSIS_PASSED histories=6 preparations=24 negative_controls=4 new_worlds=0', flush=True)
