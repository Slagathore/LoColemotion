"""Describe retained R10Y loads and ideal geometry; never step a physical world.

Forward kinematics is a model calculation using measured joints and torso pose.
It is not a replacement for native contact observations or an acceptance test.
"""
import argparse
import json
import math
from pathlib import Path
import subprocess
import r10y_first_support_closure as prior

ROOT = prior.ROOT
RECORD = ROOT / 'sdk/recovery/r10z_support_geometry_diagnosis_v1.json'
LIMBS = ('front_left', 'front_right', 'rear_left', 'rear_right')
THRESHOLD = 0.019293


def rotate(q, v):
    x, y, z, w = (q[k] for k in ('x', 'y', 'z', 'w'))
    return [
        (1-2*(y*y+z*z))*v[0] + 2*(x*y-z*w)*v[1] + 2*(x*z+y*w)*v[2],
        2*(x*y+z*w)*v[0] + (1-2*(x*x+z*z))*v[1] + 2*(y*z-x*w)*v[2],
        2*(x*z-y*w)*v[0] + 2*(y*z+x*w)*v[1] + (1-2*(x*x+y*y))*v[2],
    ]


def hull_margin(points, point):
    """Signed distance to the ideal horizontal foot-center convex hull edges."""
    def cross(a, b, c):
        return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
    ordered = sorted(set(tuple(p) for p in points))
    assert len(ordered) >= 3
    lower, upper = [], []
    for chain, source in ((lower, ordered), (upper, reversed(ordered))):
        for p in source:
            while len(chain) >= 2 and cross(chain[-2], chain[-1], p) <= 0:
                chain.pop()
            chain.append(p)
    hull = lower[:-1] + upper[:-1]
    assert len(hull) >= 3
    return min(cross(a, b, point)/math.dist(a, b)
               for a, b in zip(hull, hull[1:]+hull[:1]))


def sample(observation, descriptor, partial_step):
    state = observation['state']
    joints = state['ordered_joint_observations']
    assert [j['joint_id'] for j in joints] == [f'{leg}_{joint}' for leg in LIMBS for joint in ('hip', 'knee')]
    contacts, loads = state['ordered_contact_observations'], observation['ordered_foot_bearing_observations']
    assert [c['contact_site_id'] for c in contacts] == [f'{leg}_foot' for leg in LIMBS]
    assert [c['contact_site_id'] for c in loads] == [f'{leg}_foot' for leg in LIMBS]
    pose = state['base_pose_world']; q = pose['orientation_xyzw']
    p = [pose['position_m'][k] for k in ('x', 'y', 'z')]
    a, b, c = [rotate(q, v)[1] for v in ([1,0,0], [0,1,0], [0,0,1])]
    upper = .35*descriptor['upper_length_fraction']; lower = .35-upper
    radius = .04*descriptor['foot_radius_scale']
    feet, reach, sites = [], [], []
    for i, name in enumerate(LIMBS):
        hip, knee = [joints[2*i+j]['position_rad'] for j in (0,1)]
        x = (.2 if i < 2 else -.2)*descriptor['hip_span_scale']
        z = (-.18 if i % 2 == 0 else .18)*descriptor['hip_span_scale']
        local = [x+upper*math.sin(hip)+lower*math.sin(hip+knee),
                 -upper*math.cos(hip)-lower*math.cos(hip+knee), z]
        world = [base+offset for base, offset in zip(p, rotate(q, local))]
        feet.append(world)
        # An optimistic lower bound even without joint limits: two aligned
        # links have at most (upper+lower)*hypot(a,b) vertical reach.
        bound = p[1]+a*x+c*z-(upper+lower)*math.hypot(a,b)-radius
        reach.append(bound)
        sites.append(dict(limb=name, native_contact=contacts[i]['presence'],
            native_bears_support=contacts[i]['bears_support'],
            native_bearing_impulse_ns=loads[i]['bearing_normal_impulse_ns'],
            native_load_gate=contacts[i]['presence'] and contacts[i]['bears_support']
                and loads[i]['ordinary_unilateral_contact'] and loads[i]['bearing_normal_impulse_ns'] >= THRESHOLD,
            ideal_foot_center_world_m=world, ideal_foot_bottom_world_y_m=world[1]-radius,
            optimistic_lowest_foot_bottom_at_fixed_torso_world_y_m=bound))
    com = observation['center_of_mass']['position_world_m']
    bodies = observation['ordered_body_clearance_observations']
    return dict(partial_step=partial_step, semantic_step=observation['semantic_step'],
        torso_forward_world_y=a, torso_up_world_y=b, sagittal_pitch_rad=math.atan2(a,b),
        torso_position_world_m=p, native_com_world_m=com,
        ideal_all_four_foot_center_hull_com_margin_m=hull_margin([[f[0],f[2]] for f in feet], [com['x'],com['z']]),
        maximum_native_anchor_error_m=max(j['anchor_error_m'] for j in joints),
        native_nonfoot_impulses_ns={row['body_id']: row['accumulated_nonfoot_normal_impulse_ns'] for row in bodies},
        sites=sites)


def derive():
    assert prior.binding(prior.CHILD/'worker_report.json')['raw_sha256'] == prior.REPORT_SHA
    record = prior.read(prior.RECORD)
    for row in record['dependencies']:
        assert row == prior.binding(Path(row['path']))
    rows, descriptor = [], None
    for kind, value in prior.partial_records(prior.CHILD/'worker_report.json'):
        if kind == 'declaration':
            init = value['entry_request']['passive_request']['declaration']['initialization']
            descriptor = init['descriptor']
            assert init['morphology_context']['recovery_descriptor']['joint_authority'] == dict(
                hip_anchor_parent_y_m=0.0, hip_limit_magnitude_rad=1.6, knee_limit_magnitude_rad=1.1)
        elif kind == 'packet':
            assert descriptor is not None and value['call']['value'] == value['native_receipt']
            step = value['native_receipt']['step']
            assert step['prior_phase'] == 'establish_distal_support'
            row = sample(value['native_receipt']['collection']['observation'], descriptor, len(rows)+1)
            assert row['semantic_step'] == 513+len(rows)
            assert all(s['native_load_gate'] for s in row['sites']) == step['classification']['distal_support_gate']
            rows.append(row)
    assert len(rows) == 240
    per_site = {}
    for i, name in enumerate(LIMBS):
        values = [r['sites'][i] for r in rows]
        per_site[name] = dict(
            first_contact_absent=next((j+1 for j,v in enumerate(values) if not v['native_contact']), None),
            first_bearing_absent=next((j+1 for j,v in enumerate(values) if not v['native_bears_support']), None),
            load_gate_samples=sum(v['native_load_gate'] for v in values),
            native_impulse_range_ns=[min(v['native_bearing_impulse_ns'] for v in values), max(v['native_bearing_impulse_ns'] for v in values)],
            first_fixed_torso_geometrically_unreachable_ground=next((j+1 for j,v in enumerate(values)
                if v['optimistic_lowest_foot_bottom_at_fixed_torso_world_y_m'] > 0), None))
    return dict(native_samples=240, native_four_site_load_gate_samples=sum(all(s['native_load_gate'] for s in r['sites']) for r in rows),
        per_site=per_site, ideal_hull_com_margin_range_m=[min(r['ideal_all_four_foot_center_hull_com_margin_m'] for r in rows), max(r['ideal_all_four_foot_center_hull_com_margin_m'] for r in rows)],
        snapshots=[r for r in rows if r['partial_step'] in (1,30,33,60,90,120,150,180,210,240)],
        world_build_count=0, solver_step_count=0, original_task_regraded=False,
        geometry_is_ideal_model=True, native_foot_position_measurement=False,
        matched_causal_effect_proven=False, physical_acceptance_authority=False, release_authority=False)


def dependencies():
    return [prior.binding(p) for p in [Path(__file__), prior.RECORD]]


def verify_frozen_sources(rows):
    for row in rows:
        name = Path(row['path']).relative_to(ROOT).as_posix()
        raw = subprocess.check_output(['git', 'show', prior.HEAD+':'+name], cwd=ROOT)
        assert prior.history.raw_matches(raw, row) or (b'\r\n' not in raw and
            prior.history.raw_matches(raw.replace(b'\n', b'\r\n'), row)), name


def geometry_controls():
    # Independent closed-form cases check the frame and hull-sign conventions.
    q = dict(x=0., y=0., z=math.sin(math.pi/4), w=math.cos(math.pi/4))
    assert math.dist(rotate(q, [1,0,0]), [0,1,0]) < 1e-12
    assert math.dist(rotate(q, [0,-1,0]), [1,0,0]) < 1e-12
    square = [[-1,-1], [-1,1], [1,-1], [1,1]]
    assert hull_margin(square, [0,0]) == 1
    assert hull_margin(square, [2,0]) == -1
    assert hull_margin(square, [1,0]) == 0


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', action='store_true')
    args = parser.parse_args()
    geometry_controls()
    observed = derive()
    if args.capture:
        frozen_sources = [prior.binding(ROOT/name) for name in ('sdk/core/src/quadruped.rs',
            'sdk/core/src/recovery.rs', 'sdk/core/src/recovery_runtime.rs',
            'sdk/adapters/godot/gdscript/recovery_native_world_v1.gd')]
        verify_frozen_sources(frozen_sources)
        value = dict(schema_version='sporespore_r10z_support_geometry_diagnosis_v1',
            ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='retained_development_diagnosis', question_class='development'),
            dependencies=dependencies(), retained_report=prior.binding(prior.CHILD/'worker_report.json'),
            frozen_geometry_sources=frozen_sources,
            source_execution_commit=prior.HEAD, observed=observed,
            conventions=dict(limb_order=list(LIMBS), coordinate_frame='right_handed_x_forward_y_up_z_right_si_v1', joint_axis='+Z',
                floor_top_world_y_m=0.0, native_distal_bearing_minimum_impulse_ns=THRESHOLD,
                model='Production link lengths, hip offsets, measured torso quaternion and measured joint angles; ideal rigid anchors.'),
            inference='Neutral joint motion loses front loading while rear feet and torso retain load. At late measured torso poses even unconstrained front-leg extension cannot reach the floor. Prioritize measured torso orientation, foot placement and load distribution; this diagnosis does not prove a new controller will recover.',
            launch_authority=False, physical_acceptance_authority=False, release_authority=False)
        with RECORD.open('x', encoding='utf-8', newline='\n') as stream:
            stream.write(json.dumps(value, indent=2, allow_nan=False)+'\n')
    else:
        value = prior.read(RECORD)
        assert value['dependencies'] == dependencies()
        verify_frozen_sources(value['frozen_geometry_sources'])
        assert value['retained_report'] == prior.binding(prior.CHILD/'worker_report.json')
        assert value['observed'] == observed
    print('R10Z_SUPPORT_GEOMETRY ' + json.dumps({k:v for k,v in observed.items() if k != 'snapshots'}))
