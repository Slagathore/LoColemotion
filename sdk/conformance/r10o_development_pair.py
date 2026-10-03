"""Reconstruct the consumed positive R10O pair; never launch or regrade physics."""
import argparse
import copy
import json
from pathlib import Path

import development_recovery_smoke as smoke
import qsdk_r10f_l15_collection_retention as packet
import r10o_development as development
from r10l_development_pair import stop_diagnosis
from v52_extended_support_transfer import ROOT, binding, read

ATTEMPT = 'bb01bec134be49f5b493f092291cf90a'
SOURCE = '1c00726cc820de33a1459c4e37ecadda22a926c1'
EVIDENCE = ROOT.parent / 'SporeSpore_Evidence' / ('development-recovery-smoke-' + ATTEMPT)
RECORD = ROOT / 'sdk/recovery/r10o_phase241_development_pair_closure_v1.json'
PROFILE = 'sdk/development/recovery_candidates/r10o-v55-initialized-brake-integrated-v2.json'
TASK = 'sdk/recovery/r10o_initialized_zero_brake_finite_cycle_contract_v1.json'
SAFETY = 'sdk/development/r10o_safety_stage_contract_v1.json'


def require(value, code):
    if not value:
        raise ValueError('R10O_PAIR_' + code)


def stop_controls(report, task):
    """Corrupt compact copies of measured stop inputs, preserving the original."""
    original = report['development_cycle_stop']
    start = original['final_memory']['cycle_end_command']
    rows = []
    for row in original['rows'][start:]:
        source = row['post_native_source']
        observation = source['observation']
        rows.append(dict(session_local_step=row['session_local_step'], post_native_source=dict(
            observation=dict(center_of_mass=copy.deepcopy(observation['center_of_mass']), state=dict(
                ordered_contact_observations=copy.deepcopy(observation['state']['ordered_contact_observations']),
                base_twist_world=copy.deepcopy(observation['state']['base_twist_world']))),
            precommand_trace=dict(torso_tilt_rad=source['precommand_trace']['torso_tilt_rad']))))
    compact = dict(development_cycle_stop=dict(final_memory=copy.deepcopy(original['final_memory']),
        rows=[None] * start + rows))
    require(packet.same(stop_diagnosis(compact, task), stop_diagnosis(report, task)), 'COMPACT_STOP')
    observed = []
    for name in ('missing_tail_row', 'crossed_clock', 'unknown_contact', 'nonfinite_motion', 'forged_settled_count'):
        value = copy.deepcopy(compact)
        stop = value['development_cycle_stop']
        row = stop['rows'][-1]
        observation = row['post_native_source']['observation']
        if name == 'missing_tail_row':
            stop['rows'].pop()
        elif name == 'crossed_clock':
            row['session_local_step'] += 1
        elif name == 'unknown_contact':
            observation['state']['ordered_contact_observations'][0]['presence'] = None
        elif name == 'nonfinite_motion':
            observation['center_of_mass']['linear_velocity_world_m_s']['x'] = float('nan')
        else:
            stop['final_memory']['consecutive_settled_commands'] = 0
        try:
            stop_diagnosis(value, task)
        except ValueError as error:
            observed.append(dict(case=name, refused=True, error=str(error)))
        else:
            raise ValueError('R10O_PAIR_STOP_CONTROL_ACCEPTED:' + name)
    return observed


def reconstruct():
    supervisor = read(EVIDENCE / 'supervisor_result.json')
    require(supervisor['ok'] is True and supervisor['failure_code'] == '', 'SUPERVISOR')
    require(supervisor['source_snapshot'] == dict(head=SOURCE, dirty=False, status=[], changed_file_bindings=[]), 'FREEZE')
    selected = read(ROOT / SAFETY)['stages']
    stages = supervisor['safety_stages']
    require(len(stages) == len(selected) == 41 and sum(s['test_count'] for s in stages) == 201, 'GATE_POPULATION')
    for stage, expected in zip(stages, selected):
        require(stage['id'] == expected['id'] and stage['test_count'] == stage['expected_test_count'] == expected['tests']
            and stage['passed'] is True and stage['timed_out'] is False and stage['exit_code'] == 0, 'GATE_STAGE')
        for stream in ('stdout', 'stderr'):
            actual = binding(EVIDENCE / stage[stream])['raw_sha256']
            require(actual == 'sha256:' + stage[stream + '_sha256'], 'GATE_LOG')

    # Reopen the exact publications, launch identities, native replay receipts,
    # complete invariant population, and independently measured finite tasks.
    checkpoint = smoke.retained_checkpoint(EVIDENCE)
    result = checkpoint['observed']['r10o_finite_development']
    require(development.positive_pair_result(result, result['candidate_profile']), 'POSITIVE_PAIR')
    require(checkpoint['attempt_id'] == ATTEMPT and checkpoint['source_snapshot'] == supervisor['source_snapshot'], 'CHECKPOINT_SOURCE')
    require(checkpoint['observed']['total_solver_steps'] == 3945, 'STEP_POPULATION')
    task = read(ROOT / TASK)
    diagnoses = {}
    controls = []
    summaries = []
    for index, cell in enumerate(result['cells']):
        role = cell['role']
        report = read(EVIDENCE / 'children' / role / 'worker_report.json')
        require(report['world_build_count'] == report['world_attempt_count'] == 1, 'FRESH_WORLD')
        require(report['solver_step_count'] == (1740, 2205)[index], 'CHILD_STEPS')
        require(report['external_kick_application_count'] == index, 'KICK_POPULATION')
        walking = cell['measurement']['walking']
        require(walking['command_count'] == (1122, 1180)[index]
            and walking['cycle_end_command'] == (1002, 1060)[index]
            and len(walking['planned_cycles']) == 4 and walking['stopping_commands'] == 120, 'WALKING_POPULATION')
        diagnoses[role] = stop_diagnosis(report, task)
        require(diagnoses[role]['settled_stop_passed'] is True
            and diagnoses[role]['final_consecutive_settled_commands'] == (102, 120)[index], 'SETTLED_TAIL')
        if index == 1:
            controls = stop_controls(report, task)
        summaries.append(dict(role=role, entry_kind=cell['entry_kind'], solver_steps=report['solver_step_count'],
            walking_commands=walking['command_count'], planned_cycles=4, stopping_commands=120,
            consecutive_settled_commands=diagnoses[role]['final_consecutive_settled_commands'],
            forward_advance_m=walking['pre_first_to_post_last_body_forward_m'],
            predicates=cell['measurement']['predicates']))
        del report
    paths = [Path(__file__).relative_to(ROOT).as_posix(), 'sdk/conformance/r10l_development_pair.py',
        PROFILE, TASK, SAFETY, 'sdk/recovery/r10o_initialized_zero_brake_successor_design_v1.json',
        'sdk/recovery/r10o_v55_walking_entry_contract_v2.json',
        'sdk/development/recovery_candidates/v55-initialized-zero-brake-core-v1.runtime.json']
    return dict(schema_version='sporespore_r10o_phase241_development_pair_closure_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
            authority_mode='consumed_positive_development_pair_closure', question_class='development'),
        attempt_id=ATTEMPT, source_commit=SOURCE, evidence_root=EVIDENCE.as_posix(),
        status='valid_positive_phase241_development_pair',
        source_bindings=[binding(path) for path in paths],
        safety_gate=dict(stages=41, tests=201, passed=True, seconds=sum(s['seconds'] for s in stages)),
        retained_checkpoint=checkpoint,
        retained_evidence=[binding(path) for path in sorted(EVIDENCE.rglob('*')) if path.is_file()],
        physical_world_count=2, completed_solver_steps=3945, role_summaries=summaries,
        stop_diagnosis=diagnoses, stop_negative_controls=controls,
        claim_boundary=dict(valid_development_pair=True, all_tasks_positive=True,
            phase243_prerequisite_satisfied=True, phase243_prone_physically_tested=False,
            held_out_population_selected=False, physical_acceptance_authority=False,
            release_authority=False, original_attempt_reclassified=False, sdk1_score='14/20'))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--create', action='store_true', help='Exclusively create the first immutable closure')
    args = parser.parse_args()
    observed = reconstruct()
    if args.create:
        with RECORD.open('x', encoding='utf-8', newline='\n') as stream:
            json.dump(observed, stream, indent=2, allow_nan=False)
            stream.write('\n')
    else:
        require(packet.same(observed, read(RECORD)), 'CLOSURE_RECONSTRUCTION')
    print(json.dumps(dict(ok=True, retained_files=len(observed['retained_evidence']),
        safety_tests=201, physical_worlds=2, completed_steps=3945, positive_roles=2,
        settled_counts=[102, 120], stop_negative_controls=len(observed['stop_negative_controls']),
        phase243_prerequisite_satisfied=True, new_world_count=0, new_solver_step_count=0, sdk1_score='14/20')))


if __name__ == '__main__':
    main()
