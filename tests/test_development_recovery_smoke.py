"""Complete applicable native gate plus the new diagnostic schedule boundaries."""
import json
import os
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import qsdk_r10f_l14_runtime_binding as runtime
import qsdk_r10f_zero_world_implementation as implementation

MARKER = 'DEVELOPMENT_SMOKE_ZERO_WORLD '


def native(script, *, timeout=150):
    environment = {key: value for key, value in os.environ.items()
                   if not key.startswith('SPORESPORE_GODOT_RECOVERY_')}
    return subprocess.run([runtime.IMAGES['godot_engine']['path'], '--headless', '--path', str(ROOT),
                           '--script', 'res://' + script], cwd=ROOT, capture_output=True,
                          timeout=timeout, creationflags=subprocess.CREATE_NO_WINDOW, env=environment)


class DevelopmentSmoke(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        runtime.bind_runtime(Path(runtime.IMAGES['godot_console']['path']))
        run = native('tests/test_development_recovery_smoke_zero_world.gd')
        # Preserve original native stdout in the enclosing gate's byte-copied log.
        sys.stdout.buffer.write(run.stdout)
        sys.stdout.buffer.flush()
        lines = [line[len(MARKER):] for line in run.stdout.decode('utf-8').splitlines()
                 if line.startswith(MARKER)]
        if run.returncode or b'ERROR:' in run.stdout + run.stderr or len(lines) != 1:
            raise AssertionError(f'SMOKE_NATIVE_GATE:{run.returncode}:{run.stderr!r}:{run.stdout[-2000:]!r}')
        cls.result = json.loads(lines[0])

    def test_complete_original_native_gate_and_context(self):
        self.assertIs(self.result['ok'], True)
        self.assertIsNotNone(implementation.validate_godot_receipt(self.result['native'], require_l15_context=True))

    def test_all_new_diagnostic_controls(self):
        self.assertEqual(16, len(self.result['checks']))
        self.assertTrue(all(value is True for value in self.result['checks'].values()), self.result['checks'])
        for key in ('model_construction_count', 'world_build_count', 'solver_step_count'):
            self.assertIs(type(self.result[key]), int)
            self.assertEqual(0, self.result[key])

    def test_actual_worker_refuses_unbound_launch_without_world(self):
        run = native('sdk/adapters/godot/gdscript/development_recovery_smoke_worker_v1.gd', timeout=20)
        prefix = 'SPORESPORE_DEVELOPMENT_RECOVERY_SMOKE_RAW '
        rows = [json.loads(line[len(prefix):]) for line in run.stdout.decode('utf-8').splitlines()
                if line.startswith(prefix)]
        self.assertEqual(1, run.returncode, run.stderr)
        self.assertEqual(1, len(rows), run.stdout[-2000:])
        self.assertEqual('sporespore_sdk1_development_recovery_smoke_child_v1', rows[0]['schema_version'])
        self.assertEqual('QSDK_R10F_CAMPAIGN_BINDING_INVALID', rows[0]['failure_code'])
        self.assertEqual(0, rows[0]['world_build_count'])
        self.assertEqual(0, rows[0]['solver_step_count'])


if __name__ == '__main__':
    unittest.main()
