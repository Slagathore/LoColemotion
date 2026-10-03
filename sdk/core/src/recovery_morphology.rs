//! Versioned engine-neutral morphology authority for prone recovery.
//!
//! The original bounded-quadruped descriptor remains immutable because its
//! compiled joint placement and ranges already identify walking and turning
//! evidence. This module embeds that descriptor, publishes the additional
//! morphology authority recovery needs, and returns an exact zero-world
//! ground-geometry support or refusal receipt. It constructs no host model or
//! physics world and makes no recovery-performance claim.

use std::f64::consts::PI;

use serde::{Deserialize, Serialize};

use crate::canonical::digest_serializable;
use crate::quadruped::{
    BoundedQuadrupedDescriptor, CompiledQuadruped, DerivedQuadrupedGeometry,
    QuadrupedJointAuthority, compile_bounded_quadruped, morphology_spec_with_joint_authority,
};
use crate::schema::{CollisionShape, CompiledMorphology, CoreError, Result, compile_morphology};

pub const RECOVERY_MORPHOLOGY_DESCRIPTOR_V1_VERSION: &str =
    "sporespore_recovery_morphology_descriptor_v1";
pub const RECOVERY_MORPHOLOGY_RECEIPT_V1_VERSION: &str =
    "sporespore_recovery_morphology_receipt_v1";
pub const RECOVERY_PRONE_GEOMETRY_RECEIPT_V1_VERSION: &str =
    "sporespore_recovery_prone_geometry_receipt_v1";
pub const RECOVERY_S169_REFERENCE_MORPHOLOGY_ID: &str = "qsdk_r24_recovery_s169_v1";

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryJointAuthorityV1 {
    pub hip_anchor_parent_y_m: f64,
    pub hip_limit_magnitude_rad: f64,
    pub knee_limit_magnitude_rad: f64,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryCanonicalPronePoseV1 {
    pub front_hip_angle_rad: f64,
    pub front_knee_angle_rad: f64,
    pub rear_hip_angle_rad: f64,
    pub rear_knee_angle_rad: f64,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryMorphologyDescriptorV1 {
    pub schema_version: String,
    pub recovery_morphology_id: String,
    pub base_descriptor: BoundedQuadrupedDescriptor,
    pub joint_authority: RecoveryJointAuthorityV1,
    pub canonical_prone_pose: RecoveryCanonicalPronePoseV1,
}

impl RecoveryMorphologyDescriptorV1 {
    pub fn exact_s169_reference(base_descriptor: BoundedQuadrupedDescriptor) -> Self {
        Self {
            schema_version: RECOVERY_MORPHOLOGY_DESCRIPTOR_V1_VERSION.to_owned(),
            recovery_morphology_id: RECOVERY_S169_REFERENCE_MORPHOLOGY_ID.to_owned(),
            base_descriptor,
            joint_authority: RecoveryJointAuthorityV1 {
                hip_anchor_parent_y_m: 0.0,
                hip_limit_magnitude_rad: 1.60,
                knee_limit_magnitude_rad: 1.10,
            },
            canonical_prone_pose: RecoveryCanonicalPronePoseV1 {
                front_hip_angle_rad: 1.55,
                front_knee_angle_rad: 1.10,
                rear_hip_angle_rad: -1.55,
                rear_knee_angle_rad: -1.10,
            },
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RecoveryMorphologySupportStatusV1 {
    SupportedExact,
    UnsupportedProneGeometryInfeasible,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryProneLimbGeometryV1 {
    pub limb_id: String,
    pub hip_joint_id: String,
    pub knee_joint_id: String,
    pub hip_angle_rad: f64,
    pub knee_angle_rad: f64,
    pub hip_center_x_m: f64,
    pub hip_center_y_m: f64,
    pub knee_center_x_m: f64,
    pub knee_center_y_m: f64,
    pub distal_terminal_center_x_m: f64,
    pub distal_terminal_center_y_m: f64,
    pub upper_capsule_radius_m: f64,
    pub upper_capsule_length_m: f64,
    pub upper_capsule_minimum_ground_clearance_m: f64,
    pub distal_capsule_radius_m: f64,
    pub distal_capsule_length_m: f64,
    pub distal_capsule_minimum_ground_clearance_m: f64,
    pub contact_site_radius_m: f64,
    pub contact_site_ground_clearance_m: f64,
    pub minimum_ground_clearance_m: f64,
    pub folds_outward_from_torso: bool,
    pub ground_nonpenetrating: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryProneGeometryReceiptV1 {
    pub schema_version: String,
    pub reference_pose_rule_id: String,
    pub coordinate_frame_id: String,
    pub ground_plane_y_m: f64,
    pub feasibility_threshold_m: f64,
    pub threshold_provenance: String,
    pub torso_center_y_m: f64,
    pub torso_ventral_ground_clearance_m: f64,
    pub ordered_limb_geometry: Vec<RecoveryProneLimbGeometryV1>,
    pub minimum_limb_ground_clearance_m: f64,
    pub minimum_ground_clearance_m: f64,
    pub all_limbs_fold_outward_from_torso: bool,
    pub all_declared_collisions_ground_nonpenetrating: bool,
    pub feasible: bool,
    pub model_construction_count: u32,
    pub world_attempt_count: u32,
    pub world_build_count: u32,
    pub solver_step_count: u32,
    pub physics_state_modified: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryMorphologyClaimBoundaryV1 {
    pub legacy_base_descriptor_preserved: bool,
    pub legacy_base_morphology_spec_preserved: bool,
    pub exact_prone_ground_geometry_evaluated: bool,
    pub exact_prone_ground_geometry_supported: bool,
    pub arbitrary_morphology_recovery_claimed: bool,
    pub controller_compatibility_claimed: bool,
    pub recovery_behavior_claimed: bool,
    pub prone_to_standing_claimed: bool,
    pub cross_engine_recovery_claimed: bool,
    pub physical_acceptance_authority: bool,
    pub release_authority: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryMorphologyReceiptV1 {
    pub schema_version: String,
    pub recovery_morphology_id: String,
    pub support_status: RecoveryMorphologySupportStatusV1,
    pub refusal_reason: Option<String>,
    pub descriptor: RecoveryMorphologyDescriptorV1,
    pub descriptor_sha256: String,
    pub base_descriptor_sha256: String,
    pub base_morphology_spec_sha256: String,
    pub recovery_morphology_spec_sha256: String,
    pub geometry: DerivedQuadrupedGeometry,
    pub morphology: CompiledMorphology,
    pub prone_geometry: RecoveryProneGeometryReceiptV1,
    pub claim_boundary: RecoveryMorphologyClaimBoundaryV1,
    pub model_construction_count: u32,
    pub world_attempt_count: u32,
    pub world_build_count: u32,
    pub solver_step_count: u32,
    pub physics_state_modified: bool,
    pub physical_acceptance_authority: bool,
    pub release_authority: bool,
}

fn semantic_id_valid(value: &str) -> bool {
    let mut characters = value.chars();
    matches!(characters.next(), Some('a'..='z'))
        && characters.all(|character| {
            character.is_ascii_lowercase() || character.is_ascii_digit() || character == '_'
        })
}

fn require_finite(value: f64, field: &str) -> Result<()> {
    if value.is_finite() {
        Ok(())
    } else {
        Err(CoreError::NonFinite(field.to_owned()))
    }
}

fn require_open_angle_magnitude(value: f64, field: &str) -> Result<()> {
    require_finite(value, field)?;
    if value <= 0.0 || value >= PI {
        return Err(CoreError::Schema(format!("{field}_out_of_range")));
    }
    Ok(())
}

fn validate_descriptor(
    descriptor: &RecoveryMorphologyDescriptorV1,
    base: &CompiledQuadruped,
) -> Result<()> {
    if descriptor.schema_version != RECOVERY_MORPHOLOGY_DESCRIPTOR_V1_VERSION {
        return Err(CoreError::Schema(
            "recovery_morphology_descriptor_version".to_owned(),
        ));
    }
    if !semantic_id_valid(&descriptor.recovery_morphology_id) {
        return Err(CoreError::Identity(format!(
            "recovery_morphology_id:{}",
            descriptor.recovery_morphology_id
        )));
    }
    if descriptor.recovery_morphology_id == descriptor.base_descriptor.morphology_id {
        return Err(CoreError::Identity(
            "recovery_morphology_id_must_differ_from_immutable_base".to_owned(),
        ));
    }

    let authority = &descriptor.joint_authority;
    require_finite(
        authority.hip_anchor_parent_y_m,
        "joint_authority.hip_anchor_parent_y_m",
    )?;
    let torso_half_height_m = base.geometry.torso_size_m.y / 2.0;
    if authority.hip_anchor_parent_y_m < -torso_half_height_m
        || authority.hip_anchor_parent_y_m > torso_half_height_m
    {
        return Err(CoreError::Schema(
            "joint_authority.hip_anchor_parent_y_m_outside_torso".to_owned(),
        ));
    }
    require_open_angle_magnitude(
        authority.hip_limit_magnitude_rad,
        "joint_authority.hip_limit_magnitude_rad",
    )?;
    require_open_angle_magnitude(
        authority.knee_limit_magnitude_rad,
        "joint_authority.knee_limit_magnitude_rad",
    )?;

    let pose = &descriptor.canonical_prone_pose;
    for (value, limit, field) in [
        (
            pose.front_hip_angle_rad,
            authority.hip_limit_magnitude_rad,
            "canonical_prone_pose.front_hip_angle_rad",
        ),
        (
            pose.rear_hip_angle_rad,
            authority.hip_limit_magnitude_rad,
            "canonical_prone_pose.rear_hip_angle_rad",
        ),
        (
            pose.front_knee_angle_rad,
            authority.knee_limit_magnitude_rad,
            "canonical_prone_pose.front_knee_angle_rad",
        ),
        (
            pose.rear_knee_angle_rad,
            authority.knee_limit_magnitude_rad,
            "canonical_prone_pose.rear_knee_angle_rad",
        ),
    ] {
        require_finite(value, field)?;
        if value < -limit || value > limit {
            return Err(CoreError::Schema(format!("{field}_outside_joint_limit")));
        }
    }
    Ok(())
}

fn capsule_dimensions(shape: &CollisionShape, body_id: &str) -> Result<(f64, f64)> {
    match shape {
        CollisionShape::Capsule { radius_m, length_m } => Ok((*radius_m, *length_m)),
        _ => Err(CoreError::Topology(format!(
            "recovery_limb_body_not_capsule:{body_id}"
        ))),
    }
}

fn evaluate_prone_geometry(
    descriptor: &RecoveryMorphologyDescriptorV1,
    geometry: &DerivedQuadrupedGeometry,
    morphology: &CompiledMorphology,
) -> Result<RecoveryProneGeometryReceiptV1> {
    let spec = &morphology.morphology_spec;
    let torso_center_y_m = geometry.torso_size_m.y / 2.0;
    let torso_ventral_ground_clearance_m: f64 = 0.0;
    let mut ordered_limb_geometry = Vec::with_capacity(spec.limbs.len());

    for limb in &spec.limbs {
        if limb.ordered_joint_ids.len() != 2 || limb.ordered_contact_site_ids.len() != 1 {
            return Err(CoreError::Topology(format!(
                "recovery_limb_shape:{}",
                limb.limb_id
            )));
        }
        let hip_joint_id = &limb.ordered_joint_ids[0];
        let knee_joint_id = &limb.ordered_joint_ids[1];
        let hip_joint = spec
            .joints
            .iter()
            .find(|joint| &joint.joint_id == hip_joint_id)
            .ok_or_else(|| CoreError::Reference(format!("recovery_hip_joint:{hip_joint_id}")))?;
        let upper_body = spec
            .bodies
            .iter()
            .find(|body| body.body_id == limb.root_body_id)
            .ok_or_else(|| {
                CoreError::Reference(format!("recovery_upper_body:{}", limb.root_body_id))
            })?;
        let distal_body = spec
            .bodies
            .iter()
            .find(|body| body.body_id == limb.terminal_body_id)
            .ok_or_else(|| {
                CoreError::Reference(format!("recovery_distal_body:{}", limb.terminal_body_id))
            })?;
        let contact_site_id = &limb.ordered_contact_site_ids[0];
        let contact_site = spec
            .contact_sites
            .iter()
            .find(|site| &site.contact_site_id == contact_site_id)
            .ok_or_else(|| {
                CoreError::Reference(format!("recovery_contact_site:{contact_site_id}"))
            })?;
        let (upper_radius_m, upper_length_m) =
            capsule_dimensions(&upper_body.collision, &upper_body.body_id)?;
        let (distal_radius_m, distal_length_m) =
            capsule_dimensions(&distal_body.collision, &distal_body.body_id)?;

        let front = match limb.semantic_role.as_str() {
            "front_left" | "front_right" => true,
            "rear_left" | "rear_right" => false,
            other => {
                return Err(CoreError::Topology(format!(
                    "recovery_limb_semantic_role:{other}"
                )));
            }
        };
        let (hip_angle_rad, knee_angle_rad) = if front {
            (
                descriptor.canonical_prone_pose.front_hip_angle_rad,
                descriptor.canonical_prone_pose.front_knee_angle_rad,
            )
        } else {
            (
                descriptor.canonical_prone_pose.rear_hip_angle_rad,
                descriptor.canonical_prone_pose.rear_knee_angle_rad,
            )
        };

        let hip_center_x_m = hip_joint.anchor_parent_m.x;
        let hip_center_y_m = torso_center_y_m + hip_joint.anchor_parent_m.y;
        let knee_center_x_m = hip_center_x_m + upper_length_m * hip_angle_rad.sin();
        let knee_center_y_m = hip_center_y_m - upper_length_m * hip_angle_rad.cos();
        let distal_angle_rad = hip_angle_rad + knee_angle_rad;
        let distal_terminal_center_x_m = knee_center_x_m + distal_length_m * distal_angle_rad.sin();
        let distal_terminal_center_y_m = knee_center_y_m - distal_length_m * distal_angle_rad.cos();
        let upper_capsule_minimum_ground_clearance_m =
            hip_center_y_m.min(knee_center_y_m) - upper_radius_m;
        let distal_capsule_minimum_ground_clearance_m =
            knee_center_y_m.min(distal_terminal_center_y_m) - distal_radius_m;
        let contact_site_ground_clearance_m = distal_terminal_center_y_m - contact_site.radius_m;
        let minimum_ground_clearance_m = upper_capsule_minimum_ground_clearance_m
            .min(distal_capsule_minimum_ground_clearance_m)
            .min(contact_site_ground_clearance_m);
        let folds_outward_from_torso = if front {
            knee_center_x_m >= hip_center_x_m && distal_terminal_center_x_m >= knee_center_x_m
        } else {
            knee_center_x_m <= hip_center_x_m && distal_terminal_center_x_m <= knee_center_x_m
        };

        ordered_limb_geometry.push(RecoveryProneLimbGeometryV1 {
            limb_id: limb.limb_id.clone(),
            hip_joint_id: hip_joint_id.clone(),
            knee_joint_id: knee_joint_id.clone(),
            hip_angle_rad,
            knee_angle_rad,
            hip_center_x_m,
            hip_center_y_m,
            knee_center_x_m,
            knee_center_y_m,
            distal_terminal_center_x_m,
            distal_terminal_center_y_m,
            upper_capsule_radius_m: upper_radius_m,
            upper_capsule_length_m: upper_length_m,
            upper_capsule_minimum_ground_clearance_m,
            distal_capsule_radius_m: distal_radius_m,
            distal_capsule_length_m: distal_length_m,
            distal_capsule_minimum_ground_clearance_m,
            contact_site_radius_m: contact_site.radius_m,
            contact_site_ground_clearance_m,
            minimum_ground_clearance_m,
            folds_outward_from_torso,
            ground_nonpenetrating: minimum_ground_clearance_m >= 0.0,
        });
    }

    let minimum_limb_ground_clearance_m = ordered_limb_geometry
        .iter()
        .map(|limb| limb.minimum_ground_clearance_m)
        .fold(f64::INFINITY, f64::min);
    let minimum_ground_clearance_m =
        torso_ventral_ground_clearance_m.min(minimum_limb_ground_clearance_m);
    let all_limbs_fold_outward_from_torso = ordered_limb_geometry
        .iter()
        .all(|limb| limb.folds_outward_from_torso);
    let all_declared_collisions_ground_nonpenetrating = torso_ventral_ground_clearance_m >= 0.0
        && ordered_limb_geometry
            .iter()
            .all(|limb| limb.ground_nonpenetrating);
    let feasible =
        all_declared_collisions_ground_nonpenetrating && all_limbs_fold_outward_from_torso;

    Ok(RecoveryProneGeometryReceiptV1 {
        schema_version: RECOVERY_PRONE_GEOMETRY_RECEIPT_V1_VERSION.to_owned(),
        reference_pose_rule_id:
            "torso_ventral_tangent_y0_joint_angles_from_downward_link_reference_v1".to_owned(),
        coordinate_frame_id: spec.coordinate_frame_id.clone(),
        ground_plane_y_m: 0.0,
        feasibility_threshold_m: 0.0,
        threshold_provenance:
            "exact_rigid_shape_support_coordinate_must_be_greater_than_or_equal_to_ground_plane_y"
                .to_owned(),
        torso_center_y_m,
        torso_ventral_ground_clearance_m,
        ordered_limb_geometry,
        minimum_limb_ground_clearance_m,
        minimum_ground_clearance_m,
        all_limbs_fold_outward_from_torso,
        all_declared_collisions_ground_nonpenetrating,
        feasible,
        model_construction_count: 0,
        world_attempt_count: 0,
        world_build_count: 0,
        solver_step_count: 0,
        physics_state_modified: false,
    })
}

pub fn compile_recovery_morphology_v1(
    descriptor: RecoveryMorphologyDescriptorV1,
) -> Result<RecoveryMorphologyReceiptV1> {
    let base = compile_bounded_quadruped(descriptor.base_descriptor.clone())?;
    validate_descriptor(&descriptor, &base)?;
    let descriptor_sha256 = digest_serializable(&descriptor)?;
    let base_descriptor_sha256 = base.descriptor_sha256.clone();
    let base_morphology_spec_sha256 = base.morphology.morphology_spec_sha256.clone();
    let authority = QuadrupedJointAuthority {
        hip_anchor_parent_y_m: descriptor.joint_authority.hip_anchor_parent_y_m,
        hip_lower_limit_rad: -descriptor.joint_authority.hip_limit_magnitude_rad,
        hip_upper_limit_rad: descriptor.joint_authority.hip_limit_magnitude_rad,
        knee_lower_limit_rad: -descriptor.joint_authority.knee_limit_magnitude_rad,
        knee_upper_limit_rad: descriptor.joint_authority.knee_limit_magnitude_rad,
    };
    let morphology = compile_morphology(morphology_spec_with_joint_authority(
        &base.geometry,
        authority,
    ))?;
    let recovery_morphology_spec_sha256 = morphology.morphology_spec_sha256.clone();
    let prone_geometry = evaluate_prone_geometry(&descriptor, &base.geometry, &morphology)?;
    let support_status = if prone_geometry.feasible {
        RecoveryMorphologySupportStatusV1::SupportedExact
    } else {
        RecoveryMorphologySupportStatusV1::UnsupportedProneGeometryInfeasible
    };
    let refusal_reason = if prone_geometry.feasible {
        None
    } else if !prone_geometry.all_declared_collisions_ground_nonpenetrating {
        Some("canonical_prone_pose_ground_penetration".to_owned())
    } else {
        Some("canonical_prone_pose_not_outward_fold".to_owned())
    };

    Ok(RecoveryMorphologyReceiptV1 {
        schema_version: RECOVERY_MORPHOLOGY_RECEIPT_V1_VERSION.to_owned(),
        recovery_morphology_id: descriptor.recovery_morphology_id.clone(),
        support_status,
        refusal_reason,
        descriptor,
        descriptor_sha256,
        base_descriptor_sha256,
        base_morphology_spec_sha256,
        recovery_morphology_spec_sha256,
        geometry: base.geometry,
        morphology,
        claim_boundary: RecoveryMorphologyClaimBoundaryV1 {
            legacy_base_descriptor_preserved: true,
            legacy_base_morphology_spec_preserved: true,
            exact_prone_ground_geometry_evaluated: true,
            exact_prone_ground_geometry_supported: prone_geometry.feasible,
            arbitrary_morphology_recovery_claimed: false,
            controller_compatibility_claimed: false,
            recovery_behavior_claimed: false,
            prone_to_standing_claimed: false,
            cross_engine_recovery_claimed: false,
            physical_acceptance_authority: false,
            release_authority: false,
        },
        prone_geometry,
        model_construction_count: 0,
        world_attempt_count: 0,
        world_build_count: 0,
        solver_step_count: 0,
        physics_state_modified: false,
        physical_acceptance_authority: false,
        release_authority: false,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::actuator_profile::{
        R23D60_SELECTED_S169_DESCRIPTOR_SHA256, R23D60_SELECTED_S169_MORPHOLOGY_SPEC_SHA256,
        r23d60_selected_s169_descriptor,
    };

    #[test]
    fn exact_recovery_reference_is_zero_world_and_ground_feasible() {
        let receipt = compile_recovery_morphology_v1(
            RecoveryMorphologyDescriptorV1::exact_s169_reference(r23d60_selected_s169_descriptor()),
        )
        .unwrap();
        assert_eq!(
            receipt.support_status,
            RecoveryMorphologySupportStatusV1::SupportedExact
        );
        assert!(receipt.refusal_reason.is_none());
        assert!(receipt.prone_geometry.feasible);
        assert!(
            receipt
                .prone_geometry
                .all_declared_collisions_ground_nonpenetrating
        );
        assert!(receipt.prone_geometry.all_limbs_fold_outward_from_torso);
        assert!(receipt.prone_geometry.minimum_limb_ground_clearance_m > 0.0);
        assert!(receipt.prone_geometry.minimum_ground_clearance_m >= 0.0);
        assert_eq!(receipt.prone_geometry.ordered_limb_geometry.len(), 4);
        assert_eq!(
            receipt.base_descriptor_sha256,
            R23D60_SELECTED_S169_DESCRIPTOR_SHA256
        );
        assert_eq!(
            receipt.base_morphology_spec_sha256,
            R23D60_SELECTED_S169_MORPHOLOGY_SPEC_SHA256
        );
        assert_ne!(
            receipt.recovery_morphology_spec_sha256,
            receipt.base_morphology_spec_sha256
        );
        assert_eq!(receipt.world_build_count, 0);
        assert_eq!(receipt.solver_step_count, 0);
        assert!(!receipt.physics_state_modified);
        assert!(!receipt.claim_boundary.recovery_behavior_claimed);
        assert!(!receipt.physical_acceptance_authority);
        assert!(!receipt.release_authority);
    }

    #[test]
    fn legacy_joint_geometry_is_a_typed_recovery_refusal() {
        let mut descriptor =
            RecoveryMorphologyDescriptorV1::exact_s169_reference(r23d60_selected_s169_descriptor());
        descriptor.recovery_morphology_id = "legacy_geometry_refusal".to_owned();
        descriptor.joint_authority.hip_anchor_parent_y_m = -0.05;
        descriptor.joint_authority.hip_limit_magnitude_rad = 0.72;
        descriptor.canonical_prone_pose.front_hip_angle_rad = 0.72;
        descriptor.canonical_prone_pose.rear_hip_angle_rad = -0.72;
        let receipt = compile_recovery_morphology_v1(descriptor).unwrap();
        assert_eq!(
            receipt.support_status,
            RecoveryMorphologySupportStatusV1::UnsupportedProneGeometryInfeasible
        );
        assert_eq!(
            receipt.refusal_reason.as_deref(),
            Some("canonical_prone_pose_ground_penetration")
        );
        assert!(!receipt.prone_geometry.feasible);
        assert!(receipt.prone_geometry.minimum_ground_clearance_m < 0.0);
        assert!(!receipt.claim_boundary.exact_prone_ground_geometry_supported);
    }

    #[test]
    fn malformed_authority_and_identity_fail_closed() {
        let mut descriptor =
            RecoveryMorphologyDescriptorV1::exact_s169_reference(r23d60_selected_s169_descriptor());
        descriptor.canonical_prone_pose.front_hip_angle_rad = 1.61;
        assert!(matches!(
            compile_recovery_morphology_v1(descriptor),
            Err(CoreError::Schema(_))
        ));

        let mut same_identity =
            RecoveryMorphologyDescriptorV1::exact_s169_reference(r23d60_selected_s169_descriptor());
        same_identity.recovery_morphology_id = same_identity.base_descriptor.morphology_id.clone();
        assert!(matches!(
            compile_recovery_morphology_v1(same_identity),
            Err(CoreError::Identity(_))
        ));

        let mut nonfinite =
            RecoveryMorphologyDescriptorV1::exact_s169_reference(r23d60_selected_s169_descriptor());
        nonfinite.joint_authority.hip_anchor_parent_y_m = f64::NAN;
        assert!(matches!(
            compile_recovery_morphology_v1(nonfinite),
            Err(CoreError::NonFinite(_))
        ));
    }

    #[test]
    fn legacy_s169_compiler_identity_remains_exact() {
        let compiled = compile_bounded_quadruped(r23d60_selected_s169_descriptor()).unwrap();
        assert_eq!(
            compiled.descriptor_sha256,
            R23D60_SELECTED_S169_DESCRIPTOR_SHA256
        );
        assert_eq!(
            compiled.morphology.morphology_spec_sha256,
            R23D60_SELECTED_S169_MORPHOLOGY_SPEC_SHA256
        );
    }
}
