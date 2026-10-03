"""Exact historical replay inputs, read-only and independent of live file drift."""

import copy
import json
import os
from pathlib import Path
import sys
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "sdk/conformance"))
import qsdk_r10f_l15_frozen_source_replay as replay


class FrozenSourceReplay(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tree = replay.load_retired_tree()

    def test_original_materializer_refusal_uses_exact_frozen_git_inputs(self):
        result = replay.replay_retired_materializer(self.tree)
        self.assertIs(result["ok"], True)
        self.assertEqual(
            "DESIGN_AUTHORITY_13_IDENTITY", result["historical_materializer_refusal"]
        )
        self.assertEqual(13, result["historical_authority_prefix_passed_count"])
        self.assertEqual(17, result["snapshot_source_file_count"])
        self.assertEqual(16, len(result["read_source_paths"]))
        self.assertEqual(1, result["declared_checkout_source_projection_count"])
        projection = result["declared_checkout_source_projections"][0]
        self.assertEqual(
            "sdk/adapters/godot/gdscript/recovery_contiguous_boundary_transport_v1.gd",
            projection["path"],
        )
        self.assertEqual(19339, projection["source_git_byte_length"])
        self.assertEqual(19902, projection["declared_checkout_byte_length"])
        self.assertIs(projection["original_checkout_file_claimed_present"], False)
        for key in (
            "historical_source_function_rewritten",
            "historical_authority_or_expectation_rewritten",
            "successor_source_qualified",
            "source_checkout_or_evidence_files_written",
            "physical_execution_authorized",
            "physical_acceptance_authority",
            "release_authority",
        ):
            self.assertIs(result[key], False)
        for key in (
            "snapshot_source_reads_from_current_worktree",
            "model_construction_count",
            "world_attempt_count",
            "world_build_count",
            "native_physics_read_count",
            "solver_step_count",
        ):
            self.assertEqual(0, result[key])

    def test_historical_sources_never_fall_back_to_working_file_reads(self):
        real_open = Path.open
        projected = {(ROOT / name).resolve() for name in self.tree.identities}

        def refuse_projected_worktree(path, *args, **kwargs):
            if path.resolve() in projected:
                raise AssertionError("WORKTREE_SOURCE_FALLBACK:" + str(path))
            return real_open(path, *args, **kwargs)

        with mock.patch.object(Path, "open", refuse_projected_worktree):
            self.assertIs(replay.replay_retired_materializer(self.tree)["ok"], True)

    def test_write_modes_paths_and_missing_files_are_refused_without_mutation(self):
        frozen = self.tree.root / replay.DESIGN
        for mode in ("w", "wb", "a", "ab", "x", "xb", "r+", "rb+"):
            with self.subTest(mode=mode), self.assertRaisesRegex(
                ValueError, "READ_ONLY_MODE"
            ):
                frozen.open(mode)
        for path in ("../x", "/x", "C:/x", "a/../b", "a//b", "./a", "a\\b", "", None):
            with self.subTest(path=path), self.assertRaises(ValueError):
                self.tree.root / path
        missing = self.tree.root / "sdk/missing_source_file.py"
        self.assertFalse(missing.is_file())
        with self.assertRaises(FileNotFoundError):
            missing.read_bytes()
        with self.assertRaisesRegex(ValueError, "NO_WORKTREE_FILE_FALLBACK"):
            os.fspath(frozen)
        self.assertEqual(str(ROOT), os.fspath(self.tree.root))

    def test_changed_bytes_bindings_source_members_and_commit_kinds_fail_closed(self):
        objects = dict(self.tree._objects)
        identities = {p: dict(b) for p, b in self.tree.identities.items()}
        for path in objects:
            changed = dict(objects)
            changed[path] += b" "
            with self.subTest(source=path), self.assertRaises(ValueError):
                replay.FrozenGitTree(replay.RETIRED_SOURCE, changed, identities)
        for key, value in (
            ("byte_length", True),
            ("byte_length", float(identities[replay.DESIGN]["byte_length"])),
            ("byte_length", str(identities[replay.DESIGN]["byte_length"])),
            ("raw_sha256", "sha256:" + "0" * 64),
            ("git_blob_oid", "0" * 40),
            ("path", "sdk/other.py"),
        ):
            changed = copy.deepcopy(identities)
            changed[replay.DESIGN][key] = value
            with self.subTest(binding=key), self.assertRaises(ValueError):
                replay.FrozenGitTree(replay.RETIRED_SOURCE, objects, changed)
        for commit in ("HEAD", "f" * 39, True):
            with self.subTest(commit=commit), self.assertRaises(ValueError):
                replay.FrozenGitTree(commit, objects, identities)
        wrong_tree = replay.FrozenGitTree("f" * 40, objects, identities)
        with self.assertRaisesRegex(ValueError, "REPLAY_TREE"):
            replay.replay_retired_materializer(wrong_tree)
        changed = dict(objects)
        del changed[replay.DESIGN]
        with self.assertRaises(ValueError):
            replay.FrozenGitTree(replay.RETIRED_SOURCE, changed, identities)

    def test_rehashed_substitution_and_nonexact_line_ending_projection_are_rejected(
        self,
    ):
        objects = dict(self.tree._objects)
        identities = {p: dict(b) for p, b in self.tree.identities.items()}
        path = "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
        objects[path] += b" "
        identities[path] = replay.blob_identity(path, objects[path])
        changed_tree = replay.FrozenGitTree(replay.RETIRED_SOURCE, objects, identities)
        with self.assertRaisesRegex(ValueError, "REPLAY_GIT_ORIGIN"):
            replay.replay_retired_materializer(changed_tree)
        authority = json.loads(self.tree._objects[replay.DESIGN])["bound_authorities"][
            9
        ]
        raw = self.tree._objects[authority["path"]]
        for key, replacement in (
            ("byte_length", 19903),
            ("raw_sha256", "sha256:" + "0" * 64),
            ("git_blob_oid", "0" * 40),
        ):
            modified = dict(authority)
            modified[key] = replacement
            with self.subTest(field=key), self.assertRaises(ValueError):
                replay.declared_checkout_projection(raw, modified)


if __name__ == "__main__":
    unittest.main(verbosity=2)
