#!/usr/bin/env python3
"""Zero-world source authority for R92 future-state-stable wrapper recovery behavior."""

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
    "sdk/recovery/r24d92_godot_jolt_force_based_recovery_behavior_"
    "contract_v1.json"
)
CLOSURE = ROOT / (
    "sdk/recovery/r24d92_godot_jolt_force_based_recovery_behavior_"
    "zero_world_qualification_closure_v1.json"
)
R91_CLOSURE = ROOT / (
    "sdk/recovery/r24d91_godot_jolt_force_based_recovery_behavior_"
    "zero_world_qualification_closure_v1.json"
)
PHYSICAL_RUNNER = ROOT / (
    "sdk/run_qsdk_r24d92_godot_jolt_force_based_recovery_behavior.ps1"
)
R91_PHYSICAL_RUNNER = (
    "sdk/run_qsdk_r24d91_godot_jolt_force_based_recovery_behavior.ps1"
)
QUALIFICATION_RUNNER = (
    "sdk/run_qsdk_r24d92_godot_jolt_force_based_recovery_behavior_"
    "zero_world_qualification.ps1"
)
WORKER = "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
SUPERVISOR = "sdk/run_qsdk_r24d57_godot_native_recovery_route_ghost.ps1"
AUTHORIZATION_HELPER = "sdk/physical_authorization_projection.ps1"
SOURCE_MARKER = (
    "QSDK_R24D92_GODOT_JOLT_FORCE_BASED_RECOVERY_BEHAVIOR_SOURCE_PASS"
)
SUPERVISOR_MARKER = "QSDK_R24D92_FORCE_BASED_RECOVERY_BEHAVIOR_SUPERVISOR "
RUNTIME_IDENTITY_SCHEMA = (
    "sporespore_qsdk_r24d92_force_based_behavior_runtime_identity_v1"
)
SEED_LABEL = (
    "QSDK-R24D92/development/godot/"
    "r92-future-state-stable-wrapper-control-reachability-exact-nominal-prone-to-standing-paired-v1"
)
SEED_SHA256 = (
    "sha256:34eb7610bcb6fbc07e1324f53ef374e37542df20a7bd0a5189900dd96e754389"
)
PROSPECTIVE_STATUS = (
    "prospective_future_state_stable_authorization_control_reachability_recovery_behavior_"
    "complete_zero_world_qualification_required_physics_blocked"
)
R91_STATUS = (
    "closed_complete_zero_world_wrapper_reachable_recovery_behavior_"
    "qualification_passed_future_state_audit_not_reusable_no_control_or_"
    "physics_authorized_r92_required"
)
ACTUATOR_MODE = "force_based_joint_impulse_v1"
PROJECTION_SCHEMA = "sporespore_qsdk_r24d92_behavior_authorization_projection_v1"
CONTROL_SCHEMA = (
    "sporespore_qsdk_r24d92_published_closure_authorization_control_v1"
)
R91_SOURCE = "90fcbd37b56466a6a2961cc61b9283eadf6c0101"
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
    raw = R91_CLOSURE.read_bytes()
    verify_exact_paths(
        declaration,
        {
            "gate_id": "QSDK-R24D91",
            "role": (
                "positive_zero_world_qualification_with_future_state_source_"
                "audit_limit"
            ),
            "path": R91_CLOSURE.relative_to(ROOT).as_posix(),
            "byte_length": len(raw),
            "raw_sha256": "sha256:" + hashlib.sha256(raw).hexdigest(),
            "closure_status": R91_STATUS,
            "same_identity_rerun_permitted": False,
            "same_identity_requalification_permitted": False,
            "historical_result_rewritten": False,
        },
        "R91_PREDECESSOR_DECLARATION",
    )
    value = load(R91_CLOSURE)
    verify_exact_paths(
        value,
        {
            "closure_status": R91_STATUS,
            "qualification.official_zero_world_qualification_passed": True,
            "qualification.direct_authorization_dispatch_truth_table_case_count": 5,
            "qualification.model_construction_count": 0,
            "qualification.world_build_count": 0,
            "qualification.solver_step_count": 0,
            "qualification.authorization_control_wrapper_reachability_refusal_count": 1,
            "post_qualification_future_state_diagnosis.source_audit_requires_control_root_absent": True,
            "post_qualification_future_state_diagnosis.authorization_control_receipt_count": 0,
            "decision.physical_behavior_attempt_authorized": False,
            "decision.distinct_r92_source_required": True,
            "claim_boundary.physical_attempted": False,
            "claim_boundary.prone_to_standing_claimed": False,
        },
        "R91_PREDECESSOR",
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
[ordered]@{{ schema_version = 'sporespore_qsdk_r24d92_direct_authorization_dispatch_truth_table_v1'; rows = $rows }} | ConvertTo-Json -Depth 10 -Compress
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
        "sporespore_qsdk_r24d92_direct_authorization_dispatch_truth_table_v1",
        "DISPATCH_SCHEMA",
    )
    exact(len(receipt["rows"]), 5, "DISPATCH_CASE_COUNT")
    require(
        all(row["observed"] == row["expected"] for row in receipt["rows"]),
        "DISPATCH_TRUTH_TABLE",
    )
    return receipt


def _control_receipt_population(control_root: Path) -> tuple[tuple[str, int, str], ...]:
    if not control_root.is_dir():
        return ()
    population = []
    for path in sorted(control_root.rglob("authorization_control.json")):
        raw = path.read_bytes()
        population.append(
            (
                path.relative_to(control_root).as_posix(),
                len(raw),
                "sha256:" + hashlib.sha256(raw).hexdigest(),
            )
        )
    return tuple(population)


def _run_wrapper_reachability_refusal() -> dict[str, Any]:
    control_root = EVIDENCE_ROOT / (
        "qsdk-r24d92-godot-jolt-force-based-recovery-behavior-"
        "authorization-control"
    )
    presence_before = control_root.exists()
    population_before = _control_receipt_population(control_root)
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
    population_after = _control_receipt_population(control_root)
    exact(population_after, population_before, "WRAPPER_REACHABILITY_POPULATION")
    exact(
        control_root.exists(),
        presence_before,
        "WRAPPER_REACHABILITY_ROOT_PRESENCE",
    )
    return {
        "schema_version": (
            "sporespore_qsdk_r24d92_authorization_control_wrapper_"
            "reachability_refusal_v1"
        ),
        "gate_id": "QSDK-R24D92",
        "ok": True,
        "mode": "AuthorizationControl",
        "expected_terminal": "authorization_path_required",
        "expected_terminal_observed": True,
        "powershell_parameter_binding_failure_observed": False,
        "operation_lock_acquired": False,
        "source_audit_and_runtime_preflight_count": 0,
        "control_root_presence_before": presence_before,
        "control_root_presence_after": control_root.exists(),
        "authorization_control_receipt_count_before": len(population_before),
        "authorization_control_receipt_count_after": len(population_after),
        "authorization_control_receipt_population_unchanged": True,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_question_opened": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def _normalize_r92_wrapper(raw: bytes) -> bytes:
    text = raw.decode("utf-8")
    text = text.replace("exact finite R91", "exact finite R90")
    text = text.replace("R24D92", "R24D91")
    text = text.replace("r24d92", "r24d91")
    text = text.replace("R92", "R91")
    text = text.replace("r92", "r91")
    text = text.replace(
        "r91-future-state-stable-wrapper-control-reachability-exact-nominal-"
        "prone-to-standing-paired-v1",
        "r91-wrapper-control-reachability-exact-nominal-prone-to-standing-"
        "paired-v1",
    )
    text = text.replace(
        "sha256:34eb7610bcb6fbc07e1324f53ef374e37542df20a7bd0a5189900dd96e754389",
        "sha256:83863edfdf6b22173c06da922784548f23f3a1350cea7340df7b8f2212ef6d2d",
    )
    return text.encode("utf-8")


def validate_sources() -> tuple[
    dict[str, Any], dict[str, int], bool, dict[str, Any], dict[str, Any]
]:
    contract = load(CONTRACT)
    controls.validate_development_question(contract, "QSDK-R24D92")
    verify_exact_paths(
        contract,
        {
            "schema_version": (
                "sporespore_qsdk_r24d92_godot_jolt_force_based_recovery_"
                "behavior_contract_v1"
            ),
            "status": PROSPECTIVE_STATUS,
            "authored_parent_commit": (
                "351eeba3470fbb84ee333a1d59c855900c6d8457"
            ),
            "controlled_change.r91_complete_zero_world_qualification_bound": True,
            "controlled_change.r91_future_state_audit_limit_bound": True,
            "controlled_change.r91_behavior_question_reused_under_distinct_campaign": True,
            "controlled_change.r91_portable_recovery_controller_changed": False,
            "controlled_change.r91_portable_recovery_evaluator_changed": False,
            "controlled_change.r91_behavior_threshold_changed": False,
            "controlled_change.physical_wrapper_authorization_control_mode_changed": False,
            "controlled_change.authorization_control_wrapper_global_absence_assertion_removed": True,
            "controlled_change.authorization_control_wrapper_before_after_receipt_population_assertion_added": True,
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
            "critical_path_audit_policy.authorization_control_receipt_population_before_after_equality_count": 1,
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
            "sporespore_qsdk_r24d92_godot_jolt_force_based_recovery_behavior_"
            "zero_world_qualification_closure_v1"
        ),
        gate_id="QSDK-R24D92",
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
        "R92_WRAPPER_MODES",
    )
    exact(
        _normalize_r92_wrapper(runner_raw),
        source_bytes(ROOT, R91_SOURCE, R91_PHYSICAL_RUNNER),
        "R91_R92_WRAPPER_ONLY_CHANGE",
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
                'GateId = "QSDK-R24D92"',
                f'AuthorizationProjectionSchema =\n        "{PROJECTION_SCHEMA}"',
                f'AuthorizationControlSchema =\n        "{CONTROL_SCHEMA}"',
                'PhysicalQuestionKind = "behavior_development"',
                'ActuatorMode = "force_based_joint_impulse_v1"',
            ),
            QUALIFICATION_RUNNER: (
                "run_qsdk_core_zero_world_qualification.ps1",
                'GateId = "QSDK-R24D92"',
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
        record_key="r24d92_contract_path",
        expected={
            "r24d92_question_class": "development",
            "r24d92_physical_question_declared": True,
            "r24d92_contract_path": CONTRACT.relative_to(ROOT).as_posix(),
            "r24d92_r91_qualification_closure_bound": True,
            "r24d92_exact_r91_behavior_question_reused": True,
            "r24d92_wrapper_authorization_control_mode_preserved": True,
            "r24d92_wrapper_reachability_refusal_required": True,
            "r24d92_future_state_receipt_population_preservation_required": True,
            "r24d92_published_closure_authorization_control_required": True,
            "r24d92_additional_physical_ghost_required": False,
            "r24d92_additional_physical_canary_required": False,
        },
        prefix="LIVE_R92",
    )
    counts = {
        "source_inventory_count": 63,
        "authored_source_path_count": 10,
        "qualified_physical_path_count": 47,
        "bound_predecessor_count": 1,
        "unchanged_behavior_semantics_binding_count": 8,
        "direct_authorization_dispatch_truth_table_case_count": 5,
        "authorization_control_wrapper_reachability_refusal_count": 1,
        "authorization_control_receipt_population_before_after_equality_count": 1,
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
            "gate_id": "QSDK-R24D92",
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
        ROOT, PHYSICAL_RUNNER, SUPERVISOR_MARKER, "QSDK-R24D92"
    )
    refusal = controls.run_missing_physical_switch_refusal(
        ROOT,
        PHYSICAL_RUNNER,
        SUPERVISOR_MARKER,
        "QSDK-R24D92",
        "sporespore_qsdk_r24d92_missing_physical_switch_refusal_v1",
    )
    controls.require_zero_authority(projection)
    controls.require_zero_authority(refusal)
    return {
        "schema_version": "sporespore_qsdk_r24d92_behavior_preflight_v1",
        "gate_id": "QSDK-R24D92",
        "ok": True,
        "runtime_id": contract["exact_runtime"]["runtime_profile_id"],
        "runtime_version": contract["exact_runtime"]["runtime_version"],
        "actuator_mode": ACTUATOR_MODE,
        **counts,
        "r91_qualification_closure_raw_sha256": contract["bound_predecessors"][0][
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
                    "gate_id": "QSDK-R24D92",
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
        print(f"QSDK_R24D92_SOURCE_FAIL {error}", file=sys.stderr)
        raise SystemExit(1) from error
