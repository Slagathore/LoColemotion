"""Identity and preflight refusal controls; synthetic Git is never launch proof."""
import copy,json,sys,unittest
from pathlib import Path
from unittest.mock import patch
import r10am_preflight_fixture as fixture
ROOT=fixture.ROOT
import r10am_startup_preflight as preflight
import r10am_development as identity
import r10am_physical_identity as physical_identity
import r10ad_startup_transport as transport

class StartupPreflight(unittest.TestCase):
    def setUp(self):
        self.head='a'*40;self.declaration=fixture.fixture(self.head)
    def test_declared_identity_and_crossed_predecessor_refused(self):
        identity.validate_declaration(self.declaration)
        for key,value in [('seed',61248),('release_authority',True),('comparative_authority',0),('baseline_reused',True)]:
            bad=copy.deepcopy(self.declaration);bad[key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):identity.validate_declaration(bad)
        bad=copy.deepcopy(self.declaration);bad['r10ac_development']=bad.pop(identity.CONTEXT_KEY)
        with self.assertRaisesRegex(ValueError,'CROSSED_CAMPAIGN'):identity.validate_declaration(bad)
    def test_exact_freeze_and_dirty_or_crossed_remote_refused(self):
        outputs=[ROOT.as_posix(),'https://github.com/Slagathore/sporespore.git','main','',self.head,self.head,self.head+'\trefs/heads/main']
        def receipts(values):return [dict(stdout=v,stderr='',exit_code=0,timed_out=False) for v in values]
        with patch.object(transport,'run_captured',side_effect=receipts(outputs)):
            self.assertEqual(self.head,preflight.current_freeze(self.head)['head'])
        for index,value in [(1,'https://example.invalid/repo'),(2,'other'),(3,' M source.py'),(5,'b'*40),(6,'b'*40+'\trefs/heads/main')]:
            bad=outputs.copy();bad[index]=value
            with self.subTest(index=index),patch.object(transport,'run_captured',side_effect=receipts(bad)),self.assertRaises(ValueError):preflight.current_freeze(self.head)
    def test_git_failure_preserves_stderr_and_checked_stage(self):
        receipt=dict(command=['git','rev-parse','--show-toplevel'],stdout='',stderr='synthetic retained diagnostic',exit_code=128,timed_out=False)
        with patch.object(transport,'run_captured',return_value=receipt),self.assertRaises(transport.CommandRefused) as raised:
            preflight.current_freeze(self.head)
        self.assertEqual(receipt,raised.exception.receipt)
    def test_structured_refusal_never_grants_authority(self):
        with patch.object(Path,'read_text',return_value=json.dumps(self.declaration)),patch.object(preflight.physical_identity,'require_physical_declaration',side_effect=ValueError('synthetic refusal')):
            result=preflight.inspect_request(ROOT/'synthetic-request.json',12345)
        self.assertFalse(result['ok']);self.assertEqual('declaration',result['stage'])
        self.assertEqual('synthetic refusal',result['failure_code'])
        for key in ['physical_execution_authorized','physical_acceptance_authority','release_authority','launch_reservation_created','native_world_claim_created']:
            self.assertIs(result[key],False)

if __name__=='__main__':unittest.main()
