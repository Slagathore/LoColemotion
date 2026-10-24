"""Complete selection, artifact, launch and fresh-comparison corruption controls."""
import ast
import copy
from pathlib import Path
from unittest.mock import patch
import unittest
import uuid

import test_residual_native as base
import residual_selection as fit
import residual_selection_task as task
import residual_selection_native as worker
import audit_residual_selection as reader
import run_residual_selection as owner


class SelectionControls(base.NativeResidualControls):
    """Retain all fourteen native corruption controls against this reader."""
    @classmethod
    def setUpClass(cls):
        changed=patch.object(base.reader,"audit_trial",reader.audit_trial)
        changed.start();cls.addClassCleanup(changed.stop)
        super().setUpClass()
        cls.sc=task.declaration()
        cls.training,cls.candidates,_=fit.retained_population()

    def test_declaration_exact_full_horizon_population_and_gate(self):
        self.assertEqual(task.read(task.CONTRACT),task.expected_declaration())
        self.assertEqual(task.EXPECTED_CONTROLS,138)
        plans=task.all_plans(self.sc)
        self.assertEqual((len(plans),self.sc["outer_steps"]),(24,1440))
        self.assertEqual(len({p["trial_id"] for p in plans}),24)
        self.assertEqual({p["role"] for p in plans},{"baseline","disabled","selected"})
        self.assertTrue(all(p["partition"]=="development_comparison" and not p["training_data_authority"]
            and p["initial_native_lateral_velocity_m_s"] not in self.sc["reserved_starts"]+
                self.sc["excluded_confirmation_starts"] for p in plans))
        self.assertTrue(all(self.sc[k] is False for k in task.FLAGS))
        for change in (lambda v:v.__setitem__("outer_steps",120),
                lambda v:v.__setitem__("selected_model_sha256","sha256:"+"0"*64),
                lambda v:v.__setitem__("training_data_authority",True)):
            value=copy.deepcopy(self.sc);change(value)
            path=self.out/("bad-selection-"+uuid.uuid4().hex+".json");base.write(path,value)
            with patch.object(task,"CONTRACT",path):
                with self.assertRaisesRegex(ValueError,"declaration/source"):task.declaration()

    def test_complete_retained_population_selection_and_both_core_artifacts(self):
        expected,_=fit.expected_fit()
        self.assertEqual((expected["decision"]["candidate_count"],expected["decision"]["training_trial_count"]),(8,64))
        self.assertEqual(expected["decision"]["eligible_candidate_ids"],["iteration_00/d00_plus"])
        self.assertTrue(expected["selection_is_retrospective"])
        self.assertEqual((expected["comparison_trials_used_for_selection"],expected["route_trials_used_for_selection"]),(0,0))
        models=[]
        for core in (self.core,self.oracle):
            record,model=fit.verify_fit(core);models.append(model)
            self.assertEqual(record,expected)
            self.assertEqual(model.document()["corpus"]["kind"],"untrained_development_probe")
            self.assertEqual(model.policy.moments.count,0)
        self.assertEqual(models[0],models[1])

    def test_missing_duplicate_reordered_or_crossed_candidates_refuse(self):
        for change in (lambda v:v.pop(),lambda v:v.append(v[0]),lambda v:v.reverse(),
                lambda v:v[0].__setitem__("stage","comparison")):
            value=copy.deepcopy(self.candidates);change(value)
            with self.assertRaisesRegex(ValueError,"candidate population"):fit.select_population(value,self.training)

    def test_training_group_denominators_partitions_scores_and_models_refuse(self):
        changes=[lambda v:v[0]["trials"].pop(),lambda v:v[0]["trials"].reverse(),
            lambda v:v[0]["trials"][0].__setitem__("partition","development_comparison"),
            lambda v:v[0]["trials"][0].__setitem__("training_reward",float("nan")),
            lambda v:v[0]["trials"][0].__setitem__("reward_denominator",600),
            lambda v:v[0]["trials"][0].__setitem__("provider_model_sha256","sha256:"+"0"*64),
            lambda v:v[0]["trials"][0].__setitem__("comparison_data_used_for_training",True)]
        for change in changes:
            value=copy.deepcopy(self.candidates);change(value)
            with self.assertRaises(ValueError):fit.select_population(value,self.training)

    def test_all_group_eligibility_precedes_reward_and_no_candidate_refuses(self):
        value=copy.deepcopy(self.candidates)
        # A high reward cannot hide one failed group or erase its denominator.
        failed=value[0]["trials"][0]
        failed.update(diagnostic_eligible=False,first_reward_failure=dict(internal_step=1),
            official_quality_m_s=None,training_reward=0.)
        decision=fit.select_population(value,self.training)
        self.assertIsNone(decision["selected_candidate_id"])
        self.assertEqual(decision["training_trial_count"],64)
        self.assertEqual(decision["candidates"][0]["eligible_groups"],7)

    def test_group_mean_ranking_and_lexical_tie_are_deterministic(self):
        value=copy.deepcopy(self.candidates)
        for candidate in value[:2]:
            for row in candidate["trials"]:
                row.update(diagnostic_eligible=True,first_reward_failure=None,official_quality_m_s=-.1,training_reward=-.25)
        tied=fit.select_population(value,self.training)
        self.assertEqual(tied["selected_candidate_id"],"iteration_00/d00_minus")
        for row in value[0]["trials"]:row["training_reward"]=-.2
        higher=fit.select_population(value,self.training)
        self.assertEqual(higher["selected_candidate_id"],"iteration_00/d00_plus")

    def test_model_and_selection_cannot_be_rewritten_or_relabelled(self):
        expected,path=fit.expected_fit();encoded=path.read_bytes()
        fit.validate_frozen(expected,copy.deepcopy(expected),encoded,encoded,self.core)
        for change in (lambda v:v["decision"].__setitem__("selected_candidate_id","iteration_01/d01_plus"),
                lambda v:v.__setitem__("selection_is_retrospective",False),
                lambda v:v.__setitem__("release_authority",True),
                lambda v:v["decision"]["candidates"].pop()):
            value=copy.deepcopy(expected);change(value)
            with self.assertRaises(ValueError):fit.validate_frozen(expected,value,encoded,encoded,self.core)
        with self.assertRaises(ValueError):fit.validate_frozen(expected,expected,encoded+b" ",encoded,self.core)

    def test_preflight_selected_model_both_conditions_and_unchanged_native_loop(self):
        value=worker.preflight(self.core_path,self.baseline,"comparison")
        self.assertEqual((value["world_build_count"],value["solver_steps"]),(0,0))
        self.assertEqual((value["planned_cpu_worlds"],value["planned_controller_rows"],value["planned_internal_rows"]),(24,34560,172800))
        def function(path,name):
            source=path.read_text()
            node=next(n for n in ast.parse(source).body if isinstance(n,ast.FunctionDef) and n.name==name)
            return ast.get_source_segment(source,node)
        self.assertEqual(function(task.HERE/"residual_training.py","run_trial"),
            function(task.HERE/"residual_selection_native.py","run_trial"))
        self.assertEqual(function(task.HERE/"audit_residual_training.py","audit_trial"),
            function(task.HERE/"audit_residual_selection.py","audit_trial"))

    def test_stage_exact_fit_artifact_and_no_optimizer_update(self):
        root=self.out/("selected-stage-synthetic-"+uuid.uuid4().hex);root.mkdir();(root/"stages").mkdir()
        base.write(root/"fixture-metadata.json",dict(synthetic_control=True,worlds_opened=0,solver_steps=0))
        base.write(root/"declaration.json",dict(source_commit="0"*40,synthetic=True))
        base.write(root/"gate-receipt.json",dict(synthetic_control=True));base.write(root/"consumed.json",dict(synthetic_control=True))
        folder=root/"stages/comparison";claim,batch,models=task.prepare_stage(folder,self.sc,self.core)
        self.assertIsNone(batch)
        self.assertEqual(models["selected"].sha256,self.sc["selected_model_sha256"])
        artifact=folder/"models/selected.json";original=artifact.read_bytes()
        artifact.write_bytes(original+b" ")
        with self.assertRaisesRegex(ValueError,"staged model"):task.load_stage(folder,self.sc,self.core)
        artifact.write_bytes(original)
        bad=copy.deepcopy(claim);bad["selection_record_sha256"]="0"*64;base.write(folder/"stage.json",bad)
        with self.assertRaisesRegex(ValueError,"stage claim"):task.load_stage(folder,self.sc,self.core)
        base.write(folder/"stage.json",claim);base.write(folder/"update.json",dict(synthetic_control=True))
        with self.assertRaisesRegex(ValueError,"cannot fit"):task.load_stage(folder,self.sc,self.core)
        with self.assertRaisesRegex(ValueError,"cannot fit"):task.score([],[],self.sc,training=True)

    def test_fresh_screen_complete_eligibility_healthy_quality_and_disabled_identity(self):
        rows=[dict(p,observations=None,comparison_data_used_for_training=False,diagnostic_eligible=True,
            official_quality_m_s=-.1,raw_hashes=dict(trace="a"*64),nonzero_correction_commands=0)
            for p in task.all_plans(self.sc)]
        result=task.assess_comparison(rows,self.sc)
        self.assertTrue(result["finite_development_screen_passed"]);self.assertFalse(result["tier2_qualified"])
        for condition in ("left_075","nominal"):
            changed=copy.deepcopy(rows)
            next(r for r in changed if r["condition_id"]==condition and r["role"]=="selected").update(
                diagnostic_eligible=False,official_quality_m_s=None)
            self.assertFalse(task.assess_comparison(changed,self.sc)["finite_development_screen_passed"])
        lower=copy.deepcopy(rows)
        next(r for r in lower if r["condition_id"]=="nominal" and r["role"]=="selected")["official_quality_m_s"]=-.11
        self.assertFalse(task.assess_comparison(lower,self.sc)["finite_development_screen_passed"])
        for change in (lambda v:v.pop(),lambda v:v.reverse(),lambda v:v[0].__setitem__("observations",{}),
                lambda v:next(r for r in v if r["role"]=="disabled")["raw_hashes"].__setitem__("trace","b"*64)):
            changed=copy.deepcopy(rows);change(changed)
            with self.assertRaises(ValueError):task.assess_comparison(changed,self.sc)

    def test_launch_needs_full_gate_exact_source_consumed_population_and_containment(self):
        control=self.out/("selection-launch-control-"+uuid.uuid4().hex);control.mkdir()
        evidence=control/"SporeSpore_Evidence";evidence.mkdir()
        attempt=evidence/"sdk2-residual-selection-synthetic-claim";physical=attempt/"stages/comparison/physical"
        physical.mkdir(parents=True);source="0"*40
        base.write(attempt/"declaration.json",dict(contract=self.sc,source_commit=source,synthetic=False,synthetic_control=True))
        counts={n:k for n,_,k in task.GATES};counts.update(provider=2,containment=1)
        gate=dict(ok=True,source_commit=source,safety_controls=counts,declaration_sha256=task.sha(attempt/"declaration.json"),
            preflight=dict(ok=True,world_build_count=0,solver_steps=0))
        base.write(attempt/"gate-receipt.json",gate)
        consumed=dict(attempt_id=attempt.name,source_commit=source,lane="comparison",contract_sha256=task.sha(task.CONTRACT),
            declaration_sha256=task.sha(attempt/"declaration.json"),gate_receipt_sha256=task.sha(attempt/"gate-receipt.json"),
            trials=task.all_plans(self.sc));base.write(attempt/"consumed.json",consumed)
        with patch.object(task,"ROOT",control/"repo"):
            task.validate_launch_records(physical,self.sc,source)
            bad=copy.deepcopy(gate);bad["safety_controls"]["training-closure"]-=1;base.write(attempt/"gate-receipt.json",bad)
            with self.assertRaisesRegex(ValueError,"complete zero-world"):task.validate_launch_records(physical,self.sc,source)
            base.write(attempt/"gate-receipt.json",gate)
            with self.assertRaisesRegex(ValueError,"owner freeze"):task.validate_launch_records(physical,self.sc,"1"*40)
            bad=copy.deepcopy(consumed);bad["trials"].pop();base.write(attempt/"consumed.json",bad)
            with self.assertRaisesRegex(ValueError,"consumed claim"):task.validate_launch_records(physical,self.sc,source)
        with self.assertRaisesRegex(ValueError,"requires containment"):
            worker.run(self.out,self.out/"no-permit",self.core_path,self.baseline,"comparison")

    def test_partial_world_count_and_all_manifest_sources_remain_honest(self):
        folder=self.out/("selected-partial-"+uuid.uuid4().hex);physical=folder/"stages/comparison/physical"
        physical.mkdir(parents=True)
        trial=physical/task.all_plans(self.sc)[0]["trial_id"];trial.mkdir()
        base.write(trial/"world-opened.json",dict(native_data_constructed=True,trial_id=trial.name,core_sha256=self.sc["core_sha256"]))
        receipt=dict(requested_stages=["comparison"],contract=self.sc,planned_trials=task.all_plans(self.sc),
            error="contained timeout",ok=False)
        owner.capture_worker_state(receipt,folder)
        self.assertEqual(receipt["constructed_cpu_worlds_lower_bound"],1)
        self.assertNotIn("constructed_cpu_worlds",receipt)
        self.assertTrue(receipt["physical_started"]);self.assertEqual(receipt["error"],"contained timeout")
        binding=owner.bindings(self.core_path,self.baseline)
        for path in [task.HERE/n for n in task.SOURCES]+[task.CONTRACT,fit.FIT,fit.MODEL,fit.PARENT]:
            self.assertEqual(binding["source"][path.relative_to(task.ROOT).as_posix()],task.sha(path))


if __name__=="__main__":unittest.main()
