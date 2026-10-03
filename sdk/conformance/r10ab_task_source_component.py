"""Audit real Godot R10AB source projection, with no physical claim."""
import argparse
import json
from pathlib import Path

import r10ab_native_component as native

ROOT, EVIDENCE = native.ROOT, native.EVIDENCE
RECORD = ROOT / 'sdk/recovery/r10ab_task_source_component_v1.json'
POSITIVE = EVIDENCE / 'r10ab-task-source-0a6ae11abbdb4310bb213bd8b1855778'
WRAPPERS = ('r10ab-worker-source-check-321ad2b61b644196a727383852b1c058',)
PATHS = ('sdk/adapters/godot/gdscript/recovery_task_source_selector_v1.gd',
         'sdk/adapters/godot/gdscript/r10ab_partial_recovery_stage_v1.gd',
         'sdk/adapters/godot/gdscript/r10ab_partial_task_source_v1.gd',
         'tests/test_development_r10ab_task_source.py',
         'tests/test_development_r10ab_task_source.gd',
         'tests/test_development_r10ab_original_partial_source.gd',
         'tests/test_development_r10q_source_orchestration.py',
         'tests/test_development_r10k_task_source.gd',
         'tests/test_r10ab_loaded_source.py', 'tests/test_r10ab_loaded_source.gd',
         'sdk/conformance/r10ab_task_source_component.py')


LOADED = EVIDENCE/'r10ab-loaded-source-cbb4b3da944848d08c1f20be6c2606e2'
LOADED_WRAPPER = EVIDENCE/'r10ab-worker-repair-check-5dc44f8bde07487b96f033442bbcec8f'
FAILED_LOADED = (EVIDENCE/'r10ab-loaded-source-b68f20eb7a4a4333a95fd5f2cfcf3005',
                 EVIDENCE/'r10ab-loaded-source-af9fbb926c60438e949861d5129e90a4')
FAILED_WRAPPERS = (EVIDENCE/'r10ab-worker-repair-check-cdeb5f689c9b4d25b59ed8826502f3d4',
                   EVIDENCE/'r10ab-worker-repair-check-486629fefb7547928a0914d4dfc91879')


def loaded_inputs():
    import copy
    import r10aa_first_support_closure as previous
    assert native.read(LOADED/'source_before.json') == native.read(LOADED/'source_after.json')
    assert native.read(LOADED_WRAPPER/'loaded.execution.json')['exit_code'] == 0
    assert native.read(LOADED/'loaded-source.execution.json')['exit_code'] == 0
    result=native.read(LOADED/'loaded-source.json')
    assert result['ok'] and len(result['checks'])==574 and all(result['checks'].values())
    assert result['loaded_inputs']==44 and result['negative_checks']==352 and result['synthetic_inputs'] is True
    assert result['world_build_count']==result['solver_step_count']==0
    assert result['physical_acceptance_authority'] is result['release_authority'] is False
    value=native.read(LOADED/'fixtures.json')
    assert value['original_report']==native.diagnosis.binding(previous.CHILD/'worker_report.json')
    assert value['runtime_binding']==native.diagnosis.binding(native.BINDING)
    rows=value['fixtures'];assert len(rows)==44
    index=0
    for kind,packet in previous.partial_records(previous.CHILD/'worker_report.json'):
        if kind!='packet' or (packet['native_receipt'].get('next_load_plan') or {}).get('mode')!='loaded_geometry_rise':continue
        row=rows[index];original=json.loads(packet['call']['request']['utf8_text'])
        assert row['original_request_sha256']==packet['call']['request']['raw_sha256']
        assert row['original_partial_step']==packet['native_receipt']['step']['memory']['total_steps_observed']
        assert row['synthetic_input'] is True
        request=copy.deepcopy(row['request'])
        assert request['schema_version']=='sporespore_r10ab_partial_downward_rise_step_control_request_v1'
        request['schema_version']=original['schema_version']
        for group in ('collection','step'):
            owner=request[group]['observation']['controller_ownership']
            assert owner['recovery_controller_id']=='sporespore_exact_s169_partial_downward_rise_controller_v24'
            owner['recovery_controller_id']=original[group]['observation']['controller_ownership']['recovery_controller_id']
        binding=request['collection']['observation_source_binding']
        for key in ('observation_base_sha256','portable_observation_sha256','source_chain_sha256'):
            binding[key]=original['collection']['observation_source_binding'][key]
        assert request==original
        envelope=json.loads(row['native_response_utf8'])
        assert envelope['ok'] is True and envelope['value']==row['expected']
        plan=row['expected']['next_load_plan'];assert plan['mode']=='loaded_downward_rise' and plan['hold_reason'] is None
        dy=plan['virtual_translation_world_m'][1];assert dy>0
        assert all(v<=-.25*dy+1e-12 for v in plan['rise_geometry']['selected_fixed_torso_foot_delta_y_m'])
        index+=1
    assert index==44
    for folder,wrapper in zip(FAILED_LOADED,FAILED_WRAPPERS):
        assert native.read(folder/'source_before.json')==native.read(folder/'source_after.json')
        assert native.read(wrapper/'loaded.execution.json')['exit_code']==1
    assert 'r10ab_partial_control_native_collection_refused' in (FAILED_WRAPPERS[0]/'loaded.stderr.log').read_text(encoding='utf-8-sig')
    assert native.read(FAILED_LOADED[1]/'loaded-source.execution.json')['exit_code']==1
    assert 'Cannot find member "TaskSource"' in (FAILED_LOADED[1]/'loaded-source.stderr.log').read_text(encoding='utf-8')
    return 574


def reconstruct():
    assert native.audit()['ok']
    assert native.read(POSITIVE / 'source_before.json') == native.read(POSITIVE / 'source_after.json')
    counts = {}
    for name, expected in (('partial-source', 163), ('original-partial-source', 99)):
        result = native.read(POSITIVE / (name + '.json'))
        execution = native.read(POSITIVE / (name + '.execution.json'))
        assert execution['exit_code'] == 0 and result['ok'] is True
        assert len(result['checks']) == expected and all(v is True for v in result['checks'].values())
        assert result['checks']['no_inserted_body'] is True
        assert result['world_build_count'] == result['solver_step_count'] == 0
        assert result['physical_acceptance_authority'] is result['release_authority'] is False
        counts[name] = expected
    counts['loaded-source']=loaded_inputs()
    for name in WRAPPERS:
        assert native.read(EVIDENCE / name / 'source.execution.json')['exit_code'] == 0
    result = dict(ok=True, interface_tests=3, checks=counts, total_checks=836, loaded_input_count=44, loaded_source_negative_checks=352, synthetic_fixture_failures_retained=2,
        new_partial_source_preserves_measured_values=True,
        conflicting_tasks_refused_before_sampler_reads=True,
        original_partial_source_compatible_on_new_dll=True,
        full_worker_sequence_checked=False, launcher_reader_integrated=False,
        complete_smoke_safety_gate_passed=False, successor_physics_observed=False,
        world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)
    return result


def capture():
    assert not RECORD.exists()
    result = reconstruct()
    evidence = [p for folder in (POSITIVE, LOADED, LOADED_WRAPPER, *FAILED_LOADED, *FAILED_WRAPPERS, *(EVIDENCE / p for p in WRAPPERS))
                for p in sorted(folder.iterdir()) if p.is_file()]
    record = dict(schema_version='sporespore_r10ab_task_source_component_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='zero_world_source_component', question_class='development'),
        evidence_root=POSITIVE.as_posix(), native_component=native.diagnosis.binding(native.RECORD),
        source_bindings=[native.diagnosis.binding(ROOT / p) for p in PATHS],
        retained_evidence=[native.diagnosis.binding(p) for p in evidence], observed=result)
    native.write(RECORD, record)
    return result


def audit():
    record = native.read(RECORD)
    for item in record['source_bindings'] + record['retained_evidence'] + [record['native_component']]:
        native.verify(item)
    result = reconstruct()
    assert result == record['observed']
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', action='store_true')
    args = parser.parse_args()
    print('R10AB_SOURCE_COMPONENT ' + json.dumps(capture() if args.capture else audit()), flush=True)
