#!/usr/bin/env python3
"""Audit the consumed QSDK-R10B-L3 route ghost without opening a world."""

from __future__ import annotations

import copy
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
    r"\qsdk-r10b-development-route-ghost-physical-ce048f2b8390"
)
QUALIFICATION_ROOT = Path(
    r"C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
    r"\qsdk-r10b-development-route-ghost-zero-world-qualification-ce048f2b8390"
)
CLOSURE_PATH = ROOT / "sdk/qsdk_r10b_development_route_ghost_physical_closure_v1.json"
SOURCE_COMMIT = "ce048f2b83903c04190b5ad226f1b4f12953a252"
STAGE_COMMIT = "aacda2c036637f081a54a2b3c6c3dc3a7a527450"
AUTHORITY_COMMIT = "fa94feae96cfbf7837354888499e87fd8c3d0ae4"
CAMPAIGN_ID = "QSDK-R10B-BOUNDED-UPRIGHT-PUSH-RECOVERY-ROUTE-GHOST"
CELL_MARKER = "QSDK_R10B_PHYSICAL_CELL "
PASS_MARKER = "QSDK_R10B_DEVELOPMENT_ROUTE_GHOST_PHYSICAL_CLOSURE_PASS "

EXPECTED_EVIDENCE_FILES = [
    {
        "path": "baseline_s50300/attempt.json",
        "byte_length": 2470,
        "raw_sha256": "sha256:3c2c884e4507d9281d7599dd617b74d24552a2880811dbac4b574867dcba35df",
    },
    {
        "path": "baseline_s50300/cell.json",
        "byte_length": 6564166,
        "raw_sha256": "sha256:19dea25c92b5ea4636b3b91975e19ed84f65598b06e328d3df63000f3dd21cfe",
    },
    {
        "path": "baseline_s50300/godot.log",
        "byte_length": 6583471,
        "raw_sha256": "sha256:2c357403d3d545b67850e30ea86846e3e698694cbf4e7c88a0e7edef43716101",
    },
    {
        "path": "baseline_s50300/stderr.log",
        "byte_length": 0,
        "raw_sha256": "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    },
    {
        "path": "baseline_s50300/stdout.log",
        "byte_length": 6583602,
        "raw_sha256": "sha256:ed2920f25b19bf6bbe20dda88637644362335b18630fddb7fb675f04a66f15a6",
    },
    {
        "path": "pair-s50300-runtime/appdata/Godot/app_userdata/sporespore/logs/godot.log",
        "byte_length": 1219,
        "raw_sha256": "sha256:f2e072c7dda9aed5199452ed3081edf8c4a3ca71964d1ca82b1b1a4888802d3f",
    },
    {
        "path": "pair-s50300.json",
        "byte_length": 1105,
        "raw_sha256": "sha256:959c60c0a8aa9f97575b0221206ee12ad4462360fea93529046f455f0e1e8c82",
    },
    {
        "path": "push_s50300/attempt.json",
        "byte_length": 2463,
        "raw_sha256": "sha256:1fb67274d80013aec173fc2ffaee6dcd9efac234a99ce4d8f1baf7c50f3e3b27",
    },
    {
        "path": "push_s50300/cell.json",
        "byte_length": 6531967,
        "raw_sha256": "sha256:efac419860a63866b50a9e291c3f6e6115fab454ae6e1130af6a2d3b3b6bc4b9",
    },
    {
        "path": "push_s50300/godot.log",
        "byte_length": 6551255,
        "raw_sha256": "sha256:1dcb65ed9cbe16230f611e2ad4e11965ea7c1ecb17eb21954cdd9ad0273807db",
    },
    {
        "path": "push_s50300/stderr.log",
        "byte_length": 0,
        "raw_sha256": "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    },
    {
        "path": "push_s50300/stdout.log",
        "byte_length": 6551386,
        "raw_sha256": "sha256:81734703cace970a781985dc7b568b8142149d8322952f52161723d51e37e035",
    },
    {
        "path": "report.json",
        "byte_length": 3371,
        "raw_sha256": "sha256:64f4e3ce155cfcc379b08fa5ec0bd578012f809d344dc04715a1af0d62d173d5",
    },
]

EXPECTED_QUALIFICATION_FILES = [
    {
        "path": "audit_stderr.log",
        "byte_length": 0,
        "raw_sha256": "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    },
    {
        "path": "audit_stdout.log",
        "byte_length": 6569,
        "raw_sha256": "sha256:7b357f2ef990c0452281e74802d66f85587c54ff764f0ef3d0b90f985ffa3277",
    },
    {
        "path": "qualification_attempt.json",
        "byte_length": 2031,
        "raw_sha256": "sha256:03f8eeb06acf14b05f49a3a958ced2361dc3562f51ba059cc270a1f89f06484c",
    },
    {
        "path": "qualification_completion.json",
        "byte_length": 1840,
        "raw_sha256": "sha256:e9e466bdb80256a6c034f9d9e1b0d109bd0ed217d3af322609f1f48b8d2d8f15",
    },
    {
        "path": "qualification_receipt.json",
        "byte_length": 7456,
        "raw_sha256": "sha256:751cfb6c52a3adeb522fc12ebb7d39d31f1e701cfe6b764101415227d0ec8906",
    },
]

EXPECTED_WALKING_RECEIPTS = {
    "bounded_anchor_error",
    "bounded_hinge_axis_error",
    "bounded_joint_only_lateral_stride_steering",
    "bounded_lateral_drift",
    "bounded_tilt",
    "bounded_torso_height",
    "bounded_yaw_drift",
    "contact_gated_evidence_horizon_completed",
    "contact_gating_completed_without_timeout",
    "every_contact_observer_executed",
    "every_limb_completed_evidence_gait_horizon",
    "every_limb_forward_relocation",
    "every_limb_two_contact_cycles",
    "evidence_four_contact_stance",
    "explicit_sdk_controller_session_shutdown",
    "fixture_spec_compiled_before_world_creation",
    "initial_four_contact_stance",
    "initial_perturbation_within_declared_envelope",
    "minimum_evidence_forward_translation",
    "minimum_final_forward_translation",
    "native_sdk_exclusive_post_settle_actuation",
    "no_torso_force_or_impulse_or_velocity_or_transform_command",
    "no_world_reset",
    "one_continuous_world",
    "pinned_jolt_solver_settings",
    "terminal_four_contact_recovery",
    "zero_torso_contact",
}
EXPECTED_LIMBS = {"front_left", "front_right", "rear_left", "rear_right"}
ZERO_COUNTERS = (
    "model_construction_count",
    "world_attempt_count",
    "world_build_count",
    "native_readback_count",
    "solver_step_count",
)


class ClosureFailure(RuntimeError):
    """The retained route-ghost closure was not exact."""


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


def tree_manifest(root: Path) -> list[dict[str, Any]]:
    require(root.is_dir(), f"EVIDENCE_ROOT_MISSING:{root}")
    return [
        file_identity(path, root)
        for path in sorted(
            root.rglob("*"), key=lambda item: item.relative_to(root).as_posix()
        )
        if path.is_file()
    ]


def commit_identity(commit: str) -> dict[str, str]:
    return {
        "commit": commit,
        "parent_commit": str(git(("show", "-s", "--format=%P", commit))),
        "tree": str(git(("show", "-s", "--format=%T", commit))),
        "subject": str(git(("show", "-s", "--format=%s", commit))),
    }


def committed_file_identity(
    commit: str, relative: str, *, blob_key: str = "git_blob_oid"
) -> dict[str, Any]:
    raw = bytes(git(("show", f"{commit}:{relative}"), binary=True))
    return {
        "path": relative,
        blob_key: str(git(("rev-parse", f"{commit}:{relative}"))),
        "byte_length": len(raw),
        "raw_sha256": sha256_bytes(raw),
    }


def marker_payload(path: Path) -> dict[str, Any]:
    lines = [
        line
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.startswith(CELL_MARKER)
    ]
    require(len(lines) == 1, f"CELL_MARKER_COUNT:{path}")
    try:
        value = json.loads(lines[0][len(CELL_MARKER) :])
    except json.JSONDecodeError as exc:
        raise ClosureFailure(f"CELL_MARKER_INVALID_JSON:{path.name}:{exc}") from exc
    require(isinstance(value, dict), f"CELL_MARKER_NOT_OBJECT:{path.name}")
    return value


def numeric_array(value: Any, size: int, label: str) -> list[float]:
    require(isinstance(value, list) and len(value) == size, f"{label}_SHAPE")
    require(
        all(
            isinstance(item, (int, float))
            and not isinstance(item, bool)
            and math.isfinite(float(item))
            for item in value
        ),
        f"{label}_NONFINITE_OR_TYPE",
    )
    return [float(item) for item in value]


def validate_repository_identity() -> None:
    require(ROOT.resolve() == EXPECTED_ROOT.resolve(), "WRONG_SCRIPT_ROOT")
    require(
        Path(str(git(("rev-parse", "--show-toplevel")))).resolve()
        == EXPECTED_ROOT.resolve(),
        "WRONG_GIT_ROOT",
    )
    require(
        str(git(("remote", "get-url", "origin"))) == EXPECTED_REMOTE, "WRONG_REMOTE"
    )


def validate_source_graph(closure: dict[str, Any]) -> None:
    graph = closure.get("source_graph")
    require(isinstance(graph, dict), "SOURCE_GRAPH_MISSING")
    require(
        graph.get("implementation_source") == commit_identity(SOURCE_COMMIT),
        "SOURCE_IDENTITY_DRIFT",
    )

    stage_relative = (
        "sdk/qsdk_r10b_development_route_ghost_"
        "zero_world_qualification_closure_v4.json"
    )
    expected_stage = {
        **commit_identity(STAGE_COMMIT),
        **committed_file_identity(STAGE_COMMIT, stage_relative),
    }
    require(graph.get("stage_freeze") == expected_stage, "STAGE_IDENTITY_DRIFT")
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
        "sdk/qsdk_r10b_development_route_ghost_execution_authority_v4.json"
    )
    expected_authority = {
        **commit_identity(AUTHORITY_COMMIT),
        **committed_file_identity(AUTHORITY_COMMIT, authority_relative),
    }
    require(
        graph.get("execution_authority") == expected_authority,
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

    bindings = (
        (
            "l3_successor_design",
            "sdk/qsdk_r10b_l3_serialization_stable_trace_validation_successor_design_v1.json",
            False,
        ),
        (
            "consumed_l2_closure",
            "sdk/qsdk_r10b_l2_development_route_ghost_physical_invalid_closure_v1.json",
            True,
        ),
        (
            "consumed_l1_closure",
            "sdk/qsdk_r10b_l1_development_route_ghost_physical_invalid_closure_v1.json",
            True,
        ),
    )
    for key, relative, historical in bindings:
        expected = committed_file_identity(
            SOURCE_COMMIT, relative, blob_key="git_blob_oid_at_source_commit"
        )
        if historical:
            expected["historical_result_rewritten"] = False
        require(graph.get(key) == expected, f"{key.upper()}_IDENTITY_DRIFT")


def validate_qualification(closure: dict[str, Any]) -> None:
    boundary = closure.get("zero_world_authorization_boundary")
    require(isinstance(boundary, dict), "QUALIFICATION_BOUNDARY_MISSING")
    observed = tree_manifest(QUALIFICATION_ROOT)
    require(observed == EXPECTED_QUALIFICATION_FILES, "QUALIFICATION_TREE_DRIFT")
    canonical = canonical_bytes(observed)
    require(
        boundary.get("qualification_files") == observed, "QUALIFICATION_FILES_DRIFT"
    )
    require(boundary.get("qualification_file_count") == 5, "QUALIFICATION_FILE_COUNT")
    require(
        boundary.get("qualification_total_byte_length")
        == sum(int(item["byte_length"]) for item in observed),
        "QUALIFICATION_TOTAL_BYTES",
    )
    require(
        boundary.get("qualification_tree_manifest_canonical_byte_length")
        == len(canonical),
        "QUALIFICATION_MANIFEST_BYTES",
    )
    require(
        boundary.get("qualification_tree_manifest_sha256") == sha256_bytes(canonical),
        "QUALIFICATION_MANIFEST_SHA",
    )
    require(
        Path(str(boundary.get("official_qualification_evidence_root"))).resolve()
        == QUALIFICATION_ROOT.resolve(),
        "QUALIFICATION_ROOT",
    )

    completion = read_json(
        QUALIFICATION_ROOT / "qualification_completion.json", "QUALIFICATION_COMPLETION"
    )
    receipt = read_json(
        QUALIFICATION_ROOT / "qualification_receipt.json", "QUALIFICATION_RECEIPT"
    )
    require(
        completion.get("schema_version")
        == "sporespore_qsdk_r10b_zero_world_qualification_completion_v4",
        "QUALIFICATION_COMPLETION_SCHEMA",
    )
    require(
        completion.get("campaign_role") == "development_route_ghost",
        "QUALIFICATION_ROLE",
    )
    require(
        completion.get("status") == "complete_valid_official_zero_world_qualification",
        "QUALIFICATION_STATUS",
    )
    require(
        completion.get("official_zero_world_qualification_passed") is True,
        "QUALIFICATION_NOT_PASSING",
    )
    require(
        completion.get("physical_execution_authorized") is False
        and completion.get("physical_acceptance_authority") is False
        and completion.get("release_authority") is False,
        "QUALIFICATION_AUTHORITY",
    )
    require(
        receipt.get("schema_version")
        == "sporespore_qsdk_r10b_zero_world_implementation_audit_v4",
        "QUALIFICATION_RECEIPT_SCHEMA",
    )
    require(receipt.get("source_commit") == SOURCE_COMMIT, "QUALIFICATION_SOURCE")
    require(receipt.get("ok") is True, "QUALIFICATION_RECEIPT_NOT_OK")
    require(
        receipt.get("qualified_source_path_count") == 85
        and receipt.get("qualified_source_path_sha256")
        == "sha256:4bfe0e8a7cbdb920655cb3082b6e2a7182f4f05ac76e24142a73acca640a7a8d",
        "QUALIFICATION_SOURCE_CLOSURE",
    )
    for counter in ZERO_COUNTERS:
        require(receipt.get(counter) == 0, f"QUALIFICATION_NONZERO_{counter.upper()}")
    require(
        receipt.get("locomotion_outcome_exposure_count") == 0
        and receipt.get("physics_state_modified") is False
        and receipt.get("physical_acceptance_authority") is False
        and receipt.get("release_authority") is False,
        "QUALIFICATION_ZERO_WORLD_BOUNDARY",
    )
    require(
        boundary.get("official_qualification_passed") is True,
        "CLOSURE_QUALIFICATION_FLAG",
    )
    require(
        boundary.get("committed_graph_authority_check_passed") is True,
        "CLOSURE_AUTHORITY_CHECK_FLAG",
    )
    for counter in ZERO_COUNTERS:
        key = f"authority_check_{counter}"
        require(boundary.get(key) == 0, f"CLOSURE_NONZERO_{key.upper()}")
    require(
        boundary.get("authority_check_locomotion_outcome_exposure_count") == 0,
        "CLOSURE_AUTHORITY_CHECK_OUTCOME_EXPOSURE",
    )


def validate_attempt_record(
    attempt: dict[str, Any], *, cell_id: str, arm_id: str
) -> None:
    require(
        attempt.get("schema_version") == "sporespore_qsdk_r10b_physical_attempt_v4",
        f"{cell_id}_ATTEMPT_SCHEMA",
    )
    require(attempt.get("campaign_id") == CAMPAIGN_ID, f"{cell_id}_ATTEMPT_CAMPAIGN")
    require(
        attempt.get("campaign_role") == "development_route_ghost",
        f"{cell_id}_ATTEMPT_ROLE",
    )
    require(
        attempt.get("cell_id") == cell_id
        and attempt.get("arm_id") == arm_id
        and attempt.get("campaign_seed") == 50300,
        f"{cell_id}_ATTEMPT_IDENTITY",
    )
    require(
        attempt.get("source_commit") == SOURCE_COMMIT
        and attempt.get("qualification_parent_commit") == SOURCE_COMMIT
        and attempt.get("authorization_commit") == AUTHORITY_COMMIT
        and attempt.get("authorization_parent_commit") == STAGE_COMMIT,
        f"{cell_id}_ATTEMPT_SOURCE_GRAPH",
    )
    require(
        attempt.get("stage_freeze_sha256")
        == "sha256:e5684ea18253c8bd550e481a0df1c80bbfaf0d6411dd6bcb7a7d2b4b7c289876"
        and attempt.get("execution_authority_sha256")
        == "sha256:d9f79ed34545d13dc3976ef0c859447e5d1f2b240e08fdd53a0877f744eae5e3",
        f"{cell_id}_ATTEMPT_AUTHORITY_HASH",
    )
    require(
        Path(str(attempt.get("output_root"))).resolve() == EVIDENCE_ROOT.resolve(),
        f"{cell_id}_ATTEMPT_OUTPUT_ROOT",
    )
    require(
        attempt.get("supervisor_physical_authorized") is True
        and attempt.get("synthetic_authorization_preflight") is False
        and attempt.get("same_identity_rerun_permitted") is False,
        f"{cell_id}_ATTEMPT_AUTHORIZATION",
    )
    require(
        attempt.get("maximum_world_attempt_count") == 1
        and attempt.get("maximum_world_build_count") == 1
        and attempt.get("world_attempt_count_before_worker") == 0
        and attempt.get("world_build_count_before_worker") == 0,
        f"{cell_id}_ATTEMPT_COUNTS",
    )
    token = attempt.get("authorization_token")
    require(isinstance(token, str) and len(token) == 32, f"{cell_id}_ATTEMPT_TOKEN")
    lock = attempt.get("operation_lock")
    require(isinstance(lock, dict), f"{cell_id}_LOCK_MISSING")
    require(
        lock.get("schema_version") == "sporespore_locomotion_operation_lock_receipt_v1"
        and lock.get("acquired") is True
        and lock.get("role") == "physical_development"
        and lock.get("created_new") is True
        and lock.get("abandoned_owner_recovered") is False
        and lock.get("test_only") is False
        and lock.get("physical_acceptance_authority") is False,
        f"{cell_id}_LOCK_INVALID",
    )


def validate_trace(cell: dict[str, Any], cell_id: str, expected_rows: int) -> None:
    trace = cell.get("sdk_physical_trace")
    require(isinstance(trace, dict), f"{cell_id}_TRACE_MISSING")
    rows = trace.get("rows")
    require(isinstance(rows, list), f"{cell_id}_TRACE_ROWS_NOT_ARRAY")
    require(
        trace.get("schema_version") == "sporespore_sdk_physical_trace_v1"
        and trace.get("enabled") is True
        and trace.get("failure_codes") == []
        and trace.get("row_count") == expected_rows
        and len(rows) == expected_rows
        and trace.get("world_build_count") == 1
        and trace.get("physical_acceptance_authority") is False,
        f"{cell_id}_TRACE_HEADER",
    )
    options = trace.get("options")
    require(isinstance(options, dict), f"{cell_id}_TRACE_OPTIONS")
    require(
        options.get("cell_id") == cell_id
        and options.get("policy_id")
        == "qsdk_r10b_bounded_upright_push_recovery_trace_v3"
        and options.get("push_marker_semantic_step") == 540
        and options.get("sampling_phase") == "post_physics_for_applied_semantic_step"
        and options.get("trace_row_schema_version")
        == "sporespore_qsdk_r10b_bounded_upright_push_recovery_trace_row_v3",
        f"{cell_id}_TRACE_POLICY",
    )
    for index, row in enumerate(rows):
        require(isinstance(row, dict), f"{cell_id}_ROW_NOT_OBJECT:{index}")
        require(
            row.get("schema_version")
            == "sporespore_qsdk_r10b_bounded_upright_push_recovery_trace_row_v3"
            and row.get("cell_id") == cell_id
            and row.get("semantic_step") == index
            and row.get("push_marker_semantic_step") == 540
            and row.get("sampling_phase") == "post_physics_for_applied_semantic_step"
            and row.get("post_physics_observation_complete") is True
            and row.get("observer_physics_state_modified") is False
            and row.get("validated_portable_command_count") == 8
            and row.get("native_actuation_application_count") == 8,
            f"{cell_id}_ROW_HEADER:{index}",
        )
        require(
            isinstance(row.get("torso_ground_contact"), bool),
            f"{cell_id}_ROW_TORSO_CONTACT:{index}",
        )
        contacts_before = row.get("ordered_foot_contacts_before")
        contacts_after = row.get("ordered_foot_contacts_after")
        require(
            isinstance(contacts_before, dict)
            and isinstance(contacts_after, dict)
            and set(contacts_before) == EXPECTED_LIMBS
            and set(contacts_after) == EXPECTED_LIMBS
            and all(isinstance(value, bool) for value in contacts_before.values())
            and all(isinstance(value, bool) for value in contacts_after.values()),
            f"{cell_id}_ROW_CONTACTS:{index}",
        )
        numeric_array(
            row.get("torso_position_world_m"), 3, f"{cell_id}_POSITION:{index}"
        )
        numeric_array(
            row.get("torso_orientation_xyzw"), 4, f"{cell_id}_ORIENTATION:{index}"
        )
        numeric_array(
            row.get("torso_linear_velocity_world_m_s"),
            3,
            f"{cell_id}_LINEAR_VELOCITY:{index}",
        )
        numeric_array(
            row.get("torso_angular_velocity_world_rad_s"),
            3,
            f"{cell_id}_ANGULAR_VELOCITY:{index}",
        )
        numeric_array(
            row.get("task_frame_forward_axis_world_unit"),
            3,
            f"{cell_id}_FORWARD_AXIS:{index}",
        )
        numeric_array(
            row.get("task_frame_lateral_axis_world_unit"),
            3,
            f"{cell_id}_LATERAL_AXIS:{index}",
        )
        tilt = row.get("torso_tilt_rad")
        require(
            isinstance(tilt, (int, float))
            and not isinstance(tilt, bool)
            and math.isfinite(float(tilt))
            and float(tilt) >= 0.0,
            f"{cell_id}_TILT:{index}",
        )
        projection = row.get("torso_orientation_projection")
        require(isinstance(projection, dict), f"{cell_id}_PROJECTION:{index}")
        require(
            projection.get("schema_version")
            == "sporespore_godot_quaternion_scalar_projection_v1"
            and projection.get("ok") is True
            and projection.get("support_status") == "supported_exact"
            and projection.get("within_core_unit_contract") is True
            and projection.get("projection_method_id")
            == "godot_real_t_to_float64_largest_component_unit_reconstruction_v1"
            and projection.get("qualified_precedent_gate_id") == "QSDK-R24D66"
            and projection.get("physical_acceptance_authority") is False
            and projection.get("release_authority") is False,
            f"{cell_id}_PROJECTION_HEADER:{index}",
        )
        for counter in ZERO_COUNTERS:
            require(
                projection.get(counter) == 0,
                f"{cell_id}_PROJECTION_NONZERO_{counter.upper()}:{index}",
            )


def false_receipts(receipts: dict[str, Any]) -> list[str]:
    require(set(receipts) == EXPECTED_WALKING_RECEIPTS, "WALKING_RECEIPT_KEYS")
    require(
        all(isinstance(value, bool) for value in receipts.values()),
        "WALKING_RECEIPT_TYPES",
    )
    return sorted(key for key, value in receipts.items() if not value)


def validate_pre_window(window: dict[str, Any], label: str) -> None:
    require(
        window.get("start_semantic_step") == 180
        and window.get("end_semantic_step_exclusive") == 540
        and window.get("duration_steps") == 360
        and window.get("minimum_task_frame_forward_advance_m") == 0.01
        and window.get("task_frame_forward_advance_m") == 0.09482558816671371,
        f"{label}_INTERVAL_OR_ADVANCE",
    )
    require(
        window.get("safe_envelope_passed") is True
        and window.get("forward_advance_passed") is True
        and window.get("command_application_passed") is True
        and window.get("every_limb_airborne_then_recontact") is False
        and window.get("passed") is False
        and window.get("failure_code") == "QSDK_R10B_WINDOW_REQUIREMENT_FAILED",
        f"{label}_RESULT",
    )
    cycles = window.get("contact_cycle_by_limb")
    require(
        isinstance(cycles, dict) and set(cycles) == EXPECTED_LIMBS, f"{label}_CYCLES"
    )
    require(
        cycles["front_left"]
        == {
            "longest_airborne_dwell_steps": 29,
            "passed": False,
            "qualifying_recontact_semantic_step": -1,
        },
        f"{label}_FRONT_LEFT",
    )
    require(
        all(
            cycles[limb].get("passed") is True
            for limb in EXPECTED_LIMBS - {"front_left"}
        ),
        f"{label}_OTHER_LIMBS",
    )


def validate_valid_window(
    window: dict[str, Any], *, expected_advance: float, label: str
) -> None:
    require(
        window.get("start_semantic_step") == 541
        and window.get("end_semantic_step_exclusive") == 901
        and window.get("duration_steps") == 360
        and window.get("minimum_task_frame_forward_advance_m") == 0.01
        and window.get("task_frame_forward_advance_m") == expected_advance,
        f"{label}_INTERVAL_OR_ADVANCE",
    )
    require(
        window.get("safe_envelope_passed") is True
        and window.get("forward_advance_passed") is True
        and window.get("command_application_passed") is True
        and window.get("every_limb_airborne_then_recontact") is True
        and window.get("passed") is True
        and window.get("failure_code") == "",
        f"{label}_RESULT",
    )
    cycles = window.get("contact_cycle_by_limb")
    require(
        isinstance(cycles, dict)
        and set(cycles) == EXPECTED_LIMBS
        and all(cycles[limb].get("passed") is True for limb in EXPECTED_LIMBS),
        f"{label}_CYCLES",
    )


def validate_cell(
    cell: dict[str, Any], *, cell_id: str, arm_id: str, expected_rows: int
) -> dict[str, Any]:
    require(
        cell.get("schema_version") == "sporespore_qsdk_r10b_physical_cell_v4",
        f"{cell_id}_SCHEMA",
    )
    require(
        cell.get("gate_id") == "QSDK-R10B"
        and cell.get("campaign_id") == CAMPAIGN_ID
        and cell.get("campaign_role") == "development_route_ghost"
        and cell.get("cell_id") == cell_id
        and cell.get("arm_id") == arm_id
        and cell.get("campaign_seed") == 50300,
        f"{cell_id}_IDENTITY",
    )
    require(
        cell.get("source_commit") == SOURCE_COMMIT
        and cell.get("world_build_count") == 1
        and cell.get("world_reset_count") == 0
        and cell.get("evidence_valid") is True
        and cell.get("outcome_complete") is True
        and cell.get("behavior_passed") is False
        and cell.get("physical_acceptance_authority") is False
        and cell.get("release_authority") is False,
        f"{cell_id}_OUTCOME",
    )
    require(
        cell.get("selected_candidate_id") == "BW5R-B"
        and cell.get("controller_policy_id") == "sporespore_balanced_wave_bw5r_b_v1"
        and cell.get("selected_policy_digest")
        == "sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f"
        and cell.get("material_profile_id") == "godot_jolt_bw5c_mu095_v1",
        f"{cell_id}_ENGINE_POLICY",
    )
    evaluation = cell.get("evaluation")
    require(isinstance(evaluation, dict), f"{cell_id}_EVALUATION_MISSING")
    require(
        evaluation.get("ok") is True
        and evaluation.get("failure_code") == ""
        and evaluation.get("outcome_complete") is True
        and evaluation.get("evidence_valid") is True
        and evaluation.get("behavior_passed") is False
        and evaluation.get("common_execution_integrity") is True
        and evaluation.get("walking_receipts_structurally_complete") is True
        and evaluation.get("ordinary_walking_passed") is False
        and evaluation.get("sdk_step_count") == expected_rows
        and evaluation.get("trace_row_count") == expected_rows
        and evaluation.get("evaluation_world_build_count") == 0,
        f"{cell_id}_EVALUATION",
    )
    receipts = evaluation.get("walking_gate_receipts")
    require(isinstance(receipts, dict), f"{cell_id}_WALKING_RECEIPTS")
    require(
        false_receipts(receipts) == ["bounded_anchor_error"],
        f"{cell_id}_WALKING_RESULT",
    )
    validate_pre_window(evaluation.get("pre_push_window", {}), f"{cell_id}_PRE_WINDOW")
    validate_trace(cell, cell_id, expected_rows)
    return evaluation


def validate_pair(
    pair: dict[str, Any],
    baseline_evaluation: dict[str, Any],
    push_evaluation: dict[str, Any],
) -> None:
    require(
        pair.get("schema_version") == "sporespore_qsdk_r10b_pair_evaluation_v1",
        "PAIR_SCHEMA",
    )
    require(
        pair.get("gate_id") == "QSDK-R10B"
        and pair.get("campaign_seed") == 50300
        and pair.get("baseline_cell_id") == "baseline_s50300"
        and pair.get("push_cell_id") == "push_s50300",
        "PAIR_IDENTITY",
    )
    require(
        pair.get("ok") is True
        and pair.get("failure_code") == ""
        and pair.get("outcome_complete") is True
        and pair.get("evidence_valid") is True
        and pair.get("matched_initial_perturbation") is True
        and pair.get("native_effect_confirmed") is True
        and pair.get("behavior_passed") is False
        and pair.get("baseline_behavior_passed") is False
        and pair.get("push_behavior_passed") is False,
        "PAIR_OUTCOME",
    )
    require(
        pair.get("baseline_cell_raw_sha256")
        == "sha256:19dea25c92b5ea4636b3b91975e19ed84f65598b06e328d3df63000f3dd21cfe"
        and pair.get("push_cell_raw_sha256")
        == "sha256:efac419860a63866b50a9e291c3f6e6115fab454ae6e1130af6a2d3b3b6bc4b9",
        "PAIR_CELL_HASHES",
    )
    require(
        pair.get("native_effect_magnitude_m_s") == 0.06133231520652771
        and pair.get("baseline_lateral_velocity_jump_m_s") == -0.002786065451800823
        and pair.get("push_lateral_velocity_jump_m_s") == 0.06055179238319397
        and pair.get("paired_lateral_velocity_jump_difference_m_s")
        == 0.06333785783499479,
        "PAIR_METRICS",
    )
    require(
        pair.get("world_attempt_count") == 0
        and pair.get("world_build_count") == 0
        and pair.get("evaluation_world_build_count") == 0
        and pair.get("model_construction_count") == 0
        and pair.get("native_readback_count") == 0
        and pair.get("solver_step_count") == 0
        and pair.get("scene_tree_insertion_count") == 0
        and pair.get("physics_state_modified") is False
        and pair.get("physical_acceptance_authority") is False
        and pair.get("release_authority") is False,
        "PAIR_ZERO_WORLD_EVALUATION",
    )
    require(
        baseline_evaluation.get("initial_perturbation_sha256")
        == push_evaluation.get("initial_perturbation_sha256")
        == "sha256:b85cba7197947f8ab455a0bb2b4750084560dd0cbc0caeb598526714d0388a12",
        "PAIR_INITIAL_PERTURBATION",
    )


def validate_report(report: dict[str, Any]) -> None:
    require(
        report.get("schema_version") == "sporespore_qsdk_r10b_physical_report_v4",
        "REPORT_SCHEMA",
    )
    require(
        report.get("gate_id") == "QSDK-R10B"
        and report.get("campaign_id") == CAMPAIGN_ID
        and report.get("campaign_role") == "development_route_ghost"
        and report.get("question_class") == "development",
        "REPORT_IDENTITY",
    )
    require(
        report.get("status") == "complete_valid_finite_negative"
        and report.get("complete") is True
        and report.get("behavior_passed") is False
        and report.get("world_attempt_count") == 2
        and report.get("world_build_count") == 2
        and report.get("expected_world_count") == 2
        and report.get("pair_count") == 1
        and report.get("same_identity_rerun_permitted") is False
        and report.get("physical_acceptance_authority") is False
        and report.get("release_authority") is False,
        "REPORT_RESULT",
    )
    require(
        report.get("ordered_cell_ids") == ["baseline_s50300", "push_s50300"],
        "REPORT_CELL_ORDER",
    )
    source = report.get("source")
    require(isinstance(source, dict), "REPORT_SOURCE_MISSING")
    require(
        source.get("source_freeze_commit") == SOURCE_COMMIT
        and source.get("qualification_parent_commit") == SOURCE_COMMIT
        and source.get("qualification_commit") == STAGE_COMMIT
        and source.get("authorization_commit") == AUTHORITY_COMMIT
        and source.get("authorization_tree")
        == "00db84ff46627f50b914f56391acb00649377284"
        and source.get("branch") == "main"
        and source.get("remote") == EXPECTED_REMOTE
        and source.get("origin_main_commit") == AUTHORITY_COMMIT
        and source.get("live_main_commit") == AUTHORITY_COMMIT
        and source.get("clean") is True,
        "REPORT_SOURCE_GRAPH",
    )
    require(
        Path(str(report.get("output_root"))).resolve() == EVIDENCE_ROOT.resolve(),
        "REPORT_OUTPUT_ROOT",
    )
    require(
        report.get("stage_freeze_sha256")
        == "sha256:e5684ea18253c8bd550e481a0df1c80bbfaf0d6411dd6bcb7a7d2b4b7c289876"
        and report.get("execution_authority_sha256")
        == "sha256:d9f79ed34545d13dc3976ef0c859447e5d1f2b240e08fdd53a0877f744eae5e3"
        and report.get("l3_successor_design_sha256")
        == "sha256:ad8d147ee5a508aee3104fb346dcedde692568a9f9093a73e3bdbca638901f76"
        and report.get("consumed_l2_physical_invalid_closure_sha256")
        == "sha256:5f6242e2cab9658a54c673717596c7649fac785136d29d8798192bfc0f60babb",
        "REPORT_BINDINGS",
    )
    cells = report.get("cells")
    pairs = report.get("pairs")
    require(isinstance(cells, list) and len(cells) == 2, "REPORT_CELLS")
    require(isinstance(pairs, list) and len(pairs) == 1, "REPORT_PAIRS")
    require(
        [item.get("cell_id") for item in cells] == ["baseline_s50300", "push_s50300"]
        and all(item.get("evidence_valid") is True for item in cells)
        and all(item.get("behavior_passed") is False for item in cells),
        "REPORT_CELL_RESULTS",
    )
    require(
        pairs[0].get("campaign_seed") == 50300
        and pairs[0].get("native_effect_confirmed") is True
        and pairs[0].get("behavior_passed") is False
        and pairs[0].get("raw_sha256")
        == "sha256:959c60c0a8aa9f97575b0221206ee12ad4462360fea93529046f455f0e1e8c82",
        "REPORT_PAIR_RESULT",
    )


def validate_closure_contract(document: dict[str, Any]) -> None:
    require(
        document.get("schema_version")
        == "sporespore_qsdk_r10b_development_route_ghost_physical_closure_v1",
        "CLOSURE_SCHEMA",
    )
    require(
        document.get("status")
        == "closed_execution_valid_complete_behavior_finite_negative",
        "CLOSURE_STATUS",
    )
    require(
        document.get("gate_id") == "QSDK-R10B"
        and document.get("repair_id") == "QSDK-R10B-L3"
        and document.get("closure_id") == "QSDK-R10B-L3-P1"
        and document.get("campaign_id") == CAMPAIGN_ID
        and document.get("campaign_role") == "development_route_ghost"
        and document.get("question_class") == "development",
        "CLOSURE_IDENTITY",
    )
    require(
        document.get("route_execution_valid") is True
        and document.get("behavior_passed") is False
        and document.get("physical_identity_consumed") is True
        and document.get("same_identity_rerun_permitted") is False,
        "CLOSURE_TOP_LEVEL_RESULT",
    )
    scope = document.get("ledger_scope")
    require(
        scope
        == {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "retained_consumed_physical_development_route_closure",
            "question_class": "development",
        },
        "CLOSURE_LEDGER_SCOPE",
    )
    declared = document.get("declared_question")
    require(isinstance(declared, dict), "CLOSURE_DECLARED_QUESTION")
    require(
        declared.get("behavior_success_required_for_route_validity") is False
        and declared.get(
            "route_execution_validity_required_before_held_out_qualification"
        )
        is True
        and declared.get("behavioral_outcome_selects_or_blocks_held_out_population")
        is False
        and declared.get("maximum_campaign_attempt_count") == 1
        and declared.get("maximum_world_count") == 2
        and declared.get("ordered_cell_ids") == ["baseline_s50300", "push_s50300"],
        "CLOSURE_DECLARED_RULE",
    )

    physical = document.get("physical_attempt")
    require(isinstance(physical, dict), "CLOSURE_PHYSICAL_ATTEMPT")
    require(
        Path(str(physical.get("evidence_root"))).resolve() == EVIDENCE_ROOT.resolve(),
        "CLOSURE_EVIDENCE_ROOT",
    )
    require(
        physical.get("physical_identity_consumed") is True
        and physical.get("same_identity_rerun_permitted") is False
        and physical.get("same_identity_requalification_permitted") is False
        and physical.get("campaign_attempt_count") == 1
        and physical.get("attempted_cell_count") == 2
        and physical.get("completed_valid_cell_count") == 2
        and physical.get("unattempted_cell_count") == 0
        and physical.get("world_attempt_count") == 2
        and physical.get("world_build_count") == 2
        and physical.get("world_reset_count") == 0
        and physical.get("pair_count") == 1
        and physical.get("campaign_report_count") == 1
        and physical.get("external_push_application_count") == 1
        and physical.get("retained_trace_row_count") == 5271,
        "CLOSURE_PHYSICAL_COUNTS",
    )

    route = document.get("route_execution_result")
    require(isinstance(route, dict), "CLOSURE_ROUTE_RESULT")
    require(
        route.get("route_execution_valid") is True
        and route.get("valid_complete_campaign_result_count") == 1
        and route.get("valid_complete_cell_count") == 2
        and route.get("valid_complete_pair_count") == 1
        and route.get("worker_terminal_marker_count") == 2
        and route.get("worker_stdout_marker_count") == 2
        and route.get("worker_godot_log_marker_count") == 2
        and route.get("worker_markers_match_retained_cells") is True,
        "CLOSURE_ROUTE_COUNTS",
    )

    finite = document.get("finite_behavior_result")
    require(isinstance(finite, dict), "CLOSURE_FINITE_RESULT")
    require(
        finite.get("classification") == "valid_complete_development_finite_negative"
        and finite.get("behavior_result_established") is True
        and finite.get("infrastructure_failure_established") is False
        and finite.get("trace_representation_failure_established") is False
        and finite.get("native_push_path_executed") is True
        and finite.get("native_push_effect_confirmed") is True
        and finite.get("recovery_window_found_after_push") is True
        and finite.get("overall_behavior_passed") is False,
        "CLOSURE_FINITE_CLASSIFICATION",
    )

    decision = document.get("decision")
    require(isinstance(decision, dict), "CLOSURE_DECISION")
    require(
        decision.get("result")
        == "development_route_execution_valid_behavior_finite_negative"
        and decision.get("route_execution_valid") is True
        and decision.get("physical_attempt_consumed_for_exact_source") is True
        and decision.get("same_identity_rerun_permitted") is False
        and decision.get("development_behavior_outcome_nonselecting") is True
        and decision.get("outcome_derived_repair_selected") is False
        and decision.get("new_l4_repair_selected") is False
        and decision.get("held_out_finite_decision_prerequisite_satisfied") is True
        and decision.get("held_out_finite_decision_physical_execution_authorized")
        is False
        and decision.get("physical_acceptance_authority") is False
        and decision.get("release_authority") is False,
        "CLOSURE_DECISION_RESULT",
    )
    require(
        all(
            decision.get(field) is False
            for field in (
                "seed_changed",
                "marker_timing_changed",
                "controller_changed",
                "fixture_changed",
                "challenge_changed",
                "impulse_changed",
                "behavior_threshold_changed",
                "population_changed",
                "historical_result_rewritten",
            )
        ),
        "CLOSURE_NO_OUTCOME_DERIVED_CHANGE",
    )

    held_out = document.get("held_out_boundary")
    require(isinstance(held_out, dict), "CLOSURE_HELD_OUT_BOUNDARY")
    require(
        held_out.get("campaign_role") == "held_out_finite_decision"
        and held_out.get("question_class") == "finite decision"
        and held_out.get("campaign_seeds") == [50301, 50302, 50303]
        and held_out.get("ordered_cell_ids")
        == [
            "baseline_s50301",
            "push_s50301",
            "baseline_s50302",
            "push_s50302",
            "baseline_s50303",
            "push_s50303",
        ]
        and held_out.get("maximum_world_count") == 6
        and held_out.get("all_cells_run_regardless_of_intermediate_behavior") is True
        and held_out.get("development_outcome_may_not_change_thresholds_or_population")
        is True
        and held_out.get("held_out_world_attempt_count") == 0
        and held_out.get("held_out_world_build_count") == 0
        and held_out.get("physical_execution_blocked") is True,
        "CLOSURE_HELD_OUT_RULE",
    )

    status = document.get("sdk_status")
    require(
        isinstance(status, dict)
        and status.get("qsdk_r10_satisfied") is False
        and status.get("sdk1_m07_satisfied") is False
        and status.get("sdk1_completed_steps") == 13
        and status.get("sdk1_total_steps") == 20
        and status.get("full_program_completed_steps") == 13
        and status.get("full_program_total_steps") == 25,
        "CLOSURE_SDK_STATUS",
    )
    claims = document.get("claim_boundary")
    require(isinstance(claims, dict), "CLOSURE_CLAIMS")
    require(
        claims.get("route_execution_valid_claimed") is True
        and claims.get("complete_valid_development_finite_negative_claimed") is True
        and claims.get("native_external_push_application_claimed") is True
        and claims.get("native_external_push_effect_claimed") is True
        and claims.get("post_push_recovery_window_observed_claimed") is True,
        "CLOSURE_POSITIVE_ROUTE_CLAIMS",
    )
    require(
        all(
            claims.get(field) is False
            for field in (
                "bounded_upright_push_recovery_claimed",
                "external_push_recovery_claimed",
                "fall_recovery_claimed",
                "prone_to_standing_claimed",
                "force_aware_recovery_claimed",
                "other_engine_claimed",
                "cross_engine_equivalence_claimed",
                "population_success_rate_claimed",
                "physical_acceptance_authority",
                "release_authority",
            )
        ),
        "CLOSURE_FORBIDDEN_CLAIM",
    )


def validate_closure_against_evidence(
    closure: dict[str, Any],
    baseline: dict[str, Any],
    push: dict[str, Any],
    pair: dict[str, Any],
    report: dict[str, Any],
) -> None:
    observed_tree = tree_manifest(EVIDENCE_ROOT)
    require(observed_tree == EXPECTED_EVIDENCE_FILES, "PHYSICAL_TREE_DRIFT")
    manifest = canonical_bytes(observed_tree)
    retained = closure["physical_attempt"]["retained_tree"]
    require(
        retained
        == {
            "schema_version": "sporespore_retained_file_tree_manifest_v1",
            "file_count": 13,
            "total_byte_length": 39_376_475,
            "manifest_canonical_byte_length": len(manifest),
            "manifest_canonical_sha256": sha256_bytes(manifest),
            "files": observed_tree,
        },
        "CLOSURE_RETAINED_TREE",
    )
    require(len(manifest) == 1886, "PHYSICAL_MANIFEST_BYTES")
    require(
        sha256_bytes(manifest)
        == "sha256:de4e2eac8121ddb60b818bb157b1df2c1d0da6797229cdb8da2a495a2c8583a4",
        "PHYSICAL_MANIFEST_SHA",
    )

    for cell_id, cell, raw_sha, canonical_sha, evaluation_sha, trace_sha in (
        (
            "baseline_s50300",
            baseline,
            "sha256:19dea25c92b5ea4636b3b91975e19ed84f65598b06e328d3df63000f3dd21cfe",
            "sha256:c98837b868935d851240dc9122177a03211fd4112e2bd2cb489cb86173c5627d",
            "sha256:2d66db9ca687910f25267088deb37f6fcbba5b8b3ae8f0127823df84cd94d321",
            "sha256:79e07ead656b254e6a9f4a96bcbb9353af7d24fbb5cf3fb859a44e5b03c8aade",
        ),
        (
            "push_s50300",
            push,
            "sha256:efac419860a63866b50a9e291c3f6e6115fab454ae6e1130af6a2d3b3b6bc4b9",
            "sha256:532d51a8393e9fb2eff351105b2ed6b9a3e8170babb84e34e80fc3e6137c416c",
            "sha256:41b7df0b603ddadaa88e04fe68d28ffdffe34600cca244db83df4491f2ded27e",
            "sha256:e3520b0b40b3e58ab55802172cb5daab3031798aa71bfb874840f3488b8421c5",
        ),
    ):
        route_cell = closure["route_execution_result"][
            "baseline" if cell_id.startswith("baseline") else "push"
        ]
        require(route_cell.get("raw_sha256") == raw_sha, f"{cell_id}_CLOSURE_RAW_SHA")
        require(
            route_cell.get("canonical_byte_length") == len(canonical_bytes(cell))
            and route_cell.get("canonical_sha256") == canonical_sha,
            f"{cell_id}_CLOSURE_CANONICAL",
        )
        evaluation = cell["evaluation"]
        require(
            route_cell.get("evaluation_canonical_byte_length")
            == len(canonical_bytes(evaluation))
            and route_cell.get("evaluation_canonical_sha256") == evaluation_sha
            and route_cell.get("trace_canonical_sha256")
            == sha256_bytes(canonical_bytes(cell["sdk_physical_trace"]))
            == trace_sha,
            f"{cell_id}_CLOSURE_PROJECTIONS",
        )

    finite = closure["finite_behavior_result"]
    ordinary = finite["ordinary_walking_conjunction"]
    require(
        ordinary.get("baseline_passed") is False
        and ordinary.get("push_passed") is False
        and ordinary.get("walking_receipts_structurally_complete") is True
        and ordinary.get("receipt_count_per_cell") == 27
        and ordinary.get("false_receipts_per_cell") == ["bounded_anchor_error"]
        and ordinary.get("all_other_receipts_true") is True,
        "CLOSURE_WALKING_DECOMPOSITION",
    )
    pre = finite["pre_push_window"]
    require(
        pre.get("baseline_passed") is False
        and pre.get("push_passed") is False
        and pre.get("sole_failed_limb") == "front_left"
        and pre.get("front_left_longest_airborne_dwell_steps") == 29
        and pre.get("front_left_qualifying_recontact_semantic_step") == -1
        and pre.get("other_three_limbs_passed") is True,
        "CLOSURE_PRE_WINDOW_DECOMPOSITION",
    )
    baseline_window = baseline["evaluation"]["baseline_post_marker_window"]
    validate_valid_window(
        baseline_window,
        expected_advance=0.16715878248214722,
        label="BASELINE_POST_MARKER_WINDOW",
    )
    closure_baseline_window = finite["matched_baseline_post_marker_window"]
    require(
        closure_baseline_window.get("passed") is True
        and closure_baseline_window.get("start_semantic_step") == 541
        and closure_baseline_window.get("end_semantic_step_exclusive") == 901
        and closure_baseline_window.get("task_frame_forward_advance_m")
        == 0.16715878248214722,
        "CLOSURE_BASELINE_WINDOW",
    )

    recovery = push["evaluation"]["recovery_search"]
    require(
        recovery.get("found") is True
        and recovery.get("failure_code") == ""
        and recovery.get("first_valid_start_semantic_step") == 541
        and recovery.get("reentry_latency_steps") == 0
        and recovery.get("reentry_latency_s") == 0.0,
        "PUSH_RECOVERY_SEARCH",
    )
    validate_valid_window(
        recovery.get("window", {}),
        expected_advance=0.1980421096086502,
        label="PUSH_RECOVERY_WINDOW",
    )
    closure_recovery = finite["push_recovery_search"]
    require(
        closure_recovery.get("found") is True
        and closure_recovery.get("first_valid_start_semantic_step") == 541
        and closure_recovery.get("reentry_latency_steps") == 0
        and closure_recovery.get("window_end_semantic_step_exclusive") == 901
        and closure_recovery.get("task_frame_forward_advance_m") == 0.1980421096086502,
        "CLOSURE_PUSH_RECOVERY",
    )

    baseline_application = baseline["evaluation"]["application_receipt"]
    push_application = push["evaluation"]["application_receipt"]
    require(
        baseline_application
        == {
            "application_count": 0,
            "effect_magnitude_m_s": 0.0,
            "effect_sampled": False,
        },
        "BASELINE_APPLICATION",
    )
    require(
        push_application
        == {
            "application_count": 1,
            "effect_magnitude_m_s": 0.06133231520652771,
            "effect_sampled": True,
            "observed_velocity_delta_world_m_s": [
                0.009567681699991226,
                0.0019740310963243246,
                0.060549281537532806,
            ],
            "profile_id": "lateral_impulse_v1",
            "step_from_sdk_start": 540,
        },
        "PUSH_APPLICATION",
    )
    closure_application = finite["push_application"]
    require(
        closure_application.get("profile_id") == push_application["profile_id"]
        and closure_application.get("step_from_sdk_start")
        == push_application["step_from_sdk_start"]
        and closure_application.get("application_count")
        == push_application["application_count"]
        and closure_application.get("effect_sampled") is True
        and closure_application.get("effect_magnitude_m_s")
        == push_application["effect_magnitude_m_s"]
        and closure_application.get("observed_velocity_delta_world_m_s")
        == push_application["observed_velocity_delta_world_m_s"]
        and closure_application.get("paired_native_effect_confirmed") is True,
        "CLOSURE_PUSH_APPLICATION",
    )

    route_pair = closure["route_execution_result"]["matched_pair"]
    for field in (
        "schema_version",
        "ok",
        "evidence_valid",
        "outcome_complete",
        "matched_initial_perturbation",
        "native_effect_confirmed",
        "native_effect_magnitude_m_s",
        "baseline_lateral_velocity_jump_m_s",
        "push_lateral_velocity_jump_m_s",
        "paired_lateral_velocity_jump_difference_m_s",
        "behavior_passed",
        "evaluation_world_build_count",
        "physics_state_modified",
        "physical_acceptance_authority",
        "release_authority",
    ):
        require(route_pair.get(field) == pair.get(field), f"CLOSURE_PAIR_FIELD:{field}")
    require(
        closure["physical_attempt"]["report"]
        == {
            "path": "report.json",
            "schema_version": report["schema_version"],
            "raw_sha256": "sha256:64f4e3ce155cfcc379b08fa5ec0bd578012f809d344dc04715a1af0d62d173d5",
            "status": report["status"],
            "complete": report["complete"],
            "behavior_passed": report["behavior_passed"],
            "world_attempt_count": report["world_attempt_count"],
            "world_build_count": report["world_build_count"],
            "expected_world_count": report["expected_world_count"],
            "pair_count": report["pair_count"],
            "same_identity_rerun_permitted": report["same_identity_rerun_permitted"],
            "physical_acceptance_authority": report["physical_acceptance_authority"],
            "release_authority": report["release_authority"],
        },
        "CLOSURE_REPORT_PROJECTION",
    )


def mutation_refusal_count(closure: dict[str, Any]) -> int:
    mutations = (
        ("route_execution_valid", False),
        ("behavior_passed", True),
        ("physical_identity_consumed", False),
        ("same_identity_rerun_permitted", True),
        ("status", "closed_positive"),
        ("campaign_role", "held_out_finite_decision"),
    )
    refused = 0
    for key, value in mutations:
        candidate = copy.deepcopy(closure)
        candidate[key] = value
        try:
            validate_closure_contract(candidate)
        except ClosureFailure:
            refused += 1
    nested_mutations = (
        ("decision", "new_l4_repair_selected", True),
        ("decision", "behavior_threshold_changed", True),
        ("held_out_boundary", "maximum_world_count", 5),
        ("sdk_status", "sdk1_m07_satisfied", True),
        ("claim_boundary", "external_push_recovery_claimed", True),
        ("physical_attempt", "world_build_count", 3),
    )
    for section, key, value in nested_mutations:
        candidate = copy.deepcopy(closure)
        candidate[section][key] = value
        try:
            validate_closure_contract(candidate)
        except ClosureFailure:
            refused += 1
    require(
        refused == len(mutations) + len(nested_mutations), "MUTATION_CONTROL_FAILED"
    )
    return refused


def main() -> int:
    validate_repository_identity()
    closure = read_json(CLOSURE_PATH, "CLOSURE")
    validate_closure_contract(closure)
    validate_source_graph(closure)
    validate_qualification(closure)

    attempts = {}
    cells = {}
    specifications = (
        ("baseline_s50300", "matched_no_impulse_control", 2640),
        ("push_s50300", "lateral_upright_impulse", 2631),
    )
    marker_count = 0
    for cell_id, arm_id, expected_rows in specifications:
        attempt = read_json(
            EVIDENCE_ROOT / cell_id / "attempt.json", f"{cell_id}_ATTEMPT"
        )
        validate_attempt_record(attempt, cell_id=cell_id, arm_id=arm_id)
        attempts[cell_id] = attempt

        cell = read_json(EVIDENCE_ROOT / cell_id / "cell.json", f"{cell_id}_CELL")
        validate_cell(cell, cell_id=cell_id, arm_id=arm_id, expected_rows=expected_rows)
        cells[cell_id] = cell
        for log_name in ("stdout.log", "godot.log"):
            payload = marker_payload(EVIDENCE_ROOT / cell_id / log_name)
            require(payload == cell, f"{cell_id}_{log_name}_MARKER_CELL_MISMATCH")
            marker_count += 1

    require(
        attempts["baseline_s50300"]["authorization_token"]
        != attempts["push_s50300"]["authorization_token"],
        "ATTEMPT_TOKENS_NOT_UNIQUE",
    )
    require(
        attempts["baseline_s50300"]["operation_lock"]
        == attempts["push_s50300"]["operation_lock"],
        "ATTEMPT_LOCK_RECEIPTS_DIFFER",
    )

    baseline_evaluation = cells["baseline_s50300"]["evaluation"]
    push_evaluation = cells["push_s50300"]["evaluation"]
    require(
        baseline_evaluation["pre_push_window"] == push_evaluation["pre_push_window"],
        "PAIR_PRE_WINDOW_MISMATCH",
    )
    pair = read_json(EVIDENCE_ROOT / "pair-s50300.json", "PAIR")
    validate_pair(pair, baseline_evaluation, push_evaluation)
    report = read_json(EVIDENCE_ROOT / "report.json", "REPORT")
    validate_report(report)
    validate_closure_against_evidence(
        closure,
        cells["baseline_s50300"],
        cells["push_s50300"],
        pair,
        report,
    )
    mutation_count = mutation_refusal_count(closure)

    receipt = {
        "schema_version": (
            "sporespore_qsdk_r10b_development_route_ghost_" "physical_closure_audit_v1"
        ),
        "gate_id": "QSDK-R10B",
        "repair_id": "QSDK-R10B-L3",
        "ok": True,
        "route_execution_valid": True,
        "behavior_passed": False,
        "physical_identity_consumed": True,
        "same_identity_rerun_permitted": False,
        "retained_file_count": len(EXPECTED_EVIDENCE_FILES),
        "retained_total_byte_length": sum(
            int(item["byte_length"]) for item in EXPECTED_EVIDENCE_FILES
        ),
        "retained_tree_manifest_sha256": (
            "sha256:de4e2eac8121ddb60b818bb157b1df2c1d0da6797229cdb8da2a495a2c8583a4"
        ),
        "qualification_file_count": len(EXPECTED_QUALIFICATION_FILES),
        "world_attempt_count_in_retained_evidence": 2,
        "world_build_count_in_retained_evidence": 2,
        "valid_complete_cell_count": 2,
        "valid_complete_pair_count": 1,
        "retained_trace_row_count": 5271,
        "native_push_application_count": 1,
        "native_effect_confirmed": True,
        "post_push_recovery_window_found": True,
        "ordinary_walking_conjunction_passed": False,
        "pre_push_window_passed": False,
        "held_out_prerequisite_satisfied": True,
        "held_out_physical_execution_authorized": False,
        "cell_marker_count": marker_count,
        "closure_mutation_rejection_count": mutation_count,
        "model_construction_count": 0,
        "audit_world_attempt_count": 0,
        "audit_world_build_count": 0,
        "native_readback_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    print(PASS_MARKER + json.dumps(receipt, separators=(",", ":"), sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ClosureFailure as exc:
        print(
            f"QSDK_R10B_DEVELOPMENT_ROUTE_GHOST_PHYSICAL_CLOSURE_FAIL {exc}",
            file=sys.stderr,
        )
        raise SystemExit(1)
