#!/usr/bin/env python3
"""Audit the consumed QSDK-R10B-L2 physical-invalid closure without worlds."""

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
    r"\qsdk-r10b-development-route-ghost-physical-49edaa8d95c2"
)
QUALIFICATION_ROOT = Path(
    r"C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
    r"\qsdk-r10b-development-route-ghost-zero-world-qualification-49edaa8d95c2"
)
DIAGNOSIS_ROOT = Path(
    r"C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
    r"\qsdk-r10b-l2-retained-trace-diagnosis-dev-v3-3843009e4552"
)
CLOSURE_PATH = (
    ROOT / "sdk/qsdk_r10b_l2_development_route_ghost_physical_invalid_closure_v1.json"
)
DIAGNOSIS_SCRIPT_PATH = ROOT / "tests/test_sdk_qsdk_r10b_l2_retained_trace_diagnosis.gd"
SOURCE_COMMIT = "49edaa8d95c26aee2a57f15ec5b9e2ba308d97ef"
STAGE_COMMIT = "39deda3b2f61071d78f6c63cab1808ff7cdced2c"
AUTHORITY_COMMIT = "3843009e4552c0601e10783ec76ba3abe62bb75f"
CELL_MARKER = "QSDK_R10B_PHYSICAL_CELL "
DIAGNOSIS_MARKER = "QSDK_R10B_L2_RETAINED_TRACE_DIAGNOSIS "
PASS_MARKER = "QSDK_R10B_L2_PHYSICAL_INVALID_CLOSURE_PASS "
QUATERNION_NORM_TOLERANCE = 1.0e-9
VECTOR_TOLERANCE = 1.0e-12
EXPECTED_LIMB_ORDER = {"front_left", "front_right", "rear_left", "rear_right"}

EXPECTED_EVIDENCE_FILES = [
    {
        "path": "baseline_s50300/attempt.json",
        "byte_length": 2_247,
        "raw_sha256": (
            "sha256:c6e055d0b981d3ca2c0038536e49d600cdbd8af14bc06fa86cbcda3d410437e2"
        ),
    },
    {
        "path": "baseline_s50300/godot.log",
        "byte_length": 6_579_892,
        "raw_sha256": (
            "sha256:dbad41bfeed5c3fd49d297758289dae7090ee4e2a7202b27af923f0c6e6a9e04"
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
        "byte_length": 6_580_023,
        "raw_sha256": (
            "sha256:a692429940aeec3cee79f91e63138a0d1ab945926694bafb7c8535f6364f2e8e"
        ),
    },
    {
        "path": "l2-retained-trace-diagnosis-godot.log",
        "byte_length": 3_310,
        "raw_sha256": (
            "sha256:9ee67c22df74d614adc02f894fb73f69d60fb6574bebee00dcba23397f85e554"
        ),
    },
    {
        "path": "l2-retained-trace-diagnosis-v2-godot.log",
        "byte_length": 2_219,
        "raw_sha256": (
            "sha256:bc498e06e4e5d4980d28cffbb91fa3b1aa0c287a9f88cc408c7c8a726eb3e376"
        ),
    },
]

EXPECTED_RECEIPT_FIELD_MISMATCH_COUNTS = {
    "orientation_xyzw": 2620,
    "projected_norm": 671,
    "projected_norm_delta": 679,
    "projected_norm_squared": 687,
    "projected_norm_squared_delta": 694,
    "source_norm": 1205,
    "source_norm_delta": 1416,
    "source_norm_squared": 1575,
    "source_norm_squared_delta": 1701,
}


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


def marker_payload(path: Path, marker: str) -> str:
    lines = [
        line
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.startswith(marker)
    ]
    require(len(lines) == 1, f"MARKER_COUNT:{path.name}:{marker.strip()}")
    return lines[0][len(marker) :]


def numeric_array(value: Any, size: int) -> list[float] | None:
    if not isinstance(value, list) or len(value) != size:
        return None
    if not all(
        isinstance(item, (int, float)) and not isinstance(item, bool) for item in value
    ):
        return None
    return [float(item) for item in value]


def norm_delta(values: list[float]) -> float:
    return abs(math.sqrt(sum(value * value for value in values)) - 1.0)


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
        graph.get("implementation_source") == commit_identity(SOURCE_COMMIT),
        "SOURCE_COMMIT_IDENTITY_DRIFT",
    )

    stage_relative = (
        "sdk/qsdk_r10b_development_route_ghost_"
        "zero_world_qualification_closure_v3.json"
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
        "sdk/qsdk_r10b_development_route_ghost_execution_authority_v3.json"
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

    l1_relative = (
        "sdk/qsdk_r10b_l1_development_route_ghost_physical_invalid_closure_v1.json"
    )
    l1 = committed_file_identity(SOURCE_COMMIT, l1_relative)
    l1["git_blob_oid_at_source_commit"] = l1.pop("git_blob_oid")
    l1["historical_result_rewritten"] = False
    require(graph.get("consumed_l1_closure") == l1, "L1_CLOSURE_IDENTITY_DRIFT")

    design_relative = (
        "sdk/qsdk_r10b_l2_exact_quaternion_projection_successor_design_v1.json"
    )
    design = committed_file_identity(SOURCE_COMMIT, design_relative)
    design["git_blob_oid_at_source_commit"] = design.pop("git_blob_oid")
    require(graph.get("l2_successor_design") == design, "L2_DESIGN_IDENTITY_DRIFT")

    helper_relative = "sdk/adapters/godot/gdscript/quaternion_scalar_projection_v1.gd"
    helper = committed_file_identity(SOURCE_COMMIT, helper_relative)
    helper["git_blob_oid_at_source_commit"] = helper.pop("git_blob_oid")
    require(graph.get("l2_projection_helper") == helper, "L2_HELPER_IDENTITY_DRIFT")

    stage_document = read_json(ROOT / stage_relative, "STAGE_FREEZE")
    authority_document = read_json(ROOT / authority_relative, "EXECUTION_AUTHORITY")
    require(
        stage_document.get("schema_version") == "sporespore_qsdk_r10b_stage_freeze_v3"
        and stage_document.get("source_commit") == SOURCE_COMMIT
        and stage_document.get("official_zero_world_qualification_passed") is True
        and stage_document.get("physical_execution_authorized_by_freeze") is False,
        "STAGE_SEMANTICS_DRIFT",
    )
    require(
        authority_document.get("schema_version")
        == "sporespore_qsdk_r10b_execution_authority_v3"
        and authority_document.get("status") == "authorized_single_use_unconsumed"
        and authority_document.get("source_commit") == SOURCE_COMMIT
        and authority_document.get("authorization_parent_commit") == STAGE_COMMIT
        and authority_document.get("physical_execution_authorized") is True
        and authority_document.get("same_identity_rerun_permitted") is False,
        "AUTHORITY_SEMANTICS_DRIFT",
    )


def validate_qualification(closure: dict[str, Any]) -> None:
    boundary = closure.get("zero_world_authorization_boundary")
    require(isinstance(boundary, dict), "ZERO_WORLD_BOUNDARY_MISSING")
    require(
        Path(str(boundary.get("official_qualification_evidence_root", ""))).resolve()
        == QUALIFICATION_ROOT.resolve(),
        "QUALIFICATION_ROOT_DRIFT",
    )
    require(
        boundary.get("qualification_file_count") == 5
        and boundary.get("qualification_total_byte_length") == 13_768
        and boundary.get("qualification_completion_sha256")
        == "sha256:13377793e6d43f53e7b1479817e38a3c648c3eec129dc3269a08259dcfda2597"
        and boundary.get("qualified_source_path_count") == 77
        and boundary.get("qualified_source_path_sha256")
        == "sha256:7480f49b3a4f916345337452874e20f304b3c25320022357a016d6c1eb824ea2",
        "QUALIFICATION_BOUNDARY_DECLARATION_DRIFT",
    )
    files = sorted(
        (path for path in QUALIFICATION_ROOT.iterdir() if path.is_file()),
        key=lambda path: path.name,
    )
    identities = [file_identity(path, QUALIFICATION_ROOT) for path in files]
    stage = read_json(
        ROOT
        / "sdk/qsdk_r10b_development_route_ghost_zero_world_qualification_closure_v3.json",
        "STAGE_FREEZE",
    )
    official = stage.get("official_qualification")
    require(isinstance(official, dict), "OFFICIAL_QUALIFICATION_MISSING")
    require(
        len(files) == 5
        and sum(path.stat().st_size for path in files) == 13_768
        and identities == official.get("files"),
        "QUALIFICATION_TREE_DRIFT",
    )
    completion = QUALIFICATION_ROOT / "qualification_completion.json"
    require(
        sha256_bytes(completion.read_bytes())
        == "sha256:13377793e6d43f53e7b1479817e38a3c648c3eec129dc3269a08259dcfda2597",
        "QUALIFICATION_COMPLETION_DIGEST_DRIFT",
    )
    receipt = read_json(
        QUALIFICATION_ROOT / "qualification_receipt.json", "QUALIFICATION_RECEIPT"
    )
    require(
        receipt.get("schema_version")
        == "sporespore_qsdk_r10b_zero_world_implementation_audit_v3"
        and receipt.get("source_commit") == SOURCE_COMMIT
        and receipt.get("official_qualification_mode") is True
        and receipt.get("worktree_clean") is True
        and receipt.get("head_origin_main_equal") is True
        and receipt.get("head_live_remote_main_equal") is True
        and receipt.get("qualified_source_path_count") == 77
        and receipt.get("qualified_source_path_sha256")
        == "sha256:7480f49b3a4f916345337452874e20f304b3c25320022357a016d6c1eb824ea2"
        and receipt.get("retained_raw_quaternion_refusal_count_per_source_gate") == 2
        and receipt.get(
            "retained_projected_quaternion_acceptance_count_per_source_gate"
        )
        == 2
        and receipt.get("projection_receipt_mutation_rejection_count_per_source_gate")
        == 3,
        "QUALIFICATION_RECEIPT_DRIFT",
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
    require(
        boundary.get("committed_graph_authority_check_passed") is True
        and boundary.get("first_operator_invocation_refused_before_lock_or_output")
        is True
        and boundary.get("first_operator_invocation_retained_receipt") is False
        and boundary.get(
            "physical_mode_revalidated_the_same_committed_graph_before_attempt"
        )
        is True,
        "AUTHORITY_CHECK_BOUNDARY_DRIFT",
    )


def validate_trace_rows(rows: list[Any]) -> dict[str, Any]:
    require(len(rows) == 2640, "TRACE_ROW_COUNT_DRIFT")
    projected_deltas: list[float] = []
    source_deltas: list[float] = []
    forward_deltas: list[float] = []
    lateral_deltas: list[float] = []
    axis_dots: list[float] = []
    first_forward: list[float] | None = None
    first_lateral: list[float] | None = None

    for index, row_value in enumerate(rows):
        require(isinstance(row_value, dict), f"TRACE_ROW_NOT_OBJECT:{index}")
        row = row_value
        require(
            row.get("schema_version")
            == "sporespore_qsdk_r10b_bounded_upright_push_recovery_trace_row_v2"
            and row.get("cell_id") == "baseline_s50300"
            and row.get("semantic_step") == index
            and row.get("sampling_phase") == "post_physics_for_applied_semantic_step"
            and row.get("push_marker_semantic_step") == 540
            and row.get("validated_portable_command_count") == 8
            and row.get("native_actuation_application_count") == 8
            and row.get("post_physics_observation_complete") is True
            and row.get("observer_physics_state_modified") is False
            and isinstance(row.get("torso_ground_contact"), bool),
            f"TRACE_ROW_HEADER_DRIFT:{index}",
        )

        position = numeric_array(row.get("torso_position_world_m"), 3)
        linear = numeric_array(row.get("torso_linear_velocity_world_m_s"), 3)
        angular = numeric_array(row.get("torso_angular_velocity_world_rad_s"), 3)
        forward = numeric_array(row.get("task_frame_forward_axis_world_unit"), 3)
        lateral = numeric_array(row.get("task_frame_lateral_axis_world_unit"), 3)
        quaternion = numeric_array(row.get("torso_orientation_xyzw"), 4)
        tilt = row.get("torso_tilt_rad")
        require(
            position is not None
            and linear is not None
            and angular is not None
            and forward is not None
            and lateral is not None
            and quaternion is not None
            and isinstance(tilt, (int, float))
            and not isinstance(tilt, bool),
            f"TRACE_ROW_NUMERIC_SHAPE_DRIFT:{index}",
        )
        all_values = [*position, *linear, *angular, *forward, *lateral, *quaternion]
        require(
            all(math.isfinite(value) for value in all_values)
            and math.isfinite(float(tilt))
            and float(tilt) >= 0.0,
            f"TRACE_ROW_NONFINITE_OR_TILT_DRIFT:{index}",
        )

        forward_delta = norm_delta(forward)
        lateral_delta = norm_delta(lateral)
        dot = abs(sum(left * right for left, right in zip(forward, lateral)))
        forward_deltas.append(forward_delta)
        lateral_deltas.append(lateral_delta)
        axis_dots.append(dot)
        require(
            forward_delta <= VECTOR_TOLERANCE
            and lateral_delta <= VECTOR_TOLERANCE
            and dot <= VECTOR_TOLERANCE,
            f"TRACE_ROW_EXPORTED_AXIS_DRIFT:{index}",
        )
        if first_forward is None:
            first_forward = forward
            first_lateral = lateral
        else:
            require(
                forward == first_forward and lateral == first_lateral,
                f"TRACE_ROW_TASK_FRAME_CHANGED:{index}",
            )

        for field in ("ordered_foot_contacts_before", "ordered_foot_contacts_after"):
            contacts = row.get(field)
            require(isinstance(contacts, dict), f"TRACE_CONTACT_OBJECT:{index}:{field}")
            require(
                set(contacts) == EXPECTED_LIMB_ORDER
                and all(isinstance(value, bool) for value in contacts.values()),
                f"TRACE_CONTACT_VALUE:{index}:{field}",
            )

        receipt = row.get("torso_orientation_projection")
        require(isinstance(receipt, dict), f"TRACE_PROJECTION_OBJECT:{index}")
        source = numeric_array(receipt.get("source_orientation_xyzw"), 4)
        projected = numeric_array(receipt.get("orientation_xyzw"), 4)
        require(
            source is not None and projected is not None and projected == quaternion,
            f"TRACE_PROJECTION_LINK_DRIFT:{index}",
        )
        require(
            receipt.get("schema_version")
            == "sporespore_godot_quaternion_scalar_projection_v1"
            and receipt.get("ok") is True
            and receipt.get("support_status") == "supported_exact"
            and receipt.get("refusal_reason") is None
            and receipt.get("projection_method_id")
            == "godot_real_t_to_float64_largest_component_unit_reconstruction_v1"
            and receipt.get("qualified_precedent_gate_id") == "QSDK-R24D66"
            and receipt.get("qualified_precedent_contract_sha256")
            == "sha256:2860d75b05bf5ae1662ef73bf9585915b997e760ee392b8ba98c4b7f45665ece"
            and receipt.get("reconstructed_component_index") in (0, 1, 2, 3)
            and receipt.get("core_norm_squared_tolerance") == 1.0e-9
            and receipt.get("within_core_unit_contract") is True
            and receipt.get("model_construction_count") == 0
            and receipt.get("world_attempt_count") == 0
            and receipt.get("world_build_count") == 0
            and receipt.get("native_readback_count") == 0
            and receipt.get("solver_step_count") == 0
            and receipt.get("physics_state_modified") is False
            and receipt.get("physical_acceptance_authority") is False
            and receipt.get("release_authority") is False,
            f"TRACE_PROJECTION_STATIC_DRIFT:{index}",
        )
        projected_deltas.append(norm_delta(projected))
        source_deltas.append(norm_delta(source))

    projected_max_row = max(
        range(len(projected_deltas)), key=projected_deltas.__getitem__
    )
    source_max_row = max(range(len(source_deltas)), key=source_deltas.__getitem__)
    require(
        sum(delta > QUATERNION_NORM_TOLERANCE for delta in projected_deltas) == 0
        and projected_max_row == 9
        and math.isclose(
            projected_deltas[projected_max_row],
            1.1102230246251565e-16,
            rel_tol=0.0,
            abs_tol=0.0,
        ),
        "PROJECTED_QUATERNION_REPAIR_DRIFT",
    )
    require(
        sum(delta > QUATERNION_NORM_TOLERANCE for delta in source_deltas) == 2565
        and source_max_row == 2581
        and math.isclose(
            source_deltas[source_max_row],
            6.172870392617824e-8,
            rel_tol=0.0,
            abs_tol=1.0e-20,
        ),
        "SOURCE_QUATERNION_DIAGNOSTIC_DRIFT",
    )
    require(
        max(forward_deltas) == 0.0
        and max(lateral_deltas) == 0.0
        and max(axis_dots) == 0.0,
        "EXPORTED_AXIS_DIAGNOSTIC_DRIFT",
    )
    return {
        "trace_row_count": len(rows),
        "projected_quaternion_failure_count": 0,
        "source_quaternion_failure_count": 2565,
        "projected_maximum_row": projected_max_row,
        "source_maximum_row": source_max_row,
    }


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
    expected_tree = {
        "schema_version": "sporespore_retained_file_tree_manifest_v1",
        "file_count": 6,
        "total_byte_length": 13_167_691,
        "manifest_canonical_byte_length": 894,
        "manifest_canonical_sha256": (
            "sha256:d504a2941d9555955b0635120f08bd603bbbc2bd68f7e7ef1910d2c1b260ede3"
        ),
        "files": EXPECTED_EVIDENCE_FILES,
    }
    require(
        physical.get("retained_tree") == expected_tree,
        "PHYSICAL_TREE_DECLARATION_DRIFT",
    )
    require(
        len(canonical_bytes(identities)) == 894
        and sha256_bytes(canonical_bytes(identities))
        == "sha256:d504a2941d9555955b0635120f08bd603bbbc2bd68f7e7ef1910d2c1b260ede3",
        "PHYSICAL_TREE_MANIFEST_DRIFT",
    )
    roles = physical.get("file_role_boundary")
    require(
        isinstance(roles, dict)
        and roles.get("physical_attempt_record_paths")
        == [item["path"] for item in EXPECTED_EVIDENCE_FILES[:4]]
        and roles.get("posthoc_zero_world_exploratory_diagnostic_paths")
        == [item["path"] for item in EXPECTED_EVIDENCE_FILES[4:]]
        and roles.get("posthoc_diagnostics_are_physical_attempt_outputs") is False
        and roles.get("posthoc_diagnostics_advance_behavior_authority") is False,
        "PHYSICAL_FILE_ROLE_DRIFT",
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
        attempt.get("schema_version") == "sporespore_qsdk_r10b_physical_attempt_v3"
        and attempt.get("campaign_role") == "development_route_ghost"
        and attempt.get("arm_id") == "matched_no_impulse_control"
        and attempt.get("campaign_seed") == 50300
        and attempt.get("cell_id") == "baseline_s50300"
        and attempt.get("source_commit") == SOURCE_COMMIT
        and attempt.get("authorization_commit") == AUTHORITY_COMMIT
        and attempt.get("authorization_parent_commit") == STAGE_COMMIT
        and attempt.get("maximum_world_attempt_count") == 1
        and attempt.get("maximum_world_build_count") == 1
        and attempt.get("same_identity_rerun_permitted") is False
        and isinstance(attempt.get("authorization_token"), str)
        and len(attempt["authorization_token"]) == 32
        and isinstance(lock, dict)
        and lock.get("acquired") is True
        and lock.get("role") == "physical_development"
        and lock.get("created_new") is True
        and lock.get("abandoned_owner_recovered") is False,
        "PHYSICAL_ATTEMPT_RECORD_DRIFT",
    )

    stdout_payload = marker_payload(
        EVIDENCE_ROOT / "baseline_s50300/stdout.log", CELL_MARKER
    )
    godot_payload = marker_payload(
        EVIDENCE_ROOT / "baseline_s50300/godot.log", CELL_MARKER
    )
    require(stdout_payload == godot_payload, "CELL_MARKER_PAYLOAD_MISMATCH")
    raw_payload = stdout_payload.encode("utf-8")
    cell = json.loads(stdout_payload)
    require(isinstance(cell, dict), "CELL_MARKER_NOT_OBJECT")
    require(
        len(raw_payload) == 6_560_638
        and sha256_bytes(raw_payload)
        == "sha256:5773cfe19d2f268150934910bc780c757aad97aabaa913648317440c51977667"
        and len(canonical_bytes(cell)) == 6_560_587
        and sha256_bytes(canonical_bytes(cell))
        == "sha256:57e4b080999034f1aa4cb1b5af69e50ad3752bf8ffcf590d7878fdf8b237f54b",
        "CELL_MARKER_IDENTITY_DRIFT",
    )

    evaluation = cell.get("evaluation")
    runtime = cell.get("runtime_summary_projection")
    trace = cell.get("sdk_physical_trace")
    require(
        cell.get("schema_version") == "sporespore_qsdk_r10b_physical_cell_v3"
        and cell.get("source_commit") == SOURCE_COMMIT
        and cell.get("cell_id") == "baseline_s50300"
        and cell.get("arm_id") == "matched_no_impulse_control"
        and cell.get("world_build_count") == 1
        and cell.get("world_reset_count") == 0
        and cell.get("evidence_valid") is False
        and cell.get("outcome_complete") is False
        and cell.get("behavior_passed") is False
        and cell.get("selected_candidate_id") == "BW5R-B"
        and cell.get("controller_policy_id") == "sporespore_balanced_wave_bw5r_b_v1"
        and cell.get("selected_policy_digest")
        == "sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f"
        and cell.get("material_profile_id") == "godot_jolt_bw5c_mu095_v1"
        and isinstance(evaluation, dict)
        and evaluation.get("ok") is False
        and evaluation.get("failure_code") == "QSDK_R10B_TRACE_ROW_KINEMATICS_INVALID"
        and evaluation.get("evidence_valid") is False
        and evaluation.get("outcome_complete") is False
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
        and isinstance(rows, list),
        "CELL_TRACE_CARDINALITY_DRIFT",
    )
    walking = runtime.get("walking_gate_receipts")
    require(
        isinstance(walking, dict)
        and [key for key, value in walking.items() if value is not True]
        == ["bounded_anchor_error"],
        "WALKING_RECEIPT_PROJECTION_DRIFT",
    )
    metrics = validate_trace_rows(rows)
    require(
        not (EVIDENCE_ROOT / "baseline_s50300/cell.json").exists()
        and not (EVIDENCE_ROOT / "push_s50300").exists()
        and not (EVIDENCE_ROOT / "pair-s50300.json").exists()
        and not (EVIDENCE_ROOT / "report.json").exists(),
        "UNEXPECTED_POST_FAILURE_ARTIFACT",
    )
    return metrics


def validate_supporting_diagnosis(closure: dict[str, Any]) -> dict[str, Any]:
    support = closure.get("supporting_zero_world_diagnosis")
    require(isinstance(support, dict), "SUPPORTING_DIAGNOSIS_MISSING")
    require(
        Path(str(support.get("evidence_root", ""))).resolve()
        == DIAGNOSIS_ROOT.resolve(),
        "DIAGNOSIS_ROOT_DRIFT",
    )
    files = sorted(
        (path for path in DIAGNOSIS_ROOT.rglob("*") if path.is_file()),
        key=lambda path: path.relative_to(DIAGNOSIS_ROOT).as_posix(),
    )
    expected_file = {
        "path": "godot.log",
        "byte_length": 4_396,
        "raw_sha256": (
            "sha256:04f04c10263f4d72fb06fd777dfa9c7d943fdd78e1212dee0cbb9e883004cfb8"
        ),
    }
    require(
        [file_identity(path, DIAGNOSIS_ROOT) for path in files] == [expected_file]
        and support.get("file") == expected_file
        and support.get("file_count") == 1
        and support.get("total_byte_length") == 4_396,
        "DIAGNOSIS_FILE_TREE_DRIFT",
    )
    script_identity = file_identity(DIAGNOSIS_SCRIPT_PATH, ROOT)
    require(
        script_identity
        == {
            "path": "tests/test_sdk_qsdk_r10b_l2_retained_trace_diagnosis.gd",
            "byte_length": 24_131,
            "raw_sha256": (
                "sha256:852af93319efccab62859b8aad032a72b3aa881e18c1b23b8ae1d363caecdb78"
            ),
        }
        and support.get("diagnostic_script") == script_identity,
        "DIAGNOSIS_SCRIPT_IDENTITY_DRIFT",
    )

    payload = marker_payload(DIAGNOSIS_ROOT / "godot.log", DIAGNOSIS_MARKER)
    diagnosis = json.loads(payload)
    require(isinstance(diagnosis, dict), "DIAGNOSIS_MARKER_NOT_OBJECT")
    require(
        diagnosis.get("schema_version")
        == "sporespore_qsdk_r10b_l2_retained_trace_diagnosis_v1"
        and diagnosis.get("gate_id") == "QSDK-R10B"
        and diagnosis.get("repair_id") == "QSDK-R10B-L2"
        and diagnosis.get("ok") is True
        and diagnosis.get("failure_code") == ""
        and diagnosis.get("retained_cell_id") == "baseline_s50300"
        and diagnosis.get("retained_trace_row_count") == 2640
        and diagnosis.get("generic_trace_validation_failure_code")
        == "QSDK_R10B_TRACE_ROW_KINEMATICS_INVALID"
        and diagnosis.get("orientation_validation_failure_count") == 2640
        and diagnosis.get("projection_receipt_exact_failure_count") == 2640
        and diagnosis.get("projection_receipt_numeric_recomputation_failure_count")
        == 2637
        and diagnosis.get("projection_receipt_dictionary_only_equality_failure_count")
        == 3
        and diagnosis.get("projection_receipt_key_set_failure_count") == 0
        and diagnosis.get("projection_receipt_static_field_failure_count") == 0
        and diagnosis.get("row_orientation_projection_link_failure_count") == 0
        and diagnosis.get("projected_orientation_length_contract_failure_count") == 0
        and diagnosis.get("source_orientation_length_contract_failure_count") == 2565
        and diagnosis.get("task_axis_unit_failure_count") == 2640
        and diagnosis.get("task_axis_exported_scalar_unit_failure_count") == 0
        and diagnosis.get("task_axis_orthogonality_failure_count") == 0
        and diagnosis.get("task_axis_exported_scalar_orthogonality_failure_count") == 0
        and diagnosis.get("task_frame_approximate_change_count") == 0
        and diagnosis.get("task_frame_exact_change_count") == 0
        and diagnosis.get("other_row_contract_failure_total") == 0
        and diagnosis.get("projection_receipt_field_mismatch_counts")
        == EXPECTED_RECEIPT_FIELD_MISMATCH_COUNTS,
        "DIAGNOSIS_COUNTS_DRIFT",
    )
    first_projection = diagnosis.get("first_projection_receipt_difference")
    first_axis = diagnosis.get("first_task_axis_host_unit_failure")
    maximum_projection = diagnosis.get("maximum_projection_receipt_numeric_difference")
    require(
        isinstance(first_projection, dict)
        and first_projection.get("row_index") == 0
        and first_projection.get("key") == "orientation_xyzw"
        and first_projection.get("component_index") == 1
        and math.isclose(
            float(first_projection.get("absolute_delta", math.nan)),
            3.74049749507499e-18,
            rel_tol=0.0,
            abs_tol=0.0,
        )
        and isinstance(maximum_projection, dict)
        and maximum_projection.get("row_index") == 106
        and maximum_projection.get("key") == "source_norm_squared"
        and math.isclose(
            float(maximum_projection.get("absolute_delta", math.nan)),
            4.440892098500626e-16,
            rel_tol=0.0,
            abs_tol=0.0,
        )
        and isinstance(first_axis, dict)
        and first_axis.get("row_index") == 0
        and math.isclose(
            float(first_axis.get("forward_host_norm_delta", math.nan)),
            5.960464477539063e-8,
            rel_tol=0.0,
            abs_tol=0.0,
        )
        and math.isclose(
            float(diagnosis.get("maximum_task_axis_host_norm_delta", math.nan)),
            5.960464477539063e-8,
            rel_tol=0.0,
            abs_tol=0.0,
        )
        and math.isclose(
            float(
                diagnosis.get("maximum_task_axis_exported_scalar_norm_delta", math.nan)
            ),
            2.220446049250313e-16,
            rel_tol=0.0,
            abs_tol=0.0,
        ),
        "DIAGNOSIS_NUMERIC_DETAIL_DRIFT",
    )
    for field in (
        "scene_tree_child_count",
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "native_readback_count",
        "solver_step_count",
    ):
        require(diagnosis.get(field) == 0, f"DIAGNOSIS_NONZERO_{field.upper()}")
    require(
        diagnosis.get("physics_state_modified") is False
        and diagnosis.get("physical_acceptance_authority") is False
        and diagnosis.get("release_authority") is False
        and support.get("authority_mode")
        == "posthoc_exploratory_zero_world_diagnosis_non_authoritative",
        "DIAGNOSIS_AUTHORITY_DRIFT",
    )
    return diagnosis


def validate_source_defect_boundary() -> None:
    evaluator = bytes(
        git(
            (
                "show",
                f"{SOURCE_COMMIT}:scripts/lab/gait/qsdk_r10b_bounded_upright_push_recovery.gd",
            ),
            binary=True,
        )
    ).decode("utf-8")
    helper = bytes(
        git(
            (
                "show",
                f"{SOURCE_COMMIT}:sdk/adapters/godot/gdscript/quaternion_scalar_projection_v1.gd",
            ),
            binary=True,
        )
    ).decode("utf-8")
    require(
        "const VECTOR_TOLERANCE := 1.0e-12" in evaluator
        and "const QUATERNION_NORM_TOLERANCE := 1.0e-9" in evaluator
        and "absf(forward.length() - 1.0) > VECTOR_TOLERANCE" in evaluator
        and "absf(lateral.length() - 1.0) > VECTOR_TOLERANCE" in evaluator
        and "receipt == expected" in helper
        and 'receipt.get("orientation_xyzw", null) == orientation_value' in helper,
        "SOURCE_VALIDATOR_DEFECT_BOUNDARY_DRIFT",
    )


def validate_closure_document(closure: dict[str, Any]) -> None:
    require(
        closure.get("schema_version")
        == "sporespore_qsdk_r10b_l2_development_route_ghost_physical_invalid_closure_v1"
        and closure.get("status")
        == "closed_consumed_infrastructure_invalid_compound_trace_representation_validation"
        and closure.get("gate_id") == "QSDK-R10B"
        and closure.get("repair_id") == "QSDK-R10B-L2"
        and closure.get("closure_id") == "QSDK-R10B-L2-P1"
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
    diagnosis = closure.get("causal_diagnosis", {})
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
        diagnosis.get("classification")
        == "compound_post_physics_trace_representation_validator_failure"
        and diagnosis.get("single_original_failing_subpredicate_claimed") is False
        and diagnosis.get(
            "retained_trace_replay_establishes_multiple_independent_refusal_paths"
        )
        is True
        and diagnosis.get("integration_validation_failure_established") is True
        and diagnosis.get("physics_failure_established") is False
        and diagnosis.get("behavior_result_established") is False,
        "CLOSURE_DIAGNOSIS_BOUNDARY_DRIFT",
    )
    require(
        decision.get("valid_positive_or_negative_route_result_observed") is False
        and decision.get("selected_successor_id") == "QSDK-R10B-L3"
        and decision.get("selection_uses_quarantined_behavior_outcome") is False
        and decision.get("behavior_threshold_changed") is False
        and decision.get("quaternion_length_tolerance_changed") is False
        and decision.get("task_axis_exported_scalar_unit_tolerance_changed") is False
        and decision.get("historical_result_rewritten") is False,
        "CLOSURE_DECISION_DRIFT",
    )
    require(
        successor.get("status")
        == "selected_representation_validation_successor_not_yet_designed_or_qualified"
        and successor.get("physical_execution_blocked") is True
        and successor.get("maximum_world_attempt_count_before_qualification") == 0
        and successor.get("maximum_world_build_count_before_qualification") == 0
        and successor.get("held_out_cells_remain_sealed") is True,
        "CLOSURE_SUCCESSOR_BOUNDARY_DRIFT",
    )
    require(
        claims.get("one_genuine_godot_jolt_world_claimed") is True
        and claims.get("l2_projected_quaternion_length_repair_claimed") is True
        and claims.get("compound_trace_representation_validator_failure_claimed")
        is True
        and claims.get("single_original_failing_subpredicate_claimed") is False
        and claims.get("bounded_upright_push_recovery_claimed") is False
        and claims.get("ordinary_walking_negative_claimed") is False
        and claims.get("external_push_effect_claimed") is False
        and claims.get("physical_acceptance_authority") is False
        and claims.get("release_authority") is False,
        "CLOSURE_CLAIM_BOUNDARY_DRIFT",
    )


def validate_mutation_controls(closure: dict[str, Any]) -> int:
    mutations: list[tuple[tuple[str, ...], Any, Any]] = [
        (("status",), "closed_valid_behavior_result", validate_closure_document),
        (
            ("physical_attempt", "physical_identity_consumed"),
            False,
            validate_closure_document,
        ),
        (
            ("causal_diagnosis", "single_original_failing_subpredicate_claimed"),
            True,
            validate_closure_document,
        ),
        (
            ("decision", "valid_positive_or_negative_route_result_observed"),
            True,
            validate_closure_document,
        ),
        (
            ("successor_boundary", "physical_execution_blocked"),
            False,
            validate_closure_document,
        ),
        (
            ("claim_boundary", "bounded_upright_push_recovery_claimed"),
            True,
            validate_closure_document,
        ),
        (
            ("physical_attempt", "retained_tree", "manifest_canonical_sha256"),
            "sha256:" + "0" * 64,
            validate_physical_evidence,
        ),
        (
            ("source_graph", "implementation_source", "tree"),
            "0" * 40,
            validate_source_graph,
        ),
        (
            ("supporting_zero_world_diagnosis", "file", "raw_sha256"),
            "sha256:" + "0" * 64,
            validate_supporting_diagnosis,
        ),
        (
            ("zero_world_authorization_boundary", "qualification_file_count"),
            6,
            validate_qualification,
        ),
    ]
    rejected = 0
    for path, replacement, validator in mutations:
        candidate = copy.deepcopy(closure)
        target: dict[str, Any] = candidate
        for key in path[:-1]:
            child = target.get(key)
            require(isinstance(child, dict), "MUTATION_TARGET_NOT_OBJECT")
            target = child
        target[path[-1]] = replacement
        try:
            validator(candidate)
        except ClosureFailure:
            rejected += 1
        else:
            raise ClosureFailure("CLOSURE_MUTATION_ACCEPTED:" + ".".join(path))
    require(rejected == len(mutations), "CLOSURE_MUTATION_REJECTION_COUNT_DRIFT")
    return rejected


def main() -> int:
    try:
        validate_repository_identity()
        closure = read_json(CLOSURE_PATH, "R10B_L2_PHYSICAL_INVALID_CLOSURE")
        validate_closure_document(closure)
        validate_source_graph(closure)
        validate_qualification(closure)
        physical = validate_physical_evidence(closure)
        diagnosis = validate_supporting_diagnosis(closure)
        validate_source_defect_boundary()
        mutation_rejection_count = validate_mutation_controls(closure)
        receipt = {
            "schema_version": (
                "sporespore_qsdk_r10b_l2_development_route_ghost_"
                "physical_invalid_closure_audit_v1"
            ),
            "gate_id": "QSDK-R10B",
            "repair_id": "QSDK-R10B-L2",
            "closure_id": "QSDK-R10B-L2-P1",
            "ok": True,
            "failure_code": "",
            "retained_file_count": 6,
            "retained_physical_attempt_file_count": 4,
            "retained_posthoc_zero_world_file_count": 2,
            "retained_total_byte_length": 13_167_691,
            "retained_world_attempt_count": 1,
            "retained_world_build_count": 1,
            "retained_physics_tick_count": 2880,
            "retained_trace_row_count": physical["trace_row_count"],
            "projected_quaternion_tolerance_failure_count": physical[
                "projected_quaternion_failure_count"
            ],
            "source_quaternion_tolerance_failure_count": physical[
                "source_quaternion_failure_count"
            ],
            "projection_receipt_exact_failure_count": diagnosis[
                "projection_receipt_exact_failure_count"
            ],
            "float32_task_axis_unit_failure_count": diagnosis[
                "task_axis_unit_failure_count"
            ],
            "exported_scalar_task_axis_unit_failure_count": diagnosis[
                "task_axis_exported_scalar_unit_failure_count"
            ],
            "push_world_attempt_count": 0,
            "pair_evaluator_invocation_count": 0,
            "valid_behavior_result_count": 0,
            "physical_identity_consumed": True,
            "same_identity_rerun_permitted": False,
            "selected_successor_id": "QSDK-R10B-L3",
            "behavior_threshold_changed": False,
            "quaternion_length_tolerance_changed": False,
            "task_axis_exported_scalar_unit_tolerance_changed": False,
            "closure_mutation_rejection_count": mutation_rejection_count,
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
        print(f"QSDK_R10B_L2_PHYSICAL_INVALID_CLOSURE_FAIL {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
