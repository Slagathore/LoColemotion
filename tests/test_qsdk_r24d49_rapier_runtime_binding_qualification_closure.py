"""Compact audit of the retained QSDK-R24D49 zero-world qualification."""

from __future__ import annotations

from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError,
    canonical_bytes,
    exact,
    git,
    load,
    require,
    require_ordered_markers,
    sha256,
    source_bytes,
    verify_boolean_partition,
    verify_declared_zero_world_qualification_authority,
    verify_exact_paths,
    verify_legacy_live_gate_paths,
    verify_retained_file_tree,
)


CLOSURE_PATH = ROOT / (
    "sdk/recovery/r24d49_rapier_runtime_binding_qualification_closure_v1.json"
)
SOURCE = "a6b9f77577e36236685db8b20badd0ddc39b5017"
GATE = "QSDK-R24D49"
STATUS = "closed_complete_zero_world_rapier_runtime_binding_v1_qualified_physics_staged"
CHECKS = (
    "fresh_registry_archive_patched_and_bound",
    "source_contract_audit_passed",
    "stock_adapter_check_passed",
    "isolated_patched_rapier_and_adapter_check_passed",
    "expected_compile_refusal_parallel",
    "expected_compile_refusal_simd_stable",
    "contract_declared_preflight_expectations_passed",
    "production_preflight_passed",
    "source_manifest_bound",
    "worktree_unchanged",
    "source_commit_unchanged",
    "live_remote_unchanged",
)
DECISION_TRUE = (
    "official_zero_world_qualification_passed",
    "producer_owned_runtime_binding_qualified",
    "runtime_binding_projection_non_self_referential_qualified",
    "launcher_transport_only_qualified",
    "worker_projection_recomputation_compiled",
    "r48_behavior_semantics_preserved",
    "all_declared_runtime_binding_mutations_rejected",
    "parallel_compile_refusal_qualified",
    "simd_compile_refusal_qualified",
    "source_population_content_addressed",
    "retained_evidence_tree_content_addressed",
    "qualification_harness_cargo_lock_content_addressed",
    "integration_ghost_stage_authorized",
)
DECISION_FALSE = (
    "live_v2_recovery_route_physically_exercised",
    "integration_ghost_passed",
    "paired_development_authorized",
    "controller_behavior_evaluated",
    "controller_changed",
    "threshold_changed",
    "selector_changed",
    "evaluator_changed",
    "morphology_changed",
    "initializer_changed",
    "physical_acceptance_authority",
    "release_authority",
)
NEXT_TRUE = (
    "physical_question_declared",
    "complete_zero_world_gate_satisfied",
    "distinct_clean_pushed_source_freeze_required",
    "same_qualification_dependency_toolchain_and_environment_required",
    "physical_execution_authorized",
    "paired_development_blocked_until_valid_ghost",
    "held_out_cells_remain_sealed",
)
NEXT_FALSE = (
    "behavior_success_required",
    "full_seeded_ghost_required",
    "additional_physical_canary_required",
    "r24d49_may_be_requalified",
    "r24d48_may_be_rerun_or_requalified",
    "prone_to_standing_claimed",
    "physical_acceptance_authority",
    "release_authority",
)
CLAIM_TRUE = (
    "official_zero_world_qualification_passed",
    "runtime_binding_qualified",
    "producer_owned_runtime_binding_qualified",
    "runtime_binding_projection_non_self_referential_qualified",
    "launcher_transport_only_qualified",
    "all_four_declared_runtime_binding_mutations_rejected",
    "parallel_and_simd_refusals_qualified",
    "r48_behavior_semantics_preserved",
    "source_population_content_addressed",
    "retained_evidence_tree_content_addressed",
    "qualification_harness_cargo_lock_content_addressed",
    "integration_ghost_stage_authorized",
    "held_out_cells_remain_sealed",
)
CLAIM_FALSE = (
    "live_v2_recovery_route_physically_exercised_by_r49",
    "integration_ghost_passed",
    "paired_development_attempt_consumed",
    "controller_behavior_evaluated",
    "prone_to_standing_claimed",
    "repeatability_rate_claimed",
    "population_claimed",
    "held_out_validation_claimed",
    "cross_engine_recovery_claimed",
    "cross_engine_equivalence_claimed",
    "sdk1_milestone_advanced",
    "physical_acceptance_authority",
    "release_authority",
)


def audit() -> None:
    closure, contract, receipt, preflight = (
        verify_declared_zero_world_qualification_authority(
            root=ROOT,
            closure_path=CLOSURE_PATH,
            schema_version=(
                "sporespore_qsdk_r24d49_rapier_runtime_binding_"
                "qualification_closure_v1"
            ),
            gate_id=GATE,
            closure_status=STATUS,
            source_commit=SOURCE,
            source_subject="[recovery/rapier] Stabilize R49 source audit",
            source_binding_names=(
                "runtime_binding_route",
                "behavior_route",
                "entrypoint",
                "common_conformance_helper",
                "shared_zero_world_runner",
                "shared_physical_runner",
                "physical_wrapper",
                "source_audit",
            ),
            predecessor_status=(
                "closed_invalid_pre_world_runtime_qualification_digest_"
                "representation_mismatch_no_physics"
            ),
            attempt_schema=(
                "sporespore_qsdk_r24d49_rapier_runtime_binding_"
                "zero_world_attempt_v1"
            ),
            receipt_schema=(
                "sporespore_qsdk_r24d49_rapier_runtime_binding_"
                "zero_world_receipt_v1"
            ),
            qualification_directory_prefix=(
                "qsdk-r24d49-rapier-runtime-binding-qualification-"
            ),
            expected_checks=CHECKS,
            checkout_only_metadata=(),
            retained_log_markers={
                "01-source-audit.log": (
                    "QSDK_R24D49_RAPIER_RUNTIME_BINDING_SOURCE_PASS"
                ),
                "03-refusal-parallel.log": (
                    "qualified only for the sequential scalar solver"
                ),
                "03-refusal-simd-stable.log": (
                    "qualified only for scalar rigid impulse-joint constraints"
                ),
                "04-production-preflight.log": (
                    "QSDK_R24D49_RAPIER_RUNTIME_BINDING_ZERO_WORLD "
                ),
            },
            physical_question_declared=True,
        )
    )
    verify_exact_paths(contract, {
        "gate_id": GATE,
        "question_class": "development",
        "runtime_binding.projection_schema": (
            "sporespore_qsdk_r24d49_runtime_binding_projection_v1"
        ),
        "runtime_binding.projection_field_count": 12,
        "runtime_binding.mutation_rejection_count": 4,
        "runtime_binding.launcher_recomputation_permitted": False,
        "complete_zero_world_gate.maximum_physical_steps_authorized": 0,
        "staged_physical_execution.integration_ghost.maximum_total_outer_steps": 4,
        "staged_physical_execution.paired_development.maximum_total_outer_steps": 2400,
        "physical_runner.runtime_binding_result_field": "runtime_binding_sha256",
    }, "CONTRACT")
    exact(len(contract["source_inventory"]), 23, "CONTRACT_SOURCE_COUNT")
    exact(len(contract["qualification_runner"]["preflight_expectations"]), 19,
          "CONTRACT_PREFLIGHT_EXPECTATION_COUNT")

    dependency = load(
        ROOT / contract["qualification_runner"]["pinned_dependency_contract_path"]
    )["pinned_dependency"]
    exact(receipt["registry_archive"], {
        "path": receipt["registry_archive"]["path"],
        "raw_sha256": "sha256:" + dependency["cargo_registry_checksum"],
        "byte_length": dependency["registry_archive_byte_length"],
    }, "REGISTRY_ARCHIVE")
    exact(receipt["patch_raw_sha256"], dependency["patch_raw_sha256"], "PATCH")
    exact(receipt["patched_dependency_files"], [
        {
            "path": item["path"],
            "raw_sha256": item["patched_raw_sha256"],
            "byte_length": item["patched_byte_length"],
        }
        for item in dependency["upstream_and_patched_files"]
    ], "PATCHED_FILES")

    binding = closure["qualification"]["runtime_binding_sha256"]
    projection = preflight["runtime_binding_projection"]
    exact(set(projection), {
        "schema_version", "gate_id", "predecessor_gate_id",
        "predecessor_zero_world_sha256",
        "predecessor_invalid_closure_raw_sha256", "contract_raw_sha256",
        "route_id", "mapping_profile_id", "energy_rule_id",
        "digest_algorithm", "serialization_authority", "behavior_lineage_gate_id",
    }, "PROJECTION_FIELDS")
    projection_bytes = canonical_bytes(projection)
    exact(len(projection_bytes),
          closure["qualification"]["runtime_binding_projection_canonical_byte_length"],
          "PROJECTION_LENGTH")
    exact(sha256(projection_bytes), binding, "PROJECTION_DIGEST")
    exact(preflight["runtime_binding_sha256"], binding, "PREFLIGHT_BINDING")
    exact(projection["contract_raw_sha256"], receipt["contract_raw_sha256"],
          "PROJECTION_CONTRACT")
    exact(projection["predecessor_invalid_closure_raw_sha256"],
          closure["predecessor"]["closure_raw_sha256"], "PROJECTION_PREDECESSOR")
    exact([item["mutation_id"] for item in
           preflight["runtime_binding_mutation_results"]],
          contract["runtime_binding"]["mutation_ids"], "MUTATION_IDS")
    require(all(item["rejected"] is True for item in
                preflight["runtime_binding_mutation_results"]), "MUTATION_RESULTS")
    exact(receipt["isolated_harness_cargo_lock"],
          closure["qualification"]["isolated_harness_cargo_lock"], "CARGO_LOCK")

    route = source_bytes(
        ROOT, SOURCE, closure["source"]["runtime_binding_route"]["path"]
    ).decode("utf-8")
    ghost = route[route.index(
        "pub fn run_qsdk_r24d49_rapier_recovery_energy_v2_ghost("
    ):]
    require_ordered_markers(ghost, (
        "validate_runtime_binding_sha256(runtime_binding_sha256)?;",
        "run_qsdk_r24d48_rapier_recovery_energy_v2_ghost_after_runtime_binding_v1(",
    ), "PRE_WORLD_VALIDATION_ORDER")
    shared = source_bytes(
        ROOT, SOURCE, closure["source"]["shared_physical_runner"]["path"]
    ).decode("utf-8")
    require_ordered_markers(shared, (
        "runtime_binding_closure_json_pointer",
        "$runtimeBindingField",
        "$ghostEntrypoint",
        "sporespore_rapier_adapter::$ghostEntrypoint(",
        "[string]$result[$runtimeBindingField]",
    ), "LAUNCHER_TRANSPORT_ORDER")

    decision = closure["decision"]
    verify_exact_paths(decision, {
        "result": "positive_producer_owned_runtime_binding_qualified_zero_world",
        "runtime_binding_sha256": binding,
        "runtime_binding_projection_field_count": 12,
        "runtime_binding_mutation_rejection_count": 4,
        "maximum_physical_steps_authorized": 4,
    }, "DECISION")
    verify_boolean_partition(decision, DECISION_TRUE, DECISION_FALSE, "DECISION")
    verify_boolean_partition(closure["next_boundary"], NEXT_TRUE, NEXT_FALSE,
                             "NEXT")
    verify_boolean_partition(closure["claim_boundary"], CLAIM_TRUE, CLAIM_FALSE,
                             "CLAIM")
    exact(closure["sdk_status"], {
        "sdk1_milestone_advanced": False, "sdk1_completed_steps": 11,
        "sdk1_total_steps": 20, "full_program_completed_steps": 11,
        "full_program_total_steps": 25,
    }, "SDK_STATUS")

    evidence_root = Path(closure["qualification"]["evidence_root"])
    tree = closure["qualification"]["retained_tree"]
    rejected = 0
    for mutation in (
        {**tree, "file_count": tree["file_count"] + 1},
        {**tree, "manifest_canonical_sha256": "sha256:" + "0" * 64},
    ):
        try:
            verify_retained_file_tree(evidence_root, mutation)
        except ClosureAuditError:
            rejected += 1
    exact(rejected, 2, "TREE_MUTATION_REJECTIONS")

    relative = CLOSURE_PATH.relative_to(ROOT).as_posix()
    publication = git(ROOT, "log", "-1", "--diff-filter=A", "--format=%H",
                      "--", relative)
    assert isinstance(publication, str)
    revision = publication or None
    closure_raw = (CLOSURE_PATH.read_bytes() if revision is None else
                   source_bytes(ROOT, revision, relative))
    live = {
        **closure["live_gate_expectations"],
        "r24d49_closure_raw_sha256": sha256(closure_raw),
    }
    verify_legacy_live_gate_paths(
        ROOT, closure["live_authority_paths"], "QSDK-R24D45", live,
        revision=revision,
    )
    print(
        "QSDK_R24D49_RAPIER_RUNTIME_BINDING_QUALIFICATION_CLOSURE_PASS "
        "sources=23 checks=12/12 preflight=19/19 mutations=4+2 refusals=2 "
        "tree_files=148 models=0 worlds=0 solver_steps=0 stage_a_steps=4 "
        "behavior=false sdk1=11/20"
    )


if __name__ == "__main__":
    try:
        audit()
    except (ClosureAuditError, OSError, KeyError, TypeError, ValueError,
            subprocess.SubprocessError) as error:
        print(
            "QSDK_R24D49_RAPIER_RUNTIME_BINDING_QUALIFICATION_CLOSURE_FAIL "
            f"{error}", file=sys.stderr,
        )
        raise SystemExit(1) from error
