#requires -Version 7.0

[CmdletBinding()]
param(
    [switch]$EmitBundle,
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$contractPath = Join-Path $sdkRoot "turning\physical_development_contract_v1.json"
$modulePath = Join-Path $sdkRoot "turning\physical_development.py"
$workerPath = Join-Path $repoRoot "tests\test_sdk_qsdk_r23d1_godot_jolt_worker.gd"
$workerResource = "res://tests/test_sdk_qsdk_r23d1_godot_jolt_worker.gd"
$preflightPrefix = "QSDK_R23D1_GODOT_JOLT_PREFLIGHT "
$failurePrefix = "QSDK_R23D1_GODOT_JOLT_FAILURE "
$cellPrefix = "QSDK_R23D1_GODOT_JOLT_CELL "
$campaignId = "QSDK-R23D1-THREE-ENGINE-HEADING-RESPONSE-DEVELOPMENT"
$gateId = "QSDK-R23D1"
$engineId = "godot_jolt"
$policyId = "sporespore_balanced_wave_bw5r_b_v1"
$policyDigest = "sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f"
$morphologyId = "qsdk_r05_generated_s169"
$campaignSeed = 21501
$attemptEnvironmentNames = @(
    "SPORESPORE_QSDK_R23D1_ATTEMPT",
    "SPORESPORE_QSDK_R23D1_TOKEN",
    "SPORESPORE_QSDK_R23D1_CELL",
    "SPORESPORE_QSDK_R23D1_ENGINE"
)

function Assert-QsdkR23d1Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Invoke-QsdkR23d1GodotWorker {
    param(
        [Parameter(Mandatory)][string[]]$UserArguments,
        [Parameter(Mandatory)][string]$Label
    )
    $runRoot = Join-Path $sdkRoot (
        "target\qsdk-r23d1-godot-jolt-preflight\" +
        [guid]::NewGuid().ToString("N")
    )
    $appData = Join-Path $runRoot "appdata"
    $localAppData = Join-Path $runRoot "localappdata"
    $logPath = Join-Path $runRoot "$Label-godot.log"
    [void][System.IO.Directory]::CreateDirectory($appData)
    [void][System.IO.Directory]::CreateDirectory($localAppData)

    $start = [System.Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $Godot
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.Environment["APPDATA"] = $appData
    $start.Environment["LOCALAPPDATA"] = $localAppData
    foreach ($name in $attemptEnvironmentNames) {
        [void]$start.Environment.Remove($name)
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

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $start
    Assert-QsdkR23d1Exact $process.Start() (
        "QSDK-R23D1 failed to start Godot worker route: $Label"
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
        run_root = $runRoot
    }
}

function Assert-QsdkR23d1CleanGodotExecution {
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Execution)
    $combined = [string]$Execution.stdout + [Environment]::NewLine +
        [string]$Execution.stderr
    Assert-QsdkR23d1Exact (-not [bool]$Execution.timed_out) (
        "QSDK-R23D1 Godot worker timed out: $($Execution.label)"
    )
    Assert-QsdkR23d1Exact ($combined -cnotmatch "(?m)SCRIPT ERROR|Parse Error|ERROR:") (
        "QSDK-R23D1 Godot worker emitted a script/engine error: " +
        "$($Execution.label); log=$($Execution.log_path)"
    )
}

function Get-QsdkR23d1MarkerReceipt {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Execution,
        [Parameter(Mandatory)][string]$Prefix
    )
    $lines = @(([string]$Execution.stdout -split "`r?`n") | Where-Object {
        $_.StartsWith($Prefix, [System.StringComparison]::Ordinal)
    })
    Assert-QsdkR23d1Exact ($lines.Count -eq 1) (
        "QSDK-R23D1 expected one '$Prefix' marker from " +
        "$($Execution.label), found $($lines.Count)"
    )
    return $lines[0].Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Invoke-QsdkR23d1ProductionCellEvaluation {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Report,
        [Parameter(Mandatory)][string]$RunRoot
    )
    $inputPath = Join-Path $RunRoot "normalized-report.json"
    $json = $Report | ConvertTo-Json -Depth 100 -Compress
    [System.IO.File]::WriteAllText(
        $inputPath,
        $json + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )
    $output = & python $modulePath evaluate-cell $inputPath 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
    $prefix = "QSDK_R23D1_CELL_EVALUATION "
    $lines = @($output -split "`r?`n" | Where-Object {
        $_.StartsWith($prefix, [System.StringComparison]::Ordinal)
    })
    Assert-QsdkR23d1Exact ($exitCode -eq 0 -and $lines.Count -eq 1) (
        "QSDK-R23D1 production evaluator rejected actual Godot/Jolt composer output:`n$output"
    )
    return $lines[0].Substring($prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

foreach ($path in @($Godot, $contractPath, $modulePath, $workerPath)) {
    Assert-QsdkR23d1Exact (Test-Path -LiteralPath $path -PathType Leaf) (
        "QSDK-R23D1 Godot/Jolt worker preflight input missing: $path"
    )
}

$contract = Get-Content -Raw -LiteralPath $contractPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$contractSha256 = "sha256:" + (
    Get-FileHash -LiteralPath $contractPath -Algorithm SHA256
).Hash.ToLowerInvariant()
Assert-QsdkR23d1Exact (
    [string]$contract.campaign_id -ceq $campaignId -and
    [string]$contract.gate_id -ceq $gateId -and
    [int]$contract.fixture.initial_condition_seed -eq $campaignSeed -and
    $contract.authorization.physical_execution_authorized -is [bool] -and
    -not [bool]$contract.authorization.q_sdk_r23_satisfied -and
    -not [bool]$contract.authorization.release_authorized -and
    -not [bool]$contract.authorization.physical_acceptance_authority
) "QSDK-R23D1 contract identity or bounded authority changed"

$expectedOffsets = [ordered]@{
    reference_zero = 0.0
    positive_heading = 0.2
    negative_heading = -0.2
}
$receipts = [ordered]@{}
$productionEvaluationCount = 0
$scheduleHashes = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::Ordinal
)
foreach ($entry in $expectedOffsets.GetEnumerator()) {
    $armId = [string]$entry.Key
    $expectedOffset = [double]$entry.Value
    $execution = Invoke-QsdkR23d1GodotWorker `
        -UserArguments @("preflight", $armId) -Label $armId
    Assert-QsdkR23d1CleanGodotExecution $execution
    Assert-QsdkR23d1Exact ([int]$execution.exit_code -eq 0) (
        "QSDK-R23D1 Godot/Jolt preflight exited nonzero: $armId"
    )
    $receipt = Get-QsdkR23d1MarkerReceipt $execution $preflightPrefix
    $entrypoint = [System.Collections.IDictionary]$receipt.entrypoint_preflight
    $native = [System.Collections.IDictionary]$receipt.native_heading_preflight
    $solver = [System.Collections.IDictionary]$receipt.solver_configuration
    $headingCommand = [System.Collections.IDictionary]$native.heading_command_receipt
    $controllerHeading = [System.Collections.IDictionary]$native.controller_heading_receipt
    $commandValidation = [System.Collections.IDictionary](
        $native.balanced_wave_command_validation_receipt
    )
    $productionReport = [System.Collections.IDictionary]$receipt.production_normalized_report
    $expectedRole = if ($armId -ceq "reference_zero") {
        "reference_heading"
    } else {
        "turn_heading"
    }
    $expectedSegment = if ($armId -ceq "reference_zero") {
        "reference_warmup"
    } else {
        "commanded_turn"
    }
    Assert-QsdkR23d1Exact (
        [string]$receipt.schema_version -ceq
            "sporespore_qsdk_r23d1_godot_jolt_worker_preflight_v1" -and
        [bool]$receipt.ok -and
        [string]$receipt.campaign_id -ceq $campaignId -and
        [string]$receipt.gate_id -ceq $gateId -and
        [string]$receipt.engine_id -ceq $engineId -and
        [string]$receipt.arm_id -ceq $armId -and
        [string]$receipt.cell_id -ceq "$engineId`__$armId" -and
        [int]$receipt.campaign_seed -eq $campaignSeed -and
        [string]$receipt.selected_policy_id -ceq $policyId -and
        [string]$receipt.selected_policy_digest -ceq $policyDigest -and
        [string]$receipt.morphology_id -ceq $morphologyId -and
        [string]$receipt.contract_sha256 -ceq $contractSha256 -and
        [math]::Abs([double]$receipt.turn_heading_offset_rad - $expectedOffset) -le 1.0e-15 -and
        [int]$receipt.actual_world_build_count -eq 0 -and
        [int]$receipt.scene_tree_insertion_count -eq 0 -and
        [bool]$receipt.synthetic_contract_preflight -and
        -not [bool]$receipt.locomotion_outcome_exposed -and
        -not [bool]$receipt.physical_execution_authorized -and
        -not [bool]$receipt.q_sdk_r23_satisfied -and
        -not [bool]$receipt.physical_acceptance_authority
    ) "QSDK-R23D1 normalized Godot/Jolt worker receipt changed: $armId"
    $fixture = [System.Collections.IDictionary]$contract.fixture.initial_perturbation
    $initial = [System.Collections.IDictionary]$receipt.initial_perturbation
    Assert-QsdkR23d1Exact (
        [int]$initial.campaign_seed -eq [int]$fixture.campaign_seed -and
        [double]$initial.fixture_vertical_clearance_m -eq
            [double]$fixture.fixture_vertical_clearance_m -and
        [double]$initial.fixture_yaw_rad -eq [double]$fixture.fixture_yaw_rad -and
        [int]$initial.gait_phase_offset_ticks -eq [int]$fixture.gait_phase_offset_ticks -and
        (@($initial.initial_linear_velocity_world_m_s) -join ",") -ceq
            (@($fixture.initial_linear_velocity_world_m_s) -join ",") -and
        (@($initial.initial_torso_angular_velocity_world_rad_s) -join ",") -ceq
            (@($fixture.initial_torso_angular_velocity_world_rad_s) -join ",")
    ) "QSDK-R23D1 exact seeded Godot/Jolt perturbation changed: $armId"
    Assert-QsdkR23d1Exact (
        [bool]$solver.ok -and
        [bool]$solver.applied_before_entrypoint -and
        [string]$solver.realized_solver_policy.solver_policy_id -ceq
            "jolt_120hz_20v_7p_v1" -and
        [string]$solver.realized_solver_policy.physics_engine -ceq "Jolt Physics" -and
        [int]$solver.realized_solver_policy.physics_hz -eq 120 -and
        [int]$solver.realized_solver_policy.solver_velocity_steps -eq 20 -and
        [int]$solver.realized_solver_policy.solver_position_steps -eq 7 -and
        [int]$solver.world_build_count -eq 0 -and
        -not [bool]$solver.physics_state_modified
    ) "QSDK-R23D1 pinned Godot/Jolt solver receipt changed: $armId"
    Assert-QsdkR23d1Exact (
        [bool]$entrypoint.ok -and
        [bool]$entrypoint.entrypoint_control_flow_complete -and
        [bool]$entrypoint.sdk_heading_schedule_enabled -and
        [string]$entrypoint.sdk_heading_schedule_sha256 -ceq
            [string]$receipt.schedule_sha256 -and
        [bool]$entrypoint.sdk_transport_execution_receipt.ok -and
        [int]$entrypoint.actual_world_build_count -eq 0 -and
        [int]$entrypoint.scene_tree_insertion_count -eq 0 -and
        -not [bool]$entrypoint.physics_state_modified -and
        -not [bool]$entrypoint.locomotion_outcome_exposed -and
        -not [bool]$entrypoint.physical_acceptance_authority
    ) "QSDK-R23D1 actual generic entrypoint preflight changed: $armId"
    Assert-QsdkR23d1Exact (
        [bool]$native.ok -and
        [bool]$native.native_controller_step_passed -and
        [int]$native.native_controller_command_count -eq 8 -and
        [bool]$native.native_controller_command_order_exact -and
        [bool]$native.native_next_memory_nonnegative -and
        [string]$native.controller_policy_id -ceq $policyId -and
        [string]$commandValidation.schema_version -ceq
            "sporespore_balanced_wave_command_validation_receipt_v1" -and
        [bool]$commandValidation.ok -and
        [bool]$commandValidation.enabled -and
        [string]$commandValidation.validation_mode -ceq
            "native_balanced_wave_structure_and_receipts_v1" -and
        [bool]$commandValidation.heading_command_conditioned -and
        -not [bool]$commandValidation.legacy_command_parity_applicable -and
        -not [bool]$commandValidation.legacy_command_parity_checked -and
        -not [bool]$commandValidation.legacy_command_parity_waived -and
        [int]$native.actual_world_build_count -eq 0 -and
        [int]$native.scene_tree_insertion_count -eq 0 -and
        -not [bool]$native.physics_state_modified -and
        -not [bool]$native.locomotion_outcome_exposed -and
        -not [bool]$native.physical_acceptance_authority -and
        [string]$headingCommand.command_role -ceq $expectedRole -and
        [string]$headingCommand.segment_id -ceq $expectedSegment -and
        [math]::Abs([double]$headingCommand.heading_offset_rad - $expectedOffset) -le 1.0e-15 -and
        [math]::Abs([double]$controllerHeading.desired_heading_error_rad - $expectedOffset) -le 1.0e-15 -and
        [math]::Abs([double]$controllerHeading.requested_steering_fraction + 1.3 * $expectedOffset) -le 1.0e-15
    ) "QSDK-R23D1 native heading-command boundary changed: $armId"
    Assert-QsdkR23d1Exact (
        [string]$productionReport.schema_version -ceq
            "sporespore_qsdk_r23d1_engine_cell_report_v2" -and
        [string]$productionReport.cell_id -ceq "$engineId`__$armId" -and
        [string]$productionReport.source_commit -ceq ("0" * 40) -and
        [int]$productionReport.execution.world_build_count -eq 1 -and
        -not [bool]$productionReport.claims.q_sdk_r23_satisfied -and
        -not [bool]$productionReport.claims.physical_acceptance_authority
    ) "QSDK-R23D1 actual normalized-report composer changed: $armId"
    $productionEvaluation = Invoke-QsdkR23d1ProductionCellEvaluation `
        -Report $productionReport -RunRoot ([string]$execution.run_root)
    Assert-QsdkR23d1Exact (
        [string]$productionEvaluation.cell_id -ceq "$engineId`__$armId" -and
        [bool]$productionEvaluation.execution_valid -and
        [bool]$productionEvaluation.screen_cell_passed -and
        [int]$productionEvaluation.failed_gate_count -eq 0
    ) "QSDK-R23D1 production evaluator result changed: $armId"
    $productionEvaluationCount += 1
    Assert-QsdkR23d1Exact (
        [string]$receipt.schedule_sha256 -cmatch '^sha256:[0-9a-f]{64}$' -and
        $scheduleHashes.Add([string]$receipt.schedule_sha256)
    ) "QSDK-R23D1 schedule digest missing or duplicated: $armId"
    $receipts[$armId] = $receipt
}
Assert-QsdkR23d1Exact ($productionEvaluationCount -eq 3) (
    "QSDK-R23D1 did not production-evaluate all three Godot/Jolt reports"
)

$zeroHeld = [double]$receipts.reference_zero.native_heading_preflight.controller_heading_receipt.held_steering_fraction
$positiveHeld = [double]$receipts.positive_heading.native_heading_preflight.controller_heading_receipt.held_steering_fraction
$negativeHeld = [double]$receipts.negative_heading.native_heading_preflight.controller_heading_receipt.held_steering_fraction
Assert-QsdkR23d1Exact (
    [math]::Abs($zeroHeld) -le 1.0e-15 -and
    $positiveHeld -lt 0.0 -and
    $negativeHeld -gt 0.0 -and
    [math]::Abs($positiveHeld + $negativeHeld) -le 1.0e-15
) "QSDK-R23D1 Godot/Jolt signed steering mirror changed"

$unknownArmExecution = Invoke-QsdkR23d1GodotWorker `
    -UserArguments @("preflight", "undeclared_arm") -Label "unknown-arm"
Assert-QsdkR23d1CleanGodotExecution $unknownArmExecution
Assert-QsdkR23d1Exact ([int]$unknownArmExecution.exit_code -ne 0) (
    "QSDK-R23D1 unknown Godot/Jolt arm did not fail closed"
)
$unknownArm = Get-QsdkR23d1MarkerReceipt $unknownArmExecution $failurePrefix
Assert-QsdkR23d1Exact (
    [string]$unknownArm.failure_code -ceq "QSDK_R23D1_GODOT_JOLT_ARM_UNKNOWN" -and
    [int]$unknownArm.actual_world_build_count -eq 0 -and
    -not [bool]$unknownArm.physical_acceptance_authority
) "QSDK-R23D1 unknown-arm failure receipt changed"

$bypassExecution = Invoke-QsdkR23d1GodotWorker `
    -UserArguments @("physical", "reference_zero", ("0" * 40)) `
    -Label "physical-bypass"
Assert-QsdkR23d1CleanGodotExecution $bypassExecution
Assert-QsdkR23d1Exact ([int]$bypassExecution.exit_code -ne 0) (
    "QSDK-R23D1 direct physical Godot/Jolt bypass did not fail closed"
)
$bypass = Get-QsdkR23d1MarkerReceipt $bypassExecution $failurePrefix
$cellMarkers = @(([string]$bypassExecution.stdout -split "`r?`n") | Where-Object {
    $_.StartsWith($cellPrefix, [System.StringComparison]::Ordinal)
})
Assert-QsdkR23d1Exact (
    [string]$bypass.failure_code -ceq
        "QSDK_R23D1_GODOT_JOLT_PHYSICAL_IDENTITY_CLOSED" -and
    [int]$bypass.actual_world_build_count -eq 0 -and
    $cellMarkers.Count -eq 0 -and
    -not [bool]$bypass.physical_acceptance_authority
) "QSDK-R23D1 direct physical bypass receipt changed"

if ($EmitBundle) {
    $bundle = [ordered]@{
        schema_version = "sporespore_qsdk_r23d1_worker_bundle_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        engine_id = $engineId
        contract_sha256 = $contractSha256
        ordered_arm_ids = @($expectedOffsets.Keys)
        ordered_production_reports = @($expectedOffsets.Keys | ForEach-Object {
            $receipts[$_].production_normalized_report
        })
        production_evaluator_pass_count = $productionEvaluationCount
        negative_control_rejection_count = 2
        world_build_count = 0
        physical_execution_authorized = [bool]$contract.authorization.physical_execution_authorized
        physical_acceptance_authority = $false
    }
    Write-Host (
        "QSDK_R23D1_GODOT_JOLT_WORKER_BUNDLE " +
        ($bundle | ConvertTo-Json -Depth 100 -Compress)
    )
}

Write-Host (
    "QSDK_R23D1_GODOT_JOLT_WORKER_PASS arms=3 entrypoints=3 " +
    "native_steps=3 native_commands=24 normalized_reports=3 " +
    "production_evaluator=3/3 validation=native_receipts_no_legacy_parity " +
    "schedules=3 solver=120hz_20v_7p " +
    "signed_mirror=True negative_controls=2 physical_identity_closed=True " +
    "worlds=0 outcome_exposed=False physical_authority=False"
)
