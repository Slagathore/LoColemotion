#!/usr/bin/env python3
"""Compact zero-world projection for a finite recovery phase target pose."""

from __future__ import annotations

from collections import Counter
import json
from pathlib import Path
import subprocess
import sys
from typing import Any

from sdk.conformance.content_addressed_zero_world_closure import (
    ClosureAuditError,
    canonical_bytes,
    exact,
    require,
    sha256,
    verify_exact_paths,
    verify_legacy_live_authority_projection,
    verify_source_binding,
)
from sdk.conformance.finite_recovery_trace_diagnosis import (
    _load_bound_physical_raw,
)

JOINTS = (
    "front_left_hip",
    "front_left_knee",
    "front_right_hip",
    "front_right_knee",
    "rear_left_hip",
    "rear_left_knee",
    "rear_right_hip",
    "rear_right_knee",
)
PHASE = "establish_distal_support"


def _mean(first: float, second: float) -> float:
    return (first + second) / 2.0


def _mirror(vector: list[float]) -> tuple[float, float, float]:
    return (
        max(abs(vector[0] + vector[4]), abs(vector[2] + vector[6])),
        max(abs(vector[1] + vector[5]), abs(vector[3] + vector[7])),
        max(
            abs(vector[0] + vector[1] + vector[4] + vector[5]),
            abs(vector[2] + vector[3] + vector[6] + vector[7]),
        ),
    )


def _phase(raw: dict[str, Any]) -> dict[str, Any]:
    arm = raw["candidate_arm"]
    exact(arm["arm_kind"], "candidate_command", "CANDIDATE_ARM")
    observations = arm["trace_v3"]["observations"]
    steps = arm["portable_step_receipts"]
    exact(len(observations), len(steps), "TRACE_STEP_COUNT")
    indices = [i for i, step in enumerate(steps) if step["prior_phase"] == PHASE]
    exact(indices, list(range(indices[0], indices[0] + 240)), "PHASE_STEPS")
    require(indices[0] > 0, "PHASE_SOURCE")
    source_observation = observations[indices[0] - 1]

    controls = [
        value for value in arm["planned_control_receipts"] if value["phase"] == PHASE
    ]
    exact(len(controls), 240, "CONTROL_COUNT")
    commands = controls[0]["ordered_commands"]
    exact(tuple(str(value["joint_id"]) for value in commands), JOINTS, "TARGET_ORDER")
    targets = [float(value["target_position_rad"]) for value in commands]
    for control in controls:
        exact(
            [
                float(value["target_position_rad"])
                for value in control["ordered_commands"]
            ],
            targets,
            "TARGET_STABILITY",
        )
        exact(
            control["command_sha256"],
            controls[0]["command_sha256"],
            "COMMAND_STABILITY",
        )

    manifest = arm["initializer_manifest"]
    exact(
        tuple(str(value) for value in manifest["ordered_joint_ids"]),
        JOINTS,
        "MANIFEST_ORDER",
    )
    initial = [float(value) for value in manifest["ordered_joint_positions_rad"]]

    def positions(index: int) -> list[float]:
        joints = observations[index]["state"]["ordered_joint_observations"]
        exact(tuple(str(value["joint_id"]) for value in joints), JOINTS, "JOINT_ORDER")
        return [float(value["position_rad"]) for value in joints]

    source, final = positions(indices[0] - 1), positions(indices[-1])
    contacts: Counter[str] = Counter()
    onset: dict[str, int | None] = {}
    for index in indices:
        for value in observations[index]["ordered_foot_bearing_observations"]:
            foot = str(value["contact_site_id"])
            onset.setdefault(foot, None)
            if bool(value["ordinary_unilateral_contact"]):
                contacts[foot] += 1
                if onset[foot] is None:
                    onset[foot] = int(observations[index]["semantic_step"])
    applications = [
        value
        for value in arm["command_application_receipts"]
        if value["phase"] == PHASE
    ]
    exact(len(applications), 240, "APPLICATION_COUNT")
    return {
        "observation_sha256": sha256(canonical_bytes(source_observation)),
        "control_sha256": sha256(canonical_bytes(controls[0])),
        "command_sha256": controls[0]["command_sha256"],
        "initial": initial,
        "targets": targets,
        "source": source,
        "delta": [end - start for start, end in zip(source, final, strict=True)],
        "contacts": contacts,
        "onset": onset,
        "writes": sum(int(value["body_impulse_write_count"]) for value in applications),
    }


def front_support_target_sign_projection(
    r107_raw: dict[str, Any], r111_raw: dict[str, Any]
) -> dict[str, Any]:
    """Project immutable paired traces onto support-target sign symmetry."""

    r107, r111 = _phase(r107_raw), _phase(r111_raw)
    for key in (
        "observation_sha256",
        "control_sha256",
        "command_sha256",
        "initial",
        "targets",
        "source",
    ):
        exact(r107[key], r111[key], f"PAIRED_{key.upper()}")
    targets = list(r111["targets"])
    selected = list(targets)
    selected[1], selected[3] = -targets[5], -targets[7]
    source = r111["source"]
    observed_error = [
        abs(target - value) for target, value in zip(targets, source, strict=True)
    ]
    selected_error = [
        abs(target - value) for target, value in zip(selected, source, strict=True)
    ]
    prone_mirror = _mirror(r111["initial"])
    observed_mirror = _mirror(targets)
    selected_mirror = _mirror(selected)
    contact = r111["contacts"]
    return {
        "paired_source_observation_canonical_sha256": r111["observation_sha256"],
        "paired_first_support_control_canonical_sha256": r111["control_sha256"],
        "support_command_sha256": r111["command_sha256"],
        "phase_step_count": 240,
        "canonical_prone_positions_rad": r111["initial"],
        "observed_support_target_positions_rad": targets,
        "selected_support_target_positions_rad": selected,
        "canonical_prone_maximum_mirror_residual_rad": max(prone_mirror),
        "r107_body_impulse_write_count": r107["writes"],
        "r107_total_distal_contact_step_count": sum(r107["contacts"].values()),
        "r111_body_impulse_write_count": r111["writes"],
        "r111_front_contact_step_count": contact.get("front_left_foot", 0)
        + contact.get("front_right_foot", 0),
        "r111_rear_contact_step_count": contact.get("rear_left_foot", 0)
        + contact.get("rear_right_foot", 0),
        "r111_rear_left_contact_onset_step": r111["onset"]["rear_left_foot"],
        "r111_rear_right_contact_onset_step": r111["onset"]["rear_right_foot"],
        "observed_front_knee_mean_source_error_rad": _mean(
            observed_error[1], observed_error[3]
        ),
        "observed_rear_knee_mean_source_error_rad": _mean(
            observed_error[5], observed_error[7]
        ),
        "selected_front_knee_mean_source_error_rad": _mean(
            selected_error[1], selected_error[3]
        ),
        "selected_rear_knee_mean_source_error_rad": _mean(
            selected_error[5], selected_error[7]
        ),
        "r111_front_knee_mean_position_delta_rad": _mean(
            r111["delta"][1], r111["delta"][3]
        ),
        "r111_rear_knee_mean_position_delta_rad": _mean(
            r111["delta"][5], r111["delta"][7]
        ),
        "observed_front_knee_target_mirror_residual_rad": observed_mirror[1],
        "selected_front_knee_target_mirror_residual_rad": selected_mirror[1],
        "observed_distal_angle_mirror_residual_rad": observed_mirror[2],
        "selected_distal_angle_mirror_residual_rad": selected_mirror[2],
        "selected_front_knee_target_rad": selected[1],
        "selected_rear_knee_target_rad": selected[5],
        "execution_counts": {
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
        },
    }


def validate_diagnosis(
    root: Path,
    relative_path: str,
    schema: str,
    expected_sha256: str,
    expected_length: int,
    **scope: str,
) -> dict[str, Any]:
    raw = (root / relative_path).read_bytes()
    exact(
        (len(raw), sha256(raw)),
        (expected_length, expected_sha256),
        "DIAGNOSIS_IDENTITY",
    )
    diagnosis = json.loads(raw)
    verify_exact_paths(
        diagnosis,
        {
            "schema_version": schema,
            "gate_id": scope["gate_id"],
            "question_class": "development",
            "physical_question_declared": False,
            "ledger_scope.subsystem": "recovery",
            "ledger_scope.engine_scope": "godot_jolt",
            "ledger_scope.question_class": "development",
        },
        "DIAGNOSIS",
    )
    predecessors = diagnosis["predecessors"]
    projection = front_support_target_sign_projection(
        _load_bound_physical_raw(root, predecessors["r24d107"], "R107"),
        _load_bound_physical_raw(root, predecessors["r24d111"], "R111"),
    )
    encoded = canonical_bytes(projection)
    exact(
        (len(encoded), sha256(encoded)),
        (
            diagnosis["computed_projection_canonical_byte_length"],
            diagnosis["computed_projection_canonical_sha256"],
        ),
        "PROJECTION_IDENTITY",
    )
    exact(projection, diagnosis["computed_projection"], "PROJECTION")
    exact(
        projection["observed_support_target_positions_rad"],
        diagnosis["method"]["observed_support_target_positions_rad"],
        "OBSERVED_TARGETS",
    )
    exact(
        projection["selected_support_target_positions_rad"],
        diagnosis["method"]["selected_support_target_positions_rad"],
        "SELECTED_TARGETS",
    )
    for binding in diagnosis["source_bindings"]:
        source = verify_source_binding(
            root, str(binding["source_commit"]), binding
        ).decode("utf-8")
        require(
            all(str(marker) in source for marker in binding["required_utf8_markers"]),
            f"SOURCE_MARKERS:{binding['path']}",
        )
    verify_exact_paths(
        diagnosis,
        {
            "decision.r24d107_same_identity_rerun_permitted": False,
            "decision.r24d111_same_identity_rerun_permitted": False,
            "decision.r24d113_zero_world_implementation_authorized": True,
            "decision.physical_execution_authorized": False,
            "decision.historical_result_rewritten": False,
            "decision.prone_to_standing_claimed": False,
            "decision.sdk1_milestone_advanced": False,
            "next_boundary.gate_id": scope["next_gate_id"],
            "next_boundary.physical_execution_authorized": False,
            "next_boundary.maximum_world_build_count": 0,
            "claim_boundary.trajectory_prediction_claimed": False,
            "claim_boundary.behavior_improvement_claimed": False,
            "claim_boundary.prone_to_standing_claimed": False,
            "claim_boundary.release_authority": False,
        },
        "DECISION",
    )
    expected_live = dict(diagnosis["live_authority_projection"])
    expected_live.pop("next_gate_id")
    expected_live.pop("r24d113_zero_world_implementation_required")
    prefix = scope["live_identity_prefix"]
    expected_live.update(
        {
            f"{prefix}_path": relative_path,
            f"{prefix}_raw_sha256": expected_sha256,
            f"{prefix}_byte_length": expected_length,
        }
    )
    verify_legacy_live_authority_projection(
        root,
        tuple(str(value) for value in diagnosis["live_authority_paths"]),
        record_key=scope["live_record_key"],
        expected=expected_live,
        prefix=f"LIVE_{scope['gate_id'].replace('-', '_')}",
    )
    require((root / str(diagnosis["closure_audit_path"])).is_file(), "AUDIT_PATH")
    return diagnosis


def run_cli(
    root: Path,
    relative_path: str,
    schema: str,
    expected_sha256: str,
    expected_length: int,
    pass_marker: str,
    failure_marker: str,
    **scope: str,
) -> int:
    try:
        diagnosis = validate_diagnosis(
            root, relative_path, schema, expected_sha256, expected_length, **scope
        )
        projection = diagnosis["computed_projection"]
        print(
            pass_marker,
            json.dumps(
                {
                    "gate_id": diagnosis["gate_id"],
                    "ok": True,
                    "status": diagnosis["status"],
                    "phase_step_count": projection["phase_step_count"],
                    "r111_front_contact_step_count": projection[
                        "r111_front_contact_step_count"
                    ],
                    "r111_rear_contact_step_count": projection[
                        "r111_rear_contact_step_count"
                    ],
                    "selected_front_knee_target_rad": projection[
                        "selected_front_knee_target_rad"
                    ],
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
