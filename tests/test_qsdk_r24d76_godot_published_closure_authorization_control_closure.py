"""Audit the one exact R76 post-publication authorization control."""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    canonical_bytes,
    exact,
    git,
    load,
    records_with_key,
    retained_file_tree_projection,
    sha256,
    verify_boolean_partition,
    verify_exact_paths,
    verify_retained_commit,
    verify_retained_json,
)

CLOSURE = ROOT / (
    "sdk/recovery/r24d76_godot_published_closure_"
    "authorization_control_closure_v1.json"
)
SOURCE = "be5da9ea1a38167b480cf494c22adad3f23e3247"
STATUS = (
    "closed_published_closure_authorization_control_positive_one_finite_"
    "solved_contact_recovery_pair_authorized"
)
PREDECESSOR_STATUS = (
    "closed_complete_zero_world_solved_contact_recovery_behavior_qualified_"
    "one_paired_development_attempt_authorized"
)
TRUE = (
    "zero_world_qualification_preserved",
    "exact_published_closure_loaded",
    "authorization_projection_exactly_matched",
    "complete_r76_preflight_reexecuted",
    "seven_current_zero_world_worker_contract_preserved",
    "forced_failure_and_missing_switch_controls_preserved",
    "operation_lock_serialization_proven",
    "operation_lock_release_proven",
    "zero_physical_counts_proven",
    "one_finite_solved_contact_recovery_pair_authorized",
    "physical_execution_authorized",
)
DECISION_FALSE = (
    "held_out",
    "physical_attempted",
    "native_world_constructed",
    "solver_step_executed",
    "controller_behavior_evaluated",
    "valid_godot_behavior_result_observed",
    "exact_nominal_godot_prone_to_standing_observed",
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
CLAIM_FALSE = tuple(
    "controller_physical_viability_proven"
    if key == "controller_behavior_evaluated"
    else key
    for key in DECISION_FALSE
    if key != "held_out"
)


def verify_control_shell() -> tuple[dict, dict, dict]:
    """Reuse compact primitives while preserving R76's declared projection view."""

    closure = load(CLOSURE)
    verify_exact_paths(
        closure,
        {
            "schema_version": (
                "sporespore_qsdk_r24d76_godot_published_closure_"
                "authorization_control_closure_v1"
            ),
            "gate_id": "QSDK-R24D76",
            "closure_status": STATUS,
            "question_class": "development",
            "physical_question_declared": False,
        },
        "CLOSURE_IDENTITY",
    )
    verify_boolean_partition(
        closure,
        (),
        (
            "physical_question_declared",
            "superiority_question_declared",
            "equivalence_or_non_inferiority_question_declared",
            "population_inference_declared",
        ),
        "QUESTION_DECLARATION",
    )

    source = closure["source"]
    verify_retained_commit(ROOT, SOURCE, source["parent_commit"])
    verify_exact_paths(
        source,
        {
            "control_commit": SOURCE,
            "tree": git(ROOT, "show", "-s", "--format=%T", SOURCE),
            "subject": (
                "[recovery/godot] Close R76: authorize solved-contact "
                "recovery behavior"
            ),
            "repository_root": ROOT.as_posix(),
            "remote": "https://github.com/Slagathore/sporespore.git",
            "branch": "main",
            "worktree_count": 1,
            "clean_pushed_live_equal": True,
            "qualified_physical_path_drift_from_source_freeze": False,
        },
        "SOURCE",
    )

    predecessor_claim = closure["predecessor"]
    predecessor_path = ROOT / predecessor_claim["closure_path"]
    predecessor = load(predecessor_path)
    exact(
        (
            sha256(predecessor_path.read_bytes()),
            predecessor_path.stat().st_size,
            predecessor["closure_status"],
        ),
        (
            predecessor_claim["closure_raw_sha256"],
            predecessor_claim["closure_byte_length"],
            PREDECESSOR_STATUS,
        ),
        "PREDECESSOR",
    )
    verify_boolean_partition(
        predecessor_claim,
        (),
        (
            "historical_result_rewritten",
            "historical_threshold_rewritten",
            "historical_evaluator_rewritten",
            "historical_interpretation_rewritten",
            "same_identity_requalification_permitted",
        ),
        "PREDECESSOR_FLAGS",
    )

    control = closure["authorization_control"]
    evidence_root = Path(control["evidence_root"])
    exact(retained_file_tree_projection(evidence_root), control["retained_tree"], "TREE")
    receipt = verify_retained_json(
        evidence_root / control["receipt_path"],
        control["receipt_byte_length"],
        control["receipt_raw_sha256"],
        control["receipt_canonical_byte_length"],
        control["receipt_canonical_sha256"],
    )
    exact(
        sorted(path.name for path in evidence_root.iterdir() if path.is_file()),
        [control["receipt_path"]],
        "COMPLETE_FILE_POPULATION",
    )
    verify_exact_paths(
        receipt,
        {
            "schema_version": (
                "sporespore_qsdk_r24d76_published_closure_"
                "authorization_control_v1"
            ),
            "gate_id": "QSDK-R24D76",
            "question_class": "development",
            "ok": True,
            "status": "published_closure_authorization_control_passed",
            "control_id": control["control_id"],
            "source.control_commit": SOURCE,
            "source.repository.root": ROOT.as_posix(),
            "source.repository.remote": "https://github.com/Slagathore/sporespore.git",
            "source.repository.branch": "main",
            "source.repository.head": SOURCE,
            "source.repository.upstream": SOURCE,
            "source.repository.cached_origin_main": SOURCE,
            "source.repository.live_origin_main": SOURCE,
            "source.repository.worktree_count": 1,
            "source.repository.worktree_clean": True,
            "authorization.path": control["authorization_closure_absolute_path"],
            "authorization.raw_sha256": control["authorization_closure_raw_sha256"],
            "authorization.byte_length": control["authorization_closure_byte_length"],
            "authorization.source_freeze_commit": control[
                "authorization_source_freeze_commit"
            ],
            "preflight.schema_version": "sporespore_qsdk_r24d76_behavior_preflight_v1",
            "preflight.gate_id": "QSDK-R24D76",
            "preflight.ok": True,
            "preflight.source_audit_and_runtime_preflight_count": 1,
            "preflight.worker_parse_count": 1,
            "operation_lock.acquired": True,
            "operation_lock.released": True,
            "operation_lock.role": "conformance",
            "operation_lock.test_only": False,
            "operation_lock.abandoned_owner_recovered": False,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physical_execution_count": 0,
            "physics_state_modified": False,
            "next_physical_invocation_authorized": True,
            "held_out": False,
            "same_identity_rerun_permitted": False,
            "prone_to_standing_claimed": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        "RECEIPT",
    )

    normalization = closure["projection_normalization"]
    omitted = normalization["exactly_omitted_fields"]
    source_projection = predecessor["physical_authorization"]
    normalized_projection = receipt["authorization"]["projection"]
    verify_exact_paths(
        normalization,
        {
            "source_authorization_field_count": len(source_projection),
            "normalized_projection_field_count": len(normalized_projection),
            "exactly_omitted_fields": [
                "maximum_outer_solver_steps_per_arm",
                "behavior_evaluator_invocation_count",
            ],
            "exactly_omitted_values.maximum_outer_solver_steps_per_arm": 1200,
            "exactly_omitted_values.behavior_evaluator_invocation_count": 1,
            "all_other_fields_exactly_matched": True,
            "maximum_outer_solver_steps_per_arm_enforced_by_bound_behavior_worker": True,
            "behavior_evaluator_invocation_count_enforced_by_bound_physical_supervisor": True,
            "projection_authority_weakened": False,
        },
        "PROJECTION_NORMALIZATION",
    )
    exact(
        {key: value for key, value in source_projection.items() if key not in omitted},
        normalized_projection,
        "NORMALIZED_PROJECTION_BINDING",
    )
    exact(
        (
            len(canonical_bytes(normalized_projection)),
            sha256(canonical_bytes(normalized_projection)),
            len(canonical_bytes(receipt["preflight"])),
            sha256(canonical_bytes(receipt["preflight"])),
        ),
        (
            control["projection_canonical_byte_length"],
            control["projection_canonical_sha256"],
            control["preflight_canonical_byte_length"],
            control["preflight_canonical_sha256"],
        ),
        "CANONICAL_COMPONENTS",
    )
    verify_exact_paths(
        control,
        {
            "command_invocation_count": 1,
            "receipt_count": 1,
            "schema_version": receipt["schema_version"],
            "status": "published_closure_authorization_control_passed",
            "completed_utc": receipt["completed_utc"],
            "operation_lock_acquired": True,
            "operation_lock_released": True,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physical_execution_count": 0,
            "physics_state_modified": False,
            "held_out": False,
            "same_exact_control_rerun_permitted": False,
        },
        "CONTROL_SUMMARY",
    )
    return closure, predecessor, receipt


def main() -> None:
    closure, _predecessor, _receipt = verify_control_shell()
    exact(
        closure["ledger_scope"],
        {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "published_closure_authorization_control",
            "question_class": "development",
        },
        "LEDGER_SCOPE",
    )
    verify_exact_paths(
        closure["decision"],
        {
            "result": (
                "positive_exact_published_r76_closure_loaded_by_production_"
                "supervisor_at_zero_world"
            ),
            "seed": 278151771,
            "held_out": False,
            "maximum_model_construction_attempt_count": 2,
            "maximum_model_construction_count": 2,
            "maximum_world_attempt_count": 2,
            "maximum_world_build_count": 2,
            "maximum_outer_steps_per_arm": 1200,
            "maximum_outer_solver_steps": 2400,
            "behavior_evaluator_invocation_count": 1,
            "new_behavior_threshold_count": 0,
            "new_empirical_threshold_count": 0,
            "new_margin_count": 0,
            "observed_physical_cohort_count": 0,
            "held_out_cohort_count": 0,
            "population_claim_count": 0,
        },
        "DECISION",
    )
    verify_boolean_partition(closure["decision"], TRUE, DECISION_FALSE, "DECISION_FLAGS")
    verify_boolean_partition(closure["claim_boundary"], TRUE, CLAIM_FALSE, "CLAIM")
    verify_exact_paths(
        closure,
        {
            "sdk_status.sdk1_completed_steps": 11,
            "sdk_status.sdk1_total_steps": 20,
            "next_boundary.gate_id": "QSDK-R24D76",
            "next_boundary.physical_question_declared": True,
            "next_boundary.authorized_world_count": 2,
            "next_boundary.maximum_outer_solver_steps": 2400,
            "next_boundary.behavior_evaluator_invocation_count": 1,
            "next_boundary.same_source_physical_attempt_limit": 1,
            "next_boundary.same_identity_rerun_permitted": False,
            "next_boundary.physical_execution_authorized": True,
        },
        "BOUNDARY",
    )

    relative = CLOSURE.relative_to(ROOT).as_posix()
    publication = git(
        ROOT, "log", "-1", "--diff-filter=A", "--format=%H", "--", relative
    )
    assert isinstance(publication, str)
    if publication:
        closure_blob = git(ROOT, "show", f"{publication}:{relative}", text=False)
    else:
        closure_blob = git(ROOT, "show", f":{relative}", text=False)
    assert isinstance(closure_blob, bytes)
    expected = {
        "r24d76_source_status": STATUS,
        "r24d76_published_closure_authorization_control_executed": True,
        "r24d76_authorization_control_source_commit": SOURCE,
        "r24d76_authorization_control_receipt_raw_sha256": (
            "sha256:ead76c1aeb0455bad82fd7c9234a22068223575547ac32f05c9aff8fe40041ad"
        ),
        "r24d76_authorization_control_receipt_byte_length": 3233,
        "r24d76_model_construction_count": 0,
        "r24d76_world_attempt_count": 0,
        "r24d76_world_build_count": 0,
        "r24d76_solver_step_count": 0,
        "r24d76_physical_execution_authorized": True,
        "r24d76_physical_attempt_consumed": False,
        "r24d76_physical_execution_blocked": False,
        "physical_execution_blocked_until_r24d76_published_closure_control": False,
    }
    for authority_relative in closure["live_authority_paths"]:
        if publication:
            authority_raw = git(
                ROOT, "show", f"{publication}:{authority_relative}", text=False
            )
            assert isinstance(authority_raw, bytes)
            authority = json.loads(authority_raw)
        else:
            authority = json.loads(
                (ROOT / authority_relative).read_text(encoding="utf-8")
            )
        records = records_with_key(
            authority, "r24d76_published_closure_authorization_control_executed"
        )
        exact(len(records), 1, f"LIVE_RECORD_COUNT:{authority_relative}")
        record = records[0]
        exact(
            {key: record[key] for key in expected},
            expected,
            f"LIVE_PROJECTION:{authority_relative}",
        )
        exact(
            record["r24d76_authorization_control_closure_raw_sha256"],
            sha256(closure_blob),
            f"LIVE_CLOSURE_HASH:{authority_relative}",
        )
        exact(
            record["r24d76_authorization_control_closure_byte_length"],
            len(closure_blob),
            f"LIVE_CLOSURE_LENGTH:{authority_relative}",
        )
    print(
        "QSDK_R24D76_GODOT_PUBLISHED_CLOSURE_AUTHORIZATION_CONTROL_CLOSURE_"
        "PASS invocations=1 receipts=1 files=1 preflight=1 parse=1 models=0 "
        "worlds=0 steps=0 physics=0 next=two_worlds_2400_steps sdk1=11/20"
    )


if __name__ == "__main__":
    main()
