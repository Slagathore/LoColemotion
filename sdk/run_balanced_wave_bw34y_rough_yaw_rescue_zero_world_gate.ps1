#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [switch]$SkipGodotActualPath
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$evaluatorPath = Join-Path $sdkRoot "balanced_wave_bw34y_rough_yaw_rescue_gate.ps1"
$supervisorPath = Join-Path $sdkRoot "run_balanced_wave_bw34y_rough_yaw_rescue.ps1"
$declarationAuditPath = Join-Path $repoRoot "tests\test_bw34y_rough_yaw_rescue_declaration.ps1"
$freezeAuditPath = Join-Path $repoRoot "tests\test_bw34y_rough_yaw_rescue_freeze.ps1"
$operationLockPath = Join-Path $sdkRoot "locomotion_operation_lock.ps1"
$preflightPrefix = "BW34Y_ROUGH_YAW_RESCUE_WORKER_PREFLIGHT "
$realShapedPrefix = "BW34Y_ROUGH_YAW_RESCUE_REAL_SHAPED_RECEIPTS "

. $evaluatorPath
. $supervisorPath

function Assert-Bw34yZeroExact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Copy-Bw34yZeroValue {
    param([Parameter(Mandatory)]$Value)
    return $Value | ConvertTo-Json -Depth 64 |
        ConvertFrom-Json -AsHashtable -Depth 64
}

function Invoke-Bw34yZeroEvaluation {
    param([Parameter(Mandatory)][object[]]$Receipts)
    return Invoke-Bw34yRoughYawRescueEvaluation `
        -CellReceipts $Receipts `
        -Source ([ordered]@{
            commit = "synthetic_preflight_no_source_identity"
            worktree_clean = $false
            matches_live_github_main = $false
        }) `
        -AttemptId ("d" * 32)
}

function Set-Bw34yWalkingNegative {
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Receipt)
    $walking = [System.Collections.IDictionary]$Receipt.walking_gate_receipts
    $walking["bounded_lateral_drift"] = $false
    $Receipt.walking_observed = $false
    $Receipt.failed_walking_gate_count = 1
    $Receipt.failure_code = "WALKING_CONJUNCTION_INCOMPLETE_AT_FIXED_HORIZON"
}

function Set-Bw34yWalkingPositive {
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Receipt)
    $walking = [System.Collections.IDictionary]$Receipt.walking_gate_receipts
    foreach ($key in @($walking.Keys)) { $walking[$key] = $true }
    $Receipt.walking_observed = $true
    $Receipt.failed_walking_gate_count = 0
    $Receipt.failure_code = ""
}

function Invoke-Bw34yNegativeControl {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][scriptblock]$Mutation,
        [Parameter(Mandatory)][object[]]$Baseline
    )
    $receipts = @(Copy-Bw34yZeroValue $Baseline)
    & $Mutation ([System.Collections.IDictionary]$receipts[0])
    $evaluation = Invoke-Bw34yZeroEvaluation $receipts
    Assert-Bw34yZeroExact (-not [bool]$evaluation.ok) (
        "BW34Y negative control was accepted: $Name"
    )
    return [ordered]@{ control = $Name; rejected = $true }
}

function Invoke-Bw34yZeroWorldGate {
    foreach ($path in @(
        $evaluatorPath, $supervisorPath, $declarationAuditPath,
        $freezeAuditPath, $operationLockPath
    )) {
        Assert-Bw34yZeroExact (Test-Path -LiteralPath $path -PathType Leaf) (
            "BW34Y zero-world source missing: $path"
        )
    }
    & pwsh -NoLogo -NoProfile -File $declarationAuditPath
    Assert-Bw34yZeroExact ($LASTEXITCODE -eq 0) "BW34Y declaration audit failed"
    & pwsh -NoLogo -NoProfile -File $freezeAuditPath -SkipSupervisorPreflight
    Assert-Bw34yZeroExact ($LASTEXITCODE -eq 0) "BW34Y freeze audit failed"
    if ($SkipGodotActualPath) {
        Write-Host (
            "BW34Y_ZERO_WORLD_SOURCE_PASS actual_path_skipped=True worlds=0 " +
            "outcome_exposed=False physical_authority=False"
        )
        return
    }
    $godotPath = [System.IO.Path]::GetFullPath($Godot)
    Assert-Bw34yZeroExact (Test-Path -LiteralPath $godotPath -PathType Leaf) (
        "BW34Y Godot executable missing: $godotPath"
    )
    $runToken = (Get-Date -Format "yyyyMMddTHHmmssfff") + "-" +
        [Guid]::NewGuid().ToString("N").Substring(0, 8)
    $tempRoot = Join-Path $sdkRoot "target\bw34y-zero-world\$runToken"
    [void][System.IO.Directory]::CreateDirectory($tempRoot)
    $projectRoot = New-Bw34yIsolatedProject $tempRoot
    $entrypoint = Invoke-Bw34yWorkerMode -GodotPath $godotPath `
        -ProjectRoot $projectRoot -TempRoot $tempRoot `
        -Mode "preflight-all" -Prefix $preflightPrefix
    $realShaped = Invoke-Bw34yWorkerMode -GodotPath $godotPath `
        -ProjectRoot $projectRoot -TempRoot $tempRoot `
        -Mode "receipt-preflight-all" -Prefix $realShapedPrefix
    $baseline = @($realShaped.cell_receipts)
    $baselineEvaluation = Invoke-Bw34yZeroEvaluation $baseline
    Assert-Bw34yZeroExact (
        [bool]$baselineEvaluation.ok -and
        [int]$baselineEvaluation.invalid_cell_count -eq 0 -and
        [int]$baselineEvaluation.valid_walking_negative_count -eq 2 -and
        [string]$baselineEvaluation.selected_candidate_id -ceq "NONE"
    ) "BW34Y real-shaped baseline or selector canary failed"
    $coldInputPath = Join-Path $tempRoot "cold-evaluator-input.json"
    $coldOutputPath = Join-Path $tempRoot "cold-evaluator-output.json"
    Write-Bw34yNewJsonArtifact ([ordered]@{
        schema_version = "sporespore_balanced_wave_bw34y_rough_yaw_rescue_evaluation_input_v1"
        attempt_id = "d" * 32
        source = [ordered]@{
            commit = "synthetic_preflight_no_source_identity"
            worktree_clean = $false
            matches_live_github_main = $false
        }
        cell_receipts = $baseline
    }) $coldInputPath
    & pwsh -NoLogo -NoProfile -File $evaluatorPath `
        -InputPath $coldInputPath -OutputPath $coldOutputPath
    Assert-Bw34yZeroExact ($LASTEXITCODE -eq 0) (
        "BW34Y cold evaluator process rejected actual-composer receipts"
    )
    $coldEvaluation = Read-Bw34yJsonMap $coldOutputPath
    Assert-Bw34yZeroExact (
        [bool]$coldEvaluation.ok -and
        [string]$coldEvaluation.selected_candidate_id -ceq "NONE" -and
        [int]$coldEvaluation.observed_receipt_count -eq 3
    ) "BW34Y cold evaluator output changed"

    $negativeControls = [System.Collections.Generic.List[object]]::new()
    [void]$negativeControls.Add((Invoke-Bw34yNegativeControl `
        -Name "candidate_identity" -Baseline $baseline -Mutation {
            param($receipt) $receipt.candidate_id = "BW34Y-Z"
        }))
    [void]$negativeControls.Add((Invoke-Bw34yNegativeControl `
        -Name "runtime_profile" -Baseline $baseline -Mutation {
            param($receipt) $receipt.controller_runtime_profile_sha256 = "sha256:$('0' * 64)"
        }))
    [void]$negativeControls.Add((Invoke-Bw34yNegativeControl `
        -Name "controller_policy" -Baseline $baseline -Mutation {
            param($receipt) $receipt.controller_policy_id = "sporespore_balanced_wave_bw23y_b_v1"
        }))
    [void]$negativeControls.Add((Invoke-Bw34yNegativeControl `
        -Name "yaw_gain" -Baseline $baseline -Mutation {
            param($receipt) $receipt.yaw_error_stride_gain_per_rad = 1.0
        }))
    [void]$negativeControls.Add((Invoke-Bw34yNegativeControl `
        -Name "global_scale" -Baseline $baseline -Mutation {
            param($receipt) $receipt.global_requested_correction_scale = 0.625
        }))
    [void]$negativeControls.Add((Invoke-Bw34yNegativeControl `
        -Name "seed_identity" -Baseline $baseline -Mutation {
            param($receipt) $receipt.campaign_seed = 49101
        }))
    [void]$negativeControls.Add((Invoke-Bw34yNegativeControl `
        -Name "rough_challenge" -Baseline $baseline -Mutation {
            param($receipt) $receipt.challenge_configuration_sha256 = "sha256:$('0' * 64)"
        }))
    [void]$negativeControls.Add((Invoke-Bw34yNegativeControl `
        -Name "rough_shape_count" -Baseline $baseline -Mutation {
            param($receipt) $receipt.terrain_shape_count = 63
        }))
    [void]$negativeControls.Add((Invoke-Bw34yNegativeControl `
        -Name "material_profile" -Baseline $baseline -Mutation {
            param($receipt) $receipt.material_profile_sha256 = "sha256:$('0' * 64)"
        }))
    [void]$negativeControls.Add((Invoke-Bw34yNegativeControl `
        -Name "authority_horizon" -Baseline $baseline -Mutation {
            param($receipt) $receipt.candidate_authority_observation_count = 3231
        }))
    [void]$negativeControls.Add((Invoke-Bw34yNegativeControl `
        -Name "native_application" -Baseline $baseline -Mutation {
            param($receipt) $receipt.application_gate_passed = $false
        }))
    [void]$negativeControls.Add((Invoke-Bw34yNegativeControl `
        -Name "receipt_schema" -Baseline $baseline -Mutation {
            param($receipt) [void]$receipt.Remove("dynamic_parent_summary_gate_passed")
        }))
    [void]$negativeControls.Add((Invoke-Bw34yNegativeControl `
        -Name "missing_walking_receipt" -Baseline $baseline -Mutation {
            param($receipt)
            $walking = [System.Collections.IDictionary]$receipt.walking_gate_receipts
            [void]$walking.Remove("bounded_lateral_drift")
        }))

    $positiveReceipts = @(Copy-Bw34yZeroValue $baseline)
    foreach ($receipt in $positiveReceipts) {
        Set-Bw34yWalkingPositive ([System.Collections.IDictionary]$receipt)
    }
    $positiveEvaluation = Invoke-Bw34yZeroEvaluation $positiveReceipts
    Assert-Bw34yZeroExact (
        [bool]$positiveEvaluation.ok -and
        [string]$positiveEvaluation.selected_candidate_id -ceq "BW34Y-A" -and
        [int]$positiveEvaluation.candidate_summaries."BW34Y-A".walking_pass_count -eq 3
    ) "BW34Y strict 3/3 positive selector canary failed"

    $preservationReceipts = @(Copy-Bw34yZeroValue $positiveReceipts)
    $seed21001 = [System.Collections.IDictionary]($preservationReceipts | Where-Object {
        [int]$_.campaign_seed -eq 21001
    } | Select-Object -First 1)
    Set-Bw34yWalkingNegative $seed21001
    $preservationEvaluation = Invoke-Bw34yZeroEvaluation $preservationReceipts
    Assert-Bw34yZeroExact (
        [bool]$preservationEvaluation.ok -and
        [string]$preservationEvaluation.selected_candidate_id -ceq "NONE" -and
        -not [bool]$preservationEvaluation.candidate_summaries."BW34Y-A".retained_comparator_passing_seed_21001_preserved
    ) "BW34Y retained passing-seed preservation canary failed"

    $manifest = Read-Bw34yJsonMap $manifestPath
    $syntheticAttempt = New-Bw34yAttemptRecord -Synthetic $true `
        -AttemptId ("e" * 32) -AuthorizationToken ("f" * 32) `
        -GodotVersion "4.7.stable.mono.official.5b4e0cb0f" `
        -GodotSha256 (Get-Bw34yRawSha256 $godotPath) `
        -GodotRuntimeSha256 (Get-Bw34yRawSha256 $godotPath.Replace("_console.exe", ".exe")) `
        -AdapterSha256 (Get-Bw34yRawSha256 $adapterArtifactPath) `
        -ContentAddressedInputs ([ordered]@{})
    Assert-Bw34yZeroExact (Test-Bw34yAttemptRecord $syntheticAttempt $true) (
        "BW34Y synthetic attempt record was rejected"
    )
    $malformedPhysicalAttempt = [System.Collections.IDictionary](
        Copy-Bw34yZeroValue $syntheticAttempt
    )
    $malformedPhysicalAttempt.synthetic_contract_preflight = $false
    $malformedPhysicalAttempt.source_commit = "0" * 40
    $malformedPhysicalAttempt.origin_main_commit = "0" * 40
    $malformedPhysicalAttempt.remote_main_commit = "0" * 40
    $malformedPhysicalAttempt.source_worktree_clean = $true
    $malformedPhysicalAttempt.source_matches_live_github_main = $true
    $malformedPhysicalAttempt.physical_identity_consumed = $true
    Assert-Bw34yZeroExact (
        -not (Test-Bw34yAttemptRecord $malformedPhysicalAttempt $false)
    ) "BW34Y malformed physical CAS attempt was accepted or did not fail closed"
    $attemptPath = Join-Path $tempRoot "synthetic-attempt.json"
    Write-Bw34yNewJsonArtifact $syntheticAttempt $attemptPath
    foreach ($cell in @($manifest.ordered_cells)) {
        $cellId = [string]$cell.cell_id
        $candidateId = [string]$cell.candidate_id
        $execution = Invoke-Bw34yGodotCaptured -GodotPath $godotPath -Arguments @(
            "--headless", "--path", $projectRoot,
            "--log-file", (Join-Path $tempRoot "$cellId-authorization.log"),
            "--script", $workerResource, "--", "authorization-preflight", $cellId
        ) -WorkerRoot (Join-Path $tempRoot "authorization-$cellId") `
            -TimeoutSeconds 300 -AttemptPath $attemptPath `
            -AuthorizationToken ("f" * 32) -CellId $cellId `
            -CandidateId $candidateId -WorldAttemptId "BW34Y-P1::$cellId" `
            -CampaignAttemptId ("e" * 32)
        $receipt = Get-Bw34yReceiptFromOutput `
            -OutputText ([string]$execution.stdout) -Prefix $preflightPrefix
        Assert-Bw34yZeroExact (
            [int]$execution.exit_code -eq 0 -and
            [bool]$receipt.ok -and [bool]$receipt.authorization_exact -and
            [int]$receipt.actual_world_build_count -eq 0
        ) "BW34Y authorization preflight failed: $cellId"
    }
    Write-Host (
        "BW34Y_ZERO_WORLD_PASS cells=3 adapter_starts=$([int]$entrypoint.adapter_start_count) " +
        "real_receipts=3 valid_walking_negatives=$([int]$baselineEvaluation.valid_walking_negative_count) " +
        "negative_controls=$($negativeControls.Count) selector_canaries=3 " +
        "attempt_record_controls=1 authorization_entrypoints=3 worlds=0 " +
        "outcome_exposed=False physical_authority=False"
    )
}

if ($MyInvocation.InvocationName -ne ".") {
    Invoke-Bw34yZeroWorldGate
}
