#!/usr/bin/env python3
"""Zero-world audit of the R23D64 MuJoCo production profile route."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys
from typing import Any


CAMPAIGN_ID = "QSDK-R23D64-RAPIER-LAUNCH-CONTRACT-REPAIRED-SELECTED-PROFILE-MATCHED-THREE-ENGINE-TURNING-VALIDATION"
PROFILE_ID = "sporespore_qsdk_r23d60_selected_s169_actuator_cap_profile_v1"
PROFILE_SHA256 = (
    "sha256:b65d41e3f30c42e0a8207f1385fe00daa8f03975f4e266a0bd0867970f674964"
)
HOST_MAPPING_ID = "sporespore_mujoco_velocity_force_range_cap_mapping_v1"
EXPECTED_STATUS = (
    "prospective_campaign_machinery_implemented_receipt_schema_and_rapier_"
    "launcher_contract_gates_passed_"
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
    paths = {
        "mujoco_public_profile_mapping": repo_root
        / "sdk/adapters/mujoco/sporespore_mujoco_adapter/actuator_cap_profile.py",
        "mujoco_production_model_xml_builder": repo_root
        / "sdk/adapters/mujoco/sporespore_mujoco_adapter/selected_policy_development.py",
        "mujoco_public_profile_route": repo_root
        / "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d64_public_profile_route.py",
        "mujoco_route_audit": repo_root
        / "tests/test_qsdk_r23d64_mujoco_public_profile_physical_route.py",
        "mujoco_route_gate": repo_root
        / "tests/test_qsdk_r23d64_mujoco_public_profile_physical_route.ps1",
        "implementation": repo_root
        / "sdk/turning/r23d64_selected_profile_three_engine_turning_validation_implementation_v1.json",
    }
    for authority_path, hash_suffix in (
        (repo_root / "sdk/release/quadruped_release_contract.json", "_raw_sha256"),
        (repo_root / "sdk/release/quadruped_support_matrix.json", "_sha256"),
    ):
        records = find_campaign_records(
            json.loads(authority_path.read_text(encoding="utf-8"))
        )
        require(
            len(records) == 1,
            "QSDK_R23D64_MJC_ROUTE_AUTHORITY_CARDINALITY_INVALID",
        )
        record = records[0]
        require(
            record.get("status") == EXPECTED_STATUS,
            "QSDK_R23D64_MJC_ROUTE_AUTHORITY_STATUS_INVALID",
        )
        for stem, path in paths.items():
            require(
                record.get(stem + "_path") == path.relative_to(repo_root).as_posix()
                and record.get(stem + hash_suffix) == raw_sha256(path),
                f"QSDK_R23D64_MJC_ROUTE_AUTHORITY_BINDING_INVALID:{stem}",
            )
        require(
            record.get("mujoco_public_profile_dependency_route_zero_world_passed")
            is True
            and record.get("mujoco_route_validated_actuator_count") == 8
            and record.get("mujoco_route_mutation_rejection_count") == 17
            and record.get("mujoco_route_support_refusal_control_count") == 2
            and record.get("mujoco_route_model_construction_count") == 0
            and record.get("mujoco_route_world_attempt_count") == 0
            and record.get("mujoco_route_world_build_count") == 0
            and record.get("implemented_native_dependency_route_count") == 3
            and record.get("implemented_native_worker_count") == 3,
            "QSDK_R23D64_MJC_ROUTE_AUTHORITY_COUNTS_INVALID",
        )
        require(
            record.get("physical_campaign_opened") is False
            and record.get("finite_three_engine_turning") is False
            and record.get("q_sdk_r23_satisfied") is False
            and record.get("release_authorized") is False,
            "QSDK_R23D64_MJC_ROUTE_AUTHORITY_NONCLAIMS_INVALID",
        )


def audit_shared_source_route(repo_root: Path) -> None:
    route = (
        repo_root
        / "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d64_public_profile_route.py"
    ).read_text(encoding="utf-8")
    worker = (
        repo_root
        / "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d64_selected_profile_turning.py"
    ).read_text(encoding="utf-8")
    require(
        "def compile_public_profile_model_route(" in route
        and "build_model_xml(compiled, PER_ACTUATOR_VH5_CHARACTERIZED_PROFILE_ID)"
        in route
        and "mujoco.MjModel.from_xml_string(" not in route
        and "compile_public_profile_model_route(" in worker
        and "self.model = mujoco.MjModel.from_xml_string(self.model_xml)" in worker
        and "self.model_xml = route.model_xml" in worker,
        "QSDK_R23D64_MJC_ROUTE_SHARED_SOURCE_INVALID",
    )


class _FakeActuator:
    def __init__(self, native_id: int) -> None:
        self.id = native_id


class _FakeModel:
    def __init__(
        self, actuator_ids: tuple[str, ...], force_ranges: list[list[float]]
    ) -> None:
        self._ids = {value: index for index, value in enumerate(actuator_ids)}
        self.actuator_forcerange = force_ranges

    def actuator(self, actuator_id: str) -> _FakeActuator:
        return _FakeActuator(self._ids[actuator_id])


def audit_route(repo_root: Path) -> None:
    sys.path[:0] = [
        str(repo_root / "sdk/python"),
        str(repo_root / "sdk/adapters/mujoco"),
        str(repo_root / "sdk/turning"),
    ]
    from sporespore_locomotion import LocomotionCore
    from sporespore_mujoco_adapter import (
        qsdk_r23d64_public_profile_route as route_module,
    )
    import r23d64_selected_profile_three_engine_turning_validation as design
    import r23d64_selected_profile_three_engine_turning_validation_evaluator_v2 as evaluator

    core = LocomotionCore(repo_root / "sdk/target/debug/sporespore_locomotion_core.dll")
    value = route_module.run_zero_world_preflight(core)
    require(
        value.get("schema_version")
        == "sporespore_qsdk_r23d64_mujoco_public_profile_production_route_zero_world_v1"
        and value.get("ok") is True
        and value.get("campaign_id") == CAMPAIGN_ID
        and value.get("gate_id") == "QSDK-R23D64"
        and value.get("engine_id") == "mujoco"
        and value.get("profile_id") == PROFILE_ID
        and value.get("profile_sha256") == PROFILE_SHA256
        and value.get("host_mapping_id") == HOST_MAPPING_ID
        and value.get("validated_actuator_count") == 8
        and value.get("model_xml_byte_length") > 0
        and str(value.get("model_xml_sha256", "")).startswith("sha256:")
        and value.get("full_model_xml_compiled_before_first_mjmodel") is True
        and value.get("same_full_model_xml_consumed_by_physical_constructor") is True
        and value.get("historical_constructor_behavior_changed") is False
        and value.get("mutation_rejection_count") == 17
        and len(value.get("mutation_results", [])) == 17
        and all(
            item.get("rejected") is True for item in value.get("mutation_results", [])
        )
        and value.get("support_controls", {}).get("control_count") == 2
        and value.get("support_controls", {}).get(
            "valid_out_of_domain_morphology_refused"
        )
        is True
        and value.get("support_controls", {}).get("unsupported_profile_refused") is True
        and all(
            value.get(field) == 0
            for field in (
                "model_construction_count",
                "data_construction_count",
                "world_attempt_count",
                "world_build_count",
                "solver_step_count",
            )
        )
        and value.get("physics_state_modified") is False
        and value.get("physical_execution_authorized") is False
        and value.get("turning_claimed") is False
        and value.get("q_sdk_r23_satisfied") is False
        and value.get("physical_acceptance_authority") is False
        and value.get("release_authority") is False,
        "QSDK_R23D64_MJC_ROUTE_RECEIPT_INVALID",
    )

    evaluator._install_corrected_identity_projection()
    item = design.cell("mujoco", "reference_zero")
    resolution = value["actuator_cap_profile_resolution_receipt"]
    mapping = value["actuator_cap_profile_host_mapping_receipt"]
    resolution_failures = evaluator.legacy._resolution_failures(resolution)
    mapping_failures = evaluator.legacy._host_mapping_failures(mapping, item)
    require(
        resolution_failures == [] and mapping_failures == [],
        "QSDK_R23D64_MJC_ROUTE_EVALUATOR_PROJECTION_INVALID:"
        f"{resolution_failures}:{mapping_failures}",
    )

    production_route = route_module.compile_public_profile_model_route(core)
    force_ranges = [
        list(mapping_item["mujoco_symmetric_force_range_nm"])
        for mapping_item in mapping["ordered_mappings"]
    ]
    fake_model = _FakeModel(route_module.ORDERED_ACTUATOR_IDS, force_ranges)
    physical_binding = route_module.physical_binding_receipt(
        fake_model,
        production_route,
    )
    binding_failures = evaluator.legacy._physical_binding_failures(
        physical_binding,
        item,
        mapping,
    )
    require(
        binding_failures == []
        and physical_binding.get("solver_step_count_at_binding") == 0
        and physical_binding.get("write_count") == 8
        and physical_binding.get("readback_count") == 8,
        "QSDK_R23D64_MJC_ROUTE_PHYSICAL_BINDING_PROJECTION_INVALID:"
        f"{binding_failures}",
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", type=Path, required=True)
    arguments = parser.parse_args()
    repo_root = arguments.repo_root.resolve()
    try:
        audit_shared_source_route(repo_root)
        audit_authority_records(repo_root)
        audit_route(repo_root)
    except (
        OSError,
        KeyError,
        TypeError,
        ValueError,
        RouteAuditError,
    ) as error:
        print(
            "QSDK_R23D64_MUJOCO_PUBLIC_PROFILE_ROUTE_FAILURE "
            f"{type(error).__name__}:{error}"
        )
        return 1
    print(
        "QSDK_R23D64_MUJOCO_PUBLIC_PROFILE_ROUTE_PASS "
        "actuators=8 mutations=17 support_controls=2 models=0 worlds=0 "
        "physical=False turning=False qsdk_r23=False release=False"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
