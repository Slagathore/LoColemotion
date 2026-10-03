"""Zero-world safety checks for the actual showcase construction/owner path."""
import copy
import json
import math
import os
from pathlib import Path
import subprocess
import sys
import time
import unittest
from unittest.mock import patch
import uuid

from showcase_model import Compiler, PROTOCOL, S169, StreamIdentity, generated, impulse, runnable, validate_descriptor


class Construction(unittest.TestCase):
    def test_locked_display_file_does_not_abort_native_retention(self):
        from showcase_owner import write
        with patch.object(Path,"write_text",side_effect=PermissionError("reader still owns display file")):
            self.assertFalse(write(Path("unused-frame.json"),{"frame":1},presentation=True))
    def test_kick_before_first_frame_refuses_without_aborting_session(self):
        from showcase_owner import Owner
        owner=Owner.__new__(Owner)
        owner.session_thread=type("Active",(),{"is_alive":lambda self:True})()
        owner.status=dict(state="running",native_session="fresh",engine="rapier_parry")
        owner.frame={}
        with self.assertRaisesRegex(ValueError,"first native frame"):
            owner.command(dict(kind="kick",magnitude=.25,direction="right"))
        self.assertEqual(owner.status["state"],"running")
        owner.frame=dict(session_id="stale")
        with self.assertRaisesRegex(ValueError,"first native frame"):
            owner.command(dict(kind="kick",magnitude=.25,direction="right"))
    def test_crossed_native_streams_and_false_preflight(self):
        hello=dict(schema_version=PROTOCOL,session_id="session",engine_id="rapier_parry",message_type="hello",native_physics=True,replay=False,source_commit="source")
        frame=dict(hello,message_type="frame",frame_index=1,ordered_bodies=[{"body_id":"torso"}])
        done=dict(hello,message_type="completed",ok=True,summary={"world_build_count":0})
        guard=StreamIdentity("session","rapier_parry","source",False)
        with self.assertRaises(ValueError): guard.accept(frame)
        guard.accept(hello);guard.accept(frame)
        with self.assertRaises(ValueError): guard.accept(frame)
        for change in ({"session_id":"other"},{"engine_id":"mujoco"},{"replay":True},{"frame_index":12001},{"ordered_bodies":[]}):
            with self.assertRaises(ValueError): guard.accept(dict(frame,**change))
        guard.accept(done)
        with self.assertRaises(ValueError): guard.accept(frame)
        preflight=StreamIdentity("session","rapier_parry","source",True);preflight.accept(hello)
        with self.assertRaises(ValueError): preflight.accept(frame)
        with self.assertRaises(ValueError): preflight.accept(dict(done,summary={"world_build_count":1}))
        with self.assertRaises(ValueError): preflight.accept(dict(hello,message_type="ready_to_start"))
        preflight.accept(done)
    def test_seed_reproducibility_and_native_boundary(self):
        self.assertEqual(generated(169), S169)
        self.assertEqual(generated(42), generated(42))
        self.assertNotEqual(generated(42), generated(43))
        for seed in (0, 42, 169, 2147483647): validate_descriptor(generated(seed))
        for seed in (True, -1, 2147483648, .5):
            with self.assertRaises(ValueError): generated(seed)

    def test_invalid_and_crossed_construction(self):
        for field in ("torso_length_scale", "upper_length_fraction", "front_limb_mass_scale"):
            for value in (math.nan, math.inf, -1, True, "1", 5):
                descriptor = dict(S169); descriptor[field] = value
                with self.assertRaises(ValueError): validate_descriptor(descriptor)
        for descriptor in ({}, dict(S169, unknown=1), dict(S169, schema_version="crossed")):
            with self.assertRaises(ValueError): validate_descriptor(descriptor)

    def test_native_support_refusals(self):
        runnable(S169, "rapier_parry", 0)
        runnable(S169, "mujoco", 0)
        runnable(S169, "godot_jolt", 74)
        for descriptor, engine, phase in ((generated(42), "rapier_parry", 0), (S169,"unknown",0), (S169,"mujoco",74), (S169,"godot_jolt",360), (S169,"godot_jolt",True)):
            with self.assertRaises(ValueError): runnable(descriptor, engine, phase)

    def test_impulse_envelope_and_limits(self):
        packet = impulse("fresh", 10, .25, "right", "command1")
        self.assertEqual(packet["apply_at_frame"], 70)
        self.assertEqual(packet["impulse_n_s"], {"x":0,"y":0,"z":.25})
        for frame, force, direction in ((0,.25,"right"),(10,9,"right"),(10,math.nan,"right"),(10,.25,"up"),(10,True,"right")):
            with self.assertRaises(ValueError): impulse("fresh",frame,force,direction,"command")

    @unittest.skipUnless(os.environ.get("EXPLORER_TEST_CORE"), "explicit compiled core required")
    def test_actual_compiler_zero_world(self):
        compiler = Compiler(Path(os.environ["EXPLORER_TEST_CORE"]))
        for descriptor in (S169,generated(42),generated(43)):
            result = compiler.compile(descriptor)
            self.assertEqual(result["world_build_count"],0)
            self.assertFalse(result["physical_acceptance_authority"])
            self.assertEqual(len(result["morphology"]["morphology_spec"]["bodies"]),9)

    @unittest.skipUnless(os.environ.get("EXPLORER_TEST_OUTPUT"), "durable test output root required")
    def test_real_job_owner_reaps_leaf_and_descendant(self):
        from showcase_owner import OwnedChild, jobs
        folder=Path(os.environ["EXPLORER_TEST_OUTPUT"])/("ownership-"+uuid.uuid4().hex)
        folder.mkdir()
        child=OwnedChild([sys.executable,"-B","-c","import time; time.sleep(60)"],folder,{},folder)
        identities=[]
        try:
            deadline=time.monotonic()+10
            while time.monotonic()<deadline:
                pids=child.job.pids()
                if len(pids)>=2: break
                time.sleep(.05)
            self.assertGreaterEqual(len(pids),2)
            identities=[jobs.identity(pid) for pid in pids]
        finally: child.close()
        self.assertTrue(all(not jobs.alive(item) for item in identities))
        self.assertFalse(any("SPORESPORE_" in k for k in json.loads((folder/"leaf.json").read_text())["env"]))


if __name__=="__main__": unittest.main(verbosity=2)
