"""Post-exposure mathematical plan propagation, never a physics surrogate.

First reproduce every retained loaded plan. Then propagate the original finite
search for at most 600 mathematical updates from the first and last loaded poses.
Assume every planned torso/joint update succeeds and all four contacts remain
qualified. Carry torso-local COM unchanged, as the one-step cost itself does.
This deliberately omits dynamics and may expose a planning stall, but cannot
predict native support, balance, recovery, or acceptance.
"""
import copy
import json
import math
import statistics

import r10af_detection_frame_closure as closure
import r10ab_loaded_rise_diagnosis as geometry


def advance(model, plan):
    """Change only a Python mathematical model, never a native observation."""
    out = copy.copy(model)
    out.o = None  # Never present hypothetical states as source observations.
    out.p = geometry.add(model.p, plan['translation'])
    out.q = geometry.blend(model.q, model.flat, plan['blend'])
    out.measured = plan['targets'][:]
    out.com = geometry.add(out.p, geometry.rotate(out.q, model.com_local))
    out.feet = [out.foot(i, out.measured) for i in range(4)]
    out.floor = statistics.median(f[1] - .04*out.d['foot_radius_scale'] for f in out.feet)
    forward = geometry.rotate(out.q, [1., 0., 0.])
    out.yaw = math.atan2(-forward[2], forward[0])
    out.flat = dict(x=0., y=math.sin(out.yaw*.5), z=0., w=math.cos(out.yaw*.5))
    out.center = [sum(f[i] for f in out.feet)/4 for i in range(3)]
    out.goal_y = out.floor + .92*(out.upper+out.lower) + .04*out.d['foot_radius_scale']
    return out


def snapshot(model, update):
    return dict(mathematical_update=update, position_m=model.p,
        orientation_xyzw=model.q, joint_positions_rad=model.measured,
        torso_up_dot=geometry.rotate(model.q, [0., 1., 0.])[1],
        modeled_height_goal_gap_m=model.goal_y-model.p[1],
        modeled_floor_y_m=model.floor)


def propagate(model, bound=600, selection='downward_quarter'):
    assert all(model.qualified)
    states = [snapshot(model, 0)]
    for update in range(1, bound+1):
        search = model.search()
        plan = search['selected'].get(selection)
        if plan is None:
            return dict(stop='no_admissible_cost_decreasing_plan', updates=update-1,
                final=snapshot(model, update-1), snapshots=states,
                other_filter_plans_at_stop=search['selected'])
        model = advance(model, plan)
        if update % 60 == 0:
            states.append(snapshot(model, update))
    return dict(stop='declared_600_update_bound', updates=bound,
        final=snapshot(model, bound), snapshots=states)


def analyze():
    path = closure.CHILD / 'worker_report.json'
    assert closure.bind(path)['raw_sha256'] == closure.REPORT_SHA
    descriptor = closure.streams.small_fields(path)['configuration']['base_descriptor']
    loaded, parity = [], 0
    for kind, packet in closure.streams.partial_records(path):
        if kind != 'packet':
            continue
        native = packet['native_receipt']
        plan = native['next_load_plan']
        if plan is None or plan['mode'] != 'loaded_downward_rise':
            continue
        model = geometry.Model(native['collection']['observation'], descriptor)
        search = model.search()
        selected = search['selected']['downward_quarter']
        retained = plan['rise_geometry']
        assert search['feasible'] == retained['feasible_candidate_count']
        assert selected['scale'] == retained['selected_candidate_scale']
        assert selected['blend'] == retained['selected_virtual_level_blend']
        assert max(abs(x-y) for x,y in zip(selected['targets'], retained['ordered_target_positions_rad'])) < 1e-10
        assert abs(selected['cost']-retained['selected_model_cost']) < 1e-12
        loaded.append((native['collection']['observation']['semantic_step'], model))
        parity += 1
    assert parity == 138
    return dict(original_loaded_plan_parity_count=parity,
        protocol='First and last retained loaded poses; current downward-filtered search and separately labeled predecessor-filter ablation; at most 600 mathematical updates per pose/filter; exact planned pose and joint tracking assumed; four contacts assumed qualified; torso-local COM held constant.',
        limits='Model propagation only. No dynamics, contact-force prediction, native collection, task evaluation or counterfactual causal effect.',
        trajectories=[dict(original_semantic_step=step, result=propagate(model)) for step, model in (loaded[0], loaded[-1])],
        predecessor_filter_ablation=[dict(original_semantic_step=step,
            result=propagate(model, selection='original')) for step, model in (loaded[0], loaded[-1])],
        world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)


if __name__ == '__main__':
    print(json.dumps(analyze(), indent=2))
