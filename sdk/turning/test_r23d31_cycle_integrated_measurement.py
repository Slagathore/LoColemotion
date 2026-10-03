from __future__ import annotations

import math
import unittest

import r23d31_cycle_integrated_measurement as oracle


def _wrap(value: float) -> float:
    return math.remainder(value, 2.0 * math.pi)


def _rows(
    arm_id: str,
    *,
    terminal_shift: float,
    phase_rotation_steps: int = 0,
    yaw_origin: float = 0.0,
) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for step in range(oracle.ROW_COUNT):
        oscillator = 0.006 * math.sin(
            2.0 * math.pi * (step + phase_rotation_steps) / oracle.CYCLE_STEPS
        )
        response = terminal_shift if 600 <= step < 1_800 else 0.0
        rows.append(
            {
                "trace_step": step,
                "phase_id": oracle.phase_for_step(step),
                "measured_yaw_rad": _wrap(yaw_origin + oscillator + response),
                "arm_id": arm_id,
            }
        )
    return rows


def _passing_triplet(
    *, phase_rotation_steps: int = 0, yaw_origin: float = 0.0
) -> dict[str, list[dict[str, object]]]:
    return {
        "reference_zero": _rows(
            "reference_zero",
            terminal_shift=0.003,
            phase_rotation_steps=phase_rotation_steps,
            yaw_origin=yaw_origin,
        ),
        "positive_heading": _rows(
            "positive_heading",
            terminal_shift=0.023,
            phase_rotation_steps=phase_rotation_steps,
            yaw_origin=yaw_origin,
        ),
        "negative_heading": _rows(
            "negative_heading",
            terminal_shift=-0.019,
            phase_rotation_steps=phase_rotation_steps,
            yaw_origin=yaw_origin,
        ),
    }


class CycleIntegratedMeasurementTests(unittest.TestCase):
    def test_complete_cycle_is_exact_and_phase_rotation_invariant(self) -> None:
        baseline = oracle.measure_cycle_integrated_response(_passing_triplet())
        rotated = oracle.measure_cycle_integrated_response(
            _passing_triplet(phase_rotation_steps=37)
        )
        self.assertTrue(baseline["passed"])
        self.assertTrue(rotated["passed"])
        self.assertAlmostEqual(
            baseline["positive_reference_conditioned_cycle_shift_rad"],
            0.020,
            places=12,
        )
        self.assertAlmostEqual(
            baseline["negative_reference_conditioned_cycle_shift_rad"],
            0.022,
            places=12,
        )
        self.assertAlmostEqual(
            baseline["positive_reference_conditioned_cycle_shift_rad"],
            rotated["positive_reference_conditioned_cycle_shift_rad"],
            places=12,
        )
        self.assertEqual(
            baseline["measurement_configuration"]["selecting_gate_ids"],
            ["raw_signed_cycle_shift", "reference_conditioned_cycle_shift"],
        )

    def test_wrap_crossing_and_misleading_endpoint_do_not_select_result(self) -> None:
        rows = _passing_triplet(yaw_origin=math.pi - 0.004)
        reference_endpoint_delta = math.remainder(
            float(rows["reference_zero"][1_799]["measured_yaw_rad"])
            - float(rows["reference_zero"][600]["measured_yaw_rad"]),
            2.0 * math.pi,
        )
        rows["negative_heading"][1_799]["measured_yaw_rad"] = _wrap(
            float(rows["negative_heading"][600]["measured_yaw_rad"])
            + reference_endpoint_delta
        )
        result = oracle.measure_cycle_integrated_response(rows)
        self.assertTrue(result["passed"])
        self.assertAlmostEqual(
            result["arms"]["negative_heading"]["legacy_endpoint_yaw_delta_rad"],
            result["arms"]["reference_zero"]["legacy_endpoint_yaw_delta_rad"],
            places=12,
        )

    def test_phase_subwindow_reversal_is_diagnostic_not_selector(self) -> None:
        rows = _passing_triplet()
        start = oracle.TERMINAL_START + oracle.SWING_STEPS
        for step in range(start, start + oracle.SWING_STEPS):
            value = float(rows["positive_heading"][step]["measured_yaw_rad"])
            rows["positive_heading"][step]["measured_yaw_rad"] = _wrap(
                value - 0.03
            )
        result = oracle.measure_cycle_integrated_response(rows)
        self.assertTrue(result["passed"])
        self.assertFalse(
            result["nonselecting_diagnostics"][
                "every_terminal_swing_reference_conditioned_direction"
            ]
        )
        self.assertNotIn(
            "every_terminal_swing_reference_conditioned_direction",
            result["gates"],
        )

    def test_cycle_magnitude_mutations_fail(self) -> None:
        too_small = {
            "reference_zero": _rows("reference_zero", terminal_shift=0.001),
            "positive_heading": _rows("positive_heading", terminal_shift=0.006),
            "negative_heading": _rows("negative_heading", terminal_shift=-0.004),
        }
        result = oracle.measure_cycle_integrated_response(too_small)
        self.assertFalse(result["passed"])
        self.assertFalse(result["gates"]["raw_signed_cycle_shift"])
        self.assertFalse(result["gates"]["reference_conditioned_cycle_shift"])

    def test_synchronization_nonfinite_arm_and_configuration_fail_closed(self) -> None:
        missing = _passing_triplet()
        missing["reference_zero"].pop()
        with self.assertRaises(oracle.CycleIntegratedMeasurementError):
            oracle.measure_cycle_integrated_response(missing)

        reordered = _passing_triplet()
        reordered["positive_heading"][100], reordered["positive_heading"][101] = (
            reordered["positive_heading"][101],
            reordered["positive_heading"][100],
        )
        with self.assertRaises(oracle.CycleIntegratedMeasurementError):
            oracle.measure_cycle_integrated_response(reordered)

        nonfinite = _passing_triplet()
        nonfinite["reference_zero"][300]["measured_yaw_rad"] = math.nan
        with self.assertRaises(oracle.CycleIntegratedMeasurementError):
            oracle.measure_cycle_integrated_response(nonfinite)

        bad_arms = _passing_triplet()
        del bad_arms["negative_heading"]
        with self.assertRaises(oracle.CycleIntegratedMeasurementError):
            oracle.measure_cycle_integrated_response(bad_arms)

        original_end = oracle.TERMINAL_END
        try:
            oracle.TERMINAL_END = original_end - 1
            with self.assertRaises(oracle.CycleIntegratedMeasurementError):
                oracle.measure_cycle_integrated_response(_passing_triplet())
        finally:
            oracle.TERMINAL_END = original_end


if __name__ == "__main__":
    unittest.main()
