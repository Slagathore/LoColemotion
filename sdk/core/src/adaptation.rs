use serde::{Deserialize, Serialize};
use serde_json::Value;

use crate::canonical::{canonical_json, digest_json, digest_serializable};
use crate::canonical_actuation::CanonicalVelocityActuationFrameV1;
use crate::protocol::{MotionCommand, StateFrame};
use crate::quadruped::{BoundedQuadrupedDescriptor, CompiledQuadruped};
use crate::schema::{CoreError, Result};

pub const ADAPTATION_PROVIDER_REQUEST_V1_VERSION: &str =
    "sporespore_adaptation_provider_request_v1";
pub const ADAPTATION_PROVIDER_RESPONSE_V1_VERSION: &str =
    "sporespore_adaptation_provider_response_v1";
pub const ADAPTATION_RESOLUTION_REQUEST_V1_VERSION: &str =
    "sporespore_adaptation_resolution_request_v1";
pub const ADAPTATION_RESOLUTION_RECEIPT_V1_VERSION: &str =
    "sporespore_adaptation_resolution_receipt_v1";
pub const ADAPTATION_PROVIDER_MEMORY_V1_VERSION: &str = "sporespore_adaptation_provider_memory_v1";
pub const ADAPTATION_HISTORY_V1_VERSION: &str = "sporespore_adaptation_history_v1";
pub const ADAPTATION_CONTROLLER_CONTEXT_V1_VERSION: &str =
    "sporespore_adaptation_controller_context_v1";
pub const ADAPTATION_SAFETY_ENVELOPE_V1_VERSION: &str = "sporespore_adaptation_safety_envelope_v1";
pub const ADAPTATION_CANDIDATE_EXPERIENCE_V1_VERSION: &str =
    "sporespore_adaptation_candidate_experience_v1";
pub const MAX_ADAPTATION_HISTORY_ENTRIES_V1: usize = 64;
pub const MAX_ADAPTATION_OPAQUE_MEMORY_BYTES_V1: usize = 65_536;

const EMPTY_STATE_DIGEST: &str =
    "sha256:44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a";

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AdaptationCorrectionKindV1 {
    CanonicalVelocityDeltaRadS,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AdaptationProviderStatusV1 {
    Applied,
    NoProposal,
    Refused,
    Unsupported,
    Uncertain,
    Reset,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AdaptationFallbackReasonV1 {
    None,
    ProviderAbsent,
    InvalidProviderResponse,
    RequestIdentityMismatch,
    ProviderNoProposal,
    ProviderRefused,
    ProviderUnsupported,
    ProviderUncertain,
    ProviderReset,
    ResetRequired,
    ConfidenceBelowMinimum,
    OutsideSupportedDomain,
    SafeNoActuation,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct AdaptationProposedCorrectionV1 {
    pub actuator_id: String,
    pub canonical_velocity_delta_rad_s: f64,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct AdaptationProviderMemoryV1 {
    pub schema_version: String,
    pub provider_id: String,
    pub reset_epoch: u64,
    pub sequence: u64,
    pub opaque_state: Value,
    pub opaque_state_sha256: String,
    pub weights_mutated: bool,
}

impl AdaptationProviderMemoryV1 {
    pub fn empty(provider_id: impl Into<String>, reset_epoch: u64) -> Self {
        Self {
            schema_version: ADAPTATION_PROVIDER_MEMORY_V1_VERSION.to_owned(),
            provider_id: provider_id.into(),
            reset_epoch,
            sequence: 0,
            opaque_state: serde_json::json!({}),
            opaque_state_sha256: EMPTY_STATE_DIGEST.to_owned(),
            weights_mutated: false,
        }
    }

    fn validate(&self, expected_provider_id: &str) -> Result<()> {
        if self.schema_version != ADAPTATION_PROVIDER_MEMORY_V1_VERSION {
            return Err(CoreError::Schema(
                "adaptation_provider_memory_version".to_owned(),
            ));
        }
        require_id(&self.provider_id, "adaptation_provider_memory.provider_id")?;
        if self.provider_id != expected_provider_id {
            return Err(CoreError::Identity(
                "adaptation_provider_memory.provider_id_mismatch".to_owned(),
            ));
        }
        require_digest(
            &self.opaque_state_sha256,
            "adaptation_provider_memory.opaque_state_sha256",
        )?;
        let canonical_state = canonical_json(&self.opaque_state)?;
        if canonical_state.len() > MAX_ADAPTATION_OPAQUE_MEMORY_BYTES_V1 {
            return Err(CoreError::Schema(
                "adaptation_provider_memory.opaque_state_too_large".to_owned(),
            ));
        }
        if digest_json(&self.opaque_state)? != self.opaque_state_sha256 {
            return Err(CoreError::Digest(
                "adaptation_provider_memory.opaque_state_mismatch".to_owned(),
            ));
        }
        if self.weights_mutated {
            return Err(CoreError::Actuation(
                "adaptation_provider_memory.weights_mutated".to_owned(),
            ));
        }
        Ok(())
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct AdaptationHistoryEntryV1 {
    pub semantic_step: u64,
    pub state: StateFrame,
    pub command: MotionCommand,
    pub deterministic_baseline: CanonicalVelocityActuationFrameV1,
    pub ordered_applied_corrections: Vec<AdaptationProposedCorrectionV1>,
    pub request_sha256: String,
    pub resolution_receipt_sha256: String,
    pub provider_status: AdaptationProviderStatusV1,
    pub adaptation_applied: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct AdaptationHistoryV1 {
    pub schema_version: String,
    pub ordered_entries: Vec<AdaptationHistoryEntryV1>,
}

impl AdaptationHistoryV1 {
    pub fn empty() -> Self {
        Self {
            schema_version: ADAPTATION_HISTORY_V1_VERSION.to_owned(),
            ordered_entries: Vec::new(),
        }
    }

    fn validate(&self, compiled: &CompiledQuadruped, current_step: u64) -> Result<()> {
        if self.schema_version != ADAPTATION_HISTORY_V1_VERSION {
            return Err(CoreError::Schema("adaptation_history_version".to_owned()));
        }
        if self.ordered_entries.len() > MAX_ADAPTATION_HISTORY_ENTRIES_V1 {
            return Err(CoreError::Schema("adaptation_history_too_long".to_owned()));
        }
        let mut previous_step = None;
        for entry in &self.ordered_entries {
            if entry.semantic_step >= current_step
                || previous_step.is_some_and(|previous| entry.semantic_step <= previous)
            {
                return Err(CoreError::Time("adaptation_history_step_order".to_owned()));
            }
            require_digest(&entry.request_sha256, "adaptation_history.request_sha256")?;
            require_digest(
                &entry.resolution_receipt_sha256,
                "adaptation_history.resolution_receipt_sha256",
            )?;
            entry.state.validate(&compiled.morphology)?;
            entry.command.validate_for_step(entry.semantic_step)?;
            entry
                .deterministic_baseline
                .validate(&compiled.morphology)?;
            if entry.state.semantic_step != entry.semantic_step
                || entry.deterministic_baseline.semantic_step != entry.semantic_step
            {
                return Err(CoreError::Time(
                    "adaptation_history_payload_step_mismatch".to_owned(),
                ));
            }
            require_order(
                entry
                    .ordered_applied_corrections
                    .iter()
                    .map(|correction| correction.actuator_id.as_str()),
                &compiled.morphology.ordered_actuator_ids,
                "adaptation_history.applied_corrections",
            )?;
            for correction in &entry.ordered_applied_corrections {
                require_finite(
                    correction.canonical_velocity_delta_rad_s,
                    "adaptation_history.applied_correction",
                )?;
                if !entry.adaptation_applied && correction.canonical_velocity_delta_rad_s != 0.0 {
                    return Err(CoreError::Actuation(format!(
                        "adaptation_history_fallback_has_correction:{}",
                        correction.actuator_id
                    )));
                }
            }
            if entry.adaptation_applied
                != (entry.provider_status == AdaptationProviderStatusV1::Applied)
            {
                return Err(CoreError::Schema(
                    "adaptation_history_applied_status".to_owned(),
                ));
            }
            previous_step = Some(entry.semantic_step);
        }
        Ok(())
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct AdaptationActuatorLimitV1 {
    pub actuator_id: String,
    pub maximum_absolute_correction_rad_s: f64,
    pub maximum_slew_per_step_rad_s: f64,
    pub previous_applied_correction_rad_s: f64,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct AdaptationSafetyEnvelopeV1 {
    pub schema_version: String,
    pub correction_kind: AdaptationCorrectionKindV1,
    pub minimum_confidence: f64,
    pub maximum_support_distance: f64,
    pub ordered_actuator_limits: Vec<AdaptationActuatorLimitV1>,
    pub deterministic_baseline_fallback_required: bool,
    pub engine_specific_output_allowed: bool,
    pub direct_world_access_allowed: bool,
    pub safety_limit_override_allowed: bool,
    pub physical_acceptance_authority: bool,
}

impl AdaptationSafetyEnvelopeV1 {
    fn validate(&self, compiled: &CompiledQuadruped) -> Result<()> {
        if self.schema_version != ADAPTATION_SAFETY_ENVELOPE_V1_VERSION {
            return Err(CoreError::Schema(
                "adaptation_safety_envelope_version".to_owned(),
            ));
        }
        require_unit_interval(self.minimum_confidence, "adaptation.minimum_confidence")?;
        require_nonnegative_finite(
            self.maximum_support_distance,
            "adaptation.maximum_support_distance",
        )?;
        if !self.deterministic_baseline_fallback_required
            || self.engine_specific_output_allowed
            || self.direct_world_access_allowed
            || self.safety_limit_override_allowed
            || self.physical_acceptance_authority
        {
            return Err(CoreError::Actuation(
                "adaptation_safety_envelope_authority".to_owned(),
            ));
        }
        require_order(
            self.ordered_actuator_limits
                .iter()
                .map(|limit| limit.actuator_id.as_str()),
            &compiled.morphology.ordered_actuator_ids,
            "adaptation_safety_envelope.actuators",
        )?;
        for limit in &self.ordered_actuator_limits {
            require_nonnegative_finite(
                limit.maximum_absolute_correction_rad_s,
                "adaptation.maximum_absolute_correction_rad_s",
            )?;
            require_nonnegative_finite(
                limit.maximum_slew_per_step_rad_s,
                "adaptation.maximum_slew_per_step_rad_s",
            )?;
            require_finite(
                limit.previous_applied_correction_rad_s,
                "adaptation.previous_applied_correction_rad_s",
            )?;
            if limit.previous_applied_correction_rad_s.abs()
                > limit.maximum_absolute_correction_rad_s + 1.0e-12
            {
                return Err(CoreError::Actuation(format!(
                    "adaptation_previous_correction_out_of_bounds:{}",
                    limit.actuator_id
                )));
            }
        }
        Ok(())
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct AdaptationControllerContextV1 {
    pub schema_version: String,
    pub source_policy_id: String,
    pub skill_id: String,
    pub phase_id: Option<String>,
    pub controller_memory_schema_version: String,
    pub controller_memory: Value,
    pub controller_memory_sha256: String,
    pub engine_specific: bool,
    pub physical_acceptance_authority: bool,
}

impl AdaptationControllerContextV1 {
    fn validate(&self, baseline: &CanonicalVelocityActuationFrameV1) -> Result<()> {
        if self.schema_version != ADAPTATION_CONTROLLER_CONTEXT_V1_VERSION {
            return Err(CoreError::Schema(
                "adaptation_controller_context_version".to_owned(),
            ));
        }
        require_id(
            &self.source_policy_id,
            "adaptation_controller_context.source_policy_id",
        )?;
        require_id(&self.skill_id, "adaptation_controller_context.skill_id")?;
        if let Some(phase_id) = &self.phase_id {
            require_id(phase_id, "adaptation_controller_context.phase_id")?;
        }
        require_id(
            &self.controller_memory_schema_version,
            "adaptation_controller_context.controller_memory_schema_version",
        )?;
        require_digest(
            &self.controller_memory_sha256,
            "adaptation_controller_context.controller_memory_sha256",
        )?;
        if self.source_policy_id != baseline.source_policy_id {
            return Err(CoreError::Identity(
                "adaptation_controller_context.policy_mismatch".to_owned(),
            ));
        }
        let memory = self.controller_memory.as_object().ok_or_else(|| {
            CoreError::Schema("adaptation_controller_context.memory_not_object".to_owned())
        })?;
        if memory.get("schema_version").and_then(Value::as_str)
            != Some(self.controller_memory_schema_version.as_str())
        {
            return Err(CoreError::Schema(
                "adaptation_controller_context.memory_version_mismatch".to_owned(),
            ));
        }
        if canonical_json(&self.controller_memory)?.len() > MAX_ADAPTATION_OPAQUE_MEMORY_BYTES_V1 {
            return Err(CoreError::Schema(
                "adaptation_controller_context.memory_too_large".to_owned(),
            ));
        }
        if digest_json(&self.controller_memory)? != self.controller_memory_sha256 {
            return Err(CoreError::Digest(
                "adaptation_controller_context.memory_digest_mismatch".to_owned(),
            ));
        }
        if self.engine_specific || self.physical_acceptance_authority {
            return Err(CoreError::Actuation(
                "adaptation_controller_context.authority".to_owned(),
            ));
        }
        Ok(())
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct AdaptationProviderRequestV1 {
    pub schema_version: String,
    pub request_id: String,
    pub provider_id: String,
    pub expected_provider_version: String,
    pub expected_model_id: String,
    pub expected_model_sha256: String,
    pub expected_training_corpus_id: String,
    pub expected_training_corpus_sha256: String,
    pub descriptor: BoundedQuadrupedDescriptor,
    pub state: StateFrame,
    pub command: MotionCommand,
    pub deterministic_baseline: CanonicalVelocityActuationFrameV1,
    pub controller_context: AdaptationControllerContextV1,
    pub history: AdaptationHistoryV1,
    pub provider_memory: AdaptationProviderMemoryV1,
    pub safety_envelope: AdaptationSafetyEnvelopeV1,
    pub seed: u64,
    pub provider_may_build_worlds: bool,
    pub provider_may_modify_physics_state: bool,
    pub provider_has_physical_acceptance_authority: bool,
}

impl AdaptationProviderRequestV1 {
    fn validate(&self, compiled: &CompiledQuadruped) -> Result<()> {
        if self.schema_version != ADAPTATION_PROVIDER_REQUEST_V1_VERSION {
            return Err(CoreError::Schema(
                "adaptation_provider_request_version".to_owned(),
            ));
        }
        require_id(&self.request_id, "adaptation_provider_request.request_id")?;
        require_id(&self.provider_id, "adaptation_provider_request.provider_id")?;
        require_id(
            &self.expected_provider_version,
            "adaptation_provider_request.expected_provider_version",
        )?;
        require_id(
            &self.expected_model_id,
            "adaptation_provider_request.expected_model_id",
        )?;
        require_digest(
            &self.expected_model_sha256,
            "adaptation_provider_request.expected_model_sha256",
        )?;
        require_id(
            &self.expected_training_corpus_id,
            "adaptation_provider_request.expected_training_corpus_id",
        )?;
        require_digest(
            &self.expected_training_corpus_sha256,
            "adaptation_provider_request.expected_training_corpus_sha256",
        )?;
        if self.descriptor != compiled.descriptor {
            return Err(CoreError::Identity(
                "adaptation_provider_request.descriptor_mismatch".to_owned(),
            ));
        }
        self.state.validate(&compiled.morphology)?;
        self.command.validate_for_step(self.state.semantic_step)?;
        self.deterministic_baseline.validate(&compiled.morphology)?;
        if self.deterministic_baseline.semantic_step != self.state.semantic_step {
            return Err(CoreError::Time(
                "adaptation_baseline_state_step_mismatch".to_owned(),
            ));
        }
        self.controller_context
            .validate(&self.deterministic_baseline)?;
        self.history.validate(compiled, self.state.semantic_step)?;
        self.provider_memory.validate(&self.provider_id)?;
        self.safety_envelope.validate(compiled)?;
        if self.provider_may_build_worlds
            || self.provider_may_modify_physics_state
            || self.provider_has_physical_acceptance_authority
        {
            return Err(CoreError::Actuation(
                "adaptation_provider_request_authority".to_owned(),
            ));
        }
        Ok(())
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct AdaptationProviderProvenanceV1 {
    pub provider_id: String,
    pub provider_version: String,
    pub model_id: String,
    pub model_sha256: String,
    pub training_corpus_id: String,
    pub training_corpus_sha256: String,
    pub seed: u64,
    pub engine_specific_logic_used: bool,
    pub direct_world_access_used: bool,
    pub weights_mutated: bool,
    pub physical_acceptance_authority: bool,
}

impl AdaptationProviderProvenanceV1 {
    fn validate(&self, request: &AdaptationProviderRequestV1) -> Result<()> {
        require_id(&self.provider_id, "adaptation_provenance.provider_id")?;
        require_id(
            &self.provider_version,
            "adaptation_provenance.provider_version",
        )?;
        require_id(&self.model_id, "adaptation_provenance.model_id")?;
        require_digest(&self.model_sha256, "adaptation_provenance.model_sha256")?;
        require_id(
            &self.training_corpus_id,
            "adaptation_provenance.training_corpus_id",
        )?;
        require_digest(
            &self.training_corpus_sha256,
            "adaptation_provenance.training_corpus_sha256",
        )?;
        if self.provider_id != request.provider_id
            || self.provider_version != request.expected_provider_version
            || self.model_id != request.expected_model_id
            || self.model_sha256 != request.expected_model_sha256
            || self.training_corpus_id != request.expected_training_corpus_id
            || self.training_corpus_sha256 != request.expected_training_corpus_sha256
            || self.seed != request.seed
        {
            return Err(CoreError::Identity(
                "adaptation_provenance_request_mismatch".to_owned(),
            ));
        }
        if self.engine_specific_logic_used
            || self.direct_world_access_used
            || self.weights_mutated
            || self.physical_acceptance_authority
        {
            return Err(CoreError::Actuation(
                "adaptation_provenance_forbidden_authority".to_owned(),
            ));
        }
        Ok(())
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct AdaptationCandidateExperienceV1 {
    pub schema_version: String,
    pub candidate_event_id: String,
    pub lesson_family_id: String,
    pub candidate_only: bool,
    pub encyclopedia_promotion_authority: bool,
    pub physical_acceptance_authority: bool,
}

impl AdaptationCandidateExperienceV1 {
    fn validate(&self) -> Result<()> {
        if self.schema_version != ADAPTATION_CANDIDATE_EXPERIENCE_V1_VERSION {
            return Err(CoreError::Schema(
                "adaptation_candidate_experience_version".to_owned(),
            ));
        }
        require_id(
            &self.candidate_event_id,
            "adaptation_candidate_experience.candidate_event_id",
        )?;
        require_id(
            &self.lesson_family_id,
            "adaptation_candidate_experience.lesson_family_id",
        )?;
        if !self.candidate_only
            || self.encyclopedia_promotion_authority
            || self.physical_acceptance_authority
        {
            return Err(CoreError::Actuation(
                "adaptation_candidate_experience_authority".to_owned(),
            ));
        }
        Ok(())
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct AdaptationProviderResponseV1 {
    pub schema_version: String,
    pub request_id: String,
    pub request_sha256: String,
    pub status: AdaptationProviderStatusV1,
    pub confidence: f64,
    pub support_distance: f64,
    pub ordered_corrections: Vec<AdaptationProposedCorrectionV1>,
    pub next_memory: AdaptationProviderMemoryV1,
    pub provenance: AdaptationProviderProvenanceV1,
    pub candidate_experience: Option<AdaptationCandidateExperienceV1>,
    pub diagnostics: Vec<String>,
    pub physical_acceptance_authority: bool,
}

impl AdaptationProviderResponseV1 {
    fn validate(
        &self,
        request: &AdaptationProviderRequestV1,
        request_sha256: &str,
        compiled: &CompiledQuadruped,
    ) -> Result<()> {
        if self.schema_version != ADAPTATION_PROVIDER_RESPONSE_V1_VERSION {
            return Err(CoreError::Schema(
                "adaptation_provider_response_version".to_owned(),
            ));
        }
        require_id(&self.request_id, "adaptation_provider_response.request_id")?;
        require_digest(
            &self.request_sha256,
            "adaptation_provider_response.request_sha256",
        )?;
        if self.request_id != request.request_id || self.request_sha256 != request_sha256 {
            return Err(CoreError::Identity(
                "adaptation_provider_response.request_identity".to_owned(),
            ));
        }
        require_unit_interval(self.confidence, "adaptation_provider_response.confidence")?;
        require_nonnegative_finite(
            self.support_distance,
            "adaptation_provider_response.support_distance",
        )?;
        self.provenance.validate(request)?;
        self.next_memory.validate(&request.provider_id)?;
        if self.physical_acceptance_authority {
            return Err(CoreError::Actuation(
                "adaptation_provider_response_authority".to_owned(),
            ));
        }
        if self.diagnostics.len() > 64
            || self
                .diagnostics
                .iter()
                .any(|diagnostic| diagnostic.is_empty() || diagnostic.len() > 256)
        {
            return Err(CoreError::Schema(
                "adaptation_provider_response_diagnostics".to_owned(),
            ));
        }
        if let Some(candidate) = &self.candidate_experience {
            candidate.validate()?;
        }

        if self.status == AdaptationProviderStatusV1::Applied {
            require_order(
                self.ordered_corrections
                    .iter()
                    .map(|correction| correction.actuator_id.as_str()),
                &compiled.morphology.ordered_actuator_ids,
                "adaptation_provider_response.corrections",
            )?;
            for correction in &self.ordered_corrections {
                require_finite(
                    correction.canonical_velocity_delta_rad_s,
                    "adaptation_provider_response.correction",
                )?;
            }
        } else if !self.ordered_corrections.is_empty() {
            return Err(CoreError::Actuation(
                "adaptation_non_applied_response_has_corrections".to_owned(),
            ));
        }

        match self.status {
            AdaptationProviderStatusV1::Reset => {
                if request.provider_memory.reset_epoch.checked_add(1)
                    != Some(self.next_memory.reset_epoch)
                    || self.next_memory.sequence != 0
                    || self.next_memory.opaque_state_sha256 != EMPTY_STATE_DIGEST
                {
                    return Err(CoreError::Schema(
                        "adaptation_reset_memory_transition".to_owned(),
                    ));
                }
            }
            _ => {
                if self.next_memory.reset_epoch != request.provider_memory.reset_epoch
                    || request.provider_memory.sequence.checked_add(1)
                        != Some(self.next_memory.sequence)
                {
                    return Err(CoreError::Schema(
                        "adaptation_memory_sequence_transition".to_owned(),
                    ));
                }
            }
        }
        Ok(())
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct AdaptationResolutionRequestV1 {
    pub schema_version: String,
    pub provider_request: AdaptationProviderRequestV1,
    pub provider_response: Option<Value>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct AdaptationResolvedActuatorCommandV1 {
    pub actuator_id: String,
    pub baseline_canonical_target_velocity_rad_s: f64,
    pub proposed_correction_rad_s: f64,
    pub applied_correction_rad_s: f64,
    pub final_canonical_target_velocity_rad_s: f64,
    pub maximum_target_speed_rad_s: f64,
    pub absolute_correction_clamped: bool,
    pub slew_clamped: bool,
    pub final_speed_clamped: bool,
    pub valid_through_step: u64,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct AdaptationResolutionReceiptV1 {
    pub schema_version: String,
    pub request_id: String,
    pub request_sha256: String,
    pub provider_response_sha256: Option<String>,
    pub provider_status: Option<AdaptationProviderStatusV1>,
    pub fallback_reason: AdaptationFallbackReasonV1,
    pub deterministic_baseline_fallback_used: bool,
    pub adaptation_applied: bool,
    pub confidence: Option<f64>,
    pub support_distance: Option<f64>,
    pub provider_id: String,
    pub provider_version: Option<String>,
    pub model_id: Option<String>,
    pub model_sha256: Option<String>,
    pub ordered_commands: Vec<AdaptationResolvedActuatorCommandV1>,
    pub next_memory: AdaptationProviderMemoryV1,
    pub candidate_experience: Option<AdaptationCandidateExperienceV1>,
    pub safe_no_actuation: bool,
    pub canonical_to_host_mapping_owned_by_adapter: bool,
    pub deterministic: bool,
    pub world_build_count: u32,
    pub physics_state_modified: bool,
    pub physical_acceptance_authority: bool,
}

pub fn resolve_adaptation_v1(
    compiled: &CompiledQuadruped,
    resolution: &AdaptationResolutionRequestV1,
) -> Result<AdaptationResolutionReceiptV1> {
    if resolution.schema_version != ADAPTATION_RESOLUTION_REQUEST_V1_VERSION {
        return Err(CoreError::Schema(
            "adaptation_resolution_request_version".to_owned(),
        ));
    }
    let request = &resolution.provider_request;
    request.validate(compiled)?;
    let request_sha256 = digest_serializable(request)?;
    let raw_response_sha256 = resolution
        .provider_response
        .as_ref()
        .map(response_digest)
        .transpose()?;

    let parsed_response = resolution.provider_response.as_ref().and_then(|value| {
        serde_json::from_value::<AdaptationProviderResponseV1>(value.clone()).ok()
    });
    let response_validation = parsed_response
        .as_ref()
        .map(|response| response.validate(request, &request_sha256, compiled));
    let valid_response = match response_validation {
        Some(Ok(())) => parsed_response.as_ref(),
        _ => None,
    };

    let mut fallback_reason = if resolution.provider_response.is_none() {
        AdaptationFallbackReasonV1::ProviderAbsent
    } else if let Some(response) = parsed_response.as_ref() {
        if response.request_id != request.request_id || response.request_sha256 != request_sha256 {
            AdaptationFallbackReasonV1::RequestIdentityMismatch
        } else if valid_response.is_none() {
            AdaptationFallbackReasonV1::InvalidProviderResponse
        } else {
            status_fallback_reason(response.status)
        }
    } else {
        AdaptationFallbackReasonV1::InvalidProviderResponse
    };

    if let Some(response) = valid_response
        && response.status == AdaptationProviderStatusV1::Applied
    {
        if request.deterministic_baseline.safe_no_actuation {
            fallback_reason = AdaptationFallbackReasonV1::SafeNoActuation;
        } else if response.confidence < request.safety_envelope.minimum_confidence {
            fallback_reason = AdaptationFallbackReasonV1::ConfidenceBelowMinimum;
        } else if response.support_distance > request.safety_envelope.maximum_support_distance {
            fallback_reason = AdaptationFallbackReasonV1::OutsideSupportedDomain;
        } else {
            fallback_reason = AdaptationFallbackReasonV1::None;
        }
    }

    let adaptation_applied = fallback_reason == AdaptationFallbackReasonV1::None;
    let corrections: &[AdaptationProposedCorrectionV1] = match valid_response {
        Some(response) if adaptation_applied => &response.ordered_corrections,
        _ => &[],
    };

    let ordered_commands = request
        .deterministic_baseline
        .ordered_commands
        .iter()
        .zip(&request.safety_envelope.ordered_actuator_limits)
        .enumerate()
        .map(|(index, (baseline, limit))| {
            let proposed = corrections
                .get(index)
                .map_or(0.0, |correction| correction.canonical_velocity_delta_rad_s);
            let (applied, absolute_clamped, slew_clamped) = if adaptation_applied {
                let absolute_bounded = proposed.clamp(
                    -limit.maximum_absolute_correction_rad_s,
                    limit.maximum_absolute_correction_rad_s,
                );
                let slew_min =
                    limit.previous_applied_correction_rad_s - limit.maximum_slew_per_step_rad_s;
                let slew_max =
                    limit.previous_applied_correction_rad_s + limit.maximum_slew_per_step_rad_s;
                let applied = absolute_bounded.clamp(slew_min, slew_max).clamp(
                    -limit.maximum_absolute_correction_rad_s,
                    limit.maximum_absolute_correction_rad_s,
                );
                (
                    applied,
                    proposed != absolute_bounded,
                    absolute_bounded != applied,
                )
            } else {
                // Fallback returns immediately to the deterministic
                // baseline. A previous provider correction is history,
                // not authority to slew through the fallback path.
                (0.0, false, false)
            };
            let unbounded_final = baseline.combined_canonical_target_velocity_rad_s + applied;
            let final_velocity = unbounded_final.clamp(
                -baseline.maximum_target_speed_rad_s,
                baseline.maximum_target_speed_rad_s,
            );
            AdaptationResolvedActuatorCommandV1 {
                actuator_id: baseline.actuator_id.clone(),
                baseline_canonical_target_velocity_rad_s: baseline
                    .combined_canonical_target_velocity_rad_s,
                proposed_correction_rad_s: proposed,
                applied_correction_rad_s: applied,
                final_canonical_target_velocity_rad_s: final_velocity,
                maximum_target_speed_rad_s: baseline.maximum_target_speed_rad_s,
                absolute_correction_clamped: absolute_clamped,
                slew_clamped,
                final_speed_clamped: unbounded_final != final_velocity,
                valid_through_step: baseline.valid_through_step,
            }
        })
        .collect();

    let response = valid_response;
    let next_memory = response.map_or_else(
        || request.provider_memory.clone(),
        |response| response.next_memory.clone(),
    );
    Ok(AdaptationResolutionReceiptV1 {
        schema_version: ADAPTATION_RESOLUTION_RECEIPT_V1_VERSION.to_owned(),
        request_id: request.request_id.clone(),
        request_sha256,
        provider_response_sha256: raw_response_sha256,
        provider_status: response.map(|response| response.status),
        fallback_reason,
        deterministic_baseline_fallback_used: !adaptation_applied,
        adaptation_applied,
        confidence: response.map(|response| response.confidence),
        support_distance: response.map(|response| response.support_distance),
        provider_id: request.provider_id.clone(),
        provider_version: response.map(|response| response.provenance.provider_version.clone()),
        model_id: response.map(|response| response.provenance.model_id.clone()),
        model_sha256: response.map(|response| response.provenance.model_sha256.clone()),
        ordered_commands,
        next_memory,
        candidate_experience: response.and_then(|response| response.candidate_experience.clone()),
        safe_no_actuation: request.deterministic_baseline.safe_no_actuation,
        canonical_to_host_mapping_owned_by_adapter: true,
        deterministic: true,
        world_build_count: 0,
        physics_state_modified: false,
        physical_acceptance_authority: false,
    })
}

fn status_fallback_reason(status: AdaptationProviderStatusV1) -> AdaptationFallbackReasonV1 {
    match status {
        AdaptationProviderStatusV1::Applied => AdaptationFallbackReasonV1::None,
        AdaptationProviderStatusV1::NoProposal => AdaptationFallbackReasonV1::ProviderNoProposal,
        AdaptationProviderStatusV1::Refused => AdaptationFallbackReasonV1::ProviderRefused,
        AdaptationProviderStatusV1::Unsupported => AdaptationFallbackReasonV1::ProviderUnsupported,
        AdaptationProviderStatusV1::Uncertain => AdaptationFallbackReasonV1::ProviderUncertain,
        AdaptationProviderStatusV1::Reset => AdaptationFallbackReasonV1::ProviderReset,
    }
}

fn response_digest(value: &Value) -> Result<String> {
    digest_json(value).or_else(|_| digest_serializable(&value.to_string()))
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
        Err(CoreError::Schema(format!("{field}_negative")))
    } else {
        Ok(())
    }
}

fn require_unit_interval(value: f64, field: &str) -> Result<()> {
    require_finite(value, field)?;
    if (0.0..=1.0).contains(&value) {
        Ok(())
    } else {
        Err(CoreError::Schema(format!("{field}_out_of_range")))
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

fn require_digest(value: &str, field: &str) -> Result<()> {
    let digest = value.strip_prefix("sha256:").unwrap_or(value);
    if digest.len() == 64 && digest.bytes().all(|byte| byte.is_ascii_hexdigit()) {
        Ok(())
    } else {
        Err(CoreError::Digest(field.to_owned()))
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
    use crate::canonical_actuation::{
        CanonicalVelocityResidualV1, canonicalize_and_compose_legacy_velocity_v1,
    };
    use crate::controller::BALANCED_WAVE_BW15F_B_POLICY_ID;
    use crate::protocol::{
        CommandAuthority, ContactObservation, ContactProvenance, ContactQuality, JointObservation,
        JointValidityMask, MOTION_COMMAND_VERSION, PhaseProgressionMode, Pose, Quaternion,
        STATE_FRAME_VERSION, SpeedClass, TaskFrame, Twist,
    };
    use crate::quadruped::{BoundedQuadrupedDescriptor, compile_bounded_quadruped};
    use crate::runtime::{BalancedWaveController, BalancedWaveControllerMemory};
    use crate::schema::{CompiledMorphology, Vec3};

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
                        adapter_id: "adaptation_test".to_owned(),
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

    fn command() -> MotionCommand {
        MotionCommand {
            schema_version: MOTION_COMMAND_VERSION.to_owned(),
            command_id: "adaptation_test".to_owned(),
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

    fn fixture() -> (CompiledQuadruped, AdaptationResolutionRequestV1) {
        let compiled =
            compile_bounded_quadruped(BoundedQuadrupedDescriptor::reference("adaptation_test"))
                .unwrap();
        let fixture_state = state(&compiled.morphology);
        let fixture_command = command();
        let controller = BalancedWaveController::new_for_policy(
            compiled.clone(),
            BALANCED_WAVE_BW15F_B_POLICY_ID,
        )
        .unwrap();
        let output = controller.step(
            &BalancedWaveControllerMemory::initial(),
            &fixture_state,
            &fixture_command,
        );
        assert!(!output.actuation.safe_no_actuation);
        let residuals = output
            .actuation
            .ordered_commands
            .iter()
            .map(|item| CanonicalVelocityResidualV1::exact_zero(&item.actuator_id))
            .collect::<Vec<_>>();
        let baseline = canonicalize_and_compose_legacy_velocity_v1(
            &compiled.morphology,
            &output.actuation,
            &residuals,
        )
        .unwrap();
        let controller_memory = serde_json::to_value(&output.next_memory).unwrap();
        let controller_memory_sha256 = digest_json(&controller_memory).unwrap();
        let limits = compiled
            .morphology
            .ordered_actuator_ids
            .iter()
            .map(|actuator_id| AdaptationActuatorLimitV1 {
                actuator_id: actuator_id.clone(),
                maximum_absolute_correction_rad_s: 0.5,
                maximum_slew_per_step_rad_s: 0.2,
                previous_applied_correction_rad_s: 0.0,
            })
            .collect();
        let request = AdaptationProviderRequestV1 {
            schema_version: ADAPTATION_PROVIDER_REQUEST_V1_VERSION.to_owned(),
            request_id: "adaptation_request".to_owned(),
            provider_id: "fixture_provider".to_owned(),
            expected_provider_version: "fixture_provider_v1".to_owned(),
            expected_model_id: "fixture_model".to_owned(),
            expected_model_sha256:
                "sha256:3333333333333333333333333333333333333333333333333333333333333333".to_owned(),
            expected_training_corpus_id: "fixture_corpus".to_owned(),
            expected_training_corpus_sha256:
                "sha256:4444444444444444444444444444444444444444444444444444444444444444".to_owned(),
            descriptor: compiled.descriptor.clone(),
            state: fixture_state,
            command: fixture_command,
            deterministic_baseline: baseline,
            controller_context: AdaptationControllerContextV1 {
                schema_version: ADAPTATION_CONTROLLER_CONTEXT_V1_VERSION.to_owned(),
                source_policy_id: BALANCED_WAVE_BW15F_B_POLICY_ID.to_owned(),
                skill_id: "bounded_walk".to_owned(),
                phase_id: None,
                controller_memory_schema_version: output.next_memory.schema_version.clone(),
                controller_memory,
                controller_memory_sha256,
                engine_specific: false,
                physical_acceptance_authority: false,
            },
            history: AdaptationHistoryV1::empty(),
            provider_memory: AdaptationProviderMemoryV1::empty("fixture_provider", 0),
            safety_envelope: AdaptationSafetyEnvelopeV1 {
                schema_version: ADAPTATION_SAFETY_ENVELOPE_V1_VERSION.to_owned(),
                correction_kind: AdaptationCorrectionKindV1::CanonicalVelocityDeltaRadS,
                minimum_confidence: 0.8,
                maximum_support_distance: 1.0,
                ordered_actuator_limits: limits,
                deterministic_baseline_fallback_required: true,
                engine_specific_output_allowed: false,
                direct_world_access_allowed: false,
                safety_limit_override_allowed: false,
                physical_acceptance_authority: false,
            },
            seed: 42,
            provider_may_build_worlds: false,
            provider_may_modify_physics_state: false,
            provider_has_physical_acceptance_authority: false,
        };
        (
            compiled,
            AdaptationResolutionRequestV1 {
                schema_version: ADAPTATION_RESOLUTION_REQUEST_V1_VERSION.to_owned(),
                provider_request: request,
                provider_response: None,
            },
        )
    }

    fn response(
        resolution: &AdaptationResolutionRequestV1,
        status: AdaptationProviderStatusV1,
        confidence: f64,
        support_distance: f64,
    ) -> AdaptationProviderResponseV1 {
        let request = &resolution.provider_request;
        let corrections = if status == AdaptationProviderStatusV1::Applied {
            request
                .deterministic_baseline
                .ordered_commands
                .iter()
                .map(|command| AdaptationProposedCorrectionV1 {
                    actuator_id: command.actuator_id.clone(),
                    canonical_velocity_delta_rad_s: 0.4,
                })
                .collect()
        } else {
            Vec::new()
        };
        AdaptationProviderResponseV1 {
            schema_version: ADAPTATION_PROVIDER_RESPONSE_V1_VERSION.to_owned(),
            request_id: request.request_id.clone(),
            request_sha256: digest_serializable(request).unwrap(),
            status,
            confidence,
            support_distance,
            ordered_corrections: corrections,
            next_memory: AdaptationProviderMemoryV1 {
                schema_version: ADAPTATION_PROVIDER_MEMORY_V1_VERSION.to_owned(),
                provider_id: request.provider_id.clone(),
                reset_epoch: request.provider_memory.reset_epoch,
                sequence: request.provider_memory.sequence + 1,
                opaque_state: serde_json::json!({"fixture_sequence": 1}),
                opaque_state_sha256: digest_json(&serde_json::json!({
                    "fixture_sequence": 1
                }))
                .unwrap(),
                weights_mutated: false,
            },
            provenance: AdaptationProviderProvenanceV1 {
                provider_id: request.provider_id.clone(),
                provider_version: "fixture_provider_v1".to_owned(),
                model_id: "fixture_model".to_owned(),
                model_sha256:
                    "sha256:3333333333333333333333333333333333333333333333333333333333333333"
                        .to_owned(),
                training_corpus_id: "fixture_corpus".to_owned(),
                training_corpus_sha256:
                    "sha256:4444444444444444444444444444444444444444444444444444444444444444"
                        .to_owned(),
                seed: request.seed,
                engine_specific_logic_used: false,
                direct_world_access_used: false,
                weights_mutated: false,
                physical_acceptance_authority: false,
            },
            candidate_experience: None,
            diagnostics: vec!["fixture".to_owned()],
            physical_acceptance_authority: false,
        }
    }

    #[test]
    fn absent_provider_is_exact_deterministic_baseline() {
        let (compiled, mut resolution) = fixture();
        for limit in &mut resolution
            .provider_request
            .safety_envelope
            .ordered_actuator_limits
        {
            limit.previous_applied_correction_rad_s = 0.4;
        }
        let receipt = resolve_adaptation_v1(&compiled, &resolution).unwrap();
        assert_eq!(
            receipt.fallback_reason,
            AdaptationFallbackReasonV1::ProviderAbsent
        );
        assert!(receipt.deterministic_baseline_fallback_used);
        assert!(!receipt.adaptation_applied);
        for (resolved, baseline) in receipt.ordered_commands.iter().zip(
            &resolution
                .provider_request
                .deterministic_baseline
                .ordered_commands,
        ) {
            assert_eq!(
                resolved.final_canonical_target_velocity_rad_s.to_bits(),
                baseline.combined_canonical_target_velocity_rad_s.to_bits()
            );
            assert_eq!(
                resolved.applied_correction_rad_s.to_bits(),
                0.0_f64.to_bits()
            );
        }
        assert_eq!(receipt.world_build_count, 0);
        assert!(!receipt.physics_state_modified);
        assert!(!receipt.physical_acceptance_authority);
    }

    #[test]
    fn applied_provider_correction_is_absolute_slew_and_speed_bounded() {
        let (compiled, mut resolution) = fixture();
        resolution.provider_response = Some(
            serde_json::to_value(response(
                &resolution,
                AdaptationProviderStatusV1::Applied,
                0.95,
                0.2,
            ))
            .unwrap(),
        );
        let receipt = resolve_adaptation_v1(&compiled, &resolution).unwrap();
        assert_eq!(receipt.fallback_reason, AdaptationFallbackReasonV1::None);
        assert!(receipt.adaptation_applied);
        assert!(
            receipt
                .ordered_commands
                .iter()
                .all(|command| command.applied_correction_rad_s == 0.2)
        );
        assert!(
            receipt
                .ordered_commands
                .iter()
                .all(|command| command.slew_clamped)
        );
        assert!(receipt.ordered_commands.iter().all(|command| {
            command.final_canonical_target_velocity_rad_s.abs()
                <= command.maximum_target_speed_rad_s
        }));
    }

    #[test]
    fn uncertain_or_out_of_domain_provider_falls_back() {
        for (confidence, distance, reason) in [
            (0.5, 0.2, AdaptationFallbackReasonV1::ConfidenceBelowMinimum),
            (
                0.95,
                2.0,
                AdaptationFallbackReasonV1::OutsideSupportedDomain,
            ),
        ] {
            let (compiled, mut resolution) = fixture();
            resolution.provider_response = Some(
                serde_json::to_value(response(
                    &resolution,
                    AdaptationProviderStatusV1::Applied,
                    confidence,
                    distance,
                ))
                .unwrap(),
            );
            let receipt = resolve_adaptation_v1(&compiled, &resolution).unwrap();
            assert_eq!(receipt.fallback_reason, reason);
            assert!(receipt.deterministic_baseline_fallback_used);
            assert!(
                receipt
                    .ordered_commands
                    .iter()
                    .all(|command| command.applied_correction_rad_s == 0.0)
            );
        }
    }

    #[test]
    fn malformed_or_mismatched_provider_response_falls_back() {
        let (compiled, mut malformed) = fixture();
        malformed.provider_response = Some(serde_json::json!({"surprise": true}));
        let malformed_receipt = resolve_adaptation_v1(&compiled, &malformed).unwrap();
        assert_eq!(
            malformed_receipt.fallback_reason,
            AdaptationFallbackReasonV1::InvalidProviderResponse
        );

        let (compiled, mut mismatched) = fixture();
        let mut provider_response =
            response(&mismatched, AdaptationProviderStatusV1::Applied, 0.95, 0.2);
        provider_response.request_id = "different_request".to_owned();
        mismatched.provider_response = Some(serde_json::to_value(provider_response).unwrap());
        let mismatch_receipt = resolve_adaptation_v1(&compiled, &mismatched).unwrap();
        assert_eq!(
            mismatch_receipt.fallback_reason,
            AdaptationFallbackReasonV1::RequestIdentityMismatch
        );
    }

    #[test]
    fn reset_response_advances_epoch_and_clears_memory() {
        let (compiled, mut resolution) = fixture();
        let mut provider_response =
            response(&resolution, AdaptationProviderStatusV1::Reset, 1.0, 0.0);
        provider_response.next_memory = AdaptationProviderMemoryV1::empty("fixture_provider", 1);
        resolution.provider_response = Some(serde_json::to_value(provider_response).unwrap());
        let receipt = resolve_adaptation_v1(&compiled, &resolution).unwrap();
        assert_eq!(
            receipt.fallback_reason,
            AdaptationFallbackReasonV1::ProviderReset
        );
        assert_eq!(receipt.next_memory.reset_epoch, 1);
        assert_eq!(receipt.next_memory.sequence, 0);
        assert_eq!(receipt.next_memory.opaque_state_sha256, EMPTY_STATE_DIGEST);
    }

    #[test]
    fn recent_history_carries_canonical_payloads_and_rejects_fallback_authority() {
        let (compiled, resolution) = fixture();
        let request = &resolution.provider_request;
        let zero_corrections = request
            .deterministic_baseline
            .ordered_commands
            .iter()
            .map(|command| AdaptationProposedCorrectionV1 {
                actuator_id: command.actuator_id.clone(),
                canonical_velocity_delta_rad_s: 0.0,
            })
            .collect::<Vec<_>>();
        let mut history = AdaptationHistoryV1 {
            schema_version: ADAPTATION_HISTORY_V1_VERSION.to_owned(),
            ordered_entries: vec![AdaptationHistoryEntryV1 {
                semantic_step: 0,
                state: request.state.clone(),
                command: request.command.clone(),
                deterministic_baseline: request.deterministic_baseline.clone(),
                ordered_applied_corrections: zero_corrections,
                request_sha256:
                    "sha256:5555555555555555555555555555555555555555555555555555555555555555"
                        .to_owned(),
                resolution_receipt_sha256:
                    "sha256:6666666666666666666666666666666666666666666666666666666666666666"
                        .to_owned(),
                provider_status: AdaptationProviderStatusV1::Refused,
                adaptation_applied: false,
            }],
        };
        history.validate(&compiled, 1).unwrap();
        history.ordered_entries[0].ordered_applied_corrections[0].canonical_velocity_delta_rad_s =
            0.1;
        assert!(matches!(
            history.validate(&compiled, 1),
            Err(CoreError::Actuation(_))
        ));
    }
}
