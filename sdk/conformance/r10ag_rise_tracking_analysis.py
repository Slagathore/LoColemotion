"""Bounded, post-exposure tracking diagnosis of the invalid R10AG attempt.

Reuse reviewed coordinate mathematics, not AF's packet population or conclusion.
This reads retained observations only: no controller, world, or solver calls.
"""
from collections import Counter
import json
import math
import struct

import r10ag_replay_invalid_closure as closure
import r10af_rise_tracking_analysis as geometry

MODES = ('loaded_geometry_rise', 'seek_distal_load')


def check_links(samples):
    for before, after in zip(samples, samples[1:]):
        assert before['semantic_step'] + 1 == after['semantic_step'], 'NONCONTIGUOUS_OBSERVATIONS'
        assert before['next_command_sha256'] == after['applied_command_sha256'], 'COMMAND_LINK_MISMATCH'


def rows():
    path = closure.CHILD / 'worker_report.json'
    assert closure.bind(path)['raw_sha256'] == closure.REPORT_SHA
    descriptor = closure.streams.small_fields(path)['configuration']['base_descriptor']
    samples = []
    for kind, packet in closure.partial_records():
        if kind != 'packet':
            continue
        native = packet['native_receipt']; observation = native['collection']['observation']
        row = closure.streams.diagnosis.snapshot(packet)
        row.update(plan=native['next_load_plan'],
            position=geometry.vector(observation['state']['base_pose_world']['position_m']),
            qualified_support=geometry.qualified_support(observation),
            bearing_impulses=[x['bearing_normal_impulse_ns'] for x in observation['ordered_foot_bearing_observations']],
            applied_impulses=[x['applied_angular_impulse_nms'] for x in observation['applied_actuation']['ordered_applied_impulses']],
            caps=[x['published_maximum_outer_step_impulse_nms'] for x in packet['source_application']['ordered_intents']],
            applied_command_sha256=packet['source_application']['command_sha256'],
            next_command_sha256=None if native['next_control'] is None else native['next_control']['command_sha256'])
        if row['plan'] is not None:
            assert row['qualified_support'] == row['plan']['qualified_support']
        samples.append(row)
    assert len(samples) == 601
    check_links(samples)
    indexed = {r['semantic_step']: r for r in samples}
    seen = set()
    for record in geometry.records(path, 'r10af_contact_frames', 'records'):
        packet = record['packet']; step = packet['semantic_step']
        if step not in indexed:
            continue
        assert step not in seen, 'DUPLICATE_CONTACT_FRAME'
        seen.add(step); row = indexed[step]
        bodies = {b['body_id']: b for b in packet['callback_bodies']}
        assert geometry.vector(bodies['torso']['pose']['origin']) == row['position']
        feet = []
        for foot in geometry.FEET:
            body = foot + '_distal'; pose = bodies[body]['pose']
            # Reproduce the authored binary32 center; keep arithmetic diagnostic.
            center = [struct.unpack('<f', struct.pack('<f', x))[0]
                for x in geometry.vector(packet['contact_sites_by_body'][body]['local_center_m'])]
            columns = [geometry.vector(v) for v in pose['basis_columns']]
            origin = geometry.vector(pose['origin'])
            feet.append([origin[a] + sum(columns[c][a]*center[c] for c in range(3)) for a in range(3)])
        row['measured_cap_centers'] = feet
        row['modeled_cap_centers'] = [[row['position'][a] + geometry.rotate(row['orientation_xyzw'], v)[a]
            for a in range(3)] for v in geometry.fk(descriptor, row['joint_positions_rad'])]
    assert seen == set(indexed), 'INCOMPLETE_CONTACT_FRAMES'
    return descriptor, samples


def pair_metrics(descriptor, before, after):
    target = before['next_control']['target_positions_rad']
    old_feet = geometry.fk(descriptor, before['joint_positions_rad'])
    target_feet = geometry.fk(descriptor, target)
    predicted = [geometry.rotate(before['orientation_xyzw'],
        [target_feet[i][a] - old_feet[i][a] for a in range(3)])[1] for i in range(4)]
    parts = [geometry.motion_components(descriptor, before, after, i) for i in range(4)]
    return dict(
        mapping_errors=[after['applied_target_velocities_rad_s'][j] - max(-4., min(4.,
            (target[j] - before['joint_positions_rad'][j]) / geometry.DT)) for j in range(8)],
        target_errors=[after['joint_positions_rad'][j]-target[j] for j in range(8)],
        cap_fractions=[abs(after['applied_impulses'][j])/after['caps'][j] for j in range(8)],
        predicted_fixed_torso_foot_dy_m=predicted, decomposition=parts,
        joint_motion_error_dy_m=[parts[i]['modeled_measured_joint_dy_m']-predicted[i] for i in range(4)],
        qualified_after=after['qualified_support'],
        bearing_impulse_after_ns=after['bearing_impulses'],
        # A positive virtual rise is a planning variable, never an applied force.
        planned_virtual_torso_dy_m=before['plan']['virtual_translation_world_m'][1],
        measured_torso_dy_m=after['position'][1]-before['position'][1])


def summarize(descriptor, samples):
    check_links(samples)
    pairs = [(a, b, pair_metrics(descriptor, a, b)) for a, b in zip(samples, samples[1:])]
    assert Counter(a['plan']['mode'] for a, _, _ in pairs) == dict(loaded_geometry_rise=110, seek_distal_load=490)
    stats = geometry.stats
    result = dict(steps=len(samples), command_links=len(pairs),
        canonical_motor_velocity_mapping_error_rad_s=stats([v for _, _, m in pairs for v in m['mapping_errors']]),
        fk_position_error_m_by_foot=[stats([math.dist(r['modeled_cap_centers'][i], r['measured_cap_centers'][i])
            for r in samples]) for i in range(4)], modes={})
    for mode in MODES:
        selected = [(a, b, m) for a, b, m in pairs if a['plan']['mode'] == mode]
        metrics = [m for _, _, m in selected]
        mode_result = dict(commands=len(metrics),
            all_four_qualified_after=sum(all(m['qualified_after']) for m in metrics),
            unqualified_after_by_foot=[sum(not m['qualified_after'][i] for m in metrics) for i in range(4)],
            planned_upward_fixed_torso_foot_motion_by_foot=[sum(m['predicted_fixed_torso_foot_dy_m'][i] > 1e-8 for m in metrics) for i in range(4)],
            hold_reason_counts=dict(Counter(a['plan']['hold_reason'] or 'none' for a, _, _ in selected)),
            planned_virtual_torso_dy_m=stats([m['planned_virtual_torso_dy_m'] for m in metrics]),
            measured_torso_dy_m=stats([m['measured_torso_dy_m'] for m in metrics]))
        for key, size in (('target_errors', 8), ('cap_fractions', 8),
                ('predicted_fixed_torso_foot_dy_m', 4), ('joint_motion_error_dy_m', 4), ('bearing_impulse_after_ns', 4)):
            mode_result[key] = [stats([m[key][i] for m in metrics]) for i in range(size)]
        mode_result['motion_decomposition_by_foot'] = [{group: {
            key: stats([m['decomposition'][i][key] for m in metrics
                if group == 'all' or m['qualified_after'][i] == (group == 'qualified_after')])
            for key in metrics[0]['decomposition'][i]}
            for group in ('all', 'qualified_after', 'unqualified_after')} for i in range(4)]
        result['modes'][mode] = mode_result
    result['pose_trend'] = dict(first_step=samples[0]['semantic_step'], last_step=samples[-1]['semantic_step'],
        first_position_m=samples[0]['position'], last_position_m=samples[-1]['position'],
        torso_height_gain_m=samples[-1]['position'][1]-samples[0]['position'][1],
        last_120_commands_torso_height_gain_m=samples[-1]['position'][1]-samples[-121]['position'][1],
        first_torso_up_dot=samples[0]['classification']['torso_up_dot'],
        last_torso_up_dot=samples[-1]['classification']['torso_up_dot'])
    result.update(original_attempt_reclassified=False, physical_causal_effect_established=False,
        world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)
    return result


def analyze():
    return summarize(*rows())


if __name__ == '__main__':
    print(json.dumps(analyze(), indent=2, allow_nan=False))
