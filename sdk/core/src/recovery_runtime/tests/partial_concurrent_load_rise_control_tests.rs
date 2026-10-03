//! Compiled, retained-input mathematics; not native collection or task proof.
use super::*;
use sha2::{Digest, Sha256};

fn fixtures() -> (BoundedQuadrupedDescriptor, Vec<serde_json::Value>) {
    let binding: serde_json::Value = serde_json::from_str(include_str!(
        "../../../contracts/r10ai_retained_canonical_geometry_input_binding_v2.json"
    ))
    .unwrap();
    let raw = std::fs::read(binding["fixture"]["path"].as_str().unwrap()).unwrap();
    assert_eq!(
        format!("sha256:{:x}", Sha256::digest(&raw)),
        binding["fixture"]["raw_sha256"].as_str().unwrap()
    );
    assert_eq!(
        raw.len() as u64,
        binding["fixture"]["byte_length"].as_u64().unwrap()
    );
    let value: serde_json::Value = serde_json::from_slice(&raw).unwrap();
    assert_eq!(value["source_report"], binding["source_report"]);
    let rows = value["observations"].as_array().unwrap().clone();
    assert_eq!(rows.len(), 601);
    (
        serde_json::from_value(value["descriptor"].clone()).unwrap(),
        rows,
    )
}

fn observation(row: &serde_json::Value) -> RecoveryObservationV3 {
    serde_json::from_value(row["observation"].clone()).unwrap()
}

fn bounded(o: &RecoveryObservationV3, plan: &ConcurrentLoadRisePlan) {
    for (i, target) in plan.ordered_target_positions_rad.iter().enumerate() {
        assert!(target.is_finite());
        assert!(target.abs() <= if i % 2 == 0 { 1.6 } else { 1.1 });
        assert!(
            (target - o.state.ordered_joint_observations[i].position_rad.unwrap()).abs()
                <= 4.0 / 120.0 + 1e-12
        );
    }
    assert!(
        !plan.native_source_validation_performed
            && !plan.physical_acceptance_authority
            && !plan.release_authority
    );
    assert_eq!((plan.world_build_count, plan.solver_step_count), (0, 0));
}

#[test]
fn r10ai_all_601_retained_inputs_are_deterministic_bounded_and_immutable() {
    let (d, rows) = fixtures();
    let mut terminal = 0;
    for row in rows {
        let o = observation(&row);
        let before = serde_json::to_value(&o).unwrap();
        // The final failed-state input is explicitly counterfactual mathematics.
        // A native composition must never apply a command after task termination.
        let plan = reference(&d, &o, RecoveryPhaseV1::RaiseBody).unwrap();
        assert_eq!(plan, reference(&d, &o, RecoveryPhaseV1::RaiseBody).unwrap());
        assert_eq!(before, serde_json::to_value(&o).unwrap());
        bounded(&o, &plan);
        let is_terminal = row["source_next_phase"] == "failed";
        terminal += usize::from(is_terminal);
        println!(
            "R10AI_GEOMETRY_FIXTURE {}",
            json!({"semantic_step":o.semantic_step,
            "counterfactual_terminal_input":is_terminal,"plan":plan})
        );
    }
    assert_eq!(terminal, 1);
}

#[test]
fn r10ai_all_110_qualified_rise_plans_preserve_original_targets() {
    let (d, rows) = fixtures();
    let mut checked = 0;
    for row in rows {
        if row["original_load_plan"]["mode"] != "loaded_geometry_rise" {
            continue;
        }
        let o = observation(&row);
        let old = super::super::partial_load_seeking_control::reference(
            &d,
            &o,
            RecoveryPhaseV1::RaiseBody,
        )
        .unwrap();
        let plan = reference(&d, &o, RecoveryPhaseV1::RaiseBody).unwrap();
        assert_eq!(plan.qualified_support, [true; 4]);
        assert_eq!(
            plan.ordered_target_positions_rad,
            old.ordered_target_positions_rad
        );
        assert_eq!(
            plan.concurrent_geometry
                .as_ref()
                .unwrap()
                .load_deficit_fraction,
            [0.0; 4]
        );
        checked += 1;
    }
    assert_eq!(checked, 110);
}

#[test]
fn r10ai_support_establishment_is_exact_v23_for_all_retained_inputs() {
    let (d, rows) = fixtures();
    for row in rows {
        let o = observation(&row);
        let old = super::super::partial_load_seeking_control::reference(
            &d,
            &o,
            RecoveryPhaseV1::EstablishDistalSupport,
        )
        .unwrap();
        let plan = reference(&d, &o, RecoveryPhaseV1::EstablishDistalSupport).unwrap();
        assert_eq!(plan.baseline_reference, old);
        assert_eq!(
            plan.ordered_target_positions_rad,
            old.ordered_target_positions_rad
        );
        assert_eq!(plan.mode, "unchanged_support_reference");
        assert!(plan.concurrent_geometry.is_none());
        bounded(&o, &plan);
    }
}

#[test]
fn r10ai_weak_load_and_pose_progress_coexist_with_bounded_endpoint_error() {
    let (d, rows) = fixtures();
    let g = Geometry {
        upper: 0.35 * d.upper_length_fraction,
        lower: 0.35 * (1.0 - d.upper_length_fraction),
        radius: 0.04 * d.foot_radius_scale,
        span: d.hip_span_scale,
    };
    let mut combined = 0;
    for row in rows {
        let o = observation(&row);
        let plan = reference(&d, &o, RecoveryPhaseV1::RaiseBody).unwrap();
        if plan.mode != "concurrent_load_and_rise" || plan.qualified_support.iter().all(|b| *b) {
            continue;
        }
        let selected = plan.concurrent_geometry.unwrap();
        assert_eq!(selected.candidate_count, 135);
        assert!(selected.selected_model_cost.unwrap() < selected.initial_model_cost.unwrap());
        let joints =
            std::array::from_fn(|i| o.state.ordered_joint_observations[i].position_rad.unwrap());
        let p = vec(o.state.base_pose_world.position_m);
        let q = o.state.base_pose_world.orientation_xyzw;
        let forward = rotate(q, [1.0, 0.0, 0.0]);
        let yaw = (-forward[2]).atan2(forward[0]);
        let flat = Quaternion {
            x: 0.0,
            y: (yaw / 2.0).sin(),
            z: 0.0,
            w: (yaw / 2.0).cos(),
        };
        let rotation = blend(q, flat, selected.selected_virtual_level_blend);
        let position = add(p, selected.selected_virtual_translation_world_m);
        for i in 0..4 {
            let original = add(p, rotate(q, g.foot(i, &joints)));
            let mut expected = original;
            expected[1] -= 0.1 / 120.0
                * selected.selected_candidate_scale.unwrap()
                * selected.load_deficit_fraction[i];
            let actual = add(
                position,
                rotate(rotation, g.foot(i, &plan.ordered_target_positions_rad)),
            );
            let error = sub(actual, expected)
                .map(|x| x * x)
                .iter()
                .sum::<f64>()
                .sqrt();
            assert!(error <= 0.0005 + 1e-12);
            // The declared target, not an actual contact-force assertion.
            if !plan.qualified_support[i] {
                assert!(expected[1] < original[1]);
            }
        }
        combined += 1;
    }
    assert!(combined > 0);
    println!("R10AI_WEAK_CONCURRENT_COUNT {combined}");
}

#[test]
fn r10ai_missing_reference_has_explicit_exact_fallback() {
    let (d, rows) = fixtures();
    let mut o = observation(&rows[0]);
    for i in 0..4 {
        o.state.ordered_contact_observations[i].presence = Some(false);
        o.state.ordered_contact_observations[i].bears_support = Some(false);
        o.ordered_foot_bearing_observations[i].ordinary_unilateral_contact = false;
        o.ordered_foot_bearing_observations[i].bearing_normal_impulse_ns = 0.0;
    }
    let old =
        super::super::partial_load_seeking_control::reference(&d, &o, RecoveryPhaseV1::RaiseBody)
            .unwrap();
    let plan = reference(&d, &o, RecoveryPhaseV1::RaiseBody).unwrap();
    assert_eq!(plan.mode, "explicit_v23_fallback");
    assert_eq!(
        plan.ordered_target_positions_rad,
        old.ordered_target_positions_rad
    );
    assert_eq!(plan.baseline_reference, old);
    assert_eq!(
        plan.concurrent_geometry.unwrap().hold_reason.as_deref(),
        Some("no_bearing_reference")
    );
}

#[test]
fn r10ai_invalid_phase_clock_descriptor_and_nonfinite_sources_refuse() {
    let (d, rows) = fixtures();
    let o = observation(&rows[0]);
    assert!(reference(&d, &o, RecoveryPhaseV1::Failed).is_err());
    let mut bad = o.clone();
    bad.semantic_step += 1;
    assert!(reference(&d, &bad, RecoveryPhaseV1::RaiseBody).is_err());
    let mut bad = o.clone();
    bad.state.ordered_joint_observations[0].position_rad = Some(f64::NAN);
    assert!(reference(&d, &bad, RecoveryPhaseV1::RaiseBody).is_err());
    let mut bad = o.clone();
    bad.center_of_mass.source_measurement = false;
    assert!(reference(&d, &bad, RecoveryPhaseV1::RaiseBody).is_err());
    let mut bad = o.clone();
    bad.state.ordered_contact_observations[0].presence = None;
    assert!(reference(&d, &bad, RecoveryPhaseV1::RaiseBody).is_err());
    let mut bad = o.clone();
    bad.ordered_foot_bearing_observations[0].bearing_normal_impulse_ns = f64::INFINITY;
    assert!(reference(&d, &bad, RecoveryPhaseV1::RaiseBody).is_err());
    let mut bad = d.clone();
    bad.hip_span_scale += 0.01;
    assert!(reference(&bad, &o, RecoveryPhaseV1::RaiseBody).is_err());
}
