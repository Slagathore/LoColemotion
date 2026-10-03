//! Zero-world Rapier composition recovery for the R23D14 stage-identity seam.
//!
//! The successor owns the outer stage identity. The inherited R23D11
//! composition preflight retains its own historical stage identity, so this
//! adapter translates deliberately and verifies the returned receipt instead
//! of forwarding an incompatible stage string through the physical worker.

use serde_json::{Value, json};

pub const R23D23_STAGE_ID: &str = "rapier_mujoco_reduced_yaw_implementation_recovery";
const INHERITED_R23D11_STAGE_ID: &str = "three_engine_confirmation";
const CAMPAIGN_ID: &str = "QSDK-R23D23-IMPLEMENTATION-RECOVERY-TRANSFER-CONFORMANCE";
const GATE_ID: &str = "QSDK-R23D23";

fn validate_arm(arm_id: &str) -> Result<(), String> {
    if matches!(
        arm_id,
        "reference_zero" | "positive_heading" | "negative_heading"
    ) {
        Ok(())
    } else {
        Err("R23D23_RAP_ARM_IDENTITY_INVALID".to_owned())
    }
}

pub fn run_qsdk_r23d23_rapier_inherited_composition_preflight(
    stage_id: &str,
    arm_id: &str,
) -> Result<Value, String> {
    if stage_id != R23D23_STAGE_ID {
        return Err("R23D23_RAP_STAGE_IDENTITY_INVALID".to_owned());
    }
    validate_arm(arm_id)?;

    let predecessor_direct_error =
        crate::qsdk_r23d11_stability_assisted_taper::run_qsdk_r23d11_rapier_preflight(
            stage_id, arm_id,
        )
        .expect_err("the incompatible predecessor binding must remain reproducible");
    if predecessor_direct_error != "R23D11_RAP_CELL_IDENTITY_INVALID" {
        return Err("R23D23_RAP_PREDECESSOR_FAILURE_SHAPE_CHANGED".to_owned());
    }

    let inherited = crate::qsdk_r23d11_stability_assisted_taper::run_qsdk_r23d11_rapier_preflight(
        INHERITED_R23D11_STAGE_ID,
        arm_id,
    )?;
    if inherited["stage_id"] != INHERITED_R23D11_STAGE_ID
        || inherited["arm_id"] != arm_id
        || inherited["composition_canary_count"] != 7
        || inherited["mutation_control_count"] != 18
        || inherited["model_construction_count"] != 0
        || inherited["world_build_count"] != 0
    {
        return Err("R23D23_RAP_INHERITED_RECEIPT_INVALID".to_owned());
    }

    Ok(json!({
        "schema_version": "sporespore_qsdk_r23d23_rapier_composition_recovery_v1",
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "engine_id": "rapier_parry",
        "stage_id": stage_id,
        "arm_id": arm_id,
        "inherited_gate_id": "QSDK-R23D11",
        "inherited_stage_id": INHERITED_R23D11_STAGE_ID,
        "predecessor_direct_binding_failure_reproduced": true,
        "predecessor_direct_binding_failure_code": predecessor_direct_error,
        "explicit_stage_translation_applied": true,
        "composition_canary_count": inherited["composition_canary_count"],
        "mutation_control_count": inherited["mutation_control_count"],
        "physical_worker_implemented": false,
        "physical_execution_authorized": false,
        "physical_process_launch_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "command_conditioned_turning": false,
        "cross_engine_equivalence": false,
        "physical_acceptance_authority": false,
    }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn successor_translates_all_three_declared_arms() {
        for arm_id in ["reference_zero", "positive_heading", "negative_heading"] {
            let receipt =
                run_qsdk_r23d23_rapier_inherited_composition_preflight(R23D23_STAGE_ID, arm_id)
                    .unwrap();
            assert_eq!(receipt["stage_id"], R23D23_STAGE_ID);
            assert_eq!(receipt["inherited_stage_id"], INHERITED_R23D11_STAGE_ID);
            assert_eq!(receipt["explicit_stage_translation_applied"], true);
            assert_eq!(receipt["world_build_count"], 0);
        }
    }

    #[test]
    fn predecessor_failure_is_reproduced_not_reinterpreted() {
        let error = crate::qsdk_r23d11_stability_assisted_taper::run_qsdk_r23d11_rapier_preflight(
            R23D23_STAGE_ID,
            "reference_zero",
        )
        .unwrap_err();
        assert_eq!(error, "R23D11_RAP_CELL_IDENTITY_INVALID");
    }

    #[test]
    fn successor_identity_mutations_fail_closed() {
        assert_eq!(
            run_qsdk_r23d23_rapier_inherited_composition_preflight(
                "three_engine_confirmation",
                "positive_heading",
            )
            .unwrap_err(),
            "R23D23_RAP_STAGE_IDENTITY_INVALID"
        );
        assert_eq!(
            run_qsdk_r23d23_rapier_inherited_composition_preflight(R23D23_STAGE_ID, "unknown_arm",)
                .unwrap_err(),
            "R23D23_RAP_ARM_IDENTITY_INVALID"
        );
    }

    #[test]
    fn successor_preflight_is_deterministic() {
        let first = run_qsdk_r23d23_rapier_inherited_composition_preflight(
            R23D23_STAGE_ID,
            "negative_heading",
        )
        .unwrap();
        let second = run_qsdk_r23d23_rapier_inherited_composition_preflight(
            R23D23_STAGE_ID,
            "negative_heading",
        )
        .unwrap();
        assert_eq!(first, second);
    }
}
