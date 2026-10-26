"""Selection domain, causality, refusal, guards, determinism and real interface checks."""
import copy
import unittest
from unittest.mock import patch
import numpy as np
import predictive_command_selection as s
from test_held_contact_rollout import FOLDER
from audit_gpu_batch_execution import read_jsonl
from hierarchical_native_task_v6 import read


class SelectionControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.profile=read(FOLDER/"force-profile.json")
        cls.model=s.PredictiveSelector(cls.profile,(FOLDER/"model.xml").read_text(encoding="utf-8"))
        cls.controls=list(read_jsonl(FOLDER/"controller.jsonl"))
    def value(self):return s.packet(self.controls[60])
    def forecast(self):
        q=[0.,0.,1.,1.,0.,0.,0.]+[0.]*8
        return dict(accepted=True,completed_steps=5,rows=[dict(step=i,qpos=q.copy(),
            qvel=[0.]*14,contacts=[],prediction=dict(actuator_force=[0.]*8)) for i in range(5)])
    def test_01_nominal_binding(self):
        v=self.value();rows=s.candidates(v)
        self.assertEqual(rows[0]["target"],self.controls[60]["native_targets"])
    def test_02_complete_candidates(self):
        rows=s.candidates(self.value());self.assertEqual(len(rows),34)
        self.assertEqual([r["index"] for r in rows],list(range(34)))
        self.assertEqual(len({r["name"] for r in rows}),34)
    def test_03_bounds_and_slew(self):
        v=self.value();envelope,_=s.validate(v)
        for row in s.candidates(v):
            c=np.array(row["correction"]);t=np.array(row["target"])
            self.assertTrue(np.all(c>=envelope["lower_correction"]))
            self.assertTrue(np.all(c<=envelope["upper_correction"]))
            self.assertTrue(np.all(np.abs(c-np.array(v["previous_correction"]))<=.08+1e-12))
            self.assertTrue(np.all(np.abs(t)<=3.5))
    def test_04_deterministic_samples(self):
        self.assertEqual(s.candidates(self.value()),s.candidates(self.value()))
    def test_05_command_seed_separation(self):
        v=self.value();other=copy.deepcopy(v);other["command"]+=1
        self.assertNotEqual(s.candidates(v)[-1],s.candidates(other)[-1])
    def test_06_future_fields_refused(self):
        for name in ("next_qpos","measured_force","future_contacts"):
            v=self.value();v[name]=[]
            with self.subTest(name=name),self.assertRaises(ValueError):s.candidates(v)
    def test_07_invalid_quaternion_refused(self):
        v=self.value();v["qpos"][3:7]=[0.]*4
        with self.assertRaises(ValueError):s.candidates(v)
    def test_08_nonfinite_refused(self):
        v=self.value();v["qvel"][0]=float("nan")
        with self.assertRaises(ValueError):s.candidates(v)
    def test_09_nominal_outside_slew_refused(self):
        v=self.value();v["nominal_correction"][0]=v["previous_correction"][0]+.2
        with self.assertRaises(ValueError):s.candidates(v)
    def test_10_existing_native_limit_refused(self):
        v=self.value();v["qpos"][7]=float(self.model.limits[0,1])+.01
        with self.assertRaisesRegex(ValueError,"native joint limit"):self.model.select(v)
    def test_11_joint_margin_guard(self):
        f=self.forecast();self.assertEqual(s.guard(f,self.model.limits),[])
        f["rows"][2]["qpos"][7]=float(self.model.limits[0,1])-.001
        self.assertIn("joint_position_margin",s.guard(f,self.model.limits))
    def test_12_joint_speed_guard(self):
        f=self.forecast();f["rows"][3]["qvel"][6]=3.51
        self.assertIn("joint_speed_cap",s.guard(f,self.model.limits))
    def test_13_height_guard(self):
        f=self.forecast();f["rows"][0]["qpos"][2]=.249
        self.assertIn("height",s.guard(f,self.model.limits))
    def test_14_tilt_guard(self):
        f=self.forecast();f["rows"][0]["qpos"][3:7]=[np.cos(.31),np.sin(.31),0.,0.]
        self.assertIn("tilt",s.guard(f,self.model.limits))
    def test_15_torso_guard(self):
        f=self.forecast();f["rows"][1]["contacts"]=[dict(geom=[0,1])]
        self.assertIn("torso_contact",s.guard(f,self.model.limits))
    def test_16_incomplete_forecast_refused(self):
        f=self.forecast();f["rows"].pop()
        with self.assertRaises(ValueError):s.guard(f,self.model.limits)
    def test_17_objective_quaternion_sign(self):
        f=self.forecast();a=self.model.cost(f,self.value())
        for row in f["rows"]:row["qpos"][3:7]=[-x for x in row["qpos"][3:7]]
        self.assertEqual(a,self.model.cost(f,self.value()));self.assertGreaterEqual(a["total"],0.)
        self.assertEqual(a["total"],sum(a["terms"].values()))
    def test_18_real_selection_is_causal_and_complete(self):
        v=self.value();before=copy.deepcopy(v);timing=[];result=self.model.select(v,timing)
        self.assertEqual(v,before);self.assertEqual(len(result["candidates"]),34);self.assertEqual(len(timing),34)
        for row in result["candidates"]:
            self.assertEqual(row["forecast"]["held_target"],row["target"])
        if result["accepted"]:
            eligible=[r for r in result["candidates"] if r["eligible"]]
            expected=min(eligible,key=lambda r:(r["objective"]["total"],r["index"]))
            self.assertEqual(result["selected_index"],expected["index"])
    def test_19_numerical_refusal_has_no_selected_target(self):
        f=dict(accepted=False,completed_steps=0,rows=[])
        with patch.object(self.model.rollout,"predict",return_value=f):result=self.model.select(self.value())
        self.assertFalse(result["accepted"]);self.assertIsNone(result["selected_target"])
        self.assertTrue(all(r["rejection_reasons"]==["numerical_refusal"] for r in result["candidates"]))
    def test_20_ineligible_nominal_never_selected(self):
        f=self.forecast();calls=[]
        def checked(*args):
            calls.append(1);return ["joint_position_margin"] if len(calls)==1 else []
        with patch.object(self.model.rollout,"predict",return_value=f),patch.object(s,"guard",side_effect=checked):
            result=self.model.select(self.value())
        self.assertEqual(result["selected_index"],1)
    def test_21_tie_preserves_nominal(self):
        with patch.object(self.model.rollout,"predict",return_value=self.forecast()):
            result=self.model.select(self.value())
        self.assertEqual(result["selected_index"],0)
    def test_22_exact_contract(self):
        import audit_predictive_command_selection as a
        self.assertEqual(a.declaration(),a.expected_contract())


if __name__=="__main__":unittest.main()
