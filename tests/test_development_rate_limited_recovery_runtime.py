"""Bound compiled fixtures -> actual DLL -> Godot native motor readback."""
import copy
import json
from pathlib import Path
import sys
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
sys.path.insert(0, str(ROOT / 'sdk/python'))
import development_passive_entry_profile as entry
from sporespore_locomotion import LocomotionCore
import test_development_rearward_fold_runtime as prior_runtime


class RateLimitedRuntime(unittest.TestCase):
    # Reuse the bounded process runner, but never inherit/rerun the old suite.
    _run_godot = prior_runtime.RearwardFoldRuntime._run_godot

    @classmethod
    def setUpClass(cls):
        cls.binding = entry.read(ROOT / 'sdk/development_rate_limited_recovery_runtime_binding_v1.json')
        for source in cls.binding['source_files']:
            if entry.runtime.file_identity(ROOT / source['path'], display_path=source['path']) != source:
                raise AssertionError(('V8_SOURCE_DRIFT', source['path']))
        for path in (ROOT / cls.binding['local_build_path'], Path(cls.binding['runtime']['path'])):
            identity = entry.runtime.file_identity(path)
            for key in ('byte_length', 'raw_sha256'):
                if identity[key] != cls.binding['runtime'][key]:
                    raise AssertionError(('V8_RUNTIME_DRIFT', key))
        fixture = cls.binding['compiled_fixtures']
        if entry.runtime.file_identity(Path(fixture['path'])) != fixture:
            raise AssertionError('V8_FIXTURE_DRIFT')
        prefix = 'RATE_LIMITED_RECOVERY_CONTROL_FIXTURE '
        cls.fixtures = [entry.packet.parse_json(line[len(prefix):]) for line in Path(fixture['path']).read_text().splitlines() if line.startswith(prefix)]
        if len(cls.fixtures) != 6:
            raise AssertionError('V8_FIXTURE_POPULATION')
        cls.root = entry.EVIDENCE / ('development-rate-limited-runtime-test-' + uuid.uuid4().hex)
        cls.root.mkdir()
        cls.core = LocomotionCore(ROOT / cls.binding['local_build_path'])
        cls.results = [cls.core.recovery_plan_control_v1(f['request']) for f in cls.fixtures]
        (cls.root / 'dll_results.json').write_text(json.dumps(cls.results, indent=2) + '\n', encoding='utf-8')
        print('RATE_LIMITED_RECOVERY_RUNTIME_TEST_ROOT', cls.root)

    def test_actual_dll_preserves_three_engine_input_commands_at_both_phase_boundaries(self):
        for fixture, result in zip(self.fixtures, self.results):
            self.assertTrue(entry.packet.same(fixture['expected'], result))
            self.assertEqual([-0.6, 1.05] * 4, [c['target_position_rad'] for c in result['ordered_commands']])
            self.assertEqual([4.0] * 8, [c['maximum_target_speed_rad_s'] for c in result['ordered_commands']])
            self.assertIs(result['physical_acceptance_authority'], False)
        self.assertEqual(1, len({r['command_sha256'] for r in self.results}))

    def test_actual_dll_refuses_crossed_owner_and_unknown_controller(self):
        for owner, controller in [('sporespore_exact_s169_prone_to_standing_controller_v7', 'sporespore_exact_s169_prone_to_standing_controller_v8'), ('unknown', 'unknown')]:
            request = copy.deepcopy(self.fixtures[0]['request'])
            request['controller_id'] = controller
            request['collection']['observation']['controller_ownership']['recovery_controller_id'] = owner
            result = self.core.recovery_plan_control_v1(request)
            self.assertIs(result['no_actuation_requested'], True)
            self.assertEqual([], result['ordered_commands'])

    def test_actual_godot_planner_native_readback_and_old_controller_compatibility(self):
        self._run_godot('res://tests/test_development_rate_limited_recovery_native.gd',
            'DEVELOPMENT_RATE_LIMITED_RECOVERY_NATIVE ', 'native', 28, False)

    def test_actual_worker_reaches_and_applies_rate_limited_support(self):
        result = self._run_godot('res://tests/test_development_rate_limited_recovery_worker_hooks.gd',
            'DEVELOPMENT_PASSIVE_ENTRY_WORKER_HOOKS ', 'worker', None, False)
        for key in ('actual_worker_emits_four_rad_s_ceiling', 'actual_worker_applies_first_v8_support_command',
                    'actual_worker_retains_completed_active_support_step',
                    'publication_keeps_both_controllers_and_exact_consumption_context'):
            self.assertIs(result['checks'][key], True)

    def test_v6_worker_compatibility_on_the_new_runtime(self):
        self._run_godot('res://tests/test_development_rate_limited_recovery_worker_hooks.gd',
            'DEVELOPMENT_PASSIVE_ENTRY_WORKER_HOOKS ', 'v6_worker', 28, False,
            extra_args=('v6_compatibility',))

    def test_v7_worker_compatibility_on_the_new_runtime(self):
        self._run_godot('res://tests/test_development_rate_limited_recovery_worker_hooks.gd',
            'DEVELOPMENT_PASSIVE_ENTRY_WORKER_HOOKS ', 'v7_worker', 28, False,
            extra_args=('v7_compatibility',))

    def test_unbound_worker_refuses_before_runtime_or_world(self):
        result = self._run_godot('res://sdk/adapters/godot/gdscript/development_rate_limited_recovery_smoke_worker_v1.gd',
            'SPORESPORE_DEVELOPMENT_RECOVERY_SMOKE_RAW ', 'unbound_worker', None, False, expected_exit=1)
        self.assertEqual('QSDK_R10F_CAMPAIGN_BINDING_INVALID', result['failure_code'])
        self.assertEqual('sporespore_development_rate_limited_recovery_smoke_child_v1', result['schema_version'])
        self.assertNotIn('passive_entry', result)


if __name__ == '__main__':
    unittest.main()
