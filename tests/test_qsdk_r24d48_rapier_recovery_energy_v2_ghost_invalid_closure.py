"""Compact audit of the retained pre-world invalid R24D48 integration ghost."""

from __future__ import annotations

import json
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
    matching_evidence_roots,
    require,
    require_ordered_markers,
    sha256,
    source_bytes,
    verify_boolean_partition,
    verify_exact_paths,
    verify_legacy_live_gate_paths,
    verify_retained_file_tree,
    verify_retained_json,
    verify_source_binding,
)


CLOSURE_PATH = ROOT / (
    "sdk/recovery/"
    "r24d48_rapier_recovery_energy_v2_ghost_invalid_closure_v1.json"
)
SOURCE = "a6d171d606b632e1cc33f5d70b2fd2c67917c359"
GATE = "QSDK-R24D48"
STATUS = (
    "closed_invalid_pre_world_runtime_qualification_digest_"
    "representation_mismatch_no_physics"
)
DECISION_TRUE = (
    "integration_ghost_attempt_consumed_for_exact_source",
    "worker_and_dependency_graph_compiled",
    "qualification_cargo_lock_reused_exactly",
    "runtime_digest_transport_inconsistent",
    "failure_preceded_model_construction",
    "failure_preceded_world_construction",
    "failure_preceded_solver_step",
    "distinct_successor_source_required",
)
DECISION_FALSE = (
    "physical_result_observed",
    "physics_failure_observed",
    "controller_behavior_evaluated",
    "energy_balance_physically_observed",
    "integration_ghost_passed",
    "paired_development_authorized",
    "r24d48_exact_source_ghost_rerun_permitted",
    "r24d48_requalification_permitted",
    "historical_threshold_changed",
    "historical_selector_changed",
    "historical_evaluator_changed",
    "historical_result_rewritten",
    "prone_to_standing_claimed",
    "physical_acceptance_authority",
    "release_authority",
)
NEXT_TRUE = (
    "physical_execution_blocked",
    "complete_zero_world_gate_required",
    "distinct_clean_pushed_source_required",
    "held_out_cells_remain_sealed",
)
NEXT_FALSE = (
    "full_seeded_ghost_required",
    "additional_physical_canary_required",
    "r24d48_may_be_rerun_or_requalified",
    "prone_to_standing_claimed",
    "physical_acceptance_authority",
    "release_authority",
)
CLAIM_TRUE = (
    "integration_ghost_attempt_retained",
    "integration_ghost_attempt_consumed_for_exact_source",
    "invalid_pre_world_integration_result",
    "qualification_cargo_lock_reuse_observed",
    "operation_lock_released",
)
CLAIM_FALSE = (
    "physical_world_opened",
    "live_v2_recovery_route_physically_exercised",
    "integration_ghost_passed",
    "paired_development_attempt_consumed",
    "controller_behavior_evaluated",
    "energy_balance_physically_observed",
    "prone_to_standing_claimed",
    "population_claimed",
    "cross_engine_equivalence_claimed",
    "sdk1_milestone_advanced",
    "physical_acceptance_authority",
    "release_authority",
)


def audit() -> None:
    closure = load(CLOSURE_PATH)
    verify_exact_paths(closure, {
        "schema_version": (
            "sporespore_qsdk_r24d48_rapier_recovery_energy_v2_"
            "ghost_invalid_closure_v1"
        ),
        "gate_id": GATE,
        "stage_id": "R24D48-A",
        "closure_status": STATUS,
        "question_class": "development_integration_ghost",
        "physical_question_declared": True,
        "behavior_success_required": False,
        "superiority_question_declared": False,
        "equivalence_or_non_inferiority_question_declared": False,
        "population_inference_declared": False,
        "source.commit": SOURCE,
        "source.parent_commit": "2633da0297e999c0211e20fdb5e0d5b25f315ec9",
        "source.tree": "787ecb7fa150c32d4d3cc2dc7dc908d0b877bae1",
        "source.subject": "[recovery/rapier] Close R48 zero-world qualification",
        "source.qualification_source_commit": (
            "2633da0297e999c0211e20fdb5e0d5b25f315ec9"
        ),
    }, "CLOSURE")
    exact(git(ROOT, "show", "-s", "--format=%P", SOURCE),
          closure["source"]["parent_commit"], "SOURCE_PARENT")
    exact(git(ROOT, "show", "-s", "--format=%T", SOURCE),
          closure["source"]["tree"], "SOURCE_TREE")
    exact(git(ROOT, "show", "-s", "--format=%s", SOURCE),
          closure["source"]["subject"], "SOURCE_SUBJECT")

    bindings = closure["source"]
    route_raw = verify_source_binding(ROOT, SOURCE, bindings["route"])
    runner_raw = verify_source_binding(ROOT, SOURCE, bindings["physical_runner"])
    qualification_raw = verify_source_binding(
        ROOT, SOURCE, bindings["qualification_closure"]
    )
    qualification = load(ROOT / bindings["qualification_closure"]["path"])
    exact(sha256(qualification_raw), bindings["qualification_closure"]["raw_sha256"],
          "QUALIFICATION_CLOSURE_HASH")
    exact(qualification["closure_status"],
          "closed_complete_zero_world_rapier_recovery_energy_v2_qualified_physics_staged",
          "QUALIFICATION_STATUS")

    physical = closure["physical_attempt"]
    evidence_root = Path(physical["evidence_root"])
    exact(matching_evidence_roots(
        evidence_root.parent,
        "qsdk-r24d48-rapier-recovery-energy-v2-ghost-",
        "physical_attempt.json",
        GATE,
        SOURCE,
    ), [evidence_root], "ATTEMPT_POPULATION")
    verify_retained_file_tree(evidence_root, physical["retained_tree"])
    exact(sorted(path.relative_to(evidence_root).as_posix()
                 for path in evidence_root.rglob("*") if path.is_file()), [
        "01-worker.log",
        "isolated-harness/Cargo.lock",
        "isolated-harness/Cargo.toml",
        "isolated-harness/src/main.rs",
        "physical_attempt.json",
        "physical_failure.json",
    ], "RETAINED_PATHS")
    require(not (evidence_root / "physical_result.json").exists(),
            "UNEXPECTED_PHYSICAL_RESULT")
    require(not (evidence_root / "physical_receipt.json").exists(),
            "UNEXPECTED_PHYSICAL_RECEIPT")

    attempt = verify_retained_json(
        evidence_root / physical["attempt_path"],
        physical["attempt_byte_length"], physical["attempt_raw_sha256"],
        physical["attempt_canonical_byte_length"],
        physical["attempt_canonical_sha256"],
    )
    failure = verify_retained_json(
        evidence_root / physical["failure_path"],
        physical["failure_byte_length"], physical["failure_raw_sha256"],
        physical["failure_canonical_byte_length"],
        physical["failure_canonical_sha256"],
    )
    verify_exact_paths(attempt, {
        "schema_version": (
            "sporespore_qsdk_r24d48_rapier_recovery_energy_v2_physical_attempt_v1"
        ),
        "gate_id": GATE, "mode": "ghost", "source_commit": SOURCE,
        "qualification_source_commit": closure["source"]["qualification_source_commit"],
        "runtime_qualification_sha256": physical["runtime_qualification_sha256_supplied"],
        "branch": "main", "remote": "https://github.com/Slagathore/sporespore.git",
        "upstream_commit": SOURCE, "live_remote_commit": SOURCE,
        "worktree_clean_at_start": True,
        "environment_sha256": physical["environment_sha256"],
        "ghost_authority_path": None,
        "physical_acceptance_authority": False, "release_authority": False,
    }, "ATTEMPT")
    environment_bytes = json.dumps(
        attempt["environment"], ensure_ascii=False, separators=(",", ":")
    ).encode("utf-8")
    exact(sha256(environment_bytes),
          attempt["environment_sha256"], "ENVIRONMENT_HASH")
    exact(attempt["environment"]["qualification_harness_cargo_lock_sha256"],
          physical["retained_qualification_cargo_lock"]["raw_sha256"],
          "ATTEMPT_CARGO_LOCK")
    verify_exact_paths(failure, {
        "schema_version": (
            "sporespore_qsdk_r24d48_rapier_recovery_energy_v2_physical_failure_v1"
        ),
        "gate_id": GATE, "mode": "ghost", "source_commit": SOURCE,
        "runtime_qualification_sha256": physical["runtime_qualification_sha256_supplied"],
        "error": "QSDK_R24D48_PHYSICAL:WORKER:EXIT=101",
        "operation_lock_released": True,
        "physical_acceptance_authority": False, "release_authority": False,
    }, "FAILURE")

    log_raw = (evidence_root / physical["worker_log_path"]).read_bytes()
    exact((len(log_raw), sha256(log_raw)),
          (physical["worker_log_byte_length"], physical["worker_log_raw_sha256"]),
          "WORKER_LOG")
    mismatch = (
        physical["failure_code"] + ":expected="
        + physical["runtime_qualification_sha256_expected_by_worker"]
        + ":observed=" + physical["runtime_qualification_sha256_supplied"]
    )
    log = log_raw.decode("utf-8")
    require_ordered_markers(log, (
        "Finished `dev` profile", "Running `", mismatch, "exit code: 101",
    ), "WORKER_FAILURE_ORDER")
    require("QSDK_R24D48_RAPIER_RECOVERY_ENERGY_V2_GHOST " not in log,
            "UNEXPECTED_GHOST_TERMINAL")
    lock = physical["retained_qualification_cargo_lock"]
    lock_raw = (evidence_root / lock["path"]).read_bytes()
    exact((len(lock_raw), sha256(lock_raw)),
          (lock["byte_length"], lock["raw_sha256"]), "RETAINED_CARGO_LOCK")
    exact(lock["raw_sha256"],
          qualification["qualification"]["isolated_harness_cargo_lock"]["raw_sha256"],
          "QUALIFICATION_CARGO_LOCK_REUSE")

    route = route_raw.decode("utf-8")
    ghost = route[route.index("pub fn run_qsdk_r24d48_rapier_recovery_energy_v2_ghost("):
                  route.index("pub fn run_qsdk_r24d48_rapier_recovery_energy_v2_development_attempt(")]
    require_ordered_markers(ghost, (
        "validate_runtime_qualification_sha256(runtime_qualification_sha256)?;",
        "compile_r24d45_recovery_boundary_v1()?;",
        "run_arm(",
    ), "PRE_WORLD_FAILURE_ORDER")
    runner = runner_raw.decode("utf-8")
    require_ordered_markers(runner, (
        "$qualificationReceipt = Get-Content",
        "$runtimeQualificationSha256 =",
        "[string]$closure.qualification.production_preflight_canonical_sha256",
        "physical_attempt.json",
    ), "LAUNCHER_DIGEST_TRANSPORT")

    counts = ("model_construction_count", "world_attempt_count",
              "world_build_count", "solver_step_count", "actual_total_outer_steps")
    for key in counts:
        exact(physical[key], 0, f"PHYSICAL_{key.upper()}")
    verify_boolean_partition(closure["decision"], DECISION_TRUE, DECISION_FALSE,
                             "DECISION")
    verify_boolean_partition(closure["next_boundary"], NEXT_TRUE, NEXT_FALSE,
                             "NEXT")
    verify_boolean_partition(closure["claim_boundary"], CLAIM_TRUE, CLAIM_FALSE,
                             "CLAIM")
    exact(closure["sdk_status"], {
        "sdk1_milestone_advanced": False, "sdk1_completed_steps": 11,
        "sdk1_total_steps": 20, "full_program_completed_steps": 11,
        "full_program_total_steps": 25,
    }, "SDK_STATUS")

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
        "r24d48_integration_ghost_invalid_closure_raw_sha256": sha256(closure_raw),
    }
    verify_legacy_live_gate_paths(
        ROOT, closure["live_authority_paths"], "QSDK-R24D45", live,
        revision=revision,
    )
    print(
        "QSDK_R24D48_RAPIER_RECOVERY_ENERGY_V2_GHOST_INVALID_CLOSURE_PASS "
        "files=6 compile=true models=0 worlds=0 solver_steps=0 outer_steps=0 "
        "result=invalid_digest_transport sdk1=11/20 next=QSDK-R24D49"
    )


if __name__ == "__main__":
    try:
        audit()
    except (ClosureAuditError, OSError, KeyError, TypeError, ValueError,
            subprocess.SubprocessError) as error:
        print(
            "QSDK_R24D48_RAPIER_RECOVERY_ENERGY_V2_GHOST_INVALID_CLOSURE_FAIL "
            f"{error}", file=sys.stderr,
        )
        raise SystemExit(1) from error
