#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$manifestPath = Join-Path $sdkRoot "adapters\rapier\Cargo.toml"
$materializerPath = Join-Path $sdkRoot "r23d3_reproducible_runtime_materialization.ps1"
$contractPath = Join-Path $sdkRoot "turning\r23d4_terminal_stabilization_preregistration_v1.json"
$workerPath = Join-Path $sdkRoot "adapters\rapier\src\qsdk_r23d3_phase_balanced.rs"
$restorationPath = Join-Path $sdkRoot (
    "adapters\rapier\src\bw19v_velocity_only_pose_hold_restoration_ph1.rs"
)
$binarySourcePath = Join-Path $sdkRoot (
    "adapters\rapier\src\bin\qsdk_r23d4_terminal_stabilization.rs"
)
$aggregateSourcePath = Join-Path $sdkRoot (
    "adapters\rapier\src\bin\qsdk_r23d4_rapier_preflight_all.rs"
)
$binaryPath = Join-Path $sdkRoot "target\release\qsdk_r23d4_terminal_stabilization.exe"
$aggregatePath = Join-Path $sdkRoot "target\release\qsdk_r23d4_rapier_preflight_all.exe"
$preflightPrefix = "QSDK_R23D4_RAPIER_PREFLIGHT "
$failurePrefix = "QSDK_R23D4_RAPIER_FAILURE "
$cellPrefix = "QSDK_R23D4_RAPIER_CELL "
$campaignId = "QSDK-R23D4-TERMINAL-STABILIZED-BILATERAL-TURN-DEVELOPMENT"
$gateId = "QSDK-R23D4"

function Assert-R23D4RapierExact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Invoke-R23D4RapierExecutable {
    param(
        [Parameter(Mandatory)][string]$Executable,
        [AllowEmptyCollection()][string[]]$Arguments = @(),
        [Parameter(Mandatory)][string]$Label
    )
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $Executable
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($name in @(
        "SPORESPORE_QSDK_R23D4_FREEZE",
        "SPORESPORE_QSDK_R23D4_ATTEMPT",
        "SPORESPORE_QSDK_R23D4_TOKEN",
        "SPORESPORE_QSDK_R23D4_STAGE",
        "SPORESPORE_QSDK_R23D4_CELL",
        "SPORESPORE_QSDK_R23D4_ENGINE",
        "SPORESPORE_QSDK_R23D4_ATTEMPT_ROOT"
    )) {
        [void]$start.Environment.Remove($name)
    }
    foreach ($argument in $Arguments) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    Assert-R23D4RapierExact $process.Start() (
        "QSDK-R23D4 failed to start Rapier $Label"
    )
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit(180000)
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

function Get-R23D4RapierMarkers {
    param(
        [Parameter(Mandatory)][Collections.IDictionary]$Execution,
        [Parameter(Mandatory)][string]$Prefix
    )
    return @(($Execution.stdout -split "`r?`n") | Where-Object {
        $_.StartsWith($Prefix, [StringComparison]::Ordinal)
    } | ForEach-Object {
        $_.Substring($Prefix.Length) | ConvertFrom-Json -AsHashtable -Depth 100
    })
}

foreach ($path in @(
    $manifestPath,
    $materializerPath,
    $contractPath,
    $workerPath,
    $restorationPath,
    $binarySourcePath,
    $aggregateSourcePath
)) {
    Assert-R23D4RapierExact (Test-Path -LiteralPath $path -PathType Leaf) (
        "QSDK-R23D4 Rapier preflight input missing: $path"
    )
}
Assert-R23D4RapierExact (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D4 Rapier repository identity mismatch"

$contract = Get-Content -Raw -LiteralPath $contractPath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D4RapierExact (
    [string]$contract.schema_version -ceq
        "sporespore_qsdk_r23d4_terminal_stabilization_preregistration_v1" -and
    [string]$contract.campaign_id -ceq $campaignId -and
    [string]$contract.gate_id -ceq $gateId -and
    [int]$contract.command_and_terminal_schedule.turning_controller_semantic_step_count -eq 2992 -and
    [int]$contract.command_and_terminal_schedule.terminal_restoration_step_count -eq 540 -and
    [int]$contract.command_and_terminal_schedule.passive_settle_step_count -eq 240 -and
    [int]$contract.command_and_terminal_schedule.total_traced_step_count -eq 3772 -and
    -not [bool]$contract.authorization.physical_execution_authorized
) "QSDK-R23D4 Rapier frozen declaration changed"

. $materializerPath
$sourceCommit = (git -C $repoRoot rev-parse HEAD).Trim()
$build = Invoke-SporeSporeR23D3PinnedCargo `
    -RepoRoot $repoRoot `
    -SourceCommit $sourceCommit `
    -TargetRoot (Join-Path $sdkRoot "target") `
    -CargoArguments @(
        "build", "--quiet", "--release", "--locked", "--offline",
        "--manifest-path", $manifestPath,
        "--bin", "qsdk_r23d4_terminal_stabilization",
        "--bin", "qsdk_r23d4_rapier_preflight_all"
    )
Assert-R23D4RapierExact (
    [int]$build.exit_code -eq 0 -and
    [bool]$build.cargo_target_root_remapped_to_constant_virtual_prefix -and
    (Test-Path -LiteralPath $binaryPath -PathType Leaf) -and
    (Test-Path -LiteralPath $aggregatePath -PathType Leaf)
) "QSDK-R23D4 pinned Rapier worker build failed"

$aggregate = Invoke-R23D4RapierExecutable `
    -Executable $aggregatePath -Arguments @() -Label "all-identities"
Assert-R23D4RapierExact (
    -not [bool]$aggregate.timed_out -and [int]$aggregate.exit_code -eq 0
) "QSDK-R23D4 aggregate Rapier preflight failed"
$receipts = @(Get-R23D4RapierMarkers $aggregate $preflightPrefix)
Assert-R23D4RapierExact ($receipts.Count -eq 3) (
    "QSDK-R23D4 expected three Rapier preflight receipts"
)
$expected = [ordered]@{
    reference_zero = 0.0
    positive_heading = 0.2
    negative_heading = -0.2
}
foreach ($receipt in $receipts) {
    $armId = [string]$receipt.arm_id
    Assert-R23D4RapierExact (
        $expected.Contains($armId) -and
        [string]$receipt.schema_version -ceq
            "sporespore_qsdk_r23d4_rapier_worker_preflight_v1" -and
        [string]$receipt.campaign_id -ceq $campaignId -and
        [string]$receipt.gate_id -ceq $gateId -and
        [string]$receipt.engine_id -ceq "rapier_parry" -and
        [string]$receipt.stage_id -ceq "three_engine_confirmation" -and
        [string]$receipt.cell_id -ceq "rapier_parry__onset_600__$armId" -and
        [Math]::Abs(
            [double]$receipt.turn_heading_offset_rad - [double]$expected[$armId]
        ) -le 1.0e-15 -and
        [int]$receipt.inherited_r23d3_native_mapping_canary_count -eq 7 -and
        [int]$receipt.inherited_predicate_negative_control_count -eq 35 -and
        [int]$receipt.borrowed_ph1_restoration_negative_control_count -eq 33 -and
        [bool]$receipt.borrowed_ph1_real_shaped_restoration_canary_passed -and
        [int]$receipt.fixed_controller_horizon_step_count -eq 2992 -and
        [int]$receipt.fixed_terminal_restoration_step_count -eq 540 -and
        [int]$receipt.fixed_passive_settle_step_count -eq 240 -and
        [int]$receipt.fixed_total_trace_step_count -eq 3772 -and
        [int]$receipt.model_construction_count -eq 0 -and
        [int]$receipt.world_attempt_count -eq 0 -and
        [int]$receipt.world_build_count -eq 0 -and
        -not [bool]$receipt.physical_execution_authorized -and
        -not [bool]$receipt.physical_acceptance_authority
    ) "QSDK-R23D4 Rapier preflight receipt changed: $armId"
}

$unknown = Invoke-R23D4RapierExecutable -Executable $binaryPath `
    -Label "unknown-stage" -Arguments @(
        "--stage", "unknown_stage", "--arm", "reference_zero", "--preflight-only"
    )
Assert-R23D4RapierExact (
    -not [bool]$unknown.timed_out -and [int]$unknown.exit_code -ne 0
) "QSDK-R23D4 unknown Rapier identity did not fail closed"
$unknownMarkers = @(Get-R23D4RapierMarkers $unknown $failurePrefix)
Assert-R23D4RapierExact ($unknownMarkers.Count -eq 1) (
    "QSDK-R23D4 unknown Rapier identity emitted no unique failure"
)

$bypass = Invoke-R23D4RapierExecutable -Executable $binaryPath `
    -Label "physical-bypass" -Arguments @(
        "--stage", "three_engine_confirmation", "--arm", "reference_zero",
        "--source-commit", ("0" * 40)
    )
Assert-R23D4RapierExact (
    -not [bool]$bypass.timed_out -and [int]$bypass.exit_code -ne 0
) "QSDK-R23D4 direct Rapier physical bypass did not fail closed"
$bypassMarkers = @(Get-R23D4RapierMarkers $bypass $failurePrefix)
$cellMarkers = @(Get-R23D4RapierMarkers $bypass $cellPrefix)
Assert-R23D4RapierExact ($bypassMarkers.Count -eq 1) (
    "QSDK-R23D4 physical bypass emitted no unique Rapier failure"
)
$failure = $bypassMarkers[0]
Assert-R23D4RapierExact (
    [string]$failure.schema_version -ceq
        "sporespore_qsdk_r23d4_worker_failure_v1" -and
    [string]$failure.failure_code -ceq
        "QSDK_R23D4_RAP_PHYSICAL_AUTHORIZATION_REQUIRED" -and
    [string]$failure.failure_stage -ceq "before_world" -and
    [int]$failure.world_attempt_count -eq 0 -and
    [int]$failure.world_build_count -eq 0 -and
    $null -eq $failure.trace_artifact -and
    $cellMarkers.Count -eq 0 -and
    -not [bool]$failure.claims.physical_acceptance_authority
) "QSDK-R23D4 Rapier physical-bypass receipt changed"

Write-Host (
    "QSDK_R23D4_RAPIER_WORKER_PASS identities=3 " +
    "fixed_horizon_proofs=3 inherited_canaries=21 " +
    "inherited_predicate_controls=105 restoration_gate_executions=1 " +
    "restoration_negative_controls=33 negative_controls=2 " +
    "model_constructions=0 worlds=0 physical_authority=False"
)
