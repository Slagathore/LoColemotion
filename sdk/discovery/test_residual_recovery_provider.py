"""Both-core single-handoff controls on retained inputs; no new physical outcomes."""
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
from adaptation_provider.warning import recovery_v1 as provider
from adaptation_provider.warning import residual_v1 as warning
from adaptation_provider.retrieval import causal_history_v1 as history
from audit_gpu_batch_execution import same_bits
from gpu_measurement_probe import write_new
import portable_search_control as portable
import residual_control as original_host
import residual_recovery_control as host
import residual_selection as selection
from sporespore_locomotion import LocomotionCore

ROOT=selection.ROOT
MODEL=ROOT/"sdk/discovery/residual_recovery_model_v1.json"
PREDECESSOR=ROOT/"sdk/discovery/residual_withdrawal_closure_v1.json"
STEPS=160
SEED=104240801


class RecoveryControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        guards=ExitStack();cls.addClassCleanup(guards.close)
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Recovery controls forbid worlds")))
        closure=selection.read(PREDECESSOR)
        evidence=(ROOT.parent/"SporeSpore_Evidence").resolve(strict=True)
        attempt=evidence/closure["attempt_id"]
        if selection.sha(attempt/"receipt.json")!=closure["receipt_sha256"]:raise ValueError("Recovery fixture receipt")
        receipt=selection.read(attempt/"receipt.json");inventory={r["path"]:r for r in receipt["artifacts"]}
        cls.inputs={};cls.compiled={};cls.bindings={}
        for trial in closure["summary"]["trials"]:
            if trial["role"]!="challenge_shadow":continue
            condition=trial["condition_id"]
            directory=attempt/"stages/comparison/physical"/trial["trial_id"]
            for name in ("controller.jsonl","compiled.json"):
                p=directory/name;relative=p.relative_to(attempt).as_posix();expected=inventory[relative]
                if selection.sha(p)!=expected["sha256"] or p.stat().st_size!=expected["byte_length"]:
                    raise ValueError("Recovery retained fixture binding")
                cls.bindings[relative]=selection.sha(p)
            with (directory/"controller.jsonl").open(encoding="utf-8") as stream:
                cls.inputs[condition]=[json.loads(line) for line in islice(stream,STEPS)]
            cls.compiled[condition]=selection.read(directory/"compiled.json")
            if [r["outer_step"] for r in cls.inputs[condition]]!=list(range(STEPS)):raise ValueError("Recovery chronology")
        if set(cls.inputs)!={"left_075","nominal"}:raise ValueError("Recovery fixture population")
        cls.cores=[]
        for variable,key in (("QUADRUPED_TEST_CORE","core_sha256"),("PORTABLE_BATCH_BASELINE_CORE","baseline_core_sha256")):
            path=Path(os.environ[variable])
            if selection.sha(path)!=receipt["contract"][key]:raise ValueError("Recovery bound core")
            cls.cores.append(LocomotionCore(path))
        cls.models=[provider.FrozenModel.load(core,selection.read(MODEL)) for core in cls.cores]
        cls.c=portable.contract();cls.c["seed"]=SEED;cls.rows={};cls.original={}
        out=Path(os.environ["EXPLORER_TEST_OUTPUT"])
        write_new(out/"recovery-input-bindings.json",dict(source_attempt=closure["attempt_id"],
            source_receipt_sha256=closure["receipt_sha256"],bindings=cls.bindings,
            source_partition="exposed_development_comparison",steps_per_group=STEPS,
            groups=sorted(cls.inputs),modes=list(provider.MODES),core_count=2,worlds_opened=0,solver_steps=0,
            counterfactual_retained_input_replay=True,new_physical_outcomes=False,training_data_authority=False))
        for ci,core in enumerate(cls.cores):
            for condition,inputs in cls.inputs.items():
                for key,actor in (("challenge",cls.models[ci].actor),("selected",cls.models[ci].recovery)):
                    old=original_host.ResidualController(core,cls.compiled[condition],
                        dict(cls.c,provider=original_host.expected_provider(actor)),actor,"frozen",condition+"_"+key)
                    try:cls.original[ci,condition,key]=[old.step(r["request"]["state"],r["stability"],r["kinematics"]) for r in inputs]
                    finally:old.close()
                for mode in provider.MODES:
                    model=cls.models[ci]
                    control=host.RecoveryController(core,cls.compiled[condition],
                        dict(cls.c,provider=host.expected_provider(model)),model,mode,condition+"_"+mode)
                    try:rows=[control.step(r["request"]["state"],r["stability"],r["kinematics"]) for r in inputs]
                    finally:control.close()
                    cls.rows[ci,condition,mode]=rows
                    write_new(out/(str(ci)+"_"+condition+"_"+mode+".json"),
                        dict(retained_input_replay=True,new_physical_outcomes=False,worlds_opened=0,rows=rows))

    def controller(self,mode="warning_selected",model=None,episode="control_episode"):
        model=model or self.models[0]
        control=host.RecoveryController(self.cores[0],self.compiled["nominal"],
            dict(self.c,provider=host.expected_provider(model)),model,mode,episode)
        self.addCleanup(control.close);return control

    def request(self,step=61,mode="early_selected"):
        return copy.deepcopy(self.rows[0,"nominal",mode][step]["resolution_request"]["provider_request"])

    def call(self,request,mode="early_selected",model=None):
        return provider.call_provider(self.cores[0],request,model or self.models[0],mode)

    def resolve(self,request,called):
        return self.cores[0].resolve_adaptation_v1(dict(schema_version="sporespore_adaptation_resolution_request_v1",
            provider_request=request,provider_response=called["provider_response"]))

    def rehash_memory(self,request):
        memory=request["provider_memory"];memory["opaque_state_sha256"]=provider.digest(self.cores[0],memory["opaque_state"])

    def test_01_definition_and_unchanged_actor_warning_identities(self):
        self.assertEqual(provider.definition(),provider.expected_definition())
        for model in self.models:
            self.assertEqual(model.actor.sha256,"sha256:868fcd240a78dcee1aa98cc2653cd22b0463f92815e1216989800625cdec9d33")
            self.assertEqual(model.recovery.sha256,"sha256:f340fd7eb79abdb7ed52a93ad8f1bb038ba46d1406c81f3ea422cded17ee3c1f")
            self.assertEqual(model.warning.sha256,"sha256:1ca62d154320deb1159f9370bbc3da3660346750297cc1d06b437133cb3548b5")
            self.assertEqual(model.recovery.document(),selection.read(selection.MODEL))

    def test_02_models_own_immutable_bytes(self):
        value=selection.read(MODEL);model=provider.FrozenModel.load(self.cores[0],value)
        value["recovery"]["policy"]["weights"][0][0]+=.01
        self.assertNotEqual(provider.warning.digest(value),model.sha256)
        with self.assertRaises(FrozenInstanceError):model.sha256="changed"

    def test_03_both_cores_all_modes_and_groups_are_bit_identical(self):
        for condition in self.inputs:
            for mode in provider.MODES:self.assertTrue(same_bits(self.rows[0,condition,mode],self.rows[1,condition,mode]))
        self.assertEqual(sum(len(r) for r in self.rows.values()),5120)

    def test_04_pure_actor_controls_preserve_original_action_bits(self):
        for ci in range(2):
            for condition in self.inputs:
                for actor in ("challenge","selected"):
                    for row,old in zip(self.rows[ci,condition,actor+"_only"],self.original[ci,condition,actor],strict=True):
                        for key in ("output","composition","native_targets"):self.assertTrue(same_bits(row[key],old[key]))
                for row,native in zip(self.rows[ci,condition,"challenge_only"],self.inputs[condition],strict=True):
                    self.assertTrue(same_bits(row["native_targets"],native["native_targets"]))

    def test_05_early_trigger_is_explicit_and_leaves_prediction_untampered(self):
        for ci in range(2):
            for condition in self.inputs:
                for mode in ("early_baseline","early_selected"):
                    rows=self.rows[ci,condition,mode]
                    events=[r["residual"]["decision"] for r in rows if r["residual"]["decision"]["recovery"]["triggered_now"]]
                    self.assertEqual([r["step"] for r in events],[60])
                    d=events[0];self.assertEqual(d["recovery"]["trigger_reason"],"scheduled_early")
                    self.assertEqual(d["warning"]["natural_decision"]["score"],self.models[ci].warning.predict(d["features"],60))

    def test_06_natural_trigger_uses_original_warning_without_pretrigger_change(self):
        for ci in range(2):
            for condition in self.inputs:
                for mode in ("warning_baseline","warning_selected"):
                    rows=self.rows[ci,condition,mode]
                    events=[r for r in rows if r["residual"]["decision"]["recovery"]["triggered_now"]]
                    self.assertEqual(len(events),1)
                    step=events[0]["request"]["state"]["semantic_step"]
                    self.assertEqual(step,86 if condition=="left_075" else 140)
                    self.assertEqual(events[0]["residual"]["decision"]["recovery"]["trigger_reason"],"prediction_threshold")
                    for a,b in zip(rows[:step],self.rows[ci,condition,"challenge_only"][:step],strict=True):
                        self.assertTrue(same_bits(a["native_targets"],b["native_targets"]))

    def test_07_baseline_handoff_is_immediate_zero_and_stays_latched(self):
        for ci in range(2):
            for condition in self.inputs:
                for mode in ("early_baseline","warning_baseline"):
                    rows=self.rows[ci,condition,mode]
                    start=next(i for i,r in enumerate(rows) if r["residual"]["decision"]["recovery"]["triggered_now"])
                    self.assertTrue(any(c["applied_correction_rad_s"] for c in rows[start-1]["resolution"]["ordered_commands"]))
                    self.assertEqual(rows[start]["resolution"]["fallback_reason"],"provider_uncertain")
                    for r in rows[start:]:
                        self.assertEqual(r["residual"]["decision"]["active_actor"],"baseline")
                        self.assertFalse(r["resolution"]["adaptation_applied"])
                        self.assertTrue(all(c["applied_correction_rad_s"]==0. for c in r["resolution"]["ordered_commands"]))

    def test_08_selected_handoff_slews_from_actual_preceding_correction(self):
        for ci in range(2):
            for condition in self.inputs:
                for mode in ("early_selected","warning_selected"):
                    rows=self.rows[ci,condition,mode]
                    start=next(i for i,r in enumerate(rows) if r["residual"]["decision"]["recovery"]["triggered_now"])
                    row=rows[start];prior=rows[start-1]["resolution"]["ordered_commands"]
                    self.assertEqual(row["residual"]["decision"]["active_actor_model_sha256"],self.models[ci].recovery.sha256)
                    self.assertTrue(row["resolution"]["adaptation_applied"])
                    for prev,now,limit in zip(prior,row["resolution"]["ordered_commands"],
                            row["resolution_request"]["provider_request"]["safety_envelope"]["ordered_actuator_limits"],strict=True):
                        self.assertEqual(limit["previous_applied_correction_rad_s"],prev["applied_correction_rad_s"])
                        self.assertLessEqual(abs(now["applied_correction_rad_s"]-prev["applied_correction_rad_s"]),.08+1e-15)

    def test_09_handoff_latch_does_not_reenter_on_a_clear_warning(self):
        req=self.request()
        with patch.object(warning.FrozenWarning,"predict",return_value=-1.):called=self.call(req)
        self.assertIsNone(called["provider_error"])
        self.assertEqual(called["decision"]["active_actor"],"selected")
        self.assertEqual(called["decision"]["recovery"]["handoff_command"],60)
        self.assertFalse(called["decision"]["recovery"]["triggered_now"])
        for rows in self.rows.values():
            if rows[0]["residual"]["mode"]=="absent":continue
            commands=[r["residual"]["decision"]["recovery"]["handoff_command"] for r in rows]
            nonnull=[c for c in commands if c is not None]
            self.assertLessEqual(len(set(nonnull)),1)
            if nonnull:self.assertTrue(all(c==nonnull[0] for c in commands[nonnull[0]:]))

    def test_10_history_retains_every_actual_resolution_across_handoff(self):
        for ci,core in enumerate(self.cores):
            for condition in self.inputs:
                for mode in provider.MODES[:-1]:
                    rows=self.rows[ci,condition,mode]
                    for step,row in enumerate(rows[1:],1):
                        entry=row["resolution_request"]["provider_request"]["history"]["ordered_entries"][0]
                        prior=rows[step-1]
                        self.assertEqual(entry["request_sha256"],prior["resolution"]["request_sha256"])
                        self.assertEqual(entry["resolution_receipt_sha256"],provider.digest(core,prior["resolution"]))
                        self.assertEqual(history.final_velocities(entry),prior["native_targets"])
                        self.assertIsNone(row["residual"]["history_boundary"])
                        self.assertEqual(row["residual"]["ongoing_history_entries"],1)

    def test_11_all_commands_keep_original_caps_and_resolver_authority(self):
        for rows in self.rows.values():
            for row in rows:
                receipt=row["resolution"]
                self.assertEqual(receipt["world_build_count"],0);self.assertFalse(receipt["physics_state_modified"])
                self.assertFalse(receipt["physical_acceptance_authority"])
                self.assertTrue(all(abs(c["applied_correction_rad_s"])<=3.5
                    and abs(c["final_canonical_target_velocity_rad_s"])<=c["maximum_target_speed_rad_s"]
                    for c in receipt["ordered_commands"]))

    def test_12_baseline_and_absent_preserve_command_bits(self):
        for ci in range(2):
            for condition in self.inputs:
                for a,b in zip(self.rows[ci,condition,"absent"],self.rows[ci,condition,"baseline_only"],strict=True):
                    self.assertTrue(same_bits(a["native_targets"],b["native_targets"]))
                    self.assertFalse(b["resolution"]["adaptation_applied"])
                    self.assertIsNone(b["residual"]["history_boundary"])

    def test_13_first_command_is_baseline_only(self):
        for (ci,condition,mode),rows in self.rows.items():
            if mode!="absent":self.assertEqual(rows[0]["resolution"]["provider_status"],"no_proposal")
            self.assertFalse(rows[0]["resolution"]["adaptation_applied"])

    def test_14_crossed_model_mode_seed_and_episode_refuse(self):
        for key,value in (("expected_model_sha256","sha256:"+"0"*64),("expected_provider_version","wrong"),
                          ("seed",SEED+1),("request_id","crossed_episode")):
            req=self.request();req[key]=value;self.assertIsNotNone(self.call(req)["provider_error"])
        req=self.request();req["provider_memory"]["opaque_state"]["mode"]="challenge_only";self.rehash_memory(req)
        self.assertIsNotNone(self.call(req)["provider_error"])

    def test_15_corrupt_monitor_clock_model_and_reset_refuse(self):
        for key,value in (("last_step",59),("model_sha256","sha256:"+"0"*64),("episode_id","different"),("reset_epoch",1)):
            req=self.request();req["provider_memory"]["opaque_state"]["warning_state"][key]=value;self.rehash_memory(req)
            self.assertIsNotNone(self.call(req)["provider_error"])

    def test_16_corrupt_or_missing_handoff_latch_refuses(self):
        for value in (None,True,59,61,100,-1):
            req=self.request();req["provider_memory"]["opaque_state"]["handoff_command"]=value;self.rehash_memory(req)
            self.assertIsNotNone(self.call(req)["provider_error"])
        req=self.request(step=59);req["provider_memory"]["opaque_state"]["handoff_command"]=58;self.rehash_memory(req)
        self.assertIsNotNone(self.call(req)["provider_error"])

    def test_17_unsupported_observation_uses_baseline_after_selected_handoff(self):
        req=self.request();req["state"]["ordered_joint_observations"][0]["velocity_rad_s"]=100.
        called=self.call(req)
        self.assertIsNone(called["provider_error"]);self.assertEqual(called["provider_response"]["status"],"unsupported")
        self.assertEqual(called["decision"]["recovery"]["handoff_command"],60)
        self.assertEqual(called["decision"]["active_actor"],"selected")
        resolved=self.resolve(req,called);following,boundary=history.append_resolved(self.cores[0],req,resolved)
        self.assertFalse(resolved["adaptation_applied"]);self.assertIsNone(boundary)
        self.assertEqual(following["ordered_entries"][-1]["provider_status"],"unsupported")

    def test_18_crossed_actual_prior_command_is_unsupported(self):
        req=self.request();req["history"]["ordered_entries"][0]["request_sha256"]="sha256:"+"0"*64
        called=self.call(req);self.assertEqual(called["provider_response"]["status"],"unsupported")
        self.assertIn("crossed prior",called["decision"]["reason"])

    def test_19_corrupt_provider_packet_closes_host_with_original_receipt(self):
        control=self.controller();row=self.inputs["nominal"][0]
        with patch.object(provider,"call_provider",return_value=dict(provider_response={"invalid":True},decision=None,provider_error=None)):
            observed=control.step(row["request"]["state"],row["stability"],row["kinematics"])
        self.assertTrue(control.closed);self.assertTrue(control.session.closed)
        self.assertEqual(observed["resolution"]["fallback_reason"],"invalid_provider_response")
        self.assertEqual(observed["residual"]["terminal_error"]["type"],"UnrepresentableResolution")

    def test_20_provider_exception_closes_host_before_another_command(self):
        control=self.controller();row=self.inputs["nominal"][0]
        with patch.object(provider,"respond",side_effect=ValueError("injected fault")):
            observed=control.step(row["request"]["state"],row["stability"],row["kinematics"])
        self.assertIsNotNone(observed["residual"]["terminal_error"]);self.assertTrue(control.closed)
        with self.assertRaises(ValueError):control.step(row["request"]["state"],row["stability"],row["kinematics"])

    def test_21_clock_contract_and_reset_preserve_fresh_lifecycle(self):
        control=self.controller();row=self.inputs["nominal"][1]
        with self.assertRaises(ValueError):control.step(row["request"]["state"],row["stability"],row["kinematics"])
        self.assertTrue(control.closed)
        c=dict(self.c,provider=host.expected_provider(self.models[0]));c["provider"]["maximum_slew_per_step_rad_s"]=.16
        with self.assertRaises(ValueError):host.RecoveryController(self.cores[0],self.compiled["nominal"],c,self.models[0],"selected_only","bad")
        req=self.request(step=0);req["provider_memory"]=provider.empty_memory(self.cores[0],self.models[0],"early_selected",SEED,"nominal_early_selected",1)
        called=self.call(req)
        self.assertIsNone(called["provider_error"]);self.assertEqual(called["provider_response"]["status"],"no_proposal")
        self.assertEqual(called["provider_response"]["next_memory"]["reset_epoch"],1)

    def test_22_no_weight_changes_or_manufactured_experience(self):
        for rows in self.rows.values():
            for row in rows:
                response=row["resolution_request"]["provider_response"]
                if response is not None:
                    self.assertFalse(response["next_memory"]["weights_mutated"])
                    self.assertIsNone(response["candidate_experience"])
                    self.assertFalse(response["provenance"]["direct_world_access_used"])
        self.assertEqual(self.models[0].document(),selection.read(MODEL))

    def test_23_fold_warning_and_changed_definition_refuse(self):
        value=selection.read(MODEL);value["warning"]["training"].update(kind="retrospective_grouped_training_fold",
            training_trial_count=48,held_out_start_id="train_001")
        with self.assertRaises(ValueError):provider.FrozenModel.load(self.cores[0],value)
        value=selection.read(MODEL);value["definition"]["safe_backup_established"]=True
        with self.assertRaises(ValueError):provider.FrozenModel.load(self.cores[0],value)

    def test_24_declared_synthetic_warning_triggers_selected_handoff(self):
        req=self.request(step=60,mode="warning_selected")
        with patch.object(warning.FrozenWarning,"predict",return_value=1.5):called=self.call(req,"warning_selected")
        self.assertIsNone(called["provider_error"]);self.assertTrue(called["decision"]["recovery"]["triggered_now"])
        self.assertEqual(called["decision"]["recovery"]["trigger_reason"],"prediction_threshold")
        self.assertEqual(called["decision"]["active_actor"],"selected")
        self.assertTrue(self.resolve(req,called)["adaptation_applied"])

    def test_25_pure_actor_control_never_switches_under_synthetic_warning(self):
        req=self.request(step=60,mode="challenge_only")
        with patch.object(warning.FrozenWarning,"predict",return_value=1.5):called=self.call(req,"challenge_only")
        self.assertTrue(called["decision"]["warning"]["natural_decision"]["withdraw_requested"])
        self.assertFalse(called["decision"]["recovery"]["triggered_now"])
        self.assertEqual(called["decision"]["active_actor"],"challenge")

    def test_26_horizon_capacity_and_memory_digest(self):
        req=self.request();req["state"]["semantic_step"]=1440
        self.assertIsNotNone(self.call(req)["provider_error"])
        for rows in self.rows.values():
            for row in rows:
                response=row["resolution_request"]["provider_response"]
                if response:
                    memory=response["next_memory"]
                    self.assertEqual(provider.digest(self.cores[0],memory["opaque_state"]),memory["opaque_state_sha256"])
                    self.assertLessEqual(len(self.cores[0].canonicalize_json(memory["opaque_state"])["canonical_json"].encode()),4096)


if __name__=="__main__":unittest.main()
