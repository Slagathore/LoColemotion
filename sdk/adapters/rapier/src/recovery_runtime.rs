//! Zero-world Rapier/Parry surface for the exact-s169 recovery runtime.
//!
//! A native worker samples Rapier immediately after its single outer-step
//! `PhysicsPipeline::step` and supplies the complete observation here. These
//! functions bind that observation to the portable validator and deterministic
//! controller. They construct no body, collider, joint set, or physics world
//! and never step a pipeline.

use serde_json::{Value, json};
use sporespore_locomotion_core::{
    CANONICAL_PRONE_TO_STANDING_TASK_ID, EXACT_S169_RECOVERY_CONTROLLER_ID,
    PORTABLE_RECOVERY_SEMANTICS_ID, R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
    RAPIER_NATIVE_RUNTIME_PROFILE_ID, RECOVERY_CONTROL_REQUEST_V1_VERSION,
    RECOVERY_CONTROL_REQUEST_V2_VERSION, RECOVERY_CONTROL_REQUEST_V3_VERSION,
    RECOVERY_NATIVE_COLLECTION_REQUEST_V1_VERSION, RECOVERY_NATIVE_COLLECTION_REQUEST_V2_VERSION,
    RECOVERY_NATIVE_COLLECTION_REQUEST_V3_VERSION, RECOVERY_NATIVE_COLLECTOR_BINDING_V1_VERSION,
    RECOVERY_STANCE_CONTROL_REQUEST_V1_VERSION, RECOVERY_STANCE_CONTROL_REQUEST_V2_VERSION,
    RECOVERY_STANCE_CONTROL_REQUEST_V3_VERSION, RecoveryArmKindV1, RecoveryControlReceiptV1,
    RecoveryControlRequestV1, RecoveryControlRequestV2, RecoveryControlRequestV3,
    RecoveryDevelopmentProfileV1, RecoveryMorphologyContextV1, RecoveryNativeCollectionReceiptV1,
    RecoveryNativeCollectionReceiptV2, RecoveryNativeCollectionRequestV1,
    RecoveryNativeCollectionRequestV2, RecoveryNativeCollectionRequestV3,
    RecoveryNativeCollectorBindingV1, RecoveryObservationV1, RecoveryObservationV2,
    RecoveryObservationV2SourceBindingV1, RecoveryPhaseV1, RecoveryStanceControlRequestV1,
    RecoveryStanceControlRequestV2, RecoveryStanceControlRequestV3, RecoveryStepReceiptV1,
    collect_native_recovery_observation_v1, collect_native_recovery_observation_v2,
    collect_native_recovery_observation_v3, digest_serializable, plan_recovery_control_v1,
    plan_recovery_control_v2, plan_recovery_control_v3, plan_recovery_stance_control_v1,
    plan_recovery_stance_control_v2, plan_recovery_stance_control_v3,
    r23d60_selected_s169_descriptor, recovery_development_profile_v1,
};

use crate::recovery_capability::rapier_recovery_capability_v1;

pub const RAPIER_RECOVERY_COLLECTOR_ID: &str = "sporespore_rapier_parry_recovery_collector_v1";

fn valid_digest(value: &str) -> bool {
    value.len() == 71
        && value.starts_with("sha256:")
        && value[7..]
            .bytes()
            .all(|byte| byte.is_ascii_digit() || (b'a'..=b'f').contains(&byte))
}

/// Return the portable profile without constructing Rapier state.
pub fn rapier_recovery_development_profile_v1() -> RecoveryDevelopmentProfileV1 {
    recovery_development_profile_v1()
}

/// Bind the exact runtime qualification and current capability identities.
pub fn rapier_recovery_runtime_binding_v1(
    runtime_qualification_sha256: &str,
) -> Result<RecoveryNativeCollectorBindingV1, String> {
    if !valid_digest(runtime_qualification_sha256) {
        return Err("RAPIER_RECOVERY_RUNTIME_QUALIFICATION_DIGEST_INVALID".to_owned());
    }
    let capability_sha256 =
        digest_serializable(&rapier_recovery_capability_v1()).map_err(|error| error.to_string())?;
    Ok(RecoveryNativeCollectorBindingV1 {
        schema_version: RECOVERY_NATIVE_COLLECTOR_BINDING_V1_VERSION.to_owned(),
        collector_id: RAPIER_RECOVERY_COLLECTOR_ID.to_owned(),
        runtime_profile_id: RAPIER_NATIVE_RUNTIME_PROFILE_ID.to_owned(),
        runtime_qualification_sha256: runtime_qualification_sha256.to_owned(),
        capability_sha256,
        exact_runtime_identity_qualified: true,
        native_post_step_only: true,
        source_measurement_only: true,
        missing_value_synthesis_permitted: false,
        engine_identity_exposed_to_controller: false,
    })
}

/// Assemble one strict collection request from a complete native snapshot.
pub fn rapier_recovery_collection_request_v1(
    observation: RecoveryObservationV1,
    runtime_qualification_sha256: &str,
    arm_kind: RecoveryArmKindV1,
    phase: RecoveryPhaseV1,
) -> Result<RecoveryNativeCollectionRequestV1, String> {
    Ok(RecoveryNativeCollectionRequestV1 {
        schema_version: RECOVERY_NATIVE_COLLECTION_REQUEST_V1_VERSION.to_owned(),
        task_id: CANONICAL_PRONE_TO_STANDING_TASK_ID.to_owned(),
        semantics_id: PORTABLE_RECOVERY_SEMANTICS_ID.to_owned(),
        actuator_profile_id: R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID.to_owned(),
        descriptor: r23d60_selected_s169_descriptor(),
        adapter_capability: rapier_recovery_capability_v1(),
        runtime_binding: rapier_recovery_runtime_binding_v1(runtime_qualification_sha256)?,
        arm_kind,
        phase,
        observation,
    })
}

/// Assemble the morphology-aware observation-V1 request required by the
/// canonical prone initializer. This remains a pure transport constructor:
/// the supplied observation is validated only by the portable collector.
pub fn rapier_recovery_collection_request_v2(
    observation: RecoveryObservationV1,
    morphology_context: RecoveryMorphologyContextV1,
    runtime_qualification_sha256: &str,
    arm_kind: RecoveryArmKindV1,
    phase: RecoveryPhaseV1,
) -> Result<RecoveryNativeCollectionRequestV2, String> {
    Ok(RecoveryNativeCollectionRequestV2 {
        schema_version: RECOVERY_NATIVE_COLLECTION_REQUEST_V2_VERSION.to_owned(),
        task_id: CANONICAL_PRONE_TO_STANDING_TASK_ID.to_owned(),
        semantics_id: PORTABLE_RECOVERY_SEMANTICS_ID.to_owned(),
        actuator_profile_id: R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID.to_owned(),
        descriptor: r23d60_selected_s169_descriptor(),
        morphology_context,
        adapter_capability: rapier_recovery_capability_v1(),
        runtime_binding: rapier_recovery_runtime_binding_v1(runtime_qualification_sha256)?,
        arm_kind,
        phase,
        observation,
    })
}

/// Assemble the morphology-aware observation-V2 request. The adapter supplies
/// a complete content-addressed source binding; the portable collector remains
/// the authority that accepts or refuses the exact mapping identity.
pub fn rapier_recovery_collection_request_v3(
    observation: RecoveryObservationV2,
    observation_source_binding: RecoveryObservationV2SourceBindingV1,
    morphology_context: RecoveryMorphologyContextV1,
    runtime_qualification_sha256: &str,
    arm_kind: RecoveryArmKindV1,
    phase: RecoveryPhaseV1,
) -> Result<RecoveryNativeCollectionRequestV3, String> {
    Ok(RecoveryNativeCollectionRequestV3 {
        schema_version: RECOVERY_NATIVE_COLLECTION_REQUEST_V3_VERSION.to_owned(),
        task_id: CANONICAL_PRONE_TO_STANDING_TASK_ID.to_owned(),
        semantics_id: PORTABLE_RECOVERY_SEMANTICS_ID.to_owned(),
        actuator_profile_id: R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID.to_owned(),
        descriptor: r23d60_selected_s169_descriptor(),
        morphology_context,
        adapter_capability: rapier_recovery_capability_v1(),
        runtime_binding: rapier_recovery_runtime_binding_v1(runtime_qualification_sha256)?,
        arm_kind,
        phase,
        observation_source_binding,
        observation,
    })
}

/// Validate one already-sampled Rapier post-step observation.
pub fn collect_rapier_native_recovery_observation_v1(
    request: RecoveryNativeCollectionRequestV1,
) -> Result<RecoveryNativeCollectionReceiptV1, String> {
    collect_native_recovery_observation_v1(request).map_err(|error| error.to_string())
}

/// Validate one morphology-aware Rapier post-step observation.
pub fn collect_rapier_native_recovery_observation_v2(
    request: RecoveryNativeCollectionRequestV2,
) -> Result<RecoveryNativeCollectionReceiptV1, String> {
    collect_native_recovery_observation_v2(request).map_err(|error| error.to_string())
}

/// Validate one morphology-aware Rapier observation V2 and its exact native
/// source chain without constructing or stepping a world in the core.
pub fn collect_rapier_native_recovery_observation_v3(
    request: RecoveryNativeCollectionRequestV3,
) -> Result<RecoveryNativeCollectionReceiptV2, String> {
    collect_native_recovery_observation_v3(request).map_err(|error| error.to_string())
}

/// Plan one engine-neutral command without applying it to a Rapier joint.
pub fn plan_rapier_recovery_control_v1(
    collection: RecoveryNativeCollectionRequestV1,
    phase_step: u32,
) -> Result<RecoveryControlReceiptV1, String> {
    plan_recovery_control_v1(RecoveryControlRequestV1 {
        schema_version: RECOVERY_CONTROL_REQUEST_V1_VERSION.to_owned(),
        controller_id: EXACT_S169_RECOVERY_CONTROLLER_ID.to_owned(),
        phase_step,
        collection,
    })
    .map_err(|error| error.to_string())
}

/// Plan one morphology-aware engine-neutral recovery command.
pub fn plan_rapier_recovery_control_v2(
    collection: RecoveryNativeCollectionRequestV2,
    phase_step: u32,
) -> Result<RecoveryControlReceiptV1, String> {
    plan_recovery_control_v2(RecoveryControlRequestV2 {
        schema_version: RECOVERY_CONTROL_REQUEST_V2_VERSION.to_owned(),
        controller_id: EXACT_S169_RECOVERY_CONTROLLER_ID.to_owned(),
        phase_step,
        collection,
    })
    .map_err(|error| error.to_string())
}

/// Plan one engine-neutral recovery command from a validated observation V2.
pub fn plan_rapier_recovery_control_v3(
    collection: RecoveryNativeCollectionRequestV3,
    phase_step: u32,
) -> Result<RecoveryControlReceiptV1, String> {
    plan_recovery_control_v3(RecoveryControlRequestV3 {
        schema_version: RECOVERY_CONTROL_REQUEST_V3_VERSION.to_owned(),
        controller_id: EXACT_S169_RECOVERY_CONTROLLER_ID.to_owned(),
        phase_step,
        collection,
    })
    .map_err(|error| error.to_string())
}

/// Compose the stance-owned successor command from the same accepted Rapier
/// collection and its content-bound portable supervisor handoff receipt.
pub fn plan_rapier_recovery_stance_control_v1(
    collection: RecoveryNativeCollectionRequestV1,
    handoff_or_stance_step: RecoveryStepReceiptV1,
) -> Result<RecoveryControlReceiptV1, String> {
    plan_recovery_stance_control_v1(RecoveryStanceControlRequestV1 {
        schema_version: RECOVERY_STANCE_CONTROL_REQUEST_V1_VERSION.to_owned(),
        controller_id: sporespore_locomotion_core::EXACT_S169_STANCE_CONTROLLER_ID.to_owned(),
        collection,
        handoff_or_stance_step,
    })
    .map_err(|error| error.to_string())
}

/// Compose the morphology-aware stance-owned successor command used by the
/// native prone route after the portable supervisor transfers ownership.
pub fn plan_rapier_recovery_stance_control_v2(
    collection: RecoveryNativeCollectionRequestV2,
    handoff_or_stance_step: RecoveryStepReceiptV1,
) -> Result<RecoveryControlReceiptV1, String> {
    plan_recovery_stance_control_v2(RecoveryStanceControlRequestV2 {
        schema_version: RECOVERY_STANCE_CONTROL_REQUEST_V2_VERSION.to_owned(),
        controller_id: sporespore_locomotion_core::EXACT_S169_STANCE_CONTROLLER_ID.to_owned(),
        collection,
        handoff_or_stance_step,
    })
    .map_err(|error| error.to_string())
}

/// Compose the stance-owned successor command from the accepted Rapier
/// observation V2 and its portable supervisor handoff receipt.
pub fn plan_rapier_recovery_stance_control_v3(
    collection: RecoveryNativeCollectionRequestV3,
    handoff_or_stance_step: RecoveryStepReceiptV1,
) -> Result<RecoveryControlReceiptV1, String> {
    plan_recovery_stance_control_v3(RecoveryStanceControlRequestV3 {
        schema_version: RECOVERY_STANCE_CONTROL_REQUEST_V3_VERSION.to_owned(),
        controller_id: sporespore_locomotion_core::EXACT_S169_STANCE_CONTROLLER_ID.to_owned(),
        collection,
        handoff_or_stance_step,
    })
    .map_err(|error| error.to_string())
}

/// Exercise only identities and profile transport; no native object is built.
pub fn run_recovery_runtime_surface_preflight() -> Result<Value, String> {
    let runtime_qualification_sha256 =
        "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    let binding = rapier_recovery_runtime_binding_v1(runtime_qualification_sha256)?;
    let profile = rapier_recovery_development_profile_v1();
    if binding.runtime_profile_id != RAPIER_NATIVE_RUNTIME_PROFILE_ID
        || binding.engine_identity_exposed_to_controller
        || profile.physical_execution_authorized
        || profile.physical_acceptance_authority
        || profile.release_authority
    {
        return Err("R24D17_RAPIER_RECOVERY_RUNTIME_SURFACE_INVALID".to_owned());
    }
    Ok(json!({
        "schema_version": "sporespore_rapier_recovery_runtime_zero_world_surface_receipt_v1",
        "ok": true,
        "collector_id": binding.collector_id,
        "runtime_profile_id": binding.runtime_profile_id,
        "capability_sha256": binding.capability_sha256,
        "controller_id": profile.controller_id,
        "stance_controller_id": sporespore_locomotion_core::EXACT_S169_STANCE_CONTROLLER_ID,
        "stance_control_surface_implemented": true,
        "morphology_aware_collection_and_control_surface_implemented": true,
        "native_runtime_observation_collection_executed": false,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": false,
        "prone_to_standing_claimed": false,
        "physical_acceptance_authority": false,
        "release_authority": false
    }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn runtime_surface_is_reachable_without_a_world() {
        let receipt = run_recovery_runtime_surface_preflight().unwrap();
        assert_eq!(receipt["ok"], true);
        assert_eq!(receipt["world_build_count"], 0);
        assert_eq!(receipt["solver_step_count"], 0);
        assert_eq!(receipt["stance_control_surface_implemented"], true);
        assert_eq!(receipt["prone_to_standing_claimed"], false);
    }

    #[test]
    fn runtime_binding_rejects_unqualified_digest_shapes() {
        assert!(rapier_recovery_runtime_binding_v1("not-a-digest").is_err());
    }
}
