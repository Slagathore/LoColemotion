"""Repaired, precisely invalidated R23D76 bounded native smoke successor."""

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


ROOT = Path(__file__).resolve().parents[2]
TURNING_ROOT = ROOT / "sdk/turning"
CONTRACT_PATH = TURNING_ROOT / "r23d76_bounded_native_smoke_v3.json"
SUPERVISOR_PATH = Path(__file__).resolve()
TEST_PATH = ROOT / "tests/test_qsdk_r23d76_bounded_native_smoke_v3.py"
V2_PATH = TURNING_ROOT / "r23d76_bounded_native_smoke_v2.py"
V2_CLOSURE_PATH = TURNING_ROOT / "r23d76_bounded_native_smoke_v2_attempt1_closure.json"
V2_AUDIT_PATH = ROOT / "sdk/audit_r23d76_bounded_native_smoke_v2_attempt1.py"
REPAIR_PATH = TURNING_ROOT / "three_engine_turning_mujoco_preflight_bridge_repair_v1.json"
MUJOCO_WORKER_PATH = (
    ROOT
    / "sdk/adapters/mujoco/sporespore_mujoco_adapter/turning_three_engine_route.py"
)
MUJOCO_TEST_MODULE = (
    "sporespore_mujoco_adapter.turning_three_engine_route_test."
    "TurningThreeEngineRouteTests."
    "test_inherited_preflight_bridge_accepts_measurement_origin_extension"
)
DEFAULT_EVIDENCE_ROOT = ROOT.parent / "SporeSpore_Evidence"


def _module(name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"R23D76_SMOKE_V3_IMPORT_INVALID:{path}")
    value = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = value
    spec.loader.exec_module(value)
    return value


v2 = _module("_r23d76_smoke_v2_base", V2_PATH)
v2_audit = _module("_r23d76_smoke_v2_attempt1_audit", V2_AUDIT_PATH)
base = v2.base
delegate = v2.delegate

SMOKE_ID = "QSDK-R23D76-BOUNDED-NATIVE-SMOKE-V3"
SCHEMA = "sporespore_qsdk_r23d76_bounded_native_smoke_v3"
LEDGER_SCOPE = {
    "subsystem": "turning",
    "engine_scope": "3e",
    "authority_mode": "bounded_native_smoke_repaired_successor",
    "question_class": "development",
}
ENGINE_IDS = v2.ENGINE_IDS
DEVELOPMENT_SEED = v2.DEVELOPMENT_SEED
HELD_OUT_SEED = v2.HELD_OUT_SEED
MAX_STEPS = v2.MAX_SOLVER_STEPS_PER_ENGINE
PREFLIGHT_MARKER = "QSDK_R23D76_BOUNDED_NATIVE_SMOKE_V3_PREFLIGHT "
RESULT_MARKER = "QSDK_R23D76_BOUNDED_NATIVE_SMOKE_V3_RESULT "
ERROR_MARKER = "QSDK_R23D76_BOUNDED_NATIVE_SMOKE_V3_ERROR "


class SmokeV3Error(RuntimeError):
    pass


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise SmokeV3Error(f"R23D76_BOUNDED_SMOKE_V3_{code}")


def _load(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise SmokeV3Error(f"R23D76_BOUNDED_SMOKE_V3_JSON_UNREADABLE:{path}") from error
    _require(isinstance(value, dict), "JSON_NOT_OBJECT")
    return value


def _sha(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return "sha256:" + digest.hexdigest()


def _utc() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


CONTRACT = _load(CONTRACT_PATH)


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
    _require(
        isinstance(predecessor, Mapping)
        and predecessor.get("closure_raw_sha256") == _sha(V2_CLOSURE_PATH)
        and predecessor.get("required_status")
        == "closed_consumed_integration_invalid_complete_three_worker_population_"
        "mujoco_preflight_bridge_signature_drift"
        and predecessor.get("observed_success_terminal_count") == 2
        and predecessor.get("observed_failure_terminal_count") == 1
        and predecessor.get("observed_world_build_count") == 2
        and predecessor.get("held_out_seed_23197_opened") is False
        and predecessor.get("historical_result_reinterpreted") is False,
        "PREDECESSOR_INVALID",
    )
    repair = value.get("declared_repair")
    _require(
        isinstance(repair, Mapping)
        and repair.get("repair_raw_sha256") == _sha(REPAIR_PATH)
        and repair.get("repair_source_commit")
        == "17fe4080b448bac94f2f06d8154b25439c74b7a0"
        and repair.get("repair_id")
        == "SPORESPORE-TURNING-MUJOCO-PREFLIGHT-BRIDGE-REPAIR-V1"
        and repair.get("zero_world_regression_passed") is True
        and repair.get("threshold_seed_selector_evaluator_horizon_or_terminal_changed")
        is False
        and repair.get("physical_successor_opened") is False,
        "REPAIR_INVALID",
    )
    parent = value.get("parent_finite_decision")
    _require(
        isinstance(parent, Mapping)
        and parent.get("campaign_id")
        == "QSDK-R23D76-FRESH-FINITE-THREE-ENGINE-TURNING-DECISION"
        and parent.get("gate_id") == "QSDK-R23D76"
        and parent.get("held_out_seed") == HELD_OUT_SEED
        and parent.get("all_222_implementation_dependency_digests_must_remain_exact")
        is True
        and parent.get("physical_campaign_execution_authorized") is False,
        "PARENT_INVALID",
    )
    invalidation = value.get("precise_invalidation")
    _require(
        isinstance(invalidation, Mapping)
        and invalidation.get("historical_complete_cold_gate_artifact_count") == 15
        and invalidation.get("required_exact_reuse_artifact_count") == 13
        and invalidation.get("permitted_invalidated_artifact_count") == 2
        and invalidation.get("permitted_invalidated_artifact_paths")
        == [
            "sdk/target/debug/turning_three_engine_route.exe",
            "sdk/adapters/mujoco/sporespore_mujoco_adapter/turning_three_engine_route.py",
        ]
        and invalidation.get("focused_zero_world_preflight_engine_ids")
        == ["rapier_parry", "mujoco"]
        and invalidation.get("focused_zero_world_preflight_process_count") == 2
        and invalidation.get("any_other_dependency_toolchain_or_environment_drift_fails_closed")
        is True
        and invalidation.get("full_historical_canary_suite_repeated") is False,
        "INVALIDATION_INVALID",
    )
    population = value.get("bounded_population")
    _require(
        isinstance(population, Mapping)
        and population.get("ordered_engine_ids") == list(ENGINE_IDS)
        and population.get("complete_engine_population_count") == 3
        and population.get("development_seed") == DEVELOPMENT_SEED
        and population.get("development_seed_is_outcome_exposed") is True
        and population.get("uses_held_out_seed_23197") is False
        and population.get("maximum_world_count") == 3
        and population.get("maximum_world_count_per_engine") == 1
        and population.get("maximum_solver_step_count_per_engine") == 2
        and population.get("maximum_total_solver_step_count") == 6
        and population.get("sampling_used") is False,
        "POPULATION_INVALID",
    )
    protocol = value.get("execution_protocol")
    expected_counts = {
        "rapier_build_process_count": 1,
        "focused_invalidated_artifact_preflight_process_count": 2,
        "redundant_native_preflight_process_count": 0,
        "separate_authorization_canary_process_count": 0,
        "aggregate_behavior_evaluator_process_count": 0,
        "full_seeded_ghost_process_count": 0,
        "physical_worker_process_count": 3,
    }
    _require(
        isinstance(protocol, Mapping)
        and all(protocol.get(name) == count for name, count in expected_counts.items())
        and protocol.get("clean_pushed_live_equal_source_required") is True
        and protocol.get("machine_wide_physical_mutex_required") is True
        and protocol.get("serial_engine_order_required") is True
        and protocol.get("append_only_attempt_required") is True
        and protocol.get("continue_after_valid_physics_failure") is True
        and protocol.get("world_construction_required_per_engine") is True
        and protocol.get("bounded_native_smoke_execution_authorized_after_clean_push")
        is True
        and protocol.get("held_out_finite_campaign_execution_authorized") is False,
        "PROTOCOL_INVALID",
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
    _require(
        all(item is False for item in value.get("interpretation", {}).values()),
        "INTERPRETATION_INVALID",
    )
    _require(
        len(value.get("claims", {})) == 14
        and all(item is False for item in value["claims"].values()),
        "CLAIMS_INVALID",
    )


def _repair_authority() -> dict[str, Any]:
    repair = _load(REPAIR_PATH)
    source = repair["repair"]
    regression = repair["zero_world_regression"]
    _require(_sha(ROOT / source["source_path"]) == source["new_raw_sha256"], "REPAIR_SOURCE_DRIFT")
    _require(
        _sha(ROOT / regression["test_path"]) == regression["new_raw_sha256"],
        "REPAIR_TEST_DRIFT",
    )
    _require(
        regression.get("passed") is True
        and regression.get("model_construction_count") == 0
        and regression.get("world_attempt_count") == 0
        and regression.get("world_build_count") == 0
        and regression.get("solver_step_count") == 0,
        "REPAIR_REGRESSION_INVALID",
    )
    return {
        "repair_artifact": base._source_artifact(REPAIR_PATH),
        "repair_source_artifact": base._source_artifact(ROOT / source["source_path"]),
        "repair_test_artifact": base._source_artifact(ROOT / regression["test_path"]),
        "zero_world_regression_passed": True,
    }


def preflight() -> dict[str, Any]:
    validate_contract(CONTRACT)
    predecessor = v2_audit.audit()
    _require(predecessor.get("passed") is True, "PREDECESSOR_AUDIT_FAILED")
    parent = base._validate_parent_authorities()
    repair = _repair_authority()
    return {
        "schema_version": "sporespore_qsdk_r23d76_bounded_native_smoke_v3_preflight_v1",
        "smoke_id": SMOKE_ID,
        "ledger_scope": dict(LEDGER_SCOPE),
        "contract_artifact": base._source_artifact(CONTRACT_PATH),
        "supervisor_artifact": base._source_artifact(SUPERVISOR_PATH),
        "predecessor_closure_artifact": base._source_artifact(V2_CLOSURE_PATH),
        "predecessor_audit_receipt": predecessor,
        "repair_authority": repair,
        "r23d76_dependency_count": parent["r23d76_dependency_count"],
        "precise_runtime_invalidation_check_pending": True,
        "focused_invalidated_artifact_preflight_process_count": 0,
        "physical_worker_process_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
    }


def _precise_proof(runtime: Any, current: Sequence[Mapping[str, Any]]) -> dict[str, Any]:
    route_closure = base._load_json(base.DELEGATE_CLOSURE_PATH, "DELEGATE_CLOSURE")
    zero_path = (
        Path(route_closure["passing_attempt"]["attempt_root"]).resolve(strict=True)
        / "zero-world/complete-gate.json"
    )
    zero = base._load_json(zero_path, "COLD_ZERO_WORLD")
    selected = route_closure["passing_evidence_population"]["selected_artifacts"]
    selected_zero = [
        item for item in selected if item.get("relative_path") == "zero-world/complete-gate.json"
    ]
    _require(
        len(selected_zero) == 1
        and selected_zero[0]["raw_sha256"] == base._raw_sha256(zero_path)
        and selected_zero[0]["byte_length"] == zero_path.stat().st_size,
        "COLD_EVIDENCE_DRIFT",
    )
    historical = zero["dependency_artifacts"]
    historical_map = base._artifact_map(historical, "V3_HISTORICAL")
    current_map = base._artifact_map(current, "V3_CURRENT")
    _require(set(current_map) == set(historical_map), "DEPENDENCY_POPULATION_DRIFT")
    differences = {key for key in historical_map if historical_map[key] != current_map[key]}
    expected = {
        base._canonical_artifact_key(runtime.rapier_binary),
        base._canonical_artifact_key(MUJOCO_WORKER_PATH),
    }
    _require(differences == expected, "PRECISE_INVALIDATION_SET_INVALID")
    _require(zero.get("environment") == base._environment_receipt(), "ENVIRONMENT_DRIFT")
    historical_by_key = {
        base._canonical_artifact_key(item["path"]): dict(item) for item in historical
    }
    current_by_key = {
        base._canonical_artifact_key(item["path"]): dict(item) for item in current
    }
    return {
        "schema_version": "sporespore_qsdk_r23d76_precise_invalidation_proof_v3",
        "smoke_id": SMOKE_ID,
        "historical_cold_gate_artifact": {
            "path": str(zero_path),
            "sha256": base._raw_sha256(zero_path),
            "byte_length": zero_path.stat().st_size,
        },
        "historical_dependency_artifact_count": 15,
        "exact_reuse_artifact_count": 13,
        "invalidated_artifact_count": 2,
        "invalidated_artifacts": [
            {
                "historical": historical_by_key[key],
                "current": current_by_key[key],
                "focused_zero_world_requalification_required": True,
            }
            for key in sorted(expected)
        ],
        "all_other_dependency_toolchain_environment_keys_exact": True,
        "environment": base._environment_receipt(),
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
    }


def _attempt_root(root: Path, attempt_id: str) -> Path:
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    return root / "turning/r23d76-bounded-native-smoke-v3" / f"{stamp}__{attempt_id}"


def _evidence_root(value: Path | None) -> Path:
    expected = DEFAULT_EVIDENCE_ROOT.resolve()
    candidate = expected if value is None else value.resolve()
    _require(candidate == expected, f"EVIDENCE_ROOT_INVALID:{candidate}")
    return candidate


def _focus_receipts(
    runtime: Any,
    specs: Sequence[Any],
    process_runner: Any,
    process_root: Path,
    timeout_seconds: int,
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    rapier = next(spec for spec in specs if spec.engine_id == "rapier_parry")
    rapier_process = process_runner(
        name="rapier_invalidated_binary_preflight",
        command=rapier.preflight_command,
        cwd=rapier.cwd,
        environment=delegate._clean_worker_environment(),
        timeout_seconds=timeout_seconds,
    )
    retained = [delegate._retain_process(process_root, 1, rapier_process)]
    delegate._require_process_success(rapier_process, "rapier_invalidated_binary_preflight")
    rapier_receipt = delegate._marker_json(
        str(rapier_process["stdout"]), rapier.preflight_marker
    )
    delegate._validate_worker_preflight(rapier, rapier_receipt)

    mujoco_process = process_runner(
        name="mujoco_repaired_bridge_preflight",
        command=(str(runtime.mujoco_python), "-m", "unittest", MUJOCO_TEST_MODULE, "-v"),
        cwd=delegate.MUJOCO_ROOT,
        environment=delegate._clean_worker_environment(),
        timeout_seconds=timeout_seconds,
    )
    retained.append(delegate._retain_process(process_root, 2, mujoco_process))
    delegate._require_process_success(mujoco_process, "mujoco_repaired_bridge_preflight")
    combined = str(mujoco_process["stdout"]) + str(mujoco_process["stderr"])
    _require(
        "Ran 1 test" in combined
        and "OK" in combined
        and "test_inherited_preflight_bridge_accepts_measurement_origin_extension" in combined,
        "MUJOCO_FOCUSED_PREFLIGHT_INVALID",
    )
    mujoco_receipt = {
        "schema_version": "sporespore_qsdk_r23d76_mujoco_repaired_bridge_preflight_v1",
        "smoke_id": SMOKE_ID,
        "engine_id": "mujoco",
        "repair_id": "SPORESPORE-TURNING-MUJOCO-PREFLIGHT-BRIDGE-REPAIR-V1",
        "test_count": 1,
        "measurement_origin_keyword_exercised": True,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
    }
    return [rapier_receipt, mujoco_receipt], retained


def run(
    runtime: Any,
    *,
    evidence_root: Path | None = None,
    process_runner: Any = delegate._run_process,
    timeout_seconds: int = 600,
) -> dict[str, Any]:
    evidence_root = _evidence_root(evidence_root)
    progress = {"workers": 0, "world_attempts": 0, "world_builds": 0}
    with delegate.LocomotionOperationMutex("physical") as lock:
        source = delegate.verify_exact_source_state()
        source_commit = str(source["source_commit"])
        evidence_root.mkdir(parents=True, exist_ok=True)
        attempt_id = uuid.uuid4().hex
        token = secrets.token_hex(16)
        attempt_root = _attempt_root(evidence_root, attempt_id)
        attempt_root.mkdir(parents=True, exist_ok=False)
        reservation_artifact = delegate._write_new_json(
            attempt_root / "operation-reservation.json",
            {
                "schema_version": "sporespore_qsdk_r23d76_bounded_native_smoke_v3_reservation_v1",
                "smoke_id": SMOKE_ID,
                "ledger_scope": dict(LEDGER_SCOPE),
                "source_commit": source_commit,
                "attempt_id": attempt_id,
                "attempt_root": str(attempt_root.resolve()),
                "reserved_utc": _utc(),
                "operation_lock": lock,
                "development_seed": DEVELOPMENT_SEED,
                "uses_held_out_seed_23197": False,
                "maximum_world_count": 3,
                "maximum_solver_step_count_per_engine": 2,
                "physical_execution_authorized": True,
                "authorization_scope": "bounded_native_smoke_v3_only",
                "held_out_finite_campaign_execution_authorized": False,
                "physical_acceptance_authority": False,
            },
        )
        try:
            source_preflight_artifact = delegate._write_new_json(
                attempt_root / "pre-physical/source-preflight.json", preflight()
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
            process_root = attempt_root / "pre-physical/processes"
            retained_build = delegate._retain_process(process_root, 0, build)
            delegate._require_process_success(build, "rapier_build")
            _require(runtime.rapier_binary.is_file(), "RAPIER_BINARY_MISSING")

            current = delegate._dependency_artifacts(runtime)
            proof = _precise_proof(runtime, current)
            specs = delegate._worker_specs(runtime, source_commit)
            focus_receipts, focus_processes = _focus_receipts(
                runtime, specs, process_runner, process_root, timeout_seconds
            )
            proof.update(
                {
                    "focused_preflight_receipts": focus_receipts,
                    "focused_preflight_process_records": focus_processes,
                    "rapier_build_process_record": retained_build,
                    "focused_zero_world_preflight_process_count": 2,
                    "composite_zero_world_qualification_passed": True,
                }
            )
            proof_artifact = delegate._write_new_json(
                attempt_root / "pre-physical/precise-invalidation-proof.json", proof
            )
            _require(
                delegate.verify_exact_source_state() == source,
                "SOURCE_DRIFT_BEFORE_AUTHORIZATION",
            )

            outer_freeze = {
                "schema_version": "sporespore_qsdk_r23d76_bounded_native_smoke_v3_freeze_v1",
                "smoke_id": SMOKE_ID,
                "ledger_scope": dict(LEDGER_SCOPE),
                "source_commit": source_commit,
                "origin_main_commit": source["origin_main_commit"],
                "live_github_main_commit": source["live_github_main_commit"],
                "source_tree": source["source_tree"],
                "source_worktree_clean": True,
                "local_remote_live_equal": True,
                "source_artifacts": [
                    base._source_artifact(CONTRACT_PATH),
                    base._source_artifact(SUPERVISOR_PATH),
                    base._source_artifact(TEST_PATH),
                    base._source_artifact(V2_CLOSURE_PATH),
                    base._source_artifact(REPAIR_PATH),
                ],
                "source_preflight_artifact": source_preflight_artifact,
                "precise_invalidation_artifact": proof_artifact,
                "ordered_engine_ids": list(ENGINE_IDS),
                "development_seed": DEVELOPMENT_SEED,
                "uses_held_out_seed_23197": False,
                "maximum_world_count": 3,
                "maximum_solver_step_count_per_engine": 2,
                "physical_execution_authorized": True,
                "authorization_scope": "bounded_native_smoke_v3_only",
                "held_out_finite_campaign_execution_authorized": False,
                "behavior_thresholds_applied": False,
                "physical_acceptance_authority": False,
            }
            outer_freeze_artifact = delegate._write_new_json(
                attempt_root / "bounded-smoke-v3-freeze.json", outer_freeze
            )
            outer_attempt_artifact = delegate._write_new_json(
                attempt_root / "bounded-smoke-v3-authorization.json",
                {
                    "schema_version": "sporespore_qsdk_r23d76_bounded_native_smoke_v3_attempt_v1",
                    "smoke_id": SMOKE_ID,
                    "ledger_scope": dict(LEDGER_SCOPE),
                    "source_commit": source_commit,
                    "freeze_sha256": outer_freeze_artifact["sha256"],
                    "attempt_id": attempt_id,
                    "attempt_root": str(attempt_root.resolve(strict=True)),
                    "single_use_append_only_authorization": True,
                    "operation_lock_held": True,
                    "physical_execution_authorized": True,
                    "authorization_scope": "bounded_native_smoke_v3_only",
                    "held_out_finite_campaign_execution_authorized": False,
                    "physical_acceptance_authority": False,
                },
            )
            delegate_freeze = delegate._freeze_document(source, proof_artifact)
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

            projections: list[dict[str, Any]] = []
            terminals: list[str] = []
            physical_processes: list[dict[str, Any]] = []
            for index, spec in enumerate(specs):
                _require(
                    delegate.verify_exact_source_state() == source,
                    f"SOURCE_DRIFT_BEFORE_ENGINE:{spec.engine_id}",
                )
                name = f"{spec.engine_id}_bounded_native_smoke_v3"
                process = delegate._invoke_process(
                    process_runner,
                    godot=spec.engine_id == "godot_jolt",
                    name=name,
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
                cell_root = attempt_root / "physical" / f"{index:02d}__{name}"
                physical_processes.append(
                    delegate._retain_process(attempt_root / "physical", index, process)
                )
                terminal, projection = base._terminal_projection(spec, process, source_commit)
                projection["schema_version"] = (
                    "sporespore_qsdk_r23d76_bounded_native_smoke_v3_cell_v1"
                )
                projection["smoke_id"] = SMOKE_ID
                terminal_path = cell_root / "terminal.json"
                delegate._write_new_json(terminal_path, terminal)
                delegate._write_new_json(cell_root / "smoke-projection.json", projection)
                terminals.append(str(terminal_path.resolve()))
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
                    "schema_version": "sporespore_qsdk_r23d76_bounded_native_smoke_v3_terminal_manifest_v1",
                    "smoke_id": SMOKE_ID,
                    "source_commit": source_commit,
                    "ordered_engine_ids": list(ENGINE_IDS),
                    "terminal_paths": terminals,
                    "terminal_count": len(terminals),
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
            observed_steps = [
                item["exact_solver_step_count"]
                for item in projections
                if type(item.get("exact_solver_step_count")) is int
            ]
            result = {
                "schema_version": "sporespore_qsdk_r23d76_bounded_native_smoke_v3_result_v1",
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
                "focused_invalidated_artifact_preflight_process_count": 2,
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
                    sum(observed_steps) if len(observed_steps) == 3 else None
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
                "precise_invalidation_proof_artifact": proof_artifact,
                "outer_freeze_artifact": outer_freeze_artifact,
                "outer_attempt_artifact": outer_attempt_artifact,
                "delegate_freeze_artifact": delegate_freeze_artifact,
                "delegate_attempt_artifact": delegate_attempt_artifact,
                "terminal_manifest_artifact": manifest_artifact,
                "physical_process_records": physical_processes,
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
                    "schema_version": "sporespore_qsdk_r23d76_bounded_native_smoke_v3_completion_v1",
                    "smoke_id": SMOKE_ID,
                    "attempt_id": attempt_id,
                    "attempt_identity_consumed": True,
                    "same_attempt_rerun_allowed": False,
                    "result_artifact": result_artifact,
                    "bounded_native_smoke_passed": passed,
                    "completed_utc": _utc(),
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
                        "schema_version": "sporespore_qsdk_r23d76_bounded_native_smoke_v3_incomplete_v1",
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
    args = _arguments(argv)
    try:
        _require(1 <= args.timeout_seconds <= 7200, "TIMEOUT_INVALID")
        if args.command == "preflight":
            with delegate.LocomotionOperationMutex("conformance"):
                value = preflight()
            print(PREFLIGHT_MARKER + json.dumps(value, sort_keys=True, separators=(",", ":")))
            return 0
        runtime = delegate.resolve_runtime_paths(args)
        value = run(runtime, timeout_seconds=args.timeout_seconds)
        print(RESULT_MARKER + json.dumps(value, sort_keys=True, separators=(",", ":")))
        return 0 if value.get("bounded_native_smoke_passed") is True else 1
    except (
        SmokeV3Error,
        v2.SmokeV2Error,
        base.BoundedSmokeError,
        delegate.RouteSupervisorError,
        v2_audit.AuditError,
        OSError,
        UnicodeError,
        ValueError,
        json.JSONDecodeError,
    ) as error:
        print(
            ERROR_MARKER
            + json.dumps(
                {
                    "schema_version": "sporespore_qsdk_r23d76_bounded_native_smoke_v3_error_v1",
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
