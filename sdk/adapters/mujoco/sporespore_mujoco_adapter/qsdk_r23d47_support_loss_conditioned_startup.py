"""Trace-retention repair MuJoCo worker for QSDK-R23D47.

R23D47 reuses the immutable R23D46 scientific candidate and physical loop.  It
validates media type at the CAS manifest, where the publisher actually records
it, and exercises that exact production retention route during zero-world.
"""

from __future__ import annotations

import argparse
import ast
import copy
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from types import SimpleNamespace
from typing import Any, Sequence
import uuid


SDK_ROOT = Path(__file__).resolve().parents[3]
REPO_ROOT = SDK_ROOT.parent
TURNING_ROOT = SDK_ROOT / "turning"
if str(TURNING_ROOT) not in sys.path:
    sys.path.insert(0, str(TURNING_ROOT))

from . import qsdk_r23d45_support_loss_conditioned_startup as parent  # noqa: E402

import r23d47_support_loss_conditioned_startup as design  # noqa: E402


_core = parent._core
PREREGISTRATION_PATH = (
    TURNING_ROOT / "r23d47_support_loss_conditioned_startup_preregistration_v1.json"
)
IMPLEMENTATION_PATH = (
    TURNING_ROOT / "r23d47_support_loss_conditioned_startup_implementation_v1.json"
)
CLOSURE_PATH = (
    TURNING_ROOT / "r23d47_support_loss_conditioned_startup_closure_v1.json"
)
PARENT_CLOSURE_PATH = (
    TURNING_ROOT / "r23d46_support_loss_conditioned_startup_closure_v1.json"
)
INHERITED_PHYSICAL_WORKER_PATH = (
    Path(__file__).resolve().parent / "qsdk_r23d3_phase_balanced.py"
)
WORKER_PATH = Path(__file__).resolve()
ATTEMPT_PATH_ENV = "SPORESPORE_QSDK_R23D47_ATTEMPT"
ATTEMPT_ROOT_ENV = "SPORESPORE_QSDK_R23D47_ATTEMPT_ROOT"
TOKEN_ENV = "SPORESPORE_QSDK_R23D47_TOKEN"
POWERSHELL_ENV = "SPORESPORE_QSDK_R23D47_POWERSHELL"
ATTEMPT_SCHEMA = "sporespore_qsdk_r23d47_development_attempt_v1"
REPORT_SCHEMA = "sporespore_qsdk_r23d47_mujoco_development_report_v1"
FAILURE_SCHEMA = "sporespore_qsdk_r23d47_mujoco_development_failure_v1"
ENGINE_ID = design.ENGINE_ID
FALSE_CLAIMS = copy.deepcopy(parent.FALSE_CLAIMS)
EXPECTED_INHERITED_DESIGN_DEPENDENCIES = {
    "ACTUATOR_COUNT",
    "CAMPAIGN_ID",
    "CONTROLLER_STEPS",
    "Cell",
    "GAIT_CYCLE_STEPS",
    "GATE_ID",
    "LIMB_IDS",
    "PHASE_OFFSETS",
    "TRACE_ROW_SCHEMA",
    "TURN_DURATION_STEPS",
    "expected_segment_counts",
    "segment_for_step",
    "stage_a_cells",
    "stage_b_cells",
}


def _raw_sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def _read_json(path: Path, code: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise _core.R23D3MujocoError(code) from error
    if not isinstance(value, dict):
        raise _core.R23D3MujocoError(code)
    return value


def _contract() -> dict[str, Any]:
    if CLOSURE_PATH.is_file():
        raise _core.R23D3MujocoError("QSDK_R23D47_MJC_CLOSED")
    declaration = _read_json(
        PREREGISTRATION_PATH,
        "QSDK_R23D47_MJC_DECLARATION_UNREADABLE",
    )
    implementation = _read_json(
        IMPLEMENTATION_PATH,
        "QSDK_R23D47_MJC_IMPLEMENTATION_UNREADABLE",
    )
    parent_closure = declaration.get("immutable_parent_closure")
    change = declaration.get("sole_implementation_change")
    retention = implementation.get("retention_repair")
    candidate = declaration.get("candidate")
    matrix = declaration.get("matrix")
    invalid = (
        declaration.get("campaign_id") != design.CAMPAIGN_ID
        or declaration.get("gate_id") != design.GATE_ID
        or declaration.get("status")
        != "prospective_frozen_before_first_r23d47_world"
        or implementation.get("campaign_id") != design.CAMPAIGN_ID
        or implementation.get("gate_id") != design.GATE_ID
        or implementation.get("status") != "implemented_dormant_zero_world_only"
        or not isinstance(parent_closure, dict)
        or not isinstance(change, dict)
        or not isinstance(retention, dict)
        or not isinstance(candidate, dict)
        or not isinstance(matrix, dict)
        or parent_closure.get("path")
        != "sdk/turning/r23d46_support_loss_conditioned_startup_closure_v1.json"
        or parent_closure.get("raw_sha256") != _raw_sha256(PARENT_CLOSURE_PATH)
        or parent_closure.get("classification")
        != "invalid_complete_support_loss_conditioned_startup"
        or parent_closure.get("closed_identity_rerun_permitted") is not False
        or change.get("exact_production_retention_path_synthetic_preflight_required")
        is not True
        or change.get("synthetic_preflight_trace_row_count")
        != design.CONTROLLER_STEPS
        or change.get("controller_changed") is not False
        or change.get("startup_transform_changed") is not False
        or change.get("fixture_changed") is not False
        or change.get("seed_changed") is not False
        or change.get("horizon_changed") is not False
        or change.get("measurement_changed") is not False
        or change.get("physical_gate_changed") is not False
        or retention.get("raw_receipt_media_type_required") is not False
        or retention.get("cas_manifest_media_type_required")
        != "application/x-ndjson"
        or retention.get("receipt_and_manifest_identity_must_match_source_bytes")
        is not True
        or retention.get("exact_production_publisher_exercised_in_zero_world")
        is not True
        or retention.get("synthetic_trace_row_count") != design.CONTROLLER_STEPS
        or retention.get("receipt_mutation_negative_control_count") != 2
        or retention.get("scientific_candidate_changed") is not False
        or candidate.get("startup_transform_id") != design.STARTUP_TRANSFORM_ID
        or candidate.get("probe_last_semantic_step")
        != design.PROBE_LAST_SEMANTIC_STEP
        or candidate.get("engine_identity_input_count") != 0
        or candidate.get("arm_identity_input_count") != 0
        or matrix.get("declared_world_count") != 1
        or matrix.get("seed") != design.CAMPAIGN_SEED
        or matrix.get("controller_step_count") != design.CONTROLLER_STEPS
    )
    if invalid:
        raise _core.R23D3MujocoError("QSDK_R23D47_MJC_DECLARATION_INVALID")
    return declaration


def _cell(stage_id: str, onset_id: str, arm_id: str) -> design.Cell:
    if onset_id != "onset_600":
        raise _core.R23D3MujocoError(
            f"QSDK_R23D47_MJC_ONSET_INVALID:{onset_id}"
        )
    try:
        return design.cell(stage_id, ENGINE_ID, arm_id)
    except design.StartupTransformError as error:
        raise _core.R23D3MujocoError(str(error)) from error


def _physical_authorization(item: design.Cell, source_commit: str) -> dict[str, Any]:
    attempt_path = Path(os.environ.get(ATTEMPT_PATH_ENV, ""))
    attempt_root = Path(os.environ.get(ATTEMPT_ROOT_ENV, ""))
    token = os.environ.get(TOKEN_ENV, "")
    if (
        not attempt_path.is_file()
        or not attempt_root.is_dir()
        or len(token) != 32
        or any(character not in "0123456789abcdef" for character in token)
    ):
        raise _core.R23D3MujocoError("QSDK_R23D47_MJC_AUTHORIZATION_REQUIRED")
    attempt = _read_json(attempt_path, "QSDK_R23D47_MJC_ATTEMPT_UNREADABLE")
    evidence_root = (REPO_ROOT.parent / "SporeSpore_Evidence").resolve()
    try:
        attempt_root.resolve().relative_to(evidence_root)
    except ValueError as error:
        raise _core.R23D3MujocoError(
            "QSDK_R23D47_MJC_ATTEMPT_ROOT_NOT_DURABLE"
        ) from error
    invalid = (
        attempt.get("schema_version") != ATTEMPT_SCHEMA
        or attempt.get("campaign_id") != design.CAMPAIGN_ID
        or attempt.get("gate_id") != design.GATE_ID
        or attempt.get("status") != "identity_consumed_before_first_world"
        or attempt.get("source_commit") != source_commit
        or attempt.get("authorization_token") != token
        or attempt.get("cell_id") != item.cell_id
        or Path(str(attempt.get("attempt_root", ""))).resolve()
        != attempt_root.resolve()
        or attempt.get("source_worktree_clean") is not True
        or attempt.get("source_matches_live_github_main") is not True
        or attempt.get("zero_world_preflight_passed") is not True
        or attempt.get("global_physical_lock_held") is not True
        or attempt.get("development_only") is not True
        or attempt.get("physical_acceptance_authority") is not False
    )
    if invalid:
        raise _core.R23D3MujocoError("QSDK_R23D47_MJC_AUTHORIZATION_INVALID")
    return {"attempt": attempt, "attempt_root": attempt_root}


def _inherited_design_dependencies() -> set[str]:
    tree = ast.parse(INHERITED_PHYSICAL_WORKER_PATH.read_text(encoding="utf-8"))
    return {
        node.attr
        for node in ast.walk(tree)
        if isinstance(node, ast.Attribute)
        and isinstance(node.value, ast.Name)
        and node.value.id == "design"
    }


def _inherited_runtime_interface_canary(core: parent._R23D45Core) -> dict[str, Any]:
    observed = _inherited_design_dependencies()
    missing = sorted(name for name in observed if not hasattr(design, name))
    if observed != EXPECTED_INHERITED_DESIGN_DEPENDENCIES or missing:
        raise _core.R23D3MujocoError(
            "QSDK_R23D47_MJC_INHERITED_DESIGN_INTERFACE_INVALID:"
            + ",".join(missing)
        )
    memory = core.balanced_wave_initial_memory()
    projected = _core._limb_phase(memory)
    expected = []
    offsets = dict(zip(design.LIMB_IDS, design.PHASE_OFFSETS, strict=True))
    for limb_id, limb in zip(
        design.LIMB_IDS,
        memory["ordered_limb_memory"],
        strict=True,
    ):
        gait_step = int(limb["gait_step"])
        expected.append(
            {
                "limb_id": limb_id,
                "gait_step": gait_step,
                "local_phase_step": (
                    gait_step + design.GAIT_CYCLE_STEPS - offsets[limb_id]
                )
                % design.GAIT_CYCLE_STEPS,
                "release_hold_step_count": int(limb["release_hold_step_count"]),
            }
        )
    incomplete = SimpleNamespace(
        **{
            name: getattr(design, name)
            for name in observed
            if name != "PHASE_OFFSETS"
        }
    )
    omitted_member_detected = any(
        not hasattr(incomplete, name) for name in observed
    )
    if projected != expected or not omitted_member_detected:
        raise _core.R23D3MujocoError(
            "QSDK_R23D47_MJC_INHERITED_LIMB_PHASE_CANARY_INVALID"
        )
    return {
        "inherited_worker_path": str(INHERITED_PHYSICAL_WORKER_PATH),
        "static_design_dependency_count": len(observed),
        "static_design_dependencies": sorted(observed),
        "missing_design_dependencies": missing,
        "phase_offsets": list(design.PHASE_OFFSETS),
        "limb_phase_projection": projected,
        "omitted_phase_offsets_negative_control_passed": True,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
    }


def _synthetic_trace_rows(item: design.Cell) -> list[dict[str, Any]]:
    governor = design.SupportLossConditionedStartup()
    rows: list[dict[str, Any]] = []
    for semantic_step in range(design.CONTROLLER_STEPS):
        support_count = (4, 4, 2, 0)[semantic_step] if semantic_step < 4 else 4
        contacts = {
            limb_id: index < support_count
            for index, limb_id in enumerate(design.LIMB_IDS)
        }
        receipt = governor.step(semantic_step, contacts)
        rows.append(
            {
                "schema_version": design.TRACE_ROW_SCHEMA,
                "cell_id": item.cell_id,
                "semantic_step": semantic_step,
                "segment_id": "reference_walk",
                "desired_heading_offset_rad": 0.0,
                "oracle_passed": True,
                "validated_portable_command_count": design.ACTUATOR_COUNT,
                "native_actuation_application_count": design.ACTUATOR_COUNT,
                "torso_ground_contact": False,
                "torso_height_m": 0.4,
                "torso_tilt_rad": 0.0,
                "torso_position_world_m": [semantic_step * 0.0001, 0.4, 0.0],
                "ordered_foot_contacts_before": contacts,
                "ordered_foot_contacts_after": contacts.copy(),
                **receipt,
                "startup_transform_residual_count": design.ACTUATOR_COUNT,
                "startup_transform_maximum_absolute_residual_rad_s": 0.0,
            }
        )
    return rows


def _parse_marker(text: str, prefix: str) -> dict[str, Any]:
    matches = [line[len(prefix) :] for line in text.splitlines() if line.startswith(prefix)]
    if len(matches) != 1:
        raise _core.R23D3MujocoError("QSDK_R23D47_MJC_TRACE_CAS_MARKER_INVALID")
    try:
        value = json.loads(matches[0])
    except json.JSONDecodeError as error:
        raise _core.R23D3MujocoError(
            "QSDK_R23D47_MJC_TRACE_CAS_RECEIPT_INVALID"
        ) from error
    if not isinstance(value, dict):
        raise _core.R23D3MujocoError("QSDK_R23D47_MJC_TRACE_CAS_RECEIPT_INVALID")
    return value


def _validate_publication_receipt(
    artifact: dict[str, Any],
    expected_sha256: str,
    expected_byte_length: int,
    *,
    manifest_override: dict[str, Any] | None = None,
) -> dict[str, Any]:
    try:
        payload = Path(str(artifact["payload_path"])).resolve()
        manifest_path = Path(str(artifact["manifest_path"])).resolve()
        expected_directory = (
            REPO_ROOT.parent
            / "SporeSpore_Evidence"
            / "artifacts"
            / "sha256"
            / expected_sha256.removeprefix("sha256:")
        ).resolve()
        manifest = (
            manifest_override
            if manifest_override is not None
            else json.loads(manifest_path.read_text(encoding="utf-8"))
        )
        raw = payload.read_bytes()
    except (KeyError, OSError, UnicodeError, json.JSONDecodeError) as error:
        raise _core.R23D3MujocoError(
            "QSDK_R23D47_MJC_TRACE_CAS_RECEIPT_INVALID"
        ) from error
    valid = (
        artifact.get("schema_version")
        == "sporespore_content_addressed_artifact_receipt_v1"
        and artifact.get("sha256") == expected_sha256
        and artifact.get("byte_length") == expected_byte_length
        and artifact.get("test_only") is False
        and artifact.get("physical_acceptance_authority") is False
        and payload == (expected_directory / "payload.bin").resolve()
        and manifest_path == (expected_directory / "manifest.json").resolve()
        and len(raw) == expected_byte_length
        and "sha256:" + hashlib.sha256(raw).hexdigest() == expected_sha256
        and isinstance(manifest, dict)
        and manifest.get("schema_version")
        == "sporespore_content_addressed_artifact_manifest_v1"
        and manifest.get("algorithm") == "sha256"
        and manifest.get("sha256") == expected_sha256
        and manifest.get("byte_length") == expected_byte_length
        and manifest.get("payload_name") == "payload.bin"
        and manifest.get("media_type") == "application/x-ndjson"
    )
    if not valid:
        raise _core.R23D3MujocoError("QSDK_R23D47_MJC_TRACE_CAS_RECEIPT_INVALID")
    result = copy.deepcopy(artifact)
    result["media_type"] = "application/x-ndjson"
    result["manifest_identity_verified"] = True
    return result


def _retain_trace(
    item: design.Cell,
    rows: list[dict[str, Any]],
    attempt_root: Path,
) -> dict[str, Any]:
    summary = parent.validate_trace(item.cell_id, rows)
    if summary.get("ok") is not True:
        raise _core.R23D3MujocoError(
            "QSDK_R23D47_MJC_TRACE_INVALID:"
            + ",".join(summary.get("failure_codes", [])[:8])
        )
    pending = attempt_root / "pending-traces"
    pending.mkdir(parents=True, exist_ok=True)
    rows_path = pending / f"{item.cell_id}.rows.ndjson"
    try:
        with rows_path.open("x", encoding="utf-8", newline="\n") as stream:
            for row in rows:
                stream.write(
                    json.dumps(
                        row,
                        allow_nan=False,
                        separators=(",", ":"),
                        sort_keys=True,
                    )
                    + "\n"
                )
    except FileExistsError as error:
        raise _core.R23D3MujocoError("QSDK_R23D47_MJC_TRACE_OUTPUT_EXISTS") from error
    raw = rows_path.read_bytes()
    digest = "sha256:" + hashlib.sha256(raw).hexdigest()
    process = subprocess.run(
        [
            os.environ.get(POWERSHELL_ENV, "pwsh"),
            "-NoProfile",
            "-File",
            str(SDK_ROOT / "publish_qsdk_r23d34_trace.ps1"),
            "-RepoRoot",
            str(REPO_ROOT),
            "-ArtifactPath",
            str(rows_path),
            "-ExpectedSha256",
            digest,
            "-ExpectedByteLength",
            str(len(raw)),
        ],
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if process.returncode != 0:
        raise _core.R23D3MujocoError(
            "QSDK_R23D47_MJC_TRACE_CAS_FAILED:"
            + process.stderr.strip().replace("\n", " ")[:500]
        )
    receipt = _parse_marker(process.stdout, "QSDK_R23D34_TRACE_CAS ")
    artifact = _validate_publication_receipt(receipt, digest, len(raw))
    return {"trace_artifact": artifact, "trace_summary": summary}


def _production_retention_canary(item: design.Cell) -> dict[str, Any]:
    rows = _synthetic_trace_rows(item)
    evidence_root = (REPO_ROOT.parent / "SporeSpore_Evidence").resolve()
    canary_parent = (evidence_root / "zero-world").resolve()
    canary_parent.mkdir(parents=True, exist_ok=True)
    canary_root = (
        canary_parent / f"qsdk-r23d47-retention-canary-{uuid.uuid4().hex}"
    ).resolve()
    if canary_root.parent != canary_parent or not canary_root.name.startswith(
        "qsdk-r23d47-retention-canary-"
    ):
        raise _core.R23D3MujocoError("QSDK_R23D47_MJC_CANARY_ROOT_INVALID")
    canary_root.mkdir()
    try:
        retained = _retain_trace(item, rows, canary_root)
        artifact = retained["trace_artifact"]
        summary = retained["trace_summary"]
        rejection_count = 0
        wrong_receipt = copy.deepcopy(artifact)
        wrong_receipt["sha256"] = "sha256:" + "0" * 64
        try:
            _validate_publication_receipt(
                wrong_receipt,
                str(artifact["sha256"]),
                int(artifact["byte_length"]),
            )
        except _core.R23D3MujocoError:
            rejection_count += 1
        manifest = json.loads(
            Path(str(artifact["manifest_path"])).read_text(encoding="utf-8")
        )
        wrong_manifest = copy.deepcopy(manifest)
        wrong_manifest["media_type"] = "application/json"
        try:
            _validate_publication_receipt(
                artifact,
                str(artifact["sha256"]),
                int(artifact["byte_length"]),
                manifest_override=wrong_manifest,
            )
        except _core.R23D3MujocoError:
            rejection_count += 1
        if rejection_count != 2:
            raise _core.R23D3MujocoError(
                "QSDK_R23D47_MJC_RETENTION_NEGATIVE_CONTROL_INVALID"
            )
        receipt = {
            "synthetic_trace_row_count": len(rows),
            "synthetic_trace_sha256": artifact["sha256"],
            "synthetic_trace_byte_length": artifact["byte_length"],
            "synthetic_trace_summary_ok": summary.get("ok") is True,
            "synthetic_trace_trigger_step": summary.get("startup_ramp_trigger_step"),
            "exact_production_publisher_invoked": True,
            "publisher_test_only": artifact.get("test_only"),
            "cas_manifest_media_type": artifact.get("media_type"),
            "cas_manifest_identity_verified": artifact.get(
                "manifest_identity_verified"
            ),
            "receipt_mutation_rejection_count": rejection_count,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
        }
    finally:
        if (
            canary_root.exists()
            and canary_root.parent == canary_parent
            and canary_root.name.startswith("qsdk-r23d47-retention-canary-")
        ):
            shutil.rmtree(canary_root)
    receipt["synthetic_source_cleaned_after_cas_publication"] = not canary_root.exists()
    return receipt


def run_preflight(stage_id: str, onset_id: str, arm_id: str) -> dict[str, Any]:
    _contract()
    item = _cell(stage_id, onset_id, arm_id)
    schedule = [
        design.segment_for_step(item, step)
        for step in range(design.CONTROLLER_STEPS)
    ]
    core = parent._R23D45Core()
    compiled, profile = parent._bound_base._compile_boundary(core)
    memory = core.balanced_wave_initial_memory()
    composition = parent._composition_canary(core)
    discovery = parent._retained_discovery_canary()
    trace = parent._synthetic_trace_canary(item)
    inherited_interface = _inherited_runtime_interface_canary(core)
    retention = _production_retention_canary(item)
    identity = design.SupportLossConditionedStartup()
    identity_scales = [
        identity.step(
            step,
            {limb_id: True for limb_id in design.LIMB_IDS},
        )["startup_velocity_scale"]
        for step in range(5)
    ]
    if (
        compiled.get("morphology_id") != design.MORPHOLOGY_ID
        or profile.get("policy_id") != design.POLICY_ID
        or memory.get("schema_version")
        != "sporespore_balanced_wave_persistent_predictive_guard_memory_v1"
        or len(schedule) != design.CONTROLLER_STEPS
        or any(segment != ("reference_walk", 0.0) for segment in schedule)
        or identity_scales != [1.0] * 5
    ):
        raise _core.R23D3MujocoError("QSDK_R23D47_MJC_PREFLIGHT_INVALID")
    return {
        "schema_version": "sporespore_qsdk_r23d47_mujoco_preflight_v1",
        "campaign_id": design.CAMPAIGN_ID,
        "gate_id": design.GATE_ID,
        "engine_id": ENGINE_ID,
        "stage_id": item.stage_id,
        "cell_id": item.cell_id,
        "arm_id": item.arm_id,
        "controller_policy_id": design.POLICY_ID,
        "startup_transform_id": design.STARTUP_TRANSFORM_ID,
        "engine_identity_input_count": 0,
        "arm_identity_input_count": 0,
        "support_loss_composition_canary": composition,
        "retained_discovery_dispatch_canary": discovery,
        "trace_validation_canary": trace,
        "inherited_runtime_interface_canary": inherited_interface,
        "production_retention_canary": retention,
        "identity_path_scale_canary": identity_scales,
        "fixed_controller_horizon_step_count": design.CONTROLLER_STEPS,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
    }


def run_authorization_preflight(
    stage_id: str,
    onset_id: str,
    arm_id: str,
    source_commit: str,
) -> dict[str, Any]:
    _contract()
    item = _cell(stage_id, onset_id, arm_id)
    authorization = _physical_authorization(item, source_commit)
    return {
        "schema_version": "sporespore_qsdk_r23d47_authorization_preflight_v1",
        "campaign_id": design.CAMPAIGN_ID,
        "gate_id": design.GATE_ID,
        "source_commit": source_commit,
        "cell_id": item.cell_id,
        "attempt_root": str(authorization["attempt_root"].resolve()),
        "authorization_passed": True,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
    }


# The inherited worker resolves these names at call time.  Rebind the complete
# runtime surface before any preflight or physical entry point can execute.
parent.design = design
parent._contract = _contract
for name, value in {
    "design": design,
    "evaluator": SimpleNamespace(FALSE_CLAIMS=FALSE_CLAIMS),
    "base": parent._bound_base,
    "LocomotionCore": parent._R23D45Core,
    "PREREGISTRATION_PATH": PREREGISTRATION_PATH,
    "PHYSICAL_EVALUATOR_PATH": str(WORKER_PATH),
    "CLOSURE_PATH": CLOSURE_PATH,
    "WORKER_PATH": WORKER_PATH,
    "CAMPAIGN_ID": design.CAMPAIGN_ID,
    "GATE_ID": design.GATE_ID,
    "REPORT_SCHEMA": REPORT_SCHEMA,
    "FAILURE_SCHEMA": FAILURE_SCHEMA,
    "SCHEDULE_ID": "qsdk_r23d47_reference_walk_v1",
    "CONTROLLER_STEPS": design.CONTROLLER_STEPS,
    "ACTUATOR_COUNT": design.ACTUATOR_COUNT,
    "TURN_DURATION_STEPS": design.TURN_DURATION_STEPS,
    "TERMINAL_SETTLE_STEPS": 0,
    "_cell": _cell,
    "_contract": _contract,
    "_physical_authorization": _physical_authorization,
    "_retain_trace": _retain_trace,
}.items():
    setattr(_core, name, value)
_core.run_preflight = run_preflight


def run_physical(
    stage_id: str,
    onset_id: str,
    arm_id: str,
    source_commit: str,
) -> dict[str, Any]:
    report = parent.run_physical(stage_id, onset_id, arm_id, source_commit)
    report["implementation_repair"] = {
        "parent_gate_id": "QSDK-R23D46",
        "repair": "validate_media_type_at_content_addressed_manifest",
        "production_retention_preflight_row_count": design.CONTROLLER_STEPS,
        "scientific_candidate_changed": False,
        "physical_acceptance_authority": False,
    }
    json.dumps(report, allow_nan=False)
    return report


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "command",
        choices=("preflight", "authorization-preflight", "physical"),
    )
    parser.add_argument("--stage", required=True)
    parser.add_argument("--onset", default="onset_600")
    parser.add_argument("--arm", required=True)
    parser.add_argument("--source-commit", default="")
    args = parser.parse_args(argv)
    try:
        if args.command == "preflight":
            value = run_preflight(args.stage, args.onset, args.arm)
            marker = "QSDK_R23D47_MUJOCO_PREFLIGHT "
        elif args.command == "authorization-preflight":
            value = run_authorization_preflight(
                args.stage,
                args.onset,
                args.arm,
                args.source_commit,
            )
            marker = "QSDK_R23D47_AUTHORIZATION_PREFLIGHT "
        else:
            value = run_physical(
                args.stage,
                args.onset,
                args.arm,
                args.source_commit,
            )
            marker = "QSDK_R23D47_MUJOCO_TERMINAL "
        print(
            marker
            + json.dumps(
                value,
                allow_nan=False,
                separators=(",", ":"),
                sort_keys=True,
            )
        )
        return 0
    except _core.R23D3MujocoError as error:
        if args.command == "authorization-preflight":
            value = {
                "schema_version": (
                    "sporespore_qsdk_r23d47_authorization_preflight_failure_v1"
                ),
                "campaign_id": design.CAMPAIGN_ID,
                "gate_id": design.GATE_ID,
                "failure_code": error.code,
                "authorization_passed": False,
                "model_construction_count": 0,
                "world_attempt_count": 0,
                "world_build_count": 0,
                "physical_acceptance_authority": False,
            }
            print(
                "QSDK_R23D47_AUTHORIZATION_FAILURE "
                + json.dumps(value, allow_nan=False, separators=(",", ":"), sort_keys=True)
            )
            return 1
        value = error.terminal_receipt or {"failure_code": error.code}
        print(
            "QSDK_R23D47_MUJOCO_TERMINAL "
            + json.dumps(value, allow_nan=False, separators=(",", ":"), sort_keys=True)
        )
        return 1
    except Exception as error:
        print(
            "QSDK_R23D47_MUJOCO_FAILURE "
            + json.dumps(
                {"failure_code": f"{type(error).__name__}:{error}"},
                allow_nan=False,
                separators=(",", ":"),
                sort_keys=True,
            )
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
