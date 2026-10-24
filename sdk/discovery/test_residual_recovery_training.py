"""Twenty-four zero-world integration and corruption controls for recovery learning."""
import copy
from contextlib import ExitStack
from itertools import islice
import json
import os
from pathlib import Path
import shutil
import unittest
from unittest.mock import patch
import uuid

import mujoco
import residual_recovery_training_task as task
import residual_recovery_training_native as worker
import audit_residual_recovery_training as reader
import run_residual_recovery_training as owner
import residual_recovery_native as original_worker
import audit_residual_recovery as original_reader
from residual_recovery_control import RecoveryController
from residual_recovery_metrics import transitions
from audit_gpu_batch_execution import same_bits
from gpu_measurement_probe import write_new


def write(path,value):
    path.write_text(json.dumps(value,allow_nan=False)+"\n",encoding="utf-8",newline="\n")


def put(path,rows):
    with path.open("w",encoding="utf-8",newline="\n") as stream:
        for row in rows:stream.write(json.dumps(row,separators=(",",":"),allow_nan=False)+"\n")


class RecoveryTrainingControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        guards=ExitStack();cls.addClassCleanup(guards.close)
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Recovery training controls open no world")))
        cls.core_path=Path(os.environ["QUADRUPED_TEST_CORE"]);cls.baseline=Path(os.environ["PORTABLE_BATCH_BASELINE_CORE"])
        cls.core=task.bridge.LocomotionCore(cls.core_path);cls.oracle=task.bridge.LocomotionCore(cls.baseline)
        cls.c=task.declaration("route");cls.pilot=task.declaration("pilot");cls.warm=task.warm_model(cls.core)
        cls.out=Path(os.environ["EXPLORER_TEST_OUTPUT"])
        cls.root=cls.out/("recovery-training-fixture-"+uuid.uuid4().hex);cls.root.mkdir()
        closure=task.read(task.CLOSURE);evidence=task.ROOT.parent/"SporeSpore_Evidence"
        attempt=evidence/closure["attempt_id"]
        task.require(task.sha(attempt/"receipt.json")==closure["receipt_sha256"],"Recovery training retained receipt")
        inventory={r["path"]:r for r in task.read(attempt/"receipt.json")["artifacts"]}
        original=attempt/"stages/comparison/physical/comparison_early_selected_left_075_train_001"
        bound={}
        def verified(path):
            row=inventory[path.relative_to(attempt).as_posix()]
            task.require(task.sha(path)==row["sha256"] and path.stat().st_size==row["byte_length"],"Recovery training retained inputs")
            bound[path.relative_to(evidence).as_posix()]=row["sha256"];return path
        cls.inputs={}
        for name,count in (("controller",120),("trace",600),("timing",120)):
            with verified(original/(name+".jsonl")).open(encoding="utf-8") as stream:
                cls.inputs[name]=[json.loads(s) for s in islice(stream,count)]
        cls.compiled=task.read(verified(original/"compiled.json"))
        cls.plan=next(p for p in task.trial_plans(cls.c,"comparison") if p["role"]=="initial_recovery")
        cls.folder=cls.root/"trial";cls.folder.mkdir();write(cls.folder/"plan.json",cls.plan)
        for name in ("compiled.json","inputs.json","model.xml","native-model.json"):
            shutil.copyfile(verified(original/name),cls.folder/name)
        (cls.folder/"provider-model.json").write_text(cls.warm.serialized,encoding="utf-8",newline="\n")
        cls.controls=cls.replay(cls.warm)
        for current,old in zip(cls.controls,cls.inputs["controller"],strict=True):
            task.require(same_bits(current["native_targets"],old["native_targets"]),"Recovery training replay changed solver input")
        put(cls.folder/"controller.jsonl",cls.controls)
        put(cls.folder/"trace.jsonl",cls.inputs["trace"]);put(cls.folder/"timing.jsonl",cls.inputs["timing"])
        write(cls.folder/"result.json",dict(cls.plan,setup_s=.1,graph_capture_s=0.,outer_rows=120,internal_rows=600,
            completed=True,controller_closed=True,provider_model_sha256=cls.warm.sha256,
            hashes={n:task.sha(cls.folder/(n+".jsonl")) for n in ("controller","trace","timing")}))
        write_new(cls.root/"input-bindings.json",dict(synthetic_control=True,retained_input_replay=True,
            original_inputs=bound,worlds_opened=0,solver_steps=0,new_physical_outcomes=False,
            counterfactual_replay_does_not_simulate_physics=True,
            synthetic_audit_rows_in_other_controls_are_not_training_data=True))

    @classmethod
    def replay(cls,model):
        host=RecoveryController(cls.core,cls.compiled,task.controller_contract(cls.c,model),
            model,"early_selected",cls.plan["trial_id"])
        result=[]
        try:
            for old in cls.inputs["controller"]:
                row=host.step(old["request"]["state"],old["stability"],old["kinematics"])
                row.update(backend="cpu",cell=0,outer_step=old["outer_step"],native_observation=old["native_observation"])
                result.append(row)
        finally:host.close()
        return result

    def attempt(self):
        root=self.out/("recovery-training-synthetic-"+uuid.uuid4().hex);root.mkdir();(root/"stages").mkdir()
        for name in ("declaration","gate-receipt","consumed"):
            write(root/(name+".json"),dict(source_commit="0"*40,synthetic_control=True))
        return root

    def audit_fixture(self,folder,c):
        claim,batch,models=task.load_stage(folder,c,self.core);rows=[]
        for plan in claim["trials"]:
            model=models[plan["model_key"]];search=plan["role"]=="search"
            moments=task.ars.Moments.empty(task.actor.features.DIMENSION).add(
                [[float(plan["sign"] or 0)]*task.actor.features.DIMENSION],partition="training")
            rows.append(dict(plan,provider_model_sha256=model.sha256,policy_sha256=model.policy.sha256,
                recovery_policy_sha256=model.recovery.policy.sha256,observations=task.training.moments_document(moments) if search else None,
                training_reward=-.2 if plan["sign"]==1 else -.4,reward_denominator=(c["outer_steps"]-60)*5,
                diagnostic_eligible=False,first_reward_failure=dict(internal_step=350,time_s=350/600),
                official_quality_m_s=None,comparison_data_used_for_training=False,
                paired_prefix=dict(identical_before_handoff=True,handoff_observation_identical=True,
                    reference_trial_id=folder.name+"_challenge_only_"+plan["group_id"])))
        return dict(ok=True,synthetic=False,synthetic_control=True,new_physical_outcomes=False,
            stage=folder.name,source_commit=claim["source_commit"],stage_claim_sha256=task.sha(folder/"stage.json"),
            training_data_scope=c["training_data_scope"],reader_world_build_count=0,reader_solver_steps=0,trials=rows)

    def prepare(self,c=None):
        c=c or self.c;root=self.attempt();folder=root/"stages/iteration_00"
        _,batch,_=task.prepare_stage(folder,c,self.core);audit=self.audit_fixture(folder,c)
        write(folder/"audit.json",audit);return root,folder,batch,audit

    def finish_update(self,folder,c):
        task.write_update(folder,c,self.core)
        write(folder/"verified-update.json",task.verify_update(folder,c,self.oracle))
        return task.verify_update(folder,c,self.core,require_verification=True)

    def trained_fixture(self,c=None):
        c=c or self.c;root,folder,_,_=self.prepare(c);self.finish_update(folder,c)
        for index in range(1,c["iterations"]):
            folder=root/"stages"/f"iteration_{index:02d}"
            task.prepare_stage(folder,c,self.core);write(folder/"audit.json",self.audit_fixture(folder,c))
            self.finish_update(folder,c)
        task.write_selection(root,c,self.core)
        write(root/"verified-selection.json",task.verify_selection(root,c,self.oracle))
        return root

    def test_01_declared_populations_and_finite_boundaries(self):
        self.assertEqual(task.EXPECTED_CONTROLS,327)
        for c,total,search,reference,comparison in ((self.c,7,2,1,4),(self.pilot,112,64,16,32)):
            plans=task.all_plans(c);self.assertEqual(len(plans),total)
            self.assertEqual(len({p["trial_id"] for p in plans}),total)
            self.assertEqual(sum(p["partition"]=="training" for p in plans),search)
            self.assertEqual(sum(p["partition"]=="development_reference" for p in plans),reference)
            self.assertEqual(sum(p["partition"]=="development_comparison" for p in plans),comparison)
            self.assertTrue(all(p["start_id"] in dict(task.training.STARTS) for p in plans))
            self.assertTrue(all(c[k] is (k=="training_data_authority") for k in task.FLAGS))
        self.assertFalse(self.c["official_quality_enabled"]);self.assertTrue(self.pilot["official_quality_enabled"])

    def test_02_changed_objective_counts_scaling_or_authority_rejected(self):
        for change in (lambda v:v["lanes"]["pilot"].__setitem__("planned_cpu_worlds",111),
            lambda v:v["recovery_objective"].__setitem__("handoff_command",59),
            lambda v:v["optimizer"].__setitem__("route_data_may_initialize_pilot",True),
            lambda v:v.__setitem__("release_authority",True)):
            value=task.read(task.CONTRACT);change(value);path=self.root/(uuid.uuid4().hex+".json");write(path,value)
            with patch.object(task,"CONTRACT",path):
                with self.assertRaisesRegex(ValueError,"declaration/source"):task.declaration("pilot")

    def test_03_warm_start_is_identical_on_both_cores(self):
        self.assertEqual(self.warm,task.warm_model(self.oracle))
        self.assertEqual(self.warm.actor.sha256,self.c["challenge_actor_sha256"])
        self.assertEqual(self.warm.recovery.sha256,self.c["warm_start_recovery_actor_sha256"])
        self.assertEqual(self.warm.warning.sha256,self.c["warning_model_sha256"])
        self.assertEqual(self.warm.sha256,self.c["warm_start_model_sha256"])

    def test_04_preflight_uses_unchanged_physics_and_reader(self):
        self.assertIs(worker.run_trial,original_worker.run_trial);self.assertIs(reader.audit_trial,original_reader.audit_trial)
        for lane,worlds in (("route",7),("pilot",112)):
            result=worker.preflight(self.core_path,self.baseline,lane)
            self.assertEqual((result["world_build_count"],result["solver_steps"]),(0,0))
            self.assertEqual(result["planned_cpu_worlds"],worlds)

    def test_05_real_retained_recovery_rows_support_training_score(self):
        result=reader.audit_trial(self.folder,self.plan,self.c,self.baseline,self.oracle,self.warm.document())
        score=task.score(self.controls,self.inputs["trace"],self.c,training=True)
        self.assertEqual((result["controller_rows"],result["internal_rows"]),(120,600))
        self.assertFalse(result["diagnostic_eligible"]);self.assertEqual(score["first_reward_failure"]["internal_step"],479)
        self.assertEqual(score["reward_denominator"],300);self.assertEqual(score["walking_reward_diagnostic"]["reward_denominator"],600)
        self.assertEqual(score["supported_feature_rows"]+sum(score["unsupported_feature_rows"].values()),120)
        self.assertGreater(score["supported_feature_rows"],0);self.assertGreater(sum(score["unsupported_feature_rows"].values()),0)
        self.assertIsNone(score["official_quality_m_s"])
        write_new(self.root/"retained-prefix-audit.json",dict(synthetic_control=True,worlds_opened=0,solver_steps=0,
            new_physical_outcomes=False,reader=result,score=score))

    def test_06_perturbed_actor_preserves_challenge_prefix_and_handoff_slew(self):
        batch=task.ars.ask(self.warm.recovery.policy,task.ars_plan(self.c,0))
        model=task.composite(self.core,self.warm,batch.candidate(0,1),self.warm.recovery.document()["corpus"])
        rows=self.replay(model)
        self.assertTrue(all(same_bits(a["native_targets"],b["native_targets"])
            for a,b in zip(rows[:60],self.controls[:60],strict=True)))
        self.assertTrue(any(a["native_targets"]!=b["native_targets"] for a,b in zip(rows[60:90],self.controls[60:90],strict=True)))
        result=transitions(rows,None,self.c,model,"early_selected")
        self.assertEqual(result["handoff_command"],60);self.assertFalse(result["reentry_permitted"])
        self.assertLessEqual(result["handoff"]["maximum_actual_correction_delta_rad_s"],.08+1e-15)

    def test_07_stage_artifacts_bind_exact_models_and_perturbations(self):
        _,folder,_,_=self.prepare()
        for name,change in (("stage.json",lambda v:v["trials"].pop()),
            ("batch.json",lambda v:v.__setitem__("batch_sha256","crossed"))):
            path=folder/name;old=path.read_bytes();value=task.read(path);change(value);write(path,value)
            with self.assertRaises(ValueError):task.load_stage(folder,self.c,self.core)
            path.write_bytes(old)
        path=folder/"models/d00_plus.json";old=path.read_bytes();path.write_bytes(old+b" ")
        with self.assertRaisesRegex(ValueError,"staged model"):task.load_stage(folder,self.c,self.core)

    def test_08_update_uses_recovery_policy_identity(self):
        _,folder,batch,audit=self.prepare()
        policy,record=task.update_from_audit(batch,audit,self.c,folder.name)
        self.assertNotEqual(policy.sha256,batch.policy.sha256)
        self.assertEqual(record["underlying_update"]["rollout_count"],2)
        bad=copy.deepcopy(audit);bad["trials"][1]["recovery_policy_sha256"]=bad["trials"][1]["policy_sha256"]
        with self.assertRaisesRegex(ValueError,"policy/reward/prefix"):task.update_from_audit(batch,bad,self.c,folder.name)

    def test_09_incomplete_crossed_or_reserved_training_population_rejected(self):
        _,folder,batch,audit=self.prepare()
        for change in (lambda v:v["trials"].pop(),lambda v:v["trials"].reverse(),
            lambda v:v["trials"].__setitem__(2,copy.deepcopy(v["trials"][1])),
            lambda v:v["trials"][1].__setitem__("partition","evaluation")):
            bad=copy.deepcopy(audit);change(bad)
            with self.assertRaises(ValueError):task.update_from_audit(batch,bad,self.c,folder.name)

    def test_10_reference_observations_or_training_authority_rejected(self):
        _,folder,batch,audit=self.prepare()
        for key,value in (("observations",audit["trials"][1]["observations"]),("training_data_authority",True)):
            bad=copy.deepcopy(audit);bad["trials"][0][key]=value
            with self.assertRaises(ValueError):task.update_from_audit(batch,bad,self.c,folder.name)

    def test_11_invalid_reward_or_unmatched_prefix_rejects_entire_update(self):
        _,folder,batch,audit=self.prepare()
        for change in (lambda r:r.__setitem__("reward_denominator",600),
            lambda r:r.__setitem__("training_reward",float("nan")),
            lambda r:r["paired_prefix"].__setitem__("identical_before_handoff",False),
            lambda r:r["paired_prefix"].__setitem__("handoff_observation_identical",False)):
            bad=copy.deepcopy(audit);change(bad["trials"][1])
            with self.assertRaises(ValueError):task.update_from_audit(batch,bad,self.c,folder.name)

    def test_12_observed_moments_do_not_change_deployed_scaling(self):
        _,folder,batch,audit=self.prepare()
        policy,record=task.update_from_audit(batch,audit,self.c,folder.name)
        self.assertEqual(policy.moments,self.warm.recovery.policy.moments)
        self.assertEqual(record["observed_moments"]["count"],batch.policy.moments.count+2)
        self.assertFalse(record["normalizer_updated"])
        self.assertEqual(batch.policy,self.warm.recovery.policy)

    def test_13_other_core_reconstructs_checkpoint_and_rejects_corruption(self):
        _,folder,_,_=self.prepare();result=self.finish_update(folder,self.c)
        self.assertEqual((result["world_build_count"],result["solver_steps"]),(0,0))
        for name in ("next-model.json","update.json"):
            path=folder/name;old=path.read_bytes();value=task.read(path);value["crossed"]=True;write(path,value)
            with self.assertRaises(ValueError):task.verify_update(folder,self.c,self.oracle)
            path.write_bytes(old)

    def test_14_next_stage_requires_exact_verified_update(self):
        root,folder,_,_=self.prepare(self.pilot);self.finish_update(folder,self.pilot)
        path=folder/"verified-update.json";old=path.read_bytes();path.unlink()
        following=root/"stages/iteration_01"
        with self.assertRaises(FileNotFoundError):task.stage_inputs(following,self.pilot,self.core)
        path.write_bytes(old);value=task.read(path);value["model_sha256"]="crossed";write(path,value)
        with self.assertRaisesRegex(ValueError,"verified update"):task.stage_inputs(following,self.pilot,self.core)
        path.write_bytes(old);_,_,parent,previous=task.stage_inputs(following,self.pilot,self.core)
        self.assertEqual(parent,"sha256:"+task.sha(folder/"next-model.json"));self.assertEqual(previous,task.sha(path))

    def test_15_selection_reconstructs_original_training_bytes_on_other_core(self):
        root=self.trained_fixture();record=task.read(root/"training-selection.json")
        self.assertEqual(record["selection"]["candidate_count"],2)
        self.assertEqual(record["selection"]["selected_candidate_id"],"iteration_00/d00_plus")
        self.assertEqual((root/"selected-model.json").read_bytes(),(root/record["selected_source"]).read_bytes())
        self.assertEqual(task.verify_selection(root,self.c,self.core),task.verify_selection(root,self.c,self.oracle))
        self.assertFalse(record["selection"]["comparison_data_used_for_selection"])

    def test_16_changed_selection_or_selected_model_rejected(self):
        root=self.trained_fixture()
        for name in ("selected-model.json","training-selection.json"):
            path=root/name;old=path.read_bytes();value=task.read(path);value["crossed"]=True;write(path,value)
            with self.assertRaises(ValueError):task.verify_selection(root,self.c,self.oracle)
            path.write_bytes(old)
        path=root/"verified-selection.json";value=task.read(path);value["model_sha256"]="crossed";write(path,value)
        with self.assertRaisesRegex(ValueError,"verified selection"):
            task.verify_selection(root,self.c,self.oracle,require_verification=True)

    def test_17_comparison_requires_frozen_selection_and_cannot_fit(self):
        root=self.trained_fixture();path=root/"verified-selection.json";old=path.read_bytes();path.unlink()
        folder=root/"stages/comparison"
        with self.assertRaises(FileNotFoundError):task.stage_inputs(folder,self.c,self.core)
        path.write_bytes(old);claim,batch,models=task.prepare_stage(folder,self.c,self.core)
        self.assertIsNone(batch);self.assertEqual(set(models),{"initial_recovery","trained_final","training_selected"})
        self.assertEqual(claim["verified_selection_sha256"],task.sha(path))
        write(folder/"batch.json",dict(synthetic_control=True))
        with self.assertRaisesRegex(ValueError,"cannot fit"):task.load_stage(folder,self.c,self.core)

    def test_18_two_updates_and_all_eight_groups_feed_prospective_selection(self):
        root=self.trained_fixture(self.pilot);record=task.read(root/"training-selection.json")
        self.assertEqual(record["selection"]["candidate_count"],8)
        self.assertEqual(len(record["selection"]["training_groups"]),8)
        self.assertEqual(len(record["stage_bindings"]),2)
        final=task.provider.FrozenModel.load(self.core,task.read(root/"stages/iteration_01/next-model.json"))
        self.assertEqual(final.recovery.policy.moments,self.warm.recovery.policy.moments)
        self.assertEqual(final.actor,self.warm.actor);self.assertEqual(final.warning,self.warm.warning)
        self.assertFalse(task.verify_selection(root,self.pilot,self.oracle)["comparison_data_used_for_selection"])

    def comparison(self):
        return [dict(p,observations=None,comparison_data_used_for_training=False,diagnostic_eligible=False,
            official_quality_m_s=None,first_reward_failure=dict(internal_step=400),training_reward=-.8,
            provider_model_sha256=self.warm.sha256,
            paired_prefix=dict(identical_before_handoff=True,handoff_observation_identical=True,
                reference_trial_id="comparison_challenge_only_"+p["group_id"]))
            for p in task.trial_plans(self.pilot,"comparison")]

    def test_19_complete_negative_comparison_is_a_retained_result(self):
        result=task.assess_comparison(self.comparison(),self.pilot)
        self.assertEqual((result["selected_eligible"],result["selected_total"]),(0,8))
        self.assertFalse(result["finite_development_screen_passed"]);self.assertFalse(result["tier2_qualified"])
        self.assertFalse(result["safe_backup_established"]);self.assertFalse(result["release_authority"])

    def test_20_missing_fitted_uncensored_or_unmatched_comparisons_rejected(self):
        for change in (lambda v:v.pop(),lambda v:v.reverse(),lambda v:v[1].__setitem__("observations",{}),
            lambda v:v[1].__setitem__("official_quality_m_s",.1),
            lambda v:v[1]["paired_prefix"].__setitem__("handoff_observation_identical",False),
            lambda v:v[1]["paired_prefix"].__setitem__("reference_trial_id","crossed")):
            rows=self.comparison();change(rows)
            with self.assertRaises(ValueError):task.assess_comparison(rows,self.pilot)

    def test_21_launch_requires_complete_gate_identity_and_containment(self):
        root=self.attempt();evidence=root/"SporeSpore_Evidence";evidence.mkdir()
        attempt=evidence/"sdk2-recovery-training-synthetic";physical=attempt/"stages/iteration_00/physical";physical.mkdir(parents=True)
        source="0"*40;write(attempt/"declaration.json",dict(contract=self.c,source_commit=source,synthetic=False,synthetic_control=True))
        counts={n:k for n,_,k in task.GATES};counts.update(provider=2,containment=1)
        gate=dict(ok=True,source_commit=source,safety_controls=counts,declaration_sha256=task.sha(attempt/"declaration.json"),
            preflight=dict(ok=True,world_build_count=0,solver_steps=0))
        write(attempt/"gate-receipt.json",gate)
        consumed=dict(attempt_id=attempt.name,source_commit=source,lane="route",contract_sha256=task.sha(task.CONTRACT),
            declaration_sha256=task.sha(attempt/"declaration.json"),gate_receipt_sha256=task.sha(attempt/"gate-receipt.json"),
            trials=task.all_plans(self.c))
        write(attempt/"consumed.json",consumed)
        with patch.object(task,"ROOT",root/"repo"):
            task.validate_launch_records(physical,self.c,source)
            value=copy.deepcopy(gate);value["safety_controls"]["recovery-training"]-=1;write(attempt/"gate-receipt.json",value)
            with self.assertRaisesRegex(ValueError,"complete zero-world"):task.validate_launch_records(physical,self.c,source)
            write(attempt/"gate-receipt.json",gate)
            with self.assertRaisesRegex(ValueError,"owner freeze"):task.validate_launch_records(physical,self.c,"1"*40)
            consumed["trials"].pop();write(attempt/"consumed.json",consumed)
            with self.assertRaisesRegex(ValueError,"consumed claim"):task.validate_launch_records(physical,self.c,source)
        with self.assertRaisesRegex(ValueError,"requires containment"):worker.run(self.out,self.out/"missing",self.core_path,self.baseline,"route")

    def test_22_partial_world_counts_remain_honest_lower_bounds(self):
        root=self.attempt();plan=task.all_plans(self.c)[0];trial=root/"stages/iteration_00/physical"/plan["trial_id"]
        trial.mkdir(parents=True);write(trial/"world-opened.json",dict(native_data_constructed=True,trial_id=trial.name,core_sha256=self.c["core_sha256"]))
        receipt=dict(requested_stages=["iteration_00"],contract=self.c,planned_trials=task.all_plans(self.c),error="contained timeout",ok=False)
        owner.capture_worker_state(receipt,root)
        self.assertEqual(receipt["constructed_cpu_worlds_lower_bound"],1);self.assertNotIn("constructed_cpu_worlds",receipt)
        self.assertTrue(receipt["physical_started"]);self.assertFalse(receipt["ok"]);self.assertEqual(receipt["error"],"contained timeout")

    def test_23_pilot_requires_same_freeze_complete_route_inventory(self):
        root=self.attempt();evidence=root/"SporeSpore_Evidence";evidence.mkdir()
        folder=evidence/"sdk2-recovery-training-synthetic-route";folder.mkdir()
        selected=dict(ok=True,comparison_data_used_for_selection=False);write(folder/"verified-selection.json",selected)
        receipt=dict(ok=True,synthetic=False,synthetic_control=True,source_commit="0"*40,contract=self.c,binding={},
            source_runtime_unchanged=True,zero_world_gate_passed=True,physical_started=True,constructed_cpu_worlds=7,
            constructed_gpu_worlds=0,completed_stages=task.stages(self.c),selection_verification=selected)
        receipt["artifacts"]=owner.inventory(folder);write(folder/"receipt.json",receipt)
        with patch.object(owner,"ROOT",root/"repo"):
            result=owner.validate_route_attempt(folder,"0"*40,self.pilot,{})
            self.assertFalse(result["training_initialization"])
            for key,value in (("constructed_cpu_worlds",6),("synthetic",True),("source_commit","1"*40)):
                bad=copy.deepcopy(receipt);bad[key]=value;write(folder/"receipt.json",bad)
                with self.assertRaises(ValueError):owner.validate_route_attempt(folder,"0"*40,self.pilot,{})
            write(folder/"receipt.json",receipt);write(folder/"crossed.json",dict(synthetic_control=True))
            with self.assertRaisesRegex(ValueError,"artifact integrity"):owner.validate_route_attempt(folder,"0"*40,self.pilot,{})

    def test_24_all_training_sources_components_and_prior_artifacts_are_bound(self):
        value=owner.bindings(self.core_path,self.baseline)
        for path in [task.HERE/n for n in task.SOURCES]+[task.CONTRACT,*task.ARTIFACTS,*task.COMPONENTS]:
            self.assertEqual(value["source"][path.relative_to(task.ROOT).as_posix()],task.sha(path))


if __name__=="__main__":unittest.main()
