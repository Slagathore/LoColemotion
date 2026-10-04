#!/usr/bin/env python3
"""Reusable zero-world source audit for prospectively frozen Rapier successors."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import re
import subprocess
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
EXPECTED_ROOT = Path(r"C:\Users\Cole\CodeStuff\games\LoColemotion")
EXPECTED_REMOTE = "https://github.com/Slagathore/LoColemotion.git"
DIGEST = re.compile(r"^sha256:[0-9a-f]{64}$")
GATE = re.compile(r"^QSDK-R24D[0-9]+$")


class AuditFailure(RuntimeError):
    pass


def require(condition: bool, code: str) -> None:
    if not condition:
        raise AuditFailure(code)


def reject_duplicate_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        require(key not in result, f"DUPLICATE_JSON_KEY:{key}")
        result[key] = value
    return result


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=reject_duplicate_keys)
    require(isinstance(value, dict), f"JSON_ROOT_NOT_OBJECT:{path}")
    return value


def raw_sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def resolve_repo_path(relative: str) -> Path:
    require(relative and "\\" not in relative, f"RELATIVE_PATH_INVALID:{relative}")
    path = (ROOT / relative).resolve()
    require(path != ROOT and ROOT in path.parents, f"PATH_OUTSIDE_REPOSITORY:{relative}")
    require(path.is_file(), f"SOURCE_MISSING:{relative}")
    return path


def validate_contract_shape(contract: dict[str, Any]) -> None:
    require(GATE.fullmatch(str(contract.get("gate_id", ""))) is not None, "GATE_ID")
    require(contract.get("question_class") == "development", "QUESTION_CLASS")
    require(contract.get("physical_question_declared") is True, "PHYSICAL_QUESTION")
    require(contract.get("superiority_question_declared") is False, "SUPERIORITY_BOUNDARY")
    require(
        contract.get("equivalence_or_non_inferiority_question_declared") is False,
        "EQUIVALENCE_BOUNDARY",
    )
    require(contract.get("population_inference_declared") is False, "POPULATION_BOUNDARY")

    change = contract.get("controlled_change", {})
    for field in (
        "world_construction_changed",
        "initializer_changed",
        "controller_changed",
        "native_solver_or_patch_changed",
        "morphology_changed",
        "threshold_changed",
        "margin_changed",
        "selector_changed",
        "cohort_changed",
        "historical_result_rewritten",
    ):
        require(change.get(field) is False, f"CONTROLLED_CHANGE:{field}")

    gate = contract.get("complete_zero_world_gate", {})
    require(gate.get("must_pass_before_physics") is True, "ZERO_WORLD_REQUIRED")
    require(gate.get("physical_execution_authorized") is False, "ZERO_WORLD_AUTHORITY")
    require(gate.get("maximum_physical_steps_authorized") == 0, "ZERO_WORLD_STEP_BUDGET")
    require(gate.get("world_build_count") == 0, "ZERO_WORLD_WORLD_COUNT")
    require(gate.get("solver_step_count") == 0, "ZERO_WORLD_SOLVER_COUNT")

    thresholds = contract.get("threshold_and_margin_provenance", {})
    require(thresholds.get("threshold_change_count") == 0, "THRESHOLD_CHANGE")
    require(thresholds.get("margin_change_count") == 0, "MARGIN_CHANGE")
    require(DIGEST.fullmatch(str(thresholds.get("profile_sha256", ""))) is not None, "PROFILE_DIGEST")

    population = contract.get("finite_development_population", {})
    require(population.get("cell_count") == 1, "CELL_COUNT")
    require(population.get("arm_count") == 2, "ARM_COUNT")
    require(population.get("maximum_outer_steps_per_arm") == 1200, "ARM_BUDGET")
    require(population.get("maximum_total_outer_steps") == 2400, "TOTAL_BUDGET")
    require(population.get("same_source_attempt_limit") == 1, "ATTEMPT_LIMIT")
    require(population.get("repeatability_claimed") is False, "REPEATABILITY_BOUNDARY")
    require(population.get("population_inference_claimed") is False, "POPULATION_CLAIM")


def validate_mutation_controls(contract: dict[str, Any]) -> int:
    mutations: list[tuple[str, tuple[str, ...], Any]] = [
        ("wrong_gate", ("gate_id",), "QSDK-R24D54-MUTATED"),
        ("wrong_question", ("question_class",), "equivalence"),
        ("physical_undeclared", ("physical_question_declared",), False),
        (
            "threshold_changed",
            ("threshold_and_margin_provenance", "threshold_change_count"),
            1,
        ),
        (
            "world_authorized",
            ("complete_zero_world_gate", "physical_execution_authorized"),
            True,
        ),
        (
            "expanded_population",
            ("finite_development_population", "cell_count"),
            2,
        ),
    ]
    for mutation_id, path, replacement in mutations:
        mutated = copy.deepcopy(contract)
        target: dict[str, Any] = mutated
        for segment in path[:-1]:
            target = target[segment]
        target[path[-1]] = replacement
        try:
            validate_contract_shape(mutated)
        except AuditFailure:
            continue
        raise AuditFailure(f"CONTRACT_MUTATION_ACCEPTED:{mutation_id}")
    return len(mutations)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--contract", required=True)
    args = parser.parse_args()

    require(ROOT == EXPECTED_ROOT, f"ROOT:{ROOT}")
    git_root = subprocess.check_output(
        ["git", "rev-parse", "--show-toplevel"], cwd=ROOT, text=True
    ).strip()
    remote = subprocess.check_output(
        ["git", "remote", "get-url", "origin"], cwd=ROOT, text=True
    ).strip()
    require(Path(git_root) == EXPECTED_ROOT, f"GIT_ROOT:{git_root}")
    require(remote == EXPECTED_REMOTE, f"REMOTE:{remote}")

    contract_path = Path(args.contract).resolve()
    require(contract_path != ROOT and ROOT in contract_path.parents, "CONTRACT_OUTSIDE_REPOSITORY")
    contract = load_json(contract_path)
    validate_contract_shape(contract)
    mutation_count = validate_mutation_controls(contract)

    predecessors = contract.get("bound_predecessors", [])
    require(isinstance(predecessors, list) and len(predecessors) >= 1, "PREDECESSORS")
    for predecessor in predecessors:
        path = resolve_repo_path(str(predecessor.get("path", "")))
        expected = str(predecessor.get("raw_sha256", ""))
        require(DIGEST.fullmatch(expected) is not None, f"PREDECESSOR_DIGEST:{path}")
        require(raw_sha256(path) == expected, f"PREDECESSOR_DRIFT:{path}")
        require(predecessor.get("immutable") is True, f"PREDECESSOR_IMMUTABILITY:{path}")

    runner = contract.get("qualification_runner", {})
    patch_profile_path = resolve_repo_path(str(runner.get("patch_profile_contract_path", "")))
    require(
        raw_sha256(patch_profile_path) == runner.get("patch_profile_contract_raw_sha256"),
        "PATCH_PROFILE_DRIFT",
    )
    patch_profile = load_json(patch_profile_path).get("qualification_runner", {})
    require(bool(patch_profile.get("successor_patch_sequence")), "PATCH_SEQUENCE_MISSING")
    require(bool(patch_profile.get("successor_patched_files")), "PATCH_BINDINGS_MISSING")
    require(runner.get("audit_accepts_contract_path") is True, "AUDIT_CONTRACT_ARGUMENT")
    marker = str(runner.get("audit_pass_marker", ""))
    require(re.fullmatch(r"QSDK_R24D[0-9]+_[A-Z0-9_]+_PASS", marker) is not None, "PASS_MARKER")

    audit = contract.get("source_audit", {})
    module_path = resolve_repo_path(str(audit.get("module_path", "")))
    manifest_path = resolve_repo_path(str(audit.get("cargo_manifest_path", "")))
    crate_root_path = resolve_repo_path(str(audit.get("crate_root_path", "")))
    source = module_path.read_text(encoding="utf-8")
    manifest = manifest_path.read_text(encoding="utf-8")
    crate_root = crate_root_path.read_text(encoding="utf-8")

    preflight_token = f"pub fn {audit.get('preflight_entrypoint')}"
    physical_token = f"pub fn {audit.get('physical_entrypoint')}"
    preflight_start = source.find(preflight_token)
    physical_start = source.find(physical_token)
    require(preflight_start >= 0, "PREFLIGHT_ENTRYPOINT_MISSING")
    require(physical_start > preflight_start, "PHYSICAL_ENTRYPOINT_ORDER")
    preflight_source = source[preflight_start:physical_start]
    for token in audit.get("required_module_tokens", []):
        require(str(token) in source, f"MODULE_TOKEN_MISSING:{token}")
    for token in audit.get("preflight_forbidden_tokens", []):
        require(str(token) not in preflight_source, f"PREFLIGHT_WORLD_TOKEN:{token}")
    require(str(audit.get("cargo_feature_token")) in manifest, "CARGO_FEATURE_WIRING")
    require(str(audit.get("crate_module_token")) in crate_root, "CRATE_MODULE_WIRING")
    for token in audit.get("crate_export_tokens", []):
        require(str(token) in crate_root, f"CRATE_EXPORT_MISSING:{token}")

    physical_runner = contract.get("physical_runner", {})
    require(physical_runner.get("ghost_disabled") is True, "GHOST_DISABLED")
    require(physical_runner.get("development_requires_prior_ghost") is False, "GHOST_POLICY")
    integration = physical_runner.get("development_integration_authority", {})
    integration_path = resolve_repo_path(str(integration.get("closure_path", "")))
    require(raw_sha256(integration_path) == integration.get("closure_raw_sha256"), "INTEGRATION_DRIFT")
    require(bool(integration.get("required_true_json_pointers")), "INTEGRATION_TRUE_CONTROLS")
    require(bool(integration.get("required_false_json_pointers")), "INTEGRATION_FALSE_CONTROLS")

    inventory = contract.get("source_inventory", [])
    require(isinstance(inventory, list) and len(inventory) == len(set(inventory)), "SOURCE_INVENTORY")
    for relative in inventory:
        resolve_repo_path(str(relative))

    print(
        f"{marker} gate={contract['gate_id']} predecessors={len(predecessors)} "
        f"mutations={mutation_count} sources={len(inventory)} worlds=0 solver_steps=0"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
