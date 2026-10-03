//! R10DC finite diagnostic reference schedule. This is not a recovery controller.
//! Native composition must separately validate entry context, observations,
//! ownership, phase, energy, actuator limits and publication before execution.
use super::{CoreError, RECOVERY_OUTER_STEP_DURATION_S, Result};
use serde::{Deserialize, Serialize};

const TABLE: &str = include_str!("../../contracts/r10dc_native_reference_endpoints_v1.json");
const LIMITS: [f64; 8] = [1.6, 1.1, 1.6, 1.1, 1.6, 1.1, 1.6, 1.1];
const ENTRY_TOLERANCE_RAD: f64 = 1e-6;
pub const LAST_TICK: u32 = 236;
pub const MAXIMUM_REFERENCE_RATE_RAD_S: f64 = 3.9;

fn require(value: bool, code: &str) -> Result<()> {
    if value {
        Ok(())
    } else {
        Err(CoreError::Frame(format!("r10dc_reference_{code}")))
    }
}

#[derive(Clone, Deserialize)]
#[serde(deny_unknown_fields)]
struct EndpointTable {
    schema_version: String,
    source_result_raw_sha256: String,
    ticks_per_interval: u32,
    ordered_joint_ids: Vec<String>,
    endpoints_rad: Vec<[f64; 8]>,
}

/// An immutable, validated finite schedule. Absolute diagnostic references are
/// intentionally limited to the one exposed entry; they are not a general policy.
pub struct ReferenceSchedule {
    table: EndpointTable,
}

#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct ReferencePoint {
    pub tick: u32,
    pub lower_endpoint: u32,
    pub upper_endpoint: u32,
    pub interpolation_fraction: f64,
    pub ordered_target_positions_rad: [f64; 8],
    pub final_reference: bool,
}

impl ReferenceSchedule {
    pub fn load() -> Result<Self> {
        let table: EndpointTable = serde_json::from_str(TABLE)
            .map_err(|e| CoreError::Frame(format!("r10dc_reference_table:{e}")))?;
        Self::validate(table)
    }

    fn validate(table: EndpointTable) -> Result<Self> {
        let original: EndpointTable = serde_json::from_str(TABLE)
            .map_err(|e| CoreError::Frame(format!("r10dc_reference_table:{e}")))?;
        require(
            table.schema_version == "sporespore_r10dc_native_reference_endpoints_v1"
                && table.source_result_raw_sha256 == original.source_result_raw_sha256
                && table.ticks_per_interval == 2
                && table
                    .ordered_joint_ids
                    .iter()
                    .map(String::as_str)
                    .eq(super::ORDERED_JOINT_IDS)
                && table.ordered_joint_ids.len() == 8
                && table.endpoints_rad.len() == 119,
            "table_identity",
        )?;
        for point in &table.endpoints_rad {
            require(
                point
                    .iter()
                    .enumerate()
                    .all(|(i, x)| x.is_finite() && x.abs() <= LIMITS[i]),
                "joint_limits",
            )?;
        }
        for pair in table.endpoints_rad.windows(2) {
            require(
                (0..8).all(|i| {
                    (pair[1][i] - pair[0][i]).abs() / (2.0 * RECOVERY_OUTER_STEP_DURATION_S)
                        <= MAXIMUM_REFERENCE_RATE_RAD_S
                }),
                "reference_rate",
            )?;
        }
        Ok(Self { table })
    }

    /// Tick zero is the measured entry, not a newly applied command. The caller
    /// applies ticks 1..=236 at the existing outer-step cadence; no implicit hold
    /// or repeat is provided after exhaustion.
    pub fn reference_at(&self, tick: u32) -> Result<ReferencePoint> {
        require(tick <= LAST_TICK, "exhausted")?;
        let lower = tick / 2;
        let upper = if tick % 2 == 0 { lower } else { lower + 1 };
        let fraction = if tick % 2 == 0 { 0.0 } else { 0.5 };
        let a = self.table.endpoints_rad[lower as usize];
        let b = self.table.endpoints_rad[upper as usize];
        // Return stored endpoints directly so they survive bit-for-bit. Only
        // odd ticks interpolate; no clipping or wrap-around changes the path.
        let targets = if lower == upper {
            a
        } else {
            std::array::from_fn(|i| a[i] + (b[i] - a[i]) * fraction)
        };
        Ok(ReferencePoint {
            tick,
            lower_endpoint: lower,
            upper_endpoint: upper,
            interpolation_fraction: fraction,
            ordered_target_positions_rad: targets,
            final_reference: tick == LAST_TICK,
        })
    }

    pub fn start(&self, measured_joint_positions_rad: [f64; 8]) -> Result<ReferenceCursor<'_>> {
        let entry = self.table.endpoints_rad[0];
        require(
            measured_joint_positions_rad
                .iter()
                .enumerate()
                .all(|(i, x)| x.is_finite() && (x - entry[i]).abs() <= ENTRY_TOLERANCE_RAD),
            "entry_joints",
        )?;
        Ok(ReferenceCursor {
            schedule: self,
            next_tick: 1,
        })
    }
}

/// Single-use contiguous reference clock. Native task completion is owned by its
/// supervisor; consuming the last reference makes no completion or support claim.
pub struct ReferenceCursor<'a> {
    schedule: &'a ReferenceSchedule,
    next_tick: u32,
}

impl ReferenceCursor<'_> {
    pub fn advance(&mut self, tick: u32) -> Result<ReferencePoint> {
        require(tick == self.next_tick, "noncontiguous_tick")?;
        let point = self.schedule.reference_at(tick)?;
        self.next_tick += 1;
        Ok(point)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn table() -> EndpointTable {
        serde_json::from_str(TABLE).unwrap()
    }

    #[test]
    fn complete_compiled_reference_fixture() {
        let schedule = ReferenceSchedule::load().unwrap();
        let mut cursor = schedule.start(table().endpoints_rad[0]).unwrap();
        println!(
            "R10DC_REFERENCE_FIXTURE {}",
            serde_json::to_string(&schedule.reference_at(0).unwrap()).unwrap()
        );
        for tick in 1..=LAST_TICK {
            println!(
                "R10DC_REFERENCE_FIXTURE {}",
                serde_json::to_string(&cursor.advance(tick).unwrap()).unwrap()
            );
        }
        assert!(cursor.advance(LAST_TICK + 1).is_err());
    }

    #[test]
    fn endpoints_and_midpoints_preserved() {
        let schedule = ReferenceSchedule::load().unwrap();
        let endpoints = table().endpoints_rad;
        for (i, endpoint) in endpoints.iter().enumerate() {
            assert_eq!(
                schedule
                    .reference_at(2 * i as u32)
                    .unwrap()
                    .ordered_target_positions_rad,
                *endpoint
            );
        }
        for (i, pair) in endpoints.windows(2).enumerate() {
            let actual = schedule
                .reference_at(2 * i as u32 + 1)
                .unwrap()
                .ordered_target_positions_rad;
            for j in 0..8 {
                assert_eq!(actual[j], pair[0][j] + (pair[1][j] - pair[0][j]) * 0.5);
                assert!(
                    actual[j] >= pair[0][j].min(pair[1][j])
                        && actual[j] <= pair[0][j].max(pair[1][j])
                );
            }
        }
    }

    #[test]
    fn contiguous_clock_refuses_skips_repeats_and_exhaustion_without_advancing() {
        let schedule = ReferenceSchedule::load().unwrap();
        let mut cursor = schedule.start(table().endpoints_rad[0]).unwrap();
        assert!(cursor.advance(0).is_err());
        assert!(cursor.advance(2).is_err());
        cursor.advance(1).unwrap();
        assert!(cursor.advance(1).is_err());
        for tick in 2..=LAST_TICK {
            cursor.advance(tick).unwrap();
        }
        assert!(cursor.advance(LAST_TICK).is_err());
        assert!(cursor.advance(LAST_TICK + 1).is_err());
        assert!(cursor.advance(LAST_TICK + 1).is_err());
        assert!(schedule.reference_at(u32::MAX).is_err());
    }

    #[test]
    fn entry_joint_admission_is_finite_and_bounded() {
        let schedule = ReferenceSchedule::load().unwrap();
        let entry = table().endpoints_rad[0];
        for joint in 0..8 {
            for offset in [-2e-6, 2e-6, f64::NAN, f64::INFINITY] {
                let mut value = entry;
                value[joint] += offset;
                assert!(schedule.start(value).is_err());
            }
            for offset in [-5e-7, 5e-7] {
                let mut value = entry;
                value[joint] += offset;
                assert!(schedule.start(value).is_ok());
            }
        }
    }

    #[test]
    fn malformed_schedule_identity_is_refused() {
        let mut value = table();
        value.endpoints_rad.pop();
        assert!(ReferenceSchedule::validate(value).is_err());
        let mut value = table();
        value.ticks_per_interval = 1;
        assert!(ReferenceSchedule::validate(value).is_err());
        let mut value = table();
        value.source_result_raw_sha256 = "crossed".into();
        assert!(ReferenceSchedule::validate(value).is_err());
        let mut value = table();
        value.ordered_joint_ids.swap(0, 1);
        assert!(ReferenceSchedule::validate(value).is_err());
        let mut value = table();
        value.schema_version = "crossed".into();
        assert!(ReferenceSchedule::validate(value).is_err());
        let mut value: serde_json::Value = serde_json::from_str(TABLE).unwrap();
        value["physical_execution_authorized"] = true.into();
        assert!(serde_json::from_value::<EndpointTable>(value).is_err());
    }

    #[test]
    fn nonfinite_limits_and_reference_rate_are_refused_without_clipping() {
        for invalid in [f64::NAN, f64::INFINITY, -f64::INFINITY, 1.6001, -1.6001] {
            let mut value = table();
            value.endpoints_rad[1][0] = invalid;
            assert!(ReferenceSchedule::validate(value).is_err());
        }
        let mut value = table();
        value.endpoints_rad[1][0] = value.endpoints_rad[0][0] + 0.1;
        assert!(ReferenceSchedule::validate(value).is_err());
    }

    #[test]
    fn all_command_ticks_respect_limits_and_reference_margin() {
        let schedule = ReferenceSchedule::load().unwrap();
        let mut previous = schedule
            .reference_at(0)
            .unwrap()
            .ordered_target_positions_rad;
        for tick in 1..=LAST_TICK {
            let point = schedule.reference_at(tick).unwrap();
            assert_eq!(point.final_reference, tick == LAST_TICK);
            for joint in 0..8 {
                let current = point.ordered_target_positions_rad[joint];
                assert!(current.is_finite() && current.abs() <= LIMITS[joint]);
                assert!(
                    (current - previous[joint]).abs() / RECOVERY_OUTER_STEP_DURATION_S
                        <= MAXIMUM_REFERENCE_RATE_RAD_S
                );
            }
            previous = point.ordered_target_positions_rad;
        }
    }
}
