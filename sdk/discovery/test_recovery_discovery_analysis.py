"""Geometric controls for post-exposure contact summaries. No native worlds."""
import copy
import unittest
import recovery_discovery_analysis as A


class ContactControls(unittest.TestCase):
    def fixture(self):
        point = dict(body1_instance_id=1, body2_instance_id=10,
                     normal1_world_unit=[0, 1, 0], impulse1_world_ns=[0, .1, 0],
                     point1_body_local_m=[0, -.1, 0])
        return dict(disturbance=dict(baseline=dict(bodies=[dict(instance_id=1, body_id='front_left_distal'),
                                                         dict(instance_id=2, body_id='torso')])),
                    contact_sites_by_body={'front_left_distal': dict(local_center_m=dict(y=-.08))},
                    tail_rows=[dict(local_step=1, contacts=dict(points=[point]))])

    def test_cap_geometry_and_load(self):
        value = self.fixture()
        self.assertEqual(1, A.contact_metrics(value)['terminal_bearing_feet'])
        value['tail_rows'][0]['contacts']['points'][0]['point1_body_local_m'][1] = -.05
        result = A.contact_metrics(value)
        self.assertEqual((0, 1), (result['terminal_bearing_feet'], result['nonfoot_contact_samples']))

    def test_small_load_is_contact_without_bearing(self):
        value = self.fixture()
        value['tail_rows'][0]['contacts']['points'][0]['impulse1_world_ns'] = [0, .001, 0]
        result = A.contact_metrics(value)
        self.assertEqual((0, 0), (result['terminal_bearing_feet'], result['nonfoot_contact_samples']))

    def test_body_contact_excluded(self):
        value = self.fixture()
        body = copy.deepcopy(value['tail_rows'][0]['contacts']['points'][0])
        body['body2_instance_id'] = 2
        value['tail_rows'][0]['contacts']['points'].append(body)
        result = A.contact_metrics(value)
        self.assertEqual((1, 0), (result['terminal_bearing_feet'], result['nonfoot_contact_samples']))

    def test_second_unknown_instance_refused(self):
        value = self.fixture()
        unknown = copy.deepcopy(value['tail_rows'][0]['contacts']['points'][0])
        unknown['body2_instance_id'] = 11
        value['tail_rows'][0]['contacts']['points'].append(unknown)
        with self.assertRaisesRegex(ValueError, 'ANALYSIS_ONE_FLOOR'):
            A.contact_metrics(value)


if __name__ == '__main__':
    unittest.main()
