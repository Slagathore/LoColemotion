"""Audit the distinct no-resume branch design; never authorize a world."""

from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import subprocess

import qsdk_r10f_l14_no_resume_branch_diagnosis as diagnosis
from qsdk_r10f_l14_terminal_consumers import same_source_value

ROOT = Path(__file__).resolve().parents[2]
PATH = ROOT / "sdk/qsdk_r10f_l14_no_resume_branch_completeness_addendum_v1.json"
BYTE_LENGTH = 8763
SHA256 = "sha256:01f40035e6cbae84621b28bdca1cd8d18a7a15876ceb44adfd668956d6b14f76"
MARKER = "QSDK_R10F_L14_BRANCH_COMPLETENESS_ADDENDUM_PASS "


def require(condition: bool, code: str) -> None:
    if not condition:
        raise ValueError(code)


def exact_addendum() -> dict:
    raw = PATH.read_bytes()
    require(
        len(raw) == BYTE_LENGTH
        and "sha256:" + hashlib.sha256(raw).hexdigest() == SHA256,
        "L14_ADDENDUM_IDENTITY",
    )
    return json.loads(raw)


def validate_addendum(value: dict) -> None:
    # This is an exact prospective scope contract, not a permissive schema.
    # A changed rule, new exception or relaxed source predicate needs a new
    # declaration; number-kind changes are not silently normalized either.
    require(same_source_value(value, exact_addendum()), "L14_ADDENDUM_SCOPE_CHANGED")
    require(
        value["ledger_scope"]["question_class"] == "development"
        and value["authorization_boundary"]["physical_execution_authorized"] is False
        and value["preserved_boundaries"]["sdk1_score"] == "14/20",
        "L14_ADDENDUM_QUESTION_AND_CLAIM_BOUNDARY",
    )


def audit() -> dict:
    require(
        Path(diagnosis.git("rev-parse", "--show-toplevel")).resolve() == ROOT,
        "L14_ADDENDUM_ROOT",
    )
    require(
        diagnosis.git("remote", "get-url", "origin")
        == "https://github.com/Slagathore/sporespore.git",
        "L14_ADDENDUM_REMOTE",
    )
    value = exact_addendum()
    validate_addendum(value)
    for binding in value["bound_authorities"]:
        raw = (ROOT / binding["path"]).read_bytes()
        require(
            len(raw) == binding["byte_length"]
            and "sha256:" + hashlib.sha256(raw).hexdigest() == binding["raw_sha256"],
            "L14_ADDENDUM_BOUND_AUTHORITY:" + binding["role"],
        )
    expected = json.loads((ROOT / value["bound_authorities"][1]["path"]).read_bytes())
    actual = diagnosis.diagnose()
    require(same_source_value(expected, actual), "L14_ADDENDUM_DIAGNOSIS_REPLAY")
    require(
        actual["actual_orchestrator_source_branch_count"] == 3
        and len(actual["bound_source_population"]) == 5
        and actual["physical_execution_authorized"] is False
        and actual["physical_result_changed_or_promoted"] is False,
        "L14_ADDENDUM_DIAGNOSIS_SCOPE",
    )
    changes = [
        (("repair_id",), "QSDK-R10F-L13"),
        (("status",), "physical_execution_authorized"),
        (("ledger_scope", "question_class"), "finite_decision"),
        (("authorization_boundary", "physical_execution_authorized"), True),
        (
            (
                "authorization_boundary",
                "maximum_world_attempt_count_before_complete_new_authority_graph",
            ),
            1,
        ),
        (
            (
                "authorization_boundary",
                "maximum_world_attempt_count_before_complete_new_authority_graph",
            ),
            0.0,
        ),
        (("authorization_boundary", "release_authority"), True),
        (
            (
                "selected_changes",
                "terminal_source_retention",
                "no_additional_event_or_controller_advance",
            ),
            False,
        ),
        (
            ("selected_changes", "terminal_source_retention", "complete_source_keys"),
            ["advance_receipt"],
        ),
        (
            (
                "selected_changes",
                "independent_branch_proof",
                "exact_transition_state_event_and_advance_schemas_required",
            ),
            False,
        ),
        (
            (
                "selected_changes",
                "independent_branch_proof",
                "all_available_payload_digests_recomputed",
            ),
            False,
        ),
        (
            (
                "selected_changes",
                "independent_branch_proof",
                "no_resume_session_handoff_or_trace_rows_required",
            ),
            False,
        ),
        (
            (
                "selected_changes",
                "independent_branch_proof",
                "native_memory_number_kind_and_value_preserved",
            ),
            False,
        ),
        (
            (
                "selected_changes",
                "independent_branch_proof",
                "host_counter_numbers_remain_strict_integers",
            ),
            False,
        ),
        (
            (
                "selected_changes",
                "unchanged_populations",
                "baseline_after_complete_precondition",
            ),
            ["walking_prefix"],
        ),
        (
            (
                "selected_changes",
                "unchanged_populations",
                "active_after_walking_resume",
            ),
            ["walking_prefix"],
        ),
        (
            (
                "selected_changes",
                "unchanged_populations",
                "missing_resume_in_positive_or_nonterminal_child_is_invalid",
            ),
            False,
        ),
        (
            (
                "selected_changes",
                "unchanged_populations",
                "failed_engine_health_or_absent_peer_never_becomes_route_acceptance",
            ),
            False,
        ),
        (
            (
                "preserved_boundaries",
                "orchestrator_policy_and_event_transition_rules_changed",
            ),
            True,
        ),
        (
            (
                "preserved_boundaries",
                "caps_materials_body_impulse_or_numeric_thresholds_changed",
            ),
            True,
        ),
        (("preserved_boundaries", "consumed_identity_retry_permitted"), True),
        (("preserved_boundaries", "sdk1_m07_satisfied"), True),
        (("preserved_boundaries", "sdk1_score"), "15/20"),
    ]
    rejected = []
    for path, replacement in changes:
        candidate = copy.deepcopy(value)
        target = candidate
        for key in path[:-1]:
            target = target[key]
        target[path[-1]] = replacement
        try:
            validate_addendum(candidate)
        except ValueError:
            rejected.append(".".join(path))
    require(len(rejected) == len(changes), "L14_ADDENDUM_MUTATION_ACCEPTED")
    return {
        "schema_version": "sporespore_qsdk_r10f_l14_branch_completeness_addendum_audit_v1",
        "gate_id": "QSDK-R10F",
        "repair_id": "QSDK-R10F-L14",
        "ok": True,
        "ledger_scope": {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "zero_world_branch_completeness_design_audit",
            "question_class": "development",
        },
        "addendum": {
            "path": PATH.relative_to(ROOT).as_posix(),
            "byte_length": BYTE_LENGTH,
            "raw_sha256": SHA256,
        },
        "bound_authority_count": 3,
        "frozen_diagnostic_source_count": 5,
        "actual_orchestrator_diagnosed_branch_count": 3,
        "required_zero_world_coverage_group_count": 9,
        "positive_design_control_count": 1,
        "mutation_rejection_count": len(rejected),
        "diagnosis_recomputed_exact_including_number_kinds": True,
        "implementation_authorized": True,
        "implementation_complete": False,
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


if __name__ == "__main__":
    print(MARKER + json.dumps(audit(), sort_keys=True))
