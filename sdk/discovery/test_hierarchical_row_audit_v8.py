"""Public recovered-row verification and corruption controls."""
import copy
import os
from pathlib import Path
import unittest
from unittest.mock import patch
import numpy as np
from audit_gpu_batch_execution import read_jsonl
from contact_force_observer_task import ROOT,read,bridge
from hierarchical_force_policy_v8 import make_profile
from hierarchical_hold_control_v8 import HierarchicalHoldController,terminal_error
from hold_horizon_task import controller_contract,frozen_model,declaration
from dynamic_response_diagnostic_metrics import configured_model
from support_reach_geometry import ReachModel
from gpu_measurement_probe import write_new
import hierarchical_native_row_audit_v8 as audit

class RefinedRowControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.identity="hierarchy_hold_left_075_train_001"
        folder=ROOT.parent/"SporeSpore_Evidence/sdk2-hierarchical-native-v4-e021aaff51a8459a9f1c2309c72c6a77/physical"/cls.identity
        cls.originals=list(read_jsonl(folder/"controller.jsonl"))
        core=bridge.LocomotionCore(Path(os.environ["QUADRUPED_TEST_CORE"]));model=frozen_model(core)
        compiled=read(folder/"compiled.json");cls.profile=make_profile(compiled,read(folder/"inputs.json"))
        cls.model,_=configured_model((folder/"model.xml").read_text(),cls.profile)
        cls.reach=ReachModel(cls.profile["morphology_spec"])
        host=HierarchicalHoldController(core,compiled,controller_contract(declaration(),model),model,cls.identity,cls.profile)
        cls.nominal=host.force_policy.height;cls.rows=[]
        try:
            for old in cls.originals:
                cls.rows.append(host.step(copy.deepcopy(old["request"]["state"]),copy.deepcopy(old["stability"]),copy.deepcopy(old["kinematics"])))
                if terminal_error(cls.rows[-1]) is not None:break
        finally:
            host.close()
            if os.environ.get("EXPLORER_TEST_OUTPUT"):
                write_new(Path(os.environ["EXPLORER_TEST_OUTPUT"])/"scaled-public-row-fixture.json",
                    dict(profile=cls.profile,rows=cls.rows,worlds_opened=0,controller_closed=host.closed))
        if len(cls.rows)!=99 or terminal_error(cls.rows[-1]) is not None:raise ValueError("Refined row fixture incomplete")
    def verify(self,row,step):
        return audit.verify_row(row,self.originals[step],self.rows[step-1],self.profile,self.model,self.reach,self.nominal)
    def corrupt(self,change,step=89):
        row=copy.deepcopy(self.rows[step]);change(row["force_reference"]["decision"]["allocation"])
        with self.assertRaises(ValueError):self.verify(row,step)
    def test_01_original_route(self):
        v=self.verify(self.rows[60],60);self.assertEqual(v["solver_route"],"original_generic")
    def test_02_recovery_verified_without_solver(self):
        with patch.object(audit.hierarchy,"solve_priority",side_effect=AssertionError("Reader cannot solve")):
            v=self.verify(self.rows[89],89)
        self.assertEqual(v["solver_route"],"refined_primary");self.assertTrue(v["fallback_attempted"])
    def test_03_primary_candidate_corruption(self):
        self.corrupt(lambda a:a["primary"]["primary_refinement"]["diagnostic"]["candidate_x"].__setitem__(0,100.))
    def test_04_active_set_corruption(self):
        self.corrupt(lambda a:a["primary"]["primary_refinement"]["diagnostic"]["active_rows"].__setitem__(0,999))
    def test_05_original_refusal_cannot_claim_acceptance(self):
        self.corrupt(lambda a:a["original_refusal"].__setitem__("accepted",True))
    def test_06_false_route_rejected(self):
        self.corrupt(lambda a:a.__setitem__("solver_route","original_generic"))
    def test_07_equality_dual_rank_corruption(self):
        self.corrupt(lambda a:a["selected"].__setitem__("equality_dual_rank",0))
    def test_08_conditioning_corruption(self):
        self.corrupt(lambda a:a["selected"]["conditioning"].__setitem__("maximum_identity_error",1.))
    def test_09_selected_equations_corruption(self):
        self.corrupt(lambda a:a["attempts"][-1]["problem"]["q"].__setitem__(0,100.))
    def test_10_full_dual_corruption(self):
        self.corrupt(lambda a:a["selected"]["full_y"].__setitem__(0,100.))
    def test_11_last_held_step_corruption(self):
        self.corrupt(lambda a:a["prediction"]["predicted_steps"][4]["joint_position"].__setitem__(0,100.))
    def test_12_primary_guard_corruption(self):
        self.corrupt(lambda a:a["primary"]["primary_refinement"]["diagnostic"].__setitem__("active_equality_error",1.))
    def test_13_total_work_corruption(self):
        self.corrupt(lambda a:a.__setitem__("total_qp_solves",33))
    def test_14_original_refusal_equations_corruption(self):
        self.corrupt(lambda a:a["original_refusal"]["attempts"][-1]["problem"]["lower"].__setitem__(0,100.))
    def test_15_history_corruption(self):
        row=copy.deepcopy(self.rows[89]);row["resolution_request"]["provider_request"]["history"]["ordered_entries"][-1]["semantic_step"]=0
        with self.assertRaises(ValueError):self.verify(row,89)
    def test_16_authority_corruption(self):
        self.corrupt(lambda a:a["prediction"].__setitem__("physical_acceptance_authority",True))

    def test_17_new_primary_verified_without_any_qp_solver(self):
        from contextlib import ExitStack
        import generic_proximal_least_squares as primary
        import generic_proximal_qp_solver as secondary
        import hierarchical_least_squares_qp as old_primary
        import proximal_primary_contact_component_v2 as alternate
        with ExitStack() as guards:
            for module,name in ((primary,"solve"),(secondary,"solve"),(old_primary,"solve"),
                    (alternate,"solve_priority"),(alternate,"solve_secondary"),(audit.hierarchy,"solve_priority")):
                guards.enter_context(patch.object(module,name,side_effect=AssertionError("Reader cannot solve")))
            v=self.verify(self.rows[91],91)
        self.assertEqual(v["solver_route"],"proximal_primary")
        self.assertTrue(v["primary_backend_fallback_attempted"]);self.assertEqual(v["total_qp_solves"],6)
    def test_18_seed_mode_corruption(self):
        self.corrupt(lambda a:a["primary"].__setitem__("primary_selection_mode","refined"),91)
    def test_19_seed_refinement_cannot_be_claimed(self):
        self.corrupt(lambda a:a["primary"]["primary_refinement"].__setitem__("performed",True),91)
    def test_20_seed_guard_cannot_be_relaxed(self):
        self.corrupt(lambda a:a["primary"]["primary_refinement"].__setitem__("reduced_and_full_feasibility_guard",1e-6),91)
    def test_21_seed_initial_vector_corruption(self):
        self.corrupt(lambda a:a["primary"]["initial_primary"]["reduced"]["x"].__setitem__(0,100.),91)
    def test_22_previous_refusal_cannot_claim_acceptance(self):
        self.corrupt(lambda a:a["previous_refusal"].__setitem__("accepted",True),91)
    def test_23_previous_refusal_equations_corruption(self):
        self.corrupt(lambda a:a["previous_refusal"]["attempts"][0]["problem"]["q"].__setitem__(0,100.),91)
    def test_24_previous_refusal_refinement_corruption(self):
        self.corrupt(lambda a:a["previous_refusal"]["attempts"][0]["result"]["primary_refinement"].__setitem__("accepted",True),91)
    def test_25_new_backend_corruption(self):
        self.corrupt(lambda a:a["primary"]["reduced"].__setitem__("backend","OSQP builtin CPU"),91)
    def test_26_previous_route_work_corruption(self):
        self.corrupt(lambda a:a["previous_refusal"].__setitem__("total_qp_solves",0),91)
    def test_27_new_route_flag_corruption(self):
        self.corrupt(lambda a:a.__setitem__("primary_backend_fallback_attempted",False),91)
    def test_28_preserved_route_cannot_claim_new_backend(self):
        self.corrupt(lambda a:a.__setitem__("primary_backend_fallback_attempted",True),90)
    def test_29_refused_initial_backend_corruption(self):
        self.corrupt(lambda a:a["previous_refusal"]["attempts"][0]["result"]["initial_primary"]["reduced"].__setitem__("backend","changed"),91)
    def test_30_original_refusal_join_corruption(self):
        self.corrupt(lambda a:a["previous_refusal"]["original_refusal"].__setitem__("patterns_tried",7),91)
    def test_31_hessian_regularization_claim_rejected(self):
        self.corrupt(lambda a:a["primary"]["reduced"].__setitem__("hessian_source","regularized"),91)
    def test_32_new_primary_fifth_step_corruption(self):
        self.corrupt(lambda a:a["prediction"]["predicted_steps"][4]["joint_position"].__setitem__(0,100.),91)

    def test_33_scaled_route_without_solver_or_producer_helpers(self):
        from contextlib import ExitStack
        import generic_proximal_least_squares as primary
        import generic_proximal_qp_solver as secondary
        import hierarchical_least_squares_qp as old_primary
        import scaled_primary_refinement as producer
        import scaled_primary_contact_component as alternate
        with ExitStack() as guards:
            for module,name in ((primary,"solve"),(secondary,"solve"),(old_primary,"solve"),
                    (producer,"solve_priority"),(producer,"correction_problem"),(producer,"mapped_solution"),
                    (alternate,"solve_priority"),(alternate,"solve_secondary")):
                guards.enter_context(patch.object(module,name,side_effect=AssertionError("Independent reader cannot solve or call producer")))
            v=self.verify(self.rows[98],98)
        self.assertEqual(v["solver_route"],"scaled_primary");self.assertEqual(v["total_qp_solves"],9)
        self.assertTrue(v["scaled_primary_fallback_attempted"])
    def test_34_initial_certificate_corruption(self):
        self.corrupt(lambda a:a["primary"]["initial_primary"]["full_certificate"].__setitem__("maximum_bound_violation",0.),98)
    def test_35_correction_origin_corruption(self):
        self.corrupt(lambda a:a["primary"]["scaled_corrections"][0]["problem"]["origin"].__setitem__(0,100.),98)
    def test_36_correction_scale_sequence_corruption(self):
        self.corrupt(lambda a:a["primary"]["scaled_corrections"][0].__setitem__("exponent",30),98)
    def test_37_affine_objective_corruption(self):
        self.corrupt(lambda a:a["primary"]["scaled_corrections"][0]["problem"]["task_target"].__setitem__(0,100.),98)
    def test_38_scaled_solver_status_corruption(self):
        self.corrupt(lambda a:a["primary"]["scaled_corrections"][0]["solver"].__setitem__("status","solved inaccurate"),98)
    def test_39_scaled_solver_certificate_corruption(self):
        self.corrupt(lambda a:a["primary"]["scaled_corrections"][0]["solver"]["certificate"].__setitem__("maximum_bound_violation",1.),98)
    def test_40_mapped_primal_corruption(self):
        self.corrupt(lambda a:a["primary"]["scaled_corrections"][0]["mapped"]["reduced"]["x"].__setitem__(0,100.),98)
    def test_41_mapped_dual_corruption(self):
        self.corrupt(lambda a:a["primary"]["scaled_corrections"][0]["mapped"]["full_y"].__setitem__(0,100.),98)
    def test_42_original_certificate_corruption(self):
        self.corrupt(lambda a:a["primary"]["full_certificate"].__setitem__("maximum_bound_violation",1e-7),98)
    def test_43_inner_solve_count_corruption(self):
        self.corrupt(lambda a:a["primary"].__setitem__("qp_solves",1),98)
    def test_44_strict_guard_and_permission_corruption(self):
        self.corrupt(lambda a:a["primary"]["scaled_corrections"][0].__setitem__("strict_guard_passed",False),98)
        profile=copy.deepcopy(self.profile);profile["solver_settings"]["alternate"]["primary_refinement"]["primary_feasibility_absolute_guard"]=1e-6
        with self.assertRaises(ValueError):
            audit.verify_row(self.rows[98],self.originals[98],self.rows[97],profile,self.model,self.reach,self.nominal)
    def test_45_missing_correction_refused(self):
        self.corrupt(lambda a:a["primary"].__setitem__("scaled_corrections",[]),98)
    def test_46_correction_after_acceptance_refused(self):
        self.corrupt(lambda a:a["primary"]["scaled_corrections"].append(copy.deepcopy(a["primary"]["scaled_corrections"][0])),98)
    def test_47_third_route_initial_binding_corruption(self):
        self.corrupt(lambda a:a["scaling_previous_refusal"]["attempts"][0]["result"]["initial_primary"]["reduced"].__setitem__("backend","changed"),98)
    def test_48_third_route_failed_refinement_corruption(self):
        self.corrupt(lambda a:a["scaling_previous_refusal"]["attempts"][0]["result"]["primary_refinement"].__setitem__("accepted",True),98)
    def test_49_complete_predecessor_work_corruption(self):
        self.corrupt(lambda a:a["scaling_previous_refusal"].__setitem__("total_qp_solves",0),98)
    def test_50_scaled_route_cannot_hide_as_predecessor(self):
        self.corrupt(lambda a:a.__setitem__("scaled_primary_fallback_attempted",False),98)

if __name__=="__main__":unittest.main()
