"""Retain and audit the exact R10AL one-step geometry population."""
import argparse
from collections import Counter
import json
import math
from pathlib import Path

import r10aj_hip_recenter_closure as closure
import r10al_support_anchored_model as kernel

CONTRACT=closure.ROOT/'sdk/recovery/r10al_support_anchored_leveling_study_v1.json'
RECORD=closure.ROOT/'sdk/recovery/r10al_support_anchored_leveling_result_v1.json'


def derive():
    contract=closure.read(CONTRACT);path=Path(contract['population']['report'])
    assert closure.bind(path)['raw_sha256']==contract['population']['raw_sha256']
    for item in contract['dependencies']:
        actual=closure.bind(closure.ROOT/item['path']);actual['path']=item['path'];assert actual==item
    descriptor=closure.streams.small_fields(path)['configuration']['base_descriptor'];rows=[]
    for packet in closure.geometry.records(path,'r10aj_partial_recovery','step_packets'):
        native=packet['native_receipt'];original=native['next_load_plan']
        if original is None:continue
        observation=native['collection']['observation'];model=kernel.G.Model(observation,descriptor)
        result=kernel.search(model);plan=result['selected']
        if plan:
            # Separate FK implementation verifies the complete pose-plus-joint result.
            position=kernel.G.add(model.p,plan['translation']);rotation=kernel.G.blend(model.q,model.flat,plan['blend'])
            feet=[kernel.G.add(position,kernel.G.rotate(rotation,f)) for f in closure.geometry.fk(descriptor,plan['targets'])]
            for i,foot in enumerate(feet):
                if model.bearing[i]:assert math.dist(foot,model.feet[i])<=kernel.LATERAL+1e-12
                else:assert foot[1]<=model.feet[i][1]+1e-12
        row=dict(partial_step=native['step']['memory']['total_steps_observed'],semantic_step=observation['semantic_step'],
            source_observation_sha256=original['source_observation_sha256'],original_mode=original['mode'],
            positive_bearing=model.bearing,qualified_support=model.qualified,
            measured_torso_up=kernel.G.rotate(model.q,[0.,1.,0.])[1],result=result)
        assert row['partial_step']==len(rows)+1;rows.append(row)
    assert len(rows)==contract['population']['expected_samples']==600
    selected=[r for r in rows if r['result']['selected']]
    summary=dict(samples=600,selected=len(selected),refusals=dict(Counter(r['result']['refusal'] for r in rows if not r['result']['selected'])),
        total_candidates=sum(r['result']['candidates'] for r in rows),feasible_candidates=sum(r['result']['feasible'] for r in rows),
        selected_leveling=sum(r['result']['selected']['blend']>0 for r in selected),
        selected_with_unqualified_support=sum(not all(r['qualified_support']) for r in selected),
        maximum_anchor_error_m=max((r['result']['selected']['verification']['maximum_anchor_error_m'] for r in selected),default=0.),
        minimum_torso_up_change=min((r['result']['selected']['verification']['torso_up_change'] for r in selected),default=None),
        first_refusal_partial_step=next((r['partial_step'] for r in rows if not r['result']['selected']),None))
    return dict(schema_version='sporespore_r10al_support_anchored_leveling_result_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='engine_neutral_geometry',authority_mode='retained_input_model_result',question_class='development'),
        auditor=closure.bind(__file__),contract=closure.bind(CONTRACT),
        dependencies=[closure.bind(p) for p in (Path(kernel.__file__),Path(kernel.G.__file__),Path(closure.geometry.__file__),Path(closure.__file__))],
        source_report=closure.bind(path),original_source_commit=closure.HEAD,original_result_regraded=False,
        summary=summary,rows=rows,
        interpretation='Selected targets satisfy declared single-step geometry constraints on exposed inputs. '
            'Refusals are retained, not replaced with fallback targets. No dynamics, closed-loop progress, native tracking, '
            'load restoration or recovery conclusion follows. Controller selection remains open.',
        **contract['claim_boundary'])


def audit():
    record=closure.read(RECORD);assert record==derive()
    return dict(ok=True,summary=record['summary'],controller_selected=False,world_build_count=0,solver_step_count=0,
        physical_acceptance_authority=False,release_authority=False)


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--create',action='store_true');args=parser.parse_args()
    if args.create:closure.write_new(RECORD,derive())
    print(json.dumps(audit(),indent=2))
