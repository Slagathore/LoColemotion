"""Launch refusal, control-transfer and pair-denominator controls; zero worlds."""
import copy
import os
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import numpy as np
import recovery_hold_native_task as task
from recovery_hold_native import transfer_targets,preflight
from audit_recovery_hold_native import compare_prefix,handoff_summary


class NativeRouteControls(unittest.TestCase):
    def setUp(self):
        self.c=task.declaration();self.source="0"*40;self.attempt="sdk2-recovery-hold-native-synthetic"
        self.owner=dict(source_commit=self.source,contract=self.c,planned_trials=task.plans(self.c),
            source_status=[],component_only=False,**{k:False for k in task.FLAGS})
        self.gate=dict(ok=True,source_commit=self.source,declaration_sha256="declaration",
            safety_controls={**{n:k for n,_,k in task.GATES},"provider":2,"containment":1},
            preflight=dict(ok=True,world_build_count=0,solver_steps=0))
        self.consumed=dict(attempt_id=self.attempt,source_commit=self.source,contract_sha256=task.sha(task.CONTRACT),
            declaration_sha256="declaration",gate_receipt_sha256="gate",trials=task.plans(self.c))

    def validate(self):
        task.validate_launch_documents(self.owner,self.gate,self.consumed,self.c,self.source,self.attempt,"declaration","gate")

    def test_complete_launch_documents(self):
        self.validate();self.assertEqual(sum(self.gate["safety_controls"].values()),453)

    def test_exposed_four_world_population_and_no_reserved_starts(self):
        plans=task.plans(self.c)
        self.assertEqual(len(plans),4);self.assertEqual(len({p["trial_id"] for p in plans}),4)
        self.assertTrue(all(p["start_id"]=="train_001" and p["seed"]==104242001 for p in plans))
        for change in (dict(groups=["left_075_train_002","nominal_train_001"]),dict(roles=["force_hold"]*2)):
            with self.assertRaises(ValueError):task.plans(dict(self.c,**change))

    def test_dirty_source_refuses_launch(self):
        self.owner["source_status"]=[" M sdk/example.py"]
        with self.assertRaises(ValueError):self.validate()

    def test_component_only_cannot_launch(self):
        self.owner["component_only"]=True
        with self.assertRaises(ValueError):self.validate()

    def test_missing_control_gate_refuses_launch(self):
        del self.gate["safety_controls"]["policy"]
        with self.assertRaises(ValueError):self.validate()

    def test_consumed_attempt_or_digest_cannot_be_reused(self):
        for field in ("attempt_id","source_commit","contract_sha256","gate_receipt_sha256"):
            old=self.consumed[field];self.consumed[field]="crossed"
            with self.assertRaises(ValueError):self.validate()
            self.consumed[field]=old

    def test_terminal_error_prevents_native_control_transfer(self):
        for key in ("residual","force_reference"):
            data=SimpleNamespace(ctrl=np.ones(8))
            with self.assertRaises(ValueError):transfer_targets({key:dict(terminal_error={"type":"Failure"}),"native_targets":[0.]*8},data)
            np.testing.assert_array_equal(data.ctrl,np.ones(8))
            transfer_targets({key:dict(terminal_error=None),"native_targets":[0.]*8},data)
            np.testing.assert_array_equal(data.ctrl,np.zeros(8))

    def test_unknown_controller_role_refused_before_session(self):
        with self.assertRaises(ValueError):task.controller_for("crossed",None,None,None,None,None,None)

    def test_total_target_transition_is_not_relabelled_residual_slew(self):
        def row(b,r):return dict(resolution=dict(ordered_commands=[dict(actuator_id="a",baseline_canonical_target_velocity_rad_s=b,
            applied_correction_rad_s=r,final_canonical_target_velocity_rad_s=b+r)]))
        rows=[row(0.,1.) for _ in range(60)]+[row(2.,.92) for _ in range(60)]
        value=handoff_summary(rows)
        self.assertAlmostEqual(value["at_handoff"]["correction_delta_rad_s"][0],-.08)
        self.assertAlmostEqual(value["at_handoff"]["target_delta_rad_s"][0],1.92)
        self.assertFalse(value["total_target_slew_guaranteed"])
        with self.assertRaises(ValueError):handoff_summary(rows[:-1])

    def pair(self,mutation=None):
        fields=("native_observation","stability","kinematics","composition","output","native_targets")
        controls=[dict({k:[i] for k in fields},request=dict(state=[i])) for i in range(120)]
        traces=[dict(step=i+1,qpos=[float(i)]) for i in range(600)]
        other_controls=copy.deepcopy(controls);other_traces=copy.deepcopy(traces)
        if mutation:mutation(other_controls,other_traces)
        def reader(path):
            candidate=path.parent.name=="candidate"
            return (other_controls if candidate else controls) if path.name=="controller.jsonl" else (other_traces if candidate else traces)
        with patch("audit_recovery_hold_native.read_jsonl",side_effect=reader):
            return compare_prefix(Path("reference"),Path("candidate"),self.c)

    def test_prefix_change_or_missing_rows_refuses_pair(self):
        for mutate in (lambda c,t:t[299].update(qpos=[-1.]),lambda c,t:c[59].update(native_targets=[-1.]),
            lambda c,t:c[60].update(native_observation=[-1.]),lambda c,t:t.pop()):
            with self.assertRaises(ValueError):self.pair(mutate)

    def test_post_handoff_changes_are_not_suppressed(self):
        result=self.pair(lambda c,t:(t[300].update(qpos=[-1.]),c[60].update(native_targets=[-1.])))
        self.assertFalse(result["post_handoff_equality_required"])

    def test_runtime_preflight_opens_no_world(self):
        result=preflight(Path(os.environ["QUADRUPED_TEST_CORE"]),Path(os.environ["PORTABLE_BATCH_BASELINE_CORE"]))
        self.assertEqual(result["world_build_count"],0);self.assertEqual(result["solver_steps"],0)
        self.assertEqual(result["contact_sample_rows"],2400)


if __name__=="__main__":unittest.main()
