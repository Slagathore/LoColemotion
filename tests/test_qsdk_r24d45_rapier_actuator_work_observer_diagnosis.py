from __future__ import annotations

from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError, exact, exact_bools, find_external_source_root, load,
    require, require_ordered_markers, sha256, source_bytes, verify_exact_paths,
    verify_legacy_live_gate_paths, verify_retained_commit, verify_source_binding,
)


REPORT = ROOT / "sdk/recovery/r24d45_rapier_actuator_work_observer_diagnosis_v1.json"
PARENT = "1fc1f4a3ce55d154594113dc312ab580761815a2"
PUBLICATION = "756cb70e9b30afa57aa952bd3bde3e6f30a572f0"


def audit() -> None:
    report = load(REPORT)
    verify_retained_commit(ROOT, PUBLICATION, PARENT)
    verify_exact_paths(report, {
        "schema_version": "sporespore_qsdk_r24d45_rapier_actuator_work_observer_diagnosis_v1",
        "analysis_class": "zero_world_frozen_source_development_diagnosis",
        "authored_parent_commit": PARENT,
        "question_class": "development",
        "physical_question_declared": False,
        "behavior_question_declared": False,
        "physics_state_modified": False,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "outer_adapter_step_count": 0,
        "rapier_small_step_count": 0,
    }, "IDENTITY")
    predecessor = report["predecessor"]
    exact(predecessor["gate_id"], "QSDK-R24D45", "PREDECESSOR_GATE")
    verify_retained_commit(ROOT, PARENT, predecessor["source_commit"])
    closure = (ROOT / predecessor["closure_path"]).read_bytes()
    exact((len(closure), sha256(closure)), (predecessor["closure_byte_length"],
          predecessor["closure_raw_sha256"]), "CLOSURE_IDENTITY")
    exact_bools(predecessor, (
        "same_identity_rerun_permitted", "same_identity_requalification_permitted",
        "historical_result_rewritten", "historical_threshold_rewritten",
        "historical_evaluator_rewritten", "historical_interpretation_rewritten",
        "post_closure_diagnosis_may_reclassify_r24d45",
    ), False, "PREDECESSOR_IMMUTABILITY")

    repo = {
        binding["path"]: verify_source_binding(ROOT, PARENT, binding).decode("utf-8")
        for binding in report["repo_source_bindings"]
    }
    exact(len(repo), 5, "REPO_SOURCE_COUNT")
    dependency = report["pinned_rapier_dependency"]
    require_ordered_markers(repo["sdk/Cargo.lock"], (
        'name = "rapier3d"', f'version = "{dependency["version"]}"',
        f'source = "{dependency["registry_source"]}"',
        f'checksum = "{dependency["cargo_registry_checksum"]}"',
    ), "RAPIER_LOCK")
    upstream_root = find_external_source_root(
        Path.home() / ".cargo/registry/src",
        dependency["installed_source_root_suffix"], dependency["upstream_files"],
    )
    upstream = {
        binding["path"]: (upstream_root / binding["path"]).read_text(encoding="utf-8")
        for binding in dependency["upstream_files"]
    }
    require("max_impulse: self.max_force * dt" in upstream[
        "src/dynamics/joint/generic_joint.rs"
    ], "SMALL_STEP_CAP")
    require_ordered_markers(upstream["src/dynamics/solver/island_solver.rs"], (
        "params.dt /= num_solver_iterations as Real",
        "self.velocity_solver.solve_constraints(",
        "self.joint_constraints.writeback_impulses(impulse_joints)",
    ), "SMALL_STEP_FINAL_WRITEBACK")
    require_ordered_markers(upstream["src/dynamics/solver/velocity_solver.rs"], (
        "for substep_id in 0..num_substeps", "joint_constraints.update(params",
        "joint_constraints.solve(", "contact_constraints.solve(",
        "self.integrate_positions(params",
    ), "INTERLEAVED_SMALL_STEP_SOLVE")
    builder = upstream[
        "src/dynamics/solver/joint_constraint/joint_constraint_builder.rs"
    ]
    motor = builder[builder.index("pub fn motor_angular"):builder.index("pub fn lock_angular")]
    require("impulse: N::zero()" in motor, "MOTOR_IMPULSE_RESET")
    constraint = upstream[
        "src/dynamics/solver/joint_constraint/joint_velocity_constraint.rs"
    ]
    for marker in (
        "solver_vel2.angular) - self.ang_jac1.gdot(solver_vel1.angular)",
        "solver_vel1.angular += ii_ang_impulse1",
        "solver_vel2.angular -= ii_ang_impulse2",
        "joint.data.motors[i].impulse = self.impulse",
    ):
        require(marker in constraint, f"MOTOR_SIGN_AND_WRITEBACK:{marker}")

    require("pub const RAPIER_DT_S: f32 = 1.0 / 120.0" in
            repo["sdk/adapters/rapier/src/lib.rs"], "OUTER_DT")
    active = repo["sdk/adapters/rapier/src/active_configuration.rs"]
    for marker in (
        "RAPIER_ACTIVE_SOLVER_ITERATIONS: usize = 16",
        "RAPIER_ACTIVE_INTERNAL_PGS_ITERATIONS: usize = 3",
        "RAPIER_ACTIVE_INTERNAL_STABILIZATION_ITERATIONS: usize = 5",
    ):
        require(marker in active, f"ACTIVE_CONFIGURATION:{marker}")
    route_source = repo["sdk/adapters/rapier/src/qsdk_r24d45_recovery_route.rs"]
    route = route_source[
        route_source.index("fn apply_and_step_r24d45_recovery_v1("):
        route_source.index("fn valid_sha256(")
    ]
    require_ordered_markers(route, (
        "world.robot.world.step();", "motor.impulse as f64",
        "signed_impulse_nms * centered_velocity_rad_s",
    ), "R45_TERMINAL_READBACK_PRODUCT")
    velocity = route_source[
        route_source.index("fn joint_velocity_rad_s("):
        route_source.index("fn whole_system_center_of_mass(")
    ]
    require("(child.angvel() - parent.angvel()).dot(axis)" in velocity, "R45_RELATIVE_VELOCITY_SIGN")

    semantics = report["frozen_execution_semantics"]
    exact((
        semantics["configured_solver_small_steps_per_outer_adapter_step"],
        semantics["configured_internal_pgs_iterations_per_small_step"],
        semantics["configured_internal_stabilization_iterations_per_small_step"],
    ), (16, 3, 5), "DECLARED_CONFIGURATION")
    exact_bools(semantics, (
        "rapier_actually_executes_sixteen_small_steps_inside_each_counted_outer_call",
        "motor_constraint_impulse_resets_when_each_small_step_rebuilds_constraints",
        "joint_motor_impulse_after_outer_step_is_only_the_final_small_step_constraint_impulse",
        "joint_motor_impulse_after_outer_step_is_not_the_sum_of_all_sixteen_small_step_impulses",
        "r45_reads_joint_motor_impulse_once_after_the_outer_world_step",
    ), True, "SOURCE_SEMANTICS")
    exact(semantics["r45_retains_first_fifteen_small_step_motor_impulses"], False,
          "MISSING_IMPULSE_HISTORY")
    diagnosis = report["diagnosis"].copy()
    require(diagnosis.pop("r45_actuator_work_observer_defect_proven_by_frozen_source") is True
            and not any(diagnosis.values()), "DIAGNOSIS_CLAIM_INFLATION")
    exact(len(report["rejected_shortcuts"]), 7, "SHORTCUT_COUNT")
    live = {
        **report["live_gate_expectations"],
        "r24d45_post_closure_observer_diagnosis_raw_sha256": sha256(
            source_bytes(ROOT, PUBLICATION, REPORT.relative_to(ROOT).as_posix())
        ),
    }
    verify_legacy_live_gate_paths(
        ROOT, report["live_authority_paths"], "QSDK-R24D45", live,
        revision=PUBLICATION,
    )
    verify_exact_paths(report["next_boundary"], {
        "gate_id": "QSDK-R24D46", "question_class": "development",
        "host_split_route_may_be_used_without_distinct_equivalence_characterization": False,
        "physical_question_declared": False, "next_physical_execution_authorized": False,
        "maximum_physical_steps_authorized": 0, "held_out_cells_remain_sealed": True,
    }, "NEXT")
    print(
        "QSDK_R24D45_RAPIER_ACTUATOR_WORK_OBSERVER_DIAGNOSIS_PASS "
        "worlds=0 outer_steps=0 small_steps=0 configured_small_steps=16 "
        "terminal_only=true sign_inverted=true reconstruction=false "
        "r24d45_reclassified=false next=QSDK-R24D46:zero_world"
    )


if __name__ == "__main__":
    try:
        audit()
    except (ClosureAuditError, OSError, KeyError, ValueError) as error:
        print(f"QSDK_R24D45_RAPIER_ACTUATOR_WORK_OBSERVER_DIAGNOSIS_FAIL {error}", file=sys.stderr)
        raise SystemExit(1) from error
