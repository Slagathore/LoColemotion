from __future__ import annotations

import math
import unittest

import mujoco

from sporespore_mujoco_adapter.conformance import (
    ConformanceFailure,
    _maximum_impulse_to_force,
    capability_manifest,
    capability_manifest_sha256,
    run_c0_c5_conformance,
)
from sporespore_mujoco_adapter.characterization import (
    run_host_characterization_preflight,
)
from sporespore_mujoco_adapter.velocity_only_characterization import (
    run_velocity_only_host_preflight,
)
from sporespore_mujoco_adapter.velocity_only_stability_characterization import (
    run_stability_host_preflight,
)
from sporespore_mujoco_adapter.velocity_only_stability_characterization_vh3 import (
    _generalized_inertia_readback,
    run_stability_host_preflight as run_stability_host_vh3_preflight,
)
from sporespore_mujoco_adapter import (
    s169_force_limit_characterization_vh5 as vh5,
    selected_policy_development as selected,
    selected_policy_walking_mv1 as mv1,
    selected_policy_walking_mv2 as mv2,
    velocity_only_stability_characterization_vh4 as vh4,
)


class MuJoCoConformanceTest(unittest.TestCase):
    def test_manifest_advertises_only_implemented_host_capabilities(self) -> None:
        manifest = capability_manifest()
        self.assertTrue(manifest["conformance"]["c0_schema"])
        self.assertTrue(manifest["conformance"]["c1_pure_controller"])
        for capability in (
            "c2_kinematic",
            "c3_passive_dynamics",
            "c4_actuator",
            "c5_contact",
        ):
            self.assertTrue(manifest["conformance"][capability])
        self.assertFalse(manifest["conformance"]["c6_locomotion"])
        self.assertTrue(
            manifest["material_characterization"]["effective_breakaway"]
        )
        self.assertTrue(
            manifest["material_characterization"]["steady_slide"]
        )
        self.assertFalse(
            manifest["material_characterization"][
                "characterization_report_authority"
            ]
        )
        self.assertTrue(
            manifest["actuator_capabilities"][
                "response_grid_characterization"
            ]
        )
        self.assertFalse(manifest["controller_policy_authority"])
        self.assertFalse(manifest["physical_acceptance_authority"])

    def test_manifest_digest_is_stable_and_typed(self) -> None:
        digest = capability_manifest_sha256()
        self.assertEqual(digest, capability_manifest_sha256())
        self.assertTrue(digest.startswith("sha256:"))
        self.assertEqual(len(digest), 71)

    def test_invalid_impulse_force_mappings_fail_closed(self) -> None:
        for impulse, timestep in (
            (math.nan, 1.0 / 120.0),
            (-1.0, 1.0 / 120.0),
            (1.0, 0.0),
            (1.0, math.nan),
        ):
            with self.assertRaises(ConformanceFailure):
                _maximum_impulse_to_force(impulse, timestep)

    def test_exact_impulse_force_mapping_uses_pinned_timestep(self) -> None:
        force = _maximum_impulse_to_force(0.25, 1.0 / 120.0)
        self.assertAlmostEqual(force * (1.0 / 120.0), 0.25, places=14)

    def test_physical_c0_c5_fixtures_pass_as_one_report(self) -> None:
        report = run_c0_c5_conformance()
        self.assertTrue(report["ok"])
        self.assertEqual(report["passed_cells"], 5)
        self.assertEqual(report["failed_cells"], 0)
        self.assertEqual(
            report["passed_capabilities"],
            ["c0", "c1", "c2", "c3", "c4", "c5"],
        )
        self.assertFalse(report["physical_acceptance_authority"])

    def test_characterization_integrity_preflight_is_zero_world(self) -> None:
        report = run_host_characterization_preflight()
        self.assertTrue(report["ok"])
        self.assertTrue(report["perfect_synthetic_result_passed"])
        self.assertTrue(report["nonzero_failure_canary_rejected"])
        self.assertEqual(
            report["campaign_id"],
            "C6-HOST-CHARACTERIZATION-R2",
        )
        self.assertEqual(report["gate_id"], "C6-HC1-R2")
        self.assertEqual(
            report["preregistration_raw_sha256"],
            (
                "sha256:"
                "690dc6e5ed4d8d0be2c0c5e4eb294d"
                "8160f9ac9ec4309de7ded82aa89951f451"
            ),
        )
        self.assertEqual(report["world_build_count"], 0)
        self.assertFalse(report["physical_acceptance_authority"])

    def test_velocity_only_characterization_preflight_is_zero_world(self) -> None:
        report = run_velocity_only_host_preflight()
        self.assertTrue(report["ok"])
        self.assertTrue(report["perfect_synthetic_result_passed"])
        self.assertTrue(
            report["perfect_synthetic_serialization_round_trip_passed"]
        )
        self.assertEqual(report["declared_cell_count"], 12)
        self.assertEqual(report["negative_control_count"], 10)
        self.assertTrue(all(report["negative_controls_rejected"].values()))
        self.assertEqual(report["host_identity"]["verified_wheel_file_count"], 9)
        self.assertEqual(report["host_identity"]["world_build_count"], 0)
        self.assertEqual(
            report["campaign_id"],
            "C6-MUJOCO-VELOCITY-ONLY-HOST-CHARACTERIZATION-VH1",
        )
        self.assertEqual(report["gate_id"], "C6-MJC-HC-VH1")
        self.assertEqual(report["world_build_count"], 0)
        self.assertFalse(report["physics_state_modified"])
        self.assertFalse(report["physical_acceptance_authority"])

    def test_velocity_only_stability_preflight_is_zero_world(self) -> None:
        report = run_stability_host_preflight()
        self.assertTrue(report["ok"])
        self.assertTrue(report["perfect_synthetic_result_passed"])
        self.assertTrue(
            report["perfect_synthetic_serialization_round_trip_passed"]
        )
        self.assertEqual(report["declared_cell_count"], 24)
        self.assertEqual(report["declared_internal_trace_record_count"], 43200)
        self.assertEqual(report["negative_control_count"], 18)
        self.assertTrue(all(report["negative_controls_rejected"].values()))
        self.assertAlmostEqual(
            report["stability_mechanism"][
                "vh2_exact_fixture_saturated_band_crossing_ratio"
            ],
            1.0,
            places=14,
        )
        self.assertLess(
            report["stability_mechanism"][
                "vh2_armature_only_saturated_band_crossing_ratio"
            ],
            report["stability_mechanism"]["strict_saturated_band_skip_bound"],
        )
        self.assertEqual(report["host_identity"]["verified_wheel_file_count"], 9)
        self.assertEqual(report["host_identity"]["world_build_count"], 0)
        self.assertEqual(report["gate_id"], "C6-MJC-HC-VH2")
        self.assertEqual(report["world_build_count"], 0)
        self.assertFalse(report["physics_state_modified"])
        self.assertFalse(report["physical_acceptance_authority"])

    def test_velocity_only_stability_vh3_preflight_is_zero_world(self) -> None:
        report = run_stability_host_vh3_preflight()
        self.assertTrue(report["ok"])
        self.assertTrue(report["perfect_synthetic_result_passed"])
        self.assertTrue(
            report["perfect_synthetic_serialization_round_trip_passed"]
        )
        self.assertEqual(report["declared_cell_count"], 24)
        self.assertEqual(report["declared_internal_trace_record_count"], 43200)
        self.assertEqual(report["negative_control_count"], 18)
        self.assertTrue(all(report["negative_controls_rejected"].values()))
        self.assertEqual(report["binding_surface_canary_count"], 3)
        self.assertTrue(all(report["binding_surface_canaries_passed"].values()))
        self.assertTrue(report["host_identity"]["binding_surface"]["mjdata_has_M"])
        self.assertFalse(
            report["host_identity"]["binding_surface"]["mjdata_has_qM"]
        )
        self.assertAlmostEqual(
            report["stability_mechanism"][
                "vh3_exact_fixture_saturated_band_crossing_ratio"
            ],
            1.0,
            places=14,
        )
        self.assertEqual(report["gate_id"], "C6-MJC-HC-VH3")
        self.assertEqual(report["world_build_count"], 0)
        self.assertFalse(report["physics_state_modified"])
        self.assertFalse(report["physical_acceptance_authority"])

    def test_vh3_dense_generalized_inertia_binding_smoke_is_zero_step(self) -> None:
        model = mujoco.MjModel.from_xml_string(
            """
            <mujoco model="vh3_noncampaign_binding_smoke">
              <worldbody>
                <body name="child">
                  <joint name="hinge" type="hinge" axis="1 0 0"
                         armature="0.01" damping="0" limited="false"/>
                  <geom type="box" size=".1 .1 .1" mass="1"
                        contype="0" conaffinity="0"/>
                </body>
              </worldbody>
            </mujoco>
            """
        )
        data = mujoco.MjData(model)
        mujoco.mj_forward(model, data)
        self.assertEqual(data.time, 0.0)
        self.assertEqual(model.nv, 1)
        self.assertEqual(data.M.shape, (1,))
        self.assertAlmostEqual(
            _generalized_inertia_readback(model, data),
            1.0 / 60.0,
            places=14,
        )

    def test_velocity_only_stability_vh4_preflight_is_zero_world(self) -> None:
        report = vh4.run_stability_host_preflight()
        self.assertTrue(report["ok"])
        self.assertTrue(report["perfect_synthetic_result_passed"])
        self.assertTrue(
            report["perfect_synthetic_serialization_round_trip_passed"]
        )
        self.assertEqual(report["declared_cell_count"], 24)
        self.assertEqual(report["declared_internal_trace_record_count"], 43200)
        self.assertEqual(report["negative_control_count"], 23)
        self.assertTrue(all(report["negative_controls_rejected"].values()))
        self.assertEqual(report["binding_surface_canary_count"], 5)
        self.assertTrue(all(report["binding_surface_canaries_passed"].values()))
        self.assertEqual(report["gate_id"], "C6-MJC-HC-VH4")
        self.assertEqual(report["world_build_count"], 0)
        self.assertFalse(report["physics_state_modified"])
        self.assertFalse(report["physical_acceptance_authority"])

    def test_vh4_split_step_temporal_force_and_impulse_smoke(self) -> None:
        """Non-campaign two-step check of the timing relation VH4 gates."""

        model = vh4._model()
        data = mujoco.MjData(model)
        observation = mujoco.MjData(model)
        actuator_id = model.actuator("motor").id
        dof_address = int(model.jnt_dofadr[model.joint("hinge").id])
        target = 0.75

        def split_step() -> tuple[float, float, float, float]:
            mujoco.mj_step1(model, data)
            pre_velocity = float(data.qvel[dof_address])
            inertia = vh4._generalized_inertia_readback(model, data)
            data.ctrl[actuator_id] = target
            data.qfrc_applied.fill(0.0)
            mujoco.mj_step2(model, data)
            step_force = float(data.actuator_force[actuator_id])
            post_velocity = float(data.qvel[dof_address])
            momentum_impulse = inertia * (post_velocity - pre_velocity)

            observation.time = data.time
            observation.qpos[:] = data.qpos
            observation.qvel[:] = data.qvel
            observation.ctrl[:] = data.ctrl
            observation.qfrc_applied.fill(0.0)
            mujoco.mj_forward(model, observation)
            post_state_force = float(observation.actuator_force[actuator_id])
            return step_force, post_state_force, momentum_impulse, post_velocity

        step_force, post_force, impulse, velocity = split_step()
        self.assertAlmostEqual(step_force, 6.0, places=14)
        self.assertAlmostEqual(velocity, 0.6, places=14)
        self.assertAlmostEqual(impulse, step_force * vh4.INTERNAL_DT_S, places=14)
        self.assertAlmostEqual(post_force, 1.5, places=14)

        step_force, post_force, impulse, velocity = split_step()
        self.assertAlmostEqual(step_force, 1.5, places=14)
        self.assertAlmostEqual(velocity, 0.675, places=14)
        self.assertNotAlmostEqual(
            impulse,
            step_force * vh4.INTERNAL_DT_S,
            places=14,
        )
        self.assertAlmostEqual(impulse, post_force * vh4.INTERNAL_DT_S, places=14)

    def test_vh4_trace_gate_ignores_untrusted_force_limit_override(self) -> None:
        """An added report field cannot relax VH4's frozen 6 N m ceiling."""

        cell = vh4._perfect_synthetic_report()["cells"][0]
        cell["maximum_force_nm"] = 100.0
        cell["internal_step_trace"][0][6] = vh4.MAXIMUM_FORCE_NM + 0.5
        self.assertTrue(
            any(
                failure.startswith("C6_MJC_HC_VH4_TRACE_FORCE_LIMIT:")
                for failure in vh4._trace_failures(cell)
            )
        )

    def test_vh5_preflight_precedes_four_force_class_qualification_worlds(
        self,
    ) -> None:
        """VH5's whole synthetic gate must pass before any qualification model."""

        preflight = vh5.run_preflight()
        self.assertTrue(preflight["ok"])
        self.assertEqual(preflight["declared_force_limit_class_count"], 4)
        self.assertEqual(preflight["declared_cell_count"], 96)
        self.assertEqual(preflight["declared_mirrored_pair_count"], 48)
        self.assertEqual(preflight["declared_internal_trace_record_count"], 172800)
        self.assertEqual(preflight["negative_control_count"], 24)
        self.assertEqual(preflight["compiled_force_limit_canary_count"], 4)
        self.assertEqual(preflight["binding_surface_canary_count"], 5)
        self.assertEqual(preflight["world_build_count"], 0)
        self.assertFalse(preflight["physics_state_modified"])
        self.assertFalse(preflight["physical_acceptance_authority"])

        declaration = vh5._preregistration()
        expanded = vh5._expanded_cells(declaration)
        for class_id, _, _, force_limit in vh5.EXPECTED_FORCE_CLASSES:
            declared = next(
                item
                for item in expanded
                if item["force_limit_class_id"] == class_id
                and item["base_id"] == "unloaded_vp075"
                and item["initial_condition_profile"] == "zero"
            )
            cell = vh4._run_cell(declared, vh4._model(force_limit))
            self.assertTrue(cell["passed"], class_id)
            self.assertEqual(cell["maximum_force_nm"], force_limit)
            self.assertEqual(
                cell["motor_readback"]["force_range_nm"],
                [-force_limit, force_limit],
            )
            self.assertEqual(vh4._trace_failures(cell, force_limit), [])

    def test_selected_policy_model_preserves_exact_s169_semantic_order(self) -> None:
        robot = selected.MujocoBw19vRobot(selected.LocomotionCore())
        self.assertEqual(robot.compiled["morphology_id"], "qsdk_r05_generated_s169")
        self.assertEqual(robot.model.nbody, 10)
        self.assertEqual(robot.model.njnt, 9)
        self.assertEqual(robot.model.nu, 8)
        self.assertEqual(
            [robot.model.actuator(index).name for index in range(robot.model.nu)],
            robot.morphology["ordered_actuator_ids"],
        )
        self.assertEqual(
            robot.profile_id,
            selected.PER_ACTUATOR_DEVELOPMENT_PROFILE_ID,
        )

    def test_uniform_vh4_limit_cannot_enforce_every_portable_budget(self) -> None:
        core = selected.LocomotionCore()
        compiled = core.compile_bounded_quadruped(selected.s169_descriptor())
        uniform_outer_budget = vh4.MAXIMUM_FORCE_NM * selected.CONTROLLER_DT_S
        portable_budgets = [
            float(actuator["maximum_impulse_nms"])
            for actuator in compiled["morphology"]["morphology_spec"]["actuators"]
        ]
        self.assertTrue(any(budget < uniform_outer_budget for budget in portable_budgets))
        self.assertFalse(
            selected._mujoco_host_profile(
                selected.PER_ACTUATOR_DEVELOPMENT_PROFILE_ID
            )["host_response_characterized_for_this_profile"]
        )

    def test_selected_policy_early_horizon_real_physics_smoke(self) -> None:
        report = selected.run_development_probe(
            outer_steps=120,
            use_stability=True,
            schedule_id="clocked",
        )
        self.assertTrue(report["ok"])
        self.assertGreater(report["metrics"]["forward_displacement_m"], 0.04)
        self.assertEqual(report["portable_impulse_violation_count"], 0)
        self.assertEqual(report["torso_ground_contact_step_count"], 0)
        self.assertGreater(report["nonzero_stability_step_count"], 0)
        self.assertTrue(all(count > 0 for count in report["contact_cycles"].values()))
        self.assertFalse(report["host_response_characterized_for_this_profile"])
        self.assertFalse(report["claim_boundary"]["walking"])
        self.assertFalse(report["physical_acceptance_authority"])

    def test_mv1_characterized_profile_preserves_per_actuator_force_limits(
        self,
    ) -> None:
        profile = selected._mujoco_host_profile(
            selected.PER_ACTUATOR_VH5_CHARACTERIZED_PROFILE_ID
        )
        self.assertTrue(profile["host_response_characterized_for_this_profile"])
        self.assertEqual(profile["native_position_stiffness"], 0.0)
        robot = selected.MujocoBw19vRobot(
            selected.LocomotionCore(),
            selected.PER_ACTUATOR_VH5_CHARACTERIZED_PROFILE_ID,
        )
        expected = [
            selected._native_force_limit_nm(
                robot.actuator_specs[actuator_id], robot.profile_id
            )
            for actuator_id in robot.morphology["ordered_actuator_ids"]
        ]
        actual = [
            float(robot.model.actuator_forcerange[robot.actuator_ids[actuator_id]][1])
            for actuator_id in robot.morphology["ordered_actuator_ids"]
        ]
        self.assertEqual(actual, expected)

    def test_mv1_complete_production_gate_preflight_is_zero_world(self) -> None:
        preflight = mv1.run_preflight()
        self.assertTrue(preflight["ok"])
        self.assertTrue(preflight["perfect_synthetic_result_passed"])
        self.assertTrue(
            preflight["perfect_synthetic_serialization_round_trip_passed"]
        )
        self.assertEqual(preflight["negative_control_count"], 24)
        self.assertTrue(all(preflight["negative_controls_rejected"].values()))
        self.assertEqual(preflight["world_build_count"], 0)
        self.assertEqual(preflight["scene_insertion_count"], 0)
        self.assertFalse(preflight["physics_state_modified"])
        self.assertFalse(preflight["locomotion_outcome_exposed"])
        self.assertFalse(preflight["physical_acceptance_authority"])

    def test_mv2_real_dynamic_library_and_production_gate_are_zero_world(
        self,
    ) -> None:
        preflight = mv2.run_preflight()
        self.assertTrue(preflight["ok"])
        self.assertTrue(preflight["perfect_synthetic_result_passed"])
        self.assertTrue(
            preflight["perfect_synthetic_serialization_round_trip_passed"]
        )
        self.assertEqual(preflight["negative_control_count"], 29)
        self.assertEqual(preflight["synthetic_report_negative_control_count"], 27)
        self.assertEqual(preflight["real_dynamic_library_negative_control_count"], 2)
        self.assertTrue(all(preflight["negative_controls_rejected"].values()))
        dynamic = preflight["real_dynamic_library_profile_canary"]
        self.assertTrue(dynamic["ok"])
        self.assertTrue(dynamic["exact_release_library_loaded"])
        self.assertTrue(dynamic["positive_mapping_passed"])
        self.assertTrue(all(dynamic["negative_controls_rejected"].values()))
        self.assertEqual(dynamic["model_construction_count"], 0)
        self.assertEqual(dynamic["data_construction_count"], 0)
        self.assertEqual(preflight["world_build_count"], 0)
        self.assertEqual(preflight["scene_insertion_count"], 0)
        self.assertFalse(preflight["physics_state_modified"])
        self.assertFalse(preflight["locomotion_outcome_exposed"])
        self.assertFalse(preflight["physical_acceptance_authority"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
