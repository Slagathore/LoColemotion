from __future__ import annotations

import copy
import json
import unittest

import numpy as np

from . import turning_three_engine_route as worker


class TurningThreeEngineRouteTests(unittest.TestCase):
    def test_contract_is_exact_and_mutations_fail_closed(self) -> None:
        contract = worker._contract()
        worker._validate_contract_value(contract)
        mutations = []
        wrong_horizon = copy.deepcopy(contract)
        wrong_horizon["development_ghost"]["controller_step_count"] = 3
        mutations.append(wrong_horizon)
        wrong_profile = copy.deepcopy(contract)
        wrong_profile["canonical_semantics"]["actuator_cap_profile_sha256"] = (
            "sha256:" + "0" * 64
        )
        mutations.append(wrong_profile)
        wrong_population = copy.deepcopy(contract)
        wrong_population["development_ghost"]["ordered_engine_ids"] = [
            "godot_jolt",
            "mujoco",
        ]
        mutations.append(wrong_population)
        for candidate in mutations:
            with self.assertRaises(worker._core.R23D3MujocoError):
                worker._validate_contract_value(candidate)

    def test_zero_world_preflight_compiles_public_model_route(self) -> None:
        before = (
            worker.production.CAMPAIGN_SEED,
            worker.production.EXPECTED_REANCHOR_STEPS,
            worker.production.public_design.CONTROLLER_STEPS,
            copy.deepcopy(worker.production.public_design.INITIAL_PERTURBATION),
            worker.production._RUNTIME,
            worker.production._RAMP,
        )
        receipt = worker.run_preflight()
        after = (
            worker.production.CAMPAIGN_SEED,
            worker.production.EXPECTED_REANCHOR_STEPS,
            worker.production.public_design.CONTROLLER_STEPS,
            worker.production.public_design.INITIAL_PERTURBATION,
            worker.production._RUNTIME,
            worker.production._RAMP,
        )
        self.assertEqual(receipt["ok"], True)
        self.assertEqual(receipt["controller_step_count"], 2)
        self.assertEqual(receipt["negative_controls_rejected"], 2)
        self.assertEqual(receipt["model_construction_count"], 0)
        self.assertEqual(receipt["world_attempt_count"], 0)
        self.assertEqual(receipt["world_build_count"], 0)
        self.assertEqual(before[:4], after[:4])
        self.assertIs(before[4], after[4])
        self.assertIs(before[5], after[5])

    def test_inherited_preflight_bridge_accepts_measurement_origin_extension(self) -> None:
        plan = worker._core.evidence_window_forward_displacement_measurement_origin_plan(0)
        with worker._route_bindings():
            receipt = worker._core.run_preflight(
                worker.STAGE_ID,
                worker.ONSET_ID,
                worker.ARM_ID,
                forward_displacement_measurement_origin_plan=plan,
            )

        self.assertEqual(receipt["ok"], True)
        self.assertEqual(receipt["controller_step_count"], 2)
        self.assertEqual(receipt["model_construction_count"], 0)
        self.assertEqual(receipt["world_attempt_count"], 0)
        self.assertEqual(receipt["world_build_count"], 0)
        self.assertEqual(receipt["solver_step_count"], 0)
        self.assertFalse(receipt["physical_execution_authorized"])
        self.assertFalse(receipt["physical_acceptance_authority"])

    def test_private_kernel_is_bound_to_two_step_route(self) -> None:
        self.assertEqual(worker._core.CONTROLLER_STEPS, 2)
        self.assertEqual(worker._core.TURN_DURATION_STEPS, 2)
        self.assertEqual(worker._core.TERMINAL_SETTLE_STEPS, 0)
        self.assertIs(worker._core._physical_authorization, worker._physical_authorization)
        self.assertIs(worker._core._retain_trace, worker._retain_trace)
        self.assertIs(worker._core._trace_row, worker._trace_row)

    def test_initial_perturbation_matches_inherited_worker_shape(self) -> None:
        expected = {
            "campaign_seed": worker.CAMPAIGN_SEED,
            "fixture_vertical_clearance_m": 0.0008292800048366189,
            "fixture_yaw_rad": -0.0031932652927935123,
            "initial_linear_velocity_world_m_s": [
                0.0030934750102460384,
                0.0,
                -0.0007665741723030806,
            ],
            "initial_torso_angular_velocity_world_rad_s": [
                -0.0007512527517974377,
                0.0010391897521913052,
                0.0010421534534543753,
            ],
            "gait_phase_offset_ticks": 0,
        }
        self.assertEqual(worker.INITIAL_PERTURBATION, expected)
        with worker._route_bindings():
            inherited = worker.production._bound_base._initial_perturbation({})
            self.assertEqual(inherited, expected)
            self.assertIsNot(inherited, worker.production.public_design.INITIAL_PERTURBATION)

    def test_json_native_projection_removes_numpy_scalar_transport_types(self) -> None:
        projected = worker._json_native(
            {
                "target_velocity_readback_matches": np.bool_(True),
                "nested": [np.float64(0.125), np.int64(2)],
            }
        )
        self.assertIs(type(projected["target_velocity_readback_matches"]), bool)
        self.assertIs(type(projected["nested"][0]), float)
        self.assertIs(type(projected["nested"][1]), int)
        self.assertEqual(
            json.loads(json.dumps(projected, allow_nan=False)),
            {
                "target_velocity_readback_matches": True,
                "nested": [0.125, 2],
            },
        )

    def test_failure_projection_preserves_observed_world_counts(self) -> None:
        terminal = worker._normalize_failure(
            {
                "failure_stage": "settlement_complete",
                "failure_code": "SYNTHETIC_AFTER_WORLD_FAILURE",
                "world_attempt_count": 1,
                "world_build_count": 1,
            },
            "1" * 40,
        )
        self.assertEqual(terminal["schema_version"], worker.FAILURE_SCHEMA)
        self.assertEqual(terminal["route_id"], worker.ROUTE_ID)
        self.assertEqual(terminal["engine_id"], worker.ENGINE_ID)
        self.assertEqual(terminal["cell_id"], worker.CELL_ID)
        self.assertEqual(terminal["model_construction_count"], 1)
        self.assertEqual(terminal["world_attempt_count"], 1)
        self.assertEqual(terminal["world_build_count"], 1)
        self.assertFalse(terminal["physical_acceptance_authority"])


if __name__ == "__main__":
    unittest.main()
