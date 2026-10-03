"""Both R10G role event populations through real worker hooks and serialized cold replay."""
import copy,json,unittest
from unittest import mock
import test_development_v32_recovery_route as shared
class FiniteRecoveryRoute(shared.RecoveryRoute):
    policy_id = "r10g_v50_finite_cycle_walking_route_v1"
    run_label = "R10G"
    baseline_event_count = 36
    contract_prefix = "r10g"
    contract_version = "v3"
    task_contract = "r10g_finite_cycle_kick_recovery_contract_v1.json"
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cases = {"positive": cls.producer["baseline_replay_input"]}
        for name in ("legacy_selection", "unknown_selection", "wrong_owner", "missing_event", "wrong_final_state"):
            item=copy.deepcopy(cases["positive"])
            if name=="legacy_selection":item["policy_id"]=""
            elif name=="unknown_selection":item["policy_id"]="unknown"
            elif name=="wrong_owner":item["events"][-1]["control_owner"]="walking_bw5r_b"
            elif name=="missing_event":item["events"].pop()
            else:item["final_state"]["matched_continuation_step_count"]+=1
            cases[name]=item
        path=cls.root/"baseline_event_reader_inputs.json";path.write_text(json.dumps(cases,separators=(",",":"))+"\n",encoding="utf-8")
        run=cls._run_retained("res://tests/test_development_v32_recovery_route.gd",cls.arguments(path),"baseline_cold_reader",60)
        cls.baseline_reader=shared.shared.marker(run,cls.run_label+"_ROUTE_READER ")
    def test_independent_serialized_event_reader_and_five_refusals(self):
        super().test_independent_serialized_event_reader_and_five_refusals()
        self.assertTrue(self.baseline_reader["positive"]["ok"])
        self.assertEqual(self.baseline_event_count,self.baseline_reader["positive"]["event_count"])
        self.assertEqual(6,len(self.baseline_reader))
        for name,result in self.baseline_reader.items():
            if name!="positive":self.assertFalse(result["ok"],name)
    def test_python_policy_selection_requires_complete_explicit_pair(self):
        super().test_python_policy_selection_requires_complete_explicit_pair()
        import development_recovery_candidate_checkpoint as checkpoint
        with mock.patch.object(checkpoint.prior,"committed",side_effect=lambda p,s:(shared.ROOT/p).read_bytes()):
            sources=checkpoint.walking_entry_rule_sources(self.selection["diagnostic_schedule"],"owned-r10g-integration")
        paths={s["path"] for s in sources}
        for part in ("entry","start","route"):
            self.assertIn("sdk/recovery/"+self.contract_prefix+"_v50_walking_"+part+"_contract_"+self.contract_version+".json",paths)
        self.assertIn("sdk/recovery/"+self.task_contract,paths)
if __name__ == "__main__": unittest.main()
