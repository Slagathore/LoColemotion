"""Fresh synthetic R10AP identity, packet and linked report checks; no physics."""
import copy
import json
from pathlib import Path
import sys
from types import SimpleNamespace
import unittest
import uuid

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'sdk/conformance'))
import r10ap_development as identity
import r10af_contact_frame_replay as packet_reader
import r10af_contact_frame_report as report_reader
import development_passive_entry_profile as entry
import test_r10ae_complete_report as native_helper


class R10APContactReport(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.out=identity.EVIDENCE/('r10ap-contact-report-'+uuid.uuid4().hex);cls.out.mkdir()
        print('R10AP_CONTACT_REPORT_ROOT '+str(cls.out),flush=True)
        cls.before=entry._source_snapshot()
        (cls.out/'source-before.json').write_text(json.dumps(cls.before,indent=2),encoding='utf-8')
        attempt,child,nonce=[uuid.uuid4().hex for _ in range(3)]
        cls.declaration=dict(attempt_id=attempt,seed=identity.SEED,development_execution_mode=identity.SINGLE,
            candidate_profile=identity.reference(),source_snapshot=dict(head=cls.before['head'],dirty=False,status=[],changed_file_bindings=[]),
            children=[dict(child_attempt_id=child,termination_nonce=nonce,role=identity.ROLE,
                evidence_path=str(identity.EVIDENCE/('development-recovery-smoke-'+attempt)/'children'/identity.ROLE))],
            r10ap_development=identity.context(identity.SINGLE,cls.before['head'],identity.reference()),
            comparative_authority=False,baseline_reused=False,official_qualification=False,
            physical_acceptance_authority=False,release_authority=False,synthetic_fixture=True)
        identity.validate_declaration(cls.declaration)
        (cls.out/'declaration.json').write_text(json.dumps(cls.declaration),encoding='utf-8')
        result=native_helper.R10AECompleteReport.native(SimpleNamespace(out=cls.out),'native',
            'res://tests/test_r10ap_contact_report_fixture.gd',[cls.out/'declaration.json',cls.out/'fixtures.json'],timeout=60)
        assert result.returncode==0 and not result.stderr,result.stdout.decode(errors='replace')[-2000:]+result.stderr.decode(errors='replace')[-4000:]
        cls.fixture=json.loads((cls.out/'fixtures.json').read_text(encoding='utf-8'))
        assert cls.fixture['ok'] is True

    @classmethod
    def tearDownClass(cls):
        after=entry._source_snapshot();(cls.out/'source-after.json').write_text(json.dumps(after,indent=2),encoding='utf-8')
        assert cls.before==after

    def test_native_packet_parity(self):
        for case in self.fixture['packets']:
            packet=case['packet']
            self.assertEqual(case['replay'],packet_reader.replay(packet,7,packet['model_instance_id'],packet['body_population_instance_sha256']))

    def test_linked_report_and_negative_controls(self):
        self.assertEqual(self.fixture['replay'],report_reader.replay_report(self.fixture['report'],self.declaration,identity))
        for index,report in enumerate(self.fixture['negative_reports']):
            with self.subTest(index=index),self.assertRaises((ValueError,KeyError,TypeError)):
                report_reader.replay_report(report,self.declaration,identity)

    def test_source_rehash_does_not_hide_wrong_classification(self):
        packet=copy.deepcopy(self.fixture['packets'][0]['packet'])
        packet['contact_source_receipt']['ordered_contact_samples'][0]['classified_as_foot']=False
        packet['source_component_binding']['contact_source_sha256']=packet_reader.sha(packet['contact_source_receipt'])
        with self.assertRaisesRegex(ValueError,'classification'):
            packet_reader.replay(packet,7,packet['model_instance_id'],packet['body_population_instance_sha256'])


if __name__=='__main__':unittest.main()
