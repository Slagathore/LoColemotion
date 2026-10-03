"""Actual recovery route retention, without physical worker/abort qualification."""

import json
import unittest

from test_qsdk_r10f_l15_collection_transport import run_zero_world_fixture, verify_bytes


class RouteRetention(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.receipt = run_zero_world_fixture(
            "res://tests/test_sdk_qsdk_r10f_l15_route_retention_zero_world.gd",
            "QSDK_R10F_L15_ROUTE_RETENTION_ZERO_WORLD ",
        )

    def test_actual_route_and_dispatcher_preserve_exact_single_call(self):
        receipt = self.receipt
        self.assertEqual(49, receipt["control_count"])
        self.assertEqual([], receipt["failed_controls"])
        self.assertTrue(all(value is True for value in receipt["controls"].values()))
        self.assertEqual(5, receipt["genuine_compiled_collection_call_count"])
        self.assertEqual(3, receipt["compiled_portable_step_call_count"])
        self.assertEqual(2, receipt["compiled_control_planning_call_count"])
        self.assertEqual(1, receipt["malformed_reply_stub_call_count"])
        self.assertEqual(0, receipt["additional_failure_reconstruction_call_count"])
        for label, case in receipt["cases"].items():
            if label == "legacy_success":
                self.assertNotIn("collection_transport_retention", case)
                continue
            packet = case["collection_transport_retention"]
            sources = {
                role: json.loads(verify_bytes(binding))
                for role, binding in packet["source_links"].items()
            }
            if label.startswith("precollection_"):
                self.assertIs(case["ok"], False)
                self.assertIsNone(packet["request"])
                self.assertIsNone(packet["response"])
                self.assertIsNone(packet["decoded_collection"])
                self.assertEqual(0, packet["compiled_collection_call_count"])
            else:
                request = json.loads(verify_bytes(packet["request"]))
                verify_bytes(packet["response"])
                self.assertEqual(1, packet["compiled_collection_call_count"])
                self.assertEqual(1, packet["request_serialization_call_count"])
                self.assertEqual(1, packet["response_json_parse_call_count"])
                self.assertEqual(
                    request["observation"],
                    sources["bound_observation"]["observation_v2"],
                )
                self.assertEqual(
                    request["observation_source_binding"],
                    sources["bound_observation"]["source_binding"],
                )

    def test_post_collection_failure_and_zero_world_limits(self):
        case = self.receipt["cases"]["native_portable_step_refusal"]
        self.assertIs(case["ok"], False)
        self.assertEqual(
            "QSDK_R24D65_BEHAVIOR_PORTABLE_STEP_REFUSED", case["failure_code"]
        )
        native = json.loads(
            verify_bytes(case["collection_transport_retention"]["response"])
        )
        self.assertIs(native["ok"], True)
        self.assertEqual("supported_exact", native["value"]["support_status"])
        for key in (
            "model_construction_count",
            "world_attempt_count",
            "world_build_count",
            "scene_tree_insertion_count",
            "native_physics_read_count",
            "solver_step_count",
        ):
            self.assertEqual(0, self.receipt[key], key)
        for key in (
            "worker_abort_envelope_retention_qualified",
            "physical_execution_authorized",
            "physical_acceptance_authority",
            "release_authority",
        ):
            self.assertIs(self.receipt[key], False, key)


if __name__ == "__main__":
    unittest.main(verbosity=2)
