"""Complete exposed R10U pair audit with explicit diagnostic substitutions.

No original receipt is created or repaired. Original reports and finite results
remain R10U; the R10V declaration projection is synthetic interface evidence.
"""
import argparse
import copy
import json
from pathlib import Path
import sys
import time
from unittest.mock import patch
import uuid
import development_passive_entry_profile as entry
import development_recovery_candidate as candidate
import development_recovery_smoke as smoke
import r10v_development as development
import r10v_predecessor_history as history
import r10t_route_integration_component as base
import r10u_interrupted_pair_closure as closure

ROOT,EVIDENCE=base.ROOT,base.EVIDENCE
ORIGINAL=closure.RUN
REPLAYS=EVIDENCE/'r10u-interrupted-report-diagnosis-83ae2d6dfe804cc0bd46b281e70ad720'
PROFILE=ROOT/'sdk/development/recovery_candidates/r10v-v56-post-recovery-hold-integrated-v2.json'
SCOPE=dict(declaration_projection_only=True,projection_is_synthetic=True,
    separately_retained_diagnostic_replay_substitution=True,
    original_reports_or_replay_changed=False,original_attempt_reclassified=False,
    original_r10u_chain_closed=True,physical_baseline_created_or_reused=False,
    full_r10v_physical_workflow_proven=False,complete_safety_gate_passed=False,
    world_build_count=0,solver_step_count=0,physical_acceptance_authority=False,release_authority=False)


def exact_key():
    path=candidate.R10V_ROUTE_ENTRY_PATH;value=base.read(path)
    assert value['source_key_complete'] is True
    for item in value['bound_source_files']:
        assert candidate.sha(ROOT/item['path'])==item['raw_sha256'],item['path']
    return base.bind(path)


def projection(chosen,source):
    value=copy.deepcopy(base.read(ORIGINAL/'declaration.json'))
    value.pop('r10u_development')
    attempt=uuid.uuid4().hex;fake_root=EVIDENCE/('development-recovery-smoke-'+attempt)
    assert not fake_root.exists()
    value.update(attempt_id=attempt,seed=41345,source_snapshot=dict(head=source['head']),
        candidate_profile=chosen['candidate_profile'],development_execution_mode=development.PAIR,
        comparative_authority=False,baseline_reused=False,
        children=[dict(role=role,child_attempt_id=uuid.uuid4().hex,termination_nonce=uuid.uuid4().hex,
            evidence_path=(fake_root/'children'/role).as_posix()) for role in development.ROLES],
        r10v_development=development.context(development.PAIR,source['head'],chosen['candidate_profile']),
        schema_version=chosen['worker_selection']['declaration_schema'],diagnostic_schedule_id=chosen['worker_selection']['schedule'],
        worker_resource=chosen['worker_selection']['worker'],passive_entry_runtime=entry.binding(chosen)['runtime'])
    value.update(candidate.limits(chosen))
    assert value['timeout_seconds_per_child']==1740
    return value


def replay(projected,directory):
    chosen=candidate.selection(candidate.reference_for_path(PROFILE))
    original_declaration=base.read(ORIGINAL/'declaration.json')
    record=base.read(closure.RECORD)
    archived,count=history.historical_selector(record);assert count==942
    production_validate=entry.validate_declaration
    original_consume=entry.consume_replay;original_read=smoke.read
    calls=0;consumed={};substitutions=[]
    assert entry.CHILD_TIMEOUT_SECONDS==1500

    def progress(stage,role=''):
        with (directory/'progress.jsonl').open('a',encoding='utf-8') as out:
            out.write(json.dumps(dict(stage=stage,role=role,elapsed_seconds=time.monotonic()-started))+'\n');out.flush()

    def declaration_bridge(value):
        nonlocal calls
        assert entry.packet.same(value,original_declaration)
        with patch.object(entry,'candidate_profile',candidate),patch.object(entry,'selection_for_declaration',return_value=chosen):
            bounds=production_validate(projected)
        assert entry.packet.same(bounds,archived.limits(archived.selection(value['candidate_profile'])))
        calls+=1
        return bounds

    def replay_bridge(path,*args,**kwargs):
        path=Path(path).resolve();role=path.parent.name
        assert not args and not kwargs and role in development.ROLES
        assert path==ORIGINAL/'children'/role/'worker_report.json' and role not in consumed
        diagnostic=REPLAYS/role/'worker_report.json'
        assert base.bind(path)['raw_sha256']==base.bind(diagnostic)['raw_sha256']
        assert not (path.parent/'passive_entry_replay_result.json').exists()
        progress('consume_diagnostic_replay_start',role)
        result=original_consume(diagnostic)
        assert entry.packet.same(result,base.read(REPLAYS/role/'consumer.stdout.json'))
        consumed[role]=result
        substitutions.append(dict(role=role,original_input=base.bind(path),diagnostic_input=base.bind(diagnostic),
            diagnostic_result=base.bind(REPLAYS/role/'consumer.stdout.json'),
            diagnostic_execution=base.bind(REPLAYS/role/'passive_entry_replay/execution.json'),
            original_publication_missing=True,original_attempt_reclassified=False))
        progress('consume_diagnostic_replay_end',role)
        return result

    def publication_bridge(path):
        path=Path(path).resolve()
        if path.name=='passive_entry_replay_result.json' and path.parent.parent==ORIGINAL/'children':
            assert not path.exists() and path.parent.name in consumed
            return consumed[path.parent.name]
        return original_read(path)

    started=time.monotonic();progress('complete_pair_audit_start')
    with patch.dict(sys.modules,{'development_recovery_candidate':archived}), \
         patch.object(entry,'candidate_profile',archived),patch.object(entry,'validate_declaration',declaration_bridge), \
         patch.object(entry,'consume_replay',replay_bridge),patch.object(smoke,'read',publication_bridge):
        observed=smoke.audit(ORIGINAL)
    progress('complete_pair_audit_end')
    assert entry.CHILD_TIMEOUT_SECONDS==1500 and calls>0
    assert observed['ok'] and len(observed['children'])==2 and list(consumed)==development.ROLES
    finite=observed['r10u_finite_development']
    assert finite['all_tasks_positive'] and finite['branch_coverage_complete'] and len(finite['cells'])==2
    assert [c['solver_steps'] for c in observed['children']]==[1749,2315]
    assert all(not p.exists() for p in closure.missing_paths())
    assert not Path(projected['children'][0]['evidence_path']).parent.parent.exists()
    return dict(original_report_audit=observed,projected_declaration_validation_calls=calls,
        diagnostic_replay_substitutions=substitutions,elapsed_seconds=time.monotonic()-started)


def run():
    directory=EVIDENCE/('r10v-retained-pair-audit-'+uuid.uuid4().hex);directory.mkdir()
    print('R10V_RETAINED_PAIR_AUDIT '+str(directory),flush=True)
    source=entry._source_snapshot();base.write_new(directory/'source_before.json',source)
    key=exact_key();chosen=candidate.selection(candidate.reference_for_path(PROFILE))
    projected=projection(chosen,source);base.write_new(directory/'projected-declaration.json',projected)
    declaration=dict(schema_version='sporespore_r10v_retained_pair_audit_declaration_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='post_exposure_zero_world_diagnostic',question_class='development'),
        scope=SCOPE,source_key=key,source_archive=base.read(closure.RECORD)['source_archive'],
        question='Can the complete real final auditor process both exposed reports, with explicit diagnostic replay provenance and current R10V declaration validation?',
        audit_limit_seconds=1800,
        bindings=[base.bind(p) for p in (Path(__file__),PROFILE,development.DESIGN,closure.RECORD,REPLAYS/'result.json',ORIGINAL/'declaration.json')])
    base.write_new(directory/'declaration.json',declaration)
    try:observed=replay(projected,directory)
    except BaseException as error:
        base.write_new(directory/'source_after.json',entry._source_snapshot())
        base.write_new(directory/'result.json',dict(ok=False,failure_type=type(error).__name__,failure=str(error),scope=SCOPE,source_key=key))
        raise
    after=entry._source_snapshot();base.write_new(directory/'source_after.json',after)
    assert source==after and exact_key()==key and observed['elapsed_seconds']<=1800
    for item in declaration['bindings']:base.verify(item)
    result=dict(schema_version='sporespore_r10v_retained_pair_audit_result_v1',ok=True,
        ledger_scope=declaration['ledger_scope'],scope=SCOPE,source_key=key,observed=observed)
    base.write_new(directory/'result.json',result)
    return dict(ok=True,result=base.bind(directory/'result.json'),source_key=key,
        original_full_audit_reconstructed=True,projected_declaration_validation_calls=observed['projected_declaration_validation_calls'],
        elapsed_seconds=observed['elapsed_seconds'],**SCOPE)


def verify(*,replay_original=True):
    # Qualification runs both complete original reports afresh; no cached pass.
    assert replay_original is True
    return run()


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--run',action='store_true');parser.parse_args()
    print(json.dumps(run()))
