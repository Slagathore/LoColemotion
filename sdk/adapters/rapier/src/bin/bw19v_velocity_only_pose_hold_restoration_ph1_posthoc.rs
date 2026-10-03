#![recursion_limit = "256"]

use std::collections::BTreeMap;
use std::path::PathBuf;

use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use sporespore_rapier_adapter::evaluate_bw19v_velocity_only_pose_hold_restoration_ph1_report;

const CAMPAIGN_ID: &str = "C6-RAPIER-BW19V-VELOCITY-ONLY-POSE-HOLD-RESTORATION-PH1";
const GATE_ID: &str = "C6-RAP-BW19V-V4-PH1";
const PHYSICAL_SOURCE_COMMIT: &str = "91c528e0d0eb494a7ff1d9dc9250ef1af6963249";
const RETAINED_REPORT_RAW_SHA256: &str =
    "8096b48aabdd63fbbfbabcd601a6d0246c5ad6b3bf3670b4573e013c1f770222";
const TOTAL_STEPS: u64 = 3_172;
const COMMANDS_PER_LAYER: u64 = 25_376;
const TERMINAL_ACTIVATION_STEP: u64 = 2_092;
const REQUIRED_CONSECUTIVE_FOUR_CONTACT_STEPS: u64 = 360;
const CONTACT_IDS: [&str; 4] = [
    "front_left_foot",
    "front_right_foot",
    "rear_left_foot",
    "rear_right_foot",
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
            "refusing to overwrite PH1 post-hoc diagnostic: {}",
            path.display()
        ));
    }
    let parent = path
        .parent()
        .ok_or_else(|| "PH1 post-hoc diagnostic path has no parent".to_owned())?;
    std::fs::create_dir_all(parent).map_err(|error| error.to_string())?;
    let temporary = path.with_extension("json.tmp");
    if temporary.exists() {
        return Err(format!(
            "refusing stale PH1 post-hoc temporary file: {}",
            temporary.display()
        ));
    }
    std::fs::write(&temporary, format!("{serialized}\n")).map_err(|error| error.to_string())?;
    std::fs::rename(&temporary, path).map_err(|error| error.to_string())
}

fn required_u64(value: &Value, path: &str) -> Result<u64, String> {
    value
        .as_u64()
        .ok_or_else(|| format!("C6_RAP_V4_PH1_POSTHOC_{path}_INVALID"))
}

fn required_f64(value: &Value, path: &str) -> Result<f64, String> {
    value
        .as_f64()
        .ok_or_else(|| format!("C6_RAP_V4_PH1_POSTHOC_{path}_INVALID"))
}

fn all_four_contacts(entry: &Value) -> bool {
    CONTACT_IDS.iter().all(|contact_id| {
        entry["post_step_snapshot"]["ordered_declared_contacts"][contact_id] == true
    })
}

fn evaluate(retained_report_raw: &str) -> Result<Value, String> {
    let observed_report_hash = raw_sha256(retained_report_raw);
    if observed_report_hash != RETAINED_REPORT_RAW_SHA256 {
        return Err("C6_RAP_V4_PH1_POSTHOC_REPORT_HASH_MISMATCH".to_owned());
    }
    let report: Value = serde_json::from_str(retained_report_raw)
        .map_err(|error| format!("C6_RAP_V4_PH1_POSTHOC_REPORT_PARSE:{error}"))?;
    if report["campaign_id"] != CAMPAIGN_ID
        || report["gate_id"] != GATE_ID
        || report["source_commit"] != PHYSICAL_SOURCE_COMMIT
        || report["ok"] != true
        || report["world_attempt_count"] != 1
        || report["world_build_count"] != 1
        || report["world_reset_count"] != 0
        || report["trace_step_count"] != TOTAL_STEPS
        || report["gate_failures"] != json!([])
    {
        return Err("C6_RAP_V4_PH1_POSTHOC_PRIMARY_IDENTITY_INVALID".to_owned());
    }
    let evaluator_failures = evaluate_bw19v_velocity_only_pose_hold_restoration_ph1_report(&report);
    if !evaluator_failures.is_empty() {
        return Err(format!(
            "C6_RAP_V4_PH1_POSTHOC_UNEXPECTED_EVALUATOR_FAILURES:{}",
            evaluator_failures.join("|")
        ));
    }

    let trace = report["ordered_trace"]
        .as_array()
        .ok_or_else(|| "C6_RAP_V4_PH1_POSTHOC_TRACE_MISSING".to_owned())?;
    if trace.len() != TOTAL_STEPS as usize {
        return Err("C6_RAP_V4_PH1_POSTHOC_TRACE_LENGTH_INVALID".to_owned());
    }

    let mut event_summaries = BTreeMap::<String, (u64, u64, u64)>::new();
    let mut phase_summaries = BTreeMap::<String, (u64, u64, u64)>::new();
    let mut current_consecutive_four_contact_steps = 0_u64;
    let mut maximum_consecutive_four_contact_steps = 0_u64;
    let mut first_post_evidence_four_contact_step = None::<u64>;
    let mut consecutive_hold_completion_step = None::<u64>;
    for (index, entry) in trace.iter().enumerate() {
        let semantic_step = required_u64(&entry["semantic_step"], "SEMANTIC_STEP")?;
        if semantic_step != index as u64 {
            return Err("C6_RAP_V4_PH1_POSTHOC_SEMANTIC_STEP_SEQUENCE_INVALID".to_owned());
        }
        let phase = entry["campaign_phase"]
            .as_str()
            .ok_or_else(|| "C6_RAP_V4_PH1_POSTHOC_CAMPAIGN_PHASE_INVALID".to_owned())?;
        phase_summaries
            .entry(phase.to_owned())
            .and_modify(|summary| {
                summary.0 += 1;
                summary.2 = semantic_step;
            })
            .or_insert((1, semantic_step, semantic_step));
        for event in entry["declared_diagnostic_events"]
            .as_array()
            .ok_or_else(|| "C6_RAP_V4_PH1_POSTHOC_EVENTS_INVALID".to_owned())?
        {
            let event = event
                .as_str()
                .ok_or_else(|| "C6_RAP_V4_PH1_POSTHOC_EVENT_ID_INVALID".to_owned())?;
            event_summaries
                .entry(event.to_owned())
                .and_modify(|summary| {
                    summary.0 += 1;
                    summary.2 = semantic_step;
                })
                .or_insert((1, semantic_step, semantic_step));
        }
        if semantic_step >= TERMINAL_ACTIVATION_STEP {
            if all_four_contacts(entry) {
                first_post_evidence_four_contact_step.get_or_insert(semantic_step);
                current_consecutive_four_contact_steps += 1;
                maximum_consecutive_four_contact_steps = maximum_consecutive_four_contact_steps
                    .max(current_consecutive_four_contact_steps);
                if current_consecutive_four_contact_steps == REQUIRED_CONSECUTIVE_FOUR_CONTACT_STEPS
                {
                    consecutive_hold_completion_step.get_or_insert(semantic_step);
                }
            } else {
                current_consecutive_four_contact_steps = 0;
            }
        }
    }
    if !event_summaries.is_empty() {
        return Err("C6_RAP_V4_PH1_POSTHOC_UNEXPECTED_DIAGNOSTIC_EVENT".to_owned());
    }

    let first_four_contact_step = first_post_evidence_four_contact_step
        .ok_or_else(|| "C6_RAP_V4_PH1_POSTHOC_FOUR_CONTACT_NEVER_ACQUIRED".to_owned())?;
    let hold_completion_step = consecutive_hold_completion_step
        .ok_or_else(|| "C6_RAP_V4_PH1_POSTHOC_CONSECUTIVE_HOLD_NEVER_COMPLETED".to_owned())?;
    let declared_restoration = &report["schedule"]["terminal_restoration_phase"];
    if report["schedule"]["evidence_completion_semantic_step"] != 2_091
        || declared_restoration["activation_semantic_step"] != TERMINAL_ACTIVATION_STEP
        || declared_restoration["first_four_contact_acquisition_semantic_step"]
            != first_four_contact_step
        || declared_restoration["consecutive_four_contact_completion_semantic_step"]
            != hold_completion_step
        || declared_restoration["maximum_consecutive_four_contact_steps"]
            != maximum_consecutive_four_contact_steps
        || declared_restoration["required_consecutive_hold_completed"] != true
        || report["terminal_four_contact_stance"] != true
    {
        return Err("C6_RAP_V4_PH1_POSTHOC_RESTORATION_RECONSTRUCTION_INVALID".to_owned());
    }

    for counter in [
        "actuator_application_mismatch_count",
        "composition_error_count",
        "controller_error_count",
        "global_scale_mismatch_count",
        "motor_model_or_field_readback_mismatch_count",
        "native_position_target_application_count",
        "nonfinite_observation_count",
        "safe_no_actuation_count",
        "selected_control_mapping_mismatch_count",
        "small_step_impulse_limit_violation_count",
        "torso_ground_contact_step_count",
    ] {
        if report[counter] != 0 {
            return Err(format!(
                "C6_RAP_V4_PH1_POSTHOC_INTEGRITY_OR_SAFETY_COUNTER_NONZERO:{counter}"
            ));
        }
    }
    for counter in [
        "base_command_count",
        "bounded_residual_command_count",
        "canonical_command_count",
        "host_command_count",
        "motor_observation_count",
    ] {
        if report[counter] != COMMANDS_PER_LAYER {
            return Err(format!(
                "C6_RAP_V4_PH1_POSTHOC_COMMAND_COUNTER_INVALID:{counter}"
            ));
        }
    }

    let claims = report["claim_boundary"]
        .as_object()
        .ok_or_else(|| "C6_RAP_V4_PH1_POSTHOC_CLAIM_BOUNDARY_INVALID".to_owned())?;
    let true_claims = claims
        .iter()
        .filter_map(|(name, value)| (value == true).then_some(name.as_str()))
        .collect::<Vec<_>>();
    if claims.len() != 15
        || true_claims
            != [
                "exact_s169_rapier_v4_pose_hold_restoration_technical_commissioning",
                "finite_single_body_walking_contract",
            ]
    {
        return Err("C6_RAP_V4_PH1_POSTHOC_CLAIM_BOUNDARY_CHANGED".to_owned());
    }

    let phase_summary_json = phase_summaries
        .into_iter()
        .map(|(phase, (count, first_step, last_step))| {
            json!({
                "phase": phase,
                "count": count,
                "first_step": first_step,
                "last_step": last_step,
            })
        })
        .collect::<Vec<_>>();
    let metrics = &report["metrics"];
    let walking = json!({
        "evidence_forward_displacement_m":
            required_f64(&metrics["evidence_forward_displacement_m"], "EVIDENCE_FORWARD")?,
        "final_forward_displacement_m":
            required_f64(&metrics["final_forward_displacement_m"], "FINAL_FORWARD")?,
        "final_lateral_displacement_m":
            required_f64(&metrics["final_lateral_displacement_m"], "FINAL_LATERAL")?,
        "final_yaw_drift_rad":
            required_f64(&metrics["final_yaw_drift_rad"], "FINAL_YAW")?,
        "maximum_tilt_rad": required_f64(&metrics["maximum_tilt_rad"], "MAX_TILT")?,
        "minimum_torso_height_m":
            required_f64(&metrics["minimum_torso_height_m"], "MIN_TORSO_HEIGHT")?,
        "torso_ground_contact_step_count": report["torso_ground_contact_step_count"],
        "diagnostic_event_count": 0,
        "walking_safety_contract_passed": true,
    });

    Ok(json!({
        "schema_version":
            "sporespore_rapier_c6_bw19v_velocity_only_ph1_posthoc_diagnostic_v1",
        "ok": true,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "physical_source_commit": PHYSICAL_SOURCE_COMMIT,
        "retained_report_raw_sha256": RETAINED_REPORT_RAW_SHA256,
        "retained_primary_report_ok": true,
        "retained_primary_report_is_complete_valid_positive": true,
        "original_primary_failure_codes": [],
        "frozen_evaluator_recomputed_failure_codes": evaluator_failures,
        "integrity_reconstruction": {
            "complete_trace": true,
            "trace_step_count": TOTAL_STEPS,
            "command_count_per_layer": COMMANDS_PER_LAYER,
            "all_integrity_counters_zero": true,
            "phase_summaries": phase_summary_json,
        },
        "pose_hold_restoration_result": {
            "restoration_policy_id": declared_restoration["restoration_policy_id"],
            "activation_semantic_step": TERMINAL_ACTIVATION_STEP,
            "first_four_contact_acquisition_semantic_step": first_four_contact_step,
            "consecutive_four_contact_completion_semantic_step": hold_completion_step,
            "required_consecutive_all_four_contact_steps":
                REQUIRED_CONSECUTIVE_FOUR_CONTACT_STEPS,
            "maximum_consecutive_four_contact_steps":
                maximum_consecutive_four_contact_steps,
            "required_consecutive_hold_completed": true,
            "terminal_four_contact_stance": true,
            "pose_hold_restoration_gate_passed": true,
        },
        "walking_result": walking,
        "bounded_interpretation": {
            "observation": "The exact PH1 pose/heading-hold successor preserved all four declared contacts throughout its terminal phase and passed the unchanged finite walking and safety conjunction on the deterministic s169 Rapier v4 body.",
            "inference": "PH1 supplies exact finite single-body Rapier technical commissioning and walking-contract evidence. It does not establish release-selected C6, independent validation, arbitrary morphology, robustness, or cross-engine equivalence.",
            "population_or_release_inference_allowed": false,
        },
        "claims": {
            "complete_posthoc_trace_diagnostic": true,
            "valid_primary_ph1_positive_result": true,
            "exact_s169_rapier_v4_pose_hold_restoration_technical_commissioning": true,
            "finite_single_body_walking_contract_passed": true,
            "rapier_release_selected_policy_physical_c6": false,
            "independent_validation": false,
            "population_inference": false,
            "cross_engine_selected_policy_equivalence": false,
            "arbitrary_quadruped_coverage": false,
            "friction_or_material_robustness": false,
            "release_authorized": false,
            "physical_acceptance_authority": false,
            "completed_engine_neutral_sdk": false,
        },
    }))
}

fn run() -> Result<(), String> {
    let arguments = arguments()?;
    let raw = std::fs::read_to_string(&arguments.report).map_err(|error| error.to_string())?;
    let diagnostic = evaluate(&raw)?;
    let serialized =
        serde_json::to_string_pretty(&diagnostic).map_err(|error| error.to_string())?;
    retain(&arguments.output, &serialized)?;
    println!(
        "C6_RAP_V4_PH1_POSTHOC_PASS report_ok=True valid_positive=True \
         restoration=True walking_contract=True worlds=0 physical_authority=False"
    );
    Ok(())
}

fn main() {
    if let Err(error) = run() {
        eprintln!("{error}");
        std::process::exit(1);
    }
}
