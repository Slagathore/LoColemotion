from __future__ import annotations

from copy import deepcopy
from pathlib import Path
import unittest

from sdk.python.sporespore_locomotion import LocomotionCore

from .sporespore_mujoco_adapter.recovery_energy_v2_mapping import (
    MAPPING_PROFILE_ID,
    PORTABLE_OBSERVATION_V2_SCHEMA,
    RecoveryEnergyV2MappingError,
    map_r24d36_components_to_recovery_observation_v2,
)
from .sporespore_mujoco_adapter.recovery_energy_v2_mapping_fixture import (
    synthetic_r24d38_mapping_request_v1,
)


SDK_ROOT = Path(__file__).resolve().parents[2]
CORE_LIBRARY = SDK_ROOT / "target/debug/sporespore_locomotion_core.dll"


class RecoveryEnergyV2MappingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.core = LocomotionCore(CORE_LIBRARY)

    def test_signed_components_map_in_order_and_publish_observation_v2(self) -> None:
        receipt = map_r24d36_components_to_recovery_observation_v2(
            self.core,
            synthetic_r24d38_mapping_request_v1(),
        )
        increments = receipt["ordered_increments"]
        ledger = receipt["ledger_aggregation_receipt"]["ledger"]

        self.assertEqual(receipt["support_status"], "supported_exact")
        self.assertEqual(receipt["mapping_profile_id"], MAPPING_PROFILE_ID)
        self.assertEqual(receipt["native_component_batch_count"], 2)
        self.assertEqual(receipt["native_component_receipt_count"], 10)
        self.assertEqual(
            [item["sequence_index"] for item in increments],
            list(range(10)),
        )
        self.assertEqual(
            [item["semantic_step"] for item in increments],
            ([12] * 5) + ([13] * 5),
        )
        constraints = [item["signed_constraint_exchange_j"] for item in increments]
        self.assertTrue(any(value > 0.0 for value in constraints))
        self.assertTrue(any(value < 0.0 for value in constraints))
        self.assertEqual(ledger["source_profile_id"], MAPPING_PROFILE_ID)
        self.assertEqual(ledger["cumulative_signed_external_work_j"], 0.0)
        self.assertEqual(ledger["cumulative_passive_dissipation_j"], 0.0)
        self.assertAlmostEqual(
            receipt["ledger_aggregation_receipt"]["evaluation"]["signed_residual_j"],
            0.0,
        )
        observation = receipt["portable_observation"]
        self.assertEqual(
            observation["schema_version"],
            PORTABLE_OBSERVATION_V2_SCHEMA,
        )
        self.assertEqual(observation["energy_balance"], ledger)
        self.assertNotIn("legacy_observation", observation)
        self.assertEqual(receipt["model_construction_count"], 0)
        self.assertEqual(receipt["world_build_count"], 0)
        self.assertEqual(receipt["solver_step_count"], 0)
        self.assertFalse(receipt["physical_acceptance_authority"])

    def test_mutation_reordering_and_incomplete_receipts_fail_closed(self) -> None:
        mutated = synthetic_r24d38_mapping_request_v1()
        mutated["ordered_native_component_batches"][0]["ordered_substep_receipts"][0][
            "implicit_v3"
        ]["centered_constraint_work_j"] += 0.125
        with self.assertRaisesRegex(
            RecoveryEnergyV2MappingError,
            "QSDK_R24D38_IMPLICIT_COMPONENT_REPLAY_MISMATCH",
        ):
            map_r24d36_components_to_recovery_observation_v2(self.core, mutated)

        reordered = synthetic_r24d38_mapping_request_v1()
        substeps = reordered["ordered_native_component_batches"][0][
            "ordered_substep_receipts"
        ]
        substeps[0], substeps[1] = substeps[1], substeps[0]
        with self.assertRaisesRegex(
            RecoveryEnergyV2MappingError,
            "QSDK_R24D38_SUBSTEP_IDENTITY_INVALID",
        ):
            map_r24d36_components_to_recovery_observation_v2(self.core, reordered)

        incomplete = synthetic_r24d38_mapping_request_v1()
        del incomplete["ordered_native_component_batches"][0][
            "ordered_substep_receipts"
        ][0]["portable_v3_energy_preprojection"]
        with self.assertRaisesRegex(
            RecoveryEnergyV2MappingError,
            "QSDK_R24D38_SUBSTEP_FIELDS_INVALID",
        ):
            map_r24d36_components_to_recovery_observation_v2(self.core, incomplete)

    def test_unqualified_passive_or_external_work_returns_typed_refusal(self) -> None:
        passive = map_r24d36_components_to_recovery_observation_v2(
            self.core,
            synthetic_r24d38_mapping_request_v1(centered_damper_force=1.0),
        )
        self.assertEqual(passive["support_status"], "unsupported_capability")
        self.assertEqual(
            passive["refusal_reason"],
            "nonzero_unqualified_passive_work",
        )
        self.assertIsNone(passive["ledger_aggregation_receipt"])
        self.assertIsNone(passive["portable_observation"])

        external = map_r24d36_components_to_recovery_observation_v2(
            self.core,
            synthetic_r24d38_mapping_request_v1(external_intervention_count=1),
        )
        self.assertEqual(external["support_status"], "unsupported_capability")
        self.assertEqual(
            external["refusal_reason"],
            "nonzero_external_intervention_work_unmeasured",
        )
        self.assertIsNone(external["ledger_sha256"])
        self.assertEqual(external["model_construction_count"], 0)

    def test_source_and_passthrough_observation_digests_are_independent(self) -> None:
        baseline_request = synthetic_r24d38_mapping_request_v1()
        baseline = map_r24d36_components_to_recovery_observation_v2(
            self.core,
            baseline_request,
        )
        changed_request = deepcopy(baseline_request)
        changed_request["observation_base"]["state"]["zero_world_fixture"] = "changed"
        changed = map_r24d36_components_to_recovery_observation_v2(
            self.core,
            changed_request,
        )
        self.assertEqual(
            baseline["source_component_receipts_sha256"],
            changed["source_component_receipts_sha256"],
        )
        self.assertEqual(baseline["ledger_sha256"], changed["ledger_sha256"])
        self.assertNotEqual(
            baseline["observation_base_sha256"],
            changed["observation_base_sha256"],
        )
        self.assertNotEqual(
            baseline["portable_observation_sha256"],
            changed["portable_observation_sha256"],
        )


if __name__ == "__main__":
    unittest.main()
