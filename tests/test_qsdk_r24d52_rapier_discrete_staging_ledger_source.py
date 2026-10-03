"""Compact source audit for the prospective QSDK-R24D52 staging ledger."""

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

CONTRACT = ROOT / "sdk/recovery/r24d52_rapier_discrete_staging_ledger_contract_v1.json"


def text(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def audit() -> None:
    contract = load(CONTRACT)
    verify_exact_paths(contract, {
        "schema_version": "sporespore_qsdk_r24d52_rapier_discrete_staging_ledger_contract_v1",
        "gate_id": "QSDK-R24D52",
        "status": "prospective_zero_world_native_telemetry_and_portable_v3_ledger_implemented_qualification_blocked",
        "authored_parent_commit": "223cbb4866aaace9497597ed662800de44d54cad",
        "question_class": "development",
        "supported_native_envelope.engine": "rapier3d_0.34.0",
        "supported_native_envelope.solver_small_steps_per_outer_step": 16,
        "observer_semantics.rule_id": "rapier_discrete_force_position_half_step_staging_exchange_v1",
        "portable_ledger_v3.mapping_profile_id": "rapier_r24d52_native_discrete_staging_energy_v3_mapping_v1",
        "complete_zero_world_gate.positive_control_count": 6,
        "complete_zero_world_gate.mutation_rejection_count": 11,
        "complete_zero_world_gate.total_preflight_check_count": 17,
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
    closure_path = ROOT / predecessor["closure_path"]
    exact(sha256(closure_path.read_bytes()), predecessor["closure_raw_sha256"],
          "R51_CLOSURE_HASH")
    verify_exact_paths(load(closure_path), {
        "gate_id": "QSDK-R24D51",
        "closure_status": predecessor["historical_result"],
        "source.commit": predecessor["source_commit"],
        "decision.pure_staging_observer_design_qualified": True,
        "decision.native_boundary_telemetry_implemented": False,
        "next_boundary.gate_id": "QSDK-R24D52",
    }, "R51_CLOSURE")
    exact_bools(predecessor, (
        "same_identity_requalification_permitted", "historical_result_rewritten",
        "historical_threshold_rewritten", "historical_evaluator_rewritten",
        "historical_interpretation_rewritten",
    ), False, "PREDECESSOR")

    native = contract["native_patch"]
    base_contract_path = ROOT / native["base_complete_patch_contract_path"]
    exact(sha256(base_contract_path.read_bytes()),
          native["base_complete_patch_contract_raw_sha256"], "R47_CONTRACT_HASH")
    base_contract = load(base_contract_path)
    dependency = base_contract["pinned_dependency"]
    exact((dependency["patch_path"], dependency["patch_raw_sha256"]),
          (native["base_complete_patch_path"], native["base_complete_patch_raw_sha256"]),
          "R47_PATCH_IDENTITY")
    _, base_patch = verify_version_pinned_crates_io_patch_source(ROOT, dependency)
    require("pub struct SporeSporeEnergyExchangeTelemetry" in base_patch,
            "R47_PATCH_TELEMETRY")

    delta_path = ROOT / native["successor_delta_path"]
    delta_raw = delta_path.read_bytes()
    exact((len(delta_raw), sha256(delta_raw)),
          (native["successor_delta_byte_length"], native["successor_delta_raw_sha256"]),
          "R52_DELTA_IDENTITY")
    delta = delta_raw.decode("utf-8")
    for marker in (
        'sporespore-discrete-staging-telemetry = ["sporespore-energy-exchange-telemetry"]',
        "SPORESPORE_DISCRETE_STAGING_SMALL_STEP_CAPACITY: usize = 16",
        "pub overflow_small_step_count: u32",
        "pub island_solve_count: u32", "pub ccd_substep_count: u32",
        "pub endpoint_body_count_before: u32", "pub endpoint_body_count_after: u32",
        "self.overflow_small_step_count = self.overflow_small_step_count.saturating_add(1)",
        "#[cfg(feature = \"sporespore-discrete-staging-telemetry\")] gravity: Vector",
    ):
        require(marker in delta, f"NATIVE_MARKER:{marker}")
    require_ordered_markers(delta, (
        "let sporespore_kinetic_energy_before_force =",
        "solver_vels.linear += incr.linear",
        "let sporespore_kinetic_energy_after_force =",
        "let sporespore_raw_gravity_potential_before_position =",
        "self.integrate_positions(params, is_last_substep, bodies, multibodies)",
        "let sporespore_raw_gravity_potential_after_position =",
    ), "NATIVE_SMALL_STEP_BOUNDARIES")
    require_ordered_markers(delta, (
        "sporespore_endpoint_half_step_projection(bodies, gravity, sporespore_outer_step_dt)",
        ".begin_outer_step(projection, body_count)",
        "self.counters.step_started()",
        ".complete_outer_step(projection, body_count)",
        "self.counters.step_completed()",
    ), "NATIVE_ENDPOINT_BOUNDARIES")

    runner_contract = contract["qualification_runner"]
    sequence = runner_contract["successor_patch_sequence"]
    files = runner_contract["successor_patched_files"]
    exact((len(sequence), len(files)), (1, 8), "SUCCESSOR_POPULATION")
    exact((sequence[0]["path"], sequence[0]["byte_length"], sequence[0]["raw_sha256"]),
          (native["successor_delta_path"], native["successor_delta_byte_length"],
           native["successor_delta_raw_sha256"]), "SUCCESSOR_DELTA_BINDING")
    exact(len({item["path"] for item in files}), 8, "SUCCESSOR_FILE_PATHS")
    runner = text(runner_contract["script_path"])
    require_ordered_markers(runner, (
        'if ($runner.Contains("successor_patch_sequence"))',
        '"apply", "--check", [string]$successorPatch.resolved_path',
        '"apply", [string]$successorPatch.resolved_path',
        "$checks.successor_patch_sequence_applied_and_bound = $true",
        "$receipt.successor_patch_sequence = @($successorPatches",
        "$receipt.successor_patched_dependency_files = @($successorPatchedFiles",
    ), "SHARED_SUCCESSOR_RUNNER")
    exact_bools(runner_contract, (
        "shared_runner_reused",
        "shared_runner_extended_for_ordered_content_addressed_successor_deltas",
    ), True, "RUNNER_REUSE")
    exact_bools(runner_contract, (
        "new_zero_world_runner_added", "new_physical_harness_added",
    ), False, "RUNNER_ADDITION")

    ledger = text(contract["portable_ledger_v3"]["implementation_path"])
    require_ordered_markers(ledger, (
        "pub cumulative_signed_external_work_j: f64",
        "pub cumulative_signed_constraint_exchange_j: f64",
        "pub cumulative_signed_discrete_staging_exchange_j: f64",
        "pub cumulative_passive_dissipation_j: f64",
        "let signed_residual_j = ledger.current_mechanical_energy_j",
        "- ledger.cumulative_signed_external_work_j",
        "- ledger.cumulative_signed_constraint_exchange_j",
        "- ledger.cumulative_signed_discrete_staging_exchange_j",
        "+ ledger.cumulative_passive_dissipation_j",
        "threshold_applied: false", "physical_result: false",
    ), "PORTABLE_V3_EQUATION")
    require("digest_serializable(&request.ordered_increments)?" in ledger,
            "PORTABLE_SOURCE_DIGEST")
    subprocess.run(["git", "diff", "--quiet", contract["authored_parent_commit"],
                    "HEAD", "--", "sdk/core/src/recovery_energy.rs"],
                   cwd=ROOT, check=True)

    collector = text(contract["observer_semantics"]["native_collector_path"])
    require_ordered_markers(collector, (
        "pub fn collect_r24d52_rapier_discrete_staging_v1(",
        "telemetry.overflow_small_step_count != 0",
        "measure_r24d51_rapier_discrete_staging_exchange_v1(",
        "pub fn map_r24d52_recovery_energy_increment_v3(",
        "signed_external_work_j: energy.signed_external_work_j",
        "signed_constraint_exchange_j: energy.signed_constraint_exchange_j",
        "signed_discrete_staging_exchange_j: staging.signed_discrete_staging_exchange_j",
        "passive_dissipation_j: energy.passive_dissipation_j",
        "omitted.signed_discrete_staging_exchange_j = 0.0",
        '"mechanical_energy_change_used_as_work_source": false',
        '"energy_balance_residual_used_as_work_source": false',
    ), "NATIVE_TO_PORTABLE_MAPPING")
    require("PhysicsWorld::new" not in collector and ".step(" not in collector,
            "ZERO_WORLD")

    controls = contract["complete_zero_world_gate"]["required_positive_controls"]
    mutations = contract["complete_zero_world_gate"]["mutation_ids"]
    exact((len(controls), len(set(controls))), (6, 6), "CONTROL_IDS")
    exact((len(mutations), len(set(mutations))), (11, 11), "MUTATION_IDS")
    pointers = [item["json_pointer"] for item in runner_contract["preflight_expectations"]]
    exact(len(pointers), len(set(pointers)), "PREFLIGHT_POINTERS")
    verify_declared_source_inventory(ROOT, contract["source_inventory"])
    verify_legacy_live_gate_paths(ROOT, contract["live_authority_paths"],
                                  contract["live_gate_carrier_id"],
                                  contract["live_gate_expectations"])
    verify_boolean_partition(contract["claim_boundary"], (
        "r51_pure_staging_observer_design_qualified",
        "native_boundary_telemetry_implemented",
        "engine_neutral_staging_ledger_v3_implemented",
        "native_to_portable_staging_mapping_implemented",
        "held_out_cells_remain_sealed",
    ), (
        "native_boundary_telemetry_qualified",
        "engine_neutral_staging_ledger_v3_qualified",
        "native_to_portable_staging_mapping_qualified",
        "new_physical_observation_made", "retained_r49_residual_recomputed",
        "retained_r49_result_reclassified", "controller_behavior_evaluated",
        "prone_to_standing_claimed", "repeatability_rate_claimed",
        "population_claimed", "held_out_validation_claimed",
        "cross_engine_recovery_claimed", "cross_engine_equivalence_claimed",
        "sdk1_milestone_advanced", "physical_acceptance_authority",
        "release_authority",
    ), "CLAIM")
    print("QSDK_R24D52_RAPIER_DISCRETE_STAGING_LEDGER_SOURCE_PASS "
          "physical=0 worlds=0 solver_steps=0 controls=6 mutations=11 successor_files=8")


if __name__ == "__main__":
    try:
        audit()
    except (ClosureAuditError, OSError, KeyError, TypeError, ValueError,
            subprocess.SubprocessError) as error:
        print(f"QSDK_R24D52_RAPIER_DISCRETE_STAGING_LEDGER_SOURCE_FAIL {error}",
              file=sys.stderr)
        raise SystemExit(1) from error
