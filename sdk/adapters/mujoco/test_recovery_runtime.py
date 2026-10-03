from __future__ import annotations

from pathlib import Path
import sys
import unittest


ADAPTER_ROOT = Path(__file__).resolve().parent
SDK_ROOT = ADAPTER_ROOT.parents[1]
SDK_PYTHON = SDK_ROOT / "python"
for path in (ADAPTER_ROOT, SDK_PYTHON):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from sporespore_locomotion import LocomotionCore  # noqa: E402
from sporespore_mujoco_adapter.recovery_runtime import (  # noqa: E402
    COLLECTOR_ID,
    COLLECTION_REQUEST_SCHEMA,
    COLLECTION_REQUEST_V2_SCHEMA,
    RUNTIME_PROFILE_ID,
    RecoveryRuntimeError,
    collection_request_v1,
    collection_request_v2,
    recovery_development_profile_v1,
    runtime_binding_v1,
    zero_world_surface_receipt_v1,
)


CORE_LIBRARY = SDK_ROOT / "target" / "debug" / "sporespore_locomotion_core.dll"
SHA_A = "sha256:" + ("a" * 64)
SHA_B = "sha256:" + ("b" * 64)


class MuJoCoRecoveryRuntimeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.core = LocomotionCore(CORE_LIBRARY)

    def test_profile_and_binding_cross_real_core_without_mujoco(self) -> None:
        self.assertNotIn("mujoco", sys.modules)
        profile = recovery_development_profile_v1(self.core)
        binding = runtime_binding_v1(SHA_A, SHA_B)
        report = zero_world_surface_receipt_v1(self.core)

        self.assertEqual(len(profile["development_cohort"]), 3)
        self.assertEqual(len(profile["held_out_native_cohort"]), 9)
        self.assertEqual(binding["collector_id"], COLLECTOR_ID)
        self.assertEqual(binding["runtime_profile_id"], RUNTIME_PROFILE_ID)
        self.assertTrue(report["ok"])
        self.assertEqual(report["mujoco_import_count"], 0)
        self.assertEqual(report["world_build_count"], 0)
        self.assertEqual(report["solver_step_count"], 0)
        self.assertFalse(report["prone_to_standing_claimed"])
        self.assertNotIn("mujoco", sys.modules)

    def test_binding_rejects_malformed_digest(self) -> None:
        with self.assertRaises(RecoveryRuntimeError):
            runtime_binding_v1("not-a-digest", SHA_B)

    def test_v2_collection_is_additive_and_legacy_request_shape_is_unchanged(self) -> None:
        observation = {
            "engine_step_identity": {
                "engine": "mujoco_native",
                "source_kind": "native_post_step",
                "native_solver_substep_count": 5,
            }
        }
        descriptor = {"schema_version": "fixture_descriptor"}
        legacy = collection_request_v1(
            descriptor=descriptor,
            observation=observation,
            capability_sha256=SHA_A,
            runtime_qualification_sha256=SHA_B,
            arm_kind="candidate_command",
            phase="confirm_prone",
        )
        self.assertEqual(legacy["schema_version"], COLLECTION_REQUEST_SCHEMA)
        self.assertNotIn("morphology_context", legacy)

        context = {
            "schema_version": "sporespore_recovery_morphology_context_v1",
            "fixture": ["deep", "copy"],
        }
        request_v2 = collection_request_v2(
            descriptor=descriptor,
            morphology_context=context,
            observation=observation,
            capability_sha256=SHA_A,
            runtime_qualification_sha256=SHA_B,
            arm_kind="candidate_command",
            phase="confirm_prone",
        )
        self.assertEqual(request_v2["schema_version"], COLLECTION_REQUEST_V2_SCHEMA)
        self.assertEqual(request_v2["morphology_context"], context)
        context["fixture"].append("mutated")
        self.assertEqual(request_v2["morphology_context"]["fixture"], ["deep", "copy"])
        legacy_without_schema = {key: value for key, value in legacy.items() if key != "schema_version"}
        v2_without_context = {
            key: value
            for key, value in request_v2.items()
            if key not in {"schema_version", "morphology_context"}
        }
        self.assertEqual(v2_without_context, legacy_without_schema)


if __name__ == "__main__":
    unittest.main()
