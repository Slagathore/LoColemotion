"""Expected collection identity is captured before any observation packet exists."""

from pathlib import Path
import sys
import unittest

from test_qsdk_r10f_l15_collection_transport import run_zero_world_fixture, verify_bytes

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "sdk/conformance"))
import qsdk_r10f_l15_collection_retention as reader
import qsdk_r10f_physical_closure as closer


class PreparedCollectionContext(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.receipt = run_zero_world_fixture(
            "res://tests/test_sdk_qsdk_r10f_l15_collection_context_zero_world.gd",
            "QSDK_R10F_L15_COLLECTION_CONTEXT_ZERO_WORLD ",
        )

    def test_exact_prepared_context_and_constructor_identity_without_a_packet(self):
        receipt = self.receipt
        self.assertEqual(27, receipt["control_count"])
        self.assertEqual([], receipt["failed_controls"])
        self.assertTrue(all(value is True for value in receipt["controls"].values()))
        capture = receipt["capture"]
        context = reader.parse_json(
            verify_bytes(capture["source_context"]).decode("utf-8")
        )
        identity = reader.parse_json(
            verify_bytes(capture["expected_identity"]).decode("utf-8")
        )
        self.assertEqual(reader.IDENTITY_KEYS, identity.keys())
        self.assertTrue(
            reader.same(context["morphology_context"], identity["morphology_context"])
        )
        self.assertTrue(
            reader.same(context["capability"], identity["adapter_capability"])
        )
        self.assertTrue(
            reader.same(context["runtime_binding"], identity["runtime_binding"])
        )
        self.assertEqual("candidate_command", identity["arm_kind"])
        self.assertEqual(
            "qsdk_r05_generated_s169", identity["descriptor"]["morphology_id"]
        )
        self.assertEqual(
            closer.canonical_sha256_v1(identity["adapter_capability"]),
            identity["runtime_binding"]["capability_sha256"],
        )
        self.assertEqual(
            closer.canonical_sha256_v1(identity["descriptor"]),
            identity["morphology_context"]["base_descriptor_sha256"],
        )

    def test_capture_is_not_world_execution_or_official_context_qualification(self):
        receipt = self.receipt
        self.assertEqual(1, receipt["production_v18_context_preparation_call_count"])
        for value in (receipt, receipt["capture"]):
            for key in (
                "compiled_collection_call_count",
                "portable_recovery_advance_call_count",
                "model_construction_count",
                "world_attempt_count",
                "world_build_count",
                "scene_tree_insertion_count",
                "native_physics_read_count",
                "solver_step_count",
            ):
                self.assertIs(type(value[key]), int)
                self.assertEqual(0, value[key])
            for key in (
                "physical_execution_authorized",
                "physical_acceptance_authority",
                "release_authority",
            ):
                self.assertIs(value[key], False)
        self.assertIs(receipt["physical_worker_instance_created"], False)
        capture = receipt["capture"]
        self.assertIs(capture["official_context_qualification"], False)
        self.assertIs(capture["physical_worker_context_installed"], False)
        self.assertIs(capture["source_is_prepared_context_not_observation"], True)
        self.assertEqual(1, capture["collection_request_constructor_call_count"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
