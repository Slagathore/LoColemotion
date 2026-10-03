"""Real Godot V50 adapter/transport/ledger on detached synthetic input, no world."""
import copy, hashlib, json, sys, unittest, uuid
from pathlib import Path
import test_development_passive_entry_replay as shared
from development_recovery_candidate_test_support import ROOT, candidate, selected
from unittest.mock import patch
class MeasuredBodyAdapter(unittest.TestCase):
    _run_retained = classmethod(shared.PassiveEntryReplay._run_retained.__func__)
    @classmethod
    def setUpClass(cls):
        cls.root = ROOT.parent / "SporeSpore_Evidence" / ("development-v50-godot-body-" + uuid.uuid4().hex)
        cls.root.mkdir(); print("V50_GODOT_BODY_ROOT", cls.root, flush=True)
        source = cls.root.parent / "development-v50-mujoco-closed-loop-bd3a5a83e888432d8b3b50c9a1f46af4/calls/0001.request.json"
        value = json.loads(source.read_bytes())
        closure = json.loads((ROOT / "sdk/development/recovery_attempts/b308b58a36144525866e2f96b2abe0be.json").read_bytes())
        oldraw = Path(closure["kicked_report"]["path"]).read_bytes()
        assert "sha256:"+hashlib.sha256(oldraw).hexdigest()==closure["kicked_report"]["raw_sha256"]
        old = json.loads(oldraw)
        value["post_native_source"] = next(r["native_source"] for r in old["development_native_walking_contacts"]["rows"] if r["segment_id"]=="walking_resume" and r["session_local_step"]==2)
        del old, oldraw

        (cls.root / "input.json").write_text(json.dumps(value,separators=(",", ":"))+"\n", encoding="utf-8")
        run = cls._run_retained("res://tests/test_development_v50_measured_body_adapter.gd", ["--",str(cls.root / "input.json")], "adapter", 60)
        cls.native_run = run
        lines = [l for l in run.stdout.decode().splitlines() if l.startswith("V50_MEASURED_BODY_ADAPTER ")]
        if len(lines) != 1: raise AssertionError((run.returncode,run.stderr.decode()[-8000:],run.stdout.decode()[-4000:]))
        cls.result = json.loads(lines[0].split(" ",1)[1])
    def test_actual_start_body_projection_transport_and_shutdown(self):
        self.assertEqual(0,self.native_run.returncode,self.result)
        self.assertNotIn(b"ERROR:",self.native_run.stdout+self.native_run.stderr)
        for name in ("profile","runtime","actual_adapter_start","project_exact_body_population","v3_request","actual_native_v3_transport","shutdown"):
            self.assertTrue(self.result["checks"][name],name)
        self.assertFalse(self.result["result"]["response"]["value"]["actuation"]["safe_no_actuation"])
        self.assertEqual(0,self.result["world_build_count"])
    def test_crossed_measurements_refuse(self):
        for name in ("crossed_clock_refuses","crossed_torso_refuses"):
            self.assertTrue(self.result["checks"][name],name)
    def test_real_motor_application_and_ledger(self):
        self.assertTrue(self.result["checks"]["real_step_motor_application_and_ledger"],self.result["result"]["ledger"])
    def test_cold_reader_rejects_crossed_body_stop_and_post_measurement(self):
        self.assertTrue(self.result["checks"].get("same_process_complete_reader"),self.result["result"].get("reader"))
        report=self.result["result"]["report"];cases={"positive":report}
        for name in ("body_missing","body_clock","body_changed","early_stop_command","stop_speed","post_motion_rehashed","cycle_receipt","final_memory","early_terminal"):
            item=copy.deepcopy(report);row=item["development_walking_entry"]["rows"][0];cycle=item["development_cycle_stop"]
            if name=="body_missing":row["request"].pop("measured_body_frame")
            elif name=="body_clock":row["request"]["measured_body_frame"]["semantic_step"]+=1
            elif name=="body_changed":
                row["request"]["measured_body_frame"]["ordered_body_states"][1]["pose_world"]["position_m"]["x"]+=.001
                row["ordered_body_states"][1]["pose_world"]["position_m"]["x"]+=.001
            elif name=="early_stop_command":row["development_cycle_stopping"]=True
            elif name=="stop_speed":row["request"]["command"]["desired_planar_velocity_task_m_s"]["x"]=0.
            elif name=="post_motion_rehashed":
                source=cycle["rows"][0]["post_native_source"];source["observation"]["center_of_mass"]["linear_velocity_world_m_s"]["x"]+=.1
                binding=json.loads((ROOT/"sdk/development/recovery_candidates/v50-startup-reference-velocity-core-v1.runtime.json").read_bytes());core=shared.LocomotionCore(binding["runtime"]["path"])
                digest=core.canonicalize_json(source["observation"])["sha256"]
                source["precommand_trace"]["observation_sha256"]=digest;item["retained_arm"]["trace_rows"][0]["observation_sha256"]=digest
            elif name=="cycle_receipt":cycle["rows"][0]["advance_receipt"]["next_memory"]["last_command"]+=1
            elif name=="final_memory":cycle["final_memory"]["stopping_commands"]=120
            else:item["stop_reason"]="diagnostic_cycle_aligned_stop_complete"
            cases[name]=item
        for name in ("missing_row", "clock", "amplitude", "phase_mode", "output", "motor", "authority", "body_population", "memory", "step_hash", "raw_response_hash"):
            item=copy.deepcopy(report);retention=item["development_walking_entry"];row=retention["rows"][0]
            if name=="missing_row":retention["rows"].clear();retention["sample_count"]=0
            elif name=="clock":row["measured_global_step"]+=1
            elif name=="amplitude":row["request"]["command"]["gait_amplitude"]=1.
            elif name=="phase_mode":row["request"]["command"]["phase_progression_mode"]="clocked"
            elif name=="output":row["native_output"]["actuation"]["ordered_commands"][0]["target_velocity_rad_s"]+=.1
            elif name=="motor":row["ordered_motor_applications"][0]["host_applied_target_velocity_rad_s"]+=.1
            elif name=="authority":retention["release_authority"]=True
            elif name=="body_population":row["ordered_body_states"].pop()
            elif name=="memory":row["request"]["memory"]["ordered_limb_memory"][0]["gait_step"]+=1
            elif name=="step_hash":row["full_step_receipt_sha256"]="sha256:"+"0"*64
            else:row["raw_native_response_sha256"]="sha256:"+"0"*64
            cases[name]=item
        self.assertEqual(21,len(cases))
        path=self.root/"reader_cases.json";path.write_text(json.dumps({"reader_cases":cases},separators=(",",":"))+"\n",encoding="utf-8")
        run=self._run_retained("res://tests/test_development_v50_measured_body_adapter.gd",["--",str(path)],"cold_reader",60)
        results=shared.marker(run,"V50_BODY_COLD_READER ")
        self.assertTrue(results["positive"]["ok"],results["positive"])
        for name,result in results.items():
            if name!="positive":self.assertFalse(result["ok"],name)
        print("V50_COLD_READER_REFUSALS",json.dumps({k:v.get("failure_code") for k,v in results.items() if k!="positive"}),flush=True)
    def test_startup_clocks_and_resume_only_selection(self):
        for k in ("actual_initial_memory_clocks","start_normal_plan","worker_resume_only","seeded_legacy_start","start_selection_refusals"):
            self.assertTrue(self.result["checks"][k],k)
    def test_start_reader_and_all_six_refusals(self):
        for k in ("start_reader_actual_request","start_reader_legacy_refusal","start_zero_resume_valid_negative",*("start_reader_refuses_"+k for k in ("phase","seed","missing_first","memory_phase","duplicate_limb","selector"))):
            self.assertTrue(self.result["checks"][k],k)
    def test_all_amplitude_ramp_commands(self):
        self.assertTrue(self.result["checks"]["complete_72_command_ramp"])
    def test_real_facade_sampling_mode_and_legacy_modes(self):
        for k in ("historical_and_prefix_phase_modes_unchanged","selected_phase_mode_boundary","actual_facade_sampler_receives_selected_mode"):
            self.assertTrue(self.result["checks"][k],k)
    def test_stop_command_keeps_selected_route(self):
        for k in ("stop_changes_resume_command_only","stop_keeps_contact_gated_mode"):
            self.assertTrue(self.result["checks"][k],k)
    def test_first_eight_native_targets_and_memory(self):
        value=self.result["result"]["response"]["value"];commands=value["actuation"]["ordered_commands"]
        self.assertEqual(8,len(commands))
        self.assertTrue(all(c["requested_target_position_rad"]==0. and c["clamped_target_position_rad"]==0. for c in commands))
        self.assertTrue(value["actuation"]["receipt"]["recovery_support_plane"]["first_step_holds_neutral_reference"])
        self.assertEqual(0.,value["actuation"]["receipt"]["recovery_support_plane"]["reference_step_duration_s"])
    def test_declared_recovery_limits_and_bound_runtime(self):
        selection=selected();limits=candidate.limits(selection)
        self.assertEqual((320,30,1,240,3160,3512),tuple(limits[k] for k in ("maximum_precondition_steps","walking_prefix_steps","interaction_steps","maximum_passive_descent_steps","after_interaction_steps","maximum_steps_per_child")))
        self.assertEqual("sporespore_exact_s169_prone_to_standing_controller_v20",selection["post_kick_controller_id"])
        self.assertEqual("",candidate.walking_memory_transition_id(selection["diagnostic_schedule"]))
        binding=candidate.read(candidate.resource_path(selection["candidate"]["runtime_binding"]))
        runtime=next(f for f in binding["source_files"] if f["path"]=="sdk/core/src/runtime.rs")
        self.assertEqual(runtime["raw_sha256"],candidate.sha(ROOT/runtime["path"]))
    def test_selection_source_and_kind_refusals(self):
        selection=selected();schedule=selection["diagnostic_schedule"]
        for changed in ({"walking_start_profile_id":False},{"walking_start_profile_id":0},{"walking_start_profile_id":"unknown"},{"walking_entry_profile_id":""}):
            with self.subTest(changed=changed),self.assertRaises(ValueError):candidate.walking_start_id(dict(schedule,**changed))
        with patch.object(candidate,"sha",return_value="sha256:"+"0"*64),self.assertRaisesRegex(ValueError,"WALKING_ENTRY_CONTRACT_DRIFT"):candidate.walking_start_id(schedule)
        path=candidate.schedule_path(selection["candidate"]["diagnostic_schedule_id"]);original=candidate.read(path);reader=candidate.read
        for bad in (True,None,19,"unknown"):
            changed=copy.deepcopy(original);changed["schedules"][selection["candidate"]["diagnostic_schedule_id"]]["walking_entry_profile_id"]=bad
            with patch.object(candidate,"read",side_effect=lambda p:changed if p==path else reader(p)),self.assertRaisesRegex(ValueError,"WALKING_ENTRY_SELECTION"):candidate.selection(selection["candidate_profile"])
    def test_v23_start_negative_stays_exact(self):
        import test_development_recovery_walking_start as historical
        historical.WalkingStart.test_retained_v23_start_is_240_without_regrading(self)
    def test_v18_entry_negative_and_r173_stay_exact(self):
        import test_development_recovery_walking_entry as historical
        record=candidate.read(ROOT/"sdk/development/recovery_attempts/88d86686f4d1421286b59eb03c7d8115.json")
        path=Path(record["kicked_report"]["path"]);self.assertEqual(record["kicked_report"]["raw_sha256"],candidate.sha(path))
        self.report=candidate.read(path)
        historical.WalkingEntry.test_retained_walking_payload_limit_and_original_negative_preserved(self)
        self.assertEqual("sha256:c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f",candidate.sha(ROOT/"sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json"))
if __name__ == "__main__": unittest.main()
