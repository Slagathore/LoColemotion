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
$evaluatorPath = Join-Path $sdkRoot "balanced_wave_bw33n_rough_factorial_gate.ps1"
$supervisorPath = Join-Path $sdkRoot "run_balanced_wave_bw33n_rough_factorial.ps1"
$declarationAuditPath = Join-Path $repoRoot "tests\test_bw33n_rough_factorial_declaration.ps1"
$freezeAuditPath = Join-Path $repoRoot "tests\test_bw33n_rough_factorial_freeze.ps1"
$operationLockPath = Join-Path $sdkRoot "locomotion_operation_lock.ps1"
$preflightPrefix = "BW33N_ROUGH_FACTORIAL_WORKER_PREFLIGHT "
$realShapedPrefix = "BW33N_ROUGH_FACTORIAL_REAL_SHAPED_RECEIPTS "

. $evaluatorPath
. $supervisorPath

function Assert-Bw33nZeroExact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Copy-Bw33nZeroValue {
    param([Parameter(Mandatory)]$Value)
    return $Value | ConvertTo-Json -Depth 64 |
        ConvertFrom-Json -AsHashtable -Depth 64
}

function Invoke-Bw33nZeroEvaluation {
    param([Parameter(Mandatory)][object[]]$Receipts)
    return Invoke-Bw33nRoughFactorialEvaluation `
        -CellReceipts $Receipts `
        -Source ([ordered]@{
            commit = "synthetic_preflight_no_source_identity"
            worktree_clean = $false
            matches_live_github_main = $false
        }) `
        -AttemptId ("d" * 32)
}

function Set-Bw33nWalkingNegative {
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Receipt)
    $walking = [System.Collections.IDictionary]$Receipt.walking_gate_receipts
    $walking["bounded_lateral_drift"] = $false
    $Receipt.walking_observed = $false
    $Receipt.failed_walking_gate_count = 1
    $Receipt.failure_code = "WALKING_CONJUNCTION_INCOMPLETE_AT_FIXED_HORIZON"
}

function Invoke-Bw33nNegativeControl {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][scriptblock]$Mutation,
        [Parameter(Mandatory)][object[]]$Baseline
    )
    $receipts = @(Copy-Bw33nZeroValue $Baseline)
    & $Mutation ([System.Collections.IDictionary]$receipts[0])
    $evaluation = Invoke-Bw33nZeroEvaluation $receipts
    Assert-Bw33nZeroExact (-not [bool]$evaluation.ok) (
        "BW33N negative control was accepted: $Name"
    )
    return [ordered]@{ control = $Name; rejected = $true }
}

function Invoke-Bw33nZeroWorldGate {
    foreach ($path in @(
        $evaluatorPath, $supervisorPath, $declarationAuditPath,
        $freezeAuditPath, $operationLockPath
    )) {
        Assert-Bw33nZeroExact (Test-Path -LiteralPath $path -PathType Leaf) (
            "BW33N zero-world source missing: $path"
        )
    }
    & pwsh -NoLogo -NoProfile -File $declarationAuditPath
    Assert-Bw33nZeroExact ($LASTEXITCODE -eq 0) "BW33N declaration audit failed"
    & pwsh -NoLogo -NoProfile -File $freezeAuditPath -SkipSupervisorPreflight
    Assert-Bw33nZeroExact ($LASTEXITCODE -eq 0) "BW33N freeze audit failed"
    if ($SkipGodotActualPath) {
        Write-Host (
            "BW33N_ZERO_WORLD_SOURCE_PASS actual_path_skipped=True worlds=0 " +
            "outcome_exposed=False physical_authority=False"
        )
        return
    }
    $godotPath = [System.IO.Path]::GetFullPath($Godot)
    Assert-Bw33nZeroExact (Test-Path -LiteralPath $godotPath -PathType Leaf) (
        "BW33N Godot executable missing: $godotPath"
    )
    $runToken = (Get-Date -Format "yyyyMMddTHHmmssfff") + "-" +
        [Guid]::NewGuid().ToString("N").Substring(0, 8)
    $tempRoot = Join-Path $sdkRoot "target\bw33n-zero-world\$runToken"
    [void][System.IO.Directory]::CreateDirectory($tempRoot)
    $projectRoot = New-Bw33nIsolatedProject $tempRoot
    $entrypoint = Invoke-Bw33nWorkerMode -GodotPath $godotPath `
        -ProjectRoot $projectRoot -TempRoot $tempRoot `
        -Mode "preflight-all" -Prefix $preflightPrefix
    $realShaped = Invoke-Bw33nWorkerMode -GodotPath $godotPath `
        -ProjectRoot $projectRoot -TempRoot $tempRoot `
        -Mode "receipt-preflight-all" -Prefix $realShapedPrefix
    $baseline = @($realShaped.cell_receipts)
    $baselineEvaluation = Invoke-Bw33nZeroEvaluation $baseline
    Assert-Bw33nZeroExact (
        [bool]$baselineEvaluation.ok -and
        [int]$baselineEvaluation.invalid_cell_count -eq 0 -and
        [int]$baselineEvaluation.valid_walking_negative_count -gt 0 -and
        [string]$baselineEvaluation.selected_candidate_id -ceq "BW33N-B"
    ) "BW33N real-shaped baseline or selector canary failed"
    $coldInputPath = Join-Path $tempRoot "cold-evaluator-input.json"
    $coldOutputPath = Join-Path $tempRoot "cold-evaluator-output.json"
    Write-Bw33nNewJsonArtifact ([ordered]@{
        schema_version = "sporespore_balanced_wave_bw33n_rough_factorial_evaluation_input_v1"
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
    Assert-Bw33nZeroExact ($LASTEXITCODE -eq 0) (
        "BW33N cold evaluator process rejected actual-composer receipts"
    )
    $coldEvaluation = Read-Bw33nJsonMap $coldOutputPath
    Assert-Bw33nZeroExact (
        [bool]$coldEvaluation.ok -and
        [string]$coldEvaluation.selected_candidate_id -ceq "BW33N-B" -and
        [int]$coldEvaluation.observed_receipt_count -eq 12
    ) "BW33N cold evaluator output changed"

    $negativeControls = [System.Collections.Generic.List[object]]::new()
    [void]$negativeControls.Add((Invoke-Bw33nNegativeControl `
        -Name "candidate_identity" -Baseline $baseline -Mutation {
            param($receipt) $receipt.candidate_id = "BW33N-Z"
        }))
    [void]$negativeControls.Add((Invoke-Bw33nNegativeControl `
        -Name "runtime_profile" -Baseline $baseline -Mutation {
            param($receipt) $receipt.controller_runtime_profile_sha256 = "sha256:$('0' * 64)"
        }))
    [void]$negativeControls.Add((Invoke-Bw33nNegativeControl `
        -Name "global_scale" -Baseline $baseline -Mutation {
            param($receipt) $receipt.global_requested_correction_scale = 0.625
        }))
    [void]$negativeControls.Add((Invoke-Bw33nNegativeControl `
        -Name "seed_identity" -Baseline $baseline -Mutation {
            param($receipt) $receipt.campaign_seed = 49101
        }))
    [void]$negativeControls.Add((Invoke-Bw33nNegativeControl `
        -Name "rough_challenge" -Baseline $baseline -Mutation {
            param($receipt) $receipt.challenge_configuration_sha256 = "sha256:$('0' * 64)"
        }))
    [void]$negativeControls.Add((Invoke-Bw33nNegativeControl `
        -Name "rough_shape_count" -Baseline $baseline -Mutation {
            param($receipt) $receipt.terrain_shape_count = 63
        }))
    [void]$negativeControls.Add((Invoke-Bw33nNegativeControl `
        -Name "authority_horizon" -Baseline $baseline -Mutation {
            param($receipt) $receipt.candidate_authority_observation_count = 3231
        }))
    [void]$negativeControls.Add((Invoke-Bw33nNegativeControl `
        -Name "native_application" -Baseline $baseline -Mutation {
            param($receipt) $receipt.application_gate_passed = $false
        }))
    [void]$negativeControls.Add((Invoke-Bw33nNegativeControl `
        -Name "receipt_schema" -Baseline $baseline -Mutation {
            param($receipt) [void]$receipt.Remove("dynamic_parent_summary_gate_passed")
        }))

    $parsimonyReceipts = @(Copy-Bw33nZeroValue $baseline)
    $bReceipt = [System.Collections.IDictionary]($parsimonyReceipts | Where-Object {
        [string]$_.candidate_id -ceq "BW33N-B" -and [int]$_.campaign_seed -eq 21002
    } | Select-Object -First 1)
    Set-Bw33nWalkingNegative $bReceipt
    $parsimony = Invoke-Bw33nZeroEvaluation $parsimonyReceipts
    Assert-Bw33nZeroExact (
        [bool]$parsimony.ok -and
        [string]$parsimony.selected_candidate_id -ceq "BW33N-D"
    ) "BW33N prospective parsimony selector order failed"

    $noneReceipts = @(Copy-Bw33nZeroValue $baseline)
    foreach ($candidateId in @("BW33N-B", "BW33N-C", "BW33N-D")) {
        $target = [System.Collections.IDictionary]($noneReceipts | Where-Object {
            [string]$_.candidate_id -ceq $candidateId -and [int]$_.campaign_seed -eq 21001
        } | Select-Object -First 1)
        Set-Bw33nWalkingNegative $target
    }
    $noneEvaluation = Invoke-Bw33nZeroEvaluation $noneReceipts
    Assert-Bw33nZeroExact (
        [bool]$noneEvaluation.ok -and
        [string]$noneEvaluation.selected_candidate_id -ceq "NONE"
    ) "BW33N valid NONE selector outcome failed"

    $manifest = Read-Bw33nJsonMap $manifestPath
    $syntheticAttempt = New-Bw33nAttemptRecord -Synthetic $true `
        -AttemptId ("e" * 32) -AuthorizationToken ("f" * 32) `
        -GodotVersion "4.7.stable.mono.official.5b4e0cb0f" `
        -GodotSha256 (Get-Bw33nRawSha256 $godotPath) `
        -GodotRuntimeSha256 (Get-Bw33nRawSha256 $godotPath.Replace("_console.exe", ".exe")) `
        -AdapterSha256 (Get-Bw33nRawSha256 $adapterArtifactPath) `
        -ContentAddressedInputs ([ordered]@{})
    Assert-Bw33nZeroExact (Test-Bw33nAttemptRecord $syntheticAttempt $true) (
        "BW33N synthetic attempt record was rejected"
    )
    $malformedPhysicalAttempt = [System.Collections.IDictionary](
        Copy-Bw33nZeroValue $syntheticAttempt
    )
    $malformedPhysicalAttempt.synthetic_contract_preflight = $false
    $malformedPhysicalAttempt.source_commit = "0" * 40
    $malformedPhysicalAttempt.origin_main_commit = "0" * 40
    $malformedPhysicalAttempt.remote_main_commit = "0" * 40
    $malformedPhysicalAttempt.source_worktree_clean = $true
    $malformedPhysicalAttempt.source_matches_live_github_main = $true
    $malformedPhysicalAttempt.physical_identity_consumed = $true
    Assert-Bw33nZeroExact (
        -not (Test-Bw33nAttemptRecord $malformedPhysicalAttempt $false)
    ) "BW33N malformed physical CAS attempt was accepted or did not fail closed"
    $attemptPath = Join-Path $tempRoot "synthetic-attempt.json"
    Write-Bw33nNewJsonArtifact $syntheticAttempt $attemptPath
    foreach ($cell in @($manifest.ordered_cells)) {
        $cellId = [string]$cell.cell_id
        $candidateId = [string]$cell.candidate_id
        $execution = Invoke-Bw33nGodotCaptured -GodotPath $godotPath -Arguments @(
            "--headless", "--path", $projectRoot,
            "--log-file", (Join-Path $tempRoot "$cellId-authorization.log"),
            "--script", $workerResource, "--", "authorization-preflight", $cellId
        ) -WorkerRoot (Join-Path $tempRoot "authorization-$cellId") `
            -TimeoutSeconds 300 -AttemptPath $attemptPath `
            -AuthorizationToken ("f" * 32) -CellId $cellId `
            -CandidateId $candidateId -WorldAttemptId "BW33N-P1::$cellId" `
            -CampaignAttemptId ("e" * 32)
        $receipt = Get-Bw33nReceiptFromOutput `
            -OutputText ([string]$execution.stdout) -Prefix $preflightPrefix
        Assert-Bw33nZeroExact (
            [int]$execution.exit_code -eq 0 -and
            [bool]$receipt.ok -and [bool]$receipt.authorization_exact -and
            [int]$receipt.actual_world_build_count -eq 0
        ) "BW33N authorization preflight failed: $cellId"
    }
    Write-Host (
        "BW33N_ZERO_WORLD_PASS cells=12 adapter_starts=$([int]$entrypoint.adapter_start_count) " +
        "real_receipts=12 valid_walking_negatives=$([int]$baselineEvaluation.valid_walking_negative_count) " +
        "negative_controls=$($negativeControls.Count) selector_canaries=3 " +
        "attempt_record_controls=1 authorization_entrypoints=12 worlds=0 " +
        "outcome_exposed=False physical_authority=False"
    )
}

if ($MyInvocation.InvocationName -ne ".") {
    Invoke-Bw33nZeroWorldGate
}
