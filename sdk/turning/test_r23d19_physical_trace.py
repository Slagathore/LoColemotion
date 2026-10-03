from __future__ import annotations

import copy
from pathlib import Path
import sys

import pytest

MODULE_ROOT = Path(__file__).resolve().parent
if str(MODULE_ROOT) not in sys.path:
    sys.path.insert(0, str(MODULE_ROOT))

import r23d19_physical_evaluator as evaluator
import r23d19_physical_trace as design


def test_declared_screen_is_exact_three_cell_godot_order() -> None:
    cells = design.matrix_cells()
    assert [cell.cell_id for cell in cells] == [
        "godot_jolt__tight_gated_horizon__reference_zero",
        "godot_jolt__tight_gated_horizon__positive_heading",
        "godot_jolt__tight_gated_horizon__negative_heading",
    ]
    receipt = design.zero_world_receipt()
    assert receipt["matrix_cell_count"] == 3
    assert receipt["trace_row_count_per_cell"] == 3952
    assert receipt["controller_policy_id"] == design.CONTROLLER_POLICY_ID
    assert receipt["cross_track_frame_mode_id"] == design.CROSS_TRACK_FRAME_MODE_ID
    assert receipt["world_build_count"] == 0


def test_path_diagnostics_are_finite_only_during_controller_horizon() -> None:
    cell = design.matrix_cells()[1]
    rows = design.synthetic_trace(cell)
    assert design.validate_trace(cell, rows)["ok"]
    for field in design.R23D19_CONTROLLER_DIAGNOSTIC_FIELDS:
        assert isinstance(rows[600][field], float)
        assert rows[design.CONTROLLER_STEPS][field] is None

    missing_controller_value = copy.deepcopy(rows)
    missing_controller_value[600]["cross_track_error_m"] = None
    result = design.validate_trace(cell, missing_controller_value)
    assert not result["ok"]
    assert "R23D19_PATH_DIAGNOSTIC:600:cross_track_error_m" in result["failure_codes"]

    terminal_leak = copy.deepcopy(rows)
    terminal_leak[design.CONTROLLER_STEPS]["held_steering_fraction"] = 0.0
    result = design.validate_trace(cell, terminal_leak)
    assert not result["ok"]
    assert (
        "R23D19_TERMINAL_PATH_DIAGNOSTIC:2992:held_steering_fraction"
        in result["failure_codes"]
    )


@pytest.mark.parametrize(
    ("yaw_by_arm", "expected_classification", "expected_conditioned"),
    [
        (
            {
                "reference_zero": 0.0,
                "positive_heading": 0.03,
                "negative_heading": -0.03,
            },
            "valid_complete_positive",
            True,
        ),
        (
            {
                "reference_zero": -0.12,
                "positive_heading": -0.107,
                "negative_heading": -0.052,
            },
            "valid_complete_negative",
            False,
        ),
    ],
)
def test_complete_screen_requires_command_conditioned_separation(
    monkeypatch: pytest.MonkeyPatch,
    yaw_by_arm: dict[str, float],
    expected_classification: str,
    expected_conditioned: bool,
) -> None:
    def fake_evaluate_entry(entry, cell, **_kwargs):
        yaw = yaw_by_arm[cell.arm_id]
        absolute_passed = (
            cell.arm_id == "reference_zero"
            or (cell.arm_id == "positive_heading" and yaw >= 0.01)
            or (cell.arm_id == "negative_heading" and yaw <= -0.01)
        )
        return {
            "entry_valid": True,
            "failure_codes": [],
            "outcome": {
                "turn_phase_yaw_delta_rad": yaw,
                "outcome_gate_passed": absolute_passed,
            },
            "world_attempt_count": 1,
            "world_build_count": 1,
        }

    monkeypatch.setattr(evaluator, "evaluate_entry", fake_evaluate_entry)
    entries = [{"cell_id": cell.cell_id} for cell in design.matrix_cells()]
    result = evaluator.evaluate_complete_entries(
        entries,
        expected_source_commit="0" * 40,
        allow_test_artifacts=True,
    )
    assert result["classification"] == expected_classification
    assert result["matrix_valid"]
    assert (
        result["command_conditioned_response"]["conditioned_response_gate_passed"]
        is expected_conditioned
    )
    assert result["claims"]["portable_basic_turning"] is False
    assert result["claims"]["cross_engine_equivalence"] is False


def test_evaluator_loads_exact_frozen_declaration() -> None:
    evaluator._load_declaration()
