"""Compact source audit for the prospective QSDK-R24D48 Rapier V2 route."""

from __future__ import annotations

from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError,
    exact,
    exact_bools,
    git,
    load,
    require,
    require_ordered_markers,
    sha256,
    verify_boolean_partition,
    verify_declared_source_inventory,
    verify_exact_paths,
    verify_legacy_live_gate_paths,
    verify_version_pinned_crates_io_patch_source,
)


CONTRACT = ROOT / "sdk/recovery/r24d48_rapier_recovery_energy_v2_contract_v1.json"


def source_at(commit: str, relative: str) -> str:
    value = git(ROOT, "show", f"{commit}:{relative}")
    assert isinstance(value, str)
    return value + "\n"


def normalize_r45_successor_visibility(source: str) -> str:
    replacements = {
        "pub(crate) struct RapierRecoveryWorldV1": "struct RapierRecoveryWorldV1",
        "pub(crate) struct RapierRecoveryApplicationV1": "struct RapierRecoveryApplicationV1",
        "pub(crate) struct RapierRecoveryNativeStepV1": "struct RapierRecoveryNativeStepV1",
        "pub(crate) struct RapierRecoveryStepContextV1": "struct RapierRecoveryStepContextV1",
        "pub(crate) fn build_r24d45_recovery_world_v1": "fn build_r24d45_recovery_world_v1",
        "pub(crate) fn arm_id": "fn arm_id",
        "pub(crate) fn apply_and_step_r24d45_recovery_v1": (
            "fn apply_and_step_r24d45_recovery_v1"
        ),
        "pub(crate) fn collect_r24d45_native_step_v1": "fn collect_r24d45_native_step_v1",
        "pub(crate) fn validate_r24d45_in_run_step_v1": (
            "fn validate_r24d45_in_run_step_v1"
        ),
        "pub(crate) fn initialize_arm_memory_v1": "fn initialize_arm_memory_v1",
    }
    for current, historical in replacements.items():
        exact(source.count(current), 1, f"R45_VISIBILITY_COUNT:{current}")
        source = source.replace(current, historical)
    for field in (
        "robot", "task_origin", "initial_mechanical_energy_j",
        "cumulative_actuator_work_j", "host_step_count", "observation",
        "observation_sha256", "invariant_receipt", "arm", "phase",
        "semantic_step", "previous_observation_sha256",
        "runtime_qualification_sha256",
    ):
        current = f"    pub(crate) {field}:"
        if current in source:
            source = source.replace(current, f"    {field}:", 1)
    return source


def function_region(source: str, start: str, end: str) -> str:
    begin = source.index(start)
    finish = source.index(end, begin)
    return source[begin:finish]


def audit() -> None:
    contract = load(CONTRACT)
    contract_relative = CONTRACT.relative_to(ROOT).as_posix()
    publication = git(
        ROOT, "log", "-1", "--diff-filter=A", "--format=%H", "--",
        contract_relative,
    )
    assert isinstance(publication, str)
    require(bool(publication), "CONTRACT_PUBLICATION")
    verify_exact_paths(contract, {
        "schema_version": "sporespore_qsdk_r24d48_rapier_recovery_energy_v2_contract_v1",
        "gate_id": "QSDK-R24D48",
        "status": (
            "prospective_staged_development_source_implemented_"
            "zero_world_qualification_and_physics_blocked"
        ),
        "authored_parent_commit": "2665e005717092c7a5b43a7a2110e8891266e9b6",
        "question_class": "development",
        "scope.engine": "rapier_parry_native",
        "scope.route_id": "sporespore_qsdk_r24d48_rapier_recovery_energy_v2_route_v1",
        "scope.mapping_profile_id": (
            "rapier_r24d47_native_components_to_recovery_energy_v2_v1"
        ),
        "complete_zero_world_gate.world_build_count": 0,
        "complete_zero_world_gate.solver_step_count": 0,
        "complete_zero_world_gate.maximum_physical_steps_authorized": 0,
        "physical_runner.qualification_harness_cargo_lock_path": (
            "isolated-harness/Cargo.lock"
        ),
    }, "IDENTITY")
    exact_bools(contract, ("physical_question_declared",), True, "PHYSICAL_DECLARATION")
    exact_bools(contract, (
        "superiority_question_declared", "equivalence_or_non_inferiority_question_declared",
        "population_inference_declared",
    ), False, "INFERENCE_DECLARATION")
    exact_bools(contract["physical_runner"], (
        "qualification_harness_cargo_lock_reused_exactly",
        "locked_dependency_resolution_required",
    ), True, "PHYSICAL_DEPENDENCY_LOCK")
    exact_bools(contract["qualification_runner"], (
        "shared_runner_reused", "inherited_pinned_dependency_manifest_reused",
        "isolated_harness_cargo_lock_receipt_required",
    ), True, "QUALIFICATION_REUSE")

    predecessor = contract["predecessor"]
    for field in ("closure", "contract"):
        path = ROOT / predecessor[f"{field}_path"]
        exact(sha256(path.read_bytes()), predecessor[f"{field}_raw_sha256"],
              f"PREDECESSOR_{field.upper()}")
        subprocess.run([
            "git", "diff", "--quiet", contract["authored_parent_commit"], "--",
            predecessor[f"{field}_path"],
        ], cwd=ROOT, check=True)
    exact_bools(predecessor, (
        "same_identity_requalification_permitted", "historical_result_rewritten",
        "historical_threshold_rewritten", "historical_evaluator_rewritten",
        "historical_interpretation_rewritten",
    ), False, "PREDECESSOR")
    dependency_contract = load(ROOT / predecessor["contract_path"])
    verify_version_pinned_crates_io_patch_source(
        ROOT, dependency_contract["pinned_dependency"]
    )

    parent = contract["authored_parent_commit"]
    r45_path = "sdk/adapters/rapier/src/qsdk_r24d45_recovery_route.rs"
    current_r45 = source_at(publication, r45_path)
    exact(normalize_r45_successor_visibility(current_r45), source_at(parent, r45_path),
          "R45_MECHANICS_UNCHANGED")

    r47_path = "sdk/adapters/rapier/src/qsdk_r24d47_energy_exchange_observer.rs"
    current_r47 = source_at(publication, r47_path)
    historical_r47 = source_at(parent, r47_path)
    for start, end in (
        ("pub(crate) fn collect_r24d47_rapier_energy_exchange_v1(",
         "pub fn collect_r24d47_rapier_world_energy_exchange_v1("),
        ("pub fn collect_r24d47_rapier_world_energy_exchange_v1(",
         "fn fixture_motor_samples("),
    ):
        exact(function_region(current_r47, start, end),
              function_region(historical_r47, start, end),
              f"R47_COLLECTOR_UNCHANGED:{start}")

    core = source_at(publication, "sdk/core/src/recovery_runtime.rs")
    require_ordered_markers(core, (
        "pub const RAPIER_R24D48_RECOVERY_ROUTE_ID",
        "pub const RAPIER_R24D48_ENERGY_V2_MAPPING_PROFILE_ID",
        "pub fn bind_recovery_observation_v2_source_v1(",
        "pub fn recovery_observation_v2_source_identity_supported_v1(",
        "RecoveryNativeEngineV1::RapierParryNative =>",
        "source_route_id == RAPIER_R24D48_RECOVERY_ROUTE_ID",
        "mapping_profile_id == RAPIER_R24D48_ENERGY_V2_MAPPING_PROFILE_ID",
        "collect_native_recovery_observation_v3(",
    ), "CORE_V2_SOURCE")
    route = source_at(
        publication,
        "sdk/adapters/rapier/src/qsdk_r24d48_recovery_energy_v2_route.rs",
    )
    require_ordered_markers(route, (
        "fn map_energy_increment_v1(",
        "applied_actuator_work_j: sample.motor_net_work_j",
        "signed_external_work_j: sample.signed_external_work_j",
        "signed_constraint_exchange_j: sample.signed_constraint_exchange_j",
        "passive_dissipation_j: sample.passive_dissipation_j",
        "fn observation_v2_from_v1(",
        "aggregate_recovery_energy_balance_v2(",
        "bind_recovery_observation_v2_source_v1(",
        "observe_r24d47_rapier_world_route_capability_v1(",
        "collect_r24d47_rapier_world_energy_exchange_v1(",
        "collect_rapier_native_recovery_observation_v3(",
        "step_recovery_v3(",
        "evaluate_recovery_trace_v3(",
    ), "R48_ROUTE")
    for forbidden in (
        "mechanical_energy_change_used_as_work_source\": true",
        "energy_balance_residual_used_as_work_source\": true",
        "evaluate_recovery_trace_v2(", "step_recovery_v2(",
    ):
        require(forbidden not in route, f"FORBIDDEN_ROUTE:{forbidden}")

    zero_runner = source_at(
        publication, contract["qualification_runner"]["script_path"]
    )
    require_ordered_markers(zero_runner, (
        'elseif ($runner.Contains("pinned_dependency_contract_path"))',
        '"PINNED_DEPENDENCY_CONTRACT"',
        '"run", "--locked", "--offline"',
        "$checks.worktree_unchanged = $true",
        "isolated_harness_cargo_lock = [ordered]@{",
    ), "SHARED_ZERO_WORLD_RUNNER")
    physical_runner = source_at(
        publication, contract["physical_runner"]["script_path"]
    )
    require_ordered_markers(physical_runner, (
        'ValidateSet("Ghost", "Development")',
        '"SOURCE_NOT_CLEAN_PUSHED_EQUAL"',
        '"QUALIFIED_CODE_DRIFT"',
        '"QUALIFICATION_CARGO_LOCK"',
        '"PATCHED_BINDING:',
        '"EXACT_SOURCE_STAGE_ALREADY_ATTEMPTED"',
        '"PASSING_SAME_SOURCE_GHOST_COUNT:',
        "Enter-SporeSporeLocomotionOperationLock",
        '"COPIED_QUALIFICATION_CARGO_LOCK"',
        '"run", "--locked", "--offline", "--manifest-path"',
        '"HARNESS_CARGO_LOCK_DRIFT"',
        '"FINAL_STATUS_DRIFT"',
    ), "PHYSICAL_RUNNER")

    mutation_ids = contract["complete_zero_world_gate"]["mapping_mutation_ids"]
    exact(len(mutation_ids), len(set(mutation_ids)), "MUTATION_IDS")
    exact(len(mutation_ids),
          contract["complete_zero_world_gate"]["mapping_mutation_rejection_count"],
          "MUTATION_COUNT")
    exact(contract["staged_physical_execution"]["integration_ghost"]
          ["maximum_total_outer_steps"], 4, "GHOST_BUDGET")
    exact(contract["staged_physical_execution"]["paired_development"]
          ["maximum_total_outer_steps"], 2400, "DEVELOPMENT_BUDGET")
    exact(contract["threshold_and_margin_provenance"]["threshold_change_count"], 0,
          "THRESHOLD_CHANGE")
    exact(contract["threshold_and_margin_provenance"]["new_margin_count"], 0,
          "MARGIN_CHANGE")

    subprocess.run([
        "cargo", "test", "--locked", "--offline",
        "-p", "sporespore-locomotion-core",
        "observation_v2_collection_binds_qualified_native_mappings_and_refuses_mutations",
    ], cwd=ROOT / "sdk", check=True, capture_output=True, text=True)

    verify_declared_source_inventory(ROOT, contract["source_inventory"])
    verify_legacy_live_gate_paths(
        ROOT, contract["live_authority_paths"], contract["live_gate_carrier_id"],
        contract["live_gate_expectations"],
        revision=publication,
    )
    verify_boolean_partition(contract["claim_boundary"], (
        "rapier_observation_v2_source_identity_implemented",
        "r24d47_to_energy_v2_mapping_implemented", "live_v2_recovery_route_implemented",
    ), (
        "rapier_observation_v2_source_identity_qualified",
        "r24d47_to_energy_v2_mapping_qualified",
        "live_v2_recovery_route_physically_exercised", "integration_ghost_passed",
        "paired_development_attempt_consumed", "controller_behavior_evaluated",
        "prone_to_standing_claimed", "arbitrary_morphology_claimed",
        "cross_engine_equivalence_claimed", "sdk1_milestone_advanced",
        "physical_acceptance_authority", "release_authority",
    ), "CLAIM")
    print(
        "QSDK_R24D48_RAPIER_RECOVERY_ENERGY_V2_SOURCE_PASS "
        "worlds=0 solver_steps=0 mutations=8 physical=declared_blocked"
    )


if __name__ == "__main__":
    try:
        audit()
    except (ClosureAuditError, OSError, KeyError, ValueError,
            subprocess.SubprocessError) as error:
        print(f"QSDK_R24D48_RAPIER_RECOVERY_ENERGY_V2_SOURCE_FAIL {error}", file=sys.stderr)
        raise SystemExit(1) from error
