"""Audit the actual R10R Godot source bridge and synthetic worker sequence."""
import argparse
import json
from pathlib import Path

from r10r_native_component import ROOT, EVIDENCE, BINDING, ExactInputCore, bind, read, write

DIRECTORY = EVIDENCE / 'r10r-task-source-b1cc388a42f040a888b7ed90c12a67f8'
RECORD = ROOT / 'sdk/recovery/r10r_source_component_v1.json'
PRIOR_RUNS = ['r10r-task-source-7dc802d06b914855b70fd8a07f925d40',
    'r10q-source-orchestration-34c5da8811014c58b0852b4d48326510',
    'r10r-task-source-8296934cb90a4e01a9927bdf5d3b7190',
    'r10r-task-source-647b87334aea476e8d0988d73dfa262a',
    'r10r-task-source-a96c2640d3ae4b84b3272ee7066a7650',
    'r10r-task-source-3aed0d5cd2e442babdd94d94798c5008']
SOURCE_PATHS = ['sdk/adapters/godot/gdscript/recovery_task_source_selector_v1.gd',
    *['sdk/adapters/godot/gdscript/r10r_'+name+'_v1.gd' for name in
      ['upright_task_source','upright_recovery_stage','recovery_orchestrator','recovery_worker','development_seed']],
    *['tests/test_development_r10r_'+name for name in
      ['task_source.py','task_source.gd','original_q_source.gd','worker_hooks.gd']],
    'tests/test_development_r10q_source_orchestration.py',
    'sdk/conformance/r10r_source_component.py']


def inspect(cold):
    assert (DIRECTORY/'source_before.json').read_bytes() == (DIRECTORY/'source_after.json').read_bytes()
    counts = {}
    for name in ['direct-worker','direct-task-source','original-q-source']:
        execution = read(DIRECTORY/(name+'.execution.json'))
        assert execution['exit_code'] == 0 and execution['world_build_count'] == execution['solver_step_count'] == 0
        assert (DIRECTORY/(name+'.stderr.log')).read_bytes() == b''
        result = read(DIRECTORY/(name+'.json'))
        assert result['ok'] is True and result['checks'] and all(v is True for v in result['checks'].values())
        assert result['world_build_count'] == result['solver_step_count'] == 0
        assert result['physical_acceptance_authority'] is False and result['release_authority'] is False
        counts[name] = len(result['checks'])
    worker = read(DIRECTORY/'direct-worker.json')
    assert worker['synthetic_measurements_only'] is True and worker['selector_and_launcher_validation_exercised'] is False
    entries, steps = worker['entry_packets'], worker['upright_packets']
    assert len(entries) == 240 and len(steps) == 63
    assert worker['final_state']['phase'] == 'fresh_selected_policy_walking_resume'
    assert worker['final_upright_memory']['standing_samples_observed'] == 60
    assert [p['native_receipt']['step']['prior_phase'] for p in steps] == [
        'establish_distal_support', 'raise_body', 'stance_handoff', *['stance_dwell']*60]
    assert steps[0]['native_receipt']['next_control']['controller_id'] == 'sporespore_exact_s169_prone_to_standing_controller_v12'
    assert steps[1]['bound_observations']['observation_v3']['controller_ownership']['recovery_controller_id'] == 'sporespore_exact_s169_prone_to_standing_controller_v12'
    runtime = read(BINDING)
    core = ExactInputCore(runtime['runtime']['path']) if cold else None
    for index, packet in enumerate(entries + steps):
        call = packet['call']
        assert call['ok'] is True and call['compiled_call_count'] == 1
        assert packet['world_build_count'] == packet['solver_step_count'] == 0
        if index >= 240:
            assert call['method'] == 'recovery_r10r_upright_step_control_v1_json'
            assert packet['native_receipt']['control_composition_id'] == 'sporespore_r10r_upright_v20_v12_v7_control_composition_v1'
        else:
            assert call['method'] == 'recovery_r10q_upright_entry_control_v1_json'
        if core:
            core._call_json_input('ss_'+call['method'], call['request']['utf8_text'].encode())
            assert core.raw_response == call['response']['utf8_text'].encode(), index
    return dict(ok=True, interface_tests=3, checks=counts, native_source_calls_cold_replayed=303 if cold else 0,
        passive_samples=240, upright_samples=63, consecutive_standing_samples=60,
        actual_v12_raise_owner_measured_in_synthetic_source=True, original_q_source_compatible=True,
        full_report_publisher_and_reader_validated=False, launcher_seed_prerequisites_validated=False,
        walking_startup_runtime_key_qualified=False, complete_smoke_safety_gate_passed=False,
        successor_physics_observed=False, physical_world_count=0, solver_step_count=0,
        physical_acceptance_authority=False, release_authority=False, sdk1_score='14/20')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--create', action='store_true')
    parser.add_argument('--cold', action='store_true')
    args = parser.parse_args()
    if args.create:
        observed = inspect(True)
        write(RECORD, dict(schema_version='sporespore_r10r_source_component_v1',
            ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
                authority_mode='synthetic_production_source_and_worker_component', question_class='development'),
            evidence_root=DIRECTORY.as_posix(), runtime_binding=bind(BINDING),
            native_component=bind(ROOT/'sdk/recovery/r10r_upright_native_component_v1.json'),
            source_bindings=[bind(ROOT/p) for p in SOURCE_PATHS], observed=observed,
            retained_evidence=[bind(p) for directory in [DIRECTORY, *[EVIDENCE/name for name in PRIOR_RUNS]]
                               for p in sorted(directory.rglob('*')) if p.is_file()],
            retained_refusals=['Inherited TestCase import exposed a historical Q dependency key; fixed discovery without rebinding Q.',
                              'Worker fixture selected the old fixture name; corrected to the actual R10R emitted fixture.']))
    else:
        record = read(RECORD)
        for item in record['source_bindings'] + record['retained_evidence'] + [record['runtime_binding'], record['native_component']]:
            assert bind(item['path']) == item, item['path']
        observed = inspect(args.cold)
        expected = dict(record['observed'])
        if not args.cold: expected['native_source_calls_cold_replayed'] = 0
        assert expected == observed
    print('R10R_SOURCE_COMPONENT ' + json.dumps(observed), flush=True)


if __name__ == '__main__': main()
