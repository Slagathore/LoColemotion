"""Audit the one exact R24D59 post-publication authorization control."""

from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError, canonical_bytes, exact, git, load, retained_file_tree_projection,
    sha256, source_bytes, verify_boolean_partition, verify_exact_paths,
    verify_legacy_live_gate_paths, verify_retained_commit, verify_retained_json,
)

CLOSURE = ROOT / "sdk/recovery/r24d59_godot_published_closure_authorization_control_closure_v1.json"
SOURCE = "dd68a58082e326a6f2af19230b234a873b41065f"
STATUS = "closed_published_closure_authorization_control_positive_one_bounded_physical_ghost_authorized"
TRUE = (
    "zero_world_qualification_preserved", "exact_published_closure_loaded",
    "authorization_projection_exactly_matched", "complete_r59_preflight_reexecuted",
    "operation_lock_serialization_proven", "operation_lock_release_proven",
    "zero_physical_counts_proven", "one_bounded_physical_ghost_authorized",
    "physical_execution_authorized",
)
DECISION_FALSE = (
    "held_out",
    "physical_attempted", "native_world_constructed", "solver_step_executed",
    "controller_behavior_evaluated", "exact_nominal_godot_prone_to_standing_observed",
    "prone_to_standing_claimed", "repeatability_rate_claimed", "population_claimed",
    "held_out_validation_claimed", "cross_engine_recovery_claimed",
    "cross_engine_equivalence_claimed", "sdk1_milestone_advanced",
    "physical_acceptance_authority", "release_authority",
)
CLAIM_FALSE = tuple(
    "controller_physical_viability_proven" if key == "controller_behavior_evaluated" else key
    for key in DECISION_FALSE if key != "held_out"
)


def audit() -> None:
    closure = load(CLOSURE)
    exact((closure["schema_version"], closure["gate_id"], closure["closure_status"],
           closure["question_class"], closure["physical_question_declared"]),
          ("sporespore_qsdk_r24d59_godot_published_closure_authorization_control_closure_v1",
           "QSDK-R24D59", STATUS, "development", False), "CLOSURE_IDENTITY")
    verify_boolean_partition(closure, (), (
        "physical_question_declared",
        "superiority_question_declared", "equivalence_or_non_inferiority_question_declared",
        "population_inference_declared",
    ), "QUESTION_DECLARATION")

    source = closure["source"]
    verify_retained_commit(ROOT, SOURCE, source["parent_commit"])
    exact((source["control_commit"], source["tree"], source["subject"],
           source["clean_pushed_live_equal"], source["qualified_physical_path_drift_from_source_freeze"]),
          (SOURCE, git(ROOT, "show", "-s", "--format=%T", SOURCE),
           "[recovery/godot] Close R59 zero-world qualification", True, False),
          "SOURCE")

    predecessor = closure["predecessor"]
    predecessor_path = ROOT / predecessor["closure_path"]
    predecessor_value = load(predecessor_path)
    exact((sha256(predecessor_path.read_bytes()), predecessor_path.stat().st_size,
           predecessor_value["closure_status"]),
          (predecessor["closure_raw_sha256"], predecessor["closure_byte_length"],
           predecessor["closure_status"]), "PREDECESSOR")
    verify_boolean_partition(predecessor, (), (
        "historical_result_rewritten", "historical_threshold_rewritten",
        "historical_evaluator_rewritten", "historical_interpretation_rewritten",
        "same_identity_requalification_permitted",
    ), "PREDECESSOR_FLAGS")

    control = closure["authorization_control"]
    evidence_root = Path(control["evidence_root"])
    exact(retained_file_tree_projection(evidence_root), control["retained_tree"], "TREE")
    receipt = verify_retained_json(
        evidence_root / control["receipt_path"], control["receipt_byte_length"],
        control["receipt_raw_sha256"], control["receipt_canonical_byte_length"],
        control["receipt_canonical_sha256"],
    )
    exact([p.name for p in evidence_root.iterdir() if p.is_file()],
          ["authorization_control.json"], "COMPLETE_FILE_POPULATION")
    verify_exact_paths(receipt, {
        "schema_version": "sporespore_qsdk_r24d59_published_closure_authorization_control_v1",
        "gate_id": "QSDK-R24D59", "question_class": "development", "ok": True,
        "status": "published_closure_authorization_control_passed",
        "control_id": control["control_id"], "source.control_commit": SOURCE,
        "source.repository.root": "C:/Users/Cole/CodeStuff/games/SporeSpore",
        "source.repository.remote": "https://github.com/Slagathore/sporespore.git",
        "source.repository.branch": "main", "source.repository.head": SOURCE,
        "source.repository.upstream": SOURCE, "source.repository.cached_origin_main": SOURCE,
        "source.repository.live_origin_main": SOURCE,
        "source.repository.worktree_count": 1, "source.repository.worktree_clean": True,
        "authorization.path": control["authorization_closure_absolute_path"],
        "authorization.raw_sha256": control["authorization_closure_raw_sha256"],
        "authorization.byte_length": control["authorization_closure_byte_length"],
        "authorization.source_freeze_commit": control["authorization_source_freeze_commit"],
        "preflight.gate_id": "QSDK-R24D59", "preflight.ok": True,
        "preflight.source_audit_and_runtime_preflight_count": 1,
        "preflight.worker_parse_count": 1, "operation_lock.acquired": True,
        "operation_lock.released": True, "operation_lock.role": "conformance",
        "operation_lock.test_only": False, "operation_lock.abandoned_owner_recovered": False,
        "model_construction_count": 0, "world_attempt_count": 0,
        "world_build_count": 0, "solver_step_count": 0,
        "physical_execution_count": 0, "physics_state_modified": False,
        "next_physical_invocation_authorized": True, "held_out": False,
        "same_identity_rerun_permitted": False, "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False, "release_authority": False,
    }, "RECEIPT")
    exact(receipt["authorization"]["projection"],
          predecessor_value["physical_authorization"], "PROJECTION_BINDING")
    exact((len(canonical_bytes(receipt["authorization"]["projection"])),
           sha256(canonical_bytes(receipt["authorization"]["projection"])),
           len(canonical_bytes(receipt["preflight"])),
           sha256(canonical_bytes(receipt["preflight"]))),
          (control["projection_canonical_byte_length"],
           control["projection_canonical_sha256"], control["preflight_canonical_byte_length"],
           control["preflight_canonical_sha256"]), "CANONICAL_COMPONENTS")

    decision = closure["decision"]
    verify_exact_paths(decision, {
        "result": "positive_exact_published_closure_loaded_by_production_supervisor_at_zero_world",
        "seed": 1802965793, "held_out": False, "maximum_world_build_count": 1,
        "maximum_outer_solver_steps": 2, "new_behavior_threshold_count": 0,
        "new_empirical_threshold_count": 0, "new_margin_count": 0,
        "observed_physical_cohort_count": 0, "held_out_cohort_count": 0,
        "population_claim_count": 0,
    }, "DECISION")
    verify_boolean_partition(decision, TRUE, DECISION_FALSE, "DECISION_FLAGS")
    verify_boolean_partition(closure["claim_boundary"], TRUE, CLAIM_FALSE, "CLAIM")
    exact(closure["sdk_status"], {
        "sdk1_milestone_advanced": False, "sdk1_completed_steps": 11,
        "sdk1_total_steps": 20, "full_program_completed_steps": 11,
        "full_program_total_steps": 25,
    }, "SDK_STATUS")
    verify_exact_paths(closure["next_boundary"], {
        "gate_id": "QSDK-R24D59", "question_class": "development",
        "physical_question_declared": True, "seed": 1802965793, "held_out": False,
        "authorized_world_count": 1, "maximum_world_build_count": 1,
        "maximum_outer_solver_steps": 2, "maximum_physical_steps_authorized": 2,
        "same_source_physical_attempt_limit": 1, "same_identity_rerun_permitted": False,
        "recovery_success_required": False, "physical_execution_authorized": True,
    }, "NEXT")

    relative = CLOSURE.relative_to(ROOT).as_posix()
    publication = git(ROOT, "log", "-1", "--diff-filter=A", "--format=%H", "--", relative)
    assert isinstance(publication, str)
    revision = publication or None
    raw = CLOSURE.read_bytes() if revision is None else source_bytes(ROOT, revision, relative)
    live = {**closure["live_gate_expectations"],
            "r24d59_authorization_control_closure_raw_sha256": sha256(raw)}
    verify_legacy_live_gate_paths(ROOT, closure["live_authority_paths"],
                                  "QSDK-R24D45", live, revision=revision)
    print("QSDK_R24D59_GODOT_PUBLISHED_CLOSURE_AUTHORIZATION_CONTROL_CLOSURE_PASS "
          "invocations=1 receipts=1 files=1 preflight=1 parse=1 models=0 worlds=0 "
          "steps=0 physics=0 next=one_world_two_steps sdk1=11/20")


if __name__ == "__main__":
    try:
        audit()
    except (ClosureAuditError, OSError, KeyError, TypeError, ValueError,
            subprocess.SubprocessError) as error:
        print(f"QSDK_R24D59_GODOT_PUBLISHED_CLOSURE_AUTHORIZATION_CONTROL_CLOSURE_FAIL {error}",
              file=sys.stderr)
        raise SystemExit(1) from error
