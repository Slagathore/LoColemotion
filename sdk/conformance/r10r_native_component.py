"""Exercise the R10R DLL and preserve original Q/V20/V12/V7 responses.

This command performs no physics. Existing report calls go to their original
exports with their original input bytes; they are never relabeled as R10R.
"""
import copy
import json
from pathlib import Path
import uuid

import development_recovery_refusal as native
import development_passive_entry_profile as entry
from r10q_upright_command_diagnosis import ROOT, EVIDENCE, bind, read, write
from sporespore_locomotion import LocomotionCoreError

BINDING = ROOT / 'sdk/development/recovery_candidates/r10r-upright-direct-rise-core-v1.runtime.json'
RECORD = ROOT / 'sdk/recovery/r10r_upright_native_component_v1.json'
Q_BINDING = ROOT / 'sdk/development/recovery_candidates/r10q-upright-recovery-core-v1.runtime.json'
Q_CLOSURE = ROOT / 'sdk/recovery/r10q_phase246_development_pair_closure_v1.json'
COMMAND_COMPONENT = ROOT / 'sdk/recovery/r10q_upright_command_component_v1.json'
ORIGINAL_FIXTURES = EVIDENCE / 'development-candidate-build-bea09596be3f4184bd5df530217c826b/fixtures.stdout.log'


class ExactInputCore(native.RecordedCore):
    @staticmethod
    def _input_bytes(value):
        return value if isinstance(value, bytes) else native.RecordedCore._input_bytes(value)


def fixtures(path, prefix):
    return [json.loads(line.partition(' ')[2]) for line in Path(path).read_text(encoding='utf-8').splitlines()
            if line.startswith(prefix + ' ')]


def run():
    assert not RECORD.exists()
    runtime = read(BINDING)
    assert runtime['core_test_count'] == 410 and len(runtime['source_files']) == 101
    for source in runtime['source_files']:
        assert bind(ROOT / source['path'])['raw_sha256'] == source['raw_sha256']
    for item in [runtime['runtime'], runtime['compiled_fixtures']]: assert bind(item['path']) == item
    root = EVIDENCE / ('r10r-native-component-' + uuid.uuid4().hex)
    root.mkdir()
    print('R10R_NATIVE_COMPONENT_ROOT', root, flush=True)
    before = entry._source_snapshot()
    write(root / 'source_before.json', before)
    source = [bind(Path(__file__)), bind(ROOT / 'sdk/python/sporespore_locomotion.py')]
    declarations = [bind(BINDING), bind(Q_BINDING), bind(Q_CLOSURE), bind(COMMAND_COMPONENT),
                    bind(ROOT / 'sdk/recovery/r10r_upright_direct_rise_design_v1.json')]
    write(root / 'declaration.json', dict(sources=source, declarations=declarations,
        expected_calls=dict(r10r_fixtures=3, negative_controls=10, original_q_fixtures=3,
                            original_v20_v7_fixtures=12, retained_q_entry_and_steps=841, command_study=2322),
        old_calls_use_original_apis=True, physical_world_count=0, solver_step_count=0))
    core = ExactInputCore(runtime['runtime']['path'])
    calls, counts, controls = 0, {}, []
    with (root / 'native_calls.jsonl').open('xb') as stream:
        def call(group, identity, method, request, expected=None, raw_response=None, refuse=False):
            nonlocal calls
            result, error = None, None
            try:
                result = core._call_json_input(method, request)
            except LocomotionCoreError as failure:
                error = failure.failure_code
            raw = core.raw_response
            stream.write((json.dumps(dict(group=group, identity=identity, method=method,
                request_raw_utf8=core._input_bytes(request).decode(), response_raw_utf8=raw.decode(),
                failure_code=error), separators=(',', ':'), allow_nan=False)+'\n').encode())
            stream.flush()
            calls += 1
            counts[group] = counts.get(group, 0) + 1
            if refuse:
                assert error is not None and result is None, identity
                controls.append(dict(case=identity, failure_code=error))
            else:
                assert error is None, (identity, error)
                if expected is not None: assert result == expected, identity
                if raw_response is not None: assert raw == raw_response, identity
            return result
        own = fixtures(runtime['compiled_fixtures']['path'], 'R10R_UPRIGHT_FIXTURE')
        assert [f['id'] for f in own] == ['upright_step_1', 'upright_step_2', 'upright_step_63']
        for f in own:
            call('r10r_fixtures', f['id'], 'ss_'+f['method']+'_json', f['request'], expected=f['expected'])
        for case in range(10):
            q = copy.deepcopy(own[1]['request'])
            if case == 0: q['schema_version'] = 'sporespore_upright_recovery_step_control_request_v1'
            elif case == 1: q['collection']['task_id'] = 'sporespore_measured_partial_fall_to_standing_v1'
            elif case == 2: q['collection']['observation_source_binding']['source_route_id'] = 'unregistered'
            elif case == 3: q['collection']['observation']['controller_ownership']['recovery_controller_id'] = 'sporespore_exact_s169_prone_to_standing_controller_v20'
            elif case == 4: q['step']['observation']['semantic_step'] += 1
            elif case == 5: q['step']['observation']['energy_balance']['cumulative_signed_external_work_j'] = 0
            elif case == 6: q['step']['memory']['phase'] = 'stance_dwell'
            elif case == 7: q['collection']['observation']['state']['ordered_joint_observations'][0]['position_rad'] = None
            elif case == 8: q['collection']['descriptor']['torso_length_scale'] += 0.01
            else: q['collection']['observation_source_binding'] = None
            call('negative_controls', 'control_'+str(case), 'ss_recovery_r10r_upright_step_control_v1_json', q, refuse=True)
        old = read(Q_BINDING)
        assert bind(old['compiled_fixtures']['path']) == old['compiled_fixtures']
        for f in fixtures(old['compiled_fixtures']['path'], 'R10Q_UPRIGHT_FIXTURE'):
            call('original_q_fixtures', f['id'], 'ss_'+f['method']+'_json', f['request'], expected=f['expected'])
        assert bind(ORIGINAL_FIXTURES)['raw_sha256'] == 'sha256:fe93775b4f188f797fac6756d54449bd960ba914feeb26995f82415e8114ffdf'
        for prefix, method in [('CANDIDATE_RECOVERY_CONTROL_FIXTURE', 'ss_recovery_plan_control_v1_json'),
                               ('CANDIDATE_STANCE_CONTROL_FIXTURE', 'ss_recovery_plan_stance_control_v4_json')]:
            for index, f in enumerate(fixtures(ORIGINAL_FIXTURES, prefix)):
                call('original_v20_v7_fixtures', prefix+str(index), method, f['request'], expected=f['expected'])
        closure = read(Q_CLOSURE)
        report_path = Path(closure['evidence_root']) / 'children/kick_passive_recovery_resume/worker_report.json'
        expected_binding = next(b for b in closure['retained_evidence'] if b['path'] == report_path.as_posix())
        assert bind(report_path) == expected_binding
        report = read(report_path)
        packets = report['passive_entry']['entry_packets'] + report['r10q_upright_recovery']['step_packets']
        assert len(packets) == 841
        for index, packet in enumerate(packets):
            original = packet['call']
            raw_request = original['request']['utf8_text'].encode()
            raw_response = original['response']['utf8_text'].encode()
            assert native.digest(raw_request) == original['request']['raw_sha256']
            assert native.digest(raw_response) == original['response']['raw_sha256']
            call('retained_q_entry_and_steps', str(index), 'ss_'+original['method'], raw_request, raw_response=raw_response)
            if index % 120 == 0: print('R10R_Q_REPLAY', index+1, flush=True)
        del report, packets
        component = read(COMMAND_COMPONENT)
        trace_path = Path(component['evidence_root']) / 'native_calls.jsonl'
        expected_binding = next(b for b in component['retained_evidence'] if b['path'] == trace_path.as_posix())
        assert bind(trace_path) == expected_binding
        with trace_path.open(encoding='utf-8') as old_trace:
            for index, line in enumerate(old_trace):
                row = json.loads(line)
                call('command_study', str(index), 'ss_recovery_plan_control_v1_json', row['request'], expected=row['response'])
        assert counts == read(root / 'declaration.json')['expected_calls'] and calls == 3191
    after = entry._source_snapshot()
    write(root / 'source_after.json', after)
    assert before == after and source == [bind(item['path']) for item in source]
    observed = dict(ok=True, native_calls=calls, populations=counts, negative_controls=controls,
        original_q_report_responses_byte_identical=True, original_q_result='negative',
        original_v20_v12_v7_responses_unchanged=True, full_route_integrated=False,
        complete_smoke_safety_gate_passed=False, physical_world_count=0, solver_step_count=0,
        physical_response_predicted=False, physical_acceptance_authority=False, release_authority=False, sdk1_score='14/20')
    write(root / 'result.json', observed)
    write(RECORD, dict(schema_version='sporespore_r10r_upright_native_component_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='core_godot',
            authority_mode='native_component_and_original_input_compatibility', question_class='development'),
        evidence_root=root.as_posix(), runtime_binding=bind(BINDING), source_bindings=source,
        design_binding=declarations[-1], core_tests=410, compiled_sources=101, observed=observed,
        retained_evidence=[bind(p) for p in sorted(root.rglob('*')) if p.is_file()]))
    print('R10R_NATIVE_COMPONENT_COMPLETE', json.dumps(observed), flush=True)


if __name__ == '__main__': run()
