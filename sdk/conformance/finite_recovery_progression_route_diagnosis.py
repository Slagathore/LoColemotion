#!/usr/bin/env python3
"""Reusable zero-world diagnosis for a declared recovery-route omission."""

from __future__ import annotations

from collections import Counter
import json
from pathlib import Path
import sys
from typing import Any, Sequence

from sdk.conformance.content_addressed_zero_world_closure import (
    ClosureAuditError,
    canonical_bytes,
    exact,
    git,
    loads,
    require,
    sha256,
    source_bytes,
    verify_exact_paths,
    verify_legacy_live_authority_projection,
)


def _development_nonenergy_safety_gate(classification: dict[str, Any]) -> bool:
    """Mirror the already-qualified R126 predicate without opening a world."""

    return (
        bool(classification.get("joint_limits_respected", False))
        and bool(classification.get("actuator_budget_respected", False))
        and float(classification.get("maximum_nonfoot_contact_impulse_ns", float("nan")))
        == 0.0
        and bool(classification.get("no_cheat_gate", False))
    )


def _arm_projection(arm: dict[str, Any]) -> dict[str, Any]:
    rows = arm["portable_step_receipts"]
    require(isinstance(rows, list) and bool(rows), "STEP_RECEIPT_POPULATION")
    exact(len(rows), int(arm["outer_step_count"]), "STEP_RECEIPT_COUNT")

    schemas = Counter(str(row.get("schema_version", "")) for row in rows)
    phase_counts = Counter(str(row.get("prior_phase", "")) for row in rows)
    progression_rows = arm.get("development_progression_receipts", [])
    require(isinstance(progression_rows, list), "PROGRESSION_RECEIPT_POPULATION")

    counts: Counter[str] = Counter()
    eligible: list[tuple[int, dict[str, Any], dict[str, Any]]] = []
    for semantic_step, row in enumerate(rows, start=1):
        require(isinstance(row, dict), "STEP_RECEIPT_OBJECT")
        classification = row.get("classification")
        require(isinstance(classification, dict), "STEP_CLASSIFICATION_OBJECT")
        nonenergy = _development_nonenergy_safety_gate(classification)
        flags = {
            "raised_body_gate": bool(classification.get("raised_body_gate", False)),
            "legacy_safety_gate": bool(classification.get("safety_gate", False)),
            "joint_limits_respected": bool(
                classification.get("joint_limits_respected", False)
            ),
            "actuator_budget_respected": bool(
                classification.get("actuator_budget_respected", False)
            ),
            "zero_nonfoot_contact_impulse": float(
                classification.get("maximum_nonfoot_contact_impulse_ns", float("nan"))
            )
            == 0.0,
            "no_cheat_gate": bool(classification.get("no_cheat_gate", False)),
            "development_nonenergy_safety_gate": nonenergy,
            "stable_stance_gate": bool(
                classification.get("stable_stance_gate", False)
            ),
        }
        counts.update(key for key, passed in flags.items() if passed)
        if flags["raised_body_gate"] and nonenergy:
            counts["r126_development_stance_handoff_input"] += 1
            eligible.append((semantic_step, row, classification))

    projection: dict[str, Any] = {
        "arm_kind": str(arm["arm_kind"]),
        "outer_step_count": len(rows),
        "portable_step_receipt_schema_counts": dict(sorted(schemas.items())),
        "prior_phase_counts": dict(sorted(phase_counts.items())),
        "retained_development_progression_receipt_count": len(progression_rows),
        "predicate_pass_counts": dict(sorted(counts.items())),
    }
    if eligible:
        semantic_step, row, classification = eligible[0]
        projection["first_r126_development_handoff_input"] = {
            "semantic_step": semantic_step,
            "prior_phase": str(row["prior_phase"]),
            "observed_next_phase": str(row["next_phase"]),
            "observed_transitioned": bool(row["transitioned"]),
            "raised_body_gate": bool(classification["raised_body_gate"]),
            "legacy_safety_gate": bool(classification["safety_gate"]),
            "joint_limits_respected": bool(
                classification["joint_limits_respected"]
            ),
            "actuator_budget_respected": bool(
                classification["actuator_budget_respected"]
            ),
            "maximum_nonfoot_contact_impulse_ns": float(
                classification["maximum_nonfoot_contact_impulse_ns"]
            ),
            "no_cheat_gate": bool(classification["no_cheat_gate"]),
            "energy_balance_residual_j": float(
                classification["energy_balance_residual_j"]
            ),
            "minimum_nonfoot_clearance_m": float(
                classification["minimum_nonfoot_clearance_m"]
            ),
            "terminal_linear_speed_m_s": float(
                classification["terminal_linear_speed_m_s"]
            ),
            "terminal_angular_speed_rad_s": float(
                classification["terminal_angular_speed_rad_s"]
            ),
        }
        projection["last_r126_development_handoff_input_semantic_step"] = eligible[-1][0]
    return projection


def progression_route_diagnosis_projection(
    raw: dict[str, Any],
    worker_source: bytes,
    r128_contract: dict[str, Any],
    r128_qualification: dict[str, Any],
    r129_contract: dict[str, Any],
) -> dict[str, Any]:
    """Recompute only facts fixed by retained source and retained observations."""

    verify_exact_paths(
        raw,
        {
            "gate_id": "QSDK-R24D129",
            "source_commit": "5565c033d713e45880d4ca4b33180861f6ab3805",
            "status": "valid_complete_behavior_development",
            "scientific_outcome": "negative",
            "recovery_controller_id": (
                "sporespore_exact_s169_prone_to_standing_controller_v6"
            ),
            "all_in_run_physical_invariants_passed": True,
            "model_construction_count": 2,
            "world_build_count": 2,
            "solver_step_count": 905,
            "prone_to_standing_claimed": False,
        },
        "R129_RAW",
    )
    verify_exact_paths(
        r128_contract,
        {
            "gate_id": "QSDK-R24D128",
            "controlled_change.energy_authority_development_progression_changed": True,
            "finite_development_population.purpose": (
                "observe_the_exact_consumed_r124_candidate_plus_matched_zero_cell_"
                "with_only_the_r127_qualified_v6_solver_coupled_realization_and_"
                "r126_development_progression"
            ),
        },
        "R128_CONTRACT",
    )
    verify_exact_paths(
        r128_qualification,
        {
            "gate_id": "QSDK-R24D128",
            "decision.r24d126_incomplete_energy_authority_progression_bound": True,
            "decision.physical_execution_authorized": True,
        },
        "R128_QUALIFICATION",
    )
    verify_exact_paths(
        r129_contract,
        {
            "gate_id": "QSDK-R24D129",
            "controlled_change.application_mutation_semantics_changed": True,
            "controlled_change.recovery_controller_changed": False,
            "controlled_change.physical_behavior_inputs_changed": False,
            "controlled_change.scientific_behavior_question_changed": False,
            "controlled_change.behavior_threshold_changed": False,
            "controlled_change.behavior_evaluator_changed": False,
        },
        "R129_CONTRACT",
    )

    source = worker_source.decode("utf-8")
    candidate = _arm_projection(raw["candidate_arm"])
    matched_zero = _arm_projection(raw["matched_zero_arm"])
    exact(
        candidate["outer_step_count"] + matched_zero["outer_step_count"],
        905,
        "ARM_STEP_TOTAL",
    )

    return {
        "declared_route": {
            "r128_declared_r126_development_progression": True,
            "r128_qualification_bound_r126_development_progression": True,
            "r129_changed_only_application_mutation_semantics": True,
            "r129_preserved_recovery_controller": True,
            "r129_preserved_physical_behavior_inputs": True,
            "r129_preserved_scientific_behavior_question": True,
        },
        "invocation_source": {
            "source_commit": str(raw["source_commit"]),
            "worker_path": (
                "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
            ),
            "prepare_context_v6_call_count": source.count(
                "RouteScript.prepare_context_v6("
            ),
            "initial_behavior_application_v6_call_count": source.count(
                "RouteScript.initial_behavior_application_v6("
            ),
            "advance_behavior_v4_call_count": source.count(
                ". advance_behavior_v4("
            ),
            "advance_behavior_v5_call_count": source.count(
                ". advance_behavior_v5("
            ),
        },
        "retained_route": {
            "candidate": candidate,
            "matched_zero": matched_zero,
            "total_portable_step_receipt_count": 905,
            "total_retained_development_progression_receipt_count": (
                int(candidate["retained_development_progression_receipt_count"])
                + int(matched_zero["retained_development_progression_receipt_count"])
            ),
        },
        "diagnostic_execution_counts": {
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
        },
    }


def _verify_binding(root: Path, binding: dict[str, Any]) -> dict[str, Any]:
    path = Path(str(binding["path"]))
    if not path.is_absolute():
        path = root / path
    raw = path.read_bytes()
    exact(len(raw), int(binding["byte_length"]), f"BINDING_LENGTH:{path}")
    exact(sha256(raw), str(binding["raw_sha256"]), f"BINDING_HASH:{path}")
    return loads(raw)


def run_cli(
    root: Path,
    diagnosis_relative_path: str,
    expected_schema: str,
    expected_raw_sha256: str,
    expected_byte_length: int,
    pass_marker: str,
    failure_marker: str,
    *,
    authority_paths: Sequence[str] = (
        "sdk/release/quadruped_release_contract.json",
        "sdk/release/quadruped_support_matrix.json",
    ),
) -> int:
    try:
        diagnosis_path = root / diagnosis_relative_path
        diagnosis_raw = diagnosis_path.read_bytes()
        exact(len(diagnosis_raw), expected_byte_length, "DIAGNOSIS_LENGTH")
        exact(sha256(diagnosis_raw), expected_raw_sha256, "DIAGNOSIS_HASH")
        diagnosis = loads(diagnosis_raw)
        exact(
            (diagnosis["schema_version"], diagnosis["gate_id"]),
            (expected_schema, "QSDK-R24D130"),
            "DIAGNOSIS_IDENTITY",
        )

        bindings = {
            str(value["id"]): value for value in diagnosis["bound_artifacts"]
        }
        exact(len(bindings), len(diagnosis["bound_artifacts"]), "BINDING_IDS")
        r128_contract = _verify_binding(root, bindings["r128_contract"])
        r128_qualification = _verify_binding(root, bindings["r128_qualification"])
        r129_contract = _verify_binding(root, bindings["r129_contract"])
        _verify_binding(root, bindings["r129_qualification"])
        _verify_binding(root, bindings["r129_physical_closure"])
        raw = _verify_binding(root, bindings["r129_raw_result"])

        source = diagnosis["invocation_source_binding"]
        worker_source = source_bytes(
            root, str(source["source_commit"]), str(source["path"])
        )
        exact(len(worker_source), source["byte_length"], "WORKER_SOURCE_LENGTH")
        exact(sha256(worker_source), source["raw_sha256"], "WORKER_SOURCE_HASH")
        exact(
            git(root, "rev-parse", f'{source["source_commit"]}:{source["path"]}'),
            source["git_blob_oid"],
            "WORKER_SOURCE_BLOB",
        )

        projection = progression_route_diagnosis_projection(
            raw,
            worker_source,
            r128_contract,
            r128_qualification,
            r129_contract,
        )
        exact(projection, diagnosis["computed_projection"], "COMPUTED_PROJECTION")
        encoded = canonical_bytes(projection)
        exact(
            len(encoded),
            diagnosis["computed_projection_canonical_byte_length"],
            "COMPUTED_PROJECTION_LENGTH",
        )
        exact(
            sha256(encoded),
            diagnosis["computed_projection_canonical_sha256"],
            "COMPUTED_PROJECTION_HASH",
        )
        verify_exact_paths(
            diagnosis,
            {
                "decision.r129_same_identity_rerun_permitted": False,
                "decision.r129_scientific_behavior_inference_accepted": False,
                "decision.r129_partial_physical_observations_preserved": True,
                "decision.r131_zero_world_route_correction_required": True,
                "decision.physical_execution_authorized": False,
                "decision.historical_result_rewritten": False,
                "decision.historical_interpretation_rewritten": False,
                "claim_boundary.r129_declared_behavior_question_answered": False,
                "claim_boundary.r129_infrastructure_route_omission_established": True,
                "claim_boundary.prone_to_standing_claimed": False,
                "claim_boundary.sdk1_milestone_advanced": False,
                "next_boundary.gate_id": "QSDK-R24D131",
                "next_boundary.maximum_world_build_count": 0,
                "next_boundary.maximum_solver_step_count": 0,
            },
            "DIAGNOSIS",
        )
        verify_legacy_live_authority_projection(
            root,
            authority_paths,
            record_key="r24d130_diagnosis_path",
            expected=diagnosis["live_authority_projection"],
            prefix="R130_LIVE_AUTHORITY",
        )
        print(
            pass_marker
            + " "
            + json.dumps(
                {
                    "gate_id": "QSDK-R24D130",
                    "ok": True,
                    "world_build_count": 0,
                    "solver_step_count": 0,
                    "r129_behavior_inference_accepted": False,
                    "next_gate_id": "QSDK-R24D131",
                },
                separators=(",", ":"),
                sort_keys=True,
            )
        )
        return 0
    except (ClosureAuditError, KeyError, OSError, UnicodeDecodeError, ValueError) as error:
        print(f"{failure_marker} {error}", file=sys.stderr)
        return 1

