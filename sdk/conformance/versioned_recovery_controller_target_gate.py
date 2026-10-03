#!/usr/bin/env python3
"""Reusable compact gate for a versioned recovery-controller parameter delta."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import sys
from typing import Any, Sequence

from sdk.conformance.content_addressed_zero_world_closure import (
    ClosureAuditError,
    exact,
    git,
    load,
    records_with_key,
    require,
    sha256,
    verify_exact_paths,
)


def _targets(value: object, code: str) -> list[float]:
    require(isinstance(value, list) and len(value) == 8, f"{code}_CARDINALITY")
    targets = [float(item) for item in value]
    require(all(math.isfinite(item) for item in targets), f"{code}_FINITE")
    return targets


def validate_source_inventory(root: Path, contract: dict[str, Any]) -> None:
    inventory = contract["source_inventory"]
    require(isinstance(inventory, list) and inventory, "SOURCE_INVENTORY")
    paths = [str(item) for item in inventory]
    exact(len(set(paths)), len(paths), "SOURCE_INVENTORY_UNIQUE")
    for relative in paths:
        path = (root / relative).resolve()
        require(path.is_relative_to(root.resolve()), f"SOURCE_ESCAPE:{relative}")
        require(path.is_file(), f"SOURCE_MISSING:{relative}")

    markers = contract["audit_configuration"]["source_markers"]
    require(isinstance(markers, dict) and markers, "SOURCE_MARKERS")
    require(set(markers).issubset(set(paths)), "SOURCE_MARKER_INVENTORY")
    for relative, required_value in markers.items():
        required = list(required_value)
        require(
            required and all(isinstance(item, str) for item in required),
            f"SOURCE_MARKER_SHAPE:{relative}",
        )
        text = (root / relative).read_text(encoding="utf-8")
        require(
            all(marker in text for marker in required),
            f"SOURCE_MARKER_MISSING:{relative}",
        )


def validate_authored_delta(root: Path, contract: dict[str, Any]) -> None:
    parent = str(contract["authored_parent_commit"])
    require(len(parent) == 40, "AUTHORED_PARENT_SHAPE")
    git(root, "cat-file", "-e", f"{parent}^{{commit}}")
    head = str(git(root, "rev-parse", "HEAD"))
    if head == parent:
        tracked = str(git(root, "diff", "--name-only", "HEAD")).splitlines()
        untracked = str(
            git(root, "ls-files", "--others", "--exclude-standard")
        ).splitlines()
        actual_paths = sorted(set(tracked + untracked))
    else:
        exact(
            str(git(root, "show", "-s", "--format=%P", head)),
            parent,
            "AUTHORED_SOURCE_PARENT",
        )
        actual_paths = sorted(
            set(str(git(root, "diff", "--name-only", parent, head)).splitlines())
        )
    authored_paths = contract["authored_source_paths"]
    require(
        isinstance(authored_paths, list) and authored_paths, "AUTHORED_SOURCE_PATHS"
    )
    expected_paths = [str(item) for item in authored_paths]
    exact(len(set(expected_paths)), len(expected_paths), "AUTHORED_SOURCE_PATHS_UNIQUE")
    exact(actual_paths, sorted(expected_paths), "AUTHORED_SOURCE_PATHS_EXACT")


def _validate_live_authorities(
    root: Path,
    contract: dict[str, Any],
    *,
    contract_relative_path: str,
    authority_field_prefix: str,
    expected_change_kind: str,
    expected_historical_preservation_field: str,
) -> None:
    paths = contract["audit_configuration"]["live_authority_paths"]
    require(isinstance(paths, list) and paths, "LIVE_AUTHORITY_PATHS")
    exact(len(set(paths)), len(paths), "LIVE_AUTHORITY_PATHS_UNIQUE")
    version = contract["controller_version_contract"]
    expected = {
        f"{authority_field_prefix}_question_class_declared": True,
        f"{authority_field_prefix}_question_class": "development",
        f"{authority_field_prefix}_source_status": contract["status"],
        f"{authority_field_prefix}_physical_question_declared": False,
        f"{authority_field_prefix}_physical_execution_authorized": False,
        f"{authority_field_prefix}_contract_path": contract_relative_path,
        f"{authority_field_prefix}_historical_controller_id": version[
            "historical_controller_id"
        ],
        f"{authority_field_prefix}_successor_controller_id": version[
            "successor_controller_id"
        ],
        f"{authority_field_prefix}_historical_support_pose_id": version[
            "historical_support_pose_id"
        ],
        f"{authority_field_prefix}_successor_support_pose_id": version[
            "successor_support_pose_id"
        ],
        f"{authority_field_prefix}_historical_controller_profile_sha256": version[
            "historical_controller_profile_sha256"
        ],
        f"{authority_field_prefix}_successor_controller_profile_sha256": version[
            "successor_controller_profile_sha256"
        ],
        f"{authority_field_prefix}_historical_support_command_sha256": version[
            "historical_support_command_sha256"
        ],
        f"{authority_field_prefix}_successor_support_command_sha256": version[
            "successor_support_command_sha256"
        ],
        f"{authority_field_prefix}_changed_target_count": version[
            "changed_target_count"
        ],
        f"{authority_field_prefix}_changed_target_indices": version[
            "changed_target_indices"
        ],
        f"{authority_field_prefix}_cross_version_observation_refusal_count": contract[
            "complete_zero_world_gate"
        ]["cross_version_refusal_count"],
        f"{authority_field_prefix}_unregistered_controller_refusal_count": contract[
            "complete_zero_world_gate"
        ]["unregistered_controller_refusal_count"],
        f"{authority_field_prefix}_zero_world_qualification_required": True,
        f"{authority_field_prefix}_zero_world_qualification_complete": False,
        f"{authority_field_prefix}_prone_to_standing_claimed": False,
        f"{authority_field_prefix}_sdk1_milestone_advanced": False,
        f"physical_execution_blocked_pending_{authority_field_prefix}_declaration": False,
        f"physical_execution_blocked_until_{authority_field_prefix}_zero_world_qualification": True,
    }
    if expected_change_kind == "target_positions":
        expected.update(
            {
                f"{authority_field_prefix}_historical_v1_preserved": True,
                f"{authority_field_prefix}_non_target_command_fields_preserved": True,
            }
        )
    elif expected_change_kind == "maximum_target_speed":
        expected.update(
            {
                f"{authority_field_prefix}_historical_v1_v2_preserved": True,
                f"{authority_field_prefix}_target_positions_preserved": True,
                f"{authority_field_prefix}_non_speed_command_fields_preserved": True,
                f"{authority_field_prefix}_historical_maximum_target_speed_rad_s": version[
                    "historical_maximum_target_speed_rad_s"
                ],
                f"{authority_field_prefix}_successor_maximum_target_speed_rad_s": version[
                    "successor_maximum_target_speed_rad_s"
                ],
            }
        )
    elif expected_change_kind == "raise_body_maximum_target_speed":
        expected.update(
            {
                (
                    f"{authority_field_prefix}_{expected_historical_preservation_field}"
                ): True,
                f"{authority_field_prefix}_support_pose_preserved": True,
                f"{authority_field_prefix}_support_commands_preserved": True,
                f"{authority_field_prefix}_historical_stance_pose_id": version[
                    "historical_stance_pose_id"
                ],
                f"{authority_field_prefix}_successor_stance_pose_id": version[
                    "successor_stance_pose_id"
                ],
                f"{authority_field_prefix}_stance_target_positions_preserved": True,
                f"{authority_field_prefix}_non_speed_command_fields_preserved": True,
                f"{authority_field_prefix}_raise_body_phase_steps": version[
                    "raise_body_phase_steps"
                ],
                f"{authority_field_prefix}_historical_raise_body_command_sha256": version[
                    "historical_raise_body_command_sha256"
                ],
                f"{authority_field_prefix}_successor_raise_body_command_sha256": version[
                    "successor_raise_body_command_sha256"
                ],
                f"{authority_field_prefix}_historical_maximum_target_speed_rad_s": version[
                    "historical_maximum_target_speed_rad_s"
                ],
                f"{authority_field_prefix}_successor_maximum_target_speed_rad_s": version[
                    "successor_maximum_target_speed_rad_s"
                ],
                f"{authority_field_prefix}_command_mutation_refusal_count": contract[
                    "complete_zero_world_gate"
                ]["command_mutation_refusal_count"],
            }
        )
    elif expected_change_kind == "actuation_realization":
        expected.update(
            {
                (
                    f"{authority_field_prefix}_{expected_historical_preservation_field}"
                ): True,
                f"{authority_field_prefix}_portable_commands_preserved": True,
                f"{authority_field_prefix}_godot_actuation_realization_changed": True,
                f"{authority_field_prefix}_historical_actuator_mode": version[
                    "historical_actuator_mode"
                ],
                f"{authority_field_prefix}_successor_actuator_mode": version[
                    "successor_actuator_mode"
                ],
                f"{authority_field_prefix}_historical_actuation_realization_id": version[
                    "historical_actuation_realization_id"
                ],
                f"{authority_field_prefix}_successor_actuation_realization_id": version[
                    "successor_actuation_realization_id"
                ],
                f"{authority_field_prefix}_realization_mismatch_refusal_count": contract[
                    "complete_zero_world_gate"
                ]["realization_mismatch_refusal_count"],
            }
        )
    else:
        raise ClosureAuditError(f"CHANGE_KIND:{expected_change_kind}")
    population_key = f"{authority_field_prefix}_source_status"
    for relative in paths:
        authority_path = root / str(relative)
        authority_text = authority_path.read_text(encoding="utf-8")
        exact(
            authority_text.count(f'"{population_key}"'),
            1,
            f"LIVE_AUTHORITY_RAW_POPULATION:{relative}",
        )
        # These retained authorities predate strict duplicate-key parsing in
        # unrelated historical blocks. Bind this successor's unique raw key,
        # then parse with the repository's ordinary JSON compatibility policy.
        records = records_with_key(json.loads(authority_text), population_key)
        exact(len(records), 1, f"LIVE_AUTHORITY_POPULATION:{relative}")
        record = records[0]
        for field, expected_value in expected.items():
            require(field in record, f"LIVE_AUTHORITY_FIELD:{relative}:{field}")
            exact(
                record[field],
                expected_value,
                f"LIVE_AUTHORITY_VALUE:{relative}:{field}",
            )


def validate_contract(
    root: Path,
    contract: dict[str, Any],
    *,
    contract_relative_path: str,
    contract_schema: str,
    gate_id: str,
    authority_field_prefix: str,
    expected_historical_controller_id: str,
    expected_successor_controller_id: str,
    expected_historical_profile_sha256: str,
    expected_successor_profile_sha256: str,
    expected_historical_command_sha256: str,
    expected_successor_command_sha256: str,
    expected_historical_targets: Sequence[float],
    expected_successor_targets: Sequence[float],
    expected_changed_target_indices: Sequence[int],
    expected_changed_joint_ids: Sequence[str],
    expected_cross_version_refusal_count: int,
    expected_unregistered_controller_refusal_count: int,
    expected_change_kind: str = "target_positions",
    expected_status: str = (
        "prospective_zero_world_versioned_controller_target_"
        "implementation_qualification_pending"
    ),
    expected_authority_mode: str = (
        "prospective_zero_world_versioned_controller_target_implementation"
    ),
    expected_historical_maximum_target_speed_rad_s: float = 1.0,
    expected_successor_maximum_target_speed_rad_s: float = 1.0,
    expected_preflight_schema: str = (
        "sporespore_versioned_recovery_controller_target_preflight_v1"
    ),
    expected_historical_regression_field: str = "historical_v1_regression_count",
    expected_historical_stance_pose_id: str | None = None,
    expected_successor_stance_pose_id: str | None = None,
    expected_raise_body_phase_steps: Sequence[int] = (),
    expected_historical_raise_command_sha256: Sequence[str] = (),
    expected_successor_raise_command_sha256: Sequence[str] = (),
    expected_command_mutation_refusal_count: int = 0,
    expected_historical_preservation_field: str = "historical_v1_v3_preserved",
    expected_historical_actuator_mode: str = "",
    expected_successor_actuator_mode: str = "",
    expected_historical_actuation_realization_id: str = "",
    expected_successor_actuation_realization_id: str = "",
    expected_energy_source_profile_id: str = "",
    expected_realization_mismatch_refusal_count: int = 0,
) -> None:
    changed_target_indices = [int(item) for item in expected_changed_target_indices]
    changed_joint_ids = [str(item) for item in expected_changed_joint_ids]
    verify_exact_paths(
        contract,
        {
            "schema_version": contract_schema,
            "gate_id": gate_id,
            "status": expected_status,
            "ledger_scope.subsystem": "recovery",
            "ledger_scope.engine_scope": "godot_jolt",
            "ledger_scope.authority_mode": expected_authority_mode,
            "ledger_scope.question_class": "development",
            "question_class": "development",
            "physical_question_declared": False,
            "finite_decision_declared": False,
            "superiority_question_declared": False,
            "equivalence_or_non_inferiority_question_declared": False,
            "population_inference_declared": False,
            "controller_version_contract.historical_controller_id": (
                expected_historical_controller_id
            ),
            "controller_version_contract.successor_controller_id": (
                expected_successor_controller_id
            ),
            "controller_version_contract.historical_controller_profile_sha256": (
                expected_historical_profile_sha256
            ),
            "controller_version_contract.successor_controller_profile_sha256": (
                expected_successor_profile_sha256
            ),
            "controller_version_contract.historical_support_command_sha256": (
                expected_historical_command_sha256
            ),
            "controller_version_contract.successor_support_command_sha256": (
                expected_successor_command_sha256
            ),
            "controller_version_contract.changed_target_count": len(
                changed_target_indices
            ),
            "controller_version_contract.changed_target_indices": changed_target_indices,
            "controller_version_contract.changed_joint_ids": changed_joint_ids,
            "controller_version_contract.raise_body_ramp_preserved": True,
            "controller_version_contract.thresholds_preserved": True,
            "controller_version_contract.evaluator_preserved": True,
            "complete_zero_world_gate.must_pass_before_physics": True,
            "complete_zero_world_gate.official_qualification_must_start_clean_pushed_equal": True,
            "complete_zero_world_gate.official_qualification_attempt_limit_per_source_commit": 1,
            "complete_zero_world_gate.native_zero_world_test_count": 1,
            f"complete_zero_world_gate.{expected_historical_regression_field}": 1,
            "complete_zero_world_gate.effective_inertia_route_regression_count": 1,
            "complete_zero_world_gate.zero_world_bootstrap_application_count": 1,
            "complete_zero_world_gate.cross_version_refusal_count": (
                expected_cross_version_refusal_count
            ),
            "complete_zero_world_gate.unregistered_controller_refusal_count": (
                expected_unregistered_controller_refusal_count
            ),
            "complete_zero_world_gate.historical_closure_audits_executed_count": 0,
            "complete_zero_world_gate.additional_physical_ghost_count": 0,
            "complete_zero_world_gate.additional_physical_canary_count": 0,
            "complete_zero_world_gate.model_construction_count": 0,
            "complete_zero_world_gate.world_attempt_count": 0,
            "complete_zero_world_gate.world_build_count": 0,
            "complete_zero_world_gate.solver_step_count": 0,
            "complete_zero_world_gate.physics_state_modified": False,
            "complete_zero_world_gate.physical_execution_authorized": False,
            "complete_zero_world_gate.maximum_physical_steps_authorized": 0,
            "claim_boundary.prone_to_standing_claimed": False,
            "claim_boundary.sdk1_milestone_advanced": False,
            "claim_boundary.physical_acceptance_authority": False,
            "claim_boundary.release_authority": False,
        },
        "R113_CONTRACT",
    )

    version = contract["controller_version_contract"]
    historical = _targets(
        version["historical_support_targets_rad"], "HISTORICAL_TARGETS"
    )
    successor = _targets(version["successor_support_targets_rad"], "SUCCESSOR_TARGETS")
    exact(
        historical,
        [float(item) for item in expected_historical_targets],
        "HISTORICAL_TARGETS",
    )
    exact(
        successor,
        [float(item) for item in expected_successor_targets],
        "SUCCESSOR_TARGETS",
    )
    changed = [
        index
        for index, pair in enumerate(zip(historical, successor))
        if pair[0] != pair[1]
    ]
    exact(changed, changed_target_indices, "CHANGED_TARGET_INDICES")
    if expected_change_kind == "target_positions":
        verify_exact_paths(
            contract,
            {
                "controller_version_contract.historical_v1_preserved": True,
                "controller_version_contract.non_target_command_fields_preserved": True,
                "controller_version_contract.stance_pose_preserved": True,
                "controller_version_contract.actuator_route_preserved": True,
            },
            "TARGET_CHANGE",
        )
    elif expected_change_kind == "maximum_target_speed":
        verify_exact_paths(
            contract,
            {
                "controller_version_contract.change_kind": "maximum_target_speed",
                "controller_version_contract.historical_v1_v2_preserved": True,
                "controller_version_contract.target_positions_preserved": True,
                "controller_version_contract.non_speed_command_fields_preserved": True,
                "controller_version_contract.stance_pose_preserved": True,
                "controller_version_contract.actuator_route_preserved": True,
                "controller_version_contract.historical_maximum_target_speed_rad_s": (
                    expected_historical_maximum_target_speed_rad_s
                ),
                "controller_version_contract.successor_maximum_target_speed_rad_s": (
                    expected_successor_maximum_target_speed_rad_s
                ),
            },
            "SPEED_CHANGE",
        )
        require(
            math.isfinite(expected_historical_maximum_target_speed_rad_s)
            and math.isfinite(expected_successor_maximum_target_speed_rad_s)
            and expected_historical_maximum_target_speed_rad_s > 0.0
            and expected_successor_maximum_target_speed_rad_s
            > expected_historical_maximum_target_speed_rad_s,
            "SPEED_CHANGE_VALUES",
        )
        exact(historical, successor, "SPEED_CHANGE_TARGET_PRESERVATION")
    elif expected_change_kind == "raise_body_maximum_target_speed":
        require(
            expected_historical_stance_pose_id is not None
            and expected_successor_stance_pose_id is not None
            and expected_historical_stance_pose_id != expected_successor_stance_pose_id,
            "RAISE_BODY_STANCE_POSE_IDENTITIES",
        )
        phase_steps = [int(item) for item in expected_raise_body_phase_steps]
        historical_raise_sha256 = [
            str(item) for item in expected_historical_raise_command_sha256
        ]
        successor_raise_sha256 = [
            str(item) for item in expected_successor_raise_command_sha256
        ]
        require(
            phase_steps
            and phase_steps == sorted(set(phase_steps))
            and len(historical_raise_sha256) == len(phase_steps)
            and len(successor_raise_sha256) == len(phase_steps),
            "RAISE_BODY_COMMAND_POPULATION",
        )
        require(
            all(
                item.startswith("sha256:") and len(item) == 71
                for item in historical_raise_sha256
            )
            and all(
                item.startswith("sha256:") and len(item) == 71
                for item in successor_raise_sha256
            ),
            "RAISE_BODY_COMMAND_DIGESTS",
        )
        verify_exact_paths(
            contract,
            {
                "controller_version_contract.change_kind": (
                    "raise_body_maximum_target_speed"
                ),
                (
                    "controller_version_contract."
                    f"{expected_historical_preservation_field}"
                ): True,
                "controller_version_contract.support_pose_preserved": True,
                "controller_version_contract.support_commands_preserved": True,
                "controller_version_contract.historical_stance_pose_id": (
                    expected_historical_stance_pose_id
                ),
                "controller_version_contract.successor_stance_pose_id": (
                    expected_successor_stance_pose_id
                ),
                "controller_version_contract.stance_pose_versioned": True,
                "controller_version_contract.stance_target_positions_preserved": True,
                "controller_version_contract.non_speed_command_fields_preserved": True,
                "controller_version_contract.actuator_route_preserved": True,
                "controller_version_contract.raise_body_phase_steps": phase_steps,
                "controller_version_contract.historical_raise_body_command_sha256": (
                    historical_raise_sha256
                ),
                "controller_version_contract.successor_raise_body_command_sha256": (
                    successor_raise_sha256
                ),
                "controller_version_contract.historical_maximum_target_speed_rad_s": (
                    expected_historical_maximum_target_speed_rad_s
                ),
                "controller_version_contract.successor_maximum_target_speed_rad_s": (
                    expected_successor_maximum_target_speed_rad_s
                ),
                "complete_zero_world_gate.command_mutation_refusal_count": (
                    expected_command_mutation_refusal_count
                ),
            },
            "RAISE_BODY_SPEED_CHANGE",
        )
        require(
            math.isfinite(expected_historical_maximum_target_speed_rad_s)
            and math.isfinite(expected_successor_maximum_target_speed_rad_s)
            and expected_historical_maximum_target_speed_rad_s > 0.0
            and expected_successor_maximum_target_speed_rad_s
            > expected_historical_maximum_target_speed_rad_s,
            "RAISE_BODY_SPEED_CHANGE_VALUES",
        )
        exact(historical, successor, "RAISE_BODY_SUPPORT_TARGET_PRESERVATION")
        exact(
            expected_historical_command_sha256,
            expected_successor_command_sha256,
            "RAISE_BODY_SUPPORT_COMMAND_PRESERVATION",
        )
        exact(
            expected_command_mutation_refusal_count,
            2,
            "RAISE_BODY_MUTATION_CONTROL_COUNT",
        )
    elif expected_change_kind == "actuation_realization":
        phase_steps = [int(item) for item in expected_raise_body_phase_steps]
        historical_raise_sha256 = [
            str(item) for item in expected_historical_raise_command_sha256
        ]
        successor_raise_sha256 = [
            str(item) for item in expected_successor_raise_command_sha256
        ]
        require(
            expected_historical_actuator_mode
            and expected_successor_actuator_mode
            and expected_historical_actuator_mode != expected_successor_actuator_mode
            and expected_historical_actuation_realization_id
            and expected_successor_actuation_realization_id
            and expected_historical_actuation_realization_id
            != expected_successor_actuation_realization_id
            and expected_energy_source_profile_id
            and phase_steps
            and phase_steps == sorted(set(phase_steps))
            and len(historical_raise_sha256) == len(phase_steps)
            and len(successor_raise_sha256) == len(phase_steps)
            and expected_realization_mismatch_refusal_count == 2,
            "ACTUATION_REALIZATION_SPEC",
        )
        verify_exact_paths(
            contract,
            {
                "controller_version_contract.change_kind": "actuation_realization",
                (
                    "controller_version_contract."
                    f"{expected_historical_preservation_field}"
                ): True,
                "controller_version_contract.portable_commands_preserved": True,
                "controller_version_contract.portable_profile_fields_preserved_except_identity": True,
                "controller_version_contract.support_pose_preserved": True,
                "controller_version_contract.stance_pose_preserved": True,
                "controller_version_contract.actuator_route_preserved": False,
                "controller_version_contract.godot_actuation_realization_changed": True,
                "controller_version_contract.historical_actuator_mode": (
                    expected_historical_actuator_mode
                ),
                "controller_version_contract.successor_actuator_mode": (
                    expected_successor_actuator_mode
                ),
                "controller_version_contract.historical_actuation_realization_id": (
                    expected_historical_actuation_realization_id
                ),
                "controller_version_contract.successor_actuation_realization_id": (
                    expected_successor_actuation_realization_id
                ),
                "controller_version_contract.energy_source_profile_id": (
                    expected_energy_source_profile_id
                ),
                "controller_version_contract.raise_body_phase_steps": phase_steps,
                "controller_version_contract.historical_raise_body_command_sha256": (
                    historical_raise_sha256
                ),
                "controller_version_contract.successor_raise_body_command_sha256": (
                    successor_raise_sha256
                ),
                "complete_zero_world_gate.command_mutation_refusal_count": (
                    expected_command_mutation_refusal_count
                ),
                "complete_zero_world_gate.realization_mismatch_refusal_count": (
                    expected_realization_mismatch_refusal_count
                ),
            },
            "ACTUATION_REALIZATION_CHANGE",
        )
        exact(historical, successor, "ACTUATION_TARGET_PRESERVATION")
        exact(
            expected_historical_command_sha256,
            expected_successor_command_sha256,
            "ACTUATION_SUPPORT_COMMAND_PRESERVATION",
        )
        exact(
            historical_raise_sha256,
            successor_raise_sha256,
            "ACTUATION_RAISE_COMMAND_PRESERVATION",
        )
        exact(
            expected_historical_maximum_target_speed_rad_s,
            expected_successor_maximum_target_speed_rad_s,
            "ACTUATION_SPEED_PRESERVATION",
        )
        exact(
            expected_command_mutation_refusal_count,
            2,
            "ACTUATION_COMMAND_MUTATION_CONTROL_COUNT",
        )
    else:
        raise ClosureAuditError(f"CHANGE_KIND:{expected_change_kind}")

    validate_source_inventory(root, contract)
    validate_authored_delta(root, contract)
    _validate_live_authorities(
        root,
        contract,
        contract_relative_path=contract_relative_path,
        authority_field_prefix=authority_field_prefix,
        expected_change_kind=expected_change_kind,
        expected_historical_preservation_field=(expected_historical_preservation_field),
    )


def run_cli(
    root: Path,
    contract_relative_path: str,
    contract_schema: str,
    gate_id: str,
    pass_marker: str,
    fail_marker: str,
    **expectations: Any,
) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--core-library", type=Path)
    args = parser.parse_args()
    try:
        contract = load(root / contract_relative_path)
        validate_contract(
            root,
            contract,
            contract_relative_path=contract_relative_path,
            contract_schema=contract_schema,
            gate_id=gate_id,
            **expectations,
        )
        runtime_path = args.core_library.resolve() if args.core_library else None
        if runtime_path is not None:
            require(runtime_path.is_file(), "CORE_LIBRARY_MISSING")
            runtime_sha256 = sha256(runtime_path.read_bytes())
        else:
            runtime_sha256 = "source_only"
        print(pass_marker)
        print(
            json.dumps(
                {
                    "schema_version": (
                        expectations.get(
                            "expected_preflight_schema",
                            "sporespore_versioned_recovery_controller_target_preflight_v1",
                        )
                    ),
                    "gate_id": gate_id,
                    "ok": True,
                    "runtime_id": "sporespore_locomotion_core_debug_dll",
                    "runtime_version": runtime_sha256,
                    "model_construction_count": 0,
                    "world_attempt_count": 0,
                    "world_build_count": 0,
                    "solver_step_count": 0,
                    "physics_state_modified": False,
                    "physical_question_opened": False,
                    "prone_to_standing_claimed": False,
                    "physical_acceptance_authority": False,
                    "release_authority": False,
                },
                sort_keys=True,
                separators=(",", ":"),
            )
        )
        return 0
    except (ClosureAuditError, KeyError, TypeError, ValueError) as error:
        print(f"{fail_marker}:{error}", file=sys.stderr)
        return 1
