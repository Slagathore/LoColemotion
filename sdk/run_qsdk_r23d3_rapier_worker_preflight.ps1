#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$manifestPath = Join-Path $sdkRoot "adapters\rapier\Cargo.toml"
$runtimeMaterializationPath = Join-Path `
    $sdkRoot `
    "r23d3_reproducible_runtime_materialization.ps1"
$contractPath = Join-Path `
    $sdkRoot `
    "turning\r23d3_phase_balanced_preregistration_v1.json"
$workerPath = Join-Path `
    $sdkRoot `
    "adapters\rapier\src\qsdk_r23d3_phase_balanced.rs"
$binarySourcePath = Join-Path `
    $sdkRoot `
    "adapters\rapier\src\bin\qsdk_r23d3_phase_balanced.rs"
$binaryPath = Join-Path $sdkRoot "target\release\qsdk_r23d3_phase_balanced.exe"
$preflightPrefix = "QSDK_R23D3_RAPIER_PREFLIGHT "
$failurePrefix = "QSDK_R23D3_RAPIER_FAILURE "
$cellPrefix = "QSDK_R23D3_RAPIER_CELL "
$campaignId = "QSDK-R23D3-PHASE-BALANCED-BILATERAL-TURN-DEVELOPMENT"
$gateId = "QSDK-R23D3"

function Assert-R23D3RapierExact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Invoke-R23D3RapierWorker {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$Label
    )
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $binaryPath
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($name in @(
        "SPORESPORE_QSDK_R23D3_FREEZE",
        "SPORESPORE_QSDK_R23D3_ATTEMPT",
        "SPORESPORE_QSDK_R23D3_TOKEN",
        "SPORESPORE_QSDK_R23D3_STAGE",
        "SPORESPORE_QSDK_R23D3_CELL",
        "SPORESPORE_QSDK_R23D3_ENGINE",
        "SPORESPORE_QSDK_R23D3_ATTEMPT_ROOT"
    )) {
        [void]$start.Environment.Remove($name)
    }
    foreach ($argument in $Arguments) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    Assert-R23D3RapierExact $process.Start() (
        "QSDK-R23D3 failed to start Rapier $Label"
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

function Get-R23D3RapierMarker {
    param(
        [Parameter(Mandatory)][Collections.IDictionary]$Execution,
        [Parameter(Mandatory)][string]$Prefix
    )
    $markers = @(([string]$Execution.stdout -split "`r?`n") | Where-Object {
        $_.StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D3RapierExact ($markers.Count -eq 1) (
        "QSDK-R23D3 expected one '$Prefix' marker from " +
        "$($Execution.label), found $($markers.Count)"
    )
    return $markers[0].Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

foreach ($path in @(
    $manifestPath,
    $runtimeMaterializationPath,
    $contractPath,
    $workerPath,
    $binarySourcePath
)) {
    Assert-R23D3RapierExact (Test-Path -LiteralPath $path) (
        "QSDK-R23D3 Rapier preflight input missing: $path"
    )
}
Assert-R23D3RapierExact (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D3 Rapier repository identity mismatch"

$contract = Get-Content -Raw -LiteralPath $contractPath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D3RapierExact (
    [string]$contract.schema_version -ceq
        "sporespore_qsdk_r23d3_phase_balanced_preregistration_v1" -and
    [string]$contract.campaign_id -ceq $campaignId -and
    [string]$contract.gate_id -ceq $gateId -and
    [int]$contract.command_schedule.controller_semantic_step_count -eq 2992 -and
    [bool]$contract.command_schedule.all_engine_physical_workers_must_execute_exact_fixed_controller_horizon -and
    -not [bool]$contract.authorization.physical_execution_authorized
) "QSDK-R23D3 Rapier frozen declaration changed"

. $runtimeMaterializationPath
$sourceCommit = (git -C $repoRoot rev-parse HEAD).Trim()
$build = Invoke-SporeSporeR23D3PinnedCargo `
    -RepoRoot $repoRoot `
    -SourceCommit $sourceCommit `
    -TargetRoot (Join-Path $sdkRoot "target") `
    -CargoArguments @(
        "build", "--quiet", "--release", "--locked", "--offline",
        "--manifest-path", $manifestPath,
        "--bin", "qsdk_r23d3_phase_balanced"
    )
Assert-R23D3RapierExact (
    [int]$build.exit_code -eq 0 -and
    [bool]$build.cargo_target_root_remapped_to_constant_virtual_prefix -and
    (Test-Path -LiteralPath $binaryPath -PathType Leaf)
) "QSDK-R23D3 pinned Rapier worker build failed"

$testOutput = @(
    cargo test --quiet --locked --offline `
        --manifest-path $manifestPath --lib r23d3_tests -- --nocapture 2>&1
) -join [Environment]::NewLine
Assert-R23D3RapierExact ($LASTEXITCODE -eq 0) (
    "QSDK-R23D3 Rapier worker unit tests failed:`n$testOutput"
)

$onsets = @($contract.stage_a_mujoco_onset_screen.onset_candidates)
$arms = @($contract.stage_b_three_engine_confirmation.ordered_arm_ids)
$fixedHorizonProofs = 0
foreach ($onset in $onsets) {
    foreach ($armId in $arms) {
        $execution = Invoke-R23D3RapierWorker -Label (
            "$([string]$onset.onset_id):$([string]$armId)"
        ) -Arguments @(
            "--stage", "three_engine_confirmation",
            "--onset", [string]$onset.onset_id,
            "--arm", [string]$armId,
            "--preflight-only"
        )
        Assert-R23D3RapierExact (
            -not [bool]$execution.timed_out -and
            [int]$execution.exit_code -eq 0
        ) "QSDK-R23D3 Rapier preflight failed: $($execution.label)"
        $receipt = Get-R23D3RapierMarker $execution $preflightPrefix
        $expectedOffset = [double](
            $contract.stage_b_three_engine_confirmation.arm_heading_offsets_rad[$armId]
        )
        $expectedWarmup = [int]$onset.turn_start_semantic_step
        $expectedAfter = 2992 - $expectedWarmup - 1200 - 600
        Assert-R23D3RapierExact (
            [string]$receipt.schema_version -ceq
                "sporespore_qsdk_r23d3_rapier_worker_preflight_v1" -and
            [string]$receipt.campaign_id -ceq $campaignId -and
            [string]$receipt.gate_id -ceq $gateId -and
            [string]$receipt.engine_id -ceq "rapier_parry" -and
            [string]$receipt.stage_id -ceq "three_engine_confirmation" -and
            [string]$receipt.onset_id -ceq [string]$onset.onset_id -and
            [int]$receipt.turn_start_semantic_step -eq $expectedWarmup -and
            [string]$receipt.arm_id -ceq [string]$armId -and
            [Math]::Abs(
                [double]$receipt.turn_heading_offset_rad - $expectedOffset
            ) -le 1.0e-15 -and
            [int]$receipt.segment_counts.reference_warmup -eq $expectedWarmup -and
            [int]$receipt.segment_counts.commanded_turn -eq 1200 -and
            [int]$receipt.segment_counts.reference_recovery -eq 600 -and
            [int]$receipt.segment_counts.after_declared_schedule -eq $expectedAfter -and
            [int]$receipt.fixed_controller_horizon_step_count -eq 2992 -and
            [bool]$receipt.fixed_horizon_configuration_proved_before_fixture_insertion -and
            [bool]$receipt.trace_retained_before_terminal_entry_required -and
            [int]$receipt.world_attempt_count -eq 0 -and
            [int]$receipt.world_build_count -eq 0 -and
            -not [bool]$receipt.physical_execution_authorized -and
            -not [bool]$receipt.physical_acceptance_authority
        ) "QSDK-R23D3 Rapier receipt changed: $($execution.label)"
        $fixedHorizonProofs += 1
    }
}
Assert-R23D3RapierExact ($fixedHorizonProofs -eq 12) (
    "QSDK-R23D3 Rapier fixed-horizon proof count changed"
)

$stageBypass = Invoke-R23D3RapierWorker `
    -Label "stage-a-bypass" `
    -Arguments @(
        "--stage", "mujoco_onset_screen", "--onset", "onset_600",
        "--arm", "positive_heading", "--preflight-only"
    )
Assert-R23D3RapierExact (
    -not [bool]$stageBypass.timed_out -and
    [int]$stageBypass.exit_code -ne 0
) "QSDK-R23D3 Rapier accepted a Stage-A identity"
[void](Get-R23D3RapierMarker $stageBypass $failurePrefix)

$physicalBypass = Invoke-R23D3RapierWorker `
    -Label "physical-bypass" `
    -Arguments @(
        "--stage", "three_engine_confirmation", "--onset", "onset_600",
        "--arm", "reference_zero", "--source-commit", ("0" * 40)
    )
Assert-R23D3RapierExact (
    -not [bool]$physicalBypass.timed_out -and
    [int]$physicalBypass.exit_code -ne 0
) "QSDK-R23D3 direct Rapier physical bypass did not fail closed"
$bypass = Get-R23D3RapierMarker $physicalBypass $failurePrefix
$cellMarkers = @(([string]$physicalBypass.stdout -split "`r?`n") | Where-Object {
    $_.StartsWith($cellPrefix, [StringComparison]::Ordinal)
})
Assert-R23D3RapierExact (
    [string]$bypass.schema_version -ceq
        "sporespore_qsdk_r23d3_worker_failure_v1" -and
    [string]$bypass.failure_code -ceq
        "QSDK_R23D3_RAP_CLOSED" -and
    [string]$bypass.failure_stage -ceq "before_world" -and
    [int]$bypass.world_attempt_count -eq 0 -and
    [int]$bypass.world_build_count -eq 0 -and
    $null -eq $bypass.trace_artifact -and
    $cellMarkers.Count -eq 0 -and
    -not [bool]$bypass.claims.physical_acceptance_authority
) "QSDK-R23D3 Rapier physical-bypass receipt changed"

Write-Host (
    "QSDK_R23D3_RAPIER_WORKER_PASS identities=12 " +
    "fixed_horizon_proofs=$fixedHorizonProofs inherited_canaries=84 " +
    "inherited_predicate_controls=420 negative_controls=2 worlds=0 " +
    "physical_authority=False"
)
