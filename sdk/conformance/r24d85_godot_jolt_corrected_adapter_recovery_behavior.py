#!/usr/bin/env python3
"""Compact R85 source audit and zero-world behavior-route preflight."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance import godot_recovery_route_zero_world_controls as controls  # noqa: E402
from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError,
    exact,
    load,
    require,
    resolve_prospective_source_freeze,
    source_bytes,
    verify_bound_source_markers,
    verify_declared_source_inventory,
    verify_exact_paths,
    verify_legacy_live_authority_projection,
)

CONTRACT = ROOT / (
    "sdk/recovery/r24d85_godot_jolt_corrected_adapter_recovery_"
    "behavior_contract_v1.json"
)
CLOSURE = ROOT / (
    "sdk/recovery/r24d85_godot_jolt_corrected_adapter_recovery_behavior_"
    "zero_world_qualification_closure_v1.json"
)
R81_CLOSURE = ROOT / (
    "sdk/recovery/r24d81_godot_jolt_guarded_command_recovery_behavior_"
    "negative_closure_v1.json"
)
R84_CLOSURE = ROOT / (
    "sdk/recovery/r24d84_godot_jolt_corrected_adapter_production_route_"
    "ghost_positive_closure_v1.json"
)
PHYSICAL_RUNNER = ROOT / (
    "sdk/run_qsdk_r24d85_godot_jolt_corrected_adapter_recovery_behavior.ps1"
)
WORKER = "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
SUPERVISOR = "sdk/run_qsdk_r24d57_godot_native_recovery_route_ghost.ps1"
SOURCE_MARKER = (
    "QSDK_R24D85_GODOT_JOLT_CORRECTED_ADAPTER_RECOVERY_BEHAVIOR_SOURCE_PASS"
)
SUPERVISOR_MARKER = (
    "QSDK_R24D85_CORRECTED_ADAPTER_RECOVERY_BEHAVIOR_SUPERVISOR "
)
RUNTIME_IDENTITY_SCHEMA = (
    "sporespore_qsdk_r24d85_corrected_adapter_behavior_runtime_identity_v1"
)
SEED_LABEL = (
    "QSDK-R24D85/development/godot/"
    "r83-corrected-exact-nominal-prone-to-standing-paired-v1"
)
SEED_SHA256 = (
    "sha256:99f5f0d2fe16876b2a739504e7ba8253ece233f27fec8192c39fa1b6cb33c4d1"
)
PROSPECTIVE_STATUS = (
    "prospective_corrected_adapter_recovery_behavior_complete_zero_world_"
    "qualification_required_physics_blocked"
)
QUALIFIED_STATUS = (
    "closed_complete_zero_world_corrected_adapter_recovery_behavior_qualified_"
    "one_finite_paired_development_attempt_authorized"
)


def _one_marker(stdout: str, marker: str) -> dict[str, Any]:
    lines = [line for line in stdout.splitlines() if line.startswith(marker)]
    exact(len(lines), 1, "RUNTIME_IDENTITY_MARKER_COUNT")
    value = json.loads(lines[0][len(marker) :])
    require(isinstance(value, dict), "RUNTIME_IDENTITY_RECEIPT")
    return value


def _validate_predecessors(contract: dict[str, Any]) -> None:
    declarations = contract["bound_predecessors"]
    exact(len(declarations), 2, "PREDECESSOR_COUNT")
    expected = (
        (
            declarations[0],
            R81_CLOSURE,
            "closed_consumed_valid_finite_negative_raise_body_timeout_after_"
            "distal_support",
        ),
        (
            declarations[1],
            R84_CLOSURE,
            "closed_valid_complete_corrected_adapter_production_route_ghost_"
            "passed_distinct_r24d85_behavior_successor_required",
        ),
    )
    values: list[dict[str, Any]] = []
    for declaration, path, status in expected:
        raw = path.read_bytes()
        verify_exact_paths(
            declaration,
            {
                "path": path.relative_to(ROOT).as_posix(),
                "byte_length": len(raw),
                "raw_sha256": "sha256:" + hashlib.sha256(raw).hexdigest(),
                "closure_status": status,
                "same_identity_rerun_permitted": False,
                "same_identity_requalification_permitted": False,
                "historical_result_rewritten": False,
            },
            f"PREDECESSOR:{path.name}",
        )
        value = json.loads(raw)
        require(isinstance(value, dict), f"PREDECESSOR_OBJECT:{path.name}")
        exact(value["closure_status"], status, f"PREDECESSOR_STATUS:{path.name}")
        values.append(value)

    verify_exact_paths(
        values[0],
        {
            "physical_attempt.status": "valid_complete_behavior_development",
            "physical_attempt.scientific_outcome": "negative",
            "physical_attempt.in_run_invariant_receipt_count": 999,
            "decision.all_in_run_physical_invariants_passed": True,
            "decision.candidate_distal_support_completed": True,
            "decision.candidate_raise_body_timeout_observed": True,
            "decision.recovery_success_observed": False,
            "claim_boundary.prone_to_standing_claimed": False,
        },
        "R81",
    )
    verify_exact_paths(
        values[1],
        {
            "physical_attempt.status": "valid_complete_integration_ghost",
            "physical_attempt.model_construction_count": 1,
            "physical_attempt.world_build_count": 1,
            "physical_attempt.solver_step_count": 2,
            "physical_attempt.portable_command_application_count": 1,
            "decision.integration_ghost_passed": True,
            "decision.in_run_physical_invariants_passed": True,
            "decision.recovery_success_established": False,
            "claim_boundary.prone_to_standing_claimed": False,
        },
        "R84",
    )


def _validate_seed(contract: dict[str, Any]) -> None:
    question = contract["finite_behavior_question"]
    exact(question["seed_label"], SEED_LABEL, "SEED_LABEL")
    exact(
        "sha256:" + hashlib.sha256(SEED_LABEL.encode("utf-8")).hexdigest(),
        SEED_SHA256,
        "SEED_LABEL_HASH",
    )
    exact(
        (question["seed"], question["seed_sha256"]),
        (278151771, SEED_SHA256),
        "SEED_IDENTITY",
    )
    r81 = load(R81_CLOSURE)
    exact(
        question["seed"],
        r81["physical_attempt"]["seed"],
        "R81_SEED_VALUE_REUSE",
    )
    require(
        question["seed_label"]
        != "QSDK-R24D81/development/godot/"
        "exact-nominal-guarded-command-transport-paired-v1",
        "SEED_LABEL_NOT_DISTINCT",
    )


def validate_sources() -> tuple[dict[str, Any], dict[str, int], bool]:
    contract = load(CONTRACT)
    controls.validate_development_question(contract, "QSDK-R24D85")
    verify_exact_paths(
        contract,
        {
            "schema_version": (
                "sporespore_qsdk_r24d85_godot_jolt_corrected_adapter_"
                "recovery_behavior_contract_v1"
            ),
            "status": PROSPECTIVE_STATUS,
            "controlled_change.r81_valid_finite_behavior_negative_bound": True,
            "controlled_change.r84_valid_complete_corrected_production_route_bound": True,
            "controlled_change.r83_joint_limit_projection_correction_present": True,
            "controlled_change.r83_collision_filter_correction_present": True,
            "controlled_change.r81_behavior_question_reused_under_distinct_campaign": True,
            "controlled_change.r81_seed_value_reused": True,
            "controlled_change.r81_portable_recovery_controller_changed": False,
            "controlled_change.r81_portable_recovery_evaluator_changed": False,
            "controlled_change.r81_behavior_threshold_changed": False,
            "controlled_change.r81_actuator_cap_changed": False,
            "controlled_change.r81_recovery_morphology_changed": False,
            "controlled_change.r81_energy_observer_changed": False,
            "controlled_change.additional_route_ghost_required": False,
            "controlled_change.additional_physical_canary_required": False,
            "controlled_change.published_closure_authorization_control_required": False,
            "finite_behavior_question.cell_count": 1,
            "finite_behavior_question.physical_cohort_count": 1,
            "finite_behavior_question.arm_count": 2,
            "finite_behavior_question.world_count": 2,
            "finite_behavior_question.maximum_world_build_count": 2,
            "finite_behavior_question.maximum_outer_solver_steps": 2400,
            "finite_behavior_question.maximum_outer_solver_steps_per_arm": 1200,
            "finite_behavior_question.behavior_evaluator_invocation_count": 1,
            "finite_behavior_question.held_out": False,
            "threshold_margin_cohort_and_population_adequacy.new_behavior_threshold_count": 0,
            "threshold_margin_cohort_and_population_adequacy.equivalence_margin_count": 0,
            "threshold_margin_cohort_and_population_adequacy.population_claim_count": 0,
            "coverage_adequacy.r81_in_run_invariant_receipt_count": 999,
            "coverage_adequacy.r81_all_in_run_physical_invariants_passed": True,
            "coverage_adequacy.r84_corrected_adapter_solver_step_count": 2,
            "coverage_adequacy.r84_corrected_adapter_route_complete": True,
            "coverage_adequacy.full_seeded_ghost_required": False,
            "coverage_adequacy.additional_physical_canary_required": False,
            "critical_path_audit_policy.source_inventory_count": 63,
            "critical_path_audit_policy.qualified_physical_path_count": 48,
            "critical_path_audit_policy.authored_source_path_count": 10,
            "critical_path_audit_policy.bound_predecessor_count": 2,
            "critical_path_audit_policy.current_zero_world_worker_count": 0,
            "critical_path_audit_policy.production_worker_parse_count": 1,
            "critical_path_audit_policy.historical_closure_audits_executed_count": 0,
            "complete_zero_world_gate.unchanged_behavior_source_binding_count": 8,
            "complete_zero_world_gate.production_worker_parse_count": 1,
            "complete_zero_world_gate.forced_supervisor_failure_control_count": 1,
            "complete_zero_world_gate.missing_physical_switch_refusal_count": 1,
            "complete_zero_world_gate.historical_closure_audits_executed_count": 0,
            "complete_zero_world_gate.model_construction_count": 0,
            "complete_zero_world_gate.world_attempt_count": 0,
            "complete_zero_world_gate.world_build_count": 0,
            "complete_zero_world_gate.solver_step_count": 0,
            "complete_zero_world_gate.behavior_evaluator_invocation_count": 0,
            "physical_runner.published_closure_authorization_control_required": False,
            "physical_runner.direct_committed_closure_recheck_under_operation_lock_required": True,
            "physical_runner.physical_question_kind": "behavior_development",
            "physical_authorization_projection.maximum_world_build_count": 2,
            "physical_authorization_projection.maximum_outer_solver_steps": 2400,
            "physical_authorization_projection.maximum_outer_solver_steps_per_arm": 1200,
            "physical_authorization_projection.behavior_evaluator_invocation_count": 1,
            "physical_authorization_projection.physical_execution_authorized": False,
            "claim_boundary.complete_zero_world_gate_passed": False,
            "claim_boundary.prone_to_standing_claimed": False,
            "sdk_status.sdk1_completed_steps": 11,
            "sdk_status.sdk1_total_steps": 20,
        },
        "CONTRACT",
    )
    _validate_seed(contract)
    _validate_predecessors(contract)

    source_commit, published = resolve_prospective_source_freeze(
        root=ROOT,
        contract=contract,
        closure_path=CLOSURE,
        closure_schema=(
            "sporespore_qsdk_r24d85_godot_jolt_corrected_adapter_recovery_"
            "behavior_zero_world_qualification_closure_v1"
        ),
        gate_id="QSDK-R24D85",
    )
    r81_source = str(contract["unchanged_behavior_source_commit"])
    for relative in contract["unchanged_behavior_paths"]:
        exact(
            source_bytes(ROOT, source_commit, relative),
            source_bytes(ROOT, r81_source, relative),
            f"UNCHANGED_BEHAVIOR:{relative}",
        )

    bound_sources = {
        relative: source_bytes(ROOT, source_commit, relative)
        for relative in (
            WORKER,
            SUPERVISOR,
            "sdk/run_qsdk_r24d85_godot_jolt_corrected_adapter_recovery_behavior.ps1",
        )
    }
    verify_bound_source_markers(
        bound_sources,
        {
            WORKER: (
                "SPORESPORE_GODOT_RECOVERY_GATE_ID",
                "behavior_evaluator_invocation_count",
                "all_in_run_physical_invariants_passed",
            ),
            SUPERVISOR: (
                'PhysicalQuestionKind = "integration_ghost"',
                '"behavior_development"',
                "physical_ghost_authorized",
                "ExpectedBehaviorEvaluatorInvocationCount",
            ),
            "sdk/run_qsdk_r24d85_godot_jolt_corrected_adapter_recovery_behavior.ps1": (
                'GateId = "QSDK-R24D85"',
                'PhysicalQuestionKind = "behavior_development"',
                "MaximumOuterSolverSteps = 2400",
                "ExpectedBehaviorEvaluatorInvocationCount = 1",
            ),
        },
        "BOUND_SOURCE",
    )

    inventory = contract["source_inventory"]
    verify_declared_source_inventory(ROOT, inventory)
    exact(len(inventory), 63, "SOURCE_INVENTORY_COUNT")
    authored = contract["authored_source_paths"]
    exact(len(authored), 10, "AUTHORED_SOURCE_COUNT")
    qualified = contract["qualified_physical_paths"]
    exact(len(qualified), 48, "QUALIFIED_PATH_COUNT")
    require(set(qualified).issubset(set(inventory)), "QUALIFIED_PATH_SUBSET")
    publication = set(contract["source_path_roles"]["publication_only_paths"])
    exact(publication.intersection(qualified), set(), "PATH_ROLE_OVERLAP")

    live_expected: dict[str, Any] = {
        "next_gate_id": "QSDK-R24D85",
        "r24d85_distinct_successor_required": False,
        "r24d85_question_class": "development",
        "r24d85_physical_question_declared": True,
        "r24d85_contract_path": CONTRACT.relative_to(ROOT).as_posix(),
        "r24d85_source_status": QUALIFIED_STATUS if published else PROSPECTIVE_STATUS,
        "r24d85_r81_negative_closure_bound": True,
        "r24d85_r84_positive_route_closure_bound": True,
        "r24d85_exact_r81_behavior_question_reused": True,
        "r24d85_maximum_world_build_count": 2,
        "r24d85_maximum_outer_solver_steps": 2400,
        "r24d85_maximum_outer_solver_steps_per_arm": 1200,
        "r24d85_behavior_evaluator_invocation_count": 1,
        "r24d85_full_seeded_ghost_required": False,
        "r24d85_additional_physical_canary_required": False,
        "r24d85_zero_world_qualification_pending": not published,
        "r24d85_zero_world_qualified": published,
        "r24d85_physical_execution_authorized": published,
        "physical_execution_blocked_pending_r24d85_declaration": False,
        "physical_execution_blocked_until_r24d85_zero_world_qualification": (
            not published
        ),
    }
    if published:
        live_expected.update(
            {
                "r24d85_source_commit": source_commit,
                "r24d85_zero_world_closure_path": CLOSURE.relative_to(ROOT).as_posix(),
                "r24d85_official_qualification_attempt_count": 1,
            }
        )
    verify_legacy_live_authority_projection(
        ROOT,
        (
            "sdk/release/quadruped_release_contract.json",
            "sdk/release/quadruped_support_matrix.json",
        ),
        record_key="r24d85_contract_path",
        expected=live_expected,
        prefix="LIVE_R85",
    )
    counts = {
        "source_inventory_count": 63,
        "authored_source_path_count": 10,
        "qualified_physical_path_count": 48,
        "bound_predecessor_count": 2,
        "unchanged_behavior_source_binding_count": 8,
        "current_zero_world_worker_count": 0,
        "production_worker_parse_count": 1,
        "historical_closure_audits_executed_count": 0,
        "full_seeded_ghost_count": 0,
        "bespoke_physical_canary_count": 0,
    }
    return contract, counts, published


def _run_runtime_identity(contract: dict[str, Any]) -> dict[str, Any]:
    completed = subprocess.run(
        [
            "pwsh",
            "-NoLogo",
            "-NoProfile",
            "-File",
            str(PHYSICAL_RUNNER),
            "-Mode",
            "RuntimeIdentity",
        ],
        cwd=ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="strict",
        check=False,
    )
    exact(completed.returncode, 0, "RUNTIME_IDENTITY_EXIT")
    exact(completed.stderr, "", "RUNTIME_IDENTITY_STDERR")
    receipt = _one_marker(completed.stdout, SUPERVISOR_MARKER)
    verify_exact_paths(
        receipt,
        {
            "schema_version": RUNTIME_IDENTITY_SCHEMA,
            "gate_id": "QSDK-R24D85",
            "ok": True,
            "selected_console_path": contract["exact_runtime"]["console_path"],
            "selected_console_sha256": contract["exact_runtime"]["console_sha256"],
            "selected_console_byte_length": contract["exact_runtime"][
                "console_byte_length"
            ],
            "worker_relative_path": WORKER,
            "worker_parse_count": 1,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physical_execution_authorized": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        "RUNTIME_IDENTITY",
    )
    return receipt


def run_preflight(
    contract: dict[str, Any], counts: dict[str, int]
) -> dict[str, Any]:
    runtime_identity = _run_runtime_identity(contract)
    projection = controls.run_projection_control(
        ROOT, PHYSICAL_RUNNER, SUPERVISOR_MARKER, "QSDK-R24D85"
    )
    refusal = controls.run_missing_physical_switch_refusal(
        ROOT,
        PHYSICAL_RUNNER,
        SUPERVISOR_MARKER,
        "QSDK-R24D85",
        "sporespore_qsdk_r24d85_missing_physical_switch_refusal_v1",
    )
    controls.require_zero_authority(projection)
    controls.require_zero_authority(refusal)
    return {
        "schema_version": "sporespore_qsdk_r24d85_behavior_preflight_v1",
        "gate_id": "QSDK-R24D85",
        "ok": True,
        "runtime_id": contract["exact_runtime"]["runtime_profile_id"],
        "runtime_version": contract["exact_runtime"]["runtime_version"],
        **counts,
        "r81_negative_closure_raw_sha256": contract["bound_predecessors"][0][
            "raw_sha256"
        ],
        "r84_positive_route_closure_raw_sha256": contract["bound_predecessors"][1][
            "raw_sha256"
        ],
        "historical_closure_audit_reexecution_count": 0,
        "production_wrapper_runtime_identity_receipt": runtime_identity,
        "supervisor_projection_receipt": projection,
        "missing_physical_switch_refusal_receipt": refusal,
        "forced_supervisor_failure_control_count": 1,
        "missing_physical_switch_refusal_count": 1,
        "behavior_evaluator_invocation_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_question_opened": False,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--core-library", type=Path)
    args = parser.parse_args()
    contract, counts, published = validate_sources()
    if args.core_library is None:
        print(
            SOURCE_MARKER,
            json.dumps(
                {
                    "gate_id": "QSDK-R24D85",
                    "ok": True,
                    "published": published,
                    **counts,
                },
                sort_keys=True,
            ),
        )
        return 0
    require(args.core_library.is_file(), "CORE_LIBRARY_MISSING")
    print(json.dumps(run_preflight(contract, counts), sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (
        ClosureAuditError,
        controls.ControlError,
        AssertionError,
        KeyError,
        OSError,
        subprocess.SubprocessError,
        TypeError,
        ValueError,
    ) as error:
        print(f"QSDK_R24D85_SOURCE_FAIL {error}", file=sys.stderr)
        raise SystemExit(1) from error
