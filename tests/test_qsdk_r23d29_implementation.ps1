#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$sdkRoot = Join-Path $repoRoot "sdk"
$preregistrationPath = Join-Path $sdkRoot (
    "turning\r23d29_two_swing_persistent_predictive_stability_guarded_steering_preregistration_v1.json"
)
$implementationPath = Join-Path $sdkRoot (
    "turning\r23d29_two_swing_persistent_predictive_stability_guarded_steering_implementation_v1.json"
)
$workerPath = Join-Path $sdkRoot (
    "adapters\rapier\src\qsdk_r23d3_phase_balanced\r23d27_physical.rs"
)
$coreRuntimePath = Join-Path $sdkRoot "core\src\runtime.rs"
$supervisorPath = Join-Path $sdkRoot "run_qsdk_r23d29_supervisor.ps1"
$evaluatorTests = Join-Path $sdkRoot (
    "turning\test_r23d29_two_swing_persistent_predictive_stability_guarded_steering_evaluator.py"
)

function Assert-R23D29([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D29 IMPLEMENTATION: $Message" }
}

$preregistration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$implementation = Get-Content -Raw -LiteralPath $implementationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$workerText = Get-Content -Raw -LiteralPath $workerPath
$coreRuntimeText = Get-Content -Raw -LiteralPath $coreRuntimePath
$supervisorText = Get-Content -Raw -LiteralPath $supervisorPath
$candidate = @($preregistration.candidate_family.ordered_candidates)[0]
$dependencies = @(
    $implementation.dependency_closure.required_dependency_paths_by_worker.rapier_parry
)

Assert-R23D29 (
    [string]$preregistration.campaign_id -ceq
        "QSDK-R23D29-RAPIER-TWO-SWING-PERSISTENT-PREDICTIVE-STABILITY-GUARDED-STEERING-DEVELOPMENT" -and
    [string]$preregistration.gate_id -ceq "QSDK-R23D29" -and
    [string]$preregistration.study_classification -ceq
        "prospective_finite_rapier_controller_development" -and
    [int]$preregistration.frozen_matrix.declared_cell_count -eq 3 -and
    [string]$candidate.controller_policy_id -ceq
        "sporespore_balanced_wave_r23d29_two_swing_persistent_predictive_stability_guarded_steering_v1" -and
    [double]$candidate.prediction_horizon_s -eq 0.6 -and
    [int]$candidate.prediction_horizon_scheduler_swing_steps -eq 72 -and
    [int]$candidate.floor_hold_duration_steps -eq 144 -and
    [int]$candidate.floor_hold_scheduler_swing_count -eq 2 -and
    [string]$candidate.floor_hold_refresh_trigger -ceq
        "instantaneous_effective_authority_reaches_baseline" -and
    [string]$candidate.controller_memory_schema -ceq
        "sporespore_balanced_wave_persistent_predictive_guard_memory_v1" -and
    [string]$candidate.guard_receipt_schema -ceq
        "sporespore_steering_authority_guard_receipt_v3" -and
    -not [bool]$preregistration.selector.selected_candidate_is_validation -and
    -not [bool]$preregistration.claims.turning_validation
) "preregistration identity changed"

Assert-R23D29 (
    [string]$implementation.schema_version -ceq
        "sporespore_qsdk_r23d29_two_swing_persistent_predictive_stability_guarded_steering_implementation_v1" -and
    [string]$implementation.worker.module_path -ceq
        "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d27_physical.rs" -and
    [string]$implementation.worker.binary_path -ceq
        "sdk/adapters/rapier/src/bin/qsdk_r23d29_physical.rs" -and
    [bool]$implementation.worker.inherits_r23d28_fixture_physics_schedule_mapping_and_oracle -and
    [bool]$implementation.worker.adds_independent_persistent_guard_state_transition_oracle -and
    [int]$implementation.worker.floor_hold_duration_steps -eq 144 -and
    -not [bool]$implementation.worker.terminal_taper_invoked -and
    [int]$implementation.evaluation.ordered_cell_count -eq 3 -and
    -not [bool]$implementation.evaluation.outcome_aware_early_stop_permitted -and
    [bool]$implementation.source_binding_policy.source_bytes_consumed_by_build_must_equal_git_blobs -and
    [string]$implementation.source_binding_policy.source_materialization_kind -ceq
        "git_archive_blob_exact_v1" -and
    [bool]$implementation.source_binding_policy.ambient_checkout_is_not_build_authority -and
    $dependencies.Contains("sdk/run_qsdk_r23d27_supervisor.ps1") -and
    $dependencies.Contains("sdk/turning/r23d27_stability_guarded_steering_evaluator.py") -and
    $dependencies.Contains("sdk/publish_qsdk_r23d27_trace.ps1") -and
    $dependencies.Contains("sdk/trace_analysis/r23d28_authority_persistence_diagnosis_closure_v1.json") -and
    $workerText.Contains("expected_floor_triggered") -and
    $workerText.Contains("expected_remaining_after") -and
    $coreRuntimeText.Contains("apply_steering_floor_hold") -and
    $coreRuntimeText.Contains("two_balanced_wave_scheduler_swings_v1") -and
    $supervisorText.Contains('"-CampaignVariant", "R23D29"')
) "implementation identity changed"

$core = @(
    & cargo test --quiet --locked --manifest-path (Join-Path $sdkRoot "Cargo.toml") `
        -p sporespore-locomotion-core r23d29 2>&1
)
Assert-R23D29 ($LASTEXITCODE -eq 0) ("core tests failed: " + ($core -join " "))
$rapier = @(
    & cargo test --quiet --locked --manifest-path (Join-Path $sdkRoot "Cargo.toml") `
        -p sporespore-rapier-adapter --lib r23d29_persistent_worker 2>&1
)
Assert-R23D29 ($LASTEXITCODE -eq 0) ("worker tests failed: " + ($rapier -join " "))
$python = @(& python $evaluatorTests 2>&1)
Assert-R23D29 ($LASTEXITCODE -eq 0) ("evaluator tests failed: " + ($python -join " "))
$preflight = @(& pwsh -NoLogo -NoProfile -File $supervisorPath -PreflightOnly 2>&1)
Assert-R23D29 (
    $LASTEXITCODE -eq 0 -and
    @($preflight | Where-Object {
        ([string]$_).StartsWith(
            "QSDK_R23D29_ZERO_WORLD_PASS workers=3 mutations=2 models=0 worlds=0",
            [StringComparison]::Ordinal
        )
    }).Count -eq 1
) "short supervisor preflight failed: $($preflight -join ' ')"

Write-Host (
    "QSDK_R23D29_IMPLEMENTATION_PASS candidates=1 cells=3 " +
    "core_tests=2 rapier_tests=1 evaluator_tests=3 " +
    "models=0 worlds=0 physical=False"
)
