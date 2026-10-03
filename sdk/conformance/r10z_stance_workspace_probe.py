"""Bounded ideal-kinematics exploration, not simulation or recovery evidence.

Uses the consumed development entry only. The torso transforms here are virtual
planning variables. They are never written to a host, observation or task state.
"""
import argparse
import json
import math
from pathlib import Path
import r10y_first_support_closure as prior
from r10z_support_geometry_diagnosis import rotate, sample


def retained_entry():
    assert prior.binding(prior.CHILD/'worker_report.json')['raw_sha256'] == prior.REPORT_SHA
    for kind, value in prior.partial_records(prior.CHILD/'worker_report.json'):
        if kind == 'declaration':
            passive = value['entry_request']['passive_request']
            return passive['observation'], passive['declaration']['initialization']['descriptor']
    raise AssertionError('ENTRY_MISSING')


class Model:
    def __init__(self, observation, descriptor):
        self.descriptor = descriptor
        state = observation['state']
        pose = state['base_pose_world']
        self.q = pose['orientation_xyzw']
        self.position = [pose['position_m'][k] for k in ('x','y','z')]
        self.feet = [s['ideal_foot_center_world_m'] for s in sample(observation, descriptor, 0)['sites']]
        forward = rotate(self.q, [1,0,0])
        self.yaw = math.atan2(-forward[2], forward[0])
        self.end_q = dict(x=0., y=math.sin(self.yaw/2), z=0., w=math.cos(self.yaw/2))
        self.upper = .35*descriptor['upper_length_fraction']
        self.lower = .35-self.upper
        self.signs = [1 if state['ordered_joint_observations'][2*i+1]['position_rad'] >= 0 else -1 for i in range(4)]
        com = observation['center_of_mass']['position_world_m']
        self.goal = (sum((f[0]-com['x'])*math.cos(self.yaw)-(f[2]-com['z'])*math.sin(self.yaw) for f in self.feet)/4,
                     .92*.35+.04*descriptor['foot_radius_scale'], 1.)
        self.start = (0., self.position[1], 0.)

    def inverse(self, state):
        dx, y, alpha = state
        if not 0 <= alpha <= 1:
            return None
        q = {k:(1-alpha)*self.q[k]+alpha*self.end_q[k] for k in self.q}
        norm = math.sqrt(sum(v*v for v in q.values()))
        inverse_q = {k:(v/norm if k == 'w' else -v/norm) for k,v in q.items()}
        position = [self.position[0]+dx*math.cos(self.yaw), y, self.position[2]-dx*math.sin(self.yaw)]
        joints, lateral = [], []
        for i, foot in enumerate(self.feet):
            local = rotate(inverse_q, [f-p for f,p in zip(foot, position)])
            x = local[0]-(.2 if i < 2 else -.2)*self.descriptor['hip_span_scale']
            y = local[1]
            lateral.append(local[2]-(-.18 if i % 2 == 0 else .18)*self.descriptor['hip_span_scale'])
            cosine = (x*x+y*y-self.upper**2-self.lower**2)/(2*self.upper*self.lower)
            if abs(cosine) > 1:
                return None
            knee = math.acos(cosine)*self.signs[i]
            hip = math.atan2(x,-y)-math.atan2(self.lower*math.sin(knee),self.upper+self.lower*math.cos(knee))
            if abs(knee) > 1.1 or abs(hip) > 1.6:
                return None
            joints.extend([hip,knee])
        return joints, max(abs(v) for v in lateral)

    def cost(self, state):
        # The 0.20 m angular weight is the production nominal hip half-span.
        return sum((x-y)**2*w for x,y,w in zip(state, self.goal, (1.,1.,.04)))


def probe(maximum_steps=1200):
    model = Model(*retained_entry())
    state = model.start
    joints, lateral = model.inverse(state)
    trace = [dict(step=0, virtual_pose=list(state), joints_rad=joints, cost=model.cost(state), lateral_residual_m=lateral)]
    for step in range(1, maximum_steps+1):
        choices = []
        for scale in (1., .5, .25, .125, .0625):
            for dx in (-.1/120, 0., .1/120):
                for dy in (-.1/120, 0., .1/120):
                    for da in (-.6/120, 0., .6/120):
                        new = tuple(v+d*scale for v,d in zip(state, (dx,dy,da)))
                        if model.cost(new) >= model.cost(state)-1e-12:
                            continue
                        answer = model.inverse(new)
                        if answer is None:
                            continue
                        candidate, lateral = answer
                        if max(abs(a-b) for a,b in zip(joints,candidate)) <= 4/120:
                            choices.append((model.cost(new),new,candidate,lateral))
        if not choices:
            reason = 'no_cost_decreasing_bounded_local_candidate'
            break
        cost, state, joints, lateral = min(choices)
        trace.append(dict(step=step,virtual_pose=list(state),joints_rad=joints,cost=cost,lateral_residual_m=lateral))
    else:
        reason = 'finite_model_step_budget'
    return dict(schema_version='sporespore_r10z_stance_workspace_probe_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='engine_neutral_geometry',authority_mode='offline_development_model',question_class='development'),
        inputs=[prior.binding(Path(__file__)),prior.binding(prior.CHILD/'worker_report.json')],
        source_execution_commit=prior.HEAD, maximum_model_steps=maximum_steps,
        model_goal=list(model.goal), terminal_reason=reason, trace=trace,
        ideal_fixed_foot_model=True, knee_branch_preserved=True,
        lateral_foot_motion_not_actuated=True, native_tracking_proven=False,
        force_balance_evaluated=False, collision_feasibility_evaluated=False,
        recovery_task_evaluated=False, world_build_count=0,solver_step_count=0,
        physical_acceptance_authority=False,release_authority=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    assert args.output.resolve().is_relative_to(prior.EVIDENCE.resolve())
    value = probe()
    with args.output.open('x',encoding='utf-8',newline='\n') as stream:
        stream.write(json.dumps(value,indent=2,allow_nan=False)+'\n')
    print(json.dumps(dict(terminal_reason=value['terminal_reason'],model_steps=len(value['trace'])-1,
        initial=value['trace'][0],terminal=value['trace'][-1],goal=value['model_goal'],worlds=0,solver_steps=0)))
