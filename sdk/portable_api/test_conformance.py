from __future__ import annotations

import json
import shutil
import tempfile
import unittest
from pathlib import Path

from portable_api.conformance import ConformanceError, audit_source_surfaces


SDK_ROOT = Path(__file__).resolve().parents[1]


class PortableApiSurfaceConformanceTests(unittest.TestCase):
    def test_current_source_matches_versioned_contract(self) -> None:
        receipt = audit_source_surfaces(SDK_ROOT)
        self.assertTrue(receipt["ok"])
        self.assertEqual(receipt["contract_symbol_count"], 83)
        self.assertEqual(receipt["rust_export_count"], 83)
        self.assertEqual(receipt["c_declaration_count"], 83)
        self.assertEqual(receipt["python_ctypes_signature_count"], 83)
        self.assertTrue(receipt["rust_c_python_exact_signature_parity"])
        self.assertEqual(receipt["world_build_count"], 0)
        self.assertEqual(receipt["solver_step_count"], 0)
        self.assertFalse(receipt["physical_acceptance_authority"])

    def _copy_fixture(self, destination: Path) -> None:
        inventory_path = (
            SDK_ROOT / "release" / "quadruped_package_source_inventory_v1.json"
        )
        inventory = json.loads(inventory_path.read_text(encoding="utf-8"))
        for relative in inventory["required_portable_api_paths"]:
            source = SDK_ROOT / relative
            target = destination / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)

    def _assert_text_mutation_rejected(
        self, relative: str, original: str, replacement: str
    ) -> None:
        with tempfile.TemporaryDirectory(prefix="sporespore-portable-api-test-") as raw:
            fixture = Path(raw)
            self._copy_fixture(fixture)
            path = fixture / relative
            text = path.read_text(encoding="utf-8")
            self.assertEqual(
                text.count(original), 1, f"mutation anchor drifted: {original}"
            )
            path.write_text(text.replace(original, replacement), encoding="utf-8")
            with self.assertRaises(ConformanceError):
                audit_source_surfaces(fixture)

    def test_missing_rust_export_is_rejected(self) -> None:
        self._assert_text_mutation_rejected(
            "core/src/ffi.rs",
            'pub extern "C" fn ss_version()',
            'pub extern "C" fn ss_version_removed()',
        )

    def test_missing_c_declaration_is_rejected(self) -> None:
        self._assert_text_mutation_rejected(
            "include/sporespore_locomotion.h",
            "const char *ss_version(void)",
            "const char *ss_version_removed(void)",
        )

    def test_missing_python_ctypes_binding_is_rejected(self) -> None:
        self._assert_text_mutation_rejected(
            "python/sporespore_locomotion.py",
            '            "ss_bound_stability_influence_v3_json",\n'
            "        ):\n"
            "            function = getattr(self._library, name)",
            '            "ss_bound_stability_influence_v3_json_removed",\n'
            "        ):\n"
            "            function = getattr(self._library, name)",
        )

    def test_rust_parameter_type_drift_is_rejected(self) -> None:
        self._assert_text_mutation_rejected(
            "core/src/ffi.rs",
            "fn ss_balanced_wave_policy_session_destroy(session_handle: u64)",
            "fn ss_balanced_wave_policy_session_destroy(session_handle: usize)",
        )

    def test_c_parameter_type_drift_is_rejected(self) -> None:
        self._assert_text_mutation_rejected(
            "include/sporespore_locomotion.h",
            "ss_balanced_wave_policy_session_destroy(\n    uint64_t session_handle);",
            "ss_balanced_wave_policy_session_destroy(\n    size_t session_handle);",
        )

    def test_python_parameter_type_drift_is_rejected(self) -> None:
        self._assert_text_mutation_rejected(
            "python/sporespore_locomotion.py",
            "self._library.ss_balanced_wave_policy_session_destroy.argtypes = [\n"
            "            ctypes.c_uint64,\n"
            "        ]",
            "self._library.ss_balanced_wave_policy_session_destroy.argtypes = [\n"
            "            ctypes.c_size_t,\n"
            "        ]",
        )

    def test_missing_cdylib_artifact_is_rejected(self) -> None:
        self._assert_text_mutation_rejected(
            "core/Cargo.toml",
            'crate-type = ["rlib", "staticlib", "cdylib"]',
            'crate-type = ["rlib", "staticlib"]',
        )

    def test_package_inventory_omission_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory(prefix="sporespore-portable-api-test-") as raw:
            fixture = Path(raw)
            self._copy_fixture(fixture)
            path = fixture / "release/quadruped_package_source_inventory_v1.json"
            inventory = json.loads(path.read_text())
            inventory["required_portable_api_paths"].remove("run_portable_api_conformance.ps1")
            path.write_text(json.dumps(inventory), encoding="utf-8")
            with self.assertRaisesRegex(ConformanceError, "public surface is not mandatory"):
                audit_source_surfaces(fixture)

    def test_clean_room_acceptance_weakening_is_rejected(self) -> None:
        self._assert_text_mutation_rejected(
            "portable_api/portable_api_contract_v2.json",
            '    "candidate_authorization_report_required": true,',
            '    "candidate_authorization_report_required": false,',
        )

    def test_duplicate_contract_symbol_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory(prefix="sporespore-portable-api-test-") as raw:
            fixture = Path(raw)
            self._copy_fixture(fixture)
            path = fixture / "portable_api" / "portable_api_contract_v2.json"
            contract = json.loads(path.read_text(encoding="utf-8"))
            contract["signature_groups"][-1]["symbols"].append("ss_version")
            path.write_text(json.dumps(contract, indent=2) + "\n", encoding="utf-8")
            with self.assertRaises(ConformanceError):
                audit_source_surfaces(fixture)


if __name__ == "__main__":
    unittest.main(verbosity=2)
