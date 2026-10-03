"""The base design and branch addendum remain distinct required authorities."""

from __future__ import annotations

import copy
import json
from pathlib import Path
import subprocess
import sys
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "sdk/conformance"))
import qsdk_r10f_l14_authority_contract as contract
import qsdk_r10f_physical_closure as closer
import qsdk_r10f_authority_materializer as materializer


class AuthorityContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True
        ).strip()

    def test_four_positive_and_thirty_one_corruption_controls(self):
        actual = contract.self_test()
        self.assertTrue(actual["ok"])
        self.assertEqual(actual["positive_control_count"], 4)
        self.assertEqual(actual["mutation_rejection_count"], 31)
        self.assertEqual(actual["base_and_predecessor_mutation_rejection_count"], 16)

    def test_actual_shared_and_closer_bindings_reopen_the_same_committed_authorities(
        self,
    ):
        expected = contract.expected_authority_bindings()
        actual = contract.authority_bindings(self.source)
        self.assertTrue(contract.authority_bindings_valid(actual))
        self.assertEqual(actual, expected)
        self.assertEqual(
            closer.validate_l14_repair_design(self.source), actual["repair_design"]
        )
        self.assertEqual(
            closer.validate_l14_branch_completeness_addendum(self.source),
            actual["branch_completeness_addendum"],
        )
        self.assertEqual(
            closer.validate_l14_predecessor_physical_closure(self.source),
            actual["consumed_predecessor_physical_closure"],
        )
        self.assertEqual(
            materializer.repair_design_binding(self.source), actual["repair_design"]
        )
        self.assertEqual(
            materializer.branch_completeness_addendum_binding(self.source),
            actual["branch_completeness_addendum"],
        )
        self.assertEqual(
            materializer.predecessor_physical_closure_binding(self.source),
            actual["consumed_predecessor_physical_closure"],
        )
        # The prospective outer report and attempt must also carry the addendum;
        # a correct base-design digest alone cannot bind the new branch.
        report = closer.l9_synthetic_supervisor("behavior_positive")
        closer.validate_l9_report(report, report_path=None, verify_files=False)
        attempt = {
            **copy.deepcopy(report),
            "schema_version": closer.ATTEMPT_SCHEMA,
            "ledger_scope": closer.ledger_scope("consumed_physical_attempt_identity"),
            "status": "physical_identity_and_ordered_children_consumed_before_first_child_start",
            "seed": closer.SEED,
            "physical_execution_authorized": True,
            "child_retry_permitted": False,
            "child_replacement_permitted": False,
        }
        arguments = {
            "source_commit": report["source_commit"],
            "authority_sha256": report["authority_sha256"],
            "parent_attempt_id": report["attempt_id"],
        }
        closer.validate_l9_attempt_identity_document(
            attempt, report["ordered_child_manifest"], **arguments
        )
        for original in (report, attempt):
            for replacement in (None, closer.EXPECTED_REPAIR_DESIGN_SHA256):
                changed = copy.deepcopy(original)
                if replacement is None:
                    changed.pop("branch_completeness_addendum_sha256")
                else:
                    changed["branch_completeness_addendum_sha256"] = replacement
                with self.assertRaises(closer.ClosureFailure):
                    if original is report:
                        closer.validate_l9_report(
                            changed, report_path=None, verify_files=False
                        )
                    else:
                        closer.validate_l9_attempt_identity_document(
                            changed, report["ordered_child_manifest"], **arguments
                        )

    def test_actual_cli_emits_the_full_bundle_without_physical_authority(self):
        run = subprocess.run(
            [
                sys.executable,
                "-B",
                str(ROOT / "sdk/conformance/qsdk_r10f_l14_authority_contract.py"),
                "authority-bindings",
                "--source-commit",
                self.source,
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            timeout=60,
        )
        self.assertEqual(run.returncode, 0, run.stderr)
        lines = [
            line[len(contract.MARKER) :]
            for line in run.stdout.splitlines()
            if line.startswith(contract.MARKER)
        ]
        self.assertEqual(len(lines), 1)
        value = json.loads(lines[0])
        self.assertTrue(contract.authority_bindings_valid(value["binding"]))
        self.assertFalse(value["physical_execution_authorized"])
        for key in (
            "model_construction_count",
            "world_attempt_count",
            "world_build_count",
            "native_readback_count",
            "solver_step_count",
        ):
            self.assertIs(type(value[key]), int)
            self.assertEqual(value[key], 0)

    def test_no_omitted_swapped_or_promoted_authority_is_a_complete_bundle(self):
        base = contract.expected_authority_bindings()
        for key in base:
            missing = copy.deepcopy(base)
            missing.pop(key)
            self.assertFalse(contract.authority_bindings_valid(missing))
        swapped = copy.deepcopy(base)
        swapped["branch_completeness_addendum"] = swapped["repair_design"]
        self.assertFalse(contract.authority_bindings_valid(swapped))
        promoted = copy.deepcopy(base)
        promoted["branch_completeness_addendum"][
            "physical_execution_authorized_by_addendum"
        ] = True
        self.assertFalse(contract.authority_bindings_valid(promoted))

    def test_materializer_requires_each_exact_current_source_binding(self):
        stage = contract.expected_authority_bindings()
        materializer.validate_current_l14_authorities(stage, self.source)
        for key in stage:
            for mutation in ("missing", "float_count", "promoted"):
                with self.subTest(authority=key, mutation=mutation):
                    changed = copy.deepcopy(stage)
                    if mutation == "missing":
                        changed.pop(key)
                    elif mutation == "float_count":
                        changed[key]["byte_length"] = float(changed[key]["byte_length"])
                    else:
                        changed[key]["physical_execution_authorized"] = True
                    with self.assertRaisesRegex(
                        materializer.MaterializationFailure,
                        "CURRENT_L14_AUTHORITY_BINDINGS",
                    ):
                        materializer.validate_current_l14_authorities(
                            changed, self.source
                        )

    def test_materializer_historical_adapter_permission_is_still_l13(self):
        # The current checkout has the distinct L15 recovery-source pair. The
        # legacy reader must still refuse that drift; selecting L15 explicitly
        # preserves all 15 historical authorities and the separate L13 adapter
        # permission. Neither path widens that historical permission.
        with self.assertRaisesRegex(
            materializer.MaterializationFailure, "DESIGN_AUTHORITY_7_IDENTITY"
        ):
            materializer.design_binding(self.source)
        design, authorities = materializer.design_binding(
            self.source, require_l15_sources=True
        )
        self.assertEqual(len(authorities), 15)
        self.assertEqual(authorities, design["bound_authorities"])
        self.assertEqual(
            materializer.HISTORICAL_ADAPTER_PERMISSION_PATH,
            ROOT
            / "sdk/qsdk_r10f_l13_walking_ledger_transport_projection_successor_design_v1.json",
        )
        self.assertNotEqual(
            materializer.HISTORICAL_ADAPTER_PERMISSION_PATH,
            materializer.REPAIR_DESIGN_PATH,
        )

    def test_materializer_v15_stage_and_authority_refuse_addendum_omission(self):
        # The v19 manifest is now authored, so the actual production
        # constructors and validators bind its real digest without substitution.
        # The qualification/graph inputs remain explicit synthetic fixtures;
        # no file is materialized and no official authority is claimed.
        receipt = materializer.self_test()
        self.assertTrue(receipt["ok"])
        self.assertEqual(receipt["stage_valid_control_count"], 1)
        self.assertEqual(receipt["authority_valid_control_count"], 1)
        self.assertEqual(receipt["mutation_rejection_count"], 521)
        self.assertEqual(materializer.REPAIR_ID, "QSDK-R10F-L14")
        self.assertTrue(materializer.STAGE_SCHEMA.endswith("_v15"))
        self.assertTrue(materializer.AUTHORITY_SCHEMA.endswith("_v15"))

    def test_materializer_never_turns_a_source_refusal_into_a_binding(self):
        for function in (
            materializer.repair_design_binding,
            materializer.branch_completeness_addendum_binding,
            materializer.predecessor_physical_closure_binding,
        ):
            with self.subTest(function=function.__name__):
                with mock.patch.object(
                    contract,
                    "source_binding",
                    side_effect=ValueError("L14_SOURCE_BLOB:declared_control"),
                ):
                    with self.assertRaisesRegex(
                        materializer.MaterializationFailure, "L14_SOURCE_BLOB"
                    ):
                        function(self.source)

    def test_actual_supervisor_source_binder_and_strict_frozen_consumer(self):
        run = subprocess.run(
            [
                "pwsh",
                "-NoProfile",
                "-File",
                str(ROOT / "tests/test_qsdk_r10f_l14_supervisor_authority.ps1"),
                "-SourceCommit",
                self.source,
            ],
            cwd=ROOT,
            capture_output=True,
            input=json.dumps(
                {
                    "positive": materializer.l14_components.expected_receipt(),
                    "corruptions": materializer.l14_components.receipt_corruptions(),
                }
            ),
            text=True,
            timeout=90,
        )
        self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
        self.assertEqual(run.stderr, "")
        marker = "QSDK_R10F_L14_SUPERVISOR_AUTHORITY_ZERO_WORLD_PASS "
        lines = [
            line[len(marker) :]
            for line in run.stdout.splitlines()
            if line.startswith(marker)
        ]
        self.assertEqual(len(lines), 1)
        receipt = json.loads(lines[0])
        self.assertTrue(contract.authority_bindings_valid(receipt["bindings"]))
        self.assertEqual(receipt["source_commit"], self.source)
        self.assertEqual(receipt["loaded_actual_function_count"], 9)
        self.assertEqual(receipt["positive_control_count"], 3)
        self.assertEqual(receipt["frozen_binding_mutation_rejection_count"], 83)
        self.assertEqual(receipt["contract_receipt_mutation_rejection_count"], 48)
        self.assertEqual(receipt["component_qualification_positive_count"], 2)
        self.assertEqual(
            receipt["component_qualification_mutation_rejection_count"], 354
        )
        self.assertTrue(
            receipt["component_guard_called_by_actual_physical_authority_consumer"]
        )
        self.assertFalse(receipt["physical_execution_authorized"])
        for key in (
            "model_construction_count",
            "world_attempt_count",
            "world_build_count",
            "scene_tree_insertion_count",
            "native_readback_count",
            "solver_step_count",
        ):
            self.assertIs(type(receipt[key]), int)
            self.assertEqual(receipt[key], 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
