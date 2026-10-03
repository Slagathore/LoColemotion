"""Compact zero-world source audit for QSDK-R24D31."""

from __future__ import annotations

from copy import deepcopy
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
    qsdk_r24d31_energy_ledger_correction_worker as worker,
)


DECLARATION_PARENT = "9688a88deb55cf608773fca01b7d0ace3dcd3e64"
FROZEN_SOURCE = "2a7a63ae7c166e180177d33cf3a6954c866409d6"
CONTRACT_PATH = (
    SDK_ROOT / "recovery/r24d31_mujoco_energy_ledger_correction_contract_v1.json"
)
FIXTURE_PATH = SDK_ROOT / "recovery/r24d31_r24d30_energy_ledger_fixture_v1.json"
R24D30_CONTRACT_PATH = (
    SDK_ROOT / "recovery/r24d30_natural_recovery_progression_contract_v1.json"
)
R24D30_CLOSURE_PATH = (
    SDK_ROOT / "recovery/r24d30_natural_recovery_progression_physical_closure_v1.json"
)
R24D31_CLOSURE_PATH = (
    SDK_ROOT
    / "recovery/r24d31_mujoco_energy_ledger_correction_qualification_closure_v1.json"
)
R24D17_CONTRACT_PATH = (
    SDK_ROOT / "recovery/r24d17_native_recovery_runtime_and_physical_profile_contract_v1.json"
)
SUPPORT_MATRIX_PATH = SDK_ROOT / "release/quadruped_support_matrix.json"
RELEASE_CONTRACT_PATH = SDK_ROOT / "release/quadruped_release_contract.json"
CHANGED_PATHS = [
    "sdk/core/src/recovery.rs",
    "sdk/core/src/recovery_runtime.rs",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/recovery_capability.py",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/native_recovery_development.py",
    "sdk/adapters/mujoco/test_native_recovery_development.py",
]
CLOSURE_DEPENDENCIES = [
    "sdk/recovery/r24d30_natural_recovery_progression_physical_closure_v1.json",
    "tests/test_qsdk_r24d30_natural_recovery_progression_physical_closure.py",
]
NEW_PATHS = [
    "sdk/recovery/r24d31_mujoco_energy_ledger_correction_contract_v1.json",
    "sdk/recovery/r24d31_r24d30_energy_ledger_fixture_v1.json",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/"
    "qsdk_r24d31_energy_ledger_correction_worker.py",
    "tests/test_qsdk_r24d31_mujoco_energy_ledger_correction_source.py",
    "sdk/run_qsdk_r24d31_energy_ledger_correction_zero_world.ps1",
]


def _raw_sha256(path: Path) -> str:
    return sha256(path.read_bytes())


def _load_live_authority(path: Path) -> dict[str, Any]:
    """Load mutable authorities whose retained history can contain duplicate keys."""

    value = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(value, dict), f"LIVE_AUTHORITY_ROOT:{path}")
    return value


def _find_release_gate(value: dict[str, Any], gate_id: str) -> dict[str, Any]:
    gates = value.get("gates")
    require(isinstance(gates, list), "RELEASE_GATES")
    matches = [
        item
        for item in gates
        if isinstance(item, dict) and item.get("gate_id") == gate_id
    ]
    require(len(matches) == 1, f"RELEASE_GATE_COUNT:{gate_id}")
    return matches[0]


def _blob(relative: str, source: str | None = None) -> str:
    arguments = ("rev-parse", f"{source}:{relative}") if source else (
        "hash-object",
        "--",
        relative,
    )
    value = git(ROOT, *arguments)
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


def _energy_threshold(contract: dict[str, Any]) -> float:
    return float(
        next(
            item["value"]
            for item in contract["threshold_profile"]["thresholds"]
            if item["threshold_id"] == "maximum_energy_balance_residual_j"
        )
    )


def main() -> int:
    contract = load(CONTRACT_PATH)
    fixture = load(FIXTURE_PATH)
    predecessor_contract = load(R24D30_CONTRACT_PATH)
    predecessor_closure = load(R24D30_CLOSURE_PATH)
    threshold_contract = load(R24D17_CONTRACT_PATH)
    worker.load_contract_v1(CONTRACT_PATH)

    exact(contract["schema_version"], worker.CONTRACT_SCHEMA, "SCHEMA")
    exact(contract["gate_id"], worker.GATE_ID, "GATE")
    exact(contract["campaign_id"], worker.CAMPAIGN_ID, "CAMPAIGN")
    exact(contract["declaration_parent_commit"], DECLARATION_PARENT, "PARENT")
    exact(contract["question_class"], "development", "QUESTION_CLASS")
    exact(contract["physical_question_declared"], False, "PHYSICAL_QUESTION")
    for key in (
        "superiority_question_declared",
        "equivalence_or_non_inferiority_question_declared",
        "population_inference_declared",
    ):
        exact(contract[key], False, f"DECLARATION_{key.upper()}")

    lineage = contract["lineage"]
    exact(lineage["predecessor_gate_id"], "QSDK-R24D30", "LINEAGE_GATE")
    exact(lineage["predecessor_source_commit"], worker.R24D30_SOURCE, "LINEAGE_SOURCE")
    exact(lineage["predecessor_closure_commit"], DECLARATION_PARENT, "LINEAGE_COMMIT")
    exact(lineage["predecessor_closure_raw_sha256"], _raw_sha256(R24D30_CLOSURE_PATH), "LINEAGE_HASH")
    exact(lineage["predecessor_result"], predecessor_closure["closure_status"], "LINEAGE_RESULT")
    exact(lineage["predecessor_may_rerun"], False, "LINEAGE_RERUN")
    exact(lineage["predecessor_may_requalify"], False, "LINEAGE_REQUALIFY")
    for key in (
        "predecessor_result_rewritten",
        "predecessor_threshold_rewritten",
        "predecessor_evaluator_rewritten",
        "predecessor_interpretation_rewritten",
    ):
        exact(lineage[key], False, f"LINEAGE_{key.upper()}")

    retained = contract["retained_fixture"]
    exact(retained["path"], FIXTURE_PATH.relative_to(ROOT).as_posix(), "FIXTURE_PATH")
    exact(retained["raw_sha256"], _raw_sha256(FIXTURE_PATH), "FIXTURE_HASH")
    exact(retained["byte_length"], FIXTURE_PATH.stat().st_size, "FIXTURE_LENGTH")
    exact(fixture["source_closure_raw_sha256"], _raw_sha256(R24D30_CLOSURE_PATH), "FIXTURE_CLOSURE")
    exact(
        fixture["source_artifact"]["raw_sha256"],
        worker.R24D30_FULL_SHA256,
        "FIXTURE_ARTIFACT_HASH",
    )
    exact(len(fixture["candidate_points"]), 6, "FIXTURE_CANDIDATE_COUNT")
    exact(len(fixture["matched_zero_points"]), 4, "FIXTURE_MATCHED_COUNT")

    diagnosis = contract["diagnosis"]
    exact(diagnosis["matched_zero_recorded_actuator_work_j"], 0.0, "DIAG_ACTUATOR")
    exact(diagnosis["r24d30_recorded_external_work_j"], 0.0, "DIAG_EXTERNAL")
    exact(diagnosis["r24d30_recorded_dissipated_energy_j"], 0.0, "DIAG_DISSIPATION")
    exact(
        diagnosis["matched_zero_terminal_signed_residual_j"],
        fixture["matched_zero_points"][-1]["signed_residual_j"],
        "DIAG_MATCHED_RESIDUAL",
    )
    exact(diagnosis["unclosed_energy_accounting_is_sufficient_to_explain_failed_safety_conjunction"], True, "DIAG_UNCLOSED")
    for key in (
        "controller_fault_established",
        "actuator_work_fault_established",
        "specific_contact_or_passive_dissipation_magnitude_established",
        "numerical_integration_error_magnitude_established",
        "threshold_inadequacy_established",
        "physical_behavior_reinterpreted",
    ):
        exact(diagnosis[key], False, f"DIAG_{key.upper()}")

    change = contract["controlled_change"]
    exact(change["mujoco_capability_mapping_id_after"], worker.MAPPING_ID, "CHANGE_MAPPING")
    exact(change["energy_ledger_profile_id"], worker.runtime.ENERGY_LEDGER_PROFILE_ID, "CHANGE_PROFILE")
    exact(change["tautological_residual_closure_permitted"], False, "CHANGE_TAUTOLOGY")
    exact(change["mechanical_energy_change_used_to_calculate_dissipation"], False, "CHANGE_MECHANICAL")
    exact(change["balance_residual_used_to_calculate_dissipation"], False, "CHANGE_RESIDUAL")
    for key in (
        "controller_changed",
        "native_physics_changed",
        "morphology_changed",
        "initializer_changed",
        "behavior_thresholds_changed",
        "margins_changed",
        "cell_changed",
        "seed_changed",
        "horizon_changed",
        "portable_phase_machine_changed",
        "portable_pose_classifier_changed",
        "portable_evaluator_changed",
        "held_out_selector_changed",
    ):
        exact(change[key], False, f"CHANGE_{key.upper()}")

    threshold = contract["threshold_and_adequacy_authority"]
    exact(threshold["maximum_energy_balance_residual_j"], 0.25, "THRESHOLD_CONTRACT")
    exact(_energy_threshold(threshold_contract), 0.25, "THRESHOLD_SOURCE")
    exact(threshold["new_behavior_threshold_count"], 0, "THRESHOLD_NEW")
    exact(threshold["new_empirical_threshold_count"], 0, "THRESHOLD_EMPIRICAL")
    exact(threshold["new_margin_count"], 0, "THRESHOLD_MARGIN")
    exact(threshold["post_outcome_rethresholding_permitted"], False, "THRESHOLD_RESELECT")

    freeze = contract["prospective_freeze"]
    exact(freeze["r24d30_source_inventory_count"], 83, "FREEZE_PARENT_COUNT")
    exact(freeze["closure_dependency_source_paths"], CLOSURE_DEPENDENCIES, "FREEZE_CLOSURES")
    exact(freeze["new_campaign_source_paths"], NEW_PATHS, "FREEZE_NEW")
    exact(freeze["changed_existing_source_paths"], CHANGED_PATHS, "FREEZE_CHANGED")
    expected_inventory = (
        list(predecessor_contract["source_inventory"]) + CLOSURE_DEPENDENCIES + NEW_PATHS
    )
    exact(len(expected_inventory), 90, "INVENTORY_EXPECTED_COUNT")
    exact(contract["source_inventory"], expected_inventory, "INVENTORY_ORDER")
    exact(len(set(expected_inventory)), 90, "INVENTORY_UNIQUE")
    closed = R24D31_CLOSURE_PATH.is_file()
    observed_source = FROZEN_SOURCE if closed else None
    for relative in predecessor_contract["source_inventory"]:
        require((ROOT / relative).is_file(), f"SOURCE_MISSING:{relative}")
        if relative in CHANGED_PATHS:
            require(
                _blob(relative, observed_source) != _parent_blob(relative),
                f"SOURCE_NOT_CHANGED:{relative}",
            )
        else:
            exact(
                _blob(relative, observed_source),
                _parent_blob(relative),
                f"SOURCE_DRIFT:{relative}",
            )
    for relative in CLOSURE_DEPENDENCIES:
        require((ROOT / relative).is_file(), f"CLOSURE_MISSING:{relative}")
        exact(
            _blob(relative, observed_source),
            _parent_blob(relative),
            f"CLOSURE_DRIFT:{relative}",
        )
    for relative in NEW_PATHS:
        require((ROOT / relative).is_file(), f"NEW_SOURCE_MISSING:{relative}")
        require(_absent_at_parent(relative), f"NEW_SOURCE_EXISTED:{relative}")
        if observed_source:
            _blob(relative, observed_source)

    checks, details = worker._zero_world_controls()
    exact(list(checks), contract["complete_zero_world_gate"]["required_controls"], "CONTROL_ORDER")
    exact(len(checks), contract["complete_zero_world_gate"]["negative_control_count"], "CONTROL_COUNT")
    exact(sum(checks.values()), len(checks), "CONTROL_PASS")
    exact(details["fixture_raw_sha256"], _raw_sha256(FIXTURE_PATH), "DETAIL_FIXTURE")
    exact(details["matched_zero_terminal_signed_residual_j"], -0.7191017288295729, "DETAIL_MATCHED")
    exact(details["candidate_terminal_signed_residual_j"], -16.476426362918343, "DETAIL_CANDIDATE")

    mutated_fixture = deepcopy(fixture)
    mutated_fixture["matched_zero_points"][-1]["current_mechanical_energy_j"] = 3.25032710609537
    full = load(Path(fixture["source_evidence_root"]) / "paired_full_result.json")
    exact(worker._trace_points_match(full, mutated_fixture), False, "MUTATION_FIXTURE")

    gate = contract["complete_zero_world_gate"]
    for key in (
        "construct_mujoco_model",
        "instantiate_mujoco_data",
        "physics_state_modified",
        "full_seeded_ghost_required",
        "additional_physical_canary_required",
    ):
        exact(gate[key], False, f"GATE_{key.upper()}")
    for key in (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
    ):
        exact(gate[key], 0, f"GATE_{key.upper()}")

    qualification = contract["qualification_and_closure"]
    exact(qualification["r24d31_physical_execution_permitted"], False, "QUAL_PHYSICAL")
    exact(qualification["next_physical_successor_gate_id"], "QSDK-R24D32", "QUAL_NEXT")

    support = _load_live_authority(SUPPORT_MATRIX_PATH)
    support_boundary = support["morphology"]["recovery_morphology_boundary"]
    next_boundary = support_boundary["next_development_boundary"]
    release = _load_live_authority(RELEASE_CONTRACT_PATH)
    release_proof = _find_release_gate(release, "QSDK-R24")["proof"]
    release_boundary = release_proof["next_recovery_boundary"]
    if next_boundary["gate_id"] == worker.GATE_ID:
        live_state = "prospective"
        exact(support_boundary["next_gate_id"], worker.GATE_ID, "SUPPORT_NEXT_GATE")
        exact(next_boundary["status"], contract["status"], "SUPPORT_STATUS")
        exact(next_boundary["contract_raw_sha256"], _raw_sha256(CONTRACT_PATH), "SUPPORT_CONTRACT_HASH")
        exact(next_boundary["official_zero_world_qualification_passed"], False, "SUPPORT_QUALIFICATION")
        exact(release_boundary["gate_id"], worker.GATE_ID, "RELEASE_BOUNDARY_GATE")
        exact(release_boundary["status"], contract["status"], "RELEASE_STATUS")
        exact(release_boundary["official_zero_world_qualification_passed"], False, "RELEASE_QUALIFICATION")
    else:
        live_state = "closed"
        exact(next_boundary["gate_id"], "QSDK-R24D32", "SUPPORT_BOUNDARY_GATE")
        exact(next_boundary["status"], "not_yet_frozen_physical_execution_blocked", "SUPPORT_STATUS")
        exact(support_boundary["next_gate_id"], "QSDK-R24D32", "SUPPORT_NEXT_GATE")
        completed = support_boundary["latest_zero_world_development_closure"]
        exact(completed["gate_id"], worker.GATE_ID, "SUPPORT_COMPLETED_GATE")
        exact(completed["source_commit"], FROZEN_SOURCE, "SUPPORT_COMPLETED_SOURCE")
        exact(completed["contract_raw_sha256"], _raw_sha256(CONTRACT_PATH), "SUPPORT_CONTRACT_HASH")
        exact(completed["closure_raw_sha256"], _raw_sha256(R24D31_CLOSURE_PATH), "SUPPORT_CLOSURE_HASH")
        exact(completed["official_zero_world_qualification_passed"], True, "SUPPORT_QUALIFICATION")
        exact(release_boundary["gate_id"], "QSDK-R24D32", "RELEASE_BOUNDARY_GATE")
        release_completed = release_proof["latest_zero_world_recovery_closure"]
        exact(release_completed["gate_id"], worker.GATE_ID, "RELEASE_COMPLETED_GATE")
        exact(release_completed["source_commit"], FROZEN_SOURCE, "RELEASE_COMPLETED_SOURCE")
        exact(release_completed["closure_raw_sha256"], _raw_sha256(R24D31_CLOSURE_PATH), "RELEASE_CLOSURE_HASH")
        exact(release_completed["official_zero_world_qualification_passed"], True, "RELEASE_QUALIFICATION")
    exact(next_boundary["physical_execution_authorized"], False, "SUPPORT_PHYSICAL")
    exact(release_boundary["physical_execution_authorized"], False, "RELEASE_PHYSICAL")

    claims = contract["claim_boundary"]
    for key in (
        "r24d30_trace_reused_without_rerun",
        "unclosed_predecessor_energy_accounting_diagnosed",
        "independent_native_work_source_correction_authored",
        "development_zero_world_gate_passed",
    ):
        exact(claims[key], True, f"CLAIM_{key.upper()}")
    for key, value in claims.items():
        if key not in {
            "r24d30_trace_reused_without_rerun",
            "unclosed_predecessor_energy_accounting_diagnosed",
            "independent_native_work_source_correction_authored",
            "development_zero_world_gate_passed",
        }:
            exact(value, False, f"CLAIM_{key.upper()}")

    print(
        "QSDK_R24D31_MUJOCO_ENERGY_LEDGER_CORRECTION_SOURCE_PASS "
        "diagnosis=unclosed_zero_dissipation matched_zero_residual_j=0.7191017288295729 "
        f"controls=12 models=0 worlds=0 solver_steps=0 live_state={live_state} "
        "next=QSDK-R24D32"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"QSDK_R24D31_MUJOCO_ENERGY_LEDGER_CORRECTION_SOURCE_FAIL:{error}", file=sys.stderr)
        raise
