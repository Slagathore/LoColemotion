"""Zero-world corruption controls for native training and complete update handoff."""
import copy
import json
from pathlib import Path
from unittest.mock import patch
import unittest
import uuid

import test_residual_native as base
import residual_training_task as task
import residual_training as worker
import audit_residual_training as reader
import run_residual_training as owner


class TrainingControls(base.NativeResidualControls):
    """Run all fourteen native corruption controls against the successor reader."""
    @classmethod
    def setUpClass(cls):
        patched=patch.object(base.reader,"audit_trial",reader.audit_trial)
        patched.start();cls.addClassCleanup(patched.stop)
        super().setUpClass()
        cls.tc=task.declaration("route")

    def score_rows(self):
        folder=self.folder/self.plans[2]["trial_id"]
        controls=base.rows(folder/"controller.jsonl");trace=base.rows(folder/"trace.jsonl")
        for row in trace:row["qvel"][0]=.2;row["qvel"][1]=0.
        return controls,trace

    def update_fixture(self):
        """Native-shaped metadata is a test input, never a physical transition."""
        root=self.out/("training-synthetic-"+uuid.uuid4().hex);root.mkdir();(root/"stages").mkdir()
        base.write(root/"fixture-metadata.json",dict(synthetic_control=True,constructed_worlds=0,
            solver_steps=0,training_data_authority=False,native_shaped_claims_are_corruption_test_inputs=True))
        base.write(root/"declaration.json",dict(source_commit="0"*40,synthetic=True,contract=self.tc))
        base.write(root/"gate-receipt.json",dict(synthetic_control=True))
        base.write(root/"consumed.json",dict(synthetic_control=True))
        folder=root/"stages/iteration_00"
        claim,batch,models=task.prepare_stage(folder,self.tc,self.core)
        trials=[]
        for plan in claim["trials"]:
            policy=batch.candidate(plan["direction"],plan["sign"])
            moment=task.ars.Moments.empty(task.provider.features.DIMENSION).add(
                [[float(plan["sign"])]*task.provider.features.DIMENSION],partition="training")
            trials.append(dict(plan,policy_sha256=policy.sha256,reward_denominator=600,
                training_reward=-.2 if plan["sign"]==1 else -.7,observations=task.moments_document(moment)))
        audit=dict(ok=True,synthetic=False,source_commit="0"*40,stage=folder.name,
            training_data_scope=self.tc["training_data_scope"],stage_claim_sha256=task.sha(folder/"stage.json"),
            reader_world_build_count=0,reader_solver_steps=0,trials=trials)
        base.write(folder/"audit.json",audit)
        return folder,batch,audit

    def test_training_declaration_exact_groups_horizons_sources_and_gate(self):
        program=task.read(task.CONTRACT)
        self.assertEqual(program,task.expected_declaration())
        self.assertEqual(task.EXPECTED_CONTROLS,104)
        for lane,count,commands in (("route",3,120),("pilot",88,1440)):
            c=task.declaration(lane);plans=task.all_plans(c)
            self.assertEqual((len(plans),c["outer_steps"]),(count,commands))
            self.assertEqual(len({p["trial_id"] for p in plans}),count)
            self.assertTrue(all(p["initial_native_lateral_velocity_m_s"] not in c["reserved_starts"]+
                c["excluded_confirmation_starts"] for p in plans))
        pilot=task.declaration("pilot")
        self.assertEqual(len(pilot["groups"]),8)
        self.assertEqual(sum(p["partition"]=="training" for p in task.all_plans(pilot)),64)
        self.assertFalse(pilot["optimizer"]["route_data_may_initialize_pilot"])
        for mutate in (lambda d:d["lanes"]["pilot"].__setitem__("outer_steps",120),
                lambda d:d["reward"].__setitem__("survival_bonus",2.),
                lambda d:d["implementation_bindings"].__setitem__("residual_training.py","0"*64)):
            value=copy.deepcopy(program);mutate(value)
            path=self.out/("bad-training-contract-"+uuid.uuid4().hex+".json");base.write(path,value)
            with patch.object(task,"CONTRACT",path):
                with self.assertRaisesRegex(ValueError,"declaration/source"):task.declaration("pilot")

    def test_training_preflight_both_conditions_and_complete_denominators(self):
        for lane,worlds,outer in (("route",3,120),("pilot",88,1440)):
            value=worker.preflight(self.core_path,self.baseline,lane)
            self.assertTrue(value["ok"])
            self.assertEqual((value["world_build_count"],value["solver_steps"]),(0,0))
            self.assertEqual((value["planned_cpu_worlds"],value["planned_controller_rows"],value["planned_internal_rows"]),
                (worlds,worlds*outer,worlds*outer*5))

    def test_reward_tracking_standing_and_failure_padding_use_fixed_horizon(self):
        controls,trace=self.score_rows()
        target=task.score(controls,trace,self.tc,training=True)
        self.assertEqual(target["training_reward"],0.)
        for row in trace:row["qvel"][0]=0.
        standing=task.score(controls,trace,self.tc,training=True)
        self.assertEqual(standing["training_reward"],-.5)
        trace[9]["qpos"][2]=.1
        failed=task.score(controls,trace,self.tc,training=True)
        self.assertEqual(failed["first_reward_failure"]["internal_step"],10)
        self.assertEqual((failed["failure_padded_samples"],failed["reward_denominator"]),(591,600))
        self.assertEqual(failed["training_reward"],(-.5*9-591)/600)
        self.assertIsNone(failed["official_quality_m_s"])

    def test_safe_no_actuation_masks_from_command_start_and_missing_rows_refuse(self):
        controls,trace=self.score_rows()
        controls[2]["output"]["actuation"]["safe_no_actuation"]=True
        value=task.score(controls,trace,self.tc,training=True)
        self.assertEqual(value["first_reward_failure"]["internal_step"],11)
        self.assertEqual(value["training_reward"],-590/600)
        with self.assertRaisesRegex(ValueError,"full horizon"):task.score(controls,trace[:-1],self.tc,training=True)
        trace[20]["step"]=19
        with self.assertRaisesRegex(ValueError,"internal order"):task.score(controls,trace,self.tc,training=True)

    def test_moments_include_valid_negative_rows_and_explicit_unsupported_denominator(self):
        controls,trace=self.score_rows();trace[5]["qpos"][2]=.1
        controls[3]["residual"]["decision"].update(features=None,reason="unsupported_observation: test domain")
        value=task.score(controls,trace,self.tc,training=True)
        self.assertEqual(value["supported_feature_rows"],119)
        self.assertEqual(value["unsupported_feature_rows"],{"unsupported_observation: test domain":1})
        self.assertEqual(value["observations"]["count"],119)
        comparison=task.score(controls,trace,self.tc,training=False)
        self.assertIsNone(comparison["observations"])
        controls[3]["residual"]["decision"]["reason"]="silently dropped"
        with self.assertRaisesRegex(ValueError,"missing feature reason"):task.score(controls,trace,self.tc,training=True)
        for row in controls:row["residual"]["decision"].update(features=None,reason="unsupported_observation: all")
        with self.assertRaisesRegex(ValueError,"feature denominator"):task.score(controls,trace,self.tc,training=True)

    def test_official_quality_uses_existing_windows_and_failed_quality_stays_null(self):
        controls,trace=self.score_rows();enabled=dict(self.tc,official_quality_enabled=True)
        value=task.score(controls,trace,enabled,training=False)
        self.assertEqual(len(value["official_windows"]),4)
        self.assertEqual(value["official_quality_m_s"],sum(w["quality_m_s"] for w in value["official_windows"])/4)
        route=task.score(controls,trace,self.tc,training=False)
        self.assertIsNone(route["official_quality_m_s"])
        trace[-1]["qpos"][2]=.1
        failed=task.score(controls,trace,enabled,training=False)
        self.assertEqual(failed["official_windows"],[])
        self.assertIsNone(failed["official_quality_m_s"])

    def test_complete_paired_update_rejects_missing_reserved_crossed_and_nonfinite_inputs(self):
        folder,batch,audit=self.update_fixture()
        policy,record=task.update_from_audit(batch,audit,self.tc,folder.name)
        self.assertEqual(policy.moments.count,2)
        self.assertNotEqual(policy.weights,batch.policy.weights)
        self.assertEqual(record["rollout_count"],2)
        mutations=[lambda v:v["trials"].pop(),lambda v:v["trials"].reverse(),
            lambda v:v["trials"][0].__setitem__("partition","evaluation"),
            lambda v:v["trials"][0].__setitem__("training_reward",float("nan")),
            lambda v:v["trials"][0].__setitem__("policy_sha256","sha256:"+"0"*64),
            lambda v:v.__setitem__("synthetic",True),lambda v:v.__setitem__("training_data_scope","other")]
        for mutate in mutations:
            value=copy.deepcopy(audit);mutate(value)
            with self.assertRaises(ValueError):task.update_from_audit(batch,value,self.tc,folder.name)

    def test_stored_perturbations_model_bytes_and_stage_claim_are_all_bound(self):
        folder,batch,audit=self.update_fixture()
        expected=task.read(folder/"batch.json");corrupt=copy.deepcopy(expected);corrupt["perturbations"][0][0][0]+=.1
        base.write(folder/"batch.json",corrupt)
        with self.assertRaisesRegex(ValueError,"perturbation/parent"):task.load_stage(folder,self.tc,self.core)
        base.write(folder/"batch.json",expected)
        model=folder/"models/d00_plus.json";encoded=model.read_bytes();value=task.read(model);value["policy"]["weights"][0][0]+=.1
        base.write(model,value)
        with self.assertRaisesRegex(ValueError,"staged immutable model"):task.load_stage(folder,self.tc,self.core)
        model.write_bytes(encoded)
        claim=task.read(folder/"stage.json");claim["parent_model_sha256"]="sha256:"+"0"*64;base.write(folder/"stage.json",claim)
        with self.assertRaisesRegex(ValueError,"claim/model lineage"):task.load_stage(folder,self.tc,self.core)

    def test_next_stage_requires_exact_independently_verified_update(self):
        folder,batch,audit=self.update_fixture();task.write_update(folder,self.tc,self.core)
        verified=task.verify_update(folder,self.tc,self.oracle)
        self.assertEqual(verified["normalizer_sample_count"],2)
        self.assertEqual((verified["world_build_count"],verified["solver_steps"]),(0,0))
        following=folder.parent/"comparison";following.mkdir()
        with self.assertRaises(FileNotFoundError):task.stage_inputs(following,self.tc,self.core)
        base.write(folder/"verified-update.json",verified)
        _,models,_,_=task.stage_inputs(following,self.tc,self.core)
        self.assertEqual(models["trained"].policy.sha256,verified["policy_sha256"])
        artifact=models["trained"].document()
        self.assertEqual(artifact["corpus"]["kind"],"development_training_checkpoint")
        self.assertEqual(artifact["corpus"]["source_record_sha256"],"sha256:"+task.sha(folder/"update.json"))
        value=task.read(folder/"update.json");value["update"]["normalizer_sample_count"]+=1;base.write(folder/"update.json",value)
        with self.assertRaisesRegex(ValueError,"update reconstruction"):task.stage_inputs(following,self.tc,self.core)

    def test_final_screen_requires_all_groups_nominal_preservation_and_disabled_identity(self):
        c=task.declaration("pilot");trials=[]
        for plan in task.trial_plans(c,"comparison"):
            trials.append(dict(plan,observations=None,comparison_data_used_for_training=False,diagnostic_eligible=True,
                official_quality_m_s=-.1,raw_hashes=dict(trace="a"*64),nonzero_correction_commands=0))
        value=task.assess_comparison(trials,c)
        self.assertTrue(value["finite_development_screen_passed"]);self.assertFalse(value["tier2_qualified"])
        for condition in ("left_075","nominal"):
            negative=copy.deepcopy(trials);row=next(r for r in negative if r["condition_id"]==condition and r["role"]=="trained")
            row.update(diagnostic_eligible=False,official_quality_m_s=None)
            self.assertFalse(task.assess_comparison(negative,c)["finite_development_screen_passed"])
        lower=copy.deepcopy(trials);next(r for r in lower if r["condition_id"]=="nominal" and r["role"]=="trained")["official_quality_m_s"]=-.11
        self.assertFalse(task.assess_comparison(lower,c)["finite_development_screen_passed"])
        crossed=copy.deepcopy(trials);next(r for r in crossed if r["role"]=="disabled")["raw_hashes"]["trace"]="b"*64
        with self.assertRaisesRegex(ValueError,"disabled changed"):task.assess_comparison(crossed,c)
        with self.assertRaisesRegex(ValueError,"comparison population"):task.assess_comparison(trials[:-1],c)

    def test_training_launch_requires_full_gate_source_claim_and_verified_route(self):
        control=self.out/("training-launch-control-"+uuid.uuid4().hex);control.mkdir()
        evidence=control/"SporeSpore_Evidence";evidence.mkdir()
        attempt=evidence/"sdk2-residual-training-synthetic-claim";physical=attempt/"stages/iteration_00/physical"
        physical.mkdir(parents=True);source="0"*40
        base.write(attempt/"declaration.json",dict(contract=self.tc,source_commit=source,synthetic=False,synthetic_control=True))
        counts={n:c for n,_,c in task.GATES};counts.update(provider=2,containment=1)
        gate=dict(ok=True,source_commit=source,safety_controls=counts,declaration_sha256=task.sha(attempt/"declaration.json"),
            preflight=dict(ok=True,world_build_count=0,solver_steps=0))
        base.write(attempt/"gate-receipt.json",gate)
        consumed=dict(attempt_id=attempt.name,source_commit=source,lane="route",contract_sha256=task.sha(task.CONTRACT),
            declaration_sha256=task.sha(attempt/"declaration.json"),gate_receipt_sha256=task.sha(attempt/"gate-receipt.json"),
            trials=task.all_plans(self.tc));base.write(attempt/"consumed.json",consumed)
        with patch.object(task,"ROOT",control/"repo"):
            task.validate_launch_records(physical,self.tc,source)
            bad=copy.deepcopy(gate);bad["safety_controls"]["residual-training"]-=1;base.write(attempt/"gate-receipt.json",bad)
            with self.assertRaisesRegex(ValueError,"complete zero-world"):task.validate_launch_records(physical,self.tc,source)
            base.write(attempt/"gate-receipt.json",gate)
            with self.assertRaisesRegex(ValueError,"owner freeze"):task.validate_launch_records(physical,self.tc,"1"*40)
            bad=copy.deepcopy(consumed);bad["trials"].pop();base.write(attempt/"consumed.json",bad)
            with self.assertRaisesRegex(ValueError,"consumed claim"):task.validate_launch_records(physical,self.tc,source)
        with self.assertRaisesRegex(ValueError,"requires containment"):
            worker.run(self.out,self.out/"no-permit",self.core_path,self.baseline,"route")
        with self.assertRaisesRegex(ValueError,"verified execution fixture"):
            owner.validate_route_attempt(None,source,task.declaration("pilot"),{})
        with self.assertRaisesRegex(ValueError,"route evidence boundary"):
            owner.validate_route_attempt(self.out,source,task.declaration("pilot"),{})

    def test_training_partial_world_count_and_manifest_remain_honest(self):
        folder=self.out/("training-partial-"+uuid.uuid4().hex)
        first=folder/"stages/iteration_00/physical";second=folder/"stages/comparison/physical"
        first.mkdir(parents=True);second.mkdir(parents=True)
        base.write(first/"worker-result.json",dict(constructed_cpu_worlds=2,constructed_gpu_worlds=0))
        (second/"worker-result.json").write_text("{",encoding="utf-8")
        receipt=dict(requested_stages=["iteration_00","comparison"],contract=self.tc,planned_trials=task.all_plans(self.tc),
            error="contained timeout",ok=False)
        owner.capture_worker_state(receipt,folder)
        self.assertEqual(receipt["constructed_cpu_worlds_lower_bound"],2)
        self.assertNotIn("constructed_cpu_worlds",receipt)
        self.assertEqual(receipt["error"],"contained timeout")
        self.assertTrue(receipt["physical_started"])
        binding=owner.bindings(self.core_path,self.baseline)
        for path in [task.HERE/name for name in task.SOURCES]+[task.CONTRACT]:
            self.assertEqual(binding["source"][path.relative_to(task.ROOT).as_posix()],task.sha(path))


if __name__=="__main__":unittest.main()
