#!/usr/bin/env python3
"""Audit the retained R24D14 zero-object qualification and authorization.

This audit reads retained bytes, content-addressed objects, and Git objects. It
cannot launch the supervisor, Godot, or a physical worker.
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
FREEZE = "f0f250b92c7aeae027331cc1c9813d3eb9f163b1"
FREEZE_TREE = "51303415cba724063363de206201ee043a8bc238"
RUN_ROOT = (
    EVIDENCE
    / "qsdk-r24d14-braking-mechanism-activation"
    / "physical-supervisor-qualification"
    / "20260827T004357759Z-f0f250b9-ec92f7a9f79f"
)
RECEIPT_SHA = (
    "sha256:14f3f921f3f22ac20272a130a965d52cff6c11f8a63f85be16c93626423f7937"
)
RECEIPT_BYTES = 25801
PROJECTION_RECEIPT_SHA = (
    "sha256:e958fad063c67043fef3a9a7570a7ae3a47d6f272d64724d76ed2da471c4ad4d"
)
PROJECTION_CLOSURE_SHA = (
    "sha256:55badec51735428a10ef4b9ff18051133db2e10225e0428863fe79dac9f46ed6"
)
PREDECESSOR_SHA = (
    "sha256:2fa82f2a04d579612fbc34cfc62875f6b8f5acca63a41dd3a1da1d2d5bbdb725"
)
CONSOLE_SHA = (
    "sha256:ff655a567d31f51628d5b21742a0618e53f9fbf8a94937dd07d9882a0739872f"
)
ENGINE_SHA = (
    "sha256:2d68ed7ae53704ffb532cd5633241c74d599d69e3bf1968de0ef261553030ffb"
)
MANIFEST_SHA = (
    "sha256:570d56664e56a7a687efc7447deef81947748f1741a212cb80024de907b8813c"
)
CLOSURE_REL = (
    "sdk/recovery/r24d14_godot_jolt_braking_mechanism_activation_"
    "physical_supervisor_qualification_positive_closure_v1.json"
)
AUTH_REL = (
    "sdk/recovery/r24d14_godot_jolt_braking_mechanism_activation_"
    "physical_authorization_v1.json"
)
SUPERVISOR_REL = (
    "sdk/run_qsdk_r24d14_braking_mechanism_activation_characterization.ps1"
)
MANIFEST_REL = (
    "sdk/recovery/r24d14_godot_jolt_braking_mechanism_activation_"
    "physical_supervisor_manifest_v1.json"
)
AUDIT_REL = (
    "tests/test_qsdk_r24d14_braking_mechanism_activation_"
    "physical_supervisor_qualification.py"
)
EXPECTED_STAGES = [
    "r24d14_physical_supervisor_source_audit",
    "immutable_r24d14_native_projection_qualification_closure_audit",
    "immutable_r24d13_physical_closure_audit",
    "r24d14_evaluator_self_test_and_negative_controls",
    "evaluator_shaped_zero_world_template",
    "custom_runtime_native_serialization_zero_object_worker",
    "independent_native_serialization_evaluation",
]
NATIVE_INERTIA = [0.05000000074505806] * 3
NATIVE_IMPULSE = 0.0020000000949949026
NATIVE_TIMESTEP = 0.008333333767950535


def fail(code: str) -> NoReturn:
    raise SystemExit(f"QSDK-R24D14 supervisor qualification audit: {code}")


def exact(value: Any, expected: Any, code: str) -> None:
    if type(value) is not type(expected) or value != expected:
        fail(code)


def mapping(value: Any, code: str) -> dict[str, Any]:
    if not isinstance(value, dict):
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


def validate_receipt(receipt: dict[str, Any]) -> None:
    exact(
        receipt.get("schema_version"),
        "sporespore_qsdk_r24d14_physical_supervisor_qualification_receipt_v1",
        "receipt_schema",
    )
    exact(receipt.get("ok"), True, "receipt_ok")
    exact(receipt.get("gate_id"), "QSDK-R24D14", "receipt_gate")
    exact(receipt.get("question_class"), "development", "receipt_question")
    exact(
        receipt.get("status"),
        "complete_physical_supervisor_preflight_passed_zero_world_only",
        "receipt_status",
    )
    source = mapping(receipt.get("source"), "receipt_source")
    for key in ("head", "upstream", "cached_origin_main", "live_origin_main"):
        exact(source.get(key), FREEZE, f"receipt_source_{key}")
    exact(source.get("worktree_clean"), True, "receipt_clean")
    exact(source.get("worktree_count"), 1, "receipt_worktrees")
    exact(
        mapping(receipt.get("validation_manifest"), "receipt_manifest").get(
            "raw_sha256"
        ),
        MANIFEST_SHA,
        "receipt_manifest_sha",
    )
    projection = mapping(
        receipt.get("prerequisite_native_projection_qualification"),
        "receipt_projection",
    )
    exact(
        mapping(projection.get("receipt"), "projection_receipt").get("raw_sha256"),
        PROJECTION_RECEIPT_SHA,
        "projection_receipt_sha",
    )
    exact(
        mapping(projection.get("closure"), "projection_closure").get("raw_sha256"),
        PROJECTION_CLOSURE_SHA,
        "projection_closure_sha",
    )
    exact(projection.get("cas_verified"), True, "projection_cas")
    exact(
        mapping(receipt.get("predecessor_physical_closure"), "predecessor").get(
            "raw_sha256"
        ),
        PREDECESSOR_SHA,
        "predecessor_sha",
    )
    binary = mapping(receipt.get("binary_pair"), "receipt_binary")
    exact(mapping(binary.get("console"), "console").get("raw_sha256"), CONSOLE_SHA, "console_sha")
    exact(mapping(binary.get("engine"), "engine").get("raw_sha256"), ENGINE_SHA, "engine_sha")
    exact(binary.get("executed_exact_qualified_pair"), True, "binary_executed")
    exact(binary.get("exact_cold_baseline_bytes_reused"), True, "binary_reused")
    exact(binary.get("campaign_result_reused"), False, "result_reuse")
    exact(binary.get("physical_evidence_reused"), False, "evidence_reuse")
    stages = receipt.get("stages")
    if not isinstance(stages, list):
        fail("receipt_stages")
    exact([mapping(v, "stage").get("name") for v in stages], EXPECTED_STAGES, "stage_order")
    exact([mapping(v, "stage").get("index") for v in stages], list(range(1, 8)), "stage_indices")
    worker = mapping(mapping(receipt.get("worker"), "worker").get("receipt"), "worker_receipt")
    exact(worker.get("source_commit"), FREEZE, "worker_source")
    exact(worker.get("active_physics_object_count"), 0.0, "worker_objects")
    exact(worker.get("native_serializer_path_exercised"), True, "worker_serializer")
    exact(worker.get("template_byte_passthrough"), False, "worker_passthrough")
    exact(worker.get("native_float32_inertia_readback_matches"), True, "worker_inertia_match")
    exact(worker.get("native_inertia_readback"), NATIVE_INERTIA, "worker_inertia")
    exact(worker.get("native_joint_rid_valid"), True, "worker_joint_rid")
    exact(worker.get("native_joint_allocation_count"), 1, "worker_joint_allocation")
    exact(worker.get("native_joint_release_call_count"), 1, "worker_joint_release")
    exact(worker.get("native_projection_matches"), True, "worker_projection")
    exact(worker.get("native_impulse_readback_nms"), NATIVE_IMPULSE, "worker_impulse")
    exact(
        worker.get("native_timestep_float32_projection_s"),
        NATIVE_TIMESTEP,
        "worker_timestep",
    )
    for key in ("world_attempt_count", "world_build_count", "solver_step_count"):
        exact(worker.get(key), 0, f"worker_{key}")
    exact(worker.get("synthetic_envelope_is_physical_observation"), False, "worker_synthetic")
    evaluation = mapping(receipt.get("evaluation"), "evaluation")
    exact(evaluation.get("result"), "synthetic_shape_conforms_zero_world_only", "evaluation_result")
    shape = mapping(receipt.get("native_serialization_shape"), "shape")
    exact(shape.get("serializer_path_exercised"), True, "shape_serializer")
    exact(shape.get("native_float32_inertia_readback_matches"), True, "shape_match")
    exact(shape.get("native_inertia_readback"), NATIVE_INERTIA, "shape_inertia")
    exact(shape.get("native_joint_rid_valid"), True, "shape_joint_rid")
    exact(shape.get("native_joint_allocation_count"), 1, "shape_joint_allocation")
    exact(shape.get("native_joint_release_call_count"), 1, "shape_joint_release")
    exact(shape.get("native_projection_matches"), True, "shape_projection")
    exact(shape.get("native_impulse_readback_nms"), NATIVE_IMPULSE, "shape_impulse")
    exact(shape.get("native_timestep_projection_s"), NATIVE_TIMESTEP, "shape_timestep")
    exact(shape.get("is_physical_observation"), False, "shape_physical")
    actual = mapping(receipt.get("actual_counts"), "actual")
    exact(actual.get("native_joint_allocation_count"), 1, "actual_joint_allocation")
    exact(actual.get("native_joint_release_call_count"), 1, "actual_joint_release")
    for key in (
        "active_physics_object_count",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
        "physical_world_count",
    ):
        exact(actual.get(key), 0, f"actual_{key}")
    claims = mapping(receipt.get("claims"), "receipt_claims")
    exact(claims.get("physical_supervisor_preflight_passed"), True, "receipt_preflight")
    exact(
        claims.get("native_projection_qualification_rechecked"),
        True,
        "receipt_projection_rechecked",
    )
    exact(claims.get("exact_runtime_reuse_key_passed"), True, "receipt_runtime")
    for key in (
        "physical_characterization_executed",
        "braking_mechanism_activated",
        "numerical_accuracy_accepted",
        "instrumented_profile_promoted",
        "stock_godot_profile_promoted",
        "recovery_world_opened",
        "prone_to_standing_world_opened",
        "q_sdk_r24_satisfied",
        "physical_authorization",
        "physical_acceptance_authority",
        "release_authority",
    ):
        exact(claims.get(key), False, f"receipt_claim_{key}")
    exact(receipt.get("development_preflight"), False, "receipt_development")
    exact(receipt.get("official_qualification"), True, "receipt_official")
    exact(receipt.get("same_source_preflight_rerun_allowed"), False, "receipt_rerun")


def validate_closure(closure: dict[str, Any]) -> None:
    exact(
        closure.get("schema_version"),
        "sporespore_qsdk_r24d14_physical_supervisor_qualification_positive_closure_v1",
        "closure_schema",
    )
    exact(closure.get("closure_id"), "QSDK-R24D14-PSQ1-CLOSURE", "closure_id")
    exact(closure.get("gate_id"), "QSDK-R24D14", "closure_gate")
    exact(closure.get("question_class"), "development", "closure_question")
    exact(
        closure.get("status"),
        "complete_physical_supervisor_preflight_passed_zero_world_only_authorization_separate",
        "closure_status",
    )
    exact(closure.get("supervisor_freeze_commit"), FREEZE, "closure_freeze")
    exact(closure.get("qualified_source_commit"), FREEZE, "closure_source")
    exact(closure.get("qualified_source_tree_git_oid"), FREEZE_TREE, "closure_tree")
    exact(closure.get("validation_manifest_raw_sha256"), MANIFEST_SHA, "closure_manifest")
    exact(closure.get("qualification_receipt_raw_sha256"), RECEIPT_SHA, "closure_receipt")
    exact(closure.get("qualification_receipt_byte_length"), RECEIPT_BYTES, "closure_receipt_bytes")
    exact(
        closure.get("prerequisite_native_projection_qualification_receipt_raw_sha256"),
        PROJECTION_RECEIPT_SHA,
        "closure_projection_receipt",
    )
    exact(
        closure.get("prerequisite_native_projection_qualification_closure_raw_sha256"),
        PROJECTION_CLOSURE_SHA,
        "closure_projection_closure",
    )
    exact(closure.get("predecessor_physical_closure_raw_sha256"), PREDECESSOR_SHA, "closure_predecessor")
    qualification = mapping(closure.get("qualification"), "closure_qualification")
    exact(Path(str(qualification.get("run_root"))), RUN_ROOT, "closure_run_root")
    exact(qualification.get("execution_nonce"), "ec92f7a9f79f41b8b57b236881b425b2", "closure_nonce")
    exact(qualification.get("receipt_cas_verified"), True, "closure_cas")
    exact(
        qualification.get("attempt_raw_sha256"),
        "sha256:54e3703860c0d452c0e7138356fe3a810167c4ecb9ee1db74bb124186cc51323",
        "closure_attempt_sha",
    )
    exact(qualification.get("attempt_byte_length"), 704, "closure_attempt_bytes")
    for key, expected in {
        "retained_file_count": 21,
        "retained_total_byte_length": 148649,
        "retained_unique_content_digest_count": 18,
        "embedded_cas_reference_count": 16,
        "embedded_unique_cas_digest_count": 14,
        "native_joint_allocation_count": 1,
        "native_joint_release_call_count": 1,
        "active_physics_object_count": 0,
        "physical_world_count": 0,
    }.items():
        exact(qualification.get(key), expected, f"closure_{key}")
    exact(qualification.get("ordered_stage_names"), EXPECTED_STAGES, "closure_stages")
    exact(closure.get("stage_count"), 7, "closure_stage_count")
    for key in ("world_attempt_count", "world_build_count", "solver_step_count"):
        exact(closure.get(key), 0, f"closure_{key}")
    shape = mapping(closure.get("native_serialization_shape"), "closure_shape")
    exact(shape.get("serializer_path_exercised"), True, "closure_serializer")
    exact(shape.get("template_byte_passthrough"), False, "closure_passthrough")
    exact(shape.get("native_inertia_readback"), NATIVE_INERTIA, "closure_inertia")
    exact(shape.get("native_joint_rid_valid"), True, "closure_joint_rid")
    exact(shape.get("native_joint_allocation_count"), 1, "closure_joint_allocation")
    exact(shape.get("native_joint_release_call_count"), 1, "closure_joint_release")
    exact(shape.get("native_projection_matches"), True, "closure_projection")
    exact(shape.get("native_impulse_readback_nms"), NATIVE_IMPULSE, "closure_impulse")
    exact(shape.get("native_timestep_projection_s"), NATIVE_TIMESTEP, "closure_timestep")
    exact(shape.get("is_physical_observation"), False, "closure_physical")
    exact(closure.get("executed_console_binary_raw_sha256"), CONSOLE_SHA, "closure_console")
    exact(closure.get("executed_engine_binary_raw_sha256"), ENGINE_SHA, "closure_engine")
    next_boundary = mapping(closure.get("next_boundary"), "closure_next")
    for key in (
        "separate_parent_bound_authorization_commit_required",
        "authorization_commit_must_be_direct_single_parent_child_of_qualified_source",
        "authorization_json_must_not_embed_its_own_commit_identity",
        "authorization_only_check_required_before_physical_attempt",
        "one_bounded_physical_attempt_may_be_authorized",
    ):
        exact(next_boundary.get(key), True, f"closure_next_{key}")
    exact(next_boundary.get("physical_execution_authorized_by_this_closure"), False, "closure_not_auth")
    claims = mapping(closure.get("claims"), "closure_claims")
    exact(claims.get("physical_supervisor_preflight_passed"), True, "closure_preflight")
    for key in claims:
        if key != "physical_supervisor_preflight_passed":
            exact(claims.get(key), False, f"closure_claim_{key}")


def validate_authorization(auth: dict[str, Any], closure_sha: str) -> None:
    exact(
        auth.get("schema_version"),
        "sporespore_qsdk_r24d14_physical_authorization_v1",
        "auth_schema",
    )
    exact(auth.get("authorization_id"), "QSDK-R24D14-PHYSICAL-AUTHORIZATION-V1", "auth_id")
    exact(auth.get("gate_id"), "QSDK-R24D14", "auth_gate")
    exact(auth.get("question_class"), "development", "auth_question")
    exact(auth.get("status"), "authorized_one_bounded_native_development_attempt_parent_bound", "auth_status")
    if "authorization_commit" in auth:
        fail("auth_self_commit")
    exact(auth.get("authorization_commit_derived_from_current_head"), True, "auth_derived")
    exact(auth.get("authorization_parent_commit"), FREEZE, "auth_parent")
    exact(auth.get("authorization_parent_tree_git_oid"), FREEZE_TREE, "auth_tree")
    exact(auth.get("supervisor_freeze_commit"), FREEZE, "auth_freeze")
    exact(auth.get("supervisor_manifest_raw_sha256"), MANIFEST_SHA, "auth_manifest")
    exact(auth.get("qualification_receipt_raw_sha256"), RECEIPT_SHA, "auth_receipt")
    exact(auth.get("qualification_receipt_byte_length"), RECEIPT_BYTES, "auth_receipt_bytes")
    exact(auth.get("qualification_closure_raw_sha256"), closure_sha, "auth_closure")
    exact(
        auth.get("prerequisite_native_projection_qualification_receipt_raw_sha256"),
        PROJECTION_RECEIPT_SHA,
        "auth_projection_receipt",
    )
    exact(
        auth.get("prerequisite_native_projection_qualification_closure_raw_sha256"),
        PROJECTION_CLOSURE_SHA,
        "auth_projection_closure",
    )
    exact(auth.get("prerequisite_predecessor_physical_closure_raw_sha256"), PREDECESSOR_SHA, "auth_predecessor")
    exact(auth.get("executed_console_binary_raw_sha256"), CONSOLE_SHA, "auth_console")
    exact(auth.get("executed_engine_binary_raw_sha256"), ENGINE_SHA, "auth_engine")
    for key, expected in {
        "physical_attempt_limit": 1,
        "world_count": 1,
        "fixture_cell_count": 4,
        "solver_step_count": 1,
        "retained_sample_count": 4,
        "threshold_count": 0,
        "margin_count": 0,
        "held_out_cohort_count": 0,
        "population_claim_count": 0,
    }.items():
        exact(auth.get(key), expected, f"auth_{key}")
    exact(auth.get("authorization_only_check_required_before_physical_attempt"), True, "auth_check")
    exact(auth.get("same_source_rerun_allowed"), False, "auth_rerun")
    exact(auth.get("physical_execution_authorized"), True, "auth_physical")
    for key in (
        "numerical_accuracy_accepted",
        "instrumented_profile_promoted",
        "physical_acceptance_authority",
        "release_authority",
    ):
        exact(auth.get(key), False, f"auth_{key}")


def verify_inventory(closure: dict[str, Any]) -> None:
    values = closure.get("retained_inventory")
    if not isinstance(values, list):
        fail("inventory_list")
    expected: dict[str, tuple[str, int]] = {}
    for value in values:
        item = mapping(value, "inventory_item")
        relative = str(item.get("path"))
        if relative in expected:
            fail(f"inventory_duplicate:{relative}")
        expected[relative] = (str(item.get("raw_sha256")), int(item.get("byte_length", -1)))
    actual = {
        path.relative_to(RUN_ROOT).as_posix(): raw_receipt(path)
        for path in sorted(value for value in RUN_ROOT.rglob("*") if value.is_file())
    }
    exact(actual, expected, "inventory_exact")
    exact(sum(length for _, length in actual.values()), 148649, "inventory_bytes")
    exact(len(set(actual.values())), 18, "inventory_unique")


def verify_frozen_source(closure: dict[str, Any]) -> None:
    exact(git_text("rev-parse", f"{FREEZE}^{{tree}}"), FREEZE_TREE, "git_tree")
    source = mapping(closure.get("source"), "closure_source_object")
    for prefix in ("physical_supervisor", "contract", "manifest", "source_audit"):
        relative = str(source.get(f"{prefix}_path"))
        payload = git_bytes("show", f"{FREEZE}:{relative}")
        exact(
            "sha256:" + hashlib.sha256(payload).hexdigest(),
            source.get(f"{prefix}_raw_sha256"),
            f"source_sha:{prefix}",
        )
        exact(len(payload), source.get(f"{prefix}_byte_length"), f"source_bytes:{prefix}")
        exact(
            git_text("rev-parse", f"{FREEZE}:{relative}"),
            source.get(f"{prefix}_git_blob_oid"),
            f"source_blob:{prefix}",
        )


def mutation_controls(closure: dict[str, Any], auth: dict[str, Any], closure_sha: str) -> int:
    closure_mutations: list[tuple[tuple[str, ...], Any]] = [
        (("question_class",), "finite_decision"),
        (("supervisor_freeze_commit",), "0" * 40),
        (("qualification_receipt_raw_sha256",), PROJECTION_RECEIPT_SHA),
        (("prerequisite_native_projection_qualification_receipt_raw_sha256",), RECEIPT_SHA),
        (("prerequisite_native_projection_qualification_closure_raw_sha256",), RECEIPT_SHA),
        (("predecessor_physical_closure_raw_sha256",), PROJECTION_CLOSURE_SHA),
        (("qualification", "retained_file_count"), 20),
        (("qualification", "embedded_cas_reference_count"), 15),
        (("qualification", "native_joint_allocation_count"), 0),
        (("native_serialization_shape", "serializer_path_exercised"), False),
        (("native_serialization_shape", "template_byte_passthrough"), True),
        (("native_serialization_shape", "native_projection_matches"), False),
        (("stage_count",), 6),
        (("world_attempt_count",), 1),
        (("next_boundary", "physical_execution_authorized_by_this_closure"), True),
        (("claims", "release_authority"), True),
    ]
    auth_mutations: list[tuple[tuple[str, ...], Any]] = [
        (("question_class",), "finite_decision"),
        (("authorization_parent_commit",), "0" * 40),
        (("qualification_receipt_raw_sha256",), PROJECTION_RECEIPT_SHA),
        (("qualification_closure_raw_sha256",), RECEIPT_SHA),
        (("prerequisite_native_projection_qualification_receipt_raw_sha256",), RECEIPT_SHA),
        (("prerequisite_native_projection_qualification_closure_raw_sha256",), RECEIPT_SHA),
        (("prerequisite_predecessor_physical_closure_raw_sha256",), PROJECTION_CLOSURE_SHA),
        (("physical_attempt_limit",), 2),
        (("same_source_rerun_allowed",), True),
        (("world_count",), 2),
        (("fixture_cell_count",), 3),
        (("solver_step_count",), 2),
        (("threshold_count",), 1),
        (("physical_execution_authorized",), False),
        (("physical_acceptance_authority",), True),
        (("release_authority",), True),
    ]
    rejected = 0
    for path, replacement in closure_mutations:
        candidate = copy.deepcopy(closure)
        target = candidate
        for key in path[:-1]:
            target = mapping(target[key], "closure_mutation_path")
        target[path[-1]] = replacement
        try:
            validate_closure(candidate)
        except SystemExit:
            rejected += 1
        else:
            fail(f"closure_mutation_accepted:{'.'.join(path)}")
    for path, replacement in auth_mutations:
        candidate = copy.deepcopy(auth)
        target = candidate
        for key in path[:-1]:
            target = mapping(target[key], "auth_mutation_path")
        target[path[-1]] = replacement
        try:
            validate_authorization(candidate, closure_sha)
        except SystemExit:
            rejected += 1
        else:
            fail(f"auth_mutation_accepted:{'.'.join(path)}")
    return rejected


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--allow-prospective-uncommitted", action="store_true")
    args = parser.parse_args()

    exact(Path(git_text("rev-parse", "--show-toplevel")).resolve(), ROOT.resolve(), "root")
    exact(
        git_text("remote", "get-url", "origin"),
        "https://github.com/Slagathore/sporespore.git",
        "remote",
    )
    receipt_path = RUN_ROOT / "receipt.json"
    exact(raw_receipt(receipt_path), (RECEIPT_SHA, RECEIPT_BYTES), "receipt_file")
    receipt = load_json(receipt_path, "receipt_json")
    closure = load_json(ROOT / CLOSURE_REL, "closure_json")
    auth = load_json(ROOT / AUTH_REL, "authorization_json")
    closure_sha, _ = raw_receipt(ROOT / CLOSURE_REL)
    validate_receipt(receipt)
    validate_closure(closure)
    validate_authorization(auth, closure_sha)
    verify_inventory(closure)
    verify_frozen_source(closure)

    cas_receipts: list[tuple[str, int]] = []
    collect_cas(receipt, cas_receipts)
    exact(len(cas_receipts), 16, "cas_reference_count")
    unique_cas = sorted(set(cas_receipts))
    exact(len(unique_cas), 14, "cas_unique_count")
    for index, (sha, length) in enumerate(unique_cas):
        verify_cas(sha, length, f"embedded_cas_{index}")
    verify_cas(RECEIPT_SHA, RECEIPT_BYTES, "qualification_receipt_cas")

    head = git_text("rev-parse", "HEAD")
    if args.allow_prospective_uncommitted:
        exact(head, FREEZE, "prospective_head")
    else:
        parents = git_text("rev-list", "--parents", "-n", "1", head).split()
        exact(len(parents), 2, "authorization_parent_count")
        exact(parents[1], FREEZE, "authorization_parent")
        exact(git_text("status", "--short"), "", "worktree_clean")
        for relative in (CLOSURE_REL, AUTH_REL, AUDIT_REL):
            exact(
                git_text("hash-object", relative),
                git_text("rev-parse", f"{head}:{relative}"),
                f"committed:{relative}",
            )
        for relative in (SUPERVISOR_REL, MANIFEST_REL):
            exact(
                git_text("rev-parse", f"{FREEZE}:{relative}"),
                git_text("rev-parse", f"{head}:{relative}"),
                f"parent_edge:{relative}",
            )

    rejected = mutation_controls(closure, auth, closure_sha)
    print(
        "QSDK_R24D14_PHYSICAL_SUPERVISOR_QUALIFICATION_PASS "
        f"mutations={rejected} run_files=21 unique_digests=18 "
        "cas_references=16 unique_cas=14 worlds=0 builds=0 solver_steps=0 "
        "physical_authority=false"
    )


if __name__ == "__main__":
    main()
