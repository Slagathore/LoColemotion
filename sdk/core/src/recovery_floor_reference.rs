//! Explicit static horizontal surface context for the distinct recovery policy.
//! The adapter binds this declaration to construction; the pure core verifies
//! shape and continuity, not native geometry. No engine identity or force input.
use serde::{Deserialize, Deserializer, Serialize};

use crate::canonical::digest_serializable;
use crate::runtime::BalancedWaveControllerMemory;
use crate::schema::{CoreError, Result};

pub const MODE_ID: &str = "explicit_horizontal_floor_bounded_support_reference_slew_v1";
pub const MEMORY_VERSION: &str = "sporespore_balanced_wave_recovery_floor_support_memory_v1";
pub const FRAME_ID: &str = "sporespore_state_world_y_up_metres_v1";

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct FloorReference {
    pub schema_version: String,
    pub frame_id: String,
    pub surface_id: String,
    pub source_instance_id: String,
    pub source_kind: String,
    pub geometry_source_sha256: String,
    pub height_world_m: f64,
}

impl FloorReference {
    pub fn validate(&self) -> Result<()> {
        if self.schema_version != "sporespore_static_horizontal_floor_reference_v1"
            || self.frame_id != FRAME_ID
            || self.source_kind != "declared_static_horizontal_surface"
            || self.surface_id.trim().is_empty()
            || self.source_instance_id.trim().is_empty()
        {
            return Err(CoreError::Frame(
                "floor_reference_identity_or_frame".to_owned(),
            ));
        }
        let hash = self
            .geometry_source_sha256
            .strip_prefix("sha256:")
            .unwrap_or("");
        if hash.len() != 64
            || !hash
                .bytes()
                .all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
        {
            return Err(CoreError::Identity(
                "floor_reference_geometry_source".to_owned(),
            ));
        }
        if !self.height_world_m.is_finite() {
            return Err(CoreError::NonFinite("floor_reference_height".to_owned()));
        }
        Ok(())
    }
}

/// Missing context stays absent; an explicit null is not a valid context.
pub(crate) fn deserialize_present<'de, D: Deserializer<'de>>(
    d: D,
) -> std::result::Result<Option<FloorReference>, D::Error> {
    FloorReference::deserialize(d).map(Some)
}

pub(crate) fn validate_context(
    selected: bool,
    memory: &BalancedWaveControllerMemory,
    floor: Option<&FloorReference>,
) -> Result<Option<String>> {
    if !selected {
        return if floor.is_some() || memory.floor_reference_sha256.is_some() {
            Err(CoreError::Identity(
                "floor_reference_crossed_policy".to_owned(),
            ))
        } else {
            Ok(None)
        };
    }
    let floor = floor.ok_or_else(|| CoreError::Frame("floor_reference_missing".to_owned()))?;
    floor.validate()?;
    let hash = digest_serializable(floor)?;
    match (
        memory.last_semantic_step,
        memory.floor_reference_sha256.as_deref(),
    ) {
        (None, None) => Ok(Some(hash)),
        (Some(_), Some(previous)) if previous == hash => Ok(Some(hash)),
        _ => Err(CoreError::Identity(
            "floor_reference_session_drift".to_owned(),
        )),
    }
}
