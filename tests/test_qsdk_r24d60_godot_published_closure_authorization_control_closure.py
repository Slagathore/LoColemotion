"""Compact audit of the one exact R24D60 post-publication control."""

from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError, exact, git, sha256, source_bytes, verify_boolean_partition,
    verify_exact_paths, verify_legacy_live_gate_paths,
    verify_published_closure_authorization_control,
)

CLOSURE = ROOT / "sdk/recovery/r24d60_godot_published_closure_authorization_control_closure_v1.json"
SOURCE = "9cb1cd22d58212bb90e5c8f76bdd4f1b3eb96dad"
STATUS = "closed_published_closure_authorization_control_positive_one_bounded_physical_ghost_authorized"
TRUE = (
    "zero_world_qualification_preserved", "exact_published_closure_loaded",
    "authorization_projection_exactly_matched", "complete_r60_preflight_reexecuted",
    "operation_lock_serialization_proven", "operation_lock_release_proven",
    "zero_physical_counts_proven", "one_bounded_physical_ghost_authorized",
    "physical_execution_authorized",
)
DECISION_FALSE = (
    "held_out", "physical_attempted", "native_world_constructed",
    "solver_step_executed", "controller_behavior_evaluated",
    "exact_nominal_godot_prone_to_standing_observed", "prone_to_standing_claimed",
    "repeatability_rate_claimed", "population_claimed", "held_out_validation_claimed",
    "cross_engine_recovery_claimed", "cross_engine_equivalence_claimed",
    "sdk1_milestone_advanced", "physical_acceptance_authority", "release_authority",
)
CLAIM_FALSE = tuple(
    "controller_physical_viability_proven" if key == "controller_behavior_evaluated" else key
    for key in DECISION_FALSE if key != "held_out"
)


def audit() -> None:
    closure, _predecessor, _receipt = verify_published_closure_authorization_control(
        root=ROOT, closure_path=CLOSURE,
        schema_version="sporespore_qsdk_r24d60_godot_published_closure_authorization_control_closure_v1",
        gate_id="QSDK-R24D60", closure_status=STATUS, control_commit=SOURCE,
        control_subject="[recovery/godot] Close R60 zero-world qualification",
        predecessor_status="closed_complete_zero_world_native_telemetry_schema_consumer_qualified_published_closure_control_required_physics_blocked",
        receipt_schema="sporespore_qsdk_r24d60_published_closure_authorization_control_v1",
        preflight_schema="sporespore_qsdk_r24d60_ghost_preflight_v1",
    )

    decision = closure["decision"]
    verify_exact_paths(decision, {
        "result": "positive_exact_published_closure_loaded_by_production_supervisor_at_zero_world",
        "seed": 89023516, "held_out": False, "maximum_world_build_count": 1,
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
        "gate_id": "QSDK-R24D60", "question_class": "development",
        "physical_question_declared": True, "seed": 89023516, "held_out": False,
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
            "r24d60_authorization_control_closure_raw_sha256": sha256(raw)}
    verify_legacy_live_gate_paths(ROOT, closure["live_authority_paths"],
                                  "QSDK-R24D45", live, revision=revision)
    print("QSDK_R24D60_GODOT_PUBLISHED_CLOSURE_AUTHORIZATION_CONTROL_CLOSURE_PASS "
          "invocations=1 receipts=1 files=1 preflight=1 parse=1 models=0 worlds=0 "
          "steps=0 physics=0 next=one_world_two_steps sdk1=11/20")


if __name__ == "__main__":
    try:
        audit()
    except (ClosureAuditError, OSError, KeyError, TypeError, ValueError,
            subprocess.SubprocessError) as error:
        print(f"QSDK_R24D60_GODOT_PUBLISHED_CLOSURE_AUTHORIZATION_CONTROL_CLOSURE_FAIL {error}",
              file=sys.stderr)
        raise SystemExit(1) from error
