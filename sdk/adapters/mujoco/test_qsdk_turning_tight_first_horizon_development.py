from __future__ import annotations

import unittest
from pathlib import Path
from unittest.mock import patch

from sporespore_mujoco_adapter import (
    qsdk_turning_tight_first_development as v1_wrapper,
)
from sporespore_mujoco_adapter import (
    qsdk_turning_tight_first_horizon_development as wrapper,
)


class TightFirstHorizonMujocoDevelopmentTests(unittest.TestCase):
    def test_preflight_binds_horizon_and_keeps_production_closed(self) -> None:
        receipt = wrapper.preflight("0" * 40)
        self.assertEqual(
            receipt["candidate_id"], "tight_gated_acquisition_active600_v2"
        )
        self.assertEqual(receipt["oracle"]["predicted_confirmation_active_index"], 579)
        self.assertEqual(receipt["oracle"]["predicted_passive_steps"], 380)
        self.assertEqual(
            receipt["frozen_r23d13_production_refusal"], "QSDK_R23D13_MJC_CLOSED"
        )
        self.assertEqual(receipt["world_build_count"], 0)
        self.assertFalse(receipt["validation_authority"])

    def test_v2_uses_same_bounded_screen_conjunction(self) -> None:
        self.assertIs(wrapper.base._screen_conjunction, v1_wrapper._screen_conjunction)
        self.assertEqual(wrapper.candidate.TERMINAL_STEPS, 960)
        self.assertEqual(wrapper.candidate.MAXIMUM_ACTIVE_STEPS, 600)

    def test_horizon_injection_is_restored_after_failure(self) -> None:
        frozen = wrapper.base.frozen_worker
        original_contract = frozen._contract
        original_terminal_steps = frozen.terminal.TERMINAL_STEPS
        original_maximum_active_steps = frozen.terminal.MAXIMUM_ACTIVE_STEPS
        original_design_terminal_steps = frozen.design.TERMINAL_STEPS
        original_observer = frozen.terminal.observe_completed_step
        output = wrapper.base._durable_development_root() / "unit-test-v2-restoration"
        with patch.object(
            wrapper.base, "_validated_new_output_root", return_value=output
        ):
            with patch.object(
                frozen, "run_physical", side_effect=RuntimeError("expected_test_failure")
            ):
                with patch.object(Path, "write_text", return_value=1):
                    with self.assertRaises(RuntimeError):
                        wrapper.run_development(
                            arm_id="positive_heading",
                            source_commit="0" * 40,
                            output_root=output,
                        )
        self.assertIs(frozen._contract, original_contract)
        self.assertEqual(frozen.terminal.TERMINAL_STEPS, original_terminal_steps)
        self.assertEqual(
            frozen.terminal.MAXIMUM_ACTIVE_STEPS, original_maximum_active_steps
        )
        self.assertEqual(frozen.design.TERMINAL_STEPS, original_design_terminal_steps)
        self.assertIs(frozen.terminal.observe_completed_step, original_observer)


if __name__ == "__main__":
    unittest.main()
