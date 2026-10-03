#ifndef SPORESPORE_LOCOMOTION_SDK1_H
#define SPORESPORE_LOCOMOTION_SDK1_H

/* Complete SDK1 surface, including the existing development recovery ABI.
 * The original header remains the compatibility surface for pinned clients. */
#include "sporespore_locomotion.h"

#ifdef __cplusplus
extern "C" {
#endif

SS_API ss_status ss_recovery_r10aa_partial_entry_control_v1_json(
    const uint8_t *input, size_t input_length,
    uint8_t *output, size_t output_capacity, size_t *output_length);
SS_API ss_status ss_recovery_r10aa_partial_step_control_v1_json(
    const uint8_t *input, size_t input_length,
    uint8_t *output, size_t output_capacity, size_t *output_length);
SS_API ss_status ss_recovery_r10ab_partial_entry_control_v1_json(
    const uint8_t *input, size_t input_length,
    uint8_t *output, size_t output_capacity, size_t *output_length);
SS_API ss_status ss_recovery_r10ab_partial_step_control_v1_json(
    const uint8_t *input, size_t input_length,
    uint8_t *output, size_t output_capacity, size_t *output_length);

#ifdef __cplusplus
}
#endif
#endif
