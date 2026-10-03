#!/usr/bin/env python3
"""Materialize the mechanically inherited R23D65 successor source surface.

This tool performs only the declared namespace, campaign-stage, and unused-seed
substitution. Successor-specific runtime-integration repairs are reviewed and
audited separately. It may resume an interrupted materialization only when each
existing destination is byte-for-byte equal to its mechanical output; it never
overwrites a destination.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys
from typing import Sequence


REPO_ROOT = Path(__file__).resolve().parents[2]
SOURCE_CAMPAIGN_ID = (
    "QSDK-R23D64-RAPIER-LAUNCH-CONTRACT-REPAIRED-SELECTED-PROFILE-"
    "MATCHED-THREE-ENGINE-TURNING-VALIDATION"
)
SUCCESSOR_CAMPAIGN_ID = (
    "QSDK-R23D65-RUNTIME-INTEGRATION-REPAIRED-SELECTED-PROFILE-"
    "MATCHED-THREE-ENGINE-TURNING-VALIDATION"
)
SOURCE_CAMPAIGN_SPLIT_PREFIX = (
    "QSDK-R23D64-RAPIER-LAUNCH-CONTRACT-REPAIRED-SELECTED-PROFILE-MATCHED-"
)
SUCCESSOR_CAMPAIGN_SPLIT_PREFIX = (
    "QSDK-R23D65-RUNTIME-INTEGRATION-REPAIRED-SELECTED-PROFILE-MATCHED-"
)
SOURCE_CAMPAIGN_LITERAL_PREFIX = (
    "QSDK-R23D64-RAPIER-LAUNCH-CONTRACT-REPAIRED-SELECTED-PROFILE-"
)
SUCCESSOR_CAMPAIGN_LITERAL_PREFIX = (
    "QSDK-R23D65-RUNTIME-INTEGRATION-REPAIRED-SELECTED-PROFILE-"
)
SOURCE_STAGE_ID = (
    "rapier_launch_contract_repaired_selected_profile_matched_three_engine_"
    "turning_validation"
)
SUCCESSOR_STAGE_ID = (
    "runtime_integration_repaired_selected_profile_matched_three_engine_"
    "turning_validation"
)
SOURCE_SEED = "23171"
SUCCESSOR_SEED = "23175"
SOURCE_SEED_GROUPED = "23_171"
SUCCESSOR_SEED_GROUPED = "23_175"

MAPPINGS = (
    ("sdk/turning/r23d64_campaign_attestation_manifest_v1.json", "sdk/turning/r23d65_campaign_attestation_manifest_v1.json"),
    ("sdk/turning/r23d64_dependency_closure.py", "sdk/turning/r23d65_dependency_closure.py"),
    ("sdk/turning/r23d64_seed_fixture_compiler.gd", "sdk/turning/r23d65_seed_fixture_compiler.gd"),
    ("sdk/turning/r23d64_selected_profile_three_engine_turning_validation.py", "sdk/turning/r23d65_selected_profile_three_engine_turning_validation.py"),
    ("sdk/turning/r23d64_selected_profile_three_engine_turning_validation_evaluator.py", "sdk/turning/r23d65_selected_profile_three_engine_turning_validation_evaluator.py"),
    ("sdk/turning/r23d64_selected_profile_three_engine_turning_validation_implementation_v1.json", "sdk/turning/r23d65_selected_profile_three_engine_turning_validation_implementation_v1.json"),
    ("sdk/turning/r23d64_selected_profile_three_engine_turning_validation_preregistration_v1.json", "sdk/turning/r23d65_selected_profile_three_engine_turning_validation_preregistration_v1.json"),
    ("sdk/turning/r23d64_rapier_launcher_contract.ps1", "sdk/turning/r23d65_rapier_launcher_contract.ps1"),
    ("sdk/run_qsdk_r23d64_supervisor.ps1", "sdk/run_qsdk_r23d65_supervisor.ps1"),
    ("tests/test_qsdk_r23d64_authorization_receipt_schema.ps1", "tests/test_qsdk_r23d65_authorization_receipt_schema.ps1"),
    ("tests/test_qsdk_r23d64_campaign_roles.ps1", "tests/test_qsdk_r23d65_campaign_roles.ps1"),
    ("tests/test_qsdk_r23d64_dependency_closure.ps1", "tests/test_qsdk_r23d65_dependency_closure.ps1"),
    ("tests/test_qsdk_r23d64_evaluator.ps1", "tests/test_qsdk_r23d65_evaluator.ps1"),
    ("tests/test_qsdk_r23d64_godot_jolt_physical_worker.ps1", "tests/test_qsdk_r23d65_godot_jolt_physical_worker.ps1"),
    ("tests/test_qsdk_r23d64_godot_public_profile_physical_route.ps1", "tests/test_qsdk_r23d65_godot_public_profile_physical_route.ps1"),
    ("tests/test_qsdk_r23d64_godot_public_profile_physical_route.py", "tests/test_qsdk_r23d65_godot_public_profile_physical_route.py"),
    ("tests/test_qsdk_r23d64_mujoco_physical_worker.ps1", "tests/test_qsdk_r23d65_mujoco_physical_worker.ps1"),
    ("tests/test_qsdk_r23d64_mujoco_public_profile_physical_route.ps1", "tests/test_qsdk_r23d65_mujoco_public_profile_physical_route.ps1"),
    ("tests/test_qsdk_r23d64_mujoco_public_profile_physical_route.py", "tests/test_qsdk_r23d65_mujoco_public_profile_physical_route.py"),
    ("tests/test_qsdk_r23d64_preregistration.ps1", "tests/test_qsdk_r23d65_preregistration.ps1"),
    ("tests/test_qsdk_r23d64_rapier_physical_worker.ps1", "tests/test_qsdk_r23d65_rapier_physical_worker.ps1"),
    ("tests/test_qsdk_r23d64_rapier_public_profile_physical_route.ps1", "tests/test_qsdk_r23d65_rapier_public_profile_physical_route.ps1"),
    ("tests/test_qsdk_r23d64_rapier_public_profile_physical_route.py", "tests/test_qsdk_r23d65_rapier_public_profile_physical_route.py"),
    ("tests/test_qsdk_r23d64_rapier_launcher_contract.ps1", "tests/test_qsdk_r23d65_rapier_launcher_contract.ps1"),
    ("tests/test_sdk_qsdk_r23d64_authorization_receipt_schema_zero_world.gd", "tests/test_sdk_qsdk_r23d65_authorization_receipt_schema_zero_world.gd"),
    ("tests/test_sdk_qsdk_r23d64_godot_jolt_physical_worker.gd", "tests/test_sdk_qsdk_r23d65_godot_jolt_physical_worker.gd"),
    ("tests/test_sdk_qsdk_r23d64_godot_public_profile_physical_route_zero_world.gd", "tests/test_sdk_qsdk_r23d65_godot_public_profile_physical_route_zero_world.gd"),
    ("sdk/adapters/rapier/src/qsdk_r23d64_public_profile_route.rs", "sdk/adapters/rapier/src/qsdk_r23d65_public_profile_route.rs"),
    ("sdk/adapters/rapier/src/qsdk_r23d64_rapier_worker.rs", "sdk/adapters/rapier/src/qsdk_r23d65_rapier_worker.rs"),
    ("sdk/adapters/rapier/src/bin/qsdk_r23d64_physical.rs", "sdk/adapters/rapier/src/bin/qsdk_r23d65_physical.rs"),
    ("sdk/adapters/rapier/src/bin/qsdk_r23d64_public_profile_route.rs", "sdk/adapters/rapier/src/bin/qsdk_r23d65_public_profile_route.rs"),
    ("sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d64_public_profile_route.py", "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d65_public_profile_route.py"),
    ("sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d64_selected_profile_turning.py", "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d65_selected_profile_turning.py"),
    ("sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d64_selected_profile_turning_test.py", "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d65_selected_profile_turning_test.py"),
)


def transform(value: str) -> str:
    value = value.replace(SOURCE_CAMPAIGN_ID, SUCCESSOR_CAMPAIGN_ID)
    value = value.replace(SOURCE_CAMPAIGN_SPLIT_PREFIX, SUCCESSOR_CAMPAIGN_SPLIT_PREFIX)
    value = value.replace(
        SOURCE_CAMPAIGN_LITERAL_PREFIX,
        SUCCESSOR_CAMPAIGN_LITERAL_PREFIX,
    )
    value = value.replace(SOURCE_STAGE_ID, SUCCESSOR_STAGE_ID)
    value = value.replace("r23d64", "r23d65")
    value = value.replace("R23D64", "R23D65")
    value = value.replace(SOURCE_SEED, SUCCESSOR_SEED)
    value = value.replace(SOURCE_SEED_GROUPED, SUCCESSOR_SEED_GROUPED)
    return value


def raw_sha256(value: bytes) -> str:
    return "sha256:" + hashlib.sha256(value).hexdigest()


def materialize() -> dict[str, object]:
    prepared: list[tuple[str, str, bytes, bytes]] = []
    for source_relative, destination_relative in MAPPINGS:
        source = REPO_ROOT / source_relative
        source_bytes = source.read_bytes()
        source_text = source_bytes.decode("utf-8-sig")
        destination_bytes = transform(source_text).encode("utf-8")
        if (
            b"r23d64" in destination_bytes
            or b"R23D64" in destination_bytes
            or b"QSDK-R23D65-RAPIER-LAUNCH-CONTRACT-REPAIRED" in destination_bytes
        ):
            raise RuntimeError(f"R23D65_UNTRANSFORMED_NAMESPACE:{destination_relative}")
        destination = REPO_ROOT / destination_relative
        if destination.exists() and destination.read_bytes() != destination_bytes:
            raise RuntimeError(f"R23D65_DESTINATION_DIVERGED:{destination_relative}")
        prepared.append(
            (source_relative, destination_relative, source_bytes, destination_bytes)
        )

    receipts: list[dict[str, object]] = []
    for source_relative, destination_relative, source_bytes, destination_bytes in prepared:
        destination = REPO_ROOT / destination_relative
        already_materialized = destination.exists()
        if not already_materialized:
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(destination_bytes)
        receipts.append(
            {
                "source_path": source_relative,
                "source_raw_sha256": raw_sha256(source_bytes),
                "destination_path": destination_relative,
                "materialized_raw_sha256": raw_sha256(destination_bytes),
                "byte_length": len(destination_bytes),
                "already_materialized": already_materialized,
            }
        )
    return {
        "schema_version": "sporespore_qsdk_r23d65_mechanical_successor_materialization_receipt_v1",
        "question_class": "non_physical_source_conformance",
        "source_campaign": "QSDK-R23D64",
        "successor_campaign": "QSDK-R23D65",
        "fresh_unused_seed": int(SUCCESSOR_SEED),
        "mapping_count": len(receipts),
        "mappings": receipts,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def arguments(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = arguments(sys.argv[1:] if argv is None else argv)
    if not args.write:
        print("QSDK_R23D65_MATERIALIZATION_REFUSED --write is required")
        return 2
    try:
        receipt = materialize()
    except (OSError, UnicodeError, RuntimeError) as error:
        print(f"QSDK_R23D65_MATERIALIZATION_FAILURE {type(error).__name__}:{error}")
        return 1
    print(
        "QSDK_R23D65_MATERIALIZATION_PASS "
        + json.dumps(receipt, allow_nan=False, separators=(",", ":"), sort_keys=True)
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
