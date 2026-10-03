from __future__ import annotations

from pathlib import Path
import sys
import unittest


ADAPTER_ROOT = Path(__file__).resolve().parent
SDK_ROOT = ADAPTER_ROOT.parents[1]
TURNING_ROOT = SDK_ROOT / "turning"
for path in (ADAPTER_ROOT, TURNING_ROOT):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from sporespore_mujoco_adapter import qsdk_r23d10_quiescent_taper as native
import r23d10_quiescent_taper as oracle


class R23D10MujocoTemporalMirrorTests(unittest.TestCase):
    def _compare(self, rows: list[oracle.Observation]) -> None:
        native_rows = [
            native.Observation(
                row.contacts,
                row.torso_tilt_rad,
                row.maximum_absolute_joint_position_error_rad,
            )
            for row in rows
        ]
        self.assertEqual(native.simulate(native_rows), oracle.simulate(rows))

    def test_all_five_frozen_paths_match_oracle_exactly(self) -> None:
        supported = (True, True, True, True)
        partial = (True, True, True, False)
        tight = oracle.Observation(supported, 0.005, 0.18)
        coarse = oracle.Observation(supported, 0.03, 0.30)
        partial_tight = oracle.Observation(partial, 0.005, 0.18)
        paths = [
            [tight] * 900,
            [partial_tight] * 313 + [tight] * 587,
            [partial_tight] * 10
            + [tight] * 51
            + [partial_tight]
            + [tight] * 838,
            [coarse] * 900,
            [tight] * 500 + [partial_tight] + [tight] * 399,
        ]
        for rows in paths:
            with self.subTest(first_tilt=rows[0].torso_tilt_rad):
                self._compare(rows)

    def test_native_canaries_and_mutations_execute(self) -> None:
        self.assertEqual(native.run_zero_world_preflight(), (5, 16))

    def test_declared_cells_and_physical_claims_are_fail_closed(self) -> None:
        for stage, arms in (
            ("mujoco_quiescent_taper_screen", ("positive_heading", "negative_heading")),
            ("three_engine_confirmation", ("reference_zero", "positive_heading", "negative_heading")),
        ):
            for arm in arms:
                receipt = native.preflight(stage, arm)
                self.assertEqual(receipt["oracle_canary_count"], 5)
                self.assertEqual(receipt["mutation_control_count"], 16)
                self.assertTrue(receipt["physical_worker_implemented"])
                self.assertTrue(
                    receipt["physical_worker_dormant_behind_supervisor_authorization"]
                )
                self.assertEqual(receipt["fixed_total_trace_step_count"], 3_892)
                self.assertEqual(receipt["model_construction_count"], 0)
                self.assertEqual(receipt["world_build_count"], 0)


if __name__ == "__main__":
    unittest.main()
