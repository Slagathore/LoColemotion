#!/usr/bin/env python3
"""Reusable publication audit for finite Godot recovery qualifications."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess
import sys
from typing import Any

from sdk.conformance import godot_recovery_route_zero_world_controls as controls
from sdk.conformance.content_addressed_zero_world_closure import (
    ClosureAuditError,
    canonical_bytes,
    git,
    load,
    retained_file_tree_projection,
    source_bytes,
    verify_exact_paths,
    verify_exact_retained_inventory,
    verify_retained_commit,
    verify_source_binding,
    verify_source_receipt_manifest,
)


def _identity(raw: bytes, value: dict[str, Any], prefix: str) -> None:
    controls.require_fields(
        value,
        {
            f"{prefix}_byte_length": len(raw),
            f"{prefix}_raw_sha256": "sha256:" + hashlib.sha256(raw).hexdigest(),
        },
        prefix.upper(),
    )


def _canonical_identity(value: Any, expected: dict[str, Any], prefix: str) -> None:
    raw = canonical_bytes(value)
    controls.require_fields(
        expected,
        {
            f"{prefix}_canonical_byte_length": len(raw),
            f"{prefix}_canonical_sha256": "sha256:" + hashlib.sha256(raw).hexdigest(),
        },
        prefix.upper(),
    )


def _require_zero_authority(value: dict[str, Any], prefix: str) -> None:
    controls.require_fields(
        value,
        {
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
            "physical_question_opened": False,
            "prone_to_standing_claimed": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        prefix,
    )


def _validate_source(
    root: Path,
    closure: dict[str, Any],
) -> tuple[str, dict[str, Any]]:
    source = closure["source"]
    freeze = str(source["source_freeze_commit"])
    controls.require_fields(
        source,
        {
            "commit": freeze,
            "branch": "main",
            "remote": "https://github.com/Slagathore/sporespore.git",
            "upstream_equal_at_qualification": True,
            "live_remote_equal_at_qualification": True,
            "worktree_clean_at_qualification_start_and_end": True,
        },
        "SOURCE",
    )
    verify_retained_commit(root, freeze, str(source["parent_commit"]))
    controls.require(
        git(root, "show", "-s", "--format=%T", freeze) == source["tree"],
        "SOURCE_TREE",
    )
    controls.require(
        git(root, "show", "-s", "--format=%s", freeze) == source["subject"],
        "SOURCE_SUBJECT",
    )
    contract_raw = verify_source_binding(root, freeze, source["contract"])
    contract = json.loads(contract_raw)
    controls.require(isinstance(contract, dict), "SOURCE_CONTRACT_ROOT")
    for binding in source["source_bindings"]:
        verify_source_binding(root, freeze, binding)
    controls.require(
        int(source["source_manifest_entry_count"])
        == len(contract["source_inventory"]),
        "SOURCE_MANIFEST_COUNT",
    )
    return freeze, contract


def _validate_bound_evidence(
    root: Path,
    closure: dict[str, Any],
    contract: dict[str, Any],
) -> None:
    predecessor = closure["predecessor"]
    predecessor_path = root / str(predecessor["closure_path"])
    raw = predecessor_path.read_bytes()
    controls.require_fields(
        predecessor,
        {
            "closure_byte_length": len(raw),
            "closure_raw_sha256": "sha256:" + hashlib.sha256(raw).hexdigest(),
            "historical_closure_audit_reexecuted": False,
            "historical_result_rewritten": False,
            "historical_threshold_rewritten": False,
            "historical_evaluator_rewritten": False,
            "historical_interpretation_rewritten": False,
            "same_identity_rerun_permitted": False,
            "same_identity_requalification_permitted": False,
        },
        "PREDECESSOR",
    )
    predecessor_value = json.loads(raw)
    predecessor_status_field = str(
        predecessor.get("status_field", "closure_status")
    )
    controls.require(
        predecessor_status_field in ("closure_status", "status"),
        "PREDECESSOR_STATUS_FIELD",
    )
    controls.require_fields(
        predecessor_value,
        {
            "gate_id": predecessor["gate_id"],
            predecessor_status_field: predecessor["closure_status"],
        },
        "PREDECESSOR_CONTENT",
    )
    development = closure["development_evidence"]
    bindings = development.get("immutable_json_bindings")
    if bindings is None:
        # R101 predates the declarative binding population. Preserve its exact
        # legacy closure without forcing a historical schema rewrite.
        diagnosis_path = root / str(development["r24d100_diagnosis_path"])
        diagnosis_raw = diagnosis_path.read_bytes()
        controls.require_fields(
            development,
            {
                "r24d100_diagnosis_byte_length": len(diagnosis_raw),
                "r24d100_diagnosis_raw_sha256": (
                    "sha256:" + hashlib.sha256(diagnosis_raw).hexdigest()
                ),
                "r99_qualified_worker_receipt_cold_equivalence_passed": True,
            },
            "DEVELOPMENT_EVIDENCE",
        )
        return

    declared_bindings = contract.get("audit_configuration", {}).get(
        "immutable_json_bindings"
    )
    controls.require(isinstance(bindings, list), "DEVELOPMENT_EVIDENCE_BINDINGS")
    if declared_bindings is not None:
        controls.require(
            bindings == declared_bindings,
            "DEVELOPMENT_EVIDENCE_BINDINGS_CONTRACT",
        )
    controls.require_fields(
        development,
        {
            "historical_closure_audits_reexecuted_count": 0,
            "canonical_current_worker_receipt_equivalence_passed": True,
        },
        "DEVELOPMENT_EVIDENCE",
    )
    for index, binding in enumerate(bindings):
        controls.require(isinstance(binding, dict), f"DEVELOPMENT_BINDING:{index}")
        path = root / str(binding["path"])
        controls.require(path.is_file(), f"DEVELOPMENT_BINDING_MISSING:{index}")
        raw = path.read_bytes()
        controls.require_fields(
            binding,
            {
                "byte_length": len(raw),
                "raw_sha256": "sha256:" + hashlib.sha256(raw).hexdigest(),
            },
            f"DEVELOPMENT_BINDING_{index}",
        )
        value = json.loads(raw)
        controls.require(isinstance(value, dict), f"DEVELOPMENT_BINDING_ROOT:{index}")
        verify_exact_paths(
            value,
            dict(binding["expected_paths"]),
            f"DEVELOPMENT_BINDING_{index}",
        )


def _validate_qualification_history(
    root: Path,
    closure: dict[str, Any],
    contract: dict[str, Any],
    freeze: str,
) -> None:
    history = closure.get("qualification_history")
    if history is None:
        return
    controls.require(isinstance(history, dict), "QUALIFICATION_HISTORY_ROOT")
    prior = history["prior_invalid_attempt"]
    controls.require(
        prior
        == contract["audit_configuration"]["retained_invalid_qualification"],
        "QUALIFICATION_HISTORY_FROZEN_BINDING",
    )
    controls.require_fields(
        history,
        {
            "official_attempt_count_across_sources": 2,
            "valid_complete_attempt_count": 1,
            "invalid_or_incomplete_attempt_count": 1,
            "same_source_retry_occurred": False,
            "source_commits": [
                str(prior["record_expected_paths"]["source.commit"]),
                freeze,
            ],
        },
        "QUALIFICATION_HISTORY",
    )
    record_path = root / str(prior["record_path"])
    record_raw = record_path.read_bytes()
    controls.require_fields(
        prior,
        {
            "record_byte_length": len(record_raw),
            "record_raw_sha256": (
                "sha256:" + hashlib.sha256(record_raw).hexdigest()
            ),
        },
        "QUALIFICATION_HISTORY_RECORD",
    )
    record = json.loads(record_raw)
    controls.require(isinstance(record, dict), "QUALIFICATION_HISTORY_RECORD_ROOT")
    verify_exact_paths(
        record,
        dict(prior["record_expected_paths"]),
        "QUALIFICATION_HISTORY_RECORD",
    )
    evidence_root = Path(str(prior["evidence_root"]))
    controls.require(
        Path(str(record["attempt"]["evidence_root"])) == evidence_root,
        "QUALIFICATION_HISTORY_EVIDENCE_ROOT",
    )
    verify_exact_retained_inventory(
        evidence_root,
        record["retained_evidence"]["files"],
    )
    verify_exact_paths(
        record["retained_evidence"]["tree"],
        retained_file_tree_projection(evidence_root),
        "QUALIFICATION_HISTORY_TREE",
    )
    for relative, expected in prior["artifact_expected_paths"].items():
        verify_exact_paths(
            load(evidence_root / relative),
            expected,
            f"QUALIFICATION_HISTORY_ARTIFACT:{relative}",
        )

    observed: list[dict[str, str]] = []
    parent = Path(str(history["evidence_parent"]))
    for directory in sorted(parent.glob(f"{history['directory_prefix']}*")):
        attempt_path = directory / "qualification_attempt.json"
        if not attempt_path.is_file():
            continue
        attempt = load(attempt_path)
        if (
            attempt.get("gate_id") != closure["gate_id"]
            or attempt.get("mode") != "qualification"
        ):
            continue
        has_receipt = (directory / "qualification_receipt.json").is_file()
        has_failure = (directory / "qualification_failure.json").is_file()
        controls.require(has_receipt != has_failure, "QUALIFICATION_HISTORY_TERMINAL")
        observed.append(
            {
                "source_commit": str(attempt["source_commit"]),
                "evidence_root": directory.as_posix(),
                "result_class": (
                    "valid_complete" if has_receipt else "invalid_or_incomplete"
                ),
            }
        )
    controls.require_fields(
        history,
        {"attempt_population": observed},
        "QUALIFICATION_HISTORY_POPULATION",
    )


def _validate_manifest_representation(
    root: Path,
    freeze: str,
    manifest: list[dict[str, Any]],
    declared: dict[str, Any],
) -> None:
    oid_matches = 0
    raw_matches = 0
    checkout_only_paths: list[str] = []
    for entry in manifest:
        relative = str(entry["path"])
        raw = source_bytes(root, freeze, relative)
        oid = git(root, "rev-parse", f"{freeze}:{relative}")
        if oid == entry["git_blob_oid"]:
            oid_matches += 1
        if (
            len(raw) == entry["byte_length"]
            and "sha256:" + hashlib.sha256(raw).hexdigest() == entry["raw_sha256"]
        ):
            raw_matches += 1
        else:
            checkout_only_paths.append(relative)
    controls.require_fields(
        declared,
        {
            "git_blob_oid_match_count": oid_matches,
            "git_blob_raw_byte_match_count": raw_matches,
            "checkout_only_entry_count": len(checkout_only_paths),
            "checkout_only_paths": checkout_only_paths,
            "cause": "existing_windows_checkout_mixed_line_ending_materialization",
            "git_attribute": "text eol=lf",
        },
        "SOURCE_MANIFEST_REPRESENTATION",
    )
    witnesses = declared.get("line_ending_materialization_witnesses")
    if witnesses is not None:
        controls.require(
            isinstance(witnesses, list)
            and len(witnesses) == len(checkout_only_paths),
            "SOURCE_MANIFEST_LINE_ENDING_WITNESS_COUNT",
        )
        witness_paths = [str(item["path"]) for item in witnesses]
        controls.require(
            len(witness_paths) == len(set(witness_paths))
            and sorted(witness_paths) == sorted(checkout_only_paths),
            "SOURCE_MANIFEST_LINE_ENDING_WITNESS_PATHS",
        )
        manifest_by_path = {str(item["path"]): item for item in manifest}
        for witness in witnesses:
            relative = str(witness["path"])
            raw = source_bytes(root, freeze, relative)
            controls.require(
                b"\r\n" not in raw,
                f"SOURCE_MANIFEST_GIT_BLOB_NOT_LF:{relative}",
            )
            line_feed_count = raw.count(b"\n")
            ranges = witness["crlf_zero_based_line_ranges"]
            controls.require(isinstance(ranges, list), f"LINE_RANGE_TYPE:{relative}")
            crlf_indices: set[int] = set()
            prior_end = -1
            for item in ranges:
                controls.require(
                    isinstance(item, list)
                    and len(item) == 2
                    and all(isinstance(value, int) for value in item),
                    f"LINE_RANGE_SHAPE:{relative}",
                )
                start, end = item
                controls.require(
                    0 <= start <= end < line_feed_count and start > prior_end,
                    f"LINE_RANGE_BOUNDS:{relative}",
                )
                crlf_indices.update(range(start, end + 1))
                prior_end = end
            rebuilt = bytearray()
            cursor = 0
            for line_index in range(line_feed_count):
                newline = raw.index(b"\n", cursor)
                rebuilt.extend(raw[cursor:newline])
                rebuilt.extend(b"\r\n" if line_index in crlf_indices else b"\n")
                cursor = newline + 1
            rebuilt.extend(raw[cursor:])
            checkout_raw = bytes(rebuilt)
            entry = manifest_by_path[relative]
            controls.require_fields(
                witness,
                {
                    "git_raw_sha256": (
                        "sha256:" + hashlib.sha256(raw).hexdigest()
                    ),
                    "git_byte_length": len(raw),
                    "line_feed_count": line_feed_count,
                    "crlf_count": len(crlf_indices),
                    "checkout_raw_sha256": entry["raw_sha256"],
                    "checkout_byte_length": entry["byte_length"],
                },
                f"SOURCE_MANIFEST_LINE_ENDING_WITNESS:{relative}",
            )
            controls.require(
                len(checkout_raw) == entry["byte_length"]
                and "sha256:" + hashlib.sha256(checkout_raw).hexdigest()
                == entry["raw_sha256"],
                f"SOURCE_MANIFEST_LINE_ENDING_RECONSTRUCTION:{relative}",
            )
        controls.require_fields(
            declared,
            {
                "line_ending_materialization_proven_count": (
                    len(witnesses)
                )
            },
            "SOURCE_MANIFEST_LINE_ENDING_MATERIALIZATION",
        )


def _qualification_contract_raw_sha256(closure: dict[str, Any]) -> str:
    """Return the exact checkout identity observed by the qualification.

    Git remains the source binding. A distinct checkout identity is admitted
    only for an explicitly declared mixed-line-ending representation and is
    cross-checked against the retained source manifest below.
    """

    binding = closure["source"]["contract"]
    has_sha = "qualification_checkout_raw_sha256" in binding
    has_length = "qualification_checkout_byte_length" in binding
    controls.require(has_sha == has_length, "SOURCE_CONTRACT_CHECKOUT_PAIR")
    return str(
        binding["qualification_checkout_raw_sha256"]
        if has_sha
        else binding["raw_sha256"]
    )


def _validate_qualification_contract_representation(
    closure: dict[str, Any],
    manifest: list[dict[str, Any]],
) -> None:
    binding = closure["source"]["contract"]
    path = str(binding["path"])
    matches = [entry for entry in manifest if str(entry["path"]) == path]
    controls.require(len(matches) == 1, "SOURCE_CONTRACT_MANIFEST_ENTRY")
    entry = matches[0]
    declared = closure["qualification"][
        "source_manifest_representation_evidence"
    ]
    checkout_paths = [str(item) for item in declared["checkout_only_paths"]]
    has_checkout = "qualification_checkout_raw_sha256" in binding
    controls.require(
        has_checkout == (path in checkout_paths),
        "SOURCE_CONTRACT_CHECKOUT_DECLARATION",
    )
    if has_checkout:
        controls.require_fields(
            entry,
            {
                "raw_sha256": binding["qualification_checkout_raw_sha256"],
                "byte_length": binding["qualification_checkout_byte_length"],
                "git_blob_oid": binding["git_blob_oid"],
            },
            "SOURCE_CONTRACT_CHECKOUT_MANIFEST",
        )
        controls.require(
            binding["qualification_checkout_raw_sha256"]
            != binding["raw_sha256"],
            "SOURCE_CONTRACT_CHECKOUT_NOT_DISTINCT",
        )


def _validate_qualification(
    root: Path,
    closure: dict[str, Any],
    freeze: str,
    contract: dict[str, Any],
) -> dict[str, Any]:
    qualification = closure["qualification"]
    evidence_root = Path(str(qualification["evidence_root"]))
    controls.require(evidence_root.is_dir(), "EVIDENCE_ROOT")
    policy = contract["critical_path_audit_policy"]
    controls.require_fields(
        qualification,
        {
            "official_zero_world_qualification_passed": True,
            "official_qualification_attempt_count_for_source": 1,
            "retained_tree": retained_file_tree_projection(evidence_root),
            "source_manifest_entry_count": len(contract["source_inventory"]),
            "source_manifest_raw_representation": (
                "observed_checkout_plus_git_blob"
            ),
            "check_count": 10,
            "checks_passed": 10,
            "source_inventory_count": len(contract["source_inventory"]),
            "authored_source_path_count": len(contract["authored_source_paths"]),
            "qualified_physical_path_count": len(
                contract["qualified_physical_paths"]
            ),
            "current_zero_world_worker_count": policy[
                "current_zero_world_worker_count"
            ],
            "current_zero_world_positive_case_count": policy[
                "current_zero_world_positive_case_count"
            ],
            "current_zero_world_forced_failure_case_count": policy[
                "current_zero_world_forced_failure_case_count"
            ],
            "production_worker_parse_count": 1,
            "forced_supervisor_failure_control_count": 1,
            "missing_physical_switch_refusal_count": 1,
            "historical_closure_audits_executed_count": 0,
            "bespoke_physical_canary_count": 0,
            "full_seeded_ghost_count": 0,
            "canonical_predecessor_receipt_equivalence_passed": True,
            "held_out_cell_access_count": 0,
            "held_out_selector_invocation_count": 0,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physical_execution_count": 0,
            "physics_state_modified": False,
            "physical_question_opened": False,
            "controller_physical_viability_proven": False,
            "operation_lock_released": True,
        },
        "QUALIFICATION",
    )
    controls.require(
        not (evidence_root / "qualification_failure.json").exists(),
        "QUALIFICATION_FAILURE_PRESENT",
    )
    attempt_path = evidence_root / str(qualification["attempt_path"])
    receipt_path = evidence_root / str(qualification["receipt_path"])
    attempt_raw = attempt_path.read_bytes()
    receipt_raw = receipt_path.read_bytes()
    _identity(attempt_raw, qualification, "attempt")
    _identity(receipt_raw, qualification, "receipt")
    attempt = json.loads(attempt_raw)
    receipt = json.loads(receipt_raw)
    _canonical_identity(attempt, qualification, "attempt")
    _canonical_identity(receipt, qualification, "receipt")
    controls.require_fields(
        attempt,
        {
            "schema_version": qualification["attempt_schema"],
            "gate_id": closure["gate_id"],
            "mode": "qualification",
            "started_utc": qualification["started_utc"],
            "source_commit": freeze,
            "upstream_commit": freeze,
            "live_remote_commit": freeze,
            "worktree_clean_at_start": True,
            "prospective_physical_question_declared": True,
        },
        "ATTEMPT",
    )
    _require_zero_authority(attempt, "ATTEMPT_ZERO")
    controls.require_fields(
        receipt,
        {
            "schema_version": qualification["receipt_schema"],
            "gate_id": closure["gate_id"],
            "mode": "qualification",
            "completed_utc": qualification["completed_utc"],
            "ok": True,
            "source_commit": freeze,
            "upstream_commit": freeze,
            "live_remote_commit": freeze,
            "contract_path": closure["source"]["contract"]["path"],
            "contract_raw_sha256": _qualification_contract_raw_sha256(closure),
            "operation_lock_released": True,
            "declared_question_class": "development",
            "prospective_physical_question_declared": True,
            "held_out_cell_access_count": 0,
            "held_out_selector_invocation_count": 0,
            "controller_physical_viability_proven": False,
        },
        "RECEIPT",
    )
    _require_zero_authority(receipt, "RECEIPT_ZERO")
    controls.require(receipt["toolchain"] == qualification["toolchain"], "TOOLCHAIN")
    controls.require(
        len(receipt["checks"]) == qualification["check_count"]
        and all(receipt["checks"].values()),
        "QUALIFICATION_CHECKS",
    )
    manifest = receipt["source_manifest"]
    _canonical_identity(manifest, qualification, "source_manifest")
    verify_source_receipt_manifest(
        root,
        freeze,
        manifest,
        raw_representation=qualification["source_manifest_raw_representation"],
    )
    _validate_manifest_representation(
        root,
        freeze,
        manifest,
        qualification["source_manifest_representation_evidence"],
    )
    _validate_qualification_contract_representation(closure, manifest)
    preflight = receipt["production_preflight"]
    _canonical_identity(preflight, qualification, "production_preflight")
    controls.require_fields(
        preflight,
        {
            "gate_id": closure["gate_id"],
            "ok": True,
            "source_inventory_count": qualification["source_inventory_count"],
            "authored_source_path_count": qualification[
                "authored_source_path_count"
            ],
            "qualified_physical_path_count": qualification[
                "qualified_physical_path_count"
            ],
            "current_zero_world_worker_count": qualification[
                "current_zero_world_worker_count"
            ],
            "current_zero_world_positive_case_count": qualification[
                "current_zero_world_positive_case_count"
            ],
            "current_zero_world_forced_failure_case_count": qualification[
                "current_zero_world_forced_failure_case_count"
            ],
            "canonical_predecessor_receipt_equivalence_passed": True,
            "historical_closure_audits_executed_count": 0,
            "full_seeded_ghost_count": 0,
            "bespoke_physical_canary_count": 0,
        },
        "PREFLIGHT",
    )
    _require_zero_authority(preflight, "PREFLIGHT_ZERO")
    raw_binding_spec = contract["audit_configuration"].get(
        "raw_binding_control_spec"
    )
    if raw_binding_spec is not None:
        controls.require_fields(
            qualification,
            {
                "raw_binding_control_count": policy["raw_binding_control_count"],
                "raw_binding_positive_case_count": policy[
                    "raw_binding_positive_case_count"
                ],
                "raw_binding_forced_failure_case_count": policy[
                    "raw_binding_forced_failure_case_count"
                ],
            },
            "QUALIFICATION_RAW_BINDING",
        )
        raw_binding = preflight["production_raw_binding_control_receipt"]
        controls.require_fields(
            raw_binding,
            raw_binding_spec["expected"],
            "PREFLIGHT_RAW_BINDING",
        )
        controls.require_zero_authority(raw_binding)
    return receipt


def _validate_decision(
    closure: dict[str, Any],
    contract: dict[str, Any],
) -> None:
    population = contract["finite_development_population"]
    execution_profile_id = contract["audit_configuration"].get(
        "execution_profile_id", "finite_recovery_behavior_v1"
    )
    if execution_profile_id == "native_route_ghost_v1":
        authorization_flag = "physical_ghost_authorized"
        question_changed_flag = "finite_route_question_changed"
        result_flag = "valid_complete_route_result"
    elif execution_profile_id in (
        "finite_recovery_behavior_v1",
        "finite_behavior_development_v1",
    ):
        authorization_flag = "physical_behavior_attempt_authorized"
        question_changed_flag = "finite_behavior_question_changed"
        result_flag = "valid_complete_behavior_result"
    else:
        raise controls.ControlError(
            f"DECISION_EXECUTION_PROFILE:{execution_profile_id}"
        )
    decision = closure["decision"]
    controls.require_fields(
        decision,
        {
            "physical_execution_authorized": True,
            authorization_flag: True,
            "authorized_world_count": population["world_count"],
            "maximum_world_build_count": population["maximum_world_build_count"],
            "maximum_outer_solver_steps": population["maximum_total_outer_steps"],
            "physics_ticks_per_second": population["physics_ticks_per_second"],
            "outer_step_duration_s": population["outer_step_duration_s"],
            "seed": population["cell_seed"],
            "seed_label": population["seed_label"],
            "seed_sha256": population["seed_sha256"],
            "held_out": False,
            question_changed_flag: False,
            "physical_result_observed": False,
            "prone_to_standing_claimed": False,
            "sdk1_milestone_advanced": False,
        },
        "DECISION",
    )
    authorization = closure["physical_authorization"]
    controls.require_fields(
        authorization,
        {
            "schema_version": "sporespore_qsdk_physical_route_authorization_projection_v1",
            "gate_id": closure["gate_id"],
            "question_class": "development",
            "zero_world_qualification_passed": True,
            "source_freeze_commit": closure["source"]["source_freeze_commit"],
            "seed": population["cell_seed"],
            "seed_label": population["seed_label"],
            "seed_sha256": population["seed_sha256"],
            "held_out": False,
            "maximum_model_construction_attempt_count": population[
                "maximum_model_construction_attempt_count"
            ],
            "maximum_model_construction_count": population[
                "maximum_model_construction_count"
            ],
            "maximum_world_attempt_count": population[
                "maximum_world_attempt_count"
            ],
            "maximum_world_build_count": population["maximum_world_build_count"],
            "maximum_outer_solver_steps": population["maximum_total_outer_steps"],
            "physics_ticks_per_second": population["physics_ticks_per_second"],
            "outer_step_duration_s": population["outer_step_duration_s"],
            "behavior_evaluator_invocation_count": population[
                "behavior_evaluator_invocation_count"
            ],
            "same_identity_rerun_permitted": False,
            "recovery_success_required": False,
            "physical_execution_authorized": True,
            "prone_to_standing_claimed": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        "PHYSICAL_AUTHORIZATION",
    )
    claim_boundary = closure["claim_boundary"]
    controls.require_fields(
        claim_boundary,
        {
            "complete_zero_world_gate_passed": True,
            "physical_execution_authorized": True,
            "physical_attempted": False,
            result_flag: False,
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
    mechanics_keys = [
        key
        for key, value in claim_boundary.items()
        if key.endswith("_mechanics_qualified") and value is True
    ]
    controls.require(
        len(mechanics_keys) == 1,
        "CLAIM_BOUNDARY_QUALIFIED_MECHANICS",
    )


def _validate_publication_correction(
    root: Path,
    closure: dict[str, Any],
    closure_relative_path: str,
) -> None:
    correction = closure.get("publication_correction")
    if correction is None:
        return
    controls.require(isinstance(correction, dict), "PUBLICATION_CORRECTION_ROOT")
    prior_commit = str(correction["prior_publication_commit"])
    prior_raw = source_bytes(root, prior_commit, closure_relative_path)
    controls.require_fields(
        correction,
        {
            "revision": 2,
            "prior_closure_git_blob_oid": git(
                root, "rev-parse", f"{prior_commit}:{closure_relative_path}"
            ),
            "prior_closure_byte_length": len(prior_raw),
            "prior_closure_raw_sha256": (
                "sha256:" + hashlib.sha256(prior_raw).hexdigest()
            ),
            "qualification_evidence_changed": False,
            "qualified_physical_source_changed": False,
            "physical_attempt_started": False,
            "physical_result_changed": False,
            "threshold_or_interpretation_changed": False,
        },
        "PUBLICATION_CORRECTION",
    )
    refusal_path = root / str(correction["pre_attempt_refusal_path"])
    refusal = load(refusal_path)
    verify_exact_paths(
        refusal,
        {
            "gate_id": closure["gate_id"],
            "closure_status": (
                "retained_pre_attempt_authorization_content_refusal_zero_physical_attempts"
            ),
            "source.qualification_closure.publication_commit": prior_commit,
            "source.qualification_closure.byte_length": len(prior_raw),
            "source.qualification_closure.raw_sha256": (
                "sha256:" + hashlib.sha256(prior_raw).hexdigest()
            ),
            "invocation.operation_lock_acquired": False,
            "invocation.scientific_attempt_record_created": False,
            "invocation.godot_physical_process_started": False,
            "decision.physical_attempt_consumed": False,
            "decision.physical_result_observed": False,
            "claim_boundary.official_physical_attempted": False,
            "claim_boundary.release_authority": False,
        },
        "PUBLICATION_CORRECTION_REFUSAL",
    )


def validate_closure(
    root: Path,
    closure_relative_path: str,
    closure_schema: str,
    gate_id: str,
) -> dict[str, Any]:
    closure_path = root / closure_relative_path
    closure = load(closure_path)
    controls.require_fields(
        closure,
        {
            "schema_version": closure_schema,
            "gate_id": gate_id,
            "question_class": "development",
            "physical_question_declared": True,
            "finite_decision_declared": False,
            "superiority_question_declared": False,
            "equivalence_or_non_inferiority_question_declared": False,
            "population_inference_declared": False,
        },
        "CLOSURE",
    )
    verify_exact_paths(
        closure,
        {
            "ledger_scope.subsystem": "recovery",
            "ledger_scope.engine_scope": "godot_jolt",
            "ledger_scope.question_class": "development",
        },
        "CLOSURE_LEDGER",
    )
    freeze, contract = _validate_source(root, closure)
    controls.require(
        closure["closure_status"]
        == contract["audit_configuration"]["qualified_status"],
        "CLOSURE_STATUS",
    )
    _validate_bound_evidence(root, closure, contract)
    _validate_qualification_history(root, closure, contract, freeze)
    receipt = _validate_qualification(root, closure, freeze, contract)
    _validate_publication_correction(root, closure, closure_relative_path)
    _validate_decision(closure, contract)
    runtime = closure["runtime_identity_projection"]
    runtime_receipt = receipt["production_preflight"][
        "production_wrapper_runtime_identity_receipt"
    ]
    controls.require_fields(
        runtime,
        {
            "runtime_id": receipt["production_preflight"]["runtime_id"],
            "runtime_version": receipt["production_preflight"]["runtime_version"],
            "selected_console_path": runtime_receipt["selected_console_path"],
            "selected_console_sha256": runtime_receipt["selected_console_sha256"],
            "selected_console_byte_length": runtime_receipt[
                "selected_console_byte_length"
            ],
            "production_worker_parse_count": 1,
            "actuator_mode": receipt["production_preflight"]["actuator_mode"],
            "numeric_predicate_id": receipt["production_preflight"][
                "numeric_predicate_id"
            ],
        },
        "RUNTIME_IDENTITY",
    )
    controls.require((root / closure["closure_audit_path"]).is_file(), "AUDIT_PATH")
    return closure


def run_cli(
    root: Path,
    closure_relative_path: str,
    closure_schema: str,
    gate_id: str,
    pass_marker: str,
    failure_marker: str,
) -> int:
    try:
        closure = validate_closure(
            root, closure_relative_path, closure_schema, gate_id
        )
        print(
            pass_marker,
            json.dumps(
                {
                    "gate_id": gate_id,
                    "ok": True,
                    "source_freeze_commit": closure["source"][
                        "source_freeze_commit"
                    ],
                    "retained_file_count": closure["qualification"][
                        "retained_tree"
                    ]["file_count"],
                    "source_manifest_entry_count": closure["qualification"][
                        "source_manifest_entry_count"
                    ],
                    "physical_execution_authorized": closure["decision"][
                        "physical_execution_authorized"
                    ],
                    "model_construction_count": 0,
                    "world_build_count": 0,
                    "solver_step_count": 0,
                },
                sort_keys=True,
            ),
        )
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
        print(f"{failure_marker}:{error}", file=sys.stderr)
        return 1
