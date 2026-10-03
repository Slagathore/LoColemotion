"""Offline diagnosis of consumed R10AA load loss; no controller or physics.

The original R10Z geometry search is reconstructed on all exposed partial
observations. Retained loaded-rise outputs must match before counterfactual
support-direction filters are considered. A feasible mathematical target is
not a force prediction, native tracking proof, or acceptance result.
"""
import argparse
import json
import math
from pathlib import Path
import statistics

import r10aa_first_support_closure as closed

ROOT, EVIDENCE = closed.ROOT, closed.EVIDENCE
KERNEL = ROOT / 'sdk/core/src/recovery_runtime/partial_pose_geometry_control.rs'
THRESHOLD = 0.019293
DT = 1 / 120
SCALES = (1., .5, .25, .125, .0625)


def rotate(q, v):
    x, y, z, w = (q[k] for k in ('x', 'y', 'z', 'w'))
    return [(1-2*(y*y+z*z))*v[0]+2*(x*y-z*w)*v[1]+2*(x*z+y*w)*v[2],
            2*(x*y+z*w)*v[0]+(1-2*(x*x+z*z))*v[1]+2*(y*z-x*w)*v[2],
            2*(x*z-y*w)*v[0]+2*(y*z+x*w)*v[1]+(1-2*(x*x+y*y))*v[2]]


def inverse(q):
    return {k: v if k == 'w' else -v for k, v in q.items()}


def blend(q, end, fraction):
    sign = -1 if sum(q[k]*end[k] for k in q) < 0 else 1
    out = {k: q[k]+(sign*end[k]-q[k])*fraction for k in q}
    norm = math.sqrt(sum(v*v for v in out.values()))
    return {k: v/norm for k, v in out.items()}


def add(a, b):
    return [x+y for x, y in zip(a, b)]


def sub(a, b):
    return [x-y for x, y in zip(a, b)]


class Model:
    def __init__(self, observation, descriptor):
        self.o, self.d = observation, descriptor
        state = observation['state']
        self.q = state['base_pose_world']['orientation_xyzw']
        self.p = [state['base_pose_world']['position_m'][k] for k in ('x', 'y', 'z')]
        self.com = [observation['center_of_mass']['position_world_m'][k] for k in ('x', 'y', 'z')]
        self.measured = [j['position_rad'] for j in state['ordered_joint_observations']]
        self.upper = .35*descriptor['upper_length_fraction']
        self.lower = .35*(1-descriptor['upper_length_fraction'])
        self.feet = [self.foot(i, self.measured) for i in range(4)]
        self.impulses = [b['bearing_normal_impulse_ns'] for b in observation['ordered_foot_bearing_observations']]
        self.bearing = [c['presence'] and c['bears_support'] and b['ordinary_unilateral_contact'] and b['bearing_normal_impulse_ns'] > 0
                        for c, b in zip(state['ordered_contact_observations'], observation['ordered_foot_bearing_observations'])]
        self.qualified = [b and impulse >= THRESHOLD for b, impulse in zip(self.bearing, self.impulses)]
        floors = [f[1]-.04*descriptor['foot_radius_scale'] for f, b in zip(self.feet, self.bearing) if b]
        self.floor = statistics.median(floors) if floors else None
        forward = rotate(self.q, [1., 0., 0.])
        self.yaw = math.atan2(-forward[2], forward[0])
        self.flat = dict(x=0., y=math.sin(self.yaw*.5), z=0., w=math.cos(self.yaw*.5))
        self.com_local = rotate(inverse(self.q), sub(self.com, self.p))
        self.center = [sum(f[i] for f in self.feet)/4 for i in range(3)]
        self.goal_y = None if self.floor is None else self.floor+.92*(self.upper+self.lower)+.04*descriptor['foot_radius_scale']

    def hip(self, i):
        return [(.2 if i < 2 else -.2)*self.d['hip_span_scale'], 0.,
                (-.18 if i % 2 == 0 else .18)*self.d['hip_span_scale']]

    def foot(self, i, joints):
        h, k = joints[2*i:2*i+2]
        local = add(self.hip(i), [self.upper*math.sin(h)+self.lower*math.sin(h+k),
                                 -self.upper*math.cos(h)-self.lower*math.cos(h+k), 0.])
        return add(self.p, rotate(self.q, local))

    def solve(self, targets, position, rotation):
        result, residual = [], 0.
        for i, target in enumerate(targets):
            local = sub(rotate(inverse(rotation), sub(target, position)), self.hip(i))
            residual = max(residual, abs(local[2]))
            if residual > .0005:
                return None
            cosine = (local[0]**2+local[1]**2-self.upper**2-self.lower**2)/(2*self.upper*self.lower)
            if not -1 <= cosine <= 1:
                return None
            angle, best = math.acos(cosine), None
            for knee in (angle, -angle):
                hip = math.atan2(local[0], -local[1])-math.atan2(self.lower*math.sin(knee), self.upper+self.lower*math.cos(knee))
                dh, dk = hip-self.measured[2*i], knee-self.measured[2*i+1]
                if abs(hip) > 1.6 or abs(knee) > 1.1 or max(abs(dh), abs(dk)) > 4*DT:
                    continue
                value = (dh*dh+dk*dk, hip, knee)
                if best is None or value[0] < best[0]:
                    best = value
            if best is None:
                return None
            result.extend(best[1:])
        return result, residual

    def cost(self, position, rotation, targets):
        com = add(position, rotate(rotation, self.com_local))
        tilt = math.acos(max(-1., min(1., rotate(rotation, [0., 1., 0.])[1])))
        return ((com[0]-self.center[0])**2+(com[2]-self.center[2])**2+
                (position[1]-self.goal_y)**2+.04*tilt*tilt+
                sum(max(targets[i][1]-self.floor-.04*self.d['foot_radius_scale'], 0.)**2 for i in range(4) if not self.bearing[i]))

    def search(self):
        if self.floor is None:
            return dict(feasible=0, selected={}, candidates=[])
        initial = self.cost(self.p, self.q, self.feet)
        best = {key: initial for key in ('original', 'downward_quarter', 'translation_only')}
        selected, candidates, feasible = {}, [], 0
        for scale in SCALES:
            distance = .1*DT*scale
            for dx in (-distance, 0., distance):
                for dy in (-distance, 0., distance):
                    for fraction in (-.6*DT*scale, 0., .6*DT*scale):
                        delta = [dx*math.cos(self.yaw), dy, -dx*math.sin(self.yaw)]
                        position, rotation = add(self.p, delta), blend(self.q, self.flat, fraction)
                        targets = [list(f) for f in self.feet]
                        for i in range(4):
                            if not self.bearing[i] and targets[i][1] > self.floor+.04*self.d['foot_radius_scale']:
                                targets[i][1] = max(targets[i][1]-distance, self.floor+.04*self.d['foot_radius_scale'])
                        solution = self.solve(targets, position, rotation)
                        if solution is None:
                            continue
                        feasible += 1
                        joints, residual = solution
                        value = self.cost(position, rotation, targets)
                        if value >= initial-1e-12:
                            continue
                        downward = [self.foot(i, joints)[1]-self.feet[i][1] for i in range(4)]
                        candidate = dict(scale=scale, translation=delta, blend=fraction, targets=joints,
                                         cost=value, lateral_residual=residual, fixed_torso_foot_dy=downward)
                        candidates.append(candidate)
                        admissible = dict(original=True,
                            downward_quarter=dy > 0 and all(y <= -.25*dy+1e-12 for y in downward),
                            translation_only=dy > 0 and fraction == 0.)
                        for key, allowed in admissible.items():
                            if allowed and value < best[key]-1e-12:
                                best[key], selected[key] = value, candidate
        return dict(feasible=feasible, selected=selected, candidates=candidates)


def summary(values):
    return dict(minimum=min(values), median=statistics.median(values), maximum=max(values))


def derive():
    assert closed.audit()['execution_valid']
    observations, parity, control = [], 0, []
    for kind, packet in closed.partial_records(closed.CHILD / 'worker_report.json'):
        if kind != 'packet':
            continue
        request = json.loads(packet['call']['request']['utf8_text'])
        observation, descriptor = request['step']['observation'], request['collection']['descriptor']
        receipt = packet['native_receipt']; plan = receipt['next_load_plan']
        model = Model(observation, descriptor)
        search = model.search()
        if plan is not None and plan['mode'] == 'loaded_geometry_rise':
            retained, rebuilt = plan['rise_geometry'], search['selected']['original']
            assert search['feasible'] == retained['feasible_candidate_count']
            assert rebuilt['scale'] == retained['selected_candidate_scale'] and rebuilt['blend'] == retained['selected_virtual_level_blend']
            assert max(abs(a-b) for a,b in zip(rebuilt['targets'],retained['ordered_target_positions_rad'])) < 1e-10
            assert abs(rebuilt['cost']-retained['selected_model_cost']) < 1e-12
            parity += 1
        observations.append(dict(step=len(observations)+1, phase=receipt['step']['prior_phase'],
            next_phase=receipt['step']['next_phase'], original_mode=plan['mode'] if plan else None,
            all_qualified=all(model.qualified), impulses=model.impulses, qualified=model.qualified,
            com_y=observation['center_of_mass']['position_world_m']['y'], joints=model.measured,
            original_targets=plan['ordered_target_positions_rad'] if plan else None,
            alternatives=search['selected'], model_feasible_candidates=search['feasible']))
    assert len(observations) == 646 and parity == 44
    for before, after in zip(observations, observations[1:]):
        if before['original_mode'] != 'loaded_geometry_rise':
            continue
        assert before['all_qualified'] and not after['all_qualified']
        requested = [a-b for a,b in zip(before['original_targets'],before['joints'])]
        measured = [a-b for a,b in zip(after['joints'],before['joints'])]
        control.append(dict(step=before['step'], minimum_load_ratio_before=min(before['impulses'])/THRESHOLD,
            minimum_load_ratio_after=min(after['impulses'])/THRESHOLD,
            lost_feet=[i for i,q in enumerate(after['qualified']) if not q],
            requested_joint_delta=requested, actual_joint_delta=measured,
            direction_alignment=[a*b > 0 for a,b in zip(requested,measured)],
            actual_com_delta_y=after['com_y']-before['com_y']))
    assert len(control) == 44 and all(all(event['direction_alignment']) for event in control)
    loaded = [o for o in observations if o['original_mode'] == 'loaded_geometry_rise']
    counts = {key: sum(key in o['alternatives'] for o in loaded)
              for key in ('original', 'downward_quarter', 'translation_only')}
    claims = dict(world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)
    return dict(schema_version='sporespore_r10ab_loaded_rise_diagnosis_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='engine_neutral_geometry',authority_mode='retained_input_offline_diagnosis',question_class='development'),
        dependencies=[closed.binding(p) for p in (Path(__file__), KERNEL, closed.RECORD, Path(closed.__file__))],
        source_report=closed.binding(closed.CHILD / 'worker_report.json'), original_source_commit=closed.HEAD,
        original_physical_result_changed=False, prospective_controller_implemented=False,
        exposed_observations=len(observations), retained_loaded_plan_parity_count=parity,
        loaded_event_summary=dict(count=len(control), all_joint_direction_alignments=352,
            minimum_load_ratio_before=summary([e['minimum_load_ratio_before'] for e in control]),
            minimum_load_ratio_after=summary([e['minimum_load_ratio_after'] for e in control]),
            actual_com_delta_y=summary([e['actual_com_delta_y'] for e in control]),
            lost_foot_counts=[sum(i in e['lost_feet'] for e in control) for i in range(4)],
            original_upward_foot_target_counts=[sum(o['alternatives']['original']['fixed_torso_foot_dy'][i] > 1e-9 for o in loaded) for i in range(4)],
            alternative_feasibility_counts=counts),
        observations=observations, loaded_events=control,
        limitations=['Geometry feasibility does not predict contact force or closed-loop recovery.',
            'Counterfactual targets on unqualified or terminal observations are model probes, never admitted motor commands.',
            'No held-out inputs, physics rerun, deadline change, or acceptance threshold change.'], **claims)


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    assert args.output.resolve().is_relative_to(EVIDENCE.resolve()) and not args.output.exists()
    result=derive()
    with args.output.open('x',encoding='utf-8',newline='\n') as stream:
        json.dump(result,stream,indent=2,allow_nan=False);stream.write('\n')
    print(json.dumps(dict(ok=True,exposed_observations=result['exposed_observations'],retained_loaded_plan_parity_count=result['retained_loaded_plan_parity_count'],loaded_event_summary=result['loaded_event_summary'],world_build_count=0,solver_step_count=0)))
