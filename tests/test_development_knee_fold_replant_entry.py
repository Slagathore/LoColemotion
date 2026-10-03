"""Bind V14 commands to retained V13 entry; ideal geometry is not physics."""
import json
import math
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import development_recovery_candidate as candidate
import development_recovery_leg_geometry as geometry


class KneeFoldReplantEntry(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.record = candidate.read(ROOT / 'sdk/development/recovery_attempts/6938c042f1a84754b926cb6d46de0e57.json')
        report_path = Path(cls.record['kicked_report']['path'])
        if candidate.sha(report_path) != cls.record['kicked_report']['raw_sha256']:
            raise AssertionError('V14_RETAINED_ENTRY_REPORT_DRIFT')
        report = candidate.read(report_path)
        packet = next(p for p in report['passive_entry']['canonical_packets'] if p['global_semantic_step'] == 410)
        request = json.loads(packet['collection_transport']['request']['utf8_text'])
        cls.observation = request['observation']
        cls.descriptor = request['descriptor']
        cls.positions = [j['position_rad'] for j in cls.observation['state']['ordered_joint_observations']]
        binding = candidate.read(ROOT / 'sdk/development/recovery_candidates/v14-knee-fold-replant-v1.runtime.json')
        fixture_path = Path(binding['compiled_fixtures']['path'])
        if candidate.sha(fixture_path) != binding['compiled_fixtures']['raw_sha256']:
            raise AssertionError('V14_ENTRY_FIXTURE_DRIFT')
        cls.fixtures = [json.loads(line.partition(' ')[2]) for line in fixture_path.read_text().splitlines()
                        if line.startswith('CANDIDATE_RECOVERY_CONTROL_FIXTURE ')]
        cls.fixtures = [f for f in cls.fixtures if f['request']['collection']['phase'] == 'raise_body']

    def test_three_adapter_shaped_inputs_bind_actual_v13_lift_entry(self):
        self.assertEqual(3, len(self.fixtures))
        for fixture in self.fixtures:
            request = fixture['request']
            self.assertEqual(0, request['phase_step'])
            self.assertEqual(self.positions, [j['position_rad'] for j in request['collection']['observation']['state']['ordered_joint_observations']])
            self.assertTrue(fixture['synthetic_native_shaped_observations_only'])
            self.assertEqual(0, fixture['world_build_count'])

    def test_first_commands_fold_negative_without_intended_hip_progress(self):
        blend = (1 / 120) ** 2 * (3 - 2 / 120)
        vectors = []
        for fixture in self.fixtures:
            dt = fixture['request']['collection']['observation']['outer_step_duration_s']
            commands = fixture['expected']['ordered_commands']
            for i, (command, measured) in enumerate(zip(commands, self.positions)):
                target = measured if i % 2 == 0 else measured + (-1.05 - measured) * blend
                self.assertAlmostEqual(target, command['target_position_rad'], places=11)
                if i % 2 == 1:
                    self.assertLess(command['target_position_rad'], measured)
                self.assertEqual(4.0, command['maximum_target_speed_rad_s'])
            vectors.append([(c['target_position_rad'] - q) / dt for c, q in zip(commands, self.positions)])
            self.assertFalse(fixture['expected']['physical_acceptance_authority'])
        self.assertEqual(vectors[0], vectors[1])
        self.assertEqual(vectors[0], vectors[2])
        print('V14_SYNTHETIC_ENTRY_COMMAND_SPEEDS', json.dumps(dict(
            source_report=self.record['kicked_report'], source_step=410,
            calculated_first_raise_speeds=vectors[0], segment_steps=[120, 120, 120],
            waypoint_attainment_guaranteed=False, world_build_count=0, solver_step_count=0)))

    def test_fixed_body_entry_geometry_distinguishes_up_fold_from_down_fold(self):
        upper = .35 * self.descriptor['upper_length_fraction']
        distal = .35 - upper
        pose = self.observation['state']['base_pose_world']
        base = [pose['position_m'][k] for k in 'xyz']
        radius = .04 * self.descriptor['foot_radius_scale']
        results = []
        for i, limb in enumerate(geometry.LIMBS):
            hip, knee = self.positions[2*i:2*i+2]
            hip_x = (.2 if i < 2 else -.2) * self.descriptor['hip_span_scale']
            hip_z = (-.18 if i % 2 == 0 else .18) * self.descriptor['hip_span_scale']
            def center(k, length):
                x, y = geometry.endpoint(hip, k, upper, length)
                return [a+b for a, b in zip(base, geometry.rotate(pose['orientation_xyzw'], [hip_x+x, y, hip_z]))]
            entry = center(knee, distal)
            knee_y = center(knee, 0)[1]
            previous = entry[1]
            # Hold the observed torso transform and hip angle only in this
            # calculation. The native test is free to move and need not track it.
            for step in range(1, 121):
                t = step / 120
                k = knee + (-1.05-knee) * t*t*(3-2*t)
                current = center(k, distal)[1]
                self.assertGreaterEqual(current + 1e-14, previous)
                previous = current
            up = center(-1.05, distal)
            down = center(1.05, distal)
            self.assertGreater(up[1], entry[1])
            self.assertLess(down[1], entry[1])
            self.assertGreaterEqual(min(knee_y, up[1])-radius, min(knee_y, entry[1])-radius)
            self.assertTrue(all(math.isfinite(v) for v in up + down))
            results.append(dict(limb=limb, entry_ideal_contact_center_world_m=entry,
                negative_fold_ideal_contact_center_world_m=up,
                positive_fold_ideal_contact_center_world_m=down,
                entry_ideal_distal_capsule_clearance_m=min(knee_y, entry[1])-radius,
                negative_fold_ideal_distal_capsule_clearance_m=min(knee_y, up[1])-radius))
        print('V14_RETAINED_FOLD_GEOMETRY', json.dumps(dict(
            source_report=self.record['kicked_report'], source_commit=self.record['source_snapshot']['head'],
            source_step=410, geometry_helper_sha256=candidate.sha(Path(geometry.__file__)), limbs=results,
            limitation='Fixed observed torso transform and fixed hip angles; ideal hinges omit anchor separation and out-of-plane error. Initial overlap is not erased. No prediction of actual contacts, unloading, knee support, stable recovery, or causal proof.',
            new_physical_observation=False, world_build_count=0, native_read_count=0, solver_step_count=0)))


if __name__ == '__main__':
    unittest.main()
