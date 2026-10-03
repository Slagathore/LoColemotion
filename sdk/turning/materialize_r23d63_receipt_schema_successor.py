#!/usr/bin/env python3
"""Materialize the mechanically inherited R23D63 successor source surface.

This tool performs only the declared namespace, stage, and unused-seed
substitution.  Successor-specific receipt-schema hardening is reviewed and
audited separately.  It refuses to overwrite any destination so an observed
or partially edited successor can never be silently regenerated.
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
    "QSDK-R23D62-SELECTED-PROFILE-MATCHED-THREE-ENGINE-TURNING-VALIDATION"
)
SUCCESSOR_CAMPAIGN_ID = (
    "QSDK-R23D63-RECEIPT-SCHEMA-REPAIRED-SELECTED-PROFILE-MATCHED-"
    "THREE-ENGINE-TURNING-VALIDATION"
)
SOURCE_STAGE_ID = "selected_profile_matched_three_engine_turning_validation"
SUCCESSOR_STAGE_ID = (
    "receipt_schema_repaired_selected_profile_matched_three_engine_"
    "turning_validation"
)
SOURCE_SEED = "23167"
SUCCESSOR_SEED = "23169"
SOURCE_SEED_GROUPED = "23_167"
SUCCESSOR_SEED_GROUPED = "23_169"

MAPPINGS = (
    ("sdk/turning/r23d62_campaign_attestation_manifest_v1.json", "sdk/turning/r23d63_campaign_attestation_manifest_v1.json"),
    ("sdk/turning/r23d62_dependency_closure.py", "sdk/turning/r23d63_dependency_closure.py"),
    ("sdk/turning/r23d62_evaluator_v1_zero_world_rejection_v1.json", "sdk/turning/r23d63_evaluator_v1_zero_world_rejection_v1.json"),
    ("sdk/turning/r23d62_seed_fixture_compiler.gd", "sdk/turning/r23d63_seed_fixture_compiler.gd"),
    ("sdk/turning/r23d62_selected_profile_three_engine_turning_validation.py", "sdk/turning/r23d63_selected_profile_three_engine_turning_validation.py"),
    ("sdk/turning/r23d62_selected_profile_three_engine_turning_validation_evaluator.py", "sdk/turning/r23d63_selected_profile_three_engine_turning_validation_evaluator.py"),
    ("sdk/turning/r23d62_selected_profile_three_engine_turning_validation_evaluator_v2.py", "sdk/turning/r23d63_selected_profile_three_engine_turning_validation_evaluator_v2.py"),
    ("sdk/turning/r23d62_selected_profile_three_engine_turning_validation_implementation_v1.json", "sdk/turning/r23d63_selected_profile_three_engine_turning_validation_implementation_v1.json"),
    ("sdk/turning/r23d62_selected_profile_three_engine_turning_validation_preregistration_v1.json", "sdk/turning/r23d63_selected_profile_three_engine_turning_validation_preregistration_v1.json"),
    ("sdk/run_qsdk_r23d62_supervisor.ps1", "sdk/run_qsdk_r23d63_supervisor.ps1"),
    ("tests/test_qsdk_r23d62_campaign_roles.ps1", "tests/test_qsdk_r23d63_campaign_roles.ps1"),
    ("tests/test_qsdk_r23d62_dependency_closure.ps1", "tests/test_qsdk_r23d63_dependency_closure.ps1"),
    ("tests/test_qsdk_r23d62_evaluator.ps1", "tests/test_qsdk_r23d63_evaluator.ps1"),
    ("tests/test_qsdk_r23d62_evaluator_v2.ps1", "tests/test_qsdk_r23d63_evaluator_v2.ps1"),
    ("tests/test_qsdk_r23d62_godot_jolt_physical_worker.ps1", "tests/test_qsdk_r23d63_godot_jolt_physical_worker.ps1"),
    ("tests/test_qsdk_r23d62_godot_public_profile_physical_route.ps1", "tests/test_qsdk_r23d63_godot_public_profile_physical_route.ps1"),
    ("tests/test_qsdk_r23d62_godot_public_profile_physical_route.py", "tests/test_qsdk_r23d63_godot_public_profile_physical_route.py"),
    ("tests/test_qsdk_r23d62_mujoco_physical_worker.ps1", "tests/test_qsdk_r23d63_mujoco_physical_worker.ps1"),
    ("tests/test_qsdk_r23d62_mujoco_public_profile_physical_route.ps1", "tests/test_qsdk_r23d63_mujoco_public_profile_physical_route.ps1"),
    ("tests/test_qsdk_r23d62_mujoco_public_profile_physical_route.py", "tests/test_qsdk_r23d63_mujoco_public_profile_physical_route.py"),
    ("tests/test_qsdk_r23d62_rapier_physical_worker.ps1", "tests/test_qsdk_r23d63_rapier_physical_worker.ps1"),
    ("tests/test_qsdk_r23d62_rapier_public_profile_physical_route.ps1", "tests/test_qsdk_r23d63_rapier_public_profile_physical_route.ps1"),
    ("tests/test_qsdk_r23d62_rapier_public_profile_physical_route.py", "tests/test_qsdk_r23d63_rapier_public_profile_physical_route.py"),
    ("tests/test_sdk_qsdk_r23d62_godot_jolt_physical_worker.gd", "tests/test_sdk_qsdk_r23d63_godot_jolt_physical_worker.gd"),
    ("tests/test_sdk_qsdk_r23d62_godot_public_profile_physical_route_zero_world.gd", "tests/test_sdk_qsdk_r23d63_godot_public_profile_physical_route_zero_world.gd"),
    ("sdk/adapters/rapier/src/qsdk_r23d62_public_profile_route.rs", "sdk/adapters/rapier/src/qsdk_r23d63_public_profile_route.rs"),
    ("sdk/adapters/rapier/src/qsdk_r23d62_rapier_worker.rs", "sdk/adapters/rapier/src/qsdk_r23d63_rapier_worker.rs"),
    ("sdk/adapters/rapier/src/bin/qsdk_r23d62_physical.rs", "sdk/adapters/rapier/src/bin/qsdk_r23d63_physical.rs"),
    ("sdk/adapters/rapier/src/bin/qsdk_r23d62_public_profile_route.rs", "sdk/adapters/rapier/src/bin/qsdk_r23d63_public_profile_route.rs"),
    ("sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d62_public_profile_route.py", "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d63_public_profile_route.py"),
    ("sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d62_selected_profile_turning.py", "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d63_selected_profile_turning.py"),
    ("sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d62_selected_profile_turning_test.py", "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d63_selected_profile_turning_test.py"),
)


def transform(value: str) -> str:
    value = value.replace(SOURCE_CAMPAIGN_ID, SUCCESSOR_CAMPAIGN_ID)
    value = value.replace(SOURCE_STAGE_ID, SUCCESSOR_STAGE_ID)
    value = value.replace("r23d62", "r23d63")
    value = value.replace("R23D62", "R23D63")
    value = value.replace(SOURCE_SEED, SUCCESSOR_SEED)
    value = value.replace(SOURCE_SEED_GROUPED, SUCCESSOR_SEED_GROUPED)
    return value


def raw_sha256(value: bytes) -> str:
    return "sha256:" + hashlib.sha256(value).hexdigest()


def materialize() -> dict[str, object]:
    destinations = [REPO_ROOT / destination for _, destination in MAPPINGS]
    existing = [path.relative_to(REPO_ROOT).as_posix() for path in destinations if path.exists()]
    if existing:
        raise RuntimeError("R23D63_DESTINATION_ALREADY_EXISTS:" + "|".join(existing))

    receipts: list[dict[str, object]] = []
    for source_relative, destination_relative in MAPPINGS:
        source = REPO_ROOT / source_relative
        destination = REPO_ROOT / destination_relative
        source_bytes = source.read_bytes()
        source_text = source_bytes.decode("utf-8-sig")
        destination_bytes = transform(source_text).encode("utf-8")
        if b"r23d62" in destination_bytes or b"R23D62" in destination_bytes:
            raise RuntimeError(f"R23D63_UNTRANSFORMED_NAMESPACE:{destination_relative}")
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(destination_bytes)
        receipts.append(
            {
                "source_path": source_relative,
                "source_raw_sha256": raw_sha256(source_bytes),
                "destination_path": destination_relative,
                "materialized_raw_sha256": raw_sha256(destination_bytes),
                "byte_length": len(destination_bytes),
            }
        )
    return {
        "schema_version": "sporespore_qsdk_r23d63_mechanical_successor_materialization_receipt_v1",
        "question_class": "non_physical_source_conformance",
        "source_campaign": "QSDK-R23D62",
        "successor_campaign": "QSDK-R23D63",
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
        print("QSDK_R23D63_MATERIALIZATION_REFUSED --write is required")
        return 2
    try:
        receipt = materialize()
    except (OSError, UnicodeError, RuntimeError) as error:
        print(f"QSDK_R23D63_MATERIALIZATION_FAILURE {type(error).__name__}:{error}")
        return 1
    print(
        "QSDK_R23D63_MATERIALIZATION_PASS "
        + json.dumps(receipt, allow_nan=False, separators=(",", ":"), sort_keys=True)
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
