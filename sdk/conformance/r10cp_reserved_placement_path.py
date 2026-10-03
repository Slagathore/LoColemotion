"""Fresh quadratic right-rear placement from the admitted R10BZ lift endpoint.

Fixed exposed contact modes; unchanged physical guards and bounded integration.
The R10CM secondary selector replaces only normalized L1 motion minimization.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import numpy as np
from scipy.integrate import solve_ivp
import r10cb_right_rear_placement as P
import r10cm_implied_conic_rows as F
import r10co_placement_field_diagnosis as O
L,C,S,G,Z,I,T=P.L,P.C,P.S,P.G,P.Z,P.I,P.T
M,H,Q,B=P.M,P.H,P.Q,P.B
STUDY=C.ROOT/'sdk/recovery/r10cp_reserved_placement_path_study_v1.json'
RESULT=C.ROOT/'sdk/recovery/r10cp_reserved_placement_path_result_v1.json'
MAX_STEPS=P.MAX_STEPS
VelocityRefusal=P.VelocityRefusal
floor_jacobian=P.floor_jacobian
placement_cost=P.placement_cost
placement_gradient=P.placement_gradient
certify_mode=P.certify_mode
reconstruct=P.reconstruct
controls=O.controls
PROGRESS_FRACTION=.95


def velocity(model,modes,heading):
    record=O.solve_problem(F.E.E.problem(model,modes,heading),PROGRESS_FRACTION)
    if not record['accepted']:raise VelocityRefusal(dict(stage='reserved_placement_motion',diagnostic=record))
    certificate=dict(record['quadratic_result']['certificate'],qp_status=record['quadratic_result']['status'],
        qp_status_rule='solved_or_almost_solved_with_full_original_certificate')
    return np.array(record['normalized_velocity'])*S.MAXIMUM,dict(maximum_progress=record['primary_certificate'],minimum_normalized_motion=certificate)


def qualified_case():
    return next(c for c in C.read(O.RESULT)['cases'] if c['geometry']=='original' and c['fraction']==PROGRESS_FRACTION)



def check_node(base, model, delta, modes, caps, heading, reference, fraction):
    # Reproduce original geometry/load/material-work admission without changing
    # its tolerances. Use this successor's motion selector explicitly, not mutation
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
    node = dict(fraction=fraction, delta=delta.tolist(), guards=guards, placement_cost_reduction_m2=placement_cost(base,np.zeros(14),heading)-placement_cost(model,zero,heading),
        foot_hull_gap_m=model.gap(zero), admitted=False, refusal=None)
    if not B.geometry_allowed(guards):node['refusal'] = 'integrated_geometry_guard'; return node
    if node['placement_cost_reduction_m2'] <= 1e-12*fraction:node['refusal'] = 'no_finite_rear_placement_progress'; return node
    node['floor_jacobian_comparison_error'] = float(np.max(np.abs(floor_jacobian(model)-S.derivative(model.features_y, zero))))
    if node['floor_jacobian_comparison_error'] > 1e-7:node['refusal'] = 'analytic_floor_jacobian_guard'; return node
    node['placement_gradient_comparison_error']=float(np.max(np.abs(placement_gradient(model,heading)-S.derivative(lambda q:placement_cost(model,q,heading),zero))))
    if node['placement_gradient_comparison_error']>1e-7:node['refusal']='placement_gradient_guard';return node
    node['load'] = Z.load(model, zero, modes, caps)
    if not node['load']['feasible']:node['refusal'] = 'sampled_stationary_force_refusal'; return node
    try:direction, certificate = velocity(model, modes, heading)
    except VelocityRefusal as error:node.update(refusal='sampled_motion_solver_refusal', velocity_refusal=error.record); return node
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
    calls = 0; max_certificate = 0.; probe = None; recoveries = []; statuses = {}
    def rhs(time, q):
        nonlocal calls, max_certificate, probe
        calls += 1; probe = dict(model_interval_fraction=float(time), delta=q.tolist())
        if calls > I.MAX_RHS:raise I.IntegrationRefusal('integrator_rhs_budget')
        model = I.advance(base, q)
        if np.any(np.abs(model.joints) > S.LIMITS):raise I.IntegrationRefusal('integrator_probe_outside_hard_joint_limits')
        direction, certificates = velocity(model, modes, heading)
        status=certificates['minimum_normalized_motion']['qp_status']
        statuses[status]=statuses.get(status,0)+1
        recoveries.extend(recovery_receipts(certificates,probe))
        for certificate in certificates.values():
            for name in ('primal_max_residual', 'stationarity_max_residual', 'dual_sign_violation', 'complementarity_max_residual', 'objective_gap'):
                max_certificate = max(max_certificate, certificate[name])
        derivative = direction.copy(); derivative[3:6] = np.linalg.solve(I.left_jacobian(q[3:6]), direction[3:6])
        return derivative
    result = dict(nodes=[], admitted=False, refusal=None, solver_recoveries=recoveries, quadratic_rhs_status_counts=statuses)
    try:solution = solve_ivp(rhs, (0., 1.), np.zeros(14), t_eval=B.FRACTIONS, **I.INTEGRATOR)
    except (I.IntegrationRefusal, VelocityRefusal) as error:
        result.update(refusal='integration_motion_solver_refusal' if isinstance(error, VelocityRefusal) else str(error),
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


def declare():
    prior=C.read(P.STUDY);qualified=C.read(F.RESULT)
    assert qualified['summary']['certified_problems']==61
    modes=C.read(P.RESULT)['summary']['selected_modes'];assert modes==[1,0,0,0,2,1,0]
    design=dict(prior['design'])
    design.update(modes='Freeze the exposed R10CB mode vector. Retain its original search as provenance only; no new search. Fresh independent coupled force/velocity LP entry verification remains unchanged, including its L1 tie-break, and does not choose the integration velocity.',
        velocity='Use the exact R10CM equality-coordinate quadratic selector with its explicit roundoff-redundant backend-row preprocessing at every RHS and sampled node: unchanged certified primary optimum,95% progress, minimum half squared normalized velocity, pinned Clarabel settings and one reduced solve per QP; Solved or AlmostSolved plus the full independent1e-6 original-matrix certificate, including every backend-omitted row with reconstructed zero dual. Preserve all refusal inputs and outputs. All separate physical guards remain unchanged.',
        retention='Fresh exclusive journal, every admitted or refused attempt, status counts for successfully certified RHS solves, full refused QP inputs and outputs, and complete result/journal cold replay.')
    population=dict(prior['population'],coverage='One fresh path from the69-increment admitted R10BZ lift endpoint; at most120 additional increments with four sampled nodes each. No native timing equivalence.')
    C.write_new(STUDY,dict(schema_version='sporespore_r10cp_reserved_placement_path_study_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='engine_neutral_model_from_godot_measurements',authority_mode='prospective_five_percent_reserved_right_rear_path',question_class='development'),
        source_parent_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=C.ROOT).decode().strip(),
        question='Does the qualified95% progress objective advance rear placement beyond the R10CN integration refusal with original geometry and unchanged physical guards and integration budget?',
        dependencies=C.read(O.STUDY)['dependencies']+[C.bind(p) for p in [O.__file__,O.STUDY,O.RESULT,__file__]],
        selected_modes=modes,population=population,design=design,
        numerics=dict(prior['numerics'],progress_fraction=PROGRESS_FRACTION,mode_search_performed=False,quadratic_selector=C.bind(O.STUDY)),
        checks=['228 inherited selector, certificate, mode and physical admission controls.','Exact inherited prefix, fresh fixed-mode entry certificate, full sampled admission and complete cold result/journal replay.'],
        research_sources=C.read(F.STUDY)['research_sources'],claim_boundary=prior['claim_boundary']))



def derive(journal=None):
    declaration=C.read(STUDY)
    for binding in [*declaration['dependencies'],declaration['population']['report']]:assert C.bind(binding['path'])==binding
    assert np.__version__==declaration['numerics']['numpy'] and S.statics.scipy.__version__==declaration['numerics']['scipy']
    qualified=qualified_case();assert qualified['summary']['certified_poses']==59
    checked=controls();model,previous,replay,caps=reconstruct();initial=T.snapshot(model);zero=np.zeros(14)
    heading=np.array(previous['initial']['torso_basis_columns'])[0].copy();heading[1]=0.;heading/=np.linalg.norm(heading)
    initial_deficits=H.deficits(model,zero,heading).tolist()
    gradient=placement_gradient(model,heading);error=float(np.max(np.abs(gradient-S.derivative(lambda q:placement_cost(model,q,heading),zero))))
    assert error<=1e-7
    eligible=Q.eligibility(previous['initial']['original_contact_markers_m'],initial['original_contact_markers_m'])
    rear=[i for i,p in enumerate(model.contacts) if p['body_id'].startswith('rear_right')]
    for i in rear:eligible[i]=False
    reference=Q.phase_reference(previous['initial'],initial)
    problem=Z.Problem(T.advance(model,zero),caps,np.zeros(3));problem.cost[:14]=gradient*S.MAXIMUM/.01;Q.restrict_modes(problem,eligible)
    search=copy.deepcopy(C.read(P.RESULT)['search']);verification=None;modes=None;stop='placement_mode_search_refusal';trajectory=[];accepted=0
    digest=hashlib.sha256();count=0
    def retain(value):
        nonlocal count
        line=L.journal_line(value);digest.update(line);count+=1
        if journal is not None:journal.write(line);journal.flush()
    retain(dict(kind='inputs',declaration=C.bind(STUDY),implementation=C.bind(__file__),eligible=eligible,rear_inactive=rear,
        phase_reference=reference,heading=heading.tolist(),gradient=gradient.tolist(),gradient_error=error,search=search))
    if search['proposal'] is not None:
        modes=search['proposal']['modes'];assert modes==declaration['selected_modes'];assert all(allow or mode==0 for allow,mode in zip(eligible,modes,strict=True))
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
                print(f'R10CP step{accepted}: deficits {H.deficits(model,zero,heading).tolist()}',file=sys.stderr,flush=True)
                if H.deficits(model,zero,heading)[1]<=1e-6:stop='right_rear_cap_placement_model_target';break
    final=T.snapshot(model);final_load=trajectory[accepted-1]['nodes'][-1]['load'] if accepted else (verification or {}).get('load',{})
    summary=dict(progress_fraction=PROGRESS_FRACTION,inherited_lift_increments=previous['summary']['accepted_model_steps'],accepted_additional_increments=accepted,attempted_additional_increments=len(trajectory),
        stop_reason=stop,selected_modes=modes,initial_rear_deficits_m=initial_deficits,
        final_rear_deficits_m=H.deficits(model,zero,heading).tolist(),final_gap_m=final['foot_hull_gap_m'],
        final_minimum_nonfoot_weight_fraction=final_load.get('minimum_nonfoot_weight_fraction'),
        total_integrator_rhs_calls=sum(row['rhs_calls'] for row in trajectory),integration_solver_recoveries=sum(len(row['solver_recoveries']) for row in trajectory),
        quadratic_rhs_status_counts={status:sum(row['quadratic_rhs_status_counts'].get(status,0) for row in trajectory) for status in F.F.STATUSES},
        placement_target='rear_right',placement_target_reached=stop=='right_rear_cap_placement_model_target',landing_proven=False,complete_transfer_or_rise_proven=False)
    retain(dict(kind='terminal_summary',value=summary))
    return dict(schema_version='sporespore_r10cp_reserved_placement_path_result_v1',ledger_scope=declaration['ledger_scope'],
        declaration=C.bind(STUDY),implementation=C.bind(__file__),controls=checked,entry_contact_replay=replay,
        initial=initial,final=final,phase_reference=reference,search=search,verification=verification,summary=summary,trajectory=trajectory,
        journal=dict(line_count=count,raw_sha256='sha256:'+digest.hexdigest()),**declaration['claim_boundary'])


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    for flag in ('declare','controls','create'):parser.add_argument('--'+flag,action='store_true')
    parser.add_argument('--journal');args=parser.parse_args()
    if args.declare:declare();print('R10CP prospective declaration created')
    elif args.controls:print(json.dumps(controls(),indent=2))
    elif args.create:
        if not args.journal:parser.error('--create requires fresh durable --journal')
        path=Path(args.journal).resolve();assert path.is_relative_to(C.EVIDENCE.resolve()) and not RESULT.exists()
        with path.open('xb') as journal:result=derive(journal)
        json.dumps(result,allow_nan=False)
        C.write_new(RESULT,result);print(json.dumps(L.present(result,False),indent=2))
    else:
        result=C.read(RESULT);assert result==derive();print(json.dumps(L.present(result,True),indent=2))

