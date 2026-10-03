#requires -Version 7.0

[CmdletBinding()]
param(
    [switch]$SkipRetainedWalkingEvidence
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))

function Assert-ThresholdProvenance {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-ThresholdProvenanceSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Assert-ThresholdProvenanceSource {
    param(
        [Parameter(Mandatory)][string]$RelativePath,
        [Parameter(Mandatory)][string]$ExpectedSha256
    )
    $path = Join-Path $repoRoot $RelativePath
    Assert-ThresholdProvenance (Test-Path -LiteralPath $path -PathType Leaf) (
        "Threshold-provenance source is missing: $RelativePath"
    )
    Assert-ThresholdProvenance (
        (Get-ThresholdProvenanceSha256 $path) -ceq $ExpectedSha256
    ) "Threshold-provenance source bytes changed: $RelativePath"
    return $path
}

function Assert-ThresholdProvenanceNumber {
    param(
        [Parameter(Mandatory)][double]$Actual,
        [Parameter(Mandatory)][double]$Expected,
        [Parameter(Mandatory)][string]$Label
    )
    Assert-ThresholdProvenance (
        [Math]::Abs($Actual - $Expected) -le 1e-15
    ) "$Label changed: expected $Expected, observed $Actual"
}

$r23d10Path = Assert-ThresholdProvenanceSource `
    -RelativePath "sdk/turning/r23d10_quiescent_taper_preregistration_v1.json" `
    -ExpectedSha256 "sha256:8a367a311b1133737037900bb0922f14a3c31d0e3f063fc39bb2fc554f263b3b"
$r23d12Path = Assert-ThresholdProvenanceSource `
    -RelativePath "sdk/turning/r23d12_physical_closure_v1.json" `
    -ExpectedSha256 "sha256:853abeea25229621136323842ac6e6b989f42f3de375d869968cd371f7df7143"
$r23d13Path = Assert-ThresholdProvenanceSource `
    -RelativePath "sdk/turning/r23d13_physical_closure_v1.json" `
    -ExpectedSha256 "sha256:c5d465d20a958b3e5968221a038ab328ceca1688c4db530a68f4816f6c98738a"
$bw19vPath = Assert-ThresholdProvenanceSource `
    -RelativePath "sdk/balanced_wave_bw19v_closure_manifest.json" `
    -ExpectedSha256 "sha256:ea8df6a574e1b9be1050afa8ed57982a102982ada0f0d5babccf3c937c7067f7"
$mujocoMv6Path = Assert-ThresholdProvenanceSource `
    -RelativePath "sdk/mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv6_closure.json" `
    -ExpectedSha256 "sha256:5da3675d848c1d127419c43f009fb430c4f02abd2a55da730ea70fca6d3cee09"
$rapierPh1Path = Assert-ThresholdProvenanceSource `
    -RelativePath "sdk/rapier_c6_bw19v_velocity_only_pose_hold_restoration_ph1_closure.json" `
    -ExpectedSha256 "sha256:e2fd42545d59908db69f9fe34a18453afafe4273a02618be0b531f6443e040db"

$r23d10 = Get-Content -Raw -LiteralPath $r23d10Path | ConvertFrom-Json
$predecessor = $r23d10.declared_use_of_predecessor_data
$numeric = $r23d10.numeric_derivation
Assert-ThresholdProvenanceNumber `
    ([double]$predecessor.r23d9_positive_last_30_support_maximum_torso_tilt_rad) `
    0.0046328184846318905 "R23D9 stable-arm tilt calibration"
Assert-ThresholdProvenanceNumber `
    ([double]$predecessor.r23d9_negative_last_30_support_minimum_torso_tilt_rad) `
    0.02392804760050467 "R23D9 unstable-arm tilt calibration"
Assert-ThresholdProvenanceNumber `
    ([double]$predecessor.r23d9_positive_last_30_support_maximum_joint_position_error_rad) `
    0.17540983309682578 "R23D9 stable-arm joint calibration"
Assert-ThresholdProvenanceNumber `
    ([double]$predecessor.r23d9_negative_last_30_support_minimum_joint_position_error_rad) `
    0.26349168895154307 "R23D9 unstable-arm joint calibration"
Assert-ThresholdProvenanceNumber `
    ([double]$numeric.tight_maximum_torso_tilt_rad.value) 0.01 `
    "R23D10 tight tilt threshold"
Assert-ThresholdProvenanceNumber `
    ([double]$numeric.tight_maximum_joint_position_error_rad.value) 0.2 `
    "R23D10 tight joint-error threshold"
Assert-ThresholdProvenance (
    0.0046328184846318905 -lt 0.01 -and
    0.01 -lt 0.02392804760050467 -and
    0.17540983309682578 -lt 0.2 -and
    0.2 -lt 0.26349168895154307 -and
    [string]$numeric.tight_maximum_torso_tilt_rad.basis -match "Strictly between" -and
    [string]$numeric.tight_maximum_joint_position_error_rad.basis -match "Strictly between"
) "R23D10 no longer prospectively separates stable and unstable R23D9 windows"

$r23d12 = Get-Content -Raw -LiteralPath $r23d12Path | ConvertFrom-Json
$r23d13 = Get-Content -Raw -LiteralPath $r23d13Path | ConvertFrom-Json
$d12Positive = @($r23d12.retained_stage_a_cells | Where-Object arm_id -ceq "positive_heading")[0]
$d12Negative = @($r23d12.retained_stage_a_cells | Where-Object arm_id -ceq "negative_heading")[0]
$d13Positive = @($r23d13.retained_stage_a_cells | Where-Object arm_id -ceq "positive_heading")[0]
$d13Negative = @($r23d13.retained_stage_a_cells | Where-Object arm_id -ceq "negative_heading")[0]

Assert-ThresholdProvenanceNumber ([double]$d12Positive.minimum_active_tilt_rad) `
    0.001040764142985916 "R23D12 positive minimum active tilt"
Assert-ThresholdProvenanceNumber ([double]$d12Positive.minimum_active_joint_position_error_rad) `
    0.04242439355597014 "R23D12 positive minimum active joint error"
Assert-ThresholdProvenanceNumber ([double]$d12Negative.minimum_active_tilt_rad) `
    0.02039827933466296 "R23D12 negative minimum active tilt"
Assert-ThresholdProvenanceNumber ([double]$d12Negative.minimum_active_joint_position_error_rad) `
    0.2375508558310486 "R23D12 negative minimum active joint error"
Assert-ThresholdProvenanceNumber ([double]$d13Positive.minimum_active_tilt_rad) `
    0.001040764142985916 "R23D13 positive minimum active tilt"
Assert-ThresholdProvenanceNumber ([double]$d13Positive.minimum_active_joint_position_error_rad) `
    0.042424393555970066 "R23D13 positive minimum active joint error"
Assert-ThresholdProvenanceNumber ([double]$d13Negative.minimum_active_tilt_rad) `
    0.017080407913174254 "R23D13 negative minimum active tilt"
Assert-ThresholdProvenanceNumber ([double]$d13Negative.minimum_active_joint_position_error_rad) `
    0.20794296329907377 "R23D13 negative minimum active joint error"
Assert-ThresholdProvenance (
    [bool]$d12Positive.walking_and_taper_gate_passed -and
    -not [bool]$d12Negative.walking_and_taper_gate_passed -and
    [bool]$d13Positive.walking_and_taper_gate_passed -and
    -not [bool]$d13Negative.walking_and_taper_gate_passed -and
    [double]$d13Negative.minimum_active_tilt_rad -lt [double]$d12Negative.minimum_active_tilt_rad -and
    [double]$d13Negative.minimum_active_joint_position_error_rad -lt [double]$d12Negative.minimum_active_joint_position_error_rad -and
    [double]$d13Negative.minimum_active_tilt_rad -gt 0.01 -and
    [double]$d13Negative.minimum_active_joint_position_error_rad -gt 0.2 -and
    [int]$d13Negative.tight_pose_satisfied_row_count -eq 0 -and
    [int]$d13Negative.post_handoff_contact_loss_step_count -eq 43
) "R23D12/R23D13 discriminant or immutable outcomes changed"

$mujocoMv6 = Get-Content -Raw -LiteralPath $mujocoMv6Path | ConvertFrom-Json
$rapierPh1 = Get-Content -Raw -LiteralPath $rapierPh1Path | ConvertFrom-Json
Assert-ThresholdProvenance (
    [bool]$mujocoMv6.frozen_primary_result.required_360_step_hold_completed -and
    [bool]$mujocoMv6.frozen_primary_result.finite_single_body_walking_contract_passed -and
    [double]$mujocoMv6.frozen_primary_result.metrics.maximum_tilt_rad -gt 0.01 -and
    [bool]$rapierPh1.posthoc_diagnostic_result.pose_hold_restoration_gate_passed -and
    [bool]$rapierPh1.posthoc_diagnostic_result.finite_walking_contract_passed -and
    [double]$rapierPh1.physical_observations.maximum_tilt_rad -gt 0.01 -and
    -not [bool]$mujocoMv6.claims.cross_engine_selected_policy_equivalence -and
    -not [bool]$rapierPh1.claims.cross_engine_selected_policy_equivalence
) "Active pose-hold evidence no longer has the bounded non-equivalence disposition"

$walkingCount = 0
$walkingAtOrBelowThresholdCount = 0
$walkingFinalTiltMinimum = [double]::NaN
$walkingFinalTiltMedian = [double]::NaN
$walkingFinalTiltMaximum = [double]::NaN
$positiveFirstCoarseActiveIndex = -1
$positiveFirstTightActiveIndex = -1
$negativeFirstCoarseActiveIndex = -1
$negativeFirstTaperActiveIndex = -1
$negativeFirstFloorDominantActiveIndex = -1
if (-not $SkipRetainedWalkingEvidence) {
    $bw19v = Get-Content -Raw -LiteralPath $bw19vPath | ConvertFrom-Json
    $candidate = @(
        $bw19v.complete_attempt.candidate_reports |
            Where-Object candidate_id -ceq "BW19V-B"
    )[0]
    Assert-ThresholdProvenance (
        [int]$candidate.walking_conjunction_pass_count -eq 33 -and
        [int]$candidate.walking_conjunction_failure_count -eq 3 -and
        [bool]$bw19v.scientific_disposition.broad_walking_acceptance_not_established
    ) "BW19V-B finite walking disposition changed"
    Assert-ThresholdProvenance (
        (Get-ThresholdProvenanceSha256 $candidate.path) -ceq (
            "sha256:" + [string]$candidate.sha256
        )
    ) "BW19V-B retained report bytes do not match the closure"

    $report = Get-Content -Raw -LiteralPath $candidate.path | ConvertFrom-Json
    $walking = @($report.results | Where-Object walking_observed)
    $finalTilts = @()
    foreach ($cell in $walking) {
        Assert-ThresholdProvenance (
            (Get-ThresholdProvenanceSha256 $cell.engine_log_path) -ceq (
                [string]$cell.engine_log_sha256
            )
        ) "BW19V-B engine-log bytes do not match the retained report"
        $lastWaveLine = @(
            Get-Content -LiteralPath $cell.engine_log_path |
                Where-Object { $_ -match "\bwave_tick=" }
        ) | Select-Object -Last 1
        Assert-ThresholdProvenance (
            $null -ne $lastWaveLine -and
            $lastWaveLine -match "\btilt=(?<tilt>[0-9]+(?:\.[0-9]+)?)\b"
        ) "BW19V-B walking engine log has no parseable final sampled tilt"
        $finalTilts += [double]$Matches.tilt
    }

    $sortedTilts = @($finalTilts | Sort-Object)
    $walkingCount = $sortedTilts.Count
    $walkingAtOrBelowThresholdCount = @(
        $sortedTilts | Where-Object { $_ -le 0.01 }
    ).Count
    $walkingFinalTiltMinimum = [double]$sortedTilts[0]
    $walkingFinalTiltMedian = [double]$sortedTilts[16]
    $walkingFinalTiltMaximum = [double]$sortedTilts[-1]
    Assert-ThresholdProvenance (
        $walkingCount -eq 33 -and
        $walkingAtOrBelowThresholdCount -eq 33 -and
        $walkingFinalTiltMinimum -eq 0.0 -and
        $walkingFinalTiltMedian -eq 0.000772 -and
        $walkingFinalTiltMaximum -eq 0.001859
    ) "BW19V-B accepted-walker final sampled tilt characterization changed"

    $traceRoot = Join-Path ([string]$r23d13.attempt.attempt_root) "traces"
    $positiveTrace = Join-Path $traceRoot (
        "mujoco_residual_pose_authority_screen__" +
        "mujoco__residual_pose_authority__positive_heading.ndjson"
    )
    $negativeTrace = Join-Path $traceRoot (
        "mujoco_residual_pose_authority_screen__" +
        "mujoco__residual_pose_authority__negative_heading.ndjson"
    )
    Assert-ThresholdProvenance (
        (Get-ThresholdProvenanceSha256 $positiveTrace) -ceq
            [string]$d13Positive.trace_raw_sha256 -and
        (Get-ThresholdProvenanceSha256 $negativeTrace) -ceq
            [string]$d13Negative.trace_raw_sha256
    ) "R23D13 retained trace bytes do not match the immutable closure"
    $positiveTerminal = @(
        Get-Content -LiteralPath $positiveTrace -Tail 900 |
            ForEach-Object { $_ | ConvertFrom-Json }
    )
    $negativeTerminal = @(
        Get-Content -LiteralPath $negativeTrace -Tail 900 |
            ForEach-Object { $_ | ConvertFrom-Json }
    )
    $positiveActive = @($positiveTerminal | Where-Object {
        -not [bool]$_.zero_actuation
    })
    $negativeActive = @($negativeTerminal | Where-Object {
        -not [bool]$_.zero_actuation
    })
    $positiveFirstCoarseActiveIndex = [int](
        0..($positiveActive.Count - 1) | Where-Object {
            [bool]$positiveActive[$_].coarse_pose_satisfied
        } | Select-Object -First 1
    )
    $positiveFirstTightActiveIndex = [int](
        0..($positiveActive.Count - 1) | Where-Object {
            [bool]$positiveActive[$_].tight_pose_satisfied
        } | Select-Object -First 1
    )
    $negativeFirstCoarseActiveIndex = [int](
        0..($negativeActive.Count - 1) | Where-Object {
            [bool]$negativeActive[$_].coarse_pose_satisfied
        } | Select-Object -First 1
    )
    $negativeFirstTaperActiveIndex = [int](
        0..($negativeActive.Count - 1) | Where-Object {
            [string]$negativeActive[$_].phase_id -ceq
                "terminal_quiescent_taper"
        } | Select-Object -First 1
    )
    $negativeFirstFloorDominantActiveIndex = [int](
        0..($negativeActive.Count - 1) | Where-Object {
            [int]$negativeActive[$_].pose_authority_floor_numerator -gt
                [int]$negativeActive[$_].temporal_scale_numerator
        } | Select-Object -First 1
    )
    Assert-ThresholdProvenance (
        $positiveActive.Count -eq 439 -and
        $positiveFirstCoarseActiveIndex -eq 318 -and
        $positiveFirstTightActiveIndex -eq 318 -and
        $negativeActive.Count -eq 540 -and
        $negativeFirstCoarseActiveIndex -eq 339 -and
        $negativeFirstTaperActiveIndex -eq 340 -and
        $negativeFirstFloorDominantActiveIndex -eq 407 -and
        @($negativeActive | Where-Object tight_pose_satisfied).Count -eq 0
    ) "R23D13 retained taper-transition diagnosis changed"
}

Write-Host (
    "TERMINAL_HANDOFF_THRESHOLD_PROVENANCE_PASS " +
    "tilt_threshold=0.01 joint_threshold=0.2 calibrated=True " +
    "r23d13_negative_tilt=0.017080407913174254 " +
    "r23d13_negative_joint_error=0.20794296329907377 " +
    "bw19v_walking_count=$walkingCount " +
    "bw19v_at_or_below_count=$walkingAtOrBelowThresholdCount " +
    "bw19v_final_tilt_min=$walkingFinalTiltMinimum " +
    "bw19v_final_tilt_median=$walkingFinalTiltMedian " +
    "bw19v_final_tilt_max=$walkingFinalTiltMaximum " +
    "positive_coarse_tight_index=$positiveFirstCoarseActiveIndex " +
    "negative_coarse_index=$negativeFirstCoarseActiveIndex " +
    "negative_taper_index=$negativeFirstTaperActiveIndex " +
    "negative_floor_dominant_index=$negativeFirstFloorDominantActiveIndex " +
    "threshold_rewrite_authorized=False worlds=0"
)
