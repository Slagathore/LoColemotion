"""Verify the retained QSDK-R24D19 invalid development closure."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
CLOSURE_RELATIVE = Path(
    "sdk/recovery/r24d19_mujoco_native_recovery_development_invalid_closure_v1.json"
)
SOURCE_COMMIT = "82bb733a73daf2d1f3aca36fd7cbc3ba3ea0083a"


class ClosureError(RuntimeError):
    pass


def require(condition: bool, code: str) -> None:
    if not condition:
        raise ClosureError(code)


def exact(actual: object, expected: object, code: str) -> None:
    require(actual == expected, f"{code}: expected={expected!r} actual={actual!r}")


def load(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(value, dict), "JSON_ROOT")
    assert isinstance(value, dict)
    return value


def raw_sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def source_at_commit(relative: str) -> str:
    result = subprocess.run(
        ["git", "show", f"{SOURCE_COMMIT}:{relative}"],
        cwd=REPO_ROOT,
        check=True,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    return result.stdout


def audit() -> None:
    closure = load(REPO_ROOT / CLOSURE_RELATIVE)
    exact(
        closure["schema_version"],
        "sporespore_qsdk_r24d19_mujoco_native_recovery_development_invalid_closure_v1",
        "SCHEMA",
    )
    exact(closure["gate_id"], "QSDK-R24D19", "GATE")
    exact(closure["question_class"], "development", "QUESTION_CLASS")
    exact(closure["source_commit"], SOURCE_COMMIT, "SOURCE_COMMIT")
    subprocess.run(
        ["git", "cat-file", "-e", f"{SOURCE_COMMIT}^{{commit}}"],
        cwd=REPO_ROOT,
        check=True,
        capture_output=True,
    )

    contract_path = REPO_ROOT / closure["contract_path"]
    exact(raw_sha256(contract_path), closure["contract_raw_sha256"], "CONTRACT_DIGEST")

    qualification = closure["qualification"]
    qualification_root = Path(qualification["evidence_root"])
    qualification_receipt = qualification_root / qualification["receipt_path"]
    require(qualification_receipt.is_file(), "QUALIFICATION_RECEIPT_MISSING")
    exact(
        raw_sha256(qualification_receipt),
        qualification["receipt_raw_sha256"],
        "QUALIFICATION_DIGEST",
    )
    qualification_value = load(qualification_receipt)
    exact(qualification_value["ok"], True, "QUALIFICATION_OK")
    exact(qualification_value["source_commit"], SOURCE_COMMIT, "QUALIFICATION_SOURCE")
    for key in (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
    ):
        exact(qualification_value[key], 0, f"QUALIFICATION_{key.upper()}")
    exact(qualification_value["physics_state_modified"], False, "QUALIFICATION_PHYSICS")

    attempt = closure["physical_attempt"]
    attempt_root = Path(attempt["evidence_root"])
    require(attempt_root.is_dir(), "ATTEMPT_ROOT_MISSING")
    for artifact in closure["retained_artifacts"]:
        path = attempt_root / artifact["path"]
        require(path.is_file(), f"ARTIFACT_MISSING:{artifact['path']}")
        exact(path.stat().st_size, artifact["byte_length"], "ARTIFACT_LENGTH")
        exact(raw_sha256(path), artifact["raw_sha256"], "ARTIFACT_DIGEST")
    invalid = load(attempt_root / "invalid_result.json")
    exact(invalid["source_commit"], SOURCE_COMMIT, "INVALID_SOURCE")
    exact(invalid["invalid_but_retained"], True, "INVALID_RETAINED")
    exact(invalid["error"], "QSDK_R24D19_MODEL_TIMESTEP_MISMATCH", "INVALID_ERROR")
    exact(invalid["route_coverage_passed"], False, "INVALID_COVERAGE")
    exact(invalid["held_out_cell_access_count"], 0, "INVALID_HELDOUT")
    exact(invalid["prone_to_standing_claimed"], False, "INVALID_CLAIM")
    require(
        "validate_public_profile_model_identity_v2" in invalid["traceback"],
        "INVALID_STACK_VALIDATOR",
    )

    exact(attempt["selected_cell_id"], "development_nominal", "CELL")
    exact(attempt["selected_seed"], 1129522465, "SEED")
    exact(attempt["held_out_cell_access_count"], 0, "HELDOUT_ACCESS")
    exact(attempt["held_out_selector_invocation_count"], 0, "HELDOUT_SELECTOR")
    exact(attempt["model_construction_count"], 1, "MODEL_CONSTRUCTION")
    exact(attempt["public_profile_binding_completed"], True, "PUBLIC_BINDING")
    exact(attempt["data_construction_count"], 1, "DATA_CONSTRUCTION")
    exact(attempt["world_attempt_count"], 1, "WORLD_ATTEMPT")
    exact(attempt["world_build_count"], 0, "WORLD_BUILD")
    exact(attempt["solver_step_count"], 0, "SOLVER_STEP")
    exact(attempt["physics_state_modified"], False, "PHYSICS_MODIFIED")
    exact(attempt["route_coverage_passed"], False, "ROUTE_COVERAGE")
    exact(attempt["result_class"], "invalid_integration_result", "RESULT_CLASS")

    route_source = source_at_commit(
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/native_recovery_development.py"
    )
    base_source = source_at_commit(
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/selected_policy_development.py"
    )
    require(
        "float(model.opt.timestep) == OUTER_DT_S / NATIVE_SUBSTEPS_PER_OUTER_STEP"
        in route_source,
        "CONSUMED_TIMESTEP_PREDICATE",
    )
    require(
        '"timestep": f"{INTERNAL_DT_S:.17g}"' in base_source,
        "PRODUCTION_XML_TIMESTEP_AUTHORITY",
    )
    production_timestep = 1.0 / 600.0
    recomputed_timestep = (1.0 / 120.0) / 5
    exact(production_timestep.hex(), "0x1.b4e81b4e81b4fp-10", "PRODUCTION_HEX")
    exact(recomputed_timestep.hex(), "0x1.b4e81b4e81b4ep-10", "RECOMPUTED_HEX")
    exact(math.nextafter(recomputed_timestep, math.inf), production_timestep, "ONE_ULP")
    require(production_timestep != recomputed_timestep, "TIMESTEPS_DISTINCT")

    cause = closure["observed_cause"]
    exact(cause["class"], "model_timestep_identity_recomposition_mismatch", "CAUSE")
    exact(cause["production_timestep_authority"], "base.INTERNAL_DT_S", "AUTHORITY")
    exact(cause["production_timestep_binary64_hex"], production_timestep.hex(), "CAUSE_PRODUCTION")
    exact(cause["recomputed_predicate_binary64_hex"], recomputed_timestep.hex(), "CAUSE_RECOMPUTED")
    exact(cause["binary64_ulp_distance"], 1, "CAUSE_ULP")
    exact(cause["physical_model_rejected_was_correctly_authored"], True, "AUTHORED_MODEL")
    for key in (
        "physics_behavior_failure",
        "threshold_failure",
        "selector_failure",
        "evaluator_failure",
        "result_interpretation_rewritten",
    ):
        exact(cause[key], False, f"CAUSE_{key.upper()}")

    decision = closure["decision"]
    exact(decision["r24d19_result"], "invalid_and_retained", "DECISION")
    exact(decision["r24d19_may_be_rerun"], False, "RERUN")
    exact(decision["controller_physical_viability_proven"], False, "VIABILITY")
    exact(decision["prone_to_standing_claimed"], False, "RECOVERY_CLAIM")
    exact(decision["sdk1_milestone_advanced"], False, "MILESTONE")
    exact(decision["sdk1_completed_steps"], 11, "SDK1_COUNT")
    exact(decision["sdk1_total_steps"], 20, "SDK1_TOTAL")

    next_boundary = closure["next_boundary"]
    exact(next_boundary["gate_id"], "QSDK-R24D20", "NEXT_GATE")
    exact(next_boundary["question_class"], "development", "NEXT_CLASS")
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
    ):
        exact(next_boundary[key], False, f"NEXT_{key.upper()}")
    exact(next_boundary["held_out_cells_remain_sealed"], True, "NEXT_HELDOUT")

    claim = closure["claim_boundary"]
    exact(claim["complete_zero_world_gate_passed"], True, "ZERO_WORLD_CLAIM")
    exact(claim["physical_question_opened"], True, "PHYSICAL_OPENED")
    exact(claim["public_profile_validator_force_range_path_reached"], True, "FORCE_PATH")
    for key in (
        "valid_physical_behavior_result_observed",
        "native_route_coverage_proven",
        "controller_physical_viability_proven",
        "prone_to_standing_claimed",
        "repeatability_rate_claimed",
        "population_claimed",
        "held_out_validation_claimed",
        "cross_engine_recovery_claimed",
        "cross_engine_equivalence_claimed",
        "physical_acceptance_authority",
        "release_authority",
    ):
        exact(claim[key], False, f"CLAIM_{key.upper()}")

    print(
        "QSDK_R24D19_INVALID_CLOSURE_PASS result=invalid retained=True "
        "cause=one_ulp_timestep_identity model_constructions=1 world_builds=0 "
        "solver_steps=0 heldout_access=0 prone_to_standing_claimed=False "
        "next=QSDK-R24D20"
    )


if __name__ == "__main__":
    try:
        audit()
    except Exception as error:
        print(f"QSDK_R24D19_INVALID_CLOSURE_FAIL {error}", file=sys.stderr)
        raise SystemExit(1) from error
