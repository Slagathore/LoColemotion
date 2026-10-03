"""Audit the retained R24D44 exact nominal MuJoCo prone-to-standing positive."""

from __future__ import annotations

from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    exact,
    exact_bools,
    exact_true_checks,
    find_gate_nodes,
    git,
    load,
    load_legacy_live_authority,
    loads,
    require,
    sha256,
    verify_exact_paths,
    verify_physical_attempt_closure,
    verify_retained_commit,
    verify_source_binding,
    verify_stance_completion_physical_positive,
    verify_zero_world_qualification_closure,
)


GATE = "QSDK-R24D44"
NEXT_GATE = "QSDK-R24D45"
CAMPAIGN = "QSDK-R24D44-MUJOCO-EXCLUSIVE-STANCE-COMPLETION-LAUNCH-REPAIR"
SOURCE = "914f5be5ea232b94566579978b821ba5a2ec37af"
CLOSURE_RELATIVE = (
    "sdk/recovery/"
    "r24d44_stance_completion_launcher_compatibility_positive_closure_v1.json"
)
AUDIT_RELATIVE = (
    "tests/test_qsdk_r24d44_stance_completion_launcher_compatibility_"
    "positive_closure.py"
)
RELEASE_RELATIVE = "sdk/release/quadruped_release_contract.json"
SUPPORT_RELATIVE = "sdk/release/quadruped_support_matrix.json"
MAPPING_RELATIVE = "sdk/release/quadruped_sdk1_milestone_mapping_v1.json"
CLOSURE = ROOT / CLOSURE_RELATIVE
EXECUTION_CHECKS = {
    "candidate_in_run_checks_pass",
    "complete_observation_v2_replay_pass",
    "finite_development_claim_boundary_preserved",
    "matched_zero_in_run_checks_pass",
    "model_world_counts_exact",
    "observation_v2_route_exact",
    "outer_and_solver_counts_exact_bounded",
    "paired_initializer_identity_matched",
    "portable_evaluation_supported_valid",
}
TARGET_CHECKS = {
    "candidate_phase_sequence_exact",
    "candidate_reached_portable_complete",
    "exclusive_stance_handoff_gate_passed",
    "matched_zero_failed_without_actuation",
    "portable_evaluator_passed_exact_development_pair",
    "portable_stance_control_executed",
    "recovery_handoff_gates_passed",
    "stable_stance_dwell_completed",
    "stance_owner_observed_exclusively",
}
TRANSITIONS = [
    ["confirm_prone", "establish_distal_support"],
    ["establish_distal_support", "raise_body"],
    ["raise_body", "stance_handoff"],
    ["stance_handoff", "stance_dwell"],
    ["stance_dwell", "complete"],
]


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
            "sporespore_qsdk_r24d44_stance_completion_launcher_compatibility_positive_closure_v1",
            GATE,
            CAMPAIGN,
            "closed_exact_nominal_mujoco_prone_to_standing_development_positive",
            "development",
        ),
        "CLOSURE_IDENTITY",
    )
    exact_bools(
        closure,
        ("physical_question_declared", "behavior_question_declared"),
        True,
        "DECLARED",
    )
    exact_bools(
        closure,
        (
            "superiority_question_declared",
            "equivalence_or_non_inferiority_question_declared",
            "population_inference_declared",
        ),
        False,
        "UNDECLARED",
    )

    source = closure["source"]
    verify_retained_commit(ROOT, SOURCE, source["parent_commit"])
    exact(
        (source["commit"], source["tree"], source["subject"]),
        (
            SOURCE,
            git(ROOT, "show", "-s", "--format=%T", SOURCE),
            "[recovery/mujoco] Freeze R24D44 launcher compatibility",
        ),
        "SOURCE_IDENTITY",
    )
    bound = {
        key: verify_source_binding(ROOT, SOURCE, source[key])
        for key in (
            "contract",
            "worker",
            "shared_physical_runner",
            "physical_wrapper",
            "source_audit",
        )
    }
    contract = loads(bound["contract"])
    exact(
        (contract["gate_id"], contract["campaign_id"]),
        (GATE, CAMPAIGN),
        "CONTRACT_IDENTITY",
    )

    qualification = closure["qualification"]
    _, receipt, preflight = verify_zero_world_qualification_closure(
        root=ROOT,
        closure=closure,
        gate_id=GATE,
        source_commit=SOURCE,
        attempt_schema="sporespore_qsdk_r24d44_stance_completion_launcher_compatibility_zero_world_attempt_v1",
        receipt_schema="sporespore_qsdk_r24d44_stance_completion_launcher_compatibility_zero_world_receipt_v1",
        qualification_directory_prefix="qsdk-r24d44-qualification-",
        contract_inventory=contract["source_inventory"],
        source_manifest_raw_representation="observed_checkout_plus_git_blob",
    )
    verify_exact_paths(
        preflight,
        {
            "control_count": 11,
            "controls_passed": 11,
            "forced_failure_count": 14,
            "inherited_r24d43_control_count": 10,
            "inherited_r24d43_forced_failure_count": 12,
            "exact_nominal_mujoco_prone_to_standing_observed": False,
        },
        "PREFLIGHT",
    )
    exact_true_checks(
        preflight["exclusive_stance_completion_controls"],
        set(preflight["exclusive_stance_completion_controls"]),
        "EXCLUSIVE_STANCE_CONTROLS",
    )
    launcher = preflight["launcher_contract_validation"]
    exact(
        launcher["forced_failures"],
        {"missing_ghost_horizon": True, "missing_held_out_seal": True},
        "LAUNCHER_FAILURES",
    )
    verify_exact_paths(
        launcher,
        {
            "physical_evidence_directory_count_before": 0,
            "physical_evidence_directory_count_after": 0,
            "physical_evidence_population_unchanged": True,
            "positive_receipt.ok": True,
            "positive_receipt.model_construction_count": 0,
            "positive_receipt.world_attempt_count": 0,
            "positive_receipt.world_build_count": 0,
            "positive_receipt.solver_step_count": 0,
            "positive_receipt.physical_question_opened": False,
        },
        "LAUNCHER",
    )
    source_log = Path(qualification["evidence_root"]) / "source_audit.log"
    require(
        "QSDK_R24D44_STANCE_COMPLETION_LAUNCHER_COMPATIBILITY_SOURCE_PASS"
        in source_log.read_text(encoding="utf-8"),
        "SOURCE_AUDIT_MARKER",
    )

    values = verify_physical_attempt_closure(
        root=ROOT,
        closure=closure,
        gate_id=GATE,
        campaign_id=CAMPAIGN,
        source_commit=SOURCE,
        physical_directory_prefix=(
            "qsdk-r24d44-mujoco-exclusive-stance-completion-"
        ),
        schemas={
            "reservation": "sporespore_qsdk_r24d44_stance_completion_launcher_compatibility_attempt_reservation_v1",
            "manifest": "sporespore_qsdk_r24d44_stance_completion_launcher_compatibility_manifest_v1",
            "full": "sporespore_qsdk_r24d44_stance_completion_launcher_compatibility_full_result_v1",
            "summary": "sporespore_qsdk_r24d44_stance_completion_launcher_compatibility_compact_projection_v1",
            "completion": "sporespore_qsdk_r24d44_stance_completion_launcher_compatibility_supervisor_completion_v1",
            "lock": "sporespore_locomotion_operation_lock_receipt_v1",
        },
        qualification_receipt_raw_sha256=qualification["receipt_raw_sha256"],
    )
    exact(
        closure["physical_attempt"]["official_physical_attempt_count_for_source"],
        1,
        "PHYSICAL_ATTEMPT_COUNT",
    )
    exact(
        (
            values["reservation"]["core_build_profile"],
            values["reservation"]["core_library_raw_sha256"],
        ),
        (
            receipt["toolchain"]["core_build_profile"],
            receipt["toolchain"]["core_library_raw_sha256"],
        ),
        "PHYSICAL_CORE",
    )
    exact(
        (values["manifest"]["execution_valid"], values["manifest"]["decision_positive"]),
        (True, True),
        "MANIFEST_DECISION",
    )
    verify_stance_completion_physical_positive(
        summary=values["summary"],
        full=values["full"],
        observed=closure["observed_result"],
        expected_execution_checks=EXECUTION_CHECKS,
        expected_target_checks=TARGET_CHECKS,
        expected_transitions=TRANSITIONS,
    )

    exact_bools(
        closure["decision"],
        (
            "official_zero_world_qualification_passed",
            "physical_attempt_execution_valid",
            "physical_development_decision_positive",
            "exact_nominal_mujoco_prone_to_standing_observed",
        ),
        True,
        "DECISION_TRUE",
    )
    exact_bools(
        closure["decision"],
        (
            "canonical_prone_to_standing_sdk1_milestone_complete",
            "repeatability_rate_established",
            "population_performance_established",
            "held_out_validation_established",
            "cross_engine_recovery_established",
        ),
        False,
        "DECISION_FALSE",
    )
    exact(
        (
            closure["decision"]["sdk1_completed_steps"],
            closure["decision"]["sdk1_total_steps"],
            closure["decision"]["full_program_completed_steps"],
            closure["decision"]["full_program_total_steps"],
        ),
        (11, 20, 11, 25),
        "SDK_COUNTS",
    )
    exact_bools(
        closure["claim_boundary"],
        (
            "official_zero_world_qualification_passed",
            "physical_attempt_consumed",
            "physical_attempt_execution_valid",
            "physical_development_decision_positive",
            "native_stance_controller_execution_observed",
            "exclusive_stance_ownership_observed",
            "stable_stance_dwell_observed",
            "portable_complete_observed",
            "exact_nominal_mujoco_prone_to_standing_observed",
            "matched_zero_failed_without_actuation",
            "complete_trace_and_invariants_replayed",
            "portable_step_exact_cell_prone_to_standing_result_observed",
        ),
        True,
        "CLAIM_TRUE",
    )
    exact_bools(
        closure["claim_boundary"],
        (
            "physical_envelope_prone_to_standing_claimed",
            "canonical_three_engine_prone_to_standing_claimed",
            "repeatability_rate_claimed",
            "population_claimed",
            "held_out_validation_claimed",
            "cross_engine_recovery_claimed",
            "cross_engine_equivalence_claimed",
            "sdk1_milestone_advanced",
            "physical_acceptance_authority",
            "release_authority",
        ),
        False,
        "CLAIM_FALSE",
    )
    next_boundary = closure["next_boundary"]
    exact(
        (
            next_boundary["gate_id"],
            next_boundary["physical_question_declared"],
            next_boundary["rapier_parry_and_godot_jolt_physics_remain_closed"],
            next_boundary["r24d44_may_rerun"],
        ),
        (NEXT_GATE, False, True, False),
        "NEXT_BOUNDARY",
    )

    closure_hash = sha256(CLOSURE.read_bytes())
    audit_hash = sha256((ROOT / AUDIT_RELATIVE).read_bytes())
    for relative in (RELEASE_RELATIVE, SUPPORT_RELATIVE):
        nodes = find_gate_nodes(
            load_legacy_live_authority(ROOT / relative), NEXT_GATE
        )
        exact(len(nodes), 1, f"NEXT_NODE_COUNT:{relative}")
        verify_exact_paths(
            nodes[0],
            {
                "predecessor_gate_id": GATE,
                "predecessor_source_commit": SOURCE,
                "predecessor_closure_path": CLOSURE_RELATIVE,
                "predecessor_closure_raw_sha256": closure_hash,
                "predecessor_closure_audit_path": AUDIT_RELATIVE,
                "predecessor_closure_audit_raw_sha256": audit_hash,
                "r24d44_official_qualification_passed": True,
                "r24d44_physical_attempt_consumed": True,
                "r24d44_physical_attempt_valid": True,
                "r24d44_decision_positive": True,
                "r24d44_exact_nominal_mujoco_prone_to_standing_observed": True,
                "canonical_three_engine_prone_to_standing_complete": False,
                "physical_question_declared": False,
                "physical_execution_authorized": False,
                "release_authority": False,
            },
            f"NEXT_NODE:{relative}",
        )

    mapping = load(ROOT / MAPPING_RELATIVE)
    exact(
        mapping["full_program_authority"]["release_contract_raw_sha256"],
        sha256((ROOT / RELEASE_RELATIVE).read_bytes()),
        "MAPPING_RELEASE",
    )
    exact(
        mapping["full_program_authority"]["support_matrix_raw_sha256"],
        sha256((ROOT / SUPPORT_RELATIVE).read_bytes()),
        "MAPPING_SUPPORT",
    )
    milestones = {
        item["milestone_id"]: item for item in mapping["sdk1_contract"]["milestones"]
    }
    exact(mapping["sdk1_contract"]["milestone_count"], 20, "SDK1_DENOMINATOR")
    require(
        "every advertised engine"
        in milestones["SDK1-M19"]["plain_english_requirement"],
        "M19_ENGINE_SCOPE",
    )
    for relative in (
        "docs/README.md",
        "docs/ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md",
        "docs/LOCOMOTION_GROUND_UP_RESEARCH_PROGRAM.md",
        "docs/LOCOMOTION_ARCHITECTURE.md",
        "docs/SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md",
        "sdk/adapters/mujoco/README.md",
    ):
        text = (ROOT / relative).read_text(encoding="utf-8")
        require("R24D44 closed exact nominal MuJoCo positive" in text, f"DOC:{relative}")
        require("11/20" in text and "11/25" in text, f"DOC_COUNTS:{relative}")


def main() -> int:
    try:
        audit()
    except Exception as error:
        print(
            "QSDK_R24D44_STANCE_COMPLETION_LAUNCHER_COMPATIBILITY_"
            f"POSITIVE_CLOSURE_FAIL {error}"
        )
        return 1
    print(
        "QSDK_R24D44_STANCE_COMPLETION_LAUNCHER_COMPATIBILITY_"
        "POSITIVE_CLOSURE_PASS qualification=11/11+14 candidate=complete:373 "
        "stance=66 dwell=60 matched_zero=failed:775 worlds=2 outer=1148 "
        "solver=5740 result=exact_nominal_mujoco_prone_to_standing_positive "
        "sdk1=11/20 full=11/25 next=QSDK-R24D45:engine_port_selection"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
