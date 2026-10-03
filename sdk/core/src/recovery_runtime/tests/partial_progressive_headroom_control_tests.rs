use super::*;
use sha2::{Digest, Sha256};
use std::sync::OnceLock;

fn fixtures() -> &'static (BoundedQuadrupedDescriptor, Vec<serde_json::Value>) {
    static FIXTURES: OnceLock<(BoundedQuadrupedDescriptor, Vec<serde_json::Value>)> =
        OnceLock::new();
    FIXTURES.get_or_init(|| {
        let binding: serde_json::Value = serde_json::from_str(include_str!(
            "../../../contracts/r10ap_retained_canonical_geometry_input_binding_v1.json"
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
        assert_eq!(value["independent_result"], binding["independent_result"]);
        assert_eq!(value["source_form"], "original_v3_step_observation");
        assert_eq!(value["terminal_inputs"], 0);
        let rows = value["observations"].as_array().unwrap().clone();
        assert_eq!(rows.len(), 600);
        (
            serde_json::from_value(value["descriptor"].clone()).unwrap(),
            rows,
        )
    })
}

fn observation(row: &serde_json::Value) -> RecoveryObservationV3 {
    serde_json::from_value(row["observation"].clone()).unwrap()
}

fn close(actual: f64, expected: &serde_json::Value, tolerance: f64) {
    assert!(
        (actual - expected.as_f64().unwrap()).abs() < tolerance,
        "actual {actual}, expected {expected}, tolerance {tolerance}"
    );
}

#[test]
fn r10ap_all_inputs_match_independent_model_and_preserve_sources() {
    let (descriptor, rows) = fixtures();
    let (mut restore, mut raise, mut fallback, mut cost_increases) = (0, 0, 0, 0);
    for row in rows {
        let source = observation(row);
        let before = serde_json::to_value(&source).unwrap();
        let plan = reference(descriptor, &source, RecoveryPhaseV1::RaiseBody).unwrap();
        assert_eq!(
            plan,
            reference(descriptor, &source, RecoveryPhaseV1::RaiseBody).unwrap()
        );
        assert_eq!(serde_json::to_value(&source).unwrap(), before);
        assert_eq!(
            plan.source_observation_sha256,
            row["source_observation_sha256"]
        );
        let geometry = plan.progressive_headroom_geometry.as_ref().unwrap();
        let expected = &row["expected"];
        for (actual, name) in [
            (geometry.candidate_count, "candidates"),
            (geometry.feasible_candidate_count, "geometric"),
            (
                geometry.nonworsening_headroom_candidate_count,
                "nonworsening",
            ),
            (geometry.headroom_progress_candidate_count, "progress"),
        ] {
            assert_eq!(actual as u64, expected[name].as_u64().unwrap());
        }
        for (i, actual) in geometry.initial_deficits_rad.iter().enumerate() {
            close(*actual, &expected["deficits_before_rad"][i], 1e-12);
        }
        let expected_targets = if expected["selected"].is_null() {
            fallback += 1;
            assert_eq!(plan.mode, "explicit_v23_fallback");
            assert_eq!(
                geometry.hold_reason.as_deref(),
                expected["refusal"].as_str()
            );
            assert!(geometry.selected_scale.is_none() && geometry.selected_deficits_rad.is_none());
            assert_eq!(
                plan.ordered_target_positions_rad,
                plan.baseline_reference
                    .baseline_reference
                    .ordered_target_positions_rad
            );
            &row["v23_fallback_targets"]
        } else {
            let selected = &expected["selected"];
            assert_eq!(plan.mode, selected["mode"]);
            match plan.mode.as_str() {
                "recover_joint_headroom" => restore += 1,
                "raise_with_headroom" => raise += 1,
                _ => panic!("undeclared mode"),
            }
            assert!(geometry.hold_reason.is_none());
            assert_eq!(geometry.selected_scale, selected["scale"].as_f64());
            close(geometry.virtual_level_blend, &selected["blend"], 1e-12);
            close(
                geometry.initial_cost.unwrap(),
                &expected["initial_cost"],
                1e-12,
            );
            close(geometry.selected_cost.unwrap(), &selected["cost"], 1e-12);
            for i in 0..3 {
                close(
                    geometry.virtual_translation_world_m[i],
                    &selected["translation"][i],
                    1e-12,
                );
            }
            let after = geometry.selected_deficits_rad.unwrap();
            for i in 0..8 {
                close(
                    after[i],
                    &selected["verification"]["deficits_after_rad"][i],
                    1e-12,
                );
            }
            assert_eq!(
                headroom_allowed(geometry.initial_deficits_rad, after),
                (true, true)
            );
            assert!(rank_less(
                rank(after, geometry.selected_cost.unwrap()),
                rank(
                    geometry.initial_deficits_rad,
                    geometry.initial_cost.unwrap()
                )
            ));
            assert!(geometry.maximum_anchor_error_m <= LATERAL + EPS);
            assert!(geometry.virtual_translation_world_m[1] >= 0.0);
            assert_eq!(
                geometry.geometry_cost_increased,
                selected["verification"]["geometry_cost_change"]
                    .as_f64()
                    .unwrap()
                    > EPS
            );
            cost_increases += usize::from(geometry.geometry_cost_increased);
            &selected["targets"]
        };
        for (i, target) in plan.ordered_target_positions_rad.iter().enumerate() {
            close(*target, &expected_targets[i], 1e-10);
            assert!(target.abs() <= LIMITS[i]);
            assert!(
                (target
                    - source.state.ordered_joint_observations[i]
                        .position_rad
                        .unwrap())
                .abs()
                    <= 4.0 * DT + EPS
            );
        }
        assert!(
            !plan.native_source_validation_performed
                && !plan.physical_acceptance_authority
                && !plan.release_authority
        );
        assert_eq!((plan.world_build_count, plan.solver_step_count), (0, 0));
        println!(
            "R10AP_KERNEL_FIXTURE {}",
            json!({"semantic_step": source.semantic_step,
            "source_sha256": plan.source_observation_sha256, "mode": plan.mode,
            "targets": plan.ordered_target_positions_rad, "geometry": geometry})
        );
    }
    assert_eq!((restore, raise, fallback, cost_increases), (593, 4, 3, 492));
}

#[test]
fn r10ap_establish_support_preserves_all_v25_references() {
    let (descriptor, rows) = fixtures();
    for row in rows {
        let source = observation(row);
        let old = super::super::partial_concurrent_load_rise_control::reference(
            descriptor,
            &source,
            RecoveryPhaseV1::EstablishDistalSupport,
        )
        .unwrap();
        let plan = reference(descriptor, &source, RecoveryPhaseV1::EstablishDistalSupport).unwrap();
        assert_eq!(
            plan.ordered_target_positions_rad,
            old.ordered_target_positions_rad
        );
        assert_eq!(plan.baseline_reference, old);
        assert_eq!(plan.mode, "unchanged_support_reference");
        assert!(plan.progressive_headroom_geometry.is_none());
    }
}

#[test]
fn r10ap_invalid_admission_refuses_before_geometry() {
    let (descriptor, rows) = fixtures();
    let source = observation(&rows[0]);
    assert!(reference(descriptor, &source, RecoveryPhaseV1::Complete).is_err());
    let mut bad = source.clone();
    bad.outer_step_duration_s *= 2.0;
    assert!(reference(descriptor, &bad, RecoveryPhaseV1::RaiseBody).is_err());
    let mut bad = source.clone();
    bad.state.ordered_joint_observations[0].position_rad = Some(f64::NAN);
    assert!(reference(descriptor, &bad, RecoveryPhaseV1::RaiseBody).is_err());
    let mut bad = source.clone();
    bad.state.ordered_joint_observations[0].position_rad = None;
    assert!(reference(descriptor, &bad, RecoveryPhaseV1::RaiseBody).is_err());
    let mut bad = source.clone();
    bad.state.ordered_joint_observations.pop();
    assert!(reference(descriptor, &bad, RecoveryPhaseV1::RaiseBody).is_err());
    let mut bad = source.clone();
    bad.state.ordered_contact_observations.pop();
    assert!(reference(descriptor, &bad, RecoveryPhaseV1::RaiseBody).is_err());
    let mut bad = source.clone();
    bad.ordered_foot_bearing_observations[0].bearing_normal_impulse_ns = -1.0;
    assert!(reference(descriptor, &bad, RecoveryPhaseV1::RaiseBody).is_err());
    let mut bad = source.clone();
    bad.state.base_pose_world.orientation_xyzw.w = f64::NAN;
    assert!(reference(descriptor, &bad, RecoveryPhaseV1::RaiseBody).is_err());
    let mut wrong = descriptor.clone();
    wrong.hip_span_scale *= 1.01;
    assert!(reference(&wrong, &source, RecoveryPhaseV1::RaiseBody).is_err());
}

#[test]
fn r10ap_loss_of_bearing_uses_fresh_explicit_v23_reference() {
    let (descriptor, rows) = fixtures();
    let source = observation(&rows[0]);
    let previous = reference(descriptor, &source, RecoveryPhaseV1::RaiseBody).unwrap();
    let mut unloaded = source.clone();
    for contact in &mut unloaded.state.ordered_contact_observations {
        contact.presence = Some(false);
        contact.bears_support = Some(false);
    }
    for foot in &mut unloaded.ordered_foot_bearing_observations {
        foot.bearing_normal_impulse_ns = 0.0;
    }
    let plan = reference(descriptor, &unloaded, RecoveryPhaseV1::RaiseBody).unwrap();
    assert_eq!(plan.mode, "explicit_v23_fallback");
    assert_ne!(
        plan.source_observation_sha256,
        previous.source_observation_sha256
    );
    assert_eq!(
        plan.source_observation_sha256,
        digest_serializable(&unloaded).unwrap()
    );
    let geometry = plan.progressive_headroom_geometry.unwrap();
    assert_eq!(geometry.positive_bearing, [false; 4]);
    assert_eq!(
        geometry.hold_reason.as_deref(),
        Some("no_positive_bearing_plane")
    );
    assert_eq!(geometry.candidate_count, 0);
    assert!(geometry.selected_deficits_rad.is_none());
    assert_eq!(
        plan.ordered_target_positions_rad,
        plan.baseline_reference
            .baseline_reference
            .ordered_target_positions_rad
    );
    assert_eq!(
        reference(descriptor, &source, RecoveryPhaseV1::RaiseBody).unwrap(),
        previous
    );
}

#[test]
fn r10ap_vertical_heading_has_explicit_fallback() {
    let (descriptor, rows) = fixtures();
    let mut source = observation(&rows[0]);
    let angle = std::f64::consts::FRAC_PI_4;
    source.state.base_pose_world.orientation_xyzw = Quaternion {
        x: 0.0,
        y: 0.0,
        z: angle.sin(),
        w: angle.cos(),
    };
    let plan = reference(descriptor, &source, RecoveryPhaseV1::RaiseBody).unwrap();
    assert_eq!(plan.mode, "explicit_v23_fallback");
    assert_eq!(
        plan.progressive_headroom_geometry
            .unwrap()
            .hold_reason
            .as_deref(),
        Some("undefined_horizontal_heading")
    );
}

#[test]
fn r10ap_deficit_and_ranking_controls() {
    assert_eq!(deficits([0.0; 8]), [0.0; 8]);
    assert!(deficits(LIMITS).into_iter().all(|v| (v - 0.02).abs() < EPS));
    assert!(
        deficits(LIMITS.map(|v| v - 0.02))
            .into_iter()
            .all(|v| v < EPS)
    );
    assert!(
        deficits(LIMITS.map(|v| v + 0.01))
            .into_iter()
            .all(|v| (v - 0.03).abs() < EPS)
    );
    assert!(rank_less([0.01, 1.0, 100.0], [0.02, 0.0, 0.0]));
    assert!(!rank_less([0.02, 0.0, 0.0], [0.01, 1.0, 100.0]));
    assert!(rank_less([0.0, 0.0, 1.0], [0.0, 0.0, 2.0]));
    assert!(!rank_less([0.0, 0.0, 2.0], [0.0, 0.0, 2.0]));
    let mut before = [0.0; 8];
    before[0] = 0.02;
    before[1] = 0.01;
    let mut after = before;
    after[0] = 0.019;
    assert_eq!(headroom_allowed(before, after), (true, true));
    after[0] = 0.01;
    after[1] = 0.011;
    assert_eq!(headroom_allowed(before, after), (false, true));
    assert_eq!(headroom_allowed(before, before), (true, false));
    assert_eq!(headroom_allowed([0.0; 8], [0.0; 8]), (true, true));
}

#[test]
fn r10ap_receipt_roundtrip_is_strict_and_has_no_native_authority() {
    let (descriptor, rows) = fixtures();
    for row in [&rows[0], &rows[30], &rows[4]] {
        let plan = reference(descriptor, &observation(row), RecoveryPhaseV1::RaiseBody).unwrap();
        let value = serde_json::to_value(&plan).unwrap();
        assert_eq!(
            serde_json::from_value::<ProgressiveHeadroomPlan>(value.clone()).unwrap(),
            plan
        );
        assert_eq!(
            value["schema_version"],
            "sporespore_r10ap_progressive_headroom_plan_v1"
        );
        assert!(
            !plan.native_source_validation_performed
                && !plan.physical_acceptance_authority
                && !plan.release_authority
        );
        let mut invalid = value.clone();
        invalid["undeclared"] = json!(true);
        assert!(serde_json::from_value::<ProgressiveHeadroomPlan>(invalid).is_err());
        let mut invalid = value;
        invalid["progressive_headroom_geometry"]["undeclared"] = json!(true);
        assert!(serde_json::from_value::<ProgressiveHeadroomPlan>(invalid).is_err());
    }
}
