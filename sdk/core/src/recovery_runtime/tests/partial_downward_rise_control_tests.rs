//! Exposed-input model parity is not native admission or physical evidence.
use super::*;

fn retained() -> (BoundedQuadrupedDescriptor, Vec<serde_json::Value>) {
    let value: serde_json::Value = serde_json::from_str(include_str!(
        "../../../contracts/r10ab_retained_partial_observations_v1.json"
    ))
    .unwrap();
    (
        serde_json::from_value(value["descriptor"].clone()).unwrap(),
        value["entries"].as_array().unwrap().clone(),
    )
}

fn observation(row: &serde_json::Value) -> RecoveryObservationV3 {
    serde_json::from_value(row["observation"].clone()).unwrap()
}

fn loaded() -> (BoundedQuadrupedDescriptor, RecoveryObservationV3) {
    let (d, rows) = retained();
    let row = rows
        .iter()
        .find(|r| r["original_mode"] == "loaded_geometry_rise")
        .unwrap();
    (d, observation(row))
}

fn bounded(o: &RecoveryObservationV3, targets: &[f64; 8]) {
    for (i, target) in targets.iter().enumerate() {
        assert!(target.is_finite() && target.abs() <= if i % 2 == 0 { 1.6 } else { 1.1 });
        assert!(
            (target - o.state.ordered_joint_observations[i].position_rad.unwrap()).abs()
                <= 4.0 / 120.0 + 1e-12
        );
    }
}

fn downward(d: &BoundedQuadrupedDescriptor, o: &RecoveryObservationV3, plan: &GeometryPlan) {
    let dy = plan.selected_virtual_translation_world_m[1];
    assert!(dy > 0.0);
    let measured =
        std::array::from_fn(|i| o.state.ordered_joint_observations[i].position_rad.unwrap());
    // Independently evaluate each endpoint using the scalar two-link formula,
    // then the measured rotation's world-y row (not the search's virtual pose).
    let q = o.state.base_pose_world.orientation_xyzw;
    let world_y = |i: usize, joints: &[f64; 8]| {
        let h = joints[2 * i];
        let k = joints[2 * i + 1];
        let upper = 0.35 * d.upper_length_fraction;
        let lower = 0.35 * (1.0 - d.upper_length_fraction);
        let x = upper * h.sin() + lower * (h + k).sin();
        let y = -upper * h.cos() - lower * (h + k).cos();
        2.0 * (q.x * q.y + q.z * q.w) * x + (1.0 - 2.0 * (q.x * q.x + q.z * q.z)) * y
    };
    let recorded = plan.selected_fixed_torso_foot_delta_y_m.unwrap();
    for i in 0..4 {
        let actual = world_y(i, &plan.ordered_target_positions_rad) - world_y(i, &measured);
        assert!(actual <= -0.25 * dy + 1e-12);
        assert!((actual - recorded[i]).abs() < 1e-12);
    }
    bounded(o, &plan.ordered_target_positions_rad);
    assert!(plan.maximum_unactuated_lateral_residual_m <= 0.0005);
    assert!(plan.selected_model_cost.unwrap() < plan.initial_model_cost.unwrap() - 1e-12);
    assert!(
        !plan.native_source_validation_performed
            && !plan.physical_acceptance_authority
            && !plan.release_authority
    );
    assert_eq!((plan.world_build_count, plan.solver_step_count), (0, 0));
}

#[test]
fn r10ab_all_646_model_probes_match_retained_offline_counterfactuals() {
    let (d, rows) = retained();
    assert_eq!(rows.len(), 646);
    for row in rows {
        let o = observation(&row);
        let before = serde_json::to_value(&o).unwrap();
        let p = downward_geometry(&d, &o).unwrap();
        assert_eq!(p, downward_geometry(&d, &o).unwrap());
        assert_eq!(before, serde_json::to_value(&o).unwrap());
        assert_eq!(p.candidate_count, 135);
        assert!(
            p.downward_feasible_candidate_count > 0
                && p.downward_feasible_candidate_count <= p.feasible_candidate_count
        );
        assert!(p.hold_reason.is_none());
        let e = &row["expected"];
        assert_eq!(
            p.selected_candidate_scale.unwrap(),
            e["scale"].as_f64().unwrap()
        );
        assert_eq!(p.selected_virtual_level_blend, e["blend"].as_f64().unwrap());
        assert!((p.selected_model_cost.unwrap() - e["cost"].as_f64().unwrap()).abs() < 1e-12);
        for i in 0..8 {
            assert!(
                (p.ordered_target_positions_rad[i] - e["targets"][i].as_f64().unwrap()).abs()
                    < 1e-10
            );
        }
        for i in 0..3 {
            assert!(
                (p.selected_virtual_translation_world_m[i] - e["translation"][i].as_f64().unwrap())
                    .abs()
                    < 1e-12
            );
        }
        downward(&d, &o, &p);
    }
    println!("R10AB_COUNTERFACTUAL_PARITY 646");
}

#[test]
fn r10ab_44_loaded_states_use_new_constraint_without_mutation_or_authority() {
    let (d, rows) = retained();
    let mut count = 0;
    for row in rows
        .iter()
        .filter(|r| r["original_mode"] == "loaded_geometry_rise")
    {
        let o = observation(row);
        let before = serde_json::to_value(&o).unwrap();
        let p = reference(&d, &o, RecoveryPhaseV1::RaiseBody).unwrap();
        assert_eq!(p, reference(&d, &o, RecoveryPhaseV1::RaiseBody).unwrap());
        assert_eq!(before, serde_json::to_value(&o).unwrap());
        assert_eq!(p.mode, "loaded_downward_rise");
        assert_eq!(p.qualified_support, [true; 4]);
        assert_eq!(
            p.source_observation_sha256,
            digest_serializable(&o).unwrap()
        );
        assert!(
            !p.native_source_validation_performed
                && !p.physical_acceptance_authority
                && !p.release_authority
        );
        assert_eq!((p.world_build_count, p.solver_step_count), (0, 0));
        downward(&d, &o, p.rise_geometry.as_ref().unwrap());
        count += 1;
    }
    assert_eq!(count, 44);
    println!("R10AB_LOADED_ADMISSION 44");
}

#[test]
fn r10ab_support_and_weak_raise_are_exact_predecessor_results() {
    let (d, rows) = retained();
    let mut counts = [0; 2];
    for row in rows {
        let o = observation(&row);
        for (index, phase) in [
            RecoveryPhaseV1::EstablishDistalSupport,
            RecoveryPhaseV1::RaiseBody,
        ]
        .into_iter()
        .enumerate()
        {
            let old = super::super::partial_load_seeking_control::reference(&d, &o, phase).unwrap();
            if index == 1 && old.qualified_support.into_iter().all(|b| b) {
                continue;
            }
            let new = reference(&d, &o, phase).unwrap();
            let mut expected = serde_json::to_value(old).unwrap();
            expected["schema_version"] = json!("sporespore_r10ab_downward_rise_plan_v1");
            assert_eq!(serde_json::to_value(new).unwrap(), expected);
            counts[index] += 1;
        }
    }
    assert_eq!(counts, [646, 602]);
    println!("R10AB_UNCHANGED_PHASE_PARITY 646 602");
}

#[test]
fn r10ab_every_native_qualification_condition_controls_loaded_admission() {
    let (d, original) = loaded();
    for i in 0..4 {
        for kind in 0..4 {
            let mut o = original.clone();
            match kind {
                0 => o.state.ordered_contact_observations[i].presence = Some(false),
                1 => o.state.ordered_contact_observations[i].bears_support = Some(false),
                2 => o.ordered_foot_bearing_observations[i].ordinary_unilateral_contact = false,
                _ => {
                    o.ordered_foot_bearing_observations[i].bearing_normal_impulse_ns =
                        0.019293 - 1e-10
                }
            }
            let p = reference(&d, &o, RecoveryPhaseV1::RaiseBody).unwrap();
            assert_eq!(p.mode, "seek_distal_load");
            assert!(!p.qualified_support[i] && p.rise_geometry.is_none());
        }
    }
    let mut exact = original;
    for b in &mut exact.ordered_foot_bearing_observations {
        b.bearing_normal_impulse_ns = 0.019293;
    }
    assert_eq!(
        reference(&d, &exact, RecoveryPhaseV1::RaiseBody)
            .unwrap()
            .mode,
        "loaded_downward_rise"
    );
}

#[test]
fn r10ab_invalid_inputs_and_nonpartial_phases_refuse() {
    let (d, original) = loaded();
    for phase in [
        RecoveryPhaseV1::StanceHandoff,
        RecoveryPhaseV1::Complete,
        RecoveryPhaseV1::Failed,
    ] {
        assert!(reference(&d, &original, phase).is_err());
    }
    for kind in 0..10 {
        let mut o = original.clone();
        match kind {
            0 => o.state.ordered_joint_observations[0].position_rad = None,
            1 => o.state.ordered_joint_observations[0].position_rad = Some(f64::NAN),
            2 => o.state.ordered_contact_observations[0].presence = None,
            3 => o.ordered_foot_bearing_observations[0].bearing_normal_impulse_ns = f64::INFINITY,
            4 => o.ordered_foot_bearing_observations[0].source_measurement = false,
            5 => o.semantic_step += 1,
            6 => o.outer_step_duration_s *= 2.0,
            7 => o.center_of_mass.position_world_m.x = f64::NAN,
            8 => o.state.ordered_joint_observations[0].joint_id = "crossed".to_owned(),
            _ => o.state.ordered_contact_observations[0].contact_site_id = "crossed".to_owned(),
        }
        assert!(
            reference(&d, &o, RecoveryPhaseV1::RaiseBody).is_err(),
            "kind={kind}"
        );
    }
    let mut wrong = d;
    wrong.hip_span_scale += 0.001;
    assert!(reference(&wrong, &original, RecoveryPhaseV1::RaiseBody).is_err());
}

#[test]
fn r10ab_no_admissible_rise_is_explicit_bounded_hold() {
    let (d, mut o) = loaded();
    o.state.base_pose_world.orientation_xyzw = Quaternion {
        x: 0.0,
        y: 0.0,
        z: 0.0,
        w: 1.0,
    };
    for j in &mut o.state.ordered_joint_observations {
        j.position_rad = Some(0.0);
    }
    let before = serde_json::to_value(&o).unwrap();
    let p = reference(&d, &o, RecoveryPhaseV1::RaiseBody).unwrap();
    assert_eq!(
        p.hold_reason.as_deref(),
        Some("no_feasible_downward_cost_decreasing_candidate")
    );
    assert_eq!(p.ordered_target_positions_rad, [0.0; 8]);
    assert_eq!(p.virtual_translation_world_m, [0.0; 3]);
    assert_eq!(p.candidate_count, 135);
    assert!(p.selected_scale.is_none());
    assert!(
        p.rise_geometry
            .unwrap()
            .selected_fixed_torso_foot_delta_y_m
            .is_none()
    );
    assert_eq!(before, serde_json::to_value(&o).unwrap());
}

#[test]
fn r10ab_quaternion_sign_and_world_translation_preserve_targets() {
    let (d, o) = loaded();
    let original = reference(&d, &o, RecoveryPhaseV1::RaiseBody).unwrap();
    let mut moved = o.clone();
    let q = &mut moved.state.base_pose_world.orientation_xyzw;
    q.x = -q.x;
    q.y = -q.y;
    q.z = -q.z;
    q.w = -q.w;
    moved.state.base_pose_world.position_m.x += 2.0;
    moved.state.base_pose_world.position_m.y += 1.0;
    moved.state.base_pose_world.position_m.z -= 3.0;
    moved.center_of_mass.position_world_m.x += 2.0;
    moved.center_of_mass.position_world_m.y += 1.0;
    moved.center_of_mass.position_world_m.z -= 3.0;
    let p = reference(&d, &moved, RecoveryPhaseV1::RaiseBody).unwrap();
    assert_eq!(p.selected_scale, original.selected_scale);
    for i in 0..8 {
        assert!(
            (p.ordered_target_positions_rad[i] - original.ordered_target_positions_rad[i]).abs()
                < 1e-10
        );
    }
    downward(&d, &moved, p.rise_geometry.as_ref().unwrap());
}

#[test]
fn r10ab_measured_overshoot_is_preserved_and_singular_heading_holds() {
    let (d, mut o) = loaded();
    o.state.ordered_joint_observations[0].position_rad = Some(1.61);
    let before = serde_json::to_value(&o).unwrap();
    let p = reference(&d, &o, RecoveryPhaseV1::RaiseBody).unwrap();
    bounded(&o, &p.ordered_target_positions_rad);
    assert_eq!(before, serde_json::to_value(&o).unwrap());
    assert_eq!(
        p.rise_geometry
            .unwrap()
            .measured_joint_boundary_return_count,
        1
    );
    o.state.ordered_joint_observations[0].position_rad = Some(1.64);
    assert!(reference(&d, &o, RecoveryPhaseV1::RaiseBody).is_err());
    o.state.ordered_joint_observations[0].position_rad = Some(1.0);
    o.state.base_pose_world.orientation_xyzw = Quaternion {
        x: 0.0,
        y: 0.0,
        z: std::f64::consts::FRAC_1_SQRT_2,
        w: std::f64::consts::FRAC_1_SQRT_2,
    };
    let p = reference(&d, &o, RecoveryPhaseV1::RaiseBody).unwrap();
    assert_eq!(
        p.hold_reason.as_deref(),
        Some("undefined_horizontal_heading")
    );
    assert_eq!(p.candidate_count, 0);
    bounded(&o, &p.ordered_target_positions_rad);
}
