"""Fail-closed zero-world source audit for QSDK-R24D20."""

from __future__ import annotations

import ast
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys
from typing import Any, Iterable


REPO_ROOT = Path(__file__).resolve().parents[1]
CONTRACT_RELATIVE = Path(
    "sdk/recovery/r24d20_production_timestep_identity_successor_contract_v1.json"
)
PREDECESSOR_RELATIVE = Path(
    "sdk/recovery/r24d19_mujoco_native_recovery_development_invalid_closure_v1.json"
)
PREDECESSOR_CONTRACT_RELATIVE = Path(
    "sdk/recovery/r24d19_public_profile_validator_successor_contract_v1.json"
)
PARENT_THRESHOLDS_RELATIVE = Path(
    "sdk/recovery/r24d17_native_recovery_runtime_and_physical_profile_contract_v1.json"
)
ROUTE_RELATIVE = Path(
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/native_recovery_development.py"
)
WORKER_RELATIVE = Path(
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/"
    "qsdk_r24d20_recovery_development_worker.py"
)
TEST_RELATIVE = Path("sdk/adapters/mujoco/test_native_recovery_development.py")
ZERO_WRAPPER_RELATIVE = Path(
    "sdk/run_qsdk_r24d20_mujoco_native_recovery_zero_world.ps1"
)
PHYSICAL_WRAPPER_RELATIVE = Path(
    "sdk/run_qsdk_r24d20_mujoco_native_recovery_development.ps1"
)
BASE_ZERO_RELATIVE = Path(
    "sdk/run_qsdk_r24d18_mujoco_native_recovery_zero_world.ps1"
)
BASE_PHYSICAL_RELATIVE = Path(
    "sdk/run_qsdk_r24d18_mujoco_native_recovery_development.ps1"
)
PREDECESSOR_RAW_SHA256 = (
    "sha256:407060b39dab49fa8adb05b221962cd74f4c26314ce68a6981d885b65aa86503"
)
PARENT_THRESHOLDS_RAW_SHA256 = (
    "sha256:9dc6bbbe0b7e003d167b9f29ee7d33e1ae52281f86131e8c7d07646a1f0d8e22"
)
CODE_FIX_COMMIT = "409cc88a47f455124228e1c8b3cc70dd8b30c2c1"


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


def function_source(module_source: str, name: str) -> str:
    tree = ast.parse(module_source)
    matches = [
        node
        for node in tree.body
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) and node.name == name
    ]
    exact(len(matches), 1, f"FUNCTION_COUNT:{name}")
    segment = ast.get_source_segment(module_source, matches[0])
    require(isinstance(segment, str), f"FUNCTION_SEGMENT:{name}")
    assert isinstance(segment, str)
    return segment


def audit() -> None:
    contract = load(CONTRACT_RELATIVE)
    predecessor = load(PREDECESSOR_RELATIVE)
    predecessor_contract = load(PREDECESSOR_CONTRACT_RELATIVE)
    parent = load(PARENT_THRESHOLDS_RELATIVE)
    exact(raw_sha256(PREDECESSOR_RELATIVE), PREDECESSOR_RAW_SHA256, "PREDECESSOR_HASH")
    exact(
        raw_sha256(PARENT_THRESHOLDS_RELATIVE),
        PARENT_THRESHOLDS_RAW_SHA256,
        "THRESHOLD_PARENT_HASH",
    )
    exact(
        contract["schema_version"],
        "sporespore_qsdk_r24d20_production_timestep_identity_successor_contract_v1",
        "SCHEMA",
    )
    exact(contract["gate_id"], "QSDK-R24D20", "GATE")
    exact(
        contract["campaign_id"],
        "QSDK-R24D20-MUJOCO-NATIVE-RECOVERY-ROUTE-DEVELOPMENT-GHOST",
        "CAMPAIGN",
    )
    exact(contract["question_class"], "development", "QUESTION_CLASS")
    exact(contract["superiority_question_declared"], False, "SUPERIORITY")
    exact(
        contract["equivalence_or_non_inferiority_question_declared"],
        False,
        "EQUIVALENCE",
    )
    subprocess.run(
        ["git", "cat-file", "-e", f"{CODE_FIX_COMMIT}^{{commit}}"],
        cwd=REPO_ROOT,
        check=True,
        capture_output=True,
    )

    lineage = contract["lineage"]
    exact(lineage["predecessor_gate_id"], "QSDK-R24D19", "PREDECESSOR_GATE")
    exact(lineage["predecessor_closure_raw_sha256"], PREDECESSOR_RAW_SHA256, "LINEAGE_HASH")
    exact(lineage["predecessor_result"], "invalid_integration_result", "LINEAGE_RESULT")
    exact(lineage["predecessor_error"], "QSDK_R24D19_MODEL_TIMESTEP_MISMATCH", "LINEAGE_ERROR")
    exact(lineage["predecessor_result_rewritten"], False, "LINEAGE_REWRITE")
    exact(lineage["predecessor_rerun"], False, "LINEAGE_RERUN")
    exact(predecessor["next_boundary"]["gate_id"], "QSDK-R24D20", "AUTHORIZED_NEXT")

    change = contract["controlled_change"]
    exact(change["code_fix_commit"], CODE_FIX_COMMIT, "FIX_COMMIT")
    exact(
        change["route_id"],
        "sporespore_mujoco_exact_s169_native_recovery_development_v3",
        "ROUTE_ID",
    )
    exact(
        change["validator_id"],
        "sporespore_mujoco_public_profile_model_identity_v3",
        "VALIDATOR_ID",
    )
    for key in (
        "comparison_relaxed",
        "controller_changed",
        "force_profile_changed",
        "thresholds_changed",
        "margins_changed",
        "selector_changed",
        "cell_changed",
        "seed_changed",
        "horizon_changed",
        "initializer_changed",
        "host_mapping_changed",
        "collector_changed",
        "evaluator_changed",
        "result_interpretation_changed",
    ):
        exact(change[key], False, f"CHANGE_{key.upper()}")

    timestep = contract["timestep_authority"]
    production_timestep = 1.0 / 600.0
    predecessor_timestep = (1.0 / 120.0) / 5
    exact(production_timestep.hex(), timestep["binary64_hex"], "TIMESTEP_HEX")
    exact(predecessor_timestep.hex(), timestep["predecessor_binary64_hex"], "OLD_HEX")
    exact(math.nextafter(predecessor_timestep, math.inf), production_timestep, "ONE_ULP")
    exact(timestep["ulp_distance"], 1, "ULP_DISTANCE")
    exact(timestep["exact_identity_required"], True, "EXACT_REQUIRED")
    exact(timestep["tolerance_introduced"], False, "NO_TOLERANCE")
    require(bool(timestep["adequacy_argument"].strip()), "TIMESTEP_ADEQUACY")

    thresholds = contract["threshold_authority"]
    exact(thresholds["threshold_count"], 16, "THRESHOLD_COUNT")
    exact(len(parent["threshold_profile"]["thresholds"]), 16, "PARENT_THRESHOLD_COUNT")
    exact(thresholds["new_threshold_count"], 0, "NEW_THRESHOLDS")
    exact(thresholds["new_margin_count"], 0, "NEW_MARGINS")
    require(bool(thresholds["adequacy_argument"].strip()), "THRESHOLD_ADEQUACY")
    for item in parent["threshold_profile"]["thresholds"]:
        require(bool(item["provenance"].strip()), "PARENT_PROVENANCE")
        require(bool(item["adequacy"].strip()), "PARENT_ADEQUACY")

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
    exact(zero["accepted_production_xml_timestep_fixture_count"], 1, "ZERO_TIMESTEP_POSITIVE")
    exact(zero["rejected_adjacent_ulp_timestep_mutation_count"], 1, "ZERO_TIMESTEP_NEGATIVE")
    exact(zero["accepted_public_cap_fixture_count"], 1, "ZERO_CAP_POSITIVE")
    exact(zero["rejected_public_cap_mutation_count"], 1, "ZERO_CAP_NEGATIVE")
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
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/selected_policy_development.py",
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

    route_source = source(ROUTE_RELATIVE)
    validator_v3 = function_source(
        route_source,
        "validate_public_profile_model_identity_v3",
    )
    contains_all(
        route_source,
        (
            'ROUTE_ID = "sporespore_mujoco_exact_s169_native_recovery_development_v3"',
            "self.model_identity = validate_public_profile_model_identity_v3(",
            '"schema_version": "sporespore_mujoco_public_profile_model_identity_v3"',
        ),
        "ROUTE_SUCCESSOR",
    )
    contains_all(
        validator_v3,
        (
            "float(model.opt.timestep) == base.INTERNAL_DT_S",
            '"QSDK_R24D20_MODEL_TIMESTEP_MISMATCH"',
            '"timestep_authority": "selected_policy_development.INTERNAL_DT_S"',
            'f"QSDK_R24D20_PUBLIC_ACTUATOR_CONFIGURATION:{index}"',
        ),
        "VALIDATOR_SUCCESSOR",
    )
    require(
        "OUTER_DT_S / NATIVE_SUBSTEPS_PER_OUTER_STEP" not in validator_v3,
        "RECOMPOSED_TIMESTEP_REUSED",
    )
    require("base._native_force_limit_nm" not in validator_v3, "BASE_CAP_REUSED")

    tests = source(TEST_RELATIVE)
    contains_all(
        tests,
        (
            "test_r24d20_validator_binds_production_xml_and_rejects_adjacent_ulp",
            "compile_public_profile_model_route(self.core)",
            "float(option.attrib[\"timestep\"]), production_timestep",
            "math.nextafter(production_timestep, 0.0)",
            "QSDK_R24D20_MODEL_TIMESTEP_MISMATCH",
        ),
        "TARGETED_MUTATION_CONTROL",
    )
    worker = source(WORKER_RELATIVE)
    contains_all(
        worker,
        (
            "QSDK-R24D20-MUJOCO-NATIVE-RECOVERY-ROUTE-DEVELOPMENT-GHOST",
            "run_paired_development(",
            "compact_projection_v3",
            "QUALIFICATION_RECEIPT_SCHEMA",
            '"invalid_result.json"',
            '"r24d19_invalid_result_rewritten": False',
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
            '-GateId "QSDK-R24D20"',
            "r24d20_production_timestep_identity_successor_contract_v1.json",
            "qsdk_r24d20_recovery_development_worker",
            "qsdk-r24d20-qualification-",
        ),
        "ZERO_WRAPPER",
    )
    contains_all(
        physical_wrapper,
        (
            '-GateId "QSDK-R24D20"',
            "QSDK-R24D20-MUJOCO-NATIVE-RECOVERY-ROUTE-DEVELOPMENT-GHOST",
            "qsdk_r24d20_recovery_development_worker",
            "qsdk-r24d20-mujoco-recovery-ghost-",
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
        not any(value in validator_v3 or value in worker for value in forbidden),
        "HELDOUT_ID_IN_SUCCESSOR",
    )

    claim = contract["claim_boundary"]
    exact(claim["production_timestep_identity_successor_implemented"], True, "IMPLEMENTED")
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
        "QSDK_R24D20_PRODUCTION_TIMESTEP_IDENTITY_SOURCE_PASS "
        "question=development changed_identity_authorities=1 "
        "accepted_production_values=1 rejected_adjacent_ulp_mutations=1 "
        "selected_cells=1 heldout_access=0 worlds=0 solver_steps=0 "
        "behavior_claimed=False"
    )


if __name__ == "__main__":
    try:
        audit()
    except Exception as error:
        print(f"QSDK_R24D20_PRODUCTION_TIMESTEP_IDENTITY_SOURCE_FAIL {error}", file=sys.stderr)
        raise SystemExit(1) from error
