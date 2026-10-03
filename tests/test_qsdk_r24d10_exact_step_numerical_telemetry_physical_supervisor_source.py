#!/usr/bin/env python3
"""Zero-world source audit for the R24D10 production supervisor.

This audit parses declarations and source bytes only. It does not launch Godot,
construct a physics object, or create a retained campaign attempt.
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
CONTRACT_REL = (
    "sdk/recovery/r24d10_godot_jolt_exact_step_numerical_telemetry_"
    "physical_supervisor_contract_v1.json"
)
MANIFEST_REL = (
    "sdk/recovery/r24d10_godot_jolt_exact_step_numerical_telemetry_"
    "physical_supervisor_manifest_v1.json"
)
SUPERVISOR_REL = (
    "sdk/run_qsdk_r24d10_exact_step_numerical_telemetry_characterization.ps1"
)
EXPECTED_ZERO_SOURCE = "11df9b566dda911c6c3f1a8ad76369c8ee0c340e"
EXPECTED_ZERO_RECEIPT = (
    "sha256:093db061d3bb4799c4ac6a0a4c30364031297aee4b27608ef797cea05c6bb34f"
)
EXPECTED_CONSOLE = (
    "sha256:ff655a567d31f51628d5b21742a0618e53f9fbf8a94937dd07d9882a0739872f"
)
EXPECTED_ENGINE = (
    "sha256:2d68ed7ae53704ffb532cd5633241c74d599d69e3bf1968de0ef261553030ffb"
)
EXPECTED_TOOLCHAIN_CONSOLE = (
    "sha256:8a629f16859f653d447cd7f07f712f0045a1aed3f27be53413d97df6ff1ec0e6"
)
EXPECTED_TOOLCHAIN_ENGINE = (
    "sha256:0d77df42106c6d2f6fa51727d8051bf403e8a0273b3242daee581c93c4ba7257"
)
EXPECTED_BINDINGS = {
    ".gitattributes",
    "sdk/recovery/r24d10_godot_jolt_exact_step_numerical_telemetry_"
    "characterization_preregistration_v1.json",
    "sdk/recovery/r24d10_godot_jolt_exact_step_numerical_telemetry_"
    "zero_world_positive_closure_v1.json",
    "tests/test_qsdk_r24d10_exact_step_numerical_telemetry_"
    "zero_world_positive_closure.ps1",
    "tests/test_qsdk_r24d10_exact_step_numerical_telemetry_"
    "zero_world_positive_closure.py",
    CONTRACT_REL,
    "sdk/recovery/r24d9_godot_jolt_one_hinge_numerical_telemetry_"
    "characterization_evaluator.py",
    "scripts/lab/rigs/r24d9_godot_jolt_one_hinge_numerical_telemetry_rig.gd",
    "tests/test_sdk_qsdk_r24d9_godot_jolt_one_hinge_numerical_telemetry_"
    "worker.gd",
    "sdk/recovery/r24d10_godot_jolt_exact_step_numerical_telemetry_"
    "characterization_evaluator.py",
    "scripts/lab/rigs/r24d10_godot_jolt_exact_step_numerical_telemetry_rig.gd",
    "tests/test_sdk_qsdk_r24d10_godot_jolt_exact_step_numerical_telemetry_"
    "worker.gd",
    SUPERVISOR_REL,
    "sdk/locomotion_operation_lock.ps1",
    "sdk/godot_receipt_terminated_process.ps1",
    "sdk/content_addressed_artifact_store.ps1",
    "tests/test_qsdk_r24d10_exact_step_numerical_telemetry_"
    "physical_supervisor_source.py",
}


def fail(code: str) -> NoReturn:
    raise SystemExit(f"QSDK-R24D10 physical supervisor source audit: {code}")


def load_json(relative: str) -> dict[str, Any]:
    try:
        value = json.loads((ROOT / relative).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        fail(f"json:{relative}:{exc}")
    if not isinstance(value, dict):
        fail(f"json_object:{relative}")
    return value


def mapping(value: Any, code: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        fail(code)
    return value


def exact(value: Any, expected: Any, code: str) -> None:
    if type(value) is not type(expected) or value != expected:
        fail(code)


def git(*arguments: str) -> str:
    run = subprocess.run(
        ["git", "-C", str(ROOT), *arguments],
        check=False,
        capture_output=True,
        text=True,
    )
    if run.returncode != 0:
        fail(f"git:{'_'.join(arguments)}:{run.stderr.strip()}")
    return run.stdout.strip()


def raw_receipt(path: Path) -> tuple[str, int]:
    try:
        payload = path.read_bytes()
    except OSError as exc:
        fail(f"file:{path}:{exc}")
    return "sha256:" + hashlib.sha256(payload).hexdigest(), len(payload)


def validate_contract(contract: dict[str, Any]) -> None:
    exact(
        contract.get("schema_version"),
        "sporespore_qsdk_r24d10_physical_supervisor_contract_v1",
        "contract_schema",
    )
    exact(contract.get("gate_id"), "QSDK-R24D10", "contract_gate")
    exact(contract.get("question_class"), "development", "question_class")
    exact(
        contract.get("status"),
        "prospective_physical_supervisor_source_implemented_preflight_"
        "pending_physics_forbidden",
        "contract_status",
    )
    authority = mapping(contract.get("authority_chain"), "authority_chain")
    exact(
        authority.get("immutable_zero_world_source_commit"),
        EXPECTED_ZERO_SOURCE,
        "zero_source",
    )
    exact(
        authority.get("immutable_zero_world_receipt_raw_sha256"),
        EXPECTED_ZERO_RECEIPT,
        "zero_receipt",
    )
    exact(authority.get("physical_authorization_exists"), False, "authorization")

    runtime = mapping(contract.get("runtime_identity"), "runtime_identity")
    exact(
        runtime.get("executed_console_binary_raw_sha256"),
        EXPECTED_CONSOLE,
        "executed_console",
    )
    exact(
        runtime.get("executed_engine_binary_raw_sha256"),
        EXPECTED_ENGINE,
        "executed_engine",
    )
    exact(
        runtime.get("report_embedded_toolchain_console_binary_raw_sha256"),
        EXPECTED_TOOLCHAIN_CONSOLE,
        "toolchain_console",
    )
    exact(
        runtime.get("report_embedded_toolchain_engine_binary_raw_sha256"),
        EXPECTED_TOOLCHAIN_ENGINE,
        "toolchain_engine",
    )
    exact(
        runtime.get("toolchain_provenance_is_not_executed_binary_identity"),
        True,
        "runtime_identity_separation",
    )
    exact(runtime.get("runtime_substitution_allowed"), False, "runtime_substitution")
    exact(
        runtime.get("solver_setting_substitution_allowed"),
        False,
        "solver_substitution",
    )
    exact(
        runtime.get("rebuild_required_for_supervisor_preflight"),
        False,
        "precise_reuse",
    )

    schedule = mapping(contract.get("physical_schedule"), "physical_schedule")
    for key, expected in {
        "world_count": 1,
        "fixture_cell_count": 9,
        "solver_step_count": 20,
        "retained_sample_count": 68,
        "pre_sample_physics_frame_count": 0,
        "terminal_physics_server_deactivation_count": 1,
        "same_source_physical_attempt_limit": 1,
    }.items():
        exact(schedule.get(key), expected, f"schedule_{key}")
    exact(schedule.get("same_source_physical_rerun_allowed"), False, "rerun")
    exact(schedule.get("selective_cell_rerun_allowed"), False, "selective_rerun")
    exact(schedule.get("early_stop_allowed"), False, "early_stop")
    tokens = mapping(schedule.get("native_space_step_tokens"), "tokens")
    exact(tokens, {"first": 1, "last": 20, "count": 20}, "token_schedule")

    preflight = mapping(contract.get("supervisor_preflight"), "supervisor_preflight")
    for key in (
        "complete_zero_world_closure_recheck_required",
        "source_manifest_audit_required",
        "inherited_evaluator_negative_controls_required",
        "real_custom_runtime_zero_object_worker_required",
        "same_production_project_staging_required",
        "same_production_worker_required",
        "same_production_evaluator_required",
        "same_supervisor_termination_protocol_required",
        "same_content_addressed_retention_required",
    ):
        exact(preflight.get(key), True, f"preflight_{key}")
    for key in ("world_attempt_count", "world_build_count", "solver_step_count"):
        exact(preflight.get(key), 0, f"preflight_{key}")
    exact(
        preflight.get("separate_shortened_physics_ghost_required"),
        False,
        "short_ghost",
    )
    if len(str(preflight.get("ghost_adequacy_argument", ""))) < 300:
        fail("ghost_adequacy_argument")

    adequacy = mapping(contract.get("evidence_adequacy"), "evidence_adequacy")
    for key in (
        "threshold_count",
        "margin_count",
        "held_out_cohort_count",
        "population_claim_count",
    ):
        exact(adequacy.get(key), 0, f"adequacy_{key}")
    if len(str(adequacy.get("adequacy_argument", ""))) < 300:
        fail("evidence_adequacy_argument")

    authorization = mapping(
        contract.get("authorization_boundary"), "authorization_boundary"
    )
    exact(authorization.get("physical_execution_authorized"), False, "physical_auth")
    for key in (
        "clean_pushed_supervisor_freeze_required",
        "complete_supervisor_preflight_required",
        "immutable_preflight_closure_required",
        "separate_exact_authorization_commit_required",
        "one_attempt_only",
        "authorization_must_bind_supervisor_blob",
        "authorization_must_bind_preflight_receipt",
        "authorization_must_bind_executed_binary_pair",
    ):
        exact(authorization.get(key), True, f"authorization_{key}")

    claims = mapping(contract.get("claims"), "claims")
    exact(claims.get("physical_supervisor_source_implemented"), True, "implemented")
    for key in (
        "physical_supervisor_preflight_passed",
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


def validate_manifest(
    manifest: dict[str, Any], *, allow_prospective_uncommitted: bool
) -> None:
    exact(
        manifest.get("schema_version"),
        "sporespore_qsdk_r24d10_physical_supervisor_manifest_v1",
        "manifest_schema",
    )
    exact(manifest.get("gate_id"), "QSDK-R24D10", "manifest_gate")
    exact(manifest.get("question_class"), "development", "manifest_question")
    exact(
        manifest.get("status"),
        "prospective_physical_supervisor_source_frozen_preflight_pending",
        "manifest_status",
    )
    exact(manifest.get("includes_self"), False, "manifest_self")
    exact(manifest.get("zero_world_source_commit"), EXPECTED_ZERO_SOURCE, "manifest_zero")
    exact(
        manifest.get("executed_console_binary_raw_sha256"),
        EXPECTED_CONSOLE,
        "manifest_console",
    )
    exact(
        manifest.get("executed_engine_binary_raw_sha256"),
        EXPECTED_ENGINE,
        "manifest_engine",
    )
    exact(
        manifest.get("lineage_toolchain_console_binary_raw_sha256"),
        EXPECTED_TOOLCHAIN_CONSOLE,
        "manifest_toolchain_console",
    )
    exact(
        manifest.get("lineage_toolchain_engine_binary_raw_sha256"),
        EXPECTED_TOOLCHAIN_ENGINE,
        "manifest_toolchain_engine",
    )
    for key, expected in {
        "declared_world_count": 1,
        "declared_cell_count": 9,
        "declared_solver_step_count": 20,
        "declared_retained_sample_count": 68,
        "threshold_count": 0,
        "margin_count": 0,
        "population_claim_count": 0,
    }.items():
        exact(manifest.get(key), expected, f"manifest_{key}")
    for key in (
        "physical_authorization",
        "physical_characterization_executed",
        "physical_acceptance_authority",
        "release_authority",
    ):
        exact(manifest.get(key), False, f"manifest_{key}")

    bindings = manifest.get("source_bindings")
    if not isinstance(bindings, list):
        fail("manifest_bindings")
    exact(manifest.get("source_binding_count"), len(bindings), "binding_count")
    paths = [str(mapping(item, "binding_object").get("path")) for item in bindings]
    if len(paths) != len(set(paths)) or set(paths) != EXPECTED_BINDINGS:
        fail("binding_population")
    head = git("rev-parse", "HEAD")
    for item in bindings:
        binding = mapping(item, "binding")
        relative = str(binding.get("path"))
        path = ROOT / relative
        sha, length = raw_receipt(path)
        exact(binding.get("raw_sha256"), sha, f"binding_sha:{relative}")
        exact(binding.get("byte_length"), length, f"binding_bytes:{relative}")
        working_blob = git("hash-object", relative)
        exact(binding.get("git_blob_oid"), working_blob, f"binding_blob:{relative}")
        if not allow_prospective_uncommitted:
            committed_blob = git("rev-parse", f"{head}:{relative}")
            exact(committed_blob, working_blob, f"binding_commit:{relative}")


def validate_supervisor_source(text: str) -> None:
    required_present = (
        '[ValidateSet("Preflight", "Physical")]',
        "explicit_run_physical_switch_required",
        "same_source_preflight_attempt_already_consumed",
        "same_authorization_binary_pair_physical_attempt_already_consumed",
        "Assert-R24D10SupervisorRepositoryBoundary",
        "Assert-R24D10SupervisorManifest",
        "Assert-R24D10ZeroWorldClosure",
        "Assert-R24D10QualificationReceipt",
        "Assert-R24D10PhysicalAuthorization",
        "Invoke-SporeSporeGodotReceiptTerminatedProcess",
        "Publish-SporeSporeContentAddressedArtifact",
        "QSDK_R24D10_PHYSICAL_SUPERVISOR_PREFLIGHT_PASS",
        "QSDK_R24D10_EXACT_STEP_PHYSICAL_RESULT",
        "--mode=$WorkerMode",
        '"zero_world_preflight", "physical"',
        '"--expected-evidence-kind", $EvidenceKind',
        "consumed_before_worker_launch",
        "consumed_physical_attempt_failed_or_incomplete",
    )
    for token in required_present:
        if token not in text:
            fail(f"supervisor_token:{token}")
    for token in (
        "QSDK_R24D10_PHYSICAL_SUPERVISOR_PREFLIGHT_PASS",
        "QSDK_R24D10_EXACT_STEP_PHYSICAL_RESULT",
    ):
        if text.count(token) != 1:
            fail(f"supervisor_unique_token:{token}:{text.count(token)}")
    for digest in (
        EXPECTED_CONSOLE[7:],
        EXPECTED_ENGINE[7:],
        EXPECTED_TOOLCHAIN_CONSOLE[7:],
        EXPECTED_TOOLCHAIN_ENGINE[7:],
    ):
        if text.count(digest) != 1:
            fail(f"supervisor_digest:{digest}")
    if "-TimeoutSeconds 180" not in text:
        fail("supervisor_timeout")
    if "world_attempt_count = 1" not in text or "solver_step_count = 20" not in text:
        fail("supervisor_physical_counts")
    if "physical_acceptance_authority = $false" not in text:
        fail("supervisor_nonclaim")


def mutation_controls(contract: dict[str, Any]) -> int:
    mutations: list[tuple[tuple[str, ...], Any]] = [
        (("question_class",), "finite_decision"),
        (("authority_chain", "physical_authorization_exists"), True),
        (("runtime_identity", "executed_console_binary_raw_sha256"), EXPECTED_TOOLCHAIN_CONSOLE),
        (("runtime_identity", "runtime_substitution_allowed"), True),
        (("physical_schedule", "world_count"), 2),
        (("physical_schedule", "solver_step_count"), 2),
        (("physical_schedule", "same_source_physical_rerun_allowed"), True),
        (("supervisor_preflight", "real_custom_runtime_zero_object_worker_required"), False),
        (("supervisor_preflight", "separate_shortened_physics_ghost_required"), True),
        (("evidence_adequacy", "threshold_count"), 1),
        (("authorization_boundary", "physical_execution_authorized"), True),
        (("claims", "release_authority"), True),
    ]
    rejected = 0
    for path, replacement in mutations:
        candidate = copy.deepcopy(contract)
        target: dict[str, Any] = candidate
        for key in path[:-1]:
            target = mapping(target[key], "mutation_path")
        target[path[-1]] = replacement
        try:
            validate_contract(candidate)
        except SystemExit:
            rejected += 1
        else:
            fail(f"mutation_accepted:{'.'.join(path)}")
    return rejected


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--allow-prospective-uncommitted", action="store_true")
    args = parser.parse_args()

    root = git("rev-parse", "--show-toplevel")
    remote = git("remote", "get-url", "origin")
    exact(Path(root).resolve(), ROOT.resolve(), "repository_root")
    exact(remote, "https://github.com/Slagathore/sporespore.git", "repository_remote")

    contract = load_json(CONTRACT_REL)
    manifest = load_json(MANIFEST_REL)
    validate_contract(contract)
    validate_manifest(
        manifest,
        allow_prospective_uncommitted=args.allow_prospective_uncommitted,
    )
    supervisor_text = (ROOT / SUPERVISOR_REL).read_text(encoding="utf-8")
    validate_supervisor_source(supervisor_text)
    rejected = mutation_controls(contract)
    print(
        "QSDK_R24D10_PHYSICAL_SUPERVISOR_SOURCE_PASS "
        f"bindings={len(EXPECTED_BINDINGS)} mutations={rejected} "
        "worlds=0 builds=0 solver_steps=0 physical_authority=false"
    )


if __name__ == "__main__":
    main()
