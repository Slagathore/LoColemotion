"""Close R10AI's consumed valid negative from original retained bytes only.

No world, replay process, source-key renewal, or result reclassification occurs.
Stream the large physical report to keep this historical audit bounded in memory.
"""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import subprocess

import r10ab_first_support_closure as streams
import r10af_rise_tracking_analysis as geometry
import r10ai_development_launch as launch
import r10ai_native_world_authority as authority
import r10ai_report_gate as reports
import qsdk_r10f_l15_launch_relationship as ownership
from r10ae_replay_invalid_closure import ROOT, EVIDENCE, read, bind, write_new

HEAD = '6e921eeae6932946dbbc2f47db4e6ee2b7b2bd08'
RUN = EVIDENCE / 'development-recovery-smoke-ef8541de5e63459ea1fd6720b1dcd184'
CHILD = RUN / 'children/kick_passive_recovery_resume'
TOKEN = EVIDENCE / 'r10ai_concurrent_load_rise_diagnostic_67248_consumption_v1.json'
KEY = ROOT / 'sdk/recovery/r10ai_v56_walking_entry_contract_v14.json'
CONTRACT = ROOT / 'sdk/development/r10ai_safety_stage_contract_v1.json'
RECORD = ROOT / 'sdk/recovery/r10ai_concurrent_load_rise_closure_v1.json'
SOURCE_BYTES = EVIDENCE / 'r10ai-frozen-source-bytes-c80a419ad30445afbce332421ec34f0d'
REPORT_SHA = 'sha256:e439aa623c068815439663dee4c6aa920b8891f8abaee4ef44566b6051089dfc'
SCOPE = dict(subsystem='recovery', engine_scope='godot_jolt',
    authority_mode='retained_single_kick_development_closure', question_class='development')
CLAIMS = dict(outcome='valid_development_negative', population_consumed=True,
    rerun_authorized=False, bounded_production_path_exercised=True,
    complete_route_proven=False, recovery_success_obtained=False,
    paired_commissioning_satisfied=False, comparative_authority=False,
    causal_repair_proven=False, official_qualification_passed=False,
    physical_acceptance_authority=False, release_authority=False,
    sdk1_score='14/20', full_program_score='14/25')


def frozen_sources():
    """Validate the original 2,294-file key against the pushed Git freeze."""
    rows = read(KEY)['bound_source_files']
    assert len(rows) == len({r['path'] for r in rows}) == 2294
    result = subprocess.run(['git', 'cat-file', '--batch'], cwd=ROOT,
        input=''.join(HEAD + ':' + r['path'] + '\n' for r in rows).encode(),
        capture_output=True, check=True, timeout=60, creationflags=subprocess.CREATE_NO_WINDOW)
    assert not result.stderr
    raw, cursor = result.stdout, 0
    for row in rows:
        end = raw.index(b'\n', cursor); header = raw[cursor:end].split()
        assert len(header) == 3 and header[1] == b'blob', row['path']
        size = int(header[2]); data = raw[end+1:end+1+size]; cursor = end+2+size
        variants = [data] if b'\r\n' in data else [data, data.replace(b'\n', b'\r\n')]
        if not any(len(v) == row['byte_length'] and
            'sha256:' + hashlib.sha256(v).hexdigest() == row['raw_sha256'] for v in variants):
            # Three historical files mix EOL forms. Preserve exact pre-existing
            # working bytes, while also checking equivalence to the Git blob.
            exact = (SOURCE_BYTES/row['path']).read_bytes()
            assert len(exact) == row['byte_length'] and 'sha256:' + hashlib.sha256(exact).hexdigest() == row['raw_sha256']
            assert exact.replace(b'\r\n',b'\n') == data.replace(b'\r\n',b'\n'), row['path']
    assert cursor == len(raw)


def fixture_roots():
    return {name: EVIDENCE / ('development-recovery-smoke-' + case['declaration']['attempt_id'])
        for name, case in read(reports.CATALOG)['cases'].items()}


def consumer_results():
    """Reopen consumed fixture receipts; never execute a catalog identity again."""
    results = {}
    for name, root in fixture_roots().items():
        execution, result = read(root/'execution.json'), read(root/'result.json')
        assert execution['ok'] is True and execution['source_unchanged'] is True
        before = read(root/'source-before.json')
        assert before == read(root/'source-after.json')
        assert before == dict(head=HEAD, remote=launch.REMOTE, status='', changed_files=[])
        assert result['complete_production_python_consumer'] is True
        assert result['world_build_count'] == result['solver_step_count'] == 0
        assert result['physical_acceptance_authority'] is result['release_authority'] is False
        value = result['result']
        if name in reports.FAILURES:
            assert value == dict(expected_refusal=True,
                consumer_error='DEVELOPMENT_PASSIVE_PROFILE_PROCESS_FAILED',
                process_returncode=1, native_failure_code=reports.FAILURES[name])
        else:
            assert value['ok'] is True
            assert value['transition_count'] == dict(partial=575, upright=575, ready=605, timeout=815, walking=607)[name]
        results[name] = value
    assert len(results) == 13
    return results


def trajectory():
    report = CHILD/'worker_report.json'
    assert bind(report)['raw_sha256'] == REPORT_SHA
    rows, previous = [], None
    for packet in geometry.records(report, 'r10ai_partial_recovery', 'step_packets'):
        assert packet['ok'] is True and packet['call']['value'] == packet['native_receipt']
        if previous is not None: assert packet['prior_memory'] == previous
        row = streams.diagnosis.snapshot(packet)
        row['plan'] = packet['native_receipt']['next_load_plan']
        row['applied_command'] = packet['source_application']['command_sha256']
        control = packet['native_receipt']['next_control']
        row['next_command'] = None if control is None else control['command_sha256']
        assert row['partial_step'] == len(rows)+1 and row['semantic_step'] == len(rows)+513
        rows.append(row); previous = packet['native_receipt']['step']['memory']
    assert len(rows) == 601 and previous['phase'] == 'failed'
    assert previous['terminal_failure_code'] == 'phase_timeout:raise_body'
    assert previous['phase_steps_observed'] == 600 and previous['standing_samples_observed'] == 0
    assert previous['ordered_completed_phases'] == ['establish_distal_support']
    assert [r['prior_phase'] for r in rows] == ['establish_distal_support'] + ['raise_body']*600
    assert rows[-1]['plan'] is None
    pairs = list(zip(rows, rows[1:]))
    assert all(a['next_command'] == b['applied_command'] for a, b in pairs)
    modes = dict(Counter(a['plan']['mode'] for a, _ in pairs))
    assert modes == dict(concurrent_load_and_rise=334, explicit_v23_fallback=266)
    gates = {key: sum(r['classification'][key] for r in rows[1:]) for key in (
        'distal_support_gate','raised_body_gate','stable_stance_gate','safety_gate',
        'joint_limits_respected','actuator_budget_respected','any_nonfoot_contact')}
    assert gates == dict(distal_support_gate=0, raised_body_gate=0, stable_stance_gate=0,
        safety_gate=0, joint_limits_respected=477, actuator_budget_respected=600, any_nonfoot_contact=600)
    fields = ('torso_height_ratio','torso_up_dot','center_of_mass_height_gain_m','minimum_nonfoot_clearance_m')
    per_mode = {}
    for mode in modes:
        selected = [(a,b) for a,b in pairs if a['plan']['mode'] == mode]
        per_mode[mode] = dict(commands=len(selected),
            hold_reasons=dict(Counter(a['plan']['concurrent_geometry']['hold_reason'] or 'none' for a,b in selected)),
            joint_limit_failures_after=sum(not b['classification']['joint_limits_respected'] for a,b in selected))
    return dict(partial_steps=601, support_commands=1, raise_commands=600, command_links=600,
        original_final_memory=previous, mode_counts=modes, raise_gate_counts=gates,
        raise_ranges={k:[min(r['classification'][k] for r in rows[1:]),
                        max(r['classification'][k] for r in rows[1:])] for k in fields},
        per_mode=per_mode, snapshots=[rows[i] for i in (0,60,120,180,240,300,360,420,480,540,600)],
        inference='The body lifts but never restores qualified four-foot support during raising. '
            'All 266 fallback commands follow no feasible cost-decreasing candidate; the body settles '
            'near height ratio 0.57 with non-foot contact. Diagnose support, pitch, joint tracking and '
            'planner feasibility before selecting a successor. This single child establishes no matched causal effect.',
        original_result_regraded=False, comparative_authority=False)


def observations():
    declaration, supervisor = read(RUN/'declaration.json'), read(RUN/'supervisor_result.json')
    assert supervisor['ok'] is True and supervisor['failure_code'] == '' and supervisor['physical_attempt_started'] is True
    assert declaration['source_snapshot'] == supervisor['source_snapshot'] == dict(head=HEAD, dirty=False, status=[], changed_file_bindings=[])
    marker = (RUN/'published_marker.txt').read_text().strip()
    assert marker.startswith('DEVELOPMENT_RECOVERY_SMOKE_COMPLETE ')
    assert json.loads(marker.split(' ',1)[1]) == supervisor
    # Live admission correctly rejects later source additions. Verify historical
    # authorization against its receipts and frozen Git bytes instead.
    path = RUN/'declaration.json'
    launch.development.validate_declaration(declaration)
    issued = read(RUN/launch.LAUNCH_FILE)
    assert issued['declaration'] == launch.binding(path)
    assert issued['source_key'] == launch.binding(KEY)
    assert issued['safety_contract'] == launch.binding(CONTRACT)
    assert issued['safety_logs'] == launch.shared.safety(path,declaration,contract_path=CONTRACT)
    assert issued['context_handoff'] == launch.handoff.verify(path)
    assert issued['runtime_binding'] == declaration['runtime']
    assert issued['stage_reservation'] == launch.binding(TOKEN)
    assert read(TOKEN) == launch.reservation(path,declaration)
    assert issued['attempt_id'] == declaration['attempt_id'] and issued['stage'] == launch.development.STAGE
    assert issued['freeze'] == dict(root=ROOT.as_posix(),remote=launch.REMOTE,branch='main',
        head=HEAD,origin_main=HEAD,live_origin_main=HEAD,clean=True)
    assert all(issued[k] is False for k in ('official_qualification','physical_acceptance_authority','release_authority'))
    claim = read(CHILD/authority.CLAIM)
    assert claim == authority.expected_claim(path,declaration,claim['worker_process_id'])
    token, contract = read(TOKEN), read(CONTRACT)
    assert token['seed'] == declaration['seed'] == 67248 and token['attempt_limit'] == 1
    stages = declaration['safety_stages']
    assert stages == supervisor['safety_stages'] and len(stages) == len(contract['stages']) == 75
    assert sum(s['test_count'] for s in stages) == contract['total_tests'] == 258
    for stage,spec in zip(stages,contract['stages'],strict=True):
        assert stage['id'] == spec['id'] and stage['passed'] is True
        assert stage['timed_out'] is False and stage['exit_code'] == 0
        assert stage['test_count'] == stage['expected_test_count'] == spec['tests']
    termination = streams.small_fields(CHILD/'termination_receipt.json')
    context = json.loads(termination['r10f_l15_launch_relationship']['payload_json'])['context']
    ownership.validate_child_launch(streams.small_fields(CHILD/'child_envelope.json'), context)
    assert termination['exit_code'] == 0 and termination['timed_out'] is False and termination['termination_protocol_valid'] is True
    assert read(CHILD/'engine_health.json')['passed'] is True
    release = read(CHILD/'payload_release_receipt.json')
    assert release['original_evidence_rewritten'] is False and release['launch_relationship_valid'] is True
    for item in [release['retained_envelope'],*release['verified_artifacts'].values()]: assert bind(item['path']) == item
    report = streams.small_fields(CHILD/'worker_report.json')
    assert report['world_build_count'] == report['world_attempt_count'] == report['external_kick_application_count'] == 1
    assert report['solver_step_count'] == report['global_solver_frame_count'] == 1113
    assert report['held_out_cell_access_count'] == 0
    replay = read(CHILD/'passive_entry_replay_result.json')
    assert replay['ok'] is replay['controller_and_diagnostic_replay_passed'] is True
    assert replay['input_raw_sha256'] == REPORT_SHA and replay['transition_count'] == 1113 and replay['partial_observation_count'] == 601
    execution = read(CHILD/'passive_entry_replay/execution.json')
    assert execution['returncode'] == 0 and execution['timed_out'] is False and execution['input_raw_sha256'] == REPORT_SHA
    independent = read(RUN/'independent_audit.stdout.json')
    assert independent == supervisor['independent_audit'] and independent['ok'] is True and independent['total_solver_steps'] == 1113
    result = independent['r10ai_contact_frame_diagnostic']
    assert result['all_tasks_positive'] is False and result['branch_coverage_complete'] is True
    assert result['paired_commissioning_satisfied'] is False and len(result['cells']) == 1
    assert result['cells'][0]['measurement']['walking']['status'] == 'walking_not_reached'
    contacts = result['contact_frame_replay']
    assert contacts == replay['r10af_contact_frame_replay'] and contacts['ok'] is True
    assert contacts['diagnostic_steps_replayed'] == 1113 and contacts['matched_source_contacts'] == 4797 and contacts['classification_changes'] == 263
    return dict(execution_valid=True, source_commit=HEAD, seed=67248, exposed_prefix_phase=248,
        safety_stages=75, safety_tests=258, worlds=1, kicks=1, solver_steps=1113,
        native_replay_passed=True, final_python_consumer_passed=True, final_audit_passed=True,
        terminal_failure_code='phase_timeout:raise_body', walking_reached=False,
        consumer_cases=consumer_results(), physical_measurement=result['cells'][0]['measurement'],
        contact_replay=contacts, diagnostic=trajectory())


def audit(record):
    assert record['schema_version'] == 'sporespore_r10ai_concurrent_load_rise_closure_v1'
    assert record['ledger_scope'] == SCOPE and record['claim_boundary'] == CLAIMS and record['source_commit'] == HEAD
    for item in [record['auditor'],*record['bindings']]: assert bind(item['path']) == item, item['path']
    frozen_sources()
    assert record['observed'] == observations()
    return dict(ok=True, safety_stages=75, safety_tests=258, consumer_cases=13,
        solver_steps=1113, raise_commands=600, terminal_failure_code='phase_timeout:raise_body', **CLAIMS)


def create():
    assert not RECORD.exists()
    frozen_sources(); observed = observations()
    paths = {p for root in (RUN,SOURCE_BYTES,*fixture_roots().values()) for p in root.rglob('*') if p.is_file()}
    paths.update([TOKEN, KEY, CONTRACT, reports.CATALOG, Path(streams.__file__),
        Path(streams.diagnosis.__file__), Path(geometry.__file__), Path(reports.__file__)])
    record = dict(schema_version='sporespore_r10ai_concurrent_load_rise_closure_v1',
        ledger_scope=SCOPE, source_commit=HEAD, evidence_root=RUN.as_posix(), auditor=bind(__file__),
        bindings=[bind(p) for p in sorted(paths)], observed=observed, claim_boundary=CLAIMS,
        next_action='Use retained-data tracking and planner-feasibility analysis to explain the tilted boundary stall. '
            'Declare a distinct successor before changing control or physical execution. Do not reuse this population, '
            'renew key v14, widen its deadline, or treat its diagnostic gate as official qualification.')
    result = audit(record); write_new(RECORD, record); return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('--create', action='store_true')
    args = parser.parse_args(); print(json.dumps(create() if args.create else audit(read(RECORD)),indent=2))
