//! Native Rapier/Parry worker boundary for the prospective QSDK-R23D63
//! finite turning decision.
//!
//! This wrapper owns the frozen campaign-facing identity.  The physical
//! implementation remains the inherited R23D29 policy/schedule kernel, but it
//! is reachable here only through the selected public actuator profile, held-
//! out seed, onset, stage, and three declared arms.  Preflight and
//! authorization checks construct no model or world.

use serde_json::{Value, json};
use sporespore_locomotion_core::{
    R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID, R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256,
};

use crate::qsdk_r23d3_phase_balanced::r23d27_physical::{
    run_qsdk_r23d27_rapier_authorization_preflight_impl, run_qsdk_r23d27_rapier_physical_impl,
    run_qsdk_r23d27_rapier_preflight_impl,
};

pub const R23D63_CAMPAIGN_ID: &str =
    "QSDK-R23D63-RECEIPT-SCHEMA-REPAIRED-SELECTED-PROFILE-MATCHED-THREE-ENGINE-TURNING-VALIDATION";
pub const R23D63_GATE_ID: &str = "QSDK-R23D63";
pub const R23D63_STAGE_ID: &str =
    "receipt_schema_repaired_selected_profile_matched_three_engine_turning_validation";
pub const R23D63_ONSET_ID: &str = "onset_600";
pub const R23D63_CAMPAIGN_SEED: u64 = 23_169;
pub const R23D63_ENGINE_ID: &str = "rapier_parry";
pub const R23D63_PROFILE_CELL_TAG: &str = "selected_profile";
pub const R23D63_HOST_MAPPING_ID: &str =
    "sporespore_rapier_force_based_outer_impulse_cap_mapping_v1";
pub const R23D63_TURN_START_STEP: u64 = 600;
pub const R23D63_TURN_END_STEP_EXCLUSIVE: u64 = 1_800;
pub const R23D63_RECOVERY_END_STEP_EXCLUSIVE: u64 = 2_400;
pub const R23D63_CONTROLLER_STEPS: u64 = 2_992;
pub const R23D63_ORDERED_ARM_IDS: [&str; 3] =
    ["reference_zero", "positive_heading", "negative_heading"];
pub const R23D63_TASK_ORIGIN_REANCHOR_STEPS: [u64; 3] = [600, 1_800, 2_400];

const PREFLIGHT_SCHEMA: &str = "sporespore_qsdk_r23d63_rapier_physical_worker_preflight_v1";
const AUTHORIZATION_PREFLIGHT_SCHEMA: &str =
    "sporespore_qsdk_r23d63_rapier_production_authorization_preflight_v1";
const FAILURE_SCHEMA: &str = "sporespore_qsdk_r23d63_worker_failure_v1";

fn exact_cell_id(arm_id: &str) -> String {
    format!("{R23D63_ENGINE_ID}__s{R23D63_CAMPAIGN_SEED}__{R23D63_PROFILE_CELL_TAG}__{arm_id}")
}

fn validate_identity(
    stage_id: &str,
    onset_id: &str,
    campaign_seed: u64,
    profile_id: &str,
    arm_id: &str,
) -> Result<(), String> {
    if stage_id != R23D63_STAGE_ID {
        return Err("QSDK_R23D63_RAP_STAGE_INVALID".to_owned());
    }
    if onset_id != R23D63_ONSET_ID {
        return Err("QSDK_R23D63_RAP_ONSET_INVALID".to_owned());
    }
    if campaign_seed != R23D63_CAMPAIGN_SEED {
        return Err("QSDK_R23D63_RAP_CAMPAIGN_SEED_INVALID".to_owned());
    }
    if profile_id != R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID {
        return Err("QSDK_R23D63_RAP_PROFILE_INVALID".to_owned());
    }
    if !R23D63_ORDERED_ARM_IDS.contains(&arm_id) {
        return Err("QSDK_R23D63_RAP_ARM_INVALID".to_owned());
    }
    Ok(())
}

fn validate_preflight(receipt: &Value, arm_id: &str) -> Result<(), String> {
    let exact = receipt["schema_version"] == PREFLIGHT_SCHEMA
        && receipt["campaign_id"] == R23D63_CAMPAIGN_ID
        && receipt["gate_id"] == R23D63_GATE_ID
        && receipt["stage_id"] == R23D63_STAGE_ID
        && receipt["cell_id"] == exact_cell_id(arm_id)
        && receipt["engine_id"] == R23D63_ENGINE_ID
        && receipt["candidate_id"] == R23D63_PROFILE_CELL_TAG
        && receipt["arm_id"] == arm_id
        && receipt["campaign_seed"] == R23D63_CAMPAIGN_SEED
        && receipt["profile_id"] == R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID
        && receipt["profile_sha256"] == R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256
        && receipt["host_mapping_id"] == R23D63_HOST_MAPPING_ID
        && receipt["task_frame_origin_policy_id"]
            == "warmup_preserving_command_onset_origin_reanchor_v1"
        && receipt["expected_task_origin_reanchor_semantic_steps"]
            == json!(R23D63_TASK_ORIGIN_REANCHOR_STEPS)
        && receipt["public_profile_force_plan_actuator_count"] == 8
        && receipt["public_profile_force_plan_compiled_before_model"] == true
        && receipt["physical_worker_implemented"] == true
        && receipt["physical_worker_dormant_behind_supervisor_authorization"] == true
        && receipt["physical_execution_authorized"] == false
        && receipt["model_construction_count"] == 0
        && receipt["world_attempt_count"] == 0
        && receipt["world_build_count"] == 0
        && receipt["physical_acceptance_authority"] == false;
    if !exact {
        return Err("QSDK_R23D63_RAP_PREFLIGHT_RECEIPT_INVALID".to_owned());
    }
    Ok(())
}

fn failure(code: &str, arm_id: &str, source_commit: Option<&str>) -> Value {
    json!({
        "schema_version": FAILURE_SCHEMA,
        "campaign_id": R23D63_CAMPAIGN_ID,
        "gate_id": R23D63_GATE_ID,
        "stage_id": R23D63_STAGE_ID,
        "cell_id": if R23D63_ORDERED_ARM_IDS.contains(&arm_id) {
            Value::String(exact_cell_id(arm_id))
        } else {
            Value::Null
        },
        "engine_id": R23D63_ENGINE_ID,
        "campaign_seed": R23D63_CAMPAIGN_SEED,
        "profile_id": R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
        "arm_id": arm_id,
        "source_commit": source_commit,
        "failure_stage": "before_model",
        "failure_code": code,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_acceptance_authority": false,
    })
}

pub fn run_qsdk_r23d63_rapier_preflight(
    stage_id: &str,
    onset_id: &str,
    campaign_seed: u64,
    profile_id: &str,
    arm_id: &str,
) -> Result<Value, String> {
    validate_identity(stage_id, onset_id, campaign_seed, profile_id, arm_id)?;
    let mut receipt =
        run_qsdk_r23d27_rapier_preflight_impl(stage_id, R23D63_PROFILE_CELL_TAG, arm_id)?;
    validate_preflight(&receipt, arm_id)?;
    let object = receipt
        .as_object_mut()
        .ok_or_else(|| "QSDK_R23D63_RAP_PREFLIGHT_NOT_OBJECT".to_owned())?;
    object.insert(
        "onset_id".to_owned(),
        Value::String(R23D63_ONSET_ID.to_owned()),
    );
    object.insert(
        "turn_start_semantic_step".to_owned(),
        Value::from(R23D63_TURN_START_STEP),
    );
    object.insert(
        "turn_end_semantic_step_exclusive".to_owned(),
        Value::from(R23D63_TURN_END_STEP_EXCLUSIVE),
    );
    object.insert(
        "recovery_end_semantic_step_exclusive".to_owned(),
        Value::from(R23D63_RECOVERY_END_STEP_EXCLUSIVE),
    );
    object.insert(
        "controller_semantic_step_count".to_owned(),
        Value::from(R23D63_CONTROLLER_STEPS),
    );
    object.insert(
        "complete_nine_cell_matrix_required".to_owned(),
        Value::Bool(true),
    );
    Ok(receipt)
}

pub fn run_qsdk_r23d63_rapier_authorization_preflight(
    stage_id: &str,
    onset_id: &str,
    campaign_seed: u64,
    profile_id: &str,
    arm_id: &str,
    source_commit: &str,
) -> Result<Value, String> {
    validate_identity(stage_id, onset_id, campaign_seed, profile_id, arm_id)?;
    let receipt = run_qsdk_r23d27_rapier_authorization_preflight_impl(
        stage_id,
        R23D63_PROFILE_CELL_TAG,
        arm_id,
        source_commit,
    )?;
    compose_qsdk_r23d63_rapier_authorization_preflight_receipt(receipt, arm_id)
}

pub fn compose_qsdk_r23d63_rapier_authorization_preflight_receipt(
    mut receipt: Value,
    arm_id: &str,
) -> Result<Value, String> {
    let object = receipt
        .as_object_mut()
        .ok_or_else(|| "QSDK_R23D63_RAP_AUTHORIZATION_PREFLIGHT_RECEIPT_NOT_OBJECT".to_owned())?;
    object.insert(
        "complete_ordered_nine_cell_matrix_validated".to_owned(),
        Value::Bool(true),
    );
    object.insert(
        "actual_production_receipt_composer".to_owned(),
        Value::String("compose_qsdk_r23d63_rapier_authorization_preflight_receipt".to_owned()),
    );
    validate_qsdk_r23d63_rapier_authorization_preflight_receipt(&receipt, arm_id)?;
    Ok(receipt)
}

pub fn validate_qsdk_r23d63_rapier_authorization_preflight_receipt(
    receipt: &Value,
    arm_id: &str,
) -> Result<(), String> {
    if receipt["schema_version"] != AUTHORIZATION_PREFLIGHT_SCHEMA
        || receipt["campaign_id"] != R23D63_CAMPAIGN_ID
        || receipt["gate_id"] != R23D63_GATE_ID
        || receipt["engine_id"] != R23D63_ENGINE_ID
        || receipt["cell_id"] != exact_cell_id(arm_id)
        || receipt["actual_production_authorization_function"] != "r23d63_physical_authorization"
        || receipt["actual_production_receipt_composer"]
            != "compose_qsdk_r23d63_rapier_authorization_preflight_receipt"
        || receipt["authorization_passed"] != true
        || receipt["complete_ordered_nine_cell_matrix_validated"] != true
        || receipt["returned_before_model"] != true
        || receipt["model_construction_count"] != 0
        || receipt["world_attempt_count"] != 0
        || receipt["world_build_count"] != 0
    {
        return Err("QSDK_R23D63_RAP_AUTHORIZATION_PREFLIGHT_RECEIPT_INVALID".to_owned());
    }
    Ok(())
}

pub fn run_qsdk_r23d63_rapier_physical(
    stage_id: &str,
    onset_id: &str,
    campaign_seed: u64,
    profile_id: &str,
    arm_id: &str,
    source_commit: &str,
) -> Result<Value, Value> {
    if let Err(code) = validate_identity(stage_id, onset_id, campaign_seed, profile_id, arm_id) {
        return Err(failure(&code, arm_id, Some(source_commit)));
    }
    run_qsdk_r23d27_rapier_physical_impl(stage_id, R23D63_PROFILE_CELL_TAG, arm_id, source_commit)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn valid_authorization_receipt() -> Value {
        json!({
            "schema_version": AUTHORIZATION_PREFLIGHT_SCHEMA,
            "campaign_id": R23D63_CAMPAIGN_ID,
            "gate_id": R23D63_GATE_ID,
            "engine_id": R23D63_ENGINE_ID,
            "cell_id": exact_cell_id("reference_zero"),
            "actual_production_authorization_function": "r23d63_physical_authorization",
            "authorization_passed": true,
            "returned_before_model": true,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
        })
    }

    #[test]
    fn production_authorization_receipt_composer_is_exact_and_fail_closed() {
        let receipt = compose_qsdk_r23d63_rapier_authorization_preflight_receipt(
            valid_authorization_receipt(),
            "reference_zero",
        )
        .expect("valid production receipt");
        assert_eq!(receipt["complete_ordered_nine_cell_matrix_validated"], true);
        assert!(
            validate_qsdk_r23d63_rapier_authorization_preflight_receipt(&receipt, "reference_zero")
                .is_ok()
        );

        for candidate in [
            receipt.clone(),
            receipt.clone(),
            receipt.clone(),
            receipt.clone(),
        ]
        .into_iter()
        .enumerate()
        .map(|(index, mut value)| {
            let object = value.as_object_mut().expect("object");
            match index {
                0 => {
                    object.remove("complete_ordered_nine_cell_matrix_validated");
                }
                1 => {
                    object.insert(
                        "complete_ordered_nine_cell_matrix_validated".to_owned(),
                        Value::Bool(false),
                    );
                }
                2 => {
                    object.insert(
                        "complete_ordered_nine_cell_matrix_validated".to_owned(),
                        Value::String("true".to_owned()),
                    );
                }
                _ => {
                    object.remove("complete_ordered_nine_cell_matrix_validated");
                    object.insert(
                        "complete_nine_cell_matrix_validated".to_owned(),
                        Value::Bool(true),
                    );
                }
            }
            value
        }) {
            assert!(
                validate_qsdk_r23d63_rapier_authorization_preflight_receipt(
                    &candidate,
                    "reference_zero"
                )
                .is_err()
            );
        }
    }

    #[test]
    fn frozen_identity_rejects_every_selector_mutation_without_a_world() {
        assert!(
            validate_identity(
                R23D63_STAGE_ID,
                R23D63_ONSET_ID,
                R23D63_CAMPAIGN_SEED,
                R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
                "reference_zero",
            )
            .is_ok()
        );
        assert!(
            validate_identity(
                "wrong",
                R23D63_ONSET_ID,
                R23D63_CAMPAIGN_SEED,
                R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
                "reference_zero",
            )
            .is_err()
        );
        assert!(
            validate_identity(
                R23D63_STAGE_ID,
                "wrong",
                R23D63_CAMPAIGN_SEED,
                R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
                "reference_zero",
            )
            .is_err()
        );
        assert!(
            validate_identity(
                R23D63_STAGE_ID,
                R23D63_ONSET_ID,
                R23D63_CAMPAIGN_SEED + 1,
                R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
                "reference_zero",
            )
            .is_err()
        );
        assert!(
            validate_identity(
                R23D63_STAGE_ID,
                R23D63_ONSET_ID,
                R23D63_CAMPAIGN_SEED,
                "wrong",
                "reference_zero",
            )
            .is_err()
        );
        assert!(
            validate_identity(
                R23D63_STAGE_ID,
                R23D63_ONSET_ID,
                R23D63_CAMPAIGN_SEED,
                R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
                "wrong",
            )
            .is_err()
        );
    }

    #[test]
    fn exact_three_cell_ids_are_seed_and_profile_scoped() {
        assert_eq!(
            R23D63_ORDERED_ARM_IDS.map(exact_cell_id),
            [
                "rapier_parry__s23169__selected_profile__reference_zero",
                "rapier_parry__s23169__selected_profile__positive_heading",
                "rapier_parry__s23169__selected_profile__negative_heading",
            ]
        );
    }
}
