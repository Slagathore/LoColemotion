"""Compact closure audit for the passing QSDK-R24D49 integration ghost."""

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
    exact_bools,
    git,
    load,
    loads,
    require,
    require_ordered_markers,
    sha256,
    source_bytes,
    verify_exact_paths,
    verify_legacy_live_gate_paths,
    verify_rapier_recovery_energy_v2_arm,
    verify_retained_file_tree,
    verify_source_binding,
    verify_staged_physical_runner_closure,
)


CLOSURE_PATH = ROOT / (
    "sdk/recovery/"
    "r24d49_rapier_recovery_energy_v2_ghost_positive_closure_v1.json"
)
SOURCE = "686cf0ab5ff41c20504118e202b2329b264830f2"
QUALIFICATION_SOURCE = "a6b9f77577e36236685db8b20badd0ddc39b5017"
GATE = "QSDK-R24D49"
STATUS = (
    "closed_valid_complete_integration_ghost_live_chain_"
    "exercised_stage_b_authorized"
)
RUNTIME_BINDING = (
    "sha256:946d9f1dda22658c989b59daf7f75b32d82586009288baca0207b8ca8c01ea28"
)


def audit() -> None:
    closure = load(CLOSURE_PATH)
    verify_exact_paths(closure, {
        "schema_version": (
            "sporespore_qsdk_r24d49_rapier_recovery_energy_v2_"
            "ghost_positive_closure_v1"
        ),
        "gate_id": GATE,
        "stage_id": "R24D49-A",
        "closure_status": STATUS,
        "question_class": "development_integration_ghost",
        "physical_question_declared": True,
        "behavior_success_required": False,
        "superiority_question_declared": False,
        "equivalence_or_non_inferiority_question_declared": False,
        "population_inference_declared": False,
        "source.commit": SOURCE,
        "source.parent_commit": QUALIFICATION_SOURCE,
        "source.tree": "ff03879fdaf5b66f7dd8bd13967bc364caf7e614",
        "source.subject": "[recovery/rapier] Close R49 zero-world qualification",
        "source.qualification_source_commit": QUALIFICATION_SOURCE,
        "qualification_dependency.runtime_binding_sha256": RUNTIME_BINDING,
        "qualification_dependency.complete_zero_world_gate_satisfied": True,
        "qualification_dependency.may_be_requalified": False,
    }, "CLOSURE")
    exact(git(ROOT, "show", "-s", "--format=%P", SOURCE),
          QUALIFICATION_SOURCE, "SOURCE_PARENT")
    exact(git(ROOT, "show", "-s", "--format=%T", SOURCE),
          closure["source"]["tree"], "SOURCE_TREE")
    exact(git(ROOT, "show", "-s", "--format=%s", SOURCE),
          closure["source"]["subject"], "SOURCE_SUBJECT")

    source = closure["source"]
    bound = {
        name: verify_source_binding(ROOT, SOURCE, source[name])
        for name in (
            "contract", "runtime_binding_route", "behavior_route",
            "shared_physical_runner", "physical_wrapper",
            "qualification_closure", "qualification_closure_audit",
        )
    }
    qualification = loads(bound["qualification_closure"])
    verify_exact_paths(qualification, {
        "gate_id": GATE,
        "closure_status": (
            "closed_complete_zero_world_rapier_runtime_binding_v1_"
            "qualified_physics_staged"
        ),
        "source.commit": QUALIFICATION_SOURCE,
        "qualification.runtime_binding_sha256": RUNTIME_BINDING,
        "qualification.isolated_harness_cargo_lock.raw_sha256": (
            closure["qualification_dependency"][
                "qualification_harness_cargo_lock_sha256"
            ]
        ),
        "decision.official_zero_world_qualification_passed": True,
        "decision.integration_ghost_stage_authorized": True,
        "claim_boundary.prone_to_standing_claimed": False,
    }, "QUALIFICATION")

    values = verify_staged_physical_runner_closure(
        root=ROOT,
        closure=closure,
        gate_id=GATE,
        source_commit=SOURCE,
        qualification_source_commit=QUALIFICATION_SOURCE,
        physical_directory_prefix=(
            "qsdk-r24d49-rapier-recovery-energy-v2-ghost-"
        ),
        mode="ghost",
        schemas={
            "attempt": (
                "sporespore_qsdk_r24d49_rapier_recovery_energy_v2_"
                "physical_attempt_v1"
            ),
            "result": (
                "sporespore_qsdk_r24d49_rapier_recovery_energy_v2_ghost_v1"
            ),
            "receipt": (
                "sporespore_qsdk_r24d49_rapier_recovery_energy_v2_"
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
    exact(receipt["candidate_outer_steps"], 2, "RECEIPT_CANDIDATE_STEPS")
    exact(receipt["matched_zero_outer_steps"], 2, "RECEIPT_ZERO_STEPS")

    verify_exact_paths(result, {
        "schema_version": (
            "sporespore_qsdk_r24d49_rapier_recovery_energy_v2_ghost_v1"
        ),
        "ok": True,
        "gate_id": GATE,
        "route_id": (
            "sporespore_qsdk_r24d48_rapier_recovery_energy_v2_route_v1"
        ),
        "question_class": "development_integration_ghost",
        "runtime_qualification_sha256": RUNTIME_BINDING,
        "runtime_binding_sha256": RUNTIME_BINDING,
        "behavior_lineage_gate_id": "QSDK-R24D48",
        "runtime_binding_projection_schema": (
            "sporespore_qsdk_r24d49_runtime_binding_projection_v1"
        ),
        "maximum_outer_steps_per_arm": 2,
        "maximum_total_outer_steps": 4,
        "actual_total_outer_steps": 4,
        "behavior_success_required": False,
        "official_behavior_evidence": False,
        "result_may_satisfy_prone_to_standing": False,
        "held_out_cell_access_count": 0,
        "held_out_selector_invocation_count": 0,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }, "RESULT")
    candidate = result["candidate"]
    matched = result["matched_zero_command"]
    verify_exact_paths(candidate, {
        "arm_kind": "candidate_command",
        "cell_id": "r24d48_rapier_development_nominal",
        "seed": 260226999,
    }, "CANDIDATE_IDENTITY")
    verify_exact_paths(matched, {
        "arm_kind": "matched_zero_command",
        "cell_id": "r24d48_rapier_development_nominal",
        "seed": 260226999,
    }, "MATCHED_IDENTITY")
    candidate_projection = verify_rapier_recovery_energy_v2_arm(
        candidate, "CANDIDATE", expected_outer_steps=2
    )
    matched_projection = verify_rapier_recovery_energy_v2_arm(
        matched, "MATCHED_ZERO", expected_outer_steps=2
    )
    observed = closure["observed_integration"]
    exact(candidate_projection, observed["candidate"], "CANDIDATE_PROJECTION")
    exact(matched_projection, observed["matched_zero_command"],
          "MATCHED_PROJECTION")
    exact(
        candidate["declared_initial_state_sha256"],
        matched["declared_initial_state_sha256"],
        "PAIRED_INITIAL_STATE",
    )
    require(
        all(value["no_actuation_requested"] for value in
            candidate["planned_control_receipts"])
        and all(not value["matched_zero_command"] for value in
                candidate["planned_control_receipts"])
        and all(value["no_actuation_requested"] for value in
                matched["planned_control_receipts"])
        and all(value["matched_zero_command"] for value in
                matched["planned_control_receipts"]),
        "GHOST_NO_ACTUATION_CONTROL_PARTITION",
    )
    exact(
        (
            sum(arm["model_construction_count"] for arm in (candidate, matched)),
            sum(arm["world_attempt_count"] for arm in (candidate, matched)),
            sum(arm["world_build_count"] for arm in (candidate, matched)),
            sum(arm["native_solver_step_count"] for arm in (candidate, matched)),
            sum(arm["outer_step_count"] for arm in (candidate, matched)),
        ),
        (
            closure["physical_attempt"]["model_construction_count"],
            closure["physical_attempt"]["world_attempt_count"],
            closure["physical_attempt"]["world_build_count"],
            closure["physical_attempt"]["solver_step_count"],
            closure["physical_attempt"]["actual_total_outer_steps"],
        ),
        "PHYSICAL_COUNTS",
    )

    physical = closure["physical_attempt"]
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
        "QSDK_R24D49_RAPIER_RECOVERY_ENERGY_V2_GHOST {",
    ), "WORKER_PASS_ORDER")

    route = bound["runtime_binding_route"].decode("utf-8")
    require_ordered_markers(route, (
        "pub fn run_qsdk_r24d49_rapier_recovery_energy_v2_ghost(",
        "validate_runtime_binding_sha256(runtime_binding_sha256)?;",
        "run_qsdk_r24d48_rapier_recovery_energy_v2_ghost_after_runtime_binding_v1(",
        "relabel_result(result, GHOST_SCHEMA, runtime_binding_sha256)",
    ), "R49_PHYSICAL_ROUTE")
    runner = bound["shared_physical_runner"].decode("utf-8")
    require_ordered_markers(runner, (
        "runtime_binding_closure_json_pointer",
        "$runtimeBindingField",
        "physical_attempt.json",
        "sporespore_rapier_adapter::$ghostEntrypoint(",
        "physical_result.json",
        "physical_receipt.json",
    ), "PHYSICAL_RUNNER")

    exact_bools(closure["decision"], (
        "integration_ghost_attempt_consumed_for_exact_source",
        "integration_ghost_valid", "integration_ghost_complete",
        "integration_ghost_passed", "qualified_runtime_binding_consumed_exactly",
        "live_v2_recovery_route_physically_exercised", "paired_initial_state_exact",
        "complete_in_run_chain_observed", "all_in_run_source_invariants_passed",
        "all_retained_evidence_content_addressed", "operation_lock_released",
        "paired_development_authorized",
    ), True, "DECISION_TRUE")
    exact_bools(closure["decision"], (
        "behavior_success_required", "behavior_success_observed",
        "controller_changed", "threshold_changed", "selector_changed",
        "evaluator_changed", "morphology_changed", "initializer_changed",
        "r24d49_exact_source_ghost_rerun_permitted",
        "paired_development_attempt_consumed", "prone_to_standing_claimed",
        "physical_acceptance_authority", "release_authority",
    ), False, "DECISION_FALSE")
    exact_bools(closure["claim_boundary"], (
        "official_zero_world_qualification_passed", "runtime_binding_qualified",
        "integration_ghost_attempt_retained",
        "integration_ghost_attempt_consumed_for_exact_source",
        "integration_ghost_passed", "live_v2_recovery_route_physically_exercised_by_r49",
        "paired_initial_state_exact", "all_in_run_physical_invariants_passed",
        "paired_development_stage_authorized", "held_out_cells_remain_sealed",
    ), True, "CLAIM_TRUE")
    exact_bools(closure["claim_boundary"], (
        "behavior_success_claimed", "paired_development_attempt_consumed",
        "prone_to_standing_claimed", "repeatability_rate_claimed",
        "population_claimed", "held_out_validation_claimed",
        "cross_engine_recovery_claimed", "cross_engine_equivalence_claimed",
        "sdk1_milestone_advanced", "physical_acceptance_authority",
        "release_authority",
    ), False, "CLAIM_FALSE")
    exact(closure["sdk_status"], {
        "sdk1_milestone_advanced": False, "sdk1_completed_steps": 11,
        "sdk1_total_steps": 20, "full_program_completed_steps": 11,
        "full_program_total_steps": 25,
    }, "SDK_STATUS")
    verify_exact_paths(closure["audit_economy"], {
        "common_staged_physical_runner_closure_helper_reused": True,
        "common_rapier_recovery_energy_v2_arm_helper_reused": True,
        "historical_closure_audit_execution_count": 0,
        "physical_reexecution_count": 0,
        "new_campaign_specific_physical_canary_count": 0,
    }, "AUDIT_ECONOMY")
    verify_exact_paths(closure["next_boundary"], {
        "gate_id": GATE,
        "stage_id": "R24D49-B",
        "question_class": "development",
        "physical_execution_authorized": True,
        "maximum_outer_steps_per_arm_authorized": 1200,
        "maximum_total_outer_steps_authorized": 2400,
        "additional_physical_canary_required": False,
        "same_identity_ghost_rerun_permitted": False,
        "paired_development_attempt_consumed": False,
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

    relative = CLOSURE_PATH.relative_to(ROOT).as_posix()
    publication = git(ROOT, "log", "-1", "--diff-filter=A", "--format=%H",
                      "--", relative)
    assert isinstance(publication, str)
    revision = publication or None
    closure_raw = (CLOSURE_PATH.read_bytes() if revision is None else
                   source_bytes(ROOT, revision, relative))
    live = {
        **closure["live_gate_expectations"],
        "r24d49_integration_ghost_closure_raw_sha256": sha256(closure_raw),
    }
    verify_legacy_live_gate_paths(
        ROOT, closure["live_authority_paths"], "QSDK-R24D45", live,
        revision=revision,
    )
    print(
        "QSDK_R24D49_RAPIER_RECOVERY_ENERGY_V2_GHOST_POSITIVE_CLOSURE_PASS "
        "files=7 models=2 worlds=2 solver_steps=4 outer_steps=4 "
        "in_run_chains=4 behavior=false stage_b_steps=2400 sdk1=11/20"
    )


if __name__ == "__main__":
    try:
        audit()
    except (
        ClosureAuditError, OSError, KeyError, IndexError, TypeError, ValueError,
        subprocess.SubprocessError,
    ) as error:
        print(
            "QSDK_R24D49_RAPIER_RECOVERY_ENERGY_V2_GHOST_POSITIVE_CLOSURE_FAIL "
            f"{error}", file=sys.stderr,
        )
        raise SystemExit(1) from error
