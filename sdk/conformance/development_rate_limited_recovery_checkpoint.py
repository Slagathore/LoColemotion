"""Cold V8 closure and descriptive support timing; no engine is launched.

Reopen the original completed pair, both independently executed readers and
the supervisor publication. The proposed next investigation is not a causal
finding, controller adoption, successful recovery or acceptance claim.
"""
import json

import development_rearward_fold_checkpoint as prior

entry = prior.entry
smoke = prior.smoke
ATTEMPT = '64c4499dd7a7489099e4c62fdc39029b'
SOURCE = '9b90081d159d6ddb2dcbe72d673a2c78dd4ba0e6'
EVIDENCE = entry.EVIDENCE / ('development-recovery-smoke-' + ATTEMPT)
RECORD = entry.ROOT / 'sdk/development_rate_limited_recovery_checkpoint_v1.json'
PROFILE = 'sdk/development_rate_limited_recovery_profile_v1.json'
DESIGN = 'sdk/development_rate_limited_recovery_design_v1.json'
SAMPLE_STEPS = (386, 387, 394, 400, 410, 420, 434, 450, 626)


def summarize(report):
    return prior.summarize(report, source_commit=SOURCE, profile_path=PROFILE)


def support_timing(report):
    """Use every active support sample for foot counts, not selected anecdotes."""
    design = entry.packet.parse_json(prior.committed(DESIGN, SOURCE).decode())
    targets = design['prospective_controller']['support_targets_rad']
    ceiling = design['prospective_controller']['support_maximum_target_speed_rad_s']
    rule = entry.packet.parse_json(prior.committed(prior.RULE, SOURCE).decode())
    minimum = next(t['value'] for t in rule['threshold_profile']['thresholds']
                   if t['threshold_id'] == 'distal_bearing_minimum_impulse_ns')
    feet = {}
    samples = []
    active = []
    initial = None
    for packet in report['passive_entry']['canonical_packets']:
        step = packet['global_semantic_step']
        phase = packet['step_receipt']['prior_phase']
        observation = entry.packet.parse_json(packet['collection_transport']['source_links']
            ['bound_observation']['utf8_text'])['observation_v3']
        joints = observation['state']['ordered_joint_observations']
        positions = [j['position_rad'] for j in joints]
        smoke.require(len(positions) == len(targets) == 8, 'V8_TIMING_JOINT_POPULATION')
        if step == 386:
            initial = joints
        qualified = []
        for foot, contact in zip(observation['ordered_foot_bearing_observations'],
                                 observation['state']['ordered_contact_observations']):
            name = foot['contact_site_id']
            smoke.require(name == contact['contact_site_id'], 'V8_TIMING_CONTACT_ORDER')
            bears = (contact['presence'] is True and contact['bears_support'] is True
                     and foot['ordinary_unilateral_contact'] is True
                     and foot['bearing_normal_impulse_ns'] >= minimum)
            if bears:
                qualified.append(name)
            if phase == 'establish_distal_support':
                row = feet.setdefault(name, dict(contact_site_id=name,
                    qualifying_sample_count=0, first_qualifying_step=None, last_qualifying_step=None))
                if bears:
                    row['qualifying_sample_count'] += 1
                    if row['first_qualifying_step'] is None:
                        row['first_qualifying_step'] = step
                    row['last_qualifying_step'] = step
        classification = packet['step_receipt']['classification']
        smoke.require(classification['distal_support_gate'] is (len(qualified) == 4),
                      'V8_TIMING_SUPPORT_RECOMPUTATION')
        commands = [v['canonical_target_velocity_rad_s'] for v in packet['application'].get('ordered_intents', [])]
        if phase == 'establish_distal_support':
            active.append(step)
        if step in SAMPLE_STEPS:
            samples.append(dict(global_step=step, phase=phase, joint_positions_rad=positions,
                commanded_joint_velocities_rad_s=commands, qualifying_feet=qualified,
                torso_up_dot=classification['torso_up_dot'],
                angular_speed_rad_s=classification['terminal_angular_speed_rad_s']))
    smoke.require(tuple(s['global_step'] for s in samples) == SAMPLE_STEPS
                  and active == list(range(387, 627)) and initial is not None, 'V8_TIMING_POPULATION')
    return dict(
        initial_sample_global_step=386, active_support_sample_count=len(active),
        initial_joint_travel=[dict(joint_id=j['joint_id'], position_rad=j['position_rad'],
            target_position_rad=target, absolute_error_rad=abs(target - j['position_rad']),
            ideal_unconstrained_travel_seconds_at_ceiling=abs(target - j['position_rad']) / ceiling)
            for j, target in zip(initial, targets)],
        target_speed_ceiling_rad_s=ceiling, per_foot_support=list(feet.values()), samples=samples,
        travel_time_limitation='Distance divided by commanded speed is a kinematic scale, not actual arrival time or contact feasibility. Native joints are dynamically coupled.',
        interpretation='The rear-left knee begins farther from its target than the other knees while all eight initial motor velocity requests equal 4 rad/s. Its foot never meets the unchanged support rule. The front feet remain loaded during torso rotation; the joints eventually approach their targets with the torso upside down.',
        next_investigation='A common measured-entry-to-support joint trajectory that coordinates progress, rather than another uniform speed-ceiling guess. Verify the geometry and contact ordering before selecting a controller.',
        cause_proven=False, coordinated_motion_success_proven=False, new_controller_adopted=False)


def observe():
    checkpoint = smoke.retained_checkpoint(EVIDENCE)
    smoke.require(checkpoint['attempt_id'] == ATTEMPT and checkpoint['source_snapshot']['head'] == SOURCE
                  and checkpoint['source_snapshot']['dirty'] is False, 'V8_CLOSURE_SOURCE')
    report_path = EVIDENCE / 'children' / smoke.ROLES[1] / 'worker_report.json'
    report = smoke.read(report_path)
    metrics = summarize(report)
    smoke.require(report['solver_step_count'] == 626
                  and metrics['terminal_reason'] == 'phase_timeout:establish_distal_support'
                  and metrics['stable_stance_sample_count'] == metrics['walking_resume_step_count'] == 0
                  and metrics['four_foot_support_global_steps'] == [], 'V8_CLOSURE_OBSERVED_NEGATIVE')
    children = [{key: value for key, value in child.items() if key != 'step_cost_profile'}
                for child in checkpoint['observed']['children']]
    rules = []
    for relative in (prior.RULE, PROFILE, DESIGN, 'sdk/core/src/recovery_runtime.rs'):
        raw = prior.committed(relative, SOURCE)
        rules.append(dict(path=relative, source_commit=SOURCE, byte_length=len(raw), raw_sha256=entry.digest(raw)))
    return dict(schema_version='sporespore_development_rate_limited_recovery_checkpoint_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
            authority_mode='retained_development_physical_result', question_class='development'),
        status='closed_consumed_valid_development_behavior_negative', attempt_id=ATTEMPT,
        evidence_root=EVIDENCE.as_posix(), source_snapshot=checkpoint['source_snapshot'],
        retained_population=checkpoint['retained_population'], artifact_sha256=checkpoint['artifact_sha256'],
        elapsed_seconds=checkpoint['elapsed_seconds'], children=children, rule_sources=rules,
        kicked_report=entry.runtime.file_identity(report_path), whole_original_attempt_audit_passed=True,
        both_independent_report_replays_passed=True, world_count=2,
        solver_step_count=checkpoint['observed']['total_solver_steps'], metrics=metrics,
        support_timing=support_timing(report),
        descriptive_conclusion='V8 never establishes four-foot support, overturns and times out in support. No stable standing or walking resume is recorded. The unchanged diagnostic horizon is not fully covered.',
        causal_attribution_proven=False, successful_recovery_proven=False, complete_route_proven=False,
        physical_acceptance_authority=False, release_authority=False,
        repeat_consumed_attempt_permitted=False, new_world_build_count=0, new_solver_step_count=0)


if __name__ == '__main__':
    print(json.dumps(observe(), indent=2, allow_nan=False))
