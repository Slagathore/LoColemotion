"""Build reviewable R10J closure/adoption records from independently audited bytes.

Print records only. Writing a repository closure, adopting the release gate,
and compiling readiness are explicit subsequent steps, never side effects.
"""
import argparse
import json
from pathlib import Path

import r10j_campaign_authority as authority
import r10j_campaign_audit as campaign
import r10j_dependency_manifest as dependencies
import r10j_qualification as qualification

PHYSICAL_CLOSURE = 'sdk/recovery/r10j_held_out_physical_closure_v1.json'
ADOPTION = 'sdk/recovery/r10j_release_gate_adoption_v1.json'


def finite_decision(audit):
    authority.require(audit.get('mode') == 'held_out_finite_decision', 'ADOPTION_REQUIRES_HELD_OUT')
    decision = campaign.decide(audit['cells'], 'held_out_finite_decision')
    authority.require(all(authority.same(audit.get(key), value) for key,value in decision.items()), 'ADOPTION_DECISION_DRIFT')
    authority.require(authority.same(audit.get('total_world_builds'), 6), 'ADOPTION_WORLD_POPULATION')
    return dict(q_sdk_r10_satisfied=decision['all_finite_tasks_passed'],
                sdk1_m07_satisfied=decision['all_finite_tasks_passed'],
                acceptance='accepted_exact_finite_tasks' if decision['all_finite_tasks_passed'] else 'not_accepted',
                population_robustness=False, arbitrary_morphology=False, cross_engine_push_recovery=False,
                force_aware_recovery=False, continuous_coverage=False, release_authority=False)


def build(root):
    root = Path(root)
    audit = campaign.audit(root, retained=True)
    mode = audit['mode']
    record = dict(schema_version='sporespore_r10j_'+('production_route_ghost_closure_v1' if mode == 'development_ghost' else 'held_out_physical_closure_v1'),
                  ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='retained_development_closure' if mode == 'development_ghost' else 'finite_physical_closure', question_class='development' if mode == 'development_ghost' else 'finite decision'),
                  source_commit=audit['source_commit'], evidence_root=root.resolve().as_posix(),
                  production_route_key=audit['production_route_key'], independent_audit=audit,
                  launcher_ok=True, independent_audit_ok=True, post_exposure_regraded=False,
                  held_out_worlds_opened=0 if mode == 'development_ghost' else 6,
                  physical_acceptance_authority=False, release_authority=False,
                  preserved_original_refusal='sdk/recovery/r10j_settled_hold_pair_closure_v1.json',
                  task_contract=authority.file_binding(authority.TASK_PATH))
    if mode == 'development_ghost':
        record.update(production_route_ghost_passed=audit['execution_valid'],
                      safety_gate=qualification.validate_gate(root, source_commit=audit['source_commit'], route_key=audit['production_route_key'], physical=True))
    else:
        record.update(decision=finite_decision(audit),
                      authority=authority.file_binding(authority.AUTHORITY_PATH),
                      preregistration=authority.file_binding(authority.PREREGISTRATION_PATH),
                      qualification=authority.file_binding(authority.QUALIFICATION_PATH),
                      population_consumed=True, retry_permitted=False, acceptance_requires_separate_adoption=True)
    return record


def adoption():
    record = authority.parse((authority.ROOT / PHYSICAL_CLOSURE).read_bytes())
    rebuilt = build(record['evidence_root'])
    authority.require(authority.same(record, rebuilt), 'ADOPTION_CLOSURE_RECONSTRUCTION')
    decision = finite_decision(record['independent_audit'])
    authority.require(decision['q_sdk_r10_satisfied'] is True, 'ADOPTION_NEGATIVE_OR_INVALID')
    key = dependencies.validate(authority.parse((authority.ROOT / authority.MANIFEST_PATH).read_bytes()))
    authority.require(key == record['production_route_key'], 'ADOPTION_FROZEN_KEY')
    return dict(schema_version='sporespore_r10j_release_gate_adoption_v1',
                ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='explicit_exact_finite_release_gate_adoption', question_class='finite decision'),
                gate_id='QSDK-R10', milestone_id='SDK1-M07', decision=decision,
                closure=authority.file_binding(PHYSICAL_CLOSURE),
                dependency_manifest=authority.file_binding(authority.MANIFEST_PATH),
                task_contract=authority.file_binding(authority.TASK_PATH),
                accepted_cell_count=6, production_route_key=key,
                scoped_behavior='Exact S169 Godot/Jolt: matched no-kick settling/continuation and native kick followed by passive descent, V20/V7 recovery, fresh V50 finite walking and settled stop at prefix phases 241, 242, 243.',
                preserved_prior_negative='balanced-wave-bw6n-validation-e44a7e2/report.json',
                prior_negative_regraded=False, development_evidence_promoted=False,
                release_authority=False, clean_room_candidate_authorized=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['closure', 'adoption'])
    parser.add_argument('--root', type=Path)
    args = parser.parse_args()
    try:
        value = build(args.root) if args.command == 'closure' else adoption()
        print(json.dumps(dict(ok=True, result=value), allow_nan=False))
    except (ValueError, OSError, KeyError, TypeError, RuntimeError) as error:
        print(json.dumps(dict(ok=False, failure_code=str(error), release_authority=False)))
        raise SystemExit(1)
