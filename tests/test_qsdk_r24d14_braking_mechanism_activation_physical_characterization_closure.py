#!/usr/bin/env python3
"""Audit the immutable R24D14 native braking-mechanism characterization.

This audit reads retained run bytes, content-addressed objects, and historical
Git objects. It independently recomputes the four finite mechanism witnesses;
it cannot launch the supervisor, Godot, a worker, or a physics world.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import subprocess
from pathlib import Path
from typing import Any, NoReturn


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = Path(r"C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence")
AUTHORIZATION_COMMIT = "a6be67273c113d4768fa8930cd47ab0eab21be15"
AUTHORIZATION_TREE = "1f7c455d061f89c2dbf0f20c4e4c7ed0097e6cfa"
FREEZE_COMMIT = "f0f250b92c7aeae027331cc1c9813d3eb9f163b1"
NONCE = "bd015eb4a2ea44498146d5f29639dedb"
RUN_ROOT = (
    EVIDENCE
    / "qsdk-r24d14-braking-mechanism-activation"
    / "physical"
    / "20260827T005329324Z-a6be6727-bd015eb4a2ea"
)
CLOSURE_REL = (
    "sdk/recovery/r24d14_godot_jolt_braking_mechanism_activation_"
    "physical_characterization_closure_v1.json"
)
AUDIT_REL = (
    "tests/test_qsdk_r24d14_braking_mechanism_activation_"
    "physical_characterization_closure.py"
)
AUTH_REL = (
    "sdk/recovery/r24d14_godot_jolt_braking_mechanism_activation_"
    "physical_authorization_v1.json"
)
RESULT = "complete_valid_finite_native_braking_mechanism_activation_positive"
RECEIPT_SHA = (
    "sha256:6038ce332790040963c40f991c06fed8f01278fe652891c0b586e5040458c11d"
)
RECEIPT_BYTES = 67405
ATTEMPT_SHA = (
    "sha256:98e78812522be4d2ebd4f56b8d3dc59a843452a41da61a3589c256940934ddcf"
)
RAW_SHA = (
    "sha256:1897c66d8ac322edacd93da1011fe9e465bd13ff50466fd1e3ee25e3e198aff3"
)
RAW_CANONICAL_SHA = (
    "sha256:4a07dd326c060f5d4768e760ca607da2fd5ec3ad626c689d70f8dc0f31cbc2e0"
)
EVALUATION_SHA = (
    "sha256:c6ff7380916e02f96f686b836792b5314b303d9c4d18643fb735e0cdad242081"
)
AUTH_SHA = (
    "sha256:2e9f72ff88dc0c210bbe9c80b0a931a0bc10d34be1a4225578d9f8142c2ccc73"
)
QUALIFICATION_RECEIPT_SHA = (
    "sha256:14f3f921f3f22ac20272a130a965d52cff6c11f8a63f85be16c93626423f7937"
)
QUALIFICATION_CLOSURE_SHA = (
    "sha256:f9f15e4bc7d6f6e718823693d5a596d786456169d52c31f2844f7a15a1463ed4"
)
PROJECTION_RECEIPT_SHA = (
    "sha256:e958fad063c67043fef3a9a7570a7ae3a47d6f272d64724d76ed2da471c4ad4d"
)
PROJECTION_CLOSURE_SHA = (
    "sha256:55badec51735428a10ef4b9ff18051133db2e10225e0428863fe79dac9f46ed6"
)
PREDECESSOR_CLOSURE_SHA = (
    "sha256:2fa82f2a04d579612fbc34cfc62875f6b8f5acca63a41dd3a1da1d2d5bbdb725"
)
CONSOLE_SHA = (
    "sha256:ff655a567d31f51628d5b21742a0618e53f9fbf8a94937dd07d9882a0739872f"
)
ENGINE_SHA = (
    "sha256:2d68ed7ae53704ffb532cd5633241c74d599d69e3bf1968de0ef261553030ffb"
)
EXPECTED_CELL_IDS = [
    "brake_positive",
    "brake_negative",
    "disabled_positive",
    "disabled_negative",
]
EXPECTED_BINDINGS = [
    {
        "role": "physical_supervisor",
        "path": "sdk/run_qsdk_r24d14_braking_mechanism_activation_characterization.ps1",
        "raw_sha256": "sha256:76af1ed2cdabd559ce28eb1c5951383c75af4a044645b0d5465c47b6fe16bd81",
        "byte_length": 81468,
        "git_blob_oid": "7cb36ab138768c7e495bc491411cbb57dd8fcc65",
    },
    {
        "role": "physical_supervisor_contract",
        "path": "sdk/recovery/r24d14_godot_jolt_braking_mechanism_activation_physical_supervisor_contract_v1.json",
        "raw_sha256": "sha256:30cbadf2039a18f80257075dffa91dbc1ea525d40028037cbab393dc71891e50",
        "byte_length": 11184,
        "git_blob_oid": "2f335695e5f9505f9a354c50500b69998252f98d",
    },
    {
        "role": "physical_supervisor_manifest",
        "path": "sdk/recovery/r24d14_godot_jolt_braking_mechanism_activation_physical_supervisor_manifest_v1.json",
        "raw_sha256": "sha256:570d56664e56a7a687efc7447deef81947748f1741a212cb80024de907b8813c",
        "byte_length": 7335,
        "git_blob_oid": "4d01b32f8757cb56e0c753f1b4b5805e2af5d098",
    },
    {
        "role": "physical_authorization",
        "path": AUTH_REL,
        "raw_sha256": AUTH_SHA,
        "byte_length": 3343,
        "git_blob_oid": "b206daedfaf0f1fce34df80ab75fbc285e34631c",
    },
    {
        "role": "physical_supervisor_qualification_closure",
        "path": "sdk/recovery/r24d14_godot_jolt_braking_mechanism_activation_physical_supervisor_qualification_positive_closure_v1.json",
        "raw_sha256": QUALIFICATION_CLOSURE_SHA,
        "byte_length": 10990,
        "git_blob_oid": "f739a2d8ac15d110f5796f78ff66ca8f39a2e9ff",
    },
    {
        "role": "native_projection_qualification_closure",
        "path": "sdk/recovery/r24d14_godot_native_float_projection_qualification_positive_closure_v1.json",
        "raw_sha256": PROJECTION_CLOSURE_SHA,
        "byte_length": 10801,
        "git_blob_oid": "502fb80744849664c4b7d224a7bdb65b2dc6554b",
    },
    {
        "role": "predecessor_physical_closure",
        "path": "sdk/recovery/r24d13_godot_jolt_braking_mechanism_activation_physical_attempt_closure_v1.json",
        "raw_sha256": PREDECESSOR_CLOSURE_SHA,
        "byte_length": 10665,
        "git_blob_oid": "a0d9341a09d1e74650c411d97489932dfc205379",
    },
    {
        "role": "physical_evaluator",
        "path": "sdk/recovery/r24d14_godot_jolt_braking_mechanism_activation_physical_evaluator.py",
        "raw_sha256": "sha256:2dae9b5aa61d1cb0c6e1a0073c41a0319d9510f69796b9470f84d1cec16cd1ac",
        "byte_length": 8396,
        "git_blob_oid": "e889ee2915c87ef6d1abd771f3ab0f54acc65e15",
    },
    {
        "role": "base_evaluator",
        "path": "sdk/recovery/r24d13_godot_jolt_braking_mechanism_activation_evaluator.py",
        "raw_sha256": "sha256:5e8c99c40cc7ea974d065d94aeeaac0e824e46b14e9ae82af62440d937ec4162",
        "byte_length": 41357,
        "git_blob_oid": "70ff11d71bd7f45d88cb540802506808f7fc1b81",
    },
    {
        "role": "physical_worker",
        "path": "tests/test_sdk_qsdk_r24d14_godot_jolt_braking_mechanism_activation_worker.gd",
        "raw_sha256": "sha256:486dc4a1ec1174fb7b3a0e18f6f37b4a2f6d410491ccf9b771556c3d8d19b896",
        "byte_length": 25382,
        "git_blob_oid": "5b5354a7a33441d5645559ea0fd64a7abe0595c0",
    },
]
TRUE_CLAIMS = {
    "complete_zero_world_gate_passed",
    "production_authorization_only_check_passed",
    "physical_world_executed",
    "accepted_physical_characterization",
    "valid_finite_descriptive_development_result",
    "native_braking_mechanism_characterized",
    "native_braking_mechanism_activation_observed",
}
FALSE_CLAIMS = {
    "numerical_accuracy_accepted",
    "instrumented_profile_promoted",
    "stock_godot_profile_promoted",
    "native_capability_conjunction_complete",
    "native_recovery_collector_implemented",
    "recovery_controller_implemented",
    "recovery_world_opened",
    "prone_to_standing_world_opened",
    "turning_claim_changed",
    "cross_engine_equivalence_claimed",
    "q_sdk_r24_satisfied",
    "physical_acceptance_authority",
    "release_authority",
}


def fail(code: str) -> NoReturn:
    raise SystemExit(f"QSDK-R24D14 physical characterization audit: {code}")


def exact(value: Any, expected: Any, code: str) -> None:
    if type(value) is not type(expected) or value != expected:
        fail(f"{code}:expected={expected!r}:actual={value!r}")


def mapping(value: Any, code: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        fail(code)
    return value


def sequence(value: Any, code: str) -> list[Any]:
    if not isinstance(value, list):
        fail(code)
    return value


def load_json(path: Path, code: str) -> dict[str, Any]:
    try:
        return mapping(json.loads(path.read_text(encoding="utf-8")), code)
    except (OSError, json.JSONDecodeError) as exc:
        fail(f"{code}:{exc}")


def raw_receipt(path: Path) -> tuple[str, int]:
    try:
        payload = path.read_bytes()
    except OSError as exc:
        fail(f"file:{path}:{exc}")
    return "sha256:" + hashlib.sha256(payload).hexdigest(), len(payload)


def git_text(*arguments: str) -> str:
    run = subprocess.run(
        ["git", "-C", str(ROOT), *arguments],
        check=False,
        capture_output=True,
        text=True,
    )
    if run.returncode != 0:
        fail(f"git:{'_'.join(arguments)}:{run.stderr.strip()}")
    return run.stdout.strip()


def git_bytes(*arguments: str) -> bytes:
    run = subprocess.run(
        ["git", "-C", str(ROOT), *arguments],
        check=False,
        capture_output=True,
    )
    if run.returncode != 0:
        fail(f"git_bytes:{'_'.join(arguments)}")
    return run.stdout


def verify_cas(sha: str, length: int, code: str) -> None:
    if not sha.startswith("sha256:") or len(sha) != 71:
        fail(f"{code}:digest")
    digest = sha[7:]
    directory = EVIDENCE / "artifacts" / "sha256" / digest
    exact(raw_receipt(directory / "payload.bin"), (sha, length), f"{code}:payload")
    manifest = load_json(directory / "manifest.json", f"{code}:manifest")
    exact(
        manifest.get("schema_version"),
        "sporespore_content_addressed_artifact_manifest_v1",
        f"{code}:schema",
    )
    exact(manifest.get("sha256"), sha, f"{code}:sha")
    exact(manifest.get("byte_length"), length, f"{code}:bytes")


def collect_cas(value: Any, found: list[tuple[str, int]]) -> None:
    if isinstance(value, dict):
        if value.get("schema_version") == "sporespore_content_addressed_artifact_receipt_v1":
            found.append((str(value.get("sha256")), int(value.get("byte_length", -1))))
        for child in value.values():
            collect_cas(child, found)
    elif isinstance(value, list):
        for child in value:
            collect_cas(child, found)


def validate_closure(closure: dict[str, Any]) -> None:
    exact(
        closure.get("schema_version"),
        "sporespore_qsdk_r24d14_godot_jolt_braking_mechanism_activation_physical_characterization_closure_v1",
        "closure_schema",
    )
    exact(closure.get("closure_id"), "QSDK-R24D14-PH1-CLOSURE", "closure_id")
    exact(closure.get("gate_id"), "QSDK-R24D14", "closure_gate")
    exact(closure.get("question_class"), "development", "closure_question")
    exact(
        closure.get("status"),
        "closed_complete_valid_finite_native_braking_mechanism_activation_positive_profile_promotion_decision_next",
        "closure_status",
    )
    exact(
        closure.get("result_class"),
        "valid_finite_descriptive_development_result",
        "closure_result_class",
    )

    source = mapping(closure.get("source"), "closure_source")
    exact(source.get("repository_root"), ROOT.as_posix(), "source_root")
    exact(
        source.get("repository_remote"),
        "https://github.com/Slagathore/sporespore.git",
        "source_remote",
    )
    exact(source.get("branch"), "main", "source_branch")
    exact(source.get("authorization_commit"), AUTHORIZATION_COMMIT, "source_commit")
    exact(source.get("authorization_tree_git_oid"), AUTHORIZATION_TREE, "source_tree")
    exact(source.get("authorization_parent_commit"), FREEZE_COMMIT, "source_parent")
    exact(source.get("supervisor_freeze_commit"), FREEZE_COMMIT, "source_freeze")
    for key in (
        "clean_pushed_before_physical_attempt",
        "local_upstream_cached_live_equal_before_physical_attempt",
        "single_worktree",
    ):
        exact(source.get(key), True, f"source_{key}")
    exact(sequence(source.get("bindings"), "source_bindings"), EXPECTED_BINDINGS, "source_binding_set")

    qualification = mapping(closure.get("prerequisite_qualification"), "qualification")
    exact(qualification.get("source_commit"), FREEZE_COMMIT, "qualification_source")
    exact(qualification.get("receipt_raw_sha256"), QUALIFICATION_RECEIPT_SHA, "qualification_receipt")
    exact(qualification.get("receipt_byte_length"), 25801, "qualification_receipt_bytes")
    exact(qualification.get("closure_raw_sha256"), QUALIFICATION_CLOSURE_SHA, "qualification_closure")
    exact(qualification.get("stage_count"), 7, "qualification_stages")
    for key in ("world_attempt_count", "world_build_count", "solver_step_count"):
        exact(qualification.get(key), 0, f"qualification_{key}")
    exact(qualification.get("physical_authority"), False, "qualification_authority")

    projection = mapping(closure.get("native_projection_prerequisite"), "projection")
    exact(projection.get("receipt_raw_sha256"), PROJECTION_RECEIPT_SHA, "projection_receipt")
    exact(projection.get("closure_raw_sha256"), PROJECTION_CLOSURE_SHA, "projection_closure")
    exact(projection.get("native_maximum_motor_impulse_binary64_hex"), "3f60624de0000000", "projection_impulse")
    exact(projection.get("native_solver_timestep_binary64_hex"), "3f81111120000000", "projection_timestep")
    for key in ("world_attempt_count", "world_build_count", "solver_step_count"):
        exact(projection.get(key), 0, f"projection_{key}")

    authorization = mapping(closure.get("physical_authorization"), "authorization")
    exact(authorization.get("path"), AUTH_REL, "authorization_path")
    exact(authorization.get("raw_sha256"), AUTH_SHA, "authorization_sha")
    exact(authorization.get("authorization_parent_commit"), FREEZE_COMMIT, "authorization_parent")
    exact(authorization.get("authorization_commit_derived_from_current_head"), True, "authorization_derived")
    exact(authorization.get("authorization_json_contains_self_commit_identity"), False, "authorization_self")
    exact(authorization.get("production_authorization_only_check_observed_before_attempt"), True, "authorization_check")
    exact(authorization.get("physical_attempt_limit"), 1, "authorization_limit")
    exact(authorization.get("physical_attempt_consumed"), True, "authorization_consumed")
    exact(authorization.get("same_source_rerun_allowed"), False, "authorization_rerun")

    runtime = mapping(closure.get("runtime"), "runtime")
    exact(runtime.get("profile_id"), "godot_4_7_jolt_sporespore_motor_telemetry_active_step_snapshot_v2", "runtime_profile")
    exact(runtime.get("godot_source_commit"), "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88", "runtime_source")
    exact(runtime.get("combined_patch_raw_sha256"), "sha256:9629982deb74da1d3e16ea8eaff7cefef7c37a33f407c4cd777e332f05ff376c", "runtime_patch")
    exact(runtime.get("executed_console_binary_raw_sha256"), CONSOLE_SHA, "runtime_console")
    exact(runtime.get("executed_console_binary_byte_length"), 293376, "runtime_console_bytes")
    exact(runtime.get("executed_engine_binary_raw_sha256"), ENGINE_SHA, "runtime_engine")
    exact(runtime.get("executed_engine_binary_byte_length"), 188829184, "runtime_engine_bytes")
    exact(runtime.get("physics_engine"), "Jolt Physics", "runtime_physics")
    exact(runtime.get("retained_binary_pair_executed"), True, "runtime_executed")
    exact(runtime.get("campaign_result_reused"), False, "runtime_result_reuse")
    exact(runtime.get("physical_evidence_reused"), False, "runtime_evidence_reuse")

    attempt = mapping(closure.get("physical_attempt"), "physical_attempt")
    exact(Path(str(attempt.get("run_root"))), RUN_ROOT, "attempt_root")
    exact(attempt.get("execution_nonce"), NONCE, "attempt_nonce")
    exact(attempt.get("attempt_raw_sha256"), ATTEMPT_SHA, "attempt_sha")
    exact(attempt.get("attempt_byte_length"), 1751, "attempt_bytes")
    exact(attempt.get("raw_report_raw_sha256"), RAW_SHA, "raw_sha")
    exact(attempt.get("raw_report_byte_length"), 11417, "raw_bytes")
    exact(attempt.get("raw_report_canonical_sha256"), RAW_CANONICAL_SHA, "raw_canonical")
    exact(attempt.get("evaluation_raw_sha256"), EVALUATION_SHA, "evaluation_sha")
    exact(attempt.get("evaluation_byte_length"), 3905, "evaluation_bytes")
    exact(attempt.get("receipt_raw_sha256"), RECEIPT_SHA, "receipt_sha")
    exact(attempt.get("receipt_byte_length"), RECEIPT_BYTES, "receipt_bytes")
    exact(attempt.get("result"), RESULT, "attempt_result")
    exact(attempt.get("execution_valid"), True, "attempt_valid")
    for key, expected in {
        "world_attempt_count": 1,
        "world_build_count": 1,
        "solver_step_count": 1,
        "retained_sample_count": 4,
    }.items():
        exact(attempt.get(key), expected, f"attempt_{key}")
    exact(attempt.get("same_source_rerun_allowed"), False, "attempt_rerun")

    mechanism = mapping(closure.get("mechanism_characterization"), "mechanism")
    exact(mechanism.get("cell_ids_in_order"), EXPECTED_CELL_IDS, "mechanism_cells")
    for key, expected in {
        "cell_count": 4,
        "retained_sample_count": 4,
        "motor_enabled_braking_witness_count": 2,
        "motor_disabled_zero_witness_count": 2,
        "signed_enabled_directions_observed": 2,
        "paired_disabled_directions_observed": 2,
    }.items():
        exact(mechanism.get(key), expected, f"mechanism_{key}")
    exact(mechanism.get("native_braking_mechanism_activation_observed"), True, "mechanism_positive")
    exact(mechanism.get("mechanism_witness_is_empirical_performance_threshold"), False, "mechanism_threshold")
    cells = sequence(closure.get("cell_observation_summary"), "closure_cells")
    exact([mapping(cell, "closure_cell").get("cell_id") for cell in cells], EXPECTED_CELL_IDS, "closure_cell_order")
    exact(len(cells), 4, "closure_cell_count")
    exact(mapping(cells[0], "closure_brake_positive").get("signed_motor_impulse_nms"), -0.0020000000949949026, "closure_brake_positive_impulse")

    retention = mapping(closure.get("retention"), "retention")
    for key, expected in {
        "physical_retained_file_count": 18,
        "physical_retained_total_byte_length": 157599,
        "physical_unique_content_digest_count": 16,
        "embedded_cas_reference_count": 28,
        "embedded_unique_cas_digest_count": 23,
    }.items():
        exact(retention.get(key), expected, f"retention_{key}")
    for key in (
        "receipt_cas_verified",
        "live_run_root_is_durable_convenience_copy",
        "content_addressed_and_git_bound_records_are_identity_authority",
    ):
        exact(retention.get(key), True, f"retention_{key}")

    boundary = mapping(closure.get("statistical_claim_boundary"), "statistical_boundary")
    for key in (
        "empirical_acceptance_threshold_count",
        "superiority_margin_count",
        "equivalence_or_non_inferiority_margin_count",
        "held_out_validation_cohort_count",
        "population_claim_count",
    ):
        exact(boundary.get(key), 0, f"statistical_{key}")
    exact(boundary.get("source_derived_mechanism_witness_rule_count"), 1, "mechanism_rule_count")
    if not str(boundary.get("adequacy_argument", "")).startswith("The complete prospectively frozen population"):
        fail("adequacy_argument")

    immutable = mapping(closure.get("immutability"), "immutability")
    for key, value in immutable.items():
        exact(value, True, f"immutability_{key}")
    next_boundary = mapping(closure.get("next_boundary"), "next_boundary")
    exact(next_boundary.get("gate_id"), "QSDK-R24D15", "next_gate")
    exact(next_boundary.get("question_class"), "finite_decision", "next_question")
    exact(next_boundary.get("declaration_authorized"), True, "next_declaration")
    exact(next_boundary.get("new_physical_execution_required"), False, "next_physics_required")
    for key in (
        "physical_execution_authorized",
        "instrumented_profile_promotion_authorized_by_this_closure",
        "stock_profile_promotion_authorized",
        "recovery_world_authorized",
        "prone_to_standing_world_authorized",
    ):
        exact(next_boundary.get(key), False, f"next_{key}")

    claims = mapping(closure.get("claims"), "claims")
    exact(set(claims), TRUE_CLAIMS | FALSE_CLAIMS, "claim_fields")
    for key in TRUE_CLAIMS:
        exact(claims.get(key), True, f"claim_{key}")
    for key in FALSE_CLAIMS:
        exact(claims.get(key), False, f"claim_{key}")
    exact(closure.get("closure_audit_path"), AUDIT_REL, "closure_audit_path")


def verify_inventory(closure: dict[str, Any]) -> None:
    declared = sequence(closure.get("physical_retained_inventory"), "inventory")
    expected: dict[str, tuple[str, int]] = {}
    for value in declared:
        item = mapping(value, "inventory_item")
        relative = str(item.get("path"))
        if relative in expected:
            fail(f"inventory_duplicate:{relative}")
        expected[relative] = (str(item.get("raw_sha256")), int(item.get("byte_length", -1)))
    exact(list(expected), sorted(expected), "inventory_order")
    actual = {
        path.relative_to(RUN_ROOT).as_posix(): raw_receipt(path)
        for path in sorted(value for value in RUN_ROOT.rglob("*") if value.is_file())
    }
    exact(actual, expected, "inventory_exact")
    exact(len(actual), 18, "inventory_count")
    exact(sum(length for _, length in actual.values()), 157599, "inventory_bytes")
    exact(len({sha for sha, _ in actual.values()}), 16, "inventory_unique_digests")
    physical_root = RUN_ROOT.parent
    exact(
        sorted(path for path in physical_root.iterdir() if path.is_dir()),
        [RUN_ROOT],
        "single_physical_attempt",
    )


def verify_frozen_source(closure: dict[str, Any]) -> None:
    exact(git_text("rev-parse", f"{AUTHORIZATION_COMMIT}^{{tree}}"), AUTHORIZATION_TREE, "git_tree")
    exact(
        git_text("rev-list", "--parents", "-n", "1", AUTHORIZATION_COMMIT).split(),
        [AUTHORIZATION_COMMIT, FREEZE_COMMIT],
        "authorization_parent_edge",
    )
    source = mapping(closure.get("source"), "source")
    for binding in sequence(source.get("bindings"), "bindings"):
        item = mapping(binding, "binding")
        relative = str(item.get("path"))
        payload = git_bytes("show", f"{AUTHORIZATION_COMMIT}:{relative}")
        exact("sha256:" + hashlib.sha256(payload).hexdigest(), item.get("raw_sha256"), f"source_sha:{relative}")
        exact(len(payload), item.get("byte_length"), f"source_bytes:{relative}")
        exact(git_text("rev-parse", f"{AUTHORIZATION_COMMIT}:{relative}"), item.get("git_blob_oid"), f"source_blob:{relative}")
    auth_payload = git_bytes("show", f"{AUTHORIZATION_COMMIT}:{AUTH_REL}")
    exact(("sha256:" + hashlib.sha256(auth_payload).hexdigest(), len(auth_payload)), (AUTH_SHA, 3343), "authorization_git_bytes")
    auth = mapping(json.loads(auth_payload), "authorization_json")
    if "authorization_commit" in auth:
        fail("authorization_self_identity")
    exact(auth.get("authorization_parent_commit"), FREEZE_COMMIT, "authorization_json_parent")
    exact(auth.get("physical_attempt_limit"), 1, "authorization_json_limit")
    exact(auth.get("same_source_rerun_allowed"), False, "authorization_json_rerun")


def verify_attempt_and_receipt(closure: dict[str, Any]) -> tuple[dict[str, Any], dict[str, Any]]:
    exact(raw_receipt(RUN_ROOT / "attempt.json"), (ATTEMPT_SHA, 1751), "attempt_file")
    exact(raw_receipt(RUN_ROOT / "raw-report.json"), (RAW_SHA, 11417), "raw_file")
    exact(raw_receipt(RUN_ROOT / "evaluation.json"), (EVALUATION_SHA, 3905), "evaluation_file")
    exact(raw_receipt(RUN_ROOT / "receipt.json"), (RECEIPT_SHA, RECEIPT_BYTES), "receipt_file")

    attempt = load_json(RUN_ROOT / "attempt.json", "attempt_json")
    exact(attempt.get("schema_version"), "sporespore_qsdk_r24d14_physical_attempt_v1", "attempt_schema")
    exact(attempt.get("gate_id"), "QSDK-R24D14", "attempt_gate")
    exact(attempt.get("question_class"), "development", "attempt_question")
    exact(attempt.get("status"), RESULT, "attempt_status")
    exact(attempt.get("authorization_commit"), AUTHORIZATION_COMMIT, "attempt_authorization")
    exact(attempt.get("authorization_parent_commit"), FREEZE_COMMIT, "attempt_parent")
    exact(attempt.get("authorization_sha256"), AUTH_SHA, "attempt_authorization_sha")
    exact(attempt.get("qualification_receipt_sha256"), QUALIFICATION_RECEIPT_SHA, "attempt_qualification_receipt")
    exact(attempt.get("qualification_closure_sha256"), QUALIFICATION_CLOSURE_SHA, "attempt_qualification_closure")
    exact(attempt.get("prerequisite_native_projection_qualification_receipt_sha256"), PROJECTION_RECEIPT_SHA, "attempt_projection_receipt")
    exact(attempt.get("prerequisite_native_projection_qualification_closure_sha256"), PROJECTION_CLOSURE_SHA, "attempt_projection_closure")
    exact(attempt.get("prerequisite_predecessor_physical_closure_sha256"), PREDECESSOR_CLOSURE_SHA, "attempt_predecessor")
    exact(attempt.get("execution_nonce"), NONCE, "attempt_nonce")
    for key, expected in {
        "world_attempt_count": 1,
        "world_build_count": 1,
        "solver_step_count": 1,
        "retained_sample_count": 4,
        "worker_launch_count": 1,
    }.items():
        exact(attempt.get(key), expected, f"attempt_{key}")
    exact(attempt.get("same_source_rerun_allowed"), False, "attempt_rerun")
    exact(attempt.get("physical_acceptance_authority"), False, "attempt_physical_authority")
    exact(attempt.get("release_authority"), False, "attempt_release")

    receipt = load_json(RUN_ROOT / "receipt.json", "receipt_json")
    exact(receipt.get("schema_version"), "sporespore_qsdk_r24d14_braking_mechanism_activation_physical_receipt_v1", "receipt_schema")
    exact(receipt.get("ok"), True, "receipt_ok")
    exact(receipt.get("gate_id"), "QSDK-R24D14", "receipt_gate")
    exact(receipt.get("question_class"), "development", "receipt_question")
    exact(receipt.get("status"), RESULT, "receipt_status")
    source = mapping(receipt.get("source"), "receipt_source")
    for key in ("head", "upstream", "cached_origin_main", "live_origin_main"):
        exact(source.get(key), AUTHORIZATION_COMMIT, f"receipt_source_{key}")
    exact(source.get("worktree_count"), 1, "receipt_worktrees")
    exact(source.get("worktree_clean"), True, "receipt_clean")
    exact(source.get("status_porcelain"), "", "receipt_status_porcelain")
    authorization = mapping(receipt.get("authorization"), "receipt_authorization")
    exact(mapping(authorization.get("file"), "receipt_authorization_file").get("raw_sha256"), AUTH_SHA, "receipt_authorization_sha")
    exact(mapping(authorization.get("value"), "receipt_authorization_value").get("physical_attempt_limit"), 1, "receipt_authorization_limit")
    worker = mapping(mapping(receipt.get("worker"), "receipt_worker").get("receipt"), "receipt_worker_value")
    exact(worker.get("ok"), True, "worker_ok")
    exact(worker.get("source_commit"), AUTHORIZATION_COMMIT, "worker_source")
    exact(worker.get("execution_nonce"), NONCE, "worker_nonce")
    for key, expected in {
        "world_attempt_count": 1,
        "world_build_count": 1,
        "solver_step_count": 1,
        "retained_sample_count": 4,
    }.items():
        exact(worker.get(key), expected, f"worker_{key}")
    evaluation = load_json(RUN_ROOT / "evaluation.json", "evaluation_json")
    exact(mapping(receipt.get("evaluation"), "receipt_evaluation").get("receipt"), evaluation, "receipt_embedded_evaluation")
    actual = mapping(receipt.get("actual_counts"), "receipt_actual")
    exact(actual, {"world_attempt_count": 1, "world_build_count": 1, "solver_step_count": 1, "retained_sample_count": 4}, "receipt_counts")
    claims = mapping(receipt.get("claims"), "receipt_claims")
    exact(claims.get("native_braking_mechanism_characterized"), True, "receipt_characterized")
    exact(claims.get("native_braking_mechanism_activation_observed"), True, "receipt_activation")
    for key in (
        "numerical_accuracy_accepted",
        "instrumented_profile_promoted",
        "stock_godot_profile_promoted",
        "recovery_world_opened",
        "prone_to_standing_world_opened",
        "turning_claim_changed",
        "cross_engine_equivalence_claimed",
        "q_sdk_r24_satisfied",
        "physical_acceptance_authority",
        "release_authority",
    ):
        exact(claims.get(key), False, f"receipt_claim_{key}")
    exact(mapping(closure.get("physical_attempt"), "closure_attempt").get("receipt_raw_sha256"), RECEIPT_SHA, "closure_receipt_link")
    return receipt, evaluation


def recompute_characterization(closure: dict[str, Any], evaluation: dict[str, Any]) -> None:
    report = load_json(RUN_ROOT / "raw-report.json", "raw_report")
    exact(report.get("schema_version"), "sporespore_qsdk_r24d14_godot_jolt_braking_mechanism_activation_raw_report_v1", "report_schema")
    exact(report.get("gate_id"), "QSDK-R24D14", "report_gate")
    exact(report.get("question_class"), "development", "report_question")
    exact(report.get("evidence_kind"), "native_physical", "report_kind")
    exact(report.get("source_commit"), AUTHORIZATION_COMMIT, "report_source")
    exact(report.get("execution_nonce"), NONCE, "report_nonce")
    execution = mapping(report.get("execution"), "report_execution")
    exact(execution.get("world_attempt_count"), 1, "report_worlds")
    exact(execution.get("world_build_count"), 1, "report_builds")
    exact(execution.get("physics_step_count"), 1, "report_steps")
    exact(execution.get("retained_sample_count"), 4, "report_samples")
    exact(execution.get("first_retained_space_step_sequence"), 1, "report_first_token")
    exact(execution.get("last_retained_space_step_sequence"), 1, "report_last_token")
    exact(execution.get("extra_unretained_post_activation_step_count"), 0, "report_extra_steps")
    exact(execution.get("outcome_dependent_early_stop_count"), 0, "report_early_stop")
    exact(execution.get("physics_server_disabled_before_step_two"), True, "report_disabled")

    canonical = json.dumps(report, sort_keys=True, separators=(",", ":"), allow_nan=False).encode("utf-8")
    exact("sha256:" + hashlib.sha256(canonical).hexdigest(), RAW_CANONICAL_SHA, "report_canonical_sha")
    exact(evaluation.get("raw_report_canonical_sha256"), RAW_CANONICAL_SHA, "evaluation_canonical_sha")
    exact(evaluation.get("schema_version"), "sporespore_qsdk_r24d14_godot_jolt_braking_mechanism_activation_evaluation_v1", "evaluation_schema")
    exact(evaluation.get("ok"), True, "evaluation_ok")
    exact(evaluation.get("gate_id"), "QSDK-R24D14", "evaluation_gate")
    exact(evaluation.get("question_class"), "development", "evaluation_question")
    exact(evaluation.get("evidence_kind"), "native_physical", "evaluation_kind")
    exact(evaluation.get("result"), RESULT, "evaluation_result")
    exact(evaluation.get("source_commit"), AUTHORIZATION_COMMIT, "evaluation_source")
    exact(evaluation.get("execution_nonce"), NONCE, "evaluation_nonce")
    exact(evaluation.get("execution_valid"), True, "evaluation_valid")

    cells = sequence(report.get("cells"), "report_cells")
    exact([mapping(cell, "report_cell").get("cell_id") for cell in cells], EXPECTED_CELL_IDS, "report_cell_order")
    findings: list[dict[str, Any]] = []
    enabled_witnesses = 0
    disabled_witnesses = 0
    for cell in cells:
        item = mapping(cell, "cell")
        samples = sequence(item.get("samples"), "cell_samples")
        exact(len(samples), 1, f"sample_count:{item.get('cell_id')}")
        sample = mapping(samples[0], "sample")
        telemetry = mapping(sample.get("telemetry"), "telemetry")
        pre_rate = float(sample["pre_canonical_relative_rate_rad_s"])
        post_rate = float(sample["post_canonical_relative_rate_rad_s"])
        impulse = float(telemetry["signed_motor_impulse_nms"])
        positive_work = float(telemetry["positive_motor_work_j"])
        absorbed_work = float(telemetry["absorbed_motor_work_j"])
        net_work = float(telemetry["net_motor_work_j"])
        motor_enabled = bool(item["motor_enabled"])
        if motor_enabled:
            witness = impulse != 0.0 and impulse * pre_rate < 0.0 and absorbed_work > 0.0 and net_work < 0.0
            enabled_witnesses += int(witness)
        else:
            witness = impulse == 0.0 and positive_work == 0.0 and absorbed_work == 0.0 and net_work == 0.0
            disabled_witnesses += int(witness)
        effective_inertia = 1.0 / float(sample["inverse_inertia_axis_kg_inv_m2"])
        independent_impulse = effective_inertia * (post_rate - pre_rate)
        independent_energy = 0.5 * effective_inertia * (post_rate**2 - pre_rate**2)
        findings.append(
            {
                "cell_id": item["cell_id"],
                "motor_enabled": item["motor_enabled"],
                "mechanism_witness": witness,
                "pre_canonical_relative_rate_rad_s": pre_rate,
                "post_canonical_relative_rate_rad_s": sample["post_canonical_relative_rate_rad_s"],
                "signed_motor_impulse_nms": impulse,
                "positive_motor_work_j": positive_work,
                "absorbed_motor_work_j": absorbed_work,
                "net_motor_work_j": net_work,
                "independent_angular_momentum_change_nms": independent_impulse,
                "independent_kinetic_energy_change_j": independent_energy,
                "impulse_residual_nms": impulse - independent_impulse,
                "work_residual_j": net_work - independent_energy,
            }
        )
    exact(enabled_witnesses, 2, "enabled_witnesses")
    exact(disabled_witnesses, 2, "disabled_witnesses")
    exact(sequence(evaluation.get("cells"), "evaluation_cells"), findings, "evaluation_findings")
    exact(sequence(closure.get("cell_observation_summary"), "closure_findings"), findings, "closure_findings")
    summary = mapping(evaluation.get("summary"), "evaluation_summary")
    exact(summary, {"cell_count": 4, "retained_sample_count": 4, "motor_enabled_braking_witness_count": 2, "motor_disabled_zero_witness_count": 2, "native_braking_mechanism_activation_observed": True}, "evaluation_summary_exact")
    for key in (
        "empirical_acceptance_threshold_count",
        "superiority_margin_count",
        "equivalence_or_non_inferiority_margin_count",
        "held_out_validation_cohort_count",
        "population_claim_count",
    ):
        exact(evaluation.get(key), 0, f"evaluation_{key}")
    for key in (
        "numerical_accuracy_accepted",
        "instrumented_profile_promoted",
        "stock_godot_profile_promoted",
        "native_capability_conjunction_complete",
        "recovery_world_opened",
        "prone_to_standing_world_opened",
        "q_sdk_r24_satisfied",
        "physical_acceptance_authority",
        "release_authority",
    ):
        exact(evaluation.get(key), False, f"evaluation_claim_{key}")


def verify_cas_population(receipt: dict[str, Any]) -> None:
    cas_receipts: list[tuple[str, int]] = []
    collect_cas(receipt, cas_receipts)
    exact(len(cas_receipts), 28, "cas_reference_count")
    unique_cas = sorted(set(cas_receipts))
    exact(len(unique_cas), 23, "cas_unique_count")
    for index, (sha, length) in enumerate(unique_cas):
        verify_cas(sha, length, f"embedded_cas_{index}")
    verify_cas(RECEIPT_SHA, RECEIPT_BYTES, "physical_receipt_cas")


def mutation_controls(closure: dict[str, Any]) -> int:
    mutations: list[tuple[tuple[Any, ...], Any]] = [
        (("question_class",), "finite_decision"),
        (("status",), "negative"),
        (("source", "authorization_commit"), "0" * 40),
        (("source", "authorization_tree_git_oid"), "0" * 40),
        (("source", "bindings"), EXPECTED_BINDINGS[:-1]),
        (("prerequisite_qualification", "receipt_raw_sha256"), PROJECTION_RECEIPT_SHA),
        (("prerequisite_qualification", "world_attempt_count"), 1),
        (("native_projection_prerequisite", "native_maximum_motor_impulse_binary64_hex"), "3f60624ddfffffff"),
        (("physical_authorization", "physical_attempt_consumed"), False),
        (("physical_authorization", "same_source_rerun_allowed"), True),
        (("runtime", "campaign_result_reused"), True),
        (("physical_attempt", "receipt_raw_sha256"), RAW_SHA),
        (("physical_attempt", "result"), "negative"),
        (("physical_attempt", "execution_valid"), False),
        (("physical_attempt", "world_attempt_count"), 0),
        (("physical_attempt", "solver_step_count"), 2),
        (("mechanism_characterization", "motor_enabled_braking_witness_count"), 1),
        (("mechanism_characterization", "motor_disabled_zero_witness_count"), 1),
        (("mechanism_characterization", "native_braking_mechanism_activation_observed"), False),
        (("mechanism_characterization", "mechanism_witness_is_empirical_performance_threshold"), True),
        (("cell_observation_summary", 0, "signed_motor_impulse_nms"), 0.0),
        (("retention", "physical_retained_file_count"), 17),
        (("retention", "embedded_cas_reference_count"), 27),
        (("statistical_claim_boundary", "empirical_acceptance_threshold_count"), 1),
        (("statistical_claim_boundary", "held_out_validation_cohort_count"), 1),
        (("immutability", "physical_attempt_consumed"), False),
        (("immutability", "same_authorization_physical_rerun_forbidden"), False),
        (("next_boundary", "gate_id"), "QSDK-R24"),
        (("next_boundary", "question_class"), "development"),
        (("next_boundary", "new_physical_execution_required"), True),
        (("claims", "accepted_physical_characterization"), False),
        (("claims", "native_braking_mechanism_activation_observed"), False),
        (("claims", "numerical_accuracy_accepted"), True),
        (("claims", "instrumented_profile_promoted"), True),
        (("claims", "prone_to_standing_world_opened"), True),
        (("claims", "physical_acceptance_authority"), True),
        (("claims", "release_authority"), True),
    ]
    rejected = 0
    for path, replacement in mutations:
        candidate = copy.deepcopy(closure)
        target: Any = candidate
        for key in path[:-1]:
            target = target[key]
        target[path[-1]] = replacement
        try:
            validate_closure(candidate)
        except SystemExit:
            rejected += 1
        else:
            fail(f"mutation_accepted:{'.'.join(str(value) for value in path)}")
    exact(rejected, len(mutations), "mutation_rejections")
    return rejected


def verify_commit_boundary(allow_prospective: bool) -> None:
    head = git_text("rev-parse", "HEAD")
    if allow_prospective:
        exact(head, AUTHORIZATION_COMMIT, "prospective_head")
        return
    exact(
        git_text("rev-list", "--parents", "-n", "1", head).split(),
        [head, AUTHORIZATION_COMMIT],
        "closure_parent_edge",
    )
    exact(git_text("status", "--short"), "", "worktree_clean")
    for relative in (CLOSURE_REL, AUDIT_REL):
        exact(git_text("hash-object", relative), git_text("rev-parse", f"{head}:{relative}"), f"committed:{relative}")
    for binding in EXPECTED_BINDINGS:
        relative = binding["path"]
        exact(git_text("rev-parse", f"{AUTHORIZATION_COMMIT}:{relative}"), git_text("rev-parse", f"{head}:{relative}"), f"source_unchanged:{relative}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--allow-prospective-uncommitted", action="store_true")
    args = parser.parse_args()

    exact(Path(git_text("rev-parse", "--show-toplevel")).resolve(), ROOT.resolve(), "root")
    exact(git_text("remote", "get-url", "origin"), "https://github.com/Slagathore/sporespore.git", "remote")
    closure = load_json(ROOT / CLOSURE_REL, "closure_json")
    validate_closure(closure)
    verify_inventory(closure)
    verify_frozen_source(closure)
    receipt, evaluation = verify_attempt_and_receipt(closure)
    recompute_characterization(closure, evaluation)
    verify_cas_population(receipt)
    rejected = mutation_controls(closure)
    verify_commit_boundary(args.allow_prospective_uncommitted)
    print(
        "QSDK_R24D14_PHYSICAL_CHARACTERIZATION_CLOSURE_PASS "
        f"files=18 unique_digests=16 bytes=157599 cas_references=28 "
        f"unique_cas=23 mutations={rejected} worlds=1 builds=1 solver_steps=1 "
        "samples=4 enabled_witnesses=2 disabled_controls=2 "
        "mechanism_observed=true numerical_accuracy=false profile_promoted=false "
        "physical_authority=false release_authority=false rerun=false"
    )


if __name__ == "__main__":
    main()
