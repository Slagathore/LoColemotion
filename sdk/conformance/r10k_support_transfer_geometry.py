"""Frozen-pose geometry diagnosis, not a controller or physical continuation.

The caller owns the native operation lock for compiling the original descriptor.
Python IK is anchored to the last original native result before evaluating the
declared alternative reference bounds. No contact or success claim follows.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path

import development_recovery_refusal as refusal
import r10k_development_failure as failure

ROOT = Path(__file__).resolve().parents[2]
RECORD = ROOT / 'sdk/recovery/r10k_support_transfer_geometry_diagnosis_v1.json'
BIASES = (-.25, -.27, -.28, -.30, -.35)


def require(value, code):
    if not value:
        raise ValueError('R10K_TRANSFER_GEOMETRY_' + code)


def vector(value):
    return tuple(value[k] for k in 'xyz')


def translated(position, forward, distance):
    return tuple(p + f * distance for p, f in zip(position, forward))


def triangle_margin(point, vertices):
    center = tuple(sum(p[i] for p in vertices)/3 for i in range(3))
    ordered = sorted(vertices, key=lambda p: math.atan2(p[2]-center[2], p[0]-center[0]))
    margins = []
    for a, b in zip(ordered, ordered[1:] + ordered[:1]):
        length = math.hypot(b[0]-a[0], b[2]-a[2])
        margins.append((-(b[2]-a[2])*(point[0]-a[0])+(b[0]-a[0])*(point[2]-a[2]))/length)
    return min(margins)


def choose_height(body, forward, targets, compiled):
    g = compiled['geometry']
    upper, lower = g['upper_length_m'], g['lower_length_m']
    actuators = compiled['morphology']['morphology_spec']['actuators']
    # This is terminal reference feasibility across the original height range.
    # It does not skip or simulate the original per-command height-rate limit.
    for index in range(81):
        correction = -index*.00025
        goals, reserves = [], []
        for i, target in enumerate(targets):
            x = sum((t-b)*f for t,b,f in zip(target,body,forward)) - g['front_hip_x_m' if i<2 else 'rear_hip_x_m']
            down = body[1]+correction-target[1]
            reserve = upper+lower-math.hypot(x,down)
            cosine = (x*x+down*down-upper*upper-lower*lower)/(2*upper*lower)
            if down <= 0 or reserve < .001 or not -1 <= cosine <= 1:
                break
            knee = math.acos(cosine)
            hip = math.atan2(x,down)-math.atan2(lower*math.sin(knee),upper+lower*math.cos(knee))
            if not (actuators[2*i]['minimum_target_position_rad'] <= hip <= actuators[2*i]['maximum_target_position_rad']
                    and actuators[2*i+1]['minimum_target_position_rad'] <= knee <= actuators[2*i+1]['maximum_target_position_rad']):
                break
            require(math.hypot(upper*math.sin(hip)+lower*math.sin(hip+knee)-x,
                               upper*math.cos(hip)+lower*math.cos(hip+knee)-down) < 1e-12, 'FK_RESIDUAL')
            goals.extend((hip,knee));reserves.append(reserve)
        else:
            return dict(feasible=True, height_correction_m=correction, body_height_world_m=body[1]+correction,
                        ordered_joint_goals_rad=goals, ordered_reach_reserves_m=reserves)
    return dict(feasible=False)


def audit():
    closure = failure.read(failure.RECORD)
    for key in ('report','descriptor_source','native_runtime'):
        require(failure.binding(closure[key]['path']) == closure[key], 'SOURCE_BINDING_'+key)
    report = failure.read(closure['report']['path'])
    descriptor = failure.read(closure['descriptor_source']['path'])['configuration']['base_descriptor']
    core = refusal.RecordedCore(closure['native_runtime']['path'])
    compiled = core.compile_bounded_quadruped(descriptor)
    require(core.canonicalize_json(compiled['morphology']['morphology_spec'])['sha256'] ==
            report['detail']['portable_step_receipt']['development_native_step_failure']['compiled_morphology_spec_sha256'], 'COMPILED_MORPHOLOGY')
    row = report['development_walking_entry']['rows'][-1]
    plane = row['native_output']['actuation']['receipt']['recovery_support_plane']
    pose, transfer = plane['anchored_body_pose'], plane['measured_support_transfer']
    current = vector(pose['desired_body_position_world_m'])
    nominal = (current[0], pose['joint_feasible_height']['nominal_body_height_world_m'], current[2])
    forward = vector(pose['desired_forward_world_unit'])
    targets = [vector(p) for p in pose['ordered_foot_targets_world_m']]
    measured = transfer['measurement']
    com = vector(measured['measured_com_position_world_m'])
    feet = [vector(p) for i,p in enumerate(measured['ordered_measured_capsule_endpoints_world_m']) if i != 2]
    require(abs(triangle_margin(com,feet)-transfer['remaining_triangle_margin_m']) < 1e-12, 'ORIGINAL_MARGIN')
    length = compiled['geometry']['upper_length_m']+compiled['geometry']['lower_length_m']
    cases = []
    for bias in BIASES:
        distance = length*(transfer['next_memory']['hip_bias_rad']-bias)
        candidate = choose_height(translated(nominal,forward,distance),forward,targets,compiled)
        candidate.update(reference_bias_rad=bias, additional_reference_translation_m=distance,
            hypothetical_margin_with_rigid_com_translation_and_fixed_measured_feet_m=triangle_margin(translated(com,forward,distance),feet))
        cases.append(candidate)
    baseline = cases[0]
    require(baseline['feasible'] and baseline['height_correction_m'] == pose['joint_feasible_height']['selected_correction_m']
            and max(abs(a-b) for a,b in zip(baseline['ordered_joint_goals_rad'],pose['ordered_joint_goals_rad'])) < 1e-12, 'ORIGINAL_NATIVE_IK')
    return dict(schema_version='sporespore_r10k_support_transfer_geometry_diagnosis_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='retained_measurement_geometry_diagnosis',question_class='development'),
        closure=failure.binding(failure.RECORD), report=closure['report'], descriptor_source=closure['descriptor_source'],
        native_runtime=closure['native_runtime'], auditor=failure.binding(Path(__file__)),
        observed_walking_command=839, original_python_ik_matches_native_goals_within_m_or_rad=1e-12,
        cases=cases, rate_transition_simulated=False, new_controller_implemented=False,
        physical_response_predicted=False, original_attempt_reclassified=False,
        limits=['The foot targets and measured support triangle are held fixed while examining reference geometry.',
                'A shifted COM is a stated geometric assumption, not a predicted native body trajectory or measured contact load.',
                'Feasibility is checked over the original 20 mm height range; a successor must separately preserve the per-command rate limits.',
                'The complete next walking cycle, earlier trajectory and kicked recovery remain untested.'],
        world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--create',action='store_true')
    args = parser.parse_args()
    result = audit()
    if args.create:
        with RECORD.open('x',encoding='utf-8',newline='\n') as stream:
            json.dump(result,stream,indent=2,allow_nan=False);stream.write('\n')
    else:
        require(failure.read(RECORD) == result,'RECONSTRUCTION')
    print(json.dumps(dict(ok=True,cases=[{k:v for k,v in case.items() if k not in ('ordered_joint_goals_rad','ordered_reach_reserves_m')} for case in result['cases']],physical_response_predicted=False)))
