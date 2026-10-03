//! Synthetic native-shape/source-kernel canaries, not native engine evidence.
use super::*;
use crate::recovery_runtime::passive_entry_collection::*;

fn passive_request(engine: RecoveryNativeEngineV1) -> RecoveryPassiveNativeCollectionRequestV1 {
    let mut original = native_request_v3_for_phase(engine, RecoveryPhaseV1::ConfirmProne);
    let owner = &mut original.observation.controller_ownership;
    owner.owner = RecoveryControllerOwnerV1::None;
    owner.recovery_controller_id = None;
    owner.stance_controller_id = None;
    owner.handoff_event_count = 0;
    for motor in &mut original
        .observation
        .applied_actuation
        .ordered_applied_impulses
    {
        motor.applied_angular_impulse_nms = 0.0;
    }
    // Bind the NEW synthetic source, never edit a retained physical record.
    let source = &original.observation_source_binding;
    original.observation_source_binding = bind_recovery_observation_v2_source_v1(
        &original.observation,
        &original.adapter_capability.adapter_id,
        &source.source_route_id,
        &source.mapping_profile_id,
        SHA_A,
        SHA_B,
    )
    .unwrap();
    let mut value = serde_json::to_value(&original).unwrap();
    value["schema_version"] = json!(PASSIVE_COLLECTION_REQUEST_V1);
    value.as_object_mut().unwrap().remove("phase");
    serde_json::from_value(value).unwrap()
}

#[test]
fn passive_native_collection_preserves_candidate_and_exact_source_for_three_identities() {
    for engine in [
        RecoveryNativeEngineV1::GodotJolt4_7,
        RecoveryNativeEngineV1::RapierParryNative,
        RecoveryNativeEngineV1::MujocoNative,
    ] {
        let request = passive_request(engine);
        let receipt = collect_passive_native_observation_v1(request.clone()).unwrap();
        let collection = &receipt.collection;
        assert_eq!(
            collection.support_status,
            RecoverySupportStatusV1::SupportedExact
        );
        assert_eq!(collection.observation.as_ref(), Some(&request.observation));
        assert_eq!(
            collection.observation_source_binding.as_ref(),
            Some(&request.observation_source_binding)
        );
        assert_eq!(
            collection.observation_sha256.as_deref(),
            Some(digest_serializable(&request.observation).unwrap().as_str())
        );
        assert!(!request.observation.applied_actuation.zero_command);
        assert!(collection.supplied_native_post_step_observation_validated);
        assert!(!collection.native_runtime_observation_collection_executed);
        assert_eq!(collection.solver_step_count, 0);
        assert_eq!(collection.world_build_count, 0);
        assert!(!receipt.canonical_controller_step_executed);
        assert!(!receipt.physical_acceptance_authority);
        assert!(!receipt.release_authority);

        // The original canonical interface MUST still refuse this real shape.
        let mut old = serde_json::to_value(&request).unwrap();
        old["schema_version"] = json!(RECOVERY_NATIVE_COLLECTION_REQUEST_V3_VERSION);
        old["phase"] = json!("confirm_prone");
        let old_receipt =
            collect_native_recovery_observation_v3(serde_json::from_value(old).unwrap()).unwrap();
        assert_eq!(
            old_receipt.support_status,
            RecoverySupportStatusV1::InvalidObservation
        );
        assert_eq!(
            old_receipt.refusal_reason.as_deref(),
            Some("recovery_controller_ownership_invalid")
        );
    }
}

#[test]
fn passive_native_collection_refuses_ownership_actuation_and_source_drift() {
    let request = passive_request(RecoveryNativeEngineV1::GodotJolt4_7);
    for index in 0..12 {
        let mut bad = request.clone();
        match index {
            0 => bad.observation.controller_ownership.owner = RecoveryControllerOwnerV1::Recovery,
            1 => {
                bad.observation.controller_ownership.recovery_controller_id =
                    Some(EXACT_S169_RECOVERY_CONTROLLER_V6_ID.to_owned())
            }
            2 => {
                bad.observation.controller_ownership.stance_controller_id =
                    Some(EXACT_S169_STANCE_CONTROLLER_ID.to_owned())
            }
            3 => bad.observation.controller_ownership.handoff_event_count = 1,
            4 => bad.observation.controller_ownership.source_measurement = false,
            5 => {
                bad.observation
                    .controller_ownership
                    .fallback_controller_active = true
            }
            6 => {
                bad.observation.applied_actuation.ordered_applied_impulses[0]
                    .applied_angular_impulse_nms = 0.00001
            }
            7 => bad.observation.applied_actuation.zero_command = true,
            8 => bad.observation_source_binding.source_route_id = "unqualified".to_owned(),
            9 => bad.observation_source_binding.observation_base_sha256 = SHA_C.to_owned(),
            10 => bad.observation.energy_balance.current_mechanical_energy_j += 0.1,
            11 => bad.observation.engine_step_identity.host_step_after += 1,
            _ => unreachable!(),
        }
        let receipt = collect_passive_native_observation_v1(bad).unwrap();
        assert_ne!(
            receipt.collection.support_status,
            RecoverySupportStatusV1::SupportedExact,
            "mutation {index}"
        );
        assert!(receipt.collection.observation.is_none(), "mutation {index}");
        assert!(!receipt.canonical_controller_step_executed);
    }
    let mut wrong_arm = request.clone();
    wrong_arm.arm_kind = RecoveryArmKindV1::MatchedZeroCommand;
    assert!(collect_passive_native_observation_v1(wrong_arm).is_err());
    let mut with_phase = serde_json::to_value(request).unwrap();
    with_phase["phase"] = json!("failed");
    assert!(
        serde_json::from_value::<RecoveryPassiveNativeCollectionRequestV1>(with_phase).is_err()
    );
}

#[test]
fn passive_native_collection_public_json_preserves_valid_and_refused_receipts() {
    use crate::ffi::{SS_BUFFER_TOO_SMALL, SS_OK, ss_recovery_collect_passive_native_v1_json};
    for valid in [true, false] {
        let mut request = passive_request(RecoveryNativeEngineV1::GodotJolt4_7);
        if !valid {
            request
                .observation
                .controller_ownership
                .fallback_controller_active = true;
        }
        let expected =
            serde_json::to_value(collect_passive_native_observation_v1(request.clone()).unwrap())
                .unwrap();
        let input = serde_json::to_vec(&request).unwrap();
        let mut required = 0;
        let size_status = unsafe {
            ss_recovery_collect_passive_native_v1_json(
                input.as_ptr(),
                input.len(),
                std::ptr::null_mut(),
                0,
                &mut required,
            )
        };
        assert_eq!(size_status, SS_BUFFER_TOO_SMALL);
        let mut output = vec![0u8; required];
        let status = unsafe {
            ss_recovery_collect_passive_native_v1_json(
                input.as_ptr(),
                input.len(),
                output.as_mut_ptr(),
                output.len(),
                &mut required,
            )
        };
        assert_eq!(status, SS_OK);
        let value: serde_json::Value = serde_json::from_slice(&output[..required]).unwrap();
        assert_eq!(value["value"], expected);
        assert_eq!(
            value["value"]["collection"]["supplied_native_post_step_observation_validated"],
            valid
        );
    }
}
