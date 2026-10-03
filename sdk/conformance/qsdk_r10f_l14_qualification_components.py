"""Execute and strictly consume L14's additional source-only qualification.

This is not an official qualification entry point. The existing serialized
wrapper owns that identity. This module runs real component tests, including
the GDScript -> PowerShell -> Python negative path, without opening physics.
"""

from __future__ import annotations

import copy
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from typing import Any, Mapping

import qsdk_r10f_l14_authority_contract as authority

ROOT = Path(__file__).resolve().parents[2]
SCHEMA = "sporespore_qsdk_r10f_l14_complete_component_qualification_v1"
ZERO_COUNTERS = (
    "model_construction_count",
    "world_attempt_count",
    "world_build_count",
    "scene_tree_insertion_count",
    "native_readback_count",
    "solver_step_count",
)
DENIED_FLAGS = (
    "physics_state_modified",
    "physical_execution_authorized",
    "physical_acceptance_authority",
    "release_authority",
)
TESTS = (
    ("test_qsdk_r10f_l14_terminal_consumers.py", 10),
    ("test_qsdk_r10f_l14_production_terminal_paths.py", 6),
    ("test_qsdk_r10f_l14_no_resume_terminal.py", 18),
    ("test_qsdk_r10f_l14_authority_contract.py", 9),
    ("test_qsdk_r10f_l14_no_resume_diagnosis.py", 1),
    ("test_qsdk_r10f_l14_runtime_binding.py", 11),
)
COVERAGE = {
    "base_design_positive_count": 1,
    "base_design_corruption_count": 18,
    "addendum_design_positive_count": 1,
    "addendum_design_corruption_count": 23,
    "shared_authority_positive_count": 4,
    "shared_authority_corruption_count": 31,
    "walking_v2_control_count": 32,
    "walking_v2_malformed_input_count": 20,
    "walking_v2_retained_segment_count": 2,
    "terminal_consumer_test_count": 10,
    "worker_retention_test_count": 6,
    "worker_source_control_count": 14,
    "no_resume_test_count": 18,
    "authority_binding_test_count": 9,
    "frozen_no_resume_diagnosis_test_count": 1,
    "runtime_binding_test_count": 11,
    "selected_runtime_image_count": 5,
    "actual_runtime_guards_before_identity_and_each_child": True,
    "python_test_count": 55,
    "pre_resume_terminal_cause_count": 7,
    "actual_powershell_source_binding_positive_count": 3,
    "actual_powershell_frozen_binding_corruption_count": 83,
    "actual_powershell_binding_receipt_corruption_count": 48,
    "actual_powershell_complete_pair_source_consumed": True,
    "actual_independent_report_and_v15_closure_builder_consumed": True,
    "missing_resume_alone_never_qualifies_a_negative": True,
    "failed_health_or_missing_peer_never_qualifies_a_route": True,
    "complete_resumed_route_four_handoffs_preserved": True,
    "complete_proven_no_resume_negative_handoff_count": 3,
    "future_authority_graph_is_in_memory_test_fixture_only": True,
    "retained_physical_result_reclassified": False,
    "sdk1_m07_satisfied": False,
}


def require(condition: bool, code: str) -> None:
    if not condition:
        raise ValueError(code)


def exact(value: Any, expected: Any) -> bool:
    return authority.design_audit.exact(value, expected)


def require_zero_world(value: Mapping[str, Any], label: str) -> None:
    require(value.get("ok") is True, label + ":NOT_OK")
    for name in ZERO_COUNTERS:
        require(exact(value.get(name), 0), label + ":" + name)
    for name in DENIED_FLAGS:
        require(value.get(name) is False, label + ":" + name)


def expected_receipt() -> dict[str, Any]:
    """The exact compact consumer contract, not evidence that tests have run."""
    return {
        "schema_version": SCHEMA,
        "gate_id": "QSDK-R10F",
        "repair_id": authority.REPAIR_ID,
        "ledger_scope": {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "zero_world_production_component_qualification",
            "question_class": "development",
        },
        "ok": True,
        "base_design_raw_sha256": authority.design_audit.DESIGN_SHA256,
        "branch_completeness_addendum_sha256": authority.addendum_audit.SHA256,
        "coverage": copy.deepcopy(COVERAGE),
        "test_suites": [
            {"path": "tests/" + path, "test_count": count, "passed": True}
            for path, count in TESTS
        ],
        **dict.fromkeys(ZERO_COUNTERS, 0),
        **dict.fromkeys(DENIED_FLAGS, False),
    }


def validate_receipt(value: Any) -> None:
    # Recursive exactness rejects missing/extra fields and float/bool counters.
    require(exact(value, expected_receipt()), "L14_COMPONENT_RECEIPT_NOT_EXACT")


def receipt_corruptions() -> list[dict[str, Any]]:
    """Offered malformed records for both real Python and PowerShell consumers."""
    valid = expected_receipt()
    paths: list[tuple[str | int, ...]] = []

    def visit(value: Any, prefix: tuple[str | int, ...] = ()) -> None:
        if isinstance(value, dict):
            for key, child in value.items():
                paths.append((*prefix, key))
                visit(child, (*prefix, key))
        elif isinstance(value, list):
            for index, child in enumerate(value):
                paths.append((*prefix, index))
                visit(child, (*prefix, index))

    visit(valid)
    cases = []
    for path in paths:
        changed = copy.deepcopy(valid)
        owner = changed
        for key in path[:-1]:
            owner = owner[key]
        del owner[path[-1]]
        cases.append({"id": "missing:" + str(path), "receipt": changed})
    for key, original in valid["coverage"].items():
        for replacement in (float(original), str(original), None):
            changed = copy.deepcopy(valid)
            changed["coverage"][key] = replacement
            cases.append(
                {
                    "id": "kind:" + key + ":" + type(replacement).__name__,
                    "receipt": changed,
                }
            )
    changed = copy.deepcopy(valid)
    changed["invented_authority"] = True
    cases.append({"id": "extra_authority", "receipt": changed})
    return cases


def receipt_contract_self_test() -> dict[str, int | bool]:
    validate_receipt(expected_receipt())
    cases = receipt_corruptions()
    for case in cases:
        try:
            validate_receipt(case["receipt"])
        except ValueError:
            pass
        else:
            raise ValueError("L14_COMPONENT_CORRUPTION_ACCEPTED:" + case["id"])
    return {
        "ok": True,
        "positive_control_count": 1,
        "mutation_rejection_count": len(cases),
    }


def run(arguments: list[str], label: str, *, environment=None, timeout=300):
    # Match the strict UTF-8 reader, including non-ASCII failure diagnostics on Windows.
    child_environment = dict(os.environ if environment is None else environment)
    child_environment["PYTHONIOENCODING"] = "utf-8"
    result = subprocess.run(
        arguments,
        cwd=ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        timeout=timeout,
        env=child_environment,
    )
    require(
        result.returncode == 0,
        label + ":PROCESS:" + (result.stdout + result.stderr)[-5000:],
    )
    return result


def audit(godot: Path) -> dict[str, Any]:
    authority.verify_repository()
    base = authority.design_audit.audit()
    require_zero_world(base, "L14_BASE_DESIGN")
    require(
        exact(base.get("valid_design_control_count"), 1)
        and exact(base.get("mutation_rejection_count"), 18),
        "L14_BASE_COUNTS",
    )
    addendum = authority.addendum_audit.audit()
    require_zero_world(addendum, "L14_ADDENDUM_DESIGN")
    require(
        exact(addendum.get("positive_design_control_count"), 1)
        and exact(addendum.get("mutation_rejection_count"), 23),
        "L14_ADDENDUM_COUNTS",
    )
    shared = authority.self_test()
    require(
        shared.get("ok") is True
        and exact(shared.get("positive_control_count"), 4)
        and exact(shared.get("mutation_rejection_count"), 31),
        "L14_SHARED_COUNTS",
    )
    marker = "QSDK_R10F_L14_WALKING_TERMINAL_ZERO_WORLD "
    walking = run(
        [
            str(godot),
            "--headless",
            "--path",
            str(ROOT),
            "--script",
            "res://tests/test_sdk_qsdk_r10f_l14_walking_terminal_zero_world.gd",
        ],
        "L14_WALKING_V2",
    )
    require(
        "ERROR:" not in walking.stdout + walking.stderr, "L14_WALKING_ENGINE_HEALTH"
    )
    records = [
        line[len(marker) :]
        for line in walking.stdout.splitlines()
        if line.startswith(marker)
    ]
    require(len(records) == 1, "L14_WALKING_MARKER_COUNT")
    receipt = json.loads(records[0])
    require_zero_world(receipt, "L14_WALKING_V2")
    controls = receipt.get("controls")
    retained = receipt.get("retained_replay", {})
    require(
        exact(receipt.get("control_count"), 32)
        and exact(receipt.get("mutation_rejection_count"), 20)
        and isinstance(controls, dict)
        and len(controls) == 32
        and all(value is True for value in controls.values())
        and receipt.get("failed_controls") == []
        and retained.get("ok") is True
        and len(retained.get("segments", [])) == 2
        and all(segment.get("ok") is True for segment in retained["segments"])
        and retained.get("retained_result_reclassified") is False
        and retained.get("retained_bytes_modified") is False,
        "L14_WALKING_COMPLETE_SOURCE_CONTROLS",
    )
    environment = dict(os.environ)
    environment["SPORESPORE_L14_GODOT_EXECUTABLE"] = str(godot)
    for path, count in TESTS:
        result = run(
            [
                sys.executable,
                "-B",
                "-m",
                "unittest",
                "discover",
                "-s",
                "tests",
                "-p",
                path,
                "-v",
            ],
            "L14_TEST:" + path,
            environment=environment,
        )
        require(
            re.search(r"Ran " + str(count) + r" tests? in [0-9.]+s", result.stderr)
            is not None
            and result.stderr.rstrip().endswith("OK"),
            "L14_TEST_COUNT_OR_SKIP:" + path,
        )
        print("L14_COMPONENT_SUITE_PASS " + path + " tests=" + str(count), flush=True)
    result = expected_receipt()
    validate_receipt(result)
    receipt_contract_self_test()
    return result
