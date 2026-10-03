#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$manifestPath = Join-Path $sdkRoot "adapters\rapier\Cargo.toml"
$oraclePath = Join-Path $sdkRoot "turning\r23d2_oracle_preregistration.json"
$contractPath = Join-Path $sdkRoot "turning\r23d2_rapier_worker_contract_v1.json"
$developmentContractPath = Join-Path $sdkRoot "turning\r23d2_development_contract_v1.json"
$developmentEvaluatorPath = Join-Path $sdkRoot "turning\r23d2_development.py"
$sourcePath = Join-Path $sdkRoot "adapters\rapier\src\qsdk_r23d2_heading_response.rs"
$binarySourcePath = Join-Path $sdkRoot "adapters\rapier\src\bin\qsdk_r23d2_heading_response.rs"
$binaryPath = Join-Path $sdkRoot "target\debug\qsdk_r23d2_heading_response.exe"
$reproducibleRuntimePath = Join-Path $sdkRoot "r23d2_reproducible_runtime_materialization.ps1"
$preflightPrefix = "QSDK_R23D2_RAPIER_PREFLIGHT "
$failurePrefix = "QSDK_R23D2_RAPIER_FAILURE "
$cellPrefix = "QSDK_R23D2_RAPIER_CELL "
$campaignId = "QSDK-R23D2-THREE-ENGINE-HEADING-RESPONSE-DEVELOPMENT"
$gateId = "QSDK-R23D2-RAP"
$engineId = "rapier_parry"
$policyId = "sporespore_balanced_wave_bw5r_b_v1"
$morphologyId = "qsdk_r05_generated_s169"
$sourceCommit = "d9303df0e16dbbbdb35983f9632b5cfd0ff3061f"

function Assert-QsdkR23d2Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Invoke-QsdkR23d2RapierWorker {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$Label
    )
    $start = [System.Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $binaryPath
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in $Arguments) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $start
    Assert-QsdkR23d2Exact $process.Start() "QSDK-R23D2 failed to start $Label"
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit(60000)
    if ($timedOut) {
        $process.Kill($true)
        $process.WaitForExit()
    }
    return [ordered]@{
        label = $Label
        exit_code = $process.ExitCode
        timed_out = $timedOut
        stdout = $stdoutTask.GetAwaiter().GetResult()
        stderr = $stderrTask.GetAwaiter().GetResult()
    }
}

function Get-QsdkR23d2MarkerReceipt {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Execution,
        [Parameter(Mandatory)][string]$Prefix
    )
    $lines = @(([string]$Execution.stdout -split "`r?`n") | Where-Object {
        $_.StartsWith($Prefix, [System.StringComparison]::Ordinal)
    })
    Assert-QsdkR23d2Exact ($lines.Count -eq 1) (
        "QSDK-R23D2 expected one '$Prefix' marker from " +
        "$($Execution.label), found $($lines.Count)"
    )
    return $lines[0].Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

$evaluationRoot = Join-Path (
    $sdkRoot
) ("target\r23d2-rapier-worker-preflight-" + [guid]::NewGuid().ToString("N"))
$evaluationIndex = 0

function Test-QsdkR23d2EvaluatorEntry {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Entry,
        [Parameter(Mandatory)][string]$Label
    )
    $script:evaluationIndex += 1
    [void][System.IO.Directory]::CreateDirectory($evaluationRoot)
    $path = Join-Path $evaluationRoot (
        "entry-{0:D2}.json" -f $script:evaluationIndex
    )
    [System.IO.File]::WriteAllText(
        $path,
        ($Entry | ConvertTo-Json -Depth 100 -Compress),
        [System.Text.UTF8Encoding]::new($false)
    )
    $output = @(& python $developmentEvaluatorPath evaluate-entry $path 2>&1)
    $exitCode = $LASTEXITCODE
    $prefix = "QSDK_R23D2_ENTRY_EVALUATION "
    $lines = @($output | ForEach-Object { [string]$_ } | Where-Object {
        $_.StartsWith($prefix, [System.StringComparison]::Ordinal)
    })
    Assert-QsdkR23d2Exact (
        $exitCode -eq 0 -and $lines.Count -eq 1
    ) "QSDK-R23D2 evaluator rejected Rapier $Label`n$($output -join [Environment]::NewLine)"
    return $lines[0].Substring($prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Remove-QsdkR23d2EvaluationRoot {
    $resolvedEvaluationRoot = [System.IO.Path]::GetFullPath($evaluationRoot)
    $resolvedTargetRoot = [System.IO.Path]::GetFullPath((Join-Path $sdkRoot "target"))
    Assert-QsdkR23d2Exact (
        $resolvedEvaluationRoot.StartsWith(
            $resolvedTargetRoot + [System.IO.Path]::DirectorySeparatorChar,
            [System.StringComparison]::OrdinalIgnoreCase
        )
    ) "QSDK-R23D2 Rapier evaluation cleanup escaped sdk/target"
    if (Test-Path -LiteralPath $resolvedEvaluationRoot -PathType Container) {
        Remove-Item -LiteralPath $resolvedEvaluationRoot -Recurse -Force
    }
}

foreach ($path in @(
    $manifestPath,
    $oraclePath,
    $contractPath,
    $developmentContractPath,
    $developmentEvaluatorPath,
    $sourcePath,
    $binarySourcePath,
    $reproducibleRuntimePath
)) {
    Assert-QsdkR23d2Exact (Test-Path -LiteralPath $path -PathType Leaf) (
        "QSDK-R23D2 Rapier worker input missing: $path"
    )
}

. $reproducibleRuntimePath

$oracleSha256 = "sha256:" + (
    Get-FileHash -LiteralPath $oraclePath -Algorithm SHA256
).Hash.ToLowerInvariant()
$contractSha256 = "sha256:" + (
    Get-FileHash -LiteralPath $contractPath -Algorithm SHA256
).Hash.ToLowerInvariant()
$developmentContractSha256 = "sha256:" + (
    Get-FileHash -LiteralPath $developmentContractPath -Algorithm SHA256
).Hash.ToLowerInvariant()
$contract = Get-Content -Raw -LiteralPath $contractPath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-QsdkR23d2Exact (
    [string]$contract.schema_version -ceq
        "sporespore_qsdk_r23d2_rapier_worker_contract_v1" -and
    [string]$contract.status -ceq
        "rapier_supervisor_only_physical_authorized" -and
    [string]$contract.campaign_id -ceq $campaignId -and
    [string]$contract.gate_id -ceq $gateId -and
    [string]$contract.stage_zero_oracle.sha256 -ceq $oracleSha256 -and
    [string]$contract.stage_zero_oracle.source_commit -ceq $sourceCommit -and
    [string]$contract.engine.engine_id -ceq $engineId -and
    [bool]$contract.future_physical_requirements.physical_implementation_present -and
    [bool]$contract.future_physical_requirements.successful_report_canary_per_arm -and
    [bool]$contract.future_physical_requirements.all_six_failure_stage_canaries_per_arm -and
    [bool]$contract.future_physical_requirements.physical_world_loop_requires_exact_supervisor_authorization -and
    [string]$contract.future_physical_requirements.reproducible_worker_build.shared_helper_path -ceq
        "sdk/r23d2_reproducible_runtime_materialization.ps1" -and
    -not [bool]$contract.future_physical_requirements.reproducible_worker_build.cargo_incremental -and
    [string]$contract.future_physical_requirements.reproducible_worker_build.source_date_epoch -ceq
        "stage_zero_source_commit_epoch" -and
    [bool]$contract.future_physical_requirements.reproducible_worker_build.source_cargo_home_and_rust_sysroot_remapped -and
    [bool]$contract.future_physical_requirements.reproducible_worker_build.cargo_target_root_remapped_to_constant_virtual_prefix -and
    [bool]$contract.future_physical_requirements.reproducible_worker_build.msvc_brepro -and
    [bool]$contract.future_physical_requirements.reproducible_worker_build.pdb_alt_path_bare_name -and
    [bool]$contract.claim_boundary.rapier_worker_zero_world_commissioned -and
    [bool]$contract.claim_boundary.rapier_physical_worker_implemented -and
    [int]$contract.claim_boundary.actual_r23d2_engine_worker_count -eq 3 -and
    [int]$contract.claim_boundary.physical_worker_implementation_count -eq 3 -and
    [bool]$contract.claim_boundary.physical_workers_complete -and
    [bool]$contract.authorization.physical_execution_authorized -and
    [int]$contract.authorization.world_build_count -eq 0 -and
    -not [bool]$contract.authorization.physical_acceptance_authority -and
    -not [bool]$contract.claim_boundary.development_result_exists -and
    -not [bool]$contract.claim_boundary.scientific_result_exists -and
    -not [bool]$contract.claim_boundary.command_conditioned_turning -and
    -not [bool]$contract.claim_boundary.q_sdk_r23_satisfied -and
    -not [bool]$contract.claim_boundary.cross_engine_equivalence -and
    -not [bool]$contract.claim_boundary.release_authorized
) "QSDK-R23D2 Rapier worker contract identity or authority changed"

$testBuild = Invoke-SporeSporeR23D2PinnedCargo `
    -RepoRoot $repoRoot `
    -TargetRoot (Join-Path $sdkRoot "target") `
    -CargoArguments @(
        "test", "--quiet", "--locked", "--offline",
        "--manifest-path", $manifestPath,
        "--lib", "qsdk_r23d2_heading_response"
    )
$workerBuild = Invoke-SporeSporeR23D2PinnedCargo `
    -RepoRoot $repoRoot `
    -TargetRoot (Join-Path $sdkRoot "target") `
    -CargoArguments @(
        "build", "--quiet", "--locked", "--offline",
        "--manifest-path", $manifestPath,
        "--bin", "qsdk_r23d2_heading_response"
    )
Assert-QsdkR23d2Exact (Test-Path -LiteralPath $binaryPath -PathType Leaf) (
    "QSDK-R23D2 Rapier worker binary missing after build: $binaryPath"
)

$expectedOffsets = [ordered]@{
    reference_zero = 0.0
    positive_heading = 0.2
    negative_heading = -0.2
}
$aggregateCanaries = 0
$aggregateNonzero = 0
$aggregateLegacyRejections = 0
$aggregatePredicateControls = 0
$aggregateSteps = 0
$aggregateCommands = 0
$aggregateHostMappings = 0
$aggregateSuccessReportCanaries = 0
$aggregateFailureStageCanaries = 0
[void][System.IO.Directory]::CreateDirectory($evaluationRoot)
try {
    foreach ($entry in $expectedOffsets.GetEnumerator()) {
        $armId = [string]$entry.Key
        $execution = Invoke-QsdkR23d2RapierWorker `
            -Arguments @("--arm", $armId, "--preflight-only") -Label $armId
        Assert-QsdkR23d2Exact (
            -not [bool]$execution.timed_out -and [int]$execution.exit_code -eq 0
        ) "QSDK-R23D2 Rapier preflight failed: $armId`n$($execution.stderr)"
        $receipt = Get-QsdkR23d2MarkerReceipt $execution $preflightPrefix
        $invalidCanaries = @($receipt.canaries | Where-Object {
            @($_.failed_predicates).Count -ne 0 -or
            [int]$_.world_build_count -ne 0 -or
            [bool]$_.physical_acceptance_authority -or
            [string]$_.host_mapping_sha256 -notmatch '^sha256:[0-9a-f]{64}$'
        })
        $armBoundary = [System.Collections.IDictionary]$receipt.arm_command_boundary
        Assert-QsdkR23d2Exact (
            [string]$receipt.schema_version -ceq
                "sporespore_qsdk_r23d2_rapier_worker_preflight_v1" -and
            [string]$receipt.campaign_id -ceq $campaignId -and
            [string]$receipt.gate_id -ceq $gateId -and
            [string]$receipt.engine_id -ceq $engineId -and
            [string]$receipt.arm_id -ceq $armId -and
            [math]::Abs(
                [double]$receipt.arm_heading_offset_rad - [double]$entry.Value
            ) -le 1.0e-15 -and
            [string]$receipt.selected_policy_id -ceq $policyId -and
            [string]$receipt.morphology_id -ceq $morphologyId -and
            [string]$receipt.oracle_contract_sha256 -ceq $oracleSha256 -and
            [string]$receipt.worker_contract_sha256 -ceq $contractSha256 -and
            [string]$receipt.development_contract_sha256 -ceq
                $developmentContractSha256 -and
            [string]$receipt.worker_contract_status -ceq
                "rapier_supervisor_only_physical_authorized" -and
            [bool]$receipt.physical_implementation_present -and
            [string]$receipt.adapter_capability_sha256 -match
                '^sha256:[0-9a-f]{64}$' -and
            [int]$receipt.canary_count -eq 7 -and
            [int]$receipt.nonzero_cross_track_canary_count -eq 6 -and
            [int]$receipt.legacy_raw_offset_oracle_rejection_count -eq 6 -and
            [int]$receipt.predicate_negative_control_count -eq 35 -and
            [int]$receipt.native_controller_step_count -eq 8 -and
            [int]$receipt.native_command_count -eq 64 -and
            [int]$receipt.host_mapping_validation_count -eq 8 -and
            [math]::Abs(
                [double]$armBoundary.desired_heading_error_rad - [double]$entry.Value
            ) -le 1.0e-12 -and
            [math]::Abs(
                [double]$armBoundary.observed_heading_error_rad - [double]$entry.Value
            ) -le 1.0e-12 -and
            @($armBoundary.failed_predicates).Count -eq 0 -and
            [string]$armBoundary.host_mapping_sha256 -match
                '^sha256:[0-9a-f]{64}$' -and
            [int]$armBoundary.native_command_count -eq 8 -and
            [int]$armBoundary.world_build_count -eq 0 -and
            -not [bool]$armBoundary.physical_acceptance_authority -and
            $invalidCanaries.Count -eq 0 -and
            [int]$receipt.world_attempt_count -eq 0 -and
            [int]$receipt.world_build_count -eq 0 -and
            [bool]$receipt.physical_execution_authorized -and
            -not [bool]$receipt.q_sdk_r23_satisfied -and
            -not [bool]$receipt.physical_acceptance_authority
        ) "QSDK-R23D2 normalized Rapier preflight receipt changed: $armId"

        $successEvaluation = Test-QsdkR23d2EvaluatorEntry `
            -Entry ([System.Collections.IDictionary]$receipt.synthetic_physical_report) `
            -Label "$armId synthetic success report"
        Assert-QsdkR23d2Exact (
            [string]$successEvaluation.result_classification -ceq "valid_positive" -and
            [bool]$successEvaluation.entry_valid -and
            [bool]$successEvaluation.execution_valid -and
            [bool]$successEvaluation.screen_cell_passed -and
            [int]$successEvaluation.world_attempt_count -eq 1 -and
            [int]$successEvaluation.world_build_count -eq 1
        ) "QSDK-R23D2 Rapier success-report canary changed: $armId"
        $aggregateSuccessReportCanaries += 1

        $failureReceipts = @($receipt.synthetic_failure_receipts)
        Assert-QsdkR23d2Exact ($failureReceipts.Count -eq 6) (
            "QSDK-R23D2 Rapier failure-stage canary count changed: $armId"
        )
        $expectedStageCounts = [ordered]@{
            before_world = @(0, 0)
            world_construction_failed = @(1, 0)
            world_constructed = @(1, 1)
            settlement_complete = @(1, 1)
            cell_report_complete = @(1, 1)
            controller_validation_failed = @(1, 1)
        }
        foreach ($failureReceipt in $failureReceipts) {
            $stageId = [string]$failureReceipt.stage_id
            Assert-QsdkR23d2Exact ($expectedStageCounts.Contains($stageId)) (
                "QSDK-R23D2 Rapier emitted an unknown failure stage: $stageId"
            )
            $counts = @($expectedStageCounts[$stageId])
            $failureEvaluation = Test-QsdkR23d2EvaluatorEntry `
                -Entry ([System.Collections.IDictionary]$failureReceipt) `
                -Label "$armId $stageId failure"
            Assert-QsdkR23d2Exact (
                [string]$failureEvaluation.result_classification -ceq "worker_failure" -and
                [bool]$failureEvaluation.entry_valid -and
                -not [bool]$failureEvaluation.execution_valid -and
                [int]$failureEvaluation.world_attempt_count -eq [int]$counts[0] -and
                [int]$failureEvaluation.world_build_count -eq [int]$counts[1]
            ) "QSDK-R23D2 Rapier failure-stage evaluation changed: $armId $stageId"
            $aggregateFailureStageCanaries += 1
        }

        $aggregateCanaries += [int]$receipt.canary_count
        $aggregateNonzero += [int]$receipt.nonzero_cross_track_canary_count
        $aggregateLegacyRejections += [int]$receipt.legacy_raw_offset_oracle_rejection_count
        $aggregatePredicateControls += [int]$receipt.predicate_negative_control_count
        $aggregateSteps += [int]$receipt.native_controller_step_count
        $aggregateCommands += [int]$receipt.native_command_count
        $aggregateHostMappings += [int]$receipt.host_mapping_validation_count
    }
}
finally {
    Remove-QsdkR23d2EvaluationRoot
}
Assert-QsdkR23d2Exact (
    $aggregateCanaries -eq 21 -and
    $aggregateNonzero -eq 18 -and
    $aggregateLegacyRejections -eq 18 -and
    $aggregatePredicateControls -eq 105 -and
    $aggregateSteps -eq 24 -and
    $aggregateCommands -eq 192 -and
    $aggregateHostMappings -eq 24 -and
    $aggregateSuccessReportCanaries -eq 3 -and
    $aggregateFailureStageCanaries -eq 18
) "QSDK-R23D2 Rapier aggregate preflight counts changed"

$unknownExecution = Invoke-QsdkR23d2RapierWorker `
    -Arguments @("--arm", "undeclared_arm", "--preflight-only") `
    -Label "unknown-arm"
Assert-QsdkR23d2Exact (
    -not [bool]$unknownExecution.timed_out -and
    [int]$unknownExecution.exit_code -ne 0
) "QSDK-R23D2 unknown Rapier arm did not fail closed"
$unknown = Get-QsdkR23d2MarkerReceipt $unknownExecution $failurePrefix
Assert-QsdkR23d2Exact (
    [string]$unknown.failure_code -ceq
        "QSDK_R23D2_RAP_ARM_UNKNOWN:undeclared_arm" -and
    [int]$unknown.world_attempt_count -eq 0 -and
    [int]$unknown.world_build_count -eq 0 -and
    -not [bool]$unknown.physical_acceptance_authority
) "QSDK-R23D2 unknown-arm failure receipt changed"

$bypassExecution = Invoke-QsdkR23d2RapierWorker `
    -Arguments @(
        "--arm", "reference_zero", "--source-commit", ("0" * 40)
    ) -Label "physical-bypass"
Assert-QsdkR23d2Exact (
    -not [bool]$bypassExecution.timed_out -and
    [int]$bypassExecution.exit_code -ne 0
) "QSDK-R23D2 direct Rapier physical bypass did not fail closed"
$bypass = Get-QsdkR23d2MarkerReceipt $bypassExecution $failurePrefix
$cellMarkers = @(([string]$bypassExecution.stdout -split "`r?`n") | Where-Object {
    $_.StartsWith($cellPrefix, [System.StringComparison]::Ordinal)
})
Assert-QsdkR23d2Exact (
    [string]$bypass.process_failure_code -ceq
        "QSDK_R23D2_RAP_SUPERVISOR_AUTHORIZATION_INVALID" -and
    [string]$bypass.schema_version -ceq
        "sporespore_qsdk_r23d2_worker_failure_v1" -and
    [string]$bypass.campaign_id -ceq $campaignId -and
    [string]$bypass.gate_id -ceq "QSDK-R23D2" -and
    [string]$bypass.cell_id -ceq "rapier_parry__reference_zero" -and
    [string]$bypass.source_commit -ceq ("0" * 40) -and
    [string]$bypass.contract_sha256 -ceq $developmentContractSha256 -and
    [string]$bypass.stage_id -ceq "before_world" -and
    [int]$bypass.world_attempt_count -eq 0 -and
    [int]$bypass.world_build_count -eq 0 -and
    $cellMarkers.Count -eq 0 -and
    -not [bool]$bypass.claims.physical_acceptance_authority
) "QSDK-R23D2 direct Rapier physical bypass receipt changed"
try {
    $bypassEvaluation = Test-QsdkR23d2EvaluatorEntry `
        -Entry ([System.Collections.IDictionary]$bypass) -Label "physical bypass"
    Assert-QsdkR23d2Exact (
        [string]$bypassEvaluation.result_classification -ceq "worker_failure" -and
        [bool]$bypassEvaluation.entry_valid -and
        [int]$bypassEvaluation.world_attempt_count -eq 0 -and
        [int]$bypassEvaluation.world_build_count -eq 0
    ) "QSDK-R23D2 direct Rapier bypass evaluator receipt changed"
}
finally {
    Remove-QsdkR23d2EvaluationRoot
}

Write-Host (
    "QSDK_R23D2_RAPIER_WORKER_PASS arms=3 canaries=21 " +
    "nonzero_cross_track=18 legacy_oracle_rejections=18 " +
    "predicate_negative_controls=105 arm_command_boundaries=3 native_steps=24 " +
    "native_commands=192 host_mappings=24 success_reports=3/3 " +
    "failure_stages=18/18 physical_worker=True negative_controls=2 " +
    "supervisor_authorization=True worlds=0 physical_authority=False"
)
