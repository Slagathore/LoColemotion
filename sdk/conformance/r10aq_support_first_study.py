"""One prospectively declared support-first law on retained R10AP inputs only.

Foot hulls and body bottoms are geometric diagnostics, not force balance,
contact authority, collision-free paths, or predictions of physical recovery.
"""
import argparse
from collections import Counter
import json
import math
from pathlib import Path

import r10ap_load_tracking_diagnosis as tracking
import r10ao_progressive_headroom_study as prior
import r10an_support_transfer_study as envelope
import r10af_contact_frame_replay as replay

C, G, M = tracking.C, tracking.G, prior.M
STUDY=C.ROOT/'sdk/recovery/r10aq_support_first_study_v1.json'
RESULT=C.ROOT/'sdk/recovery/r10aq_support_first_result_v1.json'
EPS=1e-12


def bottoms(m,position,rotation,targets):
    """Compiled box and capsule support heights in the ideal rigid FK model."""
    axes=[G.rotate(rotation,v) for v in ([1.,0.,0.],[0.,1.,0.],[0.,0.,1.])]
    half=[.25*m.d['torso_length_scale'],.06,.16*m.d['torso_width_scale']]
    values=[position[1]-sum(abs(axes[i][1])*half[i] for i in range(3))]
    for i in range(4):
        h,k=targets[2*i:2*i+2]
        hip=m.hip(i)
        knee=M.G.add(hip,[m.upper*math.sin(h),-m.upper*math.cos(h),0.])
        foot=M.G.add(knee,[m.lower*math.sin(h+k),-m.lower*math.cos(h+k),0.])
        ys=[position[1]+G.rotate(rotation,v)[1] for v in (hip,knee,foot)]
        values.extend([min(ys[:2])-.0225,min(ys[1:])-.04*m.d['foot_radius_scale']])
    return values


def floor_allowed(before,after):
    return all(a>=min(0.,b)-EPS for a,b in zip(after,before,strict=True))


def gap(m,position,rotation,targets):
    com=M.G.add(position,G.rotate(rotation,m.com_local))
    feet=[M.G.add(position,G.rotate(rotation,v)) for v in G.fk(m.d,targets)]
    return envelope.envelope(com,feet)['distance_m']


def select(m):
    before=prior.deficits(m.measured)
    initial_gap=gap(m,m.p,m.q,m.measured)
    outside=initial_gap>EPS
    floors=bottoms(m,m.p,m.q,m.measured)
    counts=dict(candidates=0,geometric=0,headroom=0,height=0,floor=0,support=0)
    if m.floor is None:
        return dict(counts=counts,selected=None,refusal='no_positive_bearing_plane',initial_gap_m=initial_gap)
    cost=envelope.cost(m,m.p,m.q,m.feet,True)
    best=(initial_gap,max(before),sum(before),cost) if outside else (max(before),sum(before),cost)
    selected=None
    for p in prior.candidates(m):
        counts['candidates']+=1
        if p is None:continue
        counts['geometric']+=1
        after=prior.deficits(p['targets'])
        if not all(prior.allowed(before,after)):continue
        counts['headroom']+=1
        if outside and p['translation'][1]>EPS:continue
        counts['height']+=1
        position=M.G.add(m.p,p['translation']);rotation=M.G.blend(m.q,m.flat,p['blend'])
        clearance=bottoms(m,position,rotation,p['targets'])
        if not floor_allowed(floors,clearance):continue
        counts['floor']+=1
        new_gap=gap(m,position,rotation,p['targets'])
        if outside and not new_gap<initial_gap-EPS:continue
        counts['support']+=1
        rank=(new_gap,max(after),sum(after),p['cost']) if outside else (max(after),sum(after),p['cost'])
        if prior.less(rank,best):
            best=rank
            selected=dict(**p,mode='support_first_recenter' if outside else 'supported_raise',
                proposed_gap_m=new_gap,initial_body_bottoms_m=floors,proposed_body_bottoms_m=clearance,
                deficits_before_rad=before,deficits_after_rad=after)
    assert counts['candidates']==90
    if selected is not None:
        # Reuse the independent FK bound checks, but the old cost/headroom rank
        # is deliberately not the authority for this distinct support-first law.
        position=M.G.add(m.p,selected['translation']);rotation=M.G.blend(m.q,m.flat,selected['blend'])
        endpoints=[M.G.add(position,G.rotate(rotation,v)) for v in G.fk(m.d,selected['targets'])]
        errors=[]
        for i,bearing in enumerate(m.bearing):
            if bearing:
                errors.append(math.dist(endpoints[i],m.feet[i]));assert errors[-1]<=M.LATERAL+EPS
            else:
                assert endpoints[i][1]<=m.feet[i][1]+EPS
                assert math.dist(G.fk(m.d,selected['targets'])[i],G.fk(m.d,m.measured)[i])<=.1*G.DT+EPS
        assert all(abs(t)<=lim and abs(t-q)<=4*G.DT+EPS for t,q,lim in zip(selected['targets'],m.measured,prior.LIMITS,strict=True))
        assert all(prior.allowed(before,prior.deficits(selected['targets'])))
        assert floor_allowed(floors,bottoms(m,position,rotation,selected['targets']))
        assert not outside or selected['translation'][1]<=EPS and selected['proposed_gap_m']<initial_gap-EPS
        selected['maximum_anchor_error_m']=max(errors,default=0.)
    refusal=None if selected else next((name for key,name in (
        ('geometric','no_geometric_candidate'),('headroom','no_headroom_progress_candidate'),
        ('height','no_nonascending_candidate'),('floor','no_nonworsening_floor_candidate'),
        ('support','no_support_progress_candidate')) if not counts[key]),'no_improving_rank')
    return dict(counts=counts,selected=selected,refusal=refusal,initial_gap_m=initial_gap)


def controls():
    checked={**envelope.controls(),**prior.controls()}
    tests=[floor_allowed([-0.01,0.02],[-0.005,0.]),not floor_allowed([-0.01,0.02],[-0.011,0.]),
        not floor_allowed([-0.01,0.02],[-0.005,-0.001]),floor_allowed([0.,0.],[0.,0.])]
    class Model:
        d=dict(torso_length_scale=1.,torso_width_scale=1.,foot_radius_scale=1.)
        upper=lower=.175
        def hip(self,i):return [.2 if i<2 else -.2,0.,-.18 if i%2==0 else .18]
    identity=dict(x=0.,y=0.,z=0.,w=1.)
    b=bottoms(Model(),[0.,.4,0.],identity,[0.]*8)
    expected=[.34]+[.2025,.01]*4
    tests.append(all(math.isclose(x,y,abs_tol=EPS) for x,y in zip(b,expected,strict=True)))
    moved=bottoms(Model(),[10.,.5,-7.],identity,[0.]*8)
    tests.append(all(math.isclose(x+.1,y,abs_tol=EPS) for x,y in zip(b,moved,strict=True)))
    assert all(tests);checked['floor_guard_and_shape_known_answer_controls']=len(tests)
    return checked


def derive():
    study=C.read(STUDY)
    for b in [*study['dependencies'],study['population']['report']]:assert C.bind(b['path'])==b
    checked=controls()
    descriptor,samples=tracking.rows();indexed={r['semantic_step']:r for r in samples}
    contacts=[];contact_count=0
    for record in G.records(C.CHILD/'worker_report.json','r10af_contact_frames','records'):
        packet=record['packet'];row=indexed.get(packet['semantic_step'])
        if row is None:continue
        verified=replay.replay(packet,packet['semantic_step'],packet['model_instance_id'],packet['body_population_instance_sha256'])
        assert verified['ok'];contact_count+=verified['matched_source_contacts']
        positive=[p for p in packet['contact_source_receipt']['ordered_contact_samples'] if p['normal_impulse_ns']>0]
        total=sum(p['normal_impulse_ns'] for p in positive);nonfoot=sum(p['normal_impulse_ns'] for p in positive if not p['classified_as_foot'])
        sets=dict(all_cap_centers=row['measured_cap_centers'],
            actual_foot_contacts=[G.vector(p['position_world_m']) for p in positive if p['classified_as_foot']],
            actual_all_body_contacts=[G.vector(p['position_world_m']) for p in positive])
        contacts.append(dict(partial_step=row['partial_step'],envelopes={k:envelope.envelope(row['com'],v) for k,v in sets.items()},
            total_normal_impulse_ns=total,nonfoot_normal_impulse_ns=nonfoot,nonfoot_impulse_fraction=nonfoot/total if total else None))
    rows=[]
    for packet in G.records(C.CHILD/'worker_report.json','r10ap_partial_recovery','step_packets'):
        n=packet['native_receipt'];original=n['next_load_plan']
        if original is None:continue
        m=M.G.Model(n['collection']['observation'],descriptor)
        reconstructed=prior.search(m);geometry=original['progressive_headroom_geometry']
        plan=reconstructed['selected']
        assert reconstructed['candidates']==geometry['candidate_count']
        assert reconstructed['refusal']==geometry['hold_reason']
        if plan:
            assert max(abs(a-b) for a,b in zip(plan['targets'],geometry['ordered_target_positions_rad'],strict=True))<1e-12
            assert plan['mode']==original['mode']
        result=select(m)
        rows.append(dict(semantic_step=n['collection']['observation']['semantic_step'],**result))
    assert len(rows)==600 and len(contacts)==601
    selected=[r['selected'] for r in rows if r['selected']]
    contact_summary={name:dict(inside=sum(r['envelopes'][name]['inside'] for r in contacts),
        empty=sum(r['envelopes'][name]['distance_m'] is None for r in contacts),
        distance_m=G.stats([r['envelopes'][name]['distance_m'] for r in contacts if r['envelopes'][name]['distance_m'] is not None])) for name in contacts[0]['envelopes']}
    summary=dict(selected=len(selected),refusals=dict(Counter(r['refusal'] for r in rows if r['refusal'])),
        modes=dict(Counter(p['mode'] for p in selected)),
        counts={k:sum(r['counts'][k] for r in rows) for k in rows[0]['counts']},
        gap_reduction_m=G.stats([r['initial_gap_m']-r['selected']['proposed_gap_m'] for r in rows if r['selected']]),
        upward_proposals=sum(p['translation'][1]>EPS for p in selected))
    return dict(schema_version='sporespore_r10aq_support_first_result_v1',ledger_scope=study['ledger_scope'],
        study=C.bind(STUDY),implementation=C.bind(__file__),controls=checked,original_native_plan_reconstructions=600,
        independently_replayed_partial_contacts=contact_count,contact_summary=contact_summary,
        nonfoot_impulse_fraction=G.stats([r['nonfoot_impulse_fraction'] for r in contacts if r['nonfoot_impulse_fraction'] is not None]),
        summary=summary,contacts=contacts,rows=rows,**study['claim_boundary'])


def audit():
    record=C.read(RESULT);assert record==derive()
    return dict(ok=True,**{k:record[k] for k in ('controls','summary','contact_summary','nonfoot_impulse_fraction')},
        world_build_count=0,solver_step_count=0,physical_acceptance_authority=False,release_authority=False)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--create',action='store_true')
    args=parser.parse_args()
    if args.create:C.write_new(RESULT,derive())
    print(json.dumps(audit(),indent=2))
