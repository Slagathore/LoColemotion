"""One-world MuJoCo development worker for QSDK-R23D45.

The worker reuses the accepted R23D3 fixed-horizon real-physics loop without
editing any consumed predecessor.  A stateful transform observes only the four
portable foot-contact booleans captured before command composition.  It either
keeps the canonical velocity command unchanged or latches the frozen one-cycle
smoothstep ramp.  Every decision is included in the retained trace.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import sys
from types import ModuleType, SimpleNamespace
from typing import Any, Mapping, Sequence

from sporespore_locomotion import LocomotionCore, LocomotionCoreError


SDK_ROOT = Path(__file__).resolve().parents[3]
REPO_ROOT = SDK_ROOT.parent
TURNING_ROOT = SDK_ROOT / "turning"
if str(TURNING_ROOT) not in sys.path:
    sys.path.insert(0, str(TURNING_ROOT))

from . import qsdk_r23d2_heading_response as inherited_base  # noqa: E402
from . import qsdk_r23d38_startup_ramp_stabilization as inherited_worker  # noqa: E402

import r23d45_support_loss_conditioned_startup as design  # noqa: E402


_core = inherited_worker._core
_INHERITED_TRACE_ROW = inherited_worker._INHERITED_TRACE_ROW
PREREGISTRATION_PATH = (
    TURNING_ROOT / "r23d45_support_loss_conditioned_startup_preregistration_v1.json"
)
IMPLEMENTATION_PATH = (
    TURNING_ROOT / "r23d45_support_loss_conditioned_startup_implementation_v1.json"
)
CLOSURE_PATH = (
    TURNING_ROOT / "r23d45_support_loss_conditioned_startup_closure_v1.json"
)
WORKER_PATH = Path(__file__).resolve()
ATTEMPT_PATH_ENV = "SPORESPORE_QSDK_R23D45_ATTEMPT"
ATTEMPT_ROOT_ENV = "SPORESPORE_QSDK_R23D45_ATTEMPT_ROOT"
TOKEN_ENV = "SPORESPORE_QSDK_R23D45_TOKEN"
PYTHON_ENV = "SPORESPORE_QSDK_R23D45_PYTHON"
POWERSHELL_ENV = "SPORESPORE_QSDK_R23D45_POWERSHELL"
REPORT_SCHEMA = "sporespore_qsdk_r23d45_mujoco_development_report_v1"
FAILURE_SCHEMA = "sporespore_qsdk_r23d45_mujoco_development_failure_v1"
ATTEMPT_SCHEMA = "sporespore_qsdk_r23d45_development_attempt_v1"
ENGINE_ID = design.ENGINE_ID
FALSE_CLAIMS = {
    "startup_mechanism_positive": False,
    "turning_tested": False,
    "portable_turning": False,
    "finite_three_engine_turning": False,
    "cross_engine_equivalence": False,
    "population_robustness": False,
    "prone_to_standing": False,
    "release_authorized": False,
    "physical_acceptance_authority": False,
}


class _GovernorRun:
    """Bind one support observation and one transform receipt to every step."""

    def __init__(self) -> None:
        self.reset()

    def reset(self) -> None:
        self.governor = design.SupportLossConditionedStartup()
        self.pending_contacts: dict[int, dict[str, bool]] = {}
        self.rows: dict[int, dict[str, Any]] = {}
        self.composition_step_count = 0
        self.ramped_step_count = 0
        self.exact_zero_scale_step_count = 0
        self.exact_unity_scale_step_count = 0
        self.maximum_absolute_residual_rad_s = 0.0

    def capture_contacts(
        self,
        semantic_step: int,
        contacts: Mapping[str, bool],
    ) -> None:
        if semantic_step in self.pending_contacts or semantic_step in self.rows:
            raise RuntimeError("QSDK_R23D45_CONTACT_CAPTURE_DUPLICATE")
        self.pending_contacts[semantic_step] = {
            limb_id: contacts[limb_id] for limb_id in design.LIMB_IDS
        }

    def compose(self, actuation: dict[str, Any]) -> list[dict[str, Any]]:
        semantic_step = int(actuation.get("semantic_step", -1))
        commands = actuation.get("ordered_commands")
        try:
            contacts = self.pending_contacts.pop(semantic_step)
        except KeyError as error:
            raise RuntimeError("QSDK_R23D45_CONTACT_CAPTURE_MISSING") from error
        if (
            semantic_step in self.rows
            or not isinstance(commands, list)
            or len(commands) != design.ACTUATOR_COUNT
        ):
            raise RuntimeError("QSDK_R23D45_TRANSFORM_STEP_BINDING_INVALID")

        receipt = self.governor.step(semantic_step, contacts)
        scale = float(receipt["startup_velocity_scale"])
        residuals: list[dict[str, Any]] = []
        maximum = 0.0
        for command in commands:
            actuator_id = command.get("actuator_id")
            legacy_velocity = float(command.get("target_velocity_rad_s", math.nan))
            portable_canonical = -legacy_velocity
            delta = portable_canonical * (scale - 1.0)
            if not isinstance(actuator_id, str) or not all(
                math.isfinite(value) for value in (legacy_velocity, delta)
            ):
                raise RuntimeError("QSDK_R23D45_TRANSFORM_NONFINITE")
            maximum = max(maximum, abs(delta))
            residuals.append(
                {
                    "schema_version": "sporespore_canonical_velocity_residual_v1",
                    "actuator_id": actuator_id,
                    "canonical_velocity_delta_rad_s": delta,
                    "command_not_measurement": True,
                    "physical_acceptance_authority": False,
                }
            )

        receipt.update(
            {
                "startup_transform_residual_count": len(residuals),
                "startup_transform_maximum_absolute_residual_rad_s": maximum,
            }
        )
        self.rows[semantic_step] = receipt
        self.composition_step_count += 1
        self.ramped_step_count += int(bool(receipt["startup_ramp_active"]))
        self.exact_zero_scale_step_count += int(scale == 0.0)
        self.exact_unity_scale_step_count += int(scale == 1.0)
        self.maximum_absolute_residual_rad_s = max(
            self.maximum_absolute_residual_rad_s,
            maximum,
        )
        return residuals

    def trace_fields(self, semantic_step: int) -> dict[str, Any]:
        try:
            return self.rows.pop(semantic_step)
        except KeyError as error:
            raise RuntimeError("QSDK_R23D45_TRANSFORM_TRACE_BINDING_INVALID") from error

    def summary(self) -> dict[str, Any]:
        trigger_step = self.governor.trigger_step
        return {
            "startup_transform_id": design.STARTUP_TRANSFORM_ID,
            "startup_probe_last_semantic_step": design.PROBE_LAST_SEMANTIC_STEP,
            "startup_ramp_triggered": trigger_step is not None,
            "startup_ramp_trigger_step": trigger_step,
            "startup_probe_minimum_support_count": (
                self.governor.minimum_probe_support_count
            ),
            "startup_transform_composition_step_count": self.composition_step_count,
            "startup_ramp_active_step_count": self.ramped_step_count,
            "startup_ramp_exact_zero_scale_step_count": (
                self.exact_zero_scale_step_count
            ),
            "startup_ramp_exact_unity_scale_step_count": (
                self.exact_unity_scale_step_count
            ),
            "maximum_absolute_startup_transform_residual_rad_s": (
                self.maximum_absolute_residual_rad_s
            ),
            "startup_transform_composition_integrity_passed": (
                not self.pending_contacts
                and not self.rows
                and self.composition_step_count == design.CONTROLLER_STEPS
            ),
        }


_RUN = _GovernorRun()


class _R23D45Core(LocomotionCore):
    def balanced_wave_initial_memory(self) -> dict[str, Any]:
        return self.balanced_wave_policy_initial_memory(
            design.POLICY_ID,
            inherited_base.bridge.s169_descriptor(),
        )


class _BridgeBound:
    def __init__(self, bridge: ModuleType) -> None:
        self._bridge = bridge

    def __getattr__(self, name: str) -> Any:
        return getattr(self._bridge, name)

    def MujocoBw19vRobot(self, core: LocomotionCore, profile_id: str) -> Any:
        robot = self._bridge.MujocoBw19vRobot(core, profile_id)
        _RUN.reset()
        return robot


class _PolicyBoundBase:
    POLICY_ID = design.POLICY_ID
    CAMPAIGN_SEED = design.CAMPAIGN_SEED

    def __init__(self, base: ModuleType) -> None:
        self._base = base
        self.bridge = _BridgeBound(base.bridge)

    def __getattr__(self, name: str) -> Any:
        return getattr(self._base, name)

    def _compile_boundary(
        self,
        core: LocomotionCore,
    ) -> tuple[dict[str, Any], dict[str, Any]]:
        return self._base._compile_boundary(core, policy_id=design.POLICY_ID)

    def _initial_perturbation(self, _development: dict[str, Any]) -> dict[str, Any]:
        return copy.deepcopy(design.INITIAL_PERTURBATION)

    def _state_frame(
        self,
        robot: Any,
        semantic_step: int,
        task_origin: Any,
        reference_heading_rad: float,
    ) -> dict[str, Any]:
        state = self._base._state_frame(
            robot,
            semantic_step,
            task_origin,
            reference_heading_rad,
        )
        _RUN.capture_contacts(semantic_step, self._base._foot_contacts(robot))
        return state

    def _zero_residuals(self, actuation: dict[str, Any]) -> list[dict[str, Any]]:
        return _RUN.compose(actuation)


_bound_base = _PolicyBoundBase(inherited_base)


def _cell(stage_id: str, onset_id: str, arm_id: str) -> design.Cell:
    if onset_id != "onset_600":
        raise _core.R23D3MujocoError(
            f"QSDK_R23D45_MJC_ONSET_INVALID:{onset_id}"
        )
    try:
        return design.cell(stage_id, ENGINE_ID, arm_id)
    except design.StartupTransformError as error:
        raise _core.R23D3MujocoError(str(error)) from error


def _read_json(path: Path, code: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise _core.R23D3MujocoError(code) from error
    if not isinstance(value, dict):
        raise _core.R23D3MujocoError(code)
    return value


def _raw_sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def _contract() -> dict[str, Any]:
    if CLOSURE_PATH.is_file():
        raise _core.R23D3MujocoError("QSDK_R23D45_MJC_CLOSED")
    declaration = _read_json(
        PREREGISTRATION_PATH,
        "QSDK_R23D45_MJC_DECLARATION_UNREADABLE",
    )
    parents = declaration.get("immutable_parent_closures")
    candidate = declaration.get("candidate")
    matrix = declaration.get("matrix")
    invalid = (
        declaration.get("campaign_id") != design.CAMPAIGN_ID
        or declaration.get("gate_id") != design.GATE_ID
        or declaration.get("status")
        != "prospective_frozen_before_first_r23d45_world"
        or not isinstance(parents, dict)
        or not isinstance(candidate, dict)
        or not isinstance(matrix, dict)
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
        raise _core.R23D3MujocoError("QSDK_R23D45_MJC_DECLARATION_INVALID")
    for prefix in ("r23d34", "r23d35", "r23d38", "r23d44"):
        path = REPO_ROOT / str(parents.get(f"{prefix}_path", ""))
        if (
            not path.is_file()
            or parents.get(f"{prefix}_raw_sha256") != _raw_sha256(path)
        ):
            raise _core.R23D3MujocoError(
                f"QSDK_R23D45_MJC_PARENT_INVALID:{prefix}"
            )
    return declaration


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
        raise _core.R23D3MujocoError("QSDK_R23D45_MJC_AUTHORIZATION_REQUIRED")
    attempt = _read_json(attempt_path, "QSDK_R23D45_MJC_ATTEMPT_UNREADABLE")
    evidence_root = (REPO_ROOT.parent / "SporeSpore_Evidence").resolve()
    try:
        attempt_root.resolve().relative_to(evidence_root)
    except ValueError as error:
        raise _core.R23D3MujocoError(
            "QSDK_R23D45_MJC_ATTEMPT_ROOT_NOT_DURABLE"
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
        raise _core.R23D3MujocoError("QSDK_R23D45_MJC_AUTHORIZATION_INVALID")
    return {"attempt": attempt, "attempt_root": attempt_root}


def _contact_map(value: Any) -> bool:
    return (
        isinstance(value, dict)
        and set(value) == set(design.LIMB_IDS)
        and all(type(value[limb_id]) is bool for limb_id in design.LIMB_IDS)
    )


def _finite(value: Any) -> bool:
    return (
        not isinstance(value, bool)
        and isinstance(value, (int, float))
        and math.isfinite(float(value))
    )


def validate_trace(cell_id: str, rows: Any) -> dict[str, Any]:
    failures: list[str] = []
    if not isinstance(rows, list) or len(rows) != design.CONTROLLER_STEPS:
        return {
            "ok": False,
            "row_count": len(rows) if isinstance(rows, list) else 0,
            "failure_codes": ["R23D45_TRACE_ROW_COUNT"],
        }
    governor = design.SupportLossConditionedStartup()
    active_count = 0
    exact_zero_count = 0
    exact_unity_count = 0
    for semantic_step, row in enumerate(rows):
        if not isinstance(row, dict):
            failures.append(f"R23D45_TRACE_ROW_TYPE:{semantic_step}")
            continue
        contacts_before = row.get("ordered_foot_contacts_before")
        contacts_after = row.get("ordered_foot_contacts_after")
        if not _contact_map(contacts_before) or not _contact_map(contacts_after):
            failures.append(f"R23D45_TRACE_CONTACTS:{semantic_step}")
            continue
        expected = governor.step(semantic_step, contacts_before)
        observed_scale = row.get("startup_velocity_scale")
        base_valid = (
            row.get("schema_version") == design.TRACE_ROW_SCHEMA
            and row.get("cell_id") == cell_id
            and row.get("semantic_step") == semantic_step
            and row.get("segment_id") == "reference_walk"
            and row.get("desired_heading_offset_rad") == 0.0
            and row.get("oracle_passed") is True
            and row.get("validated_portable_command_count") == design.ACTUATOR_COUNT
            and row.get("native_actuation_application_count")
            == design.ACTUATOR_COUNT
            and type(row.get("torso_ground_contact")) is bool
            and _finite(row.get("torso_height_m"))
            and _finite(row.get("torso_tilt_rad"))
            and isinstance(row.get("torso_position_world_m"), list)
            and len(row["torso_position_world_m"]) == 3
            and all(_finite(value) for value in row["torso_position_world_m"])
        )
        transform_valid = (
            _finite(observed_scale)
            and abs(float(observed_scale) - float(expected["startup_velocity_scale"]))
            <= 1.0e-15
            and all(row.get(key) == value for key, value in expected.items())
            and row.get("startup_transform_residual_count")
            == design.ACTUATOR_COUNT
            and _finite(
                row.get("startup_transform_maximum_absolute_residual_rad_s")
            )
            and float(
                row.get("startup_transform_maximum_absolute_residual_rad_s", -1.0)
            )
            >= 0.0
        )
        if not base_valid:
            failures.append(f"R23D45_TRACE_BASE_INVALID:{semantic_step}")
        if not transform_valid:
            failures.append(f"R23D45_TRACE_TRANSFORM_INVALID:{semantic_step}")
        if _finite(observed_scale):
            scale = float(observed_scale)
            active_count += int(row.get("startup_ramp_active") is True)
            exact_zero_count += int(scale == 0.0)
            exact_unity_count += int(scale == 1.0)
    return {
        "schema_version": "sporespore_qsdk_r23d45_trace_summary_v1",
        "cell_id": cell_id,
        "ok": not failures,
        "row_count": len(rows),
        "failure_codes": failures[:32],
        "startup_ramp_triggered": governor.trigger_step is not None,
        "startup_ramp_trigger_step": governor.trigger_step,
        "startup_probe_minimum_support_count": governor.minimum_probe_support_count,
        "startup_ramp_active_step_count": active_count,
        "startup_ramp_exact_zero_scale_step_count": exact_zero_count,
        "startup_ramp_exact_unity_scale_step_count": exact_unity_count,
        "physical_acceptance_authority": False,
    }


def _synthetic_trace_canary(item: design.Cell) -> dict[str, Any]:
    governor = design.SupportLossConditionedStartup()
    rows: list[dict[str, Any]] = []
    for semantic_step in range(design.CONTROLLER_STEPS):
        support_count = (4, 4, 2, 0)[semantic_step] if semantic_step < 4 else 4
        contacts_before = {
            limb_id: index < support_count
            for index, limb_id in enumerate(design.LIMB_IDS)
        }
        receipt = governor.step(semantic_step, contacts_before)
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
                "ordered_foot_contacts_before": contacts_before,
                "ordered_foot_contacts_after": contacts_before.copy(),
                **receipt,
                "startup_transform_residual_count": design.ACTUATOR_COUNT,
                "startup_transform_maximum_absolute_residual_rad_s": 0.0,
            }
        )
    valid = validate_trace(item.cell_id, rows)
    original_scale = rows[3]["startup_velocity_scale"]
    rows[3]["startup_velocity_scale"] = 0.25
    scale_mutation = validate_trace(item.cell_id, rows)
    rows[3]["startup_velocity_scale"] = original_scale
    original_identity = rows[4]["startup_transform_id"]
    rows[4]["startup_transform_id"] = "wrong"
    identity_mutation = validate_trace(item.cell_id, rows)
    rows[4]["startup_transform_id"] = original_identity
    original_contacts = rows[3]["ordered_foot_contacts_before"]
    rows[3]["ordered_foot_contacts_before"] = {
        limb_id: True for limb_id in design.LIMB_IDS
    }
    contact_mutation = validate_trace(item.cell_id, rows)
    rows[3]["ordered_foot_contacts_before"] = original_contacts
    if (
        valid.get("ok") is not True
        or scale_mutation.get("ok") is not False
        or identity_mutation.get("ok") is not False
        or contact_mutation.get("ok") is not False
    ):
        raise _core.R23D3MujocoError("QSDK_R23D45_TRACE_CANARY_INVALID")
    return {
        "valid_trace_row_count": valid["row_count"],
        "valid_trace_trigger_step": valid["startup_ramp_trigger_step"],
        "trace_mutation_rejection_count": 3,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
    }


def _parse_marker(text: str, prefix: str) -> dict[str, Any]:
    matches = [line[len(prefix) :] for line in text.splitlines() if line.startswith(prefix)]
    if len(matches) != 1:
        raise RuntimeError("QSDK_R23D45_TRACE_CAS_MARKER_INVALID")
    value = json.loads(matches[0])
    if not isinstance(value, dict):
        raise RuntimeError("QSDK_R23D45_TRACE_CAS_RECEIPT_INVALID")
    return value


def _retain_trace(
    item: design.Cell,
    rows: list[dict[str, Any]],
    attempt_root: Path,
) -> dict[str, Any]:
    summary = validate_trace(item.cell_id, rows)
    if summary.get("ok") is not True:
        raise _core.R23D3MujocoError(
            "QSDK_R23D45_MJC_TRACE_INVALID:"
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
        raise _core.R23D3MujocoError("QSDK_R23D45_MJC_TRACE_OUTPUT_EXISTS") from error
    raw = rows_path.read_bytes()
    digest = "sha256:" + hashlib.sha256(raw).hexdigest()
    powershell = os.environ.get(POWERSHELL_ENV, "pwsh")
    process = subprocess.run(
        [
            powershell,
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
            "QSDK_R23D45_MJC_TRACE_CAS_FAILED:"
            + process.stderr.strip().replace("\n", " ")[:500]
        )
    artifact = _parse_marker(process.stdout, "QSDK_R23D34_TRACE_CAS ")
    if (
        artifact.get("sha256") != digest
        or artifact.get("byte_length") != len(raw)
        or artifact.get("media_type") != "application/x-ndjson"
        or artifact.get("physical_acceptance_authority") is not False
    ):
        raise _core.R23D3MujocoError("QSDK_R23D45_MJC_TRACE_CAS_RECEIPT_INVALID")
    return {"trace_artifact": artifact, "trace_summary": summary}


def _composition_canary(core: LocomotionCore) -> dict[str, Any]:
    descriptor = inherited_base.bridge.s169_descriptor()
    compiled, _profile = _bound_base._compile_boundary(core)
    state = inherited_base._state_for_canary(
        compiled,
        {
            "task_lateral_axis_world_unit": [0.0, 0.0, 1.0],
            "base_position_world_m": [0.0, 0.5, 0.0],
            "measured_heading_world_rad": 0.0,
            "base_linear_velocity_world_m_s": [0.0, 0.0, 0.0],
            "task_origin_world_m": [0.0, 0.5, 0.0],
            "reference_yaw_rad": 0.0,
        },
    )
    memory = core.balanced_wave_policy_initial_memory(design.POLICY_ID, descriptor)
    local = _GovernorRun()
    selected_steps = (0, 1, 2, 3, 4, 182, 361, 362)
    selected_scales: list[float] = []
    last_actuation: dict[str, Any] | None = None
    last_residuals: list[dict[str, Any]] | None = None
    for semantic_step in range(selected_steps[-1] + 1):
        state["semantic_step"] = semantic_step
        state["sample_time_s"] = semantic_step / 120.0
        command = {
            "schema_version": "sporespore_motion_command_v2",
            "command_id": f"qsdk_r23d45_zero_world_{semantic_step}",
            "desired_planar_velocity_task_m_s": {"x": 0.2, "y": 0.0, "z": 0.0},
            "desired_heading_rad": 0.0,
            "desired_yaw_rate_rad_s": None,
            "gait_family_id": "lateral_wave",
            "speed_class": "walk",
            "gait_amplitude": 1.0,
            "phase_progression_mode": "clocked",
            "valid_from_step": semantic_step,
            "valid_through_step": semantic_step,
            "authority": "test_fixture",
        }
        output = LocomotionCore.balanced_wave_policy_step(
            core,
            design.POLICY_ID,
            {
                "descriptor": descriptor,
                "memory": memory,
                "state": state,
                "command": command,
            },
        )
        memory = output["next_memory"]
        actuation = output["actuation"]
        support_count = (4, 4, 2, 0)[semantic_step] if semantic_step < 4 else 4
        contacts = {
            limb_id: index < support_count
            for index, limb_id in enumerate(design.LIMB_IDS)
        }
        local.capture_contacts(semantic_step, contacts)
        residuals = local.compose(actuation)
        canonical = core.canonical_velocity_compose_v1(
            {
                "schema_version": "sporespore_canonical_velocity_compose_request_v1",
                "descriptor": descriptor,
                "source_actuation": actuation,
                "ordered_stability_residuals": residuals,
            }
        )
        receipt = local.trace_fields(semantic_step)
        scale = float(receipt["startup_velocity_scale"])
        if semantic_step in selected_steps:
            selected_scales.append(scale)
        for source, composed in zip(
            actuation["ordered_commands"],
            canonical["ordered_commands"],
            strict=True,
        ):
            expected = -float(source["target_velocity_rad_s"]) * scale
            if abs(
                float(composed["combined_canonical_target_velocity_rad_s"])
                - expected
            ) > 1.0e-12:
                raise _core.R23D3MujocoError(
                    "QSDK_R23D45_MJC_COMPOSITION_CANARY_INVALID"
                )
        last_actuation = actuation
        last_residuals = residuals
    reversed_order_rejected = False
    if last_actuation is not None and last_residuals is not None:
        try:
            core.canonical_velocity_compose_v1(
                {
                    "schema_version": "sporespore_canonical_velocity_compose_request_v1",
                    "descriptor": descriptor,
                    "source_actuation": last_actuation,
                    "ordered_stability_residuals": list(reversed(last_residuals)),
                }
            )
        except LocomotionCoreError:
            reversed_order_rejected = True
    expected_scales = [
        1.0,
        1.0,
        1.0,
        0.0,
        design.smoothstep_scale(1),
        design.smoothstep_scale(179),
        design.smoothstep_scale(358),
        1.0,
    ]
    if selected_scales != expected_scales or not reversed_order_rejected:
        raise _core.R23D3MujocoError("QSDK_R23D45_MJC_COMPOSITION_CANARY_INVALID")
    return {
        "selected_semantic_steps": list(selected_steps),
        "selected_velocity_scales": selected_scales,
        "trigger_step": 3,
        "complete_composition_step_count": selected_steps[-1] + 1,
        "residual_order_mutation_rejected": True,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
    }


def _retained_discovery_canary() -> dict[str, Any]:
    declaration = _contract()
    discovery = declaration["retained_discovery_inputs"]
    names = {
        "mujoco_identity": "mujoco_identity_transform_trace_sha256",
        "mujoco_ramp": "mujoco_unconditional_ramp_trace_sha256",
        "rapier_identity": "rapier_identity_transform_trace_sha256",
        "godot_jolt_identity": "godot_jolt_identity_transform_trace_sha256",
    }
    receipts: dict[str, dict[str, Any]] = {}
    trigger_steps: dict[str, int | None] = {}
    for name, field in names.items():
        expected = str(discovery[field])
        digest_hex = expected.removeprefix("sha256:")
        payload = (
            REPO_ROOT.parent
            / "SporeSpore_Evidence"
            / "artifacts"
            / "sha256"
            / digest_hex
            / "payload.bin"
        )
        try:
            raw = payload.read_bytes()
        except OSError as error:
            raise _core.R23D3MujocoError(
                f"QSDK_R23D45_DISCOVERY_TRACE_UNREADABLE:{name}"
            ) from error
        observed = "sha256:" + hashlib.sha256(raw).hexdigest()
        if observed != expected:
            raise _core.R23D3MujocoError(
                f"QSDK_R23D45_DISCOVERY_TRACE_DIGEST:{name}"
            )
        rows: list[dict[str, Any]] = []
        for line in raw.splitlines()[:4]:
            value = json.loads(line)
            if not isinstance(value, dict):
                raise _core.R23D3MujocoError(
                    f"QSDK_R23D45_DISCOVERY_TRACE_ROW:{name}"
                )
            rows.append(value)
        if len(rows) != 4 or [row.get("semantic_step") for row in rows] != list(
            range(4)
        ):
            raise _core.R23D3MujocoError(
                f"QSDK_R23D45_DISCOVERY_TRACE_PREFIX:{name}"
            )
        governor = design.SupportLossConditionedStartup()
        for step, row in enumerate(rows):
            contacts = row.get("ordered_foot_contacts_before")
            if not _contact_map(contacts):
                raise _core.R23D3MujocoError(
                    f"QSDK_R23D45_DISCOVERY_TRACE_CONTACTS:{name}:{step}"
                )
            governor.step(step, contacts)
        trigger_steps[name] = governor.trigger_step
        receipts[name] = {
            "sha256": observed,
            "byte_length": len(raw),
            "prefix_row_count": len(rows),
            "probe_support_counts": [
                sum(int(value) for value in row["ordered_foot_contacts_before"].values())
                for row in rows
            ],
            "replayed_trigger_step": governor.trigger_step,
        }
    if (
        trigger_steps["mujoco_identity"] != 3
        or trigger_steps["mujoco_ramp"] is not None
        or trigger_steps["rapier_identity"] is not None
        or trigger_steps["godot_jolt_identity"] is not None
    ):
        raise _core.R23D3MujocoError("QSDK_R23D45_DISCOVERY_DISPATCH_INVALID")
    return {
        "retained_trace_count": len(receipts),
        "retained_trace_receipts": receipts,
        "engine_identity_used_by_transform": False,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
    }


def run_preflight(stage_id: str, onset_id: str, arm_id: str) -> dict[str, Any]:
    _contract()
    item = _cell(stage_id, onset_id, arm_id)
    schedule = [
        design.segment_for_step(item, step) for step in range(design.CONTROLLER_STEPS)
    ]
    core = _R23D45Core()
    compiled, profile = _bound_base._compile_boundary(core)
    memory = core.balanced_wave_initial_memory()
    canary = _composition_canary(core)
    discovery_canary = _retained_discovery_canary()
    trace_canary = _synthetic_trace_canary(item)
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
        raise _core.R23D3MujocoError("QSDK_R23D45_MJC_PREFLIGHT_INVALID")
    return {
        "schema_version": "sporespore_qsdk_r23d45_mujoco_preflight_v1",
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
        "support_loss_composition_canary": canary,
        "retained_discovery_dispatch_canary": discovery_canary,
        "trace_validation_canary": trace_canary,
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
        "schema_version": "sporespore_qsdk_r23d45_authorization_preflight_v1",
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


for name, value in {
    "design": design,
    "evaluator": SimpleNamespace(FALSE_CLAIMS=FALSE_CLAIMS),
    "base": _bound_base,
    "LocomotionCore": _R23D45Core,
    "PREREGISTRATION_PATH": PREREGISTRATION_PATH,
    "PHYSICAL_EVALUATOR_PATH": str(WORKER_PATH),
    "CLOSURE_PATH": CLOSURE_PATH,
    "WORKER_PATH": WORKER_PATH,
    "CAMPAIGN_ID": design.CAMPAIGN_ID,
    "GATE_ID": design.GATE_ID,
    "REPORT_SCHEMA": REPORT_SCHEMA,
    "FAILURE_SCHEMA": FAILURE_SCHEMA,
    "SCHEDULE_ID": "qsdk_r23d45_reference_walk_v1",
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


def _trace_row(**kwargs: Any) -> dict[str, Any]:
    row = _INHERITED_TRACE_ROW(**kwargs)
    row.update(_RUN.trace_fields(int(kwargs["semantic_step"])))
    return row


_core._trace_row = _trace_row
_core.run_preflight = run_preflight


def _physical_gate_evaluation(report: dict[str, Any]) -> dict[str, Any]:
    declaration = _contract()
    gates = declaration["physical_gates"]
    measurements = report["measurements"]
    failures: list[str] = []
    checks = {
        "forward_displacement": float(measurements["final_forward_displacement_m"])
        >= float(gates["minimum_final_forward_displacement_m"]),
        "maximum_tilt": float(measurements["maximum_tilt_rad"])
        <= float(gates["maximum_tilt_rad"]),
        "minimum_torso_height": float(measurements["minimum_torso_height_m"])
        >= float(gates["minimum_torso_height_m"]),
        "contact_cycles": all(
            int(measurements["contact_cycle_count_by_limb"][limb_id])
            >= int(gates["minimum_contact_cycles_per_limb"])
            for limb_id in design.LIMB_IDS
        ),
        "torso_ground_contact": int(measurements["torso_ground_contact_step_count"])
        <= int(gates["maximum_torso_ground_contact_step_count"]),
        "controller_steps": int(measurements["controller_semantic_step_count"])
        == int(gates["exact_controller_step_count"]),
        "portable_commands": int(measurements["validated_portable_command_count"])
        == int(gates["exact_validated_portable_command_count"]),
        "native_applications": int(measurements["native_actuation_application_count"])
        == int(gates["exact_native_actuation_application_count"]),
        "controller_errors": int(measurements["controller_error_count"])
        <= int(gates["maximum_controller_error_count"]),
        "safe_no_actuation": int(measurements["safe_no_actuation_count"])
        <= int(gates["maximum_safe_no_actuation_count"]),
        "finite_observations": int(measurements["nonfinite_observation_count"])
        <= int(gates["maximum_nonfinite_observation_count"]),
        "actuator_mapping": int(measurements["actuator_application_mismatch_count"])
        <= int(gates["maximum_actuator_application_mismatch_count"]),
    }
    failures.extend(name for name, passed in checks.items() if not passed)
    mechanism_engaged = (
        measurements.get("startup_ramp_triggered") is True
        and measurements.get("startup_ramp_trigger_step") == 3
        and measurements.get("startup_probe_minimum_support_count") == 0
    )
    execution_valid = (
        report["execution"].get("integrity_passed") is True
        and report["trace_summary"].get("ok") is True
        and measurements.get("startup_transform_composition_integrity_passed")
        is True
    )
    walking_passed = not failures
    classification = (
        "valid_complete_positive_support_loss_conditioned_startup"
        if execution_valid and mechanism_engaged and walking_passed
        else "valid_complete_negative_support_loss_conditioned_startup"
        if execution_valid
        else "invalid_complete_support_loss_conditioned_startup"
    )
    return {
        "classification": classification,
        "execution_valid": execution_valid,
        "mechanism_engaged_at_predeclared_step": mechanism_engaged,
        "common_physical_walking_gate_passed": walking_passed,
        "physical_gate_checks": checks,
        "physical_gate_failures": failures,
        "development_only": True,
        "fresh_held_out_condition_consumed": False,
        "turning_tested": False,
        "physical_acceptance_authority": False,
    }


def run_physical(
    stage_id: str,
    onset_id: str,
    arm_id: str,
    source_commit: str,
) -> dict[str, Any]:
    report = _core.run_physical(stage_id, onset_id, arm_id, source_commit)
    summary = _RUN.summary()
    report["measurements"].update(summary)
    report["execution"].update(summary)
    report["execution"]["integrity_passed"] = bool(
        report["execution"]["integrity_passed"]
        and summary["startup_transform_composition_integrity_passed"]
    )
    report["development_evaluation"] = _physical_gate_evaluation(report)
    report["claims"] = copy.deepcopy(FALSE_CLAIMS)
    report["claims"]["startup_mechanism_positive"] = (
        report["development_evaluation"]["classification"]
        == "valid_complete_positive_support_loss_conditioned_startup"
    )
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
            marker = "QSDK_R23D45_MUJOCO_PREFLIGHT "
        elif args.command == "authorization-preflight":
            value = run_authorization_preflight(
                args.stage,
                args.onset,
                args.arm,
                args.source_commit,
            )
            marker = "QSDK_R23D45_AUTHORIZATION_PREFLIGHT "
        else:
            value = run_physical(
                args.stage,
                args.onset,
                args.arm,
                args.source_commit,
            )
            marker = "QSDK_R23D45_MUJOCO_TERMINAL "
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
                    "sporespore_qsdk_r23d45_authorization_preflight_failure_v1"
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
                "QSDK_R23D45_AUTHORIZATION_FAILURE "
                + json.dumps(
                    value,
                    allow_nan=False,
                    separators=(",", ":"),
                    sort_keys=True,
                )
            )
            return 1
        value = error.terminal_receipt or {"failure_code": error.code}
        print(
            "QSDK_R23D45_MUJOCO_TERMINAL "
            + json.dumps(value, allow_nan=False, separators=(",", ":"), sort_keys=True)
        )
        return 1
    except Exception as error:
        print(
            "QSDK_R23D45_MUJOCO_FAILURE "
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
