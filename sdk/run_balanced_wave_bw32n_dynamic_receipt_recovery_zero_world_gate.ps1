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
$evaluatorPath = Join-Path $sdkRoot "balanced_wave_bw32n_dynamic_receipt_recovery_gate.ps1"
$supervisorPath = Join-Path $sdkRoot "run_balanced_wave_bw32n_dynamic_receipt_recovery.ps1"
$declarationAuditPath = Join-Path $repoRoot "tests\test_bw32n_dynamic_receipt_recovery_declaration.ps1"
$adapterPath = Join-Path $sdkRoot "target\debug\sporespore_godot_adapter.dll"
$receiptPrefix = "BW32N_DYNAMIC_RECEIPT_RECOVERY_WORKER_PREFLIGHT "
$rawPrefix = "BW32N_DYNAMIC_RECEIPT_RECOVERY_RAW_CELL "
$realShapedPrefix = "BW32N_DYNAMIC_RECEIPT_RECOVERY_REAL_SHAPED_RECEIPTS "

function Assert-Bw32nZeroExact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Copy-Bw32nZeroValue {
    param([Parameter(Mandatory)]$Value)
    return $Value | ConvertTo-Json -Depth 80 |
        ConvertFrom-Json -AsHashtable -Depth 80
}

function Get-Bw32nZeroGatePassed {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Evaluation,
        [Parameter(Mandatory)][string]$GateId
    )
    $gate = @($Evaluation["gates"] | Where-Object {
        [string]$_["gate_id"] -ceq $GateId
    })
    return $gate.Count -eq 1 -and [bool]$gate[0]["passed"]
}

function Set-Bw32nSyntheticWalkingFailure {
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
    Assert-Bw32nZeroExact ($Count -ge 0 -and $Count -le $matches.Count) (
        "BW32N synthetic walking-failure request exceeded the declared pair"
    )
    for ($index = 0; $index -lt $Count; $index += 1) {
        $matches[$index]["walking_observed"] = $false
        $matches[$index]["walking_gate_receipts"]["bounded_lateral_drift"] = $false
    }
}

function Assert-Bw32nZeroEvaluationFailure {
    param(
        [Parameter(Mandatory)][object[]]$Receipts,
        [Parameter(Mandatory)][string]$FailureCode,
        [Parameter(Mandatory)][string]$Label
    )
    $evaluation = Invoke-Bw32nRecoveryEvaluation -CellReceipts $Receipts
    Assert-Bw32nZeroExact (
        -not [bool]$evaluation["ok"] -and
        @($evaluation["failure_codes"]) -ccontains $FailureCode -and
        [string]$evaluation["selected_candidate_id"] -ceq "NONE" -and
        -not [bool]$evaluation["physical_acceptance_authority"]
    ) "BW32N evaluator canary failed open: $Label"
}

Assert-Bw32nZeroExact (Test-Path -LiteralPath $evaluatorPath -PathType Leaf) (
    "BW32N production evaluator is missing"
)
Assert-Bw32nZeroExact (Test-Path -LiteralPath $supervisorPath -PathType Leaf) (
    "BW32N supervisor is missing"
)
. $evaluatorPath
. $supervisorPath -PreflightOnly:$false -RunPhysical:$false -Godot $Godot

& pwsh -NoLogo -NoProfile -File $declarationAuditPath
Assert-Bw32nZeroExact ($LASTEXITCODE -eq 0) "BW32N declaration audit failed"

$perfect = @(New-Bw32nPerfectSyntheticReceiptSet)
$perfectEvaluation = Invoke-Bw32nRecoveryEvaluation -CellReceipts $perfect
Assert-Bw32nZeroExact (
    [bool]$perfectEvaluation["ok"] -and
    [string]$perfectEvaluation["status"] -ceq "complete_valid_development_result" -and
    [int]$perfectEvaluation["observed_world_count"] -eq 24 -and
    [int]$perfectEvaluation["passed_gate_count"] -eq 16 -and
    [int]$perfectEvaluation["failed_gate_count"] -eq 0 -and
    [string]$perfectEvaluation["selected_candidate_id"] -ceq "NONE" -and
    -not [bool]$perfectEvaluation["fresh_nuisance_validation_ready"] -and
    -not [bool]$perfectEvaluation["walking_acceptance"] -and
    -not [bool]$perfectEvaluation["nuisance_acceptance"] -and
    -not [bool]$perfectEvaluation["release_authorized"] -and
    -not [bool]$perfectEvaluation["physical_acceptance_authority"]
) "BW32N neutral perfect matrix did not pass 16/16 and select NONE"

# A walking-negative receipt is still a complete scientific result. With one
# A failure and twelve B passes, the frozen development selector may select B,
# but it still grants no acceptance or release authority.
$strictImprovement = @(Copy-Bw32nZeroValue $perfect)
Set-Bw32nSyntheticWalkingFailure $strictImprovement "BW32N-A" "bw6n_push_v1" 1
$strictEvaluation = Invoke-Bw32nRecoveryEvaluation -CellReceipts $strictImprovement
Assert-Bw32nZeroExact (
    [bool]$strictEvaluation["ok"] -and
    [int]$strictEvaluation["passed_gate_count"] -eq 16 -and
    [bool]$strictEvaluation["strict_total_improvement_passed"] -and
    [bool]$strictEvaluation["per_axis_non_regression_passed"] -and
    [string]$strictEvaluation["selected_candidate_id"] -ceq "BW32N-B" -and
    [bool]$strictEvaluation["fresh_nuisance_validation_ready"] -and
    -not [bool]$strictEvaluation["walking_acceptance"] -and
    -not [bool]$strictEvaluation["nuisance_acceptance"] -and
    -not [bool]$strictEvaluation["physical_acceptance_authority"]
) "BW32N strict-improvement selector control failed"

$walkingNegative = @(Copy-Bw32nZeroValue $perfect)
Set-Bw32nSyntheticWalkingFailure $walkingNegative "BW32N-B" "bw6n_sensor_noise_v1" 1
$walkingNegativeEvaluation = Invoke-Bw32nRecoveryEvaluation -CellReceipts $walkingNegative
Assert-Bw32nZeroExact (
    [bool]$walkingNegativeEvaluation["ok"] -and
    [int]$walkingNegativeEvaluation["passed_gate_count"] -eq 16 -and
    (Get-Bw32nZeroGatePassed $walkingNegativeEvaluation "complete_development_result") -and
    [string]$walkingNegativeEvaluation["selected_candidate_id"] -ceq "NONE"
) "BW32N walking-negative cell was confused with an integrity failure"

$axisRegression = @(Copy-Bw32nZeroValue $perfect)
Set-Bw32nSyntheticWalkingFailure $axisRegression "BW32N-A" "bw6n_rough_v1" 2
Set-Bw32nSyntheticWalkingFailure $axisRegression "BW32N-A" "bw6n_push_v1" 1
Set-Bw32nSyntheticWalkingFailure $axisRegression "BW32N-B" "bw6n_baseline_v1" 1
$axisRegressionEvaluation = Invoke-Bw32nRecoveryEvaluation -CellReceipts $axisRegression
Assert-Bw32nZeroExact (
    [bool]$axisRegressionEvaluation["ok"] -and
    [bool]$axisRegressionEvaluation["strict_total_improvement_passed"] -and
    -not [bool]$axisRegressionEvaluation["per_axis_non_regression_passed"] -and
    [string]$axisRegressionEvaluation["selected_candidate_id"] -ceq "NONE" -and
    -not [bool]$axisRegressionEvaluation["fresh_nuisance_validation_ready"]
) "BW32N paired-axis regression escaped the frozen selector"

$tie = @(Copy-Bw32nZeroValue $perfect)
Set-Bw32nSyntheticWalkingFailure $tie "BW32N-A" "bw6n_baseline_v1" 1
Set-Bw32nSyntheticWalkingFailure $tie "BW32N-B" "bw6n_baseline_v1" 1
$tieEvaluation = Invoke-Bw32nRecoveryEvaluation -CellReceipts $tie
Assert-Bw32nZeroExact (
    [bool]$tieEvaluation["ok"] -and
    -not [bool]$tieEvaluation["strict_total_improvement_passed"] -and
    [string]$tieEvaluation["selected_candidate_id"] -ceq "NONE"
) "BW32N tied candidates did not select NONE"

$canaryCount = 0
function Invoke-Bw32nZeroCanary {
    param(
        [Parameter(Mandatory)][scriptblock]$Mutation,
        [Parameter(Mandatory)][string]$FailureCode,
        [Parameter(Mandatory)][string]$Label
    )
    $receipts = @(Copy-Bw32nZeroValue $perfect)
    $mutated = & $Mutation $receipts
    if ($null -ne $mutated) { $receipts = @($mutated) }
    Assert-Bw32nZeroEvaluationFailure $receipts $FailureCode $Label
    $script:canaryCount += 1
}

Invoke-Bw32nZeroCanary { param($r) @($r | Select-Object -Skip 1) } `
    "BW32N_CARDINALITY_INVALID" "missing receipt"
Invoke-Bw32nZeroCanary { param($r) $r[23] = Copy-Bw32nZeroValue $r[0] } `
    "BW32N_CARDINALITY_INVALID" "duplicate receipt"
Invoke-Bw32nZeroCanary { param($r) $r[0]["cell_id"] = "BW32N-UNDECLARED" } `
    "BW32N_CARDINALITY_INVALID" "unexpected receipt identity"
Invoke-Bw32nZeroCanary { param($r) $r[0]["candidate_base_composition_digest"] = "sha256:$('0' * 64)" } `
    "BW32N_IDENTITY_INVALID" "candidate composition digest"
Invoke-Bw32nZeroCanary { param($r) [void]$r[0].Remove("material_profile_sha256") } `
    "BW32N_RECEIPT_SCHEMA_INVALID" "missing shared receipt field"
Invoke-Bw32nZeroCanary { param($r) $r[0]["material_profile_digest"] = $r[0]["material_profile_sha256"] } `
    "BW32N_RECEIPT_SCHEMA_INVALID" "candidate-specific legacy receipt alias"
Invoke-Bw32nZeroCanary { param($r) $r[0]["dynamic_parent_summary_gate_passed"] = $false } `
    "BW32N_DYNAMIC_PARENT_SUMMARY_INVALID" "dynamic parent projection"
Invoke-Bw32nZeroCanary {
    param($r)
    [void]$r[0]["walking_gate_receipts"].Remove("sdk_stability_overlay_evidence_actuation")
    $r[0]["walking_gate_receipts"]["native_sdk_exclusive_post_settle_actuation"] = $true
} "BW32N_DYNAMIC_PARENT_SUMMARY_INVALID" "cross-route nested walking schema"
Invoke-Bw32nZeroCanary { param($r) $r[0]["candidate_authority_observation_count"] = 3231 } `
    "BW32N_HORIZON_INVALID" "candidate-dependent short horizon"
Invoke-Bw32nZeroCanary { param($r) $r[0]["candidate_specific_horizon_extension_count"] = 1 } `
    "BW32N_HORIZON_INVALID" "candidate-specific horizon extension"
Invoke-Bw32nZeroCanary { param($r) $r[0]["pre_authority_world_tick_count"] += 1 } `
    "BW32N_PRE_AUTHORITY_INVALID" "pre-authority tick exclusion"
$roughIndex = [array]::FindIndex([object[]]$perfect, [Predicate[object]]{
    param($receipt) [string]$receipt["challenge_profile_id"] -ceq "bw6n_rough_v1"
})
Assert-Bw32nZeroExact ($roughIndex -ge 0) "BW32N perfect fixture lacks rough profile"
Invoke-Bw32nZeroCanary { param($r) $r[$roughIndex]["terrain_shape_count"] = 1 } `
    "BW32N_CHALLENGE_INVALID" "rough challenge realization"
Invoke-Bw32nZeroCanary { param($r) $r[0]["measurement_gate_passed"] = $false } `
    "BW32N_MEASUREMENT_INVALID" "measurement acquisition"
Invoke-Bw32nZeroCanary { param($r) $r[0]["application_gate_passed"] = $false } `
    "BW32N_APPLICATION_INVALID" "candidate application"
Invoke-Bw32nZeroCanary { param($r) $r[0]["outcome_complete"] = $false } `
    "BW32N_OUTCOME_INCOMPLETE" "outcome completion"
Invoke-Bw32nZeroCanary { param($r) $r[0]["walking_claim_authorized"] = $true } `
    "BW32N_CLAIM_INFLATION" "claim inflation"

$godotActualPathCount = 0
$workerEntrypointCount = 0
$realShapedReceiptCount = 0
$authorizationCanaryCount = 0
if (-not $SkipGodotActualPath) {
    $godotPath = [System.IO.Path]::GetFullPath($Godot)
    $runtimePath = $godotPath.Replace("_console.exe", ".exe")
    Assert-Bw32nZeroExact (
        (Test-Path -LiteralPath $godotPath -PathType Leaf) -and
        (Test-Path -LiteralPath $runtimePath -PathType Leaf) -and
        (Test-Path -LiteralPath $adapterPath -PathType Leaf)
    ) "BW32N pinned Godot or adapter artifact is missing"
    $godotVersion = (& $godotPath --version 2>&1 | Out-String).Trim()
    Assert-Bw32nZeroExact ($godotVersion -ceq "4.7.stable.mono.official.5b4e0cb0f") (
        "BW32N unexpected Godot version: $godotVersion"
    )

    $runToken = (Get-Date -Format "yyyyMMddTHHmmssfff") + "-" +
        [Guid]::NewGuid().ToString("N").Substring(0, 8)
    $tempRoot = Join-Path $sdkRoot "target\bw32n-recovery-zero-world\$runToken"
    [void][System.IO.Directory]::CreateDirectory($tempRoot)
    $projectRoot = New-Bw32nIsolatedProject -Root $tempRoot
    $referencePreflight = Invoke-Bw32nWorkerPreflight -GodotPath $godotPath `
        -ProjectRoot $projectRoot -TempRoot $tempRoot `
        -WorkerResource "res://tests/test_sdk_balanced_wave_bw32n_reference_worker.gd" `
        -CandidateId "BW32N-A"
    $successorPreflight = Invoke-Bw32nWorkerPreflight -GodotPath $godotPath `
        -ProjectRoot $projectRoot -TempRoot $tempRoot `
        -WorkerResource "res://tests/test_sdk_balanced_wave_bw32n_successor_worker.gd" `
        -CandidateId "BW32N-B"
    Assert-Bw32nZeroExact (
        [int]$referencePreflight["entrypoint_count"] -eq 12 -and
        [int]$successorPreflight["entrypoint_count"] -eq 12 -and
        [int]$successorPreflight["adapter_start_count"] -eq 12
    ) "BW32N actual worker entrypoint matrix changed"
    $workerEntrypointCount = 24

    $realShapedReceipts = [System.Collections.Generic.List[object]]::new()
    foreach ($route in @(
        [ordered]@{
            candidate_id = "BW32N-A"
            resource = "res://tests/test_sdk_balanced_wave_bw32n_reference_worker.gd"
        },
        [ordered]@{
            candidate_id = "BW32N-B"
            resource = "res://tests/test_sdk_balanced_wave_bw32n_successor_worker.gd"
        }
    )) {
        $candidateId = [string]$route["candidate_id"]
        $execution = Invoke-Bw32nGodotCaptured -GodotPath $godotPath -Arguments @(
            "--headless", "--path", $projectRoot,
            "--log-file", (Join-Path $tempRoot "$candidateId-real-shaped-engine.log"),
            "--script", [string]$route["resource"], "--", "receipt-preflight-all"
        ) -WorkerRoot (Join-Path $tempRoot "$candidateId-real-shaped") -TimeoutSeconds 300
        $aggregate = Get-Bw32nReceiptFromOutput `
            -OutputText ([string]$execution["stdout"]) -Prefix $realShapedPrefix
        Assert-Bw32nZeroExact (
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
        ) "BW32N $candidateId real-shaped receipt preflight failed"
        foreach ($receipt in @($aggregate["cell_receipts"])) {
            [void]$realShapedReceipts.Add($receipt)
        }
    }
    $realShapedEvaluation = Invoke-Bw32nRecoveryEvaluation `
        -CellReceipts @($realShapedReceipts)
    $walkingNegativeCount = @(
        $realShapedReceipts | Where-Object { -not [bool]$_["walking_observed"] }
    ).Count
    Assert-Bw32nZeroExact (
        $realShapedReceipts.Count -eq 24 -and
        $walkingNegativeCount -eq 2 -and
        [bool]$realShapedEvaluation["ok"] -and
        [int]$realShapedEvaluation["passed_gate_count"] -eq 16 -and
        [string]$realShapedEvaluation["selected_candidate_id"] -ceq "NONE" -and
        -not [bool]$realShapedEvaluation["physical_acceptance_authority"]
    ) "BW32N actual A/B real-shaped receipts did not pass the complete evaluator"
    $realShapedReceiptCount = $realShapedReceipts.Count

    $attemptId = [Guid]::NewGuid().ToString("N")
    $token = [Guid]::NewGuid().ToString("N")
    $attempt = New-Bw32nAttemptRecord -Synthetic $true -AttemptId $attemptId `
        -AuthorizationToken $token -GodotVersion $godotVersion `
        -GodotSha256 (Get-Bw32nRawSha256 $godotPath) `
        -GodotRuntimeSha256 (Get-Bw32nRawSha256 $runtimePath) `
        -AdapterSha256 (Get-Bw32nRawSha256 $adapterPath)
    Assert-Bw32nZeroExact (Test-Bw32nAttemptRecord -Attempt $attempt -Synthetic $true) (
        "BW32N synthetic attempt constructor failed its exact parser"
    )
    $attemptPath = Join-Path $tempRoot "synthetic-attempt.json"
    Write-Bw32nUtf8NoBom -Path $attemptPath -Text (
        ($attempt | ConvertTo-Json -Depth 64) + [Environment]::NewLine
    )

    $manifest = Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -AsHashtable -Depth 64
    foreach ($candidateId in @("BW32N-A", "BW32N-B")) {
        $cell = @($manifest["ordered_cells"] | Where-Object {
            [string]$_["candidate_id"] -ceq $candidateId
        } | Select-Object -First 1)[0]
        $cellId = [string]$cell["cell_id"]
        $resource = if ($candidateId -ceq "BW32N-A") {
            "res://tests/test_sdk_balanced_wave_bw32n_reference_worker.gd"
        } else { "res://tests/test_sdk_balanced_wave_bw32n_successor_worker.gd" }
        $execution = Invoke-Bw32nGodotCaptured -GodotPath $godotPath -Arguments @(
            "--headless", "--path", $projectRoot,
            "--log-file", (Join-Path $tempRoot "$candidateId-authorization-engine.log"),
            "--script", $resource, "--", "authorization-preflight", $cellId
        ) -WorkerRoot (Join-Path $tempRoot "$candidateId-authorization") `
            -TimeoutSeconds 300 -AttemptPath $attemptPath -AuthorizationToken $token `
            -CellId $cellId -CandidateId $candidateId `
            -WorldAttemptId "BW32N-P1::$cellId" -CampaignAttemptId $attemptId
        $receipt = Get-Bw32nReceiptFromOutput -OutputText ([string]$execution["stdout"]) `
            -Prefix $receiptPrefix
        Assert-Bw32nZeroExact (
            [int]$execution["exit_code"] -eq 0 -and
            -not [bool]$execution["timed_out"] -and
            [bool]$receipt["ok"] -and [bool]$receipt["authorization_requested"] -and
            [bool]$receipt["authorization_exact"] -and
            [int]$receipt["actual_world_build_count"] -eq 0 -and
            [int]$receipt["scene_tree_insertion_count"] -eq 0 -and
            -not [bool]$receipt["physics_state_modified"] -and
            -not [bool]$receipt["locomotion_outcome_exposed"] -and
            -not [bool]$receipt["physical_acceptance_authority"]
        ) "BW32N $candidateId valid authorization preflight failed"
        $godotActualPathCount += 1
    }

    $firstCell = [System.Collections.IDictionary]$manifest["ordered_cells"][0]
    $firstCellId = [string]$firstCell["cell_id"]
    $wrongToken = Invoke-Bw32nGodotCaptured -GodotPath $godotPath -Arguments @(
        "--headless", "--path", $projectRoot,
        "--log-file", (Join-Path $tempRoot "wrong-token-engine.log"),
        "--script", "res://tests/test_sdk_balanced_wave_bw32n_reference_worker.gd",
        "--", "authorization-preflight", $firstCellId
    ) -WorkerRoot (Join-Path $tempRoot "wrong-token") -TimeoutSeconds 300 `
        -AttemptPath $attemptPath -AuthorizationToken ([Guid]::NewGuid().ToString("N")) `
        -CellId $firstCellId -CandidateId "BW32N-A" `
        -WorldAttemptId "BW32N-P1::$firstCellId" -CampaignAttemptId $attemptId
    $wrongTokenReceipt = Get-Bw32nReceiptFromOutput `
        -OutputText ([string]$wrongToken["stdout"]) -Prefix $receiptPrefix
    Assert-Bw32nZeroExact (
        [int]$wrongToken["exit_code"] -ne 0 -and
        -not [bool]$wrongTokenReceipt["ok"] -and
        -not [bool]$wrongTokenReceipt["authorization_exact"] -and
        [int]$wrongTokenReceipt["actual_world_build_count"] -eq 0
    ) "BW32N wrong-token authorization canary failed open"
    $authorizationCanaryCount += 1

    $directBypass = Invoke-Bw32nGodotCaptured -GodotPath $godotPath -Arguments @(
        "--headless", "--path", $projectRoot,
        "--log-file", (Join-Path $tempRoot "direct-bypass-engine.log"),
        "--script", "res://tests/test_sdk_balanced_wave_bw32n_reference_worker.gd",
        "--", "physical", $firstCellId
    ) -WorkerRoot (Join-Path $tempRoot "direct-bypass") -TimeoutSeconds 300
    Assert-Bw32nZeroExact (
        [int]$directBypass["exit_code"] -ne 0 -and
        -not ([string]$directBypass["stdout"]).Contains($rawPrefix, [StringComparison]::Ordinal)
    ) "BW32N direct worker bypass reached a raw physical receipt"
    $authorizationCanaryCount += 1
}

$attemptCanary = New-Bw32nAttemptRecord -Synthetic $true `
    -AttemptId ([Guid]::NewGuid().ToString("N")) `
    -AuthorizationToken ([Guid]::NewGuid().ToString("N")) `
    -GodotVersion "4.7.stable.mono.official.5b4e0cb0f" `
    -GodotSha256 "c5fc2d0bb24826a6757fa1e6bf2991effb294859c7dd03d09a122ef217484896" `
    -GodotRuntimeSha256 "baa909d0a905021da80cfc831713e9d3ba4bd0935ac3b93ba4c77dc140cfecc4" `
    -AdapterSha256 (Get-Bw32nRawSha256 $adapterPath)
Assert-Bw32nZeroExact (Test-Bw32nAttemptRecord $attemptCanary $true) (
    "BW32N synthetic attempt record did not pass"
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
    $candidate = [System.Collections.IDictionary](Copy-Bw32nZeroValue $attemptCanary)
    & $mutation $candidate
    Assert-Bw32nZeroExact (-not (Test-Bw32nAttemptRecord $candidate $true)) (
        "BW32N attempt-record canary failed open"
    )
    $attemptCanaryCount += 1
}

Write-Host (
    "BW32N_ZERO_WORLD_GATE_PASS gates=16 cells=24 evaluator_canaries=$canaryCount " +
    "attempt_canaries=$attemptCanaryCount authorization_canaries=$authorizationCanaryCount " +
    "worker_entrypoints=$workerEntrypointCount actual_authorizations=$godotActualPathCount " +
    "real_shaped_receipts=$realShapedReceiptCount shared_composer=True authority_horizon=3232 " +
    "walking_negative_complete=True strict_selection=True axis_regression_veto=True " +
    "worlds=0 outcomes_exposed=False physical_authority=False"
)
