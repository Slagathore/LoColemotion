"""Post-lift unloaded rear placement under a single eligible support mode.

This distinct preparatory phase changes its motion objective and contact mode.
It preserves global physical guards and does not acquire or load new contacts.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import numpy as np

import r10bm_entry_raise_directions as M
import r10bn_bounded_torso_raise_path as N
import r10by_certified_runtime_portfolio as W
import r10bz_portfolio_raise_path as X
import r10bg_supported_rear_placement as H
import r10bq_eligible_raise_reselection as Q
from scipy.integrate import solve_ivp

L, C, S, G, Z, I, T = M.L, M.C, M.S, M.G, M.Z, M.I, M.T
STUDY = C.ROOT/'sdk/recovery/r10ca_post_lift_rear_placement_study_v1.json'
RESULT = C.ROOT/'sdk/recovery/r10ca_post_lift_rear_placement_result_v1.json'
MAX_STEPS = 120
PROGRESS_FRACTION = .99
B = L.B
VelocityRefusal = L.VelocityRefusal
certified_lp = W.certified_lp
floor_jacobian = L.floor_jacobian


def secondary_problem(cost, optimum, a, u, v, bounds):
    bound = PROGRESS_FRACTION*optimum
    scale = max(float(np.max(np.abs(cost))), abs(bound), 1e-12)
    secondary_u = np.vstack((np.c_[u, np.zeros((len(u), 14))], np.r_[cost/scale, np.zeros(14)][None, :],
        np.c_[np.eye(14), -np.eye(14)], np.c_[-np.eye(14), -np.eye(14)]))
    secondary_v = np.r_[v, bound/scale, np.zeros(28)]
    return np.c_[a, np.zeros((len(a), 14))], secondary_u, secondary_v, bounds+[(0., None)]*14, scale


def velocity(model, modes, heading):
    zero = np.zeros(14); j = I.material_jacobian(model)
    floor = model.features_y(zero); fj = floor_jacobian(model)
    equality = []; inequality = list(-fj); rhs = list(floor-np.minimum(0., floor))
    for i, mode in enumerate(modes):
        inequality.append(-j[i, 1]); rhs.append(0.)
        if mode:
            equality.append(j[i, 1])
            if mode == 1:equality.extend((j[i, 0], j[i, 2]))
            else:
                axis, sign = Z.MODES[mode]
                for other in (-1., 1.):inequality.append(other*j[i, 2-axis]-sign*j[i, axis]); rhs.append(0.)
    a = np.array(equality).reshape((-1, 14)); u = np.array(inequality); v = np.array(rhs)
    lo, hi = S.bounds(model.joints); cost = placement_gradient(model,heading)
    a = a*S.MAXIMUM; u = u*S.MAXIMUM; cost = cost*S.MAXIMUM
    anorm = np.maximum(np.max(np.abs(a), axis=1), 1e-12); a /= anorm[:, None]
    unorm = np.maximum(np.max(np.abs(u), axis=1), 1e-12); u /= unorm[:, None]; v /= unorm
    bounds = list(zip(lo/S.MAXIMUM, hi/S.MAXIMUM))
    first_x, first = certified_lp('primary_placement_cost_reduction', cost, a, np.zeros(len(a)), u, v, bounds)
    second_a, second_u, second_v, second_bounds, scale = secondary_problem(cost, first['primal_objective'], a, u, v, bounds)
    witness = np.r_[first_x, np.abs(first_x)]
    witness_error = max(float(np.max(np.abs(second_a@witness))), float(np.max(second_u@witness-second_v)))
    try:
        result, second = certified_lp('secondary_normalized_motion', np.r_[np.zeros(14), np.ones(14)], second_a,
            np.zeros(len(a)), second_u, second_v, second_bounds)
    except VelocityRefusal as error:
        error.record.update(primary_solution=first_x.tolist(), primary_certificate=first,
            constructed_secondary_witness=witness.tolist(), constructed_witness_max_residual=witness_error,
            objective_row_scale=scale)
        raise
    return result[:14]*S.MAXIMUM, dict(maximum_progress=first, minimum_normalized_motion=second)


def check_node(base, model, delta, modes, caps, heading, reference, fraction):
    # Reproduce original geometry/load/material-work admission without changing
    # its tolerances. Use this successor's velocity LP explicitly, not mutation
    # of the imported historical module's globals.
    zero = np.zeros(14); points = model.contact_points(zero); original = np.array(reference['original_contact_markers_m'])
    residual = []
    for i, mode in enumerate(modes):
        if mode:
            residual.append(points[i, 1]-original[i, 1])
            if mode == 1 and not model.contacts[i]['classified_as_foot']:residual.extend(points[i, [0, 2]]-original[i, [0, 2]])
    lo, hi = S.bounds(base.joints); bounded = np.r_[0:3, 6:14]
    guards = dict(active_contact=float(np.max(np.abs(residual), initial=0.)),
        original_contact_descent=float(np.max(original[:, 1]-points[:, 1])),
        original_floor=float(np.max(np.minimum(0., reference['shape_bottom_witnesses_m'])-model.features_y(zero))),
        local_floor=float(np.max(np.minimum(0., base.features_y(zero))-model.features_y(zero))),
        translation_and_joint_bounds=max(float(np.max(fraction*lo[bounded]-delta[bounded])),float(np.max(delta[bounded]-fraction*hi[bounded]))),
        rotation_norm=float(np.linalg.norm(delta[3:6])-fraction*.6*G.DT),
        original_headroom=float(np.max(np.abs(model.joints)-np.maximum(S.LIMITS-.02, np.abs(reference['joints_rad'])))))
    node = dict(fraction=fraction, delta=delta.tolist(), guards=guards, placement_cost_reduction_m2=H.cost(base,np.zeros(14),heading)-H.cost(model,zero,heading),
        foot_hull_gap_m=model.gap(zero), admitted=False, refusal=None)
    if not B.geometry_allowed(guards):node['refusal'] = 'integrated_geometry_guard'; return node
    if node['placement_cost_reduction_m2'] <= 1e-12*fraction:node['refusal'] = 'no_finite_rear_placement_progress'; return node
    node['floor_jacobian_comparison_error'] = float(np.max(np.abs(floor_jacobian(model)-S.derivative(model.features_y, zero))))
    if node['floor_jacobian_comparison_error'] > 1e-7:node['refusal'] = 'analytic_floor_jacobian_guard'; return node
    node['placement_gradient_comparison_error']=float(np.max(np.abs(placement_gradient(model,heading)-S.derivative(lambda q:H.cost(model,q,heading),zero))))
    if node['placement_gradient_comparison_error']>1e-7:node['refusal']='placement_gradient_guard';return node
    node['load'] = Z.load(model, zero, modes, caps)
    if not node['load']['feasible']:node['refusal'] = 'sampled_stationary_force_refusal'; return node
    try:direction, certificate = velocity(model, modes, heading)
    except VelocityRefusal as error:node.update(refusal='sampled_velocity_lp_refusal', velocity_refusal=error.record); return node
    material = I.material_jacobian(model)@direction
    node['velocity'] = direction.tolist(); node['velocity_certificates'] = certificate; node['material_contact_motion_per_model_interval_m'] = material.tolist()
    forces = np.array(node['load']['forces_world_n']); checks = []
    for i, mode in enumerate(modes):
        work = float(forces[i]@material[i]); minimum = -Z.X.MU*forces[i, 1]*float(np.max(np.abs(material[i, [0, 2]]))) if mode >= 2 else 0.
        valid = np.max(np.abs(forces[i])) <= 1e-6 if mode == 0 else Z.work_allowed(work, minimum)
        if mode == 1:valid = valid and np.max(np.abs(material[i])) <= 1e-9
        if mode >= 2:
            axis, sign = Z.MODES[mode]; valid = valid and abs(material[i, 1]) <= 1e-9 and abs(material[i, 2-axis])-sign*material[i, axis] <= 1e-9
        checks.append(dict(contact=i, mode=mode, sampled_work_per_model_interval_j=work, minimum_diamond_work_j=minimum, ok=bool(valid)))
    node['sampled_material_dissipation'] = checks
    if not all(row['ok'] for row in checks):node['refusal'] = 'sampled_material_velocity_or_work_guard'; return node
    node['admitted'] = True
    return node


def recovery_receipts(certificates, probe):
    return [dict(probe=copy.deepcopy(probe),velocity_stage=stage,record=copy.deepcopy(certificate['retained_solver_recovery']))
        for stage,certificate in certificates.items() if 'retained_solver_recovery' in certificate]


def step(base, modes, caps, heading, reference):
    calls = 0; max_certificate = 0.; probe = None; recoveries = []
    def rhs(time, q):
        nonlocal calls, max_certificate, probe
        calls += 1; probe = dict(model_interval_fraction=float(time), delta=q.tolist())
        if calls > I.MAX_RHS:raise I.IntegrationRefusal('integrator_rhs_budget')
        model = I.advance(base, q)
        if np.any(np.abs(model.joints) > S.LIMITS):raise I.IntegrationRefusal('integrator_probe_outside_hard_joint_limits')
        direction, certificates = velocity(model, modes, heading)
        recoveries.extend(recovery_receipts(certificates,probe))
        for certificate in certificates.values():
            for name in ('primal_max_residual', 'stationarity_max_residual', 'dual_sign_violation', 'complementarity_max_residual', 'objective_gap'):
                max_certificate = max(max_certificate, certificate[name])
        derivative = direction.copy(); derivative[3:6] = np.linalg.solve(I.left_jacobian(q[3:6]), direction[3:6])
        return derivative
    result = dict(nodes=[], admitted=False, refusal=None, solver_recoveries=recoveries)
    try:solution = solve_ivp(rhs, (0., 1.), np.zeros(14), t_eval=B.FRACTIONS, **I.INTEGRATOR)
    except (I.IntegrationRefusal, VelocityRefusal) as error:
        result.update(refusal='integration_velocity_lp_refusal' if isinstance(error, VelocityRefusal) else str(error),
            rhs_calls=calls, maximum_velocity_certificate_residual=max_certificate, last_integration_probe=probe)
        if isinstance(error, VelocityRefusal):result['velocity_refusal'] = error.record
        return result
    result.update(rhs_calls=calls, maximum_velocity_certificate_residual=max_certificate,
        integrator=dict(success=bool(solution.success), status=int(solution.status), message=solution.message, nfev=int(solution.nfev)))
    if not solution.success or len(solution.t) != len(B.FRACTIONS):result['refusal'] = 'integrator_unsuccessful'; return result
    for fraction, delta in zip(B.FRACTIONS, solution.y.T, strict=True):
        node = check_node(base, I.advance(base, delta), delta, modes, caps, heading, reference, fraction); result['nodes'].append(node)
        if not node['admitted']:result['refusal'] = node['refusal']; return result
    result['admitted'] = True
    return result











def placement_gradient(model,heading):
    zero=np.zeros(14);poses=model.poses(zero)
    _,jacobian,_,_,_=S.statics.frame(model.packet,model.d,model.com(poses))
    com_j=sum(state['mass_kg']*jacobian(state['body_id'],model.point(poses,state['body_id'],model.local_com[state['body_id']]))
        for state in model.states)/model.mass
    foot_jacs=[jacobian(foot+'_distal',model.point(poses,foot+'_distal',model.local_caps[foot])) for foot in H.REAR]
    return combine_placement_gradient(H.deficits(model,zero,heading),foot_jacs,com_j,heading)


def certify_mode(problem,modes):
    a,b,_=Z.assembly(problem.model,np.zeros(14))
    eq=np.c_[np.zeros((14,14)),a]*problem.scale
    scale=np.maximum(1.,np.abs(b));eq/=scale[:,None];rhs=b/scale
    active=np.all(problem.ub[:,problem.base:]==0.,axis=1)
    u=list(problem.ub[active,:problem.base]);v=list(problem.limit[active])
    for i,mode in enumerate(modes):
        for row,bound in problem.mode_rows[(i,mode)]:
            norm=max(float(np.max(np.abs(row))),abs(bound),1e-12)
            u.append(row/norm);v.append(bound/norm)
    u=np.array(u);v=np.array(v);bounds=list(zip(problem.lower[:problem.base],problem.upper[:problem.base]))
    first_x,first=certified_lp('fixed_mode_placement_objective',problem.cost[:problem.base],eq,rhs,u,v,bounds)
    if first['primal_objective']>=0.:return None,dict(maximum_placement=first)
    identity=np.c_[np.eye(14),np.zeros((14,problem.base-14))]
    second_u=np.vstack((np.c_[u,np.zeros((len(u),14))],np.r_[problem.cost[:problem.base],np.zeros(14)][None,:],
        np.c_[identity,-np.eye(14)],np.c_[-identity,-np.eye(14)]))
    second_v=np.r_[v,.99*first['primal_objective'],np.zeros(28)]
    try:
        x,second=certified_lp('fixed_mode_placement_minimum_motion',np.r_[np.zeros(problem.base),np.ones(14)],
            np.c_[eq,np.zeros((len(eq),14))],rhs,second_u,second_v,bounds+[(0.,None)]*14)
    except VelocityRefusal as failure:
        failure.record.update(primary_solution=first_x.tolist(),primary_certificate=first);raise
    return x[:problem.base]*problem.scale,dict(maximum_placement=first,minimum_normalized_motion=second)


def combine_placement_gradient(deficits,foot_jacs,com_j,heading):
    return sum(2.*deficit*(heading@(foot_jac-com_j)) for deficit,foot_jac in zip(deficits,foot_jacs,strict=True))


def controls():
    checked=X.controls();extra=Q.controls()
    key='additional_height_eligibility_binary_force_exclusion_and_global_reference_controls'
    checked[key]=extra[key]
    shared=np.c_[np.eye(3),np.zeros((3,11))];front=shared.copy();front[0,6]=2.
    gradient=combine_placement_gradient([.2,0.],[front,shared],shared,np.array([1.,0.,0.]))
    assert abs(gradient[6]-.8)<1e-12 and np.all(gradient[:3]==0.)
    fd=S.derivative(lambda q:float(np.maximum(0.,.2+2*q[6])**2),np.zeros(14))
    assert np.max(np.abs(gradient-fd))<1e-10
    assert H.cost.__name__=='cost' and H.MARGIN==.02
    checked['additional_relative_placement_gradient_translation_and_objective_controls']=3
    return checked


def reconstruct():
    retained=C.read(X.RESULT);descriptor,samples=S.statics.tracking.rows();entry=samples[0]
    packet=next(r['packet'] for r in G.records(C.CHILD/'worker_report.json','r10af_contact_frames','records') if r['packet']['semantic_step']==513)
    replay=S.statics.replay.replay(packet,513,packet['model_instance_id'],packet['body_population_instance_sha256']);assert replay['ok']
    packet=copy.deepcopy(packet);packet['counterfactual_model_only']=True
    model=I.CapModel(packet,descriptor,entry['joint_positions_rad']);assert T.snapshot(model)==retained['initial']
    accepted=0
    for row in retained['trajectory']:
        assert T.snapshot(model)==row['before']
        if not row['admitted']:break
        model=I.advance(model,np.array(row['nodes'][-1]['delta']));accepted+=1
        assert T.snapshot(model)==row['after']
    assert accepted==retained['summary']['accepted_model_steps'] and accepted>0
    assert T.snapshot(model)==retained['final']
    return model,retained,replay,[v/G.DT for v in entry['caps']]


def search_mode(problem):
    result=Z.milp(problem.cost,integrality=np.r_[np.zeros(problem.base),np.ones(problem.columns-problem.base)],
        bounds=Z.Bounds(problem.lower,problem.upper),constraints=[Z.LinearConstraint(problem.eq,problem.rhs,problem.rhs),
        Z.LinearConstraint(problem.ub,np.full(len(problem.ub),-np.inf),problem.limit)],options=Z.OPTIONS)
    record=dict(status=int(result.status),message=result.message,success=bool(result.success),
        raw_scaled_solution=None if result.x is None else result.x.tolist(),proposal=None)
    if not result.success or result.x is None:return record
    x=result.x;residual=max(float(np.max(np.abs(problem.eq@x-problem.rhs))),float(np.max(problem.ub@x-problem.limit)),
        float(np.max(problem.lower-x)),float(np.max(x-problem.upper)))
    binary=x[problem.base:];integer_error=float(np.max(np.abs(binary-np.round(binary))))
    record.update(maximum_scaled_primal_residual=residual,maximum_integrality_error=integer_error)
    if residual>1e-6 or integer_error>1e-6:return record
    record['proposal']=dict(modes=np.argmax(binary.reshape((problem.n,6)),axis=1).tolist(),recomputed_objective=float(problem.cost@x))
    return record


def declare():
    prior=C.read(X.STUDY);retained=C.read(X.RESULT)
    assert retained['summary']['accepted_model_steps']>0
    C.write_new(STUDY,dict(schema_version='sporespore_r10ca_post_lift_rear_placement_study_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='engine_neutral_model_from_godot_measurements',
            authority_mode='prospective_post_lift_unloaded_rear_placement_phase',question_class='development'),
        source_parent_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=C.ROOT).decode().strip(),
        question='Can the last admitted R10BZ lift pose support unloaded rear-foot placement behind COM under one eligible contact mode?',
        dependencies=prior['dependencies']+[C.bind(p) for p in [X.__file__,X.STUDY,X.RESULT,H.__file__,H.STUDY,H.RESULT,Q.__file__,Q.STUDY,Q.RESULT,__file__]],
        population=dict(prior['population'],inherited_model_increments=retained['summary']['accepted_model_steps']),
        design=dict(start='Replay only admitted saved R10BZ deltas from the original measured entry, checking every snapshot. Never propagate its refused probe or rerun its integrator.',
            objective='R10BG squared positive rear-cap forward deficits relative to COM with20 mm rearward placement margin and original-entry horizontal heading. Analytic gradient includes COM motion and both foot-center motions, compared with finite differences at entry and every admitted node.',
            modes='One original bounded six-mode search minimizing the instantaneous placement gradient. Only sites within1e-9 m of original contact height may carry force; all rear-body sites are forced inactive regardless of height. No new contact acquisition. Independently certify selected mode with the declared two-backend portfolio,99% primary progress and minimum normalized L1 motion.',
            anchors='New nonfoot sticking horizontal anchors use phase-entry positions. Original entry contact heights,24 floor witnesses and joint headroom stay global. Keep nonnegative normal material velocity at all original contacts, including inactive feet; this is placement with optional lift, not landing.',
            path='At most120 additional model increments. Fixed selected modes; recompute placement gradient each RHS. Same DOP853,2048 RHS limit, speed/rotation bounds, force/actuator/friction/material-work and1e-9 geometry limits. Objective-specific finite progress is the existing R10BG cost reduction>1e-12*fraction m2. Stop at first refusal or both rear deficits<=1e-6 m.',
            retention='Fresh exclusive journal of mode search, verification, every attempted increment and terminal summary. Retain every recovered or exhausted solver attempt, including integration probes. Complete cold replay.',
            boundary='A preparatory rear-placement model phase, not landing, dynamic transition, full unloading, standing, motor realization or native recovery. All original and new negative evidence remains immutable.'),
        numerics=dict(prior['numerics'],maximum_additional_steps=MAX_STEPS,mode_search_options=Z.OPTIONS,placement_gradient_tolerance=1e-7,placement_cost_progress_m2=1e-12),
        checks=['171 inherited plus4 phase eligibility/reference controls and3 relative-placement gradient checks;178 with shared coverage.',
            'Exact inherited prefix, selected-mode independent force/work verification, analytic-vs-FD gradient and full sampled admission.',
            'Full result and incremental journal cold replay.'],research_sources=prior['research_sources'],claim_boundary=prior['claim_boundary']))


def derive(journal=None):
    declaration=C.read(STUDY)
    for binding in [*declaration['dependencies'],declaration['population']['report']]:assert C.bind(binding['path'])==binding
    assert np.__version__==declaration['numerics']['numpy'] and S.statics.scipy.__version__==declaration['numerics']['scipy']
    checked=controls();model,previous,replay,caps=reconstruct();initial=T.snapshot(model);zero=np.zeros(14)
    heading=np.array(previous['initial']['torso_basis_columns'])[0].copy();heading[1]=0.;heading/=np.linalg.norm(heading)
    initial_deficits=H.deficits(model,zero,heading).tolist()
    gradient=placement_gradient(model,heading);error=float(np.max(np.abs(gradient-S.derivative(lambda q:H.cost(model,q,heading),zero))))
    assert error<=1e-7
    eligible=Q.eligibility(previous['initial']['original_contact_markers_m'],initial['original_contact_markers_m'])
    rear=[i for i,p in enumerate(model.contacts) if p['body_id'].startswith(H.REAR)]
    for i in rear:eligible[i]=False
    reference=Q.phase_reference(previous['initial'],initial)
    problem=Z.Problem(T.advance(model,zero),caps,np.zeros(3));problem.cost[:14]=gradient*S.MAXIMUM/.01;Q.restrict_modes(problem,eligible)
    search=search_mode(problem);verification=None;modes=None;stop='placement_mode_search_refusal';trajectory=[];accepted=0
    digest=hashlib.sha256();count=0
    def retain(value):
        nonlocal count
        line=L.journal_line(value);digest.update(line);count+=1
        if journal is not None:journal.write(line);journal.flush()
    retain(dict(kind='inputs',declaration=C.bind(STUDY),implementation=C.bind(__file__),eligible=eligible,rear_inactive=rear,
        phase_reference=reference,heading=heading.tolist(),gradient=gradient.tolist(),gradient_error=error,search=search))
    if search['proposal'] is not None:
        modes=search['proposal']['modes'];assert all(allow or mode==0 for allow,mode in zip(eligible,modes,strict=True))
        allowed=False
        try:
            solution,certificates=certify_mode(problem,modes)
            if solution is None:verification=dict(certificates=certificates);stop='no_instantaneous_placement_progress'
            else:
                mismatch=abs(certificates['maximum_placement']['primal_objective']-search['proposal']['recomputed_objective'])
                checks=M.direction_check(model,caps,modes,solution);load=Z.load(model,zero,modes,caps)
                verification=dict(physical_solution=solution.tolist(),certificates=certificates,search_objective_difference=mismatch,instantaneous_checks=checks,load=load)
                allowed=mismatch<=1e-6 and checks['admitted'] and load['feasible'];stop='placement_entry_independent_refusal'
        except VelocityRefusal as failure:verification=dict(refusal=failure.record);stop='placement_entry_lp_refusal'
        retain(dict(kind='entry_verification',value=verification))
        if allowed:
            stop='bounded_placement_phase_horizon'
            for index in range(MAX_STEPS):
                row=step(model,modes,caps,heading,reference);row['additional_model_step']=index+1;row['before']=T.snapshot(model);trajectory.append(row)
                if not row['admitted']:stop=row['refusal'];retain(dict(kind='model_step',value=row));break
                accepted+=1;model=I.advance(model,np.array(row['nodes'][-1]['delta']));row['after']=T.snapshot(model)
                retain(dict(kind='model_step',value=row))
                print(f'R10CA step{accepted}: deficits {H.deficits(model,zero,heading).tolist()}',file=sys.stderr,flush=True)
                if np.max(H.deficits(model,zero,heading))<=1e-6:stop='rear_cap_placement_model_target';break
    final=T.snapshot(model);final_load=trajectory[accepted-1]['nodes'][-1]['load'] if accepted else (verification or {}).get('load',{})
    summary=dict(inherited_lift_increments=previous['summary']['accepted_model_steps'],accepted_additional_increments=accepted,attempted_additional_increments=len(trajectory),
        stop_reason=stop,selected_modes=modes,initial_rear_deficits_m=initial_deficits,
        final_rear_deficits_m=H.deficits(model,zero,heading).tolist(),final_gap_m=final['foot_hull_gap_m'],
        final_minimum_nonfoot_weight_fraction=final_load.get('minimum_nonfoot_weight_fraction'),
        total_integrator_rhs_calls=sum(row['rhs_calls'] for row in trajectory),integration_solver_recoveries=sum(len(row['solver_recoveries']) for row in trajectory),
        placement_target_reached=stop=='rear_cap_placement_model_target',landing_proven=False,complete_transfer_or_rise_proven=False)
    retain(dict(kind='terminal_summary',value=summary))
    return dict(schema_version='sporespore_r10ca_post_lift_rear_placement_result_v1',ledger_scope=declaration['ledger_scope'],
        declaration=C.bind(STUDY),implementation=C.bind(__file__),controls=checked,entry_contact_replay=replay,
        initial=initial,final=final,phase_reference=reference,search=search,verification=verification,summary=summary,trajectory=trajectory,
        journal=dict(line_count=count,raw_sha256='sha256:'+digest.hexdigest()),**declaration['claim_boundary'])


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    for flag in ('declare','controls','create'):parser.add_argument('--'+flag,action='store_true')
    parser.add_argument('--journal');args=parser.parse_args()
    if args.declare:declare();print('R10CA prospective declaration created')
    elif args.controls:print(json.dumps(controls(),indent=2))
    elif args.create:
        if not args.journal:parser.error('--create requires fresh durable --journal')
        path=Path(args.journal).resolve();assert path.is_relative_to(C.EVIDENCE.resolve()) and not RESULT.exists()
        with path.open('xb') as journal:result=derive(journal)
        C.write_new(RESULT,result);print(json.dumps(L.present(result,False),indent=2))
    else:
        result=C.read(RESULT);assert result==derive();print(json.dumps(L.present(result,True),indent=2))
