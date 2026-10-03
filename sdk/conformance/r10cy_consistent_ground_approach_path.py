"""Bounded unloaded right-rear ground approach after horizontal placement.

Only the target foot may descend. It carries zero force throughout; the near-
 ground target does not acquire a contact or establish landing/support transfer.
"""
import argparse
import copy
import gzip
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import uuid
import zlib
import numpy as np
from scipy.integrate import solve_ivp
import r10cr_landing_direction as R
import r10cr_landing_direction_audit as A
import r10cx_consistent_polish_field as V
import r10cw_polished_ground_approach_path as PREVIOUS
P=R.P
C,S,I,T,L,Z,H=R.C,R.S,R.I,R.T,R.L,R.Z,R.H
B,G=P.B,P.G
VelocityRefusal=P.VelocityRefusal
floor_jacobian=P.floor_jacobian
STUDY=C.ROOT/'sdk/recovery/r10cy_consistent_ground_approach_path_study_v1.json'
RESULT=C.ROOT/'sdk/recovery/r10cy_consistent_ground_approach_path_result_v1.json'
MAX_STEPS=120
TARGET_HEIGHT=1e-6
VARIANT='right_rear_only'


def solve_problem(p,fraction):
    cost,a,b,u,v=[np.array(p[key]) for key in ('cost','equality','equality_rhs','inequality','inequality_rhs')]
    bounds=p['bounds'];record=dict(fraction=fraction,accepted=False,primary_certificate=None,quadratic_problem=None,quadratic_result=None,refusal=None)
    try:first_x,first=V.E.W.certified_lp('primary_placement_cost_reduction',cost,a,b,u,v,bounds)
    except L.VelocityRefusal as failure:record['refusal']=failure.record;return record
    bound=fraction*first['primal_objective'];scale=max(float(np.max(np.abs(cost))),abs(bound),1e-12)
    u2=np.vstack((u,cost/scale));v2=np.r_[v,bound/scale]
    record.update(primary_solution=first_x.tolist(),primary_certificate=first,
        quadratic_problem=dict(equality=a.tolist(),equality_rhs=b.tolist(),inequality=u2.tolist(),inequality_rhs=v2.tolist(),bounds=bounds,start=first_x.tolist()))
    answer=V.solve_qp(a,b,u2,v2,bounds,first_x);record['quadratic_result']=answer
    if answer['accepted']:
        x=np.array(answer['solution']);record.update(accepted=True,normalized_velocity=x.tolist(),
            achieved_progress_fraction=None if first['primal_objective']==0. else float(cost@x)/first['primal_objective'])
    return record


def velocity(model,modes,heading):
    problem,released=R.problem(model,modes,heading,VARIANT)
    record=solve_problem(problem,.95)
    if not record['accepted']:raise VelocityRefusal(dict(stage='unloaded_right_rear_descent',diagnostic=record))
    certificate=dict(record['quadratic_result']['certificate'],qp_status=record['quadratic_result']['status'],
        qp_status_rule='consistent_active_face_polish_with_full_original_certificate')
    if 'consistent_face_polish' in record['quadratic_result']:
        certificate['retained_solver_recovery']=dict(stage='secondary_ground_approach_qp',problem=record['quadratic_problem'],selected=record['quadratic_result'])
    return np.array(record['normalized_velocity'])*S.MAXIMUM,dict(maximum_progress=record['primary_certificate'],minimum_normalized_motion=certificate)


def compressed_recoveries(records):
    nonfinite=[];safe=P.F.J.safe_record(records,nonfinite=nonfinite)
    raw=json.dumps(dict(records=safe,nonfinite_diagnostics=nonfinite),separators=(',',':'),sort_keys=True,allow_nan=False).encode('utf-8')
    return raw,gzip.compress(raw,compresslevel=6,mtime=0)


def retain_recoveries(row,root,write):
    records=row.pop('solver_records');row['solver_record_count']=len(records);row['solver_record_artifact']=None
    if not records:return
    raw,compressed=compressed_recoveries(records);digest=hashlib.sha256(raw).hexdigest();path=root/(digest+'.json.gz')
    assert path.resolve().is_relative_to(root.resolve()) and root.resolve().is_relative_to(C.EVIDENCE.resolve())
    if write and not path.exists():
        with path.open('xb') as stream:stream.write(compressed)
    assert path.read_bytes()==compressed and gzip.decompress(path.read_bytes())==raw
    row['solver_record_artifact']=dict(binding=C.bind(path),canonical_raw_sha256='sha256:'+digest,canonical_byte_length=len(raw),record_count=len(records),codec='gzip_level6_mtime0_canonical_json')


def controls():
    checked=V.controls()
    value=dict(primary=dict(retained_solver_recovery=dict(marker='original_failed_attempt')),secondary=dict())
    probe=dict(fraction=.5,delta=[1.,2.]);retained=recovery_receipts(value,probe)
    assert len(retained)==1 and retained[0]['record']==value['primary']['retained_solver_recovery']
    probe['delta'][0]=9.;value['primary']['retained_solver_recovery']['marker']='changed'
    assert retained[0]['probe']['delta']==[1.,2.] and retained[0]['record']['marker']=='original_failed_attempt'
    checked['additional_complete_recovery_receipt_and_deep_copy_controls']=2
    return checked


def check_node(base, model, delta, modes, caps, heading, reference, fraction):
    # Reproduce original geometry/load/material-work admission without changing
    # its tolerances. Use this successor's motion selector explicitly, not mutation
    # of the imported historical module's globals.
    zero = np.zeros(14); target=R.target_index(model); retained=[i for i in range(len(modes)) if i!=target]; points = model.contact_points(zero); original = np.array(reference['original_contact_markers_m'])
    residual = []
    for i, mode in enumerate(modes):
        if mode:
            residual.append(points[i, 1]-original[i, 1])
            if mode == 1 and not model.contacts[i]['classified_as_foot']:residual.extend(points[i, [0, 2]]-original[i, [0, 2]])
    lo, hi = S.bounds(base.joints); bounded = np.r_[0:3, 6:14]
    guards = dict(active_contact=float(np.max(np.abs(residual), initial=0.)),
        original_contact_descent=float(np.max(original[retained, 1]-points[retained, 1])),
        original_floor=float(np.max(np.minimum(0., reference['shape_bottom_witnesses_m'])-model.features_y(zero))),
        local_floor=float(np.max(np.minimum(0., base.features_y(zero))-model.features_y(zero))),
        translation_and_joint_bounds=max(float(np.max(fraction*lo[bounded]-delta[bounded])),float(np.max(delta[bounded]-fraction*hi[bounded]))),
        rotation_norm=float(np.linalg.norm(delta[3:6])-fraction*.6*G.DT),
        original_headroom=float(np.max(np.abs(model.joints)-np.maximum(S.LIMITS-.02, np.abs(reference['joints_rad'])))))
    node = dict(fraction=fraction, delta=delta.tolist(), guards=guards, right_rear_height_m=float(points[target,1]),signed_placement_m=R.signed_placement(model,zero,heading),
        descent_m=float(base.contact_points(zero)[target,1]-points[target,1]),
        foot_hull_gap_m=model.gap(zero), admitted=False, refusal=None)
    if not B.geometry_allowed(guards):node['refusal'] = 'integrated_geometry_guard'; return node
    if node['right_rear_height_m'] < -1e-9:node['refusal']='right_rear_cap_floor_guard';return node
    if node['signed_placement_m'] > 1e-9:node['refusal']='horizontal_placement_guard';return node
    if node['descent_m'] <= 1e-12*fraction:node['refusal']='no_finite_descent_progress';return node
    node['floor_jacobian_comparison_error'] = float(np.max(np.abs(floor_jacobian(model)-S.derivative(model.features_y, zero))))
    if node['floor_jacobian_comparison_error'] > 1e-7:node['refusal'] = 'analytic_floor_jacobian_guard'; return node
    node['placement_gradient_comparison_error']=float(np.max(np.abs(R.signed_placement_gradient(model,heading)-S.derivative(lambda q:R.signed_placement(model,q,heading),zero))))
    if node['placement_gradient_comparison_error']>1e-7:node['refusal']='placement_gradient_guard';return node
    node['height_gradient_comparison_error']=float(np.max(np.abs(I.material_jacobian(model)[target,1]-S.derivative(lambda q:model.contact_points(q)[target,1],zero))))
    if node['height_gradient_comparison_error']>1e-7:node['refusal']='height_gradient_guard';return node
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
    result = dict(nodes=[], admitted=False, refusal=None, solver_records=recoveries, quadratic_rhs_status_counts=statuses)
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
    prior=C.read(V.STUDY);audit=C.read(A.AUDIT)
    qualification=C.read(V.RESULT);assert qualification['summary']['consistent_regression_certified']==65 and qualification['summary']['consistent_field_certified']==57
    assert audit['full_replay_passed'] and not audit['original_cli_success']
    case=next(row for row in C.read(R.RESULT)['cases'] if row['variant']==VARIANT);assert case['supported_positive_descent']
    # This Windows Python embeds zlib in python311.dll rather than a .pyd.
    codec_binary=getattr(zlib,'__file__',str(Path(sys.base_prefix)/'python311.dll'))
    dependencies=prior['dependencies']+C.read(V.V.STUDY)['dependencies']+[C.bind(p) for p in [R.__file__,R.STUDY,R.RESULT,A.__file__,A.AUDIT,gzip.__file__,sys.executable,codec_binary,V.__file__,V.STUDY,V.RESULT,PREVIOUS.__file__,PREVIOUS.STUDY,PREVIOUS.RESULT,__file__]]
    diagnostics=C.EVIDENCE/('r10cy-solver-diagnostics-'+uuid.uuid4().hex);diagnostics.mkdir()
    C.write_new(STUDY,dict(schema_version='sporespore_r10cy_consistent_ground_approach_path_study_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='engine_neutral_model_from_godot_measurements',authority_mode='prospective_consistently_polished_unloaded_right_rear_ground_approach',question_class='development'),
        source_parent_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=C.ROOT).decode().strip(),
        question='Can a fixed-mode unloaded right-rear descent reach a near-ground approach while preserving horizontal placement and all other physical guards?',
        dependencies=dependencies,
        population=dict(prior['population'],coverage='One fresh bounded path from the admitted69-lift plus24-placement endpoint. At most120 additional model increments with four sampled nodes each.'),
        variant=VARIANT,diagnostic_artifact_root=diagnostics.as_posix(),
        design=dict(start='Exactly reconstruct the completed R10CQ endpoint; no old integrator rerun or refused probe propagation. Require the independent R10CR full numerical replay; its original CLI presentation failure remains unchanged.',
            solver='R10CX consistent active-face correction on every eligible original QP seed, independently qualified on65 regression problems and57 nearby poses. Keep complete original certificates, original objective and physical limits. Explicit consistent-polish status and full original/dual/candidate receipts at EVERY evaluated probe, including already successful original seeds.',
            prefix='Fresh execution from the completed R10CQ endpoint. R10CX changes the selector consistently at every probe, so no historical increment identity is assumed. No old failed probe is propagated.',
            motion='R10CR right-rear-only direction selector: minimize cap height rate, retain95% progress in minimum squared normalized motion. Keep original modes with zero target-foot force. All other normal restrictions and every shape-floor/rate/headroom constraint remain.',
            finite_guards='Keep global original floor/headroom references and existing active-contact/force/friction/material-work checks. Release only the target original-marker non-descent check. Explicit cap-above-floor and signed horizontal placement <=1e-9 guards; descent must exceed1e-12*fraction m. Check analytic height/placement/floor Jacobians against finite differences.',
            integration='Unchanged DOP853 tolerances/max step and2048 RHS limit per increment. Four original sample fractions; stop on first refusal, near-ground target or120 increments.',
            target='Cap height <=1e-6 m is a near-ground approach only. No support-mode transition or new contact is acquired. Landing/contact/support still require a separate declared verification and native evidence.',
            retention='Complete fresh journal and full cold replay. Preserve every complete selected QP record and any primary-solver recovery losslessly in per-increment gzip artifacts with canonical JSON hashes, raw byte lengths and record counts. All records are freshly recomputed and byte-checked during replay; no numerical solution is cached.',
            telemetry_measurement='Prior R10CQ complete result is44034565 bytes and includes1937 integration recovery records. Those records occupy13670654 canonical JSON bytes and2986523 bytes with gzip level6/mtime0. Compression preserves complete records and solver inputs; official/native capture is unchanged.',
            boundary='Counterfactual finite model approach, not landing, support acquisition, native actuation, standing, recovery or release.'),
        numerics=dict(prior['numerics'],maximum_steps=MAX_STEPS,target_cap_height_m=TARGET_HEIGHT,gzip_level=6,gzip_mtime=0,zlib_runtime_version=zlib.ZLIB_RUNTIME_VERSION),
        checks=['259 inherited plus2 full record retention and deep-copy controls;261 with shared coverage.','Exact endpoint, sampled full admission, source bindings and complete result/journal/artifact cold replay.'],
        research_sources=prior['research_sources'],claim_boundary=prior['claim_boundary']))


def derive(journal=None):
    declaration=C.read(STUDY)
    for binding in declaration['dependencies']:assert C.bind(binding['path'])==binding
    assert zlib.ZLIB_RUNTIME_VERSION==declaration['numerics']['zlib_runtime_version']
    assert np.__version__==declaration['numerics']['numpy'] and S.statics.scipy.__version__==declaration['numerics']['scipy']
    checked=controls();model,previous,replay,caps,heading=R.reconstruct();modes=previous['summary']['selected_modes'];zero=np.zeros(14);target=R.target_index(model)
    assert modes[target]==0
    initial=T.snapshot(model);reference=P.Q.phase_reference(previous['phase_reference'],initial);root=Path(declaration['diagnostic_artifact_root'])
    initial_height=float(model.contact_points(zero)[target,1]);entry=solve_problem(R.problem(model,modes,heading,VARIANT)[0],.95)
    direction=np.array(entry['normalized_velocity'])*S.MAXIMUM if entry['accepted'] else np.zeros(14)
    verification=R.direction_check(model,modes,caps,direction)
    qualified=next(row for row in C.read(V.RESULT)['regression'] if row['name']=='R10CR_right_rear_only')
    assert entry['accepted'] and entry['quadratic_result']==qualified['consistent'] and verification['admitted']
    digest=hashlib.sha256();count=0;trajectory=[];accepted=0;stop='entry_refusal'
    def retain(value):
        nonlocal count
        line=L.journal_line(value);digest.update(line);count+=1
        if journal is not None:journal.write(line);journal.flush()
    retain(dict(kind='inputs',declaration=C.bind(STUDY),implementation=C.bind(__file__),reference=reference,heading=heading.tolist(),selected_modes=modes,target=target))
    retain(dict(kind='entry_verification',velocity=entry,physical=verification))
    if entry['accepted'] and verification['admitted']:
        stop='bounded_ground_approach_horizon'
        for index in range(MAX_STEPS):
            row=step(model,modes,caps,heading,reference);row['additional_model_step']=index+1;row['before']=T.snapshot(model)
            retain_recoveries(row,root,journal is not None);trajectory.append(row)
            if not row['admitted']:stop=row['refusal'];retain(dict(kind='model_step',value=row));break
            accepted+=1;model=I.advance(model,np.array(row['nodes'][-1]['delta']));row['after']=T.snapshot(model)
            retain(dict(kind='model_step',value=row))
            height=float(model.contact_points(zero)[target,1]);print(f'R10CY step{accepted}: cap height {height:.12g} m',file=sys.stderr,flush=True)
            if height<=TARGET_HEIGHT:stop='right_rear_near_ground_model_target';break
    final=T.snapshot(model);final_load=trajectory[accepted-1]['nodes'][-1]['load'] if accepted else verification['load']
    summary=dict(inherited_lift_increments=69,inherited_placement_increments=24,accepted_additional_increments=accepted,attempted_additional_increments=len(trajectory),stop_reason=stop,
        initial_cap_height_m=initial_height,final_cap_height_m=float(model.contact_points(zero)[target,1]),final_signed_placement_m=R.signed_placement(model,zero,heading),
        final_gap_m=final['foot_hull_gap_m'],final_minimum_nonfoot_weight_fraction=final_load.get('minimum_nonfoot_weight_fraction'),selected_modes=modes,
        total_integrator_rhs_calls=sum(row['rhs_calls'] for row in trajectory),integration_solver_records=sum(row['solver_record_count'] for row in trajectory),
        quadratic_rhs_status_counts={status:sum(row['quadratic_rhs_status_counts'].get(status,0) for row in trajectory) for status in (*P.F.F.STATUSES,V.STATUS)},
        near_ground_target_reached=stop=='right_rear_near_ground_model_target',ground_contact_acquired=False,landing_proven=False,complete_transfer_or_rise_proven=False)
    retain(dict(kind='terminal_summary',value=summary))
    return dict(schema_version='sporespore_r10cy_consistent_ground_approach_path_result_v1',ledger_scope=declaration['ledger_scope'],declaration=C.bind(STUDY),implementation=C.bind(__file__),
        controls=checked,entry_contact_replay=replay,initial=initial,final=final,phase_reference=reference,entry_velocity=entry,entry_verification=verification,summary=summary,trajectory=trajectory,
        journal=dict(line_count=count,raw_sha256='sha256:'+digest.hexdigest()),**declaration['claim_boundary'])


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    for flag in ('declare','controls','create'):parser.add_argument('--'+flag,action='store_true')
    parser.add_argument('--journal');args=parser.parse_args()
    if args.declare:declare();print('R10CY prospective declaration created')
    elif args.controls:print(json.dumps(controls(),indent=2))
    elif args.create:
        if not args.journal:parser.error('--create requires fresh durable --journal')
        path=Path(args.journal).resolve();assert path.is_relative_to(C.EVIDENCE.resolve()) and not RESULT.exists()
        with path.open('xb') as journal:result=derive(journal)
        json.dumps(result,allow_nan=False)
        C.write_new(RESULT,result);print(json.dumps(L.present(result,False),indent=2))
    else:
        result=C.read(RESULT);assert result==derive();print(json.dumps(L.present(result,True),indent=2))
