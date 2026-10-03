#!/usr/bin/env python3
"""Audit the R24D10 v2 zero-world qualification and parent-bound authorization.

This audit reads exact Git objects and retained evidence. It never invokes the
production supervisor, launches Godot, creates an attempt, or constructs a
physics world.
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
EVIDENCE_ROOT = Path(r"C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence")
SOURCE = "b2bccdb76041a46a5d51ba56129f014e6c0dbf95"
SOURCE_TREE = "3e19ff30cb1a07dbee60f32fe35b8e6f6ac0050d"
SOURCE_PARENT = "5fa2754dd7f1f50d97a3d6ea2bfb5685192abc8c"
RUN_ROOT = EVIDENCE_ROOT / (
    "qsdk-r24d10-exact-step-numerical-telemetry/"
    "physical-supervisor-qualification/"
    "20260826T203447143Z-b2bccdb7-a2955f32da4a"
)
CLOSURE_REL = (
    "sdk/recovery/r24d10_godot_jolt_exact_step_numerical_telemetry_"
    "physical_supervisor_qualification_positive_closure_v2.json"
)
AUTHORIZATION_REL = (
    "sdk/recovery/r24d10_godot_jolt_exact_step_numerical_telemetry_"
    "physical_authorization_v2.json"
)
AUDIT_REL = (
    "tests/test_qsdk_r24d10_physical_supervisor_qualification_"
    "positive_closure_v2.py"
)
SUPERVISOR_REL = (
    "sdk/run_qsdk_r24d10_exact_step_numerical_telemetry_characterization.ps1"
)
CONTRACT_REL = (
    "sdk/recovery/r24d10_godot_jolt_exact_step_numerical_telemetry_"
    "physical_supervisor_contract_v2.json"
)
MANIFEST_REL = (
    "sdk/recovery/r24d10_godot_jolt_exact_step_numerical_telemetry_"
    "physical_supervisor_manifest_v2.json"
)
SOURCE_AUDIT_REL = (
    "tests/test_qsdk_r24d10_exact_step_numerical_telemetry_"
    "physical_supervisor_source_v2.py"
)
CLOSURE_SHA = (
    "sha256:2eff43d9c960c64a7a889874711de4af89baea066e774ea278f17a0375752a58"
)
AUTHORIZATION_SHA = (
    "sha256:c228c020c3ec42f246a9676f0cdecc29742f2b69b595cbd756c13ac106e3b059"
)
RECEIPT_SHA = (
    "sha256:a260a3c1a883487e5615fd1de82d8d6b05a5deefbf484bf82e266b4a73412cd7"
)
ATTEMPT_SHA = (
    "sha256:1595cb36f98656c6c9594c02185047d6bedb9251819b022314d4b79f5ab959f7"
)
MANIFEST_SHA = (
    "sha256:6684a37ba78f68818cc35c23240d6f66ebcf0bb592aed6041e82f632ec35210a"
)
ZERO_RECEIPT_SHA = (
    "sha256:093db061d3bb4799c4ac6a0a4c30364031297aee4b27608ef797cea05c6bb34f"
)
CONSOLE_SHA = (
    "sha256:ff655a567d31f51628d5b21742a0618e53f9fbf8a94937dd07d9882a0739872f"
)
ENGINE_SHA = (
    "sha256:2d68ed7ae53704ffb532cd5633241c74d599d69e3bf1968de0ef261553030ffb"
)
ORDERED_STAGES = [
    "immutable_r24d10_v1_adoption_refusal_recheck",
    "immutable_r24d10_zero_world_closure_recheck",
    "r24d10_physical_supervisor_source_audit",
    "r24d10_evaluator_self_test",
    "evaluator_shaped_zero_world_template",
    "production_worker_zero_object_route",
    "production_evaluator_zero_world_route",
]
FROZEN_SOURCE = {
    SUPERVISOR_REL: (
        "sha256:889ab73e34c9c4dfa4d24484f8d57e199ca665b137183e80dd390e40cb4de7ca",
        72353,
        "8b43ae7d8e52af481c6ede39010eeaa3d06b5a5a",
    ),
    CONTRACT_REL: (
        "sha256:7de3527d68fd0ee783d6320bca2a81faa392ca7be5d9a1d75cef72e9aca8648f",
        8920,
        "bd28e3090d89e82f2004205befcd6bb455e38201",
    ),
    MANIFEST_REL: (MANIFEST_SHA, 7132, "2375ee6064110fd05891a2d0a3450d5bbf0a6dfb"),
    SOURCE_AUDIT_REL: (
        "sha256:20b6a5b751726a916a0db93482e5ce4502bea6dba12c02dbe53fba39e61f7cf3",
        22666,
        "408d443b3474212224adaa6f1340734587a59639",
    ),
}


def fail(code: str) -> NoReturn:
    raise SystemExit(f"QSDK-R24D10 v2 qualification closure audit: {code}")


def exact(value: Any, expected: Any, code: str) -> None:
    if type(value) is not type(expected) or value != expected:
        fail(code)


def mapping(value: Any, code: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        fail(code)
    return value


def sequence(value: Any, code: str) -> list[Any]:
    if not isinstance(value, list):
        fail(code)
    return value


def load_json(path: Path) -> dict[str, Any]:
    try:
        return mapping(json.loads(path.read_text(encoding="utf-8")), f"json:{path}")
    except (OSError, json.JSONDecodeError) as exc:
        fail(f"json:{path}:{exc}")


def git(*arguments: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    run = subprocess.run(
        ["git", "-C", str(ROOT), *arguments],
        check=False,
        capture_output=True,
        text=True,
    )
    if check and run.returncode != 0:
        fail(f"git:{'_'.join(arguments)}:{run.stderr.strip()}")
    return run


def git_text(*arguments: str) -> str:
    return git(*arguments).stdout.strip()


def git_bytes(commit: str, relative: str) -> bytes:
    run = subprocess.run(
        ["git", "-C", str(ROOT), "show", f"{commit}:{relative}"],
        check=False,
        capture_output=True,
    )
    if run.returncode != 0:
        fail(f"git_show:{commit}:{relative}:{run.stderr.decode(errors='replace')}")
    return run.stdout


def raw_receipt(path: Path) -> tuple[str, int]:
    try:
        payload = path.read_bytes()
    except OSError as exc:
        fail(f"file:{path}:{exc}")
    return "sha256:" + hashlib.sha256(payload).hexdigest(), len(payload)


def find_cas_receipts(node: Any) -> list[dict[str, Any]]:
    found: list[dict[str, Any]] = []
    if isinstance(node, dict):
        if node.get("schema_version") == "sporespore_content_addressed_artifact_receipt_v1":
            found.append(node)
        for value in node.values():
            found.extend(find_cas_receipts(value))
    elif isinstance(node, list):
        for value in node:
            found.extend(find_cas_receipts(value))
    return found


def validate_closure(closure: dict[str, Any]) -> None:
    exact(
        closure.get("schema_version"),
        "sporespore_qsdk_r24d10_physical_supervisor_qualification_positive_closure_v2",
        "closure_schema",
    )
    exact(closure.get("closure_id"), "QSDK-R24D10-PSQ2-CLOSURE", "closure_id")
    exact(closure.get("gate_id"), "QSDK-R24D10", "closure_gate")
    exact(closure.get("question_class"), "development", "closure_question")
    exact(
        closure.get("status"),
        "complete_v2_physical_supervisor_preflight_passed_zero_world_only_"
        "authorization_separate",
        "closure_status",
    )
    if len(str(closure.get("scope", ""))) < 450:
        fail("closure_scope")
    exact(closure.get("qualified_source_commit"), SOURCE, "qualified_source")
    exact(closure.get("qualified_source_tree_git_oid"), SOURCE_TREE, "qualified_tree")
    exact(closure.get("qualified_source_parent_commit"), SOURCE_PARENT, "qualified_parent")
    exact(closure.get("validation_manifest_raw_sha256"), MANIFEST_SHA, "manifest_sha")
    exact(closure.get("qualification_receipt_raw_sha256"), RECEIPT_SHA, "receipt_sha")
    exact(closure.get("qualification_receipt_byte_length"), 91463, "receipt_bytes")
    exact(closure.get("executed_console_binary_raw_sha256"), CONSOLE_SHA, "console_sha")
    exact(closure.get("executed_engine_binary_raw_sha256"), ENGINE_SHA, "engine_sha")
    for key, expected in {
        "stage_count": 7,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
    }.items():
        exact(closure.get(key), expected, f"closure_{key}")

    source = mapping(closure.get("source"), "source")
    exact(source.get("repository_root"), ROOT.as_posix(), "source_root")
    exact(
        source.get("repository_remote"),
        "https://github.com/Slagathore/sporespore.git",
        "source_remote",
    )
    exact(source.get("branch"), "main", "source_branch")
    exact(source.get("clean_pushed_before_qualification"), True, "source_clean")
    exact(
        source.get("local_upstream_cached_live_equal_before_qualification"),
        True,
        "source_equal",
    )
    for relative, (sha, length, blob) in FROZEN_SOURCE.items():
        prefix = {
            SUPERVISOR_REL: "physical_supervisor",
            CONTRACT_REL: "contract",
            MANIFEST_REL: "manifest",
            SOURCE_AUDIT_REL: "source_audit",
        }[relative]
        exact(source.get(f"{prefix}_path"), relative, f"source_path:{prefix}")
        exact(source.get(f"{prefix}_raw_sha256"), sha, f"source_sha:{prefix}")
        exact(source.get(f"{prefix}_byte_length"), length, f"source_bytes:{prefix}")
        exact(source.get(f"{prefix}_git_blob_oid"), blob, f"source_blob:{prefix}")

    qualification = mapping(closure.get("qualification"), "qualification")
    exact(qualification.get("run_root"), RUN_ROOT.as_posix(), "run_root")
    exact(
        qualification.get("execution_nonce"),
        "a2955f32da4a48abb45d6898b36c3437",
        "nonce",
    )
    exact(qualification.get("receipt_cas_verified"), True, "receipt_cas")
    exact(qualification.get("attempt_raw_sha256"), ATTEMPT_SHA, "attempt_sha")
    exact(qualification.get("attempt_byte_length"), 668, "attempt_bytes")
    exact(qualification.get("ordered_stage_names"), ORDERED_STAGES, "stage_names")
    for key, expected in {
        "retained_file_count": 21,
        "retained_total_byte_length": 528177,
        "retained_unique_content_digest_count": 17,
        "embedded_cas_reference_count": 14,
        "embedded_unique_cas_digest_count": 11,
        "active_physics_object_count": 0,
        "physical_world_count": 0,
    }.items():
        exact(qualification.get(key), expected, f"qualification_{key}")
    exact(
        qualification.get("result"),
        "complete_physical_supervisor_preflight_passed_zero_world_only",
        "qualification_result",
    )
    exact(len(sequence(closure.get("retained_inventory"), "inventory")), 21, "inventory_count")

    boundary = mapping(closure.get("next_boundary"), "next_boundary")
    for key in (
        "separate_parent_bound_authorization_commit_required",
        "authorization_commit_must_be_direct_single_parent_child_of_qualified_source",
        "authorization_json_must_not_embed_its_own_commit_identity",
        "authorization_only_check_required_before_physical_attempt",
        "one_bounded_physical_attempt_may_be_authorized",
    ):
        exact(boundary.get(key), True, f"boundary_{key}")
    exact(
        boundary.get("physical_execution_authorized_by_this_closure"),
        False,
        "closure_not_authorization",
    )
    claims = mapping(closure.get("claims"), "claims")
    exact(claims.get("v2_physical_supervisor_preflight_passed"), True, "claim_preflight")
    for key in (
        "physical_authorization",
        "physical_characterization_executed",
        "native_numerical_telemetry_characterized",
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
        exact(claims.get(key), False, f"claim_{key}")


def validate_authorization(authorization: dict[str, Any]) -> None:
    exact(
        authorization.get("schema_version"),
        "sporespore_qsdk_r24d10_physical_authorization_v2",
        "authorization_schema",
    )
    exact(authorization.get("gate_id"), "QSDK-R24D10", "authorization_gate")
    exact(authorization.get("question_class"), "development", "authorization_question")
    exact(
        authorization.get("status"),
        "one_bounded_native_development_characterization_authorized",
        "authorization_status",
    )
    if "authorization_commit" in authorization:
        fail("authorization_self_identity")
    if len(str(authorization.get("scope", ""))) < 350:
        fail("authorization_scope")
    exact(
        authorization.get("authorization_commit_derived_from_current_head"),
        True,
        "authorization_derived_head",
    )
    exact(authorization.get("authorization_parent_commit"), SOURCE, "authorization_parent")
    exact(authorization.get("authorization_parent_tree_git_oid"), SOURCE_TREE, "authorization_tree")
    exact(
        authorization.get("supervisor_git_blob_oid"),
        FROZEN_SOURCE[SUPERVISOR_REL][2],
        "authorization_supervisor_blob",
    )
    exact(
        authorization.get("supervisor_manifest_git_blob_oid"),
        FROZEN_SOURCE[MANIFEST_REL][2],
        "authorization_manifest_blob",
    )
    exact(authorization.get("supervisor_manifest_raw_sha256"), MANIFEST_SHA, "authorization_manifest")
    exact(authorization.get("qualification_receipt_raw_sha256"), RECEIPT_SHA, "authorization_receipt")
    exact(authorization.get("qualification_receipt_byte_length"), 91463, "authorization_receipt_bytes")
    exact(authorization.get("qualification_closure_raw_sha256"), CLOSURE_SHA, "authorization_closure")
    exact(
        authorization.get("prerequisite_zero_world_receipt_raw_sha256"),
        ZERO_RECEIPT_SHA,
        "authorization_zero_receipt",
    )
    exact(authorization.get("executed_console_binary_raw_sha256"), CONSOLE_SHA, "authorization_console")
    exact(authorization.get("executed_engine_binary_raw_sha256"), ENGINE_SHA, "authorization_engine")
    for key, expected in {
        "physical_attempt_limit": 1,
        "world_count": 1,
        "fixture_cell_count": 9,
        "solver_step_count": 20,
        "retained_sample_count": 68,
        "threshold_count": 0,
        "margin_count": 0,
        "population_claim_count": 0,
    }.items():
        exact(authorization.get(key), expected, f"authorization_{key}")
    exact(authorization.get("authorization_only_check_required_before_physical_attempt"), True, "authorization_check")
    exact(authorization.get("same_source_rerun_allowed"), False, "authorization_rerun")
    exact(authorization.get("physical_execution_authorized"), True, "authorization_physical")
    for key in (
        "numerical_accuracy_accepted",
        "instrumented_profile_promoted",
        "physical_acceptance_authority",
        "release_authority",
    ):
        exact(authorization.get(key), False, f"authorization_{key}")


def validate_source_freeze() -> None:
    exact(git_text("rev-parse", f"{SOURCE}^{{tree}}"), SOURCE_TREE, "source_tree")
    exact(git_text("rev-parse", f"{SOURCE}^"), SOURCE_PARENT, "source_parent")
    payloads: dict[str, bytes] = {}
    for relative, (sha, length, blob) in FROZEN_SOURCE.items():
        payload = git_bytes(SOURCE, relative)
        payloads[relative] = payload
        exact("sha256:" + hashlib.sha256(payload).hexdigest(), sha, f"source_sha:{relative}")
        exact(len(payload), length, f"source_bytes:{relative}")
        exact(git_text("rev-parse", f"{SOURCE}:{relative}"), blob, f"source_blob:{relative}")
    contract = mapping(json.loads(payloads[CONTRACT_REL]), "contract")
    exact(
        contract.get("schema_version"),
        "sporespore_qsdk_r24d10_physical_supervisor_contract_v2",
        "contract_schema",
    )
    exact(
        mapping(contract.get("authority_chain"), "authority_chain").get(
            "physical_authorization_exists"
        ),
        False,
        "source_contract_authorization",
    )
    manifest = mapping(json.loads(payloads[MANIFEST_REL]), "manifest")
    exact(manifest.get("source_binding_count"), 19, "manifest_bindings")
    exact(manifest.get("declared_preflight_stage_count"), 7, "manifest_stages")
    exact(manifest.get("v2_preflight_passed"), False, "source_manifest_preflight")
    supervisor = payloads[SUPERVISOR_REL].decode("utf-8")
    for token in (
        '[ValidateSet("Preflight", "Authorization", "Physical")]',
        "QSDK_R24D10_PHYSICAL_AUTHORIZATION_CHECK_PASS",
        "authorization_commit_must_have_exactly_one_parent",
        '$parentBlob -ceq $currentBlob',
        '$parentManifestBlob -ceq $currentManifestBlob',
    ):
        if token not in supervisor:
            fail(f"supervisor_token:{token}")


def validate_retained_evidence(closure: dict[str, Any]) -> None:
    inventory = sequence(closure["retained_inventory"], "inventory")
    declared: dict[str, tuple[str, int]] = {}
    for item_value in inventory:
        item = mapping(item_value, "inventory_item")
        relative = str(item.get("path"))
        if relative in declared or relative.startswith(("/", "\\")) or ".." in Path(relative).parts:
            fail(f"inventory_path:{relative}")
        declared[relative] = (str(item.get("raw_sha256")), int(item.get("byte_length")))
    actual_paths = sorted(
        path.relative_to(RUN_ROOT).as_posix()
        for path in RUN_ROOT.rglob("*")
        if path.is_file()
    )
    exact(sorted(declared), actual_paths, "inventory_population")
    digests: set[str] = set()
    total_bytes = 0
    for relative in actual_paths:
        receipt = raw_receipt(RUN_ROOT / relative)
        exact(receipt, declared[relative], f"inventory_receipt:{relative}")
        digests.add(receipt[0])
        total_bytes += receipt[1]
    exact(len(actual_paths), 21, "file_count")
    exact(len(digests), 17, "unique_digests")
    exact(total_bytes, 528177, "total_bytes")

    receipt = load_json(RUN_ROOT / "receipt.json")
    attempt = load_json(RUN_ROOT / "attempt.json")
    exact(raw_receipt(RUN_ROOT / "receipt.json"), (RECEIPT_SHA, 91463), "receipt_file")
    exact(raw_receipt(RUN_ROOT / "attempt.json"), (ATTEMPT_SHA, 668), "attempt_file")
    exact(
        receipt.get("schema_version"),
        "sporespore_qsdk_r24d10_physical_supervisor_qualification_receipt_v2",
        "receipt_schema",
    )
    exact(receipt.get("ok"), True, "receipt_ok")
    source = mapping(receipt.get("source"), "receipt_source")
    for key in ("head", "upstream", "cached_origin_main", "live_origin_main"):
        exact(source.get(key), SOURCE, f"receipt_source_{key}")
    exact(source.get("worktree_count"), 1, "receipt_worktrees")
    exact(source.get("worktree_clean"), True, "receipt_clean")
    exact(
        mapping(receipt.get("validation_manifest"), "receipt_manifest").get("raw_sha256"),
        MANIFEST_SHA,
        "receipt_manifest_sha",
    )
    binary = mapping(receipt.get("binary_pair"), "binary_pair")
    exact(mapping(binary.get("console"), "console").get("raw_sha256"), CONSOLE_SHA, "receipt_console")
    exact(mapping(binary.get("engine"), "engine").get("raw_sha256"), ENGINE_SHA, "receipt_engine")
    exact(binary.get("executed_retained_pair"), True, "receipt_pair_executed")
    stages = sequence(receipt.get("stages"), "receipt_stages")
    exact([mapping(item, "stage").get("name") for item in stages], ORDERED_STAGES, "receipt_stages")
    exact(
        mapping(receipt.get("actual_counts"), "actual_counts"),
        {
            "active_physics_object_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physical_world_count": 0,
        },
        "receipt_counts",
    )
    claims = mapping(receipt.get("claims"), "receipt_claims")
    exact(claims.get("physical_supervisor_preflight_passed"), True, "receipt_preflight")
    for key in (
        "physical_characterization_executed",
        "native_numerical_telemetry_characterized",
        "physical_authorization",
        "physical_acceptance_authority",
        "release_authority",
    ):
        exact(claims.get(key), False, f"receipt_claim_{key}")
    exact(
        attempt.get("schema_version"),
        "sporespore_qsdk_r24d10_physical_supervisor_preflight_attempt_v2",
        "attempt_schema",
    )
    exact(attempt.get("status"), "complete_preflight_passed_zero_world_only", "attempt_status")
    exact(attempt.get("source_commit"), SOURCE, "attempt_source")
    exact(attempt.get("qualification_attempt_count"), 1, "attempt_count")
    for key in ("world_attempt_count", "world_build_count", "solver_step_count"):
        exact(attempt.get(key), 0, f"attempt_{key}")
    exact(attempt.get("same_source_rerun_allowed"), False, "attempt_rerun")

    cas_receipts = find_cas_receipts(receipt)
    exact(len(cas_receipts), 14, "cas_reference_count")
    exact(len({str(item.get("sha256")) for item in cas_receipts}), 11, "cas_unique_count")
    for item in cas_receipts:
        sha = str(item.get("sha256"))
        if not sha.startswith("sha256:") or len(sha) != 71:
            fail("cas_digest_shape")
        digest = sha[7:]
        length = int(item.get("byte_length"))
        payload = EVIDENCE_ROOT / "artifacts" / "sha256" / digest / "payload.bin"
        manifest = EVIDENCE_ROOT / "artifacts" / "sha256" / digest / "manifest.json"
        exact(raw_receipt(payload), (sha, length), f"cas_payload:{digest}")
        if not manifest.is_file():
            fail(f"cas_manifest:{digest}")
    receipt_cas = EVIDENCE_ROOT / "artifacts" / "sha256" / RECEIPT_SHA[7:] / "payload.bin"
    exact(raw_receipt(receipt_cas), (RECEIPT_SHA, 91463), "receipt_cas_payload")


def validate_transition(*, allow_prospective_uncommitted: bool) -> None:
    if allow_prospective_uncommitted:
        return
    head = git_text("rev-parse", "HEAD")
    parents = git_text("rev-list", "--parents", "-n", "1", head).split()
    exact(len(parents), 2, "transition_parent_count")
    exact(parents[0], head, "transition_head")
    exact(parents[1], SOURCE, "transition_parent")
    for relative in FROZEN_SOURCE:
        exact(
            git_text("rev-parse", f"{head}:{relative}"),
            git_text("rev-parse", f"{SOURCE}:{relative}"),
            f"transition_frozen_blob:{relative}",
        )
    for relative in (CLOSURE_REL, AUTHORIZATION_REL, AUDIT_REL):
        exact(
            git_text("rev-parse", f"{head}:{relative}"),
            git_text("hash-object", relative),
            f"transition_tracked:{relative}",
        )


def mutation_controls(closure: dict[str, Any], authorization: dict[str, Any]) -> int:
    mutations: list[tuple[str, tuple[str, ...], Any]] = [
        ("closure", ("question_class",), "finite_decision"),
        ("closure", ("qualified_source_commit",), SOURCE_PARENT),
        ("closure", ("qualification_receipt_raw_sha256",), ATTEMPT_SHA),
        ("closure", ("stage_count",), 6),
        ("closure", ("world_attempt_count",), 1),
        ("closure", ("next_boundary", "physical_execution_authorized_by_this_closure"), True),
        ("closure", ("claims", "physical_authorization"), True),
        ("closure", ("claims", "release_authority"), True),
        ("authorization", ("authorization_parent_commit",), SOURCE_PARENT),
        ("authorization", ("authorization_commit",), "self"),
        ("authorization", ("supervisor_git_blob_oid",), FROZEN_SOURCE[MANIFEST_REL][2]),
        ("authorization", ("qualification_receipt_raw_sha256",), ATTEMPT_SHA),
        ("authorization", ("qualification_closure_raw_sha256",), AUTHORIZATION_SHA),
        ("authorization", ("physical_attempt_limit",), 2),
        ("authorization", ("solver_step_count",), 21),
        ("authorization", ("same_source_rerun_allowed",), True),
        ("authorization", ("physical_execution_authorized",), False),
        ("authorization", ("release_authority",), True),
    ]
    rejected = 0
    for target_name, path, replacement in mutations:
        candidate = copy.deepcopy(closure if target_name == "closure" else authorization)
        target: dict[str, Any] = candidate
        for key in path[:-1]:
            target = mapping(target[key], "mutation_path")
        target[path[-1]] = replacement
        try:
            if target_name == "closure":
                validate_closure(candidate)
            else:
                validate_authorization(candidate)
        except SystemExit:
            rejected += 1
        else:
            fail(f"mutation_accepted:{target_name}:{'.'.join(path)}")
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
    exact(raw_receipt(ROOT / CLOSURE_REL), (CLOSURE_SHA, 9297), "closure_file")
    exact(raw_receipt(ROOT / AUTHORIZATION_REL), (AUTHORIZATION_SHA, 2804), "authorization_file")
    closure = load_json(ROOT / CLOSURE_REL)
    authorization = load_json(ROOT / AUTHORIZATION_REL)
    validate_closure(closure)
    validate_authorization(authorization)
    validate_source_freeze()
    validate_retained_evidence(closure)
    validate_transition(allow_prospective_uncommitted=args.allow_prospective_uncommitted)
    rejected = mutation_controls(closure, authorization)
    print(
        "QSDK_R24D10_PHYSICAL_SUPERVISOR_QUALIFICATION_POSITIVE_CLOSURE_V2_PASS "
        f"stages=7 files=21 unique_digests=17 cas_refs=14 cas_unique=11 "
        f"mutations={rejected} worlds=0 builds=0 solver_steps=0 "
        "authorization_declared=true physical_attempts=0 "
        "physical_acceptance_authority=false"
    )


if __name__ == "__main__":
    main()
