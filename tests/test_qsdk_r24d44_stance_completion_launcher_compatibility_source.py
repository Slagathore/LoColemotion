"""Compact source audit for prospective QSDK-R24D44."""

from __future__ import annotations

import json
from pathlib import Path
import sys
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
for path in (ROOT, ROOT / "sdk/python", ROOT / "sdk/adapters/mujoco"):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    exact,
    load,
    require,
    sha256,
)
from sporespore_mujoco_adapter import (  # noqa: E402
    qsdk_r24d44_stance_completion_launcher_compatibility_worker as worker,
)

GATE = "QSDK-R24D44"
CAMPAIGN = "QSDK-R24D44-MUJOCO-EXCLUSIVE-STANCE-COMPLETION-LAUNCH-REPAIR"
CONTRACT_RELATIVE = (
    "sdk/recovery/r24d44_stance_completion_launcher_compatibility_contract_v1.json"
)
CONTRACT_PATH = ROOT / CONTRACT_RELATIVE
R43_CLOSURE = (
    ROOT
    / "sdk/recovery/"
    "r24d43_exclusive_stance_completion_launch_invalid_closure_v1.json"
)
R43_AUDIT = (
    ROOT
    / "tests/test_qsdk_r24d43_exclusive_stance_completion_launch_invalid_closure.py"
)
RELEASE_RELATIVE = "sdk/release/quadruped_release_contract.json"
SUPPORT_RELATIVE = "sdk/release/quadruped_support_matrix.json"
MAPPING_RELATIVE = "sdk/release/quadruped_sdk1_milestone_mapping_v1.json"
SHARED_RUNNER_RELATIVE = (
    "sdk/run_qsdk_r24d18_mujoco_native_recovery_development.ps1"
)
WORKER_RELATIVE = (
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/"
    "qsdk_r24d44_stance_completion_launcher_compatibility_worker.py"
)
PHYSICAL_WRAPPER_RELATIVE = (
    "sdk/run_qsdk_r24d44_stance_completion_launcher_compatibility.ps1"
)
ZERO_WORLD_WRAPPER_RELATIVE = (
    "sdk/run_qsdk_r24d44_stance_completion_launcher_compatibility_zero_world.ps1"
)

REQUIRED_INVENTORY = {
    CONTRACT_RELATIVE,
    WORKER_RELATIVE,
    SHARED_RUNNER_RELATIVE,
    PHYSICAL_WRAPPER_RELATIVE,
    ZERO_WORLD_WRAPPER_RELATIVE,
    "sdk/recovery/r24d43_exclusive_stance_completion_contract_v1.json",
    R43_CLOSURE.relative_to(ROOT).as_posix(),
    R43_AUDIT.relative_to(ROOT).as_posix(),
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/"
    "qsdk_r24d43_exclusive_stance_completion_worker.py",
    "tests/test_qsdk_r24d44_stance_completion_launcher_compatibility_source.py",
    RELEASE_RELATIVE,
    SUPPORT_RELATIVE,
    MAPPING_RELATIVE,
}


def _text(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def _json(relative: str) -> dict[str, Any]:
    value = json.loads((ROOT / relative).read_bytes())
    require(isinstance(value, dict), f"JSON_ROOT:{relative}")
    return value


def _contains_all(source: str, markers: tuple[str, ...], code: str) -> None:
    missing = [marker for marker in markers if marker not in source]
    require(not missing, f"{code}:missing={missing}")


def _find_gate(value: object) -> list[dict[str, Any]]:
    found: list[dict[str, Any]] = []
    if isinstance(value, dict):
        if value.get("gate_id") == GATE:
            found.append(value)
        for child in value.values():
            found.extend(_find_gate(child))
    elif isinstance(value, list):
        for child in value:
            found.extend(_find_gate(child))
    return found


def audit() -> None:
    contract = worker.load_contract_v1(CONTRACT_PATH)
    exact(
        (
            contract["gate_id"],
            contract["campaign_id"],
            contract["question_class"],
            contract["physical_question_declared"],
            contract["behavior_question_declared"],
        ),
        (GATE, CAMPAIGN, "development", True, True),
        "CONTRACT_IDENTITY",
    )
    lineage = contract["lineage"]
    exact(
        lineage["predecessor_launch_invalid_closure_raw_sha256"],
        sha256(R43_CLOSURE.read_bytes()),
        "R43_CLOSURE",
    )
    exact(
        lineage["predecessor_closure_audit_raw_sha256"],
        sha256(R43_AUDIT.read_bytes()),
        "R43_AUDIT",
    )
    closure = load(R43_CLOSURE)
    exact(
        (
            closure["closure_status"],
            closure["launcher_observation"]["attempt_reservation_count"],
            closure["launcher_observation"]["world_attempt_count"],
            closure["launcher_observation"]["solver_step_count"],
            closure["launcher_observation"]["physical_question_opened"],
        ),
        (
            "closed_officially_qualified_launcher_contract_integration_invalid_"
            "before_physical_reservation",
            0,
            0,
            0,
            False,
        ),
        "R43_PRESERVATION",
    )

    inventory = tuple(contract["source_inventory"])
    exact(len(inventory), worker.EXPECTED_SOURCE_INVENTORY_COUNT, "INVENTORY_COUNT")
    require(len(inventory) == len(set(inventory)), "INVENTORY_DUPLICATE")
    require(REQUIRED_INVENTORY.issubset(inventory), "INVENTORY_REQUIRED")
    require(all((ROOT / item).is_file() for item in inventory), "INVENTORY_MISSING")
    exact(
        contract["prospective_freeze"]["source_inventory_count"],
        len(inventory),
        "FREEZE_INVENTORY",
    )
    exact(contract["prospective_freeze"]["core_build_profile"], "release", "BUILD")
    compile(_text(WORKER_RELATIVE), str(ROOT / WORKER_RELATIVE), "exec")

    runner = _text(SHARED_RUNNER_RELATIVE)
    exact(runner.count("function Read-ValidatedPhysicalContract"), 1, "SELECTOR_DEF")
    exact(runner.count("Read-ValidatedPhysicalContract"), 3, "SELECTOR_USAGE")
    _contains_all(
        runner,
        (
            "[switch]$ContractValidationOnly",
            '"missing_ghost_horizon"',
            '"missing_held_out_seal"',
            "$value.PSObject.Properties.Remove(\"ghost_horizon\")",
            "$value.PSObject.Properties.Remove(\"held_out_seal\")",
            "sporespore_shared_physical_launcher_contract_validation_v1",
            "QSDK_R24D18_CONTRACT_VALIDATION_MUTATION_REQUIRES_VALIDATION_ONLY",
        ),
        "SHARED_SELECTOR",
    )
    start = runner.index("if ($ContractValidationOnly) {")
    end = runner.index(
        "if (-not [string]::IsNullOrEmpty($ContractValidationMutation))", start
    )
    validation_branch = runner[start:end]
    _contains_all(
        validation_branch,
        (
            "Read-ValidatedPhysicalContract",
            "model_construction_count = 0",
            "world_attempt_count = 0",
            "solver_step_count = 0",
            "physical_question_opened = $false",
            "return",
        ),
        "VALIDATION_BRANCH",
    )
    require(
        all(
            marker not in validation_branch
            for marker in (
                "Enter-SporeSporeLocomotionOperationLock",
                "New-Item -ItemType Directory",
                "Start-Process",
                "attempt_reservation.json",
            )
        ),
        "VALIDATION_SIDE_EFFECT",
    )
    require(
        runner.rindex("Read-ValidatedPhysicalContract")
        < runner.index("$priorReservations = @("),
        "PHYSICAL_SELECTOR_ORDER",
    )

    _contains_all(
        _text(WORKER_RELATIVE),
        (
            "r43.run_zero_world_preflight(core)",
            "r43._run_route(core_library, contract)",
            "r43.compact_projection_v1(result, trace_invariants)",
            "_run_launcher_contract_controls()",
            'for mutation in ("missing_ghost_horizon", "missing_held_out_seal")',
            "physical_evidence_population_unchanged",
        ),
        "WORKER_REUSE",
    )
    wrappers = {
        ZERO_WORLD_WRAPPER_RELATIVE: (
            'CoreBuildProfile "release"',
            "run_qsdk_r24d18_mujoco_native_recovery_zero_world.ps1",
            "QSDK_R24D44_STANCE_COMPLETION_LAUNCHER_COMPATIBILITY_SOURCE_PASS",
        ),
        PHYSICAL_WRAPPER_RELATIVE: (
            'CoreBuildProfile "release"',
            "run_qsdk_r24d18_mujoco_native_recovery_development.ps1",
            'ExpectedHorizonSteps 1200',
            'ExpectedPairedArmCount 2',
        ),
    }
    for relative, markers in wrappers.items():
        _contains_all(_text(relative), markers, f"WRAPPER:{relative}")

    gate = contract["complete_zero_world_gate"]
    exact(
        (
            gate["must_pass_before_physics"],
            gate["construct_mujoco_model"],
            gate["required_control_count"],
            gate["required_forced_failure_count"],
            gate["world_attempt_count"],
            gate["solver_step_count"],
        ),
        (True, False, 11, 14, 0, 0),
        "ZERO_WORLD_GATE",
    )
    horizon = contract["ghost_horizon"]
    exact(
        (
            horizon["outer_steps_per_arm"],
            horizon["maximum_steps_per_arm"],
            horizon["maximum_total_outer_steps"],
            horizon["maximum_total_native_solver_steps"],
            horizon["terminal_stop_phases"],
            horizon["full_seeded_predictive_ghost_required"],
            horizon["physical_canary_required"],
        ),
        (1200, 1200, 2400, 12000, ["complete", "failed", "refused"], False, False),
        "FINITE_ROUTE",
    )
    exact(
        (
            contract["held_out_seal"]["held_out_cell_access_count"],
            contract["held_out_seal"]["held_out_selector_invocation_count"],
        ),
        (0, 0),
        "HELD_OUT",
    )

    release_nodes = _find_gate(_json(RELEASE_RELATIVE))
    support_nodes = _find_gate(_json(SUPPORT_RELATIVE))
    exact((len(release_nodes), len(support_nodes)), (1, 1), "R44_NODE_COUNT")
    for node in (release_nodes[0], support_nodes[0]):
        exact(node["contract_path"], CONTRACT_RELATIVE, "NODE_CONTRACT")
        exact(node["r24d43_official_qualification_passed"], True, "NODE_R43_QUAL")
        exact(node["r24d43_physical_attempt_reserved"], False, "NODE_R43_PHYSICAL")
        exact(node["r24d44_source_inventory_count"], 52, "NODE_INVENTORY")
        exact(node["r24d44_required_control_count"], 11, "NODE_CONTROLS")
        exact(node["r24d44_forced_failure_count"], 14, "NODE_FAILURES")
        exact(
            node["r24d44_development_zero_world_gate_passed"],
            True,
            "NODE_DEVELOPMENT_GATE",
        )
        exact(node["r24d44_scientific_inputs_changed"], False, "NODE_CHANGE")
        exact(node["physical_execution_authorized"], False, "NODE_EXECUTION")
        exact(node["physical_acceptance_authority"], False, "NODE_ACCEPTANCE")
        exact(node["release_authority"], False, "NODE_RELEASE")

    mapping = _json(MAPPING_RELATIVE)
    authority = mapping["full_program_authority"]
    exact(
        authority["release_contract_raw_sha256"],
        sha256((ROOT / RELEASE_RELATIVE).read_bytes()),
        "MAPPING_RELEASE_HASH",
    )
    exact(
        authority["support_matrix_raw_sha256"],
        sha256((ROOT / SUPPORT_RELATIVE).read_bytes()),
        "MAPPING_SUPPORT_HASH",
    )
    exact(mapping["sdk1_contract"]["milestone_count"], 20, "SDK1_DENOMINATOR")
    for relative in contract["source_inventory"][:6]:
        source = _text(relative)
        require("R24D43" in source and "R24D44" in source, f"DOC_LINEAGE:{relative}")
        require("11/20" in source and "11/25" in source, f"DOC_COUNTS:{relative}")

    claims = contract["claim_boundary"]
    exact(claims["development_zero_world_gate_passed"], True, "DEVELOPMENT_GATE")
    exact(
        claims["physical_launcher_contract_compatibility_zero_world_proven"],
        True,
        "LAUNCHER_COMPATIBILITY",
    )
    exact(claims["official_zero_world_qualification_pending"], True, "QUALIFICATION")
    require(
        not any(
            claims[field]
            for field in (
                "physical_question_opened",
                "native_stance_controller_execution_observed",
                "stance_dwell_observed",
                "portable_complete_observed",
                "exact_nominal_mujoco_prone_to_standing_observed",
                "repeatability_rate_claimed",
                "population_claimed",
                "held_out_validation_claimed",
                "cross_engine_recovery_claimed",
                "cross_engine_equivalence_claimed",
                "sdk1_milestone_advanced",
                "physical_acceptance_authority",
                "release_authority",
            )
        ),
        "CLAIM_OVERREACH",
    )
    exact(
        (
            claims["sdk1_completed_steps"],
            claims["sdk1_total_steps"],
            claims["full_program_completed_steps"],
            claims["full_program_total_steps"],
        ),
        (11, 20, 11, 25),
        "MILESTONE_COUNTS",
    )


if __name__ == "__main__":
    audit()
    print("QSDK_R24D44_STANCE_COMPLETION_LAUNCHER_COMPATIBILITY_SOURCE_PASS")
