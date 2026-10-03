"""Compact source/contract audit for the R24D32 physical successor."""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
SDK_ROOT = ROOT / "sdk"
for path in (SDK_ROOT / "python", SDK_ROOT / "adapters/mujoco", ROOT):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    exact,
    git,
    load,
    require,
    sha256,
)
from sporespore_mujoco_adapter import (  # noqa: E402
    qsdk_r24d32_corrected_energy_progression_worker as worker,
)


DECLARATION_PARENT = "0950cee91b37937ebe8fdc56abfe0e8496e5b861"
GATE_ID = "QSDK-R24D32"
CONTRACT_PATH = SDK_ROOT / "recovery/r24d32_corrected_energy_progression_contract_v1.json"
R24D31_CONTRACT_PATH = (
    SDK_ROOT / "recovery/r24d31_mujoco_energy_ledger_correction_contract_v1.json"
)
R24D31_CLOSURE_PATH = (
    SDK_ROOT
    / "recovery/r24d31_mujoco_energy_ledger_correction_qualification_closure_v1.json"
)
SUPPORT_MATRIX_PATH = SDK_ROOT / "release/quadruped_support_matrix.json"
RELEASE_CONTRACT_PATH = SDK_ROOT / "release/quadruped_release_contract.json"
CLOSURE_DEPENDENCIES = [
    "sdk/recovery/r24d31_mujoco_energy_ledger_correction_qualification_closure_v1.json",
    "tests/test_qsdk_r24d31_mujoco_energy_ledger_correction_qualification_closure.py",
]
NEW_PATHS = [
    "sdk/recovery/r24d32_corrected_energy_progression_contract_v1.json",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/"
    "qsdk_r24d32_corrected_energy_progression_worker.py",
    "tests/test_qsdk_r24d32_corrected_energy_progression_source.py",
    "sdk/run_qsdk_r24d32_corrected_energy_progression_zero_world.ps1",
    "sdk/run_qsdk_r24d32_corrected_energy_progression_development.ps1",
]


def _raw_sha256(path: Path) -> str:
    return sha256(path.read_bytes())


def _load_live_authority(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(value, dict), f"LIVE_AUTHORITY_ROOT:{path}")
    return value


def _find_release_gate(value: dict[str, Any], gate_id: str) -> dict[str, Any]:
    matches = [
        item
        for item in value.get("gates", [])
        if isinstance(item, dict) and item.get("gate_id") == gate_id
    ]
    require(len(matches) == 1, f"RELEASE_GATE_COUNT:{gate_id}")
    return matches[0]


def _blob(relative: str) -> str:
    value = git(ROOT, "hash-object", "--", relative)
    assert isinstance(value, str)
    return value


def _parent_blob(relative: str) -> str:
    value = git(ROOT, "rev-parse", f"{DECLARATION_PARENT}:{relative}")
    assert isinstance(value, str)
    return value


def _absent_at_parent(relative: str) -> bool:
    return (
        subprocess.run(
            ["git", "cat-file", "-e", f"{DECLARATION_PARENT}:{relative}"],
            cwd=ROOT,
            check=False,
            capture_output=True,
        ).returncode
        != 0
    )


def main() -> int:
    contract = worker.load_contract_v1(CONTRACT_PATH)
    predecessor = load(R24D31_CONTRACT_PATH)
    closure = load(R24D31_CLOSURE_PATH)
    exact(contract["declaration_parent_commit"], DECLARATION_PARENT, "PARENT")
    exact(contract["question_class"], "development", "QUESTION_CLASS")
    exact(contract["physical_question_declared"], True, "PHYSICAL_QUESTION")
    for key in (
        "superiority_question_declared",
        "equivalence_or_non_inferiority_question_declared",
        "population_inference_declared",
    ):
        exact(contract[key], False, f"QUESTION_{key.upper()}")

    exact(
        _raw_sha256(R24D31_CLOSURE_PATH),
        contract["lineage"]["energy_correction_closure_raw_sha256"],
        "R24D31_CLOSURE_HASH",
    )
    exact(
        closure["closure_status"],
        contract["lineage"]["energy_correction_result"],
        "R24D31_RESULT",
    )
    exact(closure["qualification"]["controls_passed"], 12, "R24D31_CONTROLS")
    exact(closure["qualification"]["world_attempt_count"], 0, "R24D31_WORLDS")
    exact(closure["predecessor"]["same_identity_rerun_permitted"], False, "R24D30_RERUN")

    change = contract["controlled_change"]
    exact(change["energy_ledger_profile_id"], worker.runtime.ENERGY_LEDGER_PROFILE_ID, "PROFILE")
    for key in (
        "controller_changed",
        "native_physics_changed",
        "native_observer_changed",
        "morphology_changed",
        "initializer_changed",
        "behavior_thresholds_changed",
        "margins_changed",
        "cell_changed",
        "seed_changed",
        "horizon_changed",
        "portable_phase_machine_changed",
        "portable_pose_classifier_changed",
        "progression_evaluator_meaning_changed",
        "held_out_selector_changed",
        "result_interpretation_changed",
    ):
        exact(change[key], False, f"CHANGE_{key.upper()}")

    threshold = contract["threshold_and_adequacy_authority"]
    exact(threshold["maximum_energy_balance_residual_j"], 0.25, "THRESHOLD")
    exact(
        threshold["native_component_identity_tolerance_j"],
        worker.ENERGY_IDENTITY_TOLERANCE_J,
        "IDENTITY_TOLERANCE",
    )
    exact(threshold["new_behavior_threshold_count"], 0, "NEW_BEHAVIOR_THRESHOLD")
    exact(threshold["new_empirical_threshold_count"], 0, "NEW_EMPIRICAL_THRESHOLD")
    exact(threshold["new_inference_margin_count"], 0, "NEW_MARGIN")
    exact(threshold["post_outcome_rethresholding_permitted"], False, "RETHRESHOLD")

    smoke = contract["development_integration_smoke"]
    exact(smoke["maximum_outer_steps_per_arm"], 2, "SMOKE_HORIZON")
    exact(smoke["maximum_total_native_solver_steps"], 20, "SMOKE_SOLVER_MAX")
    exact(smoke["behavior_success_predicted_or_claimed"], False, "SMOKE_BEHAVIOR")
    exact(smoke["official_physical_identity_consumed"], False, "SMOKE_OFFICIAL")
    exact(smoke["full_seed_or_natural_stop_required"], False, "SMOKE_FULL")

    zero = contract["complete_zero_world_gate"]
    exact(zero["historical_r24d30_control_count_bound_by_immutable_closure"], 48, "R30_BOUND")
    exact(zero["historical_r24d30_controls_reexecuted"], False, "R30_REEXECUTED")
    exact(zero["executed_r24d31_control_count"], 12, "R31_EXECUTED")
    exact(zero["r24d32_integration_control_count"], 5, "R32_CONTROL_COUNT")
    exact(zero["current_executed_negative_control_count"], 17, "TOTAL_CONTROLS")
    for key in (
        "construct_mujoco_model",
        "instantiate_mujoco_data",
        "physics_state_modified",
        "full_seeded_ghost_required",
        "additional_physical_canary_required",
    ):
        exact(zero[key], False, f"ZERO_{key.upper()}")
    for key in (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
    ):
        exact(zero[key], 0, f"ZERO_{key.upper()}")

    freeze = contract["prospective_freeze"]
    exact(freeze["r24d31_source_inventory_count"], 90, "FREEZE_R31_COUNT")
    exact(freeze["closure_dependency_source_paths"], CLOSURE_DEPENDENCIES, "FREEZE_CLOSURES")
    exact(freeze["new_campaign_source_paths"], NEW_PATHS, "FREEZE_NEW")
    expected_inventory = list(predecessor["source_inventory"]) + CLOSURE_DEPENDENCIES + NEW_PATHS
    exact(contract["source_inventory"], expected_inventory, "SOURCE_INVENTORY")
    exact(len(expected_inventory), 97, "SOURCE_COUNT")
    exact(len(set(expected_inventory)), 97, "SOURCE_UNIQUE")
    changed = set(freeze["changed_existing_source_paths"])
    require(changed.issubset(set(predecessor["source_inventory"])), "CHANGED_SOURCE_SCOPE")
    for relative in predecessor["source_inventory"]:
        require((ROOT / relative).is_file(), f"SOURCE_MISSING:{relative}")
        if relative in changed:
            require(_blob(relative) != _parent_blob(relative), f"SOURCE_NOT_CHANGED:{relative}")
        else:
            exact(_blob(relative), _parent_blob(relative), f"SOURCE_DRIFT:{relative}")
    for relative in CLOSURE_DEPENDENCIES:
        require((ROOT / relative).is_file(), f"CLOSURE_MISSING:{relative}")
        exact(_blob(relative), _parent_blob(relative), f"CLOSURE_DRIFT:{relative}")
    for relative in NEW_PATHS:
        require((ROOT / relative).is_file(), f"NEW_SOURCE_MISSING:{relative}")
        require(_absent_at_parent(relative), f"NEW_SOURCE_EXISTED:{relative}")

    checks, _details = worker._r24d32_controls()
    exact(len(checks), 5, "CONTROL_COUNT")
    exact(sum(checks.values()), 5, "CONTROL_PASS")

    zero_wrapper = (SDK_ROOT / "run_qsdk_r24d32_corrected_energy_progression_zero_world.ps1").read_text(
        encoding="utf-8"
    )
    physical_wrapper = (SDK_ROOT / "run_qsdk_r24d32_corrected_energy_progression_development.ps1").read_text(
        encoding="utf-8"
    )
    for text, marker in (
        (zero_wrapper, 'GateId "QSDK-R24D32"'),
        (physical_wrapper, 'GateId "QSDK-R24D32"'),
    ):
        require(marker in text, "WRAPPER_GATE")
        require("qsdk_r24d32_corrected_energy_progression_worker" in text, "WRAPPER_WORKER")

    support = _load_live_authority(SUPPORT_MATRIX_PATH)
    support_root = support["morphology"]["recovery_morphology_boundary"]
    next_support = support_root["next_development_boundary"]
    exact(support_root["next_gate_id"], GATE_ID, "SUPPORT_NEXT_GATE")
    exact(next_support["gate_id"], GATE_ID, "SUPPORT_BOUNDARY_GATE")
    exact(next_support["physical_execution_authorized"], False, "SUPPORT_PHYSICAL")
    if "contract_path" in next_support:
        exact(
            next_support["contract_path"],
            CONTRACT_PATH.relative_to(ROOT).as_posix(),
            "SUPPORT_CONTRACT_PATH",
        )
        exact(next_support["contract_raw_sha256"], _raw_sha256(CONTRACT_PATH), "SUPPORT_CONTRACT_HASH")

    release = _load_live_authority(RELEASE_CONTRACT_PATH)
    next_release = _find_release_gate(release, "QSDK-R24")["proof"]["next_recovery_boundary"]
    exact(next_release["gate_id"], GATE_ID, "RELEASE_NEXT_GATE")
    exact(next_release["physical_execution_authorized"], False, "RELEASE_PHYSICAL")
    if "contract_path" in next_release:
        exact(
            next_release["contract_path"],
            CONTRACT_PATH.relative_to(ROOT).as_posix(),
            "RELEASE_CONTRACT_PATH",
        )
        exact(next_release["contract_raw_sha256"], _raw_sha256(CONTRACT_PATH), "RELEASE_CONTRACT_HASH")

    claims = contract["claim_boundary"]
    positive = {
        "r24d31_zero_world_correction_consumed",
        "r24d30_physical_result_preserved",
        "physical_question_declared",
    }
    if freeze["development_zero_world_gate_passed"]:
        positive.add("development_zero_world_gate_passed")
    if freeze["development_integration_smoke_passed"]:
        positive.add("development_integration_smoke_passed")
    for key, value in claims.items():
        exact(value, key in positive, f"CLAIM_{key.upper()}")

    print(
        "QSDK_R24D32_CORRECTED_ENERGY_PROGRESSION_SOURCE_PASS "
        "current_controls=17/17 historical_r30=48_digest_bound models=0 worlds=0 "
        f"solver_steps=0 dev_smoke={str(freeze['development_integration_smoke_passed']).lower()} "
        "official_physics=false"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(
            f"QSDK_R24D32_CORRECTED_ENERGY_PROGRESSION_SOURCE_FAIL:{error}",
            file=sys.stderr,
        )
        raise
