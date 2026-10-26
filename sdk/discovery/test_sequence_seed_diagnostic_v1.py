"""Causal seed identity, history, envelope and mutation controls."""
import copy
import os
from pathlib import Path
import unittest
import numpy as np
from audit_sequence_seed_diagnostic_v1 import inputs,seed_packet,Policy,DLL,bridge,digest
from actuation_recovery_mechanics import command_envelope,resolve_correction


class SeedControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.core=bridge.LocomotionCore(Path(os.environ["QUADRUPED_TEST_CORE"]))
        cls.row,cls.profile,_=inputs();cls.policy=Policy(cls.core,cls.profile,DLL)
    def rebound(self,row):
        request=row["resolution_request"]["provider_request"];memory=request["provider_memory"]
        memory["opaque_state_sha256"]=digest(self.core,memory["opaque_state"])
        row["resolution"]=self.core.resolve_adaptation_v1(row["resolution_request"])
        d=row["force_reference"]["decision"];d["request_sha256"]=digest(self.core,request)
        d["nominal"]["request_sha256"]=digest(self.core,self.policy.nominal_request(request))
    def test_01_exact_refusal_and_actual_prior_plan(self):
        value,plan,internal,proposal=seed_packet(self.policy,self.row)
        self.assertEqual(value["command"],68);self.assertEqual(plan["command"],67)
        self.assertEqual(plan["request_sha256"],internal["provider_memory"]["opaque_state"]["previous_binding"])
        self.assertFalse(proposal["force_allocation_certificate"]);self.assertFalse(proposal["public_transfer_authority"])
    def test_02_projected_actual_correction_seed(self):
        value,_,_,proposal=seed_packet(self.policy,self.row)
        env=command_envelope(value["baseline"],value["speeds"],value["previous_correction"],[3.5]*8,[.08]*8)
        correction,target=resolve_correction(env,value["previous_correction"])
        self.assertEqual(correction.tolist(),value["nominal_correction"])
        self.assertEqual(target.tolist(),proposal["target"])
        self.assertTrue(np.all(np.abs(target)<=np.array(value["speeds"])+1e-12))
    def test_03_input_and_profile_immutable(self):
        before=copy.deepcopy((self.row,self.profile));seed_packet(self.policy,self.row)
        self.assertEqual(before,(self.row,self.profile))
    def test_04_nonrefusal_or_crossed_public_identity_refused(self):
        for field in ("stage","profile","resolution"):
            r=copy.deepcopy(self.row)
            if field=="stage":r["force_reference"]["decision"]["stage"]="selection"
            elif field=="profile":r["force_reference"]["decision"]["profile_sha256"]="sha256:"+"0"*64
            else:r["resolution"]["adaptation_applied"]=True
            with self.assertRaises(ValueError):seed_packet(self.policy,r)
    def test_05_nominal_identity_and_false_acceptance_refused(self):
        for field in ("request_sha256","accepted"):
            r=copy.deepcopy(self.row);n=r["force_reference"]["decision"]["nominal"]
            if field=="request_sha256":n[field]="sha256:"+"0"*64
            else:n["allocation"][field]=True
            with self.assertRaises(ValueError):seed_packet(self.policy,r)
    def test_06_rehashed_history_mismatch_refused(self):
        r=copy.deepcopy(self.row);req=r["resolution_request"]["provider_request"]
        req["history"]["ordered_entries"][0]["ordered_applied_corrections"][0]["canonical_velocity_delta_rad_s"]+=.01
        with self.assertRaises(ValueError):
            self.rebound(r);seed_packet(self.policy,r)
    def test_07_rehashed_plan_domain_and_binding_refused(self):
        for field in ("future","binding","clock"):
            r=copy.deepcopy(self.row);plan=r["resolution_request"]["provider_request"]["provider_memory"]["opaque_state"]["plan"]
            if field=="future":plan["future_observation"]=[]
            elif field=="binding":plan["request_sha256"]="sha256:"+"0"*64
            else:plan["command"]-=1
            with self.assertRaises(ValueError):
                self.rebound(r);seed_packet(self.policy,r)
    def test_08_current_permission_and_envelope_unchanged(self):
        for field in ("permission","slew"):
            r=copy.deepcopy(self.row);req=r["resolution_request"]["provider_request"]
            if field=="permission":req["deterministic_baseline"]["safe_no_actuation"]=True
            else:req["safety_envelope"]["ordered_actuator_limits"][0]["maximum_slew_per_step_rad_s"]=.09
            with self.assertRaises(ValueError):
                self.rebound(r);seed_packet(self.policy,r)


if __name__=="__main__":unittest.main()
