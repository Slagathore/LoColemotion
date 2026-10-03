"""Compact audit of the retained zero-world QSDK-R24D31 closure."""

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
    git,
    load,
    loads,
    require,
    sha256,
    source_bytes,
    verify_retained_commit,
    verify_zero_world_qualification_closure,
)


CLOSURE_PATH = ROOT / "sdk/recovery/r24d31_mujoco_energy_ledger_correction_qualification_closure_v1.json"
SOURCE = "2a7a63ae7c166e180177d33cf3a6954c866409d6"
GATE = "QSDK-R24D31"
STATUS = (
    "closed_complete_zero_world_energy_accounting_diagnosis_and_"
    "independent_source_correction_qualified_no_physical_question"
)


def _source_authority(source: dict[str, object], prefix: str) -> bytes:
    relative = str(source[f"{prefix}_path"])
    raw = source_bytes(ROOT, SOURCE, relative)
    exact(len(raw), source[f"{prefix}_byte_length"], f"{prefix.upper()}_LENGTH")
    exact(sha256(raw), source[f"{prefix}_raw_sha256"], f"{prefix.upper()}_HASH")
    exact(
        git(ROOT, "rev-parse", f"{SOURCE}:{relative}"),
        source[f"{prefix}_git_blob_oid"],
        f"{prefix.upper()}_OID",
    )
    return raw


def _exact_bools(value: dict[str, object], keys: tuple[str, ...], expected: bool, prefix: str) -> None:
    for key in keys:
        exact(value[key], expected, f"{prefix}_{key.upper()}")


def audit() -> None:
    closure = load(CLOSURE_PATH)
    exact(
        closure["schema_version"],
        "sporespore_qsdk_r24d31_mujoco_energy_ledger_correction_qualification_closure_v1",
        "SCHEMA",
    )
    exact(closure["gate_id"], GATE, "GATE")
    exact(closure["closure_status"], STATUS, "STATUS")
    exact(closure["question_class"], "development", "QUESTION")
    _exact_bools(
        closure,
        (
            "physical_question_declared",
            "superiority_question_declared",
            "equivalence_or_non_inferiority_question_declared",
            "population_inference_declared",
        ),
        False,
        "DECLARATION",
    )

    source = closure["source"]
    exact(source["commit"], SOURCE, "SOURCE")
    verify_retained_commit(ROOT, SOURCE, str(source["parent_commit"]))
    exact(git(ROOT, "show", "-s", "--format=%T", SOURCE), source["tree"], "TREE")
    contract = loads(_source_authority(source, "contract"))
    fixture = loads(_source_authority(source, "fixture"))
    exact(contract["gate_id"], GATE, "CONTRACT_GATE")
    exact(contract["physical_question_declared"], False, "CONTRACT_PHYSICAL")
    exact(
        contract["qualification_and_closure"]["qualification_result_pending"],
        True,
        "CONTRACT_PROSPECTIVE",
    )
    exact(fixture["gate_id"], GATE, "FIXTURE_GATE")
    exact((len(fixture["candidate_points"]), len(fixture["matched_zero_points"])), (6, 4), "FIXTURE_POINTS")

    predecessor = closure["predecessor"]
    predecessor_value = load(ROOT / predecessor["closure_path"])
    exact(
        sha256((ROOT / predecessor["closure_path"]).read_bytes()),
        predecessor["closure_raw_sha256"],
        "PREDECESSOR_HASH",
    )
    exact(predecessor_value["closure_status"], predecessor["historical_result"], "PREDECESSOR_RESULT")
    _exact_bools(
        predecessor,
        (
            "historical_result_rewritten",
            "historical_threshold_rewritten",
            "historical_evaluator_rewritten",
            "historical_interpretation_rewritten",
            "same_identity_rerun_permitted",
            "same_identity_requalification_permitted",
        ),
        False,
        "PREDECESSOR",
    )

    _attempt, receipt, preflight = verify_zero_world_qualification_closure(
        root=ROOT,
        closure=closure,
        gate_id=GATE,
        source_commit=SOURCE,
        attempt_schema="sporespore_qsdk_r24d31_mujoco_energy_ledger_correction_zero_world_attempt_v1",
        receipt_schema="sporespore_qsdk_r24d31_mujoco_energy_ledger_correction_zero_world_receipt_v1",
        qualification_directory_prefix="qsdk-r24d31-qualification-",
        contract_inventory=contract["source_inventory"],
    )
    exact(receipt["contract_path"], source["contract_path"], "RECEIPT_CONTRACT")
    exact(receipt["contract_raw_sha256"], source["contract_raw_sha256"], "RECEIPT_CONTRACT_HASH")
    exact(preflight["negative_control_count"], 12, "PREFLIGHT_COUNT")
    exact(preflight["negative_controls_passed"], 12, "PREFLIGHT_PASSED")
    exact(
        set(preflight["energy_ledger_controls"]),
        set(contract["complete_zero_world_gate"]["required_controls"]),
        "PREFLIGHT_CONTROL_SET",
    )
    require(all(preflight["energy_ledger_controls"].values()), "PREFLIGHT_CONTROL_FAILURE")
    details = preflight["energy_ledger_control_details"]
    exact(details["fixture_raw_sha256"], source["fixture_raw_sha256"], "DETAIL_FIXTURE")
    exact(details["matched_zero_terminal_signed_residual_j"], -0.7191017288295729, "DETAIL_MATCHED")
    exact(details["candidate_terminal_signed_residual_j"], -16.476426362918343, "DETAIL_CANDIDATE")
    exact(details["unchanged_maximum_absolute_residual_j"], 0.25, "DETAIL_LIMIT")

    decision = closure["decision"]
    _exact_bools(
        decision,
        (
            "unclosed_predecessor_energy_accounting_diagnosed",
            "independent_native_work_source_correction_qualified",
            "tautological_residual_closure_rejected",
            "actuator_coordinate_crosscheck_required",
            "native_component_terms_retained",
            "r24d31_closed_without_physics",
        ),
        True,
        "DECISION",
    )
    _exact_bools(
        decision,
        (
            "controller_changed",
            "native_physics_changed",
            "morphology_changed",
            "portable_phase_machine_changed",
            "portable_pose_classifier_changed",
            "portable_evaluator_changed",
            "corrected_energy_balance_physically_validated",
            "r24d31_physical_execution_permitted",
        ),
        False,
        "DECISION",
    )
    exact(
        (
            decision["new_behavior_threshold_count"],
            decision["new_empirical_threshold_count"],
            decision["new_margin_count"],
        ),
        (0, 0, 0),
        "DECISION_NEW_LIMITS",
    )

    exact(closure["sdk_status"]["sdk1_completed_steps"], 11, "SDK1_SCORE")
    exact(closure["sdk_status"]["full_program_completed_steps"], 11, "PROGRAM_SCORE")
    next_boundary = closure["next_boundary"]
    exact(next_boundary["gate_id"], "QSDK-R24D32", "NEXT_GATE")
    exact(next_boundary["status"], "not_yet_frozen_physical_execution_blocked", "NEXT_STATUS")
    _exact_bools(
        next_boundary,
        ("r24d31_physical_execution_authorized", "r24d31_may_be_requalified"),
        False,
        "NEXT",
    )

    claims = closure["claim_boundary"]
    positive = {
        "official_zero_world_qualification_passed",
        "unclosed_predecessor_energy_accounting_diagnosed",
        "independent_native_work_source_correction_qualified",
    }
    for key, value in claims.items():
        exact(value, key in positive, f"CLAIM_{key.upper()}")

    evidence_root = Path(closure["qualification"]["evidence_root"])
    audit_log = (evidence_root / "source_audit.log").read_text(encoding="utf-8")
    require("QSDK_R24D31_MUJOCO_ENERGY_LEDGER_CORRECTION_SOURCE_PASS" in audit_log, "SOURCE_AUDIT_MARKER")
    print(
        "QSDK_R24D31_MUJOCO_ENERGY_LEDGER_QUALIFICATION_CLOSURE_PASS "
        "sources=90 controls=12/12 models=0 worlds=0 solver_steps=0 "
        "diagnosis=unclosed_zero_dissipation correction=qualified_zero_world "
        "physical=false sdk1=11/20 next=QSDK-R24D32"
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
        subprocess.SubprocessError,
    ) as error:
        print(
            "QSDK_R24D31_MUJOCO_ENERGY_LEDGER_QUALIFICATION_CLOSURE_FAIL "
            f"{error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
