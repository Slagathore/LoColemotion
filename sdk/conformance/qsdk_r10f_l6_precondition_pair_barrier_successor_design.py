#!/usr/bin/env python3
"""Audit the prospective QSDK-R10F-L6 pair-barrier design at zero worlds."""

from __future__ import annotations

import hashlib
import json
import subprocess
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
DESIGN_PATH = (
    ROOT / "sdk/qsdk_r10f_l6_precondition_pair_barrier_successor_design_v1.json"
)
PREDECESSOR_DESIGN_PATH = (
    ROOT / "sdk/qsdk_r10f_continuous_passive_fall_recovery_successor_design_v1.json"
)
L5_CLOSURE_PATH = (
    ROOT / "sdk/qsdk_r10f_development_route_ghost_physical_closure_v6.json"
)
EXPECTED_ROOT = "C:/Users/Cole/CodeStuff/games/SporeSpore"
EXPECTED_REMOTE = "https://github.com/Slagathore/sporespore.git"
GATE_ID = "QSDK-R10F"
REPAIR_ID = "QSDK-R10F-L6"
ACTIVE_ARM = "kick_passive_recovery_resume"
BASELINE_ARM = "matched_no_kick_continuation"
ARM_IDS = (BASELINE_ARM, ACTIVE_ARM)
JOINT_IDS = (
    "front_left_hip",
    "front_left_knee",
    "front_right_hip",
    "front_right_knee",
    "rear_left_hip",
    "rear_left_knee",
    "rear_right_hip",
    "rear_right_knee",
)
PASS_MARKER = "QSDK_R10F_L6_PRECONDITION_PAIR_BARRIER_SUCCESSOR_DESIGN_PASS "


class DesignFailure(RuntimeError):
    """Raised when a design or a zero-world control fails closed."""


def require(condition: bool, code: str) -> None:
    if not condition:
        raise DesignFailure(code)


def _reject_duplicate_pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise DesignFailure(f"DUPLICATE_JSON_KEY:{key}")
        result[key] = value
    return result


def read_json(path: Path) -> dict[str, Any]:
    require(path.is_file(), f"JSON_MISSING:{path.as_posix()}")
    try:
        value = json.loads(
            path.read_text(encoding="utf-8"), object_pairs_hook=_reject_duplicate_pairs
        )
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise DesignFailure(f"JSON_INVALID:{path.as_posix()}:{exc}") from exc
    require(type(value) is dict, f"JSON_ROOT_NOT_OBJECT:{path.as_posix()}")
    return value


def identity(path: Path) -> dict[str, Any]:
    raw = path.read_bytes()
    return {
        "path": path.relative_to(ROOT).as_posix(),
        "byte_length": len(raw),
        "raw_sha256": "sha256:" + hashlib.sha256(raw).hexdigest(),
    }


def canonical_sha256(value: dict[str, Any]) -> str:
    raw = json.dumps(value, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return "sha256:" + hashlib.sha256(raw).hexdigest()


def is_sha256(value: Any) -> bool:
    if type(value) is not str or not value.startswith("sha256:") or len(value) != 71:
        return False
    return all(character in "0123456789abcdef" for character in value[7:])


def exact_int(value: Any, expected: int | None = None) -> bool:
    return type(value) is int and (expected is None or value == expected)


def git_text(*arguments: str) -> str:
    result = subprocess.run(
        ["git", *arguments],
        cwd=ROOT,
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    require(result.returncode == 0, f"GIT_FAILED:{arguments[0]}")
    return result.stdout.strip()


def terminal_source(
    arm_id: str,
    global_step: int,
    *,
    terminal_phase: str = "complete",
    stable: bool = True,
) -> dict[str, Any]:
    fill = "a" if arm_id == ACTIVE_ARM else "b"
    return {
        "schema_version": "sporespore_qsdk_r10f_precondition_terminal_source_v1",
        "gate_id": GATE_ID,
        "repair_id": REPAIR_ID,
        "attempt_id": "0" * 32,
        "arm_id": arm_id,
        "model_instance_id": f"zero-world-{arm_id}",
        "global_semantic_step": global_step,
        "recovery_controller_id": "sporespore_exact_s169_prone_to_standing_controller_v6",
        "terminal_phase": terminal_phase,
        "stable_four_foot_stance": stable,
        "step_receipt_sha256": "sha256:" + fill * 64,
        "classification_sha256": "sha256:" + ("c" if fill == "a" else "d") * 64,
        "source_measurement": True,
        "outcome_derived_readiness": False,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "native_readback_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def terminal_source_valid(
    source: dict[str, Any], expected_arm: str, expected_step: int
) -> bool:
    expected_keys = {
        "schema_version",
        "gate_id",
        "repair_id",
        "attempt_id",
        "arm_id",
        "model_instance_id",
        "global_semantic_step",
        "recovery_controller_id",
        "terminal_phase",
        "stable_four_foot_stance",
        "step_receipt_sha256",
        "classification_sha256",
        "source_measurement",
        "outcome_derived_readiness",
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "native_readback_count",
        "solver_step_count",
        "physics_state_modified",
        "physical_acceptance_authority",
        "release_authority",
    }
    return (
        set(source) == expected_keys
        and source.get("schema_version")
        == "sporespore_qsdk_r10f_precondition_terminal_source_v1"
        and source.get("gate_id") == GATE_ID
        and source.get("repair_id") == REPAIR_ID
        and source.get("attempt_id") == "0" * 32
        and source.get("arm_id") == expected_arm
        and source.get("model_instance_id") == f"zero-world-{expected_arm}"
        and exact_int(source.get("global_semantic_step"), expected_step)
        and source.get("recovery_controller_id")
        == "sporespore_exact_s169_prone_to_standing_controller_v6"
        and source.get("terminal_phase") == "complete"
        and source.get("stable_four_foot_stance") is True
        and is_sha256(source.get("step_receipt_sha256"))
        and is_sha256(source.get("classification_sha256"))
        and source.get("source_measurement") is True
        and source.get("outcome_derived_readiness") is False
        and all(
            exact_int(source.get(field), 0)
            for field in (
                "model_construction_count",
                "world_attempt_count",
                "world_build_count",
                "native_readback_count",
                "solver_step_count",
            )
        )
        and source.get("physics_state_modified") is False
        and source.get("physical_acceptance_authority") is False
        and source.get("release_authority") is False
    )


def barrier_application(
    arm_id: str, global_step: int, terminal_source_sha256: str, action_kind: str
) -> dict[str, Any]:
    return {
        "schema_version": "sporespore_qsdk_r10f_precondition_pair_barrier_application_v1",
        "gate_id": GATE_ID,
        "repair_id": REPAIR_ID,
        "attempt_id": "0" * 32,
        "arm_id": arm_id,
        "global_semantic_step": global_step,
        "action_kind": action_kind,
        "terminal_source_sha256": terminal_source_sha256,
        "ordered_motor_readbacks": [
            {
                "joint_id": joint_id,
                "motor_enabled": False,
                "motor_target_velocity_rad_s": 0.0,
            }
            for joint_id in JOINT_IDS
        ],
        "control_owner": "none",
        "actuation_owner": "none",
        "no_actuation_requested": True,
        "source_measurement": True,
        "outcome_derived_readiness": False,
        "body_transform_write_count": 0,
        "body_velocity_write_count": 0,
        "solver_reset_count": 0,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def barrier_application_valid(
    application: dict[str, Any],
    expected_arm: str,
    expected_step: int,
    expected_kind: str,
) -> bool:
    expected_keys = {
        "schema_version",
        "gate_id",
        "repair_id",
        "attempt_id",
        "arm_id",
        "global_semantic_step",
        "action_kind",
        "terminal_source_sha256",
        "ordered_motor_readbacks",
        "control_owner",
        "actuation_owner",
        "no_actuation_requested",
        "source_measurement",
        "outcome_derived_readiness",
        "body_transform_write_count",
        "body_velocity_write_count",
        "solver_reset_count",
        "physical_acceptance_authority",
        "release_authority",
    }
    rows = application.get("ordered_motor_readbacks")
    return (
        set(application) == expected_keys
        and application.get("schema_version")
        == "sporespore_qsdk_r10f_precondition_pair_barrier_application_v1"
        and application.get("gate_id") == GATE_ID
        and application.get("repair_id") == REPAIR_ID
        and application.get("attempt_id") == "0" * 32
        and application.get("arm_id") == expected_arm
        and exact_int(application.get("global_semantic_step"), expected_step)
        and application.get("action_kind") == expected_kind
        and expected_kind in {"wait", "release"}
        and is_sha256(application.get("terminal_source_sha256"))
        and type(rows) is list
        and len(rows) == len(JOINT_IDS)
        and all(
            type(row) is dict
            and set(row)
            == {
                "joint_id",
                "motor_enabled",
                "motor_target_velocity_rad_s",
            }
            and row.get("joint_id") == JOINT_IDS[index]
            and row.get("motor_enabled") is False
            and type(row.get("motor_target_velocity_rad_s")) is float
            and row.get("motor_target_velocity_rad_s") == 0.0
            for index, row in enumerate(rows)
        )
        and application.get("control_owner") == "none"
        and application.get("actuation_owner") == "none"
        and application.get("no_actuation_requested") is True
        and application.get("source_measurement") is True
        and application.get("outcome_derived_readiness") is False
        and all(
            exact_int(application.get(field), 0)
            for field in (
                "body_transform_write_count",
                "body_velocity_write_count",
                "solver_reset_count",
            )
        )
        and application.get("physical_acceptance_authority") is False
        and application.get("release_authority") is False
    )


def simulate(active_terminal_step: int, baseline_terminal_step: int) -> dict[str, Any]:
    require(1 <= active_terminal_step <= 1200, "SIM_ACTIVE_TERMINAL_STEP")
    require(1 <= baseline_terminal_step <= 1200, "SIM_BASELINE_TERMINAL_STEP")
    terminal_steps = {
        ACTIVE_ARM: active_terminal_step,
        BASELINE_ARM: baseline_terminal_step,
    }
    ready: dict[str, dict[str, Any] | None] = {arm_id: None for arm_id in ARM_IDS}
    wait_counts = {arm_id: 0 for arm_id in ARM_IDS}
    rows: list[dict[str, Any]] = []
    last_terminal = max(terminal_steps.values())
    for global_step in range(1, last_terminal + 1):
        actions: dict[str, str] = {}
        for arm_id in ARM_IDS:
            if ready[arm_id] is None:
                actions[arm_id] = "recovery"
                if global_step == terminal_steps[arm_id]:
                    source = terminal_source(arm_id, global_step)
                    require(
                        terminal_source_valid(source, arm_id, global_step),
                        f"SIM_TERMINAL_SOURCE:{arm_id}",
                    )
                    ready[arm_id] = source
            else:
                actions[arm_id] = "wait"
                wait_counts[arm_id] += 1
                source = ready[arm_id]
                assert source is not None
                application = barrier_application(
                    arm_id, global_step, canonical_sha256(source), "wait"
                )
                require(
                    barrier_application_valid(application, arm_id, global_step, "wait"),
                    f"SIM_WAIT_APPLICATION:{arm_id}",
                )
        rows.append({"global_semantic_step": global_step, "actions": actions})
    require(all(ready.values()), "SIM_PAIR_NOT_READY")
    active_source = ready[ACTIVE_ARM]
    baseline_source = ready[BASELINE_ARM]
    assert active_source is not None and baseline_source is not None
    require(
        canonical_sha256(active_source) != canonical_sha256(baseline_source),
        "SIM_COPIED_TERMINAL_SOURCE",
    )
    release_step = last_terminal + 1
    release_applications: dict[str, dict[str, Any]] = {}
    for arm_id in ARM_IDS:
        source = ready[arm_id]
        assert source is not None
        application = barrier_application(
            arm_id, release_step, canonical_sha256(source), "release"
        )
        require(
            barrier_application_valid(application, arm_id, release_step, "release"),
            f"SIM_RELEASE_APPLICATION:{arm_id}",
        )
        release_applications[arm_id] = application
    return {
        "active_terminal_step": active_terminal_step,
        "baseline_terminal_step": baseline_terminal_step,
        "last_terminal_step": last_terminal,
        "release_global_step": release_step,
        "walking_prefix_first_global_step": release_step + 1,
        "wait_step_count_by_arm": wait_counts,
        "common_release": all(
            application["global_semantic_step"] == release_step
            and application["action_kind"] == "release"
            for application in release_applications.values()
        ),
        "rows": rows,
    }


def negative_controls() -> dict[str, bool]:
    active = terminal_source(ACTIVE_ARM, 240)
    baseline = terminal_source(BASELINE_ARM, 241)
    controls: dict[str, bool] = {}

    wrong_arm = dict(active)
    wrong_arm["arm_id"] = BASELINE_ARM
    controls["wrong_arm_terminal_source_refused"] = not terminal_source_valid(
        wrong_arm, ACTIVE_ARM, 240
    )

    controls["copied_terminal_source_refused"] = canonical_sha256(
        active
    ) == canonical_sha256(dict(active)) and canonical_sha256(
        active
    ) != canonical_sha256(
        baseline
    )

    ready_by_arm = {ACTIVE_ARM: canonical_sha256(active), BASELINE_ARM: ""}
    duplicate_before = dict(ready_by_arm)
    duplicate_attempt_refused = bool(duplicate_before[ACTIVE_ARM])
    controls["duplicate_terminal_source_refused"] = duplicate_attempt_refused

    stale = dict(active)
    stale["global_semantic_step"] = 239
    controls["stale_or_future_terminal_step_refused"] = not terminal_source_valid(
        stale, ACTIVE_ARM, 240
    )

    noncomplete = dict(active)
    noncomplete["terminal_phase"] = "failed"
    controls["noncomplete_terminal_source_refused"] = not terminal_source_valid(
        noncomplete, ACTIVE_ARM, 240
    )

    unstable = dict(active)
    unstable["stable_four_foot_stance"] = False
    controls["unstable_terminal_source_refused"] = not terminal_source_valid(
        unstable, ACTIVE_ARM, 240
    )

    wait = barrier_application(ACTIVE_ARM, 241, canonical_sha256(active), "wait")
    enabled = json.loads(json.dumps(wait))
    enabled["ordered_motor_readbacks"][0]["motor_enabled"] = True
    controls["enabled_motor_wait_refused"] = not barrier_application_valid(
        enabled, ACTIVE_ARM, 241, "wait"
    )

    nonzero = json.loads(json.dumps(wait))
    nonzero["ordered_motor_readbacks"][0]["motor_target_velocity_rad_s"] = 0.1
    controls["nonzero_target_velocity_wait_refused"] = not barrier_application_valid(
        nonzero, ACTIVE_ARM, 241, "wait"
    )

    actuated = json.loads(json.dumps(wait))
    actuated["actuation_owner"] = "recovery_v6"
    actuated["no_actuation_requested"] = False
    controls["actuation_owned_wait_refused"] = not barrier_application_valid(
        actuated, ACTIVE_ARM, 241, "wait"
    )

    controls["release_before_both_ready_refused"] = not all(ready_by_arm.values())

    active_release = barrier_application(
        ACTIVE_ARM, 242, canonical_sha256(active), "release"
    )
    baseline_wait = barrier_application(
        BASELINE_ARM, 242, canonical_sha256(baseline), "wait"
    )
    controls["asymmetric_release_refused"] = (
        active_release["action_kind"] != baseline_wait["action_kind"]
    )

    outcome_derived = dict(active)
    outcome_derived["outcome_derived_readiness"] = True
    controls["outcome_derived_readiness_refused"] = not terminal_source_valid(
        outcome_derived, ACTIVE_ARM, 240
    )
    return controls


def audit() -> dict[str, Any]:
    require(
        git_text("rev-parse", "--show-toplevel").replace("\\", "/") == EXPECTED_ROOT,
        "ROOT",
    )
    require(git_text("remote", "get-url", "origin") == EXPECTED_REMOTE, "REMOTE")

    design = read_json(DESIGN_PATH)
    predecessor = read_json(PREDECESSOR_DESIGN_PATH)
    closure = read_json(L5_CLOSURE_PATH)
    predecessor_identity = identity(PREDECESSOR_DESIGN_PATH)
    closure_identity = identity(L5_CLOSURE_PATH)

    require(
        design.get("schema_version")
        == "sporespore_qsdk_r10f_l6_precondition_pair_barrier_successor_design_v1",
        "DESIGN_SCHEMA",
    )
    require(
        design.get("status") == "prospective_zero_world_implementation_authorized",
        "STATUS",
    )
    require(design.get("gate_id") == GATE_ID, "GATE")
    require(design.get("repair_id") == REPAIR_ID, "REPAIR")
    require(design.get("question_class") == "development", "QUESTION_CLASS")
    require(
        design.get("ledger_scope")
        == {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "prospective_successor_design",
            "question_class": "development",
        },
        "LEDGER_SCOPE",
    )
    require(
        design.get("predecessor_design", {}).get("path")
        == predecessor_identity["path"],
        "PREDECESSOR_PATH",
    )
    require(
        design.get("predecessor_design", {}).get("byte_length")
        == predecessor_identity["byte_length"],
        "PREDECESSOR_BYTES",
    )
    require(
        design.get("predecessor_design", {}).get("raw_sha256")
        == predecessor_identity["raw_sha256"],
        "PREDECESSOR_SHA",
    )
    require(predecessor.get("gate_id") == GATE_ID, "PREDECESSOR_GATE")
    require(
        design.get("predecessor_design", {}).get("superseded") is False,
        "PREDECESSOR_SUPERSEDED",
    )

    consumed = design.get("consumed_l5_physical_closure", {})
    require(consumed.get("path") == closure_identity["path"], "L5_PATH")
    require(consumed.get("byte_length") == closure_identity["byte_length"], "L5_BYTES")
    require(consumed.get("raw_sha256") == closure_identity["raw_sha256"], "L5_SHA")
    for field in (
        "status",
        "classification",
        "attempt_id",
        "source_commit",
        "stage_commit",
        "authority_commit",
        "authority_sha256",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
        "failure_code",
        "same_identity_rerun_permitted",
        "physical_acceptance_authority",
        "release_authority",
    ):
        require(consumed.get(field) == closure.get(field), f"L5_FIELD:{field}")
    require(consumed.get("external_kick_application_count") == 0, "L5_KICK_COUNT")
    require(
        consumed.get("behavior_evaluator_invocation_count") == 0, "L5_EVALUATOR_COUNT"
    )
    require(
        consumed.get("inner_failure_code") == "QSDK_R10F_PRECONDITION_NOT_LOCKSTEP",
        "L5_INNER_FAILURE",
    )
    require(closure.get("scientific_outcome") == "none", "L5_OUTCOME")

    diagnosis = design.get("retained_diagnosis", {})
    require(
        exact_int(diagnosis.get("last_completed_global_solver_frame"), 240),
        "DIAGNOSIS_FRAME",
    )
    require(
        diagnosis.get("both_worlds_advanced_once_per_completed_global_frame") is True,
        "DIAGNOSIS_LOCKSTEP",
    )
    require(
        diagnosis.get("active_phase_after_frame")
        == "canonical_prone_precondition_recovery",
        "DIAGNOSIS_ACTIVE_PHASE",
    )
    require(
        diagnosis.get("baseline_phase_after_frame")
        == "fresh_selected_policy_walking_prefix",
        "DIAGNOSIS_BASELINE_PHASE",
    )
    require(
        diagnosis.get("baseline_v6_stable_standing_terminal_observed") is True,
        "DIAGNOSIS_BASELINE_READY",
    )
    require(
        diagnosis.get("active_v6_stable_standing_terminal_observed") is False,
        "DIAGNOSIS_ACTIVE_READY",
    )
    require(
        diagnosis.get("solver_lockstep_failed") is False, "DIAGNOSIS_SOLVER_LOCKSTEP"
    )
    require(
        diagnosis.get("threshold_crossing_frame_lockstep_failed") is True,
        "DIAGNOSIS_THRESHOLD_LOCKSTEP",
    )
    require(diagnosis.get("behavior_question_reached") is False, "DIAGNOSIS_BEHAVIOR")

    change = design.get("controlled_change", {})
    for field in (
        "threshold_lockstep_not_required",
        "readiness_is_arm_local",
        "readiness_monotonic",
    ):
        require(change.get(field) is True, f"CHANGE_TRUE:{field}")
    for field in (
        "readiness_copy_between_arms_permitted",
        "readiness_from_later_outcome_permitted",
        "world_pause_or_step_skip_permitted",
        "body_transform_or_velocity_write_permitted",
        "solver_reset_permitted",
        "motor_enabled_during_wait_or_release_permitted",
        "nonzero_motor_target_during_wait_or_release_permitted",
        "pair_release_for_one_arm_only_permitted",
    ):
        require(change.get(field) is False, f"CHANGE_FALSE:{field}")

    frozen = design.get("frozen_behavioral_terms", {})
    require(
        exact_int(frozen.get("maximum_precondition_recovery_controller_steps"), 1200),
        "FROZEN_PRECONDITION",
    )
    require(exact_int(frozen.get("walking_prefix_steps"), 720), "FROZEN_PREFIX")
    require(
        exact_int(frozen.get("maximum_post_kick_recovery_epoch_steps"), 1200),
        "FROZEN_RECOVERY",
    )
    require(exact_int(frozen.get("walking_resume_steps"), 720), "FROZEN_RESUME")
    for field in (
        "threshold_values_changed",
        "policy_changed",
        "controller_changed",
        "model_or_material_changed",
        "kick_changed",
        "seed_changed",
        "evaluator_changed",
    ):
        require(frozen.get(field) is False, f"FROZEN_FALSE:{field}")

    envelope = design.get("bounded_execution_envelope", {})
    expected_envelope = {
        "maximum_development_campaign_attempt_count": 1,
        "maximum_world_count": 2,
        "maximum_precondition_global_frames_before_release": 1200,
        "maximum_early_arm_barrier_wait_steps": 1199,
        "barrier_release_solver_frame_count": 1,
        "predecessor_maximum_solver_steps_per_arm": 3841,
        "successor_maximum_solver_steps_per_arm": 3842,
        "predecessor_maximum_total_solver_steps": 7682,
        "successor_maximum_total_solver_steps": 7684,
        "solver_budget_delta_per_arm": 1,
    }
    for field, expected in expected_envelope.items():
        require(exact_int(envelope.get(field), expected), f"ENVELOPE:{field}")
    require(envelope.get("held_out_cells_accessible") is False, "ENVELOPE_HELD_OUT")
    require(envelope.get("same_identity_rerun_permitted") is False, "ENVELOPE_RERUN")

    scenarios = [
        simulate(240, 240),
        simulate(241, 240),
        simulate(240, 241),
        simulate(244, 240),
    ]
    require(all(row["common_release"] for row in scenarios), "POSITIVE_COMMON_RELEASE")
    require(
        all(
            row["release_global_step"] == row["last_terminal_step"] + 1
            for row in scenarios
        ),
        "POSITIVE_RELEASE_STEP",
    )
    require(
        all(
            row["walking_prefix_first_global_step"] == row["release_global_step"] + 1
            for row in scenarios
        ),
        "POSITIVE_PREFIX_STEP",
    )
    require(simulate(1200, 1)["release_global_step"] == 1201, "MAXIMUM_RELEASE_FRAME")
    require(1201 + 720 + 1 + 1200 + 720 == 3842, "MAXIMUM_SOLVER_BUDGET")

    controls = negative_controls()
    required_positive = design.get("required_positive_zero_world_controls")
    required_negative = design.get("required_negative_zero_world_controls")
    require(
        type(required_positive) is list and len(required_positive) == 4,
        "POSITIVE_DECLARATIONS",
    )
    require(
        type(required_negative) is list and set(required_negative) == set(controls),
        "NEGATIVE_DECLARATIONS",
    )
    require(all(controls.values()), "NEGATIVE_CONTROL_FAILED")

    sequence = design.get("forward_authority_sequence", {})
    require(
        sequence.get("physical_execution_authorized_by_design") is False,
        "DESIGN_PHYSICAL_AUTHORITY",
    )
    require(
        sequence.get("held_out_finite_decision_authorized") is False,
        "DESIGN_HELD_OUT_AUTHORITY",
    )
    claim = design.get("claim_boundary", {})
    require(claim.get("design_complete") is True, "CLAIM_DESIGN")
    require(
        claim.get("zero_world_implementation_authorized") is True,
        "CLAIM_IMPLEMENTATION",
    )
    for field in (
        "physical_execution_authorized",
        "event_triggered_passive_recovery_observed",
        "continuous_same_body_recovery_resume_observed",
        "force_aware_recovery",
        "force_aware_bracing",
        "arbitrary_fall_recovery",
        "cross_engine_push_recovery",
        "physical_acceptance_authority",
        "release_authority",
        "sdk1_m07_satisfied",
        "q_sdk_r10_satisfied",
        "scores_changed",
    ):
        require(claim.get(field) is False, f"CLAIM_FALSE:{field}")

    return {
        "schema_version": "sporespore_qsdk_r10f_l6_precondition_pair_barrier_successor_design_audit_v1",
        "gate_id": GATE_ID,
        "repair_id": REPAIR_ID,
        "ok": True,
        "ledger_scope": {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "zero_world_successor_design_audit",
            "question_class": "development",
        },
        "design": identity(DESIGN_PATH),
        "consumed_l5_physical_closure": closure_identity,
        "positive_sequence_control_count": len(scenarios),
        "negative_mutation_rejection_count": len(controls),
        "maximum_solver_steps_per_arm": 3842,
        "maximum_total_solver_steps": 7684,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "scene_tree_insertion_count": 0,
        "native_readback_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def main() -> int:
    try:
        receipt = audit()
    except (DesignFailure, OSError) as exc:
        print(f"QSDK_R10F_L6_PRECONDITION_PAIR_BARRIER_SUCCESSOR_DESIGN_FAIL {exc}")
        return 1
    print(PASS_MARKER + json.dumps(receipt, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
