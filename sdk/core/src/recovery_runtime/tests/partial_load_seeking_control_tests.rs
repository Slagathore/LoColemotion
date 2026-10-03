//! Finite exposed inputs, independent endpoint checks and refusal controls.
use super::*;

fn entries() -> Vec<(BoundedQuadrupedDescriptor, RecoveryObservationV3)> {
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
                serde_json::from_value(row["descriptor"].clone()).unwrap(),
                serde_json::from_value(row["observation"].clone()).unwrap(),
            )
        })
        .collect()
}

fn retained() -> Vec<(BoundedQuadrupedDescriptor, RecoveryObservationV3)> {
    let value: serde_json::Value = serde_json::from_str(include_str!(
        "../../../contracts/r10aa_retained_support_observations_v2.json"
    ))
    .unwrap();
    let descriptor: BoundedQuadrupedDescriptor =
        serde_json::from_value(value["descriptor"].clone()).unwrap();
    value["observations"]
        .as_array()
        .unwrap()
        .iter()
        .map(|o| {
            (
                descriptor.clone(),
                serde_json::from_value(o.clone()).unwrap(),
            )
        })
        .collect()
}

fn set_load(o: &mut RecoveryObservationV3, load: f64) {
    for i in 0..4 {
        o.state.ordered_contact_observations[i].presence = Some(true);
        o.state.ordered_contact_observations[i].bears_support = Some(true);
        o.ordered_foot_bearing_observations[i].ordinary_unilateral_contact = true;
        o.ordered_foot_bearing_observations[i].bearing_normal_impulse_ns = load;
    }
}

fn bounded(o: &RecoveryObservationV3, p: &LoadSeekingPlan) {
    for (i, t) in p.ordered_target_positions_rad.iter().enumerate() {
        assert!(t.is_finite() && t.abs() <= if i % 2 == 0 { 1.6 } else { 1.1 });
        assert!(
            (t - o.state.ordered_joint_observations[i].position_rad.unwrap()).abs()
                <= 4.0 / 120.0 + 1e-12
        );
    }
    assert!(
        !p.native_source_validation_performed
            && !p.physical_acceptance_authority
            && !p.release_authority
    );
    assert_eq!((p.world_build_count, p.solver_step_count), (0, 0));
}

#[test]
fn r10aa_all_244_exposed_inputs_are_deterministic_bounded_and_unchanged() {
    let mut inputs = entries();
    inputs.extend(retained());
    assert_eq!(inputs.len(), 244);
    let mut active = 0;
    let mut held = 0;
    let mut lowered = 0;
    for (d, o) in inputs {
        let before = serde_json::to_value(&o).unwrap();
        let p = reference(&d, &o, RecoveryPhaseV1::EstablishDistalSupport).unwrap();
        assert_eq!(
            p,
            reference(&d, &o, RecoveryPhaseV1::EstablishDistalSupport).unwrap()
        );
        assert_eq!(before, serde_json::to_value(&o).unwrap());
        bounded(&o, &p);
        assert!(p.virtual_translation_world_m[1] <= 0.0);
        if p.selected_scale.is_some() {
            active += 1;
        } else {
            held += 1;
        }
        if p.virtual_translation_world_m[1] < 0.0 {
            lowered += 1;
        }
        assert!(p.rise_geometry.is_none());
    }
    println!(
        "R10AA_EXPOSED_INPUTS {}",
        json!({"inputs":244,"active":active,"held":held,"virtual_body_lowering":lowered})
    );
    assert!(active > 0);
}

#[test]
fn r10aa_weak_foot_endpoints_descend_and_loaded_endpoints_remain_fixed_in_model() {
    let mut checked = 0;
    for (d, o) in retained() {
        let plan = reference(&d, &o, RecoveryPhaseV1::EstablishDistalSupport).unwrap();
        let Some(scale) = plan.selected_scale else {
            continue;
        };
        let g = Geometry {
            upper: 0.35 * d.upper_length_fraction,
            lower: 0.35 * (1.0 - d.upper_length_fraction),
            span: d.hip_span_scale,
        };
        let measured =
            std::array::from_fn(|i| o.state.ordered_joint_observations[i].position_rad.unwrap());
        let q = o.state.base_pose_world.orientation_xyzw;
        let p = vec(o.state.base_pose_world.position_m);
        let f = rotate(q, [1.0, 0.0, 0.0]);
        let yaw = (-f[2]).atan2(f[0]);
        let rotation = blend(
            q,
            Quaternion {
                x: 0.0,
                y: (yaw / 2.0).sin(),
                z: 0.0,
                w: (yaw / 2.0).cos(),
            },
            plan.virtual_level_blend,
        );
        for i in 0..4 {
            let mut expected = add(p, rotate(q, g.foot(i, &measured)));
            expected[1] -= 0.1 / 120.0 * scale * plan.load_deficit_fraction[i];
            let actual = add(
                add(p, plan.virtual_translation_world_m),
                rotate(rotation, g.foot(i, &plan.ordered_target_positions_rad)),
            );
            let error = sub(actual, expected)
                .map(|v| v * v)
                .iter()
                .sum::<f64>()
                .sqrt();
            assert!(error <= 0.0005 + 1e-12);
            if plan.load_deficit_fraction[i] > 1e-6 {
                let original = add(p, rotate(q, g.foot(i, &measured)));
                assert!(actual[1] < original[1], "step {} limb {i}", o.semantic_step);
            }
        }
        checked += 1;
    }
    println!("R10AA_ENDPOINT_CHECKS {checked}");
    assert!(checked > 0);
}

#[test]
fn r10aa_below_plane_and_missing_reference_do_not_disable_load_seeking() {
    let (d, mut o) = retained().remove(0);
    set_load(&mut o, 0.0);
    let old = super::super::partial_pose_geometry_control::reference(&d, &o).unwrap();
    assert_eq!(old.hold_reason.as_deref(), Some("no_bearing_reference"));
    let p = reference(&d, &o, RecoveryPhaseV1::EstablishDistalSupport).unwrap();
    assert_eq!(p.load_deficit_fraction, [1.0; 4]);
    assert_eq!(p.candidate_count, 60);
    assert!(p.selected_scale.is_some());
    bounded(&o, &p);
}

#[test]
fn r10aa_phase_and_load_jointly_gate_rise_without_resetting_task_state() {
    let (d, mut o) = entries().remove(2);
    set_load(&mut o, LOAD_THRESHOLD);
    let support = reference(&d, &o, RecoveryPhaseV1::EstablishDistalSupport).unwrap();
    assert_eq!(support.mode, "hold_qualified_support");
    assert!(support.rise_geometry.is_none());
    let rise = reference(&d, &o, RecoveryPhaseV1::RaiseBody).unwrap();
    assert_eq!(rise.mode, "loaded_geometry_rise");
    assert!(rise.rise_geometry.is_some());
    o.ordered_foot_bearing_observations[1].bearing_normal_impulse_ns = LOAD_THRESHOLD * 0.5;
    let lost = reference(&d, &o, RecoveryPhaseV1::RaiseBody).unwrap();
    assert_eq!(lost.mode, "seek_distal_load");
    assert!(lost.rise_geometry.is_none());
    assert_eq!(lost.load_deficit_fraction, [0.0, 0.5, 0.0, 0.0]);
    assert!(lost.virtual_translation_world_m[1] <= 0.0);
}

#[test]
fn r10aa_native_flags_cannot_be_replaced_by_impulse_alone() {
    let (d, mut o) = entries().remove(2);
    set_load(&mut o, LOAD_THRESHOLD * 2.0);
    o.state.ordered_contact_observations[0].presence = Some(false);
    o.state.ordered_contact_observations[1].bears_support = Some(false);
    o.ordered_foot_bearing_observations[2].ordinary_unilateral_contact = false;
    let p = reference(&d, &o, RecoveryPhaseV1::RaiseBody).unwrap();
    assert_eq!(p.qualified_support, [false, false, false, true]);
    assert_eq!(p.load_deficit_fraction, [1.0, 1.0, 1.0, 0.0]);
    assert_eq!(p.mode, "seek_distal_load");
}

#[test]
fn r10aa_crossed_nonfinite_and_missing_inputs_are_refused() {
    let (d, o) = entries().remove(0);
    for case in 0..7 {
        let mut bad = o.clone();
        match case {
            0 => bad.outer_step_duration_s *= 2.0,
            1 => bad.semantic_step += 1,
            2 => bad.state.ordered_joint_observations[0].position_rad = None,
            3 => bad.state.ordered_joint_observations[0].position_rad = Some(f64::NAN),
            4 => bad.ordered_foot_bearing_observations[0].source_measurement = false,
            5 => bad.state.ordered_contact_observations[0].contact_site_id = "crossed".to_owned(),
            _ => bad.center_of_mass.source_measurement = false,
        }
        assert!(
            reference(&d, &bad, RecoveryPhaseV1::EstablishDistalSupport).is_err(),
            "case {case}"
        );
    }
    for phase in [
        RecoveryPhaseV1::StanceHandoff,
        RecoveryPhaseV1::Complete,
        RecoveryPhaseV1::Failed,
    ] {
        assert!(reference(&d, &o, phase).is_err());
    }
}

#[test]
fn r10aa_quaternion_sign_and_translation_preserve_targets() {
    let (d, o) = entries().remove(0);
    let baseline = reference(&d, &o, RecoveryPhaseV1::EstablishDistalSupport).unwrap();
    let mut changed = o.clone();
    let q = &mut changed.state.base_pose_world.orientation_xyzw;
    q.x = -q.x;
    q.y = -q.y;
    q.z = -q.z;
    q.w = -q.w;
    changed.state.base_pose_world.position_m.x += 3.0;
    changed.center_of_mass.position_world_m.x += 3.0;
    changed.state.base_pose_world.position_m.y += 2.0;
    changed.center_of_mass.position_world_m.y += 2.0;
    let p = reference(&d, &changed, RecoveryPhaseV1::EstablishDistalSupport).unwrap();
    for (a, b) in p
        .ordered_target_positions_rad
        .iter()
        .zip(baseline.ordered_target_positions_rad)
    {
        assert!((a - b).abs() < 1e-10);
    }
}

#[test]
fn r10aa_original_joint_overshoot_is_preserved_and_hold_returns_inside_limits() {
    let (d, mut o) = entries().remove(2);
    set_load(&mut o, LOAD_THRESHOLD);
    o.state.ordered_joint_observations[0].position_rad = Some(1.61);
    let p = reference(&d, &o, RecoveryPhaseV1::EstablishDistalSupport).unwrap();
    assert_eq!(p.ordered_target_positions_rad[0], 1.6);
    assert_eq!(
        o.state.ordered_joint_observations[0].position_rad,
        Some(1.61)
    );
    bounded(&o, &p);
    o.state.ordered_joint_observations[0].position_rad = Some(1.64);
    assert!(reference(&d, &o, RecoveryPhaseV1::EstablishDistalSupport).is_err());
}

#[test]
fn r10aa_singular_heading_and_unreachable_ik_do_not_fabricate_motion() {
    let (d, mut o) = entries().remove(2);
    set_load(&mut o, 0.0);
    let a = std::f64::consts::PI / 4.0;
    o.state.base_pose_world.orientation_xyzw = Quaternion {
        x: 0.0,
        y: 0.0,
        z: a.sin(),
        w: a.cos(),
    };
    let p = reference(&d, &o, RecoveryPhaseV1::EstablishDistalSupport).unwrap();
    assert_eq!(
        p.hold_reason.as_deref(),
        Some("undefined_horizontal_heading")
    );
    assert!(p.selected_scale.is_none());
    bounded(&o, &p);
    let g = Geometry {
        upper: 0.35 * d.upper_length_fraction,
        lower: 0.35 * (1.0 - d.upper_length_fraction),
        span: d.hip_span_scale,
    };
    let zero = [0.0; 8];
    let feet = std::array::from_fn(|i| g.foot(i, &zero));
    assert!(
        g.solve(&feet, [0.0, 0.01, 0.0], Quaternion::IDENTITY, &zero)
            .is_none()
    );
}
