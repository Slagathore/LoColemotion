use super::*;
use sha2::{Digest, Sha256};

fn fixtures() -> (BoundedQuadrupedDescriptor, Vec<serde_json::Value>) {
    let binding: serde_json::Value = serde_json::from_str(include_str!(
        "../../../contracts/r10aj_retained_canonical_geometry_input_binding_v1.json"
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
    let value: serde_json::Value = serde_json::from_slice(&raw).unwrap();
    assert_eq!(value["source_report"], binding["source_report"]);
    assert_eq!(value["terminal_inputs"], 0);
    let rows = value["observations"].as_array().unwrap().clone();
    assert_eq!(rows.len(), 600);
    (
        serde_json::from_value(value["descriptor"].clone()).unwrap(),
        rows,
    )
}

fn observation(row: &serde_json::Value) -> RecoveryObservationV3 {
    serde_json::from_value(row["observation"].clone()).unwrap()
}

#[test]
fn r10aj_all_retained_inputs_match_independent_model_and_preserve_sources() {
    let (d, rows) = fixtures();
    let mut changed = 0;
    let mut preserved = 0;
    for row in rows {
        let o = observation(&row);
        let before = serde_json::to_value(&o).unwrap();
        let plan = reference(&d, &o, RecoveryPhaseV1::RaiseBody).unwrap();
        assert_eq!(plan, reference(&d, &o, RecoveryPhaseV1::RaiseBody).unwrap());
        assert_eq!(before, serde_json::to_value(&o).unwrap());
        let expected = if plan.qualified_support.into_iter().all(|v| v) {
            preserved += 1;
            assert_eq!(plan.mode, "unchanged_v25_reference");
            row["original_plan"]["ordered_target_positions_rad"]
                .as_array()
                .unwrap()
        } else {
            changed += 1;
            assert_eq!(plan.mode, "weak_support_hip_recenter");
            row["expected_hip_recenter"]["targets"].as_array().unwrap()
        };
        for (i, target) in plan.ordered_target_positions_rad.iter().enumerate() {
            assert!((target - expected[i].as_f64().unwrap()).abs() < 1e-10);
            assert!(target.abs() <= if i % 2 == 0 { 1.6 } else { 1.1 });
            assert!(
                (target - o.state.ordered_joint_observations[i].position_rad.unwrap()).abs()
                    <= 4. / 120. + 1e-12
            );
        }
        assert!(
            !plan.native_source_validation_performed
                && !plan.physical_acceptance_authority
                && !plan.release_authority
        );
        assert_eq!((plan.world_build_count, plan.solver_step_count), (0, 0));
        println!(
            "R10AJ_GEOMETRY_FIXTURE {}",
            json!({"semantic_step":o.semantic_step,"mode":plan.mode,
            "targets":plan.ordered_target_positions_rad,"source_sha256":plan.source_observation_sha256})
        );
    }
    assert_eq!((changed, preserved), (599, 1));
}

#[test]
fn r10aj_support_establishment_is_exact_v25_reference() {
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
        assert!(plan.hip_recenter_geometry.is_none());
    }
}

#[test]
fn r10aj_invalid_phase_clock_descriptor_and_joint_source_refuse() {
    let (mut d, rows) = fixtures();
    let o = observation(&rows[1]);
    assert!(reference(&d, &o, RecoveryPhaseV1::Complete).is_err());
    let mut bad = o.clone();
    bad.outer_step_duration_s *= 2.;
    assert!(reference(&d, &bad, RecoveryPhaseV1::RaiseBody).is_err());
    let mut bad = o.clone();
    bad.state.ordered_joint_observations[0].position_rad = Some(f64::NAN);
    assert!(reference(&d, &bad, RecoveryPhaseV1::RaiseBody).is_err());
    d.hip_span_scale *= 1.01;
    assert!(reference(&d, &o, RecoveryPhaseV1::RaiseBody).is_err());
}

#[test]
fn r10aj_gravity_normal_to_plane_has_explicit_hold() {
    let (d, rows) = fixtures();
    let mut o = observation(&rows[1]);
    let a = std::f64::consts::FRAC_PI_4;
    o.state.base_pose_world.orientation_xyzw = Quaternion {
        x: a.sin(),
        y: 0.,
        z: 0.,
        w: a.cos(),
    };
    let result = recenter(&d, &o).unwrap();
    assert_eq!(
        result.hold_reason.as_deref(),
        Some("gravity_normal_to_joint_plane")
    );
    assert_eq!(result.desired_hip_angles_rad, [None; 4]);
}
