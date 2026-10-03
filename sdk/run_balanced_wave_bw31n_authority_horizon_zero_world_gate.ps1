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
$evaluatorPath = Join-Path $sdkRoot "balanced_wave_bw31n_authority_horizon_gate.ps1"
$supervisorPath = Join-Path $sdkRoot "run_balanced_wave_bw31n_authority_horizon.ps1"
$declarationAuditPath = Join-Path $repoRoot "tests\test_bw31n_authority_horizon_declaration.ps1"
$adapterPath = Join-Path $sdkRoot "target\debug\sporespore_godot_adapter.dll"
$receiptPrefix = "BW31N_AUTHORITY_HORIZON_WORKER_PREFLIGHT "
$rawPrefix = "BW31N_AUTHORITY_HORIZON_RAW_CELL "
$realShapedPrefix = "BW31N_AUTHORITY_HORIZON_REAL_SHAPED_RECEIPTS "

function Assert-Bw31nZeroExact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Copy-Bw31nZeroValue {
    param([Parameter(Mandatory)]$Value)
    return $Value | ConvertTo-Json -Depth 80 |
        ConvertFrom-Json -AsHashtable -Depth 80
}

function Get-Bw31nZeroGatePassed {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Evaluation,
        [Parameter(Mandatory)][string]$GateId
    )
    $gate = @($Evaluation["gates"] | Where-Object {
        [string]$_["gate_id"] -ceq $GateId
    })
    return $gate.Count -eq 1 -and [bool]$gate[0]["passed"]
}

function Set-Bw31nSyntheticWalkingFailure {
    param(
        [Parameter(Mandatory)][object[]]$Receipts,
        [Parameter(Mandatory)][string]$CandidateId,
        [Parameter(Mandatory)][string]$ProfileId,
        [Parameter(Mandatory)][int]$Count
    )
    $matches = @($Receipts | Where-Object {
        [string]$_["candidate_id"] -ceq $CandidateId -and
        [string]$_["challenge_profile_id"] -ceq $ProfileId
    })
    Assert-Bw31nZeroExact ($Count -ge 0 -and $Count -le $matches.Count) (
        "BW31N synthetic walking-failure request exceeded the declared pair"
    )
    for ($index = 0; $index -lt $Count; $index += 1) {
        $matches[$index]["walking_observed"] = $false
    }
}

function Assert-Bw31nZeroEvaluationFailure {
    param(
        [Parameter(Mandatory)][object[]]$Receipts,
        [Parameter(Mandatory)][string]$FailureCode,
        [Parameter(Mandatory)][string]$Label
    )
    $evaluation = Invoke-Bw31nRecoveryEvaluation -CellReceipts $Receipts
    Assert-Bw31nZeroExact (
        -not [bool]$evaluation["ok"] -and
        @($evaluation["failure_codes"]) -ccontains $FailureCode -and
        [string]$evaluation["selected_candidate_id"] -ceq "NONE" -and
        -not [bool]$evaluation["physical_acceptance_authority"]
    ) "BW31N evaluator canary failed open: $Label"
}

Assert-Bw31nZeroExact (Test-Path -LiteralPath $evaluatorPath -PathType Leaf) (
    "BW31N production evaluator is missing"
)
Assert-Bw31nZeroExact (Test-Path -LiteralPath $supervisorPath -PathType Leaf) (
    "BW31N supervisor is missing"
)
. $evaluatorPath
. $supervisorPath -PreflightOnly:$false -RunPhysical:$false -Godot $Godot

& pwsh -NoLogo -NoProfile -File $declarationAuditPath
Assert-Bw31nZeroExact ($LASTEXITCODE -eq 0) "BW31N declaration audit failed"

$perfect = @(New-Bw31nPerfectSyntheticReceiptSet)
$perfectEvaluation = Invoke-Bw31nRecoveryEvaluation -CellReceipts $perfect
Assert-Bw31nZeroExact (
    [bool]$perfectEvaluation["ok"] -and
    [string]$perfectEvaluation["status"] -ceq "complete_valid_development_result" -and
    [int]$perfectEvaluation["observed_world_count"] -eq 24 -and
    [int]$perfectEvaluation["passed_gate_count"] -eq 15 -and
    [int]$perfectEvaluation["failed_gate_count"] -eq 0 -and
    [string]$perfectEvaluation["selected_candidate_id"] -ceq "NONE" -and
    -not [bool]$perfectEvaluation["fresh_nuisance_validation_ready"] -and
    -not [bool]$perfectEvaluation["walking_acceptance"] -and
    -not [bool]$perfectEvaluation["nuisance_acceptance"] -and
    -not [bool]$perfectEvaluation["release_authorized"] -and
    -not [bool]$perfectEvaluation["physical_acceptance_authority"]
) "BW31N neutral perfect matrix did not pass 15/15 and select NONE"

# A walking-negative receipt is still a complete scientific result. With one
# A failure and twelve B passes, the frozen development selector may select B,
# but it still grants no acceptance or release authority.
$strictImprovement = @(Copy-Bw31nZeroValue $perfect)
Set-Bw31nSyntheticWalkingFailure $strictImprovement "BW31N-A" "bw6n_push_v1" 1
$strictEvaluation = Invoke-Bw31nRecoveryEvaluation -CellReceipts $strictImprovement
Assert-Bw31nZeroExact (
    [bool]$strictEvaluation["ok"] -and
    [int]$strictEvaluation["passed_gate_count"] -eq 15 -and
    [bool]$strictEvaluation["strict_total_improvement_passed"] -and
    [bool]$strictEvaluation["per_axis_non_regression_passed"] -and
    [string]$strictEvaluation["selected_candidate_id"] -ceq "BW31N-B" -and
    [bool]$strictEvaluation["fresh_nuisance_validation_ready"] -and
    -not [bool]$strictEvaluation["walking_acceptance"] -and
    -not [bool]$strictEvaluation["nuisance_acceptance"] -and
    -not [bool]$strictEvaluation["physical_acceptance_authority"]
) "BW31N strict-improvement selector control failed"

$walkingNegative = @(Copy-Bw31nZeroValue $perfect)
Set-Bw31nSyntheticWalkingFailure $walkingNegative "BW31N-B" "bw6n_sensor_noise_v1" 1
$walkingNegativeEvaluation = Invoke-Bw31nRecoveryEvaluation -CellReceipts $walkingNegative
Assert-Bw31nZeroExact (
    [bool]$walkingNegativeEvaluation["ok"] -and
    [int]$walkingNegativeEvaluation["passed_gate_count"] -eq 15 -and
    (Get-Bw31nZeroGatePassed $walkingNegativeEvaluation "complete_development_result") -and
    [string]$walkingNegativeEvaluation["selected_candidate_id"] -ceq "NONE"
) "BW31N walking-negative cell was confused with an integrity failure"

$axisRegression = @(Copy-Bw31nZeroValue $perfect)
Set-Bw31nSyntheticWalkingFailure $axisRegression "BW31N-A" "bw6n_rough_v1" 2
Set-Bw31nSyntheticWalkingFailure $axisRegression "BW31N-A" "bw6n_push_v1" 1
Set-Bw31nSyntheticWalkingFailure $axisRegression "BW31N-B" "bw6n_baseline_v1" 1
$axisRegressionEvaluation = Invoke-Bw31nRecoveryEvaluation -CellReceipts $axisRegression
Assert-Bw31nZeroExact (
    [bool]$axisRegressionEvaluation["ok"] -and
    [bool]$axisRegressionEvaluation["strict_total_improvement_passed"] -and
    -not [bool]$axisRegressionEvaluation["per_axis_non_regression_passed"] -and
    [string]$axisRegressionEvaluation["selected_candidate_id"] -ceq "NONE" -and
    -not [bool]$axisRegressionEvaluation["fresh_nuisance_validation_ready"]
) "BW31N paired-axis regression escaped the frozen selector"

$tie = @(Copy-Bw31nZeroValue $perfect)
Set-Bw31nSyntheticWalkingFailure $tie "BW31N-A" "bw6n_baseline_v1" 1
Set-Bw31nSyntheticWalkingFailure $tie "BW31N-B" "bw6n_baseline_v1" 1
$tieEvaluation = Invoke-Bw31nRecoveryEvaluation -CellReceipts $tie
Assert-Bw31nZeroExact (
    [bool]$tieEvaluation["ok"] -and
    -not [bool]$tieEvaluation["strict_total_improvement_passed"] -and
    [string]$tieEvaluation["selected_candidate_id"] -ceq "NONE"
) "BW31N tied candidates did not select NONE"

$canaryCount = 0
function Invoke-Bw31nZeroCanary {
    param(
        [Parameter(Mandatory)][scriptblock]$Mutation,
        [Parameter(Mandatory)][string]$FailureCode,
        [Parameter(Mandatory)][string]$Label
    )
    $receipts = @(Copy-Bw31nZeroValue $perfect)
    $mutated = & $Mutation $receipts
    if ($null -ne $mutated) { $receipts = @($mutated) }
    Assert-Bw31nZeroEvaluationFailure $receipts $FailureCode $Label
    $script:canaryCount += 1
}

Invoke-Bw31nZeroCanary { param($r) @($r | Select-Object -Skip 1) } `
    "BW31N_CARDINALITY_INVALID" "missing receipt"
Invoke-Bw31nZeroCanary { param($r) $r[23] = Copy-Bw31nZeroValue $r[0] } `
    "BW31N_CARDINALITY_INVALID" "duplicate receipt"
Invoke-Bw31nZeroCanary { param($r) $r[0]["cell_id"] = "BW31N-UNDECLARED" } `
    "BW31N_CARDINALITY_INVALID" "unexpected receipt identity"
Invoke-Bw31nZeroCanary { param($r) $r[0]["candidate_base_composition_digest"] = "sha256:$('0' * 64)" } `
    "BW31N_IDENTITY_INVALID" "candidate composition digest"
Invoke-Bw31nZeroCanary { param($r) [void]$r[0].Remove("material_profile_sha256") } `
    "BW31N_RECEIPT_SCHEMA_INVALID" "missing shared receipt field"
Invoke-Bw31nZeroCanary { param($r) $r[0]["material_profile_digest"] = $r[0]["material_profile_sha256"] } `
    "BW31N_RECEIPT_SCHEMA_INVALID" "candidate-specific legacy receipt alias"
Invoke-Bw31nZeroCanary { param($r) $r[0]["candidate_authority_observation_count"] = 3231 } `
    "BW31N_HORIZON_INVALID" "candidate-dependent short horizon"
Invoke-Bw31nZeroCanary { param($r) $r[0]["candidate_specific_horizon_extension_count"] = 1 } `
    "BW31N_HORIZON_INVALID" "candidate-specific horizon extension"
Invoke-Bw31nZeroCanary { param($r) $r[0]["pre_authority_world_tick_count"] += 1 } `
    "BW31N_PRE_AUTHORITY_INVALID" "pre-authority tick exclusion"
$roughIndex = [array]::FindIndex([object[]]$perfect, [Predicate[object]]{
    param($receipt) [string]$receipt["challenge_profile_id"] -ceq "bw6n_rough_v1"
})
Assert-Bw31nZeroExact ($roughIndex -ge 0) "BW31N perfect fixture lacks rough profile"
Invoke-Bw31nZeroCanary { param($r) $r[$roughIndex]["terrain_shape_count"] = 1 } `
    "BW31N_CHALLENGE_INVALID" "rough challenge realization"
Invoke-Bw31nZeroCanary { param($r) $r[0]["measurement_gate_passed"] = $false } `
    "BW31N_MEASUREMENT_INVALID" "measurement acquisition"
Invoke-Bw31nZeroCanary { param($r) $r[0]["application_gate_passed"] = $false } `
    "BW31N_APPLICATION_INVALID" "candidate application"
Invoke-Bw31nZeroCanary { param($r) $r[0]["outcome_complete"] = $false } `
    "BW31N_OUTCOME_INCOMPLETE" "outcome completion"
Invoke-Bw31nZeroCanary { param($r) $r[0]["walking_claim_authorized"] = $true } `
    "BW31N_CLAIM_INFLATION" "claim inflation"

$godotActualPathCount = 0
$workerEntrypointCount = 0
$realShapedReceiptCount = 0
$authorizationCanaryCount = 0
if (-not $SkipGodotActualPath) {
    $godotPath = [System.IO.Path]::GetFullPath($Godot)
    $runtimePath = $godotPath.Replace("_console.exe", ".exe")
    Assert-Bw31nZeroExact (
        (Test-Path -LiteralPath $godotPath -PathType Leaf) -and
        (Test-Path -LiteralPath $runtimePath -PathType Leaf) -and
        (Test-Path -LiteralPath $adapterPath -PathType Leaf)
    ) "BW31N pinned Godot or adapter artifact is missing"
    $godotVersion = (& $godotPath --version 2>&1 | Out-String).Trim()
    Assert-Bw31nZeroExact ($godotVersion -ceq "4.7.stable.mono.official.5b4e0cb0f") (
        "BW31N unexpected Godot version: $godotVersion"
    )

    $runToken = (Get-Date -Format "yyyyMMddTHHmmssfff") + "-" +
        [Guid]::NewGuid().ToString("N").Substring(0, 8)
    $tempRoot = Join-Path $sdkRoot "target\bw31n-recovery-zero-world\$runToken"
    [void][System.IO.Directory]::CreateDirectory($tempRoot)
    $projectRoot = New-Bw31nIsolatedProject -Root $tempRoot
    $referencePreflight = Invoke-Bw31nWorkerPreflight -GodotPath $godotPath `
        -ProjectRoot $projectRoot -TempRoot $tempRoot `
        -WorkerResource "res://tests/test_sdk_balanced_wave_bw31n_reference_worker.gd" `
        -CandidateId "BW31N-A"
    $successorPreflight = Invoke-Bw31nWorkerPreflight -GodotPath $godotPath `
        -ProjectRoot $projectRoot -TempRoot $tempRoot `
        -WorkerResource "res://tests/test_sdk_balanced_wave_bw31n_successor_worker.gd" `
        -CandidateId "BW31N-B"
    Assert-Bw31nZeroExact (
        [int]$referencePreflight["entrypoint_count"] -eq 12 -and
        [int]$successorPreflight["entrypoint_count"] -eq 12 -and
        [int]$successorPreflight["adapter_start_count"] -eq 12
    ) "BW31N actual worker entrypoint matrix changed"
    $workerEntrypointCount = 24

    $realShapedReceipts = [System.Collections.Generic.List[object]]::new()
    foreach ($route in @(
        [ordered]@{
            candidate_id = "BW31N-A"
            resource = "res://tests/test_sdk_balanced_wave_bw31n_reference_worker.gd"
        },
        [ordered]@{
            candidate_id = "BW31N-B"
            resource = "res://tests/test_sdk_balanced_wave_bw31n_successor_worker.gd"
        }
    )) {
        $candidateId = [string]$route["candidate_id"]
        $execution = Invoke-Bw31nGodotCaptured -GodotPath $godotPath -Arguments @(
            "--headless", "--path", $projectRoot,
            "--log-file", (Join-Path $tempRoot "$candidateId-real-shaped-engine.log"),
            "--script", [string]$route["resource"], "--", "receipt-preflight-all"
        ) -WorkerRoot (Join-Path $tempRoot "$candidateId-real-shaped") -TimeoutSeconds 300
        $aggregate = Get-Bw31nReceiptFromOutput `
            -OutputText ([string]$execution["stdout"]) -Prefix $realShapedPrefix
        Assert-Bw31nZeroExact (
            [int]$execution["exit_code"] -eq 0 -and
            -not [bool]$execution["timed_out"] -and
            [bool]$aggregate["ok"] -and
            [string]$aggregate["candidate_id"] -ceq $candidateId -and
            [int]$aggregate["entrypoint_count"] -eq 12 -and
            [int]$aggregate["actual_world_build_count"] -eq 0 -and
            [int]$aggregate["scene_tree_insertion_count"] -eq 0 -and
            -not [bool]$aggregate["physics_state_modified"] -and
            -not [bool]$aggregate["locomotion_outcome_exposed"] -and
            -not [bool]$aggregate["physical_acceptance_authority"]
        ) "BW31N $candidateId real-shaped receipt preflight failed"
        foreach ($receipt in @($aggregate["cell_receipts"])) {
            [void]$realShapedReceipts.Add($receipt)
        }
    }
    $realShapedEvaluation = Invoke-Bw31nRecoveryEvaluation `
        -CellReceipts @($realShapedReceipts)
    $walkingNegativeCount = @(
        $realShapedReceipts | Where-Object { -not [bool]$_["walking_observed"] }
    ).Count
    Assert-Bw31nZeroExact (
        $realShapedReceipts.Count -eq 24 -and
        $walkingNegativeCount -eq 2 -and
        [bool]$realShapedEvaluation["ok"] -and
        [int]$realShapedEvaluation["passed_gate_count"] -eq 15 -and
        [string]$realShapedEvaluation["selected_candidate_id"] -ceq "NONE" -and
        -not [bool]$realShapedEvaluation["physical_acceptance_authority"]
    ) "BW31N actual A/B real-shaped receipts did not pass the complete evaluator"
    $realShapedReceiptCount = $realShapedReceipts.Count

    $attemptId = [Guid]::NewGuid().ToString("N")
    $token = [Guid]::NewGuid().ToString("N")
    $attempt = New-Bw31nAttemptRecord -Synthetic $true -AttemptId $attemptId `
        -AuthorizationToken $token -GodotVersion $godotVersion `
        -GodotSha256 (Get-Bw31nRawSha256 $godotPath) `
        -GodotRuntimeSha256 (Get-Bw31nRawSha256 $runtimePath) `
        -AdapterSha256 (Get-Bw31nRawSha256 $adapterPath)
    Assert-Bw31nZeroExact (Test-Bw31nAttemptRecord -Attempt $attempt -Synthetic $true) (
        "BW31N synthetic attempt constructor failed its exact parser"
    )
    $attemptPath = Join-Path $tempRoot "synthetic-attempt.json"
    Write-Bw31nUtf8NoBom -Path $attemptPath -Text (
        ($attempt | ConvertTo-Json -Depth 64) + [Environment]::NewLine
    )

    $manifest = Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -AsHashtable -Depth 64
    foreach ($candidateId in @("BW31N-A", "BW31N-B")) {
        $cell = @($manifest["ordered_cells"] | Where-Object {
            [string]$_["candidate_id"] -ceq $candidateId
        } | Select-Object -First 1)[0]
        $cellId = [string]$cell["cell_id"]
        $resource = if ($candidateId -ceq "BW31N-A") {
            "res://tests/test_sdk_balanced_wave_bw31n_reference_worker.gd"
        } else { "res://tests/test_sdk_balanced_wave_bw31n_successor_worker.gd" }
        $execution = Invoke-Bw31nGodotCaptured -GodotPath $godotPath -Arguments @(
            "--headless", "--path", $projectRoot,
            "--log-file", (Join-Path $tempRoot "$candidateId-authorization-engine.log"),
            "--script", $resource, "--", "authorization-preflight", $cellId
        ) -WorkerRoot (Join-Path $tempRoot "$candidateId-authorization") `
            -TimeoutSeconds 300 -AttemptPath $attemptPath -AuthorizationToken $token `
            -CellId $cellId -CandidateId $candidateId `
            -WorldAttemptId "BW31N-P1::$cellId" -CampaignAttemptId $attemptId
        $receipt = Get-Bw31nReceiptFromOutput -OutputText ([string]$execution["stdout"]) `
            -Prefix $receiptPrefix
        Assert-Bw31nZeroExact (
            [int]$execution["exit_code"] -eq 0 -and
            -not [bool]$execution["timed_out"] -and
            [bool]$receipt["ok"] -and [bool]$receipt["authorization_requested"] -and
            [bool]$receipt["authorization_exact"] -and
            [int]$receipt["actual_world_build_count"] -eq 0 -and
            [int]$receipt["scene_tree_insertion_count"] -eq 0 -and
            -not [bool]$receipt["physics_state_modified"] -and
            -not [bool]$receipt["locomotion_outcome_exposed"] -and
            -not [bool]$receipt["physical_acceptance_authority"]
        ) "BW31N $candidateId valid authorization preflight failed"
        $godotActualPathCount += 1
    }

    $firstCell = [System.Collections.IDictionary]$manifest["ordered_cells"][0]
    $firstCellId = [string]$firstCell["cell_id"]
    $wrongToken = Invoke-Bw31nGodotCaptured -GodotPath $godotPath -Arguments @(
        "--headless", "--path", $projectRoot,
        "--log-file", (Join-Path $tempRoot "wrong-token-engine.log"),
        "--script", "res://tests/test_sdk_balanced_wave_bw31n_reference_worker.gd",
        "--", "authorization-preflight", $firstCellId
    ) -WorkerRoot (Join-Path $tempRoot "wrong-token") -TimeoutSeconds 300 `
        -AttemptPath $attemptPath -AuthorizationToken ([Guid]::NewGuid().ToString("N")) `
        -CellId $firstCellId -CandidateId "BW31N-A" `
        -WorldAttemptId "BW31N-P1::$firstCellId" -CampaignAttemptId $attemptId
    $wrongTokenReceipt = Get-Bw31nReceiptFromOutput `
        -OutputText ([string]$wrongToken["stdout"]) -Prefix $receiptPrefix
    Assert-Bw31nZeroExact (
        [int]$wrongToken["exit_code"] -ne 0 -and
        -not [bool]$wrongTokenReceipt["ok"] -and
        -not [bool]$wrongTokenReceipt["authorization_exact"] -and
        [int]$wrongTokenReceipt["actual_world_build_count"] -eq 0
    ) "BW31N wrong-token authorization canary failed open"
    $authorizationCanaryCount += 1

    $directBypass = Invoke-Bw31nGodotCaptured -GodotPath $godotPath -Arguments @(
        "--headless", "--path", $projectRoot,
        "--log-file", (Join-Path $tempRoot "direct-bypass-engine.log"),
        "--script", "res://tests/test_sdk_balanced_wave_bw31n_reference_worker.gd",
        "--", "physical", $firstCellId
    ) -WorkerRoot (Join-Path $tempRoot "direct-bypass") -TimeoutSeconds 300
    Assert-Bw31nZeroExact (
        [int]$directBypass["exit_code"] -ne 0 -and
        -not ([string]$directBypass["stdout"]).Contains($rawPrefix, [StringComparison]::Ordinal)
    ) "BW31N direct worker bypass reached a raw physical receipt"
    $authorizationCanaryCount += 1
}

$attemptCanary = New-Bw31nAttemptRecord -Synthetic $true `
    -AttemptId ([Guid]::NewGuid().ToString("N")) `
    -AuthorizationToken ([Guid]::NewGuid().ToString("N")) `
    -GodotVersion "4.7.stable.mono.official.5b4e0cb0f" `
    -GodotSha256 "c5fc2d0bb24826a6757fa1e6bf2991effb294859c7dd03d09a122ef217484896" `
    -GodotRuntimeSha256 "baa909d0a905021da80cfc831713e9d3ba4bd0935ac3b93ba4c77dc140cfecc4" `
    -AdapterSha256 (Get-Bw31nRawSha256 $adapterPath)
Assert-Bw31nZeroExact (Test-Bw31nAttemptRecord $attemptCanary $true) (
    "BW31N synthetic attempt record did not pass"
)
$attemptCanaryCount = 0
foreach ($mutation in @(
    { param($a) $a["authorization_token"] = "wrong" },
    { param($a) $a["source_commit"] = "0" * 40 },
    { param($a) $a["complete_zero_world_gate_passed"] = $false },
    { param($a) $a["physical_identity_consumed"] = $true },
    { param($a) $a["ordered_cell_ids"] = @($a["ordered_cell_ids"] | Select-Object -Skip 1) },
    { param($a) $a["unexpected_field"] = $true }
)) {
    $candidate = [System.Collections.IDictionary](Copy-Bw31nZeroValue $attemptCanary)
    & $mutation $candidate
    Assert-Bw31nZeroExact (-not (Test-Bw31nAttemptRecord $candidate $true)) (
        "BW31N attempt-record canary failed open"
    )
    $attemptCanaryCount += 1
}

Write-Host (
    "BW31N_ZERO_WORLD_GATE_PASS gates=15 cells=24 evaluator_canaries=$canaryCount " +
    "attempt_canaries=$attemptCanaryCount authorization_canaries=$authorizationCanaryCount " +
    "worker_entrypoints=$workerEntrypointCount actual_authorizations=$godotActualPathCount " +
    "real_shaped_receipts=$realShapedReceiptCount shared_composer=True authority_horizon=3232 " +
    "walking_negative_complete=True strict_selection=True axis_regression_veto=True " +
    "worlds=0 outcomes_exposed=False physical_authority=False"
)
