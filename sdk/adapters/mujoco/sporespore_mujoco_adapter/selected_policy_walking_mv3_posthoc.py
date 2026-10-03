"""Deterministic read-only diagnosis for the consumed MuJoCo MV3 report."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

from . import selected_policy_walking_mv3 as campaign


DIAGNOSTIC_SCHEMA = (
    "sporespore_mujoco_c6_bw19v_selected_policy_walking_mv3_posthoc_v1"
)


def _raw_sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _close(left: Any, right: Any, tolerance: float = 1.0e-8) -> bool:
    try:
        return abs(float(left) - float(right)) <= tolerance
    except (TypeError, ValueError):
        return False


def diagnose(report_path: Path) -> dict[str, Any]:
    report = json.loads(report_path.read_text(encoding="utf-8"))
    trace = report["ordered_trace"]
    actuator_ids = report["ordered_actuator_ids"]
    expected_limb_order = report["ordered_limb_ids"]

    receipt_counts = {
        "row_count": len(trace),
        "top_level_source_policy_id_match_count": 0,
        "nested_receipt_policy_id_match_count": 0,
        "controller_command_projection_match_count": 0,
        "bounded_residual_projection_match_count": 0,
        "canonical_command_projection_match_count": 0,
        "host_command_projection_match_count": 0,
        "host_identity_projection_match_count": 0,
        "all_non_policy_projection_fields_match_count": 0,
        "all_fields_match_using_nested_policy_receipt_count": 0,
    }
    memory_order_mismatch_count = 0
    memory_membership_match_count = 0
    observed_memory_orders: set[tuple[str, ...]] = set()
    normalized_evidence_completion: int | None = None
    normalized_evidence_end: list[float] | None = None

    for index, row in enumerate(trace):
        payload = row["receipt_payload"]
        controller = payload["controller_actuation"]
        source_policy_match = (
            controller.get("source_policy_id") == campaign.bridge.SELECTED_POLICY_ID
        )
        nested_policy_match = (
            controller.get("receipt", {}).get("policy_id")
            == campaign.bridge.SELECTED_POLICY_ID
        )
        controller_projection = (
            controller.get("semantic_step") == index
            and controller.get("ordered_commands")
            == row["ordered_portable_base_commands"]
        )
        receipt_bounded = [
            {
                "actuator_id": item.get("actuator_id"),
                "applied_velocity_delta_rad_s": item.get(
                    "applied_velocity_delta_rad_s"
                ),
            }
            for item in payload["stability_influence"].get(
                "ordered_applied_corrections", []
            )
        ]
        bounded_projection = receipt_bounded == row[
            "ordered_bounded_canonical_residuals"
        ]
        canonical_projection = (
            payload["canonical_actuation"].get("ordered_commands")
            == row["ordered_canonical_commands"]
        )
        host_projection = (
            payload["host_mapping"].get("ordered_commands")
            == row["ordered_host_commands"]
        )
        host_identity_projection = (
            payload["host_mapping"].get("host_profile_id") == campaign.PROFILE_ID
            and payload["host_mapping"].get(
                "host_response_characterized_for_this_profile"
            )
            is True
        )
        non_policy_fields_match = all(
            (
                controller_projection,
                bounded_projection,
                canonical_projection,
                host_projection,
                host_identity_projection,
            )
        )
        receipt_counts["top_level_source_policy_id_match_count"] += int(
            source_policy_match
        )
        receipt_counts["nested_receipt_policy_id_match_count"] += int(
            nested_policy_match
        )
        receipt_counts["controller_command_projection_match_count"] += int(
            controller_projection
        )
        receipt_counts["bounded_residual_projection_match_count"] += int(
            bounded_projection
        )
        receipt_counts["canonical_command_projection_match_count"] += int(
            canonical_projection
        )
        receipt_counts["host_command_projection_match_count"] += int(
            host_projection
        )
        receipt_counts["host_identity_projection_match_count"] += int(
            host_identity_projection
        )
        receipt_counts["all_non_policy_projection_fields_match_count"] += int(
            non_policy_fields_match
        )
        receipt_counts["all_fields_match_using_nested_policy_receipt_count"] += int(
            nested_policy_match and non_policy_fields_match
        )

        memory = row["ordered_limb_controller_memory_after"]
        observed_order = tuple(item["limb_id"] for item in memory)
        observed_memory_orders.add(observed_order)
        memory_order_mismatch_count += int(observed_order != tuple(expected_limb_order))
        memory_membership_match_count += int(
            len(observed_order) == len(expected_limb_order)
            and set(observed_order) == set(expected_limb_order)
        )
        if normalized_evidence_completion is None and index >= campaign.CLOCKED_STEPS:
            memory_by_limb = {item["limb_id"]: item for item in memory}
            if set(memory_by_limb) == set(expected_limb_order) and all(
                memory_by_limb[limb_id].get("evidence_gait_step_limit") is not None
                and memory_by_limb[limb_id]["gait_step"]
                >= memory_by_limb[limb_id]["evidence_gait_step_limit"]
                for limb_id in expected_limb_order
            ):
                normalized_evidence_completion = index
                normalized_evidence_end = row["post_step_snapshot"][
                    "torso_position_m"
                ]

    evidence_start = trace[campaign.CLOCKED_STEPS]["pre_step_snapshot"][
        "torso_position_m"
    ]
    normalized_evidence_advance = (
        None
        if normalized_evidence_end is None
        else normalized_evidence_end[0] - evidence_start[0]
    )
    metrics = report["metrics"]
    limbs = report["limb_evidence"]
    final_contacts = trace[-1]["post_step_snapshot"][
        "ordered_declared_contacts"
    ]
    physical_gate_observations = {
        "evidence_advance_passed": (
            normalized_evidence_advance is not None
            and normalized_evidence_advance >= campaign.MINIMUM_EVIDENCE_ADVANCE_M
        ),
        "final_advance_passed": (
            metrics["final_forward_displacement_m"] >= campaign.MINIMUM_FINAL_ADVANCE_M
        ),
        "lateral_drift_passed": (
            abs(metrics["final_lateral_displacement_m"])
            <= campaign.MAXIMUM_LATERAL_DRIFT_M
        ),
        "yaw_drift_passed": (
            abs(metrics["final_yaw_drift_rad"]) <= campaign.MAXIMUM_YAW_DRIFT_RAD
        ),
        "tilt_passed": metrics["maximum_tilt_rad"] <= campaign.MAXIMUM_TILT_RAD,
        "height_passed": (
            metrics["minimum_torso_height_m"] >= campaign.MINIMUM_TORSO_HEIGHT_M
        ),
        "zero_torso_contact_passed": report["torso_ground_contact_step_count"] == 0,
        "all_limb_cycle_gates_passed": all(
            item["contact_cycles"] >= campaign.MINIMUM_CONTACT_CYCLES_PER_LIMB
            and item["maximum_airborne_dwell_steps"]
            >= campaign.MINIMUM_AIRBORNE_DWELL_STEPS
            and item["maximum_foot_relocation_m"]
            >= campaign.MINIMUM_FOOT_RELOCATION_M
            for item in limbs.values()
        ),
        "evidence_deadline_passed_after_order_normalization": (
            normalized_evidence_completion is not None
            and normalized_evidence_completion < campaign.EVIDENCE_DEADLINE_EXCLUSIVE
        ),
        "post_evidence_horizon_passed_after_order_normalization": (
            normalized_evidence_completion is not None
            and normalized_evidence_completion + campaign.REQUIRED_POST_EVIDENCE_STEPS
            < campaign.TOTAL_STEPS
        ),
        "terminal_four_contact_stance_passed": all(final_contacts.values()),
    }
    evaluator_failures = campaign.evaluate_report(report)
    return {
        "schema_version": DIAGNOSTIC_SCHEMA,
        "campaign_id": report["campaign_id"],
        "gate_id": report["gate_id"],
        "source_commit": report["source_commit"],
        "report_path": report_path.resolve().as_posix(),
        "report_byte_length": report_path.stat().st_size,
        "report_raw_sha256": _raw_sha256(report_path),
        "primary_report_ok": report["ok"],
        "primary_gate_failures": report["gate_failures"],
        "replayed_evaluator_failures": evaluator_failures,
        "replay_matches_primary_failures": evaluator_failures
        == report["gate_failures"],
        "trace_step_count": len(trace),
        "receipt_projection_diagnosis": receipt_counts,
        "limb_memory_order_diagnosis": {
            "expected_order": expected_limb_order,
            "observed_orders": [list(item) for item in sorted(observed_memory_orders)],
            "order_mismatch_row_count": memory_order_mismatch_count,
            "exact_membership_match_row_count": memory_membership_match_count,
        },
        "order_normalized_development_only_reconstruction": {
            "evidence_completion_semantic_step": normalized_evidence_completion,
            "evidence_forward_displacement_m": normalized_evidence_advance,
            "matches_declared_evidence_completion": (
                normalized_evidence_completion
                == report["schedule"]["evidence_completion_semantic_step"]
            ),
            "matches_declared_evidence_forward_displacement": _close(
                normalized_evidence_advance,
                metrics["evidence_forward_displacement_m"],
            ),
            "physical_gate_observations": physical_gate_observations,
            "final_contacts": final_contacts,
            "development_observation_only": True,
            "may_not_replace_or_rethreshold_primary_result": True,
        },
        "scientific_boundaries": {
            "campaign_identity_consumed": True,
            "complete_report_retained": True,
            "frozen_primary_result_remains_negative": True,
            "trace_projection_integrity_passed": False,
            "terminal_stance_passed": False,
            "accepted_exact_s169_mujoco_walking": False,
            "mujoco_selected_policy_physical_c6": False,
            "cross_engine_equivalence": False,
            "release_authorized": False,
            "physical_acceptance_authority": False,
            "same_identity_rerun_allowed": False,
        },
    }


def _write_new_json(path: Path, value: dict[str, Any]) -> None:
    with path.open("x", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2, allow_nan=False)
        handle.write("\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--diagnostic", type=Path)
    args = parser.parse_args()
    diagnostic = diagnose(args.report)
    if args.diagnostic is None:
        print(json.dumps(diagnostic, indent=2, allow_nan=False))
    else:
        _write_new_json(args.diagnostic, diagnostic)
    return 0 if diagnostic["replay_matches_primary_failures"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
