//! Zero-world mapping of the public actuator-cap profile into Rapier motors.
//!
//! This module deliberately constructs only standalone joint values. It does
//! not construct a rigid-body set, collider set, physics pipeline, or world,
//! and it never advances a solver.

use rapier3d::prelude::*;
use serde_json::{Value, json};
use sporespore_locomotion_core::{
    ACTUATOR_CAP_PROFILE_RECEIPT_V1_VERSION, ACTUATOR_CAP_PROFILE_V1_VERSION,
    ACTUATOR_PROFILE_OUTER_STEP_DURATION_S, ACTUATOR_PROFILE_OUTER_STEP_HZ,
    ActuatorCapProfileReceiptV1, ActuatorCapProfileRequestV1, ActuatorCapProfileSupportStatusV1,
    OUTER_STEP_ANGULAR_IMPULSE_SEMANTICS_V1, R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
    R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256, R23D60_SELECTED_S169_DESCRIPTOR_SHA256,
    R23D60_SELECTED_S169_MORPHOLOGY_SPEC_SHA256, digest_serializable,
    r23d60_selected_s169_descriptor, resolve_actuator_cap_profile_v1,
};

use crate::active_configuration::RAPIER_ACTIVE_SOLVER_ITERATIONS;
use crate::velocity_only_live_integration::{
    VELOCITY_ONLY_MOTOR_DAMPING_NM_S_PER_RAD, VELOCITY_ONLY_NATIVE_POSITION_STIFFNESS_NM_PER_RAD,
    build_velocity_only_joint_v1, update_velocity_only_motor_v1,
    velocity_only_maximum_force_from_outer_impulse_v1, velocity_only_small_step_impulse_limit_v1,
};
use crate::{ADAPTER_ID, RAPIER_DT_S};

const REPORT_SCHEMA_VERSION: &str = "sporespore_rapier_actuator_cap_profile_zero_world_mapping_v1";
const HOST_MAPPING_ID: &str = "sporespore_rapier_force_based_outer_impulse_cap_mapping_v1";
const F32_ROUNDING_BUDGET_EPSILON_MULTIPLIER: f64 = 8.0;

const ORDERED_ACTUATOR_IDS: [&str; 8] = [
    "front_left_hip_motor",
    "front_left_knee_motor",
    "front_right_hip_motor",
    "front_right_knee_motor",
    "rear_left_hip_motor",
    "rear_left_knee_motor",
    "rear_right_hip_motor",
    "rear_right_knee_motor",
];
const ORDERED_JOINT_IDS: [&str; 8] = [
    "front_left_hip",
    "front_left_knee",
    "front_right_hip",
    "front_right_knee",
    "rear_left_hip",
    "rear_left_knee",
    "rear_right_hip",
    "rear_right_knee",
];
const ORDERED_CAPS_NMS: [f64; 8] = [
    0.05362625170687301,
    0.4567500054836273,
    0.05362625170687301,
    0.4567500054836273,
    0.05637374829312699,
    0.4567500054836273,
    0.05637374829312699,
    0.4567500054836273,
];

/// One exact public-profile entry after conversion into Rapier's native
/// ForceBased maximum-force surface.  This typed value is shared by the
/// zero-world production-route audit and the physical HostRobot constructor;
/// neither path is allowed to reconstruct the profile independently.
#[derive(Clone, Debug)]
pub(crate) struct RapierPublicActuatorCapMappingV1 {
    pub(crate) actuator_id: String,
    pub(crate) joint_id: String,
    pub(crate) portable_maximum_outer_step_impulse_nms: f64,
    pub(crate) rapier_maximum_force_nm_f32: f32,
    pub(crate) reconstructed_outer_step_impulse_nms: f64,
    pub(crate) outer_step_reconstruction_error_nms: f64,
    pub(crate) outer_step_reconstruction_budget_nms: f64,
}

/// Fully resolved exact-profile dependency passed into the production robot
/// constructor.  The JSON receipts remain attached so the eventual physical
/// worker can expose the same identity that was validated before its world is
/// constructed.
#[derive(Clone, Debug)]
pub(crate) struct RapierPublicActuatorCapBindingV1 {
    pub(crate) resolution_receipt: Value,
    pub(crate) host_mapping_receipt: Value,
    pub(crate) ordered_mappings: Vec<RapierPublicActuatorCapMappingV1>,
}

fn validate_profile_receipt(receipt: &ActuatorCapProfileReceiptV1) -> Result<(), String> {
    if receipt.schema_version != ACTUATOR_CAP_PROFILE_RECEIPT_V1_VERSION {
        return Err("QSDK_R23D61_RAPIER_RECEIPT_SCHEMA_INVALID".to_owned());
    }
    if receipt.requested_profile_id != R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID
        || receipt.supported_profile_ids
            != [R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID.to_owned()]
        || receipt.support_status != ActuatorCapProfileSupportStatusV1::SupportedExact
        || receipt.refusal_reason.is_some()
    {
        return Err("QSDK_R23D61_RAPIER_PROFILE_SUPPORT_INVALID".to_owned());
    }
    if receipt.descriptor_sha256 != R23D60_SELECTED_S169_DESCRIPTOR_SHA256
        || receipt.morphology_spec_sha256 != R23D60_SELECTED_S169_MORPHOLOGY_SPEC_SHA256
        || receipt.profile_sha256.as_deref()
            != Some(R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256)
    {
        return Err("QSDK_R23D61_RAPIER_PROFILE_IDENTITY_INVALID".to_owned());
    }
    if receipt.world_build_count != 0
        || receipt.physics_state_modified
        || receipt.physical_acceptance_authority
        || receipt.release_authority
    {
        return Err("QSDK_R23D61_RAPIER_PROFILE_AUTHORITY_INVALID".to_owned());
    }

    let profile = receipt
        .profile
        .as_ref()
        .ok_or_else(|| "QSDK_R23D61_RAPIER_PROFILE_MISSING".to_owned())?;
    let observed_profile_sha256 = digest_serializable(profile)
        .map_err(|_| "QSDK_R23D61_RAPIER_PROFILE_DIGEST_INVALID".to_owned())?;
    if observed_profile_sha256 != R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256 {
        return Err("QSDK_R23D61_RAPIER_PROFILE_CONTENT_IDENTITY_INVALID".to_owned());
    }
    if profile.schema_version != ACTUATOR_CAP_PROFILE_V1_VERSION
        || profile.profile_id != R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID
        || profile.supported_descriptor_sha256 != R23D60_SELECTED_S169_DESCRIPTOR_SHA256
        || profile.supported_morphology_spec_sha256 != R23D60_SELECTED_S169_MORPHOLOGY_SPEC_SHA256
        || profile.semantics.semantics_id != OUTER_STEP_ANGULAR_IMPULSE_SEMANTICS_V1
        || profile.semantics.quantity != "maximum_angular_impulse_per_complete_outer_control_step"
        || profile.semantics.unit != "newton_meter_second"
        || profile.semantics.outer_step_hz != ACTUATOR_PROFILE_OUTER_STEP_HZ
        || profile.semantics.outer_step_duration_s.to_bits()
            != ACTUATOR_PROFILE_OUTER_STEP_DURATION_S.to_bits()
        || profile.semantics.host_mapping_rule
            != "preserve_maximum_outer_step_angular_impulse_exactly"
        || profile
            .semantics
            .solver_iteration_multiplier_in_canonical_budget
    {
        return Err("QSDK_R23D61_RAPIER_PROFILE_SEMANTICS_INVALID".to_owned());
    }
    let boundary = &profile.claim_boundary;
    if !boundary.exact_scope_profile_publication
        || boundary.arbitrary_morphology_support
        || boundary.physical_question_declared
        || boundary.physical_world_opened
        || boundary.three_engine_turning
        || boundary.prone_to_standing
        || boundary.cross_engine_equivalence
        || boundary.physical_acceptance_authority
        || boundary.release_authority
    {
        return Err("QSDK_R23D61_RAPIER_PROFILE_CLAIM_BOUNDARY_INVALID".to_owned());
    }
    if profile.ordered_caps.len() != ORDERED_CAPS_NMS.len() {
        return Err("QSDK_R23D61_RAPIER_PROFILE_CARDINALITY_INVALID".to_owned());
    }
    for (index, entry) in profile.ordered_caps.iter().enumerate() {
        if entry.actuator_id != ORDERED_ACTUATOR_IDS[index]
            || entry.joint_id != ORDERED_JOINT_IDS[index]
            || entry.maximum_outer_step_impulse_nms.to_bits() != ORDERED_CAPS_NMS[index].to_bits()
        {
            return Err("QSDK_R23D61_RAPIER_PROFILE_ORDER_OR_CAP_INVALID".to_owned());
        }
    }
    Ok(())
}

fn compile_profile_binding(
    receipt: &ActuatorCapProfileReceiptV1,
) -> Result<RapierPublicActuatorCapBindingV1, String> {
    validate_profile_receipt(receipt)?;
    let profile = receipt.profile.as_ref().expect("validated profile exists");
    let mut ordered_mappings = Vec::with_capacity(profile.ordered_caps.len());
    let mut typed_mappings = Vec::with_capacity(profile.ordered_caps.len());
    let mut maximum_outer_reconstruction_error_nms = 0.0_f64;
    let mut maximum_outer_reconstruction_budget_nms = 0.0_f64;

    for (index, entry) in profile.ordered_caps.iter().enumerate() {
        let cap = entry.maximum_outer_step_impulse_nms;
        let maximum_force_nm = velocity_only_maximum_force_from_outer_impulse_v1(cap)?;
        let small_step_impulse_limit_nms =
            velocity_only_small_step_impulse_limit_v1(maximum_force_nm);
        let reconstructed_outer_impulse_nms = maximum_force_nm as f64 * RAPIER_DT_S as f64;
        let outer_reconstruction_error_nms = (reconstructed_outer_impulse_nms - cap).abs();
        let outer_reconstruction_budget_nms = F32_ROUNDING_BUDGET_EPSILON_MULTIPLIER
            * f32::EPSILON as f64
            * cap.abs().max(f64::MIN_POSITIVE);
        if outer_reconstruction_error_nms > outer_reconstruction_budget_nms {
            return Err("QSDK_R23D61_RAPIER_F32_MAPPING_BUDGET_EXCEEDED".to_owned());
        }
        maximum_outer_reconstruction_error_nms =
            maximum_outer_reconstruction_error_nms.max(outer_reconstruction_error_nms);
        maximum_outer_reconstruction_budget_nms =
            maximum_outer_reconstruction_budget_nms.max(outer_reconstruction_budget_nms);

        let target_velocity_rad_s = if index % 2 == 0 { 0.25 } else { -0.5 };
        let builder_joint = build_velocity_only_joint_v1(
            RevoluteJointBuilder::new(Vector::X),
            target_velocity_rad_s,
            maximum_force_nm,
        )?;
        let builder_motor = builder_joint
            .motor()
            .ok_or_else(|| "QSDK_R23D61_RAPIER_BUILDER_MOTOR_MISSING".to_owned())?;
        if builder_motor.model != MotorModel::ForceBased
            || builder_motor.target_pos != 0.0
            || builder_motor.target_vel != target_velocity_rad_s
            || builder_motor.stiffness != VELOCITY_ONLY_NATIVE_POSITION_STIFFNESS_NM_PER_RAD
            || builder_motor.damping != VELOCITY_ONLY_MOTOR_DAMPING_NM_S_PER_RAD
            || builder_motor.max_force != maximum_force_nm
        {
            return Err("QSDK_R23D61_RAPIER_BUILDER_READBACK_INVALID".to_owned());
        }
        let mut mutable_joint = builder_joint;
        let mutable_readback = update_velocity_only_motor_v1(
            &mut mutable_joint,
            -target_velocity_rad_s,
            maximum_force_nm,
        )?;
        if !mutable_readback.validates(-target_velocity_rad_s, maximum_force_nm) {
            return Err("QSDK_R23D61_RAPIER_MUTABLE_READBACK_INVALID".to_owned());
        }

        ordered_mappings.push(json!({
            "actuator_id": entry.actuator_id,
            "joint_id": entry.joint_id,
            "portable_maximum_outer_step_impulse_nms": cap,
            "rapier_maximum_force_nm_f32": maximum_force_nm,
            "rapier_small_step_impulse_limit_nms_f32": small_step_impulse_limit_nms,
            "rapier_solver_iteration_count": RAPIER_ACTIVE_SOLVER_ITERATIONS,
            "reconstructed_outer_step_impulse_nms": reconstructed_outer_impulse_nms,
            "outer_step_reconstruction_error_nms": outer_reconstruction_error_nms,
            "outer_step_reconstruction_budget_nms": outer_reconstruction_budget_nms,
            "builder_motor_model": "ForceBased",
            "builder_maximum_force_readback_nm_f32": builder_motor.max_force,
            "mutable_maximum_force_readback_nm_f32": mutable_readback.maximum_force_nm,
        }));
        typed_mappings.push(RapierPublicActuatorCapMappingV1 {
            actuator_id: entry.actuator_id.clone(),
            joint_id: entry.joint_id.clone(),
            portable_maximum_outer_step_impulse_nms: cap,
            rapier_maximum_force_nm_f32: maximum_force_nm,
            reconstructed_outer_step_impulse_nms: reconstructed_outer_impulse_nms,
            outer_step_reconstruction_error_nms: outer_reconstruction_error_nms,
            outer_step_reconstruction_budget_nms: outer_reconstruction_budget_nms,
        });
    }

    let host_mapping_receipt = json!({
        "schema_version": REPORT_SCHEMA_VERSION,
        "ok": true,
        "adapter_id": ADAPTER_ID,
        "host_mapping_id": HOST_MAPPING_ID,
        "profile_id": R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
        "profile_sha256": R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256,
        "portable_semantics_id": OUTER_STEP_ANGULAR_IMPULSE_SEMANTICS_V1,
        "rapier_scalar": "f32",
        "rapier_outer_step_duration_s_f32": RAPIER_DT_S,
        "rapier_solver_iteration_count": RAPIER_ACTIVE_SOLVER_ITERATIONS,
        "ordered_mappings": ordered_mappings,
        "validated_actuator_count": ORDERED_CAPS_NMS.len(),
        "maximum_outer_step_reconstruction_error_nms":
            maximum_outer_reconstruction_error_nms,
        "maximum_outer_step_reconstruction_budget_nms":
            maximum_outer_reconstruction_budget_nms,
        "numeric_adequacy": {
            "kind": "host_f32_representation_rounding_bound_not_physical_margin",
            "f32_epsilon_multiplier": F32_ROUNDING_BUDGET_EPSILON_MULTIPLIER,
            "applies_only_to": "portable_f64_cap_to_rapier_f32_force_and_f32_dt_round_trip",
            "population_claim": false,
            "physical_claim": false,
        },
        "standalone_joint_value_count": ORDERED_CAPS_NMS.len(),
        "rigid_body_set_construction_count": 0,
        "collider_set_construction_count": 0,
        "physics_pipeline_construction_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": false,
        "locomotion_outcome_exposed": false,
        "turning_claimed": false,
        "prone_to_standing_claimed": false,
        "cross_engine_equivalence_claimed": false,
        "physical_acceptance_authority": false,
        "release_authority": false,
    });
    let resolution_receipt = serde_json::to_value(receipt)
        .map_err(|error| format!("QSDK_R23D61_RAPIER_RECEIPT_SERIALIZATION_FAILED:{error}"))?;
    Ok(RapierPublicActuatorCapBindingV1 {
        resolution_receipt,
        host_mapping_receipt,
        ordered_mappings: typed_mappings,
    })
}

fn map_profile_receipt(receipt: &ActuatorCapProfileReceiptV1) -> Result<Value, String> {
    Ok(compile_profile_binding(receipt)?.host_mapping_receipt)
}

/// Resolve the published exact-s169 profile into the typed mapping consumed by
/// the production HostRobot constructor.  This performs no model or world
/// construction and advances no solver.
pub(crate) fn resolve_production_public_profile_binding_v1()
-> Result<RapierPublicActuatorCapBindingV1, String> {
    let receipt = resolve_actuator_cap_profile_v1(ActuatorCapProfileRequestV1 {
        schema_version: sporespore_locomotion_core::ACTUATOR_CAP_PROFILE_REQUEST_V1_VERSION
            .to_owned(),
        profile_id: R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID.to_owned(),
        descriptor: r23d60_selected_s169_descriptor(),
    })
    .map_err(|error| error.to_string())?;
    compile_profile_binding(&receipt)
}

/// Exercise the production Rapier motor-configuration helpers with the exact
/// published profile and a complete set of fail-closed receipt mutations.
pub fn run_actuator_cap_profile_preflight() -> Result<Value, String> {
    let receipt = resolve_actuator_cap_profile_v1(ActuatorCapProfileRequestV1 {
        schema_version: sporespore_locomotion_core::ACTUATOR_CAP_PROFILE_REQUEST_V1_VERSION
            .to_owned(),
        profile_id: R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID.to_owned(),
        descriptor: r23d60_selected_s169_descriptor(),
    })
    .map_err(|error| error.to_string())?;
    let mut report = map_profile_receipt(&receipt)?;

    let mut mutations = Vec::new();
    let mut candidates: Vec<(&str, ActuatorCapProfileReceiptV1)> = Vec::new();

    let mut wrong_receipt_schema = receipt.clone();
    wrong_receipt_schema.schema_version.push_str("_mutated");
    candidates.push(("wrong_receipt_schema", wrong_receipt_schema));

    let mut wrong_support = receipt.clone();
    wrong_support.support_status = ActuatorCapProfileSupportStatusV1::OutOfDomainMorphology;
    candidates.push(("wrong_support_status", wrong_support));

    let mut wrong_profile_sha = receipt.clone();
    wrong_profile_sha.profile_sha256 = Some("sha256:mutated".to_owned());
    candidates.push(("wrong_profile_sha256", wrong_profile_sha));

    let mut wrong_semantics = receipt.clone();
    wrong_semantics
        .profile
        .as_mut()
        .expect("fixture profile")
        .semantics
        .semantics_id
        .push_str("_mutated");
    candidates.push(("wrong_semantics", wrong_semantics));

    let mut swapped_order = receipt.clone();
    swapped_order
        .profile
        .as_mut()
        .expect("fixture profile")
        .ordered_caps
        .swap(0, 1);
    candidates.push(("swapped_actuator_order", swapped_order));

    let mut wrong_cap = receipt.clone();
    wrong_cap
        .profile
        .as_mut()
        .expect("fixture profile")
        .ordered_caps[0]
        .maximum_outer_step_impulse_nms = 0.0;
    candidates.push(("zero_cap", wrong_cap));

    let mut mutated_bound_profile_field = receipt.clone();
    mutated_bound_profile_field
        .profile
        .as_mut()
        .expect("fixture profile")
        .ordered_caps[4]
        .maximum_outer_step_impulse_binary64_hex = "0x3facdd051a8b389c".to_owned();
    candidates.push(("mutated_bound_profile_field", mutated_bound_profile_field));

    let mut inflated_world = receipt.clone();
    inflated_world.world_build_count = 1;
    candidates.push(("inflated_world_count", inflated_world));

    let mut inflated_authority = receipt.clone();
    inflated_authority
        .profile
        .as_mut()
        .expect("fixture profile")
        .claim_boundary
        .cross_engine_equivalence = true;
    candidates.push(("inflated_claim_authority", inflated_authority));

    for (mutation_id, candidate) in candidates {
        let rejected = map_profile_receipt(&candidate).is_err();
        mutations.push(json!({
            "mutation_id": mutation_id,
            "rejected": rejected,
        }));
        if !rejected {
            return Err(format!(
                "QSDK_R23D61_RAPIER_MUTATION_ACCEPTED:{mutation_id}"
            ));
        }
    }

    let object = report
        .as_object_mut()
        .ok_or_else(|| "QSDK_R23D61_RAPIER_REPORT_INVALID".to_owned())?;
    object.insert(
        "mutation_rejection_count".to_owned(),
        json!(mutations.len()),
    );
    object.insert("mutation_results".to_owned(), Value::Array(mutations));
    Ok(report)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn exact_profile_maps_through_real_rapier_joint_apis_without_a_world() {
        let report = run_actuator_cap_profile_preflight().unwrap();
        assert_eq!(report["ok"], true);
        assert_eq!(report["validated_actuator_count"], 8);
        assert_eq!(report["standalone_joint_value_count"], 8);
        assert_eq!(report["mutation_rejection_count"], 9);
        assert_eq!(report["world_build_count"], 0);
        assert_eq!(report["solver_step_count"], 0);
        assert_eq!(report["physics_state_modified"], false);
        assert_eq!(report["turning_claimed"], false);
        assert_eq!(report["prone_to_standing_claimed"], false);
        assert_eq!(report["cross_engine_equivalence_claimed"], false);
        assert_eq!(report["physical_acceptance_authority"], false);
        assert_eq!(report["release_authority"], false);
        assert!(
            report["maximum_outer_step_reconstruction_error_nms"]
                .as_f64()
                .unwrap()
                <= report["maximum_outer_step_reconstruction_budget_nms"]
                    .as_f64()
                    .unwrap()
        );
    }

    #[test]
    fn valid_out_of_domain_morphology_cannot_enter_the_rapier_mapping() {
        let receipt = resolve_actuator_cap_profile_v1(ActuatorCapProfileRequestV1 {
            schema_version: sporespore_locomotion_core::ACTUATOR_CAP_PROFILE_REQUEST_V1_VERSION
                .to_owned(),
            profile_id: R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID.to_owned(),
            descriptor: sporespore_locomotion_core::BoundedQuadrupedDescriptor::reference(
                "valid_out_of_domain",
            ),
        })
        .unwrap();
        assert_eq!(
            receipt.support_status,
            ActuatorCapProfileSupportStatusV1::OutOfDomainMorphology
        );
        assert!(map_profile_receipt(&receipt).is_err());
    }
}
