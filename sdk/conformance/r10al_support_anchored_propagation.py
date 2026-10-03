"""Bounded ideal-state propagation of the frozen R10AL geometry search."""
import argparse
import copy
import json
import math
from pathlib import Path
import r10al_support_anchored_study as study

closure,kernel=study.closure,study.kernel
CONTRACT=closure.ROOT/'sdk/recovery/r10al_support_anchored_propagation_study_v1.json'
RECORD=closure.ROOT/'sdk/recovery/r10al_support_anchored_propagation_result_v1.json'


def advance(model,plan):
    out=copy.copy(model);out.o=None
    out.p=kernel.G.add(model.p,plan['translation']);out.q=kernel.G.blend(model.q,model.flat,plan['blend'])
    out.measured=plan['targets'][:]
    out.com=kernel.G.add(out.p,kernel.G.rotate(out.q,out.com_local))
    out.feet=[out.foot(i,out.measured) for i in range(4)]
    forward=kernel.G.rotate(out.q,[1.,0.,0.]);out.yaw=math.atan2(-forward[2],forward[0])
    out.flat=dict(x=0.,y=math.sin(out.yaw*.5),z=0.,w=math.cos(out.yaw*.5))
    out.center=[sum(f[i] for f in out.feet)/4 for i in range(3)]
    return out


def snapshot(model,initial,step):
    return dict(update=step,torso_up=kernel.G.rotate(model.q,[0.,1.,0.])[1],
        torso_position=model.p,height_goal_gap_m=model.goal_y-model.p[1],
        maximum_anchor_drift_m=max((math.dist(a,b) for a,b,loaded in zip(model.feet,initial,model.bearing) if loaded),default=0.),
        unsupported_cap_clearance_m=[None if loaded else f[1]-model.floor-.04*model.d['foot_radius_scale']
            for f,loaded in zip(model.feet,model.bearing)])


def propagate(model):
    model=copy.deepcopy(model);model.o=None;initial=copy.deepcopy(model.feet)
    snapshots=[snapshot(model,initial,0)];plans=[];refusal=None
    for step in range(600):
        result=kernel.search(model)
        if result['selected'] is None:refusal=result['refusal'];break
        plan=result['selected'];plans.append(plan);model=advance(model,plan)
        if len(plans)%60==0:snapshots.append(snapshot(model,initial,len(plans)))
    final=snapshot(model,initial,len(plans))
    return dict(updates=len(plans),stop=refusal or 'declared_600_update_bound',final=final,
        snapshots=snapshots,plans=plans,positive_bearing_mask=model.bearing,qualified_support_mask=model.qualified)


def derive():
    contract=closure.read(CONTRACT)
    for item in contract['dependencies']:
        actual=closure.bind(closure.ROOT/item['path']);actual['path']=item['path'];assert actual==item
    path=Path(contract['population']['source_report']);assert closure.bind(path)['raw_sha256']==contract['population']['raw_sha256']
    descriptor=closure.streams.small_fields(path)['configuration']['base_descriptor'];starts={}
    for packet in closure.geometry.records(path,'r10aj_partial_recovery','step_packets'):
        native=packet['native_receipt']
        if native['next_load_plan'] is None:continue
        model=kernel.G.Model(native['collection']['observation'],descriptor)
        name='all_bearing' if all(model.bearing) else ('rear_bearing_only' if model.bearing==[False,False,True,True] else None)
        if name and name not in starts:
            starts[name]=dict(partial_step=native['step']['memory']['total_steps_observed'],result=propagate(model))
        if len(starts)==2:break
    assert set(starts)=={'all_bearing','rear_bearing_only'}
    return dict(schema_version='sporespore_r10al_support_anchored_propagation_result_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='engine_neutral_geometry',authority_mode='bounded_model_propagation_result',question_class='development'),
        auditor=closure.bind(__file__),contract=closure.bind(CONTRACT),
        dependencies=[closure.bind(p) for p in (Path(kernel.__file__),Path(kernel.G.__file__),Path(study.__file__))],
        source_report=closure.bind(path),starts=starts,
        interpretation='These are ideal-state geometric trajectories with frozen contacts, not physical rollouts. '
            'Goal gaps, refusals and modeled penetrations remain diagnostic. No standing, support or recovery result is inferred.',
        **contract['claim_boundary'])


def audit():
    record=closure.read(RECORD);assert record==derive()
    return dict(ok=True,starts={name:dict(partial_step=row['partial_step'],updates=row['result']['updates'],
        stop=row['result']['stop'],final=row['result']['final']) for name,row in record['starts'].items()},
        world_build_count=0,solver_step_count=0,physical_acceptance_authority=False,release_authority=False)


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--create',action='store_true');args=parser.parse_args()
    if args.create:closure.write_new(RECORD,derive())
    print(json.dumps(audit(),indent=2))
