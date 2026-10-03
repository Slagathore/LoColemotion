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
    verify_legacy_live_gate_paths, verify_version_pinned_crates_io_patch_source,
)


CONTRACT = ROOT / "sdk/recovery/r24d47_rapier_energy_exchange_accounting_contract_v1.json"


def audit() -> None:
    contract = load(CONTRACT)
    verify_exact_paths(contract, {
        "schema_version": "sporespore_qsdk_r24d47_rapier_energy_exchange_accounting_contract_v1",
        "gate_id": "QSDK-R24D47",
        "status": "prospective_zero_world_source_implemented_qualification_and_physics_blocked",
        "authored_parent_commit": "46b42f8b272230e09eb87cfe6bfcca827904ff7d",
        "question_class": "development",
        "complete_zero_world_gate.world_build_count": 0,
        "complete_zero_world_gate.solver_step_count": 0,
        "complete_zero_world_gate.maximum_physical_steps_authorized": 0,
    }, "IDENTITY")
    exact_bools(contract, (
        "physical_question_declared", "superiority_question_declared",
        "equivalence_or_non_inferiority_question_declared",
        "population_inference_declared",
    ), False, "DECLARATION")

    predecessor = contract["predecessor"]
    predecessor_path = ROOT / predecessor["closure_path"]
    exact(sha256(predecessor_path.read_bytes()), predecessor["closure_raw_sha256"],
          "PREDECESSOR_HASH")
    exact_bools(predecessor, (
        "same_identity_requalification_permitted", "historical_result_rewritten",
        "historical_threshold_rewritten", "historical_evaluator_rewritten",
        "historical_interpretation_rewritten",
    ), False, "PREDECESSOR")
    subprocess.run([
        "git", "diff", "--quiet", contract["authored_parent_commit"], "--",
        predecessor["closure_path"],
    ], cwd=ROOT, check=True)

    dependency = contract["pinned_dependency"]
    exact(dependency["patch_raw_sha256"], dependency["successor_patch_raw_sha256"],
          "SUCCESSOR_PATCH")
    _, patch_source = verify_version_pinned_crates_io_patch_source(ROOT, dependency)
    for marker in (
        'sporespore-energy-exchange-telemetry = ["sporespore-motor-work-telemetry"]',
        "pub fn sporespore_kinetic_energy", "pub struct SporeSporeEnergyExchangeTelemetry",
        "pub total_constraint_exchange_j: Real", "pub joint_constraint_exchange_j: Real",
        "pub contact_constraint_exchange_j: Real", "pub contact_warmstart_exchange_j: Real",
        'feature = "parallel"', "qualified only for the sequential scalar solver",
        "self.sporespore_energy_exchange.begin_outer_step();",
        "self.sporespore_energy_exchange.accumulate(sample);",
    ):
        require(marker in patch_source, f"PATCH_MARKER:{marker}")
    exact(patch_source.count("sporespore_kinetic_energy()"), 10, "ENERGY_SAMPLE_COUNT")
    exact(patch_source.count("total_constraint_exchange += exchange"), 5,
          "TOTAL_PHASE_COUNT")
    exact((patch_source.count("joint_constraint_exchange += exchange"),
           patch_source.count("contact_constraint_exchange += exchange"),
           patch_source.count("contact_warmstart_exchange += exchange")),
          (2, 3, 1), "GROUPED_PHASE_COUNTS")

    cargo = (ROOT / "sdk/adapters/rapier/Cargo.toml").read_text(encoding="utf-8")
    library = (ROOT / "sdk/adapters/rapier/src/lib.rs").read_text(encoding="utf-8")
    module = (ROOT / "sdk/adapters/rapier/src/qsdk_r24d47_energy_exchange_observer.rs").read_text(
        encoding="utf-8")
    require('sporespore-rapier-energy-exchange = ["sporespore-rapier-motor-work"]'
            in cargo, "ADAPTER_FEATURE")
    for source, marker in (
        (library, '#[cfg(feature = "sporespore-rapier-energy-exchange")]'),
        (module, "collect_r24d47_rapier_energy_exchange_v1"),
        (module, "pub fn collect_r24d47_rapier_world_energy_exchange_v1"),
        (module, "fn observe_route_capability("),
        (module, "world.physics_pipeline.sporespore_energy_exchange"),
        (module, "QSDK_R24D47_ACTUATOR_JOINT_HANDLE_DUPLICATE"),
        (module, "joint_exchange_j - net_motor_work_j"),
        (module, "nonmotor_joint_exchange_j + contact_exchange_j"),
        (module, '"independent_v2_energy_balance_residual"'),
        (module, '"residual_derived_work_used": false'),
        (module, '"mutation_rejection_count": mutation_count'),
        (module, "QSDK_R24D47_SOLVER_CONFIGURATION_UNSUPPORTED"),
    ):
        require(marker in source, f"ADAPTER_MARKER:{marker}")
    require("PhysicsWorld::new" not in module and "world.step" not in module,
            "ZERO_WORLD_SOURCE")
    active_configuration = (
        ROOT / "sdk/adapters/rapier/src/active_configuration.rs"
    ).read_text(encoding="utf-8")
    require_ordered_markers(active_configuration, (
        "RAPIER_ACTIVE_SOLVER_ITERATIONS: usize = 16",
        "RAPIER_ACTIVE_INTERNAL_PGS_ITERATIONS: usize = 3",
        "RAPIER_ACTIVE_INTERNAL_STABILIZATION_ITERATIONS: usize = 5",
        "world.integration_parameters.dt = RAPIER_DT_S",
        "world.integration_parameters.length_unit = 1.0",
        "world.integration_parameters.num_solver_iterations",
        ".num_internal_pgs_iterations",
        ".num_internal_stabilization_iterations",
    ), "ACTIVE_CONFIGURATION")
    locomotion = (ROOT / "sdk/adapters/rapier/src/locomotion.rs").read_text(
        encoding="utf-8")
    require_ordered_markers(locomotion, (
        "RigidBodyBuilder::fixed()", "RigidBodyBuilder::dynamic()",
        ".can_sleep(false)", ".ccd_enabled(true)",
    ), "ROUTE_BODY_CONFIGURATION")
    initializer = (
        ROOT / "sdk/adapters/rapier/src/qsdk_r24d45_recovery_route.rs"
    ).read_text(encoding="utf-8")
    require("body.reset_forces(true);" in initializer,
            "ROUTE_FORCE_INITIALIZATION")

    runner_contract = contract["qualification_runner"]
    runner = (ROOT / runner_contract["script_path"]).read_text(encoding="utf-8")
    require_ordered_markers(runner, (
        "function Get-JsonPointerValue", "function Assert-DeclaredPreflightExpectations",
        '"apply", "--check", $patchPath', "PATCHED_DEPENDENCY_BINDING",
        "[patch.crates-io]", '"check", "--locked", "--offline"',
        'Contains("expected_compile_refusals")', "Invoke-ExpectedFailureLogged",
        '"run", "--locked", "--offline"', 'Contains("preflight_expectations")',
        "contract_declared_preflight_expectations_passed",
        "$checks.worktree_unchanged = $true",
    ), "QUALIFICATION_RUNNER")
    expectations = runner_contract["preflight_expectations"]
    pointers = [item["json_pointer"] for item in expectations]
    exact(len(pointers), len(set(pointers)), "PREFLIGHT_EXPECTATION_POINTERS")
    mutation_ids = contract["complete_zero_world_gate"]["collector_mutation_ids"]
    exact(len(mutation_ids), len(set(mutation_ids)), "MUTATION_IDS")
    exact(len(mutation_ids),
          contract["complete_zero_world_gate"]["collector_mutation_rejection_count"],
          "MUTATION_COUNT")
    refusals = runner_contract["expected_compile_refusals"]
    exact([item["id"] for item in refusals], ["parallel", "simd-stable"],
          "COMPILE_REFUSAL_IDS")
    require("world.step" not in runner and '"physical"' not in runner,
            "RUNNER_PHYSICAL_PATH")

    verify_declared_source_inventory(ROOT, contract["source_inventory"])
    verify_legacy_live_gate_paths(
        ROOT, contract["live_authority_paths"], contract["live_gate_carrier_id"],
        contract["live_gate_expectations"],
    )
    verify_boolean_partition(contract["claim_boundary"], (
        "phase_exchange_observer_implemented",
        "route_capability_validator_implemented",
        "live_world_collector_implemented",
        "complete_rapier_physical_energy_partition_source_ready",
        "held_out_cells_remain_sealed",
    ), (
        "phase_exchange_observer_qualified", "route_capability_validator_qualified",
        "complete_rapier_energy_partition_physically_observed",
        "controller_behavior_evaluated", "prone_to_standing_claimed",
        "r24d45_reclassified", "cross_engine_equivalence_claimed",
        "sdk1_milestone_advanced", "physical_acceptance_authority",
        "release_authority",
    ), "CLAIM")
    print(
        "QSDK_R24D47_RAPIER_ENERGY_EXCHANGE_SOURCE_PASS "
        "worlds=0 solver_steps=0 mutations=13 partition_source=true physics=false"
    )


if __name__ == "__main__":
    try:
        audit()
    except (ClosureAuditError, OSError, KeyError, ValueError,
            subprocess.SubprocessError) as error:
        print(f"QSDK_R24D47_RAPIER_ENERGY_EXCHANGE_SOURCE_FAIL {error}", file=sys.stderr)
        raise SystemExit(1) from error
