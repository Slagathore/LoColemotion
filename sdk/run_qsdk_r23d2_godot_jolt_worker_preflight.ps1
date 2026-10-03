#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$Python = "python"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$manifestPath = Join-Path $sdkRoot "Cargo.toml"
$oraclePath = Join-Path $sdkRoot "turning\r23d2_oracle_preregistration.json"
$contractPath = Join-Path $sdkRoot "turning\r23d2_godot_jolt_worker_contract_v1.json"
$developmentContractPath = Join-Path $sdkRoot "turning\r23d2_development_contract_v1.json"
$developmentEvaluatorPath = Join-Path $sdkRoot "turning\r23d2_development.py"
$workerPath = Join-Path $repoRoot "tests\test_sdk_qsdk_r23d2_godot_jolt_worker.gd"
$adapterPath = Join-Path $repoRoot "scripts\lab\gait\sdk_godot_jolt_adapter.gd"
$adapterArtifactPath = Join-Path $sdkRoot "target\debug\sporespore_godot_adapter.dll"
$reproducibleRuntimePath = Join-Path $sdkRoot "r23d2_reproducible_runtime_materialization.ps1"
$workerResource = "res://tests/test_sdk_qsdk_r23d2_godot_jolt_worker.gd"
$preflightPrefix = "QSDK_R23D2_GODOT_JOLT_PREFLIGHT "
$failurePrefix = "QSDK_R23D2_GODOT_JOLT_FAILURE "
$cellPrefix = "QSDK_R23D2_GODOT_JOLT_CELL "
$campaignId = "QSDK-R23D2-THREE-ENGINE-HEADING-RESPONSE-DEVELOPMENT"
$gateId = "QSDK-R23D2-GJT"
$engineId = "godot_jolt"
$policyId = "sporespore_balanced_wave_bw5r_b_v1"
$morphologyId = "qsdk_r05_generated_s169"
$sourceCommit = "d9303df0e16dbbbdb35983f9632b5cfd0ff3061f"

function Assert-QsdkR23d2Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Invoke-QsdkR23d2GodotJoltWorker {
    param(
        [Parameter(Mandatory)][string[]]$UserArguments,
        [Parameter(Mandatory)][string]$Label
    )
    $runRoot = Join-Path $sdkRoot (
        "target\qsdk-r23d2-godot-jolt-preflight\" +
        [guid]::NewGuid().ToString("N")
    )
    $appData = Join-Path $runRoot "appdata"
    $localAppData = Join-Path $runRoot "localappdata"
    $logPath = Join-Path $runRoot "$Label-godot.log"
    [void][IO.Directory]::CreateDirectory($appData)
    [void][IO.Directory]::CreateDirectory($localAppData)

    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $Godot
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.Environment["APPDATA"] = $appData
    $start.Environment["LOCALAPPDATA"] = $localAppData
    foreach ($environmentVariable in @(
        "SPORESPORE_QSDK_R23D2_ATTEMPT",
        "SPORESPORE_QSDK_R23D2_TOKEN",
        "SPORESPORE_QSDK_R23D2_CELL",
        "SPORESPORE_QSDK_R23D2_ENGINE",
        "SPORESPORE_QSDK_R23D2_GODOT_JOLT_ORACLE_TRACE"
    )) {
        $start.Environment[$environmentVariable] = ""
    }
    foreach ($argument in @(
        "--headless",
        "--path", $repoRoot,
        "--log-file", $logPath,
        "--script", $workerResource,
        "--"
    ) + $UserArguments) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    Assert-QsdkR23d2Exact $process.Start() (
        "QSDK-R23D2 failed to start Godot/Jolt worker: $Label"
    )
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
        log_path = $logPath
    }
}

function Assert-QsdkR23d2CleanGodotExecution {
    param([Parameter(Mandatory)][Collections.IDictionary]$Execution)
    $combined = [string]$Execution.stdout + [Environment]::NewLine +
        [string]$Execution.stderr
    Assert-QsdkR23d2Exact (-not [bool]$Execution.timed_out) (
        "QSDK-R23D2 Godot/Jolt worker timed out: $($Execution.label)"
    )
    Assert-QsdkR23d2Exact (
        $combined -cnotmatch "(?m)SCRIPT ERROR|Parse Error|ERROR:"
    ) (
        "QSDK-R23D2 Godot/Jolt worker emitted an engine error: " +
        "$($Execution.label); log=$($Execution.log_path)"
    )
}

function Get-QsdkR23d2MarkerReceipt {
    param(
        [Parameter(Mandatory)][Collections.IDictionary]$Execution,
        [Parameter(Mandatory)][string]$Prefix
    )
    $lines = @(([string]$Execution.stdout -split "`r?`n") | Where-Object {
        $_.StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-QsdkR23d2Exact ($lines.Count -eq 1) (
        "QSDK-R23D2 expected one '$Prefix' marker from " +
        "$($Execution.label), found $($lines.Count)"
    )
    return $lines[0].Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

$evaluationRoot = Join-Path $sdkRoot (
    "target\r23d2-godot-jolt-worker-preflight-" + [guid]::NewGuid().ToString("N")
)
$evaluationIndex = 0

function Test-QsdkR23d2EvaluatorEntry {
    param(
        [Parameter(Mandatory)][Collections.IDictionary]$Entry,
        [Parameter(Mandatory)][string]$Label
    )
    $script:evaluationIndex += 1
    [void][IO.Directory]::CreateDirectory($evaluationRoot)
    $path = Join-Path $evaluationRoot (
        "entry-{0:D2}.json" -f $script:evaluationIndex
    )
    [IO.File]::WriteAllText(
        $path,
        ($Entry | ConvertTo-Json -Depth 100 -Compress),
        [Text.UTF8Encoding]::new($false)
    )
    $output = @(& $Python $developmentEvaluatorPath evaluate-entry $path 2>&1)
    $exitCode = $LASTEXITCODE
    $prefix = "QSDK_R23D2_ENTRY_EVALUATION "
    $lines = @($output | ForEach-Object { [string]$_ } | Where-Object {
        $_.StartsWith($prefix, [StringComparison]::Ordinal)
    })
    Assert-QsdkR23d2Exact (
        $exitCode -eq 0 -and $lines.Count -eq 1
    ) "QSDK-R23D2 evaluator rejected Godot/Jolt $Label`n$($output -join [Environment]::NewLine)"
    return $lines[0].Substring($prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Remove-QsdkR23d2EvaluationRoot {
    $resolvedEvaluationRoot = [IO.Path]::GetFullPath($evaluationRoot)
    $resolvedTargetRoot = [IO.Path]::GetFullPath((Join-Path $sdkRoot "target"))
    Assert-QsdkR23d2Exact (
        $resolvedEvaluationRoot.StartsWith(
            $resolvedTargetRoot + [IO.Path]::DirectorySeparatorChar,
            [StringComparison]::OrdinalIgnoreCase
        )
    ) "QSDK-R23D2 Godot/Jolt evaluation cleanup escaped sdk/target"
    if (Test-Path -LiteralPath $resolvedEvaluationRoot -PathType Container) {
        Remove-Item -LiteralPath $resolvedEvaluationRoot -Recurse -Force
    }
}

$pythonCommand = @(
    Get-Command -Name $Python -CommandType Application -ErrorAction SilentlyContinue |
        Where-Object { Test-Path -LiteralPath $_.Source -PathType Leaf }
) | Select-Object -First 1
Assert-QsdkR23d2Exact ($null -ne $pythonCommand) (
    "QSDK-R23D2 Godot/Jolt evaluator Python command is unavailable: $Python"
)
$Python = [IO.Path]::GetFullPath([string]$pythonCommand.Source)

foreach ($path in @(
    $Godot,
    $Python,
    $manifestPath,
    $oraclePath,
    $contractPath,
    $developmentContractPath,
    $developmentEvaluatorPath,
    $workerPath,
    $adapterPath
)) {
    Assert-QsdkR23d2Exact (Test-Path -LiteralPath $path -PathType Leaf) (
        "QSDK-R23D2 Godot/Jolt worker input missing: $path"
    )
}
Assert-QsdkR23d2Exact (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D2 Godot/Jolt worker repository identity mismatch"

$workerSource = Get-Content -Raw -LiteralPath $workerPath
$adapterSource = Get-Content -Raw -LiteralPath $adapterPath
Assert-QsdkR23d2Exact (
    $workerSource -cnotmatch "test_sdk_qsdk_r23d1_godot_jolt_worker" -and
    $workerSource -cmatch "WaveGaitScript" -and
    $workerSource -cmatch "_physical_authorization_exact" -and
    $workerSource -cmatch "_validate_physical_oracle_trace" -and
    $workerSource -cmatch "_validate_preflight_oracle_trace" -and
    $workerSource -cmatch "_synthetic_physical_report" -and
    $workerSource -cmatch "_synthetic_failure_receipts" -and
    $workerSource -cmatch "_emit_worker_failure" -and
    $workerSource -cmatch "SPORESPORE_QSDK_R23D2_ATTEMPT" -and
    $workerSource -cmatch "SPORESPORE_QSDK_R23D2_GODOT_JOLT_ORACLE_TRACE" -and
    $adapterSource -cmatch (
        "func preflight_explicit_balanced_wave_heading_runtime_boundary"
    ) -and
    $adapterSource -cmatch "func _record_r23d2_oracle_trace" -and
    $adapterSource -cmatch "SPORESPORE_QSDK_R23D2_GODOT_JOLT_ORACLE_TRACE" -and
    $adapterSource -cmatch '"state_frame_sha256"' -and
    $adapterSource -cmatch '"motion_command_sha256"' -and
    $adapterSource -cmatch '"controller_receipt_sha256"' -and
    $adapterSource -cmatch "var authority_receipt := apply_authority\(" -and
    $adapterSource -cmatch "var joint := HingeJoint3D\.new\(\)" -and
    $adapterSource -cmatch "joint\.get_param\(" -and
    $adapterSource -cmatch "joint\.free\(\)"
) "QSDK-R23D2 Godot/Jolt worker source boundary changed"

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
        "sporespore_qsdk_r23d2_godot_jolt_worker_contract_v1" -and
    [string]$contract.status -ceq
        "godot_jolt_supervisor_only_physical_authorized" -and
    [string]$contract.campaign_id -ceq $campaignId -and
    [string]$contract.gate_id -ceq $gateId -and
    [string]$contract.stage_zero_oracle.sha256 -ceq $oracleSha256 -and
    [string]$contract.stage_zero_oracle.source_commit -ceq $sourceCommit -and
    [string]$contract.engine.engine_id -ceq $engineId -and
    [string]$contract.engine.physics_engine -ceq "Jolt Physics" -and
    [string]$contract.engine.adapter_id -ceq "godot_jolt_gdextension_v1" -and
    [bool]$contract.future_physical_requirements.physical_implementation_present -and
    [bool]$contract.future_physical_requirements.successful_report_canary_per_arm -and
    [bool]$contract.future_physical_requirements.all_six_failure_stage_canaries_per_arm -and
    [bool]$contract.future_physical_requirements.physical_world_loop_requires_exact_supervisor_authorization -and
    [string]$contract.future_physical_requirements.reproducible_adapter_build.shared_helper_path -ceq
        "sdk/r23d2_reproducible_runtime_materialization.ps1" -and
    -not [bool]$contract.future_physical_requirements.reproducible_adapter_build.cargo_incremental -and
    [string]$contract.future_physical_requirements.reproducible_adapter_build.source_date_epoch -ceq
        "stage_zero_source_commit_epoch" -and
    [bool]$contract.future_physical_requirements.reproducible_adapter_build.source_cargo_home_and_rust_sysroot_remapped -and
    [bool]$contract.future_physical_requirements.reproducible_adapter_build.cargo_target_root_remapped_to_constant_virtual_prefix -and
    [bool]$contract.future_physical_requirements.reproducible_adapter_build.msvc_brepro -and
    [bool]$contract.future_physical_requirements.reproducible_adapter_build.pdb_alt_path_bare_name -and
    [bool]$contract.future_physical_requirements.stage_aware_attempt_and_build_counts_required -and
    [bool]$contract.future_physical_requirements.rejected_receipt_and_per_predicate_failures_retained_before_exit -and
    [bool]$contract.claim_boundary.godot_jolt_worker_zero_world_commissioned -and
    [bool]$contract.claim_boundary.godot_jolt_physical_worker_implemented -and
    [bool]$contract.claim_boundary.all_engine_workers_zero_world_commissioned -and
    [int]$contract.claim_boundary.actual_r23d2_engine_worker_count -eq 3 -and
    [int]$contract.claim_boundary.physical_worker_implementation_count -eq 3 -and
    [bool]$contract.claim_boundary.physical_workers_complete -and
    [bool]$contract.authorization.physical_execution_authorized -and
    [int]$contract.authorization.world_attempt_count -eq 0 -and
    [int]$contract.authorization.world_build_count -eq 0 -and
    -not [bool]$contract.authorization.physical_acceptance_authority -and
    -not [bool]$contract.claim_boundary.development_result_exists -and
    -not [bool]$contract.claim_boundary.scientific_result_exists -and
    -not [bool]$contract.claim_boundary.command_conditioned_turning -and
    -not [bool]$contract.claim_boundary.q_sdk_r23_satisfied -and
    -not [bool]$contract.claim_boundary.cross_engine_equivalence -and
    -not [bool]$contract.claim_boundary.release_authorized
) "QSDK-R23D2 Godot/Jolt worker contract identity or authority changed"

Assert-QsdkR23d2Exact (
    Test-Path -LiteralPath $reproducibleRuntimePath -PathType Leaf
) "QSDK-R23D2 reproducible runtime helper is missing"
. $reproducibleRuntimePath
$adapterBuild = Invoke-SporeSporeR23D2PinnedCargo `
    -RepoRoot $repoRoot `
    -TargetRoot (Join-Path $sdkRoot "target") `
    -CargoArguments @(
        "build", "--quiet", "--locked", "--offline",
        "--manifest-path", $manifestPath,
        "--package", "sporespore-godot-adapter"
    )
Assert-QsdkR23d2Exact (
    Test-Path -LiteralPath $adapterArtifactPath -PathType Leaf
) "QSDK-R23D2 Godot adapter DLL is missing"

$expectedOffsets = [ordered]@{
    reference_zero = 0.0
    positive_heading = 0.2
    negative_heading = -0.2
}
$aggregateCanaries = 0
$aggregateNonzero = 0
$aggregateLegacyRejections = 0
$aggregatePredicateControls = 0
$aggregateStarts = 0
$aggregateSteps = 0
$aggregateCommands = 0
$aggregateMappings = 0
$aggregateWrites = 0
$aggregateObjects = 0
$aggregateSceneInsertions = 0
$aggregateSuccessReportCanaries = 0
$aggregateFailureStageCanaries = 0
$adapterCapabilitySha256 = ""
$controllerProfileSha256 = ""
try {
foreach ($entry in $expectedOffsets.GetEnumerator()) {
    $armId = [string]$entry.Key
    $execution = Invoke-QsdkR23d2GodotJoltWorker `
        -UserArguments @("preflight", $armId) -Label $armId
    Assert-QsdkR23d2CleanGodotExecution $execution
    Assert-QsdkR23d2Exact ([int]$execution.exit_code -eq 0) (
        "QSDK-R23D2 Godot/Jolt preflight failed: $armId`n$($execution.stderr)"
    )
    $receipt = Get-QsdkR23d2MarkerReceipt $execution $preflightPrefix
    $invalidCanaries = @($receipt.canaries | Where-Object {
        @($_.failed_predicates).Count -ne 0 -or
        [int]$_.world_attempt_count -ne 0 -or
        [int]$_.world_build_count -ne 0 -or
        [bool]$_.physical_acceptance_authority -or
        [string]$_.host_mapping_sha256 -notmatch '^sha256:[0-9a-f]{64}$'
    })
    $armBoundary = [Collections.IDictionary]$receipt.arm_command_boundary
    $version = [Collections.IDictionary]$receipt.engine_version
    $solver = [Collections.IDictionary]$receipt.solver_receipt
    $traceCanary = [Collections.IDictionary]$receipt.oracle_trace_canary
    $entrypointPreflight = [Collections.IDictionary]$receipt.physical_entrypoint_preflight
    Assert-QsdkR23d2Exact (
        [string]$receipt.schema_version -ceq
            "sporespore_qsdk_r23d2_godot_jolt_worker_preflight_v1" -and
        [string]$receipt.campaign_id -ceq $campaignId -and
        [string]$receipt.gate_id -ceq $gateId -and
        [string]$receipt.engine_id -ceq $engineId -and
        [int]$version.major -eq 4 -and [int]$version.minor -eq 7 -and
        [string]$version.status -ceq "stable" -and
        [string]$receipt.physics_engine -ceq "Jolt Physics" -and
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
            "godot_jolt_supervisor_only_physical_authorized" -and
        [string]$receipt.development_contract_status -ceq
            "frozen_supervisor_only_physical_authorized_pending_exact_source_attestation" -and
        [bool]$receipt.physical_worker_implementation_present -and
        [string]$receipt.controller_profile_sha256 -match '^sha256:[0-9a-f]{64}$' -and
        [string]$receipt.adapter_capability_sha256 -match '^sha256:[0-9a-f]{64}$' -and
        [bool]$solver.ok -and [int]$solver.world_attempt_count -eq 0 -and
        [int]$solver.world_build_count -eq 0 -and
        [int]$receipt.canary_count -eq 7 -and
        [int]$receipt.nonzero_cross_track_canary_count -eq 6 -and
        [int]$receipt.legacy_raw_offset_oracle_rejection_count -eq 6 -and
        [int]$receipt.predicate_negative_control_count -eq 35 -and
        [int]$receipt.adapter_start_count -eq 8 -and
        [int]$receipt.native_controller_step_count -eq 8 -and
        [int]$receipt.native_command_count -eq 64 -and
        [int]$receipt.host_mapping_validation_count -eq 8 -and
        [int]$receipt.host_parameter_write_count -eq 64 -and
        [int]$receipt.host_object_creation_count -eq 64 -and
        [int]$receipt.scene_tree_insertion_count -eq 0 -and
        [string]$traceCanary.schema_version -ceq
            "sporespore_qsdk_r23d2_godot_jolt_oracle_trace_canary_v1" -and
        [bool]$traceCanary.ok -and
        [int]$traceCanary.step_count -eq 1 -and
        [bool]$traceCanary.full_state_frame_sha256_bound -and
        [bool]$traceCanary.full_motion_command_sha256_bound -and
        [bool]$traceCanary.controller_receipt_sha256_bound -and
        [bool]$traceCanary.controller_profile_sha256_bound -and
        [bool]$traceCanary.independent_oracle_recomputed -and
        [int]$traceCanary.world_attempt_count -eq 0 -and
        [int]$traceCanary.world_build_count -eq 0 -and
        -not [bool]$traceCanary.physical_acceptance_authority -and
        [bool]$entrypointPreflight.ok -and
        [bool]$entrypointPreflight.entrypoint_control_flow_complete -and
        [bool]$entrypointPreflight.sdk_heading_schedule_enabled -and
        [int]$entrypointPreflight.actual_world_build_count -eq 0 -and
        [int]$receipt.world_attempt_count -eq 0 -and
        [int]$receipt.world_build_count -eq 0 -and
        $invalidCanaries.Count -eq 0 -and
        [math]::Abs(
            [double]$armBoundary.desired_heading_error_rad - [double]$entry.Value
        ) -le 1.0e-12 -and
        [math]::Abs(
            [double]$armBoundary.observed_heading_error_rad - [double]$entry.Value
        ) -le 1.0e-12 -and
        @($armBoundary.failed_predicates).Count -eq 0 -and
        [int]$armBoundary.native_command_count -eq 8 -and
        [int]$armBoundary.host_parameter_write_count -eq 8 -and
        [int]$armBoundary.scene_tree_insertion_count -eq 0 -and
        [int]$armBoundary.world_attempt_count -eq 0 -and
        [int]$armBoundary.world_build_count -eq 0 -and
        [int]$receipt.world_attempt_count -eq 0 -and
        [int]$receipt.world_build_count -eq 0 -and
        [bool]$receipt.physical_execution_authorized -and
        -not [bool]$receipt.q_sdk_r23_satisfied -and
        -not [bool]$receipt.physical_acceptance_authority
    ) "QSDK-R23D2 normalized Godot/Jolt receipt changed: $armId"

    $successEvaluation = Test-QsdkR23d2EvaluatorEntry `
        -Entry ([Collections.IDictionary]$receipt.synthetic_physical_report) `
        -Label "$armId synthetic success report"
    Assert-QsdkR23d2Exact (
        [string]$successEvaluation.result_classification -ceq "valid_positive" -and
        [bool]$successEvaluation.entry_valid -and
        [bool]$successEvaluation.execution_valid -and
        [bool]$successEvaluation.screen_cell_passed -and
        [int]$successEvaluation.world_attempt_count -eq 1 -and
        [int]$successEvaluation.world_build_count -eq 1
    ) "QSDK-R23D2 Godot/Jolt success-report canary changed: $armId"
    $aggregateSuccessReportCanaries += 1

    $failureReceipts = @($receipt.synthetic_failure_receipts)
    Assert-QsdkR23d2Exact ($failureReceipts.Count -eq 6) (
        "QSDK-R23D2 Godot/Jolt failure-stage canary count changed: $armId"
    )
    $expectedStageCounts = [ordered]@{
        before_world = @(0, 0)
        world_construction_failed = @(1, 0)
        world_constructed = @(1, 1)
        settlement_complete = @(1, 1)
        controller_validation_failed = @(1, 1)
        cell_report_complete = @(1, 1)
    }
    foreach ($failureReceipt in $failureReceipts) {
        $stageId = [string]$failureReceipt.stage_id
        Assert-QsdkR23d2Exact ($expectedStageCounts.Contains($stageId)) (
            "QSDK-R23D2 Godot/Jolt emitted an unknown failure stage: $stageId"
        )
        $counts = @($expectedStageCounts[$stageId])
        $failureEvaluation = Test-QsdkR23d2EvaluatorEntry `
            -Entry ([Collections.IDictionary]$failureReceipt) `
            -Label "$armId $stageId failure"
        Assert-QsdkR23d2Exact (
            [string]$failureEvaluation.result_classification -ceq "worker_failure" -and
            [bool]$failureEvaluation.entry_valid -and
            -not [bool]$failureEvaluation.execution_valid -and
            [int]$failureEvaluation.world_attempt_count -eq [int]$counts[0] -and
            [int]$failureEvaluation.world_build_count -eq [int]$counts[1]
        ) "QSDK-R23D2 Godot/Jolt failure-stage evaluation changed: $armId $stageId"
        $aggregateFailureStageCanaries += 1
    }
    if ($adapterCapabilitySha256.Length -eq 0) {
        $adapterCapabilitySha256 = [string]$receipt.adapter_capability_sha256
        $controllerProfileSha256 = [string]$receipt.controller_profile_sha256
    } else {
        Assert-QsdkR23d2Exact (
            [string]$receipt.adapter_capability_sha256 -ceq $adapterCapabilitySha256 -and
            [string]$receipt.controller_profile_sha256 -ceq $controllerProfileSha256
        ) "QSDK-R23D2 Godot/Jolt adapter identity changed between arms"
    }
    $aggregateCanaries += [int]$receipt.canary_count
    $aggregateNonzero += [int]$receipt.nonzero_cross_track_canary_count
    $aggregateLegacyRejections += [int]$receipt.legacy_raw_offset_oracle_rejection_count
    $aggregatePredicateControls += [int]$receipt.predicate_negative_control_count
    $aggregateStarts += [int]$receipt.adapter_start_count
    $aggregateSteps += [int]$receipt.native_controller_step_count
    $aggregateCommands += [int]$receipt.native_command_count
    $aggregateMappings += [int]$receipt.host_mapping_validation_count
    $aggregateWrites += [int]$receipt.host_parameter_write_count
    $aggregateObjects += [int]$receipt.host_object_creation_count
    $aggregateSceneInsertions += [int]$receipt.scene_tree_insertion_count
}
Assert-QsdkR23d2Exact (
    $aggregateCanaries -eq 21 -and
    $aggregateNonzero -eq 18 -and
    $aggregateLegacyRejections -eq 18 -and
    $aggregatePredicateControls -eq 105 -and
    $aggregateStarts -eq 24 -and
    $aggregateSteps -eq 24 -and
    $aggregateCommands -eq 192 -and
    $aggregateMappings -eq 24 -and
    $aggregateWrites -eq 192 -and
    $aggregateObjects -eq 192 -and
    $aggregateSceneInsertions -eq 0 -and
    $aggregateSuccessReportCanaries -eq 3 -and
    $aggregateFailureStageCanaries -eq 18
) "QSDK-R23D2 Godot/Jolt aggregate preflight counts changed"

$unknownExecution = Invoke-QsdkR23d2GodotJoltWorker `
    -UserArguments @("preflight", "undeclared_arm") -Label "unknown-arm"
Assert-QsdkR23d2CleanGodotExecution $unknownExecution
Assert-QsdkR23d2Exact ([int]$unknownExecution.exit_code -ne 0) (
    "QSDK-R23D2 unknown Godot/Jolt arm did not fail closed"
)
$unknown = Get-QsdkR23d2MarkerReceipt $unknownExecution $failurePrefix
Assert-QsdkR23d2Exact (
    [string]$unknown.process_failure_code -ceq
        "QSDK_R23D2_GJT_ARM_UNKNOWN:undeclared_arm" -and
    [string]$unknown.schema_version -ceq
        "sporespore_qsdk_r23d2_worker_failure_v1" -and
    [string]$unknown.campaign_id -ceq $campaignId -and
    [string]$unknown.gate_id -ceq "QSDK-R23D2" -and
    [string]$unknown.cell_id -ceq "godot_jolt__undeclared_arm" -and
    [string]$unknown.engine_id -ceq $engineId -and
    [string]$unknown.arm_id -ceq "undeclared_arm" -and
    [string]$unknown.source_commit -ceq ("0" * 40) -and
    [string]$unknown.contract_sha256 -ceq $developmentContractSha256 -and
    [string]$unknown.stage_id -ceq "before_world" -and
    [int]$unknown.world_attempt_count -eq 0 -and
    [int]$unknown.world_build_count -eq 0 -and
    -not [bool]$unknown.rejected_projection_retention.embedded_before_exit -and
    -not [bool]$unknown.claims.physical_acceptance_authority
) "QSDK-R23D2 unknown-arm failure receipt changed"

$bypassExecution = Invoke-QsdkR23d2GodotJoltWorker `
    -UserArguments @("physical", "reference_zero", ("0" * 40)) `
    -Label "physical-bypass"
Assert-QsdkR23d2CleanGodotExecution $bypassExecution
Assert-QsdkR23d2Exact ([int]$bypassExecution.exit_code -ne 0) (
    "QSDK-R23D2 direct Godot/Jolt physical bypass did not fail closed"
)
$bypass = Get-QsdkR23d2MarkerReceipt $bypassExecution $failurePrefix
$cellMarkers = @(([string]$bypassExecution.stdout -split "`r?`n") | Where-Object {
    $_.StartsWith($cellPrefix, [StringComparison]::Ordinal)
})
Assert-QsdkR23d2Exact (
    [string]$bypass.process_failure_code -ceq
        "QSDK_R23D2_GJT_PHYSICAL_AUTHORIZATION_REQUIRED" -and
    [string]$bypass.schema_version -ceq
        "sporespore_qsdk_r23d2_worker_failure_v1" -and
    [string]$bypass.campaign_id -ceq $campaignId -and
    [string]$bypass.gate_id -ceq "QSDK-R23D2" -and
    [string]$bypass.cell_id -ceq "godot_jolt__reference_zero" -and
    [string]$bypass.engine_id -ceq $engineId -and
    [string]$bypass.arm_id -ceq "reference_zero" -and
    [string]$bypass.source_commit -ceq ("0" * 40) -and
    [string]$bypass.contract_sha256 -ceq $developmentContractSha256 -and
    [string]$bypass.stage_id -ceq "before_world" -and
    [int]$bypass.world_attempt_count -eq 0 -and
    [int]$bypass.world_build_count -eq 0 -and
    -not [bool]$bypass.rejected_projection_retention.embedded_before_exit -and
    $cellMarkers.Count -eq 0 -and
    -not [bool]$bypass.claims.physical_acceptance_authority
) "QSDK-R23D2 direct Godot/Jolt physical bypass receipt changed"

$bypassEvaluation = Test-QsdkR23d2EvaluatorEntry `
    -Entry ([Collections.IDictionary]$bypass) -Label "physical bypass"
Assert-QsdkR23d2Exact (
    [string]$bypassEvaluation.result_classification -ceq "worker_failure" -and
    [bool]$bypassEvaluation.entry_valid -and
    -not [bool]$bypassEvaluation.execution_valid -and
    [int]$bypassEvaluation.world_attempt_count -eq 0 -and
    [int]$bypassEvaluation.world_build_count -eq 0
) "QSDK-R23D2 direct Godot/Jolt bypass evaluator receipt changed"
}
finally {
    Remove-QsdkR23d2EvaluationRoot
}

Write-Host (
    "QSDK_R23D2_GODOT_JOLT_WORKER_PASS arms=3 canaries=21 " +
    "nonzero_cross_track=18 legacy_oracle_rejections=18 " +
    "predicate_negative_controls=105 arm_command_boundaries=3 " +
    "adapter_starts=24 native_steps=24 native_commands=192 " +
    "host_mappings=24 host_parameter_writes=192 host_objects=192 " +
    "scene_tree_insertions=0 success_reports=3/3 failure_stages=18/18 " +
    "physical_worker=True negative_controls=2 supervisor_authorization=True " +
    "worlds=0 physical_authority=False"
)
