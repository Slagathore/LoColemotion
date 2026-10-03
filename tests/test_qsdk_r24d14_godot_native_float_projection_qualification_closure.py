#!/usr/bin/env python3
"""Immutable closure audit for the official R24D14 zero-step qualification."""

from __future__ import annotations

import copy
import hashlib
import json
import struct
import subprocess
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = Path(r"C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence")
CLOSURE_PATH = ROOT / "sdk/recovery/r24d14_godot_native_float_projection_qualification_positive_closure_v1.json"
RUN_ROOT = EVIDENCE / "qsdk-r24d14-native-float-projection/qualification/20260827T000809847Z-4f4d9f49-5da8edfa32af"
DEVELOPMENT_ROOT = EVIDENCE / "qsdk-r24d14-native-float-projection/development"
SOURCE_COMMIT = "4f4d9f4900689bd7b452383d75b1eb8021b41e28"
MANIFEST_RELATIVE = "sdk/recovery/r24d14_godot_native_float_projection_validation_manifest.json"
MANIFEST_SHA = "sha256:7b32d6f5cafcfe68301c683761a8fb0e5cd4b3b151fc242e18a58994300115ae"
RECEIPT_SHA = "sha256:e958fad063c67043fef3a9a7570a7ae3a47d6f272d64724d76ed2da471c4ad4d"


def fail(code: str) -> None:
    raise SystemExit(f"QSDK-R24D14 native projection qualification closure: {code}")


def require(condition: bool, code: str) -> None:
    if not condition:
        fail(code)


def read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    require(type(value) is dict, f"json_object:{path}")
    return value


def sha(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def git(*args: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(ROOT), *args],
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    require(result.returncode == 0, f"git:{'_'.join(args)}:{result.stderr.strip()}")
    return result.stdout.strip()


def binary64_hex(value: float) -> str:
    return struct.pack(">d", value).hex()


def validate_closure(value: dict[str, Any]) -> None:
    require(
        value.get("schema_version")
        == "sporespore_qsdk_r24d14_godot_native_float_projection_qualification_positive_closure_v1",
        "schema",
    )
    require(value.get("gate_id") == "QSDK-R24D14", "gate")
    require(value.get("question_class") == "development", "class")
    require(
        value.get("status")
        == "complete_clean_pushed_zero_step_native_property_and_telemetry_projection_qualified_physical_supervisor_pending",
        "status",
    )
    source = value.get("source", {})
    require(source.get("commit") == SOURCE_COMMIT, "source_commit")
    require(source.get("cached_origin_main") == SOURCE_COMMIT, "cached_remote")
    require(source.get("live_origin_main") == SOURCE_COMMIT, "live_remote")
    require(source.get("clean_pushed_before_qualification") is True, "clean_pushed")
    require(source.get("validation_manifest_raw_sha256") == MANIFEST_SHA, "manifest_sha")
    require(source.get("source_binding_count") == 17, "source_bindings")
    require(source.get("native_source_binding_count") == 6, "native_bindings")
    predecessor = value.get("predecessor", {})
    require(predecessor.get("gate_id") == "QSDK-R24D13", "predecessor_gate")
    require(predecessor.get("result_rewritten_rethresholded_or_reinterpreted") is False, "predecessor_rewrite")
    require(predecessor.get("physical_evidence_reused") is False, "predecessor_reuse")
    retained = value.get("retained_evidence", {})
    require(retained.get("receipt_raw_sha256") == RECEIPT_SHA, "receipt_sha")
    require(retained.get("file_count") == 18, "file_count")
    require(retained.get("total_byte_length") == 117384, "byte_count")
    require(retained.get("unique_content_digest_count") == 16, "unique_count")
    require(retained.get("embedded_cas_reference_count") == 10, "cas_count")
    require(retained.get("unique_embedded_cas_digest_count") == 8, "cas_unique")
    require(len(retained.get("inventory", [])) == 18, "inventory_count")
    calibration = value.get("development_calibration_population", {})
    require(calibration.get("run_count") == 4, "development_count")
    require(calibration.get("invalid_or_incomplete_count") == 3, "development_invalid")
    require(calibration.get("passing_count") == 1, "development_pass")
    require(calibration.get("official_qualification_count") == 1, "official_count")
    require(calibration.get("development_runs_are_official_evidence") is False, "development_authority")
    qualification = value.get("qualification", {})
    require(
        qualification.get("result")
        == "complete_zero_step_native_property_and_telemetry_projection_passed",
        "result",
    )
    for key in (
        "source_audit_passed",
        "predecessor_closure_audit_passed",
        "evaluator_self_test_passed",
        "native_worker_passed",
        "independent_python_evaluation_passed",
        "native_joint_rid_valid",
        "adjacent_r24d13_values_rejected",
        "production_evaluator_full_precision_round_trip_passed",
    ):
        require(qualification.get(key) is True, f"qualification_{key}")
    require(qualification.get("native_joint_allocation_count") == 1, "joint_count")
    require(qualification.get("native_joint_release_call_count") == 1, "joint_release")
    require(qualification.get("native_impulse_binary64_hex") == "3f60624de0000000", "impulse_hex")
    require(qualification.get("native_timestep_binary64_hex") == "3f81111120000000", "timestep_hex")
    require(qualification.get("production_evaluator_parser") == "python_json", "parser")
    require(qualification.get("godot_json_parser_is_production_evaluator") is False, "godot_parser")
    for key in ("world_attempt_count", "world_build_count", "solver_step_count"):
        require(qualification.get(key) == 0, f"qualification_{key}")
    require(qualification.get("physical_characterization_executed") is False, "physical_execution")
    adequacy = value.get("adequacy", {})
    for key in (
        "empirical_acceptance_threshold_count",
        "superiority_margin_count",
        "equivalence_or_non_inferiority_margin_count",
        "held_out_validation_cohort_count",
        "population_claim_count",
    ):
        require(adequacy.get(key) == 0, f"adequacy_{key}")
    disposition = value.get("disposition", {})
    require(disposition.get("official_qualification_consumed") is True, "consumed")
    require(disposition.get("same_source_official_qualification_rerun_allowed") is False, "rerun")
    require(disposition.get("qualification_may_be_rewritten_or_reinterpreted") is False, "rewrite")
    require(disposition.get("physical_supervisor_source_must_be_distinct") is True, "distinct_supervisor")
    require(disposition.get("physical_supervisor_must_bind_this_closure") is True, "closure_binding")
    require(disposition.get("physical_execution_authorized_now") is False, "authorization")
    claims = value.get("claims", {})
    for key in (
        "native_property_readback_projection_qualified",
        "telemetry_float32_variant_projection_qualified",
        "complete_zero_step_qualification_passed",
    ):
        require(claims.get(key) is True, f"claim_{key}")
    for key in (
        "physical_supervisor_implemented",
        "physical_characterization_executed",
        "native_braking_mechanism_activation_observed",
        "instrumented_profile_promoted",
        "stock_godot_profile_promoted",
        "native_capability_conjunction_complete",
        "recovery_world_opened",
        "prone_to_standing_world_opened",
        "turning_claim_changed",
        "cross_engine_equivalence_claimed",
        "q_sdk_r24_satisfied",
        "physical_acceptance_authority",
        "release_authority",
    ):
        require(claims.get(key) is False, f"claim_{key}")
    require(value.get("next_boundary", {}).get("physical_world_may_open_now") is False, "next_world")


def collect_cas(value: Any, found: list[dict[str, Any]]) -> None:
    if type(value) is dict:
        if value.get("schema_version") == "sporespore_content_addressed_artifact_receipt_v1":
            found.append(value)
        for child in value.values():
            collect_cas(child, found)
    elif type(value) is list:
        for child in value:
            collect_cas(child, found)


def main() -> int:
    closure = read_json(CLOSURE_PATH)
    validate_closure(closure)
    require(RUN_ROOT.is_dir(), "run_root_missing")
    inventory = closure["retained_evidence"]["inventory"]
    expected_paths = [item["path"] for item in inventory]
    require(len(expected_paths) == len(set(expected_paths)), "inventory_duplicate")
    actual_paths = sorted(path.relative_to(RUN_ROOT).as_posix() for path in RUN_ROOT.rglob("*") if path.is_file())
    require(actual_paths == sorted(expected_paths), "inventory_population")
    actual_hashes: list[str] = []
    total = 0
    for item in inventory:
        path = RUN_ROOT / item["path"]
        require(path.is_file(), f"inventory_missing:{item['path']}")
        raw_sha = sha(path)
        byte_length = path.stat().st_size
        require(raw_sha == item["raw_sha256"], f"inventory_sha:{item['path']}")
        require(byte_length == item["byte_length"], f"inventory_bytes:{item['path']}")
        actual_hashes.append(raw_sha)
        total += byte_length
    require(total == 117384, "inventory_total")
    require(len(set(actual_hashes)) == 16, "inventory_unique")

    receipt_path = RUN_ROOT / "receipt.json"
    require(sha(receipt_path) == RECEIPT_SHA, "receipt_live_sha")
    receipt = read_json(receipt_path)
    require(receipt.get("ok") is True, "receipt_ok")
    require(receipt.get("mode") == "Qualification", "receipt_mode")
    require(receipt.get("official_qualification") is True, "receipt_official")
    require(receipt.get("same_source_official_qualification_rerun_allowed") is False, "receipt_rerun")
    source = receipt["source"]
    require(source.get("head") == SOURCE_COMMIT, "receipt_source")
    require(source.get("clean_pushed") is True, "receipt_clean")
    require(source.get("status_porcelain") == "", "receipt_status")
    worker = receipt["worker"]["receipt"]
    require(worker.get("ok") is True, "worker_ok")
    require(worker.get("native_joint_allocation_count") == 1, "worker_joint")
    require(worker.get("native_joint_release_call_count") == 1, "worker_release")
    require(worker.get("native_impulse_matches") is True, "worker_impulse")
    require(worker.get("native_timestep_matches") is True, "worker_timestep")
    require(worker.get("full_precision_text_matches") is True, "worker_text")
    require(worker.get("godot_json_parser_is_production_evaluator") is False, "worker_parser")
    for key in ("world_attempt_count", "world_build_count", "solver_step_count"):
        require(worker.get(key) == 0, f"worker_{key}")

    raw_report = read_json(RUN_ROOT / "synthetic-raw-report.json")
    impulse = raw_report["cells"][0]["parameter_readback"]["public_maximum_motor_impulse_nms"]
    timestep = raw_report["cells"][0]["samples"][0]["telemetry"]["solver_step_s"]
    require(binary64_hex(impulse) == "3f60624de0000000", "raw_impulse_bits")
    require(binary64_hex(timestep) == "3f81111120000000", "raw_timestep_bits")
    evaluation = read_json(RUN_ROOT / "synthetic-evaluation.json")
    require(evaluation.get("ok") is True, "evaluation_ok")
    require(evaluation.get("gate_id") == "QSDK-R24D14", "evaluation_gate")
    require(evaluation.get("result") == "synthetic_shape_conforms_zero_world_only", "evaluation_result")
    require(evaluation.get("physical_acceptance_authority") is False, "evaluation_authority")
    attempt = read_json(RUN_ROOT / "attempt.json")
    require(attempt.get("status") == "complete_zero_step_native_projection_passed", "attempt_status")
    for key in ("world_attempt_count", "world_build_count", "solver_step_count"):
        require(attempt.get(key) == 0, f"attempt_{key}")

    manifest_bytes = subprocess.run(
        ["git", "-C", str(ROOT), "show", f"{SOURCE_COMMIT}:{MANIFEST_RELATIVE}"],
        check=True,
        capture_output=True,
    ).stdout
    require("sha256:" + hashlib.sha256(manifest_bytes).hexdigest() == MANIFEST_SHA, "manifest_commit_sha")
    manifest = json.loads(manifest_bytes)
    require(manifest.get("source_binding_count") == 17, "manifest_source_count")
    for binding in manifest["source_bindings"]:
        blob = git("rev-parse", f"{SOURCE_COMMIT}:{binding['path']}")
        require(blob == binding["git_blob_oid"], f"manifest_blob:{binding['path']}")

    cas_receipts: list[dict[str, Any]] = []
    collect_cas(receipt, cas_receipts)
    require(len(cas_receipts) == 10, "cas_receipt_count")
    unique_cas = {item["sha256"] for item in cas_receipts}
    require(len(unique_cas) == 8, "cas_unique_count")
    for item in cas_receipts:
        digest = item["sha256"].split(":", 1)[1]
        payload = EVIDENCE / "artifacts/sha256" / digest / "payload.bin"
        require(payload.is_file(), f"cas_payload_missing:{digest}")
        require(sha(payload) == item["sha256"], f"cas_payload_sha:{digest}")
        require(payload.stat().st_size == item["byte_length"], f"cas_payload_bytes:{digest}")

    official_receipts = list((EVIDENCE / "qsdk-r24d14-native-float-projection/qualification").rglob("receipt.json"))
    require(official_receipts == [receipt_path], "official_receipt_population")
    development_names = sorted(path.name for path in DEVELOPMENT_ROOT.iterdir() if path.is_dir())
    require(development_names == sorted(closure["development_calibration_population"]["development_run_names"]), "development_population")

    mutations: list[tuple[tuple[str, ...], Any]] = [
        (("gate_id",), "QSDK-MUTATED"),
        (("question_class",), "finite_decision"),
        (("status",), "mutated"),
        (("source", "commit"), "0" * 40),
        (("source", "clean_pushed_before_qualification"), False),
        (("source", "validation_manifest_raw_sha256"), "sha256:" + "0" * 64),
        (("retained_evidence", "receipt_raw_sha256"), "sha256:" + "0" * 64),
        (("retained_evidence", "file_count"), 17),
        (("retained_evidence", "total_byte_length"), 0),
        (("development_calibration_population", "official_qualification_count"), 2),
        (("qualification", "native_impulse_binary64_hex"), "3f60624ddffffffa"),
        (("qualification", "native_timestep_binary64_hex"), "3f8111111ffffffd"),
        (("qualification", "adjacent_r24d13_values_rejected"), False),
        (("qualification", "solver_step_count"), 1),
        (("adequacy", "empirical_acceptance_threshold_count"), 1),
        (("disposition", "same_source_official_qualification_rerun_allowed"), True),
        (("disposition", "physical_supervisor_source_must_be_distinct"), False),
        (("disposition", "physical_execution_authorized_now"), True),
        (("claims", "complete_zero_step_qualification_passed"), False),
        (("claims", "release_authority"), True),
    ]
    rejected = 0
    for path, replacement in mutations:
        mutated = copy.deepcopy(closure)
        target: Any = mutated
        for part in path[:-1]:
            target = target[part]
        target[path[-1]] = replacement
        try:
            validate_closure(mutated)
        except SystemExit:
            rejected += 1
        else:
            fail(f"mutation_accepted:{'.'.join(path)}")

    print(
        "QSDK_R24D14_NATIVE_PROJECTION_QUALIFICATION_CLOSURE_PASS "
        f"files=18 unique_digests=16 bytes=117384 cas=10/8 mutations={rejected} "
        "native_joints=1 worlds=0 builds=0 solver_steps=0 "
        "physical_authority=false release_authority=false"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
