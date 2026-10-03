"""Audit the finite positive R24D55 Rapier recovery result without replaying it."""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError,
    exact,
    git,
    load,
    records_with_key,
    require,
    sha256,
    verify_exact_paths,
    verify_patched_rapier_runner_attempt,
    verify_rapier_recovery_v3_arm_capture,
    verify_retained_commit,
)

CLOSURE = ROOT / (
    "sdk/recovery/"
    "r24d55_rapier_terminal_prefix_recovery_development_positive_closure_v1.json"
)
CONTRACT = ROOT / "sdk/recovery/r24d55_rapier_terminal_prefix_recovery_contract_v1.json"
INTEGRATION = ROOT / (
    "sdk/recovery/r24d53_rapier_staging_transport_smoke_positive_closure_v1.json"
)
RELEASE = ROOT / "sdk/release/quadruped_release_contract.json"
SUPPORT = ROOT / "sdk/release/quadruped_support_matrix.json"
MAPPING = ROOT / "sdk/release/quadruped_sdk1_milestone_mapping_v1.json"
SOURCE = "5116b28e90ec9850067d41a89642b3185ea90a90"
STATUS = (
    "closed_consumed_valid_complete_exact_nominal_rapier_terminal_prefix_"
    "recovery_development_positive"
)


def audit() -> None:
    closure = load(CLOSURE)
    exact(
        (
            closure["schema_version"],
            closure["gate_id"],
            closure["closure_status"],
            closure["question_class"],
            closure["physical_question_declared"],
        ),
        (
            "sporespore_qsdk_r24d55_rapier_terminal_prefix_recovery_"
            "development_positive_closure_v1",
            "QSDK-R24D55",
            STATUS,
            "development",
            True,
        ),
        "CLOSURE_IDENTITY",
    )
    for key in (
        "superiority_question_declared",
        "equivalence_or_non_inferiority_question_declared",
        "population_inference_declared",
    ):
        exact(closure[key], False, f"CLOSURE_{key.upper()}")

    source = closure["source"]
    verify_retained_commit(ROOT, SOURCE, source["parent_commit"])
    exact(source["commit"], SOURCE, "SOURCE_COMMIT")
    exact(git(ROOT, "rev-parse", f"{SOURCE}^{{tree}}"), source["tree"], "SOURCE_TREE")
    exact(
        git(ROOT, "show", "-s", "--format=%s", SOURCE),
        source["subject"],
        "SOURCE_SUBJECT",
    )
    exact(
        sha256(CONTRACT.read_bytes()),
        source["behavior_contract_raw_sha256"],
        "CONTRACT",
    )
    exact(
        sha256(INTEGRATION.read_bytes()),
        source["development_integration_closure_raw_sha256"],
        "INTEGRATION_CLOSURE",
    )

    attempt, receipt, result = verify_patched_rapier_runner_attempt(
        root=ROOT,
        closure=closure,
    )
    physical = closure["physical_attempt"]
    exact(
        sum(item["byte_length"] for item in physical["retained_artifacts"]),
        physical["retained_total_byte_length"],
        "RETAINED_TOTAL_BYTES",
    )
    exact(attempt["started_utc"], physical["started_utc"], "ATTEMPT_STARTED")
    exact(receipt["completed_utc"], physical["completed_utc"], "ATTEMPT_COMPLETED")

    verify_exact_paths(
        result,
        {
            "ok": True,
            "result_may_satisfy_r24d55": True,
            "question_class": "development",
            "actual_total_outer_steps": 1219,
            "candidate_outer_steps": 967,
            "matched_zero_outer_steps": 252,
            "complete_native_capture_retained": True,
            "evaluator_input_is_exact_terminal_prefix": True,
            "post_terminal_observations_excluded_from_evaluator": True,
            "projection_world_build_count": 0,
            "projection_solver_step_count": 0,
            "projection_physics_state_modified": False,
            "prone_to_standing_claimed": True,
            "repeatability_rate_claimed": False,
            "population_claimed": False,
            "cross_engine_recovery_claimed": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        "RESULT",
    )

    candidate_projection = result["candidate"]
    zero_projection = result["matched_zero_command"]
    candidate = verify_rapier_recovery_v3_arm_capture(
        projection=candidate_projection,
        expected_arm_kind="candidate_command",
        captured_observation_count=967,
        terminal_prefix_observation_count=787,
    )
    zero = verify_rapier_recovery_v3_arm_capture(
        projection=zero_projection,
        expected_arm_kind="matched_zero_command",
        captured_observation_count=252,
        terminal_prefix_observation_count=252,
    )
    observed = closure["observed_result"]
    exact(
        (
            candidate_projection["captured_trace_v3_sha256"],
            candidate_projection["evaluator_terminal_prefix_trace_v3_sha256"],
            zero_projection["captured_trace_v3_sha256"],
            zero_projection["evaluator_terminal_prefix_trace_v3_sha256"],
        ),
        (
            observed["candidate"]["captured_trace_v3_sha256"],
            observed["candidate"]["evaluator_terminal_prefix_trace_v3_sha256"],
            observed["matched_zero_command"]["captured_trace_v3_sha256"],
            observed["matched_zero_command"][
                "evaluator_terminal_prefix_trace_v3_sha256"
            ],
        ),
        "TRACE_DIGESTS",
    )

    exact(
        (
            candidate["final_phase_v3"],
            candidate["terminal_failure_code_v3"],
            zero["final_phase_v3"],
            zero["terminal_failure_code_v3"],
        ),
        (
            "complete",
            None,
            "failed",
            "phase_timeout:establish_distal_support",
        ),
        "ARM_TERMINALS",
    )
    candidate_receipts = candidate["v2_v3_phase_prefix_receipts"]
    zero_receipts = zero["v2_v3_phase_prefix_receipts"]
    exact(
        sum(item["terminal_transition_divergence"] for item in candidate_receipts),
        1,
        "CANDIDATE_DIVERGENCE_COUNT",
    )
    exact(
        sum(item["terminal_transition_divergence"] for item in zero_receipts),
        0,
        "ZERO_DIVERGENCE_COUNT",
    )
    verify_exact_paths(
        candidate_receipts[-1],
        {
            "semantic_step": 787,
            "v2_prior_phase": "stance_dwell",
            "v2_next_phase": "stance_dwell",
            "v3_prior_phase": "stance_dwell",
            "v3_next_phase": "complete",
            "v3_terminal": True,
            "terminal_transition_divergence": True,
        },
        "CANDIDATE_TERMINAL_RECEIPT",
    )
    verify_exact_paths(
        zero_receipts[-1],
        {
            "semantic_step": 252,
            "v3_prior_phase": "establish_distal_support",
            "v3_next_phase": "failed",
            "v3_terminal": True,
            "terminal_transition_divergence": False,
        },
        "ZERO_TERMINAL_RECEIPT",
    )

    terminal = candidate["trace_v3"]["observations"][786]
    torso = next(
        item
        for item in terminal["ordered_body_clearance_observations"]
        if item["body_id"] == "torso"
    )
    exact(terminal["semantic_step"], 787, "TERMINAL_STEP")
    exact(
        terminal["state"]["base_pose_world"]["position_m"]["y"],
        0.3454165756702423,
        "TERMINAL_TORSO_HEIGHT",
    )
    exact(
        torso["minimum_nonfoot_clearance_m"],
        0.2673356533050537,
        "TERMINAL_TORSO_CLEARANCE",
    )
    require(
        not torso["nonfoot_contact_present"]
        and not torso["ventral_surface_contact"]
        and all(
            item["ordinary_unilateral_contact"]
            for item in terminal["ordered_foot_bearing_observations"]
        )
        and all(
            item["bears_support"]
            for item in terminal["state"]["ordered_contact_observations"]
        )
        and sum(terminal["external_interventions"].values()) == 0,
        "TERMINAL_PHYSICS",
    )
    exact(
        candidate["v3_prefix_aggregation_receipts"][786]["absolute_residual_j"],
        1.8697292034630664e-6,
        "TERMINAL_ENERGY_RESIDUAL",
    )

    evaluation = result["evaluation"]
    verify_exact_paths(
        evaluation,
        {
            "support_status": "supported_exact",
            "verdict": "physical_development_passed",
            "candidate_trace.accepted_observation_count": 787,
            "candidate_trace.observation_count": 787,
            "candidate_trace.completed": True,
            "candidate_trace.final_phase": "complete",
            "matched_zero_command_trace.accepted_observation_count": 252,
            "matched_zero_command_trace.observation_count": 252,
            "matched_zero_command_trace.completed": False,
            "matched_zero_command_trace.final_phase": "failed",
            "matched_zero_command_trace.terminal_failure_code": (
                "phase_timeout:establish_distal_support"
            ),
            "physical_development_trace_valid": True,
            "candidate_physical_path_completed": True,
            "matched_zero_command_physical_control_failed_to_complete": True,
            "all_negative_control_requirements_enforced": True,
            "initial_state_identity_matched": True,
            "physical_result": True,
            "prone_to_standing_claimed": True,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        "FROZEN_EVALUATION",
    )

    decision = closure["decision"]
    verify_exact_paths(
        decision,
        {
            "paired_development_attempt_consumed_for_exact_source": True,
            "execution_complete": True,
            "physical_question_valid": True,
            "decision_positive": True,
            "exact_nominal_rapier_prone_to_standing_observed": True,
            "exact_nominal_rapier_prone_to_standing_claimed_by_frozen_evaluator": True,
            "same_source_or_identity_rerun_permitted": False,
            "r24d55_may_be_requalified": False,
            "all_engine_canonical_prone_to_standing_claimed": False,
            "sdk1_m19_satisfied": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        "DECISION",
    )
    exact(
        closure["sdk_status"],
        {
            "sdk1_milestone_advanced": False,
            "sdk1_completed_steps": 11,
            "sdk1_total_steps": 20,
            "full_program_completed_steps": 11,
            "full_program_total_steps": 25,
        },
        "SDK_STATUS",
    )
    verify_exact_paths(
        closure["next_boundary"],
        {
            "next_successor_campaign_declared": False,
            "physical_execution_authorized": False,
            "maximum_physical_steps_authorized": 0,
            "same_identity_rerun_permitted": False,
            "held_out_cells_remain_sealed": True,
            "all_engine_prone_to_standing_claimed": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        "NEXT_BOUNDARY",
    )

    closure_digest = sha256(
        CLOSURE.read_text(encoding="utf-8").replace("\r\n", "\n").encode()
    )
    for ledger_path in (RELEASE, SUPPORT):
        ledger = json.loads(ledger_path.read_text(encoding="utf-8"))
        records = records_with_key(ledger, "r24d55_question_class")
        exact(len(records), 1, f"LEDGER_RECORD_COUNT:{ledger_path.name}")
        record = records[0]
        exact(
            (
                record["r24d55_source_status"],
                record["r24d55_physical_closure_raw_sha256"],
                record["r24d55_paired_development_authorized"],
                record["r24d55_physical_attempted"],
                record["r24d55_behavior_observed"],
                record["r24d55_physical_development_trace_valid"],
                record["r24d55_physical_result_positive"],
                record["r24d55_exact_nominal_rapier_prone_to_standing_observed"],
                record["r24d55_same_source_development_may_be_rerun"],
                record["r24d55_authorized_world_count"],
                record["r24d55_maximum_total_outer_steps"],
            ),
            (
                STATUS,
                closure_digest,
                False,
                True,
                True,
                True,
                True,
                True,
                False,
                0,
                0,
            ),
            f"LEDGER_R55:{ledger_path.name}",
        )
    mapping = load(MAPPING)
    exact(
        mapping["full_program_authority"]["release_contract_raw_sha256"],
        sha256(RELEASE.read_bytes()),
        "MAPPING_RELEASE",
    )
    exact(
        mapping["full_program_authority"]["support_matrix_raw_sha256"],
        sha256(SUPPORT.read_bytes()),
        "MAPPING_SUPPORT",
    )

    print(
        "QSDK_R24D55_RAPIER_TERMINAL_PREFIX_RECOVERY_POSITIVE_CLOSURE_PASS "
        "files=7 worlds=2 steps=1219 invariants=1219 staging=1219 "
        "candidate=complete@787 captured=967 tail=180 zero=failed@252 "
        "evaluation=physical_development_passed trace_valid=true "
        "rapier_prone=true all_engine_prone=false consumed=true sdk1=11/20"
    )


if __name__ == "__main__":
    try:
        audit()
    except (
        ClosureAuditError,
        OSError,
        KeyError,
        TypeError,
        ValueError,
        StopIteration,
        subprocess.SubprocessError,
    ) as error:
        print(
            "QSDK_R24D55_RAPIER_TERMINAL_PREFIX_RECOVERY_POSITIVE_CLOSURE_FAIL "
            f"{error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
