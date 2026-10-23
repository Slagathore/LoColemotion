"""Real-ABI native-corpus gate with synthetic worlds trapped and corruptions retained."""
import copy
import json
import math
import os
from pathlib import Path
import shutil
import unittest
from unittest.mock import patch
import uuid
import mujoco
import numpy as np

import test_portable_search as fixtures
from gpu_repertoire import declaration, trial_plan, initial_arrays, preflight, ROOT
from gpu_quadruped_model import sha, f32
from portable_search_control import contract as legacy_contract, bridge
from repertoire_control import RepertoireController
from audit_gpu_repertoire import audit, audit_trial, validate_proposal
from audit_gpu_batch_execution import SECTIONS


def put(path, value):
    path.write_text(json.dumps(value, allow_nan=False, separators=(",", ":")), encoding="utf-8", newline="\n")


class RepertoireControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.core_path = Path(os.environ["QUADRUPED_TEST_CORE"])
        cls.baseline = Path(os.environ["PORTABLE_BATCH_BASELINE_CORE"])
        cls.core = bridge.LocomotionCore(cls.core_path)
        cls.oracle = bridge.LocomotionCore(cls.baseline)
        c = legacy_contract()
        c["core_sha256"] = sha(cls.core_path)
        with patch.object(fixtures, "contract", return_value=c):
            fixtures.PortableSearchControls.setUpClass()
        cls.f = fixtures.PortableSearchControls
        cls.compiled, cls.xml = cls.f.compiled, cls.f.xml
        cls.spec = copy.deepcopy(cls.f.spec)
        cls.spec["initial_lateral_velocities"] = []
        cls.root = Path(os.environ["EXPLORER_TEST_OUTPUT"]) / ("repertoire-fixture-" + uuid.uuid4().hex)
        cls.root.mkdir()
        cls.folder = cls.root / "physical"
        cls.folder.mkdir()
        cls.c = dict(declaration(), outer_steps=2, synthetic=True, training_data_authority=False)
        put(cls.root / "declaration.json", dict(contract=cls.c, synthetic=True))
        (cls.folder / "model.xml").write_text(cls.xml, encoding="utf-8", newline="\n")
        put(cls.folder / "compiled.json", cls.compiled)
        put(cls.folder / "inputs.json", cls.spec)
        cls.metadata = dict(model_sha256=sha(cls.folder / "model.xml"), compiled_sha256=sha(cls.folder / "compiled.json"),
            inputs_sha256=sha(cls.folder / "inputs.json"), ordered_bodies=cls.f.names, body_rootid=[0]+[1]*9,
            observation_stage="prepared_before_control", force_stage="completed_step_before_next_prepare")
        put(cls.folder / "native-model.json", cls.metadata)
        results = []
        with patch.object(mujoco, "MjModel", side_effect=AssertionError("Synthetic world")), \
                patch.object(mujoco, "MjData", side_effect=AssertionError("Synthetic data")):
            for plan in trial_plan(cls.c):
                results.append(cls.make_trial(cls.folder / plan["trial_id"], plan, cls.c))
        put(cls.folder / "worker-result.json", dict(ok=True, synthetic=True, trials=results,
            constructed_gpu_worlds=36, cpu_readback_views=36, stepped_cpu_worlds=0, controller_sessions_closed=True,
            physical_acceptance_authority=False, release_authority=False, equivalence_authority=False, training_data_authority=False))

    @classmethod
    def native(cls, plan, cell):
        n = cls.f.native("gpu", cell % 4)
        positions, velocities = initial_arrays(cls.spec, plan)
        n["qpos"], n["qvel"] = positions[cell].tolist(), velocities[cell].tolist()
        angle = plan["initial_native_roll_rad"]
        rotation = np.array([[1.,0.,0.],[0.,math.cos(angle),-math.sin(angle)],[0.,math.sin(angle),math.cos(angle)]])
        origin = np.asarray(n["qpos"][:3])  # Rotate around the same float32 root as the retained state.
        for name in ["xpos", "xipos", "xanchor"]:
            n[name] = [(origin + rotation @ (np.asarray(x)-origin)).tolist() for x in n[name]]
        n["xmat"] = [rotation.reshape(-1).tolist() for _ in n["xmat"]]
        n["xaxis"] = [(rotation @ np.asarray(x)).tolist() for x in n["xaxis"]]
        n["cvel"] = [[0.,0.,0.,0.,float(velocities[cell,1]),0.] for _ in n["cvel"]]
        for i, contact in enumerate(n["contacts"]):
            contact.update(world=cell,native_index=cell*4+i)
        return n

    @classmethod
    def observations(cls, native, outer):
        state, stability, kinematics = cls.f.observations(native, outer)
        for body in stability["ordered_body_states"]:
            index = cls.f.names.index(body["body_id"])
            body["pose_world"]["orientation_xyzw"] = bridge._quaternion_xyzw(bridge._canonical_rotation(native["xmat"][index]))
            if body["body_id"] == "torso":
                state["base_pose_world"] = copy.deepcopy(body["pose_world"])
        return state, stability, kinematics

    @classmethod
    def make_trial(cls, folder, plan, c):
        folder.mkdir()
        put(folder / "plan.json", plan)
        nworld = plan["nworld"]
        natives = [cls.native(plan, cell) for cell in range(nworld)]
        controls, trace = [], []
        batch = RepertoireController(cls.core, cls.compiled, dict(c, seed=plan["seed"]))
        try:
            for outer in range(c["outer_steps"]):
                rows = batch.step([cls.observations(n, outer) for n in natives])
                for cell, row in enumerate(rows):
                    native = copy.deepcopy(natives[cell])
                    native["time_s"] = outer*5*c["timestep_s"]
                    row.update(backend="gpu", cell=cell, outer_step=outer, native_observation=native)
                    controls.append(row)
                for sub in range(5):
                    for cell, row in enumerate(rows):
                        n = natives[cell]
                        trace.append(dict(backend="gpu",cell=cell,step=5*outer+sub+1,
                            before_qpos=n["qpos"],before_qvel=n["qvel"],qpos=n["qpos"],qvel=n["qvel"],
                            ctrl=list(map(f32,row["native_targets"])),actuator_force_nm=[0.]*8,joint_force_nm=[0.]*8,
                            on_force_cap=[False]*8,time_s=(5*outer+sub+1)*c["timestep_s"],
                            contacts=n["contacts"],batch_contacts=nworld*4,nefc=12,overflow=0,warnings=[]))
        finally:
            batch.close()
        timing=[dict(outer_step=i,measured=True,**{k:.01 for k in SECTIONS},outer_total_s=.1) for i in range(c["outer_steps"])]
        for name, rows in [("controller",controls),("trace",trace),("timing",timing)]:
            (folder / (name+".jsonl")).write_text("".join(json.dumps(r,allow_nan=False)+"\n" for r in rows),encoding="utf-8",newline="\n")
        result=dict(plan,completed=True,setup_s=.1,graph_capture_s=.1,outer_rows=nworld*c["outer_steps"],internal_rows=nworld*c["outer_steps"]*5,
            hashes={name:sha(folder/(name+".jsonl")) for name in ["controller","trace","timing"]})
        put(folder/"result.json",result)
        return result

    def damaged(self, stream, change):
        plan = trial_plan(self.c)[0]
        folder = self.root / uuid.uuid4().hex
        shutil.copytree(self.folder / plan["trial_id"], folder)
        path = folder / (stream + ".jsonl")
        rows = [json.loads(line) for line in path.read_text().splitlines()]
        change(rows)
        path.write_text("".join(json.dumps(r)+"\n" for r in rows),encoding="utf-8",newline="\n")
        result=json.loads((folder/"result.json").read_text())
        result["hashes"][stream]=sha(path)
        put(folder/"result.json",result)
        with self.assertRaises(ValueError):
            audit_trial(folder,plan,self.c,self.spec,self.compiled,self.metadata,self.oracle)

    def test_complete_population_scalar_replay_and_no_physical_authority(self):
        with patch.object(mujoco,"MjModel",side_effect=AssertionError("world")),patch.object(mujoco,"MjData",side_effect=AssertionError("data")):
            result=audit(self.folder,self.core_path,self.baseline)
        self.assertEqual(result["controller_rows"],72)
        self.assertEqual(result["internal_rows"],360)
        self.assertEqual(result["eligible_episodes"],36)
        self.assertFalse(result["training_data_authority"])
        self.assertEqual(result["calibration_worlds"]+result["evaluation_worlds"],0)

    def test_actual_preflight_and_group_initialization(self):
        result=preflight(self.core_path,self.baseline)
        self.assertEqual(result["world_build_count"],0)
        self.assertEqual(result["planned_gpu_worlds"],36)
        for plan in trial_plan(self.c):
            positions,velocities=initial_arrays(self.spec,plan)
            self.assertEqual(positions[0,4],f32(math.sin(plan["initial_native_roll_rad"]/2)))
            self.assertEqual(velocities[0,1],f32(plan["initial_native_lateral_velocity_m_s"]))
            self.assertTrue(np.array_equal(positions[0],positions[-1]))
        with self.assertRaises(ValueError):preflight(self.baseline,self.core_path)

    def test_window_endpoints_quality_and_raw_bindings(self):
        c=dict(self.c,outer_steps=30)
        plan=trial_plan(c)[0]
        folder=self.root/uuid.uuid4().hex
        with patch.object(mujoco,"MjModel",side_effect=AssertionError("world")),patch.object(mujoco,"MjData",side_effect=AssertionError("data")):
            self.make_trial(folder,plan,c)
            result=audit_trial(folder,plan,c,self.spec,self.compiled,self.metadata,self.oracle)
        self.assertEqual(len(result["episodes"]),9)
        for episode,raw in zip(result["episodes"],result["raw_bindings"],strict=True):
            self.assertEqual(len(episode["windows"]),1)
            self.assertEqual(episode["windows"][0]["quality_m_s"],-.2)
            self.assertEqual(episode["windows"][0]["start_position_xz_m"],episode["windows"][0]["end_position_xz_m"])
            self.assertEqual(raw["expected_internal_rows"],150)
            self.assertTrue(episode["synthetic"])

    def test_missing_reordered_and_crossed_memory_refuse(self):
        self.damaged("controller",lambda r:r.pop())
        self.damaged("trace",lambda r:r.reverse())
        self.damaged("controller",lambda r:r[9]["request"].__setitem__("memory",r[0]["request"]["memory"]))
        self.damaged("trace",lambda r:r[0]["before_qpos"].__setitem__(4,0.))

    def test_action_native_input_and_contact_corruptions_refuse(self):
        self.damaged("controller",lambda r:r[1]["resolution_request"]["provider_response"]["ordered_corrections"][0].__setitem__("canonical_velocity_delta_rad_s",99.))
        self.damaged("controller",lambda r:r[0]["native_targets"].__setitem__(0,99.))
        self.damaged("trace",lambda r:r[0]["joint_force_nm"].__setitem__(0,1.))
        self.damaged("trace",lambda r:r[0]["contacts"][0].__setitem__("world",8))
        self.damaged("trace",lambda r:r[0].__setitem__("overflow",1))
        self.damaged("controller",lambda r:r[0]["request"]["state"]["ordered_contact_observations"][0].__setitem__("presence",False))

    def test_split_seed_and_envelope_changes_refuse(self):
        self.damaged("controller",lambda r:r[0]["resolution_request"]["provider_request"].__setitem__("seed",1))
        self.damaged("controller",lambda r:r[0]["resolution_request"]["provider_request"]["safety_envelope"]["ordered_actuator_limits"][0].__setitem__("maximum_absolute_correction_rad_s",5.))
        c=copy.deepcopy(self.c)
        c["retrieval_contract_sha256"]="0"*64
        with self.assertRaises(ValueError):trial_plan(c)
        self.assertEqual([p["group_id"] for p in trial_plan(self.c)],["train_0","train_1","train_2","train_3"])


if __name__=="__main__":unittest.main()
