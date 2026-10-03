#!/usr/bin/env python3
"""Audit the zero-world R24D173 three-engine recovery conjunction.

This audit intentionally reads the immutable R44, R55, and R172 closures
directly.  The older closure audits include live-successor assertions, so
running them against today's ledger would confuse later ledger progress with
historical evidence drift.
"""

from __future__ import annotations

import copy
import hashlib
import json
import subprocess
import sys
from pathlib import Path
from typing import Any, Callable


REPO_ROOT = Path(__file__).resolve().parents[2]
EXPECTED_ROOT = "C:/Users/Cole/CodeStuff/games/SporeSpore"
EXPECTED_REMOTE = "https://github.com/Slagathore/sporespore.git"
DECISION_PARENT = "70a1080d88f487982e7a29eecea03d68ff72c2a1"
DECISION_PATH = (
    "sdk/recovery/"
    "r24d173_three_engine_canonical_prone_to_standing_decision_v1.json"
)
DECISION_BYTES = 13023
DECISION_SHA256 = (
    "sha256:c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f"
)
RELEASE_CONTRACT_PATH = "sdk/release/quadruped_release_contract.json"
RELEASE_CONTRACT_SHA256 = (
    "sha256:68e6a6368bdef965dd7728c7248ea217888f26f45626696904865c78ed1ac8bb"
)
SUPPORT_MATRIX_PATH = "sdk/release/quadruped_support_matrix.json"
SUPPORT_MATRIX_SHA256 = (
    "sha256:f2d3cc1d0b304757bf23ea5dd9b65bbbdfe918f5bbf49d8e4774377de1a5f653"
)
SDK1_MAPPING_PATH = "sdk/release/quadruped_sdk1_milestone_mapping_v1.json"
SDK1_MAPPING_SHA256 = (
    "sha256:11ea49db3d71faca04013e02c18036c3b5701d34a159060c68cb37657fcd4635"
)
THRESHOLD_PROFILE_SHA256 = (
    "sha256:3081621eb53f4d67bc1d8dc0f3a7d3ad7ae5ed829f902bce60b01ba1530bfb34"
)


class DecisionAuditError(RuntimeError):
    """Raised when an R24D173 decision invariant fails."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise DecisionAuditError(message)


def read_json(relative_path: str) -> dict[str, Any]:
    path = REPO_ROOT / relative_path
    value = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(value, dict), f"JSON_OBJECT_REQUIRED:{relative_path}")
    return value


def raw_identity(relative_path: str) -> tuple[int, str]:
    payload = (REPO_ROOT / relative_path).read_bytes()
    return len(payload), "sha256:" + hashlib.sha256(payload).hexdigest()


def git(*arguments: str) -> str:
    completed = subprocess.run(
        ["git", "-C", str(REPO_ROOT), *arguments],
        check=True,
        capture_output=True,
        text=True,
    )
    return completed.stdout.strip()


def git_blob_oid(relative_path: str) -> str:
    return git("rev-parse", f"HEAD:{relative_path}")


def get_path(value: dict[str, Any], dotted_path: str) -> Any:
    current: Any = value
    for component in dotted_path.split("."):
        require(
            isinstance(current, dict) and component in current,
            f"MISSING_PATH:{dotted_path}",
        )
        current = current[component]
    return current


def set_path(value: dict[str, Any], dotted_path: str, replacement: Any) -> None:
    components = dotted_path.split(".")
    current: Any = value
    for component in components[:-1]:
        current = current[component]
    current[components[-1]] = replacement


def find_unique_mapping_with_key(value: Any, key: str) -> dict[str, Any]:
    matches: list[dict[str, Any]] = []

    def visit(current: Any) -> None:
        if isinstance(current, dict):
            if key in current:
                matches.append(current)
            for child in current.values():
                visit(child)
        elif isinstance(current, list):
            for child in current:
                visit(child)

    visit(value)
    require(len(matches) == 1, f"UNIQUE_MAPPING_REQUIRED:{key}:{len(matches)}")
    return matches[0]


def validate_decision_shape(decision: dict[str, Any]) -> None:
    expected_scalars = {
        "schema_version": (
            "sporespore_qsdk_r24d173_three_engine_"
            "canonical_prone_to_standing_decision_v1"
        ),
        "gate_id": "QSDK-R24D173",
        "release_gate_id": "QSDK-R24",
        "sdk1_milestone_id": "SDK1-M19",
        "status": (
            "closed_zero_world_finite_conjunction_positive_"
            "qsdk_r24_satisfied_sdk1_m19_passed"
        ),
        "question_class": "finite_decision",
        "physical_question_declared": False,
        "new_physical_evidence_collected": False,
        "superiority_question_declared": False,
        "equivalence_or_non_inferiority_question_declared": False,
        "population_inference_declared": False,
        "source_boundary.decision_parent_commit": DECISION_PARENT,
        "source_boundary.historical_closure_audits_reexecuted_count": 0,
        "source_boundary.model_construction_count": 0,
        "source_boundary.world_attempt_count": 0,
        "source_boundary.world_build_count": 0,
        "source_boundary.solver_step_count": 0,
        "source_boundary.physics_state_modified": False,
        "canonical_task_authority.task_id": (
            "sporespore_canonical_ventral_prone_to_four_foot_stance_v1"
        ),
        "canonical_task_authority.semantics_id": (
            "sporespore_qsdk_r24d2_portable_recovery_semantics_v1"
        ),
        "conjunction_audit.required_engine_count": 3,
        "conjunction_audit.bound_engine_result_count": 3,
        "conjunction_audit.engine_identity_set_exact": True,
        (
            "conjunction_audit."
            "every_engine_result_is_immutable_consumed_valid_complete_positive"
        ): True,
        "conjunction_audit.every_candidate_reached_portable_complete": True,
        "conjunction_audit.every_matched_zero_arm_failed_without_active_recovery": True,
        "conjunction_audit.every_frozen_evaluator_returned_physical_development_passed": True,
        "conjunction_audit.every_engine_retained_no_cheat_and_safety_evidence": True,
        "conjunction_audit.every_engine_retained_contact_and_clearance_evidence": True,
        "conjunction_audit.every_engine_stopped_at_terminal_or_the_frozen_timeout": True,
        "conjunction_audit.common_threshold_profile_sha256": THRESHOLD_PROFILE_SHA256,
        "conjunction_audit.maximum_energy_balance_residual_j": 0.25,
        "conjunction_audit.required_stance_dwell_steps": 60,
        "conjunction_audit.maximum_outer_steps_per_arm": 1200,
        "conjunction_audit.controller_implementation_identity_equal_across_engines": False,
        "conjunction_audit.controller_equivalence_inferred": False,
        (
            "conjunction_audit."
            "canonical_task_and_evaluator_gate_semantics_equal_across_engines"
        ): True,
        "finite_decision_rule.conjunctive": True,
        "finite_decision_rule.partial_credit_allowed": False,
        "finite_decision_rule.result": "positive",
        "finite_decision_rule.q_sdk_r24_satisfied": True,
        "finite_decision_rule.sdk1_m19_satisfied": True,
        "finite_decision_rule.full_program_score_before": "11/25",
        "finite_decision_rule.full_program_score_after": "12/25",
        "finite_decision_rule.sdk1_score_before": "11/20",
        "finite_decision_rule.sdk1_score_after": "12/20",
        "claim_boundary.q_sdk_r24_satisfied": True,
        "claim_boundary.sdk1_m19_satisfied": True,
        "claim_boundary.prone_to_standing": True,
        "claim_boundary.controller_implementation_identity_claimed": False,
        "claim_boundary.cross_engine_equivalence_claimed": False,
        "claim_boundary.repeatability_claimed": False,
        "claim_boundary.population_claimed": False,
        "claim_boundary.general_self_righting_claimed": False,
        "claim_boundary.physical_balance_recovery_claimed": False,
        "claim_boundary.physical_acceptance_authority": False,
        "claim_boundary.release_authority": False,
        "next_boundary.gate_id": "QSDK-R01",
        "next_boundary.physical_question_declared": False,
        "next_boundary.physical_execution_authorized": False,
        "next_boundary.maximum_world_build_count": 0,
        "next_boundary.maximum_solver_step_count": 0,
        "next_boundary.release_remains_blocked": True,
    }
    for dotted_path, expected in expected_scalars.items():
        actual = get_path(decision, dotted_path)
        require(
            actual == expected and type(actual) is type(expected),
            f"DECISION_FIELD:{dotted_path}:expected={expected!r}:actual={actual!r}",
        )

    require(
        decision["canonical_task_authority"]["advertised_engines"]
        == ["godot_jolt", "rapier_parry", "mujoco"],
        "ADVERTISED_ENGINE_ORDER",
    )
    require(
        decision["canonical_task_authority"]["ordered_success_phases"]
        == [
            "confirm_prone",
            "establish_distal_support",
            "raise_body",
            "stance_handoff",
            "stance_dwell",
            "complete",
        ],
        "ORDERED_SUCCESS_PHASES",
    )
    require(
        decision["canonical_task_authority"]["required_gate_families"]
        == ["entry", "exit", "contact", "clearance", "safety", "timeout", "no_cheat"],
        "REQUIRED_GATE_FAMILIES",
    )
    require(
        decision["conjunction_audit"]["controller_identity_set"]
        == [
            "sporespore_exact_s169_prone_to_standing_controller_v1",
            "sporespore_exact_s169_prone_to_standing_controller_v6",
        ],
        "CONTROLLER_IDENTITY_SET",
    )

    results = decision["immutable_engine_results"]
    require(isinstance(results, list) and len(results) == 3, "ENGINE_RESULT_COUNT")
    require(
        [result["engine_id"] for result in results]
        == ["mujoco", "rapier_parry", "godot_jolt"],
        "ENGINE_RESULT_ORDER",
    )
    for result in results:
        require(result["question_class"] == "development", "ENGINE_QUESTION_CLASS")
        require(result["physical_attempt_consumed"] is True, "ENGINE_RESULT_CONSUMED")
        require(result["model_construction_count"] == 2, "ENGINE_MODEL_COUNT")
        require(result["world_build_count"] == 2, "ENGINE_WORLD_COUNT")
        require(result["candidate_terminal_phase"] == "complete", "ENGINE_CANDIDATE_TERMINAL")
        require(result["matched_zero_terminal_phase"] == "failed", "ENGINE_ZERO_TERMINAL")
        require(
            result["portable_evaluation_verdict"] == "physical_development_passed",
            "ENGINE_EVALUATOR_VERDICT",
        )
        require(
            result["exact_nominal_prone_to_standing_observed"] is True,
            "ENGINE_EXACT_NOMINAL_POSITIVE",
        )


def validate_bound_files(decision: dict[str, Any]) -> dict[str, dict[str, Any]]:
    authority = decision["canonical_task_authority"]
    for prefix in ("design", "portable_semantics"):
        path = authority[f"{prefix}_path"]
        length, digest = raw_identity(path)
        require(digest == authority[f"{prefix}_raw_sha256"], f"{prefix.upper()}_RAW_SHA")
        require(
            git_blob_oid(path) == authority[f"{prefix}_git_blob_oid"],
            f"{prefix.upper()}_GIT_BLOB",
        )
        require(length > 0, f"{prefix.upper()}_EMPTY")

    closures: dict[str, dict[str, Any]] = {}
    for result in decision["immutable_engine_results"]:
        for stem in ("closure", "closure_audit"):
            path = result[f"{stem}_path"]
            length, digest = raw_identity(path)
            require(length == result[f"{stem}_byte_length"], f"{stem.upper()}_BYTES:{path}")
            require(digest == result[f"{stem}_raw_sha256"], f"{stem.upper()}_SHA:{path}")
            require(
                git_blob_oid(path) == result[f"{stem}_git_blob_oid"],
                f"{stem.upper()}_GIT_BLOB:{path}",
            )
        closures[result["engine_id"]] = read_json(result["closure_path"])
    return closures


def validate_historical_closure_claims(closures: dict[str, dict[str, Any]]) -> None:
    mujoco = closures["mujoco"]
    require(mujoco["gate_id"] == "QSDK-R24D44", "R44_GATE")
    require(
        mujoco["closure_status"]
        == "closed_exact_nominal_mujoco_prone_to_standing_development_positive",
        "R44_STATUS",
    )
    require(mujoco["observed_result"]["execution_valid"] is True, "R44_EXECUTION")
    require(mujoco["observed_result"]["decision_positive"] is True, "R44_POSITIVE")
    require(
        mujoco["observed_result"]["portable_evaluation_verdict"]
        == "physical_development_passed",
        "R44_VERDICT",
    )
    require(
        mujoco["observed_result"]["candidate"]["final_phase"] == "complete",
        "R44_COMPLETE",
    )
    require(
        mujoco["observed_result"]["candidate"]["final_no_cheat_gate"] is True
        and mujoco["observed_result"]["candidate"]["final_safety_gate"] is True
        and mujoco["observed_result"]["candidate"]["final_stable_stance_gate"] is True,
        "R44_TERMINAL_GATES",
    )
    require(
        mujoco["observed_result"]["matched_zero_command"]["final_phase"] == "failed",
        "R44_MATCHED_ZERO",
    )
    require(
        mujoco["decision"]["exact_nominal_mujoco_prone_to_standing_observed"] is True,
        "R44_EXACT_NOMINAL",
    )

    rapier = closures["rapier_parry"]
    require(rapier["gate_id"] == "QSDK-R24D55", "R55_GATE")
    require(
        rapier["closure_status"]
        == "closed_consumed_valid_complete_exact_nominal_rapier_terminal_prefix_recovery_development_positive",
        "R55_STATUS",
    )
    frozen = rapier["observed_result"]["frozen_evaluation"]
    require(frozen["verdict"] == "physical_development_passed", "R55_VERDICT")
    require(frozen["physical_development_trace_valid"] is True, "R55_TRACE")
    require(frozen["candidate_physical_path_completed"] is True, "R55_COMPLETE")
    require(
        frozen["matched_zero_command_physical_control_failed_to_complete"] is True,
        "R55_MATCHED_ZERO",
    )
    require(frozen["all_negative_control_requirements_enforced"] is True, "R55_NO_CHEAT")
    require(frozen["prone_to_standing_claimed"] is True, "R55_EXACT_NOMINAL")
    require(
        rapier["observed_result"]["candidate"]["terminal_all_four_contacts_bear_support"]
        is True,
        "R55_CONTACT_GATE",
    )
    require(
        rapier["observed_result"]["candidate"]["terminal_torso_contact_present"]
        is False,
        "R55_CLEARANCE_GATE",
    )

    godot = closures["godot_jolt"]
    require(godot["gate_id"] == "QSDK-R24D172", "R172_GATE")
    require(
        godot["physical_attempt"]["status"] == "valid_complete_behavior_development",
        "R172_STATUS",
    )
    require(godot["physical_attempt"]["scientific_outcome"] == "positive", "R172_POSITIVE")
    require(godot["observed_behavior"]["raw_exact"]["all_in_run_physical_invariants_passed"] is True, "R172_INVARIANTS")
    require(
        godot["observed_behavior"]["computed_projection"]["candidate"]["final_phase"]
        == "complete",
        "R172_COMPLETE",
    )
    require(
        godot["observed_behavior"]["computed_projection"]["matched_zero"]["final_phase"]
        == "failed",
        "R172_MATCHED_ZERO",
    )
    evaluator = godot["observed_behavior"]["evaluator_projection"]
    require(evaluator["verdict"] == "physical_development_passed", "R172_VERDICT")
    require(evaluator["common_pass_count"] == evaluator["common_check_count"] == 22, "R172_COMMON_GATES")
    require(evaluator["verdict_pass_count"] == evaluator["verdict_check_count"] == 9, "R172_VERDICT_GATES")
    require(
        godot["decision"]["exact_nominal_godot_jolt_prone_to_standing_observed"]
        is True,
        "R172_EXACT_NOMINAL",
    )


def validate_threshold_authority() -> None:
    r44 = read_json(
        "sdk/recovery/r24d44_stance_completion_launcher_compatibility_contract_v1.json"
    )["threshold_margin_and_population_provenance"]
    r55 = read_json(
        "sdk/recovery/r24d55_rapier_terminal_prefix_recovery_contract_v1.json"
    )["threshold_and_margin_provenance"]
    r172 = read_json(
        "sdk/recovery/r24d172_godot_jolt_initializer_receipt_retention_recovery_behavior_contract_v1.json"
    )["threshold_and_margin_provenance"]
    require(
        r44["threshold_profile_id"]
        == r55["profile_id"]
        == "sporespore_exact_s169_recovery_development_thresholds_v1",
        "COMMON_THRESHOLD_PROFILE_ID",
    )
    require(
        r55["profile_sha256"] == r172["threshold_profile_sha256"] == THRESHOLD_PROFILE_SHA256,
        "COMMON_THRESHOLD_PROFILE_SHA",
    )
    require(
        r44["maximum_energy_balance_residual_j"]
        == r55["maximum_energy_balance_residual_j"]
        == r172["maximum_energy_balance_residual_j"]
        == 0.25,
        "COMMON_ENERGY_THRESHOLD",
    )
    require(
        r44["stance_dwell_steps"]
        == r55["required_stance_dwell_steps"]
        == r172["required_stance_dwell_steps"]
        == 60,
        "COMMON_STANCE_DWELL",
    )
    require(
        r44["new_behavior_threshold_count"] == 0
        and r55["threshold_change_count"] == 0
        and r172["threshold_change_count"] == 0,
        "NO_THRESHOLD_CHANGE",
    )


def parse_compiler_marker(command: list[str], prefix: str) -> dict[str, Any]:
    completed = subprocess.run(
        command,
        cwd=REPO_ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    markers = [line[len(prefix) :] for line in completed.stdout.splitlines() if line.startswith(prefix)]
    require(len(markers) == 1, f"COMPILER_MARKER_COUNT:{prefix}:{len(markers)}")
    value = json.loads(markers[0])
    require(isinstance(value, dict), f"COMPILER_REPORT_OBJECT:{prefix}")
    return value


def validate_live_authority(decision: dict[str, Any]) -> None:
    expected_identities = {
        RELEASE_CONTRACT_PATH: RELEASE_CONTRACT_SHA256,
        SUPPORT_MATRIX_PATH: SUPPORT_MATRIX_SHA256,
        SDK1_MAPPING_PATH: SDK1_MAPPING_SHA256,
    }
    for path, expected_digest in expected_identities.items():
        _, digest = raw_identity(path)
        require(digest == expected_digest, f"LIVE_AUTHORITY_SHA:{path}")

    release_contract = read_json(RELEASE_CONTRACT_PATH)
    gates = [gate for gate in release_contract["gates"] if gate["gate_id"] == "QSDK-R24"]
    require(len(gates) == 1, "R24_GATE_COUNT")
    proof = gates[0]["proof"]
    require(proof["kind"] == "repo_json", "R24_PROOF_KIND")
    require(proof["path"] == DECISION_PATH, "R24_PROOF_PATH")
    require(proof["sha256"] == DECISION_SHA256, "R24_PROOF_SHA")
    for predicate in proof["predicates"]:
        require(
            get_path(decision, predicate["path"]) == predicate["equals"],
            f"R24_PROOF_PREDICATE:{predicate['path']}",
        )

    release_node = find_unique_mapping_with_key(release_contract, "r24d173_status")
    support_matrix = read_json(SUPPORT_MATRIX_PATH)
    support_node = find_unique_mapping_with_key(support_matrix, "r24d173_status")
    for label, node in (("release", release_node), ("support", support_node)):
        require(node["r24d173_status"] == decision["status"], f"{label}:R173_STATUS")
        require(node["r24d173_decision_path"] == DECISION_PATH, f"{label}:R173_PATH")
        require(node["r24d173_decision_raw_sha256"] == DECISION_SHA256, f"{label}:R173_SHA")
        require(node["r24d173_decision_byte_length"] == DECISION_BYTES, f"{label}:R173_BYTES")
        require(node["r24d173_bound_engine_result_count"] == 3, f"{label}:ENGINE_COUNT")
        require(node["r24d173_q_sdk_r24_satisfied"] is True, f"{label}:R24")
        require(node["r24d173_sdk1_m19_satisfied"] is True, f"{label}:M19")
        require(node["r24d173_prone_to_standing"] is True, f"{label}:PRONE")
        require(node["r24d173_controller_equivalence_claimed"] is False, f"{label}:EQUIVALENCE")
        require(node["r24d173_world_build_count"] == 0, f"{label}:WORLD_COUNT")
        require(node["r24d173_solver_step_count"] == 0, f"{label}:STEP_COUNT")
        require(node["r24d173_sdk1_score_after"] == "12/20", f"{label}:SDK1_SCORE")
        require(node["r24d173_full_program_score_after"] == "12/25", f"{label}:FULL_SCORE")

    require(support_matrix["locomotion_modes"]["prone_to_standing"] is True, "SUPPORT_PRONE")
    require(support_matrix["claim_boundary"]["prone_to_standing"] is True, "CLAIM_PRONE")
    require(
        support_matrix["claim_boundary"]["physical_balance_recovery"] is False,
        "BROAD_RECOVERY_NOT_CLAIMED",
    )
    require(
        support_matrix["claim_boundary"]["formal_cross_engine_comparative_inference"]
        is False,
        "FORMAL_EQUIVALENCE_NOT_CLAIMED",
    )
    require(support_matrix["release_authorized"] is False, "RELEASE_NOT_AUTHORIZED")

    mapping = read_json(SDK1_MAPPING_PATH)
    full_authority = mapping["full_program_authority"]
    require(
        full_authority["release_contract_raw_sha256"] == RELEASE_CONTRACT_SHA256,
        "MAPPING_RELEASE_SHA",
    )
    require(
        full_authority["support_matrix_raw_sha256"] == SUPPORT_MATRIX_SHA256,
        "MAPPING_SUPPORT_SHA",
    )

    full_report = parse_compiler_marker(
        ["pwsh", "-NoProfile", "-File", "sdk/compile_quadruped_sdk_release_readiness.ps1"],
        "QUADRUPED_SDK_RELEASE_READINESS ",
    )
    require(full_report["gate_counts"]["required_passed"] == 12, "FULL_PASSED_COUNT")
    require(full_report["gate_counts"]["required_missing"] == 9, "FULL_MISSING_COUNT")
    require(full_report["gate_counts"]["required_contradicted"] == 4, "FULL_CONTRADICTED_COUNT")
    require(full_report["gate_counts"]["required_invalid_proof"] == 0, "FULL_INVALID_COUNT")
    require(full_report["claims"]["prone_to_standing"] is True, "FULL_PRONE_CLAIM")
    require(full_report["release_ready"] is False, "FULL_RELEASE_BLOCKED")

    sdk1_report = parse_compiler_marker(
        ["pwsh", "-NoProfile", "-File", "sdk/compile_quadruped_sdk1_milestone_readiness.ps1"],
        "QUADRUPED_SDK1_MILESTONE_READINESS ",
    )
    require(sdk1_report["sdk1_counts"]["passed"] == 12, "SDK1_PASSED_COUNT")
    require(sdk1_report["sdk1_counts"]["missing"] == 6, "SDK1_MISSING_COUNT")
    require(sdk1_report["sdk1_counts"]["contradicted"] == 2, "SDK1_CONTRADICTED_COUNT")
    require(sdk1_report["sdk1_counts"]["invalid_proof"] == 0, "SDK1_INVALID_COUNT")
    m19 = [m for m in sdk1_report["milestones"] if m["milestone_id"] == "SDK1-M19"]
    require(len(m19) == 1 and m19[0]["disposition"] == "passed", "SDK1_M19")
    require(sdk1_report["sdk1_milestones_complete"] is False, "SDK1_RELEASE_BLOCKED")


def validate_mutation_controls(decision: dict[str, Any]) -> int:
    mutations: list[tuple[str, Any]] = [
        ("status", "closed_negative"),
        ("physical_question_declared", True),
        ("source_boundary.world_build_count", 1),
        ("conjunction_audit.bound_engine_result_count", 2),
        (
            "conjunction_audit.every_engine_result_is_immutable_consumed_valid_complete_positive",
            False,
        ),
        ("conjunction_audit.controller_implementation_identity_equal_across_engines", True),
        ("conjunction_audit.canonical_task_and_evaluator_gate_semantics_equal_across_engines", False),
        ("finite_decision_rule.partial_credit_allowed", True),
        ("finite_decision_rule.q_sdk_r24_satisfied", False),
        ("finite_decision_rule.full_program_score_after", "11/25"),
        ("claim_boundary.cross_engine_equivalence_claimed", True),
        ("claim_boundary.repeatability_claimed", True),
        ("claim_boundary.physical_acceptance_authority", True),
        ("next_boundary.physical_execution_authorized", True),
    ]
    rejected = 0
    for dotted_path, replacement in mutations:
        candidate = copy.deepcopy(decision)
        set_path(candidate, dotted_path, replacement)
        try:
            validate_decision_shape(candidate)
        except DecisionAuditError:
            rejected += 1
    require(rejected == len(mutations), f"MUTATION_REJECTIONS:{rejected}/{len(mutations)}")
    return rejected


def main() -> None:
    root = git("rev-parse", "--show-toplevel").replace("\\", "/")
    remote = git("remote", "get-url", "origin")
    require(root == EXPECTED_ROOT, f"REPOSITORY_ROOT:{root}")
    require(remote == EXPECTED_REMOTE, f"REPOSITORY_REMOTE:{remote}")
    subprocess.run(
        ["git", "-C", str(REPO_ROOT), "merge-base", "--is-ancestor", DECISION_PARENT, "HEAD"],
        check=True,
        capture_output=True,
        text=True,
    )

    length, digest = raw_identity(DECISION_PATH)
    require(length == DECISION_BYTES, f"DECISION_BYTES:{length}")
    require(digest == DECISION_SHA256, f"DECISION_SHA:{digest}")
    decision = read_json(DECISION_PATH)
    validate_decision_shape(decision)
    closures = validate_bound_files(decision)
    validate_historical_closure_claims(closures)
    validate_threshold_authority()
    validate_live_authority(decision)
    rejected = validate_mutation_controls(decision)

    print(
        "QSDK_R24D173_THREE_ENGINE_CANONICAL_PRONE_TO_STANDING_DECISION_PASS "
        + json.dumps(
            {
                "ok": True,
                "gate_id": "QSDK-R24D173",
                "release_gate_id": "QSDK-R24",
                "engine_count": 3,
                "mutation_rejection_count": rejected,
                "model_construction_count": 0,
                "world_build_count": 0,
                "solver_step_count": 0,
                "q_sdk_r24_satisfied": True,
                "sdk1_m19_satisfied": True,
                "sdk1_score": "12/20",
                "full_program_score": "12/25",
                "controller_implementation_identity_equal": False,
                "cross_engine_equivalence_claimed": False,
                "release_authority": False,
            },
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    try:
        main()
    except (
        DecisionAuditError,
        KeyError,
        OSError,
        subprocess.CalledProcessError,
        TypeError,
        ValueError,
    ) as error:
        print(
            f"QSDK_R24D173_THREE_ENGINE_CANONICAL_PRONE_TO_STANDING_DECISION_FAIL:{error}",
            file=sys.stderr,
        )
        raise SystemExit(1)
