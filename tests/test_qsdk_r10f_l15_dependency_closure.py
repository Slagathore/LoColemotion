"""Exercise the complete prospective source graph without importing physics."""

import ast
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "sdk/conformance"))
import qsdk_r10f_dependency_closure as closure
import qsdk_r10f_zero_world_implementation as implementation
import qsdk_r10f_authority_materializer as materializer


class DependencyClosure(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.original = closure.MANIFEST_PATH.read_bytes()
        cls.manifest = json.loads(closure.L15_MANIFEST_PATH.read_bytes())
        cls.receipt = closure.audit(
            require_tracked=False, allow_unfinalized=False, require_l15_sources=True
        )

    def audit_manifest(self, manifest):
        original_read = Path.read_bytes
        raw = json.dumps(manifest, separators=(",", ":")).encode("utf-8")
        with mock.patch.object(
            Path,
            "read_bytes",
            lambda path: (
                raw if path == closure.L15_MANIFEST_PATH else original_read(path)
            ),
        ):
            return closure.audit(
                require_tracked=False, allow_unfinalized=False, require_l15_sources=True
            )

    def test_complete_current_population_has_all_owned_files_and_legacy_sources(self):
        receipt = self.receipt
        policy = self.manifest["policy"]
        self.assertTrue(receipt["ok"])
        self.assertEqual("QSDK-R10F-L15", receipt["repair_id"])
        self.assertEqual(57, receipt["gdscript_transitive_path_count"])
        self.assertEqual(25, receipt["rust_build_path_count"])
        self.assertEqual(60, receipt["l15_owned_source_path_count"])
        self.assertEqual(240, receipt["qualified_source_path_count"])
        self.assertEqual(4, receipt["mutation_rejection_count"])
        actual = set(receipt["qualified_source_paths"])
        self.assertTrue(set(policy["owned_source_paths"]).issubset(actual))
        legacy = json.loads(self.original)["policy"]
        for field in (
            "expected_gdscript_transitive_paths",
            "process_and_audit_paths",
            "rust_build_paths",
        ):
            self.assertTrue(set(legacy[field]).issubset(actual))
        self.assertTrue(set(closure.EXPECTED_RUNTIME_AUTHORITIES).issubset(actual))
        self.assertIn(
            "sdk/qsdk_r10f_development_route_ghost_physical_closure_v15.json", actual
        )
        self.assertFalse(set(closure.L15_RUNTIME_AUTHORITIES) & actual)
        for field in (
            "model_construction_count",
            "world_attempt_count",
            "world_build_count",
            "scene_tree_insertion_count",
            "native_readback_count",
            "solver_step_count",
        ):
            self.assertIs(type(receipt[field]), int)
            self.assertEqual(0, receipt[field])
        for field in (
            "official_qualification_executed_here",
            "physical_execution_authorized",
            "physics_state_modified",
            "physical_acceptance_authority",
            "release_authority",
        ):
            self.assertIs(False, receipt[field])

    def test_v19_bytes_and_default_family_are_preserved(self):
        self.assertEqual(self.original, closure.MANIFEST_PATH.read_bytes())
        self.assertEqual(22_462, len(self.original))
        self.assertEqual(
            closure.L15_PREDECESSOR_MANIFEST["raw_sha256"],
            "sha256:" + hashlib.sha256(self.original).hexdigest(),
        )
        self.assertEqual(
            "sporespore_qsdk_r10f_dependency_manifest_v19", closure.SCHEMA_VERSION
        )
        # Current L15 resources cannot silently refresh or pass the frozen v19
        # graph. Its default reader still refuses that real source mismatch.
        with self.assertRaisesRegex(
            closure.ClosureFailure, "R10F_DEPENDENCY_GDSCRIPT_CLOSURE"
        ):
            closure.audit(require_tracked=False, allow_unfinalized=False)

    def test_successor_selection_is_an_exact_external_boolean(self):
        for value in (None, 0, 1, "true", [], {}):
            with mock.patch.object(Path, "read_bytes") as read:
                with self.assertRaisesRegex(closure.ClosureFailure, "L15_MODE_KIND"):
                    closure.audit(
                        require_tracked=False,
                        allow_unfinalized=False,
                        require_l15_sources=value,
                    )
                read.assert_not_called()

    def test_missing_extra_crossed_and_promoted_manifest_fields_refuse(self):
        for key in self.manifest:
            changed = copy.deepcopy(self.manifest)
            del changed[key]
            with self.assertRaises(closure.ClosureFailure, msg=key):
                self.audit_manifest(changed)
        for path, value in (
            (("schema_version",), "sporespore_qsdk_r10f_dependency_manifest_v19"),
            (("repair_id",), "QSDK-R10F-L14"),
            (
                ("design_authority",),
                "QSDK-R10F-L14-terminal-boundaries-and-no-resume-addendum",
            ),
            (("predecessor_manifest_binding", "byte_length"), 22462.0),
            (("predecessor_manifest_binding", "raw_sha256"), "sha256:" + "0" * 64),
            (("policy", "undeclared"), True),
            (("claim_boundary", "physical_execution_authorized"), True),
            (("claim_boundary", "l15_official_qualification_executed_here"), True),
            (("claim_boundary", "solver_step_count"), False),
        ):
            changed = copy.deepcopy(self.manifest)
            owner = changed
            for key in path[:-1]:
                owner = owner[key]
            owner[path[-1]] = value
            with self.assertRaises(closure.ClosureFailure, msg=str(path)):
                self.audit_manifest(changed)

    def test_each_discovered_population_rejects_missing_reordered_and_extra_paths(self):
        for field in closure.l15_source_population():
            original = self.manifest["policy"][field]
            for values in (
                original[1:],
                list(reversed(original)),
                original + [original[-1]],
                [],
            ):
                changed = copy.deepcopy(self.manifest)
                changed["policy"][field] = values
                with self.assertRaisesRegex(
                    closure.ClosureFailure, "SOURCE_POPULATION:" + field
                ):
                    self.audit_manifest(changed)

    def test_omitted_transitive_resource_count_digest_and_runtime_crossings_refuse(
        self,
    ):
        policy = self.manifest["policy"]
        for field, value, code in (
            (
                "expected_gdscript_transitive_paths",
                policy["expected_gdscript_transitive_paths"][1:],
                "GDSCRIPT_CLOSURE",
            ),
            (
                "expected_qualified_source_count",
                policy["expected_qualified_source_count"] - 1,
                "QUALIFIED_COUNT",
            ),
            (
                "expected_qualified_source_path_sha256",
                "sha256:" + "0" * 64,
                "QUALIFIED_PATH_DIGEST",
            ),
            (
                "prospective_runtime_authority_paths",
                closure.EXPECTED_RUNTIME_AUTHORITIES,
                "RUNTIME_AUTHORITIES",
            ),
            (
                "active_runtime_artifact_paths",
                policy["inactive_declared_runtime_artifact_paths"],
                "RUNTIME_ARTIFACT_CLASSIFICATION",
            ),
        ):
            changed = copy.deepcopy(self.manifest)
            changed["policy"][field] = value
            with self.assertRaisesRegex(closure.ClosureFailure, code):
                self.audit_manifest(changed)

    def test_legacy_bytes_cannot_be_replaced_with_coherently_edited_policy(self):
        original_read = Path.read_bytes
        with mock.patch.object(
            Path,
            "read_bytes",
            lambda path: (
                self.original + b"\n"
                if path == closure.MANIFEST_PATH
                else original_read(path)
            ),
        ):
            with self.assertRaisesRegex(
                closure.ClosureFailure, "PREDECESSOR_MANIFEST_BYTES"
            ):
                closure.audit(
                    require_tracked=False,
                    allow_unfinalized=False,
                    require_l15_sources=True,
                )

    def test_duplicate_keys_nonfinite_and_nonobject_manifest_refuse(self):
        original_read = Path.read_bytes
        for raw in (b'{"policy":{},"policy":{}}', b'{"policy":NaN}', b"[]", b"\xff"):
            with mock.patch.object(
                Path,
                "read_bytes",
                lambda path: (
                    raw if path == closure.L15_MANIFEST_PATH else original_read(path)
                ),
            ):
                with self.assertRaises(closure.ClosureFailure):
                    closure.audit(
                        require_tracked=False,
                        allow_unfinalized=False,
                        require_l15_sources=True,
                    )

    def test_local_import_scan_executes_no_project_module_and_rejects_missing_import(
        self,
    ):
        target = "sdk/conformance/qsdk_r10f_l15_context_source_bridge.py"
        with mock.patch.object(closure.subprocess, "run") as run:
            paths = closure.local_python_import_closure([target])
            self.assertIn(target, paths)
            self.assertIn("sdk/conformance/qsdk_r10f_l15_collection_context.py", paths)
            self.assertIn("sdk/conformance/qsdk_r10f_physical_closure.py", paths)
            run.assert_not_called()
            missing = ast.parse("import qsdk_r10f_l15_missing_source")
            with mock.patch.object(closure.ast, "parse", return_value=missing):
                with self.assertRaisesRegex(
                    closure.ClosureFailure, "LOCAL_IMPORT_UNRESOLVED_OR_AMBIGUOUS"
                ):
                    closure.local_python_import_closure([target])
            run.assert_not_called()

    def test_tracked_source_requirement_cannot_be_reported_without_actual_git_membership(
        self,
    ):
        actual = set(self.receipt["qualified_source_paths"])
        actual.remove("sdk/qsdk_r10f_dependency_manifest_v20.json")
        with mock.patch.object(closure, "tracked_paths", return_value=actual):
            with self.assertRaisesRegex(
                closure.ClosureFailure, "R10F_DEPENDENCY_UNTRACKED"
            ):
                closure.audit(
                    require_tracked=True,
                    allow_unfinalized=False,
                    require_l15_sources=True,
                )

    def test_actual_cli_selects_only_the_explicit_successor(self):
        run = subprocess.run(
            [
                sys.executable,
                "-B",
                str(ROOT / "sdk/conformance/qsdk_r10f_dependency_closure.py"),
                "--require-l15-sources",
            ],
            capture_output=True,
            cwd=ROOT,
            timeout=60,
            check=False,
        )
        self.assertEqual(0, run.returncode, run.stderr.decode("utf-8"))
        text = run.stdout.decode("utf-8")
        self.assertTrue(text.startswith(closure.PASS_MARKER))
        offered = json.loads(text[len(closure.PASS_MARKER) :])
        self.assertEqual(self.receipt, offered)

    def test_every_source_omission_refuses_against_separately_discovered_population(
        self,
    ):
        expected = closure.l15_source_population()
        policy = self.manifest["policy"]
        closure.validate_l15_source_population(policy, expected=expected)
        rejected = 0
        with mock.patch.object(closure.subprocess, "run") as run:
            for field, paths in expected.items():
                for index in range(len(paths)):
                    changed = copy.deepcopy(policy)
                    changed[field] = paths[:index] + paths[index + 1 :]
                    with self.assertRaisesRegex(
                        closure.ClosureFailure, "SOURCE_POPULATION:" + field
                    ):
                        closure.validate_l15_source_population(
                            changed, expected=expected
                        )
                    rejected += 1
            run.assert_not_called()
        self.assertEqual(327, rejected)

    def test_actual_implementation_dependency_reader_preserves_the_complete_result(
        self,
    ):
        actual = implementation.audit_dependency(
            official_qualification=False, require_l15_sources=True
        )
        self.assertEqual(self.receipt, actual)
        # Mutations are copies of the actual full child result. The independent
        # source read is real; no source population is supplied by the offer.
        for key in actual:
            changed = copy.deepcopy(actual)
            del changed[key]
            offered = subprocess.CompletedProcess(
                [], 0, closure.PASS_MARKER + json.dumps(changed), ""
            )
            with mock.patch.object(
                implementation, "checked_process", return_value=offered
            ):
                with self.assertRaises(implementation.AuditFailure, msg=key):
                    implementation.audit_dependency(
                        official_qualification=False, require_l15_sources=True
                    )
        for flag in (None, 0, 1, "true"):
            with mock.patch.object(implementation, "checked_process") as run:
                with self.assertRaisesRegex(
                    implementation.AuditFailure, "DEPENDENCY_L15_MODE_KIND"
                ):
                    implementation.audit_dependency(
                        official_qualification=False, require_l15_sources=flag
                    )
                run.assert_not_called()
        offered = subprocess.CompletedProcess(
            [], 0, closure.PASS_MARKER + json.dumps(actual), ""
        )
        with mock.patch.object(
            implementation, "checked_process", return_value=offered
        ), mock.patch.object(
            closure, "audit", side_effect=closure.ClosureFailure("SOURCE_CHANGED")
        ):
            with self.assertRaisesRegex(
                implementation.AuditFailure,
                "DEPENDENCY_L15_SOURCE_REOPEN:SOURCE_CHANGED",
            ):
                implementation.audit_dependency(
                    official_qualification=False, require_l15_sources=True
                )

    def test_actual_materializer_consumes_the_complete_source_only_graph(self):
        receipt = materializer.dependency_receipt(require_l15_sources=True)
        expected = copy.deepcopy(self.receipt)
        expected["tracked_source_required"] = True
        self.assertEqual(expected, receipt)
        manifest, policy = materializer.manifest_binding(require_l15_sources=True)
        self.assertEqual(self.manifest, manifest)
        self.assertEqual(
            {
                "count": receipt["qualified_source_path_count"],
                "digest": receipt["qualified_source_path_sha256"],
            },
            policy,
        )
        legacy_manifest, legacy_policy = materializer.manifest_binding()
        self.assertEqual(json.loads(self.original), legacy_manifest)
        self.assertEqual(176, legacy_policy["count"])
        self.assertEqual(closure.MANIFEST_PATH, materializer.MANIFEST_PATH)
        self.assertTrue(materializer.STAGE_RELATIVE.endswith("_v15.json"))
        self.assertTrue(materializer.AUTHORITY_RELATIVE.endswith("_v15.json"))
        self.assertEqual("QSDK-R10F-L14", materializer.REPAIR_ID)

    def test_materializer_selector_failure_and_manifest_drift_cannot_mint_a_binding(
        self,
    ):
        for consumer in (
            materializer.dependency_receipt,
            materializer.manifest_binding,
        ):
            for mode in (None, 0, 1, "true"):
                with mock.patch.object(implementation, "audit_dependency") as read:
                    with self.assertRaisesRegex(
                        materializer.MaterializationFailure, "L15_MODE_KIND"
                    ):
                        consumer(require_l15_sources=mode)
                    read.assert_not_called()
        with mock.patch.object(
            implementation,
            "audit_dependency",
            side_effect=implementation.AuditFailure("SOURCE_CHANGED"),
        ):
            with self.assertRaisesRegex(
                materializer.MaterializationFailure,
                "L15_DEPENDENCY_RECEIPT:SOURCE_CHANGED",
            ):
                materializer.manifest_binding(require_l15_sources=True)
        # This is a complete actual child receipt with crossed retained bytes,
        # not a synthetic green shortcut. The materializer reopens real v20.
        for key, value in (
            ("manifest_raw_sha256", "sha256:" + "0" * 64),
            ("manifest_byte_length", self.receipt["manifest_byte_length"] + 1),
        ):
            changed = copy.deepcopy(self.receipt)
            changed[key] = value
            with mock.patch.object(
                materializer, "dependency_receipt", return_value=changed
            ):
                with self.assertRaisesRegex(
                    materializer.MaterializationFailure, "L15_MANIFEST_REOPEN_BINDING"
                ):
                    materializer.manifest_binding(require_l15_sources=True)


if __name__ == "__main__":
    unittest.main(verbosity=2)
