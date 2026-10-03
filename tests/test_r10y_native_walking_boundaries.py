"""Actual Godot deadline and reader boundaries on declared synthetic inputs."""
import copy
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
from development_passive_entry_profile import _source_snapshot
from development_recovery_refusal import RecordedCore
from sporespore_locomotion import LocomotionCoreError
import test_development_v55_walking_adapter as prior
import test_development_r10k_worker_component as worker
from test_development_v32_recontact_component import NativeApi


class R10YNativeWalkingBoundaries(unittest.TestCase):
    def test_actual_deadlines_refusal_retention_and_crossed_readers(self):
        evidence = ROOT.parent / 'SporeSpore_Evidence'
        out = Path(os.environ.get('SPORE_R10Y_BOUNDARY_ROOT', str(evidence / ('r10y-native-walking-boundaries-' + uuid.uuid4().hex))))
        out.mkdir(exist_ok=False)
        print('R10Y_NATIVE_WALKING_BOUNDARIES_EVIDENCE', out.as_posix(), flush=True)
        before = _source_snapshot()
        worker.write(out / 'source_before.json', before)
        component_path = ROOT / 'sdk/recovery/v56_extended_preparation_component_v1.json'
        component = json.loads(component_path.read_bytes())
        fixture_path = evidence / 'development-v50-mujoco-closed-loop-bd3a5a83e888432d8b3b50c9a1f46af4/calls/0001.request.json'
        inputs = dict(boundaries=component['observed']['boundary_cases'],
            walking_fixture=json.loads(fixture_path.read_bytes()),
            source_files=[dict(path=p.as_posix(), raw_sha256='sha256:' + hashlib.sha256(p.read_bytes()).hexdigest())
                for p in [component_path, fixture_path]])
        self.assertEqual(15, len(inputs['boundaries']))
        worker.write(out / 'input.json', inputs)
        command = [str(worker.GODOT), '--headless', '--path', str(ROOT), '--script',
            'res://tests/test_r10y_native_walking_boundaries.gd', '--', str(out / 'input.json'), str(out / 'result.json')]
        worker.write(out / 'invocation.json', dict(command=command, world_build_count=0, solver_step_count=0))
        started = time.monotonic()
        try:
            with (out / 'stdout.log').open('xb') as stdout, (out / 'stderr.log').open('xb') as stderr:
                process = subprocess.run(command, cwd=ROOT, stdout=stdout, stderr=stderr,
                    timeout=120, creationflags=subprocess.CREATE_NO_WINDOW)
            worker.write(out / 'execution.json', dict(exit_code=process.returncode,
                seconds=round(time.monotonic() - started, 3), world_build_count=0, solver_step_count=0))
        except subprocess.TimeoutExpired:
            worker.write(out / 'execution.json', dict(command=command, timed_out=True, direct_process_killed_and_reaped=True))
            raise
        finally:
            after = _source_snapshot()
            worker.write(out / 'source_after.json', after)
        self.assertEqual(before, after)
        error = (out / 'stderr.log').read_text(encoding='utf-8')
        self.assertEqual(0, process.returncode, error)
        self.assertNotIn('ERROR:', error)
        result = json.loads((out / 'result.json').read_bytes())
        self.assertTrue(result['ok'], [k for k, v in result['checks'].items() if not v])
        self.assertEqual(15, len(result['boundaries']))
        self.assertEqual((0, 0), (result['world_build_count'], result['solver_step_count']))
        runtime = json.loads((ROOT / 'sdk/development/recovery_candidates/r10y-partial-direct-neutral-core-v1.runtime.json').read_bytes())['runtime']
        self.assertEqual(runtime['raw_sha256'], 'sha256:' + hashlib.sha256(Path(runtime['path']).read_bytes()).hexdigest())
        api = NativeApi(runtime['path'])
        session_core = RecordedCore(runtime['path'])
        rows = []
        for fixture, retained in zip(inputs['boundaries'], result['boundaries']):
            self.assertEqual(fixture['case'], retained['case'])
            request = json.loads(retained['request_raw'])
            request.update(schema_version='sporespore_balanced_wave_policy_step_request_v3',
                descriptor=retained['descriptor'], policy_id='sporespore_balanced_wave_recovery_extended_preparation_v1')
            # Prove that fresh host/floor provenance is the only packet change.
            projected = copy.deepcopy(request)
            original = fixture['request']
            for key in ('source_instance_id', 'geometry_source_sha256'):
                projected['floor_reference'][key] = original['floor_reference'][key]
            for key in ('state', 'measured_body_frame'):
                if key in original:
                    projected[key]['adapter_capability_sha256'] = original[key]['adapter_capability_sha256']
            if 'floor_reference_sha256' in original['memory']:
                projected['memory']['floor_reference_sha256'] = original['memory']['floor_reference_sha256']
            self.assertEqual(prior.integers(original), prior.integers(projected))
            raw_request = json.dumps(prior.integers(request), separators=(',', ':'), allow_nan=False).encode()
            status, raw = api.raw('ss_balanced_wave_policy_step_json', raw_request)
            expected = json.loads(fixture['raw_response_utf8'])
            method = 'ss_balanced_wave_policy_step_json'
            if not expected['ok']:
                # Malformed requests name their receiving API in the error
                # detail. Preserve the stateless refusal and cold-replay the
                # same session API used by Godot for exact envelope equality.
                (out / (retained['case'] + '.stateless-response.json')).write_bytes(raw)
                self.assertEqual(expected['failure_code'], json.loads(raw)['failure_code'])
                session_request = prior.integers(json.loads(retained['request_raw']))
                raw_request = session_core._input_bytes(session_request)
                method = 'ss_balanced_wave_policy_session_step_json'
                with session_core.create_balanced_wave_policy_session(request['policy_id'], request['descriptor']) as session:
                    try:
                        session.step_with_measured_body(session_request)
                        self.fail('Malformed request unexpectedly succeeded')
                    except LocomotionCoreError as failure:
                        status = failure.status
                        self.assertEqual(expected['failure_code'], failure.failure_code)
                    raw = session_core.raw_response
            (out / (retained['case'] + '.cold-request.json')).write_bytes(raw_request)
            (out / (retained['case'] + '.cold-response.json')).write_bytes(raw)
            response = retained['response']
            if response['ok']:
                expected_sha = response['native_step_transport_verification']['raw_native_response_sha256']
            else:
                expected_sha = response['development_native_step_failure']['response']['raw_sha256']
            actual_sha = 'sha256:' + hashlib.sha256(raw).hexdigest()
            self.assertEqual(expected_sha, actual_sha)
            actual = json.loads(raw)
            self.assertEqual(expected['ok'], actual['ok'])
            if expected['ok']:
                self.assertEqual(expected['value']['actuation']['ordered_commands'], actual['value']['actuation']['ordered_commands'])
                self.assertEqual(expected['value']['actuation']['safe_no_actuation'], actual['value']['actuation']['safe_no_actuation'])
                self.assertEqual(expected['value']['actuation']['receipt'].get('controller_error'), actual['value']['actuation']['receipt'].get('controller_error'))
                self.assertEqual(0, status)
            else:
                self.assertEqual(expected['failure_code'], actual['failure_code'])
            rows.append(dict(case=retained['case'], method=method, native_status=status, response_byte_exact=True,
                expected_response_sha256=expected_sha, actual_response_sha256=actual_sha))
        unchanged = before == _source_snapshot()
        worker.write(out / 'cold-replay.json', dict(rows=rows, source_unchanged=unchanged,
            world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False))
        self.assertTrue(unchanged)


if __name__ == '__main__':
    unittest.main()
