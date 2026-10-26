"""Prospective zero-world scope, refusal and corruption controls."""
import copy
import io
import itertools
import os
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import numpy as np
import predictive_native_task_v1 as task
import predictive_native_checks_v1 as checks
from predictive_native_trial_v1 import transfer_targets,refusal_receipt
from predictive_native_trial_audit_v1 import bounded_rows,selected_reference
from predictive_native_v1 import preflight
from audit_gpu_batch_execution import read_jsonl,SECTIONS


class PredictiveNativeControls(unittest.TestCase):
    def setUp(self):
        self.c=task.declaration();self.source="0"*40;self.attempt="sdk2-predictive-native-v1-synthetic"
        self.owner=dict(source_commit=self.source,contract=self.c,planned_trials=task.plans(self.c),
            source_status=[],component_only=False,**{k:False for k in task.FLAGS})
        self.gate=dict(ok=True,source_commit=self.source,declaration_sha256="declaration",
            safety_controls={**{n:k for n,_,k in task.GATES},"provider":2,"containment":1},
            preflight=dict(ok=True,world_build_count=0,solver_steps=0,component_evidence_verified=True,gate_coverage_verified=True))
        self.consumed=dict(attempt_id=self.attempt,source_commit=self.source,contract_sha256=task.sha(task.CONTRACT),
            declaration_sha256="declaration",gate_receipt_sha256="gate",trials=task.plans(self.c))

    def validate(self):
        task.validate_launch_documents(self.owner,self.gate,self.consumed,self.c,self.source,self.attempt,"declaration","gate")

    def test_01_complete_gate(self):
        self.validate();self.assertEqual(sum(self.gate["safety_controls"].values()),1227)

    def test_02_scope(self):
        plans=task.plans(self.c)
        self.assertEqual(len({p["trial_id"] for p in plans}),4)
        self.assertTrue(all(p["start_id"]=="train_001" and p["seed"]==104242001 for p in plans))
        self.assertEqual(self.c["outer_steps"],1440);self.assertEqual(self.c["horizon_s"],12.)
        self.assertEqual(self.c["selection"]["minimum_height_m"],.25);self.assertEqual(self.c["selection"]["maximum_tilt_rad"],.6)

    def test_03_changed_scope(self):
        for change in (dict(roles=["predictive_hold"]),dict(groups=["nominal_train_003"]),
            dict(outer_steps=120),dict(horizon_s=1.),dict(planned_gpu_worlds=1)):
            with self.assertRaises(ValueError):task.plans(dict(self.c,**change))

    def test_04_dirty_or_component_only(self):
        for change in (dict(source_status=[" M unexpected.py"]),dict(component_only=True)):
            saved=copy.deepcopy(self.owner);self.owner.update(change)
            with self.assertRaises(ValueError):self.validate()
            self.owner=saved

    def test_05_missing_gate(self):
        for name in ("prediction-predictive-policy","predictive-native","containment"):
            saved=self.gate["safety_controls"].copy()
            # Select the declared policy name without depending on its presentation label.
            key=next(n for n,m,_ in task.GATES if m=="test_predictive_hold_policy_v1") if "policy" in name else name
            del self.gate["safety_controls"][key]
            with self.assertRaises(ValueError):self.validate()
            self.gate["safety_controls"]=saved

    def test_06_preflight_false_or_physical(self):
        for change in (dict(component_evidence_verified=False),dict(gate_coverage_verified=False),dict(world_build_count=1)):
            saved=self.gate["preflight"].copy();self.gate["preflight"].update(change)
            with self.assertRaises(ValueError):self.validate()
            self.gate["preflight"]=saved

    def test_07_consumed_identity(self):
        for key in ("attempt_id","source_commit","contract_sha256","declaration_sha256","gate_receipt_sha256"):
            value=self.consumed[key];self.consumed[key]="crossed"
            with self.assertRaises(ValueError):self.validate()
            self.consumed[key]=value

    def test_08_authority(self):
        for key in task.FLAGS:
            self.owner[key]=True
            with self.assertRaises(ValueError):self.validate()
            self.owner[key]=False

    def terminal(self):
        data=SimpleNamespace(ctrl=np.ones(8),qpos=np.zeros(15),qvel=np.zeros(14),time=.5)
        row=dict(force_reference=dict(terminal_error=dict(type="failure")),native_targets=[0.]*8,outer_step=60,
            native_observation=dict(qpos=data.qpos.tolist(),qvel=data.qvel.tolist(),time_s=.5))
        return row,data

    def test_09_terminal_transfer(self):
        row,data=self.terminal()
        with self.assertRaises(ValueError):transfer_targets(row,data)
        np.testing.assert_array_equal(data.ctrl,np.ones(8))

    def test_10_refusal_state_join(self):
        row,data=self.terminal();value=refusal_receipt(row,data,"predictive_hold")
        result=dict(terminal_refusal=value);last=dict(qpos=value["qpos"],qvel=value["qvel"],time_s=.5)
        checks.refusal_join(result,row,last,([],[]),[1.]*8)
        for key in ("qpos","qvel","native_control"):
            bad=copy.deepcopy(result);bad["terminal_refusal"][key][0]+=1.
            with self.assertRaises(ValueError):checks.refusal_join(bad,row,last,([],[]),[1.]*8)
        with self.assertRaises(ValueError):refusal_receipt(row,data,"reach_hold")

    def test_11_refusal_cannot_be_completion(self):
        r=dict(completed=False,outer_rows=62,internal_rows=305,controller_closed=True,
            status="controller_refusal",terminal_refusal=dict(command=61))
        self.assertEqual(checks.outcome(r,self.c,"predictive_hold"),(62,305))
        for change in (dict(completed=True),dict(internal_rows=310),dict(outer_rows=63),dict(terminal_refusal=None)):
            with self.assertRaises(ValueError):checks.outcome(dict(r,**change),self.c,"predictive_hold")

    def test_12_opened_unopened_population(self):
        population=task.plans(self.c)
        rows=[dict(population[0],completed=True),dict(population[1],completed=False,status="controller_refusal")]
        w=dict(ok=True,synthetic=False,trials=rows,constructed_cpu_worlds=2,constructed_model_count=2,
            constructed_gpu_worlds=0,unopened_trials=[p["trial_id"] for p in population[2:]],execution_complete=False,
            status="retained_controller_refusal",**{k:False for k in task.FLAGS})
        self.assertEqual(checks.worker_population(w,population,task.FLAGS),2)
        for change in (dict(constructed_cpu_worlds=4),dict(execution_complete=True),dict(unopened_trials=[])):
            with self.assertRaises(ValueError):checks.worker_population(dict(w,**change),population,task.FLAGS)

    def pairs(self,mutation=None,baseline=False):
        def row(i):return dict(native_observation=dict(step=i),stability=i,kinematics=i,composition=i,
            output=i,native_targets=[float(i)],request=dict(state=dict(step=i)))
        left=[row(i) for i in range(1440)];right=copy.deepcopy(left)
        a=[dict(step=i+1,value=float(i)) for i in range(7200)];b=copy.deepcopy(a)
        if mutation:mutation(right,b)
        def reader(path):
            candidate=path.parent.name=="candidate"
            return iter((right if candidate else left) if path.name=="controller.jsonl" else (b if candidate else a))
        with patch.object(checks,"read_jsonl",side_effect=reader):
            return (checks.compare_baseline if baseline else checks.compare_pair)(Path("reference"),Path("candidate"),self.c)

    def test_13_prefix_allows_new_trajectory(self):
        self.assertFalse(self.pairs(lambda c,t:(c[61].update(output=-1),t[300].update(value=-1)))["post_handoff_equality_required"])

    def test_14_crossed_or_missing_prefix(self):
        for mutation in (lambda c,t:c[59].update(output=-1),lambda c,t:t[299].update(value=-1),
            lambda c,t:c[60].update(native_observation={"step":-1}),lambda c,t:c.__delitem__(slice(60,None))):
            with self.assertRaises(ValueError):self.pairs(mutation)

    def test_15_full_baseline_regression(self):
        self.assertEqual(self.pairs(baseline=True)["trace_rows_identical"],7200)
        for mutation in (lambda c,t:c[-1].update(output=-1),lambda c,t:t[-1].update(value=-1),lambda c,t:t.pop()):
            with self.assertRaises(ValueError):self.pairs(mutation,True)

    def native_fixture(self):
        parent=task.read(task.PARENT_CLOSURE)
        folder=task.ROOT.parent/"SporeSpore_Evidence"/parent["attempt_id"]/"physical/reach_hold_left_075_train_001"
        row=next(read_jsonl(folder/"trace.jsonl"));control=next(read_jsonl(folder/"controller.jsonl"))
        spec=task.read(folder/"inputs.json");profile=task.read(folder/"force-profile.json")
        initial=task.initial_arrays(spec,task.plans(self.c)[0])
        return row,control,spec,profile,initial

    def native_check(self,row,fixture):
        _,control,spec,profile,initial=fixture
        return checks.native_step(row,1,control,None,initial,spec,self.c,profile)

    def test_16_native_continuity(self):
        fixture=self.native_fixture();row=fixture[0]
        self.assertLessEqual(self.native_check(row,fixture),1e-10)
        for key in ("before_qpos","before_qvel","ctrl"):
            bad=copy.deepcopy(row);bad[key][0]+=.1
            with self.assertRaises(ValueError):self.native_check(bad,fixture)

    def test_17_force_and_caps(self):
        fixture=self.native_fixture();row=fixture[0]
        for edit in (lambda r:r["actuator_force_nm"].__setitem__(0,999.),
            lambda r:r["joint_force_nm"].__setitem__(0,999.),lambda r:r["on_force_cap"].__setitem__(0,not r["on_force_cap"][0])):
            bad=copy.deepcopy(row);edit(bad)
            with self.assertRaises(ValueError):self.native_check(bad,fixture)

    def test_18_contact_clock_and_capacity(self):
        fixture=self.native_fixture();row=fixture[0]
        for change in (dict(time_s=1.),dict(batch_contacts=row["batch_contacts"]+1),dict(overflow=1),dict(nefc=-1)):
            with self.assertRaises(ValueError):self.native_check(dict(row,**change),fixture)

    def test_19_refusal_timing(self):
        row=dict(outer_step=61,measured=True,transfer_performed=False,outer_total_s=1.,**{k:0. for k in SECTIONS})
        checks.timing_row(row,61,False)
        for change in (dict(transfer_performed=True),dict(integration_and_device_history_s=.1),dict(outer_total_s=float("nan"))):
            with self.assertRaises(ValueError):checks.timing_row(dict(row,**change),61,False)

    @classmethod
    def selected_fixture(cls):
        if not hasattr(cls,"public_fixture"):
            from test_predictive_public_audit_v1 import PredictiveReaderControls
            PredictiveReaderControls.setUpClass()
            cls.public_fixture=(PredictiveReaderControls.rows[60],PredictiveReaderControls.reference)
        return cls.public_fixture

    def test_20_selected_reference(self):
        row,reference=self.selected_fixture()
        self.assertLessEqual(selected_reference(row,reference)["maximum_position_error"],1e-10)

    def test_21_forecast_and_objective_corruption(self):
        original,reference=self.selected_fixture()
        for kind in ("cost","force"):
            row=copy.deepcopy(original);selection=row["force_reference"]["decision"]["selection"]
            selected=selection["candidates"][selection["selected_index"]]
            if kind=="cost":selected["objective"]["total"]+=1.
            else:selected["forecast"]["rows"][0]["prediction"]["actuator_force"][0]+=.1
            with self.assertRaises(ValueError):selected_reference(row,reference)

    def test_22_zero_world_runtime(self):
        result=preflight(Path(os.environ["QUADRUPED_TEST_CORE"]),Path(os.environ["PORTABLE_BATCH_BASELINE_CORE"]))
        self.assertEqual(result["world_build_count"],0);self.assertEqual(result["solver_steps"],0)
        self.assertEqual(len(result["profiles"]),4);self.assertTrue(result["component_evidence_verified"])

    def test_23_stream_bounds(self):
        c=dict(maximum_trace_bytes_per_trial=50,maximum_controller_row_bytes=10);path=Path("synthetic")
        with patch.object(Path,"stat",return_value=SimpleNamespace(st_size=12)):
            with patch.object(Path,"open",return_value=io.BytesIO(b'{"a":1}\n')):
                self.assertEqual(list(bounded_rows(path,c)),[dict(a=1)])
            for value in (b'{"a":123456789}\n',b'{"a":1}'):
                with patch.object(Path,"open",return_value=io.BytesIO(value)):
                    with self.assertRaises(ValueError):list(bounded_rows(path,c))

    def test_24_unknown_role(self):
        with self.assertRaises(ValueError):task.profile_for("crossed",None,None,None)
        with self.assertRaises(ValueError):task.controller_for("crossed",None,None,None,None,None,None)


if __name__=="__main__":unittest.main()

