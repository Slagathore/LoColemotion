"""Prospective zero-world source audit for QSDK-R24D21."""

from __future__ import annotations

import ast
import hashlib
import json
from pathlib import Path
import subprocess
import sys
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
CONTRACT_RELATIVE = Path(
    "sdk/recovery/r24d21_exact_s169_prone_geometry_feasibility_contract_v1.json"
)
EVALUATOR_RELATIVE = Path(
    "sdk/recovery/r24d21_exact_s169_prone_geometry_feasibility.py"
)
PREDECESSOR_RELATIVE = Path(
    "sdk/recovery/r24d20_mujoco_native_recovery_development_incomplete_closure_v1.json"
)
PREDECESSOR_RAW_SHA256 = (
    "sha256:752121f1c5ba02e53ddd50eee62092fb8d016b6e911fd6fcb0a2b403622fbb0b"
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


def audit() -> None:
    contract = load(CONTRACT_RELATIVE)
    predecessor = load(PREDECESSOR_RELATIVE)
    exact(raw_sha256(PREDECESSOR_RELATIVE), PREDECESSOR_RAW_SHA256, "PREDECESSOR_HASH")
    exact(
        contract["schema_version"],
        "sporespore_qsdk_r24d21_exact_s169_prone_geometry_feasibility_contract_v1",
        "SCHEMA",
    )
    exact(contract["gate_id"], "QSDK-R24D21", "GATE")
    exact(contract["question_class"], "finite_decision", "QUESTION_CLASS")
    exact(contract["superiority_question_declared"], False, "SUPERIORITY")
    exact(
        contract["equivalence_or_non_inferiority_question_declared"],
        False,
        "EQUIVALENCE",
    )
    lineage = contract["lineage"]
    exact(lineage["predecessor_gate_id"], "QSDK-R24D20", "PREDECESSOR_GATE")
    exact(lineage["predecessor_closure_raw_sha256"], PREDECESSOR_RAW_SHA256, "LINEAGE_HASH")
    exact(lineage["predecessor_result_rewritten"], False, "LINEAGE_REWRITE")
    exact(lineage["predecessor_rerun"], False, "LINEAGE_RERUN")
    exact(predecessor["next_boundary"]["gate_id"], "QSDK-R24D21", "AUTHORIZED_NEXT")

    population = contract["population"]
    exact(population["descriptor_count"], 1, "POPULATION_COUNT")
    exact(population["morphology_id"], "qsdk_r05_generated_s169", "MORPHOLOGY")
    exact(population["torso_roll_rad"], 0.0, "ROLL")
    exact(population["arbitrary_morphology_claimed"], False, "ARBITRARY")
    exact(population["population_inference_claimed"], False, "INFERENCE")

    rule = contract["decision_rule"]
    exact(rule["feasibility_threshold_m"], 0.0, "THRESHOLD")
    exact(rule["new_threshold_count"], 1, "THRESHOLD_COUNT")
    exact(rule["new_margin_count"], 0, "MARGIN_COUNT")
    exact(rule["post_outcome_rethresholding_permitted"], False, "RETHRESHOLD")
    require(bool(rule["threshold_provenance"].strip()), "THRESHOLD_PROVENANCE")
    require(bool(rule["threshold_adequacy"].strip()), "THRESHOLD_ADEQUACY")
    require(bool(rule["adequacy_argument"].strip()), "DECISION_ADEQUACY")

    execution = contract["execution_contract"]
    exact(execution["mujoco_import_permitted"], False, "MUJOCO_IMPORT")
    for key in (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
        "held_out_cell_access_count",
        "held_out_selector_invocation_count",
    ):
        exact(execution[key], 0, f"EXECUTION_{key.upper()}")
    exact(execution["physics_state_modified"], False, "EXECUTION_PHYSICS")

    expected_inventory = [
        "sdk/core/src/quadruped.rs",
        "sdk/python/sporespore_locomotion.py",
        PREDECESSOR_RELATIVE.as_posix(),
        EVALUATOR_RELATIVE.as_posix(),
        CONTRACT_RELATIVE.as_posix(),
        Path(__file__).resolve().relative_to(REPO_ROOT).as_posix(),
    ]
    exact(contract["source_inventory"], expected_inventory, "SOURCE_INVENTORY")
    for item in expected_inventory:
        require((REPO_ROOT / item).is_file(), f"SOURCE_MISSING:{item}")

    evaluator = (REPO_ROOT / EVALUATOR_RELATIVE).read_text(encoding="utf-8")
    ast.parse(evaluator)
    required = (
        "def _upper_link_decision(",
        "def evaluate_compiled_v1(",
        "proximal_cap_clearance_m = hip_center_y_m - radius_m",
        "length_m * math.cos(best_abs_hip_angle_rad)",
        "maximum_upper_capsule_clearance_m = min(",
        '"knee_configuration_can_change_this_bound": False',
        '"mujoco_imported": False',
        '"model_construction_count": 0',
        '"held_out_cell_access_count": 0',
    )
    missing = [value for value in required if value not in evaluator]
    require(not missing, f"EVALUATOR_SOURCE:{missing}")
    require("import mujoco" not in evaluator, "MUJOCO_IMPORTED")
    subprocess.run(
        [sys.executable, "-m", "py_compile", str(REPO_ROOT / EVALUATOR_RELATIVE)],
        cwd=REPO_ROOT,
        check=True,
        capture_output=True,
    )

    mutations = contract["mutation_controls"]
    exact(len(mutations), 2, "MUTATION_COUNT")
    exact(
        [item["mutation_id"] for item in mutations],
        [
            "raise_hip_anchor_until_current_range_is_exactly_tangent",
            "increase_hip_anchor_by_one_binary64_step_above_tangent",
        ],
        "MUTATION_IDS",
    )

    claim = contract["claim_boundary"]
    exact(claim["finite_geometry_question_declared"], True, "DECLARED")
    for key in (
        "finite_geometry_decision_observed",
        "initializer_successor_implemented",
        "physical_question_opened",
        "controller_physical_viability_proven",
        "prone_to_standing_claimed",
        "held_out_validation_claimed",
        "cross_engine_recovery_claimed",
        "cross_engine_equivalence_claimed",
        "sdk1_milestone_advanced",
        "physical_acceptance_authority",
        "release_authority",
    ):
        exact(claim[key], False, f"CLAIM_{key.upper()}")

    print(
        "QSDK_R24D21_PRONE_GEOMETRY_SOURCE_PASS question=finite_decision "
        "population=1 threshold_m=0 margins=0 models=0 worlds=0 solver_steps=0 "
        "heldout_access=0 outcome_observed=False"
    )


if __name__ == "__main__":
    try:
        audit()
    except Exception as error:
        print(f"QSDK_R24D21_PRONE_GEOMETRY_SOURCE_FAIL {error}", file=sys.stderr)
        raise SystemExit(1) from error
