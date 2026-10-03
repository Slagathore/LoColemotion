"""One prospectively declared quasistatic torso-slide law on exposed entry data.

Use maximum dissipation for the existing inner friction diamond. This is a
sampled kinematic/force model, not an inertial simulation or native controller.
"""
import argparse
from collections import Counter
import copy
import json
import numpy as np

import r10as_contact_motion_study as S
import r10at_fixed_contact_path as path
import r10au_contact_mode_survey as modes

C, G = S.C, S.G
STUDY = C.ROOT/'sdk/recovery/r10av_sliding_support_study_v1.json'
RESULT = C.ROOT/'sdk/recovery/r10av_sliding_support_result_v1.json'
MU = 1.8


def sector(heading):
    axis = 0 if abs(heading[0]) >= abs(heading[2]) else 2
    return axis, 1. if heading[axis] >= 0 else -1.


def force_mode_rows(columns, sliding, axis, sign, mu=MU):
    rows = []
    for index in sliding:
        drag = np.zeros(columns); drag[3*index+axis] = 1.; drag[3*index+1] = sign*mu
        transverse = np.zeros(columns); transverse[3*index+2-axis] = 1.
        rows.extend((drag, transverse))
    return np.array(rows).reshape((-1, columns))


def sector_violation(displacement, axis, sign):
    return abs(displacement[2-axis])-sign*displacement[axis]


def load(model, delta, selected, caps, axis, sign):
    packet = copy.deepcopy(model.packet); poses = model.poses(delta)
    for body in packet['callback_bodies']:
        name = body['body_id']; body['pose']['origin'] = poses[0][name].tolist()
        body['pose']['basis_columns'] = poses[1][name].T.tolist()
    for body in packet['direct_state_source']['ordered_body_states']:
        name = body['body_id']
        body['position_world_m'] = model.point(poses, name, model.local_com[name]).tolist()
    points = model.contact_points(delta); chosen = []
    for i in selected:
        point = copy.deepcopy(model.contacts[i]); point['position_world_m'] = points[i].tolist(); chosen.append(point)
    packet['contact_source_receipt']['ordered_contact_samples'] = chosen
    contacts, jacobian, rhs, weight, _ = S.statics.frame(packet, model.d, model.com(poses))
    a = np.zeros((14, 3*len(contacts)+8)); a[6:, 3*len(contacts):] = np.eye(8)
    for i, point in enumerate(contacts):
        a[:, 3*i:3*i+3] = jacobian(point['body_id'], G.vector(point['position_world_m'])).T
    sliding = [i for i, point in enumerate(contacts) if point['body_id'] == 'torso']
    extra = force_mode_rows(a.shape[1], sliding, axis, sign)
    return S.statics.solve(np.vstack((a, extra)), np.r_[rhs, np.zeros(len(extra))],
        [p['classified_as_foot'] for p in contacts], caps, MU, weight)


def residual_vector(model, delta, selected, reference):
    points = model.contact_points(delta); values = []
    for i in selected:
        difference = points[i]-reference[i]
        values.extend([difference[1]] if model.contacts[i]['body_id'] == 'torso' else difference)
    return np.array(values)


def project(model, delta, selected, reference):
    value = delta.copy()
    for iteration in range(11):
        residual = residual_vector(model, value, selected, reference)
        if np.max(np.abs(residual)) <= 1e-11:
            return value, iteration
        if iteration == 10:
            return None, iteration
        jacobian = S.derivative(lambda x: residual_vector(model, x, selected, reference), value)
        value += np.linalg.lstsq(jacobian*S.MAXIMUM, -residual, rcond=1e-12)[0]*S.MAXIMUM
    raise AssertionError('unreachable')


def direction(model, selected, heading, axis, sign):
    zero = np.zeros(14); contacts = model.contact_points(zero); floor = model.features_y(zero)
    jacobian = S.derivative(model.contact_points, zero)
    equality = S.derivative(lambda x: residual_vector(model, x, selected, contacts), zero)
    inequality = [-row for row in jacobian[:, 1, :]]
    rhs = [0.]*len(contacts)
    inequality.extend(-S.derivative(model.features_y, zero)); rhs.extend(floor-np.minimum(0., floor))
    for i in selected:
        if model.contacts[i]['body_id'] == 'torso':
            for transverse_sign in (-1., 1.):
                inequality.append(transverse_sign*jacobian[i, 2-axis]-sign*jacobian[i, axis]); rhs.append(0.)
    u = np.array(inequality); v = np.array(rhs); b = np.zeros(len(equality)); lo, hi = S.bounds(model.joints)
    cost = np.r_[-heading, np.zeros(11)]
    _, first = S.statics.lp(cost, equality, b, u, v, list(zip(lo, hi)))
    if first['primal_objective'] >= -S.PROGRESS:
        return None, dict(maximum_progress=first)
    # Among nearly maximal-progress solutions, avoid arbitrary motion in every
    # unconstrained limb by minimizing normalized absolute coordinate changes.
    identity = np.diag(1/S.MAXIMUM)
    secondary_u = np.vstack((np.c_[u, np.zeros((len(u), 14))], np.r_[cost, np.zeros(14)][None, :],
        np.c_[identity, -np.eye(14)], np.c_[-identity, -np.eye(14)]))
    secondary_v = np.r_[v, first['primal_objective']+1e-10, np.zeros(28)]
    chosen, second = S.statics.lp(np.r_[np.zeros(14), np.ones(14)], np.c_[equality, np.zeros((len(equality), 14))],
        b, secondary_u, secondary_v, list(zip(lo, hi))+[(0., None)]*14)
    return chosen[:14], dict(maximum_progress=first,minimum_normalized_absolute_motion=second)


def step(model, caps, selected, heading, axis, sign, original_contacts, original_floor):
    zero = np.zeros(14); initial = model.contact_points(zero); floor = model.features_y(zero)
    initial_load = load(model, zero, selected, caps, axis, sign)
    result = dict(initial_load=initial_load, selected=None, refusal=None, backtracks=[])
    if not initial_load['feasible']:
        result['refusal'] = 'sliding_force_balance_infeasible'; return result
    proposed, certificates = direction(model, selected, heading, axis, sign)
    result['direction_certificates'] = certificates
    if proposed is None:
        result['refusal'] = 'no_first_order_body_progress'; return result
    result['direction'] = proposed.tolist(); lo, hi = S.bounds(model.joints)
    sliding = [i for i in selected if model.contacts[i]['body_id'] == 'torso']
    assert sliding
    for exponent in range(11):
        scale = 2.**(-exponent); nodes = []; reason = None; previous_points = initial
        for fraction in (.25, .5, .75, 1.):
            delta, iterations = project(model, proposed*scale*fraction, selected, initial)
            if delta is None:
                reason = 'contact_projection_failed'; nodes.append(dict(fraction=fraction, reason=reason)); break
            points = model.contact_points(delta); increment = points-previous_points
            deficits = np.maximum(0., .02-S.LIMITS+np.abs(model.joints+delta[6:]))
            residuals = dict(bounds=max(float(np.max(lo-delta)), float(np.max(delta-hi))),
                mode=float(np.max(np.abs(residual_vector(model, delta, selected, initial)))),
                global_mode=float(np.max(np.abs(residual_vector(model, delta, selected, original_contacts)))),
                contact_descent=float(np.max(initial[:, 1]-points[:, 1])),
                global_contact_descent=float(np.max(original_contacts[:, 1]-points[:, 1])),
                floor=float(np.max(np.minimum(0., floor)-model.features_y(delta))),
                global_floor=float(np.max(np.minimum(0., original_floor)-model.features_y(delta))),
                headroom=float(np.max(deficits-np.maximum(0., .02-S.LIMITS+np.abs(model.joints)))),
                sector=max(float(sector_violation(increment[i], axis, sign)) for i in sliding))
            progress = float(delta[:3]@heading)
            node = dict(fraction=fraction,delta=delta.tolist(),projection_iterations=iterations,residuals=residuals,
                forward_progress_m=progress,foot_hull_gap_m=model.gap(delta))
            nodes.append(node)
            if any(v > S.GEOMETRY_TOL for v in residuals.values()):
                reason = 'nonlinear_geometry_or_sector_guard'; break
            if progress <= S.PROGRESS*fraction or any(sign*increment[i, axis] <= 1e-12 for i in sliding):
                reason = 'no_finite_body_or_slide_progress'; break
            node['load'] = load(model, delta, selected, caps, axis, sign)
            if not node['load']['feasible']:
                reason = 'proposed_sliding_force_balance_infeasible'; break
            dissipation = []
            for j, i in enumerate(selected):
                if i not in sliding:
                    continue
                force = np.array(node['load']['forces_world_n'][j])
                work = float(force[[0, 2]]@increment[i, [0, 2]])
                lower_bound = -MU*force[1]*float(np.max(np.abs(increment[i, [0, 2]])))
                error = abs(work-lower_bound)
                assert work <= 1e-9 and error <= 1e-9
                dissipation.append(dict(contact_index=i,displacement_work_j=work,minimum_diamond_work_j=lower_bound,error_j=error))
            node['maximum_dissipation_checks'] = dissipation
            previous_points = points
        attempt = dict(scale=scale,samples=nodes,refusal=reason); result['backtracks'].append(attempt)
        if reason is None:
            result['selected'] = attempt; return result
    result['refusal'] = 'all_finite_steps_refused'; return result


def controls():
    checked = S.controls(); count = 0
    assert sector(np.array([1., 0., .2])) == (0, 1.); count += 1
    assert sector(np.array([.2, 0., -1.])) == (2, -1.); count += 1
    assert sector_violation(np.array([2., 0., 1.]), 0, 1.) <= 0; count += 1
    assert sector_violation(np.array([1., 0., 2.]), 0, 1.) > 0; count += 1
    # A 10 N block with mu=.5 needs a 5 N drive to slide, with opposite drag.
    for sign in (-1., 1.):
        a = np.array([[1., 0., 0., 1.], [0., 1., 0., 0.], [0., 0., 1., 0.]])
        extra = force_mode_rows(4, [0], 0, sign, .5)
        system = np.vstack((a, extra)); rhs = np.r_[[0., 10., 0.], np.zeros(len(extra))]
        assert not S.statics.solve(system,rhs,[False],[4.],.5,10.)['feasible']; count += 1
        value = S.statics.solve(system,rhs,[False],[5.],.5,10.)
        assert value['feasible']; count += 1
        assert abs(value['forces_world_n'][0][0]+sign*5.) < 1e-9; count += 1
        assert value['forces_world_n'][0][0]*sign < 0.; count += 1
    checked['additional_sliding_sector_drive_threshold_and_drag_controls'] = count
    return checked


def derive():
    declaration = C.read(STUDY)
    for binding in [*declaration['dependencies'],declaration['population']['report']]:
        assert C.bind(binding['path']) == binding
    assert np.__version__ == declaration['numerics']['numpy'] and S.statics.scipy.__version__ == declaration['numerics']['scipy']
    checked = controls(); descriptor, samples = S.statics.tracking.rows(); entry = samples[0]
    assert entry['semantic_step'] == 513 and entry['partial_step'] == 1
    packet = next(r['packet'] for r in G.records(C.CHILD/'worker_report.json','r10af_contact_frames','records') if r['packet']['semantic_step'] == 513)
    replay = S.statics.replay.replay(packet,513,packet['model_instance_id'],packet['body_population_instance_sha256']); assert replay['ok']
    model = S.Model(packet,descriptor,entry['joint_positions_rad']); zero = np.zeros(14)
    caps = [v/G.DT for v in entry['caps']]; assert len(model.contacts) == 7
    heading = model.r['torso'][:,0].copy(); heading[1] = 0.; heading /= np.linalg.norm(heading)
    axis, sign = sector(heading); contacts = model.contact_points(zero); floor = model.features_y(zero)
    survey = []
    for mask, selected in enumerate(modes.subsets(7)):
        if not any(model.contacts[i]['body_id'] == 'torso' for i in selected):
            survey.append(dict(mask=mask,support_indices=selected,result=dict(selected=None,refusal='no_torso_sliding_contact'))); continue
        survey.append(dict(mask=mask,support_indices=selected,result=step(model,caps,selected,heading,axis,sign,contacts,floor)))
    admitted = [r for r in survey if r['result']['selected'] is not None]
    selected_mode = max(admitted,key=lambda r:(r['result']['selected']['samples'][-1]['forward_progress_m'],-r['mask'])) if admitted else None
    trajectory = []; stop = 'no_admitted_entry_slide'
    initial = path.snapshot(model)
    if selected_mode is not None:
        selected = selected_mode['support_indices']; stop = 'finite_model_horizon'
        for index in range(600):
            result = selected_mode['result'] if index == 0 else step(model,caps,selected,heading,axis,sign,contacts,floor)
            row = dict(model_step=index+1,before=path.snapshot(model),result=result); trajectory.append(row)
            if result['selected'] is None:
                stop = result['refusal']; break
            model = path.advance(model,np.array(result['selected']['samples'][-1]['delta']))
            row['after'] = path.snapshot(model)
            if row['after']['foot_hull_gap_m'] <= 1e-6:
                stop = 'all_cap_hull_gap_within_1um_model_only'; break
    final = path.snapshot(model)
    summary = dict(subsets_enumerated=128,entry_slides_admitted=len(admitted),
        entry_refusals=dict(Counter(r['result']['refusal'] for r in survey if r['result']['selected'] is None)),
        selected_model_mask=None if selected_mode is None else selected_mode['mask'],
        accepted_model_steps=sum(r['result']['selected'] is not None for r in trajectory),attempted_model_steps=len(trajectory),stop_reason=stop,
        initial_gap_m=initial['foot_hull_gap_m'],final_gap_m=final['foot_hull_gap_m'],
        torso_forward_translation_m=float((np.array(final['torso_position_m'])-initial['torso_position_m'])@heading))
    return dict(schema_version='sporespore_r10av_sliding_support_result_v1',ledger_scope=declaration['ledger_scope'],declaration=C.bind(STUDY),
        implementation=C.bind(__file__),controls=checked,entry_contact_replay=replay,heading=heading.tolist(),sector_axis=axis,sector_sign=sign,
        summary=summary,initial=initial,final=final,survey=survey,trajectory=trajectory,**declaration['claim_boundary'])


def audit():
    result = C.read(RESULT); assert result == derive()
    return dict(ok=True,controls=result['controls'],summary=result['summary'],world_build_count=0,solver_step_count=0,
        physical_acceptance_authority=False,release_authority=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('--create',action='store_true'); parser.add_argument('--controls',action='store_true')
    args = parser.parse_args()
    if args.controls:
        print(json.dumps(controls(),indent=2))
    else:
        if args.create:C.write_new(RESULT,derive())
        print(json.dumps(audit(),indent=2))
