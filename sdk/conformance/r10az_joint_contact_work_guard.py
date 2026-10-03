"""Distinct successor retaining work refusals and trying smaller declared steps.

Mixed-integer search is a bounded model proposal. A separate fixed-mode LP and
nonlinear pose/load checks are required; solver status alone is not admission.
"""
import argparse
import copy
import json
import numpy as np
from scipy.optimize import milp, Bounds, LinearConstraint

import r10ax_coupled_sliding_study as X

S, C, G = X.S, X.C, X.G
STUDY = C.ROOT/'sdk/recovery/r10az_joint_contact_work_guard_study_v1.json'
RESULT = C.ROOT/'sdk/recovery/r10az_joint_contact_work_guard_result_v1.json'
MODES = (None, None, (0, 1.), (0, -1.), (2, 1.), (2, -1.))
OPTIONS = dict(time_limit=60., node_limit=100000, mip_rel_gap=0., presolve=True)


def work_allowed(work, minimum):
    return work <= 1e-9 and abs(work-minimum) <= 1e-9


def assembly(model, delta):
    packet = copy.deepcopy(model.packet); poses = model.poses(delta)
    for body in packet['callback_bodies']:
        name = body['body_id']; body['pose']['origin'] = poses[0][name].tolist(); body['pose']['basis_columns'] = poses[1][name].T.tolist()
    for body in packet['direct_state_source']['ordered_body_states']:
        name = body['body_id']; body['position_world_m'] = model.point(poses, name, model.local_com[name]).tolist()
    for point, world in zip([p for p in packet['contact_source_receipt']['ordered_contact_samples'] if p['normal_impulse_ns'] > 0], model.contact_points(delta), strict=True):
        point['position_world_m'] = world.tolist()
    contacts, jacobian, rhs, weight, _ = S.statics.frame(packet, model.d, model.com(poses))
    a = np.zeros((14, 3*len(contacts)+8)); a[6:, 3*len(contacts):] = np.eye(8)
    for i, p in enumerate(contacts):a[:, 3*i:3*i+3] = jacobian(p['body_id'], G.vector(p['position_world_m'])).T
    return a, rhs, weight


def mode_force_rows(n, modes):
    rows = []
    for i, mode in enumerate(modes):
        if mode == 0:
            row = np.zeros(3*n+8); row[3*i+1] = 1.; rows.append(row)
        elif mode >= 2:
            axis, sign = MODES[mode]
            rows.extend(X.force_mode_rows(3*n+8, [i], axis, sign))
    return np.array(rows).reshape((-1, 3*n+8))


def load(model, delta, modes, caps):
    a, rhs, weight = assembly(model, delta); extra = mode_force_rows(len(modes), modes)
    return S.statics.solve(np.vstack((a, extra)),np.r_[rhs,np.zeros(len(extra))],
        [p['classified_as_foot'] for p in model.contacts],caps,X.MU,weight)


class Problem:
    def __init__(self, model, caps, heading):
        self.model = model; self.n = len(model.contacts); self.base = 14+3*self.n+8
        self.columns = self.base+6*self.n
        self.eq = []; self.rhs = []; self.ub = []; self.limit = []; self.mode_rows = {}
        a, b, weight = assembly(model,np.zeros(14))
        self.scale = np.r_[S.MAXIMUM, np.full(3*self.n,weight),caps]
        lo, hi = S.bounds(model.joints)
        self.lower = np.r_[lo/S.MAXIMUM, np.tile([-X.MU,0.,-X.MU],self.n),-np.ones(8),np.zeros(6*self.n)]
        self.upper = np.r_[hi/S.MAXIMUM, np.tile([X.MU,1.,X.MU],self.n),np.ones(8),np.ones(6*self.n)]
        balance = np.c_[np.zeros((14,14)),a]*self.scale
        for row, rhs in zip(balance,b):self.equality(row/max(1.,abs(rhs)),rhs/max(1.,abs(rhs)))
        self.cost = np.zeros(self.columns); self.cost[:3] = -heading*S.MAXIMUM[:3]/(.1*G.DT)
        j = S.derivative(model.contact_points,np.zeros(14))*S.MAXIMUM
        f = model.features_y(np.zeros(14)); fj = S.derivative(model.features_y,np.zeros(14))*S.MAXIMUM
        for row, floor in zip(fj,f):
            self.inequality(self.velocity_row(-row),floor-min(0.,floor))
        for i in range(self.n):
            for sx,sz in ((-1.,-1.),(-1.,1.),(1.,-1.),(1.,1.)):
                row = np.zeros(self.base); row[14+3*i:14+3*i+3] = [sx,-X.MU,sz]; self.inequality(row,0.)
            self.inequality(self.velocity_row(-j[i,1]),0.)
            choice = np.zeros(self.columns); choice[self.base+6*i:self.base+6*i+6] = 1.
            self.eq.append(choice); self.rhs.append(1.)
            for mode in range(6):
                rows = []
                def eq(row):rows.extend(((row,0.),(-row,0.)))
                if mode == 0:
                    row = np.zeros(self.base); row[14+3*i+1] = 1.; eq(row)
                else:
                    eq(self.velocity_row(j[i,1]))
                    if mode == 1:
                        eq(self.velocity_row(j[i,0])); eq(self.velocity_row(j[i,2]))
                    else:
                        axis,sign = MODES[mode]
                        for other_sign in (-1.,1.):rows.append((self.velocity_row(other_sign*j[i,2-axis]-sign*j[i,axis]),0.))
                        for force_row in X.force_mode_rows(3*self.n+8,[i],axis,sign):eq(np.r_[np.zeros(14),force_row])
                self.mode_rows[(i,mode)] = rows
                for row,rhs in rows:self.conditional(row,rhs,self.base+6*i+mode)
        self.eq = np.array(self.eq); self.rhs = np.array(self.rhs); self.ub = np.array(self.ub); self.limit = np.array(self.limit)

    def velocity_row(self, row):return np.r_[row,np.zeros(self.base-14)]
    def equality(self,row,rhs):self.eq.append(np.r_[row,np.zeros(self.columns-len(row))]); self.rhs.append(rhs)
    def inequality(self,row,rhs):
        scale = max(float(np.max(np.abs(row))),abs(rhs),1e-12)
        self.ub.append(np.r_[row,np.zeros(self.columns-len(row))]/scale); self.limit.append(rhs/scale)
    def conditional(self,row,rhs,index):
        # Finite bounds derive M; no unbounded or guessed force/velocity M.
        maximum = float(np.maximum(row,0.)@self.upper[:self.base]+np.minimum(row,0.)@self.lower[:self.base])
        big_m = max(0.,maximum-rhs)+1e-12
        full = np.r_[row,np.zeros(self.columns-self.base)]; full[index] = big_m
        self.inequality(full,rhs+big_m)

    def solve(self):
        result = milp(self.cost,integrality=np.r_[np.zeros(self.base),np.ones(self.columns-self.base)],
            bounds=Bounds(self.lower,self.upper),constraints=[LinearConstraint(self.eq,self.rhs,self.rhs),
            LinearConstraint(self.ub,np.full(len(self.ub),-np.inf),self.limit)],options=OPTIONS)
        record = dict(status=int(result.status),message=result.message,success=bool(result.success),
            node_count=getattr(result,'mip_node_count',None),reported_dual_bound=getattr(result,'mip_dual_bound',None),
            reported_relative_gap=getattr(result,'mip_gap',None),proposal=None)
        if not result.success or result.x is None:return record
        x = result.x
        residual = max(float(np.max(np.abs(self.eq@x-self.rhs))),float(np.max(self.ub@x-self.limit)),
            float(np.max(self.lower-x)),float(np.max(x-self.upper)))
        binary = x[self.base:]; integer_error = float(np.max(np.abs(binary-np.round(binary))))
        assert residual <= 1e-6 and integer_error <= 1e-6
        modes = np.argmax(binary.reshape((self.n,6)),axis=1).tolist()
        record['proposal'] = dict(modes=modes,scaled_solution=x[:self.base].tolist(),recomputed_objective=float(self.cost@x),
            maximum_scaled_primal_residual=residual,maximum_integrality_error=integer_error)
        return record

    def certify_mode(self,modes):
        # Independently rebuild a continuous fixed-mode LP without binary M.
        a,b,weight = assembly(self.model,np.zeros(14)); eq = np.c_[np.zeros((14,14)),a]*self.scale
        scale = np.maximum(1.,np.abs(b)); eq /= scale[:,None]; rhs = b/scale
        # Keep only unconditional rows (all binary coefficients are zero).
        active = np.all(self.ub[:,self.base:] == 0.,axis=1)
        u = list(self.ub[active,:self.base]); v = list(self.limit[active])
        for i,mode in enumerate(modes):
            for row,bound in self.mode_rows[(i,mode)]:
                normalization = max(float(np.max(np.abs(row))),abs(bound),1e-12)
                u.append(row/normalization); v.append(bound/normalization)
        u=np.array(u);v=np.array(v);bounds=list(zip(self.lower[:self.base],self.upper[:self.base]))
        _,first = S.statics.lp(self.cost[:self.base],eq,rhs,u,v,bounds)
        identity=np.c_[np.eye(14),np.zeros((14,self.base-14))]
        second_u=np.vstack((np.c_[u,np.zeros((len(u),14))],
            np.r_[self.cost[:self.base],np.zeros(14)][None,:],
            np.c_[identity,-np.eye(14)],np.c_[-identity,-np.eye(14)]))
        second_v=np.r_[v,first['primal_objective']+1.2e-7,np.zeros(28)]
        x,second=S.statics.lp(np.r_[np.zeros(self.base),np.ones(14)],np.c_[eq,np.zeros((len(eq),14))],rhs,
            second_u,second_v,bounds+[(0.,None)]*14)
        return x[:self.base]*self.scale,dict(maximum_progress=first,minimum_normalized_motion=second)


def contact_residual(model,delta,modes,initial):
    difference = model.contact_points(delta)-initial; rows = []
    for i,mode in enumerate(modes):
        if mode == 1:rows.extend(difference[i])
        elif mode >= 2:rows.append(difference[i,1])
    return np.array(rows)


def finite(model,caps,modes,proposed,heading):
    initial = model.contact_points(np.zeros(14)); floor = model.features_y(np.zeros(14)); lo,hi = S.bounds(model.joints)
    attempts = []
    for exponent in range(11):
        nodes = []; reason = None; previous = initial
        for fraction in (.25,.5,.75,1.):
            delta = proposed*(2.**-exponent)*fraction
            for iteration in range(11):
                residual = contact_residual(model,delta,modes,initial)
                if np.max(np.abs(residual)) <= 1e-11:break
                if iteration == 10:break
                jac = S.derivative(lambda x:contact_residual(model,x,modes,initial),delta)
                delta += np.linalg.lstsq(jac*S.MAXIMUM,-residual,rcond=1e-12)[0]*S.MAXIMUM
            points = model.contact_points(delta); travel = points-previous
            checks = dict(contact=float(np.max(np.abs(residual))),bounds=max(float(np.max(lo-delta)),float(np.max(delta-hi))),
                marker_descent=float(np.max(initial[:,1]-points[:,1])),floor=float(np.max(np.minimum(0.,floor)-model.features_y(delta))))
            for i,mode in enumerate(modes):
                if mode >= 2:
                    axis,sign = MODES[mode]; checks[f'sector_{i}'] = float(abs(travel[i,2-axis])-sign*travel[i,axis])
            node = dict(fraction=fraction,delta=delta.tolist(),checks=checks,forward_progress_m=float(delta[:3]@heading),foot_hull_gap_m=model.gap(delta));nodes.append(node)
            if any(value > 1e-9 for value in checks.values()):reason='nonlinear_geometry_or_sector_guard';break
            if node['forward_progress_m'] <= 1e-9*fraction:reason='no_finite_body_progress';break
            node['load'] = load(model,delta,modes,caps)
            if not node['load']['feasible']:reason='finite_force_balance_refusal';break
            work_checks=[]
            for i,mode in enumerate(modes):
                if mode >= 2:
                    force=np.array(node['load']['forces_world_n'][i]);work=float(force[[0,2]]@travel[i,[0,2]])
                    bound=-X.MU*force[1]*float(np.max(np.abs(travel[i,[0,2]])))
                    work_checks.append(dict(contact=i,work_j=work,minimum_diamond_work_j=bound,error_j=abs(work-bound)))
                    if not work_allowed(work,bound):
                        reason='maximum_dissipation_work_refusal'
                        break
            node['dissipation']=work_checks
            if reason is not None:break
            previous=points
        attempts.append(dict(scale=2.**-exponent,samples=nodes,refusal=reason))
        if reason is None:return dict(selected=attempts[-1],attempts=attempts,refusal=None)
    return dict(selected=None,attempts=attempts,refusal='all_finite_steps_refused')


def controls():
    checked=X.controls()
    # Fractional optimum x=1.5 must not masquerade as integer x=1.
    result=milp(np.array([-1.]),integrality=[1],bounds=Bounds([0.],[1.5]),options=OPTIONS)
    assert result.success and result.x.tolist()==[1.] and result.fun==-1.
    for mode in range(2,6):
        axis,sign=MODES[mode];row=mode_force_rows(1,[mode]);force=np.zeros(11)
        force[1]=2.;force[axis]=-sign*X.MU*2.
        assert np.max(np.abs(row@force))==0.
        assert force[axis]*sign<0.
    checked['additional_integer_and_four_sector_force_controls']=9
    # Exhaust the corners of a manufactured conditional inequality. The
    # binary-off branch must admit every bounded point; binary-on means g<=0.
    p=Problem.__new__(Problem);p.base=2;p.columns=3
    p.lower=np.array([-1.,-2.,0.]);p.upper=np.array([2.,4.,1.]);p.ub=[];p.limit=[]
    p.conditional(np.array([2.,-3.]),0.,2)
    for x in (-1.,2.):
        for y in (-2.,4.):
            assert p.ub[0]@np.array([x,y,0.])<=p.limit[0]+1e-12
            assert (p.ub[0]@np.array([x,y,1.])<=p.limit[0]+1e-12)==(2*x-3*y<=0.)
    checked['additional_conditional_bound_truth_table_controls']=8
    # Geometry tolerance alone is insufficient when multiplied by a force.
    force=30.; dx=-1e-6; dz=-1.0005e-6
    assert abs(dz)-abs(dx) <= 1e-9 and not work_allowed(force*dx,-force*max(abs(dx),abs(dz)))
    assert work_allowed(-force*1e-6,-force*1e-6)
    assert not work_allowed(force*1e-6,-force*1e-6)
    checked['additional_force_work_units_and_refusal_controls']=3
    return checked


def derive():
    declaration=C.read(STUDY)
    for binding in [*declaration['dependencies'],declaration['population']['report']]:assert C.bind(binding['path'])==binding
    assert np.__version__==declaration['numerics']['numpy'] and S.statics.scipy.__version__==declaration['numerics']['scipy']
    checked=controls();descriptor,samples=S.statics.tracking.rows();entry=samples[0]
    assert entry['semantic_step']==513 and entry['partial_step']==1
    packet=next(r['packet'] for r in G.records(C.CHILD/'worker_report.json','r10af_contact_frames','records') if r['packet']['semantic_step']==513)
    replay=S.statics.replay.replay(packet,513,packet['model_instance_id'],packet['body_population_instance_sha256']);assert replay['ok']
    model=S.Model(packet,descriptor,entry['joint_positions_rad']);caps=[v/G.DT for v in entry['caps']]
    heading=model.r['torso'][:,0].copy();heading[1]=0.;heading/=np.linalg.norm(heading)
    problem=Problem(model,caps,heading);search=problem.solve();verification=None;step=None
    if search['proposal'] is not None:
        modes=search['proposal']['modes'];solution,certificate=problem.certify_mode(modes)
        assert abs(certificate['maximum_progress']['primal_objective']-search['proposal']['recomputed_objective'])<=1e-6
        verification=dict(modes=modes,physical_solution=solution.tolist(),certificate=certificate,
            forward_linear_progress_m=float(solution[:3]@heading))
        if verification['forward_linear_progress_m']>1e-9:step=finite(model,caps,modes,solution[:14],heading)
    summary=dict(search_status=search['status'],fixed_mode_linear_progress_m=None if verification is None else verification['forward_linear_progress_m'],
        selected_modes=None if verification is None else verification['modes'],finite_step_admitted=step is not None and step['selected'] is not None,
        finite_refusal=None if step is None else step['refusal'])
    return dict(schema_version='sporespore_r10az_joint_contact_work_guard_result_v1',ledger_scope=declaration['ledger_scope'],declaration=C.bind(STUDY),implementation=C.bind(__file__),
        controls=checked,entry_contact_replay=replay,summary=summary,search=search,fixed_mode_verification=verification,finite_step=step,**declaration['claim_boundary'])


def audit():
    result=C.read(RESULT);assert result==derive()
    return dict(ok=True,controls=result['controls'],summary=result['summary'],world_build_count=0,solver_step_count=0,physical_acceptance_authority=False,release_authority=False)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--create',action='store_true');parser.add_argument('--controls',action='store_true');args=parser.parse_args()
    if args.controls:print(json.dumps(controls(),indent=2))
    else:
        if args.create:C.write_new(RESULT,derive())
        print(json.dumps(audit(),indent=2))
