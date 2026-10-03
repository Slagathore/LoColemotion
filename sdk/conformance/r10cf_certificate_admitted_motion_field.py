"""Prospective solved-status policy with unchanged independent QP certificates.

R10CE's strict Solved-only refusals remain immutable. This successor explicitly
permits Solved or AlmostSolved only together with the original full certificate.
Neither internal nor independent tolerances, matrices or objectives change.
"""
import argparse
import json
import subprocess
import numpy as np

import r10ce_clarabel_motion_field as E

C,K,S,L = E.C,E.K,E.S,E.L
STUDY=C.ROOT/'sdk/recovery/r10cf_certificate_admitted_motion_field_study_v1.json'
RESULT=C.ROOT/'sdk/recovery/r10cf_certificate_admitted_motion_field_result_v1.json'
STATUSES=('Solved','AlmostSolved')


def eligible(status,certificate):
    return bool(status in STATUSES and (certificate or {}).get('accepted') is True)


def admit_record(record):
    answer=record['quadratic_result']
    if answer is None:return record
    answer['status_and_certificate_eligible']=eligible(answer['status'],answer['certificate'])
    answer['accepted']=answer['status_and_certificate_eligible']
    record['accepted']=bool(answer['accepted'] and (record['primary_certificate'] or {}).get('accepted') is True)
    if record['accepted']:
        x=np.array(answer['solution']);p=record['quadratic_problem']
        # The final QP row is c*x/scale <= .99*primary_optimum/scale.
        fraction=.99*float(np.array(p['inequality'][-1])@x)/p['inequality_rhs'][-1]
        record.update(normalized_velocity=x.tolist(),velocity=(x*S.MAXIMUM).tolist(),achieved_progress_fraction=fraction)
    return record


def quadratic_direction(problem):
    return admit_record(E.quadratic_direction(problem))


def velocity(model,modes,heading):
    record=quadratic_direction(E.E.problem(model,modes,heading))
    if not record['accepted']:raise L.VelocityRefusal(dict(stage='certificate_admitted_quadratic_motion',diagnostic=record))
    certificate=dict(record['quadratic_result']['certificate'],qp_status=record['quadratic_result']['status'],
        qp_status_rule='solved_or_almost_solved_with_full_independent_certificate')
    return np.array(record['velocity']),dict(maximum_progress=record['primary_certificate'],minimum_normalized_motion=certificate)


def status_controls():
    for status in ('Solved','AlmostSolved','PrimalInfeasible','DualInfeasible','MaxIterations','NumericalError'):
        for proof in (True,False):
            assert eligible(status,dict(accepted=proof)) == (status in STATUSES and proof)
    return 12


def controls():
    checked=E.controls();checked['additional_solver_status_and_independent_certificate_truth_table_controls']=status_controls()
    return checked


def declare():
    prior=C.read(E.STUDY)
    C.write_new(STUDY,dict(schema_version='sporespore_r10cf_certificate_admitted_motion_field_study_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='engine_neutral_model_from_godot_measurements',
            authority_mode='prospective_solved_like_status_plus_independent_certificate',question_class='development'),
        source_parent_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=C.ROOT).decode().strip(),
        question='Does an explicit Solved-or-AlmostSolved rule with unchanged full independent certificates qualify the pinned quadratic selector on all59 declared poses?',
        dependencies=prior['dependencies']+[C.bind(p) for p in [E.__file__,E.STUDY,E.RESULT,__file__]],population=prior['population'],
        design=dict(change='Accept status Solved or AlmostSolved only if the complete original-matrix QP certificate passes. Keep the raw strict solver-success field and actual status. Infeasibility, iteration-limit and numerical-error statuses remain ineligible.',
            unchanged='Exactly R10CE solver/binary/settings, primary portfolio,99% progress requirement, squared-motion objective and every original row/bound. The independent1e-6 certificate remains unchanged; later physical geometry/work gates remain separate and unchanged.',
            reproduction='Run the complete original R10CE derivation afresh and require exact equality to its immutable result before applying this new declared status policy to the new result only.',
            boundary='R10CE stays a valid negative under its Solved-only rule. This is a distinct model-selector qualification, not regraded old evidence or a physical success. No integration or native world.',
            retention='Retain all old raw statuses, certificates, solutions and inputs under the successor rule, with full cold replay.'),
        numerics=dict(prior['numerics'],eligible_statuses=list(STATUSES)),
        checks=['190 inherited plus12 status/certificate truth-table checks;202 with shared coverage.','Exact original solver-result reproduction and complete successor cold replay.'],
        research_sources=prior['research_sources'],claim_boundary=prior['claim_boundary']))


def derive():
    declaration=C.read(STUDY)
    for binding in declaration['dependencies']:assert C.bind(binding['path'])==binding
    result=E.derive();assert result==C.read(E.RESULT)
    result['controls']['additional_solver_status_and_independent_certificate_truth_table_controls']=status_controls()
    for row in result['probes']:admit_record(row['quadratic'])
    reference=result['probes'][2]['quadratic'];sensitivity=[]
    if reference['accepted']:
        x=np.array(reference['normalized_velocity'])
        for scale in E.E.SCALES:
            passing=[row for row in result['probes'][3:] if row['specification']['scale']==scale and row['quadratic']['accepted']]
            sensitivity.append(dict(scale=scale,certified_probes=len(passing),maximum_normalized_velocity_change=max((float(np.max(np.abs(np.array(row['quadratic']['normalized_velocity'])-x))) for row in passing),default=None)))
    result['summary']['variants']['quadratic']=dict(certified_poses=sum(row['quadratic']['accepted'] for row in result['probes']),sensitivity=sensitivity)
    result.update(schema_version='sporespore_r10cf_certificate_admitted_motion_field_result_v1',ledger_scope=declaration['ledger_scope'],
        declaration=C.bind(STUDY),implementation=C.bind(__file__),original_solver_result=C.bind(E.RESULT))
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    for flag in ('declare','controls','create'):parser.add_argument('--'+flag,action='store_true')
    args=parser.parse_args()
    if args.declare:declare();print('R10CF prospective declaration created')
    elif args.controls:print(json.dumps(controls(),indent=2))
    elif args.create:
        assert not RESULT.exists();result=derive();C.write_new(RESULT,result);print(json.dumps(E.W.T.present(result,False),indent=2))
    else:
        result=C.read(RESULT);assert result==derive();print(json.dumps(E.W.T.present(result,True),indent=2))
