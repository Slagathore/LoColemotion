"""Offline support-placement feasibility on exposed measurements, never physics.

The torso stays a fixed mathematical input. Grid targets are counterfactual
joint positions, not motor commands, loaded contacts, or a recovery controller.
No consumed source key or physical result is modified by this probe.
"""
import argparse
import json
import math
from pathlib import Path
import statistics

import r10z_first_support_closure as closed
from r10z_support_geometry_diagnosis import rotate, sample

ROOT = closed.ROOT
ENTRIES = ROOT / 'sdk/core/contracts/r10z_retained_partial_entries_v1.json'
KERNEL = ROOT / 'sdk/core/src/recovery_runtime/partial_pose_geometry_control.rs'
STEP = 4 / 120


def foot(descriptor, position, rotation, limb, hip, knee):
    upper = .35 * descriptor['upper_length_fraction']
    lower = .35 * (1 - descriptor['upper_length_fraction'])
    local = [(.2 if limb < 2 else -.2) * descriptor['hip_span_scale']
             + upper * math.sin(hip) + lower * math.sin(hip + knee),
             -upper * math.cos(hip) - lower * math.cos(hip + knee),
             (-.18 if limb % 2 == 0 else .18) * descriptor['hip_span_scale']]
    return [p + v for p, v in zip(position, rotate(rotation, local))]


def grid(angle, limit):
    lower, upper = max(-limit, angle - STEP), min(limit, angle + STEP)
    assert lower <= upper
    return sorted(set([lower + (upper - lower) * i / 8 for i in range(9)]
                      + [min(upper, max(lower, angle))]))


def inspect(observation, descriptor, label, plan=None):
    state = observation['state']
    q = state['base_pose_world']['orientation_xyzw']
    p = [state['base_pose_world']['position_m'][k] for k in ('x', 'y', 'z')]
    joints = [j['position_rad'] for j in state['ordered_joint_observations']]
    measured = sample(observation, descriptor, 0)
    sites = measured['sites']
    radius = .04 * descriptor['foot_radius_scale']
    feet = [foot(descriptor, p, q, i, *joints[2*i:2*i+2]) for i in range(4)]
    assert all(math.dist(f, s['ideal_foot_center_world_m']) < 1e-12 for f, s in zip(feet, sites))
    bearing = [c['presence'] and c['bears_support'] and b['ordinary_unilateral_contact']
               and b['bearing_normal_impulse_ns'] > 0
               for c, b in zip(state['ordered_contact_observations'], observation['ordered_foot_bearing_observations'])]
    floors = [f[1] - radius for f, b in zip(feet, bearing) if b]
    floor = statistics.median(floors) if floors else None
    limbs = []
    for i, site in enumerate(sites):
        hip, knee = joints[2*i:2*i+2]
        row = dict(limb=site['limb'], bearing_reference=bearing[i],
                   native_load_gate=site['native_load_gate'],
                   native_impulse_ns=site['native_bearing_impulse_ns'])
        if floor is not None:
            gap = feet[i][1] - radius - floor
            choices = []
            for h in grid(hip, 1.6):
                for k in grid(knee, 1.1):
                    target = foot(descriptor, p, q, i, h, k)
                    target_gap = target[1] - radius - floor
                    # Contact seeking ends at the modeled plane. Do not
                    # interpret penetration or a model intersection as load.
                    if target_gap < -1e-9:
                        continue
                    choices.append((abs(target_gap), (h-hip)**2+(k-knee)**2,
                                    h, k, target, target_gap))
            best = min(choices) if choices else None
            row.update(gap_m=gap,
                optimistic_unrestricted_ground_shortfall_m=site['optimistic_lowest_foot_bottom_at_fixed_torso_world_y_m']-floor,
                bounded_grid_candidate_count=len(choices),
                candidate_joint_positions_rad=list(best[2:4]) if best else None,
                candidate_gap_m=best[5] if best else None,
                candidate_horizontal_motion_m=math.hypot(best[4][0]-feet[i][0], best[4][2]-feet[i][2]) if best else None,
                positive_gap_decreased=best is not None and gap > 1e-9 and best[0] < gap-1e-9)
            if best:
                assert abs(best[2]) <= 1.6 and abs(best[3]) <= 1.1
                assert max(abs(best[2]-hip), abs(best[3]-knee)) <= STEP + 1e-12
        limbs.append(row)
    parity = None
    if plan is not None:
        assert floor is not None and abs(floor-plan['modeled_support_plane_world_y_m']) < 1e-12
        assert sum(bearing) == plan['bearing_reference_count']
        forward = rotate(q, [1, 0, 0]); yaw = math.atan2(-forward[2], forward[0])
        flat = dict(x=0., y=math.sin(yaw/2), z=0., w=math.cos(yaw/2))
        if sum(q[k]*flat[k] for k in q) < 0:
            flat = {k: -v for k, v in flat.items()}
        blend = plan['selected_virtual_level_blend']
        virtual_q = {k: q[k]+(flat[k]-q[k])*blend for k in q}
        norm = math.sqrt(sum(v*v for v in virtual_q.values()))
        virtual_q = {k: v/norm for k, v in virtual_q.items()}
        virtual_p = [a+b for a,b in zip(p, plan['selected_virtual_translation_world_m'])]
        targets = plan['ordered_target_positions_rad']
        residuals = []
        for i in range(4):
            expected = feet[i].copy()
            if not bearing[i] and expected[1] > floor+radius:
                expected[1] = max(floor+radius, expected[1] - .1/120*plan['selected_candidate_scale'])
            actual = foot(descriptor, virtual_p, virtual_q, i, *targets[2*i:2*i+2])
            residuals.append(math.dist(actual, expected))
        parity = max(residuals)
        assert abs(parity-plan['maximum_unactuated_lateral_residual_m']) < 1e-10
    return dict(label=label, semantic_step=observation['semantic_step'],
        bearing_reference_count=sum(bearing), modeled_floor_y_m=floor,
        modeled_bearing_floor_spread_m=max(floors)-min(floors) if floors else None,
        native_plan_fk_residual_m=parity, limbs=limbs)


def derive():
    entries = closed.read(ENTRIES)['entries']
    rows, inputs = [], [closed.binding(p) for p in (Path(__file__), ENTRIES, KERNEL,
        ROOT/'sdk/conformance/r10z_support_geometry_diagnosis.py', Path(closed.__file__))]
    for entry in entries:
        assert entry['report'] == closed.binding(Path(entry['report']['path']))
        inputs.append(entry['report'])
        # These extracted entries were checked against native request bytes by
        # the immutable R10Z native component closure. No held-out data is read.
        rows.append(inspect(entry['observation'], entry['descriptor'], 'retained_seed_'+str(entry['seed'])))
    report = closed.CHILD/'worker_report.json'
    assert closed.binding(report)['raw_sha256'] == closed.REPORT_SHA
    inputs.append(closed.binding(report))
    descriptor = None
    count = parity = 0
    for kind, value in closed.partial_records(report):
        if kind == 'declaration':
            passive = value['entry_request']['passive_request']
            descriptor = passive['declaration']['initialization']['descriptor']
            rows.append(inspect(passive['observation'], descriptor, 'r10z_entry'))
        elif kind == 'packet':
            assert descriptor is not None and value['call']['value'] == value['native_receipt']
            receipt = value['native_receipt']; count += 1
            plan = receipt['next_geometry_plan']
            parity += plan is not None
            rows.append(inspect(receipt['collection']['observation'], descriptor, 'r10z_step_'+str(count), plan))
    assert count == 240 and parity == 239 and len(rows) == 245
    unsupported = [s for r in rows for s in r['limbs'] if not s['bearing_reference']]
    return dict(schema_version='sporespore_r10aa_support_first_workspace_probe_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='engine_neutral_geometry',
            authority_mode='offline_exposed_measurement_diagnostic',question_class='development'),
        inputs=inputs, rows=rows,
        summary=dict(measured_poses=len(rows), native_plan_geometry_checks=parity,
            unsupported_limb_samples=len(unsupported),
            positive_gap_samples=sum(s.get('gap_m', 0)>1e-9 for s in unsupported),
            bounded_gap_decrease_samples=sum(s.get('positive_gap_decreased', False) for s in unsupported),
            unrestricted_fixed_torso_unreachable_samples=sum(s.get('optimistic_unrestricted_ground_shortfall_m', 0)>1e-9 for s in unsupported),
            nonbearing_at_or_below_modeled_plane_samples=sum(s.get('gap_m', 1)<=1e-9 for s in unsupported)),
        model_grid_is_not_exhaustive=True, torso_is_fixed_model_input=True,
        body_dynamics_evaluated=False, contact_force_evaluated=False,
        motor_tracking_evaluated=False, candidate_controller_declared=False,
        historical_task_regraded=False, physical_acceptance_authority=False,
        release_authority=False, world_build_count=0, solver_step_count=0)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    assert args.output.resolve().is_relative_to(closed.EVIDENCE.resolve())
    assert not args.output.exists()
    value = derive()
    with args.output.open('x', encoding='utf-8', newline='\n') as stream:
        stream.write(json.dumps(value, indent=2, allow_nan=False)+'\n')
    print(json.dumps(value['summary']), flush=True)
