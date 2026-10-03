"""The original complete root-design audit remains historical inside L15."""

import json
from pathlib import Path
import subprocess
import sys
import time
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "sdk/conformance"))
import qsdk_r10f_l15_source_binding as binding
import qsdk_r10f_zero_world_implementation as implementation


class L15RootDesignProjection(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        started = time.perf_counter()
        cls.receipt = implementation.audit_design(require_l15_sources=True)
        print(
            "L15_ROOT_DESIGN_PROJECTION_SOURCE_ONLY_SECONDS="
            + str(round(time.perf_counter() - started, 3)),
            flush=True,
        )

    def test_original_full_audit_and_retained_negative_remain_nested_unchanged(self):
        receipt = self.receipt
        historical = receipt["historical_root_design_audit"]
        self.assertEqual(
            "sporespore_qsdk_r10f_l15_root_design_projection_v1",
            receipt["schema_version"],
        )
        self.assertEqual(
            "sporespore_qsdk_r10f_continuous_passive_recovery_successor_design_audit_v1",
            historical["schema_version"],
        )
        self.assertEqual(262, historical["design_mutation_refusal_count"])
        self.assertEqual(15, historical["bound_authority_count"])
        self.assertEqual(6, historical["predecessor_authority_count"])
        self.assertEqual(48, historical["source_seam_marker_count"])
        self.assertEqual(6, historical["epoch_sequence_refusal_count"])
        self.assertEqual(35, historical["retained_r10e_file_count"])
        self.assertEqual(79_688_410, historical["retained_r10e_total_byte_length"])
        self.assertEqual(6, historical["retained_r10e_valid_world_count"])
        self.assertEqual(3, historical["retained_r10e_valid_pair_count"])
        self.assertEqual(
            3841, historical["maximum_active_arm_solver_steps_if_later_authorized"]
        )
        self.assertNotIn("scene_tree_insertion_count", historical)
        self.assertEqual(3, receipt["current_disk_drift_path_count"])
        self.assertEqual(
            [*binding.SOURCE_ROLES, "scripts/lab/gait/sdk_godot_jolt_adapter.gd"],
            receipt["current_disk_drift_paths"],
        )
        self.assertEqual(
            67778, receipt["historical_auditor_source_binding"]["byte_length"]
        )
        self.assertIs(receipt["historical_authority_input_loader_replaced"], True)
        for key in (
            "historical_auditor_source_file_modified",
            "historical_design_and_behavior_predicates_rewritten",
            "historical_schedule_promoted_to_current_execution_budget",
            "physical_family_selector_changed",
            "whole_route_qualified",
            "official_qualification_consumed",
            "stage_file_written",
            "execution_authority_written",
            "physical_execution_authorized",
            "physical_acceptance_authority",
            "release_authority",
            "physics_state_modified",
        ):
            self.assertIs(receipt[key], False)
        for key in (*implementation.ZERO_COUNTERS, "scene_tree_insertion_count"):
            self.assertIs(type(receipt[key]), int)
            self.assertEqual(0, receipt[key])
        self.assertIs(historical["sdk1_m07_satisfied"], False)
        self.assertIs(historical["q_sdk_r10_satisfied"], False)

    def test_legacy_mode_stays_closed_and_opt_in_requires_an_exact_boolean(self):
        for value in (None, 0, 1, "true"):
            with self.subTest(value=value), self.assertRaisesRegex(
                implementation.AuditFailure, "DESIGN_L15_MODE_KIND"
            ):
                implementation.audit_design(require_l15_sources=value)
        with self.assertRaisesRegex(
            implementation.AuditFailure,
            "ROOT_DESIGN_CURRENT_DRIFT_NOT_EXACT_SUCCESSOR_SURFACE",
        ):
            implementation.audit_design()

    def test_coherently_rehashed_auditor_substitution_cannot_replace_original_program(
        self,
    ):
        original = binding.bind_current_source
        auditor = implementation.DESIGN_AUDIT_PATH.relative_to(ROOT).as_posix()
        changes = []

        def replace_auditor(relative, source_commit):
            raw, identity = original(relative, source_commit)
            if relative == auditor:
                changes.append(relative)
                raw += b"\n# deliberately substituted source\n"
                identity = {
                    **binding.frozen.blob_identity(relative, raw),
                    "source_commit": source_commit,
                }
            return raw, identity

        with mock.patch.object(
            binding, "bind_current_source", side_effect=replace_auditor
        ), self.assertRaisesRegex(
            implementation.AuditFailure, "DESIGN_L15_ORIGINAL_AUDITOR_PIN"
        ):
            implementation.audit_design(require_l15_sources=True)
        self.assertEqual([auditor], changes)

    def test_unlisted_current_source_drift_is_not_an_additional_permission(self):
        original = subprocess.run
        target = ["git", "hash-object", "--", "sdk/core/src/recovery_runtime.rs"]
        interceptions = []

        def wrong_current_oid(arguments, *args, **kwargs):
            if list(arguments) == target:
                interceptions.append(list(arguments))
                return subprocess.CompletedProcess(arguments, 0, "0" * 40 + "\n", "")
            return original(arguments, *args, **kwargs)

        with mock.patch.object(
            subprocess, "run", side_effect=wrong_current_oid
        ), self.assertRaisesRegex(
            implementation.AuditFailure,
            "ROOT_DESIGN_CURRENT_DRIFT_NOT_EXACT_SUCCESSOR_SURFACE",
        ):
            implementation.audit_design(require_l15_sources=True)
        self.assertEqual([target], interceptions)

    def test_actual_retained_file_hash_check_still_rejects_bad_read_without_a_write(
        self,
    ):
        root = json.loads(implementation.DESIGN_PATH.read_bytes())
        closure_path = next(
            a["path"]
            for a in root["bound_authorities"]
            if a["role"] == "consumed_r10e_l3_finite_negative"
        )
        closure = json.loads((ROOT / closure_path).read_bytes())
        retained = closure["retained_evidence"]
        selected = next(
            f for f in retained["retained_tree"]["files"] if f["byte_length"] > 0
        )
        target = (Path(retained["output_root"]) / selected["path"]).resolve()
        original = Path.read_bytes
        original_raw = original(target)
        interceptions = []

        def corrupt_read(path):
            raw = original(path)
            if path.resolve() == target:
                interceptions.append(path.resolve())
                return bytes([raw[0] ^ 1]) + raw[1:]
            return raw

        with mock.patch.object(
            Path, "read_bytes", corrupt_read
        ), self.assertRaisesRegex(implementation.AuditFailure, "R10E_TREE_SHA"):
            implementation.audit_design(require_l15_sources=True)
        self.assertEqual([target], interceptions)
        self.assertEqual(original_raw, original(target))


if __name__ == "__main__":
    unittest.main(verbosity=2)
