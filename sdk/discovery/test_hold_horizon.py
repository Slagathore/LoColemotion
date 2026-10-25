"""Horizon scope, full temporal integration and geometry controls; zero worlds."""
import copy
from contextlib import ExitStack
import hashlib
import json
import math
import os
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import mujoco
import numpy as np
import hold_horizon_task as task
from hold_horizon_native import preflight
from recovery_hold_native import transfer_targets
from causal_force_control import terminal_error
from causal_force_policy import make_profile
from audit_hold_horizon import compare_prefix
from audit_gpu_batch_execution import read_jsonl,same_bits


class HorizonControls(unittest.TestCase):
    def setUp(self):
        self.c=task.declaration();self.source="0"*40;self.attempt="sdk2-hold-horizon-synthetic"
        self.owner=dict(source_commit=self.source,contract=self.c,planned_trials=task.plans(self.c),
            source_status=[],component_only=False,**{k:False for k in task.FLAGS})
        self.gate=dict(ok=True,source_commit=self.source,declaration_sha256="declaration",
            safety_controls={**{n:k for n,_,k in task.GATES},"provider":2,"containment":1},
            preflight=dict(ok=True,world_build_count=0,solver_steps=0,parent_reconstruction_verified=True))
        self.consumed=dict(attempt_id=self.attempt,source_commit=self.source,contract_sha256=task.sha(task.CONTRACT),
            declaration_sha256="declaration",gate_receipt_sha256="gate",trials=task.plans(self.c))

    def validate(self):
        task.validate_launch_documents(self.owner,self.gate,self.consumed,self.c,self.source,self.attempt,"declaration","gate")

    def test_complete_launch_documents(self):
        self.validate();self.assertEqual(sum(self.gate["safety_controls"].values()),479)

    def test_two_fresh_exposed_worlds_and_exact_horizon(self):
        plans=task.plans(self.c);self.assertEqual(len(plans),2);self.assertEqual(len({p["trial_id"] for p in plans}),2)
        self.assertTrue(all(p["role"]=="force_hold" and p["start_id"]=="train_001" and p["seed"]==104242001 for p in plans))
        self.assertEqual(self.c["outer_steps"],1440);self.assertEqual(self.c["horizon_s"],12.)

    def test_changed_horizon_roles_or_starts_refused(self):
        for change in (dict(outer_steps=1441),dict(horizon_s=1.),dict(roles=["force_walk"]),
            dict(groups=["left_075_train_002","nominal_train_001"]),dict(planned_cpu_worlds=4)):
            with self.assertRaises(ValueError):task.plans(dict(self.c,**change))

    def test_dirty_source_refuses_launch(self):
        self.owner["source_status"]=[" M unexpected.py"]
        with self.assertRaises(ValueError):self.validate()

    def test_component_only_cannot_launch(self):
        self.owner["component_only"]=True
        with self.assertRaises(ValueError):self.validate()

    def test_missing_gate_or_unverified_parent_refuses_launch(self):
        self.gate["preflight"]["parent_reconstruction_verified"]=False
        with self.assertRaises(ValueError):self.validate()
        self.gate["preflight"]["parent_reconstruction_verified"]=True
        del self.gate["safety_controls"]["hold-horizon"]
        with self.assertRaises(ValueError):self.validate()

    def test_consumed_identity_and_digests_cannot_be_reused(self):
        for key in ("attempt_id","source_commit","contract_sha256","gate_receipt_sha256"):
            value=self.consumed[key];self.consumed[key]="crossed"
            with self.assertRaises(ValueError):self.validate()
            self.consumed[key]=value

    def test_terminal_provider_row_prevents_transfer(self):
        data=SimpleNamespace(ctrl=np.ones(8))
        with self.assertRaises(ValueError):transfer_targets(dict(force_reference=dict(terminal_error={"type":"failure"}),native_targets=[0.]*8),data)
        np.testing.assert_array_equal(data.ctrl,np.ones(8))

    def pair(self,mutation=None):
        controls=[dict(step=i,value=float(i)) for i in range(1440)]
        traces=[dict(step=i+1,value=float(i)) for i in range(7200)]
        old_controls=copy.deepcopy(controls[:120]);old_trace=copy.deepcopy(traces[:600])
        if mutation:mutation(controls,traces)
        def reader(path):
            candidate=path.parent.name=="candidate"
            return (controls if candidate else old_controls) if path.name=="controller.jsonl" else (traces if candidate else old_trace)
        with patch("audit_hold_horizon.read_jsonl",side_effect=reader):return compare_prefix(Path("reference"),Path("candidate"),self.c)

    def test_changed_or_incomplete_historical_prefix_refused(self):
        for mutate in (lambda c,t:c[119].update(value=-1.),lambda c,t:t[599].update(value=-1.),lambda c,t:c.pop(),lambda c,t:t.pop()):
            with self.assertRaises(ValueError):self.pair(mutate)

    def test_later_states_are_fresh_not_constrained_to_original(self):
        result=self.pair(lambda c,t:(c[120].update(value=-1.),t[600].update(value=-1.)))
        self.assertTrue(result["new_trajectory_is_fresh"]);self.assertFalse(result["cached_physical_state_used"])

    def test_real_runtime_preflight_opens_no_world(self):
        result=preflight(Path(os.environ["QUADRUPED_TEST_CORE"]),Path(os.environ["PORTABLE_BATCH_BASELINE_CORE"]))
        self.assertEqual(result["world_build_count"],0);self.assertEqual(result["solver_steps"],0)
        self.assertTrue(result["parent_reconstruction_verified"])
        self.assertEqual(result["planned_cpu_worlds"],2);self.assertEqual(result["contact_sample_rows"],14400)

    def test_full_supported_clock_both_cores_and_terminal_boundary(self):
        record=task.read(task.PARENT_CLOSURE)
        folder=task.ROOT.parent/"SporeSpore_Evidence"/record["attempt_id"]/"physical/force_hold_left_075_train_001"
        compiled=task.read(folder/"compiled.json");profile=make_profile(compiled,task.read(folder/"inputs.json"))
        originals=list(read_jsonl(folder/"controller.jsonl"));digests=[]
        with ExitStack() as guards:
            for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
                guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Synthetic clock opens no world")))
            for env in ("QUADRUPED_TEST_CORE","PORTABLE_BATCH_BASELINE_CORE"):
                core=task.bridge.LocomotionCore(Path(os.environ[env]));model=task.frozen_model(core)
                host=task.controller_for("force_hold",core,compiled,self.c,model,"force_hold_left_075_train_001",profile)
                digest=hashlib.sha256()
                try:
                    for step in range(1440):
                        old=originals[min(step,119)];state=copy.deepcopy(old["request"]["state"]);stability=copy.deepcopy(old["stability"])
                        state.update(semantic_step=step,sample_time_s=step*self.c["controller_dt_s"]);stability["semantic_step"]=step
                        previous=list(host.previous);row=host.step(state,stability,copy.deepcopy(old["kinematics"]))
                        self.assertIsNone(terminal_error(row));self.assertEqual(host.next_step,step+1)
                        if step<120:self.assertTrue(all(same_bits(value,old[key]) for key,value in row.items()),f"Original prefix differs at command {step}")
                        for i,command in enumerate(row["resolution"]["ordered_commands"]):
                            self.assertLessEqual(abs(command["final_canonical_target_velocity_rad_s"]),3.5)
                            if step>=60:self.assertLessEqual(abs(command["applied_correction_rad_s"]-previous[i]),.08+1e-12)
                        digest.update(json.dumps(row,sort_keys=True,separators=(",",":"),allow_nan=False).encode()+b"\n")
                    self.assertEqual(host.force_memory["sequence"],1380)
                    state["semantic_step"]=1440;state["sample_time_s"]=12.;stability["semantic_step"]=1440
                    data=SimpleNamespace(ctrl=np.ones(8))
                    try:row=host.step(state,stability,copy.deepcopy(originals[-1]["kinematics"]))
                    except ValueError:pass
                    else:
                        self.assertIsNotNone(terminal_error(row))
                        with self.assertRaises(ValueError):transfer_targets(row,data)
                    self.assertTrue(host.closed);np.testing.assert_array_equal(data.ctrl,np.ones(8))
                finally:host.close()
                digests.append(digest.hexdigest())
        self.assertEqual(digests[0],digests[1])
        print(json.dumps(dict(synthetic=True,unique_commands=1440,core_reconstructions=2,controller_sha256=digests[0],
            final_supported_command=1439,terminal_command_1440_refused=True,worlds_opened=0,alternative_actions_generated_observations=False)))

    def test_capsule_plane_clearance_translation_and_rotation(self):
        endpoints=[0.,0.,-1.,0.,0.,1.]
        self.assertAlmostEqual(task.capsule_clearance([0.,0.,2.],np.eye(3),endpoints,.1),.9)
        rotation=[[0.,0.,1.],[0.,1.,0.],[-1.,0.,0.]]
        self.assertAlmostEqual(task.capsule_clearance([0.,0.,2.],rotation,endpoints,.1),1.9)

    def test_invalid_capsule_geometry_refused(self):
        for position,rotation,endpoints,radius in (([0.,0.,0.],np.eye(3),[0.]*6,-1.),
            ([float("nan"),0.,0.],np.eye(3),[0.]*6,.1),([0.,0.,0.],np.zeros((3,3)),[0.]*6,.1)):
            with self.assertRaises(ValueError):task.capsule_clearance(position,rotation,endpoints,radius)


if __name__=="__main__":unittest.main()
