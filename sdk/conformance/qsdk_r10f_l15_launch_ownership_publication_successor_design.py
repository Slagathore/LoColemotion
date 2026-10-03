"""Audit the prospective L15 contract, not the unimplemented repair.

This zero-world design gate reopens immutable inputs and the sealed historical
diagnosis. Contract mutations test scope enforcement only; they do not prove
that any future launch, collector, publication path or physics run succeeds.
"""

from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
EXPECTED_ROOT = Path(r"C:\Users\Cole\CodeStuff\games\SporeSpore")
PARENT = "595bf65361ff3283ff75a4ddde11258ea8cfc90d"
DESIGN = (
    ROOT / "sdk/qsdk_r10f_l15_launch_ownership_publication_successor_design_v1.json"
)
DESIGN_BYTES = 20711
DESIGN_SHA = "sha256:80c2c5bf331f3a632b58242866e1b0468b15c7c04f443b933ae90e28c5d1bd77"
MARKER = "QSDK_R10F_L15_LAUNCH_OWNERSHIP_PUBLICATION_SUCCESSOR_DESIGN_PASS "
DIAGNOSIS_MARKER = "QSDK_R10F_L15_RETAINED_DIAGNOSIS_AUDIT_PASS "
# Literal, versioned semantics independent of the candidate being validated.
SEMANTICS = json.loads(
    r"""{
  "schema_version": "sporespore_qsdk_r10f_l15_launch_ownership_publication_successor_design_v1",
  "gate_id": "QSDK-R10F",
  "repair_id": "QSDK-R10F-L15",
  "parent_repair_id": "QSDK-R10F-L14",
  "design_id": "QSDK-R10F-L15-SOURCE-BOUND-LAUNCH-CANONICAL-OWNER-AND-SINGLE-PUBLICATION",
  "authored_parent_commit": "595bf65361ff3283ff75a4ddde11258ea8cfc90d",
  "status": "prospective_zero_world_repair_design_implementation_authorized_after_audit_physics_blocked",
  "ledger_scope": {
    "subsystem": "recovery",
    "engine_scope": "godot_jolt",
    "authority_mode": "prospective_interface_and_failure_retention_repair_design",
    "question_class": "development"
  },
  "question_declaration": {
    "scientific_question_changed_from_r10f": false,
    "development_question_declared": true,
    "finite_decision_declared": false,
    "superiority_question_declared": false,
    "equivalence_or_non_inferiority_question_declared": false,
    "population_inference_declared": false,
    "physical_question_declared": false,
    "physical_execution_authorized": false,
    "maximum_world_attempt_count_before_complete_new_authority_graph": 0,
    "maximum_model_construction_count_before_complete_new_authority_graph": 0,
    "maximum_world_build_count_before_complete_new_authority_graph": 0,
    "maximum_solver_step_count_before_complete_new_authority_graph": 0
  },
  "selected_changes": {
    "launch_relationship": {
      "legacy_entrypoints_and_other_campaigns_keep_their_existing_contract": true,
      "receipt_schema": "sporespore_qsdk_r10f_launch_relationship_receipt_v1",
      "relationship_values": [
        "self",
        "descendant"
      ],
      "chain_direction": "worker_to_console",
      "maximum_ancestry_edge_count": 16,
      "retain_observed_process_chain_before_termination": true,
      "retain_root_worker_nonce_ready_receipt_and_runtime_source_bindings": true,
      "same_pid_requires_self_and_zero_edges": true,
      "different_pids_require_contiguous_noncyclic_chain_ending_at_console": true,
      "arbitrary_different_pid_acceptance_forbidden": true,
      "missing_unrelated_dead_or_unreadable_ancestry_is_invalid": true,
      "existing_exit_health_timeout_raw_marker_and_child_content_checks_preserved": true,
      "early_validator_powershell_pair_and_independent_closer_must_agree": true,
      "old_receipts_without_new_proof_are_not_upgraded": true,
      "cryptographic_or_os_security_attestation_claimed": false
    },
    "canonical_ownership": {
      "orchestration_to_canonical": [
        {
          "orchestration_owner": "none",
          "canonical_owner": "none",
          "recovery_controller_id": "must_be_null"
        },
        {
          "orchestration_owner": "recovery_v6",
          "canonical_owner": "recovery",
          "recovery_controller_id": "must_equal_existing_exact_v6_controller_id"
        }
      ],
      "unmapped_owner_or_wrong_controller_identity_refused": true,
      "versioned_mapping_receipt_binds_source_owner_memory_and_application": true,
      "initial_postkick_and_subsequent_passive_observation_calls_both_covered": true,
      "orchestrator_control_and_actuation_owner_labels_unchanged": true,
      "rust_owner_enum_and_collector_validation_unchanged": true,
      "legacy_no_actuation_entrypoint_semantics_preserved": true,
      "prospective_command_metadata_and_digests_may_change_only_for_declared_mapping": true,
      "motor_enable_target_speed_impulse_cap_and_physical_work_values_unchanged": true,
      "no_rehash_or_rewrite_of_historical_application_or_observation": true,
      "single_field_fix_not_claimed_to_validate_missing_complete_request": true
    },
    "publication": {
      "typed_return_object_count": 1,
      "primary_supervisor_report_count": 1,
      "primary_machine_readable_marker_count": 1,
      "invalid_report_exit_code": 1,
      "valid_complete_report_exit_code": 0,
      "primary_report_written_before_publication_and_cleanup": true,
      "no_primary_report_replacement_by_later_terminal_exception": true,
      "error_handling_retains_existing_primary_identity_and_error_separately": true,
      "early_invalid_and_full_pair_callers_use_same_typed_contract": true,
      "stdout_marker_never_becomes_second_return_value": true,
      "no_failure_or_incomplete_population_reclassified_as_behavior_negative": true
    },
    "exact_failed_collection_retention": {
      "original_serializer_and_numeric_number_kinds_preserved": true,
      "exact_serialized_request_and_response_text_required": true,
      "request_and_response_utf8_byte_lengths_and_sha256_required": true,
      "exact_compiled_collector_call_count": 1,
      "additional_collection_call_count": 0,
      "additional_controller_advance_count": 0,
      "additional_native_physics_read_count": 0,
      "additional_solver_step_count": 0,
      "source_application_memory_and_bound_observation_links_required": true,
      "retention_occurs_before_worker_cleanup_and_projection": true,
      "success_and_refusal_response_shapes_both_tested": true,
      "malformed_response_and_precollection_failure_have_distinct_stage_receipts": true,
      "precollection_failure_must_not_fabricate_a_compiled_response": true,
      "partial_trace_and_completed_global_counter_retention_preserved": true,
      "legacy_collection_entrypoint_semantics_preserved": true,
      "no_reconstruction_of_l14_missing_request": true,
      "missing_or_corrupt_failure_sources_cannot_qualify_route": true
    }
  },
  "preserved_contract": {
    "recovery_v6_bw5r_b_orchestrator_policy_and_event_rules_unchanged": true,
    "nine_body_eight_joint_s169_descriptor_materials_caps_impulse_solver_and_images_unchanged": true,
    "all_27_walking_gate_names_and_numerical_thresholds_unchanged": true,
    "existing_rotation_aware_energy_accounting_and_r69_host_projection_unchanged": true,
    "global_epoch_local_counter_relationship_and_native_number_kinds_unchanged": true,
    "current_l14_qualified_schedule_including_explicit_release_step_preserved": true,
    "current_maximum_per_child_solver_steps": 3842,
    "current_maximum_pair_solver_steps": 7684,
    "current_child_timeout_seconds": 3600,
    "schedule_horizon_seed_partition_and_timeout_not_changed_or_allocated_here": true,
    "process_isolated_baseline_then_active_order_preserved": true,
    "l14_base_design_and_no_resume_addendum_preserved": true,
    "all_consumed_sources_graphs_identities_and_results_immutable": true,
    "consumed_identity_retry_permitted": false,
    "held_out_seeds_remain_sealed": true,
    "r173_three_engine_prone_to_standing_preserved": true,
    "sdk1_m07_satisfied": false,
    "force_aware_recovery": false,
    "support_matrix_changed": false,
    "release_contract_changed": false,
    "sdk1_score": "14/20",
    "full_program_score": "14/25"
  },
  "authorization_boundary": {
    "implementation_authorized_after_this_design_audit_passes": true,
    "implementation_qualified_by_this_design": false,
    "physical_execution_authorized": false,
    "seed_or_cohort_allocated": false,
    "horizon_allocated": false,
    "attempt_identity_allocated": false,
    "retry_authorized": false,
    "held_out_access_authorized": false,
    "physical_acceptance_authority": false,
    "release_authority": false,
    "publication_authority": false,
    "development_route_success_requires_complete_valid_execution_not_behavioral_success": true,
    "incomplete_or_infrastructure_invalid_is_never_a_valid_route_ghost": true,
    "new_finite_or_support_claim_requires_its_own_prospective_evidence": true
  }
}"""
)
AUTHORITY_ROLES = [
    "consumed_l14_physical_closure",
    "closed_l15_retained_diagnosis",
    "sealed_retained_diagnosis_auditor",
    "sealed_frozen_statement_replay",
    "unchanged_l14_base_design",
    "unchanged_l14_no_resume_addendum",
    "unchanged_r10f_behavioral_contract",
    "consumed_l14_qualification_closure",
    "consumed_l14_execution_authority",
]
COVERAGE_IDS = [
    "retained_diagnosis",
    "live_launch_producer",
    "all_launch_consumers",
    "ownership_producer_to_compiled_collector",
    "physics_input_preservation",
    "full_supervisor_publication",
    "exact_refusal_bytes_through_actual_callers",
    "whole_worker_and_pair",
    "l14_and_earlier_regressions",
    "actual_qualification_and_authority_handoff",
    "serialized_zero_world_execution",
]
RETENTION_PATHS = [
    "sdk/adapters/godot/gdscript/recovery_native_route_v1.gd",
    "sdk/adapters/godot/gdscript/recovery_runtime.gd",
    "sdk/trace_analysis/godot_authoritative_json_transport.gd",
]


def require(condition: bool, code: str) -> None:
    if not condition:
        raise ValueError(code)


def same(left: object, right: object) -> bool:
    """Reject Boolean/integer and integer/float substitutions."""
    return json.dumps(left, sort_keys=True, allow_nan=False) == json.dumps(
        right, sort_keys=True, allow_nan=False
    )


def sha(raw: bytes) -> str:
    return "sha256:" + hashlib.sha256(raw).hexdigest()


def git(*args: str) -> bytes:
    return subprocess.check_output(["git", *args], cwd=ROOT)


def bound_bytes(path: Path, length: int, digest: str) -> bytes:
    raw = path.read_bytes()
    require(
        type(length) is int and len(raw) == length and sha(raw) == digest,
        "RAW_BINDING:" + str(path),
    )
    return raw


def subset(value: dict, expected: dict, prefix: str = "") -> None:
    require(type(value) is dict, "OBJECT:" + prefix)
    for key, item in expected.items():
        label = prefix + "." + key
        require(key in value, "MISSING:" + label)
        if type(item) is dict:
            subset(value[key], item, label)
        else:
            require(same(value[key], item), "SEMANTICS:" + label)


def validate_contract(candidate: dict, sealed: dict) -> None:
    """Validate scope, binding roles and coverage before any expensive replay."""
    subset(candidate, SEMANTICS)
    require(candidate.keys() == sealed.keys(), "TOP_LEVEL_FIELDS")
    require(
        same(candidate["bound_authorities"], sealed["bound_authorities"]),
        "AUTHORITY_BINDINGS",
    )
    require(
        [a["role"] for a in candidate["bound_authorities"]] == AUTHORITY_ROLES,
        "AUTHORITY_ROLES",
    )
    require(
        same(
            candidate["additional_frozen_retention_sources"],
            sealed["additional_frozen_retention_sources"],
        ),
        "RETENTION_BINDINGS",
    )
    require(
        [s["path"] for s in candidate["additional_frozen_retention_sources"]]
        == RETENTION_PATHS,
        "RETENTION_SOURCE_PATHS",
    )
    require(
        same(candidate["diagnosed_boundaries"], sealed["diagnosed_boundaries"]),
        "DIAGNOSIS_LIMITS",
    )
    coverage = candidate["required_zero_world_coverage"]
    require(
        type(coverage) is list
        and [c["id"] for c in coverage] == COVERAGE_IDS
        and same(coverage, sealed["required_zero_world_coverage"]),
        "COVERAGE",
    )
    # Prose is part of the sealed design too; extra aliases cannot add authority.
    require(same(candidate, sealed), "UNDECLARED_CONTRACT_CHANGE")


def reopen_inputs(sealed: dict) -> dict:
    for item in sealed["bound_authorities"]:
        path = ROOT / item["path"]
        require(path.resolve().is_relative_to(ROOT.resolve()), "AUTHORITY_PATH_ESCAPE")
        require(item["source_commit"] == PARENT, "AUTHORITY_PARENT")
        raw = bound_bytes(path, item["byte_length"], item["raw_sha256"])
        spec = item["source_commit"] + ":" + item["path"]
        require(
            git("rev-parse", spec).decode().strip() == item["git_blob"],
            "AUTHORITY_GIT_BLOB",
        )
        require(git("show", spec) == raw, "AUTHORITY_GIT_BYTES")
    # Production sources may change prospectively. Reopen their frozen Git
    # objects instead of requiring today's checkout to remain historical.
    for item in sealed["additional_frozen_retention_sources"]:
        require(item["source_commit"] == PARENT, "RETENTION_SOURCE_PARENT")
        spec = item["source_commit"] + ":" + item["path"]
        raw = git("show", spec)
        require(
            git("rev-parse", spec).decode().strip() == item["git_blob"],
            "RETENTION_SOURCE_GIT_BLOB",
        )
        require(
            len(raw) == item["byte_length"] and sha(raw) == item["raw_sha256"],
            "RETENTION_SOURCE_RAW_BYTES",
        )
    record = json.loads((ROOT / sealed["bound_authorities"][1]["path"]).read_bytes())
    observed = sealed["diagnosed_boundaries"]
    require(
        observed["complete_rejected_request_reconstructed"] is False
        and observed["changing_owner_alone_proves_complete_observation_valid"] is False,
        "MISSING_REQUEST_CLAIM",
    )
    require(len(record["frozen_sources"]) == 8, "DIAGNOSED_SOURCE_COUNT")
    return record


def leaf_mutations(value: object, prefix: tuple = ()) -> list:
    """Mutate each constrained scalar once; counts are design controls only."""
    mutations = []
    if type(value) is dict:
        for key, child in value.items():
            mutations.extend(leaf_mutations(child, prefix + (key,)))
    elif type(value) is list:
        for index, child in enumerate(value):
            mutations.extend(leaf_mutations(child, prefix + (index,)))
    else:
        replacement = (
            (not value)
            if type(value) is bool
            else (value + 1 if type(value) is int else "invalid-design-control")
        )
        mutations.append((prefix, replacement))
    return mutations


def audit() -> dict:
    started = time.monotonic()
    require(ROOT.resolve() == EXPECTED_ROOT.resolve(), "CANONICAL_ROOT")
    require(
        Path(git("rev-parse", "--show-toplevel").decode().strip()).resolve()
        == ROOT.resolve(),
        "GIT_ROOT",
    )
    require(
        git("remote", "get-url", "origin").decode().strip()
        == "https://github.com/Slagathore/sporespore.git",
        "ORIGIN",
    )
    sealed_raw = bound_bytes(DESIGN, DESIGN_BYTES, DESIGN_SHA)
    sealed = json.loads(sealed_raw)
    validate_contract(sealed, sealed)
    reopen_inputs(sealed)
    mutations = leaf_mutations(SEMANTICS)
    mutations.extend(
        [
            (
                (
                    "question_declaration",
                    "maximum_world_build_count_before_complete_new_authority_graph",
                ),
                False,
            ),
            (
                (
                    "selected_changes",
                    "launch_relationship",
                    "maximum_ancestry_edge_count",
                ),
                16.0,
            ),
            (
                (
                    "selected_changes",
                    "exact_failed_collection_retention",
                    "exact_compiled_collector_call_count",
                ),
                True,
            ),
            (("bound_authorities", 0, "raw_sha256"), "sha256:" + "0" * 64),
            (("bound_authorities", 1, "path"), "../untrusted.json"),
            (("bound_authorities", 2, "git_blob"), "0" * 40),
            (("bound_authorities", 3, "byte_length"), False),
            (("additional_frozen_retention_sources", 0, "source_commit"), "0" * 40),
            (
                ("additional_frozen_retention_sources", 1, "raw_sha256"),
                "sha256:" + "0" * 64,
            ),
            (("additional_frozen_retention_sources", 2, "git_blob"), "0" * 40),
            (("diagnosed_boundaries", "complete_rejected_request_reconstructed"), True),
            (
                (
                    "diagnosed_boundaries",
                    "changing_owner_alone_proves_complete_observation_valid",
                ),
                True,
            ),
            (("diagnosed_boundaries", "historical_result_remains"), "valid_complete"),
            (
                ("required_zero_world_coverage",),
                sealed["required_zero_world_coverage"][:-1],
            ),
            (
                ("required_zero_world_coverage", 3, "requirement"),
                "A stub-only test is enough.",
            ),
        ]
    )
    rejected = []
    for path, replacement in mutations:
        changed = copy.deepcopy(sealed)
        target = changed
        for key in path[:-1]:
            target = target[key]
        target[path[-1]] = replacement
        try:
            validate_contract(changed, sealed)
        except (ValueError, KeyError, TypeError):
            rejected.append(".".join(map(str, path)))
        else:
            raise ValueError("DESIGN_MUTATION_ACCEPTED:" + str(path))
    # The executable and its PowerShell companion were verified above, before
    # running the exact sealed historical diagnosis. It creates no physics.
    result = subprocess.run(
        [sys.executable, "-B", str(ROOT / sealed["bound_authorities"][2]["path"])],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=True,
        timeout=60,
    )
    require(result.stderr == "", "DIAGNOSIS_STDERR")
    lines = result.stdout.splitlines()
    require(
        len(lines) == 1 and lines[0].startswith(DIAGNOSIS_MARKER),
        "DIAGNOSIS_OUTPUT_SHAPE",
    )
    diagnosis = json.loads(lines[0][len(DIAGNOSIS_MARKER) :])
    subset(
        diagnosis,
        {
            "ok": True,
            "mutation_rejection_count": 39,
            "retained_file_count": 17,
            "retained_byte_length": 143907759,
            "frozen_source_count": 8,
            "complete_rejected_native_request_replayed": False,
            "physical_execution_authorized": False,
            **{
                k: 0
                for k in (
                    "model_construction_count",
                    "world_attempt_count",
                    "world_build_count",
                    "scene_tree_insertion_count",
                    "native_physics_read_count",
                    "solver_step_count",
                )
            },
        },
    )
    # Reopen sealed inputs after replay to fail closed on concurrent changes.
    require(DESIGN.read_bytes() == sealed_raw, "DESIGN_CHANGED_DURING_AUDIT")
    reopen_inputs(sealed)
    return {
        "schema_version": "sporespore_qsdk_r10f_l15_successor_design_audit_v1",
        "gate_id": "QSDK-R10F",
        "repair_id": "QSDK-R10F-L15",
        "ledger_scope": {
            **sealed["ledger_scope"],
            "authority_mode": "zero_world_prospective_design_audit",
        },
        "ok": True,
        "design_byte_length": DESIGN_BYTES,
        "design_raw_sha256": DESIGN_SHA,
        "valid_design_control_count": 1,
        "design_mutation_rejection_count": len(rejected),
        "retained_diagnosis_control_count": 39,
        "bound_authority_count": 9,
        "additional_frozen_retention_source_count": 3,
        "required_future_zero_world_coverage_group_count": len(COVERAGE_IDS),
        "implementation_authorized": True,
        "implementation_qualified": False,
        "production_successor_paths_executed": False,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
        "publication_authority": False,
        "old_result_reclassified": False,
        "same_identity_rerun_permitted": False,
        "sdk1_m07_satisfied": False,
        "sdk1_score": "14/20",
        "full_program_score": "14/25",
        **{
            k: 0
            for k in (
                "model_construction_count",
                "world_attempt_count",
                "world_build_count",
                "scene_tree_insertion_count",
                "native_physics_read_count",
                "solver_step_count",
            )
        },
        "elapsed_seconds": time.monotonic() - started,
    }


if __name__ == "__main__":
    try:
        print(MARKER + json.dumps(audit(), sort_keys=True, separators=(",", ":")))
    except (
        ValueError,
        KeyError,
        TypeError,
        OSError,
        subprocess.SubprocessError,
    ) as exc:
        print("QSDK_R10F_L15_SUCCESSOR_DESIGN_FAIL " + str(exc), file=sys.stderr)
        raise SystemExit(1)
