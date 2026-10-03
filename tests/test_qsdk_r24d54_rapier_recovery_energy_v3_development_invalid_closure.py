"""Audit the consumed-invalid R24D54 paired physical result without replaying it."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess
import sys
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
CLOSURE = ROOT / "sdk/recovery/r24d54_rapier_recovery_energy_v3_development_invalid_closure_v1.json"
CONTRACT = ROOT / "sdk/recovery/r24d54_rapier_recovery_energy_v3_behavior_contract_v1.json"
L2_CLOSURE = ROOT / "sdk/recovery/r24d54_rapier_authority_route_probe_repair_closure_v1.json"
RELEASE = ROOT / "sdk/release/quadruped_release_contract.json"
SUPPORT = ROOT / "sdk/release/quadruped_support_matrix.json"
MAPPING = ROOT / "sdk/release/quadruped_sdk1_milestone_mapping_v1.json"
MODULE_PATH = "sdk/adapters/rapier/src/qsdk_r24d54_recovery_energy_v3_behavior.rs"


class AuditError(RuntimeError):
    """Raised when a retained R54 closure assertion fails."""


def require(condition: bool, code: str) -> None:
    if not condition:
        raise AuditError(code)


def exact(actual: Any, expected: Any, code: str) -> None:
    require(actual == expected, f"{code}:{actual!r}!={expected!r}")


def digest(raw: bytes) -> str:
    return "sha256:" + hashlib.sha256(raw).hexdigest()


def repository_text_digest(path: Path) -> str:
    return digest(path.read_text(encoding="utf-8").replace("\r\n", "\n").encode())


def git(*arguments: str, text: bool = True) -> str | bytes:
    command = ["git", *arguments]
    if text:
        return subprocess.check_output(command, cwd=ROOT, text=True).strip()
    return subprocess.check_output(command, cwd=ROOT)


def records_with_key(value: Any, key: str) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    if isinstance(value, dict):
        if key in value:
            records.append(value)
        for child in value.values():
            records.extend(records_with_key(child, key))
    elif isinstance(value, list):
        for child in value:
            records.extend(records_with_key(child, key))
    return records


def verify_arm_invariants(arm: dict[str, Any], expected_count: int) -> None:
    exact(arm["captured_observation_count"], expected_count, "ARM_CAPTURE_COUNT")
    exact(len(arm["trace_v3"]["observations"]), expected_count, "ARM_TRACE_COUNT")
    exact(len(arm["in_run_invariant_receipts"]), expected_count, "ARM_INVARIANT_COUNT")
    exact(len(arm["compact_staging_records"]), expected_count, "ARM_STAGING_COUNT")
    exact(len(arm["v3_prefix_aggregation_receipts"]), expected_count, "ARM_AGGREGATE_COUNT")
    for index, receipt in enumerate(arm["in_run_invariant_receipts"], start=1):
        exact(receipt["semantic_step"], index, "INVARIANT_SEQUENCE")
        require(
            receipt["engine_specific_policy_branch_count"] == 0
            and receipt["external_intervention_count"] == 0
            and receipt["native_solver_step_count"] == 1
            and not receipt["physical_acceptance_authority"]
            and not receipt["release_authority"]
            and not receipt["prone_to_standing_claimed"],
            "INVARIANT_BOUNDARY",
        )
        application = receipt["application"]
        require(
            application["engine_specific_policy_branch_count"] == 0
            and application["external_impulse_application_count"] == 0
            and all(value["readback_matches"] for value in application["ordered_pre_step_readbacks"])
            and all(value["impulse_within_cap"] for value in application["ordered_post_step_readbacks"]),
            "NATIVE_APPLICATION_INVARIANT",
        )
        exact(sum(receipt["observation"]["external_interventions"].values()), 0, "INTERVENTION_TOTAL")
    for index, record in enumerate(arm["compact_staging_records"], start=1):
        require(
            record["semantic_step"] == index
            and record["energy_sequence"] == index
            and record["staging_sequence"] == index
            and record["source_measurement"]
            and record["endpoint_source_measurement"]
            and record["overflow_small_step_count"] == 0
            and record["island_solve_count"] == 1
            and record["ccd_substep_count"] == 1,
            "STAGING_RECORD",
        )
    for index, receipt in enumerate(arm["v3_prefix_aggregation_receipts"], start=1):
        require(
            receipt["semantic_step"] == index
            and receipt["increment_count"] == index
            and not receipt["threshold_applied"]
            and not receipt["physical_result"],
            "AGGREGATION_RECEIPT",
        )


def audit() -> None:
    closure = json.loads(CLOSURE.read_text(encoding="utf-8"))
    contract = json.loads(CONTRACT.read_text(encoding="utf-8"))
    exact(
        (
            closure["schema_version"], closure["gate_id"], closure["closure_status"],
            closure["question_class"], closure["physical_question_declared"],
        ),
        (
            "sporespore_qsdk_r24d54_rapier_recovery_energy_v3_development_invalid_closure_v1",
            "QSDK-R24D54",
            "closed_consumed_invalid_complete_evaluation_trace_population_included_post_terminal_candidate_tail",
            "development", True,
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
    commit = source["commit"]
    exact(git("rev-parse", f"{commit}^"), source["parent_commit"], "SOURCE_PARENT")
    exact(git("rev-parse", f"{commit}^{{tree}}"), source["tree"], "SOURCE_TREE")
    exact(repository_text_digest(L2_CLOSURE), source["stage_authority_closure_raw_sha256"], "L2_DIGEST")
    l2_closure = json.loads(L2_CLOSURE.read_text(encoding="utf-8"))
    exact(
        (
            l2_closure["schema_version"], l2_closure["closure_status"],
            l2_closure["repair_source"]["commit"],
            l2_closure["decision"]["production_route_authority_probe_passed"],
            l2_closure["decision"]["r24d54_paired_physical_attempt_remains_unconsumed"],
            l2_closure["decision"]["r24d54_paired_development_authorized"],
        ),
        (
            "sporespore_qsdk_r24d54_rapier_authority_route_probe_repair_closure_v1",
            "closed_complete_zero_world_production_route_authority_probe_repair_qualified",
            "39bc8234830311c98435c487c721b6f27534d8ea", True, True, True,
        ),
        "L2_IMMUTABLE_DECISION",
    )
    module = git("show", f"{commit}:{MODULE_PATH}")
    require(
        "let trace = RecoveryTraceV3" in module
        and "observations: observations_v3" in module
        and "terminal_prefix_observation_count = index + 1" in module
        and "candidate.trace.clone()" in module
        and "matched_zero.trace.clone()" in module,
        "OBSERVED_SOURCE_ROUTE",
    )
    arm_start = module.index("fn run_v3_arm")
    require(
        module.index("let trace = RecoveryTraceV3", arm_start)
        < module.index("terminal_prefix_observation_count = index + 1", arm_start)
        < module.index("Ok(R54ArmRun { trace, result })", arm_start),
        "OBSERVED_ARM_SOURCE_ORDER",
    )
    rule = contract["v3_replay_validity"]
    exact(rule["only_terminal_transition_divergence_permitted"], True, "CONTRACT_TERMINAL_DIVERGENCE")
    require("no later physical observation is needed or accepted" in rule["adequacy"], "CONTRACT_PREFIX_RULE")

    attempt_claim = closure["physical_attempt"]
    evidence_root = Path(attempt_claim["evidence_root"])
    actual_files = sorted(path for path in evidence_root.rglob("*") if path.is_file())
    expected_files = attempt_claim["retained_files"]
    exact(
        [path.relative_to(evidence_root).as_posix() for path in actual_files],
        [record["path"] for record in expected_files],
        "RETAINED_FILE_POPULATION",
    )
    for path, record in zip(actual_files, expected_files, strict=True):
        exact(path.stat().st_size, record["byte_length"], f"FILE_BYTES:{record['path']}")
        exact(digest(path.read_bytes()), record["raw_sha256"], f"FILE_DIGEST:{record['path']}")
    exact(len(actual_files), attempt_claim["retained_file_count"], "TREE_FILE_COUNT")
    exact(sum(path.stat().st_size for path in actual_files), attempt_claim["retained_total_byte_length"], "TREE_BYTES")

    physical_attempt = json.loads((evidence_root / "physical_attempt.json").read_text(encoding="utf-8"))
    physical_receipt = json.loads((evidence_root / "physical_receipt.json").read_text(encoding="utf-8"))
    result = json.loads((evidence_root / "physical_result.json").read_text(encoding="utf-8"))
    exact(
        (
            physical_attempt["source_commit"], physical_attempt["upstream_commit"],
            physical_attempt["live_remote_commit"], physical_attempt["worktree_clean_at_start"],
            physical_attempt["runtime_binding_sha256"],
        ),
        (commit, commit, commit, True, source["runtime_binding_sha256"]),
        "ATTEMPT_IDENTITY",
    )
    exact(
        (
            physical_receipt["source_commit"], physical_receipt["mode"],
            physical_receipt["stage_valid"], physical_receipt["operation_lock_released"],
            physical_receipt["actual_total_outer_steps"],
            physical_receipt["candidate_outer_steps"], physical_receipt["matched_zero_outer_steps"],
        ),
        (commit, "development", True, True, 1219, 967, 252),
        "RECEIPT_IDENTITY",
    )
    exact(
        digest((evidence_root / physical_receipt["result_path"]).read_bytes()),
        physical_receipt["result_raw_sha256"],
        "RECEIPT_RESULT_BINDING",
    )
    exact(
        (
            result["ok"], result["result_may_satisfy_r24d54"],
            result["actual_total_outer_steps"], result["candidate_outer_steps"],
            result["matched_zero_outer_steps"], result["held_out_cell_access_count"],
            result["held_out_selector_invocation_count"], result["prone_to_standing_claimed"],
        ),
        (True, True, 1219, 967, 252, 0, 0, False),
        "RESULT_IDENTITY",
    )

    candidate = result["candidate"]
    zero = result["matched_zero_command"]
    evaluation = result["evaluation"]
    verify_arm_invariants(candidate, 967)
    verify_arm_invariants(zero, 252)
    exact(len(candidate["v2_v3_phase_prefix_receipts"]), 787, "CANDIDATE_PREFIX_COUNT")
    exact(len(zero["v2_v3_phase_prefix_receipts"]), 252, "ZERO_PREFIX_COUNT")
    require(all(value["pre_terminal_phase_identity"] for value in candidate["v2_v3_phase_prefix_receipts"]), "CANDIDATE_PREFIX_IDENTITY")
    require(all(value["pre_terminal_phase_identity"] for value in zero["v2_v3_phase_prefix_receipts"]), "ZERO_PREFIX_IDENTITY")
    exact(sum(value["terminal_transition_divergence"] for value in candidate["v2_v3_phase_prefix_receipts"]), 1, "CANDIDATE_DIVERGENCE_COUNT")
    exact(sum(value["terminal_transition_divergence"] for value in zero["v2_v3_phase_prefix_receipts"]), 0, "ZERO_DIVERGENCE_COUNT")
    last_candidate = candidate["v2_v3_phase_prefix_receipts"][-1]
    exact(
        (
            last_candidate["semantic_step"], last_candidate["v2_prior_phase"],
            last_candidate["v2_next_phase"], last_candidate["v3_prior_phase"],
            last_candidate["v3_next_phase"], last_candidate["v3_terminal"],
        ),
        (787, "stance_dwell", "stance_dwell", "stance_dwell", "complete", True),
        "CANDIDATE_TERMINAL",
    )
    exact(
        (
            candidate["terminal_prefix_observation_count"], candidate["captured_observation_count"],
            candidate["final_phase_v3"], candidate["terminal_failure_code_v3"],
            zero["terminal_prefix_observation_count"], zero["captured_observation_count"],
            zero["final_phase_v3"], zero["terminal_failure_code_v3"],
        ),
        (787, 967, "complete", None, 252, 252, "failed", "phase_timeout:establish_distal_support"),
        "ARM_TERMINALS",
    )
    exact(
        (
            evaluation["support_status"], evaluation["verdict"],
            evaluation["candidate_trace"]["accepted_observation_count"],
            evaluation["candidate_trace"]["observation_count"],
            evaluation["matched_zero_command_trace"]["accepted_observation_count"],
            evaluation["matched_zero_command_trace"]["observation_count"],
            evaluation["physical_development_trace_valid"], evaluation["physical_result"],
            evaluation["all_negative_control_requirements_enforced"],
            evaluation["prone_to_standing_claimed"],
        ),
        ("supported_exact", "physical_development_failed", 787, 967, 252, 252, False, False, False, False),
        "FROZEN_EVALUATION",
    )
    terminal_observation = candidate["trace_v3"]["observations"][786]
    torso = next(value for value in terminal_observation["ordered_body_clearance_observations"] if value["body_id"] == "torso")
    require(
        all(value["ordinary_unilateral_contact"] for value in terminal_observation["ordered_foot_bearing_observations"])
        and not torso["nonfoot_contact_present"]
        and torso["minimum_nonfoot_clearance_m"] > 0
        and sum(terminal_observation["external_interventions"].values()) == 0,
        "CANDIDATE_TERMINAL_PHYSICS",
    )
    exact(candidate["v3_prefix_aggregation_receipts"][786]["absolute_residual_j"], 1.8697292034630664e-6, "TERMINAL_RESIDUAL")

    decision = closure["decision"]
    exact(
        (
            decision["paired_development_attempt_consumed_for_exact_source"],
            decision["execution_complete"], decision["physical_question_valid"],
            decision["decision_positive"], decision["candidate_v3_terminal_completion_observed"],
            decision["matched_zero_v3_terminal_failure_observed"],
            decision["candidate_completion_promoted_to_prone_to_standing_claim"],
            decision["same_source_or_identity_rerun_permitted"],
        ),
        (True, True, False, False, True, True, False, False),
        "DECISION",
    )
    closure_digest = repository_text_digest(CLOSURE)
    for ledger_path in (RELEASE, SUPPORT):
        ledger = json.loads(ledger_path.read_text(encoding="utf-8"))
        records = records_with_key(ledger, "r24d54_question_class")
        exact(len(records), 1, f"LEDGER_RECORD_COUNT:{ledger_path.name}")
        record = records[0]
        # This historical closure owns only the immutable R54-prefixed fields.
        # Active authorization, blockers, and next-gate state belong to the live
        # successor and must be tested by that successor rather than frozen here.
        exact(
            (
                record["r24d54_source_status"], record["r24d54_physical_closure_raw_sha256"],
                record["r24d54_paired_development_authorized"], record["r24d54_physical_attempted"],
                record["r24d54_physical_development_trace_valid"],
                record["r24d54_candidate_v3_terminal_completion_observed"],
                record["r24d54_candidate_post_terminal_tail_observation_count"],
            ),
            (
                closure["closure_status"], closure_digest, False, True, False, True, 180,
            ),
            f"LEDGER_R54:{ledger_path.name}",
        )
    mapping = json.loads(MAPPING.read_text(encoding="utf-8"))
    exact(mapping["full_program_authority"]["release_contract_raw_sha256"], digest(RELEASE.read_bytes()), "MAPPING_RELEASE")
    exact(mapping["full_program_authority"]["support_matrix_raw_sha256"], digest(SUPPORT.read_bytes()), "MAPPING_SUPPORT")

    print(
        "QSDK_R24D54_RAPIER_RECOVERY_ENERGY_V3_INVALID_CLOSURE_PASS "
        "files=7 worlds=2 steps=1219 invariants=1219 staging=1219 "
        "candidate_terminal=complete@787 captured=967 tail=180 zero=failed@252 "
        "evaluation=physical_development_failed trace_valid=false consumed=true "
        "prone=false sdk1=11/20 live_successor_state_not_bound=true"
    )


if __name__ == "__main__":
    try:
        audit()
    except (AuditError, OSError, KeyError, TypeError, ValueError, StopIteration, subprocess.SubprocessError) as error:
        print(f"QSDK_R24D54_RAPIER_RECOVERY_ENERGY_V3_INVALID_CLOSURE_FAIL {error}", file=sys.stderr)
        raise SystemExit(1) from error
