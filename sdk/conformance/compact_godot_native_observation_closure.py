#!/usr/bin/env python3
"""Shared content-addressed closure audit for compact Godot observations."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import sys
from typing import Any

from sdk.conformance.compact_godot_zero_world_qualification import (
    verify_closure as verify_zero_world_closure,
)
from sdk.conformance.content_addressed_zero_world_closure import (
    ClosureAuditError,
    exact,
    load,
    require,
    sha256,
    source_bytes,
    verify_retained_file_tree,
)


def _identity(path: Path) -> dict[str, Any]:
    value = path.read_bytes()
    return {
        "path": path.as_posix(),
        "raw_sha256": sha256(value),
        "byte_length": len(value),
    }


def _require_artifact(
    root: Path,
    declaration: dict[str, Any],
    label: str,
) -> tuple[Path, dict[str, Any]]:
    path = Path(str(declaration["path"]))
    if not path.is_absolute():
        path = root / path
    path = path.resolve()
    require(path.is_file(), f"{label}_MISSING")
    observed = _identity(path)
    exact(observed["raw_sha256"], declaration["raw_sha256"], f"{label}_SHA256")
    exact(observed["byte_length"], declaration["byte_length"], f"{label}_LENGTH")
    return path, observed


def _verify_invalid_or_incomplete_closure(
    root: Path,
    contract: dict[str, Any],
    closure: dict[str, Any],
    authorization_identity: dict[str, Any],
) -> dict[str, Any]:
    """Verify a compact attempt that produced no interpretable native receipt."""

    runner = contract["physical_runner"]
    question = contract["prospective_physical_question"]
    physical = closure["physical_attempt"]
    evidence_root = Path(str(physical["evidence_root"])).resolve()
    require(evidence_root.is_dir(), "PHYSICAL_EVIDENCE_ROOT_MISSING")
    verify_retained_file_tree(evidence_root, physical["retained_tree"])

    artifacts = physical["artifacts"]
    exact(
        set(artifacts),
        {"attempt", "terminal", "stdout", "stderr"},
        "INVALID_ARTIFACT_KEYS",
    )
    artifact_paths: dict[str, Path] = {}
    artifact_identities: dict[str, dict[str, Any]] = {}
    for name in ("attempt", "terminal", "stdout", "stderr"):
        artifact_path, artifact_identity = _require_artifact(
            root,
            artifacts[name],
            f"PHYSICAL_{name.upper()}",
        )
        exact(artifact_path.parent, evidence_root, f"EVIDENCE_PARENT:{name}")
        artifact_paths[name] = artifact_path
        artifact_identities[name] = artifact_identity

    exact(
        {path.name for path in evidence_root.iterdir()},
        {
            "attempt.json",
            "terminal.json",
            "godot.stdout.log",
            "godot.stderr.log",
        },
        "INVALID_RETAINED_FILE_POPULATION",
    )
    require(
        not (evidence_root / "native-observation-report.json").exists(),
        "REPORT_EXISTS",
    )

    attempt = load(artifact_paths["attempt"])
    terminal = load(artifact_paths["terminal"])
    invalid_status = runner["invalid_or_incomplete_status"]
    execution_commit = str(closure["source"]["physical_execution_commit"])
    physical_gate = runner.get("worker_gate_id", contract["gate_id"])
    exact(physical["status"], invalid_status, "PHYSICAL_STATUS")
    exact(physical["official_attempt_count"], 1, "PHYSICAL_ATTEMPT_COUNT")
    expected_common = {
        "gate_id": contract["gate_id"],
        "physical_question_gate_id": physical_gate,
        "question_class": "development",
        "physical_question_kind": "native_observation_smoke",
        "status": invalid_status,
        "attempt_id": physical["attempt_id"],
        "source.head": execution_commit,
        "authorization.raw_sha256": authorization_identity["raw_sha256"],
        "same_identity_rerun_permitted": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    for path, value in expected_common.items():
        node: Any = attempt
        for part in path.split("."):
            node = node[part]
        exact(node, value, f"ATTEMPT_BINDING:{path}")
        node = terminal
        for part in path.split("."):
            node = node[part]
        exact(node, value, f"TERMINAL_BINDING:{path}")

    exact(attempt["schema_version"], runner["attempt_schema"], "ATTEMPT_SCHEMA")
    exact(terminal["schema_version"], runner["terminal_schema"], "TERMINAL_SCHEMA")
    exact(attempt["seed"], question["seed"], "ATTEMPT_SEED")
    exact(attempt["seed_label"], question["seed_label"], "ATTEMPT_SEED_LABEL")
    exact(attempt["seed_sha256"], question["seed_sha256"], "ATTEMPT_SEED_SHA")
    exact(
        attempt["maximum_world_build_count"],
        question["maximum_world_build_count"],
        "ATTEMPT_WORLD_CEILING",
    )
    exact(
        attempt["maximum_outer_solver_steps"],
        question["maximum_outer_solver_steps"],
        "ATTEMPT_STEP_CEILING",
    )
    exact(attempt["operation_lock"]["acquired"], True, "ATTEMPT_LOCK")
    exact(
        attempt["operation_lock"]["role"],
        "physical_development",
        "ATTEMPT_LOCK_ROLE",
    )
    exact(
        attempt["operation_lock"]["test_only"],
        False,
        "ATTEMPT_LOCK_TEST_ONLY",
    )
    exact(attempt["terminal_path"], "terminal.json", "ATTEMPT_TERMINAL_PATH")

    worker = terminal["worker"]
    exact(worker["semantic_exit_code"], 124, "WORKER_SEMANTIC_EXIT")
    exact(worker["host_exit_code"], -1, "WORKER_HOST_EXIT")
    exact(worker["timed_out"], True, "WORKER_TIMEOUT")
    exact(worker["termination_protocol_valid"], False, "WORKER_TERMINATION")
    exact(worker["raw_marker_count"], 0, "WORKER_RAW_MARKER_COUNT")
    exact(worker["raw_binding_valid"], False, "WORKER_RAW_BINDING")
    exact(
        (
            physical["worker_semantic_exit_code"],
            physical["worker_host_exit_code"],
            physical["worker_timed_out"],
            physical["termination_protocol_valid"],
            physical["raw_marker_count"],
            physical["raw_binding_valid"],
        ),
        (124, -1, True, False, 0, False),
        "PHYSICAL_WORKER_PROJECTION",
    )
    engine_health = worker["engine_health"]
    exact(engine_health["passed"], False, "ENGINE_HEALTH")
    exact(engine_health["fatal_diagnostic_line_count"], 1, "FATAL_COUNT")
    exact(
        engine_health["fatal_diagnostic_unique_line_count"],
        1,
        "FATAL_UNIQUE_COUNT",
    )
    exact(
        engine_health["ordered_unique_fatal_diagnostic_lines"],
        [
            "SCRIPT ERROR: Invalid access to property or key 'space' on a base object of type 'null instance'."
        ],
        "FATAL_DIAGNOSTIC",
    )
    exact(terminal["valid_complete"], False, "TERMINAL_VALID_COMPLETE")
    exact(terminal["artifacts"]["report"], None, "TERMINAL_REPORT")
    for name in ("stdout", "stderr"):
        exact(
            terminal["artifacts"][name],
            artifact_identities[name],
            f"TERMINAL_ARTIFACT:{name}",
        )

    stdout_text = artifact_paths["stdout"].read_text(encoding="utf-8")
    stderr_text = artifact_paths["stderr"].read_text(encoding="utf-8")
    require("Godot Engine v4.7.stable.custom_build" in stdout_text, "ENGINE_BANNER")
    exact(stderr_text.count("SCRIPT ERROR:"), 1, "STDERR_SCRIPT_ERROR_COUNT")
    require("null instance" in stderr_text, "STDERR_NULL_INSTANCE")
    require("_run_physical" in stderr_text, "STDERR_FAILURE_SITE")
    require("Jolt Physics job system exceeded" in stderr_text, "STDERR_JOLT_WARNING")

    frozen_worker = source_bytes(root, execution_commit, str(runner["worker_path"]))
    exact(
        frozen_worker.count(b"viewport.world_3d.space"),
        1,
        "FROZEN_NULL_LOOKUP_SITE",
    )
    exact(
        physical["observed_execution_counts"],
        {
            "model_construction_attempt_count": None,
            "model_construction_count": None,
            "world_attempt_count": None,
            "world_build_count": None,
            "solver_step_count": None,
            "native_readback_count": None,
            "in_run_physical_invariant_step_count": None,
        },
        "UNOBSERVABLE_EXECUTION_COUNTS",
    )
    exact(physical["same_identity_rerun_permitted"], False, "PHYSICAL_RERUN")
    exact(closure["decision"]["next_gate_id"], "QSDK-R24D160", "NEXT_GATE")
    exact(
        closure["decision"]["same_identity_rerun_permitted"],
        False,
        "DECISION_RERUN",
    )
    for key in (
        "valid_physics_result_observed",
        "native_v6_field_population_observed",
        "rotation_exchange_magnitude_recorded",
        "rotational_staging_cause_established",
        "behavior_improvement_established",
        "recovery_claimed",
        "prone_to_standing_claimed",
        "population_inference_claimed",
        "cross_engine_equivalence_claimed",
        "physical_acceptance_authority",
        "release_authority",
    ):
        exact(closure["claim_boundary"][key], False, f"CLAIM_BOUNDARY:{key}")

    return {
        "schema_version": contract["physical_closure"]["audit_receipt_schema"],
        "gate_id": contract["gate_id"],
        "physical_question_gate_id": physical_gate,
        "ok": True,
        "status": closure["status"],
        "source_freeze_commit": closure["source"]["source_freeze_commit"],
        "physical_execution_commit": execution_commit,
        "attempt_id": physical["attempt_id"],
        "artifact_identities": artifact_identities,
        "worker_timed_out": True,
        "raw_marker_count": 0,
        "observed_execution_counts_available": False,
        "same_identity_rerun_permitted": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def verify_physical_closure(root: Path, contract_path: Path) -> dict[str, Any]:
    contract = load(contract_path)
    zero_audit = verify_zero_world_closure(root, contract_path)
    closure_path = root / str(contract["physical_closure"]["path"])
    closure = load(closure_path)
    require(
        closure["status"]
        in {
            "closed_valid_complete_native_observation_smoke",
            "closed_consumed_invalid_or_incomplete_native_observation_smoke",
        },
        "PHYSICAL_CLOSURE_STATUS",
    )
    exact(
        (
            closure["schema_version"],
            closure["gate_id"],
            closure["question_class"],
            closure["physical_question_kind"],
        ),
        (
            contract["physical_closure"]["schema"],
            contract["gate_id"],
            "development",
            "native_observation_smoke",
        ),
        "PHYSICAL_CLOSURE_IDENTITY",
    )
    source_freeze = str(closure["source"]["source_freeze_commit"])
    exact(source_freeze, zero_audit["source_freeze_commit"], "SOURCE_FREEZE")

    authorization_path, authorization_identity = _require_artifact(
        root,
        closure["authorization"],
        "AUTHORIZATION",
    )
    exact(
        authorization_path,
        (root / str(contract["closure"]["path"])).resolve(),
        "AUTHORIZATION_PATH",
    )
    authorization = load(authorization_path)
    exact(
        authorization["source"]["source_freeze_commit"],
        source_freeze,
        "AUTHORIZATION_SOURCE_FREEZE",
    )
    exact(
        authorization["decision"]["physical_native_observation_authorized"],
        True,
        "AUTHORIZATION_NATIVE_OBSERVATION",
    )
    exact(
        closure["authorization"]["raw_sha256"],
        authorization_identity["raw_sha256"],
        "AUTHORIZATION_IDENTITY",
    )

    if closure["status"] == "closed_consumed_invalid_or_incomplete_native_observation_smoke":
        return _verify_invalid_or_incomplete_closure(
            root,
            contract,
            closure,
            authorization_identity,
        )

    physical = closure["physical_attempt"]
    evidence_root = Path(str(physical["evidence_root"])).resolve()
    require(evidence_root.is_dir(), "PHYSICAL_EVIDENCE_ROOT_MISSING")
    verify_retained_file_tree(evidence_root, physical["retained_tree"])
    artifacts = physical["artifacts"]
    exact(
        set(artifacts),
        {"attempt", "report", "terminal", "stdout", "stderr"},
        "VALID_ARTIFACT_KEYS",
    )
    artifact_paths: dict[str, Path] = {}
    artifact_identities: dict[str, dict[str, Any]] = {}
    for name in ("attempt", "report", "terminal", "stdout", "stderr"):
        artifact_path, artifact_identity = _require_artifact(
            root,
            artifacts[name],
            f"PHYSICAL_{name.upper()}",
        )
        exact(artifact_path.parent, evidence_root, f"EVIDENCE_PARENT:{name}")
        artifact_paths[name] = artifact_path
        artifact_identities[name] = artifact_identity
    exact(
        {path.name for path in evidence_root.iterdir()},
        {
            "attempt.json",
            "native_observation.json",
            "terminal.json",
            "godot.stdout.log",
            "godot.stderr.log",
        },
        "VALID_RETAINED_FILE_POPULATION",
    )

    attempt = load(artifact_paths["attempt"])
    report = load(artifact_paths["report"])
    terminal = load(artifact_paths["terminal"])
    question = contract["prospective_physical_question"]
    runner = contract["physical_runner"]
    execution_commit = str(closure["source"]["physical_execution_commit"])
    physical_gate = runner.get("worker_gate_id", contract["gate_id"])
    exact(physical["status"], runner["valid_complete_status"], "PHYSICAL_STATUS")
    exact(physical["official_attempt_count"], 1, "PHYSICAL_ATTEMPT_COUNT")
    exact(physical["same_identity_rerun_permitted"], False, "PHYSICAL_RERUN")
    expected_attempt_binding = {
        "gate_id": contract["gate_id"],
        "physical_question_gate_id": physical_gate,
        "question_class": "development",
        "physical_question_kind": "native_observation_smoke",
        "status": runner["valid_complete_status"],
        "attempt_id": physical["attempt_id"],
        "source.head": execution_commit,
        "authorization.raw_sha256": authorization_identity["raw_sha256"],
        "same_identity_rerun_permitted": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    for path, value in expected_attempt_binding.items():
        for document, label in ((attempt, "ATTEMPT"), (terminal, "TERMINAL")):
            node: Any = document
            for part in path.split("."):
                node = node[part]
            exact(node, value, f"{label}_BINDING:{path}")
    exact(attempt["schema_version"], runner["attempt_schema"], "ATTEMPT_SCHEMA")
    exact(attempt["seed"], question["seed"], "ATTEMPT_SEED")
    exact(attempt["seed_label"], question["seed_label"], "ATTEMPT_SEED_LABEL")
    exact(attempt["seed_sha256"], question["seed_sha256"], "ATTEMPT_SEED_SHA")
    exact(
        attempt["maximum_world_build_count"],
        question["maximum_world_build_count"],
        "ATTEMPT_WORLD_CEILING",
    )
    exact(
        attempt["maximum_outer_solver_steps"],
        question["maximum_outer_solver_steps"],
        "ATTEMPT_STEP_CEILING",
    )
    exact(attempt["operation_lock"]["acquired"], True, "ATTEMPT_LOCK")
    exact(
        attempt["operation_lock"]["role"],
        "physical_development",
        "ATTEMPT_LOCK_ROLE",
    )
    exact(attempt["operation_lock"]["test_only"], False, "ATTEMPT_LOCK_TEST_ONLY")
    exact(attempt["terminal_path"], "terminal.json", "ATTEMPT_TERMINAL_PATH")

    expected_binding = {
        "gate_id": physical_gate,
        "question_class": "development",
        "physical_question_kind": "native_observation_smoke",
        "status": runner["valid_complete_status"],
        "source_commit": execution_commit,
        "authorization_sha256": authorization_identity["raw_sha256"],
        "attempt_id": physical["attempt_id"],
    }
    if "source_successor_id" in runner:
        expected_binding["source_successor_id"] = runner["source_successor_id"]
    for key, value in expected_binding.items():
        exact(report[key], value, f"REPORT_BINDING:{key}")
    exact(
        report["execution_nonce"],
        closure["physical_attempt"]["execution_nonce"],
        "NONCE",
    )
    exact(report["seed"], question["seed"], "SEED")
    exact(report["seed_label"], question["seed_label"], "SEED_LABEL")
    exact(report["seed_sha256"], question["seed_sha256"], "SEED_SHA256")
    exact(report["held_out"], False, "HELD_OUT")
    exact(report["ok"], True, "REPORT_OK")

    stdout_text = artifact_paths["stdout"].read_text(encoding="utf-8")
    stderr_text = artifact_paths["stderr"].read_text(encoding="utf-8")
    exact(stderr_text, "", "STDERR_EMPTY")
    raw_marker = str(runner["raw_marker"])
    raw_lines = [
        line for line in stdout_text.splitlines() if line.startswith(raw_marker)
    ]
    exact(len(raw_lines), 1, "RAW_MARKER_COUNT")
    raw = json.loads(raw_lines[0][len(raw_marker):])
    for key, value in expected_binding.items():
        if key != "status":
            exact(raw[key], value, f"RAW_BINDING:{key}")
    exact(raw["status"], runner["valid_complete_status"], "RAW_STATUS")
    exact(raw["ok"], True, "RAW_OK")
    exact(raw["execution_nonce"], report["execution_nonce"], "RAW_NONCE")
    exact(raw["seed"], question["seed"], "RAW_SEED")
    exact(raw["seed_sha256"], question["seed_sha256"], "RAW_SEED_SHA")
    exact(raw["model_construction_attempt_count"], 1, "RAW_MODEL_ATTEMPTS")
    exact(raw["model_construction_count"], 1, "RAW_MODELS")
    exact(raw["world_attempt_count"], 1, "RAW_WORLD_ATTEMPTS")
    exact(raw["world_build_count"], 1, "RAW_WORLDS")
    exact(raw["solver_step_count"], 2, "RAW_STEPS")
    exact(raw["native_readback_count"], 2, "RAW_READBACKS")
    exact(raw["in_run_physical_invariant_step_count"], 2, "RAW_INVARIANT_STEPS")
    exact(raw["all_in_run_physical_invariants_passed"], True, "RAW_INVARIANTS")
    if "terminal_physics_server_deactivation_count" in runner:
        exact(
            raw["terminal_physics_server_deactivation_count"],
            runner["terminal_physics_server_deactivation_count"],
            "RAW_TERMINAL_PHYSICS_SERVER_DEACTIVATION_COUNT",
        )
    exact(raw["report_written"], True, "RAW_REPORT_WRITTEN")
    exact(raw["physics_state_modified"], True, "RAW_PHYSICS_MODIFIED")
    exact(raw["native_field_population_observed"], True, "RAW_FIELD_POPULATION")
    for key in (
        "portable_collection_count",
        "portable_control_plan_count",
        "portable_command_application_count",
        "behavior_evaluator_invocation_count",
    ):
        exact(raw[key], 0, f"RAW_ZERO_EXECUTION:{key}")
    for key in (
        "prone_to_standing_claimed",
        "physical_acceptance_authority",
        "release_authority",
    ):
        exact(raw[key], False, f"RAW_CLAIM_BOUNDARY:{key}")



    engine = report["engine"]
    exact(engine["physics_engine"], "Jolt Physics", "ENGINE")
    exact(engine["physics_ticks_per_second"], 120, "PHYSICS_HZ")
    exact(engine["solver_velocity_steps"], 20, "VELOCITY_STEPS")
    exact(engine["solver_position_steps"], 4, "POSITION_STEPS")
    exact(engine["thread_model"], "single_safe", "THREAD_MODEL")
    exact(engine["telemetry_class_registered"], True, "TELEMETRY_CLASS")
    exact(engine["telemetry_method_registered"], True, "TELEMETRY_METHOD")
    exact(
        engine["telemetry_schema_version"],
        "sporespore.godot_jolt_solver_energy_exchange_telemetry.v2",
        "TELEMETRY_SCHEMA",
    )
    exact(
        engine["telemetry_profile_id"],
        "godot_4_7_jolt_sporespore_solver_energy_exchange_telemetry_v6",
        "TELEMETRY_PROFILE",
    )
    readback = report["parameter_readback"]
    require(math.isclose(float(readback["child_mass_kg"]), 1.0), "CHILD_MASS")
    for observed, expected in zip(
        readback["child_inertia_diagonal_kg_m2"],
        (0.031, 0.047, 0.083),
        strict=True,
    ):
        require(math.isclose(float(observed), expected, rel_tol=1e-6), "CHILD_INERTIA")
    for observed, expected in zip(
        readback["initial_angular_velocity_world_rad_s"],
        (1.25, -0.75, 2.0),
        strict=True,
    ):
        require(math.isclose(float(observed), expected, rel_tol=1e-6), "INITIAL_OMEGA")
    exact(readback["gravity_scale"], 0.0, "GRAVITY_SCALE")
    exact(readback["linear_damping"], 0.0, "LINEAR_DAMPING")
    exact(readback["angular_damping"], 0.0, "ANGULAR_DAMPING")
    exact(readback["can_sleep"], False, "CAN_SLEEP")
    if "expected_world_binding" in runner:
        for path, expected in runner["expected_world_binding"].items():
            node: Any = report["world_binding"]
            for part in path.split("."):
                node = node[part]
            exact(node, expected, f"WORLD_BINDING:{path}")

    execution = report["execution"]
    exact(execution["model_construction_attempt_count"], 1, "MODEL_ATTEMPTS")
    exact(execution["model_construction_count"], 1, "MODELS")
    exact(execution["world_attempt_count"], 1, "WORLD_ATTEMPTS")
    exact(execution["world_build_count"], 1, "WORLDS")
    exact(execution["solver_step_count"], 2, "STEPS")
    exact(execution["native_readback_count"], 2, "READBACKS")
    exact(execution["in_run_physical_invariant_step_count"], 2, "INVARIANT_STEPS")
    exact(execution["all_in_run_physical_invariants_passed"], True, "INVARIANTS")
    if "terminal_physics_server_deactivation_count" in runner:
        exact(
            execution["terminal_physics_server_deactivation_count"],
            runner["terminal_physics_server_deactivation_count"],
            "TERMINAL_PHYSICS_SERVER_DEACTIVATION_COUNT",
        )
    exact(
        execution["physics_tick_rate_configuration_write_count"],
        1,
        "PHYSICS_TICK_RATE_WRITE",
    )
    for key in (
        "portable_collection_count",
        "portable_control_plan_count",
        "portable_command_application_count",
        "behavior_evaluator_invocation_count",
        "direct_force_write_count",
        "direct_torque_write_count",
        "direct_impulse_write_count",
        "outcome_dependent_early_stop_count",
    ):
        exact(execution[key], 0, f"ZERO_EXECUTION:{key}")

    samples = report["samples"]
    exact(len(samples), 2, "SAMPLE_COUNT")
    rotations: list[float] = []
    sequences: list[int] = []
    for expected_step, sample in enumerate(samples, start=1):
        exact(sample["step_index"], expected_step, "SAMPLE_STEP")
        invariant = sample["in_run_invariants"]
        exact(invariant["passed"], True, "SAMPLE_INVARIANT_PASS")
        exact(
            invariant["check_count"],
            runner.get("in_run_invariant_check_count", 11),
            "SAMPLE_INVARIANT_COUNT",
        )
        require(all(invariant["checks"].values()), "SAMPLE_INVARIANT_CHECK")
        telemetry = sample["telemetry"]
        consumer = sample["consumer"]
        exact(consumer["ok"], True, "CONSUMER_OK")
        exact(consumer["check_count"], 38, "CONSUMER_CHECK_COUNT")
        exact(telemetry["complete"], True, "NATIVE_COMPLETE")
        exact(telemetry["source_measurement"], True, "SOURCE_MEASUREMENT")
        exact(telemetry["snapshot_is_current_space_step"], True, "CURRENT_SNAPSHOT")
        sequence = int(telemetry["read_space_step_sequence"])
        exact(telemetry["capture_space_step_sequence"], sequence, "CAPTURE_SEQUENCE")
        sequences.append(sequence)
        rotation = float(consumer["rotation_integration_kinetic_exchange_j"])
        require(math.isfinite(rotation), "ROTATION_EXCHANGE_NONFINITE")
        rotations.append(rotation)
    exact(sequences[1], sequences[0] + 1, "CONSECUTIVE_SEQUENCES")
    exact(report["rotation_integration_kinetic_exchange_j"], rotations, "ROTATIONS")
    exact(
        closure["observation"]["space_step_sequences"], sequences, "CLOSURE_SEQUENCES"
    )
    exact(
        closure["observation"]["rotation_integration_kinetic_exchange_j"],
        rotations,
        "CLOSURE_ROTATIONS",
    )

    exact(terminal["schema_version"], runner["terminal_schema"], "TERMINAL_SCHEMA")
    exact(terminal["gate_id"], contract["gate_id"], "TERMINAL_GATE")
    exact(
        terminal["physical_question_gate_id"],
        runner.get("worker_gate_id", contract["gate_id"]),
        "TERMINAL_PHYSICAL_GATE",
    )
    exact(terminal["status"], runner["valid_complete_status"], "TERMINAL_STATUS")
    exact(terminal["valid_complete"], True, "TERMINAL_VALID")
    exact(
        terminal["attempt_id"],
        closure["physical_attempt"]["attempt_id"],
        "TERMINAL_ATTEMPT",
    )
    exact(terminal["worker"]["semantic_exit_code"], 0, "WORKER_SEMANTIC_EXIT")
    exact(terminal["worker"]["host_exit_code"], -1, "WORKER_HOST_EXIT")
    exact(terminal["worker"]["timed_out"], False, "TERMINAL_TIMEOUT")
    exact(terminal["worker"]["termination_protocol_valid"], True, "TERMINATION")
    exact(terminal["worker"]["raw_marker_count"], 1, "RAW_MARKER_COUNT")
    exact(terminal["worker"]["raw_binding_valid"], True, "RAW_BINDING")
    exact(terminal["worker"]["engine_health"]["passed"], True, "ENGINE_HEALTH")
    exact(
        (
            physical["worker_semantic_exit_code"],
            physical["worker_host_exit_code"],
            physical["worker_timed_out"],
            physical["termination_protocol_valid"],
            physical["raw_marker_count"],
            physical["raw_binding_valid"],
            physical["native_engine_health_passed"],
        ),
        (0, -1, False, True, 1, True, True),
        "PHYSICAL_WORKER_PROJECTION",
    )
    exact(
        physical["observed_execution_counts"],
        {
            "model_construction_attempt_count": 1,
            "model_construction_count": 1,
            "world_attempt_count": 1,
            "world_build_count": 1,
            "solver_step_count": 2,
            "native_readback_count": 2,
            "in_run_physical_invariant_step_count": 2,
            "in_run_physical_invariant_check_count": (
                2 * runner.get("in_run_invariant_check_count", 11)
            ),
        },
        "PHYSICAL_EXECUTION_PROJECTION",
    )
    for name in ("report", "stdout", "stderr"):
        exact(
            terminal["artifacts"][name]["path"],
            artifact_identities[name]["path"],
            f"TERMINAL_ARTIFACT_PATH:{name}",
        )
        exact(
            terminal["artifacts"][name]["raw_sha256"],
            artifact_identities[name]["raw_sha256"],
            f"TERMINAL_ARTIFACT_SHA256:{name}",
        )
        exact(
            terminal["artifacts"][name]["byte_length"],
            artifact_identities[name]["byte_length"],
            f"TERMINAL_ARTIFACT_LENGTH:{name}",
        )

    claims = report["claims"]
    exact(claims["native_v6_field_population_observed"], True, "POPULATION_OBSERVED")
    exact(claims["rotation_exchange_magnitude_recorded"], True, "MAGNITUDE_RECORDED")
    for key in (
        "rotation_exchange_nonzero_claimed",
        "rotational_staging_cause_established",
        "behavior_improvement_established",
        "recovery_claimed",
        "prone_to_standing_claimed",
        "population_inference_claimed",
        "cross_engine_equivalence_claimed",
        "physical_acceptance_authority",
        "release_authority",
    ):
        exact(claims[key], False, f"CLAIM_BOUNDARY:{key}")
    exact(
        closure["claim_boundary"]["physical_acceptance_authority"],
        False,
        "CLOSURE_ACCEPTANCE",
    )
    exact(closure["claim_boundary"]["release_authority"], False, "CLOSURE_RELEASE")

    return {
        "schema_version": contract["physical_closure"]["audit_receipt_schema"],
        "gate_id": contract["gate_id"],
        "physical_question_gate_id": runner.get(
            "worker_gate_id", contract["gate_id"]
        ),
        "ok": True,
        "source_freeze_commit": source_freeze,
        "physical_execution_commit": closure["source"]["physical_execution_commit"],
        "attempt_id": closure["physical_attempt"]["attempt_id"],
        "artifact_identities": artifact_identities,
        "space_step_sequences": sequences,
        "rotation_integration_kinetic_exchange_j": rotations,
        "model_construction_count": 1,
        "world_build_count": 1,
        "solver_step_count": 2,
        "native_readback_count": 2,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def run_cli(root: Path, contract_relative: str) -> int:
    parser = argparse.ArgumentParser()
    parser.parse_args()
    contract_path = root / contract_relative
    contract: dict[str, Any] = {}
    try:
        contract = load(contract_path)
        receipt = verify_physical_closure(root, contract_path)
        print(
            contract["physical_closure"]["audit_marker"]
            + " "
            + json.dumps(receipt, sort_keys=True, separators=(",", ":"))
        )
        return 0
    except (
        ClosureAuditError,
        KeyError,
        OSError,
        ValueError,
        json.JSONDecodeError,
    ) as error:
        marker = contract.get("physical_closure", {}).get(
            "audit_fail_marker",
            "QSDK_COMPACT_GODOT_NATIVE_OBSERVATION_CLOSURE_FAIL",
        )
        print(marker + " " + json.dumps({"ok": False, "error": str(error)}))
        return 1


if __name__ == "__main__":
    raise SystemExit("Use a thin campaign binding.")
