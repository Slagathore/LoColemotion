//! Zero-world Rapier/Parry recovery-observation capability mapping.
//!
//! This source boundary names the exact Rapier 0.34 APIs from which a future
//! native recovery collector must obtain each portable channel. It constructs
//! no body, collider, joint set, pipeline, query pipeline, or physics world and
//! never calls `PhysicsPipeline::step`.

use rapier3d::geometry::{Collider, ContactData, ContactPair};
use rapier3d::prelude::{RevoluteJoint, RigidBody};
use serde_json::{Value, json};
use sporespore_locomotion_core::{
    CANONICAL_PRONE_TO_STANDING_TASK_ID, PORTABLE_RECOVERY_SEMANTICS_ID,
    R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID, RECOVERY_ADAPTER_CAPABILITY_V1_VERSION,
    RECOVERY_INITIALIZE_REQUEST_V1_VERSION, RecoveryAdapterCapabilityV1, RecoveryArmKindV1,
    RecoveryChannelCapabilityV1, RecoveryChannelSupportV1, RecoveryInitializeRequestV1,
    RecoveryNativeEngineV1, RecoveryObservationChannelV1, RecoverySupportStatusV1,
    SYNTHETIC_ZERO_WORLD_THRESHOLD_PROFILE_ID, digest_serializable, initialize_recovery_v1,
    r23d60_selected_s169_descriptor,
};

pub const RAPIER_RECOVERY_ADAPTER_ID: &str = "sporespore_rapier3d_adapter";
pub const RAPIER_RECOVERY_MAPPING_ID: &str =
    "sporespore_rapier_parry_recovery_observation_capability_v1";
pub const RAPIER_RECOVERY_ENGINE_VERSION: &str = "rapier3d-0.34.0-parry3d-0.29.0";

fn channel(
    channel: RecoveryObservationChannelV1,
    host_source_ids: &[&str],
    mapping_rule_id: &str,
) -> RecoveryChannelCapabilityV1 {
    RecoveryChannelCapabilityV1 {
        channel,
        support: RecoveryChannelSupportV1::SupportedMeasured,
        host_source_ids: host_source_ids
            .iter()
            .map(|value| (*value).to_owned())
            .collect(),
        mapping_rule_id: mapping_rule_id.to_owned(),
        source_measurement_only: true,
        synthesized_when_missing: false,
    }
}

/// Return the content-addressable, zero-world source capability receipt.
pub fn rapier_recovery_capability_v1() -> RecoveryAdapterCapabilityV1 {
    RecoveryAdapterCapabilityV1 {
        schema_version: RECOVERY_ADAPTER_CAPABILITY_V1_VERSION.to_owned(),
        adapter_id: RAPIER_RECOVERY_ADAPTER_ID.to_owned(),
        engine: RecoveryNativeEngineV1::RapierParryNative,
        engine_version: RAPIER_RECOVERY_ENGINE_VERSION.to_owned(),
        mapping_id: RAPIER_RECOVERY_MAPPING_ID.to_owned(),
        native_engine: true,
        ordered_channels: vec![
            channel(
                RecoveryObservationChannelV1::CanonicalBodyPoseAndTwist,
                &[
                    "rapier3d::dynamics::RigidBody::position",
                    "rapier3d::dynamics::RigidBody::linvel",
                    "rapier3d::dynamics::RigidBody::angvel",
                ],
                "rapier_pose_twist_to_canonical_y_up_right_handed_v1",
            ),
            channel(
                RecoveryObservationChannelV1::WholeSystemCenterOfMassPositionAndVelocity,
                &[
                    "rapier3d::dynamics::RigidBody::center_of_mass",
                    "rapier3d::dynamics::RigidBody::mass",
                    "rapier3d::dynamics::RigidBody::linvel",
                    "sporespore_rapier_adapter::mass_weighted_whole_system_com_ledger_v1",
                ],
                "rapier_mass_weighted_whole_system_com_projection_v1",
            ),
            channel(
                RecoveryObservationChannelV1::OrderedJointPositionAndVelocity,
                &[
                    "rapier3d::dynamics::RevoluteJoint::angle",
                    "rapier3d::dynamics::RigidBody::rotation",
                    "rapier3d::dynamics::RigidBody::angvel",
                ],
                "rapier_revolute_angle_and_relative_axis_velocity_ordered_v1",
            ),
            channel(
                RecoveryObservationChannelV1::OrderedFootBearingContactObservations,
                &[
                    "rapier3d::geometry::NarrowPhase::contact_pair",
                    "rapier3d::geometry::ContactPair::total_impulse",
                    "rapier3d::geometry::ContactData::impulse",
                ],
                "rapier_post_step_ordinary_unilateral_foot_normal_impulse_sum_v1",
            ),
            channel(
                RecoveryObservationChannelV1::ClassifiedNonfootContactObservations,
                &[
                    "rapier3d::geometry::NarrowPhase::contact_pair",
                    "rapier3d::geometry::ContactData::impulse",
                    "rapier3d::geometry::Collider::position",
                    "rapier3d::geometry::Collider::compute_aabb",
                    "rapier3d::geometry::Collider::shape",
                ],
                "rapier_collider_identity_nonfoot_classification_and_clearance_query_v1",
            ),
            channel(
                RecoveryObservationChannelV1::AppliedActuationReceipts,
                &[
                    "rapier3d::dynamics::RevoluteJoint::motor",
                    "sporespore_rapier_adapter::post_application_motor_impulse_ledger_v1",
                ],
                "rapier_applied_outer_step_angular_impulse_receipt_v1",
            ),
            channel(
                RecoveryObservationChannelV1::ExternalInterventionLedger,
                &["sporespore_rapier_adapter::append_only_intervention_call_ledger_v1"],
                "rapier_adapter_owned_exact_intervention_counter_projection_v1",
            ),
            channel(
                RecoveryObservationChannelV1::ControllerOwnershipReceipt,
                &["sporespore_rapier_adapter::exclusive_controller_owner_ledger_v1"],
                "rapier_adapter_owned_controller_handoff_projection_v1",
            ),
            channel(
                RecoveryObservationChannelV1::EnergyBalanceLedger,
                &[
                    "rapier3d::dynamics::RigidBody::kinetic_energy",
                    "rapier3d::dynamics::RigidBody::gravitational_potential_energy",
                    "sporespore_rapier_adapter::measured_actuator_and_external_work_ledger_v1",
                ],
                "rapier_mechanical_energy_known_work_and_unclosed_residual_ledger_v1",
            ),
            channel(
                RecoveryObservationChannelV1::EngineStepIdentity,
                &["sporespore_rapier_adapter::physics_pipeline_step_identity_ledger_v1"],
                "rapier_exact_post_step_and_solver_substep_identity_v1",
            ),
        ],
        host_pose_label_used_for_success: false,
        fallback_control_permitted: false,
        engine_identity_exposed_to_policy: false,
        model_construction_count: 0,
        world_attempt_count: 0,
        world_build_count: 0,
        solver_step_count: 0,
        physics_state_modified: false,
        physical_acceptance_authority: false,
        release_authority: false,
    }
}

/// Compile-time reachability probe for every Rapier API named above.
///
/// It is intentionally never invoked; accepting borrowed host objects keeps
/// compilation honest without constructing or stepping a world.
#[allow(dead_code)]
fn compile_time_native_api_surface(
    body: &RigidBody,
    other_body: &RigidBody,
    joint: &RevoluteJoint,
    pair: &ContactPair,
    contact: &ContactData,
    collider: &Collider,
) {
    let _ = body.position();
    let _ = body.rotation();
    let _ = body.linvel();
    let _ = body.angvel();
    let _ = body.center_of_mass();
    let _ = body.mass();
    let _ = body.kinetic_energy();
    let _ = body.gravitational_potential_energy(1.0 / 120.0, Default::default());
    let _ = joint.angle(body.rotation(), other_body.rotation());
    let _ = joint.motor();
    let _ = contact.impulse;
    let _ = pair.total_impulse();
    let _ = pair.total_impulse_magnitude();
    let _ = collider.position();
    let _ = collider.compute_aabb();
    let _ = collider.shape();
}

/// Exercise the portable initialization contract without constructing physics.
pub fn run_recovery_capability_preflight() -> Result<Value, String> {
    let capability = rapier_recovery_capability_v1();
    let capability_sha256 = digest_serializable(&capability).map_err(|error| error.to_string())?;
    let receipt = initialize_recovery_v1(RecoveryInitializeRequestV1 {
        schema_version: RECOVERY_INITIALIZE_REQUEST_V1_VERSION.to_owned(),
        task_id: CANONICAL_PRONE_TO_STANDING_TASK_ID.to_owned(),
        semantics_id: PORTABLE_RECOVERY_SEMANTICS_ID.to_owned(),
        actuator_profile_id: R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID.to_owned(),
        threshold_profile_id: SYNTHETIC_ZERO_WORLD_THRESHOLD_PROFILE_ID.to_owned(),
        descriptor: r23d60_selected_s169_descriptor(),
        adapter_capability: capability,
        arm_kind: RecoveryArmKindV1::CandidateCommand,
    })
    .map_err(|error| error.to_string())?;
    if receipt.support_status != RecoverySupportStatusV1::SupportedExact
        || receipt.capability_sha256 != capability_sha256
        || receipt.controller_implemented
        || receipt.physical_threshold_authority
        || receipt.physical_question_opened
        || receipt.model_construction_count != 0
        || receipt.world_attempt_count != 0
        || receipt.world_build_count != 0
        || receipt.solver_step_count != 0
        || receipt.physics_state_modified
        || receipt.prone_to_standing_claimed
        || receipt.physical_acceptance_authority
        || receipt.release_authority
    {
        return Err("R24D2_RAPIER_PORTABLE_INITIALIZATION_BOUNDARY_INVALID".to_owned());
    }
    Ok(json!({
        "schema_version": "sporespore_qsdk_r24d2_rapier_recovery_capability_preflight_v1",
        "ok": true,
        "question_class": "non_physical_source_conformance",
        "adapter_id": RAPIER_RECOVERY_ADAPTER_ID,
        "engine_version": RAPIER_RECOVERY_ENGINE_VERSION,
        "mapping_id": RAPIER_RECOVERY_MAPPING_ID,
        "capability_sha256": capability_sha256,
        "required_channel_count": 10,
        "compile_time_native_api_surface_present": true,
        "native_runtime_observation_collection_executed": false,
        "controller_implemented": false,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": false,
        "prone_to_standing_claimed": false,
        "cross_engine_equivalence_claimed": false,
        "physical_acceptance_authority": false,
        "release_authority": false
    }))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn initialize(capability: RecoveryAdapterCapabilityV1) -> RecoverySupportStatusV1 {
        initialize_recovery_v1(RecoveryInitializeRequestV1 {
            schema_version: RECOVERY_INITIALIZE_REQUEST_V1_VERSION.to_owned(),
            task_id: CANONICAL_PRONE_TO_STANDING_TASK_ID.to_owned(),
            semantics_id: PORTABLE_RECOVERY_SEMANTICS_ID.to_owned(),
            actuator_profile_id: R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID.to_owned(),
            threshold_profile_id: SYNTHETIC_ZERO_WORLD_THRESHOLD_PROFILE_ID.to_owned(),
            descriptor: r23d60_selected_s169_descriptor(),
            adapter_capability: capability,
            arm_kind: RecoveryArmKindV1::CandidateCommand,
        })
        .unwrap()
        .support_status
    }

    #[test]
    fn exact_mapping_initializes_without_a_world() {
        let report = run_recovery_capability_preflight().unwrap();
        assert_eq!(report["required_channel_count"], 10);
        assert_eq!(report["world_build_count"], 0);
        assert_eq!(report["solver_step_count"], 0);
        assert_eq!(report["prone_to_standing_claimed"], false);
    }

    #[test]
    fn capability_mutations_are_typed_refusals() {
        let mut missing = rapier_recovery_capability_v1();
        missing.ordered_channels.pop();
        assert_eq!(
            initialize(missing),
            RecoverySupportStatusV1::UnsupportedCapability
        );

        let mut synthesized = rapier_recovery_capability_v1();
        synthesized.ordered_channels[3].synthesized_when_missing = true;
        assert_eq!(
            initialize(synthesized),
            RecoverySupportStatusV1::UnsupportedCapability
        );

        let mut world = rapier_recovery_capability_v1();
        world.world_build_count = 1;
        assert_eq!(
            initialize(world),
            RecoverySupportStatusV1::UnsupportedCapability
        );

        let mut branch = rapier_recovery_capability_v1();
        branch.engine_identity_exposed_to_policy = true;
        assert_eq!(
            initialize(branch),
            RecoverySupportStatusV1::UnsupportedCapability
        );
    }
}
