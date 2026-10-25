"""Exact binary-coefficient Farkas checks; floating LP proposes support only."""
from fractions import Fraction as F
import hashlib
import json
import math
import numpy as np
from scipy.optimize import linprog

def require(ok,label):
    if not ok:raise ValueError(label)

def exact(value):
    require(type(value) in (int,float) and math.isfinite(value),"Finite numeric coefficient")
    return F(value)

def encode(value):
    return [str(value.numerator),str(value.denominator)]

def decode(value):
    require(isinstance(value,list) and len(value)==2 and all(isinstance(x,str) for x in value),
        "Exact rational encoding")
    numerator,denominator=map(int,value)
    require(denominator>0,"Positive rational denominator")
    return F(numerator,denominator)

def digest(problem):
    return hashlib.sha256(json.dumps(problem,sort_keys=True,separators=(",",":"),allow_nan=False).encode()).hexdigest()

def canonical(problem):
    a=problem["A"];lower=problem["lower"];upper=problem["upper"]
    require(isinstance(a,list) and a and len(a)==len(lower)==len(upper),"Constraint population")
    n=len(a[0]);require(n>0 and all(len(v)==n for v in a),"Constraint dimensions")
    rows=[]
    for i,(values,l,u) in enumerate(zip(a,lower,upper,strict=True)):
        v=[exact(x) for x in values]
        require(l is None or u is None or l<=u,"Ordered finite bounds")
        if l is not None and u is not None and l==u:
            rows.append(dict(row=i,side="equal",a=v,b=exact(l)))
        else:
            if l is not None:rows.append(dict(row=i,side="lower",a=[-x for x in v],b=-exact(l)))
            if u is not None:rows.append(dict(row=i,side="upper",a=v,b=exact(u)))
    return n,rows

def dot(a,b):
    return sum((x*y for x,y in zip(a,b,strict=True)),F(0))

def solve_exact(matrix,rhs):
    """RREF of an exact rectangular system; free variables are zero."""
    require(matrix and len(matrix)==len(rhs),"Exact system rows")
    cols=len(matrix[0]);require(cols>0 and all(len(r)==cols for r in matrix),"Exact system columns")
    a=[list(r)+[v] for r,v in zip(matrix,rhs,strict=True)];pivot=[];row=0
    for col in range(cols):
        found=next((i for i in range(row,len(a)) if a[i][col]),None)
        if found is None:continue
        a[row],a[found]=a[found],a[row];scale=a[row][col]
        a[row]=[x/scale for x in a[row]]
        for i in range(len(a)):
            if i==row or not a[i][col]:continue
            scale=a[i][col];a[i]=[x-scale*y for x,y in zip(a[i],a[row],strict=True)]
        pivot.append(col);row+=1
        if row==len(a):break
    require(all(any(r[:-1]) or not r[-1] for r in a),"Inconsistent exact certificate system")
    solution=[F(0)]*cols
    for i,col in enumerate(pivot):solution[col]=a[i][-1]
    require(all(dot(r,solution)==v for r,v in zip(matrix,rhs,strict=True)),"Exact system reconstruction")
    return solution,len(pivot)

def verify(problem,certificate):
    """Verify a contradiction directly against all named original coefficients."""
    require(certificate["problem_sha256"]==digest(problem),"Certificate problem identity")
    n,rows=canonical(problem);lookup={(r["row"],r["side"]):r for r in rows}
    total=[F(0)]*n;bound=F(0);weight=F(0);seen=set()
    require(isinstance(certificate["terms"],list) and certificate["terms"],"Certificate term population")
    for term in certificate["terms"]:
        key=(term["row"],term["side"])
        require(key in lookup and key not in seen,"Certificate unique original constraint")
        seen.add(key);r=lookup[key];value=decode(term["multiplier"])
        require(value!=0 and (r["side"]=="equal" or value>0),"Certificate multiplier sign")
        if r["side"]!="equal":weight+=value
        total=[x+value*y for x,y in zip(total,r["a"],strict=True)];bound+=value*r["b"]
    require(weight==1,"Certificate normalized inequality weights")
    require(all(x==0 for x in total),"Certificate exact zero coefficient sum")
    require(bound<0,"Certificate strictly negative bound")
    return dict(verified=True,arithmetic="exact rational arithmetic on decoded binary64 coefficients",
        contradiction=encode(bound),contradiction_float=float(bound),inequality_weight_sum=encode(weight),
        coefficient_sum_exactly_zero=True,variables=n,constraint_rows=len(problem["A"]),
        terms=len(seen),scope="infeasibility of this exact finite encoded constraint system only")

def settings():
    return dict(candidate_slack_max=1e-6,objective_scale=1e10,positive_support_threshold=1e-9,
        method="highs-ds",options=dict(presolve=True,maxiter=20000,
            primal_feasibility_tolerance=1e-10,dual_feasibility_tolerance=1e-10))

def diagnose(problem,origin):
    n,rows=canonical(problem);require(len(origin)==n,"Origin dimension")
    x=[exact(v) for v in origin];p=settings()
    slacks=[r["b"]-dot(r["a"],x) for r in rows]
    selected=[(r,s) for r,s in zip(rows,slacks,strict=True)
        if r["side"]=="equal" or s<=exact(p["candidate_slack_max"])]
    inequalities=[(r,s) for r,s in selected if r["side"]!="equal"]
    equalities=[(r,s) for r,s in selected if r["side"]=="equal"]
    ordered=inequalities+equalities;k=len(inequalities)
    report=dict(problem_sha256=digest(problem),settings=p,variables=n,constraint_rows=len(problem["A"]),
        exact_origin_minimum_inequality_slack=encode(min((s for r,s in zip(rows,slacks,strict=True)
            if r["side"]!="equal"),default=F(0))),candidate_inequalities=k,candidate_equalities=len(equalities),
        certificate=None,verification=None,exact_infeasibility_proved=False,feasibility_proved=False)
    if not k:return dict(report,status="no_candidate_inequalities")
    matrix=np.array([[float(r["a"][i]) for r,_ in ordered] for i in range(n)]+[[1.]*k+[0.]*len(equalities)])
    rhs=np.r_[np.zeros(n),1.]
    objective=np.array([float(s)*p["objective_scale"] for _,s in ordered])
    lp=linprog(objective,A_eq=matrix,b_eq=rhs,bounds=[(0,None)]*k+[(None,None)]*len(equalities),
        method=p["method"],options=p["options"])
    report["proposal"]=dict(status=int(lp.status),message=lp.message,success=bool(lp.success),
        iterations=int(lp.nit),objective=float(lp.fun) if lp.fun is not None else None,
        x=lp.x.tolist() if lp.x is not None else None,
        ordered_constraints=[dict(row=r["row"],side=r["side"]) for r,_ in ordered])
    if not lp.success:return dict(report,status="floating_support_search_inconclusive")
    indices=[i for i in range(k) if lp.x[i]>p["positive_support_threshold"]]+list(range(k,len(ordered)))
    active=[ordered[i][0] for i in indices]
    if not active:return dict(report,status="empty_support")
    exact_matrix=[[r["a"][i] for r in active] for i in range(n)]
    exact_matrix.append([F(r["side"]!="equal") for r in active])
    try:
        coefficients,rank=solve_exact(exact_matrix,[F(0)]*n+[F(1)])
        certificate=dict(problem_sha256=digest(problem),terms=[
            dict(row=r["row"],side=r["side"],multiplier=encode(v))
            for r,v in zip(active,coefficients,strict=True) if v])
        report["candidate_certificate"]=certificate;report["exact_system_rank"]=rank
        verified=verify(problem,certificate)
    except ValueError as exc:
        return dict(report,status="candidate_not_exactly_certified",candidate_error=str(exc))
    return dict(report,status="exact_infeasibility_certificate_verified",certificate=certificate,
        verification=verified,exact_infeasibility_proved=True)
