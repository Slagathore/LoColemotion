"""Native configured-value parity and refusal controls; no world construction."""
import copy
import json
from pathlib import Path
import sys
from types import SimpleNamespace
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'sdk/conformance'))
import contact_frame_replay_v2 as successor
import r10ac_contact_frame_replay as predecessor
import development_passive_entry_profile as entry
import test_r10ae_complete_report as native_helper


class ConfiguredVectorV2(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.out = ROOT.parent/'SporeSpore_Evidence'/('contact-frame-configured-vector-v2-'+uuid.uuid4().hex)
        cls.out.mkdir(); print('CONFIGURED_VECTOR_V2_ROOT '+str(cls.out), flush=True)
        cls.before = entry._source_snapshot()
        (cls.out/'source-before.json').write_text(json.dumps(cls.before, indent=2), encoding='utf-8')
        result = native_helper.R10AECompleteReport.native(SimpleNamespace(out=cls.out), 'native',
            'res://tests/test_contact_frame_configured_vector_v2.gd', [cls.out/'fixtures.json'], timeout=60)
        if result.returncode or result.stderr:
            raise AssertionError(result.stdout.decode(errors='replace')[-2000:]+result.stderr.decode(errors='replace'))
        cls.fixture = json.loads((cls.out/'fixtures.json').read_text(encoding='utf-8'))
        assert cls.fixture['ok'] is True
        assert cls.fixture['world_build_count'] == cls.fixture['solver_step_count'] == 0

    @classmethod
    def tearDownClass(cls):
        after = entry._source_snapshot()
        (cls.out/'source-after.json').write_text(json.dumps(after, indent=2), encoding='utf-8')
        assert after == cls.before

    def test_native_parity_on_unrounded_authored_centers(self):
        self.assertEqual(4, len(self.fixture['cases']))
        for case in self.fixture['cases']:
            packet = case['packet']
            with self.subTest(center=case['authored_center']):
                actual = successor.replay(packet,7,packet['model_instance_id'],packet['body_population_instance_sha256'])
                self.assertEqual(case['replay'], actual)
                with self.assertRaisesRegex(ValueError, 'exact float32 vector'):
                    predecessor.replay(packet,7,packet['model_instance_id'],packet['body_population_instance_sha256'])

    def test_invalid_configured_values_refuse(self):
        for value in ([0,0,0], {}, {'x':0,'y':0}, {'x':0,'y':True,'z':0},
                {'x':0,'y':'0','z':0}, {'x':0,'y':float('nan'),'z':0},
                {'x':0,'y':float('inf'),'z':0}, {'x':0,'y':1e100,'z':0}):
            with self.subTest(value=value), self.assertRaises(ValueError):
                successor.configured_vec(value)

    def test_measured_vectors_still_require_exact_float32(self):
        with self.assertRaisesRegex(ValueError, 'exact float32 vector'):
            successor.vec([0,-0.08365750000000001,0])
        packet = copy.deepcopy(self.fixture['cases'][0]['packet'])
        packet['callback_bodies'][0]['pose']['origin'][1] = -0.08365750000000001
        with self.assertRaisesRegex(ValueError, 'exact float32 vector'):
            successor.replay(packet,7,packet['model_instance_id'],packet['body_population_instance_sha256'])

    def test_old_capture_controls_preserved(self):
        path = ROOT.parent/'SporeSpore_Evidence/r10ac-capture-check-6025ba78de6f44de9b2e8218b3caacce/fixtures.json'
        import hashlib
        self.assertEqual('3888a35569cc2fac500f83c48d2893ef428540c19d8e9a839e2ca107361946e3',hashlib.sha256(path.read_bytes()).hexdigest())
        data = json.loads(path.read_text(encoding='utf-8'))
        for row in data['fixtures']:
            p = row['packet']
            self.assertEqual(row['replay'],successor.replay(p,7,p['model_instance_id'],p['body_population_instance_sha256']))
        for index,p in enumerate(data['negative_packets']):
            with self.subTest(index=index),self.assertRaises((ValueError,KeyError,TypeError)):
                successor.replay(p,7,'r10ac-synthetic-no-world','sha256:'+'a'*64)


if __name__ == '__main__':
    unittest.main()
