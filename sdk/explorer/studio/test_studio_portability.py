"""Relocation and corruption controls, including the actual retained viewing pack."""
import copy
import json
import os
from pathlib import Path
import shutil
import unittest
from unittest.mock import patch
import uuid

from studio_layout import EVIDENCE, ROOT
import studio_portability as portable
import studio_proof


class PortableStudio(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.folder = Path(os.environ.get("EXPLORER_TEST_OUTPUT", EVIDENCE)) / ("studio-portability-controls-" + uuid.uuid4().hex)
        cls.folder.mkdir(parents=True)
        (cls.folder / "synthetic.json").write_text('{"synthetic":true,"world_build_count":0}\n')

    def setUp(self):
        self.root = self.folder / uuid.uuid4().hex
        self.root.mkdir()

    def fixture(self):
        cfg = {}
        for role in portable.ROLES:
            path = self.root / (role + ".bin")
            path.write_bytes(role.encode())
            cfg[role] = str(path)
        cfg["mujoco_python"] = str(self.root / "python.exe")
        Path(cfg["mujoco_python"]).write_bytes(b"synthetic interpreter")
        output = self.root / "installation"
        output.mkdir()
        with patch.object(portable, "inspect_python", return_value={"packages": {}, "synthetic": True}):
            value = portable.make_portable(cfg, output, "a" * 40, {})
        path = output / "dependencies.json"
        path.write_text(json.dumps(value))
        return cfg, path, value

    def test_relocation_uses_new_paths_and_rejects_runtime_drift(self):
        cfg, path, value = self.fixture()
        moved = self.root / "relocated installation"
        path.parent.rename(moved)
        path = moved / path.name
        with patch.object(portable, "inspect_python", return_value=value["python_runtime"]):
            result = portable.load_dependencies(path, "a" * 40, cfg["mujoco_python"])
            self.assertTrue(all(Path(result[r]).is_relative_to(moved) for r in portable.ROLES))
            runtime = Path(result["core"])
            runtime.write_bytes(b"different native image")
            with self.assertRaises(ValueError):
                portable.load_dependencies(path, "a" * 40, cfg["mujoco_python"])

    def test_manifest_refuses_crossed_missing_duplicate_and_authority(self):
        cfg, path, value = self.fixture()
        variants = []
        for flag in ["release_authority", "physical_acceptance_authority", "binary_distribution_authorized"]:
            variants.append(dict(value, **{flag: True}))
        variants.append(dict(value, source_commit="b" * 40))
        variants.append(dict(value, runtime_files=value["runtime_files"][1:]))
        variants.append(dict(value, runtime_files=value["runtime_files"] * 2))
        crossed = copy.deepcopy(value)
        crossed["roles"]["core"] = "../outside.dll"
        variants.append(crossed)
        for variant in variants:
            path.write_text(json.dumps(variant))
            with self.assertRaises(ValueError), patch.object(portable, "inspect_python", side_effect=AssertionError("Must refuse before loading runtime")):
                portable.load_dependencies(path, "a" * 40, cfg["mujoco_python"])

    def test_extra_file_and_python_drift_refused(self):
        cfg, path, value = self.fixture()
        with patch.object(portable, "inspect_python", return_value={"packages": {}, "synthetic": False}):
            with self.assertRaises(ValueError):
                portable.load_dependencies(path, "a" * 40, cfg["mujoco_python"])
        (path.parent / "runtimes/unexpected.dll").write_bytes(b"extra")
        with self.assertRaises(ValueError):
            portable.load_dependencies(path, "a" * 40, cfg["mujoco_python"])

    def test_path_and_evidence_boundaries(self):
        for name in ["../a", "/a", "C:/a", "a/../b", "a//b", "a\\b", "a/./b", ""]:
            with self.assertRaises(ValueError):
                portable.within(self.root, name)
        for root, output in [(self.root, self.root), (self.root, self.root.parent / "outside"),
                             (self.root, self.root / "source/session"), (self.root / "tmp", self.root / "tmp/session")]:
            with self.assertRaises(ValueError):
                portable.evidence_destination(output, root, source_root=self.root / "source")
        self.assertEqual(portable.evidence_destination(self.root / "retained/session", self.root / "retained", source_root=self.root / "source"), self.root / "retained/session")

    def test_real_proof_relocates_and_recomputes_all_frames(self):
        pack = self.root / "proof-pack"
        studio_proof.curate(ROOT, pack, EVIDENCE, "a" * 40)
        moved = self.root / "relocated proof"
        pack.rename(moved)
        report = studio_proof.verify(moved)
        self.assertEqual(report["viewing_frames"], 5962)
        self.assertEqual(report["raw_streams_verified"], 3)
        self.assertGreater(report["missing_scientific_dependencies"], 0)
        manifest = moved / "viewing-closure.json"
        original = manifest.read_bytes()
        value = json.loads(original)
        value["missing_scientific_dependencies"] = []
        manifest.write_text(json.dumps(value))
        with self.assertRaises(ValueError):
            studio_proof.verify(moved)
        manifest.write_bytes(original)
        (moved / "raw/godot_jolt/stream.jsonl").write_bytes(b"corrupt raw stream")
        with self.assertRaises(ValueError):
            studio_proof.verify(moved)
        # Keep the failed synthetic copy for diagnosis; the source archive is untouched.


if __name__ == "__main__":
    unittest.main()
