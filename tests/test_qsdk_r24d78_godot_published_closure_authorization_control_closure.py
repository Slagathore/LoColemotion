"""Audit the one exact R78 post-publication authorization control."""

from __future__ import annotations

import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    exact,
    git,
    records_with_key,
    sha256,
    verify_boolean_partition,
    verify_exact_paths,
    verify_published_closure_authorization_control,
)

CLOSURE = ROOT / (
    "sdk/recovery/r24d78_godot_published_closure_"
    "authorization_control_closure_v1.json"
)
SOURCE = "a000c8a52902d5fb5fd2017a685f3b91fdb08fa8"
STATUS = (
    "closed_published_closure_authorization_control_positive_one_finite_"
    "host_real_recovery_pair_authorized"
)
PREDECESSOR_STATUS = (
    "closed_complete_zero_world_host_real_recovery_behavior_qualified_"
    "one_paired_development_attempt_authorized"
)
OMITTED = (
    "maximum_outer_solver_steps_per_arm",
    "behavior_evaluator_invocation_count",
)
CONSOLE_PATH = (
    "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/"
    "qsdk-r24d71-godot-solved-contact-telemetry/development-runtime-v3/"
    "19dc32b39400-b20323fd08a7/"
    "godot.windows.editor.dev.x86_64.console.exe"
)
CONSOLE_SHA256 = (
    "sha256:19dc32b39400d200b5e5273f541ac41aa72a82110bb2fd338726a7fd465e0fa8"
)
TRUE = (
    "zero_world_qualification_preserved",
    "exact_published_closure_loaded",
    "authorization_projection_exactly_matched",
    "selected_v3_runtime_identity_preserved",
    "complete_r78_preflight_reexecuted",
    "eight_current_zero_world_worker_contract_preserved",
    "focused_host_real_application_contract_preserved",
    "forced_failure_and_missing_switch_controls_preserved",
    "operation_lock_serialization_proven",
    "operation_lock_release_proven",
    "zero_physical_counts_proven",
    "one_finite_host_real_recovery_pair_authorized",
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


def main() -> None:
    closure, predecessor, receipt = (
        verify_published_closure_authorization_control(
            root=ROOT,
            closure_path=CLOSURE,
            schema_version=(
                "sporespore_qsdk_r24d78_godot_published_closure_"
                "authorization_control_closure_v1"
            ),
            gate_id="QSDK-R24D78",
            closure_status=STATUS,
            control_commit=SOURCE,
            control_subject=(
                "[recovery/godot] Close R78 qualification: authorize physical pair"
            ),
            predecessor_status=PREDECESSOR_STATUS,
            receipt_schema=(
                "sporespore_qsdk_r24d78_published_closure_"
                "authorization_control_v1"
            ),
            preflight_schema="sporespore_qsdk_r24d78_behavior_preflight_v1",
            projection_omitted_fields=OMITTED,
        )
    )
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
    source_projection = predecessor["physical_authorization"]
    normalized_projection = receipt["authorization"]["projection"]
    verify_exact_paths(
        closure["projection_normalization"],
        {
            "source_authorization_field_count": len(source_projection),
            "normalized_projection_field_count": len(normalized_projection),
            "exactly_omitted_fields": list(OMITTED),
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
        {key: value for key, value in source_projection.items() if key not in OMITTED},
        normalized_projection,
        "NORMALIZED_PROJECTION_BINDING",
    )
    verify_exact_paths(
        receipt,
        {
            "preflight.selected_console_path": CONSOLE_PATH,
            "preflight.selected_console_sha256": CONSOLE_SHA256,
            "preflight.selected_console_byte_length": 293376,
            "preflight.worker_parse_count": 1,
        },
        "RUNTIME_IDENTITY",
    )
    verify_exact_paths(
        closure,
        {
            "authorization_control.selected_console_path": CONSOLE_PATH,
            "authorization_control.selected_console_sha256": CONSOLE_SHA256,
            "authorization_control.selected_console_byte_length": 293376,
            "decision.result": (
                "positive_exact_published_r78_closure_loaded_by_production_"
                "supervisor_at_zero_world"
            ),
            "decision.seed": 278151771,
            "decision.maximum_model_construction_count": 2,
            "decision.maximum_world_build_count": 2,
            "decision.maximum_outer_solver_steps": 2400,
            "decision.behavior_evaluator_invocation_count": 1,
            "decision.new_behavior_threshold_count": 0,
            "decision.new_empirical_threshold_count": 0,
            "decision.new_margin_count": 0,
            "decision.observed_physical_cohort_count": 0,
            "decision.held_out_cohort_count": 0,
            "decision.population_claim_count": 0,
            "sdk_status.sdk1_completed_steps": 11,
            "next_boundary.gate_id": "QSDK-R24D78",
            "next_boundary.physical_question_declared": True,
            "next_boundary.authorized_world_count": 2,
            "next_boundary.maximum_outer_solver_steps": 2400,
            "next_boundary.behavior_evaluator_invocation_count": 1,
            "next_boundary.same_source_physical_attempt_limit": 1,
            "next_boundary.same_identity_rerun_permitted": False,
            "next_boundary.physical_execution_authorized": True,
        },
        "CLOSURE",
    )
    verify_boolean_partition(closure["decision"], TRUE, DECISION_FALSE, "DECISION")
    verify_boolean_partition(closure["claim_boundary"], TRUE, CLAIM_FALSE, "CLAIM")

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
        "r24d78_source_status": STATUS,
        "r24d78_published_closure_authorization_control_executed": True,
        "r24d78_authorization_control_source_commit": SOURCE,
        "r24d78_authorization_control_receipt_raw_sha256": (
            "sha256:278b98efa1a026f869389c823bc7e1daacbcaf89838216fa116398563a75c5b1"
        ),
        "r24d78_authorization_control_receipt_byte_length": 3598,
        "r24d78_model_construction_count": 0,
        "r24d78_world_attempt_count": 0,
        "r24d78_world_build_count": 0,
        "r24d78_solver_step_count": 0,
        "r24d78_physical_execution_authorized": True,
        "r24d78_physical_attempt_consumed": False,
        "r24d78_physical_execution_blocked": False,
        "physical_execution_blocked_until_r24d78_published_closure_control": False,
    }
    for authority_relative in closure["live_authority_paths"]:
        if publication:
            raw = git(ROOT, "show", f"{publication}:{authority_relative}", text=False)
            assert isinstance(raw, bytes)
            authority = json.loads(raw)
        else:
            authority = json.loads(
                (ROOT / authority_relative).read_text(encoding="utf-8")
            )
        records = records_with_key(
            authority, "r24d78_published_closure_authorization_control_executed"
        )
        exact(len(records), 1, f"LIVE_RECORD_COUNT:{authority_relative}")
        record = records[0]
        exact(
            {key: record[key] for key in expected},
            expected,
            f"LIVE_PROJECTION:{authority_relative}",
        )
        exact(
            record["r24d78_authorization_control_closure_raw_sha256"],
            sha256(closure_blob),
            f"LIVE_CLOSURE_HASH:{authority_relative}",
        )
        exact(
            record["r24d78_authorization_control_closure_byte_length"],
            len(closure_blob),
            f"LIVE_CLOSURE_LENGTH:{authority_relative}",
        )
    print(
        "QSDK_R24D78_GODOT_PUBLISHED_CLOSURE_AUTHORIZATION_CONTROL_CLOSURE_"
        "PASS invocations=1 receipts=1 files=1 preflight=1 runtime=19dc32 "
        "models=0 worlds=0 steps=0 physics=0 next=two_worlds_2400_steps "
        "sdk1=11/20"
    )


if __name__ == "__main__":
    main()
