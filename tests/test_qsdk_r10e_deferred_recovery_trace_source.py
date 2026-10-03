from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]
OBSERVER_PATH = ROOT / "sdk/adapters/godot/gdscript/deferred_recovery_trace_v1.gd"
SCALAR_VALIDATOR_PATH = (
    ROOT
    / "sdk/adapters/godot/gdscript/qsdk_r10e_native_impulse_scalar_receipt_validation_v2.gd"
)
HISTORICAL_SCALAR_VALIDATOR_PATH = (
    ROOT
    / "sdk/adapters/godot/gdscript/qsdk_r10e_native_impulse_scalar_receipt_validation_v1.gd"
)
WALKER_PATH = ROOT / "scripts/lab/gait/physical_wave_gait_quadruped.gd"
RECOVERY_PATH = (
    ROOT / "scripts/lab/gait/qsdk_r10e_observer_minimized_upright_push_recovery.gd"
)
ZERO_WORLD_TEST_PATH = (
    ROOT / "tests/test_sdk_qsdk_r10e_deferred_recovery_trace_zero_world.gd"
)


def _function(source: str, name: str) -> str:
    match = re.search(
        rf"(?ms)^static func {re.escape(name)}\(.*?(?=^static func |\Z)",
        source,
    )
    if match is None:
        raise AssertionError(f"missing static function: {name}")
    return match.group(0)


class DeferredRecoveryTraceSourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.observer = OBSERVER_PATH.read_text(encoding="utf-8")
        cls.scalar_validator = SCALAR_VALIDATOR_PATH.read_text(encoding="utf-8")
        cls.historical_scalar_validator = HISTORICAL_SCALAR_VALIDATOR_PATH.read_text(
            encoding="utf-8"
        )
        cls.walker = WALKER_PATH.read_text(encoding="utf-8")
        cls.recovery = RECOVERY_PATH.read_text(encoding="utf-8")
        cls.zero_world_test = ZERO_WORLD_TEST_PATH.read_text(encoding="utf-8")

    def test_live_capture_functions_contain_no_rich_materialization(self) -> None:
        live_source = "\n".join(
            [
                _function(self.observer, "capture_before_solver_step"),
                _function(self.observer, "capture_after_solver_step"),
            ]
        )
        for forbidden in (
            ".duplicate(",
            "CanonicalJson",
            "JSON.",
            "sha256",
            "project_quaternion",
            "orientation_projection",
            '"row":',
            "rows.append",
        ):
            self.assertNotIn(forbidden, live_source)

        self.assertNotRegex(live_source, r"(?m)^\s*return\s*\{")
        self.assertIn("PackedInt32Array", self.observer)
        self.assertIn("PackedFloat64Array", self.observer)
        self.assertIn("PackedByteArray", self.observer)
        self.assertIn("func _prepared_buffer() -> Variant:", self.zero_world_test)
        self.assertEqual(
            self.zero_world_test.count(": Variant = _prepared_buffer()"), 7
        )

    def test_all_rich_work_is_in_the_post_solver_materializer(self) -> None:
        materializer = _function(self.observer, "materialize_after_final_solver_step")
        self.assertIn("var rows: Array[Dictionary] = []", materializer)
        self.assertIn("rows.resize(buffer.captured_row_count)", materializer)
        self.assertIn("project_quaternion_to_unit_scalar_v1", materializer)
        self.assertIn('"torso_orientation_projection"', materializer)
        self.assertIn("post_solver_materialized_row_count += 1", materializer)
        self.assertIn("post_solver_projection_receipt_count += 1", materializer)
        self.assertIn(
            "expected_sdk_step_count != buffer.captured_row_count", materializer
        )

    def test_observer_receipt_exposes_every_required_counter(self) -> None:
        receipt = _function(self.observer, "_instrumentation_receipt")
        required_fields = (
            "capture_buffer_preallocated",
            "capture_buffer_capacity",
            "captured_row_count",
            "live_nested_row_materialization_count",
            "live_trace_row_deep_duplicate_count",
            "live_trace_json_or_hash_count",
            "live_quaternion_projection_receipt_count",
            "post_solver_materialized_row_count",
            "post_solver_projection_receipt_count",
            "additional_solver_step_during_materialization_count",
            "downsampled_row_count",
            "missing_measurement_count",
            "physics_state_modified",
        )
        for field in required_fields:
            self.assertIn(f'"{field}"', receipt)

    def test_walker_orders_capture_around_physics_and_materializes_after_loop(
        self,
    ) -> None:
        before_call = self.walker.index(
            "DeferredRecoveryTraceScript.capture_before_solver_step"
        )
        physics_frame = self.walker.index("await tree.physics_frame", before_call)
        after_call = self.walker.index(
            "DeferredRecoveryTraceScript.capture_after_solver_step", physics_frame
        )
        loop_terminal = self.walker.index(
            "if not authority_horizon_enabled and run_end_tick >= 0 and tick + 1 >= run_end_tick:",
            after_call,
        )
        materialize_call = self.walker.index(
            "DeferredRecoveryTraceScript.materialize_after_final_solver_step",
            loop_terminal,
        )
        self.assertLess(before_call, physics_frame)
        self.assertLess(physics_frame, after_call)
        self.assertLess(after_call, loop_terminal)
        self.assertLess(loop_terminal, materialize_call)

    def test_walker_keeps_historical_trace_path_separate(self) -> None:
        self.assertIn(
            "if sdk_physical_trace_enabled and not sdk_deferred_recovery_trace_enabled:",
            self.walker,
        )
        self.assertIn(
            "if sdk_deferred_recovery_trace_step_pending:",
            self.walker,
        )
        self.assertIn(
            'String(sdk_physical_trace_options.get("policy_id", ""))\n'
            "\t\t\t== QSDK_R10E_RECOVERY_TRACE_POLICY_ID",
            self.walker,
        )

    def test_tilt_and_torso_contact_measurements_are_shared(self) -> None:
        capture_region_start = self.walker.index(
            "var torso_tilt_rad := _tilt_rad(torso)"
        )
        capture_region_end = self.walker.index(
            "for limb_value in limbs:", capture_region_start
        )
        region = self.walker[capture_region_start:capture_region_end]
        self.assertEqual(region.count("_tilt_rad(torso)"), 1)
        self.assertEqual(region.count('_body_bears_floor(torso, "torso", floor)'), 1)
        self.assertEqual(region.count("_bearing_contact_by_limb(limbs, floor)"), 1)
        self.assertIn("torso_tilt_rad,", region)
        self.assertIn("torso_ground_contact,", region)

    def test_r10e_policy_and_scalar_receipt_are_forward_versioned(self) -> None:
        required_tokens = (
            "QSDK_R10E_RECOVERY_TRACE_POLICY_ID",
            "QSDK_R10E_RECOVERY_TRACE_ROW_SCHEMA",
            "QSDK_R10E_MINIMUM_CONTROLLER_STEP_COUNT",
            "QSDK_R10E_MAXIMUM_CONTROLLER_STEP_COUNT",
            "QSDK_R10E_PUSH_MARKER_SEMANTIC_STEP",
            "sporespore_qsdk_r10e_native_impulse_application_receipt_v1",
            "initial_task_frame_forward_axis_world_host_real",
            "initial_task_frame_lateral_axis_world_host_real",
            "impulse_composition_numeric_precision",
            "godot_real_t_binary32",
            "observer_instrumentation_receipt",
        )
        for token in required_tokens:
            self.assertIn(token, self.walker)

    def test_no_physical_execution_surface_exists_in_observer_module(self) -> None:
        for forbidden in (
            "RigidBody3D",
            "PhysicsServer3D",
            "physics_frame",
            "apply_central_impulse",
            "add_child",
            "PackedScene",
        ):
            self.assertNotIn(forbidden, self.observer)

    def test_scalar_validator_limits_host_real_replay_to_redundant_magnitude(
        self,
    ) -> None:
        validator = _function(self.scalar_validator, "validate_push_receipt")
        self.assertEqual(validator.count("Vector3("), 1)
        self.assertNotIn("PackedFloat32Array", self.scalar_validator)
        self.assertIn(
            "32 * 2^-52 * max(1.0, abs(actual), abs(recomputed_expected))",
            self.scalar_validator,
        )
        self.assertIn("16 * 2^-23", self.scalar_validator)
        self.assertIn("16 * 2^-23 * 0.25", self.scalar_validator)
        self.assertIn(
            "observed_r10d_outcome_used_to_select_allowances", self.scalar_validator
        )
        self.assertIn(
            '"observed_delta_host_real_vector_construction_count": 1',
            self.scalar_validator,
        )
        self.assertIn(
            '"axis_and_impulse_links_remain_scalar_only": true', self.scalar_validator
        )
        self.assertIn(
            '"observed_l2_outcome_used_to_select_allowance": false',
            self.scalar_validator,
        )
        self.assertIn("binary64_transport_only", self.scalar_validator)
        self.assertIn("behavior_threshold_changed", self.scalar_validator)

    def test_consumed_l2_scalar_validator_is_immutable(self) -> None:
        historical_bytes = HISTORICAL_SCALAR_VALIDATOR_PATH.read_bytes()
        self.assertEqual(len(historical_bytes), 12079)
        self.assertEqual(
            "sha256:" + hashlib.sha256(historical_bytes).hexdigest(),
            "sha256:d8fc31b59d2d1e4d4cd77e9a8a1abc134a903a7cac2df3d4865dbd1f072e546a",
        )
        self.assertNotIn("Vector3(", self.historical_scalar_validator)
        self.assertIn(
            "const OBSERVED_DELTA_MAGNITUDE_LINK_ALLOWANCE_M_S := 1.0e-9",
            self.historical_scalar_validator,
        )

    def test_r10e_evaluator_preserves_behavior_thresholds(self) -> None:
        expected_tokens = (
            "const MINIMUM_SDK_STEP_COUNT := 2152",
            "const MAXIMUM_SDK_STEP_COUNT := 2872",
            "const PUSH_MARKER_STEP := 900",
            "const PRE_WINDOW_START := 180",
            "const PRE_WINDOW_END_EXCLUSIVE := 900",
            "const BASELINE_WINDOW_START := 901",
            "const BASELINE_WINDOW_END_EXCLUSIVE := 1621",
            "const FIRST_RECOVERY_START := 901",
            "const LAST_RECOVERY_START := 1260",
            "const WINDOW_STEP_COUNT := 720",
            "const MAXIMUM_TORSO_TILT_RAD := 0.60",
            "const MINIMUM_TORSO_HEIGHT_M := 0.25",
            "const MINIMUM_AIRBORNE_DWELL_STEPS := 3",
            "const MINIMUM_FORWARD_ADVANCE_M := 0.02",
            "const MINIMUM_NATIVE_EFFECT_M_S := 1.0e-4",
        )
        for token in expected_tokens:
            self.assertIn(token, self.recovery)

    def test_r10e_evaluator_requires_instrumentation_and_scalar_receipt(self) -> None:
        self.assertIn("_validate_observer_instrumentation", self.recovery)
        self.assertIn("OBSERVER_INSTRUMENTATION_KEYS", self.recovery)
        self.assertIn("ScalarImpulseValidationScript", self.recovery)
        self.assertIn("validate_push_receipt(", self.recovery)
        self.assertIn("TRACE_ROW_KEYS", self.recovery)
        self.assertIn("_has_exact_keys(row, TRACE_ROW_KEYS)", self.recovery)

    def test_generator_225_identity_is_exact_and_unopened_for_r10(self) -> None:
        expected_tokens = (
            "const GENERATOR_INDEX := 225",
            'const MORPHOLOGY_ID := "qsdk_r05e_axis_star_foot_radius_low_s225"',
            '"foot_radius_scale": 0.99375',
            "sha256:11c04da70cf613bc5b40a38568de3e45e3658a3f1cf46bfa35cac23ab2713686",
            "sha256:491074191576f8f784e9cb305321c6fee32e46cf83692c796b6ed3d5467660cd",
            "sha256:805dc1d69617414a81cdad74f5cf7c6eaf44f0765a3d53c19f8af3f8324f569d",
            "sha256:e02fa9c7599cffe8b331f7d8c10b6cc4dbffe7408e319169c09cbcb7d9b3890e",
            "sha256:b9f59849bb6b22c8837f9c2784345899b95a14b1aa058df53df480da9f7a4a68",
            "const DEVELOPMENT_GHOST_SEEDS := [40002]",
            "const HELD_OUT_SEEDS := [40101, 40102, 40103]",
        )
        for token in expected_tokens:
            self.assertIn(token, self.recovery)

    def test_design_and_generation_receipts_are_content_bound(self) -> None:
        design_path = (
            ROOT
            / "sdk/qsdk_r10e_observer_minimized_upright_push_recovery_successor_design_v1.json"
        )
        self.assertEqual(
            hashlib.sha256(design_path.read_bytes()).hexdigest(),
            "791dbf01b8720ca0851b5ec4f722ff421baeb9ca277399974db6338aec03e81a",
        )
        generation_receipt = {
            "schema_version": "sporespore_qsdk_r10e_supported_start_generation_receipt_v1",
            "generator_policy_id": "qsdk_r10e_r05e_unopened_supported_start_v1",
            "source_gate_id": "QSDK-R05E",
            "source_generator_policy_id": "qsdk_r05e_exact_finite_axis_star_v1",
            "source_generator_receipt_sha256": "sha256:11c04da70cf613bc5b40a38568de3e45e3658a3f1cf46bfa35cac23ab2713686",
            "source_proportion_spec_sha256": "sha256:491074191576f8f784e9cb305321c6fee32e46cf83692c796b6ed3d5467660cd",
            "generator_index": 225,
            "morphology_id": "qsdk_r05e_axis_star_foot_radius_low_s225",
            "proportion_spec_sha256": "sha256:491074191576f8f784e9cb305321c6fee32e46cf83692c796b6ed3d5467660cd",
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physical_acceptance_authority": False,
        }
        encoded = json.dumps(
            generation_receipt,
            sort_keys=True,
            separators=(",", ":"),
            ensure_ascii=False,
        ).encode("utf-8")
        self.assertEqual(
            "sha256:" + hashlib.sha256(encoded).hexdigest(),
            "sha256:4aef2888d84b80bf7c0ccba1c6dd1854567ca28d6536a2e2335d49ba1b2247a2",
        )

    def test_instrumentation_producer_and_consumer_key_sets_match(self) -> None:
        declared_match = re.search(
            r"(?ms)^const OBSERVER_INSTRUMENTATION_KEYS := \[(.*?)^\]",
            self.recovery,
        )
        self.assertIsNotNone(declared_match)
        declared = set(re.findall(r'"([a-z0-9_]+)"', declared_match.group(1)))
        receipt_source = _function(self.observer, "_instrumentation_receipt")
        produced = set(re.findall(r'^\s*"([a-z0-9_]+)"\s*:', receipt_source, re.M))
        self.assertEqual(declared, produced)


if __name__ == "__main__":
    unittest.main()
