"""Native Godot V51 adapter registration, bounded to exposed input computations."""
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


class V51WalkingAdapter(unittest.TestCase):
    def test_actual_v51_and_v50_sessions_and_refusals(self):
        out = Path(os.environ.get('SPORE_V51_ADAPTER_ROOT', str(EVIDENCE / ('development-v51-walking-adapter-' + uuid.uuid4().hex))))
        out.mkdir(exist_ok=False)
        print('V51_WALKING_ADAPTER_EVIDENCE ' + str(out), flush=True)
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
        write(out / 'input.json', dict(fixtures=inputs, exposed_sources=sources))
        command = [str(GODOT), '--headless', '--path', str(ROOT), '--script',
            'res://tests/test_development_v51_walking_adapter.gd', '--', str(out / 'input.json'), str(out / 'result.json')]
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
        self.assertEqual(before, after, 'V51_ADAPTER_SOURCE_DRIFT')
        error = (out / 'stderr.log').read_text(encoding='utf-8')
        self.assertEqual(0, process.returncode, error)
        self.assertNotIn('ERROR:', error)
        result = json.loads((out / 'result.json').read_bytes())
        self.assertTrue(result['ok'], result['checks'])
        self.assertEqual(45, len(result['checks']))
        for label in ['v51', 'v50']:
            self.assertEqual(3, len(result['results'][label]['steps']))
            self.assertEqual(3, len(result['results'][label]['refusals']))
        self.assertEqual((0, 0), (result['world_build_count'], result['solver_step_count']))
        # The Godot process has exited. Recompute its six outputs independently
        # through the stateless C ABI and compare the original native byte hashes.
        component = json.loads((ROOT / 'sdk/recovery/r10k_partial_fall_component_implementation_v1.json').read_bytes())
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
        unchanged = before == _source_snapshot()
        write(out / 'cold-replay.json', dict(rows=replays, source_unchanged=unchanged,
            world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False))
        self.assertTrue(unchanged)
        self.assertTrue(all(row['native_status'] == 0 and row['response_byte_exact'] for row in replays), replays)



if __name__ == '__main__':
    unittest.main()
