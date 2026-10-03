"""Shared, zero-world L14 design/predecessor bindings for production tooling.

The supervisor, materializer and closer consume the same narrow binding
contract. Design permission is never physical execution permission.
"""

from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path
import subprocess
from typing import Any, Mapping

import qsdk_r10f_l14_terminal_boundary_successor_design as design_audit
import qsdk_r10f_l14_no_resume_branch_completeness_addendum as addendum_audit


ROOT = Path(__file__).resolve().parents[2]
DESIGN_PATH = design_audit.DESIGN_PATH
PREDECESSOR_PATH = (
    ROOT / "sdk/qsdk_r10f_development_route_ghost_physical_closure_v14.json"
)
PREDECESSOR_BYTES = 9998
PREDECESSOR_SHA256 = (
    "sha256:1df9bd1896deb23989d6a3c080948a21805a1465b2682748d7e31c7fa1bdd4cb"
)
REPAIR_ID = "QSDK-R10F-L14"
CHANGE_CLASS = "observed_contact_cycle_and_exact_terminal_source_boundaries_only"
MARKER = "QSDK_R10F_L14_AUTHORITY_CONTRACT_PASS "


def require(condition: bool, code: str) -> None:
    if not condition:
        raise ValueError(code)


def git(*arguments: str) -> str:
    return subprocess.check_output(["git", *arguments], cwd=ROOT, text=True).strip()


def verify_repository() -> None:
    require(
        Path(git("rev-parse", "--show-toplevel")).resolve()
        == ROOT.resolve()
        == design_audit.diagnosis.EXPECTED_ROOT.resolve(),
        "L14_ROOT",
    )
    require(
        git("remote", "get-url", "origin")
        == "https://github.com/Slagathore/sporespore.git",
        "L14_REMOTE",
    )


def source_binding(path: Path, source_commit: str) -> None:
    relative = path.relative_to(ROOT).as_posix()
    require(
        git("rev-parse", f"{source_commit}:{relative}")
        == git("hash-object", str(path)),
        "L14_SOURCE_BLOB:" + relative,
    )


def expected_repair_binding() -> dict[str, Any]:
    return {
        "path": DESIGN_PATH.relative_to(ROOT).as_posix(),
        "byte_length": design_audit.DESIGN_BYTES,
        "raw_sha256": design_audit.DESIGN_SHA256,
        "status": "prospective_zero_world_successor_design_complete_implementation_authorized_physics_blocked",
        "repair_id": REPAIR_ID,
        "parent_repair_id": "QSDK-R10F-L13",
        "change_class": CHANGE_CLASS,
        "bound_authority_count": 5,
        "historical_source_binding_count": 5,
        "isolated_terminal_boundary_count": 3,
        "design_positive_control_count": 1,
        "design_mutation_rejection_count": 18,
        "walking_evaluator_version": 2,
        "walking_behavior_receipt_count": 27,
        "v1_observed_evaluator_preserved": True,
        "initial_partial_flight_not_counted_as_complete_cycle": True,
        "exact_native_terminal_number_kind_preserved": True,
        "interaction_start_receipt_not_wrapper_required": True,
        "complete_failed_evaluation_source_retention_required": True,
        "production_shaped_full_route_zero_world_checks_required": True,
        "all_l13_transport_handoff_and_earlier_controls_preserved": True,
        "controller_commands_solver_inputs_and_thresholds_changed": False,
        "maximum_child_process_count": 2,
        "maximum_world_count_per_child": 1,
        "maximum_total_world_count": 2,
        "maximum_solver_steps_per_child": 3842,
        "maximum_total_solver_steps": 7684,
        "force_aware_recovery": False,
        "physical_execution_authorized_by_design": False,
    }


def expected_predecessor_binding() -> dict[str, Any]:
    return {
        "path": PREDECESSOR_PATH.relative_to(ROOT).as_posix(),
        "byte_length": PREDECESSOR_BYTES,
        "raw_sha256": PREDECESSOR_SHA256,
        "status": "closed_consumed_invalid_or_incomplete_no_behavioral_conclusion",
        "repair_id": "QSDK-R10F-L13",
        "classification": "invalid_or_incomplete_no_behavioral_conclusion",
        "attempt_id": "788c80fb9da04edf87d7a49ace783278",
        "physical_identity_consumed": True,
        "same_identity_rerun_permitted": False,
        "observed_child_process_count": 1,
        "world_attempt_count": 1,
        "world_build_count": 1,
        "solver_step_count": 2882,
        "scientific_outcome": "none",
        "qualified_child_projection_count": 0,
        "failure_code": "QSDK_R10F_L9_PROCESS_POPULATION_VALIDATION_FAILED",
        "sdk1_m07_satisfied": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def expected_addendum_binding() -> dict[str, Any]:
    """A separate authority; never silently widen the immutable base design."""
    return {
        "path": addendum_audit.PATH.relative_to(ROOT).as_posix(),
        "byte_length": addendum_audit.BYTE_LENGTH,
        "raw_sha256": addendum_audit.SHA256,
        "repair_id": REPAIR_ID,
        "design_id": "QSDK-R10F-L14-NO-RESUME-BRANCH-COMPLETENESS-ADDENDUM-V1",
        "status": "prospective_zero_world_branch_design_implementation_authorized_physics_blocked",
        "base_design_raw_sha256": design_audit.DESIGN_SHA256,
        "bound_authority_count": 3,
        "design_positive_control_count": 1,
        "design_mutation_rejection_count": 23,
        "required_coverage_group_count": 9,
        "required_pre_resume_terminal_cause_count": 7,
        "terminal_transition_source_keys": ["state_before", "event", "advance_receipt"],
        "complete_terminal_and_observation_source_proof_required": True,
        "missing_resume_alone_is_not_a_valid_negative": True,
        "two_session_baseline_and_active_resume_requirements_preserved": True,
        "extra_resume_sources_cannot_bypass_terminal_proof": True,
        "strict_host_counter_and_exact_native_source_kinds_preserved": True,
        "orchestrator_controller_threshold_and_physics_inputs_changed": False,
        "physical_execution_authorized_by_addendum": False,
        "sdk1_m07_satisfied": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def addendum_binding_valid(value: Any) -> bool:
    return design_audit.exact(value, expected_addendum_binding())


def branch_completeness_addendum_binding(source_commit: str) -> dict[str, Any]:
    verify_repository()
    value = addendum_audit.exact_addendum()
    addendum_audit.validate_addendum(value)
    source_binding(addendum_audit.PATH, source_commit)
    for entry in value["bound_authorities"]:
        path = ROOT / entry["path"]
        raw = path.read_bytes()
        require(
            len(raw) == entry["byte_length"]
            and design_audit.diagnosis.digest(raw) == entry["raw_sha256"],
            "L14_ADDENDUM_BOUND_AUTHORITY:" + entry["role"],
        )
        source_binding(path, source_commit)
    return expected_addendum_binding()


def expected_authority_bindings() -> dict[str, Any]:
    return {
        "repair_design": expected_repair_binding(),
        "branch_completeness_addendum": expected_addendum_binding(),
        "consumed_predecessor_physical_closure": expected_predecessor_binding(),
    }


def authority_bindings_valid(value: Any) -> bool:
    return design_audit.exact(value, expected_authority_bindings())


def authority_bindings(source_commit: str) -> dict[str, Any]:
    return {
        "repair_design": repair_design_binding(source_commit),
        "branch_completeness_addendum": branch_completeness_addendum_binding(
            source_commit
        ),
        "consumed_predecessor_physical_closure": predecessor_physical_closure_binding(
            source_commit
        ),
    }


def repair_binding_valid(value: Any) -> bool:
    return design_audit.exact(value, expected_repair_binding())


def predecessor_binding_valid(value: Any) -> bool:
    return design_audit.exact(value, expected_predecessor_binding())


def repair_design_binding(source_commit: str) -> dict[str, Any]:
    verify_repository()
    raw = DESIGN_PATH.read_bytes()
    require(
        len(raw) == design_audit.DESIGN_BYTES
        and design_audit.diagnosis.digest(raw) == design_audit.DESIGN_SHA256,
        "L14_DESIGN_IDENTITY",
    )
    design = json.loads(raw)
    design_audit.validate_design(design)
    source_binding(DESIGN_PATH, source_commit)
    for entry in design["bound_authorities"]:
        path = ROOT / entry["path"]
        source_binding(path, source_commit)
    return expected_repair_binding()


def predecessor_physical_closure_binding(source_commit: str) -> dict[str, Any]:
    verify_repository()
    raw = PREDECESSOR_PATH.read_bytes()
    require(
        len(raw) == PREDECESSOR_BYTES
        and design_audit.diagnosis.digest(raw) == PREDECESSOR_SHA256,
        "L14_PREDECESSOR_IDENTITY",
    )
    value = json.loads(raw)
    expected = expected_predecessor_binding()
    for key in (
        "status",
        "repair_id",
        "classification",
        "attempt_id",
        "physical_identity_consumed",
        "same_identity_rerun_permitted",
        "observed_child_process_count",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
        "scientific_outcome",
        "failure_code",
        "sdk1_m07_satisfied",
        "physical_acceptance_authority",
        "release_authority",
    ):
        require(
            design_audit.exact(value.get(key), expected[key]),
            "L14_PREDECESSOR_FIELD:" + key,
        )
    require(
        value.get("child_projections") == {}
        and value.get("child_validation_errors")
        == {
            "matched_no_kick_continuation": "L9_matched_no_kick_continuation_TERMINAL_CONTENT_ADDRESS"
        },
        "L14_PREDECESSOR_INVALID_TERMINAL_PRESERVED",
    )
    source_binding(PREDECESSOR_PATH, source_commit)
    return expected


def self_test() -> dict[str, Any]:
    repair = expected_repair_binding()
    predecessor = expected_predecessor_binding()
    require(
        repair_binding_valid(repair) and predecessor_binding_valid(predecessor),
        "L14_BINDING_POSITIVES",
    )
    mutations = [
        ("repair", "repair_id", "QSDK-R10F-L13"),
        ("repair", "raw_sha256", PREDECESSOR_SHA256),
        ("repair", "physical_execution_authorized_by_design", True),
        ("repair", "walking_evaluator_version", 1),
        ("repair", "walking_evaluator_version", 2.0),
        ("repair", "walking_behavior_receipt_count", 26),
        ("repair", "controller_commands_solver_inputs_and_thresholds_changed", True),
        ("repair", "initial_partial_flight_not_counted_as_complete_cycle", False),
        ("repair", "interaction_start_receipt_not_wrapper_required", False),
        ("predecessor", "same_identity_rerun_permitted", True),
        ("predecessor", "physical_identity_consumed", False),
        ("predecessor", "qualified_child_projection_count", 1),
        ("predecessor", "solver_step_count", 241),
        ("predecessor", "solver_step_count", 2882.0),
        ("predecessor", "sdk1_m07_satisfied", True),
        ("predecessor", "release_authority", True),
    ]
    for kind, key, replacement in mutations:
        changed = copy.deepcopy(repair if kind == "repair" else predecessor)
        changed[key] = replacement
        check = repair_binding_valid if kind == "repair" else predecessor_binding_valid
        require(not check(changed), "L14_BINDING_MUTATION_ACCEPTED:" + key)
    addendum = expected_addendum_binding()
    require(addendum_binding_valid(addendum), "L14_ADDENDUM_BINDING_POSITIVE")
    addendum_mutations = [
        ("raw_sha256", design_audit.DESIGN_SHA256),
        ("byte_length", float(addendum_audit.BYTE_LENGTH)),
        ("base_design_raw_sha256", PREDECESSOR_SHA256),
        ("required_pre_resume_terminal_cause_count", 3),
        ("required_pre_resume_terminal_cause_count", 7.0),
        ("terminal_transition_source_keys", ["advance_receipt"]),
        ("complete_terminal_and_observation_source_proof_required", False),
        ("missing_resume_alone_is_not_a_valid_negative", False),
        ("two_session_baseline_and_active_resume_requirements_preserved", False),
        ("extra_resume_sources_cannot_bypass_terminal_proof", False),
        ("physical_execution_authorized_by_addendum", True),
        ("sdk1_m07_satisfied", True),
    ]
    for key, replacement in addendum_mutations:
        changed = copy.deepcopy(addendum)
        changed[key] = replacement
        require(
            not addendum_binding_valid(changed),
            "L14_ADDENDUM_BINDING_MUTATION_ACCEPTED:" + key,
        )
    bundle = expected_authority_bindings()
    require(authority_bindings_valid(bundle), "L14_AUTHORITY_BUNDLE_POSITIVE")
    for key in bundle:
        changed = copy.deepcopy(bundle)
        del changed[key]
        require(
            not authority_bindings_valid(changed),
            "L14_AUTHORITY_BUNDLE_MEMBER_MISSING:" + key,
        )
    return {
        "ok": True,
        "positive_control_count": 4,
        "mutation_rejection_count": len(mutations)
        + len(addendum_mutations)
        + len(bundle),
        "base_and_predecessor_positive_control_count": 2,
        "base_and_predecessor_mutation_rejection_count": len(mutations),
        "addendum_positive_control_count": 1,
        "addendum_mutation_rejection_count": len(addendum_mutations),
        "composite_positive_control_count": 1,
        "composite_missing_authority_rejection_count": len(bundle),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "command",
        choices=(
            "self-test",
            "repair-binding",
            "predecessor-binding",
            "addendum-binding",
            "authority-bindings",
        ),
    )
    parser.add_argument("--source-commit")
    args = parser.parse_args()
    if args.command == "self-test":
        value = self_test()
    else:
        require(
            type(args.source_commit) is str and len(args.source_commit) == 40,
            "L14_SOURCE_COMMIT_REQUIRED",
        )
        function = {
            "repair-binding": repair_design_binding,
            "predecessor-binding": predecessor_physical_closure_binding,
            "addendum-binding": branch_completeness_addendum_binding,
            "authority-bindings": authority_bindings,
        }[args.command]
        value = {"ok": True, "binding": function(args.source_commit)}
    receipt = {
        "schema_version": "sporespore_qsdk_r10f_l14_authority_contract_receipt_v1",
        "gate_id": "QSDK-R10F",
        "repair_id": REPAIR_ID,
        "ledger_scope": {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "zero_world_production_source_binding",
            "question_class": "development",
        },
        "command": args.command,
        "source_commit": args.source_commit,
        **value,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "scene_tree_insertion_count": 0,
        "native_readback_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    print(MARKER + json.dumps(receipt, sort_keys=True))


if __name__ == "__main__":
    main()
