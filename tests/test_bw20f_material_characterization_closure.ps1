#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$sdkRoot = Join-Path $repoRoot "sdk"
$closurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw20f_material_characterization_closure.json"
$supervisorPath = Join-Path (
    $sdkRoot
) "run_balanced_wave_bw20f_material_characterization.ps1"
$productionGatePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw20f_material_characterization_gate.ps1"
$expectedClosureRawSha256 = (
    "68d1ba699d1dcfd9b190423fd542b18843823374cdd8f69029c4e05548e3bf2a"
)
$campaignId = "BW20F-BW19V-COLD-MATERIAL"
$gateId = "BW20F"
$physicalSourceCommit = "476aa4ea521a519a6cd91ef12f265cdb26245839"
$expectedValues = @(0.09, 0.37, 0.76, 1.18)
$expectedLowerForces = @(3.0, 14.0, 29.0, 46.0)
$expectedUpperForces = @(4.0, 15.0, 31.0, 47.0)
$expectedLowerRatios = @(
    0.07647180229187284,
    0.35691676077326845,
    0.7395363279264746,
    1.1730118440718895
)
$expectedControllerMus = @(0.07, 0.35, 0.73, 1.0)
$falseClaimKeys = @(
    "walking_acceptance",
    "friction_or_material_locomotion_robustness",
    "continuous_friction_coverage",
    "portable_material_coefficient",
    "cross_engine_equivalence",
    "arbitrary_quadruped_coverage",
    "continuous_full_volume_morphology_coverage",
    "rough_terrain_robustness",
    "external_push_recovery",
    "sensor_noise_or_latency_robustness",
    "release_authorized",
    "physical_acceptance_authority",
    "completed_engine_neutral_sdk"
)

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

function Assert-HashedFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$ExpectedSha256,
        [Parameter(Mandatory)][long]$ExpectedLength,
        [Parameter(Mandatory)][string]$Message
    )
    Assert-Exact (
        (Test-Path -LiteralPath $Path -PathType Leaf) -and
        (Get-RawSha256 -Path $Path) -ceq $ExpectedSha256 -and
        (Get-Item -LiteralPath $Path).Length -eq $ExpectedLength
    ) $Message
}

Assert-Exact (
    (Test-Path -LiteralPath $closurePath -PathType Leaf) -and
    (Get-RawSha256 -Path $closurePath) -ceq $expectedClosureRawSha256
) "$gateId closure is missing or changed"
$closure = Get-Content -Raw -LiteralPath $closurePath | ConvertFrom-Json

Assert-Exact (
    [string]$closure.schema_version -ceq
        "sporespore_balanced_wave_bw20f_material_characterization_closure_v1" -and
    [string]$closure.status -ceq
        "closed_complete_valid_positive_exact_finite_adapter_material_characterization" -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.study_classification -ceq
        "exact_finite_cell_adapter_material_characterization" -and
    [string]$closure.decision_classification -ceq "finite_decision" -and
    [string]$closure.physical_source_commit -ceq $physicalSourceCommit -and
    -not [bool]$closure.same_identity_rerun_allowed -and
    -not [bool]$closure.threshold_fixture_host_report_or_world_rewrite_allowed -and
    [int]$closure.physical_attempt.process_launch_count -eq 1 -and
    [int]$closure.physical_attempt.process_exit_code -eq 0 -and
    [bool]$closure.physical_attempt.identity_consumed -and
    [bool]$closure.physical_attempt.report_retained -and
    [int]$closure.physical_attempt.expected_world_count -eq 13 -and
    [int]$closure.physical_attempt.observed_world_count -eq 13 -and
    [int]$closure.physical_attempt.locomotion_world_count -eq 0 -and
    [int]$closure.physical_attempt.expected_gate_count -eq 23 -and
    [int]$closure.physical_attempt.passed_gate_count -eq 23 -and
    [int]$closure.physical_attempt.failed_gate_count -eq 0 -and
    [bool]$closure.physical_attempt.accepted
) "$gateId closure identity, classification, or attempt summary changed"

& git -C $repoRoot cat-file -e "${physicalSourceCommit}^{commit}"
Assert-Exact (
    $LASTEXITCODE -eq 0
) "$gateId physical source commit is not retained by Git"
& git -C $repoRoot merge-base --is-ancestor $physicalSourceCommit HEAD
Assert-Exact (
    $LASTEXITCODE -eq 0
) "$gateId physical source is not an ancestor of HEAD"
$originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
Assert-Exact (
    $LASTEXITCODE -eq 0
) "$gateId origin/main cannot be resolved"
& git -C $repoRoot merge-base --is-ancestor $physicalSourceCommit $originMain
Assert-Exact (
    $LASTEXITCODE -eq 0
) "$gateId physical source is not retained by origin/main"

foreach ($binding in @($closure.frozen_source_blobs.PSObject.Properties)) {
    $entry = $binding.Value
    $relativePath = [string]$entry.path
    $gitBlob = (& git -C $repoRoot rev-parse (
        $physicalSourceCommit + ":" + $relativePath
    )).Trim()
    Assert-Exact (
        $LASTEXITCODE -eq 0 -and
        [string]$entry.raw_sha256 -cmatch "^[0-9a-f]{64}$" -and
        $gitBlob -ceq [string]$entry.git_blob_oid
    ) "$gateId physical-source Git blob changed: $relativePath"
}

$evidenceRoot = [System.IO.Path]::GetFullPath(
    [string]$closure.retained_evidence.root
)
$expectedEvidenceRoot = [System.IO.Path]::GetFullPath(
    (Join-Path (Split-Path -Parent $repoRoot) (
        "SporeSpore_Evidence\" +
        "balanced-wave-bw20f-material-characterization-476aa4e"
    ))
)
Assert-Exact (
    $evidenceRoot -ceq $expectedEvidenceRoot -and
    -not $evidenceRoot.StartsWith(
        "C:\tmp\",
        [StringComparison]::OrdinalIgnoreCase
    )
) "$gateId retained evidence root changed or escaped durable storage"

$declaredEvidencePaths = @()
foreach ($binding in @($closure.retained_evidence.PSObject.Properties)) {
    if ($binding.Name -ceq "root") {
        continue
    }
    $entry = $binding.Value
    $declaredEvidencePaths += [string]$entry.path
    Assert-HashedFile `
        -Path (Join-Path $evidenceRoot ([string]$entry.path)) `
        -ExpectedSha256 ([string]$entry.raw_sha256) `
        -ExpectedLength ([long]$entry.byte_length) `
        -Message "$gateId retained evidence changed: $($entry.path)"
}
$observedEvidencePaths = @(
    Get-ChildItem -LiteralPath $evidenceRoot -Recurse -File |
        ForEach-Object {
            [System.IO.Path]::GetRelativePath(
                $evidenceRoot,
                $_.FullName
            ).Replace("\", "/")
        } |
        Sort-Object
)
$declaredEvidencePaths = @($declaredEvidencePaths | Sort-Object)
Assert-Exact (
    $observedEvidencePaths.Count -eq 7 -and
    ($observedEvidencePaths -join "|") -ceq
        ($declaredEvidencePaths -join "|")
) "$gateId retained evidence file set is incomplete or contains undeclared files"

$attemptPath = Join-Path $evidenceRoot "attempt.json"
$reportPath = Join-Path $evidenceRoot "report.json"
$attempt = Get-Content -Raw -LiteralPath $attemptPath | ConvertFrom-Json
$report = Get-Content -Raw -LiteralPath $reportPath |
    ConvertFrom-Json -AsHashtable

Assert-Exact (
    [string]$attempt.schema_version -ceq
        "sporespore_balanced_wave_bw20f_attempt_v1" -and
    [string]$attempt.campaign_id -ceq $campaignId -and
    [string]$attempt.gate_id -ceq $gateId -and
    [string]$attempt.source_commit -ceq $physicalSourceCommit -and
    [string]$attempt.origin_main_commit -ceq $physicalSourceCommit -and
    [string]$attempt.remote_main_commit -ceq $physicalSourceCommit -and
    [bool]$attempt.source_worktree_clean -and
    [bool]$attempt.source_matches_live_github_main -and
    [string]$attempt.godot_version -ceq
        "4.7.stable.mono.official.5b4e0cb0f" -and
    [string]$attempt.godot_executable_sha256 -ceq
        "c5fc2d0bb24826a6757fa1e6bf2991effb294859c7dd03d09a122ef217484896" -and
    [string]$attempt.preregistration_raw_sha256 -ceq
        "7f90a75611c34dd27c3e2a6f1b04b30a58368be9d9871075fb6ef1d0d2caf999" -and
    [bool]$attempt.complete_synthetic_production_gate_passed -and
    [bool]$attempt.zero_world_fixture_preflight_passed -and
    [int]$attempt.preflight_world_build_count -eq 0 -and
    [bool]$attempt.physical_process_launch_reserved_identity_consumed -and
    -not [bool]$attempt.same_identity_rerun_allowed -and
    [int]$attempt.expected_world_count -eq 13 -and
    [int]$attempt.expected_gate_count -eq 23 -and
    [int]$attempt.locomotion_seed_world_count -eq 0 -and
    -not [bool]$attempt.physical_acceptance_authority
) "$gateId attempt receipt changed"

Assert-Exact (
    [string]$report.schema_version -ceq
        "sporespore_balanced_wave_bw20f_material_characterization_report_v1" -and
    [string]$report.source_commit -ceq $physicalSourceCommit -and
    [bool]$report.source_worktree_clean -and
    [bool]$report.source_matches_origin_main -and
    [string]$report.campaign -ceq $gateId -and
    [bool]$report.accepted -and
    [string]$report.result_status -ceq "passed" -and
    [int]$report.godot_exit_code -eq 0 -and
    [string]$report.host_identity.godot_version -ceq
        "4.7.stable.mono.official.5b4e0cb0f" -and
    [string]$report.host_identity.godot_executable_sha256 -ceq
        "c5fc2d0bb24826a6757fa1e6bf2991effb294859c7dd03d09a122ef217484896" -and
    [string]$report.host_identity.physics_engine -ceq "Jolt Physics" -and
    [int]$report.host_identity.physics_hz -eq 120 -and
    [int]$report.host_identity.solver_velocity_steps -eq 20 -and
    [int]$report.host_identity.solver_position_steps -eq 7 -and
    [string]$report.prerequisite_evidence.bw5c_material_characterization.sha256 -ceq
        "067b033266166b15eb0e9f98a5962fdfe7bc199a0af335a64bbb44cc18a09143" -and
    [string]$report.prerequisite_evidence.bw5c_material_characterization.threshold_use -ceq
        "inherited_operational_contract_only"
) "$gateId retained report identity, host, result, or provenance changed"

$receipt = $report.receipt
Assert-Exact (
    [string]$receipt.schema_version -ceq
        "sporespore_balanced_wave_bw20f_material_characterization_receipt_v1" -and
    [bool]$receipt.ok -and
    [int]$receipt.expected_world_count -eq 13 -and
    [int]$receipt.observed_world_count -eq 13 -and
    [int]$receipt.expected_gate_count -eq 23 -and
    [int]$receipt.passed_gate_count -eq 23 -and
    [int]$receipt.failed_gate_count -eq 0 -and
    [bool]$receipt.cold_characterization -and
    -not [bool]$receipt.development_data_only -and
    -not [bool]$receipt.adapter_actuation_applied -and
    -not [bool]$receipt.physics_transform_or_velocity_written -and
    -not [bool]$receipt.walking -and
    -not [bool]$receipt.material_robustness -and
    -not [bool]$receipt.continuous_friction_coverage -and
    -not [bool]$receipt.cross_engine_equivalence -and
    -not [bool]$receipt.physical_acceptance_authority -and
    -not [bool]$receipt.completed_engine_neutral_sdk -and
    [bool]$receipt.invalid_value_control.rejected -and
    [double]$receipt.invalid_value_control.attempted_friction -eq 0.25 -and
    [string]$receipt.invalid_value_control.failure_code -ceq
        "SDK_FRICTION_LADDER_VALUE_INVALID" -and
    [bool]$receipt.frictionless_control.ok -and
    [string]$receipt.frictionless_control.classification -ceq "SLIDING" -and
    [int]$receipt.frictionless_control.world_build_count -eq 1 -and
    [bool]$receipt.monotonicity.ok -and
    @($receipt.monotonicity.violations).Count -eq 0
) "$gateId receipt integrity, controls, or claim boundary changed"

$authoredValues = @($receipt.fixture.authored_friction_values)
$positiveValues = @($receipt.fixture.positive_friction_values)
Assert-Exact (
    $authoredValues.Count -eq 5 -and
    [double]$authoredValues[0] -eq 0.0 -and
    $positiveValues.Count -eq 4 -and
    (@(for ($i = 0; $i -lt 4; $i += 1) {
        [double]$authoredValues[$i + 1] -eq $expectedValues[$i] -and
        [double]$positiveValues[$i] -eq $expectedValues[$i]
    }) -notcontains $false)
) "$gateId authored friction matrix changed"

$cells = @($receipt.positive_cells)
$evaluatedCells = @($report.production_gate_evaluation.cells)
Assert-Exact (
    $cells.Count -eq 4 -and $evaluatedCells.Count -eq 4
) "$gateId must retain exactly four positive characterization cells"
for ($cellIndex = 0; $cellIndex -lt 4; $cellIndex += 1) {
    $cell = $cells[$cellIndex]
    $evaluated = $evaluatedCells[$cellIndex]
    $replicates = @($cell.replicates)
    Assert-Exact (
        [double]$cell.authored_friction -eq $expectedValues[$cellIndex] -and
        [bool]$cell.ok -and
        $replicates.Count -eq 3 -and
        [double]$cell.minimum_lower_breakaway_force_n -eq
            $expectedLowerForces[$cellIndex] -and
        [double]$cell.minimum_lower_empirical_ratio -eq
            $expectedLowerRatios[$cellIndex] -and
        [double]$cell.coefficient_derivation.controller_mu -eq
            $expectedControllerMus[$cellIndex] -and
        [bool]$cell.coefficient_derivation.ok -and
        -not [bool]$cell.coefficient_derivation.cross_engine_equivalent -and
        -not [bool]$cell.coefficient_derivation.locomotion_robustness -and
        [double]$cell.first_sliding_force_spread_n -eq 0.0 -and
        [double]$cell.lower_breakaway_force_spread_n -eq 0.0 -and
        [double]$evaluated.authored_friction -eq $expectedValues[$cellIndex] -and
        [double]$evaluated.minimum_lower_breakaway_force_n -eq
            $expectedLowerForces[$cellIndex] -and
        [double]$evaluated.minimum_lower_empirical_ratio -eq
            $expectedLowerRatios[$cellIndex] -and
        [double]$evaluated.controller_mu -eq $expectedControllerMus[$cellIndex] -and
        [bool]$evaluated.passed
    ) "$gateId cell $cellIndex summary or coefficient changed"
    foreach ($replicate in $replicates) {
        Assert-Exact (
            [bool]$replicate.ok -and
            [bool]$replicate.all_stage_observations_complete -and
            [bool]$replicate.breakaway_analysis.breakaway_detected -and
            [double]$replicate.breakaway_analysis.breakaway_force_lower_n -eq
                $expectedLowerForces[$cellIndex] -and
            [double]$replicate.breakaway_analysis.breakaway_force_upper_n -eq
                $expectedUpperForces[$cellIndex] -and
            [bool]$replicate.two_consecutive_sliding_stages_observed -and
            [bool]$replicate.positive_force_held_observed -and
            [int]$replicate.world_build_count -eq 1
        ) "$gateId cell $cellIndex replicate changed or became incomplete"
    }
}

Assert-Exact (
    [bool]$report.production_gate_evaluation.ok -and
    [int]$report.production_gate_evaluation.expected_gate_count -eq 23 -and
    [int]$report.production_gate_evaluation.reconstructed_passed_gate_count -eq 23 -and
    [int]$report.production_gate_evaluation.reconstructed_failed_gate_count -eq 0 -and
    @($report.production_gate_evaluation.gates).Count -eq 23 -and
    @($report.production_gate_evaluation.failure_codes).Count -eq 0 -and
    [bool]$report.production_gate_evaluation.claims_remain_bounded -and
    -not [bool]$report.production_gate_evaluation.physical_acceptance_authority
) "$gateId retained production-gate evaluation changed"

. $productionGatePath
$recomputed = Test-Bw20fMaterialCharacterizationReceipt -Receipt $receipt
Assert-Exact (
    [bool]$recomputed.ok -and
    [int]$recomputed.reconstructed_passed_gate_count -eq 23 -and
    [int]$recomputed.reconstructed_failed_gate_count -eq 0 -and
    [int]$recomputed.observed_world_count -eq 13 -and
    @($recomputed.failure_codes).Count -eq 0 -and
    -not [bool]$recomputed.physical_acceptance_authority
) "$gateId frozen production evaluator no longer accepts the retained receipt"

Assert-Exact (
    [string]$report.transcript.sha256 -ceq
        [string]$closure.retained_evidence.transcript.raw_sha256 -and
    [string]$report.engine_log.sha256 -ceq
        [string]$closure.retained_evidence.engine_log.raw_sha256 -and
    [string]$report.sources.preregistration.sha256 -ceq
        [string]$closure.frozen_source_blobs.preregistration.raw_sha256 -and
    [string]$report.sources.production_gate.sha256 -ceq
        [string]$closure.frozen_source_blobs.production_gate.raw_sha256 -and
    [string]$report.sources.campaign_runner.sha256 -ceq
        [string]$closure.frozen_source_blobs.physical_supervisor.raw_sha256 -and
    [string]$report.sources.runner.sha256 -ceq
        [string]$closure.frozen_source_blobs.physical_worker.raw_sha256 -and
    [string]$report.sources.fixture_preflight.sha256 -ceq
        [string]$closure.frozen_source_blobs.fixture_preflight.raw_sha256 -and
    [string]$report.sources.test.sha256 -ceq
        [string]$closure.frozen_source_blobs.physical_harness.raw_sha256 -and
    [string]$report.sources.rig.sha256 -ceq
        [string]$closure.frozen_source_blobs.fixture_rig.raw_sha256 -and
    [string]$report.sources.selected_policy.sha256 -ceq
        [string]$closure.frozen_source_blobs.selected_candidate_policy.raw_sha256 -and
    [string]$report.sources.bw19v_closure.sha256 -ceq
        [string]$closure.frozen_source_blobs.bw19v_closure.raw_sha256
) "$gateId report/source/evidence hash reconciliation changed"

Assert-Exact (
    [bool]$closure.result.accepted -and
    [string]$closure.result.result_status -ceq "passed" -and
    [bool]$closure.result.cold_characterization -and
    [bool]$closure.result.invalid_authored_value_rejected -and
    [bool]$closure.result.operational_monotonicity_passed -and
    [bool]$closure.scientific_disposition.complete_valid_positive_exact_finite_characterization -and
    [bool]$closure.scientific_disposition.adapter_profile_publication_authorized -and
    -not [bool]$closure.scientific_disposition.locomotion_outcome_observed -and
    -not [bool]$closure.scientific_disposition.future_locomotion_seeds_opened -and
    -not [bool]$closure.scientific_disposition.material_robustness_established -and
    -not [bool]$closure.scientific_disposition.continuous_friction_coverage_established -and
    -not [bool]$closure.scientific_disposition.portable_material_coefficient_established -and
    -not [bool]$closure.scientific_disposition.cross_engine_equivalence_established -and
    -not [bool]$closure.scientific_disposition.physical_acceptance_authority -and
    [bool]$closure.next_allowed_work.bw20f_stage_1_is_closed -and
    [bool]$closure.next_allowed_work.immutable_adapter_profile_publication_may_proceed -and
    [bool]$closure.next_allowed_work.stage_3_manifest_may_freeze_only_after_profile_publication -and
    [bool]$closure.next_allowed_work.stage_3_physical_locomotion_may_not_open_before_distinct_manifest_and_complete_zero_world_gate -and
    [bool]$closure.next_allowed_work.release_selected_policy_unchanged -and
    [bool]$closure.next_allowed_work.release_not_authorized
) "$gateId scientific disposition or staged interlock changed"

Assert-Exact (
    [bool]$closure.claims.exact_finite_godot_jolt_material_characterization -and
    [bool]$closure.claims.immutable_profile_publication_authorized
) "$gateId positive characterization claim changed"
foreach ($key in $falseClaimKeys) {
    Assert-Exact (
        -not [bool]$closure.claims.$key
    ) "$gateId unsupported claim became true: $key"
}

$allAttemptPaths = @(
    Get-ChildItem `
        -LiteralPath (Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence") `
        -Recurse `
        -File `
        -Filter "attempt.json" |
        Where-Object {
            try {
                $candidateAttempt = Get-Content -Raw -LiteralPath $_.FullName |
                    ConvertFrom-Json
                [string]$candidateAttempt.campaign_id -ceq $campaignId
            } catch {
                $false
            }
        }
)
Assert-Exact (
    $allAttemptPaths.Count -eq 1 -and
    [System.IO.Path]::GetFullPath($allAttemptPaths[0].FullName) -ceq
        [System.IO.Path]::GetFullPath($attemptPath)
) "$gateId must retain exactly one physical attempt"

$rerunOutput = @(
    & pwsh `
        -NoLogo `
        -NoProfile `
        -File $supervisorPath `
        -RunPhysical `
        -OutputRoot $evidenceRoot 2>&1
)
$rerunExitCode = $LASTEXITCODE
Assert-Exact (
    $rerunExitCode -ne 0 -and
    (($rerunOutput | Out-String) -match
        "BW20F characterization is already closed and may not rerun")
) "$gateId physical rerun did not fail at the immutable closure interlock"

Write-Host (
    "BW20F_MATERIAL_CLOSURE_PASS status=positive worlds=13 gates=23 " +
    "cells=4 profile_publication=True locomotion_seeds_opened=0 " +
    "rerun_refused=True material_robustness=False " +
    "physical_authority=False"
)
