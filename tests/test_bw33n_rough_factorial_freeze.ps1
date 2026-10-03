#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [switch]$SkipSupervisorPreflight
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$freezePath = Join-Path $repoRoot "sdk\balanced_wave_bw33n_rough_factorial_freeze.json"
$bindingPath = Join-Path $repoRoot "sdk\balanced_wave_bw33n_native_candidate_bindings.json"
$candidatePath = Join-Path $repoRoot "sdk\balanced_wave_bw33n_rough_factorial_candidates.json"
$manifestPath = Join-Path $repoRoot "sdk\balanced_wave_bw33n_rough_factorial_manifest.json"
$workerPath = Join-Path $repoRoot "tests\test_sdk_balanced_wave_bw33n_rough_factorial_worker.gd"
$commonPath = Join-Path $repoRoot "scripts\lab\gait\sdk_bw33n_worker_common.gd"
$evaluatorPath = Join-Path $repoRoot "sdk\balanced_wave_bw33n_rough_factorial_gate.ps1"
$supervisorPath = Join-Path $repoRoot "sdk\run_balanced_wave_bw33n_rough_factorial.ps1"
$zeroWorldPath = Join-Path $repoRoot "sdk\run_balanced_wave_bw33n_rough_factorial_zero_world_gate.ps1"
$declarationAuditPath = Join-Path $repoRoot "tests\test_bw33n_rough_factorial_declaration.ps1"

function Assert-Bw33nFreezeExact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Read-Bw33nFreezeJson {
    param([Parameter(Mandatory)][string]$Path)
    return Get-Content -Raw -LiteralPath $Path |
        ConvertFrom-Json -AsHashtable -Depth 64
}

function Get-Bw33nFreezeSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-Bw33nUtf8Sha256 {
    param([Parameter(Mandatory)][string]$Text)
    $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
    return "sha256:" + [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($bytes)
    ).ToLowerInvariant()
}

Assert-Bw33nFreezeExact (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace('\', '/') -ceq
        ([System.IO.Path]::GetFullPath($repoRoot).Replace('\', '/'))
) "BW33N freeze audit is not in the authoritative checkout"
Assert-Bw33nFreezeExact (
    (git -C $repoRoot remote get-url origin).Trim() -ceq $expectedRemote
) "BW33N origin remote changed"

foreach ($path in @(
    $freezePath, $bindingPath, $candidatePath, $manifestPath, $workerPath,
    $commonPath, $evaluatorPath, $supervisorPath, $zeroWorldPath,
    $declarationAuditPath
)) {
    Assert-Bw33nFreezeExact (Test-Path -LiteralPath $path -PathType Leaf) (
        "BW33N stage-one source missing: $path"
    )
}

$freeze = Read-Bw33nFreezeJson $freezePath
Assert-Bw33nFreezeExact (
    [string]$freeze.schema_version -ceq
        "sporespore_balanced_wave_bw33n_rough_factorial_freeze_v1" -and
    [string]$freeze.status -ceq "frozen_before_first_bw33n_physical_world" -and
    [string]$freeze.campaign_id -ceq "BW33N-BW32N-ROUGH-FACTORIAL-DEVELOPMENT" -and
    [string]$freeze.gate_id -ceq "BW33N" -and
    [int]$freeze.world_build_count -eq 0 -and
    -not [bool]$freeze.physical_execution_authorized_by_freeze -and
    -not [bool]$freeze.selection_authority -and
    -not [bool]$freeze.rough_terrain_acceptance -and
    -not [bool]$freeze.release_authorized -and
    -not [bool]$freeze.physical_acceptance_authority
) "BW33N stage-one freeze identity or claim boundary changed"
Assert-Bw33nFreezeExact (
    [int]$freeze.physical_matrix.expected_world_count -eq 12 -and
    [int]$freeze.physical_matrix.candidate_count -eq 4 -and
    [int]$freeze.physical_matrix.seed_count -eq 3 -and
    [int]$freeze.physical_matrix.exact_candidate_authority_observation_count -eq 3232 -and
    [int]$freeze.physical_matrix.expected_native_motor_write_count_per_cell -eq 25856 -and
    [int]$freeze.physical_matrix.branch_surface_count -eq 0
) "BW33N physical matrix freeze changed"

$sourceBindings = [System.Collections.IDictionary]$freeze.source_bindings
Assert-Bw33nFreezeExact ($sourceBindings.Count -ge 14) (
    "BW33N freeze has an incomplete source-binding inventory"
)
foreach ($entry in $sourceBindings.GetEnumerator()) {
    $path = Join-Path $repoRoot ([string]$entry.Value.path -replace '/', '\')
    Assert-Bw33nFreezeExact (Test-Path -LiteralPath $path -PathType Leaf) (
        "BW33N frozen source missing: $path"
    )
    Assert-Bw33nFreezeExact (
        (Get-Bw33nFreezeSha256 $path) -ceq [string]$entry.Value.raw_sha256
    ) "BW33N frozen source digest changed: $path"
}

$bindings = Read-Bw33nFreezeJson $bindingPath
$candidateOrder = @("BW33N-A", "BW33N-B", "BW33N-C", "BW33N-D")
$expectedDigests = @{
    "BW33N-A" = "sha256:4d10129d115e05b90d016f17852550f01a2ae1f55ef0b6c4b76e7b3f502104d4"
    "BW33N-B" = "sha256:63256c50af72be8ca9f0ce8b8a5e0ccaddea65e0c57c47ac8a7a5653a856b1fb"
    "BW33N-C" = "sha256:0598d4c57ae37fab2beb9268c2f90412e1f04a7db58d76c1bfe8e228074bcdb8"
    "BW33N-D" = "sha256:f48dae75095a7c2b2e192203a4ce12bfd88b56a1d716977ca04d94ffb7b7ff59"
}
Assert-Bw33nFreezeExact (
    [string]$bindings.binding_algorithm -ceq "sha256_utf8_exact_binding_string_v1" -and
    @($bindings.candidate_bindings).Count -eq 4 -and
    [int]$bindings.branch_surface_count -eq 0 -and
    [int]$bindings.world_build_count -eq 0
) "BW33N native binding contract changed"
foreach ($candidateId in $candidateOrder) {
    $matches = @($bindings.candidate_bindings | Where-Object {
        [string]$_.candidate_id -ceq $candidateId
    })
    Assert-Bw33nFreezeExact ($matches.Count -eq 1) (
        "BW33N native binding missing or duplicated: $candidateId"
    )
    Assert-Bw33nFreezeExact (
        (Get-Bw33nUtf8Sha256 ([string]$matches[0].exact_binding_string)) -ceq
            $expectedDigests[$candidateId] -and
        [string]$matches[0].candidate_composition_digest -ceq
            $expectedDigests[$candidateId]
    ) "BW33N native candidate composition digest changed: $candidateId"
}

$workerText = Get-Content -Raw -LiteralPath $workerPath
$commonText = Get-Content -Raw -LiteralPath $commonPath
$evaluatorText = Get-Content -Raw -LiteralPath $evaluatorPath
$supervisorText = Get-Content -Raw -LiteralPath $supervisorPath
$zeroWorldText = Get-Content -Raw -LiteralPath $zeroWorldPath
Assert-Bw33nFreezeExact (
    $workerText.Contains('extends "res://tests/test_sdk_balanced_wave_bw32n_successor_worker.gd"') -and
    $workerText.Contains('var summary := await _run_cell(0, int(cell["campaign_seed"]), false)') -and
    $workerText.Contains('Bw33Common.compose_dynamic_final_receipt(cell, summary)') -and
    $workerText.Contains('func _controller_policy_id() -> String:') -and
    $workerText.Contains('func _controller_policy_digest() -> String:') -and
    $workerText.Contains('func _candidate_global_scale() -> float:') -and
    $workerText.Contains('controller_profile.get("yaw_error_stride_gain_per_rad"')
) "BW33N worker no longer binds the actual inherited world path exactly"
Assert-Bw33nFreezeExact (
    $commonText.Contains('This is the sole physical receipt constructor') -and
    $commonText.Contains('summary.get("sdk_authority_start_result", {})') -and
    $commonText.Contains('summary.get("sdk_authority_summary", {})') -and
    $commonText.Contains('summary.get("sdk_material_profile_sha256", "")') -and
    $commonText.Contains('fixture_spec.get("contact_material", {})') -and
    $commonText.Contains('candidate_authority_observation_count", -1)) == 3232') -and
    $commonText.Contains('native_actuation_application_count", -1))') -and
    $commonText.Contains('walking_receipt_structurally_complete') -and
    $commonText.Contains('_content_addressed_inputs_exact')
) "BW33N actual dynamic parent-summary composer or authorization path changed"
Assert-Bw33nFreezeExact (
    $evaluatorText.Contains('Invoke-Bw33nRoughFactorialEvaluation') -and
    $evaluatorText.Contains('@("BW33N-B", "BW33N-C", "BW33N-D")') -and
    $evaluatorText.Contains('valid_walking_negative') -and
    $evaluatorText.Contains('selected_candidate_id')
) "BW33N cold evaluator or prospective selector changed"
Assert-Bw33nFreezeExact (
    $supervisorText.Contains('Enter-SporeSporeLocomotionOperationLock') -and
    $supervisorText.Contains('already has a retained attempt and may not rerun') -and
    $supervisorText.Contains('Publish-Bw33nInputSet') -and
    $supervisorText.Contains('Publish-SporeSporeContentAddressedArtifact') -and
    $supervisorText.Contains('-InputPath ([string]$inputCas.payload_path)') -and
    $supervisorText.Contains('HEAD equal to live GitHub main')
) "BW33N one-shot, CAS, cold-evaluator, or source-exact supervisor boundary changed"
foreach ($control in @(
    'candidate_identity', 'runtime_profile', 'global_scale', 'seed_identity',
    'rough_challenge', 'rough_shape_count', 'authority_horizon',
    'native_application', 'receipt_schema'
)) {
    Assert-Bw33nFreezeExact ($zeroWorldText.Contains($control)) (
        "BW33N zero-world negative control missing: $control"
    )
}
Assert-Bw33nFreezeExact (
    $zeroWorldText.Contains('selected_candidate_id -ceq "BW33N-D"') -and
    $zeroWorldText.Contains('selected_candidate_id -ceq "NONE"') -and
    $zeroWorldText.Contains('malformed physical CAS attempt was accepted') -and
    $zeroWorldText.Contains('authorization-preflight') -and
    $zeroWorldText.Contains('actual_world_build_count -eq 0')
) "BW33N selector canaries or authorization preflight changed"

& pwsh -NoLogo -NoProfile -File $declarationAuditPath
Assert-Bw33nFreezeExact ($LASTEXITCODE -eq 0) "BW33N declaration audit failed"
if (-not $SkipSupervisorPreflight) {
    & pwsh -NoLogo -NoProfile -File $supervisorPath -PreflightOnly -Godot $Godot
    Assert-Bw33nFreezeExact ($LASTEXITCODE -eq 0) "BW33N supervisor preflight failed"
}

Write-Host (
    "BW33N_FREEZE_PASS candidates=4 cells=12 native_bindings=4 " +
    "source_bindings=$($sourceBindings.Count) authority_horizon=3232 " +
    "native_writes=25856 negative_controls=9 selector_canaries=3 " +
    "worlds=0 physical_authority=False"
)
