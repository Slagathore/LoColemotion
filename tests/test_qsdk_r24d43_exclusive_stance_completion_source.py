"""Compact declarative source audit for prospective QSDK-R24D43."""

from __future__ import annotations

import json
from pathlib import Path
import sys
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    exact,
    load,
    require,
    sha256,
)


GATE = "QSDK-R24D43"
CAMPAIGN = "QSDK-R24D43-MUJOCO-EXCLUSIVE-STANCE-COMPLETION"
CONTRACT_RELATIVE = "sdk/recovery/r24d43_exclusive_stance_completion_contract_v1.json"
CONTRACT_PATH = ROOT / CONTRACT_RELATIVE
R42_CLOSURE = (
    ROOT
    / "sdk/recovery/r24d42_mujoco_observation_v2_natural_progression_positive_closure_v1.json"
)
R42_AUDIT = (
    ROOT
    / "tests/test_qsdk_r24d42_observation_v2_natural_progression_positive_closure.py"
)
RELEASE_RELATIVE = "sdk/release/quadruped_release_contract.json"
SUPPORT_RELATIVE = "sdk/release/quadruped_support_matrix.json"
MAPPING_RELATIVE = "sdk/release/quadruped_sdk1_milestone_mapping_v1.json"
WORKER_RELATIVE = (
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/"
    "qsdk_r24d43_exclusive_stance_completion_worker.py"
)
RUNTIME_RELATIVE = (
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/native_recovery_development.py"
)
STANCE_RELATIVE = "sdk/python/sporespore_recovery_stance.py"

REQUIRED_INVENTORY = {
    CONTRACT_RELATIVE,
    WORKER_RELATIVE,
    RUNTIME_RELATIVE,
    STANCE_RELATIVE,
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/recovery_runtime.py",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/"
    "qsdk_r24d42_observation_v2_natural_progression_worker.py",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/"
    "recovery_observation_v2_route_fixture.py",
    "sdk/run_qsdk_r24d43_exclusive_stance_completion.ps1",
    "sdk/run_qsdk_r24d43_exclusive_stance_completion_zero_world.ps1",
    "tests/test_qsdk_r24d43_exclusive_stance_completion_source.py",
    "tests/test_sporespore_recovery_stance.py",
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
    contract = load(CONTRACT_PATH)
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
    exact(
        (
            contract["superiority_question_declared"],
            contract["equivalence_or_non_inferiority_question_declared"],
            contract["population_inference_declared"],
        ),
        (False, False, False),
        "QUESTION_SCOPE",
    )
    lineage = contract["lineage"]
    exact(
        lineage["predecessor_positive_closure_raw_sha256"],
        sha256(R42_CLOSURE.read_bytes()),
        "R42_CLOSURE",
    )
    exact(
        lineage["predecessor_closure_audit_raw_sha256"],
        sha256(R42_AUDIT.read_bytes()),
        "R42_AUDIT",
    )
    exact(
        (
            lineage["predecessor_result_is_immutable"],
            lineage["predecessor_reinterpreted"],
            lineage["predecessor_reopened"],
        ),
        (True, False, False),
        "R42_PRESERVATION",
    )

    inventory = tuple(contract["source_inventory"])
    exact(len(inventory), 45, "INVENTORY_COUNT")
    require(len(inventory) == len(set(inventory)), "INVENTORY_DUPLICATE")
    require(REQUIRED_INVENTORY.issubset(inventory), "INVENTORY_REQUIRED_SURFACE")
    require(all((ROOT / item).is_file() for item in inventory), "INVENTORY_MISSING")
    exact(contract["prospective_freeze"]["source_inventory_count"], 45, "FREEZE_COUNT")
    exact(contract["prospective_freeze"]["core_build_profile"], "release", "BUILD")

    for relative in (WORKER_RELATIVE, RUNTIME_RELATIVE, STANCE_RELATIVE):
        compile(_text(relative), str(ROOT / relative), "exec")
    _contains_all(
        _text(STANCE_RELATIVE),
        (
            "plan_recovery_stance_control_v1",
            "STANCE_STEP_OBSERVATION_BINDING",
            "STANCE_HANDOFF_GATES",
            "STANCE_OWNERSHIP_GATE",
            "STANCE_POSE_IDENTITY",
            "recovery_controller_active",
            "engine_specific_policy_branch_count",
        ),
        "STANCE_COMPOSER",
    )
    _contains_all(
        _text(RUNTIME_RELATIVE),
        (
            "continue_through_stance: bool = False",
            "require_stance_continuation_commissioned_v1",
            "plan_stance_control_v1(core, collection, stepped)",
            '"stance_continuation_commissioned": continue_through_stance',
        ),
        "SHARED_RUNTIME",
    )
    _contains_all(
        _text(WORKER_RELATIVE),
        (
            "r42.validate_observation_v2_trace_v1",
            "arm_checks=_arm_execution_checks_v1",
            "continue_through_stance=True",
            "MujocoRecoveryMorphologyStreamingObservationV2World",
            "behavior_claim_authority=False",
            "physical_development_passed",
        ),
        "WORKER_TOPOLOGY",
    )
    _contains_all(
        _text(
            "sdk/adapters/mujoco/sporespore_mujoco_adapter/"
            "qsdk_r24d42_observation_v2_natural_progression_worker.py"
        ),
        ("arm_checks:", "receipt_schema:", "checks = arm_checks(arm)"),
        "SHARED_TRACE_REPLAY",
    )

    wrappers = {
        "sdk/run_qsdk_r24d43_exclusive_stance_completion_zero_world.ps1": (
            'CoreBuildProfile "release"',
            "run_qsdk_r24d18_mujoco_native_recovery_zero_world.ps1",
            "QSDK_R24D43_EXCLUSIVE_STANCE_COMPLETION_SOURCE_PASS",
        ),
        "sdk/run_qsdk_r24d43_exclusive_stance_completion.ps1": (
            'CoreBuildProfile "release"',
            "run_qsdk_r24d18_mujoco_native_recovery_development.ps1",
            "ExpectedHorizonSteps 1200",
            "ExpectedPairedArmCount 2",
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
        (True, False, 10, 12, 0, 0),
        "ZERO_WORLD_GATE",
    )
    horizon = contract["natural_stop_horizon"]
    exact(
        (
            horizon["maximum_steps_per_arm"],
            horizon["maximum_total_outer_steps"],
            horizon["maximum_total_native_solver_steps"],
            horizon["terminal_stop_phases"],
            horizon["full_seeded_predictive_ghost_required"],
            horizon["physical_canary_required"],
        ),
        (1200, 2400, 12000, ["complete", "failed", "refused"], False, False),
        "FINITE_ROUTE",
    )

    release_nodes = _find_gate(_json(RELEASE_RELATIVE))
    support_nodes = _find_gate(_json(SUPPORT_RELATIVE))
    exact((len(release_nodes), len(support_nodes)), (1, 1), "R43_NODE_COUNT")
    for node in (release_nodes[0], support_nodes[0]):
        exact(node["contract_path"], CONTRACT_RELATIVE, "NODE_CONTRACT")
        exact(node["r24d43_source_inventory_count"], 45, "NODE_INVENTORY")
        exact(node["r24d43_required_control_count"], 10, "NODE_CONTROLS")
        exact(node["r24d43_forced_failure_count"], 12, "NODE_FAILURES")
        exact(node["r24d43_source_declared"], True, "NODE_DECLARED")
        exact(
            node["r24d43_development_zero_world_gate_passed"],
            contract["claim_boundary"]["development_zero_world_gate_passed"],
            "NODE_DEVELOPMENT_GATE",
        )
        exact(node["r24d43_official_qualification_passed"], False, "NODE_QUALIFICATION")
        exact(node["r24d43_physical_attempt_consumed"], False, "NODE_PHYSICAL")
        exact(node["r24d43_stance_controller_implemented"], True, "NODE_CONTROLLER")
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
        require("R24D43" in source, f"DOC_R24D43:{relative}")
        require("11/20" in source and "11/25" in source, f"DOC_COUNTS:{relative}")

    claims = contract["claim_boundary"]
    exact(claims["development_zero_world_gate_passed"], True, "DEVELOPMENT_GATE")
    exact(
        claims["official_zero_world_qualification_pending"],
        True,
        "QUALIFICATION_PENDING",
    )
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
    print("QSDK_R24D43_EXCLUSIVE_STANCE_COMPLETION_SOURCE_PASS")
