"""Independent finite geometry reconstruction for the compiled AI kernel."""
import math

import r10ab_loaded_rise_diagnosis as geometry


def search(observation, descriptor):
    model=geometry.Model(observation,descriptor)
    deficit=[max(0.,min(1.,(geometry.THRESHOLD-(v if b else 0.))/geometry.THRESHOLD))
        for v,b in zip(model.impulses,model.bearing)]
    # Retain the plane computed from positive native bearing observations;
    # the added weak-foot penalty uses the stricter unchanged load threshold.
    model.bearing=model.qualified[:]
    if model.floor is None:
        return dict(selected=None,feasible=0,model=model,deficit=deficit)
    best=model.cost(model.p,model.q,model.feet);selected=None;feasible=0
    for scale in geometry.SCALES:
        distance=.1*geometry.DT*scale
        for dx in (-distance,0.,distance):
            for dy in (-distance,0.,distance):
                for fraction in (-.6*geometry.DT*scale,0.,.6*geometry.DT*scale):
                    delta=[dx*math.cos(model.yaw),dy,-dx*math.sin(model.yaw)]
                    position=geometry.add(model.p,delta);rotation=geometry.blend(model.q,model.flat,fraction)
                    feet=[f[:] for f in model.feet]
                    for i in range(4):feet[i][1]-=distance*deficit[i]
                    solved=model.solve(feet,position,rotation)
                    if solved is None:continue
                    feasible+=1;joints,residual=solved;cost=model.cost(position,rotation,feet)
                    if cost < best-1e-12:
                        best=cost;selected=dict(scale=scale,translation=delta,blend=fraction,targets=joints,
                            residual=residual,cost=cost,desired_endpoints=feet)
    return dict(selected=selected,feasible=feasible,model=model,deficit=deficit)


def verify(observation, descriptor, plan):
    result=search(observation,descriptor);native=plan['concurrent_geometry'];selected=result['selected']
    assert result['feasible']==native['feasible_candidate_count']
    assert max(abs(a-b) for a,b in zip(result['deficit'],native['load_deficit_fraction']))<1e-12
    if selected is None:
        assert plan['mode']=='explicit_v23_fallback'
        assert plan['ordered_target_positions_rad']==plan['baseline_reference']['ordered_target_positions_rad']
        return dict(selected=False,weak_foot_count=sum(not q for q in result['model'].qualified),maximum_endpoint_error_m=0.)
    assert plan['mode']=='concurrent_load_and_rise'
    assert selected['scale']==native['selected_candidate_scale'] and selected['blend']==native['selected_virtual_level_blend']
    assert abs(selected['cost']-native['selected_model_cost'])<1e-12
    assert max(abs(a-b) for a,b in zip(selected['targets'],plan['ordered_target_positions_rad']))<1e-10
    modeled=result['model']
    from r10af_rise_tracking_analysis import fk
    position=geometry.add(modeled.p,selected['translation']);rotation=geometry.blend(modeled.q,modeled.flat,selected['blend'])
    endpoints=[geometry.add(position,geometry.rotate(rotation,f)) for f in fk(descriptor,plan['ordered_target_positions_rad'])]
    errors=[math.dist(actual,expected) for actual,expected in zip(endpoints,selected['desired_endpoints'])]
    assert max(errors)<=.0005+1e-12
    return dict(selected=True,weak_foot_count=sum(not q for q in modeled.qualified),
        upward_virtual_torso_motion=selected['translation'][1]>0.,maximum_endpoint_error_m=max(errors))
