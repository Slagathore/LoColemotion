#!/usr/bin/env python3
"""Audit the immutable R24D10 v1 qualification and adoption refusal.

This audit reads retained evidence and exact Git objects only. It never invokes
the supervisor, launches Godot, creates an attempt, or constructs physics.
"""

from __future__ import annotations

import copy
import hashlib
import json
import subprocess
from pathlib import Path
from typing import Any, NoReturn


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE_ROOT = Path(r"C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence")
RECORD_REL = (
    "sdk/recovery/"
    "r24d10_first_physical_supervisor_qualification_adoption_refusal_v1.json"
)
SOURCE = "be6365cea71351519c796cefa4ec3900eed77539"
TREE = "1746beeb01e7087794c679c11d9bc8d3a49b4660"
PARENT = "4953b71b8bfc2baaff308b4645fe443a6b598d49"
RUN_ROOT = EVIDENCE_ROOT / (
    "qsdk-r24d10-exact-step-numerical-telemetry/"
    "physical-supervisor-qualification/"
    "20260826T195806966Z-be6365ce-e437bcbc373d"
)
RECEIPT_SHA = (
    "sha256:fd380507caa22c5bb15c4e98a9235e5528436f92148603534ff6c8bea2925119"
)
ATTEMPT_SHA = (
    "sha256:77c1d65988111a2db1ef5c2e56d6fa6358dbfa760cc9e5c170432611c22b5c85"
)
MANIFEST_SHA = (
    "sha256:a2923dfff2bdf7418d0fa2cab0152bdc92ec399c5f300b87d7de0d812867063b"
)
CONSOLE_SHA = (
    "sha256:ff655a567d31f51628d5b21742a0618e53f9fbf8a94937dd07d9882a0739872f"
)
ENGINE_SHA = (
    "sha256:2d68ed7ae53704ffb532cd5633241c74d599d69e3bf1968de0ef261553030ffb"
)
SUPERVISOR_REL = (
    "sdk/run_qsdk_r24d10_exact_step_numerical_telemetry_characterization.ps1"
)
CONTRACT_REL = (
    "sdk/recovery/r24d10_godot_jolt_exact_step_numerical_telemetry_"
    "physical_supervisor_contract_v1.json"
)
MANIFEST_REL = (
    "sdk/recovery/r24d10_godot_jolt_exact_step_numerical_telemetry_"
    "physical_supervisor_manifest_v1.json"
)
SOURCE_AUDIT_REL = (
    "tests/test_qsdk_r24d10_exact_step_numerical_telemetry_"
    "physical_supervisor_source.py"
)
AUTHORIZATION_REL = (
    "sdk/recovery/r24d10_godot_jolt_exact_step_numerical_telemetry_"
    "physical_authorization_v1.json"
)
ORDERED_STAGES = [
    "immutable_r24d10_zero_world_closure_recheck",
    "r24d10_physical_supervisor_source_audit",
    "r24d10_evaluator_self_test",
    "evaluator_shaped_zero_world_template",
    "production_worker_zero_object_route",
    "production_evaluator_zero_world_route",
]


def fail(code: str) -> NoReturn:
    raise SystemExit(f"QSDK-R24D10 v1 qualification adoption refusal: {code}")


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
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        fail(f"json:{path}:{exc}")
    return mapping(value, f"json_object:{path}")


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


def raw_receipt(path: Path) -> tuple[str, int]:
    try:
        payload = path.read_bytes()
    except OSError as exc:
        fail(f"file:{path}:{exc}")
    return "sha256:" + hashlib.sha256(payload).hexdigest(), len(payload)


def git_bytes(commit: str, relative: str) -> bytes:
    run = subprocess.run(
        ["git", "-C", str(ROOT), "show", f"{commit}:{relative}"],
        check=False,
        capture_output=True,
    )
    if run.returncode != 0:
        fail(f"git_show:{commit}:{relative}:{run.stderr.decode(errors='replace')}")
    return run.stdout


def find_cas_receipts(node: Any) -> list[dict[str, Any]]:
    found: list[dict[str, Any]] = []
    if isinstance(node, dict):
        if node.get("schema_version") == (
            "sporespore_content_addressed_artifact_receipt_v1"
        ):
            found.append(node)
        for value in node.values():
            found.extend(find_cas_receipts(value))
    elif isinstance(node, list):
        for value in node:
            found.extend(find_cas_receipts(value))
    return found


def validate_record(record: dict[str, Any]) -> None:
    exact(
        record.get("schema_version"),
        "sporespore_qsdk_r24d10_first_physical_supervisor_"
        "qualification_adoption_refusal_v1",
        "schema",
    )
    exact(record.get("closure_id"), "QSDK-R24D10-PSQ1-ADOPTION-REFUSAL", "id")
    exact(record.get("gate_id"), "QSDK-R24D10", "gate")
    exact(record.get("question_class"), "development", "question_class")
    exact(
        record.get("status"),
        "physical_supervisor_v1_preflight_passed_zero_world_only_"
        "adoption_refused_self_referential_authorization_transition",
        "status",
    )
    source = mapping(record.get("source"), "source")
    exact(source.get("commit"), SOURCE, "source_commit")
    exact(source.get("tree_git_oid"), TREE, "source_tree")
    exact(source.get("parent_commit"), PARENT, "source_parent")
    exact(source.get("clean_pushed_before_qualification"), True, "source_clean")
    exact(
        source.get("local_upstream_cached_live_equal_before_qualification"),
        True,
        "source_equal",
    )
    exact(source.get("physical_supervisor_path"), SUPERVISOR_REL, "supervisor_path")
    exact(
        source.get("physical_supervisor_raw_sha256"),
        "sha256:943a5b1e29628841dc482fcde7a82fbe4bd4d335495d6174f19eb257004a016e",
        "supervisor_sha",
    )
    exact(source.get("physical_supervisor_byte_length"), 63607, "supervisor_bytes")
    exact(
        source.get("physical_supervisor_git_blob_oid"),
        "4f816098f3b86bb914ddba89b93d0560f4b29aa4",
        "supervisor_blob",
    )
    exact(source.get("contract_path"), CONTRACT_REL, "contract_path")
    exact(source.get("manifest_path"), MANIFEST_REL, "manifest_path")
    exact(source.get("manifest_raw_sha256"), MANIFEST_SHA, "manifest_sha")
    exact(source.get("source_audit_path"), SOURCE_AUDIT_REL, "source_audit_path")

    qualification = mapping(record.get("qualification"), "qualification")
    exact(qualification.get("run_root"), RUN_ROOT.as_posix(), "run_root")
    exact(
        qualification.get("execution_nonce"),
        "e437bcbc373d4018ae749a07fa50d585",
        "nonce",
    )
    exact(qualification.get("receipt_raw_sha256"), RECEIPT_SHA, "receipt_sha")
    exact(qualification.get("receipt_byte_length"), 90240, "receipt_bytes")
    exact(qualification.get("receipt_cas_verified"), True, "receipt_cas")
    exact(qualification.get("attempt_raw_sha256"), ATTEMPT_SHA, "attempt_sha")
    exact(qualification.get("attempt_byte_length"), 668, "attempt_bytes")
    exact(qualification.get("validation_manifest_raw_sha256"), MANIFEST_SHA, "q_manifest")
    exact(qualification.get("stage_count"), 6, "stage_count")
    exact(qualification.get("ordered_stage_names"), ORDERED_STAGES, "stage_names")
    exact(qualification.get("executed_console_binary_raw_sha256"), CONSOLE_SHA, "console")
    exact(qualification.get("executed_engine_binary_raw_sha256"), ENGINE_SHA, "engine")
    for key, expected in {
        "retained_file_count": 20,
        "retained_total_byte_length": 526594,
        "retained_unique_content_digest_count": 16,
        "embedded_cas_reference_count": 13,
        "embedded_unique_cas_digest_count": 10,
        "active_physics_object_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physical_world_count": 0,
    }.items():
        exact(qualification.get(key), expected, f"qualification_{key}")
    exact(
        qualification.get("result"),
        "complete_physical_supervisor_preflight_passed_zero_world_only",
        "qualification_result",
    )
    exact(
        qualification.get("qualification_is_valid_for_exact_v1_source"),
        True,
        "qualification_valid",
    )
    exact(
        qualification.get("qualification_is_physical_authority"),
        False,
        "qualification_authority",
    )
    exact(
        qualification.get("qualification_is_adoptable_by_v1_transition"),
        False,
        "qualification_adoptable",
    )

    inventory = sequence(record.get("retained_inventory"), "inventory")
    exact(len(inventory), 20, "inventory_count")
    if len(str(record.get("scope", ""))) < 250:
        fail("scope")

    refusal = mapping(record.get("adoption_refusal"), "refusal")
    exact(
        refusal.get("decision"),
        "refused_before_authorization_and_before_physics",
        "refusal_decision",
    )
    exact(
        refusal.get("failure_class"),
        "prospective_integration_authorization_transition_invalid",
        "failure_class",
    )
    if len(str(refusal.get("invalidity_argument", ""))) < 400:
        fail("invalidity_argument")
    for key in (
        "authorization_file_created",
        "authorization_commit_created",
        "physical_mode_invoked",
        "physical_attempt_consumed",
        "world_opened",
        "v1_qualification_may_be_reinterpreted_as_v2_qualification",
        "v1_qualification_may_be_used_to_open_physics",
    ):
        exact(refusal.get(key), False, f"refusal_{key}")

    successor = mapping(record.get("successor_boundary"), "successor")
    for key in (
        "distinct_v2_supervisor_required",
        "complete_v2_zero_world_preflight_required",
        "separate_v2_authorization_commit_required",
    ):
        exact(successor.get(key), True, f"successor_{key}")
    exact(successor.get("physical_execution_authorized"), False, "successor_auth")
    if len(str(successor.get("v2_rule", ""))) < 250:
        fail("successor_rule")

    claims = mapping(record.get("claims"), "claims")
    exact(claims.get("v1_physical_supervisor_preflight_passed"), True, "claim_pass")
    exact(claims.get("v1_adoption_refused"), True, "claim_refused")
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


def validate_source_freeze(record: dict[str, Any]) -> None:
    exact(git_text("rev-parse", f"{SOURCE}^{{tree}}"), TREE, "git_tree")
    exact(git_text("rev-parse", f"{SOURCE}^"), PARENT, "git_parent")
    source = mapping(record["source"], "source")
    frozen = {
        SUPERVISOR_REL: (
            str(source["physical_supervisor_raw_sha256"]),
            int(source["physical_supervisor_byte_length"]),
            str(source["physical_supervisor_git_blob_oid"]),
        ),
        CONTRACT_REL: (str(source["contract_raw_sha256"]), None, None),
        MANIFEST_REL: (str(source["manifest_raw_sha256"]), None, None),
        SOURCE_AUDIT_REL: (str(source["source_audit_raw_sha256"]), None, None),
    }
    payloads: dict[str, bytes] = {}
    for relative, (expected_sha, expected_bytes, expected_blob) in frozen.items():
        payload = git_bytes(SOURCE, relative)
        payloads[relative] = payload
        exact("sha256:" + hashlib.sha256(payload).hexdigest(), expected_sha, f"git_sha:{relative}")
        if expected_bytes is not None:
            exact(len(payload), expected_bytes, f"git_bytes:{relative}")
        if expected_blob is not None:
            exact(git_text("rev-parse", f"{SOURCE}:{relative}"), expected_blob, f"git_blob:{relative}")

    contract = mapping(json.loads(payloads[CONTRACT_REL]), "contract")
    exact(
        contract.get("schema_version"),
        "sporespore_qsdk_r24d10_physical_supervisor_contract_v1",
        "contract_schema",
    )
    exact(
        mapping(contract.get("authority_chain"), "authority_chain").get(
            "physical_authorization_exists"
        ),
        False,
        "contract_authorization",
    )
    manifest = mapping(json.loads(payloads[MANIFEST_REL]), "manifest")
    exact(
        manifest.get("schema_version"),
        "sporespore_qsdk_r24d10_physical_supervisor_manifest_v1",
        "manifest_schema",
    )
    exact(manifest.get("source_binding_count"), 17, "manifest_bindings")
    exact(manifest.get("physical_authorization"), False, "manifest_authorization")

    supervisor = payloads[SUPERVISOR_REL].decode("utf-8")
    for token in (
        '[string]$authorization.authorization_commit -ceq $Head',
        '"physical_authorization_v1.json"',
        "Assert-R24D10PhysicalAuthorization",
        "Assert-R24D10SupervisorRepositoryBoundary",
    ):
        if token not in supervisor:
            fail(f"v1_rule_token:{token}")
    absent = git("cat-file", "-e", f"{SOURCE}:{AUTHORIZATION_REL}", check=False)
    if absent.returncode == 0:
        fail("v1_authorization_unexpectedly_present")


def validate_retained_evidence(record: dict[str, Any]) -> None:
    inventory = sequence(record["retained_inventory"], "inventory")
    declared: dict[str, tuple[str, int]] = {}
    for item_value in inventory:
        item = mapping(item_value, "inventory_item")
        relative = str(item.get("path"))
        if relative in declared or relative.startswith(('/', '\\')) or ".." in Path(relative).parts:
            fail(f"inventory_path:{relative}")
        declared[relative] = (str(item.get("raw_sha256")), int(item.get("byte_length")))
    actual_paths = sorted(
        path.relative_to(RUN_ROOT).as_posix()
        for path in RUN_ROOT.rglob("*")
        if path.is_file()
    )
    exact(sorted(declared), actual_paths, "inventory_population")
    actual_digests: set[str] = set()
    total_bytes = 0
    for relative in actual_paths:
        sha, length = raw_receipt(RUN_ROOT / relative)
        exact((sha, length), declared[relative], f"inventory_receipt:{relative}")
        actual_digests.add(sha)
        total_bytes += length
    exact(len(actual_paths), 20, "run_file_count")
    exact(len(actual_digests), 16, "run_unique_digests")
    exact(total_bytes, 526594, "run_total_bytes")

    receipt_path = RUN_ROOT / "receipt.json"
    attempt_path = RUN_ROOT / "attempt.json"
    exact(raw_receipt(receipt_path), (RECEIPT_SHA, 90240), "receipt_file")
    exact(raw_receipt(attempt_path), (ATTEMPT_SHA, 668), "attempt_file")
    receipt = load_json(receipt_path)
    attempt = load_json(attempt_path)
    exact(
        receipt.get("schema_version"),
        "sporespore_qsdk_r24d10_physical_supervisor_qualification_receipt_v1",
        "receipt_schema",
    )
    exact(receipt.get("ok"), True, "receipt_ok")
    exact(receipt.get("question_class"), "development", "receipt_question")
    exact(
        receipt.get("status"),
        "complete_physical_supervisor_preflight_passed_zero_world_only",
        "receipt_status",
    )
    source = mapping(receipt.get("source"), "receipt_source")
    for key in ("head", "upstream", "cached_origin_main", "live_origin_main"):
        exact(source.get(key), SOURCE, f"receipt_source_{key}")
    exact(source.get("worktree_count"), 1, "receipt_worktree_count")
    exact(source.get("worktree_clean"), True, "receipt_worktree_clean")
    exact(
        mapping(receipt.get("validation_manifest"), "receipt_manifest").get(
            "raw_sha256"
        ),
        MANIFEST_SHA,
        "receipt_manifest_sha",
    )
    binary = mapping(receipt.get("binary_pair"), "receipt_binary")
    exact(mapping(binary.get("console"), "receipt_console").get("raw_sha256"), CONSOLE_SHA, "receipt_console_sha")
    exact(mapping(binary.get("engine"), "receipt_engine").get("raw_sha256"), ENGINE_SHA, "receipt_engine_sha")
    exact(binary.get("executed_retained_pair"), True, "receipt_pair_executed")
    stages = sequence(receipt.get("stages"), "receipt_stages")
    exact([mapping(item, "stage").get("name") for item in stages], ORDERED_STAGES, "receipt_stage_names")
    counts = mapping(receipt.get("actual_counts"), "receipt_counts")
    exact(
        counts,
        {
            "active_physics_object_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physical_world_count": 0,
        },
        "receipt_counts_exact",
    )
    claims = mapping(receipt.get("claims"), "receipt_claims")
    exact(claims.get("physical_supervisor_preflight_passed"), True, "receipt_claim_pass")
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
        "sporespore_qsdk_r24d10_physical_supervisor_preflight_attempt_v1",
        "attempt_schema",
    )
    exact(attempt.get("status"), "complete_preflight_passed_zero_world_only", "attempt_status")
    exact(attempt.get("source_commit"), SOURCE, "attempt_source")
    exact(attempt.get("qualification_attempt_count"), 1, "attempt_count")
    for key in ("world_attempt_count", "world_build_count", "solver_step_count"):
        exact(attempt.get(key), 0, f"attempt_{key}")
    exact(attempt.get("same_source_rerun_allowed"), False, "attempt_rerun")

    cas_receipts = find_cas_receipts(receipt)
    exact(len(cas_receipts), 13, "cas_reference_count")
    unique_cas = {str(item.get("sha256")) for item in cas_receipts}
    exact(len(unique_cas), 10, "cas_unique_count")
    for item in cas_receipts:
        digest_value = str(item.get("sha256"))
        if not digest_value.startswith("sha256:") or len(digest_value) != 71:
            fail("cas_digest_shape")
        digest = digest_value[7:]
        expected_length = int(item.get("byte_length"))
        payload = EVIDENCE_ROOT / "artifacts" / "sha256" / digest / "payload.bin"
        manifest = EVIDENCE_ROOT / "artifacts" / "sha256" / digest / "manifest.json"
        exact(raw_receipt(payload), (digest_value, expected_length), f"cas_payload:{digest}")
        if not manifest.is_file():
            fail(f"cas_manifest:{digest}")
    receipt_digest = RECEIPT_SHA[7:]
    receipt_cas = EVIDENCE_ROOT / "artifacts" / "sha256" / receipt_digest / "payload.bin"
    exact(raw_receipt(receipt_cas), (RECEIPT_SHA, 90240), "receipt_cas_payload")


def mutation_controls(record: dict[str, Any]) -> int:
    mutations: list[tuple[tuple[str, ...], Any]] = [
        (("schema_version",), "sporespore_qsdk_r24d10_refusal_v2"),
        (("source", "commit"), PARENT),
        (("qualification", "receipt_raw_sha256"), ATTEMPT_SHA),
        (("qualification", "stage_count"), 5),
        (("qualification", "world_attempt_count"), 1),
        (("qualification", "qualification_is_adoptable_by_v1_transition"), True),
        (("adoption_refusal", "decision"), "adopted"),
        (("adoption_refusal", "authorization_commit_created"), True),
        (("adoption_refusal", "physical_mode_invoked"), True),
        (("adoption_refusal", "v1_qualification_may_be_reinterpreted_as_v2_qualification"), True),
        (("successor_boundary", "distinct_v2_supervisor_required"), False),
        (("claims", "release_authority"), True),
    ]
    rejected = 0
    for path, replacement in mutations:
        candidate = copy.deepcopy(record)
        target: dict[str, Any] = candidate
        for key in path[:-1]:
            target = mapping(target[key], "mutation_path")
        target[path[-1]] = replacement
        try:
            validate_record(candidate)
        except SystemExit:
            rejected += 1
        else:
            fail(f"mutation_accepted:{'.'.join(path)}")
    return rejected


def main() -> None:
    exact(Path(git_text("rev-parse", "--show-toplevel")).resolve(), ROOT.resolve(), "root")
    exact(
        git_text("remote", "get-url", "origin"),
        "https://github.com/Slagathore/sporespore.git",
        "remote",
    )
    record = load_json(ROOT / RECORD_REL)
    validate_record(record)
    validate_source_freeze(record)
    validate_retained_evidence(record)
    rejected = mutation_controls(record)
    print(
        "QSDK_R24D10_FIRST_PHYSICAL_SUPERVISOR_QUALIFICATION_ADOPTION_REFUSAL_PASS "
        f"stages=6 files=20 unique_digests=16 cas_refs=13 "
        f"cas_unique=10 mutations={rejected} worlds=0 builds=0 solver_steps=0 "
        "physical_authority=false"
    )


if __name__ == "__main__":
    main()
