"""Compact audit of the retained invalid QSDK-R24D40 route smoke."""

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
    sha256,
    verify_exact_retained_inventory,
    verify_invalid_physical_attempt_closure,
    verify_retained_commit,
    verify_source_binding,
    verify_zero_world_qualification_closure,
)

CLOSURE_PATH = (
    ROOT
    / "sdk/recovery/r24d40_mujoco_observation_v2_native_smoke_invalid_closure_v1.json"
)
SOURCE = "c68a1aef834998b9c57be59f2bffa8e134ddef64"
GATE = "QSDK-R24D40"
CAMPAIGN = "QSDK-R24D40-MUJOCO-OBSERVATION-V2-NATIVE-ROUTE-SMOKE"
STATUS = "closed_consumed_invalid_recovery_morphology_route_context_missing"


def _ordered(source: str, markers: tuple[str, ...], code: str) -> None:
    require(all(marker in source for marker in markers), f"{code}_MARKER")
    offsets = [source.index(marker) for marker in markers]
    require(offsets == sorted(offsets), f"{code}_ORDER")


def _slice(source: str, start: str, end: str, code: str) -> str:
    require(start in source and end in source, f"{code}_MARKER")
    value = source[source.index(start) : source.index(end, source.index(start))]
    require(value, f"{code}_EMPTY")
    return value


def audit() -> None:
    closure = load(CLOSURE_PATH)
    exact(
        (
            closure["gate_id"],
            closure["campaign_id"],
            closure["closure_status"],
            closure["question_class"],
        ),
        (GATE, CAMPAIGN, STATUS, "development"),
        "CLOSURE_IDENTITY",
    )
    exact_bools(closure, ("physical_question_declared",), True, "DECLARATION")
    exact_bools(
        closure,
        (
            "superiority_question_declared",
            "equivalence_or_non_inferiority_question_declared",
            "population_inference_declared",
        ),
        False,
        "DECLARATION",
    )

    source = closure["source"]
    verify_retained_commit(ROOT, SOURCE, source["parent_commit"])
    exact(
        (
            source["commit"],
            source["tree"],
            source["subject"],
        ),
        (
            SOURCE,
            git(ROOT, "show", "-s", "--format=%T", SOURCE),
            "[recovery/mujoco] Freeze R24D40 observation-v2 route smoke",
        ),
        "SOURCE_IDENTITY",
    )
    contract = loads(verify_source_binding(ROOT, SOURCE, source["contract"]))
    runtime = verify_source_binding(ROOT, SOURCE, source["runtime"]).decode("utf-8")
    shared_smoke = verify_source_binding(ROOT, SOURCE, source["shared_smoke"]).decode(
        "utf-8"
    )
    worker = verify_source_binding(ROOT, SOURCE, source["worker"]).decode("utf-8")
    morphology_route = verify_source_binding(
        ROOT, SOURCE, source["recovery_morphology_route"]
    ).decode("utf-8")
    verify_source_binding(ROOT, SOURCE, source["source_audit"])
    exact(
        (
            contract["gate_id"],
            contract["campaign_id"],
            contract["question_class"],
            contract["physical_question_declared"],
            contract["behavior_question_declared"],
        ),
        (GATE, CAMPAIGN, "development", True, False),
        "CONTRACT_IDENTITY",
    )

    qualification = closure["qualification"]
    _attempt, receipt, preflight = verify_zero_world_qualification_closure(
        root=ROOT,
        closure=closure,
        gate_id=GATE,
        source_commit=SOURCE,
        attempt_schema=(
            "sporespore_qsdk_r24d40_observation_v2_native_smoke_zero_world_attempt_v1"
        ),
        receipt_schema=(
            "sporespore_qsdk_r24d40_mujoco_observation_v2_native_smoke_"
            "zero_world_receipt_v1"
        ),
        qualification_directory_prefix="qsdk-r24d40-qualification-",
        contract_inventory=contract["source_inventory"],
        source_manifest_raw_representation=qualification[
            "source_manifest_raw_representation"
        ],
    )
    verify_exact_retained_inventory(
        Path(qualification["evidence_root"]), qualification["retained_artifacts"]
    )
    exact(
        (receipt["contract_path"], receipt["contract_raw_sha256"]),
        (source["contract"]["path"], source["contract"]["raw_sha256"]),
        "RECEIPT_CONTRACT",
    )
    exact(
        (
            preflight["control_count"],
            preflight["controls_passed"],
            preflight["forced_failure_count"],
        ),
        (8, 8, 7),
        "PREFLIGHT_COUNTS",
    )
    exact(
        set(preflight["observation_v2_native_smoke_controls"]),
        set(contract["complete_zero_world_gate"]["required_controls"]),
        "CONTROL_SET",
    )
    require(
        all(preflight["observation_v2_native_smoke_controls"].values()),
        "CONTROL_FAILURE",
    )
    checkout_only_entries = []
    for entry in receipt["source_manifest"]:
        raw = git(ROOT, "show", f"{SOURCE}:{entry['path']}", text=False)
        assert isinstance(raw, bytes)
        if len(raw) == entry["byte_length"] and sha256(raw) == entry["raw_sha256"]:
            continue
        checkout_only_entries.append(
            {
                "path": entry["path"],
                "observed_checkout_byte_length": entry["byte_length"],
                "observed_checkout_raw_sha256": entry["raw_sha256"],
                "canonical_git_blob_byte_length": len(raw),
                "canonical_git_blob_raw_sha256": sha256(raw),
                "representation_note": (
                    "qualification_runner_recorded_exact_windows_checkout_bytes_"
                    "while_git_blob_oid_retained_canonical_source_identity"
                ),
            }
        )
    exact(
        qualification["source_manifest_representation_evidence"],
        {
            "git_blob_oid_match_count": len(receipt["source_manifest"]),
            "git_blob_raw_byte_match_count": (
                len(receipt["source_manifest"]) - len(checkout_only_entries)
            ),
            "checkout_only_entry_count": len(checkout_only_entries),
            "checkout_only_entries": checkout_only_entries,
        },
        "SOURCE_REPRESENTATION",
    )

    values = verify_invalid_physical_attempt_closure(
        root=ROOT,
        closure=closure,
        gate_id=GATE,
        campaign_id=CAMPAIGN,
        source_commit=SOURCE,
        physical_directory_prefix=("qsdk-r24d40-mujoco-observation-v2-native-smoke-"),
        schemas={
            "reservation": (
                "sporespore_qsdk_r24d40_observation_v2_native_smoke_"
                "attempt_reservation_v1"
            ),
            "invalid": (
                "sporespore_qsdk_r24d40_mujoco_observation_v2_native_invalid_v1"
            ),
            "completion": (
                "sporespore_qsdk_r24d40_observation_v2_native_smoke_"
                "supervisor_completion_v1"
            ),
            "lock": "sporespore_locomotion_operation_lock_receipt_v1",
        },
        qualification_receipt_raw_sha256=qualification["receipt_raw_sha256"],
        absent_complete_paths=(
            "manifest.json",
            "smoke_result.json",
            "smoke_summary.json",
        ),
    )
    physical = closure["physical_attempt"]
    exact(physical["official_physical_attempt_count_for_source"], 1, "ATTEMPT_COUNT")
    for marker in (
        "bounded_recovery_route_smoke.py",
        "result = runtime.run_paired_development(",
        "candidate = _run_arm(",
        "world = world_type(core, route, capability_sha256)",
        "QSDK_R24D39_RECOVERY_MORPHOLOGY_CONTEXT_REQUIRED",
    ):
        require(marker in values["invalid"]["traceback"], f"TRACEBACK_MARKER:{marker}")
    exact(
        (Path(physical["evidence_root"]) / "worker_stderr.log").stat().st_size,
        0,
        "STDERR_EMPTY",
    )

    shared_call = _slice(
        shared_smoke,
        "result = runtime.run_paired_development(",
        "    invariants = trace_validator(result)",
        "SHARED_CALL",
    )
    require("world_type=world_type" in shared_call, "SHARED_WORLD_TYPE")
    require("route=" not in shared_call, "SHARED_ROUTE_WAS_EXPLICIT")
    worker_call = _slice(
        worker,
        "return bounded_smoke.run_and_publish_v1(",
        "\n\n\ndef main(",
        "WORKER_CALL",
    )
    require(
        "world_type=runtime.MujocoObservationV2RecoveryWorld" in worker_call,
        "WORKER_WORLD_TYPE",
    )
    require("route_factory=" not in worker_call, "WORKER_ROUTE_FACTORY_PRESENT")

    paired = _slice(runtime, "def run_paired_development(", "\n\ndef ", "PAIRED")
    _ordered(
        paired,
        (
            "exact_route = (",
            "compile_public_profile_model_route(",
            "candidate = _run_arm(",
            "matched_zero = _run_arm(",
        ),
        "SOURCE_PAIRED",
    )
    arm = _slice(runtime, "def _run_arm(", "\n\ndef run_paired_development(", "ARM")
    _ordered(
        arm,
        (
            "world = world_type(core, route, capability_sha256)",
            "initializer = world.initialize_prone(",
            "observation, native = world.step_native(",
        ),
        "SOURCE_ARM",
    )
    observation_world = _slice(
        runtime,
        "class MujocoObservationV2RecoveryWorld(",
        "\n\ndef _portable_morphology_context(",
        "OBSERVATION_WORLD",
    )
    _ordered(
        observation_world,
        (
            "super().__init__(core, route, capability_sha256)",
            "morphology_context = _portable_morphology_context(route)",
            "QSDK_R24D39_RECOVERY_MORPHOLOGY_CONTEXT_REQUIRED",
        ),
        "SOURCE_CONTEXT",
    )
    native_world = _slice(
        runtime,
        "class MujocoNativeRecoveryWorld(",
        "\n\nclass MujocoImplicitStepRecoveryWorld(",
        "NATIVE_WORLD",
    )
    _ordered(
        native_world,
        (
            "self.model = mujoco.MjModel.from_xml_string(self.model_xml)",
            "self.data = mujoco.MjData(self.model)",
        ),
        "SOURCE_MODEL_DATA",
    )
    require(
        '== "sporespore_recovery_morphology_receipt_v1"' in morphology_route,
        "MORPHOLOGY_SCHEMA",
    )
    require(
        "def compile_recovery_morphology_model_route(" in morphology_route,
        "MORPHOLOGY_COMPILER",
    )

    exact_bools(
        physical,
        (
            "worker_started",
            "operation_lock_released",
            "invalid_or_incomplete_retained",
            "candidate_arm_entered_by_traceback",
            "base_model_route_compiled_by_source_order",
            "candidate_world_constructor_entered_by_traceback",
            "model_and_data_construction_returned_by_source_order",
            "recovery_morphology_context_check_reached",
        ),
        True,
        "PHYSICAL_OBSERVED",
    )
    exact_bools(
        physical,
        (
            "route_coverage_passed",
            "matched_zero_arm_entered_by_source_order",
            "initializer_called_by_source_order",
            "native_step_called_by_source_order",
            "portable_observation_published",
            "collector_invoked",
            "supervisor_invoked",
            "controller_invoked",
            "portable_evaluator_invoked",
            "durable_complete_result_published",
            "valid_behavior_result_observed",
            "exact_execution_counts_published",
        ),
        False,
        "PHYSICAL_LIMIT",
    )
    for key in (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "outer_step_count",
        "solver_step_count",
        "physics_state_modified",
    ):
        exact(physical[key], None, f"UNPUBLISHED_{key.upper()}")

    failure = closure["observed_failure"]
    exact(
        failure["class"],
        "observation_v2_world_received_base_route_without_recovery_morphology_context",
        "FAILURE_CLASS",
    )
    exact_bools(failure, ("integration_failure_observed",), True, "FAILURE_OBSERVED")
    exact_bools(
        failure,
        tuple(
            key
            for key, value in failure.items()
            if isinstance(value, bool) and key not in {"integration_failure_observed"}
        ),
        False,
        "FAILURE_LIMIT",
    )

    postmortem = closure["zero_world_gate_postmortem"]
    exact_bools(
        postmortem,
        (
            "gate_passed_for_declared_controls",
            "physical_opening_conditions_were_satisfied",
            "physical_opening_was_contract_compliant",
            "declared_synthetic_invariant_coverage_was_adequate",
            "smallest_route_smoke_fulfilled_fail_closed_role",
        ),
        True,
        "POSTMORTEM",
    )
    exact_bools(
        postmortem,
        (
            "gate_result_rewritten",
            "route_constructor_conjunction_coverage_was_adequate",
            "historical_closure_audits_reexecuted",
            "full_seeded_ghost_required",
            "additional_full_physical_canary_required",
        ),
        False,
        "POSTMORTEM_LIMIT",
    )
    exact(len(postmortem["required_successor_controls"]), 8, "SUCCESSOR_CONTROLS")

    decision = closure["decision"]
    exact(
        (
            decision["result"],
            decision["sdk1_completed_steps"],
            decision["sdk1_total_steps"],
            decision["full_program_completed_steps"],
            decision["full_program_total_steps"],
        ),
        ("consumed_invalid_incomplete_and_retained", 11, 20, 11, 25),
        "DECISION",
    )
    exact_bools(
        decision,
        (
            "official_zero_world_qualification_passed",
            "all_eight_declared_zero_world_controls_passed",
        ),
        True,
        "DECISION_POSITIVE",
    )
    exact_bools(
        decision,
        tuple(
            key
            for key, value in decision.items()
            if isinstance(value, bool)
            and key
            not in {
                "official_zero_world_qualification_passed",
                "all_eight_declared_zero_world_controls_passed",
            }
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
            next_boundary["behavior_question_declared"],
        ),
        ("QSDK-R24D41", "development", False, False),
        "NEXT",
    )
    exact_bools(
        next_boundary,
        (
            "distinct_source_declaration_required",
            "complete_zero_world_gate_required_before_physics",
            "held_out_cells_remain_sealed",
        ),
        True,
        "NEXT_POSITIVE",
    )
    exact_bools(
        next_boundary,
        tuple(
            key
            for key, value in next_boundary.items()
            if isinstance(value, bool)
            and key
            not in {
                "distinct_source_declaration_required",
                "complete_zero_world_gate_required_before_physics",
                "held_out_cells_remain_sealed",
            }
        ),
        False,
        "NEXT_LIMIT",
    )

    positive_claims = {
        "official_zero_world_qualification_passed",
        "declared_r24d40_zero_world_controls_passed",
        "physical_question_opened",
        "invalid_incomplete_result_retained",
        "route_constructor_integration_failure_observed",
    }
    for key, value in closure["claim_boundary"].items():
        exact(value, key in positive_claims, f"CLAIM_{key.upper()}")
    require(
        "QSDK_R24D40_OBSERVATION_V2_NATIVE_SMOKE_SOURCE_PASS"
        in (Path(qualification["evidence_root"]) / "source_audit.log").read_text(
            encoding="utf-8"
        ),
        "SOURCE_AUDIT_MARKER",
    )
    print(
        "QSDK_R24D40_MUJOCO_OBSERVATION_V2_NATIVE_SMOKE_INVALID_CLOSURE_PASS "
        "qualification=8/8 physical=consumed_invalid "
        "cause=recovery_morphology_route_context_missing exact_counts=unpublished "
        "heldout=0 sdk1=11/20 next=QSDK-R24D41"
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
            "QSDK_R24D40_MUJOCO_OBSERVATION_V2_NATIVE_SMOKE_"
            f"INVALID_CLOSURE_FAIL {error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
