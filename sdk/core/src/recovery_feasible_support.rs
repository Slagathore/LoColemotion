//! V35: intersect joint-compatible support heights; never claim contact or force.
use crate::schema::{CoreError, Result};
use serde::{Deserialize, Serialize};

pub const MODE_ID: &str = "explicit_floor_joint_feasible_stance_height_reference_slew_v1";
pub const MEMORY_VERSION: &str = "sporespore_balanced_wave_recovery_feasible_support_memory_v1";

pub(crate) struct Direction<'a> {
    pub limb: &'a str,
    pub angle: f64,
    pub anchor_y: f64,
    pub downward: f64,
    pub hip_minimum: f64,
    pub hip_maximum: f64,
    pub knee_maximum: f64,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct LimbHeightInterval {
    pub limb_id: String,
    pub minimum_torso_height_m: f64,
    pub maximum_torso_height_m: f64,
    pub maximum_direction_preserving_knee_rad: f64,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct FeasibleSupportPlan {
    pub schema_version: String,
    pub measured_torso_height_m: f64,
    pub common_minimum_torso_height_m: f64,
    pub common_maximum_torso_height_m: f64,
    pub common_height_interval_nonempty: bool,
    pub requested_stance_torso_height_m: f64,
    pub requested_lowering_m: f64,
    pub lowering_permitted: bool,
    pub ordered_limb_intervals: Vec<LimbHeightInterval>,
    pub ordered_lowering_participant_limb_ids: Vec<String>,
    pub physical_acceptance_authority: bool,
}

pub(crate) fn plan(
    height: f64,
    upper: f64,
    lower: f64,
    radius: f64,
    directions: &[Direction<'_>],
) -> Result<FeasibleSupportPlan> {
    if ![height, upper, lower, radius].iter().all(|v| v.is_finite())
        || upper <= 0.0
        || lower <= 0.0
        || radius <= 0.0
        || directions.len() != 4
    {
        return Err(CoreError::Frame(
            "feasible_support_geometry_domain".to_owned(),
        ));
    }
    let mut intervals = Vec::with_capacity(4);
    for d in directions {
        if ![
            d.angle,
            d.anchor_y,
            d.downward,
            d.hip_minimum,
            d.hip_maximum,
            d.knee_maximum,
        ]
        .iter()
        .all(|v| v.is_finite())
            || d.downward <= 0.0
            || d.downward > 1.0
            || d.angle < d.hip_minimum
            || d.angle > d.hip_maximum
            || d.knee_maximum <= 0.0
            || d.knee_maximum > std::f64::consts::FRAC_PI_2
        {
            return Err(CoreError::Frame(
                "feasible_support_direction_domain".to_owned(),
            ));
        }
        // For positive U,L and 0<=k<=pi/2, beta(k) is monotone. Hip=a-beta(k).
        // Restrict the folded endpoint by BOTH knee and hip limits. Bisection
        // retains the feasible lower endpoint; it is not a fitted tolerance.
        let beta = |k: f64| (lower * k.sin()).atan2(upper + lower * k.cos());
        let mut maximum_knee = d.knee_maximum;
        if beta(maximum_knee) > d.angle - d.hip_minimum {
            let (mut lo, mut hi) = (0.0, maximum_knee);
            for _ in 0..64 {
                let mid = (lo + hi) * 0.5;
                if beta(mid) <= d.angle - d.hip_minimum {
                    lo = mid;
                } else {
                    hi = mid;
                }
            }
            maximum_knee = lo;
        }
        let minimum_length = ((upper + lower * maximum_knee.cos()).powi(2)
            + (lower * maximum_knee.sin()).powi(2))
        .sqrt();
        intervals.push(LimbHeightInterval {
            limb_id: d.limb.to_owned(),
            minimum_torso_height_m: radius - d.anchor_y + minimum_length * d.downward,
            maximum_torso_height_m: radius - d.anchor_y + (upper + lower) * d.downward,
            maximum_direction_preserving_knee_rad: maximum_knee,
        });
    }
    let minimum = intervals
        .iter()
        .map(|r| r.minimum_torso_height_m)
        .fold(f64::NEG_INFINITY, f64::max);
    let maximum = intervals
        .iter()
        .map(|r| r.maximum_torso_height_m)
        .fold(f64::INFINITY, f64::min);
    if !minimum.is_finite() || !maximum.is_finite() {
        return Err(CoreError::NonFinite(
            "feasible_support_height_interval".to_owned(),
        ));
    }
    let nonempty = minimum <= maximum;
    let permitted = nonempty && height >= minimum;
    let target = if permitted {
        height.min(maximum)
    } else {
        height
    };
    Ok(FeasibleSupportPlan {
        schema_version: "sporespore_recovery_feasible_support_plan_v1".to_owned(),
        measured_torso_height_m: height,
        common_minimum_torso_height_m: minimum,
        common_maximum_torso_height_m: maximum,
        common_height_interval_nonempty: nonempty,
        requested_stance_torso_height_m: target,
        requested_lowering_m: height - target,
        lowering_permitted: permitted,
        ordered_limb_intervals: intervals,
        ordered_lowering_participant_limb_ids: Vec::new(),
        physical_acceptance_authority: false,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    fn directions(angles: [f64; 4]) -> Vec<Direction<'static>> {
        ["front_left", "front_right", "rear_left", "rear_right"]
            .into_iter()
            .zip(angles)
            .map(|(limb, angle)| Direction {
                limb,
                angle,
                anchor_y: 0.0,
                downward: angle.cos(),
                hip_minimum: -0.72,
                hip_maximum: 0.72,
                knee_maximum: 1.1,
            })
            .collect()
    }
    #[test]
    fn lower_only_to_the_shared_reachable_height() {
        let d = directions([0.2, 0.0, -0.1, 0.1]);
        let p = plan(0.39, 0.183, 0.167, 0.04, &d).unwrap();
        assert!(p.common_height_interval_nonempty && p.lowering_permitted);
        assert_eq!(
            p.requested_stance_torso_height_m,
            0.04 + 0.35 * 0.2f64.cos()
        );
        assert!(p.requested_stance_torso_height_m >= p.common_minimum_torso_height_m);
        assert!(p.requested_lowering_m > 0.0);
        let already = plan(0.36, 0.183, 0.167, 0.04, &d).unwrap();
        assert_eq!(already.requested_lowering_m, 0.0);
        let low = plan(0.1, 0.183, 0.167, 0.04, &d).unwrap();
        assert!(!low.lowering_permitted);
        assert_eq!(low.requested_stance_torso_height_m, 0.1);
    }
    #[test]
    fn empty_joint_interval_does_not_invent_a_supported_height() {
        let p = plan(
            0.39,
            0.183,
            0.167,
            0.04,
            &directions([-0.72, 0.0, 0.0, 0.0]),
        )
        .unwrap();
        assert!(!p.common_height_interval_nonempty && !p.lowering_permitted);
        assert_eq!(p.requested_lowering_m, 0.0);
        assert_eq!(
            p.ordered_limb_intervals[0].maximum_direction_preserving_knee_rad,
            0.0
        );
    }
    #[test]
    fn folded_endpoint_respects_hip_and_knee_bounds() {
        let d = directions([-0.5, -0.2, 0.0, 0.3]);
        let p = plan(0.39, 0.183, 0.167, 0.04, &d).unwrap();
        for (a, b) in d.iter().zip(&p.ordered_limb_intervals) {
            let k = b.maximum_direction_preserving_knee_rad;
            let h = a.angle - (0.167 * k.sin()).atan2(0.183 + 0.167 * k.cos());
            assert!(h >= a.hip_minimum && h <= a.hip_maximum);
            assert!(k >= 0.0 && k <= a.knee_maximum);
            assert!(b.minimum_torso_height_m <= b.maximum_torso_height_m);
        }
    }
    #[test]
    fn invalid_geometry_fails_closed() {
        let d = directions([0.0; 4]);
        for h in [f64::NAN, f64::INFINITY] {
            assert!(plan(h, 0.183, 0.167, 0.04, &d).is_err());
        }
        assert!(plan(0.39, 0.167, 0.183, 0.04, &d).is_ok());
        assert!(plan(0.39, 0.0, 0.183, 0.04, &d).is_err());
        assert!(plan(0.39, 0.183, 0.167, 0.04, &directions([0.8, 0.0, 0.0, 0.0])).is_err());
    }
}
