"""Build reviewable R10W closure/adoption records from independently audited bytes.

Print records only. Writing a repository closure, adopting the release gate,
and compiling readiness are explicit subsequent steps, never side effects.
"""
import argparse
import json
from pathlib import Path

import r10w_campaign_authority as authority
import r10w_campaign_audit as campaign
import r10w_dependency_manifest as dependencies
import r10w_qualification as qualification

PHYSICAL_CLOSURE = 'sdk/recovery/r10w_held_out_physical_closure_v1.json'
ADOPTION = 'sdk/recovery/r10w_release_gate_adoption_v1.json'


def finite_decision(audit):
    authority.require(audit.get('mode') == 'held_out_finite_decision', 'ADOPTION_REQUIRES_HELD_OUT')
    decision = campaign.decide(audit['cells'], 'held_out_finite_decision')
    authority.require(all(authority.same(audit.get(key), value) for key,value in decision.items()), 'ADOPTION_DECISION_DRIFT')
    if decision['execution_valid']:
        authority.require(authority.same(audit.get('total_world_builds'), 6), 'ADOPTION_WORLD_POPULATION')
    return dict(q_sdk_r10_satisfied=decision['all_finite_tasks_passed'],
                sdk1_m07_satisfied=decision['all_finite_tasks_passed'],
                acceptance='accepted_exact_finite_tasks' if decision['all_finite_tasks_passed'] else 'not_accepted',
                population_robustness=False, arbitrary_morphology=False, cross_engine_push_recovery=False,
                force_aware_recovery=False, continuous_coverage=False, release_authority=False)



def development_coverage(audit):
    """Only the fresh pair including upright bounded hold qualifies this campaign."""
    authority.require(audit.get('mode') == 'development_ghost', 'GHOST_MODE')
    decision = campaign.decide(audit['cells'], 'development_ghost')
    authority.require(all(authority.same(audit.get(key), value) for key, value in decision.items())
        and decision['all_finite_tasks_passed'] is True, 'GHOST_VALID_POSITIVE_REQUIRED')
    authority.require(authority.same(audit.get('total_world_builds'), 2), 'GHOST_WORLD_POPULATION')
    expected = authority.population('development_ghost')
    authority.require(all(authority.same(cell.get('seed'), spec['seed']['seed'])
        and cell.get('role') == spec['role'] for cell, spec in zip(audit['cells'], expected)), 'GHOST_IDENTITY')
    branches = [cell.get('entry_kind') for cell in audit['cells']]
    authority.require(branches == ['unselected', 'upright'], 'GHOST_BRANCH_COVERAGE')
    authority.require(audit['cells'][1].get('post_recovery_handoff') == 'bounded_hold', 'GHOST_HOLD_COVERAGE')
    return dict(no_kick=True, upright_bounded_hold=True)


def original_workflow(root):
    """Bind the original host terminal; a positive cell report is insufficient."""
    root=Path(root)
    supervisor=qualification.files.read(root/'supervisor_result.json')
    context=supervisor.get('r10w_host')
    authority.require(type(context) is dict,'CLOSURE_ORIGINAL_HOST_MISSING')
    request=Path(context['request']['path'])
    authority.require(qualification.files.bind(request)==context['request'],'CLOSURE_REQUEST_BYTES')
    status=qualification.host.status(request.parent)
    authority.require(status['state'] in ('complete','failed') and status.get('host_alive') is False,
        'CLOSURE_ORIGINAL_HOST_UNFINISHED')
    terminal=status['result']
    authority.require(terminal['primary_terminal']==qualification.files.bind(root/'supervisor_result.json'),
        'CLOSURE_ORIGINAL_PRIMARY')
    return dict(original_host_success=status['state']=='complete',
        original_publication_complete=True,owned_cleanup_complete=terminal['owned_cleanup_complete'],
        source_unchanged=terminal['source_unchanged'],
        original_host_request=qualification.files.bind(request),
        original_host_terminal=qualification.files.bind(request.parent/'host_result.json'),
        original_host_publication=qualification.files.bind(request.parent/'published.json'))


def workflow_passed(record):
    return all(record.get(k) is True for k in ('original_host_success','original_publication_complete',
        'owned_cleanup_complete','source_unchanged'))


def accepted_decision(audit, workflow):
    decision=finite_decision(audit)
    if not workflow_passed(workflow):
        decision.update(q_sdk_r10_satisfied=False,sdk1_m07_satisfied=False,acceptance='not_accepted')
    return decision

def build(root):
    root = Path(root)
    audit = campaign.audit(root, retained=True)
    mode = audit['mode']
    workflow=original_workflow(root)
    record = dict(schema_version='sporespore_r10w_'+('production_route_ghost_closure_v1' if mode == 'development_ghost' else 'held_out_physical_closure_v1'),
                  ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='retained_development_closure' if mode == 'development_ghost' else 'finite_physical_closure', question_class='development' if mode == 'development_ghost' else 'finite decision'),
                  source_commit=audit['source_commit'], evidence_root=root.resolve().as_posix(),
                  production_route_key=audit['production_route_key'], independent_audit=audit,
                  launcher_ok=audit['execution_valid'], independent_audit_ok=True, post_exposure_regraded=False,
                  held_out_worlds_opened=0 if mode == 'development_ghost' else audit['total_world_builds'],
                  physical_acceptance_authority=False, release_authority=False,
                  preserved_development_prerequisite=authority.file_binding(authority.READER_COMPONENT_PATH),
                  reader_contract=authority.file_binding(authority.READER_CONTRACT_PATH),
                  reader_component_sha256=authority.READER_COMPONENT_SHA,
                  task_contract=authority.file_binding(authority.TASK_PATH),**workflow)
    if mode == 'development_ghost':
        try:
            covered = development_coverage(audit)
        except ValueError as error:
            covered = dict(complete=False, failure_code=str(error))
        record.update(production_route_ghost_passed=audit['execution_valid'] and workflow_passed(workflow),
                      all_tasks_positive=audit['all_finite_tasks_passed'],
                      declared_cells=authority.population('development_ghost'), branch_coverage=covered,
                      safety_gate=qualification.validate_gate(root, source_commit=audit['source_commit'], route_key=audit['production_route_key'], physical=True)
                          if audit['execution_valid'] and workflow_passed(workflow) else None)
    else:
        record.update(decision=accepted_decision(audit,workflow),
                      authority=authority.file_binding(authority.AUTHORITY_PATH),
                      preregistration=authority.file_binding(authority.PREREGISTRATION_PATH),
                      qualification=authority.file_binding(authority.QUALIFICATION_PATH),
                      population_consumed=True, retry_permitted=False, acceptance_requires_separate_adoption=True)
    return record


def adoption():
    record = authority.parse((authority.ROOT / PHYSICAL_CLOSURE).read_bytes())
    rebuilt = build(record['evidence_root'])
    authority.require(authority.same(record, rebuilt), 'ADOPTION_CLOSURE_RECONSTRUCTION')
    decision = accepted_decision(record['independent_audit'],record)
    authority.require(decision['q_sdk_r10_satisfied'] is True, 'ADOPTION_NEGATIVE_OR_INVALID')
    key = dependencies.validate(authority.parse((authority.ROOT / authority.MANIFEST_PATH).read_bytes()))
    authority.require(key == record['production_route_key'], 'ADOPTION_FROZEN_KEY')
    return dict(schema_version='sporespore_r10w_release_gate_adoption_v1',
                ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='explicit_exact_finite_release_gate_adoption', question_class='finite decision'),
                gate_id='QSDK-R10', milestone_id='SDK1-M07', decision=decision,
                closure=authority.file_binding(PHYSICAL_CLOSURE),
                dependency_manifest=authority.file_binding(authority.MANIFEST_PATH),
                task_contract=authority.file_binding(authority.TASK_PATH),
                reader_contract=authority.file_binding(authority.READER_CONTRACT_PATH),
                reader_component=authority.file_binding(authority.READER_COMPONENT_PATH),
                accepted_cell_count=6, production_route_key=key,
                scoped_behavior='Exact S169 Godot/Jolt: matched no-kick continuation and one native kick followed by passive descent and native upright, partial, or prone recovery; conditional upright bounded hold, fresh V56 finite walking and settled stop at prefix phases 247, 248, 249.',
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
