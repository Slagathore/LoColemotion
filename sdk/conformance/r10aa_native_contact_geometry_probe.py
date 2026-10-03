"""Compare ideal articulated geometry with retained native contact positions.

Native local/world contact pairs provide a check independent of the R10Z
planner. A mismatch does not by itself identify faulty angle measurement,
constraint drift, contact timing, or an incorrect kinematic assumption.
"""
import argparse
import json
import math
from pathlib import Path

import r10z_first_support_closure as closed
from r10z_support_geometry_diagnosis import rotate

WORLD = closed.ROOT/'sdk/adapters/godot/gdscript/recovery_native_world_v1.gd'
QUADRUPED = closed.ROOT/'sdk/core/src/quadruped.rs'
LIMBS = ('front_left', 'front_right', 'rear_left', 'rear_right')


def rotate_z(angle, vector):
    x, y, z = vector
    return [math.cos(angle)*x-math.sin(angle)*y,
            math.sin(angle)*x+math.cos(angle)*y, z]


def derive():
    report = closed.CHILD/'worker_report.json'
    assert closed.binding(report)['raw_sha256'] == closed.REPORT_SHA
    rows = []
    for kind, value in closed.partial_records(report):
        if kind == 'declaration':
            descriptor = value['entry_request']['passive_request']['declaration']['initialization']['descriptor']
            upper = .35*descriptor['upper_length_fraction']
            lower = .35*(1-descriptor['upper_length_fraction'])
        elif kind == 'packet':
            assert value['call']['value'] == value['native_receipt']
            observation = value['native_receipt']['collection']['observation']
            state = observation['state']; pose = state['base_pose_world']
            p = [pose['position_m'][k] for k in ('x','y','z')]
            q = pose['orientation_xyzw']
            joints = state['ordered_joint_observations']
            source = value['bound_observations']['source_component_receipts']['rotation_aware_source_component_receipts']
            contact = source['contact_source_receipt']
            assert contact['semantic_step'] == observation['semantic_step']
            assert contact['source_measurement'] is True
            for sample in contact['ordered_contact_samples']:
                body = sample['body_id']
                local = [sample['position_body_local_m'][k] for k in ('x','y','z')]
                actual = [sample['position_world_m'][k] for k in ('x','y','z')]
                if body == 'torso':
                    torso_local = local
                    anchor_error = 0.
                else:
                    limb = next(name for name in LIMBS if body in (name+'_upper',name+'_distal'))
                    i = LIMBS.index(limb)
                    hip, knee = joints[2*i]['position_rad'], joints[2*i+1]['position_rad']
                    origin = [(.2 if i<2 else -.2)*descriptor['hip_span_scale'], 0.,
                              (-.18 if i%2==0 else .18)*descriptor['hip_span_scale']]
                    if body.endswith('_upper'):
                        offset = rotate_z(hip,[local[0],local[1]-upper/2,local[2]])
                        anchor_error = joints[2*i]['anchor_error_m']
                    else:
                        knee_offset = rotate_z(hip,[0.,-upper,0.])
                        distal_offset = rotate_z(hip+knee,[local[0],local[1]-lower/2,local[2]])
                        offset = [a+b for a,b in zip(knee_offset,distal_offset)]
                        anchor_error = sum(joints[2*i+j]['anchor_error_m'] for j in (0,1))
                    torso_local = [a+b for a,b in zip(origin,offset)]
                predicted = [a+b for a,b in zip(p,rotate(q,torso_local))]
                error = [a-b for a,b in zip(predicted,actual)]
                rows.append(dict(semantic_step=observation['semantic_step'],body_id=body,
                    classified_as_foot=sample['classified_as_foot'],
                    engine_contact_id=sample['engine_contact_id'],
                    native_contact_world_m=actual, ideal_contact_world_m=predicted,
                    ideal_minus_native_world_m=error, distance_m=math.dist(predicted,actual),
                    summed_measured_chain_anchor_error_m=anchor_error))
    by_body = {}
    for body in sorted({r['body_id'] for r in rows}):
        subset = [r for r in rows if r['body_id']==body]
        by_body[body] = dict(samples=len(subset), maximum_position_error_m=max(r['distance_m'] for r in subset),
            maximum_absolute_vertical_error_m=max(abs(r['ideal_minus_native_world_m'][1]) for r in subset),
            maximum_summed_anchor_error_m=max(r['summed_measured_chain_anchor_error_m'] for r in subset),
            first=subset[0], maximum=max(subset,key=lambda r:r['distance_m']))
    assert len({r['semantic_step'] for r in rows}) == 240
    # Torso pairs exercise the common position/quaternion/local-point transform
    # without assuming the two-angle articulated model is physically exact.
    assert by_body['torso']['maximum_position_error_m'] < 1e-5
    return dict(schema_version='sporespore_r10aa_native_contact_geometry_probe_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',
            authority_mode='retained_native_contact_geometry_diagnostic',question_class='development'),
        inputs=[closed.binding(p) for p in (Path(__file__),Path(closed.__file__),
            closed.ROOT/'sdk/conformance/r10z_support_geometry_diagnosis.py',report,WORLD,QUADRUPED)],
        contact_samples=len(rows), observed_steps=240, by_body=by_body, rows=rows,
        actual_distal_body_pose_retained=False, root_cause_isolated=False,
        native_contact_positions_are_source_measurements=True,
        historical_task_regraded=False, physical_acceptance_authority=False,
        release_authority=False, world_build_count=0, solver_step_count=0)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    args = parser.parse_args()
    assert args.output.resolve().is_relative_to(closed.EVIDENCE.resolve())
    assert not args.output.exists()
    value = derive()
    with args.output.open('x',encoding='utf-8',newline='\n') as stream:
        stream.write(json.dumps(value,indent=2,allow_nan=False)+'\n')
    print(json.dumps({k:{name:row[name] for name in ('samples','maximum_position_error_m','maximum_absolute_vertical_error_m','maximum_summed_anchor_error_m')} for k,row in value['by_body'].items()}))
