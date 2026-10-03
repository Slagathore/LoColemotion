#!/usr/bin/env python3
"""Reusable declarative gate for finite Godot/Jolt recovery production work."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
from typing import Any

from sdk.conformance import godot_recovery_route_zero_world_controls as controls
from sdk.conformance.content_addressed_zero_world_closure import (
    ClosureAuditError,
    load,
    require,
    retained_file_tree_projection,
    resolve_prospective_source_freeze,
    source_bytes,
    verify_bound_source_markers,
    verify_exact_retained_inventory,
    verify_exact_paths,
    verify_legacy_live_authority_projection,
)
from sdk.conformance.versioned_recovery_controller_target_gate import (
    validate_authored_delta,
)


_EXECUTION_PROFILES: dict[str, dict[str, Any]] = {
    "finite_behavior_development_v1": {
        "arm_count": 2,
        "world_count": 2,
        "ordered_arms": ["candidate_command", "matched_zero_command"],
        "candidate_and_matched_zero_run_sequentially": True,
        "maximum_model_construction_attempt_count": 2,
        "maximum_model_construction_count": 2,
        "maximum_world_attempt_count": 2,
        "maximum_world_build_count": 2,
        "outer_step_multiplier": 2,
        "evaluator_invocation_count": 1,
        "paired_arm_count": 1,
        "execution_contract_key": "behavior_execution_contract",
        "physical_question_kind": "behavior_development",
        "valid_complete_status": "valid_complete_behavior_development",
        "invalid_or_incomplete_status": "invalid_or_incomplete_behavior_development",
        "claim_declared_key": "finite_behavior_question_declared",
        "claim_result_key": "valid_complete_behavior_result",
        "policy_reuse_key": "reusable_finite_behavior_gate_reused",
        "terminal_consumed_path": "decision.behavior_attempt_consumed_for_exact_source",
    },
    "native_route_ghost_v1": {
        "arm_count": 1,
        "world_count": 1,
        "ordered_arms": ["candidate_command"],
        "candidate_and_matched_zero_run_sequentially": False,
        "maximum_model_construction_attempt_count": 1,
        "maximum_model_construction_count": 1,
        "maximum_world_attempt_count": 1,
        "maximum_world_build_count": 1,
        "outer_step_multiplier": 1,
        "evaluator_invocation_count": 0,
        "paired_arm_count": 0,
        "execution_contract_key": "route_execution_contract",
        "physical_question_kind": "integration_ghost",
        "valid_complete_status": "valid_complete_integration_ghost",
        "invalid_or_incomplete_status": "invalid_or_incomplete_integration_ghost",
        "claim_declared_key": "finite_route_ghost_declared",
        "claim_result_key": "valid_complete_route_result",
        "policy_reuse_key": "reusable_finite_gate_reused",
        "terminal_consumed_path": "decision.ghost_attempt_consumed_for_exact_source",
    },
}


def _execution_profile(contract: dict[str, Any]) -> tuple[str, dict[str, Any]]:
    profile_id = str(
        contract["audit_configuration"].get(
            "execution_profile_id", "finite_behavior_development_v1"
        )
    )
    controls.require(profile_id in _EXECUTION_PROFILES, "EXECUTION_PROFILE_ID")
    return profile_id, _EXECUTION_PROFILES[profile_id]


def _canonical_json(value: dict[str, Any]) -> bytes:
    return json.dumps(
        value, sort_keys=True, separators=(",", ":"), ensure_ascii=False
    ).encode("utf-8")


def _relative_file(root: Path, relative: str, code: str) -> Path:
    path = (root / relative).resolve()
    controls.require(path.is_relative_to(root.resolve()), f"{code}_ESCAPE")
    controls.require(path.is_file(), f"{code}_MISSING")
    return path


def _validate_finite_contract(
    contract: dict[str, Any],
    gate_id: str,
    contract_schema: str,
) -> None:
    config = contract["audit_configuration"]
    profile_id, profile = _execution_profile(contract)
    controls.require_fields(
        contract,
        {
            "schema_version": contract_schema,
            "gate_id": gate_id,
            "status": config["prospective_status"],
        },
        "CONTRACT_ROOT",
    )
    verify_exact_paths(
        contract,
        {
            "ledger_scope.subsystem": "recovery",
            "ledger_scope.engine_scope": "godot_jolt",
            "ledger_scope.question_class": "development",
        },
        "LEDGER_SCOPE",
    )
    controls.validate_development_question(contract, gate_id)

    population = contract["finite_development_population"]
    seed_label = str(population["seed_label"])
    seed_sha = "sha256:" + hashlib.sha256(seed_label.encode("utf-8")).hexdigest()
    controls.require_fields(
        population,
        {
            "seed_sha256": seed_sha,
            "held_out": False,
            "cell_count": 1,
            "physical_cohort_count": 1,
            "arm_count": profile["arm_count"],
            "world_count": profile["world_count"],
            "ordered_arms": profile["ordered_arms"],
            "candidate_and_matched_zero_run_sequentially": profile[
                "candidate_and_matched_zero_run_sequentially"
            ],
            "maximum_model_construction_attempt_count": profile[
                "maximum_model_construction_attempt_count"
            ],
            "maximum_model_construction_count": profile[
                "maximum_model_construction_count"
            ],
            "maximum_world_attempt_count": profile["maximum_world_attempt_count"],
            "maximum_world_build_count": profile["maximum_world_build_count"],
            "physics_ticks_per_second": 120,
            "outer_step_duration_s": 1.0 / 120.0,
            "behavior_evaluator_invocation_count": profile[
                "evaluator_invocation_count"
            ],
            "stop_exactly_at_terminal_or_budget": True,
            "complete_trace_retained": True,
            "every_native_step_has_in_run_invariant_receipt": True,
            "same_source_attempt_limit": 1,
            "same_identity_rerun_permitted": False,
            "repeatability_claimed": False,
            "population_inference_claimed": False,
            "cross_engine_equivalence_claimed": False,
        },
        "FINITE_POPULATION",
    )
    controls.require(
        int(population["maximum_total_outer_steps"])
        == int(profile["outer_step_multiplier"])
        * int(population["maximum_outer_steps_per_arm"]),
        "FINITE_POPULATION_STEP_PARTITION",
    )

    threshold = contract["threshold_and_margin_provenance"]
    representation_rule_count = config.get("declared_new_representation_rule_count", 0)
    controls.require(
        type(representation_rule_count) is int
        and representation_rule_count in (0, 1),
        "DECLARED_REPRESENTATION_RULE_COUNT",
    )
    controls.require_fields(
        threshold,
        {
            "maximum_outer_steps_per_arm": population[
                "maximum_outer_steps_per_arm"
            ],
            "threshold_change_count": 0,
            "margin_change_count": 0,
            "new_empirical_threshold_count": 0,
            "new_behavior_threshold_count": 0,
            "new_representation_rule_count": representation_rule_count,
            "equivalence_margin_count": 0,
            "non_inferiority_margin_count": 0,
            "physical_cohort_count": 1,
            "paired_arm_count": profile["paired_arm_count"],
            "held_out_cell_access_count": 0,
            "population_claim_count": 0,
        },
        "THRESHOLD_PROVENANCE",
    )

    worker_specs = config["zero_world_worker_specs"]
    positive_count = sum(int(item["expected"]["positive_case_count"])
                         for item in worker_specs)
    failure_count = sum(int(item["expected"]["forced_failure_case_count"])
                        for item in worker_specs)
    raw_binding_spec = config.get("raw_binding_control_spec")
    zero_gate = contract["complete_zero_world_gate"]
    controls.require_fields(
        zero_gate,
        {
            "must_pass_before_physics": True,
            "official_qualification_must_start_clean_pushed_equal": True,
            "official_qualification_attempt_limit_per_source_commit": 1,
            "current_worker_count": len(worker_specs),
            "current_positive_case_count": positive_count,
            "current_forced_failure_case_count": failure_count,
            "production_wrapper_runtime_identity_count": 1,
            "production_worker_parse_count": 1,
            "forced_supervisor_failure_control_count": 1,
            "missing_physical_switch_refusal_count": 1,
            "qualified_physical_path_partition_check_count": 1,
            "historical_closure_audits_executed_count": 0,
            "additional_physical_ghost_count": 0,
            "additional_physical_canary_count": 0,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
            "physical_execution_authorized": False,
            "maximum_physical_steps_authorized": 0,
        },
        "ZERO_GATE",
    )
    policy = contract["critical_path_audit_policy"]
    controls.require_fields(
        policy,
        {
            "current_zero_world_worker_count": len(worker_specs),
            "current_zero_world_positive_case_count": positive_count,
            "current_zero_world_forced_failure_case_count": failure_count,
            "production_worker_parse_count": 1,
            "historical_closure_audits_executed_count": 0,
            "full_seeded_ghost_count": 0,
            "bespoke_physical_canary_count": 0,
            "bespoke_campaign_source_audit_mechanics_added_count": 0,
            "thin_campaign_binding_required": True,
            "declarative_contract_specs_required": True,
            str(profile["policy_reuse_key"]): True,
            "shared_content_addressed_closure_mechanics_reused": True,
            "shared_process_control_module_reused": True,
        },
        "CRITICAL_PATH_POLICY",
    )
    if raw_binding_spec is not None:
        controls.require(isinstance(raw_binding_spec, dict), "RAW_BINDING_CONTROL_SPEC")
        controls.require_fields(
            raw_binding_spec["expected"],
            {
                "schema_version": raw_binding_spec["schema"],
                "gate_id": gate_id,
                "ok": True,
                "production_route_field": "energy_route_id",
                "rejected_legacy_only_route_field": "recovery_energy_route_id",
                "positive_case_count": 1,
                "positive_pass_count": 1,
                "forced_failure_case_count": 3,
                "forced_failure_pass_count": 3,
                "positive_checks": {"exact_energy_route_id": True},
                "forced_failure_checks": {
                    "missing_energy_route_id": True,
                    "wrong_energy_route_id": True,
                    "legacy_only_recovery_energy_route_id": True,
                },
                "model_construction_count": 0,
                "world_attempt_count": 0,
                "world_build_count": 0,
                "solver_step_count": 0,
                "physics_state_modified": False,
                "physics_evidence_authority": False,
                "physical_execution_authorized": False,
                "physical_acceptance_authority": False,
                "release_authority": False,
            },
            "RAW_BINDING_CONTROL_EXPECTED",
        )
        controls.require_fields(
            zero_gate,
            {
                "raw_binding_control_count": 1,
                "raw_binding_positive_case_count": 1,
                "raw_binding_forced_failure_case_count": 3,
            },
            "RAW_BINDING_ZERO_GATE",
        )
        controls.require_fields(
            policy,
            {
                "raw_binding_control_count": 1,
                "raw_binding_positive_case_count": 1,
                "raw_binding_forced_failure_case_count": 3,
            },
            "RAW_BINDING_POLICY",
        )

    execution = contract[str(profile["execution_contract_key"])]
    controls.require_fields(
        execution,
        {
            "genuine_engine": "godot_4_7_jolt",
            "actuator_mode": config["actuator_mode"],
            "numeric_predicate_id": config["numeric_predicate_id"],
            "worker_path": config["production_worker_path"],
            "native_engine_health_required": True,
            "physical_success_required_for_worker_validity": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        "BEHAVIOR_EXECUTION",
    )
    runner = contract["physical_runner"]
    controls.require_fields(
        runner,
        {
            "script_path": config["physical_runner_path"],
            "worker_path": config["production_worker_path"],
            "actuator_mode": config["actuator_mode"],
            "physical_question_kind": profile["physical_question_kind"],
            "published_closure_authorization_control_required": False,
            "direct_committed_closure_recheck_under_operation_lock_required": True,
            "qualified_physical_source_drift_check_required": True,
            "complete_raw_invariant_scan_required_after_physics": True,
            "valid_complete_status": profile["valid_complete_status"],
            "invalid_or_incomplete_status": profile["invalid_or_incomplete_status"],
        },
        "PHYSICAL_RUNNER",
    )
    if raw_binding_spec is not None:
        controls.require_fields(
            runner,
            {
                "raw_result_energy_route_field": raw_binding_spec["expected"][
                    "production_route_field"
                ],
            },
            "RAW_BINDING_RUNNER",
        )
    progress_spec = config.get("progress_observability_control_spec")
    if progress_spec is not None:
        controls.require(isinstance(progress_spec, dict), "PROGRESS_CONTROL_SPEC")
        controls.require_fields(
            runner,
            {
                "progress_observability_enabled": True,
                "progress_marker": progress_spec["production_progress_marker"],
                "progress_cadence_steps": progress_spec["arguments"][
                    "ProgressCadenceSteps"
                ],
                "progress_stall_timeout_seconds": progress_spec["arguments"][
                    "DeclaredProgressStallTimeoutSeconds"
                ],
                "physical_timeout_seconds": progress_spec["arguments"][
                    "DeclaredTotalTimeoutSeconds"
                ],
                "progress_receipts_are_behavior_evidence": False,
            },
            "PROGRESS_RUNNER",
        )
        controls.require_fields(
            progress_spec["arguments"],
            {
                "MaximumSolverSteps": population["maximum_total_outer_steps"],
                "RequiredTotalMarginFactor": 1.25,
                "RequiredStallMarginFactor": 2.0,
            },
            "PROGRESS_CONTROL_ARGUMENTS",
        )
        controls.require_fields(
            progress_spec["expected"],
            {
                "schema_version": (
                    "sporespore_godot_progress_observability_zero_world_v1"
                ),
                "ok": True,
                "positive_case_count": 1,
                "forced_failure_case_count": 2,
                "invalid_sequence_rejected": True,
                "progress_stall_detected": True,
                "model_construction_count": 0,
                "world_attempt_count": 0,
                "world_build_count": 0,
                "solver_step_count": 0,
                "physics_state_modified": False,
                "physics_evidence_authority": False,
                "physical_acceptance_authority": False,
                "release_authority": False,
            },
            "PROGRESS_CONTROL_EXPECTED",
        )
        controls.require_fields(
            zero_gate,
            {
                "progress_observability_control_count": 1,
                "progress_observability_positive_case_count": 1,
                "progress_observability_forced_failure_case_count": 2,
            },
            "PROGRESS_ZERO_GATE",
        )
        controls.require_fields(
            policy,
            {
                "progress_observability_control_count": 1,
                "progress_observability_positive_case_count": 1,
                "progress_observability_forced_failure_case_count": 2,
            },
            "PROGRESS_POLICY",
        )
    authorization = contract["physical_authorization_projection"]
    controls.require_fields(
        authorization,
        {
            "gate_id": gate_id,
            "question_class": "development",
            "seed": population["cell_seed"],
            "seed_label": seed_label,
            "seed_sha256": seed_sha,
            "held_out": False,
            "maximum_model_construction_attempt_count": profile[
                "maximum_model_construction_attempt_count"
            ],
            "maximum_model_construction_count": profile[
                "maximum_model_construction_count"
            ],
            "maximum_world_attempt_count": profile["maximum_world_attempt_count"],
            "maximum_world_build_count": profile["maximum_world_build_count"],
            "maximum_outer_solver_steps": population["maximum_total_outer_steps"],
            "physics_ticks_per_second": 120,
            "outer_step_duration_s": 1.0 / 120.0,
            "behavior_evaluator_invocation_count": profile[
                "evaluator_invocation_count"
            ],
            "same_identity_rerun_permitted": False,
            "recovery_success_required": False,
            "physical_execution_authorized": False,
            "prone_to_standing_claimed": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        "AUTHORIZATION",
    )
    controls.require_fields(
        contract["claim_boundary"],
        {
            str(profile["claim_declared_key"]): True,
            "complete_zero_world_gate_passed": False,
            "physical_execution_authorized": False,
            "physical_attempted": False,
            str(profile["claim_result_key"]): False,
            "prone_to_standing_claimed": False,
            "repeatability_claimed": False,
            "population_claimed": False,
            "cross_engine_recovery_claimed": False,
            "cross_engine_equivalence_claimed": False,
            "sdk1_milestone_advanced": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        "CLAIM_BOUNDARY",
    )
    controls.require(
        config.get("execution_profile_id", "finite_behavior_development_v1")
        == profile_id,
        "EXECUTION_PROFILE",
    )


def _validate_bound_evidence(root: Path, contract: dict[str, Any]) -> None:
    config = contract["audit_configuration"]
    predecessor_relative = str(contract["bound_predecessors"][0]["path"])
    predecessor = controls.validate_bound_predecessor(
        root, contract, _relative_file(root, predecessor_relative, "PREDECESSOR")
    )
    verify_exact_paths(
        predecessor, config["predecessor_expected_paths"], "PREDECESSOR"
    )
    for index, binding in enumerate(config["immutable_json_bindings"]):
        path = _relative_file(root, str(binding["path"]), f"IMMUTABLE_JSON_{index}")
        raw = path.read_bytes()
        controls.require_fields(
            binding,
            {
                "byte_length": len(raw),
                "raw_sha256": "sha256:" + hashlib.sha256(raw).hexdigest(),
            },
            f"IMMUTABLE_JSON_{index}",
        )
        value = json.loads(raw)
        controls.require(isinstance(value, dict), f"IMMUTABLE_JSON_{index}_ROOT")
        verify_exact_paths(
            value, binding["expected_paths"], f"IMMUTABLE_JSON_{index}"
        )
    for index, binding in enumerate(config.get("immutable_file_bindings", [])):
        path = _relative_file(root, str(binding["path"]), f"IMMUTABLE_FILE_{index}")
        raw = path.read_bytes()
        controls.require_fields(
            binding,
            {
                "byte_length": len(raw),
                "raw_sha256": "sha256:" + hashlib.sha256(raw).hexdigest(),
            },
            f"IMMUTABLE_FILE_{index}",
        )
    retained = config.get("retained_invalid_qualification")
    if retained is not None:
        record_path = _relative_file(
            root,
            str(retained["record_path"]),
            "RETAINED_INVALID_QUALIFICATION_RECORD",
        )
        record_raw = record_path.read_bytes()
        controls.require_fields(
            retained,
            {
                "record_byte_length": len(record_raw),
                "record_raw_sha256": (
                    "sha256:" + hashlib.sha256(record_raw).hexdigest()
                ),
            },
            "RETAINED_INVALID_QUALIFICATION_RECORD",
        )
        record = json.loads(record_raw)
        controls.require(
            isinstance(record, dict),
            "RETAINED_INVALID_QUALIFICATION_RECORD_ROOT",
        )
        verify_exact_paths(
            record,
            retained["record_expected_paths"],
            "RETAINED_INVALID_QUALIFICATION_RECORD",
        )
        evidence_root = Path(str(retained["evidence_root"]))
        controls.require(
            Path(str(record["attempt"]["evidence_root"])) == evidence_root,
            "RETAINED_INVALID_QUALIFICATION_EVIDENCE_ROOT",
        )
        verify_exact_retained_inventory(
            evidence_root,
            record["retained_evidence"]["files"],
        )
        verify_exact_paths(
            record["retained_evidence"]["tree"],
            retained_file_tree_projection(evidence_root),
            "RETAINED_INVALID_QUALIFICATION_TREE",
        )
        for relative, expected in retained["artifact_expected_paths"].items():
            verify_exact_paths(
                load(evidence_root / relative),
                expected,
                f"RETAINED_INVALID_QUALIFICATION_ARTIFACT:{relative}",
            )


def validate_sources(
    root: Path,
    contract_relative_path: str,
    contract_schema: str,
    *,
    terminal_closure_relative_path: str | None = None,
    terminal_closure_schema: str | None = None,
    terminal_closure_raw_sha256: str | None = None,
    terminal_closure_byte_length: int | None = None,
    terminal_live_keys: tuple[str, ...] = (),
) -> tuple[dict[str, Any], dict[str, int], bool, str]:
    contract_path = _relative_file(root, contract_relative_path, "CONTRACT")
    contract = load(contract_path)
    gate_id = str(contract["gate_id"])
    config = contract["audit_configuration"]
    _, profile = _execution_profile(contract)
    _validate_finite_contract(contract, gate_id, contract_schema)
    _validate_bound_evidence(root, contract)
    closure_path = root / str(config["closure_path"])
    development_worktree = False
    if not closure_path.is_file():
        validate_authored_delta(root, contract)
        head = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            cwd=root,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="strict",
            check=True,
        ).stdout.strip()
        development_worktree = head == str(contract["authored_parent_commit"])
    source_commit, published = resolve_prospective_source_freeze(
        root=root,
        contract=contract,
        closure_path=closure_path,
        closure_schema=str(config["closure_schema"]),
        gate_id=gate_id,
    )
    marker_specs = config["source_marker_specs"]
    bound = {
        str(spec["path"]): (
            _relative_file(
                root,
                str(spec["path"]),
                "SOURCE_MARKER_WORKTREE",
            ).read_bytes()
            if development_worktree
            else source_bytes(root, source_commit, str(spec["path"]))
        )
        for spec in marker_specs
    }
    verify_bound_source_markers(
        bound,
        {
            str(spec["path"]): tuple(str(item) for item in spec["ordered_markers"])
            for spec in marker_specs
        },
        "SOURCE_MARKERS",
    )
    counts = controls.validate_route_source_populations(root, contract)
    policy = contract["critical_path_audit_policy"]
    controls.require_fields(
        counts,
        {
            "source_inventory_count": policy["source_inventory_count"],
            "authored_source_path_count": policy["authored_source_path_count"],
            "qualified_physical_path_count": policy["qualified_physical_path_count"],
            "bound_predecessor_count": 1,
            "current_zero_world_worker_count": policy[
                "current_zero_world_worker_count"
            ],
            "production_worker_parse_count": 1,
            "historical_closure_audits_executed_count": 0,
            "full_seeded_ghost_count": 0,
            "bespoke_physical_canary_count": 0,
        },
        "COUNTS",
    )
    live = config["live_authority"]
    expected = {
        **live["base_expected"],
        **(live["qualified_expected"] if published else live["prospective_expected"]),
    }
    if published:
        expected[str(live["qualified_source_commit_key"])] = source_commit
        expected[str(live["qualified_closure_path_key"])] = str(config["closure_path"])
    if terminal_closure_relative_path is not None:
        controls.require(published, "TERMINAL_LIVE_TRANSITION_BEFORE_PUBLICATION")
        controls.require(
            terminal_closure_schema is not None
            and terminal_closure_raw_sha256 is not None
            and terminal_closure_byte_length is not None
            and bool(terminal_live_keys),
            "TERMINAL_LIVE_TRANSITION_BINDING",
        )
        terminal_path = _relative_file(
            root, terminal_closure_relative_path, "TERMINAL_CLOSURE"
        )
        terminal_raw = terminal_path.read_bytes()
        controls.require_fields(
            {
                "byte_length": len(terminal_raw),
                "raw_sha256": "sha256:" + hashlib.sha256(terminal_raw).hexdigest(),
            },
            {
                "byte_length": terminal_closure_byte_length,
                "raw_sha256": terminal_closure_raw_sha256,
            },
            "TERMINAL_CLOSURE_IDENTITY",
        )
        terminal = json.loads(terminal_raw)
        verify_exact_paths(
            terminal,
            {
                "schema_version": terminal_closure_schema,
                "gate_id": gate_id,
                str(profile["terminal_consumed_path"]): True,
                "decision.same_identity_rerun_permitted": False,
                "decision.physical_execution_authorized": False,
                "claim_boundary.physical_attempt_consumed": True,
                "claim_boundary.physical_acceptance_authority": False,
                "claim_boundary.release_authority": False,
            },
            "TERMINAL_CLOSURE",
        )
        _relative_file(
            root, str(terminal["closure_audit_path"]), "TERMINAL_CLOSURE_AUDIT"
        )
        terminal_projection = terminal["live_authority_projection"]
        for key in terminal_live_keys:
            controls.require(key in expected, f"TERMINAL_LIVE_KEY_NOT_QUALIFIED:{key}")
            controls.require(
                key in terminal_projection,
                f"TERMINAL_LIVE_KEY_NOT_PROJECTED:{key}",
            )
            expected[key] = terminal_projection[key]
    verify_legacy_live_authority_projection(
        root,
        tuple(str(path) for path in live["authority_paths"]),
        record_key=str(live["record_key"]),
        expected=expected,
        prefix=str(live["prefix"]),
    )
    return contract, counts, published, source_commit


def run_preflight(
    root: Path,
    contract: dict[str, Any],
    counts: dict[str, int],
) -> dict[str, Any]:
    gate_id = str(contract["gate_id"])
    config = contract["audit_configuration"]
    executable = Path(contract["exact_runtime"]["console_path"])
    worker_specs = tuple(
        {
            **spec,
            "path": _relative_file(root, str(spec["path"]), "ZERO_WORKER"),
        }
        for spec in config["zero_world_worker_specs"]
    )
    workers = controls.run_zero_world_worker_specs(root, executable, worker_specs)
    equivalence = config["canonical_receipt_equivalence"]
    equivalent_receipt = workers[str(equivalence["worker_id"])]
    canonical = _canonical_json(equivalent_receipt)
    controls.require_fields(
        equivalence,
        {
            "canonical_byte_length": len(canonical),
            "canonical_sha256": "sha256:" + hashlib.sha256(canonical).hexdigest(),
        },
        "CANONICAL_RECEIPT_EQUIVALENCE",
    )
    runner = _relative_file(
        root, str(config["physical_runner_path"]), "PHYSICAL_RUNNER"
    )
    runtime_identity = controls.run_route_runtime_identity(
        root,
        runner,
        str(config["supervisor_marker"]),
        gate_id=gate_id,
        schema=str(config["runtime_identity_schema"]),
        contract=contract,
        worker_relative_path=str(config["production_worker_path"]),
        actuator_mode=str(config["actuator_mode"]),
        expected_fields=dict(config.get("runtime_identity_expected_fields", {})),
    )
    raw_binding_control = None
    if "raw_binding_control_spec" in config:
        raw_binding_control = controls.run_raw_binding_control(
            root,
            runner,
            str(config["supervisor_marker"]),
            dict(config["raw_binding_control_spec"]),
        )
    projection = controls.run_projection_control(
        root, runner, str(config["supervisor_marker"]), gate_id
    )
    refusal = controls.run_missing_physical_switch_refusal(
        root,
        runner,
        str(config["supervisor_marker"]),
        gate_id,
        str(config["missing_switch_receipt_schema"]),
    )
    controls.require_zero_authority(projection)
    controls.require_zero_authority(refusal)
    progress_control = None
    if "progress_observability_control_spec" in config:
        progress_control = controls.run_progress_observability_control(
            root,
            dict(config["progress_observability_control_spec"]),
        )
    policy = contract["critical_path_audit_policy"]
    receipt = {
        "schema_version": config["preflight_schema"],
        "gate_id": gate_id,
        "ok": True,
        "runtime_id": contract["exact_runtime"]["runtime_profile_id"],
        "runtime_version": contract["exact_runtime"]["runtime_version"],
        "actuator_mode": config["actuator_mode"],
        "numeric_predicate_id": config["numeric_predicate_id"],
        **counts,
        "current_zero_world_positive_case_count": policy[
            "current_zero_world_positive_case_count"
        ],
        "current_zero_world_forced_failure_case_count": policy[
            "current_zero_world_forced_failure_case_count"
        ],
        "historical_closure_audits_executed_count": 0,
        "full_seeded_ghost_count": 0,
        "bespoke_physical_canary_count": 0,
        "current_worker_receipts": workers,
        "canonical_predecessor_receipt_equivalence_passed": True,
        "canonical_predecessor_receipt_sha256": (
            "sha256:" + hashlib.sha256(canonical).hexdigest()
        ),
        "production_wrapper_runtime_identity_receipt": runtime_identity,
        "supervisor_projection_receipt": projection,
        "missing_physical_switch_refusal_receipt": refusal,
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
    if progress_control is not None:
        receipt["progress_observability_control_receipt"] = progress_control
    if raw_binding_control is not None:
        receipt["production_raw_binding_control_receipt"] = raw_binding_control
    return receipt


def run_cli(
    root: Path,
    contract_relative_path: str,
    contract_schema: str,
    *,
    terminal_closure_relative_path: str | None = None,
    terminal_closure_schema: str | None = None,
    terminal_closure_raw_sha256: str | None = None,
    terminal_closure_byte_length: int | None = None,
    terminal_live_keys: tuple[str, ...] = (),
) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--core-library", type=Path)
    args = parser.parse_args()
    fallback_marker = "QSDK_FINITE_GODOT_RECOVERY_BEHAVIOR_GATE_FAIL"
    try:
        contract, counts, published, _ = validate_sources(
            root,
            contract_relative_path,
            contract_schema,
            terminal_closure_relative_path=terminal_closure_relative_path,
            terminal_closure_schema=terminal_closure_schema,
            terminal_closure_raw_sha256=terminal_closure_raw_sha256,
            terminal_closure_byte_length=terminal_closure_byte_length,
            terminal_live_keys=terminal_live_keys,
        )
        config = contract["audit_configuration"]
        if args.core_library is None:
            print(
                config["source_pass_marker"],
                json.dumps(
                    {
                        "gate_id": contract["gate_id"],
                        "ok": True,
                        "published": published,
                        **counts,
                    },
                    sort_keys=True,
                ),
            )
            return 0
        require(args.core_library.is_file(), "CORE_LIBRARY_MISSING")
        print(json.dumps(run_preflight(root, contract, counts), sort_keys=True))
        return 0
    except (
        ClosureAuditError,
        controls.ControlError,
        KeyError,
        OSError,
        subprocess.CalledProcessError,
        TypeError,
        ValueError,
    ) as error:
        marker = fallback_marker
        try:
            value = load(root / contract_relative_path)
            marker = str(value["audit_configuration"]["failure_marker"])
        except (OSError, KeyError, TypeError, ValueError):
            pass
        print(f"{marker}:{error}", file=sys.stderr)
        return 1
