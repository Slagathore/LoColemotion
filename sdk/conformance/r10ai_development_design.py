"""Validate the prospective AI diagnostic declaration; never grant a launch."""
import json
from pathlib import Path
import r10ai_worker_component as worker

ROOT=worker.ROOT
DESIGN=ROOT/'sdk/recovery/r10ai_concurrent_load_rise_development_design_v1.json'


def audit():
    read=worker.native.closure.read
    value=read(DESIGN)
    assert value['schema_version']=='sporespore_r10ai_concurrent_load_rise_development_design_v1'
    assert value['ledger_scope']['question_class']=='development'
    for row in value['dependencies']:worker.native.verify(row)
    predecessor=read(ROOT/'sdk/recovery/r10ag_detection_frame_load_seeking_design_v1.json')
    assert value['preserved']==predecessor['preserved']
    assert value['limits']==predecessor['limits']
    change=value['controlled_change'];worker.native.verify(change['runtime_binding']);worker.native.verify(change['selected_runtime'])
    assert change['selected_runtime']==read(worker.native.BINDING)['runtime']
    assert change['to_controller']=='sporespore_exact_s169_partial_concurrent_load_rise_controller_v25'
    assert change['composition']=='sporespore_r10ai_partial_concurrent_load_rise_v25_v7_composition_v1'
    assert change['entry_export']=='ss_recovery_r10ai_partial_entry_control_v1_json'
    assert change['step_export']=='ss_recovery_r10ai_partial_step_control_v1_json'
    probe=value['first_probe']
    assert probe['seed']==67248 and probe['prefix_phase']==248 and probe['attempt_limit']==1
    assert probe['seed_label']=='R10AI-CONCURRENT-LOAD-RISE-PREFIX-248-V1'
    assert probe['roles']==['kick_passive_recovery_resume']
    assert probe['execution_mode']=='single_kick_controller_diagnostic_v1'
    assert probe['held_out'] is False and probe['fresh_setup'] is True and probe['baseline_reuse'] is False
    for name in ('complete_physical_route_integrated','complete_report_consumer_qualified','launch_enabled',
        'physical_execution_authorized','held_out_campaign_declared','physical_acceptance_authority','release_authority'):
        assert value[name] is False,name
    assert value['world_build_count']==value['solver_step_count']==0
    component=worker.audit()
    return dict(ok=True,design=worker.native.closure.bind(DESIGN),worker_component=component['observed'],
        diagnostic_seed=67248,prefix_phase=248,prospective_probe_declared=True,launch_enabled=False,
        physical_acceptance_authority=False,release_authority=False)


if __name__=='__main__':print(json.dumps(audit(),indent=2))
