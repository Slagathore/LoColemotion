"""Never promote R10AC's startup refusal to a physics result or partial gate."""
import copy,sys,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'sdk/conformance'))
import r10ac_startup_invalid_closure as closure

class StartupClosure(unittest.TestCase):
    def setUp(self):
        child=closure.RUN/'children/kick_passive_recovery_resume'
        self.inputs=[closure.read(p) for p in [closure.RUN/'declaration.json',closure.RUN/'supervisor_result.json',
            child/'worker_report.json',child/'termination_receipt.json',closure.TOKEN,
            closure.RUN/'r10ac_development_launch.json',closure.CONTRACT]]
    def test_original_is_invalid_with_zero_physics(self):
        observed=closure.validate_observation(*self.inputs)
        self.assertEqual(196,observed['safety_tests']);self.assertEqual(0,observed['physical_worlds'])
    def test_nonzero_or_boolean_counters_cannot_be_closed_as_zero_world(self):
        for field in ['world_build_count','solver_step_count','model_construction_count','external_kick_application_count']:
            for value in [1,False]:
                args=copy.deepcopy(self.inputs);args[2][field]=value
                with self.subTest(field=field,value=value),self.assertRaisesRegex(ValueError,'ZERO_WORLD_COUNTERS'):
                    closure.validate_observation(*args)
    def test_partial_or_failed_gate_cannot_be_promoted(self):
        for mutation in ['missing','failed']:
            args=copy.deepcopy(self.inputs)
            if mutation=='missing':
                args[0]['safety_stages'].pop();args[1]['safety_stages'].pop()
            else:
                args[0]['safety_stages'][0]['passed']=False;args[1]['safety_stages'][0]['passed']=False
            with self.subTest(mutation=mutation),self.assertRaises(ValueError):closure.validate_observation(*args)
    def test_missing_reservation_or_new_success_changes_the_outcome(self):
        for index,key,value in [(4,'attempt_limit',2),(2,'recovery_success_observed',True),(3,'termination_ready_receipt',{})]:
            args=copy.deepcopy(self.inputs);args[index][key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):closure.validate_observation(*args)

if __name__=='__main__':unittest.main()
