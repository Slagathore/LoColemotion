"""Compact audit of the consumed pre-attempt R24D58 ghost invocation."""

from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError, exact, git, load, matching_evidence_roots,
    require_ordered_markers, sha256, source_bytes, verify_boolean_partition,
    verify_exact_paths, verify_legacy_live_gate_paths, verify_retained_commit,
    verify_retained_file_tree, verify_retained_json, verify_source_binding,
)

CLOSURE = ROOT / "sdk/recovery/r24d58_godot_native_recovery_route_ghost_pre_attempt_invalid_closure_v1.json"
SOURCE = "720084d3e22fdf7907aa50fb1e27eba20beee2a2"
STATUS = "closed_consumed_invalid_pre_attempt_authorization_schema_projection"
TRUE = (
    "r58_zero_world_qualification_preserved", "physical_invocation_consumed",
    "authorization_file_loaded", "authorization_schema_projection_failed",
    "complete_retained_invocation_population_content_addressed",
)
FALSE = (
    "same_identity_rerun_permitted", "materialized_physical_attempt_exists",
    "operation_lock_acquired", "worker_process_started", "physical_trajectory_observed",
    "native_world_constructed", "native_runtime_observation_collected",
    "portable_command_applied", "controller_behavior_evaluated",
    "controller_physical_viability_proven", "exact_nominal_godot_prone_to_standing_observed",
    "prone_to_standing_claimed", "repeatability_rate_claimed", "population_claimed",
    "held_out_validation_claimed", "cross_engine_recovery_claimed",
    "cross_engine_equivalence_claimed", "sdk1_milestone_advanced",
    "physical_acceptance_authority", "release_authority",
)


def audit() -> None:
    closure = load(CLOSURE)
    verify_exact_paths(closure, {
        "schema_version": "sporespore_qsdk_r24d58_godot_native_recovery_route_ghost_pre_attempt_invalid_closure_v1",
        "gate_id": "QSDK-R24D58", "stage_id": "R24D58-GHOST",
        "closure_status": STATUS, "question_class": "development",
        "physical_question_declared": True, "behavior_success_required": False,
        "superiority_question_declared": False,
        "equivalence_or_non_inferiority_question_declared": False,
        "population_inference_declared": False,
    }, "CLOSURE")
    source = closure["source"]
    verify_retained_commit(ROOT, SOURCE, source["parent_commit"])
    exact((source["commit"], source["tree"], source["subject"]),
          (SOURCE, git(ROOT, "show", "-s", "--format=%T", SOURCE),
           "[recovery/godot] Close R58 zero-world qualification"), "SOURCE")
    for name in ("wrapper", "shared_supervisor", "authorization_closure", "successor_contract"):
        verify_source_binding(ROOT, SOURCE, source[name])

    physical = closure["physical_invocation"]
    evidence = Path(physical["evidence_root"])
    verify_retained_file_tree(evidence, physical["retained_tree"])
    invocation = verify_retained_json(
        evidence / physical["invocation_path"], physical["invocation_byte_length"],
        physical["invocation_raw_sha256"], physical["invocation_canonical_byte_length"],
        physical["invocation_canonical_sha256"],
    )
    exact(matching_evidence_roots(evidence.parent, "", "invocation.json",
                                  "QSDK-R24D58", SOURCE), [evidence], "INVOCATION_POPULATION")
    stderr = (evidence / physical["stderr_path"]).read_bytes()
    exact((len(stderr), sha256(stderr)),
          (physical["stderr_byte_length"], physical["stderr_raw_sha256"]), "STDERR")
    exact(physical["exact_invocation_count_for_source_and_seed"], 1, "INVOCATION_COUNT")

    verify_exact_paths(invocation, {
        "status": "invalid_or_incomplete_integration_invocation_before_attempt_materialization",
        "source_commit": SOURCE, "seed": 408048331, "held_out": False,
        "host_exit_code": 1,
        "authorization.path_resolved": True, "authorization.file_loaded": True,
        "authorization.failure_phase": "shared_supervisor_authorization_schema_projection",
        "authorization.failure_property": "qualification.official_zero_world_qualification_passed",
        "ordered_execution_boundary.authorization_read_preceded_operation_lock": True,
        "ordered_execution_boundary.authorization_read_preceded_attempt_id_allocation": True,
        "ordered_execution_boundary.authorization_read_preceded_evidence_attempt_root_creation": True,
        "ordered_execution_boundary.authorization_read_preceded_worker_process_start": True,
        "observed_counts.physical_invocation_count": 1,
        "observed_counts.materialized_attempt_count": 0,
        "observed_counts.operation_lock_acquisition_count": 0,
        "observed_counts.worker_process_start_count": 0,
        "observed_counts.model_construction_attempt_count": 0,
        "observed_counts.world_attempt_count": 0,
        "observed_counts.world_build_count": 0,
        "observed_counts.solver_step_count": 0,
        "observed_counts.native_runtime_observation_collection_count": 0,
        "observed_counts.portable_command_application_count": 0,
        "observed_counts.behavior_evaluator_invocation_count": 0,
        "claim_boundary.invocation_consumed": True,
        "claim_boundary.same_identity_rerun_permitted": False,
    }, "INVOCATION")
    exact(invocation["source"]["bindings"], [
        {"path": source[name]["path"], "byte_length": source[name]["byte_length"],
         "raw_sha256": source[name]["raw_sha256"]}
        for name in ("wrapper", "shared_supervisor", "authorization_closure", "successor_contract")
    ], "INVOCATION_BINDINGS")

    supervisor = source_bytes(ROOT, SOURCE, source["shared_supervisor"]["path"]).decode("utf-8")
    require_ordered_markers(supervisor, (
        "$authorization = Get-R57Authorization -Path $AuthorizationPath -Repository $repository",
        "$lock = Enter-SporeSporeLocomotionOperationLock -Role physical_development",
        "$attemptId = [guid]::NewGuid().ToString(\"N\")", "$attemptRoot = Join-Path $EvidenceRoot",
        "$process = Invoke-SporeSporeGodotReceiptTerminatedProcess",
    ), "SOURCE_ORDER")

    decision = closure["decision"]
    verify_exact_paths(decision, {
        "result": "invalid_or_incomplete_integration_invocation_before_attempt_materialization",
        "r58_zero_world_qualification_remains_positive": True,
        "physical_invocation_consumed": True, "same_identity_rerun_permitted": False,
        "new_behavior_threshold_count": 0, "new_empirical_threshold_count": 0,
        "new_margin_count": 0, "observed_physical_cohort_count": 0,
        "population_claim_count": 0, "physical_trajectory_observed": False,
    }, "DECISION")
    verify_boolean_partition(closure["claim_boundary"], TRUE, FALSE, "CLAIM")
    exact(closure["sdk_status"], {
        "sdk1_milestone_advanced": False, "sdk1_completed_steps": 11,
        "sdk1_total_steps": 20, "full_program_completed_steps": 11,
        "full_program_total_steps": 25,
    }, "SDK_STATUS")
    verify_exact_paths(closure["next_boundary"], {
        "gate_id": "QSDK-R24D59", "question_class": "development",
        "physical_question_declared": False, "complete_zero_world_gate_passed": False,
        "full_seeded_ghost_required": False, "additional_physical_canary_required": False,
        "authorized_world_count": 0, "maximum_physical_steps_authorized": 0,
        "r24d58_same_identity_rerun_permitted": False,
        "physical_execution_authorized": False,
    }, "NEXT")

    relative = CLOSURE.relative_to(ROOT).as_posix()
    publication = git(ROOT, "log", "-1", "--diff-filter=A", "--format=%H", "--", relative)
    assert isinstance(publication, str)
    revision = publication or None
    raw = CLOSURE.read_bytes() if revision is None else source_bytes(ROOT, revision, relative)
    live = {**closure["live_gate_expectations"],
            "r24d58_ghost_invalid_closure_raw_sha256": sha256(raw)}
    verify_legacy_live_gate_paths(ROOT, closure["live_authority_paths"],
                                  "QSDK-R24D45", live, revision=revision)
    print("QSDK_R24D58_GODOT_NATIVE_RECOVERY_ROUTE_GHOST_PRE_ATTEMPT_INVALID_"
          "CLOSURE_PASS invocations=1 attempts=0 locks=0 workers=0 models=0 "
          "worlds=0 steps=0 same_identity_rerun=0 next=R24D59 sdk1=11/20")


if __name__ == "__main__":
    try:
        audit()
    except (ClosureAuditError, OSError, KeyError, TypeError, ValueError,
            subprocess.SubprocessError) as error:
        print(f"QSDK_R24D58_GODOT_NATIVE_RECOVERY_ROUTE_GHOST_PRE_ATTEMPT_INVALID_CLOSURE_FAIL {error}",
              file=sys.stderr)
        raise SystemExit(1) from error
