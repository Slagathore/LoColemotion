"""Both-core withdrawal/reentry controls on retained inputs; no new physics."""
import copy
from contextlib import ExitStack
from dataclasses import FrozenInstanceError
from itertools import islice
import json
import os
from pathlib import Path
import unittest
from unittest.mock import patch

import mujoco
from adaptation_provider.warning import control_v1 as provider
from adaptation_provider.warning import residual_v1 as warning
from adaptation_provider.retrieval import causal_history_v1 as history
from audit_gpu_batch_execution import same_bits
from gpu_measurement_probe import write_new
import portable_search_control as portable
import residual_control as original_host
import residual_withdrawal_control as host
import residual_selection as selection
from sporespore_locomotion import LocomotionCore

ROOT=selection.ROOT
MODEL=ROOT/"sdk/discovery/residual_withdrawal_model_v1.json"
WARNING_MODEL=ROOT/"sdk/discovery/residual_warning_model_v1.json"
STEPS=140
SEED=104240701


class WithdrawalControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        guards=ExitStack();cls.addClassCleanup(guards.close)
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Withdrawal controls forbid all worlds")))
        c,candidates,bindings=selection.retained_population()
        candidate=next(v for v in candidates if v["stage"]=="iteration_00" and v["model_key"]=="d00_plus")
        root=(ROOT.parent/"SporeSpore_Evidence").resolve(strict=True);pilot=root/selection.PILOT
        receipt=selection.read(pilot/"receipt.json")
        inventory={r["path"]:r for r in receipt["artifacts"]}
        cls.inputs={};cls.compiled={};cls.bindings={}
        for trial in candidate["trials"]:
            if trial["start_id"]!="train_001":continue
            condition=trial["condition_id"]
            directory=pilot/"stages/iteration_00/physical"/trial["trial_id"]
            for name in ("controller.jsonl","compiled.json"):
                p=directory/name;relative=p.relative_to(pilot).as_posix()
                expected=inventory[relative]
                if selection.sha(p)!=expected["sha256"] or p.stat().st_size!=expected["byte_length"]:
                    raise ValueError("Withdrawal retained fixture binding")
                cls.bindings[relative]=selection.sha(p)
            p=directory/"controller.jsonl"
            if selection.sha(p)!=trial["raw_hashes"]["controller"]:raise ValueError("Withdrawal audited raw binding")
            with p.open(encoding="utf-8") as stream:cls.inputs[condition]=[json.loads(line) for line in islice(stream,STEPS)]
            cls.compiled[condition]=selection.read(directory/"compiled.json")
            if [r["outer_step"] for r in cls.inputs[condition]]!=list(range(STEPS)):raise ValueError("Withdrawal fixture chronology")
        if set(cls.inputs)!={"left_075","nominal"}:raise ValueError("Withdrawal fixture group population")
        cls.cores=[]
        for variable,key in (("QUADRUPED_TEST_CORE","core_sha256"),("PORTABLE_BATCH_BASELINE_CORE","baseline_core_sha256")):
            path=Path(os.environ[variable])
            if selection.sha(path)!=c[key]:raise ValueError("Withdrawal bound core")
            cls.cores.append(LocomotionCore(path))
        cls.models=[provider.FrozenModel.load(core,selection.read(MODEL)) for core in cls.cores]
        cls.c=portable.contract();cls.c["seed"]=SEED
        cls.rows={};cls.original={}
        out=Path(os.environ["EXPLORER_TEST_OUTPUT"])
        write_new(out/"withdrawal-input-bindings.json",dict(source_pilot=selection.PILOT,
            source_receipt_sha256=selection.PILOT_RECEIPT_SHA,bindings=cls.bindings,
            source_partition="training",steps_per_group=STEPS,groups=sorted(cls.inputs),
            modes=list(provider.MODES),core_count=2,worlds_opened=0,solver_steps=0,
            counterfactual_retained_input_replay=True,new_physical_outcomes=False,training_data_authority=False))
        for ci,core in enumerate(cls.cores):
            for condition,inputs in cls.inputs.items():
                actor=cls.models[ci].actor
                old=original_host.ResidualController(core,cls.compiled[condition],
                    dict(cls.c,provider=original_host.expected_provider(actor)),actor,"frozen",condition+"_original")
                try:cls.original[ci,condition]=[old.step(r["request"]["state"],r["stability"],r["kinematics"]) for r in inputs]
                finally:old.close()
                for mode in provider.MODES:
                    model=cls.models[ci]
                    control=host.WithdrawalController(core,cls.compiled[condition],
                        dict(cls.c,provider=host.expected_provider(model)),model,mode,condition+"_"+mode)
                    try:rows=[control.step(r["request"]["state"],r["stability"],r["kinematics"]) for r in inputs]
                    finally:control.close()
                    cls.rows[ci,condition,mode]=rows
                    write_new(out/(str(ci)+"_"+condition+"_"+mode+".json"),
                        dict(retained_input_replay=True,new_physical_outcomes=False,worlds_opened=0,rows=rows))

    def controller(self,mode="frozen",model=None,episode="control_episode"):
        model=model or self.models[0]
        control=host.WithdrawalController(self.cores[0],self.compiled["nominal"],
            dict(self.c,provider=host.expected_provider(model)),model,mode,episode)
        self.addCleanup(control.close)
        return control

    def request(self,step=91,mode="forced_route"):
        return copy.deepcopy(self.rows[0,"nominal",mode][step]["resolution_request"]["provider_request"])

    def call(self,request,mode="forced_route",model=None):
        return provider.call_provider(self.cores[0],request,model or self.models[0],mode)

    def resolve(self,request,called):
        return self.cores[0].resolve_adaptation_v1(dict(schema_version="sporespore_adaptation_resolution_request_v1",
            provider_request=request,provider_response=called["provider_response"]))

    def rehash_memory(self,request):
        memory=request["provider_memory"]
        memory["opaque_state_sha256"]=provider.digest(self.cores[0],memory["opaque_state"])

    def test_definitions_and_composite_artifact_identity(self):
        self.assertEqual(provider.definition(),provider.expected_definition())
        for model in self.models:
            self.assertEqual(model.actor.sha256,"sha256:f340fd7eb79abdb7ed52a93ad8f1bb038ba46d1406c81f3ea422cded17ee3c1f")
            self.assertEqual(model.warning.sha256,"sha256:1ca62d154320deb1159f9370bbc3da3660346750297cc1d06b437133cb3548b5")
            self.assertEqual(model.document()["actor"],selection.read(selection.MODEL))
            self.assertEqual(model.document()["warning"],selection.read(WARNING_MODEL))

    def test_models_own_immutable_bytes(self):
        value=selection.read(MODEL);model=provider.FrozenModel.load(self.cores[0],value)
        value["actor"]["policy"]["weights"][0][0]+=.01
        self.assertNotEqual(provider.warning.digest(value),model.sha256)
        with self.assertRaises(FrozenInstanceError):model.sha256="changed"

    def test_both_cores_all_modes_and_groups_are_bit_identical(self):
        for condition in self.inputs:
            for mode in provider.MODES:self.assertTrue(same_bits(self.rows[0,condition,mode],self.rows[1,condition,mode]))
        self.assertEqual(sum(len(r) for r in self.rows.values()),2800)

    def test_shadow_preserves_original_actor_and_retained_command_bits(self):
        for ci in range(2):
            for condition,inputs in self.inputs.items():
                for row,old,native in zip(self.rows[ci,condition,"shadow"],self.original[ci,condition],inputs,strict=True):
                    for key in ("output","composition","native_targets"):
                        self.assertTrue(same_bits(row[key],old[key]))
                        self.assertTrue(same_bits(row[key],native[key]))
                    self.assertTrue(same_bits(row["residual"]["decision"]["features"]["values"],
                        old["residual"]["decision"]["features"]["values"]))

    def test_natural_guard_preserves_no_warning_actor_path(self):
        for ci in range(2):
            for condition in self.inputs:
                for a,b in zip(self.rows[ci,condition,"shadow"],self.rows[ci,condition,"frozen"],strict=True):
                    self.assertTrue(same_bits(a["native_targets"],b["native_targets"]))
                    self.assertFalse(b["residual"]["decision"]["warning"]["withheld"])

    def test_forced_route_is_explicit_and_leaves_prediction_untampered(self):
        for ci in range(2):
            for condition in self.inputs:
                rows=self.rows[ci,condition,"forced_route"]
                forced=[r for r in rows if r["residual"]["decision"]["warning"]["forced_route_request"]]
                self.assertEqual([r["request"]["state"]["semantic_step"] for r in forced],[90])
                detail=forced[0]["residual"]["decision"];natural=detail["warning"]["natural_decision"]
                self.assertEqual(natural["score"],self.models[ci].warning.predict(detail["features"],90))
                self.assertFalse(natural["withdraw_requested"])
                self.assertEqual(detail["reason"],"declared_route_withdrawal")

    def test_v1_withdrawal_is_immediate_zero_after_nonzero_residual(self):
        for ci in range(2):
            for condition in self.inputs:
                rows=self.rows[ci,condition,"forced_route"]
                self.assertTrue(any(c["applied_correction_rad_s"]!=0 for c in rows[89]["resolution"]["ordered_commands"]))
                receipt=rows[90]["resolution"]
                self.assertEqual(receipt["provider_status"],"uncertain")
                self.assertEqual(receipt["fallback_reason"],"provider_uncertain")
                self.assertFalse(receipt["adaptation_applied"])
                for c in receipt["ordered_commands"]:
                    self.assertEqual(c["applied_correction_rad_s"],0.)
                    self.assertEqual(c["final_canonical_target_velocity_rad_s"],c["baseline_canonical_target_velocity_rad_s"])

    def test_hysteresis_reentry_requires_thirty_actual_clear_commands(self):
        for ci in range(2):
            for condition in self.inputs:
                rows=self.rows[ci,condition,"forced_route"]
                self.assertTrue(all(r["residual"]["decision"]["warning"]["withheld"] for r in rows[90:120]))
                self.assertEqual(rows[119]["residual"]["decision"]["warning"]["clear_commands"],29)
                self.assertEqual(rows[120]["residual"]["decision"]["warning"]["natural_decision"]["reason"],"supported_reentry")
                self.assertTrue(rows[120]["resolution"]["adaptation_applied"])

    def test_reentry_slew_starts_from_actual_zero_correction(self):
        for ci in range(2):
            for condition in self.inputs:
                row=self.rows[ci,condition,"forced_route"][120]
                self.assertTrue(all(r["previous_applied_correction_rad_s"]==0.
                    for r in row["resolution_request"]["provider_request"]["safety_envelope"]["ordered_actuator_limits"]))
                self.assertTrue(all(abs(c["applied_correction_rad_s"])<=.08 for c in row["resolution"]["ordered_commands"]))

    def test_history_includes_uncertain_resolution_and_actual_final_commands(self):
        for ci,core in enumerate(self.cores):
            for condition in self.inputs:
                rows=self.rows[ci,condition,"forced_route"]
                for step,row in enumerate(rows[1:],1):
                    req=row["resolution_request"]["provider_request"];prior=rows[step-1]
                    entry=req["history"]["ordered_entries"][0]
                    self.assertEqual(entry["request_sha256"],prior["resolution"]["request_sha256"])
                    self.assertEqual(entry["resolution_receipt_sha256"],provider.digest(core,prior["resolution"]))
                    self.assertEqual(entry["provider_status"],prior["resolution"]["provider_status"])
                    self.assertEqual(history.final_velocities(entry),prior["native_targets"])
                    self.assertEqual(row["residual"]["ongoing_history_entries"],1)
                    self.assertIsNone(row["residual"]["history_boundary"])

    def test_all_commands_keep_original_caps_and_resolver_authority(self):
        for rows in self.rows.values():
            for row in rows:
                receipt=row["resolution"]
                self.assertEqual(receipt["world_build_count"],0);self.assertFalse(receipt["physics_state_modified"])
                self.assertFalse(receipt["physical_acceptance_authority"])
                self.assertTrue(all(abs(c["applied_correction_rad_s"])<=3.5
                    and abs(c["final_canonical_target_velocity_rad_s"])<=c["maximum_target_speed_rad_s"]
                    for c in receipt["ordered_commands"]))

    def test_disabled_and_absent_preserve_same_baseline_command_bits(self):
        for ci in range(2):
            for condition in self.inputs:
                for a,b in zip(self.rows[ci,condition,"absent"],self.rows[ci,condition,"disabled"],strict=True):
                    self.assertTrue(same_bits(a["native_targets"],b["native_targets"]))
                    self.assertFalse(any(c["applied_correction_rad_s"] for c in b["resolution"]["ordered_commands"]))
                    self.assertIsNone(b["residual"]["history_boundary"])
                    self.assertEqual(a["residual"]["history_boundary"],"v1_unrepresentable_provider_status")

    def test_first_command_is_baseline_only(self):
        for (ci,condition,mode),rows in self.rows.items():
            if mode!="absent":self.assertEqual(rows[0]["resolution"]["provider_status"],"no_proposal")
            self.assertFalse(rows[0]["resolution"]["adaptation_applied"])

    def test_crossed_model_mode_seed_and_episode_refuse(self):
        for key,value in (("expected_model_sha256","sha256:"+"0"*64),("expected_provider_version","wrong"),
                          ("seed",SEED+1),("request_id","crossed_episode")):
            req=self.request();req[key]=value;self.assertIsNotNone(self.call(req)["provider_error"])
        req=self.request();req["provider_memory"]["opaque_state"]["mode"]="shadow";self.rehash_memory(req)
        self.assertIsNotNone(self.call(req)["provider_error"])

    def test_corrupt_monitor_clock_model_and_reset_refuse_even_with_valid_memory_digest(self):
        for key,value in (("last_step",89),("model_sha256","sha256:"+"0"*64),("episode_id","different"),("reset_epoch",1)):
            req=self.request();req["provider_memory"]["opaque_state"]["warning_state"][key]=value;self.rehash_memory(req)
            self.assertIsNotNone(self.call(req)["provider_error"])

    def test_unsupported_observation_requests_baseline_without_losing_history(self):
        req=self.request(mode="frozen")
        req["state"]["ordered_joint_observations"][0]["velocity_rad_s"]=100.
        called=self.call(req,mode="frozen")
        self.assertIsNone(called["provider_error"]);self.assertEqual(called["provider_response"]["status"],"unsupported")
        self.assertTrue(called["decision"]["warning"]["withheld"])
        resolved=self.resolve(req,called);following,boundary=history.append_resolved(self.cores[0],req,resolved)
        self.assertIsNone(boundary);self.assertEqual(following["ordered_entries"][-1]["provider_status"],"unsupported")

    def test_actual_prior_command_binding_rejects_crossed_history(self):
        req=self.request()
        req["history"]["ordered_entries"][0]["request_sha256"]="sha256:"+"0"*64
        called=self.call(req)
        self.assertEqual(called["provider_response"]["status"],"unsupported")
        self.assertIn("crossed prior",called["decision"]["reason"])

    def test_corrupt_provider_packet_closes_host_and_preserves_original_receipt(self):
        control=self.controller();row=self.inputs["nominal"][0]
        with patch.object(provider,"call_provider",return_value=dict(provider_response={"invalid":True},decision=None,provider_error=None)):
            observed=control.step(row["request"]["state"],row["stability"],row["kinematics"])
        self.assertTrue(control.closed);self.assertTrue(control.session.closed)
        self.assertEqual(observed["resolution"]["fallback_reason"],"invalid_provider_response")
        self.assertEqual(observed["residual"]["terminal_error"]["type"],"UnrepresentableResolution")

    def test_provider_exception_closes_host_before_another_command(self):
        control=self.controller();row=self.inputs["nominal"][0]
        with patch.object(provider,"respond",side_effect=ValueError("injected control fault")):
            observed=control.step(row["request"]["state"],row["stability"],row["kinematics"])
        self.assertIsNotNone(observed["residual"]["terminal_error"]);self.assertTrue(control.closed)
        with self.assertRaises(ValueError):control.step(row["request"]["state"],row["stability"],row["kinematics"])

    def test_host_clock_and_contract_mismatch_fail_closed(self):
        control=self.controller();row=self.inputs["nominal"][1]
        with self.assertRaises(ValueError):control.step(row["request"]["state"],row["stability"],row["kinematics"])
        self.assertTrue(control.closed)
        c=dict(self.c,provider=host.expected_provider(self.models[0]));c["provider"]["maximum_slew_per_step_rad_s"]=.16
        with self.assertRaises(ValueError):host.WithdrawalController(self.cores[0],self.compiled["nominal"],c,self.models[0],"frozen","bad")

    def test_reset_epoch_starts_fresh_with_no_previous_action(self):
        model=self.models[0];req=copy.deepcopy(self.rows[0,"nominal","frozen"][0]["resolution_request"]["provider_request"])
        req["provider_memory"]=provider.empty_memory(self.cores[0],model,"frozen",SEED,"nominal_frozen",1)
        called=self.call(req,mode="frozen")
        self.assertIsNone(called["provider_error"]);self.assertEqual(called["provider_response"]["status"],"no_proposal")
        self.assertEqual(called["provider_response"]["next_memory"]["reset_epoch"],1)

    def test_guard_never_mutates_weights_or_manufactures_experience(self):
        for rows in self.rows.values():
            for row in rows:
                response=row["resolution_request"]["provider_response"]
                if response is not None:
                    self.assertFalse(response["next_memory"]["weights_mutated"])
                    self.assertIsNone(response["candidate_experience"])
                    self.assertFalse(response["provenance"]["direct_world_access_used"])
        self.assertEqual(self.models[0].document(),selection.read(MODEL))

    def test_fold_warning_and_changed_definition_models_are_refused(self):
        value=selection.read(MODEL);value["warning"]["training"].update(kind="retrospective_grouped_training_fold",
            training_trial_count=48,held_out_start_id="train_001")
        with self.assertRaises(ValueError):provider.FrozenModel.load(self.cores[0],value)
        value=selection.read(MODEL);value["definition"]["safe_backup_established"]=True
        with self.assertRaises(ValueError):provider.FrozenModel.load(self.cores[0],value)

    def test_natural_warning_branch_with_declared_synthetic_score_stimulus(self):
        req=self.request(mode="frozen")
        # Explicit inference fault stimulus; no recorded prediction or weight is changed.
        with patch.object(warning.FrozenWarning,"predict",return_value=1.5):
            called=self.call(req,mode="frozen")
        self.assertIsNone(called["provider_error"])
        self.assertEqual(called["provider_response"]["status"],"uncertain")
        self.assertEqual(called["decision"]["reason"],"warning_withdrawal")
        self.assertFalse(called["decision"]["warning"]["forced_route_request"])
        self.assertTrue(called["decision"]["warning"]["withdrawal_applied_to_proposal"])
        self.assertFalse(self.resolve(req,called)["adaptation_applied"])

    def test_shadow_records_same_score_stimulus_without_actuating_withdrawal(self):
        req=self.request(mode="shadow")
        with patch.object(warning.FrozenWarning,"predict",return_value=1.5):
            called=self.call(req,mode="shadow")
        self.assertTrue(called["decision"]["warning"]["natural_decision"]["withdraw_requested"])
        self.assertFalse(called["decision"]["warning"]["withdrawal_requested_for_mode"])
        self.assertEqual(called["provider_response"]["status"],"applied")

    def test_horizon_memory_capacity_and_inference_bounds(self):
        req=self.request();req["state"]["semantic_step"]=1440
        self.assertIsNotNone(self.call(req)["provider_error"])
        for rows in self.rows.values():
            for row in rows:
                response=row["resolution_request"]["provider_response"]
                if response:
                    raw=provider.digest(self.cores[0],response["next_memory"]["opaque_state"])
                    self.assertEqual(raw,response["next_memory"]["opaque_state_sha256"])
                    self.assertLessEqual(len(self.cores[0].canonicalize_json(response["next_memory"]["opaque_state"])["canonical_json"].encode()),4096)


if __name__=="__main__":unittest.main()
