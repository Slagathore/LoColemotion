//! Additive native source validation for controller-free passive entry.
//! Reuses the production runtime/capability/source-mapping kernel, not an
//! observation relabeled as matched-zero, failed, or canonical ConfirmProne.
use super::*;

pub const PASSIVE_COLLECTION_REQUEST_V1: &str =
    "sporespore_recovery_passive_native_collection_request_v1";
pub const PASSIVE_COLLECTION_RECEIPT_V1: &str =
    "sporespore_recovery_passive_native_collection_receipt_v1";

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryPassiveNativeCollectionRequestV1 {
    pub schema_version: String,
    pub task_id: String,
    pub semantics_id: String,
    pub actuator_profile_id: String,
    pub descriptor: BoundedQuadrupedDescriptor,
    pub morphology_context: RecoveryMorphologyContextV1,
    pub adapter_capability: RecoveryAdapterCapabilityV1,
    pub runtime_binding: RecoveryNativeCollectorBindingV1,
    pub arm_kind: RecoveryArmKindV1,
    pub observation_source_binding: RecoveryObservationV2SourceBindingV1,
    pub observation: RecoveryObservationV2,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryPassiveNativeCollectionReceiptV1 {
    pub schema_version: String,
    pub collection: RecoveryNativeCollectionReceiptV2,
    pub canonical_controller_step_executed: bool,
    pub physical_acceptance_authority: bool,
    pub release_authority: bool,
}

pub fn collect_passive_native_observation_v1(
    request: RecoveryPassiveNativeCollectionRequestV1,
) -> Result<RecoveryPassiveNativeCollectionReceiptV1> {
    if request.schema_version != PASSIVE_COLLECTION_REQUEST_V1
        || request.arm_kind != RecoveryArmKindV1::CandidateCommand
    {
        return Err(CoreError::Schema(
            "passive_native_collection_identity".to_owned(),
        ));
    }
    // Internal field carrier only. Its phase is not serialized and is ignored
    // by the explicit passive ownership scope. The original observation and
    // source-binding hashes are validated unchanged by the production kernel.
    let collection = collect_native_observation_v3_scoped(
        RecoveryNativeCollectionRequestV3 {
            schema_version: RECOVERY_NATIVE_COLLECTION_REQUEST_V3_VERSION.to_owned(),
            task_id: request.task_id,
            semantics_id: request.semantics_id,
            actuator_profile_id: request.actuator_profile_id,
            descriptor: request.descriptor,
            morphology_context: request.morphology_context,
            adapter_capability: request.adapter_capability,
            runtime_binding: request.runtime_binding,
            arm_kind: request.arm_kind,
            phase: RecoveryPhaseV1::ConfirmProne,
            observation_source_binding: request.observation_source_binding,
            observation: request.observation,
        },
        true,
    )?;
    Ok(RecoveryPassiveNativeCollectionReceiptV1 {
        schema_version: PASSIVE_COLLECTION_RECEIPT_V1.to_owned(),
        collection,
        canonical_controller_step_executed: false,
        physical_acceptance_authority: false,
        release_authority: false,
    })
}
