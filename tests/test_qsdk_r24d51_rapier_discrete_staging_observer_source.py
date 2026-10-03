"""Compact source audit for the prospective QSDK-R24D51 observer design."""

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

CONTRACT = ROOT / "sdk/recovery/r24d51_rapier_discrete_staging_observer_contract_v1.json"


def audit() -> None:
    contract = load(CONTRACT)
    verify_exact_paths(contract, {
        "schema_version": "sporespore_qsdk_r24d51_rapier_discrete_staging_observer_contract_v1",
        "gate_id": "QSDK-R24D51",
        "status": "prospective_zero_world_observer_design_implemented_qualification_and_native_wiring_blocked",
        "authored_parent_commit": "54046523c45cc61a76a77abb6505d81fc8fa314f",
        "question_class": "development",
        "supported_design_envelope.solver_small_steps_per_outer_step": 16,
        "observer_semantics.rule_id": "rapier_discrete_force_position_half_step_staging_exchange_v1",
        "identity_adequacy.binary64_control_operation_budget": 1024,
        "complete_zero_world_gate.positive_control_count": 5,
        "complete_zero_world_gate.mutation_rejection_count": 8,
        "complete_zero_world_gate.total_preflight_check_count": 13,
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
    for path_field, hash_field in (
        ("diagnosis_path", "diagnosis_raw_sha256"),
        ("audit_path", "audit_raw_sha256"),
        ("retained_physical_predecessor_path", "retained_physical_predecessor_raw_sha256"),
    ):
        relative = predecessor[path_field]
        exact(sha256((ROOT / relative).read_bytes()), predecessor[hash_field], path_field)
        subprocess.run(["git", "diff", "--quiet", contract["authored_parent_commit"],
                        "--", relative], cwd=ROOT, check=True)
    exact_bools(predecessor, (
        "same_identity_requalification_permitted", "historical_result_rewritten",
        "historical_threshold_rewritten", "historical_evaluator_rewritten",
        "historical_interpretation_rewritten",
    ), False, "PREDECESSOR")

    runner_contract = contract["qualification_runner"]
    dependency_path = ROOT / runner_contract["pinned_dependency_contract_path"]
    exact(sha256(dependency_path.read_bytes()),
          runner_contract["pinned_dependency_contract_raw_sha256"],
          "PINNED_DEPENDENCY_CONTRACT")
    upstream, patch_source = verify_version_pinned_crates_io_patch_source(
        ROOT, load(dependency_path)["pinned_dependency"])
    velocity_solver = (upstream / "src/dynamics/solver/velocity_solver.rs").read_text(
        encoding="utf-8")
    require_ordered_markers(velocity_solver, (
        "solver_vels.linear += incr.linear", ".warmstart(&mut self.solver_bodies",
        "joint_constraints.solve", "self.integrate_positions",
        "joint_constraints", ".solve_wo_bias",
    ), "RAPIER_STAGE_ORDER")
    rigid_body = (upstream / "src/dynamics/rigid_body.rs").read_text(encoding="utf-8")
    require_ordered_markers(rigid_body, (
        "pub fn gravitational_potential_energy(&self, dt: Real, gravity: Vector)",
        "let world_com = self.mprops.local_mprops.world_com(&self.pos.position);",
        "let world_com = world_com - self.vels.linvel * (dt / 2.0);",
        "-self.mass() * self.forces.gravity_scale * gravity.dot(world_com)",
    ), "RAPIER_ENDPOINT_POTENTIAL")
    require("pub struct SporeSporeEnergyExchangeTelemetry" in patch_source,
            "INHERITED_PATCH_TELEMETRY")

    module = (ROOT / contract["observer_semantics"]["implementation_path"]).read_text(
        encoding="utf-8")
    require_ordered_markers(module, (
        "pub struct RapierDiscreteStagingSmallStepV1",
        "pub kinetic_energy_before_force_j: f64",
        "pub kinetic_energy_after_force_j: f64",
        "pub raw_gravity_potential_before_position_j: f64",
        "pub raw_gravity_potential_after_position_j: f64",
        "pub struct RapierEndpointHalfStepProjectionV1",
        "pub fn measure_r24d51_rapier_discrete_staging_exchange_v1(",
        "force_after - force_before", "position_after - position_before",
        "endpoint_after - endpoint_before",
        "force_exchange + position_exchange + endpoint_exchange",
        "pub fn run_qsdk_r24d51_rapier_discrete_staging_zero_world_qualification()",
        '"resting_supported_gravity_kick_and_constraint_cancellation_close"',
        '"free_fall_force_position_and_half_step_terms_match_endpoint_change_once"',
        '"upward_and_downward_free_fall_preserve_the_same_discrete_defect"',
        '"zero_gravity_has_zero_force_position_half_step_and_total_exchange"',
        '"omitted_small_step"', '"duplicated_small_step"', '"reordered_small_steps"',
    ), "OBSERVER")
    start = module.index("pub fn measure_r24d51_rapier_discrete_staging_exchange_v1(")
    signature = module[start:module.index("{", start)]
    for forbidden in ("mechanical", "residual", "threshold", "constraint", "behavior"):
        require(forbidden not in signature, f"FORBIDDEN_OBSERVER_INPUT:{forbidden}")
    require("PhysicsWorld::new" not in module and ".step(" not in module, "ZERO_WORLD")

    library = (ROOT / "sdk/adapters/rapier/src/lib.rs").read_text(encoding="utf-8")
    binary = (ROOT / "sdk/adapters/rapier/src/bin/qsdk_r24d51_discrete_staging_observer.rs").read_text(
        encoding="utf-8")
    for source, marker in (
        (library, "mod qsdk_r24d51_discrete_staging_observer;"),
        (library, "measure_r24d51_rapier_discrete_staging_exchange_v1"),
        (binary, "QSDK_R24D51_RAPIER_DISCRETE_STAGING_ZERO_WORLD"),
    ):
        require(marker in source, f"PUBLIC_ROUTE:{marker}")

    runner = (ROOT / runner_contract["script_path"]).read_text(encoding="utf-8")
    require_ordered_markers(runner, (
        'elseif ($runner.Contains("pinned_dependency_contract_path"))',
        '"apply", "--check", $patchPath', '"check", "--locked", "--offline"',
        'Contains("expected_compile_refusals")', '"run", "--locked", "--offline"',
        'Contains("preflight_expectations")', "$checks.worktree_unchanged = $true",
    ), "SHARED_RUNNER")
    exact_bools(runner_contract, (
        "shared_runner_reused", "inherited_pinned_dependency_manifest_reused",
    ), True, "RUNNER_REUSE")
    exact_bools(runner_contract, (
        "new_zero_world_runner_added", "new_physical_harness_added",
    ), False, "RUNNER_ADDITION")

    controls = contract["complete_zero_world_gate"]["required_positive_controls"]
    mutations = contract["complete_zero_world_gate"]["mutation_ids"]
    exact((len(controls), len(set(controls))), (5, 5), "CONTROL_IDS")
    exact((len(mutations), len(set(mutations))), (8, 8), "MUTATION_IDS")
    pointers = [item["json_pointer"] for item in runner_contract["preflight_expectations"]]
    exact(len(pointers), len(set(pointers)), "PREFLIGHT_POINTERS")
    verify_declared_source_inventory(ROOT, contract["source_inventory"])
    verify_legacy_live_gate_paths(ROOT, contract["live_authority_paths"],
                                  contract["live_gate_carrier_id"],
                                  contract["live_gate_expectations"])
    verify_boolean_partition(contract["claim_boundary"], (
        "pure_staging_observer_design_implemented", "supported_rest_analytic_control_passed",
        "free_fall_analytic_control_passed", "moving_vertical_and_zero_gravity_controls_passed",
        "topology_and_finiteness_mutations_rejected", "held_out_cells_remain_sealed",
    ), (
        "pure_staging_observer_design_qualified", "native_boundary_telemetry_implemented",
        "native_boundary_telemetry_qualified", "engine_neutral_staging_ledger_implemented",
        "retained_r49_residual_recomputed", "retained_r49_result_reclassified",
        "controller_behavior_evaluated", "prone_to_standing_claimed",
        "cross_engine_equivalence_claimed", "sdk1_milestone_advanced",
        "physical_acceptance_authority", "release_authority",
    ), "CLAIM")
    print("QSDK_R24D51_RAPIER_DISCRETE_STAGING_SOURCE_PASS "
          "physical=0 worlds=0 solver_steps=0 controls=5 mutations=8 wiring=false")


if __name__ == "__main__":
    try:
        audit()
    except (ClosureAuditError, OSError, KeyError, ValueError,
            subprocess.SubprocessError) as error:
        print(f"QSDK_R24D51_RAPIER_DISCRETE_STAGING_SOURCE_FAIL {error}", file=sys.stderr)
        raise SystemExit(1) from error
