"""Analytical and corruption controls for retained-data recovery measurements."""
import copy
from contextlib import ExitStack
import hashlib
import json
import os
from pathlib import Path
import unittest

import residual_recovery_diagnostic as audit
from residual_recovery_diagnostic import metrics as m
from audit_gpu_batch_execution import read_jsonl


class DiagnosticControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.guards=ExitStack();cls.addClassCleanup(cls.guards.close)
        cls.guards.enter_context(audit.no_physics())
        cls.evidence=audit.ROOT.parent/"SporeSpore_Evidence"
        cls.parent=audit.read(audit.CLOSURE);cls.attempts=audit.parent.header(cls.parent,cls.evidence)
        cls.out=Path(os.environ["EXPLORER_TEST_OUTPUT"])
        cls.stage=cls.attempts["route"]/"stages/iteration_00"
        cls.audited=audit.read(cls.stage/"audit.json")
        cls.plan=audit.parent.task.trial_plans(audit.parent.task.declaration("route"),"iteration_00")
        cls.raw=[];cls.frames=[]
        for plan in cls.plan[:2]:
            raw=list(read_jsonl(cls.stage/"physical"/plan["trial_id"]/"controller.jsonl"))
            frames=[];previous=None
            for i,row in enumerate(raw):
                previous=m.frame(row,previous,i);frames.append(previous)
            cls.raw.append(raw);cls.frames.append(frames)
        cls.trial=cls.stage/"physical"/cls.plan[0]["trial_id"]
        cls.spec=audit.read(cls.trial/"inputs.json");cls.native=audit.read(cls.trial/"native-model.json")
        cls.gains,cls.caps=m.motor_profile(cls.native,cls.spec)
        cls.trace=list(read_jsonl(cls.trial/"trace.jsonl"))
        cls.selection=audit.parent.task.declaration("route")["selection"]
        cls.failure=cls.audited["trials"][0]["first_reward_failure"]

    def test_01_known_convex_geometry(self):
        points=[[0.,0.],[2.,0.],[2.,2.],[0.,2.]]
        value=m.support_geometry([1.,1.],points)
        self.assertEqual(value["signed_interior_margin_m"],1.)
        self.assertEqual(value["com_projection_distance_to_support_hull_m"],0.)
        outside=m.support_geometry([3.,1.],points)
        self.assertEqual(outside["signed_interior_margin_m"],-1.)
        self.assertEqual(outside["com_projection_distance_to_support_hull_m"],1.)
        self.assertFalse(outside["force_feasibility_established"])

    def test_02_degenerate_support_has_no_interior_margin(self):
        for points in ([],[[0.,0.]],[[0.,0.],[2.,0.]],[[0.,0.],[1.,0.],[2.,0.],[1.,0.]]):
            value=m.support_geometry([1.,1.],points)
            self.assertIsNone(value["signed_interior_margin_m"])
        self.assertEqual(m.support_geometry([1.,1.],[[0.,0.],[2.,0.]])["com_projection_distance_to_support_hull_m"],1.)
        with self.assertRaises(ValueError):m.support_geometry([float("nan"),0.],[])

    def test_03_clock_history_and_native_join_refuse(self):
        for change in (
            lambda v:v.__setitem__("outer_step",2),
            lambda v:v["resolution_request"]["provider_request"]["history"]["ordered_entries"].clear(),
            lambda v:v["native_targets"].__setitem__(0,99.),
            lambda v:v["native_observation"]["qvel"].__setitem__(6,99.),
            lambda v:v["resolution_request"]["provider_request"]["safety_envelope"]["ordered_actuator_limits"][0].__setitem__("previous_applied_correction_rad_s",99.)):
            row=copy.deepcopy(self.raw[0][1]);change(row)
            with self.subTest(change=change),self.assertRaises(ValueError):m.frame(row,self.frames[0][0],1)

    def test_04_missing_contact_loads_remain_unavailable(self):
        frame=self.frames[0][1]
        self.assertEqual(frame["normal_load_n"],[None]*4)
        for change in (
            lambda v:v["stability"]["ordered_support_contacts"][0].__setitem__("presence",False),
            lambda v:v["request"]["state"]["ordered_contact_observations"][0].__setitem__("normal_load_n",-1.),
            lambda v:v["resolution"]["ordered_commands"][0].__setitem__("slew_clamped",1)):
            row=copy.deepcopy(self.raw[0][1]);change(row)
            with self.subTest(change=change),self.assertRaises(ValueError):m.frame(row,self.frames[0][0],1)

    def test_05_affine_native_profile_and_transmission_refuse(self):
        for key,value in (("gear",[[2.,0.,0.,0.,0.,0.]]*8),("dyntype",[1]*8),
                ("ctrllimited",[True]*8),("gainprm",[[1.]*10]*8),("forcelimited",[False]*8)):
            native=copy.deepcopy(self.native);native["actuator_profile"][key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):m.motor_profile(native,self.spec)
        native=copy.deepcopy(self.native);native["force_stage"]="post_integrated_state"
        with self.assertRaises(ValueError):m.motor_profile(native,self.spec)

    def test_06_analytical_affine_clipping_and_sign(self):
        # A pure algebra fixture: this is not a simulated dynamics trajectory.
        row=dict(ctrl=[2.,-2.,.25,0.,2.,-2.,.25,0.],before_qvel=[0.]*14,
            actuator_force_nm=[1.,-1.,.5,0.]*2,joint_force_nm=[1.,-1.,.5,0.]*2,
            on_force_cap=[True,True,False,False]*2)
        forces,labels,error=m.force_sample(row,[2.]*8,[[-1.,1.]]*8)
        self.assertEqual(forces,[1.,-1.,.5,0.]*2);self.assertEqual(error,0.)
        self.assertEqual(labels,[True,True,False,False]*2)

    def test_07_post_integrated_velocity_cannot_relabel_retained_force(self):
        row=next(r for r in self.trace if r["before_qvel"]!=r["qvel"])
        value=copy.deepcopy(row);value["before_qvel"]=list(value["qvel"])
        with self.assertRaises(ValueError):m.force_sample(value,self.gains,self.caps)
        value=copy.deepcopy(row);value["actuator_force_nm"][0]+=.001;value["joint_force_nm"][0]+=.001
        with self.assertRaises(ValueError):m.force_sample(value,self.gains,self.caps)
        value=copy.deepcopy(row);value["on_force_cap"][0]=not value["on_force_cap"][0]
        with self.assertRaises(ValueError):m.force_sample(value,self.gains,self.caps)

    def test_08_raw_stream_digest_truncation_append_and_reordering_refuse(self):
        folder=self.out/"stream-controls";folder.mkdir()
        raw=b'{"i":0}\n{"i":1}\n';path=folder/"rows.jsonl"
        index={"rows.jsonl":dict(path="rows.jsonl",sha256=hashlib.sha256(raw).hexdigest(),byte_length=len(raw))}
        path.write_bytes(raw)
        self.assertEqual(list(audit.bound_jsonl(folder,"rows.jsonl",index)),[dict(i=0),dict(i=1)])
        for bad in (b'{"i":0}\n',raw+b'{"i":2}\n',b'{"i":1}\n{"i":0}\n'):
            path.write_bytes(bad)
            with self.assertRaises(ValueError):list(audit.bound_jsonl(folder,"rows.jsonl",index))
        path.write_bytes(raw)

    def test_09_complete_trial_population_order_and_horizon_refuse(self):
        rows=self.audited["trials"];audit.validate_population(rows,self.plan,120)
        for change in (lambda v:v.pop(),lambda v:v.reverse(),lambda v:v.append(v[0]),
                lambda v:v[0].__setitem__("controller_rows",119),
                lambda v:v[0].__setitem__("internal_rows",599)):
            value=copy.deepcopy(rows);change(value)
            with self.assertRaises(ValueError):audit.validate_population(value,self.plan,120)

    def test_10_complete_native_trace_and_original_failure_required(self):
        def run(rows,failure):
            return m.trace_measurements(rows,self.frames[0],failure,self.selection,self.gains,self.caps)
        result=run(self.trace,self.failure)
        self.assertEqual(result["internal_samples"],600)
        self.assertEqual(result["windows"]["before_failure"]["count"],self.failure["internal_step"]-1)
        self.assertFalse(result["normal_contact_forces_retained"])
        with self.assertRaises(ValueError):run(self.trace[:-1],self.failure)
        failure=dict(self.failure,internal_step=self.failure["internal_step"]+1)
        with self.assertRaises(ValueError):run(self.trace,failure)
        rows=copy.deepcopy(self.trace);rows[5]["before_qpos"][0]+=.001
        with self.assertRaises(ValueError):run(rows,self.failure)

    def test_11_common_window_and_censoring_cannot_hide_early_failure(self):
        result=m.summarize_frames(self.frames[0],self.failure)
        self.assertEqual(result["windows"]["common_handoff_window"]["controller_rows"],20)
        self.assertEqual(result["windows"]["common_handoff_window"]["unavailable_normal_load_values"],80)
        self.assertEqual(result["windows"]["before_failure"]["controller_rows"],101)
        self.assertFalse(result["terminal_is_horizon_censored"])
        censored=m.summarize_frames(self.frames[0],None)
        self.assertTrue(censored["terminal_is_horizon_censored"])
        self.assertEqual(censored["snapshots"]["last_pre_failure_or_horizon"]["step"],119)
        with self.assertRaises(ValueError):m.summarize_frames(self.frames[0],dict(self.failure,internal_step=400))

    def test_12_fresh_reference_prefix_cannot_be_substituted(self):
        value=m.paired_frames(self.frames[1],self.frames[0],self.plan[1],self.plan[0])
        self.assertTrue(value["identical_through_handoff_observation"])
        frames=copy.deepcopy(self.frames[1]);frames[60]["qpos"][0]+=.001
        with self.assertRaises(ValueError):m.paired_frames(frames,self.frames[0],self.plan[1],self.plan[0])
        frames=copy.deepcopy(self.frames[1]);frames[59]["targets"][0]+=.001
        with self.assertRaises(ValueError):m.paired_frames(frames,self.frames[0],self.plan[1],self.plan[0])
        plan=dict(self.plan[0],group_id="foreign")
        with self.assertRaises(ValueError):m.paired_frames(self.frames[1],self.frames[0],self.plan[1],plan)

    def test_13_identity_source_window_and_authority_cannot_be_promoted(self):
        record=audit.fixed_header("a"*64);audit.validate_header(record,"a"*64)
        for key in audit.DENIALS:
            value=copy.deepcopy(record);value[key]=True
            with self.subTest(key=key),self.assertRaises(ValueError):audit.validate_header(value,"a"*64)
        for key,value in (("parent_closure_sha256","0"*64),("parent_reconstruction_sha256","0"*64),
                ("source_bindings",{}),("window_definition",{}),("reader_solver_steps",1)):
            changed=copy.deepcopy(record);changed[key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):audit.validate_header(changed,"a"*64)

    def test_14_complete_parent_reconstruction_required(self):
        # This fixture tests the metadata gate. The owner reruns the full parent reader separately.
        result=dict(ok=True,closure_sha256=audit.PARENT_SHA,source_commit=self.parent["source_commit"],
            original_counts=audit.TOTALS,reader_world_build_count=0,reader_solver_steps=0,
            raw_rewards_moments_quality_and_comparison_recomputed=True,
            all_updates_and_training_selection_reconstructed=True,fresh_challenge_prefixes_recomputed=True,
            summaries={a["lane"]:a["summary"] for a in self.parent["attempts"]},
            **{k:False for k in audit.parent.DENIALS})
        audit.validate_parent(self.parent,result)
        for key,value in (("ok",False),("closure_sha256","0"*64),("original_counts",{}),
                ("reader_world_build_count",1),("all_updates_and_training_selection_reconstructed",False),
                ("summaries",{}),("safe_backup_established",True)):
            changed=copy.deepcopy(result);changed[key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):audit.validate_parent(self.parent,changed)

    def test_15_physics_entrypoints_are_guarded(self):
        for name in audit.PHYSICS:
            with self.subTest(name=name),self.assertRaises(AssertionError):getattr(audit.mujoco,name)()

    def test_16_final_speed_projection_is_not_the_resolved_correction(self):
        # Synthetic resolver measurement fixture, preserving the observed past-action join.
        row=copy.deepcopy(self.raw[0][1]);command=row["resolution"]["ordered_commands"][0]
        command.update(baseline_canonical_target_velocity_rad_s=3.45,proposed_correction_rad_s=.2,
            applied_correction_rad_s=.08,final_canonical_target_velocity_rad_s=3.5,final_speed_clamped=True)
        row["resolution_request"]["provider_request"]["deterministic_baseline"]["ordered_commands"][0]["combined_canonical_target_velocity_rad_s"]=3.45
        row["native_targets"][0]=3.5
        frame=m.frame(row,self.frames[0][0],1)
        self.assertEqual(frame["resolved"][0],.08)
        self.assertAlmostEqual(frame["delivered"][0],.05)
        self.assertNotEqual(frame["resolved"][0],frame["delivered"][0])


if __name__=="__main__":unittest.main()
