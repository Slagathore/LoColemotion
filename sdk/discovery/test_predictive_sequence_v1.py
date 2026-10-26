"""Bounds, causal inputs, refusal, search and reference reconstruction controls."""
import copy
import io
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import numpy as np
import predictive_sequence_v1 as sequence
import predictive_sequence_task_v1 as task
from audit_predictive_sequence_v1 import Capture,packet,verify_sequence,forecast_recorded,native_errors
from audit_predictive_numeric_backend import compare
from prepared_predictive_model import PreparedSelector
from predictive_command_selection_v2 import PredictiveSelector
from audit_gpu_batch_execution import same_bits


def synthetic_value():
    return dict(command=60,qpos=[0.,0.,1.,1.,0.,0.,0.]+[0.]*8,qvel=[0.]*14,
        baseline=[0.]*8,speeds=[3.5]*8,previous_correction=[0.]*8,nominal_correction=[0.]*8,
        target_com=[0.,1.,0.],reference_joints=[0.]*8)


class SyntheticSelector:
    limits=np.array([[-2.,2.]]*8)
    def __init__(self):self.rollout=self
    def predict(self,start):
        rows=[dict(step=i,before_qpos=list(start["qpos"]),before_qvel=list(start["qvel"]),
            qpos=list(start["qpos"]),qvel=list(start["qvel"]),contacts=[]) for i in range(5)]
        return dict(accepted=True,rows=rows,completed_steps=5,held_target=list(start["target_velocity"]),
            final_qpos=rows[-1]["qpos"],final_qvel=rows[-1]["qvel"])
    def cost(self,forecast,value):
        return dict(total=float(sum(x*x for x in forecast["held_target"])),terms=dict(synthetic=True))


class SequenceControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.rows,cls.trace,cls.profile,cls.xml=task.inputs()
        cls.value=packet(cls.rows[60],cls.profile)
        cls.model=PreparedSelector(cls.profile["prepared_model"],task.DLL,task.DLL_SHA)
        cls.reference=PredictiveSelector(cls.profile["nominal_profile"],cls.xml)

    def simple(self):
        value=synthetic_value();knots=np.zeros((4,8)).tolist();model=SyntheticSelector()
        return value,knots,model

    def test_01_sequential_correction_bounds(self):
        value=synthetic_value();knots=np.full((4,8),3.5)
        corrections,targets=sequence.commands(value,knots,66)
        previous=np.zeros(8)
        for correction,target in zip(corrections,targets,strict=True):
            self.assertTrue(np.all(np.abs(np.array(correction)-previous)<=.08+1e-12))
            self.assertTrue(np.all(np.abs(correction)<=3.5));previous=np.array(correction)
        self.assertEqual(corrections[-1],[3.5]*8)

    def test_02_per_actuator_speed_caps(self):
        value=synthetic_value();value["speeds"]=[3.,3.5]*4;value["baseline"]=[3.]*8
        _,targets=sequence.commands(value,np.full((4,8),3.5),66)
        self.assertEqual(targets[-1],[3.,3.5]*4)

    def test_03_linear_control_points_and_single_interval(self):
        value=synthetic_value();knots=np.zeros((4,8));knots[:,0]=[.01,.02,.03,.04]
        corrections,_=sequence.commands(value,knots,4)
        self.assertEqual([r[0] for r in corrections],[.01,.02,.03,.04])
        self.assertEqual(sequence.commands(value,knots,1)[0][0][0],.01)

    def test_04_invalid_domain(self):
        value=synthetic_value()
        for horizon in (0,67,True,1.5):
            with self.assertRaises(ValueError):sequence.commands(value,np.zeros((4,8)),horizon)
        for knots in (np.zeros((3,8)),np.full((4,8),3.6),np.full((4,8),np.nan)):
            with self.assertRaises(ValueError):sequence.commands(value,knots,4)

    def test_05_input_immutability(self):
        value=synthetic_value();before=copy.deepcopy(value);knots=np.zeros((4,8));original=knots.copy()
        sequence.commands(value,knots,66);sequence.parameters(value,knots,0)
        self.assertEqual(value,before);np.testing.assert_array_equal(knots,original)

    def test_06_deterministic_candidates(self):
        value=synthetic_value();knots=np.zeros((4,8))
        self.assertEqual(sequence.parameters(value,knots,1),sequence.parameters(value,knots,1))

    def test_07_seed_separation(self):
        value=synthetic_value();knots=np.zeros((4,8))
        a=sequence.parameters(value,knots,0);b=sequence.parameters(value,knots,1)
        value["command"]+=1;c=sequence.parameters(value,knots,0)
        self.assertNotEqual(a[20:],b[20:]);self.assertNotEqual(a[20:],c[20:])

    def test_08_candidate_population(self):
        value=synthetic_value();options=sequence.parameters(value,np.zeros((4,8)),0)
        self.assertEqual(len(options),34);self.assertEqual([r["index"] for r in options],list(range(34)))
        self.assertEqual([r["name"] for r in options[:4]],["incumbent","zero_correction","zero_target","velocity_brake"])
        self.assertTrue(all(np.all(np.abs(r["knots"])<=3.5) for r in options))

    def test_09_one_interval_matches_consumed_nominal(self):
        knots=np.tile(self.value["nominal_correction"],(4,1))
        result=sequence.evaluate(self.model,self.value,knots,1)
        old=self.rows[60]["force_reference"]["decision"]["selection"]["candidates"][0]
        self.assertTrue(same_bits(result["rows"][0]["forecast"],old["forecast"]))
        self.assertEqual(result["rows"][0]["guard_reasons"],old["rejection_reasons"])
        self.assertEqual(result["rows"][0]["objective"],old["objective"])

    def test_10_two_interval_reference_and_continuity(self):
        knots=np.tile(self.value["nominal_correction"],(4,1))
        result=sequence.evaluate(self.model,self.value,knots,2)
        verify_sequence(result,self.value,knots,2,self.model)
        measured=compare(sequence.evaluate(self.reference,self.value,knots,2),result)
        self.assertLessEqual(measured["maximum_velocity_error"],1e-8)
        self.assertTrue(result["eligible"])

    def test_11_guard_refusal_stops_sequence(self):
        value,knots,model=self.simple();value["qvel"][6]=4.
        result=sequence.evaluate(model,value,knots,12)
        self.assertFalse(result["eligible"]);self.assertEqual(result["attempted_intervals"],1)
        self.assertEqual(result["rejection_reasons"],["joint_speed_cap"])

    def test_12_numerical_refusal_is_not_eligible(self):
        value,knots,model=self.simple()
        with patch.object(model,"predict",return_value=dict(accepted=False,completed_steps=0,rows=[{}])):
            result=sequence.evaluate(model,value,knots,12)
        self.assertFalse(result["eligible"]);self.assertIsNone(result["mean_objective"])
        self.assertEqual(result["rejection_reasons"],["numerical_refusal"])

    def test_13_full_horizon_required(self):
        value,knots,model=self.simple();result=sequence.evaluate(model,value,knots,12)
        result["rows"].pop()
        with self.assertRaises(ValueError):verify_sequence(result,value,knots,12,model)

    def test_14_rank_requires_finite_cost_and_prefers_eligibility(self):
        self.assertLess(sequence.rank(dict(eligible=True,valid_intervals=12,mean_objective=1000.)),
            sequence.rank(dict(eligible=False,valid_intervals=11,mean_objective=0.)))
        for cost in (-1.,float("nan"),float("inf")):
            with self.assertRaises(ValueError):sequence.rank(dict(eligible=False,valid_intervals=1,mean_objective=cost))

    def test_15_complete_bounded_search_preserves_incumbent(self):
        value,_,model=self.simple();records=[]
        result=sequence.search(model,value,3,records.append)
        self.assertEqual(len(records),102);self.assertTrue(result["best"]["result"]["eligible"])
        self.assertTrue(all(r["best_index"]==0 for r in result["rounds"]))
        self.assertFalse(result["native_recovery_established"]);self.assertFalse(result["trained"])

    def test_16_future_observation_and_action_inputs_rejected(self):
        value,knots,model=self.simple()
        for key in ("future_observations","future_recorded_actions"):
            bad=dict(value,**{key:[]})
            with self.assertRaises(ValueError):sequence.evaluate(model,bad,knots,12)

    def test_17_changed_projected_target_refused(self):
        value,knots,model=self.simple();result=sequence.evaluate(model,value,knots,2)
        result["rows"][1]["target"][0]=1.
        with self.assertRaises(ValueError):verify_sequence(result,value,knots,2,model)

    def test_18_changed_predicted_state_join_refused(self):
        value,knots,model=self.simple();result=sequence.evaluate(model,value,knots,2)
        result["rows"][1]["forecast"]["rows"][0]["before_qvel"][0]=1.
        with self.assertRaises(ValueError):verify_sequence(result,value,knots,2,model)

    def test_19_forged_guard_or_objective_refused(self):
        value,knots,model=self.simple()
        for key,replacement in (("guard_reasons",["invented"]),("objective",dict(total=99.))):
            result=sequence.evaluate(model,value,knots,2);result["rows"][0][key]=replacement
            with self.assertRaises(ValueError):verify_sequence(result,value,knots,2,model)

    def test_20_authority_promotion_refused(self):
        value,knots,model=self.simple()
        for key in ("future_observations_used","future_recorded_actions_used","public_future_envelope_equivalence",
            "trained","physical_acceptance_authority","release_authority"):
            result=sequence.evaluate(model,value,knots,2);result[key]=True
            with self.assertRaises(ValueError):verify_sequence(result,value,knots,2,model)

    def test_21_recorded_calibration_never_resets_state(self):
        targets=[r["native_targets"] for r in self.rows[60:62]]
        forecast=forecast_recorded(self.model,self.value,targets)
        checked=native_errors(forecast,self.trace,60,targets)
        self.assertTrue(forecast["completed"]);self.assertEqual(checked["compared_native_steps"],10)
        self.assertFalse(forecast["intermediate_native_observations_used"])
        self.assertEqual(forecast["rows"][1]["forecast"]["rows"][0]["before_qpos"],
            forecast["rows"][0]["forecast"]["final_qpos"])
        bad=copy.deepcopy(targets);bad[0][0]+=1.
        with self.assertRaises(ValueError):native_errors(forecast,self.trace,60,bad)

    def test_22_capture_row_and_total_limits(self):
        capture=Capture(Path("synthetic"),dict(maximum_capture_row_bytes=10,maximum_capture_bytes=12));stream=io.BytesIO()
        capture.append(stream,dict(a=1));self.assertEqual(capture.rows,1)
        with self.assertRaises(ValueError):capture.append(stream,dict(a=1))
        self.assertEqual(capture.rows,1)
        with self.assertRaises(ValueError):capture.append(stream,dict(a="long value"))

    def test_23_parent_population_and_authority_refusals(self):
        self.assertTrue(task.verify_parent()["ok"])
        original=task.read;target=task.EVIDENCE/task.PARENT/"audit.json"
        for change in (dict(constructed_cpu_worlds=4),dict(execution_complete=True),dict(controller_rows=115)):
            def crossed(path):return dict(original(path),**change) if path==target else original(path)
            with patch.object(task,"read",side_effect=crossed):
                with self.assertRaises(ValueError):task.verify_parent()

    def test_24_contract_cannot_change(self):
        c=task.declaration();self.assertEqual(c["planned_search_evaluations"],612);self.assertEqual(task.CONTROLS,139)
        self.assertEqual(c["horizons"],[66,54,42,30,18,12])
        for change in (dict(native_worlds=1),dict(control_points=8),dict(future_baseline="actual unknown future")):
            original=task.read
            with patch.object(task,"read",side_effect=lambda p:dict(c,**change) if p==task.CONTRACT else original(p)):
                with self.assertRaises(ValueError):task.declaration()


if __name__=="__main__":unittest.main()

