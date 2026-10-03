"""Compact source audit for the prospective QSDK-R24D53 transport smoke."""

from __future__ import annotations

from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError, exact, exact_bools, load, require,
    require_ordered_markers, sha256, verify_boolean_partition,
    verify_declared_source_inventory, verify_exact_paths,
    verify_legacy_live_gate_paths,
)

CONTRACT = ROOT / "sdk/recovery/r24d53_rapier_staging_transport_smoke_contract_v1.json"


def text(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def audit() -> None:
    contract = load(CONTRACT)
    verify_exact_paths(contract, {
        "schema_version": "sporespore_qsdk_r24d53_rapier_staging_transport_smoke_contract_v1",
        "gate_id": "QSDK-R24D53",
        "status": "prospective_minimal_native_staging_transport_smoke_implemented_zero_world_qualification_blocked",
        "authored_parent_commit": "ea5e8202db749bde1c8b7667da1c2613f1d6bd26",
        "question_class": "development", "physical_question_declared": True,
        "finite_physical_population.cell_count": 1,
        "finite_physical_population.world_count": 1,
        "finite_physical_population.arm_count": 1,
        "finite_physical_population.arm_kind": "candidate_command",
        "finite_physical_population.maximum_outer_steps": 2,
        "finite_physical_population.maximum_total_outer_steps": 2,
        "finite_physical_population.behavior_success_required": False,
        "transport_acceptance.exact_staging_record_count": 2,
        "transport_acceptance.exact_portable_increment_count": 2,
        "transport_acceptance.in_run_r45_invariant_receipt_count": 2,
        "complete_zero_world_gate.positive_control_count": 7,
        "complete_zero_world_gate.mutation_rejection_count": 5,
        "complete_zero_world_gate.total_preflight_check_count": 12,
        "complete_zero_world_gate.maximum_physical_steps_authorized": 0,
    }, "IDENTITY")
    exact_bools(contract, (
        "superiority_question_declared", "equivalence_or_non_inferiority_question_declared",
        "population_inference_declared",
    ), False, "DECLARATION")

    predecessor = contract["predecessor"]
    closure_path = ROOT / predecessor["closure_path"]
    exact(sha256(closure_path.read_bytes()), predecessor["closure_raw_sha256"],
          "R52_CLOSURE_HASH")
    closure = load(closure_path)
    verify_exact_paths(closure, {
        "gate_id": "QSDK-R24D52", "closure_status": predecessor["historical_result"],
        "decision.native_boundary_telemetry_qualified": True,
        "decision.engine_neutral_staging_ledger_v3_qualified": True,
        "decision.native_to_portable_staging_mapping_qualified": True,
        "decision.native_runtime_observation_made": False,
        "next_boundary.gate_id": "QSDK-R24D53",
    }, "R52_CLOSURE")
    exact_bools(predecessor, (
        "same_identity_requalification_permitted", "historical_result_rewritten",
        "historical_threshold_rewritten", "historical_evaluator_rewritten",
        "historical_interpretation_rewritten",
    ), False, "PREDECESSOR")

    controlled = contract["controlled_change"]
    exact_bools(controlled, (
        "shared_recovery_arm_observer_hook_added", "single_arm_two_step_transport_result_added",
        "shared_physical_runner_single_arm_shape_added",
    ), True, "CONTROLLED_ADDITION")
    exact_bools(controlled, (
        "r49_world_construction_changed", "r49_initializer_changed",
        "r49_controller_changed", "r49_behavior_evaluator_changed",
        "r52_native_patch_changed", "r52_portable_v3_ledger_changed",
        "threshold_changed", "margin_changed", "selector_changed",
        "morphology_changed", "physical_route_executed",
    ), False, "CONTROLLED_PRESERVATION")
    population = contract["finite_physical_population"]
    require("minimum finite horizon" in population["step_adequacy"], "STEP_ADEQUACY")
    require("not sampled as a robustness or population cohort" in population["seed_adequacy"],
            "SEED_ADEQUACY")
    require("does not spend a second world" in population["negative_control_adequacy"],
            "NEGATIVE_CONTROL_ADEQUACY")

    route = text("sdk/adapters/rapier/src/qsdk_r24d48_recovery_energy_v2_route.rs")
    require_ordered_markers(route, (
        "pub(crate) fn run_arm<F>(", "F: FnMut(",
        "let energy_sample = collect_r24d47_rapier_world_energy_exchange_v1(",
        "observe_post_step(&world.robot.world, &energy_sample, semantic_step)?;",
        "let native = collect_r24d45_native_step_v1(",
        "validate_r24d45_in_run_step_v1(",
    ), "SHARED_POST_STEP_OBSERVER")
    exact(route.count("|_, _, _| Ok(())"), 4, "HISTORICAL_NOOP_CALLERS")

    module_path = "sdk/adapters/rapier/src/qsdk_r24d53_staging_transport_smoke.rs"
    module = text(module_path)
    require_ordered_markers(module, (
        "pub fn run_qsdk_r24d53_rapier_staging_transport_zero_world_qualification()",
        "let r49 = run_qsdk_r24d49_rapier_runtime_binding_zero_world_qualification()?;",
        "let r52 = run_qsdk_r24d52_rapier_discrete_staging_ledger_zero_world_qualification()?;",
        "let runtime_binding_sha256 = digest_json(&projection)",
        '"wrong_r52_predecessor_digest"', '"wrong_step_budget"',
        '"physical_execution_authorized_by_this_receipt": false',
        "pub fn run_qsdk_r24d53_rapier_staging_transport_smoke(",
        "validate_runtime_binding_sha256(runtime_binding_sha256)?;",
        "let arm = run_arm(", "RecoveryArmKindV1::CandidateCommand", "2,",
        "let telemetry = world.physics_pipeline.sporespore_discrete_staging;",
        "collect_r24d52_rapier_discrete_staging_v1(telemetry, previous_staging_sequence)?;",
        "map_r24d52_recovery_energy_increment_v3(*energy, exchange, semantic_step)?;",
        '"native_telemetry": native_telemetry_json(telemetry)',
        "aggregate_recovery_energy_balance_v3(RecoveryEnergyBalanceAggregationRequestV3 {",
        '"native_staging_transport_observed": true',
        '"recovery_evaluation_executed": false',
    ), "R53_ROUTE")
    preflight_start = module.index(
        "pub fn run_qsdk_r24d53_rapier_staging_transport_zero_world_qualification()")
    preflight_end = module.index("fn exchange_json", preflight_start)
    preflight = module[preflight_start:preflight_end]
    for forbidden in ("compile_r24d45_recovery_boundary_v1", "run_arm(",
                      "PhysicsWorld::new", ".step("):
        require(forbidden not in preflight, f"ZERO_WORLD:{forbidden}")
    require("evaluate_recovery_trace_v3" not in module, "NO_BEHAVIOR_EVALUATOR")

    cargo = text("sdk/adapters/rapier/Cargo.toml")
    library = text("sdk/adapters/rapier/src/lib.rs")
    binary = text("sdk/adapters/rapier/src/bin/qsdk_r24d53_staging_transport_smoke.rs")
    for source, marker in (
        (cargo, 'sporespore-rapier-r24d53-staging-transport = ["sporespore-rapier-discrete-staging"]'),
        (cargo, 'name = "qsdk_r24d53_staging_transport_smoke"'),
        (library, "mod qsdk_r24d53_staging_transport_smoke;"),
        (library, "run_qsdk_r24d53_rapier_staging_transport_smoke"),
        (binary, "QSDK_R24D53_RAPIER_STAGING_TRANSPORT_ZERO_WORLD"),
    ):
        require(marker in source, f"PUBLIC_ROUTE:{marker}")

    qualification = contract["qualification_runner"]
    exact((len(qualification["successor_patch_sequence"]),
           len(qualification["successor_patched_files"])), (1, 8),
          "SUCCESSOR_PATCH_POPULATION")
    delta = ROOT / qualification["successor_patch_sequence"][0]["path"]
    raw = delta.read_bytes()
    exact((len(raw), sha256(raw)),
          (qualification["successor_patch_sequence"][0]["byte_length"],
           qualification["successor_patch_sequence"][0]["raw_sha256"]),
          "SUCCESSOR_PATCH_IDENTITY")
    exact_bools(qualification, ("shared_runner_reused",), True, "QUALIFICATION_REUSE")
    exact_bools(qualification, ("new_zero_world_runner_added", "new_physical_harness_added"),
                False, "QUALIFICATION_ADDITION")

    physical = contract["physical_runner"]
    exact_bools(physical, (
        "qualification_harness_cargo_lock_reused_exactly",
        "locked_dependency_resolution_required", "development_disabled",
        "shared_physical_runner_reused",
    ), True, "PHYSICAL_REUSE")
    exact_bools(physical, ("new_physical_runner_added",), False, "PHYSICAL_ADDITION")
    runner = text(physical["script_path"])
    require_ordered_markers(runner, (
        '$ghostResultShape = if ($runner.Contains("ghost_result_shape"))',
        '$successorBindings = @{}',
        '$contract.qualification_runner.successor_patched_files',
        'if ($ghostResultShape -ceq "single_arm_transport_v1")',
        '[bool]$result.native_staging_transport_observed',
        'ghost_result_shape = if ($Mode -ceq "Ghost")',
    ), "SHARED_PHYSICAL_RUNNER")

    controls = contract["complete_zero_world_gate"]["required_positive_controls"]
    mutations = contract["complete_zero_world_gate"]["mutation_ids"]
    exact((len(controls), len(set(controls))), (7, 7), "CONTROL_IDS")
    exact((len(mutations), len(set(mutations))), (5, 5), "MUTATION_IDS")
    pointers = [item["json_pointer"] for item in qualification["preflight_expectations"]]
    exact(len(pointers), len(set(pointers)), "PREFLIGHT_POINTERS")
    verify_declared_source_inventory(ROOT, contract["source_inventory"])
    verify_legacy_live_gate_paths(ROOT, contract["live_authority_paths"],
                                  contract["live_gate_carrier_id"],
                                  contract["live_gate_expectations"])
    verify_boolean_partition(contract["claim_boundary"], (
        "r52_zero_world_qualification_closed_positive", "native_staging_transport_implemented",
        "producer_owned_runtime_binding_implemented", "single_arm_two_step_projection_implemented",
        "in_run_physical_invariant_route_retained", "held_out_cells_remain_sealed",
    ), (
        "native_staging_transport_zero_world_qualified", "native_transport_smoke_stage_authorized",
        "native_transport_smoke_attempted", "native_transport_smoke_observed",
        "new_physical_observation_made", "retained_r49_residual_recomputed",
        "retained_r49_result_reclassified", "controller_behavior_evaluated",
        "prone_to_standing_claimed", "repeatability_rate_claimed", "population_claimed",
        "held_out_validation_claimed", "cross_engine_recovery_claimed",
        "cross_engine_equivalence_claimed", "sdk1_milestone_advanced",
        "physical_acceptance_authority", "release_authority",
    ), "CLAIM")
    print("QSDK_R24D53_RAPIER_STAGING_TRANSPORT_SMOKE_SOURCE_PASS "
          "physical=0 worlds=0 solver_steps=0 controls=7 mutations=5 "
          "declared_worlds=1 declared_outer_steps=2 behavior=false")


if __name__ == "__main__":
    try:
        audit()
    except (ClosureAuditError, OSError, KeyError, TypeError, ValueError,
            subprocess.SubprocessError) as error:
        print(f"QSDK_R24D53_RAPIER_STAGING_TRANSPORT_SMOKE_SOURCE_FAIL {error}",
              file=sys.stderr)
        raise SystemExit(1) from error
