#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$sdkRoot = Join-Path $repoRoot "sdk"
$preregistrationPath = Join-Path $sdkRoot (
    "turning\r23d27_stability_guarded_steering_preregistration_v1.json"
)
$implementationPath = Join-Path $sdkRoot (
    "turning\r23d27_stability_guarded_steering_implementation_v1.json"
)
$evaluatorPath = Join-Path $sdkRoot (
    "turning\r23d27_stability_guarded_steering_evaluator.py"
)
$workerPath = Join-Path $sdkRoot (
    "adapters\rapier\src\qsdk_r23d3_phase_balanced\r23d27_physical.rs"
)
$coreRuntimePath = Join-Path $sdkRoot "core\src\runtime.rs"
$supervisorPath = Join-Path $sdkRoot "run_qsdk_r23d27_supervisor.ps1"
$runtimeMaterializationPath = Join-Path $sdkRoot (
    "r23d3_reproducible_runtime_materialization.ps1"
)

function Assert-R23D27([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D27 IMPLEMENTATION: $Message" }
}

$preregistration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$implementation = Get-Content -Raw -LiteralPath $implementationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$workerText = Get-Content -Raw -LiteralPath $workerPath
$coreRuntimeText = Get-Content -Raw -LiteralPath $coreRuntimePath
$supervisorText = Get-Content -Raw -LiteralPath $supervisorPath
$runtimeMaterializationText = Get-Content -Raw -LiteralPath $runtimeMaterializationPath
$expectedCandidates = @("stability_guarded_0p20_to_0p28")
$expectedPolicies = @(
    "sporespore_balanced_wave_r23d27_stability_guarded_steering_v1"
)
$candidates = @($preregistration.candidate_family.ordered_candidates)
Assert-R23D27 (
    [string]$preregistration.campaign_id -ceq
        "QSDK-R23D27-RAPIER-STABILITY-GUARDED-STEERING-VALIDATION" -and
    [string]$preregistration.gate_id -ceq "QSDK-R23D27" -and
    [int]$preregistration.frozen_matrix.declared_cell_count -eq 3 -and
    (@($preregistration.frozen_matrix.ordered_candidate_ids) -join "|") -ceq
        ($expectedCandidates -join "|") -and
    (@($candidates.controller_policy_id) -join "|") -ceq
        ($expectedPolicies -join "|") -and
    [double]$candidates[0].minimum_steering_fraction -eq 0.20 -and
    [double]$candidates[0].maximum_steering_fraction -eq 0.28 -and
    [double]$candidates[0].full_authority_maximum_tilt_rad -eq 0.10 -and
    [double]$candidates[0].minimum_authority_tilt_rad -eq 0.20 -and
    [int]$candidates[0].minimum_support_contact_count -eq 2 -and
    -not [bool]$preregistration.frozen_active_turn_gates.terminal_quiescent_taper_required -and
    [bool]$preregistration.selector.selected_candidate_is_validation -and
    -not [bool]$preregistration.claims.finite_rapier_candidate_validation -and
    -not [bool]$preregistration.claims.turning_validation
) "preregistration identity changed"
Assert-R23D27 (
    [string]$implementation.schema_version -ceq
        "sporespore_qsdk_r23d27_stability_guarded_steering_implementation_v1" -and
    [string]$implementation.worker.module_path -ceq
        "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d27_physical.rs" -and
    [string]$implementation.worker.binary_path -ceq
        "sdk/adapters/rapier/src/bin/qsdk_r23d27_physical.rs" -and
    -not [bool]$implementation.worker.terminal_taper_invoked -and
    [int]$implementation.evaluation.ordered_cell_count -eq 3 -and
    -not [bool]$implementation.evaluation.outcome_aware_early_stop_permitted -and
    [bool]$implementation.source_binding_policy.source_bytes_consumed_by_build_must_equal_git_blobs -and
    [string]$implementation.source_binding_policy.source_materialization_kind -ceq
        "git_archive_blob_exact_v1" -and
    [bool]$implementation.source_binding_policy.ambient_checkout_is_not_build_authority -and
    $workerText.Contains("r23d27_validate_guard_receipt") -and
    $workerText.Contains("ordered_final_canonical_velocities_rad_s") -and
    $workerText.Contains("ordered_actuator_velocity_limits_rad_s") -and
    $coreRuntimeText.Contains("steering_authority_guard_receipt") -and
    $supervisorText.Contains("New-R23D27GitBlobSourceMaterialization") -and
    $supervisorText.Contains("git -c core.autocrlf=false -c core.eol=lf") -and
    $supervisorText.Contains("-SourceAuthorityRepoRoot `$repoRoot") -and
    $runtimeMaterializationText.Contains("[string]`$SourceAuthorityRepoRoot = `"`"") -and
    $runtimeMaterializationText.Contains("build_source_root_is_git_blob_materialization")
) "implementation identity changed"

$rustArgs = @(
    "test", "--quiet", "--locked", "--manifest-path",
    (Join-Path $sdkRoot "Cargo.toml"),
    "-p", "sporespore-locomotion-core", "r23d27"
)
$rust = @(& cargo @rustArgs 2>&1)
Assert-R23D27 ($LASTEXITCODE -eq 0) (
    "core cap tests failed: " + ($rust -join " ")
)
$rapierArgs = @(
    "test", "--quiet", "--locked", "--manifest-path",
    (Join-Path $sdkRoot "Cargo.toml"),
    "-p", "sporespore-rapier-adapter", "--lib", "r23d27_tests"
)
$rapier = @(& cargo @rapierArgs 2>&1)
Assert-R23D27 ($LASTEXITCODE -eq 0) (
    "Rapier worker tests failed: " + ($rapier -join " ")
)
$python = @(& python $evaluatorPath --help 2>&1)
Assert-R23D27 ($LASTEXITCODE -eq 0) (
    "evaluator command surface failed: " + ($python -join " ")
)
$preflight = @(& pwsh -NoLogo -NoProfile -File $supervisorPath -PreflightOnly 2>&1)
Assert-R23D27 (
    $LASTEXITCODE -eq 0 -and
    @($preflight | Where-Object {
        ([string]$_).StartsWith(
            "QSDK_R23D27_ZERO_WORLD_PASS workers=3 mutations=2 models=0 worlds=0",
            [StringComparison]::Ordinal
        )
    }).Count -eq 1
) "short supervisor preflight failed: $($preflight -join ' ')"

Write-Host (
    "QSDK_R23D27_IMPLEMENTATION_PASS candidates=1 cells=3 " +
    "core_tests=green rapier_tests=3 models=0 worlds=0 physical=False"
)
