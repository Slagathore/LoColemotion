#!/usr/bin/env python3
"""Cross-language zero-world audit of the R23D63 Godot public-cap route."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
from typing import Any, Sequence


REPO_ROOT = Path(__file__).resolve().parent.parent
TURNING_ROOT = REPO_ROOT / "sdk" / "turning"
EXPECTED_ROOT = Path(r"C:\Users\Cole\CodeStuff\games\SporeSpore")
EXPECTED_REMOTE = "https://github.com/Slagathore/sporespore.git"
MARKER = "QSDK_R23D63_GODOT_PUBLIC_PROFILE_PHYSICAL_ROUTE_ZERO_WORLD "
GDSCRIPT_PATH = (
    "res://tests/"
    "test_sdk_qsdk_r23d63_godot_public_profile_physical_route_zero_world.gd"
)
RELEASE_CONTRACT_PATH = (
    REPO_ROOT / "sdk" / "release" / "quadruped_release_contract.json"
)
SUPPORT_MATRIX_PATH = REPO_ROOT / "sdk" / "release" / "quadruped_support_matrix.json"
ROUTE_SOURCE_PATH = (
    REPO_ROOT
    / "scripts"
    / "lab"
    / "gait"
    / "sdk_godot_jolt_public_actuator_cap_profile_binding.gd"
)
PHYSICAL_RUNNER_PATH = (
    REPO_ROOT / "scripts" / "lab" / "gait" / "physical_wave_gait_quadruped.gd"
)
RUNTIME_TEST_PATH = REPO_ROOT / GDSCRIPT_PATH.removeprefix("res://")
PYTHON_AUDIT_PATH = Path(__file__).resolve()
SERIALIZED_GATE_PATH = (
    REPO_ROOT / "tests" / "test_qsdk_r23d63_godot_public_profile_physical_route.ps1"
)
IMPLEMENTATION_PATH = (
    TURNING_ROOT
    / "r23d63_selected_profile_three_engine_turning_validation_implementation_v1.json"
)
WORKER_SOURCE_PATH = (
    REPO_ROOT / "tests" / "test_sdk_qsdk_r23d63_godot_jolt_physical_worker.gd"
)
WORKER_GATE_PATH = (
    REPO_ROOT / "tests" / "test_qsdk_r23d63_godot_jolt_physical_worker.ps1"
)
TERMINATION_HELPER_PATH = REPO_ROOT / "sdk" / "godot_receipt_terminated_process.ps1"

sys.path.insert(0, str(TURNING_ROOT))
import r23d63_selected_profile_three_engine_turning_validation as design  # noqa: E402
import r23d63_selected_profile_three_engine_turning_validation_evaluator_v2 as evaluator  # noqa: E402


class AuditError(RuntimeError):
    """The production route or cross-language evaluator projection is invalid."""


def require(condition: bool, code: str) -> None:
    if not condition:
        raise AuditError(code)


def git(*arguments: str) -> str:
    return subprocess.run(
        ["git", *arguments],
        cwd=REPO_ROOT,
        check=True,
        capture_output=True,
        text=True,
        timeout=30,
    ).stdout.strip()


def raw_sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def find_campaign_records(value: Any) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    if isinstance(value, dict):
        if (
            value.get("gate_id") == design.GATE_ID
            and value.get("campaign_id") == design.CAMPAIGN_ID
        ):
            records.append(value)
        for child in value.values():
            records.extend(find_campaign_records(child))
    elif isinstance(value, list):
        for child in value:
            records.extend(find_campaign_records(child))
    return records


def audit_authority_records() -> None:
    contract = json.loads(RELEASE_CONTRACT_PATH.read_text(encoding="utf-8"))
    matrix = json.loads(SUPPORT_MATRIX_PATH.read_text(encoding="utf-8"))
    contract_records = find_campaign_records(contract)
    matrix_records = find_campaign_records(matrix)
    require(
        len(contract_records) == 1, "R23D63_GODOT_ROUTE_CONTRACT_CARDINALITY_INVALID"
    )
    require(len(matrix_records) == 1, "R23D63_GODOT_ROUTE_MATRIX_CARDINALITY_INVALID")
    expected_status = (
        "prospective_campaign_machinery_implemented_receipt_schema_gate_passed_"
        "complete_zero_world_gate_passed_physical_not_opened"
    )
    path_fields = (
        (
            "godot_public_profile_route_source_path",
            "godot_public_profile_route_source",
            ROUTE_SOURCE_PATH,
        ),
        (
            "godot_production_physical_runner_path",
            "godot_production_physical_runner",
            PHYSICAL_RUNNER_PATH,
        ),
        (
            "godot_zero_world_runtime_test_path",
            "godot_zero_world_runtime_test",
            RUNTIME_TEST_PATH,
        ),
        (
            "godot_cross_language_route_audit_path",
            "godot_cross_language_route_audit",
            PYTHON_AUDIT_PATH,
        ),
        (
            "godot_serialized_route_gate_path",
            "godot_serialized_route_gate",
            SERIALIZED_GATE_PATH,
        ),
        ("implementation_path", "implementation", IMPLEMENTATION_PATH),
        ("godot_worker_source_path", "godot_worker_source", WORKER_SOURCE_PATH),
        (
            "godot_worker_zero_world_gate_path",
            "godot_worker_zero_world_gate",
            WORKER_GATE_PATH,
        ),
        (
            "godot_supervised_termination_helper_path",
            "godot_supervised_termination_helper",
            TERMINATION_HELPER_PATH,
        ),
    )
    for record, hash_suffix in (
        (contract_records[0], "_raw_sha256"),
        (matrix_records[0], "_sha256"),
    ):
        require(
            record.get("status") == expected_status, "R23D63_GODOT_ROUTE_STATUS_INVALID"
        )
        for path_field, hash_stem, path in path_fields:
            require(
                record.get(path_field) == path.relative_to(REPO_ROOT).as_posix(),
                "R23D63_GODOT_ROUTE_AUTHORITY_PATH_INVALID:" + path_field,
            )
            require(
                record.get(hash_stem + hash_suffix) == raw_sha256(path),
                "R23D63_GODOT_ROUTE_AUTHORITY_HASH_INVALID:" + hash_stem,
            )
        require(
            record.get("godot_public_profile_dependency_route_zero_world_passed")
            is True
            and record.get("godot_route_validated_actuator_count")
            == design.ACTUATOR_COUNT
            and record.get("godot_route_write_count") == design.ACTUATOR_COUNT
            and record.get("godot_route_readback_count") == design.ACTUATOR_COUNT
            and record.get("godot_route_authority_application_count")
            == design.ACTUATOR_COUNT
            and record.get("godot_route_normalization_mutation_rejection_count") == 2
            and record.get("godot_route_mutation_rejection_count") == 5
            and record.get("implemented_native_dependency_route_count") == 3
            and record.get("implemented_native_worker_count") == 3
            and record.get("godot_worker_zero_world_gate_passed") is True
            and record.get("godot_worker_preflight_cell_count") == 3
            and record.get("godot_worker_negative_control_rejection_count") == 11
            and record.get("godot_worker_model_construction_count") == 0
            and record.get("godot_worker_world_attempt_count") == 0
            and record.get("godot_worker_world_build_count") == 0
            and record.get("godot_worker_supervised_termination_protocol_id")
            == "godot_4_7_gdscript_shutdown_containment_v1",
            "R23D63_GODOT_ROUTE_AUTHORITY_COUNTS_INVALID",
        )
        require(
            record.get("implementation_complete") is True
            and record.get("complete_campaign_zero_world_gate_passed") is True
            and record.get("physical_campaign_opened") is False
            and record.get("world_attempt_count") == 0
            and record.get("world_build_count") == 0
            and record.get("finite_three_engine_turning") is False
            and record.get("portable_basic_turning") is False
            and record.get("q_sdk_r23_satisfied") is False
            and record.get("cross_engine_equivalence") is False
            and record.get("physical_acceptance_authority") is False
            and record.get("release_authorized") is False,
            "R23D63_GODOT_ROUTE_AUTHORITY_NONCLAIMS_INVALID",
        )


def parse_marker(stdout: str) -> dict[str, Any]:
    matches = [
        line[len(MARKER) :] for line in stdout.splitlines() if line.startswith(MARKER)
    ]
    require(len(matches) == 1, "R23D63_GODOT_ROUTE_TERMINAL_CARDINALITY_INVALID")
    value = json.loads(matches[0])
    require(isinstance(value, dict), "R23D63_GODOT_ROUTE_TERMINAL_TYPE_INVALID")
    return value


def audit(godot: Path) -> dict[str, Any]:
    require(REPO_ROOT == EXPECTED_ROOT, "R23D63_GODOT_ROUTE_REPOSITORY_ROOT_INVALID")
    require(
        Path(git("rev-parse", "--show-toplevel")) == EXPECTED_ROOT,
        "R23D63_GODOT_ROUTE_GIT_ROOT_INVALID",
    )
    require(
        git("remote", "get-url", "origin") == EXPECTED_REMOTE,
        "R23D63_GODOT_ROUTE_REMOTE_INVALID",
    )
    audit_authority_records()
    require(godot.is_file(), "R23D63_GODOT_ROUTE_RUNTIME_MISSING")
    process = subprocess.run(
        [
            str(godot),
            "--headless",
            "--path",
            str(REPO_ROOT),
            "--script",
            GDSCRIPT_PATH,
        ],
        cwd=REPO_ROOT,
        check=False,
        capture_output=True,
        text=True,
        timeout=300,
    )
    require(
        process.returncode == 0,
        "R23D63_GODOT_ROUTE_PROCESS_FAILED:"
        + process.stderr[-2000:]
        + process.stdout[-2000:],
    )
    receipt = parse_marker(process.stdout)
    require(receipt.get("ok") is True, "R23D63_GODOT_ROUTE_RECEIPT_FAILED")
    require(
        receipt.get("schema_version")
        == "sporespore_qsdk_r23d63_godot_public_profile_physical_route_zero_world_v1",
        "R23D63_GODOT_ROUTE_SCHEMA_INVALID",
    )
    require(
        receipt.get("profile_id") == design.PROFILE_ID
        and receipt.get("profile_sha256") == design.PROFILE_SHA256,
        "R23D63_GODOT_ROUTE_PROFILE_INVALID",
    )
    require(
        receipt.get("validated_actuator_count") == design.ACTUATOR_COUNT
        and receipt.get("write_count") == design.ACTUATOR_COUNT
        and receipt.get("readback_count") == design.ACTUATOR_COUNT
        and receipt.get("authority_application_count") == design.ACTUATOR_COUNT,
        "R23D63_GODOT_ROUTE_APPLICATION_COUNT_INVALID",
    )
    require(
        receipt.get("normalization_mutation_rejection_count") == 2
        and receipt.get("route_mutation_rejection_count") == 5,
        "R23D63_GODOT_ROUTE_MUTATION_COUNT_INVALID",
    )
    require(
        receipt.get("scene_tree_insertion_count") == 0
        and receipt.get("model_construction_count") == 0
        and receipt.get("world_attempt_count") == 0
        and receipt.get("world_build_count") == 0
        and receipt.get("solver_step_count") == 0
        and receipt.get("physics_state_modified") is False
        and receipt.get("physical_campaign_opened") is False
        and receipt.get("physical_acceptance_authority") is False
        and receipt.get("release_authority") is False,
        "R23D63_GODOT_ROUTE_ZERO_WORLD_BOUNDARY_INVALID",
    )

    evaluator._install_corrected_identity_projection()
    legacy = evaluator.legacy
    item = design.cell("godot_jolt", "reference_zero")
    resolution = receipt.get("actuator_cap_profile_resolution_receipt")
    host_mapping = receipt.get("actuator_cap_profile_host_mapping_receipt")
    physical_binding = receipt.get("actuator_cap_profile_physical_binding_receipt")
    failures = legacy._resolution_failures(resolution)
    failures.extend(legacy._host_mapping_failures(host_mapping, item))
    failures.extend(
        legacy._physical_binding_failures(physical_binding, item, host_mapping)
    )
    require(not failures, "R23D63_GODOT_ROUTE_EVALUATOR_REJECTED:" + "|".join(failures))

    return {
        "schema_version": "sporespore_qsdk_r23d63_godot_public_profile_route_audit_v1",
        "campaign_id": design.CAMPAIGN_ID,
        "gate_id": design.GATE_ID,
        "engine_id": "godot_jolt",
        "profile_id": design.PROFILE_ID,
        "validated_actuator_count": design.ACTUATOR_COUNT,
        "write_count": receipt["write_count"],
        "readback_count": receipt["readback_count"],
        "authority_application_count": receipt["authority_application_count"],
        "normalization_mutation_rejection_count": receipt[
            "normalization_mutation_rejection_count"
        ],
        "route_mutation_rejection_count": receipt["route_mutation_rejection_count"],
        "evaluator_projection_failure_count": len(failures),
        "authority_record_count": 2,
        "content_addressed_route_source_count": 5,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def arguments(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--godot",
        type=Path,
        default=Path(
            os.environ.get(
                "SPORESPORE_GODOT",
                r"C:\Users\Cole\CodeStuff\Misc\Godot\Godot_v4.7-stable_mono_win64_console.exe",
            )
        ),
    )
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    parsed = arguments(sys.argv[1:] if argv is None else argv)
    try:
        value = audit(parsed.godot.resolve())
    except (
        AuditError,
        OSError,
        subprocess.SubprocessError,
        json.JSONDecodeError,
        KeyError,
        TypeError,
        ValueError,
    ) as error:
        print(
            f"QSDK_R23D63_GODOT_PUBLIC_PROFILE_ROUTE_FAILURE "
            f"{type(error).__name__}:{error}",
            file=sys.stderr,
        )
        return 1
    print(
        "QSDK_R23D63_GODOT_PUBLIC_PROFILE_ROUTE_PASS "
        + json.dumps(value, allow_nan=False, separators=(",", ":"), sort_keys=True)
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
