"""Prospective zero-world scope, refusal and corruption controls."""
import copy
import io
import itertools
import json
import os
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import numpy as np
import contact_sequence_native_task_v2 as task
import contact_sequence_native_checks_v1 as checks
from contact_sequence_native_trial_v2 import transfer_targets,refusal_receipt
from contact_sequence_native_trial_audit_v2 import bounded_rows,selected_reference,applied_forecast,selection_counts
from contact_sequence_native_capture_v1 import append as append_capture
from contact_sequence_native_v2 import preflight
from audit_gpu_batch_execution import read_jsonl,SECTIONS


class PredictiveNativeControls(unittest.TestCase):
    def setUp(self):
        self.c=task.declaration();self.source="0"*40;self.attempt="sdk2-contact-sequence-native-v2-synthetic"
        self.owner=dict(source_commit=self.source,contract=self.c,planned_trials=task.plans(self.c),
            source_status=[],component_only=False,**{k:False for k in task.FLAGS})
        self.gate=dict(ok=True,source_commit=self.source,declaration_sha256="declaration",
            safety_controls={**{n:k for n,_,k in task.GATES},"provider":2,"containment":1},
            preflight=dict(ok=True,world_build_count=0,solver_steps=0,component_evidence_verified=True,gate_coverage_verified=True,
                lifecycle_evidence_verified=True,lifecycle_evidence=dict(predecessors=copy.deepcopy(task.PREDECESSORS))))
        self.consumed=dict(attempt_id=self.attempt,source_commit=self.source,contract_sha256=task.sha(task.CONTRACT),
            declaration_sha256="declaration",gate_receipt_sha256="gate",trials=task.plans(self.c))

    def validate(self):
        task.validate_launch_documents(self.owner,self.gate,self.consumed,self.c,self.source,self.attempt,"declaration","gate")

    def test_01_complete_gate(self):
        self.validate();self.assertEqual(sum(self.gate["safety_controls"].values()),1615)

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
        for name in ("prediction-predictive-policy","contact-sequence-native","contact-sequence-native-v2","contained-stage-lifecycle-v2","containment"):
            saved=self.gate["safety_controls"].copy()
            # Select the declared policy name without depending on its presentation label.
            key=next(n for n,m,_ in task.GATES if m=="test_predictive_hold_policy_v1") if "policy" in name else name
            del self.gate["safety_controls"][key]
            with self.assertRaises(ValueError):self.validate()
            self.gate["safety_controls"]=saved

    def test_06_preflight_false_or_physical(self):
        for change in (dict(component_evidence_verified=False),dict(gate_coverage_verified=False),dict(lifecycle_evidence_verified=False),dict(world_build_count=1)):
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
            from predictive_command_selection_v2 import PredictiveSelector
            from prepared_predictive_model import PreparedSelector
            root=task.ROOT.parent/"SporeSpore_Evidence"
            path=root/"sdk2-predictive-sequence-public-v3-4db025ca0ada47e5a7e801c7cd9fdb29"/"audit-capture/predictive_hold_left_075_train_001-core0.jsonl"
            with path.open("rb") as stream:
                stream.seek(max(0,path.stat().st_size-16*2**20));tail=stream.read()
            assert tail.endswith(b"\n")
            row=json.loads(tail.rstrip(b"\n").rsplit(b"\n",1)[-1])
            assert row["request"]["state"]["semantic_step"]==73
            original=root/"sdk2-predictive-native-v1-13374a22f25c4d089c34045c96ec64f7"/"physical/predictive_hold_left_075_train_001"
            compiled=task.read(original/"compiled.json");spec=task.read(original/"inputs.json")
            xml=(original/"model.xml").read_text(encoding="utf-8")
            profile=task.profile_for("predictive_hold",compiled,spec,xml)
            cls.public_fixture=(row,PreparedSelector(profile["prepared_model"],task.DLL,task.DLL_SHA),PredictiveSelector(profile["nominal_profile"],xml))
            cls.route_fixture=(compiled,spec,xml,profile)
        return cls.public_fixture

    def test_20_selected_reference(self):
        row,selector,reference=self.selected_fixture()
        self.assertLessEqual(selected_reference(row,selector,reference)["maximum_position_error"],1e-10)

    def test_21_forecast_and_objective_corruption(self):
        original,selector,reference=self.selected_fixture()
        for kind in ("cost","force"):
            row=copy.deepcopy(original);selection=row["force_reference"]["decision"]["selection"]
            self.assertEqual(selection["reason"],"warm_valid");self.assertEqual(len(selection["evaluations"]),1)
            first=selection["best"]["result"]["rows"][0]
            if kind=="cost":first["objective"]["total"]+=1.
            else:first["forecast"]["rows"][0]["prediction"]["actuator_force"][0]+=.1
            selection["evaluations"][0]=copy.deepcopy(selection["best"])
            with self.assertRaises(ValueError):selected_reference(row,selector,reference)

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

    def capture_contract(self):
        return dict(maximum_controller_row_bytes=100,maximum_trace_bytes_per_trial=100,
            maximum_attempt_stream_bytes=200)

    def test_25_aggregate_budget_across_streams(self):
        c=self.capture_contract();c["maximum_attempt_stream_bytes"]=15
        population=dict(retained_stream_bytes=0);a=io.StringIO();b=io.StringIO()
        append_capture(a,"controller",dict(a=1),c,population)
        self.assertEqual(population["retained_stream_bytes"],8)
        with self.assertRaises(ValueError):append_capture(b,"trace",dict(a=1),c,population)
        self.assertEqual(b.getvalue(),"");self.assertEqual(population["retained_stream_bytes"],8)

    def test_26_row_budget_refuses_before_write(self):
        c=self.capture_contract();c["maximum_controller_row_bytes"]=7
        population=dict(retained_stream_bytes=0);stream=io.StringIO()
        with self.assertRaises(ValueError):append_capture(stream,"controller",dict(a=1),c,population)
        self.assertEqual(stream.getvalue(),"");self.assertEqual(population["retained_stream_bytes"],0)

    def test_27_stream_budget_refuses_before_write(self):
        c=self.capture_contract();c["maximum_trace_bytes_per_trial"]=15
        population=dict(retained_stream_bytes=0);stream=io.StringIO()
        append_capture(stream,"controller",dict(a=1),c,population)
        with self.assertRaises(ValueError):append_capture(stream,"controller",dict(a=2),c,population)
        self.assertEqual(stream.getvalue(),'{"a":1}\n')
        self.assertEqual(population["retained_stream_bytes"],8)

    def test_28_capture_malformed_or_nonfinite_refused(self):
        for name,row,count in (("unknown",{},0),("trace",dict(a=float("nan")),0),("trace",{},True),("trace",{},-1)):
            stream=io.StringIO();population=dict(retained_stream_bytes=count)
            with self.assertRaises(ValueError):append_capture(stream,name,row,self.capture_contract(),population)
            self.assertEqual(stream.getvalue(),"");self.assertEqual(population["retained_stream_bytes"],count)

    def test_29_first_interval_requires_exact_applied_target(self):
        original,_,_=self.selected_fixture();forecast=applied_forecast(original)
        self.assertEqual(forecast["completed_steps"],5)
        for kind in ("target","offset","steps","refused"):
            row=copy.deepcopy(original);selection=row["force_reference"]["decision"]["selection"]
            first=selection["best"]["result"]["rows"][0]
            if kind=="target":first["target"][0]+=.01
            elif kind=="offset":first["offset"]=1
            elif kind=="steps":first["forecast"]["completed_steps"]=4
            else:selection["accepted"]=False
            with self.assertRaises(ValueError):applied_forecast(row)

    def test_30_future_interval_is_not_native_comparison(self):
        original,selector,reference=self.selected_fixture();row=copy.deepcopy(original)
        selection=row["force_reference"]["decision"]["selection"]
        selection["best"]["result"]["rows"][1]["forecast"]["rows"][0]["qpos"][0]+=.01
        selection["evaluations"][0]=copy.deepcopy(selection["best"])
        self.assertEqual(applied_forecast(row),applied_forecast(original))
        with self.assertRaises(ValueError):selected_reference(row,selector,reference)

    def test_31_production_host_uses_verified_sequence_policy(self):
        from predictive_contact_sequence_policy_v1 import Policy
        from predictive_sequence_online_v2 import HORIZON,REPLAN_INTERVAL
        from predictive_sequence_v1 import SEED
        self.selected_fixture();compiled,spec,xml,profile=self.route_fixture
        core=task.bridge.LocomotionCore(Path(os.environ["QUADRUPED_TEST_CORE"]))
        model=task.frozen_model(core)
        host=task.controller_for("predictive_hold",core,compiled,self.c,model,"sequence_native_fixture",profile)
        try:
            self.assertIsInstance(host.force_policy,Policy)
            self.assertEqual((HORIZON,REPLAN_INTERVAL,SEED),(66,12,20261026))
        finally:host.close()
        self.assertTrue(host.closed)

    def test_32_resource_contract_is_immutable_and_bounded(self):
        c=self.c
        self.assertLess(c["maximum_controller_row_bytes"],c["maximum_trace_bytes_per_trial"])
        self.assertLess(c["maximum_trace_bytes_per_trial"],c["maximum_attempt_stream_bytes"])
        self.assertLess(c["maximum_attempt_stream_bytes"],c["minimum_free_storage_bytes"])
        for key in ("maximum_attempt_stream_bytes","maximum_controller_row_bytes","maximum_worker_wall_seconds"):
            bad=copy.deepcopy(c);bad[key]+=1
            with patch.object(task,"read",return_value=bad):
                with self.assertRaises(ValueError):task.declaration()


    def binding_fixture(self):
        return dict(source={"a":"one"},runtime={"x":"same"},gpu="cpu")

    def test_33_binding_merge_preserves_scalar_and_inputs(self):
        from run_contact_sequence_native_v2 import merge_bindings
        left=self.binding_fixture();right=self.binding_fixture();right["source"]["b"]="two"
        before=copy.deepcopy((left,right));result=merge_bindings(left,right)
        self.assertEqual(result,dict(source={"a":"one","b":"two"},runtime={"x":"same"},gpu="cpu"))
        self.assertEqual((left,right),before)

    def test_34_binding_scalar_or_section_crossing_refused(self):
        from run_contact_sequence_native_v2 import merge_bindings
        for change in (dict(gpu="other"),dict(gpu={}),dict(source="other")):
            with self.assertRaises(ValueError):merge_bindings(self.binding_fixture(),dict(self.binding_fixture(),**change))
        right=self.binding_fixture();del right["runtime"]
        with self.assertRaises(ValueError):merge_bindings(self.binding_fixture(),right)

    def test_35_binding_overlap_conflicts_refused(self):
        from run_contact_sequence_native_v2 import merge_bindings
        for kind,key in (("source","a"),("runtime","x")):
            right=self.binding_fixture();right[kind][key]="different"
            with self.assertRaises(ValueError):merge_bindings(self.binding_fixture(),right)


    def test_36_predictor_roles_cannot_be_crossed(self):
        row,selector,reference=self.selected_fixture()
        for exact,independent in ((reference,reference),(selector,selector),(reference,selector)):
            with self.assertRaisesRegex(ValueError,"Sequence reader predictor roles"):
                selected_reference(row,exact,independent)




    @classmethod
    def contact_fixture(cls):
        if not hasattr(cls,"contact_public_fixture"):
            path=task.ROOT.parent/"SporeSpore_Evidence"/task.read(task.COMPONENT_RESULT)["attempt_id"]/"audit-capture/predictive_hold_left_075_train_001-core0.jsonl"
            row=None
            for value in bounded_rows(path,task.declaration()):row=value
            assert row["request"]["state"]["semantic_step"]==61
            assert row["force_reference"]["decision"]["selection"]["reason"]=="contact_priority"
            cls.contact_public_fixture=row
        return cls.contact_public_fixture

    def test_37_contact_native_reader_reconstructs_both_searches(self):
        row=self.contact_fixture();_,selector,reference=self.selected_fixture()
        self.assertEqual(selection_counts(row["force_reference"]["decision"]["selection"]),
            dict(contact_searches=1,refinements=0,best_sequences=2))
        self.assertLessEqual(selected_reference(row,selector,reference)["maximum_position_error"],1e-10)
        forecast=applied_forecast(row)
        self.assertEqual(forecast["held_target"],row["native_targets"])
        self.assertEqual(forecast["completed_steps"],5)

    def test_38_contact_target_crossing_refuses_before_transfer(self):
        row=dict(self.contact_fixture())
        row["native_targets"]=list(row["native_targets"]);row["native_targets"][0]+=.01
        with self.assertRaises(ValueError):applied_forecast(row)

    def test_39_contact_search_cannot_masquerade_as_warm_continuation(self):
        original=self.contact_fixture();_,selector,reference=self.selected_fixture()
        row=dict(original);row["force_reference"]=dict(original["force_reference"])
        decision=dict(original["force_reference"]["decision"]);row["force_reference"]["decision"]=decision
        decision["selection"]=dict(decision["selection"]);del decision["selection"]["seed_selection"]
        with self.assertRaisesRegex(ValueError,"Contact only warm continuation may bypass search"):
            selected_reference(row,selector,reference)

    def test_40_contact_rejection_and_nested_reconstruction_denominator(self):
        self.assertEqual(selection_counts({"seed_selection":{"original":{}}}),
            dict(contact_searches=1,refinements=1,best_sequences=3))
        self.assertEqual(selection_counts({}),dict(contact_searches=0,refinements=0,best_sequences=1))
        original=self.contact_fixture();row=dict(original)
        row["force_reference"]=dict(original["force_reference"])
        decision=dict(original["force_reference"]["decision"]);row["force_reference"]["decision"]=decision
        decision["selection"]=dict(decision["selection"],accepted=False)
        with self.assertRaises(ValueError):applied_forecast(row)


    def test_41_scientific_fields_and_production_controller_cannot_change(self):
        parent=task.previous.declaration()
        task.validate_science(self.c,parent)
        for key in parent:
            if key in task.IDENTITY_FIELDS:continue
            bad=copy.deepcopy(self.c);bad[key]=None
            with self.assertRaisesRegex(ValueError,"scientific contract changed"):
                task.validate_science(bad,parent)
        for key in ("candidate","reference","resolver","stepping"):
            bad=copy.deepcopy(self.c);bad["production_entrypoints"][key]="crossed"
            with self.assertRaisesRegex(ValueError,"production science changed"):
                task.validate_science(bad,parent)

    def test_42_complete_inherited_gate_is_retained(self):
        self.assertEqual(task.GATES[:len(task.previous.GATES)],task.previous.GATES)
        self.assertEqual(task.EXPECTED_CONTROLS,1546+17+52)
        self.assertEqual(len({m for _,m,_ in task.GATES}),len(task.GATES))
        self.assertEqual(self.c["selection_seed"],task.previous.declaration()["selection_seed"])
        self.assertEqual(self.c["stage_owner"]["cleanup_seconds"],10.)

    def test_43_lifecycle_launch_evidence_cannot_be_missing_or_crossed(self):
        self.validate()
        saved=copy.deepcopy(self.gate["preflight"])
        for key in ("lifecycle_evidence_verified","lifecycle_evidence"):
            del self.gate["preflight"][key]
            with self.assertRaises(ValueError):self.validate()
            self.gate["preflight"]=copy.deepcopy(saved)
        for key in task.PREDECESSORS:
            self.gate["preflight"]["lifecycle_evidence"]["predecessors"][key]["receipt_sha256"]="crossed"
            with self.assertRaises(ValueError):self.validate()
            self.gate["preflight"]=copy.deepcopy(saved)

    def test_44_lifecycle_scope_and_authority_mutations_are_refused(self):
        failed=task.read(task.FAILED_RESULT);result=task.read(task.LIFECYCLE_RESULT)
        folder=task.ROOT.parent/"SporeSpore_Evidence"/result["attempt_id"]
        receipt=task.read(folder/"receipt.json");decl=task.read(folder/"declaration.json")
        task.validate_lifecycle_documents(failed,result,receipt,decl)
        values=[failed,result,receipt,decl]
        for index,key,value in ((0,"accepted_controls",1116),(0,"complete_gate_passed",True),
            (1,"cleanup_reports",15),(1,"lifecycle_controls",16),(1,"receipt_sha256","crossed"),
            (2,"ok",False),(2,"source_runtime_unchanged",False),(3,"controls_planned",41)):
            bad=copy.deepcopy(values);bad[index][key]=value
            with self.assertRaises(ValueError):task.validate_lifecycle_documents(*bad)
        for index in (1,2,3):
            for key in ("worlds_opened","solver_steps","physical_acceptance_authority","release_authority",
                "training_data_authority","tier2_qualified","tier3_benefit_established","original_incident_cause_established"):
                bad=copy.deepcopy(values);bad[index][key]=1 if key in ("worlds_opened","solver_steps") else True
                with self.assertRaises(ValueError):task.validate_lifecycle_documents(*bad)

    def test_45_changed_lifecycle_closure_bytes_are_refused(self):
        original=task.sha
        for path in (task.FAILED_RESULT,task.LIFECYCLE_RESULT):
            with patch.object(task,"sha",side_effect=lambda p:"crossed" if p==path else original(p)):
                with self.assertRaisesRegex(ValueError,"lifecycle closure hashes"):
                    task.verify_lifecycle(task.ROOT.parent/"SporeSpore_Evidence")

    def cleanup_fixture(self):
        return dict(ok=True,cleanup_seconds=10.,stable_handles=True,exact_job_membership=True,
            pid_reopened_after_job_close=False,errors=[],physical_acceptance_authority=False,
            release_authority=False,members=[dict(member=True,final_wait=0)])

    def test_46_stage_requires_successful_exact_handle_cleanup(self):
        from run_contact_sequence_native_v2 import validate_cleanup
        report=self.cleanup_fixture();validate_cleanup(report)
        for key,value in (("ok",False),("cleanup_seconds",11.),("stable_handles",False),
            ("exact_job_membership",False),("pid_reopened_after_job_close",True),
            ("errors",["unresolved"]),("members",[dict(member=True,final_wait=258)]),
            ("physical_acceptance_authority",True),("release_authority",True)):
            with self.assertRaises(ValueError):validate_cleanup(dict(report,**{key:value}))

    def test_47_invoke_uses_versioned_owner_and_verifies_cleanup(self):
        from unittest.mock import Mock
        import run_contact_sequence_native_v2 as runner
        from contained_stage_owner_v2 import OwnedChild
        self.assertIs(runner.OwnedChild,OwnedChild)
        child=Mock();child.process.poll.return_value=0;child.process.returncode=0
        folder=Path("synthetic-stage")
        with patch.object(Path,"mkdir"),patch.object(runner,"OwnedChild",return_value=child) as spawn,patch.object(runner,"read",return_value=self.cleanup_fixture()) as read:
            runner.invoke(["test-command"],folder,1,dict(SAMPLE="value"))
            spawn.assert_called_once_with(["test-command"],task.ROOT,dict(PYTHONDONTWRITEBYTECODE="1",SAMPLE="value"),folder)
            child.close.assert_called_once();read.assert_called_once_with(folder/"cleanup.json")

    def test_48_failed_or_timed_out_stage_closes_and_stays_failed(self):
        from unittest.mock import Mock
        import run_contact_sequence_native_v2 as runner
        for timed_out in (False,True):
            child=Mock();child.process.poll.return_value=None if timed_out else 1;child.process.returncode=1
            with patch.object(Path,"mkdir"),patch.object(runner,"OwnedChild",return_value=child),patch.object(runner.time,"monotonic",side_effect=[0.,2.]):
                with self.assertRaises(TimeoutError if timed_out else RuntimeError):
                    runner.invoke(["test-command"],Path("synthetic-stage"),1)
                child.close.assert_called_once()

    def test_49_all_six_owner_launch_sites_use_the_local_invoke(self):
        import ast
        import run_contact_sequence_native_v2 as runner
        tree=ast.parse(Path(runner.__file__).read_text(encoding="utf-8"))
        main=next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=="main")
        calls=[n for n in ast.walk(main) if isinstance(n,ast.Call) and isinstance(n.func,ast.Name) and n.func.id=="invoke"]
        self.assertEqual(len(calls),6)
        self.assertFalse(any(isinstance(n,ast.ImportFrom) and any(a.name=="invoke" for a in n.names) for n in ast.walk(tree)))
        self.assertEqual(runner.invoke.__module__,"run_contact_sequence_native_v2")
        self.assertIn("test_contact_sequence_containment_v2.Containment.test_original_leaf_and_descendant_control_with_retained_handles",Path(runner.__file__).read_text())

    def test_50_component_mode_cannot_also_request_physics(self):
        import sys
        import run_contact_sequence_native_v2 as runner
        with patch.object(sys,"argv",["owner","--core","candidate","--baseline-core","baseline","--component-only","--run"]),patch.object(runner,"invoke") as invoke,patch.object(sys,"stderr",io.StringIO()):
            with self.assertRaises(SystemExit) as caught:runner.main()
            self.assertEqual(caught.exception.code,2);invoke.assert_not_called()
        original=self.attempt;self.attempt=original.replace("-v2-","-v1-")
        self.consumed["attempt_id"]=self.attempt
        with self.assertRaises(ValueError):self.validate()

    def test_51_worker_reader_and_trial_bind_the_v2_task(self):
        import contact_sequence_native_v2 as worker
        import contact_sequence_native_trial_v2 as trial
        import contact_sequence_native_trial_audit_v2 as trial_reader
        import audit_contact_sequence_native_v2 as reader
        self.assertIs(worker.declaration,task.declaration)
        self.assertIs(worker.launch_records,task.launch_records)
        self.assertIs(reader.declaration,task.declaration)
        self.assertIs(reader.launch_records,task.launch_records)
        self.assertIs(worker.run_hold_trial,trial.run_hold_trial)
        self.assertIs(reader.audit_trial,trial_reader.audit_trial)
        self.assertIs(task.controller_for,task.previous.controller_for)
        self.assertIs(task.profile_for,task.previous.profile_for)

    def test_52_real_local_invoke_retains_cleanup_and_no_physics(self):
        import sys
        import uuid
        from run_contact_sequence_native_v2 import invoke,validate_cleanup
        folder=Path(os.environ["EXPLORER_TEST_OUTPUT"])/("route-owner-"+uuid.uuid4().hex)
        invoke([sys.executable,"-B","-c","print('zero-world stage')"],folder,30)
        validate_cleanup(task.read(folder/"cleanup.json"))
        self.assertEqual((folder/"stdout.log").read_text().strip(),"zero-world stage")
        self.assertFalse((folder/"physical").exists())


if __name__=="__main__":unittest.main()
