#!/usr/bin/env python3
"""Zero-world source audit for the R24D10 v2 production supervisor.

This audit parses declarations, manifests, immutable refusal evidence, and
source bytes only. It never launches Godot or constructs physics.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import re
import subprocess
from pathlib import Path
from typing import Any, NoReturn


ROOT = Path(__file__).resolve().parents[1]
CONTRACT_REL = (
    "sdk/recovery/r24d10_godot_jolt_exact_step_numerical_telemetry_"
    "physical_supervisor_contract_v2.json"
)
MANIFEST_REL = (
    "sdk/recovery/r24d10_godot_jolt_exact_step_numerical_telemetry_"
    "physical_supervisor_manifest_v2.json"
)
SUPERVISOR_REL = (
    "sdk/run_qsdk_r24d10_exact_step_numerical_telemetry_characterization.ps1"
)
REFUSAL_REL = (
    "sdk/recovery/"
    "r24d10_first_physical_supervisor_qualification_adoption_refusal_v1.json"
)
REFUSAL_AUDIT_REL = (
    "tests/test_qsdk_r24d10_first_physical_supervisor_"
    "qualification_adoption_refusal.py"
)
EXPECTED_ZERO_SOURCE = "11df9b566dda911c6c3f1a8ad76369c8ee0c340e"
EXPECTED_ZERO_RECEIPT = (
    "sha256:093db061d3bb4799c4ac6a0a4c30364031297aee4b27608ef797cea05c6bb34f"
)
EXPECTED_V1_SOURCE = "be6365cea71351519c796cefa4ec3900eed77539"
EXPECTED_REFUSAL = (
    "sha256:10d3e7a5e1d6215ddfd917e7b6b55522f75cfe73265dcd6b02ab23d711a03cf5"
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
    REFUSAL_REL,
    REFUSAL_AUDIT_REL,
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
    "physical_supervisor_source_v2.py",
}


def fail(code: str) -> NoReturn:
    raise SystemExit(f"QSDK-R24D10 v2 physical supervisor source audit: {code}")


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


def validate_refusal(refusal: dict[str, Any]) -> None:
    exact(
        refusal.get("schema_version"),
        "sporespore_qsdk_r24d10_first_physical_supervisor_"
        "qualification_adoption_refusal_v1",
        "refusal_schema",
    )
    exact(refusal.get("question_class"), "development", "refusal_question")
    source = mapping(refusal.get("source"), "refusal_source")
    exact(source.get("commit"), EXPECTED_V1_SOURCE, "refusal_source_commit")
    qualification = mapping(refusal.get("qualification"), "refusal_qualification")
    exact(qualification.get("stage_count"), 6, "refusal_stage_count")
    exact(qualification.get("world_attempt_count"), 0, "refusal_worlds")
    exact(
        qualification.get("qualification_is_adoptable_by_v1_transition"),
        False,
        "refusal_adoptable",
    )
    decision = mapping(refusal.get("adoption_refusal"), "refusal_decision")
    exact(
        decision.get("failure_class"),
        "prospective_integration_authorization_transition_invalid",
        "refusal_class",
    )
    exact(decision.get("physical_mode_invoked"), False, "refusal_physical")
    exact(decision.get("world_opened"), False, "refusal_world_opened")
    successor = mapping(refusal.get("successor_boundary"), "refusal_successor")
    exact(successor.get("distinct_v2_supervisor_required"), True, "refusal_v2")
    exact(
        successor.get("complete_v2_zero_world_preflight_required"),
        True,
        "refusal_v2_preflight",
    )


def validate_contract(contract: dict[str, Any]) -> None:
    exact(
        contract.get("schema_version"),
        "sporespore_qsdk_r24d10_physical_supervisor_contract_v2",
        "contract_schema",
    )
    exact(contract.get("gate_id"), "QSDK-R24D10", "contract_gate")
    exact(contract.get("question_class"), "development", "question_class")
    exact(
        contract.get("status"),
        "prospective_physical_supervisor_v2_parent_bound_transition_"
        "implemented_preflight_pending_physics_forbidden",
        "contract_status",
    )
    if len(str(contract.get("successor_reason", ""))) < 350:
        fail("successor_reason")
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
    exact(
        authority.get("immutable_v1_qualification_adoption_refusal_raw_sha256"),
        EXPECTED_REFUSAL,
        "refusal_sha",
    )
    exact(
        authority.get("qualification_positive_closure_exists"),
        False,
        "qualification_closure",
    )
    exact(authority.get("physical_authorization_exists"), False, "authorization")

    runtime = mapping(contract.get("runtime_identity"), "runtime_identity")
    exact(runtime.get("executed_console_binary_raw_sha256"), EXPECTED_CONSOLE, "console")
    exact(runtime.get("executed_engine_binary_raw_sha256"), EXPECTED_ENGINE, "engine")
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
    exact(runtime.get("solver_setting_substitution_allowed"), False, "solver_substitution")
    exact(runtime.get("rebuild_required_for_supervisor_preflight"), False, "rebuild")

    schedule = mapping(contract.get("physical_schedule"), "schedule")
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
    exact(
        mapping(schedule.get("native_space_step_tokens"), "tokens"),
        {"first": 1, "last": 20, "count": 20},
        "token_schedule",
    )

    preflight = mapping(contract.get("supervisor_preflight"), "preflight")
    for key in (
        "immutable_v1_adoption_refusal_audit_required",
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
    exact(preflight.get("declared_stage_count"), 7, "preflight_stage_count")
    exact(preflight.get("separate_shortened_physics_ghost_required"), False, "ghost")
    if len(str(preflight.get("ghost_adequacy_argument", ""))) < 400:
        fail("ghost_adequacy_argument")

    adequacy = mapping(contract.get("evidence_adequacy"), "adequacy")
    for key in (
        "threshold_count",
        "margin_count",
        "held_out_cohort_count",
        "population_claim_count",
    ):
        exact(adequacy.get(key), 0, f"adequacy_{key}")
    if len(str(adequacy.get("adequacy_argument", ""))) < 350:
        fail("evidence_adequacy_argument")

    authorization = mapping(contract.get("authorization_boundary"), "auth_boundary")
    exact(authorization.get("physical_execution_authorized"), False, "physical_auth")
    for key in (
        "clean_pushed_v2_supervisor_freeze_required",
        "complete_v2_supervisor_preflight_required",
        "immutable_v2_preflight_closure_required",
        "separate_exact_authorization_commit_required",
        "authorization_commit_must_be_direct_single_parent_child_of_qualified_source",
        "authorization_commit_identity_derived_from_current_head",
        "authorization_json_must_not_embed_its_own_commit_identity",
        "production_authorization_only_check_supported_before_attempt",
        "authorization_must_bind_supervisor_blob_across_parent_edge",
        "authorization_must_bind_manifest_blob_across_parent_edge",
        "authorization_must_bind_preflight_receipt",
        "authorization_must_bind_preflight_closure",
        "authorization_must_bind_executed_binary_pair",
        "one_attempt_only",
    ):
        exact(authorization.get(key), True, f"authorization_{key}")

    claims = mapping(contract.get("claims"), "claims")
    exact(claims.get("v1_physical_supervisor_preflight_passed"), True, "v1_pass")
    exact(claims.get("v1_adoption_refused"), True, "v1_refused")
    exact(claims.get("v2_physical_supervisor_source_implemented"), True, "v2_source")
    for key in (
        "v2_physical_supervisor_preflight_passed",
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
        "sporespore_qsdk_r24d10_physical_supervisor_manifest_v2",
        "manifest_schema",
    )
    exact(manifest.get("gate_id"), "QSDK-R24D10", "manifest_gate")
    exact(manifest.get("question_class"), "development", "manifest_question")
    exact(
        manifest.get("status"),
        "prospective_physical_supervisor_v2_parent_bound_source_frozen_"
        "preflight_pending",
        "manifest_status",
    )
    exact(manifest.get("includes_self"), False, "manifest_self")
    exact(manifest.get("zero_world_source_commit"), EXPECTED_ZERO_SOURCE, "manifest_zero")
    exact(manifest.get("v1_refusal_source_commit"), EXPECTED_V1_SOURCE, "manifest_refusal_source")
    exact(manifest.get("v1_refusal_raw_sha256"), EXPECTED_REFUSAL, "manifest_refusal")
    exact(manifest.get("executed_console_binary_raw_sha256"), EXPECTED_CONSOLE, "manifest_console")
    exact(manifest.get("executed_engine_binary_raw_sha256"), EXPECTED_ENGINE, "manifest_engine")
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
        "declared_preflight_stage_count": 7,
        "threshold_count": 0,
        "margin_count": 0,
        "population_claim_count": 0,
    }.items():
        exact(manifest.get(key), expected, f"manifest_{key}")
    for key in (
        "v2_preflight_passed",
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
        sha, length = raw_receipt(ROOT / relative)
        exact(binding.get("raw_sha256"), sha, f"binding_sha:{relative}")
        exact(binding.get("byte_length"), length, f"binding_bytes:{relative}")
        working_blob = git("hash-object", relative)
        exact(binding.get("git_blob_oid"), working_blob, f"binding_blob:{relative}")
        if not allow_prospective_uncommitted:
            committed_blob = git("rev-parse", f"{head}:{relative}")
            exact(committed_blob, working_blob, f"binding_commit:{relative}")


def validate_supervisor_source(text: str) -> None:
    required_present = (
        '[ValidateSet("Preflight", "Authorization", "Physical")]',
        "physical_supervisor_contract_v2.json",
        "physical_supervisor_manifest_v2.json",
        "physical_authorization_v2.json",
        "physical_supervisor_qualification_positive_closure_v2.json",
        "physical_supervisor_source_v2.py",
        "immutable_r24d10_v1_adoption_refusal_recheck",
        "authorization_commit_must_have_exactly_one_parent",
        "physical_switch_forbidden_in_authorization_check",
        "authorization_commit_derived_from_current_head",
        "authorization_parent_commit",
        '-not $authorization.Contains("authorization_commit")',
        "$parentBlob -ceq $currentBlob",
        "$parentManifestBlob -ceq $currentManifestBlob",
        "qualification_closure_raw_sha256",
        "Assert-R24D10QualificationClosure",
        "Assert-R24D10PhysicalAuthorization",
        "explicit_run_physical_switch_required",
        "same_source_preflight_attempt_already_consumed",
        "same_authorization_binary_pair_physical_attempt_already_consumed",
        "Assert-R24D10SupervisorRepositoryBoundary",
        "Assert-R24D10SupervisorManifest",
        "Assert-R24D10ZeroWorldClosure",
        "Assert-R24D10QualificationReceipt",
        "Invoke-SporeSporeGodotReceiptTerminatedProcess",
        "Publish-SporeSporeContentAddressedArtifact",
        "QSDK_R24D10_PHYSICAL_SUPERVISOR_PREFLIGHT_PASS",
        "QSDK_R24D10_PHYSICAL_AUTHORIZATION_CHECK_PASS",
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
    mode_switch_guard = re.compile(
        r'if \(\$Mode -ceq "Physical"\) \{\s*'
        r'Assert-R24D10Supervisor \(\$RunPhysical\) '
        r'"explicit_run_physical_switch_required"\s*\}\s*else \{\s*'
        r'Assert-R24D10Supervisor \(-not \$RunPhysical\) \(\s*'
        r'"physical_switch_forbidden_in_authorization_check"\s*\)\s*\}',
        re.MULTILINE,
    )
    if mode_switch_guard.search(text) is None:
        fail("supervisor_mode_switch_guard")
    for guard_code in (
        "explicit_run_physical_switch_required",
        "physical_switch_forbidden_in_authorization_check",
    ):
        if text.count(guard_code) != 1:
            fail(f"supervisor_unique_mode_guard:{guard_code}:{text.count(guard_code)}")
    for forbidden in (
        '[string]$authorization.authorization_commit -ceq $Head',
        '"physical_authorization_v1.json"',
        "qualification_receipt_v1",
        "physical_attempt_v1",
        "physical_receipt_v1",
    ):
        if forbidden in text:
            fail(f"supervisor_forbidden:{forbidden}")
    for token in (
        "QSDK_R24D10_PHYSICAL_SUPERVISOR_PREFLIGHT_PASS",
        "QSDK_R24D10_PHYSICAL_AUTHORIZATION_CHECK_PASS",
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
        (("authority_chain", "qualification_positive_closure_exists"), True),
        (("runtime_identity", "executed_console_binary_raw_sha256"), EXPECTED_TOOLCHAIN_CONSOLE),
        (("runtime_identity", "runtime_substitution_allowed"), True),
        (("physical_schedule", "world_count"), 2),
        (("physical_schedule", "solver_step_count"), 2),
        (("physical_schedule", "same_source_physical_rerun_allowed"), True),
        (("supervisor_preflight", "immutable_v1_adoption_refusal_audit_required"), False),
        (("supervisor_preflight", "separate_shortened_physics_ghost_required"), True),
        (("evidence_adequacy", "threshold_count"), 1),
        (("authorization_boundary", "physical_execution_authorized"), True),
        (("authorization_boundary", "authorization_commit_must_be_direct_single_parent_child_of_qualified_source"), False),
        (("authorization_boundary", "authorization_json_must_not_embed_its_own_commit_identity"), False),
        (("authorization_boundary", "production_authorization_only_check_supported_before_attempt"), False),
        (("claims", "v2_physical_supervisor_preflight_passed"), True),
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

    exact(Path(git("rev-parse", "--show-toplevel")).resolve(), ROOT.resolve(), "root")
    exact(
        git("remote", "get-url", "origin"),
        "https://github.com/Slagathore/sporespore.git",
        "remote",
    )
    contract = load_json(CONTRACT_REL)
    refusal = load_json(REFUSAL_REL)
    manifest = load_json(MANIFEST_REL)
    validate_refusal(refusal)
    exact(raw_receipt(ROOT / REFUSAL_REL)[0], EXPECTED_REFUSAL, "refusal_raw_sha")
    validate_contract(contract)
    validate_manifest(
        manifest,
        allow_prospective_uncommitted=args.allow_prospective_uncommitted,
    )
    supervisor_text = (ROOT / SUPERVISOR_REL).read_text(encoding="utf-8")
    validate_supervisor_source(supervisor_text)
    rejected = mutation_controls(contract)
    print(
        "QSDK_R24D10_PHYSICAL_SUPERVISOR_SOURCE_V2_PASS "
        f"bindings={len(EXPECTED_BINDINGS)} mutations={rejected} "
        "worlds=0 builds=0 solver_steps=0 physical_authority=false"
    )


if __name__ == "__main__":
    main()
