"""Compact audit of the consumed R24D68 native-behavior attempt."""

from pathlib import Path
import struct
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError,
    exact,
    git,
    load,
    require_ordered_markers,
    sha256,
    source_bytes,
    verify_boolean_partition,
    verify_exact_paths,
    verify_legacy_live_gate_paths,
    verify_source_binding,
    verify_supervised_bounded_ghost_attempt,
)

CLOSURE = ROOT / (
    "sdk/recovery/r24d68_godot_strict_actuator_budget_"
    "behavior_invalid_closure_v1.json"
)
SOURCE = "a5414e1ba18b698e550dabb0e39b066c0ae29ff1"
STATUS = (
    "closed_consumed_invalid_candidate_step_90_one_binary32_ulp_"
    "native_effective_limit_reexpansion"
)
PUBLISHED = 0.05637374829312699
CONFIGURED = 0.05637374520301819
MAX_TORQUE = 6.764849662780762
SOLVER_STEP = 0.008333333767950535
MEASURED = 0.05637374892830849

DECISION_TRUE = (
    "behavior_attempt_consumed_for_exact_source",
    "model_construction_completed",
    "candidate_world_build_completed",
    "ninety_solver_steps_completed",
    "physics_state_modified",
    "strict_host_cap_projection_applied_and_read_back",
    "exact_rejected_measurement_retained",
    "native_and_core_strict_budget_decisions_agreed",
    "r67_predicate_mismatch_repaired",
    "native_effective_limit_reconstructed_exactly",
    "one_binary32_ulp_reexpansion_established",
    "r68_host_projection_inadequacy_established",
    "distinct_successor_source_required",
    "native_effective_limit_inverse_projection_successor_required",
)
DECISION_FALSE = (
    "candidate_arm_completed",
    "matched_zero_world_constructed",
    "behavior_pair_completed",
    "behavior_evaluator_invoked",
    "valid_physical_behavior_result_observed",
    "behavior_physics_failure_established",
    "controller_failure_established",
    "same_identity_rerun_permitted",
    "r24d68_requalification_permitted",
    "historical_threshold_changed",
    "historical_margin_changed",
    "historical_selector_changed",
    "historical_evaluator_changed",
    "historical_result_rewritten",
    "exact_nominal_godot_prone_to_standing_observed",
    "prone_to_standing_claimed",
    "physical_acceptance_authority",
    "release_authority",
)
CLAIM_TRUE = (
    "behavior_attempt_retained",
    "behavior_attempt_consumed_for_exact_source",
    "invalid_integration_result",
    "model_construction_completed",
    "candidate_world_build_completed",
    "ninety_solver_steps_executed",
    "physics_state_modified",
    "termination_protocol_valid",
    "strict_host_cap_projection_applied_and_read_back",
    "exact_rejected_measurement_retained",
    "native_and_core_strict_budget_decisions_agreed",
    "r67_predicate_mismatch_repaired",
    "native_effective_limit_reconstructed_exactly",
    "one_binary32_ulp_reexpansion_established",
    "r68_host_projection_inadequacy_established",
)
CLAIM_FALSE = (
    "candidate_arm_completed",
    "matched_zero_world_constructed",
    "behavior_pair_completed",
    "behavior_evaluator_invoked",
    "valid_physical_behavior_result_observed",
    "behavior_physics_failure_established",
    "controller_failure_established",
    "exact_nominal_godot_prone_to_standing_observed",
    "prone_to_standing_claimed",
    "population_claimed",
    "cross_engine_equivalence_claimed",
    "sdk1_milestone_advanced",
    "physical_acceptance_authority",
    "release_authority",
)


def f32(value: float) -> float:
    return struct.unpack("<f", struct.pack("<f", value))[0]


def f32_hex(value: float) -> str:
    return f"0x{struct.unpack('<I', struct.pack('<f', value))[0]:08x}"


def audit() -> None:
    closure = load(CLOSURE)
    verify_exact_paths(
        closure,
        {
            "schema_version": (
                "sporespore_qsdk_r24d68_godot_strict_actuator_budget_"
                "behavior_invalid_closure_v1"
            ),
            "gate_id": "QSDK-R24D68",
            "stage_id": "R24D68-BEHAVIOR",
            "closure_status": STATUS,
            "ledger_scope.subsystem": "recovery",
            "ledger_scope.engine_scope": "godot_jolt",
            "ledger_scope.authority_mode": "physical_development_closure",
            "ledger_scope.question_class": "development",
            "question_class": "development",
            "physical_question_declared": True,
            "behavior_success_required_for_execution_validity": False,
            "superiority_question_declared": False,
            "equivalence_or_non_inferiority_question_declared": False,
            "population_inference_declared": False,
            "source.commit": SOURCE,
            "source.parent_commit": (
                "2a088cb21e6734f5f56a31e2c590a3dfee09e8f7"
            ),
            "source.tree": "4c057c55b2b7ab6879670458d67faff3261c8836",
            "source.subject": "[recovery/godot] Close R68: publication control",
        },
        "CLOSURE",
    )
    exact(
        git(ROOT, "show", "-s", "--format=%P", SOURCE),
        closure["source"]["parent_commit"],
        "SOURCE_PARENT",
    )
    exact(
        git(ROOT, "show", "-s", "--format=%T", SOURCE),
        closure["source"]["tree"],
        "SOURCE_TREE",
    )
    exact(
        git(ROOT, "show", "-s", "--format=%s", SOURCE),
        closure["source"]["subject"],
        "SOURCE_SUBJECT",
    )
    bound = {
        item["path"]: verify_source_binding(ROOT, SOURCE, item)
        for item in closure["source"]["bindings"]
    }

    physical = closure["physical_attempt"]
    values = verify_supervised_bounded_ghost_attempt(
        physical=physical,
        gate_id="QSDK-R24D68",
        source_commit=SOURCE,
        status="invalid_or_incomplete_behavior_development",
        schemas={
            "attempt": "sporespore_qsdk_r24d68_behavior_attempt_v1",
            "raw": (
                "sporespore_qsdk_r24d68_godot_strict_actuator_budget_raw_v1"
            ),
            "terminal": "sporespore_qsdk_r24d68_behavior_terminal_v1",
        },
        raw_count_keys=(
            "model_construction_count",
            "world_attempt_count",
            "world_build_count",
            "solver_step_count",
            "behavior_evaluator_invocation_count",
            "held_out_cell_access_count",
        ),
    )
    raw, terminal = values["raw"], values["terminal"]
    verify_exact_paths(
        raw,
        {
            "failure_code": physical["outer_failure_code"],
            "detail.failure_code": physical["route_failure_code"],
            "detail.detail.schema_version": (
                "sporespore_qsdk_r24d68_godot_native_motor_telemetry_"
                "contract_v2"
            ),
            "detail.detail.actuator_id": "rear_left_hip_motor",
            "detail.detail.telemetry.max_torque_limit_nm": MAX_TORQUE,
            "detail.detail.telemetry.solver_step_s": SOLVER_STEP,
            "detail.detail.telemetry.signed_motor_impulse_nms": MEASURED,
            "detail.detail.strict_actuator_budget_diagnostic."
            "published_maximum_outer_step_impulse_nms": PUBLISHED,
            "detail.detail.strict_actuator_budget_diagnostic."
            "signed_motor_impulse_nms": MEASURED,
            "detail.detail.strict_actuator_budget_diagnostic."
            "legacy_v1_budget_predicate_decision": True,
            "detail.detail.strict_actuator_budget_diagnostic."
            "native_v2_strict_budget_decision": False,
            "detail.detail.strict_actuator_budget_diagnostic."
            "projected_core_strict_budget_decision": False,
            "detail.detail.strict_actuator_budget_diagnostic."
            "native_core_budget_decisions_agree": True,
            "model_construction_attempt_count": 1,
            "model_construction_count": 1,
            "world_attempt_count": 1,
            "world_build_count": 1,
            "solver_step_count": 90,
            "maximum_solver_step_count": 2400,
            "behavior_evaluator_invocation_count": 0,
            "held_out_cell_access_count": 0,
            "physical_question_opened": True,
            "physics_state_modified": True,
            "physics_failure_is_valid_evidence": True,
            "recovery_success_required_for_valid_result": False,
        },
        "RAW_RESULT",
    )
    projection = raw["strict_host_cap_projection_by_actuator_id"]
    exact(len(projection), 8, "HOST_PROJECTION_COUNT")
    rear = projection["rear_left_hip_motor"]
    verify_exact_paths(
        rear,
        {
            "configured_host_maximum_impulse_nms": CONFIGURED,
            "configured_host_cap_binary32_hex": "0x3d66e828",
            "host_cap_readback_nms": CONFIGURED,
            "published_maximum_outer_step_impulse_nms": PUBLISHED,
            "nearest_binary32_cap_nms": MEASURED,
            "nearest_binary32_rounds_above_published": True,
            "binary32_floor_guard_applied": True,
            "configured_host_cap_not_above_published": True,
            "published_cap_changed": False,
            "measurement_clamped": False,
        },
        "REAR_HOST_PROJECTION",
    )
    verify_exact_paths(
        terminal,
        {
            "physical_question_kind": "behavior_development",
            "integration_ghost_passed": False,
            "behavior_development_completed": False,
            "completed_utc": physical["completed_utc"],
            "worker.termination_protocol_failure_code": "",
            "recovery_success_observed": False,
        },
        "TERMINAL",
    )

    evidence = Path(physical["evidence_root"])
    stdout = (evidence / "godot.stdout.log").read_text(encoding="utf-8")
    require_ordered_markers(
        stdout,
        (
            "Godot Engine v4.7.stable.custom_build",
            "QSDK_R24D68_GODOT_STRICT_ACTUATOR_BUDGET_RAW ",
            physical["route_failure_code"],
            physical["outer_failure_code"],
            "QSDK_R24D68_GODOT_SUPERVISOR_TERMINATION_READY ",
        ),
        "STDOUT",
    )

    world = bound[
        "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
    ].decode()
    core = bound["sdk/core/src/recovery_runtime.rs"].decode()
    jolt_patch = bound[
        "sdk/adapters/godot/engine_patches/"
        "godot_4_7_jolt_motor_telemetry_active_step_snapshot_v2.patch"
    ].decode()
    require_ordered_markers(
        world,
        (
            "static func strict_host_impulse_cap_projection_v1(",
            '"configured_host_cap_not_above_published"',
            "static func native_motor_telemetry_contract_v2(",
            "absolute_impulse <= maximum_outer_step_impulse_nms",
            '"native_core_budget_decisions_agree"',
        ),
        "R68_NATIVE_ROUTE",
    )
    require_ordered_markers(
        core,
        (
            'finite(item.applied_angular_impulse_nms, "applied_angular_impulse")?;',
            "if item.applied_angular_impulse_nms.abs() > cap.maximum_outer_step_impulse_nms",
            '"published_actuator_budget_exceeded:{}"',
        ),
        "CORE_STRICT_PREDICATE",
    )
    require_ordered_markers(
        jolt_patch,
        (
            "mMotorTelemetryStep = inDeltaTime;",
            "mMotorTelemetryMaxTorqueLimit = mMotorSettings.mMaxTorqueLimit;",
            "inDeltaTime * mMotorSettings.mMinTorqueLimit, inDeltaTime * mMotorSettings.mMaxTorqueLimit",
            "GetTotalLambdaMotor()",
        ),
        "JOLT_NATIVE_LIMIT_AND_MEASUREMENT",
    )

    exact(f32(CONFIGURED / (1.0 / 120.0)), MAX_TORQUE, "HOST_TO_TORQUE")
    exact(f32(MAX_TORQUE * SOLVER_STEP), MEASURED, "NATIVE_EFFECTIVE_LIMIT")
    exact(f32_hex(CONFIGURED), "0x3d66e828", "CONFIGURED_BITS")
    exact(f32_hex(MAX_TORQUE), "0x40d879a6", "TORQUE_BITS")
    exact(f32_hex(SOLVER_STEP), "0x3c088889", "STEP_BITS")
    exact(f32_hex(MEASURED), "0x3d66e829", "MEASURED_BITS")
    exact(
        struct.unpack("<I", struct.pack("<f", MEASURED))[0]
        - struct.unpack("<I", struct.pack("<f", CONFIGURED))[0],
        1,
        "CONFIGURED_TO_MEASURED_ULPS",
    )
    exact(MEASURED - PUBLISHED, 6.351814976768289e-10, "PUBLISHED_DELTA")
    exact(MEASURED - CONFIGURED, 3.725290298461914e-9, "HOST_DELTA")

    verify_exact_paths(
        closure["causal_diagnosis"],
        {
            "classification": (
                "candidate_step_90_one_binary32_ulp_native_effective_limit_"
                "reexpansion"
            ),
            "r67_predicate_mismatch_repaired": True,
            "native_and_core_strict_predicates_agreed": True,
            "both_strict_predicates_refused": True,
            "exact_rejected_measurement_retained": True,
            "configured_host_cap_readback_below_published": True,
            "configured_host_cap_binary32_hex": "0x3d66e828",
            "measured_impulse_binary32_hex": "0x3d66e829",
            "configured_to_measured_binary32_ulp_distance": 1,
            "native_effective_limit_nms": MEASURED,
            "native_effective_limit_equals_float32_solver_step_times_float32_max_torque": True,
            "native_effective_limit_equals_measured_impulse": True,
            "host_impulse_divided_by_nominal_step_then_binary32_equals_native_max_torque": True,
            "jolt_source_formula_bound": True,
            "r68_host_parameter_floor_was_not_an_effective_native_impulse_bound": True,
            "r68_projection_inadequacy_established_for_observed_rear_left_hip_saturation": True,
            "behavior_physics_failure_established": False,
            "controller_failure_established": False,
            "recovery_result_established": False,
            "distinct_successor_required": True,
            "successor_projection_rule_selected": True,
            "additional_physical_calibration_required": False,
        },
        "CAUSE",
    )
    verify_boolean_partition(
        closure["decision"], DECISION_TRUE, DECISION_FALSE, "DECISION"
    )
    verify_boolean_partition(
        closure["claim_boundary"], CLAIM_TRUE, CLAIM_FALSE, "CLAIM"
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
            "gate_id": "QSDK-R24D69",
            "ledger_prefix": "[recovery/godot]",
            "question_class": "development",
            "physical_question_declared": False,
            "physical_execution_blocked": True,
            "maximum_world_attempt_count": 0,
            "maximum_world_build_count": 0,
            "maximum_physical_steps_authorized": 0,
            "complete_zero_world_gate_required": True,
            "distinct_clean_pushed_source_required": True,
            "complete_eight_actuator_projection_required": True,
            "native_effective_limit_formula_required": True,
            "strict_published_caps_preserved": True,
            "strict_native_core_predicates_preserved": True,
            "raw_measurement_clamping_permitted": False,
            "published_budget_change_permitted": False,
            "full_seeded_ghost_required": False,
            "additional_physical_canary_required": False,
            "additional_physical_calibration_required": False,
            "r24d68_may_be_rerun_or_requalified": False,
        },
        "NEXT",
    )

    relative = CLOSURE.relative_to(ROOT).as_posix()
    publication = git(
        ROOT, "log", "-1", "--diff-filter=A", "--format=%H", "--", relative
    )
    revision = publication or None
    raw_closure = (
        CLOSURE.read_bytes()
        if revision is None
        else source_bytes(ROOT, revision, relative)
    )
    verify_legacy_live_gate_paths(
        ROOT,
        closure["live_authority_paths"],
        "QSDK-R24D45",
        {
            **closure["live_gate_expectations"],
            "r24d68_behavior_invalid_closure_raw_sha256": sha256(raw_closure),
        },
        revision=revision,
    )
    print(
        "QSDK_R24D68_GODOT_STRICT_ACTUATOR_BUDGET_BEHAVIOR_INVALID_"
        "CLOSURE_PASS attempts=1 models=1 worlds=1 steps=90 evaluator=0 "
        "strict_agreement=1 ulp_reexpansion=1 next=R24D69 sdk1=11/20"
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
            "QSDK_R24D68_GODOT_STRICT_ACTUATOR_BUDGET_BEHAVIOR_"
            f"INVALID_CLOSURE_FAIL {error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
