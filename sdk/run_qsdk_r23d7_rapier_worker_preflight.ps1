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
$contractPath = Join-Path $sdkRoot "turning\r23d7_neutral_stance_preregistration_v1.json"
$workerPath = Join-Path $sdkRoot "adapters\rapier\src\qsdk_r23d3_phase_balanced.rs"
$binarySourcePath = Join-Path $sdkRoot (
    "adapters\rapier\src\bin\qsdk_r23d7_neutral_stance.rs"
)
$binaryPath = Join-Path $sdkRoot "target\release\qsdk_r23d7_neutral_stance.exe"
$preflightPrefix = "QSDK_R23D7_RAPIER_PREFLIGHT "
$failurePrefix = "QSDK_R23D7_RAPIER_FAILURE "
$cellPrefix = "QSDK_R23D7_RAPIER_CELL "
$campaignId = "QSDK-R23D7-NEUTRAL-STANCE-ACQUISITION-BILATERAL-TURN-DEVELOPMENT"
$gateId = "QSDK-R23D7"

function Assert-R23D7RapierExact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Invoke-R23D7RapierExecutable {
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
        "SPORESPORE_QSDK_R23D7_FREEZE",
        "SPORESPORE_QSDK_R23D7_ATTEMPT",
        "SPORESPORE_QSDK_R23D7_TOKEN",
        "SPORESPORE_QSDK_R23D7_STAGE",
        "SPORESPORE_QSDK_R23D7_CELL",
        "SPORESPORE_QSDK_R23D7_ENGINE",
        "SPORESPORE_QSDK_R23D7_ATTEMPT_ROOT"
    )) {
        [void]$start.Environment.Remove($name)
    }
    foreach ($argument in $Arguments) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    Assert-R23D7RapierExact $process.Start() (
        "QSDK-R23D7 failed to start Rapier $Label"
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

function Get-R23D7RapierMarkers {
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
    $binarySourcePath
)) {
    Assert-R23D7RapierExact (Test-Path -LiteralPath $path -PathType Leaf) (
        "QSDK-R23D7 Rapier preflight input missing: $path"
    )
}
Assert-R23D7RapierExact (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D7 Rapier repository identity mismatch"

$contract = Get-Content -Raw -LiteralPath $contractPath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D7RapierExact (
    [string]$contract.schema_version -ceq
        "sporespore_qsdk_r23d7_neutral_stance_preregistration_v1" -and
    [string]$contract.campaign_id -ceq $campaignId -and
    [string]$contract.gate_id -ceq $gateId -and
    [int]$contract.frozen_schedule_and_gate_snapshot.turning_controller_semantic_step_count -eq 2992 -and
    [int]$contract.frozen_schedule_and_gate_snapshot.terminal_stance_step_count -eq 540 -and
    [int]$contract.frozen_schedule_and_gate_snapshot.passive_settle_step_count -eq 240 -and
    [int]$contract.frozen_schedule_and_gate_snapshot.total_traced_step_count -eq 3772 -and
    -not [bool]$contract.authorization.physical_execution_authorized
) "QSDK-R23D7 Rapier frozen declaration changed"

. $materializerPath
$sourceCommit = (git -C $repoRoot rev-parse HEAD).Trim()
$build = Invoke-SporeSporeR23D3PinnedCargo `
    -RepoRoot $repoRoot `
    -SourceCommit $sourceCommit `
    -TargetRoot (Join-Path $sdkRoot "target") `
    -CargoArguments @(
        "build", "--quiet", "--release", "--locked", "--offline",
        "--manifest-path", $manifestPath,
        "--bin", "qsdk_r23d7_neutral_stance"
    )
Assert-R23D7RapierExact (
    [int]$build.exit_code -eq 0 -and
    [bool]$build.cargo_target_root_remapped_to_constant_virtual_prefix -and
    (Test-Path -LiteralPath $binaryPath -PathType Leaf)
) "QSDK-R23D7 pinned Rapier worker build failed"

$expected = [ordered]@{
    reference_zero = 0.0
    positive_heading = 0.2
    negative_heading = -0.2
}
$receipts = @()
foreach ($armId in $expected.Keys) {
    $execution = Invoke-R23D7RapierExecutable -Executable $binaryPath `
        -Label "preflight-$armId" -Arguments @(
            "--stage", "three_engine_confirmation", "--arm", $armId,
            "--preflight-only"
        )
    Assert-R23D7RapierExact (
        -not [bool]$execution.timed_out -and [int]$execution.exit_code -eq 0
    ) "QSDK-R23D7 Rapier preflight failed: $armId"
    $markers = @(Get-R23D7RapierMarkers $execution $preflightPrefix)
    Assert-R23D7RapierExact ($markers.Count -eq 1) (
        "QSDK-R23D7 expected one Rapier preflight receipt: $armId"
    )
    $receipts += $markers[0]
}
Assert-R23D7RapierExact ($receipts.Count -eq 3) (
    "QSDK-R23D7 expected three Rapier preflight receipts"
)
foreach ($receipt in $receipts) {
    $armId = [string]$receipt.arm_id
    Assert-R23D7RapierExact (
        $expected.Contains($armId) -and
        [string]$receipt.schema_version -ceq
            "sporespore_qsdk_r23d7_rapier_worker_preflight_v1" -and
        [string]$receipt.campaign_id -ceq $campaignId -and
        [string]$receipt.gate_id -ceq $gateId -and
        [string]$receipt.engine_id -ceq "rapier_parry" -and
        [string]$receipt.stage_id -ceq "three_engine_confirmation" -and
        [string]$receipt.cell_id -ceq "rapier_parry__neutral_stance__$armId" -and
        [Math]::Abs(
            [double]$receipt.turn_heading_offset_rad - [double]$expected[$armId]
        ) -le 1.0e-15 -and
        [int]$receipt.inherited_r23d3_native_mapping_canary_count -eq 7 -and
        [int]$receipt.inherited_predicate_negative_control_count -eq 35 -and
        [int]$receipt.neutral_stance_algebra_canary_count -eq 5 -and
        [int]$receipt.neutral_stance_mutation_control_count -eq 10 -and
        @($receipt.neutral_stance_mutation_controls_rejected.Values |
            Where-Object { -not [bool]$_ }).Count -eq 0 -and
        [bool]$receipt.production_neutral_stance_composition_complete -and
        [int]$receipt.neutral_target_activation_count -eq 8 -and
        [int]$receipt.canonical_command_count -eq 8 -and
        [int]$receipt.host_command_count -eq 8 -and
        [int]$receipt.fixed_controller_horizon_step_count -eq 2992 -and
        [int]$receipt.fixed_terminal_stance_step_count -eq 540 -and
        [int]$receipt.fixed_passive_settle_step_count -eq 240 -and
        [int]$receipt.fixed_total_trace_step_count -eq 3772 -and
        [int]$receipt.model_construction_count -eq 0 -and
        [int]$receipt.world_attempt_count -eq 0 -and
        [int]$receipt.world_build_count -eq 0 -and
        -not [bool]$receipt.physical_execution_authorized -and
        -not [bool]$receipt.physical_acceptance_authority
    ) "QSDK-R23D7 Rapier preflight receipt changed: $armId"
}
$unknown = Invoke-R23D7RapierExecutable -Executable $binaryPath `
    -Label "unknown-stage" -Arguments @(
        "--stage", "unknown_stage", "--arm", "reference_zero", "--preflight-only"
    )
Assert-R23D7RapierExact (
    -not [bool]$unknown.timed_out -and [int]$unknown.exit_code -ne 0
) "QSDK-R23D7 unknown Rapier identity did not fail closed"
$unknownMarkers = @(Get-R23D7RapierMarkers $unknown $failurePrefix)
Assert-R23D7RapierExact ($unknownMarkers.Count -eq 1) (
    "QSDK-R23D7 unknown Rapier identity emitted no unique failure"
)

$bypass = Invoke-R23D7RapierExecutable -Executable $binaryPath `
    -Label "physical-bypass" -Arguments @(
        "--stage", "three_engine_confirmation", "--arm", "reference_zero",
        "--source-commit", ("0" * 40)
    )
Assert-R23D7RapierExact (
    -not [bool]$bypass.timed_out -and [int]$bypass.exit_code -ne 0
) "QSDK-R23D7 direct Rapier physical bypass did not fail closed"
$bypassMarkers = @(Get-R23D7RapierMarkers $bypass $failurePrefix)
$cellMarkers = @(Get-R23D7RapierMarkers $bypass $cellPrefix)
Assert-R23D7RapierExact ($bypassMarkers.Count -eq 1) (
    "QSDK-R23D7 physical bypass emitted no unique Rapier failure"
)
$failure = $bypassMarkers[0]
Assert-R23D7RapierExact (
    [string]$failure.schema_version -ceq
        "sporespore_qsdk_r23d7_worker_failure_v1" -and
    [string]$failure.failure_code -ceq
        "QSDK_R23D7_RAP_PHYSICAL_AUTHORIZATION_REQUIRED" -and
    [string]$failure.failure_stage -ceq "before_world" -and
    [int]$failure.world_attempt_count -eq 0 -and
    [int]$failure.world_build_count -eq 0 -and
    $null -eq $failure.trace_artifact -and
    $cellMarkers.Count -eq 0 -and
    -not [bool]$failure.claims.physical_acceptance_authority
) "QSDK-R23D7 Rapier physical-bypass receipt changed"

Write-Host (
    "QSDK_R23D7_RAPIER_WORKER_PASS identities=3 " +
    "fixed_horizon_proofs=3 inherited_canaries=21 " +
    "inherited_predicate_controls=105 neutral_stance_canaries=15 " +
    "neutral_stance_mutation_controls=30 negative_controls=2 " +
    "model_constructions=0 worlds=0 physical_authority=False"
)
