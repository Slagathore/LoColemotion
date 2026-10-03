use godot::prelude::*;
use serde_json::{Number, Value};
use sha2::{Digest, Sha256};
use sporespore_locomotion_core::ffi::{
    SS_BUFFER_TOO_SMALL, ss_balanced_wave_initial_memory_json,
    ss_balanced_wave_policy_initial_memory_json, ss_balanced_wave_policy_profile_json,
    ss_balanced_wave_policy_session_create_json, ss_balanced_wave_policy_session_destroy,
    ss_balanced_wave_policy_session_step_json, ss_balanced_wave_policy_step_json,
    ss_balanced_wave_profile_json, ss_balanced_wave_step_json,
    ss_bound_stability_influence_v2_json, ss_bound_stability_influence_v3_json,
    ss_candidate35_initial_memory_json, ss_candidate35_profile_json, ss_candidate35_step_json,
    ss_canonicalize_json, ss_command_centroidal_support_v2_json, ss_compile_bounded_quadruped_json,
    ss_compile_recovery_morphology_v1_json, ss_gq15_domain_certificate_json,
    ss_map_endpoint_force_to_joint_v2_json, ss_map_endpoint_force_to_joint_v3_json,
    ss_observe_stability_v2_json, ss_plan_scheduled_load_transfer_v1_json,
    ss_plan_scheduled_load_transfer_v2_json, ss_plan_scheduled_load_transfer_v3_json,
    ss_recovery_collect_native_v1_json, ss_recovery_collect_native_v2_json,
    ss_recovery_collect_native_v3_json, ss_recovery_development_profile_v1_json,
    ss_recovery_energy_balance_aggregate_v2_json, ss_recovery_energy_balance_aggregate_v3_json,
    ss_recovery_energy_balance_evaluate_v2_json, ss_recovery_energy_balance_evaluate_v3_json,
    ss_recovery_energy_balance_migrate_v1_json, ss_recovery_evaluate_trace_v1_json,
    ss_recovery_evaluate_trace_v2_json, ss_recovery_evaluate_trace_v3_json,
    ss_recovery_evaluate_trace_v4_json, ss_recovery_evaluate_trace_v5_json,
    ss_recovery_initialize_v1_json, ss_recovery_initialize_v2_json,
    ss_recovery_passive_entry_step_v1_json, ss_recovery_collect_passive_native_v1_json,
    ss_recovery_r10k_entry_control_v1_json, ss_recovery_partial_fall_step_control_v1_json,
    ss_recovery_r10q_upright_entry_control_v1_json, ss_recovery_upright_step_control_v1_json,
    ss_recovery_r10r_upright_step_control_v1_json,
    ss_recovery_r10y_partial_entry_control_v1_json, ss_recovery_r10y_partial_step_control_v1_json,
    ss_recovery_r10z_partial_entry_control_v1_json, ss_recovery_r10z_partial_step_control_v1_json,
    ss_recovery_r10aa_partial_entry_control_v1_json, ss_recovery_r10aa_partial_step_control_v1_json,
    ss_recovery_r10ab_partial_entry_control_v1_json, ss_recovery_r10ab_partial_step_control_v1_json,
    ss_recovery_r10ai_partial_entry_control_v1_json, ss_recovery_r10ai_partial_step_control_v1_json,
    ss_recovery_r10aj_partial_entry_control_v1_json, ss_recovery_r10aj_partial_step_control_v1_json,
    ss_recovery_r10am_partial_entry_control_v1_json, ss_recovery_r10am_partial_step_control_v1_json,
    ss_recovery_r10ap_partial_entry_control_v1_json, ss_recovery_r10ap_partial_step_control_v1_json,
    ss_recovery_r10dd_partial_entry_control_v1_json, ss_recovery_r10dd_partial_step_control_v1_json,
    ss_recovery_plan_control_v1_json, ss_recovery_plan_control_v2_json,
    ss_recovery_plan_control_v3_json, ss_recovery_plan_stance_control_v1_json,
    ss_recovery_plan_stance_control_v2_json, ss_recovery_plan_stance_control_v3_json,
    ss_recovery_plan_stance_control_v4_json, ss_recovery_step_v1_json, ss_recovery_step_v2_json,
    ss_recovery_step_v3_json, ss_recovery_step_v4_json, ss_recovery_step_v5_json,
    ss_resolve_actuator_cap_profile_v1_json,
};
use sporespore_locomotion_core::runtime::{
    BALANCED_WAVE_RUNTIME_VERSION, CANDIDATE35_RUNTIME_VERSION,
};
use sporespore_locomotion_core::{SDK_VERSION, digest_json};

type InputJsonFunction = unsafe extern "C" fn(*const u8, usize, *mut u8, usize, *mut usize) -> i32;
type NoInputJsonFunction = unsafe extern "C" fn(*mut u8, usize, *mut usize) -> i32;
type SessionInputJsonFunction =
    unsafe extern "C" fn(u64, *const u8, usize, *mut u8, usize, *mut usize) -> i32;

/// Identifies the exact native execution route used by the Godot adapter.
///
/// This is deliberately independent of the SDK/controller runtime versions:
/// physical campaign preflights pin it before constructing a world, so an old
/// DLL cannot silently execute a newly frozen campaign.
pub const TRANSPORT_EXECUTION_VERSION: &str = "sporespore_godot_json_preallocated_single_pass_v1";
pub const CONTROLLER_SESSION_EXECUTION_VERSION: &str =
    "sporespore_godot_balanced_wave_persistent_session_v1";
pub const NATIVE_STEP_TRANSPORT_VERIFICATION_VERSION: &str =
    "sporespore_godot_balanced_wave_native_step_transport_verification_v1";
const TRANSPORT_CONTRACT_SCHEMA_VERSION: &str = "sporespore_godot_transport_execution_contract_v1";
const CONTROLLER_SESSION_CONTRACT_SCHEMA_VERSION: &str =
    "sporespore_godot_controller_session_execution_contract_v1";
const NATIVE_STEP_TRANSPORT_VERIFICATION_CONTRACT_SCHEMA_VERSION: &str =
    "sporespore_godot_balanced_wave_native_step_transport_verification_contract_v1";
const NATIVE_STEP_TRANSPORT_VERIFICATION_RECEIPT_SCHEMA_VERSION: &str =
    "sporespore_balanced_wave_native_step_transport_verification_v1";
const INITIAL_OUTPUT_CAPACITY_BYTES: usize = 16 * 1024;
const OVERFLOW_RETRY_LIMIT: usize = 1;

#[derive(GodotClass)]
#[class(init, base=RefCounted)]
pub struct SporeLocomotionSdk {
    balanced_wave_policy_session_handle: u64,
    base: Base<RefCounted>,
}

impl Drop for SporeLocomotionSdk {
    fn drop(&mut self) {
        if self.balanced_wave_policy_session_handle != 0 {
            let _ =
                ss_balanced_wave_policy_session_destroy(self.balanced_wave_policy_session_handle);
            self.balanced_wave_policy_session_handle = 0;
        }
    }
}

#[godot_api]
impl SporeLocomotionSdk {
    #[func]
    fn version(&self) -> GString {
        SDK_VERSION.into()
    }

    #[func]
    fn candidate35_runtime_version(&self) -> GString {
        CANDIDATE35_RUNTIME_VERSION.into()
    }

    #[func]
    fn balanced_wave_runtime_version(&self) -> GString {
        BALANCED_WAVE_RUNTIME_VERSION.into()
    }

    #[func]
    fn transport_execution_version(&self) -> GString {
        TRANSPORT_EXECUTION_VERSION.into()
    }

    #[func]
    fn transport_execution_contract_json(&self) -> GString {
        let json = serde_json::json!({
            "schema_version": TRANSPORT_CONTRACT_SCHEMA_VERSION,
            "execution_version": TRANSPORT_EXECUTION_VERSION,
            "input_transport": "normalized_json_utf8",
            "output_transport": "json_utf8",
            "normal_path_native_invocation_count": 1,
            "overflow_retry_limit": OVERFLOW_RETRY_LIMIT,
            "initial_output_capacity_bytes": INITIAL_OUTPUT_CAPACITY_BYTES,
            "world_build_count": 0,
            "physical_acceptance_authority": false,
        })
        .to_string();
        GString::from(&json)
    }

    #[func]
    fn controller_session_execution_version(&self) -> GString {
        CONTROLLER_SESSION_EXECUTION_VERSION.into()
    }

    #[func]
    fn controller_session_execution_contract_json(&self) -> GString {
        let json = serde_json::json!({
            "schema_version": CONTROLLER_SESSION_CONTRACT_SCHEMA_VERSION,
            "execution_version": CONTROLLER_SESSION_EXECUTION_VERSION,
            "create_request_schema_version":
                "sporespore_balanced_wave_policy_session_create_request_v1",
            "initial_memory_request_schema_version":
                "sporespore_balanced_wave_policy_initial_memory_request_v1",
            "step_request_schema_version":
                "sporespore_balanced_wave_policy_session_step_request_v1",
            "controller_memory_initialization": "explicit_named_policy",
            "controller_memory_transport": "explicit_every_step",
            "compiled_morphology_reused": true,
            "controller_profile_reused": true,
            "process_local_opaque_handle": true,
            "automatic_destroy_on_adapter_release": true,
            "world_build_count": 0,
            "physical_acceptance_authority": false,
        })
        .to_string();
        GString::from(&json)
    }

    #[func]
    fn balanced_wave_native_step_transport_verification_version(&self) -> GString {
        NATIVE_STEP_TRANSPORT_VERIFICATION_VERSION.into()
    }

    #[func]
    fn balanced_wave_native_step_transport_verification_contract_json(&self) -> GString {
        let json = serde_json::json!({
            "schema_version": NATIVE_STEP_TRANSPORT_VERIFICATION_CONTRACT_SCHEMA_VERSION,
            "verification_version": NATIVE_STEP_TRANSPORT_VERIFICATION_VERSION,
            "receipt_schema_version":
                NATIVE_STEP_TRANSPORT_VERIFICATION_RECEIPT_SCHEMA_VERSION,
            "verification_input": "exact_native_session_step_response_utf8_before_host_parse",
            "controller_receipt_digest_implementation":
                "sporespore_core_native_canonical_json_v1",
            "raw_response_digest_implementation": "sha256_exact_utf8_bytes",
            "raw_response_rewritten": false,
            "post_parse_dictionary_rehash_used": false,
            "floating_point_measurement_field_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physical_acceptance_authority": false,
        })
        .to_string();
        GString::from(&json)
    }

    #[func]
    fn balanced_wave_native_step_transport_verification_json(
        &self,
        raw_response: GString,
        expected_policy_id: GString,
        expected_receipt_schema: GString,
        expected_semantic_step: i64,
    ) -> GString {
        let raw_response = raw_response.to_string();
        match verify_balanced_wave_native_step_transport(
            &raw_response,
            &expected_policy_id.to_string(),
            &expected_receipt_schema.to_string(),
            expected_semantic_step,
        ) {
            Ok(receipt) => GString::from(
                &serde_json::json!({
                    "ok": true,
                    "value": receipt,
                })
                .to_string(),
            ),
            Err(code) => adapter_failure(
                code,
                "native balanced-wave step transport verification refused the supplied response",
            ),
        }
    }

    #[func]
    fn compile_bounded_quadruped_json(&self, input: GString) -> GString {
        call_input_json(input, ss_compile_bounded_quadruped_json)
    }

    #[func]
    fn canonicalize_json(&self, input: GString) -> GString {
        call_input_json(input, ss_canonicalize_json)
    }

    #[func]
    fn compile_recovery_morphology_v1_json(&self, input: GString) -> GString {
        call_input_json(input, ss_compile_recovery_morphology_v1_json)
    }

    #[func]
    fn resolve_actuator_cap_profile_v1_json(&self, input: GString) -> GString {
        call_input_json(input, ss_resolve_actuator_cap_profile_v1_json)
    }

    #[func]
    fn recovery_initialize_v1_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_initialize_v1_json)
    }

    #[func]
    fn recovery_initialize_v2_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_initialize_v2_json)
    }

    #[func]
    fn recovery_step_v1_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_step_v1_json)
    }

    #[func]
    fn recovery_step_v2_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_step_v2_json)
    }

    #[func]
    fn recovery_step_v3_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_step_v3_json)
    }

    #[func]
    fn recovery_step_v4_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_step_v4_json)
    }

    #[func]
    fn recovery_step_v5_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_step_v5_json)
    }

    #[func]
    fn recovery_collect_passive_native_v1_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_collect_passive_native_v1_json)
    }

    /// Only the new passive path uses this typed decoder. Godot's legacy JSON
    /// parser is not used to carry exact running-energy numbers back to Rust.
    #[func]
    fn decode_passive_recovery_response_v1(&self, input: GString) -> Variant {
        let Ok(value) = serde_json::from_str::<Value>(&input.to_string()) else {
            return Variant::nil();
        };
        if value.get("ok").and_then(Value::as_bool) != Some(true)
            || !matches!(value.pointer("/value/schema_version").and_then(Value::as_str),
                Some("sporespore_recovery_passive_entry_receipt_v1"
                    | "sporespore_recovery_passive_native_collection_receipt_v1"))
        {
            return Variant::nil();
        }
        json_to_exact_godot_variant(&value).unwrap_or_else(Variant::nil)
    }

    /// Decode supplied JSON without Godot's legacy decimal/integer conversion.
    /// This is a transport utility, not validation or evidence authority.
    #[func]
    fn decode_exact_json_v1(&self, input: GString) -> Variant {
        serde_json::from_str::<Value>(&input.to_string()).ok()
            .and_then(|value| json_to_exact_godot_variant(&value))
            .unwrap_or_else(Variant::nil)
    }

    #[func]
    fn recovery_passive_entry_step_v1_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_passive_entry_step_v1_json)
    }

    #[func]
    fn recovery_r10k_entry_control_v1_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_r10k_entry_control_v1_json)
    }

    #[func]
    fn recovery_partial_fall_step_control_v1_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_partial_fall_step_control_v1_json)
    }

    #[func]
    fn recovery_r10q_upright_entry_control_v1_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_r10q_upright_entry_control_v1_json)
    }

    #[func]
    fn recovery_upright_step_control_v1_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_upright_step_control_v1_json)
    }

    #[func]
    fn recovery_r10r_upright_step_control_v1_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_r10r_upright_step_control_v1_json)
    }

    #[func]
    fn recovery_r10y_partial_entry_control_v1_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_r10y_partial_entry_control_v1_json)
    }

    #[func]
    fn recovery_r10y_partial_step_control_v1_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_r10y_partial_step_control_v1_json)
    }

    #[func]
    fn recovery_r10z_partial_entry_control_v1_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_r10z_partial_entry_control_v1_json)
    }

    #[func]
    fn recovery_r10z_partial_step_control_v1_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_r10z_partial_step_control_v1_json)
    }

    #[func]
    fn recovery_r10aa_partial_entry_control_v1_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_r10aa_partial_entry_control_v1_json)
    }

    #[func]
    fn recovery_r10aa_partial_step_control_v1_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_r10aa_partial_step_control_v1_json)
    }

    #[func]
    fn recovery_r10ab_partial_entry_control_v1_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_r10ab_partial_entry_control_v1_json)
    }

    #[func]
    fn recovery_r10ab_partial_step_control_v1_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_r10ab_partial_step_control_v1_json)
    }

    #[func]
    fn recovery_r10ai_partial_entry_control_v1_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_r10ai_partial_entry_control_v1_json)
    }

    #[func]
    fn recovery_r10ai_partial_step_control_v1_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_r10ai_partial_step_control_v1_json)
    }

    #[func]
    fn recovery_r10aj_partial_entry_control_v1_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_r10aj_partial_entry_control_v1_json)
    }

    #[func]
    fn recovery_r10aj_partial_step_control_v1_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_r10aj_partial_step_control_v1_json)
    }

    #[func]
    fn recovery_r10am_partial_entry_control_v1_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_r10am_partial_entry_control_v1_json)
    }

    #[func]
    fn recovery_r10am_partial_step_control_v1_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_r10am_partial_step_control_v1_json)
    }

    #[func]
    fn recovery_r10ap_partial_entry_control_v1_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_r10ap_partial_entry_control_v1_json)
    }

    #[func]
    fn recovery_r10ap_partial_step_control_v1_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_r10ap_partial_step_control_v1_json)
    }

    #[func]
    fn recovery_r10dd_partial_entry_control_v1_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_r10dd_partial_entry_control_v1_json)
    }

    #[func]
    fn recovery_r10dd_partial_step_control_v1_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_r10dd_partial_step_control_v1_json)
    }

    #[func]
    fn recovery_evaluate_trace_v1_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_evaluate_trace_v1_json)
    }

    #[func]
    fn recovery_evaluate_trace_v2_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_evaluate_trace_v2_json)
    }

    #[func]
    fn recovery_evaluate_trace_v3_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_evaluate_trace_v3_json)
    }

    #[func]
    fn recovery_evaluate_trace_v4_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_evaluate_trace_v4_json)
    }

    #[func]
    fn recovery_evaluate_trace_v5_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_evaluate_trace_v5_json)
    }

    #[func]
    fn recovery_energy_balance_aggregate_v2_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_energy_balance_aggregate_v2_json)
    }

    #[func]
    fn recovery_energy_balance_evaluate_v2_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_energy_balance_evaluate_v2_json)
    }

    #[func]
    fn recovery_energy_balance_aggregate_v3_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_energy_balance_aggregate_v3_json)
    }

    #[func]
    fn recovery_energy_balance_evaluate_v3_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_energy_balance_evaluate_v3_json)
    }

    #[func]
    fn recovery_energy_balance_migrate_v1_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_energy_balance_migrate_v1_json)
    }

    #[func]
    fn recovery_development_profile_v1_json(&self) -> GString {
        call_no_input_json(ss_recovery_development_profile_v1_json)
    }

    #[func]
    fn recovery_collect_native_v1_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_collect_native_v1_json)
    }

    #[func]
    fn recovery_collect_native_v2_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_collect_native_v2_json)
    }

    #[func]
    fn recovery_collect_native_v3_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_collect_native_v3_json)
    }

    #[func]
    fn recovery_plan_control_v1_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_plan_control_v1_json)
    }

    #[func]
    fn recovery_plan_control_v2_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_plan_control_v2_json)
    }

    #[func]
    fn recovery_plan_control_v3_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_plan_control_v3_json)
    }

    #[func]
    fn recovery_plan_stance_control_v1_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_plan_stance_control_v1_json)
    }

    #[func]
    fn recovery_plan_stance_control_v2_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_plan_stance_control_v2_json)
    }

    #[func]
    fn recovery_plan_stance_control_v3_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_plan_stance_control_v3_json)
    }

    #[func]
    fn recovery_plan_stance_control_v4_json(&self, input: GString) -> GString {
        call_input_json(input, ss_recovery_plan_stance_control_v4_json)
    }

    #[func]
    fn candidate35_profile_json(&self, input: GString) -> GString {
        call_input_json(input, ss_candidate35_profile_json)
    }

    #[func]
    fn candidate35_initial_memory_json(&self) -> GString {
        call_no_input_json(ss_candidate35_initial_memory_json)
    }

    #[func]
    fn candidate35_step_json(&self, input: GString) -> GString {
        call_input_json(input, ss_candidate35_step_json)
    }

    #[func]
    fn balanced_wave_profile_json(&self, input: GString) -> GString {
        call_input_json(input, ss_balanced_wave_profile_json)
    }

    #[func]
    fn balanced_wave_policy_profile_json(&self, input: GString) -> GString {
        call_input_json(input, ss_balanced_wave_policy_profile_json)
    }

    #[func]
    fn balanced_wave_initial_memory_json(&self) -> GString {
        call_no_input_json(ss_balanced_wave_initial_memory_json)
    }

    #[func]
    fn balanced_wave_policy_initial_memory_json(&self, input: GString) -> GString {
        call_input_json(input, ss_balanced_wave_policy_initial_memory_json)
    }

    #[func]
    fn balanced_wave_step_json(&self, input: GString) -> GString {
        call_input_json(input, ss_balanced_wave_step_json)
    }

    #[func]
    fn balanced_wave_policy_step_json(&self, input: GString) -> GString {
        call_input_json(input, ss_balanced_wave_policy_step_json)
    }

    #[func]
    fn balanced_wave_policy_session_create_json(&mut self, input: GString) -> GString {
        if self.balanced_wave_policy_session_handle != 0 {
            return adapter_failure(
                "GODOT_ADAPTER_CONTROLLER_SESSION_ALREADY_ACTIVE",
                "destroy the active session before creating another",
            );
        }
        let input = match normalize_godot_json_numbers(&input.to_string()) {
            Ok(input) => input,
            Err(detail) => {
                return adapter_failure("GODOT_ADAPTER_INPUT_JSON_INVALID", &detail);
            }
        };
        let mut handle = 0_u64;
        let status = unsafe {
            ss_balanced_wave_policy_session_create_json(input.as_ptr(), input.len(), &mut handle)
        };
        if status != 0 || handle == 0 {
            return transport_failure("GODOT_ADAPTER_CONTROLLER_SESSION_CREATE_FAILED", status);
        }
        self.balanced_wave_policy_session_handle = handle;
        let json = serde_json::json!({
            "ok": true,
            "value": {
                "schema_version":
                    "sporespore_godot_balanced_wave_policy_session_receipt_v1",
                "execution_version": CONTROLLER_SESSION_EXECUTION_VERSION,
                "active": true,
                "world_build_count": 0,
                "physical_acceptance_authority": false,
            }
        })
        .to_string();
        GString::from(&json)
    }

    #[func]
    fn balanced_wave_policy_session_step_json(&self, input: GString) -> GString {
        if self.balanced_wave_policy_session_handle == 0 {
            return adapter_failure(
                "GODOT_ADAPTER_CONTROLLER_SESSION_NOT_ACTIVE",
                "create a balanced-wave policy session before stepping it",
            );
        }
        let input = match normalize_godot_json_numbers(&input.to_string()) {
            Ok(input) => input,
            Err(detail) => {
                return adapter_failure("GODOT_ADAPTER_INPUT_JSON_INVALID", &detail);
            }
        };
        match invoke_session_input_json(
            self.balanced_wave_policy_session_handle,
            input.as_bytes(),
            ss_balanced_wave_policy_session_step_json,
        ) {
            Ok((output, status)) => decode_output(output, status),
            Err((code, status)) => transport_failure(code, status),
        }
    }

    #[func]
    fn balanced_wave_policy_session_destroy_json(&mut self) -> GString {
        if self.balanced_wave_policy_session_handle == 0 {
            return adapter_failure(
                "GODOT_ADAPTER_CONTROLLER_SESSION_NOT_ACTIVE",
                "no active balanced-wave policy session exists",
            );
        }
        let status =
            ss_balanced_wave_policy_session_destroy(self.balanced_wave_policy_session_handle);
        if status != 0 {
            return transport_failure("GODOT_ADAPTER_CONTROLLER_SESSION_DESTROY_FAILED", status);
        }
        self.balanced_wave_policy_session_handle = 0;
        GString::from(
            &serde_json::json!({
                "ok": true,
                "value": {
                    "schema_version":
                        "sporespore_godot_balanced_wave_policy_session_receipt_v1",
                    "execution_version": CONTROLLER_SESSION_EXECUTION_VERSION,
                    "active": false,
                    "world_build_count": 0,
                    "physical_acceptance_authority": false,
                }
            })
            .to_string(),
        )
    }

    #[func]
    fn observe_stability_v2_json(&self, input: GString) -> GString {
        call_input_json(input, ss_observe_stability_v2_json)
    }

    #[func]
    fn plan_scheduled_load_transfer_v1_json(&self, input: GString) -> GString {
        call_input_json(input, ss_plan_scheduled_load_transfer_v1_json)
    }

    #[func]
    fn plan_scheduled_load_transfer_v2_json(&self, input: GString) -> GString {
        call_input_json(input, ss_plan_scheduled_load_transfer_v2_json)
    }

    #[func]
    fn plan_scheduled_load_transfer_v3_json(&self, input: GString) -> GString {
        call_input_json(input, ss_plan_scheduled_load_transfer_v3_json)
    }

    #[func]
    fn command_centroidal_support_v2_json(&self, input: GString) -> GString {
        call_input_json(input, ss_command_centroidal_support_v2_json)
    }

    #[func]
    fn map_endpoint_force_to_joint_v2_json(&self, input: GString) -> GString {
        call_input_json(input, ss_map_endpoint_force_to_joint_v2_json)
    }

    #[func]
    fn map_endpoint_force_to_joint_v3_json(&self, input: GString) -> GString {
        call_input_json(input, ss_map_endpoint_force_to_joint_v3_json)
    }

    #[func]
    fn bound_stability_influence_v2_json(&self, input: GString) -> GString {
        call_input_json(input, ss_bound_stability_influence_v2_json)
    }

    #[func]
    fn bound_stability_influence_v3_json(&self, input: GString) -> GString {
        call_input_json(input, ss_bound_stability_influence_v3_json)
    }

    #[func]
    fn gq15_domain_certificate_json(&self) -> GString {
        call_no_input_json(ss_gq15_domain_certificate_json)
    }
}

fn json_to_exact_godot_variant(value: &Value) -> Option<Variant> {
    Some(match value {
        Value::Null => Variant::nil(),
        Value::Bool(value) => value.to_variant(),
        Value::String(value) => GString::from(value.as_str()).to_variant(),
        Value::Number(value) => {
            if value.is_f64() { value.as_f64()?.to_variant() }
            else { value.as_i64()?.to_variant() }
        }
        Value::Array(values) => {
            let mut array = Array::<Variant>::new();
            for value in values { array.push(&json_to_exact_godot_variant(value)?); }
            array.to_variant()
        }
        Value::Object(values) => {
            let mut dictionary = Dictionary::<Variant, Variant>::new();
            for (key, value) in values {
                dictionary.set(&GString::from(key.as_str()), &json_to_exact_godot_variant(value)?);
            }
            dictionary.to_variant()
        }
    })
}

fn call_input_json(input: GString, function: InputJsonFunction) -> GString {
    let input = match normalize_godot_json_numbers(&input.to_string()) {
        Ok(input) => input,
        Err(detail) => {
            return adapter_failure("GODOT_ADAPTER_INPUT_JSON_INVALID", &detail);
        }
    };
    let bytes = input.as_bytes();
    match invoke_input_json(bytes, function) {
        Ok((output, status)) => decode_output(output, status),
        Err((code, status)) => transport_failure(code, status),
    }
}

fn call_no_input_json(function: NoInputJsonFunction) -> GString {
    match invoke_no_input_json(function) {
        Ok((output, status)) => decode_output(output, status),
        Err((code, status)) => transport_failure(code, status),
    }
}

/// Invoke the pure core operation once on the normal path. A single bounded
/// retry is permitted only when the exact serialized output exceeds the
/// preallocated buffer and the core reports its required size.
fn invoke_input_json(
    input: &[u8],
    function: InputJsonFunction,
) -> Result<(Vec<u8>, i32), (&'static str, i32)> {
    let mut output = vec![0_u8; INITIAL_OUTPUT_CAPACITY_BYTES];
    let mut required = 0_usize;
    let first_status = unsafe {
        function(
            input.as_ptr(),
            input.len(),
            output.as_mut_ptr(),
            output.len(),
            &mut required,
        )
    };
    if first_status != SS_BUFFER_TOO_SMALL {
        return finish_preallocated_output(output, required, first_status);
    }
    if required <= output.len() {
        return Err(("GODOT_ADAPTER_OUTPUT_SIZE_CONTRACT_INVALID", first_status));
    }
    output.resize(required, 0);
    let retry_status = unsafe {
        function(
            input.as_ptr(),
            input.len(),
            output.as_mut_ptr(),
            output.len(),
            &mut required,
        )
    };
    if retry_status == SS_BUFFER_TOO_SMALL {
        return Err(("GODOT_ADAPTER_OUTPUT_RETRY_EXHAUSTED", retry_status));
    }
    finish_preallocated_output(output, required, retry_status)
}

fn invoke_no_input_json(
    function: NoInputJsonFunction,
) -> Result<(Vec<u8>, i32), (&'static str, i32)> {
    let mut output = vec![0_u8; INITIAL_OUTPUT_CAPACITY_BYTES];
    let mut required = 0_usize;
    let first_status = unsafe { function(output.as_mut_ptr(), output.len(), &mut required) };
    if first_status != SS_BUFFER_TOO_SMALL {
        return finish_preallocated_output(output, required, first_status);
    }
    if required <= output.len() {
        return Err(("GODOT_ADAPTER_OUTPUT_SIZE_CONTRACT_INVALID", first_status));
    }
    output.resize(required, 0);
    let retry_status = unsafe { function(output.as_mut_ptr(), output.len(), &mut required) };
    if retry_status == SS_BUFFER_TOO_SMALL {
        return Err(("GODOT_ADAPTER_OUTPUT_RETRY_EXHAUSTED", retry_status));
    }
    finish_preallocated_output(output, required, retry_status)
}

fn invoke_session_input_json(
    session_handle: u64,
    input: &[u8],
    function: SessionInputJsonFunction,
) -> Result<(Vec<u8>, i32), (&'static str, i32)> {
    let mut output = vec![0_u8; INITIAL_OUTPUT_CAPACITY_BYTES];
    let mut required = 0_usize;
    let first_status = unsafe {
        function(
            session_handle,
            input.as_ptr(),
            input.len(),
            output.as_mut_ptr(),
            output.len(),
            &mut required,
        )
    };
    if first_status != SS_BUFFER_TOO_SMALL {
        return finish_preallocated_output(output, required, first_status);
    }
    if required <= output.len() {
        return Err(("GODOT_ADAPTER_OUTPUT_SIZE_CONTRACT_INVALID", first_status));
    }
    output.resize(required, 0);
    let retry_status = unsafe {
        function(
            session_handle,
            input.as_ptr(),
            input.len(),
            output.as_mut_ptr(),
            output.len(),
            &mut required,
        )
    };
    if retry_status == SS_BUFFER_TOO_SMALL {
        return Err(("GODOT_ADAPTER_OUTPUT_RETRY_EXHAUSTED", retry_status));
    }
    finish_preallocated_output(output, required, retry_status)
}

fn finish_preallocated_output(
    mut output: Vec<u8>,
    required: usize,
    status: i32,
) -> Result<(Vec<u8>, i32), (&'static str, i32)> {
    if required == 0 || required > output.len() {
        return Err(("GODOT_ADAPTER_OUTPUT_LENGTH_INVALID", status));
    }
    output.truncate(required);
    Ok((output, status))
}

fn decode_output(output: Vec<u8>, status: i32) -> GString {
    match String::from_utf8(output) {
        Ok(json) => GString::from(&json),
        Err(_) => transport_failure("GODOT_ADAPTER_NON_UTF8", status),
    }
}

fn verify_balanced_wave_native_step_transport(
    raw_response: &str,
    expected_policy_id: &str,
    expected_receipt_schema: &str,
    expected_semantic_step: i64,
) -> Result<Value, &'static str> {
    if expected_policy_id.is_empty()
        || expected_receipt_schema.is_empty()
        || expected_semantic_step < 0
    {
        return Err("GODOT_ADAPTER_NATIVE_STEP_VERIFICATION_EXPECTATION_INVALID");
    }
    let envelope: Value = serde_json::from_str(raw_response)
        .map_err(|_| "GODOT_ADAPTER_NATIVE_STEP_VERIFICATION_RESPONSE_JSON_INVALID")?;
    if envelope.get("ok").and_then(Value::as_bool) != Some(true) {
        return Err("GODOT_ADAPTER_NATIVE_STEP_VERIFICATION_PUBLIC_ENVELOPE_INVALID");
    }
    let output = envelope
        .get("value")
        .and_then(Value::as_object)
        .ok_or("GODOT_ADAPTER_NATIVE_STEP_VERIFICATION_VALUE_INVALID")?;
    let actuation = output
        .get("actuation")
        .and_then(Value::as_object)
        .ok_or("GODOT_ADAPTER_NATIVE_STEP_VERIFICATION_ACTUATION_INVALID")?;
    if actuation.get("semantic_step").and_then(Value::as_i64) != Some(expected_semantic_step) {
        return Err("GODOT_ADAPTER_NATIVE_STEP_VERIFICATION_ACTUATION_STEP_MISMATCH");
    }
    if actuation.get("world_build_count").and_then(Value::as_u64) != Some(0)
        || actuation
            .get("physical_acceptance_authority")
            .and_then(Value::as_bool)
            != Some(false)
    {
        return Err("GODOT_ADAPTER_NATIVE_STEP_VERIFICATION_ACTUATION_AUTHORITY_INVALID");
    }
    let receipt = actuation
        .get("receipt")
        .ok_or("GODOT_ADAPTER_NATIVE_STEP_VERIFICATION_CONTROLLER_RECEIPT_MISSING")?;
    let receipt = receipt
        .as_object()
        .ok_or("GODOT_ADAPTER_NATIVE_STEP_VERIFICATION_CONTROLLER_RECEIPT_INVALID")?;
    if receipt.get("schema_version").and_then(Value::as_str) != Some(expected_receipt_schema) {
        return Err("GODOT_ADAPTER_NATIVE_STEP_VERIFICATION_RECEIPT_SCHEMA_MISMATCH");
    }
    if receipt.get("policy_id").and_then(Value::as_str) != Some(expected_policy_id) {
        return Err("GODOT_ADAPTER_NATIVE_STEP_VERIFICATION_POLICY_MISMATCH");
    }
    if receipt.get("semantic_step").and_then(Value::as_i64) != Some(expected_semantic_step) {
        return Err("GODOT_ADAPTER_NATIVE_STEP_VERIFICATION_RECEIPT_STEP_MISMATCH");
    }
    if receipt.get("world_build_count").and_then(Value::as_u64) != Some(0)
        || receipt
            .get("physical_acceptance_authority")
            .and_then(Value::as_bool)
            != Some(false)
    {
        return Err("GODOT_ADAPTER_NATIVE_STEP_VERIFICATION_RECEIPT_AUTHORITY_INVALID");
    }
    let native_actuation_receipt_sha256 =
        actuation
            .get("receipt_sha256")
            .and_then(Value::as_str)
            .ok_or("GODOT_ADAPTER_NATIVE_STEP_VERIFICATION_RECEIPT_DIGEST_INVALID")?;
    let controller_receipt = Value::Object(receipt.clone());
    let recomputed_controller_receipt_sha256 = digest_json(&controller_receipt)
        .map_err(|_| "GODOT_ADAPTER_NATIVE_STEP_VERIFICATION_RECEIPT_DIGEST_RECOMPUTE_FAILED")?;
    if native_actuation_receipt_sha256 != recomputed_controller_receipt_sha256 {
        return Err("GODOT_ADAPTER_NATIVE_STEP_VERIFICATION_RECEIPT_DIGEST_MISMATCH");
    }

    let raw_native_response_sha256 =
        format!("sha256:{:x}", Sha256::digest(raw_response.as_bytes()));
    let mut verification_receipt = serde_json::json!({
        "schema_version": NATIVE_STEP_TRANSPORT_VERIFICATION_RECEIPT_SCHEMA_VERSION,
        "verification_version": NATIVE_STEP_TRANSPORT_VERIFICATION_VERSION,
        "ok": true,
        "policy_id": expected_policy_id,
        "semantic_step": expected_semantic_step,
        "controller_receipt_schema_version": expected_receipt_schema,
        "controller_receipt_sha256": recomputed_controller_receipt_sha256,
        "native_actuation_receipt_sha256": native_actuation_receipt_sha256,
        "raw_native_response_sha256": raw_native_response_sha256,
        "raw_native_response_byte_length": raw_response.len(),
        "successful_public_envelope": true,
        "policy_identity_exact": true,
        "semantic_step_identity_exact": true,
        "controller_receipt_schema_exact": true,
        "native_canonical_receipt_digest_exact": true,
        "preparse_native_response_verified": true,
        "raw_native_response_rewritten": false,
        "post_parse_dictionary_rehash_used": false,
        "floating_point_measurement_field_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physical_acceptance_authority": false,
        "payload_sha256": "",
    });
    let payload_sha256 = digest_json(&verification_receipt)
        .map_err(|_| "GODOT_ADAPTER_NATIVE_STEP_VERIFICATION_PAYLOAD_DIGEST_RECOMPUTE_FAILED")?;
    verification_receipt["payload_sha256"] = Value::String(payload_sha256);
    Ok(verification_receipt)
}

fn transport_failure(code: &str, status: i32) -> GString {
    adapter_failure(code, &format!("native transport status {status}"))
}

/// Godot's JSON parser represents every JSON number as a floating-point
/// Variant. Consequently, SDK-owned integer fields such as `semantic_step`
/// round-trip through GDScript as `0.0`. Normalize only exactly integral,
/// finite JSON numbers before entering the strict C ABI. Floating-point schema
/// fields still deserialize from integer JSON values, while fractional values
/// remain untouched. The C ABI itself deliberately retains strict serde
/// behavior for non-Godot callers.
fn normalize_godot_json_numbers(input: &str) -> Result<String, String> {
    let mut value: Value = serde_json::from_str(input).map_err(|error| error.to_string())?;
    normalize_value(&mut value);
    serde_json::to_string(&value).map_err(|error| error.to_string())
}

fn normalize_value(value: &mut Value) {
    match value {
        Value::Array(values) => {
            for value in values {
                normalize_value(value);
            }
        }
        Value::Object(values) => {
            for value in values.values_mut() {
                normalize_value(value);
            }
        }
        Value::Number(number) if number.is_f64() => {
            let Some(float) = number.as_f64() else {
                return;
            };
            if float.is_finite()
                && float.fract() == 0.0
                && float >= i64::MIN as f64
                && float <= i64::MAX as f64
            {
                *number = Number::from(float as i64);
            }
        }
        _ => {}
    }
}

fn adapter_failure(code: &str, detail: &str) -> GString {
    let json = serde_json::json!({
        "detail": detail,
        "failure_code": code,
        "ok": false,
    })
    .to_string();
    GString::from(&json)
}

struct SporeLocomotionExtension;

#[gdextension]
unsafe impl ExtensionLibrary for SporeLocomotionExtension {}

#[cfg(test)]
mod tests {
    use super::*;
    use std::hint::black_box;
    use std::ptr;
    use std::sync::atomic::{AtomicUsize, Ordering};
    use std::time::Instant;

    static NORMAL_PATH_CALLS: AtomicUsize = AtomicUsize::new(0);
    static NO_INPUT_NORMAL_PATH_CALLS: AtomicUsize = AtomicUsize::new(0);
    static OVERFLOW_PATH_CALLS: AtomicUsize = AtomicUsize::new(0);

    unsafe extern "C" fn normal_path_stub(
        _input: *const u8,
        _input_length: usize,
        output: *mut u8,
        output_capacity: usize,
        output_length: *mut usize,
    ) -> i32 {
        NORMAL_PATH_CALLS.fetch_add(1, Ordering::SeqCst);
        let payload = br#"{"ok":true}"#;
        unsafe {
            *output_length = payload.len();
            assert!(output_capacity >= payload.len());
            std::ptr::copy_nonoverlapping(payload.as_ptr(), output, payload.len());
        }
        0
    }

    unsafe extern "C" fn overflow_path_stub(
        _input: *const u8,
        _input_length: usize,
        output: *mut u8,
        output_capacity: usize,
        output_length: *mut usize,
    ) -> i32 {
        OVERFLOW_PATH_CALLS.fetch_add(1, Ordering::SeqCst);
        let required = INITIAL_OUTPUT_CAPACITY_BYTES + 1;
        unsafe {
            *output_length = required;
            if output_capacity < required {
                return SS_BUFFER_TOO_SMALL;
            }
            std::ptr::write_bytes(output, b'x', required);
        }
        0
    }

    unsafe extern "C" fn no_input_normal_path_stub(
        output: *mut u8,
        output_capacity: usize,
        output_length: *mut usize,
    ) -> i32 {
        NO_INPUT_NORMAL_PATH_CALLS.fetch_add(1, Ordering::SeqCst);
        let payload = br#"{"ok":true}"#;
        unsafe {
            *output_length = payload.len();
            assert!(output_capacity >= payload.len());
            std::ptr::copy_nonoverlapping(payload.as_ptr(), output, payload.len());
        }
        0
    }

    fn invoke_input_json_legacy_two_pass(
        input: &[u8],
        function: InputJsonFunction,
    ) -> (Vec<u8>, i32) {
        let mut required = 0_usize;
        let size_status = unsafe {
            function(
                input.as_ptr(),
                input.len(),
                ptr::null_mut(),
                0,
                &mut required,
            )
        };
        assert_eq!(size_status, SS_BUFFER_TOO_SMALL);
        assert!(required > 0);
        let mut output = vec![0_u8; required];
        let status = unsafe {
            function(
                input.as_ptr(),
                input.len(),
                output.as_mut_ptr(),
                output.len(),
                &mut required,
            )
        };
        output.truncate(required);
        (output, status)
    }

    fn balanced_wave_step_request_bytes() -> Vec<u8> {
        let descriptor = serde_json::json!({
            "schema_version": "sporespore_bounded_quadruped_descriptor_v1",
            "morphology_id": "godot_transport_benchmark",
            "torso_length_scale": 1.0,
            "torso_width_scale": 1.0,
            "upper_length_fraction": 18.0 / 35.0,
            "hip_span_scale": 1.0,
            "foot_radius_scale": 1.0,
            "front_limb_mass_scale": 1.0,
        });
        let descriptor_bytes = serde_json::to_vec(&descriptor).unwrap();
        let (compiled_bytes, compile_status) =
            invoke_input_json(&descriptor_bytes, ss_compile_bounded_quadruped_json).unwrap();
        assert_eq!(compile_status, 0);
        let compiled: Value = serde_json::from_slice(&compiled_bytes).unwrap();
        let morphology = &compiled["value"]["morphology"];

        let (memory_bytes, memory_status) =
            invoke_no_input_json(ss_balanced_wave_initial_memory_json).unwrap();
        assert_eq!(memory_status, 0);
        let memory: Value = serde_json::from_slice(&memory_bytes).unwrap();

        let joints: Vec<Value> = morphology["ordered_joint_ids"]
            .as_array()
            .unwrap()
            .iter()
            .map(|joint_id| {
                serde_json::json!({
                    "joint_id": joint_id,
                    "position_rad": 0.0,
                    "velocity_rad_s": 0.0,
                    "anchor_error_m": 0.0,
                    "validity": {
                        "position": true,
                        "velocity": true,
                        "anchor_error": true,
                    },
                })
            })
            .collect();
        let contacts: Vec<Value> = morphology["ordered_contact_site_ids"]
            .as_array()
            .unwrap()
            .iter()
            .map(|contact_id| {
                let contact_id = contact_id.as_str().unwrap();
                serde_json::json!({
                    "contact_site_id": contact_id,
                    "presence": true,
                    "bears_support": true,
                    "normal_load_n": null,
                    "provenance": {
                        "adapter_id": "godot_transport_benchmark",
                        "engine_contact_ids": [format!("{contact_id}_engine")],
                        "aggregation_rule_id": "qualified_bearing_only",
                        "quality": "qualified_bearing",
                    },
                })
            })
            .collect();

        serde_json::to_vec(&serde_json::json!({
            "schema_version": "sporespore_balanced_wave_policy_step_request_v1",
            "policy_id": "sporespore_balanced_wave_bw5r_b_v1",
            "descriptor": descriptor,
            "memory": memory["value"].clone(),
            "state": {
                "schema_version": "sporespore_state_frame_v1",
                "semantic_step": 0,
                "sample_time_s": 0.0,
                "base_pose_world": {
                    "position_m": {"x": 0.0, "y": 0.44, "z": 0.0},
                    "orientation_xyzw": {"x": 0.0, "y": 0.0, "z": 0.0, "w": 1.0},
                },
                "base_twist_world": {
                    "linear_velocity_m_s": {"x": 0.0, "y": 0.0, "z": 0.0},
                    "angular_velocity_rad_s": {"x": 0.0, "y": 0.0, "z": 0.0},
                },
                "ordered_joint_observations": joints,
                "ordered_contact_observations": contacts,
                "previous_applied_actuation": null,
                "gravity_world_m_s2": {"x": 0.0, "y": -9.81, "z": 0.0},
                "task_frame": {
                    "origin_world_m": {"x": 0.0, "y": 0.0, "z": 0.0},
                    "forward_axis_world_unit": {"x": 1.0, "y": 0.0, "z": 0.0},
                    "lateral_axis_world_unit": {"x": 0.0, "y": 0.0, "z": 1.0},
                    "up_axis_world_unit": {"x": 0.0, "y": 1.0, "z": 0.0},
                    "reference_yaw_rad": 0.0,
                },
                "adapter_capability_sha256":
                    "sha256:3333333333333333333333333333333333333333333333333333333333333333",
            },
            "command": {
                "schema_version": "sporespore_motion_command_v2",
                "command_id": "godot_transport_benchmark_walk",
                "desired_planar_velocity_task_m_s": {"x": 0.2, "y": 0.0, "z": 0.0},
                "desired_heading_rad": 0.0,
                "desired_yaw_rate_rad_s": null,
                "gait_family_id": "lateral_wave",
                "speed_class": "walk",
                "gait_amplitude": 1.0,
                "phase_progression_mode": "contact_gated",
                "valid_from_step": 0,
                "valid_through_step": 0,
                "authority": "test_fixture",
            },
        }))
        .unwrap()
    }

    #[test]
    fn godot_integral_floats_are_normalized_recursively() {
        let normalized = normalize_godot_json_numbers(
            r#"{"semantic_step":0.0,"position":0.25,"nested":[3.0,-4.0]}"#,
        )
        .unwrap();
        let value: Value = serde_json::from_str(&normalized).unwrap();
        assert!(value["semantic_step"].is_i64());
        assert!(value["nested"][0].is_i64());
        assert!(value["nested"][1].is_i64());
        assert!(value["position"].is_f64());
    }

    #[test]
    fn malformed_input_returns_an_error_instead_of_panicking() {
        assert!(normalize_godot_json_numbers("{").is_err());
    }

    #[test]
    fn normal_path_executes_the_native_operation_exactly_once() {
        NORMAL_PATH_CALLS.store(0, Ordering::SeqCst);
        let (output, status) = invoke_input_json(br#"{"input":true}"#, normal_path_stub).unwrap();
        assert_eq!(status, 0);
        assert_eq!(output, br#"{"ok":true}"#);
        assert_eq!(NORMAL_PATH_CALLS.load(Ordering::SeqCst), 1);
    }

    #[test]
    fn no_input_normal_path_executes_the_native_operation_exactly_once() {
        NO_INPUT_NORMAL_PATH_CALLS.store(0, Ordering::SeqCst);
        let (output, status) = invoke_no_input_json(no_input_normal_path_stub).unwrap();
        assert_eq!(status, 0);
        assert_eq!(output, br#"{"ok":true}"#);
        assert_eq!(NO_INPUT_NORMAL_PATH_CALLS.load(Ordering::SeqCst), 1);
    }

    #[test]
    fn oversized_output_uses_one_exact_size_retry() {
        OVERFLOW_PATH_CALLS.store(0, Ordering::SeqCst);
        let (output, status) = invoke_input_json(br#"{"input":true}"#, overflow_path_stub).unwrap();
        assert_eq!(status, 0);
        assert_eq!(output.len(), INITIAL_OUTPUT_CAPACITY_BYTES + 1);
        assert_eq!(OVERFLOW_PATH_CALLS.load(Ordering::SeqCst), 2);
    }

    #[test]
    fn single_pass_matches_legacy_two_pass_balanced_wave_bytes() {
        let input = balanced_wave_step_request_bytes();
        let (single_output, single_status) =
            invoke_input_json(&input, ss_balanced_wave_policy_step_json).unwrap();
        let (legacy_output, legacy_status) =
            invoke_input_json_legacy_two_pass(&input, ss_balanced_wave_policy_step_json);
        assert_eq!(single_status, legacy_status);
        assert_eq!(single_output, legacy_output);
        let envelope: Value = serde_json::from_slice(&single_output).unwrap();
        assert!(
            envelope["ok"].as_bool().unwrap_or(false),
            "balanced-wave fixture failed: {}",
            String::from_utf8_lossy(&single_output)
        );
        assert!(single_output.len() < INITIAL_OUTPUT_CAPACITY_BYTES);
    }

    fn persistent_session_requests() -> (Vec<u8>, Vec<u8>, Vec<u8>) {
        let legacy_bytes = balanced_wave_step_request_bytes();
        let legacy: Value = serde_json::from_slice(&legacy_bytes).unwrap();
        let create = serde_json::to_vec(&serde_json::json!({
            "schema_version": "sporespore_balanced_wave_policy_session_create_request_v1",
            "policy_id": legacy["policy_id"].clone(),
            "descriptor": legacy["descriptor"].clone(),
        }))
        .unwrap();
        let step = serde_json::to_vec(&serde_json::json!({
            "schema_version": "sporespore_balanced_wave_policy_session_step_request_v1",
            "memory": legacy["memory"].clone(),
            "state": legacy["state"].clone(),
            "command": legacy["command"].clone(),
        }))
        .unwrap();
        (create, step, legacy_bytes)
    }

    fn native_step_verification_fixture() -> (String, String, String, i64) {
        let (create, step, legacy) = persistent_session_requests();
        let legacy: Value = serde_json::from_slice(&legacy).unwrap();
        let policy_id = legacy["policy_id"].as_str().unwrap().to_owned();
        let semantic_step = legacy["state"]["semantic_step"].as_i64().unwrap();
        let mut session_handle = 0_u64;
        let create_status = unsafe {
            ss_balanced_wave_policy_session_create_json(
                create.as_ptr(),
                create.len(),
                &mut session_handle,
            )
        };
        assert_eq!(create_status, 0);
        assert_ne!(session_handle, 0);
        let (output, status) = invoke_session_input_json(
            session_handle,
            &step,
            ss_balanced_wave_policy_session_step_json,
        )
        .unwrap();
        assert_eq!(status, 0);
        assert_eq!(ss_balanced_wave_policy_session_destroy(session_handle), 0);
        let raw_response = String::from_utf8(output).unwrap();
        let parsed: Value = serde_json::from_str(&raw_response).unwrap();
        let receipt_schema = parsed["value"]["actuation"]["receipt"]["schema_version"]
            .as_str()
            .unwrap()
            .to_owned();
        (raw_response, policy_id, receipt_schema, semantic_step)
    }

    fn assert_json_has_no_floating_numbers(value: &Value) {
        match value {
            Value::Array(values) => {
                for value in values {
                    assert_json_has_no_floating_numbers(value);
                }
            }
            Value::Object(values) => {
                for value in values.values() {
                    assert_json_has_no_floating_numbers(value);
                }
            }
            Value::Number(number) => assert!(!number.is_f64()),
            _ => {}
        }
    }

    #[test]
    fn native_step_transport_verification_binds_exact_raw_bytes_and_native_receipt() {
        let (raw_response, policy_id, receipt_schema, semantic_step) =
            native_step_verification_fixture();
        let receipt = verify_balanced_wave_native_step_transport(
            &raw_response,
            &policy_id,
            &receipt_schema,
            semantic_step,
        )
        .unwrap();
        let parsed: Value = serde_json::from_str(&raw_response).unwrap();
        assert_eq!(
            receipt["controller_receipt_sha256"],
            parsed["value"]["actuation"]["receipt_sha256"]
        );
        assert_eq!(
            receipt["native_actuation_receipt_sha256"],
            parsed["value"]["actuation"]["receipt_sha256"]
        );
        assert_eq!(
            receipt["raw_native_response_sha256"],
            format!("sha256:{:x}", Sha256::digest(raw_response.as_bytes()))
        );
        assert_eq!(
            receipt["raw_native_response_byte_length"],
            raw_response.len()
        );
        let mut payload = receipt.clone();
        let declared_payload_sha256 = payload["payload_sha256"].as_str().unwrap().to_owned();
        payload["payload_sha256"] = Value::String(String::new());
        assert_eq!(digest_json(&payload).unwrap(), declared_payload_sha256);
        assert_json_has_no_floating_numbers(&receipt);
    }

    #[test]
    fn native_step_transport_verification_refuses_identity_and_digest_mutations() {
        let (raw_response, policy_id, receipt_schema, semantic_step) =
            native_step_verification_fixture();
        let mut wrong_digest: Value = serde_json::from_str(&raw_response).unwrap();
        wrong_digest["value"]["actuation"]["receipt_sha256"] =
            Value::String(format!("sha256:{}", "0".repeat(64)));
        let wrong_digest = serde_json::to_string(&wrong_digest).unwrap();
        assert_eq!(
            verify_balanced_wave_native_step_transport(
                &wrong_digest,
                &policy_id,
                &receipt_schema,
                semantic_step,
            ),
            Err("GODOT_ADAPTER_NATIVE_STEP_VERIFICATION_RECEIPT_DIGEST_MISMATCH")
        );
        assert_eq!(
            verify_balanced_wave_native_step_transport(
                &raw_response,
                "wrong_policy",
                &receipt_schema,
                semantic_step,
            ),
            Err("GODOT_ADAPTER_NATIVE_STEP_VERIFICATION_POLICY_MISMATCH")
        );
        assert_eq!(
            verify_balanced_wave_native_step_transport(
                &raw_response,
                &policy_id,
                "wrong_receipt_schema",
                semantic_step,
            ),
            Err("GODOT_ADAPTER_NATIVE_STEP_VERIFICATION_RECEIPT_SCHEMA_MISMATCH")
        );
        assert_eq!(
            verify_balanced_wave_native_step_transport(
                &raw_response,
                &policy_id,
                &receipt_schema,
                semantic_step + 1,
            ),
            Err("GODOT_ADAPTER_NATIVE_STEP_VERIFICATION_ACTUATION_STEP_MISMATCH")
        );
        let mut failed_envelope: Value = serde_json::from_str(&raw_response).unwrap();
        failed_envelope["ok"] = Value::Bool(false);
        assert_eq!(
            verify_balanced_wave_native_step_transport(
                &serde_json::to_string(&failed_envelope).unwrap(),
                &policy_id,
                &receipt_schema,
                semantic_step,
            ),
            Err("GODOT_ADAPTER_NATIVE_STEP_VERIFICATION_PUBLIC_ENVELOPE_INVALID")
        );
    }

    #[test]
    fn persistent_session_matches_stateless_bytes_and_fails_after_destroy() {
        let (create, step, legacy) = persistent_session_requests();
        let mut session_handle = 0_u64;
        let create_status = unsafe {
            ss_balanced_wave_policy_session_create_json(
                create.as_ptr(),
                create.len(),
                &mut session_handle,
            )
        };
        assert_eq!(create_status, 0);
        assert_ne!(session_handle, 0);

        let (session_output, session_status) = invoke_session_input_json(
            session_handle,
            &step,
            ss_balanced_wave_policy_session_step_json,
        )
        .unwrap();
        let (stateless_output, stateless_status) =
            invoke_input_json(&legacy, ss_balanced_wave_policy_step_json).unwrap();
        assert_eq!(session_status, stateless_status);
        assert_eq!(session_output, stateless_output);

        assert_eq!(ss_balanced_wave_policy_session_destroy(session_handle), 0);
        let (destroyed_output, destroyed_status) = invoke_session_input_json(
            session_handle,
            &step,
            ss_balanced_wave_policy_session_step_json,
        )
        .unwrap();
        assert_eq!(destroyed_status, 3);
        let destroyed: Value = serde_json::from_slice(&destroyed_output).unwrap();
        assert_eq!(destroyed["ok"], false);
        assert_eq!(destroyed["failure_code"], "REFERENCE_INVALID");
    }

    #[test]
    #[ignore = "development-only; run only through sdk/run_godot_jolt_transport_benchmark.ps1 so release artifacts remain isolated"]
    fn benchmark_single_pass_against_legacy_two_pass_balanced_wave() {
        const ITERATIONS: usize = 2_000;
        let input = balanced_wave_step_request_bytes();
        let representative_output_bytes =
            invoke_input_json(&input, ss_balanced_wave_policy_step_json)
                .unwrap()
                .0
                .len();
        for _ in 0..50 {
            black_box(invoke_input_json(&input, ss_balanced_wave_policy_step_json).unwrap());
            black_box(invoke_input_json_legacy_two_pass(
                &input,
                ss_balanced_wave_policy_step_json,
            ));
        }

        let single_started = Instant::now();
        for _ in 0..ITERATIONS {
            black_box(invoke_input_json(&input, ss_balanced_wave_policy_step_json).unwrap());
        }
        let single_seconds = single_started.elapsed().as_secs_f64();

        let legacy_started = Instant::now();
        for _ in 0..ITERATIONS {
            black_box(invoke_input_json_legacy_two_pass(
                &input,
                ss_balanced_wave_policy_step_json,
            ));
        }
        let legacy_seconds = legacy_started.elapsed().as_secs_f64();
        let speedup = legacy_seconds / single_seconds;
        println!(
            "GODOT_JOLT_TRANSPORT_MICROBENCHMARK iterations={ITERATIONS} \
             input_bytes={} output_bytes={representative_output_bytes} \
             single_seconds={single_seconds:.6} legacy_seconds={legacy_seconds:.6} \
             native_boundary_speedup={speedup:.4}x world_builds=0 physical_authority=false",
            input.len(),
        );
    }

    #[test]
    #[ignore = "development-only; run only through sdk/run_godot_jolt_persistent_session_benchmark.ps1 so release artifacts remain isolated"]
    fn benchmark_persistent_session_against_stateless_single_pass() {
        const ITERATIONS: usize = 5_000;
        let (create, step, stateless) = persistent_session_requests();
        let mut session_handle = 0_u64;
        let create_status = unsafe {
            ss_balanced_wave_policy_session_create_json(
                create.as_ptr(),
                create.len(),
                &mut session_handle,
            )
        };
        assert_eq!(create_status, 0);
        assert_ne!(session_handle, 0);
        let representative_output_bytes = invoke_session_input_json(
            session_handle,
            &step,
            ss_balanced_wave_policy_session_step_json,
        )
        .unwrap()
        .0
        .len();
        for _ in 0..100 {
            black_box(
                invoke_session_input_json(
                    session_handle,
                    &step,
                    ss_balanced_wave_policy_session_step_json,
                )
                .unwrap(),
            );
            black_box(invoke_input_json(&stateless, ss_balanced_wave_policy_step_json).unwrap());
        }

        let session_started = Instant::now();
        for _ in 0..ITERATIONS {
            black_box(
                invoke_session_input_json(
                    session_handle,
                    &step,
                    ss_balanced_wave_policy_session_step_json,
                )
                .unwrap(),
            );
        }
        let session_seconds = session_started.elapsed().as_secs_f64();

        let stateless_started = Instant::now();
        for _ in 0..ITERATIONS {
            black_box(invoke_input_json(&stateless, ss_balanced_wave_policy_step_json).unwrap());
        }
        let stateless_seconds = stateless_started.elapsed().as_secs_f64();
        let speedup = stateless_seconds / session_seconds;
        assert_eq!(ss_balanced_wave_policy_session_destroy(session_handle), 0);
        println!(
            "GODOT_JOLT_PERSISTENT_SESSION_MICROBENCHMARK iterations={ITERATIONS} \
             create_input_bytes={} session_input_bytes={} stateless_input_bytes={} \
             output_bytes={representative_output_bytes} session_seconds={session_seconds:.6} \
             stateless_seconds={stateless_seconds:.6} native_boundary_speedup={speedup:.4}x \
             output_byte_equivalence=true worlds=0 physical_authority=false",
            create.len(),
            step.len(),
            stateless.len(),
        );
    }
}
