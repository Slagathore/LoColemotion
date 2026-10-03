"""Native/source parity and refusal controls for the unlaunched R10AF component."""
import copy
import json
from pathlib import Path
import sys
from types import SimpleNamespace
import unittest
import uuid

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'sdk/conformance'))
import detection_frame_contact_source_v1 as reader
import development_passive_entry_profile as entry
import test_r10ae_complete_report as native_helper


class DetectionFrameContacts(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.out=ROOT.parent/'SporeSpore_Evidence'/('r10af-contact-reader-component-'+uuid.uuid4().hex)
        cls.out.mkdir();print('R10AF_CONTACT_READER_ROOT '+str(cls.out),flush=True)
        cls.before=entry._source_snapshot()
        (cls.out/'source-before.json').write_text(json.dumps(cls.before,indent=2),encoding='utf-8')
        result=native_helper.R10AECompleteReport.native(SimpleNamespace(out=cls.out),'native',
            'res://tests/test_r10af_detection_frame_contacts.gd',[cls.out/'fixtures.json'],timeout=60)
        assert result.returncode == 0 and not result.stderr, result.stderr.decode(errors='replace')
        cls.fixture=json.loads((cls.out/'fixtures.json').read_text(encoding='utf-8'))
        assert cls.fixture['ok'] is True and cls.fixture['negative_refusals'] == 20
        assert cls.fixture['world_build_count'] == cls.fixture['solver_step_count'] == 0

    @classmethod
    def tearDownClass(cls):
        after=entry._source_snapshot()
        (cls.out/'source-after.json').write_text(json.dumps(after,indent=2),encoding='utf-8')
        assert after == cls.before

    def replay(self,case):
        p=case['legacy_packet']
        return reader.replay_source(case['source_receipt'],p['callback_bodies'],p['contact_sites_by_body'])

    def test_native_parity_and_impulse_partition(self):
        results=[]
        self.assertEqual(6,len(self.fixture['positive_cases']))
        for case in self.fixture['positive_cases']:
            actual=self.replay(case);row=actual['comparisons'][0]
            self.assertEqual(case['detection_classified_as_foot'],row['classified_as_foot'])
            self.assertEqual(case['callback_classified_as_foot'],row['callback_classified_as_foot'])
            self.assertEqual(1,actual['matched_loaded_floor_contacts'])
            self.assertEqual(row['normal_impulse_ns'],sum(actual['foot_impulses_by_body'].values())+sum(actual['nonfoot_impulses_by_body'].values()))
            results.append(actual)
        (self.out/'independent-results.json').write_text(json.dumps(results,indent=2),encoding='utf-8')

    def test_empty_population_and_callback_body_binding(self):
        case=copy.deepcopy(self.fixture['positive_cases'][0])
        case['source_receipt']['ordered_contact_samples']=[]
        case['source_receipt']['contact_detection_frame']['native_snapshot']['points']=[]
        case['source_receipt']['contact_detection_frame']['native_snapshot']['reported_point_count']=0
        case['source_receipt']['solved_contact_telemetry_contract']['exact_contact_point_count']=0
        self.assertEqual(0,self.replay(case)['matched_loaded_floor_contacts'])
        case['legacy_packet']['callback_bodies'][0]['instance_id']=999
        with self.assertRaises(ValueError):self.replay(case)

    def test_frame_and_contact_mutations_refuse(self):
        base=self.fixture['positive_cases'][0]
        mutations=[]
        for field,value in [('schema_version','old'),('profile_id','unknown'),('native_space_step_sequence',8)]:
            bad=copy.deepcopy(base);bad['source_receipt']['contact_detection_frame'][field]=value;mutations.append(bad)
        for field,value in [('classified_as_foot',False),('native_point_index',1),('native_side','2'),('normal_impulse_ns',1.0)]:
            bad=copy.deepcopy(base);bad['source_receipt']['ordered_contact_samples'][0][field]=value;mutations.append(bad)
        for field in ['position_body_local_m','classification_position_body_local_m','detection_position_body_local_m']:
            bad=copy.deepcopy(base);bad['source_receipt']['ordered_contact_samples'][0][field]['y']=-0.2;mutations.append(bad)
        bad=copy.deepcopy(base);bad['source_receipt']['ordered_contact_samples']*=2;mutations.append(bad)
        bad=copy.deepcopy(base);bad['source_receipt']['ordered_contact_samples']=[];mutations.append(bad)
        bad=copy.deepcopy(base);bad['source_receipt']['contact_detection_frame']['native_snapshot']['read_space_step_sequence']=8;mutations.append(bad)
        for index,case in enumerate(mutations):
            with self.subTest(index=index),self.assertRaises((ValueError,KeyError,TypeError)):
                self.replay(case)

    def test_legacy_retention_native_controls(self):
        result=native_helper.R10AECompleteReport.native(SimpleNamespace(out=self.out),'legacy-retention',
            'res://tests/test_sdk_qsdk_r24d75_godot_contact_source_retention_zero_world.gd',[],timeout=60)
        self.assertEqual(0,result.returncode,result.stdout.decode(errors='replace')[-2000:]+result.stderr.decode(errors='replace'))
        self.assertEqual(b'',result.stderr)


if __name__ == '__main__':unittest.main()
