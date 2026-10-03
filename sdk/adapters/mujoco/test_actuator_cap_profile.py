from __future__ import annotations

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
    R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
    r23d60_selected_s169_quadruped,
    reference_quadruped,
)
from sporespore_mujoco_adapter.actuator_cap_profile import (  # noqa: E402
    ActuatorCapProfileMappingError,
    map_actuator_cap_profile,
    run_actuator_cap_profile_preflight,
)


CORE_LIBRARY = SDK_ROOT / "target" / "debug" / "sporespore_locomotion_core.dll"


class MuJoCoActuatorCapProfileTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.core = LocomotionCore(CORE_LIBRARY)

    def _exact_receipt(self) -> dict[str, object]:
        return self.core.resolve_actuator_cap_profile_v1(
            R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
            r23d60_selected_s169_quadruped(),
        )

    def test_real_core_receipt_maps_to_eight_zero_world_force_ranges(self) -> None:
        report = run_actuator_cap_profile_preflight(self._exact_receipt())
        self.assertTrue(report["ok"])
        self.assertEqual(report["validated_actuator_count"], 8)
        self.assertEqual(report["xml_fragment_count"], 8)
        self.assertEqual(report["mutation_rejection_count"], 9)
        self.assertEqual(report["mujoco_import_count"], 0)
        self.assertEqual(report["model_construction_count"], 0)
        self.assertEqual(report["world_build_count"], 0)
        self.assertEqual(report["solver_step_count"], 0)
        self.assertFalse(report["physics_state_modified"])
        self.assertFalse(report["turning_claimed"])
        self.assertFalse(report["prone_to_standing_claimed"])
        self.assertFalse(report["cross_engine_equivalence_claimed"])
        self.assertFalse(report["physical_acceptance_authority"])
        self.assertFalse(report["release_authority"])
        self.assertLessEqual(
            report["maximum_outer_step_reconstruction_error_nms"],
            report["maximum_outer_step_reconstruction_budget_nms"],
        )
        for mapping in report["ordered_mappings"]:
            self.assertIn('forcelimited="true"', mapping["velocity_actuator_xml"])
            force_range = mapping["mujoco_symmetric_force_range_nm"]
            self.assertEqual(force_range[0], -force_range[1])

    def test_valid_out_of_domain_and_unknown_profile_receipts_are_refused(self) -> None:
        out_of_domain = self.core.resolve_actuator_cap_profile_v1(
            R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
            reference_quadruped("valid_out_of_domain"),
        )
        self.assertEqual(
            out_of_domain["support_status"],
            "out_of_domain_morphology",
        )
        with self.assertRaises(ActuatorCapProfileMappingError):
            map_actuator_cap_profile(out_of_domain)

        unsupported = self.core.resolve_actuator_cap_profile_v1(
            "unknown_profile",
            r23d60_selected_s169_quadruped(),
        )
        self.assertEqual(unsupported["support_status"], "unsupported_profile")
        with self.assertRaises(ActuatorCapProfileMappingError):
            map_actuator_cap_profile(unsupported)


if __name__ == "__main__":
    unittest.main()
