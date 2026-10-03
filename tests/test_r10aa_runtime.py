"""Profile-bound compiled contract and native worker boundary, no new worlds."""
import copy
import json
from pathlib import Path
import subprocess
import unittest
import uuid

import test_development_passive_entry_replay as shared
from development_recovery_candidate_test_support import selected, arguments


class R10AARuntime(unittest.TestCase):
    _run_retained = classmethod(shared.PassiveEntryReplay._run_retained.__func__)

    @classmethod
    def setUpClass(cls):
        cls.selection = selected()
        cls.binding = shared.entry.binding(cls.selection)
        for source in cls.binding['source_files']:
            if shared.entry.runtime.file_identity(shared.ROOT / source['path'], display_path=source['path']) != source:
                raise AssertionError(('CANDIDATE_COMPILED_SOURCE_DRIFT', source['path']))
        if cls.selection['diagnostic_schedule']['walking_policy_id'] != 'r10aa_partial_load_seeking_route_v1':
            raise AssertionError('R10AA_RUNTIME_SELECTION_REQUIRED')
        from r10r_compatibility_fixtures import fixture_binding
        fixture = fixture_binding()
        if shared.entry.runtime.file_identity(Path(fixture['path'])) != fixture:
            raise AssertionError('CANDIDATE_COMPILED_FIXTURE_DRIFT')
        cls.fixtures = []
        cls.stance_fixtures = []
        for line in Path(fixture['path']).read_text().splitlines():
            prefix, _, payload = line.partition(' ')
            if prefix.endswith('_CONTROL_FIXTURE'):
                value = shared.parse_json(payload)
                if value['request']['controller_id'] == cls.selection['post_kick_controller_id']:
                    cls.fixtures.append(value)
                elif prefix == 'CANDIDATE_STANCE_CONTROL_FIXTURE':
                    cls.stance_fixtures.append(value)
        if len(cls.fixtures) != 6:
            raise AssertionError('CANDIDATE_FIXTURE_POPULATION')
        stance_contract = shared.entry.read(shared.ROOT / 'sdk/core/contracts/recovery_candidate_stance_profiles_v1.json')
        stance_contract['profiles'] += shared.entry.read(shared.ROOT / 'sdk/core/contracts/recovery_candidate_stance_profiles_v2.json')['profiles']
        stance_contract['profiles'] += shared.entry.read(shared.ROOT / 'sdk/core/contracts/recovery_candidate_stance_profiles_v3.json')['profiles']
        stance_contract['profiles'] += shared.entry.read(shared.ROOT / 'sdk/core/contracts/recovery_candidate_stance_profiles_v4.json')['profiles']
        stance_contract['profiles'] += shared.entry.read(shared.ROOT / 'sdk/core/contracts/recovery_candidate_stance_profiles_v5.json')['profiles']
        stance_contract['profiles'] += shared.entry.read(shared.ROOT / 'sdk/core/contracts/recovery_candidate_stance_profiles_v6.json')['profiles']
        cls.stance_profile = next((p for p in stance_contract['profiles']
            if p['recovery_controller_id'] == cls.selection['post_kick_controller_id']), None)
        if len(cls.stance_fixtures) != (6 if cls.stance_profile else 0):
            raise AssertionError('CANDIDATE_STANCE_FIXTURE_POPULATION')
        cls.core = shared.LocomotionCore(shared.ROOT / cls.binding['local_build_path'])
        cls.root = shared.entry.EVIDENCE / ('development-r10aa-runtime-' + uuid.uuid4().hex)
        cls.root.mkdir()
        print('CANDIDATE_RUNTIME_TEST_ROOT', cls.root, flush=True)

    def test_compiled_three_engine_two_phase_fixtures_match_actual_dll(self):
        for fixture in self.fixtures:
            actual = self.core.recovery_plan_control_v1(fixture['request'])
            self.assertTrue(shared.entry.packet.same(actual, fixture['expected']))
            self.assertIs(actual['physical_acceptance_authority'], False)
            self.assertEqual(8, len(actual['ordered_commands']))
        for fixture in self.stance_fixtures:
            actual = self.core.recovery_plan_stance_control_v4(fixture['request'])
            self.assertTrue(shared.entry.packet.same(actual, fixture['expected']))
            self.assertEqual(self.stance_profile['controller_id'], actual['control_receipt']['controller_id'])
            self.assertIs(actual['release_authority'], False)
        import r10r_retained_joint_entry as retained
        import json
        check = retained.evaluate(self.selection)
        (self.root / 'retained_joint_entry.json').write_text(json.dumps(check, indent=2) + '\n', encoding='utf-8')
        self.assertEqual(3, len(check['results']))
        self.assertIs(check['original_observation_rewritten'], False)
        self.assertEqual(0, check['solver_step_count'])

    def test_actual_dll_refuses_unknown_or_crossed_controller(self):
        for controller, owner in [('unknown', 'unknown'),
                                  ('sporespore_exact_s169_prone_to_standing_controller_v9999', 'sporespore_exact_s169_prone_to_standing_controller_v9999'),
                                  (self.selection['post_kick_controller_id'], 'sporespore_exact_s169_prone_to_standing_controller_v6')]:
            request = copy.deepcopy(self.fixtures[0]['request'])
            request['controller_id'] = controller
            request['collection']['observation']['controller_ownership']['recovery_controller_id'] = owner
            result = self.core.recovery_plan_control_v1(request)
            self.assertIs(result['no_actuation_requested'], True)
            self.assertEqual([], result['ordered_commands'])
        for fixture in self.stance_fixtures:
            for corruption in ('crossed_id', 'missing_position', 'missing_velocity'):
                request = copy.deepcopy(fixture['request'])
                if corruption == 'crossed_id':
                    request['controller_id'] = 'sporespore_exact_s169_stance_handoff_controller_v1'
                elif corruption == 'missing_position':
                    request['collection']['observation']['state']['ordered_joint_observations'][0]['position_rad'] = None
                else:
                    request['collection']['observation']['state']['ordered_joint_observations'][0]['velocity_rad_s'] = None
                with self.assertRaises(RuntimeError):
                    self.core.recovery_plan_stance_control_v4(request)

    def test_actual_godot_profile_context_and_single_role_contract(self):
        run = self._run_retained('res://tests/test_development_r10r_contract.gd',
                                ['--', *arguments(self.selection)], 'contract', 60)
        result = shared.marker(run, 'DEVELOPMENT_RECOVERY_CANDIDATE_CONTRACT ')
        self.assertIs(result['ok'], True, result)
        self.assertTrue(all(result['checks'].values()), result)

    def test_unbound_worker_and_reader_refuse_without_starting_a_world(self):
        # Startup wall time is distinct from the unchanged no-world refusal.
        from r10aa_development_launch import contract
        deadlines = contract()['native_startup_timeouts_seconds']
        for name, script in [('worker', self.selection['worker_selection']['worker']),
                             ('reader', self.selection['reader'])]:
            timeout = deadlines['candidate_unbound_' + name]
            self.assertIs(type(timeout), int)
            run = self._run_retained(script, [], 'unbound_' + name, timeout)
            self.assertEqual(1, run.returncode, run.stdout + run.stderr)
            self.assertNotIn(b'SPORESPORE_GODOT_RECOVERY_READY ', run.stdout)
            self.assertIn(b'DEVELOPMENT_CANDIDATE_DECLARATION_INVALID' if name == 'worker'
                          else b'CANDIDATE_REPLAY_ARGUMENTS', run.stdout + run.stderr)


if __name__ == '__main__':
    unittest.main()
