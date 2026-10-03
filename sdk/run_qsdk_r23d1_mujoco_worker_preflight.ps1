#requires -Version 7.0

[CmdletBinding()]
param([switch]$EmitBundle)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$mujocoRoot = Join-Path $sdkRoot "adapters\mujoco"
$python = Join-Path $mujocoRoot ".venv\Scripts\python.exe"
$pythonCoreRoot = Join-Path $sdkRoot "python"
$manifestPath = Join-Path $sdkRoot "Cargo.toml"
$releaseLibraryPath = Join-Path $sdkRoot (
    "target\release\sporespore_locomotion_core.dll"
)
$contractPath = Join-Path $sdkRoot "turning\physical_development_contract_v1.json"
$evaluatorPath = Join-Path $sdkRoot "turning\physical_development.py"
$workerPath = Join-Path $mujocoRoot (
    "sporespore_mujoco_adapter\qsdk_r23d1_heading_response.py"
)
$testPath = Join-Path $mujocoRoot "test_qsdk_r23d1_heading_response.py"
$preflightPrefix = "QSDK_R23D1_MUJOCO_PREFLIGHT "
$failurePrefix = "QSDK_R23D1_MUJOCO_FAILURE "
$cellPrefix = "QSDK_R23D1_MUJOCO_CELL "
$campaignId = "QSDK-R23D1-THREE-ENGINE-HEADING-RESPONSE-DEVELOPMENT"
$gateId = "QSDK-R23D1"
$engineId = "mujoco"
$policyId = "sporespore_balanced_wave_bw5r_b_v1"
$policyDigest = (
    "sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f"
)
$morphologyId = "qsdk_r05_generated_s169"
$hostProfileId = (
    "mujoco_s169_per_actuator_force_limited_five_substep_vh5_validated_v1"
)
$nativeMotorModelId = (
    "velocity_servo_s169_per_actuator_force_limited_five_substep_" +
    "vh5_validated_v1"
)
$validationMode = (
    "mujoco_vh5_characterized_velocity_only_xml_mapping_and_" +
    "force_limit_receipts_v1"
)
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

function Invoke-QsdkR23d1MujocoWorker {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$Label
    )
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $python
    $start.WorkingDirectory = $mujocoRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.Environment["SPORESPORE_LOCOMOTION_LIBRARY"] = $releaseLibraryPath
    $start.Environment["PYTHONPATH"] = $pythonCoreRoot
    foreach ($name in $attemptEnvironmentNames) {
        [void]$start.Environment.Remove($name)
    }
    [void]$start.ArgumentList.Add("-m")
    [void]$start.ArgumentList.Add(
        "sporespore_mujoco_adapter.qsdk_r23d1_heading_response"
    )
    foreach ($argument in $Arguments) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    Assert-QsdkR23d1Exact $process.Start() (
        "QSDK-R23D1 failed to start MuJoCo worker route: $Label"
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
        [Parameter(Mandatory)][Collections.IDictionary]$Execution,
        [Parameter(Mandatory)][string]$Prefix
    )
    $lines = @(([string]$Execution.stdout -split "`r?`n") | Where-Object {
        $_.StartsWith($Prefix, [StringComparison]::Ordinal)
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
        [Parameter(Mandatory)][Collections.IDictionary]$Report,
        [Parameter(Mandatory)][string]$ArmId
    )
    $runRoot = Join-Path $sdkRoot (
        "target\qsdk-r23d1-mujoco-preflight\" +
        [guid]::NewGuid().ToString("N")
    )
    [void][IO.Directory]::CreateDirectory($runRoot)
    $inputPath = Join-Path $runRoot "$ArmId-normalized-report.json"
    [IO.File]::WriteAllText(
        $inputPath,
        ($Report | ConvertTo-Json -Depth 100 -Compress) + [Environment]::NewLine,
        [Text.UTF8Encoding]::new($false)
    )
    $output = & python $evaluatorPath evaluate-cell $inputPath 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
    $prefix = "QSDK_R23D1_CELL_EVALUATION "
    $lines = @($output -split "`r?`n" | Where-Object {
        $_.StartsWith($prefix, [StringComparison]::Ordinal)
    })
    Assert-QsdkR23d1Exact ($exitCode -eq 0 -and $lines.Count -eq 1) (
        "QSDK-R23D1 production evaluator rejected MuJoCo composer output:`n$output"
    )
    return $lines[0].Substring($prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

foreach ($path in @(
    $python,
    $pythonCoreRoot,
    $manifestPath,
    $contractPath,
    $evaluatorPath,
    $workerPath,
    $testPath
)) {
    Assert-QsdkR23d1Exact (Test-Path -LiteralPath $path) (
        "QSDK-R23D1 MuJoCo worker preflight input missing: $path"
    )
}
Assert-QsdkR23d1Exact (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D1 MuJoCo worker repository identity mismatch"

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
    --package sporespore-locomotion-core --release --locked --offline `
    2>&1 | Out-String
Assert-QsdkR23d1Exact ($LASTEXITCODE -eq 0) (
    "QSDK-R23D1 MuJoCo core did not build:`n$buildOutput"
)
Assert-QsdkR23d1Exact (
    Test-Path -LiteralPath $releaseLibraryPath -PathType Leaf
) "QSDK-R23D1 MuJoCo release core library is missing"
$librarySha256 = "sha256:" + (
    Get-FileHash -LiteralPath $releaseLibraryPath -Algorithm SHA256
).Hash.ToLowerInvariant()

$oldLibrary = $env:SPORESPORE_LOCOMOTION_LIBRARY
$oldPythonPath = $env:PYTHONPATH
try {
    $env:SPORESPORE_LOCOMOTION_LIBRARY = $releaseLibraryPath
    $env:PYTHONPATH = $mujocoRoot + [IO.Path]::PathSeparator + $pythonCoreRoot
    $testOutput = & $python -m unittest -v test_qsdk_r23d1_heading_response `
        2>&1 | Out-String
    Assert-QsdkR23d1Exact ($LASTEXITCODE -eq 0) (
        "QSDK-R23D1 MuJoCo unit tests failed:`n$testOutput"
    )
} finally {
    $env:SPORESPORE_LOCOMOTION_LIBRARY = $oldLibrary
    $env:PYTHONPATH = $oldPythonPath
}

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
    $execution = Invoke-QsdkR23d1MujocoWorker `
        -Arguments @("--preflight-only", "--arm", $armId) -Label $armId
    Assert-QsdkR23d1Exact (-not [bool]$execution.timed_out) (
        "QSDK-R23D1 MuJoCo preflight timed out: $armId"
    )
    Assert-QsdkR23d1Exact ([int]$execution.exit_code -eq 0) (
        "QSDK-R23D1 MuJoCo preflight exited nonzero: $armId`n$($execution.stderr)"
    )
    $receipt = Get-QsdkR23d1MarkerReceipt $execution $preflightPrefix
    $native = [Collections.IDictionary]$receipt.native_heading_preflight
    $controller = [Collections.IDictionary]$native.controller_receipt
    $mapping = [Collections.IDictionary]$native.host_mapping
    $modelXml = [Collections.IDictionary]$native.model_xml_receipt
    $validation = [Collections.IDictionary]$native.command_validation_receipt
    $productionReport = [Collections.IDictionary]$receipt.production_normalized_report
    $expectedStep = if ($armId -ceq "reference_zero") { 0 } else { 600 }
    Assert-QsdkR23d1Exact (
        [string]$receipt.schema_version -ceq
            "sporespore_qsdk_r23d1_mujoco_worker_preflight_v1" -and
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
        [math]::Abs(
            [double]$receipt.turn_heading_offset_rad - $expectedOffset
        ) -le 1.0e-15 -and
        [string]$receipt.core.version -ceq "0.1.0" -and
        [IO.Path]::GetFullPath([string]$receipt.core.library_path) -ceq
            $releaseLibraryPath -and
        [string]$receipt.core.library_sha256 -ceq $librarySha256 -and
        [int]$receipt.actual_world_build_count -eq 0 -and
        [int]$receipt.model_construction_count -eq 0 -and
        [bool]$receipt.entrypoint_control_flow_complete -and
        -not [bool]$receipt.physics_state_modified -and
        -not [bool]$receipt.locomotion_outcome_exposed -and
        -not [bool]$receipt.physical_execution_authorized -and
        -not [bool]$receipt.q_sdk_r23_satisfied -and
        -not [bool]$receipt.physical_acceptance_authority
    ) "QSDK-R23D1 normalized MuJoCo worker receipt changed: $armId"
    $fixture = [Collections.IDictionary]$contract.fixture.initial_perturbation
    $initial = [Collections.IDictionary]$receipt.initial_perturbation
    Assert-QsdkR23d1Exact (
        [int]$initial.campaign_seed -eq [int]$fixture.campaign_seed -and
        [double]$initial.fixture_vertical_clearance_m -eq
            [double]$fixture.fixture_vertical_clearance_m -and
        [double]$initial.fixture_yaw_rad -eq
            [double]$fixture.fixture_yaw_rad -and
        [int]$initial.gait_phase_offset_ticks -eq
            [int]$fixture.gait_phase_offset_ticks -and
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
        [int]$native.actual_world_build_count -eq 0 -and
        [int]$native.model_construction_count -eq 0 -and
        -not [bool]$native.physics_state_modified -and
        -not [bool]$native.locomotion_outcome_exposed -and
        [string]$controller.policy_id -ceq $policyId -and
        [int]$controller.semantic_step -eq $expectedStep -and
        [math]::Abs(
            [double]$controller.desired_heading_error_rad - $expectedOffset
        ) -le 1.0e-12 -and
        [math]::Abs(
            [double]$controller.requested_steering_fraction +
            1.3 * $expectedOffset
        ) -le 1.0e-12 -and
        [string]$mapping.host_profile_id -ceq $hostProfileId -and
        [string]$mapping.engine_id -ceq $engineId -and
        [string]$mapping.native_motor_model_id -ceq $nativeMotorModelId -and
        [double]$mapping.native_position_stiffness -eq 0.0 -and
        -not [bool]$mapping.independent_native_position_feedback_applied -and
        [bool]$mapping.host_response_characterized_for_this_profile -and
        ($actualActuatorOrder -join "|") -ceq
            ($expectedActuatorOrder -join "|") -and
        $nativePositionTargets.Count -eq 0 -and
        $hostClamps.Count -eq 0
    ) "QSDK-R23D1 native MuJoCo heading-command boundary changed: $armId"
    Assert-QsdkR23d1Exact (
        [string]$modelXml.schema_version -ceq
            "sporespore_qsdk_r23d1_mujoco_model_xml_receipt_v1" -and
        [bool]$modelXml.ok -and
        [int]$modelXml.native_actuator_count -eq 8 -and
        [bool]$modelXml.native_actuator_order_exact -and
        [string]$modelXml.native_motor_model_id -ceq $nativeMotorModelId -and
        [double]$modelXml.velocity_gain_nm_s_per_rad -eq 10.0 -and
        [double]$modelXml.internal_timestep_s -eq (1.0 / 600.0) -and
        [int]$modelXml.internal_steps_per_controller_step -eq 5 -and
        [int]$modelXml.model_construction_count -eq 0 -and
        -not [bool]$modelXml.physics_state_modified -and
        -not [bool]$modelXml.physical_acceptance_authority
    ) "QSDK-R23D1 production MuJoCo XML receipt changed: $armId"
    Assert-QsdkR23d1Exact (
        [string]$validation.schema_version -ceq
            "sporespore_balanced_wave_command_validation_receipt_v1" -and
        [bool]$validation.ok -and
        [bool]$validation.enabled -and
        [string]$validation.validation_mode -ceq $validationMode -and
        [bool]$validation.heading_command_conditioned -and
        -not [bool]$validation.legacy_command_parity_applicable -and
        -not [bool]$validation.legacy_command_parity_checked -and
        -not [bool]$validation.legacy_command_parity_waived -and
        [int]$validation.world_build_count -eq 0 -and
        -not [bool]$validation.physics_state_modified -and
        -not [bool]$validation.physical_acceptance_authority
    ) "QSDK-R23D1 MuJoCo validation provenance changed: $armId"
    Assert-QsdkR23d1Exact (
        [string]$productionReport.schema_version -ceq
            "sporespore_qsdk_r23d1_engine_cell_report_v2" -and
        [string]$productionReport.cell_id -ceq "$engineId`__$armId" -and
        [string]$productionReport.source_commit -ceq ("0" * 40) -and
        [int]$productionReport.execution.world_build_count -eq 1 -and
        [string]$productionReport.host.velocity_only_profile_id -ceq
            $hostProfileId -and
        [bool]$productionReport.host.synthetic_preflight_only -and
        -not [bool]$productionReport.claims.q_sdk_r23_satisfied -and
        -not [bool]$productionReport.claims.physical_acceptance_authority
    ) "QSDK-R23D1 MuJoCo normalized-report composer changed: $armId"
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
    "QSDK-R23D1 did not production-evaluate all three MuJoCo reports"
)

$zeroHeld = [double](
    $receipts.reference_zero.native_heading_preflight.controller_receipt.
        held_steering_fraction
)
$positiveHeld = [double](
    $receipts.positive_heading.native_heading_preflight.controller_receipt.
        held_steering_fraction
)
$negativeHeld = [double](
    $receipts.negative_heading.native_heading_preflight.controller_receipt.
        held_steering_fraction
)
Assert-QsdkR23d1Exact (
    [math]::Abs($zeroHeld) -le 1.0e-15 -and
    $positiveHeld -lt 0.0 -and
    $negativeHeld -gt 0.0 -and
    [math]::Abs($positiveHeld + $negativeHeld) -le 1.0e-12
) "QSDK-R23D1 MuJoCo signed steering mirror changed"

$unknownArmExecution = Invoke-QsdkR23d1MujocoWorker `
    -Arguments @("--preflight-only", "--arm", "undeclared_arm") `
    -Label "unknown-arm"
Assert-QsdkR23d1Exact (
    -not [bool]$unknownArmExecution.timed_out -and
    [int]$unknownArmExecution.exit_code -ne 0
) "QSDK-R23D1 unknown MuJoCo arm did not fail closed"
$unknownArm = Get-QsdkR23d1MarkerReceipt $unknownArmExecution $failurePrefix
Assert-QsdkR23d1Exact (
    [string]$unknownArm.failure_code -ceq
        "QSDK_R23D1_MJC_ARM_UNKNOWN:undeclared_arm" -and
    [int]$unknownArm.world_attempt_count -eq 0 -and
    [int]$unknownArm.world_build_count -eq 0 -and
    -not [bool]$unknownArm.physical_acceptance_authority
) "QSDK-R23D1 unknown-arm failure receipt changed"

$bypassExecution = Invoke-QsdkR23d1MujocoWorker `
    -Arguments @(
        "--arm", "reference_zero", "--source-commit", ("0" * 40)
    ) -Label "physical-bypass"
Assert-QsdkR23d1Exact (
    -not [bool]$bypassExecution.timed_out -and
    [int]$bypassExecution.exit_code -ne 0
) "QSDK-R23D1 direct physical MuJoCo bypass did not fail closed"
$bypass = Get-QsdkR23d1MarkerReceipt $bypassExecution $failurePrefix
$cellMarkers = @(([string]$bypassExecution.stdout -split "`r?`n") |
    Where-Object {
        $_.StartsWith($cellPrefix, [StringComparison]::Ordinal)
    })
Assert-QsdkR23d1Exact (
    [string]$bypass.failure_code -ceq
        "QSDK_R23D1_MJC_PHYSICAL_IDENTITY_CLOSED" -and
    [int]$bypass.world_attempt_count -eq 0 -and
    [int]$bypass.world_build_count -eq 0 -and
    $cellMarkers.Count -eq 0 -and
    -not [bool]$bypass.physical_acceptance_authority
) "QSDK-R23D1 direct MuJoCo physical bypass receipt changed"

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
        "QSDK_R23D1_MUJOCO_WORKER_BUNDLE " +
        ($bundle | ConvertTo-Json -Depth 100 -Compress)
    )
}

Write-Host (
    "QSDK_R23D1_MUJOCO_WORKER_PASS arms=3 entrypoints=3 " +
    "native_steps=3 native_commands=24 normalized_reports=3 " +
    "production_evaluator=3/3 " +
    "validation=vh5_velocity_only_xml_mapping_receipts_no_legacy_parity " +
    "solver=120hz_five_by_600hz signed_mirror=True negative_controls=2 " +
    "physical_identity_closed=True worlds=0 models=0 " +
    "outcome_exposed=False physical_authority=False"
)
