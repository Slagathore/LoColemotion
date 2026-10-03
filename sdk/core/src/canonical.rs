use serde::Serialize;
use serde_json::{Map, Number, Value};
use sha2::{Digest, Sha256};

use crate::schema::{CoreError, Result};

const MAX_EXACT_JSON_INTEGER: i64 = 9_007_199_254_740_991;
const MIN_EXACT_JSON_INTEGER: i64 = -9_007_199_254_740_991;
const CANONICAL_BINARY64_SIGNIFICANT_DECIMAL_DIGITS_V1: usize = 14;
const GUARDED_CANONICAL_SIGNIFICANT_DECIMAL_DIGITS_V1: usize =
    CANONICAL_BINARY64_SIGNIFICANT_DECIMAL_DIGITS_V1 - 1;

fn project_binary64_with_decimal_precision(
    value: f64,
    exponent_fraction_digits: usize,
) -> Result<f64> {
    if !value.is_finite() {
        return Err(CoreError::Serialization(
            "canonical JSON number is nonfinite".to_owned(),
        ));
    }
    if value == 0.0 {
        return Ok(0.0);
    }
    if value.fract() == 0.0
        && value >= MIN_EXACT_JSON_INTEGER as f64
        && value <= MAX_EXACT_JSON_INTEGER as f64
    {
        return Ok(value);
    }

    // Quantize a nonintegral binary64 through an explicit decimal scientific
    // spelling before the JSON writer chooses its shortest representation.
    let quantized_text = format!("{value:.exponent_fraction_digits$e}");
    let quantized = quantized_text.parse::<f64>().map_err(|error| {
        CoreError::Serialization(format!(
            "canonical JSON binary64 quantization failed: {error}"
        ))
    })?;
    Ok(if quantized == 0.0 { 0.0 } else { quantized })
}

/// Project a binary64 value onto the numeric identity used by canonical JSON.
///
/// Portable receipts must not expose more numeric precision than their digest
/// identity retains. Returning the projected value makes a serialize/parse
/// boundary idempotent under the same fourteen-significant-digit policy used
/// by [`canonical_json`].
pub fn project_binary64_to_canonical_number_v1(value: f64) -> Result<f64> {
    project_binary64_with_decimal_precision(
        value,
        CANONICAL_BINARY64_SIGNIFICANT_DECIMAL_DIGITS_V1 - 1,
    )
}

/// Project a binary64 value onto a parser-guarded subset of canonical JSON.
///
/// Canonical JSON retains fourteen significant decimal digits. This transport
/// projection retains thirteen, leaving one decimal guard digit against the
/// observed one-ULP cross-language parser shifts before a subsequent
/// fourteen-digit canonical digest. Use this only for portable numeric values
/// that will be parsed and canonically re-digested by a host; each caller must
/// establish adequacy over its bounded numeric population.
pub fn project_binary64_to_guarded_canonical_number_v1(value: f64) -> Result<f64> {
    project_binary64_with_decimal_precision(
        value,
        GUARDED_CANONICAL_SIGNIFICANT_DECIMAL_DIGITS_V1 - 1,
    )
}

fn canonical_number(number: Number) -> Result<Value> {
    if let Some(integer) = number.as_i64() {
        if !(MIN_EXACT_JSON_INTEGER..=MAX_EXACT_JSON_INTEGER).contains(&integer) {
            return Err(CoreError::Serialization(
                "canonical integer outside exact JSON range".to_owned(),
            ));
        }
        return Ok(Value::Number(Number::from(integer)));
    }
    if let Some(integer) = number.as_u64() {
        if integer > MAX_EXACT_JSON_INTEGER as u64 {
            return Err(CoreError::Serialization(
                "canonical integer outside exact JSON range".to_owned(),
            ));
        }
        return Ok(Value::Number(Number::from(integer)));
    }

    let value = number.as_f64().ok_or_else(|| {
        CoreError::Serialization("canonical JSON number is not binary64".to_owned())
    })?;
    let quantized = project_binary64_to_canonical_number_v1(value)?;
    if quantized == 0.0 {
        return Ok(Value::Number(Number::from(0)));
    }
    if quantized.fract() == 0.0
        && quantized >= MIN_EXACT_JSON_INTEGER as f64
        && quantized <= MAX_EXACT_JSON_INTEGER as f64
    {
        return Ok(Value::Number(Number::from(quantized as i64)));
    }
    let canonical = Number::from_f64(quantized).ok_or_else(|| {
        CoreError::Serialization("canonical JSON quantized number is nonfinite".to_owned())
    })?;
    Ok(Value::Number(canonical))
}

fn sort_value(value: Value) -> Result<Value> {
    match value {
        Value::Object(object) => {
            let mut entries: Vec<_> = object.into_iter().collect();
            entries.sort_by(|left, right| left.0.cmp(&right.0));
            let mut sorted = Map::new();
            for (key, child) in entries {
                sorted.insert(key, sort_value(child)?);
            }
            Ok(Value::Object(sorted))
        }
        Value::Array(values) => Ok(Value::Array(
            values
                .into_iter()
                .map(sort_value)
                .collect::<Result<Vec<_>>>()?,
        )),
        Value::Number(number) => canonical_number(number),
        other => Ok(other),
    }
}

pub fn canonical_json(value: &Value) -> Result<String> {
    serde_json::to_string(&sort_value(value.clone())?)
        .map_err(|error| CoreError::Serialization(error.to_string()))
}

/// Compute the same canonical bytes and digest together without normalizing
/// the JSON tree twice. Neither the numeric projection nor hash input changes.
pub fn canonical_json_and_digest(value: &Value) -> Result<(String, String)> {
    let bytes = canonical_json(value)?;
    let digest = Sha256::digest(bytes.as_bytes());
    Ok((bytes, format!("sha256:{digest:x}")))
}

pub fn digest_json(value: &Value) -> Result<String> {
    canonical_json_and_digest(value).map(|(_, digest)| digest)
}

pub fn digest_serializable<T: Serialize>(value: &T) -> Result<String> {
    let json =
        serde_json::to_value(value).map_err(|error| CoreError::Serialization(error.to_string()))?;
    digest_json(&json)
}

#[cfg(test)]
mod tests {
    use serde_json::json;

    use super::*;

    #[test]
    fn object_order_does_not_change_digest() {
        let left = json!({"z": 1, "a": {"d": 2, "b": 3}});
        let right = json!({"a": {"b": 3, "d": 2}, "z": 1});
        assert_eq!(
            canonical_json(&left).unwrap(),
            canonical_json(&right).unwrap()
        );
        assert_eq!(digest_json(&left).unwrap(), digest_json(&right).unwrap());
    }

    #[test]
    fn array_order_remains_semantic() {
        let left = json!({"values": [1, 2]});
        let right = json!({"values": [2, 1]});
        assert_ne!(digest_json(&left).unwrap(), digest_json(&right).unwrap());
    }

    #[test]
    fn integral_floats_and_negative_zero_match_godot_canonical_numbers() {
        assert_eq!(
            canonical_json(&json!({"a": 1.0, "b": -0.0})).unwrap(),
            r#"{"a":1,"b":0}"#
        );
        assert_eq!(
            digest_json(&json!({"value": 3.0})).unwrap(),
            digest_json(&json!({"value": 3})).unwrap()
        );
    }

    #[test]
    fn binary64_values_use_the_shared_fourteen_significant_digit_policy() {
        assert_eq!(
            canonical_json(&json!({"value": 1.234567890123456})).unwrap(),
            r#"{"value":1.2345678901235}"#
        );
    }

    #[test]
    fn canonical_binary64_projection_is_idempotent_at_the_r78_boundary() {
        let progress = 257.0_f64 / 360.0_f64;
        let blend = progress * progress * (3.0 - 2.0 * progress);
        let pre_transport_target = 0.60_f64 + (0.0_f64 - 0.60_f64) * blend;
        assert_eq!(pre_transport_target.to_bits(), 0x3fbe_86a6_8898_ee48);

        let projected = project_binary64_to_canonical_number_v1(pre_transport_target).unwrap();
        assert_eq!(projected.to_bits(), 0.11924210390946_f64.to_bits());
        assert_eq!(
            project_binary64_to_canonical_number_v1(projected)
                .unwrap()
                .to_bits(),
            projected.to_bits()
        );
        assert_eq!(
            project_binary64_to_canonical_number_v1(-0.0)
                .unwrap()
                .to_bits(),
            0.0_f64.to_bits()
        );
        assert!(project_binary64_to_canonical_number_v1(f64::NAN).is_err());
    }

    #[test]
    fn guarded_projection_absorbs_the_observed_one_ulp_parser_shifts() {
        for pre_transport_target in [5.534979423871267e-05_f64, 1.3863168724204122e-05_f64] {
            let guarded =
                project_binary64_to_guarded_canonical_number_v1(pre_transport_target).unwrap();
            let canonical = project_binary64_to_canonical_number_v1(guarded).unwrap();
            for parsed in [
                f64::from_bits(guarded.to_bits() - 1),
                guarded,
                f64::from_bits(guarded.to_bits() + 1),
            ] {
                assert_eq!(
                    project_binary64_to_canonical_number_v1(parsed)
                        .unwrap()
                        .to_bits(),
                    canonical.to_bits()
                );
            }
            assert_eq!(
                project_binary64_to_guarded_canonical_number_v1(-pre_transport_target)
                    .unwrap()
                    .to_bits(),
                (-guarded).to_bits()
            );
        }
    }

    #[test]
    fn integers_outside_the_exact_json_range_fail_closed() {
        assert!(canonical_json(&json!({"value": 9_007_199_254_740_992_u64})).is_err());
    }
}
