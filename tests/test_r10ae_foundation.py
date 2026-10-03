"""R10AE identity isolation and preservation of the physical question."""
import copy,json,sys,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'sdk/conformance'));sys.path.insert(0,str(ROOT/'tests'))
import r10ae_development as identity
import r10ae_preflight_fixture as fixture
import r10ae_host_runtime as host

class R10AEFoundation(unittest.TestCase):
    def test_fresh_identity_is_explicitly_exposed_and_noncomparative(self):
        declaration=fixture.fixture('a'*40)
        result=identity.validate_declaration(declaration)
        self.assertEqual((63248,248),(result['seed'],result['identity']['prefix_phase']))
        self.assertEqual(['kick_passive_recovery_resume'],result['roles'])
        self.assertIs(declaration['comparative_authority'],False)
    def test_consumed_or_crossed_identity_refused(self):
        declaration=fixture.fixture('a'*40)
        for key,value in [('seed',62248),('r10ad_development',{}),('physical_acceptance_authority',True)]:
            changed=copy.deepcopy(declaration);changed[key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):identity.validate_declaration(changed)
    def test_controller_observer_and_physical_schedule_unchanged(self):
        def read(p):return json.loads((ROOT/p).read_text())
        old=read('sdk/recovery/r10ad_contact_frame_development_design_v1.json');new=read('sdk/recovery/r10ae_contact_frame_development_design_v1.json')
        for key in ['question','engine','core_runtime_sha256','limits','telemetry','outcome_rules']:
            self.assertEqual(old[key],new[key],key)
        a=read('sdk/development/recovery_schedules/r10ad-contact-frame-diagnostic-v1.json')['schedules']['r10ad-contact-frame-diagnostic-v1']
        b=read('sdk/development/recovery_schedules/r10ae-contact-frame-diagnostic-v1.json')['schedules']['r10ae-contact-frame-diagnostic-v1']
        allowed={'walking_entry_profile_id','walking_start_profile_id','coverage_basis','coverage_adequacy','coverage_question','coverage_argument'}
        self.assertEqual(allowed,{k for k in a if a[k]!=b[k]})
        self.assertEqual({'successor_design','successor_design_sha256'},{k for k in a['coverage_basis'] if a['coverage_basis'][k]!=b['coverage_basis'][k]})
    def test_runtime_binding_is_exact_and_predecessor_refused(self):
        current=host.expected_binding();host.validate_binding(current)
        old=json.loads((ROOT/'sdk/development/r10ad_host_runtime_contract_v1.json').read_text())
        self.assertEqual(old['images'],current['images'])
        with self.assertRaises(ValueError):host.validate_binding(old)

if __name__=='__main__':unittest.main()
