from __future__ import annotations

import json
import unittest
import warnings

try:
    from .sporespore_locomotion import (
        R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
        R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256,
        R24D22_RECOVERY_S169_MORPHOLOGY_ID,
        SS_CORE_ERROR,
        LocomotionCore,
        LocomotionCoreError,
        r23d60_selected_s169_quadruped,
        r24d22_recovery_s169_morphology,
        reference_quadruped,
    )
except ImportError:
    from sporespore_locomotion import (
        R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
        R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256,
        R24D22_RECOVERY_S169_MORPHOLOGY_ID,
        SS_CORE_ERROR,
        LocomotionCore,
        LocomotionCoreError,
        r23d60_selected_s169_quadruped,
        r24d22_recovery_s169_morphology,
        reference_quadruped,
    )

class CtypesSmokeTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        # This suite deliberately exercises compatibility-frozen entrypoints.
        # Warning behavior is verified by versioning.test_conformance.
        warnings.simplefilter("ignore", DeprecationWarning)
        cls.core = LocomotionCore()

    def _partial_joint_map_fixture(
        self,
    ) -> tuple[dict, dict, dict, list[dict]]:
        descriptor = reference_quadruped("python_joint_map_v3")
        morphology = self.core.compile_bounded_quadruped(descriptor)["morphology"]
        command = self.core.command_centroidal_support_v2(
            {
                "schema_version": "sporespore_centroidal_support_request_v2",
                "semantic_step": 12,
                "whole_system_mass_kg": 8.0,
                "gravity_world_m_s2": {"x": 0.0, "y": -9.8, "z": 0.0},
                "support_plane_forward_world_unit": {
                    "x": 1.0,
                    "y": 0.0,
                    "z": 0.0,
                },
                "center_of_mass_world_m": {"x": 0.09, "y": 0.4, "z": -0.09},
                "center_of_mass_velocity_world_m_s": {
                    "x": 0.0,
                    "y": 0.0,
                    "z": 0.0,
                },
                "target_center_of_mass_world_m": {
                    "x": 0.09,
                    "y": 0.4,
                    "z": -0.09,
                },
                "torso_roll_rad": 0.0,
                "torso_pitch_rad": 0.0,
                "torso_roll_rate_rad_s": 0.0,
                "torso_pitch_rate_rad_s": 0.0,
                "horizontal_position_gain_n_per_m": 0.0,
                "horizontal_velocity_gain_ns_per_m": 0.0,
                "vertical_position_gain_n_per_m": 0.0,
                "vertical_velocity_gain_ns_per_m": 0.0,
                "roll_position_gain_nm_per_rad": 0.0,
                "roll_velocity_gain_nm_s_per_rad": 0.0,
                "pitch_position_gain_nm_per_rad": 0.0,
                "pitch_velocity_gain_nm_s_per_rad": 0.0,
                "maximum_horizontal_force_n": 0.0,
                "maximum_vertical_correction_n": 0.0,
                "maximum_roll_pitch_moment_nm": 0.0,
                "declared_supported_weight_fraction": 1.0,
                "characterized_friction_coefficient": 0.60,
                "minimum_normal_force_n": 0.0,
                "maximum_normal_force_n": 39.2,
                "nominal_support_count": 4,
                "feasibility_tolerance": 1.0e-5,
                "support_contacts": [
                    {
                        "contact_id": "front_left_foot",
                        "point_world_m": {"x": -0.22, "y": 0.0, "z": -0.22},
                        "preferred_normal_force_n": 0.0,
                    },
                    {
                        "contact_id": "rear_left_foot",
                        "point_world_m": {"x": 0.22, "y": 0.0, "z": -0.22},
                        "preferred_normal_force_n": 0.0,
                    },
                    {
                        "contact_id": "rear_right_foot",
                        "point_world_m": {"x": 0.22, "y": 0.0, "z": 0.22},
                        "preferred_normal_force_n": 0.0,
                    },
                ],
            }
        )
        self.assertTrue(command["feasible"])
        for contact in command["ordered_support_contact_commands"]:
            contact["joint_task_force_delta_world_n"] = {
                "x": 2.0,
                "y": 0.0,
                "z": 0.0,
            }
        actuator_by_id = {
            actuator["actuator_id"]: actuator
            for actuator in morphology["morphology_spec"]["actuators"]
        }
        kinematics = []
        for actuator_id in morphology["ordered_actuator_ids"]:
            actuator = actuator_by_id[actuator_id]
            limb = next(
                limb
                for limb in morphology["morphology_spec"]["limbs"]
                if actuator["joint_id"] in limb["ordered_joint_ids"]
            )
            joint_index = limb["ordered_joint_ids"].index(actuator["joint_id"])
            kinematics.append(
                {
                    "actuator_id": actuator_id,
                    "contact_site_id": limb["ordered_contact_site_ids"][0],
                    "joint_anchor_world_m": {
                        "x": 0.0,
                        "y": -0.25 * joint_index,
                        "z": 0.0,
                    },
                    "joint_axis_world_unit": {"x": 0.0, "y": 0.0, "z": 1.0},
                    "endpoint_world_m": {"x": 0.0, "y": -0.5, "z": 0.0},
                }
            )
        return descriptor, morphology, command, kinematics

    def test_version_and_compile_through_real_dynamic_library(self) -> None:
        self.assertEqual(self.core.version, "0.1.0")
        compiled = self.core.compile_bounded_quadruped(
            reference_quadruped("python_ffi_reference")
        )
        self.assertEqual(compiled["morphology_id"], "python_ffi_reference")
        self.assertEqual(len(compiled["morphology"]["ordered_body_ids"]), 9)
        self.assertEqual(len(compiled["morphology"]["ordered_actuator_ids"]), 8)
        self.assertEqual(compiled["world_build_count"], 0)
        self.assertFalse(compiled["physical_acceptance_authority"])

    def test_profile_through_real_dynamic_library(self) -> None:
        profile = self.core.candidate35_profile(reference_quadruped())
        self.assertEqual(profile["morphology_interaction_score"], 0.0)
        self.assertEqual(
            profile["cross_track_velocity_heading_gain_rad_per_m_s"],
            0.275,
        )
        self.assertFalse(profile["physical_acceptance_authority"])

    def test_recovery_morphology_support_and_refusal_through_real_library(
        self,
    ) -> None:
        descriptor = r24d22_recovery_s169_morphology()
        receipt = self.core.compile_recovery_morphology_v1(descriptor)
        self.assertEqual(
            receipt["recovery_morphology_id"],
            R24D22_RECOVERY_S169_MORPHOLOGY_ID,
        )
        self.assertEqual(receipt["support_status"], "supported_exact")
        self.assertIsNone(receipt["refusal_reason"])
        self.assertEqual(
            receipt["base_descriptor_sha256"],
            "sha256:ae7a0872b8b15dfb294c388931899cf82822293417d125dd72ee2a5a847e09e0",
        )
        self.assertEqual(
            receipt["base_morphology_spec_sha256"],
            "sha256:30893a75e8362dcab69f0fb46b0560cacbe5d5c034cb0152e67eb520ff35f45e",
        )
        self.assertTrue(receipt["prone_geometry"]["feasible"])
        self.assertGreater(
            receipt["prone_geometry"]["minimum_limb_ground_clearance_m"],
            0.0,
        )
        self.assertEqual(receipt["world_build_count"], 0)
        self.assertEqual(receipt["solver_step_count"], 0)
        self.assertFalse(receipt["physics_state_modified"])
        self.assertFalse(receipt["claim_boundary"]["recovery_behavior_claimed"])
        self.assertFalse(receipt["physical_acceptance_authority"])
        self.assertFalse(receipt["release_authority"])

        infeasible = r24d22_recovery_s169_morphology()
        infeasible["recovery_morphology_id"] = "python_recovery_refusal"
        infeasible["joint_authority"]["hip_anchor_parent_y_m"] = -0.05
        infeasible["joint_authority"]["hip_limit_magnitude_rad"] = 0.72
        infeasible["canonical_prone_pose"]["front_hip_angle_rad"] = 0.72
        infeasible["canonical_prone_pose"]["rear_hip_angle_rad"] = -0.72
        refusal = self.core.compile_recovery_morphology_v1(infeasible)
        self.assertEqual(
            refusal["support_status"],
            "unsupported_prone_geometry_infeasible",
        )
        self.assertEqual(
            refusal["refusal_reason"],
            "canonical_prone_pose_ground_penetration",
        )

        malformed = r24d22_recovery_s169_morphology()
        malformed["forbidden_override"] = True
        with self.assertRaises(LocomotionCoreError) as raised:
            self.core.compile_recovery_morphology_v1(malformed)
        self.assertEqual(raised.exception.status, SS_CORE_ERROR)
        self.assertEqual(raised.exception.failure_code, "SCHEMA_INVALID")

    def test_recovery_development_profile_through_real_dynamic_library(self) -> None:
        profile = self.core.recovery_development_profile_v1()
        self.assertEqual(
            profile["schema_version"],
            "sporespore_recovery_development_profile_v1",
        )
        self.assertEqual(len(profile["development_cohort"]), 3)
        self.assertEqual(len(profile["held_out_native_cohort"]), 9)
        self.assertFalse(profile["held_out_seed_use_during_development_permitted"])
        self.assertTrue(profile["thresholds_frozen_before_physical_outcome"])
        self.assertFalse(profile["physical_execution_authorized"])
        self.assertFalse(profile["physical_acceptance_authority"])
        self.assertFalse(profile["release_authority"])

        for operation, schema_version in (
            (
                self.core.recovery_collect_native_v1,
                "sporespore_recovery_native_collection_request_v1",
            ),
            (
                self.core.recovery_plan_control_v1,
                "sporespore_recovery_control_request_v1",
            ),
            (
                self.core.recovery_plan_stance_control_v1,
                "sporespore_recovery_stance_control_request_v1",
            ),
            (
                self.core.recovery_plan_stance_control_v2,
                "sporespore_recovery_stance_control_request_v2",
            ),
            (
                self.core.recovery_plan_stance_control_v3,
                "sporespore_recovery_stance_control_request_v3",
            ),
            (
                self.core.recovery_plan_stance_control_v4,
                "sporespore_recovery_stance_control_request_v4",
            ),
            (
                self.core.recovery_step_v4,
                "sporespore_recovery_step_request_v4",
            ),
            (
                self.core.recovery_step_v5,
                "sporespore_recovery_step_request_v5",
            ),
            (
                self.core.recovery_evaluate_trace_v4,
                "sporespore_recovery_evaluation_request_v4",
            ),
            (
                self.core.recovery_evaluate_trace_v5,
                "sporespore_recovery_evaluation_request_v5",
            ),
        ):
            with self.assertRaises(LocomotionCoreError) as failure:
                operation({"schema_version": schema_version})
            self.assertEqual(failure.exception.status, SS_CORE_ERROR)
            self.assertEqual(failure.exception.failure_code, "SCHEMA_INVALID")

    def test_recovery_v5_malformed_request_refuses_through_real_dynamic_library(
        self,
    ) -> None:
        with self.assertRaises(LocomotionCoreError) as raised:
            self.core.recovery_step_v5({})
        self.assertEqual(raised.exception.status, SS_CORE_ERROR)
        self.assertEqual(raised.exception.failure_code, "SCHEMA_INVALID")
        self.assertIn("schema_version", raised.exception.detail)

    def test_recovery_energy_v2_through_real_dynamic_library(self) -> None:
        request = {
            "schema_version": (
                "sporespore_recovery_energy_balance_aggregation_request_v2"
            ),
            "source_profile_id": "python_zero_world_energy_fixture_v1",
            "initial_mechanical_energy_j": 10.0,
            "current_mechanical_energy_j": 11.5,
            "ordered_increments": [
                {
                    "sequence_index": 0,
                    "semantic_step": 7,
                    "applied_actuator_work_j": 4.0,
                    "signed_external_work_j": 1.0,
                    "signed_constraint_exchange_j": 2.0,
                    "passive_dissipation_j": 0.5,
                    "source_measurement": True,
                },
                {
                    "sequence_index": 1,
                    "semantic_step": 8,
                    "applied_actuator_work_j": -0.5,
                    "signed_external_work_j": -0.25,
                    "signed_constraint_exchange_j": -3.0,
                    "passive_dissipation_j": 1.25,
                    "source_measurement": True,
                },
            ],
        }
        receipt = self.core.recovery_energy_balance_aggregate_v2(request)
        self.assertEqual(
            receipt["ledger"]["cumulative_signed_constraint_exchange_j"],
            -1.0,
        )
        self.assertEqual(
            receipt["ledger"]["cumulative_passive_dissipation_j"],
            1.75,
        )
        self.assertEqual(receipt["evaluation"]["signed_residual_j"], 0.0)
        self.assertEqual(receipt["world_build_count"], 0)
        self.assertEqual(receipt["solver_step_count"], 0)

        evaluation = self.core.recovery_energy_balance_evaluate_v2(
            {
                "schema_version": (
                    "sporespore_recovery_energy_balance_evaluation_request_v2"
                ),
                "ledger": receipt["ledger"],
            }
        )
        self.assertEqual(evaluation["signed_residual_j"], 0.0)
        self.assertFalse(evaluation["threshold_applied"])

        refusal = self.core.recovery_energy_balance_migrate_v1(
            {
                "schema_version": (
                    "sporespore_recovery_energy_balance_migration_request_v1"
                ),
                "direction": "v2_to_v1",
                "source_v1": None,
                "source_v2": receipt["ledger"],
            }
        )
        self.assertEqual(refusal["support_status"], "unsupported_capability")
        self.assertEqual(
            refusal["refusal_reason"],
            "portable_v1_signed_constraint_work_unrepresentable",
        )
        self.assertIsNone(refusal["target_v1"])
        self.assertFalse(refusal["physical_acceptance_authority"])

    def test_recovery_energy_v3_through_real_dynamic_library(self) -> None:
        # Exercise the V3-only discrete-staging term through the shipped DLL,
        # then verify that the independently exposed evaluator agrees exactly.
        request = {
            "schema_version": (
                "sporespore_recovery_energy_balance_aggregation_request_v3"
            ),
            "source_profile_id": "python_zero_world_energy_v3_fixture_v1",
            "initial_mechanical_energy_j": 10.0,
            "current_mechanical_energy_j": 11.875,
            "ordered_increments": [
                {
                    "sequence_index": 1,
                    "semantic_step": 1,
                    "applied_actuator_work_j": 4.0,
                    "signed_external_work_j": 1.0,
                    "signed_constraint_exchange_j": 2.0,
                    "signed_discrete_staging_exchange_j": 0.5,
                    "passive_dissipation_j": 0.5,
                    "source_measurement": True,
                },
                {
                    "sequence_index": 2,
                    "semantic_step": 2,
                    "applied_actuator_work_j": -0.5,
                    "signed_external_work_j": -0.25,
                    "signed_constraint_exchange_j": -3.0,
                    "signed_discrete_staging_exchange_j": -0.125,
                    "passive_dissipation_j": 1.25,
                    "source_measurement": True,
                },
            ],
        }
        receipt = self.core.recovery_energy_balance_aggregate_v3(request)
        ledger = receipt["ledger"]
        self.assertEqual(
            ledger["cumulative_signed_discrete_staging_exchange_j"],
            0.375,
        )
        self.assertEqual(receipt["evaluation"]["signed_residual_j"], 0.0)
        self.assertEqual(receipt["world_build_count"], 0)
        self.assertEqual(receipt["solver_step_count"], 0)

        evaluation = self.core.recovery_energy_balance_evaluate_v3(
            {
                "schema_version": (
                    "sporespore_recovery_energy_balance_evaluation_request_v3"
                ),
                "ledger": ledger,
            }
        )
        self.assertEqual(evaluation["signed_residual_j"], 0.0)
        self.assertFalse(evaluation["threshold_applied"])

    def test_exact_scope_actuator_cap_profile_and_refusals_cross_real_library(
        self,
    ) -> None:
        receipt = self.core.resolve_actuator_cap_profile_v1(
            R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
            r23d60_selected_s169_quadruped(),
        )
        self.assertEqual(receipt["support_status"], "supported_exact")
        self.assertIsNone(receipt["refusal_reason"])
        self.assertEqual(
            receipt["profile_sha256"],
            R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256,
        )
        self.assertEqual(
            receipt["descriptor_sha256"],
            "sha256:ae7a0872b8b15dfb294c388931899cf82822293417d125dd72ee2a5a847e09e0",
        )
        self.assertEqual(
            receipt["morphology_spec_sha256"],
            "sha256:30893a75e8362dcab69f0fb46b0560cacbe5d5c034cb0152e67eb520ff35f45e",
        )
        caps = receipt["profile"]["ordered_caps"]
        self.assertEqual(
            [entry["maximum_outer_step_impulse_nms"] for entry in caps],
            [
                0.05362625170687301,
                0.4567500054836273,
                0.05362625170687301,
                0.4567500054836273,
                0.05637374829312699,
                0.4567500054836273,
                0.05637374829312699,
                0.4567500054836273,
            ],
        )
        self.assertEqual(
            [caps[index]["base_to_profile_binary64_ulp_distance"] for index in (0, 4, 6)],
            ["0", "1", "1"],
        )
        self.assertEqual(
            caps[4]["base_compiled_maximum_impulse_binary64_hex"],
            "0x3facdd051a8b389c",
        )
        self.assertEqual(
            caps[4]["maximum_outer_step_impulse_binary64_hex"],
            "0x3facdd051a8b389b",
        )
        self.assertEqual(receipt["world_build_count"], 0)
        self.assertFalse(receipt["physics_state_modified"])
        self.assertFalse(receipt["physical_acceptance_authority"])
        self.assertFalse(receipt["release_authority"])

        out_of_domain = self.core.resolve_actuator_cap_profile_v1(
            R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
            reference_quadruped("valid_but_out_of_domain"),
        )
        self.assertEqual(
            out_of_domain["support_status"],
            "out_of_domain_morphology",
        )
        self.assertIsNone(out_of_domain["profile"])

        unsupported = self.core.resolve_actuator_cap_profile_v1(
            "unknown_profile",
            r23d60_selected_s169_quadruped(),
        )
        self.assertEqual(unsupported["support_status"], "unsupported_profile")
        self.assertIsNone(unsupported["profile"])

    def test_balanced_wave_profile_and_memory_through_real_dynamic_library(
        self,
    ) -> None:
        profile = self.core.balanced_wave_profile(reference_quadruped())
        self.assertEqual(
            profile["schema_version"],
            "sporespore_balanced_wave_profile_v1",
        )
        self.assertEqual(profile["policy_id"], "sporespore_balanced_wave_v1")
        self.assertEqual(profile["cross_track_heading_gain_rad_per_m"], 1.0)
        self.assertEqual(
            profile["cross_track_velocity_heading_gain_rad_per_m_s"],
            0.30,
        )
        self.assertEqual(profile["branch_surfaces"], [])
        memory = self.core.balanced_wave_initial_memory()
        self.assertEqual(
            memory["schema_version"],
            "sporespore_balanced_wave_memory_v1",
        )
        self.assertEqual(len(memory["ordered_limb_memory"]), 4)

        persistent_memory = self.core.balanced_wave_policy_initial_memory(
            "sporespore_balanced_wave_r23d29_two_swing_persistent_predictive_stability_guarded_steering_v1",
            reference_quadruped("python_ffi_persistent_memory"),
        )
        self.assertEqual(
            persistent_memory["schema_version"],
            "sporespore_balanced_wave_persistent_predictive_guard_memory_v1",
        )
        self.assertEqual(
            persistent_memory["steering_guard_floor_hold_steps_remaining"],
            0,
        )

    def test_unknown_field_fails_closed(self) -> None:
        descriptor = reference_quadruped()
        descriptor["forbidden_override"] = True
        with self.assertRaises(LocomotionCoreError) as raised:
            self.core.compile_bounded_quadruped(descriptor)
        self.assertEqual(raised.exception.status, SS_CORE_ERROR)
        self.assertEqual(raised.exception.failure_code, "SCHEMA_INVALID")

    def test_domain_certificate_refuses_universal_physical_claim(self) -> None:
        certificate = self.core.gq15_domain_certificate()
        self.assertTrue(certificate["compiler_defined_at_every_domain_point"])
        self.assertFalse(certificate["controller_continuous_over_complete_domain"])
        self.assertFalse(
            certificate[
                "continuous_full_volume_physical_locomotion_validated"
            ]
        )

    def _step_request(self) -> dict:
        descriptor = reference_quadruped("python_runtime")
        compiled = self.core.compile_bounded_quadruped(descriptor)
        morphology = compiled["morphology"]
        return {
            "schema_version": "sporespore_candidate35_step_request_v1",
            "descriptor": descriptor,
            "memory": self.core.candidate35_initial_memory(),
            "state": {
                "schema_version": "sporespore_state_frame_v1",
                "semantic_step": 0,
                "sample_time_s": 0.0,
                "base_pose_world": {
                    "position_m": {"x": 0.0, "y": 0.44, "z": 0.0},
                    "orientation_xyzw": {
                        "x": 0.0,
                        "y": 0.0,
                        "z": 0.0,
                        "w": 1.0,
                    },
                },
                "base_twist_world": {
                    "linear_velocity_m_s": {"x": 0.0, "y": 0.0, "z": 0.0},
                    "angular_velocity_rad_s": {
                        "x": 0.0,
                        "y": 0.0,
                        "z": 0.0,
                    },
                },
                "ordered_joint_observations": [
                    {
                        "joint_id": joint_id,
                        "position_rad": 0.0,
                        "velocity_rad_s": 0.0,
                        "anchor_error_m": 0.0,
                        "validity": {
                            "position": True,
                            "velocity": True,
                            "anchor_error": True,
                        },
                    }
                    for joint_id in morphology["ordered_joint_ids"]
                ],
                "ordered_contact_observations": [
                    {
                        "contact_site_id": contact_id,
                        "presence": True,
                        "bears_support": True,
                        "normal_load_n": None,
                        "provenance": {
                            "adapter_id": "python_runtime",
                            "engine_contact_ids": [f"{contact_id}_engine"],
                            "aggregation_rule_id": "qualified_bearing_only",
                            "quality": "qualified_bearing",
                        },
                    }
                    for contact_id in morphology["ordered_contact_site_ids"]
                ],
                "previous_applied_actuation": None,
                "gravity_world_m_s2": {"x": 0.0, "y": -9.81, "z": 0.0},
                "task_frame": {
                    "origin_world_m": {"x": 0.0, "y": 0.0, "z": 0.0},
                    "forward_axis_world_unit": {
                        "x": 1.0,
                        "y": 0.0,
                        "z": 0.0,
                    },
                    "lateral_axis_world_unit": {
                        "x": 0.0,
                        "y": 0.0,
                        "z": 1.0,
                    },
                    "up_axis_world_unit": {
                        "x": 0.0,
                        "y": 1.0,
                        "z": 0.0,
                    },
                    "reference_yaw_rad": 0.0,
                },
                "adapter_capability_sha256": (
                    "sha256:"
                    "2222222222222222222222222222222222222222222222222222222222222222"
                ),
            },
            "command": {
                "schema_version": "sporespore_motion_command_v2",
                "command_id": "python_walk",
                "desired_planar_velocity_task_m_s": {
                    "x": 0.2,
                    "y": 0.0,
                    "z": 0.0,
                },
                "desired_heading_rad": 0.0,
                "desired_yaw_rate_rad_s": None,
                "gait_family_id": "lateral_wave",
                "speed_class": "walk",
                "gait_amplitude": 1.0,
                "phase_progression_mode": "contact_gated",
                "valid_from_step": 0,
                "valid_through_step": 0,
                "authority": "test_fixture",
            },
        }

    def test_real_dynamic_library_executes_and_fails_closed_one_step(self) -> None:
        request = self._step_request()
        output = self.core.candidate35_step(request)
        self.assertFalse(output["actuation"]["safe_no_actuation"])
        self.assertEqual(len(output["actuation"]["ordered_commands"]), 8)
        self.assertFalse(output["actuation"]["physical_acceptance_authority"])

        request["state"]["ordered_joint_observations"][0]["velocity_rad_s"] = None
        request["state"]["ordered_joint_observations"][0]["validity"][
            "velocity"
        ] = False
        safe = self.core.candidate35_step(request)
        self.assertTrue(safe["actuation"]["safe_no_actuation"])
        self.assertTrue(
            all(
                command["target_velocity_rad_s"] == 0.0
                for command in safe["actuation"]["ordered_commands"]
            )
        )

    def test_balanced_wave_executes_and_rejects_candidate_memory(self) -> None:
        request = self._step_request()
        request["schema_version"] = "sporespore_balanced_wave_step_request_v1"
        request["memory"] = self.core.balanced_wave_initial_memory()
        output = self.core.balanced_wave_step(request)
        self.assertEqual(
            output["schema_version"],
            "sporespore_balanced_wave_runtime_v1",
        )
        self.assertEqual(
            output["next_memory"]["schema_version"],
            "sporespore_balanced_wave_memory_v1",
        )
        self.assertEqual(
            output["actuation"]["receipt"]["policy_id"],
            "sporespore_balanced_wave_v1",
        )
        self.assertFalse(output["actuation"]["safe_no_actuation"])
        self.assertEqual(len(output["actuation"]["ordered_commands"]), 8)

        request["memory"] = self.core.candidate35_initial_memory()
        safe = self.core.balanced_wave_step(request)
        self.assertTrue(safe["actuation"]["safe_no_actuation"])
        self.assertTrue(
            all(
                command["target_velocity_rad_s"] == 0.0
                for command in safe["actuation"]["ordered_commands"]
            )
        )
        self.assertEqual(
            safe["next_memory"]["schema_version"],
            "sporespore_candidate35_memory_v2",
        )

    def test_stateful_named_policy_requires_and_accepts_policy_memory(self) -> None:
        policy_id = (
            "sporespore_balanced_wave_r23d29_two_swing_persistent_"
            "predictive_stability_guarded_steering_v1"
        )
        request = self._step_request()
        request["memory"] = self.core.balanced_wave_policy_initial_memory(
            policy_id,
            request["descriptor"],
        )
        output = self.core.balanced_wave_policy_step(policy_id, request)
        self.assertFalse(output["actuation"]["safe_no_actuation"])
        self.assertEqual(
            output["next_memory"]["schema_version"],
            "sporespore_balanced_wave_persistent_predictive_guard_memory_v1",
        )
        self.assertEqual(
            output["actuation"]["receipt"]["steering_authority_guard"][
                "schema_version"
            ],
            "sporespore_steering_authority_guard_receipt_v3",
        )

        request["memory"] = self.core.balanced_wave_initial_memory()
        legacy = self.core.balanced_wave_policy_step(policy_id, request)
        self.assertTrue(legacy["actuation"]["safe_no_actuation"])
        self.assertIn(
            "balanced_wave_memory_version",
            legacy["actuation"]["receipt"]["controller_error"],
        )

    def test_canonical_mujoco_velocity_mapping_crosses_real_dynamic_library(
        self,
    ) -> None:
        request = self._step_request()
        request["memory"] = self.core.balanced_wave_initial_memory()
        output = self.core.balanced_wave_policy_step(
            "sporespore_balanced_wave_bw15f_b_v1",
            request,
        )
        actuation = output["actuation"]
        residuals = [
            {
                "schema_version": "sporespore_canonical_velocity_residual_v1",
                "actuator_id": command["actuator_id"],
                "canonical_velocity_delta_rad_s": (
                    0.01 if index % 2 == 0 else -0.01
                ),
                "command_not_measurement": True,
                "physical_acceptance_authority": False,
            }
            for index, command in enumerate(actuation["ordered_commands"])
        ]
        canonical = self.core.canonical_velocity_compose_v1(
            {
                "schema_version": (
                    "sporespore_canonical_velocity_compose_request_v1"
                ),
                "descriptor": request["descriptor"],
                "source_actuation": actuation,
                "ordered_stability_residuals": residuals,
            }
        )
        mapped = self.core.canonical_velocity_host_map_v1(
            {
                "schema_version": (
                    "sporespore_canonical_velocity_host_map_request_v1"
                ),
                "descriptor": request["descriptor"],
                "canonical_actuation": canonical,
                "host_profile": {
                    "schema_version": "sporespore_velocity_only_host_profile_v1",
                    "profile_id": (
                        "mujoco_velocity_servo_force_limited_five_substep_v3"
                    ),
                    "adapter_id": "sporespore_mujoco_adapter",
                    "engine_id": "mujoco",
                    "native_motor_model_id": (
                        "velocity_servo_force_limited_five_substep_v3"
                    ),
                    "canonical_to_host_velocity_sign": 1.0,
                    "independent_native_position_feedback_applied": False,
                    "native_position_stiffness": 0.0,
                    "retained_host_behavior_equivalence_target": False,
                    "host_response_characterized_for_this_profile": True,
                    "world_build_count": 0,
                    "physical_acceptance_authority": False,
                },
            }
        )
        self.assertEqual(mapped["engine_id"], "mujoco")
        self.assertTrue(mapped["host_response_characterized_for_this_profile"])
        self.assertEqual(len(mapped["ordered_commands"]), 8)
        self.assertTrue(
            all(
                command["native_target_position_rad"] is None
                for command in mapped["ordered_commands"]
            )
        )
        self.assertFalse(mapped["physical_acceptance_authority"])

        # Regression for the implementation mismatch preserved by the closed
        # C6-MJC-BW19V-MV1 attempt: the exact VH5-characterized s169 profile
        # must cross the real Rust dynamic-library boundary, not merely pass a
        # Python-side synthetic report evaluator.
        vh5_mapped = self.core.canonical_velocity_host_map_v1(
            {
                "schema_version": (
                    "sporespore_canonical_velocity_host_map_request_v1"
                ),
                "descriptor": request["descriptor"],
                "canonical_actuation": canonical,
                "host_profile": {
                    "schema_version": "sporespore_velocity_only_host_profile_v1",
                    "profile_id": (
                        "mujoco_s169_per_actuator_force_limited_five_substep_"
                        "vh5_validated_v1"
                    ),
                    "adapter_id": "sporespore_mujoco_adapter",
                    "engine_id": "mujoco",
                    "native_motor_model_id": (
                        "velocity_servo_s169_per_actuator_force_limited_"
                        "five_substep_vh5_validated_v1"
                    ),
                    "canonical_to_host_velocity_sign": 1.0,
                    "independent_native_position_feedback_applied": False,
                    "native_position_stiffness": 0.0,
                    "retained_host_behavior_equivalence_target": False,
                    "host_response_characterized_for_this_profile": True,
                    "world_build_count": 0,
                    "physical_acceptance_authority": False,
                },
            }
        )
        self.assertEqual(
            vh5_mapped["host_profile_id"],
            "mujoco_s169_per_actuator_force_limited_five_substep_vh5_validated_v1",
        )
        self.assertTrue(
            vh5_mapped["host_response_characterized_for_this_profile"]
        )
        self.assertTrue(
            all(
                command["native_target_position_rad"] is None
                for command in vh5_mapped["ordered_commands"]
            )
        )
        self.assertFalse(vh5_mapped["physical_acceptance_authority"])

        invalid_profile = json.loads(
            json.dumps(
                {
                    "schema_version": "sporespore_velocity_only_host_profile_v1",
                    "profile_id": (
                        "mujoco_velocity_servo_force_limited_five_substep_v3"
                    ),
                    "adapter_id": "sporespore_mujoco_adapter",
                    "engine_id": "mujoco",
                    "native_motor_model_id": (
                        "velocity_servo_force_limited_five_substep_v3"
                    ),
                    "canonical_to_host_velocity_sign": 1.0,
                    "independent_native_position_feedback_applied": False,
                    "native_position_stiffness": 0.0,
                    "retained_host_behavior_equivalence_target": False,
                    "host_response_characterized_for_this_profile": False,
                    "world_build_count": 0,
                    "physical_acceptance_authority": False,
                }
            )
        )
        with self.assertRaises(LocomotionCoreError):
            self.core.canonical_velocity_host_map_v1(
                {
                    "schema_version": (
                        "sporespore_canonical_velocity_host_map_request_v1"
                    ),
                    "descriptor": request["descriptor"],
                    "canonical_actuation": canonical,
                    "host_profile": invalid_profile,
                }
            )

    def test_stability_observation_crosses_real_dynamic_library(self) -> None:
        descriptor = reference_quadruped("python_stability")
        morphology = self.core.compile_bounded_quadruped(descriptor)["morphology"]
        body_states = [
            {
                "body_id": body_id,
                "pose_world": {
                    "position_m": {"x": 0.0, "y": 0.44, "z": 0.0},
                    "orientation_xyzw": {
                        "x": 0.0,
                        "y": 0.0,
                        "z": 0.0,
                        "w": 1.0,
                    },
                },
                "twist_world": {
                    "linear_velocity_m_s": {"x": 0.0, "y": 0.0, "z": 0.0},
                    "angular_velocity_rad_s": {
                        "x": 0.0,
                        "y": 0.0,
                        "z": 0.0,
                    },
                },
            }
            for body_id in morphology["ordered_body_ids"]
        ]
        support_contacts = []
        for contact_id in morphology["ordered_contact_site_ids"]:
            support_contacts.append(
                {
                    "contact_site_id": contact_id,
                    "presence": True,
                    "bears_support": True,
                    "point_world_m": {
                        "x": 0.20 if contact_id.startswith("front") else -0.20,
                        "y": 0.0,
                        "z": 0.15 if "left" in contact_id else -0.15,
                    },
                    "normal_world_unit": {"x": 0.0, "y": 1.0, "z": 0.0},
                    "surface_relative_velocity_world_m_s": {
                        "x": 0.0,
                        "y": 0.0,
                        "z": 0.0,
                    },
                    "material_id": "python_fixture_material",
                    "adapter_id": "python_fixture",
                    "engine_contact_ids": [f"{contact_id}_engine"],
                }
            )
        stability_state = {
            "schema_version": "sporespore_stability_state_v2",
            "semantic_step": 9,
            "ordered_body_states": body_states,
            "ordered_support_contacts": support_contacts,
            "gravity_world_m_s2": {"x": 0.0, "y": -9.81, "z": 0.0},
            "support_plane_forward_world_unit": {
                "x": 1.0,
                "y": 0.0,
                "z": 0.0,
            },
            "adapter_capability_sha256": "sha256:" + ("3" * 64),
        }
        observation = self.core.observe_stability_v2(
            {
                "schema_version": "sporespore_observe_stability_request_v2",
                "descriptor": descriptor,
                "state": stability_state,
            }
        )
        self.assertEqual(
            observation["schema_version"],
            "sporespore_support_observation_v2",
        )
        self.assertEqual(observation["semantic_step"], 9)
        self.assertEqual(observation["support_geometry_kind"], "polygon")
        self.assertTrue(observation["support_polygon_available"])
        self.assertGreater(observation["center_of_mass_margin_m"], 0.0)
        self.assertFalse(observation["physics_state_modified"])
        self.assertFalse(observation["physical_acceptance_authority"])

        plan = self.core.plan_scheduled_load_transfer_v1(
            {
                "schema_version": "sporespore_plan_scheduled_load_transfer_request_v1",
                "descriptor": descriptor,
                "request": {
                    "schema_version": "sporespore_scheduled_load_transfer_request_v1",
                    "policy_id": "sporespore_scheduled_load_transfer_bw9l_d_v1",
                    "gait_amplitude": 1.0,
                    "cycle_steps": 360,
                    "swing_steps": 72,
                    "characterized_friction_coefficient": 1.0,
                    "maximum_normal_force_n": 100.0,
                    "feasibility_tolerance": 1.0e-5,
                    "ordered_limb_gait_steps": [
                        {"limb_id": limb_id, "gait_step": 54}
                        for limb_id in morphology["ordered_limb_ids"]
                    ],
                    "stability_state": stability_state,
                },
            }
        )
        self.assertEqual(
            plan["schema_version"],
            "sporespore_scheduled_load_transfer_receipt_v1",
        )
        self.assertTrue(plan["active"])
        self.assertEqual(plan["scheduled_limb_id"], "rear_left")
        self.assertEqual(
            plan["ordered_scheduled_unweighted_contact_ids"],
            ["rear_left_foot"],
        )
        self.assertEqual(plan["morphology_branch_surface_count"], 0)
        self.assertFalse(plan["physics_state_modified"])
        self.assertFalse(plan["physical_acceptance_authority"])

        v2_request = {
            "schema_version": "sporespore_plan_scheduled_load_transfer_request_v2",
            "descriptor": descriptor,
            "request": {
                "schema_version": "sporespore_scheduled_load_transfer_request_v2",
                "policy_id": "sporespore_scheduled_load_transfer_bw10f_d_v2",
                "gait_amplitude": 1.0,
                "cycle_steps": 360,
                "swing_steps": 72,
                "characterized_friction_coefficient": 1.0,
                "maximum_normal_force_n": 100.0,
                "feasibility_tolerance": 1.0e-5,
                "ordered_limb_gait_steps": [
                    {"limb_id": limb_id, "gait_step": 54}
                    for limb_id in morphology["ordered_limb_ids"]
                ],
                "stability_state": stability_state,
            },
        }
        v2_plan = self.core.plan_scheduled_load_transfer_v2(v2_request)
        self.assertEqual(
            v2_plan["schema_version"],
            "sporespore_scheduled_load_transfer_receipt_v2",
        )
        self.assertEqual(v2_plan["planning_availability"], "available")
        self.assertEqual(v2_plan["planning_outcome_code"], "AVAILABLE")
        self.assertFalse(v2_plan["fail_zero_required"])
        self.assertTrue(v2_plan["active"])
        self.assertEqual(v2_plan["morphology_branch_surface_count"], 0)
        self.assertFalse(v2_plan["walking_claim_authorized"])
        self.assertFalse(v2_plan["physical_acceptance_authority"])

        unavailable_request = json.loads(json.dumps(v2_request))
        unavailable_contacts = unavailable_request["request"]["stability_state"][
            "ordered_support_contacts"
        ]
        unavailable_contacts[0]["bears_support"] = False
        unavailable_contacts[1]["bears_support"] = False
        unavailable_plan = self.core.plan_scheduled_load_transfer_v2(
            unavailable_request
        )
        self.assertEqual(
            unavailable_plan["planning_availability"],
            "observation_unavailable",
        )
        self.assertTrue(unavailable_plan["fail_zero_required"])
        self.assertIsNone(unavailable_plan["centroidal_request"])
        self.assertIsNone(unavailable_plan["centroidal_command"])
        self.assertEqual(
            unavailable_plan["ordered_safe_zero_actuator_ids"],
            morphology["ordered_actuator_ids"],
        )

        v3_request = {
            "schema_version": "sporespore_plan_scheduled_load_transfer_request_v3",
            "descriptor": descriptor,
            "request": {
                "schema_version": "sporespore_scheduled_load_transfer_request_v3",
                "policy_id": "sporespore_scheduled_load_transfer_bw11r_d_v3",
                "semantic_step": 9,
                "observation_available": False,
                "observation_unavailable_reason": "NO_QUALIFIED_SUPPORT_CONTACT",
                "gait_amplitude": 1.0,
                "cycle_steps": 360,
                "swing_steps": 72,
                "characterized_friction_coefficient": 1.0,
                "maximum_normal_force_n": 100.0,
                "feasibility_tolerance": 1.0e-5,
                "ordered_limb_gait_steps": [
                    {"limb_id": limb_id, "gait_step": 54}
                    for limb_id in morphology["ordered_limb_ids"]
                ],
                "stability_state": None,
            },
        }
        v3_plan = self.core.plan_scheduled_load_transfer_v3(v3_request)
        self.assertEqual(
            v3_plan["schema_version"],
            "sporespore_scheduled_load_transfer_receipt_v3",
        )
        self.assertFalse(v3_plan["observation_input_available"])
        self.assertEqual(
            v3_plan["observation_unavailable_reason"],
            "NO_QUALIFIED_SUPPORT_CONTACT",
        )
        self.assertEqual(
            v3_plan["planning_availability"],
            "observation_unavailable",
        )
        self.assertEqual(
            v3_plan["planning_outcome_code"],
            "OBSERVATION_UNAVAILABLE:NO_QUALIFIED_SUPPORT_CONTACT",
        )
        self.assertTrue(v3_plan["fail_zero_required"])
        self.assertEqual(
            v3_plan["ordered_safe_zero_actuator_ids"],
            morphology["ordered_actuator_ids"],
        )
        self.assertFalse(v3_plan["physical_acceptance_authority"])

    def test_centroidal_command_crosses_real_dynamic_library(self) -> None:
        command = self.core.command_centroidal_support_v2(
            {
                "schema_version": "sporespore_centroidal_support_request_v2",
                "semantic_step": 10,
                "whole_system_mass_kg": 8.0,
                "gravity_world_m_s2": {"x": 0.0, "y": -9.8, "z": 0.0},
                "support_plane_forward_world_unit": {
                    "x": 1.0,
                    "y": 0.0,
                    "z": 0.0,
                },
                "center_of_mass_world_m": {"x": 0.09, "y": 0.38625, "z": -0.09},
                "center_of_mass_velocity_world_m_s": {
                    "x": 0.0,
                    "y": 0.0,
                    "z": 0.0,
                },
                "target_center_of_mass_world_m": {
                    "x": 0.09,
                    "y": 0.38625,
                    "z": -0.09,
                },
                "torso_roll_rad": 0.0,
                "torso_pitch_rad": 0.0,
                "torso_roll_rate_rad_s": 0.0,
                "torso_pitch_rate_rad_s": 0.0,
                "horizontal_position_gain_n_per_m": 160.0,
                "horizontal_velocity_gain_ns_per_m": 24.0,
                "vertical_position_gain_n_per_m": 200.0,
                "vertical_velocity_gain_ns_per_m": 30.0,
                "roll_position_gain_nm_per_rad": 30.0,
                "roll_velocity_gain_nm_s_per_rad": 4.0,
                "pitch_position_gain_nm_per_rad": 30.0,
                "pitch_velocity_gain_nm_s_per_rad": 4.0,
                "maximum_horizontal_force_n": 30.0,
                "maximum_vertical_correction_n": 20.0,
                "maximum_roll_pitch_moment_nm": 6.0,
                "declared_supported_weight_fraction": 1.0,
                "characterized_friction_coefficient": 0.60,
                "minimum_normal_force_n": 0.0,
                "maximum_normal_force_n": 39.2,
                "nominal_support_count": 4,
                "feasibility_tolerance": 1.0e-5,
                "support_contacts": [
                    {
                        "contact_id": "front_left",
                        "point_world_m": {"x": -0.22, "y": 0.0, "z": -0.22},
                        "preferred_normal_force_n": 0.0,
                    },
                    {
                        "contact_id": "rear_left",
                        "point_world_m": {"x": 0.22, "y": 0.0, "z": -0.22},
                        "preferred_normal_force_n": 0.0,
                    },
                    {
                        "contact_id": "rear_right",
                        "point_world_m": {"x": 0.22, "y": 0.0, "z": 0.22},
                        "preferred_normal_force_n": 0.0,
                    },
                ],
            }
        )
        self.assertTrue(command["feasible"])
        self.assertEqual(command["semantic_step"], 10)
        self.assertFalse(command["actuator_mapping_available"])
        self.assertFalse(command["per_foot_measured_load_allocation_available"])
        self.assertFalse(command["physics_state_modified"])
        self.assertFalse(command["physical_acceptance_authority"])

    def test_endpoint_force_joint_map_crosses_real_dynamic_library(self) -> None:
        descriptor = reference_quadruped("python_joint_map")
        morphology = self.core.compile_bounded_quadruped(descriptor)["morphology"]
        command = self.core.command_centroidal_support_v2(
            {
                "schema_version": "sporespore_centroidal_support_request_v2",
                "semantic_step": 11,
                "whole_system_mass_kg": 8.0,
                "gravity_world_m_s2": {"x": 0.0, "y": -9.8, "z": 0.0},
                "support_plane_forward_world_unit": {
                    "x": 1.0,
                    "y": 0.0,
                    "z": 0.0,
                },
                "center_of_mass_world_m": {"x": 0.0, "y": 0.4, "z": 0.0},
                "center_of_mass_velocity_world_m_s": {
                    "x": 0.0,
                    "y": 0.0,
                    "z": 0.0,
                },
                "target_center_of_mass_world_m": {
                    "x": 0.0,
                    "y": 0.4,
                    "z": 0.0,
                },
                "torso_roll_rad": 0.0,
                "torso_pitch_rad": 0.0,
                "torso_roll_rate_rad_s": 0.0,
                "torso_pitch_rate_rad_s": 0.0,
                "horizontal_position_gain_n_per_m": 0.0,
                "horizontal_velocity_gain_ns_per_m": 0.0,
                "vertical_position_gain_n_per_m": 0.0,
                "vertical_velocity_gain_ns_per_m": 0.0,
                "roll_position_gain_nm_per_rad": 0.0,
                "roll_velocity_gain_nm_s_per_rad": 0.0,
                "pitch_position_gain_nm_per_rad": 0.0,
                "pitch_velocity_gain_nm_s_per_rad": 0.0,
                "maximum_horizontal_force_n": 0.0,
                "maximum_vertical_correction_n": 0.0,
                "maximum_roll_pitch_moment_nm": 0.0,
                "declared_supported_weight_fraction": 1.0,
                "characterized_friction_coefficient": 0.60,
                "minimum_normal_force_n": 0.0,
                "maximum_normal_force_n": 39.2,
                "nominal_support_count": 4,
                "feasibility_tolerance": 1.0e-5,
                "support_contacts": [
                    {
                        "contact_id": "front_left_foot",
                        "point_world_m": {"x": -0.22, "y": 0.0, "z": -0.22},
                        "preferred_normal_force_n": 0.0,
                    },
                    {
                        "contact_id": "rear_left_foot",
                        "point_world_m": {"x": 0.22, "y": 0.0, "z": -0.22},
                        "preferred_normal_force_n": 0.0,
                    },
                    {
                        "contact_id": "rear_right_foot",
                        "point_world_m": {"x": 0.22, "y": 0.0, "z": 0.22},
                        "preferred_normal_force_n": 0.0,
                    },
                    {
                        "contact_id": "front_right_foot",
                        "point_world_m": {"x": -0.22, "y": 0.0, "z": 0.22},
                        "preferred_normal_force_n": 0.0,
                    },
                ],
            }
        )
        for contact in command["ordered_support_contact_commands"]:
            contact["joint_task_force_delta_world_n"] = {
                "x": 2.0,
                "y": 0.0,
                "z": 0.0,
            }
        actuator_by_id = {
            actuator["actuator_id"]: actuator
            for actuator in morphology["morphology_spec"]["actuators"]
        }
        kinematics = []
        for actuator_id in morphology["ordered_actuator_ids"]:
            actuator = actuator_by_id[actuator_id]
            limb = next(
                limb
                for limb in morphology["morphology_spec"]["limbs"]
                if actuator["joint_id"] in limb["ordered_joint_ids"]
            )
            joint_index = limb["ordered_joint_ids"].index(actuator["joint_id"])
            kinematics.append(
                {
                    "actuator_id": actuator_id,
                    "contact_site_id": limb["ordered_contact_site_ids"][0],
                    "joint_anchor_world_m": {
                        "x": 0.0,
                        "y": -0.25 * joint_index,
                        "z": 0.0,
                    },
                    "joint_axis_world_unit": {"x": 0.0, "y": 0.0, "z": 1.0},
                    "endpoint_world_m": {"x": 0.0, "y": -0.5, "z": 0.0},
                }
            )
        receipt = self.core.map_endpoint_force_to_joint_v2(
            {
                "schema_version": (
                    "sporespore_map_endpoint_force_to_joint_request_v2"
                ),
                "descriptor": descriptor,
                "request": {
                    "schema_version": (
                        "sporespore_endpoint_force_joint_map_request_v2"
                    ),
                    "semantic_step": 11,
                    "centroidal_command": command,
                    "ordered_actuator_kinematics": kinematics,
                },
            }
        )
        mapped = receipt["ordered_generalized_joint_torque_commands"]
        self.assertEqual(
            [command["actuator_id"] for command in mapped],
            morphology["ordered_actuator_ids"],
        )
        self.assertAlmostEqual(mapped[0]["generalized_torque_command_nm"], 1.0)
        self.assertAlmostEqual(mapped[1]["generalized_torque_command_nm"], 0.5)
        self.assertTrue(receipt["endpoint_force_map_available"])
        self.assertFalse(receipt["measured_joint_torque_available"])
        self.assertFalse(receipt["actuator_response_characterized"])
        self.assertFalse(receipt["adapter_actuation_applied"])
        self.assertFalse(receipt["physics_state_modified"])
        self.assertFalse(receipt["physical_acceptance_authority"])

    def test_partial_support_joint_map_v3_crosses_real_dynamic_library(self) -> None:
        descriptor, morphology, command, kinematics = self._partial_joint_map_fixture()
        receipt = self.core.map_endpoint_force_to_joint_v3(
            {
                "schema_version": (
                    "sporespore_map_endpoint_force_to_joint_request_v3"
                ),
                "descriptor": descriptor,
                "request": {
                    "schema_version": (
                        "sporespore_endpoint_force_joint_map_request_v3"
                    ),
                    "semantic_step": 12,
                    "centroidal_command": command,
                    "ordered_actuator_kinematics": kinematics,
                },
            }
        )
        mapped = receipt["ordered_generalized_joint_torque_commands"]
        self.assertEqual(
            [item["actuator_id"] for item in mapped],
            morphology["ordered_actuator_ids"],
        )
        self.assertEqual(receipt["active_actuator_count"], 6)
        self.assertEqual(receipt["inactive_actuator_count"], 2)
        inactive = [item for item in mapped if not item["active_support_contact"]]
        self.assertEqual(len(inactive), 2)
        for item in inactive:
            self.assertEqual(item["contact_site_id"], "front_right_foot")
            self.assertEqual(item["mapping_mode"], "inactive_contact_zero")
            self.assertEqual(
                item["endpoint_task_force_command_world_n"],
                {"x": 0.0, "y": 0.0, "z": 0.0},
            )
            self.assertEqual(item["generalized_torque_command_nm"], 0.0)
            self.assertTrue(item["inactive_contact_forced_zero"])
        self.assertTrue(receipt["partial_support_mapping_available"])
        self.assertTrue(receipt["inactive_contact_commands_forced_zero"])
        self.assertFalse(receipt["measured_joint_torque_available"])
        self.assertFalse(receipt["actuator_response_characterized"])
        self.assertFalse(receipt["adapter_actuation_applied"])
        self.assertFalse(receipt["physics_state_modified"])
        self.assertFalse(receipt["physical_acceptance_authority"])

    def test_bounded_stability_influence_crosses_real_dynamic_library(self) -> None:
        descriptor = reference_quadruped("python_influence")
        actuator_ids = self.core.compile_bounded_quadruped(descriptor)["morphology"][
            "ordered_actuator_ids"
        ]
        receipt = self.core.bound_stability_influence_v2(
            {
                "schema_version": (
                    "sporespore_bound_stability_influence_request_v2"
                ),
                "descriptor": descriptor,
                "request": {
                    "schema_version": "sporespore_stability_influence_request_v2",
                    "semantic_step": 2,
                    "availability": "available",
                    "maximum_absolute_position_delta_rad": 0.10,
                    "maximum_absolute_velocity_delta_rad_s": 0.20,
                    "maximum_position_delta_slew_per_step_rad": 0.02,
                    "maximum_velocity_delta_slew_per_step_rad_s": 0.04,
                    "ordered_requested_corrections": [
                        {
                            "actuator_id": actuator_id,
                            "requested_position_delta_rad": 0.50,
                            "requested_velocity_delta_rad_s": -0.50,
                        }
                        for actuator_id in actuator_ids
                    ],
                    "previous_semantic_step": 1,
                    "ordered_previous_applied_corrections": [
                        {
                            "actuator_id": actuator_id,
                            "applied_position_delta_rad": 0.01,
                            "applied_velocity_delta_rad_s": -0.01,
                        }
                        for actuator_id in actuator_ids
                    ],
                },
            }
        )
        self.assertEqual(receipt["semantic_step"], 2)
        self.assertTrue(receipt["any_magnitude_saturation"])
        self.assertTrue(receipt["any_slew_limiting"])
        self.assertFalse(receipt["fallback_applied"])
        self.assertEqual(
            [
                correction["actuator_id"]
                for correction in receipt["ordered_applied_corrections"]
            ],
            actuator_ids,
        )
        for correction in receipt["ordered_applied_corrections"]:
            self.assertAlmostEqual(
                correction["applied_position_delta_rad"],
                0.03,
            )
            self.assertAlmostEqual(
                correction["applied_velocity_delta_rad_s"],
                -0.05,
            )
        self.assertFalse(receipt["adapter_actuation_applied"])
        self.assertFalse(receipt["physics_state_modified"])
        self.assertFalse(receipt["physical_acceptance_authority"])

    def test_scaled_stability_influence_v3_crosses_real_dynamic_library(
        self,
    ) -> None:
        descriptor = reference_quadruped("python_influence_v3")
        actuator_ids = self.core.compile_bounded_quadruped(descriptor)["morphology"][
            "ordered_actuator_ids"
        ]

        def request(scale: float) -> dict[str, object]:
            return {
                "schema_version": (
                    "sporespore_bound_stability_influence_request_v3"
                ),
                "descriptor": descriptor,
                "request": {
                    "schema_version": (
                        "sporespore_stability_influence_request_v3"
                    ),
                    "semantic_step": 2,
                    "availability": "available",
                    "global_requested_correction_scale": scale,
                    "maximum_absolute_position_delta_rad": 0.10,
                    "maximum_absolute_velocity_delta_rad_s": 0.20,
                    "maximum_position_delta_slew_per_step_rad": 0.02,
                    "maximum_velocity_delta_slew_per_step_rad_s": 0.04,
                    "ordered_requested_corrections": [
                        {
                            "actuator_id": actuator_id,
                            "requested_position_delta_rad": 0.50,
                            "requested_velocity_delta_rad_s": -0.50,
                        }
                        for actuator_id in actuator_ids
                    ],
                    "previous_semantic_step": 1,
                    "ordered_previous_applied_corrections": [
                        {
                            "actuator_id": actuator_id,
                            "applied_position_delta_rad": 0.01,
                            "applied_velocity_delta_rad_s": -0.01,
                        }
                        for actuator_id in actuator_ids
                    ],
                },
            }

        receipt = self.core.bound_stability_influence_v3(request(0.25))
        self.assertEqual(
            receipt["schema_version"],
            "sporespore_stability_influence_receipt_v3",
        )
        self.assertEqual(receipt["global_requested_correction_scale"], 0.25)
        self.assertTrue(receipt["global_scale_applied_before_magnitude_and_slew"])
        self.assertTrue(receipt["any_nonzero_raw_request"])
        self.assertTrue(receipt["any_nonzero_scaled_request"])
        self.assertTrue(receipt["any_magnitude_saturation"])
        self.assertTrue(receipt["any_slew_limiting"])
        self.assertEqual(
            [
                correction["actuator_id"]
                for correction in receipt["ordered_applied_corrections"]
            ],
            actuator_ids,
        )
        for correction in receipt["ordered_applied_corrections"]:
            self.assertAlmostEqual(
                correction["raw_requested_position_delta_rad"],
                0.50,
            )
            self.assertAlmostEqual(
                correction["scaled_requested_position_delta_rad"],
                0.125,
            )
            self.assertAlmostEqual(
                correction["raw_requested_velocity_delta_rad_s"],
                -0.50,
            )
            self.assertAlmostEqual(
                correction["scaled_requested_velocity_delta_rad_s"],
                -0.125,
            )
            self.assertAlmostEqual(
                correction["applied_position_delta_rad"],
                0.03,
            )
            self.assertAlmostEqual(
                correction["applied_velocity_delta_rad_s"],
                -0.05,
            )

        control = self.core.bound_stability_influence_v3(request(0.0))
        self.assertTrue(control["any_nonzero_raw_request"])
        self.assertFalse(control["any_nonzero_scaled_request"])
        for correction in control["ordered_applied_corrections"]:
            self.assertEqual(
                correction["scaled_requested_position_delta_rad"],
                0.0,
            )
            self.assertEqual(
                correction["scaled_requested_velocity_delta_rad_s"],
                -0.0,
            )
            self.assertEqual(correction["applied_position_delta_rad"], 0.0)
            self.assertEqual(correction["applied_velocity_delta_rad_s"], 0.0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
