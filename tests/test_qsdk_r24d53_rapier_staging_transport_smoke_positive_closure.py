"""Compact closure audit for the passing QSDK-R24D53 transport smoke."""

from __future__ import annotations

from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError,
    exact,
    git,
    load,
    loads,
    require_ordered_markers,
    sha256,
    source_bytes,
    verify_boolean_partition,
    verify_exact_paths,
    verify_legacy_live_gate_paths,
    verify_rapier_staging_transport_v3,
    verify_retained_file_tree,
    verify_source_binding,
    verify_staged_physical_runner_closure,
)


CLOSURE = ROOT / (
    "sdk/recovery/"
    "r24d53_rapier_staging_transport_smoke_positive_closure_v1.json"
)
SOURCE = "e6bd27c0fc5f2c59e389a1df690436f03f2b4ecb"
PARENT = "7f25ee2937087b490d0d27ec5740a9342cdd7ec2"
QUALIFICATION_SOURCE = "f722b4f64a9df3c10164ad21bcf938a0644ea691"
GATE = "QSDK-R24D53"
STATUS = (
    "closed_valid_complete_live_native_staging_transport_and_portable_v3_"
    "mapping_positive_behavior_unassessed"
)
RUNTIME_BINDING = (
    "sha256:a25bd0f7294db3ce26dd10a008dfc56f5232e08373d3dec4a8fdc5821cc93c0e"
)


def audit() -> None:
    closure = load(CLOSURE)
    verify_exact_paths(closure, {
        "schema_version": (
            "sporespore_qsdk_r24d53_rapier_staging_transport_smoke_"
            "positive_closure_v1"
        ),
        "gate_id": GATE,
        "closure_status": STATUS,
        "ledger_scope": (
            "one_exact_r24d53_source_one_nominal_candidate_world_and_two_"
            "native_steps_only"
        ),
        "question_class": "development_integration_smoke",
        "physical_question_declared": True,
        "behavior_success_required": False,
        "superiority_question_declared": False,
        "equivalence_or_non_inferiority_question_declared": False,
        "population_inference_declared": False,
        "source.commit": SOURCE,
        "source.parent_commit": PARENT,
        "source.tree": "b5c5918c8dbbe740615ac373c978b280418fa768",
        "source.subject": "[recovery/rapier] Repair R53 physical lock role",
        "source.qualification_source_commit": QUALIFICATION_SOURCE,
        "qualification_dependency.runtime_binding_sha256": RUNTIME_BINDING,
        "qualification_dependency.complete_zero_world_gate_satisfied": True,
        "qualification_dependency.may_be_requalified": False,
    }, "CLOSURE")
    exact(git(ROOT, "show", "-s", "--format=%P", SOURCE), PARENT,
          "SOURCE_PARENT")
    exact(git(ROOT, "show", "-s", "--format=%T", SOURCE),
          closure["source"]["tree"], "SOURCE_TREE")
    exact(git(ROOT, "show", "-s", "--format=%s", SOURCE),
          closure["source"]["subject"], "SOURCE_SUBJECT")

    source = closure["source"]
    bound = {
        name: verify_source_binding(ROOT, SOURCE, source[name])
        for name in (
            "contract", "transport_module", "recovery_route",
            "physical_runner", "operation_lock", "operation_lock_test",
            "qualification_closure", "qualification_closure_audit",
        )
    }
    qualification = loads(bound["qualification_closure"])
    verify_exact_paths(qualification, {
        "gate_id": GATE,
        "closure_status": (
            "closed_complete_zero_world_native_staging_transport_binding_"
            "qualified_single_smoke_authorized"
        ),
        "source.commit": QUALIFICATION_SOURCE,
        "qualification.runtime_binding_sha256": RUNTIME_BINDING,
        "decision.native_transport_smoke_stage_authorized": True,
        "claim_boundary.official_zero_world_qualification_passed": True,
        "claim_boundary.prone_to_standing_claimed": False,
    }, "QUALIFICATION")

    refusal = closure["pre_attempt_launcher_refusal"]
    verify_exact_paths(refusal, {
        "source_commit": PARENT,
        "result": "parameter_binding_validation_refusal_before_operation_lock",
        "requested_operation_lock_role": "physical_development",
        "accepted_roles_before_repair": ["conformance", "physical"],
        "evidence_root_created": False,
        "operation_lock_acquired": False,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_attempt_consumed": False,
        "repair_source_commit": SOURCE,
        "qualified_runtime_path_changed": False,
        "physical_model_changed": False,
        "physical_question_changed": False,
    }, "PRE_ATTEMPT_REFUSAL")

    values = verify_staged_physical_runner_closure(
        root=ROOT,
        closure=closure,
        gate_id=GATE,
        source_commit=SOURCE,
        qualification_source_commit=QUALIFICATION_SOURCE,
        physical_directory_prefix=(
            "qsdk-r24d53-rapier-staging-transport-smoke-"
        ),
        mode="ghost",
        schemas={
            "attempt": (
                "sporespore_qsdk_r24d53_rapier_staging_transport_"
                "physical_attempt_v1"
            ),
            "result": (
                "sporespore_qsdk_r24d53_rapier_staging_transport_smoke_"
                "result_v1"
            ),
            "receipt": (
                "sporespore_qsdk_r24d53_rapier_staging_transport_"
                "physical_receipt_v1"
            ),
        },
        runtime_binding_field="runtime_binding_sha256",
    )
    attempt, result, receipt = (
        values["attempt"], values["result"], values["receipt"]
    )
    verify_exact_paths(attempt, {
        "branch": "main",
        "remote": "https://github.com/Slagathore/sporespore.git",
        "environment_sha256": closure["physical_attempt"]["environment_sha256"],
        "ghost_authority_path": None,
    }, "ATTEMPT")
    verify_exact_paths(receipt, {
        "candidate_outer_steps": 2,
        "matched_zero_outer_steps": 0,
        "ghost_result_shape": "single_arm_transport_v1",
        "ghost_authority_path": None,
    }, "RECEIPT")
    projection = verify_rapier_staging_transport_v3(
        result, "R53_TRANSPORT", gate_id=GATE, expected_steps=2
    )
    observed = closure["observed_transport"]
    verify_exact_paths(observed, {
        "result": "valid_complete_live_native_staging_transport_positive",
        "route_id": result["route_id"],
        "mapping_profile_id": result["mapping_profile_id"],
        "native_staging_record_count": 2,
        "native_small_step_record_count": 32,
        "in_run_invariant_receipt_count": 2,
        "all_native_staging_samples_source_measured": True,
        "all_native_energy_components_finite": True,
        "all_native_staging_topology_exact": True,
        "all_native_to_portable_mappings_exact": True,
        "all_in_run_physical_invariants_passed": True,
        "v3_threshold_applied": False,
        "behavior_evaluator_executed": False,
        "behavior_success_observed": False,
        "prone_to_standing_observed": False,
    }, "OBSERVED_TRANSPORT")
    exact(projection, {
        key: observed[key] for key in projection
    }, "OBSERVED_TRANSPORT_PROJECTION")

    physical = closure["physical_attempt"]
    exact(
        (
            result["model_construction_count"],
            result["world_attempt_count"], result["world_build_count"],
            result["solver_step_count"], result["actual_total_outer_steps"],
        ),
        (
            physical["model_construction_count"],
            physical["world_attempt_count"], physical["world_build_count"],
            physical["solver_step_count"], physical["actual_total_outer_steps"],
        ),
        "PHYSICAL_COUNTS",
    )
    evidence_root = Path(physical["evidence_root"])
    exact(sorted(
        path.relative_to(evidence_root).as_posix()
        for path in evidence_root.rglob("*") if path.is_file()
    ), [
        "01-worker.log",
        "isolated-harness/Cargo.lock",
        "isolated-harness/Cargo.toml",
        "isolated-harness/src/main.rs",
        "physical_attempt.json",
        "physical_receipt.json",
        "physical_result.json",
    ], "RETAINED_PATHS")
    log_claim = physical["worker_log"]
    log_raw = (evidence_root / log_claim["path"]).read_bytes()
    exact((len(log_raw), sha256(log_raw)),
          (log_claim["byte_length"], log_claim["raw_sha256"]), "WORKER_LOG")
    require_ordered_markers(log_raw.decode("utf-8"), (
        "Finished `dev` profile",
        "Running `",
        "QSDK_R24D53_RAPIER_STAGING_TRANSPORT_SMOKE {",
    ), "WORKER_PASS_ORDER")

    verify_boolean_partition(closure["decision"], (
        "physical_attempt_consumed_for_exact_source", "physical_attempt_valid",
        "physical_attempt_complete", "physical_attempt_passed",
        "qualified_runtime_binding_consumed_exactly",
        "pre_attempt_launcher_refusal_preserved",
        "launch_role_alias_repair_qualified", "one_world_two_step_budget_exact",
        "live_native_staging_transport_observed", "portable_v3_mapping_observed",
        "all_native_staging_samples_source_measured",
        "all_native_energy_components_finite", "all_native_staging_topology_exact",
        "all_in_run_physical_invariants_passed",
        "all_retained_evidence_content_addressed", "operation_lock_released",
        "r24d53_closed_positive",
    ), (
        "pre_attempt_launcher_refusal_consumed_physics",
        "behavior_success_required", "behavior_success_observed",
        "behavior_evaluator_executed", "v3_threshold_applied",
        "retained_r49_residual_recomputed", "retained_r49_result_reclassified",
        "controller_changed", "threshold_changed", "margin_changed",
        "selector_changed", "evaluator_changed", "morphology_changed",
        "initializer_changed", "r24d53_exact_source_rerun_permitted",
        "prone_to_standing_claimed", "physical_acceptance_authority",
        "release_authority",
    ), "DECISION")
    exact(closure["decision"]["result"],
          "positive_complete_live_native_staging_transport_and_portable_v3_"
          "mapping_observed", "DECISION_RESULT")
    verify_boolean_partition(closure["claim_boundary"], (
        "official_zero_world_qualification_passed",
        "native_staging_transport_physical_attempt_retained",
        "native_staging_transport_physical_attempt_consumed",
        "native_staging_transport_observed", "portable_v3_mapping_observed",
        "all_native_staging_samples_source_measured",
        "all_native_staging_topology_exact",
        "all_in_run_physical_invariants_passed",
        "pre_attempt_launcher_refusal_preserved", "r24d53_closed_positive",
        "held_out_cells_remain_sealed",
    ), (
        "behavior_success_claimed", "v3_energy_threshold_claimed",
        "retained_r49_residual_recomputed", "retained_r49_result_reclassified",
        "controller_physical_viability_proven", "prone_to_standing_claimed",
        "repeatability_rate_claimed", "population_claimed",
        "held_out_validation_claimed", "cross_engine_recovery_claimed",
        "cross_engine_equivalence_claimed", "sdk1_milestone_advanced",
        "physical_acceptance_authority", "release_authority",
    ), "CLAIM")
    exact(closure["sdk_status"], {
        "sdk1_milestone_advanced": False, "sdk1_completed_steps": 11,
        "sdk1_total_steps": 20, "full_program_completed_steps": 11,
        "full_program_total_steps": 25,
    }, "SDK_STATUS")
    verify_exact_paths(closure["audit_economy"], {
        "common_staged_physical_runner_closure_helper_reused": True,
        "common_rapier_recovery_energy_v2_arm_helper_reused": True,
        "common_rapier_staging_transport_v3_helper_added_for_reuse": True,
        "historical_closure_audit_execution_count": 0,
        "physical_reexecution_count": 0,
        "new_campaign_specific_physical_canary_count": 0,
    }, "AUDIT_ECONOMY")
    verify_exact_paths(closure["next_boundary"], {
        "gate_id": "QSDK-R24D54", "question_class": "not_yet_declared",
        "status": (
            "distinct_v3_accounted_rapier_recovery_behavior_declaration_required"
        ),
        "physical_question_declared": False,
        "behavior_question_declared": False,
        "distinct_clean_pushed_source_freeze_required": True,
        "complete_zero_world_gate_required": True,
        "maximum_total_outer_steps_authorized": 0,
        "maximum_model_construction_count": 0,
        "maximum_world_attempt_count": 0,
        "maximum_world_build_count": 0,
        "physical_execution_authorized": False,
        "full_seeded_ghost_required": False,
        "additional_physical_canary_required": False,
        "r24d53_may_be_rerun": False,
        "r24d49_may_be_rerun_or_rethresholded": False,
        "held_out_cells_remain_sealed": True,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }, "NEXT")

    rejected = 0
    tree = physical["retained_tree"]
    for mutation in (
        {**tree, "file_count": tree["file_count"] + 1},
        {**tree, "manifest_canonical_sha256": "sha256:" + "0" * 64},
    ):
        try:
            verify_retained_file_tree(evidence_root, mutation)
        except ClosureAuditError:
            rejected += 1
    exact(rejected, 2, "TREE_MUTATION_REJECTIONS")

    relative = CLOSURE.relative_to(ROOT).as_posix()
    publication = git(
        ROOT, "log", "-1", "--diff-filter=A", "--format=%H", "--", relative
    )
    assert isinstance(publication, str)
    revision = publication or None
    raw = CLOSURE.read_bytes() if revision is None else source_bytes(
        ROOT, revision, relative
    )
    live = {
        **closure["live_gate_expectations"],
        "r24d53_physical_closure_raw_sha256": sha256(raw),
    }
    verify_legacy_live_gate_paths(
        ROOT, closure["live_authority_paths"], "QSDK-R24D45", live,
        revision=revision,
    )
    print(
        "QSDK_R24D53_RAPIER_STAGING_TRANSPORT_SMOKE_POSITIVE_CLOSURE_PASS "
        "files=7 models=1 worlds=1 solver_steps=2 outer_steps=2 "
        "native_records=2 small_steps=32 invariants=2 behavior=false "
        "sdk1=11/20 next=QSDK-R24D54"
    )


if __name__ == "__main__":
    try:
        audit()
    except (
        ClosureAuditError, OSError, KeyError, IndexError, TypeError, ValueError,
        subprocess.SubprocessError,
    ) as error:
        print(
            "QSDK_R24D53_RAPIER_STAGING_TRANSPORT_SMOKE_POSITIVE_CLOSURE_FAIL "
            f"{error}", file=sys.stderr,
        )
        raise SystemExit(1) from error
