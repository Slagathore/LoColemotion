"""Close the R10Z kernel, native composition and actual Godot API checks.

This component does not qualify the worker, report reader, launcher or physics.
"""
import argparse
import json
from pathlib import Path
import r10z_native_component as native

ROOT, EVIDENCE = native.ROOT, native.EVIDENCE
RECORD = ROOT/'sdk/recovery/r10z_geometry_source_component_v1.json'
API = EVIDENCE/'r10z-native-api-a03dd4882f7548228dfb49dd44199f47'
CHECK = EVIDENCE/'r10z-interface-check-9b841376889c482abccfb4e7dab43bee'
TARGETED = EVIDENCE/'r10z-geometry-kernel-e8d680903c1d47b6934656c05b71d7c0'


def observations():
    assert native.audit()['ok']
    runtime, fixtures = native.runtime()
    assert runtime['core_test_count'] == 432 and len(fixtures) == 5
    execution = native.read(CHECK/'execution.json')
    assert execution['cold_exit_code'] == execution['godot_exit_code'] == 0
    cold = json.loads(
        (CHECK/'cold.stdout.txt').read_text(encoding='utf-8-sig').strip().removeprefix('R10Z_NATIVE_COMPONENT '))
    assert cold['ok'] and cold['cold_replayed'] == 40
    assert native.read(API/'source_before.json') == native.read(API/'source_after.json')
    result = native.read(API/'native-api.json')
    assert result['ok'] and result['checks'] and all(result['checks'].values())
    assert result['new_fixture_calls'] == result['negative_calls'] == 5
    for identity in ('partial_entry','partial_step_1','partial_step_2','partial_step_3','partial_step_63'):
        assert all(result['checks'][identity+suffix] for suffix in ('_method','_native_success','_exact_value','_crossed_schema_refused'))
    assert result['world_build_count'] == result['solver_step_count'] == 0
    assert result['physical_acceptance_authority'] is result['release_authority'] is False
    assert native.read(API/'native-api.execution.json')['exit_code'] == 0
    assert not (API/'native-api.stderr.log').read_bytes()
    assert native.read(TARGETED/'source_before.json') == native.read(TARGETED/'source_after.json')
    assert native.read(TARGETED/'execution.json')['exit_code'] == 0
    log = (TARGETED/'tests.stdout.txt').read_text(encoding='utf-8-sig')
    assert 'test result: ok. 13 passed; 0 failed;' in log
    plans = [json.loads(line.partition(' ')[2]) for line in log.splitlines() if line.startswith('R10Z_GEOMETRY_ENTRY ')]
    assert {row['seed'] for row in plans} == {41341,51007,51008,51009}
    assert all(row['plan']['candidate_count'] == 135 and row['plan']['hold_reason'] is None for row in plans)
    return dict(controller_kernel_implemented=True, source_bound_composition_implemented=True,
        core_tests=432,targeted_tests=13,retained_entry_seeds=[41341,51007,51008,51009],
        c_abi_native_calls=40,c_abi_negative_controls=17,original_response_byte_comparisons=18,
        independent_cold_replay_calls=40,godot_fixture_calls=5,godot_negative_calls=5,
        godot_check_count=len(result['checks']),godot_forwarders_executed=True,
        runtime=runtime['runtime'],compiled_source_count=len(runtime['source_files']),
        worker_integrated=False,complete_report_reader_integrated=False,launcher_integrated=False,
        complete_smoke_safety_gate_passed=False,successor_physics_observed=False,
        world_build_count=0,solver_step_count=0,physical_acceptance_authority=False,release_authority=False)


def bindings():
    return [native.diagnosis.binding(p) for p in [Path(__file__),native.RECORD,native.BINDING,
        ROOT/'sdk/recovery/r10z_pose_geometry_kernel_contract_v1.json',
        ROOT/'sdk/recovery/r10z_pose_geometry_kernel_contract_v2.json',
        ROOT/'tests/test_r10z_native_api.py',ROOT/'tests/test_r10z_native_api.gd']]


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture',action='store_true')
    args=parser.parse_args()
    observed=observations()
    if args.capture:
        value=dict(schema_version='sporespore_r10z_geometry_source_component_v1',
            ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='zero_world_source_and_native_interface_component',question_class='development'),
            dependencies=bindings(),retained_evidence=[native.diagnosis.binding(p)
                for folder in (API,CHECK,TARGETED) for p in sorted(folder.iterdir()) if p.is_file()],
            observed=observed,next_action='Integrate distinct task-source/bridge, production worker, complete report reader and launcher. Run real interfaces and the complete applicable smoke safety graph before a fresh bounded R10Z development world. Preserve R10Y consumed evidence.')
        native.write(RECORD,value)
    else:
        value=native.read(RECORD)
        assert value['dependencies']==bindings()
        for item in value['retained_evidence']:
            native.verify(item)
        assert value['observed']==observed
    print('R10Z_SOURCE_COMPONENT '+json.dumps(observed))
