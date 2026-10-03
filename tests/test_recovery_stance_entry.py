"""Actual source capture, native neutral actuation, cold replay and timeout; zero worlds."""
import copy
import hashlib
import json
import math
from pathlib import Path
import unittest
import uuid
from development_recovery_candidate_test_support import selected, arguments, ROOT
import test_development_passive_entry_replay as shared
import recovery_walking_readiness as readiness


class StanceEntry(unittest.TestCase):
    _run_retained = classmethod(shared.PassiveEntryReplay._run_retained.__func__)

    @classmethod
    def setUpClass(cls):
        cls.selection = selected()
        cls.root = ROOT.parent / "SporeSpore_Evidence" / ("r10h-entry-interfaces-"+uuid.uuid4().hex)
        cls.root.mkdir()
        print("R10H_ENTRY_INTERFACES_ROOT", cls.root, flush=True)
        source = ROOT.parent / "SporeSpore_Evidence/r10h-readiness-source-5af1b33630f34484be9c418e42416eb3"
        raw = (source / "first_v50_command.json").read_bytes()
        assert hashlib.sha256(raw).hexdigest() == "27b28261113f51cf017684d9841a0afaed910203c32f73a97bfa3fa18b9c6ef0"
        command = json.loads(raw)
        raw = (source / "first_v50_native_source.json").read_bytes()
        assert hashlib.sha256(raw).hexdigest() == "7f25668a5d88b7629e4da3a5b273ce43bea9a55d72ba5a07ce16dc5d858e57a6"
        native = copy.deepcopy(json.loads(raw)["native_source"])
        core = shared.LocomotionCore(shared.entry.binding(cls.selection)["runtime"]["path"])
        cls.compiled = core.compile_bounded_quadruped(command["configuration"]["base_descriptor"])
        cls.limits = json.loads((ROOT / "sdk/recovery/r10h_stance_entry_finite_cycle_contract_v1.json").read_bytes())["stance_entry"]
        # Exact refused first neutral command. This diagnostic counterfactual
        # never edits or reclassifies the consumed native attempt.
        refusal_record = json.loads((ROOT / "sdk/recovery/r10h_neutral_frame_refusal_v1.json").read_bytes())
        refusal_raw = Path(refusal_record["report"]["path"]).read_bytes()
        assert "sha256:"+hashlib.sha256(refusal_raw).hexdigest() == refusal_record["report"]["raw_sha256"]
        refused = json.loads(refusal_raw)
        refusal = refused["detail"]["portable_step_receipt"]["development_native_step_failure"]
        refused_start = refused["partial_arm"]["active_walking_session"]["start_receipt"]
        rows = []
        measured = native["observation"]["semantic_step"]
        # Explicit synthetic callback population reconstructed for interface tests.
        # Original retained evidence is hash checked and never rewritten/regraded.
        for i, body in enumerate(command["row"]["request"]["measured_body_frame"]["ordered_body_states"]):
            pose, twist = copy.deepcopy(body["pose_world"]), copy.deepcopy(body["twist_world"])
            x, y, z, w = (pose["orientation_xyzw"][k] for k in ("x", "y", "z", "w"))
            h = math.sqrt(.5)
            pose["orientation_xyzw"] = dict(x=(x+z)*h, y=(y-w)*h, z=(z-x)*h, w=(w+y)*h)
            if i == 0:
                pose, twist = native["observation"]["state"]["base_pose_world"], native["observation"]["state"]["base_twist_world"]
            rows.append(dict(body_id=body["body_id"], callback_sequence=measured,
                             position_world_m=pose["position_m"], orientation_xyzw=pose["orientation_xyzw"],
                             linear_velocity_world_m_s=twist["linear_velocity_m_s"],
                             angular_velocity_world_rad_s=twist["angular_velocity_rad_s"], mass_kg=3.0 if i == 0 else .215))
            if i > 0 and i % 2 == 0:
                native["precommand_trace"]["foot_position_world_m_by_limb"][body["body_id"].removesuffix("_distal")] = [pose["position_m"][k] for k in ("x", "y", "z")]
        direct = dict(schema_version="sporespore_qsdk_r24d57_godot_direct_state_source_v1", semantic_step=measured,
                      ordered_body_states=rows, gravity_world_m_s2=native["observation"]["state"]["gravity_world_m_s2"], source_measurement=True)
        components = dict(semantic_step=measured, source_measurement=True,
                          direct_state_source_sha256=core.canonicalize_json(direct)["sha256"],
                          contact_source_receipt=native["contact_source_receipt"], contact_source_sha256=native["contact_source_sha256"])
        arm = dict(model_instance_id=native["model_instance_id"], body_population_instance_sha256=native["body_population_instance_sha256"],
                   trace_rows=[native["precommand_trace"]], last_collection=dict(global_result=dict(
                       measurement=dict(source_component_receipts=components, development_direct_state_source=direct),
                       bound=dict(observation_v3=native["observation"]))))
        path = cls.root / "synthetic_callback_input.json"
        path.write_text(json.dumps(dict(arm=arm, compiled=cls.compiled, synthetic_only=True,
            retained_refusal=refusal, retained_start=refused_start), separators=(",", ":"))+"\n", encoding="utf-8")
        run = cls._run_retained("res://tests/test_recovery_stance_entry.gd", ["--", *arguments(cls.selection), str(path)], "interfaces", 90)
        # Preserve all checks, including failures, instead of losing the actual interface receipt.
        rows = [shared.parse_json(line[len("R10H_STANCE_ENTRY_INTERFACES "):]) for line in run.stdout.decode().splitlines() if line.startswith("R10H_STANCE_ENTRY_INTERFACES ")]
        if len(rows) != 1 or b"ERROR:" in run.stdout+run.stderr:
            raise AssertionError((run.returncode, run.stdout[-5000:], run.stderr[-5000:]))
        cls.result = rows[0]

    def check_group(self, *prefixes):
        checks = {k: v for k, v in self.result["checks"].items() if any(k.startswith(p) for p in prefixes)}
        self.assertTrue(checks)
        self.assertTrue(all(checks.values()), (checks, self.result["result"].get("native_replay"), self.result["result"].get("timeout_failure")))

    def test_actual_worker_selects_neutral_session_only_for_r10h(self):
        self.check_group("selection", "runtime", "neutral_")
        self.assertEqual(0, self.result["world_build_count"])
        self.assertEqual(0, self.result["solver_step_count"])

    def test_callback_source_capture_replay_and_seven_corruptions(self):
        self.check_group("source_")
        measured = self.result["result"]["measurement"]
        expected = readiness.measure(measured["projection"]["request"], measured["packet"]["native_source"]["observation"]["center_of_mass"], self.compiled, self.limits)
        self.assertEqual(expected["checks"], measured["readiness"]["checks"])
        row = dict(source=measured, global_semantic_step=measured['readiness']['source_semantic_step'])
        verified = shared.entry.verify_entry_measurements([row], self.compiled, self.limits)
        self.assertEqual(1, verified['recomputed_samples'])
        for kind in ('ready', 'leg', 'clock'):
            bad = copy.deepcopy(row)
            if kind == 'ready': bad['source']['readiness']['ready'] = not bad['source']['readiness']['ready']
            elif kind == 'leg': bad['source']['readiness']['ordered_legs'][0]['maximum_required_reach_m'] += .001
            else: bad['global_semantic_step'] += 1
            with self.assertRaises(ValueError): shared.entry.verify_entry_measurements([bad], self.compiled, self.limits)

        for a, b in zip(expected["ordered_legs"], measured["readiness"]["ordered_legs"]):
            self.assertEqual(a["failed_references"], b["failed_references"])
            self.assertAlmostEqual(a["maximum_required_reach_m"], b["maximum_required_reach_m"], places=12)

    def test_actual_native_neutral_initialization_step_application_and_replay(self):
        self.check_group("native_neutral_", "frame_")
        receipt = self.result["result"]["native_fixture"]
        self.assertTrue(receipt["fresh_handoff_constructed_by_production_facade"])
        self.assertEqual(8, receipt["detached_hinge_parameter_container_count"])
        self.assertTrue(receipt["adapter_shutdown_receipt"]["explicit_shutdown_completed"])

    def test_neutral_replay_refuses_seven_rehashed_control_corruptions(self):
        self.check_group("command_refuses_")
        self.assertEqual(7, sum(k.startswith("command_refuses_") for k in self.result["checks"]))

    def test_actual_scheduler_dwell_resets_and_stops_exactly_at_240(self):
        self.check_group("timeout_", "exact_timeout", "legacy_refuses_")
        self.assertEqual("neutral_stance_entry_timeout", self.result["result"]["timeout_state"]["terminal_reason"])


if __name__ == "__main__": unittest.main()
