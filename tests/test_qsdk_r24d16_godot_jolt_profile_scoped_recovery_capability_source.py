#!/usr/bin/env python3
"""Audit the prospective R24D16 profile-scoped Godot capability source."""

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
EXPECTED_REMOTE = "https://github.com/Slagathore/sporespore.git"
CONTRACT_RELATIVE = Path(
    "sdk/recovery/"
    "r24d16_godot_jolt_profile_scoped_recovery_capability_contract_v1.json"
)
MAPPING_RELATIVE = Path(
    "sdk/adapters/godot/gdscript/"
    "recovery_capability_instrumented_v2.gd"
)
STOCK_MAPPING_RELATIVE = Path(
    "sdk/adapters/godot/gdscript/recovery_capability.gd"
)
WORKER_RELATIVE = Path(
    "tests/test_sdk_qsdk_r24d16_godot_profile_scoped_"
    "recovery_capability_zero_world.gd"
)
RUNNER_RELATIVE = Path(
    "sdk/run_qsdk_r24d16_profile_scoped_recovery_capability_zero_world.ps1"
)
PREDECESSOR_RELATIVE = Path(
    "sdk/recovery/"
    "r24d15_godot_jolt_instrumented_profile_promotion_decision_v1.json"
)
AUDIT_RELATIVE = Path(
    "tests/test_qsdk_r24d16_godot_jolt_profile_scoped_"
    "recovery_capability_source.py"
)
SOURCE_RELATIVES = (
    CONTRACT_RELATIVE,
    MAPPING_RELATIVE,
    STOCK_MAPPING_RELATIVE,
    WORKER_RELATIVE,
    RUNNER_RELATIVE,
    PREDECESSOR_RELATIVE,
    AUDIT_RELATIVE,
    Path("sdk/core/src/recovery.rs"),
    Path("sdk/adapters/godot/src/lib.rs"),
    Path("sdk/adapters/godot/sporespore_locomotion.gdextension"),
)
EXPECTED_PARENT = "b8c5ec5919d9d890946262d923f79259a6c8662a"
EXPECTED_PARENT_TREE = "3e0bab787046baf7cdedf26e706fa38fd510c83c"
EXPECTED_PREDECESSOR_SHA256 = (
    "ae5359f106732cecda253d6c346e9ac14703568883344982326597db79bd4aed"
)
EXPECTED_PREDECESSOR_BYTES = 12491
EXPECTED_PREDECESSOR_BLOB = "025a705a0034f10d9fc9f9a926dabdb4d15e4797"
EXPECTED_STOCK_SHA256 = (
    "4c341284bc4816b309ae7fc7b165dfb281d6df2decb51b1b03ceb991bbc5a8c2"
)
EXPECTED_STOCK_BYTES = 8173
EXPECTED_STOCK_BLOB = "3f249226830441ff37d23db9b6e9ed83577da65e"
EXPECTED_CONSOLE_SHA256 = (
    "ff655a567d31f51628d5b21742a0618e53f9fbf8a94937dd07d9882a0739872f"
)
EXPECTED_ENGINE_SHA256 = (
    "2d68ed7ae53704ffb532cd5633241c74d599d69e3bf1968de0ef261553030ffb"
)
EXPECTED_STOCK_CONSOLE_SHA256 = (
    "c5fc2d0bb24826a6757fa1e6bf2991effb294859c7dd03d09a122ef217484896"
)


class AuditError(RuntimeError):
    """A fail-closed R24D16 source-audit error."""


def require(condition: bool, code: str) -> None:
    if not condition:
        raise AuditError(code)


def exact(actual: Any, expected: Any, code: str) -> None:
    require(actual == expected, f"{code}: expected={expected!r} actual={actual!r}")


def read_bytes(relative: Path) -> bytes:
    path = EXPECTED_ROOT / relative
    require(path.is_file(), f"FILE_MISSING:{relative.as_posix()}")
    return path.read_bytes()


def read_text(relative: Path) -> str:
    payload = read_bytes(relative)
    require(b"\r" not in payload, f"SOURCE_NOT_LF:{relative.as_posix()}")
    try:
        return payload.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise AuditError(f"SOURCE_NOT_UTF8:{relative.as_posix()}:{exc}") from exc


def read_json(relative: Path) -> dict[str, Any]:
    value = json.loads(read_text(relative))
    require(isinstance(value, dict), f"JSON_ROOT_INVALID:{relative.as_posix()}")
    return value


def sha256(relative: Path) -> str:
    return hashlib.sha256(read_bytes(relative)).hexdigest()


def git(*arguments: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(EXPECTED_ROOT), *arguments],
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    require(
        result.returncode == 0,
        f"GIT_FAILED:{' '.join(arguments)}:{result.stderr.strip()}",
    )
    return result.stdout.strip()


def validate_contract(contract: dict[str, Any]) -> None:
    exact(
        contract.get("schema_version"),
        "sporespore_qsdk_r24d16_godot_jolt_profile_scoped_"
        "recovery_capability_contract_v1",
        "CONTRACT_SCHEMA",
    )
    exact(contract.get("gate_id"), "QSDK-R24D16", "GATE_ID")
    exact(
        contract.get("work_id"),
        "QSDK-R24D16-GODOT-JOLT-PROFILE-SCOPED-RECOVERY-CAPABILITY-MAPPING",
        "WORK_ID",
    )
    exact(
        contract.get("question_class"),
        "non_physical_source_conformance",
        "QUESTION_CLASS",
    )
    exact(
        contract.get("status"),
        "implemented_prospective_source_freeze_qualification_pending",
        "STATUS",
    )
    exact(
        contract.get("answer_before_qualification"),
        "implemented_not_yet_qualified",
        "ANSWER",
    )

    source = contract["source_boundary"]
    exact(source.get("repository_root"), EXPECTED_ROOT.as_posix(), "SOURCE_ROOT")
    exact(source.get("remote"), EXPECTED_REMOTE, "SOURCE_REMOTE")
    exact(source.get("branch"), "main", "SOURCE_BRANCH")
    exact(source.get("parent_commit"), EXPECTED_PARENT, "SOURCE_PARENT")
    exact(source.get("parent_tree_git_oid"), EXPECTED_PARENT_TREE, "SOURCE_TREE")
    exact(source.get("source_freeze_commit"), None, "SELF_COMMIT_MUST_BE_NULL")
    exact(source.get("source_freeze_tree_git_oid"), None, "SELF_TREE_MUST_BE_NULL")
    exact(source.get("qualification_must_use_clean_pushed_freeze"), True, "CLEAN_FREEZE")
    for field in (
        "historical_stock_mapping_rewritten",
        "historical_r24d15_decision_rewritten",
        "observed_campaign_rewritten",
        "observed_threshold_rewritten",
        "observed_selector_rewritten",
        "observed_evaluator_rewritten",
    ):
        exact(source.get(field), False, f"SOURCE_IMMUTABILITY:{field}")

    predecessor = contract["predecessor"]
    exact(predecessor.get("gate_id"), "QSDK-R24D15", "PREDECESSOR_GATE")
    exact(
        predecessor.get("decision_path"),
        PREDECESSOR_RELATIVE.as_posix(),
        "PREDECESSOR_PATH",
    )
    exact(
        predecessor.get("decision_raw_sha256"),
        f"sha256:{EXPECTED_PREDECESSOR_SHA256}",
        "PREDECESSOR_SHA",
    )
    exact(
        predecessor.get("decision_byte_length"),
        EXPECTED_PREDECESSOR_BYTES,
        "PREDECESSOR_BYTES",
    )
    exact(
        predecessor.get("decision_git_blob_oid"),
        EXPECTED_PREDECESSOR_BLOB,
        "PREDECESSOR_BLOB",
    )
    exact(predecessor.get("instrumented_profile_promoted"), True, "PROMOTION")
    exact(predecessor.get("stock_profile_promoted"), False, "STOCK_PROMOTION")
    exact(predecessor.get("numerical_accuracy_accepted"), False, "ACCURACY")
    exact(predecessor.get("adapter_capability_mapping_implemented"), False, "OLD_MAPPING")
    exact(predecessor.get("adapter_capability_mapping_qualified"), False, "OLD_QUALIFICATION")

    stock = contract["historical_stock_mapping"]
    exact(stock.get("path"), STOCK_MAPPING_RELATIVE.as_posix(), "STOCK_PATH")
    exact(stock.get("raw_sha256"), f"sha256:{EXPECTED_STOCK_SHA256}", "STOCK_SHA")
    exact(stock.get("byte_length"), EXPECTED_STOCK_BYTES, "STOCK_BYTES")
    exact(stock.get("git_blob_oid"), EXPECTED_STOCK_BLOB, "STOCK_BLOB")
    exact(stock.get("supported_channel_count"), 8, "STOCK_SUPPORTED")
    exact(stock.get("unsupported_channel_count"), 2, "STOCK_UNSUPPORTED")
    exact(
        stock.get("unsupported_channels"),
        ["applied_actuation_receipts", "energy_balance_ledger"],
        "STOCK_UNSUPPORTED_CHANNELS",
    )
    exact(stock.get("typed_support_status"), "unsupported_capability", "STOCK_STATUS")
    exact(stock.get("must_remain_unchanged"), True, "STOCK_IMMUTABILITY")

    mapping = contract["profile_scoped_mapping"]
    exact(mapping.get("path"), MAPPING_RELATIVE.as_posix(), "MAPPING_PATH")
    exact(
        mapping.get("instrumented_profile_id"),
        "godot_4_7_jolt_sporespore_motor_telemetry_active_step_snapshot_v2",
        "PROFILE_ID",
    )
    exact(
        mapping.get("fallback_profile_id"),
        "godot_4_7_jolt_stock_or_unqualified_v1",
        "FALLBACK_ID",
    )
    exact(mapping.get("canonical_mapping_identity_changed"), False, "MAPPING_IDENTITY")
    exact(mapping.get("required_channel_count"), 10, "REQUIRED_CHANNELS")
    exact(mapping.get("instrumented_supported_channel_count"), 10, "PROFILE_SUPPORTED")
    exact(mapping.get("instrumented_unsupported_channel_count"), 0, "PROFILE_UNSUPPORTED")
    exact(mapping.get("fallback_supported_channel_count"), 8, "FALLBACK_SUPPORTED")
    exact(mapping.get("fallback_unsupported_channel_count"), 2, "FALLBACK_UNSUPPORTED")
    exact(
        [entry["channel"] for entry in mapping.get("promoted_channels", [])],
        ["applied_actuation_receipts", "energy_balance_ledger"],
        "PROMOTED_CHANNELS",
    )
    for entry in mapping["promoted_channels"]:
        exact(entry.get("source_measurement_only"), True, "MEASURED_ONLY")
        exact(entry.get("synthesized_when_missing"), False, "NO_SYNTHESIS")
    for field in (
        "caller_supplied_profile_label_can_promote",
        "environment_variable_can_promote",
        "configured_motor_limit_can_be_relabelled_as_applied_impulse",
        "missing_measurement_can_be_synthesized",
        "engine_identity_exposed_to_policy",
    ):
        exact(mapping.get(field), False, f"MAPPING_FAIL_CLOSED:{field}")

    runtime = contract["exact_instrumented_runtime"]
    exact(runtime.get("godot_source_commit"), "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88", "GODOT_COMMIT")
    exact(runtime.get("console_binary_raw_sha256"), f"sha256:{EXPECTED_CONSOLE_SHA256}", "CONSOLE_SHA")
    exact(runtime.get("console_binary_byte_length"), 293376, "CONSOLE_BYTES")
    exact(runtime.get("engine_binary_raw_sha256"), f"sha256:{EXPECTED_ENGINE_SHA256}", "ENGINE_SHA")
    exact(runtime.get("engine_binary_byte_length"), 188829184, "ENGINE_BYTES")
    exact(runtime.get("binary_pair_and_api_conjunction_required"), True, "IDENTITY_CONJUNCTION")
    exact(runtime.get("partial_identity_match_can_promote"), False, "PARTIAL_MATCH")
    exact(runtime.get("different_custom_build_can_promote"), False, "OTHER_BUILD")

    negative = contract["stock_runtime_negative_control"]
    exact(
        negative.get("invoked_console_raw_sha256"),
        f"sha256:{EXPECTED_STOCK_CONSOLE_SHA256}",
        "STOCK_CONSOLE_SHA",
    )
    exact(negative.get("invoked_console_byte_length"), 198152, "STOCK_CONSOLE_BYTES")
    exact(negative.get("instrumented_profile_must_be_selected"), False, "STOCK_SELECTION")
    exact(negative.get("profile_capability_must_equal_historical_stock_mapping"), True, "STOCK_EQUALITY")
    exact(negative.get("expected_supported_channel_count"), 8, "STOCK_EXPECTED_SUPPORTED")
    exact(negative.get("expected_unsupported_channel_count"), 2, "STOCK_EXPECTED_UNSUPPORTED")
    exact(negative.get("expected_support_status"), "unsupported_capability", "STOCK_EXPECTED_STATUS")

    qualification = contract["qualification_contract"]
    exact(qualification.get("runner_path"), RUNNER_RELATIVE.as_posix(), "RUNNER_PATH")
    exact(qualification.get("source_audit_path"), AUDIT_RELATIVE.as_posix(), "AUDIT_PATH")
    exact(qualification.get("runtime_worker_path"), WORKER_RELATIVE.as_posix(), "WORKER_PATH")
    exact(qualification.get("stage_count"), 4, "STAGE_COUNT")
    exact(qualification.get("required_runtime_process_count"), 2, "PROCESS_COUNT")
    exact(qualification.get("required_instrumented_positive_count"), 1, "POSITIVE_COUNT")
    exact(qualification.get("required_stock_negative_control_count"), 1, "NEGATIVE_COUNT")
    exact(qualification.get("capability_mutation_count_per_runtime"), 4, "MUTATION_COUNT")
    exact(qualification.get("capability_mutation_rejection_count_per_runtime"), 4, "MUTATION_REJECTIONS")
    exact(qualification.get("qualification_is_single_clean_pushed_finite_decision"), True, "FINITE_QUALIFICATION")
    exact(qualification.get("same_freeze_qualification_rerun_permitted_after_terminal_receipt"), False, "NO_RERUN")
    for field in (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
    ):
        exact(qualification.get(field), 0, f"ZERO_COUNT:{field}")
    for field in ("physics_state_modified", "physical_question_opened", "physical_execution_authorized"):
        exact(qualification.get(field), False, f"ZERO_WORLD_BOUNDARY:{field}")

    provenance = contract["decision_rule_provenance"]
    for field in (
        "empirical_performance_threshold_count",
        "superiority_margin_count",
        "equivalence_or_non_inferiority_margin_count",
        "held_out_validation_cohort_count",
        "population_claim_count",
    ):
        exact(provenance.get(field), 0, f"PROVENANCE_COUNT:{field}")
    require("clean pushed source" in provenance.get("decision_rule", ""), "DECISION_RULE_SOURCE")
    require("exact stock negative runtime" in provenance.get("adequacy_argument", ""), "ADEQUACY_NEGATIVE")

    positive = contract["prospective_outcomes"]["positive"]
    exact(positive.get("instrumented_profile_mapping_qualified"), True, "POSITIVE_MAPPING")
    exact(positive.get("stock_profile_promoted"), False, "POSITIVE_STOCK")
    exact(positive.get("exact_profile_native_capability_conjunction_complete"), True, "POSITIVE_CONJUNCTION")
    exact(positive.get("native_observation_collectors_complete"), False, "POSITIVE_COLLECTORS")
    exact(positive.get("recovery_controller_implemented"), False, "POSITIVE_CONTROLLER")
    exact(positive.get("recovery_physical_execution_authorized"), False, "POSITIVE_PHYSICS")
    negative_outcome = contract["prospective_outcomes"]["negative_or_invalid"]
    exact(negative_outcome.get("instrumented_profile_mapping_qualified"), False, "NEGATIVE_MAPPING")
    exact(negative_outcome.get("distinct_successor_required"), True, "NEGATIVE_SUCCESSOR")

    claims = contract["claims"]
    exact(claims.get("profile_scoped_mapping_implemented"), True, "IMPLEMENTED_CLAIM")
    exact(claims.get("historical_stock_mapping_preserved"), True, "STOCK_PRESERVED")
    for field, value in claims.items():
        if field in {
            "profile_scoped_mapping_implemented",
            "historical_stock_mapping_preserved",
            "sdk1_milestone_score_before",
            "sdk1_milestone_score_after",
            "full_program_score_before",
            "full_program_score_after",
        }:
            continue
        exact(value, False, f"UNLICENSED_CLAIM:{field}")
    exact(claims.get("sdk1_milestone_score_before"), "11/20", "SDK1_BEFORE")
    exact(claims.get("sdk1_milestone_score_after"), "11/20", "SDK1_AFTER")
    exact(claims.get("full_program_score_before"), "11/25", "FULL_BEFORE")
    exact(claims.get("full_program_score_after"), "11/25", "FULL_AFTER")


def validate_source_texts(mapping: str, worker: str, runner: str) -> None:
    for marker in (
        "const StockCapabilityScript := preload(",
        "runtime_identity_v1",
        "OS.get_executable_path()",
        "EXPECTED_CONSOLE_RAW_SHA256",
        EXPECTED_CONSOLE_SHA256,
        "EXPECTED_ENGINE_RAW_SHA256",
        EXPECTED_ENGINE_SHA256,
        "ClassDB.class_has_method(TELEMETRY_CLASS_NAME, TELEMETRY_METHOD_NAME)",
        "var selected := exact_pair and telemetry_api_reachable",
        "if not bool(runtime.get(\"instrumented_profile_selected\", false)):",
        "return capability",
        "godot_jolt_active_step_snapshot_v2_applied_actuation_receipt_projection_v1",
        "godot_jolt_active_step_snapshot_v2_energy_balance_ledger_projection_v1",
        '"synthesized_when_missing"] = false',
        '"engine_identity_exposed_to_policy", true',
    ):
        require(marker in mapping, f"MAPPING_MARKER_MISSING:{marker}")
    require("get_param(" not in mapping, "CONFIGURED_LIMIT_READBACK_FORBIDDEN")
    require("get_environment(" not in mapping, "ENVIRONMENT_PROMOTION_FORBIDDEN")

    for marker in (
        "QSDK_R24D16_GODOT_PROFILE_CAPABILITY_ZERO_WORLD ",
        '--expected_profile=',
        '"supported_exact"',
        '"unsupported_capability"',
        "stock_fallback_exact",
        "mutation_rejection_count",
        '"world_attempt_count": 0',
        '"solver_step_count": 0',
    ):
        require(marker in worker, f"WORKER_MARKER_MISSING:{marker}")
    for marker in (
        '[ValidateSet("Development", "Qualification")]',
        "Enter-SporeSporeLocomotionOperationLock",
        "qualification_already_consumed_for_source",
        "--require-committed-source",
        "exact instrumented profile positive",
        "exact stock runtime typed-refusal negative",
        "world_attempt_count = 0",
        "QSDK_R24D16_PROFILE_CAPABILITY_GATE ",
    ):
        require(marker in runner, f"RUNNER_MARKER_MISSING:{marker}")
    require("RunPhysical" not in runner, "PHYSICAL_SWITCH_FORBIDDEN")


def run_mutations(contract: dict[str, Any]) -> int:
    mutations: tuple[tuple[str, Callable[[dict[str, Any]], None]], ...] = (
        ("question_class", lambda d: d.__setitem__("question_class", "development")),
        ("source_parent", lambda d: d["source_boundary"].__setitem__("parent_commit", "0" * 40)),
        ("predecessor_hash", lambda d: d["predecessor"].__setitem__("decision_raw_sha256", "sha256:" + "0" * 64)),
        ("stock_mapping_hash", lambda d: d["historical_stock_mapping"].__setitem__("raw_sha256", "sha256:" + "0" * 64)),
        ("caller_label_promotion", lambda d: d["profile_scoped_mapping"].__setitem__("caller_supplied_profile_label_can_promote", True)),
        ("console_identity", lambda d: d["exact_instrumented_runtime"].__setitem__("console_binary_raw_sha256", "sha256:" + "0" * 64)),
        ("stock_negative", lambda d: d["stock_runtime_negative_control"].__setitem__("instrumented_profile_must_be_selected", True)),
        ("physical_authority", lambda d: d["claims"].__setitem__("physical_acceptance_authority", True)),
    )
    rejected = 0
    for name, mutate in mutations:
        candidate = copy.deepcopy(contract)
        mutate(candidate)
        try:
            validate_contract(candidate)
        except AuditError:
            rejected += 1
        else:
            raise AuditError(f"MUTATION_SURVIVED:{name}")
    return rejected


def validate_repository(require_committed: bool) -> tuple[str, str]:
    exact(Path(git("rev-parse", "--show-toplevel")).resolve(), EXPECTED_ROOT.resolve(), "REPOSITORY_ROOT")
    exact(git("remote", "get-url", "origin"), EXPECTED_REMOTE, "REPOSITORY_REMOTE")
    exact(git("branch", "--show-current"), "main", "REPOSITORY_BRANCH")
    head = git("rev-parse", "HEAD")
    tree = git("rev-parse", "HEAD^{tree}")
    if require_committed:
        exact(git("rev-parse", "HEAD^"), EXPECTED_PARENT, "FREEZE_PARENT")
        for relative in SOURCE_RELATIVES:
            path = relative.as_posix()
            exact(
                git("hash-object", "--", path),
                git("rev-parse", f"HEAD:{path}"),
                f"UNCOMMITTED_SOURCE:{path}",
            )
    else:
        exact(head, EXPECTED_PARENT, "PROSPECTIVE_PARENT")
        exact(tree, EXPECTED_PARENT_TREE, "PROSPECTIVE_PARENT_TREE")
    return head, tree


def main() -> int:
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--allow-prospective-uncommitted", action="store_true")
    mode.add_argument("--require-committed-source", action="store_true")
    args = parser.parse_args()

    require(EXPECTED_ROOT.is_dir(), "EXPECTED_ROOT_MISSING")
    head, tree = validate_repository(args.require_committed_source)
    contract = read_json(CONTRACT_RELATIVE)
    validate_contract(contract)
    exact(sha256(PREDECESSOR_RELATIVE), EXPECTED_PREDECESSOR_SHA256, "LIVE_PREDECESSOR_SHA")
    exact(len(read_bytes(PREDECESSOR_RELATIVE)), EXPECTED_PREDECESSOR_BYTES, "LIVE_PREDECESSOR_BYTES")
    exact(git("hash-object", "--", PREDECESSOR_RELATIVE.as_posix()), EXPECTED_PREDECESSOR_BLOB, "LIVE_PREDECESSOR_BLOB")
    exact(sha256(STOCK_MAPPING_RELATIVE), EXPECTED_STOCK_SHA256, "LIVE_STOCK_SHA")
    exact(len(read_bytes(STOCK_MAPPING_RELATIVE)), EXPECTED_STOCK_BYTES, "LIVE_STOCK_BYTES")
    exact(git("hash-object", "--", STOCK_MAPPING_RELATIVE.as_posix()), EXPECTED_STOCK_BLOB, "LIVE_STOCK_BLOB")
    validate_source_texts(
        read_text(MAPPING_RELATIVE),
        read_text(WORKER_RELATIVE),
        read_text(RUNNER_RELATIVE),
    )
    mutation_rejections = run_mutations(contract)
    print(
        "QSDK_R24D16_PROFILE_CAPABILITY_SOURCE_PASS "
        f"mode={'committed' if args.require_committed_source else 'prospective'} "
        f"head={head} tree={tree} source_bindings={len(SOURCE_RELATIVES)} "
        f"contract_mutations={mutation_rejections}/8 "
        "profile_channels=10/10 fallback_channels=8/10 "
        "worlds=0 builds=0 solver_steps=0"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AuditError, KeyError, TypeError, ValueError, json.JSONDecodeError) as exc:
        print(f"QSDK_R24D16_PROFILE_CAPABILITY_SOURCE_FAIL {exc}", file=sys.stderr)
        raise SystemExit(1) from exc
