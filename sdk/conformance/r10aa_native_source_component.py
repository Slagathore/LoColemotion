"""Close the R10AA source composition and actual native forwarding checks.

This component does not qualify the worker, complete report reader or physics.
"""
import argparse
import json
from pathlib import Path
import r10aa_native_component as native

ROOT, EVIDENCE = native.ROOT, native.EVIDENCE
RECORD = ROOT/'sdk/recovery/r10aa_native_source_component_v1.json'
API = EVIDENCE/'r10aa-native-api-0b50a46c91f94c8999346ff702b4c62e'
CHECK = EVIDENCE/'r10aa-native-interface-check-bc564e56ad0f446e892933d0f13efc0d'
BUILD = EVIDENCE/'r10aa-native-build-launch-fa845c85b9f44994a1a940f0a5bb103f'
TARGETED = EVIDENCE/'r10aa-composition-check-d8d565841e2340ab84024be56da95c88'


def observations():
    assert native.audit()['ok']
    runtime, fixtures = native.runtime()
    assert runtime['core_test_count']==447 and len(fixtures)==5
    for name in ('native','cold','godot'):
        assert native.read(CHECK/(name+'.execution.json'))['exit_code']==0
        assert not (CHECK/(name+'.stderr.log')).read_bytes() or name=='godot'
    assert native.read(BUILD/'execution.json')['exit_code']==0
    cold=json.loads((CHECK/'cold.stdout.log').read_text(encoding='utf-8-sig').strip().removeprefix('R10AA_NATIVE_COMPONENT '))
    assert cold['ok'] and cold['cold_replayed']==42
    assert native.read(API/'source_before.json')==native.read(API/'source_after.json')
    result=native.read(API/'native-api.json')
    assert result['ok'] and result['checks'] and all(result['checks'].values())
    assert result['new_fixture_calls']==result['negative_calls']==5
    for identity in ('partial_entry','partial_step_1','partial_step_2','partial_step_3','partial_step_63'):
        assert all(result['checks'][identity+suffix] for suffix in ('_method','_native_success','_exact_value','_crossed_schema_refused'))
    assert result['world_build_count']==result['solver_step_count']==0
    assert result['physical_acceptance_authority'] is result['release_authority'] is False
    assert native.read(API/'native-api.execution.json')['exit_code']==0
    assert not (API/'native-api.stderr.log').read_bytes()
    assert native.read(TARGETED/'source_before.json')==native.read(TARGETED/'source_after.json')
    assert native.read(TARGETED/'execution.json')['exit_code']==0
    log=(TARGETED/'stdout.log').read_text(encoding='utf-8-sig')
    assert 'test result: ok. 6 passed; 0 failed;' in log
    assert 'r10aa_retained_geometry_is_the_actual_bounded_command_in_both_phases ... ok' in log
    assert len(runtime['source_files'])==117
    return dict(controller_kernel_implemented=True,source_bound_composition_implemented=True,
        core_tests=447,targeted_composition_tests=6,exposed_command_input_count=244,
        support_and_rise_command_checks=488,c_abi_native_calls=42,c_abi_negative_controls=17,
        original_response_byte_comparisons=20,independent_cold_replay_calls=42,
        godot_fixture_calls=5,godot_negative_calls=5,godot_check_count=len(result['checks']),
        godot_forwarders_executed=True,runtime=runtime['runtime'],compiled_source_count=117,
        worker_integrated=False,complete_report_reader_integrated=False,launcher_integrated=False,
        complete_smoke_safety_gate_passed=False,successor_physics_observed=False,
        world_build_count=0,solver_step_count=0,physical_acceptance_authority=False,release_authority=False)


def dependencies():
    return [native.diagnosis.binding(p) for p in (Path(__file__),native.RECORD,native.BINDING,
        ROOT/'sdk/core/src/recovery_runtime/partial_load_seeking_composition.rs',
        ROOT/'sdk/core/src/recovery_runtime/tests/partial_load_seeking_composition_tests.rs',
        ROOT/'tests/test_r10aa_native_api.py',ROOT/'tests/test_r10aa_native_api.gd')]


def run(capture=False):
    observed=observations()
    if capture:
        assert not RECORD.exists()
        value=dict(schema_version='sporespore_r10aa_native_source_component_v1',
            ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',
                authority_mode='zero_world_source_and_native_interface_component',question_class='development'),
            dependencies=dependencies(),retained_evidence=[native.diagnosis.binding(p)
                for folder in (API,CHECK,BUILD,TARGETED) for p in sorted(folder.iterdir()) if p.is_file()],
            observed=observed,
            next_action='Integrate distinct task-source bridge, production worker, complete report reader and launcher. Run real interfaces and the complete applicable smoke safety graph before a fresh bounded R10AA development world. Preserve consumed R10Y/R10Z evidence.')
        native.write(RECORD,value)
    else:
        value=native.read(RECORD)
        assert value['dependencies']==dependencies()
        for item in value['retained_evidence']:native.verify(item)
        assert value['observed']==observed
    return observed


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture',action='store_true')
    args=parser.parse_args()
    print('R10AA_NATIVE_SOURCE_COMPONENT '+json.dumps(run(args.capture)),flush=True)
