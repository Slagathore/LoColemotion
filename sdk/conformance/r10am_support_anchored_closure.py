"""Close R10AM's consumed valid negative from original retained bytes only.

No world, replay process, source-key renewal, or result reclassification occurs.
Stream the large physical report to keep this historical audit bounded in memory.
"""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import subprocess
import re

import r10ab_first_support_closure as streams
import r10af_rise_tracking_analysis as geometry
import r10am_development_launch as launch
import r10am_native_world_authority as authority
import r10am_report_gate as reports
import qsdk_r10f_l15_launch_relationship as ownership
from r10ae_replay_invalid_closure import ROOT, EVIDENCE, read, bind, write_new

HEAD = '68451b0d20fd99e0f74e37d26362e5d9f2c750c1'
RUN = EVIDENCE / 'development-recovery-smoke-899ecfdea2914711a39b7b0d5db0b621'
CHILD = RUN / 'children/kick_passive_recovery_resume'
TOKEN = EVIDENCE / 'r10am_support_anchored_diagnostic_69248_consumption_v1.json'
KEY = ROOT / 'sdk/recovery/r10am_v56_walking_entry_contract_v11.json'
CONTRACT = ROOT / 'sdk/development/r10am_safety_stage_contract_v1.json'
OUTER = EVIDENCE / 'r10am-supervisor-invocation-2150fa2d545341659e1dbde1fe315ba7'
RECORD = ROOT / 'sdk/recovery/r10am_support_anchored_closure_v1.json'
SOURCE_BYTES = EVIDENCE / 'r10am-frozen-source-bytes-54510972163e4f34aa6c0fcbb679a93a'
REPORT_SHA = 'sha256:d4f9ba6de5f10404c4272ff256155814ebd224cb0f2a6afe22e288315be2658a'
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
    """Validate the original 2,631-file key against the pushed Git freeze."""
    rows = read(KEY)['bound_source_files']
    assert len(rows) == len({r['path'] for r in rows}) == 2631
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
    rows, previous, previous_command = [], None, None
    modes, reasons = Counter(), Counter()
    supports, positive = [], []
    for packet in geometry.records(report, 'r10am_partial_recovery', 'step_packets'):
        native = packet['native_receipt']
        assert packet['ok'] is True and packet['call']['value'] == native
        if previous is not None:
            assert packet['prior_memory'] == previous
            assert packet['source_application']['command_sha256'] == previous_command
        row = streams.diagnosis.snapshot(packet)
        assert row['partial_step'] == len(rows)+1 and row['semantic_step'] == len(rows)+513
        plan = native['next_load_plan']; row['plan_mode'] = None if plan is None else plan['mode']
        if plan is not None:
            modes[plan['mode']] += 1
            supports.append(plan['baseline_reference']['qualified_support'])
            anchored = plan['support_anchored_geometry']
            if anchored is not None: positive.append(anchored['positive_bearing'])
            reasons[(anchored or {}).get('hold_reason') or 'none'] += 1
            row['support_anchored_geometry'] = anchored
        rows.append(row); previous = native['step']['memory']
        previous_command = None if native['next_control'] is None else native['next_control']['command_sha256']
    assert len(rows) == 601 and previous['phase'] == 'failed' and previous_command is None
    assert previous['terminal_failure_code'] == 'phase_timeout:raise_body'
    assert previous['phase_steps_observed'] == 600 and previous['standing_samples_observed'] == 0
    assert previous['ordered_completed_phases'] == ['establish_distal_support']
    assert [r['prior_phase'] for r in rows] == ['establish_distal_support'] + ['raise_body']*600
    assert dict(modes) == dict(support_anchored_leveling=597, explicit_v23_fallback=3)
    assert dict(reasons) == dict(none=597, no_positive_bearing_plane=3)
    gates = {key:sum(r['classification'][key] for r in rows[1:]) for key in (
        'distal_support_gate','raised_body_gate','stable_stance_gate','safety_gate',
        'joint_limits_respected','actuator_budget_respected','any_nonfoot_contact')}
    assert gates == dict(distal_support_gate=0, raised_body_gate=0, stable_stance_gate=0,
        safety_gate=0, joint_limits_respected=285, actuator_budget_respected=600, any_nonfoot_contact=600)
    first_limit_failure = next(r['partial_step'] for r in rows if not r['classification']['joint_limits_respected'])
    assert first_limit_failure == 15
    support_counts = [sum(q[i] for q in supports) for i in range(4)]
    positive_counts = [sum(q[i] for q in positive) for i in range(4)]
    assert support_counts == [5,8,590,151] and positive_counts == [128,29,597,296]
    fields = ('torso_height_ratio','torso_up_dot','center_of_mass_height_gain_m','minimum_nonfoot_clearance_m')
    return dict(partial_steps=601, support_commands=1, raise_commands=600, command_links=600,
        original_final_memory=previous, mode_counts=dict(modes), hold_reasons=dict(reasons),
        raise_gate_counts=gates, first_joint_limit_failure_partial_step=first_limit_failure,
        measured_joint_limit_failure_samples=315, qualified_support_command_counts=support_counts,
        positive_bearing_command_counts=positive_counts,
        raise_ranges={k:[min(r['classification'][k] for r in rows[1:]),
                         max(r['classification'][k] for r in rows[1:])] for k in fields},
        snapshots=[rows[i] for i in (0,14,60,120,180,240,300,360,420,480,540,600)],
        inference='The torso remains mostly upright but no raising sample regains qualified four-foot support or passes the raised-body gate. '
            'Joint-limit checks fail in 315 of 600 raising samples, first at partial step 15; all actuator-budget checks pass. '
            'Inspect bearing acquisition and loaded joint tracking before selecting a distinct successor. '
            'Geometric anchor closure does not establish force-bearing support, and this single child proves no matched causal effect.',
        original_result_regraded=False, comparative_authority=False)


def observations():
    outer = read(OUTER/'execution.json')
    assert outer['exit_code'] == 0 and read(OUTER/'invocation.json')['source_commit'] == HEAD
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
    assert token['seed'] == declaration['seed'] == 69248 and token['attempt_limit'] == 1
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
    result = independent['r10am_contact_frame_diagnostic']
    assert result['all_tasks_positive'] is False and result['branch_coverage_complete'] is True
    assert result['paired_commissioning_satisfied'] is False and len(result['cells']) == 1
    assert result['cells'][0]['measurement']['walking']['status'] == 'walking_not_reached'
    contacts = result['contact_frame_replay']
    assert contacts == replay['r10af_contact_frame_replay'] and contacts['ok'] is True
    assert contacts['diagnostic_steps_replayed'] == 1113 and contacts['matched_source_contacts'] == 4854 and contacts['classification_changes'] == 304
    return dict(execution_valid=True, source_commit=HEAD, seed=69248, exposed_prefix_phase=248,
        safety_stages=75, safety_tests=258, worlds=1, kicks=1, solver_steps=1113,
        native_replay_passed=True, final_python_consumer_passed=True, final_audit_passed=True,
        terminal_failure_code='phase_timeout:raise_body', walking_reached=False,
        consumer_cases=consumer_results(), physical_measurement=result['cells'][0]['measurement'],
        contact_replay=contacts, diagnostic=trajectory())


def audit(record):
    assert record['evidence_root'] == RUN.as_posix()
    assert [item['path'] for item in record['bindings']] == [p.as_posix() for p in evidence_paths()]
    assert record['schema_version'] == 'sporespore_r10am_support_anchored_closure_v1'
    assert record['ledger_scope'] == SCOPE and record['claim_boundary'] == CLAIMS and record['source_commit'] == HEAD
    for item in [record['auditor'],*record['bindings']]: assert bind(item['path']) == item, item['path']
    frozen_sources()
    assert record['observed'] == observations()
    return dict(ok=True, safety_stages=75, safety_tests=258, consumer_cases=13,
        solver_steps=1113, raise_commands=600, terminal_failure_code='phase_timeout:raise_body', **CLAIMS)


def evidence_paths():
    paths = {p for root in (RUN, OUTER, SOURCE_BYTES, *fixture_roots().values()) for p in root.rglob('*') if p.is_file()}
    for log in RUN.glob('*.stdout.log'):
        for line in log.read_text(encoding='utf-8-sig').splitlines():
            match = re.fullmatch(r'[A-Z0-9_]+(?:ROOT|CHECK|EVIDENCE) (C:[\\/].+)', line)
            if match:
                root = Path(match[1]).resolve()
                assert root.parent == EVIDENCE and root.is_dir()
                paths.update(p for p in root.rglob('*') if p.is_file())
    paths.update([TOKEN, KEY, CONTRACT, reports.CATALOG, Path(streams.__file__),
        Path(streams.diagnosis.__file__), Path(geometry.__file__), Path(reports.__file__)])
    return sorted(paths)


def create():
    assert not RECORD.exists()
    frozen_sources(); observed = observations()
    record = dict(schema_version='sporespore_r10am_support_anchored_closure_v1',
        ledger_scope=SCOPE, source_commit=HEAD, evidence_root=RUN.as_posix(), auditor=bind(__file__),
        bindings=[bind(p) for p in evidence_paths()], observed=observed, claim_boundary=CLAIMS,
        next_action='Diagnose qualified-support acquisition and measured joint-limit tracking on the retained report; the torso remained mostly upright but no raising sample qualified. '
            'Declare a distinct successor before changing control or physical execution. Do not reuse this population, '
            'renew key v11, widen its deadline, or treat its diagnostic gate as official qualification.')
    result = audit(record); write_new(RECORD, record); return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('--create', action='store_true')
    args = parser.parse_args(); print(json.dumps(create() if args.create else audit(read(RECORD)),indent=2))
