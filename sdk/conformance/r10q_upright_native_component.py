"""Cold-check the R10Q DLL and replay exposed entry inputs without physics.

Run under the operation lock. Original R10P reports remain negative and intact;
the two admitted upright states have no physical successor continuation here.
"""
import copy
import json
from pathlib import Path

import development_recovery_refusal as native
import r10p_entry_domain_diagnosis as prior
import r10q_entry_successor_design as design
from sporespore_locomotion import LocomotionCoreError

ROOT = prior.ROOT
BINDING = 'sdk/development/recovery_candidates/r10q-upright-recovery-core-v1.runtime.json'
BINDING_SHA = 'sha256:398aa8478cfccb4ae6964393d3db1e08750f86caadf5d1cf8dcf545a14adc5ff'
RECORD = 'sdk/recovery/r10q_upright_native_component_v1.json'


def require(value, code):
    if not value:
        raise ValueError('R10Q_NATIVE_' + code)


def run(stream):
    design.audit()
    raw = (ROOT / BINDING).read_bytes()
    require(prior.digest(raw) == BINDING_SHA, 'RUNTIME_BINDING')
    runtime = json.loads(raw)
    require(runtime['core_test_count'] == 406 and len(runtime['source_files']) == 99, 'BUILD_POPULATION')
    for item in runtime['source_files']:
        require(prior.binding(ROOT / item['path'])['raw_sha256'] == item['raw_sha256'], 'COMPILED_SOURCE:' + item['path'])
    for item in (runtime['runtime'], runtime['compiled_fixtures']):
        require(prior.binding(Path(item['path'])) == item, 'RETAINED_BUILD_BYTES')
    core = native.RecordedCore(runtime['runtime']['path'])
    fixtures = [json.loads(line.split(' ', 1)[1])
                for line in Path(runtime['compiled_fixtures']['path']).read_text(encoding='utf-8').splitlines()
                if line.startswith('R10Q_UPRIGHT_FIXTURE ')]
    require([f['id'] for f in fixtures] == ['upright_timeout', 'first_upright_control', 'complete_upright_standing'], 'FIXTURE_POPULATION')
    calls = 0

    def call(identity, method, request):
        nonlocal calls
        error = None
        try:
            result = getattr(core, method)(request)
        except LocomotionCoreError as refused:
            result, error = None, refused.failure_code
        response = core.raw_response
        row = dict(identity=identity, method=method, request_raw_utf8=core._input_bytes(request).decode('utf-8'),
                   response_raw_utf8=response.decode('utf-8'), failure_code=error)
        stream.write((json.dumps(row, separators=(',', ':'), allow_nan=False) + '\n').encode())
        stream.flush()
        calls += 1
        return result, error

    for fixture in fixtures:
        require(fixture['physical_source'] is False, 'SYNTHETIC_FIXTURE_LABEL')
        result, error = call('fixture:' + fixture['id'], fixture['method'], fixture['request'])
        require(error is None and result == fixture['expected'], 'DLL_FIXTURE_REPRODUCTION:' + fixture['id'])
    controls = []
    for case in ('entry_schema', 'counter_overflow', 'source_crossed', 'step_task', 'energy_reset', 'phase_skip'):
        fixture = fixtures[0 if case in ('entry_schema', 'counter_overflow', 'source_crossed') else 1]
        request = copy.deepcopy(fixture['request'])
        if case == 'entry_schema': request['schema_version'] = 'unregistered'
        elif case == 'counter_overflow': request['entry']['prior']['consecutive_upright_samples'] = 13
        elif case == 'source_crossed': request['collection']['observation']['state']['base_pose_world']['position_m']['y'] += 0.001
        elif case == 'step_task': request['step']['observation']['task_id'] = 'sporespore_measured_partial_fall_to_standing_v1'
        elif case == 'energy_reset': request['step']['observation']['energy_balance']['cumulative_signed_external_work_j'] = 0.0
        else: request['step']['memory']['phase'] = 'stance_dwell'
        result, error = call('negative_control:' + case, fixture['method'], request)
        require(result is None and error is not None, 'CONTROL_ACCEPTED:' + case)
        controls.append(dict(case=case, refused=True, failure_code=error))

    closure_raw = (ROOT / prior.CLOSURE).read_bytes()
    require(prior.digest(closure_raw) == prior.CLOSURE_SHA, 'ORIGINAL_CLOSURE')
    closure = json.loads(closure_raw)
    claim_path = Path(closure['evidence_root']) / 'campaign_claim.json'
    require(prior.binding(claim_path)['raw_sha256'] == closure['independent_audit']['campaign_claim_sha256'], 'ORIGINAL_CLAIM')
    children = {c['cell_id']: c for c in json.loads(claim_path.read_text(encoding='utf-8'))['children']}
    cells = [c for c in closure['independent_audit']['cells'] if c['role'] == prior.KICK and c['outcome'] == 'negative']
    require([c['seed'] for c in cells] == [50645, 50646], 'EXPOSED_POPULATION')
    replayed = []
    for cell in cells:
        report, report_binding = prior.read_report(cell, children[cell['cell_id']])
        packets = report['passive_entry']['entry_packets']
        require(len(packets) == 240, 'EXPOSED_ENTRY_POPULATION')
        memory = None
        for index, packet in enumerate(packets, 1):
            original = json.loads(packet['call']['request']['utf8_text'])
            request = dict(schema_version='sporespore_r10q_upright_entry_control_request_v1',
                entry=dict(schema_version='sporespore_r10q_upright_entry_request_v1',
                           original_request=original['entry'], prior=memory), collection=original['collection'])
            result, error = call(cell['cell_id'] + ':' + str(index), 'recovery_r10q_upright_entry_control_v1', request)
            require(error is None, 'EXPOSED_NATIVE_REFUSAL:' + cell['cell_id'] + ':' + str(index) + ':' + str(error))
            require(result['original_control'] == packet['native_receipt'], 'ORIGINAL_API_RESULT_CHANGED:' + cell['cell_id'] + ':' + str(index))
            require(result['entry']['original_entry'] == result['original_control']['entry'], 'ORIGINAL_RECEIPT_CROSSED')
            memory = result['entry']['memory']
            require(memory['route'] == ('upright' if index == 240 else 'waiting'), 'EXPOSED_BRANCH_OR_CLOCK')
            require(result['world_build_count'] == result['solver_step_count'] == 0
                    and result['physical_acceptance_authority'] is False and result['release_authority'] is False, 'PHYSICAL_SIDE_EFFECT')
        control = result['initial_upright_control']
        require(control is not None and control['controller_id'] == 'sporespore_exact_s169_prone_to_standing_controller_v20'
                and len(control['ordered_commands']) == 8 and result['original_control']['initial_partial_control'] is None, 'REPAIR_PLAN')
        replayed.append(dict(cell_id=cell['cell_id'], report=report_binding, native_entry_calls=240,
            original_control_results_unchanged=True, original_entry_kind='timeout', successor_entry_kind='upright',
            final_consecutive_upright_samples=memory['consecutive_upright_samples'], initial_control=control,
            original_outcome='negative', successor_physics_steps=0, successor_standing_observed=False))
    require(calls == 489, 'TOTAL_CALL_POPULATION')
    require(prior.binding(Path(runtime['runtime']['path'])) == runtime['runtime'], 'RUNTIME_CHANGED_DURING_CHECK')
    sources = [dict(path=p, raw_sha256=prior.binding(ROOT / p)['raw_sha256']) for p in
               ('sdk/conformance/r10q_upright_native_component.py', 'sdk/python/sporespore_locomotion.py')]
    return dict(schema_version='sporespore_r10q_upright_native_component_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='core_godot', authority_mode='native_component_and_retained_input_diagnosis', question_class='development'),
        implementation_scope='native_upright_task_and_C_Python_Godot_exports_only',
        design=dict(path=design.PATH, raw_sha256=design.DESIGN_SHA),
        runtime_binding=dict(path=BINDING, raw_sha256=BINDING_SHA), runtime=runtime['runtime'],
        compiled_source_count=99, core_test_count=406, cold_fixture_count=3, negative_controls=controls,
        exposed_entry_replays=replayed, native_call_count=calls, source_bindings=sources,
        production_orchestrator_integrated=False, ramp_to_hold_handoff_implemented=False,
        full_360_phase_startup_sweep_complete=False, complete_smoke_safety_gate_passed=False,
        original_results_regraded=False, successor_physics_observed=False,
        world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)
