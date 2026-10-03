//! Rapier/Parry host adapter for the SporeSpore locomotion SDK.
//!
//! The adapter owns Rapier world construction, state/contact observation,
//! actuator mapping, and host receipts. Controller policy remains in
//! `sporespore-locomotion-core`.

#![recursion_limit = "256"]

use serde_json::{Value, json};
use sporespore_locomotion_core::{LOCOMOTION_SEMANTICS_VERSION, digest_json};

mod active_configuration;
mod actuator_cap_profile;
mod bw19v_commissioning;
mod bw19v_composition;
mod bw19v_early_horizon_development;
mod bw19v_velocity_only_contact_restoration_tr1;
mod bw19v_velocity_only_early_horizon_eh1;
mod bw19v_velocity_only_long_horizon_lc1;
mod bw19v_velocity_only_pose_hold_restoration_ph1;
mod bw19v_velocity_only_terminal_stance_ts1;
mod characterization;
mod conformance;
mod cross_engine_discrete_material_validation_xv1_rapier;
mod cross_engine_discrete_material_validation_xv2_rapier;
mod force_based_characterization;
mod force_based_convergence_window;
mod force_based_load_response;
mod force_based_selected_configuration_validation;
mod force_based_solver_phase_development;
mod force_based_velocity_only_characterization;
mod live_explorer;
mod locomotion;
mod qsdk_r23d10_quiescent_taper;
mod qsdk_r23d11_stability_assisted_taper;
mod qsdk_r23d12_measurement_semantics;
mod qsdk_r23d13_residual_pose_authority;
mod qsdk_r23d14_tight_gated_horizon;
mod qsdk_r23d15_composition_recovery;
mod qsdk_r23d16_composition_recovery;
mod qsdk_r23d17_composition_recovery;
mod qsdk_r23d18_composition_recovery;
mod qsdk_r23d1_heading_response;
mod qsdk_r23d22_composition_recovery;
mod qsdk_r23d23_composition_recovery;
mod qsdk_r23d2_heading_response;
mod qsdk_r23d3_phase_balanced;
mod qsdk_r23d62_public_profile_route;
mod qsdk_r23d62_rapier_worker;
mod qsdk_r23d63_public_profile_route;
mod qsdk_r23d63_rapier_worker;
mod qsdk_r23d64_public_profile_route;
mod qsdk_r23d64_rapier_worker;
mod qsdk_r23d65_public_profile_route;
mod qsdk_r23d65_rapier_worker;
mod qsdk_r23d66_turning_route;
mod qsdk_r23d67_turning_route;
mod qsdk_r23d68_turning_route;
mod qsdk_r23d69_turning_route;
mod qsdk_r23d70_receipt_contract;
mod qsdk_r23d70_turning_route;
mod qsdk_r23d71_receipt_contract;
mod qsdk_r23d71_turning_route;
mod qsdk_r23d74_receipt_contract;
mod qsdk_r23d74_turning_route;
mod qsdk_r23d76_receipt_contract;
mod qsdk_r23d76_turning_route;
mod qsdk_r23d78_receipt_contract;
mod qsdk_r23d78_turning_route;
mod qsdk_r23d9_support_handoff;
mod qsdk_r24d45_recovery_route;
#[cfg(feature = "sporespore-rapier-motor-work")]
mod qsdk_r24d46_motor_work_observer;
#[cfg(feature = "sporespore-rapier-energy-exchange")]
mod qsdk_r24d47_energy_exchange_observer;
#[cfg(feature = "sporespore-rapier-energy-exchange")]
mod qsdk_r24d48_recovery_energy_v2_route;
#[cfg(feature = "sporespore-rapier-energy-exchange")]
mod qsdk_r24d49_runtime_binding_route;
#[cfg(feature = "sporespore-rapier-energy-exchange")]
mod qsdk_r24d51_discrete_staging_observer;
#[cfg(feature = "sporespore-rapier-discrete-staging")]
mod qsdk_r24d52_discrete_staging_ledger;
#[cfg(feature = "sporespore-rapier-r24d53-staging-transport")]
mod qsdk_r24d53_staging_transport_smoke;
#[cfg(feature = "sporespore-rapier-r24d54-v3-recovery-behavior")]
mod qsdk_r24d54_recovery_energy_v3_behavior;
mod recovery_capability;
mod recovery_runtime;
mod turning_three_engine_route;
mod velocity_only_live_integration;

pub use active_configuration::{
    RAPIER_ACTIVE_INTERNAL_PGS_ITERATIONS, RAPIER_ACTIVE_INTERNAL_STABILIZATION_ITERATIONS,
    RAPIER_ACTIVE_SOLVER_ITERATIONS,
};
pub use actuator_cap_profile::run_actuator_cap_profile_preflight;
pub use bw19v_commissioning::{
    run_bw19v_selected_policy_commissioning, run_bw19v_selected_policy_commissioning_c2,
    run_bw19v_selected_policy_commissioning_c2_preflight,
    run_bw19v_selected_policy_commissioning_preflight,
};
pub use bw19v_early_horizon_development::{
    run_bw19v_early_horizon_development, run_bw19v_early_horizon_development_preflight,
};
pub use bw19v_velocity_only_contact_restoration_tr1::{
    evaluate_bw19v_velocity_only_contact_restoration_tr1_report,
    run_bw19v_velocity_only_contact_restoration_tr1,
    run_bw19v_velocity_only_contact_restoration_tr1_preflight,
};
pub use bw19v_velocity_only_early_horizon_eh1::{
    evaluate_retained_bw19v_velocity_only_early_horizon_eh1_report,
    run_bw19v_velocity_only_early_horizon_eh1, run_bw19v_velocity_only_early_horizon_eh1_preflight,
};
pub use bw19v_velocity_only_long_horizon_lc1::{
    evaluate_bw19v_velocity_only_long_horizon_lc1_report, run_bw19v_velocity_only_long_horizon_lc1,
    run_bw19v_velocity_only_long_horizon_lc1_preflight,
};
pub use bw19v_velocity_only_pose_hold_restoration_ph1::{
    evaluate_bw19v_velocity_only_pose_hold_restoration_ph1_report,
    run_bw19v_velocity_only_pose_hold_restoration_ph1,
    run_bw19v_velocity_only_pose_hold_restoration_ph1_preflight,
};
pub use bw19v_velocity_only_terminal_stance_ts1::{
    evaluate_bw19v_velocity_only_terminal_stance_ts1_report,
    run_bw19v_velocity_only_terminal_stance_ts1,
    run_bw19v_velocity_only_terminal_stance_ts1_preflight,
};
pub use characterization::{run_host_characterization, run_host_characterization_preflight};
pub use conformance::run_c2_c5_conformance;
pub use cross_engine_discrete_material_validation_xv1_rapier::{
    evaluate_cross_engine_discrete_material_validation_xv1_rapier_report,
    run_cross_engine_discrete_material_validation_xv1_rapier,
    run_cross_engine_discrete_material_validation_xv1_rapier_preflight,
};
pub use cross_engine_discrete_material_validation_xv2_rapier::{
    evaluate_cross_engine_discrete_material_validation_xv2_rapier_report,
    run_cross_engine_discrete_material_validation_xv2_rapier,
    run_cross_engine_discrete_material_validation_xv2_rapier_preflight,
};
pub use force_based_characterization::{
    run_force_based_host_characterization, run_force_based_host_characterization_preflight,
};
pub use force_based_convergence_window::{
    run_force_based_convergence_window, run_force_based_convergence_window_preflight,
};
pub use force_based_load_response::{
    run_force_based_load_response, run_force_based_load_response_preflight,
};
pub use force_based_selected_configuration_validation::{
    run_force_based_selected_configuration_validation,
    run_force_based_selected_configuration_validation_preflight,
};
pub use force_based_solver_phase_development::{
    run_force_based_solver_phase_development, run_force_based_solver_phase_development_preflight,
};
pub use force_based_velocity_only_characterization::{
    run_force_based_velocity_only_characterization,
    run_force_based_velocity_only_characterization_preflight,
};
pub use live_explorer::{
    LIVE_EXPLORER_PROTOCOL_VERSION, configure_live_explorer, finish_live_explorer,
};
pub use locomotion::{
    run_selected_policy_commissioning, run_selected_policy_commissioning_preflight,
    run_selected_policy_commissioning_r1, run_selected_policy_commissioning_r1_preflight,
    run_selected_policy_commissioning_r2, run_selected_policy_commissioning_r2_preflight,
};
pub use qsdk_r23d1_heading_response::{
    run_qsdk_r23d1_rapier_physical, run_qsdk_r23d1_rapier_preflight,
};
pub use qsdk_r23d2_heading_response::{
    run_qsdk_r23d2_rapier_physical, run_qsdk_r23d2_rapier_preflight,
};
pub use qsdk_r23d3_phase_balanced::r23d13_physical::{
    run_qsdk_r23d13_rapier_authorization_preflight_impl as run_qsdk_r23d13_rapier_authorization_preflight,
    run_qsdk_r23d13_rapier_physical_impl as run_qsdk_r23d13_rapier_physical,
    run_qsdk_r23d13_rapier_preflight_impl as run_qsdk_r23d13_rapier_preflight,
};
pub use qsdk_r23d3_phase_balanced::r23d14_physical::{
    run_qsdk_r23d14_rapier_authorization_preflight_impl as run_qsdk_r23d14_rapier_authorization_preflight,
    run_qsdk_r23d14_rapier_physical_impl as run_qsdk_r23d14_rapier_physical,
    run_qsdk_r23d14_rapier_preflight_impl as run_qsdk_r23d14_rapier_preflight,
};
pub use qsdk_r23d3_phase_balanced::r23d15_physical::{
    run_qsdk_r23d15_rapier_authorization_preflight_impl as run_qsdk_r23d15_rapier_authorization_preflight,
    run_qsdk_r23d15_rapier_physical_impl as run_qsdk_r23d15_rapier_physical,
    run_qsdk_r23d15_rapier_preflight_impl as run_qsdk_r23d15_rapier_preflight,
};
pub use qsdk_r23d3_phase_balanced::r23d16_physical::{
    run_qsdk_r23d16_rapier_authorization_preflight_impl as run_qsdk_r23d16_rapier_authorization_preflight,
    run_qsdk_r23d16_rapier_physical_impl as run_qsdk_r23d16_rapier_physical,
    run_qsdk_r23d16_rapier_preflight_impl as run_qsdk_r23d16_rapier_preflight,
};
pub use qsdk_r23d3_phase_balanced::r23d17_physical::{
    run_qsdk_r23d17_rapier_authorization_preflight_impl as run_qsdk_r23d17_rapier_authorization_preflight,
    run_qsdk_r23d17_rapier_physical_impl as run_qsdk_r23d17_rapier_physical,
    run_qsdk_r23d17_rapier_preflight_impl as run_qsdk_r23d17_rapier_preflight,
};
pub use qsdk_r23d3_phase_balanced::r23d18_physical::{
    run_qsdk_r23d18_rapier_authorization_preflight_impl as run_qsdk_r23d18_rapier_authorization_preflight,
    run_qsdk_r23d18_rapier_physical_impl as run_qsdk_r23d18_rapier_physical,
    run_qsdk_r23d18_rapier_preflight_impl as run_qsdk_r23d18_rapier_preflight,
};
pub use qsdk_r23d3_phase_balanced::r23d22_physical::{
    run_qsdk_r23d22_rapier_authorization_preflight_impl as run_qsdk_r23d22_rapier_authorization_preflight,
    run_qsdk_r23d22_rapier_physical_impl as run_qsdk_r23d22_rapier_physical,
    run_qsdk_r23d22_rapier_preflight_impl as run_qsdk_r23d22_rapier_preflight,
};
pub use qsdk_r23d3_phase_balanced::r23d23_physical::{
    run_qsdk_r23d23_rapier_authorization_preflight_impl as run_qsdk_r23d23_rapier_authorization_preflight,
    run_qsdk_r23d23_rapier_physical_impl as run_qsdk_r23d23_rapier_physical,
    run_qsdk_r23d23_rapier_preflight_impl as run_qsdk_r23d23_rapier_preflight,
};
pub use qsdk_r23d3_phase_balanced::r23d26_physical::{
    run_qsdk_r23d26_rapier_authorization_preflight_impl as run_qsdk_r23d26_rapier_authorization_preflight,
    run_qsdk_r23d26_rapier_physical_impl as run_qsdk_r23d26_rapier_physical,
    run_qsdk_r23d26_rapier_preflight_impl as run_qsdk_r23d26_rapier_preflight,
};
pub use qsdk_r23d3_phase_balanced::r23d27_physical::{
    R23D66_CAMPAIGN_ID, R23D66_CAMPAIGN_SEED, R23D66_GATE_ID, R23D66_STAGE_ID,
};
pub use qsdk_r23d3_phase_balanced::r23d27_physical::{
    R23D67_CAMPAIGN_ID, R23D67_CAMPAIGN_SEED, R23D67_GATE_ID, R23D67_STAGE_ID,
};
pub use qsdk_r23d3_phase_balanced::r23d27_physical::{
    R23D68_CAMPAIGN_ID, R23D68_CAMPAIGN_SEED, R23D68_GATE_ID, R23D68_STAGE_ID,
};
pub use qsdk_r23d3_phase_balanced::r23d27_physical::{
    R23D69_CAMPAIGN_ID, R23D69_CAMPAIGN_SEED, R23D69_GATE_ID, R23D69_STAGE_ID,
};
pub use qsdk_r23d3_phase_balanced::r23d27_physical::{
    R23D70_CAMPAIGN_ID, R23D70_CAMPAIGN_SEED, R23D70_GATE_ID, R23D70_STAGE_ID,
};
pub use qsdk_r23d3_phase_balanced::r23d27_physical::{
    R23D71_CAMPAIGN_ID, R23D71_CAMPAIGN_SEED, R23D71_GATE_ID, R23D71_STAGE_ID,
};
pub use qsdk_r23d3_phase_balanced::r23d27_physical::{
    R23D74_CAMPAIGN_ID, R23D74_CAMPAIGN_SEED, R23D74_GATE_ID, R23D74_STAGE_ID,
};
pub use qsdk_r23d3_phase_balanced::r23d27_physical::{
    R23D76_CAMPAIGN_ID, R23D76_CAMPAIGN_SEED, R23D76_GATE_ID, R23D76_STAGE_ID,
};
pub use qsdk_r23d3_phase_balanced::r23d27_physical::{
    R23D78_CAMPAIGN_ID, R23D78_CAMPAIGN_SEED, R23D78_GATE_ID, R23D78_STAGE_ID,
};
pub use qsdk_r23d3_phase_balanced::r23d27_physical::{
    run_qsdk_r23d27_rapier_authorization_preflight_impl as run_qsdk_r23d27_rapier_authorization_preflight,
    run_qsdk_r23d27_rapier_physical_impl as run_qsdk_r23d27_rapier_physical,
    run_qsdk_r23d27_rapier_preflight_impl as run_qsdk_r23d27_rapier_preflight,
};
pub use qsdk_r23d3_phase_balanced::r23d27_physical::{
    run_qsdk_r23d27_rapier_authorization_preflight_impl as run_qsdk_r23d28_rapier_authorization_preflight,
    run_qsdk_r23d27_rapier_physical_impl as run_qsdk_r23d28_rapier_physical,
    run_qsdk_r23d27_rapier_preflight_impl as run_qsdk_r23d28_rapier_preflight,
};
pub use qsdk_r23d3_phase_balanced::r23d27_physical::{
    run_qsdk_r23d27_rapier_authorization_preflight_impl as run_qsdk_r23d29_rapier_authorization_preflight,
    run_qsdk_r23d27_rapier_physical_impl as run_qsdk_r23d29_rapier_physical,
    run_qsdk_r23d27_rapier_preflight_impl as run_qsdk_r23d29_rapier_preflight,
};
pub use qsdk_r23d3_phase_balanced::r23d27_physical::{
    run_qsdk_r23d27_rapier_authorization_preflight_impl as run_qsdk_r23d30_rapier_authorization_preflight,
    run_qsdk_r23d27_rapier_physical_impl as run_qsdk_r23d30_rapier_physical,
    run_qsdk_r23d27_rapier_preflight_impl as run_qsdk_r23d30_rapier_preflight,
};
pub use qsdk_r23d3_phase_balanced::r23d27_physical::{
    run_qsdk_r23d27_rapier_authorization_preflight_impl as run_qsdk_r23d31_rapier_authorization_preflight,
    run_qsdk_r23d27_rapier_physical_impl as run_qsdk_r23d31_rapier_physical,
    run_qsdk_r23d27_rapier_preflight_impl as run_qsdk_r23d31_rapier_preflight,
};
pub use qsdk_r23d3_phase_balanced::r23d27_physical::{
    run_qsdk_r23d27_rapier_authorization_preflight_impl as run_qsdk_r23d32_rapier_authorization_preflight,
    run_qsdk_r23d27_rapier_physical_impl as run_qsdk_r23d32_rapier_physical,
    run_qsdk_r23d27_rapier_preflight_impl as run_qsdk_r23d32_rapier_preflight,
};
pub use qsdk_r23d3_phase_balanced::r23d27_physical::{
    run_qsdk_r23d27_rapier_authorization_preflight_impl as run_qsdk_r23d40_rapier_authorization_preflight,
    run_qsdk_r23d27_rapier_physical_impl as run_qsdk_r23d40_rapier_physical,
    run_qsdk_r23d27_rapier_preflight_impl as run_qsdk_r23d40_rapier_preflight,
};
pub use qsdk_r23d3_phase_balanced::r23d27_physical::{
    run_qsdk_r23d27_rapier_authorization_preflight_impl as run_qsdk_r23d41_rapier_authorization_preflight,
    run_qsdk_r23d27_rapier_physical_impl as run_qsdk_r23d41_rapier_physical,
    run_qsdk_r23d27_rapier_preflight_impl as run_qsdk_r23d41_rapier_preflight,
};
pub use qsdk_r23d3_phase_balanced::r23d27_physical::{
    run_qsdk_r23d27_rapier_authorization_preflight_impl as run_qsdk_r23d42_rapier_authorization_preflight,
    run_qsdk_r23d27_rapier_physical_impl as run_qsdk_r23d42_rapier_physical,
    run_qsdk_r23d27_rapier_preflight_impl as run_qsdk_r23d42_rapier_preflight,
};
pub use qsdk_r23d3_phase_balanced::r23d27_physical::{
    run_qsdk_r23d27_rapier_authorization_preflight_impl as run_qsdk_r23d43_rapier_authorization_preflight,
    run_qsdk_r23d27_rapier_physical_impl as run_qsdk_r23d43_rapier_physical,
    run_qsdk_r23d27_rapier_preflight_impl as run_qsdk_r23d43_rapier_preflight,
};
pub use qsdk_r23d3_phase_balanced::r23d27_physical::{
    run_qsdk_r23d27_rapier_authorization_preflight_impl as run_qsdk_r23d44_rapier_authorization_preflight,
    run_qsdk_r23d27_rapier_physical_impl as run_qsdk_r23d44_rapier_physical,
    run_qsdk_r23d27_rapier_preflight_impl as run_qsdk_r23d44_rapier_preflight,
};
pub use qsdk_r23d3_phase_balanced::r23d27_physical::{
    run_qsdk_r23d27_rapier_authorization_preflight_impl as run_qsdk_r23d48_rapier_authorization_preflight,
    run_qsdk_r23d27_rapier_physical_impl as run_qsdk_r23d48_rapier_physical,
    run_qsdk_r23d27_rapier_preflight_impl as run_qsdk_r23d48_rapier_preflight,
};
pub use qsdk_r23d3_phase_balanced::r23d27_physical::{
    run_qsdk_r23d27_rapier_authorization_preflight_impl as run_qsdk_r23d49_rapier_authorization_preflight,
    run_qsdk_r23d27_rapier_physical_impl as run_qsdk_r23d49_rapier_physical,
    run_qsdk_r23d27_rapier_preflight_impl as run_qsdk_r23d49_rapier_preflight,
};
pub use qsdk_r23d3_phase_balanced::r23d27_physical::{
    run_qsdk_r23d27_rapier_authorization_preflight_impl as run_qsdk_r23d50_rapier_authorization_preflight,
    run_qsdk_r23d27_rapier_physical_impl as run_qsdk_r23d50_rapier_physical,
    run_qsdk_r23d27_rapier_preflight_impl as run_qsdk_r23d50_rapier_preflight,
};
pub use qsdk_r23d3_phase_balanced::{
    run_qsdk_r23d3_rapier_physical, run_qsdk_r23d3_rapier_preflight,
    run_qsdk_r23d4_rapier_physical, run_qsdk_r23d4_rapier_preflight,
    run_qsdk_r23d5_rapier_physical, run_qsdk_r23d5_rapier_preflight,
    run_qsdk_r23d6_rapier_physical, run_qsdk_r23d6_rapier_preflight,
    run_qsdk_r23d7_rapier_physical, run_qsdk_r23d7_rapier_preflight,
    run_qsdk_r23d8_rapier_authorization_preflight, run_qsdk_r23d8_rapier_physical,
    run_qsdk_r23d8_rapier_preflight,
};
pub use qsdk_r23d9_support_handoff::{
    run_qsdk_r23d9_rapier_authorization_preflight, run_qsdk_r23d9_rapier_physical,
    run_qsdk_r23d9_rapier_preflight,
};
pub use qsdk_r23d10_quiescent_taper::{
    run_qsdk_r23d10_rapier_authorization_preflight, run_qsdk_r23d10_rapier_physical,
    run_qsdk_r23d10_rapier_preflight,
};
pub use qsdk_r23d11_stability_assisted_taper::{
    run_qsdk_r23d11_rapier_authorization_preflight, run_qsdk_r23d11_rapier_physical,
    run_qsdk_r23d11_rapier_preflight,
};
pub use qsdk_r23d12_measurement_semantics::{
    run_qsdk_r23d12_rapier_authorization_preflight, run_qsdk_r23d12_rapier_physical,
    run_qsdk_r23d12_rapier_preflight, run_qsdk_r23d12_rapier_semantics_preflight,
};
pub use qsdk_r23d13_residual_pose_authority::run_qsdk_r23d13_rapier_authority_preflight;
pub use qsdk_r23d14_tight_gated_horizon::run_qsdk_r23d14_rapier_temporal_preflight;
pub use qsdk_r23d15_composition_recovery::{
    R23D15_STAGE_ID, run_qsdk_r23d15_rapier_inherited_composition_preflight,
};
pub use qsdk_r23d16_composition_recovery::{
    R23D16_STAGE_ID, run_qsdk_r23d16_rapier_inherited_composition_preflight,
};
pub use qsdk_r23d17_composition_recovery::{
    R23D17_STAGE_ID, run_qsdk_r23d17_rapier_inherited_composition_preflight,
};
pub use qsdk_r23d18_composition_recovery::{
    R23D18_STAGE_ID, run_qsdk_r23d18_rapier_inherited_composition_preflight,
};
pub use qsdk_r23d22_composition_recovery::{
    R23D22_STAGE_ID, run_qsdk_r23d22_rapier_inherited_composition_preflight,
};
pub use qsdk_r23d23_composition_recovery::{
    R23D23_STAGE_ID, run_qsdk_r23d23_rapier_inherited_composition_preflight,
};
pub use qsdk_r23d62_public_profile_route::run_qsdk_r23d62_rapier_public_profile_route_preflight;
pub use qsdk_r23d62_rapier_worker::{
    R23D62_CAMPAIGN_ID, R23D62_CAMPAIGN_SEED, R23D62_GATE_ID, R23D62_STAGE_ID,
    run_qsdk_r23d62_rapier_authorization_preflight, run_qsdk_r23d62_rapier_physical,
    run_qsdk_r23d62_rapier_preflight,
};
pub use qsdk_r23d63_public_profile_route::run_qsdk_r23d63_rapier_public_profile_route_preflight;
pub use qsdk_r23d63_rapier_worker::{
    R23D63_CAMPAIGN_ID, R23D63_CAMPAIGN_SEED, R23D63_GATE_ID, R23D63_STAGE_ID,
    run_qsdk_r23d63_rapier_authorization_preflight, run_qsdk_r23d63_rapier_physical,
    run_qsdk_r23d63_rapier_preflight,
};
pub use qsdk_r23d64_public_profile_route::run_qsdk_r23d64_rapier_public_profile_route_preflight;
pub use qsdk_r23d64_rapier_worker::{
    R23D64_CAMPAIGN_ID, R23D64_CAMPAIGN_SEED, R23D64_GATE_ID, R23D64_STAGE_ID,
    run_qsdk_r23d64_rapier_authorization_preflight, run_qsdk_r23d64_rapier_physical,
    run_qsdk_r23d64_rapier_preflight,
};
pub use qsdk_r23d65_public_profile_route::run_qsdk_r23d65_rapier_public_profile_route_preflight;
pub use qsdk_r23d65_rapier_worker::{
    R23D65_CAMPAIGN_ID, R23D65_CAMPAIGN_SEED, R23D65_GATE_ID, R23D65_STAGE_ID,
    run_qsdk_r23d65_rapier_authorization_preflight, run_qsdk_r23d65_rapier_physical,
    run_qsdk_r23d65_rapier_preflight,
};
pub use qsdk_r23d66_turning_route::{
    run_qsdk_r23d66_rapier_authorization_preflight, run_qsdk_r23d66_rapier_physical,
    run_qsdk_r23d66_rapier_preflight,
};
pub use qsdk_r23d67_turning_route::{
    run_qsdk_r23d67_rapier_authorization_preflight, run_qsdk_r23d67_rapier_physical,
    run_qsdk_r23d67_rapier_preflight,
};
pub use qsdk_r23d68_turning_route::{
    run_qsdk_r23d68_rapier_authorization_preflight, run_qsdk_r23d68_rapier_physical,
    run_qsdk_r23d68_rapier_preflight,
};
pub use qsdk_r23d69_turning_route::{
    run_qsdk_r23d69_rapier_authorization_preflight, run_qsdk_r23d69_rapier_complete_row_ghost,
    run_qsdk_r23d69_rapier_physical, run_qsdk_r23d69_rapier_preflight,
};
pub use qsdk_r23d70_turning_route::{
    run_qsdk_r23d70_rapier_authorization_preflight, run_qsdk_r23d70_rapier_complete_row_ghost,
    run_qsdk_r23d70_rapier_physical, run_qsdk_r23d70_rapier_preflight,
};
pub use qsdk_r23d71_turning_route::{
    run_qsdk_r23d71_rapier_authorization_preflight, run_qsdk_r23d71_rapier_complete_row_ghost,
    run_qsdk_r23d71_rapier_physical, run_qsdk_r23d71_rapier_preflight,
    run_qsdk_r23d71_success_terminal_projection_ghost,
};
pub use qsdk_r23d74_turning_route::{
    run_qsdk_r23d74_rapier_authorization_preflight, run_qsdk_r23d74_rapier_complete_row_ghost,
    run_qsdk_r23d74_rapier_physical, run_qsdk_r23d74_rapier_preflight,
    run_qsdk_r23d74_success_terminal_projection_ghost,
};
pub use qsdk_r23d76_turning_route::{
    run_qsdk_r23d76_rapier_authorization_preflight, run_qsdk_r23d76_rapier_complete_row_ghost,
    run_qsdk_r23d76_rapier_physical, run_qsdk_r23d76_rapier_preflight,
    run_qsdk_r23d76_success_terminal_projection_ghost,
};
pub use qsdk_r23d78_turning_route::{
    run_qsdk_r23d78_rapier_authorization_preflight, run_qsdk_r23d78_rapier_complete_row_ghost,
    run_qsdk_r23d78_rapier_physical, run_qsdk_r23d78_rapier_preflight,
    run_qsdk_r23d78_success_terminal_projection_ghost,
};
pub use qsdk_r24d45_recovery_route::{
    run_qsdk_r24d45_rapier_recovery_development_attempt, run_qsdk_r24d45_rapier_recovery_ghost,
    run_qsdk_r24d45_rapier_recovery_route_qualification,
};
#[cfg(feature = "sporespore-rapier-motor-work")]
pub use qsdk_r24d46_motor_work_observer::{
    R24D46_GATE_ID, R24D46_PATCH_FEATURE, R24D46_WORK_RULE_ID, RapierMotorWorkSampleV1,
    collect_r24d46_rapier_motor_work_v1,
    run_qsdk_r24d46_rapier_motor_work_zero_world_qualification,
};
#[cfg(feature = "sporespore-rapier-energy-exchange")]
pub use qsdk_r24d47_energy_exchange_observer::{
    R24D47_ENERGY_RULE_ID, R24D47_GATE_ID, R24D47_PATCH_FEATURE, RapierEnergyExchangeSampleV1,
    collect_r24d47_rapier_world_energy_exchange_v1,
    run_qsdk_r24d47_rapier_energy_exchange_zero_world_qualification,
};
#[cfg(feature = "sporespore-rapier-energy-exchange")]
pub use qsdk_r24d48_recovery_energy_v2_route::{
    R24D48_GATE_ID, run_qsdk_r24d48_rapier_recovery_energy_v2_development_attempt,
    run_qsdk_r24d48_rapier_recovery_energy_v2_ghost,
    run_qsdk_r24d48_rapier_recovery_energy_v2_zero_world_qualification,
};
#[cfg(feature = "sporespore-rapier-energy-exchange")]
pub use qsdk_r24d49_runtime_binding_route::{
    R24D49_GATE_ID, run_qsdk_r24d49_rapier_recovery_energy_v2_development_attempt,
    run_qsdk_r24d49_rapier_recovery_energy_v2_ghost,
    run_qsdk_r24d49_rapier_runtime_binding_zero_world_qualification,
};
#[cfg(feature = "sporespore-rapier-energy-exchange")]
pub use qsdk_r24d51_discrete_staging_observer::{
    R24D51_EXPECTED_SMALL_STEP_COUNT, R24D51_GATE_ID, R24D51_STAGING_RULE_ID,
    RapierDiscreteStagingExchangeV1, RapierDiscreteStagingSmallStepV1,
    RapierEndpointHalfStepProjectionV1, measure_r24d51_rapier_discrete_staging_exchange_v1,
    run_qsdk_r24d51_rapier_discrete_staging_zero_world_qualification,
};
#[cfg(feature = "sporespore-rapier-discrete-staging")]
pub use qsdk_r24d52_discrete_staging_ledger::{
    R24D52_GATE_ID, R24D52_STAGING_LEDGER_MAPPING_PROFILE_ID,
    collect_r24d52_rapier_discrete_staging_v1, collect_r24d52_rapier_world_discrete_staging_v1,
    map_r24d52_recovery_energy_increment_v3,
    run_qsdk_r24d52_rapier_discrete_staging_ledger_zero_world_qualification,
};
#[cfg(feature = "sporespore-rapier-r24d53-staging-transport")]
pub use qsdk_r24d53_staging_transport_smoke::{
    R24D53_GATE_ID, run_qsdk_r24d53_rapier_staging_transport_smoke,
    run_qsdk_r24d53_rapier_staging_transport_zero_world_qualification,
};
#[cfg(feature = "sporespore-rapier-r24d54-v3-recovery-behavior")]
pub use qsdk_r24d54_recovery_energy_v3_behavior::{
    R24D54_GATE_ID, run_qsdk_r24d54_rapier_recovery_energy_v3_development_attempt,
    run_qsdk_r24d54_rapier_recovery_energy_v3_zero_world_qualification,
};
#[cfg(feature = "sporespore-rapier-r24d55-terminal-prefix-recovery")]
pub use qsdk_r24d54_recovery_energy_v3_behavior::{
    R24D55_GATE_ID, run_qsdk_r24d55_rapier_terminal_prefix_recovery_development_attempt,
    run_qsdk_r24d55_rapier_terminal_prefix_recovery_zero_world_qualification,
};
pub use recovery_capability::{
    RAPIER_RECOVERY_ADAPTER_ID, RAPIER_RECOVERY_ENGINE_VERSION, RAPIER_RECOVERY_MAPPING_ID,
    rapier_recovery_capability_v1, run_recovery_capability_preflight,
};
pub use recovery_runtime::{
    RAPIER_RECOVERY_COLLECTOR_ID, collect_rapier_native_recovery_observation_v1,
    collect_rapier_native_recovery_observation_v2, collect_rapier_native_recovery_observation_v3,
    plan_rapier_recovery_control_v1, plan_rapier_recovery_control_v2,
    plan_rapier_recovery_control_v3, plan_rapier_recovery_stance_control_v1,
    plan_rapier_recovery_stance_control_v2, plan_rapier_recovery_stance_control_v3,
    rapier_recovery_collection_request_v1, rapier_recovery_collection_request_v2,
    rapier_recovery_collection_request_v3, rapier_recovery_development_profile_v1,
    rapier_recovery_runtime_binding_v1, run_recovery_runtime_surface_preflight,
};
pub use turning_three_engine_route::{
    run_turning_route_rapier_authorization_preflight, run_turning_route_rapier_physical,
    run_turning_route_rapier_preflight,
};
pub use velocity_only_live_integration::run_velocity_only_live_integration_preflight;

pub const ADAPTER_ID: &str = "sporespore_rapier3d_adapter";
pub const ADAPTER_MANIFEST_VERSION: &str = "sporespore_rapier_adapter_manifest_v2";
/// Stable outer integration timestep shared by active and retained Rapier paths.
pub const RAPIER_DT_S: f32 = 1.0 / 120.0;

/// Return the capability manifest for the implemented adapter slice.
///
/// Capability booleans are deliberately fail-closed. They become `true` only
/// in the same commit that adds and verifies the corresponding physical
/// conformance fixtures.
pub fn capability_manifest() -> Value {
    json!({
        "schema_version": ADAPTER_MANIFEST_VERSION,
        "adapter_id": ADAPTER_ID,
        "locomotion_semantics_version": LOCOMOTION_SEMANTICS_VERSION,
        "host": {
            "engine": "rapier3d",
            "engine_version": rapier3d::VERSION,
            "geometry_query_backend": "parry3d_via_rapier",
            "geometry_query_backend_version": "0.29.0",
            "scalar": "f32",
            "dimension": 3,
            "coordinate_mapping": "canonical_x_forward_y_up_z_right_to_rapier_x_forward_y_up_z_right",
            "timestep_s": RAPIER_DT_S,
            "solver_iterations": RAPIER_ACTIVE_SOLVER_ITERATIONS,
            "internal_pgs_iterations": RAPIER_ACTIVE_INTERNAL_PGS_ITERATIONS,
            "internal_stabilization_iterations":
                RAPIER_ACTIVE_INTERNAL_STABILIZATION_ITERATIONS,
            "friction_model": "simplified",
        },
        "conformance": {
            "c0_schema": true,
            "c1_pure_controller": true,
            "c2_kinematic": true,
            "c3_passive_dynamics": true,
            "c4_actuator": true,
            "c5_contact": true,
            "c6_locomotion": false,
        },
        "observation_capabilities": {
            "ordered_body_pose_twist": true,
            "joint_position_velocity": true,
            "joint_anchor_error": true,
            "contact_presence": true,
            "contact_bearing": false,
            "contact_point": true,
            "contact_normal": true,
            "contact_relative_velocity": true,
            "raw_contact_impulse": true,
            "normal_load": false,
        },
        "actuator_capabilities": {
            "position_velocity_motor": true,
            "per_step_impulse_limit": true,
            "response_grid_characterization": true,
            "motor_model": "ForceBased",
            "motor_model_explicit_selection": true,
            "motor_model_readback": true,
            "canonical_velocity_semantics_version": "sporespore_locomotion_semantics_v4",
            "velocity_only_live_profile_id":
                "rapier_force_based_velocity_only_v1",
            "velocity_only_force_based_builder_path": true,
            "velocity_only_force_based_mutable_update_path": true,
            "velocity_only_zero_native_position_stiffness": true,
            "velocity_only_host_characterization_closure_sha256":
                velocity_only_live_integration::VH1_CLOSURE_RAW_SHA256,
            "velocity_only_live_semantic_integration_preflight": true,
            "velocity_only_selected_policy_physical_evaluation": false,
            "effort_torque": false,
        },
        "material_characterization": {
            "authored_friction": true,
            "effective_solver_friction": true,
            "effective_breakaway": true,
            "steady_slide": true,
            "distinct_static_and_dynamic_coefficients": false,
            "implemented_discrete_authored_values": [0.2, 0.6, 1.0],
            "characterization_report_authority": false,
            "restitution": true,
        },
        "controller_policy_authority": false,
        "physical_acceptance_authority": false,
    })
}

pub fn capability_manifest_sha256() -> String {
    digest_json(&capability_manifest()).expect("static Rapier manifest must be canonicalizable")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn manifest_advertises_only_implemented_host_capabilities() {
        let manifest = capability_manifest();
        assert_eq!(manifest["adapter_id"], ADAPTER_ID);
        assert_eq!(manifest["conformance"]["c0_schema"], true);
        assert_eq!(manifest["conformance"]["c1_pure_controller"], true);
        for capability in [
            "c2_kinematic",
            "c3_passive_dynamics",
            "c4_actuator",
            "c5_contact",
        ] {
            assert_eq!(manifest["conformance"][capability], true);
        }
        assert_eq!(manifest["conformance"]["c6_locomotion"], false);
        assert_eq!(
            manifest["host"]["solver_iterations"],
            RAPIER_ACTIVE_SOLVER_ITERATIONS
        );
        assert_eq!(
            manifest["host"]["internal_pgs_iterations"],
            RAPIER_ACTIVE_INTERNAL_PGS_ITERATIONS
        );
        assert_eq!(
            manifest["host"]["internal_stabilization_iterations"],
            RAPIER_ACTIVE_INTERNAL_STABILIZATION_ITERATIONS
        );
        assert_eq!(manifest["observation_capabilities"]["normal_load"], false);
        assert_eq!(
            manifest["material_characterization"]["effective_breakaway"],
            true
        );
        assert_eq!(manifest["material_characterization"]["steady_slide"], true);
        assert_eq!(
            manifest["material_characterization"]["characterization_report_authority"],
            false
        );
        assert_eq!(
            manifest["actuator_capabilities"]["response_grid_characterization"],
            true
        );
        assert_eq!(
            manifest["actuator_capabilities"]["motor_model"],
            "ForceBased"
        );
        assert_eq!(
            manifest["actuator_capabilities"]["motor_model_explicit_selection"],
            true
        );
        assert_eq!(
            manifest["actuator_capabilities"]["motor_model_readback"],
            true
        );
        assert_eq!(
            manifest["actuator_capabilities"]["canonical_velocity_semantics_version"],
            "sporespore_locomotion_semantics_v4"
        );
        assert_eq!(
            manifest["actuator_capabilities"]["velocity_only_live_profile_id"],
            "rapier_force_based_velocity_only_v1"
        );
        assert_eq!(
            manifest["actuator_capabilities"]["velocity_only_host_characterization_closure_sha256"],
            velocity_only_live_integration::VH1_CLOSURE_RAW_SHA256
        );
        assert_eq!(
            manifest["actuator_capabilities"]["velocity_only_selected_policy_physical_evaluation"],
            false
        );
        assert_eq!(manifest["controller_policy_authority"], false);
        assert_eq!(manifest["physical_acceptance_authority"], false);
    }

    #[test]
    fn manifest_digest_is_stable_and_typed() {
        let digest = capability_manifest_sha256();
        assert!(digest.starts_with("sha256:"));
        assert_eq!(digest.len(), 71);
        assert_eq!(digest, capability_manifest_sha256());
    }

    #[test]
    fn physical_c2_c5_fixtures_pass_as_one_report() {
        let report = run_c2_c5_conformance().unwrap();
        assert_eq!(report["ok"], true);
        assert_eq!(report["passed_cells"], 4);
        assert_eq!(report["failed_cells"], 0);
        assert_eq!(report["physical_acceptance_authority"], false);
    }

    #[test]
    fn host_characterization_integrity_preflight_is_zero_world_and_fail_closed() {
        let report = run_host_characterization_preflight().unwrap();
        assert_eq!(report["ok"], true);
        assert_eq!(report["perfect_synthetic_result_passed"], true);
        assert_eq!(report["nonzero_failure_canary_rejected"], true);
        assert_eq!(report["campaign_id"], "C6-HOST-CHARACTERIZATION-R2");
        assert_eq!(report["gate_id"], "C6-HC1-R2");
        assert_eq!(
            report["preregistration_raw_sha256"],
            "sha256:690dc6e5ed4d8d0be2c0c5e4eb294d8160f9ac9ec4309de7ded82aa89951f451"
        );
        assert_eq!(report["world_build_count"], 0);
        assert_eq!(report["physical_acceptance_authority"], false);
    }

    #[test]
    fn force_based_host_characterization_preflight_is_zero_world_and_fail_closed() {
        let report = run_force_based_host_characterization_preflight().unwrap();
        assert_eq!(report["ok"], true);
        assert_eq!(
            report["campaign_id"],
            "C6-RAPIER-FORCE-BASED-HOST-CHARACTERIZATION"
        );
        assert_eq!(report["gate_id"], "C6-RAP-HC-FB1");
        assert_eq!(
            report["default_model_canary"]["observed"],
            "AccelerationBased"
        );
        assert_eq!(report["default_model_canary"]["passed"], true);
        assert_eq!(report["explicit_builder_model"]["observed"], "ForceBased");
        assert_eq!(report["explicit_builder_model"]["passed"], true);
        assert_eq!(report["mutable_update_model"]["observed"], "ForceBased");
        assert_eq!(report["mutable_update_model"]["passed"], true);
        assert_eq!(
            report["perfect_synthetic_result_passed_entire_integrity_gate"],
            true
        );
        assert_eq!(report["nonzero_motor_model_mismatch_canary_rejected"], true);
        assert_eq!(report["world_build_count"], 0);
        assert_eq!(report["locomotion_outcome_exposed"], false);
        assert_eq!(report["physical_acceptance_authority"], false);
    }

    #[test]
    fn force_based_load_response_preflight_is_zero_world_and_fail_closed() {
        let report = run_force_based_load_response_preflight().unwrap();
        assert_eq!(report["ok"], true);
        assert_eq!(report["campaign_id"], "C6-RAPIER-FORCE-BASED-LOAD-RESPONSE");
        assert_eq!(report["gate_id"], "C6-RAP-HC-LR1");
        assert_eq!(report["default_model_canary"]["passed"], true);
        assert_eq!(report["explicit_builder_model"]["passed"], true);
        assert_eq!(report["mutable_update_model"]["passed"], true);
        assert_eq!(
            report["perfect_analytic_eight_cell_result_passed_entire_gate"],
            true
        );
        assert_eq!(report["whole_outer_step_impulse_canary_rejected"], true);
        assert_eq!(report["wrong_signed_response_canary_rejected"], true);
        assert_eq!(report["missing_cell_canary_rejected"], true);
        assert_eq!(report["world_build_count"], 0);
        assert_eq!(report["locomotion_outcome_exposed"], false);
        assert_eq!(report["physical_acceptance_authority"], false);
    }

    #[test]
    fn force_based_convergence_window_preflight_is_zero_world_and_fail_closed() {
        let report = run_force_based_convergence_window_preflight().unwrap();
        assert_eq!(report["ok"], true);
        assert_eq!(
            report["campaign_id"],
            "C6-RAPIER-FORCE-BASED-CONVERGENCE-WINDOW"
        );
        assert_eq!(report["gate_id"], "C6-RAP-HC-CW1");
        assert_eq!(report["default_model_canary"]["passed"], true);
        assert_eq!(report["explicit_builder_model"]["passed"], true);
        assert_eq!(report["mutable_update_model"]["passed"], true);
        assert_eq!(
            report["perfect_eight_cell_convergence_traces_passed_entire_gate"],
            true
        );
        assert_eq!(report["single_acceptable_step_canary_rejected"], true);
        assert_eq!(report["window_gap_canary_rejected"], true);
        assert_eq!(report["whole_outer_step_impulse_canary_rejected"], true);
        assert_eq!(report["missing_cell_canary_rejected"], true);
        assert_eq!(report["world_build_count"], 0);
        assert_eq!(report["locomotion_outcome_exposed"], false);
        assert_eq!(report["physical_acceptance_authority"], false);
    }

    #[test]
    fn force_based_solver_phase_development_preflight_is_zero_world_and_fail_closed() {
        let report = run_force_based_solver_phase_development_preflight().unwrap();
        assert_eq!(report["ok"], true);
        assert_eq!(
            report["campaign_id"],
            "C6-RAPIER-FORCE-BASED-SOLVER-PHASE-DEVELOPMENT"
        );
        assert_eq!(report["gate_id"], "C6-RAP-HC-SPD1");
        assert_eq!(report["default_model_canary"]["passed"], true);
        assert_eq!(report["explicit_builder_model"]["passed"], true);
        assert_eq!(report["mutable_update_model"]["passed"], true);
        assert_eq!(
            report["perfect_sixteen_cell_traces_passed_entire_gate"],
            true
        );
        assert_eq!(
            report["known_fastest_candidate_selected"]["selected_candidate_id"],
            "SPD1-D"
        );
        assert_eq!(report["no_eligible_candidate_canary_selected_none"], true);
        assert_eq!(report["missing_cell_canary_rejected"], true);
        assert_eq!(report["window_gap_canary_rejected"], true);
        assert_eq!(report["unequal_total_pass_canary_rejected"], true);
        assert_eq!(report["tie_break_canary_selected_spd1_a"], true);
        assert_eq!(report["world_build_count"], 0);
        assert_eq!(report["validation_authority"], false);
        assert_eq!(report["physical_acceptance_authority"], false);
    }

    #[test]
    fn force_based_selected_configuration_validation_preflight_is_zero_world_and_fail_closed() {
        let report = run_force_based_selected_configuration_validation_preflight().unwrap();
        assert_eq!(report["ok"], true);
        assert_eq!(
            report["campaign_id"],
            "C6-RAPIER-FORCE-BASED-SELECTED-CONFIGURATION-VALIDATION"
        );
        assert_eq!(report["gate_id"], "C6-RAP-HC-SPV1");
        assert_eq!(report["default_model_canary"]["passed"], true);
        assert_eq!(report["explicit_builder_model"]["passed"], true);
        assert_eq!(report["mutable_update_model"]["passed"], true);
        assert_eq!(report["perfect_eight_cell_result_passed_entire_gate"], true);
        assert_eq!(report["missing_cell_canary_rejected"], true);
        assert_eq!(report["wrong_allocation_canary_rejected"], true);
        assert_eq!(report["position_error_canary_rejected"], true);
        assert_eq!(report["velocity_response_canary_rejected"], true);
        assert_eq!(report["loaded_window_gap_canary_rejected"], true);
        assert_eq!(report["motor_model_mismatch_canary_rejected"], true);
        assert_eq!(report["world_build_count"], 0);
        assert_eq!(report["validation_authority"], false);
        assert_eq!(report["physical_acceptance_authority"], false);
    }

    #[test]
    fn selected_policy_commissioning_preflight_is_zero_world_and_fail_closed() {
        let report = run_selected_policy_commissioning_preflight().unwrap();
        assert_eq!(report["ok"], true);
        assert_eq!(report["perfect_synthetic_result_passed"], true);
        assert_eq!(report["nonzero_failure_canary_rejected"], true);
        assert_eq!(
            report["campaign_id"],
            "C6-RAPIER-SELECTED-POLICY-COMMISSIONING"
        );
        assert_eq!(report["gate_id"], "C6-RAP-SP1");
        assert_eq!(
            report["preregistration_raw_sha256"],
            "sha256:5d1f77ae8b84bd2fa32f2cd7c71613b0f0c01b03ecbc88b4ca0deba9670bb440"
        );
        assert_eq!(report["world_build_count"], 0);
        assert_eq!(report["locomotion_outcome_exposed"], false);
        assert_eq!(report["physical_acceptance_authority"], false);
    }

    #[test]
    fn bw19v_early_horizon_development_preflight_is_zero_world_and_outcome_agnostic() {
        let report = run_bw19v_early_horizon_development_preflight().unwrap();
        assert_eq!(report["ok"], true);
        assert_eq!(
            report["campaign_id"],
            "C6-RAPIER-BW19V-EARLY-HORIZON-MECHANISM-DEVELOPMENT-ED1"
        );
        assert_eq!(report["gate_id"], "C6-RAP-BW19V-ED1");
        assert_eq!(report["synthetic_arm_count"], 2);
        assert_eq!(report["synthetic_trace_step_count"], 944);
        assert_eq!(
            report["synthetic_outcome_variants_all_integrity_valid"],
            true
        );
        assert_eq!(report["world_build_count"], 0);
        assert_eq!(report["physical_acceptance_authority"], false);
    }

    #[test]
    fn selected_policy_commissioning_r1_preflight_catches_host_transport_regressions() {
        let report = run_selected_policy_commissioning_r1_preflight().unwrap();
        assert_eq!(report["ok"], true);
        assert_eq!(report["perfect_synthetic_result_passed"], true);
        assert_eq!(report["nonzero_failure_canary_rejected"], true);
        assert_eq!(
            report["nonidentity_host_quaternion_conversion"]["portable_unit_norm_validation_passed"],
            true
        );
        assert_eq!(
            report["intentional_previous_actuation_null_ignored_by_numeric_finiteness_check"],
            true
        );
        assert_eq!(
            report["campaign_id"],
            "C6-RAPIER-SELECTED-POLICY-COMMISSIONING-R1"
        );
        assert_eq!(report["gate_id"], "C6-RAP-SP1-R1");
        assert_eq!(
            report["preregistration_raw_sha256"],
            "sha256:3102a8dddb8f6c7236735e2cdc6b403763d000a6b1518d55c201a7627e00a37f"
        );
        assert_eq!(
            report["predecessor_closure_raw_sha256"],
            "sha256:b7f461bcadff96069e14b85357e58b97c61c555903792b99c37116e17ee31557"
        );
        assert_eq!(report["world_build_count"], 0);
        assert_eq!(report["locomotion_outcome_exposed"], false);
        assert_eq!(report["physical_acceptance_authority"], false);
    }

    #[test]
    fn selected_policy_commissioning_r2_preflight_requires_complete_observability() {
        let report = run_selected_policy_commissioning_r2_preflight().unwrap();
        assert_eq!(report["ok"], true);
        assert_eq!(
            report["perfect_synthetic_observability_receipt_passed"],
            true
        );
        assert_eq!(
            report["missing_required_observability_field_canary_rejected"],
            true
        );
        assert_eq!(report["inherited_r1_preflight"]["ok"], true);
        assert_eq!(
            report["campaign_id"],
            "C6-RAPIER-SELECTED-POLICY-COMMISSIONING-R2"
        );
        assert_eq!(report["gate_id"], "C6-RAP-SP1-R2");
        assert_eq!(
            report["preregistration_raw_sha256"],
            "sha256:fe0b6d23f1262d1d3ead5621f6c8042c48ae016afebbdac20d51c52671ff7ec9"
        );
        assert_eq!(
            report["predecessor_closure_raw_sha256"],
            "sha256:0fe513b1af8fe386f4d9c13d7485f4bdfd37711d38a846a938fab11270b0e9fb"
        );
        assert_eq!(report["world_build_count"], 0);
        assert_eq!(report["locomotion_outcome_exposed"], false);
        assert_eq!(report["physical_acceptance_authority"], false);
    }
}
