"""Close the consumed R10Z diagnostic and describe its retained support trajectory.

This reads original bytes only. It never launches physics, renews qualification,
regrades a task, or permits another use of the consumed phase-248 population.
"""
import argparse
import hashlib
import json
import mmap
from pathlib import Path
import re
import subprocess

import r10y_partial_recovery_diagnosis as diagnosis
import r10y_hold_report_component as history
import r10v_development_launch as gate_reader
import qsdk_r10f_l15_launch_relationship as ownership

ROOT, EVIDENCE = diagnosis.ROOT, diagnosis.EVIDENCE
RUN = EVIDENCE / 'development-recovery-smoke-1db441b1af33456aab4d0248d80c3ba1'
WRAPPER = EVIDENCE / 'r10z-first-smoke-launch-827b4ecd465343a8ad856bed3f8d3465'
CHILD = RUN / 'children/kick_passive_recovery_resume'
TOKEN = EVIDENCE / 'r10z_first_support_diagnostic_51008_consumption_v1.json'
HEAD = '1107e1f986f75d1747e7e654f34262134abfc755'
CONTRACT = ROOT / 'sdk/development/r10z_safety_stage_contract_v1.json'
KEY = ROOT / 'sdk/recovery/r10z_v56_walking_entry_contract_v10.json'
RECORD = ROOT / 'sdk/recovery/r10z_first_support_diagnostic_closure_v1.json'
REPORT_SHA = 'sha256:280d9b7f675d7eb0d192233cbc200676701616dbc2b57f34c70f43644787a4df'
read = lambda p: json.loads(Path(p).read_text(encoding='utf-8-sig'))
binding = diagnosis.binding


def small_fields(path, maximum=65536):
    """Read bounded top-level values without loading the 250 MB report DOM."""
    result = {}
    with path.open('rb') as stream, mmap.mmap(stream.fileno(), 0, access=mmap.ACCESS_READ) as raw:
        rows = list(re.finditer(rb'^  "([a-zA-Z0-9_]+)":', raw, re.M))
        assert rows
        for index, match in enumerate(rows):
            end = rows[index + 1].start() if index + 1 < len(rows) else len(raw) - 2
            if end - match.end() <= maximum:
                key = match[1].decode('ascii')
                assert key not in result
                result[key] = json.loads(raw[match.end():end].decode('utf-8').strip().removesuffix(','))
    return result


def partial_records(path):
    """Fixed-layout reader for this exact hash-bound R10Z report namespace."""
    found = closed = False
    with path.open(encoding='utf-8') as stream:
        for line in stream:
            if not line.startswith('  "r10z_partial_recovery": {'):
                continue
            assert not found
            found = True
            for line in stream:
                if line.startswith('    "step_packets": ['):
                    lines = []
                    for line in stream:
                        if line.startswith('    ]'):
                            assert not lines
                            break
                        lines.append(line)
                        if line.startswith('      }'):
                            yield 'packet', json.loads(''.join(lines).rstrip().removesuffix(','))
                            lines = []
                    else:
                        raise AssertionError('UNTERMINATED_PARTIAL_PACKETS')
                elif line.startswith(('    "declaration": {', '    "final_memory": {')):
                    key, lines = line.split('"')[1], ['{\n']
                    for line in stream:
                        lines.append(line)
                        if line.startswith('    }'):
                            break
                    yield key, json.loads(''.join(lines).rstrip().removesuffix(','))
                elif line.startswith('  }'):
                    closed = True
                    break
    assert found and closed


def frozen_sources():
    """Verify the original key against Git, independent of the later checkout."""
    rows = read(KEY)['bound_source_files']
    assert len(rows) == len({r['path'] for r in rows}) == 1428
    request = ''.join(HEAD + ':' + r['path'] + '\n' for r in rows).encode()
    process = subprocess.run(['git', 'cat-file', '--batch'], input=request, cwd=ROOT,
        capture_output=True, timeout=60, check=True, creationflags=subprocess.CREATE_NO_WINDOW)
    assert not process.stderr
    raw, cursor = process.stdout, 0
    for row in rows:
        end = raw.index(b'\n', cursor)
        header = raw[cursor:end].split()
        assert len(header) == 3 and header[1] == b'blob', row['path']
        length = int(header[2]); content = raw[end + 1:end + 1 + length]
        cursor = end + 2 + length
        # Older unchanged Windows sources can have normalized Git text blobs.
        assert history.raw_matches(content, row) or (b'\r\n' not in content and
            history.raw_matches(content.replace(b'\n', b'\r\n'), row)), row['path']
    assert cursor == len(raw)


def trajectory():
    report = CHILD / 'worker_report.json'
    assert binding(report)['raw_sha256'] == REPORT_SHA
    metadata, rows, previous, plans = {}, [], None, []
    for kind, value in partial_records(report):
        if kind != 'packet':
            assert kind not in metadata
            metadata[kind] = value
            continue
        assert value['ok'] is True and value['call']['value'] == value['native_receipt']
        receipt = value['native_receipt']
        if previous is not None:
            assert value['prior_memory'] == previous
        row = diagnosis.snapshot(value)
        plan = receipt['next_geometry_plan']
        row['geometry_plan'] = plan
        plans.append(plan)
        assert row['partial_step'] == len(rows) + 1 and row['semantic_step'] == len(rows) + 513
        assert row['prior_phase'] == 'establish_distal_support'
        rows.append(row); previous = receipt['step']['memory']
    assert len(rows) == 240 and metadata['final_memory'] == previous
    assert previous['phase'] == 'failed' and previous['terminal_failure_code'] == 'phase_timeout:establish_distal_support'
    assert previous['total_steps_observed'] == previous['phase_steps_observed'] == 240
    fields = ('torso_up_dot', 'torso_height_ratio', 'center_of_mass_height_gain_m',
        'minimum_nonfoot_clearance_m', 'maximum_nonfoot_contact_impulse_ns',
        'terminal_linear_speed_m_s', 'terminal_angular_speed_rad_s', 'minimum_distal_bearing_impulse_ns')
    gates = ('all_four_distal_sites_bearing', 'distal_support_gate', 'raised_body_gate',
        'safety_gate', 'stable_stance_gate', 'joint_limits_respected', 'actuator_budget_respected', 'any_nonfoot_contact')
    ranges = {k: [min(r['classification'][k] for r in rows), max(r['classification'][k] for r in rows)] for k in fields}
    counts = {k: sum(r['classification'][k] for r in rows) for k in gates}
    assert counts['distal_support_gate'] == counts['all_four_distal_sites_bearing'] == 0
    assert counts['joint_limits_respected'] == 232
    assert counts['actuator_budget_respected'] == counts['any_nonfoot_contact'] == 240
    assert plans[-1] is None and all(p is not None and p['hold_reason'] is None and p['feasible_candidate_count'] > 0 for p in plans[:-1])
    initial = metadata['declaration']['entry_request']['passive_request']['observation']
    entry_joints = [j['position_rad'] for j in initial['state']['ordered_joint_observations']]
    entry_rotation = initial['state']['base_pose_world']['orientation_xyzw']
    snapshots = [r for r in rows if r['partial_step'] == 1 or r['partial_step'] % 30 == 0]
    preceding = read(ROOT / 'sdk/recovery/r10y_first_support_diagnostic_closure_v1.json')['observed']['diagnostic']
    active = plans[:-1]
    geometry = dict(active_plans=len(active), held_plans=0,
        bearing_reference_counts={str(n): sum(p['bearing_reference_count'] == n for p in active) for n in (0, 1, 2, 3, 4)},
        feasible_candidate_range=[min(p['feasible_candidate_count'] for p in active), max(p['feasible_candidate_count'] for p in active)],
        upward_virtual_translations=sum(p['selected_virtual_translation_world_m'][1] > 0 for p in active),
        selected_cost_improvements=sum(p['selected_model_cost'] < p['initial_model_cost'] for p in active),
        initial_model_cost_first=active[0]['initial_model_cost'], initial_model_cost_last=active[-1]['initial_model_cost'],
        measured_initial_cost_minimum=min(p['initial_model_cost'] for p in active),
        model_is_not_dynamics=True)
    return dict(partial_steps=240, final_memory=previous, ranges=ranges, gate_counts=counts,
        raw_contact_flag_all_four_samples=sum(all(r['foot_bearing']) for r in rows),
        first_raw_contact_loss=next((r['partial_step'] for r in rows if not all(r['foot_bearing'])), None),
        joint_limit_failed_steps=[r['partial_step'] for r in rows if not r['classification']['joint_limits_respected']],
        entry_joint_positions_rad=entry_joints, entry_orientation_xyzw=entry_rotation,
        prior_r10y_entry_joints_equal=entry_joints == preceding['entry_joint_positions_rad'],
        prior_r10y_entry_rotation_equal=entry_rotation == preceding['entry_orientation_xyzw'],
        prior_r10y_ranges=preceding['ranges'], geometry_summary=geometry, snapshots=snapshots,
        comparison_is_descriptive=True, matched_effect_authority=False)


def observations():
    frozen_sources()
    supervisor, declaration, launch = [read(RUN / f) for f in ('supervisor_result.json', 'declaration.json', 'r10z_development_launch.json')]
    assert supervisor['ok'] is True and supervisor['failure_code'] == '' and supervisor['physical_attempt_started'] is True
    assert read(WRAPPER / 'execution.json')['exit_code'] == 0
    assert supervisor['source_snapshot'] == declaration['source_snapshot'] == dict(head=HEAD, dirty=False, status=[], changed_file_bindings=[])
    assert supervisor['safety_stages'] == declaration['safety_stages']
    assert len(supervisor['safety_stages']) == 52 and sum(s['test_count'] for s in supervisor['safety_stages']) == 176
    assert launch['safety_logs'] == gate_reader.safety(RUN / 'declaration.json', declaration, contract_path=CONTRACT)
    assert launch['safety_contract'] == gate_reader.binding(CONTRACT) and launch['declaration'] == gate_reader.binding(RUN / 'declaration.json')
    assert launch['stage_reservation'] == gate_reader.binding(TOKEN)
    token = read(TOKEN)
    assert token['attempt_id'] == declaration['attempt_id'] == RUN.name.removeprefix('development-recovery-smoke-')
    assert token['source_commit'] == HEAD and token['seed'] == declaration['seed'] == 51008 and token['attempt_limit'] == 1
    assert token['declaration'] == gate_reader.binding(RUN / 'declaration.json')
    assert launch['freeze'] == dict(root=ROOT.as_posix(), remote='https://github.com/Slagathore/sporespore.git', branch='main',
        head=HEAD, origin_main=HEAD, live_origin_main=HEAD, clean=True)
    envelope = small_fields(CHILD / 'child_envelope.json')
    termination = small_fields(CHILD / 'termination_receipt.json')
    context = json.loads(termination['r10f_l15_launch_relationship']['payload_json'])['context']
    descriptor = read(CHILD / 'child_attempt_identity.json')
    assert context['parent_attempt_id'] == token['attempt_id'] and context['child_attempt_id'] == descriptor['child_attempt_id']
    assert context['source_commit'] == HEAD and context['termination_nonce'] == descriptor['termination_nonce']
    assert context['root_image'] == declaration['runtime']['images']['godot_console']
    assert context['worker_image'] == declaration['runtime']['images']['godot_engine']
    ownership.validate_child_launch(envelope, context)
    assert termination['exit_code'] == 0 and termination['timed_out'] is False
    assert termination['supervisor_terminated'] is True and termination['termination_protocol_valid'] is True
    assert read(CHILD / 'engine_health.json')['passed'] is True
    released = read(CHILD / 'payload_release_receipt.json')
    assert released['retained_envelope'] == binding(CHILD / 'child_envelope.json')
    for row in released['verified_artifacts'].values():
        assert row == binding(Path(row['path']))
    report = small_fields(CHILD / 'worker_report.json')
    assert report['ok'] is True and report['source_commit'] == HEAD and report['seed'] == 51008
    assert report['child_attempt_id'] == descriptor['child_attempt_id']
    assert report['world_build_count'] == report['world_attempt_count'] == report['external_kick_application_count'] == 1
    assert report['solver_step_count'] == report['global_solver_frame_count'] == 752
    assert report['held_out'] is False and report['held_out_cell_access_count'] == 0
    audit = read(RUN / 'independent_audit.stdout.json')
    assert audit == supervisor['independent_audit'] and audit['ok'] is True and audit['total_solver_steps'] == 752
    finite = audit['r10z_finite_development']
    assert finite['all_tasks_positive'] is False and finite['branch_coverage_complete'] is True
    assert finite['paired_commissioning_satisfied'] is False and len(finite['cells']) == 1
    assert finite['cells'][0]['entry_kind'] == 'partial' and finite['cells'][0]['post_recovery_handoff'] == 'not_reached'
    replay = audit['children'][0]['passive_entry_replay']
    assert replay['ok'] is True and replay['input_raw_sha256'] == REPORT_SHA
    assert replay['complete_report_timeline_replayed'] is True and replay['transition_count'] == 752
    assert replay['partial_observation_count'] == 240 and replay['world_build_count'] == replay['solver_step_count'] == 0
    assert read(CHILD / 'passive_entry_replay/execution.json')['returncode'] == 0
    trace = trajectory()
    return dict(execution_valid=True, outcome='negative', source_commit=HEAD, seed=51008, prefix_phase=248,
        safety_stages=52, safety_tests=176, worlds=1, external_kicks=1, solver_steps=752,
        partial_steps=240, terminal_failure_code='phase_timeout:establish_distal_support',
        native_replay_passed=True, independent_audit_passed=True, supervisor_completed=True,
        full_later_route_covered=False, walking_reached=False, paired_commissioning_satisfied=False,
        population_consumed=True, retry_permitted=False, physical_acceptance_authority=False,
        release_authority=False, diagnostic=trace)


def capture():
    assert not RECORD.exists()
    observed = observations()
    files = [p for folder in [RUN, WRAPPER] for p in sorted(folder.rglob('*')) if p.is_file()] + [TOKEN]
    value = dict(schema_version='sporespore_r10z_first_support_diagnostic_closure_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='retained_single_kick_development_closure', question_class='development'),
        source_commit=HEAD, evidence_root=RUN.as_posix(),
        dependencies=[binding(p) for p in [Path(__file__), KEY, CONTRACT, diagnosis.RECORD]],
        retained_evidence=[binding(p) for p in files], observed=observed,
        diagnostic_dependencies=[binding(ROOT / 'sdk/conformance/r10y_partial_recovery_diagnosis.py'), binding(ROOT / 'sdk/recovery/r10y_first_support_diagnostic_closure_v1.json')],
        next_action='Diagnose why 239 active feasible geometry plans fail to establish four-foot support; use a distinct prospectively declared successor. Do not repeat R10Z, widen its deadline, renew its consumed v10 key or proceed to commissioning.',
        held_out_worlds_opened=0, post_exposure_regraded=False, physical_acceptance_authority=False, release_authority=False)
    with RECORD.open('x', encoding='utf-8', newline='\n') as stream:
        stream.write(json.dumps(value, indent=2, allow_nan=False) + '\n')
    return observed


def audit():
    value = read(RECORD)
    for row in value['dependencies'] + value['retained_evidence']:
        assert row == binding(Path(row['path'])), row['path']
    for row in value['diagnostic_dependencies']:
        assert row == binding(Path(row['path']))
    observed = observations()
    assert observed == value['observed']
    return observed


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', action='store_true')
    args = parser.parse_args()
    value = capture() if args.capture else audit()
    print('R10Z_FIRST_SUPPORT_CLOSURE ' + json.dumps({k: v for k, v in value.items() if k != 'diagnostic'}), flush=True)
