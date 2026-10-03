//! R23D74 trace-retention receipt validator shared by the zero-world ghost and
//! the successor physical route.

use serde_json::Value;

const ARTIFACT_SCHEMA: &str = "sporespore_content_addressed_artifact_receipt_v1";

#[derive(Debug, Clone, Copy)]
pub(crate) struct ExpectedReceipt<'a> {
    pub schema_version: &'a str,
    pub stage_id: &'a str,
    pub cell_id: &'a str,
    pub engine_id: &'a str,
    pub campaign_seed: u64,
    pub profile_id: &'a str,
    pub host_mapping_id: &'a str,
    pub row_count: u64,
    pub test_only: bool,
}

pub(crate) fn validate_retention_receipt(
    receipt: &Value,
    expected: ExpectedReceipt<'_>,
) -> Result<(), Vec<String>> {
    let Some(object) = receipt.as_object() else {
        return Err(vec!["R23D74_RECEIPT_NOT_OBJECT".to_owned()]);
    };
    let mut failures = Vec::<String>::new();
    let strings = [
        ("schema_version", expected.schema_version),
        ("stage_id", expected.stage_id),
        ("cell_id", expected.cell_id),
        ("engine_id", expected.engine_id),
        ("profile_id", expected.profile_id),
        ("host_mapping_id", expected.host_mapping_id),
    ];
    for (field, value) in strings {
        if object.get(field).and_then(Value::as_str) != Some(value) {
            failures.push(format!("R23D74_{}_MISMATCH", field.to_ascii_uppercase()));
        }
    }
    if object.get("campaign_seed").and_then(Value::as_u64) != Some(expected.campaign_seed) {
        failures.push("R23D74_CAMPAIGN_SEED_MISMATCH".to_owned());
    }
    let top_level = object.get("row_count").and_then(Value::as_u64);
    let summary = object.get("trace_summary").and_then(Value::as_object);
    let nested = summary
        .and_then(|value| value.get("row_count"))
        .and_then(Value::as_u64);
    if top_level != Some(expected.row_count) {
        failures.push("R23D74_TOP_LEVEL_ROW_COUNT_INVALID".to_owned());
    }
    if nested != Some(expected.row_count) {
        failures.push("R23D74_NESTED_ROW_COUNT_INVALID".to_owned());
    }
    if top_level.is_some() && nested.is_some() && top_level != nested {
        failures.push("R23D74_ROW_COUNT_PROJECTIONS_DIVERGED".to_owned());
    }
    if object
        .get("retained_before_terminal_entry")
        .and_then(Value::as_bool)
        != Some(true)
    {
        failures.push("R23D74_RETAINED_BEFORE_TERMINAL_INVALID".to_owned());
    }
    if object.get("world_attempt_count").and_then(Value::as_u64) != Some(0) {
        failures.push("R23D74_WORLD_ATTEMPT_COUNT_INVALID".to_owned());
    }
    if object.get("world_build_count").and_then(Value::as_u64) != Some(0) {
        failures.push("R23D74_WORLD_BUILD_COUNT_INVALID".to_owned());
    }
    if object
        .get("physical_acceptance_authority")
        .and_then(Value::as_bool)
        != Some(false)
    {
        failures.push("R23D74_PHYSICAL_AUTHORITY_INVALID".to_owned());
    }
    let artifact = object.get("trace_artifact").and_then(Value::as_object);
    if let Some(artifact) = artifact {
        if artifact.get("schema_version").and_then(Value::as_str) != Some(ARTIFACT_SCHEMA) {
            failures.push("R23D74_TRACE_ARTIFACT_SCHEMA_MISMATCH".to_owned());
        }
        if artifact.get("test_only").and_then(Value::as_bool) != Some(expected.test_only) {
            failures.push("R23D74_TRACE_ARTIFACT_TEST_ONLY_MISMATCH".to_owned());
        }
        if let Some(summary) = summary {
            if artifact.get("sha256") != summary.get("raw_sha256") {
                failures.push("R23D74_TRACE_ARTIFACT_SHA_MISMATCH".to_owned());
            }
            if artifact.get("byte_length") != summary.get("byte_length") {
                failures.push("R23D74_TRACE_ARTIFACT_LENGTH_MISMATCH".to_owned());
            }
        }
    } else {
        failures.push("R23D74_TRACE_ARTIFACT_NOT_OBJECT".to_owned());
    }
    if failures.is_empty() {
        Ok(())
    } else {
        Err(failures)
    }
}

#[cfg(test)]
mod tests {
    use std::{env, fs};

    use serde_json::Value;

    use super::{ExpectedReceipt, validate_retention_receipt};

    fn expected() -> ExpectedReceipt<'static> {
        ExpectedReceipt {
            schema_version: "sporespore_qsdk_r23d74_trace_retention_v1",
            stage_id: "trace_retention_receipt_contract_ghost",
            cell_id: "r23d74_receipt_contract_ghost",
            engine_id: "contract_ghost",
            campaign_seed: 23_193,
            profile_id: "sporespore_qsdk_r23d60_selected_s169_actuator_cap_profile_v1",
            host_mapping_id: "contract_ghost",
            row_count: 2,
            test_only: true,
        }
    }

    #[test]
    fn r23d74_receipt_contract_ghost() {
        let Ok(path) = env::var("SPORESPORE_R23D74_RECEIPT_GHOST_PATH") else {
            // The cross-engine PowerShell ghost supplies this path and also
            // requires the emitted marker.  Unrelated full-crate test runs do
            // not own the shared receipt fixture and must remain hermetic.
            return;
        };
        let raw = fs::read(path).expect("read shared R23D74 receipt");
        let receipt: Value = serde_json::from_slice(&raw).expect("parse shared R23D74 receipt");
        validate_retention_receipt(&receipt, expected()).expect("positive receipt");
        let mut mutations = Vec::<Value>::new();
        let mut missing = receipt.clone();
        missing.as_object_mut().unwrap().remove("row_count");
        mutations.push(missing);
        let mut wrong_integer = receipt.clone();
        wrong_integer["row_count"] = Value::from(3_u64);
        mutations.push(wrong_integer);
        let mut wrong_type = receipt.clone();
        wrong_type["row_count"] = Value::String("2".to_owned());
        mutations.push(wrong_type);
        let mut nested_mismatch = receipt.clone();
        nested_mismatch["trace_summary"]["row_count"] = Value::from(1_u64);
        mutations.push(nested_mismatch);
        for mutation in &mutations {
            assert!(validate_retention_receipt(mutation, expected()).is_err());
        }
        println!(
            "QSDK_R23D74_RAPIER_RECEIPT_GHOST positive=true negative_decisions={} models=0 worlds=0",
            mutations.len()
        );
    }
}
