"""Twenty zero-world controls for native withdrawal declarations and evidence."""
import ast
import copy
from contextlib import ExitStack
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
import residual_withdrawal_task as task
import residual_withdrawal_native as worker
import audit_residual_withdrawal as reader
import run_residual_withdrawal as owner
from residual_withdrawal_control import WithdrawalController
from residual_withdrawal_metrics import transitions
from gpu_measurement_probe import write_new

def write(path,value):
    path.write_text(json.dumps(value,allow_nan=False)+"\n",encoding="utf-8",newline="\n")

def rows(path):
    with path.open(encoding="utf-8") as stream:return [json.loads(line) for line in stream]

def put(path,values):
    with path.open("w",encoding="utf-8",newline="\n") as stream:
        for value in values:stream.write(json.dumps(value,separators=(",",":"),allow_nan=False)+"\n")


class WithdrawalNativeControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        guards=ExitStack();cls.addClassCleanup(guards.close)
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Withdrawal controls open no worlds")))
        cls.core_path=Path(os.environ["QUADRUPED_TEST_CORE"]);cls.baseline=Path(os.environ["PORTABLE_BATCH_BASELINE_CORE"])
        cls.core=task.bridge.LocomotionCore(cls.core_path);cls.oracle=task.bridge.LocomotionCore(cls.baseline)
        cls.c=task.declaration();cls.models=task.frozen_models(cls.core);cls.plans=task.all_plans(cls.c)
        cls.out=Path(os.environ["EXPLORER_TEST_OUTPUT"])
        cls.root=cls.out/("withdrawal-native-fixture-"+uuid.uuid4().hex);cls.root.mkdir()
        _,population,_=task.selection.retained_population()
        selected=next(r for r in population if r["stage"]=="iteration_00" and r["model_key"]=="d00_plus")
        trial=next(r for r in selected["trials"] if r["group_id"]=="left_075_train_001")
        evidence=(task.ROOT.parent/"SporeSpore_Evidence").resolve(strict=True)
        pilot=evidence/task.selection.PILOT
        original=pilot/"stages/iteration_00/physical"/trial["trial_id"]
        receipt=task.read(pilot/"receipt.json")
        inventory={r["path"]:r for r in receipt["artifacts"]};bound={}
        def verified(path):
            record=inventory[path.relative_to(pilot).as_posix()]
            task.require(task.sha(path)==record["sha256"] and path.stat().st_size==record["byte_length"],
                "Withdrawal fixture raw source")
            bound[path.relative_to(evidence).as_posix()]=record["sha256"]
            return path
        cls.inputs={}
        for name,count in (("controller",140),("trace",700),("timing",140)):
            path=verified(original/(name+".jsonl"))
            task.require(task.sha(path)==trial["raw_hashes"][name],"Withdrawal fixture trial/raw join")
            with path.open(encoding="utf-8") as stream:
                cls.inputs[name]=[json.loads(line) for line in islice(stream,count)]
        cls.compiled=task.read(verified(original/"compiled.json"))
        cls.fixture_c=dict(cls.c,outer_steps=140,official_quality_enabled=False)
        cls.plan=cls.plans[0];cls.model=cls.models["selected"]
        cls.folder=cls.root/"trial";cls.folder.mkdir()
        write(cls.folder/"plan.json",cls.plan)
        for name in ("compiled.json","inputs.json","model.xml"):
            shutil.copyfile(verified(original/name),cls.folder/name)
        (cls.folder/"provider-model.json").write_text(cls.model.serialized,encoding="utf-8",newline="\n")
        metadata=task.read(verified(original/"native-model.json"))
        metadata["provider_model_sha256"]=cls.model.sha256
        write(cls.folder/"native-model.json",metadata)
        cls.controls=cls.replay("shadow")
        for current,old in zip(cls.controls,cls.inputs["controller"],strict=True):
            task.require(reader.same_bits(current["native_targets"],old["native_targets"]),
                "Withdrawal fixture shadow changed original native inputs")
        put(cls.folder/"controller.jsonl",cls.controls)
        put(cls.folder/"trace.jsonl",cls.inputs["trace"]);put(cls.folder/"timing.jsonl",cls.inputs["timing"])
        write(cls.folder/"result.json",dict(cls.plan,setup_s=.1,graph_capture_s=0.,outer_rows=140,
            internal_rows=700,completed=True,controller_closed=True,provider_model_sha256=cls.model.sha256,
            hashes={name:task.sha(cls.folder/(name+".jsonl")) for name in ("controller","trace","timing")}))
        write_new(cls.root/"input-bindings.json",dict(synthetic_control=True,retained_input_replay=True,
            original_inputs=bound,worlds_opened=0,solver_steps=0,new_physical_outcomes=False,
            counterfactual_modes_are_not_physical_transitions=True))

    @classmethod
    def replay(cls,mode):
        host=WithdrawalController(cls.core,cls.compiled,task.controller_contract(cls.fixture_c,cls.model),
            cls.model,mode,cls.plan["trial_id"])
        result=[]
        try:
            for old in cls.inputs["controller"]:
                row=host.step(old["request"]["state"],old["stability"],old["kinematics"])
                row.update(backend="cpu",cell=0,outer_step=old["outer_step"],native_observation=copy.deepcopy(old["native_observation"]))
                result.append(row)
        finally:host.close()
        return result

    def clone(self):
        path=self.out/("withdrawal-corruption-"+uuid.uuid4().hex)
        shutil.copytree(self.folder,path);return path

    def audit(self,path):
        return reader.audit_trial(path,self.plan,self.fixture_c,self.baseline,self.oracle,self.model.document())

    def change_stream(self,path,name,change):
        value=rows(path/(name+".jsonl"));change(value);put(path/(name+".jsonl"),value)
        result=task.read(path/"result.json");result["hashes"][name]=task.sha(path/(name+".jsonl"));write(path/"result.json",result)

    def test_01_prospective_full_population_no_reserved_starts_or_claims(self):
        self.assertEqual(task.expected_declaration(),self.c)
        self.assertEqual(task.EXPECTED_CONTROLS,218)
        self.assertEqual((len(self.plans),self.c["outer_steps"],self.c["horizon_s"]),(10,1440,12.))
        self.assertEqual({p["initial_native_lateral_velocity_m_s"] for p in self.plans},{.001})
        self.assertEqual(len({p["trial_id"] for p in self.plans}),10)
        self.assertTrue(all(p["partition"]=="development_comparison" and not p["training_data_authority"] for p in self.plans))
        self.assertTrue(all(self.c[k] is False for k in task.FLAGS))
        self.assertFalse(self.c["intervention_success_is_completion_requirement"])

    def test_02_changed_contract_modes_or_models_refuse(self):
        for change in (lambda v:v.__setitem__("outer_steps",120),
            lambda v:v.__setitem__("challenge_actor_sha256","sha256:"+"0"*64),
            lambda v:v.__setitem__("forced_request_command",91),
            lambda v:v.__setitem__("training_data_authority",True)):
            value=copy.deepcopy(self.c);change(value);path=self.out/("bad-contract-"+uuid.uuid4().hex+".json")
            write(path,value)
            with patch.object(task,"CONTRACT",path):
                with self.assertRaisesRegex(ValueError,"declaration/source"):task.declaration()

    def test_03_both_core_models_preserve_original_actor_warning_and_no_training(self):
        self.assertEqual(self.models,task.frozen_models(self.oracle))
        for model in self.models.values():
            self.assertEqual(model.warning.sha256,self.c["warning_model_sha256"])
            self.assertEqual(model.policy.moments.count,0)
            self.assertEqual(model.actor.document()["corpus"]["kind"],"untrained_development_probe")
        self.assertEqual(self.models["challenge"].actor.sha256,task.CHALLENGE_ACTOR)

    def test_04_zero_world_preflight_and_unchanged_native_loop(self):
        result=worker.preflight(self.core_path,self.baseline,"comparison")
        self.assertEqual((result["world_build_count"],result["solver_steps"]),(0,0))
        self.assertEqual((result["planned_cpu_worlds"],result["planned_controller_rows"],result["planned_internal_rows"]),
            (10,14400,72000))
        def function(path,name):
            source=path.read_text();node=next(n for n in ast.parse(source).body if isinstance(n,ast.FunctionDef) and n.name==name)
            return ast.get_source_segment(source,node)
        self.assertEqual(function(task.HERE/"residual_selection_native.py","run_trial"),
            function(task.HERE/"residual_withdrawal_native.py","run_trial"))

    def test_05_complete_reader_uses_other_core_and_retained_raw_state(self):
        first=self.audit(self.folder)
        second=reader.audit_trial(self.folder,self.plan,self.fixture_c,self.core_path,self.core,self.model.document())
        self.assertEqual(first,second)
        self.assertEqual((first["controller_rows"],first["internal_rows"]),(140,700))
        self.assertTrue(first["diagnostic_eligible"]);self.assertIsNone(first["official_quality_m_s"])
        write_new(self.root/"independent-prefix-audit.json",dict(result=first,synthetic_control=True,
            worlds_opened=0,solver_steps=0,new_physical_outcomes=False))

    def test_06_raw_digest_missing_order_and_denominator_refuse(self):
        path=self.clone()
        with (path/"trace.jsonl").open("a",encoding="utf-8") as stream:stream.write("{}\n")
        with self.assertRaisesRegex(ValueError,"raw digest"):self.audit(path)
        for change in (lambda v:v.pop(),lambda v:v.reverse()):
            path=self.clone();self.change_stream(path,"controller",change)
            with self.assertRaises(ValueError):self.audit(path)
        path=self.clone();v=task.read(path/"result.json");v["internal_rows"]-=1;write(path/"result.json",v)
        with self.assertRaisesRegex(ValueError,"worker denominator"):self.audit(path)

    def test_07_native_observation_receipt_and_actual_history_corruption_refuse(self):
        changes=(lambda v:v[0]["native_observation"]["qpos"].__setitem__(7,.123),
            lambda v:v[0]["kinematics"][0]["joint_axis_world_unit"].__setitem__("x",.123),
            lambda v:v[2]["resolution"]["ordered_commands"][0].__setitem__("applied_correction_rad_s",.123),
            lambda v:v[2]["resolution_request"]["provider_request"]["history"]["ordered_entries"].clear())
        for change in changes:
            path=self.clone();self.change_stream(path,"controller",change)
            with self.assertRaises(ValueError):self.audit(path)

    def test_08_prediction_memory_and_forced_request_corruption_refuse(self):
        changes=(lambda v:v[3]["residual"]["decision"]["warning"]["natural_decision"].__setitem__("score",5.),
            lambda v:v[3]["residual"]["decision"]["warning"].__setitem__("forced_route_request",True),
            lambda v:v[3]["resolution"]["next_memory"]["opaque_state"]["warning_state"].__setitem__("withheld",True))
        for change in changes:
            path=self.clone();self.change_stream(path,"controller",change)
            with self.assertRaises(ValueError):self.audit(path)

    def test_09_held_input_continuity_time_forces_warnings_and_contacts_refuse(self):
        changes=(lambda v:v[6]["ctrl"].__setitem__(0,v[6]["ctrl"][0]+.01),
            lambda v:v[6]["before_qpos"].__setitem__(0,v[6]["before_qpos"][0]+.01),
            lambda v:v[6].__setitem__("time_s",.5),lambda v:v[6]["actuator_force_nm"].__setitem__(0,1e9),
            lambda v:v[6]["warnings"].__setitem__(0,1),lambda v:v[6].__setitem__("batch_contacts",255),
            lambda v:v.pop())
        for change in changes:
            path=self.clone();self.change_stream(path,"trace",change)
            with self.assertRaises(ValueError):self.audit(path)

    def test_10_crossed_actor_warning_xml_and_native_profile_refuse(self):
        changes=(("provider-model.json",lambda v:v.__setitem__("actor",self.models["challenge"].actor.document())),
            ("provider-model.json",lambda v:v["warning"]["weights"].__setitem__(0,123.)),
            ("native-model.json",lambda v:v["actuator_profile"]["gainprm"][0].__setitem__(0,99.)),
            ("native-model.json",lambda v:v["ordered_bodies"].reverse()))
        for name,change in changes:
            path=self.clone();v=task.read(path/name);change(v);write(path/name,v)
            with self.assertRaises(ValueError):self.audit(path)
        path=self.clone()
        with (path/"model.xml").open("a",encoding="utf-8") as stream:stream.write("\n")
        with self.assertRaises(ValueError):self.audit(path)

    def test_11_terminal_provider_failure_blocks_transfer_before_solver_input(self):
        row=copy.deepcopy(self.controls[1]);data=SimpleNamespace(ctrl=[7.]*8)
        row["residual"]["terminal_error"]=dict(type="Injected",message="control")
        with self.assertRaisesRegex(ValueError,"terminal provider"):worker.transfer_targets(row,data)
        self.assertEqual(data.ctrl,[7.]*8)
        worker.transfer_targets(self.controls[1],data);self.assertEqual(data.ctrl,self.controls[1]["native_targets"])

    def test_12_independent_transition_accounting_on_silent_and_forced_replay(self):
        quiet=transitions(self.controls,None,self.fixture_c,self.model,"shadow")
        self.assertEqual(quiet["monitor_withheld_commands"],0)
        forced=self.replay("forced_route")
        result=transitions(forced,None,self.fixture_c,self.model,"forced_route")
        self.assertEqual(result["forced_request_commands"],[90])
        self.assertEqual(result["warning_withdrawal_commands"],30)
        self.assertEqual(result["reentries"][0]["command"],120)
        self.assertTrue(result["entries"][0]["previous_nonzero_residual"])
        self.assertTrue(result["entries"][0]["actual_zero_residual"])
        self.assertFalse(result["sufficient_intervention_lead_established"])
        write_new(self.root/"counterfactual-transition-control.json",dict(synthetic_control=True,
            new_physical_outcomes=False,worlds_opened=0,solver_steps=0,result=result))

    def test_13_transition_accounting_rejects_invented_natural_or_actual_events(self):
        for change in (lambda v:v[3]["residual"]["decision"]["warning"]["natural_decision"].__setitem__("withdraw_requested",True),
            lambda v:v[3]["residual"]["decision"]["warning"].__setitem__("withdrawal_applied_to_proposal",True),
            lambda v:v[3]["residual"]["decision"]["warning"].__setitem__("clear_commands",4)):
            value=copy.deepcopy(self.controls);change(value)
            with self.assertRaises(ValueError):transitions(value,None,self.fixture_c,self.model,"shadow")

    def test_14_ordinary_physical_failure_is_retained_with_null_quality(self):
        path=self.clone();self.change_stream(path,"trace",lambda v:v[-1]["qpos"].__setitem__(2,.1))
        result=self.audit(path);self.assertFalse(result["diagnostic_eligible"])
        self.assertIn("height",result["diagnostic_failure_codes"])
        scored=task.score(rows(path/"controller.jsonl"),rows(path/"trace.jsonl"),self.fixture_c,training=False)
        self.assertIsNone(scored["official_quality_m_s"])
        self.assertEqual(scored["first_reward_failure"]["internal_step"],700)
        with self.assertRaisesRegex(ValueError,"cannot fit"):task.score([],[],self.c,training=True)

    def synthetic_comparison(self):
        return [dict(p,observations=None,comparison_data_used_for_training=False,
            diagnostic_eligible=True,official_quality_m_s=-.1,first_reward_failure=None,
            raw_hashes=dict(trace="a"*64),withdrawal=dict(monitor_withheld_commands=0))
            for p in self.plans]

    def test_15_comparison_retains_negative_outcomes_without_requiring_rescue(self):
        values=self.synthetic_comparison()
        for row in values:
            if row["model_key"]=="challenge":
                row.update(diagnostic_eligible=False,official_quality_m_s=None,
                    first_reward_failure=dict(time_s=1.2 if row["mode"]=="frozen" else 1.,internal_step=600))
        result=task.assess_comparison(values,self.c)
        self.assertEqual(len(result["groups"]),2)
        for group in result["groups"]:
            self.assertFalse(group["challenge_guarded_eligible"])
            self.assertIsNone(group["challenge_quality_change_m_s"])
            self.assertAlmostEqual(group["challenge_failure_time_change_s"],.2)
        self.assertFalse(result["tier2_qualified"]);self.assertFalse(result["safe_backup_established"])

    def test_16_missing_crossed_fitted_or_silently_changed_comparison_refuses(self):
        for change in (lambda v:v.pop(),lambda v:v.reverse(),lambda v:v[0].__setitem__("observations",{}),
            lambda v:v[0].__setitem__("diagnostic_eligible",False),
            lambda v:v[1]["raw_hashes"].__setitem__("trace","b"*64)):
            values=self.synthetic_comparison();change(values)
            with self.assertRaises(ValueError):task.assess_comparison(values,self.c)

    def test_17_stage_binds_both_unchanged_artifacts_and_cannot_update(self):
        root=self.out/("withdrawal-stage-"+uuid.uuid4().hex);root.mkdir();(root/"stages").mkdir()
        for name in ("declaration","gate-receipt","consumed"):write(root/(name+".json"),dict(source_commit="0"*40,synthetic=True))
        folder=root/"stages/comparison";claim,batch,models=task.prepare_stage(folder,self.c,self.core)
        self.assertIsNone(batch);self.assertEqual(models,self.models)
        artifact=folder/"models/challenge.json";raw=artifact.read_bytes();artifact.write_bytes(raw+b" ")
        with self.assertRaisesRegex(ValueError,"staged model"):task.load_stage(folder,self.c,self.core)
        artifact.write_bytes(raw);bad=copy.deepcopy(claim);bad["trials"].pop();write(folder/"stage.json",bad)
        with self.assertRaisesRegex(ValueError,"stage claim"):task.load_stage(folder,self.c,self.core)
        write(folder/"stage.json",claim);write(folder/"update.json",dict(synthetic=True))
        with self.assertRaisesRegex(ValueError,"cannot fit"):task.load_stage(folder,self.c,self.core)

    def test_18_launch_requires_complete_gate_containment_and_exact_consumed_claim(self):
        root=self.out/("withdrawal-launch-"+uuid.uuid4().hex);root.mkdir()
        evidence=root/"SporeSpore_Evidence";evidence.mkdir()
        attempt=evidence/"sdk2-residual-withdrawal-synthetic-claim";physical=attempt/"stages/comparison/physical"
        physical.mkdir(parents=True);source="0"*40
        write(attempt/"declaration.json",dict(contract=self.c,source_commit=source,synthetic=False,synthetic_control=True))
        counts={n:k for n,_,k in task.GATES};counts.update(provider=2,containment=1)
        gate=dict(ok=True,source_commit=source,safety_controls=counts,
            declaration_sha256=task.sha(attempt/"declaration.json"),preflight=dict(ok=True,world_build_count=0,solver_steps=0))
        write(attempt/"gate-receipt.json",gate)
        consumed=dict(attempt_id=attempt.name,source_commit=source,lane="comparison",contract_sha256=task.sha(task.CONTRACT),
            declaration_sha256=task.sha(attempt/"declaration.json"),gate_receipt_sha256=task.sha(attempt/"gate-receipt.json"),trials=self.plans)
        write(attempt/"consumed.json",consumed)
        with patch.object(task,"ROOT",root/"repo"):
            task.validate_launch_records(physical,self.c,source)
            bad=copy.deepcopy(gate);bad["safety_controls"]["withdrawal-provider"]-=1;write(attempt/"gate-receipt.json",bad)
            with self.assertRaisesRegex(ValueError,"complete zero-world"):task.validate_launch_records(physical,self.c,source)
            write(attempt/"gate-receipt.json",gate)
            with self.assertRaisesRegex(ValueError,"owner freeze"):task.validate_launch_records(physical,self.c,"1"*40)
            bad=copy.deepcopy(consumed);bad["trials"].pop();write(attempt/"consumed.json",bad)
            with self.assertRaisesRegex(ValueError,"consumed claim"):task.validate_launch_records(physical,self.c,source)
        with self.assertRaisesRegex(ValueError,"requires containment"):
            worker.run(self.out,self.out/"missing",self.core_path,self.baseline,"comparison")

    def test_19_partial_world_counts_remain_lower_bounds(self):
        root=self.out/("withdrawal-partial-"+uuid.uuid4().hex)
        trial=root/"stages/comparison/physical"/self.plans[0]["trial_id"];trial.mkdir(parents=True)
        write(trial/"world-opened.json",dict(native_data_constructed=True,trial_id=trial.name,core_sha256=self.c["core_sha256"]))
        receipt=dict(requested_stages=["comparison"],contract=self.c,planned_trials=self.plans,error="contained timeout",ok=False)
        owner.capture_worker_state(receipt,root)
        self.assertEqual(receipt["constructed_cpu_worlds_lower_bound"],1)
        self.assertNotIn("constructed_cpu_worlds",receipt);self.assertTrue(receipt["physical_started"])
        self.assertEqual(receipt["error"],"contained timeout")

    def test_20_every_component_model_and_source_is_bound(self):
        value=owner.bindings(self.core_path,self.baseline)
        for path in [task.HERE/n for n in task.SOURCES]+[task.CONTRACT,*task.ARTIFACTS,*task.COMPONENTS]:
            self.assertEqual(value["source"][path.relative_to(task.ROOT).as_posix()],task.sha(path))


if __name__=="__main__":unittest.main()
