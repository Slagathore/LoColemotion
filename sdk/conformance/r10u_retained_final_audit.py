"""Full retained R10T audit with an explicit R10U declaration-only projection.

The original trajectory, report headers, native replay, launch and supervisor
remain R10T evidence. Only the host declaration validation receives a synthetic
R10U pair projection. This exercises the real new validator without changing a
timeout global, creating a baseline, rewriting data or reclassifying R10T.
"""
import argparse
import copy
import json
from pathlib import Path
import sys
from unittest.mock import patch
import uuid

import development_passive_entry_profile as entry
import development_recovery_candidate as candidate
import development_recovery_smoke as smoke
import r10u_development as development
import r10u_predecessor_history as history
import r10t_route_integration_component as base

ROOT, EVIDENCE = base.ROOT, base.EVIDENCE
DIRECTORY = EVIDENCE/'r10u-retained-final-audit-43541cb2843b4cd287754221fe7fb981'
ORIGINAL = EVIDENCE/'development-recovery-smoke-108ce23f94694d61ab90acb1495a4fb0'
PROFILE = ROOT/'sdk/development/recovery_candidates/r10u-v56-post-recovery-hold-integrated-v2.json'
RESULT = DIRECTORY/'result.json'
SCOPE = dict(declaration_projection_only=True, projection_is_synthetic=True,
    original_reports_or_replay_changed=False, original_attempt_reclassified=False,
    original_r10t_chain_closed=True, physical_baseline_created_or_reused=False,
    full_r10u_physical_workflow_proven=False, complete_safety_gate_passed=False,
    world_build_count=0,solver_step_count=0,physical_acceptance_authority=False,release_authority=False)


def exact_key():
    path = candidate.R10U_ROUTE_ENTRY_PATH
    value = base.read(path)
    assert value['source_key_complete'] is True
    for item in value['bound_source_files']:
        assert candidate.sha(ROOT/item['path']) == item['raw_sha256'], item['path']
    return base.bind(path)


def projection(chosen, source):
    value = copy.deepcopy(base.read(ORIGINAL/'declaration.json'))
    value.pop('r10t_development')
    attempt = uuid.uuid4().hex
    # These paths are validation-only synthetic descriptors. Never create them.
    fake_root = EVIDENCE/('development-recovery-smoke-'+attempt)
    assert not fake_root.exists()
    value.update(attempt_id=attempt,seed=41245,source_snapshot=dict(head=source['head']),
        candidate_profile=chosen['candidate_profile'], development_execution_mode=development.PAIR,
        comparative_authority=False,baseline_reused=False,
        children=[dict(role=role,child_attempt_id=uuid.uuid4().hex,termination_nonce=uuid.uuid4().hex,
            evidence_path=(fake_root/'children'/role).as_posix()) for role in development.ROLES],
        r10u_development=development.context(development.PAIR,source['head'],chosen['candidate_profile']),
        schema_version=chosen['worker_selection']['declaration_schema'],
        diagnostic_schedule_id=chosen['worker_selection']['schedule'],
        worker_resource=chosen['worker_selection']['worker'],passive_entry_runtime=entry.binding(chosen)['runtime'])
    value.update(candidate.limits(chosen))
    # Use the actual retained 1740 field; do not manufacture a corrected value.
    assert value['timeout_seconds_per_child'] == 1740
    return value


def replay(projected):
    chosen = candidate.selection(candidate.reference_for_path(PROFILE))
    original_declaration = base.read(ORIGINAL/'declaration.json')
    closure = base.read(development.read(development.DESIGN)['predecessor_closure']['path'])
    archived, count = history.historical_selector(closure)
    assert count == 819
    production_validate = entry.validate_declaration
    calls = 0
    assert entry.CHILD_TIMEOUT_SECONDS == 1500

    def declaration_only_bridge(value):
        nonlocal calls
        # Only this exact exposed declaration can use the diagnostic projection.
        assert entry.packet.same(value, original_declaration)
        with patch.object(entry,'selection_for_declaration',return_value=chosen):
            bounds = production_validate(projected)
        assert entry.packet.same(bounds, archived.limits(archived.selection(value['candidate_profile'])))
        calls += 1
        return bounds

    # Resolve the old report against its original exact source archive. The new
    # candidate was selected against the complete live key above, before this
    # local historical scope. No native replay process or physical worker runs.
    with patch.dict(sys.modules,{'development_recovery_candidate':archived}), \
            patch.object(entry,'candidate_profile',archived), \
            patch.object(entry,'validate_declaration',declaration_only_bridge):
        observed = smoke.audit(ORIGINAL)
    assert entry.CHILD_TIMEOUT_SECONDS == 1500
    assert calls > 0
    assert observed['ok'] and observed['r10t_finite_development']['all_tasks_positive']
    assert observed['r10t_finite_development']['branch_coverage_complete']
    assert len(observed['children']) == 1
    assert base.read(ORIGINAL/'supervisor_result.json')['ok'] is False
    assert base.read(ORIGINAL/'independent_audit.stdout.json')['ok'] is False
    assert not Path(projected['children'][0]['evidence_path']).parent.parent.exists()
    return dict(original_report_audit=observed,projected_declaration_validation_calls=calls)


def verify(*, replay_original=True):
    value = base.read(RESULT)
    assert value['ok'] is True and value['scope'] == SCOPE
    current_key = exact_key()
    base.verify(value['source_key'])
    # A later complete source key must execute this full diagnostic again.
    # Only the historical expected output is reused; qualification is never cached.
    if not replay_original:
        assert value['source_key'] == current_key
    for item in value['bindings']: base.verify(item)
    assert base.read(DIRECTORY/'source_before.json') == base.read(DIRECTORY/'source_after.json')
    observed = value['observed']
    if replay_original:
        assert entry.packet.same(replay(base.read(DIRECTORY/'projected-declaration.json')),observed)
    finite = observed['original_report_audit']['r10t_finite_development']
    assert finite['all_tasks_positive'] and finite['branch_coverage_complete'] and len(finite['cells']) == 1
    return dict(ok=True,source_key=current_key,recorded_source_key=value['source_key'],result=base.bind(RESULT),
        original_full_audit_reconstructed=replay_original,
        projected_declaration_validation_calls=observed['projected_declaration_validation_calls'],**SCOPE)


def run():
    DIRECTORY.mkdir(exist_ok=False)
    source = entry._source_snapshot();base.write_new(DIRECTORY/'source_before.json',source)
    key = exact_key()
    chosen = candidate.selection(candidate.reference_for_path(PROFILE))
    projected = projection(chosen,source)
    base.write_new(DIRECTORY/'projected-declaration.json',projected)
    declaration = dict(schema_version='sporespore_r10u_retained_final_audit_declaration_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='post_exposure_zero_world_diagnostic',question_class='development'),
        scope=SCOPE,source_key=key,source_archive=history.original.base.read(history.original.RECORD)['source_archive'],
        question='Can the complete retained audit finish while the exact new shared host validator checks a labeled R10U pair projection?',
        projection_limit='Synthetic declaration validation only. Original source, report identities, role population, native replay and all measured physics stay R10T; no R10U baseline or physical result exists.',
        bindings=[base.bind(p) for p in [Path(__file__),PROFILE,development.DESIGN,
            ORIGINAL/'declaration.json',ORIGINAL/'supervisor_result.json',ORIGINAL/'independent_audit.stdout.json',
            ROOT/'sdk/recovery/r10t_phase245_initial_invalid_closure_v1.json']])
    base.write_new(DIRECTORY/'declaration.json',declaration)
    try:
        observed = replay(projected)
    except Exception as error:
        base.write_new(DIRECTORY/'source_after.json',entry._source_snapshot())
        base.write_new(RESULT,dict(ok=False,failure_type=type(error).__name__,failure=str(error),scope=SCOPE,source_key=key))
        raise
    after = entry._source_snapshot();base.write_new(DIRECTORY/'source_after.json',after)
    assert source == after and exact_key() == key
    bindings = declaration['bindings']+[base.bind(DIRECTORY/name) for name in
        ['source_before.json','source_after.json','projected-declaration.json','declaration.json']]
    value = dict(schema_version='sporespore_r10u_retained_final_audit_result_v1',
        ledger_scope=declaration['ledger_scope'],ok=True,scope=SCOPE,source_key=key,
        bindings=bindings,observed=observed)
    base.write_new(RESULT,value)
    return verify(replay_original=False)


if __name__ == '__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--run',action='store_true');args=parser.parse_args()
    print(json.dumps(run() if args.run else verify()))
