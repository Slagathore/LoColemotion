#requires -Version 7.0

Set-StrictMode -Version Latest

$script:Bw24mValues = @(0.59, 0.71, 0.83)
$script:Bw24mSchema = (
    "sporespore_balanced_wave_bw24m_material_characterization_receipt_v1"
)
$script:Bw24mFixtureId = "SDK.BW24M.godot_jolt_material_sled.v1"
$script:Bw24mGodotVersion = "4.7.stable.mono.official.5b4e0cb0f"
$script:Bw24mGodotRuntimeVersion = "4.7-stable (official)"
$script:Bw24mGodotLauncherSha256 = (
    "c5fc2d0bb24826a6757fa1e6bf2991effb294859c7dd03d09a122ef217484896"
)
$script:Bw24mGodotRuntimeSha256 = (
    "baa909d0a905021da80cfc831713e9d3ba4bd0935ac3b93ba4c77dc140cfecc4"
)
$script:Bw24mExpectedWorldCount = 10
$script:Bw24mExpectedGateCount = 19
$script:Bw24mMaximumBracketWidthN = 2.0
$script:Bw24mMaximumForceSpreadN = 2.0
$script:Bw24mMaximumMonotonicForceDecreaseN = 2.0
$script:Bw24mMaximumMonotonicRatioDecrease = 0.05
$script:Bw24mMaximumSlidingTiltRad = 0.08726646259971647

function Get-Bw24mMapValue {
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

function Test-Bw24mFinite {
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
function Test-Bw24mNear {
    param(
        [AllowNull()][object]$Actual,
        [double]$Expected,
        [double]$Tolerance = 1.0e-9
    )
    return (
        (Test-Bw24mFinite $Actual) -and
        [math]::Abs(([double]$Actual) - $Expected) -le $Tolerance
    )
}

function Test-Bw24mMaterialContract {
    param(
        [AllowNull()][object]$Contract,
        [double]$ExpectedFriction
    )
    if ($Contract -isnot [System.Collections.IDictionary]) {
        return $false
    }
    foreach ($sideName in @("body", "floor")) {
        $side = Get-Bw24mMapValue $Contract $sideName
        if (
            $side -isnot [System.Collections.IDictionary] -or
            -not (Test-Bw24mNear (
                Get-Bw24mMapValue $side "friction"
            ) $ExpectedFriction 1.0e-6) -or
            -not [bool](Get-Bw24mMapValue $side "rough" $false) -or
            -not (Test-Bw24mNear (
                Get-Bw24mMapValue $side "bounce"
            ) 0.0 1.0e-9) -or
            -not [bool](Get-Bw24mMapValue $side "absorbent" $false)
        ) {
            return $false
        }
    }
    return (
        [string](Get-Bw24mMapValue $Contract "godot_pair_rule" "") -ceq
            "highest_friction_both_rough_v1" -and
        (Test-Bw24mNear (
            Get-Bw24mMapValue $Contract "authored_friction_cell"
        ) $ExpectedFriction 1.0e-6) -and
        -not [bool](Get-Bw24mMapValue (
            $Contract
        ) "portable_material_coefficient" $true) -and
        -not [bool](Get-Bw24mMapValue $Contract "locomotion_robustness" $true)
    )
}

function Add-Bw24mGateResult {
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

function Test-Bw24mMaterialCharacterizationReceipt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Receipt
    )

    $gates = [System.Collections.Generic.List[object]]::new()
    $engine = Get-Bw24mMapValue $Receipt "engine" @{}
    $enginePassed = (
        [string](Get-Bw24mMapValue $engine "operating_system_family" "") -ceq
            "windows" -and
        [string](Get-Bw24mMapValue $engine "physics_engine" "") -ceq
            "Jolt Physics" -and
        [string](Get-Bw24mMapValue $engine "godot_version" "") -ceq
            $script:Bw24mGodotVersion -and
        [string](Get-Bw24mMapValue $engine "godot_runtime_version" "") -ceq
            $script:Bw24mGodotRuntimeVersion -and
        [string](Get-Bw24mMapValue (
            $engine
        ) "godot_launcher_executable_sha256" "") -ceq
            $script:Bw24mGodotLauncherSha256 -and
        [string](Get-Bw24mMapValue (
            $engine
        ) "godot_runtime_executable_sha256" "") -ceq
            $script:Bw24mGodotRuntimeSha256 -and
        [int](Get-Bw24mMapValue $engine "physics_hz" -1) -eq 120 -and
        [int](Get-Bw24mMapValue $engine "solver_velocity_steps" -1) -eq 20 -and
        [int](Get-Bw24mMapValue $engine "solver_position_steps" -1) -eq 7
    )
    Add-Bw24mGateResult $gates 1 "engine_identity" $enginePassed `
        "BW24M_ENGINE_IDENTITY"

    $observerPassed = [bool](Get-Bw24mMapValue (
        $Receipt
    ) "observer_profile_executable" $false)
    Add-Bw24mGateResult $gates 2 "observer_profile" $observerPassed `
        "BW24M_OBSERVER_PROFILE"

    $invalid = Get-Bw24mMapValue $Receipt "invalid_value_control" @{}
    $invalidPassed = (
        [bool](Get-Bw24mMapValue $invalid "rejected" $false) -and
        [string](Get-Bw24mMapValue $invalid "failure_code" "") -ceq
            "SDK_FRICTION_LADDER_VALUE_INVALID" -and
        (Test-Bw24mNear (
            Get-Bw24mMapValue $invalid "attempted_friction"
        ) 0.25)
    )
    Add-Bw24mGateResult $gates 3 "invalid_value_control" $invalidPassed `
        "BW24M_INVALID_VALUE_CONTROL"

    $frictionless = Get-Bw24mMapValue $Receipt "frictionless_control" @{}
    $frictionlessStage = Get-Bw24mMapValue $frictionless "stage" @{}
    $frictionlessPassed = (
        [bool](Get-Bw24mMapValue $frictionless "ok" $false) -and
        [string](Get-Bw24mMapValue $frictionless "failure_code" "x") -ceq "" -and
        [int](Get-Bw24mMapValue $frictionless "world_build_count" -1) -eq 1 -and
        [string](Get-Bw24mMapValue $frictionless "classification" "") -ceq
            "SLIDING" -and
        (Test-Bw24mMaterialContract (
            Get-Bw24mMapValue $frictionless "material_contract"
        ) 0.0) -and
        (Test-Bw24mFinite (
            Get-Bw24mMapValue $frictionlessStage "max_slip_speed_mps"
        )) -and
        [double](Get-Bw24mMapValue (
            $frictionlessStage
        ) "max_slip_speed_mps" -1.0) -ge 0.05 -and
        (Test-Bw24mFinite (
            Get-Bw24mMapValue $frictionlessStage "tangential_displacement_m"
        )) -and
        [double](Get-Bw24mMapValue (
            $frictionlessStage
        ) "tangential_displacement_m" -1.0) -ge 0.01
    )
    Add-Bw24mGateResult $gates 4 "frictionless_control" `
        $frictionlessPassed "BW24M_FRICTIONLESS_CONTROL"

    $cells = @(Get-Bw24mMapValue $Receipt "positive_cells" @())
    $recomputedCells = [System.Collections.Generic.List[object]]::new()
    $nextOrdinal = 5
    for ($cellIndex = 0; $cellIndex -lt 3; $cellIndex += 1) {
        $expectedFriction = [double]$script:Bw24mValues[$cellIndex]
        $cell = if ($cellIndex -lt $cells.Count) { $cells[$cellIndex] } else { @{} }
        $replicates = @(Get-Bw24mMapValue $cell "replicates" @())
        $lowerForces = [System.Collections.Generic.List[double]]::new()
        $upperForces = [System.Collections.Generic.List[double]]::new()
        $lowerRatios = [System.Collections.Generic.List[double]]::new()

        for ($replicateIndex = 0; $replicateIndex -lt 3; $replicateIndex += 1) {
            $replicate = if ($replicateIndex -lt $replicates.Count) {
                $replicates[$replicateIndex]
            } else { @{} }
            $lower = Get-Bw24mMapValue $replicate "breakaway_force_lower_n"
            $upper = Get-Bw24mMapValue $replicate "breakaway_force_upper_n"
            $lowerRatio = Get-Bw24mMapValue $replicate "empirical_static_ratio_lower"
            $upperRatio = Get-Bw24mMapValue $replicate "empirical_static_ratio_upper"
            $firstSliding = Get-Bw24mMapValue $replicate "first_sliding_stage" @{}
            $secondSliding = Get-Bw24mMapValue $replicate "second_sliding_stage" @{}
            $analysis = Get-Bw24mMapValue $replicate "breakaway_analysis" @{}
            $replicatePassed = (
                $replicates.Count -eq 3 -and
                [bool](Get-Bw24mMapValue $replicate "ok" $false) -and
                [string](Get-Bw24mMapValue $replicate "failure_code" "x") -ceq "" -and
                (Test-Bw24mNear (
                    Get-Bw24mMapValue $replicate "friction"
                ) $expectedFriction 1.0e-9) -and
                [int](Get-Bw24mMapValue $replicate "replicate_index" -1) -eq
                    ($replicateIndex + 1) -and
                [int](Get-Bw24mMapValue $replicate "world_build_count" -1) -eq 1 -and
                (Test-Bw24mMaterialContract (
                    Get-Bw24mMapValue $replicate "material_contract"
                ) $expectedFriction) -and
                [bool](Get-Bw24mMapValue $analysis "ok" $false) -and
                [bool](Get-Bw24mMapValue $analysis "breakaway_detected" $false) -and
                [bool](Get-Bw24mMapValue (
                    $replicate
                ) "all_stage_observations_complete" $false) -and
                [bool](Get-Bw24mMapValue (
                    $replicate
                ) "positive_force_held_observed" $false) -and
                [bool](Get-Bw24mMapValue (
                    $replicate
                ) "two_consecutive_sliding_stages_observed" $false) -and
                (Test-Bw24mFinite $lower) -and
                (Test-Bw24mFinite $upper) -and
                [double]$upper -gt [double]$lower -and
                ([double]$upper - [double]$lower) -le
                    ($script:Bw24mMaximumBracketWidthN + 1.0e-9) -and
                (Test-Bw24mFinite $lowerRatio) -and
                (Test-Bw24mFinite $upperRatio) -and
                [double]$lowerRatio -gt 0.0 -and
                [double]$upperRatio -gt [double]$lowerRatio -and
                (Test-Bw24mFinite (
                    Get-Bw24mMapValue $firstSliding "max_body_tilt_rad"
                )) -and
                [double](Get-Bw24mMapValue (
                    $firstSliding
                ) "max_body_tilt_rad" 1.0) -lt
                    $script:Bw24mMaximumSlidingTiltRad -and
                (Test-Bw24mFinite (
                    Get-Bw24mMapValue $secondSliding "max_body_tilt_rad"
                )) -and
                [double](Get-Bw24mMapValue (
                    $secondSliding
                ) "max_body_tilt_rad" 1.0) -lt
                    $script:Bw24mMaximumSlidingTiltRad
            )
            Add-Bw24mGateResult $gates $nextOrdinal (
                "mu{0:D3}_replicate_{1}" -f
                [int][math]::Round($expectedFriction * 100.0),
                ($replicateIndex + 1)
            ) $replicatePassed "BW24M_REPLICATE_GATE"
            $nextOrdinal += 1
            if (
                (Test-Bw24mFinite $lower) -and
                (Test-Bw24mFinite $upper) -and
                (Test-Bw24mFinite $lowerRatio)
            ) {
                $lowerForces.Add([double]$lower)
                $upperForces.Add([double]$upper)
                $lowerRatios.Add([double]$lowerRatio)
            }
        }

        $firstSpread = if ($upperForces.Count -eq 3) {
            ($upperForces | Measure-Object -Maximum).Maximum -
                ($upperForces | Measure-Object -Minimum).Minimum
        } else { [double]::PositiveInfinity }
        $lowerSpread = if ($lowerForces.Count -eq 3) {
            ($lowerForces | Measure-Object -Maximum).Maximum -
                ($lowerForces | Measure-Object -Minimum).Minimum
        } else { [double]::PositiveInfinity }
        $minimumLowerForce = if ($lowerForces.Count -eq 3) {
            ($lowerForces | Measure-Object -Minimum).Minimum
        } else { [double]::NaN }
        $minimumLowerRatio = if ($lowerRatios.Count -eq 3) {
            ($lowerRatios | Measure-Object -Minimum).Minimum
        } else { [double]::NaN }
        $expectedControllerMu = if (Test-Bw24mFinite $minimumLowerRatio) {
            [math]::Min(
                1.0,
                [math]::Floor(100.0 * $minimumLowerRatio) / 100.0
            )
        } else { [double]::NaN }
        $reportedCoefficient = Get-Bw24mMapValue (
            $cell
        ) "coefficient_derivation" @{}
        $cellPassed = (
            $cell -is [System.Collections.IDictionary] -and
            [bool](Get-Bw24mMapValue $cell "ok" $false) -and
            [string](Get-Bw24mMapValue $cell "failure_code" "x") -ceq "" -and
            (Test-Bw24mNear (
                Get-Bw24mMapValue $cell "authored_friction"
            ) $expectedFriction 1.0e-9) -and
            $replicates.Count -eq 3 -and
            $lowerForces.Count -eq 3 -and
            $firstSpread -le ($script:Bw24mMaximumForceSpreadN + 1.0e-9) -and
            $lowerSpread -le ($script:Bw24mMaximumForceSpreadN + 1.0e-9) -and
            (Test-Bw24mNear (
                Get-Bw24mMapValue $cell "first_sliding_force_spread_n"
            ) $firstSpread 1.0e-9) -and
            (Test-Bw24mNear (
                Get-Bw24mMapValue $cell "lower_breakaway_force_spread_n"
            ) $lowerSpread 1.0e-9) -and
            (Test-Bw24mNear (
                Get-Bw24mMapValue $cell "minimum_lower_breakaway_force_n"
            ) $minimumLowerForce 1.0e-9) -and
            (Test-Bw24mNear (
                Get-Bw24mMapValue $cell "minimum_lower_empirical_ratio"
            ) $minimumLowerRatio 1.0e-12) -and
            [bool](Get-Bw24mMapValue $reportedCoefficient "ok" $false) -and
            [string](Get-Bw24mMapValue (
                $reportedCoefficient
            ) "failure_code" "x") -ceq "" -and
            [string](Get-Bw24mMapValue (
                $reportedCoefficient
            ) "rounding_rule" "") -ceq
                "min(1.0,floor(100*minimum_lower_ratio)/100)" -and
            (Test-Bw24mNear (
                Get-Bw24mMapValue $reportedCoefficient "minimum_lower_ratio"
            ) $minimumLowerRatio 1.0e-12) -and
            (Test-Bw24mNear (
                Get-Bw24mMapValue $reportedCoefficient "controller_mu"
            ) $expectedControllerMu 1.0e-12) -and
            $expectedControllerMu -gt 0.0 -and
            $expectedControllerMu -le 1.0 -and
            -not [bool](Get-Bw24mMapValue (
                $reportedCoefficient
            ) "cross_engine_equivalent" $true) -and
            -not [bool](Get-Bw24mMapValue (
                $reportedCoefficient
            ) "locomotion_robustness" $true)
        )
        Add-Bw24mGateResult $gates $nextOrdinal (
            "mu{0:D3}_cell" -f
            [int][math]::Round($expectedFriction * 100.0)
        ) $cellPassed "BW24M_CELL_GATE"
        $nextOrdinal += 1
        $recomputedCells.Add([ordered]@{
            authored_friction = $expectedFriction
            minimum_lower_breakaway_force_n = $minimumLowerForce
            minimum_lower_empirical_ratio = $minimumLowerRatio
            controller_mu = $expectedControllerMu
            passed = $cellPassed
        })
    }

    $monotonicity = Get-Bw24mMapValue $Receipt "monotonicity" @{}
    $monotonicityPassed = (
        $recomputedCells.Count -eq 3 -and
        [bool](Get-Bw24mMapValue $monotonicity "ok" $false) -and
        @(Get-Bw24mMapValue $monotonicity "violations" @()).Count -eq 0 -and
        (Test-Bw24mNear (
            Get-Bw24mMapValue $monotonicity "maximum_force_decrease_n"
        ) $script:Bw24mMaximumMonotonicForceDecreaseN) -and
        (Test-Bw24mNear (
            Get-Bw24mMapValue $monotonicity "maximum_ratio_decrease"
        ) $script:Bw24mMaximumMonotonicRatioDecrease)
    )
    for ($index = 1; $index -lt $recomputedCells.Count; $index += 1) {
        $previous = $recomputedCells[$index - 1]
        $current = $recomputedCells[$index]
        $monotonicityPassed = (
            $monotonicityPassed -and
            [double]$current.minimum_lower_breakaway_force_n -ge
                ([double]$previous.minimum_lower_breakaway_force_n -
                    $script:Bw24mMaximumMonotonicForceDecreaseN) -and
            [double]$current.minimum_lower_empirical_ratio -ge
                ([double]$previous.minimum_lower_empirical_ratio -
                    $script:Bw24mMaximumMonotonicRatioDecrease)
        )
    }
    Add-Bw24mGateResult $gates 17 "operational_monotonicity" `
        $monotonicityPassed "BW24M_MONOTONICITY"

    $coefficientsPassed = (
        $recomputedCells.Count -eq 3 -and
        @($recomputedCells | Where-Object {
            -not [bool]$_.passed -or
            -not (Test-Bw24mFinite $_.controller_mu) -or
            [double]$_.controller_mu -le 0.0 -or
            [double]$_.controller_mu -gt 1.0
        }).Count -eq 0
    )
    Add-Bw24mGateResult $gates 18 "profile_coefficient_derivation" `
        $coefficientsPassed "BW24M_COEFFICIENT_DERIVATION"

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
            -not [bool](Get-Bw24mMapValue $Receipt $field $true)
        )
    }
    Add-Bw24mGateResult $gates 19 "negative_claim_boundary" $claimsPassed `
        "BW24M_CLAIM_INFLATION"

    $fixture = Get-Bw24mMapValue $Receipt "fixture" @{}
    $reportedValues = @(Get-Bw24mMapValue $fixture "positive_friction_values" @())
    $authoredValues = @(Get-Bw24mMapValue $fixture "authored_friction_values" @())
    $fixtureValuesExact = (
        [string](Get-Bw24mMapValue $fixture "fixture_id" "") -ceq
            $script:Bw24mFixtureId -and
        $reportedValues.Count -eq 3 -and
        $authoredValues.Count -eq 4 -and
        (Test-Bw24mNear $authoredValues[0] 0.0)
    )
    for ($index = 0; $index -lt 3; $index += 1) {
        $fixtureValuesExact = (
            $fixtureValuesExact -and
            (Test-Bw24mNear (
                $reportedValues[$index]
            ) $script:Bw24mValues[$index]) -and
            (Test-Bw24mNear (
                $authoredValues[$index + 1]
            ) $script:Bw24mValues[$index])
        )
    }
    $fixtureExact = (
        $fixtureValuesExact -and
        (Test-Bw24mNear (
            Get-Bw24mMapValue $fixture "frictionless_force_n"
        ) 2.0) -and
        [int](Get-Bw24mMapValue $fixture "settle_ticks" -1) -eq 180 -and
        [int](Get-Bw24mMapValue $fixture "stage_ticks" -1) -eq 60 -and
        [int](Get-Bw24mMapValue $fixture "analysis_ticks" -1) -eq 30 -and
        [string](Get-Bw24mMapValue $fixture "force_application" "") -ceq
            "RigidBody3D.apply_central_force_once_per_tick" -and
        [string](Get-Bw24mMapValue $fixture "stopping_rule" "") -ceq
            "stop_after_two_consecutive_completed_sliding_stages" -and
        -not [bool](Get-Bw24mMapValue $fixture "hidden_rotation_constraint" $true) -and
        -not [bool](Get-Bw24mMapValue $fixture "hidden_damping" $true)
    )
    $metaExact = (
        [string](Get-Bw24mMapValue $Receipt "schema_version" "") -ceq
            $script:Bw24mSchema -and
        [bool](Get-Bw24mMapValue $Receipt "ok" $false) -and
        [int](Get-Bw24mMapValue $Receipt "passed_gate_count" -1) -eq 19 -and
        [int](Get-Bw24mMapValue $Receipt "failed_gate_count" -1) -eq 0 -and
        [int](Get-Bw24mMapValue $Receipt "expected_gate_count" -1) -eq 19 -and
        [int](Get-Bw24mMapValue $Receipt "expected_world_count" -1) -eq 10 -and
        [int](Get-Bw24mMapValue $Receipt "observed_world_count" -1) -eq 10 -and
        $cells.Count -eq 3 -and
        $fixtureExact -and
        -not [bool](Get-Bw24mMapValue $Receipt "development_data_only" $true) -and
        [bool](Get-Bw24mMapValue $Receipt "cold_characterization" $false)
    )
    $failedGates = @($gates | Where-Object { -not [bool]$_.passed })
    $failureCodes = @(
        $failedGates | ForEach-Object { [string]$_.failure_code }
    )
    if (-not $metaExact) {
        $failureCodes += "BW24M_RECEIPT_META_INTEGRITY"
    }
    $failureCodes = @($failureCodes | Select-Object -Unique)

    return [ordered]@{
        schema_version = "sporespore_balanced_wave_bw24m_gate_evaluation_v1"
        ok = $failureCodes.Count -eq 0
        expected_gate_count = 19
        reconstructed_passed_gate_count = 19 - $failedGates.Count
        reconstructed_failed_gate_count = $failedGates.Count
        receipt_meta_integrity_passed = $metaExact
        fixture_identity_and_matrix_passed = $fixtureExact
        expected_world_count = 10
        observed_world_count = [int](Get-Bw24mMapValue (
            $Receipt
        ) "observed_world_count" -1)
        gates = $gates.ToArray()
        cells = $recomputedCells.ToArray()
        failure_codes = $failureCodes
        claims_remain_bounded = $claimsPassed
        physical_acceptance_authority = $false
    }
}

function New-Bw24mMaterialContract {
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
        authored_value_outside_documented_range = $false
        portable_material_coefficient = $false
        locomotion_robustness = $false
    }
}

function New-Bw24mPerfectSyntheticCharacterizationReceipt {
    [CmdletBinding()]
    param()

    $minimumForces = @(22.0, 27.0, 32.0)
    $minimumRatios = @(0.56, 0.68, 0.80)
    $cells = [System.Collections.Generic.List[object]]::new()
    for ($cellIndex = 0; $cellIndex -lt 3; $cellIndex += 1) {
        $friction = [double]$script:Bw24mValues[$cellIndex]
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
                material_contract = New-Bw24mMaterialContract $friction
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
                first_sliding_stage = [ordered]@{ max_body_tilt_rad = 0.01 }
                second_sliding_stage = [ordered]@{ max_body_tilt_rad = 0.01 }
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
                rounding_rule = "min(1.0,floor(100*minimum_lower_ratio)/100)"
                documented_godot_maximum_cap = 1.0
                controller_mu = $controllerMu
                cross_engine_equivalent = $false
                locomotion_robustness = $false
            }
        })
    }

    return [ordered]@{
        schema_version = $script:Bw24mSchema
        ok = $true
        passed_gate_count = 19
        failed_gate_count = 0
        expected_gate_count = 19
        engine = [ordered]@{
            operating_system_family = "windows"
            physics_engine = "Jolt Physics"
            godot_version = $script:Bw24mGodotVersion
            godot_runtime_version = $script:Bw24mGodotRuntimeVersion
            godot_launcher_executable_sha256 = $script:Bw24mGodotLauncherSha256
            godot_runtime_executable_sha256 = $script:Bw24mGodotRuntimeSha256
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
            fixture_id = $script:Bw24mFixtureId
            authored_friction_values = @(0.0, 0.59, 0.71, 0.83)
            positive_friction_values = $script:Bw24mValues
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
        expected_world_count = 10
        observed_world_count = 10
        frictionless_control = [ordered]@{
            ok = $true
            failure_code = ""
            world_build_count = 1
            classification = "SLIDING"
            material_contract = New-Bw24mMaterialContract 0.0
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
