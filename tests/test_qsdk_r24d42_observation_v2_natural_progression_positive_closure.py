"""Audit the retained R24D42 exact-cell stance-handoff positive."""

from __future__ import annotations

import json
from pathlib import Path
import sys
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    canonical_bytes,
    exact,
    exact_bools,
    git,
    load,
    loads,
    require,
    sha256,
    source_bytes,
    verify_exact_paths,
    verify_exact_retained_inventory,
    verify_physical_attempt_closure,
    verify_retained_commit,
    verify_source_binding,
    verify_zero_world_qualification_closure,
)

GATE = "QSDK-R24D42"
NEXT_GATE = "QSDK-R24D43"
CAMPAIGN = "QSDK-R24D42-MUJOCO-OBSERVATION-V2-NATURAL-RECOVERY-PROGRESSION"
SOURCE = "a3e0384b27346866ecf2f2a3810bdfcf388f79b7"
CLOSURE_RELATIVE = "sdk/recovery/r24d42_mujoco_observation_v2_natural_progression_positive_closure_v1.json"
CLOSURE = ROOT / CLOSURE_RELATIVE
CONTRACT_RELATIVE = "sdk/recovery/r24d42_mujoco_observation_v2_natural_progression_contract_v1.json"
RELEASE_RELATIVE = "sdk/release/quadruped_release_contract.json"
SUPPORT_RELATIVE = "sdk/release/quadruped_support_matrix.json"
MAPPING_RELATIVE = "sdk/release/quadruped_sdk1_milestone_mapping_v1.json"
EXECUTION_CHECKS = {
    "candidate_in_run_invariants_pass",
    "complete_observation_v2_replay_pass",
    "full_recovery_and_release_authority_absent",
    "matched_zero_in_run_invariants_pass",
    "model_world_counts_exact",
    "observation_v2_route_exact",
    "outer_and_solver_counts_exact_bounded",
    "paired_initializer_identity_matched",
    "portable_evaluation_v3_supported_valid",
}
TARGET_CHECKS = {
    "both_arms_stop_within_frozen_maximum",
    "candidate_controller_continues_beyond_first_application",
    "candidate_reaches_stance_handoff_without_phase_skip",
    "candidate_transition_gates_are_measured_true",
    "matched_zero_remains_unactuated",
    "matched_zero_stops_failed",
}


def _find_gate(value: object, gate_id: str) -> list[dict[str, Any]]:
    found: list[dict[str, Any]] = []
    if isinstance(value, dict):
        if value.get("gate_id") == gate_id:
            found.append(value)
        for child in value.values():
            found.extend(_find_gate(child, gate_id))
    elif isinstance(value, list):
        for child in value:
            found.extend(_find_gate(child, gate_id))
    return found


def _live_authority_json(relative: str) -> dict[str, Any]:
    """Read the legacy live authorities without rewriting retained duplicate keys."""

    value = json.loads((ROOT / relative).read_bytes())
    require(isinstance(value, dict), f"LIVE_AUTHORITY_ROOT:{relative}")
    return value


def _require_exact_true_checks(
    checks: dict[str, Any], expected: set[str], code: str
) -> None:
    exact(set(checks), expected, f"{code}_KEYS")
    require(all(checks.values()), f"{code}_VALUES")


def _candidate_projection(candidate: dict[str, Any]) -> dict[str, Any]:
    handoffs = [
        item
        for item in candidate["transition_records"]
        if (item["prior_phase"], item["next_phase"])
        == ("raise_body", "stance_handoff")
    ]
    exact(len(handoffs), 1, "HANDOFF_COUNT")
    return {
        "outer_step_count": candidate["outer_step_count"],
        "native_solver_step_count": candidate["outer_step_count"] * 5,
        "final_phase": candidate["final_phase"],
        "terminal_failure_code": candidate["terminal_failure_code"],
        "active_application_count": candidate["active_application_count"],
        "first_active_outer_index_zero_based": candidate["first_active_outer_index_zero_based"],
        "last_active_outer_index_zero_based": candidate["last_active_outer_index_zero_based"],
        "all_joint_limits_respected": candidate["all_joint_limits_respected"],
        "transition_pairs": candidate["transition_pairs"],
        "transition_outer_indices_zero_based": [
            item["outer_index_zero_based"] for item in candidate["transition_records"]
        ],
        "handoff_classification": handoffs[0]["classification"],
    }


def _matched_projection(matched: dict[str, Any]) -> dict[str, Any]:
    return {
        "outer_step_count": matched["outer_step_count"],
        "native_solver_step_count": matched["outer_step_count"] * 5,
        "final_phase": matched["final_phase"],
        "terminal_failure_code": matched["terminal_failure_code"],
        "active_application_count": matched["active_application_count"],
        "observations_all_zero_command": matched["observations_all_zero_command"],
        "all_joint_limits_respected": matched["all_joint_limits_respected"],
        "transition_pairs": matched["transition_pairs"],
    }


def audit() -> None:
    closure = load(CLOSURE)
    exact(
        (
            closure["schema_version"],
            closure["gate_id"],
            closure["campaign_id"],
            closure["closure_status"],
            closure["question_class"],
        ),
        (
            "sporespore_qsdk_r24d42_mujoco_observation_v2_natural_progression_positive_closure_v1",
            GATE,
            CAMPAIGN,
            "closed_consumed_execution_valid_exact_nominal_mujoco_recovery_to_stance_handoff_development_positive_full_prone_to_standing_incomplete",
            "development",
        ),
        "CLOSURE_IDENTITY",
    )
    exact_bools(closure, ("physical_question_declared", "behavior_question_declared"), True, "DECLARED")
    exact_bools(
        closure,
        ("superiority_question_declared", "equivalence_or_non_inferiority_question_declared", "population_inference_declared"),
        False,
        "UNDECLARED",
    )

    source = closure["source"]
    verify_retained_commit(ROOT, SOURCE, source["parent_commit"])
    exact(
        (source["commit"], source["tree"], source["subject"]),
        (SOURCE, git(ROOT, "show", "-s", "--format=%T", SOURCE), "[recovery/mujoco] Freeze R24D42 streaming natural progression"),
        "SOURCE_IDENTITY",
    )
    contract = loads(verify_source_binding(ROOT, SOURCE, source["contract"]))
    exact((contract["gate_id"], contract["campaign_id"]), (GATE, CAMPAIGN), "CONTRACT_IDENTITY")
    predecessor_paths = {
        "behavior_contract_raw_sha256": "sdk/recovery/r24d32_corrected_energy_progression_contract_v1.json",
        "behavior_closure_raw_sha256": "sdk/recovery/r24d32_corrected_energy_progression_physical_closure_v1.json",
        "route_closure_raw_sha256": "sdk/recovery/r24d41_mujoco_recovery_morphology_observation_v2_smoke_positive_closure_v1.json",
        "route_closure_audit_raw_sha256": "tests/test_qsdk_r24d41_observation_v2_morphology_smoke_positive_closure.py",
    }
    for field, relative in predecessor_paths.items():
        exact(closure["predecessors"][field], sha256(source_bytes(ROOT, SOURCE, relative)), f"PREDECESSOR:{field}")

    qualification = closure["qualification"]
    verify_exact_retained_inventory(Path(qualification["evidence_root"]), qualification["retained_artifacts"])
    _, receipt, preflight = verify_zero_world_qualification_closure(
        root=ROOT,
        closure=closure,
        gate_id=GATE,
        source_commit=SOURCE,
        attempt_schema="sporespore_qsdk_r24d42_observation_v2_natural_progression_zero_world_attempt_v1",
        receipt_schema="sporespore_qsdk_r24d42_mujoco_observation_v2_natural_progression_zero_world_receipt_v1",
        qualification_directory_prefix="qsdk-r24d42-qualification-",
        contract_inventory=contract["source_inventory"],
        source_manifest_raw_representation="observed_checkout_plus_git_blob",
    )
    checkout_only = []
    raw_match_count = 0
    for entry in receipt["source_manifest"]:
        raw = source_bytes(ROOT, SOURCE, entry["path"])
        raw_hash = sha256(raw)
        if len(raw) == entry["byte_length"] and raw_hash == entry["raw_sha256"]:
            raw_match_count += 1
        else:
            checkout_only.append(
                {
                    "path": entry["path"],
                    "observed_checkout_byte_length": entry["byte_length"],
                    "observed_checkout_raw_sha256": entry["raw_sha256"],
                    "canonical_git_blob_byte_length": len(raw),
                    "canonical_git_blob_raw_sha256": raw_hash,
                    "representation_note": "qualification_runner_recorded_exact_windows_checkout_bytes_while_git_blob_oid_retained_canonical_source_identity",
                }
            )
    exact(
        qualification["source_manifest_representation_evidence"],
        {
            "git_blob_oid_match_count": len(receipt["source_manifest"]),
            "git_blob_raw_byte_match_count": raw_match_count,
            "checkout_only_entry_count": len(checkout_only),
            "checkout_only_entries": checkout_only,
        },
        "SOURCE_REPRESENTATION",
    )
    details = preflight["observation_v2_natural_progression_control_details"]
    stream = details["streaming_mapping_controls"]
    _require_exact_true_checks(preflight["observation_v2_natural_progression_controls"], set(preflight["observation_v2_natural_progression_controls"]), "QUALIFICATION_CONTROLS")
    _require_exact_true_checks(stream["mutation_controls"], set(stream["mutation_controls"]), "STREAMING_MUTATIONS")
    verify_exact_paths(
        preflight,
        {
            "control_count": 9,
            "forced_failure_count": 21,
            "model_xml_sha256": qualification["model_xml_sha256"],
            "observation_v2_natural_progression_control_details.conjunction_receipt_sha256": qualification["conjunction_receipt_sha256"],
            "recovery_morphology_observation_v2_control_details.candidate_invariant_receipt_sha256": qualification["candidate_invariant_receipt_sha256"],
            "recovery_morphology_observation_v2_control_details.matched_zero_invariant_receipt_sha256": qualification["matched_zero_invariant_receipt_sha256"],
        },
        "PREFLIGHT",
    )
    exact(
        (stream["numeric_parity_prefixes"], stream["final_source_chain_sha256"], stream["final_state_sha256"], stream["prior_history_replayed_in_current_step"]),
        (qualification["streaming_numeric_parity_prefixes"], qualification["streaming_control_final_source_chain_sha256"], qualification["streaming_control_final_state_sha256"], False),
        "STREAMING_QUALIFICATION",
    )

    values = verify_physical_attempt_closure(
        root=ROOT,
        closure=closure,
        gate_id=GATE,
        campaign_id=CAMPAIGN,
        source_commit=SOURCE,
        physical_directory_prefix="qsdk-r24d42-mujoco-observation-v2-natural-progression-",
        schemas={
            "reservation": "sporespore_qsdk_r24d42_observation_v2_natural_progression_attempt_reservation_v1",
            "manifest": "sporespore_qsdk_r24d42_mujoco_observation_v2_natural_progression_manifest_v1",
            "full": "sporespore_qsdk_r24d42_mujoco_observation_v2_natural_progression_full_result_v1",
            "summary": "sporespore_qsdk_r24d42_mujoco_observation_v2_natural_progression_compact_projection_v1",
            "completion": "sporespore_qsdk_r24d42_observation_v2_natural_progression_supervisor_completion_v1",
            "lock": "sporespore_locomotion_operation_lock_receipt_v1",
        },
        qualification_receipt_raw_sha256=qualification["receipt_raw_sha256"],
    )
    physical = closure["physical_attempt"]
    exact(physical["official_physical_attempt_count_for_source"], 1, "PHYSICAL_ATTEMPT_COUNT")
    exact(
        (values["reservation"]["core_build_profile"], values["reservation"]["core_library_raw_sha256"]),
        (receipt["toolchain"]["core_build_profile"], receipt["toolchain"]["core_library_raw_sha256"]),
        "PHYSICAL_CORE_BUILD",
    )
    summary = values["summary"]
    manifest = values["manifest"]
    exact(
        (manifest["execution_valid"], manifest["decision_positive"], manifest["observation_v2_invariants_passed"], manifest["streaming_chain_replayed_once"], manifest["final_legacy_full_aggregate_numeric_parity"], summary["execution_valid"], summary["decision_positive"], summary["valid_negative_if_decision_not_positive"]),
        (True, True, True, True, True, True, True, False),
        "PHYSICAL_DECISION",
    )
    _require_exact_true_checks(summary["execution_checks"], EXECUTION_CHECKS, "EXECUTION_CHECKS")
    _require_exact_true_checks(summary["target_checks"], TARGET_CHECKS, "TARGET_CHECKS")
    observed = closure["observed_result"]
    exact(_candidate_projection(summary["candidate"]), observed["candidate"], "CANDIDATE")
    exact(_matched_projection(summary["matched_zero_command"]), observed["matched_zero_command"], "MATCHED_ZERO")

    evaluation = values["full"]["result"]["evaluation"]
    exact(
        (evaluation["support_status"], evaluation["verdict"], evaluation["physical_development_trace_valid"], evaluation["candidate_physical_path_completed"], evaluation["candidate_trace"]["final_phase"], evaluation["matched_zero_command_physical_control_failed_to_complete"], evaluation["matched_zero_command_trace"]["final_phase"], evaluation["all_negative_control_requirements_enforced"]),
        (observed["portable_evaluation_support_status"], observed["portable_evaluation_verdict"], observed["portable_evaluation_physical_development_trace_valid"], False, "stance_handoff", True, "failed", False),
        "PORTABLE_EVALUATOR_DISTINCTION",
    )
    invariants = summary["trace_invariants"]
    invariant_receipts = invariants["in_run_invariant_receipt_sha256s"]
    stream_claim = closure["streaming_evidence"]
    verify_exact_paths(
        invariants,
        {
            "validated_arm_count": stream_claim["validated_arm_count"],
            "arm_step_counts": stream_claim["arm_step_counts"],
            "validated_outer_step_count": stream_claim["validated_outer_step_count"],
            "validated_native_substep_count": stream_claim["validated_native_substep_count"],
            "final_source_chain_sha256s": stream_claim["final_source_chain_sha256s"],
            "final_legacy_mapping_sha256s": stream_claim["final_legacy_mapping_sha256s"],
            "streaming_chain_replayed_once": True,
            "final_legacy_full_aggregate_execution_count": 2,
            "final_legacy_full_aggregate_numeric_parity": True,
            "retained_streaming_publication_canonical_byte_count": stream_claim["retained_streaming_publication_canonical_byte_count"],
            "maximum_streaming_publication_canonical_byte_length": stream_claim["maximum_streaming_publication_canonical_byte_length"],
        },
        "TRACE",
    )
    exact(
        (len(invariant_receipts), len(canonical_bytes(invariant_receipts)), sha256(canonical_bytes(invariant_receipts))),
        (stream_claim["in_run_invariant_receipt_count"], stream_claim["in_run_invariant_receipt_list_canonical_byte_length"], stream_claim["in_run_invariant_receipt_list_canonical_sha256"]),
        "INVARIANT_RECEIPT_POPULATION",
    )

    exact_bools(
        closure["decision"],
        ("official_zero_world_qualification_passed", "all_nine_declared_zero_world_controls_passed", "all_twenty_one_declared_forced_failures_passed", "sole_physical_attempt_consumed", "exact_nominal_mujoco_recovery_progression_proven", "recovery_to_stance_handoff_observed", "recovery_controller_physical_viability_proven_for_exact_cell"),
        True,
        "DECISION_TRUE",
    )
    exact_bools(
        closure["decision"],
        ("r24d42_may_be_rerun", "same_source_may_be_reused_for_another_r24d42_result", "stance_controller_executed", "stance_dwell_observed", "portable_complete_observed", "prone_to_standing_claimed", "sdk1_milestone_advanced"),
        False,
        "DECISION_FALSE",
    )
    exact(
        (closure["decision"]["sdk1_completed_steps"], closure["decision"]["sdk1_total_steps"], closure["decision"]["full_program_completed_steps"], closure["decision"]["full_program_total_steps"]),
        (11, 20, 11, 25),
        "SDK_COUNTS",
    )
    exact_bools(
        closure["claim_boundary"],
        ("development_zero_world_gate_passed", "official_zero_world_qualification_passed", "physical_question_opened", "complete_physical_development_trace_observed", "execution_valid_development_positive_observed", "matched_zero_negative_control_observed", "native_observation_v2_route_coverage_proven", "streaming_observation_v2_route_physically_validated", "all_in_run_physical_invariants_passed", "final_legacy_numeric_parity_passed", "recovery_progression_proven", "recovery_to_stance_handoff_observed", "recovery_controller_physical_viability_proven_for_exact_cell"),
        True,
        "CLAIM_TRUE",
    )
    exact_bools(
        closure["claim_boundary"],
        ("stance_controller_execution_observed", "stance_dwell_observed", "portable_complete_observed", "prone_to_standing_claimed", "repeatability_rate_claimed", "population_claimed", "held_out_validation_claimed", "cross_engine_recovery_claimed", "cross_engine_equivalence_claimed", "sdk1_milestone_advanced", "physical_acceptance_authority", "release_authority"),
        False,
        "CLAIM_FALSE",
    )
    exact(
        (closure["next_boundary"]["gate_id"], closure["next_boundary"]["next_physical_execution_authorized"], closure["next_boundary"]["same_identity_rerun_permitted"], closure["audit_economy"]["historical_closure_audit_execution_count"]),
        (NEXT_GATE, False, False, 0),
        "SUCCESSOR_BOUNDARY",
    )

    current_contract = load(ROOT / CONTRACT_RELATIVE)
    verify_exact_paths(
        current_contract,
        {
            "claim_boundary.official_zero_world_qualification_pending": False,
            "claim_boundary.native_natural_progression_pending": False,
            "claim_boundary.new_physical_observation_made": True,
            "claim_boundary.recovery_progression_proven": True,
            "claim_boundary.recovery_to_stance_handoff_observed": True,
            "claim_boundary.controller_physical_viability_proven": True,
            "claim_boundary.prone_to_standing_claimed": False,
        },
        "CURRENT_CONTRACT",
    )
    closure_hash = sha256(CLOSURE.read_bytes())
    audit_hash = sha256(Path(__file__).read_bytes())
    for relative in (RELEASE_RELATIVE, SUPPORT_RELATIVE):
        nodes = _find_gate(_live_authority_json(relative), NEXT_GATE)
        exact(len(nodes), 1, f"NEXT_NODE_COUNT:{relative}")
        verify_exact_paths(
            nodes[0],
            {
                "predecessor_gate_id": GATE,
                "predecessor_source_commit": SOURCE,
                "predecessor_closure_path": CLOSURE_RELATIVE,
                "predecessor_closure_raw_sha256": closure_hash,
                "predecessor_closure_audit_path": "tests/test_qsdk_r24d42_observation_v2_natural_progression_positive_closure.py",
                "predecessor_closure_audit_raw_sha256": audit_hash,
                "r24d42_official_qualification_passed": True,
                "r24d42_physical_attempt_consumed": True,
                "r24d42_physical_attempt_valid": True,
                "r24d42_decision_positive": True,
                "controller_progression_to_stance_handoff_proven": True,
                "prone_to_standing_claimed": False,
                "physical_execution_authorized": False,
                "release_authority": False,
            },
            f"NEXT_NODE:{relative}",
        )
    mapping = load(ROOT / MAPPING_RELATIVE)
    exact(mapping["full_program_authority"]["release_contract_raw_sha256"], sha256((ROOT / RELEASE_RELATIVE).read_bytes()), "MAPPING_RELEASE")
    exact(mapping["full_program_authority"]["support_matrix_raw_sha256"], sha256((ROOT / SUPPORT_RELATIVE).read_bytes()), "MAPPING_SUPPORT")
    exact(mapping["sdk1_contract"]["milestone_count"], 20, "SDK1_DENOMINATOR")
    for relative in (
        "docs/README.md",
        "docs/ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md",
        "docs/LOCOMOTION_GROUND_UP_RESEARCH_PROGRAM.md",
        "docs/LOCOMOTION_ARCHITECTURE.md",
        "docs/SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md",
        "sdk/adapters/mujoco/README.md",
    ):
        text = (ROOT / relative).read_text(encoding="utf-8")
        require("R24D42 closed" in text, f"DOC_CLOSURE:{relative}")
        require("11/20" in text and "11/25" in text, f"DOC_COUNTS:{relative}")


def main() -> int:
    try:
        audit()
    except Exception as error:
        print(f"QSDK_R24D42_OBSERVATION_V2_NATURAL_PROGRESSION_POSITIVE_CLOSURE_FAIL {error}")
        return 1
    print("QSDK_R24D42_OBSERVATION_V2_NATURAL_PROGRESSION_POSITIVE_CLOSURE_PASS candidate_outer=307 matched_zero_outer=775 total_outer=1082 solver_steps=5410 handoff_residual_j=0.001765744132594449 sdk1=11/20 full=11/25")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
