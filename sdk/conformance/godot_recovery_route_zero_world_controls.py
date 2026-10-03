#!/usr/bin/env python3
"""Reusable process controls for bounded Godot recovery-route successors."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import struct
import subprocess
from typing import Any


class ControlError(RuntimeError):
    """Stable fail-closed shared-control error."""


def require(condition: bool, code: str) -> None:
    if not condition:
        raise ControlError(code)


def _one_json_marker(stdout: str, marker: str, code: str) -> dict[str, Any]:
    lines = [line for line in stdout.splitlines() if line.startswith(marker)]
    require(len(lines) == 1, f"{code}_MARKER")
    value = json.loads(lines[0][len(marker):])
    require(isinstance(value, dict), f"{code}_RECEIPT")
    return value


def run_godot_worker(
    root: Path,
    executable: Path,
    worker: Path,
    marker: str,
    user_args: tuple[str, ...] = (),
    runtime_args: tuple[str, ...] = (),
) -> dict[str, Any]:
    command = [str(executable), "--headless", *runtime_args, "--path", str(root),
               "--script", "res://" + worker.relative_to(root).as_posix()]
    if user_args:
        command.extend(("--", *user_args))
    completed = subprocess.run(
        command,
        cwd=root, capture_output=True, text=True, encoding="utf-8",
        errors="strict", check=False,
    )
    require(completed.returncode == 0,
            f"GODOT_WORKER_EXIT:{completed.returncode}:{completed.stdout}:{completed.stderr}")
    return _one_json_marker(completed.stdout, marker, "GODOT_WORKER")


def run_projection_control(
    root: Path,
    runner: Path,
    marker: str,
    gate_id: str,
) -> dict[str, Any]:
    completed = subprocess.run(
        ["pwsh", "-NoProfile", "-File", str(runner),
         "-Mode", "ProjectionControl"],
        cwd=root, capture_output=True, text=True, encoding="utf-8",
        errors="strict", check=False,
    )
    require(completed.returncode == 23,
            f"PROJECTION_CONTROL_EXIT:{completed.returncode}")
    value = _one_json_marker(completed.stdout, marker, "PROJECTION_CONTROL")
    require(value.get("gate_id") == gate_id, "PROJECTION_CONTROL_GATE")
    require(value.get("status") == "forced_failure_projection_control",
            "PROJECTION_CONTROL_STATUS")
    require(value.get("ok") is False, "PROJECTION_CONTROL_OK")
    require(completed.stderr == "", f"PROJECTION_CONTROL_STDERR:{completed.stderr}")
    return value


def run_raw_binding_control(
    root: Path,
    runner: Path,
    marker: str,
    spec: dict[str, Any],
) -> dict[str, Any]:
    """Exercise the production raw-result binding predicate without physics."""
    completed = subprocess.run(
        ["pwsh", "-NoProfile", "-File", str(runner),
         "-Mode", "RawBindingControl"],
        cwd=root, capture_output=True, text=True, encoding="utf-8",
        errors="strict", check=False,
    )
    require(
        completed.returncode == 0,
        f"RAW_BINDING_CONTROL_EXIT:{completed.returncode}:"
        f"{completed.stdout}:{completed.stderr}",
    )
    value = _one_json_marker(completed.stdout, marker, "RAW_BINDING_CONTROL")
    require_fields(value, dict(spec["expected"]), "RAW_BINDING_CONTROL")
    require_zero_authority(value)
    require(value.get("physics_state_modified") is False,
            "RAW_BINDING_CONTROL_PHYSICS_STATE")
    require(value.get("physics_evidence_authority") is False,
            "RAW_BINDING_CONTROL_PHYSICS_EVIDENCE_AUTHORITY")
    require(value.get("physical_execution_authorized") is False,
            "RAW_BINDING_CONTROL_PHYSICAL_AUTHORIZATION")
    require(completed.stderr == "", f"RAW_BINDING_CONTROL_STDERR:{completed.stderr}")
    return value


def run_missing_physical_switch_refusal(
    root: Path,
    runner: Path,
    marker: str,
    gate_id: str,
    receipt_schema: str,
) -> dict[str, Any]:
    completed = subprocess.run(
        ["pwsh", "-NoProfile", "-File", str(runner), "-Mode", "Physical"],
        cwd=root, capture_output=True, text=True, encoding="utf-8",
        errors="strict", check=False,
    )
    require(completed.returncode == 1,
            f"PHYSICAL_REFUSAL_EXIT:{completed.returncode}")
    require("physical_switch_required" in completed.stderr,
            "PHYSICAL_REFUSAL_CODE")
    require(marker not in completed.stdout, "PHYSICAL_REFUSAL_SUMMARY")
    return {
        "schema_version": receipt_schema, "gate_id": gate_id, "ok": True,
        "refusal_count": 1, "model_construction_count": 0,
        "world_attempt_count": 0, "world_build_count": 0,
        "solver_step_count": 0, "physical_acceptance_authority": False,
        "release_authority": False,
    }


def run_progress_observability_control(
    root: Path,
    spec: dict[str, Any],
) -> dict[str, Any]:
    """Run the reusable non-physical progress, mutation, and stall controls."""
    script = root / str(spec["path"])
    require(script.is_file(), "PROGRESS_CONTROL_SCRIPT")
    command = ["pwsh", "-NoProfile", "-File", str(script)]
    for name, value in spec["arguments"].items():
        command.extend((f"-{name}", str(value)))
    completed = subprocess.run(
        command,
        cwd=root,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="strict",
        check=False,
    )
    require(
        completed.returncode == 0,
        f"PROGRESS_CONTROL_EXIT:{completed.returncode}:{completed.stdout}:{completed.stderr}",
    )
    receipt = _one_json_marker(
        completed.stdout,
        str(spec["marker"]),
        "PROGRESS_CONTROL",
    )
    require_fields(receipt, dict(spec["expected"]), "PROGRESS_CONTROL")
    require_zero_authority(receipt)
    require(
        receipt.get("physics_evidence_authority") is False,
        "PROGRESS_CONTROL_PHYSICS_EVIDENCE_AUTHORITY",
    )
    require(completed.stderr == "", f"PROGRESS_CONTROL_STDERR:{completed.stderr}")
    return receipt


def require_zero_authority(receipt: dict[str, Any]) -> None:
    for key in ("model_construction_count", "world_attempt_count",
                "world_build_count", "solver_step_count"):
        require(receipt.get(key) == 0, f"ZERO_COUNT:{key}")
    require(receipt.get("physical_acceptance_authority") is False,
            "PHYSICAL_AUTHORITY")
    require(receipt.get("release_authority") is False, "RELEASE_AUTHORITY")


def require_fields(
    value: dict[str, Any],
    expected: dict[str, Any],
    label: str,
) -> None:
    """Apply a compact exact-field conjunction with stable failure codes."""
    for key, wanted in expected.items():
        require(value.get(key) == wanted, f"{label}:{key}")


def binary32(value: float) -> float:
    """Round one Python float through IEEE-754 binary32."""
    return struct.unpack("<f", struct.pack("<f", value))[0]


def binary32_bits(value: float) -> int:
    """Return the raw little-endian IEEE-754 binary32 representation."""
    return struct.unpack("<I", struct.pack("<f", value))[0]


def binary32_from_bits(value: int) -> float:
    """Decode one raw IEEE-754 binary32 representation."""
    return struct.unpack("<f", struct.pack("<I", value))[0]


def project_binary32_native_effective_limit(
    host_impulse: float,
    nominal_host_step: float,
    native_solver_step: float,
) -> tuple[float, float]:
    """Project host impulse through binary32 torque and solver-limit arithmetic."""
    torque = binary32(host_impulse / nominal_host_step)
    return torque, binary32(torque * binary32(native_solver_step))


def inverse_project_binary32_native_effective_limit(
    published_cap: float,
    nominal_host_step: float,
    native_solver_step: float,
    maximum_downward_steps: int = 3,
) -> tuple[float, float, float, float, float]:
    """Select the greatest safe binary32 host input and its unsafe neighbor."""
    candidate = binary32(published_cap)
    for _ in range(maximum_downward_steps + 1):
        torque, effective = project_binary32_native_effective_limit(
            candidate, nominal_host_step, native_solver_step
        )
        if effective <= published_cap:
            next_candidate = binary32_from_bits(binary32_bits(candidate) + 1)
            _, next_effective = project_binary32_native_effective_limit(
                next_candidate, nominal_host_step, native_solver_step
            )
            require(next_effective > published_cap,
                    "BINARY32_INVERSE_PROJECTION_NOT_MAXIMAL")
            return candidate, torque, effective, next_candidate, next_effective
        candidate = binary32_from_bits(binary32_bits(candidate) - 1)
    raise ControlError("BINARY32_INVERSE_PROJECTION_SEARCH_EXHAUSTED")


def validate_binary32_native_effective_limit_population(
    projection: dict[str, Any],
    nominal_host_step: float,
    native_solver_step: float,
) -> dict[str, list[float]]:
    """Validate a complete ordered inverse-projection contract population."""
    published = projection["ordered_published_caps_nms"]
    projected = [
        inverse_project_binary32_native_effective_limit(
            value, nominal_host_step, native_solver_step
        )
        for value in published
    ]
    selected = [item[0] for item in projected]
    torques = [item[1] for item in projected]
    effective = [item[2] for item in projected]
    next_host = [item[3] for item in projected]
    next_effective = [item[4] for item in projected]
    require(selected == projection["ordered_selected_host_caps_nms"],
            "BINARY32_SELECTED_HOST")
    require(
        [f"0x{binary32_bits(value):08x}" for value in selected]
        == projection["ordered_selected_host_binary32_hex"],
        "BINARY32_SELECTED_HOST_HEX",
    )
    require(torques == projection["ordered_projected_native_torque_limits_nm"],
            "BINARY32_NATIVE_TORQUE")
    require(
        [f"0x{binary32_bits(value):08x}" for value in torques]
        == projection["ordered_projected_native_torque_limits_binary32_hex"],
        "BINARY32_NATIVE_TORQUE_HEX",
    )
    require(
        effective == projection["ordered_projected_native_effective_limits_nms"],
        "BINARY32_EFFECTIVE_LIMIT",
    )
    require(
        [f"0x{binary32_bits(value):08x}" for value in effective]
        == projection["ordered_projected_native_effective_limits_binary32_hex"],
        "BINARY32_EFFECTIVE_LIMIT_HEX",
    )
    require(next_host == projection["ordered_immediately_higher_host_caps_nms"],
            "BINARY32_NEXT_HOST")
    require(
        [f"0x{binary32_bits(value):08x}" for value in next_host]
        == projection["ordered_immediately_higher_host_binary32_hex"],
        "BINARY32_NEXT_HOST_HEX",
    )
    require(
        next_effective
        == projection["ordered_immediately_higher_projected_native_effective_limits_nms"],
        "BINARY32_NEXT_EFFECTIVE",
    )
    require(all(value <= cap for value, cap in zip(effective, published, strict=True)),
            "BINARY32_SELECTED_ABOVE_PUBLISHED")
    require(all(value > cap for value, cap in zip(next_effective, published, strict=True)),
            "BINARY32_NEXT_NOT_ABOVE_PUBLISHED")
    require(
        all(
            binary32_bits(upper) - binary32_bits(lower) == 1
            for lower, upper in zip(selected, next_host, strict=True)
        ),
        "BINARY32_ADJACENCY",
    )
    return {
        "selected": selected,
        "torques": torques,
        "effective": effective,
        "next_host": next_host,
        "next_effective": next_effective,
    }


def validate_development_question(
    contract: dict[str, Any],
    gate_id: str,
) -> None:
    """Validate the common non-inferential physical-development declaration."""
    require_fields(contract, {
        "gate_id": gate_id,
        "question_class": "development",
        "physical_question_declared": True,
        "finite_decision_declared": False,
        "superiority_question_declared": False,
        "equivalence_or_non_inferiority_question_declared": False,
        "population_inference_declared": False,
    }, "DEVELOPMENT_QUESTION")


def validate_bound_predecessor(
    root: Path,
    contract: dict[str, Any],
    predecessor_path: Path,
) -> dict[str, Any]:
    """Bind one immutable consumed predecessor without re-executing its audit."""
    predecessors = contract.get("bound_predecessors")
    require(isinstance(predecessors, list) and len(predecessors) == 1,
            "PREDECESSOR_COUNT")
    predecessor = predecessors[0]
    require(isinstance(predecessor, dict), "PREDECESSOR_TYPE")
    digest = "sha256:" + hashlib.sha256(predecessor_path.read_bytes()).hexdigest()
    require_fields(predecessor, {
        "path": predecessor_path.relative_to(root).as_posix(),
        "raw_sha256": digest,
        "byte_length": predecessor_path.stat().st_size,
        "same_identity_rerun_permitted": False,
    }, "PREDECESSOR")
    value = json.loads(predecessor_path.read_text(encoding="utf-8"))
    require(isinstance(value, dict), "PREDECESSOR_JSON_ROOT")
    return value


def validate_finite_development_envelope(
    contract: dict[str, Any],
    seed_label: str,
    population_expected: dict[str, Any],
    threshold_expected: dict[str, Any],
    zero_gate_expected: dict[str, Any],
    authorization_expected: dict[str, Any],
    cell_seed_expected: int | None = None,
) -> None:
    """Validate shared seed, cohort, threshold, zero-gate, and budget mechanics."""
    seed_digest = hashlib.sha256(seed_label.encode("utf-8")).hexdigest()
    cell_seed = (
        int(seed_digest[:8], 16)
        if cell_seed_expected is None
        else cell_seed_expected
    )
    population = contract["finite_development_population"]
    require_fields(population, {
        "cell_count": 1,
        "world_count": 2,
        "arm_count": 2,
        "cell_seed": cell_seed,
        "seed_label": seed_label,
        "seed_sha256": f"sha256:{seed_digest}",
        "ordered_arms": ["candidate_command", "matched_zero_command"],
        "same_source_attempt_limit": 1,
        "held_out": False,
        "repeatability_claimed": False,
        "population_inference_claimed": False,
        "cross_engine_equivalence_claimed": False,
        **population_expected,
    }, "POPULATION")
    require_fields(contract["threshold_and_margin_provenance"],
                   threshold_expected, "THRESHOLD")
    require_fields(contract["complete_zero_world_gate"], {
        "must_pass_before_physics": True,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_execution_authorized": False,
        "maximum_physical_steps_authorized": 0,
        **zero_gate_expected,
    }, "ZERO_GATE")
    require_fields(contract["physical_authorization_projection"], {
        "seed": population["cell_seed"],
        "same_identity_rerun_permitted": False,
        "recovery_success_required": False,
        "physical_execution_authorized": False,
        **authorization_expected,
    }, "AUTHORIZATION")


def validate_exact_runtime_and_inventory(
    root: Path,
    contract: dict[str, Any],
    inventory_count: int,
) -> Path:
    """Validate one exact executable and the complete current source population."""
    runtime = contract["exact_runtime"]
    executable = Path(runtime["console_path"])
    require(executable.is_file(), "EXACT_RUNTIME_MISSING")
    digest = "sha256:" + hashlib.sha256(executable.read_bytes()).hexdigest()
    require_fields(runtime, {
        "console_sha256": digest,
        "console_byte_length": executable.stat().st_size,
    }, "EXACT_RUNTIME")
    inventory = contract["source_inventory"]
    require(len(inventory) == inventory_count == len(set(inventory)),
            "SOURCE_INVENTORY")
    for relative in inventory:
        require((root / relative).is_file(), f"SOURCE_MISSING:{relative}")
    return executable


def run_zero_world_worker_specs(
    root: Path,
    executable: Path,
    specs: tuple[dict[str, Any], ...],
) -> dict[str, dict[str, Any]]:
    """Execute and zero-authority-check a declarative current-worker population."""
    receipts: dict[str, dict[str, Any]] = {}
    for spec in specs:
        worker = Path(spec["path"])
        require(worker.is_file(), f"WORKER_MISSING:{spec['id']}")
        receipt = run_godot_worker(
            root, executable, worker, str(spec["marker"]),
            tuple(spec.get("user_args", ())),
        )
        require_fields(receipt, dict(spec["expected"]), str(spec["id"]).upper())
        require_zero_authority(receipt)
        receipts[str(spec["id"])] = receipt
    return receipts


def validate_two_step_route_declaration(
    contract: dict[str, Any],
    gate_id: str,
    *,
    question_expected: dict[str, Any],
) -> None:
    """Validate the reusable one-world/two-step development-ghost contract."""

    validate_development_question(contract, gate_id)
    question = contract["route_ghost_question"]
    seed_label = str(question["seed_label"])
    seed_digest = hashlib.sha256(seed_label.encode("utf-8")).hexdigest()
    require_fields(
        question,
        {
            "seed_derivation_rule": (
                "uint32(first_8_sha256_hex_of_utf8_seed_label) & 0x7fffffff"
            ),
            "seed": int(seed_digest[:8], 16) & 0x7FFFFFFF,
            "seed_sha256": f"sha256:{seed_digest}",
            "held_out": False,
            "world_count": 1,
            "maximum_model_construction_attempt_count": 1,
            "maximum_model_construction_count": 1,
            "maximum_world_attempt_count": 1,
            "maximum_world_build_count": 1,
            "maximum_outer_solver_steps": 2,
            "minimum_completed_solver_steps_for_valid_route": 2,
            "physics_ticks_per_second": 120,
            "outer_step_duration_s": 1.0 / 120.0,
            "portable_collection_count": 2,
            "portable_control_plan_count": 2,
            "portable_command_application_count": 1,
            "behavior_evaluator_invocation_count": 0,
            "full_seeded_world_demo": False,
            "matched_zero_arm_required": False,
            "additional_seed_required": False,
            "recovery_success_required": False,
            "same_source_attempt_limit": 1,
            "same_identity_rerun_permitted": False,
            **question_expected,
        },
        "TWO_STEP_QUESTION",
    )
    require_fields(
        contract["coverage_adequacy"],
        {
            "new_behavior_threshold_count": 0,
            "new_empirical_threshold_count": 0,
            "new_margin_count": 0,
            "physical_population_claim_count": 0,
            "repeatability_claimed": False,
            "cross_engine_equivalence_claimed": False,
        },
        "TWO_STEP_COVERAGE",
    )
    require_fields(
        contract["threshold_margin_cohort_and_population_adequacy"],
        {
            "new_physical_threshold_count": 0,
            "new_equivalence_margin_count": 0,
            "development_seed_count": 1,
            "held_out_seed_count": 0,
            "population_claim_count": 0,
        },
        "TWO_STEP_ADEQUACY",
    )
    require_fields(
        contract["complete_zero_world_gate"],
        {
            "must_pass_before_physics": True,
            "official_qualification_must_start_clean_pushed_equal": True,
            "official_qualification_attempt_limit_per_source_commit": 1,
            "production_wrapper_runtime_identity_count": 1,
            "production_worker_parse_count": 1,
            "forced_supervisor_failure_control_count": 1,
            "missing_physical_switch_refusal_count": 1,
            "qualified_physical_path_partition_check_count": 1,
            "historical_closure_audits_executed_count": 0,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
            "physical_execution_authorized": False,
            "maximum_physical_steps_authorized": 0,
        },
        "TWO_STEP_ZERO_GATE",
    )
    require_fields(
        contract["physical_runner"],
        {
            "physical_question_kind": "integration_ghost",
            "published_closure_authorization_control_required": False,
            "direct_committed_closure_recheck_under_operation_lock_required": True,
            "qualified_physical_source_drift_check_required": True,
            "complete_raw_invariant_scan_required_after_physics": True,
            "valid_complete_status": "valid_complete_integration_ghost",
            "invalid_or_incomplete_status": "invalid_or_incomplete_integration_ghost",
        },
        "TWO_STEP_PHYSICAL_RUNNER",
    )
    require_fields(
        contract["physical_authorization_projection"],
        {
            "gate_id": gate_id,
            "question_class": "development",
            "seed": question["seed"],
            "seed_label": question["seed_label"],
            "seed_sha256": question["seed_sha256"],
            "held_out": False,
            "maximum_model_construction_attempt_count": 1,
            "maximum_model_construction_count": 1,
            "maximum_world_attempt_count": 1,
            "maximum_world_build_count": 1,
            "maximum_outer_solver_steps": 2,
            "behavior_evaluator_invocation_count": 0,
            "same_identity_rerun_permitted": False,
            "recovery_success_required": False,
            "physical_execution_authorized": False,
            "prone_to_standing_claimed": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        "TWO_STEP_AUTHORIZATION",
    )
    require_fields(
        contract["claim_boundary"],
        {
            "production_route_ghost_declared": True,
            "complete_zero_world_gate_passed": False,
            "physical_execution_authorized": False,
            "physical_attempted": False,
            "prone_to_standing_claimed": False,
            "sdk1_milestone_advanced": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        "TWO_STEP_CLAIM",
    )


def validate_route_source_populations(
    root: Path,
    contract: dict[str, Any],
) -> dict[str, int]:
    """Validate reusable inventory, path-role, and critical-path counts."""

    policy = contract["critical_path_audit_policy"]
    inventory = contract["source_inventory"]
    require(
        len(inventory) == len(set(inventory)) == policy["source_inventory_count"],
        "ROUTE_SOURCE_INVENTORY",
    )
    validate_exact_runtime_and_inventory(root, contract, len(inventory))
    qualified = contract["qualified_physical_paths"]
    require(
        len(qualified)
        == len(set(qualified))
        == policy["qualified_physical_path_count"],
        "ROUTE_QUALIFIED_PATHS",
    )
    require(set(qualified).issubset(set(inventory)), "ROUTE_QUALIFIED_SUBSET")
    publication = set(contract["source_path_roles"]["publication_only_paths"])
    require(not publication.intersection(qualified), "ROUTE_PATH_ROLE_OVERLAP")
    authored = contract["authored_source_paths"]
    require(
        len(authored) == len(set(authored)) == policy["authored_source_path_count"],
        "ROUTE_AUTHORED_PATHS",
    )
    require(set(authored).issubset(set(inventory)), "ROUTE_AUTHORED_SUBSET")
    current_zero_world_worker_count = int(
        policy.get("current_zero_world_worker_count", 0)
    )
    require(current_zero_world_worker_count >= 0, "ROUTE_ZERO_WORLD_WORKER_COUNT")
    return {
        "source_inventory_count": len(inventory),
        "authored_source_path_count": len(authored),
        "qualified_physical_path_count": len(qualified),
        "bound_predecessor_count": len(contract["bound_predecessors"]),
        "current_zero_world_worker_count": current_zero_world_worker_count,
        "production_worker_parse_count": 1,
        "historical_closure_audits_executed_count": 0,
        "full_seeded_ghost_count": 0,
        "bespoke_physical_canary_count": 0,
    }


def run_route_runtime_identity(
    root: Path,
    runner: Path,
    marker: str,
    *,
    gate_id: str,
    schema: str,
    contract: dict[str, Any],
    worker_relative_path: str,
    actuator_mode: str,
    expected_fields: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Parse the real worker through its thin production wrapper without physics."""

    completed = subprocess.run(
        [
            "pwsh",
            "-NoLogo",
            "-NoProfile",
            "-File",
            str(runner),
            "-Mode",
            "RuntimeIdentity",
        ],
        cwd=root,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="strict",
        check=False,
    )
    require(completed.returncode == 0, f"RUNTIME_IDENTITY_EXIT:{completed.returncode}")
    require(completed.stderr == "", f"RUNTIME_IDENTITY_STDERR:{completed.stderr}")
    receipt = _one_json_marker(completed.stdout, marker, "RUNTIME_IDENTITY")
    route_expected = {} if expected_fields is None else expected_fields
    require(isinstance(route_expected, dict), "RUNTIME_IDENTITY_EXPECTED_FIELDS")
    require_fields(
        receipt,
        {
            "schema_version": schema,
            "gate_id": gate_id,
            "ok": True,
            "selected_console_path": contract["exact_runtime"]["console_path"],
            "selected_console_sha256": contract["exact_runtime"]["console_sha256"],
            "selected_console_byte_length": contract["exact_runtime"][
                "console_byte_length"
            ],
            "worker_relative_path": worker_relative_path,
            "actuator_mode": actuator_mode,
            "worker_parse_count": 1,
            "source_audit_execution_count": 0,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
            "physical_execution_authorized": False,
            **route_expected,
        },
        "RUNTIME_IDENTITY",
    )
    require_zero_authority(receipt)
    return receipt
