from __future__ import annotations

import copy
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock


HERE = Path(__file__).resolve().parent
SDK_ROOT = HERE.parents[1]
for path in (HERE, SDK_ROOT / "python", SDK_ROOT / "turning"):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from sporespore_mujoco_adapter import (  # noqa: E402
    qsdk_r23d73_positive_turn_development as route,
)


class R23D73PositiveTurnDevelopmentTests(unittest.TestCase):
    def setUp(self) -> None:
        for name in (
            route.FREEZE_PATH_ENV,
            route.ATTEMPT_PATH_ENV,
            route.TOKEN_ENV,
            route.STAGE_ENV,
            route.CELL_ENV,
            route.ENGINE_ENV,
            route.ATTEMPT_ROOT_ENV,
            route.AUTHORITY_REPO_ROOT_ENV,
        ):
            os.environ.pop(name, None)

    def test_zero_world_preflight_is_bounded_and_complete(self) -> None:
        receipt = route.run_preflight()

        self.assertTrue(receipt["ok"])
        self.assertEqual(receipt["question_class"], "development")
        self.assertTrue(receipt["outcome_exposed_fixture"])
        self.assertEqual(receipt["fixed_controller_horizon_step_count"], 2_992)
        self.assertEqual(
            receipt["segment_counts"],
            {
                "reference_warmup": 600,
                "commanded_turn": 1_200,
                "reference_recovery": 600,
                "after_declared_schedule": 592,
            },
        )
        self.assertEqual(receipt["commanded_turn_step_count"], 1_200)
        self.assertEqual(receipt["turn_heading_offset_rad"], 0.2)
        self.assertTrue(receipt["turning_tested"])
        self.assertEqual(receipt["negative_control_class_count"], 5)
        self.assertTrue(
            all(item["rejected"] for item in receipt["negative_control_results"])
        )
        self.assertTrue(receipt["returned_before_mjmodel"])
        self.assertEqual(receipt["model_construction_count"], 0)
        self.assertEqual(receipt["world_attempt_count"], 0)
        self.assertEqual(receipt["world_build_count"], 0)
        self.assertEqual(receipt["solver_step_count"], 0)

    def test_preflight_restores_closed_production_bindings(self) -> None:
        production = route.production
        before = {
            "runtime": production._RUNTIME,
            "ramp": production._RAMP,
            "campaign_seed": production.CAMPAIGN_SEED,
            "reanchor_steps": production.EXPECTED_REANCHOR_STEPS,
            "design_steps": production.public_design.CONTROLLER_STEPS,
            "design_seed": production.public_design.CAMPAIGN_SEED,
            "design_perturbation": copy.deepcopy(
                production.public_design.INITIAL_PERTURBATION
            ),
            "bound_seed": production._bound_base.CAMPAIGN_SEED,
        }

        route.run_preflight()

        self.assertIs(production._RUNTIME, before["runtime"])
        self.assertIs(production._RAMP, before["ramp"])
        self.assertEqual(production.CAMPAIGN_SEED, before["campaign_seed"])
        self.assertEqual(production.EXPECTED_REANCHOR_STEPS, before["reanchor_steps"])
        self.assertEqual(
            production.public_design.CONTROLLER_STEPS,
            before["design_steps"],
        )
        self.assertEqual(production.public_design.CAMPAIGN_SEED, before["design_seed"])
        self.assertEqual(
            production.public_design.INITIAL_PERTURBATION,
            before["design_perturbation"],
        )
        self.assertEqual(production._bound_base.CAMPAIGN_SEED, before["bound_seed"])

    def test_complete_ramp_law_has_expected_exact_counts(self) -> None:
        scales = [
            route.ramp_design.startup_velocity_scale(step)
            for step in range(route.CONTROLLER_STEPS)
        ]

        self.assertEqual(scales[0], 0.0)
        self.assertEqual(scales[359], 1.0)
        self.assertEqual(scales[360], 1.0)
        self.assertEqual(sum(value < 1.0 for value in scales), 359)
        self.assertEqual(sum(value == 0.0 for value in scales), 1)
        self.assertEqual(sum(value == 1.0 for value in scales), 2_633)
        self.assertTrue(
            all(left < right for left, right in zip(scales[:358], scales[1:359]))
        )

    def test_contract_mutations_are_rejected(self) -> None:
        contract = route._contract()
        mutations = []

        wrong_seed = copy.deepcopy(contract)
        wrong_seed["fixture"]["campaign_seed"] += 1
        mutations.append(wrong_seed)

        wrong_horizon = copy.deepcopy(contract)
        wrong_horizon["fixed_horizon"]["controller_step_count"] += 1
        mutations.append(wrong_horizon)

        wrong_gate = copy.deepcopy(contract)
        wrong_gate["development_gate"]["raw_signed_cycle_shift"]["minimum_rad"] = 0.02
        mutations.append(wrong_gate)

        for mutation in mutations:
            with self.assertRaises(route._core.R23D3MujocoError):
                route._validate_contract_value(mutation)

    def test_common_physical_gate_vector_is_exact(self) -> None:
        measurements = {
            "final_forward_displacement_m": 0.030123046875,
            "turn_phase_yaw_delta_rad": 0.02,
            "maximum_absolute_requested_steering_fraction": 0.1,
            "maximum_absolute_held_steering_fraction": 0.1,
            "maximum_tilt_rad": 0.6,
            "minimum_torso_height_m": 0.2499708652072946,
            "contact_cycle_count_by_limb": {
                limb_id: 2 for limb_id in route.production.LIMB_IDS
            },
            "torso_ground_contact_step_count": 0,
            "controller_error_count": 0,
            "safe_no_actuation_count": 0,
            "nonfinite_observation_count": 0,
            "actuator_application_mismatch_count": 0,
            "controller_semantic_step_count": 2_992,
            "validated_portable_command_count": 23_936,
            "native_actuation_application_count": 23_936,
        }
        execution = {
            "integrity_passed": True,
            "controller_semantic_step_count": 2_992,
            "validated_portable_command_count": 23_936,
            "native_actuation_application_count": 23_936,
            "portable_impulse_violation_count": 0,
            "world_attempt_count": 1,
            "world_build_count": 1,
            "trace_retained_before_terminal_entry": True,
            "fixed_horizon_configuration_proved_before_fixture_insertion": True,
        }
        self.assertEqual(route._common_physical_gate_failures(measurements, execution), [])

        changed = copy.deepcopy(measurements)
        changed["final_forward_displacement_m"] -= 1e-12
        self.assertEqual(
            route._common_physical_gate_failures(changed, execution),
            ["R23D34_FORWARD_DISPLACEMENT"],
        )

    def test_positive_cycle_measurement_reads_complete_retained_trace(self) -> None:
        rows = []
        for step in range(route.CONTROLLER_STEPS):
            yaw = 0.0 if step < route.TURN_START_STEP else 0.02
            rows.append(
                {
                    "trace_step": step,
                    "phase_id": route.cycle_measurement.phase_for_step(step),
                    "measured_yaw_rad": yaw,
                }
            )
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            trace_path = root / "trace.ndjson"
            trace_path.write_text(
                "".join(
                    json.dumps(row, separators=(",", ":"), sort_keys=True) + "\n"
                    for row in rows
                ),
                encoding="utf-8",
            )
            os.environ[route.ATTEMPT_ROOT_ENV] = str(root)
            measured = route._positive_cycle_measurement(
                {"trace_artifact": {"path": str(trace_path)}}
            )

        self.assertAlmostEqual(measured["cycle_shift_rad"], 0.02)

    def test_missing_authorization_returns_before_any_model(self) -> None:
        with mock.patch.object(
            route.production.R23D65MujocoRobot,
            "__init__",
            side_effect=AssertionError("MjModel construction must remain unreachable"),
        ) as constructor:
            with self.assertRaises(route._core.R23D3MujocoError) as observed:
                route.run_physical("a" * 40)

        self.assertIn("PHYSICAL_AUTHORIZATION_REQUIRED", observed.exception.code)
        self.assertEqual(observed.exception.world_attempt_count, 0)
        self.assertEqual(observed.exception.world_build_count, 0)
        constructor.assert_not_called()

    def test_source_binding_equality_is_exact(self) -> None:
        bindings = [
            {
                "path": path.relative_to(route.REPO_ROOT).as_posix(),
                "raw_sha256": route._raw_sha256(path),
            }
            for path in route._required_source_paths()
        ]
        self.assertTrue(route._source_bindings_exact({"source_bindings": bindings}))

        missing = copy.deepcopy(bindings[:-1])
        self.assertFalse(route._source_bindings_exact({"source_bindings": missing}))

        extra = copy.deepcopy(bindings)
        extra.append({"path": "unexpected", "raw_sha256": "sha256:" + "0" * 64})
        self.assertFalse(route._source_bindings_exact({"source_bindings": extra}))


if __name__ == "__main__":
    unittest.main()
