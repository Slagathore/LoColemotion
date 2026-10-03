//! Zero-world qualification of the R23D64 Rapier public-profile production
//! dependency route.
//!
//! The route resolves the R23D61 profile, converts it through Rapier's real
//! ForceBased motor helpers, and compiles the complete force plan consumed by
//! the physical `HostRobot` constructor.  It deliberately never calls that
//! constructor, creates no model or world, and advances no solver.

use serde_json::{Value, json};
use sporespore_locomotion_core::{
    ACTUATOR_CAP_PROFILE_REQUEST_V1_VERSION, ActuatorCapProfileRequestV1,
    ActuatorCapProfileSupportStatusV1, BoundedQuadrupedDescriptor,
    R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID, R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256,
    compile_bounded_quadruped, r23d60_selected_s169_descriptor, resolve_actuator_cap_profile_v1,
};

use crate::actuator_cap_profile::{
    RapierPublicActuatorCapBindingV1, resolve_production_public_profile_binding_v1,
};
use crate::locomotion::compile_public_profile_actuator_force_plan_v1;

const CAMPAIGN_ID: &str = "QSDK-R23D64-RAPIER-LAUNCH-CONTRACT-REPAIRED-SELECTED-PROFILE-MATCHED-THREE-ENGINE-TURNING-VALIDATION";
const GATE_ID: &str = "QSDK-R23D64";
const ENGINE_ID: &str = "rapier_parry";
const HOST_MAPPING_ID: &str = "sporespore_rapier_force_based_outer_impulse_cap_mapping_v1";
const ROUTE_SCHEMA: &str =
    "sporespore_qsdk_r23d64_rapier_public_profile_production_route_zero_world_v1";

fn rejected(
    compiled: &sporespore_locomotion_core::CompiledQuadruped,
    binding: &RapierPublicActuatorCapBindingV1,
) -> bool {
    compile_public_profile_actuator_force_plan_v1(compiled, binding).is_err()
}

fn record_mutation(
    results: &mut Vec<Value>,
    mutation_id: &str,
    rejected: bool,
) -> Result<(), String> {
    results.push(json!({
        "mutation_id": mutation_id,
        "rejected": rejected,
    }));
    if !rejected {
        return Err(format!(
            "QSDK_R23D64_RAP_ROUTE_MUTATION_ACCEPTED:{mutation_id}"
        ));
    }
    Ok(())
}

fn mutation_controls(
    compiled: &sporespore_locomotion_core::CompiledQuadruped,
    binding: &RapierPublicActuatorCapBindingV1,
) -> Result<Vec<Value>, String> {
    let mut results = Vec::new();

    let mut candidate = binding.clone();
    candidate.resolution_receipt["requested_profile_id"] = json!("mutated");
    record_mutation(
        &mut results,
        "wrong_resolution_profile_id",
        rejected(compiled, &candidate),
    )?;

    let mut candidate = binding.clone();
    candidate.resolution_receipt["support_status"] = json!("out_of_domain_morphology");
    record_mutation(
        &mut results,
        "wrong_resolution_support_status",
        rejected(compiled, &candidate),
    )?;

    let mut candidate = binding.clone();
    candidate.resolution_receipt["profile"]["supported_morphology_id"] = json!("mutated");
    record_mutation(
        &mut results,
        "wrong_resolution_morphology_id",
        rejected(compiled, &candidate),
    )?;

    let mut candidate = binding.clone();
    candidate.host_mapping_receipt["schema_version"] = json!("mutated");
    record_mutation(
        &mut results,
        "wrong_host_mapping_schema",
        rejected(compiled, &candidate),
    )?;

    let mut candidate = binding.clone();
    candidate.host_mapping_receipt["host_mapping_id"] = json!("mutated");
    record_mutation(
        &mut results,
        "wrong_host_mapping_id",
        rejected(compiled, &candidate),
    )?;

    let mut candidate = binding.clone();
    candidate.host_mapping_receipt["profile_sha256"] = json!("sha256:mutated");
    record_mutation(
        &mut results,
        "wrong_host_profile_sha256",
        rejected(compiled, &candidate),
    )?;

    let mut candidate = binding.clone();
    candidate.host_mapping_receipt["world_build_count"] = json!(1);
    record_mutation(
        &mut results,
        "inflated_host_world_count",
        rejected(compiled, &candidate),
    )?;

    let mut candidate = binding.clone();
    candidate
        .host_mapping_receipt
        .get_mut("ordered_mappings")
        .and_then(Value::as_array_mut)
        .expect("fixture host rows")
        .pop();
    record_mutation(
        &mut results,
        "missing_host_mapping_row",
        rejected(compiled, &candidate),
    )?;

    let mut candidate = binding.clone();
    candidate.ordered_mappings.swap(0, 1);
    record_mutation(
        &mut results,
        "swapped_typed_mapping_order",
        rejected(compiled, &candidate),
    )?;

    let mut candidate = binding.clone();
    candidate.ordered_mappings[0].portable_maximum_outer_step_impulse_nms = 0.0;
    record_mutation(
        &mut results,
        "zero_typed_portable_cap",
        rejected(compiled, &candidate),
    )?;

    let mut candidate = binding.clone();
    candidate.ordered_mappings[0].rapier_maximum_force_nm_f32 *= 1.01;
    record_mutation(
        &mut results,
        "wrong_typed_maximum_force",
        rejected(compiled, &candidate),
    )?;

    let mut candidate = binding.clone();
    candidate.ordered_mappings[0].reconstructed_outer_step_impulse_nms = 0.0;
    record_mutation(
        &mut results,
        "wrong_typed_reconstruction",
        rejected(compiled, &candidate),
    )?;

    let mut candidate = binding.clone();
    candidate.ordered_mappings[0].outer_step_reconstruction_budget_nms = 0.0;
    record_mutation(
        &mut results,
        "insufficient_typed_rounding_budget",
        rejected(compiled, &candidate),
    )?;

    let mut candidate = binding.clone();
    candidate.host_mapping_receipt["ordered_mappings"][0]["rapier_maximum_force_nm_f32"] =
        json!(0.0);
    record_mutation(
        &mut results,
        "wrong_host_force_readback",
        rejected(compiled, &candidate),
    )?;

    let other = compile_bounded_quadruped(BoundedQuadrupedDescriptor::reference(
        "r23d64_valid_out_of_domain_route_control",
    ))
    .map_err(|error| error.to_string())?;
    record_mutation(
        &mut results,
        "valid_out_of_domain_compiled_morphology",
        rejected(&other, binding),
    )?;

    Ok(results)
}

fn support_controls() -> Result<Value, String> {
    let ood = resolve_actuator_cap_profile_v1(ActuatorCapProfileRequestV1 {
        schema_version: ACTUATOR_CAP_PROFILE_REQUEST_V1_VERSION.to_owned(),
        profile_id: R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID.to_owned(),
        descriptor: BoundedQuadrupedDescriptor::reference(
            "r23d64_valid_out_of_domain_resolution_control",
        ),
    })
    .map_err(|error| error.to_string())?;
    let unsupported = resolve_actuator_cap_profile_v1(ActuatorCapProfileRequestV1 {
        schema_version: ACTUATOR_CAP_PROFILE_REQUEST_V1_VERSION.to_owned(),
        profile_id: "sporespore_unknown_profile_control".to_owned(),
        descriptor: r23d60_selected_s169_descriptor(),
    })
    .map_err(|error| error.to_string())?;
    if ood.support_status != ActuatorCapProfileSupportStatusV1::OutOfDomainMorphology
        || ood.profile.is_some()
        || unsupported.support_status == ActuatorCapProfileSupportStatusV1::SupportedExact
        || unsupported.profile.is_some()
    {
        return Err("QSDK_R23D64_RAP_ROUTE_SUPPORT_CONTROLS_INVALID".to_owned());
    }
    Ok(json!({
        "valid_out_of_domain_morphology_refused": true,
        "unsupported_profile_refused": true,
        "control_count": 2,
    }))
}

/// Execute the complete R23D64 Rapier production dependency-route gate without
/// constructing a native model or physics world.
pub fn run_qsdk_r23d64_rapier_public_profile_route_preflight() -> Result<Value, String> {
    let compiled = compile_bounded_quadruped(r23d60_selected_s169_descriptor())
        .map_err(|error| error.to_string())?;
    let binding = resolve_production_public_profile_binding_v1()?;
    let force_plan = compile_public_profile_actuator_force_plan_v1(&compiled, &binding)?;
    if !force_plan.public_profile_bound
        || force_plan.ordered_entries.len() != 8
        || force_plan
            .ordered_entries
            .iter()
            .zip(&binding.ordered_mappings)
            .any(|(plan, mapping)| {
                plan.actuator_id != mapping.actuator_id
                    || plan.joint_id != mapping.joint_id
                    || plan.portable_maximum_outer_step_impulse_nms
                        != mapping.portable_maximum_outer_step_impulse_nms
                    || plan.maximum_force_nm != mapping.rapier_maximum_force_nm_f32
            })
    {
        return Err("QSDK_R23D64_RAP_ROUTE_FORCE_PLAN_INVALID".to_owned());
    }
    let mutations = mutation_controls(&compiled, &binding)?;
    let support = support_controls()?;
    let ordered_force_plan = force_plan
        .ordered_entries
        .iter()
        .map(|entry| {
            json!({
                "actuator_id": entry.actuator_id,
                "joint_id": entry.joint_id,
                "portable_maximum_outer_step_impulse_nms":
                    entry.portable_maximum_outer_step_impulse_nms,
                "rapier_maximum_force_nm_f32": entry.maximum_force_nm,
            })
        })
        .collect::<Vec<_>>();

    Ok(json!({
        "schema_version": ROUTE_SCHEMA,
        "ok": true,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "engine_id": ENGINE_ID,
        "question_class": "non_physical_native_dependency_route_qualification",
        "profile_id": R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
        "profile_sha256": R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256,
        "host_mapping_id": HOST_MAPPING_ID,
        "actuator_cap_profile_resolution_receipt": binding.resolution_receipt,
        "actuator_cap_profile_host_mapping_receipt": binding.host_mapping_receipt,
        "ordered_production_force_plan": ordered_force_plan,
        "validated_actuator_count": 8,
        "force_plan_compiled_before_first_native_model": true,
        "same_typed_force_plan_consumed_by_physical_constructor": true,
        "production_force_plan_function": "compile_public_profile_actuator_force_plan_v1",
        "production_physical_constructor":
            "build_bw19v_velocity_only_v4_robot_with_public_profile",
        "historical_constructor_behavior_changed": false,
        "mutation_rejection_count": mutations.len(),
        "mutation_results": mutations,
        "support_controls": support,
        "standalone_joint_value_count": 8,
        "rigid_body_set_construction_count": 0,
        "collider_set_construction_count": 0,
        "physics_pipeline_construction_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": false,
        "physical_execution_authorized": false,
        "turning_claimed": false,
        "finite_three_engine_turning_claimed": false,
        "q_sdk_r23_satisfied": false,
        "physical_acceptance_authority": false,
        "release_authority": false,
    }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn exact_public_profile_reaches_the_shared_production_force_plan_without_a_world() {
        let report = run_qsdk_r23d64_rapier_public_profile_route_preflight().unwrap();
        assert_eq!(report["ok"], true);
        assert_eq!(report["validated_actuator_count"], 8);
        assert_eq!(report["mutation_rejection_count"], 15);
        assert_eq!(report["support_controls"]["control_count"], 2);
        assert_eq!(report["model_construction_count"], 0);
        assert_eq!(report["world_attempt_count"], 0);
        assert_eq!(report["world_build_count"], 0);
        assert_eq!(report["solver_step_count"], 0);
        assert_eq!(report["physical_execution_authorized"], false);
        assert_eq!(report["turning_claimed"], false);
        assert_eq!(report["q_sdk_r23_satisfied"], false);
        assert_eq!(report["physical_acceptance_authority"], false);
        assert_eq!(report["release_authority"], false);
    }
}
