use std::collections::{HashMap, HashSet};
use std::fmt;

use serde::{Deserialize, Serialize};

use crate::canonical::digest_serializable;

pub type Result<T> = std::result::Result<T, CoreError>;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CoreError {
    Schema(String),
    NonFinite(String),
    Identity(String),
    Reference(String),
    Topology(String),
    Capability(String),
    Frame(String),
    Order(String),
    Time(String),
    Contact(String),
    Actuation(String),
    Digest(String),
    Serialization(String),
    Internal(String),
    BufferTooSmall(usize),
}

impl fmt::Display for CoreError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        let (code, detail) = match self {
            Self::Schema(detail) => ("SCHEMA_INVALID", detail.as_str()),
            Self::NonFinite(detail) => ("NONFINITE_VALUE", detail.as_str()),
            Self::Identity(detail) => ("IDENTITY_INVALID", detail.as_str()),
            Self::Reference(detail) => ("REFERENCE_INVALID", detail.as_str()),
            Self::Topology(detail) => ("TOPOLOGY_INVALID", detail.as_str()),
            Self::Capability(detail) => ("CAPABILITY_UNSUPPORTED", detail.as_str()),
            Self::Frame(detail) => ("FRAME_INVALID", detail.as_str()),
            Self::Order(detail) => ("ORDER_INVALID", detail.as_str()),
            Self::Time(detail) => ("TIME_INVALID", detail.as_str()),
            Self::Contact(detail) => ("CONTACT_INVALID", detail.as_str()),
            Self::Actuation(detail) => ("ACTUATION_INVALID", detail.as_str()),
            Self::Digest(detail) => ("DIGEST_INVALID", detail.as_str()),
            Self::Serialization(detail) => ("SERIALIZATION_FAILED", detail.as_str()),
            Self::Internal(detail) => ("INTERNAL_ERROR", detail.as_str()),
            Self::BufferTooSmall(_) => ("BUFFER_TOO_SMALL", "output capacity"),
        };
        write!(formatter, "{code}:{detail}")
    }
}

impl std::error::Error for CoreError {}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Vec3 {
    pub x: f64,
    pub y: f64,
    pub z: f64,
}

impl Vec3 {
    pub const ZERO: Self = Self {
        x: 0.0,
        y: 0.0,
        z: 0.0,
    };

    pub fn finite(self, field: &str) -> Result<()> {
        if self.x.is_finite() && self.y.is_finite() && self.z.is_finite() {
            Ok(())
        } else {
            Err(CoreError::NonFinite(field.to_owned()))
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case", deny_unknown_fields)]
pub enum CollisionShape {
    Box { size_m: Vec3 },
    Capsule { radius_m: f64, length_m: f64 },
    Sphere { radius_m: f64 },
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct BodySpec {
    pub body_id: String,
    pub parent_body_id: Option<String>,
    pub mass_kg: f64,
    pub center_of_mass_local_m: Vec3,
    pub inertia_diagonal_kg_m2: Vec3,
    pub collision: CollisionShape,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum JointType {
    Revolute,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct JointSpec {
    pub joint_id: String,
    pub parent_body_id: String,
    pub child_body_id: String,
    pub joint_type: JointType,
    pub anchor_parent_m: Vec3,
    pub anchor_child_m: Vec3,
    pub axis_parent_unit: Vec3,
    pub lower_limit_rad: f64,
    pub upper_limit_rad: f64,
    pub passive_damping_nms_per_rad: f64,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct LimbSpec {
    pub limb_id: String,
    pub semantic_role: String,
    pub root_body_id: String,
    pub terminal_body_id: String,
    pub ordered_joint_ids: Vec<String>,
    pub ordered_contact_site_ids: Vec<String>,
    pub nominal_phase_fraction: f64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ActuatorMode {
    PositionVelocity,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ActuatorSpec {
    pub actuator_id: String,
    pub joint_id: String,
    pub mode: ActuatorMode,
    pub minimum_target_position_rad: f64,
    pub maximum_target_position_rad: f64,
    pub maximum_target_speed_rad_s: f64,
    pub maximum_impulse_nms: f64,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ContactMaterial {
    pub material_id: String,
    pub friction_coefficient: f64,
    pub restitution: f64,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ContactSiteSpec {
    pub contact_site_id: String,
    pub body_id: String,
    pub local_center_m: Vec3,
    pub radius_m: f64,
    pub material: ContactMaterial,
    pub can_support: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct MorphologySpec {
    pub schema_version: String,
    pub coordinate_frame_id: String,
    pub topology_family: String,
    pub bodies: Vec<BodySpec>,
    pub joints: Vec<JointSpec>,
    pub limbs: Vec<LimbSpec>,
    pub actuators: Vec<ActuatorSpec>,
    pub contact_sites: Vec<ContactSiteSpec>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CompiledMorphology {
    pub schema_version: String,
    pub morphology_spec: MorphologySpec,
    pub morphology_spec_sha256: String,
    pub ordered_body_ids: Vec<String>,
    pub ordered_joint_ids: Vec<String>,
    pub ordered_limb_ids: Vec<String>,
    pub ordered_actuator_ids: Vec<String>,
    pub ordered_contact_site_ids: Vec<String>,
    pub total_mass_kg: f64,
    pub world_build_count: u32,
    pub controller_authority: bool,
    pub physical_acceptance_authority: bool,
}

fn valid_id(value: &str) -> bool {
    let mut characters = value.chars();
    matches!(characters.next(), Some('a'..='z'))
        && characters.all(|character| {
            character.is_ascii_lowercase() || character.is_ascii_digit() || character == '_'
        })
}

fn require_id(id: &str, field: &str) -> Result<()> {
    if valid_id(id) {
        Ok(())
    } else {
        Err(CoreError::Identity(format!("{field}:{id}")))
    }
}

fn require_finite(value: f64, field: &str) -> Result<()> {
    if value.is_finite() {
        Ok(())
    } else {
        Err(CoreError::NonFinite(field.to_owned()))
    }
}

fn insert_unique(set: &mut HashSet<String>, id: &str, field: &str) -> Result<()> {
    require_id(id, field)?;
    if set.insert(id.to_owned()) {
        Ok(())
    } else {
        Err(CoreError::Identity(format!("duplicate_{field}:{id}")))
    }
}

pub fn compile_morphology(spec: MorphologySpec) -> Result<CompiledMorphology> {
    if spec.schema_version != "sporespore_morphology_spec_v1" {
        return Err(CoreError::Schema("morphology_spec_version".to_owned()));
    }
    if spec.coordinate_frame_id != "right_handed_x_forward_y_up_z_right_si_v1" {
        return Err(CoreError::Schema("coordinate_frame_id".to_owned()));
    }
    require_id(&spec.topology_family, "topology_family")?;
    if spec.bodies.is_empty()
        || spec.joints.is_empty()
        || spec.limbs.is_empty()
        || spec.actuators.is_empty()
        || spec.contact_sites.is_empty()
    {
        return Err(CoreError::Topology("empty_required_collection".to_owned()));
    }

    let mut body_ids = HashSet::new();
    let mut ordered_body_ids = Vec::with_capacity(spec.bodies.len());
    let mut total_mass_kg = 0.0;
    let mut roots = 0;
    for body in &spec.bodies {
        insert_unique(&mut body_ids, &body.body_id, "body_id")?;
        if body.parent_body_id.is_none() {
            roots += 1;
        }
        require_finite(body.mass_kg, "body.mass_kg")?;
        if body.mass_kg <= 0.0 {
            return Err(CoreError::Topology(format!(
                "nonpositive_body_mass:{}",
                body.body_id
            )));
        }
        body.center_of_mass_local_m
            .finite("body.center_of_mass_local_m")?;
        body.inertia_diagonal_kg_m2
            .finite("body.inertia_diagonal_kg_m2")?;
        if body.inertia_diagonal_kg_m2.x <= 0.0
            || body.inertia_diagonal_kg_m2.y <= 0.0
            || body.inertia_diagonal_kg_m2.z <= 0.0
        {
            return Err(CoreError::Topology(format!(
                "nonpositive_inertia:{}",
                body.body_id
            )));
        }
        match &body.collision {
            CollisionShape::Box { size_m } => {
                (*size_m).finite("body.collision.box")?;
                if size_m.x <= 0.0 || size_m.y <= 0.0 || size_m.z <= 0.0 {
                    return Err(CoreError::Topology("box_size".to_owned()));
                }
            }
            CollisionShape::Capsule { radius_m, length_m } => {
                require_finite(*radius_m, "capsule.radius_m")?;
                require_finite(*length_m, "capsule.length_m")?;
                if *radius_m <= 0.0 || *length_m <= 0.0 {
                    return Err(CoreError::Topology("capsule_size".to_owned()));
                }
            }
            CollisionShape::Sphere { radius_m } => {
                require_finite(*radius_m, "sphere.radius_m")?;
                if *radius_m <= 0.0 {
                    return Err(CoreError::Topology("sphere_size".to_owned()));
                }
            }
        }
        ordered_body_ids.push(body.body_id.clone());
        total_mass_kg += body.mass_kg;
    }
    if roots != 1 {
        return Err(CoreError::Topology(format!("root_body_count:{roots}")));
    }
    let parent_by_body: HashMap<_, _> = spec
        .bodies
        .iter()
        .map(|body| (body.body_id.as_str(), body.parent_body_id.as_deref()))
        .collect();
    for body in &spec.bodies {
        if let Some(parent) = &body.parent_body_id {
            if !body_ids.contains(parent) || parent == &body.body_id {
                return Err(CoreError::Reference(format!(
                    "body_parent:{}",
                    body.body_id
                )));
            }
            let mut cursor = Some(parent.as_str());
            let mut visited = HashSet::new();
            while let Some(current) = cursor {
                if !visited.insert(current) {
                    return Err(CoreError::Topology("body_parent_cycle".to_owned()));
                }
                cursor = parent_by_body.get(current).copied().flatten();
            }
        }
    }

    let mut joint_ids = HashSet::new();
    let mut ordered_joint_ids = Vec::with_capacity(spec.joints.len());
    for joint in &spec.joints {
        insert_unique(&mut joint_ids, &joint.joint_id, "joint_id")?;
        if !body_ids.contains(&joint.parent_body_id)
            || !body_ids.contains(&joint.child_body_id)
            || joint.parent_body_id == joint.child_body_id
        {
            return Err(CoreError::Reference(format!("joint:{}", joint.joint_id)));
        }
        joint.anchor_parent_m.finite("joint.anchor_parent_m")?;
        joint.anchor_child_m.finite("joint.anchor_child_m")?;
        joint.axis_parent_unit.finite("joint.axis_parent_unit")?;
        for (value, field) in [
            (joint.lower_limit_rad, "joint.lower_limit_rad"),
            (joint.upper_limit_rad, "joint.upper_limit_rad"),
            (
                joint.passive_damping_nms_per_rad,
                "joint.passive_damping_nms_per_rad",
            ),
        ] {
            require_finite(value, field)?;
        }
        if joint.lower_limit_rad >= joint.upper_limit_rad {
            return Err(CoreError::Topology(format!(
                "joint_limits:{}",
                joint.joint_id
            )));
        }
        let norm_squared = joint.axis_parent_unit.x * joint.axis_parent_unit.x
            + joint.axis_parent_unit.y * joint.axis_parent_unit.y
            + joint.axis_parent_unit.z * joint.axis_parent_unit.z;
        if (norm_squared - 1.0).abs() > 1.0e-9 {
            return Err(CoreError::Topology(format!(
                "joint_axis_not_unit:{}",
                joint.joint_id
            )));
        }
        ordered_joint_ids.push(joint.joint_id.clone());
    }

    let mut contact_ids = HashSet::new();
    let mut ordered_contact_site_ids = Vec::with_capacity(spec.contact_sites.len());
    for contact in &spec.contact_sites {
        insert_unique(
            &mut contact_ids,
            &contact.contact_site_id,
            "contact_site_id",
        )?;
        if !body_ids.contains(&contact.body_id) {
            return Err(CoreError::Reference(format!(
                "contact_body:{}",
                contact.contact_site_id
            )));
        }
        contact.local_center_m.finite("contact.local_center_m")?;
        require_finite(contact.radius_m, "contact.radius_m")?;
        require_id(&contact.material.material_id, "material_id")?;
        require_finite(
            contact.material.friction_coefficient,
            "material.friction_coefficient",
        )?;
        require_finite(contact.material.restitution, "material.restitution")?;
        if contact.radius_m <= 0.0
            || contact.material.friction_coefficient < 0.0
            || !(0.0..=1.0).contains(&contact.material.restitution)
        {
            return Err(CoreError::Topology(format!(
                "contact_material:{}",
                contact.contact_site_id
            )));
        }
        ordered_contact_site_ids.push(contact.contact_site_id.clone());
    }

    let mut limb_ids = HashSet::new();
    let mut ordered_limb_ids = Vec::with_capacity(spec.limbs.len());
    for limb in &spec.limbs {
        insert_unique(&mut limb_ids, &limb.limb_id, "limb_id")?;
        require_id(&limb.semantic_role, "semantic_role")?;
        if !body_ids.contains(&limb.root_body_id)
            || !body_ids.contains(&limb.terminal_body_id)
            || limb.ordered_joint_ids.is_empty()
            || limb.ordered_contact_site_ids.is_empty()
            || limb
                .ordered_joint_ids
                .iter()
                .any(|id| !joint_ids.contains(id))
            || limb
                .ordered_contact_site_ids
                .iter()
                .any(|id| !contact_ids.contains(id))
        {
            return Err(CoreError::Reference(format!("limb:{}", limb.limb_id)));
        }
        require_finite(limb.nominal_phase_fraction, "limb.nominal_phase_fraction")?;
        if !(0.0..1.0).contains(&limb.nominal_phase_fraction) {
            return Err(CoreError::Topology(format!("limb_phase:{}", limb.limb_id)));
        }
        ordered_limb_ids.push(limb.limb_id.clone());
    }

    let mut actuator_ids = HashSet::new();
    let mut ordered_actuator_ids = Vec::with_capacity(spec.actuators.len());
    for actuator in &spec.actuators {
        insert_unique(&mut actuator_ids, &actuator.actuator_id, "actuator_id")?;
        if !joint_ids.contains(&actuator.joint_id) {
            return Err(CoreError::Reference(format!(
                "actuator_joint:{}",
                actuator.actuator_id
            )));
        }
        for (value, field) in [
            (
                actuator.minimum_target_position_rad,
                "actuator.minimum_target_position_rad",
            ),
            (
                actuator.maximum_target_position_rad,
                "actuator.maximum_target_position_rad",
            ),
            (
                actuator.maximum_target_speed_rad_s,
                "actuator.maximum_target_speed_rad_s",
            ),
            (actuator.maximum_impulse_nms, "actuator.maximum_impulse_nms"),
        ] {
            require_finite(value, field)?;
        }
        if actuator.minimum_target_position_rad >= actuator.maximum_target_position_rad
            || actuator.maximum_target_speed_rad_s <= 0.0
            || actuator.maximum_impulse_nms <= 0.0
        {
            return Err(CoreError::Topology(format!(
                "actuator_limits:{}",
                actuator.actuator_id
            )));
        }
        ordered_actuator_ids.push(actuator.actuator_id.clone());
    }

    let morphology_spec_sha256 = digest_serializable(&spec)?;
    Ok(CompiledMorphology {
        schema_version: "sporespore_compiled_morphology_v1".to_owned(),
        morphology_spec: spec,
        morphology_spec_sha256,
        ordered_body_ids,
        ordered_joint_ids,
        ordered_limb_ids,
        ordered_actuator_ids,
        ordered_contact_site_ids,
        total_mass_kg,
        world_build_count: 0,
        controller_authority: false,
        physical_acceptance_authority: false,
    })
}
