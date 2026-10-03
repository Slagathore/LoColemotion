"""Check selected V23 interfaces in the existing DLL, with zero worlds.

Run --run under the repository native-operation lock. This is a real-interface
component check, not qualification of the new Godot route or permission to launch.
"""
import argparse
import copy
import json
from pathlib import Path
import uuid

import r10af_detection_frame_closure as closure
import development_passive_entry_profile as entry
from development_recovery_refusal import RecordedCore
from sporespore_locomotion import LocomotionCoreError

ROOT, EVIDENCE = closure.ROOT, closure.EVIDENCE
DESIGN = ROOT/'sdk/recovery/r10ag_detection_frame_load_seeking_design_v1.json'
RECORD = ROOT/'sdk/recovery/r10ag_native_interface_component_v1.json'
FIXTURE_BINDING = ROOT/'sdk/development/recovery_candidates/r10aa-partial-load-seeking-core-v1.runtime.json'


def inputs():
    design = closure.read(DESIGN)
    assert design['controlled_change']['to_controller'] == 'sporespore_exact_s169_partial_load_seeking_controller_v23'
    assert design['preserved']['contact_profile'] == 'godot_jolt_distal_contact_detection_frame_v1'
    assert design['first_probe']['seed'] == 65248 and design['launch_enabled'] is False
    for item in design['dependencies']:
        actual = closure.bind(ROOT/item['path']); actual['path'] = item['path']
        assert actual == item
    runtime = design['controlled_change']['selected_runtime']
    assert closure.bind(runtime['path']) == runtime
    fixture_binding = closure.read(FIXTURE_BINDING)['compiled_fixtures']
    assert closure.bind(fixture_binding['path']) == fixture_binding
    fixtures = [json.loads(line.partition(' ')[2]) for line in Path(fixture_binding['path']).read_text(encoding='utf-8').splitlines()
        if line.startswith('R10AA_PARTIAL_FIXTURE ')]
    assert [f['id'] for f in fixtures] == ['partial_entry', 'partial_step_1', 'partial_step_2', 'partial_step_3', 'partial_step_63']
    assert all(f['physical_source'] is False for f in fixtures)
    return runtime, fixture_binding, fixtures


def cases(fixtures):
    for fixture in fixtures:
        yield fixture['id'], 'ss_'+fixture['method']+'_json', fixture['request'], fixture['expected']
    for case in range(11):
        q = copy.deepcopy(fixtures[1]['request'])
        if case == 0: q['schema_version'] = 'sporespore_partial_fall_step_control_request_v1'
        elif case == 1: q['collection']['task_id'] = 'sporespore_measured_upright_recovery_to_standing_v1'
        elif case == 2: q['collection']['observation_source_binding']['source_route_id'] = 'unregistered'
        elif case == 3: q['collection']['observation']['controller_ownership']['recovery_controller_id'] = 'sporespore_exact_s169_partial_downward_rise_controller_v24'
        elif case == 4: q['step']['observation']['semantic_step'] += 1
        elif case == 5: q['step']['observation']['energy_balance']['cumulative_signed_external_work_j'] = 0.0
        elif case == 6: q['step']['memory']['phase'] = 'stance_dwell'
        elif case == 7: q['collection']['observation']['state']['ordered_joint_observations'][0]['position_rad'] = None
        elif case == 8: q['collection']['runtime_binding']['collector_id'] = 'unregistered'
        elif case == 9: q['collection']['descriptor']['torso_length_scale'] += .01
        else: q['collection']['observation']['controller_ownership']['fallback_controller_active'] = True
        yield 'refuse_step_'+str(case), 'ss_recovery_r10aa_partial_step_control_v1_json', q, None
    for case in range(6):
        q = copy.deepcopy(fixtures[0]['request'])
        if case == 0: q['schema_version'] = 'sporespore_r10q_upright_entry_control_request_v1'
        elif case == 1: q['collection']['observation']['state']['base_pose_world']['position_m']['y'] += .001
        elif case == 2: q['collection']['observation_source_binding']['source_route_id'] = 'unregistered'
        elif case == 3: q['entry']['original_request']['passive_request']['observation']['energy_balance']['initial_mechanical_energy_j'] += 1
        elif case == 4: q['collection']['task_id'] = 'sporespore_measured_partial_fall_to_standing_v1'
        else: q['entry']['prior']['schema_version'] = 'crossed'
        yield 'refuse_entry_'+str(case), 'ss_recovery_r10aa_partial_entry_control_v1_json', q, None


def run():
    assert not RECORD.exists(), 'R10AG_INTERFACE_COMPONENT_ALREADY_RETAINED'
    runtime, fixture_binding, fixtures = inputs()
    out = EVIDENCE/('r10ag-native-interface-'+uuid.uuid4().hex)
    out.mkdir()
    print('R10AG_INTERFACE_ROOT '+out.as_posix(), flush=True)
    before = entry._source_snapshot()
    closure.write_new(out/'source_before.json', before)
    closure.write_new(out/'declaration.json', dict(runtime=runtime, compiled_fixtures=fixture_binding,
        expected_successes=5, expected_refusals=17, world_build_count=0, solver_step_count=0,
        coverage='Exact original compiled V23 fixtures through the existing selected DLL; crossed source, ownership, clock, schema, energy and morphology controls. Detection-frame Godot route integration remains pending.'))
    core = RecordedCore(runtime['path'])
    passed = refused = 0
    with (out/'native_calls.jsonl').open('x', encoding='utf-8', newline='\n') as trace:
        for identity, method, request, expected in cases(fixtures):
            result = failure = None
            try:
                result = core._call_json_input(method, request)
            except LocomotionCoreError as error:
                failure = error.failure_code
            trace.write(json.dumps(dict(id=identity, method=method, request=request,
                response_raw_utf8=core.raw_response.decode('utf-8'), result=result, failure_code=failure), separators=(',', ':'), allow_nan=False)+'\n')
            trace.flush()
            if expected is None:
                assert result is None and failure, identity
                refused += 1
            else:
                assert failure is None and result == expected, (identity, failure)
                passed += 1
    after = entry._source_snapshot()
    closure.write_new(out/'source_after.json', after)
    assert before == after
    observed = dict(ok=True, fixture_successes=passed, crossed_input_refusals=refused,
        source_unchanged=True, runtime_unchanged=True, core_rebuild_required=False,
        detection_frame_route_integrated=False, qualification_satisfied=False,
        world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)
    assert passed == 5 and refused == 17
    closure.write_new(out/'result.json', observed)
    record = dict(schema_version='sporespore_r10ag_native_interface_component_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt_c_abi',
            authority_mode='zero_world_selected_native_interfaces', question_class='development'),
        dependencies=[closure.bind(p) for p in (Path(__file__), DESIGN, FIXTURE_BINDING, Path(fixture_binding['path']),
            Path(runtime['path']), ROOT/'sdk/conformance/development_recovery_refusal.py', ROOT/'sdk/python/sporespore_locomotion.py')],
        evidence_root=out.as_posix(), retained_evidence=[closure.bind(p) for p in sorted(out.iterdir())], observed=observed,
        next_action='Integrate a distinct R10AG candidate, worker, report and pre-world safety graph selecting these V23 APIs with the unchanged detection-frame source. No native launch authority is granted by this component.')
    closure.write_new(RECORD, record)
    return observed


def audit():
    record = closure.read(RECORD)
    for item in record['dependencies']+record['retained_evidence']:
        assert closure.bind(item['path']) == item, item['path']
    _, _, fixtures = inputs()
    out = Path(record['evidence_root'])
    rows = [json.loads(line) for line in (out/'native_calls.jsonl').read_text().splitlines()]
    expected_cases = list(cases(fixtures))
    assert len(rows) == len(expected_cases) == 22
    for row, (identity, method, request, expected) in zip(rows, expected_cases):
        assert (row['id'], row['method'], row['request']) == (identity, method, request)
        raw = json.loads(row['response_raw_utf8'])
        if expected is None:
            assert row['failure_code'] and row['result'] is None and raw
        else:
            assert row['failure_code'] is None and row['result'] == expected
    assert closure.read(out/'source_before.json') == closure.read(out/'source_after.json')
    assert record['observed'] == closure.read(out/'result.json')
    assert record['observed']['fixture_successes'] == 5 and record['observed']['crossed_input_refusals'] == 17
    return record['observed']


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run', action='store_true')
    print(json.dumps(run() if parser.parse_args().run else audit(), indent=2))
