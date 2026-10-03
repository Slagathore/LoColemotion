#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$contractPath = Join-Path $repoRoot "sdk\godot_jolt_phase_timing_contract.json"
$sourceToolPath = Join-Path $repoRoot "sdk\godot_jolt_phase_timing_source.ps1"
$runnerPath = Join-Path $repoRoot "sdk\run_godot_jolt_phase_timing.ps1"
$workerPath = Join-Path $repoRoot "tests\probe_godot_jolt_phase_timing.gd"
$baseRunnerPath = Join-Path $repoRoot (
    "scripts\lab\gait\physical_wave_gait_quadruped.gd"
)
$godot = (
    "C:\Users\Cole\CodeStuff\Misc\Godot\" +
    "Godot_v4.7-stable_mono_win64_console.exe"
)

function Assert-Exact([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Get-RawSha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).
        Hash.ToLowerInvariant()
}

Assert-Exact (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "GJPT1 repository identity mismatch"
foreach ($path in @(
    $contractPath, $sourceToolPath, $runnerPath, $workerPath, $baseRunnerPath, $godot
)) {
    Assert-Exact (Test-Path -LiteralPath $path -PathType Leaf) (
        "GJPT1 required source or runtime is missing: $path"
    )
}
$contract = Get-Content -Raw -LiteralPath $contractPath |
    ConvertFrom-Json -AsHashtable -Depth 64
Assert-Exact (
    [string]$contract.schema_version -ceq
        "sporespore_godot_jolt_phase_timing_contract_v1" -and
    [string]$contract.contract_id -ceq "GJPT1" -and
    [string]$contract.scientific_class -ceq
        "non_acceptance_performance_phase_characterization" -and
    [string]$contract.cell.cell_id -ceq "gjpt1_baseline_s21001_bw32n_b" -and
    [string]$contract.cell.source_cell_template_id -ceq
        "baseline_s21001_bw32n_b" -and
    [bool]$contract.cell.historical_campaign_identity_is_not_reopened -and
    [int]$contract.cell.expected_pre_authority_world_tick_count -eq 240 -and
    [int]$contract.cell.candidate_authority_observation_count -eq 3232 -and
    [int]$contract.cell.expected_instrumented_tick_count -eq 3472 -and
    [int]$contract.cell.expected_world_count -eq 1 -and
    [bool]$contract.execution.first_attempt_is_final_for_this_identity -and
    [bool]$contract.execution.retry_or_replacement_forbidden -and
    [int]$contract.execution.wall_clock_timeout_seconds -eq 360 -and
    -not [bool]$contract.claims.walking_claim_authorized -and
    -not [bool]$contract.claims.physical_acceptance_authority
) "GJPT1 contract identity or claim boundary changed"
Assert-Exact (
    @($contract.instrumentation.phase_fields).Count -eq 8 -and
    @($contract.instrumentation.phase_fields) -ccontains
        "native_boundary_usec" -and
    @($contract.instrumentation.phase_fields) -ccontains
        "physics_frame_wait_usec" -and
    @($contract.instrumentation.phase_fields) -ccontains
        "post_physics_observation_evidence_usec" -and
    @($contract.instrumentation.phase_fields) -ccontains
        "evidence_file_write_usec"
) "GJPT1 phase partition changed"
foreach ($binding in @($contract.source_bindings)) {
    $path = Join-Path $repoRoot ([string]$binding.path)
    Assert-Exact (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        "sha256:$(Get-RawSha256 $path)" -ceq [string]$binding.raw_sha256
    ) "GJPT1 source binding changed: $([string]$binding.path)"
}
foreach ($binding in @(
    $contract.instrumentation.base_runner,
    $contract.instrumentation.transformer,
    $contract.instrumentation.worker
)) {
    $path = Join-Path $repoRoot ([string]$binding.path)
    Assert-Exact (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        "sha256:$(Get-RawSha256 $path)" -ceq [string]$binding.raw_sha256
    ) "GJPT1 instrumentation binding changed: $([string]$binding.path)"
}
$baseSource = Get-Content -Raw -LiteralPath $baseRunnerPath
Assert-Exact (
    -not $baseSource.Contains("gjpt1_phase_timing") -and
    -not $baseSource.Contains("_gjpt1_native_boundary_usec")
) "GJPT1 instrumentation leaked into the frozen base runner"
. $sourceToolPath
$generated = New-Gjpt1InstrumentedRunner -RepoRoot $repoRoot
Assert-Exact (
    [string]$generated.generated_raw_sha256 -ceq
        [string]$contract.instrumentation.generated_runner.raw_sha256 -and
    [long]$generated.generated_byte_length -eq
        [long]$contract.instrumentation.generated_runner.byte_length
) "GJPT1 generated runner bytes changed"
$generatedSource = Get-Content -Raw -LiteralPath ([string]$generated.generated_path)
foreach ($required in @(
    "class_name LabPhysicalWaveGaitQuadrupedGjpt1PhaseTiming",
    "_gjpt1_native_boundary_usec",
    "_gjpt1_physics_frame_wait_usec",
    "post_physics_observation_evidence_usec",
    "setup_summary_cleanup_residual_usec"
)) {
    Assert-Exact ($generatedSource.Contains($required)) (
        "GJPT1 generated runner is missing instrumentation: $required"
    )
}
$directOutput = @(& $godot --headless --path $repoRoot --script `
    "res://tests/probe_godot_jolt_phase_timing.gd" -- physical 2>&1)
$directExit = $LASTEXITCODE
Assert-Exact (
    $directExit -ne 0 -and
    ($directOutput -join "`n").Contains(
        "GJPT1 physical execution requires supervisor authorization"
    ) -and
    -not ($directOutput -join "`n").Contains("wave_tick=")
) "GJPT1 direct physical execution was not rejected before the world"
$runnerSource = Get-Content -Raw -LiteralPath $runnerPath
foreach ($required in @(
    "clean pushed live source",
    "Enter-SporeSporeLocomotionOperationLock",
    "Publish-SporeSporeContentAddressedArtifact",
    "first physical identity already has a retained authorization",
    "same_identity_rerun_allowed = `$false",
    "GJPT1_PROGRESS",
    "instrumented_denominator_usec"
)) {
    Assert-Exact ($runnerSource.Contains($required)) (
        "GJPT1 supervisor lost a fail-closed obligation: $required"
    )
}
& pwsh -NoLogo -NoProfile -File $runnerPath -PreflightOnly
Assert-Exact ($LASTEXITCODE -eq 0) "GJPT1 complete zero-world runner gate failed"

Write-Host (
    "GJPT1_PHASE_TIMING_CONTRACT_PASS worlds=0 generated_sha256=" +
    "$([string]$generated.generated_raw_sha256) direct_physical_rejected=True " +
    "frozen_runner_unchanged=True physical_authority=False " +
    "contract_sha256=$(Get-RawSha256 $contractPath)"
)
