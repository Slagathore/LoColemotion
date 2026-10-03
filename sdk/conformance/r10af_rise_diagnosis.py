"""Reproduce the retained post-exposure tracking and mathematical diagnosis."""
import argparse
import json
from pathlib import Path

import r10af_detection_frame_closure as closure
import r10af_rise_tracking_analysis as tracking
import r10af_rise_model_rollout as model

ROOT, EVIDENCE = closure.ROOT, closure.EVIDENCE
RUN = EVIDENCE / 'r10af-rise-diagnosis-c4dbca13c8164c52a628d13adddd79c1'
RECORD = ROOT / 'sdk/recovery/r10af_rise_diagnosis_v1.json'
NEXT = ('Declare R10AG selecting the existing V23 load-seeking and unrestricted loaded-rise geometry '
        'with the R10AF detection-frame contact source. Verify the selected native interfaces and '
        'complete prospective route safety before one fresh SingleKick diagnostic. Do not restore '
        'old contact classification, alter task limits, reuse consumed populations or infer physical '
        'success from mathematical propagation.')
CLAIMS = dict(original_result_regraded=False, physical_causal_effect_established=False,
    physical_recovery_success=False, official_qualification=False,
    physical_acceptance_authority=False, release_authority=False,
    new_world_build_count=0, new_solver_step_count=0, sdk1_score='14/20', full_program_score='14/25')


def observations():
    execution = closure.read(RUN / 'execution.json')
    assert execution['source_before'] == execution['source_after']
    for item in execution['source_before']:
        assert closure.bind(item['path']) == item
    assert execution['report'] == closure.bind(closure.CHILD / 'worker_report.json')
    assert execution['report']['raw_sha256'] == closure.REPORT_SHA
    assert execution['world_build_count'] == execution['solver_step_count'] == 0
    assert [r['name'] for r in execution['runs']] == ['controls', 'tracking', 'model']
    assert all(r['returncode'] == 0 for r in execution['runs'])
    controls = (RUN / 'controls.stderr.txt').read_text()
    assert controls.count(' ... ok\n') == 6 and 'Ran 6 tests' in controls and controls.rstrip().endswith('OK')
    assert (RUN / 'controls.stdout.json').read_bytes() == b''
    for name in ('tracking', 'model'):
        assert (RUN / (name+'.stderr.txt')).read_bytes() == b''
    track = closure.read(RUN / 'tracking.stdout.json')
    ideal = closure.read(RUN / 'model.stdout.json')
    assert track == tracking.analyze()
    assert ideal == model.analyze()
    assert track['command_links'] == 600 and track['steps'] == 601
    mapping = track['canonical_motor_velocity_mapping_error_rad_s']
    assert mapping['count'] == 4800 and mapping['minimum'] == mapping['maximum'] == 0.
    loaded = track['modes']['loaded_downward_rise']
    assert loaded['commands'] == 138 and loaded['unqualified_after_by_foot'] == [26, 61, 1, 63]
    maximum_cap = max(s['maximum'] for m in track['modes'].values() for s in m['applied_cap_fraction_by_joint'])
    assert maximum_cap < 1.0
    assert ideal['original_loaded_plan_parity_count'] == 138
    primary = ideal['trajectories']
    assert [t['original_semantic_step'] for t in primary] == [513, 1112]
    assert [t['result']['updates'] for t in primary] == [243, 8]
    assert all(t['result']['stop'] == 'no_admissible_cost_decreasing_plan' for t in primary)
    alternate = ideal['predecessor_filter_ablation']
    assert [t['original_semantic_step'] for t in alternate] == [513, 1112]
    assert all(t['result']['updates'] == 600 and abs(t['result']['final']['modeled_height_goal_gap_m']) < .00025 for t in alternate)
    return dict(ok=True, synthetic_controls_passed=6, original_packets=601,
        exact_command_links=600, exact_canonical_motor_velocity_mappings=4800,
        maximum_observed_actuator_cap_fraction=maximum_cap,
        loaded_rise_commands=138, unqualified_after_loaded_by_foot=[26, 61, 1, 63],
        pose_trend=track['pose_trend'], joint_limit_excursion_count=len(track['joint_boundary_excursions']),
        original_loaded_plan_parity_count=138,
        mathematical_downward_filter=[dict(start=t['original_semantic_step'], updates=t['result']['updates'],
            final_height_goal_gap_m=t['result']['final']['modeled_height_goal_gap_m']) for t in primary],
        mathematical_predecessor_filter=[dict(start=t['original_semantic_step'], updates=600,
            final_height_goal_gap_m=t['result']['final']['modeled_height_goal_gap_m']) for t in alternate],
        inference='Exact command mapping and unused impulse capacity do not explain away the physical tracking failure. Within the declared ideal model, the downward-only filter stalls both selected poses; the predecessor filter reaches its height objective closely. This motivates a distinct source-corrected V23 diagnostic, not a physical effect claim.',
        model_limits=ideal['protocol']+' '+ideal['limits'], **CLAIMS)


def create():
    assert not RECORD.exists()
    result = observations()
    paths = [Path(__file__), Path(tracking.__file__), Path(model.__file__), Path(model.geometry.__file__),
        Path(closure.__file__), Path(closure.streams.__file__), Path(closure.streams.diagnosis.__file__),
        closure.RECORD, ROOT/'tests/test_r10af_rise_analysis.py',
        ROOT/'sdk/core/src/recovery_runtime/partial_downward_rise_control.rs',
        ROOT/'sdk/core/src/recovery_runtime/partial_load_seeking_control.rs',
        ROOT/'sdk/core/src/recovery_runtime/partial_pose_geometry_control.rs',
        ROOT/'sdk/adapters/godot/gdscript/recovery_native_route_v1.gd',
        ROOT/'sdk/adapters/godot/gdscript/recovery_native_world_v1.gd']
    record = dict(schema_version='sporespore_r10af_rise_diagnosis_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt_and_geometry_model',
            authority_mode='post_exposure_retained_input_diagnosis', question_class='development'),
        source_parent_commit='69e8916e9c6b6f017ccd36ed6364714d8694a867',
        dependencies=[closure.bind(p) for p in paths],
        retained_evidence=[closure.bind(p) for p in sorted(RUN.iterdir()) if p.is_file()],
        observed=result, claim_boundary=CLAIMS, next_action=NEXT)
    closure.write_new(RECORD, record)
    return result


def audit():
    record = closure.read(RECORD)
    assert record['claim_boundary'] == CLAIMS and record['next_action'] == NEXT
    for item in record['dependencies']+record['retained_evidence']:
        assert closure.bind(item['path']) == item, item['path']
    result = observations()
    assert result == record['observed']
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--create', action='store_true')
    print(json.dumps(create() if parser.parse_args().create else audit(), indent=2))
