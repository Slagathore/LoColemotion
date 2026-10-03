#!/usr/bin/env python3
"""Zero-world source authority for R91 wrapper-reachable recovery behavior."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance import godot_recovery_route_zero_world_controls as controls  # noqa: E402
from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError,
    exact,
    load,
    require,
    resolve_prospective_source_freeze,
    source_bytes,
    verify_bound_source_markers,
    verify_declared_source_inventory,
    verify_exact_paths,
    verify_legacy_live_authority_projection,
)

CONTRACT = ROOT / (
    "sdk/recovery/r24d91_godot_jolt_force_based_recovery_behavior_"
    "contract_v1.json"
)
CLOSURE = ROOT / (
    "sdk/recovery/r24d91_godot_jolt_force_based_recovery_behavior_"
    "zero_world_qualification_closure_v1.json"
)
R90_CLOSURE = ROOT / (
    "sdk/recovery/r24d90_godot_jolt_force_based_recovery_behavior_"
    "zero_world_qualification_closure_v1.json"
)
PHYSICAL_RUNNER = ROOT / (
    "sdk/run_qsdk_r24d91_godot_jolt_force_based_recovery_behavior.ps1"
)
R90_PHYSICAL_RUNNER = (
    "sdk/run_qsdk_r24d90_godot_jolt_force_based_recovery_behavior.ps1"
)
QUALIFICATION_RUNNER = (
    "sdk/run_qsdk_r24d91_godot_jolt_force_based_recovery_behavior_"
    "zero_world_qualification.ps1"
)
WORKER = "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
SUPERVISOR = "sdk/run_qsdk_r24d57_godot_native_recovery_route_ghost.ps1"
AUTHORIZATION_HELPER = "sdk/physical_authorization_projection.ps1"
SOURCE_MARKER = (
    "QSDK_R24D91_GODOT_JOLT_FORCE_BASED_RECOVERY_BEHAVIOR_SOURCE_PASS"
)
SUPERVISOR_MARKER = "QSDK_R24D91_FORCE_BASED_RECOVERY_BEHAVIOR_SUPERVISOR "
RUNTIME_IDENTITY_SCHEMA = (
    "sporespore_qsdk_r24d91_force_based_behavior_runtime_identity_v1"
)
SEED_LABEL = (
    "QSDK-R24D91/development/godot/"
    "r91-wrapper-control-reachability-exact-nominal-prone-to-standing-paired-v1"
)
SEED_SHA256 = (
    "sha256:83863edfdf6b22173c06da922784548f23f3a1350cea7340df7b8f2212ef6d2d"
)
PROSPECTIVE_STATUS = (
    "prospective_wrapper_authorization_control_reachability_recovery_behavior_"
    "complete_zero_world_qualification_required_physics_blocked"
)
R90_STATUS = (
    "closed_complete_zero_world_generic_authorization_dispatch_qualification_"
    "passed_precontrol_wrapper_mode_unreachable_no_control_or_physics_"
    "authorized_r91_required"
)
ACTUATOR_MODE = "force_based_joint_impulse_v1"
PROJECTION_SCHEMA = "sporespore_qsdk_r24d91_behavior_authorization_projection_v1"
CONTROL_SCHEMA = (
    "sporespore_qsdk_r24d91_published_closure_authorization_control_v1"
)
R90_SOURCE = "096cc62c41f3f413312b0fecb0d9715d16996ec7"
EVIDENCE_ROOT = Path(r"C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence")


def _one_marker(stdout: str, marker: str) -> dict[str, Any]:
    lines = [line for line in stdout.splitlines() if line.startswith(marker)]
    exact(len(lines), 1, "RUNTIME_IDENTITY_MARKER_COUNT")
    value = json.loads(lines[0][len(marker) :])
    require(isinstance(value, dict), "RUNTIME_IDENTITY_RECEIPT")
    return value


def _mode_validate_set(raw: bytes) -> tuple[str, ...]:
    match = re.search(
        r"\[ValidateSet\((.*?)\)\]\s*\[string\]\$Mode",
        raw.decode("utf-8"),
        flags=re.DOTALL,
    )
    require(match is not None, "MODE_VALIDATE_SET")
    assert match is not None
    return tuple(re.findall(r'"([^"]+)"', match.group(1)))


def _validate_predecessor(contract: dict[str, Any]) -> None:
    declarations = contract["bound_predecessors"]
    exact(len(declarations), 1, "PREDECESSOR_COUNT")
    declaration = declarations[0]
    raw = R90_CLOSURE.read_bytes()
    verify_exact_paths(
        declaration,
        {
            "gate_id": "QSDK-R24D90",
            "role": (
                "positive_zero_world_qualification_with_precontrol_wrapper_"
                "reachability_limit"
            ),
            "path": R90_CLOSURE.relative_to(ROOT).as_posix(),
            "byte_length": len(raw),
            "raw_sha256": "sha256:" + hashlib.sha256(raw).hexdigest(),
            "closure_status": R90_STATUS,
            "same_identity_rerun_permitted": False,
            "same_identity_requalification_permitted": False,
            "historical_result_rewritten": False,
        },
        "R90_PREDECESSOR_DECLARATION",
    )
    value = load(R90_CLOSURE)
    verify_exact_paths(
        value,
        {
            "closure_status": R90_STATUS,
            "qualification.official_zero_world_qualification_passed": True,
            "qualification.direct_authorization_dispatch_truth_table_case_count": 5,
            "qualification.model_construction_count": 0,
            "qualification.world_build_count": 0,
            "qualification.solver_step_count": 0,
            "post_qualification_reachability_diagnosis.required_authorization_control_mode_present": False,
            "post_qualification_reachability_diagnosis.authorization_control_receipt_count": 0,
            "decision.physical_behavior_attempt_authorized": False,
            "decision.distinct_r91_source_required": True,
            "claim_boundary.physical_attempted": False,
            "claim_boundary.prone_to_standing_claimed": False,
        },
        "R90_PREDECESSOR",
    )


def _validate_seed(contract: dict[str, Any]) -> None:
    question = contract["finite_behavior_question"]
    exact(question["seed_label"], SEED_LABEL, "SEED_LABEL")
    exact(
        "sha256:" + hashlib.sha256(SEED_LABEL.encode("utf-8")).hexdigest(),
        SEED_SHA256,
        "SEED_LABEL_HASH",
    )
    exact(
        (question["seed"], question["seed_sha256"]),
        (278151771, SEED_SHA256),
        "SEED_IDENTITY",
    )


def _run_dispatch_truth_table() -> dict[str, Any]:
    helper = (ROOT / AUTHORIZATION_HELPER).as_posix().replace("'", "''")
    script = f"""
. '{helper}'
$ghost = @{{ decision = @{{ physical_ghost_authorized = $true; physical_behavior_attempt_authorized = $false }} }}
$behavior = @{{ decision = @{{ physical_ghost_authorized = $false; physical_behavior_attempt_authorized = $true }} }}
$empty = @{{}}
$rows = @(
    [ordered]@{{ case = 'ghost_as_ghost'; observed = [bool](Test-SporeSporeDirectQuestionAuthorization -Closure $ghost -PhysicalQuestionKind 'integration_ghost'); expected = $true }},
    [ordered]@{{ case = 'ghost_as_behavior'; observed = [bool](Test-SporeSporeDirectQuestionAuthorization -Closure $ghost -PhysicalQuestionKind 'behavior_development'); expected = $false }},
    [ordered]@{{ case = 'behavior_as_ghost'; observed = [bool](Test-SporeSporeDirectQuestionAuthorization -Closure $behavior -PhysicalQuestionKind 'integration_ghost'); expected = $false }},
    [ordered]@{{ case = 'behavior_as_behavior'; observed = [bool](Test-SporeSporeDirectQuestionAuthorization -Closure $behavior -PhysicalQuestionKind 'behavior_development'); expected = $true }},
    [ordered]@{{ case = 'missing_decision'; observed = [bool](Test-SporeSporeDirectQuestionAuthorization -Closure $empty -PhysicalQuestionKind 'behavior_development'); expected = $false }}
)
[ordered]@{{ schema_version = 'sporespore_qsdk_r24d91_direct_authorization_dispatch_truth_table_v1'; rows = $rows }} | ConvertTo-Json -Depth 10 -Compress
"""
    completed = subprocess.run(
        ["pwsh", "-NoLogo", "-NoProfile", "-Command", script],
        cwd=ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="strict",
        check=False,
    )
    exact(completed.returncode, 0, "DISPATCH_EXIT")
    exact(completed.stderr, "", "DISPATCH_STDERR")
    lines = [line for line in completed.stdout.splitlines() if line.strip()]
    exact(len(lines), 1, "DISPATCH_OUTPUT_COUNT")
    receipt = json.loads(lines[0])
    exact(
        receipt["schema_version"],
        "sporespore_qsdk_r24d91_direct_authorization_dispatch_truth_table_v1",
        "DISPATCH_SCHEMA",
    )
    exact(len(receipt["rows"]), 5, "DISPATCH_CASE_COUNT")
    require(
        all(row["observed"] == row["expected"] for row in receipt["rows"]),
        "DISPATCH_TRUTH_TABLE",
    )
    return receipt


def _run_wrapper_reachability_refusal() -> dict[str, Any]:
    control_root = EVIDENCE_ROOT / (
        "qsdk-r24d91-godot-jolt-force-based-recovery-behavior-"
        "authorization-control"
    )
    require(not control_root.exists(), "PREEXISTING_R91_AUTHORIZATION_CONTROL_ROOT")
    completed = subprocess.run(
        [
            "pwsh",
            "-NoLogo",
            "-NoProfile",
            "-File",
            str(PHYSICAL_RUNNER),
            "-Mode",
            "AuthorizationControl",
        ],
        cwd=ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="strict",
        check=False,
    )
    exact(completed.returncode, 1, "WRAPPER_REACHABILITY_EXIT")
    exact(completed.stdout, "", "WRAPPER_REACHABILITY_STDOUT")
    require(
        "authorization_path_required" in completed.stderr,
        "WRAPPER_REACHABILITY_TERMINAL",
    )
    require(
        "ParameterArgumentValidationError" not in completed.stderr,
        "WRAPPER_REACHABILITY_PARAMETER_BINDING",
    )
    require(not control_root.exists(), "WRAPPER_REACHABILITY_EVIDENCE_ROOT")
    return {
        "schema_version": (
            "sporespore_qsdk_r24d91_authorization_control_wrapper_"
            "reachability_refusal_v1"
        ),
        "gate_id": "QSDK-R24D91",
        "ok": True,
        "mode": "AuthorizationControl",
        "expected_terminal": "authorization_path_required",
        "expected_terminal_observed": True,
        "powershell_parameter_binding_failure_observed": False,
        "operation_lock_acquired": False,
        "source_audit_and_runtime_preflight_count": 0,
        "authorization_control_receipt_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_question_opened": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def _normalize_r91_wrapper(raw: bytes) -> bytes:
    text = raw.decode("utf-8")
    text = text.replace(
        '"Preflight", "Physical", "ProjectionControl", '
        '"AuthorizationControl", "RuntimeIdentity"',
        '"Preflight", "Physical", "ProjectionControl", "RuntimeIdentity"',
    )
    text = text.replace("exact finite R90", "exact finite R89")
    text = text.replace("R24D91", "R24D90")
    text = text.replace("r24d91", "r24d90")
    text = text.replace("R91", "R90")
    text = text.replace("r91", "r90")
    text = text.replace(
        "r90-wrapper-control-reachability-exact-nominal-prone-to-standing-"
        "paired-v1",
        "r90-question-kind-dispatch-exact-nominal-prone-to-standing-paired-v1",
    )
    text = text.replace(
        "sha256:83863edfdf6b22173c06da922784548f23f3a1350cea7340df7b8f2212ef6d2d",
        "sha256:d0b6ae0f8eac299645e22176b53e20731b9d8a0ba677bacd6132feb9109e15c8",
    )
    return text.encode("utf-8")


def validate_sources() -> tuple[
    dict[str, Any], dict[str, int], bool, dict[str, Any], dict[str, Any]
]:
    contract = load(CONTRACT)
    controls.validate_development_question(contract, "QSDK-R24D91")
    verify_exact_paths(
        contract,
        {
            "schema_version": (
                "sporespore_qsdk_r24d91_godot_jolt_force_based_recovery_"
                "behavior_contract_v1"
            ),
            "status": PROSPECTIVE_STATUS,
            "authored_parent_commit": (
                "25ae24c7611f59bf768d76e850b5cc6dba64c4ee"
            ),
            "controlled_change.r90_complete_zero_world_qualification_bound": True,
            "controlled_change.r90_precontrol_wrapper_mode_reachability_limit_bound": True,
            "controlled_change.r90_behavior_question_reused_under_distinct_campaign": True,
            "controlled_change.r90_portable_recovery_controller_changed": False,
            "controlled_change.r90_portable_recovery_evaluator_changed": False,
            "controlled_change.r90_behavior_threshold_changed": False,
            "controlled_change.physical_wrapper_authorization_control_mode_added": True,
            "controlled_change.authorization_control_wrapper_reachability_refusal_added": True,
            "controlled_change.production_worker_changed": False,
            "controlled_change.native_route_or_world_changed": False,
            "controlled_change.additional_route_ghost_required": False,
            "controlled_change.additional_physical_canary_required": False,
            "finite_behavior_question.world_count": 2,
            "finite_behavior_question.maximum_outer_solver_steps": 2400,
            "finite_behavior_question.maximum_outer_solver_steps_per_arm": 1200,
            "finite_behavior_question.behavior_evaluator_invocation_count": 1,
            "behavior_execution_contract.actuator_mode": ACTUATOR_MODE,
            "critical_path_audit_policy.source_inventory_count": 63,
            "critical_path_audit_policy.qualified_physical_path_count": 47,
            "critical_path_audit_policy.authored_source_path_count": 10,
            "critical_path_audit_policy.bound_predecessor_count": 1,
            "critical_path_audit_policy.unchanged_behavior_semantics_binding_count": 8,
            "critical_path_audit_policy.direct_authorization_dispatch_truth_table_case_count": 5,
            "critical_path_audit_policy.authorization_control_wrapper_reachability_refusal_count": 1,
            "complete_zero_world_gate.production_worker_parse_count": 1,
            "complete_zero_world_gate.published_closure_authorization_control_required": True,
            "complete_zero_world_gate.model_construction_count": 0,
            "complete_zero_world_gate.world_build_count": 0,
            "complete_zero_world_gate.solver_step_count": 0,
            "physical_runner.physical_question_kind": "behavior_development",
            "physical_runner.authorization_projection_schema": PROJECTION_SCHEMA,
            "physical_runner.authorization_control_schema": CONTROL_SCHEMA,
            "physical_runner.published_closure_authorization_control_required": True,
            "physical_authorization_projection.physics_ticks_per_second": 120,
            "physical_authorization_projection.maximum_world_build_count": 2,
            "physical_authorization_projection.maximum_outer_solver_steps": 2400,
            "physical_authorization_projection.physical_execution_authorized": False,
            "claim_boundary.complete_zero_world_gate_passed": False,
            "claim_boundary.prone_to_standing_claimed": False,
            "sdk_status.sdk1_completed_steps": 11,
            "sdk_status.sdk1_total_steps": 20,
        },
        "CONTRACT",
    )
    _validate_seed(contract)
    _validate_predecessor(contract)

    source_commit, published = resolve_prospective_source_freeze(
        root=ROOT,
        contract=contract,
        closure_path=CLOSURE,
        closure_schema=(
            "sporespore_qsdk_r24d91_godot_jolt_force_based_recovery_behavior_"
            "zero_world_qualification_closure_v1"
        ),
        gate_id="QSDK-R24D91",
    )
    semantics_source = str(contract["unchanged_behavior_semantics_source_commit"])
    for relative in contract["unchanged_behavior_semantics_paths"]:
        exact(
            source_bytes(ROOT, source_commit, relative),
            source_bytes(ROOT, semantics_source, relative),
            f"UNCHANGED_BEHAVIOR_SEMANTICS:{relative}",
        )

    runner_relative = PHYSICAL_RUNNER.relative_to(ROOT).as_posix()
    runner_raw = source_bytes(ROOT, source_commit, runner_relative)
    exact(
        _mode_validate_set(runner_raw),
        (
            "Preflight",
            "Physical",
            "ProjectionControl",
            "AuthorizationControl",
            "RuntimeIdentity",
        ),
        "R91_WRAPPER_MODES",
    )
    exact(
        _normalize_r91_wrapper(runner_raw),
        source_bytes(ROOT, R90_SOURCE, R90_PHYSICAL_RUNNER),
        "R90_R91_WRAPPER_ONLY_CHANGE",
    )
    bound_sources = {
        relative: source_bytes(ROOT, source_commit, relative)
        for relative in (
            AUTHORIZATION_HELPER,
            SUPERVISOR,
            runner_relative,
            QUALIFICATION_RUNNER,
            WORKER,
        )
    }
    verify_bound_source_markers(
        bound_sources,
        {
            AUTHORIZATION_HELPER: (
                "Test-SporeSporeDirectQuestionAuthorization",
                'PhysicalQuestionKind -ceq "integration_ghost"',
                'PhysicalQuestionKind -ceq "behavior_development"',
            ),
            SUPERVISOR: (
                '"AuthorizationControl"',
                "Test-SporeSporeDirectQuestionAuthorization",
                "Find-R57AuthorizationControlReceipts",
            ),
            runner_relative: (
                '"AuthorizationControl"',
                'GateId = "QSDK-R24D91"',
                f'AuthorizationProjectionSchema =\n        "{PROJECTION_SCHEMA}"',
                f'AuthorizationControlSchema =\n        "{CONTROL_SCHEMA}"',
                'PhysicalQuestionKind = "behavior_development"',
                'ActuatorMode = "force_based_joint_impulse_v1"',
            ),
            QUALIFICATION_RUNNER: (
                "run_qsdk_core_zero_world_qualification.ps1",
                'GateId = "QSDK-R24D91"',
                "ProspectivePhysicalQuestionDeclared = $true",
            ),
            WORKER: (
                "SPORESPORE_GODOT_RECOVERY_ACTUATOR_MODE",
                "apply_behavior_control_force_based_v2",
                '"actuator_mode": _actuator_mode',
            ),
        },
        "BOUND_SOURCE",
    )

    inventory = contract["source_inventory"]
    verify_declared_source_inventory(ROOT, inventory)
    exact((len(inventory), len(set(inventory))), (63, 63), "SOURCE_INVENTORY")
    authored = contract["authored_source_paths"]
    exact((len(authored), len(set(authored))), (10, 10), "AUTHORED_SOURCE")
    qualified = contract["qualified_physical_paths"]
    exact((len(qualified), len(set(qualified))), (47, 47), "QUALIFIED_SOURCE")
    publication = set(contract["source_path_roles"]["publication_only_paths"])
    exact(publication.intersection(qualified), set(), "PATH_ROLE_OVERLAP")
    exact(set(inventory), set(qualified) | publication, "PATH_ROLE_PARTITION")

    dispatch = _run_dispatch_truth_table()
    reachability = _run_wrapper_reachability_refusal()
    verify_legacy_live_authority_projection(
        ROOT,
        (
            "sdk/release/quadruped_release_contract.json",
            "sdk/release/quadruped_support_matrix.json",
        ),
        record_key="r24d91_contract_path",
        expected={
            "next_gate_id": "QSDK-R24D91",
            "r24d91_question_class": "development",
            "r24d91_physical_question_declared": True,
            "r24d91_contract_path": CONTRACT.relative_to(ROOT).as_posix(),
            "r24d91_r90_qualification_closure_bound": True,
            "r24d91_exact_r90_behavior_question_reused": True,
            "r24d91_wrapper_authorization_control_mode_added": True,
            "r24d91_wrapper_reachability_refusal_required": True,
            "r24d91_published_closure_authorization_control_required": True,
            "r24d91_additional_physical_ghost_required": False,
            "r24d91_additional_physical_canary_required": False,
        },
        prefix="LIVE_R91",
    )
    counts = {
        "source_inventory_count": 63,
        "authored_source_path_count": 10,
        "qualified_physical_path_count": 47,
        "bound_predecessor_count": 1,
        "unchanged_behavior_semantics_binding_count": 8,
        "direct_authorization_dispatch_truth_table_case_count": 5,
        "authorization_control_wrapper_reachability_refusal_count": 1,
        "current_zero_world_worker_count": 0,
        "production_worker_parse_count": 1,
        "historical_closure_audits_executed_count": 0,
        "full_seeded_ghost_count": 0,
        "bespoke_physical_canary_count": 0,
    }
    return contract, counts, published, dispatch, reachability


def _run_runtime_identity(contract: dict[str, Any]) -> dict[str, Any]:
    completed = subprocess.run(
        [
            "pwsh",
            "-NoLogo",
            "-NoProfile",
            "-File",
            str(PHYSICAL_RUNNER),
            "-Mode",
            "RuntimeIdentity",
        ],
        cwd=ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="strict",
        check=False,
    )
    exact(completed.returncode, 0, "RUNTIME_IDENTITY_EXIT")
    exact(completed.stderr, "", "RUNTIME_IDENTITY_STDERR")
    receipt = _one_marker(completed.stdout, SUPERVISOR_MARKER)
    verify_exact_paths(
        receipt,
        {
            "schema_version": RUNTIME_IDENTITY_SCHEMA,
            "gate_id": "QSDK-R24D91",
            "ok": True,
            "selected_console_path": contract["exact_runtime"]["console_path"],
            "selected_console_sha256": contract["exact_runtime"]["console_sha256"],
            "selected_console_byte_length": contract["exact_runtime"][
                "console_byte_length"
            ],
            "worker_relative_path": WORKER,
            "worker_parse_count": 1,
            "actuator_mode": ACTUATOR_MODE,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physical_execution_authorized": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        "RUNTIME_IDENTITY",
    )
    return receipt


def run_preflight(
    contract: dict[str, Any],
    counts: dict[str, int],
    dispatch: dict[str, Any],
    reachability: dict[str, Any],
) -> dict[str, Any]:
    runtime_identity = _run_runtime_identity(contract)
    projection = controls.run_projection_control(
        ROOT, PHYSICAL_RUNNER, SUPERVISOR_MARKER, "QSDK-R24D91"
    )
    refusal = controls.run_missing_physical_switch_refusal(
        ROOT,
        PHYSICAL_RUNNER,
        SUPERVISOR_MARKER,
        "QSDK-R24D91",
        "sporespore_qsdk_r24d91_missing_physical_switch_refusal_v1",
    )
    controls.require_zero_authority(projection)
    controls.require_zero_authority(refusal)
    return {
        "schema_version": "sporespore_qsdk_r24d91_behavior_preflight_v1",
        "gate_id": "QSDK-R24D91",
        "ok": True,
        "runtime_id": contract["exact_runtime"]["runtime_profile_id"],
        "runtime_version": contract["exact_runtime"]["runtime_version"],
        "actuator_mode": ACTUATOR_MODE,
        **counts,
        "r90_qualification_closure_raw_sha256": contract["bound_predecessors"][0][
            "raw_sha256"
        ],
        "direct_authorization_dispatch_truth_table_receipt": dispatch,
        "authorization_control_wrapper_reachability_refusal_receipt": reachability,
        "historical_closure_audit_reexecution_count": 0,
        "production_wrapper_runtime_identity_receipt": runtime_identity,
        "supervisor_projection_receipt": projection,
        "missing_physical_switch_refusal_receipt": refusal,
        "forced_supervisor_failure_control_count": 1,
        "missing_physical_switch_refusal_count": 1,
        "published_closure_authorization_control_count": 0,
        "behavior_evaluator_invocation_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_question_opened": False,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--core-library", type=Path)
    args = parser.parse_args()
    contract, counts, published, dispatch, reachability = validate_sources()
    if args.core_library is None:
        print(
            SOURCE_MARKER,
            json.dumps(
                {
                    "gate_id": "QSDK-R24D91",
                    "ok": True,
                    "published": published,
                    **counts,
                },
                sort_keys=True,
            ),
        )
        return 0
    require(args.core_library.is_file(), "CORE_LIBRARY_MISSING")
    print(
        json.dumps(
            run_preflight(contract, counts, dispatch, reachability),
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (
        ClosureAuditError,
        controls.ControlError,
        AssertionError,
        KeyError,
        OSError,
        subprocess.SubprocessError,
        TypeError,
        ValueError,
    ) as error:
        print(f"QSDK_R24D91_SOURCE_FAIL {error}", file=sys.stderr)
        raise SystemExit(1) from error
