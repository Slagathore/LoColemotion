"""Actual launcher selection plus negative controls; no physical processes."""
import copy
import json
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch
import uuid

from development_recovery_candidate_test_support import selected, candidate, ROOT
import development_passive_entry_profile as entry
import development_recovery_smoke as reader
import development_step_cost_profile as cost
import test_development_recovery_smoke_reader as header

PWSH = 'C:/Program Files/PowerShell/7/pwsh.exe'


class CandidateProfile(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.selection = selected()
        cls.relative = cls.selection['candidate_profile']['resource'].removeprefix('res://')
        cls.root = entry.EVIDENCE / ('development-candidate-profile-' + uuid.uuid4().hex)
        cls.root.mkdir()
        cls.launches = {}
        for single in (False, True):
            command = (f". ./sdk/run_development_recovery_smoke.ps1 -Library -ProfileSteps -ReuseContextChecks -CandidateProfile '{cls.relative}' "
                       + ('-SingleKick' if single else '')
                       + '; ConvertTo-SporeSporeExactJson -Value ([ordered]@{fields=(Get-DevelopmentCandidateFields);'
                         'worker=$script:WorkerResource;roles=$script:OrderedChildRoles;stages=$stages})')
            run = subprocess.run([PWSH, '-NoProfile', '-NonInteractive', '-Command', command], cwd=ROOT,
                                 capture_output=True, timeout=30, creationflags=subprocess.CREATE_NO_WINDOW)
            (cls.root / f'launcher_{single}.stdout.txt').write_bytes(run.stdout)
            (cls.root / f'launcher_{single}.stderr.txt').write_bytes(run.stderr)
            if run.returncode:
                raise AssertionError((run.returncode, run.stdout, run.stderr))
            cls.launches[single] = entry.packet.parse_json(run.stdout.decode())
        print('CANDIDATE_PROFILE_TEST_ROOT', cls.root, flush=True)

    def declaration(self, single):
        launch = self.launches[single]
        return dict(entry.LIMITS, **launch['fields'], worker_resource=launch['worker'],
                    children=[dict(role=role) for role in launch['roles']],
                    context_cache_profile_id=cost.CACHE_PROFILE_ID, context_cache_call_sites=cost.CACHE_CALL_SITES,
                    step_cost_profile_id=cost.PROFILE_ID, official_qualification=False,
                    physical_acceptance_authority=False, release_authority=False)

    def test_actual_launcher_and_python_share_both_role_modes_and_gate(self):
        for single in (False, True):
            declaration = self.declaration(single)
            self.assertEqual(candidate.limits(self.selection), entry.validate_declaration(declaration))
            self.assertEqual(self.launches[single]['roles'], reader.declared_roles(declaration))
            expected_count = (91 if 'diagnostic_schedule' in self.selection else 87)
            if self.selection.get('diagnostic_schedule', {}).get('walking_resume_frame_id'):
                expected_count += 4
            if self.selection.get('diagnostic_schedule', {}).get('walking_entry_profile_id'):
                expected_count += 6
            if self.selection.get('diagnostic_schedule', {}).get('walking_start_profile_id'):
                expected_count += 4
            if self.selection.get('diagnostic_schedule', {}).get('walking_policy_id'):
                expected_count += 12 # Includes the mandatory three native-failure retention checks.
                selected_policy = self.selection['diagnostic_schedule']['walking_policy_id']
                bounded_support = selected_policy == candidate.read(candidate.SUPPORT_POLICY_PATH)['policy_id']
                floor_support = selected_policy == candidate.read(candidate.FLOOR_POLICY_PATH)['policy_id']
                feasible_support = selected_policy == candidate.read(candidate.FEASIBLE_POLICY_PATH)['policy_id']
                smooth_swing = selected_policy == candidate.read(candidate.SMOOTH_POLICY_PATH)['policy_id']
                reference_velocity = selected_policy == candidate.read(candidate.REFERENCE_POLICY_PATH)['policy_id']
                wave_velocity = selected_policy == candidate.read(candidate.WAVE_POLICY_PATH)['policy_id']
                airborne_reference = selected_policy == candidate.read(candidate.AIRBORNE_POLICY_PATH)['policy_id']
                absent_reference = selected_policy == candidate.read(candidate.ABSENT_POLICY_PATH)['policy_id']
                upright_stance = selected_policy == candidate.read(candidate.UPRIGHT_POLICY_PATH)['policy_id']
                stance_latch = selected_policy == candidate.read(candidate.STANCE_LATCH_POLICY_PATH)['policy_id']
                progression = selected_policy == candidate.read(candidate.PROGRESSION_POLICY_PATH)['policy_id']
                posture = selected_policy == candidate.read(candidate.POSTURE_POLICY_PATH)['policy_id']
                startup_velocity = selected_policy == candidate.read(candidate.STARTUP_VELOCITY_POLICY_PATH)['policy_id']
                hold_route = selected_policy == candidate.HOLD_ROUTE_ID
                flexed_route = selected_policy == candidate.FLEXED_ROUTE_ID
                stance_route = selected_policy == candidate.STANCE_ROUTE_ID
                finite_route = hold_route or flexed_route or stance_route or selected_policy == candidate.FINITE_ROUTE_ID
                remaining = finite_route or startup_velocity or selected_policy == candidate.read(candidate.REMAINING_POLICY_PATH)['policy_id']
                explicit_floor = floor_support or feasible_support or smooth_swing or reference_velocity or wave_velocity or airborne_reference or absent_reference or upright_stance or stance_latch or progression or posture
                variant = 'r10j' if hold_route else 'r10i' if flexed_route else 'r10h' if stance_route else 'r10g' if finite_route else 'v50' if startup_velocity else 'v49' if remaining else 'v44' if posture else 'v43' if progression else 'v42' if stance_latch else 'v41' if upright_stance else 'v40' if absent_reference else 'v39' if airborne_reference else 'v38' if wave_velocity else 'v37' if reference_velocity else 'v36' if smooth_swing else 'v35' if feasible_support else 'v34' if floor_support else 'v33' if bounded_support else 'v32'
                stages = {stage['id']: stage for stage in self.launches[single]['stages']}
                expected_policy_suite = f'test_development_{variant}_floor_adapter.py' if explicit_floor else f'test_development_{variant}_walking_policy.py'
                if hold_route:
                    expected_count += 18
                    for key, pattern, count in [('walking_entry_readiness', 'test_recovery_walking_readiness.py', 7), ('walking_joint_entry_interfaces', 'test_recovery_joint_pose_entry_interfaces.py', 5), ('walking_joint_entry_boundaries', 'test_recovery_joint_pose_entry_boundaries.py', 3), ('walking_hold_entry_boundaries', 'test_recovery_v50_hold_entry_boundaries.py', 3)]:
                        self.assertEqual((pattern, count), (stages[key]['pattern'], stages[key]['tests']))
                elif flexed_route:
                    expected_count += 15
                    for key, pattern, count in [('walking_entry_readiness', 'test_recovery_walking_readiness.py', 7), ('walking_joint_entry_interfaces', 'test_recovery_joint_pose_entry_interfaces.py', 5), ('walking_joint_entry_boundaries', 'test_recovery_joint_pose_entry_boundaries.py', 3)]:
                        self.assertEqual((pattern, count), (stages[key]['pattern'], stages[key]['tests']))
                elif stance_route:
                    expected_count += 12
                    for key, pattern, count in [('walking_entry_readiness', 'test_recovery_walking_readiness.py', 7), ('walking_entry_interfaces', 'test_recovery_stance_entry.py', 5)]:
                        self.assertEqual((pattern, count), (stages[key]['pattern'], stages[key]['tests']))
                else:
                    self.assertNotIn('walking_entry_readiness', stages)
                    self.assertNotIn('walking_entry_interfaces', stages)
                if remaining:
                    expected_count += 24 if finite_route else 3 # Both roles add fourteen checks; fourteen body/start/entry checks replace five adapter plus four start and six entry checks; cycle and legacy add four.
                    for stage_id, pattern, count in (('candidate_measured_body_adapter', f'test_development_{variant}_measured_body_adapter.py', 28 if finite_route else 14), ('candidate_cycle_stop', f'test_development_{variant}_cycle_stop.py', 3), ('candidate_legacy_source', 'test_development_v42_legacy_source.py', 1)):
                        self.assertEqual((pattern, count), (stages[stage_id]['pattern'], stages[stage_id]['tests']))
                    self.assertEqual(f'test_development_{variant}_candidate_schedule.py', stages['candidate_schedule']['pattern'])
                    self.assertNotIn('candidate_walking_start', stages)
                    self.assertNotIn('candidate_walking_entry', stages)
                    if finite_route:
                        self.assertEqual(('test_finite_recovery_walking.py', 7), (stages['finite_recovery_measurements']['pattern'], stages['finite_recovery_measurements']['tests']))
                else:
                    self.assertEqual(expected_policy_suite, stages['candidate_walking_policy']['pattern'])
                    self.assertEqual(6 if explicit_floor and not (stance_latch or progression or posture) else 5, stages['candidate_walking_policy']['tests'])
                self.assertEqual(f'test_development_{variant}_recovery_route.py', stages['candidate_recovery_route']['pattern'])
                self.assertEqual(bounded_support, 'candidate_bounded_support_native' in stages)
                self.assertEqual(floor_support, 'candidate_floor_support_native' in stages)
                self.assertEqual(feasible_support, 'candidate_feasible_support_native' in stages)
                self.assertEqual(smooth_swing, 'candidate_smooth_swing_native' in stages)
                self.assertEqual(reference_velocity, 'candidate_reference_velocity_native' in stages)
                self.assertEqual(wave_velocity, 'candidate_wave_velocity_native' in stages)
                self.assertEqual(airborne_reference, 'candidate_airborne_reference_native' in stages)
                self.assertEqual(absent_reference, 'candidate_absent_contact_reference_native' in stages)
                self.assertEqual(upright_stance, 'candidate_upright_stance_native' in stages)
                self.assertEqual(stance_latch, 'candidate_stance_latch_native' in stages)
                self.assertEqual(stance_latch or progression or posture or remaining, 'candidate_legacy_source' in stages)
                self.assertEqual(progression, 'candidate_support_progression_native' in stages)
                self.assertEqual(progression, 'candidate_support_progression_reader' in stages)
                self.assertEqual(posture, 'candidate_support_hold_posture_native' in stages)
                self.assertEqual(posture, 'candidate_support_hold_posture_reader' in stages)
                self.assertEqual(('test_development_native_step_failure.py', 3),
                                 (stages['candidate_native_step_failure']['pattern'], stages['candidate_native_step_failure']['tests']))
                if posture:
                    expected_count += 7
                    self.assertEqual(('test_development_v42_legacy_source.py', 1),
                                     (stages['candidate_legacy_source']['pattern'], stages['candidate_legacy_source']['tests']))
                    self.assertEqual(('test_development_support_hold_posture_component.py', 5),
                                     (stages['candidate_support_hold_posture_native']['pattern'], stages['candidate_support_hold_posture_native']['tests']))
                    self.assertEqual(('test_development_v44_posture_reader.py', 1),
                                     (stages['candidate_support_hold_posture_reader']['pattern'], stages['candidate_support_hold_posture_reader']['tests']))
                if progression:
                    expected_count += 6
                    self.assertEqual(('test_development_v42_legacy_source.py', 1),
                                     (stages['candidate_legacy_source']['pattern'], stages['candidate_legacy_source']['tests']))
                    self.assertEqual(('test_development_v43_support_progression_component.py', 4),
                                     (stages['candidate_support_progression_native']['pattern'], stages['candidate_support_progression_native']['tests']))
                    self.assertEqual(('test_development_v43_progression_reader.py', 1),
                                     (stages['candidate_support_progression_reader']['pattern'], stages['candidate_support_progression_reader']['tests']))
                if stance_latch:
                    expected_count += 5
                    self.assertEqual(('test_development_v42_legacy_source.py', 1),
                                     (stages['candidate_legacy_source']['pattern'], stages['candidate_legacy_source']['tests']))
                    self.assertEqual(('test_development_v42_stance_latch_component.py', 4),
                                     (stages['candidate_stance_latch_native']['pattern'], stages['candidate_stance_latch_native']['tests']))
                if upright_stance:
                    expected_count += 5
                    self.assertEqual(('test_development_v41_upright_stance_component.py', 4),
                                     (stages['candidate_upright_stance_native']['pattern'], stages['candidate_upright_stance_native']['tests']))
                if absent_reference:
                    expected_count += 5
                    self.assertEqual(('test_development_v40_absent_contact_reference_component.py', 4),
                                     (stages['candidate_absent_contact_reference_native']['pattern'], stages['candidate_absent_contact_reference_native']['tests']))
                if airborne_reference:
                    expected_count += 5
                    self.assertEqual(('test_development_v39_airborne_reference_component.py', 4),
                                     (stages['candidate_airborne_reference_native']['pattern'], stages['candidate_airborne_reference_native']['tests']))
                if wave_velocity:
                    expected_count += 5
                    self.assertEqual(('test_development_v38_wave_velocity_component.py', 4),
                                     (stages['candidate_wave_velocity_native']['pattern'], stages['candidate_wave_velocity_native']['tests']))
                if reference_velocity:
                    expected_count += 5 # Four native checks plus the sixth floor/adapter check.
                    self.assertEqual(('test_development_v37_reference_velocity_component.py', 4),
                                     (stages['candidate_reference_velocity_native']['pattern'], stages['candidate_reference_velocity_native']['tests']))
                if smooth_swing:
                    expected_count += 6 # Five native checks plus the sixth floor/adapter check.
                    self.assertEqual(('test_development_v36_smooth_swing_component.py', 5),
                                     (stages['candidate_smooth_swing_native']['pattern'], stages['candidate_smooth_swing_native']['tests']))
                if feasible_support:
                    expected_count += 5
                    self.assertEqual(('test_development_v35_feasible_support_component.py', 4),
                                     (stages['candidate_feasible_support_native']['pattern'], stages['candidate_feasible_support_native']['tests']))
                if floor_support:
                    expected_count += 5 # Four native checks plus the sixth floor/adapter check.
                    self.assertEqual(('test_development_v34_floor_support_component.py', 4),
                                     (stages['candidate_floor_support_native']['pattern'], stages['candidate_floor_support_native']['tests']))
                if bounded_support:
                    expected_count += 4
                    self.assertEqual(('test_development_v33_bounded_support_component.py', 4),
                                     (stages['candidate_bounded_support_native']['pattern'], stages['candidate_bounded_support_native']['tests']))
            if self.selection.get('diagnostic_schedule', {}).get('walking_replay_profile_id'):
                expected_count += 8
            if self.selection.get('diagnostic_schedule', {}).get('walking_contact_profile_id'):
                expected_count += 4
            native_contact = candidate.read(ROOT / 'sdk/development/recovery_native_walking_contact_contract_v1.json')
            if self.selection.get('diagnostic_schedule', {}).get('walking_contact_profile_id') == native_contact['profile_id']:
                expected_count += 4
            self.assertEqual(expected_count,
                             sum(stage['tests'] for stage in self.launches[single]['stages']))
            for stage in self.launches[single]['stages']:
                if 'candidate_profile' in stage:
                    self.assertEqual(self.relative, stage['candidate_profile'])
            self.assertEqual(self.selection['candidate_profile'], declaration['candidate_profile'])

    def test_missing_baseline_cannot_be_presented_as_a_pair_or_legacy_schedule(self):
        good = self.declaration(True)
        for key, value in [('development_execution_mode', self.selection['paired_mode']),
                           ('comparative_authority', True), ('baseline_reused', True), ('children', [])]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                reader.declared_roles(dict(good, **{key: value}))
        with self.assertRaises(ValueError):
            reader.declared_roles(dict(good, diagnostic_schedule_id=entry.SCHEDULE))

    def test_profile_hash_dll_contract_and_unknown_fields_fail_closed(self):
        reference = self.selection['candidate_profile']
        for changed in ({}, dict(reference, raw_sha256='sha256:' + '0' * 64),
                        dict(reference, resource='res://sdk/development/recovery_candidates/../unknown.json')):
            with self.assertRaises((ValueError, OSError)):
                candidate.selection(changed)
        original_read = candidate.read
        profile_path = candidate.resource_path(reference['resource'])
        mutations = [('post_kick_controller_id', 'unknown'), ('physical_acceptance_authority', True),
                     ('runtime_sha256', 'sha256:' + '0' * 64), ('extension_sha256', 'sha256:' + '0' * 64),
                     ('runtime_binding_sha256', 'sha256:' + '0' * 64)]
        for key, value in mutations:
            changed = dict(self.selection['candidate'], **{key: value})
            with self.subTest(key=key), patch.object(candidate, 'read', side_effect=lambda path: changed if path == profile_path else original_read(path)):
                with self.assertRaises(ValueError):
                    candidate.selection(reference)

    def test_actual_header_binds_profile_and_no_comparison(self):
        report, descriptor, declaration = header.SmokeReader().fixture()
        declaration.update(self.declaration(True))
        report.update(schema_version=self.selection['worker_selection']['report_schema'],
                      work_id=self.selection['worker_selection']['work_id'],
                      maximum_solver_step_count=candidate.limits(self.selection)['maximum_steps_per_child'])
        for key in ('candidate_profile', 'development_execution_mode', 'comparative_authority', 'baseline_reused'):
            report[key] = declaration[key]
        reader.validate_header(report, descriptor, declaration, 123)
        for key in ('candidate_profile', 'development_execution_mode', 'comparative_authority', 'baseline_reused'):
            with self.subTest(key=key), self.assertRaises(ValueError):
                reader.validate_header(dict(report, **{key: None}), descriptor, declaration, 123)

    def test_actual_cli_rejects_unbound_single_mode_and_incompatible_schedules(self):
        for flags, code in [(['-SingleKick'], b'SMOKE_SINGLE_KICK_REQUIRES_CANDIDATE_PROFILE'),
                            (['-CandidateProfile', self.relative], b'SMOKE_CANDIDATE_REQUIRES_CONTEXT_CACHE'),
                            (['-CandidateProfile', self.relative, '-ProfileSteps', '-ReuseContextChecks', '-ObserveRateLimitedRecovery'], b'SMOKE_DIAGNOSTIC_SCHEDULES_EXCLUSIVE')]:
            run = subprocess.run([PWSH, '-NoProfile', '-NonInteractive', '-File', 'sdk/run_development_recovery_smoke.ps1', *flags],
                                 cwd=ROOT, capture_output=True, timeout=20, creationflags=subprocess.CREATE_NO_WINDOW)
            self.assertNotEqual(0, run.returncode)
            self.assertIn(code, run.stderr)


if __name__ == '__main__':
    unittest.main()
