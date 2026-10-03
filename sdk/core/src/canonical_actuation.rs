use serde::{Deserialize, Serialize};

use crate::protocol::ActuationFrame;
use crate::schema::{CompiledMorphology, CoreError, Result};

pub const CANONICAL_VELOCITY_ACTUATION_FRAME_V1_VERSION: &str =
    "sporespore_canonical_velocity_actuation_frame_v1";
pub const CANONICAL_VELOCITY_RESIDUAL_V1_VERSION: &str =
    "sporespore_canonical_velocity_residual_v1";
pub const VELOCITY_ONLY_HOST_PROFILE_V1_VERSION: &str = "sporespore_velocity_only_host_profile_v1";
pub const VELOCITY_ONLY_HOST_MAPPING_RECEIPT_V1_VERSION: &str =
    "sporespore_velocity_only_host_mapping_receipt_v1";
pub const COMPLETE_CLOSED_LOOP_CANONICAL_VELOCITY_PROFILE_ID: &str =
    "sporespore_complete_closed_loop_canonical_velocity_v1";
pub const LEGACY_GODOT_HOST_VELOCITY_CONVENTION_ID: &str = "legacy_godot_host_target_velocity_v1";
pub const GODOT_JOLT_VELOCITY_ONLY_EQUIVALENCE_PROFILE_ID: &str =
    "godot_jolt_velocity_only_equivalence_v1";
pub const RAPIER_FORCE_BASED_VELOCITY_ONLY_PROFILE_ID: &str = "rapier_force_based_velocity_only_v1";
pub const MUJOCO_VELOCITY_SERVO_FORCE_LIMITED_FIVE_SUBSTEP_PROFILE_ID: &str =
    "mujoco_velocity_servo_force_limited_five_substep_v3";
pub const MUJOCO_PER_ACTUATOR_FORCE_LIMITED_FIVE_SUBSTEP_DEVELOPMENT_PROFILE_ID: &str =
    "mujoco_per_actuator_force_limited_five_substep_development_v1";
pub const MUJOCO_S169_PER_ACTUATOR_FORCE_LIMITED_FIVE_SUBSTEP_VH5_VALIDATED_PROFILE_ID: &str =
    "mujoco_s169_per_actuator_force_limited_five_substep_vh5_validated_v1";
pub const LEGACY_GODOT_HOST_TO_CANONICAL_VELOCITY_SIGN: f64 = -1.0;
pub const GODOT_JOLT_CANONICAL_TO_HOST_VELOCITY_SIGN: f64 = -1.0;
pub const RAPIER_CANONICAL_TO_HOST_VELOCITY_SIGN: f64 = 1.0;
pub const MUJOCO_CANONICAL_TO_HOST_VELOCITY_SIGN: f64 = 1.0;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum PositionTargetRoleV1 {
    ProvenanceAndBoundsOnly,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum LoadBearingActuationV1 {
    CompleteClosedLoopCanonicalTargetVelocity,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CanonicalVelocityResidualV1 {
    pub schema_version: String,
    pub actuator_id: String,
    pub canonical_velocity_delta_rad_s: f64,
    pub command_not_measurement: bool,
    pub physical_acceptance_authority: bool,
}

impl CanonicalVelocityResidualV1 {
    pub fn exact_zero(actuator_id: impl Into<String>) -> Self {
        Self {
            schema_version: CANONICAL_VELOCITY_RESIDUAL_V1_VERSION.to_owned(),
            actuator_id: actuator_id.into(),
            canonical_velocity_delta_rad_s: 0.0,
            command_not_measurement: true,
            physical_acceptance_authority: false,
        }
    }

    fn validate(&self) -> Result<()> {
        if self.schema_version != CANONICAL_VELOCITY_RESIDUAL_V1_VERSION {
            return Err(CoreError::Schema(
                "canonical_velocity_residual_version".to_owned(),
            ));
        }
        require_id(&self.actuator_id, "canonical_velocity_residual_actuator_id")?;
        require_finite(
            self.canonical_velocity_delta_rad_s,
            "canonical_velocity_delta_rad_s",
        )?;
        if !self.command_not_measurement || self.physical_acceptance_authority {
            return Err(CoreError::Actuation(format!(
                "canonical_velocity_residual_authority:{}",
                self.actuator_id
            )));
        }
        Ok(())
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CanonicalVelocityActuatorCommandV1 {
    pub actuator_id: String,
    pub requested_target_position_rad: f64,
    pub clamped_target_position_rad: f64,
    pub position_target_role: PositionTargetRoleV1,
    pub source_legacy_host_target_velocity_rad_s: f64,
    pub source_legacy_residual_contribution_rad_s: f64,
    pub source_legacy_safety_contribution_rad_s: f64,
    pub portable_canonical_target_velocity_rad_s: f64,
    pub portable_canonical_residual_contribution_rad_s: f64,
    pub portable_canonical_safety_contribution_rad_s: f64,
    pub stability_canonical_velocity_delta_rad_s: f64,
    pub unbounded_canonical_target_velocity_rad_s: f64,
    pub combined_canonical_target_velocity_rad_s: f64,
    pub maximum_target_speed_rad_s: f64,
    pub canonical_speed_saturated: bool,
    pub valid_through_step: u64,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CanonicalVelocityActuationFrameV1 {
    pub schema_version: String,
    pub profile_id: String,
    pub source_velocity_convention_id: String,
    pub source_policy_id: String,
    pub source_actuation_receipt_sha256: String,
    pub semantic_step: u64,
    pub position_target_role: PositionTargetRoleV1,
    pub load_bearing_actuation: LoadBearingActuationV1,
    pub canonical_to_host_mapping_owned_by_adapter: bool,
    pub ordered_commands: Vec<CanonicalVelocityActuatorCommandV1>,
    pub safe_no_actuation: bool,
    pub failure_codes: Vec<String>,
    pub world_build_count: u32,
    pub physics_state_modified: bool,
    pub physical_acceptance_authority: bool,
}

impl CanonicalVelocityActuationFrameV1 {
    pub fn validate(&self, morphology: &CompiledMorphology) -> Result<()> {
        if self.schema_version != CANONICAL_VELOCITY_ACTUATION_FRAME_V1_VERSION {
            return Err(CoreError::Schema(
                "canonical_velocity_actuation_frame_version".to_owned(),
            ));
        }
        if self.profile_id != COMPLETE_CLOSED_LOOP_CANONICAL_VELOCITY_PROFILE_ID
            || self.source_velocity_convention_id != LEGACY_GODOT_HOST_VELOCITY_CONVENTION_ID
            || self.position_target_role != PositionTargetRoleV1::ProvenanceAndBoundsOnly
            || self.load_bearing_actuation
                != LoadBearingActuationV1::CompleteClosedLoopCanonicalTargetVelocity
            || !self.canonical_to_host_mapping_owned_by_adapter
        {
            return Err(CoreError::Actuation(
                "canonical_velocity_profile_identity".to_owned(),
            ));
        }
        require_id(
            &self.source_policy_id,
            "canonical_velocity_source_policy_id",
        )?;
        require_digest(
            &self.source_actuation_receipt_sha256,
            "canonical_velocity_source_actuation_receipt_sha256",
        )?;
        require_order(
            self.ordered_commands
                .iter()
                .map(|command| command.actuator_id.as_str()),
            &morphology.ordered_actuator_ids,
            "canonical_velocity_commands",
        )?;
        for (command, actuator) in self
            .ordered_commands
            .iter()
            .zip(&morphology.morphology_spec.actuators)
        {
            if command.position_target_role != PositionTargetRoleV1::ProvenanceAndBoundsOnly {
                return Err(CoreError::Actuation(format!(
                    "canonical_velocity_position_role:{}",
                    command.actuator_id
                )));
            }
            for (value, field) in [
                (
                    command.requested_target_position_rad,
                    "requested_target_position_rad",
                ),
                (
                    command.clamped_target_position_rad,
                    "clamped_target_position_rad",
                ),
                (
                    command.source_legacy_host_target_velocity_rad_s,
                    "source_legacy_host_target_velocity_rad_s",
                ),
                (
                    command.source_legacy_residual_contribution_rad_s,
                    "source_legacy_residual_contribution_rad_s",
                ),
                (
                    command.source_legacy_safety_contribution_rad_s,
                    "source_legacy_safety_contribution_rad_s",
                ),
                (
                    command.portable_canonical_target_velocity_rad_s,
                    "portable_canonical_target_velocity_rad_s",
                ),
                (
                    command.portable_canonical_residual_contribution_rad_s,
                    "portable_canonical_residual_contribution_rad_s",
                ),
                (
                    command.portable_canonical_safety_contribution_rad_s,
                    "portable_canonical_safety_contribution_rad_s",
                ),
                (
                    command.stability_canonical_velocity_delta_rad_s,
                    "stability_canonical_velocity_delta_rad_s",
                ),
                (
                    command.unbounded_canonical_target_velocity_rad_s,
                    "unbounded_canonical_target_velocity_rad_s",
                ),
                (
                    command.combined_canonical_target_velocity_rad_s,
                    "combined_canonical_target_velocity_rad_s",
                ),
                (
                    command.maximum_target_speed_rad_s,
                    "maximum_target_speed_rad_s",
                ),
            ] {
                require_finite(value, field)?;
            }
            if command.maximum_target_speed_rad_s <= 0.0
                || command.clamped_target_position_rad
                    < actuator.minimum_target_position_rad - 1.0e-12
                || command.clamped_target_position_rad
                    > actuator.maximum_target_position_rad + 1.0e-12
                || command.combined_canonical_target_velocity_rad_s.abs()
                    > command.maximum_target_speed_rad_s + 1.0e-12
                || command.valid_through_step < self.semantic_step
            {
                return Err(CoreError::Actuation(format!(
                    "canonical_velocity_command_bounds:{}",
                    command.actuator_id
                )));
            }
            let canonical = command.source_legacy_host_target_velocity_rad_s
                * LEGACY_GODOT_HOST_TO_CANONICAL_VELOCITY_SIGN;
            let canonical_residual = command.source_legacy_residual_contribution_rad_s
                * LEGACY_GODOT_HOST_TO_CANONICAL_VELOCITY_SIGN;
            let canonical_safety = command.source_legacy_safety_contribution_rad_s
                * LEGACY_GODOT_HOST_TO_CANONICAL_VELOCITY_SIGN;
            let unbounded = command.portable_canonical_target_velocity_rad_s
                + command.stability_canonical_velocity_delta_rad_s;
            let combined = unbounded.clamp(
                -command.maximum_target_speed_rad_s,
                command.maximum_target_speed_rad_s,
            );
            if !same_float(canonical, command.portable_canonical_target_velocity_rad_s)
                || !same_float(
                    canonical_residual,
                    command.portable_canonical_residual_contribution_rad_s,
                )
                || !same_float(
                    canonical_safety,
                    command.portable_canonical_safety_contribution_rad_s,
                )
                || !same_float(unbounded, command.unbounded_canonical_target_velocity_rad_s)
                || !same_float(combined, command.combined_canonical_target_velocity_rad_s)
                || command.canonical_speed_saturated != (combined != unbounded)
            {
                return Err(CoreError::Actuation(format!(
                    "canonical_velocity_command_reconstruction:{}",
                    command.actuator_id
                )));
            }
            if self.safe_no_actuation
                && (command.portable_canonical_target_velocity_rad_s != 0.0
                    || command.stability_canonical_velocity_delta_rad_s != 0.0
                    || command.combined_canonical_target_velocity_rad_s != 0.0)
            {
                return Err(CoreError::Actuation(format!(
                    "canonical_velocity_safe_frame_has_authority:{}",
                    command.actuator_id
                )));
            }
        }
        if self.world_build_count != 0
            || self.physics_state_modified
            || self.physical_acceptance_authority
        {
            return Err(CoreError::Actuation(
                "canonical_velocity_frame_authority".to_owned(),
            ));
        }
        Ok(())
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct VelocityOnlyHostProfileV1 {
    pub schema_version: String,
    pub profile_id: String,
    pub adapter_id: String,
    pub engine_id: String,
    pub native_motor_model_id: String,
    pub canonical_to_host_velocity_sign: f64,
    pub independent_native_position_feedback_applied: bool,
    pub native_position_stiffness: f64,
    pub retained_host_behavior_equivalence_target: bool,
    pub host_response_characterized_for_this_profile: bool,
    pub world_build_count: u32,
    pub physical_acceptance_authority: bool,
}

impl VelocityOnlyHostProfileV1 {
    pub fn godot_jolt_equivalence_target() -> Self {
        Self {
            schema_version: VELOCITY_ONLY_HOST_PROFILE_V1_VERSION.to_owned(),
            profile_id: GODOT_JOLT_VELOCITY_ONLY_EQUIVALENCE_PROFILE_ID.to_owned(),
            adapter_id: "sporespore_godot_jolt_adapter".to_owned(),
            engine_id: "godot_jolt".to_owned(),
            native_motor_model_id: "hinge_target_velocity_with_impulse_cap".to_owned(),
            canonical_to_host_velocity_sign: GODOT_JOLT_CANONICAL_TO_HOST_VELOCITY_SIGN,
            independent_native_position_feedback_applied: false,
            native_position_stiffness: 0.0,
            retained_host_behavior_equivalence_target: true,
            host_response_characterized_for_this_profile: false,
            world_build_count: 0,
            physical_acceptance_authority: false,
        }
    }

    pub fn rapier_force_based_velocity_only_target() -> Self {
        Self {
            schema_version: VELOCITY_ONLY_HOST_PROFILE_V1_VERSION.to_owned(),
            profile_id: RAPIER_FORCE_BASED_VELOCITY_ONLY_PROFILE_ID.to_owned(),
            adapter_id: "sporespore_rapier3d_adapter".to_owned(),
            engine_id: "rapier3d".to_owned(),
            native_motor_model_id: "force_based_velocity_only".to_owned(),
            canonical_to_host_velocity_sign: RAPIER_CANONICAL_TO_HOST_VELOCITY_SIGN,
            independent_native_position_feedback_applied: false,
            native_position_stiffness: 0.0,
            retained_host_behavior_equivalence_target: false,
            host_response_characterized_for_this_profile: false,
            world_build_count: 0,
            physical_acceptance_authority: false,
        }
    }

    /// Return the exact MuJoCo velocity-only host identity characterized by
    /// the immutable C6-MJC-HC-VH4 positive closure.
    ///
    /// `host_response_characterized_for_this_profile` is intentionally true
    /// only for this exact native actuator, gain, force-limit, integrator, and
    /// five-internal-step identity. The mapping remains pure and carries no
    /// walking or physical-acceptance authority.
    pub fn mujoco_velocity_servo_force_limited_five_substep_v3() -> Self {
        Self {
            schema_version: VELOCITY_ONLY_HOST_PROFILE_V1_VERSION.to_owned(),
            profile_id: MUJOCO_VELOCITY_SERVO_FORCE_LIMITED_FIVE_SUBSTEP_PROFILE_ID.to_owned(),
            adapter_id: "sporespore_mujoco_adapter".to_owned(),
            engine_id: "mujoco".to_owned(),
            native_motor_model_id: "velocity_servo_force_limited_five_substep_v3".to_owned(),
            canonical_to_host_velocity_sign: MUJOCO_CANONICAL_TO_HOST_VELOCITY_SIGN,
            independent_native_position_feedback_applied: false,
            native_position_stiffness: 0.0,
            retained_host_behavior_equivalence_target: false,
            host_response_characterized_for_this_profile: true,
            world_build_count: 0,
            physical_acceptance_authority: false,
        }
    }

    /// Return the honest pre-characterization identity used while integrating
    /// exact portable per-actuator impulse budgets into MuJoCo.
    pub fn mujoco_per_actuator_force_limited_five_substep_development_v1() -> Self {
        Self {
            schema_version: VELOCITY_ONLY_HOST_PROFILE_V1_VERSION.to_owned(),
            profile_id: MUJOCO_PER_ACTUATOR_FORCE_LIMITED_FIVE_SUBSTEP_DEVELOPMENT_PROFILE_ID
                .to_owned(),
            adapter_id: "sporespore_mujoco_adapter".to_owned(),
            engine_id: "mujoco".to_owned(),
            native_motor_model_id:
                "velocity_servo_per_actuator_force_limited_five_substep_development_v1".to_owned(),
            canonical_to_host_velocity_sign: MUJOCO_CANONICAL_TO_HOST_VELOCITY_SIGN,
            independent_native_position_feedback_applied: false,
            native_position_stiffness: 0.0,
            retained_host_behavior_equivalence_target: false,
            host_response_characterized_for_this_profile: false,
            world_build_count: 0,
            physical_acceptance_authority: false,
        }
    }

    /// Return the exact s169 per-actuator MuJoCo host identity characterized
    /// by the immutable C6-MJC-HC-VH5 positive closure.
    ///
    /// This profile registration repairs the cross-language identity mismatch
    /// exposed by the closed, implementation-invalid C6-MJC-BW19V-MV1
    /// attempt. It grants only the VH5 exact-finite host characterization; it
    /// does not retroactively create an MV1 locomotion result.
    pub fn mujoco_s169_per_actuator_force_limited_five_substep_vh5_validated_v1() -> Self {
        Self {
            schema_version: VELOCITY_ONLY_HOST_PROFILE_V1_VERSION.to_owned(),
            profile_id:
                MUJOCO_S169_PER_ACTUATOR_FORCE_LIMITED_FIVE_SUBSTEP_VH5_VALIDATED_PROFILE_ID
                    .to_owned(),
            adapter_id: "sporespore_mujoco_adapter".to_owned(),
            engine_id: "mujoco".to_owned(),
            native_motor_model_id:
                "velocity_servo_s169_per_actuator_force_limited_five_substep_vh5_validated_v1"
                    .to_owned(),
            canonical_to_host_velocity_sign: MUJOCO_CANONICAL_TO_HOST_VELOCITY_SIGN,
            independent_native_position_feedback_applied: false,
            native_position_stiffness: 0.0,
            retained_host_behavior_equivalence_target: false,
            host_response_characterized_for_this_profile: true,
            world_build_count: 0,
            physical_acceptance_authority: false,
        }
    }

    pub fn validate(&self) -> Result<()> {
        if self.schema_version != VELOCITY_ONLY_HOST_PROFILE_V1_VERSION {
            return Err(CoreError::Schema(
                "velocity_only_host_profile_version".to_owned(),
            ));
        }
        for (value, field) in [
            (&self.profile_id, "velocity_only_host_profile_id"),
            (&self.adapter_id, "velocity_only_host_adapter_id"),
            (&self.engine_id, "velocity_only_host_engine_id"),
            (
                &self.native_motor_model_id,
                "velocity_only_host_motor_model_id",
            ),
        ] {
            require_id(value, field)?;
        }
        require_finite(
            self.canonical_to_host_velocity_sign,
            "canonical_to_host_velocity_sign",
        )?;
        require_finite(self.native_position_stiffness, "native_position_stiffness")?;
        let identity_matches = match self.profile_id.as_str() {
            GODOT_JOLT_VELOCITY_ONLY_EQUIVALENCE_PROFILE_ID => {
                self.adapter_id == "sporespore_godot_jolt_adapter"
                    && self.engine_id == "godot_jolt"
                    && self.native_motor_model_id == "hinge_target_velocity_with_impulse_cap"
                    && same_float(
                        self.canonical_to_host_velocity_sign,
                        GODOT_JOLT_CANONICAL_TO_HOST_VELOCITY_SIGN,
                    )
                    && self.retained_host_behavior_equivalence_target
            }
            RAPIER_FORCE_BASED_VELOCITY_ONLY_PROFILE_ID => {
                self.adapter_id == "sporespore_rapier3d_adapter"
                    && self.engine_id == "rapier3d"
                    && self.native_motor_model_id == "force_based_velocity_only"
                    && same_float(
                        self.canonical_to_host_velocity_sign,
                        RAPIER_CANONICAL_TO_HOST_VELOCITY_SIGN,
                    )
                    && !self.retained_host_behavior_equivalence_target
            }
            MUJOCO_VELOCITY_SERVO_FORCE_LIMITED_FIVE_SUBSTEP_PROFILE_ID => {
                self.adapter_id == "sporespore_mujoco_adapter"
                    && self.engine_id == "mujoco"
                    && self.native_motor_model_id == "velocity_servo_force_limited_five_substep_v3"
                    && same_float(
                        self.canonical_to_host_velocity_sign,
                        MUJOCO_CANONICAL_TO_HOST_VELOCITY_SIGN,
                    )
                    && !self.retained_host_behavior_equivalence_target
                    && self.host_response_characterized_for_this_profile
            }
            MUJOCO_PER_ACTUATOR_FORCE_LIMITED_FIVE_SUBSTEP_DEVELOPMENT_PROFILE_ID => {
                self.adapter_id == "sporespore_mujoco_adapter"
                    && self.engine_id == "mujoco"
                    && self.native_motor_model_id
                        == "velocity_servo_per_actuator_force_limited_five_substep_development_v1"
                    && same_float(
                        self.canonical_to_host_velocity_sign,
                        MUJOCO_CANONICAL_TO_HOST_VELOCITY_SIGN,
                    )
                    && !self.retained_host_behavior_equivalence_target
                    && !self.host_response_characterized_for_this_profile
            }
            MUJOCO_S169_PER_ACTUATOR_FORCE_LIMITED_FIVE_SUBSTEP_VH5_VALIDATED_PROFILE_ID => {
                self.adapter_id == "sporespore_mujoco_adapter"
                    && self.engine_id == "mujoco"
                    && self.native_motor_model_id
                        == "velocity_servo_s169_per_actuator_force_limited_five_substep_vh5_validated_v1"
                    && same_float(
                        self.canonical_to_host_velocity_sign,
                        MUJOCO_CANONICAL_TO_HOST_VELOCITY_SIGN,
                    )
                    && !self.retained_host_behavior_equivalence_target
                    && self.host_response_characterized_for_this_profile
            }
            _ => false,
        };
        if !identity_matches
            || self.independent_native_position_feedback_applied
            || self.native_position_stiffness != 0.0
            || (!matches!(
                self.profile_id.as_str(),
                MUJOCO_VELOCITY_SERVO_FORCE_LIMITED_FIVE_SUBSTEP_PROFILE_ID
                    | MUJOCO_S169_PER_ACTUATOR_FORCE_LIMITED_FIVE_SUBSTEP_VH5_VALIDATED_PROFILE_ID
            ) && self.host_response_characterized_for_this_profile)
            || self.world_build_count != 0
            || self.physical_acceptance_authority
        {
            return Err(CoreError::Actuation(format!(
                "velocity_only_host_profile:{}",
                self.profile_id
            )));
        }
        Ok(())
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct VelocityOnlyHostActuatorCommandV1 {
    pub actuator_id: String,
    pub requested_target_position_rad: f64,
    pub clamped_target_position_rad: f64,
    pub position_target_role: PositionTargetRoleV1,
    pub native_target_position_rad: Option<f64>,
    pub canonical_target_velocity_rad_s: f64,
    pub host_target_velocity_rad_s: f64,
    pub maximum_host_target_speed_rad_s: f64,
    pub host_clamped: bool,
    pub valid_through_step: u64,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct VelocityOnlyHostMappingReceiptV1 {
    pub schema_version: String,
    pub canonical_profile_id: String,
    pub host_profile_id: String,
    pub adapter_id: String,
    pub engine_id: String,
    pub semantic_step: u64,
    pub canonical_to_host_velocity_sign: f64,
    pub native_motor_model_id: String,
    pub independent_native_position_feedback_applied: bool,
    pub native_position_stiffness: f64,
    pub host_response_characterized_for_this_profile: bool,
    pub ordered_commands: Vec<VelocityOnlyHostActuatorCommandV1>,
    pub safe_no_actuation_preserved: bool,
    pub world_build_count: u32,
    pub physics_state_modified: bool,
    pub physical_acceptance_authority: bool,
}

impl VelocityOnlyHostMappingReceiptV1 {
    pub fn validate(
        &self,
        morphology: &CompiledMorphology,
        canonical: &CanonicalVelocityActuationFrameV1,
        profile: &VelocityOnlyHostProfileV1,
    ) -> Result<()> {
        canonical.validate(morphology)?;
        profile.validate()?;
        if self.schema_version != VELOCITY_ONLY_HOST_MAPPING_RECEIPT_V1_VERSION
            || self.canonical_profile_id != canonical.profile_id
            || self.host_profile_id != profile.profile_id
            || self.adapter_id != profile.adapter_id
            || self.engine_id != profile.engine_id
            || self.semantic_step != canonical.semantic_step
            || !same_float(
                self.canonical_to_host_velocity_sign,
                profile.canonical_to_host_velocity_sign,
            )
            || self.native_motor_model_id != profile.native_motor_model_id
            || self.independent_native_position_feedback_applied
            || self.native_position_stiffness != 0.0
            || self.host_response_characterized_for_this_profile
                != profile.host_response_characterized_for_this_profile
            || !self.safe_no_actuation_preserved
            || self.world_build_count != 0
            || self.physics_state_modified
            || self.physical_acceptance_authority
        {
            return Err(CoreError::Actuation(
                "velocity_only_host_mapping_receipt".to_owned(),
            ));
        }
        require_order(
            self.ordered_commands
                .iter()
                .map(|command| command.actuator_id.as_str()),
            &morphology.ordered_actuator_ids,
            "velocity_only_host_commands",
        )?;
        for (mapped, source) in self
            .ordered_commands
            .iter()
            .zip(&canonical.ordered_commands)
        {
            let expected_host = source.combined_canonical_target_velocity_rad_s
                * profile.canonical_to_host_velocity_sign;
            if mapped.actuator_id != source.actuator_id
                || !same_float(
                    mapped.requested_target_position_rad,
                    source.requested_target_position_rad,
                )
                || !same_float(
                    mapped.clamped_target_position_rad,
                    source.clamped_target_position_rad,
                )
                || mapped.position_target_role != PositionTargetRoleV1::ProvenanceAndBoundsOnly
                || mapped.native_target_position_rad.is_some()
                || !same_float(
                    mapped.canonical_target_velocity_rad_s,
                    source.combined_canonical_target_velocity_rad_s,
                )
                || !same_float(mapped.host_target_velocity_rad_s, expected_host)
                || !same_float(
                    mapped.maximum_host_target_speed_rad_s,
                    source.maximum_target_speed_rad_s,
                )
                || mapped.host_clamped
                || mapped.valid_through_step != source.valid_through_step
            {
                return Err(CoreError::Actuation(format!(
                    "velocity_only_host_command:{}",
                    mapped.actuator_id
                )));
            }
        }
        Ok(())
    }
}

pub fn canonicalize_and_compose_legacy_velocity_v1(
    morphology: &CompiledMorphology,
    source: &ActuationFrame,
    ordered_stability_residuals: &[CanonicalVelocityResidualV1],
) -> Result<CanonicalVelocityActuationFrameV1> {
    source.validate(morphology)?;
    require_order(
        ordered_stability_residuals
            .iter()
            .map(|residual| residual.actuator_id.as_str()),
        &morphology.ordered_actuator_ids,
        "canonical_velocity_residuals",
    )?;
    for residual in ordered_stability_residuals {
        residual.validate()?;
    }
    let ordered_commands = source
        .ordered_commands
        .iter()
        .zip(ordered_stability_residuals)
        .map(|(command, residual)| {
            if source.safe_no_actuation && residual.canonical_velocity_delta_rad_s != 0.0 {
                return Err(CoreError::Actuation(format!(
                    "canonical_velocity_safe_residual:{}",
                    command.actuator_id
                )));
            }
            let portable_canonical_target_velocity_rad_s =
                command.target_velocity_rad_s * LEGACY_GODOT_HOST_TO_CANONICAL_VELOCITY_SIGN;
            let stability_canonical_velocity_delta_rad_s = residual.canonical_velocity_delta_rad_s;
            let unbounded_canonical_target_velocity_rad_s =
                portable_canonical_target_velocity_rad_s + stability_canonical_velocity_delta_rad_s;
            let combined_canonical_target_velocity_rad_s =
                unbounded_canonical_target_velocity_rad_s.clamp(
                    -command.maximum_target_speed_rad_s,
                    command.maximum_target_speed_rad_s,
                );
            Ok(CanonicalVelocityActuatorCommandV1 {
                actuator_id: command.actuator_id.clone(),
                requested_target_position_rad: command.requested_target_position_rad,
                clamped_target_position_rad: command.clamped_target_position_rad,
                position_target_role: PositionTargetRoleV1::ProvenanceAndBoundsOnly,
                source_legacy_host_target_velocity_rad_s: command.target_velocity_rad_s,
                source_legacy_residual_contribution_rad_s: command.residual_contribution_rad_s,
                source_legacy_safety_contribution_rad_s: command.safety_contribution_rad_s,
                portable_canonical_target_velocity_rad_s,
                portable_canonical_residual_contribution_rad_s: command.residual_contribution_rad_s
                    * LEGACY_GODOT_HOST_TO_CANONICAL_VELOCITY_SIGN,
                portable_canonical_safety_contribution_rad_s: command.safety_contribution_rad_s
                    * LEGACY_GODOT_HOST_TO_CANONICAL_VELOCITY_SIGN,
                stability_canonical_velocity_delta_rad_s,
                unbounded_canonical_target_velocity_rad_s,
                combined_canonical_target_velocity_rad_s,
                maximum_target_speed_rad_s: command.maximum_target_speed_rad_s,
                canonical_speed_saturated: combined_canonical_target_velocity_rad_s
                    != unbounded_canonical_target_velocity_rad_s,
                valid_through_step: command.valid_through_step,
            })
        })
        .collect::<Result<Vec<_>>>()?;
    let frame = CanonicalVelocityActuationFrameV1 {
        schema_version: CANONICAL_VELOCITY_ACTUATION_FRAME_V1_VERSION.to_owned(),
        profile_id: COMPLETE_CLOSED_LOOP_CANONICAL_VELOCITY_PROFILE_ID.to_owned(),
        source_velocity_convention_id: LEGACY_GODOT_HOST_VELOCITY_CONVENTION_ID.to_owned(),
        source_policy_id: source.receipt.policy_id.clone(),
        source_actuation_receipt_sha256: source.receipt_sha256.clone(),
        semantic_step: source.semantic_step,
        position_target_role: PositionTargetRoleV1::ProvenanceAndBoundsOnly,
        load_bearing_actuation: LoadBearingActuationV1::CompleteClosedLoopCanonicalTargetVelocity,
        canonical_to_host_mapping_owned_by_adapter: true,
        ordered_commands,
        safe_no_actuation: source.safe_no_actuation,
        failure_codes: source.failure_codes.clone(),
        world_build_count: 0,
        physics_state_modified: false,
        physical_acceptance_authority: false,
    };
    frame.validate(morphology)?;
    Ok(frame)
}

pub fn map_canonical_velocity_to_host_v1(
    morphology: &CompiledMorphology,
    canonical: &CanonicalVelocityActuationFrameV1,
    profile: &VelocityOnlyHostProfileV1,
) -> Result<VelocityOnlyHostMappingReceiptV1> {
    canonical.validate(morphology)?;
    profile.validate()?;
    let ordered_commands = canonical
        .ordered_commands
        .iter()
        .map(|command| VelocityOnlyHostActuatorCommandV1 {
            actuator_id: command.actuator_id.clone(),
            requested_target_position_rad: command.requested_target_position_rad,
            clamped_target_position_rad: command.clamped_target_position_rad,
            position_target_role: PositionTargetRoleV1::ProvenanceAndBoundsOnly,
            native_target_position_rad: None,
            canonical_target_velocity_rad_s: command.combined_canonical_target_velocity_rad_s,
            host_target_velocity_rad_s: command.combined_canonical_target_velocity_rad_s
                * profile.canonical_to_host_velocity_sign,
            maximum_host_target_speed_rad_s: command.maximum_target_speed_rad_s,
            host_clamped: false,
            valid_through_step: command.valid_through_step,
        })
        .collect();
    let receipt = VelocityOnlyHostMappingReceiptV1 {
        schema_version: VELOCITY_ONLY_HOST_MAPPING_RECEIPT_V1_VERSION.to_owned(),
        canonical_profile_id: canonical.profile_id.clone(),
        host_profile_id: profile.profile_id.clone(),
        adapter_id: profile.adapter_id.clone(),
        engine_id: profile.engine_id.clone(),
        semantic_step: canonical.semantic_step,
        canonical_to_host_velocity_sign: profile.canonical_to_host_velocity_sign,
        native_motor_model_id: profile.native_motor_model_id.clone(),
        independent_native_position_feedback_applied: false,
        native_position_stiffness: 0.0,
        host_response_characterized_for_this_profile: profile
            .host_response_characterized_for_this_profile,
        ordered_commands,
        safe_no_actuation_preserved: true,
        world_build_count: 0,
        physics_state_modified: false,
        physical_acceptance_authority: false,
    };
    receipt.validate(morphology, canonical, profile)?;
    Ok(receipt)
}

fn same_float(first: f64, second: f64) -> bool {
    first.to_bits() == second.to_bits()
}

fn require_finite(value: f64, field: &str) -> Result<()> {
    if value.is_finite() {
        Ok(())
    } else {
        Err(CoreError::NonFinite(field.to_owned()))
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

fn require_id(value: &str, field: &str) -> Result<()> {
    let mut characters = value.chars();
    if matches!(characters.next(), Some('a'..='z'))
        && characters.all(|character| {
            character.is_ascii_lowercase() || character.is_ascii_digit() || character == '_'
        })
    {
        Ok(())
    } else {
        Err(CoreError::Identity(format!("{field}:{value}")))
    }
}

fn require_order<'a>(
    actual: impl Iterator<Item = &'a str>,
    expected: &[String],
    field: &str,
) -> Result<()> {
    let actual = actual.collect::<Vec<_>>();
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
    use crate::controller::BALANCED_WAVE_BW15F_B_POLICY_ID;
    use crate::protocol::{
        CommandAuthority, ContactObservation, ContactProvenance, ContactQuality, JointObservation,
        JointValidityMask, MOTION_COMMAND_VERSION, MotionCommand, PhaseProgressionMode, Pose,
        Quaternion, STATE_FRAME_VERSION, SpeedClass, StateFrame, TaskFrame, Twist,
    };
    use crate::quadruped::{
        BoundedQuadrupedDescriptor, CompiledQuadruped, compile_bounded_quadruped,
    };
    use crate::runtime::{BalancedWaveController, BalancedWaveControllerMemory};
    use crate::schema::Vec3;

    fn state(compiled: &CompiledMorphology) -> StateFrame {
        StateFrame {
            schema_version: STATE_FRAME_VERSION.to_owned(),
            semantic_step: 0,
            sample_time_s: 0.0,
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
            ordered_joint_observations: compiled
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
            ordered_contact_observations: compiled
                .ordered_contact_site_ids
                .iter()
                .map(|contact_site_id| ContactObservation {
                    contact_site_id: contact_site_id.clone(),
                    presence: Some(true),
                    bears_support: Some(true),
                    normal_load_n: None,
                    provenance: ContactProvenance {
                        adapter_id: "canonical_actuation_test".to_owned(),
                        engine_contact_ids: vec![format!("{contact_site_id}_contact")],
                        aggregation_rule_id: "qualified_bearing_only".to_owned(),
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
                "sha256:1111111111111111111111111111111111111111111111111111111111111111".to_owned(),
        }
    }

    fn motion_command() -> MotionCommand {
        MotionCommand {
            schema_version: MOTION_COMMAND_VERSION.to_owned(),
            command_id: "canonical_actuation_test".to_owned(),
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
            phase_progression_mode: PhaseProgressionMode::Clocked,
            valid_from_step: 0,
            valid_through_step: 0,
            authority: CommandAuthority::TestFixture,
        }
    }

    fn fixture() -> (CompiledQuadruped, ActuationFrame) {
        let compiled =
            compile_bounded_quadruped(BoundedQuadrupedDescriptor::reference("canonical_actuation"))
                .unwrap();
        let controller = BalancedWaveController::new_for_policy(
            compiled.clone(),
            BALANCED_WAVE_BW15F_B_POLICY_ID,
        )
        .unwrap();
        let output = controller.step(
            &BalancedWaveControllerMemory::initial(),
            &state(&compiled.morphology),
            &motion_command(),
        );
        assert!(!output.actuation.safe_no_actuation);
        (compiled, output.actuation)
    }

    fn zero_residuals(source: &ActuationFrame) -> Vec<CanonicalVelocityResidualV1> {
        source
            .ordered_commands
            .iter()
            .map(|command| CanonicalVelocityResidualV1::exact_zero(&command.actuator_id))
            .collect()
    }

    #[test]
    fn godot_mapping_is_bit_exact_legacy_command_equivalence() {
        let (compiled, source) = fixture();
        let frozen_source = source.clone();
        let canonical = canonicalize_and_compose_legacy_velocity_v1(
            &compiled.morphology,
            &source,
            &zero_residuals(&source),
        )
        .unwrap();
        let profile = VelocityOnlyHostProfileV1::godot_jolt_equivalence_target();
        let mapped =
            map_canonical_velocity_to_host_v1(&compiled.morphology, &canonical, &profile).unwrap();

        assert_eq!(source, frozen_source, "frozen legacy frame was mutated");
        assert!(
            mapped
                .ordered_commands
                .iter()
                .zip(&source.ordered_commands)
                .all(|(mapped, legacy)| {
                    mapped.host_target_velocity_rad_s.to_bits()
                        == legacy.target_velocity_rad_s.to_bits()
                        && mapped.native_target_position_rad.is_none()
                })
        );
        assert!(!mapped.host_response_characterized_for_this_profile);
        assert_eq!(mapped.world_build_count, 0);
        assert!(!mapped.physics_state_modified);
        assert!(!mapped.physical_acceptance_authority);

        let serialized = serde_json::to_string(&mapped).unwrap();
        let round_trip: VelocityOnlyHostMappingReceiptV1 =
            serde_json::from_str(&serialized).unwrap();
        assert_eq!(round_trip, mapped);
    }

    #[test]
    fn rapier_mapping_composes_residual_in_canonical_space_before_host_conversion() {
        let (compiled, source) = fixture();
        let residuals = source
            .ordered_commands
            .iter()
            .enumerate()
            .map(|(index, command)| CanonicalVelocityResidualV1 {
                schema_version: CANONICAL_VELOCITY_RESIDUAL_V1_VERSION.to_owned(),
                actuator_id: command.actuator_id.clone(),
                canonical_velocity_delta_rad_s: if index % 2 == 0 { 0.01 } else { -0.01 },
                command_not_measurement: true,
                physical_acceptance_authority: false,
            })
            .collect::<Vec<_>>();
        let canonical =
            canonicalize_and_compose_legacy_velocity_v1(&compiled.morphology, &source, &residuals)
                .unwrap();
        let profile = VelocityOnlyHostProfileV1::rapier_force_based_velocity_only_target();
        let mapped =
            map_canonical_velocity_to_host_v1(&compiled.morphology, &canonical, &profile).unwrap();

        let nonzero_legacy_commands = source
            .ordered_commands
            .iter()
            .filter(|command| command.target_velocity_rad_s != 0.0)
            .count();
        let mut old_mixed_space_differs = 0;
        for (((legacy, residual), canonical), mapped) in source
            .ordered_commands
            .iter()
            .zip(&residuals)
            .zip(&canonical.ordered_commands)
            .zip(&mapped.ordered_commands)
        {
            let expected_unbounded = legacy.target_velocity_rad_s
                * LEGACY_GODOT_HOST_TO_CANONICAL_VELOCITY_SIGN
                + residual.canonical_velocity_delta_rad_s;
            assert_eq!(
                canonical
                    .unbounded_canonical_target_velocity_rad_s
                    .to_bits(),
                expected_unbounded.to_bits()
            );
            assert_eq!(
                mapped.host_target_velocity_rad_s.to_bits(),
                canonical.combined_canonical_target_velocity_rad_s.to_bits()
            );
            assert!(mapped.native_target_position_rad.is_none());
            let old_mixed = legacy.target_velocity_rad_s + residual.canonical_velocity_delta_rad_s;
            if old_mixed.to_bits() != mapped.host_target_velocity_rad_s.to_bits() {
                old_mixed_space_differs += 1;
            }
        }
        assert_eq!(nonzero_legacy_commands, 5);
        assert_eq!(old_mixed_space_differs, nonzero_legacy_commands);
        assert_eq!(profile.native_position_stiffness, 0.0);
        assert!(!profile.independent_native_position_feedback_applied);
        assert!(!profile.host_response_characterized_for_this_profile);
    }

    #[test]
    fn mujoco_mapping_uses_the_vh4_characterized_velocity_only_identity() {
        let (compiled, source) = fixture();
        let residuals = source
            .ordered_commands
            .iter()
            .enumerate()
            .map(|(index, command)| CanonicalVelocityResidualV1 {
                schema_version: CANONICAL_VELOCITY_RESIDUAL_V1_VERSION.to_owned(),
                actuator_id: command.actuator_id.clone(),
                canonical_velocity_delta_rad_s: if index % 2 == 0 { 0.01 } else { -0.01 },
                command_not_measurement: true,
                physical_acceptance_authority: false,
            })
            .collect::<Vec<_>>();
        let canonical =
            canonicalize_and_compose_legacy_velocity_v1(&compiled.morphology, &source, &residuals)
                .unwrap();
        let profile =
            VelocityOnlyHostProfileV1::mujoco_velocity_servo_force_limited_five_substep_v3();
        let mapped =
            map_canonical_velocity_to_host_v1(&compiled.morphology, &canonical, &profile).unwrap();

        assert!(profile.host_response_characterized_for_this_profile);
        assert_eq!(profile.canonical_to_host_velocity_sign, 1.0);
        assert!(!profile.independent_native_position_feedback_applied);
        assert_eq!(profile.native_position_stiffness, 0.0);
        assert!(mapped.host_response_characterized_for_this_profile);
        assert!(
            mapped
                .ordered_commands
                .iter()
                .zip(&canonical.ordered_commands)
                .all(|(mapped, canonical)| {
                    mapped.host_target_velocity_rad_s.to_bits()
                        == canonical.combined_canonical_target_velocity_rad_s.to_bits()
                        && mapped.native_target_position_rad.is_none()
                })
        );
        assert_eq!(mapped.world_build_count, 0);
        assert!(!mapped.physics_state_modified);
        assert!(!mapped.physical_acceptance_authority);

        let mut falsified = profile;
        falsified.host_response_characterized_for_this_profile = false;
        assert!(matches!(
            map_canonical_velocity_to_host_v1(&compiled.morphology, &canonical, &falsified),
            Err(CoreError::Actuation(_))
        ));

        let development = VelocityOnlyHostProfileV1::
            mujoco_per_actuator_force_limited_five_substep_development_v1();
        let development_mapping =
            map_canonical_velocity_to_host_v1(&compiled.morphology, &canonical, &development)
                .unwrap();
        assert!(!development.host_response_characterized_for_this_profile);
        assert!(!development_mapping.host_response_characterized_for_this_profile);
        assert!(!development_mapping.physical_acceptance_authority);

        let vh5 = VelocityOnlyHostProfileV1::
            mujoco_s169_per_actuator_force_limited_five_substep_vh5_validated_v1();
        let vh5_mapping =
            map_canonical_velocity_to_host_v1(&compiled.morphology, &canonical, &vh5).unwrap();
        assert_eq!(
            vh5.profile_id,
            MUJOCO_S169_PER_ACTUATOR_FORCE_LIMITED_FIVE_SUBSTEP_VH5_VALIDATED_PROFILE_ID
        );
        assert!(vh5.host_response_characterized_for_this_profile);
        assert!(vh5_mapping.host_response_characterized_for_this_profile);
        assert!(
            vh5_mapping
                .ordered_commands
                .iter()
                .all(|command| command.native_target_position_rad.is_none())
        );
        assert!(!vh5_mapping.physical_acceptance_authority);
    }

    #[test]
    fn malformed_residuals_and_host_profiles_fail_closed() {
        let (compiled, source) = fixture();
        let mut residuals = zero_residuals(&source);
        residuals.swap(0, 1);
        assert!(matches!(
            canonicalize_and_compose_legacy_velocity_v1(&compiled.morphology, &source, &residuals,),
            Err(CoreError::Order(_))
        ));

        let mut residuals = zero_residuals(&source);
        residuals[0].canonical_velocity_delta_rad_s = f64::NAN;
        assert!(matches!(
            canonicalize_and_compose_legacy_velocity_v1(&compiled.morphology, &source, &residuals,),
            Err(CoreError::NonFinite(_))
        ));

        let mut residuals = zero_residuals(&source);
        residuals[0].command_not_measurement = false;
        assert!(matches!(
            canonicalize_and_compose_legacy_velocity_v1(&compiled.morphology, &source, &residuals,),
            Err(CoreError::Actuation(_))
        ));

        let canonical = canonicalize_and_compose_legacy_velocity_v1(
            &compiled.morphology,
            &source,
            &zero_residuals(&source),
        )
        .unwrap();
        let mut invalid_sign = VelocityOnlyHostProfileV1::rapier_force_based_velocity_only_target();
        invalid_sign.canonical_to_host_velocity_sign = -1.0;
        assert!(matches!(
            map_canonical_velocity_to_host_v1(&compiled.morphology, &canonical, &invalid_sign,),
            Err(CoreError::Actuation(_))
        ));

        let mut duplicated_position =
            VelocityOnlyHostProfileV1::rapier_force_based_velocity_only_target();
        duplicated_position.independent_native_position_feedback_applied = true;
        duplicated_position.native_position_stiffness = 40.0;
        assert!(matches!(
            map_canonical_velocity_to_host_v1(
                &compiled.morphology,
                &canonical,
                &duplicated_position,
            ),
            Err(CoreError::Actuation(_))
        ));

        let mut false_characterization =
            VelocityOnlyHostProfileV1::rapier_force_based_velocity_only_target();
        false_characterization.host_response_characterized_for_this_profile = true;
        assert!(matches!(
            map_canonical_velocity_to_host_v1(
                &compiled.morphology,
                &canonical,
                &false_characterization,
            ),
            Err(CoreError::Actuation(_))
        ));

        let mut unknown_profile =
            VelocityOnlyHostProfileV1::rapier_force_based_velocity_only_target();
        unknown_profile.profile_id = "unregistered_velocity_only_profile".to_owned();
        assert!(matches!(
            map_canonical_velocity_to_host_v1(&compiled.morphology, &canonical, &unknown_profile,),
            Err(CoreError::Actuation(_))
        ));

        let mut inflated = VelocityOnlyHostProfileV1::rapier_force_based_velocity_only_target();
        inflated.world_build_count = 1;
        inflated.physical_acceptance_authority = true;
        assert!(matches!(
            map_canonical_velocity_to_host_v1(&compiled.morphology, &canonical, &inflated,),
            Err(CoreError::Actuation(_))
        ));
    }

    #[test]
    fn safe_frame_rejects_nonzero_stability_residual() {
        let (compiled, mut source) = fixture();
        source.safe_no_actuation = true;
        for command in &mut source.ordered_commands {
            command.target_velocity_rad_s = 0.0;
            command.residual_contribution_rad_s = 0.0;
            command.safety_contribution_rad_s = 0.0;
        }
        source.validate(&compiled.morphology).unwrap();
        let mut residuals = zero_residuals(&source);
        residuals[0].canonical_velocity_delta_rad_s = 0.01;
        assert!(matches!(
            canonicalize_and_compose_legacy_velocity_v1(&compiled.morphology, &source, &residuals,),
            Err(CoreError::Actuation(_))
        ));
    }
}
