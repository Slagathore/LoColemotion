"""Audit R43's qualified but pre-reservation launcher-integration invalid."""

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
    exact_bools,
    git,
    load,
    loads,
    require,
    verify_exact_retained_inventory,
    verify_retained_commit,
    verify_source_binding,
    verify_zero_world_qualification_closure,
)

CLOSURE_PATH = (
    ROOT
    / "sdk/recovery/"
    "r24d43_exclusive_stance_completion_launch_invalid_closure_v1.json"
)
SOURCE = "53e624f3fc493e3096815ea6f4f978f382a3c9fc"
GATE = "QSDK-R24D43"
CAMPAIGN = "QSDK-R24D43-MUJOCO-EXCLUSIVE-STANCE-COMPLETION"
STATUS = (
    "closed_officially_qualified_launcher_contract_integration_invalid_"
    "before_physical_reservation"
)


def _ordered(source: str, markers: tuple[str, ...], code: str) -> None:
    require(all(marker in source for marker in markers), f"{code}_MARKER")
    positions = [source.index(marker) for marker in markers]
    require(positions == sorted(positions), f"{code}_ORDER")


def audit() -> None:
    closure = load(CLOSURE_PATH)
    exact(
        (
            closure["schema_version"],
            closure["gate_id"],
            closure["campaign_id"],
            closure["closure_status"],
            closure["question_class"],
        ),
        (
            "sporespore_qsdk_r24d43_exclusive_stance_completion_"
            "launch_invalid_closure_v1",
            GATE,
            CAMPAIGN,
            STATUS,
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
            "[recovery/mujoco] Freeze R24D43 exclusive stance completion",
        ),
        "SOURCE_IDENTITY",
    )
    contract = loads(verify_source_binding(ROOT, SOURCE, source["contract"]))
    wrapper = verify_source_binding(ROOT, SOURCE, source["physical_wrapper"]).decode()
    runner = verify_source_binding(ROOT, SOURCE, source["shared_physical_runner"]).decode()
    verify_source_binding(ROOT, SOURCE, source["worker"])
    verify_source_binding(ROOT, SOURCE, source["source_audit"])
    exact(
        (
            contract["gate_id"],
            contract["campaign_id"],
            contract["question_class"],
            contract["physical_question_declared"],
            contract["behavior_question_declared"],
        ),
        (GATE, CAMPAIGN, "development", True, True),
        "CONTRACT_IDENTITY",
    )
    require("natural_stop_horizon" in contract, "NATURAL_HORIZON_ABSENT")
    require("ghost_horizon" not in contract, "GHOST_HORIZON_PRESENT")
    require("held_out_seal" not in contract, "HELD_OUT_SEAL_PRESENT")
    require("-ExpectedHorizonSteps 1200" in wrapper, "WRAPPER_HORIZON")
    require("$contract.ghost_horizon.outer_steps_per_arm" in runner, "RUNNER_GHOST")
    require(
        "$contract.held_out_seal.held_out_cell_access_count" in runner,
        "RUNNER_HELDOUT",
    )
    _ordered(
        runner,
        (
            "$contract = Get-Content",
            "$contract.ghost_horizon.outer_steps_per_arm",
            "$priorReservations = @(",
            ". $operationLockPath",
            "Enter-SporeSporeLocomotionOperationLock -Role physical",
            "New-Item -ItemType Directory",
            "$workerProcess = Start-Process",
        ),
        "PRE_RESERVATION_FAILURE",
    )

    qualification = closure["qualification"]
    _attempt, receipt, preflight = verify_zero_world_qualification_closure(
        root=ROOT,
        closure=closure,
        gate_id=GATE,
        source_commit=SOURCE,
        attempt_schema=(
            "sporespore_qsdk_r24d43_exclusive_stance_completion_"
            "zero_world_attempt_v1"
        ),
        receipt_schema=(
            "sporespore_qsdk_r24d43_exclusive_stance_completion_"
            "zero_world_receipt_v1"
        ),
        qualification_directory_prefix="qsdk-r24d43-qualification-",
        contract_inventory=contract["source_inventory"],
        source_manifest_raw_representation=qualification[
            "source_manifest_raw_representation"
        ],
    )
    verify_exact_retained_inventory(
        Path(qualification["evidence_root"]), qualification["retained_artifacts"]
    )
    controls = preflight["exclusive_stance_completion_controls"]
    exact(
        (
            preflight["control_count"],
            preflight["controls_passed"],
            preflight["forced_failure_count"],
            len(controls),
        ),
        (10, 10, 12, 10),
        "PREFLIGHT_COUNTS",
    )
    require(all(controls.values()), "PREFLIGHT_CONTROL")
    exact(
        (receipt["contract_path"], receipt["contract_raw_sha256"]),
        (source["contract"]["path"], source["contract"]["raw_sha256"]),
        "RECEIPT_CONTRACT",
    )

    observation = closure["launcher_observation"]
    exact(
        (
            observation["failure_stage"],
            observation["error_type"],
            observation["error"],
            observation["missing_contract_object"],
            observation["declared_but_unconsumed_object"],
            observation["additional_required_object_also_absent"],
        ),
        (
            "shared_physical_runner_contract_selector_evaluation",
            "PropertyNotFoundStrict",
            "The property 'ghost_horizon' cannot be found on this object.",
            "ghost_horizon",
            "natural_stop_horizon",
            "held_out_seal",
        ),
        "OBSERVED_FAILURE",
    )
    physical_roots = sorted(
        Path(qualification["evidence_root"]).parent.glob(
            f"{observation['physical_directory_prefix']}*"
        )
    )
    exact(physical_roots, [], "PHYSICAL_EVIDENCE_ROOTS")
    exact_bools(
        observation,
        (
            "operation_lock_acquired",
            "worker_started",
            "physics_state_modified",
            "physical_question_opened",
        ),
        False,
        "OBSERVATION_ZERO",
    )
    for key in (
        "matching_physical_directory_count",
        "attempt_reservation_count",
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "outer_step_count",
        "solver_step_count",
    ):
        exact(observation[key], 0, f"OBSERVATION_{key.upper()}")

    decision = closure["decision"]
    exact(
        (
            decision["result"],
            decision["sdk1_completed_steps"],
            decision["sdk1_total_steps"],
            decision["full_program_completed_steps"],
            decision["full_program_total_steps"],
        ),
        (
            "official_zero_world_positive_then_pre_reservation_launcher_"
            "integration_invalid",
            11,
            20,
            11,
            25,
        ),
        "DECISION",
    )
    exact_bools(
        decision,
        (
            "official_zero_world_qualification_passed",
            "all_ten_declared_zero_world_controls_passed",
            "distinct_successor_required",
        ),
        True,
        "DECISION_POSITIVE",
    )
    exact_bools(
        decision,
        (
            "physical_attempt_reserved_or_consumed",
            "valid_behavior_result_observed",
            "valid_physical_negative_observed",
            "physical_question_answered",
            "r24d43_source_may_rerun_or_be_requalified",
        ),
        False,
        "DECISION_LIMIT",
    )
    next_boundary = closure["next_boundary"]
    exact(
        (
            next_boundary["gate_id"],
            next_boundary["question_class"],
            next_boundary["physical_question_declared"],
            next_boundary["scientific_question_changed"],
        ),
        ("QSDK-R24D44", "development", True, False),
        "NEXT",
    )
    positive_claims = {
        "official_zero_world_qualification_passed",
        "r24d43_zero_world_stance_composition_passed",
        "launcher_contract_integration_failure_observed",
        "invalid_pre_reservation_invocation_preserved",
    }
    for key, value in closure["claim_boundary"].items():
        exact(value, key in positive_claims, f"CLAIM_{key.upper()}")
    require(
        "QSDK_R24D43_EXCLUSIVE_STANCE_COMPLETION_SOURCE_PASS"
        in (Path(qualification["evidence_root"]) / "source_audit.log").read_text(),
        "SOURCE_AUDIT_MARKER",
    )
    print(
        "QSDK_R24D43_EXCLUSIVE_STANCE_COMPLETION_LAUNCH_INVALID_CLOSURE_PASS "
        "qualification=10/10 physical_reservations=0 worlds=0 solver=0 "
        "cause=launcher_contract_schema_bridge next=QSDK-R24D44 sdk1=11/20"
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
            "QSDK_R24D43_EXCLUSIVE_STANCE_COMPLETION_"
            f"LAUNCH_INVALID_CLOSURE_FAIL {error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
