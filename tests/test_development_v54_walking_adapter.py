"""Native Godot V54 adapter registration, bounded to exposed input computations."""
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
EVIDENCE = ROOT.parent / 'SporeSpore_Evidence'
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
from development_passive_entry_profile import _source_snapshot
from test_development_r10k_worker_component import GODOT, write
from test_development_v32_recontact_component import NativeApi
from development_recovery_refusal import integers


class V54WalkingAdapter(unittest.TestCase):
    def test_actual_v54_and_v50_sessions_and_refusals(self):
        out = Path(os.environ.get('SPORE_V54_ADAPTER_ROOT', str(EVIDENCE / ('development-v54-walking-adapter-' + uuid.uuid4().hex))))
        out.mkdir(exist_ok=False)
        print('V54_WALKING_ADAPTER_EVIDENCE ' + str(out), flush=True)
        before = _source_snapshot()
        write(out / 'source_before.json', before)
        inputs = []
        sources = []
        base = EVIDENCE / 'development-v50-mujoco-closed-loop-bd3a5a83e888432d8b3b50c9a1f46af4/calls'
        for index in range(1, 4):
            path = base / f'{index:04d}.request.json'
            raw = path.read_bytes()
            inputs.append(json.loads(raw))
            sources.append(dict(path=path.as_posix(), byte_length=len(raw), raw_sha256='sha256:' + hashlib.sha256(raw).hexdigest()))
        component = json.loads((ROOT / 'sdk/recovery/v54_zero_velocity_brake_component_v1.json').read_bytes())
        component_root = Path(component['execution']['path']).parent / 'v54'
        braking = []
        for name in ['matched_no_kick_continuation-startup-1.json', 'matched_no_kick_continuation-stop-1.json', 'matched_no_kick_continuation-stop-120.json', 'kick_passive_recovery_resume-startup-1.json'] + [f'kick_passive_recovery_resume-stop-{n}.json' for n in (1,94,97,120)]:
            path = component_root / name
            raw = path.read_bytes()
            original = json.loads(raw)
            braking.append(dict(label=name.removesuffix('.json'), request=original['request'],
                expected_commands=json.loads(original['raw_response_utf8'])['value']['actuation']['ordered_commands'],
                expected_response_sha256=original['raw_response_sha256']))
            sources.append(dict(path=path.as_posix(), byte_length=len(raw), raw_sha256='sha256:' + hashlib.sha256(raw).hexdigest()))
        write(out / 'input.json', dict(fixtures=inputs, braking_fixtures=braking, exposed_sources=sources))
        command = [str(GODOT), '--headless', '--path', str(ROOT), '--script',
            'res://tests/test_development_v54_walking_adapter.gd', '--', str(out / 'input.json'), str(out / 'result.json')]
        started = time.monotonic()
        try:
            with (out / 'stdout.log').open('xb') as stdout, (out / 'stderr.log').open('xb') as stderr:
                process = subprocess.run(command, cwd=ROOT, stdout=stdout, stderr=stderr,
                    timeout=120, creationflags=subprocess.CREATE_NO_WINDOW)
            write(out / 'execution.json', dict(command=command, exit_code=process.returncode,
                seconds=round(time.monotonic() - started, 3), world_build_count=0, solver_step_count=0))
        except subprocess.TimeoutExpired:
            write(out / 'execution.json', dict(command=command, timed_out=True, direct_process_killed_and_reaped=True))
            raise
        finally:
            after = _source_snapshot()
            write(out / 'source_after.json', after)
            write(out / 'source-stability.json', dict(source_unchanged=before == after))
        self.assertEqual(before, after, 'V54_ADAPTER_SOURCE_DRIFT')
        error = (out / 'stderr.log').read_text(encoding='utf-8')
        self.assertEqual(0, process.returncode, error)
        self.assertNotIn('ERROR:', error)
        result = json.loads((out / 'result.json').read_bytes())
        self.assertTrue(result['ok'], result['checks'])
        self.assertEqual(206, len(result['checks']))
        for label in ['v54', 'v53', 'v52', 'v51', 'v50']:
            self.assertEqual(3, len(result['results'][label]['steps']))
            self.assertEqual(3, len(result['results'][label]['refusals']))
        self.assertEqual((0, 0), (result['world_build_count'], result['solver_step_count']))
        # The Godot process has exited. Recompute all twenty-three outputs independently
        # through the stateless C ABI and compare the original native byte hashes.
        component = json.loads((ROOT / 'sdk/recovery/v54_zero_velocity_brake_component_v1.json').read_bytes())
        runtime = component['runtime']
        dll = Path(runtime['path'])
        self.assertEqual(runtime['raw_sha256'], 'sha256:' + hashlib.sha256(dll.read_bytes()).hexdigest())
        native = NativeApi(dll)
        replays = []
        for label, retained in result['results'].items():
            for index, step in enumerate(retained['steps'], 1):
                request = json.loads(step['request_raw'])
                request.update(schema_version='sporespore_balanced_wave_policy_step_request_v3',
                    descriptor=retained['descriptor'], policy_id=retained['start']['controller_policy_id'])
                request = integers(request)
                raw_request = json.dumps(request, separators=(',', ':'), allow_nan=False).encode()
                status, response = native.raw('ss_balanced_wave_policy_step_json', raw_request)
                (out / f'{label}-{index}.cold-request.json').write_bytes(raw_request)
                (out / f'{label}-{index}.cold-response.json').write_bytes(response)
                actual = 'sha256:' + hashlib.sha256(response).hexdigest()
                expected = step['response']['native_step_transport_verification']['raw_native_response_sha256']
                replays.append(dict(policy=label, step=index, native_status=status,
                    expected_response_sha256=expected, actual_response_sha256=actual, response_byte_exact=actual == expected))
        self.assertEqual(8, len(result['braking_results']))
        for index, step in enumerate(result['braking_results'], 1):
            request = json.loads(step['request_raw'])
            request.update(schema_version='sporespore_balanced_wave_policy_step_request_v3',
                descriptor=step['descriptor'], policy_id=result['results']['v54']['start']['controller_policy_id'])
            raw_request = json.dumps(integers(request), separators=(',', ':'), allow_nan=False).encode()
            status, response = native.raw('ss_balanced_wave_policy_step_json', raw_request)
            (out / f'braking-{index}.cold-request.json').write_bytes(raw_request)
            (out / f'braking-{index}.cold-response.json').write_bytes(response)
            actual = 'sha256:' + hashlib.sha256(response).hexdigest()
            expected = step['response']['native_step_transport_verification']['raw_native_response_sha256']
            fixture = braking[index-1]
            self.assertEqual(fixture['expected_commands'], json.loads(response)['value']['actuation']['ordered_commands'])
            # Fresh host/floor identities are the only copied-request changes.
            import copy
            projected = copy.deepcopy(request)
            original = fixture['request']
            for key in ('source_instance_id', 'geometry_source_sha256'):
                projected['floor_reference'][key] = original['floor_reference'][key]
            for key in ('state', 'measured_body_frame'):
                projected[key]['adapter_capability_sha256'] = original[key]['adapter_capability_sha256']
            if 'floor_reference_sha256' in original['memory']:
                projected['memory']['floor_reference_sha256'] = original['memory']['floor_reference_sha256']
            self.assertEqual(integers(original), integers(projected))
            guard = json.loads(response)['value']['actuation']['receipt']['recovery_support_plane']['anchored_body_pose']['zero_amplitude_motor_brake']
            self.assertTrue(all(c['held_target_velocity_rad_s'] == 0 for c in guard['ordered_commands']))
            self.assertFalse(guard['zero_applied_impulse_claim'])
            replays.append(dict(policy='braking', step=index, native_status=status,
                expected_response_sha256=expected, actual_response_sha256=actual, response_byte_exact=actual == expected))
        unchanged = before == _source_snapshot()
        write(out / 'cold-replay.json', dict(rows=replays, source_unchanged=unchanged,
            world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False))
        self.assertTrue(unchanged)
        self.assertTrue(all(row['native_status'] == 0 and row['response_byte_exact'] for row in replays), replays)



if __name__ == '__main__':
    unittest.main()
