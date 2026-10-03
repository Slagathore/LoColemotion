"""Success-transport retention and evaluation for bounded three-engine turning.

This module evaluates execution validity only.  It deliberately does not apply
walking or turning thresholds and cannot emit a behavioral or release claim.
The same entry points are used by the short development ghost and by a future
held-out configuration; authority comes from the caller's frozen route record,
not from a second evaluator implementation.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import subprocess
import sys
from collections.abc import Mapping, Sequence
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[2]
CONTRACT_PATH = (
    REPO_ROOT
    / "sdk/turning/three_engine_turning_success_transport_route_v2.json"
)
PUBLISHER_PATH = REPO_ROOT / "sdk/publish_qsdk_r23d48_trace.ps1"
CAS_MARKER = "QSDK_R23D48_EVIDENCE_CAS "
RETAINED_MARKER = "SPORESPORE_TURNING_ROUTE_TRACE_RETAINED "
EVALUATION_MARKER = "SPORESPORE_TURNING_ROUTE_EVALUATION "
PREFLIGHT_MARKER = "SPORESPORE_TURNING_ROUTE_EVALUATOR_PREFLIGHT "
SOURCE_COMMIT_LENGTH = 40


class RouteEvaluationError(RuntimeError):
    """A fail-closed route-integrity violation."""


def _load_contract(path: Path = CONTRACT_PATH) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise RouteEvaluationError(
            f"TURNING_ROUTE_CONTRACT_UNREADABLE:{type(error).__name__}"
        ) from error
    if not isinstance(value, dict):
        raise RouteEvaluationError("TURNING_ROUTE_CONTRACT_NOT_OBJECT")
    return value


CONTRACT = _load_contract()
ROUTE_ID = str(CONTRACT["route_id"])
GHOST = CONTRACT["development_ghost"]
LEDGER_SCOPE = CONTRACT["ledger_scope"]
TRACE_TRANSPORT = CONTRACT["trace_transport_contract"]
ENGINE_IDS = tuple(str(value) for value in GHOST["ordered_engine_ids"])
CONTROLLER_STEPS = int(GHOST["controller_step_count"])
TRACE_ROW_SCHEMA = str(GHOST["trace_row_schema"])
CELL_REPORT_SCHEMA = str(GHOST["cell_report_schema"])
WORKER_FAILURE_SCHEMA = str(GHOST["worker_failure_schema"])
TRACE_RETENTION_SCHEMA = str(GHOST["trace_retention_schema"])
EVALUATION_SCHEMA = str(GHOST["evaluation_schema"])
DEVELOPMENT_SEED = int(GHOST["development_seed"])
ARM_ID = str(GHOST["arm_id"])
HEADING_OFFSET = float(GHOST["turn_heading_offset_rad"])
TRACE_TRANSPORT_ID = str(TRACE_TRANSPORT["trace_transport_id"])
ARTIFACT_SCHEMA = str(TRACE_TRANSPORT["artifact_schema_version"])
TERMINAL_QUESTION_CLASS = str(TRACE_TRANSPORT["terminal_question_class"])


def _is_lower_hex(value: Any, length: int) -> bool:
    return (
        isinstance(value, str)
        and len(value) == length
        and all(character in "0123456789abcdef" for character in value)
    )


def _sha256(raw: bytes) -> str:
    return "sha256:" + hashlib.sha256(raw).hexdigest()


def _canonical_line(value: Mapping[str, Any]) -> bytes:
    try:
        encoded = json.dumps(
            value,
            allow_nan=False,
            ensure_ascii=False,
            separators=(",", ":"),
            sort_keys=True,
        )
    except (TypeError, ValueError) as error:
        raise RouteEvaluationError(
            f"TURNING_ROUTE_TRACE_ROW_NOT_CANONICAL_JSON:{type(error).__name__}"
        ) from error
    return encoded.encode("utf-8") + b"\n"


def expected_cell_id(engine_id: str) -> str:
    if engine_id not in ENGINE_IDS:
        raise RouteEvaluationError(f"TURNING_ROUTE_ENGINE_UNKNOWN:{engine_id}")
    return (
        f"turning_success_transport_v2__{engine_id}__s{DEVELOPMENT_SEED}__"
        f"{ARM_ID}"
    )


def _validate_trace_rows(rows: Any, *, engine_id: str, cell_id: str) -> list[dict[str, Any]]:
    if not isinstance(rows, list) or len(rows) != CONTROLLER_STEPS:
        raise RouteEvaluationError("TURNING_ROUTE_TRACE_ROW_COUNT_INVALID")
    normalized: list[dict[str, Any]] = []
    nonzero_turn_steps = 0
    for index, value in enumerate(rows):
        if not isinstance(value, dict):
            raise RouteEvaluationError(f"TURNING_ROUTE_TRACE_ROW_TYPE_INVALID:{index}")
        if value.get("schema_version") != TRACE_ROW_SCHEMA:
            raise RouteEvaluationError(f"TURNING_ROUTE_TRACE_ROW_SCHEMA_INVALID:{index}")
        if value.get("route_id") != ROUTE_ID:
            raise RouteEvaluationError(f"TURNING_ROUTE_TRACE_ROUTE_ID_INVALID:{index}")
        if value.get("engine_id") != engine_id or value.get("cell_id") != cell_id:
            raise RouteEvaluationError(f"TURNING_ROUTE_TRACE_CELL_IDENTITY_INVALID:{index}")
        if value.get("campaign_seed") != DEVELOPMENT_SEED:
            raise RouteEvaluationError(f"TURNING_ROUTE_TRACE_SEED_INVALID:{index}")
        if value.get("semantic_step") != index:
            raise RouteEvaluationError(f"TURNING_ROUTE_TRACE_STEP_INVALID:{index}")
        desired = value.get("desired_heading_offset_rad")
        if not isinstance(desired, (int, float)) or not math.isfinite(float(desired)):
            raise RouteEvaluationError(f"TURNING_ROUTE_TRACE_HEADING_INVALID:{index}")
        if abs(float(desired)) > 0.0:
            nonzero_turn_steps += 1
        normalized.append(dict(value))
    minimum = int(
        CONTRACT["route_integrity_thresholds"][
            "minimum_nonzero_turn_command_step_count_per_cell"
        ]
    )
    if nonzero_turn_steps < minimum:
        raise RouteEvaluationError("TURNING_ROUTE_TRACE_NONZERO_COMMAND_MISSING")
    return normalized


def _nonzero_turn_command_step_count(rows: Sequence[Mapping[str, Any]]) -> int:
    return sum(
        1
        for row in rows
        if abs(float(row.get("desired_heading_offset_rad", 0.0))) > 0.0
    )


def _safe_attempt_child(attempt_root: Path, relative: Path) -> Path:
    root = attempt_root.resolve()
    candidate = (root / relative).resolve()
    if candidate.parent != root and root not in candidate.parents:
        raise RouteEvaluationError("TURNING_ROUTE_ATTEMPT_PATH_ESCAPE")
    return candidate


def _bounded_stream(raw: bytes, limit: int = 4096) -> str:
    text = raw.decode("utf-8", errors="replace")
    return text if len(text) <= limit else text[:limit] + "...[truncated]"


def retain_trace(
    *,
    engine_id: str,
    cell_id: str,
    rows_json_path: Path,
    repo_root: Path,
    attempt_root: Path,
    powershell: str,
    test_only: bool = False,
    evidence_root_override: Path | None = None,
) -> dict[str, Any]:
    expected_id = expected_cell_id(engine_id)
    if cell_id != expected_id:
        raise RouteEvaluationError("TURNING_ROUTE_TRACE_CELL_ID_INVALID")
    if repo_root.resolve() != REPO_ROOT:
        raise RouteEvaluationError("TURNING_ROUTE_REPO_ROOT_INVALID")
    try:
        rows_value = json.loads(rows_json_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise RouteEvaluationError(
            f"TURNING_ROUTE_ROWS_JSON_UNREADABLE:{type(error).__name__}"
        ) from error
    rows = _validate_trace_rows(rows_value, engine_id=engine_id, cell_id=cell_id)
    trace_path = _safe_attempt_child(attempt_root, Path("traces") / f"{cell_id}.ndjson")
    trace_path.parent.mkdir(parents=True, exist_ok=True)
    if trace_path.exists():
        raise RouteEvaluationError("TURNING_ROUTE_TRACE_ALREADY_EXISTS")
    raw = b"".join(_canonical_line(row) for row in rows)
    trace_path.write_bytes(raw)
    digest = _sha256(raw)
    command = [
        powershell,
        "-NoLogo",
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        str(PUBLISHER_PATH),
        "-RepoRoot",
        str(REPO_ROOT),
        "-ArtifactPath",
        str(trace_path),
        "-ExpectedSha256",
        digest,
        "-ExpectedByteLength",
        str(len(raw)),
        "-MediaType",
        "application/x-ndjson",
    ]
    if test_only:
        if evidence_root_override is None:
            raise RouteEvaluationError("TURNING_ROUTE_TEST_EVIDENCE_ROOT_REQUIRED")
        command.extend(
            ["-TestOnly", "-EvidenceRootOverride", str(evidence_root_override.resolve())]
        )
    completed = subprocess.run(command, capture_output=True, check=False)
    markers = [
        line[len(CAS_MARKER) :]
        for line in completed.stdout.decode("utf-8", errors="replace").splitlines()
        if line.startswith(CAS_MARKER)
    ]
    if completed.returncode != 0 or len(markers) != 1:
        raise RouteEvaluationError(
            "TURNING_ROUTE_TRACE_PUBLICATION_FAILED:"
            f"exit={completed.returncode}:markers={len(markers)}:"
            f"stdout={_bounded_stream(completed.stdout)}:"
            f"stderr={_bounded_stream(completed.stderr)}"
        )
    try:
        artifact = json.loads(markers[0])
    except json.JSONDecodeError as error:
        raise RouteEvaluationError("TURNING_ROUTE_CAS_RECEIPT_JSON_INVALID") from error
    if (
        not isinstance(artifact, dict)
        or artifact.get("schema_version")
        != ARTIFACT_SCHEMA
        or artifact.get("sha256") != digest
        or artifact.get("byte_length") != len(raw)
        or artifact.get("physical_acceptance_authority") is not False
    ):
        raise RouteEvaluationError("TURNING_ROUTE_CAS_RECEIPT_INVALID")
    artifact.update(
        trace_transport_id=TRACE_TRANSPORT_ID,
        trace_transport_engine_id=engine_id,
        canonical_ndjson=True,
        full_precision=True,
    )
    _validate_trace_artifact_identity(artifact, engine_id=engine_id)
    nonzero_turn_command_step_count = _nonzero_turn_command_step_count(rows)
    trace_summary = {
        "row_count": len(rows),
        "first_semantic_step": 0,
        "last_semantic_step": len(rows) - 1,
        "nonzero_turn_command_step_count": nonzero_turn_command_step_count,
        "complete": True,
    }
    return {
        "schema_version": TRACE_RETENTION_SCHEMA,
        "route_id": ROUTE_ID,
        "ledger_scope": dict(LEDGER_SCOPE),
        "question_class": TERMINAL_QUESTION_CLASS,
        "engine_id": engine_id,
        "cell_id": cell_id,
        "campaign_seed": DEVELOPMENT_SEED,
        "row_count": len(rows),
        "first_semantic_step": 0,
        "last_semantic_step": len(rows) - 1,
        "nonzero_turn_command_step_count": nonzero_turn_command_step_count,
        "canonical_ndjson": True,
        "retained_before_terminal_entry": True,
        "trace_artifact": artifact,
        "trace_summary": trace_summary,
        "physical_behavior_thresholds_applied": False,
        "physical_acceptance_authority": False,
    }


def _validate_trace_artifact_identity(
    artifact: Any, *, engine_id: str
) -> Mapping[str, Any]:
    if not isinstance(artifact, Mapping):
        raise RouteEvaluationError("TURNING_ROUTE_TRACE_ARTIFACT_TYPE_INVALID")
    digest = artifact.get("sha256")
    digest_hex = digest.removeprefix("sha256:") if isinstance(digest, str) else ""
    if (
        artifact.get("schema_version") != ARTIFACT_SCHEMA
        or not _is_lower_hex(digest_hex, 64)
        or not isinstance(artifact.get("byte_length"), int)
        or int(artifact["byte_length"]) < 0
        or artifact.get("trace_transport_id") != TRACE_TRANSPORT_ID
        or artifact.get("trace_transport_engine_id") != engine_id
        or artifact.get("canonical_ndjson") is not True
        or artifact.get("full_precision") is not True
        or artifact.get("physical_acceptance_authority") is not False
    ):
        raise RouteEvaluationError(
            f"TURNING_ROUTE_TRACE_ARTIFACT_IDENTITY_INVALID:{engine_id}"
        )
    return artifact


def _trace_payload_rows(artifact: Any, *, engine_id: str, cell_id: str) -> list[dict[str, Any]]:
    artifact = _validate_trace_artifact_identity(artifact, engine_id=engine_id)
    digest = artifact.get("sha256")
    assert isinstance(digest, str)
    digest_hex = digest.removeprefix("sha256:")
    try:
        payload = Path(str(artifact["payload_path"])).resolve(strict=True)
        manifest_path = Path(str(artifact["manifest_path"])).resolve(strict=True)
        raw = payload.read_bytes()
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (KeyError, OSError, UnicodeError, json.JSONDecodeError) as error:
        raise RouteEvaluationError(
            f"TURNING_ROUTE_TRACE_ARTIFACT_UNREADABLE:{type(error).__name__}"
        ) from error
    if (
        _sha256(raw) != digest
        or len(raw) != artifact.get("byte_length")
        or not isinstance(manifest, Mapping)
        or manifest.get("sha256") != digest
        or manifest.get("byte_length") != len(raw)
        or manifest.get("media_type") != "application/x-ndjson"
    ):
        raise RouteEvaluationError("TURNING_ROUTE_TRACE_ARTIFACT_BYTES_INVALID")
    try:
        rows = [json.loads(line) for line in raw.decode("utf-8").splitlines()]
    except (UnicodeError, json.JSONDecodeError) as error:
        raise RouteEvaluationError("TURNING_ROUTE_TRACE_NDJSON_INVALID") from error
    return _validate_trace_rows(rows, engine_id=engine_id, cell_id=cell_id)


def _validate_success_terminal_shape(
    terminal: Any, *, engine_id: str, expected_source_commit: str
) -> Mapping[str, Any]:
    if not isinstance(terminal, Mapping):
        raise RouteEvaluationError(f"TURNING_ROUTE_TERMINAL_TYPE_INVALID:{engine_id}")
    cell_id = expected_cell_id(engine_id)
    expected_identity = {
        "schema_version": CELL_REPORT_SCHEMA,
        "route_id": ROUTE_ID,
        "ledger_scope": LEDGER_SCOPE,
        "question_class": TERMINAL_QUESTION_CLASS,
        "engine_id": engine_id,
        "cell_id": cell_id,
        "campaign_seed": DEVELOPMENT_SEED,
        "arm_id": ARM_ID,
        "turn_heading_offset_rad": HEADING_OFFSET,
        "source_commit": expected_source_commit,
    }
    for field, expected in expected_identity.items():
        if terminal.get(field) != expected:
            raise RouteEvaluationError(
                f"TURNING_ROUTE_TERMINAL_{field.upper()}_INVALID:{engine_id}"
            )
    forbidden_root_counts = (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
    )
    if any(field in terminal for field in forbidden_root_counts):
        raise RouteEvaluationError(f"TURNING_ROUTE_SUCCESS_ROOT_COUNTS_FORBIDDEN:{engine_id}")
    execution = terminal.get("execution")
    if not isinstance(execution, Mapping):
        raise RouteEvaluationError(f"TURNING_ROUTE_EXECUTION_MISSING:{engine_id}")
    if (
        execution.get("integrity_passed") is not True
        or execution.get("worker_failure_code") != ""
        or execution.get("controller_semantic_step_count") != CONTROLLER_STEPS
        or execution.get("world_attempt_count") != 1
        or execution.get("world_build_count") != 1
        or execution.get("trace_retained_before_terminal_entry") is not True
        or execution.get("fixed_horizon_configuration_proved_before_fixture_insertion")
        is not True
        or int(execution.get("nonzero_turn_command_step_count", -1)) < 1
    ):
        raise RouteEvaluationError(f"TURNING_ROUTE_EXECUTION_INVALID:{engine_id}")
    retention = terminal.get("trace_retention")
    if not isinstance(retention, Mapping):
        raise RouteEvaluationError(f"TURNING_ROUTE_TRACE_RETENTION_MISSING:{engine_id}")
    if (
        retention.get("schema_version") != TRACE_RETENTION_SCHEMA
        or retention.get("route_id") != ROUTE_ID
        or retention.get("question_class") != TERMINAL_QUESTION_CLASS
        or retention.get("engine_id") != engine_id
        or retention.get("cell_id") != cell_id
        or retention.get("row_count") != CONTROLLER_STEPS
        or retention.get("retained_before_terminal_entry") is not True
        or retention.get("canonical_ndjson") is not True
    ):
        raise RouteEvaluationError(f"TURNING_ROUTE_TRACE_RETENTION_INVALID:{engine_id}")
    root_artifact = terminal.get("trace_artifact")
    retention_artifact = retention.get("trace_artifact")
    if root_artifact != retention_artifact:
        raise RouteEvaluationError(
            f"TURNING_ROUTE_TRACE_ARTIFACT_PROJECTIONS_DIVERGED:{engine_id}"
        )
    artifact = _validate_trace_artifact_identity(root_artifact, engine_id=engine_id)
    if terminal.get("physical_behavior_thresholds_applied") is not False:
        raise RouteEvaluationError(f"TURNING_ROUTE_BEHAVIOR_THRESHOLD_LEAK:{engine_id}")
    claims = terminal.get("claims")
    if not isinstance(claims, Mapping) or any(value is not False for value in claims.values()):
        raise RouteEvaluationError(f"TURNING_ROUTE_CLAIM_LEAK:{engine_id}")
    return artifact


def _validate_success_terminal(
    terminal: Any, *, engine_id: str, expected_source_commit: str
) -> dict[str, Any]:
    cell_id = expected_cell_id(engine_id)
    artifact = _validate_success_terminal_shape(
        terminal,
        engine_id=engine_id,
        expected_source_commit=expected_source_commit,
    )
    rows = _trace_payload_rows(
        artifact,
        engine_id=engine_id,
        cell_id=cell_id,
    )
    return {
        "engine_id": engine_id,
        "cell_id": cell_id,
        "execution_valid": True,
        "trace_row_count": len(rows),
        "physics_behavior_classification": (
            "not_evaluated_development_success_transport_ghost"
        ),
    }


def evaluate_complete_entries(
    terminals: Sequence[Any], *, expected_source_commit: str
) -> dict[str, Any]:
    if not _is_lower_hex(expected_source_commit, SOURCE_COMMIT_LENGTH):
        raise RouteEvaluationError("TURNING_ROUTE_EXPECTED_SOURCE_COMMIT_INVALID")
    if len(terminals) != len(ENGINE_IDS):
        raise RouteEvaluationError("TURNING_ROUTE_TERMINAL_COUNT_INVALID")
    by_engine: dict[str, Any] = {}
    for terminal in terminals:
        if not isinstance(terminal, Mapping):
            raise RouteEvaluationError("TURNING_ROUTE_TERMINAL_TYPE_INVALID")
        engine_id = terminal.get("engine_id")
        if engine_id not in ENGINE_IDS or engine_id in by_engine:
            raise RouteEvaluationError("TURNING_ROUTE_ENGINE_POPULATION_INVALID")
        by_engine[str(engine_id)] = terminal
    evaluations = [
        _validate_success_terminal(
            by_engine[engine_id],
            engine_id=engine_id,
            expected_source_commit=expected_source_commit,
        )
        for engine_id in ENGINE_IDS
    ]
    return {
        "schema_version": EVALUATION_SCHEMA,
        "route_id": ROUTE_ID,
        "ledger_scope": dict(LEDGER_SCOPE),
        "configuration_id": GHOST["configuration_id"],
        "source_commit": expected_source_commit,
        "declared_engine_count": len(ENGINE_IDS),
        "execution_valid_engine_count": len(evaluations),
        "complete_evaluator_invocation_count": 1,
        "route_execution_valid": True,
        "valid_physics_negative_would_satisfy_route_question": True,
        "physical_behavior_thresholds_applied": False,
        "behavioral_outcome": "not_evaluated_development_success_transport_ghost",
        "engine_evaluations": evaluations,
        "claims": {
            "turning_established": False,
            "portable_basic_turning": False,
            "cross_engine_equivalence": False,
            "q_sdk_r23_satisfied": False,
            "release_authorized": False,
            "physical_acceptance_authority": False,
        },
    }


def run_zero_world_preflight() -> dict[str, Any]:
    source = "1" * SOURCE_COMMIT_LENGTH
    base = {
        "schema_version": CELL_REPORT_SCHEMA,
        "route_id": ROUTE_ID,
        "ledger_scope": dict(LEDGER_SCOPE),
        "question_class": TERMINAL_QUESTION_CLASS,
        "campaign_seed": DEVELOPMENT_SEED,
        "arm_id": ARM_ID,
        "turn_heading_offset_rad": HEADING_OFFSET,
        "source_commit": source,
        "execution": {
            "integrity_passed": True,
            "worker_failure_code": "",
            "controller_semantic_step_count": CONTROLLER_STEPS,
            "world_attempt_count": 1,
            "world_build_count": 1,
            "trace_retained_before_terminal_entry": True,
            "fixed_horizon_configuration_proved_before_fixture_insertion": True,
            "nonzero_turn_command_step_count": CONTROLLER_STEPS,
        },
        "physical_behavior_thresholds_applied": False,
        "claims": {
            "turning_established": False,
            "portable_basic_turning": False,
            "cross_engine_equivalence": False,
            "arbitrary_quadruped_coverage": False,
            "q_sdk_r23_satisfied": False,
            "release_authorized": False,
            "physical_acceptance_authority": False,
        },
    }
    controls: list[tuple[str, dict[str, Any]]] = []
    for engine_id in ENGINE_IDS:
        value = json.loads(json.dumps(base))
        value.update(engine_id=engine_id, cell_id=expected_cell_id(engine_id))
        artifact = {
            "schema_version": ARTIFACT_SCHEMA,
            "sha256": "sha256:" + "1" * 64,
            "byte_length": 1,
            "trace_transport_id": TRACE_TRANSPORT_ID,
            "trace_transport_engine_id": engine_id,
            "canonical_ndjson": True,
            "full_precision": True,
            "physical_acceptance_authority": False,
        }
        value["trace_artifact"] = artifact
        value["trace_retention"] = {
            "schema_version": TRACE_RETENTION_SCHEMA,
            "route_id": ROUTE_ID,
            "ledger_scope": dict(LEDGER_SCOPE),
            "question_class": TERMINAL_QUESTION_CLASS,
            "engine_id": engine_id,
            "cell_id": expected_cell_id(engine_id),
            "campaign_seed": DEVELOPMENT_SEED,
            "row_count": CONTROLLER_STEPS,
            "first_semantic_step": 0,
            "last_semantic_step": CONTROLLER_STEPS - 1,
            "nonzero_turn_command_step_count": CONTROLLER_STEPS,
            "canonical_ndjson": True,
            "retained_before_terminal_entry": True,
            "trace_artifact": json.loads(json.dumps(artifact)),
            "physical_behavior_thresholds_applied": False,
            "physical_acceptance_authority": False,
        }
        _validate_success_terminal_shape(
            value,
            engine_id=engine_id,
            expected_source_commit=source,
        )
        controls.append((engine_id, value))
    terminal_mutations: list[tuple[str, list[dict[str, Any]]]] = []
    missing_engine = [dict(value) for _, value in controls[:-1]]
    terminal_mutations.append(("missing_engine", missing_engine))
    root_count = [dict(value) for _, value in controls]
    root_count[0]["world_build_count"] = 1
    terminal_mutations.append(("success_root_count", root_count))
    bad_commit = [dict(value) for _, value in controls]
    bad_commit[1]["source_commit"] = "0" * SOURCE_COMMIT_LENGTH
    terminal_mutations.append(("source_commit", bad_commit))
    bad_execution = [json.loads(json.dumps(value)) for _, value in controls]
    bad_execution[2]["execution"]["world_build_count"] = 0
    terminal_mutations.append(("execution_count", bad_execution))
    missing_question = [json.loads(json.dumps(value)) for _, value in controls]
    missing_question[0].pop("question_class")
    terminal_mutations.append(("question_class_missing", missing_question))
    wrong_question = [json.loads(json.dumps(value)) for _, value in controls]
    wrong_question[1]["question_class"] = "finite_decision"
    terminal_mutations.append(("question_class_wrong", wrong_question))
    rejected: list[str] = []
    mutated_engine_indexes = {
        "success_root_count": 0,
        "source_commit": 1,
        "execution_count": 2,
        "question_class_missing": 0,
        "question_class_wrong": 1,
    }
    for name, values in terminal_mutations:
        try:
            if name == "missing_engine":
                if len(values) != len(ENGINE_IDS):
                    raise RouteEvaluationError("TURNING_ROUTE_TERMINAL_COUNT_INVALID")
            else:
                index = mutated_engine_indexes[name]
                _validate_success_terminal_shape(
                    values[index],
                    engine_id=ENGINE_IDS[index],
                    expected_source_commit=source,
                )
        except RouteEvaluationError:
            rejected.append(name)
    artifact_mutations: list[tuple[str, str, Any]] = [
        ("trace_transport_id_missing", "trace_transport_id", None),
        ("trace_transport_id_wrong", "trace_transport_id", "wrong"),
        ("trace_transport_engine_id_missing", "trace_transport_engine_id", None),
        ("trace_transport_engine_id_wrong", "trace_transport_engine_id", "mujoco"),
        ("canonical_ndjson_missing", "canonical_ndjson", None),
        ("canonical_ndjson_false", "canonical_ndjson", False),
        ("full_precision_missing", "full_precision", None),
        ("full_precision_false", "full_precision", False),
    ]
    artifact_rejected: list[str] = []
    for name, field, replacement in artifact_mutations:
        artifact = json.loads(json.dumps(controls[0][1]["trace_artifact"]))
        if replacement is None:
            artifact.pop(field)
        else:
            artifact[field] = replacement
        try:
            _validate_trace_artifact_identity(artifact, engine_id=ENGINE_IDS[0])
        except RouteEvaluationError:
            artifact_rejected.append(name)
    if (
        rejected != list(CONTRACT["negative_controls"]["terminal_population_mutations"])
        or artifact_rejected
        != list(CONTRACT["negative_controls"]["trace_artifact_mutations"])
    ):
        raise RouteEvaluationError("TURNING_ROUTE_PREFLIGHT_NEGATIVE_CONTROL_FAILED")
    if (
        CONTRACT.get("schema_version")
        != "sporespore_three_engine_turning_success_transport_route_v2"
        or CONTRACT.get("status") != "prospective_zero_world_only"
        or LEDGER_SCOPE
        != {
            "subsystem": "turning",
            "engine_scope": "3e",
            "authority_mode": "development_ghost",
            "question_class": "development",
        }
        or CONTROLLER_STEPS != 2
        or ENGINE_IDS != ("godot_jolt", "rapier_parry", "mujoco")
        or TRACE_TRANSPORT_ID
        != "sporespore_three_engine_turning_success_transport_v2"
        or TERMINAL_QUESTION_CLASS != "development"
    ):
        raise RouteEvaluationError("TURNING_ROUTE_CONTRACT_PREFLIGHT_INVALID")
    return {
        "schema_version": (
            "sporespore_three_engine_turning_success_transport_evaluator_"
            "preflight_v2"
        ),
        "route_id": ROUTE_ID,
        "ledger_scope": dict(LEDGER_SCOPE),
        "contract_raw_sha256": _sha256(CONTRACT_PATH.read_bytes()),
        "terminal_positive_control_count": len(controls),
        "terminal_negative_control_count": len(terminal_mutations),
        "artifact_negative_control_count": len(artifact_mutations),
        "negative_control_count": len(terminal_mutations) + len(artifact_mutations),
        "negative_controls_rejected": rejected,
        "artifact_negative_controls_rejected": artifact_rejected,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_behavior_thresholds_applied": False,
        "physical_acceptance_authority": False,
    }


def _arguments(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("preflight")
    retain = commands.add_parser("retain-trace")
    retain.add_argument("--engine-id", required=True)
    retain.add_argument("--cell-id", required=True)
    retain.add_argument("--rows-json", type=Path, required=True)
    retain.add_argument("--repo-root", type=Path, required=True)
    retain.add_argument("--attempt-root", type=Path, required=True)
    retain.add_argument("--powershell", required=True)
    retain.add_argument("--test-only", action="store_true")
    retain.add_argument("--evidence-root-override", type=Path)
    evaluate = commands.add_parser("evaluate-complete")
    evaluate.add_argument("--manifest", type=Path, required=True)
    evaluate.add_argument("--expected-source-commit", required=True)
    return parser.parse_args(argv)


def _manifest_paths(path: Path) -> list[Path]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise RouteEvaluationError("TURNING_ROUTE_MANIFEST_UNREADABLE") from error
    if not isinstance(value, list) or any(not isinstance(item, str) for item in value):
        raise RouteEvaluationError("TURNING_ROUTE_MANIFEST_INVALID")
    return [Path(item) for item in value]


def main(argv: Sequence[str] | None = None) -> int:
    arguments = _arguments(sys.argv[1:] if argv is None else argv)
    try:
        if arguments.command == "preflight":
            print(PREFLIGHT_MARKER + json.dumps(run_zero_world_preflight(), sort_keys=True))
        elif arguments.command == "retain-trace":
            value = retain_trace(
                engine_id=arguments.engine_id,
                cell_id=arguments.cell_id,
                rows_json_path=arguments.rows_json,
                repo_root=arguments.repo_root,
                attempt_root=arguments.attempt_root,
                powershell=arguments.powershell,
                test_only=arguments.test_only,
                evidence_root_override=arguments.evidence_root_override,
            )
            print(RETAINED_MARKER + json.dumps(value, sort_keys=True))
        else:
            paths = _manifest_paths(arguments.manifest)
            terminals = [json.loads(path.read_text(encoding="utf-8")) for path in paths]
            value = evaluate_complete_entries(
                terminals, expected_source_commit=arguments.expected_source_commit
            )
            print(EVALUATION_MARKER + json.dumps(value, sort_keys=True))
        return 0
    except (RouteEvaluationError, OSError, UnicodeError, json.JSONDecodeError) as error:
        print(f"SPORESPORE_TURNING_ROUTE_EVALUATOR_ERROR {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
