#!/usr/bin/env python3
"""Fail-closed source audit for the prospective R24D17 zero-world freeze."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import subprocess
import sys
from pathlib import Path
from typing import Any, Callable


EXPECTED_ROOT = Path(r"C:\Users\Cole\CodeStuff\games\SporeSpore")
EXPECTED_REMOTE = "https://github.com/Slagathore/sporespore.git"
EXPECTED_PARENT = "7c76aa69b32511c9bcec0c77930f418f41dbc0ed"
EXPECTED_PARENT_TREE = "17d8840a781067c747f3ebf3422740f7d1b39e3f"
CONTRACT_RELATIVE = Path(
    "sdk/recovery/r24d17_native_recovery_runtime_and_physical_profile_contract_v1.json"
)
AUDIT_RELATIVE = Path("tests/test_qsdk_r24d17_native_recovery_runtime_source.py")
RUNNER_RELATIVE = Path("sdk/run_qsdk_r24d17_native_recovery_runtime_zero_world.ps1")
ABI_RELATIVE = Path("sdk/versioning/c_abi_manifest_v1.json")
SCHEMA_RELATIVE = Path("sdk/versioning/schema_registry_v1.json")

EXPECTED_THRESHOLDS: dict[str, Any] = {
    "entry_prone_height_ratio_max": 0.25,
    "entry_torso_up_dot_max": 1.0,
    "entry_prone_confirm_steps": 12,
    "entry_initial_state_match_tolerance": (
        "exact_initializer_manifest_sha256_and_canonical_pre_step_state_sha256_"
        "equality_within_each_engine_pair"
    ),
    "distal_bearing_minimum_impulse_ns": 0.019293,
    "minimum_com_height_gain_m": 0.22,
    "stance_height_ratio_min": 0.75,
    "stance_torso_up_dot_min": 0.95,
    "minimum_nonfoot_clearance_m": 0.005,
    "maximum_forbidden_contact_impulse_ns": 0.0,
    "maximum_terminal_linear_speed_m_s": 0.1,
    "maximum_terminal_angular_speed_rad_s": 0.2,
    "stance_dwell_steps": 60,
    "per_phase_timeout_steps": {
        "confirm_prone": 60,
        "establish_distal_support": 240,
        "raise_body": 600,
        "stance_handoff": 120,
        "stance_dwell": 240,
    },
    "total_timeout_steps": 1200,
    "maximum_energy_balance_residual_j": 0.25,
}


class AuditError(RuntimeError):
    """Stable source-audit failure."""


def require(condition: bool, code: str) -> None:
    if not condition:
        raise AuditError(code)


def exact(actual: Any, expected: Any, code: str) -> None:
    require(actual == expected, f"{code}:expected={expected!r}:actual={actual!r}")


def read_bytes(relative: Path) -> bytes:
    path = EXPECTED_ROOT / relative
    require(path.is_file(), f"FILE_MISSING:{relative.as_posix()}")
    return path.read_bytes()


def read_text(relative: Path) -> str:
    payload = read_bytes(relative)
    require(b"\r" not in payload, f"SOURCE_NOT_LF:{relative.as_posix()}")
    try:
        return payload.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise AuditError(f"SOURCE_NOT_UTF8:{relative.as_posix()}:{exc}") from exc


def read_json(relative: Path) -> dict[str, Any]:
    value = json.loads(read_text(relative))
    require(isinstance(value, dict), f"JSON_ROOT_INVALID:{relative.as_posix()}")
    return value


def git(*arguments: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(EXPECTED_ROOT), *arguments],
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    require(
        result.returncode == 0,
        f"GIT_FAILED:{' '.join(arguments)}:{result.stderr.strip()}",
    )
    return result.stdout.strip()


def validate_seed_cell(cell: dict[str, Any]) -> None:
    label = cell.get("seed_label")
    require(isinstance(label, str) and bool(label), "SEED_LABEL_INVALID")
    digest = hashlib.sha256(label.encode("utf-8")).hexdigest()
    exact(cell.get("seed_sha256"), f"sha256:{digest}", f"SEED_SHA:{label}")
    exact(cell.get("seed"), int(digest[:8], 16) & 0x7FFFFFFF, f"SEED_VALUE:{label}")


def validate_contract(contract: dict[str, Any]) -> None:
    exact(
        contract.get("schema_version"),
        "sporespore_qsdk_r24d17_native_recovery_runtime_and_physical_profile_contract_v1",
        "CONTRACT_SCHEMA",
    )
    exact(contract.get("gate_id"), "QSDK-R24D17", "GATE_ID")
    exact(contract.get("declaration_parent_commit"), EXPECTED_PARENT, "PARENT")
    exact(
        contract.get("status"),
        "prospective_zero_world_source_contract_physics_closed",
        "STATUS",
    )
    exact(
        contract.get("question_class"),
        "non_physical_source_conformance_no_physical_question_opened",
        "QUESTION_CLASS",
    )
    classes = contract["physical_question_classification"]
    exact(classes.get("future_repeatable_mujoco_development"), "development", "DEV_CLASS")
    exact(classes.get("future_frozen_native_engine_cohort"), "finite_decision", "HELD_CLASS")
    exact(classes.get("superiority_question_declared"), False, "NO_SUPERIORITY")
    exact(
        classes.get("equivalence_or_non_inferiority_question_declared"),
        False,
        "NO_EQUIVALENCE",
    )

    scope = contract["scope"]
    exact(scope.get("morphology_id"), "qsdk_r05_generated_s169", "MORPHOLOGY")
    exact(scope.get("arbitrary_morphology"), False, "NO_ARBITRARY")
    exact(scope.get("cross_engine_equivalence"), False, "NO_CROSS_ENGINE_EQUIVALENCE")
    exact(scope.get("population_inference"), False, "NO_POPULATION")

    bindings = contract["native_runtime_bindings"]
    exact(len(bindings), 3, "ENGINE_BINDING_COUNT")
    exact(
        [item["engine"] for item in bindings],
        ["godot_jolt4_7", "rapier_parry_native", "mujoco_native"],
        "ENGINE_ORDER",
    )
    exact([item["native_substeps_per_outer_step"] for item in bindings], [1, 1, 5], "SUBSTEPS")
    exact([item["complete_channel_count"] for item in bindings], [10, 10, 10], "CHANNELS")

    collector = contract["collector_boundary"]
    for field in (
        "complete_native_post_step_observation_required",
        "source_measurement_only",
        "native_worker_owns_sampling",
        "portable_core_owns_strict_validation",
    ):
        exact(collector.get(field), True, f"COLLECTOR_TRUE:{field}")
    for field in (
        "missing_measurement_synthesis_permitted",
        "engine_identity_exposed_to_controller",
        "current_gate_executes_native_sampling",
        "current_gate_executes_physics",
    ):
        exact(collector.get(field), False, f"COLLECTOR_FALSE:{field}")

    controller = contract["controller_candidate"]
    exact(controller.get("engine_specific_policy_branch_count"), 0, "CONTROLLER_ENGINE_BRANCH")
    exact(
        controller.get("establish_distal_support_ordered_target_positions_rad"),
        [0.6, 1.05, 0.6, 1.05, -0.6, 1.05, -0.6, 1.05],
        "CONTROLLER_TARGETS",
    )
    exact(controller.get("raise_body_ramp_steps"), 360, "RAMP_STEPS")
    exact(controller.get("physical_viability_proven"), False, "NO_CONTROLLER_PROOF")
    exact(controller.get("prone_to_standing_proven"), False, "NO_PRONE_PROOF")

    provenance = contract["geometry_and_weight_provenance"]
    exact(provenance.get("total_mass_kg"), 4.72, "TOTAL_MASS")
    exact(provenance.get("nominal_static_per_foot_outer_step_impulse_ns"), 0.096465, "STATIC_IMPULSE")
    exact(provenance.get("empirical_recovery_outcome_used"), False, "NO_EMPIRICAL_SELECTION")
    exact(provenance.get("br13_numeric_threshold_used"), False, "NO_BR13_NUMERIC_AUTHORITY")

    threshold_records = contract["threshold_profile"]["thresholds"]
    exact(len(threshold_records), 16, "THRESHOLD_COUNT")
    thresholds = {item["threshold_id"]: item for item in threshold_records}
    exact(set(thresholds), set(EXPECTED_THRESHOLDS), "THRESHOLD_IDS")
    for threshold_id, expected in EXPECTED_THRESHOLDS.items():
        item = thresholds[threshold_id]
        exact(item.get("value"), expected, f"THRESHOLD_VALUE:{threshold_id}")
        require(len(str(item.get("provenance", ""))) >= 20, f"PROVENANCE_MISSING:{threshold_id}")
        require(len(str(item.get("adequacy", ""))) >= 50, f"ADEQUACY_MISSING:{threshold_id}")
    exact(
        contract["threshold_profile"].get("post_outcome_rethresholding_permitted"),
        False,
        "NO_RETHRESHOLD",
    )

    cohorts = contract["cohort_profile"]
    development = cohorts["development"]
    held_out = cohorts["held_out"]
    exact(development.get("question_class"), "development", "DEV_COHORT_CLASS")
    exact(development.get("cell_count"), 3, "DEV_CELL_COUNT")
    exact(len(development.get("cells", [])), 3, "DEV_CELL_RECORDS")
    exact(held_out.get("question_class"), "finite_decision", "HELD_COHORT_CLASS")
    exact(held_out.get("cell_count"), 9, "HELD_CELL_COUNT")
    exact(len(held_out.get("cells", [])), 9, "HELD_CELL_RECORDS")
    exact(held_out.get("development_access_permitted"), False, "HELD_ACCESS")
    all_cells = [*development["cells"], *held_out["cells"]]
    for cell in all_cells:
        validate_seed_cell(cell)
    seeds = [cell["seed"] for cell in all_cells]
    exact(len(set(seeds)), 12, "SEED_UNIQUENESS")

    gate = contract["zero_world_gate"]
    exact(gate.get("official_qualification_run_count"), 1, "QUALIFICATION_RUN_COUNT")
    exact(len(gate.get("required_mutation_refusals", [])), 9, "MUTATION_COUNT")
    for field in (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
    ):
        exact(gate.get(field), 0, f"ZERO_WORLD_COUNT:{field}")

    claims = contract["claim_boundary"]
    for field in (
        "native_runtime_collection_executed",
        "physical_question_opened",
        "controller_physical_viability_proven",
        "prone_to_standing_claimed",
        "cross_engine_recovery_claimed",
        "cross_engine_equivalence_claimed",
        "sdk1_milestone_advanced",
        "physical_acceptance_authority",
        "release_authority",
    ):
        exact(claims.get(field), False, f"CLAIM_BOUNDARY:{field}")


def validate_publication_surfaces() -> None:
    abi = read_json(ABI_RELATIVE)
    registry = read_json(SCHEMA_RELATIVE)
    symbols = [item["name"] for item in abi["symbols"]]
    exact(len(symbols), 35, "ABI_SYMBOL_COUNT")
    exact(len(set(symbols)), 35, "ABI_SYMBOL_UNIQUENESS")
    for symbol in (
        "ss_recovery_development_profile_v1_json",
        "ss_recovery_collect_native_v1_json",
        "ss_recovery_plan_control_v1_json",
    ):
        require(symbol in symbols, f"ABI_SYMBOL_MISSING:{symbol}")
    schemas = [item["schema_id"] for item in registry["schemas"]]
    exact(len(schemas), 49, "SCHEMA_COUNT")
    exact(len(set(schemas)), 49, "SCHEMA_UNIQUENESS")
    for schema in (
        "sporespore_recovery_native_collection_request_v1",
        "sporespore_recovery_control_request_v1",
    ):
        require(schema in schemas, f"SCHEMA_MISSING:{schema}")

    required_markers = {
        Path("sdk/core/src/recovery_runtime.rs"): (
            "pub fn recovery_development_profile_v1()",
            "pub fn collect_native_recovery_observation_v1(",
            "pub fn plan_recovery_control_v1(",
            "engine_specific_policy_branch_count: 0",
            "world_attempt_count: 0",
            "prone_to_standing_claimed: false",
        ),
        Path("sdk/core/src/ffi.rs"): (
            "ss_recovery_development_profile_v1_json",
            "ss_recovery_collect_native_v1_json",
            "ss_recovery_plan_control_v1_json",
        ),
        Path("sdk/python/sporespore_locomotion.py"): (
            "def recovery_development_profile_v1(",
            "def recovery_collect_native_v1(",
            "def recovery_plan_control_v1(",
        ),
        Path("sdk/adapters/godot/src/lib.rs"): (
            "fn recovery_development_profile_v1_json(",
            "fn recovery_collect_native_v1_json(",
            "fn recovery_plan_control_v1_json(",
        ),
        Path("sdk/adapters/godot/gdscript/recovery_runtime.gd"): (
            "static func development_profile_v1(",
            "static func collect_native_v1(",
            "static func plan_control_v1(",
        ),
        Path("sdk/adapters/rapier/src/recovery_runtime.rs"): (
            "pub fn rapier_recovery_runtime_binding_v1(",
            "pub fn collect_rapier_native_recovery_observation_v1(",
            "pub fn plan_rapier_recovery_control_v1(",
        ),
        Path(
            "sdk/adapters/mujoco/sporespore_mujoco_adapter/recovery_runtime.py"
        ): (
            "def runtime_binding_v1(",
            "def collect_native_v1(",
            "def plan_control_v1(",
            'NATIVE_SUBSTEPS_PER_OUTER_STEP = 5',
        ),
    }
    for relative, markers in required_markers.items():
        text = read_text(relative)
        for marker in markers:
            require(marker in text, f"SOURCE_MARKER_MISSING:{relative.as_posix()}:{marker}")
    mujoco_surface = read_text(
        Path("sdk/adapters/mujoco/sporespore_mujoco_adapter/recovery_runtime.py")
    )
    require("\nimport mujoco" not in mujoco_surface, "MUJOCO_IMPORT_FORBIDDEN")
    require("mj_step(" not in mujoco_surface, "MUJOCO_STEP_FORBIDDEN")


def source_relatives(contract: dict[str, Any]) -> tuple[Path, ...]:
    relatives = {
        Path(value) for value in contract.get("source_inventory", [])
    }
    relatives.update((CONTRACT_RELATIVE, AUDIT_RELATIVE, RUNNER_RELATIVE))
    return tuple(sorted(relatives, key=lambda path: path.as_posix()))


def validate_repository(require_committed: bool, relatives: tuple[Path, ...]) -> tuple[str, str]:
    exact(Path(git("rev-parse", "--show-toplevel")).resolve(), EXPECTED_ROOT.resolve(), "ROOT")
    exact(git("remote", "get-url", "origin"), EXPECTED_REMOTE, "REMOTE")
    exact(git("branch", "--show-current"), "main", "BRANCH")
    head = git("rev-parse", "HEAD")
    tree = git("rev-parse", "HEAD^{tree}")
    if require_committed:
        exact(git("rev-parse", "HEAD^"), EXPECTED_PARENT, "FREEZE_PARENT")
        for relative in relatives:
            path = relative.as_posix()
            exact(git("hash-object", "--", path), git("rev-parse", f"HEAD:{path}"), f"DIRTY:{path}")
    else:
        exact(head, EXPECTED_PARENT, "PROSPECTIVE_PARENT")
        exact(tree, EXPECTED_PARENT_TREE, "PROSPECTIVE_PARENT_TREE")
    return head, tree


def run_contract_mutations(contract: dict[str, Any]) -> int:
    mutations: tuple[tuple[str, Callable[[dict[str, Any]], None]], ...] = (
        ("question_class", lambda value: value.__setitem__("question_class", "development")),
        ("engine_count", lambda value: value["native_runtime_bindings"].pop()),
        ("engine_branch", lambda value: value["controller_candidate"].__setitem__("engine_specific_policy_branch_count", 1)),
        ("threshold", lambda value: value["threshold_profile"]["thresholds"][0].__setitem__("value", 0.5)),
        ("threshold_provenance", lambda value: value["threshold_profile"]["thresholds"][0].__setitem__("provenance", "")),
        ("rethreshold", lambda value: value["threshold_profile"].__setitem__("post_outcome_rethresholding_permitted", True)),
        ("held_access", lambda value: value["cohort_profile"]["held_out"].__setitem__("development_access_permitted", True)),
        ("seed", lambda value: value["cohort_profile"]["development"]["cells"][0].__setitem__("seed", 1)),
        ("world", lambda value: value["zero_world_gate"].__setitem__("world_attempt_count", 1)),
        ("claim", lambda value: value["claim_boundary"].__setitem__("prone_to_standing_claimed", True)),
    )
    rejected = 0
    for mutation_id, mutate in mutations:
        candidate = copy.deepcopy(contract)
        mutate(candidate)
        try:
            validate_contract(candidate)
        except AuditError:
            rejected += 1
        else:
            raise AuditError(f"CONTRACT_MUTATION_SURVIVED:{mutation_id}")
    return rejected


def main() -> int:
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--allow-prospective-uncommitted", action="store_true")
    mode.add_argument("--require-committed-source", action="store_true")
    args = parser.parse_args()

    contract = read_json(CONTRACT_RELATIVE)
    relatives = source_relatives(contract)
    head, tree = validate_repository(args.require_committed_source, relatives)
    validate_contract(contract)
    validate_publication_surfaces()
    rejected = run_contract_mutations(contract)
    for relative in relatives:
        read_bytes(relative)
    print(
        "QSDK_R24D17_RECOVERY_RUNTIME_SOURCE_PASS "
        f"mode={'committed' if args.require_committed_source else 'prospective'} "
        f"head={head} tree={tree} source_bindings={len(relatives)} "
        f"engines=3 channels=10/10 controller_mutations={rejected}/10 "
        "development_cells=3 heldout_cells=9 worlds=0 builds=0 solver_steps=0"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AuditError, KeyError, TypeError, ValueError, json.JSONDecodeError) as exc:
        print(f"QSDK_R24D17_RECOVERY_RUNTIME_SOURCE_FAIL {exc}", file=sys.stderr)
        raise SystemExit(1) from exc
