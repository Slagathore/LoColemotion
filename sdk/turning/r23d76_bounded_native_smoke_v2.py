"""Precisely invalidated successor to the R23D76 bounded native smoke v1."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import secrets
import shutil
import sys
import uuid
from collections.abc import Mapping, Sequence
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[2]
TURNING_ROOT = REPO_ROOT / "sdk/turning"
CONTRACT_PATH = TURNING_ROOT / "r23d76_bounded_native_smoke_v2.json"
SUPERVISOR_PATH = Path(__file__).resolve()
TEST_PATH = REPO_ROOT / "tests/test_qsdk_r23d76_bounded_native_smoke_v2.py"
V1_SUPERVISOR_PATH = TURNING_ROOT / "r23d76_bounded_native_smoke.py"
V1_CLOSURE_PATH = TURNING_ROOT / "r23d76_bounded_native_smoke_v1_closure.json"
V1_CLOSURE_AUDIT_PATH = REPO_ROOT / "sdk/audit_r23d76_bounded_native_smoke_v1_closure.py"
DEFAULT_EVIDENCE_ROOT = REPO_ROOT.parent / "SporeSpore_Evidence"


def _load_module(name: str, path: Path) -> Any:
    specification = importlib.util.spec_from_file_location(name, path)
    if specification is None or specification.loader is None:
        raise RuntimeError(f"R23D76_SMOKE_V2_IMPORT_INVALID:{path}")
    module = importlib.util.module_from_spec(specification)
    sys.modules[specification.name] = module
    specification.loader.exec_module(module)
    return module


base = _load_module("_r23d76_bounded_smoke_v1_base", V1_SUPERVISOR_PATH)
v1_audit = _load_module("_r23d76_bounded_smoke_v1_closure_audit", V1_CLOSURE_AUDIT_PATH)
delegate = base.delegate

SMOKE_ID = "QSDK-R23D76-BOUNDED-NATIVE-SMOKE-V2"
SCHEMA = "sporespore_qsdk_r23d76_bounded_native_smoke_v2"
LEDGER_SCOPE = {
    "subsystem": "turning",
    "engine_scope": "3e",
    "authority_mode": "bounded_native_smoke_successor",
    "question_class": "development",
}
ENGINE_IDS = base.ENGINE_IDS
DEVELOPMENT_SEED = base.DEVELOPMENT_SEED
HELD_OUT_SEED = base.HELD_OUT_SEED
MAX_WORLD_COUNT = base.MAX_WORLD_COUNT
MAX_SOLVER_STEPS_PER_ENGINE = base.MAX_SOLVER_STEPS_PER_ENGINE
PREFLIGHT_MARKER = "QSDK_R23D76_BOUNDED_NATIVE_SMOKE_V2_PREFLIGHT "
RESULT_MARKER = "QSDK_R23D76_BOUNDED_NATIVE_SMOKE_V2_RESULT "
ERROR_MARKER = "QSDK_R23D76_BOUNDED_NATIVE_SMOKE_V2_ERROR "


class SmokeV2Error(RuntimeError):
    pass


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise SmokeV2Error(f"R23D76_BOUNDED_SMOKE_V2_{code}")


def _load(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise SmokeV2Error(f"R23D76_BOUNDED_SMOKE_V2_JSON_UNREADABLE:{path}") from error
    _require(isinstance(value, dict), "JSON_NOT_OBJECT")
    return value


CONTRACT = _load(CONTRACT_PATH)


def _sha(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return "sha256:" + digest.hexdigest()


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def validate_contract(value: Mapping[str, Any]) -> None:
    _require(value.get("schema_version") == SCHEMA, "SCHEMA_INVALID")
    _require(value.get("smoke_id") == SMOKE_ID, "ID_INVALID")
    _require(
        value.get("status") == "prospective_source_only_physical_not_opened",
        "STATUS_INVALID",
    )
    _require(value.get("question_class") == "development", "QUESTION_CLASS_INVALID")
    _require(value.get("ledger_scope") == LEDGER_SCOPE, "LEDGER_SCOPE_INVALID")

    predecessor = value.get("predecessor")
    _require(isinstance(predecessor, Mapping), "PREDECESSOR_INVALID")
    _require(
        predecessor.get("smoke_id") == base.SMOKE_ID
        and predecessor.get("closure_path")
        == "sdk/turning/r23d76_bounded_native_smoke_v1_closure.json"
        and predecessor.get("closure_raw_sha256") == _sha(V1_CLOSURE_PATH)
        and predecessor.get("required_status")
        == "closed_consumed_prephysical_incomplete_zero_world_no_native_world_opened"
        and predecessor.get("observed_physical_worker_process_count") == 0
        and predecessor.get("observed_world_build_count") == 0
        and predecessor.get("observed_solver_step_count") == 0
        and predecessor.get("held_out_seed_23197_opened") is False
        and predecessor.get("historical_result_reinterpreted") is False
        and predecessor.get("historical_protocol_or_interpretation_changed") is False,
        "PREDECESSOR_DRIFT",
    )

    parent = value.get("parent_finite_decision")
    _require(isinstance(parent, Mapping), "PARENT_INVALID")
    _require(
        parent.get("campaign_id")
        == "QSDK-R23D76-FRESH-FINITE-THREE-ENGINE-TURNING-DECISION"
        and parent.get("gate_id") == "QSDK-R23D76"
        and parent.get("held_out_seed") == HELD_OUT_SEED
        and parent.get("complete_zero_world_gate_must_remain_passed") is True
        and parent.get("all_222_implementation_dependency_digests_must_remain_exact")
        is True
        and parent.get("physical_campaign_execution_authorized") is False,
        "PARENT_DRIFT",
    )

    invalidation = value.get("precise_invalidation")
    _require(isinstance(invalidation, Mapping), "INVALIDATION_INVALID")
    expected_invalidation = {
        "historical_complete_cold_gate_artifact_count": 15,
        "required_exact_reuse_artifact_count": 14,
        "permitted_invalidated_artifact_count": 1,
        "permitted_invalidated_artifact_path": (
            "sdk/target/debug/turning_three_engine_route.exe"
        ),
        "permitted_invalidated_artifact_is_derived": True,
        "focused_requalification_engine_id": "rapier_parry",
        "focused_zero_world_preflight_process_count": 1,
        "focused_preflight_negative_control_count": 2,
        "focused_preflight_must_return_before_model": True,
        "any_other_dependency_toolchain_or_environment_drift_fails_closed": True,
        "full_historical_canary_suite_repeated": False,
    }
    _require(dict(invalidation) == expected_invalidation, "INVALIDATION_PROTOCOL_DRIFT")

    population = value.get("bounded_population")
    _require(isinstance(population, Mapping), "POPULATION_INVALID")
    _require(
        population.get("ordered_engine_ids") == list(ENGINE_IDS)
        and population.get("complete_engine_population_count") == 3
        and population.get("development_seed") == DEVELOPMENT_SEED
        and population.get("development_seed_is_outcome_exposed") is True
        and population.get("uses_held_out_seed_23197") is False
        and population.get("maximum_world_count") == 3
        and population.get("maximum_world_count_per_engine") == 1
        and population.get("maximum_solver_step_count_per_engine") == 2
        and population.get("maximum_total_solver_step_count") == 6
        and population.get("sampling_used") is False,
        "POPULATION_DRIFT",
    )

    protocol = value.get("execution_protocol")
    _require(isinstance(protocol, Mapping), "PROTOCOL_INVALID")
    expected_counts = {
        "rapier_build_process_count": 1,
        "focused_invalidated_artifact_preflight_process_count": 1,
        "redundant_native_preflight_process_count": 0,
        "separate_authorization_canary_process_count": 0,
        "aggregate_behavior_evaluator_process_count": 0,
        "full_seeded_ghost_process_count": 0,
        "physical_worker_process_count": 3,
    }
    _require(
        all(protocol.get(field) == expected for field, expected in expected_counts.items()),
        "PROCESS_COUNTS_INVALID",
    )
    for field in (
        "clean_pushed_live_equal_source_required",
        "machine_wide_physical_mutex_required",
        "serial_engine_order_required",
        "append_only_attempt_required",
        "continue_after_valid_physics_failure",
        "world_construction_required_per_engine",
        "bounded_native_smoke_execution_authorized_after_clean_push",
    ):
        _require(protocol.get(field) is True, f"PROTOCOL_{field.upper()}_INVALID")
    _require(
        protocol.get("held_out_finite_campaign_execution_authorized") is False,
        "HELD_OUT_CAMPAIGN_AUTHORIZED",
    )

    adequacy = value.get("adequacy")
    _require(
        isinstance(adequacy, Mapping)
        and adequacy.get("complete_native_producer_population_count") == 3
        and adequacy.get("sampling_used") is False
        and adequacy.get("behavior_threshold") is None
        and adequacy.get("equivalence_margin") is None
        and adequacy.get("non_inferiority_margin") is None
        and len(str(adequacy.get("argument", ""))) >= 300,
        "ADEQUACY_INVALID",
    )
    interpretation = value.get("interpretation")
    _require(
        isinstance(interpretation, Mapping)
        and all(item is False for item in interpretation.values()),
        "INTERPRETATION_INVALID",
    )
    claims = value.get("claims")
    _require(
        isinstance(claims, Mapping)
        and len(claims) == 14
        and all(item is False for item in claims.values()),
        "CLAIMS_INVALID",
    )


def preflight() -> dict[str, Any]:
    validate_contract(CONTRACT)
    closure_receipt = v1_audit.audit()
    _require(closure_receipt.get("passed") is True, "V1_CLOSURE_AUDIT_FAILED")
    parent = base._validate_parent_authorities()
    return {
        "schema_version": "sporespore_qsdk_r23d76_bounded_native_smoke_v2_preflight_v1",
        "smoke_id": SMOKE_ID,
        "ledger_scope": dict(LEDGER_SCOPE),
        "contract_artifact": base._source_artifact(CONTRACT_PATH),
        "supervisor_artifact": base._source_artifact(SUPERVISOR_PATH),
        "v1_closure_artifact": base._source_artifact(V1_CLOSURE_PATH),
        "v1_closure_audit_receipt": closure_receipt,
        "parent_authorities": parent,
        "r23d76_dependency_count": parent["r23d76_dependency_count"],
        "precise_runtime_invalidation_check_pending": True,
        "focused_invalidated_artifact_preflight_process_count": 0,
        "redundant_native_preflight_process_count": 0,
        "physical_worker_process_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
    }


def _precise_invalidation_proof(
    runtime: Any, current_artifacts: Sequence[Mapping[str, Any]]
) -> dict[str, Any]:
    route_closure = base._load_json(base.DELEGATE_CLOSURE_PATH, "DELEGATE_CLOSURE")
    passing = route_closure["passing_attempt"]
    zero_world_path = (
        Path(str(passing["attempt_root"])).resolve(strict=True)
        / "zero-world/complete-gate.json"
    )
    zero_world = base._load_json(zero_world_path, "COLD_ZERO_WORLD")
    selected = route_closure.get("passing_evidence_population", {}).get(
        "selected_artifacts"
    )
    _require(isinstance(selected, list), "COLD_SELECTION_INVALID")
    selected_zero = [
        item
        for item in selected
        if isinstance(item, Mapping)
        and item.get("relative_path") == "zero-world/complete-gate.json"
    ]
    _require(
        len(selected_zero) == 1
        and selected_zero[0].get("raw_sha256") == base._raw_sha256(zero_world_path)
        and selected_zero[0].get("byte_length") == zero_world_path.stat().st_size,
        "COLD_EVIDENCE_ARTIFACT_DRIFT",
    )
    historical = zero_world.get("dependency_artifacts")
    _require(isinstance(historical, list) and len(historical) == 15, "COLD_KEY_INVALID")
    _require(
        zero_world.get("complete_zero_world_gate_passed") is True
        and zero_world.get("world_build_count") == 0
        and zero_world.get("physical_execution_authorized") is False,
        "COLD_GATE_INVALID",
    )
    historical_map = base._artifact_map(historical, "V2_HISTORICAL")
    current_map = base._artifact_map(current_artifacts, "V2_CURRENT")
    _require(set(current_map) == set(historical_map), "DEPENDENCY_POPULATION_DRIFT")
    differences = sorted(
        key for key in historical_map if historical_map[key] != current_map[key]
    )
    expected_key = base._canonical_artifact_key(runtime.rapier_binary)
    _require(differences == [expected_key], "PRECISE_INVALIDATION_SET_INVALID")
    _require(
        zero_world.get("environment") == base._environment_receipt(),
        "ENVIRONMENT_DRIFT",
    )
    historical_by_key = {
        base._canonical_artifact_key(item["path"]): dict(item) for item in historical
    }
    current_by_key = {
        base._canonical_artifact_key(item["path"]): dict(item)
        for item in current_artifacts
    }
    return {
        "schema_version": "sporespore_qsdk_r23d76_precise_invalidation_proof_v2",
        "smoke_id": SMOKE_ID,
        "historical_cold_gate_artifact": {
            "path": str(zero_world_path),
            "sha256": base._raw_sha256(zero_world_path),
            "byte_length": zero_world_path.stat().st_size,
        },
        "historical_dependency_artifact_count": len(historical),
        "exact_reuse_artifact_count": len(historical) - len(differences),
        "invalidated_artifact_count": len(differences),
        "invalidated_artifact": {
            "historical": historical_by_key[expected_key],
            "current": current_by_key[expected_key],
            "derived_artifact": True,
            "focused_zero_world_requalification_required": True,
        },
        "all_other_dependency_toolchain_environment_keys_exact": True,
        "environment": base._environment_receipt(),
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
    }


def _attempt_root(evidence_root: Path, attempt_id: str) -> Path:
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    return (
        evidence_root
        / "turning/r23d76-bounded-native-smoke-v2"
        / f"{stamp}__{attempt_id}"
    )


def _require_evidence_root(value: Path | None) -> Path:
    expected = DEFAULT_EVIDENCE_ROOT.resolve()
    candidate = expected if value is None else value.resolve()
    _require(candidate == expected, f"EVIDENCE_ROOT_INVALID:{candidate}")
    return candidate


def _outer_freeze(
    source: Mapping[str, Any],
    source_preflight_artifact: Mapping[str, Any],
    precise_proof_artifact: Mapping[str, Any],
) -> dict[str, Any]:
    return {
        "schema_version": "sporespore_qsdk_r23d76_bounded_native_smoke_v2_freeze_v1",
        "smoke_id": SMOKE_ID,
        "ledger_scope": dict(LEDGER_SCOPE),
        "source_commit": source["source_commit"],
        "origin_main_commit": source["origin_main_commit"],
        "live_github_main_commit": source["live_github_main_commit"],
        "source_tree": source["source_tree"],
        "source_worktree_clean": True,
        "local_remote_live_equal": True,
        "source_artifacts": [
            base._source_artifact(CONTRACT_PATH),
            base._source_artifact(SUPERVISOR_PATH),
            base._source_artifact(TEST_PATH),
            base._source_artifact(V1_CLOSURE_PATH),
        ],
        "source_preflight_artifact": dict(source_preflight_artifact),
        "precise_invalidation_and_requalification_artifact": dict(
            precise_proof_artifact
        ),
        "ordered_engine_ids": list(ENGINE_IDS),
        "development_seed": DEVELOPMENT_SEED,
        "uses_held_out_seed_23197": False,
        "maximum_world_count": MAX_WORLD_COUNT,
        "maximum_solver_step_count_per_engine": MAX_SOLVER_STEPS_PER_ENGINE,
        "physical_execution_authorized": True,
        "authorization_scope": "bounded_native_smoke_v2_only",
        "held_out_finite_campaign_execution_authorized": False,
        "behavior_thresholds_applied": False,
        "physical_acceptance_authority": False,
    }


def run(
    runtime: Any,
    *,
    evidence_root: Path | None = None,
    process_runner: Any = delegate._run_process,
    timeout_seconds: int = 600,
) -> dict[str, Any]:
    evidence_root = _require_evidence_root(evidence_root)
    progress = {"workers": 0, "world_attempts": 0, "world_builds": 0}
    with delegate.LocomotionOperationMutex("physical") as operation_lock:
        source = delegate.verify_exact_source_state()
        source_commit = str(source["source_commit"])
        evidence_root.mkdir(parents=True, exist_ok=True)
        attempt_id = uuid.uuid4().hex
        token = secrets.token_hex(16)
        attempt_root = _attempt_root(evidence_root, attempt_id)
        attempt_root.mkdir(parents=True, exist_ok=False)
        reservation = {
            "schema_version": "sporespore_qsdk_r23d76_bounded_native_smoke_v2_reservation_v1",
            "smoke_id": SMOKE_ID,
            "ledger_scope": dict(LEDGER_SCOPE),
            "source_commit": source_commit,
            "attempt_id": attempt_id,
            "attempt_root": str(attempt_root.resolve()),
            "reserved_utc": _utc_now(),
            "operation_lock": operation_lock,
            "development_seed": DEVELOPMENT_SEED,
            "uses_held_out_seed_23197": False,
            "maximum_world_count": MAX_WORLD_COUNT,
            "maximum_solver_step_count_per_engine": MAX_SOLVER_STEPS_PER_ENGINE,
            "physical_execution_authorized": True,
            "authorization_scope": "bounded_native_smoke_v2_only",
            "held_out_finite_campaign_execution_authorized": False,
            "physical_acceptance_authority": False,
        }
        reservation_artifact = delegate._write_new_json(
            attempt_root / "operation-reservation.json", reservation
        )
        try:
            source_preflight = preflight()
            source_preflight_artifact = delegate._write_new_json(
                attempt_root / "pre-physical/source-preflight.json", source_preflight
            )

            build = process_runner(
                name="rapier_build",
                command=(
                    str(runtime.cargo),
                    "build",
                    "--quiet",
                    "--bin",
                    "turning_three_engine_route",
                ),
                cwd=delegate.RAPIER_ROOT,
                environment=delegate._clean_worker_environment(),
                timeout_seconds=timeout_seconds,
            )
            retained_build = delegate._retain_process(
                attempt_root / "pre-physical/processes", 0, build
            )
            delegate._require_process_success(build, "rapier_build")
            _require(runtime.rapier_binary.is_file(), "RAPIER_BINARY_MISSING")

            current_artifacts = delegate._dependency_artifacts(runtime)
            precise_proof = _precise_invalidation_proof(runtime, current_artifacts)
            specs = delegate._worker_specs(runtime, source_commit)
            rapier_spec = next(spec for spec in specs if spec.engine_id == "rapier_parry")
            focused = process_runner(
                name="rapier_invalidated_binary_preflight",
                command=rapier_spec.preflight_command,
                cwd=rapier_spec.cwd,
                environment=delegate._clean_worker_environment(),
                timeout_seconds=timeout_seconds,
            )
            retained_focused = delegate._retain_process(
                attempt_root / "pre-physical/processes", 1, focused
            )
            delegate._require_process_success(focused, "rapier_invalidated_binary_preflight")
            focused_receipt = delegate._marker_json(
                str(focused["stdout"]), rapier_spec.preflight_marker
            )
            delegate._validate_worker_preflight(rapier_spec, focused_receipt)
            precise_proof.update(
                {
                    "invalidated_artifact_focused_preflight_passed": True,
                    "focused_preflight_receipt": focused_receipt,
                    "focused_preflight_process_record": retained_focused,
                    "rapier_build_process_record": retained_build,
                    "composite_zero_world_qualification_passed": True,
                }
            )
            precise_proof_artifact = delegate._write_new_json(
                attempt_root / "pre-physical/precise-invalidation-proof.json",
                precise_proof,
            )
            _require(
                delegate.verify_exact_source_state() == source,
                "SOURCE_DRIFT_BEFORE_AUTHORIZATION",
            )

            outer_freeze = _outer_freeze(
                source, source_preflight_artifact, precise_proof_artifact
            )
            outer_freeze_artifact = delegate._write_new_json(
                attempt_root / "bounded-smoke-v2-freeze.json", outer_freeze
            )
            outer_attempt = {
                "schema_version": (
                    "sporespore_qsdk_r23d76_bounded_native_smoke_v2_attempt_v1"
                ),
                "smoke_id": SMOKE_ID,
                "ledger_scope": dict(LEDGER_SCOPE),
                "source_commit": source_commit,
                "freeze_sha256": outer_freeze_artifact["sha256"],
                "attempt_id": attempt_id,
                "attempt_root": str(attempt_root.resolve(strict=True)),
                "single_use_append_only_authorization": True,
                "operation_lock_held": True,
                "physical_execution_authorized": True,
                "authorization_scope": "bounded_native_smoke_v2_only",
                "held_out_finite_campaign_execution_authorized": False,
                "physical_acceptance_authority": False,
            }
            outer_attempt_artifact = delegate._write_new_json(
                attempt_root / "bounded-smoke-v2-authorization.json", outer_attempt
            )

            delegate_freeze = delegate._freeze_document(source, precise_proof_artifact)
            delegate_freeze_path = attempt_root / "delegate-physical-freeze.json"
            delegate_freeze_artifact = delegate._write_new_json(
                delegate_freeze_path, delegate_freeze
            )
            delegate_attempt = delegate._attempt_document(
                source_commit=source_commit,
                freeze_raw_sha256=str(delegate_freeze_artifact["sha256"]),
                token=token,
                attempt_id=attempt_id,
                attempt_root=attempt_root,
            )
            delegate_attempt_path = attempt_root / "delegate-attempt-authorization.json"
            delegate_attempt_artifact = delegate._write_new_json(
                delegate_attempt_path, delegate_attempt
            )

            physical_records: list[dict[str, Any]] = []
            projections: list[dict[str, Any]] = []
            terminal_paths: list[str] = []
            for index, spec in enumerate(specs):
                _require(
                    delegate.verify_exact_source_state() == source,
                    f"SOURCE_DRIFT_BEFORE_ENGINE:{spec.engine_id}",
                )
                process_name = f"{spec.engine_id}_bounded_native_smoke_v2"
                process = delegate._invoke_process(
                    process_runner,
                    godot=spec.engine_id == "godot_jolt",
                    name=process_name,
                    command=spec.physical_command,
                    cwd=spec.cwd,
                    environment=delegate._physical_environment(
                        runtime,
                        freeze_path=delegate_freeze_path,
                        attempt_path=delegate_attempt_path,
                        attempt_root=attempt_root,
                        token=token,
                        spec=spec,
                    ),
                    timeout_seconds=timeout_seconds,
                )
                progress["workers"] += 1
                process_root = attempt_root / "physical" / f"{index:02d}__{process_name}"
                physical_records.append(
                    delegate._retain_process(attempt_root / "physical", index, process)
                )
                terminal, projection = base._terminal_projection(
                    spec, process, source_commit
                )
                projection["schema_version"] = (
                    "sporespore_qsdk_r23d76_bounded_native_smoke_v2_cell_v1"
                )
                projection["smoke_id"] = SMOKE_ID
                terminal_path = process_root / "terminal.json"
                delegate._write_new_json(terminal_path, terminal)
                delegate._write_new_json(
                    process_root / "smoke-projection.json", projection
                )
                terminal_paths.append(str(terminal_path.resolve()))
                projections.append(projection)
                if type(projection.get("world_attempt_count")) is int:
                    progress["world_attempts"] += int(projection["world_attempt_count"])
                if type(projection.get("world_build_count")) is int:
                    progress["world_builds"] += int(projection["world_build_count"])

            _require(
                delegate.verify_exact_source_state() == source,
                "SOURCE_DRIFT_AFTER_PHYSICAL",
            )
            manifest_artifact = delegate._write_new_json(
                attempt_root / "terminal-manifest.json",
                {
                    "schema_version": (
                        "sporespore_qsdk_r23d76_bounded_native_smoke_v2_"
                        "terminal_manifest_v1"
                    ),
                    "smoke_id": SMOKE_ID,
                    "source_commit": source_commit,
                    "ordered_engine_ids": list(ENGINE_IDS),
                    "terminal_paths": terminal_paths,
                    "terminal_count": len(terminal_paths),
                    "behavior_outcome_evaluated": False,
                    "physical_acceptance_authority": False,
                },
            )
            passed = bool(
                len(projections) == 3
                and all(item.get("integration_valid") is True for item in projections)
                and progress["world_attempts"] == 3
                and progress["world_builds"] == 3
            )
            exact_steps = [
                item["exact_solver_step_count"]
                for item in projections
                if type(item.get("exact_solver_step_count")) is int
            ]
            result = {
                "schema_version": (
                    "sporespore_qsdk_r23d76_bounded_native_smoke_v2_result_v1"
                ),
                "smoke_id": SMOKE_ID,
                "ledger_scope": dict(LEDGER_SCOPE),
                "question_class": "development",
                "source_commit": source_commit,
                "attempt_id": attempt_id,
                "attempt_root": str(attempt_root.resolve()),
                "bounded_native_smoke_passed": passed,
                "outcome_class": (
                    "bounded_native_smoke_integration_valid"
                    if passed
                    else "bounded_native_smoke_invalid_or_incomplete"
                ),
                "development_seed": DEVELOPMENT_SEED,
                "uses_held_out_seed_23197": False,
                "rapier_build_process_count": 1,
                "focused_invalidated_artifact_preflight_process_count": 1,
                "redundant_native_preflight_process_count": 0,
                "separate_authorization_canary_process_count": 0,
                "aggregate_behavior_evaluator_process_count": 0,
                "full_seeded_ghost_process_count": 0,
                "physical_worker_process_count": progress["workers"],
                "world_attempt_count": progress["world_attempts"],
                "world_build_count": progress["world_builds"],
                "maximum_solver_step_count_per_engine": 2,
                "maximum_total_solver_step_count": 6,
                "exact_observed_solver_step_count": (
                    sum(exact_steps) if len(exact_steps) == 3 else None
                ),
                "worker_success_terminal_count": sum(
                    item.get("worker_outcome_class") == "success_terminal"
                    for item in projections
                ),
                "worker_failure_terminal_count": sum(
                    item.get("worker_outcome_class") == "failure_terminal"
                    for item in projections
                ),
                "behavior_outcome_evaluated": False,
                "cell_projections": projections,
                "reservation_artifact": reservation_artifact,
                "source_preflight_artifact": source_preflight_artifact,
                "precise_invalidation_proof_artifact": precise_proof_artifact,
                "outer_freeze_artifact": outer_freeze_artifact,
                "outer_attempt_artifact": outer_attempt_artifact,
                "delegate_freeze_artifact": delegate_freeze_artifact,
                "delegate_attempt_artifact": delegate_attempt_artifact,
                "terminal_manifest_artifact": manifest_artifact,
                "physical_process_records": physical_records,
                "finite_evidence": False,
                "claims": {
                    "bounded_native_smoke_opened": True,
                    "bounded_native_smoke_passed": passed,
                    "held_out_seed_23197_opened": False,
                    "physical_campaign_opened": False,
                    "finite_three_engine_turning": False,
                    "portable_basic_turning": False,
                    "q_sdk_r23_satisfied": False,
                    "cross_engine_equivalence": False,
                    "arbitrary_quadruped_coverage": False,
                    "population_robustness": False,
                    "prone_to_standing": False,
                    "release_readiness_score_changed": False,
                    "release_authorized": False,
                    "physical_acceptance_authority": False,
                },
                "physical_acceptance_authority": False,
            }
            result_artifact = delegate._write_new_json(
                attempt_root / "supervisor-result.json", result
            )
            completion_artifact = delegate._write_new_json(
                attempt_root / "attempt-completion.json",
                {
                    "schema_version": (
                        "sporespore_qsdk_r23d76_bounded_native_smoke_v2_completion_v1"
                    ),
                    "smoke_id": SMOKE_ID,
                    "attempt_id": attempt_id,
                    "attempt_identity_consumed": True,
                    "same_attempt_rerun_allowed": False,
                    "result_artifact": result_artifact,
                    "bounded_native_smoke_passed": passed,
                    "completed_utc": _utc_now(),
                    "physical_acceptance_authority": False,
                },
            )
            result["result_artifact"] = result_artifact
            result["completion_artifact"] = completion_artifact
            return result
        except Exception as error:
            try:
                delegate._write_new_json(
                    attempt_root / "supervisor-incomplete.json",
                    {
                        "schema_version": (
                            "sporespore_qsdk_r23d76_bounded_native_smoke_v2_"
                            "incomplete_v1"
                        ),
                        "smoke_id": SMOKE_ID,
                        "ledger_scope": dict(LEDGER_SCOPE),
                        "source_commit": source_commit,
                        "attempt_id": attempt_id,
                        "attempt_root": str(attempt_root.resolve()),
                        "failure_code": f"{type(error).__name__}:{error}",
                        "attempt_identity_consumed": True,
                        "bounded_native_smoke_passed": False,
                        "physical_worker_process_count": progress["workers"],
                        "world_attempt_count": progress["world_attempts"],
                        "world_build_count": progress["world_builds"],
                        "uses_held_out_seed_23197": False,
                        "behavior_outcome_evaluated": False,
                        "physical_acceptance_authority": False,
                    },
                )
            except delegate.RouteSupervisorError:
                pass
            raise


def _arguments(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--python-host", default=sys.executable)
    parser.add_argument("--mujoco-python", default=str(delegate.DEFAULT_MUJOCO_PYTHON))
    parser.add_argument("--godot", default=str(delegate.DEFAULT_GODOT))
    parser.add_argument("--powershell", default=shutil.which("pwsh") or "pwsh")
    parser.add_argument("--cargo", default=shutil.which("cargo") or "cargo")
    parser.add_argument("--rapier-binary", default=str(delegate.RAPIER_BINARY_PATH))
    parser.add_argument("--timeout-seconds", type=int, default=600)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("preflight")
    commands.add_parser("run")
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    arguments = _arguments(argv)
    try:
        _require(1 <= arguments.timeout_seconds <= 7200, "TIMEOUT_INVALID")
        if arguments.command == "preflight":
            with delegate.LocomotionOperationMutex("conformance"):
                value = preflight()
            print(
                PREFLIGHT_MARKER
                + json.dumps(value, allow_nan=False, separators=(",", ":"), sort_keys=True)
            )
            return 0
        runtime = delegate.resolve_runtime_paths(arguments)
        value = run(runtime, timeout_seconds=arguments.timeout_seconds)
        print(
            RESULT_MARKER
            + json.dumps(value, allow_nan=False, separators=(",", ":"), sort_keys=True)
        )
        return 0 if value.get("bounded_native_smoke_passed") is True else 1
    except (
        SmokeV2Error,
        base.BoundedSmokeError,
        delegate.RouteSupervisorError,
        v1_audit.ClosureAuditError,
        OSError,
        UnicodeError,
        ValueError,
        json.JSONDecodeError,
    ) as error:
        print(
            ERROR_MARKER
            + json.dumps(
                {
                    "schema_version": (
                        "sporespore_qsdk_r23d76_bounded_native_smoke_v2_error_v1"
                    ),
                    "smoke_id": SMOKE_ID,
                    "failure_code": f"{type(error).__name__}:{error}",
                    "held_out_seed_23197_opened": False,
                    "physical_counts_available_only_in_retained_attempt": True,
                    "physical_acceptance_authority": False,
                },
                sort_keys=True,
                separators=(",", ":"),
            ),
            file=sys.stderr,
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
