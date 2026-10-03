"""Fail-closed source audit for the prospective QSDK-R24D18 freeze.

This audit is intentionally compact. Runtime unit tests own executable negative
controls; this file binds the declared selector, inherited threshold authority,
production call chain, physical supervisor, and zero-world runner without
constructing or stepping a physics world.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import sys
from typing import Any, Iterable


REPO_ROOT = Path(__file__).resolve().parents[1]
CONTRACT_RELATIVE = Path(
    "sdk/recovery/r24d18_mujoco_native_recovery_development_contract_v1.json"
)
PARENT_RELATIVE = Path(
    "sdk/recovery/r24d17_native_recovery_runtime_and_physical_profile_contract_v1.json"
)
PARENT_CLOSURE_RELATIVE = Path(
    "sdk/recovery/r24d17_native_recovery_runtime_qualification_closure_v1.json"
)
ROUTE_RELATIVE = Path(
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/native_recovery_development.py"
)
WORKER_RELATIVE = Path(
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/"
    "qsdk_r24d18_recovery_development_worker.py"
)
CORE_RELATIVE = Path("sdk/core/src/recovery.rs")
ZERO_WORLD_RELATIVE = Path(
    "sdk/run_qsdk_r24d18_mujoco_native_recovery_zero_world.ps1"
)
SUPERVISOR_RELATIVE = Path(
    "sdk/run_qsdk_r24d18_mujoco_native_recovery_development.ps1"
)
PARENT_RAW_SHA256 = (
    "sha256:9dc6bbbe0b7e003d167b9f29ee7d33e1ae52281f86131e8c7d07646a1f0d8e22"
)
PARENT_CLOSURE_RAW_SHA256 = (
    "sha256:9316c74f99dc12ae8e8adc0b0e4764fbe95cb1c865c8510e045b5f794afe1403"
)


class AuditError(RuntimeError):
    pass


def require(condition: bool, code: str) -> None:
    if not condition:
        raise AuditError(code)


def exact(actual: object, expected: object, code: str) -> None:
    require(actual == expected, f"{code}: expected={expected!r} actual={actual!r}")


def _reject_duplicate_pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    value: dict[str, Any] = {}
    for key, item in pairs:
        require(key not in value, f"DUPLICATE_JSON_KEY:{key}")
        value[key] = item
    return value


def load_json(relative: Path) -> dict[str, Any]:
    value = json.loads(
        (REPO_ROOT / relative).read_text(encoding="utf-8"),
        object_pairs_hook=_reject_duplicate_pairs,
    )
    require(isinstance(value, dict), f"JSON_ROOT:{relative.as_posix()}")
    assert isinstance(value, dict)
    return value


def raw_sha256(relative: Path) -> str:
    return "sha256:" + hashlib.sha256((REPO_ROOT / relative).read_bytes()).hexdigest()


def text(relative: Path) -> str:
    return (REPO_ROOT / relative).read_text(encoding="utf-8")


def contains_all(source: str, needles: Iterable[str], code: str) -> None:
    missing = [needle for needle in needles if needle not in source]
    require(not missing, f"{code}:{missing}")


def audit() -> None:
    contract = load_json(CONTRACT_RELATIVE)
    parent = load_json(PARENT_RELATIVE)
    load_json(PARENT_CLOSURE_RELATIVE)
    exact(raw_sha256(PARENT_RELATIVE), PARENT_RAW_SHA256, "PARENT_DIGEST")
    exact(
        raw_sha256(PARENT_CLOSURE_RELATIVE),
        PARENT_CLOSURE_RAW_SHA256,
        "PARENT_CLOSURE_DIGEST",
    )

    exact(
        contract.get("schema_version"),
        "sporespore_qsdk_r24d18_mujoco_native_recovery_development_contract_v1",
        "SCHEMA",
    )
    exact(contract.get("gate_id"), "QSDK-R24D18", "GATE")
    exact(
        contract.get("campaign_id"),
        "QSDK-R24D18-MUJOCO-NATIVE-RECOVERY-ROUTE-DEVELOPMENT-GHOST",
        "CAMPAIGN",
    )
    exact(contract.get("question_class"), "development", "QUESTION_CLASS")
    exact(contract.get("superiority_question_declared"), False, "SUPERIORITY")
    exact(
        contract.get("equivalence_or_non_inferiority_question_declared"),
        False,
        "EQUIVALENCE",
    )

    authority = contract["parent_authority"]
    exact(authority["runtime_contract_raw_sha256"], PARENT_RAW_SHA256, "AUTH_PARENT")
    exact(
        authority["runtime_qualification_closure_raw_sha256"],
        PARENT_CLOSURE_RAW_SHA256,
        "AUTH_CLOSURE",
    )
    exact(authority["inherited_observations_rewritten"], False, "OBS_REWRITE")
    exact(authority["inherited_thresholds_reselected"], False, "THRESH_RESELECT")
    exact(authority["inherited_cohorts_reselected"], False, "COHORT_RESELECT")

    parent_thresholds = parent["threshold_profile"]["thresholds"]
    exact(len(parent_thresholds), 16, "PARENT_THRESHOLD_COUNT")
    for threshold in parent_thresholds:
        require(bool(str(threshold.get("provenance", "")).strip()), "THRESHOLD_PROVENANCE")
        require(bool(str(threshold.get("adequacy", "")).strip()), "THRESHOLD_ADEQUACY")
    threshold = contract["threshold_authority"]
    exact(threshold["threshold_count"], len(parent_thresholds), "THRESHOLD_COUNT")
    exact(threshold["new_threshold_count"], 0, "NEW_THRESHOLDS")
    exact(threshold["new_margin_count"], 0, "NEW_MARGINS")
    exact(threshold["post_outcome_rethresholding_permitted"], False, "RETHRESHOLD")
    require(bool(threshold["adequacy_argument"].strip()), "THRESHOLD_ADEQUACY_ARGUMENT")

    parent_cell = parent["cohort_profile"]["development"]["cells"][0]
    cell = contract["selected_development_cell"]
    for key in ("cell_id", "initial_state_id", "seed_label", "seed_sha256", "seed"):
        exact(cell[key], parent_cell[key], f"CELL_{key.upper()}")
    exact(cell["question_class"], "development", "CELL_CLASS")
    exact(cell["torso_roll_rad"], 0.0, "CELL_ROLL")
    exact(cell["random_draw_count"], 0, "CELL_RANDOM_DRAWS")
    require(bool(cell["selection_provenance"].strip()), "CELL_PROVENANCE")
    require(bool(cell["selection_adequacy"].strip()), "CELL_ADEQUACY")

    horizon = contract["ghost_horizon"]
    exact(horizon["outer_steps_per_arm"], 14, "HORIZON")
    exact(horizon["paired_arm_count"], 2, "ARMS")
    exact(horizon["maximum_total_outer_steps"], 28, "OUTER_STEPS")
    exact(horizon["maximum_total_native_solver_steps"], 140, "SOLVER_STEPS")
    require(bool(horizon["provenance"].strip()), "HORIZON_PROVENANCE")
    require(bool(horizon["adequacy"].strip()), "HORIZON_ADEQUACY")
    exact(horizon["extension_after_outcome_permitted"], False, "HORIZON_EXTENSION")

    acceptance = contract["ghost_execution_acceptance"]
    exact(acceptance["candidate_active_command_outer_step_minimum"], 1, "ACTIVE_COMMAND")
    exact(acceptance["matched_zero_active_command_outer_step_count"], 0, "ZERO_COMMAND")
    exact(
        acceptance["required_evaluation_verdict"],
        "physical_development_incomplete",
        "GHOST_VERDICT",
    )
    exact(acceptance["prone_to_standing_result_required"], False, "GHOST_BEHAVIOR")
    exact(
        acceptance["every_positive_negative_rejected_invalid_and_incomplete_result_retained"],
        True,
        "RETENTION",
    )

    zero = contract["complete_zero_world_gate"]
    exact(zero["must_pass_before_physics"], True, "ZERO_REQUIRED")
    exact(zero["construct_mujoco_model"], False, "ZERO_MODEL")
    exact(zero["instantiate_mujoco_data"], False, "ZERO_DATA")
    exact(zero["world_attempt_count"], 0, "ZERO_ATTEMPTS")
    exact(zero["world_build_count"], 0, "ZERO_BUILDS")
    exact(zero["solver_step_count"], 0, "ZERO_STEPS")
    exact(zero["physics_state_modified"], False, "ZERO_PHYSICS")

    held_out = contract["held_out_seal"]
    exact(held_out["held_out_cell_count"], 9, "HELDOUT_COUNT")
    exact(held_out["held_out_cell_access_count"], 0, "HELDOUT_ACCESS")
    exact(held_out["held_out_selector_invocation_count"], 0, "HELDOUT_SELECTOR")
    exact(held_out["held_out_data_use_permitted"], False, "HELDOUT_USE")
    exact(held_out["held_out_cells_remain_sealed_after_r24d18"], True, "HELDOUT_SEAL")

    expected_inventory = [
        "sdk/core/src/recovery.rs",
        "sdk/core/src/recovery_runtime.rs",
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/native_recovery_development.py",
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r24d18_recovery_development_worker.py",
        "sdk/adapters/mujoco/test_native_recovery_development.py",
        CONTRACT_RELATIVE.as_posix(),
        Path(__file__).resolve().relative_to(REPO_ROOT).as_posix(),
        ZERO_WORLD_RELATIVE.as_posix(),
        SUPERVISOR_RELATIVE.as_posix(),
        "sdk/locomotion_operation_lock.ps1",
    ]
    exact(contract["source_inventory"], expected_inventory, "SOURCE_INVENTORY")
    for item in expected_inventory:
        require((REPO_ROOT / item).is_file(), f"SOURCE_MISSING:{item}")

    route_source = text(ROUTE_RELATIVE)
    contains_all(
        route_source,
        (
            "mujoco.MjModel.from_xml_string",
            "mujoco.MjData(self.model)",
            "mujoco.mj_step1(self.model, self.data)",
            "mujoco.mj_step2(self.model, self.data)",
            "mujoco.mj_contactForce",
            "mujoco.mj_geomDistance",
            "core.recovery_step_v1",
            "collect_native_v1(core, collection)",
            "plan_control_v1(",
            "core.recovery_evaluate_trace_v1",
            'arm_kind="candidate_command"',
            'arm_kind="matched_zero_command"',
            "QSDK_R24D18_NONDEVELOPMENT_CELL",
            "QSDK_R24D18_STANCE_HANDOFF_CONTROLLER_NOT_COMMISSIONED",
        ),
        "ROUTE_CALL_CHAIN",
    )
    worker_source = text(WORKER_RELATIVE)
    contains_all(
        worker_source,
        (
            "EXPECTED_HORIZON_STEPS = 14",
            "EXPECTED_SEED = 1129522465",
            "run_paired_development(",
            "compact_projection_v1",
            '"paired_full_result.json"',
            '"paired_summary.json"',
            '"manifest.json"',
            '"invalid_result.json"',
        ),
        "WORKER_CALL_CHAIN",
    )
    forbidden_cells = (
        "heldout_godot_nominal",
        "heldout_rapier_nominal",
        "heldout_mujoco_nominal",
        "948793232",
    )
    require(
        not any(value in route_source or value in worker_source for value in forbidden_cells),
        "HELDOUT_ID_IN_PRODUCTION_ROUTE",
    )

    core_source = text(CORE_RELATIVE)
    contains_all(
        core_source,
        (
            "recovery_physical_development_threshold_profile_v1",
            "EXACT_S169_DEVELOPMENT_THRESHOLD_PROFILE_ID",
            "RecoveryEvaluationVerdictV1::PhysicalDevelopmentIncomplete",
            "physical_development_trace_valid",
        ),
        "CORE_PHYSICAL_PROFILE",
    )
    zero_source = text(ZERO_WORLD_RELATIVE)
    contains_all(
        zero_source,
        (
            "Enter-SporeSporeLocomotionOperationLock",
            "-Role conformance",
            "cargo build --offline -p sporespore-locomotion-core --lib",
            "test_native_recovery_development.py",
            "test_qsdk_r24d18_mujoco_native_recovery_route_source.py",
            "qsdk_r24d18_recovery_development_worker",
            "$workerModule preflight",
            'model_construction_count -ne 0',
            'world_build_count -ne 0',
            'solver_step_count -ne 0',
        ),
        "ZERO_WORLD_RUNNER",
    )
    supervisor_source = text(SUPERVISOR_RELATIVE)
    contains_all(
        supervisor_source,
        (
            "status --porcelain=v1",
            "ls-remote origin refs/heads/main",
            "Enter-SporeSporeLocomotionOperationLock",
            "-Role physical",
            "qsdk_r24d18_recovery_development_worker",
            '$workerModule,',
            '"run",',
            "attempt_reservation.json",
            "operation_lock.json",
            "Exit-SporeSporeLocomotionOperationLock",
        ),
        "PHYSICAL_SUPERVISOR",
    )

    claim = contract["claim_boundary"]
    exact(claim["native_mujoco_recovery_route_implemented"], True, "ROUTE_IMPLEMENTED")
    for key in (
        "complete_zero_world_gate_passed",
        "physical_question_opened",
        "native_route_executed",
        "controller_physical_viability_proven",
        "prone_to_standing_claimed",
        "repeatability_rate_claimed",
        "population_claimed",
        "held_out_validation_claimed",
        "cross_engine_recovery_claimed",
        "cross_engine_equivalence_claimed",
        "sdk1_milestone_advanced",
        "physical_acceptance_authority",
        "release_authority",
    ):
        exact(claim[key], False, f"CLAIM_{key.upper()}")

    print(
        "QSDK_R24D18_MUJOCO_RECOVERY_SOURCE_PASS "
        "question=development selected_cells=1 heldout_access=0 "
        "horizon_per_arm=14 paired_arms=2 maximum_solver_steps=140 "
        "worlds=0 physics_modified=False behavior_claimed=False"
    )


if __name__ == "__main__":
    try:
        audit()
    except Exception as error:
        print(f"QSDK_R24D18_MUJOCO_RECOVERY_SOURCE_FAIL {error}", file=sys.stderr)
        raise SystemExit(1) from error
