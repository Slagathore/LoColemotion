//! Versioned, exact-scope actuator-cap profiles.
//!
//! This module publishes actuator semantics; it does not construct a physics
//! world, apply host actuation, or turn an evidence-bounded profile into an
//! arbitrary-morphology claim. The first profile makes the cap vector selected
//! by QSDK-R23D59 and validated by QSDK-R23D60 explicit instead of leaving its
//! knee limits hidden behind a legacy Godot fixture comparator.

use serde::{Deserialize, Serialize};

use crate::canonical::digest_serializable;
use crate::quadruped::{
    BOUNDED_QUADRUPED_DESCRIPTOR_VERSION, BoundedQuadrupedDescriptor, compile_bounded_quadruped,
};
use crate::schema::{CoreError, Result};

pub const ACTUATOR_CAP_PROFILE_REQUEST_V1_VERSION: &str =
    "sporespore_actuator_cap_profile_request_v1";
pub const ACTUATOR_CAP_PROFILE_V1_VERSION: &str = "sporespore_actuator_cap_profile_v1";
pub const ACTUATOR_CAP_PROFILE_RECEIPT_V1_VERSION: &str =
    "sporespore_actuator_cap_profile_receipt_v1";
pub const OUTER_STEP_ANGULAR_IMPULSE_SEMANTICS_V1: &str =
    "sporespore_outer_control_step_angular_impulse_budget_120hz_v1";
pub const R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID: &str =
    "sporespore_qsdk_r23d60_selected_s169_actuator_cap_profile_v1";
pub const R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256: &str =
    "sha256:b65d41e3f30c42e0a8207f1385fe00daa8f03975f4e266a0bd0867970f674964";
pub const R23D60_SELECTED_S169_DESCRIPTOR_SHA256: &str =
    "sha256:ae7a0872b8b15dfb294c388931899cf82822293417d125dd72ee2a5a847e09e0";
pub const R23D60_SELECTED_S169_MORPHOLOGY_SPEC_SHA256: &str =
    "sha256:30893a75e8362dcab69f0fb46b0560cacbe5d5c034cb0152e67eb520ff35f45e";
pub const R23D60_SELECTED_S169_MORPHOLOGY_ID: &str = "qsdk_r05_generated_s169";
pub const ACTUATOR_PROFILE_OUTER_STEP_HZ: u32 = 120;
pub const ACTUATOR_PROFILE_OUTER_STEP_DURATION_S: f64 = 1.0 / 120.0;

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
const ORDERED_BASE_COMPILED_CAPS_NMS: [f64; 8] = [
    0.05362625170687301,
    0.04387602412380519,
    0.05362625170687301,
    0.04387602412380519,
    0.056373748293126996,
    0.046123975876194816,
    0.056373748293126996,
    0.046123975876194816,
];
const ORDERED_SELECTED_CAPS_NMS: [f64; 8] = [
    0.05362625170687301,
    0.4567500054836273,
    0.05362625170687301,
    0.4567500054836273,
    0.05637374829312699,
    0.4567500054836273,
    0.05637374829312699,
    0.4567500054836273,
];

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ActuatorCapProfileRequestV1 {
    pub schema_version: String,
    pub profile_id: String,
    pub descriptor: BoundedQuadrupedDescriptor,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ActuatorCapProfileSupportStatusV1 {
    SupportedExact,
    OutOfDomainMorphology,
    UnsupportedProfile,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ActuatorCapSourceV1 {
    R23d60SelectedPortableHipExplicitPublication,
    R23d60SelectedFixtureKneeExplicitPublication,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ActuatorCapProfileSemanticsV1 {
    pub semantics_id: String,
    pub quantity: String,
    pub unit: String,
    pub outer_step_hz: u32,
    pub outer_step_duration_s: f64,
    pub host_mapping_rule: String,
    pub solver_iteration_multiplier_in_canonical_budget: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ActuatorCapEntryV1 {
    pub actuator_id: String,
    pub joint_id: String,
    pub source: ActuatorCapSourceV1,
    pub base_compiled_maximum_impulse_nms: f64,
    pub base_compiled_maximum_impulse_binary64_hex: String,
    pub maximum_outer_step_impulse_nms: f64,
    pub maximum_outer_step_impulse_binary64_hex: String,
    pub differs_from_base_compiled_morphology: bool,
    pub base_to_profile_binary64_ulp_distance: String,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ActuatorCapProfileProvenanceV1 {
    pub r23d58_zero_world_contract_path: String,
    pub r23d58_zero_world_contract_raw_sha256: String,
    pub r23d58_physical_source_commit: String,
    pub r23d59_selection_closure_path: String,
    pub r23d59_selection_closure_raw_sha256: String,
    pub r23d59_selection_source_commit: String,
    pub r23d60_validation_closure_path: String,
    pub r23d60_validation_closure_raw_sha256: String,
    pub r23d60_validation_source_commit: String,
    pub selected_predecessor_profile_id: String,
    pub fixture_comparator_was_public_sdk_semantics: bool,
    pub fixture_behavior_silently_applied: bool,
    pub historical_result_reinterpreted: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ActuatorCapProfileClaimBoundaryV1 {
    pub exact_scope_profile_publication: bool,
    pub arbitrary_morphology_support: bool,
    pub physical_question_declared: bool,
    pub physical_world_opened: bool,
    pub three_engine_turning: bool,
    pub prone_to_standing: bool,
    pub cross_engine_equivalence: bool,
    pub physical_acceptance_authority: bool,
    pub release_authority: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ActuatorCapProfileV1 {
    pub schema_version: String,
    pub profile_id: String,
    pub supported_morphology_id: String,
    pub supported_descriptor_sha256: String,
    pub supported_morphology_spec_sha256: String,
    pub semantics: ActuatorCapProfileSemanticsV1,
    pub ordered_caps: Vec<ActuatorCapEntryV1>,
    pub provenance: ActuatorCapProfileProvenanceV1,
    pub claim_boundary: ActuatorCapProfileClaimBoundaryV1,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ActuatorCapProfileReceiptV1 {
    pub schema_version: String,
    pub requested_profile_id: String,
    pub supported_profile_ids: Vec<String>,
    pub support_status: ActuatorCapProfileSupportStatusV1,
    pub refusal_reason: Option<String>,
    pub descriptor_sha256: String,
    pub morphology_spec_sha256: String,
    pub profile: Option<ActuatorCapProfileV1>,
    pub profile_sha256: Option<String>,
    pub world_build_count: u32,
    pub physics_state_modified: bool,
    pub physical_acceptance_authority: bool,
    pub release_authority: bool,
}

pub fn r23d60_selected_s169_descriptor() -> BoundedQuadrupedDescriptor {
    BoundedQuadrupedDescriptor {
        schema_version: BOUNDED_QUADRUPED_DESCRIPTOR_VERSION.to_owned(),
        morphology_id: R23D60_SELECTED_S169_MORPHOLOGY_ID.to_owned(),
        torso_length_scale: 1.0041015625,
        torso_width_scale: 1.0031893004115227,
        upper_length_fraction: 0.5219571428571428,
        hip_span_scale: 0.9856413994169096,
        foot_radius_scale: 0.9987180691209617,
        front_limb_mass_scale: 0.975022758306782,
    }
}

fn binary64_hex(value: f64) -> String {
    format!("0x{:016x}", value.to_bits())
}

fn refusal_receipt(
    requested_profile_id: String,
    support_status: ActuatorCapProfileSupportStatusV1,
    refusal_reason: &str,
    descriptor_sha256: String,
    morphology_spec_sha256: String,
) -> ActuatorCapProfileReceiptV1 {
    ActuatorCapProfileReceiptV1 {
        schema_version: ACTUATOR_CAP_PROFILE_RECEIPT_V1_VERSION.to_owned(),
        requested_profile_id,
        supported_profile_ids: vec![R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID.to_owned()],
        support_status,
        refusal_reason: Some(refusal_reason.to_owned()),
        descriptor_sha256,
        morphology_spec_sha256,
        profile: None,
        profile_sha256: None,
        world_build_count: 0,
        physics_state_modified: false,
        physical_acceptance_authority: false,
        release_authority: false,
    }
}

fn selected_profile() -> ActuatorCapProfileV1 {
    let ordered_caps = ORDERED_ACTUATOR_IDS
        .iter()
        .zip(ORDERED_JOINT_IDS)
        .zip(ORDERED_BASE_COMPILED_CAPS_NMS)
        .zip(ORDERED_SELECTED_CAPS_NMS)
        .enumerate()
        .map(
            |(index, (((actuator_id, joint_id), base_cap), selected_cap))| ActuatorCapEntryV1 {
                actuator_id: (*actuator_id).to_owned(),
                joint_id: joint_id.to_owned(),
                source: if index % 2 == 0 {
                    ActuatorCapSourceV1::R23d60SelectedPortableHipExplicitPublication
                } else {
                    ActuatorCapSourceV1::R23d60SelectedFixtureKneeExplicitPublication
                },
                base_compiled_maximum_impulse_nms: base_cap,
                base_compiled_maximum_impulse_binary64_hex: binary64_hex(base_cap),
                maximum_outer_step_impulse_nms: selected_cap,
                maximum_outer_step_impulse_binary64_hex: binary64_hex(selected_cap),
                differs_from_base_compiled_morphology: base_cap.to_bits() != selected_cap.to_bits(),
                base_to_profile_binary64_ulp_distance: base_cap
                    .to_bits()
                    .abs_diff(selected_cap.to_bits())
                    .to_string(),
            },
        )
        .collect();

    ActuatorCapProfileV1 {
        schema_version: ACTUATOR_CAP_PROFILE_V1_VERSION.to_owned(),
        profile_id: R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID.to_owned(),
        supported_morphology_id: R23D60_SELECTED_S169_MORPHOLOGY_ID.to_owned(),
        supported_descriptor_sha256: R23D60_SELECTED_S169_DESCRIPTOR_SHA256.to_owned(),
        supported_morphology_spec_sha256: R23D60_SELECTED_S169_MORPHOLOGY_SPEC_SHA256.to_owned(),
        semantics: ActuatorCapProfileSemanticsV1 {
            semantics_id: OUTER_STEP_ANGULAR_IMPULSE_SEMANTICS_V1.to_owned(),
            quantity: "maximum_angular_impulse_per_complete_outer_control_step".to_owned(),
            unit: "newton_meter_second".to_owned(),
            outer_step_hz: ACTUATOR_PROFILE_OUTER_STEP_HZ,
            outer_step_duration_s: ACTUATOR_PROFILE_OUTER_STEP_DURATION_S,
            host_mapping_rule: "preserve_maximum_outer_step_angular_impulse_exactly".to_owned(),
            solver_iteration_multiplier_in_canonical_budget: false,
        },
        ordered_caps,
        provenance: ActuatorCapProfileProvenanceV1 {
            r23d58_zero_world_contract_path:
                "sdk/turning/r23d58_godot_terminal_trace_cap_factorial_zero_world_v1.json"
                    .to_owned(),
            r23d58_zero_world_contract_raw_sha256:
                "sha256:b1d5615048c624e506dd4b89a3abac41dd07c41e90a9b814bae6cbb5913961ad".to_owned(),
            r23d58_physical_source_commit: "ecfc191bcc97ea53b089e9862a5d0b5a7a8ad6b5".to_owned(),
            r23d59_selection_closure_path:
                "sdk/turning/r23d59_godot_knee_source_finite_decision_closure_v1.json".to_owned(),
            r23d59_selection_closure_raw_sha256:
                "sha256:cbce64d87d18dbd819f8afd759943f4bbe7c066d32da3d4c4f567fc7b4422cc8".to_owned(),
            r23d59_selection_source_commit: "22020d397ea4ce952a67051a843c22b388f0f78b".to_owned(),
            r23d60_validation_closure_path:
                "sdk/turning/r23d60_godot_fixture_knee_held_out_turning_validation_closure_v1.json"
                    .to_owned(),
            r23d60_validation_closure_raw_sha256:
                "sha256:910fd0ba2369a889430c1228f2eaea1146cf26005c4ac51f353803869d709fd8".to_owned(),
            r23d60_validation_source_commit: "3d884af6dc0a15aa9bd2cde15de4535a24bb44a2".to_owned(),
            selected_predecessor_profile_id: "portable_hip__fixture_knee".to_owned(),
            fixture_comparator_was_public_sdk_semantics: false,
            fixture_behavior_silently_applied: false,
            historical_result_reinterpreted: false,
        },
        claim_boundary: ActuatorCapProfileClaimBoundaryV1 {
            exact_scope_profile_publication: true,
            arbitrary_morphology_support: false,
            physical_question_declared: false,
            physical_world_opened: false,
            three_engine_turning: false,
            prone_to_standing: false,
            cross_engine_equivalence: false,
            physical_acceptance_authority: false,
            release_authority: false,
        },
    }
}

pub fn resolve_actuator_cap_profile_v1(
    request: ActuatorCapProfileRequestV1,
) -> Result<ActuatorCapProfileReceiptV1> {
    if request.schema_version != ACTUATOR_CAP_PROFILE_REQUEST_V1_VERSION {
        return Err(CoreError::Schema(
            "actuator_cap_profile_request_version".to_owned(),
        ));
    }

    // Compile every descriptor first. A profile refusal must never become a
    // bypass around the ordinary public descriptor validation contract.
    let compiled = compile_bounded_quadruped(request.descriptor)?;
    let descriptor_sha256 = compiled.descriptor_sha256.clone();
    let morphology_spec_sha256 = compiled.morphology.morphology_spec_sha256.clone();

    if request.profile_id != R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID {
        return Ok(refusal_receipt(
            request.profile_id,
            ActuatorCapProfileSupportStatusV1::UnsupportedProfile,
            "requested_profile_id_not_registered",
            descriptor_sha256,
            morphology_spec_sha256,
        ));
    }

    if descriptor_sha256 != R23D60_SELECTED_S169_DESCRIPTOR_SHA256
        || morphology_spec_sha256 != R23D60_SELECTED_S169_MORPHOLOGY_SPEC_SHA256
    {
        return Ok(refusal_receipt(
            request.profile_id,
            ActuatorCapProfileSupportStatusV1::OutOfDomainMorphology,
            "descriptor_or_compiled_morphology_outside_exact_profile_scope",
            descriptor_sha256,
            morphology_spec_sha256,
        ));
    }

    if compiled.morphology.ordered_actuator_ids != ORDERED_ACTUATOR_IDS.map(str::to_owned).to_vec()
        || compiled.morphology.ordered_joint_ids != ORDERED_JOINT_IDS.map(str::to_owned).to_vec()
        || compiled.morphology.morphology_spec.actuators.len() != ORDERED_ACTUATOR_IDS.len()
    {
        return Err(CoreError::Order(
            "selected_actuator_cap_profile_scope_order_drift".to_owned(),
        ));
    }
    for (index, actuator) in compiled
        .morphology
        .morphology_spec
        .actuators
        .iter()
        .enumerate()
    {
        if actuator.actuator_id != ORDERED_ACTUATOR_IDS[index]
            || actuator.joint_id != ORDERED_JOINT_IDS[index]
            || actuator.maximum_impulse_nms.to_bits()
                != ORDERED_BASE_COMPILED_CAPS_NMS[index].to_bits()
        {
            return Err(CoreError::Digest(
                "selected_actuator_cap_profile_compiled_surface_drift".to_owned(),
            ));
        }
    }

    let profile = selected_profile();
    let profile_sha256 = digest_serializable(&profile)?;
    if profile_sha256 != R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256 {
        return Err(CoreError::Digest(format!(
            "selected_actuator_cap_profile_content_drift:{profile_sha256}"
        )));
    }
    Ok(ActuatorCapProfileReceiptV1 {
        schema_version: ACTUATOR_CAP_PROFILE_RECEIPT_V1_VERSION.to_owned(),
        requested_profile_id: request.profile_id,
        supported_profile_ids: vec![R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID.to_owned()],
        support_status: ActuatorCapProfileSupportStatusV1::SupportedExact,
        refusal_reason: None,
        descriptor_sha256,
        morphology_spec_sha256,
        profile: Some(profile),
        profile_sha256: Some(profile_sha256),
        world_build_count: 0,
        physics_state_modified: false,
        physical_acceptance_authority: false,
        release_authority: false,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn request(
        profile_id: &str,
        descriptor: BoundedQuadrupedDescriptor,
    ) -> ActuatorCapProfileRequestV1 {
        ActuatorCapProfileRequestV1 {
            schema_version: ACTUATOR_CAP_PROFILE_REQUEST_V1_VERSION.to_owned(),
            profile_id: profile_id.to_owned(),
            descriptor,
        }
    }

    #[test]
    fn selected_profile_is_exact_scope_content_addressed_and_zero_world() {
        let receipt = resolve_actuator_cap_profile_v1(request(
            R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
            r23d60_selected_s169_descriptor(),
        ))
        .unwrap();
        assert_eq!(
            receipt.support_status,
            ActuatorCapProfileSupportStatusV1::SupportedExact
        );
        assert_eq!(
            receipt.descriptor_sha256,
            R23D60_SELECTED_S169_DESCRIPTOR_SHA256
        );
        assert_eq!(
            receipt.morphology_spec_sha256,
            R23D60_SELECTED_S169_MORPHOLOGY_SPEC_SHA256
        );
        assert!(receipt.refusal_reason.is_none());
        assert_eq!(receipt.world_build_count, 0);
        assert!(!receipt.physics_state_modified);
        assert!(!receipt.physical_acceptance_authority);
        assert!(!receipt.release_authority);

        let profile = receipt.profile.unwrap();
        assert_eq!(profile.ordered_caps.len(), 8);
        assert_eq!(
            profile
                .ordered_caps
                .iter()
                .map(|entry| entry.maximum_outer_step_impulse_nms)
                .collect::<Vec<_>>(),
            ORDERED_SELECTED_CAPS_NMS
        );
        assert_eq!(
            profile
                .ordered_caps
                .iter()
                .filter(|entry| entry.differs_from_base_compiled_morphology)
                .count(),
            6
        );
        assert_eq!(
            profile
                .ordered_caps
                .iter()
                .filter(|entry| {
                    entry.source
                        == ActuatorCapSourceV1::R23d60SelectedFixtureKneeExplicitPublication
                })
                .count(),
            4
        );
        assert_eq!(
            profile
                .ordered_caps
                .iter()
                .filter(|entry| {
                    entry.source
                        == ActuatorCapSourceV1::R23d60SelectedPortableHipExplicitPublication
                })
                .count(),
            4
        );
        assert_eq!(
            profile.ordered_caps[0].base_to_profile_binary64_ulp_distance,
            "0"
        );
        assert_eq!(
            profile.ordered_caps[0].base_compiled_maximum_impulse_binary64_hex,
            "0x3fab74e66a937fb7"
        );
        assert_eq!(
            profile.ordered_caps[4].base_compiled_maximum_impulse_binary64_hex,
            "0x3facdd051a8b389c"
        );
        assert_eq!(
            profile.ordered_caps[4].maximum_outer_step_impulse_binary64_hex,
            "0x3facdd051a8b389b"
        );
        assert_eq!(
            profile.ordered_caps[4].base_to_profile_binary64_ulp_distance,
            "1"
        );
        assert_eq!(
            profile.ordered_caps[6].base_to_profile_binary64_ulp_distance,
            "1"
        );
        assert_eq!(
            receipt.profile_sha256,
            Some(R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256.to_owned())
        );
        assert_eq!(
            digest_serializable(&profile).unwrap(),
            R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256
        );
        assert!(profile.claim_boundary.exact_scope_profile_publication);
        assert!(!profile.claim_boundary.arbitrary_morphology_support);
        assert!(!profile.claim_boundary.physical_question_declared);
        assert!(!profile.claim_boundary.three_engine_turning);
        assert!(!profile.claim_boundary.prone_to_standing);
    }

    #[test]
    fn valid_arbitrary_descriptor_receives_explicit_out_of_domain_refusal() {
        let receipt = resolve_actuator_cap_profile_v1(request(
            R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
            BoundedQuadrupedDescriptor::reference("valid_but_not_s169"),
        ))
        .unwrap();
        assert_eq!(
            receipt.support_status,
            ActuatorCapProfileSupportStatusV1::OutOfDomainMorphology
        );
        assert_eq!(
            receipt.refusal_reason.as_deref(),
            Some("descriptor_or_compiled_morphology_outside_exact_profile_scope")
        );
        assert!(receipt.profile.is_none());
        assert!(receipt.profile_sha256.is_none());
        assert_eq!(receipt.world_build_count, 0);
    }

    #[test]
    fn unknown_profile_receives_explicit_unsupported_refusal() {
        let receipt = resolve_actuator_cap_profile_v1(request(
            "unknown_profile",
            r23d60_selected_s169_descriptor(),
        ))
        .unwrap();
        assert_eq!(
            receipt.support_status,
            ActuatorCapProfileSupportStatusV1::UnsupportedProfile
        );
        assert_eq!(
            receipt.refusal_reason.as_deref(),
            Some("requested_profile_id_not_registered")
        );
        assert!(receipt.profile.is_none());
        assert_eq!(
            receipt.supported_profile_ids,
            vec![R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID]
        );
    }

    #[test]
    fn profile_resolution_cannot_bypass_descriptor_validation() {
        let mut descriptor = r23d60_selected_s169_descriptor();
        descriptor.front_limb_mass_scale = 1.2;
        let failure =
            resolve_actuator_cap_profile_v1(request("unknown_profile", descriptor)).unwrap_err();
        assert_eq!(
            failure,
            CoreError::Schema("front_limb_mass_scale_out_of_range".to_owned())
        );
    }

    #[test]
    fn descriptor_identity_mutation_cannot_inherit_exact_profile_support() {
        let mut descriptor = r23d60_selected_s169_descriptor();
        descriptor.morphology_id = "qsdk_r05_generated_s169_alias".to_owned();
        let receipt = resolve_actuator_cap_profile_v1(request(
            R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
            descriptor,
        ))
        .unwrap();
        assert_eq!(
            receipt.support_status,
            ActuatorCapProfileSupportStatusV1::OutOfDomainMorphology
        );
        assert_ne!(
            receipt.descriptor_sha256,
            R23D60_SELECTED_S169_DESCRIPTOR_SHA256
        );
        // The morphology compiler does not include the caller's morphology ID
        // in its spec. Exact descriptor identity remains independently required.
        assert_eq!(
            receipt.morphology_spec_sha256,
            R23D60_SELECTED_S169_MORPHOLOGY_SPEC_SHA256
        );

        let mut adjacent_binary64 = r23d60_selected_s169_descriptor();
        adjacent_binary64.torso_length_scale =
            f64::from_bits(adjacent_binary64.torso_length_scale.to_bits() + 1);
        let adjacent_receipt = resolve_actuator_cap_profile_v1(request(
            R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
            adjacent_binary64,
        ))
        .unwrap();
        assert_eq!(
            adjacent_receipt.support_status,
            ActuatorCapProfileSupportStatusV1::SupportedExact
        );
        // The portable descriptor identity deliberately quantizes binary64
        // transport differences. Godot and Rust can therefore express the
        // same public descriptor without a raw-bit false refusal.
        assert_eq!(
            adjacent_receipt.descriptor_sha256,
            R23D60_SELECTED_S169_DESCRIPTOR_SHA256
        );
        assert!(adjacent_receipt.profile.is_some());
    }
}
