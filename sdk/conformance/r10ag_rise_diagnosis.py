"""Authenticate and reproduce AG tracking findings without upgrading its attempt."""
import argparse
import json
from pathlib import Path

import r10ag_rise_tracking_analysis as tracking

closure = tracking.closure
ROOT, EVIDENCE = closure.ROOT, closure.EVIDENCE
RUN = EVIDENCE / 'r10ag-rise-tracking-c1722c34260c41f28c3e17651226a436'
REJECTED = EVIDENCE / 'r10ag-rise-tracking-08f7758fe62e4f0eba01bed4613bbdaa'
RECORD = ROOT / 'sdk/recovery/r10ag_rise_diagnosis_v1.json'
CLAIMS = dict(original_attempt_reclassified=False,
    original_attempt_classification='consumed_infrastructure_invalid_after_world',
    physical_causal_effect_established=False, physical_recovery_success=False,
    complete_safety_gate_qualified=False, physical_acceptance_authority=False,
    release_authority=False, new_world_build_count=0, new_solver_step_count=0,
    sdk1_score='14/20', full_program_score='14/25')
NEXT = [
    'Exercise positive hold and walking reports through the entire production Python consumer in the distinct successor safety graph; native replay plus independent contact replay alone is insufficient.',
    'Design a distinct loaded-rise controller that addresses support retention and measured torso/joint response. First test its bounded geometry and real native interfaces on retained inputs with explicit diagnostic limits; do not equate virtual torso movement with an applied physical command.',
    'Do not simply restore the downward-only filter: the immutable AF mathematical diagnosis already records its planning stalls. Do not extend the timeout, loosen contact/standing thresholds or increase actuator caps to conceal the current failure.',
    'Declare a new population and complete applicable gate before a fresh bounded development world. AG seed 65248 and its source key remain consumed; later paired commissioning, official qualification, held-out acceptance and M07 adoption remain necessary for 15/20.',
]


def observations():
    before = closure.read(RUN / 'bindings-before.json')
    assert before == closure.read(RUN / 'bindings-after.json')
    for item in before:
        assert closure.bind(item['path']) == item, item['path']
    assert closure.read(RUN / 'execution.json') == dict(ok=True, source_unchanged=True,
        controls_returncode=0, world_build_count=0, solver_step_count=0,
        physical_acceptance_authority=False, release_authority=False)
    controls = (RUN / 'controls.stderr.txt').read_text()
    assert controls.count(' ... ok\n') == 12 and 'Ran 12 tests' in controls and controls.rstrip().endswith('OK')
    assert (RUN / 'controls.stdout.txt').read_bytes() == b''
    assert closure.read(REJECTED / 'execution.json')['ok'] is False
    assert 'Ran 0 tests' in (REJECTED / 'controls.stderr.txt').read_text()
    assert not (REJECTED / 'tracking.json').exists()
    assert closure.read(closure.RECORD)['claim_boundary'] == closure.CLAIMS
    data = closure.read(RUN / 'tracking.json')
    assert data == tracking.analyze()
    assert data['steps'] == 601 and data['command_links'] == 600
    mapping = data['canonical_motor_velocity_mapping_error_rad_s']
    assert mapping['count'] == 4800 and mapping['minimum'] == mapping['maximum'] == 0.
    loaded = data['modes']['loaded_geometry_rise']; seeking = data['modes']['seek_distal_load']
    assert (loaded['commands'], seeking['commands']) == (110, 490)
    assert loaded['all_four_qualified_after'] == 24
    assert loaded['unqualified_after_by_foot'] == [66, 86, 2, 50]
    assert loaded['planned_upward_fixed_torso_foot_motion_by_foot'] == [0, 88, 0, 0]
    assert all(m['hold_reason_counts'] == dict(none=m['commands']) for m in data['modes'].values())
    maximum_cap = max(s['maximum'] for m in data['modes'].values() for s in m['cap_fractions'])
    assert maximum_cap < 1.
    return dict(ok=True, synthetic_controls_passed=12, original_packets=601,
        exact_command_links=600, exact_canonical_motor_velocity_mappings=4800,
        loaded_rise_commands=110, retained_four_foot_support_after_loaded_rise=24,
        unqualified_after_loaded_by_foot=loaded['unqualified_after_by_foot'],
        front_right_upward_fixed_torso_targets=88,
        maximum_observed_actuator_cap_fraction=maximum_cap,
        loaded_mean_virtual_torso_rise_m=loaded['planned_virtual_torso_dy_m']['mean'],
        loaded_mean_measured_torso_rise_m=loaded['measured_torso_dy_m']['mean'],
        pose_trend=data['pose_trend'],
        maximum_fk_cap_position_error_m=max(x['maximum'] for x in data['fk_position_error_m_by_foot']),
        inference='The retained invalid report shows correct canonical velocity mapping and unused impulse capacity, but poor support retention during loaded rise. All 86 loaded commands followed by loss of four-foot support include a front-right support loss. The geometry also requests upward front-right motion at fixed torso in 88 loaded plans. These aggregate observations motivate support-aware control design; they do not establish causation, a matched effect, or a physical fix.',
        limits='One consumed infrastructure-invalid diagnostic report. Coordinate decomposition is algebraic and assumes ideal rigid forward kinematics; measured callback positions retain the residual. Command mapping equality does not imply target tracking, unused impulse capacity does not prove adequate closed-loop actuation, and virtual torso translation is not an applied physical command.',
        **CLAIMS)


def create():
    assert not RECORD.exists()
    observed = observations()
    paths = [Path(__file__), ROOT/'sdk/recovery/r10af_rise_diagnosis_v1.json',
        ROOT/'sdk/recovery/r10ag_consumer_repair_component_v1.json']
    record = dict(schema_version='sporespore_r10ag_rise_diagnosis_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
            authority_mode='post_exposure_retained_input_diagnosis', question_class='development'),
        source_parent_commit='e1d484dc39d9d7a5592a37b3b36fc17fa774b0f0',
        dependencies=[closure.bind(p) for p in paths],
        retained_evidence=[closure.bind(p) for root in (RUN, REJECTED) for p in sorted(root.iterdir()) if p.is_file()],
        observed=observed, claim_boundary=CLAIMS, next_actions=NEXT)
    closure.write_new(RECORD, record)
    return observed


def audit():
    record = closure.read(RECORD)
    assert record['claim_boundary'] == CLAIMS and record['next_actions'] == NEXT
    for item in record['dependencies'] + record['retained_evidence']:
        assert closure.bind(item['path']) == item, item['path']
    result = observations()
    assert result == record['observed']
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--create', action='store_true')
    print(json.dumps(create() if parser.parse_args().create else audit(), indent=2, allow_nan=False))
