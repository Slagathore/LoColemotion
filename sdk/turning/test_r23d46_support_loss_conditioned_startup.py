from __future__ import annotations

import ast
from pathlib import Path
import unittest

import r23d45_support_loss_conditioned_startup as parent
import r23d46_support_loss_conditioned_startup as design


REPO_ROOT = Path(__file__).resolve().parents[2]
INHERITED_WORKER = (
    REPO_ROOT
    / "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d3_phase_balanced.py"
)


def inherited_design_dependencies() -> set[str]:
    tree = ast.parse(INHERITED_WORKER.read_text(encoding="utf-8"))
    return {
        node.attr
        for node in ast.walk(tree)
        if isinstance(node, ast.Attribute)
        and isinstance(node.value, ast.Name)
        and node.value.id == "design"
    }


class R23D46SupportLossConditionedStartupTest(unittest.TestCase):
    def test_campaign_is_distinct_but_scientific_candidate_is_unchanged(self) -> None:
        self.assertNotEqual(design.CAMPAIGN_ID, parent.CAMPAIGN_ID)
        self.assertNotEqual(design.GATE_ID, parent.GATE_ID)
        self.assertEqual(design.POLICY_ID, parent.POLICY_ID)
        self.assertEqual(design.CANDIDATE_ID, parent.CANDIDATE_ID)
        self.assertEqual(design.CAMPAIGN_SEED, parent.CAMPAIGN_SEED)
        self.assertEqual(design.INITIAL_PERTURBATION, parent.INITIAL_PERTURBATION)

    def test_complete_inherited_design_interface_is_exported(self) -> None:
        required = inherited_design_dependencies()
        missing = sorted(name for name in required if not hasattr(design, name))
        self.assertEqual(missing, [])
        self.assertIn("PHASE_OFFSETS", required)
        self.assertEqual(design.PHASE_OFFSETS, (0, 90, 180, 270))

    def test_support_loss_transform_is_byte_for_byte_parent_behavior(self) -> None:
        current = design.SupportLossConditionedStartup()
        previous = parent.SupportLossConditionedStartup()
        for step in range(400):
            support = (4, 4, 2, 0)[step] if step < 4 else 4
            contacts = {
                limb_id: index < support
                for index, limb_id in enumerate(design.LIMB_IDS)
            }
            self.assertEqual(
                current.step(step, contacts),
                previous.step(step, contacts),
            )

    def test_complete_inherited_cell_helpers_are_deterministic(self) -> None:
        item = design.cells()[0]
        self.assertEqual(design.stage_a_cells(), [item])
        self.assertEqual(design.stage_b_cells("onset_600"), [item])
        self.assertEqual(design.stage_b_cells("wrong"), [])
        self.assertEqual(
            design.expected_segment_counts(item),
            {"reference_walk": design.CONTROLLER_STEPS},
        )


if __name__ == "__main__":
    unittest.main()
