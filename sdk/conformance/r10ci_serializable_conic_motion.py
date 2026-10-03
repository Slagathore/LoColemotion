"""Complete refusal retention for the unchanged R10CH numerical algorithm.

Nonfinite certificate diagnostics receive explicit tagged JSON values. They
remain rejected. The incomplete R10CH publication is retained independently.
"""
import argparse
import json
import math
import subprocess
import numpy as np
import r10ch_reduced_conic_motion as H
F,P,E,C,K,S,L=H.F,H.P,H.E,H.C,H.K,H.S,H.L
STUDY=C.ROOT/'sdk/recovery/r10ci_serializable_conic_motion_study_v1.json'
RESULT=C.ROOT/'sdk/recovery/r10ci_serializable_conic_motion_result_v1.json'


def safe_record(value,path='$',nonfinite=None):
    if nonfinite is None:nonfinite=[]
    if isinstance(value,float) and not math.isfinite(value):
        label='nan' if math.isnan(value) else ('positive_infinity' if value>0 else 'negative_infinity')
        nonfinite.append(dict(path=path,value=label));return dict(nonfinite=label)
    if isinstance(value,dict):return {k:safe_record(v,path+'.'+k,nonfinite) for k,v in value.items()}
    if isinstance(value,list):return [safe_record(v,path+'['+str(i)+']',nonfinite) for i,v in enumerate(value)]
    return value


def solve_qp(a,b,u,v,bounds,start):
    with np.errstate(over='ignore',invalid='ignore'):
        raw=H.solve_qp(a,b,u,v,bounds,start)
    nonfinite=[];record=safe_record(raw,nonfinite=nonfinite)
    record['nonfinite_diagnostics']=nonfinite
    if nonfinite:record['accepted']=False
    json.dumps(record,allow_nan=False)
    return record


def controls():
    checked=H.controls()
    paths=[];result=safe_record(dict(values=[float('inf'),float('-inf'),float('nan'),1.]),nonfinite=paths)
    assert len(paths)==3 and result['values'][-1]==1.
    assert json.loads(json.dumps(result,allow_nan=False))==result
    assert [r['value'] for r in paths]==['positive_infinity','negative_infinity','nan']
    checked['additional_nonfinite_refusal_retention_and_json_roundtrip_controls']=3
    return checked


def declare():
    prior=C.read(H.STUDY)
    C.write_new(STUDY,dict(prior,schema_version='sporespore_r10ci_serializable_conic_motion_study_v1',
        ledger_scope=dict(prior['ledger_scope'],authority_mode='prospective_nonfinite_refusal_retention'),
        source_parent_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=C.ROOT).decode().strip(),
        question='Can the unchanged R10CH numerical test retain every finite or nonfinite refusal and complete all60 regression outcomes?',
        dependencies=prior['dependencies']+[C.bind(p) for p in [H.__file__,H.STUDY,H.RESULT,C.ROOT/'sdk/recovery/r10ch_reduced_conic_motion_execution_closure_v1.json',__file__]],
        design=dict(prior['design'],serialization='Map every nonfinite diagnostic scalar to an explicit nonfinite tag and retain its field path. Any such occurrence forces candidate rejection. Validate complete JSON before opening the result file. Numerical inputs, solver settings and original certificate unchanged; old incomplete execution is not regraded.'),
        checks=['211 inherited plus3 nonfinite-tag/path and strict-JSON roundtrip checks.','All60 outcomes and complete cold replay.']))


def derive():
    declaration=C.read(STUDY)
    for binding in declaration['dependencies']:assert C.bind(binding['path'])==binding
    assert np.__version__==declaration['numerics']['numpy'] and S.statics.scipy.__version__==declaration['numerics']['scipy']
    checked=controls();previous=C.read(F.RESULT);path=C.read(P.RESULT)
    bank=[dict(name='R10CF_'+str(i),specification=row['specification'],source=C.bind(F.RESULT),problem=row['quadratic']['quadratic_problem'],
        retained_original=row['quadratic']['quadratic_result']) for i,row in enumerate(previous['probes'])]
    failed=path['trajectory'][-1]['velocity_refusal']['diagnostic']
    bank.append(dict(name='R10CG_failed_runtime',source=C.bind(P.RESULT),problem=failed['quadratic_problem'],retained_original=failed['quadratic_result']))
    for row in bank:
        p=row['problem'];a,b,u,v=[np.array(p[key]) for key in ('equality','equality_rhs','inequality','inequality_rhs')]
        row['candidate']=solve_qp(a,b,u,v,p['bounds'],np.array(p['start']))
    assert len(bank)==60
    summary=dict(problem_count=len(bank),certified_problems=sum(row['candidate']['accepted'] for row in bank),
        prior_population_certified=sum(row['candidate']['accepted'] for row in bank[:-1]),new_runtime_failure_certified=bank[-1]['candidate']['accepted'])
    return dict(schema_version='sporespore_r10ci_serializable_conic_motion_result_v1',ledger_scope=declaration['ledger_scope'],
        declaration=C.bind(STUDY),implementation=C.bind(__file__),controls=checked,problems=bank,summary=summary,**declaration['claim_boundary'])

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    for flag in ('declare','controls','create'):parser.add_argument('--'+flag,action='store_true')
    args=parser.parse_args()
    if args.declare:declare();print('R10CI prospective declaration created')
    elif args.controls:print(json.dumps(controls(),indent=2))
    elif args.create:
        assert not RESULT.exists();result=derive();json.dumps(result,allow_nan=False);C.write_new(RESULT,result);print(json.dumps(E.W.T.present(result,False),indent=2))
    else:
        result=C.read(RESULT);assert result==derive();print(json.dumps(E.W.T.present(result,True),indent=2))
