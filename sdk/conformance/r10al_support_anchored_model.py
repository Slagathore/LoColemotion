"""Bounded contact-constrained geometry; never body actuation or force prediction."""
import math
import r10ab_loaded_rise_diagnosis as G


SCALES=(1.,.5,.25,.125,.0625)
DAMPING_SQUARED=1e-4
LATERAL=0.0005


def local_foot(model,h,k):
    return [model.upper*math.sin(h)+model.lower*math.sin(h+k),
        -model.upper*math.cos(h)-model.lower*math.cos(h+k),0.]


def world_foot(model,i,joints,position,rotation):
    return G.add(position,G.rotate(rotation,G.add(model.hip(i),local_foot(model,*joints))))


def jacobian(model,h,k):
    return [[model.upper*math.cos(h)+model.lower*math.cos(h+k),model.lower*math.cos(h+k)],
        [model.upper*math.sin(h)+model.lower*math.sin(h+k),model.lower*math.sin(h+k)]]


def within(source,targets):
    return all(abs(v)<=limit and abs(v-q)<=4*G.DT+1e-12
        for q,v,limit in zip(source,targets,(1.6,1.1),strict=True))


def anchor(model,i,position,rotation):
    local=G.sub(G.rotate(G.inverse(rotation),G.sub(model.feet[i],position)),model.hip(i))
    if abs(local[2])>LATERAL:return None
    cosine=(local[0]**2+local[1]**2-model.upper**2-model.lower**2)/(2*model.upper*model.lower)
    if not -1<=cosine<=1:return None
    source=model.measured[2*i:2*i+2];best=None
    angle=math.acos(cosine)
    for knee in (angle,-angle):
        hip=math.atan2(local[0],-local[1])-math.atan2(model.lower*math.sin(knee),model.upper+model.lower*math.cos(knee))
        target=[hip,knee]
        if not within(source,target):continue
        rank=sum((a-b)**2 for a,b in zip(source,target))
        if best is None or rank<best[0]:best=(rank,target)
    return None if best is None else best[1]


def placement(model,i,position,rotation,distance):
    source=model.measured[2*i:2*i+2]
    desired=model.feet[i][:];desired[1]-=distance
    target_local=G.sub(G.rotate(G.inverse(rotation),G.sub(desired,position)),model.hip(i))
    start=local_foot(model,*source);error=G.sub(target_local,start)
    j=jacobian(model,*source)
    # J^T (J J^T + lambda^2 I)^-1 error, solved explicitly in two dimensions.
    a=sum(v*v for v in j[0])+DAMPING_SQUARED
    b=sum(x*y for x,y in zip(j[0],j[1]))
    c=sum(v*v for v in j[1])+DAMPING_SQUARED
    determinant=a*c-b*b;assert determinant>0
    solved=[(c*error[0]-b*error[1])/determinant,(-b*error[0]+a*error[1])/determinant]
    delta=[sum(j[r][k]*solved[r] for r in range(2)) for k in range(2)]
    size=max(abs(v) for v in delta)
    if size>4*G.DT:delta=[v*(4*G.DT)/size for v in delta]
    best=None
    for scale in (*SCALES,0.):
        targets=[max(-limit,min(limit,q+scale*d)) for q,d,limit in zip(source,delta,(1.6,1.1),strict=True)]
        if not within(source,targets):continue
        if math.dist(local_foot(model,*targets),start)>.1*G.DT+1e-12:continue
        endpoint=world_foot(model,i,targets,position,rotation)
        if endpoint[1]>model.feet[i][1]+1e-12:continue
        rank=sum((a-b)**2 for a,b in zip(endpoint,desired))
        if best is None or rank<best[0]:best=(rank,targets)
    return None if best is None else best[1]


def cost(model,position,rotation,endpoints):
    com=G.add(position,G.rotate(rotation,model.com_local))
    up=G.rotate(rotation,[0.,1.,0.])[1];tilt=math.acos(max(-1.,min(1.,up)))
    height_goal=model.goal_y if all(model.bearing) else model.p[1]
    return ((com[0]-model.center[0])**2+(com[2]-model.center[2])**2+
        .04*tilt*tilt+(position[1]-height_goal)**2+
        sum(max(f[1]-model.floor-.04*model.d['foot_radius_scale'],0.)**2
            for f,b in zip(endpoints,model.bearing) if not b))


def verify(model,plan):
    position=G.add(model.p,plan['translation']);rotation=G.blend(model.q,model.flat,plan['blend'])
    targets=plan['targets'];assert len(targets)==8
    assert all(within(model.measured[2*i:2*i+2],targets[2*i:2*i+2]) for i in range(4))
    endpoints=[world_foot(model,i,targets[2*i:2*i+2],position,rotation) for i in range(4)]
    up=G.rotate(rotation,[0.,1.,0.])[1]
    assert up>=G.rotate(model.q,[0.,1.,0.])[1]-1e-12
    for i,bearing in enumerate(model.bearing):
        if bearing:assert math.dist(endpoints[i],model.feet[i])<=LATERAL+1e-12
        else:
            assert endpoints[i][1]<=model.feet[i][1]+1e-12
            assert math.dist(local_foot(model,*targets[2*i:2*i+2]),
                local_foot(model,*model.measured[2*i:2*i+2]))<=.1*G.DT+1e-12
    assert plan['cost']<cost(model,model.p,model.q,model.feet)-1e-12
    return dict(maximum_anchor_error_m=max((math.dist(a,b) for a,b,loaded in
        zip(endpoints,model.feet,model.bearing) if loaded),default=0.),
        unsupported_dy_m=[None if model.bearing[i] else endpoints[i][1]-model.feet[i][1] for i in range(4)],
        torso_up_change=up-G.rotate(model.q,[0.,1.,0.])[1])


def search(model):
    if not all(math.isfinite(v) for v in (*model.p,*model.q.values(),*model.measured)):
        raise ValueError('R10AL_NONFINITE_INPUT')
    if abs(sum(v*v for v in model.q.values())-1.)>1e-5:raise ValueError('R10AL_QUATERNION')
    if model.floor is None:return dict(candidates=0,feasible=0,selected=None,refusal='no_positive_bearing_plane')
    initial=cost(model,model.p,model.q,model.feet);best=initial;selected=None;feasible=0;count=0
    for scale in SCALES:
        distance=.1*G.DT*scale
        for dx in (-distance,0.,distance):
            for dy in (-distance,0.,distance):
                for blend in (0.,.6*G.DT*scale):
                    count+=1;translation=[dx*math.cos(model.yaw),dy,-dx*math.sin(model.yaw)]
                    position=G.add(model.p,translation);rotation=G.blend(model.q,model.flat,blend)
                    if G.rotate(rotation,[0.,1.,0.])[1]<G.rotate(model.q,[0.,1.,0.])[1]-1e-12:continue
                    joints=[]
                    for i,bearing in enumerate(model.bearing):
                        target=anchor(model,i,position,rotation) if bearing else placement(model,i,position,rotation,distance)
                        if target is None:break
                        joints.extend(target)
                    if len(joints)!=8:continue
                    endpoints=[world_foot(model,i,joints[2*i:2*i+2],position,rotation) for i in range(4)]
                    feasible+=1;value=cost(model,position,rotation,endpoints)
                    if value<best-1e-12:
                        best=value;selected=dict(scale=scale,translation=translation,blend=blend,targets=joints,cost=value)
    assert count==90
    if selected is not None:selected['verification']=verify(model,selected)
    return dict(candidates=count,feasible=feasible,initial_cost=initial,selected=selected,
        refusal=None if selected else ('no_feasible_candidate' if not feasible else 'no_cost_decreasing_candidate'))
