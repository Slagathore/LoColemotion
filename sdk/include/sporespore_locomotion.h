#ifndef SPORESPORE_LOCOMOTION_H
#define SPORESPORE_LOCOMOTION_H

#include <stddef.h>
#include <stdint.h>

#define SS_SDK_VERSION "0.1.0"
#define SS_ABI_GENERATION 1
#define SS_SELECTED_BALANCED_WAVE_CANDIDATE_ID "BW5R-B"
#define SS_SELECTED_BALANCED_WAVE_POLICY_ID "sporespore_balanced_wave_bw5r_b_v1"

#if defined(_WIN32)
#  if defined(SPORESPORE_LOCOMOTION_BUILD)
#    define SS_API __declspec(dllexport)
#  else
#    define SS_API __declspec(dllimport)
#  endif
#else
#  define SS_API
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef enum ss_status {
    SS_OK = 0,
    SS_INVALID_ARGUMENT = 1,
    SS_BUFFER_TOO_SMALL = 2,
    SS_CORE_ERROR = 3,
    SS_PANIC_CAUGHT = 4
} ss_status;

/* Returned pointer is process-static UTF-8 and must not be freed. */
SS_API const char *ss_version(void);

/*
 * All JSON functions use the same allocation-free caller-owned buffer
 * protocol:
 *
 * 1. Call with output=NULL and output_capacity=0.
 * 2. SS_BUFFER_TOO_SMALL is returned and *output_length receives the exact
 *    number of bytes required (no terminating NUL is included).
 * 3. Allocate at least that many bytes and call again.
 *
 * Input and output may not overlap. Receipts are canonical-schema records,
 * but transport JSON is not itself an evidence digest authority.
 */
SS_API ss_status ss_canonicalize_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

SS_API ss_status ss_compile_bounded_quadruped_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

/*
 * Compile a versioned recovery morphology and evaluate its exact canonical
 * prone ground geometry without constructing a model or world. Valid but
 * infeasible geometry returns a successful typed refusal receipt.
 */
SS_API ss_status ss_compile_recovery_morphology_v1_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

/*
 * Resolve a named actuator-cap profile without constructing a world or
 * applying host actuation. Valid descriptors outside a profile's declared
 * support scope return an explicit reasoned refusal receipt.
 */
SS_API ss_status ss_resolve_actuator_cap_profile_v1_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

/*
 * Validate and replay the exact-scope portable recovery semantics. These
 * entrypoints construct no host model or world, take no solver step, and emit
 * no controller actuation. Native observations remain refused until a later
 * prospectively frozen physical threshold profile exists.
 */
SS_API ss_status ss_recovery_initialize_v1_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

SS_API ss_status ss_recovery_step_v1_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

SS_API ss_status ss_recovery_evaluate_trace_v1_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

/*
 * Recovery V2 requests require an exact, versioned recovery-morphology
 * context. The V1 request schemas and entrypoints above remain unchanged.
 */
SS_API ss_status ss_recovery_initialize_v2_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

SS_API ss_status ss_recovery_step_v2_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

SS_API ss_status ss_recovery_evaluate_trace_v2_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

/*
 * Recovery V3 request identities carry the morphology context plus the true
 * flat observation-V2 schema. Existing V1/V2 request meanings are unchanged.
 */
SS_API ss_status ss_recovery_step_v3_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

SS_API ss_status ss_recovery_evaluate_trace_v3_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

/*
 * Recovery V4 consumes the additive observation-V3 energy and staging ledger.
 * Existing V1-V3 request meanings remain unchanged.
 */
SS_API ss_status ss_recovery_step_v4_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

/*
 * Recovery V5 adds a provenance-bound energy-partition authority and returns
 * the unchanged V1 step receipt inside an additive V2 progression receipt.
 */
SS_API ss_status ss_recovery_step_v5_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

/* Source validation for owner-none candidate descent. Never steps a controller. */
SS_API ss_status ss_recovery_collect_passive_native_v1_json(
    const uint8_t *input, size_t input_length,
    uint8_t *output, size_t output_capacity, size_t *output_length);

/* Development-only bounded passive descent and measured prone initialization.
 * No world, command, energy reset, acceptance or release authority. Existing
 * initialization/step/evaluation contracts are unchanged. */
SS_API ss_status ss_recovery_passive_entry_step_v1_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

/* R10K development entry selection and separate partial-fall supervision.
 * Source-bound planning only: no world, solver step, energy reset or claim. */
SS_API ss_status ss_recovery_r10k_entry_control_v1_json(
    const uint8_t *input, size_t input_length,
    uint8_t *output, size_t output_capacity, size_t *output_length);

SS_API ss_status ss_recovery_partial_fall_step_control_v1_json(
    const uint8_t *input, size_t input_length,
    uint8_t *output, size_t output_capacity, size_t *output_length);

/* R10AI development-only concurrent load/rise composition. Preserves the
 * original partial task, source ownership, energy ledger and terminal refusal.
 * No world, solver step, physical acceptance or release authority. */
SS_API ss_status ss_recovery_r10ai_partial_entry_control_v1_json(
    const uint8_t *input, size_t input_length,
    uint8_t *output, size_t output_capacity, size_t *output_length);
SS_API ss_status ss_recovery_r10ai_partial_step_control_v1_json(
    const uint8_t *input, size_t input_length,
    uint8_t *output, size_t output_capacity, size_t *output_length);

/* R10AJ development-only weak-support hip-recentering composition. Preserves the
 * original partial task, source ownership, energy ledger and terminal refusal.
 * No world, solver step, physical acceptance or release authority. */
SS_API ss_status ss_recovery_r10aj_partial_entry_control_v1_json(
    const uint8_t *input, size_t input_length,
    uint8_t *output, size_t output_capacity, size_t *output_length);
SS_API ss_status ss_recovery_r10aj_partial_step_control_v1_json(
    const uint8_t *input, size_t input_length,
    uint8_t *output, size_t output_capacity, size_t *output_length);

/* R10AM development composition; no physical or release authority. */
SS_API ss_status ss_recovery_r10am_partial_entry_control_v1_json(
    const uint8_t *input, size_t input_length,
    uint8_t *output, size_t output_capacity, size_t *output_length);
SS_API ss_status ss_recovery_r10am_partial_step_control_v1_json(
    const uint8_t *input, size_t input_length,
    uint8_t *output, size_t output_capacity, size_t *output_length);

/* R10AP development composition; no physical or release authority. */
SS_API ss_status ss_recovery_r10ap_partial_entry_control_v1_json(
    const uint8_t *input, size_t input_length,
    uint8_t *output, size_t output_capacity, size_t *output_length);
SS_API ss_status ss_recovery_r10ap_partial_step_control_v1_json(
    const uint8_t *input, size_t input_length,
    uint8_t *output, size_t output_capacity, size_t *output_length);

/* R10DD finite diagnostic reference; no execution or release authority. */
SS_API ss_status ss_recovery_r10dd_partial_entry_control_v1_json(
    const uint8_t *input, size_t input_length,
    uint8_t *output, size_t output_capacity, size_t *output_length);
SS_API ss_status ss_recovery_r10dd_partial_step_control_v1_json(
    const uint8_t *input, size_t input_length,
    uint8_t *output, size_t output_capacity, size_t *output_length);

/* R10Q upright stabilization preserves original timeout and energy receipts. */
SS_API ss_status ss_recovery_r10q_upright_entry_control_v1_json(
    const uint8_t *input, size_t input_length,
    uint8_t *output, size_t output_capacity, size_t *output_length);

SS_API ss_status ss_recovery_upright_step_control_v1_json(
    const uint8_t *input, size_t input_length,
    uint8_t *output, size_t output_capacity, size_t *output_length);

/* R10R source-bound upright step: V20 support, V12 direct rise, V7 stance. */
SS_API ss_status ss_recovery_r10r_upright_step_control_v1_json(
    const uint8_t *input, size_t input_length,
    uint8_t *output, size_t output_capacity, size_t *output_length);

/* R10Y development partial control; original selector/task results retained. */
SS_API ss_status ss_recovery_r10y_partial_entry_control_v1_json(
    const uint8_t *input, size_t input_length,
    uint8_t *output, size_t output_capacity, size_t *output_length);

SS_API ss_status ss_recovery_r10y_partial_step_control_v1_json(
    const uint8_t *input, size_t input_length,
    uint8_t *output, size_t output_capacity, size_t *output_length);

SS_API ss_status ss_recovery_r10z_partial_entry_control_v1_json(
    const uint8_t *input, size_t input_length,
    uint8_t *output, size_t output_capacity, size_t *output_length);

SS_API ss_status ss_recovery_r10z_partial_step_control_v1_json(
    const uint8_t *input, size_t input_length,
    uint8_t *output, size_t output_capacity, size_t *output_length);

SS_API ss_status ss_recovery_evaluate_trace_v4_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

/*
 * Recovery evaluator V5 replays observation-V3 traces with an explicit,
 * provenance-bound development energy authority. It cannot grant physical
 * acceptance or release authority. Existing V1-V4 meanings remain unchanged.
 */
SS_API ss_status ss_recovery_evaluate_trace_v5_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

/*
 * Recovery energy ledger V2 keeps signed external and constraint work separate
 * from nonnegative passive dissipation. These entrypoints aggregate or evaluate
 * supplied measurements and perform explicit V1/V2 migration without opening a
 * physics world. A lossy V2-to-V1 downgrade returns a typed refusal receipt.
 */
SS_API ss_status ss_recovery_energy_balance_aggregate_v2_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

SS_API ss_status ss_recovery_energy_balance_evaluate_v2_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

/*
 * Recovery energy ledger V3 adds signed discrete-staging exchange without
 * changing any V1/V2 schema or operation.
 */
SS_API ss_status ss_recovery_energy_balance_aggregate_v3_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

SS_API ss_status ss_recovery_energy_balance_evaluate_v3_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

SS_API ss_status ss_recovery_energy_balance_migrate_v1_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

/*
 * Publish the frozen exact-s169 recovery development profile, validate one
 * complete native post-step observation, and plan one engine-neutral command.
 * These entrypoints construct no model or world and take no solver step. The
 * profile grants no physical execution, acceptance, or release authority.
 */
SS_API ss_status ss_recovery_development_profile_v1_json(
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

SS_API ss_status ss_recovery_collect_native_v1_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

SS_API ss_status ss_recovery_collect_native_v2_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

SS_API ss_status ss_recovery_collect_native_v3_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

SS_API ss_status ss_recovery_plan_control_v1_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

SS_API ss_status ss_recovery_plan_control_v2_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

SS_API ss_status ss_recovery_plan_control_v3_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

SS_API ss_status ss_recovery_plan_stance_control_v1_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

SS_API ss_status ss_recovery_plan_stance_control_v2_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

SS_API ss_status ss_recovery_plan_stance_control_v3_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

SS_API ss_status ss_recovery_plan_stance_control_v4_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

SS_API ss_status ss_candidate35_profile_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

SS_API ss_status ss_balanced_wave_profile_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

SS_API ss_status ss_balanced_wave_policy_profile_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

SS_API ss_status ss_gq15_domain_certificate_json(
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

SS_API ss_status ss_candidate35_initial_memory_json(
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

SS_API ss_status ss_balanced_wave_initial_memory_json(
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

SS_API ss_status ss_balanced_wave_policy_initial_memory_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

SS_API ss_status ss_candidate35_step_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

SS_API ss_status ss_balanced_wave_step_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

SS_API ss_status ss_balanced_wave_policy_step_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

SS_API ss_status ss_observe_stability_v2_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

/*
 * Persistent balanced-wave sessions compile immutable morphology and policy
 * state once. Controller memory remains explicit in every step request.
 * Handles are process-local, opaque, nonzero, and must be destroyed exactly
 * once by the caller. Session step output uses the ordinary caller-owned
 * buffer protocol above and may be queried for size without mutating state.
 */
SS_API ss_status ss_balanced_wave_policy_session_create_json(
    const uint8_t *input,
    size_t input_length,
    uint64_t *session_handle);

SS_API ss_status ss_balanced_wave_policy_session_step_json(
    uint64_t session_handle,
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

SS_API ss_status ss_balanced_wave_policy_session_destroy(
    uint64_t session_handle);

SS_API ss_status ss_canonical_velocity_compose_v1_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

SS_API ss_status ss_canonical_velocity_host_map_v1_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

/*
 * Resolve an optional engine-neutral provider response against the request's
 * deterministic canonical baseline and fail-closed safety envelope. An absent,
 * invalid, stale, uncertain, refused, or out-of-domain response returns a
 * successful reasoned baseline-fallback receipt. The function itself builds
 * no world, mutates no physics state, and applies no host actuation.
 */
SS_API ss_status ss_resolve_adaptation_v1_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

SS_API ss_status ss_plan_scheduled_load_transfer_v1_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

SS_API ss_status ss_plan_scheduled_load_transfer_v2_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

SS_API ss_status ss_plan_scheduled_load_transfer_v3_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

SS_API ss_status ss_command_centroidal_support_v2_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

SS_API ss_status ss_map_endpoint_force_to_joint_v2_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

SS_API ss_status ss_map_endpoint_force_to_joint_v3_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

SS_API ss_status ss_bound_stability_influence_v2_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

SS_API ss_status ss_bound_stability_influence_v3_json(
    const uint8_t *input,
    size_t input_length,
    uint8_t *output,
    size_t output_capacity,
    size_t *output_length);

#ifdef __cplusplus
}
#endif

#endif
