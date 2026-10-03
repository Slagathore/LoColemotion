from __future__ import annotations

import copy
import tempfile
import unittest
from pathlib import Path

try:
    from sporespore_locomotion import (
        LocomotionCore,
        LocomotionCoreError,
        SELECTED_BALANCED_WAVE_POLICY_ID,
    )
except ImportError:
    from python.sporespore_locomotion import (
        LocomotionCore,
        LocomotionCoreError,
        SELECTED_BALANCED_WAVE_POLICY_ID,
    )

from .conformance import (
    ConformanceFailure,
    _retain_report,
    run_adapter_authoring_conformance,
)
from .reference_adapter import ReferenceHostAdapter


class AdapterAuthoringConformanceTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.core = LocomotionCore()

    def test_complete_a0_a6_report(self) -> None:
        report = run_adapter_authoring_conformance()
        self.assertTrue(report["ok"])
        self.assertEqual(report["passed_cells"], 7)
        self.assertEqual(report["failed_cells"], 0)
        self.assertEqual(
            [cell["cell_id"] for cell in report["cells"]],
            [
                "a0_contract",
                "a1_named_policy",
                "a2_order_and_time",
                "a3_applied_feedback",
                "a4_safe_zero",
                "a5_negative_paths",
                "a6_import_boundary",
            ],
        )
        self.assertTrue(
            report["third_party_fixture_uses_public_surfaces_only"]
        )
        self.assertFalse(report["legacy_unnamed_entrypoint_used"])
        self.assertEqual(report["world_build_count"], 0)
        self.assertFalse(report["walking_acceptance"])
        self.assertFalse(report["physical_acceptance_authority"])

    def test_reference_loop_is_byte_deterministic(self) -> None:
        first = ReferenceHostAdapter(self.core)
        second = ReferenceHostAdapter(self.core)
        first_result = first.advance()
        second_result = second.advance()
        self.assertEqual(
            first_result["controller_output"],
            second_result["controller_output"],
        )
        self.assertEqual(
            first_result["adapter_receipt"],
            second_result["adapter_receipt"],
        )
        self.assertEqual(
            first_result["adapter_receipt_sha256"],
            second_result["adapter_receipt_sha256"],
        )

    def test_report_retention_is_atomic_and_immutable(self) -> None:
        report = run_adapter_authoring_conformance()
        with tempfile.TemporaryDirectory(
            prefix="sporespore_adapter_kit_"
        ) as temporary:
            report_path = Path(temporary) / "report.json"
            _retain_report(report, report_path)
            self.assertTrue(report_path.is_file())
            self.assertFalse(report_path.with_name("report.json.tmp").exists())
            with self.assertRaises(ConformanceFailure):
                _retain_report(report, report_path)
            with self.assertRaises(ConformanceFailure):
                _retain_report(report, Path(temporary) / "renamed.json")

    def test_selected_policy_is_explicit_and_unknown_policy_fails(self) -> None:
        adapter = ReferenceHostAdapter(self.core)
        result = adapter.advance()
        self.assertEqual(
            result["controller_output"]["actuation"]["receipt"]["policy_id"],
            SELECTED_BALANCED_WAVE_POLICY_ID,
        )
        with self.assertRaises(LocomotionCoreError) as raised:
            self.core.balanced_wave_policy_profile(
                "sporespore_unknown_policy_v1",
                adapter.descriptor,
            )
        self.assertEqual(raised.exception.failure_code, "IDENTITY_INVALID")

    def test_unknown_contacts_preserve_safe_zero(self) -> None:
        adapter = ReferenceHostAdapter(self.core)
        adapter.advance()
        safe = adapter.advance(contacts_available=False)
        actuation = safe["controller_output"]["actuation"]
        self.assertTrue(actuation["safe_no_actuation"])
        self.assertTrue(
            all(
                command["target_velocity_rad_s"] == 0.0
                and command["residual_contribution_rad_s"] == 0.0
                and command["safety_contribution_rad_s"] == 0.0
                for command in actuation["ordered_commands"]
            )
        )
        self.assertTrue(
            safe["adapter_receipt"]["safe_no_actuation_preserved"]
        )

    def test_reordered_or_stale_host_state_fails_closed(self) -> None:
        adapter = ReferenceHostAdapter(self.core)
        reordered = adapter.build_step_request(0)
        reordered["state"]["ordered_joint_observations"].reverse()
        order_output = self.core.balanced_wave_policy_step(
            SELECTED_BALANCED_WAVE_POLICY_ID,
            reordered,
        )
        self.assertTrue(order_output["actuation"]["safe_no_actuation"])
        self.assertEqual(
            order_output["actuation"]["failure_codes"],
            ["ORDER_INVALID"],
        )

        first = adapter.advance()
        stale_previous = copy.deepcopy(
            first["previous_applied_actuation"]
        )
        stale_previous["source_semantic_step"] = 1
        stale = adapter.build_step_request(
            1,
            previous_applied_actuation=stale_previous,
        )
        time_output = self.core.balanced_wave_policy_step(
            SELECTED_BALANCED_WAVE_POLICY_ID,
            stale,
        )
        self.assertTrue(time_output["actuation"]["safe_no_actuation"])
        self.assertEqual(
            time_output["actuation"]["failure_codes"],
            ["TIME_INVALID"],
        )


if __name__ == "__main__":
    unittest.main()
