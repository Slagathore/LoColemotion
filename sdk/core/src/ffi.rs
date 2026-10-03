use std::collections::HashMap;
use std::ffi::{c_char, c_int};
use std::panic::{AssertUnwindSafe, catch_unwind};
use std::ptr;
use std::slice;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex, OnceLock};

use serde::de::DeserializeOwned;
use serde::{Deserialize, Serialize};
use serde_json::Value;

use crate::actuator_profile::{ActuatorCapProfileRequestV1, resolve_actuator_cap_profile_v1};
use crate::adaptation::{AdaptationResolutionRequestV1, resolve_adaptation_v1};
use crate::canonical::canonical_json_and_digest;
use crate::canonical_actuation::{
    CanonicalVelocityActuationFrameV1, CanonicalVelocityResidualV1, VelocityOnlyHostProfileV1,
    canonicalize_and_compose_legacy_velocity_v1, map_canonical_velocity_to_host_v1,
};
use crate::controller::{
    balanced_wave_profile, balanced_wave_profile_for_policy, candidate35_profile,
};
use crate::coverage::compile_gq15_domain_certificate;
use crate::protocol::{MotionCommand, StateFrame};
use crate::quadruped::{BoundedQuadrupedDescriptor, compile_bounded_quadruped};
use crate::recovery::{
    RecoveryEvaluationRequestV1, RecoveryEvaluationRequestV2, RecoveryEvaluationRequestV3,
    RecoveryEvaluationRequestV4, RecoveryEvaluationRequestV5, RecoveryInitializeRequestV1,
    RecoveryInitializeRequestV2, RecoveryStepRequestV1, RecoveryStepRequestV2,
    RecoveryStepRequestV3, RecoveryStepRequestV4, RecoveryStepRequestV5,
    evaluate_recovery_trace_v1, evaluate_recovery_trace_v2, evaluate_recovery_trace_v3,
    evaluate_recovery_trace_v4, evaluate_recovery_trace_v5, initialize_recovery_v1,
    initialize_recovery_v2, step_recovery_v1, step_recovery_v2, step_recovery_v3, step_recovery_v4,
    step_recovery_v5,
};
use crate::recovery_energy::{
    RecoveryEnergyBalanceAggregationRequestV2, RecoveryEnergyBalanceEvaluationRequestV2,
    RecoveryEnergyBalanceMigrationRequestV1, aggregate_recovery_energy_balance_v2,
    evaluate_recovery_energy_balance_v2, migrate_recovery_energy_balance_v1,
};
use crate::recovery::passive_entry::{RecoveryPassiveEntryStepRequestV1, step_passive_entry_v1};
use crate::recovery_runtime::passive_entry_collection::{
    RecoveryPassiveNativeCollectionRequestV1, collect_passive_native_observation_v1,
};
use crate::recovery_energy_v3::{
    RecoveryEnergyBalanceAggregationRequestV3, RecoveryEnergyBalanceEvaluationRequestV3,
    aggregate_recovery_energy_balance_v3, evaluate_recovery_energy_balance_v3,
};
use crate::recovery_morphology::{RecoveryMorphologyDescriptorV1, compile_recovery_morphology_v1};
use crate::recovery_runtime::{
    RecoveryControlRequestV1, RecoveryControlRequestV2, RecoveryControlRequestV3,
    RecoveryNativeCollectionRequestV1, RecoveryNativeCollectionRequestV2,
    RecoveryNativeCollectionRequestV3, RecoveryStanceControlRequestV1,
    RecoveryStanceControlRequestV2, RecoveryStanceControlRequestV3, RecoveryStanceControlRequestV4,
    collect_native_recovery_observation_v1, collect_native_recovery_observation_v2,
    collect_native_recovery_observation_v3, plan_recovery_control_v1, plan_recovery_control_v2,
    plan_recovery_control_v3, plan_recovery_stance_control_v1, plan_recovery_stance_control_v2,
    plan_recovery_stance_control_v3, plan_recovery_stance_control_v4,
    recovery_development_profile_v1,
};
use crate::runtime::{
    BalancedWaveController, BalancedWaveControllerMemory, Candidate35Controller,
    Candidate35ControllerMemory,
};
use crate::schema::CoreError;
use crate::stability::{
    CentroidalSupportRequestV2, EndpointForceJointMapRequestV2, EndpointForceJointMapRequestV3,
    ScheduledLoadTransferRequestV1, ScheduledLoadTransferRequestV2, ScheduledLoadTransferRequestV3,
    StabilityInfluenceRequestV2, StabilityInfluenceRequestV3, StabilityStateV2,
    bound_stability_influence_v2, bound_stability_influence_v3, command_centroidal_support_v2,
    map_endpoint_force_to_joint_v2, map_endpoint_force_to_joint_v3, observe_stability_v2,
    plan_scheduled_load_transfer_v1, plan_scheduled_load_transfer_v2,
    plan_scheduled_load_transfer_v3,
};

pub const SS_OK: c_int = 0;
pub const SS_INVALID_ARGUMENT: c_int = 1;
pub const SS_BUFFER_TOO_SMALL: c_int = 2;
pub const SS_CORE_ERROR: c_int = 3;
pub const SS_PANIC_CAUGHT: c_int = 4;

#[derive(Serialize)]
struct ApiSuccess<T: Serialize> {
    ok: bool,
    value: T,
}

#[derive(Serialize)]
struct ApiFailure {
    ok: bool,
    failure_code: String,
    detail: String,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct CanonicalJsonRequest {
    schema_version: String,
    value: Value,
}

#[derive(Serialize)]
struct CanonicalJsonReceipt {
    schema_version: &'static str,
    canonical_json: String,
    sha256: String,
    world_build_count: u32,
    physical_acceptance_authority: bool,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Candidate35StepRequest {
    schema_version: String,
    descriptor: BoundedQuadrupedDescriptor,
    memory: Candidate35ControllerMemory,
    state: StateFrame,
    command: MotionCommand,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct BalancedWaveStepRequest {
    schema_version: String,
    descriptor: BoundedQuadrupedDescriptor,
    memory: BalancedWaveControllerMemory,
    state: StateFrame,
    command: MotionCommand,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct BalancedWavePolicyProfileRequest {
    schema_version: String,
    policy_id: String,
    descriptor: BoundedQuadrupedDescriptor,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct BalancedWavePolicyInitialMemoryRequest {
    schema_version: String,
    policy_id: String,
    descriptor: BoundedQuadrupedDescriptor,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct BalancedWavePolicyStepRequest {
    schema_version: String,
    policy_id: String,
    descriptor: BoundedQuadrupedDescriptor,
    memory: BalancedWaveControllerMemory,
    state: StateFrame,
    command: MotionCommand,
    #[serde(default, deserialize_with = "crate::recovery_floor_reference::deserialize_present")]
    floor_reference: Option<crate::recovery_floor_reference::FloorReference>,
    #[serde(default, deserialize_with = "crate::recovery_measured_support_transfer::deserialize_present")]
    measured_body_frame: Option<crate::recovery_measured_support_transfer::MeasuredBodyFrame>,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct BalancedWavePolicySessionCreateRequest {
    schema_version: String,
    policy_id: String,
    descriptor: BoundedQuadrupedDescriptor,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct BalancedWavePolicySessionStepRequest {
    schema_version: String,
    memory: BalancedWaveControllerMemory,
    state: StateFrame,
    command: MotionCommand,
    #[serde(default, deserialize_with = "crate::recovery_floor_reference::deserialize_present")]
    floor_reference: Option<crate::recovery_floor_reference::FloorReference>,
    #[serde(default, deserialize_with = "crate::recovery_measured_support_transfer::deserialize_present")]
    measured_body_frame: Option<crate::recovery_measured_support_transfer::MeasuredBodyFrame>,
}

static NEXT_BALANCED_WAVE_POLICY_SESSION_HANDLE: AtomicU64 = AtomicU64::new(1);
static BALANCED_WAVE_POLICY_SESSIONS: OnceLock<Mutex<HashMap<u64, Arc<BalancedWaveController>>>> =
    OnceLock::new();

fn allocate_balanced_wave_policy_session_handle(counter: &AtomicU64) -> crate::schema::Result<u64> {
    counter
        .fetch_update(Ordering::Relaxed, Ordering::Relaxed, |current| {
            if current == 0 || current == u64::MAX {
                None
            } else {
                Some(current + 1)
            }
        })
        .map_err(|_| {
            CoreError::Internal("balanced_wave_policy_session_handle_space_exhausted".to_owned())
        })
}

fn balanced_wave_policy_sessions() -> &'static Mutex<HashMap<u64, Arc<BalancedWaveController>>> {
    BALANCED_WAVE_POLICY_SESSIONS.get_or_init(|| Mutex::new(HashMap::new()))
}

fn lock_balanced_wave_policy_sessions()
-> crate::schema::Result<std::sync::MutexGuard<'static, HashMap<u64, Arc<BalancedWaveController>>>>
{
    balanced_wave_policy_sessions().lock().map_err(|_| {
        CoreError::Internal("balanced_wave_policy_session_registry_poisoned".to_owned())
    })
}

#[derive(Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct ObserveStabilityV2Request {
    schema_version: String,
    descriptor: BoundedQuadrupedDescriptor,
    state: StabilityStateV2,
}

#[derive(Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct PlanScheduledLoadTransferV1Request {
    schema_version: String,
    descriptor: BoundedQuadrupedDescriptor,
    request: ScheduledLoadTransferRequestV1,
}

#[derive(Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct PlanScheduledLoadTransferV2Request {
    schema_version: String,
    descriptor: BoundedQuadrupedDescriptor,
    request: ScheduledLoadTransferRequestV2,
}

#[derive(Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct PlanScheduledLoadTransferV3Request {
    schema_version: String,
    descriptor: BoundedQuadrupedDescriptor,
    request: ScheduledLoadTransferRequestV3,
}

#[derive(Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct BoundStabilityInfluenceV2Request {
    schema_version: String,
    descriptor: BoundedQuadrupedDescriptor,
    request: StabilityInfluenceRequestV2,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct BoundStabilityInfluenceV3Request {
    schema_version: String,
    descriptor: BoundedQuadrupedDescriptor,
    request: StabilityInfluenceRequestV3,
}

#[derive(Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct MapEndpointForceToJointV2Request {
    schema_version: String,
    descriptor: BoundedQuadrupedDescriptor,
    request: EndpointForceJointMapRequestV2,
}

#[derive(Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct MapEndpointForceToJointV3Request {
    schema_version: String,
    descriptor: BoundedQuadrupedDescriptor,
    request: EndpointForceJointMapRequestV3,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct CanonicalVelocityComposeRequestV1 {
    schema_version: String,
    descriptor: BoundedQuadrupedDescriptor,
    source_actuation: crate::protocol::ActuationFrame,
    ordered_stability_residuals: Vec<CanonicalVelocityResidualV1>,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct CanonicalVelocityHostMapRequestV1 {
    schema_version: String,
    descriptor: BoundedQuadrupedDescriptor,
    canonical_actuation: CanonicalVelocityActuationFrameV1,
    host_profile: VelocityOnlyHostProfileV1,
}

fn failure_bytes(error: &CoreError) -> Vec<u8> {
    let display = error.to_string();
    let (failure_code, detail) = display
        .split_once(':')
        .map_or(("INTERNAL_ERROR", display.as_str()), |parts| parts);
    serde_json::to_vec(&ApiFailure {
        ok: false,
        failure_code: failure_code.to_owned(),
        detail: detail.to_owned(),
    })
    .unwrap_or_else(|_| {
        br#"{"detail":"error serialization failed","failure_code":"INTERNAL_ERROR","ok":false}"#
            .to_vec()
    })
}

unsafe fn copy_output(
    bytes: &[u8],
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    if output_length.is_null() {
        return SS_INVALID_ARGUMENT;
    }
    unsafe {
        *output_length = bytes.len();
    }
    if output.is_null() || output_capacity < bytes.len() {
        return SS_BUFFER_TOO_SMALL;
    }
    unsafe {
        ptr::copy_nonoverlapping(bytes.as_ptr(), output, bytes.len());
    }
    SS_OK
}

fn parse_descriptor(
    input: *const u8,
    input_length: usize,
) -> Result<BoundedQuadrupedDescriptor, CoreError> {
    if input.is_null() || input_length == 0 {
        return Err(CoreError::Schema("empty_input".to_owned()));
    }
    let bytes = unsafe { slice::from_raw_parts(input, input_length) };
    serde_json::from_slice(bytes).map_err(|error| CoreError::Schema(error.to_string()))
}

unsafe fn descriptor_call<T, F>(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
    operation: F,
) -> c_int
where
    T: Serialize,
    F: FnOnce(BoundedQuadrupedDescriptor) -> Result<T, CoreError>,
{
    let guarded = catch_unwind(AssertUnwindSafe(|| {
        let descriptor = parse_descriptor(input, input_length)?;
        let value = operation(descriptor)?;
        serde_json::to_vec(&ApiSuccess { ok: true, value })
            .map_err(|error| CoreError::Serialization(error.to_string()))
    }));
    match guarded {
        Ok(Ok(bytes)) => unsafe { copy_output(&bytes, output, output_capacity, output_length) },
        Ok(Err(error)) => {
            let bytes = failure_bytes(&error);
            let copy_status =
                unsafe { copy_output(&bytes, output, output_capacity, output_length) };
            if copy_status == SS_OK {
                SS_CORE_ERROR
            } else {
                copy_status
            }
        }
        Err(_) => {
            let bytes = br#"{"detail":"panic caught at C boundary","failure_code":"INTERNAL_PANIC_CAUGHT","ok":false}"#;
            let copy_status = unsafe { copy_output(bytes, output, output_capacity, output_length) };
            if copy_status == SS_OK {
                SS_PANIC_CAUGHT
            } else {
                copy_status
            }
        }
    }
}

unsafe fn json_input_call<I, T, F>(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
    operation: F,
) -> c_int
where
    I: DeserializeOwned,
    T: Serialize,
    F: FnOnce(I) -> Result<T, CoreError>,
{
    let guarded = catch_unwind(AssertUnwindSafe(|| {
        if input.is_null() || input_length == 0 {
            return Err(CoreError::Schema("empty_input".to_owned()));
        }
        let bytes = unsafe { slice::from_raw_parts(input, input_length) };
        let request: I =
            serde_json::from_slice(bytes).map_err(|error| CoreError::Schema(error.to_string()))?;
        let value = operation(request)?;
        serde_json::to_vec(&ApiSuccess { ok: true, value })
            .map_err(|error| CoreError::Serialization(error.to_string()))
    }));
    match guarded {
        Ok(Ok(bytes)) => unsafe { copy_output(&bytes, output, output_capacity, output_length) },
        Ok(Err(error)) => {
            let bytes = failure_bytes(&error);
            let copy_status =
                unsafe { copy_output(&bytes, output, output_capacity, output_length) };
            if copy_status == SS_OK {
                SS_CORE_ERROR
            } else {
                copy_status
            }
        }
        Err(_) => {
            let bytes = br#"{"detail":"panic caught at C boundary","failure_code":"INTERNAL_PANIC_CAUGHT","ok":false}"#;
            let copy_status = unsafe { copy_output(bytes, output, output_capacity, output_length) };
            if copy_status == SS_OK {
                SS_PANIC_CAUGHT
            } else {
                copy_status
            }
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn ss_version() -> *const c_char {
    concat!(env!("CARGO_PKG_VERSION"), "\0").as_ptr().cast()
}

#[unsafe(no_mangle)]
/// Canonicalize and digest arbitrary strict JSON with the SDK's shared policy.
///
/// # Safety
///
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. When non-null, `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_canonicalize_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(
            input,
            input_length,
            output,
            output_capacity,
            output_length,
            |request: CanonicalJsonRequest| {
                if request.schema_version != "sporespore_canonical_json_request_v1" {
                    return Err(CoreError::Schema(
                        "canonical_json_request_version".to_owned(),
                    ));
                }
                let (canonical_json, sha256) = canonical_json_and_digest(&request.value)?;
                Ok(CanonicalJsonReceipt {
                    schema_version: "sporespore_canonical_json_receipt_v1",
                    canonical_json,
                    sha256,
                    world_build_count: 0,
                    physical_acceptance_authority: false,
                })
            },
        )
    }
}

#[unsafe(no_mangle)]
/// Compile one strict bounded-quadruped JSON descriptor.
///
/// # Safety
///
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. When non-null, `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_compile_bounded_quadruped_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    unsafe {
        descriptor_call(
            input,
            input_length,
            output,
            output_capacity,
            output_length,
            compile_bounded_quadruped,
        )
    }
}

#[unsafe(no_mangle)]
/// Compile one strict recovery-morphology descriptor and evaluate its exact
/// canonical prone ground geometry without constructing a physics world.
///
/// Valid but infeasible geometry returns a typed successful refusal receipt.
/// Malformed descriptors still fail through the ordinary core error envelope.
///
/// # Safety
///
/// The input pointer must address input_length readable bytes. The
/// output_length pointer must address one writable usize. When non-null, the
/// output pointer must address output_capacity writable bytes and must not
/// overlap input.
pub unsafe extern "C" fn ss_compile_recovery_morphology_v1_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call::<RecoveryMorphologyDescriptorV1, _, _>(
            input,
            input_length,
            output,
            output_capacity,
            output_length,
            compile_recovery_morphology_v1,
        )
    }
}

#[unsafe(no_mangle)]
/// Resolve one named, exact-scope actuator-cap profile.
///
/// A valid descriptor outside the profile's exact support scope returns an
/// explicit successful refusal receipt. Malformed or out-of-bounds descriptors
/// still fail through the ordinary core error envelope. This call is pure: it
/// builds no world and applies no host actuation.
///
/// # Safety
///
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. When non-null, `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_resolve_actuator_cap_profile_v1_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(
            input,
            input_length,
            output,
            output_capacity,
            output_length,
            |request: ActuatorCapProfileRequestV1| resolve_actuator_cap_profile_v1(request),
        )
    }
}

#[unsafe(no_mangle)]
/// Initialize one exact-scope portable recovery supervisor from strict JSON.
///
/// This operation compiles and validates schemas only. It constructs no host
/// model or world, performs no solver step, and emits no controller command.
///
/// # Safety
///
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. When non-null, `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_recovery_initialize_v1_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(
            input,
            input_length,
            output,
            output_capacity,
            output_length,
            |request: RecoveryInitializeRequestV1| initialize_recovery_v1(request),
        )
    }
}

#[unsafe(no_mangle)]
/// Initialize recovery through the recovery-morphology-aware V2 request.
///
/// V2 requires an exact versioned morphology context. The V1 request and
/// entrypoint remain unchanged and continue to identify the legacy bounded
/// morphology.
///
/// # Safety
///
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. When non-null, `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_recovery_initialize_v2_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(
            input,
            input_length,
            output,
            output_capacity,
            output_length,
            |request: RecoveryInitializeRequestV2| initialize_recovery_v2(request),
        )
    }
}

#[unsafe(no_mangle)]
/// Classify one already-observed zero-world recovery semantic step.
///
/// Native observations remain a typed refusal until a later physical
/// threshold profile is prospectively frozen.
///
/// # Safety
///
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. When non-null, `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_recovery_step_v1_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(
            input,
            input_length,
            output,
            output_capacity,
            output_length,
            |request: RecoveryStepRequestV1| step_recovery_v1(request),
        )
    }
}

#[unsafe(no_mangle)]
/// Classify and advance one recovery-morphology-aware V2 observation.
///
/// # Safety
///
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. When non-null, `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_recovery_step_v2_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(
            input,
            input_length,
            output,
            output_capacity,
            output_length,
            |request: RecoveryStepRequestV2| step_recovery_v2(request),
        )
    }
}

#[unsafe(no_mangle)]
/// Classify and advance one morphology-aware true observation-V2 step.
///
/// # Safety
///
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. When non-null, `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_recovery_step_v3_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(
            input,
            input_length,
            output,
            output_capacity,
            output_length,
            |request: RecoveryStepRequestV3| step_recovery_v3(request),
        )
    }
}

#[unsafe(no_mangle)]
/// Classify and advance one morphology-aware observation-V3 recovery step.
///
/// # Safety
///
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. When non-null, `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_recovery_step_v4_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(
            input,
            input_length,
            output,
            output_capacity,
            output_length,
            |request: RecoveryStepRequestV4| step_recovery_v4(request),
        )
    }
}

#[unsafe(no_mangle)]
/// Advance one observation-V3 recovery step with explicit energy authority.
///
/// # Safety
///
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. When non-null, `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_recovery_step_v5_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(
            input,
            input_length,
            output,
            output_capacity,
            output_length,
            |request: RecoveryStepRequestV5| step_recovery_v5(request),
        )
    }
}

#[unsafe(no_mangle)]
/// Observe bounded passive descent and initialize at a measured prone boundary.
/// This additive development API creates no world and grants no acceptance.
///
/// # Safety
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. When non-null, `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_recovery_passive_entry_step_v1_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(input, input_length, output, output_capacity, output_length,
            |request: RecoveryPassiveEntryStepRequestV1| step_passive_entry_v1(request))
    }
}

#[unsafe(no_mangle)]
/// Validate the original passive source and select the distinct R10K entry.
/// No world or solver step is created; an optional initial control is a plan.
///
/// # Safety
/// `input` addresses `input_length` readable bytes; `output_length` addresses
/// one writable `usize`. Non-null output addresses `output_capacity` writable
/// bytes and must not overlap input.
pub unsafe extern "C" fn ss_recovery_r10k_entry_control_v1_json(
    input: *const u8, input_length: usize, output: *mut u8,
    output_capacity: usize, output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(input, input_length, output, output_capacity, output_length,
            |request: crate::recovery_runtime::partial_fall_control::EntryControlRequest|
                crate::recovery_runtime::partial_fall_control::entry_control(request))
    }
}

#[unsafe(no_mangle)]
/// Validate a source-bound partial-task step and plan unchanged V20/V7 control.
/// The partial supervisor never supplies canonical prone-to-standing authority.
///
/// # Safety
/// `input` addresses `input_length` readable bytes; `output_length` addresses
/// one writable `usize`. Non-null output addresses `output_capacity` writable
/// bytes and must not overlap input.
pub unsafe extern "C" fn ss_recovery_partial_fall_step_control_v1_json(
    input: *const u8, input_length: usize, output: *mut u8,
    output_capacity: usize, output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(input, input_length, output, output_capacity, output_length,
            |request: crate::recovery_runtime::partial_fall_control::StepControlRequest|
                crate::recovery_runtime::partial_fall_control::step_control(request))
    }
}

#[unsafe(no_mangle)]
/// Validate the original passive source and select the distinct R10Q upright entry.
/// No world or solver step is created; an optional initial control is a plan.
///
/// # Safety
/// `input` addresses `input_length` readable bytes; `output_length` addresses
/// one writable `usize`. Non-null output addresses `output_capacity` writable
/// bytes and must not overlap input.
pub unsafe extern "C" fn ss_recovery_r10q_upright_entry_control_v1_json(
    input: *const u8, input_length: usize, output: *mut u8,
    output_capacity: usize, output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(input, input_length, output, output_capacity, output_length,
            |request: crate::recovery_runtime::upright_recovery_control::EntryControlRequest|
                crate::recovery_runtime::upright_recovery_control::entry_control(request))
    }
}

#[unsafe(no_mangle)]
/// Validate a source-bound upright-task step and plan unchanged V20/V7 control.
/// The upright supervisor never supplies canonical prone-to-standing authority.
///
/// # Safety
/// `input` addresses `input_length` readable bytes; `output_length` addresses
/// one writable `usize`. Non-null output addresses `output_capacity` writable
/// bytes and must not overlap input.
pub unsafe extern "C" fn ss_recovery_upright_step_control_v1_json(
    input: *const u8, input_length: usize, output: *mut u8,
    output_capacity: usize, output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(input, input_length, output, output_capacity, output_length,
            |request: crate::recovery_runtime::upright_recovery_control::StepControlRequest|
                crate::recovery_runtime::upright_recovery_control::step_control(request))
    }
}

#[unsafe(no_mangle)]
/// Validate a source-bound upright-task step and plan the R10R V20/V12/V7 composition.
/// The upright supervisor never supplies canonical prone-to-standing authority.
///
/// # Safety
/// `input` addresses `input_length` readable bytes; `output_length` addresses
/// one writable `usize`. Non-null output addresses `output_capacity` writable
/// bytes and must not overlap input.
pub unsafe extern "C" fn ss_recovery_r10r_upright_step_control_v1_json(
    input: *const u8, input_length: usize, output: *mut u8,
    output_capacity: usize, output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(input, input_length, output, output_capacity, output_length,
            |request: crate::recovery_runtime::upright_direct_rise_control::StepControlRequest|
                crate::recovery_runtime::upright_direct_rise_control::step_control(request))
    }
}

#[unsafe(no_mangle)]
/// Retain original entry selection and separately plan R10Y partial control.
///
/// # Safety
/// Input addresses input_length readable bytes. output_length addresses one
/// writable usize. Non-null output addresses output_capacity writable bytes
/// and must not overlap input.
pub unsafe extern "C" fn ss_recovery_r10y_partial_entry_control_v1_json(
    input: *const u8, input_length: usize, output: *mut u8,
    output_capacity: usize, output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(input, input_length, output, output_capacity, output_length,
            |request: crate::recovery_runtime::partial_direct_neutral_control::EntryControlRequest|
                crate::recovery_runtime::partial_direct_neutral_control::entry_control(request))
    }
}

#[unsafe(no_mangle)]
/// Validate the unchanged partial task and plan the separate R10Y V21/V7 law.
///
/// # Safety
/// Input addresses input_length readable bytes. output_length addresses one
/// writable usize. Non-null output addresses output_capacity writable bytes
/// and must not overlap input.
pub unsafe extern "C" fn ss_recovery_r10y_partial_step_control_v1_json(
    input: *const u8, input_length: usize, output: *mut u8,
    output_capacity: usize, output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(input, input_length, output, output_capacity, output_length,
            |request: crate::recovery_runtime::partial_direct_neutral_control::StepControlRequest|
                crate::recovery_runtime::partial_direct_neutral_control::step_control(request))
    }
}

#[unsafe(no_mangle)]
/// Retain original entry selection and separately plan R10Z partial control.
///
/// # Safety
/// Input addresses input_length readable bytes. output_length addresses one
/// writable usize. Non-null output addresses output_capacity writable bytes
/// and must not overlap input.
pub unsafe extern "C" fn ss_recovery_r10z_partial_entry_control_v1_json(
    input: *const u8, input_length: usize, output: *mut u8,
    output_capacity: usize, output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(input, input_length, output, output_capacity, output_length,
            |request: crate::recovery_runtime::partial_pose_geometry_composition::EntryControlRequest|
                crate::recovery_runtime::partial_pose_geometry_composition::entry_control(request))
    }
}

#[unsafe(no_mangle)]
/// Validate the unchanged partial task and plan the separate R10Z V22/V7 law.
///
/// # Safety
/// Input addresses input_length readable bytes. output_length addresses one
/// writable usize. Non-null output addresses output_capacity writable bytes
/// and must not overlap input.
pub unsafe extern "C" fn ss_recovery_r10z_partial_step_control_v1_json(
    input: *const u8, input_length: usize, output: *mut u8,
    output_capacity: usize, output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(input, input_length, output, output_capacity, output_length,
            |request: crate::recovery_runtime::partial_pose_geometry_composition::StepControlRequest|
                crate::recovery_runtime::partial_pose_geometry_composition::step_control(request))
    }
}

#[unsafe(no_mangle)]
/// Retain original entry selection and separately plan R10AA partial control.
///
/// # Safety
/// Input addresses input_length readable bytes. output_length addresses one
/// writable usize. Non-null output addresses output_capacity writable bytes
/// and must not overlap input.
pub unsafe extern "C" fn ss_recovery_r10aa_partial_entry_control_v1_json(
    input: *const u8, input_length: usize, output: *mut u8,
    output_capacity: usize, output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(input, input_length, output, output_capacity, output_length,
            |request: crate::recovery_runtime::partial_load_seeking_composition::EntryControlRequest|
                crate::recovery_runtime::partial_load_seeking_composition::entry_control(request))
    }
}

#[unsafe(no_mangle)]
/// Validate the unchanged partial task and plan the separate R10AA V23/V7 law.
///
/// # Safety
/// Input addresses input_length readable bytes. output_length addresses one
/// writable usize. Non-null output addresses output_capacity writable bytes
/// and must not overlap input.
pub unsafe extern "C" fn ss_recovery_r10aa_partial_step_control_v1_json(
    input: *const u8, input_length: usize, output: *mut u8,
    output_capacity: usize, output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(input, input_length, output, output_capacity, output_length,
            |request: crate::recovery_runtime::partial_load_seeking_composition::StepControlRequest|
                crate::recovery_runtime::partial_load_seeking_composition::step_control(request))
    }
}

#[unsafe(no_mangle)]
/// Retain original entry selection and separately plan R10AB partial control.
///
/// # Safety
/// Input addresses input_length readable bytes. output_length addresses one
/// writable usize. Non-null output addresses output_capacity writable bytes
/// and must not overlap input.
pub unsafe extern "C" fn ss_recovery_r10ab_partial_entry_control_v1_json(
    input: *const u8, input_length: usize, output: *mut u8,
    output_capacity: usize, output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(input, input_length, output, output_capacity, output_length,
            |request: crate::recovery_runtime::partial_downward_rise_composition::EntryControlRequest|
                crate::recovery_runtime::partial_downward_rise_composition::entry_control(request))
    }
}

#[unsafe(no_mangle)]
/// Validate the unchanged partial task and plan the separate R10AB V24/V7 law.
///
/// # Safety
/// Input addresses input_length readable bytes. output_length addresses one
/// writable usize. Non-null output addresses output_capacity writable bytes
/// and must not overlap input.
pub unsafe extern "C" fn ss_recovery_r10ab_partial_step_control_v1_json(
    input: *const u8, input_length: usize, output: *mut u8,
    output_capacity: usize, output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(input, input_length, output, output_capacity, output_length,
            |request: crate::recovery_runtime::partial_downward_rise_composition::StepControlRequest|
                crate::recovery_runtime::partial_downward_rise_composition::step_control(request))
    }
}

#[unsafe(no_mangle)]
/// Retain original entry selection and separately plan R10AI partial control.
///
/// # Safety
/// Input addresses input_length readable bytes. output_length addresses one
/// writable usize. Non-null output addresses output_capacity writable bytes
/// and must not overlap input.
pub unsafe extern "C" fn ss_recovery_r10ai_partial_entry_control_v1_json(
    input: *const u8, input_length: usize, output: *mut u8,
    output_capacity: usize, output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(input, input_length, output, output_capacity, output_length,
            |request: crate::recovery_runtime::partial_concurrent_load_rise_composition::EntryControlRequest|
                crate::recovery_runtime::partial_concurrent_load_rise_composition::entry_control(request))
    }
}

#[unsafe(no_mangle)]
/// Validate the unchanged partial task and plan the separate R10AI V25/V7 law.
///
/// # Safety
/// Input addresses input_length readable bytes. output_length addresses one
/// writable usize. Non-null output addresses output_capacity writable bytes
/// and must not overlap input.
pub unsafe extern "C" fn ss_recovery_r10ai_partial_step_control_v1_json(
    input: *const u8, input_length: usize, output: *mut u8,
    output_capacity: usize, output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(input, input_length, output, output_capacity, output_length,
            |request: crate::recovery_runtime::partial_concurrent_load_rise_composition::StepControlRequest|
                crate::recovery_runtime::partial_concurrent_load_rise_composition::step_control(request))
    }
}

/// R10AJ development-only native composition; no world or release authority.
#[unsafe(no_mangle)]
/// Retain original entry selection and separately plan R10AJ partial control.
///
/// # Safety
/// Input addresses input_length readable bytes. output_length addresses one
/// writable usize. Non-null output addresses output_capacity writable bytes
/// and must not overlap input.
pub unsafe extern "C" fn ss_recovery_r10aj_partial_entry_control_v1_json(
    input: *const u8, input_length: usize, output: *mut u8,
    output_capacity: usize, output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(input, input_length, output, output_capacity, output_length,
            |request: crate::recovery_runtime::partial_hip_recenter_composition::EntryControlRequest|
                crate::recovery_runtime::partial_hip_recenter_composition::entry_control(request))
    }
}

#[unsafe(no_mangle)]
/// Validate the unchanged partial task and plan the separate R10AJ V26/V7 law.
///
/// # Safety
/// Input addresses input_length readable bytes. output_length addresses one
/// writable usize. Non-null output addresses output_capacity writable bytes
/// and must not overlap input.
pub unsafe extern "C" fn ss_recovery_r10aj_partial_step_control_v1_json(
    input: *const u8, input_length: usize, output: *mut u8,
    output_capacity: usize, output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(input, input_length, output, output_capacity, output_length,
            |request: crate::recovery_runtime::partial_hip_recenter_composition::StepControlRequest|
                crate::recovery_runtime::partial_hip_recenter_composition::step_control(request))
    }
}

/// R10AM development-only native composition; no world or release authority.
#[unsafe(no_mangle)]
/// Retain original entry selection and separately plan R10AM partial control.
///
/// # Safety
/// Input addresses input_length readable bytes. output_length addresses one
/// writable usize. Non-null output addresses output_capacity writable bytes
/// and must not overlap input.
pub unsafe extern "C" fn ss_recovery_r10am_partial_entry_control_v1_json(
    input: *const u8, input_length: usize, output: *mut u8,
    output_capacity: usize, output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(input, input_length, output, output_capacity, output_length,
            |request: crate::recovery_runtime::partial_support_anchored_composition::EntryControlRequest|
                crate::recovery_runtime::partial_support_anchored_composition::entry_control(request))
    }
}

#[unsafe(no_mangle)]
/// Validate the unchanged partial task and plan the separate R10AM V27/V7 law.
///
/// # Safety
/// Input addresses input_length readable bytes. output_length addresses one
/// writable usize. Non-null output addresses output_capacity writable bytes
/// and must not overlap input.
pub unsafe extern "C" fn ss_recovery_r10am_partial_step_control_v1_json(
    input: *const u8, input_length: usize, output: *mut u8,
    output_capacity: usize, output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(input, input_length, output, output_capacity, output_length,
            |request: crate::recovery_runtime::partial_support_anchored_composition::StepControlRequest|
                crate::recovery_runtime::partial_support_anchored_composition::step_control(request))
    }
}

/// R10AP development-only native composition; no world or release authority.
#[unsafe(no_mangle)]
/// Retain original entry selection and separately plan R10AP partial control.
///
/// # Safety
/// Input addresses input_length readable bytes. output_length addresses one
/// writable usize. Non-null output addresses output_capacity writable bytes
/// and must not overlap input.
pub unsafe extern "C" fn ss_recovery_r10ap_partial_entry_control_v1_json(
    input: *const u8, input_length: usize, output: *mut u8,
    output_capacity: usize, output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(input, input_length, output, output_capacity, output_length,
            |request: crate::recovery_runtime::partial_progressive_headroom_composition::EntryControlRequest|
                crate::recovery_runtime::partial_progressive_headroom_composition::entry_control(request))
    }
}

#[unsafe(no_mangle)]
/// Validate the unchanged partial task and plan the separate R10AP V28/V7 law.
///
/// # Safety
/// Input addresses input_length readable bytes. output_length addresses one
/// writable usize. Non-null output addresses output_capacity writable bytes
/// and must not overlap input.
pub unsafe extern "C" fn ss_recovery_r10ap_partial_step_control_v1_json(
    input: *const u8, input_length: usize, output: *mut u8,
    output_capacity: usize, output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(input, input_length, output, output_capacity, output_length,
            |request: crate::recovery_runtime::partial_progressive_headroom_composition::StepControlRequest|
                crate::recovery_runtime::partial_progressive_headroom_composition::step_control(request))
    }
}

/// R10DD development-only native composition; no world or release authority.
#[unsafe(no_mangle)]
/// Retain original entry selection and separately plan R10DD partial control.
///
/// # Safety
/// Input addresses input_length readable bytes. output_length addresses one
/// writable usize. Non-null output addresses output_capacity writable bytes
/// and must not overlap input.
pub unsafe extern "C" fn ss_recovery_r10dd_partial_entry_control_v1_json(
    input: *const u8, input_length: usize, output: *mut u8,
    output_capacity: usize, output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(input, input_length, output, output_capacity, output_length,
            |request: crate::recovery_runtime::partial_native_reference_composition::EntryControlRequest|
                crate::recovery_runtime::partial_native_reference_composition::entry_control(request))
    }
}

#[unsafe(no_mangle)]
/// Validate the unchanged partial task and plan the separate R10DD finite V29 reference.
///
/// # Safety
/// Input addresses input_length readable bytes. output_length addresses one
/// writable usize. Non-null output addresses output_capacity writable bytes
/// and must not overlap input.
pub unsafe extern "C" fn ss_recovery_r10dd_partial_step_control_v1_json(
    input: *const u8, input_length: usize, output: *mut u8,
    output_capacity: usize, output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(input, input_length, output, output_capacity, output_length,
            |request: crate::recovery_runtime::partial_native_reference_composition::StepControlRequest|
                crate::recovery_runtime::partial_native_reference_composition::step_control(request))
    }
}

#[unsafe(no_mangle)]
/// Replay a candidate and matched zero-command recovery trace from strict JSON.
///
/// The R24D2 evaluator has synthetic-canary authority only; it cannot emit a
/// physical result or a prone-to-standing claim.
///
/// # Safety
///
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. When non-null, `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_recovery_evaluate_trace_v1_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(
            input,
            input_length,
            output,
            output_capacity,
            output_length,
            |request: RecoveryEvaluationRequestV1| evaluate_recovery_trace_v1(request),
        )
    }
}

#[unsafe(no_mangle)]
/// Replay candidate and matched-zero traces under an exact V2 morphology context.
///
/// # Safety
///
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. When non-null, `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_recovery_evaluate_trace_v2_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(
            input,
            input_length,
            output,
            output_capacity,
            output_length,
            |request: RecoveryEvaluationRequestV2| evaluate_recovery_trace_v2(request),
        )
    }
}

#[unsafe(no_mangle)]
/// Replay morphology-aware candidate and matched-zero observation-V2 traces.
///
/// # Safety
///
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. When non-null, `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_recovery_evaluate_trace_v3_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(
            input,
            input_length,
            output,
            output_capacity,
            output_length,
            |request: RecoveryEvaluationRequestV3| evaluate_recovery_trace_v3(request),
        )
    }
}

#[unsafe(no_mangle)]
/// Replay morphology-aware candidate and matched-zero observation-V3 traces.
///
/// # Safety
///
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. When non-null, `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_recovery_evaluate_trace_v4_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(
            input,
            input_length,
            output,
            output_capacity,
            output_length,
            |request: RecoveryEvaluationRequestV4| evaluate_recovery_trace_v4(request),
        )
    }
}

#[unsafe(no_mangle)]
/// Replay observation-V3 traces under an explicit development energy authority.
///
/// # Safety
///
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. When non-null, `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_recovery_evaluate_trace_v5_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(
            input,
            input_length,
            output,
            output_capacity,
            output_length,
            |request: RecoveryEvaluationRequestV5| evaluate_recovery_trace_v5(request),
        )
    }
}

#[unsafe(no_mangle)]
/// Aggregate ordered measured recovery-energy increments into the V2 ledger.
///
/// This pure boundary constructs no model or world and takes no solver step.
///
/// # Safety
///
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. When non-null, `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_recovery_energy_balance_aggregate_v2_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(
            input,
            input_length,
            output,
            output_capacity,
            output_length,
            |request: RecoveryEnergyBalanceAggregationRequestV2| {
                aggregate_recovery_energy_balance_v2(request)
            },
        )
    }
}

#[unsafe(no_mangle)]
/// Evaluate a supplied versioned V2 recovery-energy ledger without a threshold.
///
/// # Safety
///
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. When non-null, `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_recovery_energy_balance_evaluate_v2_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(
            input,
            input_length,
            output,
            output_capacity,
            output_length,
            |request: RecoveryEnergyBalanceEvaluationRequestV2| {
                evaluate_recovery_energy_balance_v2(request)
            },
        )
    }
}

#[unsafe(no_mangle)]
/// Aggregate ordered measured recovery-energy increments into the V3 ledger.
///
/// This additive pure boundary includes signed discrete-staging exchange and
/// constructs no model or world and takes no solver step.
///
/// # Safety
///
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. When non-null, `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_recovery_energy_balance_aggregate_v3_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(
            input,
            input_length,
            output,
            output_capacity,
            output_length,
            |request: RecoveryEnergyBalanceAggregationRequestV3| {
                aggregate_recovery_energy_balance_v3(request)
            },
        )
    }
}

#[unsafe(no_mangle)]
/// Evaluate a supplied versioned V3 recovery-energy ledger without a threshold.
///
/// # Safety
///
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. When non-null, `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_recovery_energy_balance_evaluate_v3_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(
            input,
            input_length,
            output,
            output_capacity,
            output_length,
            |request: RecoveryEnergyBalanceEvaluationRequestV3| {
                evaluate_recovery_energy_balance_v3(request)
            },
        )
    }
}

#[unsafe(no_mangle)]
/// Explicitly migrate recovery-energy ledger values between V1 and V2.
///
/// Nonzero signed V2 exchange produces a typed downgrade refusal rather than
/// an implicit clamp or relabelling.
///
/// # Safety
///
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. When non-null, `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_recovery_energy_balance_migrate_v1_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(
            input,
            input_length,
            output,
            output_capacity,
            output_length,
            |request: RecoveryEnergyBalanceMigrationRequestV1| {
                migrate_recovery_energy_balance_v1(request)
            },
        )
    }
}

#[unsafe(no_mangle)]
/// Return the prospectively frozen exact-s169 recovery development profile.
///
/// The profile separates repeatable MuJoCo development cells from held-out
/// native-engine decision cells and grants no physical execution, acceptance,
/// prone-to-standing, equivalence, or release authority.
///
/// # Safety
///
/// `output_length` must address one writable `usize`. When non-null, `output`
/// must address `output_capacity` writable bytes.
pub unsafe extern "C" fn ss_recovery_development_profile_v1_json(
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    let guarded = catch_unwind(AssertUnwindSafe(|| {
        serde_json::to_vec(&ApiSuccess {
            ok: true,
            value: recovery_development_profile_v1(),
        })
    }));
    match guarded {
        Ok(Ok(bytes)) => unsafe { copy_output(&bytes, output, output_capacity, output_length) },
        Ok(Err(error)) => {
            let bytes = failure_bytes(&CoreError::Serialization(error.to_string()));
            let copy_status =
                unsafe { copy_output(&bytes, output, output_capacity, output_length) };
            if copy_status == SS_OK {
                SS_CORE_ERROR
            } else {
                copy_status
            }
        }
        Err(_) => SS_PANIC_CAUGHT,
    }
}

#[unsafe(no_mangle)]
/// Validate one complete native post-step recovery observation from strict JSON.
///
/// This zero-world boundary validates a supplied native observation. It does
/// not itself sample a runtime, construct a model or world, or take a solver
/// step.
///
/// # Safety
///
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. When non-null, `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_recovery_collect_native_v1_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(
            input,
            input_length,
            output,
            output_capacity,
            output_length,
            |request: RecoveryNativeCollectionRequestV1| {
                collect_native_recovery_observation_v1(request)
            },
        )
    }
}

#[unsafe(no_mangle)]
/// Validate a native post-step observation under an exact V2 morphology context.
///
/// # Safety
///
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. When non-null, `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_recovery_collect_native_v2_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(
            input,
            input_length,
            output,
            output_capacity,
            output_length,
            |request: RecoveryNativeCollectionRequestV2| {
                collect_native_recovery_observation_v2(request)
            },
        )
    }
}

#[unsafe(no_mangle)]
/// Validate one MuJoCo observation-V2 publication and its source binding.
///
/// # Safety
///
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. When non-null, `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_recovery_collect_native_v3_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(
            input,
            input_length,
            output,
            output_capacity,
            output_length,
            |request: RecoveryNativeCollectionRequestV3| {
                collect_native_recovery_observation_v3(request)
            },
        )
    }
}

#[unsafe(no_mangle)]
/// Validate source-bound, controller-free passive descent without a controller step.
///
/// # Safety
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. Non-null `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_recovery_collect_passive_native_v1_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(input, input_length, output, output_capacity, output_length,
            |request: RecoveryPassiveNativeCollectionRequestV1| {
                collect_passive_native_observation_v1(request)
            })
    }
}

#[unsafe(no_mangle)]
/// Plan one deterministic exact-s169 recovery control step from strict JSON.
///
/// The returned canonical command is engine-neutral and does not apply itself
/// to any host. Matched-zero and stance-handoff requests remain actuation-free.
///
/// # Safety
///
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. When non-null, `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_recovery_plan_control_v1_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(
            input,
            input_length,
            output,
            output_capacity,
            output_length,
            |request: RecoveryControlRequestV1| plan_recovery_control_v1(request),
        )
    }
}

#[unsafe(no_mangle)]
/// Plan recovery control under an exact V2 recovery-morphology context.
///
/// # Safety
///
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. When non-null, `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_recovery_plan_control_v2_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(
            input,
            input_length,
            output,
            output_capacity,
            output_length,
            |request: RecoveryControlRequestV2| plan_recovery_control_v2(request),
        )
    }
}

#[unsafe(no_mangle)]
/// Plan deterministic recovery control from a validated observation V2.
///
/// # Safety
///
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. When non-null, `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_recovery_plan_control_v3_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(
            input,
            input_length,
            output,
            output_capacity,
            output_length,
            |request: RecoveryControlRequestV3| plan_recovery_control_v3(request),
        )
    }
}

#[unsafe(no_mangle)]
/// Compose one stance-owned exact-s169 command from observation-V1 recovery
/// collection and its content-bound portable supervisor handoff receipt.
///
/// # Safety
///
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. When non-null, `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_recovery_plan_stance_control_v1_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(
            input,
            input_length,
            output,
            output_capacity,
            output_length,
            |request: RecoveryStanceControlRequestV1| plan_recovery_stance_control_v1(request),
        )
    }
}

#[unsafe(no_mangle)]
/// Compose one stance-owned command from a morphology-aware observation-V1
/// recovery collection and its content-bound supervisor handoff receipt.
///
/// # Safety
///
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. When non-null, `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_recovery_plan_stance_control_v2_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(
            input,
            input_length,
            output,
            output_capacity,
            output_length,
            |request: RecoveryStanceControlRequestV2| plan_recovery_stance_control_v2(request),
        )
    }
}

#[unsafe(no_mangle)]
/// Compose one stance-owned command from a source-bound observation-V2
/// recovery collection and its content-bound supervisor handoff receipt.
///
/// # Safety
///
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. When non-null, `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_recovery_plan_stance_control_v3_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(
            input,
            input_length,
            output,
            output_capacity,
            output_length,
            |request: RecoveryStanceControlRequestV3| plan_recovery_stance_control_v3(request),
        )
    }
}

#[unsafe(no_mangle)]
/// Compose stance control while explicitly binding a portable observation-V3
/// supervisor step to its source-bound observation-V2 control projection.
///
/// # Safety
///
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. When non-null, `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_recovery_plan_stance_control_v4_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(
            input,
            input_length,
            output,
            output_capacity,
            output_length,
            |request: RecoveryStanceControlRequestV4| plan_recovery_stance_control_v4(request),
        )
    }
}

#[unsafe(no_mangle)]
/// Compose one complete legacy portable command and one exact-order canonical
/// stability residual vector in canonical velocity space. This call is pure:
/// it opens no physics world and applies no host actuation.
///
/// # Safety
///
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. When non-null, `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_canonical_velocity_compose_v1_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(
            input,
            input_length,
            output,
            output_capacity,
            output_length,
            |request: CanonicalVelocityComposeRequestV1| {
                if request.schema_version != "sporespore_canonical_velocity_compose_request_v1" {
                    return Err(CoreError::Schema(
                        "canonical_velocity_compose_request_version".to_owned(),
                    ));
                }
                let compiled = compile_bounded_quadruped(request.descriptor)?;
                canonicalize_and_compose_legacy_velocity_v1(
                    &compiled.morphology,
                    &request.source_actuation,
                    &request.ordered_stability_residuals,
                )
            },
        )
    }
}

#[unsafe(no_mangle)]
/// Map one canonical velocity frame into one strict, versioned host profile.
/// This call is pure and cannot itself establish locomotion authority.
///
/// # Safety
///
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. When non-null, `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_canonical_velocity_host_map_v1_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(
            input,
            input_length,
            output,
            output_capacity,
            output_length,
            |request: CanonicalVelocityHostMapRequestV1| {
                if request.schema_version != "sporespore_canonical_velocity_host_map_request_v1" {
                    return Err(CoreError::Schema(
                        "canonical_velocity_host_map_request_version".to_owned(),
                    ));
                }
                let compiled = compile_bounded_quadruped(request.descriptor)?;
                map_canonical_velocity_to_host_v1(
                    &compiled.morphology,
                    &request.canonical_actuation,
                    &request.host_profile,
                )
            },
        )
    }
}

#[unsafe(no_mangle)]
/// Validate and resolve one optional engine-neutral adaptation-provider
/// response against its deterministic baseline and safety envelope. This
/// call is pure: it opens no physics world and applies no host actuation.
///
/// # Safety
///
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. When non-null, `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_resolve_adaptation_v1_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(
            input,
            input_length,
            output,
            output_capacity,
            output_length,
            |request: AdaptationResolutionRequestV1| {
                let compiled =
                    compile_bounded_quadruped(request.provider_request.descriptor.clone())?;
                resolve_adaptation_v1(&compiled, &request)
            },
        )
    }
}

#[unsafe(no_mangle)]
/// Derive the pure Candidate 35 profile for one strict JSON descriptor.
///
/// # Safety
///
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. When non-null, `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_candidate35_profile_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    unsafe {
        descriptor_call(
            input,
            input_length,
            output,
            output_capacity,
            output_length,
            |descriptor| candidate35_profile(&descriptor),
        )
    }
}

#[unsafe(no_mangle)]
/// Derive the pure balanced-wave profile for one strict JSON descriptor.
///
/// # Safety
///
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. When non-null, `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_balanced_wave_profile_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    unsafe {
        descriptor_call(
            input,
            input_length,
            output,
            output_capacity,
            output_length,
            |descriptor| balanced_wave_profile(&descriptor),
        )
    }
}

#[unsafe(no_mangle)]
/// Derive a strict named balanced-wave policy profile for one descriptor.
///
/// # Safety
///
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. When non-null, `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_balanced_wave_policy_profile_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(
            input,
            input_length,
            output,
            output_capacity,
            output_length,
            |request: BalancedWavePolicyProfileRequest| {
                if request.schema_version != "sporespore_balanced_wave_policy_profile_request_v1" {
                    return Err(CoreError::Schema(
                        "balanced_wave_policy_profile_request_version".to_owned(),
                    ));
                }
                balanced_wave_profile_for_policy(&request.descriptor, &request.policy_id)
            },
        )
    }
}

#[unsafe(no_mangle)]
/// Return the GQ15 continuous-domain certificate as JSON.
///
/// # Safety
///
/// `output_length` must address one writable `usize`. When non-null, `output`
/// must address `output_capacity` writable bytes.
pub unsafe extern "C" fn ss_gq15_domain_certificate_json(
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    let guarded = catch_unwind(AssertUnwindSafe(|| {
        serde_json::to_vec(&ApiSuccess {
            ok: true,
            value: compile_gq15_domain_certificate(),
        })
    }));
    match guarded {
        Ok(Ok(bytes)) => unsafe { copy_output(&bytes, output, output_capacity, output_length) },
        Ok(Err(error)) => {
            let bytes = failure_bytes(&CoreError::Serialization(error.to_string()));
            let copy_status =
                unsafe { copy_output(&bytes, output, output_capacity, output_length) };
            if copy_status == SS_OK {
                SS_CORE_ERROR
            } else {
                copy_status
            }
        }
        Err(_) => SS_PANIC_CAUGHT,
    }
}

#[unsafe(no_mangle)]
/// Return a fresh Candidate 35 controller memory record as JSON.
///
/// # Safety
///
/// `output_length` must address one writable `usize`. When non-null, `output`
/// must address `output_capacity` writable bytes.
pub unsafe extern "C" fn ss_candidate35_initial_memory_json(
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    let guarded = catch_unwind(AssertUnwindSafe(|| {
        serde_json::to_vec(&ApiSuccess {
            ok: true,
            value: Candidate35ControllerMemory::initial(),
        })
    }));
    match guarded {
        Ok(Ok(bytes)) => unsafe { copy_output(&bytes, output, output_capacity, output_length) },
        Ok(Err(error)) => {
            let bytes = failure_bytes(&CoreError::Serialization(error.to_string()));
            let copy_status =
                unsafe { copy_output(&bytes, output, output_capacity, output_length) };
            if copy_status == SS_OK {
                SS_CORE_ERROR
            } else {
                copy_status
            }
        }
        Err(_) => SS_PANIC_CAUGHT,
    }
}

#[unsafe(no_mangle)]
/// Return a fresh balanced-wave controller memory record as JSON.
///
/// # Safety
///
/// `output_length` must address one writable `usize`. When non-null, `output`
/// must address `output_capacity` writable bytes.
pub unsafe extern "C" fn ss_balanced_wave_initial_memory_json(
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    let guarded = catch_unwind(AssertUnwindSafe(|| {
        serde_json::to_vec(&ApiSuccess {
            ok: true,
            value: BalancedWaveControllerMemory::initial(),
        })
    }));
    match guarded {
        Ok(Ok(bytes)) => unsafe { copy_output(&bytes, output, output_capacity, output_length) },
        Ok(Err(error)) => {
            let bytes = failure_bytes(&CoreError::Serialization(error.to_string()));
            let copy_status =
                unsafe { copy_output(&bytes, output, output_capacity, output_length) };
            if copy_status == SS_OK {
                SS_CORE_ERROR
            } else {
                copy_status
            }
        }
        Err(_) => SS_PANIC_CAUGHT,
    }
}

#[unsafe(no_mangle)]
/// Return fresh memory for one explicit named balanced-wave policy as JSON.
///
/// Unlike the legacy no-input memory function, this route compiles the named
/// policy before selecting its memory schema. Stateful policies therefore
/// cannot accidentally start with legacy memory and silently fail safe on the
/// first physical step.
///
/// # Safety
///
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. When non-null, `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_balanced_wave_policy_initial_memory_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(
            input,
            input_length,
            output,
            output_capacity,
            output_length,
            |request: BalancedWavePolicyInitialMemoryRequest| {
                if request.schema_version
                    != "sporespore_balanced_wave_policy_initial_memory_request_v1"
                {
                    return Err(CoreError::Schema(
                        "balanced_wave_policy_initial_memory_request_version".to_owned(),
                    ));
                }
                let controller = BalancedWaveController::new_for_policy(
                    compile_bounded_quadruped(request.descriptor)?,
                    &request.policy_id,
                )?;
                Ok(controller.initial_memory())
            },
        )
    }
}

#[unsafe(no_mangle)]
/// Execute one pure Candidate 35 controller step from strict JSON records.
///
/// # Safety
///
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. When non-null, `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_candidate35_step_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    let guarded = catch_unwind(AssertUnwindSafe(|| {
        if input.is_null() || input_length == 0 {
            return Err(CoreError::Schema("empty_input".to_owned()));
        }
        let bytes = unsafe { slice::from_raw_parts(input, input_length) };
        let request: Candidate35StepRequest =
            serde_json::from_slice(bytes).map_err(|error| CoreError::Schema(error.to_string()))?;
        if request.schema_version != "sporespore_candidate35_step_request_v1" {
            return Err(CoreError::Schema(
                "candidate35_step_request_version".to_owned(),
            ));
        }
        let controller =
            Candidate35Controller::new(compile_bounded_quadruped(request.descriptor)?)?;
        let value = controller.step(&request.memory, &request.state, &request.command);
        serde_json::to_vec(&ApiSuccess { ok: true, value })
            .map_err(|error| CoreError::Serialization(error.to_string()))
    }));
    match guarded {
        Ok(Ok(bytes)) => unsafe { copy_output(&bytes, output, output_capacity, output_length) },
        Ok(Err(error)) => {
            let bytes = failure_bytes(&error);
            let copy_status =
                unsafe { copy_output(&bytes, output, output_capacity, output_length) };
            if copy_status == SS_OK {
                SS_CORE_ERROR
            } else {
                copy_status
            }
        }
        Err(_) => {
            let bytes = br#"{"detail":"panic caught at C boundary","failure_code":"INTERNAL_PANIC_CAUGHT","ok":false}"#;
            let copy_status = unsafe { copy_output(bytes, output, output_capacity, output_length) };
            if copy_status == SS_OK {
                SS_PANIC_CAUGHT
            } else {
                copy_status
            }
        }
    }
}

#[unsafe(no_mangle)]
/// Execute one pure balanced-wave controller step from strict JSON records.
///
/// # Safety
///
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. When non-null, `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_balanced_wave_step_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    let guarded = catch_unwind(AssertUnwindSafe(|| {
        if input.is_null() || input_length == 0 {
            return Err(CoreError::Schema("empty_input".to_owned()));
        }
        let bytes = unsafe { slice::from_raw_parts(input, input_length) };
        let request: BalancedWaveStepRequest =
            serde_json::from_slice(bytes).map_err(|error| CoreError::Schema(error.to_string()))?;
        if request.schema_version != "sporespore_balanced_wave_step_request_v1" {
            return Err(CoreError::Schema(
                "balanced_wave_step_request_version".to_owned(),
            ));
        }
        let controller =
            BalancedWaveController::new(compile_bounded_quadruped(request.descriptor)?)?;
        let value = controller.step(&request.memory, &request.state, &request.command);
        serde_json::to_vec(&ApiSuccess { ok: true, value })
            .map_err(|error| CoreError::Serialization(error.to_string()))
    }));
    match guarded {
        Ok(Ok(bytes)) => unsafe { copy_output(&bytes, output, output_capacity, output_length) },
        Ok(Err(error)) => {
            let bytes = failure_bytes(&error);
            let copy_status =
                unsafe { copy_output(&bytes, output, output_capacity, output_length) };
            if copy_status == SS_OK {
                SS_CORE_ERROR
            } else {
                copy_status
            }
        }
        Err(_) => {
            let bytes = br#"{"detail":"panic caught at C boundary","failure_code":"INTERNAL_PANIC_CAUGHT","ok":false}"#;
            let copy_status = unsafe { copy_output(bytes, output, output_capacity, output_length) };
            if copy_status == SS_OK {
                SS_PANIC_CAUGHT
            } else {
                copy_status
            }
        }
    }
}

#[unsafe(no_mangle)]
/// Execute one named pure balanced-wave controller step from strict JSON.
///
/// # Safety
///
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. When non-null, `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_balanced_wave_policy_step_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    let guarded = catch_unwind(AssertUnwindSafe(|| {
        if input.is_null() || input_length == 0 {
            return Err(CoreError::Schema("empty_input".to_owned()));
        }
        let bytes = unsafe { slice::from_raw_parts(input, input_length) };
        let request: BalancedWavePolicyStepRequest =
            serde_json::from_slice(bytes).map_err(|error| CoreError::Schema(error.to_string()))?;
        if !((request.schema_version == "sporespore_balanced_wave_policy_step_request_v1" && request.floor_reference.is_none() && request.measured_body_frame.is_none())
            || (request.schema_version == "sporespore_balanced_wave_policy_step_request_v2" && request.floor_reference.is_some() && request.measured_body_frame.is_none())
            || (request.schema_version == "sporespore_balanced_wave_policy_step_request_v3" && request.floor_reference.is_some() && request.measured_body_frame.is_some())) {
            return Err(CoreError::Schema(
                "balanced_wave_policy_step_request_version".to_owned(),
            ));
        }
        let controller = BalancedWaveController::new_for_policy(
            compile_bounded_quadruped(request.descriptor)?,
            &request.policy_id,
        )?;
        let value = controller.step_with_measured_body(&request.memory, &request.state, &request.command,
            request.floor_reference.as_ref(), request.measured_body_frame.as_ref());
        serde_json::to_vec(&ApiSuccess { ok: true, value })
            .map_err(|error| CoreError::Serialization(error.to_string()))
    }));
    match guarded {
        Ok(Ok(bytes)) => unsafe { copy_output(&bytes, output, output_capacity, output_length) },
        Ok(Err(error)) => {
            let bytes = failure_bytes(&error);
            let copy_status =
                unsafe { copy_output(&bytes, output, output_capacity, output_length) };
            if copy_status == SS_OK {
                SS_CORE_ERROR
            } else {
                copy_status
            }
        }
        Err(_) => {
            let bytes = br#"{"detail":"panic caught at C boundary","failure_code":"INTERNAL_PANIC_CAUGHT","ok":false}"#;
            let copy_status = unsafe { copy_output(bytes, output, output_capacity, output_length) };
            if copy_status == SS_OK {
                SS_PANIC_CAUGHT
            } else {
                copy_status
            }
        }
    }
}

#[unsafe(no_mangle)]
/// Compile one named balanced-wave controller into an opaque process-local session.
///
/// The returned handle owns no controller memory: callers continue to provide
/// explicit memory in every step request, preserving deterministic replay.
///
/// # Safety
///
/// `input` must address `input_length` readable bytes and `session_handle`
/// must address one writable `u64`.
pub unsafe extern "C" fn ss_balanced_wave_policy_session_create_json(
    input: *const u8,
    input_length: usize,
    session_handle: *mut u64,
) -> c_int {
    if input.is_null() || input_length == 0 || session_handle.is_null() {
        return SS_INVALID_ARGUMENT;
    }
    let guarded = catch_unwind(AssertUnwindSafe(|| {
        let bytes = unsafe { slice::from_raw_parts(input, input_length) };
        let request: BalancedWavePolicySessionCreateRequest =
            serde_json::from_slice(bytes).map_err(|error| CoreError::Schema(error.to_string()))?;
        if request.schema_version != "sporespore_balanced_wave_policy_session_create_request_v1" {
            return Err(CoreError::Schema(
                "balanced_wave_policy_session_create_request_version".to_owned(),
            ));
        }
        let controller = Arc::new(BalancedWaveController::new_for_policy(
            compile_bounded_quadruped(request.descriptor)?,
            &request.policy_id,
        )?);
        let handle = allocate_balanced_wave_policy_session_handle(
            &NEXT_BALANCED_WAVE_POLICY_SESSION_HANDLE,
        )?;
        lock_balanced_wave_policy_sessions()?.insert(handle, controller);
        Ok(handle)
    }));
    match guarded {
        Ok(Ok(handle)) => {
            unsafe { session_handle.write(handle) };
            SS_OK
        }
        Ok(Err(_)) => SS_CORE_ERROR,
        Err(_) => SS_PANIC_CAUGHT,
    }
}

#[unsafe(no_mangle)]
/// Execute one pure step through an existing balanced-wave policy session.
///
/// # Safety
///
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. When non-null, `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_balanced_wave_policy_session_step_json(
    session_handle: u64,
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(
            input,
            input_length,
            output,
            output_capacity,
            output_length,
            |request: BalancedWavePolicySessionStepRequest| {
                if !((request.schema_version == "sporespore_balanced_wave_policy_session_step_request_v1" && request.floor_reference.is_none() && request.measured_body_frame.is_none())
                    || (request.schema_version == "sporespore_balanced_wave_policy_session_step_request_v2" && request.floor_reference.is_some() && request.measured_body_frame.is_none())
                    || (request.schema_version == "sporespore_balanced_wave_policy_session_step_request_v3" && request.floor_reference.is_some() && request.measured_body_frame.is_some())) {
                    return Err(CoreError::Schema(
                        "balanced_wave_policy_session_step_request_version".to_owned(),
                    ));
                }
                let controller = lock_balanced_wave_policy_sessions()?
                    .get(&session_handle)
                    .cloned()
                    .ok_or_else(|| {
                        CoreError::Reference(
                            "balanced_wave_policy_session_handle_unknown".to_owned(),
                        )
                    })?;
                Ok(controller.step_with_measured_body(&request.memory, &request.state, &request.command,
                    request.floor_reference.as_ref(), request.measured_body_frame.as_ref()))
            },
        )
    }
}

#[unsafe(no_mangle)]
/// Destroy one process-local balanced-wave policy session.
pub extern "C" fn ss_balanced_wave_policy_session_destroy(session_handle: u64) -> c_int {
    if session_handle == 0 {
        return SS_INVALID_ARGUMENT;
    }
    let guarded = catch_unwind(AssertUnwindSafe(
        || -> crate::schema::Result<Option<Arc<BalancedWaveController>>> {
            Ok(lock_balanced_wave_policy_sessions()?.remove(&session_handle))
        },
    ));
    match guarded {
        Ok(Ok(Some(_))) => SS_OK,
        Ok(Ok(None)) => SS_INVALID_ARGUMENT,
        Ok(Err(_)) => SS_CORE_ERROR,
        Err(_) => SS_PANIC_CAUGHT,
    }
}

#[unsafe(no_mangle)]
/// Observe pure Locomotion Semantics v2 support state from strict JSON.
///
/// # Safety
///
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. When non-null, `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_observe_stability_v2_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(
            input,
            input_length,
            output,
            output_capacity,
            output_length,
            |request: ObserveStabilityV2Request| {
                if request.schema_version != "sporespore_observe_stability_request_v2" {
                    return Err(CoreError::Schema(
                        "observe_stability_request_version".to_owned(),
                    ));
                }
                let compiled = compile_bounded_quadruped(request.descriptor)?;
                observe_stability_v2(&compiled.morphology, &request.state)
            },
        )
    }
}

#[unsafe(no_mangle)]
/// Plan one pure scheduler-aware load-transfer contribution from strict JSON.
///
/// # Safety
///
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. When non-null, `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_plan_scheduled_load_transfer_v1_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(
            input,
            input_length,
            output,
            output_capacity,
            output_length,
            |request: PlanScheduledLoadTransferV1Request| {
                if request.schema_version != "sporespore_plan_scheduled_load_transfer_request_v1" {
                    return Err(CoreError::Schema(
                        "plan_scheduled_load_transfer_request_version".to_owned(),
                    ));
                }
                let compiled = compile_bounded_quadruped(request.descriptor)?;
                plan_scheduled_load_transfer_v1(&compiled.morphology, &request.request)
            },
        )
    }
}

#[unsafe(no_mangle)]
/// Plan one pure scheduler-aware load-transfer contribution with typed
/// fail-zero availability from strict JSON.
///
/// # Safety
///
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. When non-null, `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_plan_scheduled_load_transfer_v2_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(
            input,
            input_length,
            output,
            output_capacity,
            output_length,
            |request: PlanScheduledLoadTransferV2Request| {
                if request.schema_version != "sporespore_plan_scheduled_load_transfer_request_v2" {
                    return Err(CoreError::Schema(
                        "plan_scheduled_load_transfer_v2_request_version".to_owned(),
                    ));
                }
                let compiled = compile_bounded_quadruped(request.descriptor)?;
                plan_scheduled_load_transfer_v2(&compiled.morphology, &request.request)
            },
        )
    }
}

#[unsafe(no_mangle)]
/// Plan one pure scheduler-aware load-transfer contribution with an explicit
/// observation-availability input and a typed safe-zero receipt on every
/// accepted semantic step.
///
/// # Safety
///
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. When non-null, `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_plan_scheduled_load_transfer_v3_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(
            input,
            input_length,
            output,
            output_capacity,
            output_length,
            |request: PlanScheduledLoadTransferV3Request| {
                if request.schema_version != "sporespore_plan_scheduled_load_transfer_request_v3" {
                    return Err(CoreError::Schema(
                        "plan_scheduled_load_transfer_v3_request_version".to_owned(),
                    ));
                }
                let compiled = compile_bounded_quadruped(request.descriptor)?;
                plan_scheduled_load_transfer_v3(&compiled.morphology, &request.request)
            },
        )
    }
}

#[unsafe(no_mangle)]
/// Produce one pure bounded centroidal support command from strict JSON.
///
/// # Safety
///
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. When non-null, `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_command_centroidal_support_v2_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(
            input,
            input_length,
            output,
            output_capacity,
            output_length,
            |request: CentroidalSupportRequestV2| command_centroidal_support_v2(&request),
        )
    }
}

#[unsafe(no_mangle)]
/// Map one feasible endpoint-force command to generalized joint torques.
///
/// # Safety
///
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. When non-null, `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_map_endpoint_force_to_joint_v2_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(
            input,
            input_length,
            output,
            output_capacity,
            output_length,
            |request: MapEndpointForceToJointV2Request| {
                if request.schema_version != "sporespore_map_endpoint_force_to_joint_request_v2" {
                    return Err(CoreError::Schema(
                        "map_endpoint_force_to_joint_request_version".to_owned(),
                    ));
                }
                let compiled = compile_bounded_quadruped(request.descriptor)?;
                map_endpoint_force_to_joint_v2(&compiled.morphology, &request.request)
            },
        )
    }
}

#[unsafe(no_mangle)]
/// Map active endpoint-force commands and explicit inactive-contact zeros to
/// one exact-order generalized joint-torque vector.
///
/// # Safety
///
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. When non-null, `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_map_endpoint_force_to_joint_v3_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(
            input,
            input_length,
            output,
            output_capacity,
            output_length,
            |request: MapEndpointForceToJointV3Request| {
                if request.schema_version != "sporespore_map_endpoint_force_to_joint_request_v3" {
                    return Err(CoreError::Schema(
                        "map_endpoint_force_to_joint_v3_request_version".to_owned(),
                    ));
                }
                let compiled = compile_bounded_quadruped(request.descriptor)?;
                map_endpoint_force_to_joint_v3(&compiled.morphology, &request.request)
            },
        )
    }
}

#[unsafe(no_mangle)]
/// Bound one ordered stability contribution from strict JSON.
///
/// # Safety
///
/// `input` must address `input_length` readable bytes. `output_length` must
/// address one writable `usize`. When non-null, `output` must address
/// `output_capacity` writable bytes and must not overlap `input`.
pub unsafe extern "C" fn ss_bound_stability_influence_v2_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(
            input,
            input_length,
            output,
            output_capacity,
            output_length,
            |request: BoundStabilityInfluenceV2Request| {
                if request.schema_version != "sporespore_bound_stability_influence_request_v2" {
                    return Err(CoreError::Schema(
                        "bound_stability_influence_request_version".to_owned(),
                    ));
                }
                let compiled = compile_bounded_quadruped(request.descriptor)?;
                bound_stability_influence_v2(&compiled.morphology, &request.request)
            },
        )
    }
}

/// Apply one branch-free global scale, then bound one ordered stability
/// contribution from strict JSON.
///
/// # Safety
/// The caller must provide readable input bytes and writable output metadata
/// and buffer ranges for the declared lengths.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ss_bound_stability_influence_v3_json(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
    output_length: *mut usize,
) -> c_int {
    unsafe {
        json_input_call(
            input,
            input_length,
            output,
            output_capacity,
            output_length,
            |request: BoundStabilityInfluenceV3Request| {
                if request.schema_version != "sporespore_bound_stability_influence_request_v3" {
                    return Err(CoreError::Schema(
                        "bound_stability_influence_v3_request_version".to_owned(),
                    ));
                }
                let compiled = compile_bounded_quadruped(request.descriptor)?;
                bound_stability_influence_v3(&compiled.morphology, &request.request)
            },
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::canonical::{canonical_json, digest_json};
    use crate::protocol::{Pose, Quaternion, Twist};
    use crate::quadruped::BoundedQuadrupedDescriptor;
    use crate::schema::Vec3;
    use crate::stability::{
        OrderedBodyStateV2, SCHEDULED_LOAD_TRANSFER_BW9L_D_POLICY_ID,
        SCHEDULED_LOAD_TRANSFER_BW10F_D_POLICY_ID, SCHEDULED_LOAD_TRANSFER_BW11R_D_POLICY_ID,
        SCHEDULED_LOAD_TRANSFER_BW13P_D_POLICY_ID, SCHEDULED_LOAD_TRANSFER_REQUEST_V2_VERSION,
        SCHEDULED_LOAD_TRANSFER_REQUEST_V3_VERSION, SCHEDULED_LOAD_TRANSFER_REQUEST_VERSION,
        STABILITY_STATE_VERSION, ScheduledLimbGaitStepV1, ScheduledLoadTransferRequestV1,
        ScheduledLoadTransferRequestV2, ScheduledLoadTransferRequestV3, SupportContactStateV2,
    };

    fn call_with_retry(
        input: &[u8],
        function: unsafe extern "C" fn(*const u8, usize, *mut u8, usize, *mut usize) -> c_int,
    ) -> (c_int, Vec<u8>) {
        let mut required = 0;
        let first = unsafe {
            function(
                input.as_ptr(),
                input.len(),
                ptr::null_mut(),
                0,
                &mut required,
            )
        };
        assert_eq!(first, SS_BUFFER_TOO_SMALL);
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
        (status, output)
    }

    #[test]
    fn balanced_wave_policy_session_handles_fail_closed_without_wrapping() {
        let counter = AtomicU64::new(7);
        assert_eq!(
            allocate_balanced_wave_policy_session_handle(&counter).unwrap(),
            7
        );
        assert_eq!(counter.load(Ordering::Relaxed), 8);

        for exhausted_value in [0, u64::MAX] {
            let exhausted = AtomicU64::new(exhausted_value);
            assert!(allocate_balanced_wave_policy_session_handle(&exhausted).is_err());
            assert!(allocate_balanced_wave_policy_session_handle(&exhausted).is_err());
            assert_eq!(exhausted.load(Ordering::Relaxed), exhausted_value);
        }
    }

    #[test]
    fn buffer_protocol_and_compile_are_stable() {
        let input =
            serde_json::to_vec(&BoundedQuadrupedDescriptor::reference("ffi_reference")).unwrap();
        let (status, output) = call_with_retry(&input, ss_compile_bounded_quadruped_json);
        assert_eq!(status, SS_OK);
        let decoded: serde_json::Value = serde_json::from_slice(&output).unwrap();
        assert_eq!(decoded["ok"], true);
        assert_eq!(decoded["value"]["morphology_id"], "ffi_reference");
        assert_eq!(decoded["value"]["world_build_count"], 0);
    }

    #[test]
    fn recovery_morphology_support_and_refusal_cross_the_public_buffer_abi() {
        let exact_descriptor =
            crate::recovery_morphology::RecoveryMorphologyDescriptorV1::exact_s169_reference(
                crate::actuator_profile::r23d60_selected_s169_descriptor(),
            );
        let exact = serde_json::to_vec(&exact_descriptor).unwrap();
        let (status, output) = call_with_retry(&exact, ss_compile_recovery_morphology_v1_json);
        assert_eq!(status, SS_OK);
        let decoded: serde_json::Value = serde_json::from_slice(&output).unwrap();
        assert_eq!(decoded["ok"], true);
        assert_eq!(decoded["value"]["support_status"], "supported_exact");
        assert_eq!(
            decoded["value"]["recovery_morphology_id"],
            "qsdk_r24_recovery_s169_v1"
        );
        assert_eq!(
            decoded["value"]["base_descriptor_sha256"],
            crate::actuator_profile::R23D60_SELECTED_S169_DESCRIPTOR_SHA256
        );
        assert_eq!(
            decoded["value"]["base_morphology_spec_sha256"],
            crate::actuator_profile::R23D60_SELECTED_S169_MORPHOLOGY_SPEC_SHA256
        );
        assert!(
            decoded["value"]["prone_geometry"]["minimum_limb_ground_clearance_m"]
                .as_f64()
                .unwrap()
                > 0.0
        );
        assert_eq!(decoded["value"]["world_build_count"], 0);
        assert_eq!(decoded["value"]["physics_state_modified"], false);
        assert_eq!(decoded["value"]["physical_acceptance_authority"], false);
        assert_eq!(decoded["value"]["release_authority"], false);

        let mut infeasible = exact_descriptor;
        infeasible.recovery_morphology_id = "ffi_recovery_refusal".to_owned();
        infeasible.joint_authority.hip_anchor_parent_y_m = -0.05;
        infeasible.joint_authority.hip_limit_magnitude_rad = 0.72;
        infeasible.canonical_prone_pose.front_hip_angle_rad = 0.72;
        infeasible.canonical_prone_pose.rear_hip_angle_rad = -0.72;
        let input = serde_json::to_vec(&infeasible).unwrap();
        let (status, output) = call_with_retry(&input, ss_compile_recovery_morphology_v1_json);
        assert_eq!(status, SS_OK);
        let decoded: serde_json::Value = serde_json::from_slice(&output).unwrap();
        assert_eq!(
            decoded["value"]["support_status"],
            "unsupported_prone_geometry_infeasible"
        );
        assert_eq!(
            decoded["value"]["refusal_reason"],
            "canonical_prone_pose_ground_penetration"
        );
    }

    #[test]
    fn recovery_energy_v2_aggregation_and_refusal_cross_the_public_buffer_abi() {
        let input = serde_json::to_vec(&serde_json::json!({
            "schema_version": "sporespore_recovery_energy_balance_aggregation_request_v2",
            "source_profile_id": "ffi_zero_world_energy_fixture_v1",
            "initial_mechanical_energy_j": 10.0,
            "current_mechanical_energy_j": 11.5,
            "ordered_increments": [
                {
                    "sequence_index": 0,
                    "semantic_step": 7,
                    "applied_actuator_work_j": 4.0,
                    "signed_external_work_j": 1.0,
                    "signed_constraint_exchange_j": 2.0,
                    "passive_dissipation_j": 0.5,
                    "source_measurement": true
                },
                {
                    "sequence_index": 1,
                    "semantic_step": 8,
                    "applied_actuator_work_j": -0.5,
                    "signed_external_work_j": -0.25,
                    "signed_constraint_exchange_j": -3.0,
                    "passive_dissipation_j": 1.25,
                    "source_measurement": true
                }
            ]
        }))
        .unwrap();
        let (status, output) =
            call_with_retry(&input, ss_recovery_energy_balance_aggregate_v2_json);
        assert_eq!(status, SS_OK);
        let decoded: serde_json::Value = serde_json::from_slice(&output).unwrap();
        assert_eq!(
            decoded["value"]["ledger"]["cumulative_signed_constraint_exchange_j"],
            -1.0
        );
        assert_eq!(
            decoded["value"]["ledger"]["cumulative_passive_dissipation_j"],
            1.75
        );
        assert_eq!(decoded["value"]["evaluation"]["signed_residual_j"], 0.0);
        assert_eq!(decoded["value"]["world_build_count"], 0);

        let downgrade = serde_json::to_vec(&serde_json::json!({
            "schema_version": "sporespore_recovery_energy_balance_migration_request_v1",
            "direction": "v2_to_v1",
            "source_v1": null,
            "source_v2": decoded["value"]["ledger"].clone()
        }))
        .unwrap();
        let (status, output) =
            call_with_retry(&downgrade, ss_recovery_energy_balance_migrate_v1_json);
        assert_eq!(status, SS_OK);
        let refusal: serde_json::Value = serde_json::from_slice(&output).unwrap();
        assert_eq!(refusal["value"]["support_status"], "unsupported_capability");
        assert_eq!(
            refusal["value"]["refusal_reason"],
            "portable_v1_signed_constraint_work_unrepresentable"
        );
        assert!(refusal["value"]["target_v1"].is_null());
        assert_eq!(refusal["value"]["solver_step_count"], 0);
    }

    #[test]
    fn exact_scope_actuator_profile_and_refusals_cross_the_public_buffer_abi() {
        let exact = serde_json::to_vec(&serde_json::json!({
            "schema_version": "sporespore_actuator_cap_profile_request_v1",
            "profile_id": "sporespore_qsdk_r23d60_selected_s169_actuator_cap_profile_v1",
            "descriptor": crate::actuator_profile::r23d60_selected_s169_descriptor(),
        }))
        .unwrap();
        let (status, output) = call_with_retry(&exact, ss_resolve_actuator_cap_profile_v1_json);
        assert_eq!(status, SS_OK);
        let decoded: serde_json::Value = serde_json::from_slice(&output).unwrap();
        assert_eq!(decoded["ok"], true);
        assert_eq!(decoded["value"]["support_status"], "supported_exact");
        assert_eq!(
            decoded["value"]["profile"]["ordered_caps"]
                .as_array()
                .unwrap()
                .len(),
            8
        );
        assert_eq!(decoded["value"]["world_build_count"], 0);
        assert_eq!(decoded["value"]["physics_state_modified"], false);
        assert_eq!(decoded["value"]["physical_acceptance_authority"], false);

        let unsupported = serde_json::to_vec(&serde_json::json!({
            "schema_version": "sporespore_actuator_cap_profile_request_v1",
            "profile_id": "unknown_profile",
            "descriptor": crate::actuator_profile::r23d60_selected_s169_descriptor(),
        }))
        .unwrap();
        let (unsupported_status, unsupported_output) =
            call_with_retry(&unsupported, ss_resolve_actuator_cap_profile_v1_json);
        assert_eq!(unsupported_status, SS_OK);
        let unsupported_decoded: serde_json::Value =
            serde_json::from_slice(&unsupported_output).unwrap();
        assert_eq!(
            unsupported_decoded["value"]["support_status"],
            "unsupported_profile"
        );
        assert!(unsupported_decoded["value"]["profile"].is_null());

        let malformed = serde_json::to_vec(&serde_json::json!({
            "schema_version": "sporespore_actuator_cap_profile_request_v0",
            "profile_id": "unknown_profile",
            "descriptor": crate::actuator_profile::r23d60_selected_s169_descriptor(),
        }))
        .unwrap();
        let (malformed_status, malformed_output) =
            call_with_retry(&malformed, ss_resolve_actuator_cap_profile_v1_json);
        assert_eq!(malformed_status, SS_CORE_ERROR);
        let malformed_decoded: serde_json::Value =
            serde_json::from_slice(&malformed_output).unwrap();
        assert_eq!(malformed_decoded["failure_code"], "SCHEMA_INVALID");
    }

    #[test]
    fn balanced_wave_profile_and_memory_cross_the_public_buffer_abi() {
        let input =
            serde_json::to_vec(&BoundedQuadrupedDescriptor::reference("ffi_balanced")).unwrap();
        let (status, output) = call_with_retry(&input, ss_balanced_wave_profile_json);
        assert_eq!(status, SS_OK);
        let decoded: serde_json::Value = serde_json::from_slice(&output).unwrap();
        assert_eq!(decoded["ok"], true);
        assert_eq!(
            decoded["value"]["schema_version"],
            "sporespore_balanced_wave_profile_v1"
        );
        assert_eq!(decoded["value"]["policy_id"], "sporespore_balanced_wave_v1");
        assert_eq!(decoded["value"]["cross_track_heading_gain_rad_per_m"], 1.0);
        assert_eq!(
            decoded["value"]["cross_track_velocity_heading_gain_rad_per_m_s"],
            0.30
        );
        assert_eq!(decoded["value"]["branch_surfaces"], serde_json::json!([]));

        let mut required = 0;
        let first =
            unsafe { ss_balanced_wave_initial_memory_json(ptr::null_mut(), 0, &mut required) };
        assert_eq!(first, SS_BUFFER_TOO_SMALL);
        let mut memory_output = vec![0_u8; required];
        let second = unsafe {
            ss_balanced_wave_initial_memory_json(
                memory_output.as_mut_ptr(),
                memory_output.len(),
                &mut required,
            )
        };
        assert_eq!(second, SS_OK);
        let memory: serde_json::Value = serde_json::from_slice(&memory_output).unwrap();
        assert_eq!(memory["ok"], true);
        assert_eq!(
            memory["value"]["schema_version"],
            "sporespore_balanced_wave_memory_v1"
        );
        assert_eq!(
            memory["value"]["ordered_limb_memory"]
                .as_array()
                .unwrap()
                .len(),
            4
        );
    }

    #[test]
    fn named_policy_initial_memory_crosses_the_abi_and_selects_stateful_schema() {
        let descriptor = BoundedQuadrupedDescriptor::reference("ffi_named_memory");
        let persistent_request = serde_json::to_vec(&serde_json::json!({
            "schema_version": "sporespore_balanced_wave_policy_initial_memory_request_v1",
            "policy_id": "sporespore_balanced_wave_r23d29_two_swing_persistent_predictive_stability_guarded_steering_v1",
            "descriptor": descriptor,
        }))
        .unwrap();
        let (persistent_status, persistent_output) = call_with_retry(
            &persistent_request,
            ss_balanced_wave_policy_initial_memory_json,
        );
        assert_eq!(persistent_status, SS_OK);
        let persistent: serde_json::Value = serde_json::from_slice(&persistent_output).unwrap();
        assert_eq!(persistent["ok"], true);
        assert_eq!(
            persistent["value"]["schema_version"],
            "sporespore_balanced_wave_persistent_predictive_guard_memory_v1"
        );
        assert_eq!(
            persistent["value"]["steering_guard_floor_hold_steps_remaining"],
            0
        );

        let legacy_request = serde_json::to_vec(&serde_json::json!({
            "schema_version": "sporespore_balanced_wave_policy_initial_memory_request_v1",
            "policy_id": "sporespore_balanced_wave_bw5r_b_v1",
            "descriptor": BoundedQuadrupedDescriptor::reference("ffi_named_memory_legacy"),
        }))
        .unwrap();
        let (legacy_status, legacy_output) =
            call_with_retry(&legacy_request, ss_balanced_wave_policy_initial_memory_json);
        assert_eq!(legacy_status, SS_OK);
        let legacy: serde_json::Value = serde_json::from_slice(&legacy_output).unwrap();
        assert_eq!(
            legacy["value"]["schema_version"],
            "sporespore_balanced_wave_memory_v1"
        );
        assert_eq!(
            legacy["value"]["steering_guard_floor_hold_steps_remaining"],
            serde_json::Value::Null
        );

        let unknown_request = serde_json::to_vec(&serde_json::json!({
            "schema_version": "sporespore_balanced_wave_policy_initial_memory_request_v1",
            "policy_id": "sporespore_balanced_wave_unknown_v1",
            "descriptor": BoundedQuadrupedDescriptor::reference("ffi_named_memory_unknown"),
        }))
        .unwrap();
        let (unknown_status, unknown_output) = call_with_retry(
            &unknown_request,
            ss_balanced_wave_policy_initial_memory_json,
        );
        assert_eq!(unknown_status, SS_CORE_ERROR);
        let unknown: serde_json::Value = serde_json::from_slice(&unknown_output).unwrap();
        assert_eq!(unknown["failure_code"], "IDENTITY_INVALID");
    }

    #[test]
    fn named_balanced_wave_profiles_cross_the_abi_and_unknown_ids_fail_closed() {
        let descriptor = BoundedQuadrupedDescriptor::reference("ffi_named_balanced");
        for (policy_id, velocity_gain, yaw_gain) in [
            ("sporespore_balanced_wave_bw2_b_v1", 0.275, 1.0),
            ("sporespore_balanced_wave_bw2_c_v1", 0.35, 1.0),
            ("sporespore_balanced_wave_bw2r_a_v1", 0.35, 1.1),
            ("sporespore_balanced_wave_bw2r_b_v1", 0.35, 1.2),
            ("sporespore_balanced_wave_bw2r_c_v1", 0.35, 1.3),
            ("sporespore_balanced_wave_bw4r_a_v1", 0.35, 1.3),
            ("sporespore_balanced_wave_bw4r_b_v1", 0.35, 1.3),
            ("sporespore_balanced_wave_bw5r_a_v1", 0.35, 1.3),
            ("sporespore_balanced_wave_bw5r_b_v1", 0.35, 1.3),
            ("sporespore_balanced_wave_bw5r_c_v1", 0.35, 1.3),
        ] {
            let input = serde_json::to_vec(&serde_json::json!({
                "schema_version": "sporespore_balanced_wave_policy_profile_request_v1",
                "policy_id": policy_id,
                "descriptor": descriptor,
            }))
            .unwrap();
            let (status, output) = call_with_retry(&input, ss_balanced_wave_policy_profile_json);
            assert_eq!(status, SS_OK);
            let decoded: serde_json::Value = serde_json::from_slice(&output).unwrap();
            assert_eq!(decoded["ok"], true);
            assert_eq!(decoded["value"]["policy_id"], policy_id);
            assert_eq!(
                decoded["value"]["cross_track_velocity_heading_gain_rad_per_m_s"],
                velocity_gain
            );
            assert_eq!(decoded["value"]["yaw_error_stride_gain_per_rad"], yaw_gain);
            assert_eq!(decoded["value"]["branch_surfaces"], serde_json::json!([]));
            if policy_id.starts_with("sporespore_balanced_wave_bw4r_") {
                assert_eq!(
                    decoded["value"]["schema_version"],
                    "sporespore_balanced_wave_continuous_profile_v1"
                );
                assert_eq!(
                    decoded["value"]["steering_feedback_update_interval_steps"],
                    1
                );
                if policy_id == "sporespore_balanced_wave_bw4r_b_v1" {
                    assert_eq!(
                        decoded["value"]["maximum_steering_fraction_delta_per_step"],
                        0.80 / 90.0
                    );
                } else {
                    assert!(
                        decoded["value"]
                            .get("maximum_steering_fraction_delta_per_step")
                            .is_none()
                    );
                }
            } else if policy_id.starts_with("sporespore_balanced_wave_bw5r_") {
                assert_eq!(
                    decoded["value"]["schema_version"],
                    "sporespore_balanced_wave_filtered_profile_v1"
                );
                assert_eq!(
                    decoded["value"]["steering_feedback_update_interval_steps"],
                    1
                );
                assert!(
                    decoded["value"]
                        .get("maximum_steering_fraction_delta_per_step")
                        .is_none()
                );
                let expected_time_constant = match policy_id {
                    "sporespore_balanced_wave_bw5r_a_v1" => 1.0 / 32.0,
                    "sporespore_balanced_wave_bw5r_b_v1" => 1.0 / 16.0,
                    "sporespore_balanced_wave_bw5r_c_v1" => 1.0 / 8.0,
                    _ => unreachable!(),
                };
                assert_eq!(
                    decoded["value"]["steering_low_pass_time_constant_cycle_fraction"],
                    expected_time_constant
                );
            } else {
                assert!(
                    decoded["value"]
                        .get("steering_feedback_update_interval_steps")
                        .is_none()
                );
                assert!(
                    decoded["value"]
                        .get("maximum_steering_fraction_delta_per_step")
                        .is_none()
                );
            }
        }

        let unknown = serde_json::to_vec(&serde_json::json!({
            "schema_version": "sporespore_balanced_wave_policy_profile_request_v1",
            "policy_id": "unknown_balanced_wave",
            "descriptor": descriptor,
        }))
        .unwrap();
        let (status, output) = call_with_retry(&unknown, ss_balanced_wave_policy_profile_json);
        assert_eq!(status, SS_CORE_ERROR);
        let decoded: serde_json::Value = serde_json::from_slice(&output).unwrap();
        assert_eq!(decoded["ok"], false);
        assert_eq!(decoded["failure_code"], "IDENTITY_INVALID");
    }

    #[test]
    fn unknown_fields_fail_closed_through_abi() {
        let input = br#"{
            "schema_version":"sporespore_bounded_quadruped_descriptor_v1",
            "morphology_id":"ffi_unknown",
            "torso_length_scale":1.0,
            "torso_width_scale":1.0,
            "upper_length_fraction":0.5142857142857142,
            "hip_span_scale":1.0,
            "foot_radius_scale":1.0,
            "front_limb_mass_scale":1.0,
            "secret_policy_override":true
        }"#;
        let (status, output) = call_with_retry(input, ss_candidate35_profile_json);
        assert_eq!(status, SS_CORE_ERROR);
        let decoded: serde_json::Value = serde_json::from_slice(&output).unwrap();
        assert_eq!(decoded["ok"], false);
        assert_eq!(decoded["failure_code"], "SCHEMA_INVALID");
    }

    #[test]
    fn stability_observation_crosses_the_public_buffer_abi() {
        let descriptor = BoundedQuadrupedDescriptor::reference("ffi_stability");
        let compiled = compile_bounded_quadruped(descriptor.clone()).unwrap();
        let ordered_body_states = compiled
            .morphology
            .ordered_body_ids
            .iter()
            .map(|body_id| OrderedBodyStateV2 {
                body_id: body_id.clone(),
                pose_world: Pose {
                    position_m: Vec3 {
                        x: 0.0,
                        y: 1.0,
                        z: 0.0,
                    },
                    orientation_xyzw: Quaternion::IDENTITY,
                },
                twist_world: Twist {
                    linear_velocity_m_s: Vec3::ZERO,
                    angular_velocity_rad_s: Vec3::ZERO,
                },
            })
            .collect();
        let ordered_support_contacts = compiled
            .morphology
            .ordered_contact_site_ids
            .iter()
            .map(|contact_id| {
                let front = contact_id.starts_with("front");
                let left = contact_id.contains("left");
                SupportContactStateV2 {
                    contact_site_id: contact_id.clone(),
                    presence: Some(true),
                    bears_support: Some(true),
                    point_world_m: Some(Vec3 {
                        x: if front { 0.5 } else { -0.5 },
                        y: 0.0,
                        z: if left { 0.5 } else { -0.5 },
                    }),
                    normal_world_unit: Some(Vec3 {
                        x: 0.0,
                        y: 1.0,
                        z: 0.0,
                    }),
                    surface_relative_velocity_world_m_s: Some(Vec3::ZERO),
                    material_id: Some("fixture_material".to_owned()),
                    adapter_id: "ffi_fixture".to_owned(),
                    engine_contact_ids: vec![format!("{contact_id}_engine")],
                }
            })
            .collect();
        let request = ObserveStabilityV2Request {
            schema_version: "sporespore_observe_stability_request_v2".to_owned(),
            descriptor,
            state: StabilityStateV2 {
                schema_version: STABILITY_STATE_VERSION.to_owned(),
                semantic_step: 7,
                ordered_body_states,
                ordered_support_contacts,
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
                adapter_capability_sha256: format!("sha256:{}", "0".repeat(64)),
            },
        };
        let input = serde_json::to_vec(&request).unwrap();
        let (status, output) = call_with_retry(&input, ss_observe_stability_v2_json);
        assert_eq!(status, SS_OK);
        let decoded: serde_json::Value = serde_json::from_slice(&output).unwrap();
        assert_eq!(decoded["ok"], true);
        assert_eq!(
            decoded["value"]["schema_version"],
            "sporespore_support_observation_v2"
        );
        assert_eq!(decoded["value"]["semantic_step"], 7);
        assert_eq!(decoded["value"]["support_geometry_kind"], "polygon");
        assert_eq!(decoded["value"]["physics_state_modified"], false);
        assert_eq!(decoded["value"]["physical_acceptance_authority"], false);

        let plan_request = PlanScheduledLoadTransferV1Request {
            schema_version: "sporespore_plan_scheduled_load_transfer_request_v1".to_owned(),
            descriptor: request.descriptor.clone(),
            request: ScheduledLoadTransferRequestV1 {
                schema_version: SCHEDULED_LOAD_TRANSFER_REQUEST_VERSION.to_owned(),
                policy_id: SCHEDULED_LOAD_TRANSFER_BW9L_D_POLICY_ID.to_owned(),
                gait_amplitude: 1.0,
                cycle_steps: 360,
                swing_steps: 72,
                characterized_friction_coefficient: 1.0,
                maximum_normal_force_n: compiled.morphology.total_mass_kg * 9.8,
                feasibility_tolerance: 1.0e-5,
                ordered_limb_gait_steps: compiled
                    .morphology
                    .ordered_limb_ids
                    .iter()
                    .map(|limb_id| ScheduledLimbGaitStepV1 {
                        limb_id: limb_id.clone(),
                        gait_step: 54,
                    })
                    .collect(),
                stability_state: request.state.clone(),
            },
        };
        let input = serde_json::to_vec(&plan_request).unwrap();
        let (status, output) = call_with_retry(&input, ss_plan_scheduled_load_transfer_v1_json);
        assert_eq!(status, SS_OK);
        let decoded: serde_json::Value = serde_json::from_slice(&output).unwrap();
        assert_eq!(decoded["ok"], true);
        assert_eq!(
            decoded["value"]["schema_version"],
            "sporespore_scheduled_load_transfer_receipt_v1"
        );
        assert_eq!(decoded["value"]["active"], true);
        assert_eq!(decoded["value"]["scheduled_limb_id"], "rear_left");
        assert_eq!(
            decoded["value"]["ordered_scheduled_unweighted_contact_ids"][0],
            "rear_left_foot"
        );
        assert_eq!(decoded["value"]["morphology_branch_surface_count"], 0);
        assert_eq!(decoded["value"]["physics_state_modified"], false);
        assert_eq!(decoded["value"]["physical_acceptance_authority"], false);

        let v2_request = PlanScheduledLoadTransferV2Request {
            schema_version: "sporespore_plan_scheduled_load_transfer_request_v2".to_owned(),
            descriptor: plan_request.descriptor,
            request: ScheduledLoadTransferRequestV2 {
                schema_version: SCHEDULED_LOAD_TRANSFER_REQUEST_V2_VERSION.to_owned(),
                policy_id: SCHEDULED_LOAD_TRANSFER_BW10F_D_POLICY_ID.to_owned(),
                gait_amplitude: plan_request.request.gait_amplitude,
                cycle_steps: plan_request.request.cycle_steps,
                swing_steps: plan_request.request.swing_steps,
                characterized_friction_coefficient: plan_request
                    .request
                    .characterized_friction_coefficient,
                maximum_normal_force_n: plan_request.request.maximum_normal_force_n,
                feasibility_tolerance: plan_request.request.feasibility_tolerance,
                ordered_limb_gait_steps: plan_request.request.ordered_limb_gait_steps,
                stability_state: plan_request.request.stability_state,
            },
        };
        let input = serde_json::to_vec(&v2_request).unwrap();
        let (status, output) = call_with_retry(&input, ss_plan_scheduled_load_transfer_v2_json);
        assert_eq!(status, SS_OK);
        let decoded: serde_json::Value = serde_json::from_slice(&output).unwrap();
        assert_eq!(decoded["ok"], true);
        assert_eq!(
            decoded["value"]["schema_version"],
            "sporespore_scheduled_load_transfer_receipt_v2"
        );
        assert_eq!(decoded["value"]["planning_availability"], "available");
        assert_eq!(decoded["value"]["planning_outcome_code"], "AVAILABLE");
        assert_eq!(decoded["value"]["fail_zero_required"], false);
        assert_eq!(decoded["value"]["active"], true);
        assert_eq!(decoded["value"]["morphology_branch_surface_count"], 0);
        assert_eq!(decoded["value"]["walking_claim_authorized"], false);
        assert_eq!(decoded["value"]["physical_acceptance_authority"], false);

        let bw13p_v3_request = PlanScheduledLoadTransferV3Request {
            schema_version: "sporespore_plan_scheduled_load_transfer_request_v3".to_owned(),
            descriptor: v2_request.descriptor.clone(),
            request: ScheduledLoadTransferRequestV3 {
                schema_version: SCHEDULED_LOAD_TRANSFER_REQUEST_V3_VERSION.to_owned(),
                policy_id: SCHEDULED_LOAD_TRANSFER_BW13P_D_POLICY_ID.to_owned(),
                semantic_step: v2_request.request.stability_state.semantic_step,
                observation_available: true,
                observation_unavailable_reason: None,
                gait_amplitude: v2_request.request.gait_amplitude,
                cycle_steps: v2_request.request.cycle_steps,
                swing_steps: v2_request.request.swing_steps,
                characterized_friction_coefficient: v2_request
                    .request
                    .characterized_friction_coefficient,
                maximum_normal_force_n: v2_request.request.maximum_normal_force_n,
                feasibility_tolerance: v2_request.request.feasibility_tolerance,
                ordered_limb_gait_steps: v2_request.request.ordered_limb_gait_steps.clone(),
                stability_state: Some(v2_request.request.stability_state.clone()),
            },
        };
        let input = serde_json::to_vec(&bw13p_v3_request).unwrap();
        let (status, output) = call_with_retry(&input, ss_plan_scheduled_load_transfer_v3_json);
        assert_eq!(status, SS_OK);
        let decoded: serde_json::Value = serde_json::from_slice(&output).unwrap();
        assert_eq!(decoded["ok"], true);
        assert_eq!(
            decoded["value"]["policy_id"],
            SCHEDULED_LOAD_TRANSFER_BW13P_D_POLICY_ID
        );
        assert_eq!(decoded["value"]["planning_availability"], "available");
        assert_eq!(decoded["value"]["planning_outcome_code"], "AVAILABLE");
        assert_eq!(decoded["value"]["fail_zero_required"], false);
        assert_eq!(decoded["value"]["active"], true);
        assert_eq!(decoded["value"]["morphology_branch_surface_count"], 0);
        assert_eq!(decoded["value"]["walking_claim_authorized"], false);
        assert_eq!(decoded["value"]["physical_acceptance_authority"], false);

        let v3_request = PlanScheduledLoadTransferV3Request {
            schema_version: "sporespore_plan_scheduled_load_transfer_request_v3".to_owned(),
            descriptor: v2_request.descriptor,
            request: ScheduledLoadTransferRequestV3 {
                schema_version: SCHEDULED_LOAD_TRANSFER_REQUEST_V3_VERSION.to_owned(),
                policy_id: SCHEDULED_LOAD_TRANSFER_BW11R_D_POLICY_ID.to_owned(),
                semantic_step: v2_request.request.stability_state.semantic_step,
                observation_available: false,
                observation_unavailable_reason: Some("NO_QUALIFIED_SUPPORT_CONTACT".to_owned()),
                gait_amplitude: v2_request.request.gait_amplitude,
                cycle_steps: v2_request.request.cycle_steps,
                swing_steps: v2_request.request.swing_steps,
                characterized_friction_coefficient: v2_request
                    .request
                    .characterized_friction_coefficient,
                maximum_normal_force_n: v2_request.request.maximum_normal_force_n,
                feasibility_tolerance: v2_request.request.feasibility_tolerance,
                ordered_limb_gait_steps: v2_request.request.ordered_limb_gait_steps,
                stability_state: None,
            },
        };
        let input = serde_json::to_vec(&v3_request).unwrap();
        let (status, output) = call_with_retry(&input, ss_plan_scheduled_load_transfer_v3_json);
        assert_eq!(status, SS_OK);
        let decoded: serde_json::Value = serde_json::from_slice(&output).unwrap();
        assert_eq!(decoded["ok"], true);
        assert_eq!(
            decoded["value"]["schema_version"],
            "sporespore_scheduled_load_transfer_receipt_v3"
        );
        assert_eq!(decoded["value"]["observation_input_available"], false);
        assert_eq!(
            decoded["value"]["observation_unavailable_reason"],
            "NO_QUALIFIED_SUPPORT_CONTACT"
        );
        assert_eq!(
            decoded["value"]["planning_availability"],
            "observation_unavailable"
        );
        assert_eq!(decoded["value"]["fail_zero_required"], true);
        assert_eq!(
            decoded["value"]["ordered_safe_zero_actuator_ids"],
            serde_json::to_value(compiled.morphology.ordered_actuator_ids).unwrap()
        );
        assert_eq!(decoded["value"]["physical_acceptance_authority"], false);
    }

    #[test]
    fn domain_certificate_uses_same_buffer_protocol() {
        let mut required = 0;
        let first = unsafe { ss_gq15_domain_certificate_json(ptr::null_mut(), 0, &mut required) };
        assert_eq!(first, SS_BUFFER_TOO_SMALL);
        let mut output = vec![0_u8; required];
        let status = unsafe {
            ss_gq15_domain_certificate_json(output.as_mut_ptr(), output.len(), &mut required)
        };
        assert_eq!(status, SS_OK);
        let decoded: serde_json::Value = serde_json::from_slice(&output).unwrap();
        assert_eq!(
            decoded["value"]["continuous_full_volume_physical_locomotion_validated"],
            false
        );
    }

    #[test]
    fn recovery_development_profile_crosses_public_buffer_abi() {
        let mut required = 0;
        let first =
            unsafe { ss_recovery_development_profile_v1_json(ptr::null_mut(), 0, &mut required) };
        assert_eq!(first, SS_BUFFER_TOO_SMALL);
        assert!(required > 0);
        let mut output = vec![0_u8; required];
        let status = unsafe {
            ss_recovery_development_profile_v1_json(
                output.as_mut_ptr(),
                output.len(),
                &mut required,
            )
        };
        assert_eq!(status, SS_OK);
        let decoded: serde_json::Value = serde_json::from_slice(&output).unwrap();
        assert_eq!(decoded["ok"], true);
        assert_eq!(
            decoded["value"]["schema_version"],
            "sporespore_recovery_development_profile_v1"
        );
        assert_eq!(
            decoded["value"]["development_cohort"]
                .as_array()
                .unwrap()
                .len(),
            3
        );
        assert_eq!(
            decoded["value"]["held_out_native_cohort"]
                .as_array()
                .unwrap()
                .len(),
            9
        );
        assert_eq!(decoded["value"]["physical_execution_authorized"], false);
        assert_eq!(decoded["value"]["physical_acceptance_authority"], false);
        assert_eq!(decoded["value"]["release_authority"], false);
    }

    #[test]
    fn morphology_aware_recovery_entrypoints_fail_closed_through_public_buffer_abi() {
        let malformed = serde_json::to_vec(&serde_json::json!({})).unwrap();
        let entrypoints: [(
            &str,
            unsafe extern "C" fn(*const u8, usize, *mut u8, usize, *mut usize) -> c_int,
        ); 28] = [
            ("r10y_partial_entry_control_v1", ss_recovery_r10y_partial_entry_control_v1_json),
            ("r10y_partial_step_control_v1", ss_recovery_r10y_partial_step_control_v1_json),
            ("r10q_upright_entry_control_v1", ss_recovery_r10q_upright_entry_control_v1_json),
            ("upright_step_control_v1", ss_recovery_upright_step_control_v1_json),
            ("r10r_upright_step_control_v1", ss_recovery_r10r_upright_step_control_v1_json),
            ("r10k_entry_control_v1", ss_recovery_r10k_entry_control_v1_json),
            ("partial_fall_step_control_v1", ss_recovery_partial_fall_step_control_v1_json),
            ("collect_passive_native_v1", ss_recovery_collect_passive_native_v1_json),
            ("passive_entry_v1", ss_recovery_passive_entry_step_v1_json),
            ("initialize_v2", ss_recovery_initialize_v2_json),
            ("step_v2", ss_recovery_step_v2_json),
            ("step_v3", ss_recovery_step_v3_json),
            ("step_v4", ss_recovery_step_v4_json),
            ("step_v5", ss_recovery_step_v5_json),
            ("evaluate_v2", ss_recovery_evaluate_trace_v2_json),
            ("evaluate_v3", ss_recovery_evaluate_trace_v3_json),
            ("evaluate_v4", ss_recovery_evaluate_trace_v4_json),
            ("evaluate_v5", ss_recovery_evaluate_trace_v5_json),
            (
                "energy_aggregate_v3",
                ss_recovery_energy_balance_aggregate_v3_json,
            ),
            (
                "energy_evaluate_v3",
                ss_recovery_energy_balance_evaluate_v3_json,
            ),
            ("collect_native_v2", ss_recovery_collect_native_v2_json),
            ("collect_native_v3", ss_recovery_collect_native_v3_json),
            ("plan_control_v2", ss_recovery_plan_control_v2_json),
            ("plan_control_v3", ss_recovery_plan_control_v3_json),
            (
                "plan_stance_control_v1",
                ss_recovery_plan_stance_control_v1_json,
            ),
            (
                "plan_stance_control_v2",
                ss_recovery_plan_stance_control_v2_json,
            ),
            (
                "plan_stance_control_v3",
                ss_recovery_plan_stance_control_v3_json,
            ),
            (
                "plan_stance_control_v4",
                ss_recovery_plan_stance_control_v4_json,
            ),
        ];
        for (entrypoint, function) in entrypoints {
            let (status, output) = call_with_retry(&malformed, function);
            assert_eq!(status, SS_CORE_ERROR, "{entrypoint}");
            let decoded: serde_json::Value = serde_json::from_slice(&output).unwrap();
            assert_eq!(decoded["ok"], false, "{entrypoint}");
            assert_eq!(decoded["failure_code"], "SCHEMA_INVALID", "{entrypoint}");
        }
    }

    #[test]
    fn canonical_json_crosses_public_buffer_abi() {
        let value = serde_json::json!({
            "z": -0.0,
            "a": 1.234567890123456,
            "nested": {"integer_float": 3.0}
        });
        let input = serde_json::to_vec(&serde_json::json!({
            "schema_version": "sporespore_canonical_json_request_v1",
            "value": value
        }))
        .unwrap();
        let (status, output) = call_with_retry(&input, ss_canonicalize_json);
        assert_eq!(status, SS_OK);
        let decoded: serde_json::Value = serde_json::from_slice(&output).unwrap();
        assert_eq!(decoded["ok"], true);
        assert_eq!(
            decoded["value"]["schema_version"],
            "sporespore_canonical_json_receipt_v1"
        );
        assert_eq!(
            decoded["value"]["canonical_json"],
            canonical_json(&value).unwrap()
        );
        assert_eq!(decoded["value"]["sha256"], digest_json(&value).unwrap());
        assert_eq!(decoded["value"]["world_build_count"], 0);
        assert_eq!(decoded["value"]["physical_acceptance_authority"], false);

        let malformed = serde_json::to_vec(&serde_json::json!({
            "schema_version": "sporespore_canonical_json_request_v1",
            "value": {},
            "unknown": true
        }))
        .unwrap();
        let (malformed_status, malformed_output) =
            call_with_retry(&malformed, ss_canonicalize_json);
        assert_eq!(malformed_status, SS_CORE_ERROR);
        let malformed_decoded: serde_json::Value =
            serde_json::from_slice(&malformed_output).unwrap();
        assert_eq!(malformed_decoded["failure_code"], "SCHEMA_INVALID");
    }

    #[test]
    fn canonical_json_combined_receipt_matches_legacy_bytes_and_refusals() {
        use sha2::{Digest, Sha256};
        let values = [
            serde_json::json!(null),
            serde_json::json!(true),
            serde_json::json!(false),
            serde_json::json!(0),
            serde_json::json!(-0.0),
            serde_json::json!(1.0),
            serde_json::json!(1.234567890123456),
            serde_json::json!(1e-30),
            serde_json::json!(9_007_199_254_740_991_i64),
            serde_json::json!(9_007_199_254_740_992_u64),
            serde_json::json!(-9_007_199_254_740_992_i64),
            serde_json::json!({"z": [0.0, -0.0, 2, "é雪\n\t\"\\"], "a": {"x": 1.0}}),
        ];
        for value in values {
            let old = canonical_json(&value);
            let input = serde_json::to_vec(&serde_json::json!({
                "schema_version": "sporespore_canonical_json_request_v1", "value": value
            }))
            .unwrap();
            let (status, output) = call_with_retry(&input, ss_canonicalize_json);
            let actual: Value = serde_json::from_slice(&output).unwrap();
            match old {
                Ok(bytes) => {
                    let sha = format!("sha256:{:x}", Sha256::digest(bytes.as_bytes()));
                    assert_eq!(status, SS_OK);
                    assert_eq!(actual["value"]["canonical_json"], bytes);
                    assert_eq!(actual["value"]["sha256"], sha);
                    assert_eq!(actual["value"]["physical_acceptance_authority"], false);
                }
                Err(_) => {
                    assert_eq!(status, SS_CORE_ERROR);
                    assert_eq!(actual["ok"], false);
                }
            }
        }
    }

    #[test]
    fn public_header_matches_exported_primitive_abi_and_ownership_contract() {
        let header = include_str!("../../include/sporespore_locomotion.h");
        for declaration in [
            "#define SS_SDK_VERSION \"0.1.0\"",
            "#define SS_ABI_GENERATION 1",
            "SS_OK = 0",
            "SS_INVALID_ARGUMENT = 1",
            "SS_BUFFER_TOO_SMALL = 2",
            "SS_CORE_ERROR = 3",
            "SS_PANIC_CAUGHT = 4",
            "const char *ss_version(void)",
            "ss_canonicalize_json(",
            "ss_compile_bounded_quadruped_json(",
            "ss_compile_recovery_morphology_v1_json(",
            "ss_resolve_actuator_cap_profile_v1_json(",
            "ss_recovery_initialize_v1_json(",
            "ss_recovery_initialize_v2_json(",
            "ss_recovery_step_v1_json(",
            "ss_recovery_step_v2_json(",
            "ss_recovery_step_v3_json(",
            "ss_recovery_step_v4_json(",
            "ss_recovery_step_v5_json(",
            "ss_recovery_passive_entry_step_v1_json(",
            "ss_recovery_collect_passive_native_v1_json(",
            "ss_recovery_r10k_entry_control_v1_json(",
            "ss_recovery_partial_fall_step_control_v1_json(",
            "ss_recovery_r10q_upright_entry_control_v1_json(",
            "ss_recovery_upright_step_control_v1_json(",
            "ss_recovery_r10r_upright_step_control_v1_json(",
            "ss_recovery_r10y_partial_entry_control_v1_json(",
            "ss_recovery_r10y_partial_step_control_v1_json(",
            "ss_recovery_evaluate_trace_v1_json(",
            "ss_recovery_evaluate_trace_v2_json(",
            "ss_recovery_evaluate_trace_v3_json(",
            "ss_recovery_evaluate_trace_v4_json(",
            "ss_recovery_evaluate_trace_v5_json(",
            "ss_recovery_energy_balance_aggregate_v3_json(",
            "ss_recovery_energy_balance_evaluate_v3_json(",
            "ss_recovery_development_profile_v1_json(",
            "ss_recovery_collect_native_v1_json(",
            "ss_recovery_collect_native_v2_json(",
            "ss_recovery_collect_native_v3_json(",
            "ss_recovery_plan_control_v1_json(",
            "ss_recovery_plan_control_v2_json(",
            "ss_recovery_plan_control_v3_json(",
            "ss_canonical_velocity_compose_v1_json(",
            "ss_canonical_velocity_host_map_v1_json(",
            "ss_resolve_adaptation_v1_json(",
            "ss_candidate35_profile_json(",
            "ss_balanced_wave_profile_json(",
            "ss_balanced_wave_policy_profile_json(",
            "ss_gq15_domain_certificate_json(",
            "ss_candidate35_initial_memory_json(",
            "ss_balanced_wave_initial_memory_json(",
            "ss_balanced_wave_policy_initial_memory_json(",
            "ss_candidate35_step_json(",
            "ss_balanced_wave_step_json(",
            "ss_balanced_wave_policy_step_json(",
            "ss_balanced_wave_policy_session_create_json(",
            "ss_balanced_wave_policy_session_step_json(",
            "ss_balanced_wave_policy_session_destroy(",
            "ss_observe_stability_v2_json(",
            "ss_plan_scheduled_load_transfer_v1_json(",
            "ss_plan_scheduled_load_transfer_v2_json(",
            "ss_plan_scheduled_load_transfer_v3_json(",
            "ss_command_centroidal_support_v2_json(",
            "ss_map_endpoint_force_to_joint_v2_json(",
            "ss_map_endpoint_force_to_joint_v3_json(",
            "ss_bound_stability_influence_v2_json(",
            "ss_bound_stability_influence_v3_json(",
            "size_t *output_length",
            "output=NULL",
            "may not overlap",
            "Handles are process-local, opaque, nonzero",
            "destroyed exactly",
        ] {
            assert!(
                header.contains(declaration),
                "public header missing ABI contract fragment: {declaration}"
            );
        }
        assert_eq!(SS_OK, 0);
        assert_eq!(SS_INVALID_ARGUMENT, 1);
        assert_eq!(SS_BUFFER_TOO_SMALL, 2);
        assert_eq!(SS_CORE_ERROR, 3);
        assert_eq!(SS_PANIC_CAUGHT, 4);
    }
}
