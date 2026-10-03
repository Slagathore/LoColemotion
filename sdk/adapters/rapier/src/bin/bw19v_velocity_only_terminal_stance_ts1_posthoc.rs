#![recursion_limit = "256"]

use std::collections::{BTreeMap, BTreeSet};
use std::path::PathBuf;

use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use sporespore_rapier_adapter::evaluate_bw19v_velocity_only_terminal_stance_ts1_report;

const CAMPAIGN_ID: &str = "C6-RAPIER-BW19V-VELOCITY-ONLY-TERMINAL-STANCE-COMMISSIONING-TS1";
const GATE_ID: &str = "C6-RAP-BW19V-V4-TS1";
const PHYSICAL_SOURCE_COMMIT: &str = "9cb55a581efe0b3743bcb2bee82eb3be6802efd0";
const RETAINED_REPORT_RAW_SHA256: &str =
    "4db84024a07b40d8edb3bfcfefbaa98e8c0d58996d7f4f985ba34a50309d968c";
const CLOCKED_STEPS: u64 = 472;
const EVIDENCE_LIMIT_GAIT_STEP: u64 = 1_912;
const TERMINAL_TARGET_GAIT_STEP: u64 = 1_970;
const REQUIRED_POST_TERMINAL_STEPS: u64 = 360;
const TOTAL_STEPS: u64 = 3_172;
const TERMINAL_STANCE_FAILURE: &str = "C6_RAP_V4_TS1_TERMINAL_STANCE";
const CONTACT_IDS: [&str; 4] = [
    "front_left_foot",
    "front_right_foot",
    "rear_left_foot",
    "rear_right_foot",
];
const SCHEDULER_ORDERED_LIMB_IDS: [&str; 4] =
    ["rear_left", "front_left", "rear_right", "front_right"];

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
            "refusing to overwrite TS1 post-hoc diagnostic: {}",
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
            "refusing stale TS1 post-hoc temporary file: {}",
            temporary.display()
        ));
    }
    std::fs::write(&temporary, format!("{serialized}\n")).map_err(|error| error.to_string())?;
    std::fs::rename(&temporary, path).map_err(|error| error.to_string())
}

fn string_array(value: &Value, field: &str) -> Result<Vec<String>, String> {
    value[field]
        .as_array()
        .ok_or_else(|| format!("C6_RAP_V4_TS1_POSTHOC_{field}_MISSING"))?
        .iter()
        .map(|entry| {
            entry
                .as_str()
                .map(str::to_owned)
                .ok_or_else(|| format!("C6_RAP_V4_TS1_POSTHOC_{field}_INVALID"))
        })
        .collect()
}

fn memory_order_and_identity_set(value: &Value) -> Result<(Vec<String>, BTreeSet<String>), String> {
    let entries = value
        .as_array()
        .ok_or_else(|| "C6_RAP_V4_TS1_POSTHOC_MEMORY_NOT_ARRAY".to_owned())?;
    let mut order = Vec::with_capacity(entries.len());
    let mut identities = BTreeSet::new();
    for entry in entries {
        let limb_id = entry["limb_id"]
            .as_str()
            .ok_or_else(|| "C6_RAP_V4_TS1_POSTHOC_MEMORY_LIMB_ID_INVALID".to_owned())?
            .to_owned();
        if !identities.insert(limb_id.clone()) {
            return Err("C6_RAP_V4_TS1_POSTHOC_MEMORY_DUPLICATE_LIMB".to_owned());
        }
        order.push(limb_id);
    }
    Ok((order, identities))
}

fn memory_is_exact(value: &Value, gait_step: u64, limit: u64) -> bool {
    value.as_array().is_some_and(|entries| {
        entries.len() == SCHEDULER_ORDERED_LIMB_IDS.len()
            && entries.iter().all(|entry| {
                entry["gait_step"] == gait_step && entry["evidence_gait_step_limit"] == limit
            })
    })
}

fn all_four_contacts(entry: &Value) -> bool {
    CONTACT_IDS.iter().all(|contact_id| {
        entry["post_step_snapshot"]["ordered_declared_contacts"][contact_id] == true
    })
}

fn front_left_commands(entry: &Value, field: &str) -> Vec<Value> {
    entry[field]
        .as_array()
        .into_iter()
        .flatten()
        .filter(|command| {
            command["actuator_id"]
                .as_str()
                .is_some_and(|id| id.starts_with("front_left_"))
        })
        .cloned()
        .collect()
}

fn contact_site_y(entry: &Value, contact_id: &str) -> Result<f64, String> {
    entry["post_step_snapshot"]["ordered_contact_site_positions_m"][contact_id]["y"]
        .as_f64()
        .ok_or_else(|| format!("C6_RAP_V4_TS1_POSTHOC_CONTACT_SITE_Y_MISSING:{contact_id}"))
}

fn contact_snapshot(entry: &Value) -> Value {
    json!({
        "semantic_step": entry["semantic_step"],
        "campaign_phase": entry["campaign_phase"],
        "ordered_declared_contacts":
            entry["post_step_snapshot"]["ordered_declared_contacts"],
        "ordered_contact_site_positions_m":
            entry["post_step_snapshot"]["ordered_contact_site_positions_m"],
        "ordered_limb_controller_memory_after":
            entry["ordered_limb_controller_memory_after"],
        "front_left_portable_base_commands":
            front_left_commands(entry, "ordered_portable_base_commands"),
        "front_left_load_bearing_host_commands":
            front_left_commands(entry, "ordered_load_bearing_host_commands"),
        "front_left_motor_readbacks_and_impulses":
            front_left_commands(entry, "ordered_post_step_joint_motor_readbacks_and_impulses"),
    })
}

fn evaluate(retained_report_raw: &str) -> Result<Value, String> {
    if raw_sha256(retained_report_raw) != RETAINED_REPORT_RAW_SHA256 {
        return Err("C6_RAP_V4_TS1_POSTHOC_REPORT_HASH_MISMATCH".to_owned());
    }
    let report: Value = serde_json::from_str(retained_report_raw)
        .map_err(|error| format!("C6_RAP_V4_TS1_POSTHOC_REPORT_PARSE:{error}"))?;
    if report["campaign_id"] != CAMPAIGN_ID
        || report["gate_id"] != GATE_ID
        || report["source_commit"] != PHYSICAL_SOURCE_COMMIT
        || report["ok"] != false
        || report["world_attempt_count"] != 1
        || report["world_build_count"] != 1
        || report["world_reset_count"] != 0
        || report["trace_step_count"] != TOTAL_STEPS
    {
        return Err("C6_RAP_V4_TS1_POSTHOC_PRIMARY_IDENTITY_INVALID".to_owned());
    }
    let original_failures = string_array(&report, "gate_failures")?;
    if original_failures != [TERMINAL_STANCE_FAILURE] {
        return Err("C6_RAP_V4_TS1_POSTHOC_PRIMARY_FAILURES_CHANGED".to_owned());
    }
    let evaluator_failures = evaluate_bw19v_velocity_only_terminal_stance_ts1_report(&report);
    if evaluator_failures != [TERMINAL_STANCE_FAILURE] {
        return Err(format!(
            "C6_RAP_V4_TS1_POSTHOC_UNEXPECTED_EVALUATOR_FAILURES:{}",
            evaluator_failures.join("|")
        ));
    }

    let expected_limb_order = string_array(&report, "ordered_limb_ids")?;
    let expected_identity_set = expected_limb_order.iter().cloned().collect::<BTreeSet<_>>();
    let trace = report["ordered_trace"]
        .as_array()
        .ok_or_else(|| "C6_RAP_V4_TS1_POSTHOC_TRACE_MISSING".to_owned())?;
    if trace.len() != TOTAL_STEPS as usize {
        return Err("C6_RAP_V4_TS1_POSTHOC_TRACE_LENGTH_INVALID".to_owned());
    }
    let mut observed_scheduler_order = None::<Vec<String>>;
    for (index, entry) in trace.iter().enumerate() {
        if entry["semantic_step"] != index as u64 {
            return Err("C6_RAP_V4_TS1_POSTHOC_SEMANTIC_STEP_INVALID".to_owned());
        }
        for field in [
            "ordered_limb_controller_memory_before",
            "ordered_limb_controller_memory_after",
        ] {
            let (observed_order, identities) = memory_order_and_identity_set(&entry[field])?;
            if identities != expected_identity_set {
                return Err("C6_RAP_V4_TS1_POSTHOC_MEMORY_IDENTITY_SET_INVALID".to_owned());
            }
            match &observed_scheduler_order {
                Some(expected) if expected != &observed_order => {
                    return Err("C6_RAP_V4_TS1_POSTHOC_MEMORY_ORDER_NOT_STABLE".to_owned());
                }
                None => observed_scheduler_order = Some(observed_order),
                _ => {}
            }
        }
    }
    let observed_scheduler_order = observed_scheduler_order
        .ok_or_else(|| "C6_RAP_V4_TS1_POSTHOC_MEMORY_ORDER_MISSING".to_owned())?;
    if observed_scheduler_order != SCHEDULER_ORDERED_LIMB_IDS {
        return Err("C6_RAP_V4_TS1_POSTHOC_MEMORY_ORDER_INVALID".to_owned());
    }

    let evidence_completion_step = trace
        .iter()
        .find_map(|entry| {
            let semantic_step = entry["semantic_step"].as_u64()?;
            (semantic_step >= CLOCKED_STEPS
                && memory_is_exact(
                    &entry["ordered_limb_controller_memory_after"],
                    EVIDENCE_LIMIT_GAIT_STEP,
                    EVIDENCE_LIMIT_GAIT_STEP,
                ))
            .then_some(semantic_step)
        })
        .ok_or_else(|| "C6_RAP_V4_TS1_POSTHOC_EVIDENCE_NEVER_COMPLETED".to_owned())?;
    let terminal_activation_step = evidence_completion_step + 1;
    let terminal_completion_step = trace
        .iter()
        .skip(terminal_activation_step as usize)
        .find_map(|entry| {
            memory_is_exact(
                &entry["ordered_limb_controller_memory_after"],
                TERMINAL_TARGET_GAIT_STEP,
                TERMINAL_TARGET_GAIT_STEP,
            )
            .then(|| entry["semantic_step"].as_u64())
            .flatten()
        })
        .ok_or_else(|| "C6_RAP_V4_TS1_POSTHOC_TERMINAL_TARGET_NEVER_REACHED".to_owned())?;
    if report["schedule"]["evidence_completion_semantic_step"] != evidence_completion_step
        || report["schedule"]["terminal_phase"]["activation_semantic_step"]
            != terminal_activation_step
        || report["schedule"]["terminal_phase"]["completion_semantic_step"]
            != terminal_completion_step
        || terminal_completion_step - evidence_completion_step > 180
        || terminal_completion_step + REQUIRED_POST_TERMINAL_STEPS >= TOTAL_STEPS
    {
        return Err("C6_RAP_V4_TS1_POSTHOC_DECLARED_SCHEDULE_MISMATCH".to_owned());
    }

    let front_left_last_contact_step = trace
        .iter()
        .rev()
        .find_map(|entry| {
            (entry["post_step_snapshot"]["ordered_declared_contacts"]["front_left_foot"] == true)
                .then(|| entry["semantic_step"].as_u64())
                .flatten()
        })
        .ok_or_else(|| "C6_RAP_V4_TS1_POSTHOC_FRONT_LEFT_NEVER_CONTACTED".to_owned())?;
    let front_left_contact_loss_step = trace
        .windows(2)
        .find_map(|pair| {
            let before = &pair[0];
            let after = &pair[1];
            (after["semantic_step"].as_u64()? >= terminal_activation_step
                && before["post_step_snapshot"]["ordered_declared_contacts"]["front_left_foot"]
                    == true
                && after["post_step_snapshot"]["ordered_declared_contacts"]["front_left_foot"]
                    == false)
                .then(|| after["semantic_step"].as_u64())
                .flatten()
        })
        .ok_or_else(|| "C6_RAP_V4_TS1_POSTHOC_FRONT_LEFT_LOSS_MISSING".to_owned())?;
    let post_evidence_all_four_contact_steps = trace
        .iter()
        .skip(terminal_activation_step as usize)
        .filter(|entry| all_four_contacts(entry))
        .map(|entry| {
            entry["semantic_step"]
                .as_u64()
                .expect("validated semantic step")
        })
        .collect::<Vec<_>>();

    let (front_left_maximum_height_step, front_left_maximum_height_m) = trace
        .iter()
        .skip(terminal_activation_step as usize)
        .map(|entry| {
            Ok::<_, String>((
                entry["semantic_step"]
                    .as_u64()
                    .expect("validated semantic step"),
                contact_site_y(entry, "front_left_foot")?,
            ))
        })
        .collect::<Result<Vec<_>, _>>()?
        .into_iter()
        .max_by(|left, right| left.1.total_cmp(&right.1))
        .ok_or_else(|| "C6_RAP_V4_TS1_POSTHOC_FRONT_LEFT_HEIGHT_MISSING".to_owned())?;

    let final_entry = trace.last().expect("validated nonempty trace");
    let final_front_left_height_m = contact_site_y(final_entry, "front_left_foot")?;
    let other_final_contact_heights_m = CONTACT_IDS[1..]
        .iter()
        .map(|contact_id| contact_site_y(final_entry, contact_id))
        .collect::<Result<Vec<_>, _>>()?;
    let other_final_mean_height_m = other_final_contact_heights_m.iter().sum::<f64>()
        / other_final_contact_heights_m.len() as f64;
    let final_front_left_height_above_other_mean_m =
        final_front_left_height_m - other_final_mean_height_m;

    let key_steps = [
        evidence_completion_step,
        terminal_activation_step,
        front_left_last_contact_step,
        front_left_contact_loss_step,
        front_left_maximum_height_step,
        terminal_completion_step,
        TOTAL_STEPS - 1,
    ]
    .into_iter()
    .collect::<BTreeSet<_>>()
    .into_iter()
    .map(|step| contact_snapshot(&trace[step as usize]))
    .collect::<Vec<_>>();

    let terminal_contacts = final_entry["post_step_snapshot"]["ordered_declared_contacts"].clone();
    let missing_terminal_contacts = terminal_contacts
        .as_object()
        .ok_or_else(|| "C6_RAP_V4_TS1_POSTHOC_TERMINAL_CONTACTS_INVALID".to_owned())?
        .iter()
        .filter_map(|(contact_id, contact)| (contact != true).then_some(contact_id.clone()))
        .collect::<Vec<_>>();
    let last_contact_semantic_step_by_id = CONTACT_IDS
        .iter()
        .map(|contact_id| {
            let last = trace.iter().rev().find_map(|entry| {
                (entry["post_step_snapshot"]["ordered_declared_contacts"][contact_id] == true)
                    .then(|| entry["semantic_step"].as_u64())
                    .flatten()
            });
            ((*contact_id).to_owned(), last)
        })
        .collect::<BTreeMap<_, _>>();

    if evidence_completion_step != 2_091
        || terminal_activation_step != 2_092
        || front_left_last_contact_step != 2_093
        || front_left_contact_loss_step != 2_094
        || terminal_completion_step != 2_151
        || post_evidence_all_four_contact_steps != [2_092, 2_093]
        || missing_terminal_contacts != ["front_left_foot"]
        || report["terminal_four_contact_stance"] != false
        || report["controller_error_count"] != 0
        || report["safe_no_actuation_count"] != 0
        || report["composition_error_count"] != 0
        || report["nonfinite_observation_count"] != 0
        || report["actuator_application_mismatch_count"] != 0
        || report["motor_model_or_field_readback_mismatch_count"] != 0
        || report["small_step_impulse_limit_violation_count"] != 0
        || report["global_scale_mismatch_count"] != 0
        || report["native_position_target_application_count"] != 0
        || report["selected_control_mapping_mismatch_count"] != 0
    {
        return Err("C6_RAP_V4_TS1_POSTHOC_OBSERVATION_MISMATCH".to_owned());
    }

    Ok(json!({
        "schema_version":
            "sporespore_rapier_c6_bw19v_velocity_only_ts1_posthoc_diagnostic_v1",
        "ok": true,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "physical_source_commit": PHYSICAL_SOURCE_COMMIT,
        "retained_primary_report_raw_sha256": format!("sha256:{RETAINED_REPORT_RAW_SHA256}"),
        "retained_primary_report_ok": false,
        "retained_primary_report_is_complete_valid_negative": true,
        "original_primary_failure_codes": original_failures,
        "frozen_evaluator_recomputed_failure_codes": evaluator_failures,
        "frozen_evaluator_recomputed_only_failure_is_terminal_four_contact_stance": true,
        "explicit_limb_identity_reconstruction": {
            "morphology_ordered_limb_ids": expected_limb_order,
            "observed_scheduler_memory_order": observed_scheduler_order,
            "identity_set_complete_unique_and_stable_at_every_trace_layer": true,
        },
        "posthoc_observations": {
            "world_attempt_count": 1,
            "world_build_count": 1,
            "world_reset_count": 0,
            "trace_step_count": TOTAL_STEPS,
            "evidence_completion_semantic_step": evidence_completion_step,
            "terminal_activation_semantic_step": terminal_activation_step,
            "terminal_completion_semantic_step": terminal_completion_step,
            "terminal_acquisition_semantic_steps":
                terminal_completion_step - evidence_completion_step,
            "required_post_terminal_steps": REQUIRED_POST_TERMINAL_STEPS,
            "observed_post_terminal_steps": TOTAL_STEPS - 1 - terminal_completion_step,
            "post_evidence_all_four_contact_semantic_steps":
                post_evidence_all_four_contact_steps,
            "front_left_last_contact_semantic_step": front_left_last_contact_step,
            "front_left_contact_loss_semantic_step": front_left_contact_loss_step,
            "front_left_final_airborne_dwell_steps":
                TOTAL_STEPS - 1 - front_left_last_contact_step,
            "front_left_maximum_post_evidence_contact_site_height": {
                "semantic_step": front_left_maximum_height_step,
                "height_m": front_left_maximum_height_m,
            },
            "terminal_declared_contacts": terminal_contacts,
            "missing_terminal_contact_ids": missing_terminal_contacts,
            "last_contact_semantic_step_by_contact_id": last_contact_semantic_step_by_id,
            "final_contact_site_positions_m":
                final_entry["post_step_snapshot"]["ordered_contact_site_positions_m"],
            "final_front_left_contact_site_height_m": final_front_left_height_m,
            "other_final_contact_site_heights_m": other_final_contact_heights_m,
            "other_final_contact_site_mean_height_m": other_final_mean_height_m,
            "final_front_left_height_above_other_contact_site_mean_m":
                final_front_left_height_above_other_mean_m,
            "key_trace_steps": key_steps,
            "metrics": report["metrics"],
            "limb_evidence": report["limb_evidence"],
            "integrity_counters": {
                "controller_error_count": report["controller_error_count"],
                "safe_no_actuation_count": report["safe_no_actuation_count"],
                "composition_error_count": report["composition_error_count"],
                "nonfinite_observation_count": report["nonfinite_observation_count"],
                "actuator_application_mismatch_count":
                    report["actuator_application_mismatch_count"],
                "motor_model_or_field_readback_mismatch_count":
                    report["motor_model_or_field_readback_mismatch_count"],
                "small_step_impulse_limit_violation_count":
                    report["small_step_impulse_limit_violation_count"],
                "global_scale_mismatch_count": report["global_scale_mismatch_count"],
                "native_position_target_application_count":
                    report["native_position_target_application_count"],
                "selected_control_mapping_mismatch_count":
                    report["selected_control_mapping_mismatch_count"],
            },
        },
        "development_mechanism_interpretation": {
            "observation": "The prospectively declared target was acquired on time and all four limb memories reached gait step 1970. All four feet contacted only at semantic steps 2092 and 2093. Front-left contact ended at step 2094 while the local reference advanced out of its raised-knee swing state; the knee target reached zero by target completion at step 2151, but the foot remained airborne for the rest of the fixed horizon and ended about 0.03 m above the other three contact sites.",
            "inference": "The analytic local-phase predicate local_phase >= 72 classified front-left phase 80 as stance, but that predicate did not establish that the selected portable reference was physically contact-restoring through the Rapier ForceBased velocity-only path. This is a source-and-trace-grounded successor-design hypothesis, not acceptance authority and not permission to waive TS1's terminal-contact gate.",
            "trace_limitation": "The retained trace records commanded position references, mapped velocity commands, motor field readbacks, contacts, and contact-site positions, but not direct per-step joint angles. It therefore proves persistent off-ground terminal geometry but does not uniquely attribute the gap to one joint, servo tracking error, kinematic reference geometry, or contact detection.",
            "terminal_stance_threshold_retroactively_waived": false,
            "ts1_reclassified_as_passing": false,
        },
        "scientific_disposition": "complete_valid_negative_terminal_four_contact_failure",
        "claims": {
            "complete_posthoc_trace_diagnostic": true,
            "valid_primary_ts1_negative_result": true,
            "exact_s169_rapier_v4_terminal_return_technical_commissioning": false,
            "finite_walking_contract_passed": false,
            "rapier_selected_policy_physical_c6": false,
            "independent_validation": false,
            "population_inference": false,
            "cross_engine_selected_policy_equivalence": false,
            "arbitrary_quadruped_coverage": false,
            "continuous_full_volume_coverage": false,
            "friction_or_material_robustness": false,
            "rough_terrain_robustness": false,
            "external_push_recovery": false,
            "sensor_noise_or_latency_robustness": false,
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
    println!(
        "C6_RAP_V4_TS1_POSTHOC_PASS report_sha256={} failure={} last_front_left_contact=2093 final_airborne_dwell=1078 physical_authority=False",
        RETAINED_REPORT_RAW_SHA256, TERMINAL_STANCE_FAILURE
    );
    Ok(())
}

fn main() {
    if let Err(error) = run() {
        eprintln!("{error}");
        std::process::exit(1);
    }
}
