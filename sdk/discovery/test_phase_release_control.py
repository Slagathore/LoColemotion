"""Real-ABI baseline bits, matched activation timing, truthful history and refusal."""
import copy
import json
import math
import unittest
from unittest.mock import patch
import mujoco
import test_gpu_repertoire_v2 as fixtures
from cpu_phase_release_task import declaration, trial_plan
from phase_release_control import PhaseReleaseController, ROLES
from support_vertical_control import SupportVerticalController
from cpu_support_vertical_task import declaration as reference_declaration
from audit_phase_release import validate_proposal
from audit_gpu_batch_execution import same_bits


class PhaseReleaseControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        fixtures.RepertoireControls.setUpClass();cls.f=fixtures.RepertoireControls
        cls.c=declaration();cls.old_c=reference_declaration();cls.plan=trial_plan(cls.c)[0]
        cls.native=cls.f.native(cls.plan,0);cls.native.pop("contact_compatibility_copy",None)
        cls.rows=[]
        with patch.object(mujoco,"MjModel",side_effect=AssertionError("No world")), \
                patch.object(mujoco,"MjData",side_effect=AssertionError("No data")):
            for index in range(4):
                controller=PhaseReleaseController(cls.f.core,cls.f.compiled,cls.c,index)
                try:cls.rows.append([controller.step(*cls.f.observations(cls.native,step)) for step in range(18)])
                finally:controller.close()
        for index,rows in enumerate(cls.rows):
            with (cls.f.root/("phase-release-prefix-"+str(index)+".jsonl")).open("x",encoding="utf-8",newline="\n") as stream:
                for row in rows:stream.write(json.dumps(row,allow_nan=False,separators=(",",":"))+"\n")

    def setUp(self):
        for name in ["MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"]:
            guard=patch.object(mujoco,name,side_effect=AssertionError("No worlds in controls"))
            guard.start();self.addCleanup(guard.stop)

    def test_baseline_bits_and_delayed_prefix_match_absent_provider(self):
        baseline=SupportVerticalController(self.f.core,self.f.compiled,self.old_c,0)
        try:
            for step in range(18):
                expected=baseline.step(*self.f.observations(self.native,step))
                for index in ([0,3] if step<16 else [0]):
                    row=self.rows[index][step]
                    for name in ["output","composition","native_targets"]:self.assertTrue(same_bits(row[name],expected[name]))
                    self.assertFalse(row["resolution"]["adaptation_applied"])
                    self.assertEqual(row["resolution"]["provider_status"],"no_proposal")
        finally:baseline.close()

    def test_immediate_role_matches_original_vertical_equations_and_commands(self):
        original=SupportVerticalController(self.f.core,self.f.compiled,self.old_c,2)
        try:
            for step,row in enumerate(self.rows[1]):
                expected=original.step(*self.f.observations(self.native,step))
                for name in ["output","composition","native_targets","feedback"]:self.assertTrue(same_bits(row[name],expected[name]))
                self.assertEqual(row["resolution"]["ordered_commands"],expected["resolution"]["ordered_commands"])
                self.assertEqual(row["resolution_request"]["provider_request"]["history"]["ordered_entries"],[])
                self.assertIsNone(row["activation_probe"]["features"])
        finally:original.close()

    def test_first_influence_is_zero_or_sixteen_with_fresh_slew(self):
        for index,rows in enumerate(self.rows):
            applied=[i for i,row in enumerate(rows) if row["resolution"]["adaptation_applied"]]
            self.assertEqual(applied[0] if applied else None,ROLES[index]["activation_step"])
            if applied:
                values=[r["applied_correction_rad_s"] for r in rows[applied[0]]["resolution"]["ordered_commands"]]
                self.assertTrue(any(v!=0. for v in values));self.assertTrue(all(abs(v)<=.08 for v in values))

    def test_shared_sixteen_step_features_have_truthful_private_receipts(self):
        for index in [0,3]:
            rows=self.rows[index];entries=rows[16]["resolution_request"]["provider_request"]["history"]["ordered_entries"]
            self.assertEqual([e["semantic_step"] for e in entries],list(range(16)))
            for entry,row in zip(entries,rows[:16],strict=True):
                self.assertEqual(entry["state"],row["request"]["state"])
                self.assertEqual(entry["provider_status"],"no_proposal");self.assertFalse(entry["adaptation_applied"])
                self.assertEqual(entry["request_sha256"],row["resolution"]["request_sha256"])
                self.assertEqual(entry["resolution_receipt_sha256"],self.f.core.canonicalize_json(row["resolution"])["sha256"])
            self.assertEqual(rows[17]["resolution_request"]["provider_request"]["history"]["ordered_entries"],[])
        self.assertTrue(same_bits(self.rows[0][16]["activation_probe"]["features"],self.rows[3][16]["activation_probe"]["features"]))
        self.assertEqual(self.rows[3][16]["activation_probe"]["features"]["past_entries"],16)

    def test_role_identity_clock_and_closed_session_refuse(self):
        for index in [-1,4,True]:
            with self.assertRaises(ValueError):PhaseReleaseController(self.f.core,self.f.compiled,self.c,index)
        controller=PhaseReleaseController(self.f.core,self.f.compiled,self.c,3)
        try:
            with self.assertRaisesRegex(ValueError,"lifecycle/clock"):controller.step(*self.f.observations(self.native,1))
        finally:controller.close()
        with self.assertRaisesRegex(ValueError,"lifecycle/clock"):controller.step(*self.f.observations(self.native,0))
        controller.close()

    def test_unsupported_height_feedback_withdraws_to_current_baseline(self):
        controller=PhaseReleaseController(self.f.core,self.f.compiled,self.c,3)
        try:
            for step in range(17):controller.step(*self.f.observations(self.native,step))
            state,stability,kinematics=self.f.observations(self.native,17)
            state["base_pose_world"]["orientation_xyzw"]=dict(x=math.sin(.45),y=0.,z=0.,w=math.cos(.45))
            row=controller.step(state,stability,kinematics)
            self.assertEqual(row["feedback"]["status"],"refused")
            self.assertIsNone(row["resolution_request"]["provider_response"])
            for actual,baseline in zip(row["resolution"]["ordered_commands"],row["composition"]["canonical_actuation"]["ordered_commands"],strict=True):
                self.assertEqual(actual["applied_correction_rad_s"],0.)
                self.assertTrue(same_bits(actual["final_canonical_target_velocity_rad_s"],baseline["combined_canonical_target_velocity_rad_s"]))
        finally:controller.close()

    def test_partial_mapping_failure_closes_session(self):
        controller=PhaseReleaseController(self.f.core,self.f.compiled,self.c,3)
        with patch("phase_release_control.map_resolution",side_effect=ValueError("injected failure")):
            with self.assertRaisesRegex(ValueError,"injected failure"):controller.step(*self.f.observations(self.native,0))
        self.assertTrue(controller.closed)
        with self.assertRaisesRegex(ValueError,"lifecycle/clock"):controller.step(*self.f.observations(self.native,0))

    def test_independent_onset_envelope_and_feature_refusals(self):
        for index,rows in enumerate(self.rows):
            previous=[0.]*8
            for row in rows:
                validate_proposal(row,self.c,index,previous)
                previous=[r["applied_correction_rad_s"] for r in row["resolution"]["ordered_commands"]]
        for kind in ["onset","features","history","target"]:
            row=copy.deepcopy(self.rows[3][16]);previous=[0.]*8
            if kind=="onset":row["activation_probe"]["activation_step"]=0
            elif kind=="features":row["activation_probe"]["features"]["values"][0]+=.01
            elif kind=="history":row["resolution_request"]["provider_request"]["history"]["ordered_entries"].pop()
            else:row["native_targets"][0]+=.01
            with self.assertRaises(ValueError):validate_proposal(row,self.c,3,previous)


if __name__ == "__main__":unittest.main()
