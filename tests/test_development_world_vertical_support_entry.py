"""Bind V22's synthetic command checks to V21's immutable native poses."""
import hashlib
import json
from pathlib import Path
import unittest

import test_development_passive_entry_replay as shared
from development_recovery_candidate_test_support import candidate, ROOT
import development_recovery_leg_geometry as geometry


class WorldVerticalSupportEntry(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.selection = candidate.selection(candidate.reference_for_path(
            ROOT / 'sdk/development/recovery_candidates/v22-world-vertical-support-v1.json'))
        cls.record = candidate.read(ROOT / 'sdk/development/recovery_attempts/0b50a7ac1bc34180ac714bf950d2510b.json')
        source = cls.record['kicked_report']
        if candidate.sha(Path(source['path'])) != source['raw_sha256']:
            raise AssertionError('V22_SOURCE_REPORT_DRIFT')
        cls.report = candidate.read(Path(source['path']))
        cls.retained = candidate.read(ROOT / 'sdk/core/contracts/recovery_v22_retained_support_fixture_v1.json')
        cls.binding = candidate.read(candidate.resource_path(cls.selection['candidate']['runtime_binding']))
        compiled = cls.binding['compiled_fixtures']
        if candidate.sha(Path(compiled['path'])) != compiled['raw_sha256']:
            raise AssertionError('V22_COMPILED_FIXTURE_DRIFT')
        cls.fixtures = [json.loads(line.partition(' ')[2])
            for line in Path(compiled['path']).read_text().splitlines()
            if line.startswith('CANDIDATE_RECOVERY_CONTROL_FIXTURE ')]
        cls.fixtures = [f for f in cls.fixtures
            if f['request']['collection']['phase'] == 'establish_distal_support']
        cls.core = shared.LocomotionCore(ROOT / cls.binding['local_build_path'])

    def test_four_pose_samples_are_exact_original_native_observations(self):
        source = self.retained
        self.assertEqual(self.record['kicked_report']['raw_sha256'], source['source_report_sha256'])
        self.assertEqual(self.record['source_snapshot']['head'], source['source_commit'])
        self.assertEqual('0b50a7ac1bc34180ac714bf950d2510b', source['source_attempt'])
        self.assertEqual([402, 410, 430, 450], [s['global_step'] for s in source['samples']])
        packets = {p['global_semantic_step']: p for p in self.report['passive_entry']['canonical_packets']}
        for sample in source['samples']:
            request = json.loads(packets[sample['global_step']]['collection_transport']['request']['utf8_text'])
            self.assertEqual(request['descriptor'], source['descriptor'])
            self.assertEqual(request['observation']['state'], sample['state'])
        self.assertIs(source['physical_acceptance_authority'], False)
        self.assertIs(source['release_authority'], False)

    def test_three_compiled_adapter_shaped_inputs_bind_the_retained_entry(self):
        self.assertEqual(3, len(self.fixtures))
        for fixture in self.fixtures:
            request = fixture['request']
            self.assertEqual(0, request['phase_step'])
            self.assertEqual(self.core.canonicalize_json(self.retained['descriptor']),
                             self.core.canonicalize_json(request['collection']['descriptor']))
            for key in ('base_pose_world', 'ordered_joint_observations'):
                # Native and host JSON can differ by a binary64 ULP. Use the
                # production canonical identity, not a new physical tolerance.
                self.assertEqual(self.core.canonicalize_json(self.retained['samples'][0]['state'][key]),
                    self.core.canonicalize_json(request['collection']['observation']['state'][key]))
            self.assertIs(fixture['synthetic_native_shaped_observations_only'], True)
            self.assertIs(fixture['retained_pose_values_injected'], True)
            self.assertEqual(0, fixture['world_build_count'])
            self.assertEqual(0, fixture['solver_step_count'])

    def test_actual_dll_first_command_reduces_ideal_world_height_spread(self):
        vectors = []
        for fixture in self.fixtures:
            request = fixture['request']
            actual = self.core.recovery_plan_control_v1(request)
            self.assertTrue(shared.entry.packet.same(actual, fixture['expected']))
            observation = request['collection']['observation']
            descriptor = request['collection']['descriptor']
            pose = observation['state']['base_pose_world']
            before = [j['position_rad'] for j in observation['state']['ordered_joint_observations']]
            commands = actual['ordered_commands']
            after = [c['target_position_rad'] for c in commands]
            upper = .35 * descriptor['upper_length_fraction']
            distal = .35 - upper
            def heights(positions):
                result = []
                for leg in range(4):
                    hip, knee = positions[2*leg:2*leg+2]
                    x, y = geometry.endpoint(hip, knee, upper, distal)
                    hip_x = (.2 if leg < 2 else -.2) * descriptor['hip_span_scale']
                    hip_z = (-.18 if leg % 2 == 0 else .18) * descriptor['hip_span_scale']
                    result.append(pose['position_m']['y'] +
                        geometry.rotate(pose['orientation_xyzw'], [hip_x+x, y, hip_z])[1])
                return result
            old_y, new_y = heights(before), heights(after)
            self.assertLess(max(new_y)-min(new_y), max(old_y)-min(old_y))
            self.assertAlmostEqual(new_y[0], old_y[0], places=11)
            self.assertLess(new_y[2], old_y[2])
            self.assertLess(new_y[3], old_y[3])
            dt = observation['outer_step_duration_s']
            for i, command in enumerate(commands):
                self.assertEqual(4.0, command['maximum_target_speed_rad_s'])
                self.assertLessEqual(abs(after[i]-before[i]), 4*dt + 1e-11)
                if i % 2 == 0:
                    self.assertAlmostEqual(before[i], after[i], places=11)
            self.assertIs(actual['physical_acceptance_authority'], False)
            self.assertIs(actual['release_authority'], False)
            vectors.append(after)
        self.assertEqual(vectors[0], vectors[1])
        self.assertEqual(vectors[0], vectors[2])
        print('V22_RETAINED_ENTRY_IDEAL_GEOMETRY', json.dumps(dict(
            source_report=self.record['kicked_report'], source_step=402,
            before_ideal_foot_center_world_y_m=old_y,
            first_command_ideal_foot_center_world_y_m=new_y,
            first_target_positions_rad=vectors[0],
            limitation='Fixed observed torso pose and ideal hinges only. This is not measured foot motion, native contact, force, stability or a recovery prediction.',
            world_build_count=0, native_read_count=0, solver_step_count=0)))

    def test_new_schedule_preserves_bounds_contacts_and_immutable_results(self):
        schedule = self.selection['diagnostic_schedule']
        previous = candidate.read(ROOT / 'sdk/development/recovery_schedules/v21-native-walking-support-v1.json')['schedules']['v21-native-walking-support-v1']
        for key in ('limits', 'walking_resume_frame_id', 'walking_entry_profile_id', 'walking_contact_profile_id'):
            self.assertEqual(previous[key], schedule[key])
        self.assertTrue(schedule['coverage_basis']['new_controller_preserves_existing_limits_and_later_phase_commands'])
        self.assertNotIn('new_controller_preserves_v14_recovery_motion', schedule['coverage_basis'])
        self.assertEqual(schedule['coverage_basis']['support_fixture_sha256'],
                         candidate.sha(ROOT / schedule['coverage_basis']['support_fixture']))
        for path, digest in (
            ('sdk/development/recovery_attempts/0b50a7ac1bc34180ac714bf950d2510b.json', '7152e0361c3130a376f2013b6bbd98073c398655c1a2b3a9a8678b6054b53e8d'),
            ('sdk/development/recovery_candidates/v21-native-walking-support-v1.json', '21744b075f068c3db4137ed47345eb39e27ca4a7c07ba3620517f7e57ab8362f'),
            ('sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json', 'c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f')):
            self.assertEqual('sha256:' + digest, candidate.sha(ROOT / path))
        for attempt, failed_stage, counts in (
            ('e71531726e074783ba6fdb1e0c857852', 'candidate_walking_frame', (81, 77, 4)),
            ('7932dc6bcc944333b7f0ec4352f772fd', 'candidate_walking_contacts', (87, 87, 0))):
            self.check_stopped_attempt(attempt, failed_stage, counts)

    def check_stopped_attempt(self, attempt, failed_stage, counts):
        stopped = candidate.read(ROOT / 'sdk/development/recovery_attempts' / (attempt + '.json'))
        supervisor = candidate.read(Path(stopped['evidence_root']) / 'supervisor_result.json')
        self.assertEqual('SMOKE_SAFETY_GATE_FAILED:' + failed_stage, supervisor['failure_code'])
        self.assertFalse(supervisor['ok'])
        self.assertFalse(supervisor['physical_attempt_started'])
        self.assertEqual([], supervisor['children'])
        self.assertEqual(supervisor['source_snapshot'], stopped['source_snapshot'])
        self.assertEqual(counts, tuple(stopped[k] for k in
            ('completed_test_count', 'passed_stage_test_count', 'failed_stage_test_count')))
        for population in (stopped['retained_population'], stopped['failed_stage_source_population']):
            root = Path(population['root'])
            files = [dict(path=p.relative_to(root).as_posix(), byte_length=p.stat().st_size,
                raw_sha256=candidate.sha(p)) for p in sorted(root.rglob('*')) if p.is_file()]
            self.assertEqual(population['files'], files)
            self.assertEqual(population['file_count'], len(files))
            self.assertEqual(population['byte_length'], sum(f['byte_length'] for f in files))
            self.assertEqual(population['inventory_sha256'], 'sha256:' + hashlib.sha256(
                json.dumps(files, sort_keys=True, separators=(',', ':')).encode()).hexdigest())
        for key in ('complete_route_proven', 'successful_recovery_proven', 'physical_acceptance_authority',
                    'release_authority', 'repeat_consumed_attempt_permitted'):
            self.assertIs(stopped[key], False)


if __name__ == '__main__':
    unittest.main()
