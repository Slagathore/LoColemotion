use serde::{Deserialize, Serialize};

use crate::quadruped::{
    BOUNDED_QUADRUPED_DESCRIPTOR_VERSION, BOUNDED_QUADRUPED_DOMAIN_ID, BoundedQuadrupedDescriptor,
    validate_bounded_quadruped_descriptor,
};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum CoverageClass {
    Supported,
    Edge,
    OutOfDistribution,
    Invalid,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ClosedInterval {
    pub minimum: f64,
    pub maximum: f64,
    pub unit: String,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct AxisDomain {
    pub field: String,
    pub symbol: String,
    pub interval: ClosedInterval,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct DerivedInterval {
    pub field: String,
    pub derivation: String,
    pub interval: ClosedInterval,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SurfaceContinuity {
    ContinuousValue,
    PiecewiseContinuous,
    Discontinuous,
    DiscretePolicyOutput,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ControllerBranchSurface {
    pub output: String,
    pub surface: String,
    pub comparison: String,
    pub continuity: SurfaceContinuity,
    pub note: String,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct AdaptivePhysicalCover {
    pub schema_version: String,
    pub algorithm_id: String,
    pub norm: String,
    pub maximum_cell_radius: Option<f64>,
    pub resolved_cell_count: u64,
    pub unresolved_cell_count: u64,
    pub unresolved_regions: Vec<String>,
    pub counterexamples: Vec<String>,
    pub physical_margin_certificate_present: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ContinuousDomainCertificate {
    pub schema_version: String,
    pub domain_id: String,
    pub descriptor_schema_version: String,
    pub axes: Vec<AxisDomain>,
    pub derived_fixture_intervals: Vec<DerivedInterval>,
    pub controller_branch_surfaces: Vec<ControllerBranchSurface>,
    pub compiler_defined_at_every_domain_point: bool,
    pub controller_defined_at_every_domain_point: bool,
    pub controller_continuous_over_complete_domain: bool,
    pub adaptive_physical_cover: AdaptivePhysicalCover,
    pub analytic_claim_level: String,
    pub physical_claim_level: String,
    pub continuous_full_volume_physical_locomotion_validated: bool,
    pub world_build_count: u32,
    pub physical_acceptance_authority: bool,
}

fn interval(minimum: f64, maximum: f64, unit: &str) -> ClosedInterval {
    ClosedInterval {
        minimum,
        maximum,
        unit: unit.to_owned(),
    }
}

fn surface(
    output: &str,
    value: &str,
    comparison: &str,
    continuity: SurfaceContinuity,
    note: &str,
) -> ControllerBranchSurface {
    ControllerBranchSurface {
        output: output.to_owned(),
        surface: value.to_owned(),
        comparison: comparison.to_owned(),
        continuity,
        note: note.to_owned(),
    }
}

pub fn classify_bounded_quadruped_descriptor(
    descriptor: &BoundedQuadrupedDescriptor,
) -> CoverageClass {
    if descriptor.schema_version != BOUNDED_QUADRUPED_DESCRIPTOR_VERSION {
        return CoverageClass::Invalid;
    }
    if validate_bounded_quadruped_descriptor(descriptor).is_err() {
        return CoverageClass::OutOfDistribution;
    }
    // The compiler is total over the box, but GQ15 physically sampled only 36
    // generated descriptors. An arbitrary point has no inner-volume physical
    // certificate yet and therefore deliberately remains EDGE.
    CoverageClass::Edge
}

pub fn compile_gq15_domain_certificate() -> ContinuousDomainCertificate {
    let axes = [
        ("torso_length_scale", "L", 0.90, 1.10),
        ("torso_width_scale", "W", 0.90, 1.10),
        ("upper_length_fraction", "U", 0.48, 0.55),
        ("hip_span_scale", "H", 0.90, 1.10),
        ("foot_radius_scale", "F", 0.90, 1.10),
        ("front_limb_mass_scale", "M", 0.90, 1.10),
    ]
    .into_iter()
    .map(|(field, symbol, minimum, maximum)| AxisDomain {
        field: field.to_owned(),
        symbol: symbol.to_owned(),
        interval: interval(minimum, maximum, "dimensionless"),
    })
    .collect();
    let derived_fixture_intervals = vec![
        DerivedInterval {
            field: "torso_size_x_m".to_owned(),
            derivation: "0.50*L".to_owned(),
            interval: interval(0.45, 0.55, "m"),
        },
        DerivedInterval {
            field: "torso_size_z_m".to_owned(),
            derivation: "0.32*W".to_owned(),
            interval: interval(0.288, 0.352, "m"),
        },
        DerivedInterval {
            field: "upper_length_m".to_owned(),
            derivation: "0.35*U".to_owned(),
            interval: interval(0.168, 0.1925, "m"),
        },
        DerivedInterval {
            field: "lower_length_m".to_owned(),
            derivation: "0.35*(1-U)".to_owned(),
            interval: interval(0.1575, 0.182, "m"),
        },
        DerivedInterval {
            field: "absolute_hip_x_m".to_owned(),
            derivation: "0.20*H".to_owned(),
            interval: interval(0.18, 0.22, "m"),
        },
        DerivedInterval {
            field: "absolute_hip_z_m".to_owned(),
            derivation: "0.18*H".to_owned(),
            interval: interval(0.162, 0.198, "m"),
        },
        DerivedInterval {
            field: "foot_radius_m".to_owned(),
            derivation: "0.04*F".to_owned(),
            interval: interval(0.036, 0.044, "m"),
        },
        DerivedInterval {
            field: "initial_torso_center_y_m".to_owned(),
            derivation: "0.40+0.04*F".to_owned(),
            interval: interval(0.436, 0.444, "m"),
        },
        DerivedInterval {
            field: "front_limb_mass_multiplier".to_owned(),
            derivation: "M".to_owned(),
            interval: interval(0.90, 1.10, "dimensionless"),
        },
        DerivedInterval {
            field: "rear_limb_mass_multiplier".to_owned(),
            derivation: "2-M".to_owned(),
            interval: interval(0.90, 1.10, "dimensionless"),
        },
        DerivedInterval {
            field: "total_mass_kg".to_owned(),
            derivation: "3+2*(0.25+0.18)*M+2*(0.25+0.18)*(2-M)".to_owned(),
            interval: interval(4.72, 4.72, "kg"),
        },
        DerivedInterval {
            field: "hip_maximum_impulse_nms".to_owned(),
            derivation: "0.055*limb_mass_multiplier".to_owned(),
            interval: interval(0.0495, 0.0605, "N*m*s"),
        },
        DerivedInterval {
            field: "knee_maximum_impulse_nms".to_owned(),
            derivation: "0.045*limb_mass_multiplier".to_owned(),
            interval: interval(0.0405, 0.0495, "N*m*s"),
        },
    ];
    let controller_branch_surfaces = vec![
        surface(
            "interaction_score",
            "every di=0 absolute-value crease",
            "abs",
            SurfaceContinuity::ContinuousValue,
            "continuous but nondifferentiable",
        ),
        surface(
            "interaction_score",
            "unclamped_pairwise_sum=1",
            "clamp",
            SurfaceContinuity::ContinuousValue,
            "continuous saturation",
        ),
        surface(
            "cross_track_heading_gain",
            "S=0.5",
            "< versus >=",
            SurfaceContinuity::Discontinuous,
            "1.0 below and 0.75 at or above",
        ),
        surface(
            "yaw_gain",
            "F=0.985",
            "< versus >=",
            SurfaceContinuity::Discontinuous,
            "small-foot branch is strict",
        ),
        surface(
            "yaw_gain",
            "S=0.9 within F<0.985",
            "< versus >=",
            SurfaceContinuity::Discontinuous,
            "1.1 below and 1.3 at or above",
        ),
        surface(
            "yaw_gain",
            "S=0.5",
            "< versus >=",
            SurfaceContinuity::Discontinuous,
            "branch output depends on F, H, and L",
        ),
        surface(
            "yaw_gain",
            "F=1.01",
            "<= versus >",
            SurfaceContinuity::Discontinuous,
            "large-foot yaw branch is strict",
        ),
        surface(
            "yaw_gain",
            "F=1.025",
            "<= versus >",
            SurfaceContinuity::Discontinuous,
            "returns 1.3 at the surface and 1.0 immediately above",
        ),
        surface(
            "yaw_gain",
            "abs(H-1)=0.02",
            "< versus >=",
            SurfaceContinuity::Discontinuous,
            "conditional on S, F, and L",
        ),
        surface(
            "yaw_gain",
            "L=1.02 within hip-span branch",
            "<= versus >",
            SurfaceContinuity::Discontinuous,
            "1.0 at the surface and 1.1 above",
        ),
        surface(
            "velocity_gain",
            "yaw_gain=1",
            "<= versus >",
            SurfaceContinuity::Discontinuous,
            "higher-precedence yaw branch selects different formula",
        ),
        surface(
            "velocity_gain",
            "S=0.15",
            "< versus >=",
            SurfaceContinuity::Discontinuous,
            "low-score and mid-score policies differ",
        ),
        surface(
            "velocity_gain",
            "S=0.5",
            "< versus >=",
            SurfaceContinuity::Discontinuous,
            "mid-score and high-score policies differ",
        ),
        surface(
            "velocity_gain",
            "W=1",
            "<= versus >",
            SurfaceContinuity::Discontinuous,
            "Candidate35 short-wide branch can jump immediately above W=1",
        ),
        surface(
            "velocity_gain",
            "L=1",
            "< versus >=",
            SurfaceContinuity::Discontinuous,
            "Candidate35 short-wide branch is strict in L",
        ),
        surface(
            "velocity_gain",
            "W=1.02 and W=1.06",
            "clamp knees",
            SurfaceContinuity::ContinuousValue,
            "wide-fraction knees are continuous",
        ),
        surface(
            "motor_guard",
            "S=0.5",
            "< versus >=",
            SurfaceContinuity::DiscretePolicyOutput,
            "guard tuple changes",
        ),
        surface(
            "motor_guard",
            "L=1.04",
            "<= versus >",
            SurfaceContinuity::DiscretePolicyOutput,
            "strong guard length test is strict",
        ),
        surface(
            "motor_guard",
            "W=0.95 and W=1",
            "< or >",
            SurfaceContinuity::DiscretePolicyOutput,
            "strong guard union has strict sides",
        ),
    ];
    ContinuousDomainCertificate {
        schema_version: "sporespore_continuous_domain_certificate_v1".to_owned(),
        domain_id: BOUNDED_QUADRUPED_DOMAIN_ID.to_owned(),
        descriptor_schema_version: BOUNDED_QUADRUPED_DESCRIPTOR_VERSION.to_owned(),
        axes,
        derived_fixture_intervals,
        controller_branch_surfaces,
        compiler_defined_at_every_domain_point: true,
        controller_defined_at_every_domain_point: true,
        controller_continuous_over_complete_domain: false,
        adaptive_physical_cover: AdaptivePhysicalCover {
            schema_version: "sporespore_adaptive_physical_cover_v1".to_owned(),
            algorithm_id: "not_yet_executed".to_owned(),
            norm: "normalized_l_infinity".to_owned(),
            maximum_cell_radius: None,
            resolved_cell_count: 0,
            unresolved_cell_count: 1,
            unresolved_regions: vec!["complete_six_axis_closed_box".to_owned()],
            counterexamples: vec![],
            physical_margin_certificate_present: false,
        },
        analytic_claim_level: "complete_closed_box_compiler_and_total_policy_definition".to_owned(),
        physical_claim_level: "finite_gq15_population_only".to_owned(),
        continuous_full_volume_physical_locomotion_validated: false,
        world_build_count: 0,
        physical_acceptance_authority: false,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn certificate_is_explicitly_not_a_physical_universal_claim() {
        let certificate = compile_gq15_domain_certificate();
        assert!(certificate.compiler_defined_at_every_domain_point);
        assert!(certificate.controller_defined_at_every_domain_point);
        assert!(!certificate.controller_continuous_over_complete_domain);
        assert!(!certificate.continuous_full_volume_physical_locomotion_validated);
        assert_eq!(certificate.adaptive_physical_cover.unresolved_cell_count, 1);
        assert_eq!(certificate.world_build_count, 0);
        assert!(
            certificate
                .controller_branch_surfaces
                .iter()
                .any(|surface| surface.surface == "W=1"
                    && surface.continuity == SurfaceContinuity::Discontinuous)
        );
    }

    #[test]
    fn arbitrary_valid_point_is_compiler_edge_not_supported_physics() {
        let descriptor = BoundedQuadrupedDescriptor::reference("arbitrary_point");
        assert_eq!(
            classify_bounded_quadruped_descriptor(&descriptor),
            CoverageClass::Edge
        );
        let mut outside = descriptor.clone();
        outside.torso_length_scale = 1.100_001;
        assert_eq!(
            classify_bounded_quadruped_descriptor(&outside),
            CoverageClass::OutOfDistribution
        );
        let mut invalid_schema = descriptor;
        invalid_schema.schema_version = "unknown".to_owned();
        assert_eq!(
            classify_bounded_quadruped_descriptor(&invalid_schema),
            CoverageClass::Invalid
        );
    }

    #[test]
    fn interval_extrema_cover_the_exact_fixture_formulas() {
        let certificate = compile_gq15_domain_certificate();
        let total_mass = certificate
            .derived_fixture_intervals
            .iter()
            .find(|value| value.field == "total_mass_kg")
            .unwrap();
        assert_eq!(total_mass.interval.minimum, 4.72);
        assert_eq!(total_mass.interval.maximum, 4.72);
        let foot = certificate
            .derived_fixture_intervals
            .iter()
            .find(|value| value.field == "foot_radius_m")
            .unwrap();
        assert_eq!(
            (foot.interval.minimum, foot.interval.maximum),
            (0.036, 0.044)
        );
    }
}
