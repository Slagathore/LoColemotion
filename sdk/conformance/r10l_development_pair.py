"""Read-only closure and settled-tail diagnosis of the consumed R10L pair."""
import hashlib
import json
import math
from pathlib import Path
import development_recovery_smoke as smoke
from v52_extended_support_transfer import ROOT, read, binding, verify

RECORD = ROOT / 'sdk/recovery/r10l_phase241_development_pair_closure_v1.json'


def require(ok, code):
    if not ok:
        raise ValueError('R10L_PAIR_' + code)


def stop_diagnosis(report, task):
    """Use post-solver native measurements, preserving every contact observation."""
    retention = report['development_cycle_stop']
    memory = retention['final_memory']
    start = memory['cycle_end_command']
    rows = retention['rows'][start:]
    limits, tail = task['limits'], task['settled_tail']
    require(len(rows) == limits['stopping_commands'] == 120, 'STOP_POPULATION')
    measured = []
    consecutive = 0
    for index, row in enumerate(rows, 1):
        require(row['session_local_step'] == start + index, 'STOP_CLOCK')
        source = row['post_native_source']
        observation = source['observation']
        contacts = observation['state']['ordered_contact_observations']
        require(len(contacts) == 4 and len({c['contact_site_id'] for c in contacts}) == 4,
                'CONTACT_POPULATION')
        require(all(type(c['presence']) is bool and type(c['bears_support']) is bool
                    for c in contacts), 'KNOWN_CONTACT')
        velocity = observation['center_of_mass']['linear_velocity_world_m_s']
        omega = observation['state']['base_twist_world']['angular_velocity_rad_s']
        tilt = source['precommand_trace']['torso_tilt_rad']
        require(observation['center_of_mass']['source_measurement'] is True, 'MEASURED_COM')
        require(all(type(v) in (float, int) and math.isfinite(v)
                    for v in [*[velocity[k] for k in 'xyz'], *[omega[k] for k in 'xyz'], tilt]),
                'FINITE_MOTION')
        missing = [c['contact_site_id'] for c in contacts
                   if not (c['presence'] and c['bears_support'])]
        speed = math.hypot(velocity['x'], velocity['z'])
        angular = math.sqrt(sum(omega[k] ** 2 for k in 'xyz'))
        predicates = dict(all_four_bearing=not missing,
            horizontal_speed=speed <= tail['maximum_horizontal_com_speed_m_s'],
            angular_speed=angular <= tail['maximum_torso_angular_speed_rad_s'],
            torso_tilt=tilt <= tail['maximum_torso_tilt_rad'])
        settled = all(predicates.values())
        consecutive = consecutive + 1 if settled else 0
        measured.append(dict(walking_command=start + index, stopping_command=index,
            missing_support_sites=missing, horizontal_speed_m_s=speed,
            angular_speed_rad_s=angular, torso_tilt_rad=tilt,
            predicates=predicates, settled=settled))
    require(consecutive == memory['consecutive_settled_commands'], 'WORKER_SETTLED_COUNT')
    final = measured[-limits['settled_tail_commands']:]
    return dict(stop_commands=len(rows), required_final_settled_commands=30,
        final_consecutive_settled_commands=consecutive,
        failed_final_commands=[row for row in final if not row['settled']],
        final_tail_maxima={key: max(row[key] for row in final)
            for key in ['horizontal_speed_m_s', 'angular_speed_rad_s', 'torso_tilt_rad']},
        all_stop_measurements=measured, settled_stop_passed=all(row['settled'] for row in final),
        causal_attribution_proven=False, physical_acceptance_authority=False, release_authority=False)


def audit():
    r = read(RECORD)
    require(r['schema_version'] == 'sporespore_r10l_phase241_development_pair_closure_v1', 'SCHEMA')
    for key in ['auditor', 'checkpoint', 'entry_contract', 'candidate_profile', 'task_contract', 'runtime_binding']:
        verify(r[key])
    for item in r['retained_evidence']:
        verify(item)
    root = Path(r['evidence_root'])
    # Reopen the original publications, launch relationships, invariant population,
    # native replay receipts and finite predicates. This creates no physical world.
    checkpoint = smoke.retained_checkpoint(root)
    require(checkpoint == read(verify(r['checkpoint'])), 'CHECKPOINT')
    original = read(root / 'supervisor_result.json')
    require(original['ok'] is True and original['failure_code'] == '', 'VALID_DEVELOPMENT')
    stages = original['safety_stages']
    require(len(stages) == 40 and sum(s['test_count'] for s in stages) == 195
            and all(s['passed'] is True and s['timed_out'] is False for s in stages), 'FULL_GATE')
    cells = checkpoint['observed']['r10l_finite_development']['cells']
    require([c['finite_task_predicates_passed'] for c in cells] == [True, False], 'FINITE_RESULTS')
    require(cells[1]['measurement']['predicates'] == dict(entry_ready=True, planned_cycles=True,
            forward_advance=True, settled_stop=False, whole_walking_envelope=True,
            recovery_completed=True), 'KICKED_PREDICATES')
    task = read(verify(r['task_contract']))
    for role in smoke.ROLES:
        report = read(root / 'children' / role / 'worker_report.json')
        require(stop_diagnosis(report, task) == r['stop_diagnosis'][role], 'STOP_DIAGNOSIS:' + role)
    require(r['claim_boundary'] == dict(valid_development_pair=True, all_tasks_positive=False,
            phase243_prerequisite_satisfied=False, physical_acceptance_authority=False,
            release_authority=False, original_attempt_reclassified=False, sdk1_score='14/20'), 'CLAIMS')
    return dict(ok=True, safety_tests=195, physical_worlds=2, completed_solver_steps=3932,
        finite_positive_roles=1, finite_negative_roles=1, kicked_final_consecutive_settled_commands=4,
        required_final_settled_commands=30, new_world_count=0, new_solver_step_count=0, sdk1_score='14/20')


if __name__ == '__main__':
    print(json.dumps(audit(), sort_keys=True))
