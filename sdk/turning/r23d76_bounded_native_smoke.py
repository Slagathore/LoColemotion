"""Minimal post-zero-world native construction smoke for QSDK-R23D76.

This development-only route intentionally does less than the historical
success-transport campaign supervisor.  R23D76 already passed its complete
compact zero-world gate.  Before any held-out world may open, this supervisor
proves only that the current three native producers can still construct their
real worlds, advance through the delegate's fixed two-step upper bound, and
emit a production-shaped terminal on an already-exposed seed.

No behavior threshold or aggregate evaluator runs here.  A well-formed
physics failure remains a useful smoke result; an integration-invalid terminal,
missing world construction, source drift, or dependency drift fails closed.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.metadata
import importlib.util
import json
import os
import platform
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
CONTRACT_PATH = TURNING_ROOT / "r23d76_bounded_native_smoke_v1.json"
SUPERVISOR_PATH = Path(__file__).resolve()
TEST_PATH = REPO_ROOT / "tests/test_qsdk_r23d76_bounded_native_smoke.py"
DECLARATION_PATH = (
    TURNING_ROOT / "r23d76_fresh_finite_three_engine_turning_decision_v1.json"
)
IMPLEMENTATION_PATH = (
    TURNING_ROOT
    / "r23d76_production_route_three_engine_turning_implementation_v1.json"
)
R23D76_ZERO_WORLD_AUDIT_PATH = REPO_ROOT / "tests/test_qsdk_r23d76_zero_world.ps1"
DELEGATE_SUPERVISOR_PATH = TURNING_ROOT / "three_engine_turning_route_supervisor.py"
DELEGATE_CONTRACT_PATH = (
    TURNING_ROOT / "three_engine_turning_success_transport_route_v2.json"
)
DELEGATE_CLOSURE_PATH = (
    TURNING_ROOT / "three_engine_turning_success_transport_route_v2_closure.json"
)
DEFAULT_EVIDENCE_ROOT = REPO_ROOT.parent / "SporeSpore_Evidence"


def _load_delegate() -> Any:
    specification = importlib.util.spec_from_file_location(
        "_r23d76_bounded_smoke_delegate", DELEGATE_SUPERVISOR_PATH
    )
    if specification is None or specification.loader is None:
        raise RuntimeError("R23D76_BOUNDED_SMOKE_DELEGATE_IMPORT_INVALID")
    module = importlib.util.module_from_spec(specification)
    sys.modules[specification.name] = module
    specification.loader.exec_module(module)
    return module


delegate = _load_delegate()


class BoundedSmokeError(RuntimeError):
    """The bounded smoke declaration, authorization, or evidence was invalid."""


def _load_json(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise BoundedSmokeError(
            f"R23D76_BOUNDED_SMOKE_{label}_UNREADABLE:{type(error).__name__}"
        ) from error
    if not isinstance(value, dict):
        raise BoundedSmokeError(f"R23D76_BOUNDED_SMOKE_{label}_NOT_OBJECT")
    return value


CONTRACT = _load_json(CONTRACT_PATH, "CONTRACT")
SMOKE_ID = "QSDK-R23D76-BOUNDED-NATIVE-SMOKE-V1"
SMOKE_SCHEMA = "sporespore_qsdk_r23d76_bounded_native_smoke_v1"
OUTER_FREEZE_SCHEMA = "sporespore_qsdk_r23d76_bounded_native_smoke_freeze_v1"
OUTER_ATTEMPT_SCHEMA = "sporespore_qsdk_r23d76_bounded_native_smoke_attempt_v1"
RESULT_SCHEMA = "sporespore_qsdk_r23d76_bounded_native_smoke_result_v1"
LEDGER_SCOPE = {
    "subsystem": "turning",
    "engine_scope": "3e",
    "authority_mode": "bounded_native_smoke",
    "question_class": "development",
}
ENGINE_IDS = ("godot_jolt", "rapier_parry", "mujoco")
DEVELOPMENT_SEED = 21516
HELD_OUT_SEED = 23197
MAX_WORLD_COUNT = 3
MAX_SOLVER_STEPS_PER_ENGINE = 2

PREFLIGHT_MARKER = "QSDK_R23D76_BOUNDED_NATIVE_SMOKE_PREFLIGHT "
RESULT_MARKER = "QSDK_R23D76_BOUNDED_NATIVE_SMOKE_RESULT "
ERROR_MARKER = "QSDK_R23D76_BOUNDED_NATIVE_SMOKE_ERROR "


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise BoundedSmokeError(f"R23D76_BOUNDED_SMOKE_{code}")


def _raw_sha256(path: Path) -> str:
    try:
        digest = hashlib.sha256()
        with path.open("rb") as stream:
            for block in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(block)
        return "sha256:" + digest.hexdigest()
    except OSError as error:
        raise BoundedSmokeError(
            f"R23D76_BOUNDED_SMOKE_ARTIFACT_UNREADABLE:{path}:{type(error).__name__}"
        ) from error


def _source_artifact(path: Path) -> dict[str, Any]:
    try:
        resolved = path.resolve(strict=True)
        relative = resolved.relative_to(REPO_ROOT.resolve(strict=True)).as_posix()
    except (OSError, ValueError) as error:
        raise BoundedSmokeError(
            f"R23D76_BOUNDED_SMOKE_SOURCE_PATH_INVALID:{path}"
        ) from error
    _require(resolved.is_file(), f"SOURCE_FILE_MISSING:{relative}")
    return {
        "path": relative,
        "sha256": _raw_sha256(resolved),
        "byte_length": resolved.stat().st_size,
    }


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def _canonical_json_sha256(value: Any) -> str:
    raw = json.dumps(
        value,
        allow_nan=False,
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")
    return "sha256:" + hashlib.sha256(raw).hexdigest()


def validate_contract(value: Mapping[str, Any]) -> None:
    """Validate the complete prospective smoke declaration without physics."""

    _require(value.get("schema_version") == SMOKE_SCHEMA, "SCHEMA_INVALID")
    _require(value.get("smoke_id") == SMOKE_ID, "ID_INVALID")
    _require(
        value.get("status") == "prospective_source_only_physical_not_opened",
        "STATUS_INVALID",
    )
    _require(value.get("ledger_scope") == LEDGER_SCOPE, "LEDGER_SCOPE_INVALID")

    parent = value.get("parent_finite_decision")
    _require(isinstance(parent, Mapping), "PARENT_NOT_OBJECT")
    _require(
        parent.get("campaign_id")
        == "QSDK-R23D76-FRESH-FINITE-THREE-ENGINE-TURNING-DECISION",
        "PARENT_CAMPAIGN_INVALID",
    )
    _require(parent.get("gate_id") == "QSDK-R23D76", "PARENT_GATE_INVALID")
    _require(parent.get("held_out_seed") == HELD_OUT_SEED, "HELD_OUT_SEED_INVALID")
    _require(
        parent.get("declaration_path")
        == "sdk/turning/r23d76_fresh_finite_three_engine_turning_decision_v1.json",
        "DECLARATION_PATH_INVALID",
    )
    _require(
        parent.get("implementation_path")
        == "sdk/turning/r23d76_production_route_three_engine_turning_implementation_v1.json",
        "IMPLEMENTATION_PATH_INVALID",
    )
    _require(
        parent.get("complete_zero_world_audit_path")
        == "tests/test_qsdk_r23d76_zero_world.ps1",
        "ZERO_WORLD_AUDIT_PATH_INVALID",
    )
    _require(
        parent.get("required_implementation_status")
        == "implementation_complete_complete_zero_world_gate_passed_"
        "bounded_native_smoke_pending_physical_not_authorized",
        "IMPLEMENTATION_STATUS_INVALID",
    )
    _require(
        parent.get("complete_zero_world_gate_must_remain_passed") is True,
        "ZERO_WORLD_REUSE_NOT_REQUIRED",
    )
    _require(
        parent.get("all_implementation_dependency_digests_must_remain_exact") is True,
        "DEPENDENCY_EXACTNESS_NOT_REQUIRED",
    )
    _require(
        parent.get("physical_campaign_execution_authorized") is False,
        "CAMPAIGN_EXECUTION_AUTHORIZED",
    )

    population = value.get("bounded_population")
    _require(isinstance(population, Mapping), "POPULATION_NOT_OBJECT")
    _require(
        population.get("ordered_engine_ids") == list(ENGINE_IDS),
        "ENGINE_POPULATION_INVALID",
    )
    _require(
        population.get("complete_engine_population_count") == len(ENGINE_IDS),
        "ENGINE_COUNT_INVALID",
    )
    _require(
        population.get("development_seed") == DEVELOPMENT_SEED,
        "DEVELOPMENT_SEED_INVALID",
    )
    _require(
        population.get("development_seed_is_outcome_exposed") is True,
        "DEVELOPMENT_SEED_PROVENANCE_INVALID",
    )
    _require(
        population.get("uses_held_out_seed_23197") is False,
        "HELD_OUT_SEED_USE_INVALID",
    )
    _require(population.get("arm_id") == "positive_heading", "ARM_INVALID")
    _require(population.get("turn_heading_offset_rad") == 0.2, "HEADING_INVALID")
    _require(
        population.get("maximum_world_count") == MAX_WORLD_COUNT,
        "WORLD_BOUND_INVALID",
    )
    _require(
        population.get("maximum_world_count_per_engine") == 1,
        "ENGINE_WORLD_BOUND_INVALID",
    )
    _require(
        population.get("maximum_solver_step_count_per_engine")
        == MAX_SOLVER_STEPS_PER_ENGINE,
        "STEP_BOUND_INVALID",
    )
    _require(
        population.get("maximum_total_solver_step_count")
        == MAX_WORLD_COUNT * MAX_SOLVER_STEPS_PER_ENGINE,
        "TOTAL_STEP_BOUND_INVALID",
    )
    _require(population.get("sampling_used") is False, "SAMPLING_INVALID")

    native_delegate = value.get("native_delegate")
    _require(isinstance(native_delegate, Mapping), "DELEGATE_NOT_OBJECT")
    _require(
        native_delegate.get("route_id") == delegate.ROUTE_ID,
        "DELEGATE_ROUTE_INVALID",
    )
    _require(
        native_delegate.get("route_contract_path")
        == "sdk/turning/three_engine_turning_success_transport_route_v2.json",
        "DELEGATE_CONTRACT_PATH_INVALID",
    )
    _require(
        native_delegate.get("route_supervisor_path")
        == "sdk/turning/three_engine_turning_route_supervisor.py",
        "DELEGATE_SUPERVISOR_PATH_INVALID",
    )
    _require(
        native_delegate.get("historical_closure_path")
        == "sdk/turning/three_engine_turning_success_transport_route_v2_closure.json",
        "DELEGATE_CLOSURE_PATH_INVALID",
    )
    for field in (
        "historical_route_remains_closed",
        "repeat_transport_smoke_required_by_historical_closure",
    ):
        expected = field == "historical_route_remains_closed"
        _require(native_delegate.get(field) is expected, f"DELEGATE_{field.upper()}_INVALID")
    for field in (
        "historical_result_reinterpreted",
        "historical_threshold_selector_evaluator_or_result_changed",
    ):
        _require(native_delegate.get(field) is False, f"DELEGATE_{field.upper()}")
    expected_paths = [
        "sdk/turning/three_engine_turning_success_transport_route_v2.json",
        "sdk/turning/three_engine_turning_route_supervisor.py",
        "sdk/turning/three_engine_turning_route_evaluator.py",
        "sdk/turning/three_engine_turning_success_transport_route_v2_closure.json",
        "tests/test_sdk_turning_three_engine_route_godot_jolt_worker.gd",
        "sdk/adapters/rapier/src/turning_three_engine_route.rs",
        "sdk/adapters/rapier/src/bin/turning_three_engine_route.rs",
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/turning_three_engine_route.py",
        "sdk/locomotion_operation_lock.ps1",
    ]
    _require(
        native_delegate.get("required_source_paths") == expected_paths,
        "DELEGATE_SOURCE_POPULATION_INVALID",
    )

    protocol = value.get("execution_protocol")
    _require(isinstance(protocol, Mapping), "PROTOCOL_NOT_OBJECT")
    _require(
        protocol.get("canonical_evidence_parent")
        == "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/turning/"
        "r23d76-bounded-native-smoke-v1",
        "EVIDENCE_PARENT_INVALID",
    )
    for field in (
        "clean_pushed_live_equal_source_required",
        "machine_wide_physical_mutex_required",
        "serial_engine_order_required",
        "append_only_attempt_required",
        "rapier_build_before_worlds_is_zero_world",
        "continue_after_valid_physics_failure",
        "valid_terminal_required_per_engine",
        "world_construction_required_per_engine",
        "success_terminal_requires_exact_two_steps",
        "failure_terminal_is_not_behavioral_failure_evidence",
        "bounded_native_smoke_execution_authorized_after_clean_push",
    ):
        _require(protocol.get(field) is True, f"PROTOCOL_{field.upper()}_INVALID")
    for field in (
        "separate_native_preflight_process_count",
        "separate_authorization_canary_process_count",
        "aggregate_behavior_evaluator_process_count",
        "full_seeded_ghost_process_count",
    ):
        _require(protocol.get(field) == 0, f"PROTOCOL_{field.upper()}_INVALID")
    _require(
        protocol.get("physical_worker_process_count") == len(ENGINE_IDS),
        "PHYSICAL_PROCESS_COUNT_INVALID",
    )
    _require(
        protocol.get("held_out_finite_campaign_execution_authorized") is False,
        "HELD_OUT_CAMPAIGN_AUTHORIZED",
    )

    adequacy = value.get("adequacy")
    _require(isinstance(adequacy, Mapping), "ADEQUACY_NOT_OBJECT")
    _require(
        adequacy.get("complete_native_producer_population_count") == len(ENGINE_IDS)
        and adequacy.get("complete_native_producer_population_required") is True
        and adequacy.get("sampling_used") is False,
        "ADEQUACY_POPULATION_INVALID",
    )
    for field in ("behavior_threshold", "equivalence_margin", "non_inferiority_margin"):
        _require(adequacy.get(field) is None, f"ADEQUACY_{field.upper()}_INVALID")
    _require(
        isinstance(adequacy.get("argument"), str)
        and len(str(adequacy.get("argument"))) >= 300,
        "ADEQUACY_ARGUMENT_INVALID",
    )

    interpretation = value.get("interpretation")
    _require(isinstance(interpretation, Mapping), "INTERPRETATION_NOT_OBJECT")
    _require(interpretation.get("development_only") is True, "DEVELOPMENT_ONLY_INVALID")
    for field in (
        "behavior_thresholds_applied",
        "behavioral_success_prediction_allowed",
        "finite_evidence",
        "cross_engine_equivalence_evidence",
        "physical_acceptance_authority",
        "release_authority",
    ):
        _require(interpretation.get(field) is False, f"INTERPRETATION_{field.upper()}")

    claims = value.get("claims")
    _require(isinstance(claims, Mapping) and len(claims) == 14, "CLAIMS_INVALID")
    _require(all(claim is False for claim in claims.values()), "CLAIM_TRUE")


def _validate_parent_authorities() -> dict[str, Any]:
    declaration = _load_json(DECLARATION_PATH, "DECLARATION")
    implementation = _load_json(IMPLEMENTATION_PATH, "IMPLEMENTATION")
    delegate_contract = _load_json(DELEGATE_CONTRACT_PATH, "DELEGATE_CONTRACT")
    delegate_closure = _load_json(DELEGATE_CLOSURE_PATH, "DELEGATE_CLOSURE")

    smoke = declaration.get("post_zero_world_native_smoke")
    claims = declaration.get("claims")
    _require(isinstance(smoke, Mapping), "DECLARATION_SMOKE_NOT_OBJECT")
    _require(
        declaration.get("campaign_id")
        == "QSDK-R23D76-FRESH-FINITE-THREE-ENGINE-TURNING-DECISION"
        and declaration.get("gate_id") == "QSDK-R23D76",
        "DECLARATION_IDENTITY_INVALID",
    )
    _require(
        smoke.get("engine_count") == 3
        and smoke.get("maximum_world_count") == 3
        and smoke.get("maximum_solver_step_count_per_world") == 2
        and smoke.get("uses_held_out_seed_23197") is False
        and smoke.get("behavior_thresholds_applied") is False
        and smoke.get("finite_evidence") is False
        and smoke.get("physical_acceptance_authority") is False,
        "DECLARATION_SMOKE_DRIFT",
    )
    _require(
        isinstance(claims, Mapping)
        and claims.get("native_smoke_passed") is False
        and claims.get("physical_campaign_opened") is False,
        "DECLARATION_CLAIM_DRIFT",
    )

    expected_status = (
        "implementation_complete_complete_zero_world_gate_passed_"
        "bounded_native_smoke_pending_physical_not_authorized"
    )
    complete_gate = implementation.get("complete_zero_world_gate")
    bounded = implementation.get("bounded_native_smoke")
    implementation_claims = implementation.get("claims")
    _require(implementation.get("status") == expected_status, "IMPLEMENTATION_STATUS_DRIFT")
    _require(
        implementation.get("campaign_seed") == HELD_OUT_SEED
        and implementation.get("declared_cell_count") == 9
        and implementation.get("declared_world_count") == 9,
        "IMPLEMENTATION_POPULATION_DRIFT",
    )
    _require(
        isinstance(complete_gate, Mapping)
        and complete_gate.get("passed") is True
        and complete_gate.get("full_seeded_world_ghost_used") is False
        and all(
            complete_gate.get(field) == 0
            for field in (
                "model_construction_count",
                "world_attempt_count",
                "world_build_count",
                "solver_step_count",
            )
        )
        and complete_gate.get("physical_execution_authorized") is False
        and complete_gate.get("physical_acceptance_authority") is False,
        "IMPLEMENTATION_ZERO_WORLD_DRIFT",
    )
    _require(
        complete_gate.get("audit_raw_sha256") == _raw_sha256(R23D76_ZERO_WORLD_AUDIT_PATH),
        "IMPLEMENTATION_ZERO_WORLD_AUDIT_DIGEST_DRIFT",
    )
    _require(
        isinstance(bounded, Mapping)
        and bounded.get("passed") is False
        and bounded.get("maximum_world_count") == 3
        and bounded.get("maximum_solver_step_count_per_engine") == 2
        and bounded.get("uses_held_out_seed_23197") is False,
        "IMPLEMENTATION_SMOKE_DRIFT",
    )
    _require(
        isinstance(implementation_claims, Mapping)
        and implementation_claims.get("bounded_native_smoke_passed") is False
        and implementation_claims.get("physical_campaign_opened") is False,
        "IMPLEMENTATION_CLAIM_DRIFT",
    )
    _require(
        implementation.get("preregistration_raw_sha256") == _raw_sha256(DECLARATION_PATH),
        "IMPLEMENTATION_DECLARATION_DIGEST_DRIFT",
    )

    digests = implementation.get("dependency_digests")
    inventory = implementation.get("dependency_inventory")
    _require(isinstance(digests, Mapping) and len(digests) == 222, "DEPENDENCY_SET_INVALID")
    _require(isinstance(inventory, Mapping), "DEPENDENCY_INVENTORY_INVALID")
    ordered_paths = inventory.get("ordered_paths")
    _require(
        isinstance(ordered_paths, list)
        and ordered_paths == sorted(digests)
        and len(ordered_paths) == len(digests),
        "DEPENDENCY_ORDER_INVALID",
    )
    repo = REPO_ROOT.resolve(strict=True)
    for relative, expected_digest in digests.items():
        _require(isinstance(relative, str) and relative != "", "DEPENDENCY_PATH_INVALID")
        candidate = (REPO_ROOT / relative).resolve(strict=True)
        try:
            candidate.relative_to(repo)
        except ValueError as error:
            raise BoundedSmokeError(
                f"R23D76_BOUNDED_SMOKE_DEPENDENCY_ESCAPES_REPOSITORY:{relative}"
            ) from error
        _require(candidate.is_file(), f"DEPENDENCY_MISSING:{relative}")
        _require(_raw_sha256(candidate) == expected_digest, f"DEPENDENCY_DRIFT:{relative}")

    _require(
        delegate_contract.get("route_id") == delegate.ROUTE_ID
        and delegate_contract.get("development_ghost", {}).get("development_seed")
        == DEVELOPMENT_SEED
        and delegate_contract.get("development_ghost", {}).get("controller_step_count")
        == MAX_SOLVER_STEPS_PER_ENGINE
        and delegate_contract.get("development_ghost", {}).get("ordered_engine_ids")
        == list(ENGINE_IDS),
        "DELEGATE_CONTRACT_DRIFT",
    )
    _require(
        delegate_closure.get("route_id") == delegate.ROUTE_ID
        and delegate_closure.get("status")
        == "closed_complete_execution_valid_development_success_transport_ghost"
        and delegate_closure.get("next_work", {}).get("transport_route_closed") is True
        and delegate_closure.get("next_work", {}).get("repeat_transport_smoke_required")
        is False,
        "DELEGATE_CLOSURE_DRIFT",
    )

    required_paths = CONTRACT["native_delegate"]["required_source_paths"]
    delegate_sources = [_source_artifact(REPO_ROOT / relative) for relative in required_paths]
    return {
        "r23d76_declaration_artifact": _source_artifact(DECLARATION_PATH),
        "r23d76_implementation_artifact": _source_artifact(IMPLEMENTATION_PATH),
        "r23d76_zero_world_audit_artifact": _source_artifact(R23D76_ZERO_WORLD_AUDIT_PATH),
        "r23d76_dependency_count": len(digests),
        "r23d76_dependency_projection_sha256": _canonical_json_sha256(digests),
        "r23d76_dependency_inventory_projection_sha256": inventory.get(
            "inventory_projection_sha256"
        ),
        "delegate_contract_artifact": _source_artifact(DELEGATE_CONTRACT_PATH),
        "delegate_closure_artifact": _source_artifact(DELEGATE_CLOSURE_PATH),
        "delegate_source_artifacts": delegate_sources,
    }


def preflight() -> dict[str, Any]:
    """Prove the source-only smoke contract and all reused R23D76 dependencies."""

    validate_contract(CONTRACT)
    authorities = _validate_parent_authorities()
    return {
        "schema_version": "sporespore_qsdk_r23d76_bounded_native_smoke_preflight_v1",
        "smoke_id": SMOKE_ID,
        "ledger_scope": dict(LEDGER_SCOPE),
        "contract_artifact": _source_artifact(CONTRACT_PATH),
        "supervisor_artifact": _source_artifact(SUPERVISOR_PATH),
        "parent_authorities": authorities,
        "complete_zero_world_gate_reuse_source_dependencies_exact": True,
        "delegate_cold_reuse_runtime_check_pending": True,
        "separate_native_preflight_process_count": 0,
        "separate_authorization_canary_process_count": 0,
        "aggregate_behavior_evaluator_process_count": 0,
        "full_seeded_ghost_process_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
    }


def _environment_receipt() -> dict[str, Any]:
    try:
        mujoco_version = importlib.metadata.version("mujoco")
    except importlib.metadata.PackageNotFoundError:
        mujoco_version = "not-installed-in-supervisor-host"
    return {
        "os_name": os.name,
        "platform": platform.platform(),
        "python_version": platform.python_version(),
        "mujoco_package_version_in_supervisor_host": mujoco_version,
        "processor_architecture": os.environ.get("PROCESSOR_ARCHITECTURE", ""),
    }


def _canonical_artifact_key(path: str | Path) -> str:
    try:
        return os.path.normcase(os.path.normpath(str(Path(path).resolve(strict=True))))
    except OSError as error:
        raise BoundedSmokeError(
            f"R23D76_BOUNDED_SMOKE_COLD_DEPENDENCY_MISSING:{path}"
        ) from error


def _artifact_map(values: Sequence[Mapping[str, Any]], label: str) -> dict[str, tuple[str, int]]:
    result: dict[str, tuple[str, int]] = {}
    for value in values:
        path = value.get("path")
        digest = value.get("sha256")
        byte_length = value.get("byte_length")
        _require(
            isinstance(path, str)
            and isinstance(digest, str)
            and digest.startswith("sha256:")
            and type(byte_length) is int
            and byte_length >= 0,
            f"{label}_ARTIFACT_INVALID",
        )
        key = _canonical_artifact_key(path)
        _require(key not in result, f"{label}_ARTIFACT_DUPLICATE")
        result[key] = (digest, byte_length)
    return result


def _prove_delegate_cold_reuse(
    runtime: Any, current_artifacts: Sequence[Mapping[str, Any]] | None = None
) -> dict[str, Any]:
    """Require exact equality with the closed route's complete cold gate key."""

    closure = _load_json(DELEGATE_CLOSURE_PATH, "DELEGATE_CLOSURE")
    passing = closure.get("passing_attempt")
    population = closure.get("passing_evidence_population")
    _require(isinstance(passing, Mapping), "COLD_PASSING_ATTEMPT_INVALID")
    _require(isinstance(population, Mapping), "COLD_POPULATION_INVALID")
    attempt_root = Path(str(passing.get("attempt_root", ""))).resolve(strict=True)
    zero_world_path = attempt_root / "zero-world/complete-gate.json"
    zero_world = _load_json(zero_world_path, "COLD_ZERO_WORLD")
    selected = population.get("selected_artifacts")
    _require(isinstance(selected, list), "COLD_SELECTED_ARTIFACTS_INVALID")
    matches = [
        item
        for item in selected
        if isinstance(item, Mapping)
        and item.get("relative_path") == "zero-world/complete-gate.json"
    ]
    _require(len(matches) == 1, "COLD_ZERO_WORLD_SELECTION_INVALID")
    selected_zero = matches[0]
    _require(
        selected_zero.get("raw_sha256") == _raw_sha256(zero_world_path)
        and selected_zero.get("byte_length") == zero_world_path.stat().st_size,
        "COLD_ZERO_WORLD_ARTIFACT_DRIFT",
    )
    _require(
        zero_world.get("route_id") == delegate.ROUTE_ID
        and zero_world.get("complete_zero_world_gate_passed") is True
        and zero_world.get("process_count") == 8
        and all(
            zero_world.get(field) == 0
            for field in (
                "model_construction_count",
                "world_attempt_count",
                "world_build_count",
            )
        )
        and zero_world.get("physical_execution_authorized") is False
        and zero_world.get("physical_acceptance_authority") is False,
        "COLD_ZERO_WORLD_RESULT_INVALID",
    )
    historical_artifacts = zero_world.get("dependency_artifacts")
    _require(
        isinstance(historical_artifacts, list) and len(historical_artifacts) >= 14,
        "COLD_DEPENDENCY_POPULATION_INVALID",
    )
    if current_artifacts is None:
        current_artifacts = delegate._dependency_artifacts(runtime)
    historical_map = _artifact_map(historical_artifacts, "COLD_HISTORICAL")
    current_map = _artifact_map(current_artifacts, "COLD_CURRENT")
    _require(current_map == historical_map, "COLD_DEPENDENCY_OR_TOOLCHAIN_DRIFT")
    _require(
        zero_world.get("environment") == _environment_receipt(),
        "COLD_ENVIRONMENT_DRIFT",
    )
    return {
        "schema_version": "sporespore_qsdk_r23d76_delegate_cold_reuse_proof_v1",
        "smoke_id": SMOKE_ID,
        "delegate_route_id": delegate.ROUTE_ID,
        "historical_passing_source_commit": passing.get("source_commit"),
        "historical_attempt_id": passing.get("attempt_id"),
        "historical_zero_world_artifact": {
            "path": str(zero_world_path),
            "sha256": _raw_sha256(zero_world_path),
            "byte_length": zero_world_path.stat().st_size,
        },
        "complete_cold_gate_passed": True,
        "complete_dependency_toolchain_environment_key_exact": True,
        "dependency_artifact_count": len(current_artifacts),
        "dependency_projection_sha256": _canonical_json_sha256(list(current_artifacts)),
        "dependency_artifacts": list(current_artifacts),
        "environment": _environment_receipt(),
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
    }


def _require_canonical_evidence_root(value: Path | None) -> Path:
    expected = DEFAULT_EVIDENCE_ROOT.resolve()
    candidate = expected if value is None else value.resolve()
    _require(candidate == expected, f"EVIDENCE_ROOT_INVALID:{candidate}")
    return candidate


def _attempt_root(evidence_root: Path, attempt_id: str) -> Path:
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    return (
        evidence_root
        / "turning/r23d76-bounded-native-smoke-v1"
        / f"{stamp}__{attempt_id}"
    )


def _outer_freeze(
    source: Mapping[str, Any],
    source_preflight_artifact: Mapping[str, Any],
    cold_reuse_artifact: Mapping[str, Any],
) -> dict[str, Any]:
    return {
        "schema_version": OUTER_FREEZE_SCHEMA,
        "smoke_id": SMOKE_ID,
        "ledger_scope": dict(LEDGER_SCOPE),
        "source_commit": source["source_commit"],
        "origin_main_commit": source["origin_main_commit"],
        "live_github_main_commit": source["live_github_main_commit"],
        "source_tree": source["source_tree"],
        "source_worktree_clean": True,
        "local_remote_live_equal": True,
        "smoke_source_artifacts": [
            _source_artifact(CONTRACT_PATH),
            _source_artifact(SUPERVISOR_PATH),
            _source_artifact(TEST_PATH),
        ],
        "r23d76_zero_world_source_preflight_artifact": dict(source_preflight_artifact),
        "delegate_complete_cold_reuse_artifact": dict(cold_reuse_artifact),
        "ordered_engine_ids": list(ENGINE_IDS),
        "development_seed": DEVELOPMENT_SEED,
        "held_out_seed": HELD_OUT_SEED,
        "uses_held_out_seed_23197": False,
        "maximum_world_count": MAX_WORLD_COUNT,
        "maximum_solver_step_count_per_engine": MAX_SOLVER_STEPS_PER_ENGINE,
        "serial_execution_required": True,
        "physical_execution_authorized": True,
        "authorization_scope": "bounded_native_smoke_only",
        "held_out_finite_campaign_execution_authorized": False,
        "behavior_thresholds_applied": False,
        "behavioral_success_prediction_allowed": False,
        "physical_acceptance_authority": False,
    }


def _outer_attempt(
    *,
    source_commit: str,
    freeze_artifact: Mapping[str, Any],
    attempt_id: str,
    attempt_root: Path,
) -> dict[str, Any]:
    return {
        "schema_version": OUTER_ATTEMPT_SCHEMA,
        "smoke_id": SMOKE_ID,
        "ledger_scope": dict(LEDGER_SCOPE),
        "source_commit": source_commit,
        "freeze_sha256": freeze_artifact["sha256"],
        "attempt_id": attempt_id,
        "attempt_root": str(attempt_root.resolve(strict=True)),
        "ordered_engine_ids": list(ENGINE_IDS),
        "single_use_append_only_authorization": True,
        "operation_lock_held": True,
        "physical_execution_authorized": True,
        "authorization_scope": "bounded_native_smoke_only",
        "held_out_finite_campaign_execution_authorized": False,
        "behavior_thresholds_applied": False,
        "physical_acceptance_authority": False,
    }


def _terminal_projection(
    spec: Any,
    process: Mapping[str, Any],
    source_commit: str,
) -> tuple[dict[str, Any], dict[str, Any]]:
    terminal: dict[str, Any] | None = None
    validation_failure = ""
    worker_success = False
    try:
        terminal = delegate._marker_json(str(process.get("stdout", "")), spec.terminal_marker)
        worker_success = delegate._validate_physical_terminal(
            spec, terminal, source_commit
        )
    except delegate.RouteSupervisorError as error:
        validation_failure = str(error)

    terminal_valid = terminal is not None and validation_failure == ""
    world_attempt_count: int | None = None
    world_build_count: int | None = None
    exact_solver_step_count: int | None = None
    if terminal_valid and terminal is not None:
        if worker_success:
            execution = terminal["execution"]
            world_attempt_count = int(execution["world_attempt_count"])
            world_build_count = int(execution["world_build_count"])
            exact_solver_step_count = int(execution["controller_semantic_step_count"])
        else:
            world_attempt_count = int(terminal["world_attempt_count"])
            world_build_count = int(terminal["world_build_count"])

    process_valid = (
        process.get("timed_out") is False
        and (not worker_success or process.get("exit_code") == 0)
    )
    counts_bounded = (
        type(world_attempt_count) is int
        and type(world_build_count) is int
        and 0 <= world_attempt_count <= 1
        and 0 <= world_build_count <= 1
        and world_build_count <= world_attempt_count
        and (
            exact_solver_step_count is None
            or 0 <= exact_solver_step_count <= MAX_SOLVER_STEPS_PER_ENGINE
        )
    )
    world_constructed = world_attempt_count == 1 and world_build_count == 1
    integration_valid = bool(
        terminal_valid and process_valid and counts_bounded and world_constructed
    )
    projection = {
        "schema_version": "sporespore_qsdk_r23d76_bounded_native_smoke_cell_v1",
        "smoke_id": SMOKE_ID,
        "engine_id": spec.engine_id,
        "delegate_cell_id": spec.cell_id,
        "source_commit": source_commit,
        "terminal_observed": terminal is not None,
        "terminal_valid": terminal_valid,
        "terminal_validation_failure": validation_failure,
        "worker_outcome_class": (
            "success_terminal"
            if terminal_valid and worker_success
            else ("failure_terminal" if terminal_valid else "invalid_or_missing_terminal")
        ),
        "behavior_outcome_evaluated": False,
        "world_attempt_count": world_attempt_count,
        "world_build_count": world_build_count,
        "exact_solver_step_count": exact_solver_step_count,
        "solver_step_upper_bound_from_frozen_delegate": MAX_SOLVER_STEPS_PER_ENGINE,
        "counts_bounded": counts_bounded,
        "world_constructed": world_constructed,
        "process_valid": process_valid,
        "integration_valid": integration_valid,
        "physical_behavior_thresholds_applied": False,
        "finite_evidence": False,
        "physical_acceptance_authority": False,
    }
    if terminal is None:
        terminal = {
            "schema_version": "sporespore_qsdk_r23d76_bounded_native_smoke_missing_terminal_v1",
            "smoke_id": SMOKE_ID,
            "engine_id": spec.engine_id,
            "source_commit": source_commit,
            "failure_code": validation_failure or "WORKER_TERMINAL_MISSING",
            "process_exit_code": process.get("exit_code"),
            "process_timed_out": process.get("timed_out"),
            "world_attempt_count": None,
            "world_build_count": None,
            "physical_acceptance_authority": False,
        }
    return terminal, projection


def run_bounded_native_smoke(
    runtime: Any,
    *,
    evidence_root: Path | None = None,
    process_runner: Any = delegate._run_process,
    timeout_seconds: int = 600,
) -> dict[str, Any]:
    """Run exactly one build and one bounded native worker per engine."""

    canonical_evidence_root = _require_canonical_evidence_root(evidence_root)
    progress = {
        "physical_worker_process_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
    }
    with delegate.LocomotionOperationMutex("physical") as operation_lock:
        source = delegate.verify_exact_source_state()
        source_commit = str(source["source_commit"])
        canonical_evidence_root.mkdir(parents=True, exist_ok=True)
        attempt_id = uuid.uuid4().hex
        token = secrets.token_hex(16)
        attempt_root = _attempt_root(canonical_evidence_root, attempt_id)
        attempt_root.mkdir(parents=True, exist_ok=False)
        reservation = {
            "schema_version": "sporespore_qsdk_r23d76_bounded_native_smoke_reservation_v1",
            "smoke_id": SMOKE_ID,
            "ledger_scope": dict(LEDGER_SCOPE),
            "attempt_id": attempt_id,
            "attempt_root": str(attempt_root.resolve()),
            "source_commit": source_commit,
            "reserved_utc": _utc_now(),
            "operation_lock": operation_lock,
            "create_new_reservation": True,
            "development_seed": DEVELOPMENT_SEED,
            "uses_held_out_seed_23197": False,
            "maximum_world_count": MAX_WORLD_COUNT,
            "maximum_solver_step_count_per_engine": MAX_SOLVER_STEPS_PER_ENGINE,
            "physical_execution_authorized": True,
            "authorization_scope": "bounded_native_smoke_only",
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
            current_delegate_artifacts = delegate._dependency_artifacts(runtime)
            cold_reuse = _prove_delegate_cold_reuse(runtime, current_delegate_artifacts)

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
            _require(runtime.rapier_binary.is_file(), "RAPIER_BINARY_MISSING_AFTER_BUILD")
            post_build_artifacts = delegate._dependency_artifacts(runtime)
            cold_reuse = _prove_delegate_cold_reuse(runtime, post_build_artifacts)
            cold_reuse["rapier_build_process_record"] = retained_build
            cold_reuse_artifact = delegate._write_new_json(
                attempt_root / "pre-physical/delegate-cold-reuse-proof.json",
                cold_reuse,
            )
            _require(
                delegate.verify_exact_source_state() == source,
                "SOURCE_DRIFT_AFTER_PREPHYSICAL",
            )

            outer_freeze = _outer_freeze(
                source, source_preflight_artifact, cold_reuse_artifact
            )
            outer_freeze_path = attempt_root / "bounded-smoke-freeze.json"
            outer_freeze_artifact = delegate._write_new_json(
                outer_freeze_path, outer_freeze
            )
            outer_attempt = _outer_attempt(
                source_commit=source_commit,
                freeze_artifact=outer_freeze_artifact,
                attempt_id=attempt_id,
                attempt_root=attempt_root,
            )
            outer_attempt_artifact = delegate._write_new_json(
                attempt_root / "bounded-smoke-authorization.json", outer_attempt
            )

            # The native workers retain their historical raw route identity.
            # Their authorization is backed by the exact cold-equivalence proof
            # above; the outer R23D76 documents provide the new question scope.
            delegate_freeze = delegate._freeze_document(source, cold_reuse_artifact)
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

            specs = delegate._worker_specs(runtime, source_commit)
            _require(
                tuple(spec.engine_id for spec in specs) == ENGINE_IDS,
                "WORKER_ORDER_INVALID",
            )
            physical_records: list[dict[str, Any]] = []
            terminal_paths: list[str] = []
            cell_projections: list[dict[str, Any]] = []
            for index, spec in enumerate(specs):
                _require(
                    delegate.verify_exact_source_state() == source,
                    f"SOURCE_DRIFT_BEFORE_ENGINE:{spec.engine_id}",
                )
                process_name = f"{spec.engine_id}_bounded_native_smoke"
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
                progress["physical_worker_process_count"] += 1
                process_root = attempt_root / "physical" / f"{index:02d}__{process_name}"
                retained_process = delegate._retain_process(
                    attempt_root / "physical", index, process
                )
                physical_records.append(retained_process)
                terminal, projection = _terminal_projection(spec, process, source_commit)
                terminal_path = process_root / "terminal.json"
                projection_path = process_root / "smoke-projection.json"
                delegate._write_new_json(terminal_path, terminal)
                delegate._write_new_json(projection_path, projection)
                terminal_paths.append(str(terminal_path.resolve()))
                cell_projections.append(projection)
                if type(projection.get("world_attempt_count")) is int:
                    progress["world_attempt_count"] += int(
                        projection["world_attempt_count"]
                    )
                if type(projection.get("world_build_count")) is int:
                    progress["world_build_count"] += int(projection["world_build_count"])

            _require(
                delegate.verify_exact_source_state() == source,
                "SOURCE_DRIFT_AFTER_PHYSICAL",
            )
            terminal_manifest = {
                "schema_version": (
                    "sporespore_qsdk_r23d76_bounded_native_smoke_terminal_manifest_v1"
                ),
                "smoke_id": SMOKE_ID,
                "source_commit": source_commit,
                "ordered_engine_ids": list(ENGINE_IDS),
                "terminal_paths": terminal_paths,
                "terminal_count": len(terminal_paths),
                "physical_behavior_thresholds_applied": False,
                "physical_acceptance_authority": False,
            }
            terminal_manifest_artifact = delegate._write_new_json(
                attempt_root / "terminal-manifest.json", terminal_manifest
            )
            smoke_passed = bool(
                len(cell_projections) == len(ENGINE_IDS)
                and all(cell.get("integration_valid") is True for cell in cell_projections)
                and progress["world_attempt_count"] == MAX_WORLD_COUNT
                and progress["world_build_count"] == MAX_WORLD_COUNT
            )
            success_count = sum(
                cell.get("worker_outcome_class") == "success_terminal"
                for cell in cell_projections
            )
            failure_count = sum(
                cell.get("worker_outcome_class") == "failure_terminal"
                for cell in cell_projections
            )
            exact_observed_steps = [
                cell["exact_solver_step_count"]
                for cell in cell_projections
                if type(cell.get("exact_solver_step_count")) is int
            ]
            result = {
                "schema_version": RESULT_SCHEMA,
                "smoke_id": SMOKE_ID,
                "ledger_scope": dict(LEDGER_SCOPE),
                "authority_mode": "bounded_native_smoke",
                "question_class": "development",
                "source_commit": source_commit,
                "attempt_id": attempt_id,
                "attempt_root": str(attempt_root.resolve()),
                "bounded_native_smoke_passed": smoke_passed,
                "outcome_class": (
                    "bounded_native_smoke_integration_valid"
                    if smoke_passed
                    else "bounded_native_smoke_invalid_or_incomplete"
                ),
                "development_seed": DEVELOPMENT_SEED,
                "held_out_seed": HELD_OUT_SEED,
                "uses_held_out_seed_23197": False,
                "declared_engine_count": len(ENGINE_IDS),
                "physical_worker_process_count": progress[
                    "physical_worker_process_count"
                ],
                "world_attempt_count": progress["world_attempt_count"],
                "world_build_count": progress["world_build_count"],
                "maximum_solver_step_count_per_engine": MAX_SOLVER_STEPS_PER_ENGINE,
                "maximum_total_solver_step_count": (
                    MAX_WORLD_COUNT * MAX_SOLVER_STEPS_PER_ENGINE
                ),
                "exact_observed_solver_step_count": (
                    sum(exact_observed_steps)
                    if len(exact_observed_steps) == len(ENGINE_IDS)
                    else None
                ),
                "worker_success_terminal_count": success_count,
                "worker_failure_terminal_count": failure_count,
                "behavior_outcome_evaluated": False,
                "aggregate_behavior_evaluator_process_count": 0,
                "separate_native_preflight_process_count": 0,
                "separate_authorization_canary_process_count": 0,
                "full_seeded_ghost_process_count": 0,
                "cell_projections": cell_projections,
                "reservation_artifact": reservation_artifact,
                "source_preflight_artifact": source_preflight_artifact,
                "cold_reuse_artifact": cold_reuse_artifact,
                "outer_freeze_artifact": outer_freeze_artifact,
                "outer_attempt_artifact": outer_attempt_artifact,
                "delegate_freeze_artifact": delegate_freeze_artifact,
                "delegate_attempt_artifact": delegate_attempt_artifact,
                "terminal_manifest_artifact": terminal_manifest_artifact,
                "physical_process_records": physical_records,
                "physical_behavior_thresholds_applied": False,
                "finite_evidence": False,
                "claims": {
                    "bounded_native_smoke_opened": True,
                    "bounded_native_smoke_passed": smoke_passed,
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
            completion = {
                "schema_version": (
                    "sporespore_qsdk_r23d76_bounded_native_smoke_completion_v1"
                ),
                "smoke_id": SMOKE_ID,
                "attempt_id": attempt_id,
                "attempt_identity_consumed": True,
                "same_attempt_rerun_allowed": False,
                "result_artifact": result_artifact,
                "bounded_native_smoke_passed": smoke_passed,
                "completed_utc": _utc_now(),
                "physical_acceptance_authority": False,
            }
            completion_artifact = delegate._write_new_json(
                attempt_root / "attempt-completion.json", completion
            )
            result["result_artifact"] = result_artifact
            result["completion_artifact"] = completion_artifact
            return result
        except Exception as error:
            incomplete = {
                "schema_version": (
                    "sporespore_qsdk_r23d76_bounded_native_smoke_incomplete_v1"
                ),
                "smoke_id": SMOKE_ID,
                "ledger_scope": dict(LEDGER_SCOPE),
                "source_commit": source_commit,
                "attempt_id": attempt_id,
                "attempt_root": str(attempt_root.resolve()),
                "failure_code": f"{type(error).__name__}:{error}",
                "attempt_identity_consumed": True,
                "bounded_native_smoke_passed": False,
                "physical_worker_process_count": progress[
                    "physical_worker_process_count"
                ],
                "world_attempt_count": progress["world_attempt_count"],
                "world_build_count": progress["world_build_count"],
                "uses_held_out_seed_23197": False,
                "behavior_outcome_evaluated": False,
                "physical_acceptance_authority": False,
            }
            try:
                delegate._write_new_json(
                    attempt_root / "supervisor-incomplete.json", incomplete
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
        value = run_bounded_native_smoke(
            runtime,
            timeout_seconds=arguments.timeout_seconds,
        )
        print(
            RESULT_MARKER
            + json.dumps(value, allow_nan=False, separators=(",", ":"), sort_keys=True)
        )
        return 0 if value.get("bounded_native_smoke_passed") is True else 1
    except (
        BoundedSmokeError,
        delegate.RouteSupervisorError,
        OSError,
        UnicodeError,
        ValueError,
    ) as error:
        print(
            ERROR_MARKER
            + json.dumps(
                {
                    "schema_version": (
                        "sporespore_qsdk_r23d76_bounded_native_smoke_error_v1"
                    ),
                    "smoke_id": SMOKE_ID,
                    "failure_code": f"{type(error).__name__}:{error}",
                    "physical_counts_available_only_in_retained_attempt": True,
                    "held_out_seed_23197_opened": False,
                    "physical_acceptance_authority": False,
                },
                allow_nan=False,
                separators=(",", ":"),
                sort_keys=True,
            ),
            file=sys.stderr,
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
