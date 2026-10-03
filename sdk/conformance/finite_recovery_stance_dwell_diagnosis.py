#!/usr/bin/env python3
"""Reusable zero-world diagnosis of a retained recovery stance-dwell trace."""

from __future__ import annotations

from collections import defaultdict
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys
from typing import Any

from sdk.conformance.content_addressed_zero_world_closure import (
    ClosureAuditError,
    exact,
    require,
    source_bytes,
    verify_exact_paths,
    verify_legacy_live_authority_projection,
)


def _load_raw(path: Path, expected_length: int, expected_sha256: str) -> dict[str, Any]:
    raw = path.read_bytes()
    exact(
        (len(raw), "sha256:" + hashlib.sha256(raw).hexdigest()),
        (expected_length, expected_sha256),
        "STANCE_RAW_IDENTITY",
    )
    return json.loads(raw)


def _population(rows: list[tuple[int, dict[str, bool]]], key: str) -> dict[str, Any]:
    true_steps = [step for step, values in rows if values[key]]
    best_count = current_count = 0
    best_start = best_end = current_start = None
    for step, values in rows:
        if values[key]:
            current_start = step if current_count == 0 else current_start
            current_count += 1
            if current_count > best_count:
                best_count, best_start, best_end = current_count, current_start, step
        else:
            current_count, current_start = 0, None
    return {
        "pass_count": len(true_steps),
        "first_pass_semantic_step": true_steps[0] if true_steps else None,
        "last_pass_semantic_step": true_steps[-1] if true_steps else None,
        "longest_consecutive_pass_count": best_count,
        "longest_consecutive_pass_start_semantic_step": best_start,
        "longest_consecutive_pass_end_semantic_step": best_end,
    }


def stance_dwell_predicate_diagnosis_projection(
    raw: dict[str, Any], threshold_authority: dict[str, Any]
) -> dict[str, Any]:
    """Hash and summarize every frozen predicate over one complete dwell."""

    profile = threshold_authority["threshold_profile"]
    authority = {
        str(value["threshold_id"]): value["value"]
        for value in profile["thresholds"]
    }
    exact(raw["threshold_profile_id"], profile["profile_id"], "STANCE_PROFILE")
    exact(
        profile["post_outcome_rethresholding_permitted"],
        False,
        "STANCE_RETHRESHING_AUTHORITY",
    )
    frozen = {
        "stance_height_ratio_min": float(authority["stance_height_ratio_min"]),
        "stance_torso_up_dot_min": float(authority["stance_torso_up_dot_min"]),
        "minimum_nonfoot_clearance_m": float(
            authority["minimum_nonfoot_clearance_m"]
        ),
        "maximum_forbidden_contact_impulse_ns": float(
            authority["maximum_forbidden_contact_impulse_ns"]
        ),
        "maximum_terminal_linear_speed_m_s": float(
            authority["maximum_terminal_linear_speed_m_s"]
        ),
        "maximum_terminal_angular_speed_rad_s": float(
            authority["maximum_terminal_angular_speed_rad_s"]
        ),
        "maximum_energy_balance_residual_j": float(
            authority["maximum_energy_balance_residual_j"]
        ),
        "stance_dwell_steps": int(authority["stance_dwell_steps"]),
        "stance_dwell_timeout_steps": int(
            authority["per_phase_timeout_steps"]["stance_dwell"]
        ),
    }
    exact(raw["required_stance_dwell_steps"], frozen["stance_dwell_steps"], "DWELL")
    exact(raw["stance_dwell_timeout_steps"], frozen["stance_dwell_timeout_steps"], "TIMEOUT")

    arm = raw["candidate_arm"]
    receipts = arm["portable_step_receipts"]
    progressions = arm["development_progression_receipts"]
    observations = arm["trace_v3"]["observations"]
    exact(len(receipts), int(arm["outer_step_count"]), "STEP_COUNT")
    exact((len(progressions), len(observations)), (len(receipts), len(receipts)), "POPULATION_COUNT")

    predicate_rows: list[tuple[int, dict[str, bool]]] = []
    complete_rows: list[dict[str, Any]] = []
    numeric: defaultdict[str, list[float]] = defaultdict(list)
    for step, (receipt, progression, observation) in enumerate(
        zip(receipts, progressions, observations), start=1
    ):
        exact(int(observation["semantic_step"]), step, "OBSERVATION_ORDER")
        if receipt["prior_phase"] != "stance_dwell":
            continue
        value = receipt["classification"]
        flags = {
            "torso_height_ratio": float(value["torso_height_ratio"])
            >= frozen["stance_height_ratio_min"],
            "torso_up_dot": float(value["torso_up_dot"])
            >= frozen["stance_torso_up_dot_min"],
            "all_four_distal_sites_bearing": bool(
                value["all_four_distal_sites_bearing"]
            ),
            "no_nonfoot_contact": not bool(value["any_nonfoot_contact"]),
            "minimum_nonfoot_clearance": float(value["minimum_nonfoot_clearance_m"])
            >= frozen["minimum_nonfoot_clearance_m"],
            "terminal_linear_speed": float(value["terminal_linear_speed_m_s"])
            <= frozen["maximum_terminal_linear_speed_m_s"],
            "terminal_angular_speed": float(value["terminal_angular_speed_rad_s"])
            <= frozen["maximum_terminal_angular_speed_rad_s"],
            "exclusive_stance_handoff": bool(value["exclusive_stance_handoff_gate"]),
            "joint_limits": bool(value["joint_limits_respected"]),
            "actuator_budget": bool(value["actuator_budget_respected"]),
            "forbidden_contact_impulse": float(
                value["maximum_nonfoot_contact_impulse_ns"]
            )
            <= frozen["maximum_forbidden_contact_impulse_ns"],
            "no_cheat": bool(value["no_cheat_gate"]),
            "energy_balance": float(value["energy_balance_residual_j"])
            <= frozen["maximum_energy_balance_residual_j"],
        }
        safety = all(
            flags[key]
            for key in (
                "joint_limits",
                "actuator_budget",
                "forbidden_contact_impulse",
                "energy_balance",
            )
        )
        exact(bool(value["safety_gate"]), safety, "SAFETY_GATE")
        flags["nonenergy_stable"] = all(
            result for key, result in flags.items() if key != "energy_balance"
        )
        flags["legacy_stable_stance"] = all(
            result
            for key, result in flags.items()
            if key not in {"energy_balance", "nonenergy_stable"}
        ) and safety
        exact(
            bool(value["stable_stance_gate"]),
            flags["legacy_stable_stance"],
            "LEGACY_STANCE_GATE",
        )
        exact(bool(progression["legacy_safety_gate"]), safety, "PROGRESSION_SAFETY")
        exact(
            bool(progression["legacy_stable_stance_gate"]),
            flags["legacy_stable_stance"],
            "PROGRESSION_STANCE",
        )
        exact(
            bool(progression["development_nonenergy_safety_gate"]),
            all(
                flags[key]
                for key in (
                    "joint_limits",
                    "actuator_budget",
                    "forbidden_contact_impulse",
                    "no_cheat",
                )
            ),
            "PROGRESSION_NONENERGY",
        )
        flags["stable_stance_completion_authorized"] = bool(
            progression["stable_stance_completion_authorized"]
        )
        flags["formal_completion_eligible"] = (
            flags["legacy_stable_stance"]
            and flags["stable_stance_completion_authorized"]
        )
        predicate_rows.append((step, flags))
        values = {
            key: float(value[key])
            for key in (
                "torso_height_ratio",
                "torso_up_dot",
                "minimum_nonfoot_clearance_m",
                "terminal_linear_speed_m_s",
                "terminal_angular_speed_rad_s",
                "energy_balance_residual_j",
            )
        }
        require(all(math.isfinite(item) for item in values.values()), "FINITE")
        for key, item in values.items():
            numeric[key].append(item)
        complete_rows.append(
            {
                "semantic_step": step,
                "flags": flags,
                "values": values,
                "component_partition_complete": bool(
                    progression["component_partition_complete"]
                ),
                "exact_balance_safety_authority": bool(
                    progression["exact_balance_safety_authority"]
                ),
                "physical_result_authorized": bool(
                    progression["physical_result_authorized"]
                ),
                "stance_dwell_steps_observed": int(
                    receipt["memory"]["stance_dwell_steps_observed"]
                ),
            }
        )
    require(bool(predicate_rows), "STANCE_DWELL_POPULATION")
    encoded_rows = json.dumps(
        complete_rows, sort_keys=True, separators=(",", ":"), ensure_ascii=False
    ).encode("utf-8")
    predicates = {
        key: _population(predicate_rows, key) for key in predicate_rows[0][1]
    }
    nonenergy = predicates["nonenergy_stable"]
    population = {
        "semantic_step_first": predicate_rows[0][0],
        "semantic_step_last": predicate_rows[-1][0],
        "step_count": len(predicate_rows),
        "complete_row_population_canonical_byte_length": len(encoded_rows),
        "complete_row_population_canonical_sha256": (
            "sha256:" + hashlib.sha256(encoded_rows).hexdigest()
        ),
        "predicate_populations": predicates,
        "numeric_ranges": {
            key: {
                "first": values[0],
                "last": values[-1],
                "minimum": min(values),
                "maximum": max(values),
            }
            for key, values in sorted(numeric.items())
        },
        "maximum_memory_stance_dwell_steps_observed": max(
            row["stance_dwell_steps_observed"] for row in complete_rows
        ),
        "component_partition_complete_count": sum(
            row["component_partition_complete"] for row in complete_rows
        ),
        "exact_balance_safety_authority_count": sum(
            row["exact_balance_safety_authority"] for row in complete_rows
        ),
        "physical_result_authorized_count": sum(
            row["physical_result_authorized"] for row in complete_rows
        ),
        "nonenergy_stance_meets_required_dwell": (
            nonenergy["longest_consecutive_pass_count"] >= frozen["stance_dwell_steps"]
        ),
        "nonenergy_stance_required_dwell_multiple": (
            nonenergy["longest_consecutive_pass_count"] / frozen["stance_dwell_steps"]
        ),
    }
    return {
        "source_identity": {
            key: raw[key]
            for key in ("gate_id", "source_commit", "attempt_id", "seed", "seed_sha256")
        }
        | {
            "candidate_trace_v3_sha256": arm["trace_v3_sha256"],
            "threshold_profile_id": raw["threshold_profile_id"],
            "threshold_profile_sha256": raw["threshold_profile_sha256"],
        },
        "frozen_thresholds": frozen,
        "stance_dwell_population": population,
        "execution_counts": {
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
        },
    }


def validate_stance_dwell_predicate_diagnosis(
    root: Path,
    relative_path: str,
    schema: str,
    expected_sha256: str,
    expected_length: int,
    *,
    gate_id: str,
    next_gate_id: str,
    predecessor_gate_id: str,
    predecessor_decision_prefix: str,
    next_required_decision_key: str,
    live_record_key: str,
    live_identity_prefix: str,
    ignored_forward_live_keys: tuple[str, ...] = (),
) -> dict[str, Any]:
    diagnosis_raw = (root / relative_path).read_bytes()
    exact(
        (len(diagnosis_raw), "sha256:" + hashlib.sha256(diagnosis_raw).hexdigest()),
        (expected_length, expected_sha256),
        "DIAGNOSIS_IDENTITY",
    )
    diagnosis = json.loads(diagnosis_raw)
    verify_exact_paths(
        diagnosis,
        {
            "schema_version": schema,
            "gate_id": gate_id,
            "question_class": "development",
            "physical_question_declared": False,
            "finite_decision_declared": False,
            "superiority_question_declared": False,
            "equivalence_or_non_inferiority_question_declared": False,
            "population_inference_declared": False,
            "ledger_scope.subsystem": "recovery",
            "ledger_scope.engine_scope": "godot_jolt",
            "ledger_scope.authority_mode": "closed_zero_world_retained_stance_dwell_predicate_diagnosis",
            "ledger_scope.question_class": "development",
        },
        "DIAGNOSIS",
    )
    predecessor = diagnosis["predecessor"]
    closure_raw = (root / predecessor["physical_closure_path"]).read_bytes()
    exact(
        (len(closure_raw), "sha256:" + hashlib.sha256(closure_raw).hexdigest()),
        (
            predecessor["physical_closure_byte_length"],
            predecessor["physical_closure_raw_sha256"],
        ),
        "PHYSICAL_CLOSURE",
    )
    closure = json.loads(closure_raw)
    verify_exact_paths(
        closure,
        {
            "gate_id": predecessor_gate_id,
            "source.commit": predecessor["physical_source_commit"],
            "physical_attempt.status": "valid_complete_behavior_development",
            "physical_attempt.scientific_outcome": "negative",
            "physical_attempt.same_identity_rerun_permitted": False,
            "claim_boundary.all_in_run_physical_invariants_passed": True,
            "claim_boundary.prone_to_standing_claimed": False,
        },
        "PREDECESSOR",
    )
    artifact = closure["physical_attempt"]["artifacts"]["raw"]
    raw_path = Path(closure["physical_attempt"]["evidence_root"]) / artifact["path"]
    exact(str(raw_path).replace("\\", "/"), predecessor["raw_result_path"], "RAW_PATH")
    exact(
        (artifact["byte_length"], artifact["raw_sha256"]),
        (predecessor["raw_result_byte_length"], predecessor["raw_result_raw_sha256"]),
        "RAW_DECLARATION",
    )
    raw = _load_raw(
        raw_path,
        predecessor["raw_result_byte_length"],
        predecessor["raw_result_raw_sha256"],
    )
    threshold_binding = diagnosis["threshold_authority"]
    threshold_raw = (root / threshold_binding["path"]).read_bytes()
    exact(
        (len(threshold_raw), "sha256:" + hashlib.sha256(threshold_raw).hexdigest()),
        (threshold_binding["byte_length"], threshold_binding["raw_sha256"]),
        "THRESHOLD_AUTHORITY",
    )
    threshold_authority = json.loads(threshold_raw)
    verify_exact_paths(
        threshold_authority,
        {
            "threshold_profile.profile_id": threshold_binding["profile_id"],
            "threshold_profile.post_outcome_rethresholding_permitted": False,
        },
        "THRESHOLD_PATHS",
    )
    for binding in diagnosis["source_bindings"]:
        retained = source_bytes(
            root, predecessor["physical_source_commit"], binding["path"]
        )
        exact(
            (len(retained), "sha256:" + hashlib.sha256(retained).hexdigest()),
            (binding["byte_length"], binding["raw_sha256"]),
            f"SOURCE:{binding['path']}",
        )
        source = retained.decode("utf-8")
        require(
            all(marker in source for marker in binding["required_utf8_markers"]),
            f"SOURCE_MARKERS:{binding['path']}",
        )
    projection = stance_dwell_predicate_diagnosis_projection(raw, threshold_authority)
    encoded = json.dumps(
        projection, sort_keys=True, separators=(",", ":"), ensure_ascii=False
    ).encode("utf-8")
    exact(
        (len(encoded), "sha256:" + hashlib.sha256(encoded).hexdigest()),
        (
            diagnosis["computed_projection_canonical_byte_length"],
            diagnosis["computed_projection_canonical_sha256"],
        ),
        "PROJECTION_IDENTITY",
    )
    exact(projection, diagnosis["computed_projection"], "PROJECTION")
    verify_exact_paths(
        diagnosis,
        {
            f"decision.{predecessor_decision_prefix}_same_identity_rerun_permitted": False,
            f"decision.{predecessor_decision_prefix}_valid_complete_behavior_negative_preserved": True,
            "decision.nonenergy_stance_required_dwell_observed": True,
            "decision.energy_balance_threshold_changed": False,
            "decision.recovery_policy_changed": False,
            f"decision.{next_required_decision_key}": True,
            "decision.physical_execution_authorized": False,
            "decision.prone_to_standing_claimed": False,
            "decision.sdk1_milestone_advanced": False,
            "next_boundary.gate_id": next_gate_id,
            "next_boundary.physical_question_declared": False,
            "next_boundary.physical_execution_authorized": False,
            "next_boundary.maximum_world_build_count": 0,
            "next_boundary.maximum_physical_steps_authorized": 0,
            "claim_boundary.nonenergy_stance_required_dwell_observed": True,
            "claim_boundary.formal_stable_stance_observed": False,
            "claim_boundary.prone_to_standing_claimed": False,
            "claim_boundary.repeatability_claimed": False,
            "claim_boundary.population_claimed": False,
            "claim_boundary.physical_acceptance_authority": False,
            "claim_boundary.release_authority": False,
        },
        "DECISION",
    )
    expected_live = dict(diagnosis["live_authority_projection"])
    expected_live.pop("next_gate_id", None)
    for key in ignored_forward_live_keys:
        expected_live.pop(key, None)
    expected_live.update(
        {
            f"{live_identity_prefix}_path": relative_path,
            f"{live_identity_prefix}_raw_sha256": expected_sha256,
            f"{live_identity_prefix}_byte_length": expected_length,
        }
    )
    verify_legacy_live_authority_projection(
        root,
        tuple(diagnosis["live_authority_paths"]),
        record_key=live_record_key,
        expected=expected_live,
        prefix=f"LIVE_{gate_id.replace('-', '_')}_DIAGNOSIS",
    )
    require((root / diagnosis["closure_audit_path"]).is_file(), "AUDIT_PATH")
    return diagnosis


def run_stance_dwell_predicate_diagnosis_cli(
    root: Path,
    relative_path: str,
    schema: str,
    expected_sha256: str,
    expected_length: int,
    pass_marker: str,
    failure_marker: str,
    **scope: Any,
) -> int:
    try:
        diagnosis = validate_stance_dwell_predicate_diagnosis(
            root, relative_path, schema, expected_sha256, expected_length, **scope
        )
        population = diagnosis["computed_projection"]["stance_dwell_population"]
        predicates = population["predicate_populations"]
        print(
            pass_marker,
            json.dumps(
                {
                    "gate_id": diagnosis["gate_id"],
                    "ok": True,
                    "status": diagnosis["status"],
                    "stance_dwell_step_count": population["step_count"],
                    "nonenergy_stance_longest_consecutive_pass_count": predicates[
                        "nonenergy_stable"
                    ]["longest_consecutive_pass_count"],
                    "energy_balance_pass_count": predicates["energy_balance"][
                        "pass_count"
                    ],
                    "stable_stance_completion_authorized_count": predicates[
                        "stable_stance_completion_authorized"
                    ]["pass_count"],
                    "model_construction_count": 0,
                    "world_build_count": 0,
                    "solver_step_count": 0,
                    "prone_to_standing_claimed": False,
                    "sdk1_milestone_advanced": False,
                },
                sort_keys=True,
            ),
        )
        return 0
    except (
        ClosureAuditError,
        KeyError,
        OSError,
        subprocess.CalledProcessError,
        TypeError,
        ValueError,
    ) as error:
        print(f"{failure_marker}:{error}", file=sys.stderr)
        return 1
