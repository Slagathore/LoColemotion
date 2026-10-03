"""Retain the sole physical attempt and independently audit its exact saved report."""
import argparse
import gc
import json
from pathlib import Path
import traceback
import r10dg_identity as I
import r10dg_launch as L
import r10dg_native_world_authority as A

MARKER = b'SPORESPORE_DEVELOPMENT_RECOVERY_SMOKE_RAW '

def audit(path):
    path = Path(path).resolve()
    value = A.verify(path)
    child = value['children'][0]
    folder = Path(child['evidence_path'])
    result = dict(schema_version='sporespore_r10dg_physical_result_audit_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='independent_diagnostic_result_audit', question_class='development'),
        ok=False, disposition='infrastructure_invalid', physical_attempted=True,
        physical_acceptance_authority=False, release_authority=False, pause_after_attempt=True)
    try:
        process = I.read(folder / 'process.json')
        I.require(I.read(folder / 'relationship-audit.json')['ok'] is True, 'OWNED_RELATIONSHIP')
        I.require(process['termination_protocol_valid'] is True and process['supervisor_terminated'] is True
            and process['timed_out'] is False and process['exit_code'] == 0, 'PROCESS_TERMINATION')
        I.require((folder / 'stderr.log').read_bytes() == b'', 'PHYSICAL_STDERR')
        count = 0
        target = folder / 'worker_report.json'
        with (folder / 'stdout.log').open('rb') as source:
            for line in source:
                if line.startswith(MARKER):
                    count += 1
                    I.require(count == 1, 'DUPLICATE_REPORT')
                    with target.open('xb') as output:
                        output.write(line[len(MARKER):].rstrip(b'\r\n'))
        I.require(count == 1, 'REPORT_MISSING')
        report = I.read(target)
        for key in ['physical_acceptance_authority', 'release_authority', 'complete_route_proven', 'held_out']:
            I.require(report.get(key) is False, 'REPORT_CLAIM:' + key)
        I.require('synthetic_test_fixture' not in report and 'report_fixture_only' not in report, 'SYNTHETIC_REPORT')
        I.require(report['source_commit'] == value['source_snapshot']['head']
            and report['parent_attempt_id'] == value['attempt_id'] and report['child_attempt_id'] == child['child_attempt_id']
            and report['seed'] == I.SEED and report['arm_id'] == I.ROLE
            and report['diagnostic_declaration_sha256'] == I.sha(path)
            and report['process_id'] == process['worker_process_id'], 'REPORT_IDENTITY')
        I.require(report['ok'] is True and report['candidate_profile'] == value['candidate_profile'], 'REPORT_PROFILE')
        for key in ['world_build_count', 'world_attempt_count', 'model_construction_count', 'model_construction_attempt_count']:
            I.require(type(report.get(key)) is int and report[key] == 1, 'SINGLE_WORLD:' + key)
        steps = report['solver_step_count']
        I.require(type(steps) is int and 0 < steps <= value['maximum_steps_per_child']
            and report['global_solver_frame_count'] == steps, 'STEP_BUDGET')
        arm = report['retained_arm']
        I.require(len(arm['trace_rows']) == steps, 'TRACE_POPULATION')
        terminal = report['terminal_same_body_identity_receipt']
        I.require(terminal['ok'] is True and terminal['body_population_instance_sha256'] == arm['body_population_instance_sha256'], 'TERMINAL_BODY')
        claim = I.read(folder / I.CLAIM)
        I.require(claim == A.expected_claim(path, value, process['worker_process_id']), 'CLAIM')
        I.require(report.get('r10dg_native_world_claim') == dict(claim_binding=dict(path=(folder / I.CLAIM).as_posix(), raw_sha256=I.sha(folder / I.CLAIM)), world_permission_consumed=True, maximum_world_builds=1, physical_acceptance_authority=False, release_authority=False), 'REPORT_CLAIM_BINDING')
        # Descriptive tracking error only; no threshold or acceptance decision.
        packets = report.get('r10df_partial_recovery', {}).get('step_packets', [])
        errors = []
        refs = report.get('r10df_reference_session', {}).get('packets', [])
        for index, packet in enumerate(packets):
            if index >= len(refs): break
            control = refs[index].get('next_control')
            if not isinstance(control, dict): continue
            observation = packet.get('bound_observations', {}).get('observation_v3', {})
            joints = {x.get('actuator_id', x.get('joint_id')): x for x in observation.get('state', {}).get('ordered_joint_observations', [])}
            for command in control.get('ordered_commands', []):
                actual = joints.get(command.get('joint_id'))
                target_angle = command.get('target_position_rad')
                if actual and isinstance(target_angle, (int, float)) and isinstance(actual.get('position_rad'), (int, float)):
                    errors.append(abs(actual['position_rad'] - target_angle))
        result.update(solver_step_count=steps, report=I.binding(target), native_world_claim=I.binding(folder / I.CLAIM),
            final_state=arm['orchestrator_state'], external_kick_application_count=report['external_kick_application_count'],
            partial_control_application_count=len(packets), observed_tracking_samples=len(errors),
            maximum_absolute_tracking_error_rad=max(errors) if errors else None,
            root_mean_squared_tracking_error_rad=(sum(e * e for e in errors) / len(errors)) ** 0.5 if errors else None)
        del report, arm, packets, refs
        gc.collect()
        engine = value['runtime']['images']['godot_engine']['path']
        L.run_process(folder, 'independent-reader', [engine, '--headless', '--path', I.ROOT, '--script',
            'res://sdk/trace_analysis/r10dg_recovery_replay.gd', '--', target,
            value['candidate_profile']['resource'], value['candidate_profile']['raw_sha256'], path],
            L.clean_environment(), timeout=value['independent_replay_timeout_seconds'])
        receipts = [json.loads(line.removeprefix('DEVELOPMENT_RECOVERY_CANDIDATE_REPLAY '))
            for line in (folder / 'independent-reader.stdout.txt').read_text(encoding='utf-8').splitlines()
            if line.startswith('DEVELOPMENT_RECOVERY_CANDIDATE_REPLAY ')]
        I.require(len(receipts) == 1 and receipts[0]['ok'] is True, 'INDEPENDENT_REPLAY')
        I.write_new(folder / 'independent-reader-result.json', receipts[0])
        result.update(ok=True, disposition='audited_tracking_diagnostic', reader=I.binding(folder / 'independent-reader-result.json'))
    except Exception:
        result['error'] = traceback.format_exc()
    finally:
        result['retained_files'] = [I.binding(p) for p in sorted(folder.iterdir()) if p.is_file()]
        I.write_new(path.parent / 'result-audit.json', result)
    print(json.dumps({k: result[k] for k in ['ok', 'disposition', 'physical_attempted', 'pause_after_attempt']}), flush=True)
    return result

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--declaration', type=Path, required=True)
    result = audit(parser.parse_args().declaration)
    raise SystemExit(0 if result['ok'] else 1)
