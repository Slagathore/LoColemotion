"""Cold V12 geometry and V13 fixture bindings; no engine or native read."""
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import development_recovery_candidate as candidate
import development_recovery_leg_geometry as geometry


class SupportWaypointEntry(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.record = candidate.read(ROOT / 'sdk/development/recovery_attempts/00690ff0730f43aebb53bd35b6b87c81.json')
        report_path = Path(cls.record['kicked_report']['path'])
        if candidate.sha(report_path) != cls.record['kicked_report']['raw_sha256']:
            raise AssertionError('V13_RETAINED_ENTRY_REPORT_DRIFT')
        report = candidate.read(report_path)
        packet = next(p for p in report['passive_entry']['canonical_packets'] if p['global_semantic_step'] == 410)
        request = json.loads(packet['collection_transport']['request']['utf8_text'])
        cls.observation = request['observation']
        cls.descriptor = request['descriptor']
        cls.trace = report['retained_arm']['trace_rows'][409]
        cls.positions = [j['position_rad'] for j in cls.observation['state']['ordered_joint_observations']]
        binding = candidate.read(ROOT / 'sdk/development/recovery_candidates/v13-support-waypoint-rise-v1.runtime.json')
        fixture_path = Path(binding['compiled_fixtures']['path'])
        if candidate.sha(fixture_path) != binding['compiled_fixtures']['raw_sha256']:
            raise AssertionError('V13_ENTRY_FIXTURE_DRIFT')
        cls.fixtures = [json.loads(line.partition(' ')[2]) for line in fixture_path.read_text().splitlines()
                        if line.startswith('CANDIDATE_RECOVERY_CONTROL_FIXTURE ')]
        cls.fixtures = [f for f in cls.fixtures if f['request']['collection']['phase'] == 'raise_body']

    def test_three_adapter_shaped_inputs_bind_actual_v12_lift_entry(self):
        self.assertEqual(3, len(self.fixtures))
        for fixture in self.fixtures:
            request = fixture['request']
            self.assertEqual(0, request['phase_step'])
            self.assertEqual(self.positions, [j['position_rad'] for j in request['collection']['observation']['state']['ordered_joint_observations']])
            self.assertTrue(fixture['synthetic_native_shaped_observations_only'])
            self.assertEqual(0, fixture['world_build_count'])

    def test_new_first_reference_targets_existing_waypoint_not_straight_legs(self):
        waypoint = [-.6, 1.05] * 4
        blend = (1 / 180) ** 2 * (3 - 2 / 180)
        vectors = []
        for fixture in self.fixtures:
            dt = fixture['request']['collection']['observation']['outer_step_duration_s']
            commands = fixture['expected']['ordered_commands']
            for command, measured, target in zip(commands, self.positions, waypoint):
                self.assertAlmostEqual(measured + (target - measured) * blend, command['target_position_rad'], places=11)
                self.assertEqual(4.0, command['maximum_target_speed_rad_s'])
            vectors.append([(c['target_position_rad'] - q) / dt for c, q in zip(commands, self.positions)])
            self.assertFalse(fixture['expected']['physical_acceptance_authority'])
        self.assertEqual(vectors[0], vectors[1])
        self.assertEqual(vectors[0], vectors[2])
        print('V13_SYNTHETIC_ENTRY_COMMAND_SPEEDS', json.dumps(dict(
            source_report=self.record['kicked_report'], source_step=410,
            calculated_v13_first_raise_speeds=vectors[0], waypoint_rad=waypoint,
            preparation_reference_steps=180, straightening_reference_steps=180,
            waypoint_attainment_guaranteed=False, world_build_count=0, solver_step_count=0)))

    def test_cold_entry_geometry_distinguishes_foot_centers_from_body_origins(self):
        descriptor = self.descriptor
        upper = .35 * descriptor['upper_length_fraction']
        distal = .35 - upper
        pose = self.observation['state']['base_pose_world']
        base = [pose['position_m'][k] for k in 'xyz']
        com = [self.observation['center_of_mass']['position_world_m'][k] for k in 'xyz']
        axis = geometry.rotate(pose['orientation_xyzw'], [1, 0, 0])
        horizontal_length = math.hypot(axis[0], axis[2])
        feet = []
        for i, limb in enumerate(geometry.LIMBS):
            hip, knee = self.positions[2*i:2*i+2]
            hip_x = (.2 if i < 2 else -.2) * descriptor['hip_span_scale']
            hip_z = (-.18 if i % 2 == 0 else .18) * descriptor['hip_span_scale']
            def world(length):
                x, y = geometry.endpoint(hip, knee, upper, length)
                return [a+b for a, b in zip(base, geometry.rotate(pose['orientation_xyzw'], [hip_x+x, y, hip_z]))]
            center = world(distal)
            origin = world(distal/2)
            recorded = self.trace['foot_position_world_m_by_limb'][limb]
            offset = ((center[0]-com[0])*axis[0] + (center[2]-com[2])*axis[2]) / horizontal_length
            waypoint_x = hip_x + geometry.endpoint(-.6, 1.05, upper, distal)[0]
            self.assertLess(offset, 0)  # This retained entry, not a support gate.
            self.assertNotEqual(center, origin)
            self.assertTrue(math.isfinite(math.dist(recorded, origin)))
            self.assertEqual(i < 2, waypoint_x > 0)
            feet.append(dict(limb=limb, ideal_contact_center_world_m=center,
                ideal_center_offset_from_measured_com_along_horizontal_body_x_m=offset,
                recorded_distal_body_origin_world_m=recorded,
                ideal_body_origin_residual_m=math.dist(recorded, origin),
                ideal_waypoint_contact_center_x_relative_to_torso_origin_m=waypoint_x))
        self.assertTrue(self.trace['torso_contact'])
        self.assertTrue(self.observation['center_of_mass']['source_measurement'])
        sources = []
        for path in ['sdk/core/src/quadruped.rs', 'sdk/core/src/recovery_morphology.rs',
                     'tests/test_sdk_qsdk_r10f_continuous_passive_recovery_worker.gd']:
            raw = subprocess.check_output(['git', 'show', self.record['source_snapshot']['head'] + ':' + path], cwd=ROOT)
            sources.append(dict(path=path, source_commit=self.record['source_snapshot']['head'], raw_sha256='sha256:' + hashlib.sha256(raw).hexdigest()))
        print('V13_RETAINED_SUPPORT_GEOMETRY', json.dumps(dict(
            source_report=self.record['kicked_report'], source_step=410, sources=sources,
            geometry_helper_sha256=candidate.sha(Path(geometry.__file__)),
            measured_com_world_m=com, torso_contact=True, feet=feet,
            limitation='Ideal hinges omit native anchor separation and out-of-plane errors. Calculated contact centers and a level hypothetical waypoint are not measured clearance, pressure locations, support feasibility, or causal proof.',
            new_physical_observation=False, causal_attribution_proven=False,
            world_build_count=0, native_read_count=0, solver_step_count=0)))


if __name__ == '__main__':
    unittest.main()
