from __future__ import annotations

import copy
import ctypes
import tempfile
import unittest
import warnings
from pathlib import Path

try:
    from sporespore_locomotion import LocomotionCore
except ImportError:
    from python.sporespore_locomotion import LocomotionCore

from adapter_kit.reference_adapter import ReferenceHostAdapter

from .conformance import (
    ABI_MANIFEST_PATH,
    DEPRECATION_REGISTRY_PATH,
    VersioningConformanceError,
    _load_abi_manifest,
    _load_deprecations,
    _retain_report,
    run_versioning_conformance,
)
from .migrations import (
    LEGACY_BALANCED_WAVE_POLICY_ID,
    SchemaMigrationError,
    migrate_record,
)


class VersioningConformanceTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.core = LocomotionCore()

    @staticmethod
    def _legacy_request(adapter: ReferenceHostAdapter) -> dict:
        request = adapter.build_step_request(0)
        request["schema_version"] = "sporespore_balanced_wave_step_request_v1"
        return request

    def test_complete_v0_v6_report(self) -> None:
        report = run_versioning_conformance()
        self.assertTrue(report["ok"])
        self.assertEqual(report["sdk_version"], "0.1.0")
        self.assertEqual(report["abi_generation"], 1)
        self.assertEqual(report["passed_cells"], 7)
        self.assertEqual(report["failed_cells"], 0)
        self.assertEqual(
            [cell["cell_id"] for cell in report["cells"]],
            [
                "v0_compatibility_policy",
                "v1_version_lockstep",
                "v2_c_abi_manifest",
                "v3_schema_registry",
                "v4_semantic_migration",
                "v5_deprecation_registry",
                "v6_negative_paths",
            ],
        )
        self.assertEqual(report["world_build_count"], 0)
        self.assertFalse(report["release_ready"])
        self.assertFalse(report["publication_authorized"])
        self.assertFalse(report["physical_acceptance_authority"])
        self.assertFalse(report["completed_engine_neutral_sdk"])

    def test_legacy_step_migration_is_semantics_preserving(self) -> None:
        adapter = ReferenceHostAdapter(self.core)
        legacy_request = self._legacy_request(adapter)
        legacy_output = self.core.balanced_wave_step(legacy_request)
        receipt = migrate_record(
            legacy_request,
            "sporespore_balanced_wave_policy_step_request_v1",
            core=self.core,
        )
        migrated = receipt["migrated_record"]
        named_output = self.core.balanced_wave_policy_step(
            migrated["policy_id"],
            migrated,
        )
        self.assertEqual(
            migrated["policy_id"],
            LEGACY_BALANCED_WAVE_POLICY_ID,
        )
        self.assertEqual(legacy_output, named_output)
        self.assertEqual(
            receipt["migration_path"],
            ["balanced_wave_legacy_step_to_named_policy_v1"],
        )
        self.assertFalse(receipt["implicit_coercion_used"])
        self.assertEqual(receipt["world_build_count"], 0)

    def test_unregistered_or_malformed_migration_fails_closed(self) -> None:
        adapter = ReferenceHostAdapter(self.core)
        legacy_request = self._legacy_request(adapter)
        with self.assertRaises(SchemaMigrationError) as unavailable:
            migrate_record(
                legacy_request,
                "sporespore_unknown_schema_v1",
                core=self.core,
            )
        self.assertEqual(
            unavailable.exception.failure_code,
            "MIGRATION_TARGET_SCHEMA_UNKNOWN",
        )

        malformed = copy.deepcopy(legacy_request)
        malformed["unknown"] = True
        with self.assertRaises(SchemaMigrationError) as invalid:
            migrate_record(
                malformed,
                "sporespore_balanced_wave_policy_step_request_v1",
                core=self.core,
            )
        self.assertEqual(
            invalid.exception.failure_code,
            "MIGRATION_SOURCE_FIELDS_INVALID",
        )
        with self.assertRaises(SchemaMigrationError) as identity:
            migrate_record(
                legacy_request,
                "sporespore_balanced_wave_step_request_v1",
                core=self.core,
            )
        self.assertEqual(
            identity.exception.failure_code,
            "MIGRATION_NOT_REQUIRED",
        )

    def test_manifest_symbols_resolve_from_real_library(self) -> None:
        manifest = _load_abi_manifest()
        self.assertTrue(ABI_MANIFEST_PATH.is_file())
        library = ctypes.CDLL(str(self.core.library_path))
        manifest_symbols = {entry["name"] for entry in manifest["symbols"]}
        unresolved = [
            entry["name"]
            for entry in manifest["symbols"]
            if not hasattr(library, entry["name"])
        ]
        self.assertEqual(unresolved, [])
        self.assertEqual(len(manifest_symbols), 58)
        self.assertTrue(
            {
                "ss_balanced_wave_policy_initial_memory_json",
                "ss_balanced_wave_policy_session_create_json",
                "ss_balanced_wave_policy_session_step_json",
                "ss_balanced_wave_policy_session_destroy",
                "ss_resolve_adaptation_v1_json",
                "ss_compile_recovery_morphology_v1_json",
                "ss_resolve_actuator_cap_profile_v1_json",
                "ss_recovery_initialize_v1_json",
                "ss_recovery_initialize_v2_json",
                "ss_recovery_step_v1_json",
                "ss_recovery_step_v2_json",
                "ss_recovery_step_v3_json",
                "ss_recovery_step_v4_json",
                "ss_recovery_step_v5_json",
                "ss_recovery_evaluate_trace_v1_json",
                "ss_recovery_evaluate_trace_v2_json",
                "ss_recovery_evaluate_trace_v3_json",
                "ss_recovery_evaluate_trace_v4_json",
                "ss_recovery_evaluate_trace_v5_json",
                "ss_recovery_energy_balance_aggregate_v2_json",
                "ss_recovery_energy_balance_evaluate_v2_json",
                "ss_recovery_energy_balance_aggregate_v3_json",
                "ss_recovery_energy_balance_evaluate_v3_json",
                "ss_recovery_energy_balance_migrate_v1_json",
                "ss_recovery_development_profile_v1_json",
                "ss_recovery_collect_native_v1_json",
                "ss_recovery_collect_native_v2_json",
                "ss_recovery_collect_native_v3_json",
                "ss_recovery_plan_control_v1_json",
                "ss_recovery_plan_control_v2_json",
                "ss_recovery_plan_control_v3_json",
                "ss_recovery_plan_stance_control_v1_json",
                "ss_recovery_plan_stance_control_v2_json",
                "ss_recovery_plan_stance_control_v3_json",
                "ss_recovery_plan_stance_control_v4_json",
            }.issubset(manifest_symbols)
        )

    def test_deprecations_have_active_replacements_and_notice(self) -> None:
        manifest = _load_abi_manifest()
        registry = _load_deprecations()
        self.assertTrue(DEPRECATION_REGISTRY_PATH.is_file())
        active = {
            entry["name"]
            for entry in manifest["symbols"]
            if entry["status"] == "active"
        }
        deprecated = {
            entry["name"]
            for entry in manifest["symbols"]
            if entry["status"] == "deprecated"
        }
        registry_symbols = {
            entry["surface_id"]
            for entry in registry["items"]
            if entry["surface_kind"] == "c_abi_symbol"
        }
        self.assertEqual(deprecated, registry_symbols)
        for entry in registry["items"]:
            surface_kind = entry["surface_kind"]
            if surface_kind == "c_abi_symbol":
                self.assertIn(entry["replacement"], active)
            elif surface_kind == "python_method":
                self.assertTrue(hasattr(LocomotionCore, entry["surface_id"]))
                self.assertTrue(hasattr(LocomotionCore, entry["replacement"]))
            self.assertGreaterEqual(
                tuple(
                    int(part) for part in entry["not_before_removal_version"].split(".")
                ),
                (0, 3, 0),
            )
        adapter = ReferenceHostAdapter(self.core)
        with warnings.catch_warnings(record=True) as caught:
            warnings.simplefilter("always", DeprecationWarning)
            self.core.balanced_wave_profile(adapter.descriptor)
        self.assertEqual(len(caught), 1)
        self.assertIs(caught[0].category, DeprecationWarning)
        self.assertIn(
            "balanced_wave_policy_profile",
            str(caught[0].message),
        )

    def test_report_retention_is_atomic_and_immutable(self) -> None:
        report = run_versioning_conformance()
        with tempfile.TemporaryDirectory(prefix="sporespore_versioning_") as temporary:
            report_path = Path(temporary) / "report.json"
            _retain_report(report, report_path)
            self.assertTrue(report_path.is_file())
            self.assertFalse(report_path.with_name("report.json.tmp").exists())
            with self.assertRaises(VersioningConformanceError):
                _retain_report(report, report_path)
            with self.assertRaises(VersioningConformanceError):
                _retain_report(
                    report,
                    Path(temporary) / "renamed.json",
                )


if __name__ == "__main__":
    unittest.main()
