//! Engine-neutral support observation and bounded centroidal command semantics.
//!
//! These routines are pure. They do not read a physics world, infer bearing
//! from contact presence, treat commands as measurements, map endpoint forces
//! to joint actuators, or grant physical acceptance.

use std::collections::{HashMap, HashSet};

use serde::{Deserialize, Serialize};

use crate::protocol::{Pose, Twist};
use crate::schema::{CompiledMorphology, CoreError, Result, Vec3};

pub const STABILITY_STATE_VERSION: &str = "sporespore_stability_state_v2";
pub const CENTROIDAL_REQUEST_VERSION: &str = "sporespore_centroidal_support_request_v2";
pub const CENTROIDAL_COMMAND_VERSION: &str = "sporespore_centroidal_support_command_v2";
pub const STABILITY_INFLUENCE_REQUEST_VERSION: &str = "sporespore_stability_influence_request_v2";
pub const STABILITY_INFLUENCE_RECEIPT_VERSION: &str = "sporespore_stability_influence_receipt_v2";
pub const STABILITY_INFLUENCE_REQUEST_V3_VERSION: &str =
    "sporespore_stability_influence_request_v3";
pub const STABILITY_INFLUENCE_RECEIPT_V3_VERSION: &str =
    "sporespore_stability_influence_receipt_v3";
pub const ENDPOINT_FORCE_JOINT_MAP_REQUEST_VERSION: &str =
    "sporespore_endpoint_force_joint_map_request_v2";
pub const ENDPOINT_FORCE_JOINT_MAP_RECEIPT_VERSION: &str =
    "sporespore_endpoint_force_joint_map_receipt_v2";
pub const ENDPOINT_FORCE_JOINT_MAP_REQUEST_V3_VERSION: &str =
    "sporespore_endpoint_force_joint_map_request_v3";
pub const ENDPOINT_FORCE_JOINT_MAP_RECEIPT_V3_VERSION: &str =
    "sporespore_endpoint_force_joint_map_receipt_v3";
pub const SCHEDULED_LOAD_TRANSFER_REQUEST_VERSION: &str =
    "sporespore_scheduled_load_transfer_request_v1";
pub const SCHEDULED_LOAD_TRANSFER_RECEIPT_VERSION: &str =
    "sporespore_scheduled_load_transfer_receipt_v1";
pub const SCHEDULED_LOAD_TRANSFER_BW9L_A_POLICY_ID: &str =
    "sporespore_scheduled_load_transfer_bw9l_a_v1";
pub const SCHEDULED_LOAD_TRANSFER_BW9L_B_POLICY_ID: &str =
    "sporespore_scheduled_load_transfer_bw9l_b_v1";
pub const SCHEDULED_LOAD_TRANSFER_BW9L_C_POLICY_ID: &str =
    "sporespore_scheduled_load_transfer_bw9l_c_v1";
pub const SCHEDULED_LOAD_TRANSFER_BW9L_D_POLICY_ID: &str =
    "sporespore_scheduled_load_transfer_bw9l_d_v1";
pub const SCHEDULED_LOAD_TRANSFER_REQUEST_V2_VERSION: &str =
    "sporespore_scheduled_load_transfer_request_v2";
pub const SCHEDULED_LOAD_TRANSFER_RECEIPT_V2_VERSION: &str =
    "sporespore_scheduled_load_transfer_receipt_v2";
pub const SCHEDULED_LOAD_TRANSFER_BW10F_A_POLICY_ID: &str =
    "sporespore_scheduled_load_transfer_bw10f_a_v2";
pub const SCHEDULED_LOAD_TRANSFER_BW10F_B_POLICY_ID: &str =
    "sporespore_scheduled_load_transfer_bw10f_b_v2";
pub const SCHEDULED_LOAD_TRANSFER_BW10F_C_POLICY_ID: &str =
    "sporespore_scheduled_load_transfer_bw10f_c_v2";
pub const SCHEDULED_LOAD_TRANSFER_BW10F_D_POLICY_ID: &str =
    "sporespore_scheduled_load_transfer_bw10f_d_v2";
pub const SCHEDULED_LOAD_TRANSFER_REQUEST_V3_VERSION: &str =
    "sporespore_scheduled_load_transfer_request_v3";
pub const SCHEDULED_LOAD_TRANSFER_RECEIPT_V3_VERSION: &str =
    "sporespore_scheduled_load_transfer_receipt_v3";
pub const SCHEDULED_LOAD_TRANSFER_BW11R_A_POLICY_ID: &str =
    "sporespore_scheduled_load_transfer_bw11r_a_v3";
pub const SCHEDULED_LOAD_TRANSFER_BW11R_B_POLICY_ID: &str =
    "sporespore_scheduled_load_transfer_bw11r_b_v3";
pub const SCHEDULED_LOAD_TRANSFER_BW11R_C_POLICY_ID: &str =
    "sporespore_scheduled_load_transfer_bw11r_c_v3";
pub const SCHEDULED_LOAD_TRANSFER_BW11R_D_POLICY_ID: &str =
    "sporespore_scheduled_load_transfer_bw11r_d_v3";
pub const SCHEDULED_LOAD_TRANSFER_BW13P_A_POLICY_ID: &str =
    "sporespore_scheduled_load_transfer_bw13p_a_v3";
pub const SCHEDULED_LOAD_TRANSFER_BW13P_B_POLICY_ID: &str =
    "sporespore_scheduled_load_transfer_bw13p_b_v3";
pub const SCHEDULED_LOAD_TRANSFER_BW13P_C_POLICY_ID: &str =
    "sporespore_scheduled_load_transfer_bw13p_c_v3";
pub const SCHEDULED_LOAD_TRANSFER_BW13P_D_POLICY_ID: &str =
    "sporespore_scheduled_load_transfer_bw13p_d_v3";

const EPSILON: f64 = 1.0e-12;
const CONVEX_TOLERANCE: f64 = 1.0e-9;
const P5I3C_HORIZONTAL_POSITION_GAIN_N_PER_M: f64 = 5.0;
const P5I3C_HORIZONTAL_VELOCITY_GAIN_NS_PER_M: f64 = 0.1;
const P5I3C_MAXIMUM_HORIZONTAL_FORCE_N: f64 = 0.75;
const P5I3C_ROLL_PITCH_POSITION_GAIN_NM_PER_RAD: f64 = 0.5;
const P5I3C_ROLL_PITCH_VELOCITY_GAIN_NM_S_PER_RAD: f64 = 0.05;
const P5I3C_MAXIMUM_ROLL_PITCH_MOMENT_NM: f64 = 0.10;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct OrderedBodyStateV2 {
    pub body_id: String,
    pub pose_world: Pose,
    pub twist_world: Twist,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SupportContactStateV2 {
    pub contact_site_id: String,
    pub presence: Option<bool>,
    pub bears_support: Option<bool>,
    pub point_world_m: Option<Vec3>,
    pub normal_world_unit: Option<Vec3>,
    pub surface_relative_velocity_world_m_s: Option<Vec3>,
    pub material_id: Option<String>,
    pub adapter_id: String,
    pub engine_contact_ids: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct StabilityStateV2 {
    pub schema_version: String,
    pub semantic_step: u64,
    pub ordered_body_states: Vec<OrderedBodyStateV2>,
    pub ordered_support_contacts: Vec<SupportContactStateV2>,
    pub gravity_world_m_s2: Vec3,
    pub support_plane_forward_world_unit: Vec3,
    pub adapter_capability_sha256: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SupportGeometryKind {
    Point,
    Segment,
    Polygon,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SupportObservationV2 {
    pub schema_version: String,
    pub semantic_step: u64,
    pub whole_system_mass_kg: f64,
    pub center_of_mass_world_m: Vec3,
    pub center_of_mass_velocity_world_m_s: Vec3,
    pub support_plane_up_world_unit: Vec3,
    pub support_plane_forward_world_unit: Vec3,
    pub support_plane_lateral_world_unit: Vec3,
    pub support_plane_height_m: f64,
    pub center_of_mass_height_above_support_m: f64,
    pub linearized_natural_frequency_rad_s: f64,
    pub linearized_capture_point_world_m: Vec3,
    pub support_centroid_world_m: Vec3,
    pub support_vertices_plane_m: Vec<[f64; 2]>,
    pub support_geometry_dimension: u8,
    pub support_geometry_kind: SupportGeometryKind,
    pub support_polygon_available: bool,
    pub center_of_mass_margin_m: f64,
    pub linearized_capture_margin_m: f64,
    pub support_centroid_margin_m: f64,
    pub minimum_dynamic_support_margin_m: f64,
    pub center_of_mass_inside_or_boundary: bool,
    pub linearized_capture_inside_or_boundary: bool,
    pub qualified_support_contact_ids: Vec<String>,
    pub rejected_contact_count: usize,
    pub hull_uses_geometric_order_not_semantic_order: bool,
    pub linearized_capture_model_only: bool,
    pub articulated_capture_guarantee_available: bool,
    pub per_foot_measured_load_allocation_available: bool,
    pub contact_presence_is_bearing_measurement: bool,
    pub physics_state_modified: bool,
    pub physical_acceptance_authority: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ScheduledLoadTransferModeV1 {
    Control,
    PreferredNormalForce,
    RemainingSupportCentroid,
    Combined,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ScheduledLimbGaitStepV1 {
    pub limb_id: String,
    pub gait_step: u64,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ScheduledLoadTransferRequestV1 {
    pub schema_version: String,
    pub policy_id: String,
    pub gait_amplitude: f64,
    pub cycle_steps: u64,
    pub swing_steps: u64,
    pub characterized_friction_coefficient: f64,
    pub maximum_normal_force_n: f64,
    pub feasibility_tolerance: f64,
    pub ordered_limb_gait_steps: Vec<ScheduledLimbGaitStepV1>,
    pub stability_state: StabilityStateV2,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ScheduledLoadTransferContactPreferenceV1 {
    pub contact_id: String,
    pub preferred_normal_force_n: f64,
    pub scheduled_unweighted: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ScheduledLoadTransferReceiptV1 {
    pub schema_version: String,
    pub semantic_step: u64,
    pub policy_id: String,
    pub mode: ScheduledLoadTransferModeV1,
    pub active: bool,
    pub activation_reason: String,
    pub scheduled_limb_id: Option<String>,
    pub scheduled_local_phase_step: Option<u64>,
    pub ordered_scheduled_unweighted_contact_ids: Vec<String>,
    pub qualified_support_contact_ids: Vec<String>,
    pub remaining_support_contact_ids: Vec<String>,
    pub baseline_target_center_of_mass_world_m: Vec3,
    pub target_center_of_mass_world_m: Vec3,
    pub remaining_support_centroid_world_m: Option<Vec3>,
    pub ordered_contact_preferences: Vec<ScheduledLoadTransferContactPreferenceV1>,
    pub centroidal_request: CentroidalSupportRequestV2,
    pub centroidal_command: CentroidalSupportCommandV2,
    pub activation_uses_scheduler_boundaries_only: bool,
    pub morphology_branch_surface_count: usize,
    pub per_foot_measured_load_allocation_available: bool,
    pub commands_are_measurements: bool,
    pub adapter_actuation_applied: bool,
    pub physics_state_modified: bool,
    pub walking_claim_authorized: bool,
    pub physical_acceptance_authority: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ScheduledLoadTransferRequestV2 {
    pub schema_version: String,
    pub policy_id: String,
    pub gait_amplitude: f64,
    pub cycle_steps: u64,
    pub swing_steps: u64,
    pub characterized_friction_coefficient: f64,
    pub maximum_normal_force_n: f64,
    pub feasibility_tolerance: f64,
    pub ordered_limb_gait_steps: Vec<ScheduledLimbGaitStepV1>,
    pub stability_state: StabilityStateV2,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ScheduledLoadTransferReceiptV2 {
    pub schema_version: String,
    pub semantic_step: u64,
    pub policy_id: String,
    pub mode: ScheduledLoadTransferModeV1,
    pub planning_availability: StabilityInfluenceAvailability,
    pub planning_outcome_code: String,
    pub fail_zero_required: bool,
    pub active: bool,
    pub activation_reason: String,
    pub scheduled_limb_id: Option<String>,
    pub scheduled_local_phase_step: Option<u64>,
    pub ordered_scheduled_unweighted_contact_ids: Vec<String>,
    pub qualified_support_contact_ids: Vec<String>,
    pub remaining_support_contact_ids: Vec<String>,
    pub baseline_target_center_of_mass_world_m: Option<Vec3>,
    pub target_center_of_mass_world_m: Option<Vec3>,
    pub remaining_support_centroid_world_m: Option<Vec3>,
    pub ordered_contact_preferences: Vec<ScheduledLoadTransferContactPreferenceV1>,
    pub centroidal_request: Option<CentroidalSupportRequestV2>,
    pub centroidal_command: Option<CentroidalSupportCommandV2>,
    pub ordered_safe_zero_actuator_ids: Vec<String>,
    pub activation_uses_scheduler_boundaries_only: bool,
    pub morphology_branch_surface_count: usize,
    pub per_foot_measured_load_allocation_available: bool,
    pub commands_are_measurements: bool,
    pub adapter_actuation_applied: bool,
    pub physics_state_modified: bool,
    pub walking_claim_authorized: bool,
    pub physical_acceptance_authority: bool,
}

/// Additive scheduled-load-transfer request that keeps receipt authority in
/// the portable core even when the host cannot emit a usable observation.
///
/// `semantic_step` and scheduler state remain mandatory in both paths. When
/// `observation_available` is true, `stability_state` is mandatory and the
/// request delegates to the frozen v2 semantics. When it is false, a nonempty
/// `observation_unavailable_reason` is mandatory and `stability_state` may be
/// absent or may carry the host's ordered but unusable state for audit.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ScheduledLoadTransferRequestV3 {
    pub schema_version: String,
    pub policy_id: String,
    pub semantic_step: u64,
    pub observation_available: bool,
    pub observation_unavailable_reason: Option<String>,
    pub gait_amplitude: f64,
    pub cycle_steps: u64,
    pub swing_steps: u64,
    pub characterized_friction_coefficient: f64,
    pub maximum_normal_force_n: f64,
    pub feasibility_tolerance: f64,
    pub ordered_limb_gait_steps: Vec<ScheduledLimbGaitStepV1>,
    pub stability_state: Option<StabilityStateV2>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ScheduledLoadTransferReceiptV3 {
    pub schema_version: String,
    pub semantic_step: u64,
    pub policy_id: String,
    pub mode: ScheduledLoadTransferModeV1,
    pub observation_input_available: bool,
    pub observation_unavailable_reason: Option<String>,
    pub planning_availability: StabilityInfluenceAvailability,
    pub planning_outcome_code: String,
    pub fail_zero_required: bool,
    pub active: bool,
    pub activation_reason: String,
    pub scheduled_limb_id: Option<String>,
    pub scheduled_local_phase_step: Option<u64>,
    pub ordered_scheduled_unweighted_contact_ids: Vec<String>,
    pub qualified_support_contact_ids: Vec<String>,
    pub remaining_support_contact_ids: Vec<String>,
    pub baseline_target_center_of_mass_world_m: Option<Vec3>,
    pub target_center_of_mass_world_m: Option<Vec3>,
    pub remaining_support_centroid_world_m: Option<Vec3>,
    pub ordered_contact_preferences: Vec<ScheduledLoadTransferContactPreferenceV1>,
    pub centroidal_request: Option<CentroidalSupportRequestV2>,
    pub centroidal_command: Option<CentroidalSupportCommandV2>,
    pub ordered_safe_zero_actuator_ids: Vec<String>,
    pub activation_uses_scheduler_boundaries_only: bool,
    pub morphology_branch_surface_count: usize,
    pub per_foot_measured_load_allocation_available: bool,
    pub commands_are_measurements: bool,
    pub adapter_actuation_applied: bool,
    pub physics_state_modified: bool,
    pub walking_claim_authorized: bool,
    pub physical_acceptance_authority: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CentroidalSupportContactV2 {
    pub contact_id: String,
    pub point_world_m: Vec3,
    #[serde(default)]
    pub preferred_normal_force_n: f64,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CentroidalSupportRequestV2 {
    pub schema_version: String,
    pub semantic_step: u64,
    pub whole_system_mass_kg: f64,
    pub gravity_world_m_s2: Vec3,
    pub support_plane_forward_world_unit: Vec3,
    pub center_of_mass_world_m: Vec3,
    pub center_of_mass_velocity_world_m_s: Vec3,
    pub target_center_of_mass_world_m: Vec3,
    pub torso_roll_rad: f64,
    pub torso_pitch_rad: f64,
    pub torso_roll_rate_rad_s: f64,
    pub torso_pitch_rate_rad_s: f64,
    pub horizontal_position_gain_n_per_m: f64,
    pub horizontal_velocity_gain_ns_per_m: f64,
    pub vertical_position_gain_n_per_m: f64,
    pub vertical_velocity_gain_ns_per_m: f64,
    pub roll_position_gain_nm_per_rad: f64,
    pub roll_velocity_gain_nm_s_per_rad: f64,
    pub pitch_position_gain_nm_per_rad: f64,
    pub pitch_velocity_gain_nm_s_per_rad: f64,
    pub maximum_horizontal_force_n: f64,
    pub maximum_vertical_correction_n: f64,
    pub maximum_roll_pitch_moment_nm: f64,
    pub declared_supported_weight_fraction: f64,
    pub characterized_friction_coefficient: f64,
    pub minimum_normal_force_n: f64,
    pub maximum_normal_force_n: f64,
    pub nominal_support_count: usize,
    pub feasibility_tolerance: f64,
    pub support_contacts: Vec<CentroidalSupportContactV2>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CentroidalContactCommandV2 {
    pub contact_id: String,
    pub external_force_command_world_n: Vec3,
    pub joint_task_force_delta_world_n: Vec3,
    pub normal_force_command_n: f64,
    pub tangential_force_command_n: f64,
    pub friction_limit_n: f64,
    pub command_not_measurement: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CentroidalSupportCommandV2 {
    pub schema_version: String,
    pub semantic_step: u64,
    pub feasible: bool,
    pub infeasibility_reasons: Vec<String>,
    pub desired_external_force_world_n: Vec3,
    pub desired_external_roll_pitch_moment_world_nm: Vec3,
    pub achieved_external_force_world_n: Vec3,
    pub achieved_external_moment_world_nm: Vec3,
    pub force_residual_n: Vec3,
    pub roll_pitch_moment_residual_nm: [f64; 2],
    pub minimum_normal_reserve_n: f64,
    pub minimum_friction_reserve_n: f64,
    pub ordered_support_contact_commands: Vec<CentroidalContactCommandV2>,
    pub characterized_friction_is_adapter_provenance: bool,
    pub per_contact_values_are_commands_not_measurements: bool,
    pub per_foot_measured_load_allocation_available: bool,
    pub actuator_mapping_available: bool,
    pub physics_state_modified: bool,
    pub physical_acceptance_authority: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct EndpointForceActuatorKinematicsV2 {
    pub actuator_id: String,
    pub contact_site_id: String,
    pub joint_anchor_world_m: Vec3,
    pub joint_axis_world_unit: Vec3,
    pub endpoint_world_m: Vec3,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct EndpointForceJointMapRequestV2 {
    pub schema_version: String,
    pub semantic_step: u64,
    pub centroidal_command: CentroidalSupportCommandV2,
    pub ordered_actuator_kinematics: Vec<EndpointForceActuatorKinematicsV2>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct GeneralizedJointTorqueCommandV2 {
    pub actuator_id: String,
    pub contact_site_id: String,
    pub linear_jacobian_column_world_m: Vec3,
    pub endpoint_task_force_command_world_n: Vec3,
    pub generalized_torque_command_nm: f64,
    pub command_not_measurement: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct EndpointForceJointMapReceiptV2 {
    pub schema_version: String,
    pub semantic_step: u64,
    pub ordered_generalized_joint_torque_commands: Vec<GeneralizedJointTorqueCommandV2>,
    pub endpoint_force_map_available: bool,
    pub measured_joint_torque_available: bool,
    pub actuator_response_characterized: bool,
    pub adapter_actuation_applied: bool,
    pub physics_state_modified: bool,
    pub physical_acceptance_authority: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum EndpointForceJointMappingModeV3 {
    SupportCommand,
    InactiveContactZero,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct EndpointForceJointMapRequestV3 {
    pub schema_version: String,
    pub semantic_step: u64,
    pub centroidal_command: CentroidalSupportCommandV2,
    pub ordered_actuator_kinematics: Vec<EndpointForceActuatorKinematicsV2>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct GeneralizedJointTorqueCommandV3 {
    pub actuator_id: String,
    pub contact_site_id: String,
    pub mapping_mode: EndpointForceJointMappingModeV3,
    pub active_support_contact: bool,
    pub linear_jacobian_column_world_m: Vec3,
    pub endpoint_task_force_command_world_n: Vec3,
    pub generalized_torque_command_nm: f64,
    pub inactive_contact_forced_zero: bool,
    pub command_not_measurement: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct EndpointForceJointMapReceiptV3 {
    pub schema_version: String,
    pub semantic_step: u64,
    pub ordered_active_support_contact_ids: Vec<String>,
    pub ordered_generalized_joint_torque_commands: Vec<GeneralizedJointTorqueCommandV3>,
    pub active_actuator_count: usize,
    pub inactive_actuator_count: usize,
    pub endpoint_force_map_available: bool,
    pub partial_support_mapping_available: bool,
    pub inactive_contact_commands_forced_zero: bool,
    pub measured_joint_torque_available: bool,
    pub actuator_response_characterized: bool,
    pub adapter_actuation_applied: bool,
    pub physics_state_modified: bool,
    pub physical_acceptance_authority: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum StabilityInfluenceAvailability {
    Available,
    ObservationUnavailable,
    UpstreamInfeasible,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RequestedStabilityCorrectionV2 {
    pub actuator_id: String,
    pub requested_position_delta_rad: Option<f64>,
    pub requested_velocity_delta_rad_s: Option<f64>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct PreviousStabilityCorrectionV2 {
    pub actuator_id: String,
    pub applied_position_delta_rad: f64,
    pub applied_velocity_delta_rad_s: f64,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct StabilityInfluenceRequestV2 {
    pub schema_version: String,
    pub semantic_step: u64,
    pub availability: StabilityInfluenceAvailability,
    pub maximum_absolute_position_delta_rad: f64,
    pub maximum_absolute_velocity_delta_rad_s: f64,
    pub maximum_position_delta_slew_per_step_rad: f64,
    pub maximum_velocity_delta_slew_per_step_rad_s: f64,
    pub ordered_requested_corrections: Vec<RequestedStabilityCorrectionV2>,
    pub previous_semantic_step: Option<u64>,
    pub ordered_previous_applied_corrections: Option<Vec<PreviousStabilityCorrectionV2>>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct AppliedStabilityCorrectionV2 {
    pub actuator_id: String,
    pub requested_position_delta_rad: Option<f64>,
    pub requested_velocity_delta_rad_s: Option<f64>,
    pub applied_position_delta_rad: f64,
    pub applied_velocity_delta_rad_s: f64,
    pub magnitude_saturated: bool,
    pub slew_limited: bool,
    pub fallback_zeroed: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct StabilityInfluenceReceiptV2 {
    pub schema_version: String,
    pub semantic_step: u64,
    pub availability: StabilityInfluenceAvailability,
    pub ordered_applied_corrections: Vec<AppliedStabilityCorrectionV2>,
    pub any_magnitude_saturation: bool,
    pub any_slew_limiting: bool,
    pub fallback_applied: bool,
    pub fallback_bypasses_slew_to_reach_zero: bool,
    pub corrections_are_bounded_contributions_not_complete_actuation: bool,
    pub adapter_actuation_applied: bool,
    pub physics_state_modified: bool,
    pub physical_acceptance_authority: bool,
}

/// Additive portable residual-scaling request.
///
/// The scale is applied to every available requested correction before the
/// existing v2 magnitude and slew limiters. A single global value keeps the
/// operation branch-free with respect to morphology, material, seed, failure
/// identity, and outcome. Unavailable observations continue to bypass slew and
/// fail directly to exact zero.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct StabilityInfluenceRequestV3 {
    pub schema_version: String,
    pub semantic_step: u64,
    pub availability: StabilityInfluenceAvailability,
    pub global_requested_correction_scale: f64,
    pub maximum_absolute_position_delta_rad: f64,
    pub maximum_absolute_velocity_delta_rad_s: f64,
    pub maximum_position_delta_slew_per_step_rad: f64,
    pub maximum_velocity_delta_slew_per_step_rad_s: f64,
    pub ordered_requested_corrections: Vec<RequestedStabilityCorrectionV2>,
    pub previous_semantic_step: Option<u64>,
    pub ordered_previous_applied_corrections: Option<Vec<PreviousStabilityCorrectionV2>>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct AppliedStabilityCorrectionV3 {
    pub actuator_id: String,
    pub raw_requested_position_delta_rad: Option<f64>,
    pub raw_requested_velocity_delta_rad_s: Option<f64>,
    pub scaled_requested_position_delta_rad: Option<f64>,
    pub scaled_requested_velocity_delta_rad_s: Option<f64>,
    pub applied_position_delta_rad: f64,
    pub applied_velocity_delta_rad_s: f64,
    pub magnitude_saturated: bool,
    pub slew_limited: bool,
    pub fallback_zeroed: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct StabilityInfluenceReceiptV3 {
    pub schema_version: String,
    pub semantic_step: u64,
    pub availability: StabilityInfluenceAvailability,
    pub global_requested_correction_scale: f64,
    pub ordered_applied_corrections: Vec<AppliedStabilityCorrectionV3>,
    pub any_nonzero_raw_request: bool,
    pub any_nonzero_scaled_request: bool,
    pub any_magnitude_saturation: bool,
    pub any_slew_limiting: bool,
    pub fallback_applied: bool,
    pub fallback_bypasses_slew_to_reach_zero: bool,
    pub global_scale_applied_before_magnitude_and_slew: bool,
    pub corrections_are_bounded_contributions_not_complete_actuation: bool,
    pub adapter_actuation_applied: bool,
    pub physics_state_modified: bool,
    pub physical_acceptance_authority: bool,
}

#[derive(Clone, Copy, Debug)]
struct PlanePoint {
    forward: f64,
    lateral: f64,
}

impl PlanePoint {
    fn cross(self, other: Self) -> f64 {
        self.forward * other.lateral - self.lateral * other.forward
    }

    fn subtract(self, other: Self) -> Self {
        Self {
            forward: self.forward - other.forward,
            lateral: self.lateral - other.lateral,
        }
    }

    fn add(self, other: Self) -> Self {
        Self {
            forward: self.forward + other.forward,
            lateral: self.lateral + other.lateral,
        }
    }

    fn scale(self, scalar: f64) -> Self {
        Self {
            forward: self.forward * scalar,
            lateral: self.lateral * scalar,
        }
    }

    fn dot(self, other: Self) -> f64 {
        self.forward * other.forward + self.lateral * other.lateral
    }

    fn norm_squared(self) -> f64 {
        self.dot(self)
    }

    fn norm(self) -> f64 {
        self.norm_squared().sqrt()
    }
}

#[derive(Clone, Copy)]
struct SupportFrame {
    up: Vec3,
    forward: Vec3,
    lateral: Vec3,
    gravity_m_s2: f64,
}

pub fn observe_stability_v2(
    morphology: &CompiledMorphology,
    state: &StabilityStateV2,
) -> Result<SupportObservationV2> {
    if state.schema_version != STABILITY_STATE_VERSION {
        return Err(CoreError::Schema("stability_state_version".to_owned()));
    }
    require_digest(
        &state.adapter_capability_sha256,
        "stability.adapter_capability_sha256",
    )?;
    let frame = support_frame(
        state.gravity_world_m_s2,
        state.support_plane_forward_world_unit,
    )?;
    validate_body_order(morphology, &state.ordered_body_states)?;

    let mut whole_mass_kg = 0.0;
    let mut weighted_position = Vec3::ZERO;
    let mut weighted_velocity = Vec3::ZERO;
    for (spec, body) in morphology
        .morphology_spec
        .bodies
        .iter()
        .zip(&state.ordered_body_states)
    {
        body.pose_world
            .position_m
            .finite("stability.body.pose.position")?;
        body.pose_world
            .orientation_xyzw
            .validate("stability.body.pose.orientation")?;
        body.twist_world
            .linear_velocity_m_s
            .finite("stability.body.twist.linear")?;
        body.twist_world
            .angular_velocity_rad_s
            .finite("stability.body.twist.angular")?;
        let offset_world = rotate_vector(
            body.pose_world.orientation_xyzw,
            spec.center_of_mass_local_m,
        );
        let com_world = add(body.pose_world.position_m, offset_world);
        let com_velocity_world = add(
            body.twist_world.linear_velocity_m_s,
            cross(body.twist_world.angular_velocity_rad_s, offset_world),
        );
        whole_mass_kg += spec.mass_kg;
        weighted_position = add(weighted_position, scale(com_world, spec.mass_kg));
        weighted_velocity = add(weighted_velocity, scale(com_velocity_world, spec.mass_kg));
    }
    if !whole_mass_kg.is_finite() || whole_mass_kg <= 0.0 {
        return Err(CoreError::Frame("stability_mass_invalid".to_owned()));
    }
    let center_of_mass = scale(weighted_position, 1.0 / whole_mass_kg);
    let center_of_mass_velocity = scale(weighted_velocity, 1.0 / whole_mass_kg);

    let contacts = qualified_support_contacts(&state.ordered_support_contacts)?;
    if contacts.is_empty() {
        return Err(CoreError::Contact(
            "stability_qualified_support_set_empty".to_owned(),
        ));
    }
    let rejected_contact_count = state.ordered_support_contacts.len() - contacts.len();
    let mut projected = Vec::with_capacity(contacts.len());
    let mut mean_height_m = 0.0;
    let mut qualified_support_contact_ids = Vec::with_capacity(contacts.len());
    for contact in contacts {
        let point = contact
            .point_world_m
            .expect("qualified support validation requires a point");
        projected.push(project_to_plane(point, frame));
        mean_height_m += dot(point, frame.up);
        qualified_support_contact_ids.push(contact.contact_site_id.clone());
    }
    mean_height_m /= projected.len() as f64;
    let hull = convex_hull(projected);
    let (geometry_dimension, geometry_kind) = match hull.len() {
        1 => (0, SupportGeometryKind::Point),
        2 => (1, SupportGeometryKind::Segment),
        _ => (2, SupportGeometryKind::Polygon),
    };
    let centroid_plane = support_centroid(&hull, geometry_dimension)?;
    let support_centroid = lift_from_plane(centroid_plane, mean_height_m, frame);
    let center_of_mass_height_m = dot(center_of_mass, frame.up) - mean_height_m;
    if !center_of_mass_height_m.is_finite() || center_of_mass_height_m <= EPSILON {
        return Err(CoreError::Frame("stability_com_height_invalid".to_owned()));
    }
    let natural_frequency = (frame.gravity_m_s2 / center_of_mass_height_m).sqrt();
    if !natural_frequency.is_finite() || natural_frequency <= 0.0 {
        return Err(CoreError::Frame(
            "stability_natural_frequency_invalid".to_owned(),
        ));
    }
    let horizontal_com_velocity = subtract(
        center_of_mass_velocity,
        scale(frame.up, dot(center_of_mass_velocity, frame.up)),
    );
    let capture_point = add(
        center_of_mass,
        scale(horizontal_com_velocity, 1.0 / natural_frequency),
    );
    let center_plane = project_to_plane(center_of_mass, frame);
    let capture_plane = project_to_plane(capture_point, frame);
    let center_margin = support_margin(center_plane, &hull, geometry_dimension);
    let capture_margin = support_margin(capture_plane, &hull, geometry_dimension);
    let centroid_margin = support_margin(centroid_plane, &hull, geometry_dimension);

    Ok(SupportObservationV2 {
        schema_version: "sporespore_support_observation_v2".to_owned(),
        semantic_step: state.semantic_step,
        whole_system_mass_kg: whole_mass_kg,
        center_of_mass_world_m: center_of_mass,
        center_of_mass_velocity_world_m_s: center_of_mass_velocity,
        support_plane_up_world_unit: frame.up,
        support_plane_forward_world_unit: frame.forward,
        support_plane_lateral_world_unit: frame.lateral,
        support_plane_height_m: mean_height_m,
        center_of_mass_height_above_support_m: center_of_mass_height_m,
        linearized_natural_frequency_rad_s: natural_frequency,
        linearized_capture_point_world_m: capture_point,
        support_centroid_world_m: support_centroid,
        support_vertices_plane_m: hull
            .iter()
            .map(|point| [point.forward, point.lateral])
            .collect(),
        support_geometry_dimension: geometry_dimension,
        support_geometry_kind: geometry_kind,
        support_polygon_available: geometry_dimension == 2,
        center_of_mass_margin_m: center_margin,
        linearized_capture_margin_m: capture_margin,
        support_centroid_margin_m: centroid_margin,
        minimum_dynamic_support_margin_m: center_margin.min(capture_margin),
        center_of_mass_inside_or_boundary: center_margin >= -CONVEX_TOLERANCE,
        linearized_capture_inside_or_boundary: capture_margin >= -CONVEX_TOLERANCE,
        qualified_support_contact_ids,
        rejected_contact_count,
        hull_uses_geometric_order_not_semantic_order: true,
        linearized_capture_model_only: true,
        articulated_capture_guarantee_available: false,
        per_foot_measured_load_allocation_available: false,
        contact_presence_is_bearing_measurement: false,
        physics_state_modified: false,
        physical_acceptance_authority: false,
    })
}

pub fn plan_scheduled_load_transfer_v1(
    morphology: &CompiledMorphology,
    request: &ScheduledLoadTransferRequestV1,
) -> Result<ScheduledLoadTransferReceiptV1> {
    if request.schema_version != SCHEDULED_LOAD_TRANSFER_REQUEST_VERSION {
        return Err(CoreError::Schema(
            "scheduled_load_transfer_request_version".to_owned(),
        ));
    }
    let mode = match request.policy_id.as_str() {
        SCHEDULED_LOAD_TRANSFER_BW9L_A_POLICY_ID => ScheduledLoadTransferModeV1::Control,
        SCHEDULED_LOAD_TRANSFER_BW9L_B_POLICY_ID => {
            ScheduledLoadTransferModeV1::PreferredNormalForce
        }
        SCHEDULED_LOAD_TRANSFER_BW9L_C_POLICY_ID => {
            ScheduledLoadTransferModeV1::RemainingSupportCentroid
        }
        SCHEDULED_LOAD_TRANSFER_BW9L_D_POLICY_ID => ScheduledLoadTransferModeV1::Combined,
        _ => {
            return Err(CoreError::Identity(format!(
                "scheduled_load_transfer_policy_id:{}",
                request.policy_id
            )));
        }
    };
    if !request.gait_amplitude.is_finite() || !(0.0..=1.0).contains(&request.gait_amplitude) {
        return Err(CoreError::Schema(
            "scheduled_load_transfer_gait_amplitude".to_owned(),
        ));
    }
    if request.cycle_steps == 0
        || request.swing_steps == 0
        || request.swing_steps >= request.cycle_steps
    {
        return Err(CoreError::Schema(
            "scheduled_load_transfer_phase_bounds".to_owned(),
        ));
    }
    for (value, field, strictly_positive) in [
        (
            request.characterized_friction_coefficient,
            "scheduled_load_transfer_friction",
            false,
        ),
        (
            request.maximum_normal_force_n,
            "scheduled_load_transfer_maximum_normal_force",
            true,
        ),
        (
            request.feasibility_tolerance,
            "scheduled_load_transfer_feasibility_tolerance",
            true,
        ),
    ] {
        if !value.is_finite() || value < 0.0 || (strictly_positive && value <= 0.0) {
            return Err(CoreError::NonFinite(field.to_owned()));
        }
    }
    require_actuator_order(
        &morphology.ordered_limb_ids,
        request
            .ordered_limb_gait_steps
            .iter()
            .map(|limb| limb.limb_id.as_str()),
        "scheduled_load_transfer_limb",
    )?;
    require_actuator_order(
        &morphology.ordered_contact_site_ids,
        request
            .stability_state
            .ordered_support_contacts
            .iter()
            .map(|contact| contact.contact_site_id.as_str()),
        "scheduled_load_transfer_contact",
    )?;

    let observation = observe_stability_v2(morphology, &request.stability_state)?;
    let frame = support_frame(
        request.stability_state.gravity_world_m_s2,
        request.stability_state.support_plane_forward_world_unit,
    )?;
    let baseline_target_center_of_mass_world_m = add(
        observation.center_of_mass_world_m,
        scale(
            frame.lateral,
            dot(
                subtract(
                    observation.support_centroid_world_m,
                    observation.center_of_mass_world_m,
                ),
                frame.lateral,
            ),
        ),
    );

    let qualified_contact_ids = observation.qualified_support_contact_ids.clone();
    let qualified_set = qualified_contact_ids
        .iter()
        .map(String::as_str)
        .collect::<HashSet<_>>();
    let point_by_contact_id = request
        .stability_state
        .ordered_support_contacts
        .iter()
        .filter_map(|contact| {
            contact
                .point_world_m
                .map(|point| (contact.contact_site_id.as_str(), point))
        })
        .collect::<HashMap<_, _>>();
    let expected_support_contact_ids = morphology
        .morphology_spec
        .contact_sites
        .iter()
        .filter(|contact| contact.can_support)
        .map(|contact| contact.contact_site_id.as_str())
        .collect::<Vec<_>>();
    let full_support = qualified_contact_ids.len() == expected_support_contact_ids.len()
        && expected_support_contact_ids
            .iter()
            .all(|contact_id| qualified_set.contains(contact_id));

    let mut scheduled_candidates = Vec::new();
    if request.gait_amplitude > 0.0 && full_support {
        for (limb, gait) in morphology
            .morphology_spec
            .limbs
            .iter()
            .zip(&request.ordered_limb_gait_steps)
        {
            let phase_offset = limb.nominal_phase_fraction * request.cycle_steps as f64;
            let rounded_phase_offset = phase_offset.round();
            if (phase_offset - rounded_phase_offset).abs() > 1.0e-9 {
                return Err(CoreError::Time(format!(
                    "scheduled_load_transfer_fractional_phase:{}",
                    limb.limb_id
                )));
            }
            let phase_offset_step = rounded_phase_offset as u64 % request.cycle_steps;
            let local_phase_step =
                (gait.gait_step + request.cycle_steps - phase_offset_step) % request.cycle_steps;
            let all_limb_contacts_bear = limb
                .ordered_contact_site_ids
                .iter()
                .all(|contact_id| qualified_set.contains(contact_id.as_str()));
            if local_phase_step < request.swing_steps && all_limb_contacts_bear {
                scheduled_candidates.push((limb, local_phase_step));
            }
        }
    }

    let intervention_requested = mode != ScheduledLoadTransferModeV1::Control;
    let (mut active, mut activation_reason) = if !intervention_requested {
        (false, "control_policy".to_owned())
    } else if request.gait_amplitude == 0.0 {
        (false, "zero_gait_amplitude".to_owned())
    } else if !full_support {
        (false, "qualified_support_not_full".to_owned())
    } else if scheduled_candidates.is_empty() {
        (false, "no_loaded_swing_limb".to_owned())
    } else if scheduled_candidates.len() > 1 {
        (false, "multiple_loaded_swing_limbs".to_owned())
    } else {
        (true, "scheduled_loaded_swing_limb".to_owned())
    };

    let mut scheduled_limb_id = None;
    let mut scheduled_local_phase_step = None;
    let mut scheduled_unweighted_contact_ids = Vec::new();
    if active {
        let (limb, local_phase_step) = scheduled_candidates[0];
        scheduled_limb_id = Some(limb.limb_id.clone());
        scheduled_local_phase_step = Some(local_phase_step);
        scheduled_unweighted_contact_ids = limb.ordered_contact_site_ids.clone();
    }
    let unweighted_set = scheduled_unweighted_contact_ids
        .iter()
        .map(String::as_str)
        .collect::<HashSet<_>>();
    let mut remaining_support_contact_ids = qualified_contact_ids
        .iter()
        .filter(|contact_id| !unweighted_set.contains(contact_id.as_str()))
        .cloned()
        .collect::<Vec<_>>();
    if active && remaining_support_contact_ids.len() < 3 {
        active = false;
        activation_reason = "remaining_support_count_below_three".to_owned();
        scheduled_limb_id = None;
        scheduled_local_phase_step = None;
        scheduled_unweighted_contact_ids.clear();
        remaining_support_contact_ids = qualified_contact_ids.clone();
    }

    let remaining_support_centroid_world_m = if active {
        let mut projected = Vec::with_capacity(remaining_support_contact_ids.len());
        let mut mean_height_m = 0.0;
        for contact_id in &remaining_support_contact_ids {
            let point = point_by_contact_id
                .get(contact_id.as_str())
                .ok_or_else(|| {
                    CoreError::Contact(format!(
                        "scheduled_load_transfer_contact_point:{contact_id}"
                    ))
                })?;
            projected.push(project_to_plane(*point, frame));
            mean_height_m += dot(*point, frame.up);
        }
        mean_height_m /= projected.len() as f64;
        let hull = convex_hull(projected);
        let dimension = match hull.len() {
            1 => 0,
            2 => 1,
            _ => 2,
        };
        Some(lift_from_plane(
            support_centroid(&hull, dimension)?,
            mean_height_m,
            frame,
        ))
    } else {
        None
    };
    let use_remaining_centroid = active
        && matches!(
            mode,
            ScheduledLoadTransferModeV1::RemainingSupportCentroid
                | ScheduledLoadTransferModeV1::Combined
        );
    let target_center_of_mass_world_m = if use_remaining_centroid {
        let centroid = remaining_support_centroid_world_m
            .expect("active scheduled load transfer has a remaining support centroid");
        add(
            observation.center_of_mass_world_m,
            scale(
                frame.lateral,
                dot(
                    subtract(centroid, observation.center_of_mass_world_m),
                    frame.lateral,
                ),
            ),
        )
    } else {
        baseline_target_center_of_mass_world_m
    };

    let use_preferred_normal_force = active
        && matches!(
            mode,
            ScheduledLoadTransferModeV1::PreferredNormalForce
                | ScheduledLoadTransferModeV1::Combined
        );
    let preferred_stance_normal_force_n = if use_preferred_normal_force {
        observation.whole_system_mass_kg * frame.gravity_m_s2
            / remaining_support_contact_ids.len() as f64
    } else {
        0.0
    };
    let active_unweighted_set = scheduled_unweighted_contact_ids
        .iter()
        .map(String::as_str)
        .collect::<HashSet<_>>();
    let mut ordered_contact_preferences = Vec::with_capacity(qualified_contact_ids.len());
    let mut support_contacts = Vec::with_capacity(qualified_contact_ids.len());
    for contact_id in &qualified_contact_ids {
        let scheduled_unweighted = active_unweighted_set.contains(contact_id.as_str());
        let preferred_normal_force_n = if use_preferred_normal_force && !scheduled_unweighted {
            preferred_stance_normal_force_n
        } else {
            0.0
        };
        let point_world_m = *point_by_contact_id
            .get(contact_id.as_str())
            .ok_or_else(|| {
                CoreError::Contact(format!(
                    "scheduled_load_transfer_contact_point:{contact_id}"
                ))
            })?;
        ordered_contact_preferences.push(ScheduledLoadTransferContactPreferenceV1 {
            contact_id: contact_id.clone(),
            preferred_normal_force_n,
            scheduled_unweighted,
        });
        support_contacts.push(CentroidalSupportContactV2 {
            contact_id: contact_id.clone(),
            point_world_m,
            preferred_normal_force_n,
        });
    }

    let (root_spec_index, _) = morphology
        .morphology_spec
        .bodies
        .iter()
        .enumerate()
        .find(|(_, body)| body.parent_body_id.is_none())
        .ok_or_else(|| CoreError::Topology("scheduled_load_transfer_root_body".to_owned()))?;
    let root_body = &request.stability_state.ordered_body_states[root_spec_index];
    let torso_up = rotate_vector(
        root_body.pose_world.orientation_xyzw,
        Vec3 {
            x: 0.0,
            y: 1.0,
            z: 0.0,
        },
    );
    let upright_component = dot(torso_up, frame.up);
    let torso_roll_rad = dot(torso_up, frame.lateral).atan2(upright_component);
    let torso_pitch_rad = (-dot(torso_up, frame.forward)).atan2(upright_component);
    let torso_roll_rate_rad_s = dot(root_body.twist_world.angular_velocity_rad_s, frame.forward);
    let torso_pitch_rate_rad_s = dot(root_body.twist_world.angular_velocity_rad_s, frame.lateral);
    let centroidal_request = CentroidalSupportRequestV2 {
        schema_version: CENTROIDAL_REQUEST_VERSION.to_owned(),
        semantic_step: request.stability_state.semantic_step,
        whole_system_mass_kg: observation.whole_system_mass_kg,
        gravity_world_m_s2: request.stability_state.gravity_world_m_s2,
        support_plane_forward_world_unit: request.stability_state.support_plane_forward_world_unit,
        center_of_mass_world_m: observation.center_of_mass_world_m,
        center_of_mass_velocity_world_m_s: observation.center_of_mass_velocity_world_m_s,
        target_center_of_mass_world_m,
        torso_roll_rad,
        torso_pitch_rad,
        torso_roll_rate_rad_s,
        torso_pitch_rate_rad_s,
        horizontal_position_gain_n_per_m: P5I3C_HORIZONTAL_POSITION_GAIN_N_PER_M,
        horizontal_velocity_gain_ns_per_m: P5I3C_HORIZONTAL_VELOCITY_GAIN_NS_PER_M,
        vertical_position_gain_n_per_m: 0.0,
        vertical_velocity_gain_ns_per_m: 0.0,
        roll_position_gain_nm_per_rad: P5I3C_ROLL_PITCH_POSITION_GAIN_NM_PER_RAD,
        roll_velocity_gain_nm_s_per_rad: P5I3C_ROLL_PITCH_VELOCITY_GAIN_NM_S_PER_RAD,
        pitch_position_gain_nm_per_rad: P5I3C_ROLL_PITCH_POSITION_GAIN_NM_PER_RAD,
        pitch_velocity_gain_nm_s_per_rad: P5I3C_ROLL_PITCH_VELOCITY_GAIN_NM_S_PER_RAD,
        maximum_horizontal_force_n: P5I3C_MAXIMUM_HORIZONTAL_FORCE_N,
        maximum_vertical_correction_n: 0.0,
        maximum_roll_pitch_moment_nm: P5I3C_MAXIMUM_ROLL_PITCH_MOMENT_NM,
        declared_supported_weight_fraction: 1.0,
        characterized_friction_coefficient: request.characterized_friction_coefficient,
        minimum_normal_force_n: 0.0,
        maximum_normal_force_n: request.maximum_normal_force_n,
        nominal_support_count: expected_support_contact_ids.len(),
        feasibility_tolerance: request.feasibility_tolerance,
        support_contacts,
    };
    let centroidal_command = command_centroidal_support_v2(&centroidal_request)?;

    Ok(ScheduledLoadTransferReceiptV1 {
        schema_version: SCHEDULED_LOAD_TRANSFER_RECEIPT_VERSION.to_owned(),
        semantic_step: request.stability_state.semantic_step,
        policy_id: request.policy_id.clone(),
        mode,
        active,
        activation_reason,
        scheduled_limb_id,
        scheduled_local_phase_step,
        ordered_scheduled_unweighted_contact_ids: scheduled_unweighted_contact_ids,
        qualified_support_contact_ids: qualified_contact_ids,
        remaining_support_contact_ids,
        baseline_target_center_of_mass_world_m,
        target_center_of_mass_world_m,
        remaining_support_centroid_world_m,
        ordered_contact_preferences,
        centroidal_request,
        centroidal_command,
        activation_uses_scheduler_boundaries_only: true,
        morphology_branch_surface_count: 0,
        per_foot_measured_load_allocation_available: false,
        commands_are_measurements: false,
        adapter_actuation_applied: false,
        physics_state_modified: false,
        walking_claim_authorized: false,
        physical_acceptance_authority: false,
    })
}

pub fn plan_scheduled_load_transfer_v2(
    morphology: &CompiledMorphology,
    request: &ScheduledLoadTransferRequestV2,
) -> Result<ScheduledLoadTransferReceiptV2> {
    if request.schema_version != SCHEDULED_LOAD_TRANSFER_REQUEST_V2_VERSION {
        return Err(CoreError::Schema(
            "scheduled_load_transfer_request_v2_version".to_owned(),
        ));
    }
    let (mode, v1_policy_id) = match request.policy_id.as_str() {
        SCHEDULED_LOAD_TRANSFER_BW10F_A_POLICY_ID => (
            ScheduledLoadTransferModeV1::Control,
            SCHEDULED_LOAD_TRANSFER_BW9L_A_POLICY_ID,
        ),
        SCHEDULED_LOAD_TRANSFER_BW10F_B_POLICY_ID => (
            ScheduledLoadTransferModeV1::PreferredNormalForce,
            SCHEDULED_LOAD_TRANSFER_BW9L_B_POLICY_ID,
        ),
        SCHEDULED_LOAD_TRANSFER_BW10F_C_POLICY_ID => (
            ScheduledLoadTransferModeV1::RemainingSupportCentroid,
            SCHEDULED_LOAD_TRANSFER_BW9L_C_POLICY_ID,
        ),
        SCHEDULED_LOAD_TRANSFER_BW10F_D_POLICY_ID => (
            ScheduledLoadTransferModeV1::Combined,
            SCHEDULED_LOAD_TRANSFER_BW9L_D_POLICY_ID,
        ),
        _ => {
            return Err(CoreError::Identity(format!(
                "scheduled_load_transfer_v2_policy_id:{}",
                request.policy_id
            )));
        }
    };
    let v1_request = ScheduledLoadTransferRequestV1 {
        schema_version: SCHEDULED_LOAD_TRANSFER_REQUEST_VERSION.to_owned(),
        policy_id: v1_policy_id.to_owned(),
        gait_amplitude: request.gait_amplitude,
        cycle_steps: request.cycle_steps,
        swing_steps: request.swing_steps,
        characterized_friction_coefficient: request.characterized_friction_coefficient,
        maximum_normal_force_n: request.maximum_normal_force_n,
        feasibility_tolerance: request.feasibility_tolerance,
        ordered_limb_gait_steps: request.ordered_limb_gait_steps.clone(),
        stability_state: request.stability_state.clone(),
    };
    match plan_scheduled_load_transfer_v1(morphology, &v1_request) {
        Ok(receipt) => {
            let feasible = receipt.centroidal_command.feasible;
            let planning_availability = if feasible {
                StabilityInfluenceAvailability::Available
            } else {
                StabilityInfluenceAvailability::UpstreamInfeasible
            };
            let planning_outcome_code = if feasible {
                "AVAILABLE".to_owned()
            } else {
                format!(
                    "UPSTREAM_INFEASIBLE:{}",
                    receipt.centroidal_command.infeasibility_reasons.join(",")
                )
            };
            let fail_zero_required = !feasible;
            let ordered_safe_zero_actuator_ids = if fail_zero_required {
                morphology.ordered_actuator_ids.clone()
            } else {
                Vec::new()
            };
            Ok(ScheduledLoadTransferReceiptV2 {
                schema_version: SCHEDULED_LOAD_TRANSFER_RECEIPT_V2_VERSION.to_owned(),
                semantic_step: receipt.semantic_step,
                policy_id: request.policy_id.clone(),
                mode,
                planning_availability,
                planning_outcome_code,
                fail_zero_required,
                active: receipt.active && feasible,
                activation_reason: if feasible {
                    receipt.activation_reason
                } else {
                    "centroidal_command_infeasible".to_owned()
                },
                scheduled_limb_id: if feasible {
                    receipt.scheduled_limb_id
                } else {
                    None
                },
                scheduled_local_phase_step: if feasible {
                    receipt.scheduled_local_phase_step
                } else {
                    None
                },
                ordered_scheduled_unweighted_contact_ids: if feasible {
                    receipt.ordered_scheduled_unweighted_contact_ids
                } else {
                    Vec::new()
                },
                qualified_support_contact_ids: receipt.qualified_support_contact_ids,
                remaining_support_contact_ids: receipt.remaining_support_contact_ids,
                baseline_target_center_of_mass_world_m: Some(
                    receipt.baseline_target_center_of_mass_world_m,
                ),
                target_center_of_mass_world_m: Some(receipt.target_center_of_mass_world_m),
                remaining_support_centroid_world_m: receipt.remaining_support_centroid_world_m,
                ordered_contact_preferences: receipt.ordered_contact_preferences,
                centroidal_request: Some(receipt.centroidal_request),
                centroidal_command: Some(receipt.centroidal_command),
                ordered_safe_zero_actuator_ids,
                activation_uses_scheduler_boundaries_only: true,
                morphology_branch_surface_count: 0,
                per_foot_measured_load_allocation_available: false,
                commands_are_measurements: false,
                adapter_actuation_applied: false,
                physics_state_modified: false,
                walking_claim_authorized: false,
                physical_acceptance_authority: false,
            })
        }
        Err(error) if is_expected_scheduled_load_transfer_unavailable(&error) => {
            let observation = observe_stability_v2(morphology, &request.stability_state)?;
            let qualified_support_contact_ids = observation.qualified_support_contact_ids.clone();
            Ok(ScheduledLoadTransferReceiptV2 {
                schema_version: SCHEDULED_LOAD_TRANSFER_RECEIPT_V2_VERSION.to_owned(),
                semantic_step: request.stability_state.semantic_step,
                policy_id: request.policy_id.clone(),
                mode,
                planning_availability: StabilityInfluenceAvailability::ObservationUnavailable,
                planning_outcome_code: format!("PLANNING_UNAVAILABLE:{error}"),
                fail_zero_required: true,
                active: false,
                activation_reason: "centroidal_plan_unavailable".to_owned(),
                scheduled_limb_id: None,
                scheduled_local_phase_step: None,
                ordered_scheduled_unweighted_contact_ids: Vec::new(),
                qualified_support_contact_ids: qualified_support_contact_ids.clone(),
                remaining_support_contact_ids: qualified_support_contact_ids,
                baseline_target_center_of_mass_world_m: None,
                target_center_of_mass_world_m: None,
                remaining_support_centroid_world_m: None,
                ordered_contact_preferences: Vec::new(),
                centroidal_request: None,
                centroidal_command: None,
                ordered_safe_zero_actuator_ids: morphology.ordered_actuator_ids.clone(),
                activation_uses_scheduler_boundaries_only: true,
                morphology_branch_surface_count: 0,
                per_foot_measured_load_allocation_available: false,
                commands_are_measurements: false,
                adapter_actuation_applied: false,
                physics_state_modified: false,
                walking_claim_authorized: false,
                physical_acceptance_authority: false,
            })
        }
        Err(error) => Err(error),
    }
}

pub fn plan_scheduled_load_transfer_v3(
    morphology: &CompiledMorphology,
    request: &ScheduledLoadTransferRequestV3,
) -> Result<ScheduledLoadTransferReceiptV3> {
    if request.schema_version != SCHEDULED_LOAD_TRANSFER_REQUEST_V3_VERSION {
        return Err(CoreError::Schema(
            "scheduled_load_transfer_request_v3_version".to_owned(),
        ));
    }
    let (mode, v2_policy_id, progressive_mass_conserving) = match request.policy_id.as_str() {
        SCHEDULED_LOAD_TRANSFER_BW11R_A_POLICY_ID => (
            ScheduledLoadTransferModeV1::Control,
            SCHEDULED_LOAD_TRANSFER_BW10F_A_POLICY_ID,
            false,
        ),
        SCHEDULED_LOAD_TRANSFER_BW11R_B_POLICY_ID => (
            ScheduledLoadTransferModeV1::PreferredNormalForce,
            SCHEDULED_LOAD_TRANSFER_BW10F_B_POLICY_ID,
            false,
        ),
        SCHEDULED_LOAD_TRANSFER_BW11R_C_POLICY_ID => (
            ScheduledLoadTransferModeV1::RemainingSupportCentroid,
            SCHEDULED_LOAD_TRANSFER_BW10F_C_POLICY_ID,
            false,
        ),
        SCHEDULED_LOAD_TRANSFER_BW11R_D_POLICY_ID => (
            ScheduledLoadTransferModeV1::Combined,
            SCHEDULED_LOAD_TRANSFER_BW10F_D_POLICY_ID,
            false,
        ),
        SCHEDULED_LOAD_TRANSFER_BW13P_A_POLICY_ID => (
            ScheduledLoadTransferModeV1::Control,
            SCHEDULED_LOAD_TRANSFER_BW10F_D_POLICY_ID,
            true,
        ),
        SCHEDULED_LOAD_TRANSFER_BW13P_B_POLICY_ID => (
            ScheduledLoadTransferModeV1::PreferredNormalForce,
            SCHEDULED_LOAD_TRANSFER_BW10F_D_POLICY_ID,
            true,
        ),
        SCHEDULED_LOAD_TRANSFER_BW13P_C_POLICY_ID => (
            ScheduledLoadTransferModeV1::RemainingSupportCentroid,
            SCHEDULED_LOAD_TRANSFER_BW10F_D_POLICY_ID,
            true,
        ),
        SCHEDULED_LOAD_TRANSFER_BW13P_D_POLICY_ID => (
            ScheduledLoadTransferModeV1::Combined,
            SCHEDULED_LOAD_TRANSFER_BW10F_D_POLICY_ID,
            true,
        ),
        _ => {
            return Err(CoreError::Identity(format!(
                "scheduled_load_transfer_v3_policy_id:{}",
                request.policy_id
            )));
        }
    };
    validate_scheduled_load_transfer_v3_common(morphology, request)?;

    if request.observation_available {
        if request.observation_unavailable_reason.is_some() {
            return Err(CoreError::Schema(
                "scheduled_load_transfer_v3_available_with_unavailable_reason".to_owned(),
            ));
        }
        let stability_state = request.stability_state.as_ref().ok_or_else(|| {
            CoreError::Schema("scheduled_load_transfer_v3_available_without_state".to_owned())
        })?;
        let receipt = if progressive_mass_conserving {
            plan_progressive_mass_conserving_transfer_v2(
                morphology,
                request,
                mode,
                stability_state,
            )?
        } else {
            let v2_request = ScheduledLoadTransferRequestV2 {
                schema_version: SCHEDULED_LOAD_TRANSFER_REQUEST_V2_VERSION.to_owned(),
                policy_id: v2_policy_id.to_owned(),
                gait_amplitude: request.gait_amplitude,
                cycle_steps: request.cycle_steps,
                swing_steps: request.swing_steps,
                characterized_friction_coefficient: request.characterized_friction_coefficient,
                maximum_normal_force_n: request.maximum_normal_force_n,
                feasibility_tolerance: request.feasibility_tolerance,
                ordered_limb_gait_steps: request.ordered_limb_gait_steps.clone(),
                stability_state: stability_state.clone(),
            };
            plan_scheduled_load_transfer_v2(morphology, &v2_request)?
        };
        return Ok(scheduled_load_transfer_v3_from_v2(request, mode, receipt));
    }

    let unavailable_reason = request
        .observation_unavailable_reason
        .as_deref()
        .map(str::trim)
        .filter(|reason| !reason.is_empty())
        .ok_or_else(|| {
            CoreError::Schema("scheduled_load_transfer_v3_unavailable_without_reason".to_owned())
        })?;
    Ok(ScheduledLoadTransferReceiptV3 {
        schema_version: SCHEDULED_LOAD_TRANSFER_RECEIPT_V3_VERSION.to_owned(),
        semantic_step: request.semantic_step,
        policy_id: request.policy_id.clone(),
        mode,
        observation_input_available: false,
        observation_unavailable_reason: Some(unavailable_reason.to_owned()),
        planning_availability: StabilityInfluenceAvailability::ObservationUnavailable,
        planning_outcome_code: format!("OBSERVATION_UNAVAILABLE:{unavailable_reason}"),
        fail_zero_required: true,
        active: false,
        activation_reason: "stability_observation_unavailable".to_owned(),
        scheduled_limb_id: None,
        scheduled_local_phase_step: None,
        ordered_scheduled_unweighted_contact_ids: Vec::new(),
        qualified_support_contact_ids: Vec::new(),
        remaining_support_contact_ids: Vec::new(),
        baseline_target_center_of_mass_world_m: None,
        target_center_of_mass_world_m: None,
        remaining_support_centroid_world_m: None,
        ordered_contact_preferences: Vec::new(),
        centroidal_request: None,
        centroidal_command: None,
        ordered_safe_zero_actuator_ids: morphology.ordered_actuator_ids.clone(),
        activation_uses_scheduler_boundaries_only: true,
        morphology_branch_surface_count: 0,
        per_foot_measured_load_allocation_available: false,
        commands_are_measurements: false,
        adapter_actuation_applied: false,
        physics_state_modified: false,
        walking_claim_authorized: false,
        physical_acceptance_authority: false,
    })
}

fn scheduled_load_transfer_v3_from_v2(
    request: &ScheduledLoadTransferRequestV3,
    mode: ScheduledLoadTransferModeV1,
    receipt: ScheduledLoadTransferReceiptV2,
) -> ScheduledLoadTransferReceiptV3 {
    ScheduledLoadTransferReceiptV3 {
        schema_version: SCHEDULED_LOAD_TRANSFER_RECEIPT_V3_VERSION.to_owned(),
        semantic_step: receipt.semantic_step,
        policy_id: request.policy_id.clone(),
        mode,
        observation_input_available: true,
        observation_unavailable_reason: None,
        planning_availability: receipt.planning_availability,
        planning_outcome_code: receipt.planning_outcome_code,
        fail_zero_required: receipt.fail_zero_required,
        active: receipt.active,
        activation_reason: receipt.activation_reason,
        scheduled_limb_id: receipt.scheduled_limb_id,
        scheduled_local_phase_step: receipt.scheduled_local_phase_step,
        ordered_scheduled_unweighted_contact_ids: receipt.ordered_scheduled_unweighted_contact_ids,
        qualified_support_contact_ids: receipt.qualified_support_contact_ids,
        remaining_support_contact_ids: receipt.remaining_support_contact_ids,
        baseline_target_center_of_mass_world_m: receipt.baseline_target_center_of_mass_world_m,
        target_center_of_mass_world_m: receipt.target_center_of_mass_world_m,
        remaining_support_centroid_world_m: receipt.remaining_support_centroid_world_m,
        ordered_contact_preferences: receipt.ordered_contact_preferences,
        centroidal_request: receipt.centroidal_request,
        centroidal_command: receipt.centroidal_command,
        ordered_safe_zero_actuator_ids: receipt.ordered_safe_zero_actuator_ids,
        activation_uses_scheduler_boundaries_only: receipt
            .activation_uses_scheduler_boundaries_only,
        morphology_branch_surface_count: receipt.morphology_branch_surface_count,
        per_foot_measured_load_allocation_available: receipt
            .per_foot_measured_load_allocation_available,
        commands_are_measurements: receipt.commands_are_measurements,
        adapter_actuation_applied: receipt.adapter_actuation_applied,
        physics_state_modified: receipt.physics_state_modified,
        walking_claim_authorized: receipt.walking_claim_authorized,
        physical_acceptance_authority: receipt.physical_acceptance_authority,
    }
}

/// Build BW13P from BW9L-D's scheduler and support-partition result, not from
/// BW10F-D's feasibility verdict. BW10F-D evaluates a different, full-transfer
/// command. Treating that verdict as a prerequisite could censor a valid
/// progressive command before the progressive preferences were evaluated.
fn plan_progressive_mass_conserving_transfer_v2(
    morphology: &CompiledMorphology,
    request: &ScheduledLoadTransferRequestV3,
    mode: ScheduledLoadTransferModeV1,
    stability_state: &StabilityStateV2,
) -> Result<ScheduledLoadTransferReceiptV2> {
    let raw_request = ScheduledLoadTransferRequestV1 {
        schema_version: SCHEDULED_LOAD_TRANSFER_REQUEST_VERSION.to_owned(),
        policy_id: SCHEDULED_LOAD_TRANSFER_BW9L_D_POLICY_ID.to_owned(),
        gait_amplitude: request.gait_amplitude,
        cycle_steps: request.cycle_steps,
        swing_steps: request.swing_steps,
        characterized_friction_coefficient: request.characterized_friction_coefficient,
        maximum_normal_force_n: request.maximum_normal_force_n,
        feasibility_tolerance: request.feasibility_tolerance,
        ordered_limb_gait_steps: request.ordered_limb_gait_steps.clone(),
        stability_state: stability_state.clone(),
    };
    match plan_scheduled_load_transfer_v1(morphology, &raw_request) {
        Ok(raw) => {
            let mut receipt = ScheduledLoadTransferReceiptV2 {
                schema_version: SCHEDULED_LOAD_TRANSFER_RECEIPT_V2_VERSION.to_owned(),
                semantic_step: raw.semantic_step,
                policy_id: request.policy_id.clone(),
                mode,
                // These fields are deliberately transient. The progressive
                // command below replaces the old full-transfer command and
                // authors the only exposed feasibility verdict.
                planning_availability: StabilityInfluenceAvailability::Available,
                planning_outcome_code: "PENDING_PROGRESSIVE_COMMAND".to_owned(),
                fail_zero_required: false,
                active: raw.active,
                activation_reason: raw.activation_reason,
                scheduled_limb_id: raw.scheduled_limb_id,
                scheduled_local_phase_step: raw.scheduled_local_phase_step,
                ordered_scheduled_unweighted_contact_ids: raw
                    .ordered_scheduled_unweighted_contact_ids,
                qualified_support_contact_ids: raw.qualified_support_contact_ids,
                remaining_support_contact_ids: raw.remaining_support_contact_ids,
                baseline_target_center_of_mass_world_m: Some(
                    raw.baseline_target_center_of_mass_world_m,
                ),
                target_center_of_mass_world_m: Some(raw.target_center_of_mass_world_m),
                remaining_support_centroid_world_m: raw.remaining_support_centroid_world_m,
                ordered_contact_preferences: raw.ordered_contact_preferences,
                centroidal_request: Some(raw.centroidal_request),
                centroidal_command: Some(raw.centroidal_command),
                ordered_safe_zero_actuator_ids: Vec::new(),
                activation_uses_scheduler_boundaries_only: raw
                    .activation_uses_scheduler_boundaries_only,
                morphology_branch_surface_count: raw.morphology_branch_surface_count,
                per_foot_measured_load_allocation_available: raw
                    .per_foot_measured_load_allocation_available,
                commands_are_measurements: raw.commands_are_measurements,
                adapter_actuation_applied: raw.adapter_actuation_applied,
                physics_state_modified: raw.physics_state_modified,
                walking_claim_authorized: raw.walking_claim_authorized,
                physical_acceptance_authority: raw.physical_acceptance_authority,
            };
            apply_progressive_mass_conserving_transfer(
                morphology,
                request,
                mode,
                stability_state,
                &mut receipt,
            )?;
            Ok(receipt)
        }
        Err(error) if is_expected_scheduled_load_transfer_unavailable(&error) => {
            // Reuse v2's frozen typed-safe-zero translation for structural
            // observation failures. This path cannot expose an old command.
            let unavailable_request = ScheduledLoadTransferRequestV2 {
                schema_version: SCHEDULED_LOAD_TRANSFER_REQUEST_V2_VERSION.to_owned(),
                policy_id: SCHEDULED_LOAD_TRANSFER_BW10F_D_POLICY_ID.to_owned(),
                gait_amplitude: request.gait_amplitude,
                cycle_steps: request.cycle_steps,
                swing_steps: request.swing_steps,
                characterized_friction_coefficient: request.characterized_friction_coefficient,
                maximum_normal_force_n: request.maximum_normal_force_n,
                feasibility_tolerance: request.feasibility_tolerance,
                ordered_limb_gait_steps: request.ordered_limb_gait_steps.clone(),
                stability_state: stability_state.clone(),
            };
            plan_scheduled_load_transfer_v2(morphology, &unavailable_request)
        }
        Err(error) => Err(error),
    }
}

/// Apply a branch-free, phase-continuous load-transfer policy to the typed v2
/// plan. Every available support contact begins with an equal share of the
/// commanded weight. During one unambiguous loaded-swing interval, the
/// preferred-normal-force factor transfers that share continuously from the
/// scheduled contact to the remaining contacts while preserving the total
/// preferred normal force. The centroid factor continuously interpolates only
/// the gravity-plane lateral target from the all-support centroid toward the
/// remaining-support centroid.
///
/// The interpolation parameter is smoothstep(local swing progress). It uses
/// only the scheduler's already-declared cycle and swing bounds: there is no
/// morphology, material, seed, failure-cell, or outcome-conditioned branch and
/// no new fitted numeric threshold.
fn apply_progressive_mass_conserving_transfer(
    morphology: &CompiledMorphology,
    request: &ScheduledLoadTransferRequestV3,
    mode: ScheduledLoadTransferModeV1,
    stability_state: &StabilityStateV2,
    receipt: &mut ScheduledLoadTransferReceiptV2,
) -> Result<()> {
    let raw_active = receipt.active;
    let raw_scheduled_limb_id = receipt.scheduled_limb_id.clone();
    let raw_scheduled_local_phase_step = receipt.scheduled_local_phase_step;
    let raw_unweighted_contact_ids = receipt.ordered_scheduled_unweighted_contact_ids.clone();
    let raw_remaining_support_contact_ids = receipt.remaining_support_contact_ids.clone();
    let raw_remaining_support_centroid_world_m = receipt.remaining_support_centroid_world_m;
    let experimental_factor_active = raw_active && mode != ScheduledLoadTransferModeV1::Control;

    let local_phase_fraction = if raw_active {
        let local_phase_step = raw_scheduled_local_phase_step.ok_or_else(|| {
            CoreError::Internal(
                "progressive_load_transfer_active_without_local_phase_step".to_owned(),
            )
        })?;
        if request.swing_steps <= 1 {
            1.0
        } else {
            local_phase_step as f64 / (request.swing_steps - 1) as f64
        }
        .clamp(0.0, 1.0)
    } else {
        0.0
    };
    let transfer_progress =
        local_phase_fraction * local_phase_fraction * (3.0 - 2.0 * local_phase_fraction);

    let mut centroidal_request = receipt.centroidal_request.clone().ok_or_else(|| {
        CoreError::Internal("progressive_load_transfer_missing_centroidal_request".to_owned())
    })?;
    let baseline_target = receipt
        .baseline_target_center_of_mass_world_m
        .ok_or_else(|| {
            CoreError::Internal("progressive_load_transfer_missing_baseline_target".to_owned())
        })?;
    let use_remaining_centroid = experimental_factor_active
        && matches!(
            mode,
            ScheduledLoadTransferModeV1::RemainingSupportCentroid
                | ScheduledLoadTransferModeV1::Combined
        );
    let target_center_of_mass_world_m = if use_remaining_centroid {
        let remaining_centroid = raw_remaining_support_centroid_world_m.ok_or_else(|| {
            CoreError::Internal(
                "progressive_load_transfer_active_without_remaining_centroid".to_owned(),
            )
        })?;
        let frame = support_frame(
            stability_state.gravity_world_m_s2,
            stability_state.support_plane_forward_world_unit,
        )?;
        add(
            baseline_target,
            scale(
                frame.lateral,
                transfer_progress
                    * dot(subtract(remaining_centroid, baseline_target), frame.lateral),
            ),
        )
    } else {
        baseline_target
    };

    let qualified_contact_count = receipt.qualified_support_contact_ids.len();
    if qualified_contact_count == 0 {
        return Err(CoreError::Internal(
            "progressive_load_transfer_available_without_support".to_owned(),
        ));
    }
    let commanded_weight_n =
        centroidal_request.whole_system_mass_kg * norm(centroidal_request.gravity_world_m_s2);
    let uniform_preference_n = commanded_weight_n / qualified_contact_count as f64;
    let use_progressive_normal_preference = experimental_factor_active
        && matches!(
            mode,
            ScheduledLoadTransferModeV1::PreferredNormalForce
                | ScheduledLoadTransferModeV1::Combined
        );
    let unweighted_set = raw_unweighted_contact_ids
        .iter()
        .map(String::as_str)
        .collect::<HashSet<_>>();
    let remaining_count = raw_remaining_support_contact_ids.len();
    if use_progressive_normal_preference && (unweighted_set.is_empty() || remaining_count == 0) {
        return Err(CoreError::Internal(
            "progressive_load_transfer_invalid_support_partition".to_owned(),
        ));
    }
    let scheduled_preference_n = uniform_preference_n * (1.0 - transfer_progress);
    let scheduled_preference_total_n = scheduled_preference_n * unweighted_set.len() as f64;
    let remaining_preference_n = if use_progressive_normal_preference {
        (commanded_weight_n - scheduled_preference_total_n) / remaining_count as f64
    } else {
        uniform_preference_n
    };

    let mut preference_by_contact_id = HashMap::new();
    for contact_id in &receipt.qualified_support_contact_ids {
        let preferred_normal_force_n = if use_progressive_normal_preference {
            if unweighted_set.contains(contact_id.as_str()) {
                scheduled_preference_n
            } else {
                remaining_preference_n
            }
        } else {
            uniform_preference_n
        };
        preference_by_contact_id.insert(contact_id.clone(), preferred_normal_force_n);
    }
    for contact in &mut receipt.ordered_contact_preferences {
        contact.preferred_normal_force_n = *preference_by_contact_id
            .get(contact.contact_id.as_str())
            .ok_or_else(|| {
                CoreError::Order(format!(
                    "progressive_load_transfer_preference_contact:{}",
                    contact.contact_id
                ))
            })?;
        contact.scheduled_unweighted =
            experimental_factor_active && unweighted_set.contains(contact.contact_id.as_str());
    }
    for contact in &mut centroidal_request.support_contacts {
        contact.preferred_normal_force_n = *preference_by_contact_id
            .get(contact.contact_id.as_str())
            .ok_or_else(|| {
                CoreError::Order(format!(
                    "progressive_load_transfer_centroidal_contact:{}",
                    contact.contact_id
                ))
            })?;
    }
    centroidal_request.target_center_of_mass_world_m = target_center_of_mass_world_m;
    let centroidal_command = command_centroidal_support_v2(&centroidal_request)?;
    let feasible = centroidal_command.feasible;

    receipt.planning_availability = if feasible {
        StabilityInfluenceAvailability::Available
    } else {
        StabilityInfluenceAvailability::UpstreamInfeasible
    };
    receipt.planning_outcome_code = if feasible {
        "AVAILABLE".to_owned()
    } else {
        format!(
            "UPSTREAM_INFEASIBLE:{}",
            centroidal_command.infeasibility_reasons.join(",")
        )
    };
    receipt.fail_zero_required = !feasible;
    receipt.active = experimental_factor_active && feasible;
    receipt.activation_reason = if !feasible {
        "centroidal_command_infeasible".to_owned()
    } else if mode == ScheduledLoadTransferModeV1::Control {
        "progressive_mass_conserving_control".to_owned()
    } else {
        receipt.activation_reason.clone()
    };
    receipt.scheduled_limb_id = if receipt.active {
        raw_scheduled_limb_id
    } else {
        None
    };
    receipt.scheduled_local_phase_step = if receipt.active {
        raw_scheduled_local_phase_step
    } else {
        None
    };
    receipt.ordered_scheduled_unweighted_contact_ids = if receipt.active {
        raw_unweighted_contact_ids
    } else {
        Vec::new()
    };
    receipt.remaining_support_contact_ids = if receipt.active {
        raw_remaining_support_contact_ids
    } else {
        receipt.qualified_support_contact_ids.clone()
    };
    receipt.remaining_support_centroid_world_m = if receipt.active {
        raw_remaining_support_centroid_world_m
    } else {
        None
    };
    receipt.target_center_of_mass_world_m = Some(target_center_of_mass_world_m);
    receipt.centroidal_request = Some(centroidal_request);
    receipt.centroidal_command = Some(centroidal_command);
    receipt.ordered_safe_zero_actuator_ids = if feasible {
        Vec::new()
    } else {
        morphology.ordered_actuator_ids.clone()
    };
    Ok(())
}

fn validate_scheduled_load_transfer_v3_common(
    morphology: &CompiledMorphology,
    request: &ScheduledLoadTransferRequestV3,
) -> Result<()> {
    if !request.gait_amplitude.is_finite() || !(0.0..=1.0).contains(&request.gait_amplitude) {
        return Err(CoreError::Schema(
            "scheduled_load_transfer_v3_gait_amplitude".to_owned(),
        ));
    }
    if request.cycle_steps == 0
        || request.swing_steps == 0
        || request.swing_steps >= request.cycle_steps
    {
        return Err(CoreError::Schema(
            "scheduled_load_transfer_v3_phase_bounds".to_owned(),
        ));
    }
    for (value, field, strictly_positive) in [
        (
            request.characterized_friction_coefficient,
            "scheduled_load_transfer_v3_friction",
            false,
        ),
        (
            request.maximum_normal_force_n,
            "scheduled_load_transfer_v3_maximum_normal_force",
            true,
        ),
        (
            request.feasibility_tolerance,
            "scheduled_load_transfer_v3_feasibility_tolerance",
            true,
        ),
    ] {
        if !value.is_finite() || value < 0.0 || (strictly_positive && value <= 0.0) {
            return Err(CoreError::NonFinite(field.to_owned()));
        }
    }
    require_actuator_order(
        &morphology.ordered_limb_ids,
        request
            .ordered_limb_gait_steps
            .iter()
            .map(|limb| limb.limb_id.as_str()),
        "scheduled_load_transfer_v3_limb",
    )?;
    if let Some(state) = &request.stability_state {
        if state.schema_version != STABILITY_STATE_VERSION {
            return Err(CoreError::Schema(
                "scheduled_load_transfer_v3_stability_state_version".to_owned(),
            ));
        }
        if state.semantic_step != request.semantic_step {
            return Err(CoreError::Time(format!(
                "scheduled_load_transfer_v3_semantic_step:{}:{}",
                request.semantic_step, state.semantic_step
            )));
        }
        validate_body_order(morphology, &state.ordered_body_states)?;
        require_actuator_order(
            &morphology.ordered_contact_site_ids,
            state
                .ordered_support_contacts
                .iter()
                .map(|contact| contact.contact_site_id.as_str()),
            "scheduled_load_transfer_v3_contact",
        )?;
    }
    Ok(())
}

fn is_expected_scheduled_load_transfer_unavailable(error: &CoreError) -> bool {
    matches!(
        error,
        CoreError::Contact(detail)
            if detail == "centroidal_support_contact_set_too_small"
    ) || matches!(
        error,
        CoreError::Frame(detail)
            if detail == "centroidal_support_geometry_rank_deficient"
    )
}

pub fn command_centroidal_support_v2(
    request: &CentroidalSupportRequestV2,
) -> Result<CentroidalSupportCommandV2> {
    validate_centroidal_request(request)?;
    let frame = support_frame(
        request.gravity_world_m_s2,
        request.support_plane_forward_world_unit,
    )?;
    let count = request.support_contacts.len();
    let position_error = subtract(
        request.target_center_of_mass_world_m,
        request.center_of_mass_world_m,
    );
    let desired_forward = request.horizontal_position_gain_n_per_m
        * dot(position_error, frame.forward)
        - request.horizontal_velocity_gain_ns_per_m
            * dot(request.center_of_mass_velocity_world_m_s, frame.forward);
    let desired_lateral = request.horizontal_position_gain_n_per_m
        * dot(position_error, frame.lateral)
        - request.horizontal_velocity_gain_ns_per_m
            * dot(request.center_of_mass_velocity_world_m_s, frame.lateral);
    let mut desired_horizontal = add(
        scale(frame.forward, desired_forward),
        scale(frame.lateral, desired_lateral),
    );
    let horizontal_magnitude = norm(desired_horizontal);
    if horizontal_magnitude > request.maximum_horizontal_force_n {
        desired_horizontal = scale(
            desired_horizontal,
            request.maximum_horizontal_force_n / horizontal_magnitude,
        );
    }
    let vertical_position_error = dot(position_error, frame.up);
    let vertical_velocity = dot(request.center_of_mass_velocity_world_m_s, frame.up);
    let vertical_correction = clamp(
        request.vertical_position_gain_n_per_m * vertical_position_error
            - request.vertical_velocity_gain_ns_per_m * vertical_velocity,
        -request.maximum_vertical_correction_n,
        request.maximum_vertical_correction_n,
    );
    let desired_normal_force = request.whole_system_mass_kg
        * frame.gravity_m_s2
        * request.declared_supported_weight_fraction
        + vertical_correction;
    let desired_roll = clamp(
        -request.roll_position_gain_nm_per_rad * request.torso_roll_rad
            - request.roll_velocity_gain_nm_s_per_rad * request.torso_roll_rate_rad_s,
        -request.maximum_roll_pitch_moment_nm,
        request.maximum_roll_pitch_moment_nm,
    );
    let desired_pitch = clamp(
        -request.pitch_position_gain_nm_per_rad * request.torso_pitch_rad
            - request.pitch_velocity_gain_nm_s_per_rad * request.torso_pitch_rate_rad_s,
        -request.maximum_roll_pitch_moment_nm,
        request.maximum_roll_pitch_moment_nm,
    );
    let desired_moment = add(
        scale(frame.forward, desired_roll),
        scale(frame.lateral, desired_pitch),
    );

    let relative_points = request
        .support_contacts
        .iter()
        .map(|contact| subtract(contact.point_world_m, request.center_of_mass_world_m))
        .collect::<Vec<_>>();
    let row_sum = vec![1.0; count];
    let row_roll = relative_points
        .iter()
        .map(|relative| dot(cross(*relative, frame.up), frame.forward))
        .collect::<Vec<_>>();
    let row_pitch = relative_points
        .iter()
        .map(|relative| dot(cross(*relative, frame.up), frame.lateral))
        .collect::<Vec<_>>();
    let preferred = request
        .support_contacts
        .iter()
        .map(|contact| contact.preferred_normal_force_n)
        .collect::<Vec<_>>();
    let gram = [
        [
            dot_slice(&row_sum, &row_sum),
            dot_slice(&row_sum, &row_roll),
            dot_slice(&row_sum, &row_pitch),
        ],
        [
            dot_slice(&row_roll, &row_sum),
            dot_slice(&row_roll, &row_roll),
            dot_slice(&row_roll, &row_pitch),
        ],
        [
            dot_slice(&row_pitch, &row_sum),
            dot_slice(&row_pitch, &row_roll),
            dot_slice(&row_pitch, &row_pitch),
        ],
    ];
    let gram_scale = gram
        .iter()
        .map(|row| (row[0] * row[0] + row[1] * row[1] + row[2] * row[2]).sqrt())
        .fold(1.0_f64, f64::max);
    let determinant = determinant_3x3(gram).abs();
    if determinant <= 1.0e-9 * gram_scale.powi(3) {
        return Err(CoreError::Frame(
            "centroidal_support_geometry_rank_deficient".to_owned(),
        ));
    }

    let mut tangent_forces = vec![scale(desired_horizontal, 1.0 / count as f64); count];
    let mut normal_forces = vec![0.0; count];
    for iteration in 0..5 {
        let tangential_moment = relative_points
            .iter()
            .zip(&tangent_forces)
            .fold(Vec3::ZERO, |sum, (relative, force)| {
                add(sum, cross(*relative, *force))
            });
        let target = [
            desired_normal_force,
            desired_roll - dot(tangential_moment, frame.forward),
            desired_pitch - dot(tangential_moment, frame.lateral),
        ];
        let right_hand_side = [
            target[0] - dot_slice(&row_sum, &preferred),
            target[1] - dot_slice(&row_roll, &preferred),
            target[2] - dot_slice(&row_pitch, &preferred),
        ];
        let multipliers = solve_3x3(gram, right_hand_side)?;
        let mut positive_normal_sum = 0.0;
        for index in 0..count {
            normal_forces[index] = preferred[index]
                + row_sum[index] * multipliers[0]
                + row_roll[index] * multipliers[1]
                + row_pitch[index] * multipliers[2];
            positive_normal_sum += normal_forces[index].max(0.0);
        }
        if iteration < 4 && positive_normal_sum > EPSILON {
            for index in 0..count {
                tangent_forces[index] = scale(
                    desired_horizontal,
                    normal_forces[index].max(0.0) / positive_normal_sum,
                );
            }
        }
    }

    let tolerance = request.feasibility_tolerance;
    let nominal_normal =
        request.whole_system_mass_kg * frame.gravity_m_s2 / request.nominal_support_count as f64;
    let mut infeasibility_reasons = Vec::new();
    let mut commands = Vec::with_capacity(count);
    let mut achieved_force = Vec3::ZERO;
    let mut achieved_moment = Vec3::ZERO;
    let mut minimum_normal_reserve = f64::INFINITY;
    let mut minimum_friction_reserve = f64::INFINITY;
    for index in 0..count {
        let contact = &request.support_contacts[index];
        let normal = normal_forces[index];
        let tangent = norm(tangent_forces[index]);
        let friction_limit = request.characterized_friction_coefficient * normal.max(0.0);
        if normal < request.minimum_normal_force_n - tolerance {
            infeasibility_reasons.push(format!("NORMAL_BELOW_MINIMUM:{}", contact.contact_id));
        }
        if normal > request.maximum_normal_force_n + tolerance {
            infeasibility_reasons.push(format!("NORMAL_ABOVE_MAXIMUM:{}", contact.contact_id));
        }
        if tangent > friction_limit + tolerance {
            infeasibility_reasons.push(format!("FRICTION_EXCEEDED:{}", contact.contact_id));
        }
        minimum_normal_reserve =
            minimum_normal_reserve.min(request.maximum_normal_force_n - normal);
        minimum_friction_reserve = minimum_friction_reserve.min(friction_limit - tangent);
        let external_force = add(tangent_forces[index], scale(frame.up, normal));
        let joint_task_delta = scale(
            add(
                tangent_forces[index],
                scale(frame.up, normal - nominal_normal),
            ),
            -1.0,
        );
        achieved_force = add(achieved_force, external_force);
        achieved_moment = add(
            achieved_moment,
            cross(relative_points[index], external_force),
        );
        commands.push(CentroidalContactCommandV2 {
            contact_id: contact.contact_id.clone(),
            external_force_command_world_n: external_force,
            joint_task_force_delta_world_n: joint_task_delta,
            normal_force_command_n: normal,
            tangential_force_command_n: tangent,
            friction_limit_n: friction_limit,
            command_not_measurement: true,
        });
    }
    let desired_force = add(desired_horizontal, scale(frame.up, desired_normal_force));
    let force_residual = subtract(achieved_force, desired_force);
    let moment_residual = [
        dot(subtract(achieved_moment, desired_moment), frame.forward),
        dot(subtract(achieved_moment, desired_moment), frame.lateral),
    ];
    if norm(force_residual) > tolerance {
        infeasibility_reasons.push("FORCE_RESIDUAL".to_owned());
    }
    if (moment_residual[0] * moment_residual[0] + moment_residual[1] * moment_residual[1]).sqrt()
        > tolerance
    {
        infeasibility_reasons.push("ROLL_PITCH_MOMENT_RESIDUAL".to_owned());
    }

    Ok(CentroidalSupportCommandV2 {
        schema_version: CENTROIDAL_COMMAND_VERSION.to_owned(),
        semantic_step: request.semantic_step,
        feasible: infeasibility_reasons.is_empty(),
        infeasibility_reasons,
        desired_external_force_world_n: desired_force,
        desired_external_roll_pitch_moment_world_nm: desired_moment,
        achieved_external_force_world_n: achieved_force,
        achieved_external_moment_world_nm: achieved_moment,
        force_residual_n: force_residual,
        roll_pitch_moment_residual_nm: moment_residual,
        minimum_normal_reserve_n: minimum_normal_reserve,
        minimum_friction_reserve_n: minimum_friction_reserve,
        ordered_support_contact_commands: commands,
        characterized_friction_is_adapter_provenance: true,
        per_contact_values_are_commands_not_measurements: true,
        per_foot_measured_load_allocation_available: false,
        actuator_mapping_available: false,
        physics_state_modified: false,
        physical_acceptance_authority: false,
    })
}

pub fn map_endpoint_force_to_joint_v2(
    morphology: &CompiledMorphology,
    request: &EndpointForceJointMapRequestV2,
) -> Result<EndpointForceJointMapReceiptV2> {
    if request.schema_version != ENDPOINT_FORCE_JOINT_MAP_REQUEST_VERSION {
        return Err(CoreError::Schema(
            "endpoint_force_joint_map_request_version".to_owned(),
        ));
    }
    let command = &request.centroidal_command;
    if command.schema_version != CENTROIDAL_COMMAND_VERSION {
        return Err(CoreError::Schema(
            "endpoint_force_centroidal_command_version".to_owned(),
        ));
    }
    if command.semantic_step != request.semantic_step {
        return Err(CoreError::Order(
            "endpoint_force_centroidal_semantic_step".to_owned(),
        ));
    }
    if !command.feasible {
        return Err(CoreError::Capability(
            "endpoint_force_centroidal_command_infeasible".to_owned(),
        ));
    }
    if !command.characterized_friction_is_adapter_provenance
        || !command.per_contact_values_are_commands_not_measurements
        || command.per_foot_measured_load_allocation_available
        || command.actuator_mapping_available
        || command.physics_state_modified
        || command.physical_acceptance_authority
    {
        return Err(CoreError::Capability(
            "endpoint_force_centroidal_nonclaim_inconsistent".to_owned(),
        ));
    }
    if request.ordered_actuator_kinematics.len() != morphology.ordered_actuator_ids.len() {
        return Err(CoreError::Order(
            "endpoint_force_actuator_kinematics_count".to_owned(),
        ));
    }

    let mut contact_ids = HashSet::new();
    for contact in &command.ordered_support_contact_commands {
        require_id(&contact.contact_id, "endpoint_force.contact_id")?;
        if !contact_ids.insert(contact.contact_id.as_str()) {
            return Err(CoreError::Contact(format!(
                "duplicate_endpoint_force_contact:{}",
                contact.contact_id
            )));
        }
        if !contact.command_not_measurement {
            return Err(CoreError::Capability(format!(
                "endpoint_force_contact_command_relabelled:{}",
                contact.contact_id
            )));
        }
        contact
            .joint_task_force_delta_world_n
            .finite("endpoint_force.contact.task_force")?;
    }

    let mut commands = Vec::with_capacity(request.ordered_actuator_kinematics.len());
    for (expected_actuator_id, kinematics) in morphology
        .ordered_actuator_ids
        .iter()
        .zip(&request.ordered_actuator_kinematics)
    {
        require_id(
            &kinematics.actuator_id,
            "endpoint_force.kinematics.actuator_id",
        )?;
        require_id(
            &kinematics.contact_site_id,
            "endpoint_force.kinematics.contact_site_id",
        )?;
        if &kinematics.actuator_id != expected_actuator_id {
            return Err(CoreError::Order(format!(
                "endpoint_force_actuator_order:{expected_actuator_id}:{}",
                kinematics.actuator_id
            )));
        }
        let actuator = morphology
            .morphology_spec
            .actuators
            .iter()
            .find(|actuator| actuator.actuator_id == kinematics.actuator_id)
            .ok_or_else(|| {
                CoreError::Reference(format!(
                    "endpoint_force_actuator:{}",
                    kinematics.actuator_id
                ))
            })?;
        let matching_limbs = morphology
            .morphology_spec
            .limbs
            .iter()
            .filter(|limb| limb.ordered_joint_ids.contains(&actuator.joint_id))
            .collect::<Vec<_>>();
        if matching_limbs.len() != 1
            || !matching_limbs[0]
                .ordered_contact_site_ids
                .contains(&kinematics.contact_site_id)
        {
            return Err(CoreError::Reference(format!(
                "endpoint_force_actuator_contact_association:{}:{}",
                kinematics.actuator_id, kinematics.contact_site_id
            )));
        }
        let contact_command = command
            .ordered_support_contact_commands
            .iter()
            .find(|contact| contact.contact_id == kinematics.contact_site_id)
            .ok_or_else(|| {
                CoreError::Reference(format!(
                    "endpoint_force_contact_command:{}",
                    kinematics.contact_site_id
                ))
            })?;
        kinematics
            .joint_anchor_world_m
            .finite("endpoint_force.kinematics.joint_anchor")?;
        kinematics
            .joint_axis_world_unit
            .finite("endpoint_force.kinematics.joint_axis")?;
        kinematics
            .endpoint_world_m
            .finite("endpoint_force.kinematics.endpoint")?;
        if (norm(kinematics.joint_axis_world_unit) - 1.0).abs() > 1.0e-9 {
            return Err(CoreError::Frame(format!(
                "endpoint_force_joint_axis_not_unit:{}",
                kinematics.actuator_id
            )));
        }
        let lever = subtract(kinematics.endpoint_world_m, kinematics.joint_anchor_world_m);
        let jacobian = cross(kinematics.joint_axis_world_unit, lever);
        let torque = dot(jacobian, contact_command.joint_task_force_delta_world_n);
        jacobian.finite("endpoint_force.linear_jacobian_column")?;
        if !torque.is_finite() {
            return Err(CoreError::NonFinite(format!(
                "endpoint_force.generalized_torque:{}",
                kinematics.actuator_id
            )));
        }
        commands.push(GeneralizedJointTorqueCommandV2 {
            actuator_id: kinematics.actuator_id.clone(),
            contact_site_id: kinematics.contact_site_id.clone(),
            linear_jacobian_column_world_m: jacobian,
            endpoint_task_force_command_world_n: contact_command.joint_task_force_delta_world_n,
            generalized_torque_command_nm: torque,
            command_not_measurement: true,
        });
    }

    Ok(EndpointForceJointMapReceiptV2 {
        schema_version: ENDPOINT_FORCE_JOINT_MAP_RECEIPT_VERSION.to_owned(),
        semantic_step: request.semantic_step,
        ordered_generalized_joint_torque_commands: commands,
        endpoint_force_map_available: true,
        measured_joint_torque_available: false,
        actuator_response_characterized: false,
        adapter_actuation_applied: false,
        physics_state_modified: false,
        physical_acceptance_authority: false,
    })
}

pub fn map_endpoint_force_to_joint_v3(
    morphology: &CompiledMorphology,
    request: &EndpointForceJointMapRequestV3,
) -> Result<EndpointForceJointMapReceiptV3> {
    if request.schema_version != ENDPOINT_FORCE_JOINT_MAP_REQUEST_V3_VERSION {
        return Err(CoreError::Schema(
            "endpoint_force_joint_map_v3_request_version".to_owned(),
        ));
    }
    let command = &request.centroidal_command;
    if command.schema_version != CENTROIDAL_COMMAND_VERSION {
        return Err(CoreError::Schema(
            "endpoint_force_v3_centroidal_command_version".to_owned(),
        ));
    }
    if command.semantic_step != request.semantic_step {
        return Err(CoreError::Order(
            "endpoint_force_v3_centroidal_semantic_step".to_owned(),
        ));
    }
    if !command.feasible {
        return Err(CoreError::Capability(
            "endpoint_force_v3_centroidal_command_infeasible".to_owned(),
        ));
    }
    if !command.characterized_friction_is_adapter_provenance
        || !command.per_contact_values_are_commands_not_measurements
        || command.per_foot_measured_load_allocation_available
        || command.actuator_mapping_available
        || command.physics_state_modified
        || command.physical_acceptance_authority
    {
        return Err(CoreError::Capability(
            "endpoint_force_v3_centroidal_nonclaim_inconsistent".to_owned(),
        ));
    }
    if request.ordered_actuator_kinematics.len() != morphology.ordered_actuator_ids.len() {
        return Err(CoreError::Order(
            "endpoint_force_v3_actuator_kinematics_count".to_owned(),
        ));
    }
    if command.ordered_support_contact_commands.is_empty() {
        return Err(CoreError::Contact(
            "endpoint_force_v3_active_contact_set_empty".to_owned(),
        ));
    }

    let compiled_contact_ids = morphology
        .ordered_contact_site_ids
        .iter()
        .map(String::as_str)
        .collect::<HashSet<_>>();
    let mut active_contact_ids = HashSet::new();
    let mut ordered_active_support_contact_ids =
        Vec::with_capacity(command.ordered_support_contact_commands.len());
    for contact in &command.ordered_support_contact_commands {
        require_id(&contact.contact_id, "endpoint_force_v3.contact_id")?;
        if !compiled_contact_ids.contains(contact.contact_id.as_str()) {
            return Err(CoreError::Reference(format!(
                "endpoint_force_v3_active_contact_not_compiled:{}",
                contact.contact_id
            )));
        }
        if !active_contact_ids.insert(contact.contact_id.as_str()) {
            return Err(CoreError::Contact(format!(
                "duplicate_endpoint_force_v3_contact:{}",
                contact.contact_id
            )));
        }
        if !contact.command_not_measurement {
            return Err(CoreError::Capability(format!(
                "endpoint_force_v3_contact_command_relabelled:{}",
                contact.contact_id
            )));
        }
        contact
            .external_force_command_world_n
            .finite("endpoint_force_v3.contact.external_force")?;
        contact
            .joint_task_force_delta_world_n
            .finite("endpoint_force_v3.contact.task_force")?;
        for (field, value) in [
            (
                "endpoint_force_v3.contact.normal_force",
                contact.normal_force_command_n,
            ),
            (
                "endpoint_force_v3.contact.tangential_force",
                contact.tangential_force_command_n,
            ),
            (
                "endpoint_force_v3.contact.friction_limit",
                contact.friction_limit_n,
            ),
        ] {
            if !value.is_finite() {
                return Err(CoreError::NonFinite(field.to_owned()));
            }
        }
        ordered_active_support_contact_ids.push(contact.contact_id.clone());
    }

    let mut commands = Vec::with_capacity(request.ordered_actuator_kinematics.len());
    let mut active_actuator_count = 0_usize;
    let mut inactive_actuator_count = 0_usize;
    let mut active_contacts_with_actuator = HashSet::new();
    for (expected_actuator_id, kinematics) in morphology
        .ordered_actuator_ids
        .iter()
        .zip(&request.ordered_actuator_kinematics)
    {
        require_id(
            &kinematics.actuator_id,
            "endpoint_force_v3.kinematics.actuator_id",
        )?;
        require_id(
            &kinematics.contact_site_id,
            "endpoint_force_v3.kinematics.contact_site_id",
        )?;
        if &kinematics.actuator_id != expected_actuator_id {
            return Err(CoreError::Order(format!(
                "endpoint_force_v3_actuator_order:{expected_actuator_id}:{}",
                kinematics.actuator_id
            )));
        }
        let actuator = morphology
            .morphology_spec
            .actuators
            .iter()
            .find(|actuator| actuator.actuator_id == kinematics.actuator_id)
            .ok_or_else(|| {
                CoreError::Reference(format!(
                    "endpoint_force_v3_actuator:{}",
                    kinematics.actuator_id
                ))
            })?;
        let matching_limbs = morphology
            .morphology_spec
            .limbs
            .iter()
            .filter(|limb| limb.ordered_joint_ids.contains(&actuator.joint_id))
            .collect::<Vec<_>>();
        if matching_limbs.len() != 1
            || !matching_limbs[0]
                .ordered_contact_site_ids
                .contains(&kinematics.contact_site_id)
        {
            return Err(CoreError::Reference(format!(
                "endpoint_force_v3_actuator_contact_association:{}:{}",
                kinematics.actuator_id, kinematics.contact_site_id
            )));
        }
        let contact_owner_count = morphology
            .morphology_spec
            .limbs
            .iter()
            .filter(|limb| {
                limb.ordered_contact_site_ids
                    .contains(&kinematics.contact_site_id)
            })
            .count();
        if contact_owner_count != 1 {
            return Err(CoreError::Reference(format!(
                "endpoint_force_v3_contact_limb_cardinality:{}",
                kinematics.contact_site_id
            )));
        }
        kinematics
            .joint_anchor_world_m
            .finite("endpoint_force_v3.kinematics.joint_anchor")?;
        kinematics
            .joint_axis_world_unit
            .finite("endpoint_force_v3.kinematics.joint_axis")?;
        kinematics
            .endpoint_world_m
            .finite("endpoint_force_v3.kinematics.endpoint")?;
        if (norm(kinematics.joint_axis_world_unit) - 1.0).abs() > 1.0e-9 {
            return Err(CoreError::Frame(format!(
                "endpoint_force_v3_joint_axis_not_unit:{}",
                kinematics.actuator_id
            )));
        }

        let lever = subtract(kinematics.endpoint_world_m, kinematics.joint_anchor_world_m);
        let jacobian = cross(kinematics.joint_axis_world_unit, lever);
        jacobian.finite("endpoint_force_v3.linear_jacobian_column")?;
        let contact_command = command
            .ordered_support_contact_commands
            .iter()
            .find(|contact| contact.contact_id == kinematics.contact_site_id);
        let (mapping_mode, active_support_contact, endpoint_force, torque, inactive_zero) =
            if let Some(contact_command) = contact_command {
                let torque = dot(jacobian, contact_command.joint_task_force_delta_world_n);
                if !torque.is_finite() {
                    return Err(CoreError::NonFinite(format!(
                        "endpoint_force_v3.generalized_torque:{}",
                        kinematics.actuator_id
                    )));
                }
                active_actuator_count += 1;
                active_contacts_with_actuator.insert(kinematics.contact_site_id.as_str());
                (
                    EndpointForceJointMappingModeV3::SupportCommand,
                    true,
                    contact_command.joint_task_force_delta_world_n,
                    torque,
                    false,
                )
            } else {
                inactive_actuator_count += 1;
                (
                    EndpointForceJointMappingModeV3::InactiveContactZero,
                    false,
                    Vec3::ZERO,
                    0.0,
                    true,
                )
            };
        commands.push(GeneralizedJointTorqueCommandV3 {
            actuator_id: kinematics.actuator_id.clone(),
            contact_site_id: kinematics.contact_site_id.clone(),
            mapping_mode,
            active_support_contact,
            linear_jacobian_column_world_m: jacobian,
            endpoint_task_force_command_world_n: endpoint_force,
            generalized_torque_command_nm: torque,
            inactive_contact_forced_zero: inactive_zero,
            command_not_measurement: true,
        });
    }

    for contact_id in &ordered_active_support_contact_ids {
        if !active_contacts_with_actuator.contains(contact_id.as_str()) {
            return Err(CoreError::Reference(format!(
                "endpoint_force_v3_active_contact_without_actuator:{contact_id}"
            )));
        }
    }
    if active_actuator_count + inactive_actuator_count != morphology.ordered_actuator_ids.len() {
        return Err(CoreError::Order(
            "endpoint_force_v3_actuator_partition".to_owned(),
        ));
    }
    if commands.iter().any(|mapped| {
        mapped.mapping_mode == EndpointForceJointMappingModeV3::InactiveContactZero
            && (mapped.endpoint_task_force_command_world_n != Vec3::ZERO
                || mapped.generalized_torque_command_nm != 0.0
                || !mapped.inactive_contact_forced_zero
                || mapped.active_support_contact)
    }) {
        return Err(CoreError::Capability(
            "endpoint_force_v3_inactive_command_not_exact_zero".to_owned(),
        ));
    }

    Ok(EndpointForceJointMapReceiptV3 {
        schema_version: ENDPOINT_FORCE_JOINT_MAP_RECEIPT_V3_VERSION.to_owned(),
        semantic_step: request.semantic_step,
        ordered_active_support_contact_ids,
        ordered_generalized_joint_torque_commands: commands,
        active_actuator_count,
        inactive_actuator_count,
        endpoint_force_map_available: true,
        partial_support_mapping_available: true,
        inactive_contact_commands_forced_zero: true,
        measured_joint_torque_available: false,
        actuator_response_characterized: false,
        adapter_actuation_applied: false,
        physics_state_modified: false,
        physical_acceptance_authority: false,
    })
}

pub fn bound_stability_influence_v2(
    morphology: &CompiledMorphology,
    request: &StabilityInfluenceRequestV2,
) -> Result<StabilityInfluenceReceiptV2> {
    if request.schema_version != STABILITY_INFLUENCE_REQUEST_VERSION {
        return Err(CoreError::Schema(
            "stability_influence_request_version".to_owned(),
        ));
    }
    for (value, field) in [
        (
            request.maximum_absolute_position_delta_rad,
            "maximum_absolute_position_delta_rad",
        ),
        (
            request.maximum_absolute_velocity_delta_rad_s,
            "maximum_absolute_velocity_delta_rad_s",
        ),
        (
            request.maximum_position_delta_slew_per_step_rad,
            "maximum_position_delta_slew_per_step_rad",
        ),
        (
            request.maximum_velocity_delta_slew_per_step_rad_s,
            "maximum_velocity_delta_slew_per_step_rad_s",
        ),
    ] {
        if !value.is_finite() || value < 0.0 {
            return Err(CoreError::Actuation(format!(
                "stability_influence_limit:{field}"
            )));
        }
    }
    require_actuator_order(
        &morphology.ordered_actuator_ids,
        request
            .ordered_requested_corrections
            .iter()
            .map(|correction| correction.actuator_id.as_str()),
        "stability_requested",
    )?;
    let available = request.availability == StabilityInfluenceAvailability::Available;
    for correction in &request.ordered_requested_corrections {
        if available {
            let position = correction.requested_position_delta_rad.ok_or_else(|| {
                CoreError::Capability(format!(
                    "stability_position_correction_unavailable:{}",
                    correction.actuator_id
                ))
            })?;
            let velocity = correction.requested_velocity_delta_rad_s.ok_or_else(|| {
                CoreError::Capability(format!(
                    "stability_velocity_correction_unavailable:{}",
                    correction.actuator_id
                ))
            })?;
            if !position.is_finite() || !velocity.is_finite() {
                return Err(CoreError::NonFinite(format!(
                    "stability_requested_correction:{}",
                    correction.actuator_id
                )));
            }
        } else if correction.requested_position_delta_rad.is_some()
            || correction.requested_velocity_delta_rad_s.is_some()
        {
            return Err(CoreError::Capability(format!(
                "unavailable_stability_correction_has_value:{}",
                correction.actuator_id
            )));
        }
    }

    let previous = match (
        request.previous_semantic_step,
        &request.ordered_previous_applied_corrections,
    ) {
        (None, None) => None,
        (Some(step), Some(corrections)) => {
            if step >= request.semantic_step {
                return Err(CoreError::Time(
                    "stability_previous_step_not_previous".to_owned(),
                ));
            }
            require_actuator_order(
                &morphology.ordered_actuator_ids,
                corrections
                    .iter()
                    .map(|correction| correction.actuator_id.as_str()),
                "stability_previous",
            )?;
            for correction in corrections {
                if !correction.applied_position_delta_rad.is_finite()
                    || !correction.applied_velocity_delta_rad_s.is_finite()
                {
                    return Err(CoreError::NonFinite(format!(
                        "stability_previous_correction:{}",
                        correction.actuator_id
                    )));
                }
            }
            Some(corrections.as_slice())
        }
        _ => {
            return Err(CoreError::Schema(
                "stability_previous_pair_incomplete".to_owned(),
            ));
        }
    };

    let mut applied = Vec::with_capacity(request.ordered_requested_corrections.len());
    let mut any_magnitude_saturation = false;
    let mut any_slew_limiting = false;
    for (index, correction) in request.ordered_requested_corrections.iter().enumerate() {
        if !available {
            applied.push(AppliedStabilityCorrectionV2 {
                actuator_id: correction.actuator_id.clone(),
                requested_position_delta_rad: None,
                requested_velocity_delta_rad_s: None,
                applied_position_delta_rad: 0.0,
                applied_velocity_delta_rad_s: 0.0,
                magnitude_saturated: false,
                slew_limited: false,
                fallback_zeroed: true,
            });
            continue;
        }
        let requested_position = correction
            .requested_position_delta_rad
            .expect("available correction validated");
        let requested_velocity = correction
            .requested_velocity_delta_rad_s
            .expect("available correction validated");
        let magnitude_position = clamp(
            requested_position,
            -request.maximum_absolute_position_delta_rad,
            request.maximum_absolute_position_delta_rad,
        );
        let magnitude_velocity = clamp(
            requested_velocity,
            -request.maximum_absolute_velocity_delta_rad_s,
            request.maximum_absolute_velocity_delta_rad_s,
        );
        let magnitude_saturated =
            magnitude_position != requested_position || magnitude_velocity != requested_velocity;
        let (previous_position, previous_velocity) = previous
            .map(|corrections| {
                (
                    corrections[index].applied_position_delta_rad,
                    corrections[index].applied_velocity_delta_rad_s,
                )
            })
            .unwrap_or((0.0, 0.0));
        let applied_position = clamp(
            magnitude_position,
            previous_position - request.maximum_position_delta_slew_per_step_rad,
            previous_position + request.maximum_position_delta_slew_per_step_rad,
        );
        let applied_velocity = clamp(
            magnitude_velocity,
            previous_velocity - request.maximum_velocity_delta_slew_per_step_rad_s,
            previous_velocity + request.maximum_velocity_delta_slew_per_step_rad_s,
        );
        let slew_limited =
            applied_position != magnitude_position || applied_velocity != magnitude_velocity;
        any_magnitude_saturation |= magnitude_saturated;
        any_slew_limiting |= slew_limited;
        applied.push(AppliedStabilityCorrectionV2 {
            actuator_id: correction.actuator_id.clone(),
            requested_position_delta_rad: Some(requested_position),
            requested_velocity_delta_rad_s: Some(requested_velocity),
            applied_position_delta_rad: applied_position,
            applied_velocity_delta_rad_s: applied_velocity,
            magnitude_saturated,
            slew_limited,
            fallback_zeroed: false,
        });
    }
    Ok(StabilityInfluenceReceiptV2 {
        schema_version: STABILITY_INFLUENCE_RECEIPT_VERSION.to_owned(),
        semantic_step: request.semantic_step,
        availability: request.availability,
        ordered_applied_corrections: applied,
        any_magnitude_saturation,
        any_slew_limiting,
        fallback_applied: !available,
        fallback_bypasses_slew_to_reach_zero: !available,
        corrections_are_bounded_contributions_not_complete_actuation: true,
        adapter_actuation_applied: false,
        physics_state_modified: false,
        physical_acceptance_authority: false,
    })
}

pub fn bound_stability_influence_v3(
    morphology: &CompiledMorphology,
    request: &StabilityInfluenceRequestV3,
) -> Result<StabilityInfluenceReceiptV3> {
    if request.schema_version != STABILITY_INFLUENCE_REQUEST_V3_VERSION {
        return Err(CoreError::Schema(
            "stability_influence_v3_request_version".to_owned(),
        ));
    }
    let scale = request.global_requested_correction_scale;
    if !scale.is_finite() || !(0.0..=1.0).contains(&scale) {
        return Err(CoreError::Actuation(
            "stability_influence_v3_global_requested_correction_scale".to_owned(),
        ));
    }

    let scaled_corrections = request
        .ordered_requested_corrections
        .iter()
        .map(|correction| RequestedStabilityCorrectionV2 {
            actuator_id: correction.actuator_id.clone(),
            requested_position_delta_rad: correction
                .requested_position_delta_rad
                .map(|value| value * scale),
            requested_velocity_delta_rad_s: correction
                .requested_velocity_delta_rad_s
                .map(|value| value * scale),
        })
        .collect::<Vec<_>>();
    let v2 = bound_stability_influence_v2(
        morphology,
        &StabilityInfluenceRequestV2 {
            schema_version: STABILITY_INFLUENCE_REQUEST_VERSION.to_owned(),
            semantic_step: request.semantic_step,
            availability: request.availability,
            maximum_absolute_position_delta_rad: request.maximum_absolute_position_delta_rad,
            maximum_absolute_velocity_delta_rad_s: request.maximum_absolute_velocity_delta_rad_s,
            maximum_position_delta_slew_per_step_rad: request
                .maximum_position_delta_slew_per_step_rad,
            maximum_velocity_delta_slew_per_step_rad_s: request
                .maximum_velocity_delta_slew_per_step_rad_s,
            ordered_requested_corrections: scaled_corrections,
            previous_semantic_step: request.previous_semantic_step,
            ordered_previous_applied_corrections: request
                .ordered_previous_applied_corrections
                .clone(),
        },
    )?;

    let mut any_nonzero_raw_request = false;
    let mut any_nonzero_scaled_request = false;
    let ordered_applied_corrections = request
        .ordered_requested_corrections
        .iter()
        .zip(v2.ordered_applied_corrections)
        .map(|(raw, bounded)| {
            any_nonzero_raw_request |= raw
                .requested_position_delta_rad
                .is_some_and(|value| value != 0.0)
                || raw
                    .requested_velocity_delta_rad_s
                    .is_some_and(|value| value != 0.0);
            any_nonzero_scaled_request |= bounded
                .requested_position_delta_rad
                .is_some_and(|value| value != 0.0)
                || bounded
                    .requested_velocity_delta_rad_s
                    .is_some_and(|value| value != 0.0);
            AppliedStabilityCorrectionV3 {
                actuator_id: bounded.actuator_id,
                raw_requested_position_delta_rad: raw.requested_position_delta_rad,
                raw_requested_velocity_delta_rad_s: raw.requested_velocity_delta_rad_s,
                scaled_requested_position_delta_rad: bounded.requested_position_delta_rad,
                scaled_requested_velocity_delta_rad_s: bounded.requested_velocity_delta_rad_s,
                applied_position_delta_rad: bounded.applied_position_delta_rad,
                applied_velocity_delta_rad_s: bounded.applied_velocity_delta_rad_s,
                magnitude_saturated: bounded.magnitude_saturated,
                slew_limited: bounded.slew_limited,
                fallback_zeroed: bounded.fallback_zeroed,
            }
        })
        .collect();

    Ok(StabilityInfluenceReceiptV3 {
        schema_version: STABILITY_INFLUENCE_RECEIPT_V3_VERSION.to_owned(),
        semantic_step: v2.semantic_step,
        availability: v2.availability,
        global_requested_correction_scale: scale,
        ordered_applied_corrections,
        any_nonzero_raw_request,
        any_nonzero_scaled_request,
        any_magnitude_saturation: v2.any_magnitude_saturation,
        any_slew_limiting: v2.any_slew_limiting,
        fallback_applied: v2.fallback_applied,
        fallback_bypasses_slew_to_reach_zero: v2.fallback_bypasses_slew_to_reach_zero,
        global_scale_applied_before_magnitude_and_slew: true,
        corrections_are_bounded_contributions_not_complete_actuation: v2
            .corrections_are_bounded_contributions_not_complete_actuation,
        adapter_actuation_applied: v2.adapter_actuation_applied,
        physics_state_modified: v2.physics_state_modified,
        physical_acceptance_authority: v2.physical_acceptance_authority,
    })
}

fn require_actuator_order<'a>(
    expected: &[String],
    observed: impl Iterator<Item = &'a str>,
    field: &str,
) -> Result<()> {
    let observed = observed.collect::<Vec<_>>();
    if observed.len() != expected.len() {
        return Err(CoreError::Order(format!("{field}_count")));
    }
    for (expected_id, observed_id) in expected.iter().zip(observed) {
        require_id(observed_id, field)?;
        if expected_id != observed_id {
            return Err(CoreError::Order(format!(
                "{field}_order:{expected_id}:{observed_id}"
            )));
        }
    }
    Ok(())
}

fn validate_body_order(
    morphology: &CompiledMorphology,
    body_states: &[OrderedBodyStateV2],
) -> Result<()> {
    if body_states.len() != morphology.ordered_body_ids.len() {
        return Err(CoreError::Order("stability_body_state_count".to_owned()));
    }
    for (expected, observed) in morphology.ordered_body_ids.iter().zip(body_states) {
        require_id(&observed.body_id, "stability.body_id")?;
        if expected != &observed.body_id {
            return Err(CoreError::Order(format!(
                "stability_body_order:{}:{}",
                expected, observed.body_id
            )));
        }
    }
    Ok(())
}

fn qualified_support_contacts(
    contacts: &[SupportContactStateV2],
) -> Result<Vec<&SupportContactStateV2>> {
    let mut ids = HashSet::new();
    let mut qualified = Vec::new();
    for contact in contacts {
        require_id(&contact.contact_site_id, "stability.contact_site_id")?;
        require_id(&contact.adapter_id, "stability.contact_adapter_id")?;
        if !ids.insert(contact.contact_site_id.as_str()) {
            return Err(CoreError::Contact(format!(
                "duplicate_stability_contact:{}",
                contact.contact_site_id
            )));
        }
        let mut engine_ids = HashSet::new();
        for engine_id in &contact.engine_contact_ids {
            require_id(engine_id, "stability.engine_contact_id")?;
            if !engine_ids.insert(engine_id.as_str()) {
                return Err(CoreError::Contact(format!(
                    "duplicate_stability_engine_contact:{engine_id}"
                )));
            }
        }
        if let Some(point) = contact.point_world_m {
            point.finite("stability.contact.point")?;
        }
        if let Some(normal) = contact.normal_world_unit {
            normal.finite("stability.contact.normal")?;
            if (norm(normal) - 1.0).abs() > 1.0e-9 {
                return Err(CoreError::Contact(format!(
                    "stability_contact_normal_not_unit:{}",
                    contact.contact_site_id
                )));
            }
        }
        if let Some(velocity) = contact.surface_relative_velocity_world_m_s {
            velocity.finite("stability.contact.relative_velocity")?;
        }
        if let Some(material_id) = &contact.material_id {
            require_id(material_id, "stability.material_id")?;
        }
        if contact.presence == Some(false) && contact.bears_support == Some(true) {
            return Err(CoreError::Contact(format!(
                "absent_stability_contact_bears_support:{}",
                contact.contact_site_id
            )));
        }
        if contact.bears_support == Some(true) {
            if contact.presence != Some(true)
                || contact.point_world_m.is_none()
                || contact.normal_world_unit.is_none()
                || contact.engine_contact_ids.is_empty()
            {
                return Err(CoreError::Capability(format!(
                    "stability_bearing_geometry_unavailable:{}",
                    contact.contact_site_id
                )));
            }
            qualified.push(contact);
        }
    }
    Ok(qualified)
}

fn validate_centroidal_request(request: &CentroidalSupportRequestV2) -> Result<()> {
    if request.schema_version != CENTROIDAL_REQUEST_VERSION {
        return Err(CoreError::Schema("centroidal_request_version".to_owned()));
    }
    for (value, field, strictly_positive) in [
        (request.whole_system_mass_kg, "whole_system_mass_kg", true),
        (
            request.horizontal_position_gain_n_per_m,
            "horizontal_position_gain_n_per_m",
            false,
        ),
        (
            request.horizontal_velocity_gain_ns_per_m,
            "horizontal_velocity_gain_ns_per_m",
            false,
        ),
        (
            request.vertical_position_gain_n_per_m,
            "vertical_position_gain_n_per_m",
            false,
        ),
        (
            request.vertical_velocity_gain_ns_per_m,
            "vertical_velocity_gain_ns_per_m",
            false,
        ),
        (
            request.roll_position_gain_nm_per_rad,
            "roll_position_gain_nm_per_rad",
            false,
        ),
        (
            request.roll_velocity_gain_nm_s_per_rad,
            "roll_velocity_gain_nm_s_per_rad",
            false,
        ),
        (
            request.pitch_position_gain_nm_per_rad,
            "pitch_position_gain_nm_per_rad",
            false,
        ),
        (
            request.pitch_velocity_gain_nm_s_per_rad,
            "pitch_velocity_gain_nm_s_per_rad",
            false,
        ),
        (
            request.maximum_horizontal_force_n,
            "maximum_horizontal_force_n",
            false,
        ),
        (
            request.maximum_vertical_correction_n,
            "maximum_vertical_correction_n",
            false,
        ),
        (
            request.maximum_roll_pitch_moment_nm,
            "maximum_roll_pitch_moment_nm",
            false,
        ),
        (
            request.declared_supported_weight_fraction,
            "declared_supported_weight_fraction",
            false,
        ),
        (
            request.characterized_friction_coefficient,
            "characterized_friction_coefficient",
            false,
        ),
        (
            request.minimum_normal_force_n,
            "minimum_normal_force_n",
            false,
        ),
        (
            request.maximum_normal_force_n,
            "maximum_normal_force_n",
            false,
        ),
        (request.feasibility_tolerance, "feasibility_tolerance", true),
    ] {
        if !value.is_finite() || value < 0.0 || (strictly_positive && value <= 0.0) {
            return Err(CoreError::NonFinite(field.to_owned()));
        }
    }
    if request.declared_supported_weight_fraction > 1.0
        || request.maximum_normal_force_n < request.minimum_normal_force_n
        || request.nominal_support_count == 0
    {
        return Err(CoreError::Schema("centroidal_request_bounds".to_owned()));
    }
    for (value, field) in [
        (request.torso_roll_rad, "torso_roll_rad"),
        (request.torso_pitch_rad, "torso_pitch_rad"),
        (request.torso_roll_rate_rad_s, "torso_roll_rate_rad_s"),
        (request.torso_pitch_rate_rad_s, "torso_pitch_rate_rad_s"),
    ] {
        if !value.is_finite() {
            return Err(CoreError::NonFinite(field.to_owned()));
        }
    }
    for (value, field) in [
        (request.center_of_mass_world_m, "center_of_mass_world_m"),
        (
            request.center_of_mass_velocity_world_m_s,
            "center_of_mass_velocity_world_m_s",
        ),
        (
            request.target_center_of_mass_world_m,
            "target_center_of_mass_world_m",
        ),
    ] {
        value.finite(field)?;
    }
    if request.support_contacts.len() < 3 {
        return Err(CoreError::Contact(
            "centroidal_support_contact_set_too_small".to_owned(),
        ));
    }
    let mut ids = HashSet::new();
    for contact in &request.support_contacts {
        require_id(&contact.contact_id, "centroidal.contact_id")?;
        if !ids.insert(contact.contact_id.as_str()) {
            return Err(CoreError::Contact(format!(
                "duplicate_centroidal_contact:{}",
                contact.contact_id
            )));
        }
        contact
            .point_world_m
            .finite("centroidal.contact.point_world_m")?;
        if !contact.preferred_normal_force_n.is_finite() || contact.preferred_normal_force_n < 0.0 {
            return Err(CoreError::Contact(format!(
                "centroidal_contact_preference:{}",
                contact.contact_id
            )));
        }
    }
    Ok(())
}

fn support_frame(gravity: Vec3, forward_hint: Vec3) -> Result<SupportFrame> {
    gravity.finite("stability.gravity_world_m_s2")?;
    forward_hint.finite("stability.support_plane_forward_world_unit")?;
    let gravity_magnitude = norm(gravity);
    if gravity_magnitude <= EPSILON {
        return Err(CoreError::Frame("stability_zero_gravity".to_owned()));
    }
    let up = scale(gravity, -1.0 / gravity_magnitude);
    let projected_forward = subtract(forward_hint, scale(up, dot(forward_hint, up)));
    let projected_norm = norm(projected_forward);
    if projected_norm <= EPSILON {
        return Err(CoreError::Frame(
            "stability_forward_parallel_to_gravity".to_owned(),
        ));
    }
    let forward = scale(projected_forward, 1.0 / projected_norm);
    let lateral = normalize(cross(forward, up), "stability_lateral_axis")?;
    Ok(SupportFrame {
        up,
        forward,
        lateral,
        gravity_m_s2: gravity_magnitude,
    })
}

fn project_to_plane(point: Vec3, frame: SupportFrame) -> PlanePoint {
    PlanePoint {
        forward: dot(point, frame.forward),
        lateral: dot(point, frame.lateral),
    }
}

fn lift_from_plane(point: PlanePoint, height: f64, frame: SupportFrame) -> Vec3 {
    add(
        add(
            scale(frame.forward, point.forward),
            scale(frame.lateral, point.lateral),
        ),
        scale(frame.up, height),
    )
}

fn convex_hull(mut points: Vec<PlanePoint>) -> Vec<PlanePoint> {
    points.sort_by(|left, right| {
        left.forward
            .total_cmp(&right.forward)
            .then(left.lateral.total_cmp(&right.lateral))
    });
    points.dedup_by(|left, right| left.subtract(*right).norm_squared() <= EPSILON * EPSILON);
    if points.len() <= 2 {
        return points;
    }
    let mut lower = Vec::new();
    for point in points.iter().copied() {
        while lower.len() >= 2 {
            let count = lower.len();
            let first: PlanePoint = lower[count - 2];
            let second: PlanePoint = lower[count - 1];
            if second.subtract(first).cross(point.subtract(second)) > EPSILON {
                break;
            }
            lower.pop();
        }
        lower.push(point);
    }
    let mut upper = Vec::new();
    for point in points.iter().rev().copied() {
        while upper.len() >= 2 {
            let count = upper.len();
            let first: PlanePoint = upper[count - 2];
            let second: PlanePoint = upper[count - 1];
            if second.subtract(first).cross(point.subtract(second)) > EPSILON {
                break;
            }
            upper.pop();
        }
        upper.push(point);
    }
    lower.pop();
    upper.pop();
    lower.extend(upper);
    lower
}

fn support_centroid(hull: &[PlanePoint], dimension: u8) -> Result<PlanePoint> {
    if dimension == 0 {
        return Ok(hull[0]);
    }
    if dimension == 1 {
        return Ok(hull[0].add(hull[1]).scale(0.5));
    }
    let mut area_twice = 0.0;
    let mut numerator = PlanePoint {
        forward: 0.0,
        lateral: 0.0,
    };
    for index in 0..hull.len() {
        let current = hull[index];
        let next = hull[(index + 1) % hull.len()];
        let cross = current.cross(next);
        area_twice += cross;
        numerator = numerator.add(current.add(next).scale(cross));
    }
    if area_twice.abs() <= EPSILON {
        return Err(CoreError::Frame(
            "stability_support_polygon_degenerate".to_owned(),
        ));
    }
    Ok(numerator.scale(1.0 / (3.0 * area_twice)))
}

fn support_margin(point: PlanePoint, hull: &[PlanePoint], dimension: u8) -> f64 {
    if dimension == 0 {
        return -point.subtract(hull[0]).norm();
    }
    if dimension == 1 {
        return -distance_to_segment(point, hull[0], hull[1]);
    }
    let mut minimum = f64::INFINITY;
    for index in 0..hull.len() {
        let start = hull[index];
        let finish = hull[(index + 1) % hull.len()];
        let edge = finish.subtract(start);
        minimum = minimum.min(edge.cross(point.subtract(start)) / edge.norm());
    }
    minimum
}

fn distance_to_segment(point: PlanePoint, start: PlanePoint, finish: PlanePoint) -> f64 {
    let edge = finish.subtract(start);
    let fraction = clamp(
        point.subtract(start).dot(edge) / edge.norm_squared(),
        0.0,
        1.0,
    );
    point.subtract(start.add(edge.scale(fraction))).norm()
}

fn solve_3x3(matrix: [[f64; 3]; 3], right_hand_side: [f64; 3]) -> Result<[f64; 3]> {
    let mut values = [
        [matrix[0][0], matrix[0][1], matrix[0][2], right_hand_side[0]],
        [matrix[1][0], matrix[1][1], matrix[1][2], right_hand_side[1]],
        [matrix[2][0], matrix[2][1], matrix[2][2], right_hand_side[2]],
    ];
    for column in 0..3 {
        let mut pivot_row = column;
        for row in (column + 1)..3 {
            if values[row][column].abs() > values[pivot_row][column].abs() {
                pivot_row = row;
            }
        }
        if values[pivot_row][column].abs() <= 1.0e-10 {
            return Err(CoreError::Frame(
                "centroidal_linear_system_singular".to_owned(),
            ));
        }
        if pivot_row != column {
            values.swap(pivot_row, column);
        }
        let pivot = values[column][column];
        for value in &mut values[column][column..] {
            *value /= pivot;
        }
        let normalized_pivot_row = values[column];
        for (row_index, row_values) in values.iter_mut().enumerate() {
            if row_index == column {
                continue;
            }
            let factor = row_values[column];
            for (value, pivot_value) in row_values[column..]
                .iter_mut()
                .zip(&normalized_pivot_row[column..])
            {
                *value -= factor * pivot_value;
            }
        }
    }
    Ok([values[0][3], values[1][3], values[2][3]])
}

fn determinant_3x3(matrix: [[f64; 3]; 3]) -> f64 {
    matrix[0][0] * (matrix[1][1] * matrix[2][2] - matrix[1][2] * matrix[2][1])
        - matrix[0][1] * (matrix[1][0] * matrix[2][2] - matrix[1][2] * matrix[2][0])
        + matrix[0][2] * (matrix[1][0] * matrix[2][1] - matrix[1][1] * matrix[2][0])
}

fn rotate_vector(quaternion: crate::protocol::Quaternion, vector: Vec3) -> Vec3 {
    let imaginary = Vec3 {
        x: quaternion.x,
        y: quaternion.y,
        z: quaternion.z,
    };
    let first = scale(imaginary, 2.0 * dot(imaginary, vector));
    let second = scale(
        vector,
        quaternion.w * quaternion.w - dot(imaginary, imaginary),
    );
    let third = scale(cross(imaginary, vector), 2.0 * quaternion.w);
    add(add(first, second), third)
}

fn require_id(value: &str, field: &str) -> Result<()> {
    let mut chars = value.chars();
    if value.is_empty()
        || !chars
            .next()
            .is_some_and(|character| character.is_ascii_lowercase())
        || !chars.all(|character| {
            character.is_ascii_lowercase() || character.is_ascii_digit() || character == '_'
        })
    {
        return Err(CoreError::Identity(format!("{field}:{value}")));
    }
    Ok(())
}

fn require_digest(value: &str, field: &str) -> Result<()> {
    let suffix = value.strip_prefix("sha256:");
    if !suffix.is_some_and(|hex| {
        hex.len() == 64
            && hex
                .chars()
                .all(|character| character.is_ascii_hexdigit() && !character.is_ascii_uppercase())
    }) {
        return Err(CoreError::Digest(field.to_owned()));
    }
    Ok(())
}

fn normalize(value: Vec3, field: &str) -> Result<Vec3> {
    let length = norm(value);
    if !length.is_finite() || length <= EPSILON {
        return Err(CoreError::Frame(field.to_owned()));
    }
    Ok(scale(value, 1.0 / length))
}

fn dot_slice(left: &[f64], right: &[f64]) -> f64 {
    left.iter()
        .zip(right)
        .map(|(left, right)| left * right)
        .sum()
}

fn add(left: Vec3, right: Vec3) -> Vec3 {
    Vec3 {
        x: left.x + right.x,
        y: left.y + right.y,
        z: left.z + right.z,
    }
}

fn subtract(left: Vec3, right: Vec3) -> Vec3 {
    Vec3 {
        x: left.x - right.x,
        y: left.y - right.y,
        z: left.z - right.z,
    }
}

fn scale(value: Vec3, scalar: f64) -> Vec3 {
    Vec3 {
        x: value.x * scalar,
        y: value.y * scalar,
        z: value.z * scalar,
    }
}

fn dot(left: Vec3, right: Vec3) -> f64 {
    left.x * right.x + left.y * right.y + left.z * right.z
}

fn cross(left: Vec3, right: Vec3) -> Vec3 {
    Vec3 {
        x: left.y * right.z - left.z * right.y,
        y: left.z * right.x - left.x * right.z,
        z: left.x * right.y - left.y * right.x,
    }
}

fn norm(value: Vec3) -> f64 {
    dot(value, value).sqrt()
}

fn clamp(value: f64, minimum: f64, maximum: f64) -> f64 {
    value.max(minimum).min(maximum)
}

#[cfg(test)]
mod tests {
    use crate::protocol::{Pose, Quaternion, Twist};
    use crate::quadruped::{BoundedQuadrupedDescriptor, compile_bounded_quadruped};

    use super::*;

    fn descriptor() -> BoundedQuadrupedDescriptor {
        BoundedQuadrupedDescriptor {
            schema_version: "sporespore_bounded_quadruped_descriptor_v1".to_owned(),
            morphology_id: "stability_reference".to_owned(),
            torso_length_scale: 1.0,
            torso_width_scale: 1.0,
            upper_length_fraction: 18.0 / 35.0,
            hip_span_scale: 1.0,
            foot_radius_scale: 1.0,
            front_limb_mass_scale: 1.0,
        }
    }

    fn body_states(
        morphology: &CompiledMorphology,
        position: Vec3,
        velocity: Vec3,
    ) -> Vec<OrderedBodyStateV2> {
        morphology
            .ordered_body_ids
            .iter()
            .map(|body_id| OrderedBodyStateV2 {
                body_id: body_id.clone(),
                pose_world: Pose {
                    position_m: position,
                    orientation_xyzw: Quaternion::IDENTITY,
                },
                twist_world: Twist {
                    linear_velocity_m_s: velocity,
                    angular_velocity_rad_s: Vec3::ZERO,
                },
            })
            .collect()
    }

    fn contact(id: &str, point: Vec3) -> SupportContactStateV2 {
        SupportContactStateV2 {
            contact_site_id: id.to_owned(),
            presence: Some(true),
            bears_support: Some(true),
            point_world_m: Some(point),
            normal_world_unit: Some(Vec3 {
                x: 0.0,
                y: 1.0,
                z: 0.0,
            }),
            surface_relative_velocity_world_m_s: Some(Vec3::ZERO),
            material_id: Some("test_material".to_owned()),
            adapter_id: "golden_oracle".to_owned(),
            engine_contact_ids: vec![format!("{id}_engine")],
        }
    }

    fn stability_state(
        morphology: &CompiledMorphology,
        contacts: Vec<SupportContactStateV2>,
    ) -> StabilityStateV2 {
        StabilityStateV2 {
            schema_version: STABILITY_STATE_VERSION.to_owned(),
            semantic_step: 7,
            ordered_body_states: body_states(
                morphology,
                Vec3 {
                    x: 0.0,
                    y: 0.4,
                    z: 0.0,
                },
                Vec3 {
                    x: 0.2,
                    y: 0.0,
                    z: 0.0,
                },
            ),
            ordered_support_contacts: contacts,
            gravity_world_m_s2: Vec3 {
                x: 0.0,
                y: -9.8,
                z: 0.0,
            },
            support_plane_forward_world_unit: Vec3 {
                x: 1.0,
                y: 0.0,
                z: 0.0,
            },
            adapter_capability_sha256: format!("sha256:{}", "2".repeat(64)),
        }
    }

    fn triangle_contacts() -> Vec<SupportContactStateV2> {
        vec![
            contact(
                "rear_left",
                Vec3 {
                    x: 1.0,
                    y: 0.0,
                    z: -1.0,
                },
            ),
            contact(
                "front",
                Vec3 {
                    x: 0.0,
                    y: 0.0,
                    z: 1.0,
                },
            ),
            contact(
                "rear_right",
                Vec3 {
                    x: -1.0,
                    y: 0.0,
                    z: -1.0,
                },
            ),
        ]
    }

    #[test]
    fn dynamic_support_matches_the_gdscript_triangle_golden() {
        let morphology = compile_bounded_quadruped(descriptor()).unwrap().morphology;
        let observed = observe_stability_v2(
            &morphology,
            &stability_state(&morphology, triangle_contacts()),
        )
        .unwrap();
        let expected_frequency = (9.8_f64 / 0.4).sqrt();
        let expected_capture_x = 0.2 / expected_frequency;
        assert!((observed.whole_system_mass_kg - morphology.total_mass_kg).abs() <= 1.0e-12);
        assert!((observed.center_of_mass_world_m.y - 0.4).abs() <= 1.0e-12);
        assert!((observed.center_of_mass_velocity_world_m_s.x - 0.2).abs() <= 1.0e-12);
        assert!(
            (observed.linearized_natural_frequency_rad_s - expected_frequency).abs() <= 1.0e-12
        );
        assert!(
            (observed.linearized_capture_point_world_m.x - expected_capture_x).abs() <= 1.0e-12
        );
        assert!((observed.support_centroid_world_m.z + 1.0 / 3.0).abs() <= 1.0e-12);
        assert!(observed.linearized_capture_margin_m < observed.center_of_mass_margin_m);
        assert_eq!(
            observed.minimum_dynamic_support_margin_m,
            observed.linearized_capture_margin_m
        );
        assert!(observed.hull_uses_geometric_order_not_semantic_order);
        assert!(!observed.articulated_capture_guarantee_available);
        assert!(!observed.per_foot_measured_load_allocation_available);
        assert!(!observed.physical_acceptance_authority);
    }

    #[test]
    fn geometric_hull_is_invariant_to_semantic_order_and_interior_points() {
        let morphology = compile_bounded_quadruped(descriptor()).unwrap().morphology;
        let baseline = observe_stability_v2(
            &morphology,
            &stability_state(&morphology, triangle_contacts()),
        )
        .unwrap();
        let mut reordered = triangle_contacts();
        reordered.reverse();
        reordered.push(contact(
            "interior",
            Vec3 {
                x: 0.0,
                y: 0.0,
                z: 0.0,
            },
        ));
        let observed =
            observe_stability_v2(&morphology, &stability_state(&morphology, reordered)).unwrap();
        assert_eq!(
            baseline.support_vertices_plane_m,
            observed.support_vertices_plane_m
        );
        assert!(
            (baseline.linearized_capture_margin_m - observed.linearized_capture_margin_m).abs()
                <= 1.0e-12
        );
    }

    #[test]
    fn support_observer_is_gravity_aligned_not_y_up_hardcoded() {
        let morphology = compile_bounded_quadruped(descriptor()).unwrap().morphology;
        let mut contacts = vec![
            contact(
                "a",
                Vec3 {
                    x: -1.0,
                    y: 1.0,
                    z: 0.0,
                },
            ),
            contact(
                "b",
                Vec3 {
                    x: 1.0,
                    y: 1.0,
                    z: 0.0,
                },
            ),
            contact(
                "c",
                Vec3 {
                    x: 0.0,
                    y: -1.0,
                    z: 0.0,
                },
            ),
        ];
        for contact in &mut contacts {
            contact.normal_world_unit = Some(Vec3 {
                x: 0.0,
                y: 0.0,
                z: 1.0,
            });
        }
        let mut state = stability_state(&morphology, contacts);
        state.ordered_body_states = body_states(
            &morphology,
            Vec3 {
                x: 0.0,
                y: 0.0,
                z: 0.4,
            },
            Vec3 {
                x: 0.2,
                y: 0.0,
                z: 0.0,
            },
        );
        state.gravity_world_m_s2 = Vec3 {
            x: 0.0,
            y: 0.0,
            z: -9.8,
        };
        let observed = observe_stability_v2(&morphology, &state).unwrap();
        assert!(
            norm(subtract(
                observed.support_plane_up_world_unit,
                Vec3 {
                    x: 0.0,
                    y: 0.0,
                    z: 1.0,
                }
            )) <= 1.0e-12
        );
        assert!((observed.center_of_mass_height_above_support_m - 0.4).abs() <= 1.0e-12);
        assert!(
            (observed.linearized_capture_point_world_m.x - 0.2 / (9.8_f64 / 0.4).sqrt()).abs()
                <= 1.0e-12
        );
        assert_eq!(observed.support_geometry_kind, SupportGeometryKind::Polygon);
    }

    #[test]
    fn point_and_segment_support_remain_explicit_zero_area_states() {
        let morphology = compile_bounded_quadruped(descriptor()).unwrap().morphology;
        let point = observe_stability_v2(
            &morphology,
            &stability_state(&morphology, vec![contact("point", Vec3::ZERO)]),
        )
        .unwrap();
        assert_eq!(point.support_geometry_dimension, 0);
        assert_eq!(point.support_geometry_kind, SupportGeometryKind::Point);
        assert!(!point.support_polygon_available);
        let segment = observe_stability_v2(
            &morphology,
            &stability_state(
                &morphology,
                vec![
                    contact(
                        "left",
                        Vec3 {
                            x: -1.0,
                            y: 0.0,
                            z: 0.0,
                        },
                    ),
                    contact(
                        "right",
                        Vec3 {
                            x: 1.0,
                            y: 0.0,
                            z: 0.0,
                        },
                    ),
                ],
            ),
        )
        .unwrap();
        assert_eq!(segment.support_geometry_dimension, 1);
        assert_eq!(segment.support_geometry_kind, SupportGeometryKind::Segment);
        assert!(segment.center_of_mass_margin_m.abs() <= 1.0e-12);
    }

    #[test]
    fn missing_bearing_geometry_fails_closed_and_presence_is_not_bearing() {
        let morphology = compile_bounded_quadruped(descriptor()).unwrap().morphology;
        let mut unavailable = contact("unknown", Vec3::ZERO);
        unavailable.bears_support = None;
        unavailable.point_world_m = None;
        unavailable.normal_world_unit = None;
        unavailable.engine_contact_ids.clear();
        assert!(
            observe_stability_v2(
                &morphology,
                &stability_state(&morphology, vec![unavailable])
            )
            .is_err()
        );
        let mut invalid = contact("invalid", Vec3::ZERO);
        invalid.point_world_m = None;
        assert!(
            observe_stability_v2(&morphology, &stability_state(&morphology, vec![invalid]))
                .is_err()
        );
    }

    fn scheduled_load_transfer_request(
        morphology: &CompiledMorphology,
        policy_id: &str,
    ) -> ScheduledLoadTransferRequestV1 {
        let point_by_contact = HashMap::from([
            (
                "front_left_foot",
                Vec3 {
                    x: 0.30,
                    y: 0.0,
                    z: -0.20,
                },
            ),
            (
                "front_right_foot",
                Vec3 {
                    x: 0.30,
                    y: 0.0,
                    z: 0.20,
                },
            ),
            (
                "rear_left_foot",
                Vec3 {
                    x: -0.30,
                    y: 0.0,
                    z: -0.20,
                },
            ),
            (
                "rear_right_foot",
                Vec3 {
                    x: -0.30,
                    y: 0.0,
                    z: 0.20,
                },
            ),
        ]);
        let contacts = morphology
            .ordered_contact_site_ids
            .iter()
            .map(|contact_id| contact(contact_id, point_by_contact[contact_id.as_str()]))
            .collect();
        let state = stability_state(morphology, contacts);
        ScheduledLoadTransferRequestV1 {
            schema_version: SCHEDULED_LOAD_TRANSFER_REQUEST_VERSION.to_owned(),
            policy_id: policy_id.to_owned(),
            gait_amplitude: 1.0,
            cycle_steps: 360,
            swing_steps: 72,
            characterized_friction_coefficient: 1.0,
            maximum_normal_force_n: morphology.total_mass_kg * 9.8,
            feasibility_tolerance: 1.0e-5,
            ordered_limb_gait_steps: morphology
                .ordered_limb_ids
                .iter()
                .map(|limb_id| ScheduledLimbGaitStepV1 {
                    limb_id: limb_id.clone(),
                    gait_step: 54,
                })
                .collect(),
            stability_state: state,
        }
    }

    fn scheduled_load_transfer_request_v2(
        morphology: &CompiledMorphology,
        policy_id: &str,
    ) -> ScheduledLoadTransferRequestV2 {
        let v1 =
            scheduled_load_transfer_request(morphology, SCHEDULED_LOAD_TRANSFER_BW9L_A_POLICY_ID);
        ScheduledLoadTransferRequestV2 {
            schema_version: SCHEDULED_LOAD_TRANSFER_REQUEST_V2_VERSION.to_owned(),
            policy_id: policy_id.to_owned(),
            gait_amplitude: v1.gait_amplitude,
            cycle_steps: v1.cycle_steps,
            swing_steps: v1.swing_steps,
            characterized_friction_coefficient: v1.characterized_friction_coefficient,
            maximum_normal_force_n: v1.maximum_normal_force_n,
            feasibility_tolerance: v1.feasibility_tolerance,
            ordered_limb_gait_steps: v1.ordered_limb_gait_steps,
            stability_state: v1.stability_state,
        }
    }

    fn scheduled_load_transfer_request_v3(
        morphology: &CompiledMorphology,
        policy_id: &str,
    ) -> ScheduledLoadTransferRequestV3 {
        let v2 = scheduled_load_transfer_request_v2(
            morphology,
            SCHEDULED_LOAD_TRANSFER_BW10F_A_POLICY_ID,
        );
        let semantic_step = v2.stability_state.semantic_step;
        ScheduledLoadTransferRequestV3 {
            schema_version: SCHEDULED_LOAD_TRANSFER_REQUEST_V3_VERSION.to_owned(),
            policy_id: policy_id.to_owned(),
            semantic_step,
            observation_available: true,
            observation_unavailable_reason: None,
            gait_amplitude: v2.gait_amplitude,
            cycle_steps: v2.cycle_steps,
            swing_steps: v2.swing_steps,
            characterized_friction_coefficient: v2.characterized_friction_coefficient,
            maximum_normal_force_n: v2.maximum_normal_force_n,
            feasibility_tolerance: v2.feasibility_tolerance,
            ordered_limb_gait_steps: v2.ordered_limb_gait_steps,
            stability_state: Some(v2.stability_state),
        }
    }

    #[test]
    fn scheduled_load_transfer_bw9l_family_is_branch_free_and_factorial() {
        let morphology = compile_bounded_quadruped(descriptor()).unwrap().morphology;
        let control = plan_scheduled_load_transfer_v1(
            &morphology,
            &scheduled_load_transfer_request(&morphology, SCHEDULED_LOAD_TRANSFER_BW9L_A_POLICY_ID),
        )
        .unwrap();
        let preferred = plan_scheduled_load_transfer_v1(
            &morphology,
            &scheduled_load_transfer_request(&morphology, SCHEDULED_LOAD_TRANSFER_BW9L_B_POLICY_ID),
        )
        .unwrap();
        let centroid = plan_scheduled_load_transfer_v1(
            &morphology,
            &scheduled_load_transfer_request(&morphology, SCHEDULED_LOAD_TRANSFER_BW9L_C_POLICY_ID),
        )
        .unwrap();
        let combined = plan_scheduled_load_transfer_v1(
            &morphology,
            &scheduled_load_transfer_request(&morphology, SCHEDULED_LOAD_TRANSFER_BW9L_D_POLICY_ID),
        )
        .unwrap();

        assert_eq!(control.mode, ScheduledLoadTransferModeV1::Control);
        assert!(!control.active);
        assert_eq!(control.activation_reason, "control_policy");
        for receipt in [&preferred, &centroid, &combined] {
            assert!(receipt.active);
            assert_eq!(receipt.activation_reason, "scheduled_loaded_swing_limb");
            assert_eq!(receipt.scheduled_limb_id.as_deref(), Some("rear_left"));
            assert_eq!(receipt.scheduled_local_phase_step, Some(54));
            assert_eq!(
                receipt.ordered_scheduled_unweighted_contact_ids,
                ["rear_left_foot"]
            );
            assert_eq!(receipt.remaining_support_contact_ids.len(), 3);
            assert!(receipt.activation_uses_scheduler_boundaries_only);
            assert_eq!(receipt.morphology_branch_surface_count, 0);
            assert!(!receipt.per_foot_measured_load_allocation_available);
            assert!(!receipt.commands_are_measurements);
            assert!(!receipt.adapter_actuation_applied);
            assert!(!receipt.physics_state_modified);
            assert!(!receipt.walking_claim_authorized);
            assert!(!receipt.physical_acceptance_authority);
        }

        let control_preferences = control
            .ordered_contact_preferences
            .iter()
            .map(|contact| contact.preferred_normal_force_n)
            .collect::<Vec<_>>();
        let preferred_preferences = preferred
            .ordered_contact_preferences
            .iter()
            .map(|contact| contact.preferred_normal_force_n)
            .collect::<Vec<_>>();
        let centroid_preferences = centroid
            .ordered_contact_preferences
            .iter()
            .map(|contact| contact.preferred_normal_force_n)
            .collect::<Vec<_>>();
        let combined_preferences = combined
            .ordered_contact_preferences
            .iter()
            .map(|contact| contact.preferred_normal_force_n)
            .collect::<Vec<_>>();
        assert!(control_preferences.iter().all(|force| *force == 0.0));
        assert!(centroid_preferences.iter().all(|force| *force == 0.0));
        assert_eq!(preferred_preferences, combined_preferences);
        let rear_left_index = morphology
            .ordered_contact_site_ids
            .iter()
            .position(|contact_id| contact_id == "rear_left_foot")
            .unwrap();
        assert_eq!(preferred_preferences[rear_left_index], 0.0);
        assert!(preferred_preferences.iter().any(|force| *force > 0.0));

        assert_eq!(
            control.target_center_of_mass_world_m,
            preferred.target_center_of_mass_world_m
        );
        assert_eq!(
            centroid.target_center_of_mass_world_m,
            combined.target_center_of_mass_world_m
        );
        assert_ne!(
            control.target_center_of_mass_world_m,
            centroid.target_center_of_mass_world_m
        );
        assert_eq!(
            control.centroidal_request.horizontal_position_gain_n_per_m,
            P5I3C_HORIZONTAL_POSITION_GAIN_N_PER_M
        );
        assert_eq!(
            control.centroidal_request.maximum_horizontal_force_n,
            P5I3C_MAXIMUM_HORIZONTAL_FORCE_N
        );
    }

    #[test]
    fn scheduled_load_transfer_fails_safe_when_support_or_scheduler_is_ambiguous() {
        let morphology = compile_bounded_quadruped(descriptor()).unwrap().morphology;
        let mut partial =
            scheduled_load_transfer_request(&morphology, SCHEDULED_LOAD_TRANSFER_BW9L_D_POLICY_ID);
        partial.stability_state.ordered_support_contacts[0].bears_support = Some(false);
        let receipt = plan_scheduled_load_transfer_v1(&morphology, &partial).unwrap();
        assert!(!receipt.active);
        assert_eq!(receipt.activation_reason, "qualified_support_not_full");
        assert!(
            receipt
                .ordered_contact_preferences
                .iter()
                .all(|contact| contact.preferred_normal_force_n == 0.0)
        );

        let mut reordered =
            scheduled_load_transfer_request(&morphology, SCHEDULED_LOAD_TRANSFER_BW9L_D_POLICY_ID);
        reordered.ordered_limb_gait_steps.swap(0, 1);
        assert!(plan_scheduled_load_transfer_v1(&morphology, &reordered).is_err());

        let mut zero =
            scheduled_load_transfer_request(&morphology, SCHEDULED_LOAD_TRANSFER_BW9L_D_POLICY_ID);
        zero.gait_amplitude = 0.0;
        let receipt = plan_scheduled_load_transfer_v1(&morphology, &zero).unwrap();
        assert!(!receipt.active);
        assert_eq!(receipt.activation_reason, "zero_gait_amplitude");
    }

    #[test]
    fn scheduled_load_transfer_v2_full_support_preserves_v1_factorial_semantics() {
        let morphology = compile_bounded_quadruped(descriptor()).unwrap().morphology;
        let family = [
            (
                SCHEDULED_LOAD_TRANSFER_BW10F_A_POLICY_ID,
                SCHEDULED_LOAD_TRANSFER_BW9L_A_POLICY_ID,
                ScheduledLoadTransferModeV1::Control,
            ),
            (
                SCHEDULED_LOAD_TRANSFER_BW10F_B_POLICY_ID,
                SCHEDULED_LOAD_TRANSFER_BW9L_B_POLICY_ID,
                ScheduledLoadTransferModeV1::PreferredNormalForce,
            ),
            (
                SCHEDULED_LOAD_TRANSFER_BW10F_C_POLICY_ID,
                SCHEDULED_LOAD_TRANSFER_BW9L_C_POLICY_ID,
                ScheduledLoadTransferModeV1::RemainingSupportCentroid,
            ),
            (
                SCHEDULED_LOAD_TRANSFER_BW10F_D_POLICY_ID,
                SCHEDULED_LOAD_TRANSFER_BW9L_D_POLICY_ID,
                ScheduledLoadTransferModeV1::Combined,
            ),
        ];
        for (v2_policy_id, v1_policy_id, expected_mode) in family {
            let v1 = plan_scheduled_load_transfer_v1(
                &morphology,
                &scheduled_load_transfer_request(&morphology, v1_policy_id),
            )
            .unwrap();
            let v2 = plan_scheduled_load_transfer_v2(
                &morphology,
                &scheduled_load_transfer_request_v2(&morphology, v2_policy_id),
            )
            .unwrap();

            assert_eq!(v2.mode, expected_mode);
            assert_eq!(
                v2.planning_availability,
                StabilityInfluenceAvailability::Available
            );
            assert_eq!(v2.planning_outcome_code, "AVAILABLE");
            assert!(!v2.fail_zero_required);
            assert_eq!(v2.active, v1.active);
            assert_eq!(v2.scheduled_limb_id, v1.scheduled_limb_id);
            assert_eq!(
                v2.ordered_scheduled_unweighted_contact_ids,
                v1.ordered_scheduled_unweighted_contact_ids
            );
            assert_eq!(
                v2.baseline_target_center_of_mass_world_m,
                Some(v1.baseline_target_center_of_mass_world_m)
            );
            assert_eq!(
                v2.target_center_of_mass_world_m,
                Some(v1.target_center_of_mass_world_m)
            );
            assert_eq!(v2.centroidal_request, Some(v1.centroidal_request));
            assert_eq!(v2.centroidal_command, Some(v1.centroidal_command));
            assert!(v2.ordered_safe_zero_actuator_ids.is_empty());
            assert_eq!(v2.morphology_branch_surface_count, 0);
            assert!(!v2.walking_claim_authorized);
            assert!(!v2.physical_acceptance_authority);
        }
    }

    #[test]
    fn scheduled_load_transfer_v2_receipts_two_contact_unavailability_as_safe_zero() {
        let morphology = compile_bounded_quadruped(descriptor()).unwrap().morphology;
        let mut request = scheduled_load_transfer_request_v2(
            &morphology,
            SCHEDULED_LOAD_TRANSFER_BW10F_D_POLICY_ID,
        );
        request.stability_state.ordered_support_contacts[0].bears_support = Some(false);
        request.stability_state.ordered_support_contacts[1].bears_support = Some(false);

        let receipt = plan_scheduled_load_transfer_v2(&morphology, &request).unwrap();
        assert_eq!(
            receipt.planning_availability,
            StabilityInfluenceAvailability::ObservationUnavailable
        );
        assert_eq!(
            receipt.planning_outcome_code,
            "PLANNING_UNAVAILABLE:CONTACT_INVALID:centroidal_support_contact_set_too_small"
        );
        assert!(receipt.fail_zero_required);
        assert!(!receipt.active);
        assert_eq!(receipt.qualified_support_contact_ids.len(), 2);
        assert!(receipt.centroidal_request.is_none());
        assert!(receipt.centroidal_command.is_none());
        assert_eq!(
            receipt.ordered_safe_zero_actuator_ids,
            morphology.ordered_actuator_ids
        );
    }

    #[test]
    fn scheduled_load_transfer_v2_receipts_rank_deficiency_as_safe_zero() {
        let morphology = compile_bounded_quadruped(descriptor()).unwrap().morphology;
        let mut request = scheduled_load_transfer_request_v2(
            &morphology,
            SCHEDULED_LOAD_TRANSFER_BW10F_C_POLICY_ID,
        );
        for (index, contact) in request
            .stability_state
            .ordered_support_contacts
            .iter_mut()
            .enumerate()
        {
            contact.point_world_m = Some(Vec3 {
                x: index as f64 * 0.10,
                y: 0.0,
                z: 0.0,
            });
        }

        let receipt = plan_scheduled_load_transfer_v2(&morphology, &request).unwrap();
        assert_eq!(
            receipt.planning_availability,
            StabilityInfluenceAvailability::ObservationUnavailable
        );
        assert_eq!(
            receipt.planning_outcome_code,
            "PLANNING_UNAVAILABLE:FRAME_INVALID:centroidal_support_geometry_rank_deficient"
        );
        assert!(receipt.fail_zero_required);
        assert!(receipt.centroidal_command.is_none());
        assert_eq!(
            receipt.ordered_safe_zero_actuator_ids,
            morphology.ordered_actuator_ids
        );
    }

    #[test]
    fn scheduled_load_transfer_v2_receipts_centroidal_infeasibility_as_safe_zero() {
        let morphology = compile_bounded_quadruped(descriptor()).unwrap().morphology;
        let mut request = scheduled_load_transfer_request_v2(
            &morphology,
            SCHEDULED_LOAD_TRANSFER_BW10F_D_POLICY_ID,
        );
        request.maximum_normal_force_n = 0.01;

        let receipt = plan_scheduled_load_transfer_v2(&morphology, &request).unwrap();
        assert_eq!(
            receipt.planning_availability,
            StabilityInfluenceAvailability::UpstreamInfeasible
        );
        assert!(
            receipt
                .planning_outcome_code
                .starts_with("UPSTREAM_INFEASIBLE:")
        );
        assert!(receipt.fail_zero_required);
        assert!(!receipt.active);
        assert_eq!(receipt.activation_reason, "centroidal_command_infeasible");
        assert_eq!(
            receipt
                .centroidal_command
                .as_ref()
                .map(|command| command.feasible),
            Some(false)
        );
        assert_eq!(
            receipt.ordered_safe_zero_actuator_ids,
            morphology.ordered_actuator_ids
        );
    }

    #[test]
    fn scheduled_load_transfer_v3_available_path_preserves_v2_factorial_semantics() {
        let morphology = compile_bounded_quadruped(descriptor()).unwrap().morphology;
        let family = [
            (
                SCHEDULED_LOAD_TRANSFER_BW11R_A_POLICY_ID,
                SCHEDULED_LOAD_TRANSFER_BW10F_A_POLICY_ID,
            ),
            (
                SCHEDULED_LOAD_TRANSFER_BW11R_B_POLICY_ID,
                SCHEDULED_LOAD_TRANSFER_BW10F_B_POLICY_ID,
            ),
            (
                SCHEDULED_LOAD_TRANSFER_BW11R_C_POLICY_ID,
                SCHEDULED_LOAD_TRANSFER_BW10F_C_POLICY_ID,
            ),
            (
                SCHEDULED_LOAD_TRANSFER_BW11R_D_POLICY_ID,
                SCHEDULED_LOAD_TRANSFER_BW10F_D_POLICY_ID,
            ),
        ];
        for (v3_policy_id, v2_policy_id) in family {
            let v2 = plan_scheduled_load_transfer_v2(
                &morphology,
                &scheduled_load_transfer_request_v2(&morphology, v2_policy_id),
            )
            .unwrap();
            let v3 = plan_scheduled_load_transfer_v3(
                &morphology,
                &scheduled_load_transfer_request_v3(&morphology, v3_policy_id),
            )
            .unwrap();
            assert_eq!(
                v3.schema_version,
                SCHEDULED_LOAD_TRANSFER_RECEIPT_V3_VERSION
            );
            assert_eq!(v3.mode, v2.mode);
            assert!(v3.observation_input_available);
            assert!(v3.observation_unavailable_reason.is_none());
            assert_eq!(v3.planning_availability, v2.planning_availability);
            assert_eq!(v3.planning_outcome_code, v2.planning_outcome_code);
            assert_eq!(v3.fail_zero_required, v2.fail_zero_required);
            assert_eq!(v3.active, v2.active);
            assert_eq!(v3.centroidal_request, v2.centroidal_request);
            assert_eq!(v3.centroidal_command, v2.centroidal_command);
            assert_eq!(
                v3.ordered_safe_zero_actuator_ids,
                v2.ordered_safe_zero_actuator_ids
            );
            assert_eq!(v3.morphology_branch_surface_count, 0);
            assert!(!v3.walking_claim_authorized);
            assert!(!v3.physical_acceptance_authority);
        }
    }

    #[test]
    fn scheduled_load_transfer_bw13p_is_progressive_mass_conserving_and_branch_free() {
        let morphology = compile_bounded_quadruped(descriptor()).unwrap().morphology;
        let family = [
            (
                SCHEDULED_LOAD_TRANSFER_BW13P_A_POLICY_ID,
                ScheduledLoadTransferModeV1::Control,
            ),
            (
                SCHEDULED_LOAD_TRANSFER_BW13P_B_POLICY_ID,
                ScheduledLoadTransferModeV1::PreferredNormalForce,
            ),
            (
                SCHEDULED_LOAD_TRANSFER_BW13P_C_POLICY_ID,
                ScheduledLoadTransferModeV1::RemainingSupportCentroid,
            ),
            (
                SCHEDULED_LOAD_TRANSFER_BW13P_D_POLICY_ID,
                ScheduledLoadTransferModeV1::Combined,
            ),
        ];
        let receipts = family
            .iter()
            .map(|(policy_id, expected_mode)| {
                let receipt = plan_scheduled_load_transfer_v3(
                    &morphology,
                    &scheduled_load_transfer_request_v3(&morphology, policy_id),
                )
                .unwrap();
                assert_eq!(receipt.mode, *expected_mode);
                assert_eq!(
                    receipt.planning_availability,
                    StabilityInfluenceAvailability::Available
                );
                assert!(!receipt.fail_zero_required);
                assert_eq!(receipt.morphology_branch_surface_count, 0);
                assert!(!receipt.per_foot_measured_load_allocation_available);
                assert!(!receipt.commands_are_measurements);
                assert!(!receipt.adapter_actuation_applied);
                assert!(!receipt.physics_state_modified);
                assert!(!receipt.walking_claim_authorized);
                assert!(!receipt.physical_acceptance_authority);
                let preferred_sum = receipt
                    .ordered_contact_preferences
                    .iter()
                    .map(|contact| contact.preferred_normal_force_n)
                    .sum::<f64>();
                let request = receipt.centroidal_request.as_ref().unwrap();
                let commanded_weight =
                    request.whole_system_mass_kg * norm(request.gravity_world_m_s2);
                assert!((preferred_sum - commanded_weight).abs() <= 1.0e-10);
                receipt
            })
            .collect::<Vec<_>>();

        let control = &receipts[0];
        let normal = &receipts[1];
        let centroid = &receipts[2];
        let combined = &receipts[3];
        assert!(!control.active);
        assert_eq!(
            control.activation_reason,
            "progressive_mass_conserving_control"
        );
        for receipt in [normal, centroid, combined] {
            assert!(receipt.active);
            assert_eq!(receipt.scheduled_limb_id.as_deref(), Some("rear_left"));
            assert_eq!(receipt.scheduled_local_phase_step, Some(54));
            assert_eq!(
                receipt.ordered_scheduled_unweighted_contact_ids,
                ["rear_left_foot"]
            );
            assert_eq!(receipt.remaining_support_contact_ids.len(), 3);
        }

        let rear_left_index = morphology
            .ordered_contact_site_ids
            .iter()
            .position(|contact_id| contact_id == "rear_left_foot")
            .unwrap();
        let uniform = control.ordered_contact_preferences[rear_left_index].preferred_normal_force_n;
        assert!(
            control
                .ordered_contact_preferences
                .iter()
                .all(|contact| (contact.preferred_normal_force_n - uniform).abs() <= 1.0e-12)
        );
        assert!(
            centroid
                .ordered_contact_preferences
                .iter()
                .all(|contact| (contact.preferred_normal_force_n - uniform).abs() <= 1.0e-12)
        );
        let local_fraction = 54.0 / 71.0;
        let expected_progress = local_fraction * local_fraction * (3.0 - 2.0 * local_fraction);
        let expected_scheduled_preference = uniform * (1.0 - expected_progress);
        for receipt in [normal, combined] {
            assert!(
                (receipt.ordered_contact_preferences[rear_left_index].preferred_normal_force_n
                    - expected_scheduled_preference)
                    .abs()
                    <= 1.0e-10
            );
            assert!(receipt.ordered_contact_preferences.iter().any(|contact| {
                contact.contact_id != "rear_left_foot" && contact.preferred_normal_force_n > uniform
            }));
        }

        assert_eq!(
            control.target_center_of_mass_world_m,
            normal.target_center_of_mass_world_m
        );
        assert_eq!(
            centroid.target_center_of_mass_world_m,
            combined.target_center_of_mass_world_m
        );
        let old_full_shift = plan_scheduled_load_transfer_v3(
            &morphology,
            &scheduled_load_transfer_request_v3(
                &morphology,
                SCHEDULED_LOAD_TRANSFER_BW11R_C_POLICY_ID,
            ),
        )
        .unwrap();
        let baseline = control.target_center_of_mass_world_m.unwrap();
        let full_target = old_full_shift.target_center_of_mass_world_m.unwrap();
        let progressive_target = centroid.target_center_of_mass_world_m.unwrap();
        let expected_target = add(
            baseline,
            scale(subtract(full_target, baseline), expected_progress),
        );
        assert!((progressive_target.x - expected_target.x).abs() <= 1.0e-12);
        assert!((progressive_target.y - expected_target.y).abs() <= 1.0e-12);
        assert!((progressive_target.z - expected_target.z).abs() <= 1.0e-12);
    }

    #[test]
    fn scheduled_load_transfer_bw13p_evaluates_its_own_feasibility() {
        let morphology = compile_bounded_quadruped(descriptor()).unwrap().morphology;
        let commanded_weight_n = morphology.total_mass_kg * 9.8;
        let maximum_normal_force_n = commanded_weight_n * 0.30;

        // At local swing phase zero, the progressive command is exactly
        // uniform (25% per contact). The predecessor's full-transfer
        // preferences still place 33.3% on two contacts after projection.
        // This makes the predecessor infeasible under this bound while the
        // actual BW13P command remains feasible.
        let mut predecessor = scheduled_load_transfer_request_v2(
            &morphology,
            SCHEDULED_LOAD_TRANSFER_BW10F_D_POLICY_ID,
        );
        predecessor.maximum_normal_force_n = maximum_normal_force_n;
        for limb in &mut predecessor.ordered_limb_gait_steps {
            limb.gait_step = 0;
        }
        let predecessor_receipt =
            plan_scheduled_load_transfer_v2(&morphology, &predecessor).unwrap();
        assert_eq!(
            predecessor_receipt.planning_availability,
            StabilityInfluenceAvailability::UpstreamInfeasible
        );

        let mut progressive = scheduled_load_transfer_request_v3(
            &morphology,
            SCHEDULED_LOAD_TRANSFER_BW13P_D_POLICY_ID,
        );
        progressive.maximum_normal_force_n = maximum_normal_force_n;
        for limb in &mut progressive.ordered_limb_gait_steps {
            limb.gait_step = 0;
        }
        let progressive_receipt =
            plan_scheduled_load_transfer_v3(&morphology, &progressive).unwrap();
        assert_eq!(
            progressive_receipt.planning_availability,
            StabilityInfluenceAvailability::Available
        );
        assert!(!progressive_receipt.fail_zero_required);
        assert!(progressive_receipt.active);
        assert_eq!(progressive_receipt.scheduled_local_phase_step, Some(0));
        assert!(
            progressive_receipt
                .centroidal_command
                .as_ref()
                .is_some_and(|command| command.feasible)
        );
        let expected_uniform_n = commanded_weight_n / 4.0;
        assert!(
            progressive_receipt
                .ordered_contact_preferences
                .iter()
                .all(
                    |contact| (contact.preferred_normal_force_n - expected_uniform_n).abs()
                        <= 1.0e-10
                )
        );
    }

    #[test]
    fn scheduled_load_transfer_bw13p_unavailable_path_is_typed_safe_zero() {
        let morphology = compile_bounded_quadruped(descriptor()).unwrap().morphology;
        for policy_id in [
            SCHEDULED_LOAD_TRANSFER_BW13P_A_POLICY_ID,
            SCHEDULED_LOAD_TRANSFER_BW13P_B_POLICY_ID,
            SCHEDULED_LOAD_TRANSFER_BW13P_C_POLICY_ID,
            SCHEDULED_LOAD_TRANSFER_BW13P_D_POLICY_ID,
        ] {
            let mut request = scheduled_load_transfer_request_v3(&morphology, policy_id);
            request.observation_available = false;
            request.observation_unavailable_reason =
                Some("NO_QUALIFIED_SUPPORT_CONTACT".to_owned());
            request.stability_state = None;
            let receipt = plan_scheduled_load_transfer_v3(&morphology, &request).unwrap();
            assert_eq!(
                receipt.planning_availability,
                StabilityInfluenceAvailability::ObservationUnavailable
            );
            assert!(receipt.fail_zero_required);
            assert!(!receipt.active);
            assert_eq!(
                receipt.ordered_safe_zero_actuator_ids,
                morphology.ordered_actuator_ids
            );
            assert!(receipt.centroidal_request.is_none());
            assert!(receipt.centroidal_command.is_none());
        }
    }

    #[test]
    fn scheduled_load_transfer_v3_receipts_missing_observation_without_state() {
        let morphology = compile_bounded_quadruped(descriptor()).unwrap().morphology;
        let mut request = scheduled_load_transfer_request_v3(
            &morphology,
            SCHEDULED_LOAD_TRANSFER_BW11R_D_POLICY_ID,
        );
        request.observation_available = false;
        request.observation_unavailable_reason = Some("NO_QUALIFIED_SUPPORT_CONTACT".to_owned());
        request.stability_state = None;

        let receipt = plan_scheduled_load_transfer_v3(&morphology, &request).unwrap();
        assert_eq!(receipt.semantic_step, request.semantic_step);
        assert!(!receipt.observation_input_available);
        assert_eq!(
            receipt.observation_unavailable_reason.as_deref(),
            Some("NO_QUALIFIED_SUPPORT_CONTACT")
        );
        assert_eq!(
            receipt.planning_availability,
            StabilityInfluenceAvailability::ObservationUnavailable
        );
        assert_eq!(
            receipt.planning_outcome_code,
            "OBSERVATION_UNAVAILABLE:NO_QUALIFIED_SUPPORT_CONTACT"
        );
        assert!(receipt.fail_zero_required);
        assert!(!receipt.active);
        assert!(receipt.centroidal_request.is_none());
        assert!(receipt.centroidal_command.is_none());
        assert_eq!(
            receipt.ordered_safe_zero_actuator_ids,
            morphology.ordered_actuator_ids
        );
    }

    #[test]
    fn scheduled_load_transfer_v3_receipts_unusable_emitted_state_without_observing_it() {
        let morphology = compile_bounded_quadruped(descriptor()).unwrap().morphology;
        let mut request = scheduled_load_transfer_request_v3(
            &morphology,
            SCHEDULED_LOAD_TRANSFER_BW11R_C_POLICY_ID,
        );
        request.observation_available = false;
        request.observation_unavailable_reason = Some("NO_QUALIFIED_SUPPORT_CONTACT".to_owned());
        for contact in &mut request
            .stability_state
            .as_mut()
            .unwrap()
            .ordered_support_contacts
        {
            contact.presence = Some(false);
            contact.bears_support = Some(false);
            contact.point_world_m = None;
        }

        let receipt = plan_scheduled_load_transfer_v3(&morphology, &request).unwrap();
        assert_eq!(
            receipt.planning_availability,
            StabilityInfluenceAvailability::ObservationUnavailable
        );
        assert!(receipt.fail_zero_required);
        assert!(receipt.qualified_support_contact_ids.is_empty());
        assert_eq!(
            receipt.ordered_safe_zero_actuator_ids,
            morphology.ordered_actuator_ids
        );
    }

    #[test]
    fn scheduled_load_transfer_v3_rejects_availability_contradictions() {
        let morphology = compile_bounded_quadruped(descriptor()).unwrap().morphology;
        let base = scheduled_load_transfer_request_v3(
            &morphology,
            SCHEDULED_LOAD_TRANSFER_BW11R_D_POLICY_ID,
        );

        let mut missing_state = base.clone();
        missing_state.stability_state = None;
        assert!(plan_scheduled_load_transfer_v3(&morphology, &missing_state).is_err());

        let mut contradictory_reason = base.clone();
        contradictory_reason.observation_unavailable_reason = Some("CONTRADICTION".to_owned());
        assert!(plan_scheduled_load_transfer_v3(&morphology, &contradictory_reason).is_err());

        let mut missing_reason = base.clone();
        missing_reason.observation_available = false;
        missing_reason.observation_unavailable_reason = None;
        assert!(plan_scheduled_load_transfer_v3(&morphology, &missing_reason).is_err());

        let mut blank_reason = base.clone();
        blank_reason.observation_available = false;
        blank_reason.observation_unavailable_reason = Some("  ".to_owned());
        assert!(plan_scheduled_load_transfer_v3(&morphology, &blank_reason).is_err());

        let mut stale_state = base;
        stale_state.semantic_step += 1;
        assert!(plan_scheduled_load_transfer_v3(&morphology, &stale_state).is_err());
    }

    #[test]
    fn scheduled_load_transfer_v3_unavailable_path_still_requires_scheduler_order() {
        let morphology = compile_bounded_quadruped(descriptor()).unwrap().morphology;
        let mut request = scheduled_load_transfer_request_v3(
            &morphology,
            SCHEDULED_LOAD_TRANSFER_BW11R_D_POLICY_ID,
        );
        request.observation_available = false;
        request.observation_unavailable_reason = Some("HOST_OBSERVATION_UNAVAILABLE".to_owned());
        request.stability_state = None;
        request.ordered_limb_gait_steps.swap(0, 1);
        assert!(plan_scheduled_load_transfer_v3(&morphology, &request).is_err());
    }

    fn centroidal_request() -> CentroidalSupportRequestV2 {
        CentroidalSupportRequestV2 {
            schema_version: CENTROIDAL_REQUEST_VERSION.to_owned(),
            semantic_step: 0,
            whole_system_mass_kg: 8.0,
            gravity_world_m_s2: Vec3 {
                x: 0.0,
                y: -9.8,
                z: 0.0,
            },
            support_plane_forward_world_unit: Vec3 {
                x: 1.0,
                y: 0.0,
                z: 0.0,
            },
            center_of_mass_world_m: Vec3 {
                x: 0.09,
                y: 0.38625,
                z: -0.09,
            },
            center_of_mass_velocity_world_m_s: Vec3::ZERO,
            target_center_of_mass_world_m: Vec3 {
                x: 0.09,
                y: 0.38625,
                z: -0.09,
            },
            torso_roll_rad: 0.0,
            torso_pitch_rad: 0.0,
            torso_roll_rate_rad_s: 0.0,
            torso_pitch_rate_rad_s: 0.0,
            horizontal_position_gain_n_per_m: 160.0,
            horizontal_velocity_gain_ns_per_m: 24.0,
            vertical_position_gain_n_per_m: 200.0,
            vertical_velocity_gain_ns_per_m: 30.0,
            roll_position_gain_nm_per_rad: 30.0,
            roll_velocity_gain_nm_s_per_rad: 4.0,
            pitch_position_gain_nm_per_rad: 30.0,
            pitch_velocity_gain_nm_s_per_rad: 4.0,
            maximum_horizontal_force_n: 30.0,
            maximum_vertical_correction_n: 20.0,
            maximum_roll_pitch_moment_nm: 6.0,
            declared_supported_weight_fraction: 1.0,
            characterized_friction_coefficient: 0.60,
            minimum_normal_force_n: 0.0,
            maximum_normal_force_n: 39.2,
            nominal_support_count: 4,
            feasibility_tolerance: 1.0e-5,
            support_contacts: vec![
                CentroidalSupportContactV2 {
                    contact_id: "front_left".to_owned(),
                    point_world_m: Vec3 {
                        x: -0.22,
                        y: 0.0,
                        z: -0.22,
                    },
                    preferred_normal_force_n: 0.0,
                },
                CentroidalSupportContactV2 {
                    contact_id: "rear_left".to_owned(),
                    point_world_m: Vec3 {
                        x: 0.22,
                        y: 0.0,
                        z: -0.22,
                    },
                    preferred_normal_force_n: 0.0,
                },
                CentroidalSupportContactV2 {
                    contact_id: "rear_right".to_owned(),
                    point_world_m: Vec3 {
                        x: 0.22,
                        y: 0.0,
                        z: 0.22,
                    },
                    preferred_normal_force_n: 0.0,
                },
            ],
        }
    }

    fn endpoint_map_centroidal_request() -> CentroidalSupportRequestV2 {
        let mut centroidal = centroidal_request();
        centroidal.support_contacts = vec![
            CentroidalSupportContactV2 {
                contact_id: "front_left_foot".to_owned(),
                point_world_m: Vec3 {
                    x: -0.22,
                    y: 0.0,
                    z: -0.22,
                },
                preferred_normal_force_n: 0.0,
            },
            CentroidalSupportContactV2 {
                contact_id: "rear_left_foot".to_owned(),
                point_world_m: Vec3 {
                    x: 0.22,
                    y: 0.0,
                    z: -0.22,
                },
                preferred_normal_force_n: 0.0,
            },
            CentroidalSupportContactV2 {
                contact_id: "rear_right_foot".to_owned(),
                point_world_m: Vec3 {
                    x: 0.22,
                    y: 0.0,
                    z: 0.22,
                },
                preferred_normal_force_n: 0.0,
            },
            CentroidalSupportContactV2 {
                contact_id: "front_right_foot".to_owned(),
                point_world_m: Vec3 {
                    x: -0.22,
                    y: 0.0,
                    z: 0.22,
                },
                preferred_normal_force_n: 0.0,
            },
        ];
        centroidal
    }

    fn endpoint_map_request(morphology: &CompiledMorphology) -> EndpointForceJointMapRequestV2 {
        let centroidal = endpoint_map_centroidal_request();
        let mut command = command_centroidal_support_v2(&centroidal).unwrap();
        for contact in &mut command.ordered_support_contact_commands {
            contact.joint_task_force_delta_world_n = Vec3 {
                x: 2.0,
                y: 0.0,
                z: 0.0,
            };
        }
        let ordered_actuator_kinematics = morphology
            .morphology_spec
            .actuators
            .iter()
            .map(|actuator| {
                let limb = morphology
                    .morphology_spec
                    .limbs
                    .iter()
                    .find(|limb| limb.ordered_joint_ids.contains(&actuator.joint_id))
                    .unwrap();
                let joint_index = limb
                    .ordered_joint_ids
                    .iter()
                    .position(|joint_id| joint_id == &actuator.joint_id)
                    .unwrap();
                EndpointForceActuatorKinematicsV2 {
                    actuator_id: actuator.actuator_id.clone(),
                    contact_site_id: limb.ordered_contact_site_ids[0].clone(),
                    joint_anchor_world_m: Vec3 {
                        x: 0.0,
                        y: -0.25 * joint_index as f64,
                        z: 0.0,
                    },
                    joint_axis_world_unit: Vec3 {
                        x: 0.0,
                        y: 0.0,
                        z: 1.0,
                    },
                    endpoint_world_m: Vec3 {
                        x: 0.0,
                        y: -0.5,
                        z: 0.0,
                    },
                }
            })
            .collect();
        EndpointForceJointMapRequestV2 {
            schema_version: ENDPOINT_FORCE_JOINT_MAP_REQUEST_VERSION.to_owned(),
            semantic_step: command.semantic_step,
            centroidal_command: command,
            ordered_actuator_kinematics,
        }
    }

    fn endpoint_map_request_v3(
        morphology: &CompiledMorphology,
        inactive_contact_id: Option<&str>,
    ) -> EndpointForceJointMapRequestV3 {
        let mut centroidal = endpoint_map_centroidal_request();
        if let Some(inactive_contact_id) = inactive_contact_id {
            centroidal
                .support_contacts
                .retain(|contact| contact.contact_id != inactive_contact_id);
        }
        let mut command = command_centroidal_support_v2(&centroidal).unwrap();
        assert!(command.feasible);
        for contact in &mut command.ordered_support_contact_commands {
            contact.joint_task_force_delta_world_n = Vec3 {
                x: 2.0,
                y: 0.0,
                z: 0.0,
            };
        }
        let ordered_actuator_kinematics =
            endpoint_map_request(morphology).ordered_actuator_kinematics;
        EndpointForceJointMapRequestV3 {
            schema_version: ENDPOINT_FORCE_JOINT_MAP_REQUEST_V3_VERSION.to_owned(),
            semantic_step: command.semantic_step,
            centroidal_command: command,
            ordered_actuator_kinematics,
        }
    }

    #[test]
    fn centroidal_allocator_matches_gdscript_force_and_moment_golden() {
        let command = command_centroidal_support_v2(&centroidal_request()).unwrap();
        assert!(command.feasible);
        assert!(norm(command.force_residual_n) <= 1.0e-6);
        assert!(
            (command.roll_pitch_moment_residual_nm[0].powi(2)
                + command.roll_pitch_moment_residual_nm[1].powi(2))
            .sqrt()
                <= 1.0e-6
        );
        let normal_sum: f64 = command
            .ordered_support_contact_commands
            .iter()
            .map(|contact| contact.normal_force_command_n)
            .sum();
        let task_vertical_sum: f64 = command
            .ordered_support_contact_commands
            .iter()
            .map(|contact| contact.joint_task_force_delta_world_n.y)
            .sum();
        assert!((normal_sum - 78.4).abs() <= 1.0e-5);
        assert!((task_vertical_sum + 19.6).abs() <= 1.0e-5);
        assert!(!command.per_foot_measured_load_allocation_available);
        assert!(!command.actuator_mapping_available);
        assert!(!command.physical_acceptance_authority);
    }

    #[test]
    fn centroidal_allocator_reports_friction_and_geometry_infeasibility() {
        let mut friction = centroidal_request();
        friction.target_center_of_mass_world_m = Vec3 {
            x: 1.0,
            y: 0.38625,
            z: -0.09,
        };
        friction.maximum_horizontal_force_n = 200.0;
        friction.horizontal_position_gain_n_per_m = 1000.0;
        let command = command_centroidal_support_v2(&friction).unwrap();
        assert!(!command.feasible);
        assert!(
            command
                .infeasibility_reasons
                .iter()
                .any(|reason| reason.starts_with("FRICTION_EXCEEDED:"))
        );
        let mut rank_deficient = centroidal_request();
        rank_deficient.support_contacts = vec![
            CentroidalSupportContactV2 {
                contact_id: "a".to_owned(),
                point_world_m: Vec3 {
                    x: -0.2,
                    y: 0.0,
                    z: 0.0,
                },
                preferred_normal_force_n: 0.0,
            },
            CentroidalSupportContactV2 {
                contact_id: "b".to_owned(),
                point_world_m: Vec3::ZERO,
                preferred_normal_force_n: 0.0,
            },
            CentroidalSupportContactV2 {
                contact_id: "c".to_owned(),
                point_world_m: Vec3 {
                    x: 0.2,
                    y: 0.0,
                    z: 0.0,
                },
                preferred_normal_force_n: 0.0,
            },
        ];
        assert!(command_centroidal_support_v2(&rank_deficient).is_err());
    }

    #[test]
    fn endpoint_force_joint_map_matches_virtual_work_and_translation_invariance() {
        let morphology = compile_bounded_quadruped(descriptor()).unwrap().morphology;
        let request = endpoint_map_request(&morphology);
        let receipt = map_endpoint_force_to_joint_v2(&morphology, &request).unwrap();
        assert_eq!(
            receipt.schema_version,
            ENDPOINT_FORCE_JOINT_MAP_RECEIPT_VERSION
        );
        assert_eq!(
            receipt.ordered_generalized_joint_torque_commands.len(),
            morphology.ordered_actuator_ids.len()
        );
        let first = &receipt.ordered_generalized_joint_torque_commands[0];
        let second = &receipt.ordered_generalized_joint_torque_commands[1];
        assert_eq!(
            first.linear_jacobian_column_world_m,
            Vec3 {
                x: 0.5,
                y: 0.0,
                z: 0.0
            }
        );
        assert!((first.generalized_torque_command_nm - 1.0).abs() <= 1.0e-12);
        assert!((second.generalized_torque_command_nm - 0.5).abs() <= 1.0e-12);
        assert!(first.command_not_measurement);
        assert!(!receipt.measured_joint_torque_available);
        assert!(!receipt.actuator_response_characterized);
        assert!(!receipt.adapter_actuation_applied);
        assert!(!receipt.physics_state_modified);
        assert!(!receipt.physical_acceptance_authority);

        let mut translated = request.clone();
        let offset = Vec3 {
            x: 9.0,
            y: -2.0,
            z: 4.0,
        };
        for kinematics in &mut translated.ordered_actuator_kinematics {
            kinematics.joint_anchor_world_m = add(kinematics.joint_anchor_world_m, offset);
            kinematics.endpoint_world_m = add(kinematics.endpoint_world_m, offset);
        }
        let translated_receipt = map_endpoint_force_to_joint_v2(&morphology, &translated).unwrap();
        assert_eq!(
            receipt.ordered_generalized_joint_torque_commands,
            translated_receipt.ordered_generalized_joint_torque_commands
        );
    }

    #[test]
    fn endpoint_force_joint_map_reverses_with_endpoint_force() {
        let morphology = compile_bounded_quadruped(descriptor()).unwrap().morphology;
        let request = endpoint_map_request(&morphology);
        let original = map_endpoint_force_to_joint_v2(&morphology, &request).unwrap();
        let mut reversed = request;
        for command in &mut reversed.centroidal_command.ordered_support_contact_commands {
            command.joint_task_force_delta_world_n =
                scale(command.joint_task_force_delta_world_n, -1.0);
        }
        let mirrored = map_endpoint_force_to_joint_v2(&morphology, &reversed).unwrap();
        for (positive, negative) in original
            .ordered_generalized_joint_torque_commands
            .iter()
            .zip(&mirrored.ordered_generalized_joint_torque_commands)
        {
            assert!(
                (positive.generalized_torque_command_nm + negative.generalized_torque_command_nm)
                    .abs()
                    <= 1.0e-12
            );
        }
    }

    #[test]
    fn endpoint_force_joint_map_rejects_order_identity_and_association_errors() {
        let morphology = compile_bounded_quadruped(descriptor()).unwrap().morphology;
        let request = endpoint_map_request(&morphology);

        let mut missing = request.clone();
        missing.ordered_actuator_kinematics.pop();
        assert!(map_endpoint_force_to_joint_v2(&morphology, &missing).is_err());

        let mut reordered = request.clone();
        reordered.ordered_actuator_kinematics.swap(0, 1);
        assert!(map_endpoint_force_to_joint_v2(&morphology, &reordered).is_err());

        let mut duplicate = request.clone();
        duplicate.ordered_actuator_kinematics[1].actuator_id =
            duplicate.ordered_actuator_kinematics[0].actuator_id.clone();
        assert!(map_endpoint_force_to_joint_v2(&morphology, &duplicate).is_err());

        let mut wrong_limb = request;
        wrong_limb.ordered_actuator_kinematics[0].contact_site_id = "rear_right_foot".to_owned();
        assert!(map_endpoint_force_to_joint_v2(&morphology, &wrong_limb).is_err());
    }

    #[test]
    fn endpoint_force_joint_map_rejects_infeasible_and_invalid_geometry() {
        let morphology = compile_bounded_quadruped(descriptor()).unwrap().morphology;
        let request = endpoint_map_request(&morphology);

        let mut infeasible = request.clone();
        infeasible.centroidal_command.feasible = false;
        infeasible
            .centroidal_command
            .infeasibility_reasons
            .push("FIXTURE_INFEASIBLE".to_owned());
        assert!(map_endpoint_force_to_joint_v2(&morphology, &infeasible).is_err());

        let mut nonunit = request.clone();
        nonunit.ordered_actuator_kinematics[0]
            .joint_axis_world_unit
            .z = 0.5;
        assert!(map_endpoint_force_to_joint_v2(&morphology, &nonunit).is_err());

        let mut nonfinite = request;
        nonfinite.ordered_actuator_kinematics[0].endpoint_world_m.x = f64::NAN;
        assert!(map_endpoint_force_to_joint_v2(&morphology, &nonfinite).is_err());
    }

    #[test]
    fn endpoint_force_joint_map_v3_full_support_matches_v2() {
        let morphology = compile_bounded_quadruped(descriptor()).unwrap().morphology;
        let v2_request = endpoint_map_request(&morphology);
        let v2 = map_endpoint_force_to_joint_v2(&morphology, &v2_request).unwrap();
        let v3_request = endpoint_map_request_v3(&morphology, None);
        let v3 = map_endpoint_force_to_joint_v3(&morphology, &v3_request).unwrap();

        assert_eq!(
            v3.schema_version,
            ENDPOINT_FORCE_JOINT_MAP_RECEIPT_V3_VERSION
        );
        assert_eq!(
            v3.active_actuator_count,
            morphology.ordered_actuator_ids.len()
        );
        assert_eq!(v3.inactive_actuator_count, 0);
        assert!(v3.endpoint_force_map_available);
        assert!(v3.partial_support_mapping_available);
        assert!(v3.inactive_contact_commands_forced_zero);
        assert_eq!(
            v3.ordered_generalized_joint_torque_commands.len(),
            v2.ordered_generalized_joint_torque_commands.len()
        );
        for (v3_command, v2_command) in v3
            .ordered_generalized_joint_torque_commands
            .iter()
            .zip(&v2.ordered_generalized_joint_torque_commands)
        {
            assert_eq!(
                v3_command.mapping_mode,
                EndpointForceJointMappingModeV3::SupportCommand
            );
            assert!(v3_command.active_support_contact);
            assert!(!v3_command.inactive_contact_forced_zero);
            assert_eq!(
                v3_command.linear_jacobian_column_world_m,
                v2_command.linear_jacobian_column_world_m
            );
            assert_eq!(
                v3_command.endpoint_task_force_command_world_n,
                v2_command.endpoint_task_force_command_world_n
            );
            assert_eq!(
                v3_command.generalized_torque_command_nm,
                v2_command.generalized_torque_command_nm
            );
        }
        assert!(!v3.measured_joint_torque_available);
        assert!(!v3.actuator_response_characterized);
        assert!(!v3.adapter_actuation_applied);
        assert!(!v3.physics_state_modified);
        assert!(!v3.physical_acceptance_authority);
    }

    #[test]
    fn endpoint_force_joint_map_v3_partial_support_maps_six_and_zeroes_two() {
        let morphology = compile_bounded_quadruped(descriptor()).unwrap().morphology;
        let request = endpoint_map_request_v3(&morphology, Some("front_right_foot"));
        let receipt = map_endpoint_force_to_joint_v3(&morphology, &request).unwrap();

        assert_eq!(receipt.active_actuator_count, 6);
        assert_eq!(receipt.inactive_actuator_count, 2);
        assert_eq!(
            receipt.ordered_generalized_joint_torque_commands.len(),
            morphology.ordered_actuator_ids.len()
        );
        let inactive = receipt
            .ordered_generalized_joint_torque_commands
            .iter()
            .filter(|command| !command.active_support_contact)
            .collect::<Vec<_>>();
        assert_eq!(inactive.len(), 2);
        for command in inactive {
            assert_eq!(command.contact_site_id, "front_right_foot");
            assert_eq!(
                command.mapping_mode,
                EndpointForceJointMappingModeV3::InactiveContactZero
            );
            assert_eq!(command.endpoint_task_force_command_world_n, Vec3::ZERO);
            assert_eq!(command.generalized_torque_command_nm, 0.0);
            assert!(command.inactive_contact_forced_zero);
            assert!(command.command_not_measurement);
        }
        assert!(
            receipt
                .ordered_generalized_joint_torque_commands
                .iter()
                .filter(|command| command.active_support_contact)
                .any(|command| command.generalized_torque_command_nm.abs() > 1.0e-12)
        );
    }

    #[test]
    fn endpoint_force_joint_map_v3_sign_and_translation_preserve_inactive_zero() {
        let morphology = compile_bounded_quadruped(descriptor()).unwrap().morphology;
        let request = endpoint_map_request_v3(&morphology, Some("front_right_foot"));
        let original = map_endpoint_force_to_joint_v3(&morphology, &request).unwrap();

        let mut reversed = request.clone();
        for command in &mut reversed.centroidal_command.ordered_support_contact_commands {
            command.joint_task_force_delta_world_n =
                scale(command.joint_task_force_delta_world_n, -1.0);
        }
        let mirrored = map_endpoint_force_to_joint_v3(&morphology, &reversed).unwrap();
        for (positive, negative) in original
            .ordered_generalized_joint_torque_commands
            .iter()
            .zip(&mirrored.ordered_generalized_joint_torque_commands)
        {
            assert!(
                (positive.generalized_torque_command_nm + negative.generalized_torque_command_nm)
                    .abs()
                    <= 1.0e-12
            );
            if !positive.active_support_contact {
                assert_eq!(positive.endpoint_task_force_command_world_n, Vec3::ZERO);
                assert_eq!(negative.endpoint_task_force_command_world_n, Vec3::ZERO);
            }
        }

        let mut translated = request;
        let offset = Vec3 {
            x: 7.0,
            y: -3.0,
            z: 11.0,
        };
        for kinematics in &mut translated.ordered_actuator_kinematics {
            kinematics.joint_anchor_world_m = add(kinematics.joint_anchor_world_m, offset);
            kinematics.endpoint_world_m = add(kinematics.endpoint_world_m, offset);
        }
        let translated_receipt = map_endpoint_force_to_joint_v3(&morphology, &translated).unwrap();
        assert_eq!(
            original.ordered_generalized_joint_torque_commands,
            translated_receipt.ordered_generalized_joint_torque_commands
        );
    }

    #[test]
    fn endpoint_force_joint_map_v3_rejects_order_identity_and_association_errors() {
        let morphology = compile_bounded_quadruped(descriptor()).unwrap().morphology;
        let request = endpoint_map_request_v3(&morphology, Some("front_right_foot"));

        let mut missing = request.clone();
        missing.ordered_actuator_kinematics.pop();
        assert!(map_endpoint_force_to_joint_v3(&morphology, &missing).is_err());

        let mut reordered = request.clone();
        reordered.ordered_actuator_kinematics.swap(0, 1);
        assert!(map_endpoint_force_to_joint_v3(&morphology, &reordered).is_err());

        let mut duplicate = request.clone();
        duplicate.ordered_actuator_kinematics[1].actuator_id =
            duplicate.ordered_actuator_kinematics[0].actuator_id.clone();
        assert!(map_endpoint_force_to_joint_v3(&morphology, &duplicate).is_err());

        let mut wrong_limb = request;
        wrong_limb.ordered_actuator_kinematics[0].contact_site_id = "rear_right_foot".to_owned();
        assert!(map_endpoint_force_to_joint_v3(&morphology, &wrong_limb).is_err());
    }

    #[test]
    fn endpoint_force_joint_map_v3_rejects_versions_contacts_and_invalid_geometry() {
        let morphology = compile_bounded_quadruped(descriptor()).unwrap().morphology;
        let request = endpoint_map_request_v3(&morphology, Some("front_right_foot"));

        let mut wrong_version = request.clone();
        wrong_version.schema_version = ENDPOINT_FORCE_JOINT_MAP_REQUEST_VERSION.to_owned();
        assert!(map_endpoint_force_to_joint_v3(&morphology, &wrong_version).is_err());

        let mut infeasible = request.clone();
        infeasible.centroidal_command.feasible = false;
        infeasible
            .centroidal_command
            .infeasibility_reasons
            .push("FIXTURE_INFEASIBLE".to_owned());
        assert!(map_endpoint_force_to_joint_v3(&morphology, &infeasible).is_err());

        let mut unknown_contact = request.clone();
        unknown_contact
            .centroidal_command
            .ordered_support_contact_commands[0]
            .contact_id = "unknown_contact".to_owned();
        assert!(map_endpoint_force_to_joint_v3(&morphology, &unknown_contact).is_err());

        let mut duplicate_contact = request.clone();
        duplicate_contact
            .centroidal_command
            .ordered_support_contact_commands
            .push(
                duplicate_contact
                    .centroidal_command
                    .ordered_support_contact_commands[0]
                    .clone(),
            );
        assert!(map_endpoint_force_to_joint_v3(&morphology, &duplicate_contact).is_err());

        let mut nonunit = request.clone();
        nonunit.ordered_actuator_kinematics[0]
            .joint_axis_world_unit
            .z = 0.5;
        assert!(map_endpoint_force_to_joint_v3(&morphology, &nonunit).is_err());

        let mut nonfinite = request;
        nonfinite.ordered_actuator_kinematics[0].endpoint_world_m.x = f64::NAN;
        assert!(map_endpoint_force_to_joint_v3(&morphology, &nonfinite).is_err());
    }

    fn influence_request(
        morphology: &CompiledMorphology,
        availability: StabilityInfluenceAvailability,
    ) -> StabilityInfluenceRequestV2 {
        let available = availability == StabilityInfluenceAvailability::Available;
        StabilityInfluenceRequestV2 {
            schema_version: STABILITY_INFLUENCE_REQUEST_VERSION.to_owned(),
            semantic_step: 2,
            availability,
            maximum_absolute_position_delta_rad: 0.10,
            maximum_absolute_velocity_delta_rad_s: 0.20,
            maximum_position_delta_slew_per_step_rad: 0.02,
            maximum_velocity_delta_slew_per_step_rad_s: 0.04,
            ordered_requested_corrections: morphology
                .ordered_actuator_ids
                .iter()
                .map(|actuator_id| RequestedStabilityCorrectionV2 {
                    actuator_id: actuator_id.clone(),
                    requested_position_delta_rad: available.then_some(0.50),
                    requested_velocity_delta_rad_s: available.then_some(-0.50),
                })
                .collect(),
            previous_semantic_step: Some(1),
            ordered_previous_applied_corrections: Some(
                morphology
                    .ordered_actuator_ids
                    .iter()
                    .map(|actuator_id| PreviousStabilityCorrectionV2 {
                        actuator_id: actuator_id.clone(),
                        applied_position_delta_rad: 0.01,
                        applied_velocity_delta_rad_s: -0.01,
                    })
                    .collect(),
            ),
        }
    }

    #[test]
    fn stability_influence_is_magnitude_and_slew_bounded_in_semantic_order() {
        let morphology = compile_bounded_quadruped(descriptor()).unwrap().morphology;
        let receipt = bound_stability_influence_v2(
            &morphology,
            &influence_request(&morphology, StabilityInfluenceAvailability::Available),
        )
        .unwrap();
        assert!(receipt.any_magnitude_saturation);
        assert!(receipt.any_slew_limiting);
        assert!(!receipt.fallback_applied);
        for (expected, correction) in morphology
            .ordered_actuator_ids
            .iter()
            .zip(&receipt.ordered_applied_corrections)
        {
            assert_eq!(expected, &correction.actuator_id);
            assert!((correction.applied_position_delta_rad - 0.03).abs() <= 1.0e-12);
            assert!((correction.applied_velocity_delta_rad_s + 0.05).abs() <= 1.0e-12);
            assert!(correction.magnitude_saturated);
            assert!(correction.slew_limited);
            assert!(!correction.fallback_zeroed);
        }
        assert!(receipt.corrections_are_bounded_contributions_not_complete_actuation);
        assert!(!receipt.adapter_actuation_applied);
        assert!(!receipt.physical_acceptance_authority);
    }

    #[test]
    fn unavailable_or_infeasible_stability_falls_back_immediately_to_zero() {
        let morphology = compile_bounded_quadruped(descriptor()).unwrap().morphology;
        for availability in [
            StabilityInfluenceAvailability::ObservationUnavailable,
            StabilityInfluenceAvailability::UpstreamInfeasible,
        ] {
            let receipt = bound_stability_influence_v2(
                &morphology,
                &influence_request(&morphology, availability),
            )
            .unwrap();
            assert!(receipt.fallback_applied);
            assert!(receipt.fallback_bypasses_slew_to_reach_zero);
            assert!(
                receipt
                    .ordered_applied_corrections
                    .iter()
                    .all(|correction| {
                        correction.applied_position_delta_rad == 0.0
                            && correction.applied_velocity_delta_rad_s == 0.0
                            && correction.fallback_zeroed
                    })
            );
        }
    }

    #[test]
    fn malformed_stability_influence_requests_fail_closed() {
        let morphology = compile_bounded_quadruped(descriptor()).unwrap().morphology;
        let mut missing = influence_request(
            &morphology,
            StabilityInfluenceAvailability::ObservationUnavailable,
        );
        missing.ordered_requested_corrections[0].requested_position_delta_rad = Some(0.0);
        assert!(bound_stability_influence_v2(&morphology, &missing).is_err());
        let mut reordered =
            influence_request(&morphology, StabilityInfluenceAvailability::Available);
        reordered.ordered_requested_corrections.swap(0, 1);
        assert!(bound_stability_influence_v2(&morphology, &reordered).is_err());
        let mut future = influence_request(&morphology, StabilityInfluenceAvailability::Available);
        future.previous_semantic_step = Some(future.semantic_step);
        assert!(bound_stability_influence_v2(&morphology, &future).is_err());
    }

    fn influence_request_v3(
        morphology: &CompiledMorphology,
        availability: StabilityInfluenceAvailability,
        scale: f64,
    ) -> StabilityInfluenceRequestV3 {
        let v2 = influence_request(morphology, availability);
        StabilityInfluenceRequestV3 {
            schema_version: STABILITY_INFLUENCE_REQUEST_V3_VERSION.to_owned(),
            semantic_step: v2.semantic_step,
            availability: v2.availability,
            global_requested_correction_scale: scale,
            maximum_absolute_position_delta_rad: v2.maximum_absolute_position_delta_rad,
            maximum_absolute_velocity_delta_rad_s: v2.maximum_absolute_velocity_delta_rad_s,
            maximum_position_delta_slew_per_step_rad: v2.maximum_position_delta_slew_per_step_rad,
            maximum_velocity_delta_slew_per_step_rad_s: v2
                .maximum_velocity_delta_slew_per_step_rad_s,
            ordered_requested_corrections: v2.ordered_requested_corrections,
            previous_semantic_step: v2.previous_semantic_step,
            ordered_previous_applied_corrections: v2.ordered_previous_applied_corrections,
        }
    }

    #[test]
    fn stability_influence_v3_scales_globally_before_existing_bounds() {
        let morphology = compile_bounded_quadruped(descriptor()).unwrap().morphology;
        let receipt = bound_stability_influence_v3(
            &morphology,
            &influence_request_v3(&morphology, StabilityInfluenceAvailability::Available, 0.25),
        )
        .unwrap();
        assert_eq!(
            receipt.schema_version,
            STABILITY_INFLUENCE_RECEIPT_V3_VERSION
        );
        assert_eq!(receipt.global_requested_correction_scale, 0.25);
        assert!(receipt.global_scale_applied_before_magnitude_and_slew);
        assert!(receipt.any_nonzero_raw_request);
        assert!(receipt.any_nonzero_scaled_request);
        assert!(receipt.any_magnitude_saturation);
        assert!(receipt.any_slew_limiting);
        for correction in receipt.ordered_applied_corrections {
            assert_eq!(correction.raw_requested_position_delta_rad, Some(0.50));
            assert_eq!(correction.raw_requested_velocity_delta_rad_s, Some(-0.50));
            assert_eq!(correction.scaled_requested_position_delta_rad, Some(0.125));
            assert_eq!(
                correction.scaled_requested_velocity_delta_rad_s,
                Some(-0.125)
            );
            assert!((correction.applied_position_delta_rad - 0.03).abs() <= 1.0e-12);
            assert!((correction.applied_velocity_delta_rad_s + 0.05).abs() <= 1.0e-12);
        }
        assert!(!receipt.adapter_actuation_applied);
        assert!(!receipt.physics_state_modified);
        assert!(!receipt.physical_acceptance_authority);
    }

    #[test]
    fn stability_influence_v3_zero_scale_is_exact_control_and_fallback_is_exact_zero() {
        let morphology = compile_bounded_quadruped(descriptor()).unwrap().morphology;
        let control = bound_stability_influence_v3(
            &morphology,
            &influence_request_v3(&morphology, StabilityInfluenceAvailability::Available, 0.0),
        )
        .unwrap();
        assert!(control.any_nonzero_raw_request);
        assert!(!control.any_nonzero_scaled_request);
        assert!(
            control
                .ordered_applied_corrections
                .iter()
                .all(|correction| {
                    correction.scaled_requested_position_delta_rad == Some(0.0)
                        && correction.scaled_requested_velocity_delta_rad_s == Some(-0.0)
                        && correction.applied_position_delta_rad == 0.0
                        && correction.applied_velocity_delta_rad_s == 0.0
                        && !correction.fallback_zeroed
                })
        );

        let unavailable = bound_stability_influence_v3(
            &morphology,
            &influence_request_v3(
                &morphology,
                StabilityInfluenceAvailability::ObservationUnavailable,
                0.5,
            ),
        )
        .unwrap();
        assert!(unavailable.fallback_applied);
        assert!(unavailable.fallback_bypasses_slew_to_reach_zero);
        assert!(!unavailable.any_nonzero_raw_request);
        assert!(!unavailable.any_nonzero_scaled_request);
        assert!(
            unavailable
                .ordered_applied_corrections
                .iter()
                .all(|correction| {
                    correction.raw_requested_position_delta_rad.is_none()
                        && correction.raw_requested_velocity_delta_rad_s.is_none()
                        && correction.scaled_requested_position_delta_rad.is_none()
                        && correction.scaled_requested_velocity_delta_rad_s.is_none()
                        && correction.applied_position_delta_rad == 0.0
                        && correction.applied_velocity_delta_rad_s == 0.0
                        && correction.fallback_zeroed
                })
        );
    }

    #[test]
    fn malformed_stability_influence_v3_scale_fails_closed() {
        let morphology = compile_bounded_quadruped(descriptor()).unwrap().morphology;
        for invalid in [-0.01, 1.01, f64::NAN, f64::INFINITY] {
            assert!(
                bound_stability_influence_v3(
                    &morphology,
                    &influence_request_v3(
                        &morphology,
                        StabilityInfluenceAvailability::Available,
                        invalid,
                    ),
                )
                .is_err()
            );
        }
        let mut wrong_version =
            influence_request_v3(&morphology, StabilityInfluenceAvailability::Available, 0.5);
        wrong_version.schema_version = STABILITY_INFLUENCE_REQUEST_VERSION.to_owned();
        assert!(bound_stability_influence_v3(&morphology, &wrong_version).is_err());
    }

    #[test]
    fn checked_in_gdscript_stability_golden_matches_rust_v2() {
        let golden: serde_json::Value = serde_json::from_str(include_str!(
            "../../conformance/golden/stability_v2_gdscript_oracle_v1.json"
        ))
        .unwrap();
        assert_eq!(
            golden["schema_version"],
            "sporespore_stability_v2_gdscript_oracle_v1"
        );
        let tolerance = golden["comparison_tolerances"]["rust_binary64_absolute"]
            .as_f64()
            .unwrap();
        let observer_fixture = &golden["observer_fixture"];
        let expected = &observer_fixture["expected"];
        let morphology = compile_bounded_quadruped(descriptor()).unwrap().morphology;
        let support_points = observer_fixture["support_points_world_m"]
            .as_array()
            .unwrap();
        let contacts = support_points
            .iter()
            .enumerate()
            .map(|(index, point)| {
                let raw = point.as_array().unwrap();
                contact(
                    &format!("golden_{index}"),
                    Vec3 {
                        x: raw[0].as_f64().unwrap(),
                        y: raw[1].as_f64().unwrap(),
                        z: raw[2].as_f64().unwrap(),
                    },
                )
            })
            .collect();
        let observed =
            observe_stability_v2(&morphology, &stability_state(&morphology, contacts)).unwrap();
        let expected_com = expected["center_of_mass_world_m"].as_array().unwrap();
        let expected_velocity = expected["center_of_mass_velocity_world_m_s"]
            .as_array()
            .unwrap();
        let expected_capture = expected["linearized_capture_point_world_m"]
            .as_array()
            .unwrap();
        let expected_centroid = expected["support_centroid_world_m"].as_array().unwrap();
        for (actual, expected) in [
            (
                observed.center_of_mass_world_m,
                Vec3 {
                    x: expected_com[0].as_f64().unwrap(),
                    y: expected_com[1].as_f64().unwrap(),
                    z: expected_com[2].as_f64().unwrap(),
                },
            ),
            (
                observed.center_of_mass_velocity_world_m_s,
                Vec3 {
                    x: expected_velocity[0].as_f64().unwrap(),
                    y: expected_velocity[1].as_f64().unwrap(),
                    z: expected_velocity[2].as_f64().unwrap(),
                },
            ),
            (
                observed.linearized_capture_point_world_m,
                Vec3 {
                    x: expected_capture[0].as_f64().unwrap(),
                    y: expected_capture[1].as_f64().unwrap(),
                    z: expected_capture[2].as_f64().unwrap(),
                },
            ),
            (
                observed.support_centroid_world_m,
                Vec3 {
                    x: expected_centroid[0].as_f64().unwrap(),
                    y: expected_centroid[1].as_f64().unwrap(),
                    z: expected_centroid[2].as_f64().unwrap(),
                },
            ),
        ] {
            assert!(norm(subtract(actual, expected)) <= tolerance);
        }
        assert!(
            (observed.linearized_natural_frequency_rad_s
                - expected["linearized_natural_frequency_rad_s"]
                    .as_f64()
                    .unwrap())
            .abs()
                <= tolerance
        );
        assert!(
            (observed.center_of_mass_margin_m
                - expected["minimum_signed_static_margin_m"].as_f64().unwrap())
            .abs()
                <= tolerance
        );
        assert!(
            (observed.linearized_capture_margin_m
                - expected["linearized_capture_margin_m"].as_f64().unwrap())
            .abs()
                <= tolerance
        );

        let command = command_centroidal_support_v2(&centroidal_request()).unwrap();
        let expected_command = &golden["centroidal_fixture"]["expected"];
        let normal_sum: f64 = command
            .ordered_support_contact_commands
            .iter()
            .map(|contact| contact.normal_force_command_n)
            .sum();
        let task_vertical_sum: f64 = command
            .ordered_support_contact_commands
            .iter()
            .map(|contact| contact.joint_task_force_delta_world_n.y)
            .sum();
        assert_eq!(
            command.feasible,
            expected_command["feasible"].as_bool().unwrap()
        );
        assert!(
            (command.desired_external_force_world_n.y
                - expected_command["desired_vertical_force_n"]
                    .as_f64()
                    .unwrap())
            .abs()
                <= 1.0e-9
        );
        assert!(
            (normal_sum - expected_command["normal_force_sum_n"].as_f64().unwrap()).abs() <= 1.0e-9
        );
        assert!(
            (task_vertical_sum
                - expected_command["joint_task_vertical_delta_sum_n"]
                    .as_f64()
                    .unwrap())
            .abs()
                <= 1.0e-9
        );

        let joint_map_fixture = &golden["joint_map_fixture"];
        let raw_axis = joint_map_fixture["joint_axis_world_unit"]
            .as_array()
            .unwrap();
        let raw_anchor = joint_map_fixture["joint_anchor_world_m"]
            .as_array()
            .unwrap();
        let raw_endpoint = joint_map_fixture["endpoint_world_m"].as_array().unwrap();
        let raw_force = joint_map_fixture["endpoint_task_force_command_world_n"]
            .as_array()
            .unwrap();
        let mut map_request = endpoint_map_request(&morphology);
        let first_contact_id = map_request.ordered_actuator_kinematics[0]
            .contact_site_id
            .clone();
        map_request.ordered_actuator_kinematics[0].joint_axis_world_unit = Vec3 {
            x: raw_axis[0].as_f64().unwrap(),
            y: raw_axis[1].as_f64().unwrap(),
            z: raw_axis[2].as_f64().unwrap(),
        };
        map_request.ordered_actuator_kinematics[0].joint_anchor_world_m = Vec3 {
            x: raw_anchor[0].as_f64().unwrap(),
            y: raw_anchor[1].as_f64().unwrap(),
            z: raw_anchor[2].as_f64().unwrap(),
        };
        map_request.ordered_actuator_kinematics[0].endpoint_world_m = Vec3 {
            x: raw_endpoint[0].as_f64().unwrap(),
            y: raw_endpoint[1].as_f64().unwrap(),
            z: raw_endpoint[2].as_f64().unwrap(),
        };
        map_request
            .centroidal_command
            .ordered_support_contact_commands
            .iter_mut()
            .find(|contact| contact.contact_id == first_contact_id)
            .unwrap()
            .joint_task_force_delta_world_n = Vec3 {
            x: raw_force[0].as_f64().unwrap(),
            y: raw_force[1].as_f64().unwrap(),
            z: raw_force[2].as_f64().unwrap(),
        };
        let mapped = map_endpoint_force_to_joint_v2(&morphology, &map_request).unwrap();
        let expected_map = &joint_map_fixture["expected"];
        let expected_jacobian = expected_map["linear_jacobian_column_world_m"]
            .as_array()
            .unwrap();
        let first_mapping = &mapped.ordered_generalized_joint_torque_commands[0];
        assert!(
            norm(subtract(
                first_mapping.linear_jacobian_column_world_m,
                Vec3 {
                    x: expected_jacobian[0].as_f64().unwrap(),
                    y: expected_jacobian[1].as_f64().unwrap(),
                    z: expected_jacobian[2].as_f64().unwrap(),
                },
            )) <= tolerance
        );
        assert!(
            (first_mapping.generalized_torque_command_nm
                - expected_map["generalized_torque_command_nm"]
                    .as_f64()
                    .unwrap())
            .abs()
                <= tolerance
        );
    }
}
