"""Frozen-pose multi-contact load feasibility on exposed R10AP data only.

No dynamics, controller, physics world, or new interpretation of the original
recovery grade. Every LP result carries checked primal and dual residuals.
"""
import argparse
from collections import Counter
import json
from pathlib import Path
import numpy as np
import scipy
from scipy.optimize import linprog

import r10ap_load_tracking_diagnosis as tracking
import r10af_contact_frame_replay as replay

C,G=tracking.C,tracking.G
STUDY=C.ROOT/'sdk/recovery/r10ar_multicontact_statics_study_v1.json'
RESULT=C.ROOT/'sdk/recovery/r10ar_multicontact_statics_result_v1.json'
VARIANTS=('all_contacts_uncapped','all_contacts_capped','foot_contacts_capped')
OPTIONS=dict(primal_feasibility_tolerance=1e-9,dual_feasibility_tolerance=1e-9)
CERT=1e-6
FEAS=1e-7


def lp(cost,a,b,u,v,bounds):
    result=linprog(cost,A_ub=u,b_ub=v,A_eq=a,b_eq=b,bounds=bounds,method='highs-ds',options=OPTIONS)
    assert result.success, (result.status,result.message)
    x=result.x;eq=result.eqlin.marginals;ineq=result.ineqlin.marginals
    lower=result.lower.marginals;upper=result.upper.marginals
    primal=max(float(np.max(np.abs(a@x-b))),float(np.max(u@x-v,initial=0.)))
    stationarity=np.asarray(cost)-a.T@eq-u.T@ineq-lower-upper
    dual=float(b@eq+v@ineq)
    complementarity=float(np.max(np.abs((v-u@x)*ineq),initial=0.))
    for i,(lo,hi) in enumerate(bounds):
        if lo is not None:
            primal=max(primal,lo-x[i]);dual+=lo*lower[i]
            complementarity=max(complementarity,abs((x[i]-lo)*lower[i]))
        else:assert abs(lower[i])<CERT
        if hi is not None:
            primal=max(primal,x[i]-hi);dual+=hi*upper[i]
            complementarity=max(complementarity,abs((hi-x[i])*upper[i]))
        else:assert abs(upper[i])<CERT
    certificate=dict(primal_max_residual=float(primal),stationarity_max_residual=float(np.max(np.abs(stationarity))),
        dual_sign_violation=max(float(np.max(ineq,initial=0.)),float(np.max(-lower,initial=0.)),float(np.max(upper,initial=0.))),
        complementarity_max_residual=float(complementarity),primal_objective=float(np.asarray(cost)@x),dual_objective=dual,
        objective_gap=abs(float(np.asarray(cost)@x)-dual))
    assert all(certificate[k]<=CERT for k in ('primal_max_residual','stationarity_max_residual','dual_sign_violation','complementarity_max_residual','objective_gap')),certificate
    return x,certificate


def solve(a,b,foot,caps,mu,weight):
    n=len(foot);j=len(caps);variables=3*n+j;equations=len(b)
    assert a.shape==(equations,variables) and weight>0
    bounds=[bound for _ in foot for bound in ((None,None),(0.,None),(None,None))]
    bounds.extend((None,None) if cap is None else (-cap,cap) for cap in caps)
    inequalities=[]
    for i in range(n):
        for sx,sz in ((-1.,-1.),(-1.,1.),(1.,-1.),(1.,1.)):
            row=np.zeros(variables);row[3*i:3*i+3]=[sx,-mu,sz];inequalities.append(row)
    u=np.array(inequalities).reshape((-1,variables));v=np.zeros(len(u))
    scale=np.maximum(1.,np.abs(b));scaled=a/scale[:,None];rhs=b/scale
    # Phase I always has a feasible point at zero force/torque and signed
    # equilibrium slacks. A positive certified optimum is a model refusal.
    aug=np.hstack((scaled,np.eye(equations),-np.eye(equations)))
    aug_u=np.hstack((u,np.zeros((len(u),2*equations))))
    cost=np.r_[np.zeros(variables),np.ones(2*equations)]
    _,phase=lp(cost,aug,rhs,aug_u,v,bounds+[(0.,None)]*(2*equations))
    if phase['primal_objective']>FEAS:
        return dict(feasible=False,phase_one=phase,reason='certified_positive_equilibrium_slack')
    objective=np.zeros(variables)
    for i,is_foot in enumerate(foot):
        if not is_foot:objective[3*i+1]=1./weight
    x,certificate=lp(objective,scaled,rhs,u,v,bounds)
    residual=float(np.max(np.abs(a@x-b)))
    assert residual<CERT
    return dict(feasible=True,phase_one=phase,minimum_nonfoot_weight_fraction=certificate['primal_objective'],
        forces_world_n=x[:3*n].reshape((n,3)).tolist(),joint_torques_nm=x[3*n:].tolist(),
        unscaled_equilibrium_max_residual=residual,certificate=certificate)


def controls():
    def rigid(points):
        a=np.zeros((6,3*len(points)))
        for i,p in enumerate(points):
            a[:3,3*i:3*i+3]=np.eye(3)
            for axis in range(3):a[3:,3*i+axis]=np.cross(p,np.eye(3)[axis])
        return a
    b=np.array([0.,10.,0.,0.,0.,0.])
    cases=[([[0.,0.,0.]],[True],True,0.),([[1.,0.,0.]],[True],False,None),
        ([[-1.,0.,0.],[1.,0.,0.]],[False,True],True,.5),([[0.,0.,0.]],[False],True,1.)]
    checked=0
    for points,feet,feasible,value in cases:
        result=solve(rigid(points),b,feet,[],1.8,10.);assert result['feasible']==feasible
        if feasible:assert abs(result['minimum_nonfoot_weight_fraction']-value)<CERT
        checked+=1
    a=np.zeros((7,4));a[:6,:3]=rigid([[0.,0.,0.]])
    a[6,1]=1.;a[6,3]=1.;b7=np.r_[b,0.]
    assert not solve(a,b7,[True],[5.],1.8,10.)['feasible'];checked+=1
    assert solve(a,b7,[True],[10.],1.8,10.)['feasible'];checked+=1
    # Deliberate wrong equilibrium and wrong dual stationarity must be visible
    # independently of a successful optimizer status.
    force=np.array([0.,10.,0.]);assert np.max(np.abs(rigid([[0.,0.,0.]])@force-b))==0.;checked+=1
    assert np.max(np.abs(rigid([[1.,0.,0.]])@force-b))==10.;checked+=1
    return dict(known_answer_force_moment_load_fraction_and_torque_controls=checked)


def frame(packet,descriptor,expected_com):
    bodies={x['body_id']:x for x in packet['callback_bodies']}
    states=packet['direct_state_source']['ordered_body_states']
    origin=np.array(G.vector(bodies['torso']['pose']['origin']))
    def basis(name):return np.array(bodies[name]['pose']['basis_columns']).T
    root=basis('torso');anchors=[];axes=[]
    upper=.35*descriptor['upper_length_fraction']
    for i,foot in enumerate(G.FEET):
        hip=np.array([(.2 if i<2 else -.2)*descriptor['hip_span_scale'],0.,(-.18 if i%2==0 else .18)*descriptor['hip_span_scale']])
        anchors.extend((origin+root@hip,np.array(G.vector(bodies[foot+'_upper']['pose']['origin']))+basis(foot+'_upper')@np.array([0.,-upper/2,0.])))
        axes.extend((root[:,2],basis(foot+'_upper')[:,2]))
    axes=[a/np.linalg.norm(a) for a in axes]
    def jacobian(body,point):
        p=np.asarray(point);j=np.zeros((3,14));j[:,:3]=np.eye(3)
        for k in range(3):j[:,3+k]=np.cross(np.eye(3)[k],p-origin)
        if body!='torso':
            i=next(i for i,f in enumerate(G.FEET) if body.startswith(f+'_'))
            count=2 if body.endswith('_distal') else 1
            for k in range(2*i,2*i+count):j[:,6+k]=np.cross(axes[k],p-anchors[k])
        return j
    gravity=np.array(G.vector(packet['direct_state_source']['gravity_world_m_s2']))
    assert gravity[0]==gravity[2]==0. and gravity[1]<0.
    force=np.zeros(14);mass=0.;weighted=np.zeros(3)
    for body in states:
        position=np.array(G.vector(body['position_world_m']));m=body['mass_kg'];assert m>0
        force+=jacobian(body['body_id'],position).T@(m*gravity);mass+=m;weighted+=m*position
    com=weighted/mass;com_error=float(np.max(np.abs(com-expected_com)));assert com_error<1e-6
    points=[p for p in packet['contact_source_receipt']['ordered_contact_samples'] if p['normal_impulse_ns']>0]
    return points,jacobian,-force,mass*(-gravity[1]),com_error


def derive():
    declaration=C.read(STUDY)
    for b in [*declaration['dependencies'],declaration['population']['report']]:assert C.bind(b['path'])==b
    assert declaration['numerics']['numpy']==np.__version__ and declaration['numerics']['scipy']==scipy.__version__
    checked=controls();descriptor,samples=tracking.rows();indexed={r['semantic_step']:r for r in samples}
    report=C.CHILD/'worker_report.json';configuration=C.streams.small_fields(report)['configuration']
    mu=configuration['authored_friction'];assert mu==declaration['model']['friction_coefficient']==1.8
    rows=[];contact_count=0
    for record in G.records(report,'r10af_contact_frames','records'):
        packet=record['packet'];sample=indexed.get(packet['semantic_step'])
        if sample is None:continue
        validated=replay.replay(packet,packet['semantic_step'],packet['model_instance_id'],packet['body_population_instance_sha256'])
        assert validated['ok'];contact_count+=validated['matched_source_contacts']
        points,jacobian,b,weight,com_error=frame(packet,descriptor,np.array(sample['com']))
        variants={}
        for name in VARIANTS:
            chosen=[p for p in points if name!='foot_contacts_capped' or p['classified_as_foot']]
            caps=[None]*8 if name=='all_contacts_uncapped' else [v/G.DT for v in sample['caps']]
            a=np.zeros((14,3*len(chosen)+8));a[6:,3*len(chosen):]=np.eye(8)
            for i,p in enumerate(chosen):a[:,3*i:3*i+3]=jacobian(p['body_id'],G.vector(p['position_world_m'])).T
            result=solve(a,b,[p['classified_as_foot'] for p in chosen],caps,mu,weight)
            variants[name]=dict(contact_count=len(chosen),contact_bodies=[p['body_id'] for p in chosen],**result)
        rows.append(dict(partial_step=sample['partial_step'],semantic_step=sample['semantic_step'],
            center_of_mass_reconstruction_error_m=com_error,variants=variants))
    assert len(rows)==601
    summary={name:dict(feasible=sum(r['variants'][name]['feasible'] for r in rows),
        refused=sum(not r['variants'][name]['feasible'] for r in rows),
        minimum_nonfoot_weight_fraction=G.stats([r['variants'][name]['minimum_nonfoot_weight_fraction'] for r in rows if r['variants'][name]['feasible']])) for name in VARIANTS}
    return dict(schema_version='sporespore_r10ar_multicontact_statics_result_v1',ledger_scope=declaration['ledger_scope'],
        declaration=C.bind(STUDY),implementation=C.bind(__file__),controls=checked,
        independently_replayed_contacts=contact_count,summary=summary,rows=rows,**declaration['claim_boundary'])


def audit():
    result=C.read(RESULT);assert result==derive()
    return dict(ok=True,controls=result['controls'],summary=result['summary'],world_build_count=0,solver_step_count=0,
        physical_acceptance_authority=False,release_authority=False)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--create',action='store_true')
    args=parser.parse_args()
    if args.create:C.write_new(RESULT,derive())
    print(json.dumps(audit(),indent=2))
