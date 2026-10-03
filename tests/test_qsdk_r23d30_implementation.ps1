#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$sdkRoot = Join-Path $repoRoot "sdk"
$preregistrationPath = Join-Path $sdkRoot (
    "turning\r23d30_cycle_coherent_directional_response_preregistration_v1.json"
)
$implementationPath = Join-Path $sdkRoot (
    "turning\r23d30_cycle_coherent_directional_response_implementation_v1.json"
)
$attestationManifestPath = Join-Path $sdkRoot (
    "turning\r23d30_campaign_attestation_manifest_v1.json"
)
$workerPath = Join-Path $sdkRoot (
    "adapters\rapier\src\qsdk_r23d3_phase_balanced\r23d27_physical.rs"
)
$supervisorPath = Join-Path $sdkRoot "run_qsdk_r23d30_supervisor.ps1"
$inheritedSupervisorPath = Join-Path $sdkRoot "run_qsdk_r23d27_supervisor.ps1"
$oracleTests = Join-Path $sdkRoot "turning\test_r23d30_cycle_coherent_measurement.py"
$evaluatorTests = Join-Path $sdkRoot (
    "turning\test_r23d30_cycle_coherent_directional_response_evaluator.py"
)
$seedCompiler = Join-Path $sdkRoot "turning\r23d30_seed_fixture_compiler.gd"
$godot = "C:\Users\Cole\bin\godot.cmd"

function Assert-R23D30([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D30 IMPLEMENTATION: $Message" }
}

$preregistration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$implementation = Get-Content -Raw -LiteralPath $implementationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$attestationManifest = Get-Content -Raw -LiteralPath $attestationManifestPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$workerText = Get-Content -Raw -LiteralPath $workerPath
$supervisorText = Get-Content -Raw -LiteralPath $supervisorPath
$inheritedSupervisorText = Get-Content -Raw -LiteralPath $inheritedSupervisorPath
$candidate = @($preregistration.candidate_family.ordered_candidates)[0]
$measurement = $preregistration.cycle_coherent_measurement
$dependencies = @(
    $implementation.dependency_closure.required_dependency_paths_by_worker.rapier_parry
)
$expectedAttestationClaimNames = @(
    "campaign_local_qualification_passed",
    "cold_commissioning_complete",
    "physical_launch_prerequisite_satisfied",
    "physical_campaign_executed",
    "scientific_result",
    "walking_acceptance",
    "turning_acceptance",
    "cross_engine_equivalence",
    "arbitrary_quadruped_coverage",
    "release_authority",
    "physical_acceptance_authority"
) | Sort-Object
$actualAttestationClaimNames = @($attestationManifest.claims.Keys) | Sort-Object
$attestationClaimSchemaMatches = (
    ($actualAttestationClaimNames | ConvertTo-Json -Compress) -ceq
    ($expectedAttestationClaimNames | ConvertTo-Json -Compress)
)

Assert-R23D30 (
    [string]$preregistration.campaign_id -ceq
        "QSDK-R23D30-RAPIER-CYCLE-COHERENT-DIRECTIONAL-RESPONSE-MEASUREMENT-VALIDATION" -and
    [string]$preregistration.gate_id -ceq "QSDK-R23D30" -and
    [string]$preregistration.study_classification -ceq
        "prospective_finite_rapier_measurement_validation" -and
    [int]$preregistration.frozen_matrix.declared_cell_count -eq 3 -and
    [int]$preregistration.frozen_matrix.seed -eq 21504 -and
    [string]$candidate.controller_policy_id -ceq
        "sporespore_balanced_wave_r23d29_two_swing_persistent_predictive_stability_guarded_steering_v1" -and
    @($preregistration.candidate_family.behavioral_controller_change_set).Count -eq 0 -and
    [int]$measurement.baseline_start_step_inclusive -eq 240 -and
    [int]$measurement.baseline_end_step_exclusive -eq 600 -and
    [int]$measurement.terminal_start_step_inclusive -eq 1440 -and
    [int]$measurement.terminal_end_step_exclusive -eq 1800 -and
    [int]$measurement.scheduler_swing_steps -eq 72 -and
    [int]$measurement.scheduler_cycle_steps -eq 360 -and
    [double]$measurement.minimum_raw_signed_cycle_shift_rad -eq 0.01 -and
    [double]$measurement.minimum_reference_conditioned_cycle_shift_rad -eq 0.01 -and
    -not [bool]$preregistration.claims.turning_validation -and
    -not [bool]$preregistration.claims.cross_engine_equivalence
) "preregistration identity changed"

Assert-R23D30 (
    [string]$implementation.schema_version -ceq
        "sporespore_qsdk_r23d30_cycle_coherent_directional_response_implementation_v1" -and
    [string]$implementation.worker.module_path -ceq
        "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d27_physical.rs" -and
    [string]$implementation.worker.binary_path -ceq
        "sdk/adapters/rapier/src/bin/qsdk_r23d30_physical.rs" -and
    [int]$implementation.worker.campaign_seed -eq 21504 -and
    -not [bool]$implementation.worker.controller_behavior_changed_from_r23d29 -and
    [string]$implementation.evaluation.independent_oracle_path -ceq
        "sdk/turning/r23d30_cycle_coherent_measurement.py" -and
    [int]$implementation.evaluation.ordered_cell_count -eq 3 -and
    -not [bool]$implementation.evaluation.outcome_aware_early_stop_permitted -and
    -not [bool]$implementation.evaluation.legacy_endpoint_selects_result -and
    [bool]$implementation.evaluation.cycle_coherent_measurement_selects_result -and
    [bool]$implementation.source_binding_policy.source_bytes_consumed_by_build_must_equal_git_blobs -and
    $dependencies.Contains("sdk/turning/r23d30_cycle_coherent_measurement.py") -and
    $dependencies.Contains("tests/test_qsdk_r23d29_closure.ps1") -and
    $dependencies.Contains("tests/test_qsdk_r23d29_directional_response_diagnosis_closure.ps1") -and
    $workerText.Contains("R23D30_INITIAL_PERTURBATION") -and
    $workerText.Contains("prospective_initial_perturbation") -and
    $supervisorText.Contains('"-CampaignVariant", "R23D30"') -and
    -not $inheritedSupervisorText.Contains(
        'selected_measurement_is_validation = $cycleCoherent'
    ) -and
    $inheritedSupervisorText.Contains(
        '$classification -ceq "valid_complete_positive_measurement_validation_candidate"'
    )
) "implementation identity changed"

Assert-R23D30 (
    [string]$attestationManifest.schema_version -ceq
        "sporespore_locomotion_campaign_attestation_manifest_v1" -and
    [string]$attestationManifest.question_class -ceq "finite_decision" -and
    [string]$attestationManifest.campaign_id -ceq
        [string]$preregistration.campaign_id -and
    [int]$attestationManifest.declared_physical_world_count -eq 3 -and
    [int]$attestationManifest.declared_lineage_gate_count -eq 2 -and
    [int]$attestationManifest.declared_campaign_gate_count -eq 3 -and
    $attestationClaimSchemaMatches -and
    @($attestationManifest.claims.Values | Where-Object { [bool]$_ }).Count -eq 0 -and
    -not [bool]$attestationManifest.physical_execution_authorized -and
    -not [bool]$attestationManifest.physical_acceptance_authority
) "campaign attestation manifest exceeds finite-decision authority"

$seedOutput = @(& $godot --headless --path $repoRoot --script $seedCompiler 2>&1)
Assert-R23D30 (
    $LASTEXITCODE -eq 0 -and
    @($seedOutput | Where-Object {
        ([string]$_).StartsWith("QSDK_R23D30_SEED_FIXTURES ", [StringComparison]::Ordinal)
    }).Count -eq 1 -and
    (($seedOutput -join "`n").Contains('"campaign_seed":21504')) -and
    (($seedOutput -join "`n").Contains('"world_build_count":0'))
) "held-out seed compiler failed: $($seedOutput -join ' ')"

$rapier = @(
    & cargo test --quiet --locked --manifest-path (Join-Path $sdkRoot "Cargo.toml") `
        -p sporespore-rapier-adapter --lib r23d30_cycle_coherent_worker 2>&1
)
Assert-R23D30 ($LASTEXITCODE -eq 0) ("worker tests failed: " + ($rapier -join " "))
$oracle = @(& python $oracleTests 2>&1)
Assert-R23D30 ($LASTEXITCODE -eq 0) ("oracle tests failed: " + ($oracle -join " "))
$evaluator = @(& python $evaluatorTests 2>&1)
Assert-R23D30 ($LASTEXITCODE -eq 0) ("evaluator tests failed: " + ($evaluator -join " "))
$preflight = @(& pwsh -NoLogo -NoProfile -File $supervisorPath -PreflightOnly 2>&1)
Assert-R23D30 (
    $LASTEXITCODE -eq 0 -and
    @($preflight | Where-Object {
        ([string]$_).StartsWith(
            "QSDK_R23D30_ZERO_WORLD_PASS workers=3 mutations=2 models=0 worlds=0",
            [StringComparison]::Ordinal
        )
    }).Count -eq 1
) "short supervisor preflight failed: $($preflight -join ' ')"

Write-Host (
    "QSDK_R23D30_IMPLEMENTATION_PASS candidates=1 cells=3 " +
    "worker_tests=1 oracle_tests=4 evaluator_tests=3 mutations=10 " +
    "models=0 worlds=0 physical=False"
)
