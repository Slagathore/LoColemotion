use std::collections::BTreeMap;
use std::path::PathBuf;

use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use sporespore_rapier_adapter::evaluate_bw19v_velocity_only_long_horizon_lc1_report;

const CAMPAIGN_ID: &str = "C6-RAPIER-BW19V-VELOCITY-ONLY-LONG-HORIZON-COMMISSIONING-LC1";
const GATE_ID: &str = "C6-RAP-BW19V-V4-LC1";
const PHYSICAL_SOURCE_COMMIT: &str = "6a1968015dfbc7bb0ab2ff93f3467b5c2187781e";
const RETAINED_REPORT_RAW_SHA256: &str =
    "a2fc9432b4c18806dae4c906b9d6e826c21b1468bcadf40f74baa24efa13146f";
const CLOCKED_STEPS: u64 = 472;
const REQUIRED_POST_EVIDENCE_STEPS: u64 = 360;
const TOTAL_STEPS: u64 = 2_992;
const TERMINAL_STANCE_FAILURE: &str = "C6_RAP_V4_LC1_TERMINAL_STANCE";

const ORIGINAL_PRIMARY_FAILURES: [&str; 5] = [
    "C6_RAP_V4_LC1_EVIDENCE_COMPLETION_RECOMPUTE",
    "C6_RAP_V4_LC1_EVIDENCE_DEADLINE_OR_COOLDOWN",
    "C6_RAP_V4_LC1_METRIC_RECOMPUTE:/metrics/evidence_forward_displacement_m",
    TERMINAL_STANCE_FAILURE,
    "C6_RAP_V4_LC1_EVIDENCE_ADVANCE",
];

struct Arguments {
    report: PathBuf,
    output: PathBuf,
}

fn arguments() -> Result<Arguments, String> {
    let mut report = None;
    let mut output = None;
    let mut args = std::env::args().skip(1);
    while let Some(argument) = args.next() {
        match argument.as_str() {
            "--report" => {
                report = Some(PathBuf::from(
                    args.next()
                        .ok_or_else(|| "--report requires a value".to_owned())?,
                ));
            }
            "--output" => {
                output = Some(PathBuf::from(
                    args.next()
                        .ok_or_else(|| "--output requires a value".to_owned())?,
                ));
            }
            _ => return Err(format!("unknown argument: {argument}")),
        }
    }
    Ok(Arguments {
        report: report.ok_or_else(|| "--report is required".to_owned())?,
        output: output.ok_or_else(|| "--output is required".to_owned())?,
    })
}

fn raw_sha256(raw: &str) -> String {
    format!("{:x}", Sha256::digest(raw.as_bytes()))
}

fn retain(path: &PathBuf, serialized: &str) -> Result<(), String> {
    if path.exists() {
        return Err(format!(
            "refusing to overwrite LC1 post-hoc diagnostic: {}",
            path.display()
        ));
    }
    let parent = path
        .parent()
        .ok_or_else(|| "post-hoc diagnostic path has no parent".to_owned())?;
    std::fs::create_dir_all(parent).map_err(|error| error.to_string())?;
    let temporary = path.with_extension("json.tmp");
    if temporary.exists() {
        return Err(format!(
            "refusing stale LC1 post-hoc temporary file: {}",
            temporary.display()
        ));
    }
    std::fs::write(&temporary, format!("{serialized}\n")).map_err(|error| error.to_string())?;
    std::fs::rename(&temporary, path).map_err(|error| error.to_string())
}

fn string_array(value: &Value, field: &str) -> Result<Vec<String>, String> {
    value[field]
        .as_array()
        .ok_or_else(|| format!("C6_RAP_V4_LC1_POSTHOC_{field}_MISSING"))?
        .iter()
        .map(|entry| {
            entry
                .as_str()
                .map(str::to_owned)
                .ok_or_else(|| format!("C6_RAP_V4_LC1_POSTHOC_{field}_INVALID"))
        })
        .collect()
}

fn memory_order(value: &Value) -> Result<Vec<String>, String> {
    value
        .as_array()
        .ok_or_else(|| "C6_RAP_V4_LC1_POSTHOC_MEMORY_NOT_ARRAY".to_owned())?
        .iter()
        .map(|entry| {
            entry["limb_id"]
                .as_str()
                .map(str::to_owned)
                .ok_or_else(|| "C6_RAP_V4_LC1_POSTHOC_MEMORY_LIMB_ID_INVALID".to_owned())
        })
        .collect()
}

fn reorder_memory(value: &mut Value, expected_order: &[String]) -> Result<Vec<String>, String> {
    let observed_order = memory_order(value)?;
    let entries = value
        .as_array_mut()
        .ok_or_else(|| "C6_RAP_V4_LC1_POSTHOC_MEMORY_NOT_MUTABLE_ARRAY".to_owned())?;
    if entries.len() != expected_order.len() {
        return Err("C6_RAP_V4_LC1_POSTHOC_MEMORY_LENGTH_INVALID".to_owned());
    }
    let mut by_limb_id = BTreeMap::<String, Value>::new();
    for entry in std::mem::take(entries) {
        let limb_id = entry["limb_id"]
            .as_str()
            .ok_or_else(|| "C6_RAP_V4_LC1_POSTHOC_MEMORY_LIMB_ID_INVALID".to_owned())?
            .to_owned();
        if by_limb_id.insert(limb_id, entry).is_some() {
            return Err("C6_RAP_V4_LC1_POSTHOC_MEMORY_DUPLICATE_LIMB".to_owned());
        }
    }
    for limb_id in expected_order {
        entries.push(
            by_limb_id
                .remove(limb_id)
                .ok_or_else(|| "C6_RAP_V4_LC1_POSTHOC_MEMORY_LIMB_MISSING".to_owned())?,
        );
    }
    if !by_limb_id.is_empty() {
        return Err("C6_RAP_V4_LC1_POSTHOC_MEMORY_EXTRA_LIMB".to_owned());
    }
    Ok(observed_order)
}

fn memory_reached_limits_by_identity(value: &Value) -> bool {
    value.as_array().is_some_and(|entries| {
        !entries.is_empty()
            && entries.iter().all(|entry| {
                entry["evidence_gait_step_limit"]
                    .as_u64()
                    .zip(entry["gait_step"].as_u64())
                    .is_some_and(|(limit, step)| step >= limit)
            })
    })
}

fn position_x(value: &Value) -> Option<f64> {
    value
        .pointer("/torso_pose_world/position_m/x")
        .and_then(Value::as_f64)
}

fn evaluate(retained_report_raw: &str) -> Result<Value, String> {
    if raw_sha256(retained_report_raw) != RETAINED_REPORT_RAW_SHA256 {
        return Err("C6_RAP_V4_LC1_POSTHOC_REPORT_HASH_MISMATCH".to_owned());
    }
    let mut report: Value = serde_json::from_str(retained_report_raw)
        .map_err(|error| format!("C6_RAP_V4_LC1_POSTHOC_REPORT_PARSE:{error}"))?;
    if report["campaign_id"] != CAMPAIGN_ID
        || report["gate_id"] != GATE_ID
        || report["source_commit"] != PHYSICAL_SOURCE_COMMIT
        || report["ok"] != false
        || report["world_attempt_count"] != 1
        || report["world_build_count"] != 1
        || report["trace_step_count"] != TOTAL_STEPS
    {
        return Err("C6_RAP_V4_LC1_POSTHOC_PRIMARY_IDENTITY_INVALID".to_owned());
    }
    let original_failures = string_array(&report, "gate_failures")?;
    if original_failures != ORIGINAL_PRIMARY_FAILURES {
        return Err("C6_RAP_V4_LC1_POSTHOC_PRIMARY_FAILURES_CHANGED".to_owned());
    }
    let expected_limb_order = string_array(&report, "ordered_limb_ids")?;
    let trace = report["ordered_trace"]
        .as_array_mut()
        .ok_or_else(|| "C6_RAP_V4_LC1_POSTHOC_TRACE_MISSING".to_owned())?;
    if trace.len() != TOTAL_STEPS as usize {
        return Err("C6_RAP_V4_LC1_POSTHOC_TRACE_LENGTH_INVALID".to_owned());
    }
    let mut observed_scheduler_order = None::<Vec<String>>;
    for entry in trace.iter_mut() {
        for field in [
            "ordered_limb_controller_memory_before",
            "ordered_limb_controller_memory_after",
        ] {
            let observed = reorder_memory(&mut entry[field], &expected_limb_order)?;
            match &observed_scheduler_order {
                Some(expected) if expected != &observed => {
                    return Err("C6_RAP_V4_LC1_POSTHOC_MEMORY_ORDER_NOT_STABLE".to_owned());
                }
                None => observed_scheduler_order = Some(observed),
                _ => {}
            }
        }
    }
    let observed_scheduler_order = observed_scheduler_order
        .ok_or_else(|| "C6_RAP_V4_LC1_POSTHOC_MEMORY_ORDER_MISSING".to_owned())?;
    if observed_scheduler_order == expected_limb_order {
        return Err("C6_RAP_V4_LC1_POSTHOC_NO_ORDERING_DEFECT_WITNESS".to_owned());
    }

    let first_evidence_completion = trace.iter().find_map(|entry| {
        let semantic_step = entry["semantic_step"].as_u64()?;
        (semantic_step >= CLOCKED_STEPS
            && memory_reached_limits_by_identity(&entry["ordered_limb_controller_memory_after"]))
        .then_some(semantic_step)
    });
    let completion_step = first_evidence_completion
        .ok_or_else(|| "C6_RAP_V4_LC1_POSTHOC_EVIDENCE_NEVER_COMPLETED".to_owned())?;
    let evidence_start_x = trace
        .get(CLOCKED_STEPS as usize)
        .and_then(|entry| position_x(&entry["pre_step_snapshot"]))
        .ok_or_else(|| "C6_RAP_V4_LC1_POSTHOC_EVIDENCE_START_MISSING".to_owned())?;
    let evidence_end_x = trace
        .get(completion_step as usize)
        .and_then(|entry| position_x(&entry["post_step_snapshot"]))
        .ok_or_else(|| "C6_RAP_V4_LC1_POSTHOC_EVIDENCE_END_MISSING".to_owned())?;
    let evidence_advance = evidence_end_x - evidence_start_x;
    let terminal_contacts = trace
        .last()
        .ok_or_else(|| "C6_RAP_V4_LC1_POSTHOC_TERMINAL_TRACE_MISSING".to_owned())?
        ["post_step_snapshot"]["ordered_declared_contacts"]
        .clone();
    let evidence_completion_contacts =
        trace[completion_step as usize]["post_step_snapshot"]["ordered_declared_contacts"].clone();
    let evidence_completion_limb_memory =
        trace[completion_step as usize]["ordered_limb_controller_memory_after"].clone();
    let final_limb_memory =
        trace.last().expect("validated nonempty trace")["ordered_limb_controller_memory_after"]
            .clone();
    let final_contact_site_positions = trace
        .last()
        .expect("validated nonempty trace")["post_step_snapshot"]
        ["ordered_contact_site_positions_m"]
        .clone();
    let missing_terminal_contacts = terminal_contacts
        .as_object()
        .ok_or_else(|| "C6_RAP_V4_LC1_POSTHOC_TERMINAL_CONTACTS_INVALID".to_owned())?
        .iter()
        .filter_map(|(contact_id, contact)| (contact != true).then_some(contact_id.clone()))
        .collect::<Vec<_>>();
    let last_contact_semantic_step_by_id = terminal_contacts
        .as_object()
        .expect("validated terminal contact object")
        .keys()
        .map(|contact_id| {
            let last_step = trace.iter().rev().find_map(|entry| {
                (entry["post_step_snapshot"]["ordered_declared_contacts"][contact_id] == true)
                    .then(|| entry["semantic_step"].as_u64())
                    .flatten()
            });
            (contact_id.clone(), last_step)
        })
        .collect::<BTreeMap<_, _>>();
    let front_left_commands = |entry: &Value| {
        entry["ordered_portable_base_commands"]
            .as_array()
            .into_iter()
            .flatten()
            .filter(|command| {
                command["actuator_id"]
                    .as_str()
                    .is_some_and(|id| id.starts_with("front_left_"))
            })
            .cloned()
            .collect::<Vec<_>>()
    };
    let evidence_completion_front_left_base_commands =
        front_left_commands(&trace[completion_step as usize]);
    let final_front_left_base_commands =
        front_left_commands(trace.last().expect("validated nonempty trace"));

    let corrected_failures = evaluate_bw19v_velocity_only_long_horizon_lc1_report(&report);
    if corrected_failures != [TERMINAL_STANCE_FAILURE] {
        return Err(format!(
            "C6_RAP_V4_LC1_POSTHOC_UNEXPECTED_CORRECTED_FAILURES:{}",
            corrected_failures.join("|")
        ));
    }
    if report["schedule"]["evidence_completion_semantic_step"] != completion_step
        || report["metrics"]["evidence_forward_displacement_m"]
            .as_f64()
            .is_none_or(|declared| (declared - evidence_advance).abs() > 1.0e-6)
        || completion_step + REQUIRED_POST_EVIDENCE_STEPS >= TOTAL_STEPS
    {
        return Err("C6_RAP_V4_LC1_POSTHOC_DECLARED_EVIDENCE_MISMATCH".to_owned());
    }

    Ok(json!({
        "schema_version":
            "sporespore_rapier_c6_bw19v_velocity_only_lc1_posthoc_diagnostic_v2",
        "ok": true,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "physical_source_commit": PHYSICAL_SOURCE_COMMIT,
        "retained_primary_report_raw_sha256": format!("sha256:{RETAINED_REPORT_RAW_SHA256}"),
        "retained_primary_report_ok": false,
        "retained_primary_report_remains_invalid": true,
        "original_primary_failure_codes": original_failures,
        "diagnosed_evaluator_defect": {
            "incorrect_reconstruction":
                "zip scheduler-ordered limb memory with morphology-ordered limb IDs by array position",
            "correct_reconstruction":
                "match or reorder every limb-memory entry by its explicit limb_id before comparison",
            "morphology_limb_order": expected_limb_order,
            "observed_scheduler_memory_order": observed_scheduler_order,
            "synthetic_used_morphology_order_and_lacked_permutation_witness": true,
            "physical_trace_memory_order_is_stable_and_complete": true,
        },
        "corrected_counterfactual_full_gate_passed": false,
        "corrected_counterfactual_failure_codes": corrected_failures,
        "corrected_counterfactual_integrity_reconstructible": true,
        "corrected_counterfactual_only_failure_is_terminal_four_contact_stance": true,
        "posthoc_observations": {
            "trace_step_count": TOTAL_STEPS,
            "world_build_count": 1,
            "evidence_completion_semantic_step": completion_step,
            "required_post_evidence_steps_completed": true,
            "evidence_forward_displacement_m": evidence_advance,
            "final_forward_displacement_m": report["metrics"]["final_forward_displacement_m"],
            "final_lateral_displacement_m": report["metrics"]["final_lateral_displacement_m"],
            "final_yaw_drift_rad": report["metrics"]["final_yaw_drift_rad"],
            "maximum_tilt_rad": report["metrics"]["maximum_tilt_rad"],
            "minimum_torso_height_m": report["metrics"]["minimum_torso_height_m"],
            "maximum_anchor_error_m": report["metrics"]["maximum_anchor_error_m"],
            "maximum_hinge_axis_error_rad": report["metrics"]["maximum_hinge_axis_error_rad"],
            "torso_ground_contact_step_count": report["torso_ground_contact_step_count"],
            "limb_evidence": report["limb_evidence"],
            "evidence_completion_declared_contacts": evidence_completion_contacts,
            "evidence_completion_limb_memory": evidence_completion_limb_memory,
            "evidence_completion_front_left_base_commands":
                evidence_completion_front_left_base_commands,
            "final_limb_memory": final_limb_memory,
            "terminal_declared_contacts": terminal_contacts,
            "missing_terminal_contact_ids": missing_terminal_contacts,
            "last_contact_semantic_step_by_contact_id": last_contact_semantic_step_by_id,
            "final_contact_site_positions_m": final_contact_site_positions,
            "final_front_left_base_commands": final_front_left_base_commands,
        },
        "scientific_disposition":
            "invalid_primary_report_with_posthoc_single_remaining_terminal_stance_failure",
        "claims": {
            "posthoc_trace_diagnostic": true,
            "primary_lc1_integrity_restored": false,
            "valid_primary_lc1_result": false,
            "finite_walking_contract_passed": false,
            "exact_s169_rapier_v4_long_horizon_technical_commissioning": false,
            "rapier_selected_policy_physical_c6": false,
            "independent_validation": false,
            "population_inference": false,
            "cross_engine_equivalence": false,
            "arbitrary_quadruped_coverage": false,
            "friction_or_material_robustness": false,
            "release_authorized": false,
            "physical_acceptance_authority": false,
            "completed_engine_neutral_sdk": false,
        }
    }))
}

fn run() -> Result<(), String> {
    let arguments = arguments()?;
    let retained_report_raw =
        std::fs::read_to_string(&arguments.report).map_err(|error| error.to_string())?;
    let diagnostic = evaluate(&retained_report_raw)?;
    let serialized =
        serde_json::to_string_pretty(&diagnostic).map_err(|error| error.to_string())?;
    retain(&arguments.output, &serialized)?;
    println!("{serialized}");
    Ok(())
}

fn main() {
    if let Err(error) = run() {
        eprintln!("{error}");
        std::process::exit(1);
    }
}
