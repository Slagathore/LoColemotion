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
$freezePath = Join-Path $repoRoot "sdk\balanced_wave_bw34y_rough_yaw_rescue_freeze.json"
$bindingPath = Join-Path $repoRoot "sdk\balanced_wave_bw34y_native_candidate_bindings.json"
$candidatePath = Join-Path $repoRoot "sdk\balanced_wave_bw34y_rough_yaw_rescue_candidates.json"
$manifestPath = Join-Path $repoRoot "sdk\balanced_wave_bw34y_rough_yaw_rescue_manifest.json"
$workerPath = Join-Path $repoRoot "tests\test_sdk_balanced_wave_bw34y_rough_yaw_rescue_worker.gd"
$commonPath = Join-Path $repoRoot "scripts\lab\gait\sdk_bw34y_worker_common.gd"
$evaluatorPath = Join-Path $repoRoot "sdk\balanced_wave_bw34y_rough_yaw_rescue_gate.ps1"
$supervisorPath = Join-Path $repoRoot "sdk\run_balanced_wave_bw34y_rough_yaw_rescue.ps1"
$zeroWorldPath = Join-Path $repoRoot "sdk\run_balanced_wave_bw34y_rough_yaw_rescue_zero_world_gate.ps1"
$declarationAuditPath = Join-Path $repoRoot "tests\test_bw34y_rough_yaw_rescue_declaration.ps1"

function Assert-Bw34yFreezeExact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Read-Bw34yFreezeJson {
    param([Parameter(Mandatory)][string]$Path)
    return Get-Content -Raw -LiteralPath $Path |
        ConvertFrom-Json -AsHashtable -Depth 64
}

function Get-Bw34yFreezeSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-Bw34yUtf8Sha256 {
    param([Parameter(Mandatory)][string]$Text)
    $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
    return "sha256:" + [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($bytes)
    ).ToLowerInvariant()
}

Assert-Bw34yFreezeExact (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace('\', '/') -ceq
        ([System.IO.Path]::GetFullPath($repoRoot).Replace('\', '/'))
) "BW34Y freeze audit is not in the authoritative checkout"
Assert-Bw34yFreezeExact (
    (git -C $repoRoot remote get-url origin).Trim() -ceq $expectedRemote
) "BW34Y origin remote changed"

foreach ($path in @(
    $freezePath, $bindingPath, $candidatePath, $manifestPath, $workerPath,
    $commonPath, $evaluatorPath, $supervisorPath, $zeroWorldPath,
    $declarationAuditPath
)) {
    Assert-Bw34yFreezeExact (Test-Path -LiteralPath $path -PathType Leaf) (
        "BW34Y stage-one source missing: $path"
    )
}

$freeze = Read-Bw34yFreezeJson $freezePath
Assert-Bw34yFreezeExact (
    [string]$freeze.schema_version -ceq
        "sporespore_balanced_wave_bw34y_rough_yaw_rescue_freeze_v1" -and
    [string]$freeze.status -ceq "frozen_before_first_bw34y_physical_world" -and
    [string]$freeze.campaign_id -ceq "BW34Y-BW33N-ROUGH-YAW-RESCUE-DEVELOPMENT" -and
    [string]$freeze.gate_id -ceq "BW34Y" -and
    [int]$freeze.world_build_count -eq 0 -and
    -not [bool]$freeze.physical_execution_authorized_by_freeze -and
    -not [bool]$freeze.selection_authority -and
    -not [bool]$freeze.rough_terrain_acceptance -and
    -not [bool]$freeze.release_authorized -and
    -not [bool]$freeze.physical_acceptance_authority
) "BW34Y stage-one freeze identity or claim boundary changed"
Assert-Bw34yFreezeExact (
    [int]$freeze.physical_matrix.expected_world_count -eq 3 -and
    [int]$freeze.physical_matrix.candidate_count -eq 1 -and
    [int]$freeze.physical_matrix.seed_count -eq 3 -and
    [int]$freeze.physical_matrix.exact_candidate_authority_observation_count -eq 3232 -and
    [int]$freeze.physical_matrix.expected_native_motor_write_count_per_cell -eq 25856 -and
    [int]$freeze.physical_matrix.branch_surface_count -eq 0
) "BW34Y physical matrix freeze changed"

$sourceBindings = [System.Collections.IDictionary]$freeze.source_bindings
Assert-Bw34yFreezeExact ($sourceBindings.Count -ge 14) (
    "BW34Y freeze has an incomplete source-binding inventory"
)
foreach ($entry in $sourceBindings.GetEnumerator()) {
    $path = Join-Path $repoRoot ([string]$entry.Value.path -replace '/', '\')
    Assert-Bw34yFreezeExact (Test-Path -LiteralPath $path -PathType Leaf) (
        "BW34Y frozen source missing: $path"
    )
    Assert-Bw34yFreezeExact (
        (Get-Bw34yFreezeSha256 $path) -ceq [string]$entry.Value.raw_sha256
    ) "BW34Y frozen source digest changed: $path"
}

$bindings = Read-Bw34yFreezeJson $bindingPath
$candidateOrder = @("BW34Y-A")
$expectedDigests = @{
    "BW34Y-A" = "sha256:031d9fdb41626c7b2d62ec889b25089ee731d6587f16502c05b7d2284e1332c1"
}
Assert-Bw34yFreezeExact (
    [string]$bindings.binding_algorithm -ceq "sha256_utf8_exact_binding_string_v1" -and
    @($bindings.candidate_bindings).Count -eq 1 -and
    [int]$bindings.branch_surface_count -eq 0 -and
    [int]$bindings.world_build_count -eq 0
) "BW34Y native binding contract changed"
foreach ($candidateId in $candidateOrder) {
    $matches = @($bindings.candidate_bindings | Where-Object {
        [string]$_.candidate_id -ceq $candidateId
    })
    Assert-Bw34yFreezeExact ($matches.Count -eq 1) (
        "BW34Y native binding missing or duplicated: $candidateId"
    )
    Assert-Bw34yFreezeExact (
        (Get-Bw34yUtf8Sha256 ([string]$matches[0].exact_binding_string)) -ceq
            $expectedDigests[$candidateId] -and
        [string]$matches[0].candidate_composition_digest -ceq
            $expectedDigests[$candidateId]
    ) "BW34Y native candidate composition digest changed: $candidateId"
}

$workerText = Get-Content -Raw -LiteralPath $workerPath
$commonText = Get-Content -Raw -LiteralPath $commonPath
$evaluatorText = Get-Content -Raw -LiteralPath $evaluatorPath
$supervisorText = Get-Content -Raw -LiteralPath $supervisorPath
$zeroWorldText = Get-Content -Raw -LiteralPath $zeroWorldPath
Assert-Bw34yFreezeExact (
    $workerText.Contains('extends "res://tests/test_sdk_balanced_wave_bw32n_successor_worker.gd"') -and
    $workerText.Contains('var summary := await _run_cell(0, int(cell["campaign_seed"]), false)') -and
    $workerText.Contains('Bw34Common.compose_dynamic_final_receipt(cell, summary)') -and
    $workerText.Contains('func _controller_policy_id() -> String:') -and
    $workerText.Contains('func _controller_policy_digest() -> String:') -and
    $workerText.Contains('func _candidate_global_scale() -> float:') -and
    $workerText.Contains('controller_profile.get("yaw_error_stride_gain_per_rad"')
) "BW34Y worker no longer binds the actual inherited world path exactly"
Assert-Bw34yFreezeExact (
    $commonText.Contains('This is the sole physical receipt constructor') -and
    $commonText.Contains('summary.get("sdk_authority_start_result", {})') -and
    $commonText.Contains('summary.get("sdk_authority_summary", {})') -and
    $commonText.Contains('summary.get("sdk_material_profile_sha256", "")') -and
    $commonText.Contains('fixture_spec.get("contact_material", {})') -and
    $commonText.Contains('candidate_authority_observation_count", -1)) == 3232') -and
    $commonText.Contains('native_actuation_application_count", -1))') -and
    $commonText.Contains('walking_receipt_structurally_complete') -and
    $commonText.Contains('_content_addressed_inputs_exact')
) "BW34Y actual dynamic parent-summary composer or authorization path changed"
Assert-Bw34yFreezeExact (
    $evaluatorText.Contains('Invoke-Bw34yRoughYawRescueEvaluation') -and
    $evaluatorText.Contains('prospective_selector_order = @("BW34Y-A")') -and
    $evaluatorText.Contains('$passingSeeds.Count -eq 3') -and
    $evaluatorText.Contains('$preservesRetainedPassingSeed') -and
    $evaluatorText.Contains('valid_walking_negative') -and
    $evaluatorText.Contains('selected_candidate_id')
) "BW34Y cold evaluator or prospective selector changed"
Assert-Bw34yFreezeExact (
    $supervisorText.Contains('Enter-SporeSporeLocomotionOperationLock') -and
    $supervisorText.Contains('already has a retained attempt and may not rerun') -and
    $supervisorText.Contains('Publish-Bw34yInputSet') -and
    $supervisorText.Contains('Publish-SporeSporeContentAddressedArtifact') -and
    $supervisorText.Contains('-InputPath ([string]$inputCas.payload_path)') -and
    $supervisorText.Contains('HEAD equal to live GitHub main')
) "BW34Y one-shot, CAS, cold-evaluator, or source-exact supervisor boundary changed"
foreach ($control in @(
    'candidate_identity', 'runtime_profile', 'controller_policy', 'yaw_gain',
    'global_scale', 'seed_identity', 'rough_challenge', 'rough_shape_count',
    'material_profile', 'authority_horizon', 'native_application',
    'receipt_schema', 'missing_walking_receipt'
)) {
    Assert-Bw34yFreezeExact ($zeroWorldText.Contains($control)) (
        "BW34Y zero-world negative control missing: $control"
    )
}
Assert-Bw34yFreezeExact (
    $zeroWorldText.Contains('selected_candidate_id -ceq "BW34Y-A"') -and
    $zeroWorldText.Contains('selected_candidate_id -ceq "NONE"') -and
    $zeroWorldText.Contains('retained_comparator_passing_seed_21001_preserved') -and
    $zeroWorldText.Contains('malformed physical CAS attempt was accepted') -and
    $zeroWorldText.Contains('authorization-preflight') -and
    $zeroWorldText.Contains('actual_world_build_count -eq 0')
) "BW34Y selector canaries or authorization preflight changed"

& pwsh -NoLogo -NoProfile -File $declarationAuditPath
Assert-Bw34yFreezeExact ($LASTEXITCODE -eq 0) "BW34Y declaration audit failed"
if (-not $SkipSupervisorPreflight) {
    & pwsh -NoLogo -NoProfile -File $supervisorPath -PreflightOnly -Godot $Godot
    Assert-Bw34yFreezeExact ($LASTEXITCODE -eq 0) "BW34Y supervisor preflight failed"
}

Write-Host (
    "BW34Y_FREEZE_PASS candidates=1 cells=3 native_bindings=1 " +
    "source_bindings=$($sourceBindings.Count) authority_horizon=3232 " +
    "native_writes=25856 negative_controls=13 selector_canaries=3 " +
    "worlds=0 physical_authority=False"
)
