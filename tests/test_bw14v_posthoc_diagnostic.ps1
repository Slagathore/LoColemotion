#requires -Version 7.0

$ErrorActionPreference = "Stop"
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$diagnosticPath = Join-Path $repoRoot (
    "sdk\balanced_wave_bw14v_posthoc_diagnostic.json"
)

function Assert-True {
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Condition,
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

function Get-Sha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-Mean {
    param([Parameter(Mandatory = $true)][double[]]$Values)
    [double]$sum = 0.0
    foreach ($value in $Values) {
        $sum += $value
    }
    return $sum / $Values.Count
}

function Get-Median {
    param([Parameter(Mandatory = $true)][double[]]$Values)
    $ordered = @($Values | Sort-Object)
    $middle = [int][Math]::Floor($ordered.Count / 2)
    if (($ordered.Count % 2) -eq 1) {
        return [double]$ordered[$middle]
    }
    return (
        [double]$ordered[$middle - 1] +
        [double]$ordered[$middle]
    ) / 2.0
}

function Assert-Near {
    param(
        [Parameter(Mandatory = $true)][double]$Actual,
        [Parameter(Mandatory = $true)][double]$Expected,
        [Parameter(Mandatory = $true)][string]$Message,
        [double]$Tolerance = 1.0e-12
    )
    Assert-True `
        -Condition ([Math]::Abs($Actual - $Expected) -le $Tolerance) `
        -Message "$Message actual=$Actual expected=$Expected"
}

Assert-True (Test-Path -LiteralPath $diagnosticPath) (
    "The BW14V post-hoc diagnostic is missing"
)
$diagnostic = Get-Content -LiteralPath $diagnosticPath -Raw | ConvertFrom-Json
Assert-True (
    [string]$diagnostic.schema_version -ceq
        "sporespore_balanced_wave_bw14v_posthoc_diagnostic_v1" -and
    [string]$diagnostic.status -ceq
        "complete_outcome_exposed_diagnostic_only" -and
    -not [bool]$diagnostic.claim_boundary.candidate_selection_authority -and
    -not [bool]$diagnostic.claim_boundary.walking_acceptance -and
    -not [bool]$diagnostic.claim_boundary.balance_improvement -and
    -not [bool]$diagnostic.claim_boundary.independent_morphology_validation -and
    -not [bool]$diagnostic.claim_boundary.physical_acceptance_authority
) "The BW14V post-hoc diagnostic changed its nonclaim boundary"

$aPath = [string]$diagnostic.source_family.control_report.path
$bPath = [string]$diagnostic.source_family.treatment_report.path
Assert-True (Test-Path -LiteralPath $aPath) "The retained BW14V-A report is missing"
Assert-True (Test-Path -LiteralPath $bPath) "The retained BW14V-B report is missing"
Assert-True (
    (Get-Sha256 $aPath) -ceq
        [string]$diagnostic.source_family.control_report.sha256 -and
    (Get-Sha256 $bPath) -ceq
        [string]$diagnostic.source_family.treatment_report.sha256
) "A retained BW14V report changed bytes"

$aReport = Get-Content -LiteralPath $aPath -Raw | ConvertFrom-Json
$bReport = Get-Content -LiteralPath $bPath -Raw | ConvertFrom-Json
Assert-True (
    $aReport.results.Count -eq 36 -and
    $bReport.results.Count -eq 36
) "The retained BW14V reports no longer contain 36 cells per arm"

$bByKey = @{}
foreach ($row in $bReport.results) {
    $key = "$($row.morphology_id)|$($row.campaign_seed)"
    Assert-True (-not $bByKey.ContainsKey($key)) "Duplicate BW14V-B key: $key"
    $bByKey[$key] = $row
}

$pairs = [System.Collections.Generic.List[object]]::new()
foreach ($aRow in $aReport.results) {
    $key = "$($aRow.morphology_id)|$($aRow.campaign_seed)"
    Assert-True ($bByKey.ContainsKey($key)) "Missing BW14V-B match: $key"
    $bRow = $bByKey[$key]
    $pairs.Add([ordered]@{
        a = $aRow
        b = $bRow
    })
}
Assert-True (
    $pairs.Count -eq [int]$diagnostic.source_family.matched_cell_count
) "The BW14V matched-cell count changed"

$aWalking = 0
$bWalking = 0
$atCap = 0
$atUnitError = 0
$bEvidenceLess = 0
$bEvidenceNegative = 0
$bFinalNegative = 0
$bTiltGreater = 0
$bHeightLower = 0
$bLateralGreater = 0
$bAnyTimeout = 0
[int64]$correctionReceiptCount = 0

$metricValues = [ordered]@{
    evidence_forward_m = [ordered]@{ control = @(); treatment = @() }
    final_forward_m = [ordered]@{ control = @(); treatment = @() }
    absolute_lateral_m = [ordered]@{ control = @(); treatment = @() }
    minimum_torso_height_m = [ordered]@{ control = @(); treatment = @() }
    maximum_tilt_rad = [ordered]@{ control = @(); treatment = @() }
    release_timeouts = [ordered]@{ control = @(); treatment = @() }
}

foreach ($pair in $pairs) {
    $aRow = $pair.a
    $bRow = $pair.b
    if ([bool]$aRow.walking_observed) { $aWalking++ }
    if ([bool]$bRow.walking_observed) { $bWalking++ }

    $mechanism = $bRow.receipt.forward_velocity_foot_placement_summary
    if (
        [Math]::Abs(
            [double]$mechanism.maximum_absolute_hip_target_correction_rad -
            [double]$mechanism.maximum_declared_hip_target_correction_rad
        ) -le 1.0e-12
    ) {
        $atCap++
    }
    if (
        [double]$mechanism.maximum_absolute_normalized_forward_velocity_error -ge
            1.0 - 1.0e-12
    ) {
        $atUnitError++
    }
    $correctionReceiptCount += [int64]$mechanism.receipt_count

    $aEvidence = [double]$aRow.receipt.evidence_task_frame_forward_displacement_m
    $bEvidence = [double]$bRow.receipt.evidence_task_frame_forward_displacement_m
    $aFinal = [double]$aRow.receipt.final_task_frame_forward_displacement_m
    $bFinal = [double]$bRow.receipt.final_task_frame_forward_displacement_m
    $aLateral = [Math]::Abs(
        [double]$aRow.receipt.final_task_frame_lateral_displacement_m
    )
    $bLateral = [Math]::Abs(
        [double]$bRow.receipt.final_task_frame_lateral_displacement_m
    )
    $aHeight = [double]$aRow.receipt.minimum_torso_height_m
    $bHeight = [double]$bRow.receipt.minimum_torso_height_m
    $aTilt = [double]$aRow.receipt.maximum_tilt_rad
    $bTilt = [double]$bRow.receipt.maximum_tilt_rad
    $aTimeouts = [double]$aRow.release_timeout_count
    $bTimeouts = [double]$bRow.release_timeout_count

    if ($bEvidence -lt $aEvidence) { $bEvidenceLess++ }
    if ($bEvidence -lt 0.0) { $bEvidenceNegative++ }
    if ($bFinal -lt 0.0) { $bFinalNegative++ }
    if ($bTilt -gt $aTilt) { $bTiltGreater++ }
    if ($bHeight -lt $aHeight) { $bHeightLower++ }
    if ($bLateral -gt $aLateral) { $bLateralGreater++ }
    if ($bTimeouts -gt 0.0) { $bAnyTimeout++ }

    $metricValues.evidence_forward_m.control += $aEvidence
    $metricValues.evidence_forward_m.treatment += $bEvidence
    $metricValues.final_forward_m.control += $aFinal
    $metricValues.final_forward_m.treatment += $bFinal
    $metricValues.absolute_lateral_m.control += $aLateral
    $metricValues.absolute_lateral_m.treatment += $bLateral
    $metricValues.minimum_torso_height_m.control += $aHeight
    $metricValues.minimum_torso_height_m.treatment += $bHeight
    $metricValues.maximum_tilt_rad.control += $aTilt
    $metricValues.maximum_tilt_rad.treatment += $bTilt
    $metricValues.release_timeouts.control += $aTimeouts
    $metricValues.release_timeouts.treatment += $bTimeouts
}

$counts = $diagnostic.matched_directional_counts
Assert-True (
    $aWalking -eq [int]$diagnostic.source_family.control_walking_count -and
    $bWalking -eq [int]$diagnostic.source_family.treatment_walking_count -and
    $atCap -eq [int]$counts.treatment_reached_declared_correction_cap -and
    $atUnitError -eq [int]$counts.treatment_reached_unit_normalized_error -and
    $bEvidenceLess -eq [int]$counts.treatment_evidence_forward_less_than_control -and
    $bEvidenceNegative -eq [int]$counts.treatment_evidence_forward_negative -and
    $bFinalNegative -eq [int]$counts.treatment_final_forward_negative -and
    $bTiltGreater -eq [int]$counts.treatment_peak_tilt_greater_than_control -and
    $bHeightLower -eq [int]$counts.treatment_minimum_torso_height_lower_than_control -and
    $bLateralGreater -eq
        [int]$counts.treatment_absolute_lateral_displacement_greater_than_control -and
    $bAnyTimeout -eq [int]$counts.treatment_any_release_timeout -and
    $correctionReceiptCount -eq [int64]$counts.treatment_correction_receipt_count
) "A pinned BW14V post-hoc directional count changed"

foreach ($metricName in $metricValues.Keys) {
    [double[]]$controlValues = $metricValues[$metricName].control
    [double[]]$treatmentValues = $metricValues[$metricName].treatment
    [double[]]$deltas = @()
    for ($index = 0; $index -lt $controlValues.Count; $index++) {
        $deltas += $treatmentValues[$index] - $controlValues[$index]
    }
    $expected = $diagnostic.paired_metrics.$metricName
    Assert-Near (Get-Mean $controlValues) ([double]$expected.control_mean) (
        "$metricName control mean changed"
    )
    Assert-Near (Get-Median $controlValues) ([double]$expected.control_median) (
        "$metricName control median changed"
    )
    Assert-Near (Get-Mean $treatmentValues) ([double]$expected.treatment_mean) (
        "$metricName treatment mean changed"
    )
    Assert-Near (Get-Median $treatmentValues) ([double]$expected.treatment_median) (
        "$metricName treatment median changed"
    )
    Assert-Near (Get-Mean $deltas) ([double]$expected.treatment_minus_control_mean) (
        "$metricName paired mean changed"
    )
    Assert-Near (Get-Median $deltas) (
        [double]$expected.treatment_minus_control_median
    ) "$metricName paired median changed"
}

$observedControlFailures = @(
    foreach ($row in $aReport.results | Where-Object { -not $_.walking_observed }) {
        $failedGates = @(
            $row.receipt.walking_gate_receipts.psobject.Properties |
                Where-Object { -not [bool]$_.Value } |
                ForEach-Object { $_.Name }
        )
        Assert-True (
            $failedGates.Count -eq 1
        ) "A retained BW14V control counterexample changed gate cardinality"
        "$($row.generator_index)|$($row.campaign_seed)|$($failedGates[0])"
    }
)
$expectedControlFailures = @(
    foreach ($counterexample in $diagnostic.control_counterexamples) {
        "$($counterexample.generator_index)|" +
        "$($counterexample.campaign_seed)|$($counterexample.failed_gate)"
    }
)
Assert-True (
    (Compare-Object $observedControlFailures $expectedControlFailures).Count -eq 0
) "The BW14V control-counterexample identities changed"

Write-Output (
    "BW14V_POSTHOC_DIAGNOSTIC_PASS pairs=36 control_walking=33 " +
    "treatment_walking=0 saturated=36 reverse_evidence=18 timeouts=31"
)
