//! Retained geometry and refusal controls. No native world or task success.
use super::*;

fn entries() -> Vec<(u64, BoundedQuadrupedDescriptor, RecoveryObservationV3)> {
    let value: serde_json::Value = serde_json::from_str(include_str!(
        "../../../contracts/r10z_retained_partial_entries_v1.json"
    ))
    .unwrap();
    value["entries"]
        .as_array()
        .unwrap()
        .iter()
        .map(|row| {
            (
                row["seed"].as_u64().unwrap(),
                serde_json::from_value(row["descriptor"].clone()).unwrap(),
                serde_json::from_value(row["observation"].clone()).unwrap(),
            )
        })
        .collect()
}

#[test]
fn r10z_four_retained_entries_generate_finite_deterministic_bounded_references() {
    for (seed, d, o) in entries() {
        let before = serde_json::to_value(&o).unwrap();
        let plan = reference(&d, &o).unwrap();
        println!("R10Z_GEOMETRY_ENTRY {}", json!({"seed":seed,"plan":plan}));
        assert_eq!(plan, reference(&d, &o).unwrap());
        assert_eq!(135, plan.candidate_count);
        assert!(plan.feasible_candidate_count > 0);
        assert!(
            plan.hold_reason.is_none(),
            "seed {seed}: {:?}",
            plan.hold_reason
        );
        assert!(plan.selected_model_cost.unwrap() < plan.initial_model_cost.unwrap());
        for (i, target) in plan.ordered_target_positions_rad.iter().enumerate() {
            assert!(target.is_finite() && target.abs() <= if i % 2 == 0 { 1.6 } else { 1.1 });
            assert!(
                (target - o.state.ordered_joint_observations[i].position_rad.unwrap()).abs()
                    <= 4.0 / 120.0
            );
        }
        assert!(plan.maximum_unactuated_lateral_residual_m <= 0.0005);
        assert_eq!(before, serde_json::to_value(&o).unwrap());
        assert!(
            !plan.native_source_validation_performed
                && !plan.physical_acceptance_authority
                && !plan.release_authority
        );
        assert_eq!((0, 0), (plan.world_build_count, plan.solver_step_count));
    }
}

#[test]
fn r10z_inverse_targets_reconstruct_each_projected_endpoint() {
    for (_, d, o) in entries() {
        let g = Geometry {
            upper: 0.35 * d.upper_length_fraction,
            lower: 0.35 * (1.0 - d.upper_length_fraction),
            radius: 0.04 * d.foot_radius_scale,
            span: d.hip_span_scale,
        };
        let measured =
            std::array::from_fn(|i| o.state.ordered_joint_observations[i].position_rad.unwrap());
        let p = vec(o.state.base_pose_world.position_m);
        let q = o.state.base_pose_world.orientation_xyzw;
        let feet = std::array::from_fn(|i| add(p, rotate(q, g.foot(i, &measured))));
        let within_limits = (0..8).all(|i| measured[i].abs() <= if i % 2 == 0 { 1.6 } else { 1.1 });
        if within_limits {
            let (solved, residual) = g.solve(&feet, p, q, &measured).unwrap();
            assert!(residual < 1e-12);
            for i in 0..8 {
                assert!((solved[i] - measured[i]).abs() < 1e-12);
            }
        } else {
            assert!(g.solve(&feet, p, q, &measured).is_none());
        }
        let plan = reference(&d, &o).unwrap();
        let forward = rotate(q, [1.0, 0.0, 0.0]);
        let yaw = (-forward[2]).atan2(forward[0]);
        let flat = Quaternion {
            x: 0.0,
            y: (yaw / 2.0).sin(),
            z: 0.0,
            w: (yaw / 2.0).cos(),
        };
        let next_q = blend(q, flat, plan.selected_virtual_level_blend);
        let next_p = add(p, plan.selected_virtual_translation_world_m);
        for i in 0..4 {
            let endpoint = add(
                next_p,
                rotate(next_q, g.foot(i, &plan.ordered_target_positions_rad)),
            );
            // Lateral error is explicitly retained; no unavailable third joint
            // or fictitious native foot observation is introduced to remove it.
            let mut target = feet[i];
            let floor = plan.modeled_support_plane_world_y_m.unwrap();
            if plan.seeking_contact[i] && target[1] > floor + g.radius {
                target[1] = (target[1] - 0.1 / 120.0 * plan.selected_candidate_scale.unwrap())
                    .max(floor + g.radius);
            }
            let local_old = rotate(inverse(next_q), sub(target, next_p));
            let local_new = rotate(inverse(next_q), sub(endpoint, next_p));
            assert!((local_old[0] - local_new[0]).abs() < 1e-12);
            assert!((local_old[1] - local_new[1]).abs() < 1e-12);
        }
    }
}

#[test]
fn r10z_rejects_missing_crossed_nonfinite_and_out_of_range_geometry() {
    let (_, d, o) = entries().remove(2);
    for case in 0..13 {
        let mut bad = o.clone();
        let mut descriptor = d.clone();
        match case {
            0 => bad.state.ordered_joint_observations.swap(0, 2),
            1 => bad.state.ordered_joint_observations[0].position_rad = None,
            2 => bad.state.ordered_joint_observations[0].position_rad = Some(f64::NAN),
            3 => bad.state.ordered_joint_observations[0].position_rad = Some(1.7),
            4 => bad.state.ordered_contact_observations.swap(0, 1),
            5 => bad.ordered_foot_bearing_observations[0].bearing_normal_impulse_ns = -0.01,
            6 => bad.ordered_foot_bearing_observations[0].source_measurement = false,
            7 => bad.center_of_mass.source_measurement = false,
            8 => bad.center_of_mass.position_world_m.x = f64::INFINITY,
            9 => bad.outer_step_duration_s = 1.0 / 60.0,
            10 => bad.semantic_step += 1,
            11 => descriptor.hip_span_scale += 0.001,
            _ => bad.state.base_pose_world.orientation_xyzw.w = 2.0,
        }
        assert!(reference(&descriptor, &bad).is_err(), "case {case}");
    }
}

#[test]
fn r10z_native_joint_overshoot_is_retained_and_commands_return_within_bounds() {
    for (seed, d, mut o) in entries() {
        if ![41341, 51009].contains(&seed) {
            continue;
        }
        let original = serde_json::to_value(&o).unwrap();
        let plan = reference(&d, &o).unwrap();
        assert!(plan.measured_joint_boundary_return_count > 0);
        assert_eq!(original, serde_json::to_value(&o).unwrap());
        for c in &mut o.state.ordered_contact_observations {
            c.presence = Some(false);
            c.bears_support = Some(false);
        }
        for c in &mut o.ordered_foot_bearing_observations {
            c.bearing_normal_impulse_ns = 0.0;
        }
        let held = reference(&d, &o).unwrap();
        assert_eq!(Some("no_bearing_reference"), held.hold_reason.as_deref());
        for (i, target) in held.ordered_target_positions_rad.iter().enumerate() {
            let bound = if i % 2 == 0 { 1.6 } else { 1.1 };
            let measured = o.state.ordered_joint_observations[i].position_rad.unwrap();
            assert_eq!(*target, measured.clamp(-bound, bound));
            assert!((target - measured).abs() <= 4.0 / 120.0);
        }
    }
}

#[test]
fn r10z_contact_loss_is_explicit_and_no_reference_requests_measured_hold() {
    let (_, d, mut o) = entries().remove(2);
    for c in &mut o.state.ordered_contact_observations {
        c.presence = Some(false);
        c.bears_support = Some(false);
    }
    for c in &mut o.ordered_foot_bearing_observations {
        c.bearing_normal_impulse_ns = 0.0;
    }
    let plan = reference(&d, &o).unwrap();
    assert_eq!(Some("no_bearing_reference"), plan.hold_reason.as_deref());
    assert_eq!(0, plan.candidate_count);
    assert_eq!([true; 4], plan.seeking_contact);
    for (target, joint) in plan
        .ordered_target_positions_rad
        .iter()
        .zip(&o.state.ordered_joint_observations)
    {
        assert_eq!(*target, joint.position_rad.unwrap());
    }
    o.state.ordered_contact_observations[2].presence = Some(true);
    o.state.ordered_contact_observations[2].bears_support = Some(true);
    o.ordered_foot_bearing_observations[2].bearing_normal_impulse_ns = 0.05;
    let plan = reference(&d, &o).unwrap();
    assert_eq!(1, plan.bearing_reference_count);
    assert_eq!([true, true, false, true], plan.seeking_contact);
    assert_eq!(135, plan.candidate_count);
}

#[test]
fn r10z_singular_and_unreachable_inverse_geometry_cannot_escape_limits() {
    let (_, d, mut o) = entries().remove(2);
    let g = Geometry {
        upper: 0.35 * d.upper_length_fraction,
        lower: 0.35 * (1.0 - d.upper_length_fraction),
        radius: 0.04 * d.foot_radius_scale,
        span: d.hip_span_scale,
    };
    let zero = [0.0; 8];
    let feet = std::array::from_fn(|i| g.foot(i, &zero));
    // Fully extended legs sit on the singular boundary. Outside reach is
    // refused, not clamped to a fabricated reachable endpoint.
    assert!(
        g.solve(&feet, [0.0, 0.01, 0.0], Quaternion::IDENTITY, &zero)
            .is_none()
    );
    for j in &mut o.state.ordered_joint_observations {
        j.position_rad = Some(0.0);
    }
    let q = Quaternion {
        x: 0.0,
        y: 0.0,
        z: (std::f64::consts::PI / 4.0).sin(),
        w: (std::f64::consts::PI / 4.0).cos(),
    };
    o.state.base_pose_world.orientation_xyzw = q;
    assert_eq!(
        Some("undefined_horizontal_heading"),
        reference(&d, &o).unwrap().hold_reason.as_deref()
    );
}

#[test]
fn r10z_quaternion_sign_and_world_translation_preserve_joint_commands() {
    let (_, d, o) = entries().remove(2);
    let original = reference(&d, &o).unwrap();
    let mut moved = o.clone();
    let q = &mut moved.state.base_pose_world.orientation_xyzw;
    q.x = -q.x;
    q.y = -q.y;
    q.z = -q.z;
    q.w = -q.w;
    moved.state.base_pose_world.position_m.x += 2.0;
    moved.center_of_mass.position_world_m.x += 2.0;
    moved.state.base_pose_world.position_m.y += 1.0;
    moved.center_of_mass.position_world_m.y += 1.0;
    let plan = reference(&d, &moved).unwrap();
    for (a, b) in original
        .ordered_target_positions_rad
        .iter()
        .zip(plan.ordered_target_positions_rad)
    {
        assert!((a - b).abs() < 1e-12);
    }
    assert_eq!(
        original.selected_virtual_level_blend,
        plan.selected_virtual_level_blend
    );
    assert_eq!(
        original.selected_virtual_translation_world_m,
        plan.selected_virtual_translation_world_m
    );
}
