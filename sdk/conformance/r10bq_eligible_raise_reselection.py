"""One eligible support-mode reselection after the retained R10BN lift prefix.

This model-only successor may change contact modes at existing grounded sites.
It does not acquire elevated contacts or prove dynamic mode transitions.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
from types import SimpleNamespace
import numpy as np

import r10bo_velocity_field_diagnosis as O
import r10bp_cap_geometry_diagnosis as P

N, L, C, S, G, Z, I, T = O.N, O.L, O.C, O.S, O.G, O.Z, O.I, O.T
STUDY = C.ROOT/'sdk/recovery/r10bq_eligible_raise_reselection_study_v1.json'
RESULT = C.ROOT/'sdk/recovery/r10bq_eligible_raise_reselection_result_v1.json'
MAX_STEPS = 60
ELIGIBILITY_TOL = 1e-9


def eligibility(original, current):
    return (np.abs(np.array(current)[:,1]-np.array(original)[:,1]) <= ELIGIBILITY_TOL).tolist()


def restrict_modes(problem, eligible):
    for i, allowed in enumerate(eligible):
        if not allowed:
            first = problem.base+6*i
            problem.lower[first] = problem.upper[first] = 1.
            problem.lower[first+1:first+6] = problem.upper[first+1:first+6] = 0.


def phase_reference(original, current):
    # New sticking anchors are at the current horizontal positions. Original
    # contact heights, floor witnesses and joint-headroom reference survive.
    reference = copy.deepcopy(original)
    for a, b in zip(reference['original_contact_markers_m'], current['original_contact_markers_m'], strict=True):
        a[0], a[2] = b[0], b[2]
    return reference


def controls():
    checked = N.M.controls()
    original = [[0.,0.,0.]]*4
    current = [[0.,h,0.] for h in (0.,1e-9,1.001e-9,-2e-9)]
    assert eligibility(original,current) == [True,True,False,False]
    problem = SimpleNamespace(base=3,lower=np.zeros(27),upper=np.ones(27))
    restrict_modes(problem,[True,True,False,False])
    assert np.array_equal(problem.upper[15:],np.tile([1.,0.,0.,0.,0.,0.],2))
    assert np.array_equal(problem.lower[15:],np.tile([1.,0.,0.,0.,0.,0.],2))
    original = dict(original_contact_markers_m=[[1.,2.,3.]], shape_bottom_witnesses_m=[-.01], joints_rad=[.5])
    reference = phase_reference(original,dict(original_contact_markers_m=[[4.,5.,6.]]))
    assert reference == dict(original_contact_markers_m=[[4.,2.,6.]], shape_bottom_witnesses_m=[-.01], joints_rad=[.5]) and original['original_contact_markers_m'] == [[1.,2.,3.]]
    checked['additional_height_eligibility_binary_force_exclusion_and_global_reference_controls'] = 4
    return checked


def declare():
    old = C.read(P.STUDY)
    record = dict(schema_version='sporespore_r10bq_eligible_raise_reselection_study_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='engine_neutral_model_from_godot_measurements',
            authority_mode='prospective_eligible_support_mode_reselection', question_class='development'),
        source_parent_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=C.ROOT).decode().strip(),
        question='Can one height-eligible contact-mode reselection at the last admitted R10BN pose continue a bounded lift without changing geometry, solver tolerances or integration work limits?',
        dependencies=old['dependencies']+[C.bind(p) for p in [P.__file__,P.STUDY,P.RESULT,__file__]],
        population=old['population'],
        design=dict(start='Exact O.reconstruct of64 retained admitted deltas, never the unadmitted step65 probe. Prefix is inherited model evidence; zero new native steps.',
            eligibility='Only original sites whose current worldY differs from original entry by at most1e-9 m may use a nonzero contact mode. Force every other site to mode0 through binary bounds and verify the selected modes independently.',
            selection='One unchanged bounded Z.Problem search maximizing worldY torso rise. No retries, no forced different mode and no selection based on future path results. Rebuild selected continuous force/motion problem with N.M.certify_mode and check N.M.direction_check.',
            anchors='At this declared transition, sticking horizontal anchors become the current site positions. Preserve original entry contact heights,24 floor witnesses and original headroom reference. No incremental floor or height reset.',
            propagation='Fixed selected modes for at most60 additional increments with unchanged L.step and worldY objective. Stop at first refusal. Original DOP853 tolerances,2048 RHS budget, all normal/material-work and global geometry checks remain.',
            coverage='A bounded second preparatory phase, at most28.868 mm requested torso rise. No lowered airborne foot, acquired support, inertial transition, motor realization or full recovery proof.',
            retention='Fresh identity and incremental journal of search, entry verification, each admitted/refused increment and terminal summary. Full fresh-process replay; prior negatives remain immutable.'),
        numerics=dict(old['numerics'], maximum_additional_steps=MAX_STEPS, eligibility_tolerance=ELIGIBILITY_TOL),
        checks=['142 applicable inherited plus4 height eligibility, binary force exclusion and immutable-global-reference controls.',
            'Exact original prefix reconstruction; fixed-mode independent certificate and instantaneous force/material-work admission before integration.'],
        research_sources=old['research_sources'], claim_boundary=old['claim_boundary'])
    C.write_new(STUDY,record)


def derive(journal=None):
    declaration=C.read(STUDY)
    for binding in [*declaration['dependencies'],declaration['population']['report']]:assert C.bind(binding['path'])==binding
    assert np.__version__==declaration['numerics']['numpy'] and S.statics.scipy.__version__==declaration['numerics']['scipy']
    checked=controls();model,previous,replay=O.reconstruct();initial=T.snapshot(model);zero=np.zeros(14)
    _,samples=S.statics.tracking.rows();caps=[v/G.DT for v in samples[0]['caps']]
    eligible=eligibility(previous['initial']['original_contact_markers_m'],initial['original_contact_markers_m'])
    reference=phase_reference(previous['initial'],initial)
    material=T.advance(model,zero);problem=Z.Problem(material,caps,N.HEADING);restrict_modes(problem,eligible)
    search=problem.solve();verification=None;stop='eligible_mode_search_refusal';modes=None
    digest=hashlib.sha256();count=0
    def retain(value):
        nonlocal count
        line=L.journal_line(value);digest.update(line);count+=1
        if journal is not None:journal.write(line);journal.flush()
    retain(dict(kind='inputs',declaration=C.bind(STUDY),implementation=C.bind(__file__),eligible=eligible,phase_reference=reference,search=search))
    trajectory=[];accepted=0
    if search['proposal'] is not None:
        modes=search['proposal']['modes'];assert all(allow or mode==0 for allow,mode in zip(eligible,modes,strict=True))
        try:
            solution,certificate=N.M.certify_mode(problem,modes)
            mismatch=abs(certificate['maximum_raise']['primal_objective']-search['proposal']['recomputed_objective'])
            checks=N.M.direction_check(model,caps,modes,solution)
            verification=dict(physical_solution=solution.tolist(),certificate=certificate,search_objective_difference=mismatch,
                instantaneous_checks=checks,load=Z.load(model,zero,modes,caps))
            stop='entry_independent_model_check_refusal'
            allowed=mismatch<=1e-6 and checks['admitted'] and verification['load']['feasible']
        except L.VelocityRefusal as failure:
            verification=dict(refusal=failure.record);stop='entry_velocity_lp_refusal';allowed=False
        retain(dict(kind='entry_verification',value=verification))
        if allowed:
            stop='bounded_reselected_phase_horizon'
            for index in range(MAX_STEPS):
                row=L.step(model,modes,caps,N.HEADING,reference)
                for node in row['nodes']:node['vertical_progress_m']=node.pop('forward_progress_m')
                row['additional_model_step']=index+1;row['before']=T.snapshot(model);trajectory.append(row)
                if not row['admitted']:stop=row['refusal'];retain(dict(kind='model_step',value=row));break
                accepted+=1;model=I.advance(model,np.array(row['nodes'][-1]['delta']));row['after']=T.snapshot(model)
                retain(dict(kind='model_step',value=row))
                print(f'R10BQ additional step {accepted}: height {model.p["torso"][1]:.9f}, gap {model.gap(zero):.9f}',file=sys.stderr,flush=True)
    final=T.snapshot(model)
    final_load=trajectory[accepted-1]['nodes'][-1]['load'] if accepted else (verification or {}).get('load',{})
    summary=dict(inherited_model_increments=64,accepted_additional_increments=accepted,attempted_additional_increments=len(trajectory),
        stop_reason=stop,eligible_contacts=eligible,previous_modes=previous['summary']['selected_modes'],selected_modes=modes,
        initial_gap_m=initial['foot_hull_gap_m'],final_gap_m=final['foot_hull_gap_m'],
        additional_torso_rise_m=final['torso_position_m'][1]-initial['torso_position_m'][1],
        total_torso_rise_from_original_entry_m=final['torso_position_m'][1]-previous['initial']['torso_position_m'][1],
        final_minimum_nonfoot_weight_fraction=final_load.get('minimum_nonfoot_weight_fraction'),
        total_integrator_rhs_calls=sum(row['rhs_calls'] for row in trajectory),complete_transfer_or_rise_proven=False)
    retain(dict(kind='terminal_summary',value=summary))
    return dict(schema_version='sporespore_r10bq_eligible_raise_reselection_result_v1',ledger_scope=declaration['ledger_scope'],
        declaration=C.bind(STUDY),implementation=C.bind(__file__),controls=checked,entry_contact_replay=replay,
        initial=initial,final=final,phase_reference=reference,search=search,fixed_mode_verification=verification,
        summary=summary,trajectory=trajectory,journal=dict(line_count=count,raw_sha256='sha256:'+digest.hexdigest()),**declaration['claim_boundary'])


def audit():
    result=C.read(RESULT);assert result==derive();return L.present(result,True)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    for option in ('create','controls','declare'):parser.add_argument('--'+option,action='store_true')
    parser.add_argument('--journal');args=parser.parse_args()
    if args.declare:declare();print('R10BQ prospective declaration created')
    elif args.controls:print(json.dumps(controls(),indent=2))
    elif args.create:
        if not args.journal:parser.error('--create requires a fresh durable --journal path')
        path=Path(args.journal).resolve();assert path.is_relative_to(C.EVIDENCE.resolve()) and not RESULT.exists()
        with path.open('xb') as journal:result=derive(journal)
        C.write_new(RESULT,result);print(json.dumps(L.present(result,False),indent=2))
    else:print(json.dumps(audit(),indent=2))
