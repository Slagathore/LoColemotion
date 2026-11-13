"""Zero-world righting controls, public compilation and full shared reader replay."""
import copy
from contextlib import ExitStack
import json
import math
import os
from pathlib import Path
import unittest
from unittest.mock import patch
import uuid

import mujoco
import numpy as np

import creature_righting as subject
import creature_native as route
import creature_native_model as native_model
from creature_batch import compile_creature, bridge
from gpu_quadruped_model import FLAGS, sha
from showcase_model import S169, generated
from test_creature_batch import fixture, observation
from test_creature_native import metadata, primary_snapshot
from test_portable_search import _fixture


def profiles():
    common = dict(half_period_steps=24, position_gain_s_inv=6., maximum_speed_rad_s=2.5,
                  maximum_slew_rad_s_per_step=.1)
    return [dict(common, id="zero_velocity_brake", mode="zero_velocity_brake", pose_a=[0.]*8, pose_b=[0.]*8),
            dict(common, id="side_rock", mode="rock", pose_a=[.85, .85, -.4, -.4, -.85, -.85, .4, .4],
                 pose_b=[-.4, -.4, .85, .85, .4, .4, -.85, -.85])]


def population(bodies=None):
    return dict(schema_version=subject.SCHEMA, descriptors=[S169] if bodies is None else bodies,
        profiles=profiles(), conditions=[dict(id="nominal", motor_effectiveness=[1.]*8)],
        starts=[dict(id="inverted", roll_rad=math.pi), dict(id="side", roll_rad=math.pi/2)])


def motion_profile(contact=False, polarity=1):
    return dict(profiles()[1], id=f"motion_{int(contact)}_{'positive' if polarity == 1 else 'negative'}",
        mode="motion_rock", feedback_axis_body=[1., 0., 0.], feedback_polarity=polarity,
        feedback_minimum_hold_steps=12, feedback_rate_deadband_rad_s=.05,
        feedback_requires_distal_contact=contact)


class RightingControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.core_path = Path(os.environ["QUADRUPED_TEST_CORE"])
        cls.core = bridge.LocomotionCore(cls.core_path)
        cls.template = _fixture(cls.core)["provider_request"]["state"]
        cls.root = Path(os.environ["EXPLORER_TEST_OUTPUT"]) / "creature-righting"
        cls.root.mkdir()

    def setUp(self):
        self.trap = ExitStack()
        self.addCleanup(self.trap.close)
        for name in ("MjModel", "MjData", "mj_step", "mj_step1", "mj_step2", "mj_forward"):
            self.trap.enter_context(patch.object(mujoco, name, side_effect=AssertionError("Physics in righting controls")))

    def batch(self, spec=None):
        result = subject.RightingBatch(self.core, subject.expand(spec or population())["cells"], seed=1061113)
        self.addCleanup(result.close)
        return result

    def observations(self, batch, step=0, inverted=True):
        values = []
        for cell in batch.controllers:
            value = observation(cell, fixture(cell.creature, self.template), step)
            if inverted:
                value["state"]["base_pose_world"]["orientation_xyzw"] = dict(x=1., y=0., z=0., w=0.)
            values.append(value)
        return values

    def test_public_recovery_compiler_maps_exact_authority_and_keeps_walking_bytes(self):
        plain = compile_creature(self.core, S169)
        cell = self.batch().controllers[0]
        self.assertEqual(cell.creature["base_compiled"], plain["compiled"])
        self.assertEqual(cell.creature["recovery_compilation"]["descriptor"]["joint_authority"],
                         subject.recovery_descriptor(S169)["joint_authority"])
        self.assertEqual([j["upper_limit_rad"] for j in cell.spec["joints"]], [1.6, 1.1]*4)
        self.assertEqual(compile_creature(self.core, S169), plain)
        self.assertEqual(native_model.expected_native_fields(cell.creature)["jnt_range"][1:], [[-1.6, 1.6], [-1.1, 1.1]]*4)

    def test_32_shapes_match_scalar_and_batch_without_native_objects(self):
        spec = population([S169] + [generated(i) for i in range(12000, 12031)])
        spec["profiles"].extend([motion_profile(), motion_profile(True)])
        batch = self.batch(spec)
        scalars = [subject.RightingController(self.core, row, seed=1061113) for row in subject.expand(spec)["cells"]]
        self.addCleanup(lambda: [c.close() for c in scalars])
        self.assertEqual(len({c.binding["body_shape_sha256"] for c in batch.controllers}), 32)
        self.assertEqual(len(batch.controllers), 256)
        for step in range(27):
            observations = self.observations(batch, step, inverted=step != 26)
            for value in observations:
                value["state"]["base_twist_world"]["angular_velocity_rad_s"]["x"] = -.2 if step < 18 else .2
            self.assertEqual(batch.step(observations), [c.step(o) for c, o in zip(scalars, observations, strict=True)])

    def test_phase_change_brake_and_observed_upright_stance(self):
        batch = self.batch()
        for step in range(25):
            rows = batch.step(self.observations(batch, step))
            self.assertEqual(rows[0]["native_targets"], [0.]*8)
        self.assertEqual(rows[1]["resolution"]["phase"], "rock_1")
        rows = batch.step(self.observations(batch, 25, inverted=False))
        self.assertEqual(rows[1]["resolution"]["phase"], "upright_stance")
        self.assertEqual([r["target_position_rad"] for r in rows[1]["resolution"]["ordered_commands"]], [0.]*8)
        for contact, polarity in ((False, 1), (True, 1), (False, -1)):
            spec = population(); spec["profiles"][1] = motion_profile(contact, polarity)
            trial = self.batch(spec)
            for step in range(25):
                obs = self.observations(trial, step)
                for value in obs:
                    value["state"]["base_twist_world"]["angular_velocity_rad_s"]["x"] = -.2
                    for site in value["state"]["ordered_contact_observations"]:
                        site.update(presence=False, bears_support=False)
                feedback = trial.step(obs)[1]["resolution"]["motion_feedback"]
                if step < 12:
                    self.assertEqual((feedback["phase_after"], feedback["selection_reason"]), (0, "minimum_hold"))
                if step == 12:
                    expected = (0, "waiting_for_contact") if contact else (1, "measured_rotation") if polarity == 1 else (0, "measured_hold")
                    self.assertEqual((feedback["phase_after"], feedback["selection_reason"]), expected)
                if step == 24 and (contact or polarity == -1):
                    self.assertEqual((feedback["phase_after"], feedback["selection_reason"]), (1, "bounded_fallback"))
            feedback = trial.step(self.observations(trial, 25, inverted=False))[1]["resolution"]["motion_feedback"]
            self.assertEqual((feedback["hold_steps_after"], feedback["selection_reason"]), (0, "upright_stance"))
        # Rotating the entire observation about world up must preserve the
        # body-frame phase response and the resulting joint commands.
        spec = population(); spec["profiles"][1] = motion_profile()
        plain, yawed = self.batch(spec), self.batch(spec)
        yaw = .7
        for step in range(13):
            left, right = self.observations(plain, step), self.observations(yawed, step)
            for value in left:
                value["state"]["base_twist_world"]["angular_velocity_rad_s"] = dict(x=-.2, y=0., z=0.)
            for value in right:
                value["state"]["base_pose_world"]["orientation_xyzw"] = dict(x=math.cos(yaw/2), y=0., z=-math.sin(yaw/2), w=0.)
                value["state"]["base_twist_world"]["angular_velocity_rad_s"] = dict(x=-.2*math.cos(yaw), y=0., z=.2*math.sin(yaw))
            a, b = plain.step(left)[1], yawed.step(right)[1]
            self.assertEqual(a["native_targets"], b["native_targets"])
            self.assertAlmostEqual(a["resolution"]["motion_feedback"]["axis_angular_rate_rad_s"],
                                   b["resolution"]["motion_feedback"]["axis_angular_rate_rad_s"], places=14)
        self.assertEqual(a["resolution"]["motion_feedback"]["selection_reason"], "measured_rotation")
        for axis in ([0., 0., 1.], [math.sqrt(.5), 0., math.sqrt(.5)]):
            spec = population(); spec["profiles"][1] = motion_profile()
            spec["profiles"][1]["feedback_axis_body"] = axis
            trial = self.batch(spec)
            for step in range(13):
                obs = self.observations(trial, step)
                for value in obs:
                    # The inverted body maps its +Z direction to world -Z.
                    value["state"]["base_twist_world"]["angular_velocity_rad_s"] = dict(x=-.2*axis[0], y=0., z=.2*axis[2])
                feedback = trial.step(obs)[1]["resolution"]["motion_feedback"]
            self.assertAlmostEqual(feedback["axis_angular_rate_rad_s"], -.2, places=14)
            self.assertEqual((feedback["phase_after"], feedback["selection_reason"]), (1, "measured_rotation"))

    def test_speed_slew_and_joint_guard_preserve_caps_and_record_breaches(self):
        batch = self.batch()
        for step in range(5):
            observations = self.observations(batch, step)
            if step == 4:
                for o in observations:
                    for i, j in enumerate(o["state"]["ordered_joint_observations"]):
                        j["position_rad"] = 1.7 if i % 2 == 0 else -1.2
            rows = batch.step(observations)
            for row in rows:
                commands = row["resolution"]["ordered_commands"]
                for i, command in enumerate(commands):
                    actual = command["canonical_velocity_rad_s"]
                    self.assertLessEqual(abs(actual), command["maximum_speed_rad_s"])
                    if not command["joint_guard_applied"]:
                        self.assertLessEqual(abs(actual-row["resolution"]["previous_canonical_velocities_rad_s"][i]), .100000000000001)
                    if step == 4:
                        self.assertTrue(command["observed_joint_limit_breach"])
                        self.assertLessEqual(actual, 0.) if i % 2 == 0 else self.assertGreaterEqual(actual, 0.)

    def test_invalid_profiles_refuse(self):
        mutations = [("maximum_speed_rad_s", 3.6), ("maximum_slew_rad_s_per_step", math.nan),
                     ("half_period_steps", True), ("pose_a", [1.]*8), ("pose_b", [0.]*7),
                     ("position_gain_s_inv", math.inf), ("mode", "teleport")]
        for key, value in mutations:
            p = profiles()[1]; p[key] = value
            with self.assertRaises(ValueError): subject.profile(p)
        for key, value in (("feedback_axis_body", [0., 0., 0.]), ("feedback_axis_body", [1., math.nan, 0.]),
                ("feedback_axis_body", [2., 0., 0.]), ("feedback_polarity", True),
                ("feedback_minimum_hold_steps", 24), ("feedback_minimum_hold_steps", 11),
                ("feedback_rate_deadband_rad_s", 0.), ("feedback_requires_distal_contact", 1),
                ("pose_b", profiles()[1]["pose_a"])):
            p = motion_profile(); p[key] = value
            with self.assertRaises(ValueError): subject.profile(p)

    def test_crossed_missing_stale_and_nonfinite_inputs_are_atomic(self):
        batch = self.batch()
        for change in ("crossed", "missing", "stale", "nan", "joint_order", "quaternion"):
            obs = self.observations(batch)
            if change == "crossed": obs[-1]["cell_id"] = obs[0]["cell_id"]
            if change == "missing": obs.pop()
            if change == "stale": obs[-1]["state"]["semantic_step"] = 1
            if change == "nan": obs[-1]["state"]["ordered_joint_observations"][0]["position_rad"] = math.nan
            if change == "joint_order": obs[-1]["state"]["ordered_joint_observations"].reverse()
            if change == "quaternion": obs[-1]["state"]["base_pose_world"]["orientation_xyzw"]["x"] = 2.
            with self.assertRaises(ValueError): batch.step(obs)
            self.assertTrue(all(c.step_index == 0 and c.previous == [0.]*8 for c in batch.controllers))
        spec = population(); spec["profiles"].append(motion_profile())
        trial = self.batch(spec)
        for step in range(12): trial.step(self.observations(trial, step))
        before = [(copy.deepcopy(c.previous), c.step_index, c.motion_phase, c.motion_steps) for c in trial.controllers]
        for change in ("nan_rate", "missing_rate", "contact_order", "contact_type", "phantom_contact"):
            obs = self.observations(trial, 12)
            for value in obs: value["state"]["base_twist_world"]["angular_velocity_rad_s"]["x"] = -.2
            state = obs[-1]["state"]
            if change == "nan_rate": state["base_twist_world"]["angular_velocity_rad_s"]["x"] = math.nan
            if change == "missing_rate": state["base_twist_world"]["angular_velocity_rad_s"].pop("x")
            if change == "contact_order": state["ordered_contact_observations"].reverse()
            if change == "contact_type": state["ordered_contact_observations"][0]["presence"] = 1
            if change == "phantom_contact": state["ordered_contact_observations"][0].update(presence=False, bears_support=True)
            with self.assertRaises(ValueError): trial.step(obs)
            self.assertEqual(before, [(c.previous, c.step_index, c.motion_phase, c.motion_steps) for c in trial.controllers])
        obs = self.observations(trial, 12)
        for value in obs: value["state"]["base_twist_world"]["angular_velocity_rad_s"]["x"] = -.2
        rows = trial.step(obs)
        self.assertEqual(rows[2]["resolution"]["motion_feedback"]["phase_after"], 1)

    def test_input_output_ownership_and_closed_calls(self):
        spec = population(); spec["profiles"].append(motion_profile()); batch = self.batch(spec)
        spec["profiles"][1]["pose_a"][0] = -.9
        self.assertEqual(batch.controllers[1].candidate["pose_a"][0], .85)
        rows = batch.step(self.observations(batch))
        rows[1]["native_targets"][0] = 999.
        self.assertNotEqual(batch.controllers[1].previous[0], 999.)
        rows[2]["resolution"]["motion_feedback"]["axis_body"][0] = 999.
        rows[2]["resolution"]["motion_feedback"]["phase_after"] = 999
        self.assertEqual(batch.controllers[2].candidate["feedback_axis_body"], [1., 0., 0.])
        self.assertNotEqual(batch.controllers[2].motion_phase, 999)
        batch.close()
        with self.assertRaises(ValueError): batch.step(self.observations(batch, 1))
        with self.assertRaises(ValueError): batch.controllers[0].step(self.observations(batch, 1)[0])

    def test_fresh_fallen_initializers_clear_every_collision(self):
        for cell in self.batch(population([S169, generated(12031)])).controllers:
            for roll in (-math.pi, -math.pi/2, -.3, 0., .3, math.pi/2, math.pi):
                q, v = subject.initial_arrays([cell.creature], [roll])
                self.assertAlmostEqual(q[0, 2]+subject.ground_clearance(cell.creature, roll), .005, places=6)
                self.assertEqual(q[0, 7:].tolist(), [0.]*8)
                self.assertEqual(v.tolist(), [[0.]*14])
                self.assertLess(abs(float(np.dot(q[0, 3:7], q[0, 3:7]))-1), 2e-7)

    def test_population_expansion_refuses_aliases_and_budgets(self):
        for kind in ("shape", "candidate", "condition", "start", "budget"):
            spec = population()
            if kind == "shape": spec["descriptors"].append(copy.deepcopy(S169))
            if kind == "candidate": spec["profiles"].append(dict(profiles()[1], id="alias"))
            if kind == "condition": spec["conditions"].append(dict(spec["conditions"][0], id="alias"))
            if kind == "start": spec["starts"].append(dict(spec["starts"][0], id="alias"))
            if kind == "budget": spec["descriptors"] = [generated(i) for i in range(65)]
            with self.assertRaises(ValueError): subject.expand(spec)
        spec = population(); spec["profiles"].extend([motion_profile(), motion_profile(polarity=-1)])
        self.assertEqual(len(subject.expand(spec)["cells"]), 8)
        spec["profiles"].append(dict(motion_profile(), id="feedback_alias"))
        with self.assertRaises(ValueError): subject.expand(spec)

    def test_route_dispatch_initial_partition_and_expansion_binding(self):
        c = route.declaration(route.HERE / "creature_righting_route_v1.json")
        pre = route.preflight(c, self.core_path)
        self.assertEqual((pre["world_build_count"], pre["planned_gpu_worlds"], pre["distinct_body_shapes"]), (0, 8, 2))
        self.assertEqual(route.controller_types(c)[0], subject.RightingBatch)
        indices = [1, 3]
        sliced = route.batch_contract(c, indices)
        self.assertEqual(sliced["initial_roll_angles_rad"], [c["initial_roll_angles_rad"][i] for i in indices])
        c["cells"].pop()
        with self.assertRaises(ValueError): subject.verify_expansion(c)

    def test_failed_unsafe_and_transient_outcomes_cannot_enter_shortlist(self):
        c = dict(righting_spec=population(), righting_selection=subject.SELECTION, outer_steps=120)
        c.update(subject.expand(c["righting_spec"]))
        batch = self.batch()
        metrics = [dict(subject.initial_metrics(), terminal_upright_dwell_steps=300, longest_upright_dwell_steps=300)
                   for _ in c["cells"]]
        self.assertEqual(subject.assess(c, metrics, batch.bindings)["eligible_worlds"], 4)
        metrics[1]["terminal_upright_dwell_steps"] = 0
        metrics[1]["longest_upright_dwell_steps"] = 600
        metrics[3]["joint_limit_violation_steps"] = 1
        result = subject.assess(c, metrics, batch.bindings)
        self.assertEqual(result["failed_worlds"], 2)
        self.assertEqual(result["shortlists"][0]["candidates"], [])
        self.assertEqual(len(result["episodes"]), 4)
        creature = batch.controllers[0].creature
        base = dict(qpos=copy.deepcopy(creature["spec"]["initial_qpos"]), qvel=[0.]*14,
                    contacts=[dict(geom=[0, k]) for k in (3, 5, 7, 9)])
        cases = [("all_four_feet", base, True)]
        for index in range(4):
            row = copy.deepcopy(base); row["contacts"].pop(index)
            cases.append((f"missing_foot_{index}", row, False))
        for key in ("torso", "tilt", "height", "angular_speed", "joint_breach", "inverted"):
            row = copy.deepcopy(base)
            if key == "torso": row["contacts"].append(dict(geom=[0, 1]))
            if key == "tilt": row["qpos"][3:7] = [math.cos(.2), math.sin(.2), 0., 0.]
            if key == "height": row["qpos"][2] *= .7
            if key == "angular_speed": row["qvel"][3] = .51
            if key == "joint_breach": row["qpos"][7] = 1.60001
            if key == "inverted": row["qpos"][3:7] = [0., 1., 0., 0.]
            cases.append((key, row, False))
        for name, row, expected in cases:
            with self.subTest(measurement=name):
                m = subject.initial_metrics()
                for _ in range(300): subject.measure(m, row, creature)
                self.assertEqual(m["terminal_upright_dwell_steps"] >= 300 and m["joint_limit_violation_steps"] == 0, expected)
        m = subject.initial_metrics()
        for _ in range(300): subject.measure(m, base, creature)
        subject.measure(m, cases[1][1], creature)
        self.assertEqual((m["terminal_upright_dwell_steps"], m["longest_upright_dwell_steps"]), (0, 300))

    def test_full_shared_reader_replays_righting_and_refuses_corruption(self):
        for motion in (False, True):
            with self.subTest(motion_feedback=motion):
                self._reader_case(motion)

    def _reader_case(self, motion, sequence_profile=None):
        c = route.declaration(route.HERE / "creature_righting_route_v1.json")
        if motion:
            c["righting_spec"]["profiles"][1] = motion_profile(True)
            c.update(subject.expand(c["righting_spec"]))
            c["outer_steps"] = 26
        if sequence_profile is not None:
            c["righting_spec"]["profiles"][1] = copy.deepcopy(sequence_profile)
            c.update(subject.expand(c["righting_spec"]))
            c["outer_steps"] = 66
        c = route.batch_contract(c, [0, 1])
        folder = self.root / uuid.uuid4().hex; folder.mkdir()
        batch = subject.RightingBatch(self.core, c["cells"], seed=c["seed"])
        self.addCleanup(batch.close)
        creatures = [cell.creature for cell in batch.controllers]
        metas = [metadata(v) for v in creatures]
        snapshots = [primary_snapshot(m) for m in metas]
        packed, differing = native_model.merge_snapshots(snapshots)
        transport = dict(source_models=snapshots, packed_model=packed, differing_fields=differing)
        def write(path, value):
            (folder/path).write_text(json.dumps(value, allow_nan=False), encoding="utf-8")
        for i, (creature, meta) in enumerate(zip(creatures, metas, strict=True)):
            (folder/f"cell_{i}").mkdir()
            write(f"cell_{i}/creature.json", creature); write(f"cell_{i}/native-model.json", meta)
            (folder/f"cell_{i}/model.xml").write_bytes(creature["model_xml"].encode())
        for name, data in [("source-models", snapshots), ("model-transport", transport), ("model-after", packed)]:
            write(name+".json", data)
        positions, velocities = route.initial_arrays(creatures, c)
        controls, trace, times = [], [], []
        validator = route.StreamValidator(c, creatures, metas)
        transform = np.asarray([[1., 0., 0.], [0., 0., -1.], [0., 1., 0.]])
        for outer in range(c["outer_steps"]):
            for i, cell in enumerate(batch.controllers):
                roll = c["initial_roll_angles_rad"][i]
                tree = subject.RigidTree(cell.spec)
                frame = tree.kinematics([0., float(positions[i, 2]), 0.], [math.sin(roll/2), 0., 0., math.cos(roll/2)], [0.]*8)
                native = dict(qpos=positions[i].tolist(), qvel=velocities[i].tolist(), time_s=outer*5*c["timestep_s"],
                    xpos=[[0.]*3]+[(transform @ v).tolist() for v in frame["positions"]],
                    xmat=[np.eye(3).reshape(-1).tolist()]+[(transform @ r @ transform.T).reshape(-1).tolist() for r in frame["rotations"]],
                    subtree_com=[[0.]*3]*10, cvel=[[0.]*6]*10, contacts=[], sampling_stage="prepared_before_control")
                native["xipos"] = copy.deepcopy(native["xpos"])
                o = observation(cell, fixture(cell.creature, self.template), outer)
                for b in o["stability"]["ordered_body_states"]:
                    k = metas[i]["ordered_bodies"].index(b["body_id"])
                    b["pose_world"] = dict(position_m=bridge._vec_json(bridge._mujoco_to_canonical(native["xpos"][k])),
                        orientation_xyzw=bridge._quaternion_xyzw(bridge._canonical_rotation(native["xmat"][k])))
                    b["twist_world"] = dict(linear_velocity_m_s=dict(x=0., y=0., z=0.), angular_velocity_rad_s=dict(x=0., y=0., z=0.))
                o["state"]["base_pose_world"] = copy.deepcopy(o["stability"]["ordered_body_states"][0]["pose_world"])
                o["state"]["base_twist_world"] = copy.deepcopy(o["stability"]["ordered_body_states"][0]["twist_world"])
                for s in o["state"]["ordered_contact_observations"]:
                    s.update(presence=False, bears_support=False); s["provenance"]["engine_contact_ids"] = []
                for s in o["stability"]["ordered_support_contacts"]: s.update(presence=False, bears_support=False)
                row = cell.step(o)
                row.update(cell=i, outer_step=outer, native_observation=native, contact_compatibility_copy=dict(
                    unstepped_host_copy_only=True, legacy_geometry_after=[], native_geometry=[]))
                controls.append(row); validator.control(row)
            for sub in range(5):
                step = outer*5+sub+1
                block = [dict(backend="gpu", cell=i, step=step, before_qpos=positions[i].tolist(), before_qvel=velocities[i].tolist(),
                    qpos=positions[i].tolist(), qvel=velocities[i].tolist(), ctrl=[route.f32(v) for v in controls[-2+i]["native_targets"]],
                    actuator_force_nm=[0.]*8, joint_force_nm=[0.]*8, on_force_cap=[False]*8,
                    time_s=step*c["timestep_s"], contacts=[], batch_contacts=0, nefc=0, overflow=0, warnings=[])
                    for i in range(2)]
                validator.native(block); trace.extend(block)
            times.append(dict(outer_step=outer, prepare_s=0., observation_readback_s=0., controller_s=0.,
                controller_capture_transfer_s=0., integration_s=0., capture_validation_write_s=0., outer_total_s=0.))
        for name, rows in (("controller", controls), ("trace", trace), ("timing", times)):
            (folder/(name+".jsonl")).write_text("".join(json.dumps(r)+"\n" for r in rows), encoding="utf-8")
        result = dict(schema_version="locolemotion_creature_worker_v1", ledger_scope=c["ledger_scope"],
            ok=True, synthetic=True, model_unchanged=True, constructed_gpu_worlds=2, native_model_constructions=2,
            stepped_cpu_worlds=0, controller_rows=len(controls), native_rows=len(trace), metrics=validator.finish(),
            stream_sha256={k:sha(folder/(k+".jsonl")) for k in ("controller", "trace", "timing")}, **{k:False for k in FLAGS})
        write("worker-result.json", result)
        report = route.audit_batch(folder, c, self.core_path, synthetic=True)
        self.assertEqual(report["controller_rows_replayed"], len(controls))
        self.assertEqual(report["native_rows_verified"], len(trace))
        self.assertEqual(report["reader_world_build_count"], 0)
        changes = [("native_targets", [99.]*8), ("binding", {}), ("resolution", {})]
        index = 1 if motion or sequence_profile is not None else 0
        if motion:
            self.assertEqual(controls[49]["resolution"]["motion_feedback"]["selection_reason"], "bounded_fallback")
            forged = copy.deepcopy(controls[index]["resolution"]); forged["motion_feedback"]["phase_after"] = 1
            changes.append(("resolution", forged))
        if sequence_profile is not None:
            self.assertEqual(controls[129]["resolution"]["sequence"]["state_after"]["cycle"], 1)
            for key, value in (("state_after", dict(phase=999)), ("mechanics", dict(kinetic_energy_j=1.))):
                forged = copy.deepcopy(controls[index]["resolution"])
                forged["sequence"][key].update(value)
                changes.append(("resolution", forged))
        for key, value in changes:
            changed = copy.deepcopy(controls); changed[index][key] = value
            (folder/"controller.jsonl").write_text("".join(json.dumps(r)+"\n" for r in changed), encoding="utf-8")
            result["stream_sha256"]["controller"] = sha(folder/"controller.jsonl"); write("worker-result.json", result)
            with self.assertRaises((ValueError, KeyError)): route.audit_batch(folder, c, self.core_path, synthetic=True)
        if sequence_profile is not None:
            (folder/"controller.jsonl").write_text("".join(json.dumps(r)+"\n" for r in controls), encoding="utf-8")
            result["stream_sha256"]["controller"] = sha(folder/"controller.jsonl"); write("worker-result.json", result)
            self.assertTrue(route.audit_batch(folder, c, self.core_path, synthetic=True)["ok"])
            result["metrics"][1]["sampled_joint_actuator_work_j"] += 1.
            write("worker-result.json", result)
            with self.assertRaises(ValueError): route.audit_batch(folder, c, self.core_path, synthetic=True)


if __name__ == "__main__":
    unittest.main()
