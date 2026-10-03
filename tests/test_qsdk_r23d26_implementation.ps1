#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$sdkRoot = Join-Path $repoRoot "sdk"
$preregistrationPath = Join-Path $sdkRoot (
    "turning\r23d26_rapier_steering_cap_preregistration_v1.json"
)
$implementationPath = Join-Path $sdkRoot (
    "turning\r23d26_rapier_steering_cap_implementation_v1.json"
)
$evaluatorPath = Join-Path $sdkRoot (
    "turning\r23d26_rapier_steering_cap_evaluator.py"
)
$supervisorPath = Join-Path $sdkRoot "run_qsdk_r23d26_supervisor.ps1"
$runtimeMaterializationPath = Join-Path $sdkRoot (
    "r23d3_reproducible_runtime_materialization.ps1"
)

function Assert-R23D26([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D26 IMPLEMENTATION: $Message" }
}

$preregistration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$implementation = Get-Content -Raw -LiteralPath $implementationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$supervisorText = Get-Content -Raw -LiteralPath $supervisorPath
$runtimeMaterializationText = Get-Content -Raw -LiteralPath $runtimeMaterializationPath
$expectedCandidates = @("cap_0p10", "cap_0p20", "cap_0p30")
$expectedPolicies = @(
    "sporespore_balanced_wave_r23d26_steering_cap_0p10_v1",
    "sporespore_balanced_wave_r23d26_steering_cap_0p20_v1",
    "sporespore_balanced_wave_r23d26_steering_cap_0p30_v1"
)
$candidates = @($preregistration.candidate_family.ordered_candidates)
Assert-R23D26 (
    [string]$preregistration.campaign_id -ceq
        "QSDK-R23D26-RAPIER-STEERING-CAP-DEVELOPMENT" -and
    [string]$preregistration.gate_id -ceq "QSDK-R23D26" -and
    [int]$preregistration.frozen_matrix.declared_cell_count -eq 9 -and
    (@($preregistration.frozen_matrix.ordered_candidate_ids) -join "|") -ceq
        ($expectedCandidates -join "|") -and
    (@($candidates.controller_policy_id) -join "|") -ceq
        ($expectedPolicies -join "|") -and
    [double]$candidates[0].maximum_steering_fraction -eq 0.10 -and
    [double]$candidates[1].maximum_steering_fraction -eq 0.20 -and
    [double]$candidates[2].maximum_steering_fraction -eq 0.30 -and
    -not [bool]$preregistration.frozen_active_turn_gates.terminal_quiescent_taper_required -and
    -not [bool]$preregistration.selector.selected_candidate_is_validation -and
    -not [bool]$preregistration.claims.turning_validation
) "preregistration identity changed"
Assert-R23D26 (
    [string]$implementation.schema_version -ceq
        "sporespore_qsdk_r23d26_rapier_steering_cap_implementation_v1" -and
    [string]$implementation.worker.module_path -ceq
        "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d26_physical.rs" -and
    [string]$implementation.worker.binary_path -ceq
        "sdk/adapters/rapier/src/bin/qsdk_r23d26_physical.rs" -and
    -not [bool]$implementation.worker.terminal_taper_invoked -and
    [int]$implementation.evaluation.ordered_cell_count -eq 9 -and
    -not [bool]$implementation.evaluation.outcome_aware_early_stop_permitted -and
    [bool]$implementation.source_binding_policy.source_bytes_consumed_by_build_must_equal_git_blobs -and
    [string]$implementation.source_binding_policy.source_materialization_kind -ceq
        "git_archive_blob_exact_v1" -and
    [bool]$implementation.source_binding_policy.ambient_checkout_is_not_build_authority -and
    $supervisorText.Contains("New-R23D26GitBlobSourceMaterialization") -and
    $supervisorText.Contains("git -c core.autocrlf=false -c core.eol=lf") -and
    $supervisorText.Contains("-SourceAuthorityRepoRoot `$repoRoot") -and
    $runtimeMaterializationText.Contains("[string]`$SourceAuthorityRepoRoot = `"`"") -and
    $runtimeMaterializationText.Contains("build_source_root_is_git_blob_materialization")
) "implementation identity changed"

$rustArgs = @(
    "test", "--quiet", "--locked", "--manifest-path",
    (Join-Path $sdkRoot "Cargo.toml"),
    "-p", "sporespore-locomotion-core", "r23d26"
)
$rust = @(& cargo @rustArgs 2>&1)
Assert-R23D26 ($LASTEXITCODE -eq 0) (
    "core cap tests failed: " + ($rust -join " ")
)
$rapierArgs = @(
    "test", "--quiet", "--locked", "--manifest-path",
    (Join-Path $sdkRoot "Cargo.toml"),
    "-p", "sporespore-rapier-adapter", "--lib", "r23d26_tests"
)
$rapier = @(& cargo @rapierArgs 2>&1)
Assert-R23D26 ($LASTEXITCODE -eq 0) (
    "Rapier worker tests failed: " + ($rapier -join " ")
)
$python = @(& python $evaluatorPath --help 2>&1)
Assert-R23D26 ($LASTEXITCODE -eq 0) (
    "evaluator command surface failed: " + ($python -join " ")
)
$preflight = @(& pwsh -NoLogo -NoProfile -File $supervisorPath -PreflightOnly 2>&1)
Assert-R23D26 (
    $LASTEXITCODE -eq 0 -and
    @($preflight | Where-Object {
        ([string]$_).StartsWith(
            "QSDK_R23D26_ZERO_WORLD_PASS workers=9 mutations=2 models=0 worlds=0",
            [StringComparison]::Ordinal
        )
    }).Count -eq 1
) "short supervisor preflight failed: $($preflight -join ' ')"

Write-Host (
    "QSDK_R23D26_IMPLEMENTATION_PASS candidates=3 cells=9 " +
    "core_tests=green rapier_tests=2 models=0 worlds=0 physical=False"
)
