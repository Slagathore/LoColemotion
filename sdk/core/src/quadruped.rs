use serde::{Deserialize, Serialize};

use crate::canonical::digest_serializable;
use crate::controller::{Candidate35Profile, candidate35_profile};
use crate::schema::{
    ActuatorMode, ActuatorSpec, BodySpec, CollisionShape, CompiledMorphology, ContactMaterial,
    ContactSiteSpec, CoreError, JointSpec, JointType, LimbSpec, MorphologySpec, Result, Vec3,
    compile_morphology,
};

pub const BOUNDED_QUADRUPED_DESCRIPTOR_VERSION: &str = "sporespore_bounded_quadruped_descriptor_v1";
pub const BOUNDED_QUADRUPED_DOMAIN_ID: &str = "gq15_six_axis_closed_box_v1";
pub const REFERENCE_UPPER_LENGTH_FRACTION: f64 = 18.0 / 35.0;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct BoundedQuadrupedDescriptor {
    pub schema_version: String,
    pub morphology_id: String,
    pub torso_length_scale: f64,
    pub torso_width_scale: f64,
    pub upper_length_fraction: f64,
    pub hip_span_scale: f64,
    pub foot_radius_scale: f64,
    pub front_limb_mass_scale: f64,
}

impl BoundedQuadrupedDescriptor {
    pub fn reference(morphology_id: impl Into<String>) -> Self {
        Self {
            schema_version: BOUNDED_QUADRUPED_DESCRIPTOR_VERSION.to_owned(),
            morphology_id: morphology_id.into(),
            torso_length_scale: 1.0,
            torso_width_scale: 1.0,
            upper_length_fraction: REFERENCE_UPPER_LENGTH_FRACTION,
            hip_span_scale: 1.0,
            foot_radius_scale: 1.0,
            front_limb_mass_scale: 1.0,
        }
    }

    pub fn normalized_absolute_deviations(&self) -> [f64; 6] {
        [
            ((self.torso_length_scale - 1.0) / 0.10).abs(),
            ((self.torso_width_scale - 1.0) / 0.10).abs(),
            ((self.upper_length_fraction - REFERENCE_UPPER_LENGTH_FRACTION) / 0.05).abs(),
            ((self.hip_span_scale - 1.0) / 0.10).abs(),
            ((self.foot_radius_scale - 1.0) / 0.10).abs(),
            ((self.front_limb_mass_scale - 1.0) / 0.10).abs(),
        ]
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct DerivedQuadrupedGeometry {
    pub torso_size_m: Vec3,
    pub initial_torso_center_y_m: f64,
    pub upper_length_m: f64,
    pub lower_length_m: f64,
    pub foot_radius_m: f64,
    pub front_hip_x_m: f64,
    pub rear_hip_x_m: f64,
    pub left_hip_z_m: f64,
    pub right_hip_z_m: f64,
    pub front_limb_mass_multiplier: f64,
    pub rear_limb_mass_multiplier: f64,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CompiledQuadruped {
    pub schema_version: String,
    pub domain_id: String,
    pub morphology_id: String,
    pub descriptor: BoundedQuadrupedDescriptor,
    pub descriptor_sha256: String,
    pub normalized_absolute_deviations: [f64; 6],
    pub morphology_interaction_score: f64,
    pub geometry: DerivedQuadrupedGeometry,
    pub morphology: CompiledMorphology,
    pub candidate35_profile: Candidate35Profile,
    pub world_build_count: u32,
    pub physical_acceptance_authority: bool,
}

fn semantic_id_valid(value: &str) -> bool {
    let mut characters = value.chars();
    matches!(characters.next(), Some('a'..='z'))
        && characters.all(|character| {
            character.is_ascii_lowercase() || character.is_ascii_digit() || character == '_'
        })
}

fn require_closed(value: f64, minimum: f64, maximum: f64, field: &str) -> Result<()> {
    if !value.is_finite() {
        return Err(CoreError::NonFinite(field.to_owned()));
    }
    if !(minimum..=maximum).contains(&value) {
        return Err(CoreError::Schema(format!("{field}_out_of_range")));
    }
    Ok(())
}

pub fn validate_bounded_quadruped_descriptor(
    descriptor: &BoundedQuadrupedDescriptor,
) -> Result<()> {
    if descriptor.schema_version != BOUNDED_QUADRUPED_DESCRIPTOR_VERSION {
        return Err(CoreError::Schema(
            "bounded_quadruped_descriptor_version".to_owned(),
        ));
    }
    if !semantic_id_valid(&descriptor.morphology_id) {
        return Err(CoreError::Identity(format!(
            "morphology_id:{}",
            descriptor.morphology_id
        )));
    }
    require_closed(
        descriptor.torso_length_scale,
        0.90,
        1.10,
        "torso_length_scale",
    )?;
    require_closed(
        descriptor.torso_width_scale,
        0.90,
        1.10,
        "torso_width_scale",
    )?;
    require_closed(
        descriptor.upper_length_fraction,
        0.48,
        0.55,
        "upper_length_fraction",
    )?;
    require_closed(descriptor.hip_span_scale, 0.90, 1.10, "hip_span_scale")?;
    require_closed(
        descriptor.foot_radius_scale,
        0.90,
        1.10,
        "foot_radius_scale",
    )?;
    require_closed(
        descriptor.front_limb_mass_scale,
        0.90,
        1.10,
        "front_limb_mass_scale",
    )
}

pub fn interaction_score(descriptor: &BoundedQuadrupedDescriptor) -> Result<f64> {
    validate_bounded_quadruped_descriptor(descriptor)?;
    let deviations = descriptor.normalized_absolute_deviations();
    let mut sum = 0.0;
    for first in 0..deviations.len() {
        for second in (first + 1)..deviations.len() {
            sum += deviations[first] * deviations[second];
        }
    }
    Ok(sum.clamp(0.0, 1.0))
}

fn box_inertia(mass_kg: f64, size_m: Vec3) -> Vec3 {
    Vec3 {
        x: mass_kg * (size_m.y.powi(2) + size_m.z.powi(2)) / 12.0,
        y: mass_kg * (size_m.x.powi(2) + size_m.z.powi(2)) / 12.0,
        z: mass_kg * (size_m.x.powi(2) + size_m.y.powi(2)) / 12.0,
    }
}

fn capsule_proxy_inertia(mass_kg: f64, radius_m: f64, length_m: f64) -> Vec3 {
    Vec3 {
        x: mass_kg * (3.0 * radius_m.powi(2) + length_m.powi(2)) / 12.0,
        y: 0.5 * mass_kg * radius_m.powi(2),
        z: mass_kg * (3.0 * radius_m.powi(2) + length_m.powi(2)) / 12.0,
    }
}

fn leg_body(
    body_id: &str,
    parent_body_id: &str,
    mass_kg: f64,
    length_m: f64,
    radius_m: f64,
) -> BodySpec {
    BodySpec {
        body_id: body_id.to_owned(),
        parent_body_id: Some(parent_body_id.to_owned()),
        mass_kg,
        center_of_mass_local_m: Vec3::ZERO,
        inertia_diagonal_kg_m2: capsule_proxy_inertia(mass_kg, radius_m, length_m),
        collision: CollisionShape::Capsule { radius_m, length_m },
    }
}

fn actuator(
    actuator_id: String,
    joint_id: String,
    lower: f64,
    upper: f64,
    maximum_impulse_nms: f64,
) -> ActuatorSpec {
    ActuatorSpec {
        actuator_id,
        joint_id,
        mode: ActuatorMode::PositionVelocity,
        minimum_target_position_rad: lower,
        maximum_target_position_rad: upper,
        maximum_target_speed_rad_s: 3.5,
        maximum_impulse_nms,
    }
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub(crate) struct QuadrupedJointAuthority {
    pub hip_anchor_parent_y_m: f64,
    pub hip_lower_limit_rad: f64,
    pub hip_upper_limit_rad: f64,
    pub knee_lower_limit_rad: f64,
    pub knee_upper_limit_rad: f64,
}

const LEGACY_JOINT_AUTHORITY: QuadrupedJointAuthority = QuadrupedJointAuthority {
    hip_anchor_parent_y_m: -0.05,
    hip_lower_limit_rad: -0.72,
    hip_upper_limit_rad: 0.72,
    knee_lower_limit_rad: -0.15,
    knee_upper_limit_rad: 1.10,
};

pub(crate) fn derive_geometry(descriptor: &BoundedQuadrupedDescriptor) -> DerivedQuadrupedGeometry {
    DerivedQuadrupedGeometry {
        torso_size_m: Vec3 {
            x: 0.50 * descriptor.torso_length_scale,
            y: 0.12,
            z: 0.32 * descriptor.torso_width_scale,
        },
        initial_torso_center_y_m: 0.40 + 0.04 * descriptor.foot_radius_scale,
        upper_length_m: 0.35 * descriptor.upper_length_fraction,
        lower_length_m: 0.35 * (1.0 - descriptor.upper_length_fraction),
        foot_radius_m: 0.04 * descriptor.foot_radius_scale,
        front_hip_x_m: 0.20 * descriptor.hip_span_scale,
        rear_hip_x_m: -0.20 * descriptor.hip_span_scale,
        left_hip_z_m: -0.18 * descriptor.hip_span_scale,
        right_hip_z_m: 0.18 * descriptor.hip_span_scale,
        front_limb_mass_multiplier: descriptor.front_limb_mass_scale,
        rear_limb_mass_multiplier: 2.0 - descriptor.front_limb_mass_scale,
    }
}

pub(crate) fn morphology_spec_with_joint_authority(
    geometry: &DerivedQuadrupedGeometry,
    joint_authority: QuadrupedJointAuthority,
) -> MorphologySpec {
    let torso = BodySpec {
        body_id: "torso".to_owned(),
        parent_body_id: None,
        mass_kg: 3.0,
        center_of_mass_local_m: Vec3::ZERO,
        inertia_diagonal_kg_m2: box_inertia(3.0, geometry.torso_size_m),
        collision: CollisionShape::Box {
            size_m: geometry.torso_size_m,
        },
    };
    let definitions = [
        (
            "front_left",
            geometry.front_hip_x_m,
            geometry.left_hip_z_m,
            true,
            0.25,
        ),
        (
            "front_right",
            geometry.front_hip_x_m,
            geometry.right_hip_z_m,
            true,
            0.75,
        ),
        (
            "rear_left",
            geometry.rear_hip_x_m,
            geometry.left_hip_z_m,
            false,
            0.0,
        ),
        (
            "rear_right",
            geometry.rear_hip_x_m,
            geometry.right_hip_z_m,
            false,
            0.50,
        ),
    ];
    let mut bodies = vec![torso];
    let mut joints = Vec::with_capacity(8);
    let mut limbs = Vec::with_capacity(4);
    let mut actuators = Vec::with_capacity(8);
    let mut contact_sites = Vec::with_capacity(4);

    for (limb_id, hip_x, hip_z, front, phase) in definitions {
        let upper_id = format!("{limb_id}_upper");
        let distal_id = format!("{limb_id}_distal");
        let hip_joint_id = format!("{limb_id}_hip");
        let knee_joint_id = format!("{limb_id}_knee");
        let contact_id = format!("{limb_id}_foot");
        let mass_multiplier = if front {
            geometry.front_limb_mass_multiplier
        } else {
            geometry.rear_limb_mass_multiplier
        };
        let upper_mass = 0.25 * mass_multiplier;
        let distal_mass = 0.18 * mass_multiplier;
        bodies.push(leg_body(
            &upper_id,
            "torso",
            upper_mass,
            geometry.upper_length_m,
            0.0225,
        ));
        bodies.push(leg_body(
            &distal_id,
            &upper_id,
            distal_mass,
            geometry.lower_length_m,
            geometry.foot_radius_m,
        ));
        joints.push(JointSpec {
            joint_id: hip_joint_id.clone(),
            parent_body_id: "torso".to_owned(),
            child_body_id: upper_id.clone(),
            joint_type: JointType::Revolute,
            anchor_parent_m: Vec3 {
                x: hip_x,
                y: joint_authority.hip_anchor_parent_y_m,
                z: hip_z,
            },
            anchor_child_m: Vec3 {
                x: 0.0,
                y: geometry.upper_length_m / 2.0,
                z: 0.0,
            },
            axis_parent_unit: Vec3 {
                x: 0.0,
                y: 0.0,
                z: 1.0,
            },
            lower_limit_rad: joint_authority.hip_lower_limit_rad,
            upper_limit_rad: joint_authority.hip_upper_limit_rad,
            passive_damping_nms_per_rad: 0.0,
        });
        joints.push(JointSpec {
            joint_id: knee_joint_id.clone(),
            parent_body_id: upper_id.clone(),
            child_body_id: distal_id.clone(),
            joint_type: JointType::Revolute,
            anchor_parent_m: Vec3 {
                x: 0.0,
                y: -geometry.upper_length_m / 2.0,
                z: 0.0,
            },
            anchor_child_m: Vec3 {
                x: 0.0,
                y: geometry.lower_length_m / 2.0,
                z: 0.0,
            },
            axis_parent_unit: Vec3 {
                x: 0.0,
                y: 0.0,
                z: 1.0,
            },
            lower_limit_rad: joint_authority.knee_lower_limit_rad,
            upper_limit_rad: joint_authority.knee_upper_limit_rad,
            passive_damping_nms_per_rad: 0.0,
        });
        contact_sites.push(ContactSiteSpec {
            contact_site_id: contact_id.clone(),
            body_id: distal_id.clone(),
            local_center_m: Vec3 {
                x: 0.0,
                y: -geometry.lower_length_m / 2.0,
                z: 0.0,
            },
            radius_m: geometry.foot_radius_m,
            material: ContactMaterial {
                material_id: "reference_rough_absorbent".to_owned(),
                friction_coefficient: 1.8,
                restitution: 0.0,
            },
            can_support: true,
        });
        limbs.push(LimbSpec {
            limb_id: limb_id.to_owned(),
            semantic_role: limb_id.to_owned(),
            root_body_id: upper_id.clone(),
            terminal_body_id: distal_id,
            ordered_joint_ids: vec![hip_joint_id.clone(), knee_joint_id.clone()],
            ordered_contact_site_ids: vec![contact_id],
            nominal_phase_fraction: phase,
        });
        actuators.push(actuator(
            format!("{limb_id}_hip_motor"),
            hip_joint_id,
            joint_authority.hip_lower_limit_rad,
            joint_authority.hip_upper_limit_rad,
            0.055 * mass_multiplier,
        ));
        actuators.push(actuator(
            format!("{limb_id}_knee_motor"),
            knee_joint_id,
            joint_authority.knee_lower_limit_rad,
            joint_authority.knee_upper_limit_rad,
            0.045 * mass_multiplier,
        ));
    }

    MorphologySpec {
        schema_version: "sporespore_morphology_spec_v1".to_owned(),
        coordinate_frame_id: "right_handed_x_forward_y_up_z_right_si_v1".to_owned(),
        topology_family: "bounded_quadruped_gq15".to_owned(),
        bodies,
        joints,
        limbs,
        actuators,
        contact_sites,
    }
}

fn morphology_spec(
    _descriptor: &BoundedQuadrupedDescriptor,
    geometry: &DerivedQuadrupedGeometry,
) -> MorphologySpec {
    morphology_spec_with_joint_authority(geometry, LEGACY_JOINT_AUTHORITY)
}

pub fn compile_bounded_quadruped(
    descriptor: BoundedQuadrupedDescriptor,
) -> Result<CompiledQuadruped> {
    validate_bounded_quadruped_descriptor(&descriptor)?;
    let descriptor_sha256 = digest_serializable(&descriptor)?;
    let normalized_absolute_deviations = descriptor.normalized_absolute_deviations();
    let morphology_interaction_score = interaction_score(&descriptor)?;
    let geometry = derive_geometry(&descriptor);
    let morphology = compile_morphology(morphology_spec(&descriptor, &geometry))?;
    let candidate35_profile = candidate35_profile(&descriptor)?;
    Ok(CompiledQuadruped {
        schema_version: "sporespore_compiled_bounded_quadruped_v1".to_owned(),
        domain_id: BOUNDED_QUADRUPED_DOMAIN_ID.to_owned(),
        morphology_id: descriptor.morphology_id.clone(),
        descriptor,
        descriptor_sha256,
        normalized_absolute_deviations,
        morphology_interaction_score,
        geometry,
        morphology,
        candidate35_profile,
        world_build_count: 0,
        physical_acceptance_authority: false,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reference_descriptor_compiles_without_world_authority() {
        let compiled =
            compile_bounded_quadruped(BoundedQuadrupedDescriptor::reference("reference_q"))
                .unwrap();
        assert_eq!(compiled.morphology.ordered_body_ids.len(), 9);
        assert_eq!(compiled.morphology.ordered_joint_ids.len(), 8);
        assert_eq!(compiled.morphology.ordered_limb_ids.len(), 4);
        assert_eq!(compiled.morphology.ordered_actuator_ids.len(), 8);
        assert_eq!(compiled.morphology.ordered_contact_site_ids.len(), 4);
        assert_eq!(compiled.morphology_interaction_score, 0.0);
        assert_eq!(compiled.morphology.total_mass_kg, 4.72);
        assert_eq!(compiled.world_build_count, 0);
        assert!(!compiled.physical_acceptance_authority);
    }

    #[test]
    fn every_closed_corner_compiles() {
        for mask in 0_u32..64 {
            let descriptor = BoundedQuadrupedDescriptor {
                schema_version: BOUNDED_QUADRUPED_DESCRIPTOR_VERSION.to_owned(),
                morphology_id: format!("corner_{mask}"),
                torso_length_scale: if mask & 1 == 0 { 0.90 } else { 1.10 },
                torso_width_scale: if mask & 2 == 0 { 0.90 } else { 1.10 },
                upper_length_fraction: if mask & 4 == 0 { 0.48 } else { 0.55 },
                hip_span_scale: if mask & 8 == 0 { 0.90 } else { 1.10 },
                foot_radius_scale: if mask & 16 == 0 { 0.90 } else { 1.10 },
                front_limb_mass_scale: if mask & 32 == 0 { 0.90 } else { 1.10 },
            };
            let compiled = compile_bounded_quadruped(descriptor).unwrap();
            assert!((compiled.morphology.total_mass_kg - 4.72).abs() < 1.0e-12);
        }
    }

    #[test]
    fn malformed_and_out_of_domain_descriptors_fail_closed() {
        let mut bad_id = BoundedQuadrupedDescriptor::reference("Bad-ID");
        assert!(matches!(
            compile_bounded_quadruped(bad_id.clone()),
            Err(CoreError::Identity(_))
        ));
        bad_id.morphology_id = "valid_id".to_owned();
        bad_id.upper_length_fraction = 0.551;
        assert!(matches!(
            compile_bounded_quadruped(bad_id),
            Err(CoreError::Schema(_))
        ));
        let mut nonfinite = BoundedQuadrupedDescriptor::reference("nonfinite");
        nonfinite.foot_radius_scale = f64::NAN;
        assert!(matches!(
            compile_bounded_quadruped(nonfinite),
            Err(CoreError::NonFinite(_))
        ));
    }
}
