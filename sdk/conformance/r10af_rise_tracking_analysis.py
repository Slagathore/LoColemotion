"""Read-only one-step tracking analysis of the consumed R10AF report."""
import json
import math
import statistics
import struct

import r10af_detection_frame_closure as closure

FEET = ('front_left', 'front_right', 'rear_left', 'rear_right')
LOAD_THRESHOLD = 0.019293
DT = 1.0 / 120.0


def qualified_support(observation):
    return [c['presence'] is True and c['bears_support'] is True
        and b['ordinary_unilateral_contact'] is True
        and b['bearing_normal_impulse_ns'] >= LOAD_THRESHOLD
        for c, b in zip(observation['state']['ordered_contact_observations'],
                        observation['ordered_foot_bearing_observations'], strict=True)]


def records(path, section, collection):
    """Stream the fixed pretty-JSON layout only after verifying its exact hash."""
    found = closed = False
    with path.open(encoding='utf-8') as stream:
        for line in stream:
            if line.startswith('  "' + section + '": {'):
                assert not found; found = True
                for line in stream:
                    if line.startswith('    "' + collection + '": ['):
                        lines = []
                        for line in stream:
                            if line.startswith('    ]'):
                                assert not lines; break
                            lines.append(line)
                            if line.startswith('      }'):
                                yield json.loads(''.join(lines).rstrip().removesuffix(',')); lines = []
                        else: raise AssertionError('UNTERMINATED_RECORDS')
                    elif line.startswith('  }'):
                        closed = True; break
    assert found and closed


def vector(value):
    return [value[k] for k in ('x', 'y', 'z')] if isinstance(value, dict) else value


def rotate(q, v):
    x, y, z, w = [q[k] for k in ('x', 'y', 'z', 'w')]
    return [(1-2*(y*y+z*z))*v[0]+2*(x*y-z*w)*v[1]+2*(x*z+y*w)*v[2],
        2*(x*y+z*w)*v[0]+(1-2*(x*x+z*z))*v[1]+2*(y*z-x*w)*v[2],
        2*(x*z-y*w)*v[0]+2*(y*z+x*w)*v[1]+(1-2*(x*x+y*y))*v[2]]


def fk(descriptor, joints):
    upper = .35 * descriptor['upper_length_fraction']; lower = .35 * (1-descriptor['upper_length_fraction'])
    return [[(0.2 if i < 2 else -0.2)*descriptor['hip_span_scale'] + upper*math.sin(joints[2*i])+lower*math.sin(joints[2*i]+joints[2*i+1]),
        -upper*math.cos(joints[2*i])-lower*math.cos(joints[2*i]+joints[2*i+1]),
        (-.18 if i % 2 == 0 else .18)*descriptor['hip_span_scale']] for i in range(4)]


def stats(values):
    return dict(count=len(values), minimum=min(values), median=statistics.median(values), maximum=max(values), mean=statistics.mean(values)) if values else dict(count=0)


def rows():
    path = closure.CHILD / 'worker_report.json'
    assert closure.bind(path)['raw_sha256'] == closure.REPORT_SHA
    descriptor = closure.streams.small_fields(path)['configuration']['base_descriptor']
    result = []
    for kind, packet in closure.streams.partial_records(path):
        if kind != 'packet': continue
        native = packet['native_receipt']; observation = native['collection']['observation']
        row = closure.streams.diagnosis.snapshot(packet)
        row.update(plan=native['next_load_plan'], position=vector(observation['state']['base_pose_world']['position_m']),
            qualified_support=qualified_support(observation),
            bearing_impulses=[x['bearing_normal_impulse_ns'] for x in observation['ordered_foot_bearing_observations']],
            applied_impulses=[x['applied_angular_impulse_nms'] for x in observation['applied_actuation']['ordered_applied_impulses']],
            caps=[x['published_maximum_outer_step_impulse_nms'] for x in packet['source_application']['ordered_intents']],
            applied_command_sha256=packet['source_application']['command_sha256'],
            next_command_sha256=None if native['next_control'] is None else native['next_control']['command_sha256'])
        result.append(row)
        if row['plan'] is not None:
            assert row['qualified_support'] == row['plan']['qualified_support']
    assert len(result) == 601
    indexed = {r['semantic_step']: r for r in result}
    for record in records(path, 'r10af_contact_frames', 'records'):
        packet = record['packet']; step = packet['semantic_step']
        if step not in indexed: continue
        row = indexed[step]
        bodies = {b['body_id']: b for b in packet['callback_bodies']}
        assert vector(bodies['torso']['pose']['origin']) == row['position']
        feet = []
        for foot in FEET:
            pose = bodies[foot + '_distal']['pose']
            center = vector(packet['contact_sites_by_body'][foot + '_distal']['local_center_m'])
            # Match native authored-coordinate conversion; matrix arithmetic here
            # remains double precision and is diagnostic, not a new source value.
            center = [struct.unpack('<f', struct.pack('<f', x))[0] for x in center]
            columns = [vector(v) for v in pose['basis_columns']]
            origin = vector(pose['origin'])
            feet.append([origin[a]+sum(columns[c][a]*center[c] for c in range(3)) for a in range(3)])
        row['measured_cap_centers'] = feet
        modeled = fk(descriptor, row['joint_positions_rad'])
        row['modeled_cap_centers'] = [[row['position'][a]+rotate(row['orientation_xyzw'], v)[a] for a in range(3)] for v in modeled]
    assert all('measured_cap_centers' in r for r in result)
    for before, after in zip(result, result[1:]):
        assert before['semantic_step'] + 1 == after['semantic_step']
        assert before['next_command_sha256'] == after['applied_command_sha256']
    return descriptor, result


def motion_components(descriptor, before, after, foot):
    """Algebraic decomposition, not an attribution of physical causes.

    Hold the previous local FK point fixed while changing the torso rotation,
    then change joint angles at the new rotation. The remaining change is the
    callback cap versus ideal FK residual, including constraint deformation.
    """
    old_local = fk(descriptor, before['joint_positions_rad'])[foot]
    new_local = fk(descriptor, after['joint_positions_rad'])[foot]
    old_rotated = rotate(before['orientation_xyzw'], old_local)[1]
    new_rotated = rotate(after['orientation_xyzw'], old_local)[1]
    joint_dy = rotate(after['orientation_xyzw'],
        [new_local[k] - old_local[k] for k in range(3)])[1]
    translation = after['position'][1] - before['position'][1]
    rotation = new_rotated - old_rotated
    actual = after['measured_cap_centers'][foot][1] - before['measured_cap_centers'][foot][1]
    residual = ((after['measured_cap_centers'][foot][1] - after['modeled_cap_centers'][foot][1])
        - (before['measured_cap_centers'][foot][1] - before['modeled_cap_centers'][foot][1]))
    assert math.isclose(actual, translation + rotation + joint_dy + residual, abs_tol=1e-12)
    return dict(actual_world_dy_m=actual, torso_translation_dy_m=translation,
        modeled_torso_rotation_dy_m=rotation, modeled_measured_joint_dy_m=joint_dy,
        fk_residual_change_dy_m=residual)


def analyze():
    descriptor, samples = rows()
    result = dict(steps=len(samples), command_links=len(samples)-1,
        fk_position_error_m_by_foot=[stats([math.dist(r['modeled_cap_centers'][i], r['measured_cap_centers'][i]) for r in samples]) for i in range(4)])
    mapping_errors = [b['applied_target_velocities_rad_s'][j] -
        max(-4.0, min(4.0, (a['next_control']['target_positions_rad'][j] - a['joint_positions_rad'][j]) / DT))
        for a, b in zip(samples, samples[1:]) for j in range(8)]
    assert mapping_errors == [0.0] * 4800
    result['canonical_motor_velocity_mapping_error_rad_s'] = stats(mapping_errors)
    modes = {}
    for mode in ('loaded_downward_rise', 'seek_distal_load'):
        pairs = [(a,b) for a,b in zip(samples,samples[1:]) if a['plan']['mode'] == mode]
        errors = [[] for _ in range(8)]; cap_fraction = [[] for _ in range(8)]
        predicted_dy = [[] for _ in range(4)]; measured_relative_dy = [[] for _ in range(4)]; measured_world_dy = [[] for _ in range(4)]
        lost = [0]*4; wrong = [0]*4
        decomposition = [[] for _ in range(4)]
        integrated_velocity_error = [[] for _ in range(8)]
        end_velocity_error = [[] for _ in range(8)]
        for a,b in pairs:
            target = a['next_control']['target_positions_rad']
            target_feet = fk(descriptor, target); current_feet = fk(descriptor, a['joint_positions_rad'])
            for j in range(8):
                errors[j].append(b['joint_positions_rad'][j]-target[j])
                cap_fraction[j].append(abs(b['applied_impulses'][j])/b['caps'][j])
                end_velocity_error[j].append(b['joint_velocities_rad_s'][j] - b['applied_target_velocities_rad_s'][j])
                integrated_velocity_error[j].append(b['joint_positions_rad'][j] - a['joint_positions_rad'][j] - DT*b['joint_velocities_rad_s'][j])
            for i in range(4):
                predicted = rotate(a['orientation_xyzw'],[target_feet[i][axis]-current_feet[i][axis] for axis in range(3)])[1]
                actual_world = b['measured_cap_centers'][i][1]-a['measured_cap_centers'][i][1]
                actual_relative = actual_world-(b['position'][1]-a['position'][1])
                predicted_dy[i].append(predicted); measured_relative_dy[i].append(actual_relative); measured_world_dy[i].append(actual_world)
                if not b['qualified_support'][i]: lost[i] += 1
                if predicted < -1e-8 and actual_relative > 1e-8: wrong[i] += 1
                components = motion_components(descriptor, a, b, i)
                components.update(qualified_after=b['qualified_support'][i],
                    bearing_impulse_change_ns=b['bearing_impulses'][i]-a['bearing_impulses'][i])
                decomposition[i].append(components)
        modes[mode] = dict(commands=len(pairs), unqualified_after_by_foot=lost,
            foot_moved_up_after_removing_only_torso_translation_despite_downward_target=wrong,
            target_error_rad_by_joint=[stats(x) for x in errors], applied_cap_fraction_by_joint=[stats(x) for x in cap_fraction],
            end_velocity_minus_applied_target_rad_s_by_joint=[stats(x) for x in end_velocity_error],
            measured_angle_delta_minus_end_velocity_times_dt_rad_by_joint=[stats(x) for x in integrated_velocity_error],
            torso_translation_dy_m=stats([b['position'][1]-a['position'][1] for a,b in pairs]),
            predicted_fixed_torso_foot_dy_m=[stats(x) for x in predicted_dy],
            actual_foot_dy_minus_torso_translation_m=[stats(x) for x in measured_relative_dy],
            actual_world_foot_dy_m=[stats(x) for x in measured_world_dy],
            motion_decomposition_by_foot=[{group: {key: stats([x[key] for x in foot if group == 'all' or x['qualified_after'] == (group == 'qualified_after')])
                for key in foot[0] if key != 'qualified_after'}
                for group in ('all', 'qualified_after', 'unqualified_after')} for foot in decomposition])
    result['modes'] = modes
    result['pose_trend'] = dict(
        first=dict(step=samples[0]['semantic_step'], position_m=samples[0]['position'],
            joint_positions_rad=samples[0]['joint_positions_rad'], torso_up_dot=samples[0]['classification']['torso_up_dot']),
        last=dict(step=samples[-1]['semantic_step'], position_m=samples[-1]['position'],
            joint_positions_rad=samples[-1]['joint_positions_rad'], torso_up_dot=samples[-1]['classification']['torso_up_dot']),
        torso_height_gain_m=samples[-1]['position'][1]-samples[0]['position'][1],
        last_120_commands_torso_height_gain_m=samples[-1]['position'][1]-samples[-121]['position'][1],
        loaded_plans_with_zero_level_blend=sum(r['plan']['mode'] == 'loaded_downward_rise' and r['plan']['virtual_level_blend'] == 0.0 for r in samples[:-1]))
    result['joint_boundary_excursions'] = [dict(step=r['semantic_step'], joint=j,
        position=r['joint_positions_rad'][j], limit=1.6 if j%2==0 else 1.1,
        excess=abs(r['joint_positions_rad'][j])-(1.6 if j%2==0 else 1.1))
        for r in samples for j in range(8) if abs(r['joint_positions_rad'][j])>(1.6 if j%2==0 else 1.1)]
    return result


if __name__ == '__main__':
    print(json.dumps(analyze(),indent=2))
