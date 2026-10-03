"""Check the R10Q development declaration; no controller or world is invoked."""
import copy
import json
from pathlib import Path

import r10p_entry_domain_diagnosis as prior

PATH = 'sdk/recovery/r10q_entry_successor_design_v1.json'
DESIGN_SHA = 'sha256:d7732db8f80e1e9c04ddae2b3fbb85effa5c2fad0f931b0dc7ef5788ba6a5cd8'


def require(value, code):
    if not value:
        raise ValueError('R10Q_DESIGN_' + code)


def validate(design):
    require(design['schema_version'] == 'sporespore_r10q_entry_successor_design_v1'
            and design['ledger_scope']['question_class'] == 'development', 'IDENTITY')
    for key in ('physical_execution_authorized', 'physical_acceptance_authority', 'release_authority',
                'successor_implemented', 'successor_success_proven', 'held_out_population_declared'):
        require(design[key] is False, 'PREMATURE_AUTHORITY_' + key)
    require(design['held_out_population'] == [] and type(design['physical_worlds_opened']) is int
            and design['physical_worlds_opened'] == 0, 'UNOPENED_POPULATION')
    preserved = design['preserved_originals']
    require(preserved['r10p_population_consumed'] is True and preserved['r10p_outcome'] == 'negative'
            and all(preserved[k] is False for k in ('r10p_results_regraded', 'r10p_retries_permitted',
                'prior_thresholds_and_controller_identities_mutated', 'old_qualification_reused')), 'ORIGINAL_BOUNDARY')
    ramp = design['decisions']['no_kick_handoff']
    require(ramp['native_hold_policy'] == prior.HOLD_POLICY and ramp['required_consecutive_hold_ready_samples'] == 30
            and ramp['ramp_maximum_commands'] == ramp['hold_maximum_commands'] == 240
            and ramp['reference_completion_is_physical_readiness'] is False
            and ramp['geometry_may_override_native_contact'] is False
            and 'four_native_supports' in ramp['required_hold_readiness'], 'MEASURED_HOLD_BOUNDARY')
    upright = design['decisions']['upright_recovery']
    admission, supervision = upright['entry_selection'], upright['supervision']
    require(admission['admit_only_original_timeout'] is True
            and admission['existing_prone_and_partial_routes_take_priority'] is True
            and admission['original_native_entry_receipt_preserved'] is True
            and admission['entry_geometry_is_standing_success'] is False
            and admission['original_passive_descent_steps'] == 240
            and admission['consecutive_upright_samples'] == 12
            and admission['torso_height_ratio_exclusive_minimum'] == 0.5
            and admission['torso_up_dot_inclusive_minimum'] == 0.95, 'DISTINCT_UPRIGHT_ADMISSION')
    require(supervision['required_consecutive_standing_samples'] == 60
            and supervision['maximum_recovery_commands'] == 1200
            and supervision['original_joint_limits_required_at_standing'] is True
            and supervision['original_actuator_caps_preserved'] is True
            and supervision['minimum_nonfoot_clearance_m'] == 0.005
            and supervision['relative_com_height_gain_required'] is False, 'STANDING_CONTRACT')
    require(all(upright[k] is False for k in ('prone_to_standing_claimed',
            'partial_fall_standing_complete_synthesized', 'kick_energy_epoch_reset',
            'body_pose_or_velocity_writes', 'observation_rewriting')), 'UPRIGHT_NO_SYNTHESIS')
    coverage = design['development_coverage']
    require(coverage['held_out'] is False and coverage['physical_baseline_reuse'] is False
            and coverage['fresh_identity_per_attempt'] is True
            and coverage['first_pair']['roles'] == [prior.NO_KICK, prior.KICK], 'DEVELOPMENT_POPULATION')
    cells = [coverage['first_pair'], *coverage['additional_single_kick_diagnostics']]
    require([(c['seed'], c['prefix_phase']) for c in cells] == [(40846, 246), (40845, 245), (40841, 241), (40843, 243)]
            and coverage['maximum_expected_cells'] == 5, 'BRANCH_COVERAGE')


def audit():
    raw = (prior.ROOT / PATH).read_bytes()
    require(prior.digest(raw) == DESIGN_SHA, 'FROZEN_DESIGN_BYTES')
    design = json.loads(raw)
    validate(design)
    for key in ('predecessor_closure', 'post_exposure_diagnosis'):
        ref = design[key]
        path = (prior.ROOT / ref['path']).resolve()
        require(path.is_relative_to(prior.ROOT) and prior.binding(path)['raw_sha256'] == ref['raw_sha256'], 'EVIDENCE_BINDING')
    cases = []
    mutations = [
        ('grant_execution', ('physical_execution_authorized',), True),
        ('reuse_consumed_population', ('preserved_originals', 'r10p_retries_permitted'), True),
        ('hide_support_requirement', ('decisions', 'no_kick_handoff', 'required_hold_readiness'), []),
        ('confuse_hold_with_braking', ('decisions', 'no_kick_handoff', 'native_hold_policy'), 'sporespore_balanced_wave_recovery_initialized_zero_brake_v1'),
        ('accept_entry_as_standing', ('decisions', 'upright_recovery', 'entry_selection', 'entry_geometry_is_standing_success'), True),
        ('relax_final_joint_limits', ('decisions', 'upright_recovery', 'supervision', 'original_joint_limits_required_at_standing'), False),
        ('erase_partial_priority', ('decisions', 'upright_recovery', 'entry_selection', 'existing_prone_and_partial_routes_take_priority'), False),
        ('reset_kick_energy', ('decisions', 'upright_recovery', 'kick_energy_epoch_reset'), True),
    ]
    for label, keys, value in mutations:
        changed = copy.deepcopy(design)
        parent = changed
        for key in keys[:-1]:
            parent = parent[key]
        parent[keys[-1]] = value
        try:
            validate(changed)
        except ValueError as error:
            cases.append(dict(case=label, refused=True, failure_code=str(error)))
        else:
            raise ValueError('R10Q_DESIGN_CONTROL_ACCEPTED:' + label)
    return dict(ok=True, design_sha256=DESIGN_SHA, negative_controls=cases,
        implementation_status='not_implemented', world_build_count=0, solver_step_count=0,
        physical_execution_authorized=False, physical_acceptance_authority=False, release_authority=False)


if __name__ == '__main__':
    print(json.dumps(audit(), allow_nan=False))
