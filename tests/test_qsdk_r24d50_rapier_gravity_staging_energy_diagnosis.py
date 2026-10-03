"""Audit the zero-world R24D50 Rapier gravity-staging diagnosis."""

from __future__ import annotations

from copy import deepcopy
from pathlib import Path
import subprocess
import sys
from typing import Any, Callable

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError, exact, exact_bools, git, load, loads, require, sha256,
    source_bytes, verify_exact_paths, verify_legacy_live_gate_paths,
    verify_retained_commit, verify_source_binding,
)
from sdk.conformance.retained_energy_trace_diagnosis import (  # noqa: E402
    RetainedEnergyTraceError, rapier_energy_residual_decomposition_v1,
    rapier_zero_control_gravity_staging_projection_v1,
)

REPORT_PATH = ROOT / "sdk/recovery/r24d50_rapier_gravity_staging_energy_diagnosis_v1.json"
SOURCE = "5b00ad16943e552f851ef31c4032bb6140362b15"
CLOSURE_COMMIT = "b14b106fc79a74c6b4d269de26f25ac9e6a21e30"


def _arm(arm: dict[str, Any]) -> dict[str, Any]:
    """Copy only data consumed by the common diagnostic."""
    return {
        "trace": {"observations": deepcopy(arm["trace"]["observations"])},
        "energy_samples": deepcopy(arm["energy_samples"]),
        "portable_step_receipts": deepcopy(arm["portable_step_receipts"]),
    }


def _rejects(expected: str, call: Callable[[], object]) -> None:
    caught: RetainedEnergyTraceError | None = None
    try:
        call()
    except RetainedEnergyTraceError as error:
        caught = error
    exact(str(caught), expected, f"MUTATION:{expected}")


def _mutation_controls(matched: dict[str, Any]) -> None:
    value = _arm(matched)
    value["energy_samples"].pop()
    _rejects("RAPIER_RETAINED_ENERGY_ARM_COUNT",
             lambda: rapier_energy_residual_decomposition_v1(value))

    value = _arm(matched)
    value["energy_samples"][0]["sequence"] = 2
    _rejects("RAPIER_RETAINED_ENERGY_SAMPLE_IDENTITY:0",
             lambda: rapier_energy_residual_decomposition_v1(value))

    value = _arm(matched)
    value["trace"]["observations"][0]["energy_balance"][
        "cumulative_signed_constraint_exchange_j"
    ] += 1.0
    _rejects("RAPIER_RETAINED_ENERGY_CUMULATIVE_IDENTITY:0",
             lambda: rapier_energy_residual_decomposition_v1(value))

    value = _arm(matched)
    value["trace"]["observations"][0]["applied_actuation"][
        "ordered_applied_impulses"
    ][0]["applied_angular_impulse_nms"] = 0.01
    _rejects(
        "RAPIER_GRAVITY_STAGING_ZERO_CONTROL:0",
        lambda: rapier_zero_control_gravity_staging_projection_v1(
            value, total_dynamic_mass_kg=4.72, terminal_window_outer_steps=64
        ),
    )

    value = _arm(matched)
    value["trace"]["observations"][1]["state"]["gravity_world_m_s2"]["y"] = -9.7
    _rejects(
        "RAPIER_GRAVITY_STAGING_ROUTE_DRIFT:1",
        lambda: rapier_zero_control_gravity_staging_projection_v1(
            value, total_dynamic_mass_kg=4.72, terminal_window_outer_steps=64
        ),
    )
    _rejects(
        "RAPIER_GRAVITY_STAGING_MASS",
        lambda: rapier_zero_control_gravity_staging_projection_v1(
            _arm(matched), total_dynamic_mass_kg=0.0,
            terminal_window_outer_steps=64,
        ),
    )
    _rejects(
        "RAPIER_GRAVITY_STAGING_WINDOW",
        lambda: rapier_zero_control_gravity_staging_projection_v1(
            _arm(matched), total_dynamic_mass_kg=4.72,
            terminal_window_outer_steps=0,
        ),
    )


def _source_basis(report: dict[str, Any]) -> None:
    basis = report["qualified_dependency_source_basis"]
    closure_raw = (ROOT / basis["closure_path"]).read_bytes()
    exact(sha256(closure_raw), basis["closure_raw_sha256"], "R47_CLOSURE_HASH")
    closure = loads(closure_raw)
    exact(
        (
            closure["source"]["commit"],
            closure["qualification"]["evidence_root"],
            closure["qualification"]["retained_tree"]["manifest_canonical_sha256"],
        ),
        (
            basis["source_commit"], basis["evidence_root"],
            basis["retained_tree_canonical_sha256"],
        ),
        "R47_BASIS",
    )
    source_claim = basis["patched_velocity_solver"]
    source_raw = (Path(basis["evidence_root"]) / source_claim["path"]).read_bytes()
    exact((len(source_raw), sha256(source_raw)),
          (source_claim["byte_length"], source_claim["raw_sha256"]),
          "PATCHED_VELOCITY_SOLVER")

    bound = {
        item["path"]: verify_source_binding(ROOT, SOURCE, item)
        for item in report["frozen_source_bindings"]
    }
    exact(len(bound), 11, "SOURCE_BINDING_COUNT")
    text = {path: raw.decode("utf-8") for path, raw in bound.items()}
    required = {
        "sdk/adapters/rapier/src/lib.rs": ("pub const RAPIER_DT_S: f32 = 1.0 / 120.0;",),
        "sdk/adapters/rapier/src/active_configuration.rs": (
            "RAPIER_ACTIVE_SOLVER_ITERATIONS: usize = 16",
            "world.integration_parameters.dt = RAPIER_DT_S",
            "num_solver_iterations = RAPIER_ACTIVE_SOLVER_ITERATIONS",
        ),
        "sdk/adapters/rapier/src/locomotion.rs": (
            "new_active_world(Vector::new(0.0, -9.8, 0.0))",
        ),
        "sdk/adapters/rapier/src/qsdk_r24d45_recovery_route.rs": (
            "let base_descriptor = r23d60_selected_s169_descriptor();",
            "compile_bounded_quadruped(base_descriptor.clone())",
            "body.kinetic_energy() as f64", "body.gravitational_potential_energy(",
        ),
        "sdk/adapters/rapier/src/qsdk_r24d47_energy_exchange_observer.rs": (
            "integration_and_numerical_exchange_role",
            '"independent_v2_energy_balance_residual"',
            "signed_constraint_exchange_j",
        ),
        "sdk/adapters/rapier/src/qsdk_r24d48_recovery_energy_v2_route.rs": (
            '"constraint": "r24d47.signed_constraint_exchange_j"',
            '"energy_balance_residual_used_as_work_source": false',
        ),
        "sdk/core/src/quadruped.rs": (
            "mass_kg: 3.0", "let upper_mass = 0.25 * mass_multiplier;",
            "let distal_mass = 0.18 * mass_multiplier;",
            "assert_eq!(compiled.morphology.total_mass_kg, 4.72);",
        ),
        "sdk/core/src/recovery_energy.rs": (
            "current_minus_initial_minus_actuator_minus_external_minus_constraint_plus_passive_v2",
            "- ledger.cumulative_signed_constraint_exchange_j",
        ),
        "sdk/adapters/rapier/engine_patches/rapier3d_0_34_0_sporespore_energy_exchange_telemetry_v2.patch": (
            "sporespore_kinetic_energy", "contact_warmstart_exchange",
        ),
    }
    for path, markers in required.items():
        require(all(marker in text[path] for marker in markers), f"SOURCE_MARKERS:{path}")
    r17 = loads(bound["sdk/recovery/r24d17_native_recovery_runtime_and_physical_profile_contract_v1.json"])
    r47 = loads(bound["sdk/recovery/r24d47_rapier_energy_exchange_accounting_contract_v1.json"])
    exact(r17["geometry_and_weight_provenance"]["total_mass_kg"], 4.72, "MASS")
    exact(r47["supported_route"]["solver_small_steps_per_outer_step"], 16, "SMALL_STEPS")
    exact(
        r47["route_energy_partition"]["gravity_work_ledger_channel"],
        "excluded_because_gravitational_potential_energy_is_in_mechanical_energy",
        "GRAVITY_PARTITION",
    )

    dependency = source_raw.decode("utf-8")
    markers = (
        "solver_vel_incr.linear = rb.forces.force * rb.mprops.effective_inv_mass * params.dt;",
        "for substep_id in 0..num_substeps",
        "solver_vels.linear += incr.linear;",
        "let sporespore_energy_before = self.solver_bodies.sporespore_kinetic_energy();",
        "contact_constraints",
        "pub fn integrate_positions",
    )
    positions: list[int] = []
    cursor = 0
    for marker in markers:
        cursor = dependency.index(marker, cursor)
        positions.append(cursor)
        cursor += len(marker)
    require(positions == sorted(positions), "PATCHED_FORCE_MEASUREMENT_POSITION_ORDER")


def _retained_result(report: dict[str, Any]) -> tuple[dict[str, Any], dict[str, Any]]:
    evidence = report["retained_evidence"]
    raw = (Path(evidence["evidence_root"]) / evidence["full_result_path"]).read_bytes()
    exact((len(raw), sha256(raw)),
          (evidence["full_result_byte_length"], evidence["full_result_raw_sha256"]),
          "TRACE_IDENTITY")
    result = loads(raw)
    candidate, matched = result["candidate"], result["matched_zero_command"]
    exact((candidate["outer_step_count"], matched["outer_step_count"]),
          (evidence["candidate_outer_step_count"], evidence["matched_zero_outer_step_count"]),
          "ARM_COUNTS")
    exact((candidate["declared_initial_state_sha256"], matched["declared_initial_state_sha256"]),
          (evidence["paired_initial_state_sha256"],) * 2, "INITIAL_STATE")

    left, right = candidate["trace"]["observations"], matched["trace"]["observations"]
    equal = [
        left[i]["state"] == right[i]["state"]
        and left[i]["center_of_mass"] == right[i]["center_of_mass"]
        and left[i]["energy_balance"] == right[i]["energy_balance"]
        for i in range(min(len(left), len(right)))
    ]
    divergence = next(i for i, value in enumerate(equal) if not value)
    active = [
        i for i, observation in enumerate(left)
        if any(float(item["applied_angular_impulse_nms"]) != 0.0
               for item in observation["applied_actuation"]["ordered_applied_impulses"])
    ]
    exact(
        (divergence, active[0], all(equal[:divergence])),
        (
            evidence["first_candidate_matched_zero_physical_state_center_of_mass_or_energy_divergence_outer_index_zero_based"],
            evidence["candidate_first_active_application_outer_index_zero_based"], True,
        ),
        "PAIRED_PREFIX",
    )
    exact(divergence,
          evidence["paired_physical_state_center_of_mass_and_energy_equal_prefix_outer_step_count"],
          "PAIRED_PREFIX_COUNT")
    require(all(observation["applied_actuation"]["zero_command"] is True for observation in right),
            "MATCHED_ZERO_IDENTITY")
    return candidate, matched


def audit() -> None:
    report = load(REPORT_PATH)
    verify_exact_paths(report, {
        "schema_version": "sporespore_qsdk_r24d50_rapier_gravity_staging_energy_diagnosis_v1",
        "gate_id": "QSDK-R24D50",
        "analysis_class": "repeatable_zero_world_retained_trace_development_diagnosis",
        "authored_parent_commit": CLOSURE_COMMIT, "question_class": "development",
        "physical_question_declared": False, "model_construction_count": 0,
        "world_attempt_count": 0, "world_build_count": 0, "solver_step_count": 0,
        "physics_state_modified": False,
    }, "REPORT")
    predecessor = report["predecessor"]
    exact((predecessor["gate_id"], predecessor["source_commit"], predecessor["closure_commit"]),
          ("QSDK-R24D49", SOURCE, CLOSURE_COMMIT), "PREDECESSOR")
    verify_retained_commit(ROOT, CLOSURE_COMMIT, SOURCE)
    exact(sha256((ROOT / predecessor["closure_path"]).read_bytes()),
          predecessor["closure_raw_sha256"], "PREDECESSOR_HASH")
    exact_bools(predecessor, tuple(key for key in predecessor if key.endswith("_rewritten")
                                  or key.endswith("_permitted")), False, "PREDECESSOR_LIMITS")

    _source_basis(report)
    candidate, matched = _retained_result(report)
    exact(rapier_energy_residual_decomposition_v1(candidate),
          report["residual_decomposition"]["candidate"], "CANDIDATE_DECOMPOSITION")
    exact(rapier_energy_residual_decomposition_v1(matched),
          report["residual_decomposition"]["matched_zero"], "ZERO_DECOMPOSITION")
    exact(
        rapier_zero_control_gravity_staging_projection_v1(
            matched, total_dynamic_mass_kg=4.72, terminal_window_outer_steps=64
        ),
        report["gravity_staging_projection"]["matched_zero"], "PROJECTION",
    )
    verify_exact_paths(report["gravity_staging_projection"], {
        "new_threshold_count": 0, "new_margin_count": 0,
        "physical_cohort_count": 0, "population_claim_count": 0,
    }, "PROJECTION_LIMITS")
    _mutation_controls(matched)

    diagnosis = report["diagnosis"]
    positive = tuple(key for key, value in diagnosis.items() if value is True)
    negative = tuple(key for key, value in diagnosis.items() if value is False)
    exact(len(positive), 11, "DIAGNOSIS_POSITIVE_COUNT")
    exact(len(negative), 13, "DIAGNOSIS_LIMIT_COUNT")
    exact_bools(diagnosis, positive, True, "DIAGNOSIS_POSITIVE")
    exact_bools(diagnosis, negative, False, "DIAGNOSIS_LIMIT")
    exact(report["sdk_status"], {
        "sdk1_milestone_advanced": False, "sdk1_completed_steps": 11,
        "sdk1_total_steps": 20, "full_program_completed_steps": 11,
        "full_program_total_steps": 25,
    }, "SDK_STATUS")
    verify_exact_paths(report["next_boundary"], {
        "gate_id": "QSDK-R24D51", "physical_question_declared": False,
        "same_identity_rerun_permitted": False, "new_threshold_or_margin_selected": False,
        "next_physical_execution_authorized": False, "maximum_physical_steps_authorized": 0,
        "additional_physical_canary_required": False, "held_out_cells_remain_sealed": True,
        "prone_to_standing_claimed": False, "physical_acceptance_authority": False,
        "release_authority": False,
    }, "NEXT")
    claim = report["claim_boundary"]
    exact_bools(claim, ("retained_trace_and_frozen_source_diagnosed",
                        "specific_successor_measurement_boundary_identified"), True, "CLAIM")
    exact_bools(claim, tuple(key for key, value in claim.items() if value is False),
                False, "CLAIM_LIMIT")

    relative = REPORT_PATH.relative_to(ROOT).as_posix()
    publication = git(ROOT, "log", "-1", "--diff-filter=A", "--format=%H", "--", relative)
    assert isinstance(publication, str)
    revision = publication or None
    report_raw = REPORT_PATH.read_bytes() if revision is None else source_bytes(ROOT, revision, relative)
    verify_legacy_live_gate_paths(
        ROOT, report["live_authority_paths"], "QSDK-R24D45",
        {**report["live_gate_expectations"], "r24d50_diagnosis_raw_sha256": sha256(report_raw)},
        revision=revision,
    )
    print(
        "QSDK_R24D50_RAPIER_GRAVITY_STAGING_ENERGY_DIAGNOSIS_PASS "
        "physical=0 candidate_steps=967 zero_steps=252 equal_prefix=12 "
        "terminal_constraint_projection_fraction=0.9995304891004322 "
        "terminal_window=64 mutations=7 next=QSDK-R24D51:zero_world_observer_design"
    )


if __name__ == "__main__":
    try:
        audit()
    except (ClosureAuditError, RetainedEnergyTraceError, OSError, KeyError, IndexError,
            TypeError, ValueError, subprocess.SubprocessError) as error:
        print(f"QSDK_R24D50_RAPIER_GRAVITY_STAGING_ENERGY_DIAGNOSIS_FAIL {error}",
              file=sys.stderr)
        raise SystemExit(1) from error
