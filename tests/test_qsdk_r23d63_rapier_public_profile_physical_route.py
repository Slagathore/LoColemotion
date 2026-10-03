#!/usr/bin/env python3
"""Zero-world audit of the R23D63 Rapier production profile route."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
from typing import Any


MARKER = "QSDK_R23D63_RAPIER_PUBLIC_PROFILE_ROUTE "
SCHEMA = (
    "sporespore_qsdk_r23d63_rapier_public_profile_" "production_route_zero_world_v1"
)
CAMPAIGN_ID = "QSDK-R23D63-RECEIPT-SCHEMA-REPAIRED-SELECTED-PROFILE-MATCHED-THREE-ENGINE-TURNING-VALIDATION"
PROFILE_ID = "sporespore_qsdk_r23d60_selected_s169_actuator_cap_profile_v1"
PROFILE_SHA256 = (
    "sha256:b65d41e3f30c42e0a8207f1385fe00daa8f03975f4e266a0bd0867970f674964"
)
HOST_MAPPING_ID = "sporespore_rapier_force_based_outer_impulse_cap_mapping_v1"
ACTUATOR_IDS = (
    "front_left_hip_motor",
    "front_left_knee_motor",
    "front_right_hip_motor",
    "front_right_knee_motor",
    "rear_left_hip_motor",
    "rear_left_knee_motor",
    "rear_right_hip_motor",
    "rear_right_knee_motor",
)
JOINT_IDS = tuple(value.removesuffix("_motor") for value in ACTUATOR_IDS)
CAPS = (
    0.05362625170687301,
    0.4567500054836273,
    0.05362625170687301,
    0.4567500054836273,
    0.05637374829312699,
    0.4567500054836273,
    0.05637374829312699,
    0.4567500054836273,
)
EXPECTED_STATUS = (
    "prospective_campaign_machinery_implemented_receipt_schema_gate_passed_"
    "complete_zero_world_gate_passed_physical_not_opened"
)


class RouteAuditError(RuntimeError):
    """The zero-world production dependency route is not exact."""


def require(condition: bool, code: str) -> None:
    if not condition:
        raise RouteAuditError(code)


def raw_sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def find_campaign_records(value: Any) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    if isinstance(value, dict):
        if value.get("campaign_id") == CAMPAIGN_ID:
            records.append(value)
        for child in value.values():
            records.extend(find_campaign_records(child))
    elif isinstance(value, list):
        for child in value:
            records.extend(find_campaign_records(child))
    return records


def audit_authority_records(repo_root: Path) -> None:
    release_path = repo_root / "sdk/release/quadruped_release_contract.json"
    matrix_path = repo_root / "sdk/release/quadruped_support_matrix.json"
    contract_records = find_campaign_records(
        json.loads(release_path.read_text(encoding="utf-8"))
    )
    matrix_records = find_campaign_records(
        json.loads(matrix_path.read_text(encoding="utf-8"))
    )
    require(
        len(contract_records) == 1,
        "QSDK_R23D63_RAP_ROUTE_CONTRACT_CARDINALITY_INVALID",
    )
    require(
        len(matrix_records) == 1,
        "QSDK_R23D63_RAP_ROUTE_MATRIX_CARDINALITY_INVALID",
    )
    path_fields = (
        (
            "rapier_public_profile_mapping_path",
            "rapier_public_profile_mapping",
            repo_root / "sdk/adapters/rapier/src/actuator_cap_profile.rs",
        ),
        (
            "rapier_production_physical_constructor_path",
            "rapier_production_physical_constructor",
            repo_root / "sdk/adapters/rapier/src/locomotion.rs",
        ),
        (
            "rapier_public_profile_route_path",
            "rapier_public_profile_route",
            repo_root / "sdk/adapters/rapier/src/qsdk_r23d63_public_profile_route.rs",
        ),
        (
            "rapier_route_binary_path",
            "rapier_route_binary",
            repo_root
            / "sdk/adapters/rapier/src/bin/qsdk_r23d63_public_profile_route.rs",
        ),
        (
            "rapier_route_audit_path",
            "rapier_route_audit",
            repo_root
            / "tests/test_qsdk_r23d63_rapier_public_profile_physical_route.py",
        ),
        (
            "rapier_route_gate_path",
            "rapier_route_gate",
            repo_root
            / "tests/test_qsdk_r23d63_rapier_public_profile_physical_route.ps1",
        ),
        (
            "implementation_path",
            "implementation",
            repo_root / "sdk/turning/"
            "r23d63_selected_profile_three_engine_turning_validation_"
            "implementation_v1.json",
        ),
    )
    for record, hash_suffix in (
        (contract_records[0], "_raw_sha256"),
        (matrix_records[0], "_sha256"),
    ):
        require(
            record.get("status") == EXPECTED_STATUS,
            "QSDK_R23D63_RAP_ROUTE_AUTHORITY_STATUS_INVALID",
        )
        for path_field, hash_stem, path in path_fields:
            require(
                record.get(path_field) == path.relative_to(repo_root).as_posix(),
                "QSDK_R23D63_RAP_ROUTE_AUTHORITY_PATH_INVALID:" + path_field,
            )
            require(
                record.get(hash_stem + hash_suffix) == raw_sha256(path),
                "QSDK_R23D63_RAP_ROUTE_AUTHORITY_HASH_INVALID:" + hash_stem,
            )
        require(
            record.get("rapier_public_profile_dependency_route_zero_world_passed")
            is True
            and record.get("rapier_route_validated_actuator_count") == 8
            and record.get("rapier_route_mutation_rejection_count") == 15
            and record.get("rapier_route_support_refusal_control_count") == 2
            and record.get("rapier_route_model_construction_count") == 0
            and record.get("rapier_route_world_attempt_count") == 0
            and record.get("rapier_route_world_build_count") == 0
            and record.get("implemented_native_dependency_route_count") == 3
            and record.get("implemented_native_worker_count") == 3,
            "QSDK_R23D63_RAP_ROUTE_AUTHORITY_COUNTS_INVALID",
        )
        require(
            record.get("physical_campaign_opened") is False
            and record.get("finite_three_engine_turning") is False
            and record.get("q_sdk_r23_satisfied") is False
            and record.get("release_authorized") is False,
            "QSDK_R23D63_RAP_ROUTE_AUTHORITY_NONCLAIMS_INVALID",
        )


def run_route(repo_root: Path) -> dict[str, Any]:
    completed = subprocess.run(
        [
            "cargo",
            "run",
            "-q",
            "-p",
            "sporespore-rapier-adapter",
            "--bin",
            "qsdk_r23d63_public_profile_route",
            "--offline",
        ],
        cwd=repo_root / "sdk",
        text=True,
        capture_output=True,
        check=False,
    )
    if completed.returncode != 0:
        raise RouteAuditError(
            "QSDK_R23D63_RAP_ROUTE_PROCESS_FAILED:"
            f"{completed.returncode}:{completed.stdout[-1000:]}:"
            f"{completed.stderr[-1000:]}"
        )
    markers = [
        line.removeprefix(MARKER)
        for line in completed.stdout.splitlines()
        if line.startswith(MARKER)
    ]
    require(len(markers) == 1, "QSDK_R23D63_RAP_ROUTE_MARKER_INVALID")
    try:
        value = json.loads(markers[0])
    except json.JSONDecodeError as error:
        raise RouteAuditError("QSDK_R23D63_RAP_ROUTE_JSON_INVALID") from error
    require(isinstance(value, dict), "QSDK_R23D63_RAP_ROUTE_RECEIPT_TYPE")
    return value


def audit_shared_source_route(repo_root: Path) -> None:
    locomotion = (repo_root / "sdk/adapters/rapier/src/locomotion.rs").read_text(
        encoding="utf-8"
    )
    route = (
        repo_root / "sdk/adapters/rapier/src/qsdk_r23d63_public_profile_route.rs"
    ).read_text(encoding="utf-8")
    constructor = "fn build_bw19v_velocity_only_v4_robot_with_public_profile("
    shared_call = (
        "compile_actuator_force_plan_v1(compiled, motor_profile, "
        "public_profile_binding)?"
    )
    constructor_index = locomotion.find(constructor)
    shared_call_index = locomotion.find(shared_call, constructor_index)
    world_index = locomotion.find("new_active_world(", shared_call_index)
    require(
        constructor_index >= 0
        and shared_call_index > constructor_index
        and world_index > shared_call_index,
        "QSDK_R23D63_RAP_ROUTE_CONSTRUCTOR_ORDER_INVALID",
    )
    require(
        "compile_public_profile_actuator_force_plan_v1(&compiled, &binding)?" in route
        and "new_active_world(" not in route
        and "build_bw19v_velocity_only_v4_robot_with_public_profile(" not in route,
        "QSDK_R23D63_RAP_ROUTE_ZERO_WORLD_SOURCE_INVALID",
    )


def audit_receipt(repo_root: Path, value: dict[str, Any]) -> None:
    expected_false = (
        "physics_state_modified",
        "physical_execution_authorized",
        "turning_claimed",
        "finite_three_engine_turning_claimed",
        "q_sdk_r23_satisfied",
        "physical_acceptance_authority",
        "release_authority",
    )
    require(
        value.get("schema_version") == SCHEMA
        and value.get("ok") is True
        and value.get("campaign_id") == CAMPAIGN_ID
        and value.get("gate_id") == "QSDK-R23D63"
        and value.get("engine_id") == "rapier_parry"
        and value.get("profile_id") == PROFILE_ID
        and value.get("profile_sha256") == PROFILE_SHA256
        and value.get("host_mapping_id") == HOST_MAPPING_ID
        and value.get("validated_actuator_count") == 8
        and value.get("force_plan_compiled_before_first_native_model") is True
        and value.get("same_typed_force_plan_consumed_by_physical_constructor") is True
        and value.get("historical_constructor_behavior_changed") is False
        and value.get("mutation_rejection_count") == 15
        and all(value.get(field) is False for field in expected_false)
        and all(
            value.get(field) == 0
            for field in (
                "rigid_body_set_construction_count",
                "collider_set_construction_count",
                "physics_pipeline_construction_count",
                "model_construction_count",
                "world_attempt_count",
                "world_build_count",
                "solver_step_count",
            )
        ),
        "QSDK_R23D63_RAP_ROUTE_HEADER_INVALID",
    )
    mutations = value.get("mutation_results")
    support = value.get("support_controls")
    plan = value.get("ordered_production_force_plan")
    require(
        isinstance(mutations, list)
        and len(mutations) == 15
        and all(item.get("rejected") is True for item in mutations)
        and isinstance(support, dict)
        and support.get("control_count") == 2
        and support.get("valid_out_of_domain_morphology_refused") is True
        and support.get("unsupported_profile_refused") is True
        and isinstance(plan, list)
        and len(plan) == 8,
        "QSDK_R23D63_RAP_ROUTE_CONTROLS_INVALID",
    )
    for index, (entry, actuator_id, joint_id, cap) in enumerate(
        zip(plan, ACTUATOR_IDS, JOINT_IDS, CAPS, strict=True)
    ):
        require(
            isinstance(entry, dict)
            and entry.get("actuator_id") == actuator_id
            and entry.get("joint_id") == joint_id
            and entry.get("portable_maximum_outer_step_impulse_nms") == cap
            and isinstance(entry.get("rapier_maximum_force_nm_f32"), (int, float))
            and float(entry["rapier_maximum_force_nm_f32"]) > 0.0,
            f"QSDK_R23D63_RAP_ROUTE_PLAN_ENTRY_INVALID:{index}",
        )

    sys.path.insert(0, str(repo_root / "sdk/turning"))
    import r23d63_selected_profile_three_engine_turning_validation as design
    import r23d63_selected_profile_three_engine_turning_validation_evaluator_v2 as evaluator

    evaluator._install_corrected_identity_projection()
    item = design.cell("rapier_parry", "reference_zero")
    resolution_failures = evaluator.legacy._resolution_failures(
        value.get("actuator_cap_profile_resolution_receipt")
    )
    mapping_failures = evaluator.legacy._host_mapping_failures(
        value.get("actuator_cap_profile_host_mapping_receipt"), item
    )
    require(
        resolution_failures == [] and mapping_failures == [],
        "QSDK_R23D63_RAP_ROUTE_EVALUATOR_PROJECTION_INVALID:"
        f"{resolution_failures}:{mapping_failures}",
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", type=Path, required=True)
    arguments = parser.parse_args()
    repo_root = arguments.repo_root.resolve()
    try:
        audit_shared_source_route(repo_root)
        audit_authority_records(repo_root)
        receipt = run_route(repo_root)
        audit_receipt(repo_root, receipt)
    except (OSError, json.JSONDecodeError, RouteAuditError) as error:
        print(f"QSDK_R23D63_RAPIER_PUBLIC_PROFILE_ROUTE_FAILURE {error}")
        return 1
    print(
        "QSDK_R23D63_RAPIER_PUBLIC_PROFILE_ROUTE_PASS "
        "actuators=8 mutations=15 support_controls=2 models=0 worlds=0 "
        "physical=False turning=False qsdk_r23=False release=False"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
