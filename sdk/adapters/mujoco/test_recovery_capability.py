from __future__ import annotations

from copy import deepcopy
from pathlib import Path
import sys
import unittest


ADAPTER_ROOT = Path(__file__).resolve().parent
SDK_ROOT = ADAPTER_ROOT.parents[1]
SDK_PYTHON = SDK_ROOT / "python"
for path in (ADAPTER_ROOT, SDK_PYTHON):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from sporespore_locomotion import (  # noqa: E402
    LocomotionCore,
    r23d60_selected_s169_quadruped,
)
from sporespore_mujoco_adapter.recovery_capability import (  # noqa: E402
    ORDERED_CHANNELS,
    RecoveryCapabilityError,
    _validate_local,
    mujoco_recovery_capability_v1,
    run_recovery_capability_preflight,
)


CORE_LIBRARY = SDK_ROOT / "target" / "debug" / "sporespore_locomotion_core.dll"


class MuJoCoRecoveryCapabilityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.core = LocomotionCore(CORE_LIBRARY)

    def test_real_core_initialization_and_mutations_remain_zero_world(self) -> None:
        self.assertNotIn("mujoco", sys.modules)
        report = run_recovery_capability_preflight(
            self.core,
            r23d60_selected_s169_quadruped(),
        )
        self.assertTrue(report["ok"])
        self.assertEqual(report["required_channel_count"], 10)
        self.assertEqual(report["mutation_rejection_count"], 4)
        self.assertTrue(report["force_to_impulse_rule_explicit"])
        self.assertFalse(report["force_sample_relabelled_as_impulse"])
        self.assertEqual(report["mujoco_import_count"], 0)
        self.assertEqual(report["model_construction_count"], 0)
        self.assertEqual(report["world_build_count"], 0)
        self.assertEqual(report["solver_step_count"], 0)
        self.assertFalse(report["prone_to_standing_claimed"])
        self.assertFalse(report["physical_acceptance_authority"])
        self.assertNotIn("mujoco", sys.modules)

    def test_local_surface_rejects_missing_or_synthesized_measurements(self) -> None:
        capability = mujoco_recovery_capability_v1()
        self.assertEqual(
            [item["channel"] for item in capability["ordered_channels"]],
            list(ORDERED_CHANNELS),
        )
        missing = deepcopy(capability)
        missing["ordered_channels"].pop()
        with self.assertRaises(RecoveryCapabilityError):
            _validate_local(missing)
        synthesized = deepcopy(capability)
        synthesized["ordered_channels"][3]["synthesized_when_missing"] = True
        with self.assertRaises(RecoveryCapabilityError):
            _validate_local(synthesized)


if __name__ == "__main__":
    unittest.main()
