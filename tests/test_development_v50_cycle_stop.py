"""Cross-language replay of the finite schedule and corrupted/negative endpoints."""
import copy, hashlib, json, math, unittest, uuid
from pathlib import Path
import test_development_passive_entry_replay as shared
from development_recovery_candidate_test_support import ROOT
class CycleStop(unittest.TestCase):
    _run_retained = classmethod(shared.PassiveEntryReplay._run_retained.__func__)
    @classmethod
    def setUpClass(cls):
        cls.root = ROOT.parent / "SporeSpore_Evidence" / ("development-v50-godot-cycle-"+uuid.uuid4().hex)
        cls.root.mkdir();print("V50_GODOT_CYCLE_ROOT",cls.root,flush=True)
        root = cls.root.parent / "development-v50-mujoco-closed-loop-bd3a5a83e888432d8b3b50c9a1f46af4"
        raw=(root/"trajectory.jsonl").read_bytes()
        assert hashlib.sha256(raw).hexdigest()=="9142886a52f0d01c71df776a2e625cb55b4501e13ecab513688812623b828bb4"
        rows=[json.loads(l) for l in raw.splitlines()]
        value=json.loads((root/"input.json").read_bytes())
        core=shared.LocomotionCore(value["dll"]["path"] if isinstance(value["dll"],dict) else value["dll"])
        compiled=core.compile_bounded_quadruped(value["descriptor"])
        masses={b["body_id"]:b["mass_kg"] for b in compiled["morphology"]["morphology_spec"]["bodies"]}
        projected=[]
        for row in rows:
            n=row["command"];bodies=row["physics"]["post"]["bodies"];torso=bodies[0];q=torso["pose_world"]["orientation_xyzw"];norm=sum(v*v for v in q.values())
            velocity={k:sum(masses[b["body_id"]]*b["twist_world"]["linear_velocity_m_s"][k] for b in bodies)/sum(masses.values()) for k in ("x","y","z")}
            contacts=[dict(contact_site_id=l+"_foot",presence=b,bears_support=b) for l,b in row["physics"]["last_substep_bearing"].items()]
            contacts.sort(key=lambda c:("front_left_foot","front_right_foot","rear_left_foot","rear_right_foot").index(c["contact_site_id"]))
            projected.append(dict(control=dict(session_local_step=n,commanded_global_step=900+n,native_output=dict(next_memory=dict(ordered_limb_memory=row["output"]["next_memory"]["ordered_limb_memory"]),actuation=dict(receipt=dict(recovery_support_plane=dict(measured_support_transfer=row["output"]["actuation"]["receipt"]["recovery_support_plane"]["measured_support_transfer"]))))),source=dict(precommand_trace=dict(global_semantic_step=900+n,torso_tilt_rad=math.acos(max(-1,min(1,1-2*(q["x"]**2+q["z"]**2)/norm)))),observation=dict(semantic_step=900+n,state=dict(ordered_contact_observations=contacts,base_twist_world=torso["twist_world"]),center_of_mass=dict(linear_velocity_world_m_s=velocity,source_measurement=True)))))
        p=cls.root/"retained_projection.json";p.write_text(json.dumps(projected,separators=(",",":"))+"\n",encoding="utf-8")
        run=cls._run_retained("res://tests/test_development_v50_cycle_stop.gd",["--",str(p)],"cycle",60)
        cls.result=shared.marker(run,"V50_CYCLE_STOP_CHECKS ")
    def test_all_four_cycles_and_exact_stop_boundary(self):
        for k in ("no_early_cycle_cutoff","four_cycle_cutoff","no_early_stop","full_120_stop_and_30_settled","no_extra_command_after_stop","legacy_kernel_still_completes_at_720","selected_kernel_continues_past_720","selected_kernel_has_finite_1720_bound","selected_kernel_refuses_beyond_bound"):
            self.assertTrue(self.result["checks"][k],k)
    def test_corrupted_sources_refuse(self):
        for k in ("clock_refuses","contact_refuses","motion_refuses","source_refuses"):self.assertTrue(self.result["checks"][k],k)
    def test_unsettled_unsupported_and_incomplete_are_negatives(self):
        for k in ("moving_stop_is_valid_negative","unsupported_stop_is_valid_negative","walking_limit_is_not_completed_cycle"):self.assertTrue(self.result["checks"][k],k)
        self.assertEqual(0,self.result["world_build_count"])
if __name__ == "__main__": unittest.main()
