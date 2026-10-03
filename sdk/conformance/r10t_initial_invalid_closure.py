"""Preserve R10T's consumed workflow failure and separately diagnosed physics."""
import argparse
import json
import mmap
from pathlib import Path
import uuid
import r10t_route_integration_component as base
import r10t_development_launch as launch

ROOT, EVIDENCE = base.ROOT, base.EVIDENCE
RUN = EVIDENCE/'development-recovery-smoke-108ce23f94694d61ab90acb1495a4fb0'
OUTER = EVIDENCE/'r10t-settling-repaired-gate-invocation-bef4a92ccd2a470d9424afbdb4504183'
DIAGNOSIS = EVIDENCE/'r10t-initial-result-diagnosis-7ab04d8a28e94d3da56caeec52914553'
RECORD = ROOT/'sdk/recovery/r10t_phase245_initial_invalid_closure_v1.json'
KEY = ROOT/'sdk/recovery/r10t_v56_walking_entry_contract_v25.json'
HEAD = 'cc73e09aa9a81ee08d5f4bdf641e748d41fac8e2'
CLAIMS = dict(original_attempt_classification='consumed_infrastructure_invalid',
    original_attempt_reclassified=False, r10t_development_chain_closed=True,
    r10t_pair_or_later_diagnostics_authorized=False, held_out_population_declared=False,
    physical_acceptance_authority=False, release_authority=False, sdk1_score='14/20',
    full_program_score='14/25')


def root_scalars(path, names):
    # Read only root-level scalar fields from the large, retained pretty JSON.
    values = {}
    with Path(path).open('rb') as stream, mmap.mmap(stream.fileno(), 0, access=mmap.ACCESS_READ) as raw:
        for name in names:
            prefix = ('\n  '+json.dumps(name)+': ').encode()
            at = raw.find(prefix)
            assert at >= 0 and raw.find(prefix, at+1) == -1, name
            start = at+len(prefix); end = raw.find(b'\n', start)
            values[name] = json.loads(raw[start:end].rstrip(b'\r,'))
    return values


def observed():
    supervisor = base.read(RUN/'supervisor_result.json')
    original = base.read(RUN/'independent_audit.stdout.json')
    declaration = base.read(RUN/'declaration.json')
    assert supervisor['ok'] is False and supervisor['physical_attempt_started'] is True
    assert supervisor['failure_code'] == 'SMOKE_INDEPENDENT_AUDIT_FAILED'
    assert original['ok'] is False and original['failure_code'] == 'DEVELOPMENT_PASSIVE_PROFILE_DECLARATION_timeout_seconds_per_child'
    assert declaration['source_snapshot']['head'] == HEAD and declaration['timeout_seconds_per_child'] == 1740
    assert len(declaration['safety_stages']) == 62 and sum(s['test_count'] for s in declaration['safety_stages']) == 220
    assert launch.verify(RUN/'declaration.json')['ok']
    execution = base.read(OUTER/'execution.json')
    assert execution['exit_code'] == 1 and not execution['timed_out']
    assert execution['source_commit'] == HEAD and execution['head_unchanged'] and execution['tree_clean']
    diagnostic = base.read(DIAGNOSIS/'result.json')
    assert diagnostic['ok'] and diagnostic['original_attempt_reclassified'] is False
    assert diagnostic['r10t_development_chain_closed'] and not diagnostic['paired_launch_authorized']
    assert base.read(DIAGNOSIS/'source_before.json') == base.read(DIAGNOSIS/'source_after.json')
    declared = base.read(DIAGNOSIS/'diagnostic_declaration.json')
    assert (declared['original_validator_host_seconds'], declared['frozen_design_host_seconds']) == (1500, 1740)
    for item in declared['bindings']: base.verify(item)
    audit = diagnostic['diagnostic_audit']; finite = audit['r10t_finite_development']
    assert audit['ok'] and finite['all_tasks_positive'] and finite['branch_coverage_complete']
    assert len(finite['cells']) == len(audit['children']) == 1
    cell = finite['cells'][0]; measure = cell['measurement']
    assert cell['entry_kind'] == 'upright' and cell['post_recovery_handoff'] == 'bounded_hold'
    assert measure['finite_task_predicates_passed'] and all(v is True for v in measure['predicates'].values())
    post = measure['entry']['post_recovery']; walk = measure['walking']
    assert (post['commands'], post['consecutive_ready'], post['initial_ready'], post['final_ready']) == (106, 30, False, True)
    assert (walk['command_count'], walk['cycle_end_command'], walk['stopping_commands'], len(walk['planned_cycles'])) == (1175, 1055, 120, 4)
    child = RUN/'children/kick_passive_recovery_resume'
    replay = base.read(child/'passive_entry_replay_result.json')
    assert replay == audit['children'][0]['passive_entry_replay']
    assert replay['ok'] and replay['complete_report_timeline_replayed'] and replay['transition_count'] == 2315
    assert replay['walking_control_replay']['cycle_stop_final_memory']['consecutive_settled_commands'] == 120
    counts = root_scalars(child/'worker_report.json', ['world_build_count', 'external_kick_application_count', 'solver_step_count'])
    assert counts == dict(world_build_count=1, external_kick_application_count=1, solver_step_count=2315)
    return dict(complete_safety_gate_passed=True, safety_stages=62, safety_tests=220,
        seed=41145, prefix_phase=245, physical_worlds=1, physical_kicks=1, physical_solver_steps=2315,
        original_audit_failure=original['failure_code'], declared_child_wall_seconds=1740,
        stale_validator_child_wall_seconds=1500, original_native_replay_passed=True,
        diagnostic_full_audit_passed=True, diagnostic_all_finite_predicates_passed=True,
        entry_kind='upright', post_recovery_handoff='bounded_hold', hold_commands=106,
        consecutive_ready_samples=30, walking_commands=1175, planned_cycles=4, stopping_commands=120,
        forward_advance_m=walk['pre_first_to_post_last_body_forward_m'], predicates=measure['predicates'])


def audit(record):
    assert record['claim_boundary'] == CLAIMS
    for item in record['bindings']+[record['auditor'], record['manifest']]: base.verify(item)
    for item in base.read(record['manifest']['path'])['files']: base.verify(item)
    archive = record['source_archive']; base.verify(archive['key']); base.verify(archive['snapshot'])
    for item in base.read(archive['key']['path'])['bound_source_files']:
        assert base.bind(Path(archive['directory'])/item['path'])['raw_sha256'] == item['raw_sha256']
    assert observed() == record['observed']
    return dict(ok=True, **record['observed'], **CLAIMS)


def create():
    assert not RECORD.exists()
    result = observed()
    directory = EVIDENCE/('r10t-initial-invalid-closure-'+uuid.uuid4().hex); directory.mkdir()
    roots = [RUN, OUTER, DIAGNOSIS,
        EVIDENCE/'development-recovery-smoke-cfd4b6a888e24699b25ade40b95027a7',
        EVIDENCE/'r10t-settling-repaired-gate-invocation-9c8a9dc55bda40258f68ff8d0e0aff0a',
        EVIDENCE/'r10t-step-cost-check-a89f7df0c35a4b73a7c43ef3e7a14a24']
    manifest = directory/'manifest.json'
    base.write_new(manifest, dict(files=[base.bind(p) for root in roots for p in sorted(root.rglob('*')) if p.is_file()]))
    component = ROOT/'sdk/recovery/r10t_settling_test_profile_repair_component_v1.json'
    archive = base.read(component)['source_archive']
    assert archive['key'] == base.bind(KEY)
    record = dict(schema_version='sporespore_r10t_phase245_initial_invalid_closure_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
            authority_mode='consumed_infrastructure_invalid_with_separate_post_exposure_diagnosis', question_class='development'),
        auditor=base.bind(__file__), manifest=base.bind(manifest), source_archive=archive,
        source_commit=HEAD, evidence_root=str(RUN), diagnostic_root=str(DIAGNOSIS),
        bindings=[base.bind(p) for p in [component, KEY, EVIDENCE/'r10t_first_single_consumption_v1.json',
            ROOT/'sdk/recovery/r10t_post_recovery_settling_design_v1.json',
            ROOT/'sdk/conformance/r10t_initial_result_diagnosis.py']],
        observed=result, claim_boundary=CLAIMS)
    audit(record); base.write_new(RECORD, record)
    return dict(ok=True, **result, **CLAIMS)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(); parser.add_argument('--create', action='store_true')
    args = parser.parse_args(); print(json.dumps(create() if args.create else audit(base.read(RECORD))))
