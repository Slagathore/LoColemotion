#requires -Version 7.0

[CmdletBinding()]
param([switch]$EmitBundle)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$manifestPath = Join-Path $sdkRoot "adapters\rapier\Cargo.toml"
$contractPath = Join-Path $sdkRoot "turning\physical_development_contract_v1.json"
$modulePath = Join-Path $sdkRoot "turning\physical_development.py"
$sourcePath = Join-Path $sdkRoot "adapters\rapier\src\qsdk_r23d1_heading_response.rs"
$binarySourcePath = Join-Path $sdkRoot "adapters\rapier\src\bin\qsdk_r23d1_heading_response.rs"
$binaryPath = Join-Path $sdkRoot "target\debug\qsdk_r23d1_heading_response.exe"
$preflightPrefix = "QSDK_R23D1_RAPIER_PREFLIGHT "
$failurePrefix = "QSDK_R23D1_RAPIER_FAILURE "
$cellPrefix = "QSDK_R23D1_RAPIER_CELL "
$campaignId = "QSDK-R23D1-THREE-ENGINE-HEADING-RESPONSE-DEVELOPMENT"
$gateId = "QSDK-R23D1"
$engineId = "rapier_parry"
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

function Invoke-QsdkR23d1RapierWorker {
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
    foreach ($name in $attemptEnvironmentNames) {
        [void]$start.Environment.Remove($name)
    }
    foreach ($argument in $Arguments) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $start
    Assert-QsdkR23d1Exact $process.Start() (
        "QSDK-R23D1 failed to start Rapier worker route: $Label"
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
    }
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
        [Parameter(Mandatory)][string]$ArmId
    )
    $runRoot = Join-Path $sdkRoot (
        "target\qsdk-r23d1-rapier-preflight\" +
        [guid]::NewGuid().ToString("N")
    )
    [void][System.IO.Directory]::CreateDirectory($runRoot)
    $inputPath = Join-Path $runRoot "$ArmId-normalized-report.json"
    [System.IO.File]::WriteAllText(
        $inputPath,
        ($Report | ConvertTo-Json -Depth 100 -Compress) + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )
    $output = & python $modulePath evaluate-cell $inputPath 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
    $prefix = "QSDK_R23D1_CELL_EVALUATION "
    $lines = @($output -split "`r?`n" | Where-Object {
        $_.StartsWith($prefix, [System.StringComparison]::Ordinal)
    })
    Assert-QsdkR23d1Exact ($exitCode -eq 0 -and $lines.Count -eq 1) (
        "QSDK-R23D1 production evaluator rejected Rapier composer output:`n$output"
    )
    return $lines[0].Substring($prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

foreach ($path in @(
    $manifestPath,
    $contractPath,
    $modulePath,
    $sourcePath,
    $binarySourcePath
)) {
    Assert-QsdkR23d1Exact (Test-Path -LiteralPath $path -PathType Leaf) (
        "QSDK-R23D1 Rapier worker preflight input missing: $path"
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

$buildOutput = & cargo build --quiet --manifest-path $manifestPath `
    --bin qsdk_r23d1_heading_response 2>&1 | Out-String
Assert-QsdkR23d1Exact ($LASTEXITCODE -eq 0) (
    "QSDK-R23D1 Rapier worker did not build:`n$buildOutput"
)
Assert-QsdkR23d1Exact (Test-Path -LiteralPath $binaryPath -PathType Leaf) (
    "QSDK-R23D1 Rapier worker binary missing after build: $binaryPath"
)

$expectedOffsets = [ordered]@{
    reference_zero = 0.0
    positive_heading = 0.2
    negative_heading = -0.2
}
$expectedActuatorOrder = @(
    "front_left_hip_motor",
    "front_left_knee_motor",
    "front_right_hip_motor",
    "front_right_knee_motor",
    "rear_left_hip_motor",
    "rear_left_knee_motor",
    "rear_right_hip_motor",
    "rear_right_knee_motor"
)
$receipts = [ordered]@{}
$productionEvaluationCount = 0
foreach ($entry in $expectedOffsets.GetEnumerator()) {
    $armId = [string]$entry.Key
    $expectedOffset = [double]$entry.Value
    $execution = Invoke-QsdkR23d1RapierWorker `
        -Arguments @("--preflight-only", "--arm", $armId) -Label $armId
    Assert-QsdkR23d1Exact (-not [bool]$execution.timed_out) (
        "QSDK-R23D1 Rapier preflight timed out: $armId"
    )
    Assert-QsdkR23d1Exact ([int]$execution.exit_code -eq 0) (
        "QSDK-R23D1 Rapier preflight exited nonzero: $armId`n$($execution.stderr)"
    )
    $receipt = Get-QsdkR23d1MarkerReceipt $execution $preflightPrefix
    $native = [System.Collections.IDictionary]$receipt.native_heading_preflight
    $controller = [System.Collections.IDictionary]$native.controller_receipt
    $mapping = [System.Collections.IDictionary]$native.host_mapping
    $validation = [System.Collections.IDictionary]$native.command_validation_receipt
    $productionReport = [System.Collections.IDictionary]$receipt.production_normalized_report
    $expectedRole = if ($armId -ceq "reference_zero") {
        "reference_heading"
    } else {
        "turn_heading"
    }
    $expectedStep = if ($armId -ceq "reference_zero") { 0 } else { 600 }
    Assert-QsdkR23d1Exact (
        [string]$receipt.schema_version -ceq
            "sporespore_qsdk_r23d1_rapier_worker_preflight_v1" -and
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
        [bool]$receipt.entrypoint_control_flow_complete -and
        -not [bool]$receipt.physics_state_modified -and
        -not [bool]$receipt.locomotion_outcome_exposed -and
        -not [bool]$receipt.physical_execution_authorized -and
        -not [bool]$receipt.q_sdk_r23_satisfied -and
        -not [bool]$receipt.physical_acceptance_authority
    ) "QSDK-R23D1 normalized Rapier worker receipt changed: $armId"
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
    ) "QSDK-R23D1 exact seeded perturbation changed: $armId"
    $actualActuatorOrder = @($mapping.ordered_commands | ForEach-Object {
        [string]$_.actuator_id
    })
    $nativePositionTargets = @($mapping.ordered_commands | Where-Object {
        $null -ne $_.native_target_position_rad
    })
    $hostClamps = @($mapping.ordered_commands | Where-Object {
        [bool]$_.host_clamped
    })
    Assert-QsdkR23d1Exact (
        [bool]$native.native_controller_step_passed -and
        [int]$native.native_controller_command_count -eq 8 -and
        [bool]$native.native_controller_command_order_exact -and
        [bool]$native.native_next_memory_exact -and
        [string]$native.command_role -ceq $expectedRole -and
        [int]$native.actual_world_build_count -eq 0 -and
        -not [bool]$native.physics_state_modified -and
        -not [bool]$native.locomotion_outcome_exposed -and
        -not [bool]$native.physical_acceptance_authority -and
        [string]$controller.policy_id -ceq $policyId -and
        [int]$controller.semantic_step -eq $expectedStep -and
        [math]::Abs([double]$controller.desired_heading_error_rad - $expectedOffset) -le 1.0e-12 -and
        [math]::Abs([double]$controller.requested_steering_fraction + 1.3 * $expectedOffset) -le 1.0e-12 -and
        [string]$mapping.host_profile_id -ceq "rapier_force_based_velocity_only_v1" -and
        [string]$mapping.native_motor_model_id -ceq "force_based_velocity_only" -and
        [double]$mapping.native_position_stiffness -eq 0.0 -and
        -not [bool]$mapping.independent_native_position_feedback_applied -and
        ($actualActuatorOrder -join "|") -ceq ($expectedActuatorOrder -join "|") -and
        $nativePositionTargets.Count -eq 0 -and
        $hostClamps.Count -eq 0
    ) "QSDK-R23D1 native Rapier heading-command boundary changed: $armId"
    Assert-QsdkR23d1Exact (
        [string]$validation.schema_version -ceq
            "sporespore_balanced_wave_command_validation_receipt_v1" -and
        [bool]$validation.ok -and
        [bool]$validation.enabled -and
        [string]$validation.validation_mode -ceq
            "rapier_force_based_velocity_only_structure_mapping_and_motor_readback_v1" -and
        [bool]$validation.heading_command_conditioned -and
        -not [bool]$validation.legacy_command_parity_applicable -and
        -not [bool]$validation.legacy_command_parity_checked -and
        -not [bool]$validation.legacy_command_parity_waived -and
        [int]$validation.world_build_count -eq 0 -and
        -not [bool]$validation.physics_state_modified -and
        -not [bool]$validation.physical_acceptance_authority
    ) "QSDK-R23D1 Rapier validation provenance changed: $armId"
    Assert-QsdkR23d1Exact (
        [string]$productionReport.schema_version -ceq
            "sporespore_qsdk_r23d1_engine_cell_report_v2" -and
        [string]$productionReport.cell_id -ceq "$engineId`__$armId" -and
        [string]$productionReport.source_commit -ceq ("0" * 40) -and
        [int]$productionReport.execution.world_build_count -eq 1 -and
        [string]$productionReport.host.velocity_only_profile_id -ceq
            "rapier_force_based_velocity_only_v1" -and
        -not [bool]$productionReport.claims.q_sdk_r23_satisfied -and
        -not [bool]$productionReport.claims.physical_acceptance_authority
    ) "QSDK-R23D1 Rapier normalized-report composer changed: $armId"
    $evaluation = Invoke-QsdkR23d1ProductionCellEvaluation `
        -Report $productionReport -ArmId $armId
    Assert-QsdkR23d1Exact (
        [string]$evaluation.cell_id -ceq "$engineId`__$armId" -and
        [bool]$evaluation.execution_valid -and
        [bool]$evaluation.screen_cell_passed -and
        [int]$evaluation.failed_gate_count -eq 0
    ) "QSDK-R23D1 production evaluator result changed: $armId"
    $productionEvaluationCount += 1
    $receipts[$armId] = $receipt
}
Assert-QsdkR23d1Exact ($productionEvaluationCount -eq 3) (
    "QSDK-R23D1 did not production-evaluate all three Rapier reports"
)

$zeroHeld = [double]$receipts.reference_zero.native_heading_preflight.controller_receipt.held_steering_fraction
$positiveHeld = [double]$receipts.positive_heading.native_heading_preflight.controller_receipt.held_steering_fraction
$negativeHeld = [double]$receipts.negative_heading.native_heading_preflight.controller_receipt.held_steering_fraction
Assert-QsdkR23d1Exact (
    [math]::Abs($zeroHeld) -le 1.0e-15 -and
    $positiveHeld -lt 0.0 -and
    $negativeHeld -gt 0.0 -and
    [math]::Abs($positiveHeld + $negativeHeld) -le 1.0e-12
) "QSDK-R23D1 Rapier signed steering mirror changed"

$unknownArmExecution = Invoke-QsdkR23d1RapierWorker `
    -Arguments @("--preflight-only", "--arm", "undeclared_arm") -Label "unknown-arm"
Assert-QsdkR23d1Exact (
    -not [bool]$unknownArmExecution.timed_out -and
    [int]$unknownArmExecution.exit_code -ne 0
) "QSDK-R23D1 unknown Rapier arm did not fail closed"
$unknownArm = Get-QsdkR23d1MarkerReceipt $unknownArmExecution $failurePrefix
Assert-QsdkR23d1Exact (
    [string]$unknownArm.failure_code -ceq
        "QSDK_R23D1_RAP_ARM_UNKNOWN:undeclared_arm" -and
    [int]$unknownArm.world_build_count -eq 0 -and
    -not [bool]$unknownArm.physical_acceptance_authority
) "QSDK-R23D1 unknown-arm failure receipt changed"

$bypassExecution = Invoke-QsdkR23d1RapierWorker `
    -Arguments @(
        "--arm", "reference_zero", "--source-commit", ("0" * 40)
    ) -Label "physical-bypass"
Assert-QsdkR23d1Exact (
    -not [bool]$bypassExecution.timed_out -and
    [int]$bypassExecution.exit_code -ne 0
) "QSDK-R23D1 direct physical Rapier bypass did not fail closed"
$bypass = Get-QsdkR23d1MarkerReceipt $bypassExecution $failurePrefix
$cellMarkers = @(([string]$bypassExecution.stdout -split "`r?`n") | Where-Object {
    $_.StartsWith($cellPrefix, [System.StringComparison]::Ordinal)
})
Assert-QsdkR23d1Exact (
    [string]$bypass.failure_code -ceq
        "QSDK_R23D1_RAP_PHYSICAL_IDENTITY_CLOSED" -and
    [int]$bypass.world_build_count -eq 0 -and
    $cellMarkers.Count -eq 0 -and
    -not [bool]$bypass.physical_acceptance_authority
) "QSDK-R23D1 direct Rapier physical bypass receipt changed"

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
        "QSDK_R23D1_RAPIER_WORKER_BUNDLE " +
        ($bundle | ConvertTo-Json -Depth 100 -Compress)
    )
}

Write-Host (
    "QSDK_R23D1_RAPIER_WORKER_PASS arms=3 entrypoints=3 " +
    "native_steps=3 native_commands=24 normalized_reports=3 " +
    "production_evaluator=3/3 " +
    "validation=force_based_velocity_only_receipts_no_legacy_parity " +
    "signed_mirror=True negative_controls=2 physical_identity_closed=True " +
    "worlds=0 outcome_exposed=False physical_authority=False"
)
