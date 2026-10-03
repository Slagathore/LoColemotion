"""Run the existing L15 component suites serially and retain their real output.

This is not the complete implementation audit or an official qualification.
Only this driver and the selected test files are bound here; the full recursive
dependency graph, legacy rollup and qualification-origin handoff remain separate.
"""

from __future__ import annotations

import hashlib
import importlib.util
import math
import os
from pathlib import Path
import re
import subprocess
import sys

import qsdk_r10f_l14_authority_contract as authority
import qsdk_r10f_l14_runtime_binding as runtime
import qsdk_r10f_l15_collection_retention as packet
import qsdk_r10f_l15_launch_ownership_publication_successor_design as design

ROOT = Path(__file__).resolve().parents[2]
DRIVER = "sdk/conformance/qsdk_r10f_l15_component_rollup.py"
READER_CONTROLS = "tests/test_qsdk_r10f_l15_component_rollup.py"
# V1-V6 remain preceding component results. V7 adds original worker syntax-check
# output retention and full-reader controls to the actual complete gate suite.
SCHEMA = "sporespore_qsdk_r10f_l15_additional_component_rollup_v7"
SUITES = (
    ("test_qsdk_r10f_l15_frozen_source_replay.py", 5),
    ("test_qsdk_r10f_l15_source_binding.py", 13),
    ("test_qsdk_r10f_l15_root_design_projection.py", 5),
    ("test_qsdk_r10f_l15_dependency_closure.py", 15),
    ("test_qsdk_r10f_l15_launch_relationship.py", 7),
    ("test_qsdk_r10f_l15_launch_consumers.py", 4),
    ("test_qsdk_r10f_l15_canonical_ownership.py", 2),
    ("test_qsdk_r10f_l15_worker_ownership.py", 2),
    ("test_qsdk_r10f_l15_publication.py", 8),
    ("test_qsdk_r10f_l15_collection_transport.py", 3),
    ("test_qsdk_r10f_l15_collection_retention.py", 8),
    ("test_qsdk_r10f_l15_route_retention.py", 2),
    ("test_qsdk_r10f_l15_worker_retention.py", 4),
    ("test_qsdk_r10f_l15_collection_context.py", 2),
    ("test_qsdk_r10f_l15_collection_context_reader.py", 5),
    ("test_qsdk_r10f_l15_pre_world_context.py", 5),
    ("test_qsdk_r10f_l15_normal_finalization.py", 6),
    ("test_qsdk_r10f_l15_collection_enclosing_retention.py", 7),
    ("test_qsdk_r10f_l15_whole_pair.py", 6),
    ("test_qsdk_r10f_l15_context_consumers.py", 11),
    ("test_qsdk_r10f_l15_context_environment.py", 5),
    ("test_qsdk_r10f_l15_gate_context.py", 12),
)
SOURCE_PATHS = (DRIVER, READER_CONTROLS, *("tests/" + name for name, _ in SUITES))
ZERO_COUNTERS = (
    "model_construction_count",
    "world_attempt_count",
    "world_build_count",
    "scene_tree_insertion_count",
    "native_physics_read_count",
    "solver_step_count",
)
DENIED_FLAGS = (
    "physics_state_modified",
    "physical_question_opened",
    "physical_execution_authorized",
    "physical_acceptance_authority",
    "release_authority",
    "official_qualification_identity_created",
    "official_expected_context_origin_authenticated",
    "complete_recursive_dependency_graph_qualified",
    "complete_implementation_audit_passed",
    "legacy_component_rollup_executed_here",
    "sdk1_m07_satisfied",
)


def require(condition, code):
    if not condition:
        raise ValueError("L15_COMPONENT_ROLLUP_" + code)


def static_header():
    """Reader contract only. It cannot substitute for the actual nested output."""
    return {
        "schema_version": SCHEMA,
        "gate_id": "QSDK-R10F",
        "repair_id": "QSDK-R10F-L15",
        "ledger_scope": {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "development_zero_world_additional_component_rollup",
            "question_class": "development",
        },
        "ok": True,
        "suite_count": 22,
        "python_test_count": 137,
        "receipt_reader_contract_test_count": 7,
        "serialized_execution": True,
        "source_binding_scope": "rollup_driver_component_suites_and_reader_controls_only",
        "source_binding_count": 24,
        **dict.fromkeys(ZERO_COUNTERS, 0),
        **dict.fromkeys(DENIED_FLAGS, False),
    }


def snapshot(raw):
    # Preserve original process bytes, including CRLF. Decode only after join.
    text = raw.decode("utf-8", errors="strict")
    return {
        "utf8_text": text,
        "utf8_byte_length": len(raw),
        "raw_sha256": "sha256:" + hashlib.sha256(raw).hexdigest(),
    }


def source_bindings():
    result = []
    for relative in SOURCE_PATHS:
        path = ROOT / relative
        require(path.resolve().is_relative_to(ROOT.resolve()), "SOURCE_PATH")
        raw = path.read_bytes()
        result.append(
            {
                "path": relative,
                "byte_length": len(raw),
                "raw_sha256": "sha256:" + hashlib.sha256(raw).hexdigest(),
            }
        )
    return result


def validate_source_bindings(value):
    require(
        type(value) is list and len(value) == len(SOURCE_PATHS), "SOURCE_POPULATION"
    )
    for record, relative in zip(value, SOURCE_PATHS):
        packet.exact_keys(
            record, {"path", "byte_length", "raw_sha256"}, "ROLLUP_SOURCE"
        )
        require(record["path"] == relative, "SOURCE_ORDER")
        require(
            type(record["byte_length"]) is int and record["byte_length"] > 0,
            "SOURCE_LENGTH",
        )
        require(
            type(record["raw_sha256"]) is str
            and re.fullmatch(r"sha256:[0-9a-f]{64}", record["raw_sha256"]) is not None,
            "SOURCE_DIGEST",
        )


def validate_design_receipt(value):
    expected = {
        "schema_version": "sporespore_qsdk_r10f_l15_successor_design_audit_v1",
        "gate_id": "QSDK-R10F",
        "repair_id": "QSDK-R10F-L15",
        "ledger_scope": {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "zero_world_prospective_design_audit",
            "question_class": "development",
        },
        "ok": True,
        "design_byte_length": 20711,
        "design_raw_sha256": design.DESIGN_SHA,
        "valid_design_control_count": 1,
        "design_mutation_rejection_count": 134,
        "retained_diagnosis_control_count": 39,
        "bound_authority_count": 9,
        "additional_frozen_retention_source_count": 3,
        "required_future_zero_world_coverage_group_count": 11,
        "implementation_authorized": True,
        "implementation_qualified": False,
        "production_successor_paths_executed": False,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
        "publication_authority": False,
        "old_result_reclassified": False,
        "same_identity_rerun_permitted": False,
        "sdk1_m07_satisfied": False,
        "sdk1_score": "14/20",
        "full_program_score": "14/25",
        **dict.fromkeys(ZERO_COUNTERS, 0),
    }
    packet.exact_keys(value, set(expected) | {"elapsed_seconds"}, "ROLLUP_DESIGN")
    require(
        packet.same({key: value[key] for key in expected}, expected), "DESIGN_RECEIPT"
    )
    elapsed = value["elapsed_seconds"]
    require(
        type(elapsed) in (int, float) and math.isfinite(elapsed) and elapsed >= 0,
        "DESIGN_ELAPSED",
    )


def validate_suite(record, filename, count):
    packet.exact_keys(
        record, {"path", "test_count", "exit_code", "stdout", "stderr"}, "ROLLUP_SUITE"
    )
    require(record["path"] == "tests/" + filename, "SUITE_PATH")
    require(
        type(record["test_count"]) is int and record["test_count"] == count,
        "SUITE_COUNT",
    )
    require(type(record["exit_code"]) is int and record["exit_code"] == 0, "SUITE_EXIT")
    packet.verify_bytes(record["stdout"], "ROLLUP_STDOUT")
    stderr = packet.verify_bytes(record["stderr"], "ROLLUP_STDERR").decode("utf-8")
    summaries = re.findall(
        r"^Ran (\d+) tests? in ([0-9]+(?:\.[0-9]+)?)s\r?$", stderr, re.MULTILINE
    )
    require(
        len(summaries) == 1 and summaries[0][0] == str(count), "SUITE_SUMMARY_COUNT"
    )
    # A skipped or expected-failure suite may exit zero, but is not qualification.
    require(re.search(r"\nOK\r?\n?\Z", stderr) is not None, "SUITE_NOT_UNQUALIFIED_OK")
    require(
        len(re.findall(r" \.\.\. ok\r?$", stderr, re.MULTILINE)) == count,
        "SUITE_COMPLETE_OK_ROWS",
    )


def validate_receipt(value, *, expected_source_bindings):
    header = static_header()
    packet.exact_keys(
        value,
        set(header)
        | {"source_bindings", "design_audit", "runtime_binding", "test_suites"},
        "ROLLUP",
    )
    require(packet.same({key: value[key] for key in header}, header), "HEADER")
    validate_source_bindings(expected_source_bindings)
    require(
        packet.same(value["source_bindings"], expected_source_bindings),
        "ENCLOSING_SOURCE_BINDINGS",
    )
    validate_design_receipt(value["design_audit"])
    runtime.validate_binding(value["runtime_binding"])
    suites = value["test_suites"]
    require(type(suites) is list and len(suites) == len(SUITES), "SUITE_POPULATION")
    for record, (filename, count) in zip(suites, SUITES):
        validate_suite(record, filename, count)


def execute_suite(filename, count):
    require(
        type(filename) is str and type(count) is int and (filename, count) in SUITES,
        "UNDECLARED_SUITE",
    )
    run = subprocess.run(
        [
            sys.executable,
            "-B",
            "-m",
            "unittest",
            "discover",
            "-s",
            "tests",
            "-p",
            filename,
            "-v",
        ],
        cwd=ROOT,
        capture_output=True,
        timeout=420,
        creationflags=subprocess.CREATE_NO_WINDOW,
        env={**os.environ, "PYTHONIOENCODING": "utf-8"},
    )
    record = {
        "path": "tests/" + filename,
        "test_count": count,
        "exit_code": run.returncode,
        "stdout": snapshot(run.stdout),
        "stderr": snapshot(run.stderr),
    }
    try:
        validate_suite(record, filename, count)
    except ValueError as exc:
        raise ValueError(
            str(exc) + ":" + filename + ":" + record["stderr"]["utf8_text"][-6000:]
        ) from exc
    return record


def audit(godot):
    authority.verify_repository()
    require(
        len(SUITES) == 22 and sum(count for _, count in SUITES) == 137,
        "DECLARED_COUNTS",
    )
    sources = source_bindings()
    images = runtime.bind_runtime(godot)
    design_receipt = design.audit()
    validate_design_receipt(design_receipt)
    records = []
    for filename, count in SUITES:
        records.append(execute_suite(filename, count))
        print(
            "L15_COMPONENT_SUITE_PASS " + filename + " tests=" + str(count), flush=True
        )
    receipt = {
        **static_header(),
        "source_bindings": sources,
        "design_audit": design_receipt,
        "runtime_binding": images,
        "test_suites": records,
    }
    validate_receipt(receipt, expected_source_bindings=sources)
    # Reuse the exact reader controls against this complete newly produced
    # receipt. Their local host has no cold-suite setup, so this does not recurse
    # into another native run or substitute a smaller synthetic positive.
    spec = importlib.util.spec_from_file_location(
        "_sporespore_l15_rollup_reader_controls", ROOT / READER_CONTROLS
    )
    require(spec is not None and spec.loader is not None, "READER_CONTROLS_MODULE")
    controls = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(controls)
    receipt["receipt_reader_contract_test_count"] = (
        controls.exercise_actual_receipt_controls(receipt, expected_sources=sources)
    )
    require(packet.same(source_bindings(), sources), "SELECTED_SOURCE_DRIFT")
    require(packet.same(runtime.bind_runtime(godot), images), "RUNTIME_DRIFT")
    validate_receipt(receipt, expected_source_bindings=sources)
    return receipt
