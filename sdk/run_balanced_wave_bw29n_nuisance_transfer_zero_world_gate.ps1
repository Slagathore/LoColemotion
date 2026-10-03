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
$evaluatorPath = Join-Path $sdkRoot "balanced_wave_bw29n_nuisance_transfer_gate.ps1"
$supervisorPath = Join-Path $sdkRoot "run_balanced_wave_bw29n_nuisance_transfer.ps1"
$declarationAuditPath = Join-Path $repoRoot "tests\test_bw29n_nuisance_transfer_declaration.ps1"
$adapterPath = Join-Path $sdkRoot "target\debug\sporespore_godot_adapter.dll"
$receiptPrefix = "BW29N_NUISANCE_TRANSFER_WORKER_PREFLIGHT "
$rawPrefix = "BW29N_NUISANCE_TRANSFER_RAW_CELL "

function Assert-Bw29nZeroExact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Copy-Bw29nZeroValue {
    param([Parameter(Mandatory)]$Value)
    return $Value | ConvertTo-Json -Depth 80 |
        ConvertFrom-Json -AsHashtable -Depth 80
}

function Get-Bw29nZeroGatePassed {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Evaluation,
        [Parameter(Mandatory)][string]$GateId
    )
    $gate = @($Evaluation["gates"] | Where-Object {
        [string]$_["gate_id"] -ceq $GateId
    })
    return $gate.Count -eq 1 -and [bool]$gate[0]["passed"]
}

function Set-Bw29nSyntheticWalkingFailure {
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
    Assert-Bw29nZeroExact ($Count -ge 0 -and $Count -le $matches.Count) (
        "BW29N synthetic walking-failure request exceeded the declared pair"
    )
    for ($index = 0; $index -lt $Count; $index += 1) {
        $matches[$index]["walking_observed"] = $false
    }
}

function Assert-Bw29nZeroEvaluationFailure {
    param(
        [Parameter(Mandatory)][object[]]$Receipts,
        [Parameter(Mandatory)][string]$FailureCode,
        [Parameter(Mandatory)][string]$Label
    )
    $evaluation = Invoke-Bw29nNuisanceTransferEvaluation -CellReceipts $Receipts
    Assert-Bw29nZeroExact (
        -not [bool]$evaluation["ok"] -and
        @($evaluation["failure_codes"]) -ccontains $FailureCode -and
        [string]$evaluation["selected_candidate_id"] -ceq "NONE" -and
        -not [bool]$evaluation["physical_acceptance_authority"]
    ) "BW29N evaluator canary failed open: $Label"
}

Assert-Bw29nZeroExact (Test-Path -LiteralPath $evaluatorPath -PathType Leaf) (
    "BW29N production evaluator is missing"
)
Assert-Bw29nZeroExact (Test-Path -LiteralPath $supervisorPath -PathType Leaf) (
    "BW29N supervisor is missing"
)
. $evaluatorPath
. $supervisorPath -PreflightOnly:$false -RunPhysical:$false -Godot $Godot

& pwsh -NoLogo -NoProfile -File $declarationAuditPath
Assert-Bw29nZeroExact ($LASTEXITCODE -eq 0) "BW29N declaration audit failed"

$perfect = @(New-Bw29nPerfectSyntheticReceiptSet)
$perfectEvaluation = Invoke-Bw29nNuisanceTransferEvaluation -CellReceipts $perfect
Assert-Bw29nZeroExact (
    [bool]$perfectEvaluation["ok"] -and
    [string]$perfectEvaluation["status"] -ceq "complete_valid_development_result" -and
    [int]$perfectEvaluation["observed_world_count"] -eq 24 -and
    [int]$perfectEvaluation["passed_gate_count"] -eq 12 -and
    [int]$perfectEvaluation["failed_gate_count"] -eq 0 -and
    [string]$perfectEvaluation["selected_candidate_id"] -ceq "NONE" -and
    -not [bool]$perfectEvaluation["fresh_nuisance_validation_ready"] -and
    -not [bool]$perfectEvaluation["walking_acceptance"] -and
    -not [bool]$perfectEvaluation["nuisance_acceptance"] -and
    -not [bool]$perfectEvaluation["release_authorized"] -and
    -not [bool]$perfectEvaluation["physical_acceptance_authority"]
) "BW29N neutral perfect matrix did not pass 12/12 and select NONE"

# A walking-negative receipt is still a complete scientific result. With one
# A failure and twelve B passes, the frozen development selector may select B,
# but it still grants no acceptance or release authority.
$strictImprovement = @(Copy-Bw29nZeroValue $perfect)
Set-Bw29nSyntheticWalkingFailure $strictImprovement "BW29N-A" "bw6n_push_v1" 1
$strictEvaluation = Invoke-Bw29nNuisanceTransferEvaluation -CellReceipts $strictImprovement
Assert-Bw29nZeroExact (
    [bool]$strictEvaluation["ok"] -and
    [int]$strictEvaluation["passed_gate_count"] -eq 12 -and
    [bool]$strictEvaluation["strict_total_improvement_passed"] -and
    [bool]$strictEvaluation["per_axis_non_regression_passed"] -and
    [string]$strictEvaluation["selected_candidate_id"] -ceq "BW29N-B" -and
    [bool]$strictEvaluation["fresh_nuisance_validation_ready"] -and
    -not [bool]$strictEvaluation["walking_acceptance"] -and
    -not [bool]$strictEvaluation["nuisance_acceptance"] -and
    -not [bool]$strictEvaluation["physical_acceptance_authority"]
) "BW29N strict-improvement selector control failed"

$walkingNegative = @(Copy-Bw29nZeroValue $perfect)
Set-Bw29nSyntheticWalkingFailure $walkingNegative "BW29N-B" "bw6n_sensor_noise_v1" 1
$walkingNegativeEvaluation = Invoke-Bw29nNuisanceTransferEvaluation -CellReceipts $walkingNegative
Assert-Bw29nZeroExact (
    [bool]$walkingNegativeEvaluation["ok"] -and
    [int]$walkingNegativeEvaluation["passed_gate_count"] -eq 12 -and
    (Get-Bw29nZeroGatePassed $walkingNegativeEvaluation "complete_development_result") -and
    [string]$walkingNegativeEvaluation["selected_candidate_id"] -ceq "NONE"
) "BW29N walking-negative cell was confused with an integrity failure"

$axisRegression = @(Copy-Bw29nZeroValue $perfect)
Set-Bw29nSyntheticWalkingFailure $axisRegression "BW29N-A" "bw6n_rough_v1" 2
Set-Bw29nSyntheticWalkingFailure $axisRegression "BW29N-A" "bw6n_push_v1" 1
Set-Bw29nSyntheticWalkingFailure $axisRegression "BW29N-B" "bw6n_baseline_v1" 1
$axisRegressionEvaluation = Invoke-Bw29nNuisanceTransferEvaluation -CellReceipts $axisRegression
Assert-Bw29nZeroExact (
    [bool]$axisRegressionEvaluation["ok"] -and
    [bool]$axisRegressionEvaluation["strict_total_improvement_passed"] -and
    -not [bool]$axisRegressionEvaluation["per_axis_non_regression_passed"] -and
    [string]$axisRegressionEvaluation["selected_candidate_id"] -ceq "NONE" -and
    -not [bool]$axisRegressionEvaluation["fresh_nuisance_validation_ready"]
) "BW29N paired-axis regression escaped the frozen selector"

$tie = @(Copy-Bw29nZeroValue $perfect)
Set-Bw29nSyntheticWalkingFailure $tie "BW29N-A" "bw6n_baseline_v1" 1
Set-Bw29nSyntheticWalkingFailure $tie "BW29N-B" "bw6n_baseline_v1" 1
$tieEvaluation = Invoke-Bw29nNuisanceTransferEvaluation -CellReceipts $tie
Assert-Bw29nZeroExact (
    [bool]$tieEvaluation["ok"] -and
    -not [bool]$tieEvaluation["strict_total_improvement_passed"] -and
    [string]$tieEvaluation["selected_candidate_id"] -ceq "NONE"
) "BW29N tied candidates did not select NONE"

$canaryCount = 0
function Invoke-Bw29nZeroCanary {
    param(
        [Parameter(Mandatory)][scriptblock]$Mutation,
        [Parameter(Mandatory)][string]$FailureCode,
        [Parameter(Mandatory)][string]$Label
    )
    $receipts = @(Copy-Bw29nZeroValue $perfect)
    $mutated = & $Mutation $receipts
    if ($null -ne $mutated) { $receipts = @($mutated) }
    Assert-Bw29nZeroEvaluationFailure $receipts $FailureCode $Label
    $script:canaryCount += 1
}

Invoke-Bw29nZeroCanary { param($r) @($r | Select-Object -Skip 1) } `
    "BW29N_CARDINALITY_INVALID" "missing receipt"
Invoke-Bw29nZeroCanary { param($r) $r[23] = Copy-Bw29nZeroValue $r[0] } `
    "BW29N_CARDINALITY_INVALID" "duplicate receipt"
Invoke-Bw29nZeroCanary { param($r) $r[0]["cell_id"] = "BW29N-UNDECLARED" } `
    "BW29N_CARDINALITY_INVALID" "unexpected receipt identity"
Invoke-Bw29nZeroCanary { param($r) $r[0]["candidate_composition_digest"] = "sha256:$('0' * 64)" } `
    "BW29N_IDENTITY_INVALID" "candidate composition digest"
$roughIndex = [array]::FindIndex([object[]]$perfect, [Predicate[object]]{
    param($receipt) [string]$receipt["challenge_profile_id"] -ceq "bw6n_rough_v1"
})
Assert-Bw29nZeroExact ($roughIndex -ge 0) "BW29N perfect fixture lacks rough profile"
Invoke-Bw29nZeroCanary { param($r) $r[$roughIndex]["terrain_shape_count"] = 1 } `
    "BW29N_CHALLENGE_INVALID" "rough challenge realization"
Invoke-Bw29nZeroCanary { param($r) $r[0]["measurement_gate_passed"] = $false } `
    "BW29N_MEASUREMENT_INVALID" "measurement acquisition"
Invoke-Bw29nZeroCanary { param($r) $r[0]["application_gate_passed"] = $false } `
    "BW29N_APPLICATION_INVALID" "candidate application"
Invoke-Bw29nZeroCanary { param($r) $r[0]["outcome_complete"] = $false } `
    "BW29N_OUTCOME_INCOMPLETE" "outcome completion"
Invoke-Bw29nZeroCanary { param($r) $r[0]["walking_claim_authorized"] = $true } `
    "BW29N_CLAIM_INFLATION" "claim inflation"

$godotActualPathCount = 0
$workerEntrypointCount = 0
$authorizationCanaryCount = 0
if (-not $SkipGodotActualPath) {
    $godotPath = [System.IO.Path]::GetFullPath($Godot)
    $runtimePath = $godotPath.Replace("_console.exe", ".exe")
    Assert-Bw29nZeroExact (
        (Test-Path -LiteralPath $godotPath -PathType Leaf) -and
        (Test-Path -LiteralPath $runtimePath -PathType Leaf) -and
        (Test-Path -LiteralPath $adapterPath -PathType Leaf)
    ) "BW29N pinned Godot or adapter artifact is missing"
    $godotVersion = (& $godotPath --version 2>&1 | Out-String).Trim()
    Assert-Bw29nZeroExact ($godotVersion -ceq "4.7.stable.mono.official.5b4e0cb0f") (
        "BW29N unexpected Godot version: $godotVersion"
    )

    $runToken = (Get-Date -Format "yyyyMMddTHHmmssfff") + "-" +
        [Guid]::NewGuid().ToString("N").Substring(0, 8)
    $tempRoot = Join-Path $sdkRoot "target\bw29n-nuisance-transfer-zero-world\$runToken"
    [void][System.IO.Directory]::CreateDirectory($tempRoot)
    $projectRoot = New-Bw29nIsolatedProject -Root $tempRoot
    $referencePreflight = Invoke-Bw29nWorkerPreflight -GodotPath $godotPath `
        -ProjectRoot $projectRoot -TempRoot $tempRoot `
        -WorkerResource "res://tests/test_sdk_balanced_wave_bw29n_reference_worker.gd" `
        -CandidateId "BW29N-A"
    $successorPreflight = Invoke-Bw29nWorkerPreflight -GodotPath $godotPath `
        -ProjectRoot $projectRoot -TempRoot $tempRoot `
        -WorkerResource "res://tests/test_sdk_balanced_wave_bw29n_successor_worker.gd" `
        -CandidateId "BW29N-B"
    Assert-Bw29nZeroExact (
        [int]$referencePreflight["entrypoint_count"] -eq 12 -and
        [int]$successorPreflight["entrypoint_count"] -eq 12 -and
        [int]$successorPreflight["adapter_start_count"] -eq 12
    ) "BW29N actual worker entrypoint matrix changed"
    $workerEntrypointCount = 24

    $attemptId = [Guid]::NewGuid().ToString("N")
    $token = [Guid]::NewGuid().ToString("N")
    $attempt = New-Bw29nAttemptRecord -Synthetic $true -AttemptId $attemptId `
        -AuthorizationToken $token -GodotVersion $godotVersion `
        -GodotSha256 (Get-Bw29nRawSha256 $godotPath) `
        -GodotRuntimeSha256 (Get-Bw29nRawSha256 $runtimePath) `
        -AdapterSha256 (Get-Bw29nRawSha256 $adapterPath)
    Assert-Bw29nZeroExact (Test-Bw29nAttemptRecord -Attempt $attempt -Synthetic $true) (
        "BW29N synthetic attempt constructor failed its exact parser"
    )
    $attemptPath = Join-Path $tempRoot "synthetic-attempt.json"
    Write-Bw29nUtf8NoBom -Path $attemptPath -Text (
        ($attempt | ConvertTo-Json -Depth 64) + [Environment]::NewLine
    )

    $manifest = Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -AsHashtable -Depth 64
    foreach ($candidateId in @("BW29N-A", "BW29N-B")) {
        $cell = @($manifest["ordered_cells"] | Where-Object {
            [string]$_["candidate_id"] -ceq $candidateId
        } | Select-Object -First 1)[0]
        $cellId = [string]$cell["cell_id"]
        $resource = if ($candidateId -ceq "BW29N-A") {
            "res://tests/test_sdk_balanced_wave_bw29n_reference_worker.gd"
        } else { "res://tests/test_sdk_balanced_wave_bw29n_successor_worker.gd" }
        $execution = Invoke-Bw29nGodotCaptured -GodotPath $godotPath -Arguments @(
            "--headless", "--path", $projectRoot,
            "--log-file", (Join-Path $tempRoot "$candidateId-authorization-engine.log"),
            "--script", $resource, "--", "authorization-preflight", $cellId
        ) -WorkerRoot (Join-Path $tempRoot "$candidateId-authorization") `
            -TimeoutSeconds 300 -AttemptPath $attemptPath -AuthorizationToken $token `
            -CellId $cellId -CandidateId $candidateId `
            -WorldAttemptId "BW29N-P1::$cellId" -CampaignAttemptId $attemptId
        $receipt = Get-Bw29nReceiptFromOutput -OutputText ([string]$execution["stdout"]) `
            -Prefix $receiptPrefix
        Assert-Bw29nZeroExact (
            [int]$execution["exit_code"] -eq 0 -and
            -not [bool]$execution["timed_out"] -and
            [bool]$receipt["ok"] -and [bool]$receipt["authorization_requested"] -and
            [bool]$receipt["authorization_exact"] -and
            [int]$receipt["actual_world_build_count"] -eq 0 -and
            [int]$receipt["scene_tree_insertion_count"] -eq 0 -and
            -not [bool]$receipt["physics_state_modified"] -and
            -not [bool]$receipt["locomotion_outcome_exposed"] -and
            -not [bool]$receipt["physical_acceptance_authority"]
        ) "BW29N $candidateId valid authorization preflight failed"
        $godotActualPathCount += 1
    }

    $firstCell = [System.Collections.IDictionary]$manifest["ordered_cells"][0]
    $firstCellId = [string]$firstCell["cell_id"]
    $wrongToken = Invoke-Bw29nGodotCaptured -GodotPath $godotPath -Arguments @(
        "--headless", "--path", $projectRoot,
        "--log-file", (Join-Path $tempRoot "wrong-token-engine.log"),
        "--script", "res://tests/test_sdk_balanced_wave_bw29n_reference_worker.gd",
        "--", "authorization-preflight", $firstCellId
    ) -WorkerRoot (Join-Path $tempRoot "wrong-token") -TimeoutSeconds 300 `
        -AttemptPath $attemptPath -AuthorizationToken ([Guid]::NewGuid().ToString("N")) `
        -CellId $firstCellId -CandidateId "BW29N-A" `
        -WorldAttemptId "BW29N-P1::$firstCellId" -CampaignAttemptId $attemptId
    $wrongTokenReceipt = Get-Bw29nReceiptFromOutput `
        -OutputText ([string]$wrongToken["stdout"]) -Prefix $receiptPrefix
    Assert-Bw29nZeroExact (
        [int]$wrongToken["exit_code"] -ne 0 -and
        -not [bool]$wrongTokenReceipt["ok"] -and
        -not [bool]$wrongTokenReceipt["authorization_exact"] -and
        [int]$wrongTokenReceipt["actual_world_build_count"] -eq 0
    ) "BW29N wrong-token authorization canary failed open"
    $authorizationCanaryCount += 1

    $directBypass = Invoke-Bw29nGodotCaptured -GodotPath $godotPath -Arguments @(
        "--headless", "--path", $projectRoot,
        "--log-file", (Join-Path $tempRoot "direct-bypass-engine.log"),
        "--script", "res://tests/test_sdk_balanced_wave_bw29n_reference_worker.gd",
        "--", "physical", $firstCellId
    ) -WorkerRoot (Join-Path $tempRoot "direct-bypass") -TimeoutSeconds 300
    Assert-Bw29nZeroExact (
        [int]$directBypass["exit_code"] -ne 0 -and
        -not ([string]$directBypass["stdout"]).Contains($rawPrefix, [StringComparison]::Ordinal)
    ) "BW29N direct worker bypass reached a raw physical receipt"
    $authorizationCanaryCount += 1
}

$attemptCanary = New-Bw29nAttemptRecord -Synthetic $true `
    -AttemptId ([Guid]::NewGuid().ToString("N")) `
    -AuthorizationToken ([Guid]::NewGuid().ToString("N")) `
    -GodotVersion "4.7.stable.mono.official.5b4e0cb0f" `
    -GodotSha256 "c5fc2d0bb24826a6757fa1e6bf2991effb294859c7dd03d09a122ef217484896" `
    -GodotRuntimeSha256 "baa909d0a905021da80cfc831713e9d3ba4bd0935ac3b93ba4c77dc140cfecc4" `
    -AdapterSha256 (Get-Bw29nRawSha256 $adapterPath)
Assert-Bw29nZeroExact (Test-Bw29nAttemptRecord $attemptCanary $true) (
    "BW29N synthetic attempt record did not pass"
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
    $candidate = [System.Collections.IDictionary](Copy-Bw29nZeroValue $attemptCanary)
    & $mutation $candidate
    Assert-Bw29nZeroExact (-not (Test-Bw29nAttemptRecord $candidate $true)) (
        "BW29N attempt-record canary failed open"
    )
    $attemptCanaryCount += 1
}

Write-Host (
    "BW29N_ZERO_WORLD_GATE_PASS gates=12 cells=24 evaluator_canaries=$canaryCount " +
    "attempt_canaries=$attemptCanaryCount authorization_canaries=$authorizationCanaryCount " +
    "worker_entrypoints=$workerEntrypointCount actual_authorizations=$godotActualPathCount " +
    "walking_negative_complete=True strict_selection=True axis_regression_veto=True " +
    "worlds=0 outcomes_exposed=False physical_authority=False"
)
