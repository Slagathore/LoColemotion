"""Negative controls for the new public index, not scientific qualification."""
import copy
import json
from pathlib import Path
import shutil
import tempfile
import unittest

from evidence import ROOT, read_json, verify, within


class EvidenceControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.scratch = tempfile.TemporaryDirectory()
        cls.root = Path(cls.scratch.name)
        cls.index = read_json(ROOT / "proof/EVIDENCE_INDEX.json")
        paths = {entry["path"] for entry in cls.index["local_files"]}
        paths.add("sdk/publication/build_replay.py")
        for name in paths:
            destination = cls.root / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / name, destination)

    @classmethod
    def tearDownClass(cls):
        cls.scratch.cleanup()

    def test_local_check_does_not_claim_external_or_experimental_verification(self):
        result = verify(self.index, self.root)
        self.assertGreater(result["external_artifacts_not_checked"], 0)
        self.assertEqual(result["external_artifacts_verified"], 0)
        self.assertFalse(result["experiment_revalidated"])

    def test_same_length_receipt_corruption_is_rejected(self):
        path = self.root / "proof/receipts/sdk1-clean-readiness.json"
        original = path.read_bytes()
        try:
            path.write_bytes(bytes([original[0] ^ 1]) + original[1:])
            with self.assertRaisesRegex(ValueError, "SHA-256 mismatch"):
                verify(self.index, self.root)
        finally:
            path.write_bytes(original)

    def test_missing_local_file_is_rejected(self):
        broken = copy.deepcopy(self.index)
        broken["local_files"][0]["path"] = "missing-receipt.json"
        with self.assertRaisesRegex(ValueError, "Missing file"):
            verify(broken, self.root)

    def test_sdk1_overcount_is_rejected(self):
        broken = copy.deepcopy(self.index)
        broken["sdk1_counts"]["passed"] = 21
        with self.assertRaisesRegex(ValueError, "SDK1 count mismatch"):
            verify(broken, self.root)

    def test_cross_engine_overclaim_is_rejected(self):
        broken = copy.deepcopy(self.index)
        broken["authority"]["formal_cross_engine_equivalence"] = True
        with self.assertRaisesRegex(ValueError, "overclaims authority"):
            verify(broken, self.root)

    def test_complete_dependency_claim_is_rejected(self):
        broken = copy.deepcopy(self.index)
        broken["records"][0]["dependency_closure_complete"] = True
        with self.assertRaisesRegex(ValueError, "complete dependency closure"):
            verify(broken, self.root)

    def test_path_traversal_and_absolute_paths_are_rejected(self):
        for path in ["../outside", "/etc/passwd", "C:/outside", "a/../../outside", "a\\outside"]:
            with self.subTest(path=path), self.assertRaises(ValueError):
                within(self.root, path)

    def test_external_artifacts_are_not_silently_skipped_when_requested(self):
        empty_archive = self.root / "empty-archive"
        empty_archive.mkdir(exist_ok=True)
        with self.assertRaisesRegex(ValueError, "Missing file"):
            verify(self.index, self.root, empty_archive)

    def test_replay_bytes_cannot_be_replaced(self):
        path = self.root / "replay/bundle.js"
        original = path.read_bytes()
        try:
            path.write_bytes(original[:-1])
            with self.assertRaisesRegex(ValueError, "Byte length mismatch"):
                verify(self.index, self.root)
        finally:
            path.write_bytes(original)

    def test_prose_accepts_native_line_endings_without_changing_content(self):
        path = self.root / "sdk/docs/ENGINE_INTEGRATION_COMPARISON.md"
        original = path.read_bytes()
        try:
            for ending in [b"\n", b"\r\n"]:
                path.write_bytes(original.replace(b"\r\n", b"\n").replace(b"\n", ending))
                self.assertTrue(verify(self.index, self.root)["ok"])
        finally:
            path.write_bytes(original)

    def test_receipts_cannot_opt_into_text_normalization(self):
        broken = copy.deepcopy(self.index)
        next(row for row in broken["local_files"] if row["path"].endswith("sdk1-clean-readiness.json"))["byte_basis"] = "lf_normalized_text"
        with self.assertRaisesRegex(ValueError, "Normalization is limited to indexed prose"):
            verify(broken, self.root)

    def test_exported_source_accepts_only_the_declared_checkout_identities(self):
        binding = next(row for row in self.index["local_files"] if row.get("checkout_alternatives"))
        path = self.root / binding["path"]
        original = path.read_bytes()
        try:
            path.write_bytes(original.replace(b"\r\n", b"\n"))
            self.assertTrue(verify(self.index, self.root)["ok"])
            path.write_bytes(path.read_bytes() + b" ")
            with self.assertRaisesRegex(ValueError, "Source checkout content mismatch"):
                verify(self.index, self.root)
        finally:
            path.write_bytes(original)

    def test_receipts_cannot_opt_into_checkout_alternatives(self):
        broken = copy.deepcopy(self.index)
        row = next(row for row in broken["local_files"] if row["path"].endswith("sdk1-clean-readiness.json"))
        row["checkout_alternatives"] = [{"sha256": row["sha256"], "byte_length": row["byte_length"]}]
        with self.assertRaisesRegex(ValueError, "Checkout alternatives are limited to exported SDK source"):
            verify(broken, self.root)


if __name__ == "__main__":
    unittest.main()
