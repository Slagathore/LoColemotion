#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$sdkRoot = Join-Path $repoRoot "sdk"
$contractPath = Join-Path $sdkRoot "godot_jolt_phase_timing_gjpt2_contract.json"
$closurePath = Join-Path $sdkRoot "godot_jolt_phase_timing_gjpt1_closure.json"
$sourceToolPath = Join-Path $sdkRoot "godot_jolt_phase_timing_source.ps1"
$supervisorPath = Join-Path $sdkRoot "run_godot_jolt_phase_timing_gjpt2.ps1"
$workerPath = Join-Path $repoRoot "tests\probe_godot_jolt_phase_timing_gjpt2.gd"
$baseRunnerPath = Join-Path $repoRoot "scripts\lab\gait\physical_wave_gait_quadruped.gd"
$godot = (
    "C:\Users\Cole\CodeStuff\Misc\Godot\" +
    "Godot_v4.7-stable_mono_win64_console.exe"
)

function Assert-Gjpt2Audit {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-Gjpt2AuditHash {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).
        Hash.ToLowerInvariant()
}

foreach ($path in @(
    $contractPath, $closurePath, $sourceToolPath, $supervisorPath,
    $workerPath, $baseRunnerPath, $godot
)) {
    Assert-Gjpt2Audit (Test-Path -LiteralPath $path -PathType Leaf) (
        "GJPT2 required audit input is missing: $path"
    )
}
Assert-Gjpt2Audit (
    (git -C $repoRoot rev-parse --show-toplevel).Replace("/", "\") -ceq $repoRoot -and
    (git -C $repoRoot remote get-url origin) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "GJPT2 repository identity mismatch"

$contract = Get-Content -Raw -LiteralPath $contractPath |
    ConvertFrom-Json -AsHashtable -Depth 64
$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 64
Assert-Gjpt2Audit (
    [string]$contract.contract_id -ceq "GJPT2" -and
    [string]$contract.status -ceq
        "prospective_one_cell_development_measurement_successor" -and
    [string]$contract.predecessor.contract_id -ceq "GJPT1" -and
    [string]$contract.predecessor.status -ceq "invalid_or_incomplete_first_attempt" -and
    -not [bool]$contract.predecessor.same_identity_rerun -and
    [string]$closure.contract_id -ceq "GJPT1" -and
    [string]$closure.status -ceq "invalid_or_incomplete_first_attempt" -and
    [bool]$closure.attempt.physical_identity_consumed -and
    -not [bool]$closure.attempt.same_identity_rerun_allowed -and
    [int]$closure.attempt.confirmed_physical_world_count -eq -1 -and
    [bool]$closure.root_cause.predictable_before_world -and
    [bool]$closure.successor_requirements.
        synthetic_projection_canary_required_in_complete_zero_world_gate
) "GJPT2 predecessor closure or successor identity changed"
Assert-Gjpt2Audit (
    "sha256:$(Get-Gjpt2AuditHash $closurePath)" -ceq
        [string]$contract.predecessor.closure_raw_sha256
) "GJPT2 predecessor closure digest changed"

foreach ($binding in @($contract.source_bindings)) {
    $path = Join-Path $repoRoot ([string]$binding.path)
    Assert-Gjpt2Audit (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        ("sha256:$(Get-Gjpt2AuditHash $path)" -ceq [string]$binding.raw_sha256)
    ) "GJPT2 source binding changed: $([string]$binding.path)"
}
. $sourceToolPath
$generated = New-Gjpt1InstrumentedRunner -RepoRoot $repoRoot
Assert-Gjpt2Audit (
    [string]$generated.generated_raw_sha256 -ceq
        [string]$contract.instrumentation.generated_runner.raw_sha256 -and
    [long]$generated.generated_byte_length -eq
        [long]$contract.instrumentation.generated_runner.byte_length -and
    "sha256:$(Get-Gjpt2AuditHash $baseRunnerPath)" -ceq
        [string]$contract.instrumentation.base_runner.raw_sha256
) "GJPT2 generated runner or frozen base runner changed"

$workerText = Get-Content -Raw -LiteralPath $workerPath
$supervisorText = Get-Content -Raw -LiteralPath $supervisorPath
foreach ($required in @(
    "GJPT2_PROJECTION_KEYS",
    "_gjpt2_projection_canary",
    "projection_calls_frozen_acceptance_composer",
    "_compose_gjpt2_development_projection",
    "output.flush()",
    "world_outcome_observed_but_not_interpreted"
)) {
    Assert-Gjpt2Audit ($workerText.Contains($required)) (
        "GJPT2 worker obligation is missing: $required"
    )
}
foreach ($forbidden in @(
    "_bw32n_successor_receipt(",
    "Bw32Common.compose_dynamic_final_receipt(",
    "Bw32Common.compose_final_receipt("
)) {
    Assert-Gjpt2Audit (-not $workerText.Contains($forbidden)) (
        "GJPT2 worker calls a frozen acceptance composer: $forbidden"
    )
}
foreach ($required in @(
    "clean pushed live source",
    "physical identity already has a retained authorization",
    "Publish-SporeSporeContentAddressedArtifact",
    "projection_canary_passed",
    "same_identity_rerun_allowed = `$false",
    "confirmed_physical_world_count = -1",
    "estimated_recovered_stateless_to_persistent_total_cell_speedup",
    "post_optimization_native_share"
)) {
    Assert-Gjpt2Audit ($supervisorText.Contains($required)) (
        "GJPT2 supervisor obligation is missing: $required"
    )
}

$preflightOutput = @(& pwsh -NoLogo -NoProfile -File $supervisorPath -PreflightOnly 2>&1)
Assert-Gjpt2Audit (
    $LASTEXITCODE -eq 0 -and
    ($preflightOutput -join "`n").Contains(
        "GJPT2_PHASE_TIMING_PREFLIGHT_PASS worlds=0"
    ) -and
    ($preflightOutput -join "`n").Contains("projection_canary=True")
) "GJPT2 complete zero-world preflight failed: $($preflightOutput -join ' ')"

$directOutput = @(
    & $godot --headless --path $repoRoot --script `
        "res://tests/probe_godot_jolt_phase_timing_gjpt2.gd" -- physical 2>&1
)
Assert-Gjpt2Audit (
    $LASTEXITCODE -ne 0 -and
    ($directOutput -join "`n").Contains(
        "GJPT2 physical execution requires supervisor authorization"
    ) -and
    -not ($directOutput -join "`n").Contains("wave_tick=")
) "GJPT2 direct physical negative canary did not fail before world construction"

Write-Host (
    "GJPT2_PHASE_TIMING_CONTRACT_PASS worlds=0 " +
    "predecessor=GJPT1-invalid projection_canary=True " +
    "frozen_acceptance_composer=False direct_physical_rejected=True " +
    "physical_authority=False contract_sha256=$(Get-Gjpt2AuditHash $contractPath)"
)
