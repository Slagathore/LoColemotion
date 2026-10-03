"""Describe a replay-validated V41 trace without native calls or regrading.

The two height plans are separate native reference-geometry receipts. Neither
is a contact observation or a promise that a supporting foot stays anchored.
"""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
POLICY = 'sporespore_balanced_wave_recovery_upright_stance_v1'
LIMBS = ('front_left', 'front_right', 'rear_left', 'rear_right')


def require(condition, code):
    if not condition:
        raise ValueError(code)


def digest(raw):
    return 'sha256:' + hashlib.sha256(raw).hexdigest()


def summarize(report):
    rows = report['development_walking_entry']['rows']
    session = next(s for s in report['retained_arm']['walking_sessions']
                   if s['evaluation_segment_id'] == 'walking_resume')
    evaluation = session['evaluation']
    require(len(rows) > 0 and len(rows) == evaluation['trace_row_count'], 'UPRIGHT_COMPLETE_ROWS')
    selected = {limb: 0 for limb in LIMBS}
    clamps = {limb: dict(bearing_stance=0, absent_stance=0, swing_or_landing=0, other_stance=0) for limb in LIMBS}
    empty = dict(measured_pose_baseline=0, floor_upright_reference=0)
    mask_transitions = 0
    previous_mask = None
    for local, row in enumerate(rows, 1):
        require(row['session_local_step'] == local, 'UPRIGHT_ROW_ORDER')
        act = row['native_output']['actuation']
        require(act['receipt']['schema_version'] == 'sporespore_recovery_upright_stance_controller_step_receipt_v1', 'UPRIGHT_POLICY_SCHEMA')
        receipt = act['receipt']['recovery_support_plane']
        u = receipt['upright_stance']
        state = row['request']['state']
        require('feasible_support_plan' not in receipt, 'UPRIGHT_NO_FICTITIOUS_MIXED_PLAN')
        require(u['reference_geometry_role'] == 'controller_target_not_measured_pose_or_contact'
                and u['reference_anatomical_vertical_projections'] == [0., 1., 0.], 'UPRIGHT_REFERENCE_NOT_OBSERVATION')
        require(u['source_semantic_step'] == state['semantic_step']
                and u['source_floor_reference'] == row['request']['floor_reference'], 'UPRIGHT_SOURCE_IDENTITY')
        mask = []
        for i, limb in enumerate(LIMBS):
            observed = state['ordered_contact_observations'][i]
            r = u['ordered_limbs'][i]
            phase = receipt['wave_velocity']['current_wave']['ordered_limbs'][i]['scheduled_phase_step']
            require(r['limb_id'] == limb and r['precommand_contact'] == observed
                    and r['scheduled_phase_step'] == phase, 'UPRIGHT_CONTACT_PROVENANCE')
            expected = receipt['wave_velocity']['current_wave']['active'] and 72 < phase < 360 and observed['presence'] and observed['bears_support']
            require(type(r['upright_reference_selected']) is bool and r['upright_reference_selected'] == expected, 'UPRIGHT_SELECTOR')
            mask.append(expected)
            selected[limb] += expected
            chosen = u['floor_upright_reference_proposals' if expected else 'measured_pose_baseline_proposals'][i]
            require(receipt['ordered_limb_proposals'][i] == chosen, 'UPRIGHT_ACTUAL_GOAL_SELECTION')
            require(u['ordered_selected_goals_rad'][2*i:2*i+2] == [chosen['goal_hip_rad'], chosen['goal_knee_rad']], 'UPRIGHT_SELECTED_GOAL_VALUES')
            kind = ('swing_or_landing' if phase <= 72 else 'bearing_stance' if observed['presence'] and observed['bears_support']
                    else 'absent_stance' if not observed['presence'] and not observed['bears_support'] else 'other_stance')
            clamps[limb][kind] += sum(c['velocity_saturated'] for c in act['ordered_commands'][2*i:2*i+2])
        if previous_mask is not None:
            mask_transitions += sum(a != b for a, b in zip(previous_mask, mask))
        previous_mask = mask
        for name in empty:
            plan = u[name + '_plan']
            require(len(plan['ordered_limb_intervals']) == 4 and plan['common_height_interval_nonempty'] ==
                    (plan['common_minimum_torso_height_m'] <= plan['common_maximum_torso_height_m']), 'UPRIGHT_HEIGHT_PLAN_CONSISTENCY')
            empty[name] += not plan['common_height_interval_nonempty']
    per_limb = {}
    for i, limb in enumerate(LIMBS):
        last = u['ordered_limbs'][i]
        per_limb[limb] = dict(upright_selected_commands=selected[limb], speed_clamped_commands_by_precommand_state=clamps[limb],
            terminal_scheduled_phase_step=last['scheduled_phase_step'],
            terminal_precommand_contact_present=last['precommand_contact']['presence'],
            terminal_precommand_bears_support=last['precommand_contact']['bears_support'],
            observed_flight_open_at_end=evaluation['observed_flight_open_at_end_by_limb'][limb],
            minimum_observed_cycle_forward_relocation_m=evaluation['minimum_cycle_forward_relocation_by_limb_m'][limb])
    return dict(command_count=len(rows), upright_selected_limb_commands=sum(selected.values()), selector_limb_transitions=mask_transitions,
        empty_common_height_intervals=empty, speed_clamped_joint_commands=sum(sum(v.values()) for v in clamps.values()),
        per_limb=per_limb, original_walking_evaluation=evaluation,
        interpretation_limit='These describe verified native receipts and the original evaluator. Reachable reference geometry is not contact anchoring; contact-cycle counts are not planned-gait-cycle counts. No causal or comparative claim.',
        original_evaluation_replaced=False, native_calls=0, world_build_count=0, solver_step_count=0,
        physical_acceptance_authority=False, release_authority=False)


def observe(closure_path):
    closure_raw = closure_path.read_bytes()
    closure = json.loads(closure_raw)
    require(closure['candidate_id'] == 'v41-upright-stance-integrated-v2'
            and closure['original_attempt_and_all_independent_replays_passed'] is True
            and closure['world_count'] == 1 and closure['physical_acceptance_authority'] is False,
            'UPRIGHT_VALIDATED_DEVELOPMENT_CLOSURE')
    identity = closure['kicked_report']
    raw = Path(identity['path']).read_bytes()
    require(len(raw) == identity['byte_length'] and digest(raw) == identity['raw_sha256'], 'UPRIGHT_REPORT_BINDING')
    return dict(schema_version='sporespore_development_recovery_upright_stance_observation_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='post_exposure_retained_native_receipt_description', question_class='development'),
        original_closure=dict(path=closure_path.relative_to(ROOT).as_posix(), raw_sha256=digest(closure_raw)),
        original_report=identity, observation=summarize(json.loads(raw)),
        analysis_sources=[dict(path=p, raw_sha256=digest((ROOT/p).read_bytes())) for p in
            ('sdk/conformance/development_recovery_upright_stance_observation.py', 'tests/test_development_v41_observation.py')])


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('closure', type=Path)
    args = parser.parse_args()
    print(json.dumps(observe(args.closure.resolve()), indent=2, allow_nan=False))
