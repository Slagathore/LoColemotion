"""Close the consumed R10AB diagnostic and describe its retained support and rise trajectory.

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
RUN = EVIDENCE / 'development-recovery-smoke-40b03380b27b4a86b89894446ab7c29c'
CHILD = RUN / 'children/kick_passive_recovery_resume'
TOKEN = EVIDENCE / 'r10ab_first_support_diagnostic_51008_consumption_v1.json'
HEAD = 'e0951b93f2833d74292d85011369e94cdbfca655'
CONTRACT = ROOT / 'sdk/development/r10ab_safety_stage_contract_v1.json'
KEY = ROOT / 'sdk/recovery/r10ab_v56_walking_entry_contract_v6.json'
PREDECESSOR = ROOT / 'sdk/recovery/r10aa_first_support_diagnostic_closure_v1.json'
RECORD = ROOT / 'sdk/recovery/r10ab_first_support_diagnostic_closure_v1.json'
REPORT_SHA = 'sha256:f97945b1e03481490a2b520a3973761f66c422653e407f3c81a678fc938eba7d'
read = lambda p: json.loads(Path(p).read_text(encoding='utf-8-sig'))
binding = diagnosis.binding


def small_fields(path, maximum=65536):
    """Read bounded top-level values without loading the full report DOM."""
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
    """Fixed-layout reader for this exact hash-bound R10AB report namespace."""
    found = closed = False
    with path.open(encoding='utf-8') as stream:
        for line in stream:
            if not line.startswith('  "r10ab_partial_recovery": {'):
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
    assert len(rows) == len({r['path'] for r in rows}) == 1666
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
    """Describe the observed support/rise duty cycle without changing its grade."""
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
        plan = receipt['next_load_plan']
        row['load_plan'] = plan
        plans.append(plan)
        assert row['partial_step'] == len(rows) + 1 and row['semantic_step'] == len(rows) + 513
        rows.append(row); previous = receipt['step']['memory']
    assert len(rows) == 646 and metadata['final_memory'] == previous
    assert previous['phase'] == 'failed' and previous['terminal_failure_code'] == 'phase_timeout:raise_body'
    assert previous['total_steps_observed'] == 646 and previous['phase_steps_observed'] == 600
    assert previous['ordered_completed_phases'] == ['establish_distal_support']
    assert [row['prior_phase'] for row in rows] == ['establish_distal_support'] * 46 + ['raise_body'] * 600
    assert rows[45]['next_phase'] == 'raise_body'
    fields = ('torso_up_dot', 'torso_height_ratio', 'center_of_mass_height_gain_m',
        'minimum_nonfoot_clearance_m', 'maximum_nonfoot_contact_impulse_ns',
        'terminal_linear_speed_m_s', 'terminal_angular_speed_rad_s', 'minimum_distal_bearing_impulse_ns')
    gates = ('all_four_distal_sites_bearing', 'distal_support_gate', 'raised_body_gate',
        'safety_gate', 'stable_stance_gate', 'joint_limits_respected', 'actuator_budget_respected', 'any_nonfoot_contact')
    phases = []
    for phase in ('establish_distal_support', 'raise_body'):
        selected = [row for row in rows if row['prior_phase'] == phase]
        phases.append(dict(phase=phase, count=len(selected),
            ranges={k: [min(r['classification'][k] for r in selected), max(r['classification'][k] for r in selected)] for k in fields},
            gate_counts={k: sum(r['classification'][k] for r in selected) for k in gates}))
    assert phases[0]['gate_counts']['distal_support_gate'] == 1
    assert phases[1]['gate_counts']['distal_support_gate'] == 33
    assert all(p['gate_counts']['raised_body_gate'] == 0 for p in phases)
    assert all(p['gate_counts']['joint_limits_respected'] == p['gate_counts']['actuator_budget_respected'] == p['gate_counts']['any_nonfoot_contact'] == p['count'] for p in phases)
    active = plans[:-1]
    assert plans[-1] is None and all(p is not None and p['hold_reason'] is None for p in active)
    for plan in active:
        assert plan['feasible_candidate_count'] > 0
        if plan['mode'] == 'loaded_downward_rise':
            # Every selected loaded rise came from the downward-feasible subset.
            assert plan['rise_geometry']['downward_feasible_candidate_count'] > 0
    modes = {mode: sum(p['mode'] == mode for p in active) for mode in ('seek_distal_load', 'loaded_downward_rise', 'hold_qualified_support')}
    assert modes == dict(seek_distal_load=611, loaded_downward_rise=34, hold_qualified_support=0)
    after_rise = [rows[i+1] for i, p in enumerate(active) if p['mode'] == 'loaded_downward_rise']
    diagnostics = dict(active_plans=len(active), held_plans=0, mode_counts=modes,
        immediately_after_rise_samples=len(after_rise),
        immediately_after_rise_lost_distal_support=sum(not r['classification']['distal_support_gate'] for r in after_rise),
        unqualified_plan_counts_by_foot=[sum(not p['qualified_support'][i] for p in active) for i in range(4)],
        deficit_ranges_by_foot=[[min(p['load_deficit_fraction'][i] for p in active), max(p['load_deficit_fraction'][i] for p in active)] for i in range(4)],
        selected_scales=sorted(set(p['selected_scale'] for p in active)))
    selected_indices = {0,45,46,645}
    selected_indices.update(i for i, row in enumerate(rows) if row['partial_step'] % 60 == 0)
    initial = metadata['declaration']['entry_request']['passive_request']['observation']
    return dict(partial_steps=646, support_commands=46, raise_commands=600,
        phase_summary=phases, original_final_memory=previous,
        entry_joint_positions_rad=[j['position_rad'] for j in initial['state']['ordered_joint_observations']],
        entry_orientation_xyzw=initial['state']['base_pose_world']['orientation_xyzw'],
        controller_duty_cycle=diagnostics, snapshots=[rows[i] for i in sorted(selected_indices)],
        comparison_to_r10aa=comparison(phases, diagnostics),
        inference='Support seeking reproduces R10AA exactly. The downward-foot rise engaged 34 times and every loaded rise was again followed by loss of distal support, with fewer rises, fewer supported samples and less height than R10AA. Keeping modeled feet moving downward did not retain load; the loss mechanism is not established and this is not a matched comparative effect.',
        original_result_regraded=False, comparative_authority=False)


def comparison(phases, diagnostics):
    """Describe the unchanged R10AA closure beside this run; no matched effect."""
    prior = read(PREDECESSOR)['observed']['diagnostic']
    old, new = prior['phase_summary'][1], phases[1]
    keys = ('torso_height_ratio', 'center_of_mass_height_gain_m')
    return dict(r10aa_rise_commands=prior['controller_duty_cycle']['mode_counts']['loaded_geometry_rise'],
        r10ab_rise_commands=diagnostics['mode_counts']['loaded_downward_rise'],
        r10aa_lost_after_rise=prior['controller_duty_cycle']['immediately_after_rise_lost_distal_support'],
        r10ab_lost_after_rise=diagnostics['immediately_after_rise_lost_distal_support'],
        r10aa_supported_raise_samples=old['gate_counts']['distal_support_gate'],
        r10ab_supported_raise_samples=new['gate_counts']['distal_support_gate'],
        r10aa_raise_maxima={k: old['ranges'][k][1] for k in keys},
        r10ab_raise_maxima={k: new['ranges'][k][1] for k in keys},
        support_phase_identical=prior['phase_summary'][0] == phases[0],
        matched_comparison=False)


def observations():
    frozen_sources()
    supervisor, declaration, launch = [read(RUN / f) for f in ('supervisor_result.json', 'declaration.json', 'r10ab_development_launch.json')]
    assert supervisor['ok'] is True and supervisor['failure_code'] == '' and supervisor['physical_attempt_started'] is True
    assert supervisor['source_snapshot'] == declaration['source_snapshot'] == dict(head=HEAD, dirty=False, status=[], changed_file_bindings=[])
    marker = (RUN / 'published_marker.txt').read_text(encoding='utf-8').strip()
    assert marker.startswith('DEVELOPMENT_RECOVERY_SMOKE_COMPLETE ')
    assert json.loads(marker.split(' ', 1)[1]) == supervisor
    assert supervisor['safety_stages'] == declaration['safety_stages']
    assert len(supervisor['safety_stages']) == 54 and sum(s['test_count'] for s in supervisor['safety_stages']) == 178
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
    assert report['solver_step_count'] == report['global_solver_frame_count'] == 1158
    assert report['held_out'] is False and report['held_out_cell_access_count'] == 0
    audit = read(RUN / 'independent_audit.stdout.json')
    assert audit == supervisor['independent_audit'] and audit['ok'] is True and audit['total_solver_steps'] == 1158
    finite = audit['r10ab_finite_development']
    assert finite['all_tasks_positive'] is False and finite['branch_coverage_complete'] is True
    assert finite['paired_commissioning_satisfied'] is False and len(finite['cells']) == 1
    assert finite['cells'][0]['entry_kind'] == 'partial' and finite['cells'][0]['post_recovery_handoff'] == 'not_reached'
    replay = audit['children'][0]['passive_entry_replay']
    assert replay['ok'] is True and replay['input_raw_sha256'] == REPORT_SHA
    assert replay['complete_report_timeline_replayed'] is True and replay['transition_count'] == 1158
    assert replay['partial_observation_count'] == 646 and replay['world_build_count'] == replay['solver_step_count'] == 0
    assert read(CHILD / 'passive_entry_replay/execution.json')['returncode'] == 0
    trace = trajectory()
    return dict(execution_valid=True, outcome='negative', source_commit=HEAD, seed=51008, prefix_phase=248,
        safety_stages=54, safety_tests=178, worlds=1, external_kicks=1, solver_steps=1158,
        partial_steps=646, support_commands=46, raise_commands=600, terminal_failure_code='phase_timeout:raise_body',
        native_replay_passed=True, independent_audit_passed=True, supervisor_completed=True,
        full_later_route_covered=False, walking_reached=False, paired_commissioning_satisfied=False,
        population_consumed=True, retry_permitted=False, physical_acceptance_authority=False,
        release_authority=False, diagnostic=trace)


def capture():
    assert not RECORD.exists()
    observed = observations()
    files = [p for folder in [RUN] for p in sorted(folder.rglob('*')) if p.is_file()] + [TOKEN]
    value = dict(schema_version='sporespore_r10ab_first_support_diagnostic_closure_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='retained_single_kick_development_closure', question_class='development'),
        source_commit=HEAD, evidence_root=RUN.as_posix(),
        dependencies=[binding(p) for p in [Path(__file__), KEY, CONTRACT, ROOT / 'sdk/recovery/r10ab_launcher_component_v1.json', PREDECESSOR]],
        retained_evidence=[binding(p) for p in files], observed=observed,
        diagnostic_dependencies=[binding(ROOT / 'sdk/conformance/r10y_partial_recovery_diagnosis.py')],
        next_action='Diagnose why loaded rise loses distal support even with downward modeled foot motion, using R10AA and R10AB retained inputs, before any distinct prospectively declared successor. Do not repeat R10AB, widen its deadline, renew consumed v6 or proceed to commissioning.',
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
    print('R10AB_FIRST_SUPPORT_CLOSURE ' + json.dumps({k: v for k, v in value.items() if k != 'diagnostic'}), flush=True)
