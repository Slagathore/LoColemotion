"""Command-only counterfactual using real retained joint angles, never a rollout.

The native-shaped test request remains synthetic. Only its eight joint positions
are replaced by exact retained readings. No old observation or source digest is
rewritten, and this does not pretend the old trajectory belongs to a new policy.
"""
import argparse
import copy
import json
from pathlib import Path
import sys

import development_recovery_candidate as candidate
import development_passive_entry_profile as entry

sys.path.insert(0, str(candidate.ROOT / 'sdk/python'))
from sporespore_locomotion import LocomotionCore

SOURCE = entry.EVIDENCE / ('development-recovery-smoke-64c4499dd7a7489099e4c62fdc39029b/'
                          'children/kick_passive_recovery_resume/worker_report.json')
SOURCE_SHA = 'sha256:dd424aa0557e59b6d0bf17a7d7cdd93313c804fae70d045b6d6466a128db5a88'
SOURCE_STEP = 386


def evaluate(selection):
    raw = SOURCE.read_bytes()
    candidate.require(entry.digest(raw) == SOURCE_SHA, 'RETAINED_ENTRY_SOURCE_DRIFT')
    report = entry.packet.parse_json(raw.decode('utf-8'))
    packets = [p for p in report['passive_entry']['canonical_packets'] if p['global_semantic_step'] == SOURCE_STEP]
    candidate.require(len(packets) == 1, 'RETAINED_ENTRY_STEP')
    source_request = entry.packet.parse_json(packets[0]['collection_transport']['request']['utf8_text'])
    joints = source_request['observation']['state']['ordered_joint_observations']
    candidate.require(len(joints) == 8 and all(j['validity']['position'] is True and type(j['position_rad']) is float for j in joints),
                      'RETAINED_ENTRY_POSITIONS')
    binding = entry.binding(selection)
    from r10r_compatibility_fixtures import fixture_binding
    original_fixture = fixture_binding()
    fixture_path = Path(original_fixture['path'])
    candidate.require(entry.runtime.file_identity(fixture_path) == original_fixture, 'RETAINED_ENTRY_FIXTURE_DRIFT')
    fixtures = []
    for line in fixture_path.read_text().splitlines():
        prefix, _, payload = line.partition(' ')
        if prefix.endswith('_CONTROL_FIXTURE'):
            fixture = entry.packet.parse_json(payload)
            if (fixture['request']['controller_id'] == selection['post_kick_controller_id']
                    and fixture['request']['collection']['phase'] == 'establish_distal_support'):
                fixtures.append(fixture)
    candidate.require(len(fixtures) == 3, 'RETAINED_ENTRY_FIXTURES')
    core = LocomotionCore(candidate.ROOT / binding['local_build_path'])
    results = []
    for fixture in fixtures:
        request = copy.deepcopy(fixture['request'])
        destination = request['collection']['observation']['state']['ordered_joint_observations']
        candidate.require([j['joint_id'] for j in destination] == [j['joint_id'] for j in joints], 'RETAINED_ENTRY_JOINT_ORDER')
        for expected, supplied in zip(joints, destination, strict=True):
            supplied['position_rad'] = expected['position_rad']
        control = core.recovery_plan_control_v1(request)
        candidate.require(control['support_status'] == 'supported_exact' and len(control['ordered_commands']) == 8,
                          'RETAINED_ENTRY_CONTROL_REFUSED')
        dt = request['collection']['observation']['outer_step_duration_s']
        table = []
        for joint, command in zip(joints, control['ordered_commands'], strict=True):
            limit = command['maximum_target_speed_rad_s']
            requested_speed = (command['target_position_rad'] - joint['position_rad']) / dt
            table.append(dict(joint=joint['joint_id'], retained_position_rad=joint['position_rad'],
                requested_target_rad=command['target_position_rad'], speed_ceiling_rad_s=limit,
                projected_canonical_motor_speed_rad_s=max(-limit, min(limit, requested_speed))))
        results.append(dict(adapter_id=request['collection']['adapter_capability']['adapter_id'],
                            synthetic_request=request, compiled_control=control, joint_commands=table))
    candidate.require(all(entry.packet.same(results[0]['compiled_control']['ordered_commands'], row['compiled_control']['ordered_commands'])
                          for row in results[1:]), 'RETAINED_ENTRY_PORTABLE_COMMAND_MISMATCH')
    return dict(schema_version='sporespore_r10r_retained_joint_entry_command_check_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='3e_command_inputs_only',
                          authority_mode='counterfactual_retained_joint_input_check', question_class='development'),
        candidate_profile=selection['candidate_profile'], runtime=binding['runtime'], original_compatibility_fixture=original_fixture,
        source_report=dict(path=SOURCE.as_posix(), raw_sha256=SOURCE_SHA), source_global_step=SOURCE_STEP,
        injected_physical_fields=['state.ordered_joint_observations[*].position_rad'],
        native_shaped_request_is_synthetic=True, original_observation_rewritten=False,
        actual_motor_readback_measured=False, actual_motion_predicted=False,
        world_build_count=0, native_physics_read_count=0, solver_step_count=0,
        physical_acceptance_authority=False, release_authority=False, results=results)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('profile', type=Path)
    args = parser.parse_args()
    print(json.dumps(evaluate(candidate.selection(candidate.reference_for_path(args.profile))), separators=(',', ':'), allow_nan=False))
