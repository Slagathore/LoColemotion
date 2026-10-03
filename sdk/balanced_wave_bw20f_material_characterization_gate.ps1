#requires -Version 7.0

Set-StrictMode -Version Latest

$script:Bw20fAuthoredFrictionValues = @(0.09, 0.37, 0.76, 1.18)
$script:Bw20fExpectedSchema = (
    "sporespore_balanced_wave_bw20f_material_characterization_receipt_v1"
)
$script:Bw20fFixtureId = "SDK.BW20F.godot_jolt_material_sled.v1"
$script:Bw20fGodotVersion = "4.7.stable.mono.official.5b4e0cb0f"
$script:Bw20fGodotRuntimeVersion = "4.7-stable (official)"
$script:Bw20fGodotExecutableSha256 = (
    "c5fc2d0bb24826a6757fa1e6bf2991effb294859c7dd03d09a122ef217484896"
)
$script:Bw20fMaximumBracketWidthN = 2.0
$script:Bw20fMaximumForceSpreadN = 2.0
$script:Bw20fMaximumMonotonicForceDecreaseN = 2.0
$script:Bw20fMaximumMonotonicRatioDecrease = 0.05
$script:Bw20fMaximumSlidingTiltRad = 0.08726646259971647

function Get-Bw20fMapValue {
    param(
        [AllowNull()][object]$Map,
        [Parameter(Mandatory)][string]$Key,
        [AllowNull()][object]$Default = $null
    )
    if (
        $Map -is [System.Collections.IDictionary] -and
        $Map.Contains($Key)
    ) {
        return $Map[$Key]
    }
    return $Default
}

function Test-Bw20fFinite {
    param([AllowNull()][object]$Value)
    try {
        $number = [double]$Value
        return -not (
            [double]::IsNaN($number) -or
            [double]::IsInfinity($number)
        )
    } catch {
        return $false
    }
}

function Test-Bw20fNear {
    param(
        [AllowNull()][object]$Actual,
        [double]$Expected,
        [double]$Tolerance = 1.0e-9
    )
    return (
        (Test-Bw20fFinite $Actual) -and
        [math]::Abs(([double]$Actual) - $Expected) -le $Tolerance
    )
}

function Test-Bw20fMaterialContract {
    param(
        [AllowNull()][object]$Contract,
        [double]$ExpectedFriction
    )
    if ($Contract -isnot [System.Collections.IDictionary]) {
        return $false
    }
    foreach ($sideName in @("body", "floor")) {
        $side = Get-Bw20fMapValue $Contract $sideName
        if (
            $side -isnot [System.Collections.IDictionary] -or
            -not (Test-Bw20fNear (
                Get-Bw20fMapValue $side "friction"
            ) $ExpectedFriction 1.0e-6) -or
            -not [bool](Get-Bw20fMapValue $side "rough" $false) -or
            -not (Test-Bw20fNear (
                Get-Bw20fMapValue $side "bounce"
            ) 0.0 1.0e-9) -or
            -not [bool](Get-Bw20fMapValue $side "absorbent" $false)
        ) {
            return $false
        }
    }
    return (
        [string](Get-Bw20fMapValue $Contract "godot_pair_rule" "") -ceq
            "highest_friction_both_rough_v1" -and
        (Test-Bw20fNear (
            Get-Bw20fMapValue $Contract "authored_friction_cell"
        ) $ExpectedFriction 1.0e-6) -and
        -not [bool](Get-Bw20fMapValue (
            $Contract
        ) "portable_material_coefficient" $true) -and
        -not [bool](Get-Bw20fMapValue $Contract "locomotion_robustness" $true)
    )
}

function Add-Bw20fGateResult {
    param(
        [AllowEmptyCollection()]
        [Parameter(Mandatory)][System.Collections.Generic.List[object]]$Gates,
        [int]$Ordinal,
        [Parameter(Mandatory)][string]$GateId,
        [bool]$Passed,
        [Parameter(Mandatory)][string]$FailureCode
    )
    $Gates.Add([ordered]@{
        ordinal = $Ordinal
        gate_id = $GateId
        passed = $Passed
        failure_code = $(if ($Passed) { "" } else { $FailureCode })
    })
}

function Test-Bw20fMaterialCharacterizationReceipt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Receipt
    )

    $gates = [System.Collections.Generic.List[object]]::new()
    $engine = Get-Bw20fMapValue $Receipt "engine" @{}
    $enginePassed = (
        [string](Get-Bw20fMapValue $engine "physics_engine" "") -ceq
            "Jolt Physics" -and
        [string](Get-Bw20fMapValue $engine "godot_version" "") -ceq
            $script:Bw20fGodotVersion -and
        [string](Get-Bw20fMapValue $engine "godot_runtime_version" "") -ceq
            $script:Bw20fGodotRuntimeVersion -and
        [string](Get-Bw20fMapValue $engine "godot_executable_sha256" "") -ceq
            $script:Bw20fGodotExecutableSha256 -and
        [int](Get-Bw20fMapValue $engine "physics_hz" -1) -eq 120 -and
        [int](Get-Bw20fMapValue $engine "solver_velocity_steps" -1) -eq 20 -and
        [int](Get-Bw20fMapValue $engine "solver_position_steps" -1) -eq 7
    )
    Add-Bw20fGateResult $gates 1 "engine_identity" $enginePassed `
        "BW20F_ENGINE_IDENTITY"

    $observerPassed = [bool](Get-Bw20fMapValue (
        $Receipt
    ) "observer_profile_executable" $false)
    Add-Bw20fGateResult $gates 2 "observer_profile" $observerPassed `
        "BW20F_OBSERVER_PROFILE"

    $invalid = Get-Bw20fMapValue $Receipt "invalid_value_control" @{}
    $invalidPassed = (
        [bool](Get-Bw20fMapValue $invalid "rejected" $false) -and
        [string](Get-Bw20fMapValue $invalid "failure_code" "") -ceq
            "SDK_FRICTION_LADDER_VALUE_INVALID" -and
        (Test-Bw20fNear (
            Get-Bw20fMapValue $invalid "attempted_friction"
        ) 0.25)
    )
    Add-Bw20fGateResult $gates 3 "invalid_value_control" $invalidPassed `
        "BW20F_INVALID_VALUE_CONTROL"

    $frictionless = Get-Bw20fMapValue $Receipt "frictionless_control" @{}
    $frictionlessStage = Get-Bw20fMapValue $frictionless "stage" @{}
    $frictionlessPassed = (
        [bool](Get-Bw20fMapValue $frictionless "ok" $false) -and
        [string](Get-Bw20fMapValue $frictionless "failure_code" "x") -ceq "" -and
        [int](Get-Bw20fMapValue $frictionless "world_build_count" -1) -eq 1 -and
        [string](Get-Bw20fMapValue $frictionless "classification" "") -ceq
            "SLIDING" -and
        (Test-Bw20fMaterialContract (
            Get-Bw20fMapValue $frictionless "material_contract"
        ) 0.0) -and
        (Test-Bw20fFinite (
            Get-Bw20fMapValue $frictionlessStage "max_slip_speed_mps"
        )) -and
        [double](Get-Bw20fMapValue (
            $frictionlessStage
        ) "max_slip_speed_mps" -1.0) -ge 0.05 -and
        (Test-Bw20fFinite (
            Get-Bw20fMapValue $frictionlessStage "tangential_displacement_m"
        )) -and
        [double](Get-Bw20fMapValue (
            $frictionlessStage
        ) "tangential_displacement_m" -1.0) -ge 0.01
    )
    Add-Bw20fGateResult $gates 4 "frictionless_control" $frictionlessPassed `
        "BW20F_FRICTIONLESS_CONTROL"

    $cells = @(Get-Bw20fMapValue $Receipt "positive_cells" @())
    $recomputedCells = [System.Collections.Generic.List[object]]::new()
    $nextOrdinal = 5
    for ($cellIndex = 0; $cellIndex -lt 4; $cellIndex += 1) {
        $expectedFriction = [double]$script:Bw20fAuthoredFrictionValues[$cellIndex]
        $cell = if ($cellIndex -lt $cells.Count) { $cells[$cellIndex] } else { @{} }
        $replicates = @(Get-Bw20fMapValue $cell "replicates" @())
        $lowerForces = [System.Collections.Generic.List[double]]::new()
        $upperForces = [System.Collections.Generic.List[double]]::new()
        $lowerRatios = [System.Collections.Generic.List[double]]::new()

        for ($replicateIndex = 0; $replicateIndex -lt 3; $replicateIndex += 1) {
            $replicate = if ($replicateIndex -lt $replicates.Count) {
                $replicates[$replicateIndex]
            } else {
                @{}
            }
            $lower = Get-Bw20fMapValue $replicate "breakaway_force_lower_n"
            $upper = Get-Bw20fMapValue $replicate "breakaway_force_upper_n"
            $lowerRatio = Get-Bw20fMapValue (
                $replicate
            ) "empirical_static_ratio_lower"
            $upperRatio = Get-Bw20fMapValue (
                $replicate
            ) "empirical_static_ratio_upper"
            $firstSliding = Get-Bw20fMapValue $replicate "first_sliding_stage" @{}
            $secondSliding = Get-Bw20fMapValue $replicate "second_sliding_stage" @{}
            $analysis = Get-Bw20fMapValue $replicate "breakaway_analysis" @{}
            $replicatePassed = (
                $replicates.Count -eq 3 -and
                [bool](Get-Bw20fMapValue $replicate "ok" $false) -and
                [string](Get-Bw20fMapValue $replicate "failure_code" "x") -ceq "" -and
                (Test-Bw20fNear (
                    Get-Bw20fMapValue $replicate "friction"
                ) $expectedFriction 1.0e-9) -and
                [int](Get-Bw20fMapValue $replicate "replicate_index" -1) -eq
                    ($replicateIndex + 1) -and
                [int](Get-Bw20fMapValue $replicate "world_build_count" -1) -eq 1 -and
                (Test-Bw20fMaterialContract (
                    Get-Bw20fMapValue $replicate "material_contract"
                ) $expectedFriction) -and
                [bool](Get-Bw20fMapValue $analysis "ok" $false) -and
                [bool](Get-Bw20fMapValue $analysis "breakaway_detected" $false) -and
                [bool](Get-Bw20fMapValue (
                    $replicate
                ) "all_stage_observations_complete" $false) -and
                [bool](Get-Bw20fMapValue (
                    $replicate
                ) "positive_force_held_observed" $false) -and
                [bool](Get-Bw20fMapValue (
                    $replicate
                ) "two_consecutive_sliding_stages_observed" $false) -and
                (Test-Bw20fFinite $lower) -and
                (Test-Bw20fFinite $upper) -and
                [double]$upper -gt [double]$lower -and
                ([double]$upper - [double]$lower) -le
                    ($script:Bw20fMaximumBracketWidthN + 1.0e-9) -and
                (Test-Bw20fFinite $lowerRatio) -and
                (Test-Bw20fFinite $upperRatio) -and
                [double]$lowerRatio -gt 0.0 -and
                [double]$upperRatio -gt [double]$lowerRatio -and
                (Test-Bw20fFinite (
                    Get-Bw20fMapValue $firstSliding "max_body_tilt_rad"
                )) -and
                [double](Get-Bw20fMapValue (
                    $firstSliding
                ) "max_body_tilt_rad" 1.0) -lt
                    $script:Bw20fMaximumSlidingTiltRad -and
                (Test-Bw20fFinite (
                    Get-Bw20fMapValue $secondSliding "max_body_tilt_rad"
                )) -and
                [double](Get-Bw20fMapValue (
                    $secondSliding
                ) "max_body_tilt_rad" 1.0) -lt
                    $script:Bw20fMaximumSlidingTiltRad
            )
            Add-Bw20fGateResult $gates $nextOrdinal (
                "mu{0:D3}_replicate_{1}" -f
                [int][math]::Round($expectedFriction * 100.0),
                ($replicateIndex + 1)
            ) $replicatePassed "BW20F_REPLICATE_GATE"
            $nextOrdinal += 1
            if (
                (Test-Bw20fFinite $lower) -and
                (Test-Bw20fFinite $upper) -and
                (Test-Bw20fFinite $lowerRatio)
            ) {
                $lowerForces.Add([double]$lower)
                $upperForces.Add([double]$upper)
                $lowerRatios.Add([double]$lowerRatio)
            }
        }

        $reportedCoefficient = Get-Bw20fMapValue (
            $cell
        ) "coefficient_derivation" @{}
        $computedFirstSpread = if ($upperForces.Count -eq 3) {
            ($upperForces | Measure-Object -Maximum).Maximum -
                ($upperForces | Measure-Object -Minimum).Minimum
        } else { [double]::PositiveInfinity }
        $computedLowerSpread = if ($lowerForces.Count -eq 3) {
            ($lowerForces | Measure-Object -Maximum).Maximum -
                ($lowerForces | Measure-Object -Minimum).Minimum
        } else { [double]::PositiveInfinity }
        $computedMinimumLowerForce = if ($lowerForces.Count -eq 3) {
            ($lowerForces | Measure-Object -Minimum).Minimum
        } else { [double]::NaN }
        $computedMinimumLowerRatio = if ($lowerRatios.Count -eq 3) {
            ($lowerRatios | Measure-Object -Minimum).Minimum
        } else { [double]::NaN }
        $expectedControllerMu = if (Test-Bw20fFinite $computedMinimumLowerRatio) {
            [math]::Min(
                1.0,
                [math]::Floor(100.0 * $computedMinimumLowerRatio) / 100.0
            )
        } else { [double]::NaN }
        $cellPassed = (
            $cell -is [System.Collections.IDictionary] -and
            [bool](Get-Bw20fMapValue $cell "ok" $false) -and
            [string](Get-Bw20fMapValue $cell "failure_code" "x") -ceq "" -and
            (Test-Bw20fNear (
                Get-Bw20fMapValue $cell "authored_friction"
            ) $expectedFriction 1.0e-9) -and
            $replicates.Count -eq 3 -and
            $lowerForces.Count -eq 3 -and
            $computedFirstSpread -le
                ($script:Bw20fMaximumForceSpreadN + 1.0e-9) -and
            $computedLowerSpread -le
                ($script:Bw20fMaximumForceSpreadN + 1.0e-9) -and
            (Test-Bw20fNear (
                Get-Bw20fMapValue $cell "first_sliding_force_spread_n"
            ) $computedFirstSpread 1.0e-9) -and
            (Test-Bw20fNear (
                Get-Bw20fMapValue $cell "lower_breakaway_force_spread_n"
            ) $computedLowerSpread 1.0e-9) -and
            (Test-Bw20fNear (
                Get-Bw20fMapValue $cell "minimum_lower_breakaway_force_n"
            ) $computedMinimumLowerForce 1.0e-9) -and
            (Test-Bw20fNear (
                Get-Bw20fMapValue $cell "minimum_lower_empirical_ratio"
            ) $computedMinimumLowerRatio 1.0e-12) -and
            [bool](Get-Bw20fMapValue $reportedCoefficient "ok" $false) -and
            [string](Get-Bw20fMapValue (
                $reportedCoefficient
            ) "failure_code" "x") -ceq "" -and
            [string](Get-Bw20fMapValue (
                $reportedCoefficient
            ) "rounding_rule" "") -ceq
                "min(1.0,floor(100*minimum_lower_ratio)/100)" -and
            (Test-Bw20fNear (
                Get-Bw20fMapValue $reportedCoefficient "minimum_lower_ratio"
            ) $computedMinimumLowerRatio 1.0e-12) -and
            (Test-Bw20fNear (
                Get-Bw20fMapValue $reportedCoefficient "controller_mu"
            ) $expectedControllerMu 1.0e-12) -and
            $expectedControllerMu -gt 0.0 -and
            $expectedControllerMu -le 1.0 -and
            -not [bool](Get-Bw20fMapValue (
                $reportedCoefficient
            ) "cross_engine_equivalent" $true) -and
            -not [bool](Get-Bw20fMapValue (
                $reportedCoefficient
            ) "locomotion_robustness" $true)
        )
        Add-Bw20fGateResult $gates $nextOrdinal (
            "mu{0:D3}_cell" -f
            [int][math]::Round($expectedFriction * 100.0)
        ) $cellPassed "BW20F_CELL_GATE"
        $nextOrdinal += 1
        $recomputedCells.Add([ordered]@{
            authored_friction = $expectedFriction
            minimum_lower_breakaway_force_n = $computedMinimumLowerForce
            minimum_lower_empirical_ratio = $computedMinimumLowerRatio
            controller_mu = $expectedControllerMu
            passed = $cellPassed
        })
    }

    $monotonicityReported = Get-Bw20fMapValue $Receipt "monotonicity" @{}
    $monotonicityPassed = (
        $recomputedCells.Count -eq 4 -and
        [bool](Get-Bw20fMapValue $monotonicityReported "ok" $false) -and
        @(Get-Bw20fMapValue $monotonicityReported "violations" @()).Count -eq 0 -and
        (Test-Bw20fNear (
            Get-Bw20fMapValue $monotonicityReported "maximum_force_decrease_n"
        ) $script:Bw20fMaximumMonotonicForceDecreaseN) -and
        (Test-Bw20fNear (
            Get-Bw20fMapValue $monotonicityReported "maximum_ratio_decrease"
        ) $script:Bw20fMaximumMonotonicRatioDecrease)
    )
    for ($index = 1; $index -lt $recomputedCells.Count; $index += 1) {
        $previous = $recomputedCells[$index - 1]
        $current = $recomputedCells[$index]
        $monotonicityPassed = (
            $monotonicityPassed -and
            [double]$current.minimum_lower_breakaway_force_n -ge
                ([double]$previous.minimum_lower_breakaway_force_n -
                    $script:Bw20fMaximumMonotonicForceDecreaseN) -and
            [double]$current.minimum_lower_empirical_ratio -ge
                ([double]$previous.minimum_lower_empirical_ratio -
                    $script:Bw20fMaximumMonotonicRatioDecrease)
        )
    }
    Add-Bw20fGateResult $gates 21 "operational_monotonicity" `
        $monotonicityPassed "BW20F_MONOTONICITY"

    $coefficientsPassed = (
        $recomputedCells.Count -eq 4 -and
        @($recomputedCells | Where-Object {
            -not [bool]$_.passed -or
            -not (Test-Bw20fFinite $_.controller_mu) -or
            [double]$_.controller_mu -le 0.0 -or
            [double]$_.controller_mu -gt 1.0
        }).Count -eq 0
    )
    Add-Bw20fGateResult $gates 22 "profile_coefficient_derivation" `
        $coefficientsPassed "BW20F_COEFFICIENT_DERIVATION"

    $negativeClaimFields = @(
        "adapter_actuation_applied",
        "physics_transform_or_velocity_written",
        "walking",
        "material_robustness",
        "balance_improvement",
        "physical_balance_recovery",
        "friction_material_locomotion_robustness",
        "continuous_friction_coverage",
        "cross_engine_equivalence",
        "rough_terrain_robustness",
        "external_push_recovery",
        "sensor_fault_robustness",
        "fresh_morphology_validation",
        "physical_acceptance_authority",
        "completed_engine_neutral_sdk"
    )
    $claimsPassed = $true
    foreach ($field in $negativeClaimFields) {
        $claimsPassed = (
            $claimsPassed -and
            -not [bool](Get-Bw20fMapValue $Receipt $field $true)
        )
    }
    Add-Bw20fGateResult $gates 23 "negative_claim_boundary" $claimsPassed `
        "BW20F_CLAIM_INFLATION"

    $fixture = Get-Bw20fMapValue $Receipt "fixture" @{}
    $reportedValues = @(Get-Bw20fMapValue (
        $fixture
    ) "positive_friction_values" @())
    $authoredValues = @(Get-Bw20fMapValue (
        $fixture
    ) "authored_friction_values" @())
    $fixtureValuesExact = (
        [string](Get-Bw20fMapValue $fixture "fixture_id" "") -ceq
            $script:Bw20fFixtureId -and
        $reportedValues.Count -eq 4 -and
        $authoredValues.Count -eq 5 -and
        (Test-Bw20fNear $authoredValues[0] 0.0)
    )
    for ($index = 0; $index -lt 4; $index += 1) {
        $fixtureValuesExact = (
            $fixtureValuesExact -and
            (Test-Bw20fNear (
                $reportedValues[$index]
            ) $script:Bw20fAuthoredFrictionValues[$index]) -and
            (Test-Bw20fNear (
                $authoredValues[$index + 1]
            ) $script:Bw20fAuthoredFrictionValues[$index])
        )
    }
    $fixtureExact = (
        $fixtureValuesExact -and
        (Test-Bw20fNear (
            Get-Bw20fMapValue $fixture "frictionless_force_n"
        ) 2.0) -and
        [int](Get-Bw20fMapValue $fixture "settle_ticks" -1) -eq 180 -and
        [int](Get-Bw20fMapValue $fixture "stage_ticks" -1) -eq 60 -and
        [int](Get-Bw20fMapValue $fixture "analysis_ticks" -1) -eq 30 -and
        [string](Get-Bw20fMapValue $fixture "force_application" "") -ceq
            "RigidBody3D.apply_central_force_once_per_tick" -and
        [string](Get-Bw20fMapValue $fixture "stopping_rule" "") -ceq
            "stop_after_two_consecutive_completed_sliding_stages" -and
        -not [bool](Get-Bw20fMapValue $fixture "hidden_rotation_constraint" $true) -and
        -not [bool](Get-Bw20fMapValue $fixture "hidden_damping" $true)
    )
    $metaExact = (
        [string](Get-Bw20fMapValue $Receipt "schema_version" "") -ceq
            $script:Bw20fExpectedSchema -and
        [bool](Get-Bw20fMapValue $Receipt "ok" $false) -and
        [int](Get-Bw20fMapValue $Receipt "passed_gate_count" -1) -eq 23 -and
        [int](Get-Bw20fMapValue $Receipt "failed_gate_count" -1) -eq 0 -and
        [int](Get-Bw20fMapValue $Receipt "expected_gate_count" -1) -eq 23 -and
        [int](Get-Bw20fMapValue $Receipt "expected_world_count" -1) -eq 13 -and
        [int](Get-Bw20fMapValue $Receipt "observed_world_count" -1) -eq 13 -and
        $cells.Count -eq 4 -and
        $fixtureExact -and
        -not [bool](Get-Bw20fMapValue $Receipt "development_data_only" $true) -and
        [bool](Get-Bw20fMapValue $Receipt "cold_characterization" $false)
    )
    $failedGates = @($gates | Where-Object { -not [bool]$_.passed })
    $failureCodes = @(
        $failedGates | ForEach-Object { [string]$_.failure_code }
    )
    if (-not $metaExact) {
        $failureCodes += "BW20F_RECEIPT_META_INTEGRITY"
    }
    $failureCodes = @($failureCodes | Select-Object -Unique)

    return [ordered]@{
        schema_version = "sporespore_balanced_wave_bw20f_gate_evaluation_v1"
        ok = $failureCodes.Count -eq 0
        expected_gate_count = 23
        reconstructed_passed_gate_count = 23 - $failedGates.Count
        reconstructed_failed_gate_count = $failedGates.Count
        receipt_meta_integrity_passed = $metaExact
        fixture_identity_and_matrix_passed = $fixtureExact
        expected_world_count = 13
        observed_world_count = [int](Get-Bw20fMapValue (
            $Receipt
        ) "observed_world_count" -1)
        gates = $gates.ToArray()
        cells = $recomputedCells.ToArray()
        failure_codes = $failureCodes
        claims_remain_bounded = $claimsPassed
        physical_acceptance_authority = $false
    }
}

function New-Bw20fMaterialContract {
    param([double]$Friction)
    return [ordered]@{
        body = [ordered]@{
            friction = $Friction
            rough = $true
            bounce = 0.0
            absorbent = $true
        }
        floor = [ordered]@{
            friction = $Friction
            rough = $true
            bounce = 0.0
            absorbent = $true
        }
        godot_pair_rule = "highest_friction_both_rough_v1"
        authored_friction_cell = $Friction
        authored_value_outside_documented_range = $Friction -gt 1.0
        portable_material_coefficient = $false
        locomotion_robustness = $false
    }
}

function New-Bw20fPerfectSyntheticCharacterizationReceipt {
    [CmdletBinding()]
    param()

    $minimumForces = @(3.0, 14.0, 30.0, 46.0)
    $minimumRatios = @(0.08, 0.36, 0.75, 1.17)
    $cells = [System.Collections.Generic.List[object]]::new()
    for ($cellIndex = 0; $cellIndex -lt 4; $cellIndex += 1) {
        $friction = [double]$script:Bw20fAuthoredFrictionValues[$cellIndex]
        $lowerForce = [double]$minimumForces[$cellIndex]
        $lowerRatio = [double]$minimumRatios[$cellIndex]
        $upperForce = $lowerForce + 1.0
        $upperRatio = $lowerRatio + 0.02
        $replicates = [System.Collections.Generic.List[object]]::new()
        for ($replicateIndex = 1; $replicateIndex -le 3; $replicateIndex += 1) {
            $replicates.Add([ordered]@{
                ok = $true
                failure_code = ""
                friction = $friction
                replicate_index = $replicateIndex
                world_build_count = 1
                material_contract = New-Bw20fMaterialContract $friction
                contact_cap_per_body = 64
                breakaway_analysis = [ordered]@{
                    ok = $true
                    breakaway_detected = $true
                }
                classified_stages = @()
                breakaway_force_lower_n = $lowerForce
                breakaway_force_upper_n = $upperForce
                empirical_static_ratio_lower = $lowerRatio
                empirical_static_ratio_upper = $upperRatio
                first_sliding_stage = [ordered]@{
                    max_body_tilt_rad = 0.01
                }
                second_sliding_stage = [ordered]@{
                    max_body_tilt_rad = 0.01
                }
                all_stage_observations_complete = $true
                positive_force_held_observed = $true
                two_consecutive_sliding_stages_observed = $true
            })
        }
        $controllerMu = [math]::Min(
            1.0,
            [math]::Floor(100.0 * $lowerRatio) / 100.0
        )
        $cells.Add([ordered]@{
            ok = $true
            failure_code = ""
            authored_friction = $friction
            replicates = $replicates.ToArray()
            first_sliding_force_spread_n = 0.0
            lower_breakaway_force_spread_n = 0.0
            minimum_lower_breakaway_force_n = $lowerForce
            minimum_lower_empirical_ratio = $lowerRatio
            coefficient_derivation = [ordered]@{
                ok = $true
                failure_code = ""
                minimum_lower_ratio = $lowerRatio
                rounding_rule = (
                    "min(1.0,floor(100*minimum_lower_ratio)/100)"
                )
                documented_godot_maximum_cap = 1.0
                controller_mu = $controllerMu
                cross_engine_equivalent = $false
                locomotion_robustness = $false
            }
        })
    }

    $fixtureValues = @(0.0) + $script:Bw20fAuthoredFrictionValues
    return [ordered]@{
        schema_version = $script:Bw20fExpectedSchema
        ok = $true
        passed_gate_count = 23
        failed_gate_count = 0
        expected_gate_count = 23
        engine = [ordered]@{
            physics_engine = "Jolt Physics"
            godot_version = $script:Bw20fGodotVersion
            godot_runtime_version = $script:Bw20fGodotRuntimeVersion
            godot_executable_sha256 = $script:Bw20fGodotExecutableSha256
            physics_hz = 120
            solver_velocity_steps = 20
            solver_position_steps = 7
        }
        observer_profile_executable = $true
        invalid_value_control = [ordered]@{
            attempted_friction = 0.25
            rejected = $true
            failure_code = "SDK_FRICTION_LADDER_VALUE_INVALID"
        }
        fixture = [ordered]@{
            fixture_id = $script:Bw20fFixtureId
            authored_friction_values = $fixtureValues
            positive_friction_values = $script:Bw20fAuthoredFrictionValues
            frictionless_force_n = 2.0
            floor_size_m = [ordered]@{ x = 200.0; y = 1.0; z = 8.0 }
            settle_ticks = 180
            stage_ticks = 60
            analysis_ticks = 30
            force_stages_n = @()
            force_application = "RigidBody3D.apply_central_force_once_per_tick"
            stopping_rule = "stop_after_two_consecutive_completed_sliding_stages"
            hidden_rotation_constraint = $false
            hidden_damping = $false
        }
        breakaway_config = [ordered]@{
            minimum_samples_per_stage = 30
            maximum_holding_speed_mps = 0.01
            maximum_holding_displacement_m = 0.003
            minimum_sliding_speed_mps = 0.05
            minimum_sliding_displacement_m = 0.01
        }
        expected_world_count = 13
        observed_world_count = 13
        frictionless_control = [ordered]@{
            ok = $true
            failure_code = ""
            world_build_count = 1
            classification = "SLIDING"
            material_contract = New-Bw20fMaterialContract 0.0
            stage = [ordered]@{
                max_slip_speed_mps = 0.1
                tangential_displacement_m = 0.02
            }
        }
        positive_cells = $cells.ToArray()
        monotonicity = [ordered]@{
            ok = $true
            maximum_force_decrease_n = 2.0
            maximum_ratio_decrease = 0.05
            violations = @()
        }
        adapter_actuation_applied = $false
        physics_transform_or_velocity_written = $false
        development_data_only = $false
        cold_characterization = $true
        walking = $false
        material_robustness = $false
        balance_improvement = $false
        physical_balance_recovery = $false
        friction_material_locomotion_robustness = $false
        continuous_friction_coverage = $false
        cross_engine_equivalence = $false
        rough_terrain_robustness = $false
        external_push_recovery = $false
        sensor_fault_robustness = $false
        fresh_morphology_validation = $false
        physical_acceptance_authority = $false
        completed_engine_neutral_sdk = $false
    }
}
