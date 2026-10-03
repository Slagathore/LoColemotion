#!/usr/bin/env python3
"""Audit the consumed QSDK-R10B-L1 physical route-ghost refusal without worlds."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys
from typing import Any, Iterable


ROOT = Path(__file__).resolve().parents[2]
EXPECTED_ROOT = Path(r"C:\Users\Cole\CodeStuff\games\SporeSpore")
EXPECTED_REMOTE = "https://github.com/Slagathore/sporespore.git"
EVIDENCE_ROOT = Path(
    r"C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
    r"\qsdk-r10b-development-route-ghost-physical-61783dbc64bf"
)
QUALIFICATION_ROOT = Path(
    r"C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
    r"\qsdk-r10b-development-route-ghost-zero-world-qualification-61783dbc64bf"
)
CLOSURE_PATH = (
    ROOT / "sdk/qsdk_r10b_l1_development_route_ghost_physical_invalid_closure_v1.json"
)
R66_CONTRACT_PATH = (
    ROOT / "sdk/recovery/r24d66_godot_exact_quaternion_projection_contract_v1.json"
)
R66_CLOSURE_PATH = (
    ROOT / "sdk/recovery/"
    "r24d66_godot_exact_quaternion_projection_zero_world_qualification_closure_v1.json"
)
SOURCE_COMMIT = "61783dbc64bf6df4a69a7be9fed0fb0ef563bd94"
STAGE_COMMIT = "ac55feafe39e503e92babf5a442c92861a1136cb"
AUTHORITY_COMMIT = "1e595edd6b32d139b7afd524fc39dc845da2af18"
R66_SOURCE_COMMIT = "a3ad18d817efee465fae837e3d9ad144fa1bd258"
CELL_MARKER = "QSDK_R10B_PHYSICAL_CELL "
PASS_MARKER = "QSDK_R10B_L1_PHYSICAL_INVALID_CLOSURE_PASS "
QUATERNION_NORM_TOLERANCE = 1.0e-9

EXPECTED_EVIDENCE_FILES = [
    {
        "path": "baseline_s50300/attempt.json",
        "byte_length": 2023,
        "raw_sha256": (
            "sha256:51681b79134de1222f2e484dde679acb9742df44ac45913dcf144311ac62a60a"
        ),
    },
    {
        "path": "baseline_s50300/godot.log",
        "byte_length": 3_279_585,
        "raw_sha256": (
            "sha256:795e19b2c1f5699600dd7259cbd3564d175b276f91b2961514688a6c84f0552a"
        ),
    },
    {
        "path": "baseline_s50300/stderr.log",
        "byte_length": 0,
        "raw_sha256": (
            "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        ),
    },
    {
        "path": "baseline_s50300/stdout.log",
        "byte_length": 3_279_716,
        "raw_sha256": (
            "sha256:dcde1ab92a71824cf96ea84f6450001b3a4eba88b87020211c2878c3ee5312b3"
        ),
    },
]


class ClosureFailure(RuntimeError):
    """The retained physical-invalid closure was not exact."""


def require(condition: bool, code: str) -> None:
    if not condition:
        raise ClosureFailure(code)


def canonical_bytes(value: Any) -> bytes:
    return json.dumps(
        value, ensure_ascii=False, separators=(",", ":"), sort_keys=True
    ).encode("utf-8")


def sha256_bytes(raw: bytes) -> str:
    return "sha256:" + hashlib.sha256(raw).hexdigest()


def read_json(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise ClosureFailure(f"{label}_INVALID_JSON:{exc}") from exc
    require(isinstance(value, dict), f"{label}_ROOT_NOT_OBJECT")
    return value


def git(arguments: Iterable[str], *, binary: bool = False) -> str | bytes:
    completed = subprocess.run(
        ("git", "-C", ROOT, *arguments),
        check=False,
        capture_output=True,
        text=not binary,
        encoding=None if binary else "utf-8",
        errors=None if binary else "strict",
    )
    require(completed.returncode == 0, f"GIT_FAILED:{' '.join(arguments)}")
    return completed.stdout if binary else completed.stdout.strip()


def file_identity(path: Path, relative_to: Path) -> dict[str, Any]:
    raw = path.read_bytes()
    return {
        "path": path.relative_to(relative_to).as_posix(),
        "byte_length": len(raw),
        "raw_sha256": sha256_bytes(raw),
    }


def commit_identity(commit: str) -> dict[str, str]:
    return {
        "commit": commit,
        "parent_commit": str(git(("show", "-s", "--format=%P", commit))),
        "tree": str(git(("show", "-s", "--format=%T", commit))),
        "subject": str(git(("show", "-s", "--format=%s", commit))),
    }


def committed_file_identity(commit: str, relative: str) -> dict[str, Any]:
    raw = bytes(git(("show", f"{commit}:{relative}"), binary=True))
    return {
        "path": relative,
        "git_blob_oid": str(git(("rev-parse", f"{commit}:{relative}"))),
        "byte_length": len(raw),
        "raw_sha256": sha256_bytes(raw),
    }


def validate_repository_identity() -> None:
    require(ROOT.resolve() == EXPECTED_ROOT.resolve(), "WRONG_SCRIPT_ROOT")
    require(
        Path(str(git(("rev-parse", "--show-toplevel")))).resolve()
        == EXPECTED_ROOT.resolve(),
        "WRONG_GIT_ROOT",
    )
    require(
        str(git(("remote", "get-url", "origin"))) == EXPECTED_REMOTE,
        "WRONG_REMOTE",
    )


def validate_source_graph(closure: dict[str, Any]) -> None:
    graph = closure.get("source_graph")
    require(isinstance(graph, dict), "SOURCE_GRAPH_MISSING")
    require(
        graph.get("implementation_source")
        == {
            **commit_identity(SOURCE_COMMIT),
        },
        "SOURCE_COMMIT_IDENTITY_DRIFT",
    )

    stage_relative = (
        "sdk/qsdk_r10b_development_route_ghost_"
        "zero_world_qualification_closure_v2.json"
    )
    stage = {
        **commit_identity(STAGE_COMMIT),
        **committed_file_identity(STAGE_COMMIT, stage_relative),
    }
    require(graph.get("stage_freeze") == stage, "STAGE_IDENTITY_DRIFT")
    require(
        str(
            git(
                (
                    "diff-tree",
                    "--no-commit-id",
                    "--name-only",
                    "-r",
                    STAGE_COMMIT,
                )
            )
        ).splitlines()
        == [stage_relative],
        "STAGE_COMMIT_NOT_SINGLE_FILE",
    )

    authority_relative = (
        "sdk/qsdk_r10b_development_route_ghost_execution_authority_v2.json"
    )
    authority = {
        **commit_identity(AUTHORITY_COMMIT),
        **committed_file_identity(AUTHORITY_COMMIT, authority_relative),
    }
    require(
        graph.get("execution_authority") == authority,
        "AUTHORITY_IDENTITY_DRIFT",
    )
    require(
        str(
            git(
                (
                    "diff-tree",
                    "--no-commit-id",
                    "--name-only",
                    "-r",
                    AUTHORITY_COMMIT,
                )
            )
        ).splitlines()
        == [authority_relative],
        "AUTHORITY_COMMIT_NOT_SINGLE_FILE",
    )

    refusal_relative = (
        "sdk/qsdk_r10b_development_route_ghost_authority_check_refusal_v1.json"
    )
    refusal = committed_file_identity(SOURCE_COMMIT, refusal_relative)
    refusal["historical_result_rewritten"] = False
    require(
        graph.get("superseded_prephysics_refusal") == refusal,
        "PREPHYSICS_REFUSAL_IDENTITY_DRIFT",
    )


def validate_qualification(closure: dict[str, Any]) -> None:
    boundary = closure.get("zero_world_authorization_boundary")
    require(isinstance(boundary, dict), "ZERO_WORLD_BOUNDARY_MISSING")
    require(
        Path(str(boundary.get("official_qualification_evidence_root", ""))).resolve()
        == QUALIFICATION_ROOT.resolve(),
        "QUALIFICATION_ROOT_DRIFT",
    )
    files = sorted(
        (path for path in QUALIFICATION_ROOT.iterdir() if path.is_file()),
        key=lambda path: path.name,
    )
    require(len(files) == 5, "QUALIFICATION_FILE_COUNT_DRIFT")
    require(
        sum(path.stat().st_size for path in files) == 11_974,
        "QUALIFICATION_BYTE_COUNT_DRIFT",
    )
    completion = QUALIFICATION_ROOT / "qualification_completion.json"
    require(
        sha256_bytes(completion.read_bytes())
        == "sha256:4eaa962f7a8287d01d981f57a790486123e65ce0c254ca5cc1381fdcc046d681",
        "QUALIFICATION_COMPLETION_DIGEST_DRIFT",
    )
    receipt = read_json(
        QUALIFICATION_ROOT / "qualification_receipt.json", "QUALIFICATION_RECEIPT"
    )
    require(
        receipt.get("schema_version")
        == "sporespore_qsdk_r10b_zero_world_implementation_audit_v2"
        and receipt.get("source_commit") == SOURCE_COMMIT
        and receipt.get("official_qualification_mode") is True
        and receipt.get("worktree_clean") is True
        and receipt.get("head_origin_main_equal") is True
        and receipt.get("head_live_remote_main_equal") is True
        and receipt.get("qualified_source_path_count") == 70
        and receipt.get("qualified_source_path_sha256")
        == "sha256:76c421b1c1ab637046c847050fcc38d298f678cae4a6c875732bcf088941fc23",
        "QUALIFICATION_RECEIPT_DRIFT",
    )
    require(
        boundary.get("committed_graph_authority_check_passed") is True
        and boundary.get("standalone_authority_check_console_receipt_retained") is False
        and boundary.get(
            "physical_mode_revalidated_the_same_committed_graph_before_attempt"
        )
        is True,
        "AUTHORITY_CHECK_RETENTION_BOUNDARY_DRIFT",
    )
    for field in (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "native_readback_count",
        "solver_step_count",
        "locomotion_outcome_exposure_count",
    ):
        require(receipt.get(field) == 0, f"QUALIFICATION_NONZERO_{field.upper()}")


def marker_payload(path: Path) -> str:
    lines = [
        line
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.startswith(CELL_MARKER)
    ]
    require(len(lines) == 1, f"CELL_MARKER_COUNT:{path.name}")
    return lines[0][len(CELL_MARKER) :]


def vector_norm_delta(values: list[Any]) -> float:
    return abs(math.sqrt(sum(float(value) ** 2 for value in values)) - 1.0)


def validate_physical_evidence(closure: dict[str, Any]) -> dict[str, Any]:
    physical = closure.get("physical_attempt")
    require(isinstance(physical, dict), "PHYSICAL_ATTEMPT_MISSING")
    require(
        Path(str(physical.get("evidence_root", ""))).resolve()
        == EVIDENCE_ROOT.resolve(),
        "PHYSICAL_EVIDENCE_ROOT_DRIFT",
    )
    files = sorted(
        (path for path in EVIDENCE_ROOT.rglob("*") if path.is_file()),
        key=lambda path: path.relative_to(EVIDENCE_ROOT).as_posix(),
    )
    identities = [file_identity(path, EVIDENCE_ROOT) for path in files]
    require(identities == EXPECTED_EVIDENCE_FILES, "PHYSICAL_FILE_TREE_DRIFT")
    require(
        physical.get("retained_tree")
        == {
            "schema_version": "sporespore_retained_file_tree_manifest_v1",
            "file_count": 4,
            "total_byte_length": 6_561_324,
            "manifest_canonical_byte_length": 581,
            "manifest_canonical_sha256": (
                "sha256:c3d08863f43ba335100a5c20044663d77ec861b5d80aa03551ac831c5f367dfc"
            ),
            "files": EXPECTED_EVIDENCE_FILES,
        },
        "PHYSICAL_TREE_DECLARATION_DRIFT",
    )
    require(
        len(canonical_bytes(identities)) == 581
        and sha256_bytes(canonical_bytes(identities))
        == "sha256:c3d08863f43ba335100a5c20044663d77ec861b5d80aa03551ac831c5f367dfc",
        "PHYSICAL_TREE_MANIFEST_DRIFT",
    )
    require(
        (EVIDENCE_ROOT / "baseline_s50300/stderr.log").read_bytes() == b"",
        "PHYSICAL_STDERR_NOT_EMPTY",
    )

    attempt = read_json(
        EVIDENCE_ROOT / "baseline_s50300/attempt.json", "PHYSICAL_ATTEMPT_RECORD"
    )
    lock = attempt.get("operation_lock")
    require(
        attempt.get("schema_version") == "sporespore_qsdk_r10b_physical_attempt_v2"
        and attempt.get("campaign_role") == "development_route_ghost"
        and attempt.get("arm_id") == "matched_no_impulse_control"
        and attempt.get("campaign_seed") == 50300
        and attempt.get("cell_id") == "baseline_s50300"
        and attempt.get("source_commit") == SOURCE_COMMIT
        and attempt.get("authorization_commit") == AUTHORITY_COMMIT
        and attempt.get("maximum_world_attempt_count") == 1
        and attempt.get("maximum_world_build_count") == 1
        and attempt.get("same_identity_rerun_permitted") is False
        and isinstance(lock, dict)
        and lock.get("acquired") is True
        and lock.get("role") == "physical_development"
        and lock.get("created_new") is True
        and lock.get("abandoned_owner_recovered") is False,
        "PHYSICAL_ATTEMPT_RECORD_DRIFT",
    )

    stdout_payload = marker_payload(EVIDENCE_ROOT / "baseline_s50300/stdout.log")
    godot_payload = marker_payload(EVIDENCE_ROOT / "baseline_s50300/godot.log")
    require(stdout_payload == godot_payload, "CELL_MARKER_PAYLOAD_MISMATCH")
    raw_payload = stdout_payload.encode("utf-8")
    cell = json.loads(stdout_payload)
    require(isinstance(cell, dict), "CELL_MARKER_NOT_OBJECT")
    require(
        len(raw_payload) == 3_260_331
        and sha256_bytes(raw_payload)
        == "sha256:9755997926ecca5691583888deacd6efcca1e8c6f3a7d9586cf9467de335477d"
        and len(canonical_bytes(cell)) == 3_260_294
        and sha256_bytes(canonical_bytes(cell))
        == "sha256:a0985ec3642c9a8444f6bbdf8d60f79d21eea0b4e21fe15008ddd4b31f9e5d2f",
        "CELL_MARKER_IDENTITY_DRIFT",
    )
    evaluation = cell.get("evaluation")
    runtime = cell.get("runtime_summary_projection")
    trace = cell.get("sdk_physical_trace")
    require(
        cell.get("schema_version") == "sporespore_qsdk_r10b_physical_cell_v2"
        and cell.get("source_commit") == SOURCE_COMMIT
        and cell.get("cell_id") == "baseline_s50300"
        and cell.get("world_build_count") == 1
        and cell.get("world_reset_count") == 0
        and cell.get("evidence_valid") is False
        and cell.get("outcome_complete") is False
        and cell.get("behavior_passed") is False
        and isinstance(evaluation, dict)
        and evaluation.get("ok") is False
        and evaluation.get("failure_code") == "QSDK_R10B_TRACE_ROW_KINEMATICS_INVALID"
        and isinstance(runtime, dict)
        and runtime.get("ok") is False
        and runtime.get("failure_code") == "PHYSICAL_WAVE_GAIT_WALKING_NOT_ESTABLISHED"
        and runtime.get("physical_wave_gait_walking_observed") is False
        and runtime.get("world_build_count") == 1
        and runtime.get("world_reset_count") == 0
        and runtime.get("executed_ticks") == 2880
        and runtime.get("sdk_adapter_start_tick") == 240
        and runtime.get("external_push_application_count") == 0
        and runtime.get("physics_engine") == "Jolt Physics"
        and runtime.get("physics_hz") == 120
        and runtime.get("solver_velocity_steps") == 20
        and runtime.get("solver_position_steps") == 7
        and isinstance(trace, dict)
        and trace.get("enabled") is True
        and trace.get("row_count") == 2640
        and trace.get("failure_codes") == [],
        "CELL_TERMINAL_FIELDS_DRIFT",
    )
    sdk_summary = runtime.get("sdk_authority_summary")
    rows = trace.get("rows")
    require(
        isinstance(sdk_summary, dict)
        and sdk_summary.get("step_count") == 2640
        and isinstance(rows, list)
        and len(rows) == 2640,
        "CELL_TRACE_CARDINALITY_DRIFT",
    )
    walking = runtime.get("walking_gate_receipts")
    require(isinstance(walking, dict), "WALKING_RECEIPTS_MISSING")
    require(
        [key for key, value in walking.items() if value is not True]
        == ["bounded_anchor_error"],
        "WALKING_RECEIPT_PROJECTION_DRIFT",
    )

    metrics: list[dict[str, Any]] = []
    for index, row_value in enumerate(rows):
        require(isinstance(row_value, dict), f"TRACE_ROW_NOT_OBJECT:{index}")
        row = row_value
        require(
            row.get("schema_version")
            == "sporespore_qsdk_r10b_bounded_upright_push_recovery_trace_row_v1"
            and row.get("cell_id") == "baseline_s50300"
            and row.get("semantic_step") == index,
            f"TRACE_ROW_HEADER_DRIFT:{index}",
        )
        forward = row.get("task_frame_forward_axis_world_unit")
        lateral = row.get("task_frame_lateral_axis_world_unit")
        quaternion = row.get("torso_orientation_xyzw")
        require(
            isinstance(forward, list)
            and len(forward) == 3
            and isinstance(lateral, list)
            and len(lateral) == 3
            and isinstance(quaternion, list)
            and len(quaternion) == 4,
            f"TRACE_ROW_VECTOR_SHAPE:{index}",
        )
        finite_values = [
            *row.get("torso_position_world_m", []),
            *row.get("torso_linear_velocity_world_m_s", []),
            *row.get("torso_angular_velocity_world_rad_s", []),
            *forward,
            *lateral,
            *quaternion,
            row.get("torso_tilt_rad"),
        ]
        metrics.append(
            {
                "row": index,
                "quaternion_norm_delta": vector_norm_delta(quaternion),
                "quaternion_norm_squared_delta": abs(
                    sum(float(value) ** 2 for value in quaternion) - 1.0
                ),
                "forward_norm_delta": vector_norm_delta(forward),
                "lateral_norm_delta": vector_norm_delta(lateral),
                "axis_dot_abs": abs(
                    sum(
                        float(left) * float(right)
                        for left, right in zip(forward, lateral)
                    )
                ),
                "all_finite": all(
                    math.isfinite(float(value)) for value in finite_values
                ),
                "tilt_nonnegative": float(row.get("torso_tilt_rad")) >= 0.0,
            }
        )

    first = next(
        metric
        for metric in metrics
        if metric["quaternion_norm_delta"] > QUATERNION_NORM_TOLERANCE
    )
    maximum = max(metrics, key=lambda metric: metric["quaternion_norm_delta"])
    require(first["row"] == 0, "FIRST_QUATERNION_REFUSAL_ROW_DRIFT")
    require(maximum["row"] == 1889, "MAXIMUM_QUATERNION_REFUSAL_ROW_DRIFT")
    require(
        math.isclose(
            first["quaternion_norm_delta"],
            8.789622585325674e-9,
            rel_tol=0.0,
            abs_tol=1.0e-20,
        )
        and math.isclose(
            first["quaternion_norm_squared_delta"],
            1.7579245392695952e-8,
            rel_tol=0.0,
            abs_tol=1.0e-20,
        )
        and math.isclose(
            maximum["quaternion_norm_delta"],
            1.185268823089558e-7,
            rel_tol=0.0,
            abs_tol=1.0e-20,
        )
        and math.isclose(
            maximum["quaternion_norm_squared_delta"],
            2.3705377860672172e-7,
            rel_tol=0.0,
            abs_tol=1.0e-20,
        ),
        "QUATERNION_DELTA_DRIFT",
    )
    require(
        sum(
            metric["quaternion_norm_delta"] > QUATERNION_NORM_TOLERANCE
            for metric in metrics
        )
        == 2566,
        "QUATERNION_REFUSAL_COUNT_DRIFT",
    )
    require(
        all(metric["all_finite"] for metric in metrics)
        and all(metric["tilt_nonnegative"] for metric in metrics)
        and max(metric["forward_norm_delta"] for metric in metrics) == 0.0
        and max(metric["lateral_norm_delta"] for metric in metrics) == 0.0
        and max(metric["axis_dot_abs"] for metric in metrics) == 0.0,
        "NONQUATERNION_KINEMATICS_DRIFT",
    )
    require(
        not (EVIDENCE_ROOT / "baseline_s50300/cell.json").exists()
        and not (EVIDENCE_ROOT / "push_s50300").exists()
        and not (EVIDENCE_ROOT / "pair-s50300.json").exists()
        and not (EVIDENCE_ROOT / "report.json").exists(),
        "UNEXPECTED_POST_FAILURE_ARTIFACT",
    )
    return {
        "trace_row_count": len(rows),
        "quaternion_refusal_count": 2566,
        "first_refusal_row": first["row"],
        "maximum_refusal_row": maximum["row"],
    }


def validate_repair_precedent(closure: dict[str, Any]) -> None:
    precedent = closure.get("qualified_repair_precedent")
    require(isinstance(precedent, dict), "R66_PRECEDENT_MISSING")
    require(
        R66_CONTRACT_PATH.stat().st_size == 21_092
        and sha256_bytes(R66_CONTRACT_PATH.read_bytes())
        == "sha256:2860d75b05bf5ae1662ef73bf9585915b997e760ee392b8ba98c4b7f45665ece",
        "R66_CONTRACT_IDENTITY_DRIFT",
    )
    require(
        R66_CLOSURE_PATH.stat().st_size == 22_541
        and sha256_bytes(R66_CLOSURE_PATH.read_bytes())
        == "sha256:09287ca8ac4075bacc85b8abae963e61695544e331395dd1604f6511d5a329af",
        "R66_CLOSURE_IDENTITY_DRIFT",
    )
    r66 = read_json(R66_CLOSURE_PATH, "R66_CLOSURE")
    require(
        r66.get("source", {}).get("source_freeze_commit") == R66_SOURCE_COMMIT
        and r66.get("decision", {}).get("result")
        == "positive_zero_world_exact_quaternion_projection_qualified"
        and r66.get("decision", {}).get(
            "projected_quaternions_accepted_by_unchanged_core_validator"
        )
        is True,
        "R66_CLOSURE_SEMANTICS_DRIFT",
    )
    historical_world = committed_file_identity(
        R66_SOURCE_COMMIT,
        "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd",
    )
    require(
        historical_world
        == {
            "path": "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd",
            "git_blob_oid": "f588c44e0fe3cbc7073654fd49a29746b380f96b",
            "byte_length": 92_595,
            "raw_sha256": (
                "sha256:6667e71553a5d43dcc18b35a64a7e272a597a8d14e7b22d4b15f0e5f77d64a5d"
            ),
        },
        "R66_HISTORICAL_IMPLEMENTATION_DRIFT",
    )
    source_world = bytes(
        git(
            (
                "show",
                f"{SOURCE_COMMIT}:scripts/lab/gait/physical_wave_gait_quadruped.gd",
            ),
            binary=True,
        )
    ).decode("utf-8")
    evaluator = bytes(
        git(
            (
                "show",
                f"{SOURCE_COMMIT}:scripts/lab/gait/qsdk_r10b_bounded_upright_push_recovery.gd",
            ),
            binary=True,
        )
    ).decode("utf-8")
    require(
        "var orientation := torso_orientation.normalized()" in source_world
        and 'row["torso_orientation_xyzw"] = [' in source_world,
        "R10B_RAW_ORIENTATION_SOURCE_NOT_BOUND",
    )
    require(
        "const QUATERNION_NORM_TOLERANCE := 1.0e-9" in evaluator
        and "absf(orientation.length() - 1.0) > QUATERNION_NORM_TOLERANCE" in evaluator,
        "R10B_QUATERNION_VALIDATOR_NOT_BOUND",
    )


def validate_closure_document(closure: dict[str, Any]) -> None:
    require(
        closure.get("schema_version")
        == "sporespore_qsdk_r10b_l1_development_route_ghost_physical_invalid_closure_v1"
        and closure.get("status")
        == "closed_consumed_infrastructure_invalid_baseline_trace_quaternion_projection"
        and closure.get("gate_id") == "QSDK-R10B"
        and closure.get("repair_id") == "QSDK-R10B-L1"
        and closure.get("closure_id") == "QSDK-R10B-L1-P1"
        and closure.get("campaign_role") == "development_route_ghost"
        and closure.get("question_class") == "development",
        "CLOSURE_IDENTITY_DRIFT",
    )
    require(
        closure.get("ledger_scope")
        == {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "retained_consumed_physical_development_invalid_closure",
            "question_class": "development",
        },
        "CLOSURE_LEDGER_SCOPE_DRIFT",
    )
    physical = closure.get("physical_attempt", {})
    decision = closure.get("decision", {})
    successor = closure.get("successor_boundary", {})
    claims = closure.get("claim_boundary", {})
    require(
        physical.get("physical_identity_consumed") is True
        and physical.get("same_identity_rerun_permitted") is False
        and physical.get("attempted_cell_count") == 1
        and physical.get("completed_valid_cell_count") == 0
        and physical.get("unattempted_cell_ids") == ["push_s50300"],
        "CLOSURE_PHYSICAL_BOUNDARY_DRIFT",
    )
    require(
        decision.get("valid_positive_or_negative_route_result_observed") is False
        and decision.get("selected_successor_id") == "QSDK-R10B-L2"
        and decision.get("behavior_threshold_changed") is False
        and decision.get("quaternion_validator_tolerance_changed") is False
        and decision.get("historical_result_rewritten") is False,
        "CLOSURE_DECISION_DRIFT",
    )
    require(
        successor.get("method_id")
        == "godot_real_t_to_float64_largest_component_unit_reconstruction_v1"
        and successor.get("physical_execution_blocked") is True
        and successor.get("maximum_world_attempt_count_before_qualification") == 0
        and successor.get("maximum_world_build_count_before_qualification") == 0
        and successor.get("held_out_cells_remain_sealed") is True,
        "CLOSURE_SUCCESSOR_BOUNDARY_DRIFT",
    )
    require(
        claims.get("one_genuine_godot_jolt_world_claimed") is True
        and claims.get("trace_quaternion_representation_failure_claimed") is True
        and claims.get("bounded_upright_push_recovery_claimed") is False
        and claims.get("ordinary_walking_negative_claimed") is False
        and claims.get("external_push_effect_claimed") is False
        and claims.get("physical_acceptance_authority") is False
        and claims.get("release_authority") is False,
        "CLOSURE_CLAIM_BOUNDARY_DRIFT",
    )


def main() -> int:
    try:
        validate_repository_identity()
        closure = read_json(CLOSURE_PATH, "R10B_L1_PHYSICAL_INVALID_CLOSURE")
        validate_closure_document(closure)
        validate_source_graph(closure)
        validate_qualification(closure)
        physical = validate_physical_evidence(closure)
        validate_repair_precedent(closure)
        receipt = {
            "schema_version": (
                "sporespore_qsdk_r10b_l1_development_route_ghost_"
                "physical_invalid_closure_audit_v1"
            ),
            "gate_id": "QSDK-R10B",
            "repair_id": "QSDK-R10B-L1",
            "closure_id": "QSDK-R10B-L1-P1",
            "ok": True,
            "failure_code": "",
            "retained_file_count": 4,
            "retained_total_byte_length": 6_561_324,
            "retained_world_attempt_count": 1,
            "retained_world_build_count": 1,
            "retained_physics_tick_count": 2880,
            "retained_trace_row_count": physical["trace_row_count"],
            "quaternion_tolerance_violating_row_count": physical[
                "quaternion_refusal_count"
            ],
            "first_quaternion_refusal_row": physical["first_refusal_row"],
            "maximum_quaternion_refusal_row": physical["maximum_refusal_row"],
            "push_world_attempt_count": 0,
            "pair_evaluator_invocation_count": 0,
            "valid_behavior_result_count": 0,
            "physical_identity_consumed": True,
            "same_identity_rerun_permitted": False,
            "selected_successor_id": "QSDK-R10B-L2",
            "quaternion_validator_tolerance_changed": False,
            "audit_model_construction_count": 0,
            "audit_world_attempt_count": 0,
            "audit_world_build_count": 0,
            "audit_native_readback_count": 0,
            "audit_solver_step_count": 0,
            "audit_physics_state_modified": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        }
        print(PASS_MARKER + json.dumps(receipt, sort_keys=True, separators=(",", ":")))
        return 0
    except (ClosureFailure, OSError, UnicodeError, json.JSONDecodeError) as exc:
        print(f"QSDK_R10B_L1_PHYSICAL_INVALID_CLOSURE_FAIL {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
