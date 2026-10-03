use super::*;
use sha2::{Digest, Sha256};

fn fixtures() -> (BoundedQuadrupedDescriptor, Vec<serde_json::Value>) {
    let binding: serde_json::Value = serde_json::from_str(include_str!(
        "../../../contracts/r10am_retained_canonical_geometry_input_binding_v1.json"
    ))
    .unwrap();
    let raw = std::fs::read(binding["fixture"]["path"].as_str().unwrap()).unwrap();
    assert_eq!(
        format!("sha256:{:x}", Sha256::digest(&raw)),
        binding["fixture"]["raw_sha256"]
    );
    assert_eq!(
        raw.len() as u64,
        binding["fixture"]["byte_length"].as_u64().unwrap()
    );
    let v: serde_json::Value = serde_json::from_slice(&raw).unwrap();
    assert_eq!(v["source_report"], binding["source_report"]);
    let rows = v["observations"].as_array().unwrap().clone();
    assert_eq!(rows.len(), 600);
    (
        serde_json::from_value(v["descriptor"].clone()).unwrap(),
        rows,
    )
}
fn observation(row: &serde_json::Value) -> RecoveryObservationV3 {
    serde_json::from_value(row["observation"].clone()).unwrap()
}

#[test]
fn r10am_all_canonical_inputs_match_independent_geometry_and_preserve_sources() {
    let (d, rows) = fixtures();
    let mut selected = 0;
    let mut fallback = 0;
    for row in rows {
        let o = observation(&row);
        let before = serde_json::to_value(&o).unwrap();
        let plan = reference(&d, &o, RecoveryPhaseV1::RaiseBody).unwrap();
        assert_eq!(plan, reference(&d, &o, RecoveryPhaseV1::RaiseBody).unwrap());
        assert_eq!(before, serde_json::to_value(&o).unwrap());
        assert_eq!(
            plan.source_observation_sha256,
            row["original_plan"]["source_observation_sha256"]
        );
        let g = plan.support_anchored_geometry.as_ref().unwrap();
        let expected = &row["expected"];
        assert_eq!(
            g.candidate_count as u64,
            expected["candidates"].as_u64().unwrap()
        );
        assert_eq!(
            g.feasible_candidate_count as u64,
            expected["feasible"].as_u64().unwrap()
        );
        let targets = if expected["selected"].is_null() {
            fallback += 1;
            assert_eq!(plan.mode, "explicit_v23_fallback");
            assert_eq!(g.hold_reason.as_deref(), expected["refusal"].as_str());
            assert_eq!(
                plan.ordered_target_positions_rad,
                plan.baseline_reference
                    .baseline_reference
                    .ordered_target_positions_rad
            );
            row["original_plan"]["baseline_reference"]["baseline_reference"]
                ["ordered_target_positions_rad"]
                .as_array()
                .unwrap()
        } else {
            selected += 1;
            assert_eq!(plan.mode, "support_anchored_leveling");
            let e = &expected["selected"];
            assert_eq!(g.selected_scale, e["scale"].as_f64());
            assert_eq!(g.virtual_level_blend, e["blend"].as_f64().unwrap());
            assert!((g.selected_cost.unwrap() - e["cost"].as_f64().unwrap()).abs() < 1e-12);
            assert!(g.maximum_anchor_error_m <= LATERAL + 1e-12);
            e["targets"].as_array().unwrap()
        };
        for (i, target) in plan.ordered_target_positions_rad.iter().enumerate() {
            assert!(
                (target - targets[i].as_f64().unwrap()).abs() < 1e-10,
                "step {} joint {}",
                o.semantic_step,
                i
            );
            assert!(target.abs() <= if i % 2 == 0 { 1.6 } else { 1.1 });
            assert!(
                (target - o.state.ordered_joint_observations[i].position_rad.unwrap()).abs()
                    <= 4.0 * DT + 1e-12
            );
        }
        assert!(
            !plan.native_source_validation_performed
                && !plan.physical_acceptance_authority
                && !plan.release_authority
        );
        assert_eq!((plan.world_build_count, plan.solver_step_count), (0, 0));
        println!(
            "R10AM_GEOMETRY_FIXTURE {}",
            json!({"semantic_step":o.semantic_step,"mode":plan.mode,"targets":plan.ordered_target_positions_rad,
            "source_sha256":plan.source_observation_sha256,"geometry":g})
        );
    }
    assert_eq!((selected, fallback), (585, 15));
}

#[test]
fn r10am_establish_support_preserves_exact_v25_reference() {
    let (d, rows) = fixtures();
    for row in rows {
        let o = observation(&row);
        let old = super::super::partial_concurrent_load_rise_control::reference(
            &d,
            &o,
            RecoveryPhaseV1::EstablishDistalSupport,
        )
        .unwrap();
        let plan = reference(&d, &o, RecoveryPhaseV1::EstablishDistalSupport).unwrap();
        assert_eq!(
            plan.ordered_target_positions_rad,
            old.ordered_target_positions_rad
        );
        assert_eq!(plan.baseline_reference, old);
        assert!(plan.support_anchored_geometry.is_none());
    }
}

#[test]
fn r10am_invalid_source_phase_clock_descriptor_and_contacts_refuse() {
    let (mut d, rows) = fixtures();
    let o = observation(&rows[1]);
    assert!(reference(&d, &o, RecoveryPhaseV1::Complete).is_err());
    let mut bad = o.clone();
    bad.outer_step_duration_s *= 2.0;
    assert!(reference(&d, &bad, RecoveryPhaseV1::RaiseBody).is_err());
    let mut bad = o.clone();
    bad.state.ordered_joint_observations[0].position_rad = Some(f64::NAN);
    assert!(reference(&d, &bad, RecoveryPhaseV1::RaiseBody).is_err());
    let mut bad = o.clone();
    bad.ordered_foot_bearing_observations[0].bearing_normal_impulse_ns = -1.0;
    assert!(reference(&d, &bad, RecoveryPhaseV1::RaiseBody).is_err());
    d.hip_span_scale *= 1.01;
    assert!(reference(&d, &o, RecoveryPhaseV1::RaiseBody).is_err());
}

#[test]
fn r10am_vertical_heading_has_explicit_v23_fallback() {
    let (d, rows) = fixtures();
    let mut o = observation(&rows[1]);
    let a = std::f64::consts::FRAC_PI_4;
    o.state.base_pose_world.orientation_xyzw = Quaternion {
        x: 0.0,
        y: 0.0,
        z: a.sin(),
        w: a.cos(),
    };
    let p = reference(&d, &o, RecoveryPhaseV1::RaiseBody).unwrap();
    assert_eq!(p.mode, "explicit_v23_fallback");
    assert_eq!(
        p.support_anchored_geometry.unwrap().hold_reason.as_deref(),
        Some("undefined_horizontal_heading")
    );
}
