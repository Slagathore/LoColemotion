#!/usr/bin/env python3
"""Verify the immutable R24D16 zero-world qualification closure."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import subprocess
import sys
from pathlib import Path
from typing import Any, Callable


EXPECTED_ROOT = Path(r"C:\Users\Cole\CodeStuff\games\SporeSpore")
EXPECTED_EVIDENCE_ROOT = Path(r"C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence")
EXPECTED_REMOTE = "https://github.com/Slagathore/sporespore.git"
FREEZE_COMMIT = "4ed7ad937235296a4d940794548621a549c1fe6d"
FREEZE_TREE = "913e34f88f5a6a1f0326efb4d138bb4d73af79fc"
FREEZE_PARENT = "b8c5ec5919d9d890946262d923f79259a6c8662a"
CLOSURE_RELATIVE = Path(
    "sdk/recovery/"
    "r24d16_godot_jolt_profile_scoped_recovery_capability_"
    "qualification_closure_v1.json"
)
AUDIT_RELATIVE = Path(
    "tests/test_qsdk_r24d16_godot_jolt_profile_scoped_recovery_"
    "capability_qualification_closure.py"
)
RUN_RELATIVE = Path(
    "qsdk-r24d16-profile-scoped-recovery-capability/qualification/"
    "20260827T014757688Z-4ed7ad93-1405c8b1cd40"
)
RUN_ROOT = EXPECTED_EVIDENCE_ROOT / RUN_RELATIVE
EXPECTED_RECEIPT_SHA256 = (
    "3ba3ebc06873c13aa939da5543ce348147421675f568cf0c9b66efb36d4c9ed3"
)
EXPECTED_RECEIPT_BYTES = 15420
EXPECTED_SOURCE_BINDINGS = {
    "sdk/recovery/r24d16_godot_jolt_profile_scoped_recovery_capability_contract_v1.json": (
        "eb0393d70fafdf25fefbf9142af5b81b2fb6b6d5f5e5206f1387e27a497e206a",
        11553,
        "8483480c6d873aaa7c8243fdd1c98327eccc217a",
    ),
    "sdk/adapters/godot/gdscript/recovery_capability_instrumented_v2.gd": (
        "e6d1ee07f403db5b00fb2431846d9dc84e233a44e44b77a8bbea23aec0319d8a",
        12760,
        "d1a13c6c14a9ce5e5ae10ebc79572164cd2bd104",
    ),
    "sdk/adapters/godot/gdscript/recovery_capability.gd": (
        "4c341284bc4816b309ae7fc7b165dfb281d6df2decb51b1b03ceb991bbc5a8c2",
        8173,
        "3f249226830441ff37d23db9b6e9ed83577da65e",
    ),
    "sdk/recovery/r24d15_godot_jolt_instrumented_profile_promotion_decision_v1.json": (
        "ae5359f106732cecda253d6c346e9ac14703568883344982326597db79bd4aed",
        12491,
        "025a705a0034f10d9fc9f9a926dabdb4d15e4797",
    ),
    "tests/test_sdk_qsdk_r24d16_godot_profile_scoped_recovery_capability_zero_world.gd": (
        "7b8466ec4ada606ea4cad3dde649d70a3efe22a21b787764f4db8cc1184dd58b",
        11911,
        "ea6c42dfdb6188bdbc304ef6151dfc1abe482ed6",
    ),
    "tests/test_qsdk_r24d16_godot_jolt_profile_scoped_recovery_capability_source.py": (
        "7c3379f3413cc318d4a43c13d38c25bef3610095e43f540372f920ced7d8f8b9",
        21106,
        "343e8b9452b3337fcd624296581e96303f5251e2",
    ),
    "sdk/run_qsdk_r24d16_profile_scoped_recovery_capability_zero_world.ps1": (
        "4d377b68fba0cf003c39d1f94c8e465e266788b9b73549a54bc96901b56eca78",
        25423,
        "c4627b18f48101a95145dbe888ff1c5bda2a975c",
    ),
    "sdk/core/src/recovery.rs": (
        "b2385bb4737c63a3b0ab190200391c1e87a1cd6f4f3ce213250e5e2cdb72a12f",
        108580,
        "97d74b82a1e91bee0e8a6335eb1d4933623c8102",
    ),
    "sdk/adapters/godot/src/lib.rs": (
        "8676147cf8d4ed3560e81cc84279d09d5173535ae75d64d2d6854cc75d942ce1",
        36542,
        "c575b283246945bab1994da2298fdac5d3fecbb9",
    ),
    "sdk/adapters/godot/sporespore_locomotion.gdextension": (
        "971bb0b14afd094a46bffc042030a2974bd03f73b7c10d41d43acdb43b2f16d3",
        271,
        "b7515137235f6357fb366f35538c404128791a6d",
    ),
}
EXPECTED_ARTIFACTS = {
    "01-source-audit.stderr.log": ("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", 0),
    "01-source-audit.stdout.log": ("1455c78d6003a7fcdb583f3836602f4be2b15e9aac959f6146c1c097a5f96f3e", 272),
    "02-cargo-build.stderr.log": ("f0788aa36d1c86b6ccdfb7f4042a5574102d82061c046422a2d42e008a1e4710", 72),
    "02-cargo-build.stdout.log": ("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", 0),
    "03-instrumented-godot.log": ("7113914e5dcf59e461a0f36fbab800b02d038aa658d8defec90fc9a5e887d5c1", 2477),
    "03-instrumented.stderr.log": ("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", 0),
    "03-instrumented.stdout.log": ("02ff4dec0fb74ecbe8febfde11374ebf19febe54f547f82a2b0ae5b830c06fc2", 2582),
    "04-stock-godot.log": ("30227684eed6cb146d26bd85dbec31f49597d42b98ce7a194ddc106a14259b5e", 2087),
    "04-stock.stderr.log": ("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", 0),
    "04-stock.stdout.log": ("d3e0413b49ee54b0c48879da23719b02e5a6b994cbbd5060439689a9794e4897", 2193),
    "attempt.json": ("47fe35c0893aa484c5c896937887ae0c9f44a199c1a0eae8990e3198a5dbec80", 599),
    "receipt.json": (EXPECTED_RECEIPT_SHA256, EXPECTED_RECEIPT_BYTES),
}


class AuditError(RuntimeError):
    pass


def require(condition: bool, code: str) -> None:
    if not condition:
        raise AuditError(code)


def exact(actual: Any, expected: Any, code: str) -> None:
    require(actual == expected, f"{code}: expected={expected!r} actual={actual!r}")


def digest(path: Path) -> tuple[str, int]:
    require(path.is_file(), f"FILE_MISSING:{path}")
    payload = path.read_bytes()
    return hashlib.sha256(payload).hexdigest(), len(payload)


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(value, dict), f"JSON_ROOT_INVALID:{path}")
    return value


def git(*arguments: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(EXPECTED_ROOT), *arguments],
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    require(result.returncode == 0, f"GIT_FAILED:{' '.join(arguments)}:{result.stderr.strip()}")
    return result.stdout.strip()


def validate_closure(closure: dict[str, Any], verify_files: bool = True) -> None:
    exact(
        closure.get("schema_version"),
        "sporespore_qsdk_r24d16_godot_jolt_profile_scoped_recovery_"
        "capability_qualification_closure_v1",
        "SCHEMA",
    )
    exact(closure.get("gate_id"), "QSDK-R24D16", "GATE")
    exact(
        closure.get("question_class"),
        "non_physical_source_conformance",
        "QUESTION_CLASS",
    )
    exact(
        closure.get("status"),
        "qualified_exact_profile_mapping_positive_stock_refusal_preserved",
        "STATUS",
    )

    source = closure["source_freeze"]
    exact(source.get("repository_root"), EXPECTED_ROOT.as_posix(), "SOURCE_ROOT")
    exact(source.get("remote"), EXPECTED_REMOTE, "SOURCE_REMOTE")
    exact(source.get("branch"), "main", "SOURCE_BRANCH")
    exact(source.get("commit"), FREEZE_COMMIT, "FREEZE_COMMIT")
    exact(source.get("tree_git_oid"), FREEZE_TREE, "FREEZE_TREE")
    exact(source.get("parent_commit"), FREEZE_PARENT, "FREEZE_PARENT")
    exact(source.get("local_upstream_cached_live_equal_at_qualification"), True, "REMOTE_EQUALITY")
    exact(source.get("worktree_clean_at_qualification"), True, "CLEAN_SOURCE")
    exact(source.get("worktree_count"), 1, "WORKTREE_COUNT")
    exact(source.get("source_inventory_count"), 10, "SOURCE_COUNT")
    bindings = source.get("source_bindings", [])
    exact(len(bindings), 10, "SOURCE_BINDING_COUNT")
    exact({entry["path"] for entry in bindings}, set(EXPECTED_SOURCE_BINDINGS), "SOURCE_PATHS")
    for entry in bindings:
        path = entry["path"]
        expected_sha, expected_bytes, expected_blob = EXPECTED_SOURCE_BINDINGS[path]
        exact(entry.get("raw_sha256"), f"sha256:{expected_sha}", f"SOURCE_SHA:{path}")
        exact(entry.get("byte_length"), expected_bytes, f"SOURCE_BYTES:{path}")
        exact(entry.get("git_blob_oid"), expected_blob, f"SOURCE_BLOB:{path}")
        if verify_files:
            exact(git("rev-parse", f"{FREEZE_COMMIT}:{path}"), expected_blob, f"COMMITTED_BLOB:{path}")
            exact(digest(EXPECTED_ROOT / path), (expected_sha, expected_bytes), f"WORKING_SOURCE:{path}")
    for field in (
        "historical_stock_mapping_rewritten",
        "historical_r24d15_decision_rewritten",
        "observed_campaign_rewritten",
        "observed_threshold_rewritten",
        "observed_selector_rewritten",
        "observed_evaluator_rewritten",
    ):
        exact(source.get(field), False, f"SOURCE_IMMUTABILITY:{field}")

    qualification = closure["qualification"]
    exact(qualification.get("run_id"), RUN_RELATIVE.name, "RUN_ID")
    exact(qualification.get("run_root"), RUN_ROOT.as_posix(), "RUN_ROOT")
    exact(qualification.get("receipt_raw_sha256"), f"sha256:{EXPECTED_RECEIPT_SHA256}", "RECEIPT_SHA")
    exact(qualification.get("receipt_byte_length"), EXPECTED_RECEIPT_BYTES, "RECEIPT_BYTES")
    exact(qualification.get("stage_count"), 4, "STAGE_COUNT")
    exact(qualification.get("passed_stage_count"), 4, "PASSED_STAGES")
    exact(qualification.get("runtime_process_count"), 2, "RUNTIME_COUNT")
    exact(qualification.get("instrumented_positive_count"), 1, "POSITIVE_COUNT")
    exact(qualification.get("stock_negative_control_count"), 1, "STOCK_COUNT")
    exact(qualification.get("capability_mutation_count"), 8, "MUTATION_COUNT")
    exact(qualification.get("capability_mutation_rejection_count"), 8, "MUTATION_REJECTIONS")
    exact(qualification.get("terminal_receipt_present"), True, "TERMINAL_RECEIPT")
    exact(qualification.get("same_freeze_qualification_consumed"), True, "CONSUMED")
    exact(qualification.get("same_freeze_qualification_rerun_permitted"), False, "NO_RERUN")
    exact(qualification.get("artifact_reference_count"), 12, "ARTIFACT_REFS")
    exact(qualification.get("unique_artifact_count"), 9, "UNIQUE_ARTIFACTS")
    exact(qualification.get("retained_artifact_total_byte_length"), 25702, "ARTIFACT_BYTES")
    exact(qualification.get("all_artifacts_content_addressed"), True, "CAS_COMPLETE")
    inventory = qualification.get("artifact_inventory", [])
    exact(len(inventory), 12, "ARTIFACT_COUNT")
    exact({item["relative_path"] for item in inventory}, set(EXPECTED_ARTIFACTS), "ARTIFACT_PATHS")
    if verify_files:
        actual_files = {path.name for path in RUN_ROOT.rglob("*") if path.is_file()}
        exact(actual_files, set(EXPECTED_ARTIFACTS), "RUN_FILE_POPULATION")
    for item in inventory:
        name = item["relative_path"]
        expected_sha, expected_bytes = EXPECTED_ARTIFACTS[name]
        exact(item.get("raw_sha256"), f"sha256:{expected_sha}", f"ARTIFACT_SHA:{name}")
        exact(item.get("byte_length"), expected_bytes, f"ARTIFACT_BYTES:{name}")
        if verify_files:
            exact(digest(RUN_ROOT / name), (expected_sha, expected_bytes), f"ARTIFACT_FILE:{name}")
            cas_root = EXPECTED_EVIDENCE_ROOT / "artifacts" / "sha256" / expected_sha
            exact(digest(cas_root / "payload.bin"), (expected_sha, expected_bytes), f"CAS_PAYLOAD:{name}")
            manifest = load_json(cas_root / "manifest.json")
            exact(manifest.get("schema_version"), "sporespore_content_addressed_artifact_manifest_v1", f"CAS_SCHEMA:{name}")
            exact(manifest.get("sha256"), f"sha256:{expected_sha}", f"CAS_SHA:{name}")
            exact(manifest.get("byte_length"), expected_bytes, f"CAS_BYTES:{name}")

    runtime = closure["runtime_decision"]
    exact(runtime.get("instrumented_exact_binary_pair_match"), True, "INSTRUMENTED_IDENTITY")
    exact(runtime.get("instrumented_native_telemetry_method_registered"), True, "TELEMETRY_METHOD")
    exact(runtime.get("instrumented_required_channel_count"), 10, "INSTRUMENTED_REQUIRED")
    exact(runtime.get("instrumented_supported_channel_count"), 10, "INSTRUMENTED_SUPPORTED")
    exact(runtime.get("instrumented_unsupported_channel_count"), 0, "INSTRUMENTED_UNSUPPORTED")
    exact(runtime.get("instrumented_core_support_status"), "supported_exact", "INSTRUMENTED_STATUS")
    exact(runtime.get("instrumented_core_memory_present"), True, "INSTRUMENTED_MEMORY")
    exact(runtime.get("instrumented_mutation_rejection_count"), 4, "INSTRUMENTED_MUTATIONS")
    exact(runtime.get("stock_instrumented_profile_selected"), False, "STOCK_SELECTION")
    exact(runtime.get("stock_capability_equals_historical_mapping"), True, "STOCK_MAPPING")
    exact(runtime.get("stock_required_channel_count"), 10, "STOCK_REQUIRED")
    exact(runtime.get("stock_supported_channel_count"), 8, "STOCK_SUPPORTED")
    exact(runtime.get("stock_unsupported_channel_count"), 2, "STOCK_UNSUPPORTED")
    exact(runtime.get("stock_core_support_status"), "unsupported_capability", "STOCK_STATUS")
    exact(runtime.get("stock_core_refusal_reason"), "required_channel_unsupported:AppliedActuationReceipts", "STOCK_REASON")
    exact(runtime.get("stock_core_memory_present"), False, "STOCK_MEMORY")
    exact(runtime.get("stock_mutation_rejection_count"), 4, "STOCK_MUTATIONS")
    exact(runtime.get("stock_profile_promoted"), False, "STOCK_PROMOTED")
    exact(runtime.get("numerical_accuracy_accepted"), False, "NUMERICAL_ACCURACY")

    provenance = closure["decision_rule_provenance"]
    for field in (
        "empirical_performance_threshold_count",
        "superiority_margin_count",
        "equivalence_or_non_inferiority_margin_count",
        "held_out_validation_cohort_count",
        "population_claim_count",
    ):
        exact(provenance.get(field), 0, f"PROVENANCE:{field}")
    exact(provenance.get("decision_rule_applied_without_change"), True, "DECISION_RULE")

    decision = closure["decision"]
    exact(decision.get("outcome"), "qualify_exact_profile_mapping_and_preserve_stock_refusal", "OUTCOME")
    exact(decision.get("profile_scoped_mapping_qualified"), True, "MAPPING_QUALIFIED")
    exact(decision.get("exact_profile_native_capability_conjunction_complete"), True, "CONJUNCTION")
    exact(decision.get("stock_profile_promoted"), False, "DECISION_STOCK")
    exact(decision.get("numerical_accuracy_accepted"), False, "DECISION_ACCURACY")
    exact(decision.get("native_recovery_observation_collectors_complete"), False, "COLLECTORS")
    exact(decision.get("recovery_controller_implemented"), False, "CONTROLLER")
    exact(decision.get("recovery_physical_execution_authorized"), False, "PHYSICAL_AUTH")

    next_boundary = closure["next_boundary"]
    exact(next_boundary.get("gate_id"), "QSDK-R24D17", "NEXT_GATE")
    exact(next_boundary.get("question_class"), "non_physical_source_conformance", "NEXT_CLASS")
    exact(next_boundary.get("complete_zero_world_gate_required"), True, "NEXT_ZERO_WORLD")
    exact(next_boundary.get("physical_execution_authorized"), False, "NEXT_PHYSICAL")
    exact(next_boundary.get("recovery_world_authorized"), False, "NEXT_RECOVERY")
    exact(next_boundary.get("prone_to_standing_world_authorized"), False, "NEXT_PRONE")

    claims = closure["claims"]
    for field in (
        "profile_scoped_mapping_qualified",
        "exact_profile_native_capability_conjunction_complete",
        "historical_stock_mapping_preserved",
    ):
        exact(claims.get(field), True, f"POSITIVE_CLAIM:{field}")
    for field in (
        "new_physical_world_opened",
        "new_model_constructed",
        "new_solver_step_executed",
        "numerical_accuracy_accepted",
        "native_recovery_observation_collectors_complete",
        "recovery_controller_implemented",
        "recovery_world_opened",
        "prone_to_standing_world_opened",
        "turning_claim_changed",
        "cross_engine_equivalence_claimed",
        "q_sdk_r24_satisfied",
        "physical_acceptance_authority",
        "release_authority",
    ):
        exact(claims.get(field), False, f"NEGATIVE_CLAIM:{field}")
    exact(claims.get("sdk1_milestone_score_before"), "11/20", "SDK1_BEFORE")
    exact(claims.get("sdk1_milestone_score_after"), "11/20", "SDK1_AFTER")
    exact(claims.get("full_program_score_before"), "11/25", "FULL_BEFORE")
    exact(claims.get("full_program_score_after"), "11/25", "FULL_AFTER")
    exact(closure.get("closure_audit_path"), AUDIT_RELATIVE.as_posix(), "AUDIT_PATH")

    if verify_files:
        receipt = load_json(RUN_ROOT / "receipt.json")
        exact(receipt.get("ok"), True, "RECEIPT_OK")
        exact(receipt.get("mode"), "Qualification", "RECEIPT_MODE")
        exact(receipt.get("status"), closure.get("status"), "RECEIPT_STATUS")
        exact(receipt["source"].get("head"), FREEZE_COMMIT, "RECEIPT_HEAD")
        exact(receipt["source"].get("tree_git_oid"), FREEZE_TREE, "RECEIPT_TREE")
        exact(receipt["source"].get("clean_pushed"), True, "RECEIPT_CLEAN")
        exact(receipt.get("source_inventory_count"), 10, "RECEIPT_SOURCE_COUNT")
        exact(receipt.get("stage_count"), 4, "RECEIPT_STAGES")
        exact(receipt.get("passed_stage_count"), 4, "RECEIPT_PASSED")
        exact(receipt.get("profile_scoped_mapping_qualified"), True, "RECEIPT_MAPPING")
        exact(receipt.get("exact_profile_native_capability_conjunction_complete"), True, "RECEIPT_CONJUNCTION")
        for field in ("model_construction_count", "world_attempt_count", "world_build_count", "solver_step_count"):
            exact(receipt.get(field), 0, f"RECEIPT_ZERO:{field}")
        attempt = load_json(RUN_ROOT / "attempt.json")
        exact(attempt.get("source_head"), FREEZE_COMMIT, "ATTEMPT_HEAD")
        exact(attempt.get("status"), "opened_incomplete_until_terminal_receipt", "ATTEMPT_STATUS")
        exact(attempt.get("physical_execution_authorized"), False, "ATTEMPT_PHYSICS")


def run_mutations(closure: dict[str, Any]) -> int:
    mutations: tuple[tuple[str, Callable[[dict[str, Any]], None]], ...] = (
        ("freeze", lambda d: d["source_freeze"].__setitem__("commit", "0" * 40)),
        ("receipt_hash", lambda d: d["qualification"].__setitem__("receipt_raw_sha256", "sha256:" + "0" * 64)),
        ("stage_count", lambda d: d["qualification"].__setitem__("passed_stage_count", 3)),
        ("artifact_count", lambda d: d["qualification"].__setitem__("artifact_reference_count", 11)),
        ("instrumented_support", lambda d: d["runtime_decision"].__setitem__("instrumented_supported_channel_count", 9)),
        ("stock_promotion", lambda d: d["runtime_decision"].__setitem__("stock_profile_promoted", True)),
        ("mutation_rejection", lambda d: d["qualification"].__setitem__("capability_mutation_rejection_count", 7)),
        ("threshold", lambda d: d["decision_rule_provenance"].__setitem__("empirical_performance_threshold_count", 1)),
        ("mapping_decision", lambda d: d["decision"].__setitem__("profile_scoped_mapping_qualified", False)),
        ("collector_claim", lambda d: d["claims"].__setitem__("native_recovery_observation_collectors_complete", True)),
        ("physical_authority", lambda d: d["next_boundary"].__setitem__("physical_execution_authorized", True)),
        ("score", lambda d: d["claims"].__setitem__("sdk1_milestone_score_after", "12/20")),
    )
    rejected = 0
    for name, mutate in mutations:
        candidate = copy.deepcopy(closure)
        mutate(candidate)
        try:
            validate_closure(candidate, verify_files=False)
        except AuditError:
            rejected += 1
        else:
            raise AuditError(f"MUTATION_SURVIVED:{name}")
    return rejected


def main() -> int:
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--allow-prospective-uncommitted", action="store_true")
    mode.add_argument("--require-committed-closure", action="store_true")
    args = parser.parse_args()

    exact(Path(git("rev-parse", "--show-toplevel")).resolve(), EXPECTED_ROOT.resolve(), "REPOSITORY_ROOT")
    exact(git("remote", "get-url", "origin"), EXPECTED_REMOTE, "REPOSITORY_REMOTE")
    exact(git("branch", "--show-current"), "main", "REPOSITORY_BRANCH")
    exact(git("rev-parse", f"{FREEZE_COMMIT}^"), FREEZE_PARENT, "COMMITTED_FREEZE_PARENT")
    exact(git("rev-parse", f"{FREEZE_COMMIT}^{{tree}}"), FREEZE_TREE, "COMMITTED_FREEZE_TREE")
    if args.require_committed_closure:
        head_blob = git("rev-parse", f"HEAD:{CLOSURE_RELATIVE.as_posix()}")
        working_blob = git("hash-object", "--", CLOSURE_RELATIVE.as_posix())
        exact(working_blob, head_blob, "CLOSURE_NOT_COMMITTED")
        audit_head_blob = git("rev-parse", f"HEAD:{AUDIT_RELATIVE.as_posix()}")
        audit_working_blob = git("hash-object", "--", AUDIT_RELATIVE.as_posix())
        exact(audit_working_blob, audit_head_blob, "AUDIT_NOT_COMMITTED")

    closure = load_json(EXPECTED_ROOT / CLOSURE_RELATIVE)
    validate_closure(closure)
    mutations = run_mutations(closure)
    print(
        "QSDK_R24D16_PROFILE_CAPABILITY_CLOSURE_PASS "
        "source_bindings=10 stages=4/4 runtime_processes=2 "
        "profile_channels=10/10 stock_channels=8/10 mutations=8/8 "
        f"closure_mutations={mutations}/12 artifacts=12/9 bytes=25702 "
        "conjunction_complete=true collectors_complete=false controller=false "
        "worlds=0 builds=0 solver_steps=0"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AuditError, KeyError, TypeError, ValueError, json.JSONDecodeError) as exc:
        print(f"QSDK_R24D16_PROFILE_CAPABILITY_CLOSURE_FAIL {exc}", file=sys.stderr)
        raise SystemExit(1) from exc
