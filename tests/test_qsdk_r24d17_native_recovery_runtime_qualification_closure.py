#!/usr/bin/env python3
"""Verify the immutable R24D17 zero-world qualification closure."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import subprocess
import sys
from functools import lru_cache
from pathlib import Path
from typing import Any, Callable


EXPECTED_ROOT = Path(r"C:\Users\Cole\CodeStuff\games\SporeSpore")
EXPECTED_EVIDENCE_ROOT = Path(r"C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence")
EXPECTED_REMOTE = "https://github.com/Slagathore/sporespore.git"
FREEZE_COMMIT = "576e70861d77f1ea547344c5e4fcf10ed09fe954"
FREEZE_TREE = "72e2f352aa7bf19e79fe8ff6986d991bceb10e67"
FREEZE_PARENT = "7c76aa69b32511c9bcec0c77930f418f41dbc0ed"
CONTRACT_RELATIVE = Path(
    "sdk/recovery/r24d17_native_recovery_runtime_and_physical_profile_contract_v1.json"
)
SOURCE_AUDIT_RELATIVE = Path("tests/test_qsdk_r24d17_native_recovery_runtime_source.py")
RUNNER_RELATIVE = Path("sdk/run_qsdk_r24d17_native_recovery_runtime_zero_world.ps1")
CLOSURE_RELATIVE = Path(
    "sdk/recovery/r24d17_native_recovery_runtime_qualification_closure_v1.json"
)
AUDIT_RELATIVE = Path(
    "tests/test_qsdk_r24d17_native_recovery_runtime_qualification_closure.py"
)
RUN_NAME = "qsdk-r24d17-qualification-20260827T024026086Z-576e7086"
RUN_ROOT = EXPECTED_EVIDENCE_ROOT / RUN_NAME
EXPECTED_RECEIPT_SHA256 = (
    "0860fd4594c4f25a958f07fd369b6816e54042a88d1dabb14367fd071d56cbbf"
)
EXPECTED_RECEIPT_BYTES = 17727
EXPECTED_ARTIFACTS = {
    "01-source-audit.stderr.log": (
        "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
        0,
    ),
    "01-source-audit.stdout.log": (
        "24e8081916ebe765451cf78ab89b15356a01d830b29006d66ded282e22cdbb2a",
        289,
    ),
    "02-cargo-build.stderr.log": (
        "e25b02ff5e9353a237f866bad694673b318c5999587899e780b0c18ba422521b",
        278,
    ),
    "02-cargo-build.stdout.log": (
        "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
        0,
    ),
    "03-core-tests.stderr.log": (
        "cd5353237e713ab8be130e7d5bf4c07087a6d627ad7ce446f17a0a831dbd7bae",
        179,
    ),
    "03-core-tests.stdout.log": (
        "b2fabd4eeed423d4252fc652e4eabb1bf6c1aa16b4da538c0e015e2dacb7c988",
        601,
    ),
    "04-rapier-tests.stderr.log": (
        "db0250b7510b7a725ca83b544d5dfe0c7813b68779c8749e69701c97c13a3d6a",
        386,
    ),
    "04-rapier-tests.stdout.log": (
        "2865e75c988ea10cb6c6d7626245e620d1b008ce54d077091956384f1cc6c1df",
        284,
    ),
    "05-python-tests.stderr.log": (
        "8c27e85f3ad9fe49c9ee0fb3853114fa6ec5df85a2dacbd2084717cf90cd7e66",
        794,
    ),
    "05-python-tests.stdout.log": (
        "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
        0,
    ),
    "06-godot-engine.log": (
        "8d05d5f99f4a1914305ab71925d779606e1b15f9cd6718d65105469e1da36e2e",
        600,
    ),
    "06-godot.stderr.log": (
        "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
        0,
    ),
    "06-godot.stdout.log": (
        "31be241c87d37488239c35878d5e90a62c53bbc2e700ab1ff39d2845be56a2cf",
        706,
    ),
    "receipt.json": (EXPECTED_RECEIPT_SHA256, EXPECTED_RECEIPT_BYTES),
}


class AuditError(RuntimeError):
    pass


def require(condition: bool, code: str) -> None:
    if not condition:
        raise AuditError(code)


def exact(actual: Any, expected: Any, code: str) -> None:
    require(actual == expected, f"{code}: expected={expected!r} actual={actual!r}")


def digest_bytes(payload: bytes) -> tuple[str, int]:
    return hashlib.sha256(payload).hexdigest(), len(payload)


def digest(path: Path) -> tuple[str, int]:
    require(path.is_file(), f"FILE_MISSING:{path}")
    return digest_bytes(path.read_bytes())


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(value, dict), f"JSON_ROOT_INVALID:{path}")
    return value


@lru_cache(maxsize=None)
def git_bytes(*arguments: str) -> bytes:
    result = subprocess.run(
        ["git", "-C", str(EXPECTED_ROOT), *arguments],
        check=False,
        capture_output=True,
    )
    require(
        result.returncode == 0,
        f"GIT_FAILED:{' '.join(arguments)}:{result.stderr.decode(errors='replace').strip()}",
    )
    return result.stdout


def git(*arguments: str) -> str:
    return git_bytes(*arguments).decode("utf-8", errors="replace").strip()


@lru_cache(maxsize=1)
def frozen_contract() -> dict[str, Any]:
    payload = git_bytes("show", f"{FREEZE_COMMIT}:{CONTRACT_RELATIVE.as_posix()}")
    value = json.loads(payload.decode("utf-8"))
    require(isinstance(value, dict), "FROZEN_CONTRACT_ROOT")
    return value


def expected_source_paths(contract: dict[str, Any]) -> set[str]:
    paths = {Path(value).as_posix() for value in contract["source_inventory"]}
    paths.update(
        {
            CONTRACT_RELATIVE.as_posix(),
            SOURCE_AUDIT_RELATIVE.as_posix(),
            RUNNER_RELATIVE.as_posix(),
        }
    )
    exact(len(paths), 25, "EXPECTED_SOURCE_PATH_COUNT")
    return paths


def validate_frozen_contract(contract: dict[str, Any]) -> None:
    exact(
        contract.get("schema_version"),
        "sporespore_qsdk_r24d17_native_recovery_runtime_and_physical_profile_contract_v1",
        "CONTRACT_SCHEMA",
    )
    exact(contract.get("gate_id"), "QSDK-R24D17", "CONTRACT_GATE")
    exact(
        contract.get("declaration_parent_commit"),
        FREEZE_PARENT,
        "CONTRACT_PARENT",
    )
    exact(
        contract.get("question_class"),
        "non_physical_source_conformance_no_physical_question_opened",
        "CONTRACT_QUESTION_CLASS",
    )
    physical_classes = contract["physical_question_classification"]
    exact(
        physical_classes.get("current_gate"),
        "not_applicable_no_physical_question_opened",
        "CURRENT_PHYSICAL_CLASS",
    )
    exact(
        physical_classes.get("future_repeatable_mujoco_development"),
        "development",
        "DEVELOPMENT_CLASS",
    )
    exact(
        physical_classes.get("future_frozen_native_engine_cohort"),
        "finite_decision",
        "HELD_OUT_CLASS",
    )
    exact(physical_classes.get("superiority_question_declared"), False, "SUPERIORITY")
    exact(
        physical_classes.get("equivalence_or_non_inferiority_question_declared"),
        False,
        "EQUIVALENCE",
    )

    bindings = contract["native_runtime_bindings"]
    exact(len(bindings), 3, "NATIVE_ENGINE_COUNT")
    exact(
        {entry["engine"] for entry in bindings},
        {"godot_jolt4_7", "rapier_parry_native", "mujoco_native"},
        "NATIVE_ENGINES",
    )
    for entry in bindings:
        exact(entry.get("complete_channel_count"), 10, f"CHANNELS:{entry['engine']}")

    collector = contract["collector_boundary"]
    exact(
        collector.get("complete_native_post_step_observation_required"),
        True,
        "COMPLETE_OBSERVATION",
    )
    exact(
        collector.get("missing_measurement_synthesis_permitted"), False, "NO_SYNTHESIS"
    )
    exact(
        collector.get("engine_identity_exposed_to_controller"), False, "ENGINE_NEUTRAL"
    )
    exact(
        collector.get("current_gate_executes_native_sampling"),
        False,
        "NO_NATIVE_SAMPLING",
    )
    exact(collector.get("current_gate_executes_physics"), False, "NO_CONTRACT_PHYSICS")

    controller = contract["controller_candidate"]
    exact(
        controller.get("controller_id"),
        "sporespore_exact_s169_prone_to_standing_controller_v1",
        "CONTROLLER_ID",
    )
    exact(
        controller.get("engine_specific_policy_branch_count"), 0, "CONTROLLER_BRANCHES"
    )
    exact(controller.get("physical_viability_proven"), False, "CONTROLLER_VIABILITY")
    exact(controller.get("prone_to_standing_proven"), False, "CONTROLLER_GETUP")

    thresholds = contract["threshold_profile"]["thresholds"]
    exact(len(thresholds), 16, "THRESHOLD_COUNT")
    exact(
        len({entry["threshold_id"] for entry in thresholds}),
        16,
        "THRESHOLD_IDS",
    )
    for entry in thresholds:
        require(
            bool(str(entry.get("provenance", "")).strip()),
            f"THRESHOLD_PROVENANCE:{entry['threshold_id']}",
        )
        require(
            bool(str(entry.get("adequacy", "")).strip()),
            f"THRESHOLD_ADEQUACY:{entry['threshold_id']}",
        )
    exact(
        contract["threshold_profile"].get("post_outcome_rethresholding_permitted"),
        False,
        "NO_RETHRESHOLD",
    )

    cohorts = contract["cohort_profile"]
    development = cohorts["development"]
    held_out = cohorts["held_out"]
    exact(development.get("question_class"), "development", "DEVELOPMENT_QUESTION")
    exact(development.get("cell_count"), 3, "DEVELOPMENT_CELLS")
    exact(len(development.get("cells", [])), 3, "DEVELOPMENT_CELL_ROWS")
    exact(held_out.get("question_class"), "finite_decision", "HELD_OUT_QUESTION")
    exact(held_out.get("engine_count"), 3, "HELD_OUT_ENGINES")
    exact(held_out.get("cell_count"), 9, "HELD_OUT_CELLS")
    exact(len(held_out.get("cells", [])), 9, "HELD_OUT_CELL_ROWS")
    exact(held_out.get("development_access_permitted"), False, "HELD_OUT_ACCESS")
    exact(
        len({cell["seed"] for cell in development["cells"] + held_out["cells"]}),
        12,
        "SEED_UNIQUENESS",
    )

    gate = contract["zero_world_gate"]
    exact(gate.get("complete_before_physics"), True, "ZERO_WORLD_REQUIRED")
    exact(gate.get("required_engine_identities"), 3, "GATE_ENGINE_COUNT")
    exact(gate.get("required_capability_channels_per_engine"), 10, "GATE_CHANNELS")
    exact(len(gate.get("required_mutation_refusals", [])), 9, "GATE_MUTATIONS")
    for field in (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
    ):
        exact(gate.get(field), 0, f"GATE_ZERO:{field}")


def validate_closure(closure: dict[str, Any], verify_files: bool = True) -> None:
    exact(
        closure.get("schema_version"),
        "sporespore_qsdk_r24d17_native_recovery_runtime_qualification_closure_v1",
        "SCHEMA",
    )
    exact(closure.get("gate_id"), "QSDK-R24D17", "GATE")
    exact(
        closure.get("question_class"),
        "non_physical_source_conformance",
        "QUESTION_CLASS",
    )
    exact(
        closure.get("status"),
        "qualified_native_validation_surfaces_controller_and_prospective_"
        "physical_profile_physics_not_opened",
        "STATUS",
    )

    contract = frozen_contract()
    validate_frozen_contract(contract)
    source = closure["source_freeze"]
    exact(source.get("repository_root"), EXPECTED_ROOT.as_posix(), "SOURCE_ROOT")
    exact(source.get("remote"), EXPECTED_REMOTE, "SOURCE_REMOTE")
    exact(source.get("branch"), "main", "SOURCE_BRANCH")
    exact(source.get("commit"), FREEZE_COMMIT, "FREEZE_COMMIT")
    exact(source.get("tree_git_oid"), FREEZE_TREE, "FREEZE_TREE")
    exact(source.get("parent_commit"), FREEZE_PARENT, "FREEZE_PARENT")
    exact(
        source.get("local_upstream_cached_live_equal_at_qualification"),
        True,
        "REMOTE_EQUALITY",
    )
    exact(source.get("worktree_clean_at_qualification"), True, "CLEAN_SOURCE")
    exact(source.get("worktree_count"), 1, "WORKTREE_COUNT")
    exact(source.get("source_inventory_count"), 25, "SOURCE_COUNT")
    bindings = source.get("source_bindings", [])
    expected_paths = expected_source_paths(contract)
    exact(len(bindings), 25, "SOURCE_BINDING_COUNT")
    exact({entry["path"] for entry in bindings}, expected_paths, "SOURCE_PATHS")
    for entry in bindings:
        relative = entry["path"]
        payload = git_bytes("show", f"{FREEZE_COMMIT}:{relative}")
        expected_sha, expected_bytes = digest_bytes(payload)
        expected_blob = git("rev-parse", f"{FREEZE_COMMIT}:{relative}")
        exact(
            entry.get("raw_sha256"), f"sha256:{expected_sha}", f"SOURCE_SHA:{relative}"
        )
        exact(entry.get("byte_length"), expected_bytes, f"SOURCE_BYTES:{relative}")
        exact(entry.get("git_blob_oid"), expected_blob, f"SOURCE_BLOB:{relative}")
    for field in (
        "historical_r24d16_closure_rewritten",
        "observed_campaign_rewritten",
        "observed_threshold_rewritten",
        "observed_selector_rewritten",
        "observed_evaluator_rewritten",
        "observed_result_rewritten",
    ):
        exact(source.get(field), False, f"SOURCE_IMMUTABILITY:{field}")

    qualification = closure["qualification"]
    exact(
        qualification.get("run_id"),
        RUN_NAME.removeprefix("qsdk-r24d17-qualification-"),
        "RUN_ID",
    )
    exact(qualification.get("run_root"), RUN_ROOT.as_posix(), "RUN_ROOT")
    exact(
        qualification.get("receipt_raw_sha256"),
        f"sha256:{EXPECTED_RECEIPT_SHA256}",
        "RECEIPT_SHA",
    )
    exact(
        qualification.get("receipt_byte_length"),
        EXPECTED_RECEIPT_BYTES,
        "RECEIPT_BYTES",
    )
    exact(qualification.get("process_count"), 6, "PROCESS_COUNT")
    exact(qualification.get("passed_process_count"), 6, "PASSED_PROCESSES")
    exact(qualification.get("core_recovery_test_count"), 5, "CORE_TESTS")
    exact(qualification.get("rapier_surface_test_count"), 2, "RAPIER_TESTS")
    exact(qualification.get("python_test_count"), 4, "PYTHON_TESTS")
    exact(qualification.get("godot_process_count"), 1, "GODOT_PROCESSES")
    exact(qualification.get("native_engine_identity_count"), 3, "QUALIFIED_ENGINES")
    exact(
        qualification.get("required_channel_count_per_engine"), 10, "QUALIFIED_CHANNELS"
    )
    exact(qualification.get("runtime_mutation_refusal_count"), 8, "RUNTIME_MUTATIONS")
    exact(
        qualification.get("controller_mutation_refusal_count"),
        1,
        "CONTROLLER_MUTATIONS",
    )
    exact(
        qualification.get("development_cell_count"),
        3,
        "QUALIFICATION_DEVELOPMENT_CELLS",
    )
    exact(qualification.get("held_out_cell_count"), 9, "QUALIFICATION_HELD_OUT_CELLS")
    exact(
        qualification.get("held_out_cells_executed"),
        0,
        "QUALIFICATION_HELD_OUT_EXECUTION",
    )
    exact(qualification.get("terminal_receipt_present"), True, "TERMINAL_RECEIPT")
    exact(qualification.get("same_freeze_qualification_consumed"), True, "CONSUMED")
    exact(
        qualification.get("same_freeze_qualification_rerun_permitted"),
        False,
        "NO_RERUN",
    )
    exact(
        qualification.get("runner_process_artifact_reference_count"),
        12,
        "PROCESS_ARTIFACTS",
    )
    exact(qualification.get("retained_file_reference_count"), 14, "RETAINED_FILES")
    exact(qualification.get("unique_retained_artifact_count"), 11, "UNIQUE_ARTIFACTS")
    exact(qualification.get("retained_file_total_byte_length"), 21844, "RETAINED_BYTES")
    exact(
        qualification.get("all_retained_files_content_addressed_at_closure"),
        True,
        "CAS_COMPLETE",
    )
    inventory = qualification.get("artifact_inventory", [])
    exact(len(inventory), 14, "ARTIFACT_COUNT")
    exact(
        {entry["relative_path"] for entry in inventory},
        set(EXPECTED_ARTIFACTS),
        "ARTIFACT_PATHS",
    )
    for entry in inventory:
        relative = entry["relative_path"]
        expected_sha, expected_bytes = EXPECTED_ARTIFACTS[relative]
        exact(
            entry.get("raw_sha256"),
            f"sha256:{expected_sha}",
            f"ARTIFACT_SHA:{relative}",
        )
        exact(entry.get("byte_length"), expected_bytes, f"ARTIFACT_BYTES:{relative}")
        if verify_files:
            exact(
                digest(RUN_ROOT / relative),
                (expected_sha, expected_bytes),
                f"ARTIFACT_FILE:{relative}",
            )
            cas_root = EXPECTED_EVIDENCE_ROOT / "artifacts" / "sha256" / expected_sha
            exact(
                digest(cas_root / "payload.bin"),
                (expected_sha, expected_bytes),
                f"CAS_PAYLOAD:{relative}",
            )
            manifest = load_json(cas_root / "manifest.json")
            exact(
                manifest.get("schema_version"),
                "sporespore_content_addressed_artifact_manifest_v1",
                f"CAS_SCHEMA:{relative}",
            )
            exact(manifest.get("algorithm"), "sha256", f"CAS_ALGORITHM:{relative}")
            exact(
                manifest.get("sha256"), f"sha256:{expected_sha}", f"CAS_SHA:{relative}"
            )
            exact(manifest.get("byte_length"), expected_bytes, f"CAS_BYTES:{relative}")
            exact(manifest.get("payload_name"), "payload.bin", f"CAS_NAME:{relative}")
    if verify_files:
        actual_files = {path.name for path in RUN_ROOT.iterdir() if path.is_file()}
        exact(actual_files, set(EXPECTED_ARTIFACTS), "RUN_FILE_POPULATION")

    qualified = closure["qualified_source_contract"]
    exact(len(qualified.get("native_engine_identities", [])), 3, "DECISION_ENGINES")
    exact(
        qualified.get("complete_native_post_step_channels_per_engine"),
        10,
        "DECISION_CHANNELS",
    )
    for field in (
        "native_observation_validation_kernel_qualified",
        "native_adapter_collection_surface_qualified",
        "public_rust_c_python_godot_surfaces_qualified",
        "same_engine_neutral_command_digest_across_three_declared_identities",
        "matched_zero_no_actuation_qualified",
        "stance_handoff_no_recovery_actuation_qualified",
        "unknown_controller_refusal_qualified",
    ):
        exact(qualified.get(field), True, f"QUALIFIED_SOURCE:{field}")
    exact(
        qualified.get("native_runtime_observation_collection_executed"),
        False,
        "NO_NATIVE_COLLECTION",
    )
    exact(
        qualified.get("controller_physical_viability_proven"),
        False,
        "NO_CONTROLLER_VIABILITY",
    )

    profile = closure["prospective_physical_profile"]
    exact(profile.get("threshold_count"), 16, "PROFILE_THRESHOLDS")
    exact(profile.get("threshold_provenance_count"), 16, "PROFILE_PROVENANCE")
    exact(profile.get("threshold_adequacy_argument_count"), 16, "PROFILE_ADEQUACY")
    exact(
        profile.get("thresholds_frozen_before_physical_outcome"), True, "PROFILE_FROZEN"
    )
    exact(
        profile.get("post_outcome_rethresholding_permitted"),
        False,
        "PROFILE_NO_RETHRESHOLD",
    )
    exact(
        profile.get("development_question_class"),
        "development",
        "PROFILE_DEVELOPMENT_CLASS",
    )
    exact(profile.get("development_cell_count"), 3, "PROFILE_DEVELOPMENT_CELLS")
    exact(profile.get("development_engine_count"), 1, "PROFILE_DEVELOPMENT_ENGINES")
    exact(
        profile.get("held_out_question_class"),
        "finite_decision",
        "PROFILE_HELD_OUT_CLASS",
    )
    exact(profile.get("held_out_engine_count"), 3, "PROFILE_HELD_OUT_ENGINES")
    exact(profile.get("held_out_cell_count"), 9, "PROFILE_HELD_OUT_CELLS")
    exact(profile.get("held_out_cells_executed"), 0, "PROFILE_HELD_OUT_EXECUTION")
    exact(
        profile.get("held_out_seed_use_during_development_permitted"),
        False,
        "PROFILE_HELD_OUT_ACCESS",
    )
    exact(profile.get("superiority_margin_count"), 0, "PROFILE_SUPERIORITY")
    exact(
        profile.get("equivalence_or_non_inferiority_margin_count"),
        0,
        "PROFILE_EQUIVALENCE",
    )
    exact(profile.get("population_claim_count"), 0, "PROFILE_POPULATION")

    provenance = closure["decision_rule_provenance"]
    exact(
        provenance.get("contract_selected_before_qualification"),
        True,
        "PRESELECTED_CONTRACT",
    )
    exact(
        provenance.get("threshold_values_changed_after_qualification"),
        False,
        "UNCHANGED_THRESHOLDS",
    )
    exact(
        provenance.get("cohort_membership_changed_after_qualification"),
        False,
        "UNCHANGED_COHORT",
    )
    exact(provenance.get("decision_rule_applied_without_change"), True, "DECISION_RULE")

    decision = closure["decision"]
    exact(
        decision.get("outcome"),
        "qualify_native_validation_surfaces_controller_and_prospective_physical_profile",
        "OUTCOME",
    )
    for field in (
        "native_observation_validation_surfaces_qualified",
        "native_adapter_collection_surfaces_qualified",
        "deterministic_controller_candidate_qualified_for_physical_development",
        "prospective_threshold_and_cohort_profile_qualified",
    ):
        exact(decision.get(field), True, f"POSITIVE_DECISION:{field}")
    for field in (
        "physical_route_implemented",
        "native_runtime_observation_collection_executed",
        "controller_physical_viability_proven",
        "physical_execution_authorized",
    ):
        exact(decision.get(field), False, f"NEGATIVE_DECISION:{field}")

    next_boundary = closure["next_boundary"]
    exact(next_boundary.get("gate_id"), "QSDK-R24D18", "NEXT_GATE")
    exact(next_boundary.get("question_class"), "development", "NEXT_CLASS")
    exact(
        next_boundary.get("distinct_prospective_physical_declaration_required"),
        True,
        "NEXT_DECLARATION",
    )
    exact(
        next_boundary.get("complete_zero_world_gate_required"), True, "NEXT_ZERO_WORLD"
    )
    exact(
        next_boundary.get("held_out_cells_must_remain_unopened"), True, "NEXT_HELD_OUT"
    )
    for field in (
        "physical_execution_authorized_by_this_closure",
        "recovery_world_authorized_by_this_closure",
        "prone_to_standing_world_authorized_by_this_closure",
    ):
        exact(next_boundary.get(field), False, f"NEXT_AUTHORITY:{field}")

    claims = closure["claims"]
    for field in (
        "r24d17_zero_world_source_contract_complete",
        "native_observation_validation_surfaces_qualified",
        "deterministic_controller_candidate_implemented",
        "prospective_threshold_profile_frozen",
        "prospective_cohorts_frozen",
    ):
        exact(claims.get(field), True, f"POSITIVE_CLAIM:{field}")
    for field in (
        "new_physical_world_opened",
        "new_model_constructed",
        "new_solver_step_executed",
        "native_runtime_observation_collection_executed",
        "controller_physical_viability_proven",
        "recovery_world_opened",
        "prone_to_standing_world_opened",
        "turning_claim_changed",
        "cross_engine_recovery_claimed",
        "cross_engine_equivalence_claimed",
        "q_sdk_r24_satisfied",
        "physical_acceptance_authority",
        "release_authority",
    ):
        exact(claims.get(field), False, f"NEGATIVE_CLAIM:{field}")
    exact(claims.get("sdk1_milestone_score_before"), "11/20", "SDK1_BEFORE")
    exact(claims.get("sdk1_milestone_score_after"), "11/20", "SDK1_AFTER")
    exact(claims.get("full_program_score_before"), "11/25", "FULL_BEFORE")
    exact(claims.get("full_program_score_after"), "11/25", "FULL_AFTER")
    exact(closure.get("closure_audit_path"), AUDIT_RELATIVE.as_posix(), "AUDIT_PATH")

    if verify_files:
        receipt = load_json(RUN_ROOT / "receipt.json")
        exact(
            receipt.get("schema_version"),
            "sporespore_qsdk_r24d17_native_recovery_runtime_zero_world_receipt_v1",
            "RECEIPT_SCHEMA",
        )
        exact(receipt.get("gate_id"), "QSDK-R24D17", "RECEIPT_GATE")
        exact(receipt.get("run_id"), qualification.get("run_id"), "RECEIPT_RUN")
        exact(receipt.get("mode"), "Qualification", "RECEIPT_MODE")
        exact(
            receipt.get("status"),
            "qualification_passed_physics_not_opened",
            "RECEIPT_STATUS",
        )
        exact(receipt["source_boundary"].get("head"), FREEZE_COMMIT, "RECEIPT_HEAD")
        exact(
            receipt["source_boundary"].get("tree_git_oid"), FREEZE_TREE, "RECEIPT_TREE"
        )
        exact(receipt["source_boundary"].get("clean_pushed"), True, "RECEIPT_CLEAN")
        exact(
            receipt["contract"].get("raw_sha256"),
            source_binding_sha(closure, CONTRACT_RELATIVE),
            "RECEIPT_CONTRACT_SHA",
        )
        exact(receipt.get("process_count"), 6, "RECEIPT_PROCESSES")
        exact(len(receipt.get("processes", [])), 6, "RECEIPT_PROCESS_ROWS")
        exact(
            all(process.get("ok") is True for process in receipt["processes"]),
            True,
            "RECEIPT_PROCESS_PASS",
        )
        exact(receipt.get("core_recovery_test_count"), 5, "RECEIPT_CORE_TESTS")
        exact(receipt.get("rapier_surface_test_count"), 2, "RECEIPT_RAPIER_TESTS")
        exact(receipt.get("python_test_count"), 4, "RECEIPT_PYTHON_TESTS")
        exact(receipt.get("godot_process_count"), 1, "RECEIPT_GODOT")
        exact(receipt.get("native_engine_identity_count"), 3, "RECEIPT_ENGINES")
        exact(receipt.get("required_channel_count_per_engine"), 10, "RECEIPT_CHANNELS")
        exact(
            receipt.get("runtime_mutation_refusal_count"),
            8,
            "RECEIPT_RUNTIME_MUTATIONS",
        )
        exact(
            receipt.get("controller_mutation_refusal_count"),
            1,
            "RECEIPT_CONTROLLER_MUTATIONS",
        )
        exact(receipt.get("development_cell_count"), 3, "RECEIPT_DEVELOPMENT_CELLS")
        exact(receipt.get("held_out_cell_count"), 9, "RECEIPT_HELD_OUT_CELLS")
        exact(receipt.get("held_out_cells_executed"), 0, "RECEIPT_HELD_OUT_EXECUTION")
        exact(receipt.get("artifact_count"), 12, "RECEIPT_ARTIFACTS")
        exact(receipt.get("operation_lock", {}).get("acquired"), True, "RECEIPT_LOCK")
        for field in (
            "native_runtime_observation_collection_executed",
            "physical_question_opened",
            "physical_execution_authorized",
            "physics_state_modified",
            "controller_physical_viability_proven",
            "prone_to_standing_claimed",
            "cross_engine_recovery_claimed",
            "cross_engine_equivalence_claimed",
            "sdk1_milestone_advanced",
            "physical_acceptance_authority",
            "release_authority",
        ):
            exact(receipt.get(field), False, f"RECEIPT_FALSE:{field}")
        for field in (
            "model_construction_count",
            "world_attempt_count",
            "world_build_count",
            "solver_step_count",
        ):
            exact(receipt.get(field), 0, f"RECEIPT_ZERO:{field}")


def source_binding_sha(closure: dict[str, Any], relative: Path) -> str:
    for entry in closure["source_freeze"]["source_bindings"]:
        if entry["path"] == relative.as_posix():
            return entry["raw_sha256"]
    raise AuditError(f"SOURCE_BINDING_MISSING:{relative.as_posix()}")


def run_mutations(closure: dict[str, Any]) -> int:
    mutations: tuple[tuple[str, Callable[[dict[str, Any]], None]], ...] = (
        ("status", lambda d: d.__setitem__("status", "physical_positive")),
        ("freeze", lambda d: d["source_freeze"].__setitem__("commit", "0" * 40)),
        (
            "source_count",
            lambda d: d["source_freeze"].__setitem__("source_inventory_count", 24),
        ),
        (
            "receipt_hash",
            lambda d: d["qualification"].__setitem__(
                "receipt_raw_sha256", "sha256:" + "0" * 64
            ),
        ),
        (
            "process_count",
            lambda d: d["qualification"].__setitem__("passed_process_count", 5),
        ),
        (
            "retained_count",
            lambda d: d["qualification"].__setitem__(
                "retained_file_reference_count", 13
            ),
        ),
        (
            "cas",
            lambda d: d["qualification"].__setitem__(
                "all_retained_files_content_addressed_at_closure", False
            ),
        ),
        (
            "engine_count",
            lambda d: d["qualified_source_contract"]["native_engine_identities"].pop(),
        ),
        (
            "channel_count",
            lambda d: d["qualified_source_contract"].__setitem__(
                "complete_native_post_step_channels_per_engine", 9
            ),
        ),
        (
            "native_collection",
            lambda d: d["qualified_source_contract"].__setitem__(
                "native_runtime_observation_collection_executed", True
            ),
        ),
        (
            "controller_viability",
            lambda d: d["qualified_source_contract"].__setitem__(
                "controller_physical_viability_proven", True
            ),
        ),
        (
            "threshold_count",
            lambda d: d["prospective_physical_profile"].__setitem__(
                "threshold_count", 15
            ),
        ),
        (
            "threshold_provenance",
            lambda d: d["prospective_physical_profile"].__setitem__(
                "threshold_provenance_count", 15
            ),
        ),
        (
            "heldout_executed",
            lambda d: d["prospective_physical_profile"].__setitem__(
                "held_out_cells_executed", 1
            ),
        ),
        (
            "heldout_access",
            lambda d: d["prospective_physical_profile"].__setitem__(
                "held_out_seed_use_during_development_permitted", True
            ),
        ),
        (
            "physical_authority",
            lambda d: d["next_boundary"].__setitem__(
                "physical_execution_authorized_by_this_closure", True
            ),
        ),
        (
            "prone_claim",
            lambda d: d["claims"].__setitem__("prone_to_standing_world_opened", True),
        ),
        (
            "score",
            lambda d: d["claims"].__setitem__("sdk1_milestone_score_after", "12/20"),
        ),
    )
    rejected = 0
    for name, mutate in mutations:
        candidate = copy.deepcopy(closure)
        mutate(candidate)
        try:
            validate_closure(candidate, verify_files=False)
        except AuditError:
            rejected += 1
        else:
            raise AuditError(f"MUTATION_SURVIVED:{name}")
    return rejected


def main() -> int:
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--allow-prospective-uncommitted", action="store_true")
    mode.add_argument("--require-committed-closure", action="store_true")
    args = parser.parse_args()

    exact(
        Path(git("rev-parse", "--show-toplevel")).resolve(),
        EXPECTED_ROOT.resolve(),
        "REPOSITORY_ROOT",
    )
    exact(git("remote", "get-url", "origin"), EXPECTED_REMOTE, "REPOSITORY_REMOTE")
    exact(git("branch", "--show-current"), "main", "REPOSITORY_BRANCH")
    exact(
        git("rev-parse", f"{FREEZE_COMMIT}^"), FREEZE_PARENT, "COMMITTED_FREEZE_PARENT"
    )
    exact(
        git("rev-parse", f"{FREEZE_COMMIT}^{{tree}}"),
        FREEZE_TREE,
        "COMMITTED_FREEZE_TREE",
    )
    if args.require_committed_closure:
        head_blob = git("rev-parse", f"HEAD:{CLOSURE_RELATIVE.as_posix()}")
        working_blob = git("hash-object", "--", CLOSURE_RELATIVE.as_posix())
        exact(working_blob, head_blob, "CLOSURE_NOT_COMMITTED")
        audit_head_blob = git("rev-parse", f"HEAD:{AUDIT_RELATIVE.as_posix()}")
        audit_working_blob = git("hash-object", "--", AUDIT_RELATIVE.as_posix())
        exact(audit_working_blob, audit_head_blob, "AUDIT_NOT_COMMITTED")

    closure = load_json(EXPECTED_ROOT / CLOSURE_RELATIVE)
    validate_closure(closure)
    mutations = run_mutations(closure)
    print(
        "QSDK_R24D17_RECOVERY_RUNTIME_CLOSURE_PASS "
        "source_bindings=25 processes=6/6 core=5 rapier=2 python=4 godot=1 "
        "engines=3 channels=10/10 runtime_mutations=8 controller_mutations=1 "
        "thresholds=16 provenance=16 adequacy=16 development_cells=3 "
        "heldout_cells=9/0 closure_mutations="
        f"{mutations}/18 artifacts=14/11 bytes=21844 "
        "native_collection=false worlds=0 builds=0 solver_steps=0"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AuditError, KeyError, TypeError, ValueError, json.JSONDecodeError) as exc:
        print(f"QSDK_R24D17_RECOVERY_RUNTIME_CLOSURE_FAIL {exc}", file=sys.stderr)
        raise SystemExit(1) from exc
