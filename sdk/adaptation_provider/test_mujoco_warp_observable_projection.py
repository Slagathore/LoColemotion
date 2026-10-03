"""Unit tests for the zero-world MuJoCo/Warp observable projector."""

from __future__ import annotations

import copy
import math
import unittest

from . import mujoco_warp_metric_semantics as mjms
from . import mujoco_warp_observable_projection as projection
from . import mujoco_warp_observable_projection_conformance as conformance


class ObservableProjectionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.raw_binding = conformance.build_fixture_binding()
        cls.binding = projection.compile_observable_binding(cls.raw_binding)
        cls.suite = conformance.build_fixture_suite(cls.binding)
        cls.cpu_native = conformance.build_native_trace(
            cls.binding, cls.suite, "cpu_reference"
        )
        cls.warp_native = conformance.build_native_trace(
            cls.binding, cls.suite, "warp_candidate"
        )

    def test_current_inventory_is_explicitly_incomplete(self) -> None:
        inventory = projection.compile_current_observable_projection_inventory()
        self.assertEqual(inventory["production_topology_binding_count"], 0)
        self.assertEqual(inventory["unresolved_topology_binding_count"], 1)
        self.assertFalse(inventory["production_native_observable_binding_complete"])
        self.assertFalse(inventory["calibration_authorized"])

    def test_binding_covers_every_native_state_and_actuator_slot(self) -> None:
        coverage = {field: [] for field in projection.NATIVE_FIELDS}
        for component in self.binding["components"]:
            coverage[component["native_field"]].extend(component["native_indices"])
        self.assertEqual(sorted(coverage["qpos"]), list(range(9)))
        self.assertEqual(sorted(coverage["qvel"]), list(range(8)))
        self.assertEqual(sorted(coverage["actuator_force"]), [0, 1])

    def test_native_projection_enters_exact_mjms_evaluator(self) -> None:
        cpu = projection.project_native_trace(self.binding, self.cpu_native)
        warp = projection.project_native_trace(self.binding, self.warp_native)
        result = mjms.evaluate_fixture_pair(
            self.suite, cpu["metric_trace"], warp["metric_trace"]
        )
        self.assertTrue(result["valid_metric_vector"])
        self.assertEqual(set(result["metrics"]), set(mjms.REQUIRED_METRICS))
        self.assertEqual(result["metrics"]["contact_event_time_error_steps"], 1)
        self.assertTrue(math.isfinite(result["metrics"]["one_step_state_linf_normalized"]))

    def test_warp_contacts_are_filtered_to_bound_world(self) -> None:
        projected = projection.project_native_trace(self.binding, self.warp_native)
        events = projected["metric_trace"]["contact_events"]
        self.assertEqual(len(events), 4)
        self.assertNotIn(0, [event["step_index"] for event in events])
        self.assertEqual(
            {event["body_pair_id"] for event in events},
            {"front_left_foot__ground", "front_right_foot__ground"},
        )

    def test_capacity_overflow_is_retained_instead_of_rejected_or_scored(self) -> None:
        native = copy.deepcopy(self.cpu_native)
        native["snapshots"][1]["contacts"]["overflow"] = True
        projected = projection.project_native_trace(self.binding, native)
        self.assertFalse(projected["metric_trace_eligible"])
        self.assertEqual(projected["metric_trace"]["exact_failure_count"], 1)
        self.assertEqual(
            projected["failure_records"],
            [{"step_index": 1, "failure_code": "contact_capacity_overflow"}],
        )

    def test_wrong_capture_point_fails_closed(self) -> None:
        native = copy.deepcopy(self.cpu_native)
        native["snapshots"][1]["capture_point"] = "after_mj_forward"
        with self.assertRaisesRegex(
            projection.ObservableProjectionError, "MJOP_SNAPSHOT_CAPTURE_POINT"
        ):
            projection.project_native_trace(self.binding, native)

    def test_nonfinite_energy_fails_closed(self) -> None:
        native = copy.deepcopy(self.cpu_native)
        native["snapshots"][1]["arrays"]["energy"][0] = float("nan")
        with self.assertRaisesRegex(
            projection.ObservableProjectionError, "MJOP_SNAPSHOT_ARRAY_SHAPE"
        ):
            projection.project_native_trace(self.binding, native)

    def test_production_authority_injection_fails_closed(self) -> None:
        binding = copy.deepcopy(self.raw_binding)
        binding["production_binding"] = True
        with self.assertRaisesRegex(
            projection.ObservableProjectionError, "MJOP_BINDING_AUTHORITY"
        ):
            projection.compile_observable_binding(binding)

    def test_complete_conformance_matrix(self) -> None:
        report = conformance.run_conformance()
        self.assertTrue(report["ok"])
        self.assertEqual(report["passed_cells"], 8)
        self.assertEqual(report["failed_cells"], 0)
        self.assertEqual(report["control_count"], 48)
        self.assertEqual(report["rejected_mutation_count"], 24)
        self.assertEqual(report["model_construction_count"], 0)
        self.assertEqual(report["world_build_count"], 0)
        self.assertFalse(report["release_authority"])


if __name__ == "__main__":
    unittest.main()
