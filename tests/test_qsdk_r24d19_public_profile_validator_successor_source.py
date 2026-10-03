"""Fail-closed zero-world source audit for QSDK-R24D19."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import sys
from typing import Any, Iterable


REPO_ROOT = Path(__file__).resolve().parents[1]
CONTRACT_RELATIVE = Path(
    "sdk/recovery/r24d19_public_profile_validator_successor_contract_v1.json"
)
PREDECESSOR_RELATIVE = Path(
    "sdk/recovery/r24d18_mujoco_native_recovery_development_invalid_closure_v1.json"
)
PARENT_THRESHOLDS_RELATIVE = Path(
    "sdk/recovery/r24d17_native_recovery_runtime_and_physical_profile_contract_v1.json"
)
ROUTE_RELATIVE = Path(
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/native_recovery_development.py"
)
WORKER_RELATIVE = Path(
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/"
    "qsdk_r24d19_recovery_development_worker.py"
)
TEST_RELATIVE = Path("sdk/adapters/mujoco/test_native_recovery_development.py")
ZERO_WRAPPER_RELATIVE = Path(
    "sdk/run_qsdk_r24d19_mujoco_native_recovery_zero_world.ps1"
)
PHYSICAL_WRAPPER_RELATIVE = Path(
    "sdk/run_qsdk_r24d19_mujoco_native_recovery_development.ps1"
)
BASE_ZERO_RELATIVE = Path(
    "sdk/run_qsdk_r24d18_mujoco_native_recovery_zero_world.ps1"
)
BASE_PHYSICAL_RELATIVE = Path(
    "sdk/run_qsdk_r24d18_mujoco_native_recovery_development.ps1"
)
PREDECESSOR_RAW_SHA256 = (
    "sha256:ba42bb952e259b645b0086b0a76c3f83046d9252a34fbeacfee27fadc5c24f32"
)
PARENT_THRESHOLDS_RAW_SHA256 = (
    "sha256:9dc6bbbe0b7e003d167b9f29ee7d33e1ae52281f86131e8c7d07646a1f0d8e22"
)


class AuditError(RuntimeError):
    pass


def require(condition: bool, code: str) -> None:
    if not condition:
        raise AuditError(code)


def exact(actual: object, expected: object, code: str) -> None:
    require(actual == expected, f"{code}: expected={expected!r} actual={actual!r}")


def _reject_duplicates(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    value: dict[str, Any] = {}
    for key, item in pairs:
        require(key not in value, f"DUPLICATE_KEY:{key}")
        value[key] = item
    return value


def load(relative: Path) -> dict[str, Any]:
    value = json.loads(
        (REPO_ROOT / relative).read_text(encoding="utf-8"),
        object_pairs_hook=_reject_duplicates,
    )
    require(isinstance(value, dict), f"JSON_ROOT:{relative.as_posix()}")
    assert isinstance(value, dict)
    return value


def raw_sha256(relative: Path) -> str:
    return "sha256:" + hashlib.sha256((REPO_ROOT / relative).read_bytes()).hexdigest()


def source(relative: Path) -> str:
    return (REPO_ROOT / relative).read_text(encoding="utf-8")


def contains_all(value: str, needles: Iterable[str], code: str) -> None:
    missing = [needle for needle in needles if needle not in value]
    require(not missing, f"{code}:{missing}")


def audit() -> None:
    contract = load(CONTRACT_RELATIVE)
    predecessor = load(PREDECESSOR_RELATIVE)
    parent = load(PARENT_THRESHOLDS_RELATIVE)
    exact(raw_sha256(PREDECESSOR_RELATIVE), PREDECESSOR_RAW_SHA256, "PREDECESSOR_HASH")
    exact(
        raw_sha256(PARENT_THRESHOLDS_RELATIVE),
        PARENT_THRESHOLDS_RAW_SHA256,
        "THRESHOLD_PARENT_HASH",
    )
    exact(
        contract["schema_version"],
        "sporespore_qsdk_r24d19_public_profile_validator_successor_contract_v1",
        "SCHEMA",
    )
    exact(contract["gate_id"], "QSDK-R24D19", "GATE")
    exact(
        contract["campaign_id"],
        "QSDK-R24D19-MUJOCO-NATIVE-RECOVERY-ROUTE-DEVELOPMENT-GHOST",
        "CAMPAIGN",
    )
    exact(contract["question_class"], "development", "QUESTION_CLASS")
    exact(contract["superiority_question_declared"], False, "SUPERIORITY")
    exact(
        contract["equivalence_or_non_inferiority_question_declared"],
        False,
        "EQUIVALENCE",
    )
    lineage = contract["lineage"]
    exact(lineage["predecessor_gate_id"], "QSDK-R24D18", "PREDECESSOR_GATE")
    exact(lineage["predecessor_closure_raw_sha256"], PREDECESSOR_RAW_SHA256, "LINEAGE_HASH")
    exact(lineage["predecessor_result"], "invalid_integration_result", "LINEAGE_RESULT")
    exact(lineage["predecessor_result_rewritten"], False, "LINEAGE_REWRITE")
    exact(lineage["predecessor_rerun"], False, "LINEAGE_RERUN")
    exact(predecessor["next_boundary"]["gate_id"], "QSDK-R24D19", "AUTHORIZED_NEXT")

    change = contract["controlled_change"]
    exact(
        change["route_id"],
        "sporespore_mujoco_exact_s169_native_recovery_development_v2",
        "ROUTE_ID",
    )
    exact(
        change["validator_id"],
        "sporespore_mujoco_public_profile_model_identity_v2",
        "VALIDATOR_ID",
    )
    for key in (
        "controller_changed",
        "thresholds_changed",
        "margins_changed",
        "selector_changed",
        "cell_changed",
        "seed_changed",
        "horizon_changed",
        "initializer_changed",
        "host_mapping_changed",
        "evaluator_changed",
        "result_interpretation_changed",
    ):
        exact(change[key], False, f"CHANGE_{key.upper()}")

    thresholds = contract["threshold_authority"]
    exact(thresholds["threshold_count"], 16, "THRESHOLD_COUNT")
    exact(len(parent["threshold_profile"]["thresholds"]), 16, "PARENT_THRESHOLD_COUNT")
    exact(thresholds["new_threshold_count"], 0, "NEW_THRESHOLDS")
    exact(thresholds["new_margin_count"], 0, "NEW_MARGINS")
    require(bool(thresholds["adequacy_argument"].strip()), "THRESHOLD_ADEQUACY")
    for item in parent["threshold_profile"]["thresholds"]:
        require(bool(item["provenance"].strip()), "PARENT_PROVENANCE")
        require(bool(item["adequacy"].strip()), "PARENT_ADEQUACY")

    predecessor_contract = load(
        Path("sdk/recovery/r24d18_mujoco_native_recovery_development_contract_v1.json")
    )
    cell = contract["selected_development_cell"]
    old_cell = predecessor_contract["selected_development_cell"]
    for key in (
        "cohort_id",
        "question_class",
        "cell_id",
        "initial_state_id",
        "torso_roll_rad",
        "seed_label",
        "seed_sha256",
        "seed",
        "random_draw_count",
    ):
        exact(cell[key], old_cell[key], f"CELL_{key.upper()}")
    horizon = contract["ghost_horizon"]
    old_horizon = predecessor_contract["ghost_horizon"]
    for key in (
        "outer_steps_per_arm",
        "paired_arm_count",
        "maximum_total_outer_steps",
        "maximum_total_native_solver_steps",
        "extension_after_outcome_permitted",
    ):
        exact(horizon[key], old_horizon[key], f"HORIZON_{key.upper()}")
    exact(horizon["outer_steps_per_arm"], 14, "HORIZON_STEPS")
    exact(horizon["maximum_total_native_solver_steps"], 140, "NATIVE_STEPS")
    require(bool(horizon["provenance"].strip()), "HORIZON_PROVENANCE")
    require(bool(horizon["adequacy"].strip()), "HORIZON_ADEQUACY")

    zero = contract["complete_zero_world_gate"]
    exact(zero["accepted_public_cap_fixture_count"], 1, "ZERO_POSITIVE")
    exact(zero["rejected_public_cap_mutation_count"], 1, "ZERO_NEGATIVE")
    exact(zero["construct_mujoco_model"], False, "ZERO_MODEL")
    exact(zero["instantiate_mujoco_data"], False, "ZERO_DATA")
    exact(zero["world_attempt_count"], 0, "ZERO_ATTEMPTS")
    exact(zero["world_build_count"], 0, "ZERO_BUILDS")
    exact(zero["solver_step_count"], 0, "ZERO_STEPS")
    held_out = contract["held_out_seal"]
    exact(held_out["held_out_cell_access_count"], 0, "HELDOUT_ACCESS")
    exact(held_out["held_out_selector_invocation_count"], 0, "HELDOUT_SELECTOR")
    exact(held_out["held_out_data_use_permitted"], False, "HELDOUT_USE")

    expected_inventory = [
        "sdk/core/src/recovery.rs",
        "sdk/core/src/recovery_runtime.rs",
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/actuator_cap_profile.py",
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d65_public_profile_route.py",
        ROUTE_RELATIVE.as_posix(),
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r24d18_recovery_development_worker.py",
        WORKER_RELATIVE.as_posix(),
        TEST_RELATIVE.as_posix(),
        PREDECESSOR_RELATIVE.as_posix(),
        CONTRACT_RELATIVE.as_posix(),
        Path(__file__).resolve().relative_to(REPO_ROOT).as_posix(),
        BASE_ZERO_RELATIVE.as_posix(),
        BASE_PHYSICAL_RELATIVE.as_posix(),
        ZERO_WRAPPER_RELATIVE.as_posix(),
        PHYSICAL_WRAPPER_RELATIVE.as_posix(),
        "sdk/locomotion_operation_lock.ps1",
    ]
    exact(contract["source_inventory"], expected_inventory, "SOURCE_INVENTORY")
    for item in expected_inventory:
        require((REPO_ROOT / item).is_file(), f"SOURCE_MISSING:{item}")

    route = source(ROUTE_RELATIVE)
    contains_all(
        route,
        (
            'ROUTE_ID = "sporespore_mujoco_exact_s169_native_recovery_development_v2"',
            "def validate_public_profile_model_identity_v2(",
            '"QSDK_R24D19_PUBLIC_ACTUATOR_CONFIGURATION:{index}"',
            '"base_morphology_force_caps_consulted": False',
            "self.model_identity = validate_public_profile_model_identity_v2(",
        ),
        "ROUTE_SUCCESSOR",
    )
    require("base._native_force_limit_nm" not in route, "BASE_CAP_VALIDATOR_REUSED")
    tests = source(TEST_RELATIVE)
    contains_all(
        tests,
        (
            "test_public_profile_validator_accepts_exact_caps_and_rejects_mutation",
            "mutated.actuator_forcerange[1] = [-1.0, 1.0]",
            "QSDK_R24D19_PUBLIC_ACTUATOR_CONFIGURATION:1",
        ),
        "TARGETED_MUTATION_CONTROL",
    )
    worker = source(WORKER_RELATIVE)
    contains_all(
        worker,
        (
            "QSDK-R24D19-MUJOCO-NATIVE-RECOVERY-ROUTE-DEVELOPMENT-GHOST",
            "run_paired_development(",
            "compact_projection_v2",
            "QUALIFICATION_RECEIPT_SCHEMA",
            '"invalid_result.json"',
        ),
        "WORKER_SUCCESSOR",
    )
    base_zero = source(BASE_ZERO_RELATIVE)
    base_physical = source(BASE_PHYSICAL_RELATIVE)
    contains_all(
        base_zero,
        (
            '[string]$GateId = "QSDK-R24D18"',
            "$ContractRelativePath",
            "$AuditRelativePath",
            "$QualificationReceiptSchema",
            "$workerModule preflight",
            "Enter-SporeSporeLocomotionOperationLock -Role conformance",
        ),
        "PARAMETERIZED_ZERO_WORLD",
    )
    contains_all(
        base_physical,
        (
            '[string]$GateId = "QSDK-R24D18"',
            "$CampaignId",
            "$ContractRelativePath",
            "$QualificationReceiptSchema",
            '$workerModule,',
            '"run",',
            "Enter-SporeSporeLocomotionOperationLock -Role physical",
        ),
        "PARAMETERIZED_PHYSICAL",
    )
    zero_wrapper = source(ZERO_WRAPPER_RELATIVE)
    physical_wrapper = source(PHYSICAL_WRAPPER_RELATIVE)
    contains_all(
        zero_wrapper,
        (
            '-GateId "QSDK-R24D19"',
            "r24d19_public_profile_validator_successor_contract_v1.json",
            "qsdk_r24d19_recovery_development_worker",
            "qsdk-r24d19-qualification-",
        ),
        "ZERO_WRAPPER",
    )
    contains_all(
        physical_wrapper,
        (
            '-GateId "QSDK-R24D19"',
            "QSDK-R24D19-MUJOCO-NATIVE-RECOVERY-ROUTE-DEVELOPMENT-GHOST",
            "qsdk_r24d19_recovery_development_worker",
            "qsdk-r24d19-mujoco-recovery-ghost-",
        ),
        "PHYSICAL_WRAPPER",
    )
    forbidden = (
        "heldout_godot_nominal",
        "heldout_rapier_nominal",
        "heldout_mujoco_nominal",
        "948793232",
    )
    require(
        not any(value in route or value in worker for value in forbidden),
        "HELDOUT_ID_IN_ROUTE",
    )

    claim = contract["claim_boundary"]
    exact(claim["public_profile_validator_successor_implemented"], True, "IMPLEMENTED")
    for key in (
        "complete_zero_world_gate_passed",
        "physical_question_opened",
        "native_route_coverage_proven",
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
        "QSDK_R24D19_PUBLIC_PROFILE_VALIDATOR_SOURCE_PASS "
        "question=development changed_symbols=1 accepted_fixtures=1 "
        "rejected_mutations=1 selected_cells=1 heldout_access=0 worlds=0 "
        "solver_steps=0 behavior_claimed=False"
    )


if __name__ == "__main__":
    try:
        audit()
    except Exception as error:
        print(f"QSDK_R24D19_PUBLIC_PROFILE_VALIDATOR_SOURCE_FAIL {error}", file=sys.stderr)
        raise SystemExit(1) from error
