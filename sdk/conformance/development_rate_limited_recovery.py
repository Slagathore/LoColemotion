"""Reproduce the V8 development choice from immutable V7 observations.

No counterfactual solver trajectory is claimed. A target-speed ceiling is not
an actual velocity/acceleration limit; contacts can produce different speeds.
"""
import json
import development_rearward_fold_checkpoint as prior

ROOT = prior.entry.ROOT
RECORD = ROOT / 'sdk/development_rate_limited_recovery_design_v1.json'
STEPS = (386, 387, 394, 395, 399, 400, 412, 413)


def observe():
    closure = prior.entry.read(prior.RECORD)
    prior.smoke.require(prior.entry.packet.same(prior.observe(), closure), 'V8_ORIGINAL_CLOSURE')
    path = prior.EVIDENCE / 'children/kick_passive_recovery_resume/worker_report.json'
    report = prior.entry.read(path)
    samples = []
    for packet in report['passive_entry']['canonical_packets']:
        if packet['global_semantic_step'] not in STEPS:
            continue
        classification = packet['step_receipt']['classification']
        bound = prior.entry.packet.parse_json(packet['collection_transport']['source_links']['bound_observation']['utf8_text'])
        joints = bound['observation_v3']['state']['ordered_joint_observations']
        samples.append(dict(global_step=packet['global_semantic_step'], phase=packet['step_receipt']['prior_phase'],
            angular_speed_rad_s=classification['terminal_angular_speed_rad_s'],
            linear_speed_m_s=classification['terminal_linear_speed_m_s'],
            joint_positions_rad=[j['position_rad'] for j in joints],
            joint_velocities_rad_s=[j['velocity_rad_s'] for j in joints],
            commanded_joint_velocities_rad_s=[i['canonical_target_velocity_rad_s']
                for i in packet['application'].get('ordered_intents', [])]))
    prior.smoke.require(tuple(s['global_step'] for s in samples) == STEPS, 'V8_SAMPLE_POPULATION')
    targets = [-0.6, 1.05] * 4
    error = max(abs(target - actual) for target, actual in zip(targets, samples[0]['joint_positions_rad']))
    return dict(schema_version='sporespore_development_rate_limited_recovery_design_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt_observation_engine_neutral_candidate',
            authority_mode='post_exposure_diagnosis_and_prospective_development_design', question_class='development'),
        authored_parent_commit='584af0b2605c0c190a68d7bf9e1cc87fdcbf7677',
        sources=[prior.entry.runtime.file_identity(prior.RECORD), prior.entry.runtime.file_identity(path)],
        observations=samples,
        observation_interpretation='The torso is already rotating during support. The first raise step requests 22 rad/s on all eight motors after 8 rad/s support; support is lost before the later stance handoff.',
        causal_attribution_proven=False,
        prospective_controller=dict(controller_id='sporespore_exact_s169_prone_to_standing_controller_v8',
            profile_id='sporespore_exact_s169_rate_limited_recovery_development_v8',
            support_targets_rad=targets, support_maximum_target_speed_rad_s=4.0,
            raise_maximum_target_speed_rad_s=4.0,
            selection_basis='One exploratory common ceiling: half the V7 support ceiling, also removing its increase at rise. Not an optimum, safety threshold, inferred physical limit, or fitted success guarantee.',
            modified_behavior='Only the two target-speed ceilings; identity fields version the changed policy.',
            preserved=['V7 pose targets', 'force and impulse caps', '360-step pose ramp', 'phase predicates and deadlines',
                'acceptance thresholds', 'V6 setup', 'stance controller', 'walking policy', 'native energy measurement'],
            initial_maximum_joint_error_rad=error,
            ideal_unconstrained_constant_speed_travel_seconds=error / 4.0,
            travel_estimate_limitation='Kinematic scale check only; coupled contact dynamics can prevent reaching the pose. It does not prove timing adequacy for successful recovery.',
            risks=['support may still be lost', 'lower speed may fail to lift or time out',
                'stance handoff may remain unstable even if the rise improves'],
            physical_suitability_proven=False),
        diagnostic_coverage=dict(seed=40200, fresh_child_roles=list(prior.smoke.ROLES),
            after_interaction_steps=480, maximum_steps_per_child=832,
            purpose='Observe support/rise motion, native command realization and any standing/walking within the unchanged diagnostic bound.',
            early_terminal_or_horizon_does_not_prove_complete_route=True,
            full_official_route_or_held_out_coverage=False),
        force_aware_recovery=False, historical_results_reinterpreted=False,
        new_world_build_count=0, new_native_physics_read_count=0, new_solver_step_count=0,
        physical_acceptance_authority=False, release_authority=False)


if __name__ == '__main__':
    print(json.dumps(observe(), indent=2, allow_nan=False))
