"""Audit the prospective V28 diagnostic; declaration never enables a world."""
import json
import r10ap_segment_component as segment

worker, native = segment.worker, segment.native
ROOT = segment.ROOT
DESIGN = ROOT/'sdk/recovery/r10ap_progressive_headroom_development_design_v1.json'


def audit():
    value = native.closure.read(DESIGN)
    assert value['schema_version'] == 'sporespore_r10ap_progressive_headroom_development_design_v1'
    assert value['ledger_scope']['question_class'] == 'development'
    for item in value['dependencies']:
        native.builds.verify(item)
    old = native.closure.read(ROOT/'sdk/recovery/r10am_support_anchored_development_design_v1.json')
    assert value['preserved'] == old['preserved'] and value['limits'] == old['limits']
    change = value['controlled_change']
    native.builds.verify(change['runtime_binding'])
    native.builds.verify(change['selected_runtime'])
    assert change['selected_runtime'] == native.closure.read(native.BINDING)['runtime']
    assert change['from_controller'] == old['controlled_change']['to_controller']
    assert change['to_controller'] == 'sporespore_exact_s169_partial_progressive_headroom_controller_v28'
    assert change['composition'] == 'sporespore_r10ap_partial_progressive_headroom_v28_v7_composition_v1'
    assert change['entry_export'] == 'ss_recovery_r10ap_partial_entry_control_v1_json'
    assert change['step_export'] == 'ss_recovery_r10ap_partial_step_control_v1_json'
    probe = value['first_probe']
    assert (probe['seed'], probe['prefix_phase'], probe['attempt_limit']) == (70248, 248, 1)
    assert probe['seed_label'] == 'R10AP-PROGRESSIVE-HEADROOM-PREFIX-248-V1'
    assert probe['roles'] == ['kick_passive_recovery_resume']
    assert probe['execution_mode'] == 'single_kick_controller_diagnostic_v1'
    assert probe['held_out'] is False and probe['fresh_setup'] is True and probe['baseline_reuse'] is False
    for key in ('complete_physical_route_integrated', 'complete_report_consumer_qualified',
            'launch_enabled', 'physical_execution_authorized', 'held_out_campaign_declared',
            'physical_acceptance_authority', 'release_authority'):
        assert value[key] is False, key
    assert value['world_build_count'] == value['solver_step_count'] == 0
    result = segment.audit()
    return dict(ok=True, design=native.closure.bind(DESIGN),
        worker_component=worker.audit()['observed'], segment_component=result['observed'],
        diagnostic_seed=70248, prefix_phase=248, prospective_probe_declared=True,
        launch_enabled=False, physical_acceptance_authority=False, release_authority=False)


if __name__ == '__main__':
    print(json.dumps(audit(), indent=2))
