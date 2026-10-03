#!/usr/bin/env python3
"""Read-only R23D71 displacement-origin and directional-response diagnosis.

This is deliberately not a campaign evaluator.  It verifies the immutable
R23D71 evidence population, reconstructs the measurement origins used by the
three native producers, and applies the already-frozen cycle-integrated
directional-response measurement as a post-hoc development diagnostic.  It
never changes an R23D71 report, threshold, selector, result, or interpretation.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import subprocess
from typing import Any, Mapping, Sequence


SCRIPT_PATH = Path(__file__).resolve()
TURNING_ROOT = SCRIPT_PATH.parent
SDK_ROOT = TURNING_ROOT.parent
REPO_ROOT = SDK_ROOT.parent


DIAGNOSTIC_SCHEMA = (
    "sporespore_r23d71_forward_displacement_measurement_origin_diagnostic_v1"
)
DIAGNOSTIC_SOURCE_COMMIT = "a560ac8f2597eaaf1f08cbb0cd1c9c073c38c6a4"
DIAGNOSTIC_SOURCE_TREE = "95ab0bb3522b4c4b62acac54574a1aa98a4b84ce"
R23D71_SOURCE_COMMIT = "f82e3454dd8cfa53a7efced948c9ba130a0e2cda"
R23D71_ATTEMPT_ID = "63729f4ecfbc414688b6a8b2251707e9"
R23D71_CLOSURE_PATH = (
    TURNING_ROOT
    / "r23d71_success_terminal_projection_repaired_three_engine_turning_"
    "validation_closure_v1.json"
)
R23D62_DECLARATION_PATH = (
    TURNING_ROOT
    / "r23d62_selected_profile_three_engine_turning_validation_"
    "preregistration_v1.json"
)
R23D31_MEASUREMENT_PATH = TURNING_ROOT / "r23d31_cycle_integrated_measurement.py"
R23D33_EVALUATOR_PATH = (
    TURNING_ROOT / "r23d33_native_r23d29_transfer_evaluator.py"
)
DEFAULT_EVIDENCE_ROOT = Path(
    "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/"
    "qsdk-r23d71-physical-20260826T055614Z-f82e3454-lca1-python"
)
EXPECTED_REMOTE = "https://github.com/Slagathore/sporespore.git"
ENGINES = ("godot_jolt", "rapier_parry", "mujoco")
ARMS = ("reference_zero", "positive_heading", "negative_heading")
CONTROLLER_STEPS = 2_992
SETTLE_TICKS = 240
WARMUP_CYCLES = 1
SCHEDULER_CYCLE_STEPS = 360
EVIDENCE_BOUNDARY_ALIGNMENT_TICKS = 112
EVIDENCE_START_WORLD_TICK = (
    SETTLE_TICKS
    + WARMUP_CYCLES * SCHEDULER_CYCLE_STEPS
    + EVIDENCE_BOUNDARY_ALIGNMENT_TICKS
)
EVIDENCE_START_SEMANTIC_STEP = EVIDENCE_START_WORLD_TICK - SETTLE_TICKS
LAST_TASK_ORIGIN_REANCHOR_SEMANTIC_STEP = 2_400
TURN_COMMAND_START_SEMANTIC_STEP = 600

SOURCE_BINDINGS = (
    {
        "path": R23D31_MEASUREMENT_PATH.relative_to(REPO_ROOT).as_posix(),
        "git_blob_oid": "bd4c802f35bdaf844e64b13af9a6485af755083c",
        "byte_length": 8_026,
        "raw_sha256": (
            "sha256:b82656f877989a2cb1494fa2d715353715b0a01958038b3b48ccd7c8e9f99516"
        ),
    },
    {
        "path": R23D33_EVALUATOR_PATH.relative_to(REPO_ROOT).as_posix(),
        "git_blob_oid": "547be0a8a7761b0c357d6aa3619e73bbd0dee980",
        "byte_length": 29_716,
        "raw_sha256": (
            "sha256:2783fdbd99a2de6711ee833634fe33b8d53205acf9ee048a39db9998588d222a"
        ),
    },
    {
        "path": "scripts/lab/gait/physical_wave_gait_quadruped.gd",
        "git_blob_oid": "21800d942fbc63c599a8c48f64bd0031e2016e95",
        "byte_length": 429_155,
        "raw_sha256": (
            "sha256:0205268af835da3c390032a8ecb865779a1ecc756b4d824236fb1ad93cc44c73"
        ),
    },
    {
        "path": (
            "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/"
            "r23d27_physical.rs"
        ),
        "git_blob_oid": "eeab2e498666b0a8b72a83311a07b0a96ee86323",
        "byte_length": 463_761,
        "raw_sha256": (
            "sha256:f90e1f64309509a4667b4420ea9a7fc6aaf05197ab18268ecd60b90643fef64c"
        ),
    },
    {
        "path": (
            "sdk/adapters/mujoco/sporespore_mujoco_adapter/"
            "qsdk_r23d3_phase_balanced.py"
        ),
        "git_blob_oid": "a20c31d137f6b70b0ab32b3c4c470530689e821c",
        "byte_length": 35_560,
        "raw_sha256": (
            "sha256:029091f8fd3ced8d4f857db0907411afdf98b89a8e8410aa21e30960aacfc8e1"
        ),
    },
    {
        "path": (
            "sdk/adapters/mujoco/sporespore_mujoco_adapter/"
            "qsdk_r23d65_selected_profile_turning.py"
        ),
        "git_blob_oid": "a6a3ad36dc6bae0458cfcddb72653f42650c874e",
        "byte_length": 63_410,
        "raw_sha256": (
            "sha256:19940de8ec6e5a8eec9a78b721f968e3b93b26c0f39e79a8fbc38124973ded9b"
        ),
    },
    {
        "path": R23D62_DECLARATION_PATH.relative_to(REPO_ROOT).as_posix(),
        "git_blob_oid": "147b0a9309a3a9dae27be8134251b200e4b58b0e",
        "byte_length": 15_840,
        "raw_sha256": (
            "sha256:638aaff5f23ae8b0da8c93fc1e75f183c437d3e069d1112496068d1ad8350897"
        ),
    },
    {
        "path": R23D71_CLOSURE_PATH.relative_to(REPO_ROOT).as_posix(),
        "git_blob_oid": "bf282b4a0c33f9d0cc777f354c623100195f6adf",
        "byte_length": 21_372,
        "raw_sha256": (
            "sha256:4221a204adc654520b63eb5e10ed3187b1a763c70a06f424d2e72847dec6eb0d"
        ),
    },
)


class DiagnosticError(RuntimeError):
    """Fail-closed diagnostic error."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise DiagnosticError(code)


def _raw_sha256_bytes(value: bytes) -> str:
    return "sha256:" + hashlib.sha256(value).hexdigest()


def _raw_sha256(path: Path) -> str:
    return _raw_sha256_bytes(path.read_bytes())


def _load_object(path: Path, code: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise DiagnosticError(f"{code}:{type(error).__name__}") from error
    if not isinstance(value, dict):
        raise DiagnosticError(code)
    return value


def _git(*arguments: str, binary: bool = False) -> bytes | str:
    process = subprocess.run(
        ("git", *arguments),
        cwd=REPO_ROOT,
        check=False,
        capture_output=True,
        text=not binary,
    )
    if process.returncode != 0:
        stderr = process.stderr if isinstance(process.stderr, str) else ""
        raise DiagnosticError(f"R23D71_DIAGNOSTIC_GIT_FAILED:{arguments}:{stderr[-500:]}")
    return process.stdout


def _git_blob_bytes(path: str) -> bytes:
    value = _git("show", f"{DIAGNOSTIC_SOURCE_COMMIT}:{path}", binary=True)
    assert isinstance(value, bytes)
    return value


def _load_git_object(path: str, code: str) -> dict[str, Any]:
    raw = _git_blob_bytes(path)
    try:
        value = json.loads(raw.decode("utf-8"))
    except (UnicodeError, json.JSONDecodeError) as error:
        raise DiagnosticError(f"{code}:{type(error).__name__}") from error
    if not isinstance(value, dict):
        raise DiagnosticError(code)
    return value


def _load_pinned_cycle_measurement() -> Any:
    path = R23D31_MEASUREMENT_PATH.relative_to(REPO_ROOT).as_posix()
    raw = _git_blob_bytes(path)
    namespace: dict[str, Any] = {
        "__name__": "sporespore_r23d31_cycle_integrated_measurement_pinned",
        "__file__": f"{DIAGNOSTIC_SOURCE_COMMIT}:{path}",
    }
    try:
        exec(compile(raw.decode("utf-8"), namespace["__file__"], "exec"), namespace)
    except (UnicodeError, SyntaxError) as error:
        raise DiagnosticError(
            f"R23D71_DIAGNOSTIC_MEASUREMENT_LOAD:{type(error).__name__}"
        ) from error
    measurement = namespace.get("measure_cycle_integrated_response")
    _require(callable(measurement), "R23D71_DIAGNOSTIC_MEASUREMENT_CALLABLE")
    return measurement


def _measurement_rows(
    rows: Sequence[Mapping[str, Any]],
) -> list[dict[str, Any]]:
    """Apply the R23D33 frozen trace-to-estimator projection."""

    return [
        {
            "trace_step": row.get("semantic_step"),
            "phase_id": (
                "reference_continuation"
                if row.get("segment_id") == "after_declared_schedule"
                else row.get("segment_id")
            ),
            "measured_yaw_rad": row.get("measured_yaw_rad"),
        }
        for row in rows
    ]


def _verify_repository() -> None:
    root = str(_git("rev-parse", "--show-toplevel")).strip().replace("\\", "/")
    remote = str(_git("remote", "get-url", "origin")).strip()
    tree = str(_git("rev-parse", f"{DIAGNOSTIC_SOURCE_COMMIT}^{{tree}}")).strip()
    _require(root.casefold() == REPO_ROOT.as_posix().casefold(), "R23D71_DIAGNOSTIC_ROOT")
    _require(remote == EXPECTED_REMOTE, "R23D71_DIAGNOSTIC_REMOTE")
    _require(tree == DIAGNOSTIC_SOURCE_TREE, "R23D71_DIAGNOSTIC_TREE")
    for binding in SOURCE_BINDINGS:
        path = str(binding["path"])
        blob = str(_git("rev-parse", f"{DIAGNOSTIC_SOURCE_COMMIT}:{path}")).strip()
        _require(blob == binding["git_blob_oid"], f"R23D71_DIAGNOSTIC_BLOB:{path}")
        raw = _git("cat-file", "blob", blob, binary=True)
        assert isinstance(raw, bytes)
        _require(len(raw) == binding["byte_length"], f"R23D71_DIAGNOSTIC_LENGTH:{path}")
        _require(
            _raw_sha256_bytes(raw) == binding["raw_sha256"],
            f"R23D71_DIAGNOSTIC_SHA:{path}",
        )
        if path.endswith("physical_wave_gait_quadruped.gd"):
            _require(
                b"torso.global_position - evidence_start_torso_position" in raw,
                "R23D71_DIAGNOSTIC_GODOT_MEASUREMENT_ORIGIN",
            )
        elif path.endswith("r23d27_physical.rs"):
            _require(
                b"let final_delta = final_position - task_origin;" in raw,
                "R23D71_DIAGNOSTIC_RAPIER_MEASUREMENT_ORIGIN",
            )
        elif path.endswith("qsdk_r23d3_phase_balanced.py"):
            _require(
                b"- task_origin" in raw,
                "R23D71_DIAGNOSTIC_MUJOCO_MEASUREMENT_ORIGIN",
            )
        elif path.endswith("r23d31_cycle_integrated_measurement.py"):
            _require(
                b"def measure_cycle_integrated_response(" in raw
                and b"MECHANISM_FLOOR_RAD = 0.01" in raw,
                "R23D71_DIAGNOSTIC_CYCLE_MEASUREMENT",
            )
        elif path.endswith("r23d33_native_r23d29_transfer_evaluator.py"):
            _require(
                b'def _measurement_rows(' in raw
                and b'if row.get("segment_id") == "after_declared_schedule"' in raw,
                "R23D71_DIAGNOSTIC_MEASUREMENT_PROJECTION",
            )


def _trace_path(evidence_root: Path, engine_id: str, arm_id: str) -> Path:
    return (
        evidence_root
        / "traces"
        / f"r23d71__{engine_id}__s23191__{arm_id}.ndjson"
    )


def _terminal_path(evidence_root: Path, engine_id: str, arm_id: str) -> Path:
    return (
        evidence_root
        / "cells"
        / f"r23d71__{engine_id}__s23191__{arm_id}"
        / "terminal.json"
    )


def _worker_terminal(value: Mapping[str, Any], engine_id: str) -> Mapping[str, Any]:
    if engine_id != "mujoco":
        return value
    nested = value.get("observed_worker_terminal")
    _require(isinstance(nested, Mapping), "R23D71_DIAGNOSTIC_MUJOCO_TERMINAL")
    return nested


def _closure_trace_bindings(closure: Mapping[str, Any]) -> dict[str, Mapping[str, Any]]:
    values = closure.get("observed_cells")
    _require(isinstance(values, list) and len(values) == 9, "R23D71_DIAGNOSTIC_CELLS")
    result: dict[str, Mapping[str, Any]] = {}
    for value in values:
        _require(isinstance(value, Mapping), "R23D71_DIAGNOSTIC_CELL")
        cell_id = value.get("cell_id")
        trace = value.get("retained_trace")
        _require(
            isinstance(cell_id, str)
            and isinstance(trace, Mapping)
            and cell_id not in result,
            "R23D71_DIAGNOSTIC_CELL_TRACE",
        )
        result[cell_id] = trace
    return result


def _load_trace(
    path: Path,
    *,
    binding: Mapping[str, Any],
    engine_id: str,
    arm_id: str,
) -> list[dict[str, Any]]:
    _require(path.is_file(), f"R23D71_DIAGNOSTIC_TRACE_MISSING:{engine_id}:{arm_id}")
    _require(path.stat().st_size == binding.get("byte_length"), "R23D71_DIAGNOSTIC_TRACE_LENGTH")
    _require(_raw_sha256(path) == binding.get("raw_sha256"), "R23D71_DIAGNOSTIC_TRACE_SHA")
    rows: list[dict[str, Any]] = []
    with path.open("r", encoding="utf-8") as handle:
        for index, line in enumerate(handle):
            try:
                row = json.loads(line)
            except json.JSONDecodeError as error:
                raise DiagnosticError(
                    f"R23D71_DIAGNOSTIC_TRACE_JSON:{engine_id}:{arm_id}:{index}"
                ) from error
            _require(isinstance(row, dict), "R23D71_DIAGNOSTIC_TRACE_ROW")
            _require(row.get("semantic_step") == index, "R23D71_DIAGNOSTIC_TRACE_ORDER")
            _require(row.get("engine_id", engine_id) == engine_id, "R23D71_DIAGNOSTIC_TRACE_ENGINE")
            rows.append(row)
    _require(len(rows) == CONTROLLER_STEPS, "R23D71_DIAGNOSTIC_TRACE_ROW_COUNT")
    return rows


def _vector(value: Any, code: str) -> tuple[float, float, float]:
    _require(isinstance(value, list) and len(value) == 3, code)
    result = tuple(float(item) for item in value)
    _require(all(math.isfinite(item) for item in result), code)
    return result  # type: ignore[return-value]


def _dot(left: Sequence[float], right: Sequence[float]) -> float:
    return sum(a * b for a, b in zip(left, right, strict=True))


def _subtract(left: Sequence[float], right: Sequence[float]) -> tuple[float, ...]:
    return tuple(a - b for a, b in zip(left, right, strict=True))


def _common_gate_diagnostic(
    measurements: Mapping[str, Any],
    *,
    prospective_forward_displacement_m: float,
    gates: Mapping[str, Any],
) -> dict[str, bool]:
    contacts = measurements.get("contact_cycle_count_by_limb")
    _require(isinstance(contacts, Mapping), "R23D71_DIAGNOSTIC_CONTACTS")
    return {
        "minimum_forward_displacement": (
            prospective_forward_displacement_m
            >= float(gates["minimum_final_forward_displacement_m"])
        ),
        "maximum_tilt": (
            float(measurements["maximum_tilt_rad"])
            <= float(gates["maximum_tilt_rad"])
        ),
        "minimum_torso_height": (
            float(measurements["minimum_torso_height_m"])
            >= float(gates["minimum_torso_height_m"])
        ),
        "minimum_contact_cycles_per_limb": all(
            int(contacts.get(limb_id, -1))
            >= int(gates["minimum_contact_cycles_per_limb"])
            for limb_id in ("front_left", "front_right", "rear_left", "rear_right")
        ),
        "zero_torso_ground_contact": (
            int(measurements["torso_ground_contact_step_count"])
            <= int(gates["maximum_torso_ground_contact_step_count"])
        ),
        "zero_controller_errors": (
            int(measurements["controller_error_count"])
            <= int(gates["maximum_controller_error_count"])
        ),
        "zero_safe_no_actuation": (
            int(measurements["safe_no_actuation_count"])
            <= int(gates["maximum_safe_no_actuation_count"])
        ),
        "zero_nonfinite_observations": (
            int(measurements["nonfinite_observation_count"])
            <= int(gates["maximum_nonfinite_observation_count"])
        ),
        "zero_actuator_application_mismatches": (
            int(measurements["actuator_application_mismatch_count"])
            <= int(gates["maximum_actuator_application_mismatch_count"])
        ),
        "exact_controller_semantic_step_count": (
            int(measurements["controller_semantic_step_count"])
            == int(gates["exact_controller_semantic_step_count"])
        ),
        "exact_validated_portable_command_count": (
            int(measurements["validated_portable_command_count"])
            == int(gates["exact_validated_portable_command_count"])
        ),
        "exact_native_actuation_application_count": (
            int(measurements["native_actuation_application_count"])
            == int(gates["exact_native_actuation_application_count"])
        ),
    }


def diagnose(evidence_root: Path) -> dict[str, Any]:
    _verify_repository()
    closure_path = R23D71_CLOSURE_PATH.relative_to(REPO_ROOT).as_posix()
    declaration_path = R23D62_DECLARATION_PATH.relative_to(REPO_ROOT).as_posix()
    closure = _load_git_object(closure_path, "R23D71_DIAGNOSTIC_CLOSURE")
    declaration = _load_git_object(
        declaration_path, "R23D71_DIAGNOSTIC_DECLARATION"
    )
    attempt = closure.get("attempt")
    _require(isinstance(attempt, Mapping), "R23D71_DIAGNOSTIC_ATTEMPT")
    _require(closure.get("source_commit") == R23D71_SOURCE_COMMIT, "R23D71_DIAGNOSTIC_SOURCE")
    _require(attempt.get("attempt_id") == R23D71_ATTEMPT_ID, "R23D71_DIAGNOSTIC_ATTEMPT_ID")
    _require(
        closure.get("status")
        == (
            "closed_consumed_invalid_complete_after_nine_native_worlds_"
            "transport_contract_and_rapier_forward_gate_failures"
        ),
        "R23D71_DIAGNOSTIC_OFFICIAL_STATUS",
    )
    _require(
        Path(str(attempt.get("attempt_root"))).resolve(strict=True)
        == evidence_root.resolve(strict=True),
        "R23D71_DIAGNOSTIC_EVIDENCE_ROOT",
    )
    population = attempt.get("population_identity")
    _require(isinstance(population, Mapping), "R23D71_DIAGNOSTIC_POPULATION")
    _require(population.get("complete_file_population_count") == 72, "R23D71_DIAGNOSTIC_FILE_COUNT")
    _require(population.get("complete_file_population_byte_count") == 677_221_819, "R23D71_DIAGNOSTIC_BYTE_COUNT")
    _require(
        population.get("canonical_population_manifest_sha256")
        == "sha256:28f122f0ed80f1aa50e0ef9ff8b76105d339dd35d186ddbb0f66b03f72f653c7",
        "R23D71_DIAGNOSTIC_MANIFEST",
    )

    matrix = declaration.get("frozen_matrix")
    gates = declaration.get("frozen_common_physical_gates")
    _require(isinstance(matrix, Mapping) and isinstance(gates, Mapping), "R23D71_DIAGNOSTIC_CONTRACT")
    _require(
        matrix.get("expected_reanchor_semantic_steps") == [600, 1_800, 2_400],
        "R23D71_DIAGNOSTIC_REANCHORS",
    )
    _require(EVIDENCE_START_SEMANTIC_STEP == 472, "R23D71_DIAGNOSTIC_EVIDENCE_STEP")

    cycle_measurement = _load_pinned_cycle_measurement()
    trace_bindings = _closure_trace_bindings(closure)
    engine_results: dict[str, Any] = {}
    for engine_id in ENGINES:
        rows_by_arm: dict[str, list[dict[str, Any]]] = {}
        terminals_by_arm: dict[str, Mapping[str, Any]] = {}
        for arm_id in ARMS:
            cell_id = f"r23d71__{engine_id}__s23191__{arm_id}"
            rows_by_arm[arm_id] = _load_trace(
                _trace_path(evidence_root, engine_id, arm_id),
                binding=trace_bindings[cell_id],
                engine_id=engine_id,
                arm_id=arm_id,
            )
            terminal_value = _load_object(
                _terminal_path(evidence_root, engine_id, arm_id),
                "R23D71_DIAGNOSTIC_TERMINAL",
            )
            terminals_by_arm[arm_id] = _worker_terminal(terminal_value, engine_id)

        cycle = cycle_measurement(
            {
                arm_id: _measurement_rows(rows)
                for arm_id, rows in rows_by_arm.items()
            }
        )
        arm_results: dict[str, Any] = {}
        for arm_id in ARMS:
            rows = rows_by_arm[arm_id]
            terminal = terminals_by_arm[arm_id]
            measurements = terminal.get("measurements")
            _require(isinstance(measurements, Mapping), "R23D71_DIAGNOSTIC_MEASUREMENTS")
            observed_metric = float(measurements["final_forward_displacement_m"])
            evidence_origin = _vector(
                rows[EVIDENCE_START_SEMANTIC_STEP].get("torso_position_world_m"),
                "R23D71_DIAGNOSTIC_EVIDENCE_ORIGIN",
            )
            last_task_origin = _vector(
                rows[LAST_TASK_ORIGIN_REANCHOR_SEMANTIC_STEP].get(
                    "task_frame_origin_world_m"
                ),
                "R23D71_DIAGNOSTIC_LAST_TASK_ORIGIN",
            )
            if engine_id == "godot_jolt":
                origin_policy = "evidence_window_start_semantic_step_v1"
                reconstruction_prefix = 0.0
                reconstructed_metric = observed_metric
                reference_heading_rad: float | None = None
            else:
                origin_policy = "last_task_frame_reanchor_semantic_step_v1"
                reference_heading_rad = float(rows[0]["measured_yaw_rad"])
                forward = (
                    math.cos(reference_heading_rad),
                    0.0,
                    math.sin(reference_heading_rad),
                )
                reconstruction_prefix = _dot(
                    _subtract(last_task_origin, evidence_origin),
                    forward,
                )
                reconstructed_metric = observed_metric + reconstruction_prefix
            gate_diagnostic = _common_gate_diagnostic(
                measurements,
                prospective_forward_displacement_m=reconstructed_metric,
                gates=gates,
            )
            first_torso_ground_contact_step = next(
                (
                    index
                    for index, row in enumerate(rows)
                    if row.get("torso_ground_contact") is True
                ),
                None,
            )
            arm_results[arm_id] = {
                "historical_terminal_measurement_origin_policy": origin_policy,
                "historical_terminal_final_forward_displacement_m": observed_metric,
                "evidence_window_origin_semantic_step": EVIDENCE_START_SEMANTIC_STEP,
                "evidence_window_origin_world_m": list(evidence_origin),
                "last_task_origin_reanchor_semantic_step": (
                    LAST_TASK_ORIGIN_REANCHOR_SEMANTIC_STEP
                ),
                "last_task_origin_world_m": list(last_task_origin),
                "reference_heading_rad": reference_heading_rad,
                "precontinuation_forward_projection_m": reconstruction_prefix,
                "prospective_evidence_origin_reconstruction_m": reconstructed_metric,
                "prospective_common_gate_diagnostic": gate_diagnostic,
                "prospective_common_gate_diagnostic_passed": all(
                    gate_diagnostic.values()
                ),
                "maximum_tilt_rad": float(measurements["maximum_tilt_rad"]),
                "minimum_torso_height_m": float(measurements["minimum_torso_height_m"]),
                "torso_ground_contact_step_count": int(
                    measurements["torso_ground_contact_step_count"]
                ),
                "first_torso_ground_contact_semantic_step": (
                    first_torso_ground_contact_step
                ),
                "torso_ground_contact_precedes_turn_window": (
                    first_torso_ground_contact_step is not None
                    and first_torso_ground_contact_step
                    < TURN_COMMAND_START_SEMANTIC_STEP
                ),
                "contact_cycle_count_by_limb": dict(
                    measurements["contact_cycle_count_by_limb"]
                ),
            }
        engine_results[engine_id] = {
            "arms": arm_results,
            "posthoc_cycle_integrated_measurement": cycle,
            "posthoc_cycle_integrated_directional_response_passed": (
                cycle.get("passed") is True
            ),
        }

    rapier_observations = closure.get("rapier_physical_observations")
    _require(isinstance(rapier_observations, Mapping), "R23D71_DIAGNOSTIC_RAPIER")
    for observation in rapier_observations.get("ordered_observations", []):
        _require(isinstance(observation, Mapping), "R23D71_DIAGNOSTIC_RAPIER_OBSERVATION")
        arm_id = str(observation.get("arm_id"))
        _require(
            float(observation["final_forward_displacement_m"])
            == engine_results["rapier_parry"]["arms"][arm_id][
                "historical_terminal_final_forward_displacement_m"
            ],
            "R23D71_DIAGNOSTIC_RAPIER_HISTORY",
        )

    receipt: dict[str, Any] = {
        "schema_version": DIAGNOSTIC_SCHEMA,
        "status": (
            "closed_read_only_development_diagnosis_measurement_origin_mismatch_"
            "proved_physical_not_opened"
        ),
        "question_class": "development",
        "question": (
            "Did R23D71's Rapier forward-displacement failure identify deficient "
            "locomotion, or did the three producers apply the inherited final-advance "
            "gate to different measurement origins?"
        ),
        "diagnostic_source_commit": DIAGNOSTIC_SOURCE_COMMIT,
        "diagnostic_source_tree_git_oid": DIAGNOSTIC_SOURCE_TREE,
        "diagnostic_source_bindings": [dict(value) for value in SOURCE_BINDINGS],
        "immutable_r23d71_boundary": {
            "closure_path": closure_path,
            "closure_git_blob_oid": next(
                value["git_blob_oid"]
                for value in SOURCE_BINDINGS
                if value["path"] == closure_path
            ),
            "closure_blob_raw_sha256": _raw_sha256_bytes(
                _git_blob_bytes(closure_path)
            ),
            "official_status": closure["status"],
            "source_commit": R23D71_SOURCE_COMMIT,
            "attempt_id": R23D71_ATTEMPT_ID,
            "attempt_root": evidence_root.resolve(strict=True).as_posix(),
            "complete_file_population_count": 72,
            "complete_file_population_byte_count": 677_221_819,
            "canonical_population_manifest_sha256": population[
                "canonical_population_manifest_sha256"
            ],
            "official_result_or_interpretation_changed": False,
            "same_identity_rerun_performed": False,
        },
        "inherited_threshold_and_origin_provenance": {
            "threshold_id": "R23D34_FORWARD_DISPLACEMENT",
            "minimum_final_forward_displacement_m": gates[
                "minimum_final_forward_displacement_m"
            ],
            "threshold_changed": False,
            "settle_ticks": SETTLE_TICKS,
            "warmup_cycles": WARMUP_CYCLES,
            "scheduler_cycle_steps": SCHEDULER_CYCLE_STEPS,
            "evidence_boundary_alignment_ticks": EVIDENCE_BOUNDARY_ALIGNMENT_TICKS,
            "evidence_start_world_tick": EVIDENCE_START_WORLD_TICK,
            "controller_authority_start_world_tick": SETTLE_TICKS,
            "evidence_start_controller_semantic_step": EVIDENCE_START_SEMANTIC_STEP,
            "turn_command_start_semantic_step": TURN_COMMAND_START_SEMANTIC_STEP,
            "derivation": (
                "(settle_ticks + warmup_cycles * scheduler_cycle_steps + "
                "evidence_boundary_alignment_ticks) - controller_authority_start_world_tick"
            ),
            "prospective_common_measurement_origin_policy_id": (
                "evidence_window_start_semantic_step_v1"
            ),
            "task_frame_reanchors_remain_controller_path_state_only": True,
        },
        "engine_diagnostics": engine_results,
        "diagnosis": {
            "godot_historical_metric_uses_evidence_window_origin": True,
            "rapier_historical_metric_uses_last_task_frame_reanchor": True,
            "mujoco_historical_metric_uses_last_task_frame_reanchor": True,
            "producer_measurement_origins_differ": True,
            "rapier_directional_response_passes_unchanged_cycle_measurement_posthoc": True,
            "rapier_all_other_common_physical_gates_pass_posthoc": all(
                result["prospective_common_gate_diagnostic_passed"]
                for result in engine_results["rapier_parry"]["arms"].values()
            ),
            "rapier_locomotion_deficiency_established_by_r23d71_forward_gate": False,
            "mujoco_directional_response_passes_unchanged_cycle_measurement_posthoc": False,
            "mujoco_all_common_physical_gates_pass_posthoc": False,
            "mujoco_fall_precedes_turn_window_in_all_three_arms": all(
                result["torso_ground_contact_precedes_turn_window"]
                for result in engine_results["mujoco"]["arms"].values()
            ),
            "prospective_repair_scope": (
                "Separate immutable evidence-window measurement origin from mutable "
                "controller task-frame origin in future Rapier and MuJoCo producers; "
                "preserve every historical terminal and frozen evaluator result."
            ),
            "next_physical_behavior_lane": (
                "MuJoCo pre-turn walking/stability development under the canonical "
                "R23D29 policy and selected public profile"
            ),
        },
        "adequacy": {
            "complete_retained_engine_arm_population_read": True,
            "retained_trace_count": 9,
            "retained_trace_row_count": 26_928,
            "measurement_origin_code_paths_bound_to_diagnostic_source": True,
            "adequate_for_measurement_origin_bug_diagnosis": True,
            "adequate_for_new_finite_turning_claim": False,
            "population_inference_attempted": False,
            "superiority_test_invoked": False,
            "equivalence_or_non_inferiority_test_invoked": False,
            "physical_world_opened_by_diagnostic": False,
        },
        "claims": {
            "development_diagnosis_complete": True,
            "historical_result_reinterpreted": False,
            "finite_three_engine_turning": False,
            "portable_basic_turning": False,
            "q_sdk_r23_satisfied": False,
            "cross_engine_equivalence": False,
            "population_robustness": False,
            "arbitrary_quadruped_coverage": False,
            "prone_to_standing": False,
            "physical_acceptance_authority": False,
            "release_authorized": False,
        },
        "receipt_canonical_sha256_scope": "receipt_without_receipt_canonical_sha256",
    }
    canonical = json.dumps(
        receipt,
        sort_keys=True,
        separators=(",", ":"),
        allow_nan=False,
    ).encode("utf-8")
    receipt["receipt_canonical_sha256"] = _raw_sha256_bytes(canonical)
    return receipt


def _arguments(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--evidence-root", type=Path, default=DEFAULT_EVIDENCE_ROOT)
    parser.add_argument("--pretty", action="store_true")
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    arguments = _arguments(argv)
    try:
        receipt = diagnose(arguments.evidence_root)
    except (DiagnosticError, OSError, ValueError, KeyError, TypeError) as error:
        print(f"R23D71_FORWARD_MEASUREMENT_ORIGIN_DIAGNOSTIC_FAIL {error}", file=sys.stderr)
        return 1
    print(
        json.dumps(
            receipt,
            indent=2 if arguments.pretty else None,
            sort_keys=True,
            separators=None if arguments.pretty else (",", ":"),
            allow_nan=False,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
