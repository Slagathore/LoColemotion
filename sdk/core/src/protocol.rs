use std::collections::HashSet;

use serde::{Deserialize, Serialize};

use crate::schema::{ActuatorMode, CompiledMorphology, CoreError, Result, Vec3};

pub const STATE_FRAME_VERSION: &str = "sporespore_state_frame_v1";
pub const MOTION_COMMAND_VERSION: &str = "sporespore_motion_command_v2";
pub const ACTUATION_FRAME_VERSION: &str = "sporespore_actuation_frame_v1";

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Quaternion {
    pub x: f64,
    pub y: f64,
    pub z: f64,
    pub w: f64,
}

impl Quaternion {
    pub const IDENTITY: Self = Self {
        x: 0.0,
        y: 0.0,
        z: 0.0,
        w: 1.0,
    };

    pub fn validate(self, field: &str) -> Result<()> {
        if ![self.x, self.y, self.z, self.w]
            .into_iter()
            .all(f64::is_finite)
        {
            return Err(CoreError::NonFinite(field.to_owned()));
        }
        let norm_squared = self.x * self.x + self.y * self.y + self.z * self.z + self.w * self.w;
        if (norm_squared - 1.0).abs() > 1.0e-9 {
            return Err(CoreError::Frame(format!("{field}_quaternion_not_unit")));
        }
        Ok(())
    }

    /// Returns the projected heading of canonical body-local `+X` in the
    /// world `X/Z` plane.
    ///
    /// Canonical `+Z` is right, so heading grows toward `+Z`. This is a
    /// heading convention over a right-handed coordinate system, rather than
    /// the right-hand-rule angle about `+Y`. Adapters must rotate host-local
    /// body axes into canonical `+X`-forward form before constructing this
    /// quaternion.
    pub fn heading_x_forward_z_right_rad(self) -> f64 {
        let forward_world_x = 1.0 - 2.0 * (self.y * self.y + self.z * self.z);
        let forward_world_z = 2.0 * (self.x * self.z - self.w * self.y);
        forward_world_z.atan2(forward_world_x)
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Pose {
    pub position_m: Vec3,
    pub orientation_xyzw: Quaternion,
}

impl Pose {
    fn validate(self, field: &str) -> Result<()> {
        self.position_m.finite(&format!("{field}.position_m"))?;
        self.orientation_xyzw
            .validate(&format!("{field}.orientation_xyzw"))
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Twist {
    pub linear_velocity_m_s: Vec3,
    pub angular_velocity_rad_s: Vec3,
}

impl Twist {
    fn validate(self, field: &str) -> Result<()> {
        self.linear_velocity_m_s
            .finite(&format!("{field}.linear_velocity_m_s"))?;
        self.angular_velocity_rad_s
            .finite(&format!("{field}.angular_velocity_rad_s"))
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ContactQuality {
    Unavailable,
    PresenceOnly,
    QualifiedBearing,
    QualifiedLoad,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ContactProvenance {
    pub adapter_id: String,
    pub engine_contact_ids: Vec<String>,
    pub aggregation_rule_id: String,
    pub quality: ContactQuality,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub impulse_source_profile_id: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub impulse_source_kind: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ContactObservation {
    pub contact_site_id: String,
    pub presence: Option<bool>,
    pub bears_support: Option<bool>,
    pub normal_load_n: Option<f64>,
    pub provenance: ContactProvenance,
}

impl ContactObservation {
    pub fn validate(&self) -> Result<()> {
        require_id(&self.contact_site_id, "contact_site_id")?;
        require_id(&self.provenance.adapter_id, "contact_adapter_id")?;
        require_id(
            &self.provenance.aggregation_rule_id,
            "contact_aggregation_rule_id",
        )?;
        match (
            self.provenance.impulse_source_profile_id.as_deref(),
            self.provenance.impulse_source_kind.as_deref(),
        ) {
            (None, None) => {}
            (Some(profile_id), Some(source_kind)) => {
                require_id(profile_id, "contact_impulse_source_profile_id")?;
                require_id(source_kind, "contact_impulse_source_kind")?;
            }
            _ => {
                return Err(CoreError::Contact(format!(
                    "incomplete_impulse_source_provenance:{}",
                    self.contact_site_id
                )));
            }
        }
        let mut engine_ids = HashSet::new();
        for id in &self.provenance.engine_contact_ids {
            require_id(id, "engine_contact_id")?;
            if !engine_ids.insert(id) {
                return Err(CoreError::Contact(format!(
                    "duplicate_engine_contact_id:{id}"
                )));
            }
        }
        match self.provenance.quality {
            ContactQuality::Unavailable => {
                if self.presence.is_some()
                    || self.bears_support.is_some()
                    || self.normal_load_n.is_some()
                    || !self.provenance.engine_contact_ids.is_empty()
                {
                    return Err(CoreError::Contact(format!(
                        "unavailable_has_values:{}",
                        self.contact_site_id
                    )));
                }
            }
            ContactQuality::PresenceOnly => {
                if self.presence.is_none()
                    || self.bears_support.is_some()
                    || self.normal_load_n.is_some()
                {
                    return Err(CoreError::Contact(format!(
                        "presence_only_capability:{}",
                        self.contact_site_id
                    )));
                }
            }
            ContactQuality::QualifiedBearing => {
                if self.presence.is_none()
                    || self.bears_support.is_none()
                    || self.normal_load_n.is_some()
                {
                    return Err(CoreError::Contact(format!(
                        "qualified_bearing_capability:{}",
                        self.contact_site_id
                    )));
                }
            }
            ContactQuality::QualifiedLoad => {
                if self.presence.is_none()
                    || self.bears_support.is_none()
                    || self.normal_load_n.is_none()
                {
                    return Err(CoreError::Contact(format!(
                        "qualified_load_capability:{}",
                        self.contact_site_id
                    )));
                }
            }
        }
        if let Some(load) = self.normal_load_n {
            require_nonnegative_finite(load, "contact.normal_load_n")?;
        }
        if self.presence == Some(false)
            && (self.bears_support == Some(true)
                || self.normal_load_n.is_some_and(|load| load > 0.0))
        {
            return Err(CoreError::Contact(format!(
                "absent_contact_bears_load:{}",
                self.contact_site_id
            )));
        }
        Ok(())
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct JointValidityMask {
    pub position: bool,
    pub velocity: bool,
    pub anchor_error: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct JointObservation {
    pub joint_id: String,
    pub position_rad: Option<f64>,
    pub velocity_rad_s: Option<f64>,
    pub anchor_error_m: Option<f64>,
    pub validity: JointValidityMask,
}

impl JointObservation {
    pub fn validate(&self) -> Result<()> {
        require_id(&self.joint_id, "joint_observation_id")?;
        for (mask, available, field) in [
            (
                self.validity.position,
                self.position_rad.is_some(),
                "position",
            ),
            (
                self.validity.velocity,
                self.velocity_rad_s.is_some(),
                "velocity",
            ),
            (
                self.validity.anchor_error,
                self.anchor_error_m.is_some(),
                "anchor_error",
            ),
        ] {
            if mask != available {
                return Err(CoreError::Frame(format!(
                    "joint_validity_mask:{}:{field}",
                    self.joint_id
                )));
            }
        }
        if let Some(value) = self.position_rad {
            require_finite(value, "joint.position_rad")?;
        }
        if let Some(value) = self.velocity_rad_s {
            require_finite(value, "joint.velocity_rad_s")?;
        }
        if let Some(value) = self.anchor_error_m {
            require_nonnegative_finite(value, "joint.anchor_error_m")?;
        }
        Ok(())
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct AppliedActuatorObservation {
    pub actuator_id: String,
    pub applied_target_position_rad: f64,
    pub applied_target_velocity_rad_s: f64,
    pub host_clamped: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct AppliedActuationObservation {
    pub source_semantic_step: u64,
    pub ordered_commands: Vec<AppliedActuatorObservation>,
    pub adapter_receipt_sha256: String,
}

impl AppliedActuationObservation {
    fn validate(&self, morphology: &CompiledMorphology, step: u64) -> Result<()> {
        if self.source_semantic_step >= step {
            return Err(CoreError::Time(
                "previous_actuation_not_previous".to_owned(),
            ));
        }
        require_digest(
            &self.adapter_receipt_sha256,
            "previous_actuation.adapter_receipt_sha256",
        )?;
        let ids = self
            .ordered_commands
            .iter()
            .map(|command| command.actuator_id.as_str())
            .collect::<Vec<_>>();
        require_exact_order(&ids, &morphology.ordered_actuator_ids, "previous_actuation")?;
        for command in &self.ordered_commands {
            require_finite(
                command.applied_target_position_rad,
                "applied_target_position_rad",
            )?;
            require_finite(
                command.applied_target_velocity_rad_s,
                "applied_target_velocity_rad_s",
            )?;
        }
        Ok(())
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct TaskFrame {
    pub origin_world_m: Vec3,
    pub forward_axis_world_unit: Vec3,
    pub lateral_axis_world_unit: Vec3,
    pub up_axis_world_unit: Vec3,
    pub reference_yaw_rad: f64,
}

impl TaskFrame {
    fn validate(self) -> Result<()> {
        self.origin_world_m.finite("task_frame.origin_world_m")?;
        for (axis, field) in [
            (self.forward_axis_world_unit, "task_frame.forward_axis"),
            (self.lateral_axis_world_unit, "task_frame.lateral_axis"),
            (self.up_axis_world_unit, "task_frame.up_axis"),
        ] {
            axis.finite(field)?;
            if (norm_squared(axis) - 1.0).abs() > 1.0e-9 {
                return Err(CoreError::Frame(format!("{field}_not_unit")));
            }
        }
        for (first, second, field) in [
            (
                self.forward_axis_world_unit,
                self.lateral_axis_world_unit,
                "forward_lateral",
            ),
            (
                self.forward_axis_world_unit,
                self.up_axis_world_unit,
                "forward_up",
            ),
            (
                self.lateral_axis_world_unit,
                self.up_axis_world_unit,
                "lateral_up",
            ),
        ] {
            if dot(first, second).abs() > 1.0e-9 {
                return Err(CoreError::Frame(format!(
                    "task_frame_axes_not_orthogonal:{field}"
                )));
            }
        }
        require_finite(self.reference_yaw_rad, "task_frame.reference_yaw_rad")
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct StateFrame {
    pub schema_version: String,
    pub semantic_step: u64,
    pub sample_time_s: f64,
    pub base_pose_world: Pose,
    pub base_twist_world: Twist,
    pub ordered_joint_observations: Vec<JointObservation>,
    pub ordered_contact_observations: Vec<ContactObservation>,
    pub previous_applied_actuation: Option<AppliedActuationObservation>,
    pub gravity_world_m_s2: Vec3,
    pub task_frame: TaskFrame,
    pub adapter_capability_sha256: String,
}

impl StateFrame {
    pub fn validate(&self, morphology: &CompiledMorphology) -> Result<()> {
        if self.schema_version != STATE_FRAME_VERSION {
            return Err(CoreError::Schema("state_frame_version".to_owned()));
        }
        require_nonnegative_finite(self.sample_time_s, "state.sample_time_s")?;
        self.base_pose_world.validate("state.base_pose_world")?;
        self.base_twist_world.validate("state.base_twist_world")?;
        self.gravity_world_m_s2.finite("state.gravity_world_m_s2")?;
        if norm_squared(self.gravity_world_m_s2) <= 1.0e-12 {
            return Err(CoreError::Frame("zero_gravity_vector".to_owned()));
        }
        self.task_frame.validate()?;
        require_digest(
            &self.adapter_capability_sha256,
            "state.adapter_capability_sha256",
        )?;
        let joint_ids = self
            .ordered_joint_observations
            .iter()
            .map(|observation| observation.joint_id.as_str())
            .collect::<Vec<_>>();
        require_exact_order(
            &joint_ids,
            &morphology.ordered_joint_ids,
            "joint_observations",
        )?;
        for observation in &self.ordered_joint_observations {
            observation.validate()?;
        }
        let contact_ids = self
            .ordered_contact_observations
            .iter()
            .map(|observation| observation.contact_site_id.as_str())
            .collect::<Vec<_>>();
        require_exact_order(
            &contact_ids,
            &morphology.ordered_contact_site_ids,
            "contact_observations",
        )?;
        for observation in &self.ordered_contact_observations {
            observation.validate()?;
        }
        if let Some(previous) = &self.previous_applied_actuation {
            previous.validate(morphology, self.semantic_step)?;
        }
        Ok(())
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SpeedClass {
    Hold,
    Walk,
    Run,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CommandAuthority {
    User,
    Autonomy,
    TestFixture,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum PhaseProgressionMode {
    Clocked,
    ContactGated,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct MotionCommand {
    pub schema_version: String,
    pub command_id: String,
    pub desired_planar_velocity_task_m_s: Vec3,
    pub desired_heading_rad: Option<f64>,
    pub desired_yaw_rate_rad_s: Option<f64>,
    pub gait_family_id: String,
    pub speed_class: SpeedClass,
    pub gait_amplitude: f64,
    pub phase_progression_mode: PhaseProgressionMode,
    pub valid_from_step: u64,
    pub valid_through_step: u64,
    pub authority: CommandAuthority,
}

impl MotionCommand {
    pub fn validate_for_step(&self, step: u64) -> Result<()> {
        if self.schema_version != MOTION_COMMAND_VERSION {
            return Err(CoreError::Schema("motion_command_version".to_owned()));
        }
        require_id(&self.command_id, "command_id")?;
        require_id(&self.gait_family_id, "gait_family_id")?;
        self.desired_planar_velocity_task_m_s
            .finite("command.desired_planar_velocity_task_m_s")?;
        if self.desired_planar_velocity_task_m_s.y.abs() > 1.0e-12 {
            return Err(CoreError::Frame(
                "desired_planar_velocity_has_vertical_component".to_owned(),
            ));
        }
        if self.desired_heading_rad.is_some() && self.desired_yaw_rate_rad_s.is_some() {
            return Err(CoreError::Schema(
                "heading_and_yaw_rate_both_present".to_owned(),
            ));
        }
        if let Some(value) = self.desired_heading_rad {
            require_finite(value, "command.desired_heading_rad")?;
        }
        if let Some(value) = self.desired_yaw_rate_rad_s {
            require_finite(value, "command.desired_yaw_rate_rad_s")?;
        }
        require_finite(self.gait_amplitude, "command.gait_amplitude")?;
        if !(0.0..=1.0).contains(&self.gait_amplitude) {
            return Err(CoreError::Schema("gait_amplitude_out_of_range".to_owned()));
        }
        if self.speed_class == SpeedClass::Hold && self.gait_amplitude != 0.0 {
            return Err(CoreError::Schema(
                "hold_command_nonzero_amplitude".to_owned(),
            ));
        }
        if self.valid_from_step > self.valid_through_step {
            return Err(CoreError::Time("command_window_reversed".to_owned()));
        }
        if step < self.valid_from_step || step > self.valid_through_step {
            return Err(CoreError::Time("command_expired_or_early".to_owned()));
        }
        Ok(())
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ActuatorCommand {
    pub actuator_id: String,
    pub mode: ActuatorMode,
    pub requested_target_position_rad: f64,
    pub clamped_target_position_rad: f64,
    pub target_velocity_rad_s: f64,
    pub maximum_target_speed_rad_s: f64,
    pub position_saturated: bool,
    pub velocity_saturated: bool,
    pub slew_limited: bool,
    pub residual_contribution_rad_s: f64,
    pub safety_contribution_rad_s: f64,
    pub valid_through_step: u64,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ReleaseGateUnweightingReceipt {
    pub schema_version: String,
    pub knee_target_mode_id: Option<String>,
    pub hip_target_mode_id: Option<String>,
    pub ordered_knee_override_limb_ids: Vec<String>,
    pub ordered_hip_override_limb_ids: Vec<String>,
    pub analytic_target_basis: String,
    pub morphology_branch_surface_count: usize,
    pub controller_parameter: bool,
    pub walking_claim_authorized: bool,
    pub physical_acceptance_authority: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ForwardVelocityFootPlacementLimbReceipt {
    pub limb_id: String,
    pub local_phase_step: u64,
    pub cycle_envelope: f64,
    pub applied_hip_target_correction_rad: f64,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ForwardVelocityFootPlacementReceipt {
    pub schema_version: String,
    pub mode_id: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub velocity_error_orientation_id: Option<String>,
    pub desired_forward_velocity_task_m_s: f64,
    pub measured_forward_velocity_task_m_s: f64,
    pub normalized_forward_velocity_error: f64,
    pub maximum_hip_target_correction_rad: f64,
    pub ordered_limb_corrections: Vec<ForwardVelocityFootPlacementLimbReceipt>,
    pub morphology_branch_surface_count: usize,
    pub controller_parameter: bool,
    pub walking_claim_authorized: bool,
    pub physical_acceptance_authority: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SteeringAuthorityGuardReceipt {
    pub schema_version: String,
    pub mode_id: String,
    pub torso_tilt_rad: f64,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub torso_tilt_rate_rad_s: Option<f64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub worsening_torso_tilt_rate_rad_s: Option<f64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub prediction_horizon_s: Option<f64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub prediction_horizon_scheduler_swing_steps: Option<u64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub predicted_torso_tilt_rad: Option<f64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub tilt_rate_source_id: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub prediction_horizon_basis_id: Option<String>,
    pub support_contact_count: u32,
    pub support_contact_count_uses_presence_fallback: bool,
    pub minimum_support_contact_count: u32,
    pub contact_authority_permitted: bool,
    pub tilt_authority_fraction: f64,
    pub baseline_maximum_steering_fraction: f64,
    pub expanded_maximum_steering_fraction: f64,
    pub effective_maximum_steering_fraction: f64,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub instantaneous_tilt_authority_fraction: Option<f64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub instantaneous_effective_maximum_steering_fraction: Option<f64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub floor_hold_duration_steps: Option<u64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub floor_hold_scheduler_swing_count: Option<u64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub floor_hold_steps_remaining_before_step: Option<u64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub floor_hold_steps_remaining_after_step: Option<u64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub floor_hold_triggered_this_step: Option<bool>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub floor_hold_active_this_step: Option<bool>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub floor_hold_basis_id: Option<String>,
    pub full_authority_maximum_tilt_rad: f64,
    pub minimum_authority_tilt_rad: f64,
    pub direction_neutral: bool,
    pub engine_identity_input_count: u32,
    pub controller_parameter: bool,
    pub turning_claim_authorized: bool,
    pub physical_acceptance_authority: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ControllerStepReceipt {
    pub schema_version: String,
    pub policy_id: String,
    pub semantic_step: u64,
    pub command_id: String,
    pub morphology_spec_sha256: String,
    pub adapter_capability_sha256: String,
    pub steering_feedback_updated: bool,
    pub requested_steering_fraction: f64,
    pub previous_steering_fraction: f64,
    pub held_steering_fraction: f64,
    pub applied_steering_delta: f64,
    pub steering_saturated: bool,
    pub steering_slew_limited: bool,
    pub steering_filter_alpha_per_step: Option<f64>,
    pub steering_filter_time_constant_cycle_fraction: Option<f64>,
    pub cross_track_error_m: f64,
    pub cross_track_velocity_m_s: f64,
    pub measured_yaw_error_rad: f64,
    pub desired_heading_error_rad: f64,
    pub yaw_tracking_error_rad: f64,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub steering_authority_guard: Option<SteeringAuthorityGuardReceipt>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub release_gate_unweighting: Option<ReleaseGateUnweightingReceipt>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub forward_velocity_foot_placement: Option<ForwardVelocityFootPlacementReceipt>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub recovery_support_plane: Option<crate::recovery_support_plane::SupportPlaneReceipt>,
    pub controller_error: Option<String>,
    pub world_build_count: u32,
    pub physical_acceptance_authority: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ActuationFrame {
    pub schema_version: String,
    pub semantic_step: u64,
    pub ordered_commands: Vec<ActuatorCommand>,
    pub safe_no_actuation: bool,
    pub failure_codes: Vec<String>,
    pub receipt: ControllerStepReceipt,
    pub receipt_sha256: String,
    pub world_build_count: u32,
    pub physical_acceptance_authority: bool,
}

impl ActuationFrame {
    pub fn validate(&self, morphology: &CompiledMorphology) -> Result<()> {
        if self.schema_version != ACTUATION_FRAME_VERSION {
            return Err(CoreError::Schema("actuation_frame_version".to_owned()));
        }
        let ids = self
            .ordered_commands
            .iter()
            .map(|command| command.actuator_id.as_str())
            .collect::<Vec<_>>();
        require_exact_order(&ids, &morphology.ordered_actuator_ids, "actuation")?;
        for (command, actuator) in self
            .ordered_commands
            .iter()
            .zip(&morphology.morphology_spec.actuators)
        {
            for (value, field) in [
                (
                    command.requested_target_position_rad,
                    "requested_target_position_rad",
                ),
                (
                    command.clamped_target_position_rad,
                    "clamped_target_position_rad",
                ),
                (command.target_velocity_rad_s, "target_velocity_rad_s"),
                (
                    command.maximum_target_speed_rad_s,
                    "maximum_target_speed_rad_s",
                ),
                (
                    command.residual_contribution_rad_s,
                    "residual_contribution_rad_s",
                ),
                (
                    command.safety_contribution_rad_s,
                    "safety_contribution_rad_s",
                ),
            ] {
                require_finite(value, field)?;
            }
            if command.maximum_target_speed_rad_s <= 0.0
                || command.target_velocity_rad_s.abs()
                    > command.maximum_target_speed_rad_s + 1.0e-12
                || command.clamped_target_position_rad
                    < actuator.minimum_target_position_rad - 1.0e-12
                || command.clamped_target_position_rad
                    > actuator.maximum_target_position_rad + 1.0e-12
                || command.valid_through_step < self.semantic_step
            {
                return Err(CoreError::Actuation(format!(
                    "actuator_command_bounds:{}",
                    command.actuator_id
                )));
            }
            if self.safe_no_actuation
                && (command.target_velocity_rad_s != 0.0
                    || command.residual_contribution_rad_s != 0.0
                    || command.safety_contribution_rad_s != 0.0)
            {
                return Err(CoreError::Actuation(format!(
                    "safe_frame_has_authority:{}",
                    command.actuator_id
                )));
            }
        }
        require_digest(&self.receipt_sha256, "actuation.receipt_sha256")?;
        if self.world_build_count != 0 || self.physical_acceptance_authority {
            return Err(CoreError::Actuation(
                "pure_frame_claims_physical_authority".to_owned(),
            ));
        }
        Ok(())
    }
}

pub fn dot(first: Vec3, second: Vec3) -> f64 {
    first.x * second.x + first.y * second.y + first.z * second.z
}

pub fn subtract(first: Vec3, second: Vec3) -> Vec3 {
    Vec3 {
        x: first.x - second.x,
        y: first.y - second.y,
        z: first.z - second.z,
    }
}

fn norm_squared(value: Vec3) -> f64 {
    dot(value, value)
}

fn valid_id(value: &str) -> bool {
    let mut characters = value.chars();
    matches!(characters.next(), Some('a'..='z'))
        && characters.all(|character| {
            character.is_ascii_lowercase() || character.is_ascii_digit() || character == '_'
        })
}

fn require_id(value: &str, field: &str) -> Result<()> {
    if valid_id(value) {
        Ok(())
    } else {
        Err(CoreError::Identity(format!("{field}:{value}")))
    }
}

fn require_finite(value: f64, field: &str) -> Result<()> {
    if value.is_finite() {
        Ok(())
    } else {
        Err(CoreError::NonFinite(field.to_owned()))
    }
}

fn require_nonnegative_finite(value: f64, field: &str) -> Result<()> {
    require_finite(value, field)?;
    if value < 0.0 {
        Err(CoreError::Frame(format!("{field}_negative")))
    } else {
        Ok(())
    }
}

fn require_digest(value: &str, field: &str) -> Result<()> {
    if value.len() == 71
        && value.starts_with("sha256:")
        && value[7..]
            .bytes()
            .all(|byte| byte.is_ascii_digit() || (b'a'..=b'f').contains(&byte))
    {
        Ok(())
    } else {
        Err(CoreError::Digest(field.to_owned()))
    }
}

fn require_exact_order(actual: &[&str], expected: &[String], field: &str) -> Result<()> {
    if actual.len() != expected.len()
        || actual
            .iter()
            .zip(expected)
            .any(|(actual_id, expected_id)| *actual_id != expected_id)
    {
        Err(CoreError::Order(field.to_owned()))
    } else {
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::quadruped::{BoundedQuadrupedDescriptor, compile_bounded_quadruped};

    fn compiled() -> CompiledMorphology {
        compile_bounded_quadruped(BoundedQuadrupedDescriptor::reference("protocol"))
            .unwrap()
            .morphology
    }

    #[test]
    fn contact_impulse_source_provenance_is_explicit_paired_and_strict() {
        let exact = serde_json::json!({
            "contact_site_id": "front_left_foot",
            "presence": true,
            "bears_support": true,
            "normal_load_n": null,
            "provenance": {
                "adapter_id": "godot_jolt",
                "engine_contact_ids": ["body_1_floor_0"],
                "aggregation_rule_id": "exact_post_solve_contact_v1",
                "quality": "qualified_bearing",
                "impulse_source_profile_id": "godot_jolt_solved_contact_v3",
                "impulse_source_kind": "native_post_solve_contact_constraint_lambda"
            }
        });
        let contact: ContactObservation = serde_json::from_value(exact.clone()).unwrap();
        contact.validate().unwrap();
        assert_eq!(
            contact.provenance.impulse_source_profile_id.as_deref(),
            Some("godot_jolt_solved_contact_v3")
        );
        assert_eq!(
            contact.provenance.impulse_source_kind.as_deref(),
            Some("native_post_solve_contact_constraint_lambda")
        );

        for missing in ["impulse_source_profile_id", "impulse_source_kind"] {
            let mut incomplete = exact.clone();
            incomplete["provenance"]
                .as_object_mut()
                .unwrap()
                .remove(missing);
            let decoded: ContactObservation = serde_json::from_value(incomplete).unwrap();
            assert!(
                decoded
                    .validate()
                    .unwrap_err()
                    .to_string()
                    .contains("incomplete_impulse_source_provenance")
            );
        }

        let mut unknown = exact;
        unknown["provenance"]["unqualified_source_hint"] = serde_json::json!(true);
        assert!(serde_json::from_value::<ContactObservation>(unknown).is_err());

        let mut legacy = contact;
        legacy.provenance.impulse_source_profile_id = None;
        legacy.provenance.impulse_source_kind = None;
        legacy.validate().unwrap();
        let encoded = serde_json::to_value(legacy).unwrap();
        assert!(
            encoded["provenance"]
                .get("impulse_source_profile_id")
                .is_none()
        );
        assert!(encoded["provenance"].get("impulse_source_kind").is_none());
    }

    fn valid_state(morphology: &CompiledMorphology) -> StateFrame {
        StateFrame {
            schema_version: STATE_FRAME_VERSION.to_owned(),
            semantic_step: 1,
            sample_time_s: 1.0 / 120.0,
            base_pose_world: Pose {
                position_m: Vec3 {
                    x: 0.0,
                    y: 0.44,
                    z: 0.0,
                },
                orientation_xyzw: Quaternion::IDENTITY,
            },
            base_twist_world: Twist {
                linear_velocity_m_s: Vec3::ZERO,
                angular_velocity_rad_s: Vec3::ZERO,
            },
            ordered_joint_observations: morphology
                .ordered_joint_ids
                .iter()
                .map(|joint_id| JointObservation {
                    joint_id: joint_id.clone(),
                    position_rad: Some(0.0),
                    velocity_rad_s: Some(0.0),
                    anchor_error_m: Some(0.0),
                    validity: JointValidityMask {
                        position: true,
                        velocity: true,
                        anchor_error: true,
                    },
                })
                .collect(),
            ordered_contact_observations: morphology
                .ordered_contact_site_ids
                .iter()
                .map(|contact_site_id| ContactObservation {
                    contact_site_id: contact_site_id.clone(),
                    presence: Some(true),
                    bears_support: Some(true),
                    normal_load_n: None,
                    provenance: ContactProvenance {
                        adapter_id: "test_adapter".to_owned(),
                        engine_contact_ids: vec![format!("{contact_site_id}_engine")],
                        aggregation_rule_id: "no_load_aggregation".to_owned(),
                        quality: ContactQuality::QualifiedBearing,
                        impulse_source_profile_id: None,
                        impulse_source_kind: None,
                    },
                })
                .collect(),
            previous_applied_actuation: None,
            gravity_world_m_s2: Vec3 {
                x: 0.0,
                y: -9.81,
                z: 0.0,
            },
            task_frame: TaskFrame {
                origin_world_m: Vec3::ZERO,
                forward_axis_world_unit: Vec3 {
                    x: 1.0,
                    y: 0.0,
                    z: 0.0,
                },
                lateral_axis_world_unit: Vec3 {
                    x: 0.0,
                    y: 0.0,
                    z: 1.0,
                },
                up_axis_world_unit: Vec3 {
                    x: 0.0,
                    y: 1.0,
                    z: 0.0,
                },
                reference_yaw_rad: 0.0,
            },
            adapter_capability_sha256:
                "sha256:0000000000000000000000000000000000000000000000000000000000000000".to_owned(),
        }
    }

    #[test]
    fn valid_frame_requires_exact_semantic_order() {
        let morphology = compiled();
        let mut state = valid_state(&morphology);
        state.validate(&morphology).unwrap();
        state.ordered_joint_observations.swap(0, 1);
        assert!(matches!(
            state.validate(&morphology),
            Err(CoreError::Order(_))
        ));
    }

    #[test]
    fn unavailable_contact_cannot_invent_zero_or_false() {
        let morphology = compiled();
        let mut state = valid_state(&morphology);
        state.ordered_contact_observations[0].provenance.quality = ContactQuality::Unavailable;
        state.ordered_contact_observations[0].presence = Some(false);
        state.ordered_contact_observations[0].bears_support = None;
        state.ordered_contact_observations[0]
            .provenance
            .engine_contact_ids
            .clear();
        assert!(matches!(
            state.validate(&morphology),
            Err(CoreError::Contact(_))
        ));
    }

    #[test]
    fn command_window_and_authority_are_explicit() {
        let command = MotionCommand {
            schema_version: MOTION_COMMAND_VERSION.to_owned(),
            command_id: "walk_forward".to_owned(),
            desired_planar_velocity_task_m_s: Vec3 {
                x: 0.2,
                y: 0.0,
                z: 0.0,
            },
            desired_heading_rad: Some(0.0),
            desired_yaw_rate_rad_s: None,
            gait_family_id: "lateral_wave".to_owned(),
            speed_class: SpeedClass::Walk,
            gait_amplitude: 1.0,
            phase_progression_mode: PhaseProgressionMode::ContactGated,
            valid_from_step: 10,
            valid_through_step: 20,
            authority: CommandAuthority::TestFixture,
        };
        command.validate_for_step(10).unwrap();
        command.validate_for_step(20).unwrap();
        assert!(matches!(
            command.validate_for_step(21),
            Err(CoreError::Time(_))
        ));
    }

    #[test]
    fn quaternion_heading_uses_canonical_x_forward_z_right_convention() {
        let half_turn_quarter = std::f64::consts::FRAC_PI_4;
        let host_positive_y_quarter_turn = Quaternion {
            x: 0.0,
            y: half_turn_quarter.sin(),
            z: 0.0,
            w: half_turn_quarter.cos(),
        };
        let host_negative_y_quarter_turn = Quaternion {
            x: 0.0,
            y: -half_turn_quarter.sin(),
            z: 0.0,
            w: half_turn_quarter.cos(),
        };

        assert_eq!(Quaternion::IDENTITY.heading_x_forward_z_right_rad(), 0.0);
        assert!(
            (host_positive_y_quarter_turn.heading_x_forward_z_right_rad()
                + std::f64::consts::FRAC_PI_2)
                .abs()
                <= 1.0e-15
        );
        assert!(
            (host_negative_y_quarter_turn.heading_x_forward_z_right_rad()
                - std::f64::consts::FRAC_PI_2)
                .abs()
                <= 1.0e-15
        );
    }
}
