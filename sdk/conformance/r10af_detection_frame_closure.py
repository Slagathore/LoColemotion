"""Close the consumed R10AF valid negative and describe its retained trajectory."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import subprocess

import r10af_development as identity
import r10ab_first_support_closure as streams
import qsdk_r10f_l15_launch_relationship as ownership
from r10ae_replay_invalid_closure import ROOT, EVIDENCE, read, bind, write_new

HEAD = 'eb5e71887751dee4dd2f44de061a65d08935b12d'
RUN = EVIDENCE / 'development-recovery-smoke-f5a5ac2a67364a88a5d4d349e2812cfd'
CHILD = RUN / 'children/kick_passive_recovery_resume'
OUTER = EVIDENCE / 'r10af-full-supervisor-499b97429c824db1b891fc5e67e46a30'
TOKEN = EVIDENCE / 'r10af_contact_frame_diagnostic_64248_consumption_v1.json'
KEY = ROOT / 'sdk/recovery/r10af_v56_walking_entry_contract_v7.json'
CONTRACT = ROOT / 'sdk/development/r10af_safety_stage_contract_v1.json'
RECORD = ROOT / 'sdk/recovery/r10af_detection_frame_diagnostic_closure_v1.json'
REPORT_SHA = 'sha256:7987544a7429a8c7d546601b4dd71509744da5a7c52ad0631a70e2fa9435cb2d'
CLAIMS = dict(outcome='valid_development_negative', population_consumed=True,
    rerun_authorized=False, detection_frame_production_path_exercised=True,
    recovery_success_obtained=False, paired_commissioning_satisfied=False,
    comparative_authority=False, causal_repair_proven=False,
    physical_acceptance_authority=False, release_authority=False,
    sdk1_score='14/20', full_program_score='14/25')


def frozen_sources():
    rows = read(KEY)['bound_source_files']
    assert len(rows) == len({row['path'] for row in rows}) == 1989
    result = subprocess.run(['git', 'cat-file', '--batch'], cwd=ROOT,
        input=''.join(HEAD + ':' + row['path'] + '\n' for row in rows).encode(),
        capture_output=True, timeout=60, check=True, creationflags=subprocess.CREATE_NO_WINDOW)
    assert not result.stderr
    raw, cursor = result.stdout, 0
    for row in rows:
        end = raw.index(b'\n', cursor); header = raw[cursor:end].split()
        assert len(header) == 3 and header[1] == b'blob', row['path']
        size = int(header[2]); data = raw[end + 1:end + 1 + size]; cursor = end + 2 + size
        variants = [data] if b'\r\n' in data else [data, data.replace(b'\n', b'\r\n')]
        assert any(len(value) == row['byte_length'] and 'sha256:' + hashlib.sha256(value).hexdigest() == row['raw_sha256'] for value in variants), row['path']
    assert cursor == len(raw)


def trajectory():
    """Stream the hash-bound original packets without a whole-report memory copy."""
    report = CHILD / 'worker_report.json'
    assert bind(report)['raw_sha256'] == REPORT_SHA
    rows, metadata, previous = [], {}, None
    for kind, value in streams.partial_records(report):
        if kind != 'packet':
            assert kind not in metadata; metadata[kind] = value; continue
        assert value['ok'] is True and value['call']['value'] == value['native_receipt']
        if previous is not None: assert value['prior_memory'] == previous
        row = streams.diagnosis.snapshot(value)
        row['load_plan'] = value['native_receipt']['next_load_plan']
        assert row['partial_step'] == len(rows) + 1 and row['semantic_step'] == len(rows) + 513
        rows.append(row); previous = value['native_receipt']['step']['memory']
    assert len(rows) == 601 and metadata['final_memory'] == previous
    assert previous['phase'] == 'failed' and previous['terminal_failure_code'] == 'phase_timeout:raise_body'
    assert previous['phase_steps_observed'] == 600 and previous['ordered_completed_phases'] == ['establish_distal_support']
    assert [r['prior_phase'] for r in rows] == ['establish_distal_support'] + ['raise_body'] * 600
    fields = ('torso_up_dot', 'torso_height_ratio', 'center_of_mass_height_gain_m',
        'minimum_nonfoot_clearance_m', 'maximum_nonfoot_contact_impulse_ns',
        'terminal_linear_speed_m_s', 'terminal_angular_speed_rad_s', 'minimum_distal_bearing_impulse_ns')
    gates = ('all_four_distal_sites_bearing', 'distal_support_gate', 'raised_body_gate',
        'safety_gate', 'stable_stance_gate', 'joint_limits_respected', 'actuator_budget_respected', 'any_nonfoot_contact')
    phases = []
    for phase in ('establish_distal_support', 'raise_body'):
        selected = [r for r in rows if r['prior_phase'] == phase]
        phases.append(dict(phase=phase, count=len(selected),
            ranges={k: [min(r['classification'][k] for r in selected), max(r['classification'][k] for r in selected)] for k in fields},
            gate_counts={k: sum(r['classification'][k] for r in selected) for k in gates}))
    assert phases[1]['gate_counts']['distal_support_gate'] == 138
    assert phases[1]['gate_counts']['joint_limits_respected'] == 585
    assert phases[1]['gate_counts']['actuator_budget_respected'] == 600
    assert all(p['gate_counts']['raised_body_gate'] == p['gate_counts']['safety_gate'] == 0 for p in phases)
    plans = [r['load_plan'] for r in rows[:-1]]
    assert rows[-1]['load_plan'] is None and all(p is not None for p in plans)
    modes = dict(Counter(p['mode'] for p in plans))
    assert modes == dict(loaded_downward_rise=138, seek_distal_load=462)
    following = [rows[i + 1] for i, plan in enumerate(plans) if plan['mode'] == 'loaded_downward_rise']
    lost = sum(not row['classification']['distal_support_gate'] for row in following)
    assert lost == 93
    for plan in plans:
        if plan['mode'] == 'loaded_downward_rise': assert plan['rise_geometry']['downward_feasible_candidate_count'] > 0
    indices = {0, 1, 600, *range(59, 600, 60)}
    return dict(partial_steps=601, support_commands=1, raise_commands=600,
        phase_summary=phases, original_final_memory=previous,
        controller_duty_cycle=dict(mode_counts=modes, immediately_after_rise_samples=len(following),
            immediately_after_rise_lost_distal_support=lost,
            unqualified_plan_counts_by_foot=[sum(not p['qualified_support'][i] for p in plans) for i in range(4)],
            selected_scales=sorted(set(p['selected_scale'] for p in plans))),
        snapshots=[rows[i] for i in sorted(indices)],
        inference='The detection-frame route is valid, but raising remains incomplete. Qualified support is intermittent; 93 of 138 loaded rises are followed by loss of distal support. Fifteen raise samples violate the joint-limit predicate. These observations motivate one-step target/motion and limit analysis, not a causal comparison or deadline extension.',
        original_result_regraded=False, comparative_authority=False)


def observations():
    declaration, supervisor = read(RUN / 'declaration.json'), read(RUN / 'supervisor_result.json')
    identity.validate_declaration(declaration)
    assert supervisor['ok'] is True and supervisor['failure_code'] == '' and supervisor['physical_attempt_started'] is True
    assert declaration['source_snapshot'] == supervisor['source_snapshot'] == dict(head=HEAD, dirty=False, status=[], changed_file_bindings=[])
    marker = (RUN / 'published_marker.txt').read_text().strip()
    assert marker.startswith('DEVELOPMENT_RECOVERY_SMOKE_COMPLETE ') and json.loads(marker.split(' ', 1)[1]) == supervisor
    assert read(OUTER / 'terminal.json')['returncode'] == 0
    launch, token, contract = read(RUN / 'r10af_development_launch.json'), read(TOKEN), read(CONTRACT)
    assert token['attempt_id'] == declaration['attempt_id'] == launch['attempt_id'] and token['source_commit'] == HEAD
    assert token['seed'] == declaration['seed'] == 64248 and token['attempt_limit'] == 1
    assert launch['declaration'] == streams.gate_reader.binding(RUN / 'declaration.json')
    assert launch['stage_reservation'] == streams.gate_reader.binding(TOKEN)
    assert launch['source_key'] == streams.gate_reader.binding(KEY)
    assert launch['freeze'] == dict(root=ROOT.as_posix(), remote='https://github.com/Slagathore/sporespore.git', branch='main', head=HEAD, origin_main=HEAD, live_origin_main=HEAD, clean=True)
    stages = declaration['safety_stages']
    assert stages == supervisor['safety_stages'] and len(stages) == len(contract['stages']) == 65
    assert sum(row['test_count'] for row in stages) == contract['total_tests'] == 239
    for row, spec in zip(stages, contract['stages'], strict=True):
        assert row['id'] == spec['id'] and row['passed'] is True and row['timed_out'] is False and row['exit_code'] == 0
        assert row['test_count'] == row['expected_test_count'] == spec['tests']
        for stream in ('stdout', 'stderr'): assert bind(RUN / row[stream])['raw_sha256'] == 'sha256:' + row[stream + '_sha256']
    envelope = streams.small_fields(CHILD / 'child_envelope.json')
    termination = streams.small_fields(CHILD / 'termination_receipt.json')
    context = json.loads(termination['r10f_l15_launch_relationship']['payload_json'])['context']
    assert context['parent_attempt_id'] == token['attempt_id'] and context['source_commit'] == HEAD
    assert context['root_image'] == declaration['runtime']['images']['godot_console'] and context['worker_image'] == declaration['runtime']['images']['godot_engine']
    ownership.validate_child_launch(envelope, context)
    assert termination['exit_code'] == 0 and termination['timed_out'] is False and termination['termination_protocol_valid'] is True
    assert read(CHILD / 'engine_health.json')['passed'] is True
    release = read(CHILD / 'payload_release_receipt.json')
    assert release['retained_envelope'] == bind(CHILD / 'child_envelope.json')
    assert release['original_evidence_rewritten'] is False and release['launch_relationship_valid'] is True
    for item in release['verified_artifacts'].values(): assert bind(item['path']) == item
    report = streams.small_fields(CHILD / 'worker_report.json'); identity.validate_report_header(report, declaration)
    assert report['world_build_count'] == report['world_attempt_count'] == report['external_kick_application_count'] == 1
    assert report['solver_step_count'] == report['global_solver_frame_count'] == 1113
    assert report['coverage_complete'] is False and report['held_out_cell_access_count'] == 0
    replay = read(CHILD / 'passive_entry_replay_result.json')
    assert replay['ok'] is True and replay['controller_and_diagnostic_replay_passed'] is True
    assert replay['input_raw_sha256'] == REPORT_SHA and replay['transition_count'] == 1113 and replay['partial_observation_count'] == 601
    execution = read(CHILD / 'passive_entry_replay/execution.json')
    assert execution['returncode'] == 0 and execution['timed_out'] is False and execution['input_raw_sha256'] == REPORT_SHA
    independent = read(RUN / 'independent_audit.stdout.json')
    assert independent == supervisor['independent_audit'] and independent['ok'] is True and independent['total_solver_steps'] == 1113
    result = independent['r10af_contact_frame_diagnostic']
    assert result['all_tasks_positive'] is False and result['branch_coverage_complete'] is True and result['paired_commissioning_satisfied'] is False
    assert len(result['cells']) == 1 and result['cells'][0]['measurement']['walking']['status'] == 'walking_not_reached'
    contacts = result['contact_frame_replay']
    assert contacts == replay['r10af_contact_frame_replay'] and contacts['ok'] is True
    assert contacts['diagnostic_steps_replayed'] == 1113 and contacts['matched_source_contacts'] == 6106 and contacts['classification_changes'] == 683
    assert contacts['controller_observation_changed'] is True and contacts['original_observation_hash_chain_verified'] is True
    return dict(execution_valid=True, source_commit=HEAD, seed=64248, exposed_prefix_phase=248,
        safety_stages=65, safety_tests=239, worlds=1, kicks=1, solver_steps=1113,
        native_replay_passed=True, independent_contact_replay_passed=True, final_audit_passed=True,
        matched_source_contacts=6106, classification_changes=683,
        terminal_failure_code='phase_timeout:raise_body', walking_reached=False, diagnostic=trajectory())


def audit(record):
    assert record['claim_boundary'] == CLAIMS and record['source_commit'] == HEAD
    for item in record['bindings'] + [record['auditor']]: assert bind(item['path']) == item, item['path']
    frozen_sources(); assert record['observed'] == observations()
    return dict(ok=True, **{k: v for k, v in record['observed'].items() if k != 'diagnostic'}, **CLAIMS)


def create():
    assert not RECORD.exists()
    frozen_sources(); observed = observations()
    paths = [p for folder in (RUN, OUTER) for p in sorted(folder.rglob('*')) if p.is_file()]
    paths += [TOKEN, KEY, CONTRACT, Path(streams.__file__), Path(streams.diagnosis.__file__), Path(identity.__file__)]
    record = dict(schema_version='sporespore_r10af_detection_frame_diagnostic_closure_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='retained_single_kick_development_closure', question_class='development'),
        source_commit=HEAD, evidence_root=RUN.as_posix(), auditor=bind(__file__),
        bindings=[bind(p) for p in paths], observed=observed, claim_boundary=CLAIMS,
        next_action='Analyze measured one-step foot motion, joint tracking and boundary violations against the selected rise plans before declaring a distinct successor. Do not repeat seed 64248, widen this deadline, refresh its consumed source key or claim paired commissioning.')
    result = audit(record); write_new(RECORD, record); return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('--create', action='store_true')
    args = parser.parse_args()
    print(json.dumps(create() if args.create else audit(read(RECORD))))
