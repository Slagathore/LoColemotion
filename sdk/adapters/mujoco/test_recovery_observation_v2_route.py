from __future__ import annotations

from copy import deepcopy
from pathlib import Path
import unittest

from sdk.python.sporespore_locomotion import LocomotionCore, LocomotionCoreError

from .sporespore_mujoco_adapter.recovery_observation_v2_route import (
    IN_RUN_INVARIANT_RECEIPT_SCHEMA,
    PUBLICATION_RECEIPT_SCHEMA,
    RecoveryObservationV2PublicationError,
    publish_recovery_observation_v2,
    validate_recovery_observation_v2_in_run_invariants_v1,
)
from .sporespore_mujoco_adapter.recovery_observation_v2_route_fixture import (
    synthetic_r24d39_evaluation_request_v3,
    synthetic_r24d39_initialize_request_v2,
    synthetic_r24d39_publication_arguments_v1,
    synthetic_r24d39_step_request_v3,
    synthetic_r24d40_native_invariant_case_v1,
)
from .sporespore_mujoco_adapter.recovery_runtime import plan_control_v3


SDK_ROOT = Path(__file__).resolve().parents[2]
CORE_LIBRARY = SDK_ROOT / "target/debug/sporespore_locomotion_core.dll"


class RecoveryObservationV2RouteTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.core = LocomotionCore(CORE_LIBRARY)

    def publish(self, **fixture_overrides: object) -> dict[str, object]:
        arguments = synthetic_r24d39_publication_arguments_v1(self.core)
        arguments.update(fixture_overrides)
        return publish_recovery_observation_v2(self.core, **arguments)

    def test_complete_route_publishes_source_bound_observation_v2(self) -> None:
        publication = self.publish()
        collection = publication["collection_receipt"]
        observation = publication["portable_observation"]

        self.assertEqual(publication["schema_version"], PUBLICATION_RECEIPT_SCHEMA)
        self.assertEqual(publication["support_status"], "supported_exact")
        self.assertTrue(publication["portable_observation_published"])
        self.assertEqual(
            observation["schema_version"],
            "sporespore_recovery_observation_v2",
        )
        self.assertNotEqual(
            observation["energy_balance"]["cumulative_signed_constraint_exchange_j"],
            0.0,
        )
        self.assertEqual(
            collection["schema_version"],
            "sporespore_recovery_native_collection_receipt_v2",
        )
        self.assertEqual(collection["support_status"], "supported_exact")
        self.assertEqual(
            collection["observation_sha256"],
            publication["portable_observation_sha256"],
        )
        self.assertIsNotNone(publication["observation_source_binding_sha256"])
        for value in (publication, collection):
            self.assertEqual(value["model_construction_count"], 0)
            self.assertEqual(value["world_attempt_count"], 0)
            self.assertEqual(value["world_build_count"], 0)
            self.assertEqual(value["solver_step_count"], 0)
            self.assertFalse(value["physics_state_modified"])
            self.assertFalse(value["physical_acceptance_authority"])
            self.assertFalse(value["release_authority"])

        repeated = self.publish()
        self.assertEqual(
            publication["mapping_receipt_sha256"],
            repeated["mapping_receipt_sha256"],
        )
        self.assertEqual(
            publication["portable_observation_sha256"],
            repeated["portable_observation_sha256"],
        )

    def test_binding_mutation_and_v1_consumer_fail_closed(self) -> None:
        publication = self.publish()
        request = deepcopy(publication["collection_request"])
        request["observation_source_binding"]["ledger_sha256"] = "sha256:" + ("f" * 64)
        refusal = self.core.recovery_collect_native_v3(request)
        self.assertEqual(refusal["support_status"], "invalid_observation")
        self.assertEqual(
            refusal["refusal_reason"],
            "observation_v2_source_binding_mismatch",
        )
        self.assertEqual(refusal["solver_step_count"], 0)

        legacy = deepcopy(publication["collection_request"])
        legacy["schema_version"] = "sporespore_recovery_native_collection_request_v2"
        del legacy["observation_source_binding"]
        with self.assertRaises(LocomotionCoreError):
            self.core.recovery_collect_native_v2(legacy)

    def test_v3_controller_consumes_the_exact_source_bound_request(self) -> None:
        publication = self.publish()
        control = plan_control_v3(
            self.core,
            publication["collection_request"],
            phase_step=0,
        )

        self.assertEqual(control["support_status"], "supported_exact")
        self.assertEqual(control["engine_identity_input_count"], 0)
        self.assertEqual(control["engine_specific_policy_branch_count"], 0)
        self.assertEqual(control["model_construction_count"], 0)
        self.assertEqual(control["world_attempt_count"], 0)
        self.assertEqual(control["world_build_count"], 0)
        self.assertEqual(control["solver_step_count"], 0)
        self.assertFalse(control["physics_state_modified"])
        self.assertFalse(control["physical_acceptance_authority"])
        self.assertFalse(control["release_authority"])

    def test_v3_supervisor_and_evaluator_cross_public_abi_without_physics(
        self,
    ) -> None:
        publication = self.publish()
        initialized = self.core.recovery_initialize_v2(
            synthetic_r24d39_initialize_request_v2(publication)
        )
        step = self.core.recovery_step_v3(
            synthetic_r24d39_step_request_v3(
                publication,
                memory=initialized["memory"],
            )
        )
        evaluation = self.core.recovery_evaluate_trace_v3(
            synthetic_r24d39_evaluation_request_v3(self.core, publication)
        )

        self.assertEqual(initialized["support_status"], "supported_exact")
        self.assertFalse(initialized["physical_question_opened"])
        self.assertEqual(step["support_status"], "supported_exact")
        self.assertEqual(step["classification"]["energy_balance_residual_j"], 0.0)
        self.assertEqual(evaluation["support_status"], "supported_exact")
        self.assertEqual(
            evaluation["schema_version"],
            "sporespore_recovery_evaluation_receipt_v1",
        )
        self.assertEqual(evaluation["verdict"], "synthetic_canary_failed")
        self.assertTrue(evaluation["initial_state_identity_matched"])
        self.assertEqual(
            evaluation["candidate_trace"]["accepted_observation_count"],
            1,
        )
        self.assertEqual(
            evaluation["matched_zero_command_trace"]["accepted_observation_count"],
            1,
        )
        for value in (step, evaluation):
            self.assertEqual(value["world_build_count"], 0)
            self.assertEqual(value["solver_step_count"], 0)
            self.assertFalse(value["physics_state_modified"])
            self.assertFalse(value["physical_result"])
            self.assertFalse(value["prone_to_standing_claimed"])
            self.assertFalse(value["physical_acceptance_authority"])
            self.assertFalse(value["release_authority"])

    def test_mapping_typed_refusal_stops_before_collection_or_publication(self) -> None:
        arguments = synthetic_r24d39_publication_arguments_v1(self.core)
        arguments["mapping_request"]["observation_base"]["external_interventions"][
            "root_force_application_count"
        ] = 1
        publication = publish_recovery_observation_v2(self.core, **arguments)
        self.assertEqual(publication["support_status"], "unsupported_capability")
        self.assertEqual(
            publication["refusal_reason"],
            "nonzero_external_intervention_work_unmeasured",
        )
        self.assertIsNone(publication["collection_request"])
        self.assertIsNone(publication["collection_receipt"])
        self.assertFalse(publication["portable_observation_published"])
        self.assertEqual(publication["solver_step_count"], 0)

    def test_native_in_run_invariants_replay_both_paired_arms(self) -> None:
        for arm_kind in ("candidate_command", "matched_zero_command"):
            case = synthetic_r24d40_native_invariant_case_v1(
                self.core,
                arm_kind=arm_kind,
            )
            receipt = validate_recovery_observation_v2_in_run_invariants_v1(
                self.core,
                **case,
            )
            self.assertEqual(
                receipt["schema_version"],
                IN_RUN_INVARIANT_RECEIPT_SCHEMA,
            )
            self.assertEqual(receipt["arm_kind"], arm_kind)
            self.assertEqual(receipt["validated_native_substep_count"], 5)
            self.assertTrue(receipt["publication_replayed_exact"])
            self.assertTrue(receipt["all_numbers_finite"])
            self.assertFalse(receipt["prone_to_standing_claimed"])

    def test_native_in_run_invariant_mutations_fail_closed(self) -> None:
        base = synthetic_r24d40_native_invariant_case_v1(self.core)
        mutations = []
        reversed_time = deepcopy(base)
        reversed_time["native_step"]["time_after_s"] = -1.0
        mutations.append(reversed_time)
        wrong_solver_count = deepcopy(base)
        wrong_solver_count["native_step"]["solver_step_count_after"] = 4
        mutations.append(wrong_solver_count)
        wrong_batch_step = deepcopy(base)
        wrong_batch_step["ordered_native_component_batches"][0]["semantic_step"] = 1
        mutations.append(wrong_batch_step)
        broken_binding = deepcopy(base)
        broken_binding["publication"]["portable_observation"]["engine_step_identity"][
            "source_trace_sha256"
        ] = "sha256:" + ("f" * 64)
        mutations.append(broken_binding)
        nonfinite = deepcopy(base)
        nonfinite["native_step"]["time_after_s"] = float("nan")
        mutations.append(nonfinite)
        for mutation in mutations:
            with self.assertRaises(RecoveryObservationV2PublicationError):
                validate_recovery_observation_v2_in_run_invariants_v1(
                    self.core,
                    **mutation,
                )


if __name__ == "__main__":
    unittest.main()
