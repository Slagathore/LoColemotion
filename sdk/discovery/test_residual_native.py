"""World-free controls for the complete residual native worker/audit boundary."""
import copy
from contextlib import ExitStack
import hashlib
from itertools import islice
import json
import os
from pathlib import Path
import shutil
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import uuid

import mujoco
import residual_native_task as task
import residual_native as worker
import audit_residual_native as reader
import run_residual_native as owner
from gpu_measurement_probe import write_new
from residual_control import ResidualController
from run_gpu_measurement_probe import jobs

PARENT_SHA="5aeb46084f5431386656a029f3a887433945c0df97f3180a6ac58d0ba2b5d633"


def read(path):return json.loads(path.read_text(encoding="utf-8"))


def write(path,value):path.write_text(json.dumps(value,allow_nan=False)+"\n",encoding="utf-8",newline="\n")


def rows(path):
    with path.open(encoding="utf-8") as f:return [json.loads(line) for line in f]


def put_rows(path,values):
    with path.open("w",encoding="utf-8",newline="\n") as f:
        for value in values:f.write(json.dumps(value,separators=(",",":"),allow_nan=False)+"\n")


class NativeResidualControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        guards=ExitStack();cls.addClassCleanup(guards.close)
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("No residual control worlds")))
        cls.core_path=Path(os.environ["QUADRUPED_TEST_CORE"]);cls.baseline=Path(os.environ["PORTABLE_BATCH_BASELINE_CORE"])
        cls.core=task.bridge.LocomotionCore(cls.core_path);cls.oracle=task.bridge.LocomotionCore(cls.baseline)
        cls.c=task.declaration();cls.plans=task.trial_plan(cls.c)
        cls.out=Path(os.environ["EXPLORER_TEST_OUTPUT"])
        cls.root=cls.out/("residual-native-fixture-"+uuid.uuid4().hex);cls.root.mkdir()
        cls.folder=cls.root/"physical";cls.folder.mkdir()
        parent_path=task.HERE/"cpu_committed_feedback_closure_v1.json"
        if task.sha(parent_path)!=PARENT_SHA:raise ValueError("Residual native fixture parent")
        parent=read(parent_path);evidence=(task.ROOT.parent/"SporeSpore_Evidence").resolve(strict=True)
        old=evidence/parent["attempt_id"]/"physical"
        inventory={x["evidence_relative_path"]:x for x in parent["artifacts"]};bound={}
        def verified(path):
            record=inventory[path.relative_to(evidence).as_posix()]
            if task.sha(path)!=record["sha256"] or path.stat().st_size!=record["byte_length"]:raise ValueError("Fixture raw source changed")
            bound[path.relative_to(evidence).as_posix()]=record["sha256"];return path
        cls.compiled=read(verified(old/"models/nominal/compiled.json"))
        cls.spec=read(verified(old/"models/nominal/inputs.json"))
        cls.xml=verified(old/"models/nominal/model.xml").read_text(encoding="utf-8")
        cls.metadata=read(verified(old/"models/nominal/native-model.json"))
        source=old/"nominal_train_001_baseline"
        cls.inputs={}
        for name,count in (("controller",120),("trace",600),("timing",120)):
            with verified(source/(name+".jsonl")).open(encoding="utf-8") as f:
                cls.inputs[name]=[json.loads(line) for line in islice(f,count)]
            if len(cls.inputs[name])!=count:raise ValueError("Residual fixture prefix incomplete")
        write_new(cls.root/"input-bindings.json",dict(synthetic_control=True,source_closure_sha256=PARENT_SHA,
            bound_inputs=bound,constructed_worlds=0,changed_controls_are_not_new_physical_transitions=True))
        write_new(cls.root/"declaration.json",dict(contract=cls.c,synthetic=True,source_commit="0"*40))
        results=[cls.make_trial(cls.folder/p["trial_id"],p) for p in cls.plans]
        write_new(cls.folder/"worker-result.json",dict(ok=True,synthetic=True,ledger_scope=cls.c["ledger_scope"],
            status="complete_native_residual_route",constructed_cpu_worlds=0,constructed_model_count=0,
            constructed_gpu_worlds=0,trials=results,total_wall_s=.1,**{k:False for k in task.FLAGS}))
        cls.result=reader.audit(cls.folder,cls.core_path,cls.baseline)
        write_new(cls.root/"independent-audit.json",cls.result)

    @classmethod
    def make_trial(cls,folder,plan):
        folder.mkdir();write_new(folder/"plan.json",plan)
        write_new(folder/"compiled.json",cls.compiled);write_new(folder/"inputs.json",cls.spec)
        (folder/"model.xml").write_text(cls.xml,encoding="utf-8",newline="\n")
        model=task.provider.FrozenModel.load(cls.core,task.model_artifact(plan["model_kind"]))
        (folder/"provider-model.json").write_text(model.serialized,encoding="utf-8",newline="\n")
        metadata=copy.deepcopy(cls.metadata)
        metadata.update(model_sha256=task.sha(folder/"model.xml"),compiled_sha256=task.sha(folder/"compiled.json"),
            inputs_sha256=task.sha(folder/"inputs.json"),provider_model_sha256=model.sha256)
        write_new(folder/"native-model.json",metadata)
        controller=ResidualController(cls.core,cls.compiled,task.controller_contract(cls.c,model),model,plan["mode"],plan["trial_id"])
        controls=[]
        try:
            for source in cls.inputs["controller"]:
                row=controller.step(source["request"]["state"],source["stability"],source["kinematics"])
                row.update(backend="cpu",cell=0,outer_step=source["outer_step"],native_observation=copy.deepcopy(source["native_observation"]))
                controls.append(row)
        finally:controller.close()
        trace=copy.deepcopy(cls.inputs["trace"])
        for row in trace:row["ctrl"]=controls[(row["step"]-1)//5]["native_targets"]
        put_rows(folder/"controller.jsonl",controls);put_rows(folder/"trace.jsonl",trace)
        put_rows(folder/"timing.jsonl",cls.inputs["timing"])
        result=dict(plan,setup_s=.1,graph_capture_s=0.,outer_rows=120,internal_rows=600,completed=True,
            controller_closed=True,provider_model_sha256=model.sha256,
            hashes={name:task.sha(folder/(name+".jsonl")) for name in ("controller","trace","timing")})
        write_new(folder/"result.json",result)
        return result

    def clone_trial(self,role="probe"):
        plan=next(p for p in self.plans if p["role"]==role)
        folder=self.out/("trial-corruption-"+uuid.uuid4().hex)
        shutil.copytree(self.folder/plan["trial_id"],folder)
        return folder,plan

    def clone_population(self):
        target=self.out/("population-corruption-"+uuid.uuid4().hex)
        shutil.copytree(self.root,target)
        return target/"physical"

    def audit_trial(self,folder,plan):
        return reader.audit_trial(folder,plan,self.c,self.baseline,self.oracle)

    def change_stream(self,folder,name,mutation):
        values=rows(folder/(name+".jsonl"));mutation(values);put_rows(folder/(name+".jsonl"),values)
        result=read(folder/"result.json");result["hashes"][name]=task.sha(folder/(name+".jsonl"));write(folder/"result.json",result)

    def test_prospective_scope_sources_roles_and_complete_gate_are_immutable(self):
        self.assertEqual(self.c,task.expected_declaration())
        self.assertEqual(self.c["complete_safety_control_count"],85)
        self.assertEqual([(r["id"],r["mode"]) for r in self.c["roles"]],[("absent","absent"),("zero","frozen"),("probe","frozen")])
        self.assertTrue(all(self.c[k] is False for k in task.FLAGS))
        for mutation in (lambda c:c.__setitem__("outer_steps",121),lambda c:c.__setitem__("training_data_authority",True),
            lambda c:c["implementation_bindings"].__setitem__("residual_native.py","0"*64),lambda c:c["roles"].reverse()):
            value=copy.deepcopy(self.c);mutation(value)
            path=self.out/("bad-contract-"+uuid.uuid4().hex+".json");write(path,value)
            with patch.object(task,"CONTRACT",path):
                with self.assertRaisesRegex(ValueError,"declaration/source"):task.declaration()

    def test_both_core_preflight_has_no_worlds_and_exact_model_bytes(self):
        result=worker.preflight(self.core_path,self.baseline)
        self.assertTrue(result["ok"])
        self.assertEqual((result["world_build_count"],result["solver_steps"]),(0,0))
        self.assertEqual((result["planned_controller_rows"],result["planned_internal_rows"]),(360,1800))
        for plan in self.plans:
            artifact=task.model_artifact(plan["model_kind"])
            first=task.provider.FrozenModel.load(self.core,artifact)
            second=task.provider.FrozenModel.load(self.oracle,first.document())
            self.assertEqual(first,second)
            self.assertEqual(first.policy.moments.count,0)

    def test_complete_synthetic_replay_never_becomes_native_or_training_evidence(self):
        self.assertTrue(self.result["ok"]);self.assertTrue(self.result["synthetic"])
        self.assertFalse(self.result["native_route_verified"])
        self.assertEqual((self.result["controller_rows"],self.result["internal_rows"]),(360,1800))
        self.assertEqual(self.result["constructed_cpu_worlds"],0)
        for field in task.FLAGS:self.assertFalse(self.result[field])
        for plan,result in zip(self.plans,self.result["trials"],strict=True):
            candidate=reader.audit_trial(self.folder/plan["trial_id"],plan,self.c,self.core_path,self.core)
            self.assertEqual(candidate,result)
            self.assertIsNone(result["official_quality_m_s"])

    def test_raw_digest_order_and_missing_population_are_rejected(self):
        folder,plan=self.clone_trial()
        with (folder/"trace.jsonl").open("a",encoding="utf-8") as f:f.write("{}\n")
        with self.assertRaisesRegex(ValueError,"raw digest"):self.audit_trial(folder,plan)
        for mutation,expected in ((lambda v:v.pop(),"missing controller"),(lambda v:v.reverse(),"controller order")):
            folder,plan=self.clone_trial();self.change_stream(folder,"controller",mutation)
            with self.assertRaisesRegex(ValueError,expected):self.audit_trial(folder,plan)
        folder,plan=self.clone_trial();result=read(folder/"result.json");result["internal_rows"]-=1;write(folder/"result.json",result)
        with self.assertRaisesRegex(ValueError,"worker denominator"):self.audit_trial(folder,plan)

    def test_native_observation_endpoint_receipt_and_history_corruption_hits(self):
        mutations=[
            lambda r:r[0]["native_observation"]["qpos"].__setitem__(7,.123),
            lambda r:r[0]["kinematics"][0]["joint_axis_world_unit"].__setitem__("x",.123),
            lambda r:r[2]["resolution"]["ordered_commands"][0].__setitem__("applied_correction_rad_s",.123),
            lambda r:r[2]["resolution_request"]["provider_request"]["history"]["ordered_entries"].clear()]
        for mutation in mutations:
            folder,plan=self.clone_trial();self.change_stream(folder,"controller",mutation)
            with self.assertRaises(ValueError):self.audit_trial(folder,plan)

    def test_internal_input_continuity_clock_forces_warning_and_contact_guards(self):
        mutations=[
            lambda r:r[6]["ctrl"].__setitem__(0,r[6]["ctrl"][0]+.01),
            lambda r:r[6]["before_qpos"].__setitem__(0,r[6]["before_qpos"][0]+.01),
            lambda r:r[6].__setitem__("time_s",.5),
            lambda r:r[6]["actuator_force_nm"].__setitem__(0,1e9),
            lambda r:r[6]["warnings"].__setitem__(0,1),
            lambda r:r[6].__setitem__("batch_contacts",255),
            lambda r:r.pop()]
        for mutation in mutations:
            folder,plan=self.clone_trial();self.change_stream(folder,"trace",mutation)
            with self.assertRaises(ValueError):self.audit_trial(folder,plan)

    def test_terminal_provider_failure_prevents_native_control_transfer(self):
        source=rows(self.folder/self.plans[2]["trial_id"]/"controller.jsonl")[1]
        data=SimpleNamespace(ctrl=[7.]*8)
        invalid=copy.deepcopy(source);invalid["residual"]["terminal_error"]=dict(type="Injected",message="stop")
        with self.assertRaisesRegex(ValueError,"terminal provider"):worker.transfer_targets(invalid,data)
        self.assertEqual(data.ctrl,[7.]*8)
        worker.transfer_targets(source,data)
        self.assertEqual(data.ctrl,source["native_targets"])

    def test_model_artifact_xml_and_native_profile_cannot_be_crossed(self):
        mutations=[
            ("provider-model.json",lambda v:v["policy"]["weights"][0].__setitem__(0,.123)),
            ("native-model.json",lambda v:v["actuator_profile"]["gainprm"][0].__setitem__(0,99.)),
            ("native-model.json",lambda v:v["ordered_bodies"].reverse())]
        for name,mutation in mutations:
            folder,plan=self.clone_trial();value=read(folder/name);mutation(value);write(folder/name,value)
            with self.assertRaises(ValueError):self.audit_trial(folder,plan)
        folder,plan=self.clone_trial()
        with (folder/"model.xml").open("a",encoding="utf-8") as f:f.write("\n")
        with self.assertRaisesRegex(ValueError,"model/compiler"):self.audit_trial(folder,plan)

    def test_launch_requires_containment_complete_gate_frozen_claim_and_durable_path(self):
        with self.assertRaisesRegex(ValueError,"containment"):
            worker.run(self.out,self.out/"absent-permit",self.core_path,self.baseline)
        control=self.out/("launch-control-"+uuid.uuid4().hex);control.mkdir()
        evidence=control/"SporeSpore_Evidence";evidence.mkdir()
        parent=evidence/"sdk2-residual-native-synthetic-claim";parent.mkdir()
        folder=parent/"physical";folder.mkdir()
        source="0"*40
        owner=dict(synthetic=False,synthetic_control=True,contract=self.c,source_commit=source)
        write(parent/"declaration.json",owner)
        counts={g["name"]:g["count"] for g in self.c["safety_controls"]};counts.update(provider=2,containment=1)
        gate=dict(ok=True,source_commit=source,safety_controls=counts,declaration_sha256=task.sha(parent/"declaration.json"),
            preflight=dict(ok=True,world_build_count=0,solver_steps=0))
        write(parent/"gate-receipt.json",gate)
        consumed=dict(attempt_id=parent.name,source_commit=source,contract_sha256=task.sha(task.CONTRACT),
            declaration_sha256=task.sha(parent/"declaration.json"),gate_receipt_sha256=task.sha(parent/"gate-receipt.json"),
            trials=self.plans)
        write(parent/"consumed.json",consumed)
        with patch.object(worker,"ROOT",control/"fake-repo"):
            worker.validate_launch_records(folder,source)
            changed=copy.deepcopy(gate);changed["safety_controls"]["residual-native"]-=1;write(parent/"gate-receipt.json",changed)
            with self.assertRaisesRegex(ValueError,"complete zero-world gate"):worker.validate_launch_records(folder,source)
            write(parent/"gate-receipt.json",gate)
            changed=copy.deepcopy(consumed);changed["gate_receipt_sha256"]="0"*64;write(parent/"consumed.json",changed)
            with self.assertRaisesRegex(ValueError,"single-use"):worker.validate_launch_records(folder,source)
            write(parent/"consumed.json",consumed)
            with self.assertRaisesRegex(ValueError,"owner freeze"):worker.validate_launch_records(folder,"1"*40)
        with self.assertRaisesRegex(ValueError,"durable fresh"):worker.validate_launch_records(folder,source)

    def test_incomplete_worker_wrong_roles_and_authority_never_pass(self):
        mutations=[
            lambda v:v.__setitem__("ok",False),
            lambda v:v["trials"].pop(),
            lambda v:v["trials"].reverse(),
            lambda v:v.__setitem__("training_data_authority",True),
            lambda v:v.__setitem__("constructed_cpu_worlds",3),
            lambda v:v.__setitem__("synthetic",False)]
        for mutation in mutations:
            folder=self.clone_population();value=read(folder/"worker-result.json");mutation(value);write(folder/"worker-result.json",value)
            with self.assertRaises(ValueError):reader.audit(folder,self.core_path,self.baseline)

    def test_physical_failure_is_retained_and_has_no_official_quality_or_selection(self):
        folder,plan=self.clone_trial()
        self.change_stream(folder,"trace",lambda r:r[-1]["qpos"].__setitem__(2,.1))
        result=self.audit_trial(folder,plan)
        self.assertFalse(result["diagnostic_eligible"])
        self.assertIn("height",result["diagnostic_failure_codes"])
        self.assertEqual(result["diagnostic_metrics"]["first_physical_violation"]["internal_step"],600)
        self.assertIsNone(result["official_quality_m_s"])
        self.assertFalse(result["selection_authority"])

    def test_zero_trace_identity_and_real_dynamic_response_are_required(self):
        comparison=self.result["native_path_comparison"]
        self.assertTrue(comparison["zero_residual_native_trace_bit_identical"])
        self.assertIsNotNone(comparison["probe_first_different_internal_input"])
        self.assertIsNone(comparison["probe_first_different_native_position"])
        with self.assertRaisesRegex(ValueError,"native state response"):
            reader.compare_native_paths(self.folder,self.result["trials"],False)
        corrupt=copy.deepcopy(self.result["trials"]);corrupt[1]["raw_hashes"]["trace"]="0"*64
        with self.assertRaisesRegex(ValueError,"zero changed native baseline"):
            reader.compare_native_paths(self.folder,corrupt,True)

    def test_partial_worker_receipt_preserves_error_and_unknown_world_count(self):
        folder=self.out/("partial-worker-control-"+uuid.uuid4().hex);folder.mkdir()
        physical=folder/"physical";physical.mkdir()
        (physical/"worker-result.json").write_text("{",encoding="utf-8")
        receipt=dict(ok=False,synthetic_control=True,physical_launch_requested=True,error="contained timeout",contract=self.c)
        owner.capture_worker_state(receipt,folder)
        self.assertEqual(receipt["error"],"contained timeout")
        self.assertIn("JSONDecodeError",receipt["worker_result_read_error"])
        self.assertIsNone(receipt["physical_started"])
        self.assertNotIn("constructed_cpu_worlds",receipt)
        trial=physical/self.plans[0]["trial_id"];trial.mkdir()
        write(trial/"world-opened.json",dict(trial_id=trial.name,native_data_constructed=True,core_sha256=self.c["core_sha256"]))
        owner.capture_worker_state(receipt,folder)
        self.assertEqual(receipt["constructed_cpu_worlds_lower_bound"],1)
        self.assertIs(receipt["physical_started"],True)
        self.assertNotIn("constructed_cpu_worlds",receipt)
        write(physical/"worker-result.json",dict(constructed_cpu_worlds=2,constructed_gpu_worlds=0))
        owner.capture_worker_state(receipt,folder)
        self.assertEqual(receipt["constructed_cpu_worlds"],2)
        self.assertFalse(receipt["ok"])
        self.assertEqual(receipt["error"],"contained timeout")


if __name__=="__main__":unittest.main()
